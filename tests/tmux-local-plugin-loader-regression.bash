#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
loader_script="$repo_root/scripts/tmux-local-plugins-loader.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_exists() {
    local path="$1"
    local message="$2"
    [[ -f "$path" ]] || fail "$message (missing: $path)"
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

home_dir="$temp_dir/home"
config_file="$temp_dir/tmux.conf"
plugin_dir="$home_dir/my_plugins/my_plugin"
marker_file="$temp_dir/loaded.txt"
mkdir -p "$plugin_dir"

cat >"$plugin_dir/my_plugin.tmux" <<EOF
#!/usr/bin/env bash
printf 'loaded' > "$marker_file"
EOF
chmod +x "$plugin_dir/my_plugin.tmux"

cat >"$config_file" <<'EOF'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin '$HOME/my_plugins/my_plugin'
EOF

HOME="$home_dir" bash "$loader_script" "$config_file"

assert_file_exists "$marker_file" "local plugin loader should execute local @plugin entries with \$HOME expansion"

echo "All tmux local-plugin loader regression tests passed"
