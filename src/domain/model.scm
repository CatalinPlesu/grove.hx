(require (prefix-in layout. "layout.scm"))
(require (prefix-in expansion. "expansion.scm"))
(require (prefix-in path. "path.scm"))
(require (prefix-in tree. "tree.scm"))
(require (prefix-in rows. "rows.scm"))

(provide init update
         root resolved-layout icons? focused?
         expansion
         observation-snapshot
         host-observed focus-frame-observed
         observation-received
         unsaved-observed save-started geometry-observed focus-released
         cursor-move-requested cursor-expansion-requested cursor-open-requested
         row-pressed
         scroll-by-requested scroll-to-requested
         resize-by-requested resize-to-requested
         update-result-model update-result-command
         refresh-command?
         open-file-command? open-file-command-path open-file-command-mode)

(struct model-value
  (root tree git-status unsaved-paths active-path
        expansion cursor anchor geometry width side icons?))

(struct observation-snapshot (root tree git-status active-path))
(struct host-observed (root active-path))
(struct focus-frame-observed (snapshot geometry))
(struct observation-received (snapshot))
(struct unsaved-observed (paths))
(struct save-started (path))
(struct geometry-observed (geometry))
(struct focus-released ())
(struct cursor-move-requested (direction))
(struct cursor-expansion-requested (action))
(struct cursor-open-requested (mode))
(struct row-pressed (id))
(struct scroll-by-requested (amount))
(struct scroll-to-requested (numerator denominator))
(struct resize-by-requested (amount))
(struct resize-to-requested (width))

(struct refresh-command ())
(struct open-file-command (path mode))
(struct update-result (model command))

