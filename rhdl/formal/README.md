<!-- Documents the optional Rosette formal engine, its supported semantics, API, and focused validation. -->

# RHDL formal engine

The formal engine is an optional consumer of verified public RHDL IR. It uses
Rosette fixed-width bitvectors to prove deterministic combinational behavioral
equivalence or produce a concrete counterexample. It does not participate in
elaboration and is not imported by `#lang rhdl`.

The architectural plan and staged semantic scope are in [`PLAN.md`](PLAN.md).

## Setup

Install Rosette into the active Racket installation:

```sh
raco pkg install --auto rosette
```

The milestone-1 implementation is validated with Racket 9.2, Rosette 4.0,
and Rosette's pinned Z3 4.8.8 binary. Rosette declares Racket 8.1 or newer;
other compatible Racket releases have not yet been exercised by this target.
A clean catalog installation was validated from an empty `PLTUSERHOME` with
Rosette checksum `373c8c35e4a7667f38fce10cf0b74ae17de07f1d` and its transitive
`rfc6455` checksum `e3a87e914e25841a6e1bb996aa001aeb178284bf`. The earlier
`rfc6455` resolution failure was caused by a restricted test environment, not
an unavailable package source; the repository does not vendor either package.

Confirm that Rosette and its solver are usable:

```sh
racket -e '(require rosette) (displayln (solve (assert #t)))'
```

Ordinary RHDL host and backend targets do not require Rosette. Run the focused
formal suite with:

```sh
make formal-test
```

Run the independent backend differential check when CIRCT and Verilator are
available:

```sh
make formal-differential-test
```

That target proves structurally different shift, aggregate, and hierarchical
implementations equivalent, obtains live counterexamples for defects in each
category, and passes those exact packed inputs and outputs to a shared
CIRCT-generated Verilator DUT. The testbench also exhaustively checks all 128
reduced-width unequal-shift inputs, 80 aggregate layouts and projections, and
256 hierarchical arithmetic inputs against independent SystemVerilog oracles.
Set `CIRCT_OPT=/path/to/circt-opt` when the pinned tool is not installed under
the current checkout's `.tools/` directory.

## Milestone 1 API

Import `rhdl/formal/main.rhm` explicitly and call `check_equivalent` with two
verified `DesignElaboration` values or two completed core `Module` values.
Both top interfaces must have exactly the same port names and mutually equal
RHDL types.

The result status is one of `equivalent`, `counterexample`, `unsupported`, or
`unknown`. A counterexample contains every top input assignment and every
differing output. An unsupported result identifies the first reachable
operation outside the deterministic combinational contract.

Equivalence is behavioral: two designs may have different module structure,
operation order, names below the top interface, or printed IR and still prove
equivalent. The checker is not a textual or structural diff.

## Supported semantics

All packable values use the canonical RHDL packed layout. The milestone-1a
operation contract is explicit:

| Category | Supported operations |
| --- | --- |
| Structure | `rtl.input_port`, `rtl.output_port`, `rtl.wire`, `rtl.drive`, `rtl.instance` |
| Constants and bitwise | `rtl.constant`, `rtl.not`, `rtl.and`, `rtl.or`, `rtl.xor` |
| Modular arithmetic | `rtl.add`, `rtl.mul`, `rtl.sub` |
| Shifts | `rtl.shl`, `rtl.shru`, `rtl.shrs`, including unequal operand widths and overshifts |
| Comparisons | `rtl.eq`, `rtl.ult`, `rtl.slt` |
| Selection | total `rtl.mux_lookup` |
| Packing and widths | `rtl.cast`, `rtl.concat`, `rtl.extract`, `rtl.zext`, `rtl.sext`, `rtl.trunc` |
| Aggregates | `rtl.record_create`, `rtl.record_get`, `rtl.vector_create`, `rtl.vector_get` |

The engine returns `unsupported` for `rtl.dont_care`, `rtl.decode`,
`rtl.onehot_mux`, registers, every memory form, assertions, DPI operations,
and unknown operations. It performs this preflight before allocating symbolic
inputs or invoking a solver, and it does not invent values or assumptions for
unspecified behavior. Deterministic fully cared `rtl.decode` remains the
optional milestone-1b extension described in the plan.

Counterexample input values and differing output values are nonnegative packed
integers. Inputs omitted from a partial solver model are completed with zero,
then both designs are interpreted concretely so every reported difference is
replayable.
