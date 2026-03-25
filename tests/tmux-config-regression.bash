#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmux_conf="$repo_root/files/.tmux.conf"

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

full_conf="$(cat "$tmux_conf")"
assert_contains "$full_conf" "@plugin                  '\$HOME/repo/tmux-agent-status'" \
    "tmux.conf should load tmux-agent-status as a local TPM plugin via \$HOME expansion"
assert_contains "$full_conf" "tmux-local-plugins-loader.sh" \
    "tmux.conf should invoke the local-plugin loader so local @plugin paths are actually executed"
assert_not_contains "$full_conf" "\$HOME/repo/dotfiles/scripts/tmux-window-status.sh" \
    "tmux.conf should not reference the old dotfiles tmux-window-status script directly"
assert_not_contains "$full_conf" "\$HOME/repo/dotfiles/scripts/tmux-window-render.sh" \
    "tmux.conf should not reference the old dotfiles tmux-window-render script directly"

mapfile -t c_z_binding_lines < <(grep -E '^[[:space:]]*bind-key[[:space:]]+-n[[:space:]]+C-z([[:space:]]|$)' "$tmux_conf" || true)
if [[ "${#c_z_binding_lines[@]}" -eq 0 ]]; then
    fail "tmux.conf should define exactly one bare C-z binding (missing)"
fi
if [[ "${#c_z_binding_lines[@]}" -ne 1 ]]; then
    fail "tmux.conf should define exactly one bare C-z binding (found ${#c_z_binding_lines[@]})"
fi
c_z_binding_line="${c_z_binding_lines[0]}"
assert_contains "$c_z_binding_line" "send-keys C-z" \
    "bare C-z binding must send a literal Ctrl-z to the pane first"
assert_contains "$c_z_binding_line" 'send-keys "bg" Enter' \
    "bare C-z binding must background the most recent job through bg"

tmux_socket="$repo_root/.tmux-c-z-test.sock"
rm -f "$tmux_socket"
tmux_cmd=(tmux -S "$tmux_socket" -f /dev/null)
cleanup_tmux_server() {
    "${tmux_cmd[@]}" kill-server >/dev/null 2>&1 || true
    rm -f "$tmux_socket"
}
trap cleanup_tmux_server EXIT

"${tmux_cmd[@]}" new-session -d -s cztmp >/dev/null
tmux_ready=0
for _ in {1..20}; do
    if "${tmux_cmd[@]}" list-sessions >/dev/null 2>&1; then
        tmux_ready=1
        break
    fi
    sleep 0.1
done
if [[ "$tmux_ready" -ne 1 ]]; then
    fail "isolated tmux test server did not become ready"
fi

if ! printf '%s\n' "$c_z_binding_line" | "${tmux_cmd[@]}" source-file -; then
    fail "isolated tmux test server failed to source the bare C-z binding"
fi

root_keys="$("${tmux_cmd[@]}" list-keys -T root)"
assert_contains "$root_keys" "C-z" \
    "root table should register the bare C-z background binding"
assert_contains "$root_keys" "send-keys bg Enter" \
    "root table should canonicalize the background binding to send-keys bg Enter"

prefix_keys="$("${tmux_cmd[@]}" list-keys -T prefix)"
copy_mode_keys="$("${tmux_cmd[@]}" list-keys -T copy-mode)"
copy_mode_vi_keys="$("${tmux_cmd[@]}" list-keys -T copy-mode-vi)"

assert_not_contains "$prefix_keys" "send-keys bg Enter" \
    "prefix table must not register the bare C-z background binding"
assert_not_contains "$copy_mode_keys" "send-keys bg Enter" \
    "copy-mode table must not register the bare C-z background binding"
assert_not_contains "$copy_mode_vi_keys" "send-keys bg Enter" \
    "copy-mode-vi table must not register the bare C-z background binding"

echo "All tmux config regression tests passed"
