;;; init-debug.el --- Utilities for debuggin.
;;; Commentary:
;;; Code:

(global-set-key "\C-xpd" 'project-contains-debug-string)

(defun project-contains-debug-string ()
  "Search for the well-known Greek debug word $*@!*$ in the current project."
  (interactive)
  (if (require 'projectile nil 'noerror)
      (let ((project-root (projectile-project-root)))
	(if project-root
	    (progn
	      (grep (concat "grep --color=always -rnH --include=\"*.*\" -e 'peos\\|mouni\\|kavli' " project-root))
	      (message "Searching for 'peos,mouni,kavli' in project: %s" project-root))
	  (message "No 'peos,mouni,kavli' found in the current buffer. You're free to commit!")))
	(message "Projectile is not available. Please install projectile package.")))

(provide 'init-debug)

;;; init-debug.el ends here
