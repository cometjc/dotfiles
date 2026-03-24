#!/usr/bin/env bash

set -euo pipefail

session_name="${1:-$(tmux display-message -p '#{session_name}')}"

strip_styles() {
    perl -pe 's/#\[[^]]*\]//g'
}

status_left_rendered="$(tmux display-message -p -t "$session_name" '#{E:status-left}')"
status_left_plain="$(printf '%s' "$status_left_rendered" | strip_styles)"

window_list_plain=""
window_list_extra_width=0
while IFS= read -r window_id; do
    "$HOME/repo/dotfiles/scripts/tmux-window-status.sh" sync-workmux "$window_id" >/dev/null
    marker="$("$HOME/repo/dotfiles/scripts/tmux-workmux-status.sh" "$window_id" | strip_styles)"
    label="$("$HOME/repo/dotfiles/scripts/tmux-window-label.sh" "$window_id")"

    window_list_plain+="${marker}${label}"
    if [[ -n "$marker" ]]; then
        window_list_extra_width=$((window_list_extra_width + 1))
    fi
done < <(tmux list-windows -t "$session_name" -F '#{window_id}')

left_plain="${status_left_plain}${window_list_plain}"
left_width="$(printf '%s' "$left_plain" | wc -m | tr -d ' ')"
left_width=$((left_width + window_list_extra_width))

printf '== status-left ==\n%s\n' "$status_left_plain"
printf '\n== window-list ==\n%s\n' "$window_list_plain"
printf '\n== left-plain ==\n%s\n' "$left_plain"
printf '\n== left-width ==\n%s\n' "$left_width"
