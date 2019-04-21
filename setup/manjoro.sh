#!/bin/bash
pacman -Syy vim neovim yarn --noconfirm

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

nvm install stable

sudo pacman -Sy docker docker-compose --noconfirm
systemctl enable docker
systemctl start docker
# DEBUG docker if it doesn't start
# systemctl status docker.service
# journalctl -xe
sudo usermod -a -G docker $USER

sudo pacman -Sy code python --noconfirm

# TODO: AUR repos of applications installed
# Chrome: https://aur.archlinux.org/google-chrome.git
# Discord: https://aur.archlinux.org/discord.git
# Android Studio: https://aur.archlinux.org/android-studio.git
# Slack: https://aur.archlinux.org/slack-desktop.git
# libc++: https://aur.archlinux.org/libc++.git

# TODO: Tried to install but got PGP errors
# https://aur.archlinux.org/spotify.git
gpg --recv-key 931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90
# https://aur.archlinux.org/libc++.git
gpg --recv-key 474E22316ABF4785A88C6E8EA2C794A986419D8A
gpg --recv-key B6C8F98282B944E3B0D5C2530FC3042E345AD05D

