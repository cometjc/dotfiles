#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

fake_bin="$temp_dir/bin"
temp_home="$temp_dir/home"
mkdir -p "$fake_bin" "$temp_home/.cache"

cat >"$fake_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "activate" && "${2:-}" == "bash" ]]; then
    cat <<'SCRIPT'
_mise_hook_chpwd() { return 0; }
chpwd_functions+=(_mise_hook_chpwd)
SCRIPT
    exit 0
fi
exit 0
EOF
chmod +x "$fake_bin/mise"

output="$(
    HOME="$temp_home" PATH="$fake_bin:/usr/bin:/bin" XDG_CACHE_HOME="$temp_home/.cache" bash -lc '
        set -euo pipefail
        source "'"$repo_root"'/files/.bashrc.d/02-functions"
        chpwd_functions=(_mise_hook)
        source "'"$repo_root"'/files/.bashrc.d/52-env-mise"
        if ! declare -F _mise_hook_chpwd >/dev/null; then
            echo "MISSING_MISE_HOOK_CHPWD=1"
        fi
        printf "hooks:%s\n" "${chpwd_functions[*]}"
    '
)"

if [[ "$output" == *"MISSING_MISE_HOOK_CHPWD=1"* ]]; then
    echo "$output" >&2
    fail "52-env-mise should initialize mise hook even when chpwd_functions contains stale _mise_hook"
fi

if [[ "$output" != *"_mise_hook_chpwd"* ]]; then
    echo "$output" >&2
    fail "52-env-mise should ensure chpwd_functions includes _mise_hook_chpwd"
fi

echo "PASS: mise chpwd hook cache regression check"
