(require (prefix-in tree. "../tree.scm"))
(require (prefix-in path. "../path.scm"))
(require (prefix-in rows. "rows.scm"))
(require (prefix-in viewport. "viewport.scm"))

(provide start observe-host reconcile-cursor
         focused? expanded cursor viewport-intent
         release-focus move-cursor expand-at-cursor collapse-at-cursor toggle-directory
         scroll)

(struct session-value (expanded cursor viewport))

(define (focused? session)
  (and (session-value-cursor session) #t))
(define expanded session-value-expanded)
(define cursor session-value-cursor)
(define viewport-intent session-value-viewport)

(define (copy-session session
                      #:expanded [expanded (session-value-expanded session)]
                      #:cursor [cursor (session-value-cursor session)]
                      #:viewport [viewport (session-value-viewport session)])
  (session-value expanded cursor viewport))

(define (add-expanded expanded id)
  (if (member id expanded) expanded (cons id expanded)))

(define (remove-expanded expanded id)
  (filter
   (lambda (candidate) (not (string=? id candidate)))
   expanded))

(define (expanded? expanded id)
  (and (member id expanded) #t))

(define (expanded-for-path root path)
  (define id (path.id-for-path root path))
  (let loop ([parent (and id (path.parent-id id))] [expanded '()])
    (if
     (or (not parent) (path.root-id? parent))
     expanded
     (loop
      (path.parent-id parent)
      (add-expanded expanded parent)))))

(define (visible-id? file-tree expanded id)
  (and
   (path.valid-id? id)
   (tree.find file-tree id)
   (rows.visible? id expanded)
   #t))

(define (start root active-path file-tree focused?)
  (define next-expanded (expanded-for-path root active-path))
  (define active-id (path.id-for-path root active-path))
  (define next-cursor
    (and
     focused?
     (if
      (and active-id (visible-id? file-tree next-expanded active-id))
      active-id
      path.root-id)))
  (session-value
   next-expanded
   next-cursor
   (viewport.follow (if focused? next-cursor active-id))))

(define (observe-host session root file-tree active-path focus-requested?)
  (define revealed-ancestors (expanded-for-path root active-path))
  (define next-expanded
    (let loop ([remaining revealed-ancestors]
               [result (session-value-expanded session)])
      (if
       (null? remaining)
       result
       (loop
        (cdr remaining)
        (add-expanded result (car remaining))))))
  (define active-id (path.id-for-path root active-path))
  (define next-cursor
    (if
     focus-requested?
     (if
      (and active-id (visible-id? file-tree next-expanded active-id))
      active-id
      path.root-id)
     (session-value-cursor session)))
  (define next-viewport
    (if
     (or
      focus-requested?
      (not (viewport.anchored? (session-value-viewport session))))
     (viewport.follow (if focus-requested? next-cursor active-id))
     (session-value-viewport session)))
  (session-value next-expanded next-cursor next-viewport))

(define (reconcile-cursor session file-tree)
  (define current-cursor (session-value-cursor session))
  (copy-session
   session
   #:cursor
   (and
    current-cursor
    (if
     (and
      (visible-id? file-tree (session-value-expanded session) current-cursor))
     current-cursor
     path.root-id))))

(define (release-focus session)
  (copy-session session #:cursor #f))

(define (clamp value lower upper)
  (max lower (min upper value)))

(define (move-to-row session cursor)
  (copy-session
   session
   #:cursor cursor
   #:viewport (viewport.follow cursor)))

(define (move-cursor session visible-rows delta)
  (define current-index
    (or (and (session-value-cursor session)
             (rows.index-of visible-rows (session-value-cursor session)))
        0))
  (define target-row
    (rows.at
     visible-rows
     (clamp
      (+ current-index delta)
      0
      (max 0 (- (length visible-rows) 1)))))
  (if
   (and
    target-row
    (not
     (and
      (session-value-cursor session)
      (string=? (session-value-cursor session) (rows.row-id target-row)))))
   (move-to-row session (rows.row-id target-row))
   session))

(define (replace-expansion session expanded)
  (copy-session
   session
   #:expanded expanded
   #:viewport (viewport.follow (session-value-cursor session))))

(define (expand-at-cursor session row)
  (define id (and row (rows.row-id row)))
  (if
   (and
    id
    (rows.row-expandable? row)
    (not (expanded? (session-value-expanded session) id)))
   (replace-expansion
    session
    (add-expanded (session-value-expanded session) id))
   session))

(define (collapse-at-cursor session)
  (define current-cursor (session-value-cursor session))
  (if
   (and
    current-cursor
    (expanded? (session-value-expanded session) current-cursor))
   (replace-expansion
    session
    (remove-expanded (session-value-expanded session) current-cursor))
   session))

(define (toggle-directory session row)
  (define id (and row (rows.row-id row)))
  (if
   (and id (rows.row-expandable? row))
   (replace-expansion
    session
    (if
     (expanded? (session-value-expanded session) id)
     (remove-expanded (session-value-expanded session) id)
     (add-expanded (session-value-expanded session) id)))
   session))

(define (scroll session visible-rows capacity mode amount)
  (copy-session
   session
   #:viewport
   (viewport.scroll
    (session-value-viewport session)
    visible-rows capacity mode amount)))
