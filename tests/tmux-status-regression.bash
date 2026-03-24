#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status_script="$repo_root/scripts/tmux-window-status.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    if [[ "$actual" != "$expected" ]]; then
        fail "$message (expected: $expected, actual: $actual)"
    fi
}

create_fake_tmux_env() {
    local temp_dir state_dir fake_bin
    temp_dir="$(mktemp -d)"
    state_dir="$temp_dir/state"
    fake_bin="$temp_dir/bin"
    mkdir -p "$state_dir/windows" "$state_dir/panes" "$state_dir/pane_commands" "$state_dir/options" "$fake_bin"

    cat >"$fake_bin/tmux" <<'EOF'
#!/bin/bash
set -euo pipefail

state_dir="${TEST_TMUX_STATE_DIR:?}"
command="${1:?}"
shift

option_file() {
    local target="$1"
    local option_name="$2"
    local sanitized_target sanitized_option
    sanitized_target="$(printf '%s' "$target" | sed 's#[^A-Za-z0-9._-]#_#g')"
    sanitized_option="$(printf '%s' "$option_name" | sed 's#[^A-Za-z0-9._-]#_#g')"
    printf '%s/options/%s/%s\n' "$state_dir" "$sanitized_target" "$sanitized_option"
}

case "$command" in
    list-panes)
        target=""
        format='#{pane_id}'
        while (($#)); do
            case "$1" in
                -t)
                    target="$2"
                    shift 2
                    ;;
                -F)
                    format="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        while IFS= read -r pane_id; do
            case "$format" in
                '#{pane_id}')
                    printf '%s\n' "$pane_id"
                    ;;
                '#{pane_current_command}')
                    cat "$state_dir/pane_commands/$pane_id"
                    printf '\n'
                    ;;
                *)
                    echo "unsupported fake tmux list-panes format: $format" >&2
                    exit 1
                    ;;
            esac
        done <"$state_dir/windows/$target"
        ;;
    capture-pane)
        target=""
        while (($#)); do
            case "$1" in
                -t)
                    target="$2"
                    shift 2
                    ;;
                -p)
                    shift
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        cat "$state_dir/panes/$target"
        ;;
    show-options)
        target=""
        option_name=""
        while (($#)); do
            case "$1" in
                -t)
                    target="$2"
                    shift 2
                    ;;
                -wqv|-qv|-wv)
                    shift
                    ;;
                @*)
                    option_name="$1"
                    shift
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        option_path="$(option_file "$target" "$option_name")"
        if [[ -f "$option_path" ]]; then
            cat "$option_path"
        fi
        ;;
    set-option)
        target=""
        option_name=""
        unset_option=0
        while (($#)); do
            case "$1" in
                -t)
                    target="$2"
                    shift 2
                    ;;
                -uw|-u|-wu)
                    unset_option=1
                    shift
                    ;;
                -wq|-q|-w)
                    shift
                    ;;
                @*)
                    option_name="$1"
                    if ((unset_option)); then
                        shift
                    else
                        option_value="$2"
                        shift 2
                    fi
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        option_path="$(option_file "$target" "$option_name")"
        mkdir -p "$(dirname "$option_path")"
        if ((unset_option)); then
            rm -f "$option_path"
        else
            printf '%s' "$option_value" >"$option_path"
        fi
        ;;
    *)
        echo "unsupported fake tmux command: $command" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$fake_bin/tmux"

    printf '%s\n' "$temp_dir"
}

write_window_content() {
    local state_dir="$1"
    local window_id="$2"
    local pane_id="$3"
    local content="$4"
    local pane_command="${5:-codex}"

    printf '%s\n' "$pane_id" >"$state_dir/windows/$window_id"
    printf '%s' "$content" >"$state_dir/panes/$pane_id"
    printf '%s' "$pane_command" >"$state_dir/pane_commands/$pane_id"
}

