# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test host-test check-boundaries frontend-test backend-test unit-test lop-test noc-test riscv-test circt-test verilog-golden-test update-verilog-goldens setup-circt examples

CORE_TESTS := $(sort $(wildcard tests/core/*-test.rhm))
FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*-test.rhm))
BACKEND_TESTS := $(sort $(wildcard tests/backend/*-test.rhm))
LOP_FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*equivalence-test.rhm))
LOP_BACKEND_TESTS := $(sort $(wildcard tests/backend/*equivalence-test.rhm))
NOC_TESTS := $(sort $(shell find noc/tests -type f -name '*-test.rhm'))
RISCV_TESTS := $(sort $(wildcard riscv/tests/*-test.rhm))
EXAMPLES := $(sort $(shell find examples -type f \( -name '*.rhm' -o -name '*.rhdl' \)))

check-boundaries:
	bash tools/check-boundaries.sh

frontend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test $(CORE_TESTS) $(FRONTEND_TESTS)
	bash tests/frontend/run-negative.sh

backend-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test $(BACKEND_TESTS)

unit-test: frontend-test backend-test

lop-test: check-boundaries
	env PLTCOLLECTS=$(CURDIR): raco test $(LOP_FRONTEND_TESTS)
	env PLTCOLLECTS=$(CURDIR): raco test $(LOP_BACKEND_TESTS)

noc-test:
	bash noc/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test $(NOC_TESTS)
	bash noc/tests/language/run-negative.sh

riscv-test:
	bash riscv/check-boundaries.sh
	env PLTCOLLECTS=$(CURDIR): raco test $(RISCV_TESTS)

circt-test:
	bash tests/backend/run-circt.sh

verilog-golden-test:
	bash tests/backend/run-circt.sh --golden-only

update-verilog-goldens:
	bash tests/backend/run-circt.sh --update-goldens

host-test: unit-test examples noc-test riscv-test

test: host-test circt-test

setup-circt:
	bash tools/install-circt.sh

examples:
	@for example in $(EXAMPLES); do \
		echo "racket -S $(CURDIR) $$example"; \
		racket -S $(CURDIR) "$$example" || exit $$?; \
	done
