#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

temp_home="$(mktemp -d)"
trap 'rm -rf "$temp_home"' EXIT

mkdir -p "$temp_home/.cache" "$temp_home/.config" "$temp_home/repo/sre" "$temp_home/fake-bin"
ln -s "$repo_root/files/.bashrc.d" "$temp_home/.bashrc.d"
cat >"$temp_home/repo/sre/bashrc" <<'EOF'
# test stub
EOF
cat >"$temp_home/.config/everforest.dircolors" <<'EOF'
TERM *color*
EOF

cat >"$temp_home/fake-bin/tput" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$temp_home/fake-bin/tput"

cat >"$temp_home/fake-bin/direnv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "hook" ]]; then
    echo 'export DIRENV_HOOK_TEST=1'
fi
EOF
chmod +x "$temp_home/fake-bin/direnv"

mkdir -p "$temp_home/.rbenv/bin"
cat >"$temp_home/.rbenv/bin/rbenv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "init" ]]; then
    echo 'export RBENV_HOOK_TEST=1'
fi
EOF
chmod +x "$temp_home/.rbenv/bin/rbenv"

hash_key="$(git -C "$repo_root" rev-parse --verify HEAD)"
if ! git -C "$repo_root" diff --quiet -- files/.bashrc files/.bashrc.d \
    || ! git -C "$repo_root" diff --cached --quiet -- files/.bashrc files/.bashrc.d; then
    hash_key="${hash_key}-dirty"
fi
cache_file="$temp_home/.cache/dotfiles/bashrc-env/env-${hash_key}.sh"

run_probe() {
    HOME="$temp_home" \
        XDG_CACHE_HOME="$temp_home/.cache" \
        DOTFILES_REPO="$repo_root" \
        PATH="$temp_home/fake-bin:/usr/bin:/bin" \
        setupdotfile=1 \
        bash -lc "source '$repo_root/files/.bashrc'; echo HIT=\${DOTFILES_ENV_CACHE_HIT}; [[ -f '$cache_file' ]] && echo CACHE_PRESENT=1 || echo CACHE_PRESENT=0"
}

first_run="$(run_probe)"
assert_contains "$first_run" "HIT=0" "first run should miss env cache"
assert_contains "$first_run" "CACHE_PRESENT=1" "first run should generate env cache file"

second_run="$(run_probe)"
assert_contains "$second_run" "HIT=1" "second run should hit env cache"
assert_contains "$second_run" "CACHE_PRESENT=1" "cache file should remain present"

if grep -q '^export TERM=' "$cache_file"; then
    fail "env cache should not persist TERM; terminal type must come from current session"
fi

echo "PASS: bashrc env cache regression check"
