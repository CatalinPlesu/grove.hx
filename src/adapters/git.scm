(require (prefix-in command. "git/command.scm"))
(require (prefix-in porcelain. "git/porcelain.scm"))
(require (prefix-in git. "../domain/git.scm"))

(provide observe)

(define (observe root)
  (define directory-prefix
    (command.run (list "-C" root "rev-parse" "--show-prefix")))
  (define status-output
    (and
      directory-prefix
      (command.run
        (list "-C" root "status"
          "--porcelain=v1"
          "-z"
          "--untracked-files=all"
          "--ignored=matching"
          "--"
          "."))))
  (define path-statuses
    (and
      status-output
      (with-handler
        (lambda (_cause) #f)
        (porcelain.parse status-output directory-prefix))))
  (and path-statuses (git.build path-statuses)))
