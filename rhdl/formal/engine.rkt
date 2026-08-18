#lang rosette
;; Interprets immutable verified RHDL snapshots with Rosette and checks combinational equivalence.

(require racket/list
         racket/match
         racket/set)

(provide check_equivalent_snapshots
         interpret_snapshot
         preflight_snapshot
         engine_result_status
         engine_result_message
         engine_result_inputs
         engine_result_differences
         engine_result_diagnostic)

(struct formal-engine-result (status message inputs differences diagnostic) #:transparent)
(struct exn:fail:formal:unsupported exn:fail (diagnostic) #:transparent)

(define supported-opcodes
  (set "rtl.input_port"
       "rtl.output_port"
       "rtl.wire"
       "rtl.drive"
       "rtl.instance"
       "rtl.constant"
       "rtl.not"
       "rtl.and"
       "rtl.or"
       "rtl.xor"
       "rtl.add"
       "rtl.mul"
       "rtl.sub"
       "rtl.shl"
       "rtl.shru"
       "rtl.shrs"
       "rtl.eq"
       "rtl.ult"
       "rtl.slt"
       "rtl.mux_lookup"
       "rtl.cast"
       "rtl.concat"
       "rtl.extract"
       "rtl.zext"
       "rtl.sext"
       "rtl.trunc"
       "rtl.record_create"
       "rtl.record_get"
       "rtl.vector_create"
       "rtl.vector_get"))

(define (engine_result_status result)
  (formal-engine-result-status result))

(define (engine_result_message result)
  (formal-engine-result-message result))

(define (engine_result_inputs result)
  (formal-engine-result-inputs result))

(define (engine_result_differences result)
  (formal-engine-result-differences result))

(define (engine_result_diagnostic result)
  (formal-engine-result-diagnostic result))

(define (required hash key [context "snapshot"])
  (hash-ref hash key
            (lambda ()
              (error 'rhdl-formal "~a is missing required field ~s" context key))))

(define (find-by-id values id context)
  (or (findf (lambda (value) (equal? (required value "id" context) id)) values)
      (error 'rhdl-formal "~a references missing id ~a" context id)))

(define (find-module snapshot id)
  (find-by-id (required snapshot "modules" "formal snapshot") id "module"))

(define (diagnostic module operation message [path #f])
  (hash "module" (and module (required module "name" "module"))
        "module_path" (or path (and module (required module "name" "module")))
        "opcode" (and operation (required operation "opcode" "operation"))
        "operation_id" (and operation (required operation "id" "operation"))
        "location" (and operation (required operation "location" "operation"))
        "origin" (and operation (required operation "origin" "operation"))
        "message" message))

(define (unsupported module operation message [path #f])
  (raise
   (exn:fail:formal:unsupported
    message
    (current-continuation-marks)
    (diagnostic module operation message path))))

(define (positive-width type module [operation #f])
  (define kind (required type "kind" "type"))
  (define width (required type "width" "type"))
  (unless (and (member kind '("flat" "record" "vector"))
               (exact-positive-integer? width))
    (unsupported module operation
                 (format "formal engine does not support hardware type ~a"
                         (required type "text" "type"))))
  width)

(define (validate-type type module [operation #f])
  (positive-width type module operation)
  (match (required type "kind" "type")
    ["record"
     (for ([field (in-list (required type "fields" "record type"))])
       (required field "name" "record field")
       (validate-type (required field "type" "record field") module operation))]
    ["vector"
     (unless (exact-positive-integer? (required type "length" "vector type"))
       (error 'rhdl-formal "vector snapshot has invalid length"))
     (validate-type (required type "element_type" "vector type") module operation)]
    [_ (void)]))

(define (validate-operation module operation module-ids)
  (define opcode (required operation "opcode" "operation"))
  (unless (set-member? supported-opcodes opcode)
    (unsupported module operation
                 (format "formal milestone 1 does not support operation ~a" opcode)))
  (define operands (required operation "operands" "operation"))
  (define results (required operation "results" "operation"))
  (define places (required operation "places" "operation"))
  (define attributes (required operation "attributes" "operation"))
  (define (arity expected-operands expected-results expected-places)
    (unless (and (or (not expected-operands) (= (length operands) expected-operands))
                 (or (not expected-results) (= (length results) expected-results))
                 (or (not expected-places) (= (length places) expected-places)))
      (error 'rhdl-formal "operation ~a has malformed snapshot arity" opcode)))
  (match opcode
    [(or "rtl.input_port") (arity 0 1 0)]
    [(or "rtl.output_port") (arity 0 0 1)]
    [(or "rtl.wire") (arity 0 1 1)]
    [(or "rtl.drive") (arity 1 0 1)]
    [(or "rtl.constant")
     (arity 0 1 0)
     (required attributes "value" "constant attributes")]
    [(or "rtl.not" "rtl.cast") (arity 1 1 0)]
    ["rtl.extract"
     (arity 1 1 0)
     (required attributes "high" "extract attributes")
     (required attributes "low" "extract attributes")]
    [(or "rtl.zext" "rtl.sext" "rtl.trunc")
     (arity 1 1 0)
     (required attributes "target_width" "extension or truncation attributes")]
    ["rtl.record_get"
     (arity 1 1 0)
     (required attributes "field" "record projection attributes")]
    ["rtl.vector_get"
     (arity 1 1 0)
     (required attributes "index" "vector projection attributes")]
    [(or "rtl.and" "rtl.or" "rtl.xor" "rtl.add" "rtl.mul" "rtl.sub"
         "rtl.shl" "rtl.shru" "rtl.shrs" "rtl.eq" "rtl.ult" "rtl.slt")
     (arity 2 1 0)]
    [(or "rtl.mux_lookup")
     (arity #f 1 0)
     (define keys (required attributes "keys" "mux attributes"))
     (unless (and (>= (length operands) 3)
                  (= (length keys) (- (length operands) 2)))
       (error 'rhdl-formal "mux snapshot has inconsistent keys and operands"))]
    [(or "rtl.concat")
     (arity #f 1 0)
     (unless (>= (length operands) 2)
       (error 'rhdl-formal "concat snapshot has fewer than two operands"))]
    ["rtl.record_create"
     (arity #f 1 0)
     (unless (positive? (length operands))
       (error 'rhdl-formal "record construction snapshot has no operands"))
     (unless (= (length (required attributes "fields" "record construction attributes"))
                (length operands))
       (error 'rhdl-formal "record snapshot has inconsistent fields and operands"))]
    ["rtl.vector_create"
     (arity #f 1 0)
     (unless (positive? (length operands))
       (error 'rhdl-formal "vector construction snapshot has no operands"))]
    ["rtl.instance"
     (arity 0 #f #f)
     (define child-id (required attributes "child_module" "instance attributes"))
     (required attributes "name" "instance attributes")
     (unless (set-member? module-ids child-id)
       (error 'rhdl-formal "instance references missing child module ~a" child-id))]
    [_ (void)]))

(define (validate-module snapshot module)
  (for ([port (in-list (append (required module "inputs" "module")
                               (required module "outputs" "module")))])
    (validate-type (required port "type" "port") module))
  (for ([value (in-list (required module "values" "module"))])
    (validate-type (required value "type" "value") module))
  (for ([place (in-list (required module "places" "module"))])
    (validate-type (required place "type" "place") module)
    (unless (exact-nonnegative-integer? (required place "driver" "place"))
      (error 'rhdl-formal "place ~a has no final driver"
             (required place "name" "place"))))
  (define module-ids
    (for/set ([candidate (in-list (required snapshot "modules" "formal snapshot"))])
      (required candidate "id" "module")))
  (for ([operation (in-list (required module "operations" "module"))])
    (validate-operation module operation module-ids)))

(define (validate-snapshot snapshot)
  (unless (= (required snapshot "version" "formal snapshot") 1)
    (error 'rhdl-formal "unsupported formal snapshot version"))
  (define modules (required snapshot "modules" "formal snapshot"))
  (unless (pair? modules)
    (error 'rhdl-formal "formal snapshot has no modules"))
  (find-module snapshot (required snapshot "top" "formal snapshot"))
  (for ([module (in-list modules)])
    (validate-module snapshot module))
  #t)

(define (preflight_snapshot snapshot)
  (with-handlers ([exn:fail:formal:unsupported?
                   (lambda (exception)
                     (formal-engine-result
                      "unsupported"
                      (exn-message exception)
                      '()
                      '()
                      (exn:fail:formal:unsupported-diagnostic exception)))])
    (validate-snapshot snapshot)
    #f))

(define (type-width type)
  (required type "width" "type"))

(define (value-width value)
  (type-width (required value "type" "value")))

(define (module-value module id)
  (find-by-id (required module "values" "module") id "value"))

(define (module-place module id)
  (find-by-id (required module "places" "module") id "place"))

(define (operation-attribute operation name)
  (required (required operation "attributes" "operation") name "operation attributes"))

(define (bv-boolean condition)
  (if condition (bv 1 1) (bv 0 1)))

(define (pack-concat values)
  (if (= (length values) 1)
      (car values)
      (apply concat values)))

(define (normalize-shift opcode value amount value-width amount-width)
  (define shift
    (match opcode
      ["rtl.shl" bvshl]
      ["rtl.shru" bvlshr]
      ["rtl.shrs" bvashr]))
  (cond
    [(= value-width amount-width) (shift value amount)]
    [(< amount-width value-width)
     (shift value (zero-extend amount (bitvector value-width)))]
    [else
     (define widened
       (if (equal? opcode "rtl.shrs")
           (sign-extend value (bitvector amount-width))
           (zero-extend value (bitvector amount-width))))
     (extract (sub1 value-width) 0 (shift widened amount))]))

(define (record-field-range type field-name)
  (define total (type-width type))
  (let loop ([fields (required type "fields" "record type")]
             [consumed 0])
    (unless (pair? fields)
      (error 'rhdl-formal "record snapshot has no field named ~a" field-name))
    (define field (car fields))
    (define width (type-width (required field "type" "record field")))
    (if (equal? (required field "name" "record field") field-name)
        (values (- total consumed 1) (- total consumed width))
        (loop (cdr fields) (+ consumed width)))))

(define (interpret-module snapshot module-id input-values path)
  (define module (find-module snapshot module-id))
  (define value-snapshots (required module "values" "module"))
  (define place-snapshots (required module "places" "module"))
  (define operations (required module "operations" "module"))
  (define environment (make-hash))
  (define memo (make-hash))
  (define active (mutable-set))
  (define instance-cache (make-hash))
  (define result-operations (make-hash))
  (for ([operation (in-list operations)])
    (for ([result-id (in-list (required operation "results" "operation"))])
      (hash-set! result-operations result-id operation)))
  (for ([port (in-list (required module "inputs" "module"))])
    (define name (required port "name" "input port"))
    (define value-id (required port "value" "input port"))
    (unless (hash-has-key? input-values name)
      (error 'rhdl-formal "module ~a is missing input ~a" path name))
    (hash-set! environment value-id (hash-ref input-values name)))

  (define (eval-value id)
    (cond
      [(hash-has-key? environment id) (hash-ref environment id)]
      [(hash-has-key? memo id) (hash-ref memo id)]
      [(set-member? active id)
       (error 'rhdl-formal "malformed snapshot contains recursive value dependency ~a" id)]
      [else
       (set-add! active id)
       (define operation
         (hash-ref result-operations id
                   (lambda ()
                     (error 'rhdl-formal "value ~a has no defining operation" id))))
       (define result (eval-operation operation id))
       (set-remove! active id)
       (hash-set! memo id result)
       result]))

  (define (operand-values operation)
    (map eval-value (required operation "operands" "operation")))

  (define (eval-instance operation result-id)
    (define operation-id (required operation "id" "instance"))
    (unless (hash-has-key? instance-cache operation-id)
      (define child-id (operation-attribute operation "child_module"))
      (define child (find-module snapshot child-id))
      (define child-inputs (required child "inputs" "child module"))
      (define instance-places (required operation "places" "instance"))
      (unless (= (length child-inputs) (length instance-places))
        (error 'rhdl-formal "instance input count does not match child module"))
      (define child-values
        (for/hash ([port (in-list child-inputs)]
                   [place-id (in-list instance-places)])
          (define place (module-place module place-id))
          (values (required port "name" "child input")
                  (eval-value (required place "driver" "instance input place")))))
      (define instance-name (operation-attribute operation "name"))
      (define child-outputs
        (interpret-module snapshot child-id child-values
                          (string-append path "." instance-name)))
      (define result-ids (required operation "results" "instance"))
      (define output-ports (required child "outputs" "child module"))
      (unless (= (length result-ids) (length output-ports))
        (error 'rhdl-formal "instance output count does not match child module"))
      (hash-set!
       instance-cache
       operation-id
       (for/hash ([id (in-list result-ids)]
                  [port (in-list output-ports)])
         (values id (hash-ref child-outputs (required port "name" "child output"))))))
    (hash-ref (hash-ref instance-cache operation-id) result-id))

  (define (eval-operation operation result-id)
    (define opcode (required operation "opcode" "operation"))
    (define operands (operand-values operation))
    (define result-value (module-value module result-id))
    (define result-width (value-width result-value))
    (match opcode
      ["rtl.input_port"
       (error 'rhdl-formal "input value ~a was not bound" result-id)]
      ["rtl.wire"
       (define place-id (car (required operation "places" "wire")))
       (eval-value (required (module-place module place-id) "driver" "wire place"))]
      ["rtl.instance" (eval-instance operation result-id)]
      ["rtl.constant" (bv (operation-attribute operation "value") result-width)]
      ["rtl.not" (bvnot (car operands))]
      ["rtl.and" (bvand (first operands) (second operands))]
      ["rtl.or" (bvor (first operands) (second operands))]
      ["rtl.xor" (bvxor (first operands) (second operands))]
      ["rtl.add" (bvadd (first operands) (second operands))]
      ["rtl.mul" (bvmul (first operands) (second operands))]
      ["rtl.sub" (bvsub (first operands) (second operands))]
      [(or "rtl.shl" "rtl.shru" "rtl.shrs")
       (define operand-ids (required operation "operands" "shift"))
       (normalize-shift opcode
                        (first operands)
                        (second operands)
                        (value-width (module-value module (first operand-ids)))
                        (value-width (module-value module (second operand-ids))))]
      ["rtl.eq" (bv-boolean (bveq (first operands) (second operands)))]
      ["rtl.ult" (bv-boolean (bvult (first operands) (second operands)))]
      ["rtl.slt" (bv-boolean (bvslt (first operands) (second operands)))]
      ["rtl.mux_lookup"
       (define selector (first operands))
       (define default (second operands))
       (define choices (drop operands 2))
       (define keys (operation-attribute operation "keys"))
       (define selector-width
         (value-width
          (module-value module (first (required operation "operands" "mux")))))
       (for/fold ([selected default])
                 ([key (in-list keys)] [choice (in-list choices)])
         (if (bveq selector (bv key selector-width)) choice selected))]
      ["rtl.cast" (first operands)]
      ["rtl.concat" (pack-concat operands)]
      ["rtl.extract"
       (extract (operation-attribute operation "high")
                (operation-attribute operation "low")
                (first operands))]
      ["rtl.zext" (zero-extend (first operands) (bitvector result-width))]
      ["rtl.sext" (sign-extend (first operands) (bitvector result-width))]
      ["rtl.trunc" (extract (sub1 result-width) 0 (first operands))]
      ["rtl.record_create" (pack-concat operands)]
      ["rtl.record_get"
       (define operand-id (first (required operation "operands" "record get")))
       (define record-type (required (module-value module operand-id) "type" "record value"))
       (define-values (high low)
         (record-field-range record-type (operation-attribute operation "field")))
       (extract high low (first operands))]
      ["rtl.vector_create" (pack-concat (reverse operands))]
      ["rtl.vector_get"
       (define operand-id (first (required operation "operands" "vector get")))
       (define vector-type (required (module-value module operand-id) "type" "vector value"))
       (define element-width
         (type-width (required vector-type "element_type" "vector type")))
       (define low (* (operation-attribute operation "index") element-width))
       (extract (+ low element-width -1) low (first operands))]
      [_ (error 'rhdl-formal "preflight missed unsupported opcode ~a" opcode)]))

  (for/hash ([port (in-list (required module "outputs" "module"))])
    (values (required port "name" "output port")
            (eval-value (required port "driver" "output port")))))

(define (interpret-top-bv snapshot inputs)
  (define top-id (required snapshot "top" "formal snapshot"))
  (define top (find-module snapshot top-id))
  (interpret-module snapshot top-id inputs (required top "name" "top module")))

(define (interfaces snapshot)
  (define top (find-module snapshot (required snapshot "top" "formal snapshot")))
  (values top
          (required top "inputs" "top module")
          (required top "outputs" "top module")))

(define (port-map ports)
  (for/hash ([port (in-list ports)])
    (values (required port "name" "port") port)))

(define (check-interface left-snapshot right-snapshot)
  (define-values (left-top left-inputs left-outputs) (interfaces left-snapshot))
  (define-values (_right-top right-inputs right-outputs) (interfaces right-snapshot))
  (define (check-kind kind left-ports right-ports)
    (define left-map (port-map left-ports))
    (define right-map (port-map right-ports))
    (unless (equal? (sort (hash-keys left-map) string<?)
                    (sort (hash-keys right-map) string<?))
      (unsupported left-top #f
                   (format "formal subjects have different ~a port names" kind)))
    (for ([name (in-list (hash-keys left-map))])
      (define left-width (type-width (required (hash-ref left-map name) "type" "port")))
      (define right-width (type-width (required (hash-ref right-map name) "type" "port")))
      (unless (= left-width right-width)
        (unsupported left-top #f
                     (format "formal subjects have different widths for ~a port ~a" kind name)))))
  (check-kind "input" left-inputs right-inputs)
  (check-kind "output" left-outputs right-outputs)
  (values left-top left-inputs left-outputs right-inputs right-outputs))

(define (model-natural value solution)
  (define evaluated (evaluate value solution))
  (if (concrete? evaluated)
      (bitvector->natural evaluated)
      0))

(define (default-solve mismatch)
  (solve (assert mismatch)))

(define (run-equivalence-query left-snapshot right-snapshot solve-query)
  (validate-snapshot left-snapshot)
  (validate-snapshot right-snapshot)
  (define-values (_left-top left-inputs left-outputs _right-inputs _right-outputs)
    (check-interface left-snapshot right-snapshot))
  (define symbolic-inputs
    (for/hash ([port (in-list left-inputs)])
      (define name (required port "name" "input port"))
      (define width (type-width (required port "type" "input port")))
      (values name (constant (gensym (string-append "rhdl_" name "_"))
                             (bitvector width)))))
  (define left-values (interpret-top-bv left-snapshot symbolic-inputs))
  (define right-values (interpret-top-bv right-snapshot symbolic-inputs))
  (define mismatches
    (for/list ([port (in-list left-outputs)])
      (define name (required port "name" "output port"))
      (! (bveq (hash-ref left-values name) (hash-ref right-values name)))))
  (define mismatch
    (for/fold ([result #f]) ([term (in-list mismatches)]) (|| result term)))
  (define solution (solve-query mismatch))
  (cond
    [(unsat? solution)
     (formal-engine-result "equivalent" #f '() '() #f)]
    [(sat? solution)
     (define assignments
       (for/list ([port (in-list left-inputs)])
         (define name (required port "name" "input port"))
         (define type (required port "type" "input port"))
         (hash "port" name
               "type" type
               "value" (model-natural (hash-ref symbolic-inputs name) solution))))
     (define concrete-inputs
       (for/hash ([entry (in-list assignments)])
         (define name (required entry "port" "counterexample assignment"))
         (define port
           (findf (lambda (candidate)
                    (equal? (required candidate "name" "input port") name))
                  left-inputs))
         (values name
                 (bv (required entry "value" "counterexample assignment")
                     (type-width (required port "type" "input port"))))))
     (define concrete-left-values (interpret-top-bv left-snapshot concrete-inputs))
     (define concrete-right-values (interpret-top-bv right-snapshot concrete-inputs))
     (define differences
       (for/list ([port (in-list left-outputs)]
                  #:when
                  (let* ([name (required port "name" "output port")]
                         [left (bitvector->natural (hash-ref concrete-left-values name))]
                         [right (bitvector->natural (hash-ref concrete-right-values name))])
                    (not (= left right))))
         (define name (required port "name" "output port"))
         (hash "port" name
               "type" (required port "type" "output port")
               "left" (bitvector->natural (hash-ref concrete-left-values name))
               "right" (bitvector->natural (hash-ref concrete-right-values name)))))
     (formal-engine-result "counterexample" #f assignments differences #f)]
    [else
     (formal-engine-result "unknown"
                           "Rosette solver returned an unknown result"
                           '()
                           '()
                           (diagnostic #f #f "Rosette solver returned an unknown result"))]))

(define (check_equivalent_snapshots left-snapshot right-snapshot
                                    #:solve [solve-query default-solve])
  (with-handlers ([exn:fail:formal:unsupported?
                   (lambda (exception)
                     (formal-engine-result
                      "unsupported"
                      (exn-message exception)
                      '()
                      '()
                      (exn:fail:formal:unsupported-diagnostic exception)))])
    ;; Keep fail-closed preflight outside Rosette's verification-condition
    ;; exception wrapper so unsupported IR remains a typed formal result.
    (validate-snapshot left-snapshot)
    (validate-snapshot right-snapshot)
    (check-interface left-snapshot right-snapshot)
    (define isolated
      (with-terms '()
        (with-vc vc-true
          (run-equivalence-query left-snapshot right-snapshot solve-query))))
    (cond
      [(normal? isolated) (result-value isolated)]
      [else (raise (result-value isolated))])))

(define (interpret_snapshot snapshot concrete-inputs)
  (validate-snapshot snapshot)
  (define-values (_top inputs _outputs) (interfaces snapshot))
  (define bitvector-inputs
    (for/hash ([port (in-list inputs)])
      (define name (required port "name" "input port"))
      (define width (type-width (required port "type" "input port")))
      (define value
        (hash-ref concrete-inputs name
                  (lambda () (error 'rhdl-formal "missing concrete input ~a" name))))
      (values name (if (bitvector? value) value (bv value width)))))
  (for/hash ([(name value) (in-hash (interpret-top-bv snapshot bitvector-inputs))])
    (values name (bitvector->natural value))))
