# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test check-boundaries frontend-test backend-test unit-test lop-test circt-test verilog-golden-test update-verilog-goldens setup-circt examples

CORE_TESTS = tests/core/types-test.rhm tests/core/verify-test.rhm tests/core/wire-test.rhm tests/core/shift-test.rhm tests/core/memory-test.rhm
FRONTEND_TESTS = tests/frontend/ir-test.rhm tests/frontend/printer-test.rhm tests/frontend/frontend-test.rhm tests/frontend/fresh-test.rhm tests/frontend/lop-equivalence-test.rhm tests/frontend/indexing-test.rhm tests/frontend/into-test.rhm tests/frontend/concat-test.rhm tests/frontend/shift-test.rhm tests/frontend/comparison-test.rhm tests/frontend/bool-literal-test.rhm tests/frontend/expanding-arithmetic-test.rhm tests/frontend/enum-test.rhm tests/frontend/vector-test.rhm tests/frontend/vector-update-test.rhm tests/frontend/hardware-annotation-test.rhm tests/frontend/table-test.rhm tests/frontend/vec-search-test.rhm tests/frontend/vec-shift-register-test.rhm tests/frontend/vec-shift-register-param-test.rhm tests/frontend/predicate-filter-test.rhm tests/frontend/wire-test.rhm tests/frontend/memory-test.rhm tests/frontend/multi-write-memory-test.rhm tests/frontend/tiny-simd-test.rhm tests/frontend/stack-test.rhm tests/frontend/adder4-test.rhm tests/frontend/generated-adder-test.rhm tests/frontend/bundle-test.rhm tests/frontend/interface-test.rhm tests/frontend/interface-array-test.rhm tests/frontend/std-ready-valid-test.rhm tests/frontend/std-flow-test.rhm tests/frontend/std-counter-test.rhm tests/frontend/conditional-test.rhm tests/frontend/sync-test.rhm tests/frontend/register-shorthand-test.rhm tests/frontend/aggregate-equivalence-test.rhm
BACKEND_TESTS = tests/backend/circt-test.rhm tests/backend/equivalence-test.rhm

check-boundaries:
	bash tools/check-boundaries.sh

frontend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test $(CORE_TESTS) $(FRONTEND_TESTS)
	bash tests/frontend/run-negative.sh

backend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test $(BACKEND_TESTS)

unit-test: frontend-test backend-test

lop-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test tests/frontend/lop-equivalence-test.rhm tests/frontend/aggregate-equivalence-test.rhm
	env PLTCOLLECTS=$(CURDIR): raco test tests/backend/equivalence-test.rhm

circt-test:
	bash tests/backend/run-circt.sh

verilog-golden-test:
	bash tests/backend/run-circt.sh --golden-only

update-verilog-goldens:
	bash tests/backend/run-circt.sh --update-goldens

test: unit-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	racket -S $(CURDIR) examples/lop/adder-core.rhm
	racket -S $(CURDIR) examples/lop/adder-kernel.rhm
	racket -S $(CURDIR) examples/lop/adder-composed.rhdl
	racket -S $(CURDIR) examples/lop/adder-standard.rhdl
	racket -S $(CURDIR) examples/lop/width-ops-kernel.rhm
	racket -S $(CURDIR) examples/lop/bundle-kernel.rhdl
	racket -S $(CURDIR) examples/lop/bundle-standard.rhdl
	racket -S $(CURDIR) examples/lop/interface-records.rhdl
	racket -S $(CURDIR) examples/full-adder.rhdl
	racket -S $(CURDIR) examples/adder4.rhdl
	racket -S $(CURDIR) examples/generated-adder.rhdl
	racket -S $(CURDIR) examples/alu.rhdl
	racket -S $(CURDIR) examples/enum-state.rhdl
	racket -S $(CURDIR) examples/shifts.rhdl
	racket -S $(CURDIR) examples/width-ops.rhdl
	racket -S $(CURDIR) examples/counter.rhdl
	racket -S $(CURDIR) examples/standard-counter.rhdl
	racket -S $(CURDIR) examples/multiply.rhdl
	racket -S $(CURDIR) examples/expanding-arithmetic.rhdl
	racket -S $(CURDIR) examples/unsigned-comparisons.rhdl
	racket -S $(CURDIR) examples/sync-counter.rhdl
	racket -S $(CURDIR) examples/enable-shift-register.rhdl
	racket -S $(CURDIR) examples/reset-shift-register.rhdl
	racket -S $(CURDIR) examples/hierarchy.rhdl
	racket -S $(CURDIR) examples/layered-adder.rhdl
	racket -S $(CURDIR) examples/host-parameters.rhdl
	racket -S $(CURDIR) examples/fresh-generators.rhdl
	racket -S $(CURDIR) examples/bundle.rhdl
	racket -S $(CURDIR) examples/vector.rhdl
	racket -S $(CURDIR) examples/vector-update.rhdl
	racket -S $(CURDIR) examples/table.rhdl
	racket -S $(CURDIR) examples/vec-search.rhdl
	racket -S $(CURDIR) examples/vec-shift-register.rhdl
	racket -S $(CURDIR) examples/vec-shift-register-param.rhdl
	racket -S $(CURDIR) examples/predicate-filter.rhdl
	racket -S $(CURDIR) examples/wire.rhdl
	racket -S $(CURDIR) examples/async-read-memory.rhdl
	racket -S $(CURDIR) examples/multi-write-memory.rhdl
	racket -S $(CURDIR) examples/tiny-simd.rhdl
	racket -S $(CURDIR) examples/stack.rhdl
	racket -S $(CURDIR) examples/interface.rhdl
	racket -S $(CURDIR) examples/interface-array.rhdl
	racket -S $(CURDIR) examples/nested-interface.rhdl
	racket -S $(CURDIR) examples/flow-control.rhdl
	racket -S $(CURDIR) examples/inspect-ir.rhm
