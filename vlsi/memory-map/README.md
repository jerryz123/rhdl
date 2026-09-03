<!-- Defines the contract and limitations of the CIRCT-boundary SRAM mapping prototype. -->

# CIRCT SRAM mapping prototype

This flow maps memories by their occurrence beneath one selected hardware top;
RHDL and its memory IR remain technology-independent. A loadable CIRCT pass
prepares the hierarchy, preserves canonical instance paths, and retargets only
policy-selected `FIRRTLMem` instances to external wrapper modules.

```text
RHDL HW/Seq MLIR
  -> select one public top and flatten its reachable hierarchy
  -> lower seq.firmem to FIRRTLMem instances
  -> apply the YAML occurrence policy
       selected site -> site-specific hw.module.extern
       unselected site -> CIRCT inferred-memory implementation
  -> export SystemVerilog plus selected SRAM wrappers
```

`map-memories.py` consumes the transformed MLIR and JSON site inventory. It
checks each selected site's logical port and latency contract, uses its requested
macro from `sky130-sram.ini`, and emits two artifacts:

- SystemVerilog modules with the exact names CIRCT instantiates. Each module
  adapts the logical address, data, and mask ports to a rectangular array of
  physical SRAM instances.
- A JSON handoff manifest with tiling, area, utilization, instance names,
  collateral paths, power pins, and the remaining floorplan/PDN/LVS duties.

The macro contract is deliberately narrow: one synchronous read/write port,
one-cycle reads and writes, no initialization, and a physical macro whose write
granularity is no coarser than the logical mask. The installed
`sky130_sram_2kbyte_1rw1r_32x512_8` macro supplies a 512 by 32-bit byte-write
port; its second read-only port is tied off.

The policy uses full instance paths without CIRCT's generated `_ext` suffix.
Its default must be `infer`; an explicit value is either `infer` or a macro name
from the catalog. Unknown paths, duplicate paths after flattening, unknown
macros, and incompatible masks are errors. For example:

```yaml
# Maps one site while leaving every unlisted memory inferred.
schema_version: 1
top: SimpleSoC
default: infer
sites:
  ram/storage/storage: sky130_sram_2kbyte_1rw1r_32x512_8
```

The pass is compiled against the same pinned CIRCT package that supplies
`circt-opt`; its installed CMake configuration and shared libraries are used
directly. Set `CIRCT_ROOT` when `CIRCT_OPT` is not beneath that installation.

Run the synthetic banking, width-slicing, byte-mask, site-selection, and
rejection checks with:

```sh
make -C vlsi memory-map-test
```

Run the mapper against the current SimpleSoC and lint CIRCT's mixed
macro/inferred RTL against the generated wrappers and installed Sky130
behavioral model with:

```sh
make -C vlsi simple-soc-memory-map
make -C vlsi simple-soc-macro-rtl-check
```

Generated files are placed under `vlsi/build/simple-soc/`.

At the current SimpleSoC revision, the checked-in policy records all seven
logical sites and maps only the naturally sized shared RAM:

| Site | Logical shape | Decision | Physical macros |
| --- | ---: | --- | ---: |
| `ram/storage/storage` | 4096 x 128 | Sky130 SRAM | 32 |
| `rv5stage/l1i/tags/storage` | 64 x 52 | inferred | 0 |
| `rv5stage/l1i/states/storage` | 64 x 2 | inferred | 0 |
| `rv5stage/l1i/lines/storage` | 64 x 512 | inferred | 0 |
| `rv5stage/l1d/tags/storage` | 64 x 52 | inferred | 0 |
| `rv5stage/l1d/states/storage` | 64 x 3 | inferred | 0 |
| `rv5stage/l1d/lines/storage` | 64 x 512 | inferred | 0 |

The result is 32 physical SRAM instances, 100% bit utilization, and 9.105 mm2
of raw macro area before placement halos. The six shallow cache arrays remain
available to synthesis instead of consuming badly underutilized 512-row macros.
The generated manifest reports top-reachable sites and their individual
decisions rather than totals per unique generated definition.

The current implementation deliberately flattens the selected top. CIRCT keeps
the original path in each flattened instance name, so policy identity and
physical handoff remain stable, but the exported logic hierarchy is flat. A
larger replicated-core flow can later replace this step with selective module
cloning while keeping the policy, extern-wrapper, and manifest contracts.
