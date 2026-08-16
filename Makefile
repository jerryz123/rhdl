# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test host-test host-checks check-boundaries check-example-verilog frontend-test backend-test unit-test lop-test rfpl-test rfpl-unit-test rfpl-circt-test noc-test riscv-test tilelink-test ricket-host-test ricket-test emacs-test circt-test verilog-golden-test update-verilog-goldens setup-circt examples examples-rhdl examples-std examples-lop examples-rfpl examples-tilelink

CORE_TESTS := $(sort $(wildcard tests/core/*-test.rhm))
FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*-test.rhm))
BACKEND_TESTS := $(sort $(wildcard tests/backend/*-test.rhm))
LOP_FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*equivalence-test.rhm))
LOP_BACKEND_TESTS := $(sort $(wildcard tests/backend/*equivalence-test.rhm))
NOC_TESTS := $(sort $(shell find noc/tests -type f -name '*-test.rhm'))
RISCV_TESTS := $(sort $(wildcard riscv/tests/*-test.rhm))
TILELINK_TESTS := $(sort $(wildcard tilelink/tests/*-test.rhm))
RICKET_TESTS := $(sort $(wildcard cores/tests/*-test.rhm) $(wildcard cores/ricket/tests/*-test.rhm))
RICKET_BACKEND_TESTS := tests/backend/rv64i-alu-decode-test.rhm tests/backend/ricket-cache-test.rhm
RFPL_TESTS := $(sort $(wildcard rfpl/tests/*-test.rhm))
RFPL_EXAMPLES := $(sort $(wildcard examples/rfpl/*.rfpl))
RHDL_EXAMPLES := $(sort $(shell find examples/rhdl -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
STD_EXAMPLES := $(sort $(shell find examples/std -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
LOP_EXAMPLES := $(sort $(shell find examples/lop -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
RFPL_LOGICAL_EXAMPLES := $(sort $(shell find examples/rfpl -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
TILELINK_EXAMPLES := $(sort $(shell find examples/tilelink -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
EXAMPLES := $(sort $(shell find examples -type f \( -name '*.rhm' -o -name '*.rhdl' \)) $(RFPL_EXAMPLES))

check-boundaries:
	bash tools/check-boundaries.sh
	bash rfpl/check-boundaries.sh
	bash riscv/check-boundaries.sh
	bash tilelink/check-boundaries.sh
	bash cores/check-boundaries.sh

check-example-verilog:
	bash tools/check-example-verilog.sh

frontend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(CORE_TESTS) $(FRONTEND_TESTS)
	bash tests/frontend/run-negative.sh

backend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(BACKEND_TESTS)

unit-test: frontend-test backend-test

lop-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(LOP_FRONTEND_TESTS)
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(LOP_BACKEND_TESTS)

rfpl-unit-test:
	bash rfpl/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RFPL_TESTS)
	bash rfpl/tests/run-negative.sh

rfpl-test: rfpl-unit-test examples-rfpl

rfpl-circt-test:
	bash rfpl/tests/run-circt.sh

noc-test:
	bash noc/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(NOC_TESTS)
	bash noc/tests/language/run-negative.sh

riscv-test:
	bash riscv/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RISCV_TESTS)

tilelink-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(TILELINK_TESTS)
	bash tilelink/tests/run-negative.sh

emacs-test:
	emacs -Q --batch -L tools/emacs -l tests/emacs/rhdl-mode-test.el -f ert-run-tests-batch-and-exit

ricket-host-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RICKET_TESTS) $(RICKET_BACKEND_TESTS)

ricket-test: ricket-host-test
	FIXTURE=rv32i-alu bash tests/backend/run-circt.sh
	FIXTURE=rv64i-alu bash tests/backend/run-circt.sh
	FIXTURE=rv64i-alu-decode bash tests/backend/run-circt.sh
	FIXTURE=rv64i-alu-integrated bash tests/backend/run-circt.sh
	FIXTURE=load-store bash tests/backend/run-circt.sh
	FIXTURE=ricket-register-file bash tests/backend/run-circt.sh
	FIXTURE=ricket-scoreboard bash tests/backend/run-circt.sh
	FIXTURE=ricket-pipeline bash tests/backend/run-circt.sh
	FIXTURE=ricket-icache bash tests/backend/run-circt.sh
	FIXTURE=ricket-dcache bash tests/backend/run-circt.sh

circt-test: check-example-verilog
	bash tests/backend/run-circt.sh

verilog-golden-test: check-example-verilog
	bash tests/backend/run-circt.sh --golden-only

update-verilog-goldens:
	bash tools/check-example-verilog.sh --allow-empty
	bash tests/backend/run-circt.sh --update-goldens

host-checks: unit-test rfpl-unit-test noc-test riscv-test tilelink-test ricket-host-test

host-test: host-checks examples

test: host-test circt-test rfpl-circt-test

setup-circt:
	bash tools/install-circt.sh

examples: check-example-verilog
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(EXAMPLES)

examples-rhdl:
	bash tools/check-example-verilog.sh examples/rhdl
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RHDL_EXAMPLES)

examples-std:
	bash tools/check-example-verilog.sh examples/std
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(STD_EXAMPLES)

examples-lop:
	bash tools/check-example-verilog.sh examples/lop
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(LOP_EXAMPLES)

examples-rfpl:
	bash tools/check-example-verilog.sh examples/rfpl
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RFPL_LOGICAL_EXAMPLES) $(RFPL_EXAMPLES)

examples-tilelink:
	bash tools/check-example-verilog.sh examples/tilelink
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(TILELINK_EXAMPLES)
