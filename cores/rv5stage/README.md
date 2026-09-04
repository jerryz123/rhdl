<!-- Defines the width-parameterized RV5Stage core, cache boundary, pipeline contract, and verification. -->

# RV5Stage

RV5Stage is the repository's single-issue, in-order five-stage RV32I/RV64I
processor with A, B, M, Zicond, Zicsr, Zicntr, Zifencei, and an initial M/S/U privileged control plane. The required `xlen :: XLen` host parameter selects `XLen.X32` or
`XLen.X64`; the same pipeline and cache implementation is specialized during
elaboration without admitting arbitrary integer widths.
Core-specific decode, architectural state, pipeline policy, and private L1
caches live here. Reusable execution components remain directly under
[`cores/`](../).

## Dependency boundary

```text
rv5stage.rhdl                       core, MMU, and private-cache composition
  |--> core.rhdl                    IF/ID/EX/MEM/WB pipeline
  |     |--> bundles + integer decode + memory + register-file + csr
  |     |     `--> ../../riscv/rtl/counters.rhdl
  |     |--> ../{alu,branch-resolver,load-store,multiplier,divider}.rhdl
  |     |--> icache/protocol.rhdl
  |     |--> dcache/protocol.rhdl
  |     `--> ../../rhodium/std/scoreboard.rhdl
  |--> mmu/{mmu,tlb,walker}.rhdl    Sv39 translation before physical L1s
  |     `--> ../../riscv/rtl/pma.rhdl
  |--> memory-router.rhdl            physical permission and device split
  |--> uncached.rhdl                 one-outstanding RN-I device transaction
  |--> cache.rhdl                   fixed 64-byte private-L1 line geometry
  |--> chi.rhdl                     RN-F parameters and flit construction
  |--> refill.rhdl                  blocking ReadClean/ReadUnique acquisition
  |--> write-unique.rhdl            retryable partial-write transaction engine
  |--> ../../chi/retryable-transaction.rhdl
                                     shared retry and response-profile control
  |--> writeback.rhdl               serialized dirty-line drain engine
  |--> snoop.rhdl                   clean/dirty snoop-data and DVM engines
  |--> icache/cache.rhdl             instruction arrays, policy, and CHI routing
  `--> dcache/cache.rhdl             data arrays, policy, and CHI routing
```

`RV5StageCore` speaks only RV5Stage's semantic instruction and data access
protocols. Cache modules own line lookup, array arbitration, transaction
scheduling, CHI channel routing, byte masks, and load/store lane generation.
The shared transaction engines own protocol sequencing, response stability,
and DVM pairing. Refill and WriteUnique share CHI's profile-driven retry
controller while retaining their transaction-specific payload and completion
state. The wrapper composes the core, MMU, and caches into
two ready-valid RN-F channel bundles; physical credited links belong to system
integration when the channels actually cross a CHI link boundary.
`RV5StageCHIConfig` supplies the structural flit shape and one list of physical
regions paired with their CHI Homes. It derives both the transport-independent
RISC-V physical-memory map and the `CHIHomeMap`, so permissions, cacheability,
and CHI routing cannot describe different address ranges. Each cache
transaction decodes its address once and retains the selected HN-F NodeID
through retries, data, and completion acknowledgement.
`RV5StageCHIParams` is host-only placement metadata for the instruction and data
RN-F NodeIDs plus the optional device RN-I NodeID, while `RV5StageCHIIdentity`
carries those IDs into an occurrence as hardware inputs. Consequently one
RV5Stage specialization can be stamped at multiple placements without inheriting
a representative tile's NodeIDs.

RV5Stage may consume Rhodium, the pure RISC-V model, and reusable components from
`cores/`. It must not import another named core, a backend, examples, or test
implementations. See [`icache/README.md`](icache/README.md) and
[`dcache/README.md`](dcache/README.md) for their separate protocol and cache
contracts.

## Core

