#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_script="$repo_root/files/.tmux.d/tmux-term-keybindings.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        fail "$message (missing: $needle)"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        fail "$message (unexpected: $needle)"
    fi
}

create_fake_tmux_env() {
    local temp_dir state_dir fake_bin
    temp_dir="$(mktemp -d)"
    state_dir="$temp_dir/state"
    fake_bin="$temp_dir/bin"
    mkdir -p "$state_dir" "$fake_bin"

    cat >"$fake_bin/tmux" <<'TMUXEOF'
#!/bin/bash
set -euo pipefail

state_dir="${TEST_TMUX_STATE_DIR:?}"
printf '%s\n' "$*" >>"$state_dir/tmux.log"

case "${1:-}" in
    display-popup)
        exit 0
        ;;
    unbind-key|bind-key)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
TMUXEOF
    chmod +x "$fake_bin/tmux"

    printf '%s\n' "$temp_dir"
}

read_tmux_log() {
    local fake_root="$1"
    cat "$fake_root/state/tmux.log"
}

run_target_script() {
    local fake_root="$1"
    shift
    TEST_TMUX_STATE_DIR="$fake_root/state" PATH="$fake_root/bin:/usr/bin:/bin" \
        "$target_script" "$@"
}

test_switch_from_putty_to_unknown_clears_stale_global_bindings() {
    local fake_root tmux_log
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN

    run_target_script "$fake_root" putty-256color /tmp
    run_target_script "$fake_root" xterm-256color /tmp

    tmux_log="$(read_tmux_log "$fake_root")"

    assert_contains "$tmux_log" "bind-key -n M-Left previous-window" \
        "putty attach should bind Alt+Left"
    assert_contains "$tmux_log" "bind-key -n M-Right next-window" \
        "putty attach should bind Alt+Right"
    assert_contains "$tmux_log" "unbind-key -n M-Left" \
        "unknown attach should clear stale Alt+Left binding"
    assert_contains "$tmux_log" "unbind-key -n M-Right" \
        "unknown attach should clear stale Alt+Right binding"
    assert_contains "$tmux_log" "unbind-key -n C-Left" \
        "unknown attach should clear stale Ctrl+Left binding"
    assert_contains "$tmux_log" "unbind-key -n C-Right" \
        "unknown attach should clear stale Ctrl+Right binding"
    assert_not_contains "$tmux_log" "bind-key -n C-Left previous-window" \
        "unknown attach should not force Ctrl mode"
}

test_switch_from_linux_to_unknown_clears_stale_global_bindings() {
    local fake_root tmux_log
    fake_root="$(create_fake_tmux_env)"
    trap 'rm -rf "$fake_root"' RETURN

    run_target_script "$fake_root" linux /tmp
    run_target_script "$fake_root" xterm-256color /tmp

    tmux_log="$(read_tmux_log "$fake_root")"

    assert_contains "$tmux_log" "bind-key -n C-Left previous-window" \
        "linux attach should bind Ctrl+Left"
    assert_contains "$tmux_log" "bind-key -n C-Right next-window" \
        "linux attach should bind Ctrl+Right"
    assert_contains "$tmux_log" "unbind-key -n C-Left" \
        "unknown attach should clear stale Ctrl+Left binding"
    assert_contains "$tmux_log" "unbind-key -n C-Right" \
        "unknown attach should clear stale Ctrl+Right binding"
    assert_contains "$tmux_log" "unbind-key -n M-Left" \
        "unknown attach should clear stale Alt+Left binding"
    assert_contains "$tmux_log" "unbind-key -n M-Right" \
        "unknown attach should clear stale Alt+Right binding"
    assert_not_contains "$tmux_log" "bind-key -n M-Left previous-window" \
        "unknown attach should not force Alt mode"
}

test_switch_from_putty_to_unknown_clears_stale_global_bindings
test_switch_from_linux_to_unknown_clears_stale_global_bindings

echo "All tmux term-keybindings regression tests passed"
