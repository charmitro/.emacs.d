;;; init-lisp.el --- Emacs lisp settings, and common config for other lisps -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require 'use-package)

(setq-default debugger-bury-or-kill 'kill)

(require-package 'elisp-slime-nav)
(dolist (hook '(emacs-lisp-mode-hook ielm-mode-hook))
  (add-hook hook 'turn-on-elisp-slime-nav-mode))
(add-hook 'emacs-lisp-mode-hook (lambda () (setq mode-name "ELisp")))

(setq-default initial-scratch-message
	      (format "Apofasises na doulepseis e...? Mallon ton exeis  %s mm - Mpamparos\n\n" (number-to-string (random 10))))

(require-package 'immortal-scratch)
(add-hook 'after-init-hook 'immortal-scratch-mode)

(when (maybe-require-package 'ipretty)
  (add-hook 'after-init-hook 'ipretty-mode))

(global-set-key (kbd "C-h K") 'find-function-on-key)

;; Extras for theme editing
(when (maybe-require-package 'rainbow-mode)
  (defun sanityinc/enable-rainbow-mode-if-theme ()
    (when (and (buffer-file-name) (string-match-p "\\(color-theme-\\|-theme\\.el\\)" (buffer-file-name)))
      (rainbow-mode)))
  (add-hook 'emacs-lisp-mode-hook 'sanityinc/enable-rainbow-mode-if-theme)
  (add-hook 'help-mode-hook 'rainbow-mode)
  (with-eval-after-load 'rainbow-mode
    (diminish 'rainbow-mode)))

(when (maybe-require-package 'highlight-quoted)
  (add-hook 'emacs-lisp-mode-hook 'highlight-quoted-mode))
(when (maybe-require-package 'package-lint-flymake)
  (add-hook 'emacs-lisp-mode-hook #'package-lint-flymake-setup))

;; ERT
(with-eval-after-load 'ert
  (define-key ert-results-mode-map (kbd "g") 'ert-results-rerun-all-tests))
(maybe-require-package 'cl-libify)
(maybe-require-package 'flycheck-relint)
(maybe-require-package 'cask-mode)


(provide 'init-lisp)

;;; init-lisp.el ends here
