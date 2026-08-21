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
load/store lane generation. Its CHI boundary is a ready-valid
`CHIRNDecoupled` endpoint; the enclosing system owns physical link credits and
activation. `RicketL1DCache(xlen, ...)` accepts `XLen.X32` or `XLen.X64`; its
core-facing addresses use the selected XLEN while its RN-F endpoint uses the
configured CHI address width. Its 128-bit DAT width is CHI's
minimum, so a 32-byte cache line is assembled from two physical DAT packets.
The responder also exposes a combinational `drained` observation. It is true
only when no request is accepted that cycle and no lookup, refill, or coherent
write-through transaction remains active, giving architectural fences a
precise quiescence boundary without creating a separate fence transaction.

`cache.rhdl` implements a direct-mapped, read-allocating,
write-through/write-no-allocate cache. A one-stage `Pipe` carries lookup
context alongside the synchronous SRAM access and advances on consecutive
hits. A miss passes through typed `filter_flow` and `map_flow` stages into the
Ricket-local `../refill.rhdl` transaction engine. The engine owns the aligned
line address, complete client context, `ReadShared`, `CompData`, and `CompAck`,
then returns the context with one completed line over an irrevocable flow. The
cache installs that result into its tag and data arrays. A mandatory non-backpressurable
`ValidPipe` after the SRAM lookup preserves one-hit-per-cycle throughput while
aligning an EX request's hit response with WB. A miss blocks
new cache requests until refill completes. A store produces its registered
completion during lookup and enters a one-entry coherent write-through
transaction. It issues `WriteUniquePtl`, consumes `DBIDResp`, sends
`NonCopyBackWriteData`, and waits for `Comp`; the local line is invalidated
instead of becoming dirty. Incoming snoops serialize behind any lookup, refill,
or store, conservatively invalidate all clean lines, and return Invalid
`SnpResp`. Reset clears lookup, refill, write transaction, and valid state.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, snoop data return, or direct coherence connection
to the instruction cache.
