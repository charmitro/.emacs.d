;;; init-dape.el --- Debug Adapter Protocol support via dape -*- lexical-binding: t -*-
;;; Commentary:
;; DAP debugging with `dape'.  Currently set up for Go via Delve (`dlv').
;; Requires Emacs 29.1+ and the `dlv' binary on `exec-path'.
;;; Code:

(when (and (not (version< emacs-version "29.1"))
           (maybe-require-package 'dape))

  ;; Install dape's own keymap under C-c d, to match the C-c prefix used
  ;; elsewhere in this config, instead of the default C-x C-a.
  (setq dape-key-prefix "\C-cd")

  ;; Only `dape' itself is autoloaded, so the rest of the prefix map would be
  ;; void until the first session.  Declare the autoloads and mirror the core
  ;; of `dape-global-map' so every binding works from a cold start; loading
  ;; dape.el then installs the full map over this one at the same prefix.
  (defvar init-dape-map
    (let ((map (make-sparse-keymap)))
      (dolist (binding '(("d" . dape)                 ; start a session
                         ("c" . dape-continue)
                         ("n" . dape-next)            ; step over
                         ("s" . dape-step-in)
                         ("o" . dape-step-out)
                         ("p" . dape-pause)
                         ("r" . dape-restart)
                         ("u" . dape-until)           ; run to point
                         ("b" . dape-breakpoint-toggle)
                         ("B" . dape-breakpoint-remove-all)
                         ("F" . dape-breakpoint-function)
                         ("l" . dape-breakpoint-log)
                         ("e" . dape-breakpoint-expression)
                         ("x" . dape-evaluate-expression)
                         ("w" . dape-watch-dwim)
                         ("i" . dape-info)
                         ("R" . dape-repl)
                         ("t" . dape-select-thread)
                         ("S" . dape-select-stack)
                         ("D" . dape-disconnect-quit)
                         ("q" . dape-quit)))
        (autoload (cdr binding) "dape" nil t)
        (define-key map (car binding) (cdr binding)))
      map)
    "Cold-start mirror of `dape-global-map', bound at `dape-key-prefix'.")

  (global-set-key dape-key-prefix init-dape-map)

  (defun init-dape-package-dir ()
    "Return the Go package directory to debug: the current buffer's directory.
Falls back to `dape-cwd' for buffers not visiting a file."
    (if-let* ((file (buffer-file-name)))
        (file-name-directory file)
      (dape-cwd)))

  (defconst init-dape-tsdb-gateway-commands
    '("read --config tsdb-gateway.dev.yaml --debug"
      "api --config tsdb-gateway.dev.yaml --debug"
      "mcp --config tsdb-gateway.dev.yaml --debug"
      "cjob --dry-run --cron-run-now refresh-book-snapshots --config tsdb-gateway.dev.yaml --debug"
      "cjob --dry-run --cron-run-now refresh-caggs <start> <end> --config tsdb-gateway.dev.yaml --debug"
      "control --dry-run registry-metadata-sync --config tsdb-gateway.dev.yaml --debug"
      "export-chunks --dry-run <hypertables> --config tsdb-gateway.dev.yaml --debug"
      "migrate index --dry-run --config tsdb-gateway.dev.yaml --debug")
    "Suggested argv lines for the tsdb-gateway binary.
The one-shot commands come first with `--dry-run': they run a bounded
piece of logic and exit, so a breakpoint fires within seconds, and
`control'/`cjob' write to the *primary* database when not dry-run.")

  (defun init-dape-tsdb-gateway-p (config)
    "Ensure `dlv' exists and that we are inside the tsdb-gateway project.
`dape--config-ensure' binds `default-directory' to the config's
`command-cwd', i.e. the project root."
    (dape-ensure-command config)
    (unless (file-directory-p "cmd/tsdb-gateway")
      (user-error "Not inside the tsdb-gateway project"))
    t)

  (defun init-dape-tsdb-gateway-args ()
    "Prompt for a tsdb-gateway argv line, returned as a vector.
`dape--minibuffer-hint' re-evaluates every config value on each keystroke
to render the hint, and does so with `enable-recursive-minibuffers' bound
to nil.  Prompting there signals \"Command attempted to use minibuffer
while in minibuffer\", which dape then displays in place of the value, so
return a placeholder instead and only prompt for real at launch."
    (if (not enable-recursive-minibuffers)
        ["<picked at launch>"]
      (vconcat (split-string-shell-command
                (completing-read "tsdb-gateway args: "
                                 init-dape-tsdb-gateway-commands nil nil)))))

  ;; Remember breakpoints between sessions, and save buffers before launching.
  (add-hook 'after-init-hook #'dape-breakpoint-global-mode)
  (setq dape-buffer-window-arrangement 'right)

  ;; Open the right-hand info panels wide enough to leave the source an
  ;; 80-column view plus room for line numbers and fringes, giving the rest
  ;; of the frame to the panels.  Only applies when a panel window is
  ;; created, so a border dragged by hand keeps its size afterwards.
  (defun init-dape-info-window-width (window)
    "Resize dape info WINDOW to what is left after an 80-column source view."
    (let* ((frame-cols (frame-width (window-frame window)))
           (width (max 30 (min (/ frame-cols 2) (- frame-cols 90)))))
      (ignore-errors
        (window-resize window (- width (window-total-width window)) t))))

  ;; In the `dape' prompt, corfu previews the highlighted candidate with a
  ;; `display' overlay ending at `point-max', which hides dape's config hint
  ;; overlay sitting there.  The minibuffer then shrinks to one line and the
  ;; popup has nowhere left to draw.  Turn the preview off and instead
  ;; refresh the hint for the highlighted candidate.
  (defvar-local init-dape--hinted-index nil
    "Corfu index the dape hint was last computed for.")

  (defun init-dape--hint-corfu-selection ()
    "Show dape's config hint for the candidate highlighted in corfu."
    (let ((index (and (bound-and-true-p corfu--candidates) corfu--index)))
      (unless (eql index init-dape--hinted-index)
        (setq init-dape--hinted-index index)
        (pcase-let ((`(,beg ,end . ,_) completion-in-region--data))
          (if (not (and index (>= index 0) end (= end (point-max))))
              (dape--minibuffer-hint)
            ;; dape reads the config from the buffer text, so put the
            ;; candidate there just long enough to compute the hint.
            (let* ((start (+ beg (length corfu--base)))
                   (typed (buffer-substring start end))
                   (pt (point))
                   (inhibit-modification-hooks t)
                   (buffer-undo-list t))
              ;; The swap bumps `buffer-modified-tick', so corfu-terminal
              ;; re-measures the popup position; drop the old popup first or
              ;; it gets counted in the measurement and the popup drifts.
              (corfu--popup-hide)
              (delete-region start end)
              (goto-char start)
              (insert (substring-no-properties
                       (nth index corfu--candidates)))
              (unwind-protect
                  (dape--minibuffer-hint)
                (delete-region start (point-max))
                (goto-char start)
                (insert typed)
                (goto-char pt)
                (move-overlay dape--minibuffer-hint-overlay
                              (point-max) (point-max)))))))))

  (defun init-dape--minibuffer-setup ()
    "Keep corfu's popup usable in the `dape' config prompt."
    (when (memq #'dape--minibuffer-hint after-change-functions)
      (setq-local corfu-preview-current nil)
      ;; Run before corfu's global `corfu--post-command' redraws the popup,
      ;; else the popup gets placed against the stale hint and drifts right.
      (add-hook 'post-command-hook #'init-dape--hint-corfu-selection -90 t)))

  ;; Depth 90 so this runs after dape's own setup has installed its hooks.
  (add-hook 'minibuffer-setup-hook #'init-dape--minibuffer-setup 90)

  ;; Make the stopped line easy to spot: dape leaves its face blank, so only
  ;; the fringe arrow marks it.  Highlight the whole line instead, in a dim
  ;; amber from ayu-mirage's yellow accent: `highlight' and `hl-line' are
  ;; barely off the background there, and `region' would look like a mark.
  (with-eval-after-load 'dape
    (set-face-attribute 'dape-source-line-face nil
                        :background "#4a4430" :extend t))

  ;; Keep the stopped line in the middle of the window, so each step
  ;; scrolls the code by a line and what comes next stays in view.
  (add-hook 'dape-display-source-hook #'recenter)

  ;; dape hides the info panels' mode lines when they sit on the side.  GUI
  ;; frames can still resize stacked panels by dragging the dividers, but a
  ;; terminal frame has nothing else to grab, so keep the mode lines there.
  (defun init-dape--info-tty-mode-line ()
    "Restore the mode line of a dape info buffer created on a tty frame."
    (unless (display-graphic-p)
      (kill-local-variable 'mode-line-format)))
  (add-hook 'dape-info-parent-mode-hook #'init-dape--info-tty-mode-line)

  ;; dape tags info buffers with a `dape-info-N' category.  Emacs 29's
  ;; `buffer-match-p' has no (category . X) condition, so read it off the
  ;; action alist ourselves.
  (defun init-dape-info-buffer-p (_buffer action)
    "Non-nil if ACTION is displaying one of dape's info buffers."
    (when-let ((category (alist-get 'category (cdr action))))
      (string-prefix-p "dape-info-" (symbol-name category))))

  (add-to-list 'display-buffer-alist
               '(init-dape-info-buffer-p
                 nil
                 (window-width . init-dape-info-window-width)))

  ;; `dape-request-timeout' defaults to `jsonrpc-default-request-timeout' (10s).
  ;; A `dlv' launch in "debug" mode compiles the package and then loads DWARF
  ;; for the result, which blows past 10s on any sizeable Go tree -- dape then
  ;; tears down the socket ("Writing to process: Connection reset by peer").
  (setq dape-request-timeout 120)

  (with-eval-after-load 'dape
    (add-hook 'dape-compile-hook #'kill-buffer)
    (add-hook 'dape-start-hook (lambda () (save-some-buffers t t)))

    ;; Go / Delve.  `dlv debug' takes a *package*, so default `:program' to
    ;; the directory of the buffer you invoke `dape' from -- `dape-cwd' would
    ;; give the project root, which fails with "no Go files in ..." for any
    ;; repo whose main package is not at the top level (cmd/foo/main.go).
    ;; `:cwd' stays the project root, matching `go run ./cmd/foo' from there.
    (add-to-list 'dape-configs
                 `(dlv-go
                   modes (go-mode go-ts-mode)
                   ensure dape-ensure-command
                   command "dlv"
                   command-args ("dap" "--listen" "127.0.0.1:55878")
                   command-cwd dape-command-cwd
                   command-insert-stderr t
                   port 55878
                   :type "go"
                   :request "launch"
                   :mode "debug"
                   :cwd dape-cwd
                   :program init-dape-package-dir))

    ;; tsdb-gateway is one binary that runs a different service per first
    ;; argument, so prompt for the argv line instead of pinning one mode.
    ;; Only offered inside that project -- see `init-dape-tsdb-gateway-p'.
    (add-to-list 'dape-configs
                 `(dlv-tsdb
                   modes (go-mode go-ts-mode)
                   ensure init-dape-tsdb-gateway-p
                   command "dlv"
                   command-args ("dap" "--listen" "127.0.0.1:55878")
                   command-cwd dape-command-cwd
                   command-insert-stderr t
                   port 55878
                   :type "go"
                   :request "launch"
                   :mode "debug"
                   :cwd dape-cwd
                   :program "./cmd/tsdb-gateway"
                   :args (init-dape-tsdb-gateway-args)))))

;; Delve cuts values in variables responses at 256 characters (trailing
;; "...") and has no setting for it, but an evaluate request in the
;; "clipboard" context returns the value untruncated.  Show that in its own
;; buffer.  Nested "..." is Delve's one-level load depth; expand with TAB.
(with-eval-after-load 'dape
  (defun init-dape-show-full-value ()
    "Show the untruncated value of the variable on the current line."
    (interactive nil dape-info-scope-mode dape-info-watch-mode)
    (let* ((variable (get-text-property (line-beginning-position)
                                        'dape--variable))
           (expression (or (plist-get variable :evaluateName)
                           (plist-get variable :name)))
           (conn (dape--live-connection 'stopped)))
      (unless expression
        (user-error "No variable on this line"))
      (dape--evaluate-expression
       conn (plist-get (dape--current-stack-frame conn) :id)
       expression "clipboard"
       (lambda (body error)
         (if error
             (message "Failed to evaluate `%s': %s" expression error)
           (with-current-buffer (get-buffer-create "*dape-value*")
             (special-mode)
             (visual-line-mode)
             (let ((inhibit-read-only t))
               (erase-buffer)
               (insert (propertize expression 'face 'font-lock-variable-name-face)
                       "\n\n" (plist-get body :result) "\n")
               (goto-char (point-min)))
             (display-buffer (current-buffer))))))))

  (define-key dape-info-scope-mode-map "v" #'init-dape-show-full-value)
  (define-key dape-info-watch-mode-map "v" #'init-dape-show-full-value))

;; A breakpoint the adapter refuses only shows up greyed out: dape keeps the
;; verified flag but drops the reason Delve sends with it ("could not find
;; FILE:LINE", "unable to set breakpoint", ...).  Print that reason in the
;; REPL so a grey breakpoint can be diagnosed.
(with-eval-after-load 'dape
  (defvar init-dape--reported-unverified nil
    "Refusals already printed this session.
dape resends every breakpoint of a file whenever one of them changes,
so without this the same refusal would be printed over and over.")
  (add-hook 'dape-start-hook
            (lambda () (setq init-dape--reported-unverified nil)))

  (defun init-dape--report-unverified (command arguments body)
    "Print why breakpoints in the reply BODY to COMMAND were refused.
ARGUMENTS is the request, used to name the breakpoints."
    (cl-loop
     with path = (plist-get (plist-get arguments :source) :path)
     for requested across (or (plist-get arguments :breakpoints) [])
     for result across (or (plist-get body :breakpoints) [])
     for report = (format "Breakpoint %s not set: %s\n"
                          (if (eq command :setFunctionBreakpoints)
                              (plist-get requested :name)
                            (format "%s:%s"
                                    (if path (file-relative-name path) "?")
                                    (plist-get requested :line)))
                          (or (plist-get result :message) "no reason given"))
     unless (or (eq (plist-get result :verified) t)
                (member report init-dape--reported-unverified))
     do (push report init-dape--reported-unverified)
        (dape--repl-insert-error report)))

  ;; In a server, other goroutines keep reaching the breakpoint while you
  ;; step.  Delve then stops in that goroutine, keeps the original step
  ;; pending and refuses every further step ("Unable to step while the
  ;; previous step is interrupted by a breakpoint"); `continue' only
  ;; resumes that original step.  So once stopped at a breakpoint, restrict
  ;; every breakpoint to the goroutine that hit it, and lift the
  ;; restriction on continue so any goroutine can stop again.
  (defvar init-dape--follow-goid nil
    "Goroutine all breakpoints are restricted to while stepping, or nil.")
  (add-hook 'dape-start-hook (lambda () (setq init-dape--follow-goid nil)))

  (defun init-dape--follow-arguments (command arguments)
    "Return ARGUMENTS for COMMAND restricted to `init-dape--follow-goid'.
Log points never stop the program, so they are left alone."
    (if (not init-dape--follow-goid)
        arguments
      (let ((goid (format "runtime.curg.goid == %d" init-dape--follow-goid)))
        (plist-put
         (copy-sequence arguments) :breakpoints
         (cl-map 'vector
                 (lambda (bp)
                   (if (plist-get bp :logMessage)
                       bp
                     (let ((condition (plist-get bp :condition)))
                       (plist-put (copy-sequence bp) :condition
                                  (if condition
                                      (format "(%s) && %s" condition goid)
                                    goid)))))
                 (plist-get arguments :breakpoints))))))

  (defun init-dape--resend-breakpoints ()
    "Send every breakpoint to the live adapters again."
    (dape--breakpoint-notify-all)
    (init-dape--sync-function-breakpoints))

  (cl-defmethod dape-handle-event :after (_conn (_event (eql stopped)) body)
    "Follow the goroutine that stopped at a breakpoint."
    (when (member (plist-get body :reason) '("breakpoint" "function breakpoint"))
      (setq init-dape--follow-goid (plist-get body :threadId))
      (init-dape--resend-breakpoints)
      (dape--repl-insert
       (format "Following goroutine %d: other goroutines skip breakpoints until you continue\n"
               init-dape--follow-goid))))

  (defun init-dape--request-advice (request conn command arguments &optional cb)
    "Around advice for `dape-request'.
Restricts breakpoints to the followed goroutine, reports refused
breakpoints, and stops following when execution continues."
    (pcase command
      ((or :setBreakpoints :setFunctionBreakpoints)
       (funcall request conn command
                (init-dape--follow-arguments command arguments)
                (lambda (body error)
                  (unless error
                    (init-dape--report-unverified command arguments body))
                  (when cb (funcall cb body error)))))
      (:continue
       ;; Sent ahead of the continue, so Delve has them before it resumes.
       (when init-dape--follow-goid
         (setq init-dape--follow-goid nil)
         (init-dape--resend-breakpoints))
       (funcall request conn command arguments cb))
      (_ (funcall request conn command arguments cb))))

  (advice-add 'dape-request :around #'init-dape--request-advice))

;; Over DAP, Delve's console only knows a few `dlv ...' commands; breakpoints
;; have to come from the client.  Give dape's REPL dlv-style `break' and
;; `clear' that set them through dape, taking LOCATION as FILE:LINE (FILE
;; may be any path suffix within the project), LINE in the current frame's
;; file, or a function name such as main.main or pkg.(*T).Method.
(with-eval-after-load 'dape
  (defun init-dape--repl-frame-file ()
    "Return the source file of the selected stack frame, or nil."
    (when-let ((conn (dape--live-connection 'stopped t)))
      (plist-get (plist-get (dape--current-stack-frame conn) :source) :path)))

  (defun init-dape--repl-resolve-file (file)
    "Return the absolute path of FILE, matched as a suffix within the project."
    (let* ((frame-file (init-dape--repl-frame-file))
           (dir (if frame-file (file-name-directory frame-file) default-directory))
           (project (project-current nil dir))
           (root (if project (project-root project) dir))
           (direct (expand-file-name file root)))
      (if (or (file-name-absolute-p file) (file-exists-p direct))
          direct
        (let* ((suffix (concat "/" file))
               (matches (and project
                             (seq-filter (lambda (f) (string-suffix-p suffix f))
                                         (project-files project)))))
          (pcase matches
            ('() (user-error "No file matching `%s'" file))
            (`(,match) match)
            (_ (user-error "`%s' is ambiguous: %s" file
                           (mapconcat #'file-relative-name matches ", "))))))))

  (defun init-dape--repl-location (location)
    "Parse LOCATION into (FILE . LINE), or a function name string."
    (cond
     ((string-match "\\`\\(.+\\):\\([0-9]+\\)\\'" location)
      ;; Read both groups before resolving, which clobbers the match data.
      (let ((file (match-string 1 location))
            (line (string-to-number (match-string 2 location))))
        (cons (init-dape--repl-resolve-file file) line)))
     ((string-match-p "\\`[0-9]+\\'" location)
      ;; While the program runs there is no frame, so fall back to the
      ;; file buffer used most recently, i.e. the one you came from.
      (cons (or (init-dape--repl-frame-file)
                (seq-some #'buffer-file-name (buffer-list))
                (user-error "No stopped frame or file buffer to take the file from"))
            (string-to-number location)))
     (t location)))

  (defun init-dape--repl-at-line (file line fn)
    "Call FN with point on LINE of FILE."
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-min))
        (forward-line (1- line))
        (funcall fn))))

  (defun init-dape--sync-function-breakpoints ()
    "Send the current function breakpoints to every live adapter."
    (dolist (conn (dape--live-connections))
      (when (dape--initialized-p conn)
        (dape--set-function-breakpoints conn)))
    (run-hooks 'dape-update-ui-hook))

  (defun init-dape-repl-break (&rest args)
    "REPL command: break LOCATION [if CONDITION]."
    (unless args
      (user-error "Usage: break LOCATION [if CONDITION]"))
    (let* ((location (init-dape--repl-location (car args)))
           (condition (and (equal (cadr args) "if")
                           (string-join (cddr args) " "))))
      (if (stringp location)
          (progn
            (when condition
              (user-error "Conditions are only supported on FILE:LINE"))
            (push (make-dape--function-breakpoint :name location)
                  dape--breakpoints)
            (init-dape--sync-function-breakpoints)
            (dape--repl-insert (format "Breakpoint set on %s\n" location)))
        (pcase-let ((`(,file . ,line) location))
          (init-dape--repl-at-line
           file line
           (lambda ()
             (dape--breakpoint-place (and condition 'expression) condition)))
          (dape--repl-insert
           (format "Breakpoint set at %s:%d%s\n"
                   (file-relative-name file) line
                   (if condition (format " if %s" condition) "")))))))

  (defun init-dape-repl-clear (&optional location)
    "REPL command: clear LOCATION, or every breakpoint when omitted."
    (if (not location)
        (progn
          ;; `dape-breakpoint-remove-all' leaves function breakpoints alone.
          (dape-breakpoint-remove-all)
          (mapc #'dape--breakpoint-remove
                (seq-filter #'dape--function-breakpoint-p dape--breakpoints))
          (init-dape--sync-function-breakpoints)
          (dape--repl-insert "All breakpoints cleared\n"))
      (pcase (init-dape--repl-location location)
        ((and (pred stringp) name)
         (let ((matches (seq-filter
                         (lambda (bp)
                           (and (dape--function-breakpoint-p bp)
                                (equal (dape--function-breakpoint-name bp) name)))
                         dape--breakpoints)))
           (unless matches
             (user-error "No breakpoint on %s" name))
           (mapc #'dape--breakpoint-remove matches)
           (init-dape--sync-function-breakpoints)))
        (`(,file . ,line)
         (init-dape--repl-at-line file line #'dape-breakpoint-remove-at-point)))
      (dape--repl-insert (format "Breakpoint cleared at %s\n" location))))

  (defun init-dape--repl-command (fn)
    "Return FN wrapped to print its `user-error' message in the REPL.
dape itself only reports the error symbol."
    (lambda (&rest args)
      (condition-case err
          (apply fn args)
        (user-error
         (dape--repl-insert-error (concat (error-message-string err) "\n"))))))

  ;; Appended so the existing shorthands keep their letters: "b" stays
  ;; `breakpoints' and "c" `continue'; these get "br" and "cl".
  (add-to-list 'dape-repl-commands
               `("break" . ,(init-dape--repl-command #'init-dape-repl-break)) t)
  (add-to-list 'dape-repl-commands
               `("clear" . ,(init-dape--repl-command #'init-dape-repl-clear)) t))

(provide 'init-dape)

;;; init-dape.el ends here
