<!-- Defines ownership and dependency boundaries for reusable processor components and named cores. -->

# Processor components and cores

The top-level `cores/` package holds both reusable processor components and
named processor implementations. It is distinct from
[`rhdl/core/`](../rhdl/core/README.md), which owns the language's
frontend-independent hardware IR.

Only components intended for reuse across processors belong directly under
`cores/`. A named core owns its instruction-specific decode, pipeline,
architectural state, and integrated tests in `cores/<name>/`.

## Package layout

| Path | Owner |
|---|---|
| [`alu.rhdl`](alu.rhdl) | Width-parameterized 32- or 64-bit integer ALU |
| [`branch-resolver.rhdl`](branch-resolver.rhdl) | Width-parameterized branch comparison and resolution |
| [`load-store.rhdl`](load-store.rhdl) | XLEN scalar-access width, alignment, load extraction, and store lane generation |
| [`multiplier.rhdl`](multiplier.rhdl) | Width-generic iterative signed and unsigned multiplication |
| [`divider.rhdl`](divider.rhdl) | Width-generic iterative signed and unsigned division |
| [`tests/alu-test.rhm`](tests/alu-test.rhm) | Direct tests for the reusable ALU |
| [`tests/branch-resolver-test.rhm`](tests/branch-resolver-test.rhm) | Direct tests for the reusable branch resolver |
| [`tests/load-store-test.rhm`](tests/load-store-test.rhm) | Direct structural tests for the reusable load/store generators |
| [`tests/multiplier-test.rhm`](tests/multiplier-test.rhm) | Direct structural tests for the iterative multiplier |
| [`tests/divider-test.rhm`](tests/divider-test.rhm) | Direct structural tests for the iterative divider |
| [`rv5stage/`](rv5stage/README.md) | RV5Stage's RV32I/RV64I decode, five-stage pipeline, CSR/privilege state, caches, and tests |

The dependency direction is one way:

```text
cores/rv5stage/ --> cores/{alu,branch-resolver,load-store,multiplier,divider}.rhdl
       |-------> riscv/isa + riscv/rhdl
       `-------> rhdl/std

cores/{alu,load-store}.rhdl --> riscv/isa/xlen + #lang rhdl + rhdl/std
cores/branch-resolver.rhdl --> #lang rhdl only
cores/multiplier.rhdl --> #lang rhdl + rhdl/std
cores/divider.rhdl --> #lang rhdl + rhdl/std
```

Neither reusable components nor named cores may import the optional CIRCT
backend, examples, or test implementations. Backend consumers elaborate their
public designs from outside this package. Reusable components may consume the
closed architectural `XLen` configuration but remain independent of RISC-V
instruction catalogs, field models, decode adapters, and named cores.

## Iterative multiplier

[`multiplier.rhdl`](multiplier.rhdl) defines a one-request-at-a-time shift-add
engine parameterized by operand width. Each request supplies two operands and
a `MultiplierMode` that independently selects whether either operand is
signed. The irrevocable response carries the complete double-width product and
remains stable until accepted. Multiplication consumes one multiplier bit per
cycle, and the unit can accept a replacement request in the cycle that a held
response is consumed.

The component does not select architectural high, low, or word results and
does not import an instruction catalog. Those policies remain in a named
core's decode and writeback logic.

## Iterative divider

[`divider.rhdl`](divider.rhdl) defines a one-request-at-a-time restoring
divider parameterized by operand width. A request selects signed or unsigned
interpretation, and the irrevocable response returns both quotient and
remainder after one quotient bit is resolved per cycle. Division by zero
returns an all-one quotient and the original dividend; fixed-width signed
overflow returns the wrapped minimum quotient and zero remainder.

The component does not select quotient versus remainder or define
architecture-specific word operations. RV5Stage owns those projections in its
adapter and decode logic.

## Integer ALU

[`alu.rhdl`](alu.rhdl) defines a stateless `ALU(xlen)` whose host parameter is
`XLen.X32` or `XLen.X64`. Its `AluControl` input
contains one nominal one-hot `AluResultSelect` enum and four orthogonal
modifiers. Its data inputs are already-selected
`Bits(xlen.width)` operands. It owns modular arithmetic, bitwise
operations, XLEN-sized shifts, and signed and unsigned set-less-than results.
The 64-bit specialization additionally supports
32-bit word behaviors with five-bit shifts and 32-to-64-bit sign extension;
`word` is inert in the 32-bit specialization.

Typed-key one-hot-enum `.mux` arms select the arithmetic, shift, comparison, XOR, OR, or
AND result directly. `subtract`, `signed_mode`, `shift_right`, and `word`
modify only the selected family. The ALU deliberately knows nothing about
instruction encodings, operand routing, memory, branches, or writeback.

## Branch resolver

[`branch-resolver.rhdl`](branch-resolver.rhdl) defines a stateless,
width-parameterized `Valid` transform from `BranchResolverRequest` to
`BranchResult`. Decode drives orthogonal `enable`, `unconditional`,
`compare_equal`, `signed_mode`, and `invert` signals instead of an
instruction-shaped condition enum. The resolver owns equality and signed or
unsigned less-than comparison and carries request validity to its `taken`
result. It knows nothing about instruction encodings, target selection, PCs,
execute-stage acceptance, or redirects.

## Load and store generators

[`load-store.rhdl`](load-store.rhdl) owns the shared `MemoryWidth` control and
two stateless XLEN-parameterized datapath components. `LoadGen` selects a byte,
halfword, word, or doubleword from an eight-byte returned beat and extends it to
32 or 64 bits. `StoreGen` shifts an XLEN scalar source into its addressed byte
lane and generates the corresponding `Mask(8)` write-lane set.

`MemoryWidth.is_aligned(address)` checks the same size contract independently. The
generators deliberately know nothing about instruction encodings, memory
protocols, request ordering, or pipeline stalls, so a core can reuse them with
a cache, scratchpad, or another bus. The core remains responsible for aligning
the beat address and for preventing a misaligned access from becoming a
request.

Run the reusable components' direct host tests from the repository root:

```sh
tools/run-racket-tests.sh cores/tests/*-test.rhm
```

Run [`make rv5stage-host-test`](../Makefile) for all reusable components together
with RV5Stage's decode and elaboration tests. `make rv5stage-test` additionally
checks load/store lane behavior, iterative multiplier transactions, and CSR
privilege/trap transitions after CIRCT lowering with Verilator.
