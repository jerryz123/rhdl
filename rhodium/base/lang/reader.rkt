#lang racket/base
;; Exposes the nested #lang rhodium/base reader through Racket's conventional lang/reader path.

(require (submod "../main.rkt" reader))

(provide (all-from-out (submod "../main.rkt" reader)))
