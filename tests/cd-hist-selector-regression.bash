#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_file="$repo_root/files/.bashrc.d/13-cd-hist-plugin"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

content="$(cat "$target_file")"

if grep -Fq 'percol' <<<"$content"; then
    fail "$target_file must not reference percol"
fi

if ! grep -Fq 'fzf' <<<"$content"; then
    fail "$target_file must reference fzf"
fi

echo "PASS: cd-hist selector backend regression check"
