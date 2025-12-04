#!/bin/bash
# vim: set wrap tabstop=4 shiftwidth=4 softtabstop=0 expandtab :
# vim: set textwidth=0 filetype=sh foldmethod=manual nospell :
# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* && ${setupdotfile:-} == "" ]]; then
    # Shell is non-interactive.  Be done now!
    return
fi

LANG=zh_TW.UTF-8
export LANGUAGE=$LANG
export LANG=$LANG
export LC_TIME=$LANG
export LC_ALL=$LANG
export LC_CTYPE=$LANG
export LC_COLLATE=$LANG
export LC_ALL=$LANG
unset LANG

_add_prompt_command() {
    local action="$1"
    shift
    local cmd="$1"
    shift
    # normalize sep to be semicolon
    IFS=$';\n'
    # shellcheck disable=SC2016
    mapfile -t arr <<<"$PROMPT_COMMAND"
    PROMPT_COMMAND="${arr[*]}"
    unset IFS
    # skip the command if it already exists
    if [[ ";$PROMPT_COMMAND;" =~ $cmd ]]; then
        return
    fi
    if [[ "$action" = "append" ]]; then
        PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}$cmd"
    else
        PROMPT_COMMAND="$cmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi
}

#-------------------------------------------------------------
# Show dotfile changes at login
#-------------------------------------------------------------
function stacktrace {
    local size=${#BASH_SOURCE[@]}
    i=0
    for (( ; i < size - 1; i++)); do ## -1 to exclude main()
        read -r line func file < <(caller $i)
        echo >&2 "[$i] $file +$line $func(): $(sed -n "${line}p" "$file")"
    done
}
#-------------------------------------------------------------
# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
#-------------------------------------------------------------
shopt -s checkwinsize

#-------------------------------------------------------------
# Set Default keybinding
#------------------------------------------------
if [[ -z "$INPUTRC" ]] && [[ ! -f "$HOME/.inputrc" ]]; then
    export INPUTRC=/etc/inputrc
fi

#-------------------------------------------------------------
# tailoring 'less'
#-------------------------------------------------------------
alias more='less'
export EDITOR=vim
export PAGER='less'
export LESS='-i -z-4 -MFXRS -x4'
export LESSCHARDEF="8bcccbcc18b95.."
export LESS_TERMCAP_mb='[1;31m' # begin blinking
export LESS_TERMCAP_md='[4;32m' # begin bold
export LESS_TERMCAP_me='[0m'    # end mode
export LESS_TERMCAP_so='[0;31m' # begin standout-mode - info box
export LESS_TERMCAP_se='[0m'    # end standout-mode
export LESS_TERMCAP_us='[0;33m' # begin underline
export LESS_TERMCAP_ue='[0m'    # end underline
export LSCOLORS=ExGxFxdxCxDxDxBxBxExEx

#-------------------------------------------------------------
# File & string-related functions:
#-------------------------------------------------------------

dswap() {
    # Swap 2 filenames around, if they exist
    #(from Uzi's bashrc).
    local TMPFILE=tmp.$$

    [ $# -ne 2 ] && echo "swap: 2 arguments needed" && return 1
    [ ! -e "$1" ] && echo "swap: $1 does not exist" && return 1
    [ ! -e "$2" ] && echo "swap: $2 does not exist" && return 1

    mv "$1" $TMPFILE
    mv "$2" "$1"
    mv $TMPFILE "$2"
}

extract() { # Handy Extract Program.
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xvjf "$1" ;;
            *.tar.gz) tar xvzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar x "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xvf "$1" ;;
            *.tbz2) tar xvjf "$1" ;;
            *.tgz) tar xvzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *) echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
    # auto complete ssh-multi.sh as same as ssh
    if [[ -f /usr/share/bash-completion/completions/ssh ]]; then
        . /usr/share/bash-completion/completions/ssh
    fi
    if command -v ssh-multi.sh >/dev/null; then
        shopt -u hostcomplete && complete -F _ssh ssh-multi.sh
    fi
    if [[ -f /usr/share/bash-completion/completions/ssh ]]; then
        . /usr/share/bash-completion/bash_completion
        if [[ $(type -t _ssh) == function ]]; then
            ssh_func=_ssh
        elif [[ $(type -t _comp_cmd_ssh) == function ]]; then
            ssh_func=_comp_cmd_ssh
        fi
        if [[ -n $ssh_func ]]; then
            echo "complete -F $ssh_func ssh-multi.sh"
            complete -F "$ssh_func" "ssh-multi.sh"
        fi
    fi
fi

#-------------------------------------------------------------
# Set colorful PS1 only on colorful terminals.
#-------------------------------------------------------------
eval "$(dircolors -b "$HOME/.config/gruvbox.dircolors")" || :

#-------------------------------------------------------------
# History
#-------------------------------------------------------------
shopt -s cmdhist
export TIMEFORMAT=$'\nreal %3R\tuser %3U\tsys %3S\tpcpu %P\n'
export HOSTFILE=$HOME/.hosts # Put list of remote hosts in ~/.hosts ...

