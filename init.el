;;; init.el --- minimal magit-only launcher -*- lexical-binding: t; -*-

(defvar gitmacs-home (file-name-directory (or load-file-name buffer-file-name)))

(setq gc-cons-threshold most-positive-fixnum
      inhibit-startup-screen t
      vc-handled-backends nil       ; avoid Emacs' built-in VC stepping on Magit
      package-user-dir (expand-file-name "packages" gitmacs-home)
      package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                          ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                          ("melpa"  . "https://melpa.org/packages/")))

;; a real theme with explicit fg/bg on every face (region, hl-line,
;; magit-section-highlight, ...) so terminal mode never falls back to
;; unreadable "unspecified" colors on highlighted lines
(load-theme 'modus-vivendi t)

(require 'package)
(package-initialize)

(dolist (pkg '(transient with-editor dash magit))
  (unless (package-installed-p pkg)
    (unless package-archive-contents
      (package-refresh-contents))
    (package-install pkg)))

;; native-compiling the bundled packages is a few seconds of one-time
;; work; without this it happens lazily in the background the first
;; time each file is used, which is fine but makes early commands
;; janky. The stamp file makes this run exactly once per package set.
(when (native-comp-available-p)
  (let ((stamp (expand-file-name ".native-compiled" package-user-dir)))
    (unless (file-exists-p stamp)
      (let ((native-comp-async-report-warnings-errors 'silent))
        (dolist (f (directory-files-recursively package-user-dir "\\.el\\'"))
          (unless (string-match-p "-autoloads\\.el\\'\\|-pkg\\.el\\'" f)
            (ignore-errors (native-compile f)))))
      (with-temp-file stamp ""))))

(require 'magit)

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

(defvar gitmacs-recent-repos
  (when (file-exists-p gitmacs-recent-file)
    (with-temp-buffer
      (insert-file-contents gitmacs-recent-file)
      (ignore-errors (read (current-buffer))))))

(defun gitmacs--remember-repo (dir)
  (setq gitmacs-recent-repos
        (seq-take (cons dir (delete dir (copy-sequence gitmacs-recent-repos))) 10))
  (with-temp-file gitmacs-recent-file
    (prin1 gitmacs-recent-repos (current-buffer))))

(defun gitmacs-open (dir)
  "Open Magit status for DIR and remember it in the recent list."
  (magit-status dir)
  (gitmacs--remember-repo (magit-toplevel dir))
  (delete-other-windows))

(defun gitmacs-open-recent ()
  "Pick a repo from the recently opened list and open it."
  (interactive)
  (if gitmacs-recent-repos
      (gitmacs-open (completing-read "Open repo: " gitmacs-recent-repos nil t))
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
