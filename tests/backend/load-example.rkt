#lang racket/base
;; Materializes example designs and colocated Verilog references for shell tests.

(require racket/file
         racket/match)

(match (vector->list (current-command-line-arguments))
  [(list* "materialize" output-directory specifications)
   (define emit-circt
     (dynamic-require "rhdl/backend/circt.rhm" 'emit_circt))
   (make-directory* output-directory)
   (let loop ([remaining specifications])
     (match remaining
       ['() (void)]
       [(list* fixture example-path design-export reference-export rest)
        (define design
          (dynamic-require example-path (string->symbol design-export)))
        (define reference
          (dynamic-require example-path (string->symbol reference-export)))
        (call-with-output-file
         (build-path output-directory (string-append fixture ".mlir"))
         #:exists 'truncate/replace
         (lambda (out) (display (emit-circt design) out)))
        (call-with-output-file
         (build-path output-directory (string-append fixture ".expected.sv"))
         #:exists 'truncate/replace
         (lambda (out) (display reference out)))
        (loop rest)]
       [_
        (raise-user-error
         'load-example
         "each fixture needs EXAMPLE DESIGN-EXPORT REFERENCE-EXPORT")]))]
  [_
   (raise-user-error
    'load-example
    "expected: materialize OUTPUT-DIRECTORY FIXTURE EXAMPLE DESIGN-EXPORT REFERENCE-EXPORT ...")])
