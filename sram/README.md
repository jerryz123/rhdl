<!-- Defines the reusable CIRCT-boundary SRAM mapping package and its contracts. -->

# SRAM mapping

This package maps selected synchronous memories after RHDL has emitted CIRCT
HW/Seq MLIR. RHDL, processor cores, and SoCs remain technology-independent:
they expose ordinary synchronous memories and do not name physical macros.

```text
RHDL HW/Seq MLIR
  -> select and flatten an elaboration top
  -> lower seq.firmem to FIRRTLMem instances
  -> scope instance paths to a logical design top
  -> apply a site policy
       selected site -> exact-name hw.module.extern
       unselected site -> CIRCT inferred memory
  -> emit adapter RTL and a physical-handoff manifest
```

`circt/MemorySitePass.cpp` owns occurrence discovery and policy application.
`map-memories.py` validates the logical memory contract, chooses the requested
catalog entry, tiles depth and width, and emits SystemVerilog adapters. The
generic package knows macro interface names but no foundry macro names or PDK
paths. Technology catalogs, models, and collateral descriptions live in
technology subdirectories such as [`sky130/`](sky130/README.md).

## Policy and scope

A policy is relative to one logical design top. Its default must be `infer`,
and every explicitly named path must exist in the selected scope:

```yaml
# Maps one logical site while leaving every unlisted site inferred.
schema_version: 1
top: SimpleSoC
default: infer
sites:
  ram/storage/storage: sky130_sram_2kbyte_1rw1r_32x512_8
```

By default `rhdl-map-memory-sites` uses `policy.top` as the actual elaboration
top. `top=<module>` overrides that top and `scope-prefix=<path>` strips a
flattened instance prefix before policy lookup. Thus the same SimpleSoC-relative
policy applies directly to `SimpleSoC` and to `SoCHarness` with
`top=SoCHarness scope-prefix=soc`. Wrapper names derive from the policy-relative
path, so both contexts instantiate identical adapters.

The inventory records the actual top, logical policy top, scope prefix,
policy-relative path, and actual flattened instance path. Unknown policy paths,
duplicate scoped paths, unknown macros, unsupported interfaces, and incompatible
write masks are hard errors.

## Logical and macro contracts

The current logical contract is deliberately narrow: exactly one synchronous
read/write port, one-cycle reads and writes, no initialization, and optional
uniform write masking. A physical macro must have a write granularity no
coarser than the logical mask.

The first adapter interface is `openram_1rw1r`: one byte-maskable read/write
port plus one unused read-only port. The interface name makes the hardcoded pin
adapter explicit; another macro pin convention requires a new generic adapter,
not foundry conditionals in the mapper.

## Tests and consumers

Run synthetic banking, width-slicing, masking, scoped-selection, stable-wrapper,
and invalid-contract tests with:

```sh
make -C sram test
```

Physical-flow policy belongs to the design and technology combination, for
example `vlsi/designs/simple-soc/sky130/sram-map.yaml`. The same policy is
consumed by `make -C vlsi simple-soc-memory-map` and by the mapped simulator in
`vlsi/sim/`. Generated mapper artifacts stay outside version control.
