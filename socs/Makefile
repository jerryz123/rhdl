# Runs focused planning and elaboration checks for repository SoCs.
REPO_DIR := $(abspath ..)
RACO ?= raco

.PHONY: all rtl-elaboration-test tiled-plan-test tiled-elaboration-test

all: rtl-elaboration-test tiled-plan-test tiled-elaboration-test

rtl-elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhodium-simple-soc-rtl.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test \
	  socs/tests/simple-soc-test.rhm \
	  socs/tests/dram-soc-test.rhm

tiled-plan-test:
	compiled_root="$$(mktemp -d /tmp/rhodium-tiled-soc-plan.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test \
	  socs/tests/tiled-soc-plan-test.rhm \
	  socs/tests/tiled-soc-config-test.rhm

tiled-elaboration-test:
	compiled_root="$$(mktemp -d /tmp/rhodium-tiled-soc-rtl.XXXXXX)"; \
	cd $(REPO_DIR) && env PLTCOMPILEDROOTS="$$compiled_root" \
	  PLTCOLLECTS=$(REPO_DIR): $(RACO) test \
	  socs/tests/tiled-tiles-test.rhm \
	  socs/tests/tiled-soc-test.rhm
