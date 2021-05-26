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
         usage-help
         (rename-out (cli-module-begin #%module-begin))
         (except-out (all-from-out racket/base)
                     #%module-begin)
         #%top #%app #%datum #%top-interaction)

(define (read-syntax path port)
  (define src-datums (sequence->list (in-port read port)))
  (define module-datum `(module cli-mod "clilang.rkt"
                          (define ~program "")
                          (define ~usage-help "")

                          ,@src-datums))
  (datum->syntax #f module-datum))

(define-syntax-parser program
  [(_ value)
   (with-syntax ([~program (datum->syntax #'value '~program)])
     #'(set! ~program value))])

(define-syntax-parser usage-help
  [(_ value)
   (with-syntax ([~usage-help (datum->syntax #'value '~usage-help)])
     #'(set! ~usage-help value))])

(define-simple-macro (cli-module-begin EXPR ...)
  (#%module-begin
   EXPR ...))

(define-syntax-parser run
  [(_ ([arg desc] ...) body ...)
   (with-syntax ([~program (datum->syntax this-syntax '~program)]
                 [~usage-help (datum->syntax this-syntax '~usage-help)])
     #'(module+ main
         (parse-command-line ~program
                             (current-command-line-arguments)
                             `((usage-help ,~usage-help))
                             (λ (options arg ...)
                               body
                               ...)
                             (list desc ...))))])
