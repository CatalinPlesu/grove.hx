(require "helix/misc.scm")
(require (prefix-in model. "../domain/model.scm"))
(require (prefix-in view. "../presentation/view.scm"))
(require (prefix-in refresh. "refresh.scm"))
(require (prefix-in input. "helix/input.scm"))
(require (prefix-in host. "helix/host.scm"))
(require (prefix-in hooks. "helix/hooks.scm"))
(require (prefix-in theme. "helix/theme.scm"))
(require (prefix-in render. "helix/render.scm"))
(require (prefix-in component. "helix/component.scm"))

(provide start! focus!)

(struct runtime-value (icons? pane model rail-press))

(define *runtime* #f)
(define *started?* #f)

(define (runtime)
  (or *runtime* (error "Grove has not started")))

(define (execute-command! command)
  (cond
    [(model.refresh-command? command)
     (refresh.run! command dispatch!)]
    [(model.open-file-command? command)
     (host.open-file!
      (model.open-file-command-path command)
      (model.open-file-command-mode command))]
    [else (error "unknown Model command")]))

(define (apply-update! update-result)
  (define runtime-value (runtime))
  (define prior-model (unbox (runtime-value-model runtime-value)))
  (define next-model (model.update-result-model update-result))
  (set-box! (runtime-value-model runtime-value) next-model)
  (unless (equal? (model.root prior-model) (model.root next-model))
    (set-box! (runtime-value-pane runtime-value) #f)
    (set-box! (runtime-value-rail-press runtime-value) #f))
  (define command (model.update-result-command update-result))
  (when command
    (execute-command! command)))

(define (dispatch! message)
  (apply-update!
   (model.update
    (unbox (runtime-value-model (runtime)))
    message)))

(define (render-current! side geometry frame)
  (define runtime-state (runtime))
  (define current-model (unbox (runtime-value-model runtime-state)))
  (set-box! (runtime-value-pane runtime-state) #f)
  (define current-pane
    (view.build
     current-model
     side
     geometry
     (theme.current-styles (runtime-value-icons? runtime-state))))
  (if current-pane
      (begin
        (component.apply-clip!
        (view.width current-pane))
        (render.draw! frame current-pane)
        (set-box! (runtime-value-pane runtime-state) current-pane))
      (begin
        (component.apply-clip! 0)
        (set-box! (runtime-value-pane runtime-state) #f)
        (set-box! (runtime-value-rail-press runtime-state) #f)))
  frame)

(define (handle-event! event)
  (define runtime-value (runtime))
  (define current-model (unbox (runtime-value-model runtime-value)))
  (define input-result
    (input.step
     (unbox (runtime-value-rail-press runtime-value))
     (model.focused? current-model)
     (unbox (runtime-value-pane runtime-value))
     event))
  (set-box!
   (runtime-value-rail-press runtime-value)
   (input.result-rail-press input-result))
  (define message (input.result-message input-result))
  (when message
    (dispatch! message))
  (input.result-pass-through? input-result))

(define (start-runtime! side width icons?)
  (define root (host.workspace-root))
  (define initial-update
    (model.init root width (host.active-path)))
  (set! *runtime*
        (runtime-value
         icons?
         (box #f)
         (box (model.update-result-model initial-update))
         (box #f)))
  (hooks.install! dispatch!)
  (component.install! side width render-current! handle-event!)
  (refresh.subscribe! dispatch!)
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
  (enqueue-thread-local-callback
   (lambda ()
     (when *runtime*
       (dispatch!
        (model.focus-requested
         (host.workspace-root)
         (host.active-path)))))))
