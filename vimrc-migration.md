# vimrc Migration Plan

## High Priority — nvim 0.11 Compatibility

### 1. Replace deoplete + ncm2 with nvim-cmp
- [x] Remove `Shougo/deoplete.nvim` and all deoplete config (`g:deoplete#enable_at_startup`, `Multiple_cursors_before/after` functions)
- [x] Remove `ncm2/ncm2`, `ncm2/ncm2-ultisnips`, `ncm2/ncm2-bufword`, `ncm2/ncm2-path` and all ncm2 config
- [x] Remove `roxma/nvim-yarp` (dependency of both, no longer needed)
- [x] Remove the nvim venv at `~/.config/nvim/nvim-venv` and `g:python3_host_prog`
- [x] Add `hrsh7th/nvim-cmp` with sources: `nvim-lspconfig`, `ultisnips`, buffer, path
- [x] Wire up tab/shift-tab and CR keymaps for nvim-cmp

### 2. Replace denite.nvim with telescope.nvim
- [x] Remove `Shougo/denite.nvim` and all denite config (shortcuts, `s:denite_options`, `s:denite_my_settings`)
- [x] Add `nvim-telescope/telescope.nvim` + `nvim-lua/plenary.nvim`
- [x] Remap `;`, `<leader>r`, `<leader>g`, `<leader>j` to telescope equivalents

---

## Medium Priority — Dead Config Cleanup

### 3. Remove coc.nvim mappings
- [x] Remove `<leader>dd`, `<leader>dr`, `<leader>dj` coc keymaps

### 4. Remove ALE settings
- [x] Remove `g:ale_sign_error`, `g:ale_sign_warning`, `g:ale_lint_on_enter`

### 5. Deduplicate nvim-yarp
- [x] Already handled by removing deoplete + ncm2 entirely (see item 1)

---

## Low Priority

### 6. Remove g:python3_host_prog
- [x] Remove after deoplete + ncm2 are gone (nvim-lspconfig does not need a Python host)

---

## General Cleanup — vimrc + tmux.conf

### 7. Remove dead vim-plug bootstrap comment blocks (vimrc)
- [x] Removed old commented-out vim/nvim-specific plug.vim bootstrap variants (lines 11–29)
- **Why:** Dead code carried over from years of vim → nvim migration. Only one bootstrap block is needed; the active one using `stdpath('data')` already handles both vim and nvim.

### 8. Remove CtrlP and its ag integration (vimrc)
- [x] Removed `ctrlpvim/ctrlp.vim` plugin
- [x] Removed `g:ctrlp_map`, `g:ctrlp_cmd`, `g:ctrlp_user_command`, `g:ctrlp_use_caching` config
- **Why:** Telescope now covers all CtrlP use cases (file finding, buffer switching). Keeping both is redundant. The ag-in-CtrlP integration config was also removed since CtrlP is gone; the `Ag` command and `\` keymap were kept since they use ag.vim directly.

### 9. Remove duplicate indent plugins (vimrc)
- [x] Removed `nathanaelkane/vim-indent-guides` plugin and its config block (`indent_guides_start_level`, `indent_guides_guide_size`, `indent_guides_auto_colors`, highlight autocmds)
- [x] Kept `Yggdroot/indentLine` (no config needed, works out of the box)
- **Why:** Both plugins display indent levels and conflict. `indentLine` is more actively maintained for nvim and requires no config.

### 10. Remove duplicate CSV plugin (vimrc)
- [x] Removed `chrisbra/csv.vim`
- [x] Kept `hat0uma/csvview.nvim` (already configured via `lua require('csvview').setup()`)
- **Why:** Both handle CSV files. `csvview.nvim` is the lua-native plugin already wired up; `csv.vim` was redundant.

### 11. Remove dead YCM config (vimrc)
- [x] Removed `g:ycm_key_list_select_completion` and `g:ycm_key_list_previous_completion`
- **Why:** YouCompleteMe is not installed and never was in this config. These settings were leftover from a copy-paste and had no effect.

### 12. Fix duplicate limelight assignment (vimrc)
- [x] Removed `let g:limelight_conceal_ctermfg = 'gray'` (immediately overridden by `= 240` on the next line)
- **Why:** The string form was set then immediately overwritten by the numeric form. The string form was dead.

### 13. Remove redundant `filetype indent on` (vimrc)
- [x] Removed `filetype indent on` (line 278)
- **Why:** `filetype plugin indent on` (line 276) is a superset — it enables filetype detection, plugin loading, and indent rules. The plain `filetype indent on` was redundant.

### 23. Fix black bars in tmux status bar from egel/tmux-gruvbox conflict
- [x] Removed hardcoded `set -g status-style`, `setw -g window-status-format`, `setw -g window-status-current-format`, `setw -g window-status-current-style`, `setw -g window-status-style`, `set -g message-style`, `set -g message-command-style`
- [x] Removed `set -g status-left ''` (plugin sets its own)
- [x] Stripped `#[fg=colour...]`/`#[bg=colour...]` codes from `status-right` — kept spotify, battery, date content
- **Why:** `egel/tmux-gruvbox` sets all status bar colors. Hardcoded color codes created black gaps (colour0/colour234) between the session name, window tabs, and date sections because they overrode the plugin's palette.
- **How to apply:** Let the plugin own all color settings. Only set `status-right` content without inline color codes.

