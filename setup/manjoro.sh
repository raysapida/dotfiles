#!/bin/bash
pacman -Syy vim neovim

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

curl -L git.io/antigen > ~raysapida/antigen.zsh

# TODO: Change this to how it would be scripted instead of manually writing the commands
# Install yaourt: https://cloudcone.com/docs/article/install-packages-in-arch-linux-from-aur/
# git clone https://github.com/archlinuxfr/yaourt
# cd yaourt/
# makepkg -si

# git clone https://aur.archlinux.org/rcm.git
# cd rcm/
# makepkg -si
# rcup

git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
mkdir -p "$(rbenv root)"/plugins
rbenv install 2.6.3
rbenv global 2.6.3
gem install rails
gem install pry
gem install solargraph
gem install minitest
