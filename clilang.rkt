#lang racket/base

(require racket/cmdline
         (for-syntax syntax/parse
                     syntax/parse/define
                     racket/base)
         syntax/parse
         syntax/parse/define
         (only-in racket/sequence sequence->list))

(provide read-syntax
         run
         program
         (rename-out (cli-module-begin #%module-begin))
         (except-out (all-from-out racket/base)
                     #%module-begin)
         #%top #%app #%datum #%top-interaction)

(define (read-syntax path port)
  (define src-datums (sequence->list (in-port read port)))
  (define module-datum `(module cli-mod "clilang.rkt"
                          (define ~program "")

                          ,@src-datums))
  (datum->syntax #f module-datum))

(define-syntax-parser program
  [(_ value)
   (with-syntax ([~program (datum->syntax #'value '~program)])
     #'(set! ~program value))])

(define-simple-macro (cli-module-begin EXPR ...)
  (#%module-begin
   EXPR ...))

(define-syntax-parser run
  [(_ ([arg desc] ...) body ...)
   (with-syntax ([~program (datum->syntax this-syntax '~program)])
     #'(parse-command-line ~program
                           (current-command-line-arguments)
                           null
                           (λ (options arg ...)
                             body
                             ...)
                           (list desc ...)))])
