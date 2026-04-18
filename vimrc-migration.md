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

## Completed

- [x] Fix hardcoded `/usr/local/bin/python` path for nvim-dap-python → `/opt/homebrew/bin/python3`
- [x] Set `g:python3_host_prog` to nvim venv with pynvim (temporary fix, will be removed in item 6)
