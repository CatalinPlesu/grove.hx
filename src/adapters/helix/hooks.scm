(require "helix/ext.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in model. "../../domain/model.scm"))
(require (prefix-in path. "../../domain/path.scm"))
(require (prefix-in host. "host.scm"))

(provide install!)

(define (install! dispatch!)
  (define (ids-for root paths)
    (filter
      string?
      (map (lambda (value) (path.id-for-path root value)) paths)))
  (define (observe-host!)
    (define root (host.workspace-root))
    (dispatch!
      model.host-observed
      root
      (path.id-for-path root (host.active-path))))
  (define (observe-unsaved!)
    (define root (host.workspace-root))
    (dispatch! model.unsaved-observed root (ids-for root (host.unsaved-paths))))
  (define (document-focus-lost! _event)
    (observe-host!))
  (define (document-opened! _document-id)
    (observe-unsaved!))
  (define (document-changed! _document-id _old-text)
    (observe-unsaved!))
  (define (document-saved! document-id)
    (define root (host.workspace-root))
    (dispatch!
      model.save-started
      root
      (path.id-for-path root (editor-document->path document-id))))
  (define (document-closed! _event)
    (observe-host!)
    (observe-unsaved!))
  (register-hook 'document-focus-lost document-focus-lost!)
  (register-hook 'document-opened document-opened!)
  (register-hook 'document-changed document-changed!)
  (register-hook 'document-saved document-saved!)
  (register-hook 'document-closed document-closed!)
  (observe-unsaved!))
