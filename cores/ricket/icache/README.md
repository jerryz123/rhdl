<!-- Specifies Ricket's instruction-cache protocol and first-cut L1I policy. -->

# Ricket instruction cache

`protocol.rhdl` defines `RicketInstructionAccess`, an ordered `Irrevocable`
request/response interface carrying byte addresses and returning 32-bit
instructions. The pipeline checks architectural alignment; the cache
translates requests into aligned eight-byte backing-memory beats.

`cache.rhdl` implements a direct-mapped read-only cache with host-configured
power-of-two set and line counts. Its synchronous tag/data lookup is a
one-cycle pipeline: on consecutive hits it accepts one request and returns one
ordered instruction every cycle. A two-entry response queue preserves results
under fetch backpressure. A discovered miss blocks new lookups until its line
is installed; the refill may have multiple ordered `SimpleMemory` requests
outstanding. Reset clears the lookup pipeline and valid bits.

The first cut has no associativity, prefetching, invalidation, `FENCE.I`, or
coherence with the data cache. Program loading must finish before the core
starts, and self-modifying code is outside the contract.
