(require (prefix-in path. "path.scm"))
(require (prefix-in natural. "natural.scm"))

(provide file-tree-entry entry-id entry-kind
         build unreadable-root
         find
         entry-depth entry-label
         file-kind? directory-kind? expandable-kind? directory?)

(struct file-tree-entry-value (id kind))

(define entry-id file-tree-entry-value-id)
(define entry-kind file-tree-entry-value-kind)

(define (valid-kind? kind)
  (and
   (member
    kind
    '(directory unreadable-directory file file-link
                directory-link broken-link))
   #t))

(define (file-kind? kind)
  (and (member kind '(file file-link)) #t))

(define (directory-kind? kind)
  (and
   (member kind '(directory unreadable-directory directory-link))
   #t))

(define (expandable-kind? kind)
  (and (member kind '(directory unreadable-directory)) #t))

(define (file-tree-entry id kind)
  (unless (and (path.valid-id? id) (valid-kind? kind))
    (error "invalid File tree entry"))
  (file-tree-entry-value id kind))

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
   (file-tree-entry path.root-id 'directory)
   (sort entries ordered-before?)))

(define (unreadable-root)
  (list
   (file-tree-entry path.root-id 'unreadable-directory)))

(define (find file-tree id)
  (findf
   (lambda (entry) (string=? id (entry-id entry)))
   file-tree))

(define (entry-depth entry)
  (if
   (path.root-id? (entry-id entry))
   0
   (length (split-many (entry-id entry) "/"))))

(define (entry-label entry)
  (path.basename (entry-id entry)))

(define (directory? entry)
  (directory-kind? (entry-kind entry)))
