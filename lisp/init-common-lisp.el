;;; init-common-lisp.el --- Common Lisp support
;;; Commentary:
;;; Code:

(add-auto-mode 'lisp-mode "\\.cl\\'")
(add-hook 'lisp-mode-hook (lambda ()
                            (unless (featurep 'slime)
                              (require 'slime)
                              (normal-mode))))

(with-eval-after-load 'slime
  (when (executable-find "sbcl")
    (add-to-list 'slime-lisp-implementations
		 '(sbcl ("sbcl") :coding-system utf-8-unix)))
  (when (executable-find "lisp")
    (add-to-list 'slime-lisp-implementations
		 '(cmucl ("lisp") :coding-system iso-latin-1-unix)))
  (when (executable-find "ccl")
    (add-to-list 'slime-lisp-implementations
		 '(cmucl ("ccl") :coding-system utf-8-unix))))


(provide 'init-common-lisp)

;;; init-common-lisp.el ends here
