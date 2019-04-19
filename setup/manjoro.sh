#!/bin/bash
pacman -Syy vim neovim

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

curl -L git.io/antigen > ~raysapida/antigen.zsh
