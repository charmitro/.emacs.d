;;; init-projectile.el --- Rust lang support.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'projectile)
  (projectile-mode +1)
  ;; Recommended keymap prefix on macOS
  (define-key projectile-mode-map (kbd "s-p") 'projectile-command-map)
  ;; Recommended keymap prefix on Windows/Linux
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))

(provide 'init-projectile)

;;; init-projectile.el ends here.
