<!-- Documents the independently selectable RHDL frontend layers and their authoring semantics. -->

# RHDL frontend layers

Frontend layers add notation, types, static information, and authoring policy
over existing core semantics. They do not import sibling layers or backends.
Shared machinery belongs in [`../support/`](../support/), and the authoritative
dependency inventory is in [`../../README.md`](../../README.md).

## Layer catalog

| Layer | Authoring feature |
|---|---|
| [`cast.rhm`](cast.rhm) | Functional equal-width representation casts |
| [`comb.rhm`](comb.rhm) | Literals, typed synthesis don't-cares, modular arithmetic, bitwise operations, muxes, shifts, and width operations |
| [`signed.rhm`](signed.rhm) | Explicit-width signed integers, literals, and resizing |
| [`expanding-arithmetic.rhm`](expanding-arithmetic.rhm) | Lossless unsigned `+&` and `*&` |
| [`bool.rhm`](bool.rhm) | Nominal `Bool`, equality, unsigned ordering, and binary `mux` |
| [`enum.rhm`](enum.rhm) | Nominal encoded hardware enums |
| [`one-hot.rhm`](one-hot.rhm) | Structurally sized one-hot values and selection |
| [`bundle.rhm`](bundle.rhm) | Bundle declarations, record construction, and fields |
| [`vector.rhm`](vector.rhm) | `Vec`, construction, selection, and functional update |
| [`wire.rhm`](wire.rhm) | Binding-derived internal single-driver wires |
| [`sequential.rhm`](sequential.rhm) | Binding-derived explicit and ambient registers |
| [`memory.rhm`](memory.rhm) | Memories, async reads, sync writes, and address widths |
| [`sync-memory.rhm`](sync-memory.rhm) | Circuit-shaped synchronous memories with fixed separate or shared ports |
| [`assertion.rhm`](assertion.rhm) | Reset-suppressed, branch-guarded clocked assertions |
| [`dpi.rhm`](dpi.rhm) | Clocked DPI procedures and explicit named DPI result registers |
| [`conditional.rhm`](conditional.rhm) | Hardware `when`, priority branches, and guarded writes |
| [`hierarchy.rhm`](hierarchy.rhm) | Instances, deterministic names, and child-member access |
| [`sync.rhm`](sync.rhm) | Ambient clock and synchronous-reset policy |
| [`interface.rhm`](interface.rhm) | Roles, directional protocols, refinement, and bulk connection |

`#lang rhdl` aggregates the curated set. A `#lang rhdl/base` program can import
only the layers it needs.

## Literals and combinational expressions

Integer hardware literals always state their width:

```rhombus
def zero = bits(0, width)
def one = bits(1, width)
```

These are immutable host-side `HardwareLiteral` shadows. They allocate IR only
when consumed by hardware. The generic `literal(T, packed_value)` form covers
every bit image of a packable `DataType`, including frontend-defined types,
records, and vectors. Materialization creates a canonical `Bits` constant and,
for non-`Bits` data, an explicit equal-width cast. `Clock`, `Reset`, and other
non-data types are not literal domains.

`dont_care(T)` is the corresponding typed synthesis-freedom source for any
packable `DataType`. It materializes a `Bits(packed_width(T))` core don't-care
and casts it to `T` when needed. It is not a literal, cannot be inspected as a
host packed value, and gives RHDL no runtime X-propagation semantics. A backend
may expose an X carrier to downstream tools, so use it only where every
synthesized bit choice is legal and do not rely on backend simulation of it.

`hw_decode(selector, input_type, output_type, cases, default_value,
default_care)` is the low-level authoring bridge to the core decode relation.
Its cases use packed integer value/care images. Ordinary designs should prefer
the typed `DecodeGen` standard-library wrapper, which constructs those images
from `Pattern` values.

The standard combinational surface includes modular `+`, `-`, `*`, shifts,
bitwise `&`, `^`, `and`, `or`, `xor`, and `not`. `Bits` arithmetic is unsigned;
`SInt` arithmetic uses a signed interpretation where the operation depends on
it. Both remain fixed-width. On host values these operators keep their ordinary
Rhombus meaning.

