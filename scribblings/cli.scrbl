#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         racket/sandbox
         @for-label[(except-in cli #%module-begin)
                    racket]]

@(define eval-for-docs
  (parameterize ([sandbox-output 'string]
                 [sandbox-error-output 'string]
                 [sandbox-memory-limit #f])
    (make-evaluator 'racket/base
                    '(require cli))))

@title{A language for writing command line interfaces}
@author{Siddhartha Kasivajhula}

@defmodule[cli]

A language for writing command line interfaces.

@;{
@examples[
    #:eval eval-for-docs
    (program "dummy")
	(usage-help "A useful script.")

    (flag verbose
      ("-v" "--verbose")
      "Show detailed messages"
      (λ (v)
        (verbose #t)))
    (run ()
      (displayln "Hello!")
	  (display "The verbose parameter is: "
      (displayln (verbose))))
  ]
}
