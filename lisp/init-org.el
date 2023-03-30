;;; init-org.el --- Org-mode config -*- lexical-binding: t -*-
;;; Commentary:

;;; Code:

(when *is-a-mac*
  (maybe-require-package 'grab-mac-link))

(maybe-require-package 'org-cliplink)

(define-key global-map (kbd "C-c l") 'org-store-link)
(define-key global-map (kbd "C-c a") 'org-agenda)

(provide 'init-org)

;;; init-org.el ends here.
