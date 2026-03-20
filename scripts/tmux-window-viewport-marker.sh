#!/usr/bin/env bash

set -euo pipefail

window_id="${1:?window_id is required}"

"$HOME/repo/dotfiles/scripts/tmux-window-status.sh" symbol "$window_id"
