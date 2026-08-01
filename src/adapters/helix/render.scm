(require "helix/components.scm")
(require (prefix-in view. "../../presentation/view.scm"))
(require (prefix-in line. "../../presentation/line.scm"))

(provide draw!)

(define (draw-line! frame current-line current-view row)
  (buffer/clear-with
    frame
    (area
      (view.content-x current-view)
      row
      (- (view.width current-view) 1)
      1)
    (style-bg (style) (line.line-background current-line)))
  (let loop
    ([remaining (line.line-runs current-line)]
      [column (view.content-x current-view)])
    (unless (null? remaining)
      (define run (car remaining))
      (define text (line.run-text run))
      (frame-set-string!
        frame
        column
        row
        text
        (line.run-style run))
      (loop (cdr remaining) (+ column (string-length text)))))
  (define rail (line.line-rail current-line))
  (frame-set-string!
    frame
    (view.rail-x current-view)
    row
    (line.run-text rail)
    (line.run-style rail)))

(define (draw! frame current-view)
  (let loop ([remaining (view.lines current-view)]
             [row (view.y current-view)])
    (unless (null? remaining)
      (draw-line! frame (car remaining) current-view row)
      (loop (cdr remaining) (+ row 1)))))
