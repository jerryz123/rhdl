# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test host-test check-boundaries frontend-test backend-test unit-test lop-test noc-test riscv-test ricket-host-test ricket-test emacs-test circt-test verilog-golden-test update-verilog-goldens setup-circt examples

CORE_TESTS := $(sort $(wildcard tests/core/*-test.rhm))
FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*-test.rhm))
BACKEND_TESTS := $(sort $(wildcard tests/backend/*-test.rhm))
LOP_FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*equivalence-test.rhm))
LOP_BACKEND_TESTS := $(sort $(wildcard tests/backend/*equivalence-test.rhm))
NOC_TESTS := $(sort $(shell find noc/tests -type f -name '*-test.rhm'))
RISCV_TESTS := $(sort $(wildcard riscv/tests/*-test.rhm))
RICKET_TESTS := $(sort $(wildcard cores/tests/*-test.rhm) $(wildcard cores/ricket/tests/*-test.rhm))
RICKET_BACKEND_TESTS := tests/backend/rv64i-alu-decode-test.rhm tests/backend/ricket-cache-test.rhm
EXAMPLES := $(sort $(shell find examples -type f \( -name '*.rhm' -o -name '*.rhdl' \)))

check-boundaries:
	bash tools/check-boundaries.sh
	bash riscv/check-boundaries.sh
	bash cores/check-boundaries.sh

frontend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(CORE_TESTS) $(FRONTEND_TESTS)
	bash tests/frontend/run-negative.sh

backend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(BACKEND_TESTS)

unit-test: frontend-test backend-test

lop-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(LOP_FRONTEND_TESTS)
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(LOP_BACKEND_TESTS)

noc-test:
	bash noc/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(NOC_TESTS)
	bash noc/tests/language/run-negative.sh

riscv-test:
	bash riscv/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RISCV_TESTS)

emacs-test:
	emacs -Q --batch -L tools/emacs -l tests/emacs/rhdl-mode-test.el -f ert-run-tests-batch-and-exit

ricket-host-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(RICKET_TESTS) $(RICKET_BACKEND_TESTS)

ricket-test: ricket-host-test
	FIXTURE=rv64i-alu bash tests/backend/run-circt.sh
	FIXTURE=rv64i-alu-decode bash tests/backend/run-circt.sh
	FIXTURE=rv64i-alu-integrated bash tests/backend/run-circt.sh
	FIXTURE=load-store bash tests/backend/run-circt.sh
	FIXTURE=ricket-register-file bash tests/backend/run-circt.sh
	FIXTURE=ricket-scoreboard bash tests/backend/run-circt.sh
	FIXTURE=ricket-pipeline bash tests/backend/run-circt.sh
	FIXTURE=ricket-icache bash tests/backend/run-circt.sh
	FIXTURE=ricket-dcache bash tests/backend/run-circt.sh

circt-test:
	bash tests/backend/run-circt.sh

verilog-golden-test:
	bash tests/backend/run-circt.sh --golden-only

update-verilog-goldens:
	bash tests/backend/run-circt.sh --update-goldens

host-test: unit-test examples noc-test riscv-test ricket-host-test

test: host-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	env PLTCOLLECTS=$(CURDIR): raco test --direct $(EXAMPLES)
