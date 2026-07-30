(require (prefix-in git. "../src/domain/git.scm"))
(require (prefix-in expansion. "../src/domain/expansion.scm"))
(require (prefix-in layout. "../src/domain/layout.scm"))
(require (prefix-in model. "../src/domain/model.scm"))
(require (prefix-in rows. "../src/domain/rows.scm"))
(require (prefix-in tree. "../src/domain/tree.scm"))

(define ROOT "/workspace")
(define GEOMETRY (layout.geometry 0 0 40 5))

(define (check name condition)
  (unless condition
    (error (string-append "Domain law failed: " name))))

(define (any? predicate values)
  (and
    (pair? values)
    (or
      (predicate (car values))
      (any? predicate (cdr values)))))

(define (file id)
  (tree.file-tree-entry id 'file))

(define (directory id)
  (tree.file-tree-entry id 'directory))

(check
  "File tree kind predicates return booleans"
  (and
    (equal? #t (tree.file-kind? 'file))
    (equal? #f (tree.file-kind? 'directory))
    (equal? #t (tree.directory-kind? 'directory-link))
    (equal? #f (tree.directory-kind? 'broken-link))
    (equal? #t (tree.expandable-kind? 'unreadable-directory))
    (equal? #f (tree.expandable-kind? 'directory-link))))

(define flat-tree
  (tree.build
    (list
      (file "item-00")
      (file "item-01")
      (file "item-02")
      (file "item-03")
      (file "item-04")
      (file "item-05")
      (file "item-06")
      (file "item-07")
      (file "item-08")
      (file "item-09")
      (file "item-10")
      (file "item-11"))))

(define flat-rows
  (rows.build
    ROOT
    flat-tree
    (git.build '())
    '()
    #f
    (expansion.empty)
    #f))

(define (resolve-flat anchor geometry)
  (layout.resolve flat-rows anchor geometry 16 'left))

(define root-id (rows.workspace-row-id ROOT))
(define item-02-id (rows.entry-row-id ROOT "item-02"))

(define (slot-signature current)
  (map
    (lambda (slot)
      (list
        (rows.row-id (layout.slot-row slot))
        (layout.slot-pinned? slot)))
    (layout.pane-slots current)))

(define top (resolve-flat root-id GEOMETRY))

(define middle (resolve-flat item-02-id GEOMETRY))
(define down-anchor (layout.scroll-by middle 1))
(define down (resolve-flat down-anchor GEOMETRY))
(define restored
  (resolve-flat (layout.scroll-by down -1) GEOMETRY))
(check
  "one row down and up restores the middle"
  (equal? (slot-signature middle) (slot-signature restored)))

(define bottom-anchor (layout.scroll-to top 1 1))
(define bottom (resolve-flat bottom-anchor GEOMETRY))
(check
  "bottom has no avoidable blank rows"
  (and
    (= (length (layout.pane-slots bottom)) (layout.height bottom))
    (not
      (any? layout.slot-pinned? (layout.pane-slots bottom)))))

(check
  "absolute Rail movement reaches both ends"
  (and
    (equal? root-id (layout.scroll-to middle 0 1))
    (equal? bottom-anchor (layout.scroll-to middle 1 1))))

(define missing
  (resolve-flat
    (rows.entry-row-id ROOT "missing")
    GEOMETRY))
(check
  "a missing anchor falls back to the Workspace root"
  (equal?
    (rows.row-id
      (layout.slot-row
        (car (layout.pane-slots missing))))
    root-id))

(define nested-tree
  (tree.build
    (list
      (directory "outer")
      (directory "outer/inner")
      (file "outer/inner/file-00")
      (file "outer/inner/file-01")
      (file "outer/inner/file-02")
      (file "outer/inner/file-03")
      (file "tail-00")
      (file "tail-01")
      (file "tail-02"))))

(define nested-rows
  (rows.build
    ROOT
    nested-tree
    (git.build '())
    '()
    #f
    (expansion.expand
      (expansion.expand (expansion.empty) "outer")
      "outer/inner")
    #f))

(define nested-target
  (rows.entry-row-id ROOT "outer/inner/file-00"))

(define (pinned-count height)
  (length
    (filter
      layout.slot-pinned?
      (layout.pane-slots
        (layout.resolve
          nested-rows
          nested-target
          (layout.geometry 0 0 40 height)
          16
          'left)))))

(check
  "the Ancestor stack is complete or absent"
  (let loop ([height 1])
    (or
      (> height 8)
      (and
        (member (pinned-count height) '(0 3))
        (loop (+ height 1))))))

(define initial-model
  (model.update-result-model (model.init 'left 16 #t)))

(define (updated model-value message)
  (model.update-result-model
    (model.update model-value message)))

(define nested-snapshot
  (model.observation-snapshot
    ROOT
    nested-tree
    (git.build '())
    "/workspace/outer/inner/file-00"))

(define (focus-frame model-value snapshot)
  (updated
    model-value
    (model.focus-frame-observed snapshot GEOMETRY)))

(define expanded-model
  (focus-frame initial-model nested-snapshot))

(define bottom-model
  (updated
    (updated expanded-model (model.focus-released))
    (model.scroll-to-requested 1 1)))

(check
  "the focus law starts with its Active file outside Layout"
  (not
    (any?
      (lambda (slot)
        (equal?
          nested-target
          (rows.row-id (layout.slot-row slot))))
      (layout.pane-slots (model.resolved-layout bottom-model)))))

(define focused-model
  (focus-frame bottom-model nested-snapshot))

(define unavailable-focused-model
  (updated
    initial-model
    (model.focus-frame-observed
      nested-snapshot
      (layout.geometry 0 0 16 5))))

(check
  "an unavailable Pane does not expand Active file ancestors"
  (not
    (expansion.contains?
      (model.expansion unavailable-focused-model)
      "outer")))

(define focused-layout (model.resolved-layout focused-model))
(define focused-cursor-slots
  (filter
    (lambda (slot)
      (and
        (not (layout.slot-pinned? slot))
        (rows.row-cursor? (layout.slot-row slot))))
    (layout.pane-slots focused-layout)))

(check
  "the focus transaction returns a Layout containing one ordinary Cursor row"
  (and
    (= 1 (length focused-cursor-slots))
    (equal?
      nested-target
      (rows.row-id
        (layout.slot-row (car focused-cursor-slots))))))

(define (ordinary-slot? current-layout id)
  (any?
    (lambda (slot)
      (and
        (not (layout.slot-pinned? slot))
        (equal? id (rows.row-id (layout.slot-row slot)))))
    (layout.pane-slots current-layout)))

(define (all? predicate values)
  (or
    (null? values)
    (and
      (predicate (car values))
      (all? predicate (cdr values)))))

(define (every-reveal-is-visible? placement)
  (let height-loop ([height 1])
    (or
      (> height 8)
      (and
        (all?
          (lambda (anchor-row)
            (define initial
              (layout.resolve
                nested-rows
                (rows.row-id anchor-row)
                (layout.geometry 0 0 40 height)
                16
                'left))
            (all?
              (lambda (target-row)
                (define target-id (rows.row-id target-row))
                (define revealed
                  (layout.resolve
                    nested-rows
                    (layout.reveal initial target-id placement)
                    (layout.geometry 0 0 40 height)
                    16
                    'left))
                (ordinary-slot? revealed target-id))
              nested-rows))
          nested-rows)
        (height-loop (+ height 1))))))

(check
  "every revealed row is an ordinary Pane row"
  (and
    (every-reveal-is-visible? 'first)
    (every-reveal-is-visible? 'nearest)))
