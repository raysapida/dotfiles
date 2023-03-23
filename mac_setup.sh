#!/bin/bash

# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/raymond/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install node
curl "https://nodejs.org/dist/latest/node-${VERSION:-$(wget -qO- https://nodejs.org/dist/latest/ | sed -nE 's|.*>node-(.*)\.pkg</a>.*|\1|p')}.pkg" > "$HOME/Downloads/node-latest.pkg" && sudo installer -store -pkg "$HOME/Downloads/node-latest.pkg" -target "/"

brew update
brew install neovim
brew install tmux
brew install rbenv
brew install python
brew install the_silver_searcher

brew install rcm
lsrc
rcup -v

# Install antigen
curl -L git.io/antigen > antigen.zsh

# Install tpm (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Dependencies for tmux-plugins/tmux-urlview
brew install urlview
brew install extract_url


curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
