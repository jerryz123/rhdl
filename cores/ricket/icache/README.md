<!-- Specifies Ricket's instruction-cache protocol and first-cut L1I policy. -->

# Ricket instruction cache

`protocol.rhdl` defines `RicketInstructionAccess`, an ordered `Irrevocable`
request/response interface carrying byte addresses and returning 32-bit
instructions. The pipeline checks architectural alignment; the cache
translates requests into aligned eight-byte backing-memory beats.

`cache.rhdl` implements a blocking direct-mapped read-only cache with
host-configured power-of-two set and line counts. It is read-allocating, uses
synchronous tag and line memories, clears valid bits on reset, and may have
multiple ordered `SimpleMemory` refill requests outstanding.

The first cut has no associativity, prefetching, invalidation, `FENCE.I`, or
coherence with the data cache. Program loading must finish before the core
starts, and self-modifying code is outside the contract.
