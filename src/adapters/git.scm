(require (prefix-in command. "git/command.scm"))
(require (prefix-in porcelain. "git/porcelain.scm"))
(require (prefix-in git. "../domain/git.scm"))

(provide observe)

(define (observe root)
  (define workspace-prefix
    (command.run (list "-C" root "rev-parse" "--show-prefix")))
  (cond
    [(not workspace-prefix) #f]
    [else
     (define status-output
       (command.run
        (list "-C" root "status"
              "--porcelain=v1" "-z"
              "--untracked-files=all" "--ignored=matching"
              "--" ".")))
     (and
      status-output
      (with-handler
       (lambda (_cause) #f)
       (define path-statuses
         (porcelain.parse status-output workspace-prefix))
       (and path-statuses (git.build path-statuses))))]))
