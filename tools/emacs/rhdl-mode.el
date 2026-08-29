;;; rhdl-mode.el --- Project-aware Emacs entry point for RHDL -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "25.1") (racket-mode "1.0"))
;; Version: 0.1.0
;; Keywords: languages, hardware
;; URL: https://github.com/jerryz123/rhdl

;;; Commentary:

;; RHDL uses Racket Mode's `racket-hash-lang-mode' for language-provided
;; coloring, indentation, navigation, comments, and REPL integration.  This
;; file adds a discoverable `rhdl-mode' command and makes uninstalled RHDL
;; checkouts visible to the Racket Mode back end through Racket's -S option.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(declare-function racket-add-back-end "racket-back-end" (directory &rest plist))
(declare-function racket-hash-lang-mode "racket-hash-lang" ())

(defvar racket-back-end-configurations)
(defvar racket-hash-lang-mode-lighter)
(defvar racket-program)

(defgroup rhdl nil
  "Editing support for the RHDL hardware description language."
  :group 'languages)

(defcustom rhdl-racket-program nil
  "Racket command used for RHDL checkout back ends.

When nil, inherit `racket-program'.  Like `racket-program', the value may be
either an executable string or a list containing an executable and arguments."
  :type '(choice (const :tag "Inherit Racket Mode" nil)
                 string
                 (repeat string))
  :group 'rhdl)

(defcustom rhdl-auto-configure-back-end t
  "Whether `rhdl-mode' should configure Racket Mode for an RHDL checkout.

The automatic configuration adds the checkout root with Racket's -S option.
It does not replace an exact Racket Mode back-end configuration already
registered for that root."
  :type 'boolean
  :group 'rhdl)

(defvar rhdl--configured-roots nil
  "Checkout roots considered for automatic back-end configuration.")

(defconst rhdl--font-lock-keywords
  `((,(regexp-opt
       '("assert" "bundle" "case" "circuit" "dpi_import" "dpi_reg"
         "elaborate" "elsewhen" "hardware_enum" "input" "inst"
         "interface" "mem" "mux_lookup" "otherwise"
         "output" "record" "refines" "reg" "supports" "switch"
         "sync_circuit" "sync_mem" "when" "wire")
       'symbols)
     . font-lock-keyword-face)
    (,(regexp-opt '("Bits" "Bool" "Clock" "Mask" "MaybeOneHot" "OneHot" "Reset" "SInt" "Vec")
                  'symbols)
     . font-lock-type-face))
  "Additional font-lock rules for RHDL-specific syntax and types.")

(defvar-local rhdl--font-lock-installed nil
  "Whether RHDL-specific font-lock rules are installed in this buffer.")

(defun rhdl--checkout-root (&optional directory)
  "Return the RHDL checkout containing DIRECTORY, or nil.

An RHDL checkout is identified by its `rhdl/main.rkt' reader shim."
  (when-let ((root
              (locate-dominating-file
               (or directory default-directory)
               (lambda (candidate)
                 (file-readable-p
                  (expand-file-name "rhdl/main.rkt" candidate))))))
    (file-name-as-directory (expand-file-name root))))

(defun rhdl--racket-command (root)
  "Return the Racket command for an RHDL checkout at ROOT."
  (let* ((configured (or rhdl-racket-program
                         (and (boundp 'racket-program) racket-program)
                         "racket"))
         (command (if (listp configured)
                      (copy-sequence configured)
                    (list configured)))
         (collection-root (or (file-remote-p root 'localname) root)))
    (append command
            (list "-S" (directory-file-name collection-root)))))

(defun rhdl--existing-back-end-p (root)
  "Return non-nil when Racket Mode already has a back end for exactly ROOT."
  (and (boundp 'racket-back-end-configurations)
       (cl-find-if
        (lambda (configuration)
          (string-equal
           (file-name-as-directory (plist-get configuration :directory))
           (file-name-as-directory root)))
        racket-back-end-configurations)))

(defun rhdl--ensure-back-end ()
  "Configure a project-specific Racket Mode back end when appropriate."
  (when rhdl-auto-configure-back-end
    (when-let ((root (rhdl--checkout-root)))
      (unless (member root rhdl--configured-roots)
        (unless (rhdl--existing-back-end-p root)
          (racket-add-back-end root
                               :racket-program (rhdl--racket-command root)))
        (push root rhdl--configured-roots)))))

(defun rhdl--module-language-p (module-language)
  "Return non-nil when MODULE-LANGUAGE names an RHDL language profile."
  (member module-language
          '("(lib rhdl/language.rhm)"
            "(lib rhdl/base/language.rhm)")))

(defun rhdl--configure-font-lock (enable)
  "Install RHDL font-lock rules when ENABLE is non-nil, otherwise remove them."
  (cond
   ((and enable (not rhdl--font-lock-installed))
    (font-lock-add-keywords nil rhdl--font-lock-keywords 'append)
    (setq-local rhdl--font-lock-installed t)
    (font-lock-flush))
   ((and (not enable) rhdl--font-lock-installed)
    (font-lock-remove-keywords nil rhdl--font-lock-keywords)
    (setq-local rhdl--font-lock-installed nil)
    (font-lock-flush))))

(defun rhdl--language-setup (module-language)
  "Apply RHDL presentation after loading MODULE-LANGUAGE metadata."
  (let ((rhdl-language-p (rhdl--module-language-p module-language)))
    (rhdl--configure-font-lock rhdl-language-p)
    (when rhdl-language-p
      (setq-local racket-hash-lang-mode-lighter
                  (replace-regexp-in-string
                   "\\`#lang" "RHDL" racket-hash-lang-mode-lighter)))))

(with-eval-after-load 'racket-hash-lang
  (add-hook 'racket-hash-lang-module-language-hook
            #'rhdl--language-setup))

(defun rhdl--load-racket-mode ()
  "Load Racket Mode or report the missing editor dependency."
  (unless (require 'racket-mode nil t)
    (user-error "RHDL mode requires the Emacs package racket-mode")))

;;;###autoload
(defun rhdl-mode ()
  "Edit an RHDL buffer using Racket Mode's hash-language back end.

The buffer's actual `major-mode' remains `racket-hash-lang-mode' because
Racket Mode currently relies on that exact identity for some integrations."
  (interactive)
  (rhdl--load-racket-mode)
  (rhdl--ensure-back-end)
  (racket-hash-lang-mode))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.rhdl\\'" . rhdl-mode))

(provide 'rhdl-mode)

;;; rhdl-mode.el ends here
