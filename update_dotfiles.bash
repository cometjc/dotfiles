#!/bin/bash -e
set -x
current="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$current"
PATH=$PATH:/usr/local/bin

# Clean old files
[ -d local ] && echo The local folder for powerline is not needed anymore, remove? && \rm -ri local

# Update python pkgs
{ hash powerline-daemon && powerline-daemon -k; } || true
# shellcheck source=/dev/null
source ~/venv/bin/activate
pip install -U -r requirements_dotfiles.txt

# Update vim plugins
if [ -e vim/bundle/vundle ]; then
    pushd vim/bundle/vundle/
    git pull
    popd
    vim +PlugUpdate +qall
fi
find "$HOME/.vim/" -name \*.vim -exec dos2unix -q {} \;

# Update git-completion.bash
wget -N https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.256dark
pushd files/.bashrc.d/
wget -N https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh
wget -N https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
wget -N https://raw.githubusercontent.com/bobthecow/git-flow-completion/master/git-flow-completion.bash
popd
