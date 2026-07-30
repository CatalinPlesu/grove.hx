(require (prefix-in rows. "../domain/rows.scm"))
(require (prefix-in layout. "../domain/layout.scm"))
(require (prefix-in devicons. "devicons/devicons.scm"))

(provide styles build
         run-text run-style run-icon-color run-foreground run-dim?
         color-red color-green color-blue)

(struct styles-value
  (background text cursor active-file pinned
              rail-track rail-thumb error-foreground deleted-foreground
              modified-foreground created-foreground unsaved-foreground
              icon-palette))
(struct color (red green blue))
(struct run (text style icon-color foreground dim?))

(define (styles #:background background
                #:text text
                #:cursor cursor
                #:active-file active-file
                #:pinned pinned
                #:rail-track rail-track
                #:rail-thumb rail-thumb
                #:error error-foreground
                #:deleted deleted-foreground
                #:modified modified-foreground
                #:created created-foreground
                #:unsaved unsaved-foreground
                #:icon-palette icon-palette)
  (styles-value
   background text cursor active-file pinned
   rail-track rail-thumb
   error-foreground deleted-foreground
   modified-foreground created-foreground unsaved-foreground
   icon-palette))

(define (spaces count)
  (if (<= count 0) "" (make-string count #\space)))

(define (replace-control-characters text)
  (list->string
   (map (lambda (character)
          (define code (char->integer character))
          (if (or (< code 32) (= code 127)) #\? character))
        (string->list text))))

(define (file-icon row styles)
  (define palette (styles-value-icon-palette styles))
  (and
   palette
   (or (equal? (rows.row-kind row) 'file)
       (equal? (rows.row-kind row) 'file-link))
   (devicons.get_icon
    (rows.row-label row)
    #:variant palette)))

(define (error-icon-for-kind kind)
  (cond
    [(equal? kind 'unreadable-directory) "󰷌"]
    [(equal? kind 'broken-link) "󰌺"]
    [else #f]))

(define (row-indent row)
  (spaces (max 0 (- (* 2 (rows.row-depth row)) 1))))

(define (git-foreground row styles)
  (define status (rows.row-git-status row))
  (cond
    [(equal? status 'conflict)
     (styles-value-error-foreground styles)]
    [(equal? status 'deleted)
     (styles-value-deleted-foreground styles)]
    [(equal? status 'modified)
     (styles-value-modified-foreground styles)]
    [(equal? status 'created)
     (styles-value-created-foreground styles)]
    [else #f]))

(define (base-style row styles pinned?)
  (cond
    [(rows.row-cursor? row) (styles-value-cursor styles)]
    [(rows.row-active-file? row) (styles-value-active-file styles)]
    [pinned? (styles-value-pinned styles)]
    [else (styles-value-text styles)]))

(define (make-run text style [icon-color #f] [foreground #f] [dim? #f])
  (run text style icon-color foreground dim?))

(define (run-with-text source text)
  (make-run
   text
   (run-style source)
   (run-icon-color source)
   (run-foreground source)
   (run-dim? source)))

(define (fit-runs runs width style)
  (let loop ([remaining runs] [left width] [result '()])
    (cond
      [(= left 0) (reverse result)]
      [(null? remaining)
       (reverse (cons (make-run (spaces left) style) result))]
      [else
       (define current (car remaining))
       (define text (run-text current))
       (define length (string-length text))
       (cond
         [(or
           (< length left)
           (and (= length left) (null? (cdr remaining))))
          (loop
           (cdr remaining)
           (- left length)
           (if (= length 0) result (cons current result)))]
         [else
          (reverse
           (cons
            (run-with-text
             current
             (if
              (= left 1)
              "…"
              (string-append (substring text 0 (- left 1)) "…")))
            result))])])))

(define (icon-color icon)
  (and
   icon
   (color
    (devicons.icon-red icon)
    (devicons.icon-green icon)
    (devicons.icon-blue icon))))

(define (indicator-runs row icon styles style)
  (define kind (rows.row-kind row))
  (define icons? (styles-value-icon-palette styles))
  (define triangle (if (rows.row-expanded? row) "▾" "▸"))
  (define error-color (styles-value-error-foreground styles))
  (cond
    [icon
     (list
      (make-run
       (devicons.icon-glyph icon)
       style
       (and (not (rows.row-cursor? row)) (icon-color icon))))]
    [(and (= (rows.row-depth row) 0)
          (equal? kind 'unreadable-directory))
     (if
      icons?
      (list
       (make-run " " style)
       (make-run (error-icon-for-kind kind) style #f error-color))
      '())]
    [(= (rows.row-depth row) 0)
     (if icons? (list (make-run " 󰙅" style)) '())]
    [(equal? kind 'unreadable-directory)
     (append
      (list (make-run triangle style))
      (if
       icons?
       (list
        (make-run " " style)
        (make-run (error-icon-for-kind kind) style #f error-color))
       '()))]
    [(equal? kind 'broken-link)
     (list
      (if
       icons?
       (make-run (error-icon-for-kind kind) style #f error-color)
       (make-run " " style)))]
    [(equal? kind 'directory-link)
     (list (make-run (if icons? "  " " ") style))]
    [(not (equal? kind 'directory))
     (list (make-run " " style))]
    [else
     (list
      (make-run
       (if
        icons?
        (string-append
         triangle " "
         (if (rows.row-expanded? row) "" ""))
        triangle)
       style))]))

(define (row-runs slot width styles)
  (define row (layout.slot-row slot))
  (define pinned? (layout.slot-pinned? slot))
  (define body-width (max 0 (- width 1)))
  (define style (base-style row styles pinned?))
  (define kind (rows.row-kind row))
  (define icon (file-icon row styles))
  (define leading
    (string-append
     (row-indent row)
     (if
      (and
       (styles-value-icon-palette styles)
       (member kind '(file file-link broken-link)))
      "  "
      "")))
  (define error-icon (error-icon-for-kind kind))
  (define label-foreground
    (if
     error-icon
     (styles-value-error-foreground styles)
     (git-foreground row styles)))
  (define label-dim?
    (equal? (rows.row-git-status row) 'ignored))
  (define body
    (fit-runs
     (append
      (list (make-run leading style))
      (indicator-runs row icon styles style)
      (list
       (make-run " " style)
       (make-run
        (replace-control-characters (rows.row-label row))
        style
        #f
        label-foreground
        label-dim?)))
     body-width
     style))
  (if
   (= width 0)
   body
   (append
    body
    (list
     (make-run
      (if (rows.row-unsaved-status row) "●" " ")
      style
      #f
      (and
       (rows.row-unsaved-status row)
       (styles-value-unsaved-foreground styles)))))))

(define (rail-track-glyph side)
  (if (equal? side 'left) "▕" "▏"))

(define (rail-thumb-glyph side)
  (if (equal? side 'left) "▐" "▌"))

(define (rail-run part side styles)
  (make-run
   (if
    (equal? part 'thumb)
    (rail-thumb-glyph side)
    (rail-track-glyph side))
   (if
    (equal? part 'thumb)
    (styles-value-rail-thumb styles)
    (styles-value-rail-track styles))))

(define (build slot content-width side rail-part styles)
  (define content
    (if
     slot
     (row-runs slot content-width styles)
     (list
      (make-run
       (spaces content-width)
       (styles-value-background styles)))))
  (define rail-run-value (rail-run rail-part side styles))
  (if
   (equal? side 'right)
   (cons rail-run-value content)
   (append content (list rail-run-value))))
