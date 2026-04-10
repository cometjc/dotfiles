#!/usr/bin/env bash

set -euo pipefail

config_path="${1:?config_path is required}"

[[ -r "$config_path" ]] || exit 0

extract_plugins() {
    python - "$config_path" <<'PY'
import re
import sys

pattern = re.compile(r"^\s*set(?:-option)?\s+-g\s+@plugin\s+['\"]([^'\"]+)['\"]")

with open(sys.argv[1], encoding="utf-8") as handle:
    for line in handle:
        match = pattern.search(line)
        if match:
            print(match.group(1))
PY
}

expand_local_path() {
    local plugin_path="$1"
    plugin_path="${plugin_path/#\~/$HOME}"
    plugin_path="${plugin_path/#\$HOME/$HOME}"
    printf '%s\n' "$plugin_path"
}

source_local_plugin() {
    local plugin_path="$1"
    local tmux_file

    [[ -d "$plugin_path" ]] || return 0

    for tmux_file in "$plugin_path"/*.tmux; do
        [[ -f "$tmux_file" ]] || continue
        "$tmux_file" >/dev/null 2>&1
    done
}

while IFS= read -r plugin; do
    plugin="$(expand_local_path "$plugin")"
    case "$plugin" in
        /*)
            source_local_plugin "$plugin"
            ;;
    esac
done < <(extract_plugins)
