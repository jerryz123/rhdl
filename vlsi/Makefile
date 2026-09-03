# Builds a minimal RHDL leaf through CIRCT, LibreLane, and OpenFrame integration.

.DELETE_ON_ERROR:

RHDL_ROOT := $(abspath ..)
VLSI_ROOT := $(CURDIR)
HARNESS_DIR := $(VLSI_ROOT)/double_wide_openframe
BUILD_DIR := $(VLSI_ROOT)/build
CONFIG := $(VLSI_ROOT)/openlane/double_wide_openframe_project_wrapper/config.yaml
WRAPPER := $(VLSI_ROOT)/verilog/rtl/double_wide_openframe_project_wrapper.v
HARNESS_WRAPPER := $(HARNESS_DIR)/verilog/rtl/double_wide_openframe_project_wrapper.v
PIN_TEMPLATE := $(HARNESS_DIR)/librelane/wrapper/pin_template.def
TOP_NAME := double_wide_openframe_project_wrapper
LVS_CONFIG := $(VLSI_ROOT)/openlane/rhdl_lvs_smoke/config.yaml
LVS_WRAPPER := $(VLSI_ROOT)/verilog/rtl/rhdl_lvs_smoke.v
LVS_TOP_NAME := rhdl_lvs_smoke
LVS_RUN_DIR := $(VLSI_ROOT)/openlane/rhdl_lvs_smoke/runs/RHDL_LVS
MEMORY_MAP_DIR := $(VLSI_ROOT)/memory-map
MEMORY_MAP_CATALOG := $(MEMORY_MAP_DIR)/sky130-sram.ini
MEMORY_MAPPER := $(MEMORY_MAP_DIR)/map-memories.py
MEMORY_SITE_PASS_DIR := $(MEMORY_MAP_DIR)/circt
MEMORY_SITE_PLUGIN_BUILD_DIR := $(BUILD_DIR)/memory-site-plugin
MEMORY_SITE_PLUGIN := $(MEMORY_SITE_PLUGIN_BUILD_DIR)/rhdl-memory-sites.so
SIMPLE_SOC_MEMORY_POLICY := $(MEMORY_MAP_DIR)/simple-soc-policy.yaml
SIMPLE_SOC_BUILD_DIR := $(BUILD_DIR)/simple-soc
SIMPLE_SOC_MLIR := $(SIMPLE_SOC_BUILD_DIR)/simple-soc.mlir
SIMPLE_SOC_FIRRTL_MEM_MLIR := $(SIMPLE_SOC_BUILD_DIR)/simple-soc-firmem.mlir
SIMPLE_SOC_MEMORY_SITE_INVENTORY := $(SIMPLE_SOC_BUILD_DIR)/memory-sites.json
SIMPLE_SOC_MEMORY_SITE_STAMP := $(SIMPLE_SOC_BUILD_DIR)/memory-sites.stamp
SIMPLE_SOC_RTL := $(SIMPLE_SOC_BUILD_DIR)/simple-soc.sv
SIMPLE_SOC_MEMORY_WRAPPERS := $(SIMPLE_SOC_BUILD_DIR)/memory-wrappers.sv
SIMPLE_SOC_MEMORY_MANIFEST := $(SIMPLE_SOC_BUILD_DIR)/memory-manifest.json
SKY130_SRAM_MODEL = $(PDK_ROOT)/$(PDK)/libs.ref/sky130_sram_macros/verilog/sky130_sram_2kbyte_1rw1r_32x512_8.v

RACKET ?= racket
CIRCT_OPT ?= $(RHDL_ROOT)/.tools/firtool-1.155.0/bin/circt-opt
CIRCT_ROOT ?= $(abspath $(dir $(CIRCT_OPT))/..)
CIRCT_CMAKE_DIR ?= $(CIRCT_ROOT)/lib/cmake/circt
VERILATOR ?= verilator
PYTHON ?= python3
CMAKE ?= cmake
NIX_SYSTEM := /nix/var/nix/profiles/default/bin/nix
NIX ?= $(if $(wildcard $(NIX_SYSTEM)),$(NIX_SYSTEM),nix)
NIX_FLAGS ?= --extra-experimental-features 'nix-command flakes' --accept-flake-config
PDK ?= sky130A
PDK_ROOT ?= $(HOME)/.ciel
PDK_COMMIT ?= 74c0e6b118a67d94c24172143d3bd597473fa63d
LIBRELANE := librelane --pdk-root $(PDK_ROOT) --pdk $(PDK)
export PDK_ROOT PDK

.PHONY: all setup-circt rtl contract-check rtl-check lvs-smoke-rtl-check memory-site-plugin memory-map-test \
	simple-soc-memory-map simple-soc-macro-rtl simple-soc-macro-rtl-check enable-pdk \
	harden harden-native lvs-smoke lvs-smoke-native integrate integrate-native gds clean

all: rtl-check

$(BUILD_DIR):
	mkdir -p $@

setup-circt:
	$(MAKE) -C $(RHDL_ROOT) setup-circt

