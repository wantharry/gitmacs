;;; init.el --- minimal magit-only launcher -*- lexical-binding: t; -*-

(defvar gitmacs-home (file-name-directory (or load-file-name buffer-file-name)))

(setq gc-cons-threshold most-positive-fixnum
      inhibit-startup-screen t
      vc-handled-backends nil       ; avoid Emacs' built-in VC stepping on Magit
      package-user-dir (expand-file-name "packages" gitmacs-home)
      package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                          ("melpa"  . "https://melpa.org/packages/")))

;; package.el's GPG signature verification fails with "bad-signature"
;; on this platform even for an untampered download (almost certainly
;; a coding-system/line-ending mismatch corrupting the byte-exact
;; content signature checking needs) -- HTTPS already gives transport
;; integrity, so skip the extra check only where it's actually broken
(when (eq system-type 'windows-nt)
  (setq package-check-signature nil))

(require 'package)
(package-initialize)

;; native-compiling a package (below) runs in its own subprocess, whose
;; warnings don't answer to this process's `warning-minimum-level' --
;; the only thing that reliably stops the harmless first-run compiler
;; warnings from popping up their own window is refusing to give the
;; *Warnings* buffer a window at all. It still exists if ever needed
;; (`C-x b *Warnings*'), it just never grabs the screen on its own.
(add-to-list 'display-buffer-alist
             '("\\*Warnings\\*"
               (display-buffer-no-window)
               (allow-no-window . t)))

;; first-time compilation of a package can emit harmless byte-compile
;; warnings; nothing here is fatal (ignore-errors below still catches
;; real failures), so keep it quiet
(let ((warning-minimum-level :error)
      (byte-compile-warnings nil))
  (dolist (pkg '(transient with-editor dash magit doom-themes doom-modeline nerd-icons))
    (unless (package-installed-p pkg)
      (unless package-archive-contents
        (package-refresh-contents))
      (package-install pkg))))

;; a real theme with explicit fg/bg on every face (region, hl-line,
;; magit-section-highlight, ...) so terminal mode never falls back to
;; unreadable "unspecified" colors on highlighted lines
(load-theme 'doom-tokyo-night t)

;; native-compiling the bundled packages is a few seconds of one-time
;; work; without this it happens lazily in the background the first
;; time each file is used, which is fine but makes early commands
;; janky. The stamp file makes this run exactly once per package set.
(when (native-comp-available-p)
  (let ((stamp (expand-file-name ".native-compiled" package-user-dir)))
    (unless (file-exists-p stamp)
      (let ((native-comp-async-report-warnings-errors 'silent)
            (warning-minimum-level :error)
            (byte-compile-warnings nil))
        (dolist (f (directory-files-recursively package-user-dir "\\.el\\'"))
          (unless (string-match-p "-autoloads\\.el\\'\\|-pkg\\.el\\'" f)
            (ignore-errors (native-compile f)))))
      (with-temp-file stamp ""))))

(require 'magit)

;; a richer modeline (git branch, mode, position) matching the theme;
;; icons only in --gui since a plain terminal usually lacks the Nerd
;; Font glyphs and would just show missing-glyph boxes instead
(require 'doom-modeline)
(setq doom-modeline-icon (display-graphic-p))
(doom-modeline-mode 1)

;; word-level highlighting within a changed line, not just "this line
;; differs" -- much easier to see what actually changed
(setq magit-diff-refine-hunks 'all)

;; unstaged/staged/stashes start expanded instead of needing a manual
;; TAB on every single status view
(setq magit-section-initial-visibility-alist
      '((unstaged . show) (staged . show) (stashes . show)))

;; line numbers and column position in any real file buffer (editing
;; a conflict, writing a commit message); magit's own buffers
;; (status/log/diff) navigate by section, not by line, so they're
;; left alone
(add-hook 'text-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(column-number-mode 1)

;; `M-x customize' writes here instead of editing this file by hand;
;; loaded back on every startup so changes persist
(setq custom-file (expand-file-name "custom.el" gitmacs-home))
(load custom-file 'noerror)

;; terminal mode can't change the font (that's the terminal emulator's
;; job); this only affects `--gui'. Pick the best already-installed
;; font instead of bundling one, since fonts have to be OS-registered
;; to be usable, unlike a plain binary or Elisp file
(when (display-graphic-p)
  (let ((font (seq-find (lambda (f) (member f (font-family-list)))
                         '("Cascadia Code" "Cascadia Mono" "JetBrains Mono"
                           "Fira Code" "Consolas" "DejaVu Sans Mono"))))
    (when font
      (set-face-attribute 'default nil :font font :height 120))))

(defvar gitmacs-recent-file (expand-file-name "recent-repos.el" gitmacs-home))
(defvar gitmacs-visits-file (expand-file-name "visit-counts.el" gitmacs-home))

(defun gitmacs--read-data-file (file)
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (ignore-errors (read (current-buffer))))))

(defvar gitmacs-recent-repos
  (seq-filter #'stringp (gitmacs--read-data-file gitmacs-recent-file)))
(defvar gitmacs-visit-counts
  (seq-filter (lambda (c) (stringp (car c))) (gitmacs--read-data-file gitmacs-visits-file)))

(defun gitmacs--remember-repo (dir)
  (setq gitmacs-recent-repos
        (seq-take (cons dir (delete dir (copy-sequence gitmacs-recent-repos))) 10))
  (with-temp-file gitmacs-recent-file
    (prin1 gitmacs-recent-repos (current-buffer))))

(defun gitmacs--record-visit (dir)
  (let ((cell (assoc dir gitmacs-visit-counts)))
    (if cell
        (setcdr cell (1+ (cdr cell)))
      (push (cons dir 1) gitmacs-visit-counts)))
  (with-temp-file gitmacs-visits-file
    (prin1 gitmacs-visit-counts (current-buffer))))

(defun gitmacs--most-visited (n)
  (mapcar #'car
          (seq-take (sort (copy-sequence gitmacs-visit-counts)
                           (lambda (a b) (> (cdr a) (cdr b))))
                    n)))

(defun gitmacs-open (dir)
  "Open Magit status for DIR and remember it in the recent/visit lists."
  (magit-status dir)
  (when-let ((top (magit-toplevel dir)))
    (gitmacs--remember-repo top)
    (gitmacs--record-visit top))
  (delete-other-windows))

;; the landing page shown when gitmacs is started outside a repo, or
;; via `R' from any status buffer: your 10 most recent repos and your
;; 10 most-visited ones, each a line you can jump into with RET
(defvar gitmacs-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'gitmacs-dashboard-visit)
    (define-key map "n" #'next-line)
    (define-key map "p" #'previous-line)
    (define-key map "g" #'gitmacs-dashboard-refresh)
    (define-key map "o" #'gitmacs-dashboard-open-other)
    (define-key map "q" #'save-buffers-kill-terminal)
    map))

(define-derived-mode gitmacs-dashboard-mode special-mode "Gitmacs"
  "Landing page listing recent and most-visited repos."
  (hl-line-mode 1))

(defun gitmacs--dashboard-insert-section (title dirs)
  (when dirs
    (insert (propertize title 'face 'magit-section-heading) "\n")
    (dolist (dir dirs)
      (insert (propertize (abbreviate-file-name dir) 'gitmacs-dir dir) "\n"))
    (insert "\n")))

(defun gitmacs-dashboard-refresh ()
  (interactive)
  (let ((inhibit-read-only t)
        (line (line-number-at-pos)))
    (erase-buffer)
    (insert (propertize "gitmacs\n\n" 'face 'bold))
    (gitmacs--dashboard-insert-section
     (format "Recent (%d)" (length gitmacs-recent-repos))
     gitmacs-recent-repos)
    (gitmacs--dashboard-insert-section
     (format "Most visited (%d)" (length (gitmacs--most-visited 10)))
     (gitmacs--most-visited 10))
    (insert (propertize "RET" 'face 'bold) " open   "
            (propertize "o" 'face 'bold) " open other   "
            (propertize "g" 'face 'bold) " refresh   "
            (propertize "q" 'face 'bold) " quit\n")
    (goto-char (point-min))
    (forward-line (min line 2))))

(defun gitmacs-dashboard-visit ()
  (interactive)
  (let ((dir (get-text-property (line-beginning-position) 'gitmacs-dir)))
    (if dir
        (gitmacs-open dir)
      (message "No repo on this line"))))

(defun gitmacs-dashboard-open-other ()
  (interactive)
  (gitmacs-open (read-directory-name "Open repo: ")))

(defun gitmacs-open-recent ()
  "Show the recent/most-visited dashboard, or prompt if there's no history yet."
  (interactive)
  (if (or gitmacs-recent-repos gitmacs-visit-counts)
      (progn
        (switch-to-buffer (get-buffer-create "*gitmacs*"))
        (gitmacs-dashboard-mode)
        (gitmacs-dashboard-refresh)
        (delete-other-windows))
    (gitmacs-open (read-directory-name "Open repo: "))))

(with-eval-after-load 'magit
  ;; from the top-level status buffer, q quits the whole app instead of
  ;; just burying the buffer
  (define-key magit-status-mode-map "q" #'save-buffers-kill-terminal)
  ;; jump to any previously opened repo without retyping the path
  (define-key magit-status-mode-map "R" #'gitmacs-open-recent))

(menu-bar-mode -1)
(setq ring-bell-function #'ignore)

;; when started as a daemon there's no meaningful default-directory or
;; frame to open a repo into yet; `gitmacs' opens the repo explicitly
;; over emacsclient once the daemon is up
(unless (or noninteractive (daemonp))
  (if (magit-toplevel default-directory)
      (gitmacs-open default-directory)
    (gitmacs-open-recent)))
