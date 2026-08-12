# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test unit-test circt-test setup-circt examples

unit-test:
	env PLTCOLLECTS=$(CURDIR): raco test tests/ir-test.rhm tests/verify-test.rhm tests/printer-test.rhm tests/circt-test.rhm tests/frontend-test.rhm tests/frontend-fresh-test.rhm
	bash tests/run-frontend-negative.sh

circt-test:
	bash tests/run-circt.sh

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
