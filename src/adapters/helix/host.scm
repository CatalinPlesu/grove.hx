(require "helix/editor.scm")
(require "helix/ext.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix-static. "helix/static.scm"))

(provide workspace-root active-path unsaved-paths open-file!)

(define (workspace-root)
  (helix-static.get-helix-cwd))

(define (editor-view-open?)
  (and
   (findf editor-doc-in-view? (editor-all-documents))
   #t))

(define (focused-document-id)
  (and
   (editor-view-open?)
   (editor->doc-id (editor-focus))))

(define (active-path)
  (define document-id (focused-document-id))
  (and document-id (editor-document->path document-id)))

(define (unsaved-paths)
  (let loop ([remaining (editor-all-documents)] [result '()])
    (if
     (null? remaining)
     result
     (let* ([id (car remaining)]
            [path (editor-document->path id)])
       (loop
        (cdr remaining)
        (if
         (and
          (string? path)
          (editor-document-dirty? id))
         (cons path result)
         result))))))

(define (document-id-for-path path)
  (findf
   (lambda (document-id)
     (equal? path (editor-document->path document-id)))
   (editor-all-documents)))

(define (open-file! path mode)
  (define existing-document-id
    (and (equal? mode 'normal) (document-id-for-path path)))
  (cond
    [(and existing-document-id
          (equal? existing-document-id
                  (focused-document-id)))
     #t]
    [existing-document-id
     (editor-switch-action! existing-document-id (Action/Replace))
     #t]
    [(equal? mode 'normal)
     (helix.open path)
     #t]
    [(equal? mode 'horizontal-split)
     (helix.hsplit path)
     #t]
    [(equal? mode 'vertical-split)
     (helix.vsplit path)
     #t]
    [else (error "unknown file activation mode")]))
