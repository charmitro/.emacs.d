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

;; Terminal frames can't reach the Wayland clipboard on their own, so
;; route kills and yanks through wl-clipboard there.  GUI frames keep
;; the usual behaviour.
(when (and (getenv "WAYLAND_DISPLAY") (executable-find "wl-copy"))
  (defun wl-clipboard-cut (text)
    "Copy TEXT to the system clipboard, using wl-copy on terminal frames."
    (if (display-graphic-p)
        (gui-select-text text)
      (let* ((process-connection-type nil)
             (proc (start-process "wl-copy" nil "wl-copy")))
        (process-send-string proc text)
        (process-send-eof proc))))

  (defun wl-clipboard-paste ()
    "Return the system clipboard text, using wl-paste on terminal frames."
    (if (display-graphic-p)
        (gui-selection-value)
      ;; Bounded by `timeout' so a stuck clipboard owner can't hang Emacs.
      (let ((text (shell-command-to-string
                   "timeout 1 wl-paste --no-newline --type text 2>/dev/null")))
        (unless (or (string-empty-p text)
                    (equal text (car kill-ring)))
          text))))

  (setq interprogram-cut-function #'wl-clipboard-cut
        interprogram-paste-function #'wl-clipboard-paste))

;; Let terminal frames see the mouse too: clicking, wheel scrolling, and
;; dragging window borders to resize.  The terminal's own text selection
;; then needs Shift held while dragging.
(xterm-mouse-mode 1)

(provide 'init-editor)

;;; init-editor.el ends here.
