# Unifying the Mac configurations

Use `fix/unify-branches` as the shared configuration, incorporating the Air's
`ac497b6` changes. Keep `~/.dotfiles` as the stable symlink to the checkout.
Machine-local files and installed plugin state remain outside the repository.

The installed `~/antigen.zsh` now links to the vendored, unmodified official
**Antigen 2.2.3** release. Its source and checksum are in `docs/antigen.json`.
The reload fix, cache migration and terminal integration checks passed with both
1.2.3 and 2.2.3 before activation. The live upgrade is complete on this Mac;
existing shells retain their initialized loader until a fresh shell is opened.

## Shared loader preparation

rcm's `UNDOTTED="antigen.zsh"` rule links `~/antigen.zsh` to
`~/.dotfiles/antigen.zsh`. Fresh-machine bootstrap uses that committed file and
does not download another Antigen copy. The installation test checks this link
for both usernames, including repeated installation. The release-pin test checks
the vendored bytes against the recorded SHA-256.

## Live activation

Activated on this Mac on **2026-11-22**:

```text
~/antigen.zsh -> ~/.dotfiles/antigen.zsh
~/.dotfiles -> ~/personal/tools/dotfiles
```

The private backup is:

```text
~/.dotfiles-backups/antigen-2.2.3-20261122-202326-016832
```

It contains `loader-v1.zsh`, the original cache in `cache-v1`, compiled-file
backups, activation state, private verification logs and the activation/rollback
scripts. The full cache was copied and migrated alongside the live cache before
switching. All eight checkout revisions and source trees were preserved.
Relative links under `~/.antigen/repos` retain their original plugin paths for
already-running 1.2.3 shells; the migrated checkouts live under `bundles`.

Fresh cold and warm terminals sourced the real user configuration and passed:
Spaceship prompt/cache registration, actual Git Tab completion, visible history
suggestions, global mise Ruby 4.0.5/Node 24.16.0, Conda base Python, and three
reloads with one prompt hook. Verification used private history and temporary
line-editor probes without editing local credentials. A separate real login-shell
check also passed startup and three reloads. Existing tmux sessions were not reloaded.

The activation and rollback procedures were checked on an isolated full-cache
copy first, including automatic rollback after an injected verification failure.
To restore the original loader/cache and retain the v2 files in the backup:

```sh
python3 "$HOME/.dotfiles-backups/antigen-2.2.3-20261122-202326-016832/rollback.py"
```

Open a fresh shell after activation or rollback; `zshreload` keeps the loader
already initialized in the current shell. For further isolated checks, use the
retained unmigrated cache rather than the live compatibility links:

```sh
V1_CACHE="$HOME/.dotfiles-backups/antigen-2.2.3-20261122-202326-016832/cache-v1"
python3 tests/smoke_antigen_migration.py --cache-dir "$V1_CACHE"
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos"
# Compare against the retained original loader:
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos" \
  --antigen-script "${V1_CACHE%/cache-v1}/loader-v1.zsh"
```

## Cache migration rehearsal

```sh
python3 tests/smoke_antigen_migration.py --cache-dir "$V1_CACHE"
```

The rehearsal copies the complete cache and checkout into a temporary home. It
runs the unmodified pinned loader's native migration, then starts Zsh through its
automatic `.zshrc` path to generate and reuse the v2 `init.zsh` cache. An interactive
`source` alone does not enable Antigen's automatic-startup cache generation.

Results on this Mac:

- All **8 of 8** checkouts moved from `repos` into `bundles`. Their commits, Git
  metadata, file contents, modes and symlinks were preserved exactly before plugin
  startup, including tracked edits and an untracked file injected into the copy.
- Cold and warm startup loaded Spaceship from the migrated bundle directory and
  rendered the prompt. The plugin registry stayed stable, with no added/removed
  checkouts or changes to plugin commits and source files.
- New `.zwc` and `.antigen-compat` files are generated startup artifacts. The
  preservation check distinguishes these from plugin source and working files.
- The remaining `repos/.DS_Store` explains the upstream message that some bundles
  could not be migrated. No Git checkout was left behind; the metadata file can
  remain in place.
- No downloads, package installations or Git mutations occurred. The optional
  `brew command command-not-found-init` availability lookup is simulated as
  unavailable in the isolated shell.
- Legacy cache files, the live cache and the installed 1.2.3 loader remained
  unchanged. The rehearsal does not activate the new loader.

The upstream helper uses `/tmp/antigen-v2-migrate.log`. The check refuses to run if
that log already exists and verifies that a successful migration removes its own
log. Run migration checks sequentially to avoid that shared upstream log path.

## Pre-activation integration checks

```sh
# The activation section above defines V1_CACHE.
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos"
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos" \
  --antigen-script "${V1_CACHE%/cache-v1}/loader-v1.zsh"
```

The check opens a separate pseudo-terminal and waits for Zsh's line editor before
sending input. It copies the checkout, plugin repositories and Spaceship settings
into a temporary home. Conda and installed mise runtimes are reused, with private
Conda user directories and copied mise configuration/cache. mise runs offline;
Git network protocols are disabled. It does not copy `~/.zshrc.local` credentials.

Both Antigen versions pass these checks on cold and warm startup:

- The generated startup cache loads; Spaceship's normal asynchronous prompt,
  Git completion mapping and syntax-highlighting function are present.
- Actual Tab presses complete `git statu` to `git status` and a unique filename.
- A seeded history entry appears as a visible autosuggestion, verified through
  Zsh's line-editor buffer and suggestion display.
- Conda base selects its own Python while mise selects global Ruby **4.0.5** and
  Node **24.16.0**. A project `.ruby-version` selects installed Ruby **4.0.10**, and
  leaving the project restores the global versions.
