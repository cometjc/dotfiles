#!/bin/bash
# Generates files/.tmux-defaults.conf from a vanilla tmux server.
# Re-run after tmux upgrades (crontab-update-dotfiles.bash does this automatically).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$DOTFILES_DIR/files/.tmux-defaults.conf"
SOCK="tmux_defaults_$$"

tmux -L "$SOCK" -f /dev/null new-session -d -s defaults
tmux -L "$SOCK" list-keys >"$OUTPUT"
tmux -L "$SOCK" kill-server 2>/dev/null || true

echo "Wrote $(wc -l <"$OUTPUT") bindings → $OUTPUT"
