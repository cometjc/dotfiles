#!/usr/bin/env bash
# Called on userPromptSubmitted: capture the focused pane (the one where the
# user submitted the prompt) and store it so agentStop can target the correct
# window even if the user has switched away by then.
set -euo pipefail

pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
if [[ -n "$pane" ]]; then
    printf '%s\n' "$pane" >/tmp/.workmux_hook_pane
    tmux set-option -w -t "$pane" @workmux_status '🤖' 2>/dev/null || true
fi
tmux refresh-client -S 2>/dev/null || true
