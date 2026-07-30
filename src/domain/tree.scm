(require (prefix-in path. "path.scm"))
(require (prefix-in natural. "natural.scm"))

(provide file-tree-entry entry-id entry-kind
         build unreadable-root
         find entry-at
         entry-depth entry-label
         file-kind? directory-kind? expandable-kind? directory?)

(struct file-tree-entry-value (id kind))
(struct file-tree-value (entries))

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
  (file-tree-value
   (list->vector
    (cons
     (file-tree-entry path.root-id 'directory)
     (sort entries ordered-before?)))))

(define (unreadable-root)
  (file-tree-value
   (vector
    (file-tree-entry path.root-id 'unreadable-directory))))

(define (entry-count file-tree)
  (vector-length (file-tree-value-entries file-tree)))

(define (entry-at file-tree ordinal)
  (and
   (integer? ordinal)
   (>= ordinal 0)
   (< ordinal (entry-count file-tree))
   (vector-ref (file-tree-value-entries file-tree) ordinal)))

(define (find file-tree id)
  (let loop ([ordinal 0])
    (define entry (entry-at file-tree ordinal))
    (and
     entry
     (if
      (string=? id (entry-id entry))
      entry
      (loop (+ ordinal 1))))))

(define (entry-depth entry)
  (if
   (path.root-id? (entry-id entry))
   0
   (let loop ([characters (string->list (entry-id entry))] [depth 1])
     (if
      (null? characters)
      depth
      (loop
       (cdr characters)
       (if (char=? (car characters) #\/) (+ depth 1) depth))))))

(define (entry-label entry)
  (path.basename (entry-id entry)))

(define (directory? entry)
  (directory-kind? (entry-kind entry)))
