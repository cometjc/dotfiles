#!/usr/bin/env bash
# Claude Code hook: update tmux @claude_status session option.
# Receives JSON via stdin from Claude Code hooks.
# Configured via hooks in ~/.claude/settings.json.

set -euo pipefail

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')

# Only run inside tmux
[[ -z "${TMUX:-}" ]] && exit 0

session=$(tmux display-message -p '#{session_name}' 2>/dev/null) || exit 0

# Window where Claude Code is running (via TMUX_PANE inherited from Claude process)
window_id=""
if [[ -n "${TMUX_PANE:-}" ]]; then
    window_id=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null) || true
fi

set_session_status() {
    tmux set-option -t "$session" @claude_status "$1" 2>/dev/null || true
}

set_window_status() {
    [[ -z "$window_id" ]] && return
    tmux set-option -wq -t "$window_id" @claude_status "$1" 2>/dev/null || true
}

case "$event" in
    PreToolUse)
        tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
        set_session_status "⚡ $tool"
        set_window_status "1"
        ;;
    PostToolUse)
        set_session_status ""
        set_window_status ""
        ;;
    Notification)
        msg=$(printf '%s' "$input" | jq -r '.message // .title // ""')
        # Strip ANSI escape codes
        msg=$(printf '%s' "$msg" | sed 's/\x1b\[[0-9;]*m//g')
        # Truncate to 60 chars
        if [[ ${#msg} -gt 60 ]]; then
            msg="${msg:0:59}…"
        fi
        set_session_status "$msg"
        # "✻ <Verb> for <duration>" (no …) marks a completed reasoning phase
        if [[ "$msg" != *'…'* && "$msg" =~ ' for '[0-9] ]]; then
            set_window_status "done"
        else
            set_window_status "1"
        fi
        ;;
    Stop | SubagentStop)
        set_session_status ""
        set_window_status ""
        # shellcheck disable=SC1010
        workmux set-window-status done 2>/dev/null || true
        tmux refresh-client -S 2>/dev/null || true
        ;;
esac

exit 0
# DEBUG (remove later)
