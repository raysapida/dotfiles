# skip_global_compinit=1
# Path to your oh-my-zsh installation.
# export ZSH=/Users/raysapida/.oh-my-zsh
# export ZSH=/Users/raymond/.oh-my-zsh

#source ~raysapida/antigen.zsh
# source ~raymond/antigen.zsh
source $HOME/antigen.zsh

# Add bin files in dotfiles in path
export PATH="$HOME/.dotfiles/bin:$PATH"



# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder


# User configuration

# export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
# export MANPATH="/usr/local/man:$MANPATH"

# source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# place this after nvm initialization!
# autoload -U add-zsh-hook
# load-nvmrc() {
#   local node_version="$(nvm version)"
#   local nvmrc_path="$(nvm_find_nvmrc)"

#   if [ -n "$nvmrc_path" ]; then
#     local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

#     if [ "$nvmrc_node_version" != "N/A" ] && [ "$nvmrc_node_version" != "$node_version" ]; then
#       nvm install
#     fi
#   elif [ "$node_version" != "$(nvm version default)" ]; then
#     echo "Reverting to nvm default version"
#     nvm use default
#   fi
# }
# add-zsh-hook chpwd load-nvmrc
# load-nvmrc


## Copied from .bash_profile
export EDITOR="nvim"
export USE_EDITOR=$EDITOR
export VISUAL=$EDITOR
export PATH=$HOME/bin:$PATH
eval "$(rbenv init -)"

# some more ls aliases
# alias ll='ls -alF'
# alias la='ls -A'
# alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias b='bundle'
alias be='bundle exec'
alias tag='ctags -R -f ./.git/tags .'


alias ev='nvim ~/.vimrc'
alias et='nvim ~/.tmux.conf'
alias ez='nvim ~/.zshrc'

alias zshreload="source ~/.zshrc"

alias ccat='pygmentize -O bg=dark,style=colorful'

setopt inc_append_history
setopt share_history

# antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle robbyrussell/oh-my-zsh
antigen bundle lukechilds/zsh-nvm

antigen use oh-my-zsh

antigen bundle git
antigen bundle command-not-found
antigen bundle docker

# Load bundles from external repos
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting

antigen theme denysdovhan/spaceship-prompt

antigen apply

export PATH="/usr/local/opt/curl/bin:$PATH"

export VIRTUALENV_PYTHON=/usr/local/bin/python3
export VIRTUALENVWRAPPER_PYTHON=$VIRTUALENV_PYTHON

export PATH="$HOME/.yarn/bin:$PATH"


alias rtag='ctags -R --languages=ruby --exclude=.git --exclude=log --exclude=tmp . $(bundle list --paths)'

alias docker-stop-all='docker stop $(docker ps -a -q)'
alias docker-rm-all='docker rm $(docker ps -a -q)'
alias docker-start-all='docker start $(docker ps -a -q)'

alias git10='git log --pretty=format: --name-only | sort | uniq -c | sort -rg | head -10'

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /Users/raysapida/.config/yarn/global/node_modules/tabtab/.completions/serverless.zsh ]] && . /Users/raysapida/.config/yarn/global/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /Users/raysapida/.config/yarn/global/node_modules/tabtab/.completions/sls.zsh ]] && . /Users/raysapida/.config/yarn/global/node_modules/tabtab/.completions/sls.zsh

alias rn-x='react-native run-ios --simulator="iPhone X"'

export PATH=$PATH:/Users/raysapida/platform-tools/bin
export PATH=$PATH:/Users/raymond/Library/Android/sdk/platform-tools

alias lint='./node_modules/.bin/eslint --fix'

alias b='buku --suggest'

export ANDROID_SDK_ROOT="/usr/local/share/android-sdk"
export ANDROID_HOME="/usr/local/share/android-sdk"

alias clean-branches='git branch --merged master | grep -v "\* master" | xargs -n 1 git branch -d'

alias usb-info='system_profiler SPUSBDataType'
alias run-local='./scripts/run_local.sh'

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git npm docker rails brew)
plugins=(git rails yarn docker)

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/raymond/work/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/raymond/work/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/raymond/work/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/raymond/work/google-cloud-sdk/completion.zsh.inc'; fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

alias rl='./scripts/run_local.sh'
alias rt='./scripts/run_tests.sh'
alias rterm='./scripts/run_terminal.sh'

export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

nvm use default
