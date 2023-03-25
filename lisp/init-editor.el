;;; init-editor.el --- Editing utilities & enchancements.
;;; Commentary:
;;; Code:

(require-package 'multiple-cursors)
;; multiple-cursors
(global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
(global-set-key (kbd "C->") 'mc/mark-next-like-this)
(global-set-key (kbd "C-+") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)

;;nice scrolling
(defun nice-scrolling-mode ()
  (interactive)
  (cond ((= 0 scroll-conservatively)
	 (setq scroll-margin 0
	       scroll-conservatively 100000
	       scroll-preserve-screen-position 1))
	((= 100000 scroll-conservatively)
	 (setq scroll-margin 0
	       scroll-conservatively 0
	       scroll-preserve-screen-position nil))))

(delete-selection-mode)

(provide 'init-editor)

;;; init-editor.el ends here.
