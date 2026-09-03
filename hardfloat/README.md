<!-- Documents the provenance, architecture, supported surface, and validation of the RHDL HardFloat port. -->

# HardFloat for RHDL

This directory is an RHDL port of the
[Berkeley HardFloat](https://github.com/ucb-bar/berkeley-hardfloat) Chisel
source. The translation is pinned to upstream commit
[`c1105e6ac6a0dd90fc80893efc4830ab609005d3`](https://github.com/ucb-bar/berkeley-hardfloat/commit/c1105e6ac6a0dd90fc80893efc4830ab609005d3).
The Regents of the University of California and SiFive retain copyright in
the derived algorithms. See [`LICENSE.md`](LICENSE.md) for the applicable
upstream BSD-style licenses. This project is not endorsed by the University
of California, SiFive, or the upstream contributors.

The port is ordinary RHDL. It elaborates into the same public core IR as any
other RHDL library and lowers through the existing CIRCT backend. It does not
add floating-point operations to core, import Chisel, or wrap generated
Verilog.

## Status

The implemented foundation provides:

- stable host-side `FloatFormat` values for arbitrary supported formats and
  predefined binary16, bfloat16, binary32, and binary64 formats;
- typed hardware rounding modes, tininess modes, exception flags, raw
  floating-point records, and one-hot classification results;
- the HardFloat leading-zero and grouped-reduction primitives;
- IEEE-to-raw, IEEE-to-recoded, recoded-to-raw, and recoded-to-IEEE helpers;
- raw-format resizing with exponent saturation and significand sticky-bit
  preservation;
- all upstream rounding modes and tininess modes through
  `RoundAnyRawFNToRecFN` and `RoundRawFNToRecFN`;
- signed and unsigned integer conversion in both directions;
- widening and rounded narrowing between arbitrary supported RecFN formats;
- recoded classification; and
- the combinational `CompareRecFN`, rounded `AddRecFN` and `MulRecFN`, and
  single-rounding fused `MulAddRecFN` circuits, with explicit add/subtract and
  fused-operation controls; and
- the generic iterative `DivSqrtRecFN` unit in one-bit-per-cycle and
  two-bits-per-cycle configurations; and
- the pipelined multiply-assisted `DivSqrtRecF64`, plus its shareable external
  multiplier interface `DivSqrtRecF64MulAddZ31`.

The arithmetic components in the planned upstream port are now implemented.
Unported auxiliary wrappers are omitted rather than represented by stubs.

## Layout and dependency boundary

| Path | Responsibility |
|---|---|
| [`main.rhdl`](main.rhdl) | Public package facade |
| [`rtl/types.rhdl`](rtl/types.rhdl) | Format parameters and typed hardware records/enums |
| [`rtl/primitives.rhdl`](rtl/primitives.rhdl) | Representation-independent bit helpers used by the port |
| [`rtl/recode.rhdl`](rtl/recode.rhdl) | IEEE, recoded, and raw representation conversion |
| [`rtl/resize.rhdl`](rtl/resize.rhdl) | Raw exponent/significand resizing and sticky-bit preservation |
| [`rtl/round.rhdl`](rtl/round.rhdl) | Shared raw-to-recoded rounding and exception generation |
| [`rtl/conversion/`](rtl/conversion/) | Integer normalization and integer/RecFN/format conversion |
| [`rtl/classify.rhdl`](rtl/classify.rhdl) | Ten-way HardFloat classification |
| [`rtl/arithmetic/compare.rhdl`](rtl/arithmetic/compare.rhdl) | Ordered recoded comparison and invalid-operation flagging |
| [`rtl/arithmetic/add.rhdl`](rtl/arithmetic/add.rhdl) | Close/far addition and subtraction paths, normalization, rounding, and exceptions |
| [`rtl/arithmetic/multiply.rhdl`](rtl/arithmetic/multiply.rhdl) | Full raw product, sticky compression, rounding, and exception generation |
| [`rtl/arithmetic/multiply-add.rhdl`](rtl/arithmetic/multiply-add.rhdl) | Pre-multiply alignment, full-width multiply-add, post-multiply normalization, and one final rounding |
| [`rtl/arithmetic/divide-sqrt.rhdl`](rtl/arithmetic/divide-sqrt.rhdl) | Generic iterative division and square root with selectable one- or two-bit progress per cycle |
| [`rtl/arithmetic/divide-sqrt-f64.rhdl`](rtl/arithmetic/divide-sqrt-f64.rhdl) | Four-operation binary64 pipeline and its three-cycle 54x54+105 multiplier contract |
| [`tests/`](tests/) | Elaboration, structural, CIRCT, and simulation validation |

Production files depend only on the public `#lang rhdl` authoring surface and
other files in this package. They must not import RHDL implementation layers,
backends, tests, processor cores, or RISC-V definitions. Backend tooling is a
test-only consumer.

## Types and representation

`FloatFormat(exponent_width, significand_width)` uses HardFloat's convention:
the significand width includes the implicit leading bit. Consequently, an
IEEE value has `exponent_width + significand_width` bits and its recoded form
has one additional exponent bit. Formats require both widths to be at least
three and `significand_width <= 2^(exponent_width - 2) + 3`, matching
HardFloat's supported parameter domain. BF16 retains IEEE-style subnormal
support, as in upstream HardFloat.

IEEE and recoded operands remain `Bits` so they interoperate directly with
packed architectural state and external interfaces. `RawFloat` is a bundle
whose signed exponent and extended significand expose the internal HardFloat
algorithm. `RoundingMode`, `TininessMode`, `ExceptionFlags`, and `FloatClass`
give names to otherwise positional control and result bits without changing
their packed encodings. `RoundingOptions` is a stable host parameter for the
four compile-time invariants used by specialized upstream rounding clients;
it does not add hardware control ports.

The predefined formats are:

| Name | Exponent | Significand | IEEE width | Recoded width |
|---|---:|---:|---:|---:|
| `FloatFormat.F16` | 5 | 11 | 16 | 17 |
| `FloatFormat.BF16` | 8 | 8 | 16 | 17 |
| `FloatFormat.F32` | 8 | 24 | 32 | 33 |
| `FloatFormat.F64` | 11 | 53 | 64 | 65 |

## Public use

```rhombus
#lang rhdl

import:
  lib("hardfloat/main.rhdl") open

circuit CompareF32():
  input a: Bits(FloatFormat.F32.recoded_width)
  input b: Bits(FloatFormat.F32.recoded_width)
  input signaling: Bool
  output less: Bool

  inst compare(CompareRecFN(FloatFormat.F32))
  compare.a <== a
  compare.b <== b
  compare.signaling <== signaling
  less <== compare.lt
```

Use `recfn_from_fn` and `fn_from_recfn` at IEEE boundaries. Raw representations
are public so later arithmetic stages and specialized implementations can
share them, but they are not an architectural storage format.

`DivSqrtRecF64` preserves the upstream specialized protocol: division computes
`a / b`, while square root consumes `b`; the two operation classes have
independent ready and completion outputs. `DivSqrtRecF64MulAddZ31` exposes the
same recurrence with its pipelined multiplier-adder ports so a system can share
that resource instead of instantiating the integrated multiplier.

## Translation policy

Each derived RHDL source names its corresponding upstream Scala source and
the pinned commit. Chisel width inference is translated into explicit RHDL
widths. Pure combinational Scala objects become RHDL functions; a meaningful
upstream module boundary remains a circuit. Internal hierarchy and temporary
names are not compatibility promises, but packed values, special-case
behavior, exception flags, and public sequential protocols are.

## Validation

Run the focused host checks from the repository root:

```sh
make hardfloat-host-test
```

Run CIRCT verification and the combinational representation/rounding
simulations with:

```sh
make hardfloat-circt-test
```

Every Racket or Rhombus command is run through the repository wrappers, which
provide a fresh compiled root. The current slice checks format specialization,
packed type layouts, raw operation structure, representative IEEE special
values, exhaustive binary16 representation round trips, classification,
comparison, raw resizing, discarded-bit rounding across all rounding families,
overflow behavior, integer conversion with signed and unsigned saturation,
exact format widening, lossy format narrowing, and generated SystemVerilog
compilation. Multiplication coverage includes special values, signed zero,
discarded-bit rounding, overflow, exact subnormal results, and underflow.
Addition coverage selects close-cancellation and far-alignment paths and checks
ties, directed rounding, signed zero, overflow, infinities, and NaNs. Fused
multiply-add coverage exercises all four product/addend sign-control encodings,
special values, overflow, underflow, and a cancellation vector whose
single-rounded answer differs from a separately rounded multiply followed by
add. The suite also exhaustively checks binary16 `x + 0` and finite `x - x`
behavior. Iterative division and square-root coverage compares both throughput
configurations across normal, directed-rounding, signed-zero, NaN, infinity,
overflow, underflow, and invalid-operation cases, and checks that the two-bit
configuration completes normal operations sooner. Later validation work will
add differential vectors from Berkeley TestFloat and SoftFloat. The
specialized binary64 suite checks its independent admission signals,
three-cycle multiplier integration, normal and exceptional results, directed
rounding, and ordered completion with multiple divisions in flight.

## Follow-up work

1. Add broader differential vectors from Berkeley TestFloat and SoftFloat.
2. Compare representative area and timing with the pinned upstream Chisel
   implementation without making a particular internal netlist contractual.