[`core.rhdl`](core.rhdl) is a direct RTL description. It uses ordinary
registers for fetch state, one explicit priority update chain, direct
ready-valid equations, and a shared forwarding mux policy. It retains only the
pipeline storage primitives and the real deferred-completion arbiter instead
of mechanically recreating flow transformations with helper instances.

[`rv5stage.rhdl`](rv5stage.rhdl) instantiates this implementation in the
integrated MMU and cache hierarchy.

The standalone floating-point hierarchy is not yet instantiated by
`RV5StageCore`. [`fp-register-file.rhdl`](fp-register-file.rhdl) defines a
32-entry, three-read, two-write bank whose 32- or 64-bit FLEN follows the
selected F or D host profile. Unlike the integer bank, `f0` is an ordinary
writable register, and the bank has no architectural reset value.
[`decode/fp-ctrl.rhdl`](decode/fp-ctrl.rhdl) selects RV32F, RV64F, RV32FD, or
RV64FD at elaboration and emits one sparse decode table of register-bank and
direct execution-unit controls. The `None` profile emits no decode table.

[`fp-pipeline.rhdl`](fp-pipeline.rhdl) is the core-specific parallel execution
submodule for enabled profiles. It owns the FP register bank, FP RAW/WAW
scoreboarding, operand reads, two-cycle fixed execution path, buffered
iterative divide/square-root paths, and completion arbitration. Its decoded
ready-valid issue contract is non-speculative: every accepted request must
eventually complete. Completions may emerge out of issue order and return an
opaque caller context, integer or FP result metadata, and RISC-V exception
flags. The submodule writes FP destinations internally only when its completion
is accepted. Separate load-reservation/load-completion and store-data flows let
the eventual central LSU retain address generation, translation, faults, and
cache ordering. CSR state, architectural retirement, and integer scoreboarding
remain outside this submodule. [`fp-bundles.rhdl`](fp-bundles.rhdl) owns these
boundary payloads; [`fp-datapath.rhdl`](fp-datapath.rhdl) and
[`fp-div-sqrt.rhdl`](fp-div-sqrt.rhdl) own the internal execution lanes.

## Pipeline

The core keeps Fetch, Decode, Execute, Memory, and Writeback as logical regions
of one circuit. Individual stages are not module boundaries.
`Pipe(_, 1)` instances make IF/ID and ID/EX elastic, so instructions wait before
Execute until required operands and cache request capacity are available.
`ValidPipe(_, 1)` instances make EX/MEM and MEM/WB feed-forward: once an
instruction leaves Execute, no later stage can stall it.

Fetch keeps accepted PCs in a two-entry flushable metadata queue. The pipelined
L1I can therefore accept and return one hit per cycle. Redirects synchronously
flush the PC queue, lookup result, and buffered responses; a wrong-path refill
may finish internally but cannot return an instruction to Fetch.
The core exposes `started` and `fetch_pc` directly. Redirect, initial start, and
completed request update `fetch_pc` in that priority order, while paired valid
equations make the L1I request and PC correlation queue advance together.
Decode holds a token behind deferred loads, multiplies, or divides in ID/EX and EX/MEM
until they reach WB.
Execute owns forwarding, branch resolution, target and access alignment
checks, and synchronous-exception classification. One readiness equation
combines cache capacity and arithmetic-unit reservations; branch resolution and
EX/MEM observe the resulting transfer together. A legal request transfers at
the same edge that places its instruction in EX/MEM. The L1D
registers its SRAM lookup result so a hit arrives with the
instruction in WB. WB is the ordered commit point: a load whose result has not
returned or long-latency arithmetic that starts there sets its destination in the standard
`Scoreboard` and releases the pipeline before its result returns.
ID/EX carries register indices rather than captured register data. Execute
reads the register file live, so an instruction held behind cache or arithmetic
capacity observes an older write even after that write's forwarding window has
passed.
Multiplication and division are reserved in Execute but issued only when the
instruction reaches WB, so redirects and older faults never need to kill
either arithmetic unit's state.
Decode stalls on
scoreboard RAW and WAW
hazards, while independent younger instructions may complete first. A returning
load, multiply, or divide clears its destination and writes through one element of the register
file's `Valid(RegisterFileWrite(xlen))` write array. Valid-flow filtering,
mapping, and fanout connect both update streams to the scoreboard without
making its continuously observable busy bitmap into a transaction stream. A
fixed-priority completion arbiter gives loads priority because they cannot be
backpressured; multiplier and divider responses remain stable until selected.
The
other array element independently accepts the ordinary MEM/WB result through
the same valid-only payload contract, so a load completion never backpressures
either feed-forward stage. A WB-aligned hit sets and clears the entry without
an extra busy cycle.
Scoreboard WAW gating prevents both write ports from validly targeting the same
register. Stores commit in WB; their address and alignment checks still occur
before cache acceptance.

