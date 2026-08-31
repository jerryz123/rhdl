<!-- Defines RV5Stage's Sv39 MMU ownership, ordering, and first-cut feature contract. -->

# RV5Stage MMU

`RV5StageMmu` sits between `RV5StageCore`'s virtual instruction/data access ports
and the physical L1 cache ports. `RV5StageTlb` is a reusable fully associative
translation cache, and `RV5StagePageTableWalker` is a serialized Sv39 walker
whose PTE-memory protocol is independent of L1D. The composition module owns
arbitration onto L1D, response ownership, TLB refill, and fault correlation.

Instruction requests record whether their ordered response comes from L1I or
from a local page fault. Data requests remain held in Execute until a TLB hit
or completed walk determines either a physical request or a page fault, so a
faulting store cannot retire. The shared walk can claim a miss immediately,
but its PTE read begins only after two consecutive quiescent L1D observations;
it then owns that port until the load returns.

The first implementation uses eight entries per TLB, ASID zero, complete
`SFENCE.VMA` invalidation, a single outstanding walk, and Svade fault behavior.
Leaf permissions stay in the TLB and are re-evaluated against current
privilege, `SUM`, and `MXR`. See the parent [RV5Stage contract](../README.md) for
implemented page sizes and deliberately deferred privileged features.
