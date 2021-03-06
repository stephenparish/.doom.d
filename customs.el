;;; ~/.doom.d/customs.el -*- lexical-binding: t; -*-

;(add-hook 'org-archive-hook (lambda ()
;                              "Set tags to archived headline"
;                              (counsel-org-tag)))

(defun jethro/org-process-inbox ()
  "Called in org-agenda-mode, processes all inbox items."
  (interactive)
  (org-agenda-bulk-mark-regexp "inbox:")
  (jethro/bulk-process-entries))

(defun zyro/create-new-task ()
  "Add task in buffer"
  (interactive)
  (+org/insert-item-below 1)
  (org-metaright)
  (insert (format "TODO %s" (read-string "Task name: ")))
  (newline)
  (insert (format "[[%s][Link to case]]" (read-string "URL: "))))

(defvar jethro/org-current-effort "1:00"
  "Current effort for agenda items.")

(defun jethro/my-org-agenda-set-effort (effort)
  "Set the effort property for the current headline."
  (interactive
   (list (read-string (format "Effort [%s]: " jethro/org-current-effort) nil nil jethro/org-current-effort)))
  (setq jethro/org-current-effort effort)
  (org-agenda-check-no-diary)
  (let* ((hdmarker (or (org-get-at-bol 'org-hd-marker)
                       (org-agenda-error)))
         (buffer (marker-buffer hdmarker))
         (pos (marker-position hdmarker))
         (inhibit-read-only t)
         newhead)
    (org-with-remote-undo buffer
      (with-current-buffer buffer
        (widen)
        (goto-char pos)
        (org-show-context 'agenda)
        (funcall-interactively 'org-set-effort nil jethro/org-current-effort)
        (end-of-line 1)
        (setq newhead (org-get-heading)))
      (org-agenda-change-all-lines newhead hdmarker))))

(defun jethro/org-agenda-process-inbox-item ()
  "Process a single item in the org-agenda."
  (org-with-wide-buffer
   (org-agenda-set-tags)
   (org-agenda-set-property)
   (org-agenda-priority)
   (call-interactively 'org-agenda-schedule)
   (call-interactively 'jethro/my-org-agenda-set-effort)
   (org-agenda-refile nil nil t)))

(defun jethro/bulk-process-entries ()
  (if (not (null org-agenda-bulk-marked-entries))
      (let ((entries (reverse org-agenda-bulk-marked-entries))
            (processed 0)
            (skipped 0))
        (dolist (e entries)
          (let ((pos (text-property-any (point-min) (point-max) 'org-hd-marker e)))
            (if (not pos)
                (progn (message "Skipping removed entry at %s" e)
                       (cl-incf skipped))
              (goto-char pos)
              (let (org-loop-over-headlines-in-active-region) (funcall 'jethro/org-agenda-process-inbox-item))
              ;; `post-command-hook' is not run yet.  We make sure any
              ;; pending log note is processed.
              (when (or (memq 'org-add-log-note (default-value 'post-command-hook))
                        (memq 'org-add-log-note post-command-hook))
                (org-add-log-note))
              (cl-incf processed))))
        (org-agenda-redo)
        (unless org-agenda-persistent-marks (org-agenda-bulk-unmark-all))
        (message "Acted on %d entries%s%s"
                 processed
                 (if (= skipped 0)
                     ""
                   (format ", skipped %d (disappeared before their turn)"
                           skipped))
                 (if (not org-agenda-persistent-marks) "" " (kept marked)")))))

(defun jethro/org-inbox-capture ()
  (interactive)
  "Capture a task in agenda mode."
  (org-capture nil "i"))

(defun counsel-narrow ()
  "Narrow with counsel"
  (interactive)
  (counsel-imenu)
  (org-narrow-to-subtree))

(defun +org-move-next-headline-and-narrow ()
  "Move to NEXT headline on same level and narrow"
  (interactive)
  (widen)
  (outline-forward-same-level 1)
  (org-narrow-to-subtree))

(defun +org-gtd-tasks ()
  "Open projects task file"
  (interactive)
  (find-file (concat (doom-project-root) '"next.org")))

(defun +org-gtd-references ()
  "GTD References file"
  (interactive)
  (find-file (read-file-name "Choose: " +org-gtd-refs-project)))

(defun helm-org-rifle-project-files ()
  "Rifle projects files"
  (interactive)
  (helm-org-rifle-directories (doom-project-root)))

(defun my-agenda-prefix ()
  (format "%s" (my-agenda-indent-string (org-current-level))))

(defun my-agenda-indent-string (level)
  (if (= level 1)
      ""
    (let ((str ""))
      (while (> level 2)
        (setq level (1- level)
              str (concat str "──")))
      (concat str "►"))))

(defvar org-archive-directory "~/.org/archives/")

(defun org-archive-file ()
  "Moves the current buffer to the archived folder"
  (interactive)
  (let ((old (or (buffer-file-name) (user-error "Not visiting a file")))
        (dir (read-directory-name "Move to: " org-archive-directory)))
    (write-file (expand-file-name (file-name-nondirectory old) dir) t)
    (delete-file old)))
(provide 'org-archive-file)

(defun org-capture-headline-finder (&optional arg)
  "Like `org-todo-list', but using only the current buffer's file."
  (interactive "P")
  (let ((org-agenda-files (list (buffer-file-name (current-buffer)))))
    (if (null (car org-agenda-files))
        (error "%s is not visiting a file" (buffer-name (current-buffer)))
      (counsel-org-agenda-headlines)))
  (goto-char (org-end-of-subtree)))
(defun +org-find-headline-narrow ()
  "Find a headline and narrow to it"
  (interactive)
  (widen)
  (let ((org-agenda-files (list (buffer-file-name (current-buffer)))))
    (if (null (car org-agenda-files))
        (error "%s is not visiting a file" (buffer-name (current-buffer)))
      (counsel-org-agenda-headlines)))
  (org-narrow-to-subtree))
;(defun org-capture-refile-hook ()
;  "Refile before finalizing capture to project TOOD file"
;  (interactive)
;  (let ((org-agenda-files (list (+org-capture-project-todo-file))))
;    (counsel-org-agenda-headlines)))
;(defun eos/org-custom-id-get (&optional pom create prefix)
;  "Get the CUSTOM_ID property of the entry at point-or-marker POM.
;   If POM is nil, refer to the entry at point. If the entry does
;   not have an CUSTOM_ID, the function returns nil. However, when
;   CREATE is non nil, create a CUSTOM_ID if none is present
;   already. PREFIX will be passed through to `org-id-new'. In any
;   case, the CUSTOM_ID of the entry is returned."
;  (interactive)
;  (org-with-point-at pom
;    (let ((id (org-entry-get nil "CUSTOM_ID")))
;      (cond
;       ((and id (stringp id) (string-match "\\S-" id))
;        id)
;       (create
;        (org-entry-put pom "CUSTOM_ID" (read-string (format "Set CUSTOM_ID for %s: " (substring-no-properties (org-format-outline-path (org-get-outline-path t nil))))
;                       (helm-org-rifle--make-default-custom-id (nth 4 (org-heading-components)))))
;        (org-id-add-location id (buffer-file-name (buffer-base-buffer)))
;        id)))))
;(defun eos/org-add-ids-to-headlines-in-file ()
;  "Add CUSTOM_ID properties to all headlines in the
;   current file which do not already have one."
;  (interactive)
;  (org-map-entries (lambda () (eos/org-custom-id-get (point) 'create))))
;(add-hook 'org-capture-before-finalize-hook
;          (lambda () (eos/org-custom-id-get (point) '(create))))
(defun org-update-cookies-after-save()
  (interactive)
  (let ((current-prefix-arg '(4)))
    (org-update-statistics-cookies "ALL")))

(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'before-save-hook 'org-update-cookies-after-save nil 'make-it-local)))
(provide 'org-update-cookies-after-save)
(setq-default truncate-lines t)

(defun jethro/truncate-lines-hook ()
  (setq truncate-lines nil))

(add-hook 'text-mode-hook 'jethro/truncate-lines-hook)

;;; Hide all drawers

;(defun org-cycle-hide-all-drawers ()
;  "Hide all drawers"
;  (interactive)
;  (org-cycle-hide-drawers 'all))

;(defun org-cycle-hide-drawers (state)
;  "Re-hide all drawers after a visibility state change."
;  (when (and (derived-mode-p 'org-mode)
;             (not (memq state '(overview folded contents))))
;    (save-excursion
;      (let* ((globalp (memq state '(contents all)))
;             (beg (if globalp
;                    (point-min)
;                    (point)))
;             (end (if globalp
;                    (point-max)
;                    (if (eq state 'children)
;                      (save-excursion
;                        (outline-next-heading)
;                        (point))
;                      (org-end-of-subtree t)))))
;        (goto-char beg)
;        (while (re-search-forward org-drawer-regexp end t)
;          (save-excursion
;            (beginning-of-line 1)
;            (when (looking-at org-drawer-regexp)
;              (let* ((start (1- (match-beginning 0)))
;                     (limit
;                       (save-excursion
;                         (outline-next-heading)
;                           (point)))
;                     (msg (format
;                            (concat
;                              "org-cycle-hide-drawers:  "
;                              "`:END:`"
;                              " line missing at position %s")
;                            (1+ start))))
;                (if (re-search-forward "^[ \t]*:END:" limit t)
;                  (outline-flag-region start (point-at-eol) t)
;                  (user-error msg))))))))))

;------------ Show calendar busy state
(defface busy-1  '((t :foreground "black" :background "#eceff1")) "")
(defface busy-2  '((t :foreground "black" :background "#cfd8dc")) "")
(defface busy-3  '((t :foreground "black" :background "#b0bec5")) "")
(defface busy-4  '((t :foreground "black" :background "#90a4ae")) "")
(defface busy-5  '((t :foreground "white" :background "#78909c")) "")
(defface busy-6  '((t :foreground "white" :background "#607d8b")) "")
(defface busy-7  '((t :foreground "white" :background "#546e7a")) "")
(defface busy-8  '((t :foreground "white" :background "#455a64")) "")
(defface busy-9  '((t :foreground "white" :background "#37474f")) "")
(defface busy-10 '((t :foreground "white" :background "#263238")) "")

(defadvice calendar-generate-month
  (after highlight-weekend-days (month year indent) activate)
  "Highlight weekend days"
  (dotimes (i 31)
    (let ((date (list month (1+ i) year))
          (count (length (org-agenda-get-day-entries
                          "~/.org/gtd/next.org" (list month (1+ i) year)))))
      (cond ((= count 0) ())
            ((= count 1) (calendar-mark-visible-date date 'busy-1))
            ((= count 2) (calendar-mark-visible-date date 'busy-2))
            ((= count 3) (calendar-mark-visible-date date 'busy-3))
            ((= count 4) (calendar-mark-visible-date date 'busy-4))
            ((= count 5) (calendar-mark-visible-date date 'busy-5))
            ((= count 6) (calendar-mark-visible-date date 'busy-6))
            ((= count 7) (calendar-mark-visible-date date 'busy-7))
            ((= count 8) (calendar-mark-visible-date date 'busy-8))
            ((= count 9) (calendar-mark-visible-date date 'busy-9))
            (t  (calendar-mark-visible-date date 'busy-10))))))
