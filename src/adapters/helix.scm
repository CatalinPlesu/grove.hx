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
(require (prefix-in hooks. "helix/hooks.scm"))
(require (prefix-in theme. "helix/theme.scm"))
(require (prefix-in render. "helix/render.scm"))
(require (prefix-in component. "helix/component.scm"))

(provide start! focus!)

(define REFRESH-INTERVAL-MS 2000)

(struct runtime
  (model latest-view input-state focus-next-frame?))

(define *runtime* #f)
(define *started?* #f)

(define (current-runtime)
  (or *runtime* (error "Grove has not started")))

(define (current-model)
  (unbox (runtime-model (current-runtime))))

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
  (define snapshot (observe (current-model) #f))
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
    [else (error "unknown Model command")]))

(define (dispatch! message)
  (define state (current-runtime))
  (define update-result
    (model.update
     (unbox (runtime-model state))
     message))
  (define next-model (model.update-result-model update-result))
  (set-box! (runtime-model state) next-model)
  (define command (model.update-result-command update-result))
  (when command
    (execute-command! command)))

(define (render-current! geometry frame)
  (define state (current-runtime))
  (if
   (unbox (runtime-focus-next-frame? state))
   (let ([snapshot (observe (current-model) #t)])
     (set-box! (runtime-focus-next-frame? state) #f)
     (dispatch! (model.focus-frame-observed snapshot geometry)))
   (dispatch! (model.geometry-observed geometry)))
  (define model-at-render (current-model))
  (define current-view
    (view.build
     (model.resolved-layout model-at-render)
     (theme.current-styles (model.icons? model-at-render))))
  (if current-view
      (begin
        (component.apply-clip!
         (view.width current-view))
        (render.draw! frame current-view)
        (set-box! (runtime-latest-view state) current-view))
      (begin
        (component.apply-clip! 0)
        (set-box! (runtime-latest-view state) #f)
        (set-box!
         (runtime-input-state state)
         (input.init))))
  frame)

(define (handle-event! event)
  (define state (current-runtime))
  (define input-result
    (input.step
     (unbox (runtime-input-state state))
     (unbox (runtime-model state))
     (unbox (runtime-latest-view state))
     event))
  (set-box!
   (runtime-input-state state)
   (input.result-state input-result))
  (define message (input.result-message input-result))
  (when message
    (dispatch! message))
  (input.result-pass-through? input-result))

(define (start-runtime! side width icons?)
  (define initial-update
    (model.init side width icons?))
  (set! *runtime*
        (runtime
         (box (model.update-result-model initial-update))
         (box #f)
         (box (input.init))
         (box #f)))
  (hooks.install! dispatch!)
  (component.install! side render-current! handle-event!)
  (subscribe-to-refresh!)
  (define command (model.update-result-command initial-update))
  (when command
    (execute-command! command)))

(define (start! side width icons?)
  (when *started?*
    (error "Grove has already started"))
  (set! *started?* #t)
  (enqueue-thread-local-callback
   (lambda () (start-runtime! side width icons?)))
  #t)

(define (focus!)
  (when *runtime*
    (define state (current-runtime))
    (set-box!
     (runtime-focus-next-frame? state)
     #t)
    (helix.redraw))
  #t)
