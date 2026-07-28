(require (prefix-in rows. "../domain/model/rows.scm"))

(provide shown-rows shown-row shown-row-pinned?)

(struct shown-row-value (row pinned?))

(define shown-row shown-row-value-row)
(define shown-row-pinned? shown-row-value-pinned?)

(define (ancestor-id-at row target-depth)
  (list-ref (rows.row-ancestor-ids row) target-depth))

(define (all-pinned? shown-rows)
  (or
   (null? shown-rows)
   (and
    (shown-row-pinned? (car shown-rows))
    (all-pinned? (cdr shown-rows)))))

(define (replace-final-row shown-rows row)
  (if
   (null? (cdr shown-rows))
   (list (shown-row-value row #f))
   (cons
    (car shown-rows)
    (replace-final-row (cdr shown-rows) row))))

(define (shown-rows visible-rows page-rows)
  (define result-rows
    (let loop ([remaining page-rows] [offset 0] [result '()])
      (if
       (null? remaining)
       (reverse result)
       (let* ([row (car remaining)]
              [depth (rows.row-depth row)]
              [pinned? (> depth offset)]
              [shown
               (if
                pinned?
                (rows.find visible-rows (ancestor-id-at row offset))
                row)])
         (loop
          (cdr remaining)
          (+ offset 1)
          (cons (shown-row-value shown pinned?) result))))))
  ; Keep the last screen row for real content when ancestors would fill every slot.
  (if
   (and (pair? result-rows) (all-pinned? result-rows))
   (replace-final-row result-rows (car (reverse page-rows)))
   result-rows))
