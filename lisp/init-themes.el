;;; init-themes.el --- Defautls for theme.
;;; Commentary:
;;; Code:

(require-package 'naysayer-theme)
(when (maybe-require-package 'tao-theme)
  (setq-default custom-enabled-themes '(tao-yin)))


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
