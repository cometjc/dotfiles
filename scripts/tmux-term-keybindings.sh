#!/bin/bash
# Apply window-switch key bindings based on client TERM, then show a popup hint.
# Usage: tmux-term-keybindings.sh <termname> <client>
#
# putty-256color : Alt+Left/Right = previous/next window (Ctrl unbound)
# linux          : Ctrl+Left/Right = previous/next window (Alt unboud)

TERM_NAME="${1:-}"
CLIENT="${2:-}"

case "$TERM_NAME" in
    putty-256color)
        tmux unbind-key -n C-Left 2>/dev/null || true
        tmux unbind-key -n C-Right 2>/dev/null || true
        tmux bind-key -n M-Left previous-window
        tmux bind-key -n M-Right next-window
        tmux display-popup -c "$CLIENT" -w 36 -h 5 -T " 按鍵模式 " \
            "printf '\n  PuTTY 模式\n  Alt+← / Alt+→  切換 window\n'; sleep 3"
        ;;
    linux)
        tmux unbind-key -n M-Left 2>/dev/null || true
        tmux unbind-key -n M-Right 2>/dev/null || true
        tmux bind-key -n C-Left previous-window
        tmux bind-key -n C-Right next-window
        tmux display-popup -c "$CLIENT" -w 40 -h 5 -T " 按鍵模式 " \
            "printf '\n  Linux console 模式\n  Ctrl+← / Ctrl+→  切換 window\n'; sleep 3"
        ;;
esac
