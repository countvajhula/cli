#lang racket/base

(require cli
         rackunit
         rackunit/text-ui
         (only-in racket/function [thunk f:thunk]))

(require "test-scripts.rkt")

(define tests
  (test-suite
   "cli tests"

   (test-case
       "script with help metadata (smoke test - no functionality)"
     (check-equal? (run doc #("blah")) "Dinah"))

   (test-case
       "script taking no arguments"
     (check-equal? (run thunk #()) "Dinah"))

   (test-case
       "script taking arguments"
     (check-equal? (run echo #("Dinah")) "Dinah"))

   (test-case
       "script accepting a flag with no arguments"
     ;; note that the param value being dynamically bound
     ;; means that re-running these tests manually won't
     ;; necessarily produce the same results - in particular
     ;; passing no flag does not change the existing value
     (check-equal? (run greeting #()) "hi")
     (check-equal? (run greeting #("-v")) "hello"))

   (test-case
       "script accepting a flag with arguments"
     ;; see note above re: reproducibility and dynamic binding
     (check-equal? (run contact #()) 1) ; default number of attempts in the script
     (check-equal? (run contact #("-a" "3")) 3))

   (test-case
       "flag constraints"
     (check-equal? (run rules #()) #t)
     (check-equal? (run rules #("-o")) #t)
     (check-exn exn:fail? (f:thunk (run rules #("-o" "-o"))))
     (check-equal? (run rules #("-f")) #t)
     (check-equal? (run rules #("-g")) #t)
     (check-exn exn:fail? (f:thunk (run rules #("-f" "-g"))))
     (check-equal? (run rules #("-m")) #t)
     (check-equal? (run rules #("-m" "-m")) #t)
     (check-equal? (run rules #("-m" "-m" "-m")) #t))))

(module+ test
  (void
   (run-tests tests)))
