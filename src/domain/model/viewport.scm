(require (prefix-in rows. "rows.scm"))

(provide follow anchored? scroll
         page page-rows page-start page-total-rows)

(struct following-value (id))
(struct anchored-value (id fallback-start))
(struct page-value (rows start total-rows))

(define follow following-value)
(define anchored? anchored-value?)
(define page-rows page-value-rows)
(define page-start page-value-start)
(define page-total-rows page-value-total-rows)

(define (clamp value lower upper)
  (max lower (min upper value)))

(define (start-for visible-rows intent capacity)
  (define maximum-start (max 0 (- (length visible-rows) capacity)))
  (define requested-start
    (cond
      [(anchored-value? intent)
       (or
        (rows.index-of visible-rows (anchored-value-id intent))
        (anchored-value-fallback-start intent))]
      [(following-value? intent)
       (define position
         (and
          (following-value-id intent)
          (rows.index-of visible-rows (following-value-id intent))))
       (if
        (and (number? position) (> capacity 0) (>= position capacity))
        (+ 1 (- position capacity))
        0)]
      [else 0]))
  (clamp requested-start 0 maximum-start))

(define (page-slice visible-rows start-row capacity)
  (let loop ([rows visible-rows]
             [position 0]
             [remaining capacity]
             [result '()])
    (cond
      [(or (null? rows) (= remaining 0))
       (reverse result)]
      [(< position start-row)
       (loop (cdr rows) (+ position 1) remaining result)]
      [else
       (loop
        (cdr rows)
        (+ position 1)
        (- remaining 1)
        (cons (car rows) result))])))

(define (scroll intent visible-rows capacity mode amount)
  (unless
   (and
    (integer? capacity)
    (>= capacity 0)
    (member mode '(absolute relative))
    (integer? amount))
   (error "invalid viewport scroll"))
  (define current-start (start-for visible-rows intent capacity))
  (define target-start
    (clamp
     (if (equal? mode 'absolute) amount (+ current-start amount))
     0
     (max 0 (- (length visible-rows) capacity))))
  (define anchor-row
    (and
     (not (= target-start current-start))
     (rows.at visible-rows target-start)))
  (if
   anchor-row
   (anchored-value (rows.row-id anchor-row) target-start)
   intent))

(define (page visible-rows intent capacity)
  (unless (and (integer? capacity) (>= capacity 0))
    (error "invalid viewport capacity"))
  (define start-row (start-for visible-rows intent capacity))
  (page-value
   (page-slice visible-rows start-row capacity)
   start-row
   (length visible-rows)))
