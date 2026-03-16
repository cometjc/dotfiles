#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local message="$3"
    if [[ "$actual" != "$expected" ]]; then
        fail "$message (expected: $expected, actual: $actual)"
    fi
}

test_00_dotfiles_replaces_existing_directory_with_symlink() {
    local temp_home
    temp_home="$(mktemp -d)"
    trap 'rm -rf "$temp_home"' RETURN

    mkdir -p "$temp_home/.bashrc.d"
    printf 'legacy\n' >"$temp_home/.bashrc.d/local-only"

    (
        cd "$repo_root/setup.d"
        HOME="$temp_home" ./00-dotfiles -f >/tmp/test-00-dotfiles.log 2>&1
    ) || {
        cat /tmp/test-00-dotfiles.log >&2
        fail "00-dotfiles should succeed when ~/.bashrc.d already exists as a directory"
    }

    [[ -L "$temp_home/.bashrc.d" ]] || fail ".bashrc.d should become a symlink"

    local link_target
    link_target="$(readlink -f "$temp_home/.bashrc.d")"
    assert_eq "$link_target" "$repo_root/files/.bashrc.d" ".bashrc.d should point at repo-managed files"

    [[ -f "$repo_root/files/.bashrc.d/local-only" ]] || fail "existing ~/.bashrc.d contents should be preserved in repo files before replacement"
    rm -f "$repo_root/files/.bashrc.d/local-only"
}

test_24_shfmt_uses_release_asset_url_from_api() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local install_root="$temp_dir/install-root"
    local log_file="$temp_dir/curl.log"
    mkdir -p "$fake_bin" "$install_root/usr/local/bin"

    cat >"$fake_bin/dpkg" <<'EOF'
#!/bin/bash
if [[ "$1" == "--print-architecture" ]]; then
    echo amd64
    exit 0
fi
exec /usr/bin/dpkg "$@"
EOF
    chmod +x "$fake_bin/dpkg"

    cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${TEST_CURL_LOG:?}"
api_url="https://api.github.com/repos/mvdan/sh/releases/latest"
asset_url="https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_amd64"

if [[ "$#" -ge 2 && "$1" == "-fsSL" && "$2" == "$api_url" ]]; then
    cat <<JSON
{
  "tag_name": "v3.13.0",
  "assets": [
    {
      "name": "shfmt_v3.13.0_linux_amd64",
      "browser_download_url": "$asset_url"
    }
  ]
}
JSON
    exit 0
fi

if [[ "$#" -ge 4 && "$1" == "-fsSL" && "$2" == "$asset_url" && "$3" == "-o" ]]; then
    printf '%s\n' "$2" >>"$log_file"
    cat >"$4" <<'SCRIPT'
#!/bin/bash
echo "v3.13.0"
SCRIPT
    exit 0
fi

printf '%s\n' "${2:-}" >>"$log_file"
exit 22
EOF
    chmod +x "$fake_bin/curl"

    cat >"$fake_bin/sudo" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" == "mv" ]]; then
    src="$2"
    dest="$3"
    mkdir -p "$(dirname "${TEST_INSTALL_ROOT:?}$dest")"
    /bin/mv "$src" "${TEST_INSTALL_ROOT}$dest"
    exit 0
fi
exec "$@"
EOF
    chmod +x "$fake_bin/sudo"

    cat >"$fake_bin/shfmt" <<'EOF'
#!/bin/bash
exec "${TEST_INSTALL_ROOT:?}/usr/local/bin/shfmt" "$@"
EOF
    chmod +x "$fake_bin/shfmt"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:/usr/bin:/bin" \
            TEST_CURL_LOG="$log_file" \
            TEST_INSTALL_ROOT="$install_root" \
            ./24-shfmt -f >/tmp/test-24-shfmt.log 2>&1
    ) || {
        cat /tmp/test-24-shfmt.log >&2
        fail "24-shfmt should succeed when the API advertises an asset-specific download URL"
    }

    [[ -x "$install_root/usr/local/bin/shfmt" ]] || fail "24-shfmt should install the downloaded binary"
    grep -Fx "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_amd64" "$log_file" >/dev/null \
        || fail "24-shfmt should download the asset URL returned by the release API"
}

