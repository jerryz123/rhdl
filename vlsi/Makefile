# Builds Rhodium smoke designs and mapped SimpleSoC artifacts through CIRCT and LibreLane.

.DELETE_ON_ERROR:

RHODIUM_ROOT := $(abspath ..)
VLSI_ROOT := $(CURDIR)
HARNESS_DIR := $(VLSI_ROOT)/double_wide_openframe
BUILD_DIR := $(VLSI_ROOT)/build
CONFIG := $(VLSI_ROOT)/openlane/double_wide_openframe_project_wrapper/config.yaml
WRAPPER := $(VLSI_ROOT)/verilog/rtl/double_wide_openframe_project_wrapper.v
HARNESS_WRAPPER := $(HARNESS_DIR)/verilog/rtl/double_wide_openframe_project_wrapper.v
PIN_TEMPLATE := $(HARNESS_DIR)/librelane/wrapper/pin_template.def
TOP_NAME := double_wide_openframe_project_wrapper
LVS_CONFIG := $(VLSI_ROOT)/openlane/rhodium_lvs_smoke/config.yaml
LVS_WRAPPER := $(VLSI_ROOT)/verilog/rtl/rhodium_lvs_smoke.v
LVS_TOP_NAME := rhodium_lvs_smoke
LVS_RUN_DIR := $(VLSI_ROOT)/openlane/rhodium_lvs_smoke/runs/RHODIUM_LVS
SRAM_ROOT := $(RHODIUM_ROOT)/sram
MEMORY_MAP_CATALOG := $(SRAM_ROOT)/sky130/macros.ini
MEMORY_MAPPER := $(SRAM_ROOT)/map-memories.py
MEMORY_SITE_PASS_DIR := $(SRAM_ROOT)/circt
MEMORY_SITE_PLUGIN := $(SRAM_ROOT)/build/circt/rhodium-memory-sites.so
SIMPLE_SOC_MEMORY_POLICY := $(VLSI_ROOT)/designs/simple-soc/sky130/sram-map.yaml
SIMPLE_SOC_BUILD_DIR := $(BUILD_DIR)/simple-soc
SIMPLE_SOC_RHODIUM_SOURCES := $(addprefix $(RHODIUM_ROOT)/,$(shell git -C $(RHODIUM_ROOT) ls-files '*.rhdl'))
SIMPLE_SOC_MLIR := $(SIMPLE_SOC_BUILD_DIR)/simple-soc.mlir
SIMPLE_SOC_FIRRTL_MEM_MLIR := $(SIMPLE_SOC_BUILD_DIR)/simple-soc-firmem.mlir
SIMPLE_SOC_MEMORY_SITE_INVENTORY := $(SIMPLE_SOC_BUILD_DIR)/memory-sites.json
SIMPLE_SOC_MEMORY_SITE_STAMP := $(SIMPLE_SOC_BUILD_DIR)/memory-sites.stamp
SIMPLE_SOC_RTL := $(SIMPLE_SOC_BUILD_DIR)/simple-soc.sv
SIMPLE_SOC_MEMORY_WRAPPERS := $(SIMPLE_SOC_BUILD_DIR)/memory-wrappers.sv
SIMPLE_SOC_MEMORY_MANIFEST := $(SIMPLE_SOC_BUILD_DIR)/memory-manifest.json
SIMPLE_SOC_SYNTH_CONFIG := $(VLSI_ROOT)/openlane/simple_soc/config.yaml
SIMPLE_SOC_SLANG_RUN_DIR := $(VLSI_ROOT)/openlane/simple_soc/runs/RHODIUM_SLANG_CHECK
SIMPLE_SOC_SLANG_NETLIST := $(SIMPLE_SOC_SLANG_RUN_DIR)/final/nl/SimpleSoC.nl.v
SIMPLE_SOC_SYNTH_RUN_DIR := $(VLSI_ROOT)/openlane/simple_soc/runs/RHODIUM_SLANG_SYNTH
SIMPLE_SOC_SYNTH_NETLIST := $(SIMPLE_SOC_SYNTH_RUN_DIR)/final/nl/SimpleSoC.nl.v
SKY130_SRAM_MODEL = $(PDK_ROOT)/$(PDK)/libs.ref/sky130_sram_macros/verilog/sky130_sram_2kbyte_1rw1r_32x512_8.v

