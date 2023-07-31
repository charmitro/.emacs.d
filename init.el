;;; init.el --- Basic init.
;;; Commentary:
;;; Code:

(let ((minver "26.1"))
  (when (version< emacs-version minver)
    (error "Your emacs is too old -- this config requires v%s or higher" minver)))
(when (version< emacs-version "27.1")
  (message "Your emacs is old, and some functionality in this config will be disabled. PLease upgrade if possible."))


;; Bigger font on 4K

(when (display-graphic-p)
  (if (= (x-display-pixel-width) 3840)
      (set-face-attribute 'default nil :height 200)
    (set-face-attribute 'default nil :height 180))
  (tool-bar-mode -1)
  (scroll-bar-mode -1))

;;; Disable sounds.
(setq visible-bell t)
(setq ring-bell-function 'ignore)

(defconst *is-a-mac* (eq system-type 'darwin))

(setq custom-file (locate-user-emacs-file "custom.el"))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;;; Packages
(require 'init-elpa)

;;; UI
(require 'init-mode-line)
(require 'init-themes)

;;; Editor
(require 'init-editor)
(require 'init-corfu)
(require 'init-org)

;;; Misc
(require 'init-exec-path)
(require 'init-projectile)
(require 'init-debug)

;;; Languages
(require 'init-eglot)
(require 'init-flymake)
(require 'init-lisp)
(require 'init-rust)
(require 'init-sail)
(require 'init-go)
(require-package 'yaml-mode)

;;; System Specific
(require 'init-osx)

;;; Version Control
(require-package 'magit)

(when (file-exists-p custom-file)
  (load custom-file))

;;; init.el ends here
