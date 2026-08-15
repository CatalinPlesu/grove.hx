(provide parse change-path change-status)

(struct change (path status))

(define (strip-terminal-lf text)
  (define text-length (string-length text))
  (if (ends-with? text "\n")
    (substring text 0 (- text-length 1))
    text))

(define (code-contains? code character)
  (string-contains? code (string character)))

(define CONFLICT-CODES '("DD" "AU" "UD" "UA" "DU" "AA" "UU"))

(define (source-bearing? code)
  (or (code-contains? code #\R)
    (code-contains? code #\C)))

(define (decode-status code)
  (cond
    [(member code CONFLICT-CODES)
      'conflicted]
    [(code-contains? code #\D) 'deleted]
    [(code-contains? code #\R) 'renamed]
    [(code-contains? code #\C) 'copied]
    [(code-contains? code #\A) 'added]
    [(string=? code "??") 'untracked]
    [(code-contains? code #\T) 'type-changed]
    [(code-contains? code #\M) 'modified]
    [else #f]))

(define (relative-path prefix path)
  (and (starts-with? path prefix)
    (substring path (string-length prefix) (string-length path))))

(define (parse-records output directory-prefix)
  (let loop ([records (split-many output "\0")] [changes '()])
    (cond
      [(null? records) (reverse changes)]
      [(string=? (car records) "")
        (if (null? (cdr records))
          (reverse changes)
          #f)]
      [else
        (define record (car records))
        (define code (substring record 0 2))
        (define raw-path (substring record 3 (string-length record)))
        (define directory? (ends-with? raw-path "/"))
        (define normalized-path
          (if
            directory?
            (substring raw-path 0 (- (string-length raw-path) 1))
            raw-path))
        (define path (relative-path directory-prefix normalized-path))
        (cond
          [(not path) #f]
          [(source-bearing? code)
            ; Porcelain -z puts a discarded source path after each rename or copy.
            (define status (decode-status code))
            (and
              status
              (not (null? (cdr records)))
              (not (string=? (car (cdr records)) ""))
              (loop
                (cdr (cdr records))
                (cons (change path status) changes)))]
          [(string=? code "!!")
            (loop
              (cdr records)
              (cons
                (change
                  path
                  (if directory? 'ignored-tree 'ignored))
                changes))]
          [else
            (define status (decode-status code))
            (and status
              (loop (cdr records)
                (cons (change path status) changes)))])])))

(define (parse output directory-prefix)
  (parse-records output (strip-terminal-lf directory-prefix)))
