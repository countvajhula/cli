#lang cli

(provide doc)

(help (usage "A script to say hello." "It also validates any provided links.")
      (labels "A label" "Another label")
      (ps "Goodbye!"))

(program (doc [arg "A documented argument"])
  "Dinah")