Expanding arithmetic is explicit:

```rhombus
sum <== a +& b
product <== a *& b
```

`+&` widens both operands to `max(width(a), width(b)) + 1`; `*&` widens them
to the sum of their widths. Both then use the existing modular core operation.
Unsigned expanding subtraction remains undefined because borrow policy is not
implied by a result width.

The canonical selection form is N-way lookup:

```rhombus
result <== mux_lookup(op, ~default: not a):
  0: a & b
  1: a or b
  2: a ^ b
```

Cases may come from a host list. Keys are checked and normalized during
elaboration. Binary `mux(sel, when_true, when_false)` is a `Bool` specialization
of the same core `rtl.mux_lookup`; there is no separate core mux operation.

## Boolean and ordering

`Bool` is a nominal one-bit frontend `BitwiseType`, not a core special case:

```rhombus
output ready: Bool
ready <== Bool(#true)
equal <== a === b
less <== a < b
```

`Bool(#true)` lowers to a one-bit constant plus an explicit cast. Equality
works on exactly equal flat types. `<`, `>`, `<=`, and `>=` require equal-width
operands with the same numeric type and return `Bool`. `Bits` uses unsigned
ordering while `SInt` uses signed ordering; the layer derives all forms from
the corresponding core less-than operation.

## Signed integers

`SInt(width)` is a nominal frontend `SignedArithmeticType` with an explicit
positive width. Signed literals accept only the two's-complement range for that
width and retain a canonical packed image:

```rhombus
input(a, b): SInt(8)
output result: SInt(8)

result <== (a + sint(-3, 8)) >> bits(1, 3)
```

Fixed-width `+`, `-`, and `*` wrap modulo `2^width`, just as their packed
two's-complement representations do. `>>` is arithmetic for `SInt`; `<<`
preserves the signed type. Shift amounts remain unsigned `Bits`. Mixed widths
and mixed `Bits`/`SInt` arithmetic are rejected rather than coerced.

`sext(value, target_width)` explicitly sign-extends. `strunc(value,
target_width)` explicitly retains the low bits and returns the same signed type
at the narrower width. Equal-width representation changes between `Bits` and
`SInt` continue to use `cast` or `.into`. Signed expanding arithmetic,
division, remainder, and implicit width inference are not part of this layer.

See [`../../../examples/signed-integers.rhdl`](../../../examples/signed-integers.rhdl).

## Hardware enums

```rhombus
hardware_enum Opcode(~width: 4):
  Add = 0
  Sub = 1
  Load = 8
```

Hardware enums are nominal `FlatDataType`s without arithmetic or bitwise
capability. Automatic encodings use declaration order and the minimum positive
width. Explicit encodings require a stable width, unique names and values, and
all-or-none explicit values.

Each evaluated declaration has distinct nominal identity. Members lower to
`Bits(width)` constants plus casts. Enum-selected `mux_lookup` requires keys
from exactly the selector's enum and retains a mandatory default for unused
encodings. See [`../../../examples/enum-state.rhdl`](../../../examples/enum-state.rhdl).

## One-hot values

`OneHot(n)` is a structurally sized `FlatDataType`. Calling the type with a
host index produces the corresponding power-of-two literal:

```rhombus
def Grant = OneHot(4)
next_grant <== mux_onehot(current):
  Grant(1)
  Grant(2)
  Grant(3)
  Grant(0)
```

One-hot values deliberately do not implement `BitwiseType`, because bitwise
operations do not preserve the exactly-one invariant. Equality, aggregates,
ports, state, and explicit casts work normally. `mux_onehot` lowers to the
partial `rtl.onehot_mux` operation. Exactly one selector bit must be set;
zero-hot and multi-hot results are unspecified. This contract needs no default
value and allows the backend to use selector-bit gating and a balanced OR tree.

## Packing and width operations

