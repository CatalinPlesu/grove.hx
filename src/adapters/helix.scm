(require "helix/misc.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in expansion. "../domain/expansion.scm"))
(require (prefix-in model. "../domain/model.scm"))
(require (prefix-in path. "../domain/path.scm"))
(require (prefix-in view. "../presentation/view.scm"))
(require (prefix-in scanner. "scanner.scm"))
(require (prefix-in git. "git.scm"))
(require (prefix-in input. "helix/input.scm"))
(require (prefix-in host. "helix/host.scm"))
(require (prefix-in files. "helix/files.scm"))
(require (prefix-in hooks. "helix/hooks.scm"))
(require (prefix-in theme. "helix/theme.scm"))
(require (prefix-in render. "helix/render.scm"))
(require (prefix-in component. "helix/component.scm"))

(provide start! focus!)

(define REFRESH-INTERVAL-MS 2000)

(define *model* #f)
(define *latest-view* #f)
(define *input-state* #f)
(define *focus-next-frame?* #f)
(define *started?* #f)
(define *theme-sources* '())

(define (observe model-at-observation scan-active-path?)
  (define observed-root (host.workspace-root))
  (define active-path (host.active-path))
  (define base-expansion
    (if
      (equal? observed-root (model.root model-at-observation))
      (model.expansion model-at-observation)
      (expansion.empty)))
  (define active-id
    (and
      scan-active-path?
      (path.id-for-path observed-root active-path)))
  (define scan-scope
    (if
      active-id
      (expansion.expand-ancestors base-expansion active-id)
      base-expansion))
  (model.observation-snapshot
    observed-root
    (scanner.scan observed-root scan-scope)
    (git.observe observed-root)
    active-path))

(define (refresh-now!)
  (define snapshot (observe *model* #f))
  (dispatch! (model.observation-received snapshot)))

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
        (model.open-file-command-path command)
        (model.open-file-command-mode command))]
    [(model.create-prompt-command? command)
      (files.prompt-create! command dispatch! refresh-now!)]
    [(model.rename-prompt-command? command)
      (files.prompt-rename! command refresh-now!)]
    [(model.delete-confirmation-command? command)
      (files.confirm-delete! command refresh-now!)]
    [else (error "unknown Model command")]))

(define (dispatch! message)
  (define update-result
    (model.update *model* message))
  (define next-model (model.update-result-model update-result))
  (set! *model* next-model)
  (define command (model.update-result-command update-result))
  (when command
    (execute-command! command)))

(define (render-current! geometry frame)
  (if
    *focus-next-frame?*
    (let ([snapshot (observe *model* #t)])
      (set! *focus-next-frame?* #f)
      (dispatch! (model.focus-frame-observed snapshot geometry)))
    (dispatch! (model.geometry-observed geometry)))
  (define model-at-render *model*)
  (define current-view
    (view.build
      (model.resolved-layout model-at-render)
      (theme.resolve
        *theme-sources*
        (model.icons? model-at-render)
        (model.guides? model-at-render))))
  (if current-view
    (begin
      (component.apply-clip!
        (view.width current-view))
      (render.draw! frame current-view)
      (set! *latest-view* current-view))
    (begin
      (component.apply-clip! 0)
      (set! *latest-view* #f)
      (set! *input-state* (input.init))))
  frame)

(define (handle-event! event)
  (define input-result
    (input.step
      *input-state*
      *model*
      *latest-view*
      event))
  (set! *input-state* (input.result-state input-result))
  (define message (input.result-message input-result))
  (when message
    (dispatch! message))
  (input.result-pass-through? input-result))

(define (start-runtime! side width icons? guides?)
  (define initial-update
    (model.init side width icons? guides?))
  (set! *model* (model.update-result-model initial-update))
  (set! *latest-view* #f)
  (set! *input-state* (input.init))
  (set! *focus-next-frame?* #f)
  (hooks.install! dispatch!)
  (component.install! side render-current! handle-event!)
  (subscribe-to-refresh!)
  (define command (model.update-result-command initial-update))
  (when command
    (execute-command! command)))

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
