(provide build press? part-at adjust-width pointer
         pointer-result-press pointer-result-effect
         resize-effect? resize-effect-width
         scroll-effect? scroll-effect-mode scroll-effect-amount)

(struct rail-value
  (x y width max-width height side thumb-y thumb-height total-rows))
(struct press-value (origin-x origin-y action thumb-offset))
(struct pointer-result (press effect))
(struct resize-effect (width))
(struct scroll-effect (mode amount))

(define press? press-value?)

(define (build x y width max-width height side total-rows start-row)
  (define thumb?
    (and (> height 0) (> total-rows height)))
  (define thumb-height
    (and thumb? (max 1 (quotient (* height height) total-rows))))
  (define thumb-y
    (and
     thumb?
     (let* ([maximum-start-row (- total-rows height)]
            [travel (- height thumb-height)]
            [offset
             (if
              (= travel 0)
              0
              (quotient (* start-row travel) maximum-start-row))])
       (+ y offset))))
  (rail-value
   x y width max-width height side thumb-y thumb-height total-rows))

(define (rail-x rail)
  (if
   (equal? (rail-value-side rail) 'right)
   (rail-value-x rail)
   (+ (rail-value-x rail) (rail-value-width rail) -1)))

(define (thumb-end rail)
  (and
   (rail-value-thumb-y rail)
   (+ (rail-value-thumb-y rail) (rail-value-thumb-height rail))))

(define (thumb-row? rail row)
  (and
   (rail-value-thumb-y rail)
   (>= row (rail-value-thumb-y rail))
   (< row (thumb-end rail))))

(define (part-at rail row)
  (and
   (>= row (rail-value-y rail))
   (< row (+ (rail-value-y rail) (rail-value-height rail)))
   (if (thumb-row? rail row) 'thumb 'track)))

(define (cell? rail column row)
  (and
   (= column (rail-x rail))
   (part-at rail row)))

(define (cap-width rail requested)
  (min requested (rail-value-max-width rail)))

(define (adjust-width rail delta)
  (cap-width rail (+ (rail-value-width rail) delta)))

(define (resize-width rail column)
  (define requested
    (if
     (equal? (rail-value-side rail) 'right)
     (- (+ (rail-value-x rail) (rail-value-width rail)) column)
     (+ 1 (- column (rail-value-x rail)))))
  (cap-width rail requested))

(define (scroll-start-for-thumb rail grab-offset row)
  (and
   (rail-value-thumb-height rail)
   (let* ([maximum-start-row
           (max
            0
            (- (rail-value-total-rows rail)
               (rail-value-height rail)))]
          [travel
           (max
            0
            (- (rail-value-height rail)
               (rail-value-thumb-height rail)))]
          [current-grab-offset
           (min
            grab-offset
            (- (rail-value-thumb-height rail) 1))]
          [thumb-offset
           (max
            0
            (min
             travel
             (- row (rail-value-y rail) current-grab-offset)))])
     (if
      (= travel 0)
      0
      (quotient
       (+ (* thumb-offset maximum-start-row) (quotient travel 2))
       travel)))))

(define (page-scroll-amount rail row)
  (and
   (rail-value-thumb-y rail)
   (cond
     [(< row (rail-value-thumb-y rail))
      (- (rail-value-height rail))]
     [(>= row (thumb-end rail))
      (rail-value-height rail)]
     [else #f])))

(define (press rail column row)
  (and
   (cell? rail column row)
   (press-value
    column
    row
    'undecided
    (and
     (thumb-row? rail row)
     (- row (rail-value-thumb-y rail))))))

(define (chosen-action press column row)
  (define dx (abs (- column (press-value-origin-x press))))
  (define dy (abs (- row (press-value-origin-y press))))
  (cond
    [(= dx dy) 'undecided]
    [(> dx dy) 'resize]
    [(integer? (press-value-thumb-offset press)) 'scroll]
    [else 'do-nothing]))

(define (choose-action press action)
  (press-value
   (press-value-origin-x press)
   (press-value-origin-y press)
   action
   (press-value-thumb-offset press)))

(define (begin-press rail column row)
  (define rail-press (press rail column row))
  (and rail-press (pointer-result rail-press 'handled)))

(define (continue-press rail rail-press phase column row)
  (define action
    (if
     (equal? (press-value-action rail-press) 'undecided)
     (chosen-action rail-press column row)
     (press-value-action rail-press)))
  (define continued-press
    (and
     (not (equal? phase 'release))
     (choose-action rail-press action)))
  (cond
    [(equal? action 'resize)
     (pointer-result
      continued-press
      (resize-effect (resize-width rail column)))]
    [(equal? action 'scroll)
     (define start-row
       (scroll-start-for-thumb
        rail
        (press-value-thumb-offset rail-press)
        row))
     (if
      (integer? start-row)
      (pointer-result
       continued-press
       (scroll-effect 'absolute start-row))
      (pointer-result continued-press 'handled))]
    [(and
      (equal? phase 'release)
      (equal? action 'undecided)
      (= column (press-value-origin-x rail-press))
      (= row (press-value-origin-y rail-press)))
     (define page-offset (page-scroll-amount rail row))
     (if
      (integer? page-offset)
      (pointer-result #f (scroll-effect 'relative page-offset))
      (pointer-result #f 'handled))]
    [else (pointer-result continued-press 'handled)]))

(define (pointer rail rail-press phase column row)
  (cond
    [(equal? phase 'press) (begin-press rail column row)]
    [rail-press (continue-press rail rail-press phase column row)]
    [else #f]))
