#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

temp_home="$(mktemp -d)"
temp_repo="$(mktemp -d)"
trap 'rm -rf "$temp_home" "$temp_repo"' EXIT

mkdir -p "$temp_home/.cache" "$temp_repo"
cat >"$temp_repo/.env" <<'ENVEOF'
API_KEY=from-env
ENVEOF
cat >"$temp_repo/.env-store" <<'ENVSEO'
API_KEY=from-store
ENVSEO

run_output="$({
    cd "$temp_repo"
    HOME="$temp_home" XDG_CACHE_HOME="$temp_home/.cache" bash -lc '
        source_env_if_exists() { :; }
        dotenv() { :; }
        PATH_add() { :; }
        log_status() { :; }
        log_error() { :; }
        direnv_load() { return 0; }
        layout() { :; }

        unset ENVRC
        source "'"$repo_root"'/.envrc"
        declare -F clean_filter_func >/dev/null || {
            echo "MISSING_CLEAN_FILTER=1"
            exit 1
        }
        printf "API_KEY=\n" | clean_filter_func >/dev/null

        if compgen -G ".env-store.tmp.*" >/dev/null 2>&1; then
            echo "PWD_TMP_PRESENT=1"
        else
            echo "PWD_TMP_PRESENT=0"
        fi

        stat -c "ENV_STORE_MODE=%a" .env-store
    '
} 2>&1)"

if [[ "$run_output" != *"PWD_TMP_PRESENT=0"* ]]; then
    echo "$run_output" >&2
    fail "clean_filter_func should not leave temp files in PWD"
fi

if [[ "$run_output" != *"ENV_STORE_MODE=600"* ]]; then
    echo "$run_output" >&2
    fail "clean_filter_func should keep .env-store permission at 0600"
fi

echo "PASS: envrc clean filter cache path regression check"
