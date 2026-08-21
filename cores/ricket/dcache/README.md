<!-- Specifies Ricket's data-cache protocol and first-cut L1D policy. -->

# Ricket data cache

`protocol.rhdl` defines `RicketDataAccess`, an ordered `Decoupled` request and
`Valid` response interface carrying the original byte address, read/write
intent, scalar width, load signedness, and XLEN-wide store source. The request
is deliberately Decoupled because live Execute forwarding may change its
payload before the cache accepts the instruction. The response returns an
XLEN-wide normalized load value and echoes the request's five-bit completion
tag; store response data and tag have no meaning. The pipeline uses the tag to
clear the destination scoreboard entry when a delayed load returns. It checks
architectural alignment, while the cache owns beat alignment, masks, and
load/store lane generation. `RicketL1DCache(xlen, ...)` accepts `XLen.X32` or
`XLen.X64`; its core-facing addresses use the selected XLEN while its native
RN-F port uses the configured CHI address width. Ricket cache lines are always
64 bytes. The default 128-bit DAT width is CHI's minimum, so each refill is
assembled from four physical DAT packets.
The responder also exposes a combinational `drained` observation. It is true
only when no request is accepted that cycle and no lookup, refill, or coherent
write-through transaction remains active, giving architectural fences a
precise quiescence boundary without creating a separate fence transaction.

`cache.rhdl` implements a direct-mapped, read-allocating,
write-through/write-no-allocate cache. A one-stage `Pipe` carries lookup
context alongside the synchronous SRAM access and advances on consecutive
hits. A miss passes through typed `filter_flow` and `map_flow` stages into the
Ricket-local `../refill.rhdl` transaction engine. The engine owns the aligned
line address, complete client context, retryable `ReadClean`, `CompData`, and
`CompAck`, then returns the context with one completed clean line and its CHI
state over an irrevocable flow. The cache installs that result into its tag,
state, and data arrays. A mandatory non-backpressurable
`ValidPipe` after the SRAM lookup preserves one-hit-per-cycle throughput while
aligning an EX request's hit response with WB. A miss blocks
new cache requests until refill completes. A store produces its registered
completion during lookup and transfers a typed command into the one-entry
`../write-unique.rhdl` engine. That engine owns retry, DBID, data, and completion
state for `WriteUniquePtl`, accepts separate responses in either order or
`CompDBIDResp`, and sends address-labeled `NonCopyBackWriteData`; the cache
invalidates the local line instead of making it dirty.

Incoming snoops serialize behind any lookup, refill, or store. The shared
`../snoop.rhdl` engine owns request lifetime, DVM pairing, lookup-result capture,
and response stability. The cache owns the tag/state lookup and applies the
engine's typed invalidate-or-downgrade update. Sharing snoops downgrade Unique
to SharedClean, invalidating snoops discard the match, and state-preserving
snoops retain it.
Forwarding snoops silently evict a clean match and report Invalid so Home can
source the line elsewhere without a snoop-data path. `SnpQuery` reports the
stored state without changing it. Any non-forward snoop with `RetToSrc` also
silently evicts before returning Invalid because this first cut has no
snoop-data path. Each two-packet `SnpDVMOp` receives one response. Reset clears
lookup, refill, write transaction, snoop, and valid state.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, snoop data return, or direct coherence connection
to the instruction cache.
