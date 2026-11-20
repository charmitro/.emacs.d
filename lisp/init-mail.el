;;; init-mail.el --- Email via mu4e  -*- lexical-binding: t -*-
;;; Commentary:
;;; mbsync fetches mail into ~/Mail, mu indexes it, msmtp sends it.
;;; Credentials live in the GNOME keyring (see ~/.mbsyncrc, ~/.msmtprc).
;;; Code:

;; mu4e ships with the maildir-utils package, but its .elc files are
;; built for Fedora's Emacs and won't load in this one.  Keep a copy of
;; the sources compiled locally, refreshed whenever the package updates.
(defconst mail-mu4e-system-dir "/usr/share/emacs/site-lisp/mu4e")
(defconst mail-mu4e-local-dir (locate-user-emacs-file "mu4e"))

(defun mail-mu4e-rebuild ()
  "Copy mu4e sources from the system and byte-compile them locally."
  (interactive)
  (make-directory mail-mu4e-local-dir t)
  (dolist (f (directory-files mail-mu4e-local-dir t "\\.elc?\\'"))
    (delete-file f))
  (dolist (f (directory-files mail-mu4e-system-dir t "\\.el\\'"))
    (copy-file f (file-name-as-directory mail-mu4e-local-dir) t))
  (byte-recompile-directory mail-mu4e-local-dir 0 t))

