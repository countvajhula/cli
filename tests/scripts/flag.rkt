#lang cli

(provide greeting)

(flag (verbose)
  ("-v" "--verbose" "Show detailed messages.")
  (verbose #t))

(program (greeting)
  (if (verbose) "hello" "hi"))
