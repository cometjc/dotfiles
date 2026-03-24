#!/usr/bin/env bash
# Called on userPromptSubmitted: use workmux to set working status.
# TMUX_PANE is inherited from the Copilot CLI process (the agent's pane).
set -euo pipefail

workmux set-window-status working 2>/dev/null || true
tmux refresh-client -S 2>/dev/null || true
