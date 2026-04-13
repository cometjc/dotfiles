#!/bin/bash
clean_up() {
    echo "Error: Script $(basename "${BASH_SOURCE[0]}") Line $1"
}
trap 'clean_up $LINENO' INT ERR
set -e

PATH=$PATH:/usr/local/bin

hash git || exit
hash vim || exit

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Pull latest dotfiles
if command -v git-up >/dev/null 2>&1; then
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

# Regenerate tmux defaults snapshot when the tmux binary is newer than the
# cached file (i.e., after a tmux upgrade).
DEFAULTS_FILE="$DOTFILES_DIR/files/.tmux-defaults.conf"
if hash tmux 2>/dev/null; then
    TMUX_BIN=$(command -v tmux)
    if [ ! -f "$DEFAULTS_FILE" ] || [ "$TMUX_BIN" -nt "$DEFAULTS_FILE" ]; then
        echo "tmux binary newer than defaults snapshot — regenerating…"
        bash "$DOTFILES_DIR/scripts/tmux-gen-defaults.sh"
        cd "$DOTFILES_DIR"
        if [ -n "$(git status --porcelain files/.tmux-defaults.conf)" ]; then
            git add files/.tmux-defaults.conf
            git commit -m "chore(tmux): update defaults snapshot for tmux $(tmux -V | cut -d' ' -f2)"
        fi
    fi
fi

# Clean up stale entries from cd history database
if [[ -f "$HOME/.cd_history.db" ]] && command -v sqlite3 >/dev/null 2>&1; then
    # shellcheck source=files/.bashrc.d/13-cd-hist-plugin
    source "$DOTFILES_DIR/files/.bashrc.d/13-cd-hist-plugin"
    cleanup_cdhist
fi
