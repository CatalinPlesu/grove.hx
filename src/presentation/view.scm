(require (prefix-in layout. "../domain/layout.scm"))
(require (prefix-in line. "line.scm"))

(provide build lines
  y
  width
  content-x
  rail-x
  hit-test
  hit-row?
  hit-row-id
  hit-rail?
  hit-inside?
  hit-thumb-offset
  hit-resize-width
  hit-scroll-offset
  hit-scroll-limit
  hit-page-amount)

(struct view-value (layout lines))
(struct hit-value (kind row-id layout column row))

(define lines view-value-lines)

(define (x view)
  (layout.x (view-value-layout view)))

(define (y view)
  (layout.y (view-value-layout view)))

(define (width view)
  (layout.width (view-value-layout view)))

(define (content-x view)
  (if
    (equal? (layout.side (view-value-layout view)) 'right)
    (+ (x view) 1)
    (x view)))

(define (rail-x view)
  (layout.rail-x (view-value-layout view)))

(define (build-lines current-layout current-theme)
  (let loop ([offset 0]
             [remaining (layout.pane-slots current-layout)]
             [result '()])
    (if
      (= offset (layout.height current-layout))
      (reverse result)
      (let* ([slot (and (pair? remaining) (car remaining))]
             [rest (if (pair? remaining) (cdr remaining) '())]
             [row (+ (layout.y current-layout) offset)])
        (loop
          (+ offset 1)
          rest
          (cons
            (line.build
              slot
              (- (layout.width current-layout) 1)
              (layout.side current-layout)
              (layout.rail-part-at current-layout row)
              current-theme)
            result))))))

(define (build current-layout current-theme)
  (and
    current-layout
    (view-value
      current-layout
      (build-lines current-layout current-theme))))

(define (inside? view column row)
  (and
    (>= column (x view))
    (< column (+ (x view) (width view)))
    (>= row (y view))
    (< row (+ (y view) (layout.height (view-value-layout view))))))

(define (hit-test view column row)
  (unless
    (and
      (view-value? view)
      (integer? column)
      (integer? row))
    (error "invalid View hit test"))
  (define current-layout (view-value-layout view))
  (cond
    [(not (inside? view column row))
      (hit-value 'outside #f current-layout column row)]
    [(= column (layout.rail-x current-layout))
      (hit-value 'rail #f current-layout column row)]
    [else
      (define current-line
        (list-ref (lines view) (- row (y view))))
      (define row-id (line.line-press-target current-line))
      (hit-value
        (if row-id 'row 'inside)
        row-id
        current-layout
        column
        row)]))

(define (hit-row? hit)
  (equal? (hit-value-kind hit) 'row))

(define (hit-row-id hit)
  (and (hit-row? hit) (hit-value-row-id hit)))

(define (hit-rail? hit)
  (equal? (hit-value-kind hit) 'rail))

(define (hit-inside? hit)
  (not (equal? (hit-value-kind hit) 'outside)))

(define (hit-thumb-offset hit)
  (and
    (hit-rail? hit)
    (layout.rail-thumb-offset
      (hit-value-layout hit)
      (hit-value-row hit))))

(define (hit-resize-width hit)
  (layout.rail-resize-width
    (hit-value-layout hit)
    (hit-value-column hit)))

(define (hit-scroll-offset hit grab-offset)
  (layout.rail-scroll-offset
    (hit-value-layout hit)
    (hit-value-row hit)
    grab-offset))

(define (hit-scroll-limit hit)
  (layout.rail-scroll-limit
    (hit-value-layout hit)))

(define (hit-page-amount hit)
  (layout.rail-page-amount
    (hit-value-layout hit)
    (hit-value-row hit)))
