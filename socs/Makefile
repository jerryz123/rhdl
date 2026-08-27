# Runs focused elaboration for repository SoCs and the FESVR-backed SimpleSoC simulation.
REPO_DIR := $(abspath ..)
FESVR_DIR := $(REPO_DIR)/fesvr
FESVR_REVISION := e1fa113cfb6d55d878a3c1ea3befa8d9c13ce154
FESVR_PREFIX ?= $(REPO_DIR)/.tools/fesvr-$(FESVR_REVISION)
BUILD_DIR ?= /tmp/rhdl-simple-soc
RISCV_CC ?= riscv64-unknown-elf-gcc
RACKET ?= racket
RACO ?= raco
VERILATOR ?= verilator
CIRCT_OPT ?= $(REPO_DIR)/.tools/firtool-1.155.0/bin/circt-opt

FESVR_LIBRARY := $(FESVR_PREFIX)/lib/libfesvr.a
TEST_ELF := $(BUILD_DIR)/direct_mem_htif_pass.elf
SOC_MLIR := $(BUILD_DIR)/simple_soc.mlir
SOC_VERILOG := $(BUILD_DIR)/SimpleSoC.sv
SOC_OBJECT_DIR := $(BUILD_DIR)/obj
SOC_BINARY := $(SOC_OBJECT_DIR)/VTestDriver

.PHONY: all rtl-elaboration-test tiled-plan-test tiled-elaboration-test e2e-test

all: rtl-elaboration-test

rtl-elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhdl-simple-soc-rtl.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test socs/tests/simple-soc-test.rhm

tiled-plan-test:
	compiled_root="$$(mktemp -d /tmp/rhdl-tiled-soc-plan.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test \
	  socs/tests/tiled-soc-plan-test.rhm \
	  socs/tests/tiled-soc-config-test.rhm

tiled-elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhdl-tiled-soc-rtl.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test \
	  socs/tests/tiled-tiles-test.rhm \
	  socs/tests/tiled-soc-test.rhm

e2e-test: $(FESVR_LIBRARY) $(TEST_ELF) | $(BUILD_DIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	compiled_root="$$(mktemp -d /tmp/rhdl-simple-soc-e2e.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  $(RACKET) -y -S $(REPO_DIR) tools/emit-simple-soc.rhm > $(SOC_MLIR)
	$(CIRCT_OPT) --canonicalize --cse --prettify-verilog \
	  --lower-seq-hlmem --lower-sim-to-sv --lower-verif-to-sv \
	  --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
	  --lower-seq-firmem \
	  --hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined' \
	  --sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
	  --export-verilog $(SOC_MLIR) -o /dev/null > $(SOC_VERILOG)
	# Bidirectional channel bundles lower as packed aggregates, so Verilator \
	# reports false whole-aggregate feedback across independent flow fields.
	$(VERILATOR) --binary --timing --vpi --assert --Wno-UNOPTFLAT --build-jobs 0 \
	  --top-module TestDriver --Mdir $(SOC_OBJECT_DIR) \
	  $(SOC_VERILOG) $(REPO_DIR)/support/TestDriver.sv \
	  $(FESVR_DIR)/direct_mem_htif.cc $(FESVR_DIR)/direct_mem_htif_dpi.cc \
	  -CFLAGS "-I$(FESVR_PREFIX)/include -I$(FESVR_DIR) -std=c++20" \
	  -LDFLAGS "$(FESVR_LIBRARY) -pthread"
	$(SOC_BINARY) $(TEST_ELF)

$(FESVR_LIBRARY):
	@echo "FESVR is not installed; run 'make -C fesvr setup' first" >&2
	@exit 1

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TEST_ELF): $(REPO_DIR)/support/direct_mem_htif_pass.S \
             $(REPO_DIR)/support/direct_mem_htif_pass.ld | $(BUILD_DIR)
	$(RISCV_CC) -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,-T,$(REPO_DIR)/support/direct_mem_htif_pass.ld \
	  $< -o $@
