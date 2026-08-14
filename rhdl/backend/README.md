<!-- Documents the optional CIRCT backend and its lowering of verified public RHDL IR. -->

# CIRCT backend

The backend is an explicit consumer of verified public core IR. It imports
[`../core/`](../core/README.md), never frontend syntax or elaboration, and owns
all CIRCT-specific opcode dispatch, type choices, SSA naming, and emission.

```text
RHDL hardware IR
    |
    v
CIRCT hw/comb/seq/sim MLIR
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
- `RecordType` lowers recursively to packed `hw.struct`, preserving field
  names and order.
- `VectorType` lowers recursively to `hw.array`.
- `Clock` and `Reset` lower to one-bit values in their control positions.
- Modules and instances use `hw`; combinational expressions use `comb` or
  `hw`; primitive registers use `seq`.
- Active-high synchronous reset remains explicit as `seq.firreg` with
  synchronous reset semantics.

Frontend-defined flat types need no backend special case. Equal lowered types
make representation casts aliases; other equal-width representations use
`hw.bitcast`. RHDL's current structural records therefore become anonymous
packed SystemVerilog structs. Preserving a source bundle name as a typedef
would additionally require a named type declaration to survive in the public
IR and lower through CIRCT type aliases.

## Operation lowering

| RHDL | CIRCT |
|---|---|
| `rtl.constant` | `hw.constant` |
| `rtl.not` | `comb.xor` with an all-ones constant |
| `rtl.and/or/xor` | `comb.and/or/xor` |
| `rtl.add/sub/mul` | `comb.add/sub/mul` |
| `rtl.shl/shru` | `comb.shl/shru` with lossless operand-width normalization |
| `rtl.eq/ult` | `comb.icmp eq/ult` |
| `rtl.mux_lookup` | comparisons plus a `comb.mux` tree |
| `rtl.cast` | alias or `hw.bitcast` |
| `rtl.concat` | `comb.concat` |
| `rtl.extract/trunc` | `comb.extract` |
| `rtl.zext` | zero constant plus `comb.concat` |
| `rtl.record_create/get` | `hw.struct_create/extract` |
| `rtl.vector_create/get` | `hw.array_create/get` |
| `rtl.memory` | `seq.hlmem` |
| `rtl.memory_read_async` | latency-zero `seq.read` |
| `rtl.memory_write` | latency-one `seq.write` |
| `rtl.wire` | alias to the wire's driver |
| `sim.dpi_call` | result-less clocked `sim.func.dpi.call` |
| `sim.dpi_register` | result-bearing clocked `sim.func.dpi.call` |

Shift operands require equal widths in CIRCT. A narrower amount is
zero-extended. For a wider amount, the value is widened, shifted, and truncated
back to its declared width. This preserves fixed-width overflow and overshift
semantics.

RHDL does not introduce pseudo-CIRCT operations when CIRCT's canonical form is
a composition. An unsupported verified type or operation produces a backend
error rather than leaking CIRCT decisions into core schemas.

## API and verification

[`circt.rhm`](circt.rhm) exports `emit_circt(design)`. Emission verifies the
completed design before lowering. Backend unit tests check textual lowering;
external integration tests parse and verify MLIR, export SystemVerilog, and
simulate selected designs with Verilator.

The test and golden-output workflow is documented in
[`../../tests/backend/README.md`](../../tests/backend/README.md).