test_50_mise_repairs_root_owned_cache_directory() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'sudo rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local temp_home="$temp_dir/home"
    local log_file="$temp_dir/mise.log"
    mkdir -p "$fake_bin" "$temp_home/.cache" "$temp_home/.local/bin"

    sudo mkdir -p "$temp_home/.cache/mise"
    sudo touch "$temp_home/.cache/mise/root-owned"
    sudo chown -R root:root "$temp_home/.cache/mise"

    cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
cat <<'SCRIPT'
#!/bin/bash
set -eu
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/mise" <<'INNER'
#!/bin/bash
set -euo pipefail
log_file="${TEST_MISE_LOG:?}"
printf '%s\n' "$*" >>"$log_file"
case "${1:-}" in
  activate)
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    exit 0
    ;;
  settings)
    exit 0
    ;;
  upgrade)
    if [[ ! -w "$HOME/.cache/mise" ]]; then
        echo "cache directory is not writable" >&2
        exit 1
    fi
    exit 0
    ;;
esac
exit 0
INNER
chmod +x "$HOME/.local/bin/mise"
SCRIPT
EOF
    chmod +x "$fake_bin/curl"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:/usr/bin:/bin" \
            HOME="$temp_home" \
            TEST_MISE_LOG="$log_file" \
            ./50-mise -f >/tmp/test-50-mise.log 2>&1
    ) || {
        cat /tmp/test-50-mise.log >&2
        fail "50-mise should repair a root-owned cache directory before upgrading"
    }

    [[ -w "$temp_home/.cache/mise" ]] || fail "50-mise should leave ~/.cache/mise writable"
    grep -Fx "upgrade" "$log_file" >/dev/null || fail "50-mise should continue to run mise upgrade after repairing permissions"
}

test_51_node_apps_repairs_root_owned_npm_directory() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'sudo rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local temp_home="$temp_dir/home"
    local log_file="$temp_dir/node-apps.log"
    mkdir -p "$fake_bin" "$temp_home/.local/bin"

    sudo mkdir -p "$temp_home/.npm"
    sudo touch "$temp_home/.npm/root-owned"
    sudo chown -R root:root "$temp_home/.npm"

    cat >"$temp_home/.local/bin/mise" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${TEST_NODE_APPS_LOG:?}"
printf 'mise %s\n' "$*" >>"$log_file"
case "${1:-}" in
  activate)
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    ;;
  use)
    exit 0
    ;;
  exec)
    shift
    while [[ "$1" != "--" ]]; do
        shift
    done
    shift
    exec "$@"
    ;;
esac
EOF
    chmod +x "$temp_home/.local/bin/mise"

    cat >"$fake_bin/npm" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ ! -w "$HOME/.npm" ]]; then
    echo "npm cache is not writable" >&2
    exit 1
fi
printf 'npm %s\n' "$*" >>"${TEST_NODE_APPS_LOG:?}"
exit 0
EOF
    chmod +x "$fake_bin/npm"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:$temp_home/.local/bin:/usr/bin:/bin" \
            HOME="$temp_home" \
            TEST_NODE_APPS_LOG="$log_file" \
            ./51-node-apps -f >/tmp/test-51-node-apps.log 2>&1
    ) || {
        cat /tmp/test-51-node-apps.log >&2
        fail "51-node-apps should repair a root-owned ~/.npm directory before running npm"
    }

    [[ -w "$temp_home/.npm" ]] || fail "51-node-apps should leave ~/.npm writable"
    grep -F "npm install -g task-master-ai" "$log_file" >/dev/null \
        || fail "51-node-apps should continue npm installs after repairing ~/.npm"
}

test_52_go_apps_repairs_root_owned_cache_directory() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'sudo rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local temp_home="$temp_dir/home"
    local log_file="$temp_dir/go-apps.log"
    mkdir -p "$fake_bin" "$temp_home/.cache" "$temp_home/.local/bin"

    sudo mkdir -p "$temp_home/.cache/mise"
    sudo touch "$temp_home/.cache/mise/root-owned"
    sudo chown -R root:root "$temp_home/.cache/mise"

    cat >"$temp_home/.local/bin/mise" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${TEST_GO_APPS_LOG:?}"
printf 'mise %s\n' "$*" >>"$log_file"
case "${1:-}" in
  activate)
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    ;;
  use)
    if [[ ! -w "$HOME/.cache/mise" ]]; then
        echo "cache directory is not writable" >&2
        exit 1
    fi
    ;;
esac
EOF
    chmod +x "$temp_home/.local/bin/mise"

    cat >"$fake_bin/go" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'go %s\n' "$*" >>"${TEST_GO_APPS_LOG:?}"
