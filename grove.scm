(require (prefix-in helix. "src/adapters/helix.scm"))

(provide grove-start! grove-focus!)

(define (validate-settings side width icons?)
  (unless (or (equal? side 'left) (equal? side 'right))
    (error "invalid Grove side"))
  (unless (and (integer? width) (>= width 16) (<= width 64))
    (error "invalid Grove width"))
  (unless (boolean? icons?)
    (error "Grove icons must be a boolean")))

(define (grove-start! #:icons [icons? #t]
                      #:side [side 'left]
                      #:width [width 32])
  (validate-settings side width icons?)
  (helix.start! side width icons?))

;;@doc
;;Focus Grove.
(define (grove-focus!)
  (helix.focus!))
