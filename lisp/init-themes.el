;;; init-themes.el --- Defautls for theme.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'naysayer-theme)
  (when (display-graphic-p)
    (setq-default custom-enabled-themes '(naysayer))))

;; custom.el enables a base16 theme; make sure it is there to load.
(maybe-require-package 'base16-theme)

(setq custom-safe-themes t)

;; In terminal frames, approximate the theme's own colors instead of
;; borrowing the terminal's ANSI palette (bright greens and all).
(setq base16-theme-256-color-source 'colors)

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
