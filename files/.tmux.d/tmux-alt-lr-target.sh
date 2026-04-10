#!/usr/bin/env bash

set -euo pipefail

command="${1:?command is required}"
option_name="@alt_lr_target"
default_target="${2:-remote}"

current_target() {
    local current
    current="$(tmux show-options -gqv "$option_name" 2>/dev/null || true)"
    if [[ -n "$current" ]]; then
        printf '%s' "$current"
    else
        printf '%s' "$default_target"
    fi
}

set_target() {
    tmux set-option -gq "$option_name" "$1"
}

ensure_default() {
    local current
    current="$(tmux show-options -gqv "$option_name" 2>/dev/null || true)"
    if [[ -z "$current" ]]; then
        current="$default_target"
        set_target "$current"
    fi
    printf '%s' "$current"
}

toggle_target() {
    local current next
    current="$(current_target)"

    if [[ "$current" == "remote" ]]; then
        next="local"
    else
        next="remote"
    fi

    set_target "$next"
    tmux display-message -d 2000 "Alt+Left/Right: $next"
    printf '%s' "$next"
}

case "$command" in
    ensure-default)
        ensure_default
        ;;
    toggle)
        toggle_target
        ;;
    *)
        printf 'unsupported command: %s\n' "$command" >&2
        exit 1
        ;;
esac