### 14. Remove duplicate plain pane navigation bindings (tmux.conf)
- [x] Removed `bind-key -n C-h/j/k/l select-pane` block (the plain version)
- **Why:** These were overridden further down by vim-aware versions using `if-shell` to check if the current pane is running vim/nvim. The plain bindings were unreachable dead code.

### 15. Update default-terminal to tmux-256color (tmux.conf)
- [x] Changed `screen-256color` → `tmux-256color`
- **Why:** On M1 Mac with modern terminals (iTerm2, Ghostty, Kitty), `tmux-256color` enables proper true color (24-bit) support. `screen-256color` caps at 256 colors and can cause color rendering issues in nvim themes.

### 16. Fix wiki binding (tmux.conf)
- [x] Changed `bind-key w split-window -h -c ~/code/wiki "vim +:NERDTree"` → `"nvim"` with `$HOME/code/wiki`
- **Why:** Used the old `vim` binary instead of `nvim`. Also tilde expansion is unreliable inside tmux `bind-key` — `$HOME` is safer. NERDTree was removed since it's not in the plugin list.

### 17. Remove UltiSnips (vimrc)
- [x] Removed `SirVer/ultisnips` and `honza/vim-snippets` plugins
- [x] Removed `g:UltiSnipsEditSplit`, `g:UltiSnipsExpandTrigger`, `g:UltiSnipsJumpForwardTrigger`, `g:UltiSnipsJumpBackwardTrigger`
- **Why:** UltiSnips relies on the Python provider which shifts behavior across nvim minor versions. Not worth maintaining for infrequent snippet use. Re-add later with `lazy.nvim` if needed — the ecosystem will be cleaner by then.
- **To restore:** Install `lazy.nvim`, add `L3MON4D3/LuaSnip` (lua-native, no Python dependency) with `rafamadriz/friendly-snippets` for the snippet collection.

### 18. Fix missing pyright for Python LSP (post-upgrade)
- [x] Run `npm install -g pyright` after upgrading nvim
- **Why:** `nvim-lspconfig` is configured to use `pyright-langserver` for Python files but the binary isn't installed. This causes a warning when opening `.py` files: `Spawning language server with cmd: { "pyright-langserver", "--stdio" } failed`. nvim still opens Python files — only LSP features (autocomplete, go-to-definition) are missing.
- **Not fixed by nvim upgrade** — it's a missing binary, not a nvim bug. Safe to upgrade first and fix after.

### 19. Migrate vim-plug to lazy.nvim
- [x] Removed vim-plug bootstrap and all `Plug` declarations
- [x] Added lazy.nvim bootstrap using `vim.uv.fs_stat` (nvim 0.10+ API, replaces deprecated `vim.loop`)
- [x] Converted all plugins to lazy.nvim spec with `ft =` lazy loading for language-specific plugins
- [x] Removed dead UltiSnips-dependent snippet plugins (`vim-react-snippets`, `vim-react-native-snippets`, `vim-javascript-snippets`)
- [x] Removed duplicate `let mapleader` — now set via `vim.g.mapleader` before `lazy.setup()`
- **Why:** lazy.nvim lazy-loads language plugins by filetype, cutting startup time for non-language files. Lockfile (`lazy-lock.json`) pins exact plugin versions for reproducible installs across machines.
- **Key difference from vim-plug:** `build =` replaces `do:`, `branch =` replaces `{'branch': '...'}`, `ft =` replaces `{'for': '...'}`, `cmd =` lazy-loads on a command.

