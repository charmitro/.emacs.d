;;; init.el --- Basic init.
;;; Commentary:
;;; Code:

(let ((minver "26.1"))
  (when (version< emacs-version minver)
    (error "Your emacs is too old -- this config requires v%s or higher" minver)))
(when (version< emacs-version "27.1")
  (message "Your emacs is old, and some functionality in this config will be disabled. PLease upgrade if possible."))


(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

(global-display-line-numbers-mode 1)
(setq tab-width 8)
(setq c-basic-offset 8)
(setq scroll-margin 0)
(setq scroll-conservatively 10000)
(setq scroll-preserve-screen-position 1)
;; Bigger font on 4K
(when (display-graphic-p)
  (if (= (x-display-pixel-width) 3840)
      (set-face-attribute 'default nil :height 200)
    (set-face-attribute 'default nil :height 180)))

;;; Disable sounds.
(setq visible-bell t)
(setq ring-bell-function 'ignore)

(defconst *is-a-mac* (eq system-type 'darwin))

(setq custom-file (locate-user-emacs-file "custom.el"))


(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;;; Packages
(require 'init-elpa)
(require 'package)
(add-to-list 'package-archives
             '("melpa-stable" . "https://stable.melpa.org/packages/"))
(package-read-all-archive-contents)

;;;; cscope
(require 'ring)     ;; for ring-insert/ring-remove etc.
(require 'easymenu) ;; for menus in some older packages
(require-package 'xcscope)
(require 'xcscope)
(setq cscope-option-do-not-use-inverted-index t)
(cscope-setup)

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
(require 'init-dape)
(require 'init-ssh)
(require 'init-mail)

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

;;; Search
(require-package 'ag)

(when (file-exists-p custom-file)
  (load custom-file))

(setq c-default-style "linux")
(setq markdown-command "pandoc")

;;; init.el ends here