#-------------------------------------------------------------
# mintty-colors-solarized (for windows::mintty)
#-------------------------------------------------------------
if type -P mintty &>/dev/null; then
    echo -ne '\e]10;#839496\a'   # Foreground   -> base0
    echo -ne '\e]11;#002B36\a'   # Background   -> base03
    echo -ne '\e]12;#93A1A1\a'   # Cursor       -> base1
    echo -ne '\e]4;0;#073642\a'  # black        -> Base02
    echo -ne '\e]4;8;#002B36\a'  # bold black   -> Base03
    echo -ne '\e]4;1;#DC322F\a'  # red          -> red
    echo -ne '\e]4;9;#CB4B16\a'  # bold red     -> orange
    echo -ne '\e]4;2;#859900\a'  # green        -> green
    echo -ne '\e]4;10;#586E75\a' # bold green   -> base01 *
    echo -ne '\e]4;3;#B58900\a'  # yellow       -> yellow
    echo -ne '\e]4;11;#657B83\a' # bold yellow  -> base00 *
    echo -ne '\e]4;4;#268BD2\a'  # blue         -> blue
    echo -ne '\e]4;12;#839496\a' # bold blue    -> base0 *
    echo -ne '\e]4;5;#D33682\a'  # magenta      -> magenta
    echo -ne '\e]4;13;#6C71C4\a' # bold magenta -> violet
    echo -ne '\e]4;6;#2AA198\a'  # cyan         -> cyan
    echo -ne '\e]4;14;#93A1A1\a' # bold cyan    -> base1 *
    echo -ne '\e]4;7;#EEE8D5\a'  # white        -> Base2
    echo -ne '\e]4;15;#FDFDE3\a' # bold white   -> Base3
fi

#-------------------------------------------------------------
# tmux
#-------------------------------------------------------------
if [ -z "$TMUX" ]; then
    [ -f /var/run/motd ] && cat /var/run/motd
else
    export DISPLAY
    DISPLAY="$(tmux show-env | sed -n 's/^DISPLAY=//p')"
fi

#-------------------------------------------------------------
# thefuck
#-------------------------------------------------------------
if hash thefuck 2>/dev/null; then
    eval "$(thefuck --alias)"
fi

#-------------------------------------------------------------
# kitty intergration
#-------------------------------------------------------------
get() {
    echo -ne "\033];__pw:${PWD}\007"
    for file in "$@"; do echo -ne "\033];__rv:${file}\007"; done
    echo -ne "\033];__ti\007"
}
winscp() { echo -ne "\033];__ws:${PWD}\007"; }

#-------------------------------------------------------------
# Report command takes long time
#-------------------------------------------------------------

set_screen_title() {
    echo -ne "\ek$1\e\\"
}

# ensure X forwarding is setup correctly, even for screen
XAUTH=~/.Xauthority
if [[ ! -e "${XAUTH}" ]]; then
    # create new ~/.Xauthority file
    xauth q
fi
if [[ -z "${XAUTHORITY}" ]]; then
    # export env var if not already available.
    export XAUTHORITY="${XAUTH}"
fi

export DOCKER_BUILDKIT=1

if [ -f ~/bin/vault ]; then
    complete -C ~/bin/vault vault
fi
if [ -f /usr/local/bin/mc ]; then
    complete -C /usr/local/bin/mc mc
fi
if [ -f ~/.bin/mc ]; then
    complete -C ~/.bin/mc mc
fi

if [ -n "$TMUX" ]; then

    # render /etc/issue or else fall back to kernel/system info
    agetty --show-issue 2>/dev/null || uname -a

    # message of the day
    for motd in /run/motd.dynamic /etc/motd; do
        if [ -s "$motd" ]; then
            cat "$motd"
            break
        fi
    done

    # last login
    last "$USER" | awk 'NR==2 {
    if (NF==10) { i=1; if ($3!~/^:/) from = " from " $3 }
    printf("Last login: %s %s %s %s%s on %s\n",
      $(3+i), $(4+i), $(5+i), $(6+i), from, $2);
    exit
  }'

    # mail check
    if [ -s "/var/mail/$USER" ]; then # may need to change to /var/spool/mail/$USER
        echo "You have $(grep -c '^From ' "/var/mail/$USER") mails."
    else
        echo "You have no mail."
    fi
fi

#-------------------------------------------------------------
# import scripts
#-------------------------------------------------------------
include_scripts() {
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    RED=$(tput setaf 1)
    RESET=$(tput sgr0)
    find "$HOME"/.bashrc.d/ -name '*~' -delete
    # /etc/bashrc need to run after bashrc.d
    local bashrc_list
    mapfile -t bashrc_list < <(find ~/.bashrc.d/ -name '[^.]*' -type f -print0 | xargs -0 ls -1 | sort)
    # disable errexit
    local reset
    reset=$(shopt -p -o errexit)
    shopt -u -o errexit
    # save stderr
    exec 8>&2 7>&1
    exec 2>&1
    for file in "${bashrc_list[@]}"; do
        if [ -f "$file" ]; then
            name=$(basename "$file")
            echo -e "${YELLOW}[Sourcing] ${name}${RESET}"
            # shellcheck source=/dev/null
            source "$file" > >(sed -E "s/(.*)/  ${CYAN}${name}: &${RESET}/") 2> >(sed -E "s/(.*)/  ${RED}${name}: &${RESET}/" >&2)
        fi
    done
    # restore stderr
    exec 2>&8 1>&7 8>&- 7>&-
    # restore errexit
    eval "$reset"
}

include_scripts

# Task Master aliases added on 2025/7/24
alias tm='task-master'
alias taskmaster='task-master'

complete -C ~/.local/bin/mc mc
