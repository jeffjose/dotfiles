#!/bin/bash
# ~/.bashrc - Bash configuration ported from tcsh
# Managed by dotfiles

# ============================================================================
# ENVIRONMENT & PATH (always run, even for non-interactive shells)
# ============================================================================

export EDITOR=nvim
export TERM=xterm-256color

export LS_COLORS='no=00:fi=00:di=01;97:ow=01;97:st=01;97:tw=01;97:ln=01;36:pi=40;33:so=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=00;00;00;41:ex=01;32:*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:*.sh=01;32:*.csh=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.bz=01;31:*.tz=01;31:*.rpm=01;31:*.cpio=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:*.png=01;35:*.tif=01;35:*.r=01;35:*.map=01;35:*.adb=01;98:*.pdf=01;35'

# PATH SETUP (matching tcsh order exactly)
if [[ -z "$__MY_PATHS_ARE_SET" ]]; then
    export GRADLEPATH=/opt/gradle
    export GOPATH=$HOME/go
    export BUNPATH=$HOME/.bun
    export DARTPATH=/usr/lib/dart
    export GOOGLEDARTPATH=/usr/lib/google-dartlang
    export CARGOPATH=$HOME/.cargo
    export PYENVPATH=$HOME/.pyenv
    export MISEPATH=$HOME/.local/share/mise/shims
    export PNPM_HOME=$HOME/.pnpm
    export ANDROID_HOME=$HOME/Android/Sdk
    export ANDROID_NDK_HOME=$HOME/Android/Ndk
    export ANDROID_SDK_ROOT=$HOME/Android/Sdk
    export ANDROID_VER=30.0.2
    export BREWPATH=/home/linuxbrew/.linuxbrew
    export LMSTUDIOPATH=$HOME/.lmstudio

    new_path=""
    [[ -d "$GRADLEPATH/bin" ]] && new_path="$new_path:$GRADLEPATH/bin"
    [[ -d "$MISEPATH" ]] && new_path="$new_path:$MISEPATH"
    [[ -d "$CARGOPATH/bin" ]] && new_path="$new_path:$CARGOPATH/bin"
    [[ -d "$PYENVPATH/bin" ]] && new_path="$new_path:$PYENVPATH/bin"
    [[ -d "$BREWPATH/bin" ]] && new_path="$new_path:$BREWPATH/bin"
    [[ -d "$GOPATH/bin" ]] && new_path="$new_path:$GOPATH/bin"
    [[ -d "$PNPM_HOME" ]] && new_path="$new_path:$PNPM_HOME"
    [[ -d "$BUNPATH/bin" ]] && new_path="$new_path:$BUNPATH/bin"
    [[ -d "$DARTPATH/bin" ]] && new_path="$new_path:$DARTPATH/bin"
    [[ -d "$GOOGLEDARTPATH/bin" ]] && new_path="$new_path:$GOOGLEDARTPATH/bin"
    [[ -d "$ANDROID_HOME/emulator" ]] && new_path="$new_path:$ANDROID_HOME/emulator"
    [[ -d "$ANDROID_HOME/tools/bin" ]] && new_path="$new_path:$ANDROID_HOME/tools/bin"
    [[ -d "$ANDROID_HOME/platform-tools" ]] && new_path="$new_path:$ANDROID_HOME/platform-tools"
    [[ -d "$ANDROID_HOME/build-tools/$ANDROID_VER" ]] && new_path="$new_path:$ANDROID_HOME/build-tools/$ANDROID_VER"
    [[ -d "$HOME/.pub-cache/bin" ]] && new_path="$new_path:$HOME/.pub-cache/bin"
    [[ -d "$HOME/bin" ]] && new_path="$new_path:$HOME/bin"
    [[ -d "$HOME/.local/bin" ]] && new_path="$new_path:$HOME/.local/bin"
    [[ -d "$LMSTUDIOPATH/bin" ]] && new_path="$new_path:$LMSTUDIOPATH/bin"
    [[ -d "/usr/sbin" ]] && new_path="$new_path:/usr/sbin"

    new_path="${new_path#:}"
    export PATH="$new_path:$PATH"
    unset new_path
    export __MY_PATHS_ARE_SET=1
