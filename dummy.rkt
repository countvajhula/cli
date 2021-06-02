#!/usr/bin/env racket
#lang reader "clilang.rkt"

(program "dum dum")

(usage-help "This is a fun script.")

(flag length
      ("-l" "--length")
      "Length to search up to"
      (λ (~l)
        (length ~l)))

(flag depth
      (one-of ("-d"
               "--depth"
               "Depth to search up to"
               (λ (~d)
                 (depth ~d)))
              ("-g"
               "--height"
               "Height to search up to"
               (λ (~h)
                 (depth ~h)))))

(flag width
      (one-of ("-w"
               "--width"
               "Width to search up to"
               (λ (~w)
                 (width ~w)))
              ("-b"
               "--breadth"
               "Breadth to search up to"
               (λ (~b)
                 (width ~b)))))

(run ()
     (displayln "Hello there!")
     (displayln ~once-each)
     (displayln ~once-any)
     (displayln (length))
     (displayln (depth))
     (displayln (width)))
