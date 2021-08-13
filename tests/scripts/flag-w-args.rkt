#lang cli

(provide contact)

(flag (attempts #:param [attempts 1] n)
  ("-a" "--attempts" "Number of attempts to make")
  (attempts (string->number n)))

(program (contact)
  (attempts))
