#!/bin/bash

_envrc_d_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export RIPGREP_CONFIG_PATH="${_envrc_d_dir%/.envrc.d}/.ripgreprc"
unset _envrc_d_dir