$(BUILD_DIR)/rhdl-top.mlir: src/rhdl-top.rhdl tools/emit-top.rhm | $(BUILD_DIR)
	env PLTCOMPILEDROOTS=$(BUILD_DIR)/compiled $(RACKET) -S $(RHDL_ROOT) tools/emit-top.rhm > $@

$(BUILD_DIR)/rhdl-top.sv: $(BUILD_DIR)/rhdl-top.mlir
	@test -x $(CIRCT_OPT) || { \
		echo "circt-opt not found at $(CIRCT_OPT); run 'make setup-circt' or set CIRCT_OPT" >&2; \
		exit 1; \
	}
	$(CIRCT_OPT) \
		--strip-debuginfo-with-pred='drop-suffix=.mlir' \
		--canonicalize \
		--cse \
		--prettify-verilog \
		--lower-sim-to-sv \
		--lower-verif-to-sv \
		--lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
		--sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
		--export-verilog \
		$< -o /dev/null > $@

rtl: $(BUILD_DIR)/rhdl-top.sv

contract-check:
	$(PYTHON) tools/check-openframe-contract.py \
		--wrapper $(WRAPPER) \
		--harness-wrapper $(HARNESS_WRAPPER) \
		--pin-template $(PIN_TEMPLATE)

rtl-check: rtl contract-check
	$(VERILATOR) --lint-only --top-module $(TOP_NAME) -DUSE_POWER_PINS \
		-Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		$(BUILD_DIR)/rhdl-top.sv $(WRAPPER)

lvs-smoke-rtl-check: rtl
	$(VERILATOR) --lint-only --top-module $(LVS_TOP_NAME) -DUSE_POWER_PINS \
		-Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		$(BUILD_DIR)/rhdl-top.sv $(LVS_WRAPPER)

$(MEMORY_SITE_PLUGIN): $(MEMORY_SITE_PASS_DIR)/CMakeLists.txt $(MEMORY_SITE_PASS_DIR)/MemorySitePass.cpp | $(BUILD_DIR)
	@test -f $(CIRCT_CMAKE_DIR)/CIRCTConfig.cmake || { \
		echo "CIRCT CMake package not found at $(CIRCT_CMAKE_DIR); run 'make setup-circt' or set CIRCT_ROOT" >&2; \
		exit 1; \
	}
	$(CMAKE) -S $(MEMORY_SITE_PASS_DIR) -B $(MEMORY_SITE_PLUGIN_BUILD_DIR) \
		-DCIRCT_DIR=$(CIRCT_CMAKE_DIR) -DCMAKE_BUILD_TYPE=Release
	$(CMAKE) --build $(MEMORY_SITE_PLUGIN_BUILD_DIR) --parallel
	@test -s $@

memory-site-plugin: $(MEMORY_SITE_PLUGIN)

memory-map-test: $(MEMORY_SITE_PLUGIN)
	env PYTHON=$(PYTHON) VERILATOR=$(VERILATOR) CIRCT_OPT=$(CIRCT_OPT) \
		MEMORY_SITE_PLUGIN=$(MEMORY_SITE_PLUGIN) \
		$(PYTHON) -m unittest discover -s memory-map/tests -p 'test_*.py'

$(SIMPLE_SOC_BUILD_DIR):
	mkdir -p $@

$(SIMPLE_SOC_MLIR): tools/emit-simple-soc.rhm ../socs/simple-soc.rhdl | $(SIMPLE_SOC_BUILD_DIR)
	env PLTCOMPILEDROOTS=$(BUILD_DIR)/compiled PLTCOLLECTS=$(RHDL_ROOT): \
		$(RACKET) -S $(RHDL_ROOT) tools/emit-simple-soc.rhm > $@

$(SIMPLE_SOC_MEMORY_SITE_STAMP): $(SIMPLE_SOC_MLIR) $(MEMORY_SITE_PLUGIN) $(SIMPLE_SOC_MEMORY_POLICY)
	@test -x $(CIRCT_OPT) || { \
		echo "circt-opt not found at $(CIRCT_OPT); run 'make setup-circt' or set CIRCT_OPT" >&2; \
		exit 1; \
	}
	$(CIRCT_OPT) \
		--load-pass-plugin=$(MEMORY_SITE_PLUGIN) \
		--pass-pipeline="builtin.module(strip-debuginfo-with-pred{drop-suffix=.mlir},canonicalize,cse,rhdl-select-hw-top{top=SimpleSoC},hw-flatten-modules{hw-inline-all=true hw-inline-with-state=true},symbol-dce,lower-seq-firmem,rhdl-map-memory-sites{policy=$(SIMPLE_SOC_MEMORY_POLICY) inventory=$(SIMPLE_SOC_MEMORY_SITE_INVENTORY)},symbol-dce)" \
		$(SIMPLE_SOC_MLIR) -o $(SIMPLE_SOC_FIRRTL_MEM_MLIR)
	@test -s $(SIMPLE_SOC_FIRRTL_MEM_MLIR)
	@test -s $(SIMPLE_SOC_MEMORY_SITE_INVENTORY)
	touch $@

