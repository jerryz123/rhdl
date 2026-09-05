<!-- Repository-local instructions for agents working on Rhodium. -->

# Rhodium agent instructions

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
  The only exception is `tools/run-racket.sh` after it verifies an immutable
  bytecode artifact for the exact commit, Racket and Rhombus versions, platform,
  and workspace path. Treat an `instantiate-linklet` mismatch or a reference to
  a moved module as stale bytecode first, and reproduce it with a fresh compiled
  root before diagnosing the source.
- Test supported behavior and invalid uses of supported features. Do not add
  tests whose purpose is to prove that a removed or unimplemented feature does
  not exist.
- Run broader targets such as `make test` only when changes span multiple
  layers, affect shared test or build infrastructure, or otherwise cannot be
  covered confidently by focused tests.
- Keep generated Racket and Verilator build output out of version control.

## RTL formatting

- Prefer one-line RTL declarations, calls, assignments, and expressions.
- Drive a register directly with `<==`; do not spell author-level next-state
  assignments as `.next <==`. A register reads as current state and acts as
  its next-state place when it is the target of a connection.
- Use prefix `-` for fixed-width arithmetic negation; do not spell negation as
  a typed zero minus the value.
- Group assignments that share the same guard and priority into one
  state- or event-oriented `when` branch. Avoid parallel per-register chains
  that repeat an identical condition when one prioritized chain preserves the
  behavior.
- Keep conditional chains separate when their alternative events can occur
  independently or use different priorities; do not serialize simultaneous
  state updates merely to remove repeated syntax.
- Do not break an RTL expression merely because it contains a call or several
  operands. Use line breaks only for syntactic blocks, extremely long
  expressions, or regular repeated forms whose aligned layout improves the
  visible hardware structure.
- Keep record and bundle construction, lookup and decode tables, and repeated
  port or field mappings multiline when their block structure is meaningful.

## Package boundaries

- Treat `rhodium/DEVELOPING.md` as the authoritative package and frontend-layer
  dependency contract. Update its dependency table when adding a layer or
  changing a layer's direct Rhodium imports. Keep `rhodium/README.md` focused
  on the public package surface.

- Keep frontend-independent IR, Builder, verification, and printing code under
  `rhodium/core/`; core modules must not import the frontend or backend.
- Keep elaboration and language macros under `rhodium/frontend/`; frontend modules
  must not import backends.
- Put the shared public authoring surface in `rhodium/frontend/foundation.rhm`,
  independently selectable features in `rhodium/frontend/layers/`, and non-profile
  macro/static-information machinery in `rhodium/frontend/support/`.
- Frontend layers must not import sibling layers; move genuinely shared
  machinery into `rhodium/frontend/support/`.
- Keep CIRCT lowering under `rhodium/backend/`; backend modules must not import
  frontend syntax or elaboration.
- Use `rhodium/language.rhm` as the composition layer and reserve `rhodium/main.rkt`
  for the `#lang rhodium` reader shim.
- Preserve the mirrored `tests/core/`, `tests/frontend/`, and `tests/backend/`
  organization. Run `make check-boundaries` after moving or adding modules.
- Keep processor components reusable across named cores directly under `cores/`.
  Put implementation-specific decode, datapath, state, and tests under
  `cores/<core-name>/`.

## Documentation ownership

- Keep the root `README.md` focused on project orientation, quick start,
  navigation, concise status, and user-visible deferred work. Keep repository
  development setup, change workflow, and maintenance policy in the root
  `DEVELOPING.md`.
- In each documented directory, keep public entry points, behavior, stable
  contracts, supported configurations, observable failures, and deliberate
  limits in `README.md`. Keep implementation architecture, source maps,
  dependency enforcement, extension workflows, test ownership, CI, and
  generated-artifact maintenance in `DEVELOPING.md`.
- Keep the executable language walkthrough and example catalog in
  `examples/README.md`. Keep test-running guidance in `tests/README.md` and
  test placement, fixture maintenance, and CI ownership in
  `tests/DEVELOPING.md`.
- Link to an owning document instead of copying component, layer, operation,
  example, or fixture catalogs into multiple files.
