(require "helix/components.scm")
(require "helix/ext.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in layout. "../../domain/layout.scm"))

(provide install! apply-clip!)

(define GROVE-NAME "grove")
(define *clip-side* #f)
(define *clip-width* #f)

(define (apply-clip! width)
  (unless (equal? width *clip-width*)
    (if (equal? *clip-side* 'left)
      (set-editor-clip-left! width)
      (set-editor-clip-right! width))
    (set! *clip-width* width)
    ; This redraw fixes the editor's alignment in case the grove file tree is not pinned.
    (helix.redraw)))

(define (install! side render! handle-event!)
  (set! *clip-side* side)
  (set! *clip-width* #f)
  (apply-clip! 0)
  (define (render-component! _state rect frame)
    (render!
      (layout.geometry
        (area-x rect)
        (area-y rect)
        (area-width rect)
        (area-height rect))
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
        "handle_event"
        handle-component-event!
        "cursor"
        (lambda (_state _rect) #f)))))