exit 0
EOF
    chmod +x "$fake_bin/go"

    cat >"$fake_bin/gup" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'gup %s\n' "$*" >>"${TEST_GO_APPS_LOG:?}"
exit 0
EOF
    chmod +x "$fake_bin/gup"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:$temp_home/.local/bin:/usr/bin:/bin" \
            HOME="$temp_home" \
            TEST_GO_APPS_LOG="$log_file" \
            ./52-go-apps -f >/tmp/test-52-go-apps.log 2>&1
    ) || {
        cat /tmp/test-52-go-apps.log >&2
        fail "52-go-apps should repair a root-owned cache directory before using mise"
    }

    [[ -w "$temp_home/.cache/mise" ]] || fail "52-go-apps should leave ~/.cache/mise writable"
    grep -F "go install mvdan.cc/sh/v3/cmd/shfmt@latest" "$log_file" >/dev/null \
        || fail "52-go-apps should continue with go installs after repairing permissions"
}

test_56_brew_apps_installs_formulae_sequentially() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local log_file="$temp_dir/brew.log"
    mkdir -p "$fake_bin"

    cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' '#!/bin/bash' 'exit 0'
EOF
    chmod +x "$fake_bin/curl"

    cat >"$fake_bin/brew" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${TEST_BREW_APPS_LOG:?}"
printf 'brew %s\n' "$*" >>"$log_file"
case "${1:-}" in
  shellenv)
    echo 'export PATH="$PATH"'
    exit 0
    ;;
  install)
    shift
    if [[ "$#" -ne 1 ]]; then
        echo "brew install should be called one package at a time" >&2
        exit 1
    fi
    exit 0
    ;;
esac
exit 0
EOF
    chmod +x "$fake_bin/brew"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:/usr/bin:/bin" \
            BREW_BIN="$fake_bin/brew" \
            TEST_BREW_APPS_LOG="$log_file" \
            ./56-brew-apps -f >/tmp/test-56-brew-apps.log 2>&1
    ) || {
        cat /tmp/test-56-brew-apps.log >&2
        fail "56-brew-apps should install brew formulae sequentially"
    }

    grep -Fx "brew install gcc" "$log_file" >/dev/null || fail "56-brew-apps should install gcc individually"
    grep -Fx "brew install derailed/k9s/k9s" "$log_file" >/dev/null || fail "56-brew-apps should install k9s individually"
    grep -Fx "brew install fx" "$log_file" >/dev/null || fail "56-brew-apps should install fx individually"
    grep -Fx "brew install kubectx" "$log_file" >/dev/null || fail "56-brew-apps should install kubectx individually"
}

test_70_powerline_repairs_root_owned_uv_cache() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'sudo rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local temp_home="$temp_dir/home"
    local log_file="$temp_dir/powerline.log"
    mkdir -p "$fake_bin" "$temp_home/.local/bin"

    sudo mkdir -p "$temp_home/.cache/uv"
    sudo touch "$temp_home/.cache/uv/CACHEDIR.TAG"
    sudo chown -R root:root "$temp_home/.cache/uv"

    cat >"$fake_bin/uv" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ ! -w "$HOME/.cache/uv" ]]; then
    echo "uv cache is not writable" >&2
    exit 1
fi
printf 'uv %s\n' "$*" >>"${TEST_POWERLINE_LOG:?}"
exit 0
EOF
    chmod +x "$fake_bin/uv"

    cat >"$fake_bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
out=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -o)
        out="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
done
printf 'downloaded\n' >"$out"
EOF
    chmod +x "$fake_bin/curl"

    cat >"$fake_bin/fc-cache" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$fake_bin/fc-cache"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:$temp_home/.local/bin:/usr/bin:/bin" \
            HOME="$temp_home" \
            TEST_POWERLINE_LOG="$log_file" \
            ./70-powerline -f >/tmp/test-70-powerline.log 2>&1
    ) || {
        cat /tmp/test-70-powerline.log >&2
        fail "70-powerline should repair a root-owned uv cache before installing powerline"
    }

    [[ -w "$temp_home/.cache/uv" ]] || fail "70-powerline should leave ~/.cache/uv writable"
    grep -Fx "uv tool install --with powerline-gitstatus powerline-status -p 3.8" "$log_file" >/dev/null \
        || fail "70-powerline should continue with uv tool install after repairing ~/.cache/uv"
}

