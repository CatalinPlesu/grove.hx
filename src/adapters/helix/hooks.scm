(require "helix/ext.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require (prefix-in model. "../../domain/model.scm"))
(require (prefix-in host. "host.scm"))

(provide install!)

(define (install! dispatch!)
  (define (observe-host!)
    (dispatch!
     (model.host-observed
      (host.workspace-root)
      (host.active-path))))
  (define (observe-unsaved!)
    (dispatch!
     (model.unsaved-observed (host.unsaved-paths))))
  (define (document-focus-lost! _event)
    (observe-host!))
  (define (document-opened! _document-id)
    (observe-unsaved!))
  (define (document-changed! _document-id _old-text)
    (observe-unsaved!))
  (define (document-saved! document-id)
    (dispatch!
     (model.save-started (editor-document->path document-id))))
  (define (document-closed! _event)
    (observe-unsaved!))
  (register-hook 'document-focus-lost document-focus-lost!)
  (register-hook 'document-opened document-opened!)
  (register-hook 'document-changed document-changed!)
  (register-hook 'document-saved document-saved!)
  (register-hook 'document-closed document-closed!)
  (observe-unsaved!))
