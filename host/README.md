<!-- Documents the dependency-neutral host refinements shared across repository packages. -->

# Host refinements

`host/annotations.rhm` defines reusable Rhombus annotations that carry no RHDL,
NoC, RISC-V, CHI, or RFPL dependency. Domain packages may depend on this module
without reversing their dependency direction.

- `NonemptyString` accepts host strings with at least one character.
- `AsciiIdentifier` accepts nonempty ASCII identifiers beginning with a letter
  or underscore and continuing with letters, digits, or underscores.

Use built-in Rhombus annotations such as `NonemptyList.of(T)` directly instead
of wrapping them here.

Public host APIs put direct nominal and homogeneous-container requirements on
their parameters with `::` annotations. Explicit checks remain appropriate for
relationships between values, semantic membership and uniqueness, intentional
union or overload dispatch, callback results, and validation of data extracted
from IR or other untrusted structures. This keeps each type contract visible at
the API boundary without weakening domain-specific diagnostics.