This is in-order commit with out-of-order register completion, not out-of-order
instruction issue. D-cache responses remain ordered, and a blocking miss still
prevents younger memory requests from entering the cache; only independent
non-memory work passes the outstanding load.

The integrated structured decoder selects the RV32IMAB+Zicond+Zicsr+Zifencei or RV64IMAB+Zicond+Zicsr+Zifencei catalog at host
elaboration and emits the component control bundles directly, without an
intermediate instruction-kind enum or parallel hardware decoders. Unused
controls stay synthesis don't-cares while a separate valid bit determines
whether decoded values have architectural meaning.

Standard B and Zicond instructions are ordinary operations in the shared combinational
[`../alu.rhdl`](../alu.rhdl). Base and B rows live in one ALU-control module and
directly select the same physical adder, logic, shifter, compare, count, rotate,
and unary resources. Zba, Zbb, Zbs, and Zicond therefore add no second decoder,
execution unit, pipeline state, reservation, or scoreboard behavior. Zicond
reuses the logic operand-preparation path to create an all-zero or all-one mask
from `rs2`; it has no single-letter `misa` bit. `misa.B` is reported for both XLENs.

[`memory.rhdl`](memory.rhdl) owns the semantic load, store, LR, SC, and AMO
operations plus the word/doubleword atomic ALU. A operations return through the
same deferred memory-writeback path as loads. The ordered blocking L1D gives
all memory accesses stronger ordering than the architectural `aq` and `rl`
annotations require, so those instruction bits do not add a second fence or
transaction mechanism.

[`csr.rhdl`](csr.rhdl) owns the named user, machine, and supervisor CSRs, current
privilege mode, trap entry, interrupt selection, and `MRET`/`SRET`. Its F/D
specializations add the aliased `fflags`, `frm`, and `fcsr` views, profile-derived
`misa` bits, `mstatus.FS` legality and dirty tracking, and the derived `SD` bit.
Accepted FP state updates accrue exception flags; the eventual core integration
must serialize explicit FP CSR accesses against the standalone FP pipeline.
CSR instructions
atomically return the old value and update state at WB. System instructions
serialize in Decode and wait for older deferred loads, multiplies, or divides before
entering the pipeline, so younger instructions cannot create side effects
before the system operation commits. Execute-detected exceptions immediately
squash younger work but carry the faulting instruction to WB, where the CSR
file records EPC, cause, and trap value and selects the direct `mtvec` or
`stvec` target.

[`interrupt.rhdl`](interrupt.rhdl) defines six controller-independent standard
pending inputs for supervisor and machine software, timer, and external
interrupts. The CSR file merges those levels with writable supervisor pending
bits, exposes the resulting `mip`/`sip` views, applies `mie`/`sie`, global
`mstatus` enables, and `mideleg`, and selects the architectural fixed priority.
An eligible interrupt stops Fetch and Decode while accepted instructions and
deferred completions drain. It is then taken after the last retired instruction,
with EPC set to that instruction's architectural successor; every younger
pipeline token and same-cycle memory effect is discarded. `WFI` is a serialized
legal no-op for now, so it completes without idling the clock.
PMP, Zihpm performance counters, vectored trap mode, and platform interrupt controllers remain
outside this slice.

