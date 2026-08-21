<!-- Specifies Ricket's instruction-cache protocol and first-cut L1I policy. -->

# Ricket instruction cache

`protocol.rhdl` defines `RicketInstructionAccess`, an ordered `Irrevocable`
request/response interface carrying XLEN-wide byte addresses, returning 32-bit
instructions, and accepting distinct speculative-flush and architectural
invalidate-all controls from Fetch. The
pipeline checks architectural alignment; the cache translates a miss into one
line-sized RN-F `ReadShared` transaction. Its CHI boundary is a ready-valid
`CHIRNDecoupled` endpoint; the enclosing system owns physical link credits and
activation.

`cache.rhdl` implements a direct-mapped read-only cache with host-configured
power-of-two set and line counts. A one-stage `Pipe` carries each address beside
the synchronous tag/data lookup, so consecutive hits accept and return one
ordered instruction every cycle. A hit maps directly into a response flow; a
miss is filtered and mapped into the shared `../refill.rhdl` transaction engine.
The engine owns the address context, REQ transaction, returned `CompData`, and
`CompAck`, then returns the address with the completed line. Hit and
live-refill responses merge before a two-entry queue that preserves results
under fetch backpressure. A flush clears buffered hits and kills the active
lookup. A wrong-path refill still drains and installs its line but its completion
is filtered from the core response flow. An architectural invalidation also
clears all valid bits. If it intersects an active refill, that transaction
drains but cannot install or return its pre-invalidation line. Reset clears the
lookup pipeline and valid bits.

The cache stores only clean lines. An incoming ordinary snoop waits for any
lookup or refill to finish, conservatively invalidates the cache, and returns
`SnpResp` with Invalid state. It does not return or forward data. The first cut
still has no associativity, prefetching, or selective core-initiated
invalidation. Ricket implements `FENCE.I` by waiting for L1D quiescence and
then issuing the local invalidate-all operation; coherent agents may
independently invalidate the cache through snoops.
