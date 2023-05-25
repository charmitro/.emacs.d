;;; init-themes.el --- Defautls for theme.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'naysayer-theme)
  (when (display-graphic-p)
    (setq-default custom-enabled-themes '(naysayer))))

(setq custom-safe-themes t)

;; Ensure that themes will be applied even if they have not been customized
(defun reapply-themes ()
  "Forcibly load the themes listed in `custom-enabled-themes'."
  (dolist (theme custom-enabled-themes)
    (unless (custom-theme-p theme)
      (load-theme theme)))
  (custom-set-variables `(custom-enabled-themes (quote ,custom-enabled-themes))))

(add-hook 'after-init-hook 'reapply-themes)

(provide 'init-themes)

;;; init-themes.el ends here
