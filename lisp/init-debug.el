;;; init-debug.el --- Utilities for debuggin.
;;; Commentary:
;;; Code:

(global-set-key "\C-xpd" 'buffer-contains-debug-string)

(defun buffer-contains-debug-string ()
  "Search for the well-known Greek debug word $*@!*$ in the current buffer."
  (interactive)
  (let ((saved-line (line-number-at-pos)))
    (goto-char (point-min))
    (if (search-forward "peos" nil t)
	(forward-line 0)
      (forward-line (1- saved-line))
      (message "No 'peos' found in the current buffer. You're free to commit!"))))

(provide 'init-debug)

;;; init-debug.el ends here
