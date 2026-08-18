#lang racket/base
;; Exhaustively checks the Rosette engine's packed combinational semantics and query results.

(require rackunit
         racket/list
         "../../rhdl/formal/engine.rkt")

(define (flat-type width [text #f])
  (hash "kind" "flat"
        "text" (or text (format "bits<~a>" width))
        "width" width))

(define (value-snapshot id name type operation-id)
  (hash "id" id
        "name" name
        "type" type
        "defining_operation" operation-id))

(define (port-snapshot name direction type #:value [value #f]
                       #:place [place #f] #:driver [driver #f])
  (hash "name" name
        "direction" direction
        "type" type
        "value" value
        "place" place
        "driver" driver))

(define (place-snapshot id name type owner driver)
  (hash "id" id
        "name" name
        "type" type
        "owner_operation" owner
        "driver" driver))

(define (operation-snapshot id opcode operands results places [attributes (hash)])
  (hash "id" id
        "opcode" opcode
        "operands" operands
        "results" results
        "places" places
        "attributes" attributes
        "location" (format "engine-test:~a" id)
        "origin" (format "engine-test(~a)" opcode)))

(define (module-snapshot id name inputs outputs values places operations)
  (hash "id" id
        "name" name
        "inputs" inputs
        "outputs" outputs
        "values" values
        "places" places
        "operations" operations))

(define (single-module-snapshot module)
  (hash "version" 1 "top" (hash-ref module "id") "modules" (list module)))

(define (operation-design opcode input-types result-type [attributes (hash)])
  (define input-values
    (for/list ([type (in-list input-types)] [index (in-naturals)])
      (value-snapshot (+ 10 index) (format "x~a" index) type (+ 100 index))))
  (define input-ports
    (for/list ([type (in-list input-types)] [index (in-naturals)])
      (port-snapshot (format "x~a" index) "input" type #:value (+ 10 index))))
  (define input-operations
    (for/list ([index (in-range (length input-types))])
      (operation-snapshot (+ 100 index) "rtl.input_port" '() (list (+ 10 index)) '())))
  (define result-id 1000)
  (define result-operation-id 1100)
  (define output-place-id 1200)
  (define output-operation-id 1300)
  (define drive-operation-id 1400)
  (define result-value (value-snapshot result-id "y" result-type result-operation-id))
  (define output-place
    (place-snapshot output-place-id "y" result-type output-operation-id result-id))
  (define module
    (module-snapshot
     1
     "Operation"
     input-ports
     (list (port-snapshot "y" "output" result-type
                          #:place output-place-id #:driver result-id))
     (append input-values (list result-value))
     (list output-place)
     (append input-operations
             (list (operation-snapshot result-operation-id opcode
                                       (map (lambda (value) (hash-ref value "id")) input-values)
                                       (list result-id) '() attributes)
                   (operation-snapshot output-operation-id "rtl.output_port"
                                       '() '() (list output-place-id))
                   (operation-snapshot drive-operation-id "rtl.drive"
                                       (list result-id) '() (list output-place-id))))))
  (single-module-snapshot module))

(define (run-operation opcode widths inputs
                       #:result-width [result-width (car widths)]
                       #:attributes [attributes (hash)])
  (define snapshot
    (operation-design opcode (map flat-type widths) (flat-type result-width) attributes))
  (hash-ref
   (interpret_snapshot
    snapshot
    (for/hash ([value (in-list inputs)] [index (in-naturals)])
      (values (format "x~a" index) value)))
   "y"))

(define (mask width)
  (sub1 (arithmetic-shift 1 width)))

(define (truncate value width)
  (bitwise-and value (mask width)))

(define (signed-value value width)
  (if (bitwise-bit-set? value (sub1 width))
      (- value (arithmetic-shift 1 width))
      value))

(define same-width-binary-oracles
  (list (cons "rtl.and" bitwise-and)
        (cons "rtl.or" bitwise-ior)
        (cons "rtl.xor" bitwise-xor)
        (cons "rtl.add" +)
        (cons "rtl.mul" *)
        (cons "rtl.sub" -)))

(for* ([width (in-range 1 5)]
       [operation+oracle (in-list same-width-binary-oracles)]
       [left (in-range (arithmetic-shift 1 width))]
       [right (in-range (arithmetic-shift 1 width))])
  (define opcode (car operation+oracle))
  (define oracle (cdr operation+oracle))
  (check-equal? (run-operation opcode (list width width) (list left right))
                (truncate (oracle left right) width)
                (format "~a width ~a inputs ~a ~a" opcode width left right)))

(for* ([width (in-range 1 5)]
       [value (in-range (arithmetic-shift 1 width))])
  (check-equal? (run-operation "rtl.not" (list width) (list value))
                (truncate (bitwise-not value) width)))

(define comparison-oracles
  (list (cons "rtl.eq" =)
        (cons "rtl.ult" <)
        (cons "rtl.slt"
              (lambda (left right width)
                (< (signed-value left width) (signed-value right width))))))

(for* ([width (in-range 1 5)]
       [operation+oracle (in-list comparison-oracles)]
       [left (in-range (arithmetic-shift 1 width))]
       [right (in-range (arithmetic-shift 1 width))])
  (define opcode (car operation+oracle))
  (define oracle (cdr operation+oracle))
  (define expected
    (if (equal? opcode "rtl.slt")
        (oracle left right width)
        (oracle left right)))
  (check-equal? (run-operation opcode (list width width) (list left right)
                               #:result-width 1)
                (if expected 1 0)))

(for* ([value-width (in-range 1 5)]
       [amount-width (in-range 1 5)]
       [value (in-range (arithmetic-shift 1 value-width))]
       [amount (in-range (arithmetic-shift 1 amount-width))])
  (check-equal? (run-operation "rtl.shl" (list value-width amount-width)
                               (list value amount))
                (truncate (arithmetic-shift value amount) value-width))
  (check-equal? (run-operation "rtl.shru" (list value-width amount-width)
                               (list value amount))
                (arithmetic-shift value (- amount)))
  (check-equal? (run-operation "rtl.shrs" (list value-width amount-width)
                               (list value amount))
                (truncate (arithmetic-shift (signed-value value value-width) (- amount))
                          value-width)))

(for* ([left-width (in-range 1 4)]
       [right-width (in-range 1 4)]
       [left (in-range (arithmetic-shift 1 left-width))]
       [right (in-range (arithmetic-shift 1 right-width))])
  (check-equal? (run-operation "rtl.concat" (list left-width right-width)
                               (list left right)
                               #:result-width (+ left-width right-width))
                (bitwise-ior (arithmetic-shift left right-width) right)))

(for* ([source-width (in-range 2 5)]
       [low (in-range source-width)]
       [high (in-range low source-width)]
       [value (in-range (arithmetic-shift 1 source-width))])
  (define result-width (add1 (- high low)))
  (check-equal? (run-operation "rtl.extract" (list source-width) (list value)
                               #:result-width result-width
                               #:attributes (hash "high" high "low" low))
                (truncate (arithmetic-shift value (- low)) result-width)))

(for* ([source-width (in-range 1 4)]
       [target-width (in-range (add1 source-width) 5)]
       [value (in-range (arithmetic-shift 1 source-width))])
  (check-equal? (run-operation "rtl.zext" (list source-width) (list value)
                               #:result-width target-width
                               #:attributes (hash "target_width" target-width))
                value)
  (check-equal? (run-operation "rtl.sext" (list source-width) (list value)
                               #:result-width target-width
                               #:attributes (hash "target_width" target-width))
                (truncate (signed-value value source-width) target-width)))

(for* ([source-width (in-range 2 5)]
       [target-width (in-range 1 source-width)]
       [value (in-range (arithmetic-shift 1 source-width))])
  (check-equal? (run-operation "rtl.trunc" (list source-width) (list value)
                               #:result-width target-width
                               #:attributes (hash "target_width" target-width))
                (truncate value target-width)))

(for* ([width (in-range 1 5)]
       [value (in-range (arithmetic-shift 1 width))])
  (check-equal? (run-operation "rtl.cast" (list width) (list value)) value))

(for* ([width (in-range 1 5)]
       [value (in-range (arithmetic-shift 1 width))])
  (check-equal? (run-operation "rtl.constant" '() '()
                               #:result-width width
                               #:attributes (hash "value" value))
                value))

(define mux-snapshot
  (operation-design "rtl.mux_lookup"
                    (list (flat-type 2) (flat-type 3) (flat-type 3) (flat-type 3))
                    (flat-type 3)
                    (hash "keys" (list 0 2))))
(for* ([selector (in-range 4)] [default (in-range 8)]
       [zero-choice (in-range 8)] [two-choice (in-range 8)])
  (check-equal?
   (hash-ref (interpret_snapshot mux-snapshot
                                 (hash "x0" selector "x1" default
                                       "x2" zero-choice "x3" two-choice))
             "y")
   (cond [(= selector 0) zero-choice]
         [(= selector 2) two-choice]
         [else default])))

(define record-type
  (hash "kind" "record" "text" "record<a: bits<2>, b: bits<3>>" "width" 5
        "fields" (list (hash "name" "a" "type" (flat-type 2))
                       (hash "name" "b" "type" (flat-type 3)))))
(define record-create
  (operation-design "rtl.record_create" (list (flat-type 2) (flat-type 3))
                    record-type (hash "fields" (list "a" "b"))))
(for* ([a (in-range 4)] [b (in-range 8)])
  (check-equal? (hash-ref (interpret_snapshot record-create (hash "x0" a "x1" b)) "y")
                (+ (arithmetic-shift a 3) b)))
(define record-high
  (operation-design "rtl.record_get" (list record-type) (flat-type 2)
                    (hash "field" "a")))
(define record-low
  (operation-design "rtl.record_get" (list record-type) (flat-type 3)
                    (hash "field" "b")))
(for ([packed (in-range 32)])
  (check-equal? (hash-ref (interpret_snapshot record-high (hash "x0" packed)) "y")
                (arithmetic-shift packed -3))
  (check-equal? (hash-ref (interpret_snapshot record-low (hash "x0" packed)) "y")
                (truncate packed 3)))

(define vector-type
  (hash "kind" "vector" "text" "vec<3, bits<2>>" "width" 6 "length" 3
        "element_type" (flat-type 2)))
(define vector-create
  (operation-design "rtl.vector_create"
                    (list (flat-type 2) (flat-type 2) (flat-type 2)) vector-type))
(for* ([x0 (in-range 4)] [x1 (in-range 4)] [x2 (in-range 4)])
  (check-equal? (hash-ref (interpret_snapshot vector-create
                                               (hash "x0" x0 "x1" x1 "x2" x2))
                          "y")
                (+ x0 (arithmetic-shift x1 2) (arithmetic-shift x2 4))))
(for ([index (in-range 3)])
  (define vector-element
    (operation-design "rtl.vector_get" (list vector-type) (flat-type 2)
                      (hash "index" index)))
  (for ([packed (in-range 64)])
    (check-equal? (hash-ref (interpret_snapshot vector-element (hash "x0" packed)) "y")
                  (truncate (arithmetic-shift packed (* -2 index)) 2))))

(define wire-type (flat-type 3))
(define wire-design
  (single-module-snapshot
   (module-snapshot
    1 "ForwardWire"
    (list (port-snapshot "x" "input" wire-type #:value 10))
    (list (port-snapshot "y" "output" wire-type #:place 1201 #:driver 1000))
    (list (value-snapshot 10 "x" wire-type 100)
          (value-snapshot 1000 "forward" wire-type 1100))
    (list (place-snapshot 1200 "forward" wire-type 1100 10)
          (place-snapshot 1201 "y" wire-type 1300 1000))
    (list (operation-snapshot 100 "rtl.input_port" '() '(10) '())
          (operation-snapshot 1100 "rtl.wire" '() '(1000) '(1200))
          (operation-snapshot 1300 "rtl.output_port" '() '() '(1201))
          (operation-snapshot 1400 "rtl.drive" '(1000) '() '(1201))))))
(for ([value (in-range 8)])
  (check-equal? (hash-ref (interpret_snapshot wire-design (hash "x" value)) "y") value))

(define add-design
  (operation-design "rtl.add" (list (flat-type 4) (flat-type 4)) (flat-type 4)))
(define reversed-add-design
  (operation-design "rtl.add" (list (flat-type 4) (flat-type 4)) (flat-type 4)))
(define sub-design
  (operation-design "rtl.sub" (list (flat-type 4) (flat-type 4)) (flat-type 4)))
(check-equal? (engine_result_status
               (check_equivalent_snapshots add-design reversed-add-design))
              "equivalent")
(define counterexample (check_equivalent_snapshots add-design sub-design))
(check-equal? (engine_result_status counterexample) "counterexample")
(define replay-inputs
  (for/hash ([entry (in-list (engine_result_inputs counterexample))])
    (values (hash-ref entry "port") (hash-ref entry "value"))))
(check-not-equal? (hash-ref (interpret_snapshot add-design replay-inputs) "y")
                  (hash-ref (interpret_snapshot sub-design replay-inputs) "y"))
(define unknown-result
  (check_equivalent_snapshots add-design add-design
                              #:solve (lambda (_mismatch) 'forced-unknown)))
(check-equal? (engine_result_status unknown-result) "unknown")
(check-true (regexp-match? #rx"unknown" (engine_result_message unknown-result)))

(for ([opcode (in-list '("rtl.dont_care" "rtl.decode" "rtl.onehot_mux"
                          "rtl.register" "rtl.memory" "rtl.memory_write"
                          "verif.assert" "sim.dpi_call" "unknown.operation"))])
  (define rejected
    (preflight_snapshot
     (operation-design opcode (list (flat-type 1)) (flat-type 1))))
  (check-equal? (engine_result_status rejected) "unsupported")
  (check-equal? (hash-ref (engine_result_diagnostic rejected) "opcode") opcode)
  (check-true (regexp-match? #rx"does not support" (engine_result_message rejected))))

(define solver-called? #f)
(define unsupported-query-result
  (check_equivalent_snapshots
   (operation-design "rtl.dont_care" (list (flat-type 1)) (flat-type 1))
   (operation-design "rtl.dont_care" (list (flat-type 1)) (flat-type 1))
   #:solve (lambda (_mismatch) (set! solver-called? #t) 'forced-unknown)))
(check-equal? (engine_result_status unsupported-query-result) "unsupported")
(check-false solver-called?)

(check-exn #rx"missing required field"
           (lambda ()
             (preflight_snapshot
              (operation-design "rtl.extract" (list (flat-type 2)) (flat-type 1)))))
