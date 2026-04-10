#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
copilot_hooks="$repo_root/.github/hooks/workmux-status/hooks.json"
sync_width_script="$repo_root/files/.tmux.d/tmux-sync-session-width.sh"

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

copilot_hooks_content="$(cat "$copilot_hooks")"
assert_contains "$copilot_hooks_content" "\$HOME/repo/tmux-agent-status/scripts/workmux-hook-start.sh" \
    "Copilot hook config should point at the plugin repo start hook"
assert_contains "$copilot_hooks_content" "\$HOME/repo/tmux-agent-status/scripts/workmux-hook-done.sh" \
    "Copilot hook config should point at the plugin repo done hook"

sync_width_content="$(cat "$sync_width_script")"
assert_contains "$sync_width_content" "repo/tmux-agent-status/scripts/tmux-status-left-preview.sh" \
    "tmux sync-width helper should shell out to the plugin repo preview script"

echo "All tmux agent-status integration regression tests passed"
