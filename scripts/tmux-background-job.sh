#!/bin/bash
set -euo pipefail

pane_id="${1:?pane id is required}"
foreground_command="${2:-}"
wait_max_attempts="${TMUX_BACKGROUND_JOB_WAIT_MAX_ATTEMPTS:-20}"
wait_interval_seconds="${TMUX_BACKGROUND_JOB_WAIT_INTERVAL_SECONDS:-0.2}"

pane_tail_has_stopped_marker() {
    local pane_tail="$1"

    [[ "$pane_tail" == *"Stopped"* ]] || return 1
    [[ -z "$foreground_command" || "$pane_tail" == *"$foreground_command"* ]]
}

tmux send-keys -t "$pane_id" C-z

if [[ -n "$foreground_command" ]]; then
    for ((attempt = 0; attempt < wait_max_attempts; attempt++)); do
        current_command="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')"
        pane_tail="$(tmux capture-pane -p -t "$pane_id" -S -4)"
        if [[ "$current_command" != "$foreground_command" ]] && pane_tail_has_stopped_marker "$pane_tail"; then
            break
        fi
        sleep "$wait_interval_seconds"
    done
fi

tmux send-keys -t "$pane_id" bg Enter
