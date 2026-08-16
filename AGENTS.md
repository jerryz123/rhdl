<!-- Repository-local instructions for agents working on RHDL. -->

# RHDL agent instructions

## File headers

- Every new or modified source, test, script, configuration, and documentation
  file must begin with a concise top-of-file comment explaining the file's
  purpose.
- Use the file format's native comment syntax. For Markdown, use an HTML
  comment.
- When a file requires a shebang or another mandatory first line, keep that
  line first and place the explanatory comment immediately after it.
- Keep header comments specific to the file; do not use a generic copyright or
  filename-only comment as a substitute for describing its purpose.

## Verification

- After changes, run the minimum focused set of tests that directly covers the
  modified behavior; do not run the full test suite by default.
- Run every Racket or Rhombus test, elaboration, and fixture command with
  `PLTCOMPILEDROOTS` set to a newly created temporary directory. Do not append
  a trailing path-list separator: that restores source-adjacent `compiled/`
  directories as fallback roots and can load stale bytecode. Reuse the same
  temporary root within one focused validation batch so dependencies are not
  repeatedly rebuilt.
- Add `-y` when invoking `racket` directly so changed dependencies are rebuilt.
  Treat an `instantiate-linklet` mismatch or a reference to a moved module as
  stale bytecode first, and reproduce it with a fresh compiled root before
  diagnosing the source.
- Test supported behavior and invalid uses of supported features. Do not add
  tests whose purpose is to prove that a removed or unimplemented feature does
  not exist.
- Run broader targets such as `make test` only when changes span multiple
  layers, affect shared test or build infrastructure, or otherwise cannot be
  covered confidently by focused tests.
- Keep generated Racket and Verilator build output out of version control.

## RTL formatting

- Prefer one-line RTL declarations, calls, assignments, and expressions.
- Do not break an RTL expression merely because it contains a call or several
  operands. Use line breaks only for syntactic blocks, extremely long
  expressions, or regular repeated forms whose aligned layout improves the
  visible hardware structure.
- Keep record and bundle construction, lookup and decode tables, and repeated
  port or field mappings multiline when their block structure is meaningful.

## Package boundaries

- Treat `rhdl/README.md` as the authoritative package and frontend-layer
  dependency contract. Update its dependency table when adding a layer or
  changing a layer's direct RHDL imports.

- Keep frontend-independent IR, Builder, verification, and printing code under
  `rhdl/core/`; core modules must not import the frontend or backend.
- Keep elaboration and language macros under `rhdl/frontend/`; frontend modules
  must not import backends.
- Put the shared public authoring surface in `rhdl/frontend/foundation.rhm`,
  independently selectable features in `rhdl/frontend/layers/`, and non-profile
  macro/static-information machinery in `rhdl/frontend/support/`.
- Frontend layers must not import sibling layers; move genuinely shared
  machinery into `rhdl/frontend/support/`.
- Keep CIRCT lowering under `rhdl/backend/`; backend modules must not import
  frontend syntax or elaboration.
- Use `rhdl/language.rhm` as the composition layer and reserve `rhdl/main.rkt`
  for the `#lang rhdl` reader shim.
- Preserve the mirrored `tests/core/`, `tests/frontend/`, and `tests/backend/`
  organization. Run `make check-boundaries` after moving or adding modules.
- Keep processor components reusable across named cores directly under `cores/`.
  Put implementation-specific decode, datapath, state, and tests under
  `cores/<core-name>/`.

## Documentation ownership

- Keep the root `README.md` focused on project orientation, quick start,
  navigation, concise status, and deferred work.
- Put implementation architecture in `rhdl/README.md` and detailed component
  contracts in the nearest component directory's `README.md`.
- Keep the executable language walkthrough and example catalog in
  `examples/README.md`; keep test workflows under `tests/`.
- Link to an owning document instead of copying component, layer, operation,
  example, or fixture catalogs into multiple files.
