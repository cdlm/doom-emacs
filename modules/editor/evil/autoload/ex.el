;;; editor/evil/autoload/ex.el -*- lexical-binding: t; -*-

(defvar +evil--flag nil)

(defun +evil--ex-match-init (name &optional face update-hook)
  (with-current-buffer evil-ex-current-buffer
    (cond
     ((eq +evil--flag 'start)
      (evil-ex-make-hl name
        :face (or face 'evil-ex-lazy-highlight)
        :update-hook (or update-hook #'evil-ex-pattern-update-ex-info))
      (setq +evil--flag 'update))

     ((eq +evil--flag 'stop)
      (evil-ex-delete-hl name)))))

(defun +evil--ex-buffer-match (arg &optional hl-name flags beg end)
  (when (and (eq +evil--flag 'update)
             evil-ex-substitute-highlight-all
             (not (zerop (length arg))))
    (condition-case lossage
        (let* ((pattern (evil-ex-make-substitute-pattern
                         arg
                         (or flags (list))))
               (range (or (evil-copy-range evil-ex-range)
                          (evil-range (or beg (line-beginning-position))
                                      (or end (line-end-position))
                                      'line
                                      :expanded t))))
          (evil-expand-range range)
          (evil-ex-hl-set-region hl-name
                                 (max (evil-range-beginning range) (window-start))
                                 (min (evil-range-end range) (window-end)))
          (evil-ex-hl-change hl-name pattern))
      (end-of-file
       (evil-ex-pattern-update-ex-info nil "incomplete replacement"))
      (user-error
       (evil-ex-pattern-update-ex-info nil (format "?%s" lossage))))))

;;;###autoload
(defun +evil-ex-regexp-match (flag &optional arg invert)
  (let ((hl-name 'evil-ex-buffer-match)
        (+evil--flag flag))
    (with-selected-window (minibuffer-selected-window)
      (+evil--ex-match-init hl-name)
      (cl-destructuring-bind (&optional arg flags)
          (evil-delimited-arguments arg 2)
        (let ((evil-ex-substitute-global
               (if invert
                   (not evil-ex-substitute-global)
                 evil-ex-substitute-global)))
          (+evil--ex-buffer-match
           arg hl-name (string-to-list flags)))))))


;;
;;; Ex Commands

;;;###autoload (autoload '+evil:align "editor/evil/autoload/ex" nil t)
(evil-define-operator +evil:align (beg end pattern &optional flags)
  "Ex interface to `align-regexp'. PATTERN is a vim-style regexp. If BANG,
repeat the alignment for all matches (otherwise just the first match on each
line)."
  (interactive "<r><//>")
  (align-regexp
   beg end
   (concat "\\(\\s-*\\)" (evil-transform-vim-style-regexp pattern))
   1 1 (memq ?g flags)))

;;;###autoload (autoload '+evil:align-right "editor/evil/autoload/ex" nil t)
(evil-define-operator +evil:align-right (beg end pattern &optional flags)
  "Like `+evil:align', except alignments are right-justified. PATTERN is a
vim-style regexp. If BANG, repeat the alignment for all matches (otherwise just
the first match on each line)."
  (interactive "<r><//>")
  (align-regexp
   beg end
   (concat "\\(" (evil-transform-vim-style-regexp pattern) "\\)")
   -1 1 (memq ?g flags)))

;; ;;;###autoload (autoload '+evil:sort "editor/evil/autoload/ex" nil nil)
;; (evil-define-command +evil:sort (beg end &optional pattern flags reverse)
;;   (interactive "<r><//><!>"))

;;;###autoload (autoload '+evil:open-scratch-buffer "editor/evil/autoload/ex" nil t)
(evil-define-operator +evil:open-scratch-buffer (bang)
  (interactive "<!>")
  (doom/open-scratch-buffer bang))

;;;###autoload (autoload '+evil:pwd "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:pwd (bang)
  "Display the current working directory. If BANG, copy it to your clipboard."
  (interactive "<!>")
  (if (not bang)
      (pwd)
    (kill-new default-directory)
    (message "Copied to clipboard")))

;;;###autoload (autoload '+evil:make "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:make (arguments &optional bang)
  "Run make with ARGUMENTS.
If BANG is non-nil, open compilation output in a comint buffer.

If BANG, then run ARGUMENTS as a full command. This command understands vim file
modifiers (like %:p:h). See `+evil-resolve-vim-path-a' for details."
  (interactive "<sh><!>")
  (+evil:compile (format "make %s"
                        (evil-ex-replace-special-filenames
                         arguments))
                bang))

;;;###autoload (autoload '+evil:compile "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:compile (arguments &optional bang)
  "Run `compile-command' with ARGUMENTS.
If BANG is non-nil, open compilation output in a comint buffer.

This command understands vim file modifiers (like %:p:h). See
`+evil-resolve-vim-path-a' for details."
  (interactive "<sh><!>")
  (compile (evil-ex-replace-special-filenames
            (format "%s %s"
                    (eval compile-command)
                    arguments))
           bang))

;;;###autoload (autoload '+evil:reverse-lines "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:reverse-lines (beg end)
  "Reverse lines between BEG and END."
  (interactive "<r>")
  (reverse-region beg end))

;;;###autoload (autoload '+evil:cd "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:cd (&optional path)
  "Change `default-directory' with `cd'."
  (interactive "<f>")
  (let ((path (or path "~")))
    (cd path)
    (message "Changed directory to '%s'" (abbreviate-file-name (expand-file-name path)))))

;;;###autoload (autoload '+evil:kill-all-buffers "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:kill-all-buffers (&optional bang)
  "Kill all buffers. If BANG, kill current session too."
  (interactive "<!>")
  (if (and bang (fboundp '+workspace/kill-session))
      (+workspace/kill-session)
    (doom/kill-all-buffers)))

;;;###autoload (autoload '+evil:kill-matching-buffers "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:kill-matching-buffers (&optional bang pattern)
  "Kill all buffers matching PATTERN regexp. If BANG, only match project
buffers."
  (interactive "<a>")
  (doom/kill-matching-buffers pattern bang))

;;;###autoload (autoload '+evil:help "editor/evil/autoload/ex" nil t)
(evil-define-command +evil:help (&optional bang query)
  "Look up help documentation for QUERY in Emacs documentation.

If BANG, search Doom documentation."
  (interactive "<!><a>")
  (if bang
      (doom/help-search query)
    (cond ((or (null query) (string-empty-p (string-trim query)))
           (call-interactively
            (or (command-remapping #'apropos)
                #'apropos)))
          ((string-match-p "^ *:[a-z]" query)
           (let* ((modules
                   (cl-loop for path in (doom-module-load-path 'all)
                            for (cat . mod) = (doom-module-from-path path)
                            for format = (format "%s %s" cat mod)
                            if (doom-module-p cat mod)
                            collect (propertize format 'module (list cat mod))
                            else if (and cat mod)
                            collect (propertize format
                                                'face 'font-lock-comment-face
                                                'module (list cat mod))))
                  (module (completing-read "Describe module: " modules nil t query))
                  (key (get-text-property 0 'module module)))
             (doom/help-modules key)))
          ((and (string-match-p "\\(?:SPC\\|[CMsSH]-[^ ]\\|<[^>]+>\\)" query)
                (helpful-key (kbd (string-trim query)))))
          ((apropos query t)))))
