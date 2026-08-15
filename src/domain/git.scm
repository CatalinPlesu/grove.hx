(require (prefix-in path. "path.scm"))

(provide path-status build status-for)

(struct path-status-value (id status))
(struct status-value (exact-statuses descendant-statuses))

(define path-status-id path-status-value-id)
(define path-status-status path-status-value-status)

(define path-status path-status-value)

(define (semantic-status raw)
  (cond
    [(equal? raw 'conflicted) 'conflict]
    [(equal? raw 'deleted) 'deleted]
    [(member raw '(renamed copied type-changed modified)) 'modified]
    [(member raw '(added untracked)) 'created]
    [else #f]))

(define (strength status)
  (cond
    [(equal? status 'conflict) 4]
    [(equal? status 'deleted) 3]
    [(equal? status 'modified) 2]
    [(equal? status 'created) 1]
    [else 0]))

(define (stronger current candidate)
  (if (> (strength candidate) (strength current))
    candidate
    current))

(define (insert-stronger table id candidate)
  (if
    candidate
    (hash-insert table id (stronger (hash-try-get table id) candidate))
    table))

(define (insert-exact table id raw)
  (define candidate
    (if (member raw '(ignored ignored-tree))
      'ignored
      (semantic-status raw)))
  (define current (hash-try-get table id))
  (cond
    [(not candidate) table]
    [(or (equal? current 'ignored) (equal? candidate 'ignored))
      (hash-insert table id 'ignored)]
    [else (insert-stronger table id candidate)]))

(define (record-status-for-ancestors table id candidate)
  (let loop ([remaining (path.ancestor-ids id)] [result table])
    (if
      (null? remaining)
      result
      (loop
        (cdr remaining)
        (insert-stronger result (car remaining) candidate)))))

(define (build path-statuses)
  (let loop ([remaining path-statuses] [exact (hash)] [descendants (hash)])
    (if
      (null? remaining)
      (status-value exact descendants)
      (let* ([path-status (car remaining)]
             [id (path-status-id path-status)]
             [raw-status (path-status-status path-status)]
             [semantic (semantic-status raw-status)])
        (loop
          (cdr remaining)
          (insert-exact exact id raw-status)
          (record-status-for-ancestors descendants id semantic))))))

(define (status-for git-status id directory?)
  (if
    (not git-status)
    #f
    (let ([exact
            (hash-try-get
              (status-value-exact-statuses git-status)
              id)])
      (if
        (equal? exact 'ignored)
        'ignored
        (stronger
          exact
          (and
            directory?
            (hash-try-get (status-value-descendant-statuses git-status) id)))))))
