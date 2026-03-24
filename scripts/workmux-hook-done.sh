#!/usr/bin/env bash
# Called on sessionEnd/agentStop: set done status and bust tmux #() cache.
set -euo pipefail

# shellcheck disable=SC1010
workmux set-window-status done 2>/dev/null || true
# Increment render-seq so tmux's #() cache key changes → immediate re-render
SEQ=$(tmux show-options -gqv @workmux_render_seq 2>/dev/null || echo 0)
tmux set-option -g @workmux_render_seq "$((SEQ + 1))" 2>/dev/null || true
tmux refresh-client -S 2>/dev/null || true
