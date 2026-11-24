# Dotfiles Configuration Review

## vimrc Issues

### 1. Recursive Mappings (`map` instead of `nnoremap`)
**Lines:** 381, 391-393, 404-416, 421, 487, 515

`map` is recursive and applies to all modes (normal, visual, operator-pending). This can cause unexpected behavior, recursion, and slower execution. Should be `nnoremap` for normal mode mappings.

### 2. Recursive Mode-Specific Mappings (`ino`/`cno`/`vno`)
**Lines:** 399-401

```vim
ino jk <esc>
cno jk <c-c>
vno v <esc>
```

Should be `inoremap`, `cnoremap`, and `vnoremap` to prevent recursive expansion.

### 3. Global Spell Checking
**Line:** 378

```vim
set spell
set complete+=kspell
```

Spell checking is enabled for *all* filetypes, including code files. This will flag variable names, function names, and code as misspelled. Should be limited to markdown/text via an autocmd.

### 4. Clipboard Logic Broken on macOS
**Lines:** 276-288

```vim
if $TMUX == ''
  set clipboard+=unnamedplus
endif

if has("unix")
  let s:uname = system("uname")
  if s:uname == "Darwin\n"
    set clipboard=unnamedplus
  endif
endif
```

The macOS block unconditionally overrides the `$TMUX` guard, so the tmux check does nothing on macOS. The macOS block should also be wrapped in the `if $TMUX == ''` condition.

### 5. Unconditional `csvview.setup()` Call
**Line:** 191

```vim
lua require('csvview').setup()
```

The plugin is lazy-loaded with `ft = "csv"`, but `setup()` runs on every startup regardless of filetype. This could error if the plugin hasn't been loaded yet. Should be moved into the plugin's `config` function or guarded.

### 6. Hardcoded Python Path for DAP
**Line:** 152

```lua
require("dap-python").setup("/opt/homebrew/bin/python3")
```

Breaks if using pyenv, asdf, or a different Python installation. Should use `vim.fn.exepath("python3")` or be configurable.

---

## tmux.conf Issues

### 7. Global `bind -n` Key Conflicts
**Lines:** 58-66, 72-82

Shift/Ctrl arrow keys and F1-F12 are bound *without* the prefix key. These frequently conflict with:
- Terminal emulator shortcuts
- macOS system shortcuts (F1-F12 are often brightness/volume/media keys)
- IDE/editor shortcuts

### 8. External Dependency in Status Bar
**Line:** 50

```tmux
set -g status-right '#(tmux-spotify-info) #{battery_percentage} ...'
```

`tmux-spotify-info` is not installed via tpm and may not exist on the system, causing status bar errors or slow rendering when the command fails.

---

## zshrc Issues

### 9. Intel Homebrew Paths on Apple Silicon
**Lines:** 164, 166

```zsh
export PATH="/usr/local/opt/curl/bin:$PATH"
export VIRTUALENV_PYTHON=/usr/local/bin/python3
```

`/usr/local/` is the Intel Homebrew prefix. On M1/M2/M3 Macs, Homebrew uses `/opt/homebrew`. These paths will silently fail or point to outdated system binaries.

### 10. Hardcoded Python Version for GCloud
**Line:** 211

```zsh
export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11
```

Homebrew updates Python frequently. When Python 3.12+ becomes the default, this symlink will break. Should use `python3` without the minor version.

### 11. Linux-Only `alert` Alias
**Line:** 116

```zsh
alias alert='notify-send --urgency=low ...'
```

`notify-send` is a Linux utility (libnotify). It doesn't exist on macOS. Should use `osascript` for macOS notifications or be guarded by OS detection.

### 12. Unused `plugins` Array
**Line:** 209

```zsh
plugins=(git rails yarn docker)
```

Antigen doesn't read the oh-my-zsh `plugins` array. It uses `antigen bundle` instead (which is already done on lines 141-148). This line does nothing and can be removed.

### 13. Antigen Bundle Order
**Lines:** 136, 139

```zsh
antigen bundle robbyrussell/oh-my-zsh
...
antigen use oh-my-zsh
```

`antigen use oh-my-zsh` should come *before* any `antigen bundle` calls that rely on oh-my-zsh. The current order may cause bundles to load before oh-my-zsh is initialized.
