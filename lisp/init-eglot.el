;;; init-eglot.el --- Eglot support
;;; Commentary:
;;; Code:

(setq read-process-output-max (* 1024 1024))

(when (maybe-require-package 'eglot)
  (maybe-require-package 'consult-eglot))

;; The code-action indicator defaults to "💡", which is two columns wide
;; but goes in a one-column margin; in terminals that shifts the line and
;; scrambles the display.  Use ASCII ("!" is taken by flymake).
(setq eglot-code-action-indicator "*")

(with-eval-after-load 'eglot
  ;; Never add #includes on completion; in the kernel they're deliberate.
  (add-to-list 'eglot-server-programs
               '((c-mode c-ts-mode c++-mode c++-ts-mode)
                 . ("clangd" "--header-insertion=never" "--background-index" "-j=8"))))

;; Start clangd for C files in projects that have a compilation
;; database (e.g. `make compile_commands.json' in a kernel tree), and
;; leave stray C files alone.
(defun eglot-ensure-if-compile-db ()
  "Start eglot if the current file's project has a compile_commands.json."
  (when (locate-dominating-file default-directory "compile_commands.json")
    (eglot-ensure)))

(add-hook 'c-mode-hook #'eglot-ensure-if-compile-db)

;; Once a language server manages a buffer, it is the checker: drop the
;; flycheck checkers chained in by init-flymake, which would only repeat
;; (or misplace) the same diagnostics.
(defun eglot-only-diagnostics ()
  "Use only the language server's diagnostics in eglot buffers."
  (when (eglot-managed-p)
    (setq-local flymake-diagnostic-functions
                (seq-remove (lambda (f)
                              (and (symbolp f)
                                   (string-prefix-p "flymake-flycheck:" (symbol-name f))))
                            flymake-diagnostic-functions))
    (flymake-start)))

(add-hook 'eglot-managed-mode-hook #'eglot-only-diagnostics)

;; Kernel functions run long; show which one point is in.
(add-hook 'c-mode-hook #'which-function-mode)

;; Search the project: text with ripgrep, symbols through clangd.
(when (require 'consult nil t)
  (global-set-key (kbd "M-s r") #'consult-ripgrep))
(when (fboundp 'consult-eglot-symbols)
  (global-set-key (kbd "M-s s") #'consult-eglot-symbols))

(provide 'init-eglot)
