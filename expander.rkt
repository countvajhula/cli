#lang racket/base

(require racket/cmdline
         (for-syntax syntax/parse
                     syntax/parse/define
                     racket/base)
         syntax/parse
         syntax/parse/define
         racket/list
         racket/function
         mischief/shorthand
         version-case)

(require "private/util.rkt")

(version-case
 [(version< (version) "7.9.0.22")
  (define-alias define-syntax-parse-rule define-simple-macro)])

(provide run
         program
         help
         help-clause ; not intended to be used directly -- use help instead
         flag
         constraint
         (except-out (all-from-out racket/base)
                     #%module-begin)
         (rename-out [cli-module-begin #%module-begin])
         #%top #%app #%datum #%top-interaction)

(define-syntax-parser cli-module-begin
  [(_ EXPR ...)
   (with-syntax ([~usage-help (datum->syntax this-syntax '~usage-help)]
                 [~help-labels (datum->syntax this-syntax '~help-labels)]
                 [~help-ps (datum->syntax this-syntax '~help-ps)]
                 [~once-each (datum->syntax this-syntax '~once-each)]
                 [~once-any (datum->syntax this-syntax '~once-any)]
                 [~multi (datum->syntax this-syntax '~multi)]
                 [~final (datum->syntax this-syntax '~final)])
     #'(#%module-begin

        (define ~usage-help (list ""))
        (define ~help-labels (list ""))
        (define ~help-ps (list ""))
        (define ~once-each (list))
        (define ~once-any (list))
        (define ~multi (list))
        (define ~final (list))

        EXPR ...))])

;; This is so that we can use the `help` macro
;; to encapsulate all help-related configuration
;; and still be able to modify source-location bindings
;; unhygienically via modular sub-macros.
;; This help-clause macro will
;; be needed in the source module at expansion time
;; but it is not intended to be used directly.
(define-syntax-parser help-clause
  [(_ ((~datum usage) line ...))
   (with-syntax ([~usage-help (datum->syntax this-syntax '~usage-help)])
     #'(set! ~usage-help (list line ...)))]
  [(_ ((~datum labels) line ...))
   (with-syntax ([~help-labels (datum->syntax this-syntax '~help-labels)])
     #'(set! ~help-labels (list line ...)))]
  [(_ ((~datum ps) line ...))
   (with-syntax ([~help-ps (datum->syntax this-syntax '~help-ps)])
     #'(set! ~help-ps (list line ...)))])

(define-syntax-parser help
  [(_ clause ...)
   (with-syntax ([rewritten-clauses
                  (datum->syntax this-syntax
                                 (syntax->datum
                                  #'((help-clause clause)
                                     ...)))])
     #`(begin #,@(syntax->list #'rewritten-clauses)))])

(define-syntax-parser flag-param
  [(_ (name init-value))
   (with-syntax ([param-name (datum->syntax this-syntax #'name)])
     #'(define param-name (make-parameter init-value)))]
  [(_ name)
   (with-syntax ([param-name (datum->syntax this-syntax #'name)])
     #'(define param-name (make-parameter #f)))])

(define-syntax-parser flag
  [(_ (name:id (~optional (~seq #:param paramspec)
                          #:defaults ([paramspec #'name]))
               arg ...)
      (short-flag verbose-flag description)
      body ...)
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [handler #'(λ (arg ...)
                              body ...)])
     #'(begin
         (flag-param paramspec)
         (set! ~once-each
               (cons (list 'name short-flag verbose-flag description #'handler)
                     ~once-each))))])

(define-syntax-parse-rule (~extract-flag! flag source)
  (let* ([idx (or (index-where source
                               (λ (v)
                                 (eq? flag (first v))))
                  (raise-argument-error 'constraint
                                        "An identifier corresponding to a previously declared flag"
                                        flag))]
         [flagspec (list-ref source idx)])
    (set! source
          (remove-at source
                     idx))
    flagspec))

(define-syntax-parse-rule (~insert-item! item destination)
  (set! destination
        (cons item
              destination)))

;; move flag from one location (usually ~once-each, where all flags
;; go by default) to another (e.g. once-any, multi, or final)
(define-syntax-parse-rule (~refile-flag! flag source destination)
  (~insert-item! (~extract-flag! flag source)
                 destination))

(define-syntax-parser constraint
  [(_ ((~datum one-of) flag0:id flag:id ...+))
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [~once-any (datum->syntax this-syntax '~once-any)])
     #'(let ([flagspecs (for/list [(flg (list 'flag0 'flag ...))]
                          (~extract-flag! flg ~once-each))])
         (~insert-item! flagspecs ~once-any)))]
  [(_ ((~datum multi) flag:id ...+))
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [~multi (datum->syntax this-syntax '~multi)])
     #'(for-each (λ (flg)
                   (~refile-flag! flg ~once-each ~multi))
                 (list 'flag ...)))]
  [(_ ((~datum final) flag:id ...+))
   (with-syntax ([~once-each (datum->syntax this-syntax '~once-each)]
                 [~final (datum->syntax this-syntax '~final)])
     #'(for-each (λ (flg)
                   (~refile-flag! flg ~once-each ~final))
                 (list 'flag ...)))])

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
         (syntax-parse (fifth spec)
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
        (let ([arg-names (syntax-parse (fifth spec)
                           [((~or (~datum lambda) (~datum λ)) (arg ...)
                                                              body ...)
                            (map (compose symbol->string syntax->datum)
                                 (syntax->list #'(arg ...)))]
                           [((~or (~datum lambda) (~datum λ)) args
                                                              body ...)
                            (list
                             (symbol->string
                              (syntax->datum #'args)))])])
          (cons (fourth spec) arg-names))))

(define (read-specs specs header)
  (cons header
        (for/list ([spec specs])
          (read-spec spec))))

(begin-for-syntax
  (define (parse-argspec argspec)
    (syntax-parse argspec
      [(arg:id desc:string) #'(arg desc)]
      [arg:id #'(arg "undocumented argument")])))

(define-syntax-parser program
  [(_ (name:id argspec ...) body ...)
   (with-syntax ([command-name (symbol->string (syntax->datum #'name))]
                 [command-id (datum->syntax this-syntax (syntax->datum #'name))]
                 [~usage-help (datum->syntax this-syntax '~usage-help)]
                 [~help-labels (datum->syntax this-syntax '~help-labels)]
                 [~help-ps (datum->syntax this-syntax '~help-ps)]
                 [~once-each (datum->syntax this-syntax '~once-each)]
                 [~once-any (datum->syntax this-syntax '~once-any)]
                 [~multi (datum->syntax this-syntax '~multi)]
                 [~final (datum->syntax this-syntax '~final)]
                 [((arg desc) ...) (datum->syntax
                                    this-syntax
                                    (map parse-argspec
                                         (syntax->list #'(argspec ...))))])
     #'(define (command-id argv)
         (let* ([once-eaches (read-specs ~once-each 'once-each)]
                [once-anies
                 (map (curryr read-specs 'once-any) ~once-any)]
                [multis (read-specs ~multi 'multi)]
                [finals (read-specs ~final 'final)]
                [table `((usage-help ,@~usage-help)
                         (help-labels ,@~help-labels)
                         (ps ,@~help-ps)
                         ,once-eaches
                         ,@once-anies
                         ,multis
                         ,finals)])
           (parse-command-line command-name
                               argv
                               table
                               (λ (options arg ...)
                                 body
                                 ...)
                               (list desc ...)))))])

(define-syntax-parser run
  [(_ name:id) #'(name (current-command-line-arguments))]
  [(_ name:id args:expr) #'(name args)])
