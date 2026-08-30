# Builds and verifies FESVR-backed SoC harnesses with Verilator.
REPO_DIR := $(abspath ..)
FESVR_DIR := $(CURDIR)/fesvr
VERILATOR_DIR := $(CURDIR)/verilator
FESVR_REVISION := e1fa113cfb6d55d878a3c1ea3befa8d9c13ce154
FESVR_PREFIX ?= $(REPO_DIR)/.tools/fesvr-$(FESVR_REVISION)
BUILD_DIR ?= /tmp/rhdl-sims
CXX ?= c++
AR ?= ar
RISCV_CC ?= riscv64-unknown-elf-gcc
RACKET ?= racket
RACO ?= raco
VERILATOR ?= verilator
CIRCT_OPT ?= $(REPO_DIR)/.tools/firtool-1.155.0/bin/circt-opt

CPPFLAGS += -I$(FESVR_PREFIX)/include -I$(FESVR_DIR) -I$(VERILATOR_DIR)
CXXFLAGS += -std=c++20 -Wall -Wextra -Werror
FESVR_LIBRARY := $(FESVR_PREFIX)/lib/libfesvr.a
TRANSPORT_OBJECT := $(BUILD_DIR)/direct_mem_htif.o
TRANSPORT_LIBRARY := $(BUILD_DIR)/libdirect_mem_htif.a
FESVR_TEST_ELF := $(BUILD_DIR)/direct_mem_htif_high.elf
SOC_TEST_ELF := $(BUILD_DIR)/direct_mem_htif_pass.elf
FESVR_TEST_BINARY := $(BUILD_DIR)/direct_mem_htif_test
SOC_MLIR := $(BUILD_DIR)/soc_harness.mlir
SOC_VERILOG := $(BUILD_DIR)/SoCHarness.sv
SOC_OBJECT_DIR := $(BUILD_DIR)/obj
SOC_BINARY := $(SOC_OBJECT_DIR)/VTestDriver

.PHONY: all setup fesvr-test dpi-compile-check elaboration-test verilator-test tiled-lowering-test

all: elaboration-test

setup:
	$(FESVR_DIR)/install.sh

fesvr-test: $(FESVR_TEST_BINARY) $(FESVR_TEST_ELF)
	$(FESVR_TEST_BINARY) $(FESVR_TEST_ELF)

dpi-compile-check: $(FESVR_LIBRARY) | $(BUILD_DIR)
	@test -n "$(VERILATOR_ROOT)" || \
	  (echo "set VERILATOR_ROOT to the Verilator share directory" >&2; exit 1)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -I$(VERILATOR_ROOT)/include/vltstd \
	  -c $(VERILATOR_DIR)/direct_mem_htif_dpi.cc -o $(BUILD_DIR)/direct_mem_htif_dpi.o

elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-elaboration.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test sims/tests/soc-harness-test.rhm

verilator-test: $(FESVR_LIBRARY) $(SOC_TEST_ELF) | $(BUILD_DIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-verilator.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  $(RACKET) -y -S $(REPO_DIR) sims/emit-soc-harness.rhm > $(SOC_MLIR)
	$(CIRCT_OPT) --canonicalize --cse --prettify-verilog \
	  --lower-seq-hlmem --lower-sim-to-sv --lower-verif-to-sv \
	  --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
	  --lower-seq-firmem \
	  --hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined' \
	  --sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
	  --export-verilog $(SOC_MLIR) -o /dev/null > $(SOC_VERILOG)
	$(VERILATOR) --binary --timing --vpi --assert --Wno-UNOPTFLAT --build-jobs 0 \
	  --top-module TestDriver --Mdir $(SOC_OBJECT_DIR) \
	  $(SOC_VERILOG) $(CURDIR)/TestDriver.v \
	  $(FESVR_DIR)/direct_mem_htif.cc $(VERILATOR_DIR)/direct_mem_htif_dpi.cc \
	  -CFLAGS "-I$(FESVR_PREFIX)/include -I$(FESVR_DIR) -I$(VERILATOR_DIR) -std=c++20" \
	  -LDFLAGS "$(FESVR_LIBRARY) -pthread"
	$(SOC_BINARY) $(SOC_TEST_ELF)

tiled-lowering-test: | $(BUILD_DIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	compiled_root="$$(mktemp -d /tmp/rhdl-sims-tiled.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  $(RACKET) -y -S $(REPO_DIR) sims/emit-tiled-soc-harness.rhm > $(BUILD_DIR)/tiled_soc_harness.mlir
	$(CIRCT_OPT) --canonicalize --cse $(BUILD_DIR)/tiled_soc_harness.mlir -o /dev/null

$(FESVR_LIBRARY):
	@echo "FESVR is not installed; run 'make -C sims setup' first" >&2
	@exit 1

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TRANSPORT_OBJECT): $(FESVR_DIR)/direct_mem_htif.cc \
                     $(FESVR_DIR)/direct_mem_htif.h $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $(FESVR_DIR)/direct_mem_htif.cc -o $@

$(TRANSPORT_LIBRARY): $(TRANSPORT_OBJECT)
	$(AR) rcs $@ $^

$(FESVR_TEST_ELF): programs/direct_mem_htif_pass.S \
                    programs/direct_mem_htif_pass.ld | $(BUILD_DIR)
	$(RISCV_CC) -march=rv64i -mabi=lp64 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,--defsym=__memory_base=0x180000000 \
	  -Wl,-T,programs/direct_mem_htif_pass.ld $< -o $@

$(SOC_TEST_ELF): programs/direct_mem_htif_pass.S \
                 programs/direct_mem_htif_pass.ld | $(BUILD_DIR)
	$(RISCV_CC) -march=rv64i -mabi=lp64 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,-T,programs/direct_mem_htif_pass.ld $< -o $@

$(FESVR_TEST_BINARY): $(FESVR_DIR)/tests/direct_mem_htif_test.cc \
                      $(TRANSPORT_LIBRARY) $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< $(TRANSPORT_LIBRARY) \
	  $(FESVR_LIBRARY) -pthread -o $@
