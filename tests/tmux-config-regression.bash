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

assert_contains "$window_status_format" "tmux-window-render.sh" \
    "window-status-format should style workmux icons through the tmux-side helper"
assert_contains "$window_status_current_format" "tmux-window-render.sh" \
    "window-status-current-format should style workmux icons through the tmux-side helper"
assert_contains "$window_status_format" "'#3a3a3a' '#a7c080'" \
    "window-status-format should pass #3a3a3a tab_bg and #a7c080 label_fg to render script"
assert_contains "$window_status_current_format" "'#7f9a69' '#262626'" \
    "window-status-current-format should pass #7f9a69 tab_bg and #262626 label_fg to render script"
assert_not_contains "$window_status_format" '#{?#{@workmux_status}' \
    "window-status-format should not conditionally branch on icon presence"
assert_not_contains "$window_status_current_format" '#{@workmux_status}' \
    "window-status-current-format should not inline raw workmux icon value directly"

assert_not_contains "$window_status_format" "tmux-window-label.sh" \
    "window-status-format should use tmux-window-render.sh, not the old label helper"
assert_not_contains "$window_status_current_format" "tmux-window-label.sh" \
    "window-status-current-format should use tmux-window-render.sh, not the old label helper"

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