- `concat(a, b, ...)` accepts packable data and places the first operand in
  the most-significant bits; a host-generated list is also accepted.
- `bits_value[index]` produces `Bits(1)`.
- `value[low..high]` uses a half-open host range; `low..=high` is inclusive.
- Explicit `extract(value, high, low)` uses inclusive host indices.
- `zext` adds most-significant zeroes; `trunc` retains low bits.
- `.into(TargetType)` and `cast(value, TargetType)` preserve packed width and
  bit pattern while changing the hardware type.

Indices and ranges are host values known during elaboration. Width changes are
always explicit.

## Registers and synchronous circuits

A register exposes readable current state and a driveable next-state place:

```rhombus
reg state(Bits(width), ~clock: clk, ~reset: reset, ~init: zero)
state.next <== state + one
```

The type can be inferred from `~init` or `~next`. Supplying `~next` drives the
register immediately; another drive is an error. `~init` is an active-high
synchronous reset value, not power-up initialization. Register state may be
any `DataType`. Register keyword options follow ordinary Rhombus calling rules
and may appear in any order; their existing legal combinations are unchanged.

`sync_circuit` supplies real `clock: Clock` and `reset: Reset` inputs plus an
ambient domain:

```rhombus
sync_circuit Counter(width):
  output count: Bits(width)
  reg state(~init: bits(0, width))
  state.next <== state + bits(1, width)
  count <== state
```

A resetless ambient register uses the clock only. An initializer is never
invented merely because ambient reset exists.

## Asynchronous-read memories

```rhombus
mem storage(depth, Bits(width))
read_data <== storage[read_address]
storage.write(write_address, write_data,
              ~enable: write_enable, ~clock: clock)
```

Inside a `sync_circuit`, the clock may be omitted. Memory depth is a positive
host integer; elements may be any `DataType`; addresses are exactly
`Bits(index_width(depth))`. Reads are asynchronous physical ports. Writes are
independent rising-edge synchronous ports and share one clock per memory.

Initial contents, dynamic out-of-range addresses, read-during-write results,
and simultaneous writes to one address are unspecified. Resets, masks,
initialization, and combined read/write ports are not part of the current
contract.

## Synchronous memories

Synchronous memories are separate circuit-shaped primitives with declared,
fixed ports:

```rhombus
sync_mem storage(depth, Bits(width)):
  read
  write

storage.read.address <== read_address
storage.read.enable <== read_enable
read_data <== storage.read.data

storage.write.address <== write_address
storage.write.data <== write_data
storage.write.enable <== write_enable
```

Alternatively, one shared physical port performs either a read or a write per
cycle:

```rhombus
sync_mem storage(depth, Bits(width)):
  read_write

storage.read_write.address <== address
storage.read_write.enable <== enable
storage.read_write.write <== write
storage.read_write.write_data <== write_data
read_data <== storage.read_write.read_data
```

Write-capable memories can opt into uniform packed-lane masks:

```rhombus
sync_mem storage(depth, Bits(32), ~mask_granularity: 8):
  read_write

storage.read_write.address <== address
storage.read_write.enable <== enable
storage.read_write.write <== write
storage.read_write.write_data <== write_data
storage.read_write.write_mask <== byte_mask
read_data <== storage.read_write.read_data
```

The granularity is a positive host `Int` that divides the packed element
width. The mask is `Bits(packed_width / granularity)` and may select any subset
of the fixed lanes on each write. Separate write ports expose `.mask`; shared
ports expose `.write_mask`. Bit zero controls the least-significant packed
lane. Omitting `~mask_granularity` preserves the unmasked port shape.

The supported shapes are 1R, 1W, 1R1W, and 1RW. A `read_write` declaration
cannot yet be combined with separate `read` or `write` declarations. Port
declarations are not inferred from use, the primitive cannot be indexed, and
the fixed port names cannot be renamed. Address fields are
`Bits(index_width(depth))`, data fields use the element `DataType`, and
`enable` and `write` are `Bits(1)`.

