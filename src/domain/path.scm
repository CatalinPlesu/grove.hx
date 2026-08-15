(provide root-id root-id? child-id parent-id ancestor-ids depth id-inside?
  basename
  path-for-id
  id-for-path)

(define root-id "")

(define (root-id? id)
  (and (string? id) (string=? id root-id)))

(define (child-id parent name)
  (if (root-id? parent) name (string-append parent "/" name)))

(define (parent-id id)
  (and (not (root-id? id)) (parent-name id)))

(define (ancestor-ids id)
  (let loop ([parent (parent-id id)] [result '()])
    (if
      parent
      (loop (parent-id parent) (cons parent result))
      result)))

(define (depth id)
  (if
    (root-id? id)
    0
    (length (split-many id "/"))))

(define (id-inside? directory-id candidate-id)
  (define prefix
    (if
      (root-id? directory-id)
      directory-id
      (string-append directory-id "/")))
  (and
    (> (string-length candidate-id) (string-length prefix))
    (starts-with? candidate-id prefix)))

(define (basename value)
  (if (string=? value "/") "/" (file-name value)))

(define (path-for-id root id)
  (if
    (root-id? id)
    root
    (string-append root (if (string=? root "/") "" "/") id)))

(define (id-for-path root absolute-path)
  (define prefix (if (string=? root "/") root (string-append root "/")))
  (cond
    [(not (string? absolute-path)) #f]
    [(string=? root absolute-path) root-id]
    [(and
        (> (string-length absolute-path) (string-length prefix))
        (starts-with? absolute-path prefix))
      (substring
        absolute-path
        (string-length prefix)
        (string-length absolute-path))]
    [else #f]))
