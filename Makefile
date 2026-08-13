# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test check-boundaries unit-test lop-test circt-test setup-circt examples

check-boundaries:
	bash tools/check-boundaries.sh

unit-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test tests/core/types-test.rhm tests/core/verify-test.rhm tests/frontend/ir-test.rhm tests/frontend/printer-test.rhm tests/frontend/frontend-test.rhm tests/frontend/fresh-test.rhm tests/frontend/lop-equivalence-test.rhm tests/frontend/bundle-test.rhm tests/frontend/interface-test.rhm tests/frontend/aggregate-equivalence-test.rhm tests/backend/circt-test.rhm
	bash tests/frontend/run-negative.sh

lop-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test tests/frontend/lop-equivalence-test.rhm tests/frontend/aggregate-equivalence-test.rhm tests/backend/circt-test.rhm

circt-test:
	bash tests/backend/run-circt.sh

test: unit-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	racket -S $(CURDIR) examples/lop/adder-core.rhm
	racket -S $(CURDIR) examples/lop/adder-kernel.rhm
	racket -S $(CURDIR) examples/lop/adder-composed.rhdl
	racket -S $(CURDIR) examples/lop/adder-standard.rhdl
	racket -S $(CURDIR) examples/lop/bundle-kernel.rhdl
	racket -S $(CURDIR) examples/lop/bundle-standard.rhdl
	racket -S $(CURDIR) examples/lop/interface-records.rhdl
	racket -S $(CURDIR) examples/full-adder.rhdl
	racket -S $(CURDIR) examples/alu.rhdl
	racket -S $(CURDIR) examples/width-ops.rhdl
	racket -S $(CURDIR) examples/counter.rhdl
	racket -S $(CURDIR) examples/hierarchy.rhdl
	racket -S $(CURDIR) examples/layered-adder.rhdl
	racket -S $(CURDIR) examples/host-parameters.rhdl
	racket -S $(CURDIR) examples/fresh-generators.rhdl
	racket -S $(CURDIR) examples/bundle.rhdl
	racket -S $(CURDIR) examples/interface.rhdl
	racket -S $(CURDIR) examples/nested-interface.rhdl
