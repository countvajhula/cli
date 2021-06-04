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

;; cli struct specification
;;   - maybe (make-cli) prior to calling (run ...)
;;     to create a (cli ...) struct
;;     which could be introspected and independently executed
;;     in requiring modules
;;     -> define a function (cli-spec) at the module level
;;        in read-syntax, which should return the cli instance
;;        and it should be (provide ...)ed at this level
;;   - and then if that works out, maybe make all of the
;;     syntactic forms here simply mutate the global cli instance
;;     instead of setting individual variables
;;     (could use lenses to make this cleanish)

(define (read-syntax path port)
  (define src-datums (sequence->list (in-port read port)))
  (define module-datum `(module cli-mod "clilang.rkt"
                          (define ~program "")
                          (define ~usage-help "")
                          (define ~once-each (list))
                          (define ~once-any (make-hash))

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
        (list (fourth spec) "NAME")))

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
