#lang racket/base

(require racket/cmdline
         (for-syntax syntax/parse
                     syntax/parse/define
                     racket/base)
         syntax/parse
         syntax/parse/define
         racket/list)

(provide run
         program
         usage-help
         flag
         (rename-out (cli-module-begin #%module-begin))
         (except-out (all-from-out racket/base)
                     #%module-begin)
         #%top #%app #%datum #%top-interaction)

(define-syntax-parser program
  [(_ value)
   (with-syntax ([~program (datum->syntax this-syntax '~program)])
     #'(set! ~program value))])

(define-syntax-parser usage-help
  [(_ value)
   (with-syntax ([~usage-help (datum->syntax this-syntax '~usage-help)])
     #'(set! ~usage-help value))])

(define-syntax-parser flag
  [(_ name (short-flag verbose-flag) description handler)
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [param-name (datum->syntax this-syntax #'name)])
     #'(begin
         (define param-name (make-parameter #f))
         (set! ~once-each
               (cons (list 'name short-flag verbose-flag description handler #'handler)
                     ~once-each))))]
  [(_ name ((~datum one-of) (short-flag verbose-flag description handler)
                            ...))
   (with-syntax ([~once-any (datum->syntax this-syntax '~once-any)]
                 [param-name (datum->syntax this-syntax #'name)])
     #'(begin
         (define param-name (make-parameter #f))
         (hash-set! ~once-any
                    'name
                    (list
                     (list 'name short-flag verbose-flag description handler #'handler)
                     ...))))])

(define-simple-macro (cli-module-begin EXPR ...)
  (#%module-begin
   EXPR ...))

(define (read-spec spec)
  (list (list (second spec) (third spec))
        ;; the user would write a lambda without
        ;; expecting the flag argument, so we
        ;; add the flag argument here, invisibly
        ;; by parsing and then recomposing a syntax
        ;; object from the user's entered lambda
        ;; we also eval it here since the argument
        ;; needs to be a procedure rather than a
        ;; specification for a procedure
        (eval
         (syntax-parse (sixth spec)
           [((~or (~datum lambda) (~datum λ)) (arg ...)
                                              body ...)
            #'(λ (~flg arg ...)
                body ...)]
           [((~or (~datum lambda) (~datum λ)) args
                                              body ...)
            #'(λ (~flg . args)
                body ...)]))
        ;; we extract the argument names from the
        ;; lambda written by the user, and use those
        ;; as argument names in the spec
        (let ([arg-names (syntax-parse (sixth spec)
                           [((~or (~datum lambda) (~datum λ)) (arg ...)
                                                              body ...)
                            (map (compose symbol->string syntax->datum) (syntax->list #'(arg ...)))])])
          (cons (fourth spec) arg-names))))

(define (read-specs specs header)
  (cons header
        (for/list ([spec specs])
          (read-spec spec))))

(define-syntax-parser run
  [(_ ([arg desc] ...) body ...)
   (with-syntax ([~program (datum->syntax this-syntax '~program)]
                 [~usage-help (datum->syntax this-syntax '~usage-help)]
                 [~once-each (datum->syntax this-syntax '~once-each)]
                 [~once-any (datum->syntax this-syntax '~once-any)])
     #'(module+ main
         (let* ([once-eaches (read-specs ~once-each 'once-each)]
                [once-anies
                 (for/list ([specs (hash-values ~once-any)])
                   (read-specs specs 'once-any))]
                [table `((usage-help ,~usage-help)
                         ,once-eaches
                         ,@once-anies)])
           (parse-command-line ~program
                               (current-command-line-arguments)
                               table
                               (λ (options arg ...)
                                 body
                                 ...)
                               (list desc ...)))))])
