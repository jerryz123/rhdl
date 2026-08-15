<!-- Specifies Ricket's data-cache protocol and first-cut L1D policy. -->

# Ricket data cache

`protocol.rhdl` defines `RicketDataAccess`, an ordered `Irrevocable`
request/response interface carrying the original byte address, read/write
intent, scalar width, load signedness, and 64-bit store source. It returns a
normalized 64-bit load value; store response data has no meaning. The pipeline
checks architectural alignment, while the cache owns beat alignment, masks,
and load/store lane generation.

`cache.rhdl` implements a blocking direct-mapped, read-allocating,
write-through/write-no-allocate cache. A store hit updates the resident line,
every store reaches backing `SimpleMemory`, and the core receives its store
response only after the backing response. Tags and lines use synchronous
memories, reset clears valid bits, and a refill may have multiple ordered
requests outstanding.

The first cut has no associativity, dirty state, eviction writeback,
hit-under-miss, prefetching, or coherence with the instruction cache.
