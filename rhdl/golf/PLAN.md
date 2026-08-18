<!-- Defines the planned #lang rhdl/golf syntax-compression profile over standard RHDL. -->

# RHDL Golf syntax-compression plan

## Status

`#lang rhdl/golf` has its first vertical slice: the profile re-exports standard
RHDL and implements `B(width)`, homogeneous `c A(w)[a,b->s:B(w)]` headers,
typed single-output `c` headers with ordinary or expression bodies, and
default `top`. The compact and canonical adders have focused public-IR and
CIRCT equivalence coverage plus compact-grammar diagnostics.

The remaining surface in this plan is not yet implemented. Golf's purpose is
source-level code golf: express hardware already supported by RHDL with fewer
tokens and characters while retaining the existing elaboration, verification,
public IR, backend, and standard-library semantics.

The first implementation is experimental. Its syntax may change while the
initial equivalence corpus is being built. The profile becomes stable only
after the complete initial surface and acceptance gates in this plan pass.

## Decision

Build Golf as a sibling language profile over the complete standard RHDL
frontend:

```text
#lang rhdl/golf -----> golf syntax ------------------+
          |                                           |
          +-------------> standard RHDL profile ------+
                                                      |
                                                      v
                                           existing elaboration kernel
                                                      |
                                                      v
                                                public core IR
                                                      |
                                                      v
                                             existing CIRCT backend
```

Golf is its own `#lang` because it coordinates declaration syntax, aliases,
and module-level conveniences. It is not a second hardware language: no Golf
construct survives elaboration, and no core or backend component knows whether
a design was authored with Golf.

Every binding exported by `#lang rhdl` is also exported by
`#lang rhdl/golf`. A standard RHDL program must continue to compile when only
its language line is changed to `#lang rhdl/golf`. Authors may mix Golf and
canonical RHDL forms in one module and fall back to the canonical form wherever
compression is unhelpful.

Golf does not live in `rhdl/std/`. The standard library remains opt-in hardware
vocabulary written against the public RHDL authoring surface. Golf programs
import and use those modules normally. Golf also does not live in
`rhdl/frontend/layers/`: it is a coordinated profile over several existing
layers, not an independently selectable hardware feature.

## Governing rule

Golf removes repeated spelling, not hardware facts.

A capability must exist in canonical RHDL before Golf can abbreviate it. If a
proposed Golf form reveals a missing type, operation, connection rule, state
primitive, interface contract, or diagnostic, implement and validate that
capability in its owning RHDL core, frontend layer, or standard-library module
first. Golf may then add a shallow expansion over the public form.

Golf must never be the only way to express supported hardware. It must not
repair, fork, or privately reimplement behavior owned elsewhere in RHDL.

## Goals

- Minimize source characters and tokens for small and medium RTL designs.
- Compress repeated circuit boundaries, type spellings, literal spellings,
  declaration keywords, and top elaboration.
- Preserve exact, statically known hardware types and deterministic
  elaboration.
- Preserve source locations and explain expansions in diagnostics.
- Compose with all ordinary Rhombus host computation, every standard RHDL
  frontend feature, and explicitly imported `rhdl/std` modules.
- Keep the compact surface small enough to memorize and regular enough that a
  reader can mechanically expand it into canonical RHDL.
- Measure compression on representative fixtures rather than admitting aliases
  solely because they are locally shorter.

## Semantic invariants

Golf retains the standard RHDL contract without exceptions:

- `Value` remains readable and `Place` remains driveable.
- Every place has one effective driver.
- Port and state types have positive, exact widths.
- Arithmetic retains the existing fixed-width or explicitly expanding
  behavior of the operator used.
- Host control and hardware control remain distinct. Golf does not rebind host
  `if`, `unless`, `cond`, `&&`, or `||` to hardware behavior; standard hardware
  `when`, `switch`, `&`, `|||`, and `^` remain available.
