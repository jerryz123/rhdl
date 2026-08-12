#lang rhombus
// Defines the base Rhombus bindings and RHDL runtime available to #lang rhdl modules.

import:
  rhombus
  "main.rhm" open
  "frontend-runtime.rhm" open

export:
  all_from(rhombus)
  all_from("main.rhm")
  all_from("frontend-runtime.rhm")
