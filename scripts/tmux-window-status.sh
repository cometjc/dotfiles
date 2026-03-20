#!/usr/bin/env bash

set -euo pipefail

command="${1:?command is required}"
window_id="${2:?window_id is required}"
window_state_option="@codex_status_last_state"
window_unread_option="@codex_status_unread"
running_frames=('◐' '◓' '◑' '◒')

get_window_option() {
    tmux show-options -wqv -t "$window_id" "$1" 2>/dev/null || true
}

set_window_option() {
    tmux set-option -wq -t "$window_id" "$1" "$2"
}

detect_state() {
    local pane_id pane_content has_waiting=0 has_done=0

    while IFS= read -r pane_id; do
        pane_content="$(tmux capture-pane -p -t "$pane_id")"

        if grep -Fq -- '• esc to interrupt' <<<"$pane_content"; then
            printf 'running'
            return 0
        fi

        if grep -Fq -- '| esc to interrupt' <<<"$pane_content"; then
            has_waiting=1
        fi

        if grep -Fq -- '· gpt-' <<<"$pane_content"; then
            has_done=1
        fi
    done < <(tmux list-panes -t "$window_id" -F '#{pane_id}')

    if ((has_waiting)); then
        printf 'waiting'
    elif ((has_done)); then
        printf 'done'
    else
        printf 'idle'
    fi
}

sync_state() {
    local current_state last_state unread

    current_state="$(detect_state)"
    last_state="$(get_window_option "$window_state_option")"
    unread="$(get_window_option "$window_unread_option")"
    unread="${unread:-0}"

    case "$current_state" in
        running)
            unread=0
            ;;
        waiting)
            if [[ "$last_state" == "running" ]]; then
                unread=1
            fi
            ;;
        done)
            if [[ "$last_state" == "running" ]]; then
                unread=1
            fi
            ;;
        idle)
            unread=0
            ;;
    esac

    set_window_option "$window_state_option" "$current_state"
    set_window_option "$window_unread_option" "$unread"
    printf '%s' "$current_state"
}

mark_read() {
    local current_state

    current_state="$(detect_state)"
    set_window_option "$window_state_option" "$current_state"

    case "$current_state" in
        waiting | done)
            set_window_option "$window_unread_option" 0
            ;;
        running | idle)
            set_window_option "$window_unread_option" 0
            ;;
    esac
}

symbol_for_state() {
    case "$1" in
        running)
            running_symbol
            ;;
        waiting)
            printf '|'
            ;;
        done)
            printf '✓'
            ;;
        idle) ;;
    esac
}

running_symbol() {
    local frame_index

    frame_index="${TMUX_STATUS_RUNNING_FRAME:-$(($(date +%s) % ${#running_frames[@]}))}"
    printf '%s' "${running_frames[$((frame_index % ${#running_frames[@]}))]}"
}

render_marker() {
    local mode="$1"
    local current_state unread symbol color

    current_state="$(sync_state)"
    unread="$(get_window_option "$window_unread_option")"
    unread="${unread:-0}"
    symbol="$(symbol_for_state "$current_state")"

    [[ -n "$symbol" ]] || return 0

    if [[ "$current_state" == "running" ]]; then
        color="#e69875"
    elif [[ "$unread" == "1" ]]; then
        color="#e69875"
    elif [[ "$mode" == "active" ]]; then
        color="#262626"
    else
        color="#a7c080"
    fi

    printf '#[fg=%s]%s' "$color" "$symbol"
}

case "$command" in
    detect)
        detect_state
        ;;
    sync)
        sync_state
        ;;
    symbol)
        symbol_for_state "$(sync_state)"
        ;;
    render)
        render_marker "${3:-inactive}"
        ;;
    mark-read)
        mark_read
        ;;
    *)
        printf 'unsupported command: %s\n' "$command" >&2
        exit 1
        ;;
esac
