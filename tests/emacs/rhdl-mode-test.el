;;; rhdl-mode-test.el --- Tests for RHDL's Emacs entry point -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'rhdl-mode)

(defvar racket-back-end-configurations)

(defconst rhdl-test-checkout-root
  (file-name-as-directory
   (expand-file-name "../.." (file-name-directory load-file-name))))

(ert-deftest rhdl-mode-registers-rhdl-extension ()
  (should (eq (cdr (assoc "\\.rhdl\\'" auto-mode-alist)) 'rhdl-mode)))

(ert-deftest rhdl-mode-finds-checkout-root ()
  (should
   (equal (rhdl--checkout-root
           (expand-file-name "examples/lop" rhdl-test-checkout-root))
          rhdl-test-checkout-root)))

(ert-deftest rhdl-mode-builds-project-racket-command ()
  (let ((rhdl-racket-program '("racket" "-j")))
    (should
     (equal (rhdl--racket-command rhdl-test-checkout-root)
            (list "racket" "-j" "-S"
                  (directory-file-name rhdl-test-checkout-root))))))

(ert-deftest rhdl-mode-configures-checkout-once ()
  (let ((racket-back-end-configurations nil)
        (rhdl--configured-roots nil)
        (rhdl-racket-program "racket")
        calls)
    (cl-letf (((symbol-function 'rhdl--checkout-root)
               (lambda (&optional _directory) rhdl-test-checkout-root))
              ((symbol-function 'racket-add-back-end)
               (lambda (root &rest options)
                 (push (cons root options) calls))))
      (rhdl--ensure-back-end)
      (rhdl--ensure-back-end))
    (should (= (length calls) 1))
    (should
     (equal (car calls)
            (list rhdl-test-checkout-root
                  :racket-program
                  (list "racket" "-S"
                        (directory-file-name rhdl-test-checkout-root)))))))

(ert-deftest rhdl-mode-respects-explicit-checkout-back-end ()
  (let ((racket-back-end-configurations
         (list (list :directory rhdl-test-checkout-root
                     :racket-program '("custom-racket"))))
        (rhdl--configured-roots nil)
        called)
    (cl-letf (((symbol-function 'rhdl--checkout-root)
               (lambda (&optional _directory) rhdl-test-checkout-root))
              ((symbol-function 'racket-add-back-end)
               (lambda (&rest _arguments) (setq called t))))
      (rhdl--ensure-back-end))
    (should-not called)))

(ert-deftest rhdl-mode-dispatches-without-changing-back-end-order ()
  (let (events)
    (cl-letf (((symbol-function 'rhdl--load-racket-mode)
               (lambda () (push 'load events)))
              ((symbol-function 'rhdl--ensure-back-end)
               (lambda () (push 'configure events)))
              ((symbol-function 'racket-hash-lang-mode)
               (lambda () (push 'mode events))))
      (rhdl-mode))
    (should (equal (reverse events) '(load configure mode)))))

(ert-deftest rhdl-mode-reports-missing-racket-mode ()
  (cl-letf (((symbol-function 'require)
             (lambda (&rest _arguments) nil)))
    (should-error (rhdl--load-racket-mode) :type 'user-error)))

(ert-deftest rhdl-mode-labels-only-rhdl-module-languages ()
  (with-temp-buffer
    (setq-local racket-hash-lang-mode-lighter "#lang⇉")
    (rhdl--language-setup "(lib rhdl/language.rhm)")
    (should (equal racket-hash-lang-mode-lighter "RHDL⇉")))
  (with-temp-buffer
    (setq-local racket-hash-lang-mode-lighter "#lang⇉")
    (rhdl--language-setup "(lib rhdl/base/language.rhm)")
    (should (equal racket-hash-lang-mode-lighter "RHDL⇉")))
  (with-temp-buffer
    (setq-local racket-hash-lang-mode-lighter "#lang⇉")
    (rhdl--language-setup "(lib rhombus/main.rhm)")
    (should (equal racket-hash-lang-mode-lighter "#lang⇉"))))

;;; rhdl-mode-test.el ends here
