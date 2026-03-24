#!/usr/bin/env bash
# Called on agentStop: read the stored pane from userPromptSubmitted and
# update that window's status even if the user has switched to another window.
set -euo pipefail

pane=$(cat /tmp/.workmux_hook_pane 2>/dev/null || true)
if [[ -n "$pane" ]]; then
    tmux set-option -w -t "$pane" @workmux_status '✅' 2>/dev/null || true
    tmux refresh-client -S 2>/dev/null || true
fi
