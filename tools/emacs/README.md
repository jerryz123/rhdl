<!-- Documents installation and behavior of RHDL's project-aware Emacs integration. -->

# RHDL Emacs integration

[`rhdl-mode.el`](rhdl-mode.el) provides a discoverable `M-x rhdl-mode` entry
point while retaining Racket Mode's `racket-hash-lang-mode` as the actual major
mode. That distinction preserves Rhombus-provided coloring, indentation,
navigation, comments, and REPL behavior.

Install the Emacs package `racket-mode`, then add this directory to Emacs's
load path:

```elisp
(add-to-list 'load-path "/path/to/rhdl/tools/emacs")
(require 'rhdl-mode)
```

The package associates `.rhdl` files with `rhdl-mode`. For files inside an
RHDL checkout, it also registers a checkout-specific Racket Mode back end whose
Racket command includes `-S /path/to/rhdl`. This makes `#lang rhdl` resolvable
without installing or linking that checkout as a Racket package. An exact
back-end configuration already registered for the checkout takes precedence.

Set `rhdl-racket-program` to an executable string or command list to override
Racket Mode's `racket-program` for automatically configured RHDL back ends. Set
`rhdl-auto-configure-back-end` to `nil` to disable checkout configuration.

Run the editor integration unit tests with:

```sh
make emacs-test
```
