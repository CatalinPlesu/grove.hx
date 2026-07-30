(require "helix/components.scm")
(require (prefix-in view. "../../presentation/view.scm"))
(require (prefix-in line. "../../presentation/line.scm"))

(provide draw!)

(define (apply-run-icon-color run)
  (define style (line.run-style run))
  (define color (line.run-icon-color run))
  (if color
    (style-fg
      style
      (Color/rgb
        (line.color-red color)
        (line.color-green color)
        (line.color-blue color)))
    style))

(define (apply-run-style run)
  (define icon-colored-style (apply-run-icon-color run))
  (define foreground (line.run-foreground run))
  (define complete-style
    (if foreground
      (style-fg icon-colored-style foreground)
      icon-colored-style))
  (if (line.run-dim? run)
    (style-with-dim complete-style)
    complete-style))

(define (draw-line! frame runs column row)
  (let loop ([remaining runs] [x column])
    (unless (null? remaining)
      (define run (car remaining))
      (define text (line.run-text run))
      (frame-set-string!
        frame
        x
        row
        text
        (apply-run-style run))
      (loop (cdr remaining) (+ x (string-length text))))))

(define (draw! frame current-view)
  (let loop ([remaining (view.lines current-view)]
             [row (view.y current-view)])
    (unless (null? remaining)
      (draw-line!
        frame
        (view.line-runs (car remaining))
        (view.x current-view)
        row)
      (loop (cdr remaining) (+ row 1)))))
