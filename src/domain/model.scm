(require (prefix-in tree. "tree.scm"))
(require (prefix-in rows. "model/rows.scm"))
(require (prefix-in session. "model/session.scm"))

(provide init update
         root visible-rows width focused? viewport-intent
         host-observed focus-requested
         refresh-completed refresh-due
         unsaved-updated save-started focus-released
         key-pressed cursor-move-requested row-pressed
         scroll-requested resize-requested
         update-result-model update-result-command
         refresh-command? refresh-command-generation
         refresh-command-root refresh-command-expanded
         open-file-command? open-file-command-path open-file-command-mode)

(struct model-value
  (root tree git-status unsaved-paths active-path
        width session refresh-generation))

(struct host-observed (root active-path))
(struct focus-requested (root active-path))
(struct refresh-completed (generation tree git-status))
(struct refresh-due ())
(struct unsaved-updated (paths))
(struct save-started (path))
(struct focus-released ())
(struct key-pressed (key))
(struct cursor-move-requested (delta))
(struct row-pressed (id))
(struct scroll-requested (capacity mode amount))
(struct resize-requested (width))

(struct refresh-command (generation root expanded))
(struct open-file-command (path mode))
(struct update-result (model command))

(define root model-value-root)
(define width model-value-width)
(define (focused? model)
  (session.focused? (model-value-session model)))
(define (viewport-intent model)
  (session.viewport-intent (model-value-session model)))

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
                    #:width [width-value (model-value-width model)]
                    #:session [session-value (model-value-session model)]
                    #:generation
                    [generation (model-value-refresh-generation model)])
  (model-value
   root-value file-tree git-status unsaved-paths active-path
   width-value session-value generation))

(define (visible-rows model)
  (rows.build
   (model-value-root model)
   (model-value-tree model)
   (model-value-git-status model)
   (model-value-unsaved-paths model)
   (model-value-active-path model)
   (session.expanded (model-value-session model))
   (session.cursor (model-value-session model))))

