# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test unit-test circt-test setup-circt examples

unit-test:
	raco test tests/ir-test.rhm tests/verify-test.rhm tests/printer-test.rhm tests/circt-test.rhm

circt-test:
	bash tests/run-circt.sh

test: unit-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	racket examples/adder.rhm
	racket examples/alu.rhm
	racket examples/width-ops.rhm
	racket examples/counter.rhm
	racket examples/hierarchy.rhm
