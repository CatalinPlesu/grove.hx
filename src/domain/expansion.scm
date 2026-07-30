(require (prefix-in path. "path.scm"))
(require (prefix-in tree. "tree.scm"))

(provide empty contains?
  expand
  expand-ancestors
  collapse-subtree
  prune)

(struct expansion-value (paths))

(define (empty)
  (expansion-value '()))

(define paths expansion-value-paths)

(define (contains? expansion directory-id)
  (and (member directory-id (paths expansion)) #t))

(define (expand expansion directory-id)
  (if
    (or
      (path.root-id? directory-id)
      (contains? expansion directory-id))
    expansion
    (expansion-value (cons directory-id (paths expansion)))))

(define (expand-ancestors expansion entry-id)
  (let loop ([ids (path.ancestor-ids entry-id)] [result expansion])
    (if
      (null? ids)
      result
      (loop (cdr ids) (expand result (car ids))))))

(define (at-or-below? directory-id candidate-id)
  (or
    (string=? directory-id candidate-id)
    (path.id-inside? directory-id candidate-id)))

(define (collapse-subtree expansion directory-id)
  (expansion-value
    (filter
      (lambda (candidate)
        (not (at-or-below? directory-id candidate)))
      (paths expansion))))

(define (all-ancestors-expanded? expansion ids)
  (or
    (null? ids)
    (and
      (or
        (path.root-id? (car ids))
        (contains? expansion (car ids)))
      (all-ancestors-expanded? expansion (cdr ids)))))

(define (valid? file-tree expansion directory-id)
  (define entry (tree.find file-tree directory-id))
  (and
    entry
    (tree.expandable-kind? (tree.entry-kind entry))
    (all-ancestors-expanded?
      expansion
      (path.ancestor-ids directory-id))))

(define (prune expansion file-tree)
  (expansion-value
    (filter
      (lambda (directory-id)
        (valid? file-tree expansion directory-id))
      (paths expansion))))
