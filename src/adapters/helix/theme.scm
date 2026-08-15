(require "helix/components.scm")

(provide resolve)

(define (color-brightness color)
  (and
    color
    (with-handler
      (lambda (_cause) #f)
      (+
        (* 299 (Color-red color))
        (* 587 (Color-green color))
        (* 114 (Color-blue color))))))

(define (icon-palette-for background foreground)
  (define background-brightness (color-brightness background))
  (define foreground-brightness (color-brightness foreground))
  (if
    (cond
      [background-brightness (>= background-brightness 187500)]
      [foreground-brightness (<= foreground-brightness 117000)]
      [else #f])
    'light
    'dark))

(define (resolve-color sources role default-scopes property fallback)
  (define source (cdr (assoc role sources)))
  (define candidates
    (if
      source
      (list (if (string? source) (theme-scope-ref source) source))
      (map theme-scope-ref default-scopes)))
  (define candidate (findf property candidates))
  (or (and candidate (property candidate)) fallback))

(define (resolve sources icons? guides?)
  (define (background role default-scopes fallback)
    (resolve-color sources role default-scopes style->bg fallback))
  (define (foreground role default-scopes fallback)
    (resolve-color sources role default-scopes style->fg fallback))
  (define pane-background
    (background 'pane-background '("ui.background") Color/Reset))
  (define visible-foreground
    (foreground 'visible-row '("ui.text") Color/Reset))
  (define visible-background
    (background 'visible-row '("ui.text") pane-background))
  (define (row role default-scopes)
    (cons
      (background role default-scopes visible-background)
      (foreground role default-scopes visible-foreground)))

  (hash
    'pane-background pane-background
    'visible-row (cons visible-background visible-foreground)
    'pinned-ancestor-row (row 'pinned-ancestor-row '("ui.virtual.ruler"))
    'cursor (row 'cursor '("ui.text.focus"))
    'active-file
    (cons
      (background
        'active-file-background
        (list "ui.bufferline.active" "ui.statusline.active")
        visible-background)
      visible-foreground)
    'guides-foreground
    (and
      guides?
      (foreground
        'guides-foreground
        '("ui.virtual.indent-guide" "ui.virtual.whitespace")
        Color/Gray))
    'active-file-mark-foreground
    (foreground 'active-file-mark-foreground '("info") #f)
    'rail-track (background 'rail '("ui.menu.scroll") Color/Reset)
    'rail-thumb (foreground 'rail '("ui.menu.scroll") Color/Reset)
    'filesystem-error-foreground
    (foreground
      'filesystem-error-foreground
      '("error")
      Color/LightRed)
    'conflict (foreground 'git-conflict-foreground '("error") Color/Magenta)
    'deleted (foreground 'git-deleted-foreground '("diff.minus") Color/Red)
    'modified (foreground 'git-modified-foreground '("diff.delta") Color/Yellow)
    'created (foreground 'git-created-foreground '("diff.plus") Color/Green)
    'unsaved-mark-foreground
    (foreground 'unsaved-mark-foreground '("info") Color/Cyan)
    'icon-palette
    (and
      icons?
      (icon-palette-for visible-background visible-foreground))))
