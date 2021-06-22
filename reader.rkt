#lang racket/base

(require (only-in racket/sequence sequence->list))

(provide read-syntax)

(define (read-syntax path port)
    (define src-datums (sequence->list (in-port read port)))
    (define module-datum `(module cli-mod cli/expander
                            (define ~usage-help (list ""))
                            (define ~help-labels (list ""))
                            (define ~help-ps (list ""))
                            (define ~once-each (list))
                            (define ~once-any (make-hash))
                            (define ~multi (list))
                            (define ~final (list))

                            ,@src-datums))
    (datum->syntax #f module-datum))
