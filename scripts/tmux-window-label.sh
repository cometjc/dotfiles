#!/usr/bin/env bash

set -euo pipefail

window_id="${1:?window_id is required}"
window_name="$(tmux display-message -p -t "$window_id" '#W')"

if [[ -n "$window_name" ]]; then
    printf '%s' "$window_name"
    exit 0
fi

window_path="$(tmux display-message -p -t "$window_id" '#{pane_current_path}')"
window_base="$(basename "$window_path")"
printf '%.8s' "$window_base"
