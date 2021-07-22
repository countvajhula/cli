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

@title{cli: Simple Command Line Interfaces}
@author{Siddhartha Kasivajhula}

@defmodulelang[cli]

A language for writing command line interfaces that aims to be simple, composable, and robust.

@racketblock[
(help (usage "A convenient way to write command line interfaces."))

(flag (verbose)
  ("-v" "--verbose" "Show detailed messages.")
  (verbose #t))

(program (hello name)
  (displayln (string-append "Hello " name "!"))
  (if (verbose)
    (displayln "By golly, it is very nice to meet you, indeed!")
    (displayln "Nice to meet you.")))

(run hello)
]

@section{Forms}

@defform/subs[(help help-clause ...)
              ([help-clause (code:line (usage line ...))
                            (code:line (labels line ...))
                            (code:line (ps line ...))]
               [line string])]{
  Document various aspects of the command for display via shell interaction (for instance, via the @racket[-h] flag). @racket[usage] shows usage information, @racket[labels] appear before the help section on flags, and @racket[ps] appears at the end of the help text, as a "postscript" to the text. Each of the subforms, @racket[usage], @racket[labels] and @racket[ps], accept strings provided in sequence, with each provided string appearing on a separate line in the output. These forms correspond to the similarly-named forms in Racket's @seclink["Command-Line_Parsing" #:doc '(lib "scribblings/reference/reference.scrbl")]{built-in command line provisions}.

@racketblock[
  (help (usage "A script to say hello." "It also validates any provided links.")
        (labels "A label" "Another label")
        (ps "Goodbye!"))
  ]
}

@defform/subs[(flag (id maybe-paramspec arg ...) metadata body ...)
              ([maybe-paramspec (code:line #:param paramspec)]
               [paramspec (code:line param-name)
                          (code:line [param-name init-value])]
               [metadata (code:line (short-flag long-flag description))])
  ]{
  Declare a flag that will be accepted by the program. This form specifies a function that will be called when the flag is provided at the command line. This function (and the corresponding command-line flag) can accept any number of arguments, or no arguments -- but in general, a specific number of them. To accept an arbitrary number of arguments, use the @racket[multi] @racket[constraint].

Each flag defined using @racket[flag] results in the creation of a @tech/reference{parameter} which may be used to store relevant values or configuration which will be available to the running program defined in the @racket[program] form. By default, this parameter has the same name as that of the flag, and is initialized with the value @racket[#f], but these may be configured via the keyword argument @racket[#:param]. Note that Racket parameters are accessed by invoking them, so in the examples below, it is these parameters being invoked rather than the flag functions which appear to have the same name (but which, under the hood, are anonymous).

  @racketblock[
    (flag (attempts n)
      ("-a" "--attempts" "Number of attempts to make")
      (attempts (string->number n)))

    (flag (links #:param [links null] link)
      ("-l" "--link" "Links to validate")
      (links (cons link (links))))
  ]
}

@defform/subs[(constraint constraint-clause)
              ([constraint-clause (code:line (one-of flag-id ...))
                                  (code:line (multi flag-id ...))
                                  (code:line (final flag-id ...))])
  ]{
  Declare a constraint that applies to the flags. By default, a flag declared via @racket[flag] may appear at the command line at most once. A constraint changes this expectation for the indicated flags. @racket[one-of] indicates that only one of the flags in the indicated set may be provided, i.e. at most one @emph{in the set} rather than individually. @racket[multi] means that the indicated flags may appear any number of times, and @racket[final] means that none of the arguments following the indicated flags will be treated as flags. See @secref["Command-Line_Parsing" #:doc '(lib "scribblings/reference/reference.scrbl")] for more on what these constraints mean.

  @racketblock[
    (constraint (one-of attempts retries))
    (constraint (multi links))
    (constraint (final exec))
  ]
}

@defform/subs[(program (name argspec ...) body ...)
              ([argspec (code:line arg)
                        (code:line [arg description])])
  ]{
  Define the command to be run. This simply defines a function, where the arguments correspond directly to those received at the command line. The arguments may optionally be documented inline. Any declared @racketlink[flag]{flags} are available in the body of the function via the corresponding @tech[#:doc '(lib "scribblings/reference/reference.scrbl") #:key "parameter"]{parameters}. Any number of commands may be defined in the same file, and they would all have access to the same flags and environment. A command so defined is not executed unless it is invoked via @racket[run].

  @racketblock[
    (program (contact-hosts admin)
      (displayln (~a "Hello, " admin "!"))
      (define result 0)
      (for-each (λ (link)
                  (when (contact-host link (attempts))
                    (set! result (add1 result))))
                (links))
      (displayln (~a "Done. Result: " result " hosts contacted.")))
  ]
}

@defform[(run program-name)]{
  Run a command. Any command defined via @racket[program] may be indicated here. The command need not be defined in the same module -- since programs are just functions, they could be defined anywhere and simply @racketlink[require]{required} in order to make them available for execution.

  @racketblock[
    (run contact-hosts)
  ]
}
