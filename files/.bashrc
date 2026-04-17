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

DOTFILES_REPO="${DOTFILES_REPO:-$HOME/repo/dotfiles}"
DOTFILES_ENV_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/bashrc-env"
DOTFILES_ENV_CACHE_KEY=""
DOTFILES_ENV_CACHE_FILE=""
DOTFILES_ENV_CACHE_HIT=0
DOTFILES_SHELL_CACHE_FILE=""
DOTFILES_SHELL_CACHE_HIT=0

_dotfiles_env_cache_should_skip_var() {
    case "$1" in
        BASHPID | BASHOPTS | BASH_ARGC | BASH_ARGV | BASH_ARGV0 | BASH_COMMAND | BASH_LINENO | BASH_SOURCE | BASH_SUBSHELL | BASH_VERSINFO | BASH_VERSION | COLUMNS | DIRSTACK | EUID | FUNCNAME | GROUPS | LINES | LINENO | MACHTYPE | OSTYPE | PIPESTATUS | PPID | PWD | OLDPWD | RANDOM | SECONDS | SHELLOPTS | SHLVL | UID | _ | TERM | SSH_AUTH_SOCK | SSH_AGENT_PID | SSH_CLIENT | SSH_CONNECTION | SSH_TTY | TMUX | TMUX_PANE | WINDOWID | DISPLAY | XAUTHORITY)
            return 0
            ;;
    esac
    return 1
}

_dotfiles_env_cache_init() {
    [[ "${DOTFILES_DISABLE_ENV_CACHE:-0}" == "1" ]] && return 0
    local base_key dirty_diff dirty_hash dirty_mark=""
    base_key="$(git -C "$DOTFILES_REPO" rev-parse --verify HEAD 2>/dev/null || true)"
    [[ -n "$base_key" ]] || return 0
    dirty_diff="$(
        git -C "$DOTFILES_REPO" diff -- files/.bashrc files/.bashrc.d 2>/dev/null
        git -C "$DOTFILES_REPO" diff --cached -- files/.bashrc files/.bashrc.d 2>/dev/null
    )"
    if [[ -n "$dirty_diff" ]]; then
        dirty_hash="$(printf '%s' "$dirty_diff" | sha256sum | cut -c1-16)"
        dirty_mark="-${dirty_hash}"
    fi
    DOTFILES_ENV_CACHE_KEY="${base_key}${dirty_mark}"
    DOTFILES_ENV_CACHE_FILE="$DOTFILES_ENV_CACHE_DIR/env-${DOTFILES_ENV_CACHE_KEY}.sh"
    DOTFILES_SHELL_CACHE_FILE="$DOTFILES_ENV_CACHE_DIR/shell-${DOTFILES_ENV_CACHE_KEY}.sh"
}

