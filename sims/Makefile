# Builds a reusable FESVR-backed SoC simulator and runs target binaries through HTIF.
REPO_DIR := $(abspath ..)
FESVR_DIR := $(CURDIR)/fesvr
VERILATOR_DIR := $(CURDIR)/verilator
FESVR_REVISION := e1fa113cfb6d55d878a3c1ea3befa8d9c13ce154
FESVR_PREFIX ?= $(REPO_DIR)/.tools/fesvr-$(FESVR_REVISION)
SOC ?= simple
BUILD_ROOT ?= /tmp/rhdl-sims
CXX ?= c++
RISCV_CC ?= riscv64-unknown-elf-gcc
RACKET ?= racket
RACO ?= raco
VERILATOR ?= verilator
CIRCT_OPT ?= $(REPO_DIR)/.tools/firtool-1.155.0/bin/circt-opt

CPPFLAGS += -I$(FESVR_PREFIX)/include -I$(FESVR_DIR) -I$(VERILATOR_DIR)
CXXFLAGS += -std=c++20 -Wall -Wextra -Werror
FESVR_LIBRARY := $(FESVR_PREFIX)/lib/libfesvr.a
SOC_BUILD_DIR := $(BUILD_ROOT)/$(SOC)
DPI_BUILD_DIR := $(BUILD_ROOT)/tools
TILED_LOWERING_DIR := $(BUILD_ROOT)/tiled-lowering
SOC_MLIR := $(SOC_BUILD_DIR)/soc_harness.mlir
SOC_VERILOG := $(SOC_BUILD_DIR)/SoCHarness.sv
SOC_OBJECT_DIR := $(SOC_BUILD_DIR)/obj
SIMULATOR_BINARY := $(SOC_OBJECT_DIR)/VTestDriver
SMOKE_BINARY := $(SOC_BUILD_DIR)/rv5stage_smoke.elf
SIMULATOR_SOURCES := $(addprefix $(REPO_DIR)/,$(shell cd $(REPO_DIR) && rg --files -g '*.rhdl' -g '*.rhm'))

.PHONY: all setup simulator run smoke dpi-compile-check elaboration-test tiled-lowering-test

all: simulator

setup:
	$(FESVR_DIR)/install.sh

simulator: $(SIMULATOR_BINARY)
	@echo "Built $(SOC) simulator: $(SIMULATOR_BINARY)"

run: simulator
	@test -n "$(BINARY)" || \
	  (echo "BINARY is required; use 'make -C sims run BINARY=/path/to/program.elf'" >&2; exit 2)
	@test -f "$(abspath $(BINARY))" || \
	  (echo "target binary does not exist: $(abspath $(BINARY))" >&2; exit 2)
	$(SIMULATOR_BINARY) $(HTIF_ARGS) "$(abspath $(BINARY))" $(TARGET_ARGS)

smoke: $(SMOKE_BINARY)
	$(MAKE) run SOC=$(SOC) BINARY=$(SMOKE_BINARY)

dpi-compile-check: $(FESVR_LIBRARY) | $(DPI_BUILD_DIR)
	@test -n "$(VERILATOR_ROOT)" || \
	  (echo "set VERILATOR_ROOT to the Verilator share directory" >&2; exit 1)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -I$(VERILATOR_ROOT)/include/vltstd \
	  -c $(VERILATOR_DIR)/direct_mem_htif_dpi.cc -o $(DPI_BUILD_DIR)/direct_mem_htif_dpi.o

elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-elaboration.XXXXXX)"; \
	trap 'rm -rf "$$compiled_root"' EXIT; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test sims/tests/soc-harness-test.rhm

tiled-lowering-test: | $(TILED_LOWERING_DIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-tiled.XXXXXX)"; \
	trap 'rm -rf "$$compiled_root"' EXIT; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  $(RACKET) -y -S $(REPO_DIR) sims/emit-soc-harness.rhm tiled > $(TILED_LOWERING_DIR)/soc_harness.mlir
	$(CIRCT_OPT) --canonicalize --cse $(TILED_LOWERING_DIR)/soc_harness.mlir -o /dev/null

$(FESVR_LIBRARY):
	@echo "FESVR is not installed; run 'make -C sims setup' first" >&2
	@exit 1

$(SOC_BUILD_DIR) $(DPI_BUILD_DIR) $(TILED_LOWERING_DIR):
	mkdir -p $@

$(SOC_MLIR): $(SIMULATOR_SOURCES) | $(SOC_BUILD_DIR)
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-verilator.XXXXXX)"; \
	trap 'rm -rf "$$compiled_root"' EXIT; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  $(RACKET) -y -S $(REPO_DIR) sims/emit-soc-harness.rhm $(SOC) > $(SOC_MLIR)

$(SOC_VERILOG): $(SOC_MLIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	$(CIRCT_OPT) --canonicalize --cse --prettify-verilog \
	  --lower-seq-hlmem --lower-sim-to-sv --lower-verif-to-sv \
	  --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
	  --lower-seq-firmem \
	  --hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined' \
	  --sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
	  --export-verilog $(SOC_MLIR) -o /dev/null > $(SOC_VERILOG)

$(SIMULATOR_BINARY): $(SOC_VERILOG) $(CURDIR)/TestDriver.v \
                     $(FESVR_DIR)/direct_mem_htif.cc \
                     $(FESVR_DIR)/direct_mem_htif.h \
                     $(VERILATOR_DIR)/direct_mem_htif_dpi.cc \
                     $(VERILATOR_DIR)/direct_mem_htif_dpi.h \
                     $(FESVR_LIBRARY)
	$(VERILATOR) --binary --timing --vpi --assert --Wno-UNOPTFLAT --build-jobs 0 \
	  --top-module TestDriver --Mdir $(SOC_OBJECT_DIR) \
	  $(SOC_VERILOG) $(CURDIR)/TestDriver.v \
	  $(FESVR_DIR)/direct_mem_htif.cc $(VERILATOR_DIR)/direct_mem_htif_dpi.cc \
	  -CFLAGS "-I$(FESVR_PREFIX)/include -I$(FESVR_DIR) -I$(VERILATOR_DIR) -std=c++20" \
	  -LDFLAGS "$(FESVR_LIBRARY) -pthread"

$(SMOKE_BINARY): tests/programs/rv5stage_smoke.S \
                 tests/programs/rv5stage_smoke.ld | $(SOC_BUILD_DIR)
	$(RISCV_CC) -march=rv64i -mabi=lp64 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,-T,tests/programs/rv5stage_smoke.ld $< -o $@
