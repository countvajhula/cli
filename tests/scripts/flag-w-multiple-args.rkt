#lang cli

(provide reconnect)

(flag (delay #:param [delay '(1 3)] time-sec factor)
  ("-d" "--delay" "Base time in seconds and backoff factor")
  (delay (map string->number (list time-sec factor))))

(program (reconnect)
  (delay))
