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
shell_cache_file="$temp_home/.cache/dotfiles/bashrc-env/shell-${hash_key}.sh"

run_probe() {
    HOME="$temp_home" \
        XDG_CACHE_HOME="$temp_home/.cache" \
        DOTFILES_REPO="$repo_root" \
        PATH="$temp_home/fake-bin:/usr/bin:/bin" \
        setupdotfile=1 \
        bash -lc "source '$repo_root/files/.bashrc'; has_chpwd_append=0; for hook_name in \"\${chpwd_functions[@]-}\"; do if [[ \"\$hook_name\" == append_cdhist ]]; then has_chpwd_append=1; break; fi; done; echo SHIT=\${DOTFILES_SHELL_CACHE_HIT}; alias mv >/dev/null && echo HAS_ALIAS=1 || echo HAS_ALIAS=0; complete -p git >/dev/null 2>&1 && echo HAS_GIT_COMPLETION=1 || echo HAS_GIT_COMPLETION=0; echo HAS_CHPWD_APPEND=\$has_chpwd_append; [[ -f '$shell_cache_file' ]] && echo SHELL_CACHE_PRESENT=1 || echo SHELL_CACHE_PRESENT=0"
}

first_run="$(run_probe)"
assert_contains "$first_run" "SHIT=0" "first run should miss shell cache"
assert_contains "$first_run" "HAS_ALIAS=1" "first run should define aliases"
assert_contains "$first_run" "SHELL_CACHE_PRESENT=1" "first run should generate shell cache file"

second_run="$(run_probe)"
assert_contains "$second_run" "SHIT=1" "second run should hit shell cache"
assert_contains "$second_run" "HAS_ALIAS=1" "second run should restore aliases from shell cache"
assert_contains "$second_run" "HAS_GIT_COMPLETION=1" "second run should restore completion definitions"
assert_contains "$second_run" "HAS_CHPWD_APPEND=1" "second run should preserve chpwd hook registration"
assert_contains "$second_run" "SHELL_CACHE_PRESENT=1" "shell cache file should remain present"

echo "PASS: bashrc shell cache regression check"
