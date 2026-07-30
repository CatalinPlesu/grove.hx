(provide before?)

(define (digit-run-end text index)
  (if
   (and
    (< index (string-length text))
    (char-digit? (string-ref text index)))
   (digit-run-end text (+ index 1))
   index))

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
       (define left-digit? (char-digit? left-character))
       (define right-digit? (char-digit? right-character))
       (cond
         [(and left-digit? right-digit?)
          (define left-end (digit-run-end folded-left left-index))
          (define right-end (digit-run-end folded-right right-index))
          (define left-value
            (string->number
             (substring folded-left left-index left-end)))
          (define right-value
            (string->number
             (substring folded-right right-index right-end)))
          (cond
            [(< left-value right-value) #t]
            [(> left-value right-value) #f]
            ; Equal values put shorter runs first, so "2" sorts before "02".
            [(< (- left-end left-index) (- right-end right-index)) #t]
            [(> (- left-end left-index) (- right-end right-index)) #f]
            [else (loop left-end right-end)])]
         [left-digit? #t]
         [right-digit? #f]
         [(char<? left-character right-character) #t]
         [(char<? right-character left-character) #f]
         [else (loop (+ left-index 1) (+ right-index 1))])])))

(define (before? left right)
  (cond
    [(natural-before? left right) #t]
    [(natural-before? right left) #f]
    [else (string<? left right)]))
