(require (prefix-in tree. "tree.scm"))
(require (prefix-in git. "git.scm"))
(require (prefix-in path. "path.scm"))
(require (prefix-in expansion. "expansion.scm"))

(provide build workspace-row-id entry-row-id
  row-id
  row-relative-id
  row-path
  row-kind
  row-label
  row-depth
  row-ancestor-ids
  row-expanded?
  row-git-status
  row-unsaved-status
  row-cursor?
  row-file?
  row-expandable?
  row-pressable?
  find
  at
  index-of
  reconciled-id)

(struct workspace-row-id (root))
(struct entry-row-id (root relative-path))
(struct row
  (id relative-id path kind label depth ancestor-ids expanded?
    git-status
    unsaved-status
    cursor?))
(define (row-file? row)
  (tree.file-kind? (row-kind row)))

(define (row-expandable? row)
  (and
    (> (row-depth row) 0)
    (tree.expandable-kind? (row-kind row))))

(define (row-pressable? row)
  (or (row-expandable? row) (row-file? row)))

(define (visible? id expansion-value)
  (let loop ([parent (path.parent-id id)])
    (or
      (not parent)
      (path.root-id? parent)
      (and
        (expansion.contains? expansion-value parent)
        (loop (path.parent-id parent))))))

(define (unsaved-status kind path unsaved-paths)
  (cond
    [(and (tree.file-kind? kind)
        (member path unsaved-paths))
      'unsaved]
    [(tree.directory-kind? kind)
      (let loop ([remaining unsaved-paths])
        (cond
          [(null? remaining) #f]
          [(path.path-inside? path (car remaining)) 'unsaved-ancestor]
          [else (loop (cdr remaining))]))]
    [else #f]))

(define (entry-git-status git-status entry)
  (and
    (not
      (member
        (tree.entry-kind entry)
        '(unreadable-directory broken-link)))
    (git.status-for git-status
      (tree.entry-id entry)
      (tree.directory? entry))))

(define (entry-row root git-status unsaved-paths
         expansion-value
         cursor
         entry)
  (define relative-id (tree.entry-id entry))
  (define id
    (if
      (path.root-id? relative-id)
      (workspace-row-id root)
      (entry-row-id root relative-id)))
  (define kind (tree.entry-kind entry))
  (define absolute-path (path.path-for-id root relative-id))
  (row
    id
    relative-id
    absolute-path
    kind
    (if
      (path.root-id? relative-id)
      (path.basename root)
      (tree.entry-label entry))
    (tree.entry-depth entry)
    (map
      (lambda (ancestor-id)
        (if
          (path.root-id? ancestor-id)
          (workspace-row-id root)
          (entry-row-id root ancestor-id)))
      (path.ancestor-ids relative-id))
    (or
      (path.root-id? relative-id)
      (and
        (tree.expandable-kind? kind)
        (expansion.contains? expansion-value relative-id)))
    (entry-git-status git-status entry)
    (unsaved-status kind absolute-path unsaved-paths)
    (and cursor (equal? cursor id))))

(define (build root file-tree git-status unsaved-paths
         expansion-value
         cursor)
  (let loop ([remaining file-tree] [result '()])
    (cond
      [(null? remaining) (reverse result)]
      [(visible? (tree.entry-id (car remaining)) expansion-value)
        (loop
          (cdr remaining)
          (cons
            (entry-row
              root
              git-status
              unsaved-paths
              expansion-value
              cursor
              (car remaining))
            result))]
      [else (loop (cdr remaining) result)])))

(define (find rows id)
  (findf
    (lambda (row) (equal? id (row-id row)))
    rows))

(define (at rows ordinal)
  (and
    (integer? ordinal)
    (>= ordinal 0)
    (try-list-ref rows ordinal)))

(define (index-of rows id)
  (let loop ([remaining rows] [ordinal 0])
    (and
      (pair? remaining)
      (if
        (equal? id (row-id (car remaining)))
        ordinal
        (loop (cdr remaining) (+ ordinal 1))))))

(define (id-index rows)
  (let loop ([remaining rows] [result (hash)])
    (if
      (null? remaining)
      result
      (loop
        (cdr remaining)
        (hash-insert result (row-id (car remaining)) #t)))))

(define (first-indexed-id rows indexed)
  (define found
    (findf
      (lambda (row) (hash-contains? indexed (row-id row)))
      rows))
  (and found (row-id found)))

(define (reconciled-id old-rows new-rows id)
  (define indexed (id-index new-rows))
  (and
    id
    (let loop ([remaining old-rows] [before '()])
      (cond
        [(null? remaining) #f]
        [(equal? id (row-id (car remaining)))
          (or
            (first-indexed-id (cdr remaining) indexed)
            (first-indexed-id before indexed))]
        [else
          (loop (cdr remaining) (cons (car remaining) before))]))))