_dotfiles_env_cache_load() {
    [[ "${DOTFILES_DISABLE_ENV_CACHE:-0}" == "1" ]] && return 0
    [[ -n "$DOTFILES_ENV_CACHE_FILE" ]] || return 0
    if [[ -r "$DOTFILES_ENV_CACHE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$DOTFILES_ENV_CACHE_FILE"
        DOTFILES_ENV_CACHE_HIT=1
    fi
}

_dotfiles_shell_cache_load() {
    [[ "${DOTFILES_DISABLE_ENV_CACHE:-0}" == "1" ]] && return 0
    [[ -n "$DOTFILES_SHELL_CACHE_FILE" ]] || return 0
    if [[ -r "$DOTFILES_SHELL_CACHE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$DOTFILES_SHELL_CACHE_FILE"
        DOTFILES_SHELL_CACHE_HIT=1
        # Guard against cached functions shadowing critical builtins.
        if [[ "$(type -t command 2>/dev/null)" == "function" ]]; then
            unset -f command
            DOTFILES_SHELL_CACHE_HIT=0
            rm -f "$DOTFILES_SHELL_CACHE_FILE" 2>/dev/null || true
        fi
    fi
}

_dotfiles_env_cache_save() {
    [[ "${DOTFILES_DISABLE_ENV_CACHE:-0}" == "1" ]] && return 0
    [[ -n "$DOTFILES_ENV_CACHE_FILE" ]] || return 0
    ((DOTFILES_ENV_CACHE_HIT == 1)) && return 0

    mkdir -p "$DOTFILES_ENV_CACHE_DIR" 2>/dev/null || return 0
    local tmp_file
    tmp_file="$(mktemp "$DOTFILES_ENV_CACHE_DIR/.env-${DOTFILES_ENV_CACHE_KEY}.XXXXXX" 2>/dev/null)" || return 0

    {
        printf '#!/bin/bash\n'
        printf '# dotfiles env cache\n'
        printf '# key=%s\n' "$DOTFILES_ENV_CACHE_KEY"
        while IFS= read -r var_name; do
            _dotfiles_env_cache_should_skip_var "$var_name" && continue
            printf 'export %s=%q\n' "$var_name" "${!var_name}"
        done < <(compgen -e | LC_ALL=C sort)
    } >"$tmp_file" 2>/dev/null || {
        rm -f "$tmp_file"
        return 0
    }

    mv "$tmp_file" "$DOTFILES_ENV_CACHE_FILE" 2>/dev/null || rm -f "$tmp_file"
}

_dotfiles_shell_cache_save() {
    [[ "${DOTFILES_DISABLE_ENV_CACHE:-0}" == "1" ]] && return 0
    [[ -n "$DOTFILES_SHELL_CACHE_FILE" ]] || return 0
    ((DOTFILES_SHELL_CACHE_HIT == 1)) && return 0

    mkdir -p "$DOTFILES_ENV_CACHE_DIR" 2>/dev/null || return 0
    local tmp_file
    local fn
    tmp_file="$(mktemp "$DOTFILES_ENV_CACHE_DIR/.shell-${DOTFILES_ENV_CACHE_KEY}.XXXXXX" 2>/dev/null)" || return 0

    {
        printf '#!/bin/bash\n'
        printf '# dotfiles shell state cache\n'
        printf '# key=%s\n' "$DOTFILES_ENV_CACHE_KEY"
        printf 'shopt -s extglob\n'
        printf 'shopt -s progcomp\n'
        printf '# aliases\n'
        alias -p
        printf '\n# functions\n'
        while IFS= read -r fn; do
            case "$fn" in
                _dotfiles_env_cache_* | _dotfiles_shell_cache_* | command)
                    continue
                    ;;
            esac
            # If an alias has the same name, declare -f prints `name ()` form,
            # which can trip alias expansion on replay (e.g., alias mv + mv()).
            if alias "$fn" >/dev/null 2>&1; then
                continue
            fi
            declare -f "$fn"
        done < <(declare -F | awk '{print $3}' | LC_ALL=C sort)
        printf '\n# bind mappings\n'
        printf "if [[ \$- == *i* ]]; then\n"
        printf "bind -f /dev/stdin <<'__DOTFILES_BIND__'\n"
        bind -p 2>/dev/null || true
        printf "__DOTFILES_BIND__\n"
        while IFS= read -r bind_line; do
            printf 'bind -x %q\n' "$bind_line"
        done < <(bind -x 2>/dev/null || true)
        printf "fi\n"
        printf '\n# completion definitions\n'
        complete -p 2>/dev/null || true
    } >"$tmp_file" 2>/dev/null || {
        rm -f "$tmp_file"
        return 0
    }

    mv "$tmp_file" "$DOTFILES_SHELL_CACHE_FILE" 2>/dev/null || rm -f "$tmp_file"
}

_dotfiles_env_cache_init
_dotfiles_env_cache_load
_dotfiles_shell_cache_load

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
export LESS='-i -z-4 -MFXR -x4'
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
eval "$(dircolors -b "$HOME/.config/everforest.dircolors")" || :
export COLORTERM=truecolor

#-------------------------------------------------------------
# History
#-------------------------------------------------------------
shopt -s cmdhist
export TIMEFORMAT=$'\nreal %3R\tuser %3U\tsys %3S\tpcpu %P\n'
export HOSTFILE=$HOME/.hosts # Put list of remote hosts in ~/.hosts ...

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
    mapfile -t bashrc_list < <(find ~/.bashrc.d/ -name '[^.]*' -type f -print0 | xargs -r -0 ls -1 | sort)
    # disable errexit
    local reset
    local quiet_source=0
    if ((DOTFILES_ENV_CACHE_HIT == 1)); then
        quiet_source=1
    fi
    reset=$(shopt -p -o errexit)
    shopt -u -o errexit
    # save stderr
    exec 8>&2 7>&1
    exec 2>&1
    for file in "${bashrc_list[@]}"; do
        if [ -f "$file" ]; then
            name=$(basename "$file")
            if ((quiet_source)); then
                # shellcheck source=/dev/null
                source "$file"
            else
                echo -e "${YELLOW}[Sourcing] ${name}${RESET}"
                # shellcheck source=/dev/null
                source "$file" > >(sed -E "s/(.*)/  ${CYAN}${name}: &${RESET}/") 2> >(sed -E "s/(.*)/  ${RED}${name}: &${RESET}/" >&2)
            fi
        fi
    done
    # restore stderr
    exec 2>&8 1>&7 8>&- 7>&-
    # restore errexit
    eval "$reset"
}

restore_uncached_runtime_state() {
    local file
    local -a runtime_files=(
        "$HOME/.bashrc.d/10-init-zsh-cd-hooks"
        "$HOME/.bashrc.d/13-cd-hist-plugin"
        "$HOME/.bashrc.d/15-cmd-timer"
        "$HOME/.bashrc.d/51-env-direnv"
        "$HOME/.bashrc.d/52-env-mise"
        "$HOME/.bashrc.d/80-theme-powewrline"
        "$HOME/.bashrc.d/91-post-source-bashrc"
        "$HOME/.bashrc.d/92-exit-corrector"
    )

    for file in "${runtime_files[@]}"; do
        if [[ -f "$file" ]]; then
            # shellcheck source=/dev/null
            source "$file"
        fi
    done
}

if ((DOTFILES_SHELL_CACHE_HIT == 0)); then
    include_scripts
else
    restore_uncached_runtime_state
fi

# Task Master aliases added on 2025/7/24
alias tm='task-master'
alias taskmaster='task-master'
# shellcheck source=/dev/null
source "$HOME/repo/sre/bashrc"
eval "$(direnv hook bash)"

# Added by `rbenv init` on 西元2025年08月20日 (週三) 10時26分09秒 CST
eval "$(~/.rbenv/bin/rbenv init - --no-rehash bash)"

# Manually force AI terminals to load the VSCode shell integration goop.
if [[ "$CURSOR_AGENT" = 1 ]]; then
    # shellcheck source=/dev/null
    source "$(cursor --locate-shell-integration-path bash)"
    set -gx PAGER "cat"
    set -gx GIT_PAGER "cat"
fi

complete -C ~/.local/bin/mc mc

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if [[ -f "$HOME/.local/bin/env" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.local/bin/env"
fi

_dotfiles_env_cache_save
_dotfiles_shell_cache_save
