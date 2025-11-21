#!/bin/bash
clean_up() {
    echo "Error: Script $(basename "${BASH_SOURCE[0]}") Line $1"
}
trap 'clean_up $LINENO' INT ERR
set -e

PATH=$PATH:/usr/local/bin

hash git || exit
hash vim || exit

cd "$(dirname "${BASH_SOURCE[0]}")"
if (which git-up); then
    git-up
else
    git fetch --all --prune
    git stash
    git pull --rebase
    git stash pop
fi

{ hash powerline-daemon 2>/dev/null && powerline-daemon -k; } || true

if [ -d "$HOME"/.vim/vundle ]; then
    mv -f "$HOME"/.vim/{vundle,Vundle.vim}
fi
vim -c 'PlugUpgrade | PlugUpdate | qa'