- Conda deactivate/reactivate preserves mise selection. Three `.zshrc` reloads
  retain one prompt hook, the runtime versions, Tab completion and suggestions.
- The live Antigen loader and cache remain unchanged. Existing tmux sessions are
  unaffected; the ten-check suite uses a separate socket for its tmux check.

All ten unit/integration checks and the headless Neovim startup check also pass.
Terminal colors/fonts, clipboard and Yazi previews remain the manual checks below.
Live activation subsequently passed the real-home checks described above.

This integration check requires local Conda/mise, exact global Ruby/Node settings,
a second installed Ruby and cached v1 plugins. After activation, use
`--repos-dir /path/to/v1-backup/repos`. Alternative tool locations can be selected
with `--conda-bin` and `--mise-bin`. Run v2 checks sequentially because their native
migration helper shares the fixed temporary log noted above.

## Reload behavior

Antigen v2 clears theme hooks before checking for duplicate registrations. A
second `antigen theme` call can therefore remove Spaceship's hook and then refuse
to load it again. Shared startup now loads Antigen and registers plugins once
per shell, using the existing `antigen` function to recognize initialization.

Reloading `~/.zshrc` still re-applies aliases, `~/.spaceshiprc.zsh` preferences and
`~/.zshrc.local` overrides. Plugin-list or loader changes take effect in a fresh
shell. The regression check covers startup and three reloads on cold/warm caches,
checks hook and plugin-registry stability, and verifies changed prompt settings
in the actual rendered output for both Antigen versions.

## Content retained

- The Pro's mise migration, project-aware Ruby LSP, Gutentags, clangd, Claude
  integration, Spotify status and shell helpers.
- The Air's mouse default, `prefix T`, Lean plugin, soft prose wrapping and
  appearance-change debounce. There is one `ub` implementation.
- Existing Yazi passthrough and terminal environment settings.
- TypeScript LSP in the shared Neovim entry point.

The shared configuration uses `$HOME` for mise and Bun. Shell startup performs no
package installation, tolerates missing optional tools, and sources local
overrides last. The theme helper respects `$TMUX`, uses the installed gruvbox
launcher, reapplies battery formatting, and avoids launching terminal apps.

## Existing-machine activation

1. Back up both Git histories, dirty files, active dotfiles, config symlink
   targets, Neovim entry point/lockfile, mise config and default gems. Store
   credentials only in a private backup outside the checkout.
2. Reconcile the active shell into shared defaults and `~/.zshrc.local`. Preserve
   local credentials, aliases, Conda/Broot integration and SDK paths. Keep the
   local file mode at 600. The shared defaults adopt Docker BuildKit.
3. Stage only missing plugins. Preserve existing plugin versions and lockfile;
   do not run a blanket update or the fresh-machine bootstrap.
4. Run the automated suite and the Neovim smoke check, using staged plugins if
   needed. Verify the real shell plugin setup in a temporary home as well.
5. Move the existing `~/.dotfiles` checkout, including its `.git` and local
   changes, into the private backup. Replace it with a symlink to the unified
   checkout. Existing `~/.vimrc` and `~/.tmux.conf` links then resolve there.
6. Link `~/.zshrc`, `~/.rcrc`, the Neovim entry point and ctags exclusions. Keep
   the existing mise config, default gems and `~/antigen.zsh`. On this Mac the
   runtime defaults remain Ruby 4.0.5, Node 24.16.0 and uv.
7. Open a separate shell and confirm runtime selection, aliases and helpers.
   Open a new tmux/Neovim session for the interactive checks below. Existing
   processes retain their loaded configuration until reloaded/restarted.

Migration backups should include a manifest and a rollback script. Rollback
restores the old checkout and the original files/symlink targets; new local files
should be retained in the backup rather than discarded. Do not reload existing
tmux sessions automatically as part of activation or rollback.

## Automated checks

```sh
python3 -m unittest discover -s tests -v
python3 tests/smoke_zsh.py
python3 tests/smoke_zsh.py --antigen-script antigen.zsh
# V1_CACHE is defined in the live activation section.
python3 tests/smoke_antigen_migration.py --cache-dir "$V1_CACHE"
python3 tests/smoke_zsh_integration.py --repos-dir "$V1_CACHE/repos"
python3 tests/smoke_nvim.py --extra-plugin-root /path/to/staged/plugins
git diff --check
```

Coverage includes shell syntax, both usernames, repeated rcm installation,
optional dependencies, local override precedence, Unison profile selection and
arguments, theme presets, absent apps/servers, tmux socket routing, real Neovim
plugin loading, LSP config, mappings and appearance debounce. Tests never use
the live tmux socket or invoke macOS theme automation.

The Zsh smoke check must confirm the rendered prompt, not just a successful
startup. Antigen 1.2.3 requires `--loc=spaceship.zsh-theme`; without it, Spaceship
can be silently skipped even though other plugins and shell helpers load.
An inherited `SPACESHIP_ROOT` can point at an incompatible installation that
still exists. Startup clears that runtime value before loading the theme; the
prompt check covers this case and reloading a shell whose theme root is readonly.

The temporary homes test path portability; they do not emulate another Mac's
installed tools, OS permissions or terminal emulator.

## Interactive checks on each Mac

- Prompt appearance, expected aliases and Ruby/Node versions in a new shell.
- tmux prefix, pane navigation, mouse scrolling and clipboard copy/paste.
- Spotify and battery status; Yazi image previews.
- Light/dark appearance and `prefix T`, including installed iTerm2 presets.
- Ruby and TypeScript LSP in real projects; Lean and prose wrapping where used.
- Claude integration with the local CLI installed and authenticated.
