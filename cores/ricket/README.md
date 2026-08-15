<!-- Defines the Ricket RV64I core, its package boundary, pipeline contract, and focused verification. -->

# Ricket

Ricket is the repository's standalone five-stage RV64I processor. Everything
specific to its instruction decode, stage state, architectural register file,
and pipeline policy lives in this directory. It consumes the reusable
[`ALU`](../alu.rhdl) and
[`BranchResolver`](../branch-resolver.rhdl), plus the shared
[`LoadGen` and `StoreGen`](../load-store.rhdl), from the parent `cores/`
package.

## Dependency boundary

```text
ricket.rhdl
  |--> bundles.rhdl
  |--> register-file.rhdl
  |--> decode/core-ctrl.rhdl
  |      |--> decode/{alu,operand,branch,mem,writeback,trap}-ctrl.rhdl
  |      |--> decode/decode-support.rhdl
  |      `--> riscv/isa + riscv/rhdl + rhdl/std/decode
  |--> ../alu.rhdl
  |--> ../branch-resolver.rhdl
  |--> ../load-store.rhdl
  `--> rhdl/std/bits + rhdl/std/flow + rhdl/std/simple-memory
```

Ricket may consume RHDL, the pure RISC-V model, and reusable components from
`cores/`. It must not import another named core, the optional CIRCT backend,
examples, or test implementations.

## Structured decode

The files under [`decode/`](decode/README.md) independently define complete
52-row relations for the operand router, branch unit, load/store unit,
writeback path, trap path, and ALU. Each file owns its types, instruction
groupings, cases, and `ValidDecodeGen`; component decoders do not import one
another. [`decode/core-ctrl.rhdl`](decode/core-ctrl.rhdl) uses ordinary host
iteration over `RV64IInstructions` to assemble those relations as named fields
of one aggregate control pattern, then exposes one integrated `ValidDecodeGen`.
The focused decode test also checks each independent relation directly against
that canonical instruction domain.

There is no intermediate instruction-kind enum. Pipeline registers capture
only the leaf controls consumed downstream. Every relation constrains only the
fields that can affect that instruction: unused fields and unmatched
instructions remain synthesis don't-cares. A separate valid/illegal bit keeps
those values from acquiring architectural meaning.

## Five-stage core

[`ricket.rhdl`](ricket.rhdl) defines `Ricket(address_width)`, a
single-issue, in-order IF/ID/EX/MEM/WB implementation of the 52 base RV64I
instructions. It exposes:

- `start`, an `Irrevocable(Bits(64))` architectural entry-point consumer;
- `imem`, a `SimpleMemory(address_width, 4)` requester;
- `dmem`, a `SimpleMemory(address_width, 8)` requester; and
- `fault`, a sticky fault-stop indication.

The instruction path is an elastic ready-valid topology inside the single
`Ricket` circuit. Fetch, Decode, Execute, Memory, and Writeback are logical
regions of ordinary circuit code, not module boundaries. Three `Pipe(_, 1)`
instances own the stallable IF/ID, ID/EX, and EX/MEM boundaries. One
`ValidPipe(_, 1)` owns the always-advancing MEM/WB boundary without inventing a
readiness signal. Decode and Execute observe live register-file and bypass
sidebands; the elastic pipes establish `Irrevocable` stability when stalled.

Instruction fetch has one epoch-tagged request outstanding. A taken branch or
jump uses `filter_flow` to consume the younger IF/ID token, prevents a
replacement ID/EX token, redirects the PC, and drains any stale response.
Decode's ready-valid gate holds its token during a load-use hazard. The generic
`Pipe` therefore needs no processor-specific flush behavior.
The data-memory stage waits for the ordered response to every load or store.
Scalar accesses use aligned eight-byte requests with shifted data and byte
masks. The shared `StoreGen` produces those write lanes, while `LoadGen`
selects and extends returned data from decoded width and signedness. Ricket
retains aligned request-address generation and all protocol state.

Local combinational signals carry EX/MEM and MEM/WB bypass observations,
writeback, redirect, and fault events; they are deliberately not part of the
owned instruction flow. The hazard logic provides same-cycle register-file
writeback bypass, one load-use bubble, and direct forwarding from a returning
load response. Backpressure holds younger stages behind an incomplete memory
operation. `x0` is hardwired to zero. `FENCE` is a no-op in this strictly
ordered blocking first cut. Illegal instructions, ECALL, EBREAK, misaligned
control targets, and misaligned data accesses set `fault` and stop new fetches.
Interrupts, privilege, CSRs, compressed instructions, caches, and prediction
are outside the current contract.

Execute sends forwarded register operands and decoded orthogonal comparison
controls to the reusable [`BranchResolver`](../branch-resolver.rhdl). Its
`taken` result requests a redirect. Ricket separately owns PC-relative versus
register-relative target selection because that routing is pipeline and ISA
integration policy, not comparison behavior.

The instruction and data ports intentionally remain separate. Ricket is not
connected to `SimpleSoCTop`; a later SoC-level adapter or arbiter will reconcile
the Harvard core boundary with the simulation memory topology.

[`register-file.rhdl`](register-file.rhdl) owns the 32-by-64-bit architectural
register state. [`bundles.rhdl`](bundles.rhdl) owns only stage and sideband
payload types. Decode, Execute, and Memory combinational logic is written where
each logical stage consumes it in [`ricket.rhdl`](ricket.rhdl).
[`ricket.rhdl`](ricket.rhdl) owns all five logical stage regions, their local
state, hazard and squash behavior, sidebands, and the flow topology connecting
the four generic pipeline-register modules. Its implementation is ordered IF,
ID, EX, MEM, then WB. Local `Valid` interface links carry redirect and bypass
results backward without moving their producers out of the stages that own
them. A plain `Bool` wire carries the payloadless execute-fault event.

## Verification

Run the focused host checks from the repository root:

```sh
make ricket-host-test
```

Include the reusable datapath simulations when CIRCT and Verilator are
available:

```sh
make ricket-test
```

For pipeline work that does not require external RTL simulation, run only the
component decode and core elaboration checks:

```sh
env PLTCOLLECTS="$PWD": raco test \
  cores/ricket/tests/core-ctrl-test.rhm \
  cores/ricket/tests/ricket-test.rhm
```
