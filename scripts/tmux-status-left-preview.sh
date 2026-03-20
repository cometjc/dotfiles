#!/usr/bin/env bash

set -euo pipefail

session_name="${1:-$(tmux display-message -p '#{session_name}')}"

strip_styles() {
    perl -pe 's/#\[[^]]*\]//g'
}

status_left_rendered="$(tmux display-message -p -t "$session_name" '#{E:status-left}')"
status_left_plain="$(printf '%s' "$status_left_rendered" | strip_styles)"

window_list_plain=""
while IFS= read -r window_id; do
    marker="$("$HOME/repo/dotfiles/scripts/tmux-window-status.sh" symbol "$window_id")"
    label="$("$HOME/repo/dotfiles/scripts/tmux-window-label.sh" "$window_id")"

    window_list_plain+="${marker}${label}"
done < <(tmux list-windows -t "$session_name" -F '#{window_id}')

left_plain="${status_left_plain}${window_list_plain}"
left_width="$(printf '%s' "$left_plain" | wc -m | tr -d ' ')"

printf '== status-left ==\n%s\n' "$status_left_plain"
printf '\n== window-list ==\n%s\n' "$window_list_plain"
printf '\n== left-plain ==\n%s\n' "$left_plain"
printf '\n== left-width ==\n%s\n' "$left_width"
