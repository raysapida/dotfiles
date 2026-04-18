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

## Lessons Learned

### nvim-cmp migration
- `quangnguyen30192/cmp-nvim-ultisnips` is broken on nvim 0.9+ — calling `UltiSnips#SnippetsInCurrentScope` returns userdata instead of a table. No well-maintained replacement exists. UltiSnips still works via its own expand trigger (`<C-t>`), snippets just won't appear in the cmp popup.
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
