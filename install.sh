#!/usr/bin/env bash
set -euo pipefail

if ! command -v emacs >/dev/null; then
  echo "emacs not found. Install it first (e.g. 'apt install emacs' / 'brew install emacs')." >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/gitmacs" "$BIN_DIR/gitmacs"
echo "Installed gitmacs -> $BIN_DIR/gitmacs"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo "Note: $BIN_DIR is not on your PATH. Add this to your shell rc file:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo "First run will download magit + deps from GNU ELPA/MELPA (needs network) and byte-compile them; after that it starts in well under a second."