simple-soc-memory-map: \
		$(SIMPLE_SOC_MEMORY_SITE_STAMP) $(MEMORY_MAPPER) $(MEMORY_MAP_CATALOG)
	$(PYTHON) $(MEMORY_MAPPER) $(SIMPLE_SOC_FIRRTL_MEM_MLIR) \
		--catalog $(MEMORY_MAP_CATALOG) \
		--site-inventory $(SIMPLE_SOC_MEMORY_SITE_INVENTORY) \
		--pdk-root $(PDK_ROOT)/$(PDK) \
		--output-verilog $(SIMPLE_SOC_MEMORY_WRAPPERS) \
		--output-manifest $(SIMPLE_SOC_MEMORY_MANIFEST)
	@test -s $(SIMPLE_SOC_MEMORY_WRAPPERS)
	@test -s $(SIMPLE_SOC_MEMORY_MANIFEST)

$(SIMPLE_SOC_RTL): $(SIMPLE_SOC_MEMORY_SITE_STAMP)
	$(CIRCT_OPT) \
		--lower-seq-hlmem \
		--prettify-verilog \
		--lower-sim-to-sv \
		--lower-verif-to-sv \
		--lower-seq-to-sv='disable-mem-randomization=true disable-reg-randomization=true' \
		--hw-memory-sim='disable-mem-randomization=true disable-reg-randomization=true read-enable-mode=undefined' \
		--symbol-dce \
		--sv-mask-non-synthesizable='mode=ifdef macro=SYNTHESIS' \
		--export-verilog \
		$(SIMPLE_SOC_FIRRTL_MEM_MLIR) -o /dev/null > $@

simple-soc-macro-rtl: $(SIMPLE_SOC_RTL) simple-soc-memory-map

simple-soc-macro-rtl-check: simple-soc-macro-rtl
	@test -f $(SKY130_SRAM_MODEL) || { \
		echo "Sky130 SRAM model not found at $(SKY130_SRAM_MODEL); run 'make enable-pdk'" >&2; \
		exit 1; \
	}
	$(VERILATOR) --lint-only --timing --top-module SimpleSoC \
		-Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY -Wno-UNOPTFLAT \
		$(SIMPLE_SOC_RTL) $(SIMPLE_SOC_MEMORY_WRAPPERS) $(SKY130_SRAM_MODEL)

enable-pdk:
	@if command -v ciel >/dev/null 2>&1; then \
		ciel enable $(PDK_COMMIT) --pdk-family $(PDK); \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command ciel enable $(PDK_COMMIT) --pdk-family $(PDK); \
	else \
		echo "enable-pdk requires either ciel or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

harden: rtl-check
	@if command -v librelane >/dev/null 2>&1; then \
		$(MAKE) harden-native; \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command $(MAKE) harden-native; \
	else \
		echo "harden requires either LibreLane or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

harden-native: rtl
	command -v librelane >/dev/null
	$(LIBRELANE) $(CONFIG) --save-views-to $(BUILD_DIR)/views
	test -s $(BUILD_DIR)/views/gds/$(TOP_NAME).gds

lvs-smoke: rtl-check lvs-smoke-rtl-check
	@if command -v librelane >/dev/null 2>&1; then \
		$(MAKE) lvs-smoke-native; \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command $(MAKE) lvs-smoke-native; \
	else \
		echo "lvs-smoke requires either LibreLane or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

lvs-smoke-native: rtl lvs-smoke-rtl-check
	command -v librelane >/dev/null
	$(LIBRELANE) $(LVS_CONFIG) --run-tag RHDL_LVS --overwrite --condensed \
		--hide-progress-bar --save-views-to $(BUILD_DIR)/lvs-views
	test -s $(BUILD_DIR)/lvs-views/gds/$(LVS_TOP_NAME).gds
	grep -Eq "^Final result: (Circuits|Netlists) match" \
		$(LVS_RUN_DIR)/*-netgen-lvs/reports/lvs.netgen.rpt

integrate: harden
	@if command -v magic >/dev/null 2>&1; then \
		$(MAKE) integrate-native; \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command $(MAKE) integrate-native; \
	else \
		echo "integrate requires either Magic or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

integrate-native:
	command -v magic >/dev/null
	mkdir -p $(BUILD_DIR)/integrated
	PADFRAME_GDS=$(HARNESS_DIR)/gds/double_wide_chip_io.gds \
	USER_WRAPPER_GDS=$(BUILD_DIR)/views/gds/$(TOP_NAME).gds \
	OUT_GDS=$(BUILD_DIR)/integrated/double_wide_openframe.gds \
	magic -dnull -noconsole \
		-rcfile $(PDK_ROOT)/$(PDK)/libs.tech/magic/$(PDK).magicrc \
		$(HARNESS_DIR)/scripts/integrate_openframe.tcl
	test -s $(BUILD_DIR)/integrated/double_wide_openframe.gds

gds: integrate

clean:
	rm -rf $(BUILD_DIR) openlane/double_wide_openframe_project_wrapper/runs \
		openlane/rhdl_lvs_smoke/runs
