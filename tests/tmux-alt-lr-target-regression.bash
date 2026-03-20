#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_script="$repo_root/scripts/tmux-alt-lr-target.sh"

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
    mkdir -p "$state_dir/options" "$state_dir/messages" "$fake_bin"

    cat >"$fake_bin/tmux" <<'EOF'
#!/bin/bash
set -euo pipefail

state_dir="${TEST_TMUX_STATE_DIR:?}"
command="${1:?}"
shift

option_file() {
    local option_name="$1"
    local sanitized_option
    sanitized_option="$(printf '%s' "$option_name" | sed 's#[^A-Za-z0-9._-]#_#g')"
    printf '%s/options/%s\n' "$state_dir" "$sanitized_option"
}

case "$command" in
    show-options)
        option_name=""
        while (($#)); do
            case "$1" in
                -gqv|-qv|-gv)
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
        option_path="$(option_file "$option_name")"
        if [[ -f "$option_path" ]]; then
            cat "$option_path"
        fi
        ;;
    set-option)
        option_name=""
        option_value=""
        while (($#)); do
            case "$1" in
                -gq|-q|-g)
                    shift
                    ;;
                @*)
                    option_name="$1"
                    option_value="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        option_path="$(option_file "$option_name")"
        printf '%s' "$option_value" >"$option_path"
        ;;
    display-message)
        if [[ "${1:-}" == "-d" ]]; then
            shift 2
        fi
        printf '%s' "${1:-}" >"$state_dir/messages/last"
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

read_option() {
    local state_dir="$1"
    local option_name="$2"
    local option_path

    option_path="$state_dir/options/$(printf '%s' "$option_name" | sed 's#[^A-Za-z0-9._-]#_#g')"
    if [[ -f "$option_path" ]]; then
        cat "$option_path"
    fi
}

read_last_message() {
    local state_dir="$1"
    if [[ -f "$state_dir/messages/last" ]]; then
        cat "$state_dir/messages/last"
    fi
}

run_target_script() {
    local fake_root="$1"
    shift
    TEST_TMUX_STATE_DIR="$fake_root/state" PATH="$fake_root/bin:/usr/bin:/bin" \
        "$target_script" "$@"
}

test_ensure_default_sets_remote_when_option_is_missing() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    actual="$(run_target_script "$fake_root" ensure-default)"

    assert_eq "$actual" "remote" "ensure-default should report the default mode"
    assert_eq "$(read_option "$state_dir" "@alt_lr_target")" "remote" \
        "ensure-default should initialize the target mode to remote when it is unset"
}

test_ensure_default_preserves_existing_local_mode() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    printf 'local' >"$state_dir/options/_alt_lr_target"

    actual="$(run_target_script "$fake_root" ensure-default)"

    assert_eq "$actual" "local" "ensure-default should keep reporting the existing mode"
    assert_eq "$(read_option "$state_dir" "@alt_lr_target")" "local" \
        "ensure-default should not overwrite an existing local mode"
}

test_toggle_switches_remote_to_local() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    printf 'remote' >"$state_dir/options/_alt_lr_target"

    actual="$(run_target_script "$fake_root" toggle)"

    assert_eq "$actual" "local" "toggle should report the new mode after switching from remote"
    assert_eq "$(read_option "$state_dir" "@alt_lr_target")" "local" \
        "toggle should persist the new local mode"
    assert_eq "$(read_last_message "$state_dir")" "Alt+Left/Right: local" \
        "toggle should display the updated local mode"
}

test_toggle_switches_local_to_remote() {
    local fake_root state_dir actual
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN
    state_dir="$fake_root/state"

    printf 'local' >"$state_dir/options/_alt_lr_target"

    actual="$(run_target_script "$fake_root" toggle)"

    assert_eq "$actual" "remote" "toggle should report the new mode after switching from local"
    assert_eq "$(read_option "$state_dir" "@alt_lr_target")" "remote" \
        "toggle should persist the new remote mode"
    assert_eq "$(read_last_message "$state_dir")" "Alt+Left/Right: remote" \
        "toggle should display the updated remote mode"
}

test_ensure_default_sets_remote_when_option_is_missing
test_ensure_default_preserves_existing_local_mode
test_toggle_switches_remote_to_local
test_toggle_switches_local_to_remote

echo "All tmux alt_lr_target regression tests passed"
