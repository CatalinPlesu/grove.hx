(provide run)

(define GIT-VARIABLES
  '("GIT_ALTERNATE_OBJECT_DIRECTORIES"
    "GIT_CONFIG"
    "GIT_CONFIG_PARAMETERS"
    "GIT_CONFIG_COUNT"
    "GIT_OBJECT_DIRECTORY"
    "GIT_DIR"
    "GIT_WORK_TREE"
    "GIT_IMPLICIT_WORK_TREE"
    "GIT_GRAFT_FILE"
    "GIT_INDEX_FILE"
    "GIT_NO_REPLACE_OBJECTS"
    "GIT_REPLACE_REF_BASE"
    "GIT_PREFIX"
    "GIT_SHALLOW_FILE"
    "GIT_COMMON_DIR"
    "GIT_CEILING_DIRECTORIES"
    "GIT_DISCOVERY_ACROSS_FILESYSTEM"))

(define (clear-git-environment command-value)
  (let loop ([prepared command-value] [remaining GIT-VARIABLES])
    (if (null? remaining)
        prepared
        (loop (without-env-var prepared (car remaining))
              (cdr remaining)))))

(define (prepare-command arguments null-port)
  (~> (command "git" arguments)
      (with-env-var "GIT_OPTIONAL_LOCKS" "0")
      clear-git-environment
      (with-stderr null-port)
      with-stdout-piped))

(define (run arguments)
  (define null-port
    (with-handler
     (lambda (_cause) #f)
     (open-output-file "/dev/null" #:exists 'append)))
  (and
   null-port
   (let ([spawn-result
          (with-handler
           (lambda (_cause) #f)
           (spawn-process (prepare-command arguments null-port)))])
     (with-handler
      (lambda (_cause) #f)
      (close-output-port null-port))
     (and
      spawn-result
      (not (Err? spawn-result))
      (let* ([child (Ok->value spawn-result)]
             [port
              (with-handler
               (lambda (_cause) #f)
               (child-stdout child))]
             [output
              (and
               port
               (with-handler
                (lambda (_cause) #f)
                (read-port-to-string port)))]
             [closed?
              (and
               port
               (with-handler
                (lambda (_cause) #f)
                (begin
                  (close-input-port port)
                  #t)))]
             [wait-result
              (with-handler
               (lambda (_cause) #f)
               (process-wait child))])
        (and
         output
         closed?
         wait-result
         (not (Err? wait-result))
         (= 0 (Ok->value wait-result))
         output))))))
