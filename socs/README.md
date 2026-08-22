<!-- Documents the complete FESVR-backed SimpleSoC composition and tests. -->

# Example systems

`simple-soc.rhdl` composes the repository's initial coherent system:

```text
SimpleSoC
├── FESVR RN-I (NodeID 1)
├── Ricket
│   ├── L1I RN-F (NodeID 2)
│   └── L1D RN-F (NodeID 3)
├── SimpleRouter × 4 (REQ, RSP, SNP, and DAT)
├── CHIHNF (NodeID 5)
├── CHITransferFragmenter
└── CHIRam SN-F (NodeID 9)
```

FESVR loads memory through its RN-I endpoint, then hands the widened entry point
directly to Ricket. The SoC exposes the `loaded`, `entry`, and `exit` signals
consumed by [`support/TestDriver.sv`](../support/TestDriver.sv).

The RN-I and two RN-F relationships reuse one physical single-router topology
but independently compile validation, route keys, buffering, and allocation for
the four CHI channel planes. REQ is 3-to-1, RSP and DAT are 4-to-4, and SNP is
1-to-2 because only the two RN-Fs receive snoops. Router arity therefore follows
the permitted protocol paths instead of an all-node cross product.

Ricket exposes ready-valid `CHIRNChannels` bundles directly at its hierarchy
boundary, so the SoC connects both cache endpoints to the NoC without creating
internal credited links. The serialized HN-F translates coherent Ricket traffic
and authoritative dirty snoop packets into non-coherent subordinate
transactions, and the fragmenter expands 64-byte cache-line reads into the
RAM's one-DAT-beat transactions.

The FESVR transport implementation remains owned by
[`fesvr/`](../fesvr/README.md); `simple-soc.rhdl` owns its use in this concrete
system. A reusable external RN-I boundary can be introduced when another system
actually requires one.

Run the focused elaboration test with:

```sh
make -C socs rtl-elaboration-test
```

The executable smoke additionally requires FESVR, CIRCT, Verilator, and an
RV32-capable `riscv64-unknown-elf-gcc`:

```sh
make -C socs e2e-test
```
