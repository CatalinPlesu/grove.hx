(require (prefix-in command. "command.scm"))
(require (prefix-in porcelain. "porcelain.scm"))

(provide observe change-path change-status)

(define change-path porcelain.change-path)
(define change-status porcelain.change-status)

(define (observe directory)
  (define directory-prefix
    (command.run (list "-C" directory "rev-parse" "--show-prefix")))
  (cond
    [(not directory-prefix) #f]
    [else
      (define status-output
        (command.run
          (list "-C" directory "status"
            "--porcelain=v1"
            "-z"
            "--untracked-files=all"
            "--ignored=matching"
            "--"
            ".")))
      (and
        status-output
        (with-handler
          (lambda (_cause) #f)
          (porcelain.parse status-output directory-prefix)))]))
