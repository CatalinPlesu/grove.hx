(require (prefix-in model. "../domain/model.scm"))
(require (prefix-in rows. "../domain/model/rows.scm"))
(require (prefix-in viewport. "../domain/model/viewport.scm"))
(require (prefix-in ancestor. "ancestor.scm"))
(require (prefix-in line. "line.scm"))
(require (prefix-in rail. "rail.scm"))

(provide geometry build lines line-runs
         pointer
         pointer-result-rail-press pointer-result-effect
         pointer-row? pointer-row-id
         pointer-outside? pointer-resize? pointer-resize-width
         pointer-scroll? pointer-scroll-capacity pointer-scroll-mode pointer-scroll-amount
         pointer-handled? pointer-ignored?
         height x y width
         width-after)

(struct geometry-value (x y width height))
(struct pane-value (x y width height side lines rail))
(struct line-value (runs target))
(struct pointer-result (rail-press effect))
(struct pointer-row (id))
(struct pointer-resize (width))
(struct pointer-scroll (capacity mode amount))

(define x pane-value-x)
(define y pane-value-y)
(define width pane-value-width)
(define height pane-value-height)
(define side pane-value-side)
(define lines pane-value-lines)
(define line-runs line-value-runs)
(define (pointer-outside? effect) (equal? effect 'outside))
(define (pointer-handled? effect) (equal? effect 'handled))
(define (pointer-ignored? effect) (equal? effect 'ignored))

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
   (error "invalid terminal geometry"))
  (geometry-value x y width height))

(define (pressable-row-id shown-row)
  (and
   shown-row
   (let ([row (ancestor.shown-row shown-row)])
     (and
      (rows.row-pressable? row)
      (not (ancestor.shown-row-pinned? shown-row))
      (rows.row-id row)))))

(define (build-lines shown-rows rail y height content-width side styles)
  (let loop ([offset 0] [remaining shown-rows] [result '()])
    (if
     (= offset height)
     (reverse result)
     (let* ([shown-row (and (pair? remaining) (car remaining))]
            [rest (if (pair? remaining) (cdr remaining) '())])
       (loop
        (+ offset 1)
        rest
        (cons
         (line-value
          (line.build
           shown-row
           content-width
           side
           (rail.part-at rail (+ y offset))
           styles)
          (pressable-row-id shown-row))
         result))))))

(define (build-pane terminal-geometry requested-width side
                    shown-rows total-rows start-row styles)
  (unless
   (and
    (integer? requested-width)
    (> requested-width 0)
    (member side '(left right))
    (list? shown-rows)
    (<= (length shown-rows) (geometry-value-height terminal-geometry))
    (integer? total-rows)
    (integer? start-row))
   (error "invalid Pane"))
  (define terminal-x (geometry-value-x terminal-geometry))
  (define terminal-y (geometry-value-y terminal-geometry))
  (define terminal-width (geometry-value-width terminal-geometry))
  (define terminal-height (geometry-value-height terminal-geometry))
  (if
   (< terminal-width (+ requested-width 1))
   #f
   (let* ([max-width (- terminal-width 1)]
          [pane-x
           (if
            (equal? side 'right)
            (+ terminal-x (- terminal-width requested-width))
            terminal-x)]
          [rail
           (rail.build
            pane-x terminal-y requested-width max-width terminal-height
            side total-rows start-row)])
     (pane-value
      pane-x
      terminal-y
      requested-width
      terminal-height
      side
      (build-lines
       shown-rows
       rail
       terminal-y
       terminal-height
       (- requested-width 1)
       side
       styles)
      rail))))

(define (build current-model side terminal-geometry styles)
  (define visible-rows (model.visible-rows current-model))
  (define page
    (viewport.page
     visible-rows
     (model.viewport-intent current-model)
     (geometry-value-height terminal-geometry)))
  (build-pane
   terminal-geometry
   (model.width current-model)
   side
   (ancestor.shown-rows visible-rows (viewport.page-rows page))
   (viewport.page-total-rows page)
   (viewport.page-start page)
   styles))

(define (contains? pane column row)
  (and
   (>= column (x pane))
   (< column (+ (x pane) (width pane)))
   (>= row (y pane))
   (< row (+ (y pane) (height pane)))))

(define (content-width pane)
  (- (width pane) 1))

(define (content-x pane)
  (if
   (equal? (side pane) 'right)
   (+ (x pane) 1)
   (x pane)))

(define (pressed-row-id pane column row)
  (define offset (- row (y pane)))
  (define pane-lines (lines pane))
  (define content-start (content-x pane))
  (and
   (>= column content-start)
   (< column (+ content-start (content-width pane)))
   (>= offset 0)
   (< offset (length pane-lines))
   (line-value-target (list-ref pane-lines offset))))

(define (width-after pane delta)
  (rail.adjust-width (pane-value-rail pane) delta))

(define (rail-pointer-result pane rail-result)
  (define rail-press (rail.pointer-result-press rail-result))
  (define effect (rail.pointer-result-effect rail-result))
  (cond
    [(equal? effect 'handled)
     (pointer-result rail-press 'handled)]
    [(rail.resize-effect? effect)
     (pointer-result
      rail-press
      (pointer-resize (rail.resize-effect-width effect)))]
    [(rail.scroll-effect? effect)
     (pointer-result
      rail-press
      (pointer-scroll
       (height pane)
       (rail.scroll-effect-mode effect)
       (rail.scroll-effect-amount effect)))]
    [else (error "unknown Rail effect")]))

(define (handle-press pane column row)
  (define rail-result
    (rail.pointer
     (pane-value-rail pane)
     #f
     'press
     column
     row))
  (define row-id (pressed-row-id pane column row))
  (cond
    [rail-result (rail-pointer-result pane rail-result)]
    [row-id
     (pointer-result #f (pointer-row row-id))]
    [(contains? pane column row) (pointer-result #f 'handled)]
    [else (pointer-result #f 'outside)]))

(define (continue-rail-press pane rail-press phase column row)
  (rail-pointer-result
   pane
   (rail.pointer
    (pane-value-rail pane)
    rail-press
    phase
    column
    row)))

(define (pointer pane rail-press phase column row)
  (unless
   (and
    (pane-value? pane)
    (or (not rail-press) (rail.press? rail-press))
    (member phase '(press release motion wheel-up wheel-down))
    (integer? column)
    (integer? row))
   (error "invalid Pane Pointer"))
  (cond
    [(member phase '(wheel-up wheel-down))
     (pointer-result
      #f
      (if
       (contains? pane column row)
       (pointer-scroll
        (height pane)
        'relative
        (if (equal? phase 'wheel-down) 3 -3))
       'ignored))]
    [(equal? phase 'press) (handle-press pane column row)]
    [rail-press
     (continue-rail-press pane rail-press phase column row)]
    [else (pointer-result #f 'ignored)]))
