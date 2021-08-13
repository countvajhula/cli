#lang cli

(provide rules)

(flag (once)
  ("-o" "--once" "A flag that can appear only once.")
  (once #t))

(flag (f)
  ("-f" "--flag-f" "A flag in a set.")
  (f #t))

(flag (g)
  ("-g" "--flag-g" "A flag in a set.")
  (g #t))

(flag (m)
  ("-m" "--flag-m" "A flag that can appear multiple times.")
  (m #t))

(constraint (one-of f g))

(constraint (multi m))

(program (rules)
  #t)
