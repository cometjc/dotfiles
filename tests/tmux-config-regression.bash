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

window_status_format="$(grep -F 'set-option -g  window-status-format' "$tmux_conf")"
window_status_current_format="$(grep -F 'set-option -g  window-status-current-format' "$tmux_conf")"

assert_contains "$window_status_format" "tmux-workmux-status.sh" \
    "window-status-format should style workmux icons through the tmux-side helper"
assert_contains "$window_status_current_format" "tmux-workmux-status.sh" \
    "window-status-current-format should style workmux icons through the tmux-side helper"
assert_contains "$window_status_format" "prefix '#3a3a3a'" \
    "window-status-format should call the prefix mode with #3a3a3a fallback_bg"
assert_contains "$window_status_format" "suffix '#3a3a3a'" \
    "window-status-format should call the suffix mode with #3a3a3a fallback_bg"
assert_contains "$window_status_current_format" "prefix '#7f9a69'" \
    "window-status-current-format should call the prefix mode with #7f9a69 (active) fallback_bg"
assert_contains "$window_status_current_format" "suffix '#7f9a69'" \
    "window-status-current-format should call the suffix mode with #7f9a69 (active) fallback_bg"
assert_not_contains "$window_status_format" '#{?#{@workmux_status}' \
    "window-status-format label colour should be unconditional #a7c080 (name area bg is always #3a3a3a)"
assert_not_contains "$window_status_current_format" '#{@workmux_status}' \
    "window-status-current-format should not inline raw workmux icon value directly"

assert_contains "$window_status_format" "tmux-window-label.sh" \
    "window-status-format should keep the custom window label renderer"
assert_contains "$window_status_current_format" "tmux-window-label.sh" \
    "window-status-current-format should keep the custom window label renderer"

assert_not_contains "$window_status_format" "tmux-window-status.sh render" \
    "window-status-format should not call the legacy render helper"
assert_not_contains "$window_status_current_format" "tmux-window-status.sh render" \
    "window-status-current-format should not call the legacy render helper"
assert_contains "$window_status_format" "tmux-window-status.sh sync-workmux" \
    "window-status-format should poll Codex state into @workmux_status"
assert_contains "$window_status_current_format" "tmux-window-status.sh sync-workmux" \
    "window-status-current-format should poll Codex state into @workmux_status"

full_conf="$(cat "$tmux_conf")"
assert_contains "$full_conf" "tmux-window-status.sh mark-read" \
    "tmux.conf should keep the mark-read hook so polling-based Codex done/waiting icons clear after focus"

echo "All tmux config regression tests passed"
