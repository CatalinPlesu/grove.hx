(require "helix/misc.scm")
(require "helix/components.scm")
(require (prefix-in layout. "../../domain/layout.scm"))
(require (prefix-in model. "../../domain/model.scm"))

(provide cancel! handle! result-update result-pass-through?)

(struct gesture (kind origin-x origin-y grab-offset))
(struct result (update pass-through?))

(define *gesture* #f)

(define (cancel!)
  (set! *gesture* #f))

(define (finish! state update-result pass-through?)
  (set! *gesture* state)
  (result update-result pass-through?))

(define (decode-mouse event)
  (define kind (event-mouse-kind event))
  (cond
    [(= kind 0) 'press]
    [(= kind 3) 'release]
    [(= kind 6) 'motion]
    [(= kind 10) 'wheel-down]
    [(= kind 11) 'wheel-up]
    [else #f]))

(define (key-update current-model event)
  (define character (key-event-char event))
  (define modifier (key-event-modifier event))
  (define (plain? expected)
    (and
      (or (= modifier 0) (= modifier key-modifier-shift))
      (char? character)
      (char=? character expected)))
  (cond
    [(key-event-page-up? event)
      (model.cursor-move-requested current-model 'previous-page)]
    [(key-event-page-down? event)
      (model.cursor-move-requested current-model 'next-page)]
    [(or (key-event-down? event) (plain? #\j))
      (model.cursor-move-requested current-model 'next)]
    [(or (key-event-up? event) (plain? #\k))
      (model.cursor-move-requested current-model 'previous)]
    [(or (key-event-right? event) (plain? #\l))
      (model.cursor-expansion-requested current-model 'expand)]
    [(or (key-event-left? event) (plain? #\h))
      (model.cursor-expansion-requested current-model 'collapse)]
    [(key-event-enter? event)
      (model.cursor-open-requested current-model 'normal)]
    [(key-event-escape? event) (model.focus-released current-model)]
    [(and (= modifier key-modifier-ctrl)
          (char? character)
          (char=? character #\s))
      (model.cursor-open-requested current-model 'horizontal-split)]
    [(and (= modifier key-modifier-ctrl)
          (char? character)
          (char=? character #\v))
      (model.cursor-open-requested current-model 'vertical-split)]
    [(plain? #\+) (model.resize-by-requested current-model 1)]
    [(plain? #\-) (model.resize-by-requested current-model -1)]
    [(plain? #\n) (model.cursor-mutation-requested current-model 'file)]
    [(plain? #\N) (model.cursor-mutation-requested current-model 'directory)]
    [(plain? #\r) (model.cursor-mutation-requested current-model 'rename)]
    [(plain? #\d) (model.cursor-mutation-requested current-model 'delete)]
    [else #f]))

(define (inside? current-layout column row)
  (and
    (>= column (layout.x current-layout))
    (< column (+ (layout.x current-layout) (layout.width current-layout)))
    (>= row (layout.y current-layout))
    (< row (+ (layout.y current-layout) (layout.height current-layout)))))

(define (anchor-update current-model anchor)
  (and anchor (model.scroll-anchor-requested current-model anchor)))

(define (start-press! current-model current-layout column row)
  (cond
    [(not (inside? current-layout column row))
      (finish!
        #f
        (and (model.focused? current-model)
          (model.focus-released current-model))
        #t)]
    [(= column (layout.rail-x current-layout))
      (define grab-offset (layout.rail-thumb-offset current-layout row))
      (finish!
        (gesture
          (if (integer? grab-offset) 'thumb-press 'track-press)
          column row grab-offset)
        #f
        #f)]
    [else
      (define id (layout.row-id-at current-layout row))
      (finish!
        #f
        (and id (model.row-pressed current-model id))
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

(define (resize! current-model state current-layout column)
  (finish!
    state
    (model.resize-to-requested
      current-model
      (layout.rail-resize-width current-layout column))
    #f))

(define (scroll! current-model state current-layout row grab-offset)
  (finish!
    state
    (anchor-update
      current-model
      (layout.rail-scroll-anchor current-layout row grab-offset))
    #f))

(define (continue-press!
         current-model
         current-gesture
         current-layout
         column
         row
         release?)
  (define axis (chosen-axis current-gesture column row))
  (define kind (gesture-kind current-gesture))
  (define grab-offset (gesture-grab-offset current-gesture))
  (cond
    [(equal? axis 'horizontal)
      (resize!
        current-model
        (state-after (gesture 'resize #f #f #f) release?)
        current-layout column)]
    [(and (equal? axis 'vertical) (equal? kind 'thumb-press))
      (scroll!
        current-model
        (state-after (gesture 'thumb #f #f grab-offset) release?)
        current-layout row grab-offset)]
    [(equal? axis 'vertical)
      (finish!
        (state-after (gesture 'track #f #f #f) release?) #f #f)]
    [(and release?
          (equal? kind 'track-press)
          (= column (gesture-origin-x current-gesture))
          (= row (gesture-origin-y current-gesture)))
      (finish!
        #f
        (anchor-update
          current-model
          (layout.rail-page-anchor current-layout row))
        #f)]
    [else
      (finish! (state-after current-gesture release?) #f #f)]))

(define (continue-gesture! current-model current-layout phase column row)
  (define release? (equal? phase 'release))
  (define kind (gesture-kind *gesture*))
  (cond
    [(member kind '(thumb-press track-press))
      (continue-press!
        current-model *gesture* current-layout column row release?)]
    [(equal? kind 'resize)
      (resize!
        current-model
        (state-after *gesture* release?)
        current-layout column)]
    [(equal? kind 'thumb)
      (scroll!
        current-model
        (state-after *gesture* release?)
        current-layout row (gesture-grab-offset *gesture*))]
    [(equal? kind 'track)
      (finish! (state-after *gesture* release?) #f #f)]
    [else (error "invalid Rail gesture")]))

(define (handle-mouse! current-model current-layout event)
  (define kind (decode-mouse event))
  (define column (event-mouse-col event))
  (define row (event-mouse-row event))
  (cond
    [(not kind) (result #f #t)]
    [(not current-layout) (finish! #f #f #t)]
    [(equal? kind 'press)
      (start-press! current-model current-layout column row)]
    [(member kind '(wheel-up wheel-down))
      (if
        (inside? current-layout column row)
        (finish!
          #f
          (anchor-update
            current-model
            (layout.scroll-by
              current-layout
              (if (equal? kind 'wheel-down) 3 -3)))
          #f)
        (finish! #f #f #t))]
    [*gesture*
      (continue-gesture! current-model current-layout kind column row)]
    [else (finish! #f #f #t)]))

(define (handle! current-model current-layout event)
  (cond
    [(mouse-event? event)
      (handle-mouse! current-model current-layout event)]
    [(not (key-event? event)) (result #f #t)]
    [(not (model.focused? current-model)) (finish! #f #f #t)]
    [else
      (define update-result (key-update current-model event))
      (if
        update-result
        (finish! #f update-result #f)
        (finish! #f (model.focus-released current-model) #t))]))
