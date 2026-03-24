#!/usr/bin/env bash
# Called on userPromptSubmitted: set working status and bust tmux #() cache.
set -euo pipefail

# shellcheck disable=SC1010
workmux set-window-status working 2>/dev/null || true
SEQ=$(tmux show-options -gqv @workmux_render_seq 2>/dev/null || echo 0)
tmux set-option -g @workmux_render_seq "$((SEQ + 1))" 2>/dev/null || true
tmux refresh-client -S 2>/dev/null || true