### 20. Fix deprecated lspconfig API (nvim-lspconfig v2+)
- [x] Replaced `require('lspconfig').server.setup({})` with `vim.lsp.config('server', {})` + `vim.lsp.enable('server')` in both vimrc and `init.lua`
- [x] Discovered `init.lua` had its own lspconfig calls including `ts_ls` (TypeScript) not in vimrc — preserved and migrated
- **Why:** nvim-lspconfig v2 deprecated the `require('lspconfig')` framework in favor of nvim's built-in `vim.lsp.config`. Will be removed in v3.0.0.

### 21. Fix gruvbox not loading with lazy.nvim
- [x] Added `lazy = false` and `priority = 1000` to gruvbox plugin spec
- [x] Added `config` function that sets `vim.o.background = "dark"` and calls `vim.cmd.colorscheme("gruvbox")`
- [x] Fixed `set background=light` → `set background=dark` (was overriding thematic's dark default)
- **Why:** lazy.nvim defers plugin loading by default. Colorscheme plugins must set `priority = 1000` and `lazy = false` to load before all other plugins, otherwise the theme isn't applied on startup.

### 22. Sync nvim theme with macOS dark/light mode
- [x] Added `sync_macos_appearance()` lua function that reads macOS appearance via `defaults read -g AppleInterfaceStyle`
- [x] Called on startup to set initial background
- [x] Wired to `FocusGained` autocmd so nvim updates when you switch back to it after toggling macOS appearance
- **Why:** gruvbox supports both dark and light variants via `vim.o.background`. macOS stores the current appearance in `AppleInterfaceStyle` — `"Dark"` when dark mode is on, empty/missing when light. Reading it with `defaults read` is instant and requires no plugins.
- **How to toggle:** Use a macOS Shortcut (Shortcuts app → New → Toggle Dark Mode → assign keyboard shortcut). iTerm2 follows macOS appearance automatically if "Use different colors for light/dark mode" is enabled in Profiles → Colors. nvim follows on next `FocusGained`.
- **Manual nvim toggle:** `<Space>bg` toggles between dark and light independently of macOS appearance.

---

## Lessons Learned

### nvim-cmp migration
- `quangnguyen30192/cmp-nvim-ultisnips` is broken on nvim 0.9+ — calling `UltiSnips#SnippetsInCurrentScope` returns userdata instead of a table. No well-maintained replacement exists. Removed UltiSnips entirely; re-add with `LuaSnip` when snippets are needed again.
- `nvim --headless "+PlugInstall"` will error on lua blocks that `require` the plugins being installed — this is expected. The error is transient; check `ls ~/.local/share/nvim/plugged/` to confirm plugins installed, then verify with a plain `nvim --headless "+qa"`.
- deoplete and ncm2 both needed `pynvim` via a Python host. After removing them, `g:python3_host_prog` and the nvim venv are no longer needed.

### telescope migration
- Denite keymaps map 1:1 to telescope: `;` buffers, `<leader>ff` files, `<leader>g` live grep, `<leader>j` grep word under cursor. (`<leader>r` was kept for repeat last command / rspec re-run)
- telescope requires `nvim-lua/plenary.nvim` as a dependency — must be declared as a plugin alongside it.
- `file_ignore_patterns` in telescope setup prevents `node_modules` and `.git/` from appearing in file search results.

### Telescope keymaps (inside the picker window)
- `<C-n>` / `<C-p>` — navigate results
- `<CR>` — open selected
- `<C-v>` — open in vertical split
- `<C-x>` — open in horizontal split
- `<C-t>` — open in new tab
- `<Esc>` — close

---

## Recommended Next Steps

### vimrc

#### 24. Remove vim-thematic and its config
- Remove `reedes/vim-thematic` plugin and all `g:thematic#theme_name`, `g:thematic#defaults`, `g:thematic#themes` config blocks
- **Why:** Thematic was a multi-theme switcher. gruvbox dark/light toggling is now handled by `sync_macos_appearance()` + `<Leader>bg`. Thematic adds dead weight and its `airline-theme: 'serene'` default conflicts with the `gruvbox` airline theme.

#### 25. Remove dead UltiSnips config remnant (vimrc)
- Remove `let g:UltiSnipsEditSplit="vertical"` (line ~481)
- **Why:** UltiSnips was removed in item 17. This setting is now dead code.

#### 26. Consolidate duplicate JavaScript syntax plugins
- Remove `othree/yajs.vim` and `isRuslan/vim-es6` — keep `pangloss/vim-javascript`
- **Why:** All three provide JS syntax highlighting. `pangloss/vim-javascript` is actively maintained and most compatible with tree-sitter. `yajs` and `vim-es6` are largely unmaintained and conflict with it.
- **Alternative:** Replace all three with `nvim-treesitter` for JS/TS syntax — more accurate, maintained, and used by the modern nvim ecosystem.

#### 27. Remove unused colorscheme bundles
- Remove `flazz/vim-colorschemes`, `daylerees/colour-schemes`, `jacoborus/tender.vim`
- **Why:** gruvbox is the active colorscheme. These are large bundles (hundreds of themes each) that slow lazy.nvim sync with no benefit.

#### 28. Move nvim-dap-python setup inside ft=python lazy load
- Move `require("dap-python").setup(...)` into the `nvim-dap-python` plugin spec's `config` function
- **Why:** Currently the setup call runs at startup for all files even though the plugin has `ft = "python"`. Defeats the lazy loading.

#### 29. Replace Townk/vim-autoclose with nvim-autopairs
- Swap `Townk/vim-autoclose` for `windwp/nvim-autopairs`
- **Why:** `vim-autoclose` is unmaintained and has edge cases with nvim-cmp. `nvim-autopairs` integrates directly with nvim-cmp (auto-confirms on `<CR>`) and is lua-native.

---

### zshrc

#### 30. Fix `en` alias to point to init.lua (zshrc)
- Change `alias en='nvim ~/.config/nvim/init.vim'` → `alias en='nvim ~/.config/nvim/init.lua'`
- **Why:** init.vim no longer exists — the config was migrated to init.lua.

#### 31. Fix Intel-era Python/Android paths (zshrc)
- Change `VIRTUALENV_PYTHON` and `VIRTUALENVWRAPPER_PYTHON` from `/usr/local/bin/python3` → `/opt/homebrew/bin/python3`
- Change `ANDROID_SDK_ROOT` and `ANDROID_HOME` from `/usr/local/share/android-sdk` → `/opt/homebrew/share/android-sdk` (or remove if Android dev is inactive)
- **Why:** `/usr/local` is the Intel Homebrew prefix. On M1 Homebrew installs to `/opt/homebrew`. These paths silently fail on this machine.

#### 32. Fix hardcoded CLOUDSDK_PYTHON version (zshrc)
- Change `export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11` → `/opt/homebrew/bin/python3`
- **Why:** Hardcoded minor version breaks when Python is upgraded via Homebrew (e.g., 3.11 → 3.12).

#### 33. Remove Linux-only alert alias (zshrc)
- Remove `alias alert='notify-send ...'`
- **Why:** `notify-send` is a Linux desktop notification tool. Not available on macOS — the alias silently does nothing here.

#### 34. Remove large oh-my-zsh template comment block at top of zshrc (lines 11–78)
- Remove the block of commented-out oh-my-zsh configuration options (`CASE_SENSITIVE`, `DISABLE_AUTO_UPDATE`, `UPDATE_ZSH_DAYS`, etc.)
- **Why:** Dead copy-paste from the oh-my-zsh template. antigen is used here, not oh-my-zsh directly. These options have no effect.

#### 35. Remove orphaned plugins= line (zshrc)
- Remove `plugins=(git rails yarn docker)` near the bottom of the file
- **Why:** This sets the oh-my-zsh `$plugins` variable, but oh-my-zsh is loaded via antigen (`antigen use oh-my-zsh`) which reads this variable only if set *before* `antigen apply`. It appears after `antigen apply`, so it's dead.

---

## Completed

- [x] Fix hardcoded `/usr/local/bin/python` path for nvim-dap-python → `/opt/homebrew/bin/python3`
- [x] Set `g:python3_host_prog` to nvim venv with pynvim (temporary fix, will be removed in item 6)
