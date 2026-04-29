#!/usr/bin/env bash
# Toggle current window between bg session and the first non-bg session.
# Args: $1=session_name $2=window_id $3=session_windows_count
set -euo pipefail

current_session="$1"
window_id="$2"
session_windows="$3"
bg_session="bg"

if [[ "$current_session" == "$bg_session" ]]; then
    # Move bg → main (first non-bg session)
    target=$(tmux list-sessions -F "#{session_name}" | grep -v "^${bg_session}$" | head -1)
    if [[ -z "$target" ]]; then
        tmux display-message "No other session"
        exit 0
    fi
    added_keep=0
    if [[ "$session_windows" -le 1 ]]; then
        tmux new-window -d -t "${bg_session}:" -n keep
        added_keep=1
    fi
    tmux move-window -s "$window_id" -t "${target}:"
    tmux switch-client -t "$target"
    if [[ "$added_keep" -eq 1 ]]; then
        tmux kill-window -t "${bg_session}:keep" 2>/dev/null || true
    fi
    tmux display-message "Moved window to ${target}"
else
    # Move main → bg (create bg if missing)
    created_bg=0
    if ! tmux has-session -t "$bg_session" 2>/dev/null; then
        tmux new-session -d -s "$bg_session"
        created_bg=1
    fi
    if [[ "$session_windows" -le 1 ]]; then
        tmux new-window -d -t "${current_session}:" -n keep
    fi
    if tmux move-window -s "$window_id" -t "${bg_session}:"; then
        if [[ "$created_bg" -eq 1 ]]; then
            tmux kill-window -t "${bg_session}:0" 2>/dev/null || true
        fi
        tmux display-message "Moved window to ${bg_session}"
    fi
fi
