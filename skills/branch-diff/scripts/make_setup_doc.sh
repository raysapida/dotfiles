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
