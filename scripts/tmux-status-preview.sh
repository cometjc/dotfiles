#!/usr/bin/env bash

set -euo pipefail

session_name="${1:-$(tmux display-message -p '#{session_name}')}"

status_left="$(tmux display-message -p -t "$session_name" '#{T;=/#{status-left-length}:status-left}')"
status_right="$(tmux display-message -p -t "$session_name" '#{T;=/#{status-right-length}:status-right}')"

window_segments=""
while IFS= read -r window_id; do
    segment="$(tmux display-message -p -t "$window_id" '#{?window_active,#{T:window-status-current-format},#{T:window-status-format}}')"
    window_segments+="$segment"
done < <(tmux list-windows -t "$session_name" -F '#{window_id}')

rendered="${status_left}${window_segments}${status_right}"
plain="$(printf '%s' "$rendered" | perl -pe 's/#\[[^\]]*\]//g')"

printf '== rendered ==\n%s\n' "$rendered"
printf '\n== plain ==\n%s\n' "$plain"