(define (request-refresh model)
  (define generation
    (+ 1 (model-value-refresh-generation model)))
  (define next-model
    (copy-model model #:generation generation))
  (update-result
   next-model
   (refresh-command
    generation
    (model-value-root next-model)
    (session.expanded (model-value-session next-model)))))

(define (init root-value width-value active-path)
  (unless (valid-root? root-value)
    (error "invalid Workspace root"))
  (define file-tree (tree.build '()))
  (request-refresh
   (model-value
    root-value
    file-tree
    #f
    '()
    active-path
    width-value
    (session.start root-value active-path file-tree #f)
    0)))

(define (same-root? model candidate-root)
  (equal? candidate-root (model-value-root model)))

(define (apply-host-context model root-value active-path focus?)
  (unless (valid-root? root-value)
    (error "invalid Workspace root"))
  (define changed-root?
    (not (same-root? model root-value)))
  (define file-tree
    (if changed-root? (tree.build '()) (model-value-tree model)))
  (define prior-session (model-value-session model))
  (define next-session
    (if
     changed-root?
     (session.start root-value active-path file-tree focus?)
     (session.observe-host
      prior-session root-value file-tree active-path focus?)))
  (define updated-model
    (copy-model
     model
     #:root root-value
     #:tree file-tree
     #:git (if changed-root? #f (model-value-git-status model))
     #:active active-path
     #:session next-session))
  (if
   (or
    changed-root?
    (not
     (equal?
      (session.expanded next-session)
      (session.expanded prior-session))))
   (request-refresh updated-model)
   (update-result updated-model #f)))

(define (on-host-observed model root-value active-path)
  (if
   (and
    (same-root? model root-value)
    (equal? active-path (model-value-active-path model)))
   (update-result model #f)
   (apply-host-context model root-value active-path #f)))

(define (current-refresh? model generation)
  (= generation (model-value-refresh-generation model)))

(define (on-refresh-completed model generation file-tree git-status)
  (if
   (not (current-refresh? model generation))
   (update-result model #f)
   (update-result
    (copy-model
     model
     #:tree file-tree
     #:git git-status
     #:session
     (session.reconcile-cursor (model-value-session model) file-tree))
    #f)))

(define (on-unsaved-updated model paths)
  (if
   (equal? paths (model-value-unsaved-paths model))
   (update-result model #f)
   (update-result
    (copy-model model #:unsaved paths)
    #f)))

(define (without-path paths removed-path)
  (filter
   (lambda (candidate) (not (equal? candidate removed-path)))
   paths))

(define (on-save-started model path)
  (request-refresh
   (copy-model
    model
    #:unsaved
    (without-path (model-value-unsaved-paths model) path))))

(define (update-session model next-session)
  (if
   (equal? next-session (model-value-session model))
   (update-result model #f)
   (let ([next-model (copy-model model #:session next-session)])
     (if
      (equal?
       (session.expanded next-session)
       (session.expanded (model-value-session model)))
      (update-result next-model #f)
      (request-refresh next-model)))))

(define (cursor-row model)
  (define id (session.cursor (model-value-session model)))
  (and id (rows.find (visible-rows model) id)))

(define (activate-row model row mode)
  (cond
    [(not row)
     (update-result model #f)]
    [(rows.row-expandable? row)
     (update-session
      model
      (session.toggle-directory (model-value-session model) row))]
    [(rows.row-file? row)
     (update-result
      (copy-model
       model
       #:session (session.release-focus (model-value-session model)))
      (open-file-command (rows.row-path row) mode))]
    [else (update-result model #f)]))

(define (on-key-pressed model key)
  (cond
    [(equal? key 'right)
     (define row (cursor-row model))
     (if
      (and row (rows.row-expandable? row))
      (update-session
       model
       (session.expand-at-cursor (model-value-session model) row))
      (update-result model #f))]
    [(equal? key 'left)
     (update-session
      model
      (session.collapse-at-cursor (model-value-session model)))]
    [(member key '(enter horizontal-split vertical-split))
     (activate-row
      model
      (cursor-row model)
      (cond
        [(equal? key 'horizontal-split) 'horizontal-split]
        [(equal? key 'vertical-split) 'vertical-split]
        [else 'normal]))]
    [else (error "unknown Grove key")]))

(define (on-cursor-move-requested model delta)
  (update-session
   model
   (session.move-cursor
    (model-value-session model)
    (visible-rows model)
    delta)))

(define (on-scroll-requested model capacity mode amount)
  (update-session
   model
   (session.scroll
    (model-value-session model)
    (visible-rows model)
    capacity
    mode
    amount)))

(define (on-resize-requested model requested-width)
  (define resized-width
    (max MIN-WIDTH (min MAX-WIDTH requested-width)))
  (if
   (= resized-width (model-value-width model))
   (update-result model #f)
   (update-result
    (copy-model model #:width resized-width)
    #f)))

(define (release-focus model)
  (if
   (session.focused? (model-value-session model))
   (update-result
    (copy-model
     model
     #:session (session.release-focus (model-value-session model)))
    #f)
   (update-result model #f)))

(define (update model message)
  (cond
    [(host-observed? message)
     (on-host-observed
      model
      (host-observed-root message)
      (host-observed-active-path message))]
    [(focus-requested? message)
     (apply-host-context
      model
      (focus-requested-root message)
      (focus-requested-active-path message)
      #t)]
    [(refresh-completed? message)
     (on-refresh-completed
      model
      (refresh-completed-generation message)
      (refresh-completed-tree message)
      (refresh-completed-git-status message))]
    [(refresh-due? message)
     (request-refresh model)]
    [(unsaved-updated? message)
     (on-unsaved-updated model (unsaved-updated-paths message))]
    [(save-started? message)
     (on-save-started model (save-started-path message))]
    [(focus-released? message)
     (release-focus model)]
    [(key-pressed? message)
     (on-key-pressed model (key-pressed-key message))]
    [(cursor-move-requested? message)
     (on-cursor-move-requested
      model
      (cursor-move-requested-delta message))]
    [(row-pressed? message)
     (activate-row
      model
      (rows.find
       (visible-rows model)
       (row-pressed-id message))
      'normal)]
    [(scroll-requested? message)
     (on-scroll-requested
      model
      (scroll-requested-capacity message)
      (scroll-requested-mode message)
      (scroll-requested-amount message))]
    [(resize-requested? message)
     (on-resize-requested model (resize-requested-width message))]
    [else (error "unknown Model Message")]))
