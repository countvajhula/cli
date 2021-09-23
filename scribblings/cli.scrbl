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

A language for writing command line interfaces that aims to be simple, composable, and robust. You can use it to write @seclink["In_a_script" #:doc '(lib "cli/scribblings/cli.scrbl")]{standalone scripts}, or to extend the capabilities of @seclink["In_a_main_submodule" #:doc '(lib "cli/scribblings/cli.scrbl")]{an existing main submodule}.

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

@section{Usage}

The language provides a small set of @seclink["Forms" #:doc '(lib "cli/scribblings/cli.scrbl")]{forms} that allow you to comprehensively specify the behavior of your command line interface. You may use these forms in the following ways.

@subsection{In a script}

In order to use the language to write a command line script, simply declare the module as @hash-lang[] @racket[cli] at the top of the file.

@racketmod[
cli

(program (hello name)
  (displayln (string-append "Hello " name "!")))

(run hello)
]

@subsection{In a main submodule}

To use the language in a @seclink["main-and-test" #:doc '(lib "scribblings/guide/guide.scrbl")]{main submodule}, use @racket[cli] as the module language.

@racketmod[
racket

(require racket/format)

(define (greeting name)
  (~a "Hello, " name "!"))

(provide greeting)

(module* main cli
  (require (submod ".."))
  (program (say-hello [name "Your name"])
    (displayln (greeting name)))
  (run say-hello))
]

Since the module language differs from the enclosing module language, we need to explicitly require the enclosing module in the main submodule via @racket[(require (submod ".."))] in order to use the identifiers declared there. Also note that unlike in the typical case of using @racket[(module+ main)], the main submodule would only have access to the enclosing module identifiers when they are explicitly @racketlink[provide]{provided}, as in the example above.

@section{Forms}

@defform/subs[(help help-clause ...)
              ([help-clause (code:line (usage line ...))
                            (code:line (labels line ...))
                            (code:line (ps line ...))]
               [line string])]{
  Document various aspects of the command for display via shell interaction (for instance, via the @racket[-h] or @racket[--help] flag). @racket[usage] shows usage information, @racket[labels] appear before the help section on flags, and @racket[ps] appears at the end of the help text, as a "postscript" to the text. Each of the subforms, @racket[usage], @racket[labels] and @racket[ps], accept strings provided in sequence, with each provided string appearing on a separate line in the output. These forms correspond to the identically-named forms in Racket's @seclink["Command-Line_Parsing" #:doc '(lib "scribblings/reference/reference.scrbl")]{built-in command line provisions}.

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
  Declare a constraint that applies to the flags. By default, a flag declared via @racket[flag] may appear at the command line at most once. A constraint changes this expectation for the indicated flags. @racket[one-of] means that only one of the flags in the indicated set may be provided, i.e. at most one @emph{in the set} rather than individually. @racket[multi] means that the indicated flags may appear any number of times, and @racket[final] means that none of the arguments following the indicated flags will be treated as flags. See @secref["Command-Line_Parsing" #:doc '(lib "scribblings/reference/reference.scrbl")] for more on what these constraints mean.

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
  Define the command to be run. This simply defines a function, where the arguments correspond directly to those received at the command line. The arguments may optionally be documented inline, and these descriptions would appear at the command line in help text and prompts. Any declared @racketlink[flag]{flags} are available in the body of the function via the corresponding @tech[#:doc '(lib "scribblings/reference/reference.scrbl") #:key "parameter"]{parameters}. Any number of commands may be defined in the same file, and they would all have access to the same flags and environment. A command so defined is not executed unless it is invoked via @racket[run].

  @racketblock[
    (program (contact-hosts [admin "Your name"])
      (displayln (~a "Hello, " admin "!"))
      (define result 0)
      (for-each (λ (link)
                  (when (contact-host link (attempts))
                    (set! result (add1 result))))
                (links))
      (displayln (~a "Done. Result: " result " hosts contacted.")))
  ]

@margin-note{Although the function defined using @racket[program] appears to accept the arguments you indicate, in reality, it accepts raw command line arguments as a @racketlink[current-command-line-arguments]{vector of strings} which are parsed into the arguments you expect prior to your using them in the body of the function. Thus, if you called this function directly (for instance, mistakenly assuming it to be another function with the same name), you would get the following inscrutable error: @racket[parse-command-line: expected argument of type <argument vector/list of strings>]. As commands are just functions, they must have distinct names from other identifiers in scope in order to avoid shadowing them.}
}

@defform/subs[(run program-instance)
              ([program-instance (code:line name)
                                 (code:line name argv)])
]{
  Run a command. Any command defined via @racket[program] may be indicated here. The command need not be defined in the same module -- since programs are just functions, they could be defined anywhere and simply @racketlink[require]{required} in order to make them available for execution.

  By default, @racket[run] passes the @racketlink[current-command-line-arguments]{current command line arguments} to the command, but you could also override this by providing a vector of strings representing a command line invocation, which may be useful @seclink["Testing_Your_Script" #:doc '(lib "cli/scribblings/cli.scrbl")]{for testing}.

  @racketblock[
    (run contact-hosts)
    (run contact-hosts #("-a" "3" "George"))
  ]
}

@section{Interoperating with Racket}

In addition to the forms above, the language includes all of @racket[racket/base], so that you may @racket[require] any identifiers that may be needed in your command line script. You may also freely intersperse and use Racket code within the @racket[cli] module.

@section{Implementation}

This library internally leverages Racket's built-in command line facilities including @racket[parse-command-line] for core functionality, and @racket[current-command-line-arguments] for arguments parsed from the command line. The functionality provided by this library therefore includes all of the functionality of the core interfaces.

@section{Testing Your Script}

The @racket[program] form syntactically resembles and indeed compiles to a simple function, and so can be tested just like any other function. But since command line scripts do not typically return values, it would probably make the most sense to put any business logic in vanilla (non-CLI) functions which are independently unit-tested, with the @racket[program] form dispatching to those functions.

Even so, it can be useful during development and even for "smoke" tests to be able to run your script programmatically. To do this, simply pass the arguments and flags that you would on the command line to the @racket[run] form as a @racketlink[current-command-line-arguments]{vector of strings}, like @racket[(run contact-hosts #("-a" "3" "George"))]. Note that each value in the vector @emph{must} be a string, even if you use it as another data type (such as a number) in the body of your program form.

Finally, bear in mind that as passing @racketlink[flag]{flags} to a command results in @seclink["parameterize" #:doc '(lib "scribblings/guide/guide.scrbl")]{parameters} being set, which are @emph{dynamically} rather than lexically bound, commands correspond to a dynamic runtime state. Therefore, if you plan on running a command in a test module more than once, you should do so with care since it may produce different results on a subsequent invocation depending on this varying dynamic state.
