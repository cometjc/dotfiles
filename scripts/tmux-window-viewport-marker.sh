#!/usr/bin/env bash

set -euo pipefail

window_id="${1:?window_id is required}"
pattern="${2:?pattern is required}"

while IFS= read -r pane_id; do
    if tmux capture-pane -p -t "$pane_id" | grep -Fq -- "$pattern"; then
        printf '●'
        exit 0
    fi
done < <(tmux list-panes -t "$window_id" -F '#{pane_id}')
