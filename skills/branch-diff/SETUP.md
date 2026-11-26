# Setting up the branch-diff skill (/branch-diff) on a new machine

Generated 2026-11-19 from the skill's files in `~/.agents/skills/branch-diff/`. The install
blocks contain every file verbatim, so this guide is enough to recreate the skill elsewhere.
Regenerate it with `~/.agents/skills/branch-diff/scripts/make_setup_doc.sh` after changing the skill.

## What it does

`/branch-diff <base> <compare> [paths...]`, e.g. `/branch-diff production feature/notifications app/controllers`,
opens a tmux window named `diff-<compare>`:

- **Left: lazygit in diff mode**, opened in the worktree that has `<compare>` checked out (or the
  current checkout), with `<base>` as the diff base and `<compare>` selected. Diff mode compares the base
  to *whatever is selected*: on a commit it shows base → that commit's tree (cumulative), not the
  commit's own change. `W` → Exit diff mode to see single commits; `Esc` goes back one level.
- **Right: `git diff base...compare -- paths`** in `less -R` (or `delta` if installed): only the
  changes made on `<compare>` since it split from `<base>`, the same as a pull request. lazygit
  itself compares the two tips (`git diff base compare`), which differs once the base moves on.

Works from Claude Code, opencode and Codex. The name isn't `/diff` because Claude Code and Codex
both have a built-in `/diff` (uncommitted changes) that would shadow it.

## Requirements

- tmux (the agent must be running inside a tmux pane), git, lazygit (tested with 0.55.1)
- Optional: `brew install git-delta` for a syntax-highlighted right pane

## How it drives lazygit (and why it's careful)

lazygit has no command-line flag for diff mode, so the script types keys into the pane with
`tmux send-keys`, confirming each screen with `tmux capture-pane` before the next key:

1. `W` opens the Diffing menu → `/` filters it to "Enter ref to diff" → `Enter` → type `<base>`.
   The menu is chosen by text, not position: branches without an upstream have one fewer item,
   and an early version's `j j Enter` hit Cancel.
2. If `<compare>` isn't the checked-out branch, `/` filters the branch list by its name, then
   `j` steps down until the **highlighted row** (background `ESC[44m`) names it exactly. A
   filter for `production` also matches `example-production`, listed first. Don't read the
   "Showing output for" line: it wraps, so `fix/x` looks like a match for `fix/x-updates`.
3. On any screen that doesn't appear, it presses `Esc` and stops with a warning. Free text must
   never reach the branch list: letters there are commands (`p` pull, `r` rebase, `d` delete,
   `n` new branch).

## Directory layout

```
~/.agents/skills/branch-diff/          # canonical copy (Codex reads ~/.agents/skills)
├── SKILL.md                           # agent instructions
├── SETUP.md                           # this guide (generated)
└── scripts/
    ├── branch-diff.sh                 # does the work
    └── make_setup_doc.sh              # regenerates SETUP.md
~/.claude/skills/branch-diff -> ../../.agents/skills/branch-diff   # Claude Code and opencode
~/.config/opencode/command/branch-diff.md                         # makes /branch-diff a slash command in opencode
```

| Tool | Where it finds the skill | How to invoke |
|---|---|---|
| Claude Code | `~/.claude/skills/branch-diff` (symlink) | `/branch-diff production feature/x` |
| opencode | `~/.claude/skills/` + `~/.config/opencode/command/branch-diff.md` | `/branch-diff production feature/x` |
| Codex | `~/.agents/skills/branch-diff` | `$branch-diff production feature/x` (or pick it from `/skills`) |

## Install

Run these blocks in order in a shell.

### `SKILL.md`

````bash
mkdir -p "$HOME/.agents/skills/branch-diff"
cat > "$HOME/.agents/skills/branch-diff/SKILL.md" <<'BRANCH_DIFF_EOF'
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
BRANCH_DIFF_EOF
````

### `scripts/branch-diff.sh`

````bash
mkdir -p "$HOME/.agents/skills/branch-diff/scripts"
cat > "$HOME/.agents/skills/branch-diff/scripts/branch-diff.sh" <<'BRANCH_DIFF_EOF'
#!/usr/bin/env bash
# branch-diff.sh [-C <dir>] [--background] <base> <compare> [paths...]
#
# Opens a tmux window named diff-<compare>:
#   left:  lazygit in diff mode (git diff <base> <selected branch>), compare branch selected
#   right: git diff <base>...<compare> -- <paths>   (the PR view: only compare's own changes)
#
# lazygit has no CLI flag for diff mode, so this drives it with tmux send-keys. Every key is
# sent only after the screen it belongs to is confirmed, and on any miss it backs out with
# Escape. Never type free text unless a prompt or filter is confirmed open: stray letters in
# lazygit's branch list are commands (p pull, r rebase, d delete, n new branch).
set -euo pipefail

