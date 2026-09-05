# Runs focused planning and elaboration checks for repository SoCs.
REPO_DIR := $(abspath ..)
RACO ?= raco

.PHONY: all rtl-elaboration-test tiled-plan-test tiled-elaboration-test

all: rtl-elaboration-test tiled-plan-test tiled-elaboration-test

rtl-elaboration-test:
	cd $(REPO_DIR) && RACO="$(RACO)" tools/run-racket-tests.sh \
	  socs/tests/simple-soc-test.rhm \
	  socs/tests/mini-soc-test.rhm

tiled-plan-test:
	cd $(REPO_DIR) && RACO="$(RACO)" tools/run-racket-tests.sh \
	  socs/tests/tiled-soc-plan-test.rhm \
	  socs/tests/tiled-soc-config-test.rhm

tiled-elaboration-test:
	cd $(REPO_DIR) && RACO="$(RACO)" tools/run-racket-tests.sh \
	  socs/tests/tiled-tiles-test.rhm \
	  socs/tests/tiled-soc-test.rhm
