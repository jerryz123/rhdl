<!-- Documents the independently selectable RHDL frontend layers and their authoring semantics. -->

# RHDL frontend layers

Frontend layers add notation, types, static information, and authoring policy
over existing core semantics. They do not import sibling layers or backends.
Shared machinery belongs in [`../support/`](../support/), and the authoritative
dependency inventory is in [`../../README.md`](../../README.md).

## Layer catalog

| Layer | Authoring feature |
|---|---|
| [`cast.rhm`](cast.rhm) | Equal-width representation casts plus inferred packing to `Bits` and splitting into uniform vectors |
| [`comb.rhm`](comb.rhm) | Literals, typed synthesis don't-cares, modular arithmetic, bitwise operations, muxes, shifts, and width operations |
| [`signed.rhm`](signed.rhm) | Explicit-width signed integers, literals, and resizing |
| [`expanding-arithmetic.rhm`](expanding-arithmetic.rhm) | Lossless unsigned `+&` and `*&` |
| [`bool.rhm`](bool.rhm) | Nominal `Bool`, packed Boolean reductions and population count, equality, typed membership, enum validity, ordering, and binary `mux` |
| [`enum.rhm`](enum.rhm) | Nominal sequential, explicit, and one-hot encoded hardware enums |
| [`one-hot.rhm`](one-hot.rhm) | One-hot selector values and partial selection |
| [`bundle.rhm`](bundle.rhm) | Bundle declarations, record construction, and fields |
| [`vector.rhm`](vector.rhm) | `Vec`, construction, selection, and functional update |
| [`wire.rhm`](wire.rhm) | Binding-derived internal single-driver wires |
| [`sequential.rhm`](sequential.rhm) | Binding-derived explicit and ambient registers |
| [`memory.rhm`](memory.rhm) | Memories, async reads, sync writes, and address widths |
| [`sync-memory.rhm`](sync-memory.rhm) | Circuit-shaped synchronous memories with fixed separate or shared ports |
| [`assertion.rhm`](assertion.rhm) | Reset-suppressed, branch-guarded clocked assertions |
| [`dpi.rhm`](dpi.rhm) | Clocked DPI procedures and explicit named DPI result registers |
| [`conditional.rhm`](conditional.rhm) | Hardware `when` priority chains, exact-key `switch`, and guarded effects |
| [`hierarchy.rhm`](hierarchy.rhm) | Instances, deterministic names, child-member access, and derived-reset instantiation |
| [`sync.rhm`](sync.rhm) | Hidden ambient clock, synchronous-reset policy, and scoped reset derivation |
| [`interface.rhm`](interface.rhm) | Roles, directional protocols, read-only observations, refinement, and bulk connection |
| [`clocking.rhm`](clocking.rhm) | Root-owned temporal environments, durable sync-level crossing evidence, reports, and opt-in CDC enforcement |

`#lang rhdl` aggregates the curated set, including clocking now that its
crossing evidence is durable core IR. A `#lang rhdl/base` program can still
import only the layers it needs.

## Clocking environments and CDC enforcement

Import `clocking.rhm` explicitly and use `elaborate_with_clocking` when a
completed design should be analyzed in a top-level temporal environment:

```rhombus
import:
  lib("rhdl/frontend/layers/clocking.rhm") open

circuit Top():
  input clock: Clock
  input data: Bits(8)
  synchronous_input(data, clock)

def clocked = elaborate_with_clocking(Top())
def design = clocked.design
def report = clocked.summary
```

`synchronous_input`, `asynchronous_input`, and `unknown_input_timing` attach a
contract to a top data input or aggregate subtree. `identical_clocks`,
`derived_clock`, `asynchronous_clocks`, and `exclusive_clocks` describe pairs
of top `Clock` inputs. These declarations are legal only while the wrapper is
elaborating its explicit top circuit; child-owned and hardware-conditional
declarations are rejected. The result retains the `DesignElaboration`, the
validated `TemporalEnvironment`, and the resolved `DesignTemporalSummary`.

