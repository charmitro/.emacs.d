;;; init-eglot.el --- Eglot support
;;; Commentary:
;;; Code:

(setq read-process-output-max (* 1024 1024))

(when (maybe-require-package 'eglot)
  (maybe-require-package 'consult-eglot))

(provide 'init-eglot)