RACKET ?= racket
CIRCT_OPT ?= $(RHODIUM_ROOT)/.tools/firtool-1.155.0/bin/circt-opt
CIRCT_ROOT ?= $(abspath $(dir $(CIRCT_OPT))/..)
VERILATOR ?= verilator
PYTHON ?= python3
NIX_SYSTEM := /nix/var/nix/profiles/default/bin/nix
NIX ?= $(if $(wildcard $(NIX_SYSTEM)),$(NIX_SYSTEM),nix)
NIX_FLAGS ?= --extra-experimental-features 'nix-command flakes' --accept-flake-config
PDK ?= sky130A
PDK_ROOT ?= $(HOME)/.ciel
PDK_COMMIT ?= 74c0e6b118a67d94c24172143d3bd597473fa63d
LIBRELANE := librelane --pdk-root $(PDK_ROOT) --pdk $(PDK)
export PDK_ROOT PDK

.PHONY: all setup-circt rtl contract-check rtl-check lvs-smoke-rtl-check memory-site-plugin memory-map-test \
	simple-soc-memory-map simple-soc-macro-rtl simple-soc-macro-rtl-check \
	simple-soc-slang-check simple-soc-slang-check-native \
	simple-soc-synth simple-soc-synth-native enable-pdk \
	harden harden-native lvs-smoke lvs-smoke-native integrate integrate-native gds clean

all: rtl-check

$(BUILD_DIR):
	mkdir -p $@

setup-circt:
	$(MAKE) -C $(RHODIUM_ROOT) setup-circt

$(BUILD_DIR)/rhodium-top.mlir: src/rhodium-top.rhdl tools/emit-top.rhm | $(BUILD_DIR)
	env PLTCOMPILEDROOTS=$(BUILD_DIR)/compiled $(RACKET) -S $(RHODIUM_ROOT) tools/emit-top.rhm > $@

$(BUILD_DIR)/rhodium-top.sv: $(BUILD_DIR)/rhodium-top.mlir
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

rtl: $(BUILD_DIR)/rhodium-top.sv

contract-check:
	$(PYTHON) tools/check-openframe-contract.py \
		--wrapper $(WRAPPER) \
		--harness-wrapper $(HARNESS_WRAPPER) \
		--pin-template $(PIN_TEMPLATE)

rtl-check: rtl contract-check
	$(VERILATOR) --lint-only --top-module $(TOP_NAME) -DUSE_POWER_PINS \
		-Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		$(BUILD_DIR)/rhodium-top.sv $(WRAPPER)

lvs-smoke-rtl-check: rtl
	$(VERILATOR) --lint-only --top-module $(LVS_TOP_NAME) -DUSE_POWER_PINS \
		-Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
		$(BUILD_DIR)/rhodium-top.sv $(LVS_WRAPPER)

$(MEMORY_SITE_PLUGIN): $(MEMORY_SITE_PASS_DIR)/CMakeLists.txt $(MEMORY_SITE_PASS_DIR)/MemorySitePass.cpp
	$(MAKE) -C $(SRAM_ROOT) plugin CIRCT_OPT=$(CIRCT_OPT) CIRCT_ROOT=$(CIRCT_ROOT)
	@test -s $@

memory-site-plugin: $(MEMORY_SITE_PLUGIN)

memory-map-test:
	$(MAKE) -C $(SRAM_ROOT) test CIRCT_OPT=$(CIRCT_OPT) CIRCT_ROOT=$(CIRCT_ROOT) \
		PYTHON=$(PYTHON) VERILATOR=$(VERILATOR)

$(SIMPLE_SOC_BUILD_DIR):
	mkdir -p $@

$(SIMPLE_SOC_MLIR): tools/emit-simple-soc.rhm $(SIMPLE_SOC_RHODIUM_SOURCES) | $(SIMPLE_SOC_BUILD_DIR)
	env PLTCOMPILEDROOTS=$(BUILD_DIR)/compiled PLTCOLLECTS=$(RHODIUM_ROOT): \
		$(RACKET) -S $(RHODIUM_ROOT) tools/emit-simple-soc.rhm > $@

