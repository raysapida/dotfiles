# dotfiles

Shared macOS configuration for Zsh, tmux and Neovim, linked with
[rcm](https://github.com/thoughtbot/rcm). mise manages language runtimes,
Antigen manages shell plugins, TPM manages tmux plugins, and lazy.nvim manages
Neovim plugins.

The active `~/antigen.zsh` on this Mac now links to the repository's pinned
**Antigen 2.2.3**, with its official source and SHA-256 recorded in
[docs/antigen.json](docs/antigen.json). All eight plugin checkouts were preserved.
Fresh cold and warm terminals passed prompt, completion, suggestion, runtime and
reload checks. The original 1.2.3 loader and cache remain in a private backup;
see [activation and rollback](docs/unification.md#live-activation).

## Stable entry point

Keep `$HOME/.dotfiles` pointing to this checkout. The checkout can live elsewhere:

```text
~/.dotfiles -> ~/personal/tools/dotfiles
```

Aliases, helper scripts, existing config symlinks and rcm all use this entry
point. Paths use `$HOME` so the same configuration works for different usernames.

On a fresh machine, run `bash mac_setup.sh` from the checkout. It creates the
entry point when missing, refuses to replace another checkout, installs tools,
and links configuration. `RCRC` is set explicitly on the first rcm invocation so
the exclusion rules and `~/antigen.zsh` destination apply immediately.
Antigen comes from the committed script, so bootstrap never downloads a floating
loader version. The intended shared link is `~/antigen.zsh -> ~/.dotfiles/antigen.zsh`.

For an existing machine, use the [migration checklist](docs/unification.md)
instead of running the full bootstrap.
For the `raymond` Mac, start with the [destination handoff](docs/other-mac-upgrade.md),
which separates portable steps from this Mac's local activation records.

## Shared development tools

`Brewfile` lists the shared command-line tools. To install missing tools on an
existing Mac, run this from the checkout:

```sh
brew bundle install --file=Brewfile --no-upgrade
```

Neovim seeds its local `lazy-lock.json` from the repository on first startup
when the local file is missing. Existing lockfiles are kept. To adopt the
shared pins on an existing Mac, back up your local lockfile, copy
`config/nvim/lazy-lock.json` over it, then run `:Lazy restore`. To publish an
intentional plugin update, test it locally before copying the revised lockfile
back into the repository.

### Shared Git defaults

To opt in, add this include to `~/.gitconfig`. Put any local overrides after
it. Manage your work and personal Git identities in local or per-repository
configuration.

```gitconfig
[include]
    path = ~/.dotfiles/config/git/dotfiles.inc
```

The include sets the default branch for new repositories, prunes stale
remote-tracking branches on fetch, and points Git at the shared global ignore
list. If you already set `core.excludesFile`, merge any private patterns into
your own ignore file and keep that setting after the include to retain it.
Check the effective paths with
`git config --show-origin --get core.excludesFile`.

## Local settings

Personal agent skills live in `skills/`. Each tool's existing skill entry
points to its directory under `~/.dotfiles/skills/`. Shared entries use
`~/.agents/skills/`, and Claude Code entries use `~/.claude/skills/`.
These links are managed separately from rcm: run `bin/link-skills` after cloning
(and after adding a skill) to create any missing ones. It never replaces existing
entries. Synced skills stay with their installer. Skills copied from plugins are
listed with their upstream sources in [docs/vendored-skills.md](docs/vendored-skills.md).

To migrate a machine that already has standalone skills or older symlinks, run:

```sh
bin/link-skills --backup-existing
```

This moves conflicting entries into a timestamped directory under
`~/.local/state/dotfiles/skill-backups/`, preserving their original `.agents/skills/`
or `.claude/skills/` paths, then links the repository versions. Local edits remain
in the backup for comparison. Repeated runs leave correct links alone. To restore
an entry, remove its new symlink and move the saved entry back to its original
path. gstack, synced skills, and Codex's built-in/plugin skills stay with their
installers; only names present in this repo are linked.

Put credentials, local SDK paths and overrides in `~/.zshrc.local`, outside the
checkout. Zsh sources it last. Keep the file private (`chmod 600`).

Existing `~/.config/mise/config.toml` and `~/.default-gems` can remain independent
files. To retain them and an existing Antigen installation while linking other
settings:

```sh
RCRC="$HOME/.dotfiles/rcrc" rcup -v -K \
  -x config/mise/config.toml -x default-gems -x antigen.zsh
```

The Neovim entry point is `config/nvim/init.lua`; it sources `~/.vimrc`, which loads the
shared Lua modules. tmux uses `C-s` as its prefix; `prefix T` syncs macOS appearance to
the current tmux server and any running iTerm2 sessions. iTerm2 requires the
`Gruvbox Dark` and `Gruvbox Light` presets. `<Space>bg` changes Neovim's background
locally until the next macOS appearance change.

`zshreload` re-applies aliases, prompt preferences in `~/.spaceshiprc.zsh`, and
`~/.zshrc.local`. Antigen and plugin registration run once per shell, avoiding
Antigen v2's duplicate-theme handling that clears prompt hooks. Open a new shell
after changing the plugin list or the loader.

## Validation

```sh
python3 -m unittest discover -s tests -v
python3 tests/smoke_zsh.py
python3 tests/smoke_zsh.py --antigen-script antigen.zsh
# Set this to the retained v1 cache; see docs/unification.md for this Mac's path.
V1_CACHE="/path/to/antigen-backup/cache-v1"
python3 tests/smoke_antigen_migration.py --cache-dir "$V1_CACHE"
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos"
python3 tests/smoke_nvim.py
```

The unit/integration suite uses temporary homes for both usernames, recorded
external commands, and a separate tmux socket. It needs Zsh and rcm; the tmux
check is skipped if tmux is unavailable. The Neovim smoke check copies installed
plugins into a temporary home, disables plugin installation, and intercepts
theme automation. It requires the configured plugins to be installed first;
`--extra-plugin-root DIR` can supply plugins staged elsewhere.

The Zsh smoke check uses the installed Antigen and cached plugins in a temporary
home. It verifies Spaceship's prompt hook and actual rendering with both a cold
and warm cache, including a simulated Conda prompt prefix, an inherited theme
path and three reloads in each shell. It uses automatic `.zshrc` startup and
requires the generated Antigen cache to load. It checks that the loader runs once, the
prompt hook stays unique, the plugin registry stays stable, and changed local
settings appear in the rendered prompt. The theme filename is explicit because
older Antigen releases cannot infer it from the repository. Shared startup also
clears an inherited, writable `SPACESHIP_ROOT` so it finds the configured theme.

The migration check requires an unmigrated v1 cache, or a backup supplied
with `--cache-dir /path/to/v1-cache`. It copies the entire cache with symlinks,
verifies native layout migration and cold/warm v2 startup, and checks plugin
commits, Git metadata, working files and legacy cache preservation. Git mutations
and downloads are blocked; the optional Homebrew command-not-found lookup is
simulated as unavailable. See the [migration results](docs/unification.md#cache-migration-rehearsal).

The terminal integration check drives real Tab completion and visible history
suggestions in a separate pseudo-terminal, using actual Spaceship preferences,
Conda and installed mise runtimes. Its home, plugin cache and runtime-manager
state are temporary. It requires Conda, mise, exact global Ruby/Node versions and
another installed Ruby for project-version selection. `--conda-bin`, `--mise-bin`
and `--repos-dir` can select existing tools and a retained v1 cache backup.
Run v2 smoke, migration and terminal checks sequentially because upstream shares
a fixed temporary migration log.

Interactive checks for clipboard, pane navigation, terminal images and macOS
appearance are listed in the migration checklist.
