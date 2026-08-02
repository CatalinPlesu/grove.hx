(require "helix/components.scm")
(require (prefix-in resolved. "../../presentation/theme.scm"))

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

(define (resolve-style sources role default-scope)
  (define source (cdr (assoc role sources)))
  (cond
    [(string? source) (theme-scope-ref source)]
    [source source]
    [else (theme-scope-ref default-scope)]))

(define (resolve sources icons? guides?)
  (define pane-source
    (resolve-style sources 'pane-background "ui.background"))
  (define pane-background
    (or (style->bg pane-source) Color/Reset))
  (define visible-source
    (resolve-style sources 'visible-row "ui.text"))
  (define visible-foreground
    (or (style->fg visible-source) Color/Reset))
  (define visible-background
    (or (style->bg visible-source) pane-background))
  (define rail-source
    (resolve-style sources 'rail "ui.menu.scroll"))
  (define (row role default-scope)
    (define source (resolve-style sources role default-scope))
    (resolved.row-colors
      (or (style->bg source) visible-background)
      (or (style->fg source) visible-foreground)))
  (define (foreground role default-scope fallback)
    (or (style->fg (resolve-style sources role default-scope)) fallback))

  (resolved.resolved-theme
    pane-background
    (resolved.row-colors visible-background visible-foreground)
    (row 'pinned-ancestor-row "ui.virtual.ruler")
    (row 'cursor "ui.text.focus")
    (and
      guides?
      (foreground
        'guides-foreground
        "ui.virtual.indent-guide"
        Color/Gray))
    (foreground 'active-file-mark-foreground "info" #f)
    (or (style->bg rail-source) Color/Reset)
    (or (style->fg rail-source) Color/Reset)
    (foreground 'filesystem-error-foreground "error" Color/LightRed)
    (foreground 'git-conflict-foreground "error" Color/Magenta)
    (foreground 'git-deleted-foreground "diff.minus" Color/Red)
    (foreground 'git-modified-foreground "diff.delta" Color/Yellow)
    (foreground 'git-created-foreground "diff.plus" Color/Green)
    (foreground 'unsaved-mark-foreground "info" Color/Cyan)
    (and
      icons?
      (icon-palette-for visible-background visible-foreground))))
