# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test check-boundaries unit-test circt-test setup-circt examples

check-boundaries:
	bash tools/check-boundaries.sh

unit-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test tests/core/verify-test.rhm tests/frontend/ir-test.rhm tests/frontend/printer-test.rhm tests/frontend/frontend-test.rhm tests/frontend/fresh-test.rhm tests/backend/circt-test.rhm
	bash tests/frontend/run-negative.sh

circt-test:
	bash tests/backend/run-circt.sh

test: unit-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	racket -S $(CURDIR) examples/adder.rhdl
	racket -S $(CURDIR) examples/alu.rhdl
	racket -S $(CURDIR) examples/width-ops.rhdl
	racket -S $(CURDIR) examples/counter.rhdl
	racket -S $(CURDIR) examples/hierarchy.rhdl
	racket -S $(CURDIR) examples/layered-adder.rhdl
	racket -S $(CURDIR) examples/fresh-generators.rhdl
	racket -S $(CURDIR) examples/kernel-adder.rhdl
