(require (prefix-in tree. "../domain/tree.scm"))
(require (prefix-in path. "../domain/path.scm"))
(require (prefix-in expansion. "../domain/expansion.scm"))

(provide scan)

(define (metadata-at path)
  (with-handler (lambda (_) #f) (file-metadata path)))

(define (directory-entries path)
  (with-handler
   (lambda (_) #f)
   (let loop ([iterator (read-dir-iter path)] [entries '()])
     (define entry (read-dir-iter-next! iterator))
     (if entry
         (loop iterator (cons entry entries))
         entries))))

(define (symlink-kind entry)
  (define metadata (metadata-at (read-dir-entry-path entry)))
  (cond
    [(not metadata) 'broken-link]
    [(fs-metadata-is-dir? metadata) 'directory-link]
    [(fs-metadata-is-file? metadata) 'file-link]
    [else 'broken-link]))

(define (scan-entry entry parent-id expansion-value)
  (define name (read-dir-entry-file-name entry))
  (define id (path.child-id parent-id name))
  (cond
    [(string=? name ".git")
     '()]
    [(read-dir-entry-is-symlink? entry)
     (list (tree.file-tree-entry id (symlink-kind entry)))]
    [(read-dir-entry-is-file? entry)
     (list (tree.file-tree-entry id 'file))]
    [(read-dir-entry-is-dir? entry)
     (define expanded?
       (expansion.contains? expansion-value id))
     (define descendants
       (and
        expanded?
        (scan-directory
         (read-dir-entry-path entry)
         id
         expansion-value)))
     (define kind
       (if
        (and expanded? (not descendants))
        'unreadable-directory
        'directory))
     (cons
      (tree.file-tree-entry id kind)
      (if descendants descendants '()))]
    [else
     '()]))

(define (scan-directory path parent-id expansion-value)
  (define entries (directory-entries path))
  (and
   entries
   (let loop ([remaining entries] [result '()])
     (if
      (null? remaining)
      result
      (loop
       (cdr remaining)
       (append
        (scan-entry (car remaining) parent-id expansion-value)
        result))))))

(define (scan root expansion-value)
  (define entries
    (scan-directory root path.root-id expansion-value))
  (if entries (tree.build entries) (tree.unreadable-root)))
