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
brew bundle install --file="$dotfiles_dir/Brewfile" --no-upgrade

# ----------------------------------------------------------------------
# Dotfiles (rcm) — do this before mise so ~/.config/mise/config.toml exists
# ----------------------------------------------------------------------
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
"$HOME/.local/bin/mise" -C "$HOME" install

# Provision TypeScript LSP and Corepack in the default Node installation.
"$dotfiles_dir/bin/install-node-tools"

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

# lazy.nvim installs missing plugins from the shared lockfile on startup.
nvim --headless +qa
