#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_file="$repo_root/files/.bashrc.d/13-cd-hist-plugin"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if [[ ! -r "$target_file" ]]; then
    fail "$target_file must exist and be readable"
fi

selector_block="$(
    awk '
        /^[[:space:]]*cd_target=\$\(/ { in_block=1 }
        in_block { print }
        in_block && /^[[:space:]]*\)/ { exit }
    ' "$target_file"
)"

if [[ -z "$selector_block" ]]; then
    fail "$target_file must contain a cd_target selector assignment"
fi

if grep -Eq '\bpercol\b' <<<"$selector_block"; then
    fail "$target_file selector block must not reference percol"
fi

if ! grep -Eq '\bfzf\b' <<<"$selector_block"; then
    fail "$target_file selector block must reference fzf"
fi

echo "PASS: cd-hist selector backend regression check"