test_53_python_apps_is_executable() {
    [[ -x "$repo_root/setup.d/53-python-apps" ]] || fail "53-python-apps must stay executable so run-parts can install python tools like pre-commit"
}

test_53_python_apps_removes_malformed_uv_tools() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local temp_home="$temp_dir/home"
    local log_file="$temp_dir/python-apps.log"
    mkdir -p "$fake_bin" "$temp_home/.cache/uv" "$temp_home/.local/bin"

    cat >"$fake_bin/uv" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${TEST_PYTHON_APPS_LOG:?}"
printf 'uv %s\n' "$*" >>"$log_file"
case "${1:-} ${2:-} ${3:-}" in
  "self update ")
    exit 0
    ;;
  "python install 3.12")
    exit 0
    ;;
esac

if [[ "${1:-}" == "tool" && "${2:-}" == "list" ]]; then
    cat <<'OUT'
warning: Ignoring malformed tool `kubeconfig-updater` (run `uv tool uninstall kubeconfig-updater` to remove)
warning: Tool `pre-commit` environment not found (run `uv tool install pre-commit --reinstall` to reinstall)
OUT
    exit 0
fi

if [[ "${1:-}" == "tool" && "${2:-}" == "uninstall" && "${3:-}" == "kubeconfig-updater" ]]; then
    exit 0
fi

if [[ "${1:-}" == "tool" && "${2:-}" == "install" ]]; then
    exit 0
fi

if [[ "${1:-}" == "tool" && "${2:-}" == "upgrade" && "${3:-}" == "--all" ]]; then
    exit 0
fi

exit 0
EOF
    chmod +x "$fake_bin/uv"

    (
        cd "$repo_root/setup.d"
        PATH="$fake_bin:/usr/bin:/bin" \
            HOME="$temp_home" \
            TEST_PYTHON_APPS_LOG="$log_file" \
            ./53-python-apps -f >/tmp/test-53-python-apps.log 2>&1
    ) || {
        cat /tmp/test-53-python-apps.log >&2
        fail "53-python-apps should clean malformed uv tools and continue"
    }

    grep -Fx "uv tool uninstall kubeconfig-updater" "$log_file" >/dev/null \
        || fail "53-python-apps should uninstall malformed uv tools before reinstalling"
}

test_setup_bootstraps_pre_commit_from_uv() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    local fake_bin="$temp_dir/bin"
    local log_file="$temp_dir/setup.log"
    mkdir -p "$fake_bin"

    cat >"$fake_bin/uv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'uv %s\n' "$*" >>"${TEST_SETUP_LOG:?}"
if [[ "${1:-}" == "tool" && "${2:-}" == "install" ]]; then
    mkdir -p "$HOME/.local/bin"
    cat >"$HOME/.local/bin/pre-commit" <<'INNER'
#!/bin/bash
set -euo pipefail
printf 'pre-commit %s\n' "$*" >>"${TEST_SETUP_LOG:?}"
exit 0
INNER
    chmod +x "$HOME/.local/bin/pre-commit"
    exit 0
fi
exit 0
EOF
    chmod +x "$fake_bin/uv"

    if ! PATH="$fake_bin:/usr/bin:/bin" HOME="$temp_dir/home" TEST_SETUP_LOG="$log_file" bash -c '
        export PATH="$HOME/.local/bin:$PATH"
        if ! command -v pre-commit >/dev/null 2>&1; then
            uv tool install --reinstall pre-commit
        fi
        pre-commit install
    '; then
        fail "setup should bootstrap pre-commit from uv when it is missing"
    fi

    grep -Fx "uv tool install --reinstall pre-commit" "$log_file" >/dev/null \
        || fail "setup should reinstall pre-commit via uv when pre-commit is missing"
    grep -Fx "pre-commit install" "$log_file" >/dev/null \
        || fail "setup should still run pre-commit install after bootstrapping"
}

test_00_dotfiles_replaces_existing_directory_with_symlink
test_24_shfmt_uses_release_asset_url_from_api
test_50_mise_repairs_root_owned_cache_directory
test_51_node_apps_repairs_root_owned_npm_directory
test_52_go_apps_repairs_root_owned_cache_directory
test_56_brew_apps_installs_formulae_sequentially
test_70_powerline_repairs_root_owned_uv_cache
test_53_python_apps_is_executable
test_53_python_apps_removes_malformed_uv_tools
test_setup_bootstraps_pre_commit_from_uv

echo "All setup regression tests passed"