Inside a `sync_circuit`, `sync_mem` uses the ambient clock. An ordinary
`circuit` supplies `~clock: clock` in the declaration. `~clock` and
`~mask_granularity` may appear in either order. An enabled read samples
its address on a rising edge and presents the corresponding data after that
edge. Data while read enable is false is unspecified. The primitive has no
reset or initialization; out-of-range addresses and same-cycle read/write
collisions between separate ports are also unspecified. On an enabled shared
port, `write = 0` reads and `write = 1` writes; `read_data` after a write or
while disabled is unspecified. An all-zero write mask preserves storage but
does not turn a shared write-mode cycle into a read. Port arrays remain outside
this contract.

## Clocked assertions

```rhombus
sync_circuit CheckedQueue():
  input invariant: Bool
  input request: Bits(1)

  assert(invariant, "queue_invariant")
  when request:
    assert(invariant, "request_invariant")
```

An assertion samples a readable one-bit `FlatDataType` on each rising clock
edge. It is disabled while the active-high reset is asserted. `sync_circuit`
supplies the ambient clock and reset. An ordinary circuit must supply both
`~clock` and `~reset`; supplying only one is an error. Host Booleans are not
hardware conditions.

The optional second positional argument is an ASCII identifier label. The
current form has no formatted message operands or temporal-property syntax.
Inside `when`, an assertion is active only when its effective priority branch
is selected. `elsewhen` guards exclude earlier conditions, `otherwise` covers
the unmatched case, and nested chains combine their guards. The public
assertion form has no `~enable` option.

## Clocked DPI

```rhombus
dpi_import procedure rhdl_trace(value: Bits(8))
dpi_import function rhdl_step(value: Bits(8)) -> result: Bits(8)
dpi_import function rhdl_step_pair(value: Bits(8)) -> (
  out doubled: Bits(8),
  return incremented: Bits(8)
)

rhdl_trace.call(value, ~enable: enable)
dpi_reg step_result = rhdl_step(value, ~enable: enable)
dpi_reg (doubled_result, incremented_result) = rhdl_step_pair(value, ~enable: enable)
```

A procedure is a clocked side effect with no result. A DPI function has one C
return and may place `out` results before it; every input and result must be a
flat hardware type. A single-result function uses one `dpi_reg` binding. A
multi-result function uses parenthesized `dpi_reg` bindings in declaration
order. The bindings are separate hardware values rather than a packed bundle.
Each result is visible state: it holds while disabled, has unspecified initial
value, and has no reset. A `sync_circuit` supplies the ambient clock, while
ordinary circuits pass `~clock` explicitly. `dpi_reg` accepts `~clock` and
`~enable` in either order. There is no unclocked DPI form,
`inout`, or `ref` support.

## Hardware conditional assignment

`when` accepts only a readable one-bit `FlatDataType`. Host values are rejected:

```rhombus
when load:
  state.next <== data_in
elsewhen clear:
  state.next <== zero
otherwise:
  state.next <== fallback
```

The first true branch wins. Nested chains lower each destination to priority
mux lookups plus one final drive. Register-next destinations may omit
`otherwise` and implicitly hold current state. Outputs, wires, and instance
inputs require exhaustive assignment.

Conditional memory writes are effects rather than place assignments. Branch
guards combine with explicit local enables, and corresponding write positions
across mutually exclusive branches share one physical port with muxed address
and data. Independent chains remain independent ports.

Assertions participate in conditional-body lowering: each assertion receives
the effective priority branch as a derived activation guard. Clocked DPI calls
and DPI result registers do not participate; put those effects outside `when`
and pass the hardware condition through `~enable`.

A destination may appear once per branch, and separate chains do not implement
last-connect semantics. Primitive register reset remains expressed through
`~reset` and `~init`.

## Hierarchy

Every circuit call creates a fresh definition. Bind a definition once to reuse
it across instances:

```rhombus
def AdderModule = Adder(8)
inst u0(AdderModule)
inst u1(AdderModule)
```

