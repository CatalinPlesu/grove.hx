(require "helix/components.scm")
(require (prefix-in row. "../../domain/row.scm"))
(require (prefix-in tree. "../../domain/tree.scm"))
(require (prefix-in path. "../../domain/path.scm"))
(require (prefix-in layout. "../../domain/layout.scm"))
(require (prefix-in devicons. "devicons/devicons.scm"))

(provide draw!)

(struct run (text style))

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

(define (ancestry-indent entry guides)
  (define depth (path.depth (tree.entry-id entry)))
  (if
    guides
    (ancestor-trace-indent depth)
    (make-string (* 2 (max 0 (- depth 1))) #\space)))

(define (row-colors-for slot current-facts current-theme)
  (define entry (layout.slot-entry slot))
  (cond
    [(row.cursor? current-facts entry)
      (hash-ref current-theme 'cursor)]
    [(layout.slot-pinned? slot)
      (hash-ref current-theme 'pinned-ancestor-row)]
    [(row.active-file? current-facts entry)
      (hash-ref current-theme 'active-file)]
    [else (hash-ref current-theme 'visible-row)]))

(define (row-leading-runs entry current-facts current-theme base-style)
  (define guides
    (hash-ref current-theme 'guides-foreground))
  (define guides-style
    (if guides (style-fg base-style guides) base-style))
  (define active-file-foreground
    (hash-ref current-theme 'active-file-mark-foreground))
  (define active-file-style
    (if
      active-file-foreground
      (style-fg base-style active-file-foreground)
      base-style))
  (append
    (list
      (run (if (row.cursor? current-facts entry) ">" " ") base-style)
      (run (ancestry-indent entry guides) guides-style))
    (cond
      [(path.root-id? (tree.entry-id entry)) '()]
      [(tree.expandable? entry)
        (list
          (run
            (if (row.expanded? current-facts entry) "▾" "▸")
            base-style))]
      [(row.active-file? current-facts entry)
        (list (run "*" active-file-style))]
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

(define (icon-area-runs entry error-icon current-facts current-theme base-style)
  (define palette (hash-ref current-theme 'icon-palette))
  (define icon
    (and
      palette
      (tree.file-kind? (tree.entry-kind entry))
      (devicons.get_icon
        (row.label current-facts entry)
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
              (hash-ref current-theme 'filesystem-error-foreground)))]
        [(path.root-id? (tree.entry-id entry))
          (run "󰙅" base-style)]
        [(member (tree.entry-kind entry) '(directory directory-link))
          (run
            (if (row.expanded? current-facts entry) "" "")
            base-style)]
        [else #f])))
  (if
    icon-run
    (if
      (path.root-id? (tree.entry-id entry))
      (list icon-run (run " " base-style))
      (list (run " " base-style) icon-run (run " " base-style)))
    (if
      (path.root-id? (tree.entry-id entry))
      '()
      (list (run " " base-style)))))

(define (row-runs slot width current-facts current-theme base-style)
  (define entry (layout.slot-entry slot))
  (define body-width (max 0 (- width 1)))
  (define error-icon (error-icon-for-kind (tree.entry-kind entry)))
  (define git-status (row.git-status current-facts entry))
  (define label-foreground
    (or
      (and
        error-icon
        (hash-ref current-theme 'filesystem-error-foreground))
      (and
        (member git-status '(conflict deleted modified created))
        (hash-ref current-theme git-status))))
  (define label-base
    (if
      label-foreground
      (style-fg base-style label-foreground)
      base-style))
  (define label-final
    (if
      (equal? git-status 'ignored)
      (style-with-dim label-base)
      label-base))
  (define unsaved-status (row.unsaved-status current-facts entry))
  (define body
    (fit-runs
      (append
        (row-leading-runs entry current-facts current-theme base-style)
        (icon-area-runs
          entry error-icon current-facts current-theme base-style)
        (list
          (run
            (replace-control-characters (row.label current-facts entry))
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
              (hash-ref current-theme 'unsaved-mark-foreground))
            base-style))))))

(define (rail-glyph-for thumb? side)
  (if
    thumb?
    (if (equal? side 'left) "▐" "▌")
    (if (equal? side 'left) "▕" "▏")))

(define (content-x current-layout)
  (if
    (equal? (layout.side current-layout) 'right)
    (+ (layout.x current-layout) 1)
    (layout.x current-layout)))

(define (draw-runs! frame runs column row)
  (unless (null? runs)
    (define current (car runs))
    (define text (run-text current))
    (frame-set-string!
      frame column row text (run-style current))
    (draw-runs!
      frame
      (cdr runs)
      (+ column (string-length text))
      row)))

(define (draw-line! frame slot current-layout row current-facts current-theme)
  (define content-width (- (layout.width current-layout) 1))
  (define side (layout.side current-layout))
  (define thumb?
    (integer? (layout.rail-thumb-offset current-layout row)))
  (define appearance
    (and slot (row-colors-for slot current-facts current-theme)))
  (define line-background
    (if
      appearance
      (car appearance)
      (hash-ref current-theme 'pane-background)))
  (define base-style
    (and
      appearance
      (style-fg (style) (cdr appearance))))
  (buffer/clear-with
    frame
    (area (content-x current-layout) row content-width 1)
    (style-bg (style) line-background))
  (when slot
    (draw-runs!
      frame
      (row-runs slot content-width current-facts current-theme base-style)
      (content-x current-layout)
      row))
  (frame-set-string!
    frame
    (layout.rail-x current-layout)
    row
    (rail-glyph-for thumb? side)
    (style-bg
      (style-fg
        (style)
        (if
          thumb?
          (hash-ref current-theme 'rail-thumb)
          (hash-ref current-theme 'rail-track)))
      (hash-ref current-theme 'pane-background))))

(define (draw! frame current-layout current-facts current-theme)
  (let loop ([offset 0]
             [remaining (layout.pane-slots current-layout)])
    (unless (= offset (layout.height current-layout))
      (draw-line!
        frame
        (and (pair? remaining) (car remaining))
        current-layout
        (+ (layout.y current-layout) offset)
        current-facts
        current-theme)
      (loop
        (+ offset 1)
        (if (pair? remaining) (cdr remaining) '())))))
