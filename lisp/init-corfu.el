;;; init-corfu.el --- Interactive completion in buffers -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

;; WAITING: haskell-mode sets tags-table-list globally, breaks tags-completion-at-point-function
;; TODO Default sort order should place [a-z] before punctuation

(setq tab-always-indent 'complete)
(when (maybe-require-package 'orderless)
  (maybe-require-package 'vertico)
  (vertico-mode)
  ;; Wrap around at either end of the candidate list.
  (setq vertico-cycle t)
  (with-eval-after-load 'vertico
    (require 'orderless)
    (setq completion-styles '(orderless basic))))
(setq completion-category-defaults nil
      completion-category-overrides nil)
(setq completion-cycle-threshold 4)

(when (maybe-require-package 'corfu)
  (setq-default corfu-auto t)
  (with-eval-after-load 'eshell
    (add-hook 'eshell-mode-hook (lambda () (setq-local corfu-auto nil))))
  (setq-default corfu-quit-no-match 'separator)
  (add-hook 'after-init-hook 'global-corfu-mode)

  ;; Corfu's popup is a child frame, which terminal frames can't display
  ;; before Emacs 31, so `emacs -nw' never shows any candidates.  This
  ;; draws the popup with overlays on tty frames and leaves GUI ones alone.
  (when (and (< emacs-major-version 31)
             (maybe-require-package 'corfu-terminal))
    (add-hook 'after-init-hook 'corfu-terminal-mode))

  (when (featurep 'corfu-popupinfo)
    (with-eval-after-load 'corfu
      (corfu-popupinfo-mode)))

  ;; TODO: https://github.com/jdtsmith/kind-icon
  )


(provide 'init-corfu)
;;; init-corfu.el ends here