usage() { echo "usage: branch-diff.sh [-C <dir>] [--background] <base> <compare> [paths...]" >&2; exit 2; }

dir=$PWD background=0
while [ $# -gt 0 ]; do
  case $1 in
    -C) dir=$2; shift 2 ;;
    --background) background=1; shift ;;
    -h|--help) usage ;;
    *) break ;;
  esac
done
[ $# -ge 2 ] || usage
base=$1 compare=$2; shift 2
paths=("$@")

for tool in git tmux lazygit; do
  command -v "$tool" >/dev/null || { echo "error: $tool is not installed" >&2; exit 1; }
done
[ -n "${TMUX:-}" ] || { echo "error: not inside tmux; run it from a tmux pane" >&2; exit 1; }

repo=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "error: $dir is not in a git repo" >&2; exit 1; }
for ref in "$base" "$compare"; do
  git -C "$repo" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || { echo "error: unknown ref '$ref'" >&2; exit 1; }
done

# Open lazygit in the worktree that has <compare> checked out, if any (its branch is listed
# first, so it starts selected); otherwise in this checkout, and select it with a filter.
lgdir=$repo
while read -r key value; do
  case $key in
    worktree) wt=$value ;;
    branch) [ "$value" = "refs/heads/$compare" ] && lgdir=$wt ;;
  esac
done < <(git -C "$repo" worktree list --porcelain)
head_branch=$(git -C "$lgdir" branch --show-current)
is_local=0; git -C "$repo" show-ref --verify --quiet "refs/heads/$compare" && is_local=1

