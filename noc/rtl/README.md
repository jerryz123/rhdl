<!-- Defines the dependency and behavioral contract for NoC-specific RHDL hardware. -->

# NoC RTL

This directory contains the hardware consumers of the pure NoC model. It may
depend on public `#lang rhdl` facilities and reusable RHDL standard-library
primitives, but the pure `noc/model`, `analysis`, `authoring`, `language`,
`plan`, and `std` directories never depend on this package.

`route-computer.rhdl` defines `RouteDecoder`, `route_decoder_lookup`,
`compile_route_decoder`, and `RouteComputer`. `compile_route_decoder` accepts
only a `RouterPlan` projected from opaque `ValidatedRouting`; it cannot consume
an unchecked relation or rerun topology, reachability, dependency, or deadlock
analysis. Route keys retain their global stable encoding, while origin keys
and outgoing-VC masks are local to one router. The decode relation uses a typed
`RouteLookupKey` input and a typed `RouteDecision` output with a unified
`target_mask` plus a Boolean `valid` field. The receiver-explicit
`route_decoder_lookup` function preserves those decoder-dependent exact types
at its boundary. Compilation returns an opaque `RouteDecoder` that stores only
the plan, derived decode widths, and compiled `DecodeGen`; route mappings and
rows remain owned by `RouterPlan`. `DecodeGen` alone owns any flattening needed
by Espresso or CIRCT;
neither the route computer nor router logic concatenates selector fields or
slices a packed decision representation.

`router.rhdl` defines `RoutedBeat`, opaque `SimpleRouterConfig`,
`compile_simple_router`, and `SimpleRouter`. Compilation checks the supported
proof regime, compiles the route decoder, and freezes the hardware port and
target shape. One beat is one complete packet. Each local origin has one
standard depth-one `Queue`; bypass (`flow`) and same-cycle replacement (`pipe`)
remain disabled so the prior registered timing is preserved. Route decisions
form the NoC-specific request matrix. A parallel flow handle connects the
ingress array through those queues, and the endpoint-first `grant_crossbar`
helper connects their outputs directly to egress. The standard-library
`GreedyMatcher` remains an explicit sideband controller: it observes requests
and supplies grants but does not pretend to consume or forward payload flow.
A NoC-specific ingress monitor checks every externally offered route key
against the physical input's origin key before buffering. Outgoing VCs are the
first targets and every local ejection terminal follows. The router contains
no singular ejection convention, so a linkless plan with several terminals is
an ordinary many-input, many-output crossbar instance.

Router runtime collections are RHDL `Vec` values, not host lists of hardware
objects. Route-decision fields and request/grant bits therefore compose through
ordinary field projection and indexing instead of explicit packed extraction.

`wormhole-router.rhdl` defines the sibling `WormholeBeat`,
`WormholeRouterConfig`, `compile_wormhole_router`, and `WormholeRouter`
transport. A head fragment is the only fragment whose route key is decoded.
After the head transfers, the selected output VC or local ejection target is
owned by that input until its tail transfers. Body and tail fragments therefore
cannot be rerouted or interleaved with a different packet on the reserved VC.

`wormhole-link.rhdl` keeps logical VC routing distinct from physical-link
sharing. `WormholeLinkMux` fairly selects at most one logical VC beat per cycle
and adds its link-local VC index; `WormholeLinkDemux` validates that index and
delivers the beat to the corresponding downstream VC. The demultiplexer also
returns a readiness bit for every VC, allowing the multiplexer to select a
ready VC instead of letting one blocked VC stall the entire link. Link
arbitration is per beat and retains no physical-link resource across cycles, so
the only retained network resources remain the VCs represented in the
validated dependency graph. The ready-valid physical link plus per-VC reverse
readiness is the initial same-clock realization; an eventual credited or
pipelined link adapter must preserve the same logical VC acceptance contract.

Protocol packetization remains outside `noc/rtl`. A protocol adapter may map a
wide object such as a CHI flit into any finite head/body/tail sequence and
reassemble it after ejection without changing topology, routing, or VC
analysis. CHI link credits and internal physical-link credits remain separate
protocol layers.

The initial router accepts only whole-graph-acyclic validation. Escape
certificates require persistent escape requests and eventual grants; the
fixed-priority allocator does not yet claim that fairness contract, so router
configuration compilation rejects escape-certified plans.

There is intentionally no whole-network circuit or router-instantiating
network helper in this package. Real routers live in independently owned tile,
switch, or subsystem modules and may be separated by arbitrary hierarchy.
Integration code obtains each node's `RouterPlan` from the pure `NetworkPlan`,
compiles only its selected local router configuration, and exposes the VC or
physical-link ports appropriate to its own boundary. A user-owned parent
connects those boundaries from the corresponding `NetworkPlan` assignments;
`noc/rtl` neither owns the system hierarchy nor inserts a wrapper around the
complete transport.

The focused executable hardware examples live under `examples/noc/`. They
import this domain package directly; only their reusable matching and crossbar
mechanisms come from `rhdl/std`.
