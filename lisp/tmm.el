;;; tmm.el --- text mode access to menu-bar  -*- lexical-binding: t -*-

;; Copyright (C) 1994-1996, 2000-2025 Free Software Foundation, Inc.

;; Author: Ilya Zakharevich <ilya@math.mps.ohio-state.edu>
;; Maintainer: emacs-devel@gnu.org
;; Keywords: convenience

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides text mode access to the menu bar.

;;; Code:

(require 'electric)
(require 'text-property-search)

(defgroup tmm nil
  "Text mode access to menu-bar."
  :prefix "tmm-"
  :group 'menu)

;;; The following will be localized, added only to pacify the compiler.
(defvar tmm-short-cuts)
(defvar tmm-old-mb-map nil)
(defvar tmm-c-prompt nil)
(defvar tmm-km-list)
(defvar tmm-next-shortcut-digit)
(defvar tmm-table-undef)

;;;###autoload (define-key global-map "\M-`" 'tmm-menubar)

;;;###autoload
(defun tmm-menubar (&optional x-position)
  "Text-mode emulation of looking and choosing from a menubar.
See the documentation for `tmm-prompt'.
X-POSITION, if non-nil, specifies a horizontal position within the menu bar;
we make that menu bar item (the one at that position) the default choice.

Note that \\[menu-bar-open] by default drops down TTY menus; if you want it
to invoke `tmm-menubar' instead, customize the variable
`tty-menu-open-use-tmm' to a non-nil value."
  (interactive)
  (run-hooks 'menu-bar-update-hook)
  (if isearch-mode
      (isearch-tmm-menubar)
    (let ((menu-bar (menu-bar-keymap))
          (menu-bar-item-cons (and x-position
                                   (menu-bar-item-at-x x-position))))
      (tmm-prompt menu-bar
                  nil
                  (and menu-bar-item-cons (car menu-bar-item-cons))))))

;;;###autoload
(defun tmm-menubar-mouse (event)
  "Text-mode emulation of looking and choosing from a menubar.
This command is used when you click the mouse in the menubar
on a console which has no window system but does have a mouse.
See the documentation for `tmm-prompt'."
  (interactive "e")
  (tmm-menubar (car (posn-x-y (event-start event)))))

(defcustom tmm-mid-prompt "==>"
  "String to insert between shortcut and menu item.
If nil, there will be no shortcuts.  It should not consist only of spaces,
or else the correct item might not be found in the `*Completions*' buffer."
  :type '(choice (const :tag "No shortcuts" nil)
                 string))

(defcustom tmm-completion-prompt
  "Press M-v/PageUp key to reach this buffer from the minibuffer.
Alternatively, You can use Up/Down keys (or your History keys) to change
the item in the minibuffer, and press RET when you are done, or press
the %s to pick up your choice.
Type ^ to go to the parent menu.  Type C-g or ESC ESC ESC to cancel.
"
  "Help text to insert on the top of the completion buffer.
To save space, you can set this to nil,
in which case the standard introduction text is deleted too."
  :type '(choice string (const nil)))

(defcustom tmm-shortcut-style '(downcase upcase)
  "What letters to use as menu shortcuts.
Must be either one of the symbols `downcase' or `upcase',
or else a list of the two in the order you prefer."
  :type '(choice (const downcase)
		 (const upcase)
		 (repeat (choice (const downcase) (const upcase)))))

(defcustom tmm-shortcut-words 2
  "How many successive words to try for shortcuts, nil means all.
If you use only one of `downcase' or `upcase' for `tmm-shortcut-style',
specify nil for this variable."
  :type '(choice integer (const nil)))

(defcustom tmm-shortcut-inside-entry nil
  "Highlight the shortcut character in the menu entry's string.
When non-nil, the first menu-entry's character that acts as a shortcut
is displayed with the `highlight' face to help identify it.  The
`tmm-mid-prompt' string is not used then."
  :type 'boolean)

(defface tmm-inactive
  '((t :inherit shadow))
  "Face used for inactive menu items.")

(defvar tmm--history nil)

;;;###autoload
(defun tmm-prompt (menu &optional in-popup default-item no-execute path)
  "Text-mode emulation of calling the bindings in keymap.
Creates a text-mode menu of possible choices.  You can access the elements
in the menu in two ways:
   *)  via history mechanism from minibuffer;
   *)  Or via completion-buffer that is automatically shown.
The last alternative is currently a hack, you cannot use mouse reliably.

MENU is like the MENU argument to `x-popup-menu': either a
keymap or an alist of alists.
DEFAULT-ITEM, if non-nil, specifies an initial default choice.
Its value should be an event that has a binding in MENU.
NO-EXECUTE, if non-nil, means to return the command the user selects
instead of executing it.
PATH is a stack that keeps track of your path through sub-menus.  It
is used to go back through those sub-menus."
  ;; If the optional argument IN-POPUP is t,
  ;; then MENU is an alist of elements of the form (STRING . VALUE).
  ;; That is used for recursive calls only.
  (let ((gl-str "Menu bar")  ;; The menu bar itself is not a menu keymap
					; so it doesn't have a name.
	tmm-km-list out history-len tmm-table-undef tmm-c-prompt
	tmm-old-mb-map tmm-short-cuts
	chosen-string choice
	(not-menu (not (keymapp menu))))
    (run-hooks 'activate-menubar-hook)
    ;; Compute tmm-km-list from MENU.
    ;; tmm-km-list is an alist of (STRING . MEANING).
    ;; It has no other elements.
    ;; The order of elements in tmm-km-list is the order of the menu bar.
    (if (not not-menu)
        (map-keymap (lambda (k v) (tmm-get-keymap (cons k v))) menu)
      (dolist (elt menu)
        (cond
         ((stringp elt) (setq gl-str elt))
         ((listp elt) (tmm-get-keymap elt not-menu))
         ((vectorp elt)
          (dotimes (i (length elt))
            (tmm-get-keymap (cons i (aref elt i)) not-menu))))))
    ;; Choose an element of tmm-km-list; put it in choice.
    (if (and not-menu (= 1 (length tmm-km-list)))
	;; If this is the top-level of an x-popup-menu menu,
	;; and there is just one pane, choose that one silently.
	;; This way we only ask the user one question,
	;; for which element of that pane.
	(setq choice (cdr (car tmm-km-list)))
      (unless tmm-km-list
	(error "Empty menu reached"))
      (and tmm-km-list
	   (let ((index-of-default 0))
             (setq tmm-km-list
	           (if tmm-mid-prompt
                       (tmm-add-shortcuts tmm-km-list)
                     ;; tmm-add-shortcuts reverses tmm-km-list internally.
                     (reverse tmm-km-list)))
	     ;; Find the default item's index within the menu bar.
	     ;; We use this to decide the initial minibuffer contents
	     ;; and initial history position.
	     (if default-item
		 (let ((tail menu) visible)
		   (while (and tail
			       (not (eq (car-safe (car tail)) default-item)))
		     ;; Be careful to count only the elements of MENU
		     ;; that actually constitute menu bar items.
		     (if (and (consp (car tail))
			      (or (stringp (car-safe (cdr (car tail))))
				  (and
				   (eq (car-safe (cdr (car tail))) 'menu-item)
				   (progn
				     (setq visible
					   (plist-get
					    (nthcdr 4 (car tail)) :visible))
				     (or (not visible) (eval visible))))))
			 (setq index-of-default (1+ index-of-default)))
		     (setq tail (cdr tail)))))
             (let ((prompt
                    (concat "^"
                            (if (and (stringp tmm-mid-prompt)
                                     (not tmm-shortcut-inside-entry))
                                (concat "."
                                        (regexp-quote tmm-mid-prompt))))))
               (setq tmm--history
                     (reverse (delq nil
                                    (mapcar
                                     (lambda (elt)
                                       (if (string-match prompt (car elt))
                                           (car elt)))
                                     tmm-km-list)))))
	     (setq history-len (length tmm--history))
	     (setq tmm-c-prompt (nth (- history-len 1 index-of-default)
                                     tmm--history))
             (setq out
                   (if default-item
                       (car (nth index-of-default tmm-km-list))
                     (minibuffer-with-setup-hook
                         (lambda ()
                           (setq tmm-old-mb-map (tmm-define-keys t)))
                       ;; tmm-km-list is reversed, because history
                       ;; needs it in LIFO order.  But default list
                       ;; needs it in non-reverse order, so that the
                       ;; menu items are displayed by M-n as default
                       ;; values in the order they are shown on
                       ;; the menu bar.  So pass the DEFAULT arg the
                       ;; reversed copy of the list.
                       (completing-read-default
                        (concat gl-str
                                " (up/down to change, PgUp to menu): ")
                        (completion-table-with-metadata
                         tmm-km-list '((category . tmm)
                                       (eager-display . tmm-add-prompt)
                                       (display-sort-function . identity)
                                       (cycle-sort-function . identity)))
                        nil t nil
                        'tmm--history (reverse tmm--history)))))))
      (if (and (stringp out) (string= "^" out))
          ;; A fake choice to please the destructuring later.
          (setq choice (cons out out))
        (setq choice (cdr (assoc out tmm-km-list)))
        (and (null choice)
             (string-prefix-p tmm-c-prompt out)
	     (setq out (substring out (length tmm-c-prompt))
		   choice (cdr (assoc out tmm-km-list))))
        (and (null choice) out
	     (setq out (try-completion out tmm-km-list)
		   choice (cdr (assoc out tmm-km-list))))))
    ;; CHOICE is now (STRING . MEANING).  Separate the two parts.
    (setq chosen-string (car choice))
    (setq choice (cdr choice))
    (cond ((and (stringp choice) (string= "^" choice))
           ;; User wants to go up: do it first.
           (if path (tmm-prompt (pop path) in-popup nil nil path)))
          (in-popup
	   ;; We just did the inner level of a -popup menu.
	   choice)
	  ;; We just did the outer level.  Do the inner level now.
	  (not-menu (tmm-prompt choice t nil no-execute (cons menu path)))
	  ;; We just handled a menu keymap and found another keymap.
	  ((keymapp choice)
	   (if (symbolp choice)
	       (setq choice (indirect-function choice)))
	   (condition-case nil
	       (require 'mouse)
	     (error nil))
           (tmm-prompt choice nil nil no-execute (cons menu path)))
	  ;; We just handled a menu keymap and found a command.
	  (choice
	   (if chosen-string
	       (if no-execute choice
		 (setq last-command-event chosen-string)
		 (call-interactively choice))
	     choice)))))

(defun tmm-add-shortcuts (list)
  "Add shortcuts to cars of elements of the list.
Takes a list of lists with a string as car, returns list with
shortcuts added to these cars.
Stores a list of all the shortcuts in the free variable `tmm-short-cuts'."
  (let ((tmm-next-shortcut-digit ?0))
    (mapcar #'tmm-add-one-shortcut (reverse list))))

(defun tmm--shorten-space-width (str)
  "Shorten the width between the menu entry and the keybinding by 2 spaces."
  (let* ((start (next-single-property-change 0 'display str))
         (n (length str))
         (end (previous-single-property-change n 'display str))
         (curr-width (and start
                          (plist-get (get-display-property start 'space str) :width))))
    (when curr-width
      (put-text-property start end 'display (cons 'space (list :width (- curr-width 2))) str))
    str))

(defsubst tmm-add-one-shortcut (elt)
  ;; uses the free vars tmm-next-shortcut-digit and tmm-short-cuts
  (cond
   ((eq (cddr elt) 'ignore)
    (cons (concat " " (make-string (length tmm-mid-prompt) ?\-)
                  (car elt))
          (cdr elt)))
   (t
    (let* ((str (car elt))
           (paren (string-search "(" str))
           (word 0) pos char)
      (catch 'done                             ; ??? is this slow?
        (while (and (or (not tmm-shortcut-words)   ; no limit on words
                        (< word tmm-shortcut-words)) ; try n words
                    (setq pos (string-match "\\w+" str pos)) ; get next word
                    (not (and paren (> pos paren)))) ; don't go past "(binding.."
          (if (or (= pos 0)
                  (/= (aref str (1- pos)) ?.)) ; avoid file extensions
              (dolist (shortcut-style ; try upcase and downcase variants
                       (if (listp tmm-shortcut-style) ; convert to list
                           tmm-shortcut-style
                       (list tmm-shortcut-style)))
                (setq char (funcall shortcut-style (aref str pos)))
                (if (not (memq char tmm-short-cuts)) (throw 'done char))))
          (setq word (1+ word))
          (setq pos (match-end 0)))
        ;; A nil value for pos means that the shortcut is not inside the
        ;; string of the menu entry.
        (setq pos nil)
        (while (<= tmm-next-shortcut-digit ?9) ; no letter shortcut, pick a digit
          (setq char tmm-next-shortcut-digit)
          (setq tmm-next-shortcut-digit (1+ tmm-next-shortcut-digit))
          (if (not (memq char tmm-short-cuts)) (throw 'done char)))
        (setq char nil))
      (if char (setq tmm-short-cuts (cons char tmm-short-cuts)))
      (cons
       (if tmm-shortcut-inside-entry
           (if char
               (if pos
                   ;; A character inside the menu entry.
                   (let ((res (copy-sequence str)))
                     (aset res pos char)
                     (add-text-properties pos (1+ pos) '(face highlight) res)
                     res)
                 ;; A fallback digit character: place it in front of the
                 ;; menu entry.  We need to shorten the spaces between
                 ;; the menu entry and the keybinding by two spaces
                 ;; because we added two characters at the front (one
                 ;; digit and one space) and this would cause a
                 ;; misalignment otherwise.
                 (tmm--shorten-space-width
                  (concat (propertize (char-to-string char) 'face 'highlight)
                          " " str)))
             (make-string 2 ?\s))
         (concat (if char (concat (char-to-string char) tmm-mid-prompt)
                   ;; Keep them lined up in columns.
                   (make-string (1+ (length tmm-mid-prompt)) ?\s))
                 str))
       (cdr elt))))))

(defun tmm-clear-self-insert-and-exit ()
  "Clear the minibuffer contents then self insert and exit."
  (interactive)
  (delete-minibuffer-contents)
  (self-insert-and-exit))

;; This returns the old map.
(defun tmm-define-keys (minibuffer)
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map t)
    (dolist (c tmm-short-cuts)
      (if (listp tmm-shortcut-style)
          (define-key map (char-to-string c) 'tmm-shortcut)
        ;; only one kind of letters are shortcuts, so map both upcase and
        ;; downcase input to the same
        (define-key map (char-to-string (downcase c)) 'tmm-shortcut)
        (define-key map (char-to-string (upcase c)) 'tmm-shortcut)))
    (when minibuffer
      (define-key map [pageup] 'tmm-goto-completions)
      (define-key map [prior] 'tmm-goto-completions)
      (define-key map "\ev" 'tmm-goto-completions)
      (define-key map "\C-n" 'next-history-element)
      (define-key map "\C-p" 'previous-history-element)
      ;; Previous menu shortcut (see `tmm-prompt').
      (define-key map "^" 'tmm-clear-self-insert-and-exit))
    (prog1 (current-local-map)
      (use-local-map (append map (current-local-map))))))

(defun tmm-completion-delete-prompt ()
  (with-current-buffer standard-output
    (goto-char (point-min))
    (let* (;; First candidate: first string with mouse-face
           (menu-start-1 (or (and (get-text-property (point) 'mouse-face) (point))
                             (next-single-char-property-change (point) 'mouse-face)))
           ;; Second candidate: an inactive menu item with tmm-inactive face
           (tps-result (save-excursion
                         (text-property-search-forward 'face 'tmm-inactive t)))
           (menu-start-2 (and tps-result (prop-match-beginning tps-result))))
      (or (and (null menu-start-1) (null menu-start-2))
          (delete-region (point)
                         ;; Use the smallest position of the two candidates.
                         (or (and menu-start-1 menu-start-2
                                  (min menu-start-1 menu-start-2))
                             ;; Otherwise use the one that is non-nil.
                             menu-start-1
                             menu-start-2))))))

(defun tmm-remove-inactive-mouse-face ()
  "Remove the mouse-face property from inactive menu items."
  (let ((inhibit-read-only t)
        (inactive-string
         (concat " " (make-string (length tmm-mid-prompt) ?\-)))
        next)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (setq next (next-single-char-property-change (point) 'mouse-face))
        (when (looking-at inactive-string)
          (remove-text-properties (point) next '(mouse-face nil))
          (add-text-properties (point) next '(face tmm-inactive)))
        (goto-char next)))
    (set-buffer-modified-p nil)))

(defun tmm-add-prompt ()
  (unless tmm-c-prompt
    (error "No active menu entries"))
  (or tmm-completion-prompt
      (add-hook 'completion-setup-hook
                #'tmm-completion-delete-prompt 'append))
  (unwind-protect
      (minibuffer-completion-help)
    (remove-hook 'completion-setup-hook #'tmm-completion-delete-prompt))
  (with-current-buffer "*Completions*"
    (tmm-remove-inactive-mouse-face)
    (when tmm-completion-prompt
      (let ((inhibit-read-only t)
	    (window (get-buffer-window "*Completions*")))
	(goto-char (point-min))
	(insert
         (if tmm-shortcut-inside-entry
             (format tmm-completion-prompt
                     (concat (propertize "highlighted" 'face 'highlight) " character"))
           (format tmm-completion-prompt
                   (concat "character right before '" tmm-mid-prompt "' "))))
	(when window
	  ;; Try to show everything just inserted and preserve height of
	  ;; *Completions* window.  This should fix a behavior described
	  ;; in Bug#1291.
	  (fit-window-to-buffer window nil nil nil nil t))))))

(defun tmm-shortcut ()
  "Choose the shortcut that the user typed."
  (interactive)
  (let ((c last-command-event) s)
    (if (symbolp tmm-shortcut-style)
        (setq c (funcall tmm-shortcut-style c)))
    (if (memq c tmm-short-cuts)
	(if (equal (buffer-name) "*Completions*")
	    (progn
	      (goto-char (point-min))
	      (re-search-forward
	       (concat "\\(^\\|[ \t]\\)" (char-to-string c) tmm-mid-prompt))
	      (choose-completion))
	  ;; In minibuffer
	  (delete-region (minibuffer-prompt-end) (point-max))
          (dolist (elt tmm-km-list)
            (let ((str (car elt))
                  (index 0))
              (when tmm-shortcut-inside-entry
                (if (get-char-property 0 'face str)
                    (setq index 0)
                  (let ((next (next-single-char-property-change 0 'face str)))
                    (setq index (if (= (length str) next) 0 next)))))
              (if (= (aref str index) c)
                  (setq s str))))
	  (insert s)
	  (exit-minibuffer)))))

(defun tmm-goto-completions ()
  "Jump to the completions buffer."
  (interactive)
  (tmm-add-prompt)
  (setq tmm-c-prompt (buffer-substring (minibuffer-prompt-end) (point-max)))
  ;; Clear minibuffer old contents before using *Completions* buffer for
  ;; selection.
  (delete-minibuffer-contents)
  (switch-to-buffer-other-window "*Completions*")
  (search-forward tmm-c-prompt)
  (search-backward tmm-c-prompt))

(defun tmm-get-keymap (elt &optional in-x-menu)
  "Prepend (DOCSTRING EVENT BINDING) to free variable `tmm-km-list'.
The values are deduced from the argument ELT, that should be an
element of keymap, an `x-popup-menu' argument, or an element of
`x-popup-menu' argument (when IN-X-MENU is not-nil).
This function adds the element only if it is not already present.
It uses the free variable `tmm-table-undef' to keep undefined keys."
  (let (km str plist filter visible enable (event (car elt)))
    (setq elt (cdr elt))
    (if (eq elt 'undefined)
	(setq tmm-table-undef (cons (cons event nil) tmm-table-undef))
      (unless (assoc event tmm-table-undef)
	(cond ((or (functionp elt) (keymapp elt))
	       (setq km elt))

	      ((or (keymapp (cdr-safe elt)) (functionp (cdr-safe elt)))
	       (setq km (cdr elt))
	       (and (stringp (car elt)) (setq str (car elt))))

	      ((or (keymapp (cdr-safe (cdr-safe elt)))
		   (functionp (cdr-safe (cdr-safe elt))))
	       (setq km (cddr elt))
	       (and (stringp (car elt)) (setq str (car elt))))

	      ((eq (car-safe elt) 'menu-item)
	       ;; (menu-item TITLE COMMAND KEY ...)
	       (setq plist (cdr-safe (cdr-safe (cdr-safe elt))))
	       (when (consp (car-safe plist))
		 (setq plist (cdr-safe plist)))
	       (setq km (nth 2 elt))
	       (setq str (eval (nth 1 elt)))
	       (setq filter (plist-get plist :filter))
	       (if filter
		   (setq km (funcall filter km)))
	       (setq visible (plist-get plist :visible))
	       (if visible
		   (setq km (and (eval visible) km)))
	       (setq enable (plist-get plist :enable))
	       (if enable
                   (setq km (if (eval enable) km 'ignore))))

	      ((or (keymapp (cdr-safe (cdr-safe (cdr-safe elt))))
		   (functionp (cdr-safe (cdr-safe (cdr-safe elt)))))
                                        ; New style of easy-menu
	       (setq km (cdr (cddr elt)))
	       (and (stringp (car elt)) (setq str (car elt))))

	      ((stringp event)		; x-popup or x-popup element
               (setq str event)
               (setq event nil)
	       (setq km (if (or in-x-menu (stringp (car-safe elt)))
                            elt (cons 'keymap elt)))))
        (unless (or (eq km 'ignore) (null str))
          (let ((binding (where-is-internal km nil t)))
            (when binding
              (setq binding (key-description binding))
              ;; Try to align the keybindings.
              (let* ((window (get-buffer-window "*Completions*"))
                     (colwidth (min 30 (- (/ (if window
                                                 (window-width window)
                                               (frame-width))
                                             2)
                                          10)))
                     (nspaces (max 2 (- colwidth
                                        (string-width str)
                                        (string-width binding)))))
                (setq str
                      (concat str
                              (propertize (make-string nspaces ?\s)
                                          'display
                                          (cons 'space (list :width nspaces)))
                              binding)))))))
      (and km (stringp km) (setq str km))
      ;; Verify that the command is enabled;
      ;; if not, don't mention it.
      (when (and km (symbolp km) (get km 'menu-enable))
	  (setq km (if (eval (get km 'menu-enable)) km 'ignore)))
      (and km str
	   (or (assoc str tmm-km-list)
	       (push (cons str (cons event km)) tmm-km-list))))))

(provide 'tmm)

;;; tmm.el ends here
