#!/bin/bash
#
# Fresh-machine bootstrap. Safe to re-run; steps are idempotent where possible.

set -euo pipefail

# Keep ~/.dotfiles as the stable entry point, even if this checkout lives
# elsewhere. Existing checkouts are migrated separately, never overwritten.
dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -e "$HOME/.dotfiles" ] || [ -L "$HOME/.dotfiles" ]; then
  if [ "$(cd "$HOME/.dotfiles" && pwd -P)" != "$dotfiles_dir" ]; then
    echo "~/.dotfiles points to another checkout; preserve and migrate it first." >&2
    exit 1
  fi
else
  ln -s "$dotfiles_dir" "$HOME/.dotfiles"
fi

# ----------------------------------------------------------------------
# Homebrew
# ----------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew update
brew install neovim
brew install tmux
brew install python
brew install the_silver_searcher
brew install urlview      # for tmux-plugins/tmux-urlview
brew install extract_url  # for tmux-plugins/tmux-urlview

# ----------------------------------------------------------------------
# Dotfiles (rcm) — do this before mise so ~/.config/mise/config.toml exists
# ----------------------------------------------------------------------
brew install rcm
# rcrc links the pinned Antigen script to ~/antigen.zsh (no leading dot).
RCRC="$dotfiles_dir/rcrc" rcup -v -d "$HOME/.dotfiles"

# ----------------------------------------------------------------------
# mise — manages ruby, node, python versions (replaced rbenv + nvm)
# ----------------------------------------------------------------------
if ! [ -x "$HOME/.local/bin/mise" ]; then
  curl https://mise.run | sh
fi

# Installs the versions pinned in ~/.config/mise/config.toml. New Ruby versions
# get ruby-lsp through ruby.default_packages_file.
"$HOME/.local/bin/mise" install

# Node package-manager shims are setup work, not shell-startup work.
if "$HOME/.local/bin/mise" which corepack >/dev/null 2>&1; then
  "$HOME/.local/bin/mise" exec -- corepack enable
fi

# Belt and braces: ensure ruby-lsp exists in every ruby already installed,
# in case the hook did not fire (e.g. a ruby installed before this config).
"$HOME/.dotfiles/bin/install-ruby-lsp"

# ----------------------------------------------------------------------
# Shell / editor plugin managers
# ----------------------------------------------------------------------
# Antigen comes from the pinned repository file linked by rcm above.

# tpm (tmux plugins)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# nvim plugins are managed by lazy.nvim, which bootstraps itself on first
# launch (see config/nvim/lua/dotfiles/plugins.lua). `install` only fetches what is missing —
# deliberately not `sync`/`update`, which would pull every plugin to latest and
# can break a working setup. Run :Lazy update by hand when you want that.
nvim --headless "+Lazy! install" +qa
