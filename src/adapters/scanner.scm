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

(define (scan-directory path parent-id expansion-value)
  (define entries (directory-entries path))
  (and
   entries
   (let loop ([remaining entries] [result '()])
     (if (null? remaining)
         result
         (let* ([entry (car remaining)]
                [name (read-dir-entry-file-name entry)])
           (cond
             [(string=? name ".git")
              (loop (cdr remaining) result)]
             [(read-dir-entry-is-symlink? entry)
              (define kind (symlink-kind entry))
              (loop
               (cdr remaining)
               (cons
                (tree.file-tree-entry
                 (path.child-id parent-id name) kind)
                result))]
             [(read-dir-entry-is-file? entry)
              (loop
               (cdr remaining)
               (cons
                (tree.file-tree-entry
                 (path.child-id parent-id name) 'file)
                result))]
             [(read-dir-entry-is-dir? entry)
              (define id (path.child-id parent-id name))
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
              (loop
               (cdr remaining)
               (append
                (if descendants descendants '())
                (cons (tree.file-tree-entry id kind) result)))]
             [else
              (loop (cdr remaining) result)]))))))

(define (scan root expansion-value)
  (define entries
    (scan-directory root path.root-id expansion-value))
  (if entries (tree.build entries) (tree.unreadable-root)))