The CSR file reads the platform-supplied `hart_id` through `mhartid` and the
64-bit `time_counter` through the standard `time` CSR, exposing `timeh` for
RV32. Reusable 64-bit `mcycle` and `minstret` state supplies the remaining
Zicntr views, including RV32 high halves. `mcycle` advances each active core
clock and `minstret` advances only for an instruction that reaches ordered WB
without a synchronous exception; an explicit machine-counter write suppresses
that instruction's implicit update. User and supervisor counter access obeys
the corresponding `mcounteren` and `scounteren` bits. RV5Stage does not create
a second internal timer. `mcountinhibit`, Zihpm, and privilege-mode counter
filtering remain outside this slice.

RV64 RV5Stage implements Bare and Sv39 address translation ahead of its
physically indexed, physically tagged L1 caches. `satp.MODE` accepts Bare or
Sv39, `satp.ASID` is WARL zero, and RV32 remains permanently Bare. Separate
eight-entry fully associative ITLB and DTLB instances retain raw PTE
permissions and recheck current privilege, `SUM`, and `MXR` on every hit. One
serialized, non-speculative walker handles a miss at a time and reads PTEs
through the physical L1D path only after older cache work has drained. It
supports 4 KiB, 2 MiB, and 1 GiB leaves, rejects malformed or misaligned
superpages, and implements Svade by raising a page fault when an accessed or
required dirty bit is clear rather than modifying page tables in hardware.
Instruction, load, and store page faults carry the original virtual address
through the ordinary precise WB trap path. M-mode instruction accesses remain
Bare; data accesses honor `MPRV`, while `SUM` and `MXR` affect permission
checks. Physical fetches are also checked for a mapped, executable, cacheable region, data
accesses are checked for the required read, write, and atomic attributes, and
PTE-read rejection becomes an access fault on the original access. These
locally rejected requests never enter CHI. `SFENCE.VMA` is a serializing operation and currently performs a full
ITLB/DTLB flush regardless of its operands. A `satp` write conservatively does
the same. Sv48/Sv57, nonzero ASIDs, hardware A/D updates, PBMT, NAPOT, PMP,
multi-hart shootdown, and speculative walks remain outside this slice.

Base `FENCE`, `FENCE.I`, and `SFENCE.VMA` share the same serialization boundary. Decode waits
for older deferred register completions and for the L1D to report that its
lookup, ownership acquisition, and dirty writeback are drained, then
prevents younger instructions from entering Execute until the fence reaches
WB. `FENCE.I`
additionally invalidates every L1I line at WB and redirects Fetch to the
fence's own `pc + 4`. The architectural invalidate is distinct from a
speculative fetch flush: an ordinary redirect discards wrong-path work without
destroying useful cache residency. An L1I refill already in flight is allowed
to drain after invalidation, but cannot install its line or return an
instruction.

RV5Stage stores general CSR data in one aggregate state register and keeps the
profile-selected FP aliases and `FS` state in a small CSR-owned child. The
RISC-V/Rhodium `csr_bank` declaration is the single source for recognized IDs,
read values, direct storage, aliases, WARL masks, and write dispatch. Trap and
return updates remain an explicit prioritized transition because they
atomically affect privilege state and several CSRs instead of representing an
ordinary addressed write.

## Logical diagram

[`examples/rv5stage/core-diagram.rhdl`](../../examples/rv5stage/core-diagram.rhdl)
elaborates the RV64 `RV5StageCore` and extracts its module boundary, child
blocks, registers, and typed interface channels. Generate the focused JSON and
Graphviz DOT files with:

```sh
mkdir -p /tmp/rv5stage-core-diagram
env PLTCOMPILEDROOTS="$(mktemp -d)" \
  racket -y -S "$PWD" tools/write-rv5stage-core-diagram.rhm \
  /tmp/rv5stage-core-diagram
```