(define root model-value-root)
(define icons? model-value-icons?)
(define expansion model-value-expansion)
(define (focused? model)
  (and (model-value-cursor model) #t))

(define MIN-WIDTH 16)
(define MAX-WIDTH 64)

(define (valid-root? value)
  (and
   (string? value)
   (> (string-length value) 0)
   (char=? (string-ref value 0) #\/)))

(define (copy-model model
                    #:root [root-value (model-value-root model)]
                    #:tree [file-tree (model-value-tree model)]
                    #:git [git-status (model-value-git-status model)]
                    #:unsaved [unsaved-paths (model-value-unsaved-paths model)]
                    #:active [active-path (model-value-active-path model)]
                    #:expansion
                    [expansion-value (model-value-expansion model)]
                    #:cursor [cursor-value (model-value-cursor model)]
                    #:anchor [anchor-value (model-value-anchor model)]
                    #:geometry [geometry-value (model-value-geometry model)]
                    #:width [width-value (model-value-width model)]
                    #:side [side-value (model-value-side model)]
                    #:icons [icons-value (model-value-icons? model)])
  (model-value
   root-value file-tree git-status unsaved-paths active-path
   expansion-value cursor-value anchor-value geometry-value
   width-value side-value icons-value))

(define (visible-rows model)
  (if
   (and (model-value-root model) (model-value-tree model))
   (rows.build
    (model-value-root model)
    (model-value-tree model)
    (model-value-git-status model)
    (model-value-unsaved-paths model)
    (model-value-active-path model)
    (model-value-expansion model)
    (model-value-cursor model))
   '()))

(define (root-row-id model)
  (and
   (model-value-root model)
   (rows.workspace-row-id (model-value-root model))))

(define (resolved-layout-for model current-rows)
  (layout.resolve
   current-rows
   (model-value-anchor model)
   (model-value-geometry model)
   (model-value-width model)
   (model-value-side model)))

(define (resolved-layout model)
  (resolved-layout-for model (visible-rows model)))

(define (request-refresh model)
  (update-result model (refresh-command)))

(define (init side-value width-value icons-value)
  (update-result
   (model-value
    #f #f #f '() #f
    (expansion.empty) #f #f #f
    width-value side-value icons-value)
   (refresh-command)))

(define (reconciled-anchor old-model new-model new-rows)
  (define old-anchor (model-value-anchor old-model))
  (cond
    [(and old-anchor (rows.find new-rows old-anchor))
     old-anchor]
    [else
     (define old-rows (visible-rows old-model))
     (or
      (rows.reconciled-id old-rows new-rows old-anchor)
      (root-row-id new-model))]))

(define (install-observation-snapshot model snapshot)
  (define root-value (observation-snapshot-root snapshot))
  (unless (valid-root? root-value)
    (error "invalid Workspace root"))
  (define changed-root?
    (not (equal? root-value (model-value-root model))))
  (define file-tree (observation-snapshot-tree snapshot))
  (define base
    (copy-model
     model
     #:root root-value
     #:tree file-tree
     #:git (observation-snapshot-git-status snapshot)
     #:active (observation-snapshot-active-path snapshot)
     #:expansion
     (if
      changed-root?
      (expansion.empty)
      (expansion.prune (model-value-expansion model) file-tree))
     #:cursor (if changed-root? #f (model-value-cursor model))))
  (define base-rows (visible-rows base))
  (define next-cursor
    (and
     (model-value-cursor base)
     (if
      (rows.find base-rows (model-value-cursor base))
      (model-value-cursor base)
      (root-row-id base))))
  (copy-model
   base
   #:cursor next-cursor
   #:anchor
   (if
    changed-root?
    (root-row-id base)
    (reconciled-anchor model base base-rows))))

(define (active-relative-id model)
  (and
   (model-value-root model)
   (path.id-for-path
    (model-value-root model)
    (model-value-active-path model))))

(define (activatable-active-id model)
  (define relative-id (active-relative-id model))
  (define entry
    (and
     relative-id
     (model-value-tree model)
     (tree.find (model-value-tree model) relative-id)))
  (and
   entry
   (tree.file-kind? (tree.entry-kind entry))
   relative-id))

(define (focus-model model)
  (define active-id (activatable-active-id model))
  (define focused-expansion
    (if
     active-id
     (expansion.expand-ancestors
      (model-value-expansion model)
      active-id)
     (model-value-expansion model)))
  (define expanded-model
    (copy-model model #:expansion focused-expansion))
  (define focused-layout (resolved-layout expanded-model))
  (if
   (not focused-layout)
   (copy-model model #:cursor #f)
   (let* ([target-id
           (if
            active-id
            (rows.entry-row-id
             (model-value-root model)
             active-id)
            (root-row-id model))]
          [next-anchor
           (layout.reveal focused-layout target-id 'first)])
     (copy-model
      expanded-model
      #:cursor target-id
      #:anchor next-anchor))))

(define (on-host-observed model root-value active-path)
  (unless (valid-root? root-value)
    (error "invalid Workspace root"))
  (cond
    [(not (equal? root-value (model-value-root model)))
     (request-refresh (copy-model model #:active active-path))]
    [(equal? active-path (model-value-active-path model))
     (update-result model #f)]
    [else
     (update-result (copy-model model #:active active-path) #f)]))

(define (on-unsaved-observed model paths)
  (if
   (equal? paths (model-value-unsaved-paths model))
   (update-result model #f)
   (update-result (copy-model model #:unsaved paths) #f)))

(define (without-path paths removed-path)
  (filter
   (lambda (candidate)
     (not (equal? candidate removed-path)))
   paths))

(define (on-save-started model file-path)
  (request-refresh
   (copy-model
    model
    #:unsaved
    (without-path (model-value-unsaved-paths model) file-path))))

(define (install-geometry model geometry-value)
  (if
   (equal? geometry-value (model-value-geometry model))
   model
   (let ([next-model
          (copy-model model #:geometry geometry-value)])
     (if
      (or
       (not (model-value-cursor next-model))
       (resolved-layout next-model))
      next-model
      (copy-model next-model #:cursor #f)))))

(define (clamp value lower upper)
  (max lower (min upper value)))

(define (cursor-target current-rows cursor delta)
  (define current-index
    (and cursor (rows.index-of current-rows cursor)))
  (and
   current-index
   (rows.at
    current-rows
    (clamp
     (+ current-index delta)
     0
     (max 0 (- (length current-rows) 1))))))

(define (on-cursor-move-requested model direction)
  (define current-rows (visible-rows model))
  (define current-layout (resolved-layout-for model current-rows))
  (if
   (not current-layout)
   (update-result model #f)
   (let* ([delta
           (cond
             [(equal? direction 'previous) -1]
             [(equal? direction 'next) 1]
             [(equal? direction 'previous-page)
              (- (layout.ordinary-capacity current-layout))]
             [(equal? direction 'next-page)
              (layout.ordinary-capacity current-layout)]
             [else (error "invalid Cursor movement")])]
          [target
           (cursor-target
            current-rows
            (model-value-cursor model)
            delta)])
     (if
      (not target)
      (update-result model #f)
      (let ([target-id (rows.row-id target)])
        (update-result
         (copy-model
          model
          #:cursor target-id
          #:anchor (layout.reveal current-layout target-id 'nearest))
         #f))))))

(define (reveal-cursor model current-layout)
  (if
   (and current-layout (model-value-cursor model))
   (copy-model
    model
    #:anchor
    (layout.reveal
     current-layout
     (model-value-cursor model)
     'nearest))
   model))

(define (current-cursor-row model current-rows)
  (and
   (model-value-cursor model)
   (rows.find current-rows (model-value-cursor model))))

(define (stored-id-below? current-rows stored-id directory-id)
  (define row (and stored-id (rows.find current-rows stored-id)))
  (and
   row
   (path.id-inside? directory-id (rows.row-relative-id row))))

(define (collapse-directory model current-rows row)
  (define directory-id (rows.row-relative-id row))
  (define directory-row-id (rows.row-id row))
  (define (id-after-collapse stored-id)
    (if
     (stored-id-below? current-rows stored-id directory-id)
     directory-row-id
     stored-id))
  (update-result
   (copy-model
    model
    #:expansion
    (expansion.collapse-subtree
     (model-value-expansion model)
     directory-id)
    #:cursor
    (id-after-collapse (model-value-cursor model))
    #:anchor
    (id-after-collapse (model-value-anchor model)))
   #f))

(define (expand-directory model row)
  (define directory-id (rows.row-relative-id row))
  (if
   (expansion.contains?
    (model-value-expansion model)
    directory-id)
   (update-result model #f)
   (request-refresh
    (copy-model
     model
     #:expansion
     (expansion.expand
      (model-value-expansion model)
      directory-id)))))

(define (toggle-directory model current-rows row)
  (if
   (expansion.contains?
    (model-value-expansion model)
    (rows.row-relative-id row))
   (collapse-directory model current-rows row)
   (expand-directory model row)))

(define (directory-action model current-rows row action)
  (if
   (not (and row (rows.row-expandable? row)))
   (update-result model #f)
   (cond
     [(equal? action 'expand)
      (expand-directory model row)]
     [(equal? action 'collapse)
      (collapse-directory model current-rows row)]
     [(equal? action 'toggle)
      (toggle-directory model current-rows row)]
     [else (error "invalid Cursor expansion action")])))

(define (activate-row model current-rows row mode)
  (cond
    [(not row)
     (update-result model #f)]
    [(rows.row-expandable? row)
     (toggle-directory model current-rows row)]
    [(rows.row-file? row)
     (update-result
      (copy-model model #:cursor #f)
      (open-file-command (rows.row-path row) mode))]
    [else
     (update-result model #f)]))

(define (on-cursor-expansion-requested model action)
  (define current-rows (visible-rows model))
  (define current-layout
    (resolved-layout-for model current-rows))
  (define revealed (reveal-cursor model current-layout))
  (directory-action
   revealed
   current-rows
   (current-cursor-row revealed current-rows)
   action))

(define (on-cursor-open-requested model mode)
  (define current-rows (visible-rows model))
  (define current-layout
    (resolved-layout-for model current-rows))
  (define revealed (reveal-cursor model current-layout))
  (activate-row
   revealed
   current-rows
   (current-cursor-row revealed current-rows)
   mode))

(define (on-scroll-by-requested model amount)
  (define current-layout (resolved-layout model))
  (if
   current-layout
   (update-result
    (copy-model
     model
     #:anchor (layout.scroll-by current-layout amount))
    #f)
   (update-result model #f)))

(define (on-scroll-to-requested model numerator denominator)
  (define current-layout (resolved-layout model))
  (if
   current-layout
   (update-result
    (copy-model
     model
     #:anchor (layout.scroll-to current-layout numerator denominator))
    #f)
   (update-result model #f)))

(define (host-width-limit model)
  (define current-geometry (model-value-geometry model))
  (and
   current-geometry
   (- (layout.geometry-width current-geometry) 1)))

(define (on-resize-requested model requested-width)
  (define host-limit (host-width-limit model))
  (define upper
    (if
     host-limit
     (min MAX-WIDTH (max MIN-WIDTH host-limit))
     MAX-WIDTH))
  (define next-width (clamp requested-width MIN-WIDTH upper))
  (if
   (= next-width (model-value-width model))
   (update-result model #f)
   (update-result (copy-model model #:width next-width) #f)))

(define (update model message)
  (cond
    [(host-observed? message)
     (on-host-observed
      model
      (host-observed-root message)
      (host-observed-active-path message))]
    [(focus-frame-observed? message)
     (update-result
      (focus-model
       (install-geometry
        (install-observation-snapshot
         model
         (focus-frame-observed-snapshot message))
        (focus-frame-observed-geometry message)))
      #f)]
    [(observation-received? message)
     (update-result
      (install-observation-snapshot
       model
       (observation-received-snapshot message))
      #f)]
    [(unsaved-observed? message)
     (on-unsaved-observed model (unsaved-observed-paths message))]
    [(save-started? message)
     (on-save-started model (save-started-path message))]
    [(geometry-observed? message)
     (update-result
      (install-geometry
       model
       (geometry-observed-geometry message))
      #f)]
    [(focus-released? message)
     (update-result (copy-model model #:cursor #f) #f)]
    [(cursor-move-requested? message)
     (on-cursor-move-requested
      model
      (cursor-move-requested-direction message))]
    [(cursor-expansion-requested? message)
     (on-cursor-expansion-requested
      model
      (cursor-expansion-requested-action message))]
    [(cursor-open-requested? message)
     (on-cursor-open-requested
      model
      (cursor-open-requested-mode message))]
    [(row-pressed? message)
     (define current-rows (visible-rows model))
     (activate-row
      model
      current-rows
      (rows.find current-rows (row-pressed-id message))
      'normal)]
    [(scroll-by-requested? message)
     (on-scroll-by-requested
      model
      (scroll-by-requested-amount message))]
    [(scroll-to-requested? message)
     (on-scroll-to-requested
      model
      (scroll-to-requested-numerator message)
      (scroll-to-requested-denominator message))]
    [(resize-by-requested? message)
     (on-resize-requested
      model
      (+ (model-value-width model)
         (resize-by-requested-amount message)))]
    [(resize-to-requested? message)
     (on-resize-requested
      model
      (resize-to-requested-width message))]
    [else
     (error "unknown Model Message")]))