- State remains explicit. A compact register form still creates the same
  register, clock, reset, initialization, and next-state connection as the
  canonical `reg` form.
- `sc` uses exactly the ambient clock and synchronous-reset policy of
  `sync_circuit`; it does not infer a new clock domain.
- Hierarchy, generator freshness, ownership, interface roles, connection
  compatibility, assertion guards, memory collision behavior, DPI effects,
  and synthesis don't-cares retain their existing definitions.
- Golf expansion does not add modules, operations, ports, state, drivers,
  assertions, or effects beyond those in its documented canonical expansion.
- Core verification remains authoritative after expansion.

Two Golf sources that expand to the same canonical RHDL must produce the same
public IR. Source-origin descriptions may identify the compact form, but they
must not affect semantic equality or backend output.

## Initial syntax principles

The compact syntax is additive. It does not remove or reinterpret standard
forms. The initial surface favors a few regular families over unrelated
one-off abbreviations.

1. Short names abbreviate common, unambiguous nouns.
2. Structural syntax removes whole declarations or repeated boundary clauses
   before individual punctuation is optimized.
3. Port order and direction remain visible in the source.
4. Boundary types remain explicit.
5. A form with implicit output driving is allowed only when it names exactly
   one output and therefore has one possible destination.
6. Compact forms delegate type checking, ownership checking, and connection
   checking to their canonical forms.
7. Golf-specific validation is limited to the compact grammar itself, such as
   duplicate port names or an expression-bodied circuit with multiple outputs.

The spellings below are the provisional initial surface. Milestone 0 may alter
punctuation only when a Rhombus reader or macro constraint makes the proposed
grammar unavailable or destroys source/static information. Semantic expansion
rules may not be weakened to accommodate a spelling.

## Initial surface

### Type and literal aliases

The first aliases are:

| Golf | Canonical RHDL |
|---|---|
| `B(width)` | `Bits(width)` |
| `S(width)` | `SInt(width)` |
| `V(length, T)` | `Vec(length, T)` |
| `OH(width)` | `OneHot(width)` |
| `b(value, width)` | `bits(value, width)` |
| `si(value, width)` | `sint(value, width)` |

`Bool`, `Clock`, and `Reset` remain unchanged because aliases would save little
while occupying especially common names. Bundle, enum, interface, memory, and
extension-defined types retain their declared names and work wherever a Golf
type is accepted.

Aliases must preserve the canonical annotation and expression static
information. In particular, `B`, `S`, `V`, and `OH` values must retain field,
index, cast, literal, operator, and mux behavior without wrapper objects.

Golf v1 has no unsized hardware literal and no contextual integer conversion.
Widths remain explicit in `b` and `si`. A later contextual-literal proposal
requires a separate semantic decision covering expected-type propagation,
negative values, overflow, mixed-width operations, and diagnostics.

### Compact circuit headers

`c` abbreviates an ordinary `circuit`; `sc` abbreviates `sync_circuit`. The
generator parameters remain in parentheses. A bracketed port header places
inputs to the left of `->` and outputs to the right:

```rhombus
c Add(width)[a,b->sum:B(width)]=a+b
```

When every port has the same type, the final annotation applies to all names
on both sides of `->`. This homogeneous form factors repeated type text
without inferring or omitting the circuit boundary type.

```rhombus
#lang rhdl/golf

c Add(width)[a, b: B(width) -> sum: B(width)]:
  sum <== a + b

sc Accumulate(width)[enable: Bool; value: B(width) -> total: B(width)]:
  reg state(~init: b(0, width))
  when enable:
    state <== state + value
  total <== state
```

The canonical expansion is:

```rhombus
#lang rhdl

circuit Add(width):
  input(a, b): Bits(width)
  output sum: Bits(width)
  sum <== a + b

sync_circuit Accumulate(width):
  input enable: Bool
  input value: Bits(width)
  output total: Bits(width)
  reg state(~init: bits(0, width))
  when enable:
    state <== state + value
  total <== state
```

