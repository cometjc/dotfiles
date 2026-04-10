#!/bin/bash
# Apply window-switch key bindings based on client TERM, then show a popup hint.
# Usage: tmux-term-keybindings.sh <termname> <client>
#
# putty-256color : Alt+Left/Right = previous/next window (Ctrl unbound)
# linux          : Ctrl+Left/Right = previous/next window (Alt unboud)

TERM_NAME="${1:-}"
CLIENT="${2:-}"

popup_wait_for_escape() {
    cat <<'EOF'
deadline=$((SECONDS + 3))
[[ -r /dev/tty ]] || { sleep 3; exit 0; }
while :; do
    remaining=$((deadline - SECONDS))
    (( remaining <= 0 )) && break
    IFS= read -rsn1 -t "$remaining" key </dev/tty || break
    [[ "$key" == $'\e' ]] && break
done
EOF
}

show_keybinding_popup() {
    local width="$1"
    local message="$2"
    local popup_command bash_command

    popup_command="$(printf "printf '%s';\n%s\n" "$message" "$(popup_wait_for_escape)")"
    printf -v bash_command 'bash -lc %q' "$popup_command"

    # Popup is a best-effort hint; don't let attach fail if it closes early.
    tmux display-popup -E -c "$CLIENT" -w "$width" -h 5 -T " 按鍵模式 " \
        "$bash_command" >/dev/null 2>&1 || true
}

case "$TERM_NAME" in
    putty-256color)
        tmux unbind-key -n C-Left 2>/dev/null || true
        tmux unbind-key -n C-Right 2>/dev/null || true
        tmux bind-key -n M-Left previous-window
        tmux bind-key -n M-Right next-window
        show_keybinding_popup 36 '\n  PuTTY 模式\n  Alt+← / Alt+→  切換 window\n'
        ;;
    linux)
        tmux unbind-key -n M-Left 2>/dev/null || true
        tmux unbind-key -n M-Right 2>/dev/null || true
        tmux bind-key -n C-Left previous-window
        tmux bind-key -n C-Right next-window
        show_keybinding_popup 40 '\n  Linux console 模式\n  Ctrl+← / Ctrl+→  切換 window\n'
        ;;
esac
