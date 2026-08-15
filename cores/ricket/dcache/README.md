<!-- Specifies Ricket's data-cache protocol and first-cut L1D policy. -->

# Ricket data cache

`protocol.rhdl` defines `RicketDataAccess`, an ordered `Irrevocable`
request/response interface carrying the original byte address, read/write
intent, scalar width, load signedness, and 64-bit store source. It returns a
normalized 64-bit load value; store response data has no meaning. The pipeline
checks architectural alignment, while the cache owns beat alignment, masks,
and load/store lane generation.

`cache.rhdl` implements a direct-mapped, read-allocating,
write-through/write-no-allocate cache. Its synchronous lookup accepts and
returns consecutive load hits every cycle. A miss blocks new cache requests
until refill completes. A store completes to the core during its lookup,
updates a resident line on a hit, and enters a one-entry ordered write buffer;
the buffer drains to backing `SimpleMemory` before the cache accepts another
memory operation. This preserves ordering without holding unrelated pipeline
instructions behind backing-store latency. Reset clears lookup, refill,
write-buffer, and valid state.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, or coherence with the instruction cache.