Header rules are:

- `;` separates adjacent groups with different types.
- A comma-separated name group shares one type.
- Each name appears exactly once across the complete port header.
- The declared order is the canonical port order.
- Either side of `->` may be empty, but `->` is always present.
- Types are ordinary RHDL annotations and may depend on generator parameters.
- Generator parameters retain every ordinary positional, keyword, annotation,
  and default form supported by `circuit` and `sync_circuit`.
- `sc` creates only the canonical ambient clock and reset ports supplied by
  `sync_circuit`; those implicit domain ports are not repeated in the header.
- Explicit `Clock` and `Reset` data ports remain legal in `c` and retain their
  standard meaning.
- Interfaces are not encoded in the arrow header in v1 because their direction
  is role-dependent and often bidirectional. Canonical `interface` declarations
  may appear in either compact circuit body.

The compact header macro must expand through the public `circuit`,
`sync_circuit`, `input`, and `output` forms rather than constructing kernel or
core objects directly.

### Single-output expression circuits

An ordinary `c` with exactly one output may use an expression body:

```rhombus
c Invert(width)[value: B(width) -> result: B(width)] = !value
```

It expands to:

```rhombus
circuit Invert(width):
  input value: Bits(width)
  output result: Bits(width)
  result <== !value
```

The expression is evaluated exactly once while elaborating the circuit. The
form rejects zero or multiple outputs. `sc` does not initially support an
expression body because a sequential circuit whose result is purely an
expression gains little compression and could misleadingly imply state.

Golf v1 does not positionally drive multiple outputs. Such a form would hide
the output-to-expression association and would require a new product-value
policy. Multiple-output circuits use an ordinary body with explicit drives.

### Compact top elaboration

`top` creates a design binding:

```rhombus
top Add(8)
top alu = ALU(8)
```

The first form expands to:

```rhombus
def design = elaborate(Add(8))
```

The named form expands to:

```rhombus
def alu = elaborate(ALU(8))
```

The top expression is evaluated exactly once. Repeating `top` with the same
binding name is an error through ordinary Rhombus binding rules. `top` does not
guess the last declared circuit, emit CIRCT, generate Verilog, or invoke an
external tool.

Exports remain explicit. Elaborating a top does not silently change the
module's public API; a module that exposes the generated design writes an
ordinary `export` declaration.

`elaborate_with_top` remains explicit in v1. A compact physical-annotation or
inspection form should be added only if repeated use demonstrates enough
source savings to justify another top-level spelling.

### Declaration aliases

After the profile, type/literal aliases, compact headers, and `top` are working,
Golf adds the following direct declaration aliases:

| Golf | Canonical RHDL |
|---|---|
| `r name(arguments...)` | `reg name(arguments...)` |
| `w name: T` | `wire name: T` |
| `m name(depth, T)` | `mem name(depth, T)` |
| `x name(arguments...)` | `inst name(arguments...)` |

These are token-for-token aliases. They accept exactly the canonical argument
grammar, return the same statically informed binding, and introduce no
defaults. `r` therefore inherits type inference from `~next` or `~init`, but it
does not add new inference. `x` inherits ordinary sync-domain propagation and
explicit overrides. Expression-position `x` must retain the canonical
instance-port static information used by reducers and arrays.

The canonical `<==`, `<=>`, and `|>` operators remain unchanged. They are
already compact and, more importantly, visibly distinguish a drive, an
interface connection, and topology application. Golf does not replace them
with host assignment or a generic arrow.

### Standard forms inside Golf

All other RHDL forms remain available without wrappers, including:

- `bundle`, `enum`, `one_hot_enum`, records, vectors, and casts;
- `when`, `switch`, `mux`, `mux_lookup`, and decode relations;
- interfaces, roles, refinements, endpoint arrays, handles, and sinks;
- registers, wires, memories, synchronous memories, assertions, and DPI;
- nested generators, instance arrays, host loops, functions, and reducers;
- signed and expanding arithmetic; and
- explicit `elaborate` and `elaborate_with_top`.