$(SIMPLE_SOC_MEMORY_SITE_STAMP): $(SIMPLE_SOC_MLIR) $(MEMORY_SITE_PLUGIN) $(SIMPLE_SOC_MEMORY_POLICY)
	@test -x $(CIRCT_OPT) || { \
		echo "circt-opt not found at $(CIRCT_OPT); run 'make setup-circt' or set CIRCT_OPT" >&2; \
		exit 1; \
	}
	$(CIRCT_OPT) \
		--load-pass-plugin=$(MEMORY_SITE_PLUGIN) \
		--pass-pipeline="builtin.module(strip-debuginfo-with-pred{drop-suffix=.mlir},canonicalize,cse,rhodium-select-hw-top{top=SimpleSoC},hw-flatten-modules{hw-inline-all=true hw-inline-with-state=true},symbol-dce,lower-seq-firmem,rhodium-map-memory-sites{policy=$(SIMPLE_SOC_MEMORY_POLICY) inventory=$(SIMPLE_SOC_MEMORY_SITE_INVENTORY) top=SimpleSoC},symbol-dce)" \
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
	@test "$$(grep -c '\"source_module\": \"rv5stage/l1_512x64\"' $(SIMPLE_SOC_MEMORY_SITE_INVENTORY))" -eq 2
	@if grep -q '64x512' $(SIMPLE_SOC_MEMORY_SITE_INVENTORY); then \
		echo "SimpleSoC inventory contains a line-wide cache data memory" >&2; \
		exit 1; \
	fi

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

simple-soc-slang-check: simple-soc-macro-rtl
	@if command -v librelane >/dev/null 2>&1; then \
		$(MAKE) simple-soc-slang-check-native; \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command $(MAKE) simple-soc-slang-check-native; \
	else \
		echo "simple-soc-slang-check requires either LibreLane or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

simple-soc-slang-check-native: simple-soc-macro-rtl
	command -v librelane >/dev/null
	$(LIBRELANE) $(SIMPLE_SOC_SYNTH_CONFIG) --run-tag RHODIUM_SLANG_CHECK --overwrite \
		--override-config SYNTH_ELABORATE_ONLY=true --only Yosys.Synthesis \
		--condensed --hide-progress-bar
	test -s $(SIMPLE_SOC_SLANG_NETLIST)
	grep -q "use_slang" $(SIMPLE_SOC_SLANG_RUN_DIR)/*-yosys-synthesis/yosys-synthesis.log
	test "$$(grep -c 'sky130_sram_2kbyte_1rw1r_32x512_8 ' $(SIMPLE_SOC_SLANG_NETLIST))" -eq 32
	@if grep -Eq 'struct[[:space:]]+packed|typedef[[:space:]]+struct' $(SIMPLE_SOC_SLANG_NETLIST); then \
		echo "Slang elaboration left packed structs in $(SIMPLE_SOC_SLANG_NETLIST)" >&2; \
		exit 1; \
	fi

simple-soc-synth: simple-soc-macro-rtl
	@if command -v librelane >/dev/null 2>&1; then \
		$(MAKE) simple-soc-synth-native; \
	elif command -v $(NIX) >/dev/null 2>&1; then \
		$(NIX) $(NIX_FLAGS) develop $(HARNESS_DIR) --command $(MAKE) simple-soc-synth-native; \
	else \
		echo "simple-soc-synth requires either LibreLane or Nix; see vlsi/README.md" >&2; \
		exit 1; \
	fi

simple-soc-synth-native: simple-soc-macro-rtl
	command -v librelane >/dev/null
	$(LIBRELANE) $(SIMPLE_SOC_SYNTH_CONFIG) --run-tag RHODIUM_SLANG_SYNTH --overwrite \
		--only Yosys.Synthesis --condensed --hide-progress-bar
	test -s $(SIMPLE_SOC_SYNTH_NETLIST)
	grep -q "use_slang" $(SIMPLE_SOC_SYNTH_RUN_DIR)/*-yosys-synthesis/yosys-synthesis.log
	test "$$(grep -c 'sky130_sram_2kbyte_1rw1r_32x512_8 ' $(SIMPLE_SOC_SYNTH_NETLIST))" -eq 32

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
	$(LIBRELANE) $(LVS_CONFIG) --run-tag RHODIUM_LVS --overwrite --condensed \
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
		openlane/rhodium_lvs_smoke/runs
