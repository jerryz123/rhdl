<!-- Describes Rhodium's read-only logical block and flow visualization package. -->

# Logical circuit diagrams

`rhodium/diagram` builds a tool-neutral logical view from a verified
`DesignElaboration`. It is an inspection package, not another hardware IR:
changing or discarding a diagram cannot change verification, CIRCT lowering,
or generated RTL.

The first slice represents:

- each circuit boundary, ordinary child instance, and register as a block;
- directional interfaces as one compound port instead of separate data and
  handshake wires;
- configured flow operations as named transformation blocks;
- structural behavior as an orthogonal `boundary`, `combinational`, or
  `sequential` block classification;
- ready-valid connections as one typed channel with explicit backpressure;
- ordinary combinational dependencies as separately classified data channels;
- hierarchy as a set of module diagrams linked by child-module names.

Inline combinational hardware that has no declared block boundary remains
inside a channel. This keeps the default view architectural instead of turning
every primitive operation into a node.
Local `interface_link` handles are likewise transparent: extraction follows
whole-interface connections across them and emits one protocol channel between
the surrounding rendered terminals instead of introducing a wiring block.

## API

```rhombus
import lib("rhodium/diagram/main.rhm") open

def view = diagram(logical_design)
def top = view.module(logical_design.top.name)
def json = diagram_module_to_json(top)
def dot = diagram_module_to_dot(top)
```

`diagram` verifies the source design before extraction. JSON is the stable
machine-readable interchange. DOT is a deliberately small diagnostic renderer
that can be passed to Graphviz. Backpressured channels are drawn bidirectionally
while remaining one logical connection. Sequential blocks use a filled double
border, while combinational blocks retain the plain shape selected by their
logical kind.

DOT renders the selected module as a labeled cluster. Its input and output
interfaces are labeled point anchors on the left and right edges of that
cluster, rather than nested boundary boxes. Internal instances, registers, and
flow transforms use table-shaped nodes with named port cells, so every edge
terminates at the exact source and destination port.

The implicit `clock` and `reset` ports introduced by `sync_circuit`, including
their child-instance connections, are omitted from this logical view. An
ordinary `circuit` with explicitly authored `Clock` or `Reset` ports still
shows those ports; the distinction comes from sync-circuit metadata, not port
names or types.

JSON preserves interface channels and inferred ordinary combinational
dependencies with their complete types. DOT deliberately renders only
interface channels: edges are unlabeled, `Decoupled` is solid, `Irrevocable`
is thick, and `Valid` is dashed. Raw combinational dependencies remain
available to other consumers without cluttering the Graphviz view. A block
that has both flow ports and ordinary combinational ports retains short dotted
stubs from those ports into empty space. Inline map, filter, gate, and demux
transforms use one abstract `combo` input stub for their configured logic.

Sequential classification is derived from the verified IR. Registers,
memories, and other sequential operations make their containing module
sequential, and that classification propagates recursively through child
instances. A `sync_circuit` declaration alone does not make a block sequential.

## Ownership boundary

Core modules carry generic, namespace-keyed, nonsemantic metadata so extensions
can attach inspection facts without importing them. The interface frontend owns
interface grouping and transformation descriptions. Ordinary libraries such as
`std/flow` label the transformations they construct. The diagram package alone
turns those facts and the public IR into blocks and channels.

The metadata may affect presentation only. A backend must ignore it, and a
diagram extractor must still use verified IR connectivity rather than treating
metadata as a substitute netlist.

The [RV5Stage core example](../../examples/rv5stage/core-diagram.rhdl)
elaborates the RV64 core and generates a focused JSON and DOT view of its
logical pipeline and flow topology.

The [wormhole-router example](../../examples/noc/wormhole-router-diagram.rhdl)
projects a validated phased-XY plan into the packet-retaining NoC router and
generates the same JSON and DOT representations for its internal flow graph.

## Current limits

- DOT renders one graph per module; interactive hierarchy expansion is deferred.
- Flow labels cover the instrumented standard transformations, while an
  unlabelled custom interface transform still appears through its underlying
  instances and connections.
- Layout coordinates, timing, simulation activity, and physical RFPL geometry
  are intentionally outside this logical view.

See [PLAN.md](PLAN.md) for the incremental path beyond this vertical slice.
