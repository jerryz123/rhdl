#lang rhombus/and_meta
// Defines #lang rhdl as Rhombus plus the embedded RHDL standard layer.

import:
  rhombus
  rhombus/meta open
  "main.rhm" open
  "frontend-std.rhm" open

export:
  all_from(rhombus)
  all_from("main.rhm")
  all_from("frontend-std.rhm")
  if

expr.macro 'if $condition | $true_result | $false_result':
  'rhombus.if host_condition($condition) | $true_result | $false_result'
