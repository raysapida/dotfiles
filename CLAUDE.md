# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [rcm](https://github.com/thoughtbot/rcm). Files here are symlinked into `$HOME` using `rcup`. `$HOME/.dotfiles` is the stable entry point and can itself be a symlink to this checkout. Credentials and machine-specific overrides belong in `~/.zshrc.local`, sourced last.

## Setup / Installation

```sh
# Install dependencies (run mac_setup.sh for full setup)
brew install rcm neovim tmux the_silver_searcher

# Symlink dotfiles into $HOME
RCRC="$HOME/.dotfiles/rcrc" rcup -v -K

# rcm links the repository's pinned Antigen 2.2.3 to ~/antigen.zsh.
# Existing machines retain their old loader until migration/activation.

# Install tpm (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install lazy.nvim plugins without updating existing plugins
nvim --headless "+Lazy! install" +qa
```

## File Structure

| File | Symlinked to | Purpose |
|------|-------------|---------|
| `vimrc` | `~/.vimrc` | Neovim config using lazy.nvim |
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` | Sources vimrc and enables TypeScript LSP |
| `zshrc` | `~/.zshrc` | Zsh config using antigen for plugin management |
| `tmux.conf` | `~/.tmux.conf` | Tmux config using tpm for plugins |
| `eslintrc` | `~/.eslintrc` | ESLint config |
| `rspec` | `~/.rspec` | RSpec default flags |
| `bin/tat` | `~/.dotfiles/bin/tat` | Script to attach/create tmux session named after current directory |
| `bin/link-skills` | `~/.dotfiles/bin/link-skills` | Links each `skills/` entry into `~/.claude/skills` and `~/.agents/skills`; skips conflicts by default, or moves them to a private backup with `--backup-existing` |
| `antigen.zsh` | `~/antigen.zsh` | Pinned Antigen 2.2.3 (undotted destination in rcrc); provenance in docs/antigen.json |

`bin/` is on `$PATH` via `zshrc`.

## Key Configuration Details

### Neovim (vimrc)
- Plugin manager: lazy.nvim (Lua plugin specification near the top of vimrc)
- Leader key: `<Space>`
- Completion: nvim-cmp with LSP, buffer and path sources
- Insert mode escape: `jk`
- LSP: nvim-lspconfig with pyright, project-aware mise Ruby LSP, clangd and TypeScript
- Fuzzy finding: Telescope
- File search: silver searcher (ag) integrated with CtrlP and grep
- RSpec: runs via `./scripts/run_tests.sh {spec}` using vim-tmux-runner

### Tmux (tmux.conf)
- Prefix: `C-s` (replaces default `C-b`)
- Pane navigation: `C-h/j/k/l` (vim-aware, works with vim-tmux-navigator)
- Split vertical: `prefix -`, split horizontal: `prefix v`
- Reload config: `prefix r`
- Window select: `F1`-`F5`, new window: `F6`, rename: `F7`
- Plugins: tpm, tmux-resurrect (auto-restore sessions), tmux-continuum, tmux-battery, tmux-urlview, gruvbox
- Mouse: on by default; `F11` toggles it
- Theme: `prefix T` runs `bin/sync-theme` against the current socket

### Zsh (zshrc)
- Plugin manager: antigen (sourced from `~/antigen.zsh`)
- Theme: spaceship-prompt
- Key aliases: `vim` -> `nvim`, `b` -> `buku --suggest`, `be` -> `bundle exec`, `tag`/`rtag` for ctags
- Edit config shortcuts: `ev` (vimrc), `et` (tmux.conf), `ez` (zshrc), `en` (nvim init.vim)
- `zshreload` to re-source zshrc
- Version managers: mise (Ruby/Node and other tools), optional sdkman, cargo and elan
- Antigen and plugin registration initialize once per shell. `zshreload` refreshes aliases, prompt preferences and local overrides; plugin-list or loader changes require a fresh shell.

## Validation and migration

- `python3 -m unittest discover -s tests -v` uses temporary homes and an isolated tmux server.
- `python3 tests/smoke_zsh.py` verifies real Spaceship prompt loading and rendering with cold and warm Antigen caches.
- `python3 tests/smoke_antigen_migration.py` copies the full v1 cache and verifies native migration, plugin preservation and actual v2 startup-cache reuse. Run it sequentially with other migration checks because upstream uses a fixed temporary log path.
- `python3 tests/smoke_zsh_integration.py` checks real terminal completion/suggestions, Conda and installed mise runtimes with a temporary home. It supports `--antigen-script`, `--repos-dir`, `--conda-bin` and `--mise-bin`; run v2 checks sequentially because of the shared upstream migration log.
- `python3 tests/smoke_nvim.py` copies installed plugins into an isolated home without downloads or live theme automation.
- See `docs/unification.md` for activation, preservation of local runtime settings, rollback and manual checks.
- On the `raymond` Mac, start with `docs/other-mac-upgrade.md`; this Mac's private activation scripts/backups do not transfer with Git. Inspect and preserve the destination's own loader, cache and runtime settings.
- Existing machines should preserve local mise config, default gems and Antigen with the exclusions documented in README.md rather than running the fresh-machine bootstrap.
