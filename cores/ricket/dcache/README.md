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
`XLen.X64`; its core-facing and backing-memory addresses use the selected XLEN
while retaining eight-byte line beats and an eight-byte `SimpleMemory` backing
port.

`cache.rhdl` implements a direct-mapped, read-allocating,
write-through/write-no-allocate cache. A one-stage `Pipe` carries lookup
context alongside the synchronous SRAM access and advances on consecutive
hits. A miss passes through typed `filter_flow` and `map_flow` stages into the
Ricket-local `../refill.rhdl` transaction engine. The engine owns the aligned
line address, complete client context, request and response counters, and line
accumulator, then returns the context with one completed line over an
irrevocable flow. The cache retains backing-port arbitration and installs that
result into its tag and data arrays. A mandatory non-backpressurable
`ValidPipe` after the SRAM lookup preserves one-hit-per-cycle throughput while
aligning an EX request's hit response with WB. A miss blocks
new cache requests until refill completes. A store produces its registered
completion during lookup, updates a resident line on a hit, and enters a
one-entry ordered write buffer;
the buffer drains to backing `SimpleMemory` before the cache accepts another
memory operation. This preserves ordering without holding unrelated pipeline
instructions behind backing-store latency. Reset clears lookup, refill,
write-buffer, and valid state.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, or coherence with the instruction cache.