The JSON is intended for interactive renderers. The DOT file is a compact
diagnostic view of the core module; child modules remain linked by name instead
of being flattened into the same graph.

## Top-level core

[`rv5stage.rhdl`](rv5stage.rhdl) defines
`RV5Stage(xlen, ~icache: ..., ~dcache: ..., ~chi: ...)`. `xlen` is an
`XLen` enum value. Architectural addresses and cache tags use
`xlen.width` internally. Both private L1 caches use the architectural
64-byte line size from [`cache.rhdl`](cache.rhdl), while each data SRAM row and
core lookup is exactly `xlen.width` bits per way. The shared cache configuration
records set and way geometry. Independent `~icache:` and `~dcache:` parameters
default to `RV5StageCacheConfig(64, 1)` and may select different set and way
counts. Line size is not a top-level generator option. The required
`~chi:` parameter is integration
policy: the containing SoC supplies RV5Stage's RN-F NodeIDs, physical flit
parameters, and physical regions paired with Homes. RV5Stage has no implicit
standalone fabric. The core rejects requests whose high address bits do not fit
the configured physical width before the narrower CHI boundary.
The core exposes an `Irrevocable(Bits(xlen.width))` start consumer, a
packed `RV5StageInterrupts` input independent of any ACLINT, PLIC, or AIA block,
a platform `hart_id`, a 64-bit platform `time_counter`, separate instruction
and data RN-F channel ports, a device RN-I channel port, and a sticky `fault`
output for a rejected misaligned external start address. Physical addresses in configured device
sets bypass L1D through a one-outstanding uncached engine; cacheable addresses
retain the coherent L1D path. Unmapped requests and accesses denied by their
region attributes raise instruction, load, or store access faults. Device LR,
SC, and AMO requests likewise fault instead of being weakened into ordinary MMIO. Architectural
instruction exceptions enter the CSR trap machinery. L1I hits have one-cycle latency and
one-request-per-cycle throughput. In both caches, a one-stage lookup flow
carries request context beside the SRAM access; a miss is filtered and mapped
into the shared refill engine, which returns that context with the completed
line. L1I maps hits and live refill completions into response flows and merges
them before its response queue. L1D load hits have the same throughput and pass through a mandatory
non-backpressurable post-SRAM register while preserving a five-bit pipeline
completion tag. Stores acquire ownership on a miss or shared hit, then update
Unique lines locally as dirty until replacement or snoop intervention. The two
external ports intentionally remain separate RN-F Request Nodes. Home Node,
fabric, and SoC integration remain outside the core. RV5Stage uses CHI's minimum
128-bit DAT width; each fixed 64-byte cache-line refill therefore completes
from four ordinary, unelided DAT packets before the cache returns `CompAck`.
The retained refill line is installed through the XLEN-wide SRAM port over
eight RV64 cycles or sixteen RV32 cycles; the tag becomes valid only with the
final word. Dirty L1D replacement and snoop intervention gather the same words
before passing a complete line to the existing CHI transaction engines. Both
L1s continue accepting snoops while a refill or writeback transaction is
queued. A snoop already waiting takes priority before refill installation
starts; an active line transfer retains the SRAM port until it completes.

## Verification

Run the focused host checks from the repository root:

```sh
make rv5stage-host-test
```

For only the changed core/cache hierarchy:

```sh
tools/run-racket-tests.sh \
  cores/rv5stage/tests/refill-test.rhm \
  cores/rv5stage/tests/icache-test.rhm \
  cores/rv5stage/tests/dcache-test.rhm \
  cores/rv5stage/tests/rv5stage-test.rhm
```

`make rv5stage-test` additionally runs RV32I and RV64I decode, ALU,
bit-manipulation and conditional-zero, pipeline, cache, and load/store CIRCT fixtures plus the
applicable Verilator fixtures. The SimpleSoC simulator also passes all 40
upstream RV64 Zba, Zbb, and Zbs physical architectural tests.
