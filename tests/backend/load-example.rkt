#lang racket/base
;; Materializes example references and direct-emitter MLIR for external tests.

(require racket/file
         racket/match)

(match (vector->list (current-command-line-arguments))
  [(list* "materialize" output-directory specifications)
   (define emit-circt
     (dynamic-require "rhodium/backend/circt.rhm" 'emit_circt))
   (make-directory* output-directory)
   (let loop ([remaining specifications])
     (match remaining
       ['() (void)]
       [(list* "example" fixture example-path design-export reference-export rest)
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
       [(list* "emitter" fixture emitter-path rest)
        (call-with-output-file
         (build-path output-directory (string-append fixture ".mlir"))
         #:exists 'truncate/replace
         (lambda (out)
           (parameterize ([current-output-port out])
             (dynamic-require emitter-path #f))))
        (loop rest)]
       [_
        (raise-user-error
         'load-example
         "each fixture must be tagged as example or emitter")]))]
  [_
   (raise-user-error
    'load-example
    "expected: materialize OUTPUT-DIRECTORY (example FIXTURE EXAMPLE DESIGN-EXPORT REFERENCE-EXPORT | emitter FIXTURE EMITTER) ...")])
