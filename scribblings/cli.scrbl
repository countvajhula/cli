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
    (make-evaluator 'cli)))

@title{A language for writing command line interfaces}
@author{Siddhartha Kasivajhula}

@defmodulelang[cli]

A language for writing command line interfaces.

@racketblock[
(help (usage "A convenient way to write command line interfaces."))

(flag verbose
      ("-v" "--verbose")
      "Show detailed messages."
      (λ ()
        (verbose #t)))

(program (hello)
  (displayln "Hello!")
  (if (verbose)
    (displayln "Lots of words!")
    (displayln "The soul of wit.")))

(run hello)
]

@section{Forms}

@defform/subs[(help help-clause ...)
              ([help-clause (code:line (usage line ...))
                            (code:line (labels line ...))
                            (code:line (ps line ...))]
               [line string])]{
  Document various aspects of the command for display via shell interaction. Each of the subforms, @racket[usage], @racket[labels] and @racket[ps] accept strings provided in sequence, with each provided string appearing on a separate line in the output. @racket[usage] shows usage information, @racket[labels] appear before the help section on flags, and @racket[ps] appears at the end of the help text, as a "postscript" to the text. These forms correspond to the similarly-named forms in Racket's built-in command line interfaces.
}
