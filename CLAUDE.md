# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [rcm](https://github.com/thoughtbot/rcm). Files here are symlinked into `$HOME` using `rcup`.

## Setup / Installation

```sh
# Install dependencies (run mac_setup.sh for full setup)
brew install rcm neovim tmux rbenv the_silver_searcher

# Symlink dotfiles into $HOME
rcup -v

# Install antigen (zsh plugin manager)
curl -L git.io/antigen > ~/antigen.zsh

# Install tpm (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install vim-plug plugins (auto-installs on first nvim launch, or run manually)
nvim +PlugInstall +qall
```

## File Structure

| File | Symlinked to | Purpose |
|------|-------------|---------|
| `vimrc` | `~/.vimrc` | Neovim/vim config using vim-plug |
| `zshrc` | `~/.zshrc` | Zsh config using antigen for plugin management |
| `tmux.conf` | `~/.tmux.conf` | Tmux config using tpm for plugins |
| `eslintrc` | `~/.eslintrc` | ESLint config |
| `rspec` | `~/.rspec` | RSpec default flags |
| `bin/tat` | `~/.dotfiles/bin/tat` | Script to attach/create tmux session named after current directory |
| `antigen.zsh` | `~/antigen.zsh` | Antigen zsh plugin manager (committed directly) |

`bin/` is on `$PATH` via `zshrc`.

## Key Configuration Details

### Neovim (vimrc)
- Plugin manager: vim-plug (`call plug#begin()` ... `call plug#end()`)
- Leader key: `<Space>`
- Completion: deoplete + ncm2 + ultisnips; snippet expand `<C-t>`, forward `<C-j>`, backward `<C-a>`
- Insert mode escape: `jk`
- LSP: nvim-lspconfig with pyright (Python) and ruby_lsp (Ruby/Standard)
- Fuzzy finding: both Denite and CtrlP (`<C-p>`)
- File search: silver searcher (ag) integrated with CtrlP and grep
- RSpec: runs via `./scripts/run_tests.sh {spec}` using vim-tmux-runner

### Tmux (tmux.conf)
- Prefix: `C-s` (replaces default `C-b`)
- Pane navigation: `C-h/j/k/l` (vim-aware, works with vim-tmux-navigator)
- Split vertical: `prefix -`, split horizontal: `prefix v`
- Reload config: `prefix r`
- Window select: `F1`-`F5`, new window: `F6`, rename: `F7`
- Plugins: tpm, tmux-resurrect (auto-restore sessions), tmux-continuum, tmux-battery, tmux-urlview

### Zsh (zshrc)
- Plugin manager: antigen (sourced from `~/antigen.zsh`)
- Theme: spaceship-prompt
- Key aliases: `vim` -> `nvim`, `b` -> `buku --suggest`, `be` -> `bundle exec`, `tag`/`rtag` for ctags
- Edit config shortcuts: `ev` (vimrc), `et` (tmux.conf), `ez` (zshrc), `en` (nvim init.vim)
- `zshreload` to re-source zshrc
- Version managers: rbenv, nvm (via homebrew), sdkman, cargo
