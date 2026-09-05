<!-- Guides the use and maintenance of the repository's dependency-neutral Rhombus refinements. -->

# Shared Rhombus refinements

`support/` is a repository-level leaf package for small host-value refinements
that unrelated packages can import without acquiring Rhodium, protocol, ISA,
or implementation dependencies. Its public module,
[`annotations.rhm`](annotations.rhm), imports only Rhombus macro and regular-
expression libraries. The authoritative repository package boundary is in
[`rhodium/README.md`](../rhodium/README.md#package-responsibilities).

This directory is not [`rhodium/frontend/support/`](../rhodium/frontend/support/).
That directory implements shared frontend macro and static-information
mechanisms and may depend on the frontend kernel, core APIs, and analyses.

## Decide where a refinement belongs

Put a refinement here when it expresses a context-free constraint on an
ordinary host value, has vocabulary useful outside one domain, and can remain
implemented entirely with Rhombus. A caller should be able to adopt it without
depending on the package that first needed it.

Otherwise, keep the rule with its semantic owner. For example, power-of-two
integers belong with the bit utilities in
[`rhodium/std/bits.rhdl`](../rhodium/std/bits.rhdl), while CHI field-width rules
belong in [`chi/params.rhdl`](../chi/params.rhdl). Use built-in annotations such
as `NonemptyList.of(T)`, `Nat`, and `PosInt` directly instead of adding aliases
here. Relationships among values, uniqueness, ownership, reserved names,
protocol legality, and IR validity remain explicit checks in the package that
owns those semantics.

## Public annotations

| Annotation | Accepted value | Current consumers |
| --- | --- | --- |
| `NonemptyString` | Any `String` with at least one character; it does not imply identifier syntax | NoC symbolic names and routing policy; RISC-V fields, formats, instruction catalogs, and ISA helpers; CHI, device, and SoC parameter names |
| `AsciiIdentifier` | A `String` matching `[A-Za-z_][A-Za-z0-9_]*` | Rhodium core and frontend APIs that name modules, ports, fields, values, memories, instances, registers, and related generated hardware |

Both are annotation macros, so use them directly at an API boundary:

```rhombus
fun named_region(name :: NonemptyString):
  // ...
```

Choose `AsciiIdentifier` only when downstream hardware or generated-symbol
syntax requires that narrower spelling. Choose `NonemptyString` when punctuation
or other nonempty text remains meaningful to the owning domain.

## Boundaries and non-goals

- Keep this package below its consumers: it must not import Rhodium, NoC,
  RISC-V, CHI, devices, SoCs, backends, or tool integrations.
- Keep hardware types, elaboration, static information, IR checks, and backend
  behavior out of this directory.
- Do not turn this module into an aggregate for built-in annotations or
  domain-specific validation helpers.
- Centralize predicate edge cases in the direct annotation test; consumer
  suites need only assert enforcement where it is part of their public API.

## Implementation map

| Path | Role |
| --- | --- |
| [`annotations.rhm`](annotations.rhm) | Public exports plus the private predicates and ASCII identifier pattern that implement them |
| [`tests/annotations-test.rhm`](tests/annotations-test.rhm) | Direct acceptance and rejection checks for both annotations |
| [`../Makefile`](../Makefile) | Discovers `support/tests/*-test.rhm` and exposes `support-annotation-test` |

## Focused validation

From the repository root, run:

```sh
make support-annotation-test
```

The repository test wrapper creates and removes a fresh `PLTCOMPILEDROOTS`
directory when the caller has not supplied one. The focused test covers valid
nonempty text, the empty-string rejection, a valid ASCII identifier, and
leading-digit and hyphenated identifier rejections. Broader consumer suites
are needed only when an annotation or one of its call sites changes.
