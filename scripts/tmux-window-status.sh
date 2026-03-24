#!/usr/bin/env bash

set -euo pipefail

command="${1:?command is required}"
window_id="${2:?window_id is required}"
window_state_option="@codex_status_last_state"
window_unread_option="@codex_status_unread"
workmux_status_option="@workmux_status"
running_frames=('◐' '◓' '◑' '◒')

get_window_option() {
    tmux show-options -wqv -t "$window_id" "$1" 2>/dev/null || true
}

set_window_option() {
    tmux set-option -wq -t "$window_id" "$1" "$2"
}

unset_window_option() {
    tmux set-option -uw -t "$window_id" "$1"
}

is_codex_window() {
    local pane_command

    while IFS= read -r pane_command; do
        case "$pane_command" in
            codex*)
                return 0
                ;;
        esac
    done < <(tmux list-panes -t "$window_id" -F '#{pane_current_command}' 2>/dev/null || true)

    return 1
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
    local current_state last_state workmux_status

    current_state="$(detect_state)"
    last_state="$(get_window_option "$window_state_option")"
    workmux_status="$(get_window_option "$workmux_status_option")"

    # Always clear workmux unread status and bust cache when window is focused,
    # even if this is a plain idle window with no codex history.
    if [[ -n "$workmux_status" ]]; then
        unset_window_option "$workmux_status_option" 2>/dev/null || true
        local seq
        seq="$(tmux show-options -gqv @workmux_render_seq 2>/dev/null || true)"
        seq="${seq:-0}"
        tmux set-option -g @workmux_render_seq "$((seq + 1))" 2>/dev/null || true
        tmux refresh-client -S 2>/dev/null || true
    fi

    if [[ "$current_state" == "idle" && -z "$last_state" ]]; then
        return 0
    fi

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

status_icon_for_state() {
    local state="$1"
    local icon=""
    case "$state" in
        running)
            icon="${WORKMUX_ICON_WORKING:-}"
            [[ -n "$icon" ]] || icon="$(icon_from_workmux_config working)"
            printf '%s' "${icon:-🤖}"
            ;;
        waiting)
            icon="${WORKMUX_ICON_WAITING:-}"
            [[ -n "$icon" ]] || icon="$(icon_from_workmux_config waiting)"
            printf '%s' "${icon:-💬}"
            ;;
        "done")
            icon="${WORKMUX_ICON_DONE:-}"
            [[ -n "$icon" ]] || icon="$(icon_from_workmux_config "done")"
            printf '%s' "${icon:-✅}"
            ;;
    esac
}

icon_from_workmux_config() {
    local key="$1"
    local config_path value
    config_path="${WORKMUX_CONFIG_PATH:-$HOME/.config/workmux/config.yaml}"
    [[ -r "$config_path" ]] || return 1

    value="$(awk -v target="$key" '
        BEGIN { in_block = 0 }
        /^[[:space:]]*status_icons:[[:space:]]*$/ { in_block = 1; next }
        in_block && /^[^[:space:]]/ { in_block = 0 }
        in_block && $0 ~ "^[[:space:]]*" target ":[[:space:]]*" {
            sub("^[[:space:]]*" target ":[[:space:]]*", "", $0)
            print $0
            exit
        }
    ' "$config_path")"

    [[ -n "$value" ]] || return 1
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
        value="${value:1:${#value}-2}"
    else
        value="${value%%[[:space:]]#*}"
        value="${value%"${value##*[![:space:]]}"}"
    fi

    printf '%s' "$value"
}

sync_workmux_status() {
    local current_state last_state unread icon

    if ! is_codex_window; then
        return 0
    fi

    current_state="$(detect_state)"
    last_state="$(get_window_option "$window_state_option")"

    if [[ "$current_state" == "idle" && -z "$last_state" ]]; then
        return 0
    fi

    current_state="$(sync_state)"
    unread="$(get_window_option "$window_unread_option")"
    unread="${unread:-0}"

    case "$current_state" in
        running)
            icon="$(status_icon_for_state running)"
            set_window_option "$workmux_status_option" "$icon"
            ;;
        waiting)
            if [[ "$unread" == "1" ]]; then
                icon="$(status_icon_for_state waiting)"
                set_window_option "$workmux_status_option" "$icon"
            else
                unset_window_option "$workmux_status_option"
            fi
            ;;
        "done")
            if [[ "$unread" == "1" ]]; then
                icon="$(status_icon_for_state "done")"
                set_window_option "$workmux_status_option" "$icon"
            else
                unset_window_option "$workmux_status_option"
            fi
            ;;
        idle)
            unset_window_option "$workmux_status_option"
            ;;
    esac
}

render_marker() {
    local mode="$1"
    local current_state unread symbol color claude_status claude_waiting=0 pane_id pane_content output=""

    claude_status="$(get_window_option "@claude_status")"

    # Scan pane content for Claude Code state signals.
    # Patterns are anchored to line-start (^) so inline occurrences don't trigger.
    local claude_cogitated=0 claude_running_pane=0
    while IFS= read -r pane_id; do
        local pane_content
        pane_content="$(tmux capture-pane -p -t "$pane_id" 2>/dev/null)" || continue
        if grep -Fq -- 'Do you want to proceed?' <<<"$pane_content"; then
            claude_waiting=1
        fi
        if grep -Eq -- '^✻ .+ for [0-9]' <<<"$pane_content"; then
            claude_cogitated=1
        fi
        # Activity line: any leading char + space + text + …
        # Done state "✻ <verb> for <dur>" has no …, so it won't match here
        if grep -Eq -- '^. .+…' <<<"$pane_content"; then
            claude_running_pane=1
        fi
    done < <(tmux list-panes -t "$window_id" -F '#{pane_id}' 2>/dev/null)

    current_state="$(sync_state)"
    unread="$(get_window_option "$window_unread_option")"
    unread="${unread:-0}"
    symbol="$(symbol_for_state "$current_state")"

    # Claude Code indicator — waiting > cogitated(done) > spinner
    if ((claude_waiting)); then
        output+='#[fg=#e5c07b]|'
    elif ((claude_cogitated)); then
        output+='#[fg=#e5c07b]✻'
    elif [[ -n "$claude_status" ]] || ((claude_running_pane)); then
        output+="#[fg=#e5c07b]$(running_symbol)"
    fi

    # Codex / existing state indicator
    if [[ -n "$symbol" ]]; then
        if [[ "$current_state" == "running" ]]; then
            color="#e69875"
        elif [[ "$unread" == "1" ]]; then
            color="#e69875"
        elif [[ "$mode" == "active" ]]; then
            color="#262626"
        else
            color="#a7c080"
        fi
        output+="#[fg=${color}]${symbol}"
    fi

    [[ -n "$output" ]] && printf '%s' "$output"
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
    sync-workmux)
        sync_workmux_status
        ;;
    mark-read)
        mark_read
        ;;
    *)
        printf 'unsupported command: %s\n' "$command" >&2
        exit 1
        ;;
esac
