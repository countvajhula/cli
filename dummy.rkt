#!/usr/bin/env racket
#lang reader "clilang.rkt"

(program "dum dum")

(usage-help "This is a fun script.")

(flag depth
      ("-d" "--depth")
      "Depth to search up to"
      (λ (~d)
        (depth ~d)))

(run ()
     (displayln "Hello there!")
     (displayln ~once-each)
     (displayln (depth)))