`elaborate_with_clocking` remains report-only. `elaborate_with_cdc` applies the
first conservative policy: static, exact-clock, and declared-identical inputs
are safe; other sampled data requires recognized crossing evidence. Reset
inputs remain inventory-only pending RDC semantics.

The retained summary also diagnoses distinct verified crossing identities
that later reach one clocked sink through `summary.reconvergences`. These
findings preserve source and hierarchy lineage but do not make otherwise legal
crossings fail strict CDC verification.

The low-level `sync_level_crossing(source, stages)` hook records a stable-level
promise around an ordinary resetless register chain using the certified
ambient `sync_circuit` clock. An explicit destination clock may be supplied as
`sync_level_crossing(source, destination_clock, stages)` outside that ambient
context. Core verification requires `Bits(1)`, at least two direct
destination-clock stages, and no functional fanout from intermediate stages.
Most authors should instantiate
[`../../std/cdc/level.rhdl`](../../std/cdc/level.rhdl) rather than calling the
evidence hook directly.

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
and the hardware-only bitwise operators `&`, `|||`, and `^`. Prefix `-`
performs fixed-width two's-complement arithmetic negation on `Bits` and `SInt`
and ordinary numeric negation on host values. Prefix `!` is a width-preserving
hardware inversion for both `Bool` and `Bits`; on host values it retains
Rhombus negation. The three-character OR spelling avoids conflicting with
Rhombus's use of bare `|` for block alternatives. Host bit manipulation remains
available explicitly through `rhombus.bits`. `Bits` arithmetic is unsigned.
Rhombus `&&` and `||` remain host short-circuit operators; hardware conjunction
and disjunction use `&` and `|||`.
`SInt` arithmetic uses a signed interpretation where the operation depends on
it. Both remain fixed-width. Arithmetic and shift operators keep their ordinary
Rhombus meaning on host values; the symbolic bitwise family requires hardware
operands. A hardware value may be shifted by either an unsigned hardware `Bits`
amount or a nonnegative host `Int`; a host amount becomes a minimally wide
constant during elaboration. Negative host amounts are rejected.

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
result <== mux_lookup(op, ~default: !a):
  0: a & b
  1: a ||| b
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
different <== a =/= b
less <== a < b
active <== is_one_of(state, State.Refill, State.Respond)
encoding_valid <== enum_valid(state)
nonzero <== or_reduce(value)
all_set <== and_reduce(value)
set_count <== popcount(value)
first_index <== priority_encoder(value)
first_mask <== priority_encoder_oh(value)
```

`Bool(#true)` lowers to a one-bit constant plus an explicit cast. Equality
and inequality work on exactly equal flat types and return `Bool`; `=/=` is
the Boolean complement of `===` and lowers to equality followed by negation.
`is_one_of(value, alternative, ...)` accepts alternatives of the same exact
flat type either variadically or as one host list and lowers to typed
equalities joined by hardware OR. Membership in an empty host list is false.
`enum_valid(value)` derives the complete runtime membership test from a
hardware enum's declared encodings. This matters at ports and cast boundaries:
the enum type prevents unrelated typed operations, but its physical wire can
still carry an unused packed encoding. The predicate works for sequential,
explicit, and one-hot enums; a non-enum operand is rejected.
`or_reduce(value)` and `and_reduce(value)` accept any packable hardware
`DataType` or a host list of packable hardware values, reduce the canonical
packed representation, and return `Bool`. Empty host lists use the Boolean
identities: `or_reduce([])` is false and `and_reduce([])` is true. Nonempty
operands lower respectively to inequality with zero and equality with an
all-ones value, expressed through existing equality and inversion operations
without adding core reduction operations or zero-width hardware types.
`popcount(value)` counts asserted bits in the same canonical packed
representation. For an `n`-bit representation it returns
`Bits(index_width(n + 1))`; an empty host list returns one-bit zero. Population
count lowers to a balanced tree of capacity-sized additions, keeping
logarithmic depth without widening small subtrees beyond the values they can
represent.
`priority_encoder(value)` returns the index of the lowest asserted bit in the
canonical packed representation, while `priority_encoder_oh(value)` returns a
`Bits` mask containing only that bit. Both return zero for an all-zero operand;
use `or_reduce(value)` when binary index zero must be distinguished from no
asserted input. A `Vec`'s logical element zero is its lowest packed lane, so the
same lower-index-first rule applies directly to vectors. The optional-one-hot
result is `Bits` rather than `OneHot`, because an all-zero result is valid.
Host code continues to use `!=`. `<`, `>`, `<=`, and `>=` require equal-width
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

result <== (a + sint(-3, 8)) >> 1
```

Fixed-width `+`, `-`, and `*` wrap modulo `2^width`, just as their packed
two's-complement representations do. `>>` is arithmetic for `SInt`; `<<`
preserves the signed type. Dynamic shift amounts remain unsigned `Bits`;
constant amounts may be nonnegative host `Int` values. Mixed widths and mixed
`Bits`/`SInt` arithmetic are rejected rather than coerced.

`sext(value, target_width)` explicitly sign-extends. `strunc(value,
target_width)` explicitly retains the low bits and returns the same signed type
at the narrower width. Equal-width representation changes between `Bits` and
`SInt` continue to use `cast` or `.into`. Signed expanding arithmetic,
division, remainder, and implicit width inference are not part of this layer.

See [`../../../examples/rhdl/signed-integers.rhdl`](../../../examples/rhdl/signed-integers.rhdl).

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

A declaration can instead make its encoding policy explicit and derive one
selector bit per member:

```rhombus
hardware_enum ResultKind(~encoding: one_hot):
  Arithmetic
  Shift
  Compare
  Xor
  Or
  And

result <== mux_onehot(select):
  ResultKind.Arithmetic: arithmetic_result
  ResultKind.Shift: shift_result
  ResultKind.Compare: compare_result
  ResultKind.Xor: xor_result
  ResultKind.Or: or_result
  ResultKind.And: and_result
```

This produces a six-bit nominal enum with encodings `1`, `2`, `4`, `8`, `16`,
and `32`. It is distinct from both `OneHot(6)` and every other enum declaration,
but its packed representation can directly drive `mux_onehot`. Keyed arms are
checked against that nominal enum and must cover each member exactly once. See
[`../../../examples/rhdl/one-hot-enum.rhdl`](../../../examples/rhdl/one-hot-enum.rhdl).

Each evaluated declaration has distinct nominal identity. Members lower to
`Bits(width)` constants plus casts. Enum-selected `mux_lookup` requires keys
from exactly the selector's enum and retains a mandatory default for unused
encodings. See [`../../../examples/rhdl/enum-state.rhdl`](../../../examples/rhdl/enum-state.rhdl).

## One-hot values

`OneHot(n)` is a structurally sized `FlatDataType`. Calling the type with a
host index produces the corresponding power-of-two literal. A one-hot encoded
hardware enum provides the same selector contract while retaining named,
nominal members:

```rhombus
def Grant = OneHot(4)
next_grant <== mux_onehot(current):
  Grant(1)
  Grant(2)
  Grant(3)
  Grant(0)
```

`one_hot(index)` converts a hardware `Bits(n)` index to `OneHot(2^n)`. Inferring
the result width makes the conversion total: every index encoding selects
exactly one lane. Use `as_bits(one_hot(index))` when subsequent mask operations
may produce zero or multiple asserted bits.

One-hot values deliberately do not implement `BitwiseType`, because bitwise
operations do not preserve the exactly-one invariant. Equality, aggregates,
ports, state, and explicit casts work normally. `mux_onehot` accepts either a
structural `OneHot(n)` value or a nominal one-hot hardware enum and lowers to
the partial `rtl.onehot_mux` operation. Exactly one selector bit must be set;
zero-hot and multi-hot results are unspecified. This contract needs no default
value and allows the backend to use selector-bit gating and a balanced OR tree.

## Packing and width operations

- `concat(a, b, ...)` accepts packable data and places the first operand in
  the most-significant bits; a host-generated list is also accepted.
- `bits_value[index]` produces `Bits(1)`.
- `value[low..high]` uses a half-open host range; `low..=high` is inclusive.
- Explicit `extract(value, high, low)` uses inclusive host indices.
- `zext(bits_value, target_width)` adds most-significant zeroes to `Bits` and
  returns wider `Bits`; use `as_bits` to expose other packable data first.
- `trunc` retains low bits.
- `.into(TargetType)` and `cast(value, TargetType)` preserve packed width and
  bit pattern while changing the hardware type.
- `as_bits(value)` exposes any packable data value as
  `Bits(packed_width(value.type))`; an existing `Bits` value is unchanged.
- `as_vec(value, ElementType)` splits any packable data representation into a
  `Vec` whose inferred length exactly covers the source width. Element zero
  receives the least-significant element-width chunk, and an existing vector
  of the inferred type is unchanged.

Indices and ranges are host values known during elaboration. Width changes are
always explicit.

## Registers and synchronous circuits

A register reads as its current state and drives as its next state:

```rhombus
reg state(Bits(width), ~clock: clk, ~reset: reset, ~init: zero)
state <== state + one
```

The same rule follows statically selected aggregate paths. Reading
`state.field` or `state[index]` selects current state, while using that path as
the direct target of `<==` selects the corresponding next-state place.
Author-level RTL should always use this direct form. Hardware-selected dynamic
indices are values rather than places; express those updates as a
whole-register drive with `.updated`.

The type can be inferred from `~init` or `~next`. Supplying `~next` drives the
register immediately; another drive is an error. `~init` is an active-high
synchronous reset value, not power-up initialization. Register state may be
any `DataType`. Register keyword options follow ordinary Rhombus calling rules
and may appear in any order; their existing legal combinations are unchanged.

`sync_circuit` supplies real `clock: Clock` and `reset: Reset` inputs plus an
ambient domain. Those ports are present in the core IR and emitted RTL, but
`clock` and `reset` are not source bindings inside the body:

```rhombus
sync_circuit Counter(width):
  output count: Bits(width)
  reg state(~init: bits(0, width))
  state <== state + bits(1, width)
  count <== state
```

A resetless ambient register uses the clock only. An initializer is never
invented merely because ambient reset exists. Explicit `~clock` and `~reset`
controls are rejected while a sync domain is active; use an ordinary `circuit`
for an explicit clock boundary.

`reset_when(condition)` creates a nested domain whose reset is the active
ambient reset OR a readable one-bit data or `Reset` condition. Nested scopes
compose by ORing each added condition:

```rhombus
reset_when(flush):
  reg pending(~init: Bool(#false))
  pending <== next_pending
```

A sync child that needs the derived reset but remains in use after the scoped
expression uses the equivalent instance option:

```rhombus
inst responses(Queue(Response(), 2), ~reset_when: flush)
```

The child's clock remains ambient; `~reset_when` is not an explicit control
override and is valid only for a `sync_circuit` child. When hardware or a
simulation boundary must observe the active reset as data, `reset_active()`
returns it as `Bits(1)` and respects the innermost reset scope. There is no
corresponding clock-value escape hatch.

## Asynchronous-read memories

```rhombus
mem storage(depth, Bits(width))
read_data <== storage[read_address]
storage.write(write_address, write_data,
              ~enable: write_enable, ~clock: clock)
```

Inside a `sync_circuit`, the clock is omitted. Memory depth is a positive
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

Inside a `sync_circuit`, `sync_mem` uses the ambient clock and rejects
`~clock`. An ordinary `circuit` supplies `~clock: clock` in the declaration. `~clock` and
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
supplies the ambient clock and reset and rejects explicit controls. An ordinary
circuit must supply both `~clock` and `~reset`; supplying only one is an error.
Host Booleans are not hardware conditions.

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
value, and has no reset. A `sync_circuit` supplies the ambient clock and
rejects `~clock`, while ordinary circuits pass it explicitly. `dpi_reg` accepts
`~clock` and `~enable` in either order. There is no unclocked DPI form,
`inout`, or `ref` support.

## Hardware conditional assignment

`when` accepts only a readable one-bit `FlatDataType`. Host values are rejected:

```rhombus
when load:
  state <== data_in
elsewhen clear:
  state <== zero
otherwise:
  state <== fallback
```

The first true branch wins. Nested chains lower each destination to priority
mux lookups plus one final drive. Register-next destinations may omit
`otherwise` and implicitly hold current state. Outputs, wires, and instance
inputs require exhaustive assignment.

`switch` selects unordered, unique exact keys from one hardware selector:

```rhombus
switch state:
  case State.Idle:
    state <== State.Running
  case State.Running:
    state <== State.Done
  otherwise:
    state <== State.Idle
```

Bits selectors use nonnegative host `Int` keys. Typed mux-key selectors such as
hardware enums and `OneHot` require keys from that selector's own type. Case
order carries no priority, fallthrough is unsupported, and keys must be unique
and fit the selector width. Each assigned destination lowers directly to one
`rtl.mux_lookup`. As with `when`, outputs, wires, and instance inputs require
`otherwise`, while register-next destinations may omit it and hold.

Conditional memory writes are effects rather than place assignments. Branch
guards combine with explicit local enables, and corresponding write positions
across mutually exclusive branches share one physical port with muxed address
and data. Independent chains remain independent ports.

Assertions participate in conditional-body lowering: each assertion receives
the effective priority or exact-match branch as a derived activation guard.
Clocked DPI calls and DPI result registers do not participate; put those effects
outside `when` or `switch` and pass the hardware condition through `~enable`.

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

def swapped = Pair(Bits(8)):
  left: source.right
  right: source.left

result.left <== source.right
result.right <== source.left
```

Calling the declared name with its parameters and no field block produces a
`RecordType`; attaching a field block constructs a value of that type. Fields
are named, order-independent, and must be supplied exactly once with matching
hardware types. The bare type family remains an ordinary host value, so it can
be passed to a function and called later. The declaration also supplies a
preferred emitted type name without changing structural type equality. When
multiple concrete specializations request that name, the backend retains the
first and adds numeric suffixes to the rest.

A bundle can conditionally include one or more fields using a host `if` group:

```rhombus
bundle TaggedPayload(T, include_tag):
  payload: T
  if include_tag:
    tag: Bits(4)
```

The condition is evaluated during elaboration and must produce a host
`Boolean`; a hardware `Bool` is rejected. `TaggedPayload(Bits(8), #false)` is
an eight-bit record containing only `payload`, while the `#true`
specialization is a twelve-bit record that also requires `tag`. An absent
field is not evaluated, consumes no width, cannot be projected, and must not be
supplied during construction. Remaining fields retain source order, duplicate
realized names are rejected, and every concrete specialization must contain at
least one field. Structural equality continues to compare the resulting
record fields rather than the conditions that produced them.

Complete field-wise drives canonicalize to nested record construction and one
whole-record drive. Partial assignment and mixing whole with field-wise drives
are errors. When every field of a named bundle construction is a
`HardwareLiteral`, the form creates a reusable recursive `RecordLiteral`;
otherwise it creates runtime `rtl.record_create` hardware. The lower-level
`record(type_value): fields` form remains available when the `RecordType` is a
dynamically computed host value instead of a directly named bundle family.

## Fixed-length vectors

`Vec(n, T)` constructs the public structural `VectorType` descriptor, while
`vec(...)` layers concise construction over it. Literal-only construction
produces a reusable `VectorLiteral`; live elements produce a runtime vector
value. Element zero occupies the least-significant packed slot.

Static host indexing works for readable values and driveable places. A hardware
`Bits(index_width(n))` index may read a `Vec(n, T)` with ordinary brackets; an
out-of-range encoding is undefined and makes the result unconstrained.
Complete element-wise drives canonicalize to one vector construction and whole
drive. Total dynamic read and functional replacement remain explicit:

```rhombus
chosen <== values.lookup(selector, ~default: fallback)
next_value <== current.updated(selector, replacement)
```

Bracket selection lowers to core `rtl.vector_index`. Lookup projects all
elements and builds a mux with its explicit default. `updated` reconstructs the
vector with per-element muxes, and an out-of-range selector leaves the original
vector unchanged.

A direct `Reg<Vec(n, T)>` is the one dynamically assignable exception:

```rhombus
state[selector] <== replacement
```

Repeated assignments describe independent write ports without tuple syntax:

```rhombus
when write_enable_0:
  state[address_0] <== data_0
when write_enable_1:
  state[address_1] <== data_1
```

All writes to one register lower together to core `rtl.vector_write_set` and
one whole next-state driver. Writes in mutually exclusive branches share a
port; writes in independent conditionals remain independent ports. Enabled
indices must be in range and pairwise distinct. A collision has undefined
behavior and no port priority, allowing symmetric decode and merge logic.
Multiple total functional replacements may still be composed explicitly with
chained `updated` calls. Dynamically selected ordinary vector places remain
read-only.

## Wires

`wire temporary: T` creates an internal single-driver connection. Its value is
readable before its one driver is declared, so wiring order does not impose
dataflow order. Verification still requires one complete effective driver.
Aggregates may be assembled leaf by leaf;
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

Interfaces describe connectivity and do not carry monitor factories or
instrumentation policy. `observe(endpoint)` explicitly creates a read-only view
containing fields from both directions, so ordinary library functions can
correlate a forward `valid` with a backward `ready`:

```rhombus
interface Stream(T):
  role producer
  role consumer
  producer -> consumer:
    valid: Bool
    bits: T
  consumer -> producer:
    ready: Bool

fun monitor_stream(link :: Observation):
  assert(!(link.ready & !link.valid), "ready_requires_valid")

sync_circuit Producer():
  interface stream(Stream(Bits(8)), ~role: producer)
  stream.valid <== false
  stream.bits <== 0
  monitor_stream(observe(stream))
```

The observation capability prevents instrumentation from becoming another
driver. Protocol packages can offer several independent monitor functions, and
an implementation or verification wrapper chooses which ones to elaborate at a
specific endpoint. A monitor that uses `assert`, registers, or other ambient
sequential operations must be called in a `sync_circuit`.

Each root interface declaration has a stable nominal identity. By default,
repeated calls to one parameterized declaration compare that identity plus
their realized member structure; independently declared same-named interfaces
remain distinct. A declaration with a custom connection rule also preserves
its arguments as part of exact-specialization matching. `Endpoint.of(protocol)`
checks one exact nominal specialization.
`Endpoint.supports(protocol)` accepts that protocol, a transitive refinement,
or a declared supported contract while retaining endpoint static information.
Ordinary libraries can apply the same nominal relation to type descriptors
with `interface_type_supports(type, protocol)`; interface display names are not
part of either check.

A parameterized root interface may explicitly define a directional connection
rule after its provider declaration:

```rhombus
interface CapacityLink(capacity, width):
  role producer
  role consumer
  provider producer
  connection_compatible producer (provided, required):
    provided[0] >= required[0]

  producer -> consumer:
    payload: Bits(width)
```

`provided` and `required` are Lists containing the corresponding declaration
arguments. The provider-owned predicate runs at elaboration time, must return a
host `Boolean`, and is directional; `<=>` operand order does not affect which
specialization is provided. The predicate governs every connection, including
two endpoints with equal arguments. `Endpoint.supports(protocol)` uses the
rule, while `Endpoint.of(protocol)` remains exact. A rule applies only within
one nominal interface family. It may relax semantic parameter compatibility,
but member names, directions, and recursively realized hardware types must
still match exactly. Width conversion or field translation therefore requires
an explicit adapter. Nested interface members and endpoint arrays apply the
same rule recursively.

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

Declared endpoint arrays bulk-connect directly. A parenthesized sequence on
the right connects individual endpoints positionally to an array on the left:

```rhombus
egress <=> (first_ingress, second_ingress)
```

The sequence must have the same length as the array, and every pair receives
the ordinary protocol, type, and direction checks. This parenthesized form is
connection-only syntax, not a general host tuple, and cannot appear on the
left of `<=>`. Scalar endpoint connections keep using the same syntax for
interface refinement merge and split.

`interface_link(protocol)` creates a local pair of complementary endpoint
views over forward-readable, exactly-one-driver wires. An `InterfaceHandle`
owns a left endpoint shape and a right endpoint shape. Endpoint shapes are an
`Endpoint` or recursively matching `Array`s of endpoints.

`interface_transform(input_links, output_links)` adopts already-wired local
links as one generic transform. Its input can be one link or an array-shaped
product of links, and its output can independently be one link or an array.
The transform exposes input links' left sides and output links' right sides,
supporting 1-to-1 protocol conversion as well as N-to-M topology without
adding a protocol concept to core IR. Protocol libraries implement the wiring
between the internal link ends before constructing the transform.

A binding annotated as `Handle` exposes `.left` and `.right` as endpoint
shapes: either one `Endpoint` or a recursively matching endpoint `Array`.
Static information preserves field access on scalar sides and indexing on
array sides. This supports named local links such as `Valid(T)` sidebands:
drive the fields on `.left` and read the corresponding fields on `.right`
without materializing a circuit instance.

- `endpoint |> handle` connects the endpoint to the left end and returns the
  right end while preserving endpoint-shape static information.
- `endpoint |> endpoint` connects the source to the terminal endpoint and
  returns `#void`, allowing a complete topology to remain one pipeline.
- `first_handle |> second_handle` connects their adjacent ends and returns a
  handle owning the two outside ends.
- `handle |> endpoint` performs the same partial termination and returns its
  `InterfaceSink`, so a detached topology can be assembled from right to left.
- `endpoint |> sink` completes the topology and returns `#void`; an earlier
  `handle |> sink` retains that handle's left end in a new sink.
- `parallel_handles(Array(...))` creates one array-shaped handle or sink from
  a homogeneous collection. Handles and sinks cannot be mixed.

Handles and sinks are interface-generic: they contain no ready-valid policy,
buffering, or new core IR. They are linear host objects because consuming one
twice would attempt to drive an interface destination twice. `<=>` between
concrete endpoint shapes performs the hardware wiring effect and returns
`#void`; piping a handle into an endpoint performs partial termination and
returns a sink.

Configured standard flow stages use the interface topology static-information
key through `InterfaceTransformResult` to select a dependent result. A known
endpoint or endpoint array exposes the connected transform's exact result
shape, a handle remains a handle, and a generic expression receives a
conservative topology annotation that permits endpoint fields, array indexing,
and handle-side access until elaboration chooses the concrete shape. This is
frontend information only; it creates no protocol-specific runtime graph or
core IR type.

`inject_interface(protocol, ...)` creates an endpoint from ordinary hardware,
and `eject_interface(...)` terminates an endpoint back into ordinary hardware.
Every declared member is supplied by name; `interface_fields(...)` groups the
bindings of a nested interface member. These boundaries derive direction only
from the interface roles and provider declaration. They do not inspect names
such as `valid`, `ready`, `bits`, or `credit`.

The interface layer therefore owns composition, topology, and generic circuit
boundaries. `Valid`, `Decoupled`, `Irrevocable`, and `Credited` are optional
standard-library protocols above it. User libraries can declare unrelated
bidirectional protocols and configured transforms without importing those
standard protocols.

Ready-valid protocols and reusable flow circuits are documented in
[`../../std/README.md`](../../std/README.md). Canonical feature programs live
in [`../../../examples/`](../../../examples/README.md).
