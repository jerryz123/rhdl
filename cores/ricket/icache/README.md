<!-- Specifies Ricket's instruction-cache protocol and first-cut L1I policy. -->

# Ricket instruction cache

`protocol.rhdl` defines `RicketInstructionAccess`, an ordered `Irrevocable`
request/response interface carrying XLEN-wide byte addresses, returning 32-bit
instructions, and accepting an explicit speculative flush from Fetch. The
pipeline checks architectural alignment; the cache translates requests into
aligned eight-byte backing-memory beats without truncating the address.

`cache.rhdl` implements a direct-mapped read-only cache with host-configured
power-of-two set and line counts. A one-stage `Pipe` carries each address beside
the synchronous tag/data lookup, so consecutive hits accept and return one
ordered instruction every cycle. A hit maps directly into a response flow; a
miss is filtered and mapped into the shared `../refill.rhdl` transaction engine.
The engine owns the address context, ordered backing requests, response count,
and line accumulator, then returns the address with the completed line. Hit and
live-refill responses merge before a two-entry queue that preserves results
under fetch backpressure. A flush clears buffered hits and kills the active
lookup. A wrong-path refill still drains and installs its line but its completion
is filtered from the core response flow. Reset clears the lookup pipeline and
valid bits.

The first cut has no associativity, prefetching, invalidation, `FENCE.I`, or
coherence with the data cache. Program loading must finish before the core
starts, and self-modifying code is outside the contract.
