<!-- Documents the optional CIRCT backend and its lowering of verified public RHDL IR. -->

# CIRCT backend

The backend is an explicit consumer of verified public core IR. It imports
[`../core/`](../core/README.md), never frontend syntax or elaboration, and owns
all CIRCT-specific opcode dispatch, type choices, SSA naming, and emission.

```text
RHDL hardware IR
    |
    v
CIRCT hw/comb/seq/verif/sim MLIR
    |
    v
CIRCT lowering passes and ExportVerilog
    |
    v
SystemVerilog
```

RHDL does not own a SystemVerilog emitter. CIRCT owns RTL generation.

## Type lowering

- Every `FlatDataType` lowers to a signless integer of its physical width.
- Anonymous `RecordType` lowers recursively to packed `hw.struct`, preserving
  field names and order. Named record shapes lower through `hw.typedecl` and
  `hw.typealias`.
- `VectorType` lowers recursively to `hw.array`.
- `Clock` and `Reset` lower to one-bit values in their control positions.
- Modules and instances use `hw`; combinational expressions use `comb` or
  `hw`; primitive registers use `seq`.
- Active-high synchronous reset remains explicit as `seq.firreg` with
  synchronous reset semantics.

Frontend-defined flat types need no backend special case. Equal lowered types
make representation casts aliases; other equal-width representations use
`hw.bitcast`. Bundle declarations preserve a preferred name as non-semantic
record metadata. The backend emits reachable named shapes in one CIRCT type
scope, and ExportVerilog renders them as packed SystemVerilog typedefs.
Distinct concrete shapes that request the same preferred name receive stable
numeric suffixes. Anonymous structural records remain inline structs.

## Operation lowering

| RHDL | CIRCT |
|---|---|
| `rtl.constant` | `hw.constant` |
| `rtl.dont_care` | `sv.constantX` as a synthesis-freedom carrier |
| `rtl.decode` | packed mask comparisons, `comb.mux`, and `sv.constantX` for free output bits |
| `rtl.not` | `comb.xor` with an all-ones constant |
| `rtl.and/or/xor` | `comb.and/or/xor` |
| `rtl.add/sub/mul` | `comb.add/sub/mul` |
| `rtl.shl/shru/shrs` | `comb.shl/shru/shrs` with lossless operand-width normalization |
| `rtl.eq/ult/slt` | `comb.icmp eq/ult/slt` |
| `rtl.mux_lookup` | comparisons plus a `comb.mux` tree |
| `rtl.onehot_mux` | selector-bit gating plus a balanced `comb.or` tree |
| `rtl.cast` | alias or `hw.bitcast` |
| `rtl.concat` | `comb.concat` |
| `rtl.extract/trunc` | `comb.extract` |
| `rtl.zext` | zero constant plus `comb.concat` |
| `rtl.sext` | sign-bit extraction plus `comb.concat` |
| `rtl.record_create/get` | `hw.struct_create/extract` |
| `rtl.vector_create/get` | `hw.array_create/get` |
| `rtl.memory` | `seq.hlmem` |
| `rtl.memory_read_async` | latency-zero `seq.read` |
| `rtl.memory_write` | latency-one `seq.write` |
| `rtl.sync_memory` | `seq.firmem` with native read, write, or shared read-write ports |
| `rtl.wire` | alias to the wire's driver |
| `verif.assert` | guarded, reset-suppressed rising-edge `verif.clocked_assert` |
| `sim.dpi_call` | result-less clocked `sim.func.dpi.call` |
| `sim.dpi_register` | one- or multi-result clocked `sim.func.dpi.call` |

Shift operands require equal widths in CIRCT. A narrower amount is
zero-extended. For a wider amount, an unsigned value is zero-extended and a
signed value is sign-extended before shifting and truncating back to its
declared width. This preserves fixed-width overflow and overshift semantics.

One-hot mux choices are packed when necessary, AND-gated by their corresponding
selector bits, reduced through a balanced OR tree, and cast back to their result
type. The operation deliberately adds no validity detector: zero-hot and
multi-hot selectors are outside its result contract.

RHDL does not introduce pseudo-CIRCT operations when CIRCT's canonical form is
a composition. An unsupported verified type or operation produces a backend
error rather than leaking CIRCT decisions into core schemas.

Synchronous-memory element types are packed to the integer width required by
`seq.firmem` and bitcast back at port boundaries. A declared RHDL mask
granularity determines the `seq.firmem` mask width, and write and read-write
ports pass their mask operand directly. CIRCT's generated-memory flow preserves
the declared physical topology, including native 1RW mode, enables, and
packed-lane masks, before producing its simulation SystemVerilog module. The
older asynchronous-read `Memory` resource continues to use `seq.hlmem`.

`rtl.decode` stays relational until backend lowering. The CIRCT backend packs
aggregate selectors, compares each canonical input cube with a mask, builds an
unordered-equivalent mux tree, and restores the declared aggregate result
type. Both `rtl.dont_care` and uncared decode-output bits use `sv.constantX` as
their synthesis-freedom carrier.

This carrier does not give RHDL four-state value semantics: the public
operations only grant synthesis freedom, and frontend operations continue to
use the ordinary two-state hardware model. A downstream RTL simulator can
display or propagate the carrier as X, but that behavior is a backend artifact
rather than an RHDL language contract.

`verif.assert` combines its frontend-derived activation guard with the inverse
of active-high reset and uses the result as CIRCT's assertion enable. It lowers
to `verif.clocked_assert` on the rising clock edge. The external pipeline lowers
this to a labeled SystemVerilog concurrent assertion, wraps it with a
`SYNTHESIS` preprocessor guard, and enables assertion evaluation in Verilator.

## API and verification

[`circt.rhm`](circt.rhm) exports `emit_circt(design)`. Emission verifies the
completed design before lowering. Backend unit tests check textual lowering;
external integration tests parse and verify MLIR, export SystemVerilog, and
simulate selected designs with Verilator.

The test and golden-output workflow is documented in
[`../../tests/backend/README.md`](../../tests/backend/README.md).