read_window_option() {
    local state_dir="$1"
    local window_id="$2"
    local option_name="$3"
    local target_dir

    target_dir="$(printf '%s' "$window_id" | sed 's#[^A-Za-z0-9._-]#_#g')"
    option_name="$(printf '%s' "$option_name" | sed 's#[^A-Za-z0-9._-]#_#g')"
    if [[ -f "$state_dir/options/$target_dir/$option_name" ]]; then
        cat "$state_dir/options/$target_dir/$option_name"
    fi
}

run_status_script() {
    local fake_root="$1"
    shift
    TEST_TMUX_STATE_DIR="$fake_root/state" PATH="$fake_root/bin:/usr/bin:/bin" \
        "$status_script" "$@"
}

test_detect_prioritizes_running_over_waiting_and_done() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'| esc to interrupt\n· gpt-5.4\n• esc to interrupt\n'

    actual="$(run_status_script "$fake_root" detect "@1")"

    assert_eq "$actual" "running" "detect should prefer running when the pane still shows the interrupt prompt"
}

test_detect_returns_waiting_when_not_running() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'thinking...\n| esc to interrupt\n'

    actual="$(run_status_script "$fake_root" detect "@1")"

    assert_eq "$actual" "waiting" "detect should classify a waiting prompt when no running prompt remains"
}

test_detect_returns_done_when_gpt_marker_is_present_without_running_or_waiting() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'summary line\n· gpt-5.4\n'

    actual="$(run_status_script "$fake_root" detect "@1")"

    assert_eq "$actual" "done" "detect should classify completed output when only the gpt marker remains"
}

test_sync_marks_running_to_waiting_as_unread() {
    local fake_root state_dir actual unread
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    run_status_script "$fake_root" sync "@1" >/dev/null

    write_window_content "$state_dir" "@1" "%1" $'| esc to interrupt\n'
    actual="$(run_status_script "$fake_root" sync "@1")"
    unread="$(read_window_option "$state_dir" "@1" "@codex_status_unread")"

    assert_eq "$actual" "waiting" "sync should return waiting after a running pane switches to waiting"
    assert_eq "$unread" "1" "sync should flag running-to-waiting transitions as unread"
}

test_mark_read_clears_unread_for_waiting_without_removing_symbol() {
    local fake_root state_dir unread symbol
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    run_status_script "$fake_root" sync "@1" >/dev/null
    write_window_content "$state_dir" "@1" "%1" $'| esc to interrupt\n'
    run_status_script "$fake_root" sync "@1" >/dev/null

    run_status_script "$fake_root" mark-read "@1" >/dev/null
    unread="$(read_window_option "$state_dir" "@1" "@codex_status_unread")"
    symbol="$(run_status_script "$fake_root" symbol "@1")"

    assert_eq "$unread" "0" "mark-read should clear unread once the waiting window has been visited"
    assert_eq "$symbol" "|" "mark-read should not remove the waiting marker"
}

test_running_symbol_uses_spinner_frames() {
    local fake_root state_dir symbol
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    symbol="$(TMUX_STATUS_RUNNING_FRAME=2 run_status_script "$fake_root" symbol "@1")"

    assert_eq "$symbol" "◑" "running windows should render the requested spinner frame"
}

test_sync_marks_running_to_done_as_unread_and_uses_checkmark() {
    local fake_root state_dir actual unread symbol
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    run_status_script "$fake_root" sync "@1" >/dev/null

    write_window_content "$state_dir" "@1" "%1" $'response body\n· gpt-5.4\n'
    actual="$(run_status_script "$fake_root" sync "@1")"
    unread="$(read_window_option "$state_dir" "@1" "@codex_status_unread")"
    symbol="$(run_status_script "$fake_root" symbol "@1")"

    assert_eq "$actual" "done" "sync should classify completed output after the running prompt disappears"
    assert_eq "$unread" "1" "sync should flag running-to-done transitions as unread"
    assert_eq "$symbol" "✓" "done windows should render a checkmark marker"
}