Golf should not mechanically create one-letter aliases for the entire
language. Additional shorthand is admitted only through the feature criteria
below.

## Standard-library composition

Golf builds on standard-library components by importing them, not by copying
or wrapping them:

```rhombus
#lang rhdl/golf

import:
  lib("rhdl/std/flow.rhdl") open

sc Delay(T, stages :: PosInt)[->]:
  interface ingress(Valid(T), ~role: consumer)
  interface egress(Valid(T), ~role: producer)
  (ingress |> valid_pipe(stages)) <=> egress
```

The complete `rhdl/std` tree is not opened automatically. Its modules are
optional, domain-sized namespaces; opening all of them would increase load
time, create collisions, and erase useful dependency information. Existing
facades such as `rhdl/std/flow.rhdl` remain the import granularity.

A future short import form may abbreviate common library paths, but it must
still declare each dependency in source and expand to an ordinary import. Do
not create separate `rhdl/golf/flow`, `rhdl/golf/memory`, or protocol-specific
language dialects.

Golf syntax must work with types and values supplied by imported libraries.
For example, compact circuit headers accept `Valid(T)` and `SimpleMemory(...)`
where their canonical declarations accept them. This follows from preserving
normal annotation/static information rather than adding Golf-specific cases.

## Feature admission criteria

After v1, a proposed shorthand is accepted only when all of the following are
true:

1. The canonical feature is already implemented, documented, and tested in its
   owning RHDL package.
2. The shorthand has one deterministic canonical expansion.
3. The expansion requires no new core operation, verifier rule, backend case,
   or private standard-library dependency.
4. It reduces non-comment source bytes or tokens in at least two representative
   corpus fixtures, or removes one repeated structural clause in a way that is
   plainly general.
5. It does not hide a width, port direction, state element, clock/reset domain,
   connection destination, priority rule, protocol conversion, or generated
   module boundary.
6. It preserves all required static information and source locations.
7. Valid, invalid, standard-compatibility, and equivalence coverage can state
   its complete contract.
8. Its name belongs to an existing syntax family or justifies creating one.

Character savings alone do not justify semantic inference. Conversely, an
alias need not make canonical RHDL more readable: the explicit purpose of this
profile is brevity, and its separate `#lang` advertises that tradeoff.

## Compression corpus and measurement

The initial corpus pairs canonical and Golf versions of these designs:

1. A single-output combinational adder.
2. A multi-output ALU with Boolean and lookup operations.
3. A synchronous counter with reset initialization and guarded update.
4. A hierarchical ripple or generated adder with child instances.
5. A bundle/vector datapath using aggregate construction and selection.
6. An asynchronous or synchronous memory wrapper.
7. A `Valid` or ready-valid pipeline importing `rhdl/std/flow.rhdl`.

Measure only author-owned RHDL source needed to define and elaborate the
design. Exclude comments, embedded Verilog references, test assertions, and
documentation. Record:

- UTF-8 source bytes excluding whitespace and comments;
- lexical token count;
- physical source lines as a secondary readability signal; and
- the expanded canonical forms used for semantic review.

The v1 profile must reduce aggregate non-whitespace source bytes and tokens
relative to the canonical corpus. Each structural feature must show its own
delta. There is no fixed percentage gate initially: corpus results should
identify which forms earn permanence and which aliases merely pollute the
namespace.

The metric is not a synthesis metric. Module count, operation count, state
count, CIRCT, and generated Verilog must remain equivalent rather than become
smaller.

## Diagnostics and source provenance

Golf macros own only grammar-level diagnostics:

- malformed or missing `->` in a compact header;
- missing type after a port group;
- duplicate port names;
- an expression body without exactly one output;
- unsupported compact interface syntax; and
- malformed `top` binding syntax.

