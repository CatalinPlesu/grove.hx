(require (prefix-in observer. "git/observer.scm"))
(require (prefix-in git. "../domain/git.scm"))

(provide observe)

(define (path-statuses-for changes)
  (let loop ([remaining changes] [result '()])
    (if
      (null? remaining)
      (reverse result)
      (let ([change (car remaining)])
        (loop
          (cdr remaining)
          (cons
            (git.path-status
              (observer.change-path change)
              (observer.change-status change))
            result))))))

(define (observe root)
  (define changes (observer.observe root))
  (and changes (git.build (path-statuses-for changes))))
