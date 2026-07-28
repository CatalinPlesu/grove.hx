(require "helix/misc.scm")
(require (prefix-in model. "../domain/model.scm"))
(require (prefix-in scanner. "scanner.scm"))
(require (prefix-in git. "git.scm"))

(provide run! subscribe!)

(define REFRESH-INTERVAL-MS 2000)

(define (run! command dispatch!)
  (enqueue-thread-local-callback
   (lambda ()
     (define generation (model.refresh-command-generation command))
     (define root (model.refresh-command-root command))
     (define expanded (model.refresh-command-expanded command))
     (dispatch!
      (model.refresh-completed
       generation
       (scanner.scan root expanded)
       (git.observe root))))))

(define (subscribe! dispatch!)
  (define (schedule!)
    (enqueue-thread-local-callback-with-delay
     REFRESH-INTERVAL-MS
     (lambda ()
       (dispatch! (model.refresh-due))
       (schedule!))))
  (schedule!))
