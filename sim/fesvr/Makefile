# Builds the FESVR transport and generated SimpleSoCTop simulation independently.
REPO_DIR := $(abspath ../..)
FESVR_REVISION := e1fa113cfb6d55d878a3c1ea3befa8d9c13ce154
FESVR_PREFIX ?= $(REPO_DIR)/.tools/fesvr-$(FESVR_REVISION)
BUILD_DIR ?= /tmp/rhdl-direct-memory-htif
CXX ?= c++
AR ?= ar
RISCV_CC ?= riscv64-unknown-elf-gcc
RACKET ?= racket
RACO ?= raco
VERILATOR ?= verilator
CIRCT_OPT ?= $(REPO_DIR)/.tools/firtool-1.155.0/bin/circt-opt

CPPFLAGS += -I$(FESVR_PREFIX)/include -I$(CURDIR)
CXXFLAGS += -std=c++20 -Wall -Wextra -Werror
FESVR_LIBRARY := $(FESVR_PREFIX)/lib/libfesvr.a
TRANSPORT_OBJECT := $(BUILD_DIR)/direct_mem_htif.o
TRANSPORT_LIBRARY := $(BUILD_DIR)/libdirect_mem_htif.a
TEST_ELF := $(BUILD_DIR)/direct_mem_htif_pass.elf
TEST_BINARY := $(BUILD_DIR)/direct_mem_htif_test
SOC_MLIR := $(BUILD_DIR)/simple_soc_top.mlir
SOC_VERILOG := $(BUILD_DIR)/SimpleSoCTop.sv
SOC_OBJECT_DIR := $(BUILD_DIR)/simple_soc_obj
SOC_BINARY := $(SOC_OBJECT_DIR)/VTestDriver

.PHONY: all setup test dpi-compile-check rtl-elaboration-test stub-soc-test

all: $(TRANSPORT_LIBRARY)

setup:
	$(REPO_DIR)/tools/install-fesvr.sh

test: $(TEST_BINARY) $(TEST_ELF)
	$(TEST_BINARY) $(TEST_ELF)

dpi-compile-check: $(FESVR_LIBRARY) | $(BUILD_DIR)
	@test -n "$(VERILATOR_ROOT)" || \
	  (echo "set VERILATOR_ROOT to the Verilator share directory" >&2; exit 1)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -I$(VERILATOR_ROOT)/include/vltstd \
	  -c direct_mem_htif_dpi.cc -o $(BUILD_DIR)/direct_mem_htif_dpi.o

rtl-elaboration-test:
	cd $(REPO_DIR) && env PLTCOLLECTS=$(REPO_DIR): \
	  $(RACO) test tests/fesvr/fesvr-rtl-test.rhm

stub-soc-test: $(FESVR_LIBRARY) $(TEST_ELF) | $(BUILD_DIR)
	@test -x "$(CIRCT_OPT)" || \
	  (echo "circt-opt not found; run 'make setup-circt' at the repository root or set CIRCT_OPT" >&2; exit 1)
	cd $(REPO_DIR) && $(RACKET) -y -S $(REPO_DIR) \
	  tools/emit-fesvr-stub-soc.rhm > $(SOC_MLIR)
	$(CIRCT_OPT) --canonicalize --cse --prettify-verilog \
	  --lower-seq-hlmem --lower-sim-to-sv --lower-verif-to-sv \
	  --lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
	  --lower-seq-firmem \
	  --hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined' \
	  --sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
	  --export-verilog $(SOC_MLIR) -o /dev/null > $(SOC_VERILOG)
	$(VERILATOR) --binary --timing --vpi --build-jobs 0 \
	  --top-module TestDriver --Mdir $(SOC_OBJECT_DIR) \
	  $(SOC_VERILOG) $(CURDIR)/TestDriver.sv \
	  $(CURDIR)/direct_mem_htif.cc $(CURDIR)/direct_mem_htif_dpi.cc \
	  -CFLAGS "-I$(FESVR_PREFIX)/include -I$(CURDIR) -std=c++20" \
	  -LDFLAGS "$(FESVR_LIBRARY) -pthread"
	$(SOC_BINARY) $(TEST_ELF)

$(FESVR_LIBRARY):
	@echo "FESVR is not installed; run 'make setup' first" >&2
	@exit 1

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TRANSPORT_OBJECT): direct_mem_htif.cc direct_mem_htif.h $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c direct_mem_htif.cc -o $@

$(TRANSPORT_LIBRARY): $(TRANSPORT_OBJECT)
	$(AR) rcs $@ $^

$(TEST_ELF): $(REPO_DIR)/tests/fesvr/direct_mem_htif_pass.S \
             $(REPO_DIR)/tests/fesvr/direct_mem_htif_pass.ld | $(BUILD_DIR)
	$(RISCV_CC) -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,-T,$(REPO_DIR)/tests/fesvr/direct_mem_htif_pass.ld \
	  $< -o $@

$(TEST_BINARY): $(REPO_DIR)/tests/fesvr/direct_mem_htif_test.cc \
                $(TRANSPORT_LIBRARY) $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< $(TRANSPORT_LIBRARY) \
	  $(FESVR_LIBRARY) -pthread -o $@
