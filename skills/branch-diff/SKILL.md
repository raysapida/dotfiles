---
name: branch-diff
description: Opens a tmux window comparing two git branches, with lazygit in diff mode on the left and the PR-style `git diff base...compare -- paths` on the right, optionally limited to paths. Use when the user runs /branch-diff, or asks to compare, diff or review two branches or worktrees side by side in tmux or lazygit.
---

# branch-diff

Arguments: `<base> <compare> [paths...]`, e.g. `/branch-diff production feature/notifications app/controllers`.

## Run it

Run the script from the repo (any checkout or worktree of it), passing the arguments through:

```bash
~/.agents/skills/branch-diff/scripts/branch-diff.sh <base> <compare> [paths...]
```

- Add `-C <dir>` if the current directory isn't inside the repo.
- Add `--background` only if the user asks not to switch windows; by default it switches the
  user's tmux view to the new window.
- If the user gave one branch, use it as `<compare>` and ask which base they want (suggest the
  repo's default branch, e.g. `production` or `main`).
- If they named directories instead of branches, use `git -C <dir> branch --show-current` to get
  each branch.

Then report the script's output in a couple of lines: the window name, how to reach it
(`prefix` + `w` lists windows), and any `warning:` line verbatim.

## What the user sees

- **Left, lazygit:** opened in the worktree that has `<compare>` checked out (or the current
  checkout), in diff mode with `<base>` as the base and `<compare>` selected. Diff mode compares
  `<base>` to *whatever is selected*: on a commit it shows base → that commit's tree (cumulative),
  not the commit's own change. `W` → Exit diff mode to see single commits; `Esc` goes back a level.
- **Right, `less` (or `delta` if installed):** `git diff base...compare -- paths`, only the changes
  made on `<compare>` since it split from `<base>`, the same as a pull request. lazygit compares the
  two tips (`base compare`), which differs once `<base>` has moved on.
- The window is named `diff-<compare>[-<paths>]` (e.g. `diff-feature-notifications-app-models`);
  running it again with the same branch and paths replaces it, other path sets get their own window.
  Quitting both programs closes it.

## Rules

- Never send keystrokes to the lazygit pane yourself. The script checks every screen before
  each key; free text typed into lazygit's branch list runs commands (`p` pull, `d` delete…).
- If the script warns that lazygit stopped early, the right pane is still correct. Tell the user;
  don't retry in a loop.
- It must run inside tmux. If `$TMUX` is empty, give the user the command to run from a tmux
  pane instead.
- Don't kill or reuse windows the user made; the script only replaces its own `diff-*` window.
