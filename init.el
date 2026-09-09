;;; init.el --- minimal magit-only launcher -*- lexical-binding: t; -*-

(setq gc-cons-threshold most-positive-fixnum
      inhibit-startup-screen t
      vc-handled-backends nil       ; avoid Emacs' built-in VC stepping on Magit
      package-user-dir (expand-file-name
                         "packages" (file-name-directory
                                     (or load-file-name buffer-file-name)))
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

(require 'magit)

(with-eval-after-load 'magit
  ;; from the top-level status buffer, q quits the whole app instead of
  ;; just burying the buffer
  (define-key magit-status-mode-map "q" #'save-buffers-kill-terminal))

(menu-bar-mode -1)
(setq ring-bell-function #'ignore)

(unless noninteractive
  (magit-status default-directory)
  (delete-other-windows))