(when (file-directory-p mail-mu4e-system-dir)
  (add-to-list 'load-path mail-mu4e-local-dir)
  (when (file-newer-than-file-p
         (expand-file-name "mu4e.el" mail-mu4e-system-dir)
         (expand-file-name "mu4e.el" mail-mu4e-local-dir))
    (mail-mu4e-rebuild)))

(when (require 'mu4e nil t)
  (setq mail-user-agent 'mu4e-user-agent
        user-full-name "Panagiotis Foliadis")

  ;; Fetching
  (setq mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval (* 5 60)
        ;; Required with mbsync, or moved messages get duplicate UIDs.
        mu4e-change-filenames-when-moving t)

  ;; Accounts.  Each lives under ~/Mail/<name>; replies pick the account
  ;; the message came from, new mail asks which one to send from.
  (defun mail-in-account-p (msg account)
    "Return non-nil if MSG is stored under ACCOUNT's maildir."
    (and msg (string-prefix-p (concat "/" account "/")
                              (mu4e-message-field msg :maildir))))

  (setq mu4e-contexts
        (list
         (make-mu4e-context
          :name "posteo"
          :match-func (lambda (msg) (mail-in-account-p msg "posteo"))
          :vars '((user-mail-address . "pfoliadis@posteo.net")
                  (mu4e-sent-folder   . "/posteo/Sent")
                  (mu4e-drafts-folder . "/posteo/Drafts")
                  (mu4e-trash-folder  . "/posteo/Trash")
                  (mu4e-refile-folder . "/posteo/Archive")
                  ;; Posteo does not file sent mail on its own.
                  (mu4e-sent-messages-behavior . sent)))
         (make-mu4e-context
          :name "hotmail"
          :match-func (lambda (msg) (mail-in-account-p msg "hotmail"))
          :vars '((user-mail-address . "pfoliadis@hotmail.com")
                  (mu4e-sent-folder   . "/hotmail/Sent")
                  (mu4e-drafts-folder . "/hotmail/Drafts")
                  (mu4e-trash-folder  . "/hotmail/Deleted")
                  (mu4e-refile-folder . "/hotmail/Archive")
                  ;; Outlook files mail sent over SMTP in Sent itself.
                  (mu4e-sent-messages-behavior . delete)))
         ;; University (EAP), Microsoft 365 with Greek folder names.
         (make-mu4e-context
          :name "eap"
          :match-func (lambda (msg) (mail-in-account-p msg "eap"))
          :vars '((user-mail-address . "std168355@ac.eap.gr")
                  (mu4e-sent-folder   . "/eap/Απεσταλμένα")
                  (mu4e-drafts-folder . "/eap/Πρόχειρα")
                  (mu4e-trash-folder  . "/eap/Διαγραμμένα")
                  (mu4e-refile-folder . "/eap/Αρχειοθήκη")
                  (mu4e-sent-messages-behavior . delete)))
         ;; Work, Google Workspace.  Gmail files sent mail itself.
         (make-mu4e-context
          :name "work"
          :match-func (lambda (msg) (mail-in-account-p msg "work"))
          :vars '((user-mail-address . "pan@thanefield.capital")
                  (mu4e-sent-folder   . "/work/[Gmail]/Sent Mail")
                  (mu4e-drafts-folder . "/work/[Gmail]/Drafts")
                  (mu4e-trash-folder  . "/work/[Gmail]/Bin")
                  (mu4e-refile-folder . "/work/Archive")
                  (mu4e-sent-messages-behavior . delete)))))

  (setq mu4e-context-policy 'pick-first
        mu4e-compose-context-policy 'ask)

  ;; Folders, relative to ~/Mail
  (setq mu4e-maildir-shortcuts
        '((:maildir "/posteo/INBOX"        :key ?i)
          (:maildir "/posteo/INBOX/Kernel" :key ?k)
          (:maildir "/hotmail/INBOX"       :key ?h)
          (:maildir "/eap/INBOX"           :key ?u)
          (:maildir "/work/INBOX"          :key ?w)))

  ;; Sending
  (setq message-send-mail-function 'message-send-mail-with-sendmail
        sendmail-program (executable-find "msmtp")
        message-sendmail-envelope-from 'header
        message-kill-buffer-on-exit t)

  ;; Composing: hard-wrap at 72 columns.  No format=flowed, mailing
  ;; lists (the kernel ones especially) want plain wrapped text.
  (setq mu4e-compose-format-flowed nil
        message-fill-column 72
        message-signature "P. Foliadis")

  ;; Reading.  Gnus dims everything after a "--" line as a signature,
  ;; which greys out whole bodies of mails that open with one.  Only
  ;; treat it as a signature when it's reasonably short.
  (setq gnus-signature-limit 10.0)

  ;; Show the recipient instead of the sender for mail we sent, so the
  ;; Sent folders list who it went to rather than our own name.
  (setq mu4e-headers-fields
        '((:human-date   . 12)
          (:flags        . 6)
          (:mailing-list . 10)
          (:from-or-to   . 22)
          (:subject)))

  ;; Show threads folded when a list is first opened.  Refreshes of the
  ;; same search (g, executing marks, the update timer) keep whatever
  ;; was unfolded by hand.
  (defvar mail-thread-folded-query nil
    "The search whose threads were last folded by default.")

  (defvar mail-thread-fold-status t
    "Whether all threads are folded (S-TAB) in that search.")

  (defvar mail-thread-docids nil
    "Threads folded or unfolded individually in that search.
mu4e keeps this and the global status buffer-locally, and loses both
on every refresh.")

  (defun mail-remember-thread-folds (&rest _)
    "Save the fold state so it survives a refresh."
    (setq mail-thread-fold-status mu4e-thread--fold-status
          mail-thread-docids mu4e-thread--docids))

  (dolist (fn '(mu4e-thread-fold mu4e-thread-unfold
                mu4e-thread-fold-all mu4e-thread-unfold-all
                mu4e-thread-fold-toggle-all))
    (advice-add fn :after #'mail-remember-thread-folds))

  (defun mail-fold-threads-by-default ()
    "Fold all threads on a new search, restore fold state on a refresh."
    (when (bound-and-true-p mu4e-thread-mode)
      (let ((query (mu4e-last-query)))
        (unless (equal query mail-thread-folded-query)
          (setq mail-thread-folded-query query
                mail-thread-fold-status t
                mail-thread-docids nil))
        (setq mu4e-thread--fold-status mail-thread-fold-status
              mu4e-thread--docids mail-thread-docids)
        (mu4e-thread-fold-apply-all))))

  ;; Every command run from the message view (n, p, marks, ...) first
  ;; unfolds all threads so it can find the message in the list.  The
  ;; lookup searches the buffer text, which folding doesn't remove, so
  ;; skip that and keep the folds; only an explicit toggle-all goes on.
  (defun mail-keep-folds-from-view (orig &rest args)
    "Run ORIG with ARGS unless a view command is unfolding implicitly."
    (unless (and (symbolp this-command)
                 (string-prefix-p "mu4e-view-" (symbol-name this-command))
                 (not (eq this-command 'mu4e-view-thread-fold-toggle-all)))
      (apply orig args)))

  (advice-add 'mu4e-thread-unfold-all :around #'mail-keep-folds-from-view)

  (add-hook 'mu4e-headers-found-hook #'mail-fold-threads-by-default)

  ;; When a message changes (e.g. marked read on opening), mu4e deletes
  ;; its line and inserts a new one.  For a thread root that lands at
  ;; the start of the fold overlay and ends up hidden inside it, taking
  ;; the whole thread off the screen.  Rebuild the folds afterwards.
  (defun mail-refold-threads (&rest _)
    "Redo thread folding in the headers buffer from the saved state."
    (when-let ((buf (get-buffer (mu4e-get-headers-buffer))))
      (with-current-buffer buf
        (when (bound-and-true-p mu4e-thread-mode)
          (let ((status mu4e-thread--fold-status)
                (docids mu4e-thread--docids))
            (remove-overlays (point-min) (point-max) 'mu4e-thread-folded t)
            (setq mu4e-thread--fold-status status
                  mu4e-thread--docids docids)
            (mu4e-thread-fold-apply-all))))))

  ;; The same delete-and-reinsert also drags point: after reading a
  ;; folded thread's head, point ends up on the *next* thread's head,
  ;; so the following n skips a thread.  Remember which message point
  ;; (and each window showing the list) was on, and go back to it.
  (defun mail-headers-update-keep-point (orig &rest args)
    "Run ORIG with ARGS, then refold and restore point to its message."
    (let* ((buf (get-buffer (mu4e-get-headers-buffer)))
           (docid-at (lambda (pos) (save-excursion (goto-char pos)
                                                   (mu4e~headers-docid-at-point))))
           (here (and buf (with-current-buffer buf (funcall docid-at (point)))))
           (wins (and buf (mapcar (lambda (w) (cons w (with-current-buffer buf
                                                        (funcall docid-at (window-point w)))))
                                  (get-buffer-window-list buf nil t)))))
      (prog1 (apply orig args)
        (mail-refold-threads)
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (when (and here (mu4e~headers-goto-docid here))
              (move-to-column 2))
            (dolist (w wins)
              (when (and (window-live-p (car w)) (cdr w))
                (save-excursion
                  (when (mu4e~headers-goto-docid (cdr w))
                    (move-to-column 2)
                    (set-window-point (car w) (point)))))))))))

  (advice-add 'mu4e~headers-update-handler :around #'mail-headers-update-keep-point)
  (advice-add 'mu4e~headers-remove-handler :around #'mail-headers-update-keep-point)

  ;; List mail is mostly unread; folding only read messages would
  ;; leave long threads open.
  (setq mu4e-thread-fold-unread t)

  ;; TAB folds or unfolds the thread and stays on its first message,
  ;; rather than mu4e's jump to the next thread.  Bind both the GUI
  ;; <tab> and the TAB (C-i) that terminals send.
  (defun mail-thread-toggle-at-root ()
    "Fold or unfold the thread at point, then go to its first message."
    (interactive)
    (mu4e-thread-fold-toggle)
    (mu4e-thread-goto-root)
    (when-let ((docid (mu4e~headers-docid-at-point)))
      (move-to-column 2)
      (mu4e~headers-highlight docid)))

  (with-eval-after-load 'mu4e-thread
    (keymap-set mu4e-thread-mode-map "TAB" #'mail-thread-toggle-at-root)
    (keymap-set mu4e-thread-mode-map "<tab>" #'mail-thread-toggle-at-root))

  ;; While reading (a message is open), n/p from a thread's head into
  ;; its folded replies opens that thread (mu4e would skip over it); it
  ;; stays open until TAB.  Moving into a different folded thread still
  ;; skips it, and so does plain list navigation with no message open.
  (defun mail-thread-open-on-move (lines)
    "Unfold the thread at point if a move of LINES steps into its replies."
    (when (and (bound-and-true-p mu4e-thread-mode)
               (window-live-p mu4e~headers-view-win)
               (mu4e-message-at-point 'noerror))
      (let ((here (mu4e-thread-root)))
        (save-excursion
          (when (and (ignore-errors (let (line-move-visual) (line-move lines)) t)
                     (mu4e~headers-docid-at-point)
                     (mu4e-thread-message-folded-p)
                     (= (mu4e-thread-root) here))
            (mu4e-thread-unfold))))))

  (advice-add 'mu4e~headers-move :before #'mail-thread-open-on-move)

  ;; Plain line motion (arrows, C-n/C-p) steps onto the hidden lines of
  ;; a folded thread, leaving point inside it.  Move like n/p instead,
  ;; which skip folded messages.
  (with-eval-after-load 'mu4e-headers
    (keymap-set mu4e-headers-mode-map "<remap> <next-line>" #'mu4e-headers-next)
    (keymap-set mu4e-headers-mode-map "<remap> <previous-line>" #'mu4e-headers-prev))

  ;; The work mail is GitLab notifications: GitLab threads every comment
  ;; under its merge request, which isn't in the mailbox, so threading
  ;; just scrambles the date order.  List the work folders flat, newest
  ;; first, and thread everything else.  Only on a new search, so a
  ;; manual P t toggle survives g and other reruns.
  (defvar mail-search-last-query nil
    "The previous search, to tell a new search from a rerun.")

  (defun mail-search-threads-per-folder (query)
    "Thread QUERY's results unless it's for the work folders."
    (unless (equal query mail-search-last-query)
      (setq mail-search-last-query query
            mu4e-search-threads (not (string-match-p "maildir:\"?/work/" query)))))

  (add-hook 'mu4e-search-hook #'mail-search-threads-per-folder)

  ;; The main view shows (+N) new mails per folder, counted against a
  ;; baseline snapshot.  Leaving a message list with q resets the whole
  ;; baseline, wiping every folder's (+N).  Reset only the folder (or
  ;; search) that was just looked at instead.
  (defvar mail-keep-baseline nil
    "Non-nil while leaving a list: don't reset the whole baseline.")

  (defvar mail-baseline-reset-query nil
    "Effective query whose baseline entry to refresh with the next counts.")

  (defun mail-query-items-refresh (orig &optional reset-baseline)
    "Call ORIG, but skip RESET-BASELINE while leaving a list."
    (funcall orig (and reset-baseline (not mail-keep-baseline))))

  (advice-add 'mu4e--query-items-refresh :around #'mail-query-items-refresh)

  (defun mail-headers-quit-keep-counts (orig &rest args)
    "Leave the list with ORIG and ARGS, resetting only its own counter."
    (setq mail-baseline-reset-query
          (and mu4e--search-last-query
               (funcall mu4e-query-rewrite-function mu4e--search-last-query)))
    (let ((mail-keep-baseline t))
      (apply orig args)))

  (advice-add 'mu4e~headers-quit-buffer :around #'mail-headers-quit-keep-counts)

  (defun mail-baseline-reset-folder (&rest _)
    "Move the visited query's baseline entry up to its latest counts."
    (when-let ((query mail-baseline-reset-query)
               (fresh (mu4e--query-find-item query (mu4e-server-query-items))))
      (when mu4e--query-items-baseline
        (setq mu4e--query-items-baseline
              (cons fresh (seq-remove (lambda (item)
                                        (equal (mu4e--bookmark-query item) query))
                                      mu4e--query-items-baseline))))
      (setq mail-baseline-reset-query nil)))

  (advice-add 'mu4e--query-items-queries-handler :before #'mail-baseline-reset-folder)

  ;; Use the regular completion UI (vertico) for folder prompts.
  (setq mu4e-completing-read-function #'completing-read)

  (setq mu4e-view-show-images t
        mu4e-headers-date-format "%Y-%m-%d"
        mu4e-confirm-quit nil)

  ;; mu4e links only react to M-RET and the mouse, and terminals don't
  ;; send the M-RET it binds.  Let RET open the link under point and
  ;; scroll as before everywhere else.
  (defun mail-view-link-at (pos)
    "URL of the link at POS: an HTML link (shr) or a plain one (mu4e)."
    (let ((url (or (get-text-property pos 'shr-url)
                   (get-text-property pos 'mu4e-url))))
      (and (stringp url) url)))

  (defun mail-view-ret ()
    "Open the link at point, or scroll the message if there is none."
    (interactive)
    (if-let ((url (mail-view-link-at (point))))
        (browse-url url)
      (call-interactively #'mu4e-scroll-up)))

  (with-eval-after-load 'mu4e-view
    (keymap-set mu4e-view-mode-map "RET" #'mail-view-ret))

  ;; g / G jump the cursor to the next / previous link, wrapping around,
  ;; and show where it points.  Unlike TAB (every button, header
  ;; addresses included), this stops only on links, HTML ones too.
  (defun mail-view-link-starts ()
    "Start positions of the links in the current buffer, in order."
    (let ((pos (point-min)) starts)
      (while (< pos (point-max))
        (let ((url (mail-view-link-at pos))
              (next (min (next-single-property-change pos 'shr-url nil (point-max))
                         (next-single-property-change pos 'mu4e-url nil (point-max)))))
          (when (and url (not (equal url (and (> pos (point-min))
                                             (mail-view-link-at (1- pos))))))
            (push pos starts))
          (setq pos next)))
      (nreverse starts)))

  (defun mail-view-next-link (&optional backward)
    "Move to the next link, or the previous one if BACKWARD; wrap around."
    (interactive)
    (let* ((starts (or (mail-view-link-starts)
                       (user-error "No links in this message")))
           (here (point))
           (target (if backward
                       (or (car (last (seq-filter (lambda (p) (< p here)) starts)))
                           (car (last starts)))
                     (or (seq-find (lambda (p) (> p here)) starts)
                         (car starts)))))
      (goto-char target)
      ;; Keep it to one line; tracking URLs run to hundreds of characters.
      (message "%s" (truncate-string-to-width
                     (format "Link %d/%d: %s" (1+ (seq-position starts target))
                             (length starts) (mail-view-link-at target))
                     (1- (frame-width)) nil nil "…"))))

  (defun mail-view-previous-link ()
    "Move to the previous link, wrapping around."
    (interactive)
    (mail-view-next-link t))

  (with-eval-after-load 'mu4e-view
    (keymap-set mu4e-view-mode-map "g" #'mail-view-next-link)
    (keymap-set mu4e-view-mode-map "G" #'mail-view-previous-link))

  ;; Konsole draws an emoji followed by U+FE0F, or joined with U+200D,
  ;; a column wider than Emacs expects.  On a full-width line that
  ;; spills over and scrolls the whole terminal frame up by one row.
  ;; Don't send those zero-width modifiers to the display at all.  They
  ;; only vanish with auto-composition off, since composed glyphs
  ;; bypass the display table.
  (defun mail-hide-emoji-modifiers ()
    "Stop displaying zero-width emoji modifiers in the current buffer."
    (auto-composition-mode -1)
    (unless buffer-display-table
      (setq buffer-display-table (if standard-display-table
                                     (copy-sequence standard-display-table)
                                   (make-display-table))))
    (dolist (c '(#xFE0F #x200D))
      (aset buffer-display-table c [])))

  (add-hook 'mu4e-headers-mode-hook #'mail-hide-emoji-modifiers)
  (add-hook 'mu4e-view-mode-hook #'mail-hide-emoji-modifiers)

  ;; C-c C-p runs `import' to grab a screenshot and blocks Emacs until
  ;; it returns, which it never does under Wayland.
  (with-eval-after-load 'message
    (keymap-unset message-mode-map "C-c C-p"))

  (global-set-key (kbd "C-c m") 'mu4e))

(provide 'init-mail)
;;; init-mail.el ends here
