# gitmacs

A minimal, magit-only Emacs launcher. It boots straight into
[Magit](https://magit.vc/)'s status view for a repo — no editor
config, no plugin sprawl, just fast git.

## Features

- **Fast launches.** A persistent background Emacs daemon means
  package/theme/magit loading only happens once; every launch after
  the first opens in well under a second (terminal mode only — see
  [Platform notes](#platform-notes) for why `--gui` differs).
- **Dashboard.** Press `R` from any status buffer, or launch with no
  repo argument, to see your 10 most recent repos and 10 most-visited
  ones. `RET` opens the one under point, `o` opens any other path,
  `g` refreshes.
- **Sensible magit defaults.** Word-level diff highlighting
  (`magit-diff-refine-hunks`), unstaged/staged/stash sections expanded
  by default instead of needing a manual `TAB` every time.
- **Line numbers where they help.** On in real file buffers (resolving
  a conflict, writing a commit message); off in magit's own
  status/log/diff buffers, which are navigated by section, not line.
- **Themed to match.** `doom-tokyo-night` + `doom-modeline` for a
  richer look; falls back gracefully to plain glyphs in a terminal
  without Nerd Font icons.
- **`M-x customize` just works.** Settings persist to a gitignored
  `custom.el` next to `init.el` — no need to hand-edit config for
  small tweaks.

## Installation

### Linux / macOS

```sh
git clone https://github.com/wantharry/gitmacs.git
cd gitmacs
./install.sh                 # symlinks gitmacs into ~/.local/bin
gitmacs ~/path/to/some/repo
```

First run downloads magit + dependencies from GNU ELPA/MELPA (needs
network) and byte-/native-compiles them — a few seconds, once. Every
run after that is fast, because a named background daemon
(`emacs --daemon=gitmacs`) stays running between launches. It costs
nothing while idle; stop it if you ever want to with:

```sh
emacsclient -s gitmacs --eval "(kill-emacs)"
```

### Windows

Requires GNU Emacs for Windows already on `PATH`
([download](https://www.gnu.org/software/emacs/download.html)).

```
gitmacs.cmd C:\path\to\some\repo
```

### Windows, self-contained

No separate Emacs install and no network access required — everything
(a full copy of GNU Emacs, plus magit and its dependencies already
downloaded and compiled) ships in one folder. Unzip it anywhere and
run `gitmacs.cmd` from inside it. See [Platform notes](#platform-notes)
for why this build behaves a little differently from the Linux/macOS
one.

## Usage

```
gitmacs [--gui] [path-to-repo]
```

- No path: opens the [dashboard](#features) if you have history, or
  prompts for a directory if this is the first run ever.
- A path: jumps straight to that repo's magit status.
- `--gui`: opens a graphical Emacs frame instead of a terminal one.

Keys, once open, are standard Magit (`s`/`u` stage/unstage, `c c`
commit, `b b` checkout branch, `l l` log, `z z` stash, `P p`/`F u`
push/pull, `q` quit) plus:

| Key | Action |
|-----|--------|
| `R` | Recent / most-visited dashboard |
| `g` | Refresh (dashboard or status) |

## How it works

`init.el` is a self-contained Emacs config, loaded with `-Q` so it
never touches (or is affected by) a regular `~/.emacs.d`. It:

1. Points `package-user-dir` at a `packages/` folder next to itself
   (gitignored — always fetched fresh, never committed).
2. Installs `magit` and a couple of cosmetic packages
   (`doom-themes`, `doom-modeline`) if not already present.
3. Native-compiles everything once (stamped so it never re-runs),
   since Emacs would otherwise do this lazily in the background the
   first time each file is used.
4. Defines `gitmacs-open`, the dashboard, and the `R`/`q` keybindings.

`bin/gitmacs` (Linux/macOS) starts a named daemon
(`emacs --daemon=gitmacs`) on first use and, on every launch, opens an
`emacsclient` frame against it — that split is what makes repeat
launches fast. Recent repos and visit counts persist to
`recent-repos.el` / `visit-counts.el` next to `init.el` (both
gitignored, both self-healing if a bad entry ever ends up in one).

## Customizing

Run `M-x customize-group` for anything (`magit`, `magit-diff`,
`doom-modeline`, ...) — choices are written to a gitignored
`custom.el` next to `init.el` and reloaded on every startup, so they
survive daemon restarts without editing `init.el` by hand.

## Platform notes

A few things behave differently on Windows, all deliberate:

- **Default (non-`--gui`) launches don't use the daemon.** Windows
  can't attach an `emacsclient` text-mode frame to the console that
  launched it — it always opens a *new* console window instead of
  reusing the current one. Since staying in the calling window matters
  more than shaving a second off startup, plain `gitmacs.cmd` just
  runs Emacs directly each time. `--gui` mode has no such conflict (a
  new window is expected there anyway), so it keeps the daemon.
- **`emacsclient` needs `--server-file`, not `-s`.** The Windows build
  doesn't support `-s`/`--socket-name` (ambiguous with other flags) —
  Windows Emacs identifies a named server by a TCP auth file instead
  of a Unix socket.
- **Package signature checks are disabled on Windows only.**
  `package.el`'s GPG verification of GNU/NonGNU ELPA archives fails
  with `bad-signature` on this platform even for an untampered
  download — almost certainly a coding-system/line-ending mismatch
  corrupting the exact bytes verification needs, not a real integrity
  problem (the raw HTTPS download and the signature file both fetch
  fine independently). HTTPS already gives transport integrity, so the
  redundant check is skipped where it's actually broken.
- **The self-contained bundle's Emacs has native-lisp trimmed.** The
  official Windows build ships ~250MB of pre-compiled native code for
  built-in packages gitmacs never touches (org-mode, gnus, erc, calc,
  tramp, ...). Only the ~22MB "preloaded" subset that Emacs needs to
  boot at all is kept; everything else falls back to the regular
  byte-compiled `.elc` files, which are unaffected and still present.
  This has no practical effect on a git tool, since git operations are
  dominated by the `git` subprocess itself, not Emacs Lisp execution
  speed.

## Troubleshooting

- **"Starting Emacs daemon..." hangs or takes a long time.** First
  launch has to install and compile packages; antivirus scanning a
  freshly extracted, unsigned `emacs.exe` can add real time to that on
  Windows. If it's genuinely stuck (multiple minutes, no further
  output), check Task Manager for a leftover `emacs.exe` process from
  a previous failed attempt and end it, then delete
  `%APPDATA%\.emacs.d\server\gitmacs` before retrying.
- **Dashboard shows nothing even though you've opened repos before.**
  A corrupted entry in `recent-repos.el`/`visit-counts.el` can break
  the whole render. Current `init.el` filters bad entries out
  automatically on load; if you're on an older copy, delete both files
  and they'll be rebuilt from scratch.
