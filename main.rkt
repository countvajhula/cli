#lang racket/base

(module reader racket/base
  (require cli/reader)
  (provide (all-from-out cli/reader)))
