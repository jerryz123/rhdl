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

RACKET ?= racket
CIRCT_OPT ?= $(RHDL_ROOT)/.tools/firtool-1.155.0/bin/circt-opt
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

.PHONY: all setup-circt rtl contract-check rtl-check enable-pdk harden harden-native \
	integrate integrate-native gds clean

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
	rm -rf $(BUILD_DIR) openlane/double_wide_openframe_project_wrapper/runs