fi

# PyPI
export PIP_INDEX_URL=https://pypi.org/simple/
export UV_INDEX_URL=https://pypi.org/simple/
export PIPENV_PYTHON=$HOME/.pyenv/shims/python

# Cargo
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# ============================================================================
# EXIT HERE FOR NON-INTERACTIVE SHELLS
# ============================================================================
[[ $- != *i* ]] && return

# ============================================================================
# HISTORY CONFIGURATION (interactive only)
# ============================================================================

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=10000

shopt -s histappend

# Save history after each command
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a"

# ============================================================================
# HISTORY SEARCH (interactive only)
# ============================================================================

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOA": history-search-backward'
bind '"\eOB": history-search-forward'

# Show all completions on first Tab
bind 'set show-all-if-ambiguous on'

# Space expands history
bind 'Space: magic-space'

# Show expanded command before executing
shopt -s histverify

# ============================================================================
# SHELL BEHAVIOR (interactive only)
# ============================================================================

set -o ignoreeof                    # Prevent Ctrl-D exit
shopt -s extglob                    # Extended globbing
shopt -s nocaseglob                 # Case-insensitive globbing
shopt -s cdspell                    # Autocorrect cd typos
shopt -s checkwinsize               # Update LINES/COLUMNS after each command
shopt -s globstar 2>/dev/null       # ** matches recursively

bind '"\C-x": "exit\n"'             # Ctrl-x exits

# ============================================================================
# ALIASES (interactive only)
# ============================================================================

# Core
alias ls='ls --color=auto'
alias vim='nvim'
alias vi='vim'
alias ll='ls -lGh'
alias l='ll'
alias lll='ll'
alias la='ls -A'
alias grep='grep -iE --color=always'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Process
alias pgrep='pgrep -fl'
alias kill9='kill -9'

# Files
alias md='mkdir -p'
alias del='rm -rf'
alias exe='chmod a+x'

# Navigation
alias d='cd ~/Downloads'
alias dx='cd ~/Downloads/dropbox'
alias s='cd ~/scripts'
alias dot='cd ~/dotfiles'
alias plex='cd /mnt/matterhorn/Plex'

# Config
alias vimrc='vim ~/.vimrc'
alias aliases='vim ~/.aliases'

# Git
alias gs='git status'
alias gc='git commit -m'
alias ga='git add'
alias gaa='git add .'
alias gd='git diff'
alias gp='git push'
alias gitg='git gui &'
alias gitk='gitk --all &'

# Package management
alias search='apt-cache search'
alias install='sudo apt -y install'
alias remove='sudo apt -y purge'
alias update='sudo apt update'

# Tools
alias ncdu='ncdu --color dark'
alias ip='ip -c --brief'
alias pnpx='pnpm dlx'
alias ack='rg -i'
alias find='fd'
alias diff='colordiff'
alias rsync='rsync --stats --progress'
alias df='df --total -T'
alias du='du --total'

# Media
alias ffmpeg='ffmpeg -hide_banner'
alias ffprobe='ffprobe -hide_banner'
alias yget='yt-dlp'

# Network
alias myip='curl -4 ifconfig.co; curl -6 ifconfig.co'
alias dig='dig +noall +identify +answer +short'
alias ping8='ping 8.8.8.8'

# Quick exit
alias xit='exit'

# History
alias h='history'

# Source config
alias so='echo "Sourcing ~/.bashrc .."; source ~/.bashrc'
alias SO='so'
alias setup='~/dotfiles/setup; so'

# Apps
alias chrome='google-chrome &'
alias fb='thunar . &'
alias dl='thunar ~/Downloads &'

# Claude/AI
alias opus='claude --model opus'
alias sonnet='claude --model sonnet'

