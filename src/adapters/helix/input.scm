(require "helix/components.scm")
(require "helix/misc.scm")
(require (prefix-in model. "../../domain/model.scm"))
(require (prefix-in view. "../../presentation/view.scm"))

(provide init step
  result-state
  result-message
  result-pass-through?)

(struct idle ())
(struct track-press (root origin-x origin-y))
(struct thumb-press (root origin-x origin-y grab-offset))
(struct resize-drag (root))
(struct thumb-drag (root grab-offset))
(struct track-drag (root))
(struct result (state message pass-through?))

(define (init)
  (idle))

(define (consume state [message #f])
  (result state message #f))

(define (pass state [message #f])
  (result state message #t))

(define (decode-mouse event)
  (define kind (event-mouse-kind event))
  (cond
    [(= kind 0) 'press]
    [(= kind 3) 'release]
    [(= kind 6) 'motion]
    [(= kind 10) 'wheel-down]
    [(= kind 11) 'wheel-up]
    [else #f]))

(define (key-message event)
  (define character (key-event-char event))
  (define modifier (key-event-modifier event))
  (cond
    [(key-event-page-up? event)
      (model.cursor-move-requested 'previous-page)]
    [(key-event-page-down? event)
      (model.cursor-move-requested 'next-page)]
    [(or
        (key-event-down? event)
        (and (char? character) (char=? character #\j)))
      (model.cursor-move-requested 'next)]
    [(or
        (key-event-up? event)
        (and (char? character) (char=? character #\k)))
      (model.cursor-move-requested 'previous)]
    [(or
        (key-event-right? event)
        (and (char? character) (char=? character #\l)))
      (model.cursor-expansion-requested 'expand)]
    [(or
        (key-event-left? event)
        (and (char? character) (char=? character #\h)))
      (model.cursor-expansion-requested 'collapse)]
    [(key-event-enter? event)
      (model.cursor-open-requested 'normal)]
    [(key-event-escape? event)
      (model.focus-released)]
    [(and
        modifier
        (= modifier key-modifier-ctrl)
        (char? character)
        (char=? character #\s))
      (model.cursor-open-requested 'horizontal-split)]
    [(and
        modifier
        (= modifier key-modifier-ctrl)
        (char? character)
        (char=? character #\v))
      (model.cursor-open-requested 'vertical-split)]
    [(and (char? character) (char=? character #\+))
      (model.resize-by-requested 1)]
    [(and (char? character) (char=? character #\-))
      (model.resize-by-requested -1)]
    [else #f]))

(define (key-result current-model event)
  (define idle-state (init))
  (if
    (not (model.focused? current-model))
    (pass idle-state)
    (let ([message (key-message event)])
      (if
        message
        (consume idle-state message)
        (pass idle-state (model.focus-released))))))

(define (start-press current-model hit column row)
  (cond
    [(view.hit-row? hit)
      (consume
        (init)
        (model.row-pressed (view.hit-row-id hit)))]
    [(view.hit-rail? hit)
      (define grab-offset (view.hit-thumb-offset hit))
      (consume
        (if
          (integer? grab-offset)
          (thumb-press
            (model.root current-model)
            column
            row
            grab-offset)
          (track-press
            (model.root current-model)
            column
            row)))]
    [(view.hit-inside? hit)
      (consume (init))]
    [(model.focused? current-model)
      (pass (init) (model.focus-released))]
    [else
      (pass (init))]))

(define (pending-press? gesture)
  (or (track-press? gesture) (thumb-press? gesture)))

(define (gesture-root gesture)
  (cond
    [(track-press? gesture)
      (track-press-root gesture)]
    [(thumb-press? gesture)
      (thumb-press-root gesture)]
    [(resize-drag? gesture)
      (resize-drag-root gesture)]
    [(thumb-drag? gesture)
      (thumb-drag-root gesture)]
    [(track-drag? gesture)
      (track-drag-root gesture)]
    [else
      (error "invalid Rail gesture")]))

(define (press-origin-x gesture)
  (if
    (track-press? gesture)
    (track-press-origin-x gesture)
    (thumb-press-origin-x gesture)))

(define (press-origin-y gesture)
  (if
    (track-press? gesture)
    (track-press-origin-y gesture)
    (thumb-press-origin-y gesture)))

(define (chosen-axis gesture column row)
  (define dx (abs (- column (press-origin-x gesture))))
  (define dy (abs (- row (press-origin-y gesture))))
  (cond
    [(= dx dy) #f]
    [(> dx dy) 'horizontal]
    [else 'vertical]))

(define (resize-result state hit)
  (consume
    state
    (model.resize-to-requested
      (view.hit-resize-width hit))))

(define (scroll-result state hit grab-offset)
  (define offset (view.hit-scroll-offset hit grab-offset))
  (define limit (view.hit-scroll-limit hit))
  (if
    (and (integer? offset) (integer? limit))
    (consume
      state
      (model.scroll-to-requested offset limit))
    (consume state)))

(define (page-result state hit)
  (define amount (view.hit-page-amount hit))
  (if
    (integer? amount)
    (consume state (model.scroll-by-requested amount))
    (consume state)))

(define (state-after gesture release?)
  (if release? (init) gesture))

(define (continue-press gesture hit column row release?)
  (define axis (chosen-axis gesture column row))
  (define root (gesture-root gesture))
  (cond
    [(equal? axis 'horizontal)
      (resize-result
        (state-after (resize-drag root) release?)
        hit)]
    [(and
        (equal? axis 'vertical)
        (thumb-press? gesture))
      (define grab-offset (thumb-press-grab-offset gesture))
      (scroll-result
        (state-after (thumb-drag root grab-offset) release?)
        hit
        grab-offset)]
    [(equal? axis 'vertical)
      (consume
        (state-after (track-drag root) release?))]
    [(and
        release?
        (track-press? gesture)
        (= column (press-origin-x gesture))
        (= row (press-origin-y gesture)))
      (page-result (init) hit)]
    [else
      (consume
        (state-after gesture release?))]))

(define (continue-gesture gesture hit phase column row)
  (define release? (equal? phase 'release))
  (cond
    [(pending-press? gesture)
      (continue-press gesture hit column row release?)]
    [(resize-drag? gesture)
      (resize-result
        (state-after gesture release?)
        hit)]
    [(thumb-drag? gesture)
      (scroll-result
        (state-after gesture release?)
        hit
        (thumb-drag-grab-offset gesture))]
    [(track-drag? gesture)
      (consume
        (state-after gesture release?))]
    [else
      (error "invalid Rail gesture")]))

(define (mouse-result state current-model latest-view event)
  (define kind (decode-mouse event))
  (define column (event-mouse-col event))
  (define row (event-mouse-row event))
  (cond
    [(not kind)
      (pass state)]
    [(not latest-view)
      (pass (init))]
    [else
      (define hit (view.hit-test latest-view column row))
      (cond
        [(equal? kind 'press)
          (start-press current-model hit column row)]
        [(member kind '(wheel-up wheel-down))
          (if
            (view.hit-inside? hit)
            (consume
              (init)
              (model.scroll-by-requested
                (if (equal? kind 'wheel-down) 3 -3)))
            (pass (init)))]
        [(not (idle? state))
          (continue-gesture
            state
            hit
            kind
            column
            row)]
        [else
          (pass (init))])]))

(define (step state current-model latest-view event)
  (define current-state
    (if
      (or
        (idle? state)
        (equal? (gesture-root state) (model.root current-model)))
      state
      (init)))
  (cond
    [(mouse-event? event)
      (mouse-result current-state current-model latest-view event)]
    [(key-event? event)
      (key-result current-model event)]
    [else
      (pass current-state)]))