All hardware diagnostics should come from the canonical forms after expansion.
That includes invalid widths, bad operands, cross-design values, multiple or
missing drivers, illegal clock/reset combinations, unsupported interface
connections, hierarchy cycles, combinational cycles, and backend-independent
verification failures.

Expansion must retain source spans so a diagnostic points to the Golf token or
expression that caused it. Tests should reject implementation-module names,
generated identifiers, or raw kernel vocabulary in user-facing messages when
the corresponding Golf source location is available.

Each documented compact form includes its canonical expansion. A future
expansion-inspection tool may print canonical RHDL for teaching and debugging,
but v1 does not require a reversible formatter or source-to-source compiler.

## Package boundary

The intended implementation shape is:

```text
rhdl/
  golf/
    PLAN.md
    main.rkt
    language.rhm
    surface.rhm
    lang/
      reader.rkt
examples/
  golf/
    adder.rhdl
    alu.rhdl
    counter.rhdl
    hierarchy.rhdl
    aggregate.rhdl
    memory.rhdl
    valid-pipe.rhdl
tests/
  frontend/
    golf-test.rhm
    golf-equivalence-test.rhm
    golf-standard-compatibility.rhdl
    invalid/
      golf-*.rhdl
  backend/
    golf-equivalence-test.rhm
```

Responsibilities are:

- `main.rkt` and `lang/reader.rkt` are reader shims only.
- `language.rhm` aggregates ordinary Rhombus, the standard RHDL frontend, and
  `surface.rhm`; it defines no feature behavior.
- `surface.rhm` implements compact macros and aliases by expanding to bindings
  from the standard frontend profile. It may reuse the shared
  `GeneratorParameter` syntax class to preserve the canonical circuit-parameter
  grammar without reimplementing it.
- Golf modules do not import `rhdl/core`, `rhdl/backend`, CIRCT, RFPL, domain
  libraries, or optional `rhdl/std` modules.
- Core, frontend layers, standard-library modules, backends, and domain
  libraries do not import Golf.

`tools/check-boundaries.sh` must enforce those directions, allow only the two
new `.rkt` reader shims, and keep the Golf language aggregator behavior-free.
The package graph and responsibility table in `rhdl/README.md` must add the
profile when implementation begins.

## Verification strategy

### Standard-surface compatibility

A fixture using `#lang rhdl/golf` but no Golf-specific forms must exercise a
representative standard program. Its bindings, static information, IR, and
diagnostics must match the same source under `#lang rhdl`. This prevents the
profile from accidentally omitting or shadowing standard exports.

Imports from at least `rhdl/std/flow.rhdl` and one typed decode or memory module
must compile under Golf without adapters.

### Frontend equivalence

For every corpus pair:

- call `verify_design` on both designs;
- compare `dump_ir` output;
- compare module, port, and operation counts;
- compare module names and ordered port names/types;
- compare operation opcodes, result types, attributes, and connection
  structure; and
- allow only documented source-origin text differences.

Tests should compare semantic structure rather than generated temporary names
when a canonical form already permits harmless naming differences.

### Backend equivalence

Emit CIRCT for every canonical/Golf pair and require exact equality. At least
one combinational, one sequential, one hierarchical, one aggregate, one
memory, and one standard-library fixture must be covered.

Golf needs no dedicated lowering or Verilator harness. Existing backend and
behavioral tests remain authoritative for the features being abbreviated.
Add behavioral coverage only if an expansion exposes a behavior not already
covered by the canonical feature, which would normally indicate that the
canonical feature owns a missing test.

### Invalid programs

Negative fixtures cover each Golf-owned grammar rule and selected canonical
errors reached through Golf expansion. Do not add tests asserting that deferred
or unimplemented shorthand is absent. Test invalid uses only for supported
forms.

### Focused commands

