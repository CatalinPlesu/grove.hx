(provide row-colors
  row-colors-background
  row-colors-foreground
  resolved-theme
  resolved-theme-pane-background
  resolved-theme-visible-row
  resolved-theme-pinned-ancestor-row
  resolved-theme-cursor
  resolved-theme-guides-foreground
  resolved-theme-active-file-mark-foreground
  resolved-theme-rail-track
  resolved-theme-rail-thumb
  resolved-theme-filesystem-error-foreground
  resolved-theme-unsaved-mark-foreground
  resolved-theme-icon-palette
  git-foreground)

(struct row-colors (background foreground))

(struct resolved-theme
  (pane-background
    visible-row
    pinned-ancestor-row
    cursor
    guides-foreground
    active-file-mark-foreground
    rail-track
    rail-thumb
    filesystem-error-foreground
    git-conflict-foreground
    git-deleted-foreground
    git-modified-foreground
    git-created-foreground
    unsaved-mark-foreground
    icon-palette))

(define (git-foreground theme status)
  (cond
    [(equal? status 'conflict)
      (resolved-theme-git-conflict-foreground theme)]
    [(equal? status 'deleted)
      (resolved-theme-git-deleted-foreground theme)]
    [(equal? status 'modified)
      (resolved-theme-git-modified-foreground theme)]
    [(equal? status 'created)
      (resolved-theme-git-created-foreground theme)]
    [else #f]))
