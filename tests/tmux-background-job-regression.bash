#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_script="$repo_root/scripts/tmux-background-job.sh"

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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        fail "$message (missing: $needle)"
    fi
}

create_fake_tmux_env() {
    local temp_dir state_dir fake_bin
    temp_dir="$(mktemp -d)"
    state_dir="$temp_dir/state"
    fake_bin="$temp_dir/bin"
    mkdir -p "$state_dir/capture-pane" "$fake_bin"

    cat >"$fake_bin/tmux" <<'EOF'
#!/bin/bash
set -euo pipefail

state_dir="${TEST_TMUX_STATE_DIR:?}"
command="${1:?}"
shift

record_command() {
    printf '%s\n' "$*" >>"$state_dir/tmux.log"
}

case "$command" in
    send-keys)
        record_command "send-keys $*"
        ;;
    display-message)
        record_command "display-message $*"
        index_file="$state_dir/display-index"
        if [[ -f "$index_file" ]]; then
            read -r index <"$index_file"
        else
            index=0
        fi

        mapfile -t commands <"$state_dir/pane-current-command-seq"
        if [[ "${#commands[@]}" -eq 0 ]]; then
            exit 1
        fi

        if (( index >= ${#commands[@]} )); then
            current="${commands[-1]}"
        else
            current="${commands[$index]}"
        fi

        printf '%s' "$current"
        printf '%s\n' "$((index + 1))" >"$index_file"
        ;;
    capture-pane)
        record_command "capture-pane $*"
        index_file="$state_dir/capture-index"
        if [[ -f "$index_file" ]]; then
            read -r index <"$index_file"
        else
            index=0
        fi

        mapfile -t capture_files < <(find "$state_dir/capture-pane" -maxdepth 1 -type f -name '*.txt' | sort)
        if [[ "${#capture_files[@]}" -eq 0 ]]; then
            exit 1
        fi

        if (( index >= ${#capture_files[@]} )); then
            capture_file="${capture_files[-1]}"
        else
            capture_file="${capture_files[$index]}"
        fi

        cat "$capture_file"
        printf '%s\n' "$((index + 1))" >"$index_file"
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

run_target_script() {
    local fake_root="$1"
    shift
    TEST_TMUX_STATE_DIR="$fake_root/state" PATH="$fake_root/bin:/usr/bin:/bin" \
        "$target_script" "$@"
}

read_tmux_log() {
    local fake_root="$1"
    cat "$fake_root/state/tmux.log"
}

count_log_lines() {
    local fake_root="$1"
    local needle="$2"
    grep -cF "$needle" "$fake_root/state/tmux.log" || true
}

write_capture_step() {
    local fake_root="$1"
    local index="$2"
    local content="$3"
    printf '%s\n' "$content" >"$fake_root/state/capture-pane/$index.txt"
}

test_waits_for_stopped_output_before_sending_bg() {
    local fake_root tmux_log
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN

    cat >"$fake_root/state/pane-current-command-seq" <<'EOF'
bash
bash
bash
EOF
    write_capture_step "$fake_root" "00" "copilot --allow-all"
    write_capture_step "$fake_root" "01" "bash-5.2$"
    write_capture_step "$fake_root" "02" "[1]+  Stopped                 copilot --allow-all"

    TMUX_BACKGROUND_JOB_WAIT_INTERVAL_SECONDS=0 \
        run_target_script "$fake_root" "%1" "copilot"

    tmux_log="$(read_tmux_log "$fake_root")"
    assert_contains "$tmux_log" "send-keys -t %1 C-z" \
        "background-job helper should suspend the foreground program first"
    assert_contains "$tmux_log" "send-keys -t %1 bg Enter" \
        "background-job helper should background the job only after the stopped marker appears"
    assert_eq "$(count_log_lines "$fake_root" "display-message -p -t %1 #{pane_current_command}")" "3" \
        "background-job helper should keep polling until both shell control and stopped output are visible"
    assert_eq "$(count_log_lines "$fake_root" "capture-pane -p -t %1 -S -4")" "3" \
        "background-job helper should poll the pane tail for the stopped marker"
}

test_sends_bg_after_timeout_when_stopped_output_never_appears() {
    local fake_root tmux_log
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN

    cat >"$fake_root/state/pane-current-command-seq" <<'EOF'
bash
bash
bash
EOF
    write_capture_step "$fake_root" "00" "copilot --allow-all"
    write_capture_step "$fake_root" "01" "bash-5.2$"
    write_capture_step "$fake_root" "02" "bash-5.2$"

    TMUX_BACKGROUND_JOB_WAIT_INTERVAL_SECONDS=0 \
        TMUX_BACKGROUND_JOB_WAIT_MAX_ATTEMPTS=3 \
        run_target_script "$fake_root" "%1" "copilot"

    tmux_log="$(read_tmux_log "$fake_root")"
    assert_contains "$tmux_log" "send-keys -t %1 C-z" \
        "background-job helper should still send Ctrl-z before timing out"
    assert_contains "$tmux_log" "send-keys -t %1 bg Enter" \
        "background-job helper should still send bg after the wait window expires"
    assert_eq "$(count_log_lines "$fake_root" "display-message -p -t %1 #{pane_current_command}")" "3" \
        "background-job helper should stop polling after the configured timeout budget"
    assert_eq "$(count_log_lines "$fake_root" "capture-pane -p -t %1 -S -4")" "3" \
        "background-job helper should stop polling pane output after the configured timeout budget"
}

test_waits_for_stopped_output_before_sending_bg
test_sends_bg_after_timeout_when_stopped_output_never_appears

echo "All tmux background-job regression tests passed"
