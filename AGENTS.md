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

- Run `make test` after behavioral changes.
- Keep generated Racket and Verilator build output out of version control.

## Package boundaries

- Keep frontend-independent IR, Builder, verification, and printing code under
  `rhdl/core/`; core modules must not import the frontend or backend.
- Keep elaboration and language macros under `rhdl/frontend/`; frontend modules
  must not import backends.
- Keep CIRCT lowering under `rhdl/backend/`; backend modules must not import
  frontend syntax or elaboration.
- Use `rhdl/language.rhm` as the composition layer and reserve `rhdl/main.rkt`
  for the `#lang rhdl` reader shim.
- Preserve the mirrored `tests/core/`, `tests/frontend/`, and `tests/backend/`
  organization. Run `make check-boundaries` after moving or adding modules.
