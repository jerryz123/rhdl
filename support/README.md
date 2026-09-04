<!-- Documents the dependency-neutral Rhombus refinements shared across repository packages. -->

# Shared Rhombus refinements

`annotations.rhm` defines dependency-neutral annotations that carry no Rhodium,
NoC, RISC-V, CHI, or RFPL dependency. Domain packages may depend on this module
without reversing their dependency direction.

- `NonemptyString` accepts strings with at least one character.
- `AsciiIdentifier` accepts nonempty ASCII identifiers beginning with a letter
  or underscore and continuing with letters, digits, or underscores.

Use built-in Rhombus annotations such as `NonemptyList.of(T)` directly instead
of wrapping them here. Public APIs should put direct nominal and homogeneous-
container requirements on parameters with `::` annotations. Explicit checks
remain appropriate for relationships between values, semantic membership and
uniqueness, intentional union or overload dispatch, callback results, and data
extracted from IR or other untrusted structures.
