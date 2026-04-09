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

echo "All tmux config regression tests passed"
