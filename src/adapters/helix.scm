(require "helix/misc.scm")
(require "helix/components.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in expansion. "../domain/expansion.scm"))
(require (prefix-in layout. "../domain/layout.scm"))
(require (prefix-in model. "../domain/model.scm"))
(require (prefix-in path. "../domain/path.scm"))
(require (prefix-in line. "../presentation/line.scm"))
(require (prefix-in scanner. "scanner.scm"))
(require (prefix-in git. "git.scm"))
(require (prefix-in host. "helix/host.scm"))
(require (prefix-in files. "helix/files.scm"))
(require (prefix-in hooks. "helix/hooks.scm"))
(require (prefix-in theme. "helix/theme.scm"))
(require (prefix-in component. "helix/component.scm"))

(provide start! focus!)

(define REFRESH-INTERVAL-MS 2000)

(define *model* #f)
(define *latest-frame* #f)
(define *input-state* #f)
(define *focus-next-frame?* #f)
(define *started?* #f)
(define *theme-sources* '())

(struct gesture (kind origin-x origin-y grab-offset))
(struct rendered-frame (root layout))

(define (observe model-at-observation scan-active-path?)
  (define observed-root (host.workspace-root))
  (define active-path (host.active-path))
  (define active-id
    (path.id-for-path observed-root active-path))
  (define base-expansion
    (if
      (equal? observed-root (model.root model-at-observation))
      (model.expansion model-at-observation)
      (expansion.empty)))
  (define scan-scope
    (if
      (and scan-active-path? active-id)
      (expansion.expand-ancestors base-expansion active-id)
      base-expansion))
  (model.observation-snapshot
    observed-root
    (scanner.scan observed-root scan-scope)
    (git.observe observed-root)
    active-id))

(define (refresh-now!)
  (define snapshot (observe *model* #f))
  (dispatch! model.observation-received snapshot))

(define (schedule-refresh!)
  (enqueue-thread-local-callback refresh-now!))

(define (subscribe-to-refresh!)
  (define (schedule-next!)
    (enqueue-thread-local-callback-with-delay
      REFRESH-INTERVAL-MS
      (lambda ()
        (refresh-now!)
        (schedule-next!))))
  (schedule-next!))

(define (execute-command! command)
  (cond
    [(model.refresh-command? command)
      (schedule-refresh!)]
    [(model.open-file-command? command)
      (host.open-file!
        (path.path-for-id
          (model.open-file-command-root command)
          (model.open-file-command-id command))
        (model.open-file-command-mode command))]
    [(model.create-prompt-command? command)
      (files.prompt-create! command dispatch! refresh-now!)]
    [(model.rename-prompt-command? command)
      (files.prompt-rename! command refresh-now!)]
    [(model.delete-confirmation-command? command)
      (files.confirm-delete! command refresh-now!)]
    [else (error "unknown Model command")]))

(define (install-update! update-result)
  (define next-model (model.update-result-model update-result))
  (set! *model* next-model)
  (define command (model.update-result-command update-result))
  (when command
    (execute-command! command)))

(define (dispatch! transition . arguments)
  (install-update! (apply transition *model* arguments)))

(define (finish-event! state update-result pass-through?)
  (set! *input-state* state)
  (when update-result
    (install-update! update-result))
  pass-through?)

(define (decode-mouse event)
  (define kind (event-mouse-kind event))
  (cond
    [(= kind 0) 'press]
    [(= kind 3) 'release]
    [(= kind 6) 'motion]
    [(= kind 10) 'wheel-down]
    [(= kind 11) 'wheel-up]
    [else #f]))

(define (key-update event)
  (define character (key-event-char event))
  (define modifier (key-event-modifier event))
  (define (plain? expected)
    (and
      (or (= modifier 0) (= modifier key-modifier-shift))
      (char? character)
      (char=? character expected)))
  (cond
    [(key-event-page-up? event)
      (model.cursor-move-requested *model* 'previous-page)]
    [(key-event-page-down? event)
      (model.cursor-move-requested *model* 'next-page)]
    [(or (key-event-down? event) (plain? #\j))
      (model.cursor-move-requested *model* 'next)]
    [(or (key-event-up? event) (plain? #\k))
      (model.cursor-move-requested *model* 'previous)]
    [(or (key-event-right? event) (plain? #\l))
      (model.cursor-expansion-requested *model* 'expand)]
    [(or (key-event-left? event) (plain? #\h))
      (model.cursor-expansion-requested *model* 'collapse)]
    [(key-event-enter? event)
      (model.cursor-open-requested *model* 'normal)]
    [(key-event-escape? event) (model.focus-released *model*)]
    [(and (= modifier key-modifier-ctrl)
          (char? character)
          (char=? character #\s))
      (model.cursor-open-requested *model* 'horizontal-split)]
    [(and (= modifier key-modifier-ctrl)
          (char? character)
          (char=? character #\v))
      (model.cursor-open-requested *model* 'vertical-split)]
    [(plain? #\+) (model.resize-by-requested *model* 1)]
    [(plain? #\-) (model.resize-by-requested *model* -1)]
    [(plain? #\n) (model.cursor-mutation-requested *model* 'file)]
    [(plain? #\N) (model.cursor-mutation-requested *model* 'directory)]
    [(plain? #\r) (model.cursor-mutation-requested *model* 'rename)]
    [(plain? #\d) (model.cursor-mutation-requested *model* 'delete)]
    [else #f]))

(define (inside? current-layout column row)
  (and
    (>= column (layout.x current-layout))
    (< column (+ (layout.x current-layout) (layout.width current-layout)))
    (>= row (layout.y current-layout))
    (< row (+ (layout.y current-layout) (layout.height current-layout)))))

(define (scroll-to current-layout row grab-offset)
  (define offset
    (layout.rail-scroll-offset current-layout row grab-offset))
  (define limit (layout.rail-scroll-limit current-layout))
  (and
    (integer? offset)
    (integer? limit)
    (layout.scroll-to current-layout offset limit)))

(define (page current-layout row)
  (define amount (layout.rail-page-amount current-layout row))
  (and (integer? amount) (layout.scroll-by current-layout amount)))

(define (anchor-update anchor)
  (and anchor (model.scroll-anchor-requested *model* anchor)))

(define (start-press! current-layout column row)
  (cond
    [(not (inside? current-layout column row))
      (finish-event!
        #f
        (and (model.focused? *model*) (model.focus-released *model*))
        #t)]
    [(= column (layout.rail-x current-layout))
      (define grab-offset (layout.rail-thumb-offset current-layout row))
      (finish-event!
        (gesture
          (if (integer? grab-offset) 'thumb-press 'track-press)
          column row grab-offset)
        #f
        #f)]
    [else
      (define id (layout.row-id-at current-layout row))
      (finish-event!
        #f
        (and id (model.row-pressed *model* id))
        #f)]))

(define (chosen-axis current-gesture column row)
  (define dx (abs (- column (gesture-origin-x current-gesture))))
  (define dy (abs (- row (gesture-origin-y current-gesture))))
  (cond
    [(= dx dy) #f]
    [(> dx dy) 'horizontal]
    [else 'vertical]))

(define (state-after current-gesture release?)
  (and (not release?) current-gesture))

(define (resize! state current-layout column)
  (finish-event!
    state
    (model.resize-to-requested
      *model*
      (layout.rail-resize-width current-layout column))
    #f))

(define (scroll! state current-layout row grab-offset)
  (finish-event!
    state
    (anchor-update (scroll-to current-layout row grab-offset))
    #f))

(define (continue-press! current-gesture current-layout column row release?)
  (define axis (chosen-axis current-gesture column row))
  (define kind (gesture-kind current-gesture))
  (define grab-offset (gesture-grab-offset current-gesture))
  (cond
    [(equal? axis 'horizontal)
      (resize!
        (state-after (gesture 'resize #f #f #f) release?)
        current-layout column)]
    [(and (equal? axis 'vertical) (equal? kind 'thumb-press))
      (scroll!
        (state-after (gesture 'thumb #f #f grab-offset) release?)
        current-layout row grab-offset)]
    [(equal? axis 'vertical)
      (finish-event!
        (state-after (gesture 'track #f #f #f) release?) #f #f)]
    [(and release?
          (equal? kind 'track-press)
          (= column (gesture-origin-x current-gesture))
          (= row (gesture-origin-y current-gesture)))
      (finish-event! #f (anchor-update (page current-layout row)) #f)]
    [else
      (finish-event!
        (state-after current-gesture release?) #f #f)]))

(define (continue-gesture! current-layout phase column row)
  (define release? (equal? phase 'release))
  (define kind (gesture-kind *input-state*))
  (cond
    [(member kind '(thumb-press track-press))
      (continue-press! *input-state* current-layout column row release?)]
    [(equal? kind 'resize)
      (resize! (state-after *input-state* release?) current-layout column)]
    [(equal? kind 'thumb)
      (scroll!
        (state-after *input-state* release?)
        current-layout row (gesture-grab-offset *input-state*))]
    [(equal? kind 'track)
      (finish-event! (state-after *input-state* release?) #f #f)]
    [else (error "invalid Rail gesture")]))

(define (handle-mouse! current-layout event)
  (define kind (decode-mouse event))
  (define column (event-mouse-col event))
  (define row (event-mouse-row event))
  (cond
    [(not kind) #t]
    [(not current-layout) (finish-event! #f #f #t)]
    [(equal? kind 'press) (start-press! current-layout column row)]
    [(member kind '(wheel-up wheel-down))
      (if
        (inside? current-layout column row)
        (finish-event!
          #f
          (anchor-update
            (layout.scroll-by
              current-layout
              (if (equal? kind 'wheel-down) 3 -3)))
          #f)
        (finish-event! #f #f #t))]
    [*input-state*
      (continue-gesture! current-layout kind column row)]
    [else (finish-event! #f #f #t)]))

(define (render-current! geometry frame)
  (if
    *focus-next-frame?*
    (let ([snapshot (observe *model* #t)])
      (set! *focus-next-frame?* #f)
      (dispatch! model.focus-frame-observed snapshot geometry))
    (dispatch! model.geometry-observed geometry))
  (define model-at-render *model*)
  (define current-layout (model.resolved-layout model-at-render))
  (if current-layout
    (begin
      (component.apply-clip! (layout.width current-layout))
      (line.draw!
        frame
        current-layout
        (model.row-facts model-at-render)
        (theme.resolve
          *theme-sources*
          (model.icons? model-at-render)
          (model.guides? model-at-render)))
      (set! *latest-frame*
        (rendered-frame (model.root model-at-render) current-layout)))
    (begin
      (component.apply-clip! 0)
      (set! *latest-frame* #f)
      (set! *input-state* #f)))
  frame)

(define (handle-event! event)
  (define current-layout
    (and
      *latest-frame*
      (equal? (rendered-frame-root *latest-frame*) (model.root *model*))
      (rendered-frame-layout *latest-frame*)))
  (unless current-layout
    (set! *input-state* #f))
  (cond
    [(mouse-event? event) (handle-mouse! current-layout event)]
    [(not (key-event? event)) #t]
    [(not (model.focused? *model*)) (finish-event! #f #f #t)]
    [else
      (define update-result (key-update event))
      (if
        update-result
        (finish-event! #f update-result #f)
        (finish-event! #f (model.focus-released *model*) #t))]))

(define (start-runtime! side width icons? guides?)
  (set! *model* (model.init side width icons? guides?))
  (set! *latest-frame* #f)
  (set! *input-state* #f)
  (set! *focus-next-frame?* #f)
  (hooks.install! dispatch!)
  (component.install! side render-current! handle-event!)
  (subscribe-to-refresh!)
  (schedule-refresh!))

(define (start! side width icons? guides? theme-sources)
  (when *started?*
    (error "Grove has already started"))
  (set! *started?* #t)
  (set! *theme-sources* theme-sources)
  (enqueue-thread-local-callback
    (lambda () (start-runtime! side width icons? guides?)))
  #t)

(define (focus!)
  (when *model*
    (set! *focus-next-frame?* #t)
    (helix.redraw))
  void)
