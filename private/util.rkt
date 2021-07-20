#lang racket/base

(require racket/list)

(provide remove-at)

(define (remove-at seq pos)
  (append (take seq pos)
          (drop seq (add1 pos))))
