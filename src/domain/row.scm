(require (prefix-in tree. "tree.scm"))
(require (prefix-in git. "git.scm"))
(require (prefix-in path. "path.scm"))
(require (prefix-in expansion. "expansion.scm"))

(provide facts
  label
  git-status
  unsaved-status
  active-file?
  cursor?
  expanded?)

(struct facts
  (root git-status unsaved-ids active-id cursor expansion))

(define (label current-facts entry)
  (define id (tree.entry-id entry))
  (path.basename
    (if (path.root-id? id) (facts-root current-facts) id)))

(define (git-status current-facts entry)
  (define kind (tree.entry-kind entry))
  (and
    (not (member kind '(unreadable-directory broken-link)))
    (git.status-for
      (facts-git-status current-facts)
      (tree.entry-id entry)
      (tree.directory-kind? kind))))

(define (unsaved-status current-facts entry)
  (define id (tree.entry-id entry))
  (define kind (tree.entry-kind entry))
  (define unsaved-ids (facts-unsaved-ids current-facts))
  (cond
    [(tree.file-kind? kind)
      (and (member id unsaved-ids) 'unsaved)]
    [(tree.directory-kind? kind)
      (and
        (findf
          (lambda (candidate) (path.id-inside? id candidate))
          unsaved-ids)
        'unsaved-ancestor)]
    [else #f]))

(define (active-file? current-facts entry)
  (equal? (facts-active-id current-facts) (tree.entry-id entry)))

(define (cursor? current-facts entry)
  (equal? (facts-cursor current-facts) (tree.entry-id entry)))

(define (expanded? current-facts entry)
  (define id (tree.entry-id entry))
  (or
    (path.root-id? id)
    (and
      (tree.expandable-kind? (tree.entry-kind entry))
      (expansion.contains? (facts-expansion current-facts) id))))
