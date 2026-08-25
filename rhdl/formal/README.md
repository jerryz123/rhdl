<!-- Documents the optional Rosette formal engine, its supported semantics, API, and focused validation. -->

# RHDL formal engine

The formal engine is an optional consumer of verified public RHDL IR. It uses
Rosette fixed-width bitvectors to prove deterministic combinational behavioral
equivalence, produce concrete counterexamples, and find packed top-output
reachability witnesses or prove universal packed top-output properties. It does
not participate in elaboration and is not imported by `#lang rhdl`.

The architectural plan and staged semantic scope are in [`PLAN.md`](PLAN.md).

## Setup

Install Rosette into the active Racket installation:

```sh
raco pkg install --auto rosette
```

The milestone-1 implementation is validated with Racket 9.2, Rosette 4.0,
and Rosette's pinned Z3 4.8.8 binary. Rosette declares Racket 8.1 or newer;
other compatible Racket releases have not yet been exercised by this target.
A clean catalog installation was validated from an empty `PLTUSERHOME` with
Rosette checksum `373c8c35e4a7667f38fce10cf0b74ae17de07f1d` and its transitive
`rfc6455` checksum `e3a87e914e25841a6e1bb996aa001aeb178284bf`. The earlier
`rfc6455` resolution failure was caused by a restricted test environment, not
an unavailable package source; the repository does not vendor either package.

Ordinary RHDL host and backend targets do not require Rosette. The focused
formal suite probes both Rosette and its solver under an isolated compiled
root before running the RHDL proofs:

```sh
make formal-test
```

Run the independent backend differential check when CIRCT and Verilator are
available:

```sh
make formal-differential-test
```

That target proves structurally different shift, aggregate, hierarchical,
fully cared decode, and assumption-constrained one-hot implementations
equivalent, obtains live counterexamples for defects in each category, finds a
live assumption-constrained reachability witness, proves a constrained output
property, obtains a live violating property counterexample, and passes those
exact packed inputs and outputs to a shared CIRCT-generated Verilator DUT. The
testbench also exhaustively checks all 128 reduced-width
unequal-shift inputs, 80 aggregate layouts and projections, 256 hierarchical
arithmetic inputs, eight decode selectors, and 12,288 valid one-hot selections
against independent SystemVerilog oracles.
Set `CIRCT_OPT=/path/to/circt-opt` when the pinned tool is not installed under
the current checkout's `.tools/` directory.

## Formal API

Import `rhdl/formal/main.rhm` explicitly and call `check_equivalent` with two
verified `DesignElaboration` values or two completed core `Module` values.
Both top interfaces must have exactly the same port names and mutually equal
RHDL types.

Stage 2 adds an optional third `FormalQuery` argument containing a conjunction
of packed-pattern and one-hot assumptions:

```rhombus
def query:
  FormalQuery([FormalInputAssumption("mode", 0b0000),
               FormalInputAssumption("tag", 0b1000, 0b1100),
               FormalOneHotAssumption("grant")])
def result = check_equivalent(reference, candidate, query)
```

Omitting `care` requires exact equality. Supplying `care` constrains only cared
bits and requires `value & care == value`; the example accepts any `tag` whose
two high bits are `10`. Assumptions name top inputs and use their canonical
packed widths, including aggregate inputs. No symbolic Rosette or live RHDL
object crosses the query boundary.

`FormalOneHotAssumption` constrains its named packed top input to have exactly
one set bit. For every reachable `rtl.onehot_mux`, including operations below
instances or fed by derived values, the engine separately proves that the
query assumptions imply exactly-one validity. A missing or insufficient proof
returns `unsupported` with the operation path; only a proved-valid selector is
interpreted by direct choice gating and OR reduction. Contradictory assumptions
still return `vacuous` before any operation-validity claim.

`check_reachable` asks whether one named top output can match a canonical
packed pattern:

```rhombus
def result:
  check_reachable(candidate,
                  FormalOutputPattern("response", 0b1000, 0b1100),
                  query)
```

Omitting the target `care` mask requires the complete output value. With a
mask, only cared bits participate; the example seeks any `response` whose two
high bits are `10`. A `reachable` result contains every top input assignment
and the complete concrete output value, replayed through the interpreter before
it is returned. `unreachable` means no input satisfying the assumptions reaches
the target. The other statuses retain the same `vacuous`, `unsupported`, and
`unknown` meanings as equivalence queries.

`check_output_property` asks whether one named top output always matches a
canonical packed pattern under the query assumptions:

```rhombus
def result:
  check_output_property(candidate,
                        FormalOutputPattern("response", 0b1000, 0b1100),
                        query)
```

A `proved` result means every input satisfying the assumptions makes the cared
output bits match the target. A `counterexample` contains every top input
assignment and the complete violating output value, replayed concretely before
it is returned. The query uses the same masks, explicit assumptions, vacuity
classification, partial-operation validity obligations, and `unsupported` or
`unknown` outcomes as reachability. This is a universal combinational query;
it does not reinterpret the clocked `verif.assert` operation.

The result status is one of `equivalent`, `counterexample`, `vacuous`,
`unsupported`, or `unknown`. `vacuous` means the assumptions are mutually
unsatisfiable, so the engine does not claim equivalence. A counterexample
contains every top input assignment, every differing output, and retains the
query assumptions that constrained it. An unsupported result identifies the
first reachable operation outside the deterministic combinational contract.

Equivalence is behavioral: two designs may have different module structure,
operation order, names below the top interface, or printed IR and still prove
equivalent. The checker is not a textual or structural diff.

## Supported semantics

All packable values use the canonical RHDL packed layout. The milestone-1a
operation contract is explicit:

| Category | Supported operations |
| --- | --- |
| Structure | `rtl.input_port`, `rtl.output_port`, `rtl.wire`, `rtl.drive`, `rtl.instance` |
| Constants and bitwise | `rtl.constant`, `rtl.not`, `rtl.and`, `rtl.or`, `rtl.xor` |
| Modular arithmetic | `rtl.add`, `rtl.mul`, `rtl.sub` |
| Shifts | `rtl.shl`, `rtl.shru`, `rtl.shrs`, including unequal operand widths and overshifts |
| Comparisons | `rtl.eq`, `rtl.ult`, `rtl.slt` |
| Selection | total `rtl.mux_lookup`; non-overlapping `rtl.decode` with every output bit cared in every case and the default; `rtl.onehot_mux` when query assumptions prove its selector exactly one-hot |
| Packing and widths | `rtl.cast`, `rtl.concat`, `rtl.extract`, `rtl.zext`, `rtl.sext`, `rtl.trunc` |
| Aggregates | `rtl.record_create`, `rtl.record_get`, `rtl.vector_create`, `rtl.vector_get` |

The engine returns `unsupported` for `rtl.dont_care`, any `rtl.decode` with an
uncared output bit, registers, every memory form, assertions, DPI operations,
unknown operations, and any `rtl.onehot_mux` whose exactly-one precondition is
not implied by the query. Structural semantic exclusions fail during
preflight; one-hot validity fails before the requested output query. The engine
does not invent values or assumptions for unspecified behavior.

Counterexample input values and differing output values are nonnegative packed
integers. Inputs omitted from a partial solver model are completed with zero,
then both designs are interpreted concretely so every reported difference is
replayable. Reachability witnesses use the same completion and concrete replay
rule, as do violating output-property counterexamples.
