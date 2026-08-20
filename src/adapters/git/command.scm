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
  (foldl
    (lambda (variable prepared)
      (without-env-var prepared variable))
    command-value
    GIT-VARIABLES))

(define (prepare-command arguments null-port)
  (~> (command "git" arguments)
    (with-env-var "GIT_OPTIONAL_LOCKS" "0")
    clear-git-environment
    (with-stderr null-port)
    with-stdout-piped))

; Every step here fails the same way: swallow the error and report #f. A macro
; keeps that inline, because ADR 0001 rules out an indirect helper returning
; the Ok and Err structs that spawn-process and process-wait produce.
(define-syntax attempt
  (syntax-rules ()
    [(_ body ...) (with-handler (lambda (_cause) #f) (begin body ...))]))

(define (run arguments)
  (define null-port
    (attempt (open-output-file "/dev/null" #:exists 'append)))
  (and
    null-port
    (let ([spawn-result
            (attempt (spawn-process (prepare-command arguments null-port)))])
      (attempt (close-output-port null-port))
      (and
        spawn-result
        (not (Err? spawn-result))
        (let* ([child (Ok->value spawn-result)]
               [port (attempt (child-stdout child))]
               [output (and port (attempt (read-port-to-string port)))]
               [closed? (and port (attempt (close-input-port port) #t))]
               [wait-result (attempt (process-wait child))])
          (and
            output
            closed?
            wait-result
            (not (Err? wait-result))
            (= 0 (Ok->value wait-result))
            output))))))
