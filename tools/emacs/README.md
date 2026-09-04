<!-- Documents installation and behavior of Rhodium's project-aware Emacs integration. -->

# Rhodium Emacs integration

[`rhodium-mode.el`](rhodium-mode.el) provides a discoverable `M-x rhodium-mode` entry
point while retaining Racket Mode's `racket-hash-lang-mode` as the actual major
mode. That distinction preserves Rhombus-provided coloring, indentation,
navigation, comments, and REPL behavior. A language-specific font-lock layer
adds faces for Rhodium syntax such as `circuit`, `input`, `when`, and `assert`,
plus the built-in hardware types, while leaving Rhombus tokens to the reader.

Install the Emacs package `racket-mode`, then add this directory to Emacs's
load path:

```elisp
(add-to-list 'load-path "/path/to/rhodium/tools/emacs")
(require 'rhodium-mode)
```

The package associates `.rhdl` files with `rhodium-mode`. For files inside an
Rhodium checkout, it also registers a checkout-specific Racket Mode back end whose
Racket command includes `-S /path/to/rhodium`. This makes `#lang rhodium` resolvable
without installing or linking that checkout as a Racket package. An exact
back-end configuration already registered for the checkout takes precedence.

Set `rhodium-racket-program` to an executable string or command list to override
Racket Mode's `racket-program` for automatically configured Rhodium back ends. Set
`rhodium-auto-configure-back-end` to `nil` to disable checkout configuration.

Run the editor integration unit tests with:

```sh
make emacs-test
```