test_direct_done_does_not_become_unread_without_running_transition() {
    local fake_root state_dir actual unread
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'response body\n· gpt-5.4\n'
    actual="$(run_status_script "$fake_root" sync "@1")"
    unread="$(read_window_option "$state_dir" "@1" "@codex_status_unread")"

    assert_eq "$actual" "done" "sync should still detect a completed pane without previous state"
    assert_eq "${unread:-}" "0" "sync should keep directly completed windows read by default"
}

test_detect_returns_idle_when_no_status_markers_exist() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'plain shell output\n'

    actual="$(run_status_script "$fake_root" detect "@1")"

    assert_eq "$actual" "idle" "detect should return idle when no status markers are visible"
}

test_sync_workmux_sets_working_icon_for_running_codex_window() {
    local fake_root state_dir icon
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    WORKMUX_ICON_WORKING='WORKING_ICON' run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    icon="$(read_window_option "$state_dir" "@1" "@workmux_status")"

    assert_eq "$icon" "WORKING_ICON" "running Codex windows should publish the working icon via @workmux_status"
}

test_sync_workmux_sets_done_icon_until_marked_read() {
    local fake_root state_dir icon
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'• esc to interrupt\n'
    WORKMUX_ICON_WORKING='WORKING_ICON' run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    write_window_content "$state_dir" "@1" "%1" $'response body\n· gpt-5.4\n'
    WORKMUX_ICON_DONE='DONE_ICON' run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    icon="$(read_window_option "$state_dir" "@1" "@workmux_status")"
    assert_eq "$icon" "DONE_ICON" "completed Codex windows should expose the done icon while unread"

    run_status_script "$fake_root" mark-read "@1" >/dev/null
    WORKMUX_ICON_DONE='DONE_ICON' run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    icon="$(read_window_option "$state_dir" "@1" "@workmux_status")"
    assert_eq "${icon:-}" "" "mark-read should hide done icons for the polling fallback"
}

test_sync_workmux_does_not_touch_non_codex_windows() {
    local fake_root state_dir icon
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'plain shell output\n'
    run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    icon="$(read_window_option "$state_dir" "@1" "@workmux_status")"

    assert_eq "${icon:-}" "" "sync-workmux should not clear or set workmux status for unrelated windows"
}

test_sync_workmux_does_not_override_other_agent_hook_status() {
    local fake_root state_dir icon
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    write_window_content "$state_dir" "@1" "%1" $'response body\n· gpt-5.4\n' "copilot"
    TEST_TMUX_STATE_DIR="$state_dir" PATH="$fake_root/bin:/usr/bin:/bin" tmux set-option -wq -t "@1" @workmux_status "COPILOT_WORKING"

    run_status_script "$fake_root" sync-workmux "@1" >/dev/null
    icon="$(read_window_option "$state_dir" "@1" "@workmux_status")"

    assert_eq "$icon" "COPILOT_WORKING" "sync-workmux should not override hook-managed status in non-Codex windows"
}

test_detect_prioritizes_running_over_waiting_and_done
test_detect_returns_waiting_when_not_running
test_detect_returns_done_when_gpt_marker_is_present_without_running_or_waiting
test_sync_marks_running_to_waiting_as_unread
test_mark_read_clears_unread_for_waiting_without_removing_symbol
test_running_symbol_uses_spinner_frames
test_sync_marks_running_to_done_as_unread_and_uses_checkmark
test_direct_done_does_not_become_unread_without_running_transition
test_detect_returns_idle_when_no_status_markers_exist
test_sync_workmux_sets_working_icon_for_running_codex_window
test_sync_workmux_sets_done_icon_until_marked_read
test_sync_workmux_does_not_touch_non_codex_windows
test_sync_workmux_does_not_override_other_agent_hook_status

echo "All tmux status regression tests passed"
