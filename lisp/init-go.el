;;; init-go.el --- Rust lang support.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'go-mode)
  (when (maybe-require-package 'flymake-go)
    (with-eval-after-load 'go-mode
      (add-hook 'go-mode-hook 'flymake-mode))))

(provide 'init-go)

;;; init-go.el ends here.
