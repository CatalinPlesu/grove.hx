(require "helix/editor.scm")
(require "helix/components.scm")
(require "helix/misc.scm")
(require-builtin steel/filesystem)
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in model. "../../domain/model.scm"))
(require (prefix-in path. "../../domain/path.scm"))
(require (prefix-in host. "host.scm"))

(provide prompt-create! prompt-rename! confirm-delete!)

(define (observe-entry value)
  (define parent (parent-name value))
  (define name (file-name value))
  (with-handler
    (lambda (error-value) error-value)
    (let loop ([iterator (read-dir-iter parent)])
      (define entry (read-dir-iter-next! iterator))
      (cond
        [(not entry) #f]
        [(string=? name (read-dir-entry-file-name entry))
          entry]
        [else (loop iterator)]))))

(define (entry-kind observation)
  (and
    (read-dir-iter-entry? observation)
    (cond
      [(read-dir-entry-is-symlink? observation) 'link]
      [(read-dir-entry-is-dir? observation) 'directory]
      [(read-dir-entry-is-file? observation) 'file]
      [else #f])))

(define (source-error observation)
  (cond
    [(error-object? observation) (to-string observation)]
    [(not observation) "source does not exist"]
    [(not (entry-kind observation)) "source type is unsupported"]
    [else #f]))

(define (destination-error observation)
  (cond
    [(error-object? observation) (to-string observation)]
    [(read-dir-iter-entry? observation) "destination already exists"]
    [else #f]))

(define (matching-documents source)
  (filter
    (lambda (document-id)
      (define candidate (editor-document->path document-id))
      (and
        candidate
        (or
          (equal? candidate source)
          (path.path-inside? source candidate))))
    (editor-all-documents)))

(define (first-dirty documents)
  (define document (findf editor-document-dirty? documents))
  (and document (editor-document->path document)))

(define (close-affected! documents)
  (define active-path (host.active-path))
  (define paths
    (sort
      (map editor-document->path documents)
      (lambda (left right)
        (and
          (not (equal? left active-path))
          (equal? right active-path)))))
  (when (pair? paths)
    (apply helix.buffer-close paths)))

(define (refuse! description reason)
  (set-error!
    (string-append "Cannot " description ": " reason)))

(define (refuse-dirty! description root dirty-path)
  (refuse!
    description
    (string-append
      (or (path.id-for-path root dirty-path) dirty-path)
      " has unsaved changes")))

(define (commit! description refresh! mutate! reconcile!)
  (define error-value
    (with-handler
      (lambda (value) value)
      (begin
        (mutate!)
        #f)))
  (unless error-value
    (set-status! ""))
  (refresh!)
  (if error-value
    (refuse! description (to-string error-value))
    (reconcile!)))

(define (execute-create!
         kind
         root
         destination-id
         dispatch!
         refresh!)
  (define destination (path.path-for-id root destination-id))
  (define description
    (string-append
      "create "
      (if (equal? kind 'file) "file " "directory ")
      destination-id))
  (cond
    [(pair? (matching-documents destination))
      (refuse! description "destination is open in Helix")]
    [else
      (define destination-problem
        (destination-error (observe-entry destination)))
      (if
        destination-problem
        (refuse! description destination-problem)
        (commit!
          description
          refresh!
          (lambda ()
            (if
              (equal? kind 'file)
              (call-with-output-file destination (lambda (_) #t))
              (create-directory! destination)))
          (lambda ()
            (when (equal? kind 'file)
              (host.open-file! destination 'normal)
              (dispatch! model.focus-released)))))]))

(define (execute-rename! root source-id destination-id refresh!)
  (define source (path.path-for-id root source-id))
  (define destination (path.path-for-id root destination-id))
  (define description
    (string-append "rename or move " source-id " to " destination-id))
  (define source-problem
    (source-error (observe-entry source)))
  (define documents (matching-documents source))
  (define active-source? (equal? source (host.active-path)))
  (define dirty-path
    (and (not active-source?) (first-dirty documents)))
  (cond
    [source-problem
      (refuse! description source-problem)]
    [dirty-path
      (refuse-dirty! description root dirty-path)]
    [(pair? (matching-documents destination))
      (refuse! description "destination is open in Helix")]
    [else
      (define destination-problem
        (destination-error (observe-entry destination)))
      (cond
        [destination-problem
          (refuse! description destination-problem)]
        [active-source?
          (commit!
            description
            refresh!
            (lambda () (helix.move destination))
            (lambda () #t))]
        [else
          (commit!
            description
            refresh!
            (lambda ()
              (rename-file-or-directory! source destination))
            (lambda () (close-affected! documents)))])]))

(define (execute-delete! root source-id refresh!)
  (define source (path.path-for-id root source-id))
  (define description (string-append "delete " source-id))
  (define source-observation (observe-entry source))
  (define source-problem (source-error source-observation))
  (cond
    [source-problem
      (refuse! description source-problem)]
    [else
      (define kind (entry-kind source-observation))
      (define documents (matching-documents source))
      (define dirty-path (first-dirty documents))
      (if
        dirty-path
        (refuse-dirty! description root dirty-path)
        (commit!
          description
          refresh!
          (lambda ()
            (if
              (equal? kind 'directory)
              (delete-directory! source)
              (delete-file! source)))
          (lambda () (close-affected! documents))))]))

(define (prompt-create! command dispatch! refresh!)
  (define kind (model.create-prompt-command-kind command))
  (define root (model.create-prompt-command-root command))
  (define parent-id (model.create-prompt-command-parent-id command))
  (define label
    (string-append
      (if (equal? kind 'file) "New file in " "New directory in ")
      (if
        (path.root-id? parent-id)
        "./"
        (string-append parent-id "/"))))
  (push-component!
    (prompt
      label
      (lambda (input-value)
        (define destination-id
          (path.child-id parent-id input-value))
        (execute-create!
          kind
          root
          destination-id
          dispatch!
          refresh!)))))

(define (prompt-rename! command refresh!)
  (define root (model.rename-prompt-command-root command))
  (define source-id (model.rename-prompt-command-source-id command))
  (push-component!
    (prompt
      (string-append "Rename or move " source-id " to ")
      (lambda (destination-id)
        (execute-rename!
          root
          source-id
          destination-id
          refresh!)))))

(define (confirm-delete! command refresh!)
  (define root
    (model.delete-confirmation-command-root command))
  (define source-id
    (model.delete-confirmation-command-source-id command))
  (define recursive?
    (model.delete-confirmation-command-recursive? command))
  (define message
    (string-append
      "Permanently delete "
      source-id
      (if recursive? "/ recursively" "")
      "? y to confirm"))
  (push-component!
    (new-component!
      "grove-delete-confirmation"
      #f
      (lambda (_state rect frame)
        (define row
          (- (+ (area-y rect) (area-height rect)) 1))
        (buffer/clear-with
          frame
          (area (area-x rect) row (area-width rect) 1)
          (theme-scope-ref "ui.background"))
        (frame-set-string!
          frame
          (area-x rect)
          row
          message
          (theme-scope-ref "ui.text"))
        frame)
      (hash
        "handle_event"
        (lambda (_state event)
          (cond
            [(key-event? event)
              (define character (key-event-char event))
              (define modifier (key-event-modifier event))
              (when
                (and
                  (= modifier 0)
                  (char? character)
                  (char=? character #\y))
                (execute-delete!
                  root
                  source-id
                  refresh!))
              event-result/close]
            [(or (mouse-event? event) (paste-event? event))
              event-result/close]
            [else event-result/ignore]))
        "cursor"
        (lambda (_state _rect) #f)))))
