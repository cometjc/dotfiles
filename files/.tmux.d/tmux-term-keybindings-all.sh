#!/usr/bin/env bash
# Apply tmux-term-keybindings.sh to every attached client (e.g. after source-file
# or tmux-autoreload, which does not trigger client-attached).
set -euo pipefail
script="${HOME}/.tmux.d/tmux-term-keybindings.sh"
[[ -f "$script" ]] || exit 0

while IFS= read -r client; do
    [[ -n "${client:-}" ]] || continue
    term="$(tmux display-message -p -c "$client" '#{client_termname}' 2>/dev/null)" || continue
    "$script" "$term" "$client" >/dev/null 2>&1 || true
done < <(tmux list-clients -F '#{client_name}' 2>/dev/null || true)