Implementation batches use one newly created `PLTCOMPILEDROOTS` directory with
no trailing path-list separator. Direct `racket` commands use `-y`.

The intended focused targets are:

```sh
make check-boundaries
make golf-test
make examples-golf
```

`golf-test` should run Golf frontend tests, negative fixtures, and frontend and
backend equivalence without selecting unrelated frontend tests. Add Golf tests
to the existing broader `frontend-test`, `backend-test`, `unit-test`, examples,
and host-test dependency structure through their normal wildcards or explicit
variables.

Run the full test suite only when implementation changes shared reader,
frontend, test, build, or backend infrastructure beyond Golf's isolated
profile.

## Documentation ownership

- This file owns the decision, syntax roadmap, milestones, and deferred work.
- `README.md` owns the implemented Golf quick start, current syntax, semantic
  contract, and user-facing limitations.
- `rhdl/README.md` owns the implemented package/profile graph and dependency
  contract.
- `rhdl/frontend/README.md` owns how Golf relates to standard and base profiles
  once the profile exists.
- `examples/README.md` owns the executable Golf example catalog and compression
  comparison.
- `tests/README.md` owns the `golf-test` and `examples-golf` workflows.
- The root `README.md` receives only a concise link after Golf becomes a stable
  user-facing profile.

Do not duplicate the complete alias or grammar catalog across those documents;
link back to the nearest owning description.

## Milestones

### Milestone 0: corpus and parser feasibility

- Freeze canonical versions of the seven compression fixtures.
- Record baseline bytes, tokens, lines, IR, and CIRCT.
- Prototype the `c`/`sc` bracketed header and expression-body grammar against
  the Rhombus reader and macro system.
- Verify that aliases preserve annotation, dot-provider, indexing, reducer,
  and instance-port static information.
- Resolve only syntactic feasibility questions before committing the public
  spellings.

Exit gate: every proposed v1 form has a valid Rhombus parse, a deterministic
canonical expansion, and a measured corpus use.

### Milestone 1: profile shell

- Add the nested reader shims and Golf language aggregator.
- Re-export the complete standard RHDL surface.
- Add standard-only and standard-library compatibility fixtures.
- Extend boundary tooling and architecture documentation.

Exit gate: changing only `#lang rhdl` to `#lang rhdl/golf` preserves the
representative standard fixture's IR and CIRCT.

### Milestone 2: types, literals, and top

- Implement `B`, `S`, `V`, `OH`, `b`, and `si` as transparent aliases.
- Implement default and named `top` forms with exactly-once elaboration.
- Add static-information, binding, valid, invalid, and equivalence
  tests.

Exit gate: aliases behave identically in annotations, operations, fields,
indices, casts, muxes, and connections; `top` produces exactly the canonical
design binding.

### Milestone 3: compact circuit boundaries

- Implement `c` and `sc` with grouped typed port headers.
- Implement the single-output expression body for `c`.
- Preserve generator parameter grammar and ambient sync behavior.
- Add header diagnostics and source-location tests.

Exit gate: combinational, sequential, aggregate, and parameterized fixtures
have equal IR and CIRCT to their canonical versions.

### Milestone 4: declaration aliases

- Implement `r`, `w`, `m`, and `x` as exact canonical aliases.
- Verify inferred register types, reset initialization, memory access, instance
  port access, expression-position instances, arrays, and sync propagation.
- Remove any alias whose static-information behavior or corpus value is weak.

Exit gate: hierarchy, memory, and state fixtures retain canonical static
information and exact backend output.

### Milestone 5: integrated corpus and documentation

- Complete all seven Golf examples and paired equivalence tests.
- Publish compression measurements and canonical expansions.
- Add focused Makefile targets and test documentation.
- Run the focused Golf, boundary, example, and affected frontend/backend tests.
- Review namespace collisions and remove unearned aliases before stability.

Exit gate: all v1 acceptance criteria pass and the profile can be marked
stable.

