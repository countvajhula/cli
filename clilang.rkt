#lang racket/base

(require racket/cmdline
         (for-syntax syntax/parse
                     syntax/parse/define
                     racket/base)
         syntax/parse
         syntax/parse/define
         racket/list
         (only-in racket/sequence sequence->list))

(provide read-syntax
         run
         program
         usage-help
         flag
         (rename-out (cli-module-begin #%module-begin))
         (except-out (all-from-out racket/base)
                     #%module-begin)
         #%top #%app #%datum #%top-interaction)

(define (read-syntax path port)
  (define src-datums (sequence->list (in-port read port)))
  (define module-datum `(module cli-mod "clilang.rkt"
                          (define ~program "")
                          (define ~usage-help "")
                          (define ~once-each (list))

                          ,@src-datums))
  (datum->syntax #f module-datum))

(define-syntax-parser program
  [(_ value)
   (with-syntax ([~program (datum->syntax this-syntax '~program)])
     #'(set! ~program value))])

(define-syntax-parser usage-help
  [(_ value)
   (with-syntax ([~usage-help (datum->syntax this-syntax '~usage-help)])
     #'(set! ~usage-help value))])

;; lambda args call handler loses the hint that "the -d option
;; needs N arguments, but M provided"
(define-syntax-parser flag
  [(_ name (short-flag verbose-flag) description handler)
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [param-name (datum->syntax this-syntax #'name)])
     #'(begin
         (define param-name (make-parameter #f))
         (set! ~once-each
               (cons (list name short-flag verbose-flag description handler #'handler)
                     ~once-each))))])

(define-simple-macro (cli-module-begin EXPR ...)
  (#%module-begin
   EXPR ...))

(define-syntax-parser run
  [(_ ([arg desc] ...) body ...)
   (with-syntax ([~program (datum->syntax this-syntax '~program)]
                 [~usage-help (datum->syntax this-syntax '~usage-help)]
                 [~once-each (datum->syntax this-syntax '~once-each)])
     #'(module+ main
         (let* ([once-eaches (for/list ([spec ~once-each])
                               (list (list (second spec) (third spec))
                                     (lambda (flg . args)
                                       (apply (fifth spec) args))
                                     (list (fourth spec) "NAME")))]
                [table `((usage-help ,~usage-help)
                        (once-each
                         ,@once-eaches))])
           (parse-command-line ~program
                               (current-command-line-arguments)
                               table
                               (λ (options arg ...)
                                 body
                                 ...)
                               (list desc ...)))))])
