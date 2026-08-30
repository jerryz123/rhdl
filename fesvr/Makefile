# Builds and tests the standalone FESVR direct-memory transport.
REPO_DIR := $(abspath ..)
FESVR_REVISION := e1fa113cfb6d55d878a3c1ea3befa8d9c13ce154
FESVR_PREFIX ?= $(REPO_DIR)/.tools/fesvr-$(FESVR_REVISION)
BUILD_DIR ?= /tmp/rhdl-direct-memory-htif
CXX ?= c++
AR ?= ar
RISCV_CC ?= riscv64-unknown-elf-gcc

CPPFLAGS += -I$(FESVR_PREFIX)/include -I$(CURDIR)
CXXFLAGS += -std=c++20 -Wall -Wextra -Werror
FESVR_LIBRARY := $(FESVR_PREFIX)/lib/libfesvr.a
TRANSPORT_OBJECT := $(BUILD_DIR)/direct_mem_htif.o
TRANSPORT_LIBRARY := $(BUILD_DIR)/libdirect_mem_htif.a
TEST_ELF := $(BUILD_DIR)/direct_mem_htif_pass.elf
TEST_BINARY := $(BUILD_DIR)/direct_mem_htif_test

.PHONY: all setup test dpi-compile-check

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

$(FESVR_LIBRARY):
	@echo "FESVR is not installed; run 'make setup' first" >&2
	@exit 1

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TRANSPORT_OBJECT): direct_mem_htif.cc direct_mem_htif.h $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c direct_mem_htif.cc -o $@

$(TRANSPORT_LIBRARY): $(TRANSPORT_OBJECT)
	$(AR) rcs $@ $^

$(TEST_ELF): $(REPO_DIR)/support/direct_mem_htif_pass.S \
             $(REPO_DIR)/support/direct_mem_htif_pass.ld | $(BUILD_DIR)
	$(RISCV_CC) -march=rv64i -mabi=lp64 -nostdlib -nostartfiles \
	  -Wl,--build-id=none -Wl,--defsym=__memory_base=0x180000000 \
	  -Wl,-T,$(REPO_DIR)/support/direct_mem_htif_pass.ld \
	  $< -o $@

$(TEST_BINARY): tests/direct_mem_htif_test.cc \
                $(TRANSPORT_LIBRARY) $(FESVR_LIBRARY) | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< $(TRANSPORT_LIBRARY) \
	  $(FESVR_LIBRARY) -pthread -o $@
