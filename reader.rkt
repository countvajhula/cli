#lang racket/base

(require (only-in racket/sequence sequence->list))

(provide
 (rename-out [cli-read-syntax read-syntax]
             [cli-read read]))

(define (cli-read port)
  (cli-read-syntax #f port))

(define (cli-read-syntax path port)
  ;; this reads symexes from the source file
  (define src-datums (sequence->list (in-port read port)))
  (define module-datum `(module cli-mod cli/expander

                          ;; since the cli lang syntax is symex-oriented
                          ;; we just use the read input directly.
                          ;; the individual forms of the language will
                          ;; be compiled by the expander
                          ,@src-datums))
  (datum->syntax #f module-datum))
