# vim-gutentags

Plugin: [ludovicchabant/vim-gutentags](https://github.com/ludovicchabant/vim-gutentags)

Automatically generates and updates a `tags` file in the background as you edit. No manual commands needed — gutentags detects your project root, runs ctags, and keeps the tags file current.

## Requirements

Install Universal Ctags (replaces the limited BSD ctags bundled with Xcode):

```sh
brew install universal-ctags
```

## How It Works

When you open a file, gutentags walks up the directory tree looking for a project root marker (`.git`, `Gemfile`, `Rakefile`). Once found, it runs ctags from that root and writes a `tags` file. It re-runs ctags incrementally whenever you save a file.

## Navigation Commands

These are built into Neovim — no plugin mappings needed.

| Key / Command | Action |
|---|---|
| `Ctrl-]` | Jump to definition of word under cursor |
| `Ctrl-t` | Pop back to previous position (tag stack) |
| `g]` | List all tags matching word under cursor |
| `Ctrl-w ]` | Open definition in a horizontal split |
| `Ctrl-w }` | Open definition in preview window |
| `:ts <name>` | List all tags matching `<name>` |
| `:tn` / `:tp` | Next / previous tag match |
| `:tags` | Show the full tag jump stack |

## Tagbar Integration

Tagbar (bound to `<F8>`) reads the same tags file and shows a sidebar of all symbols in the current file — functions, classes, variables — with jump-to support.

## Telescope Integration

| Command | Action |
|---|---|
| `:Telescope tags` | Fuzzy search all tags across the project |
| `:Telescope current_buffer_tags` | Fuzzy search tags in the current file only |

## Configuration (current dotfiles setup)

```vim
vim.g.gutentags_ctags_executable = "ctags"
vim.g.gutentags_project_root = { ".git", "Gemfile", "Rakefile" }
vim.g.gutentags_ctags_extra_args = { "--tag-relative=yes", "--fields=+ailmnS" }
vim.g.gutentags_file_list_command = { markers = { [".git"] = "git ls-files" } }
```

- `--tag-relative=yes` — paths in the tags file are relative to the project root
- `--fields=+ailmnS` — captures access level, inheritance, line number, scope, and signature
- `gutentags_file_list_command` — in git roots, only git-tracked files are indexed, so gitignored `node_modules`, venvs, `Pods`, etc. are skipped. Roots with only a `Gemfile`/`Rakefile` fall back to `ctags -R`.

`ctags.d/exclude.ctags` (symlinked to `~/.ctags.d/` by rcm) excludes `node_modules`, `.venv*`, `venv`, `Pods`, `build`, `graphify-out` and `.git` for every ctags run. Without these two settings, some project tags files grew past 1 GB.

## Useful Status Commands

| Command | Action |
|---|---|
| `:GutentagsUpdate` | Manually trigger a tags regeneration |
| `:GutentagsToggleEnabled` | Pause/resume auto-generation |
| `:echo gutentags#statusline()` | Show current gutentags status |

## .gitignore

Add the tags file to your repo's `.gitignore`:

```
tags
```

## Finding Callers (tags limitation)

Tags only index *definitions* — they can't find all the places a function is *called*. For that, use:

- `<leader>g` — Telescope live grep (search project-wide)
- `\` — Ag search (Silver Searcher)
