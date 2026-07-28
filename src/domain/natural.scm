(provide before?)

(define (ascii-digit? character)
  (define code (char->integer character))
  (and (>= code 48) (<= code 57)))

(define (digit-run-end text index)
  (if
   (and
    (< index (string-length text))
    (ascii-digit? (string-ref text index)))
   (digit-run-end text (+ index 1))
   index))

(define (nonzero-run-start text start end)
  (if
   (and
    (< start (- end 1))
    (char=? (string-ref text start) #\0))
   (nonzero-run-start text (+ start 1) end)
   start))

(define (natural-before? left right)
  (define folded-left (string-foldcase left))
  (define folded-right (string-foldcase right))
  (let loop ([left-index 0] [right-index 0])
    (cond
      [(= left-index (string-length folded-left))
       (< right-index (string-length folded-right))]
      [(= right-index (string-length folded-right)) #f]
      [else
       (define left-character (string-ref folded-left left-index))
       (define right-character (string-ref folded-right right-index))
       (define left-digit? (ascii-digit? left-character))
       (define right-digit? (ascii-digit? right-character))
       (cond
         [(and left-digit? right-digit?)
          (define left-end (digit-run-end folded-left left-index))
          (define right-end (digit-run-end folded-right right-index))
          (define left-start
            (nonzero-run-start folded-left left-index left-end))
          (define right-start
            (nonzero-run-start folded-right right-index right-end))
          (define left-length (- left-end left-start))
          (define right-length (- right-end right-start))
          (define left-digits (substring folded-left left-start left-end))
          (define right-digits (substring folded-right right-start right-end))
          ; Compare without integer conversion so arbitrarily long digit runs still work.
          (cond
            [(< left-length right-length) #t]
            [(> left-length right-length) #f]
            [(string<? left-digits right-digits) #t]
            [(string<? right-digits left-digits) #f]
            [(< (- left-end left-index) (- right-end right-index)) #t]
            [(> (- left-end left-index) (- right-end right-index)) #f]
            [else (loop left-end right-end)])]
         [left-digit? #t]
         [right-digit? #f]
         [(string<? (string left-character) (string right-character)) #t]
         [(string<? (string right-character) (string left-character)) #f]
         [else (loop (+ left-index 1) (+ right-index 1))])])))

(define (before? left right)
  (cond
    [(natural-before? left right) #t]
    [(natural-before? right left) #f]
    [else (string<? left right)]))
