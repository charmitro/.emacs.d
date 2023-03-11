;;; init-rust.el --- Rust lang support.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'rust-mode)
  (when (maybe-require-package 'flycheck-rust)
    (with-eval-after-load 'rust-mode
      (add-hook 'flycheck-mode-hook #'flycheck-rust-setup))))

(provide 'init-rust)

;;; init-rust.el ends here.
