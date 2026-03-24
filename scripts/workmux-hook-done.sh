#!/usr/bin/env bash
# Called on sessionEnd: use workmux to set done status so it also registers
# the pane-focus-in auto-clear hook (clears ✅ when user focuses the window).
# TMUX_PANE is inherited from the Copilot CLI process (the agent's pane).
set -euo pipefail

# shellcheck disable=SC1010
workmux set-window-status done 2>/dev/null || true
tmux refresh-client -S 2>/dev/null || true
