<!-- Defines the concrete RV64I core package, its ALU contract, and verification workflow. -->

# RV64I core

The top-level `core/` package contains a concrete processor implementation built
with RHDL. It is distinct from [`rhdl/core/`](../rhdl/core/README.md), which owns
the language's frontend-independent hardware IR.

## Dependency boundary

```text
core/decode/alu-ctrl.rhdl --> riscv/isa + riscv/rhdl + rhdl/std/decode
                     |
                     v
               core/alu.rhdl --> #lang rhdl
```

The concrete core may consume RHDL and the pure RISC-V model, but it must not
import the optional CIRCT backend or test implementation. Backend consumers
operate on the public design after elaboration.

## Integer ALU

[`alu.rhdl`](alu.rhdl) defines a stateless 64-bit ALU whose `AluControl` input
contains one nominal one-hot `AluResultSelect` enum and four orthogonal
modifiers. Its data inputs are already-selected 64-bit operands. It owns modular
arithmetic, bitwise operations, six-bit RV64 shifts, signed and unsigned
set-less-than results, and the five RV64 word behaviors with five-bit shifts
and 32-to-64-bit sign extension.

Arithmetic right shift and word-result extension use the standard frontend
`SInt` operations through explicit representation casts.

Keyed `mux_onehot` arms select the arithmetic, shift, comparison, XOR, OR, or
AND result directly from the enum members. The datapath uses the decoded modifiers
directly: `subtract` chooses the
arithmetic result, `signed_mode` chooses comparison and right-shift semantics,
`shift_right` chooses direction, and `word` steers five-bit shifts and one
shared final sign extension. The word modifier is qualified by the arithmetic
or shift selector, so it cannot contaminate families where it is unconstrained.
Signed and unsigned less-than share one unsigned
comparator; sign-bit logic adjusts that result for signed ordering. Each shift
direction shares one 64-bit dynamic shifter between its full-width and word
forms; left, logical right, and arithmetic right remain separate pending an
area/timing study of a universal bidirectional shifter.

[`decode/alu-ctrl.rhdl`](decode/alu-ctrl.rhdl) defines the RV64I decode cases for the
28 OP, OP-IMM, OP-32, and OP-IMM-32 instructions. Each output is a typed partial
`Pattern(AluControl())`: listed selectors and meaningful modifiers are cared,
while omitted fields are synthesis don't-cares. Its `RV64IAluDecode` is a
valid-tagged `DecodeGen`; `RV64IAluInstructionDecoder` exposes `valid` beside
the decoded bundle, with a wholly don't-care bundle when `valid` is false.
PC/immediate selection, address generation, branches, memory, and writeback
remain outside the ALU contract.

Run the focused host and external-backend checks from the repository root:

```sh
make rv64i-core-test
```
