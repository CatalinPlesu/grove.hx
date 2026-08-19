(require (prefix-in path. "path.scm"))
(require (prefix-in natural. "natural.scm"))

(provide entry entry-id entry-kind
  build
  unreadable-root
  find
  index-of
  file-kind?
  directory-kind?
  expandable-kind?
  expandable?)

(struct entry (id kind))

(define (file-kind? kind)
  (and (member kind '(file file-link)) #t))

(define (directory-kind? kind)
  (and
    (member kind '(directory unreadable-directory directory-link))
    #t))

(define (expandable-kind? kind)
  (and (member kind '(directory unreadable-directory)) #t))

(define (expandable? entry)
  (and
    (not (path.root-id? (entry-id entry)))
    (expandable-kind? (entry-kind entry))))

(define (entry-rank entry final?)
  (if
    (not final?)
    0
    (cond
      [(directory-kind? (entry-kind entry))
        0]
      [(file-kind? (entry-kind entry)) 1]
      [else 2])))

(define (ordered-before? left right)
  (let loop ([left-path (split-many (entry-id left) "/")]
             [right-path (split-many (entry-id right) "/")])
    (cond
      [(null? left-path) (pair? right-path)]
      [(null? right-path) #f]
      [(string=? (car left-path) (car right-path))
        (loop (cdr left-path) (cdr right-path))]
      [else
        (define left-rank (entry-rank left (null? (cdr left-path))))
        (define right-rank (entry-rank right (null? (cdr right-path))))
        (cond
          [(< left-rank right-rank) #t]
          [(> left-rank right-rank) #f]
          [else
            (natural.before? (car left-path) (car right-path))])])))

(define (build entries)
  (cons
    (entry path.root-id 'directory)
    (sort entries ordered-before?)))

(define (unreadable-root)
  (list
    (entry path.root-id 'unreadable-directory)))

(define (find file-tree id)
  (findf
    (lambda (entry) (string=? id (entry-id entry)))
    file-tree))

(define (index-of entries id)
  (let loop ([remaining entries] [ordinal 0])
    (and
      (pair? remaining)
      (if
        (string=? id (entry-id (car remaining)))
        ordinal
        (loop (cdr remaining) (+ ordinal 1))))))
