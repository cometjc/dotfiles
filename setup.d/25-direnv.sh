#!/bin/bash
# vim: set et fenc=utf-8 ff=unix sts=4 sw=4 ts=8 :
common_lib="$(dirname "$(readlink -f "$0")")/common-lib"
if [[ -f "$common_lib" ]]; then
    # shellcheck source=common-lib
    . "$common_lib"
else
    echo "[FAIL] Cannot find common-lib."
    exit 1
fi

# Early Skip Flows
if command -v direnv >/dev/null 2>&1; then
    pass "direnv is already installed"
    exit 0
fi

# Ensure platform is set (from common-lib)
: "${platform:?platform variable must be set by common-lib}"

PATH_append "$HOME/.local/bin"
curl -sfL https://direnv.net/install.sh | bin_path=$HOME/.local/bin bash
