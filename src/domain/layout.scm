(require (prefix-in rows. "rows.scm"))

(provide geometry geometry-width
  resolve
  scroll-by
  scroll-to
  reveal
  x
  y
  width
  height
  side
  pane-slots
  ordinary-capacity
  slot-row
  slot-pinned?
  rail-x
  rail-part-at
  rail-thumb-offset
  rail-resize-width
  rail-scroll-offset
  rail-scroll-limit
  rail-page-amount)

(struct geometry-value (x y width height))
(struct slot-value (row pinned?))
(struct layout-value
  (rows geometry side width
    anchor
    pane-slots
    ordinary-rows
    ordinary-capacity
    start
    maximum-start
    total-rows))

(define geometry-x geometry-value-x)
(define geometry-y geometry-value-y)
(define geometry-width geometry-value-width)
(define geometry-height geometry-value-height)

(define width layout-value-width)
(define side layout-value-side)
(define pane-slots layout-value-pane-slots)
(define ordinary-capacity layout-value-ordinary-capacity)
(define slot-row slot-value-row)
(define slot-pinned? slot-value-pinned?)
(define maximum-start layout-value-maximum-start)

(define (x layout)
  (define host-geometry (layout-value-geometry layout))
  (if
    (equal? (side layout) 'right)
    (+ (geometry-x host-geometry)
      (- (geometry-width host-geometry) (width layout)))
    (geometry-x host-geometry)))

(define (y layout)
  (geometry-y (layout-value-geometry layout)))

(define (height layout)
  (geometry-height (layout-value-geometry layout)))

(define (maximum-width layout)
  (- (geometry-width (layout-value-geometry layout)) 1))

(define (geometry x y width height)
  (unless
    (and
      (integer? x)
      (>= x 0)
      (integer? y)
      (>= y 0)
      (integer? width)
      (>= width 0)
      (integer? height)
      (>= height 0))
    (error "invalid Host geometry"))
  (geometry-value x y width height))

(define (clamp value lower upper)
  (max lower (min upper value)))

(define (slice values start count)
  (take (list-drop values start) count))

; Keep slot construction and concatenation direct.
; ADR 0001 covers Steel JIT corruption.
(define (row-slots current-rows pinned?)
  (let loop ([remaining current-rows] [result '()])
    (if
      (null? remaining)
      (reverse result)
      (loop
        (cdr remaining)
        (cons
          (slot-value (car remaining) pinned?)
          result)))))

(define (prepend-all prefix suffix)
  (if
    (null? prefix)
    suffix
    (cons
      (car prefix)
      (prepend-all (cdr prefix) suffix))))

(define (ancestor-rows visible-rows anchor-row)
  (let loop ([ids (rows.row-ancestor-ids anchor-row)] [result '()])
    (if
      (null? ids)
      (reverse result)
      (let ([row (rows.find visible-rows (car ids))])
        (loop
          (cdr ids)
          (if row (cons row result) result))))))

(define (ancestor-stack-size row host-height)
  (define depth (rows.row-depth row))
  (if (< depth host-height) depth 0))

(define (bottom-start-index visible-rows total host-height)
  (define initial (max 0 (- total host-height)))
  (let loop ([candidate initial]
             [remaining-rows (list-drop visible-rows initial)])
    (define pinned
      (ancestor-stack-size (car remaining-rows) host-height))
    (if
      (<= (+ pinned (- total candidate)) host-height)
      candidate
      (loop
        (+ candidate 1)
        (cdr remaining-rows)))))

(define (resolve visible-rows anchor host-geometry requested-width side-value)
  (unless
    (and
      (list? visible-rows)
      (or (not host-geometry) (geometry-value? host-geometry))
      (integer? requested-width)
      (> requested-width 0)
      (member side-value '(left right)))
    (error "invalid Layout"))
  (and
    host-geometry
    (pair? visible-rows)
    (> (geometry-height host-geometry) 0)
    (>= (geometry-width host-geometry) (+ requested-width 1))
    (let* ([host-height (geometry-height host-geometry)]
           [total (length visible-rows)]
           [anchor-index
             (or
               (and anchor (rows.index-of visible-rows anchor))
               0)]
           [maximum-start
             (bottom-start-index visible-rows total host-height)]
           [start-index
             (min anchor-index maximum-start)]
           [anchor-row (rows.at visible-rows start-index)]
           [pinned
             (if
               (> (ancestor-stack-size anchor-row host-height) 0)
               (ancestor-rows visible-rows anchor-row)
               '())]
           [capacity (- host-height (length pinned))]
           [ordinary (slice visible-rows start-index capacity)]
           [slots
             (prepend-all
               (row-slots pinned #t)
               (row-slots ordinary #f))])
      (layout-value
        visible-rows
        host-geometry
        side-value
        requested-width
        (rows.row-id anchor-row)
        slots
        ordinary
        capacity
        start-index
        maximum-start
        total))))

(define (row-id-at visible-rows index)
  (rows.row-id (rows.at visible-rows index)))

(define (absolute-start layout numerator denominator)
  (quotient
    (+ (* numerator (maximum-start layout))
      (quotient denominator 2))
    denominator))

(define (scroll-by layout amount)
  (unless
    (and
      (layout-value? layout)
      (integer? amount))
    (error "invalid Layout scroll"))
  (define next-start
    (clamp
      (+ (layout-value-start layout) amount)
      0
      (maximum-start layout)))
  (row-id-at (layout-value-rows layout) next-start))

(define (scroll-to layout numerator denominator)
  (unless
    (and
      (layout-value? layout)
      (integer? numerator)
      (integer? denominator)
      (>= numerator 0)
      (> denominator 0)
      (<= numerator denominator))
    (error "invalid Layout scroll position"))
  (row-id-at
    (layout-value-rows layout)
    (clamp
      (absolute-start layout numerator denominator)
      0
      (maximum-start layout))))

(define (ordinary-row? layout id)
  (and
    (layout-value? layout)
    (rows.find (layout-value-ordinary-rows layout) id)
    #t))

(define (resolve-at layout candidate-index)
  (resolve
    (layout-value-rows layout)
    (row-id-at (layout-value-rows layout) candidate-index)
    (layout-value-geometry layout)
    (layout-value-width layout)
    (layout-value-side layout)))

(define (candidate-showing-target layout target-index initial-index)
  (define visible-rows (layout-value-rows layout))
  (define target-id (row-id-at visible-rows target-index))
  (let loop ([candidate initial-index])
    (define candidate-layout (resolve-at layout candidate))
    (cond
      [(ordinary-row? candidate-layout target-id)
        (layout-value-anchor candidate-layout)]
      [(>= candidate target-index)
        target-id]
      [else
        (loop (+ candidate 1))])))

(define (reveal layout id placement)
  (unless
    (and
      (layout-value? layout)
      (member placement '(nearest first)))
    (error "invalid Layout reveal"))
  (define target-index
    (rows.index-of (layout-value-rows layout) id))
  (cond
    [(not target-index)
      (layout-value-anchor layout)]
    [(ordinary-row? layout id)
      (layout-value-anchor layout)]
    [(equal? placement 'first)
      id]
    [(< target-index (layout-value-start layout))
      id]
    [else
      (candidate-showing-target
        layout
        target-index
        (max
          0
          (+ 1
            (- target-index
              (layout-value-ordinary-capacity layout)))))]))

(define (rail-x layout)
  (if
    (equal? (layout-value-side layout) 'right)
    (x layout)
    (+ (x layout) (width layout) -1)))

(define (thumb-height layout)
  (define total (layout-value-total-rows layout))
  (define pane-height (height layout))
  (and
    (> total pane-height)
    (max
      1
      (quotient
        (* pane-height pane-height)
        total))))

(define (thumb-y layout)
  (define current-height (thumb-height layout))
  (and
    current-height
    (let* ([travel (- (height layout) current-height)]
           [limit (maximum-start layout)]
           [offset
             (if
               (or (= travel 0) (= limit 0))
               0
               (quotient (* (layout-value-start layout) travel) limit))])
      (+ (y layout) offset))))

(define (rail-thumb-offset layout row)
  (define current-y (thumb-y layout))
  (define current-height
    (thumb-height layout))
  (and
    current-y
    (>= row current-y)
    (< row (+ current-y current-height))
    (- row current-y)))

(define (rail-part-at layout row)
  (and
    (>= row (y layout))
    (< row
      (+ (y layout)
        (height layout)))
    (if
      (integer? (rail-thumb-offset layout row))
      'thumb
      'track)))

(define (rail-resize-width layout column)
  (min
    (maximum-width layout)
    (if
      (equal? (layout-value-side layout) 'right)
      (-
        (+ (x layout)
          (width layout))
        column)
      (+ 1 (- column (x layout))))))

(define (rail-scroll-limit layout)
  (define current-height
    (thumb-height layout))
  (and
    current-height
    (let ([travel
            (max
              0
              (- (height layout)
                current-height))])
      (and (> travel 0) travel))))

(define (rail-page-amount layout row)
  (define current-y (thumb-y layout))
  (define current-height
    (thumb-height layout))
  (and
    current-y
    (cond
      [(< row current-y)
        (- (layout-value-ordinary-capacity layout))]
      [(>= row (+ current-y current-height))
        (layout-value-ordinary-capacity layout)]
      [else #f])))

(define (rail-scroll-offset layout row grab-offset)
  (define current-height
    (thumb-height layout))
  (define travel
    (rail-scroll-limit layout))
  (and
    current-height
    travel
    (let ([current-grab-offset
            (min grab-offset (- current-height 1))])
      (clamp
        (- (- row (y layout))
          current-grab-offset)
        0
        travel))))
