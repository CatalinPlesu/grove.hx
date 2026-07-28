(require "helix/components.scm")
(require "helix/ext.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in view. "../../presentation/view.scm"))

(provide install! apply-clip!)

(define GROVE-NAME "grove")
(define *clip-side* #f)
(define *clip-width* #f)

(define (set-clip! width)
  (if (equal? *clip-side* 'left)
      (set-editor-clip-left! width)
      (set-editor-clip-right! width)))

(define (apply-clip! width)
  (unless (equal? width *clip-width*)
    (set-clip! width)
    (set! *clip-width* width)))

(define (install! side width render! handle-event!)
  (set! *clip-side* side)
  (set! *clip-width* #f)
  (apply-clip! width)
  (define (render-component! _state rect frame)
    (render!
     *clip-side*
     (view.geometry
      (area-x rect) (area-y rect) (area-width rect) (area-height rect))
     frame))
  (define (handle-component-event! _state event)
    (if
     (handle-event! event)
     event-result/ignore
     event-result/consume))
  (push-component!
   (new-component!
    GROVE-NAME
    #f
    render-component!
    (hash
     "handle_event" handle-component-event!
     "cursor" (lambda (_state _rect) #f)))))
