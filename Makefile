# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test check-boundaries frontend-test backend-test unit-test lop-test circt-test verilog-golden-test update-verilog-goldens setup-circt examples

CORE_TESTS := $(sort $(wildcard tests/core/*-test.rhm))
FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*-test.rhm))
BACKEND_TESTS := $(sort $(wildcard tests/backend/*-test.rhm))
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
	@for example in $(EXAMPLES); do \
		echo "racket -S $(CURDIR) $$example"; \
		racket -S $(CURDIR) "$$example" || exit $$?; \
	done
