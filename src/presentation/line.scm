(require "helix/components.scm")
(require (prefix-in rows. "../domain/rows.scm"))
(require (prefix-in layout. "../domain/layout.scm"))
(require (prefix-in devicons. "devicons/devicons.scm"))
(require (prefix-in theme. "theme.scm"))

(provide build line-background line-runs line-rail line-press-target
  run-text
  run-style)

(struct run (text style))
(struct line (background runs rail press-target))

(define (replace-control-characters text)
  (list->string
    (map (lambda (character)
          (define code (char->integer character))
          (if (or (< code 32) (= code 127)) #\? character))
      (string->list text))))

(define (error-icon-for-kind kind)
  (cond
    [(equal? kind 'unreadable-directory) "󰷌"]
    [(equal? kind 'broken-link) "󰌺"]
    [else #f]))

(define (ancestor-trace-indent depth)
  (cond
    [(<= depth 1) ""]
    [else
      (string-append "│ " (ancestor-trace-indent (- depth 1)))]))

(define (ancestry-indent row guides)
  (define depth (rows.row-depth row))
  (if
    guides
    (ancestor-trace-indent depth)
    (make-string (* 2 (max 0 (- depth 1))) #\space)))

(define (row-colors-for slot current-theme)
  (define row (layout.slot-row slot))
  (cond
    [(rows.row-cursor? row) (theme.resolved-theme-cursor current-theme)]
    [(layout.slot-pinned? slot)
      (theme.resolved-theme-pinned-ancestor-row current-theme)]
    [(rows.row-active-file? row)
      (theme.resolved-theme-active-file current-theme)]
    [else (theme.resolved-theme-visible-row current-theme)]))

(define (row-leading-runs row current-theme base-style)
  (define guides
    (theme.resolved-theme-guides-foreground current-theme))
  (define guides-style
    (if guides (style-fg base-style guides) base-style))
  (define active-file-foreground
    (theme.resolved-theme-active-file-mark-foreground current-theme))
  (define active-file-style
    (if
      active-file-foreground
      (style-fg base-style active-file-foreground)
      base-style))
  (append
    (list
      (run (if (rows.row-cursor? row) ">" " ") base-style)
      (run (ancestry-indent row guides) guides-style))
    (cond
      [(= (rows.row-depth row) 0) '()]
      [(rows.row-expandable? row)
        (list
          (run
            (if (rows.row-expanded? row) "▾" "▸")
            base-style))]
      [(rows.row-active-file? row) (list (run "*" active-file-style))]
      [else (list (run (if guides "·" " ") guides-style))])))

(define (fit-runs source-runs width base-style)
  (let loop ([remaining source-runs] [left width] [result '()])
    (cond
      [(= left 0) (reverse result)]
      [(null? remaining)
        (reverse (cons (run (make-string left #\space) base-style) result))]
      [else
        (define current (car remaining))
        (define text (run-text current))
        (define text-length (string-length text))
        (cond
          [(or
              (< text-length left)
              (and (= text-length left) (null? (cdr remaining))))
            (loop
              (cdr remaining)
              (- left text-length)
              (if (= text-length 0) result (cons current result)))]
          [else
            (reverse
              (cons
                (run
                  (if
                    (= left 1)
                    "…"
                    (string-append (substring text 0 (- left 1)) "…"))
                  (run-style current))
                result))])])))

(define (icon-area-runs row error-icon current-theme base-style)
  (define palette (theme.resolved-theme-icon-palette current-theme))
  (define icon
    (and
      palette
      (rows.row-file? row)
      (devicons.get_icon
        (rows.row-label row)
        #:variant
        palette)))
  (define icon-run
    (and
      palette
      (cond
        [icon
          (run
            (devicons.icon-glyph icon)
            (style-fg
              base-style
              (Color/rgb
                (devicons.icon-red icon)
                (devicons.icon-green icon)
                (devicons.icon-blue icon))))]
        [error-icon
          (run
            error-icon
            (style-fg
              base-style
              (theme.resolved-theme-filesystem-error-foreground
                current-theme)))]
        [(= (rows.row-depth row) 0)
          (run "󰙅" base-style)]
        [(member (rows.row-kind row) '(directory directory-link))
          (run
            (if (rows.row-expanded? row) "" "")
            base-style)]
        [else #f])))
  (if
    icon-run
    (if
      (= (rows.row-depth row) 0)
      (list icon-run (run " " base-style))
      (list (run " " base-style) icon-run (run " " base-style)))
    (if
      (= (rows.row-depth row) 0)
      '()
      (list (run " " base-style)))))

(define (row-runs slot width current-theme base-style)
  (define row (layout.slot-row slot))
  (define body-width (max 0 (- width 1)))
  (define error-icon (error-icon-for-kind (rows.row-kind row)))
  (define label-foreground
    (or
      (and
        error-icon
        (theme.resolved-theme-filesystem-error-foreground current-theme))
      (theme.git-foreground current-theme (rows.row-git-status row))))
  (define label-base
    (if
      label-foreground
      (style-fg base-style label-foreground)
      base-style))
  (define label-final
    (if
      (equal? (rows.row-git-status row) 'ignored)
      (style-with-dim label-base)
      label-base))
  (define unsaved-status (rows.row-unsaved-status row))
  (define body
    (fit-runs
      (append
        (row-leading-runs row current-theme base-style)
        (icon-area-runs row error-icon current-theme base-style)
        (list
          (run
            (replace-control-characters (rows.row-label row))
            label-final)))
      body-width
      base-style))
  (if
    (= width 0)
    body
    (append
      body
      (list
        (run
          (if unsaved-status "+" " ")
          (if
            unsaved-status
            (style-fg
              base-style
              (theme.resolved-theme-unsaved-mark-foreground current-theme))
            base-style))))))

(define (rail-glyph-for part side)
  (if
    (equal? part 'thumb)
    (if (equal? side 'left) "▐" "▌")
    (if (equal? side 'left) "▕" "▏")))

(define (build slot content-width side rail-part current-theme)
  (define appearance
    (and slot (row-colors-for slot current-theme)))
  (define line-background
    (if
      appearance
      (theme.row-colors-background appearance)
      (theme.resolved-theme-pane-background current-theme)))
  (define base-style
    (and
      appearance
      (style-fg (style) (theme.row-colors-foreground appearance))))
  (line
    line-background
    (if
      slot
      (row-runs slot content-width current-theme base-style)
      '())
    (run
      (rail-glyph-for rail-part side)
      (style-bg
        (style-fg
          (style)
          (if
            (equal? rail-part 'thumb)
            (theme.resolved-theme-rail-thumb current-theme)
            (theme.resolved-theme-rail-track current-theme)))
        (theme.resolved-theme-pane-background current-theme)))
    (and
      slot
      (not (layout.slot-pinned? slot))
      (rows.row-pressable? (layout.slot-row slot))
      (rows.row-id (layout.slot-row slot)))))
