#lang racket/base

(require (only-in racket/sequence sequence->list))

(provide read-syntax)

(define (read-syntax path port)
    (define src-datums (sequence->list (in-port read port)))
    (define module-datum `(module cli-mod cli/expander
                            (define ~program "")
                            (define ~usage-help "")
                            (define ~once-each (list))
                            (define ~once-any (make-hash))
                            (define ~multi (list))

                            ,@src-datums))
    (datum->syntax #f module-datum))