session=$(tmux display-message -p -t "${TMUX_PANE:-}" '#S')
# One window per branch + paths, so different path sets can be open side by side.
slug() { printf %s "$*" | tr -c 'A-Za-z0-9_.-' '-' | sed 's/--*/-/g; s/^-//; s/-$//'; }
name="diff-$(slug "$compare")"
[ ${#paths[@]} -gt 0 ] && name="$name-$(slug "${paths[*]}" | cut -c1-40)"
target="$session:=$name"
tmux kill-window -t "$target" 2>/dev/null || true
tmux new-window -d -t "$session:" -n "$name" -c "$lgdir" "lazygit branch"
lg="$target.{top-left}"

screen() { tmux capture-pane -p -t "$lg"; }
wait_for() { for _ in $(seq 1 50); do screen | grep -qF -- "$1" && return 0; sleep 0.2; done; return 1; }
warn=""
step() {
  if ! wait_for "$1"; then
    warn="lazygit stopped before diff mode (never saw '$1'); the right pane is still correct"
    tmux send-keys -t "$lg" Escape Escape Escape
    return 1
  fi
}
# The selected branch: lazygit paints the selected row's background blue (ESC[44m); the branch
# name follows the 8-char sha. (Don't parse the "Showing output for" line: it wraps onto a second
# row, so a prefix like fix/parallel-active-storage looks like a match for ...-updates.)
selected() {
  tmux capture-pane -e -p -t "$lg" | LC_ALL=C grep -a -m1 $'\e\\[44m' |
    LC_ALL=C sed $'s/\e\\[[0-9;]*m//g' | LC_ALL=C grep -aoE '[0-9a-f]{8} +[^ ]+' | head -1 | awk '{print $2}'
}

# 1. Diff mode with <base> as the base: W -> filter the menu to "Enter ref to diff" -> type it.
#    (Menu position varies: branches without an upstream have one fewer item.)
step "Local branches" &&
  { tmux send-keys -t "$lg" W; step "Enter ref to diff"; } &&
  { tmux send-keys -t "$lg" /; step "Filter:"; } &&
  { tmux send-keys -t "$lg" -l "ref to diff"; tmux send-keys -t "$lg" Enter; step "1 of 1"; } &&
  { tmux send-keys -t "$lg" Enter; step "Enter ref:"; } &&
  { tmux send-keys -t "$lg" -l "$base"; tmux send-keys -t "$lg" Enter; step "git diff --stat -p $base "; } &&
  if [ "$head_branch" != "$compare" ]; then
    if [ $is_local = 0 ]; then
      warn="'$compare' isn't a local branch, so lazygit shows $base vs $head_branch; the right pane is correct"
    else
      # 2. Select <compare>: filter the branch list, then step down until the status line names it
      #    (a filter like "production" also matches example-production, listed first).
      tmux send-keys -t "$lg" /; step "Filter:" &&
        { tmux send-keys -t "$lg" -l "$compare"; tmux send-keys -t "$lg" Enter; sleep 0.5
          found=0
          for _ in $(seq 1 30); do
            [ "$(selected)" = "$compare" ] && { found=1; break; }
            tmux send-keys -t "$lg" j; sleep 0.3
          done
          [ $found = 1 ] || warn="couldn't select '$compare' in lazygit; select it by hand (diff mode is on)"; }
    fi
  fi || true

pager="less -R"; color="--color=always"
command -v delta >/dev/null && { pager="delta --paging=always"; color=""; }
quoted=""; [ ${#paths[@]} -gt 0 ] && quoted=$(printf ' %q' "${paths[@]}")
tmux split-window -h -d -t "$target" -c "$repo" \
  "git diff $color $(printf %q "$base...$compare") --$quoted | $pager"
[ $background = 1 ] || tmux select-window -t "$target"

echo "opened window '$name' in session '$session'"
echo "  left:  lazygit in $lgdir, diff mode vs $base"
echo "  right: git diff $base...$compare --$quoted"
[ -z "$warn" ] || echo "  warning: $warn"
BRANCH_DIFF_EOF
````

### `scripts/make_setup_doc.sh`

````bash
mkdir -p "$HOME/.agents/skills/branch-diff/scripts"
cat > "$HOME/.agents/skills/branch-diff/scripts/make_setup_doc.sh" <<'BRANCH_DIFF_EOF'
#!/usr/bin/env bash
# Regenerates ../SETUP.md: a self-contained guide (every file verbatim) for installing the
# branch-diff skill on another machine. Rerun after changing any skill file, then re-save
# SETUP.md to the knowledge base (same path updates the same document).
set -euo pipefail
skill=$(cd "$(dirname "$0")/.." && pwd)
out=$skill/SETUP.md
oc_cmd=$HOME/.config/opencode/command/branch-diff.md

embed() { # embed <title> <install path> <file>; 4-backtick fences because SKILL.md contains ``` blocks
  printf '### `%s`\n\n````bash\nmkdir -p "%s"\ncat > "%s" <<'"'"'BRANCH_DIFF_EOF'"'"'\n' "$1" "$(dirname "$2")" "$2"
  cat "$3"
  printf 'BRANCH_DIFF_EOF\n````\n\n'
}

{
cat <<EOF
# Setting up the branch-diff skill (/branch-diff) on a new machine

Generated $(date +%Y-%m-%d) from the skill's files in \`~/.agents/skills/branch-diff/\`. The install
blocks contain every file verbatim, so this guide is enough to recreate the skill elsewhere.
Regenerate it with \`~/.agents/skills/branch-diff/scripts/make_setup_doc.sh\` after changing the skill.

## What it does

\`/branch-diff <base> <compare> [paths...]\`, e.g. \`/branch-diff production feature/notifications app/controllers\`,
opens a tmux window named \`diff-<compare>\`:

- **Left: lazygit in diff mode**, opened in the worktree that has \`<compare>\` checked out (or the
  current checkout), with \`<base>\` as the diff base and \`<compare>\` selected. Diff mode compares the base
  to *whatever is selected*: on a commit it shows base → that commit's tree (cumulative), not the
  commit's own change. \`W\` → Exit diff mode to see single commits; \`Esc\` goes back one level.
- **Right: \`git diff base...compare -- paths\`** in \`less -R\` (or \`delta\` if installed): only the
  changes made on \`<compare>\` since it split from \`<base>\`, the same as a pull request. lazygit
  itself compares the two tips (\`git diff base compare\`), which differs once the base moves on.

Works from Claude Code, opencode and Codex. The name isn't \`/diff\` because Claude Code and Codex
both have a built-in \`/diff\` (uncommitted changes) that would shadow it.

## Requirements

- tmux (the agent must be running inside a tmux pane), git, lazygit (tested with 0.55.1)
- Optional: \`brew install git-delta\` for a syntax-highlighted right pane

## How it drives lazygit (and why it's careful)

lazygit has no command-line flag for diff mode, so the script types keys into the pane with
\`tmux send-keys\`, confirming each screen with \`tmux capture-pane\` before the next key:

1. \`W\` opens the Diffing menu → \`/\` filters it to "Enter ref to diff" → \`Enter\` → type \`<base>\`.
   The menu is chosen by text, not position: branches without an upstream have one fewer item,
   and an early version's \`j j Enter\` hit Cancel.
2. If \`<compare>\` isn't the checked-out branch, \`/\` filters the branch list by its name, then
   \`j\` steps down until the **highlighted row** (background \`ESC[44m\`) names it exactly. A
   filter for \`production\` also matches \`example-production\`, listed first. Don't read the
   "Showing output for" line: it wraps, so \`fix/x\` looks like a match for \`fix/x-updates\`.
3. On any screen that doesn't appear, it presses \`Esc\` and stops with a warning. Free text must
   never reach the branch list: letters there are commands (\`p\` pull, \`r\` rebase, \`d\` delete,
   \`n\` new branch).

## Directory layout

\`\`\`
~/.agents/skills/branch-diff/          # canonical copy (Codex reads ~/.agents/skills)
├── SKILL.md                           # agent instructions
├── SETUP.md                           # this guide (generated)
└── scripts/
    ├── branch-diff.sh                 # does the work
    └── make_setup_doc.sh              # regenerates SETUP.md
~/.claude/skills/branch-diff -> ../../.agents/skills/branch-diff   # Claude Code and opencode
~/.config/opencode/command/branch-diff.md                         # makes /branch-diff a slash command in opencode
\`\`\`

| Tool | Where it finds the skill | How to invoke |
|---|---|---|
| Claude Code | \`~/.claude/skills/branch-diff\` (symlink) | \`/branch-diff production feature/x\` |
| opencode | \`~/.claude/skills/\` + \`~/.config/opencode/command/branch-diff.md\` | \`/branch-diff production feature/x\` |
| Codex | \`~/.agents/skills/branch-diff\` | \`\$branch-diff production feature/x\` (or pick it from \`/skills\`) |

## Install

Run these blocks in order in a shell.

EOF
embed "SKILL.md" '$HOME/.agents/skills/branch-diff/SKILL.md' "$skill/SKILL.md"
embed "scripts/branch-diff.sh" '$HOME/.agents/skills/branch-diff/scripts/branch-diff.sh' "$skill/scripts/branch-diff.sh"
embed "scripts/make_setup_doc.sh" '$HOME/.agents/skills/branch-diff/scripts/make_setup_doc.sh' "$skill/scripts/make_setup_doc.sh"
embed "opencode command" '$HOME/.config/opencode/command/branch-diff.md' "$oc_cmd"
cat <<'EOF'
### Permissions and links

```bash
chmod +x ~/.agents/skills/branch-diff/scripts/*.sh
mkdir -p ~/.claude/skills
ln -sfn ../../.agents/skills/branch-diff ~/.claude/skills/branch-diff
```

The opencode command file names `/Users/raymond/...` as a fallback path; change it if the home
directory differs.

## Verify

```bash
# From a tmux pane inside any git repo with two local branches:
~/.agents/skills/branch-diff/scripts/branch-diff.sh --background main some-branch
tmux list-windows | grep diff-         # window exists with 2 panes
```

Then check each agent sees it, e.g. `codex exec --sandbox read-only 'Is a skill named "branch-diff"
available? yes/no' < /dev/null` (stdin must be closed or `codex exec` waits for input) and the same
question via `opencode run`.
EOF
} > "$out"
echo "wrote $out"
BRANCH_DIFF_EOF
````

### `opencode command`

````bash
mkdir -p "$HOME/.config/opencode/command"
cat > "$HOME/.config/opencode/command/branch-diff.md" <<'BRANCH_DIFF_EOF'
---
description: Compare two git branches in a new tmux window (lazygit diff mode + git diff base...compare).
---

Load the `branch-diff` skill (from ~/.agents/skills/branch-diff/SKILL.md) and execute it now, following its full instructions.

Invocation arguments: $ARGUMENTS

If the skill content is unavailable, read `/Users/raymond/.agents/skills/branch-diff/SKILL.md` directly and follow it.
BRANCH_DIFF_EOF
````

### Permissions and links

```bash
chmod +x ~/.agents/skills/branch-diff/scripts/*.sh
mkdir -p ~/.claude/skills
ln -sfn ../../.agents/skills/branch-diff ~/.claude/skills/branch-diff
```

The opencode command file names `/Users/raymond/...` as a fallback path; change it if the home
directory differs.

## Verify

```bash
# From a tmux pane inside any git repo with two local branches:
~/.agents/skills/branch-diff/scripts/branch-diff.sh --background main some-branch
tmux list-windows | grep diff-         # window exists with 2 panes
```

Then check each agent sees it, e.g. `codex exec --sandbox read-only 'Is a skill named "branch-diff"
available? yes/no' < /dev/null` (stdin must be closed or `codex exec` waits for input) and the same
question via `opencode run`.
