#!/usr/bin/env bash

set -euo pipefail

session_name="${1:?session_name is required}"
min_width=""
left_width=""

while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    line_session="${line%% *}"
    line_width="${line##* }"

    if [[ "$line_session" != "$session_name" ]]; then
        continue
    fi

    if [[ -z "$min_width" || "$line_width" -lt "$min_width" ]]; then
        min_width="$line_width"
    fi
done < <(tmux list-clients -F '#{session_name} #{client_width}')

if [[ -z "$min_width" ]]; then
    min_width=999
fi

left_width="$(
    /home/jethro/repo/dotfiles/scripts/tmux-status-left-preview.sh "$session_name" \
        | awk '/^== left-width ==$/{getline; print; exit}'
)"

available_width=$((min_width - left_width))
if ((available_width < 0)); then
    available_width=0
fi

right_length="$available_width"

tmux set-option -t "$session_name" @status_min_client_width "$min_width"
tmux set-option -t "$session_name" @status_left_width "$left_width"
tmux set-option -t "$session_name" @status_available_width "$available_width"
tmux set-option -t "$session_name" status-right-length "$right_length"
