.PHONY: test unit-test verilator-test examples

unit-test:
	raco test tests/ir-test.rhm tests/verify-test.rhm tests/printer-test.rhm tests/sv-test.rhm

verilator-test:
	bash tests/run-verilator.sh

test: unit-test verilator-test

examples:
	racket examples/adder.rhm
	racket examples/counter.rhm
	racket examples/hierarchy.rhm