An `inst` binding supplies a suggested name; collisions receive deterministic
suffixes. `InstanceArray` is a host collection reducer that retains checked
static information for concise child-port access. Child inputs are places,
child outputs are values, and all communication uses ports.

A marked sync child instantiated inside a sync parent receives the ambient
clock and reset. Ordinary children never participate implicitly. Outside a
sync parent, both signals must be supplied explicitly.

## Bundles and records

The bundle layer gives concise declarations and fields over core structural
records:

```rhombus
bundle Pair(T):
  left: T
  right: T

result.left <== source.right
result.right <== source.left
```

Complete field-wise drives canonicalize to nested record construction and one
whole-record drive. Partial assignment and mixing whole with field-wise drives
are errors. When every field of `record(...)` is a `HardwareLiteral`, the form
creates a reusable recursive `RecordLiteral`; otherwise it creates runtime
`rtl.record_create` hardware.

## Fixed-length vectors

`Vec(n, T)` constructs the public structural `VectorType` descriptor, while
`vec(...)` layers concise construction over it. Literal-only construction
produces a reusable `VectorLiteral`; live elements produce a runtime vector
value. Element zero occupies the least-significant packed slot.

Static host indexing works for readable values and driveable places. Complete
element-wise drives canonicalize to one vector construction and whole drive.
Dynamic read and functional replacement are explicit:

```rhombus
chosen <== values.lookup(selector, ~default: fallback)
next_value <== current.updated(selector, replacement)
```

Lookup projects all elements and builds a mux. `updated` reconstructs the
vector with per-element muxes; an out-of-range selector leaves the original
vector unchanged. There is no dynamic vector-index operation or dynamically
selected mutable place in core.

## Wires

`wire temporary: T` creates an internal single-driver place that becomes
readable after one complete drive. Aggregates may be assembled leaf by leaf;
all leaves must be driven, and whole and projected drive modes cannot mix.
Conditional assignment may synthesize one exhaustive priority driver.

Core retains `rtl.wire` for inspection. CIRCT lowering aliases the read value
to its driver, so a SystemVerilog wire is not necessarily emitted.

## Interfaces

Interfaces are frontend protocol descriptors over directional record ports,
not core `DataType`s:

```rhombus
interface ingress(Decoupled(T), ~role: consumer)
interface egress(Decoupled(T), ~role: producer)
egress <=> ingress
```

Each root direction becomes one record-typed core port. `<=>` atomically
connects exact flows or compatible provider-to-peer contracts; operand order
is irrelevant. Individual fields remain accessible, and frontend metadata
reconstructs endpoints through instances without guessing from port names.

Each root interface declaration has a stable nominal identity. Repeated calls
to one parameterized declaration compare that identity plus their realized
member structure; independently declared same-named interfaces remain
distinct. `Endpoint.of(protocol)` checks one exact nominal specialization.
`Endpoint.supports(protocol)` accepts that protocol, a transitive refinement,
or a declared supported contract while retaining endpoint static information.

The first declared role is the compatibility provider by default. A root
interface whose provider is the other role declares it explicitly after its
roles, for example `provider sender`. Endpoint provenance records whether the
connected component is a module peer or an instance, so compatible connection
does not infer orientation from the presence of a particular member.

An interface can declare one nominal parent with `refines` and additional,
role-qualified, structurally checked contracts such as
`supports producer: Decoupled(T)`. The support role must be the interface's
provider role. Parenthesized `<=>` forms
merge a parent endpoint with its refinement delta or split a richer source
into parent and delta destinations. The frontend checks the parent, complete
field set, types, and directions.

Interface members may themselves be interfaces. Composition, field access,
bulk connection, and instance reconstruction work recursively. Nested
directions lower to nested `RecordType` fields and then CIRCT `hw.struct`
without core or backend interface cases.

Ready-valid protocols and reusable flow circuits are documented in
[`../../std/README.md`](../../std/README.md). Canonical feature programs live
in [`../../../examples/`](../../../examples/README.md).
