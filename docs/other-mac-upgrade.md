# Handoff: upgrade the raymond Mac

Use this guide with `README.md` and `docs/unification.md` when applying
`fix/unify-branches` on the other Mac. The shared configuration uses `$HOME` and
has installation checks for both `raymond` and `raysapida`. No global username
replacement is needed. Actual installed tools and terminal behavior still need
verification on the destination computer.

## What transfers

Git carries the shared configuration, the pinned Antigen 2.2.3 loader, its
provenance/checksum in `docs/antigen.json`, and the isolated validation scripts.
The reload fix initializes Antigen and its plugins once per shell; local aliases
and prompt preferences still reload. Open a fresh shell to change loader versions.

The activation results in `docs/unification.md` describe the **raysapida** Mac.
Its timestamped backups, rollback/activation scripts and private verification
logs are outside Git. Do not use those paths as the raymond Mac's rollback plan.
Implement and validate a destination-local activation/rollback procedure before
switching its loader. Do not copy compiled caches or plugin directories from
the other username; derive them from this computer's own installation.

## Inspect and preserve this computer

Run `bin/dotfiles-doctor` from the checkout for a read-only check of the current
links, Antigen files, Zsh completion permissions, and Ghostty appearance setting.

1. Inspect the branch, dirty files, existing `~/.dotfiles`, config symlink targets,
   `~/antigen.zsh`, `~/.antigen` layout and cached plugin revisions. Do not assume
   the loader is still 1.2.3 or that this Mac has the same eight checkouts. If it
   already has 2.2.3 and a `bundles` cache, validate that state instead of rerunning
   a v1 migration.
2. Create a private timestamped backup under `$HOME/.dotfiles-backups`. Preserve
   the existing checkout/history/dirty files, loader, complete plugin cache,
   configuration files and symlink targets. Include existing compiled config
   sidecars and completion dumps in the rollback inventory. Keep credentials
   outside Git and avoid printing them in diagnostics.
3. Preserve this Mac's `~/.zshrc.local`, `~/.spaceshiprc.zsh`, mise config,
   default gems, Conda/Broot/SDK integrations and Neovim lockfile/plugins. Move
   any credentials still embedded in a tracked config into private local overrides.
   Use its own installed runtime versions; 4.0.5/24.16.0 in the other Mac's
   results are observations, not required migration targets.
4. Make `$HOME/.dotfiles` resolve to the synchronized checkout. If that path is
   already a checkout or points elsewhere, preserve its history and dirty files
   before changing it. The checkout itself can live at any path.
5. Follow the existing-machine checklist in `docs/unification.md`. Link shared
   configuration while retaining the installed loader and local runtime files:

   ```sh
   RCRC="$HOME/.dotfiles/rcrc" rcup -v -K \
     -x config/mise/config.toml -x default-gems -x antigen.zsh
   ```

   Run this only after reconciling/backing up existing configs. Use the existing
   machine workflow rather than `mac_setup.sh`, which is a fresh-machine setup.

## Rehearse Antigen 2.2.3

For an installed v1 loader/cache, run these from the synchronized checkout before
activation, sequentially (upstream shares `/tmp/antigen-v2-migrate.log`):

```sh
python3 -m unittest discover -s tests -v
python3 tests/smoke_zsh.py
python3 tests/smoke_zsh.py --antigen-script antigen.zsh
python3 tests/smoke_antigen_migration.py --cache-dir "$HOME/.antigen"
python3 tests/smoke_zsh_integration.py --antigen-script "$HOME/antigen.zsh"
python3 tests/smoke_zsh_integration.py --antigen-script antigen.zsh
```

Read the test prerequisites first. The terminal check needs Conda, mise, exact
installed global Ruby/Node versions and a second installed Ruby. Its
`--conda-bin` and `--mise-bin` flags support different tool locations. If those
prerequisites do not match this computer, adapt verification to its actual tools
and record the coverage gap; do not install or change runtimes just to match the
other Mac's results. The separate Neovim smoke check requires installed plugins.

Compare the vendored loader against the SHA-256 in `docs/antigen.json`. Rehearsals
must use copied caches, preserve plugin revisions and local edits, and avoid
downloads/blanket plugin updates. Investigate failures before live activation.

## Activate with a local rollback

1. Prepare a full staged copy of this Mac's v1 cache alongside the original.
   Run the pinned loader's native migration with cache/log paths redirected to
   the staged directory. Verify all plugin revisions and source trees before
   loading plugins. Preserve legacy cache files and locally edited/untracked files.
2. If existing v1 shells will remain open, add relative compatibility symlinks
   from each original `repos/<encoded-name>` to its migrated checkout under
   `bundles`. Derive these from this Mac's inventory. Keep the links afterward.
3. Rebuild newly generated v2 startup/completion metadata at its permanent path;
   do not retain metadata pointing to the staged directory. Confirm the live
   cache did not change during staging before switching it.
4. Retain the original cache in the local backup, move the staged cache into
   `~/.antigen`, then replace `~/antigen.zsh` with a symlink to
   `$HOME/.dotfiles/antigen.zsh`. Record the changes in the local backup manifest.
   Validate explicit rollback and automatic rollback on verification failure on
   an isolated copy before doing these live operations.
5. In separate fresh cold/warm shells, verify the generated v2 cache is loaded,
   Spaceship renders, Tab completion and history suggestions work, and runtime
   selection/Conda behavior matches this machine's baseline. Test three reloads
   retaining exactly one prompt hook and stable plugins. Check login startup too.
   Keep probe history/logs private; leave existing shells and tmux servers running.
6. Verify the active loader checksum and all plugin revisions/source files again.
   On failure, restore the original loader, cache and compiled config files,
   retaining failed v2 state for diagnosis. On success, record this computer's
   backup path, rollback command, runtime versions and check results.

After activation, use the **local** retained v1 cache for migration/terminal
rehearsals: `--cache-dir /local/backup/cache-v1` and
`--repos-dir /local/backup/cache-v1/repos`. The live compatibility symlinks are
not a standalone v1 cache copy. Finish with the interactive checks listed in
`docs/unification.md` for terminal appearance, tmux, clipboard, Yazi and Neovim.
If Ghostty prompts about insecure completion directories on startup, follow the
[Zsh completion troubleshooting steps](desktop/README.md#zsh-completion-warning).

## Suggested instruction for the next session

> Read README.md, docs/other-mac-upgrade.md and docs/unification.md. This is the
> raymond Mac. Inspect its current state, preserve its local settings and plugin
> versions, rehearse the pinned Antigen 2.2.3 upgrade, then activate it with a
> tested local backup/rollback. Use this machine's paths and installed runtimes;
> leave existing shells and tmux sessions running. Record results and any checks
> that could not run here.