# Kubectl
alias k='sudo kubectl'
alias kube='sudo kubectl'
alias knode='sudo kubectl get node'
alias kpod='sudo kubectl get pod'
alias kdeploy='sudo kubectl get deployment'
alias kservice='sudo kubectl get service'
alias kps='sudo kubectl get node,service,deployment,pod'
alias kall='sudo kubectl get all'

# Package.json helpers
alias scripts='cat package.json | jq .scripts'
alias sc='scripts'
alias deps='cat package.json | jq "{deps: .dependencies, dev: .devDependencies}"'
alias jc='jq .'

# Misc
alias fmt='npx -y prettier --write'
alias service='sudo service'
alias systemctl='sudo systemctl'

# ============================================================================
# FUNCTIONS (interactive only)
# ============================================================================

tmp() { local tmpdir=$(mktemp -d /tmp/tmp.XXXXXX); cd "$tmpdir"; pwd; }

dt() {
    local dtname="$1" dtdir
    if [[ -z "$dtname" ]]; then
        dtdir=$(mktemp -d ~/Downloads/tmp.XXXXXX)
    else
        dtdir=~/Downloads/${dtname}-$(date +%Y-%m-%d-%H-%M)-$(pwgen -A 4 1)
        mkdir -p "$dtdir"
    fi
    cd "$dtdir"; pwd
}

fixgitconfig() {
    sed -i 's#url = https://github.com/#url = git@github.com:#' .git/config
    cat .git/config
}
alias gitfixconfig='fixgitconfig'

jclone() {
    if command -v gh &>/dev/null; then
        gh repo clone "jeffjose/$1"
    else
        git clone "https://github.com/jeffjose/$1"
    fi
    cd "$1" && fixgitconfig
}

newproject() {
    mkdir -p "$1"; cd "$1"
    touch README.md; git init; git add README.md; git commit -m "Initial"
    code README.md
}
alias np='newproject'

ghnew() {
    local _repo=$(basename "$PWD")
    if gh repo create "$_repo" --private --source=. --remote=origin --push 2>/dev/null; then
        return 0
    else
        local ssh_url=$(gh repo view "$_repo" --json sshUrl -q .sshUrl 2>/dev/null)
        if [[ -n "$ssh_url" ]]; then
            git remote set-url origin "$ssh_url" 2>/dev/null || git remote add origin "$ssh_url"
            git push -u origin master
        fi
    fi
}

sshfix() { ssh-keygen -f ~/.ssh/known_hosts -R "$1"; ssh "$1"; }

# ============================================================================
# COMPLETION (interactive only)
# ============================================================================

if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
elif [[ -f /etc/bash_completion ]]; then
    . /etc/bash_completion
fi

# Enhanced completion (like tcsh's "set complete = enhance")
_enhanced_file_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local pattern=""
    local char

    for ((i=0; i<${#cur}; i++)); do
        char="${cur:$i:1}"
        if [[ "$char" == "-" ]]; then
            pattern+="*-"
        else
            pattern+="$char"
        fi
    done
    pattern+="*"

    COMPREPLY=($(compgen -f -- "$cur"))

    if [[ ${#COMPREPLY[@]} -eq 0 ]] || [[ ! -e "${COMPREPLY[0]}" ]]; then
        local matches=()
        local f
        local old_nullglob=$(shopt -p nullglob)
        shopt -s nullglob
        for f in $pattern; do
            matches+=("$f")
        done
        eval "$old_nullglob"
        COMPREPLY=("${matches[@]}")
    fi
}

complete -o default -o bashdefault -o filenames -F _enhanced_file_completion vi vim nvim cat less more head tail
complete -o default -o bashdefault -o filenames -F _enhanced_file_completion code nano emacs
complete -o default -o bashdefault -o filenames -F _enhanced_file_completion cp mv rm ln chmod chown
complete -o default -o bashdefault -o filenames -F _enhanced_file_completion source .

# ============================================================================
# STARSHIP PROMPT (interactive only)
# ============================================================================

if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# ============================================================================
# LOCAL OVERRIDES (machine-specific, not in dotfiles)
# ============================================================================

[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
