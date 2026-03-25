#!/usr/bin/env bash
#
# ─── DESIGN: Agent status & unread mechanism ─────────────────────────────────
#
# STATE OPTIONS (per-window)
#   @workmux_status        Icon emoji set by agent hooks or Codex detection.
#                          Values: 🤖 (running)  💬 (waiting)  ✅ (done)  "" (idle)
#   @codex_status_unread   Unread flag.
#                          "1"  = explicitly unread (Codex path)
#                          "0"  = explicitly cleared (mark_read ran)
#                          ""   = never written (workmux-hooked windows)
#   @codex_status_last_state  Last known Codex state string; "" for non-Codex windows.
#
# GLOBAL OPTIONS
#   @workmux_render_seq    Monotonically increasing counter used as a cache-bust
#                          key in window-status-format args.  Incrementing it
#                          forces tmux to re-execute the #() render command.
#
# TWO ICON-SETTING PATHS
#   Codex path    sync_workmux_status detects state by scanning pane content,
#                 calls sync_state which writes both @workmux_status AND
#                 @codex_status_unread ("1" on transition to done/waiting).
#
#   Workmux path  External workmux hooks set @workmux_status directly.
#                 @codex_status_unread is never touched → stays "".
#
# UNREAD INFERENCE (render script)
#   The render script treats a window as unread when:
#     • @codex_status_unread == "1"  (Codex path explicit)
#     • @codex_status_unread == ""   AND icon ∈ {✅, 💬}  (workmux implicit)
#   @codex_status_unread == "0" (mark_read cleared it) → never unread.
#   Current window (@window_active == 1) never shows the orange highlight.
#
# MARK-READ INVARIANT
#   mark_read MUST write @codex_status_unread = 0 AND increment
#   @workmux_render_seq whenever needs_bust is true — even if the early-return
#   branch fires (idle + no last_state).  Workmux-hooked windows always hit
#   that early return; writing the flag inside the needs_bust block is the only
#   place where the clear is guaranteed to land.
#
# ICON LIFETIME
#   Icon persists as long as the agent program is open (running/waiting/done).
#   It is cleared only when the agent exits (idle state via sync_workmux_status).
#   mark_read does NOT clear the icon — it only clears the unread highlight.
#
# PRINCIPLES TO PRESERVE
#   1. Never clear @workmux_status in mark_read.
#   2. Always bust @workmux_render_seq when clearing unread (both paths).
#   3. Write @codex_status_unread = 0 before any early return when needs_bust.
#   4. The render script must read @codex_status_unread raw (before :-0 default)
#      to distinguish "never written" ("") from "explicitly cleared" ("0").
#
# TESTING
#   Unit / regression:
#     bash tests/tmux-status-regression.bash   # state machine + mark_read logic
#     bash tests/tmux-config-regression.bash    # .tmux.conf format string shape
#
#   Manual (Codex path):
#     1. Open a Codex window and run a task.
#     2. Switch to another window while Codex is running.
#     3. When Codex finishes, the non-current window label should turn orange.
#     4. Switch back to the Codex window → orange clears immediately.
#     5. Switch away again → label stays normal.
#
#   Manual (workmux path / Claude Code):
#     Same steps as above; workmux hooks fire instead of pane detection.
#     Confirm orange appears on ✅/💬 and clears on focus.
# ─────────────────────────────────────────────────────────────────────────────

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
    local current_state last_state unread workmux_status

    current_state="$(detect_state)"
    last_state="$(get_window_option "$window_state_option")"
    unread="$(get_window_option "$window_unread_option")"
    workmux_status="$(get_window_option "$workmux_status_option")"

    # Bust render cache when clearing the unread highlight so the orange
    # label disappears immediately on focus.  The icon itself is NOT cleared
    # here — it persists until the agent exits (idle state via sync_workmux_status).
    #
    # Also bust when @codex_status_unread is unset (empty) and a completion icon
    # is present: workmux-hooked windows (Claude Code) set @workmux_status
    # directly without touching @codex_status_unread, so an unset flag on ✅/💬
    # means it is being seen for the first time and the orange must clear.
    local needs_bust=0
    if [[ "$unread" == "1" ]]; then
        needs_bust=1
    elif [[ -z "$unread" && ("$workmux_status" == '✅' || "$workmux_status" == '💬') ]]; then
        needs_bust=1
    fi

    if ((needs_bust)); then
        local seq
        seq="$(tmux show-options -gqv @workmux_render_seq 2>/dev/null || true)"
        seq="${seq:-0}"
        tmux set-option -g @workmux_render_seq "$((seq + 1))" 2>/dev/null || true
        tmux refresh-client -S 2>/dev/null || true
        # Write the cleared flag now so the render script sees "0" after the
        # cache bust.  This is needed for workmux-hooked windows (Claude Code)
        # where @codex_status_unread starts unset ("") and the early-return
        # below would otherwise exit before the flag gets written.
        set_window_option "$window_unread_option" 0
    fi

    unread="${unread:-0}"

    if [[ "$current_state" == "idle" && -z "$last_state" ]]; then
        return 0
    fi

    set_window_option "$window_state_option" "$current_state"
    set_window_option "$window_unread_option" 0
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
    local current_state last_state icon

    if ! is_codex_window; then
        return 0
    fi

    current_state="$(detect_state)"
    last_state="$(get_window_option "$window_state_option")"

    if [[ "$current_state" == "idle" && -z "$last_state" ]]; then
        return 0
    fi

    current_state="$(sync_state)"

    # Icon persists as long as the agent program is open (running/waiting/done).
    # It is cleared only when the agent exits (idle).  The unread flag is
    # managed separately by mark_read and controls the orange label highlight.
    case "$current_state" in
        running)
            icon="$(status_icon_for_state running)"
            set_window_option "$workmux_status_option" "$icon"
            ;;
        waiting)
            icon="$(status_icon_for_state waiting)"
            set_window_option "$workmux_status_option" "$icon"
            ;;
        "done")
            icon="$(status_icon_for_state "done")"
            set_window_option "$workmux_status_option" "$icon"
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
