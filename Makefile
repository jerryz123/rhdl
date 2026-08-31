# Build and test entry points for RHDL's Rhombus and CIRCT-based toolchain.

.PHONY: test host-test host-checks host-annotation-test check-boundaries check-example-verilog analysis-test frontend-test diagram-test backend-test formal-test formal-differential-test unit-test lop-test rfpl-test rfpl-unit-test rfpl-circt-test noc-test riscv-test ridx-test ridx-circt-test device-test chi-test rv5stage-host-test rv5stage-test emacs-test circt-test circt-verify-test verilator-test circt-full-test verilog-golden-test update-verilog-goldens setup-circt print-racket-compile-sources ci-host-foundation-test ci-host-backend-test ci-host-models-test ci-host-protocols-test ci-host-cores-test ci-host-hygiene-test ci-circt-language-test ci-circt-std-test ci-circt-protocols-test ci-circt-cores-test examples examples-rhdl examples-clocking examples-std examples-noc examples-lop examples-rfpl examples-ridx examples-riscv examples-chi examples-cores examples-formal examples-rv5stage

CORE_TESTS := $(sort $(wildcard tests/core/*-test.rhm))
ANALYSIS_TESTS := $(sort $(wildcard tests/analysis/*-test.rhm))
HOST_ANNOTATION_TESTS := $(sort $(wildcard host/tests/*-test.rhm))
FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*-test.rhm))
BACKEND_TESTS := $(sort $(wildcard tests/backend/*-test.rhm))
FORMAL_TESTS := tests/formal/suite.rkt
LOP_FRONTEND_TESTS := $(sort $(wildcard tests/frontend/*equivalence-test.rhm))
LOP_BACKEND_TESTS := $(sort $(wildcard tests/backend/*equivalence-test.rhm))
NOC_TESTS := $(sort $(shell find noc/tests -type f -name '*-test.rhm'))
RISCV_TESTS := $(sort $(wildcard riscv/tests/*-test.rhm))
RIDX_TESTS := $(sort $(shell find ridx/tests -type f -name '*-test.rhm'))
DEVICE_TESTS := $(sort $(wildcard devices/tests/*-test.rhm))
CHI_TESTS := $(sort $(wildcard chi/tests/*-test.rhm))
RV5STAGE_TESTS := $(sort $(wildcard cores/tests/*-test.rhm) $(wildcard cores/rv5stage/tests/*-test.rhm))
RV5STAGE_BACKEND_TESTS := tests/backend/rv64i-alu-decode-test.rhm tests/backend/rv5stage-cache-test.rhm
RFPL_TESTS := $(sort $(wildcard rfpl/tests/*-test.rhm))
RFPL_EXAMPLES := $(sort $(wildcard examples/rfpl/*.rfpl))
RHDL_EXAMPLES := $(sort $(shell find examples/rhdl -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
CLOCKING_EXAMPLES := $(sort $(shell find examples/clocking -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
STD_EXAMPLES := $(sort $(shell find examples/std -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
NOC_EXAMPLES := $(sort $(shell find examples/noc -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
LOP_EXAMPLES := $(sort $(shell find examples/lop -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
RFPL_LOGICAL_EXAMPLES := $(sort $(shell find examples/rfpl -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
RIDX_EXAMPLES := $(sort $(shell find examples/ridx -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
RISCV_EXAMPLES := $(sort $(shell find examples/riscv -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
CHI_EXAMPLES := $(sort $(shell find examples/chi -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
CORE_EXAMPLES := $(sort $(shell find examples/cores -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
FORMAL_EXAMPLES := $(sort $(shell find examples/formal -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
RV5STAGE_EXAMPLES := $(sort $(shell find examples/rv5stage -type f \( -name '*.rhm' -o -name '*.rhdl' \)))
EXAMPLES := $(sort $(shell find examples -path examples/formal -prune -o -type f \( -name '*.rhm' -o -name '*.rhdl' \) -print) $(RFPL_EXAMPLES))
RACKET_COMPILE_SOURCES := $(sort \
  $(HOST_ANNOTATION_TESTS) $(CORE_TESTS) $(ANALYSIS_TESTS) $(FRONTEND_TESTS) \
  $(BACKEND_TESTS) $(RFPL_TESTS) $(NOC_TESTS) $(RISCV_TESTS) $(RIDX_TESTS) \
  $(DEVICE_TESTS) $(CHI_TESTS) $(RV5STAGE_TESTS) $(EXAMPLES) \
  $(wildcard tests/backend/emit-*.rhm) $(wildcard ridx/tests/rhdl/emit-*.rhm) \
  $(wildcard socs/tests/*.rhm) $(wildcard sims/tests/*.rhm) \
  $(wildcard sims/emit-*.rhm) \
  tests/backend/load-example.rkt tests/support/run-negative.rkt \
  noc/tests/language/run-negative.rkt)

print-racket-compile-sources:
	@printf '%s\n' $(RACKET_COMPILE_SOURCES)

check-boundaries:
	bash tools/check-boundaries.sh
	bash rfpl/check-boundaries.sh
	bash riscv/check-boundaries.sh
	bash chi/check-boundaries.sh
	bash cores/check-boundaries.sh

check-example-verilog:
	bash tools/check-example-verilog.sh

host-annotation-test:
	tools/run-racket-tests.sh $(HOST_ANNOTATION_TESTS)

frontend-test: check-boundaries
	tools/run-racket-tests.sh $(CORE_TESTS) $(ANALYSIS_TESTS) $(FRONTEND_TESTS)
	bash tests/frontend/run-negative.sh

analysis-test: check-boundaries
	tools/run-racket-tests.sh $(ANALYSIS_TESTS)

diagram-test: check-boundaries
	tools/run-racket-tests.sh tests/frontend/diagram-test.rhm

backend-test: check-boundaries
	tools/run-racket-tests.sh $(BACKEND_TESTS)

formal-test: check-boundaries
	@formal_compiled_root="$$(mktemp -d)"; \
	trap 'rm -rf "$$formal_compiled_root"' EXIT; \
	if ! env PLTCOMPILEDROOTS="$$formal_compiled_root" PLTCOLLECTS=$(CURDIR): racket -y -e '(require rosette) (unless (sat? (solve (assert #t))) (error '\''formal-test "Rosette solver probe failed"))'; then \
		echo 'formal-test requires Rosette 4.0 and its Z3 4.8.8 solver; see rhdl/formal/README.md' >&2; \
		exit 1; \
	fi; \
	env PLTCOMPILEDROOTS="$$formal_compiled_root" PLTCOLLECTS=$(CURDIR): raco test --direct $(FORMAL_TESTS)

formal-differential-test: check-boundaries
	bash tests/formal/run-differential.sh

unit-test: frontend-test backend-test

lop-test: check-boundaries
	tools/run-racket-tests.sh $(LOP_FRONTEND_TESTS) $(LOP_BACKEND_TESTS)

rfpl-unit-test:
	bash rfpl/check-boundaries.sh
	tools/run-racket-tests.sh $(RFPL_TESTS)
	bash rfpl/tests/run-negative.sh

rfpl-test: rfpl-unit-test examples-rfpl

rfpl-circt-test:
	bash rfpl/tests/run-circt.sh

noc-test:
	bash noc/check-boundaries.sh
	tools/run-racket-tests.sh $(NOC_TESTS)
	bash noc/tests/language/run-negative.sh

riscv-test:
	bash riscv/check-boundaries.sh
	tools/run-racket-tests.sh $(RISCV_TESTS)

ridx-test:
	tools/run-racket-tests.sh $(RIDX_TESTS)

ridx-circt-test:
	bash ridx/tests/rhdl/run-grid-equivalence.sh

device-test: check-boundaries
	tools/run-racket-tests.sh $(DEVICE_TESTS)

chi-test: check-boundaries
	tools/run-racket-tests.sh $(CHI_TESTS)
	bash chi/tests/run-negative.sh

emacs-test:
	emacs -Q --batch -L tools/emacs -l tests/emacs/rhdl-mode-test.el -f ert-run-tests-batch-and-exit

rv5stage-host-test: check-boundaries
	tools/run-racket-tests.sh $(RV5STAGE_TESTS) $(RV5STAGE_BACKEND_TESTS)

rv5stage-test: rv5stage-host-test
	FIXTURES='rv32i-alu rv64i-alu rv64i-alu-decode rv64i-alu-integrated load-store iterative-multiplier iterative-divider scoreboard rv5stage-register-file rv5stage-csr rv5stage-atomic rv5stage-core rv5stage-core-flow rv5stage-interrupt rv5stage-interrupt-flow rv5stage-multiply rv5stage-divide rv5stage-core-rv32 rv5stage-icache rv5stage-dcache rv5stage-dcache-rv32' bash tests/backend/run-circt.sh

circt-test: check-example-verilog
	bash tests/backend/run-circt.sh

circt-verify-test: check-example-verilog
	bash tests/backend/run-circt.sh --verify-only

verilator-test: check-example-verilog
	bash tests/backend/run-circt.sh --simulate-only

circt-full-test: check-example-verilog
	bash tests/backend/run-circt.sh --full

ci-circt-language-test:
	bash tools/check-example-verilog.sh examples/rhdl examples/lop
	bash tests/backend/run-circt.sh --group language

ci-circt-std-test:
	bash tools/check-example-verilog.sh examples/std
	bash tests/backend/run-circt.sh --group std

ci-circt-protocols-test:
	bash tools/check-example-verilog.sh examples/noc examples/chi examples/ridx
	bash tests/backend/run-circt.sh --group protocols

ci-circt-cores-test:
	bash tools/check-example-verilog.sh examples/riscv examples/cores
	bash tests/backend/run-circt.sh --group cores

verilog-golden-test: check-example-verilog
	bash tests/backend/run-circt.sh --golden-only

update-verilog-goldens:
	bash tools/check-example-verilog.sh --allow-empty
	bash tests/backend/run-circt.sh --update-goldens

host-checks: host-annotation-test unit-test rfpl-unit-test noc-test riscv-test ridx-test device-test chi-test rv5stage-host-test

ci-host-foundation-test: host-annotation-test frontend-test lop-test

ci-host-backend-test: backend-test

ci-host-models-test: noc-test riscv-test ridx-test

ci-host-protocols-test: rfpl-unit-test device-test chi-test

ci-host-cores-test: rv5stage-host-test

ci-host-hygiene-test: check-boundaries check-example-verilog

host-test: host-checks examples

test: host-test circt-test rfpl-circt-test

setup-circt:
	bash tools/install-circt.sh

examples: check-example-verilog
	tools/run-racket-tests.sh $(EXAMPLES)

examples-rhdl:
	bash tools/check-example-verilog.sh examples/rhdl
	tools/run-racket-tests.sh $(RHDL_EXAMPLES)

examples-clocking:
	bash tools/check-example-verilog.sh examples/clocking
	tools/run-racket-tests.sh $(CLOCKING_EXAMPLES)

examples-std:
	bash tools/check-example-verilog.sh examples/std
	tools/run-racket-tests.sh $(STD_EXAMPLES)

examples-noc:
	bash tools/check-example-verilog.sh examples/noc
	tools/run-racket-tests.sh $(NOC_EXAMPLES)

examples-lop:
	bash tools/check-example-verilog.sh examples/lop
	tools/run-racket-tests.sh $(LOP_EXAMPLES)

examples-rfpl:
	bash tools/check-example-verilog.sh examples/rfpl
	tools/run-racket-tests.sh $(RFPL_LOGICAL_EXAMPLES) $(RFPL_EXAMPLES)

examples-ridx:
	bash tools/check-example-verilog.sh examples/ridx
	tools/run-racket-tests.sh $(RIDX_EXAMPLES)

examples-riscv:
	bash tools/check-example-verilog.sh examples/riscv
	tools/run-racket-tests.sh $(RISCV_EXAMPLES)

examples-chi:
	bash tools/check-example-verilog.sh examples/chi
	tools/run-racket-tests.sh $(CHI_EXAMPLES)

examples-cores:
	bash tools/check-example-verilog.sh examples/cores
	tools/run-racket-tests.sh $(CORE_EXAMPLES)

examples-formal: check-boundaries
	@formal_compiled_root="$$(mktemp -d)"; trap 'rm -rf "$$formal_compiled_root"' EXIT; if ! env PLTCOMPILEDROOTS="$$formal_compiled_root" PLTCOLLECTS=$(CURDIR): racket -y -e '(require rosette) (unless (sat? (solve (assert #t))) (error '\''examples-formal "Rosette solver probe failed"))'; then echo 'examples-formal requires Rosette 4.0 and its Z3 4.8.8 solver; see rhdl/formal/README.md' >&2; exit 1; fi; env PLTCOMPILEDROOTS="$$formal_compiled_root" PLTCOLLECTS=$(CURDIR): raco test --direct $(FORMAL_EXAMPLES)

examples-rv5stage:
	bash tools/check-example-verilog.sh examples/rv5stage
	tools/run-racket-tests.sh $(RV5STAGE_EXAMPLES)
