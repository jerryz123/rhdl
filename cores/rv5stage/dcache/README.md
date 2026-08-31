<!-- Specifies RV5Stage's data-cache protocol and blocking write-back L1D policy. -->

# RV5Stage data cache

`protocol.rhdl` defines `RV5StageDataAccess`, an ordered `Decoupled` request and
`Valid` response interface carrying the original byte address, a typed load,
store, LR, SC, or AMO operation, scalar width, load signedness, and XLEN-wide
source operand. The request
is deliberately Decoupled because live Execute forwarding may change its
payload before the cache accepts the instruction. The response returns an
XLEN-wide normalized load or atomic result and echoes the request's five-bit
completion tag; ordinary store response data and tag have no meaning. The
pipeline uses the tag to clear the destination scoreboard entry when a delayed
load or atomic operation returns. It checks
architectural alignment, while the cache owns beat alignment, masks, and
load/store lane generation. `RV5StageL1DCache(xlen, ..., ~chi: ...)` accepts
`XLen.X32` or `XLen.X64`; the required CHI parameter comes from system
integration and supplies the RN-F identity, flit geometry, and Home map. Its
core-facing addresses use the selected XLEN while its native RN-F port uses the
configured CHI address width. RV5Stage cache lines are always
64 bytes. The default 128-bit DAT width is CHI's minimum, so each refill is
assembled from four physical DAT packets.
The responder also exposes a combinational `drained` observation. It is true
only when no request is accepted that cycle and no lookup, acquisition, or
dirty-line writeback remains active, giving architectural fences a
precise quiescence boundary without creating a separate fence transaction.

`cache.rhdl` implements a direct-mapped, blocking write-back/write-allocate
cache. A one-stage `Pipe` carries lookup
context alongside the synchronous SRAM access and advances on consecutive
hits. Load misses request `ReadClean`; store misses and stores to SharedClean
lines request `ReadUnique`. AMOs and successful SCs use the same unique-owner
path, then update the cached word or doubleword and leave the line UniqueDirty.
AMOs return the pre-update value; RV64 word results are sign extended. The
common `../refill.rhdl` engine owns the aligned
line address, complete client context, retry, `CompData`, and `CompAck`. A
completed store acquisition merges the store bytes into the returned line and
installs it as UniqueDirty. Stores that hit UniqueClean or UniqueDirty update
the data SRAM and dirty state locally without producing REQ or DAT traffic.
A mandatory non-backpressurable
`ValidPipe` after the SRAM lookup preserves one-hit-per-cycle throughput while
aligning an EX request's hit response with WB. An acquisition or miss blocks
new cache requests until it completes. Before replacing a dirty direct-mapped
victim, `../writeback.rhdl` captures the entire line and drains its eight
64-bit beats through the currently supported retryable `WriteUniquePtl`
transaction engine; only then can the replacement refill begin.

Incoming snoops serialize behind any lookup, refill, or store. The shared
`../snoop.rhdl` engine owns request lifetime, DVM pairing, lookup-result capture,
and response stability. Clean lines use `SnpResp` and the requested
invalidate-or-downgrade transition. Dirty lines return all line packets as
`SnpRespData` with `PassDirty`, then invalidate locally so Home receives the
authoritative copy. Each two-packet `SnpDVMOp` receives one response. Reset
clears lookup, acquisition, writeback, snoop, valid, and reservation state.

LR records one exact address and scalar width in a cache-local reservation.
SC succeeds only when that reservation still matches, acquiring Unique
ownership before updating the line, and every SC attempt clears the
reservation. Same-line local writes, invalidating snoops, and replacement of
the reserved line also clear it. A failed SC returns one without issuing CHI
traffic; a successful SC returns zero.

The cache has no associativity, hit-under-miss, prefetching, background
writeback, or direct coherence connection to the instruction cache. Dirty
replacement currently decomposes a line into supported partial writes rather
than using CHI's `WriteBackFull` transaction family.
