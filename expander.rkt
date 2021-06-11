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
  [(_ help-line ...)
   (with-syntax ([~usage-help (datum->syntax this-syntax '~usage-help)])
     #'(set! ~usage-help (list help-line ...)))])

(define-syntax-parser flag-id
  [(_ (name param-name init-value))
   (with-syntax ([param-name (datum->syntax this-syntax #'param-name)])
     #'(define param-name (make-parameter init-value)))]
  [(_ (name init-value))
   (with-syntax ([param-name (datum->syntax this-syntax #'name)])
     #'(define param-name (make-parameter init-value)))]
  [(_ name)
   (with-syntax ([param-name (datum->syntax this-syntax #'name)])
     #'(define param-name (make-parameter #f)))])

(define-syntax-parser flag
  [(_ id-spec (short-flag verbose-flag) description handler)
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [name (syntax-parse #'id-spec
                         [(name arg ...) #'name]
                         [name #'name])])
     #'(begin
         (flag-id id-spec)
         (set! ~once-each
               (cons (list 'name short-flag verbose-flag description handler #'handler)
                     ~once-each))))]
  [(_ id-spec ((~datum one-of) (short-flag verbose-flag description handler)
                               ...))
   (with-syntax ([~once-any (datum->syntax this-syntax '~once-any)]
                 [name (syntax-parse #'id-spec
                         [(name arg ...) #'name]
                         [name #'name])])
     #'(begin
         (flag-id id-spec)
         (hash-set! ~once-any
                    'name
                    (list
                     (list 'name short-flag verbose-flag description handler #'handler)
                     ...))))]
  [(_ id-spec (~datum multi) (short-flag verbose-flag description handler))
   (with-syntax ([~multi (datum->syntax this-syntax '~multi)]
                 [name (syntax-parse #'id-spec
                         [(name arg ...) #'name]
                         [name #'name])])
     #'(begin
         (flag-id id-spec)
         (set! ~multi
               (cons (list 'name short-flag verbose-flag description handler #'handler)
                     ~multi))))]
  [(_ id-spec (~datum final) (short-flag verbose-flag description handler))
   (with-syntax ([~final (datum->syntax this-syntax '~final)]
                 [name (syntax-parse #'id-spec
                         [(name arg ...) #'name]
                         [name #'name])])
     #'(begin
         (flag-id id-spec)
         (set! ~final
               (cons (list 'name short-flag verbose-flag description handler #'handler)
                     ~final))))])

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
                 [~once-any (datum->syntax this-syntax '~once-any)]
                 [~multi (datum->syntax this-syntax '~multi)]
                 [~final (datum->syntax this-syntax '~final)])
     #'(module+ main
         (let* ([once-eaches (read-specs ~once-each 'once-each)]
                [once-anies
                 (for/list ([specs (hash-values ~once-any)])
                   (read-specs specs 'once-any))]
                [multis (read-specs ~multi 'multi)]
                [finals (read-specs ~final 'final)]
                [table `((usage-help ,@~usage-help)
                         ,once-eaches
                         ,@once-anies
                         ,multis
                         ,finals)])
           (parse-command-line ~program
                               (current-command-line-arguments)
                               table
                               (λ (options arg ...)
                                 body
                                 ...)
                               (list desc ...)))))])