### Milestone 6: evidence-driven extensions

- Collect real Golf designs beyond the seed corpus.
- Rank repeated syntax by total byte/token cost.
- Consider compact interfaces, instance connection maps, and import-path
  abbreviations under the feature admission criteria.
- Route every newly discovered semantic need to canonical RHDL first.

There is no requirement to grow the surface after v1. A small closed shorthand
set is preferable to comprehensive duplicate syntax.

## V1 acceptance criteria

Golf v1 is complete when:

- `#lang rhdl/golf` re-exports all standard RHDL authoring bindings.
- Standard-only RHDL and selected `rhdl/std` imports work unchanged.
- Every initial Golf form has a documented canonical expansion.
- All Golf-owned grammar errors have focused negative tests and source-facing
  diagnostics.
- The seven canonical/Golf corpus pairs have equivalent verified public IR.
- The same pairs emit identical CIRCT.
- Aggregate corpus bytes and tokens are lower than canonical RHDL.
- No Golf module imports core, backend, CIRCT, RFPL, domain packages, or
  optional standard-library modules.
- No core, standard frontend layer, backend, standard-library module, or domain
  package imports Golf.
- Boundary checks, focused Golf tests, Golf examples, and affected existing
  profile-equivalence tests pass with fresh compiled roots.
- Documentation describes Golf as compact syntax over standard RHDL, not a new
  semantic or backend language.

## Deferred questions

These require corpus evidence and separate decisions after v1:

- Contextual hardware integer literals and expected-width propagation.
- A compact interface declaration that keeps role and direction visible.
- Named or positional instance connection maps.
- A short form for `elaborate_with_top`.
- Short standard-library import paths.
- Compact multiple-output expression circuits with an explicit association.
- Source-to-source expansion display or a Golf-aware formatter.
- Whether stabilized Golf source should use `.rhdl` exclusively or gain an
  editor-facing filename convention while retaining the same reader.

## Non-goals

Golf v1 does not include:

- new core types, operations, IR nodes, verifier rules, or backend lowering;
- implicit port or result-width inference;
- unsized hardware literals or implicit conversions;
- implicit truncation, extension, signedness changes, or priority;
- last-connect semantics or relaxed one-driver verification;
- inferred ports from name use in a circuit body;
- automatic registers, pipelines, memories, interfaces, handshakes, or clock
  domain crossings;
- a clock/reset policy beyond canonical `sync_circuit` behavior;
- implicit top selection from declaration or source order;
- automatic import of all `rhdl/std` modules;
- domain-specific Golf dialects;
- a second elaborator, IR, CIRCT path, Verilog emitter, simulator, or synthesis
  optimizer; or
- shorter generated Verilog as a success metric.

## Risks and mitigations

- **Namespace pollution:** Keep the initial alias set closed, measure each
  alias, exercise ordinary Rhombus bindings under Golf, and remove aliases that
  cause disproportionate collisions.
- **Static-information loss:** Expand directly to canonical forms and test dot,
  indexing, annotation, reducer, instance-port, and interface behavior before
  retaining a wrapper.
- **Misleading compression:** Keep widths, directions, state, domains, and
  connection destinations visible; defer contextual inference.
- **Profile drift:** Re-export one standard aggregator, include a standard-only
  compatibility fixture, and make missing standard exports a test failure.
- **Duplicate implementation:** Reject Golf features that need direct kernel or
  core access; move any required capability to its canonical owner.
- **Poor diagnostics:** Preserve syntax spans, validate compact grammar early,
  and delegate hardware errors to existing canonical checks.
- **Dialect proliferation:** Maintain one Golf profile and ordinary explicit
  imports instead of protocol- or domain-specific Golf languages.
- **Stale Rhombus bytecode:** Run every implementation and validation batch
  with a fresh `PLTCOMPILEDROOTS` and direct `racket -y` invocations.
