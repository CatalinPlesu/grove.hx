(require "helix/components.scm")
(require "helix/misc.scm")
(require (prefix-in model. "../../domain/model.scm"))
(require (prefix-in view. "../../presentation/view.scm"))

(provide step
         result-rail-press result-message result-pass-through?)

(struct result (rail-press message pass-through?))

(define (message-result rail-press message [pass-through? #f])
  (result rail-press message pass-through?))

(define (handled-result rail-press)
  (result rail-press #f #f))

(define (ignored-result)
  (result #f #f #t))

(define (decode-mouse event)
  (define kind (event-mouse-kind event))
  (cond
    [(= kind 0) 'press]
    [(= kind 3) 'release]
    [(= kind 6) 'motion]
    [(= kind 10) 'wheel-down]
    [(= kind 11) 'wheel-up]
    [else #f]))

(define (decode-key event)
  (define character (key-event-char event))
  (define modifier (key-event-modifier event))
  (cond
    [(key-event-page-up? event) 'page-up]
    [(key-event-page-down? event) 'page-down]
    [(key-event-down? event) 'down]
    [(key-event-up? event) 'up]
    [(key-event-right? event) 'right]
    [(key-event-left? event) 'left]
    [(key-event-enter? event) 'enter]
    [(key-event-escape? event) 'escape]
    [(and (char? character) (char=? character #\j)) 'down]
    [(and (char? character) (char=? character #\k)) 'up]
    [(and (char? character) (char=? character #\l)) 'right]
    [(and (char? character) (char=? character #\h)) 'left]
    [(and
      modifier
      (= modifier key-modifier-ctrl)
      (char? character)
      (char=? character #\s))
     'horizontal-split]
    [(and
      modifier
      (= modifier key-modifier-ctrl)
      (char? character)
      (char=? character #\v))
     'vertical-split]
    [(and (char? character) (char=? character #\+)) 'width-increase]
    [(and (char? character) (char=? character #\-)) 'width-decrease]
    [else #f]))

(define (key-result current-pane event)
  (define key (decode-key event))
  (define height (view.height current-pane))
  (cond
   [(equal? key 'page-up)
    (message-result #f (model.cursor-move-requested (- height)))]
   [(equal? key 'page-down)
    (message-result #f (model.cursor-move-requested height))]
   [(equal? key 'up)
    (message-result #f (model.cursor-move-requested -1))]
   [(equal? key 'down)
    (message-result #f (model.cursor-move-requested 1))]
   [(equal? key 'width-increase)
    (message-result
     #f
     (model.resize-requested
      (view.width-after current-pane 1)))]
   [(equal? key 'width-decrease)
    (message-result
     #f
     (model.resize-requested
      (view.width-after current-pane -1)))]
   [(equal? key 'escape)
    (message-result #f (model.focus-released))]
   [(not key)
    (message-result #f (model.focus-released) #t)]
   [else (message-result #f (model.key-pressed key))]))

(define (result-for-pointer pointer-result)
  (define rail-press
    (view.pointer-result-rail-press pointer-result))
  (define effect (view.pointer-result-effect pointer-result))
  (cond
    [(view.pointer-row? effect)
     (message-result
      rail-press
      (model.row-pressed (view.pointer-row-id effect)))]
    [(view.pointer-outside? effect)
     (message-result rail-press (model.focus-released) #t)]
    [(view.pointer-resize? effect)
     (message-result
      rail-press
      (model.resize-requested
       (view.pointer-resize-width effect)))]
    [(view.pointer-scroll? effect)
     (message-result
      rail-press
      (model.scroll-requested
       (view.pointer-scroll-capacity effect)
       (view.pointer-scroll-mode effect)
       (view.pointer-scroll-amount effect)))]
    [(view.pointer-handled? effect) (handled-result rail-press)]
    [(view.pointer-ignored? effect) (ignored-result)]
    [else (error "unknown Pane Pointer effect")]))

(define (mouse-result rail-press current-pane event)
  (define kind (decode-mouse event))
  (define column (event-mouse-col event))
  (define row (event-mouse-row event))
  (cond
    [(member kind '(press release motion wheel-down wheel-up))
     (result-for-pointer
      (view.pointer current-pane rail-press kind column row))]
    [else (ignored-result)]))

(define (step rail-press focused? current-pane event)
  (if
   (not current-pane)
   (ignored-result)
   (cond
    [(mouse-event? event)
      (mouse-result rail-press current-pane event)]
     [(key-event? event)
      (if focused?
          (key-result current-pane event)
          (ignored-result))]
     [else (ignored-result)])))
