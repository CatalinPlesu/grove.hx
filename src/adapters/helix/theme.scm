(require "helix/components.scm")
(require (prefix-in line. "../../presentation/line.scm"))

(provide current-styles)

(define (color-channel color query)
  (and color (with-handler (lambda (_cause) #f) (query color))))

(define (linear-channel channel)
  (define value (/ channel 255.0))
  (if (<= value 0.04045)
    (/ value 12.92)
    (expt (/ (+ value 0.055) 1.055) 2.4)))

(define (color-luminance color)
  (define red (color-channel color Color-red))
  (define green (color-channel color Color-green))
  (define blue (color-channel color Color-blue))
  (and
    red
    green
    blue
    (+ (* 0.2126 (linear-channel red))
      (* 0.7152 (linear-channel green))
      (* 0.0722 (linear-channel blue)))))

(define (icon-palette-for background text)
  (define background-luminance
    (color-luminance (style->bg background)))
  (define text-luminance
    (color-luminance (style->fg text)))
  (cond
    [background-luminance
      (if (>= background-luminance 0.5) 'light 'dark)]
    [text-luminance
      (if (> text-luminance 0.179) 'dark 'light)]
    [else 'dark]))

(define (materialize-style style foreground-color background-color)
  (style-bg
    (style-fg style (or (style->fg style) foreground-color))
    (or (style->bg style) background-color)))

(define (glyph-style source foreground-color background-color)
  (style-bg (style-fg source foreground-color) background-color))

(define (current-styles icons? guides?)
  (define background-scope (theme-scope-ref "ui.background"))
  (define text-scope (theme-scope-ref "ui.text"))
  (define scroll-scope (theme-scope-ref "ui.menu.scroll"))
  (define ruler-scope (theme-scope-ref "ui.virtual.ruler"))
  (define guides-scope
    (theme-scope-ref "ui.virtual.indent-guide"))
  (define text-foreground-color
    (or (style->fg text-scope) Color/Reset))
  (define grove-background-color
    (or (style->bg background-scope) Color/Reset))
  (define rail-track-color
    (or (style->bg scroll-scope) grove-background-color))
  (define rail-thumb-color
    (or (style->fg scroll-scope) rail-track-color))
  (define background-style
    (materialize-style
      background-scope
      text-foreground-color
      grove-background-color))
  (define text-style
    (materialize-style
      text-scope
      text-foreground-color
      grove-background-color))
  (define pinned-style
    (style-bg
      text-style
      (or (style->bg ruler-scope) grove-background-color)))
  (define cursor-scope (theme-scope-ref "ui.menu.selected"))
  (define cursor-source
    (if (and (not (style->fg cursor-scope))
         (not (style->bg cursor-scope)))
      (style-with-reversed cursor-scope)
      cursor-scope))
  (define cursor-style
    (materialize-style
      cursor-source
      text-foreground-color
      grove-background-color))
  (define active-file-style
    (materialize-style
      (theme-scope-ref "ui.text.focus")
      text-foreground-color
      grove-background-color))
  (define rail-track-style
    (glyph-style
      scroll-scope
      rail-track-color
      grove-background-color))
  (define rail-thumb-style
    (glyph-style
      scroll-scope
      rail-thumb-color
      grove-background-color))
  (define (scope-foreground scope)
    (or
      (style->fg (theme-scope-ref scope))
      text-foreground-color))
  (line.styles
    #:background
    background-style
    #:text
    text-style
    #:cursor
    cursor-style
    #:active-file
    active-file-style
    #:pinned
    pinned-style
    #:rail-track
    rail-track-style
    #:rail-thumb
    rail-thumb-style
    #:guides
    (and
      guides?
      (let ([foreground (style->fg guides-scope)])
        (line.guides-style
          (or foreground text-foreground-color)
          (not foreground))))
    #:error
    (scope-foreground "error")
    #:deleted
    (scope-foreground "diff.minus")
    #:modified
    (scope-foreground "diff.delta")
    #:created
    (scope-foreground "diff.plus")
    #:unsaved
    (scope-foreground "info")
    #:icon-palette
    (and
      icons?
      (icon-palette-for background-scope text-scope))))
