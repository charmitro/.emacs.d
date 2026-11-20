;;; init-flymake.el --- Configure Flymake global behaviour -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(maybe-require-package 'flymake "1.2.1")

;; Use flycheck checkers with flymake, to extend its coverage
(when (maybe-require-package 'flymake-flycheck)
  ;; Disable flycheck checkers for which we have flymake equivalents
  (with-eval-after-load 'flycheck
    (setq-default flycheck-disabled-checkers
                  (append (default-value 'flycheck-disabled-checkers)
                          '(emacs-lisp emacs-lisp-checkdoc emacs-lisp-package
                            ;; rust-analyzer (eglot) checks Rust.  These run
                            ;; their own cargo build and pin errors from
                            ;; dependencies onto the open buffer's lines.
                            rust-cargo rust rust-clippy))))

  (defun sanityinc/enable-flymake-flycheck ()
    (setq-local flymake-diagnostic-functions
                (append flymake-diagnostic-functions
                        (flymake-flycheck-all-chained-diagnostic-functions))))

  (add-hook 'flymake-mode-hook 'sanityinc/enable-flymake-flycheck)
  (add-hook 'prog-mode-hook 'flymake-mode)
  (add-hook 'text-mode-hook 'flymake-mode))

;; In terminals the indicators go in the margin, and the default error
;; mark "‼" is an emoji that Konsole draws two columns wide while Emacs
;; counts one, which scrambles the display.  Stick to ASCII; the face
;; still tells errors from warnings.
(setq flymake-margin-indicators-string
      '((error "!" compilation-error)
        (warning "!" compilation-warning)
        (note "!" compilation-info)))

(with-eval-after-load 'flymake
  ;; Provide some flycheck-like bindings in flymake mode to ease transition
  (define-key flymake-mode-map (kbd "C-c ! n") 'flymake-goto-next-error)
  (define-key flymake-mode-map (kbd "C-c ! p") 'flymake-goto-prev-error)
  (define-key flymake-mode-map (kbd "C-c ! c") 'flymake-start))

(unless (version< emacs-version "28.1")
  (setq eldoc-documentation-function 'eldoc-documentation-compose)

  (add-hook 'flymake-mode-hook
            (lambda ()
              (setq eldoc-documentation-functions
                    (cons 'flymake-eldoc-function
                          (delq 'flymake-eldoc-function eldoc-documentation-functions))))))

(provide 'init-flymake)
;;; init-flymake.el ends here
