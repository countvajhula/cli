#lang info
(define collection "cli")
(define deps '("base"))
(define build-deps '("scribble-lib"
                     "scribble-abbrevs"
                     "racket-doc"
                     "rackunit-lib"
                     "cover"
                     "cover-coveralls"
                     "sandbox-lib"))
(define scribblings '(("scribblings/cli.scrbl" ())))
(define compile-omit-paths '("dev" "tests" "coverage"))
(define test-include-paths '("tests"))
(define test-omit-paths '("dev" "coverage"))
(define clean '("compiled" "doc" "doc/cli" "private/compiled"))
(define pkg-desc "A language for writing Command Line Interfaces")
(define version "0.0")
(define pkg-authors '(countvajhula))
