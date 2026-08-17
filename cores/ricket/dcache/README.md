<!-- Specifies Ricket's data-cache protocol and first-cut L1D policy. -->

# Ricket data cache

`protocol.rhdl` defines `RicketDataAccess`, an ordered `Irrevocable`
request/response interface carrying the original byte address, read/write
intent, scalar width, load signedness, and XLEN-wide store source. It returns an
XLEN-wide normalized load value and echoes the request's five-bit completion tag;
store response data and tag have no meaning. The pipeline uses the tag to clear
the destination scoreboard entry when a delayed load returns. It checks
architectural alignment, while the cache owns beat alignment, masks, and
load/store lane generation. `RicketL1DCache(xlen, address_width, ...)` accepts
`XLen.X32` or `XLen.X64` while retaining eight-byte line beats and
an eight-byte `SimpleMemory` backing port.

`cache.rhdl` implements a direct-mapped, read-allocating,
write-through/write-no-allocate cache. Its synchronous lookup accepts and
returns tagged consecutive load hits every cycle through a two-entry response
queue. A miss blocks new cache requests until refill completes. A store
completes to the core during its lookup,
updates a resident line on a hit, and enters a one-entry ordered write buffer;
the buffer drains to backing `SimpleMemory` before the cache accepts another
memory operation. This preserves ordering without holding unrelated pipeline
instructions behind backing-store latency. Reset clears lookup, refill,
write-buffer, and valid state.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, or coherence with the instruction cache.
