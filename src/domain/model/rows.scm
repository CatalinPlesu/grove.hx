(require (prefix-in tree. "../tree.scm"))
(require (prefix-in git. "../git.scm"))
(require (prefix-in path. "../path.scm"))

(provide build
         row-id row-path row-kind row-label row-depth row-ancestor-ids
         row-expanded? row-git-status row-unsaved-status
         row-cursor? row-active-file?
         row-file? row-expandable? row-pressable?
         find at index-of visible?)

(struct row
  (id path kind label depth ancestor-ids expanded?
      git-status unsaved-status cursor? active-file?))
(define (row-file? row)
  (member (row-kind row) '(file file-link)))

(define (expandable-kind? kind)
  (member kind '(directory unreadable-directory)))

(define (row-expandable? row)
  (and
   (not (path.root-id? (row-id row)))
   (expandable-kind? (row-kind row))))

(define (row-pressable? row)
  (or (row-expandable? row) (row-file? row)))

(define (visible? id expanded)
  (let loop ([parent (path.parent-id id)])
    (or
     (not parent)
     (path.root-id? parent)
     (and
      (member parent expanded)
      (loop (path.parent-id parent))))))

(define (unsaved-status kind path unsaved-paths)
  (cond
    [(and (member kind '(file file-link))
          (member path unsaved-paths))
     'unsaved]
    [(member kind '(directory unreadable-directory directory-link))
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
                   active-path expanded cursor entry)
  (define id (tree.entry-id entry))
  (define kind (tree.entry-kind entry))
  (define absolute-path (path.path-for-id root id))
  (row
   id
   absolute-path
   kind
   (if (path.root-id? id) (path.basename root) (tree.entry-label entry))
   (tree.entry-depth entry)
   (path.ancestor-ids id)
   (or
    (path.root-id? id)
    (and (expandable-kind? kind) (member id expanded) #t))
   (entry-git-status git-status entry)
   (unsaved-status kind absolute-path unsaved-paths)
   (and cursor (string=? cursor id))
   (and active-path (string=? active-path absolute-path))))

(define (build root file-tree git-status unsaved-paths active-path expanded cursor)
  (let loop ([ordinal 0] [result '()])
    (define entry (tree.entry-at file-tree ordinal))
    (cond
      [(not entry) (reverse result)]
      [(visible? (tree.entry-id entry) expanded)
       (loop
        (+ ordinal 1)
        (cons
         (entry-row
          root git-status unsaved-paths
          active-path expanded cursor entry)
         result))]
      [else (loop (+ ordinal 1) result)])))

(define (find rows id)
  (let loop ([remaining rows])
    (and
     (pair? remaining)
     (if
      (string=? id (row-id (car remaining)))
      (car remaining)
      (loop (cdr remaining))))))

(define (at rows ordinal)
  (and
   (integer? ordinal)
   (>= ordinal 0)
   (< ordinal (length rows))
   (list-ref rows ordinal)))

(define (index-of rows id)
  (let loop ([remaining rows] [ordinal 0])
    (and
     (pair? remaining)
     (if
      (string=? id (row-id (car remaining)))
      ordinal
      (loop (cdr remaining) (+ ordinal 1))))))
