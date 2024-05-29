;;; init-editor.el --- Editing utilities & enchancements.
;;; Commentary:
;;; Code:

(when (maybe-require-package 'swiper)
  (global-set-key "\C-s" 'swiper))

(require-package 'multiple-cursors)
;; multiple-cursors
;; Can this work on `-nw` emacs(i.e. terminal)? - @charmitro
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

(add-hook 'diff-mode-hook 'whitespace-mode)

(when (maybe-require-package 'ace-window)
  (global-set-key (kbd "C-x o") 'ace-window))

;; Interactive function to copy current buffer filename.
(defun copy-current-buffer-filename ()
  "Copy the current buffer's filename to the clipboard."
  (interactive)
  (if-let ((filename (buffer-file-name)))
      (progn
        (kill-new filename)
        (message "Copied buffer file name '%s' to the clipboard." filename))
    (message "Current buffer is not visiting a file.")))

(global-set-key "\C-ccb" 'copy-current-buffer-filename)

(provide 'init-editor)

;;; init-editor.el ends here.
