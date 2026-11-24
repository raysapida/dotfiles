#!/usr/bin/env bash
# Regenerates ../SETUP.md: how the docker-view skill was built, plus a self-contained install guide
# (every file verbatim) for another machine. Rerun after changing any skill file, then re-save
# SETUP.md to the knowledge base (same path updates the same document).
set -euo pipefail
skill=$(cd "$(dirname "$0")/.." && pwd)
out=$skill/SETUP.md
oc_cmd=$HOME/.config/opencode/command/docker-view.md

embed() { # embed <title> <install path> <file>; 4-backtick fences because SKILL.md contains ``` blocks
  printf '### `%s`\n\n````bash\nmkdir -p "%s"\ncat > "%s" <<'"'"'DOCKER_VIEW_EOF'"'"'\n' "$1" "$(dirname "$2")" "$2"
  cat "$3"
  printf 'DOCKER_VIEW_EOF\n````\n\n'
}

{
cat <<EOF
# The docker-view skill (/docker-view): how it was built and how to install it

Generated $(date +%Y-%m-%d) from the skill's files in \`~/.agents/skills/docker-view/\`. The install
blocks contain every file verbatim, so this guide is enough to recreate the skill elsewhere.
Regenerate it with \`~/.agents/skills/docker-view/scripts/make_setup_doc.sh\` after changing the skill.

## What it does

\`/docker-view [query]\`, e.g. \`/docker-view notification\`, opens a tmux window named
\`docker-<topic>\` running lazydocker for one git worktree's docker compose stack:

- **The query is fuzzy-matched** against each worktree's topic (folder name minus the \`<repo>-\`
  prefix), folder name and branch. \`notification\` → \`example-app-rails-notifications\`
  (\`feature/notifications\`), \`billing\` → \`example-app-rails-billing\`, \`production\` → the main checkout.
- **lazydocker starts in that worktree** with \`-f local_development/docker-compose.yml\`, so its
  Services panel holds only that project's services.
- **No query** opens the worktree whose code the stack's running containers have mounted (the
  one that started it), or else the current checkout.

Companion to \`/branch-diff\` (same layout, same tmux conventions). Works from Claude Code, opencode
and Codex.

## How it was built (2026-11-19)

### The constraint: lazydocker can't filter containers

The goal was "lazydocker, but only for the containers related to the worktrees". Research into the
lazydocker source settled what's possible with the installed **0.24.4** (Homebrew):

- Flags are only \`-f/--file\` (compose files), \`-c\`, \`-d\`. **No \`-p\` project flag** in 0.24.4.
- Run inside a compose project, the **Services** panel lists the services from
  \`docker compose config --services\`. The containers panel (called "Standalone Containers") shows
  *everything else on the machine*. Its filter only hides containers linked to a local service
  (\`gui.showAllContainers\`, default false). There's no project, label or name filter. The \`ignore\`
  config key exists but isn't applied.
- \`/\` filters a panel by hand, but nothing on the command line presets it.
- **"Stop all"/"remove all" act on every container**, including ones the panel hides: they iterate
  \`GetAllItems()\`, the unfiltered list.
- \`CONFIG_DIR\` sets a separate config dir per run. Not needed in the end.
- lazydocker's **main branch** (unreleased) adds project scoping (\`-p\`, a Projects panel, a
  \`ProjectName\` filter). Installing it from source was rejected as unreleased code.

Alternatives considered: build lazydocker from source for real filtering, or put a filtering Docker
API proxy in front of it via \`DOCKER_HOST\`. Both were rejected as too many extra pieces. Chosen:
scope with \`-f\`, and make the skill smart about *which worktree* to open.

### Why "which worktree" is the real problem

All example-app checkouts share one compose project (\`name: example-app\`, fixed container names
\`example-app_rails\`, \`example-app_postgres\`, \`example-app_mailcatcher\`). The rails service mounts \`\${PWD}:/app\`.
So only one worktree's stack runs at a time, and **up/restart/rebuild from lazydocker recreates
the stack with the code of whatever directory lazydocker runs in**. The skill therefore:

1. **Detects the owner**: it lists running containers labelled
   \`com.docker.compose.project=<project>\`, reads their bind-mount sources with
   \`docker inspect -f '{{range .Mounts}}...'\`, and matches them against the worktree paths.
2. **Opens lazydocker in the chosen worktree with \`PWD\` pinned** (\`export PWD=<worktree>; exec
   lazydocker ...\`). tmux's global environment can carry a stale \`PWD\`, and compose expands \`\${PWD}\`
   from the environment.
3. **Warns when they differ**: "the 'example-app' stack is running from X, not this worktree; up/restart/
   rebuild in this lazydocker would recreate it with the Y worktree's code".

The project name comes from the compose file's top-level \`name:\`, with compose's default (the
file's folder name) as the fallback.

### Fuzzy matching

Matching works in tiers, and the first tier with any match decides:

1. **exact**: topic, folder name, branch, or the branch without its prefix (\`feature/x\` → \`x\`).
2. **substring** of topic or branch, case-insensitive.
3. **\`fzf --filter\`** over "topic branch" (if fzf is installed), best score first.

One match opens it. Several matches print the candidates and **exit 3**, and the agent must ask
rather than guess. For example, \`2027\` matches two worktrees, and the typo \`verify\` gets three fzf hits
with the right one first. No match prints every worktree and exits 4. A path to a worktree folder
also works. Worktrees whose folder is missing (\`prunable\`) are skipped. The script is bash
3.2-safe (parallel indexed arrays, \`tr\` for lowercasing) even though Homebrew bash 5 is what runs.

### tmux behaviour

- The window is named \`docker-<topic>\` and **tagged with the window option \`@docker_view 1\`**.
  A rerun replaces only a tagged window. If the user has a window with the same name, the script
  refuses instead of killing it.
- \`--background\` opens it without switching.
- \`--print\` resolves the worktree and prints \`worktree= branch= topic= project= owner=\` without
  opening anything. It works outside tmux, and it was used to test matching.
- Run from the workspace folder (not a repo), it finds a checkout that has the compose file. It
  must not pick the first \`.git\` folder alphabetically, which here was the unrelated
  \`path-reports\`. In that case "this checkout" means the main checkout.

### Bugs found while testing

- \`git rev-parse --git-common-dir\` returns \`.git\` *relative to the cwd*, not to \`-C\`. Use
  \`--path-format=absolute\`.
- The workspace fallback first picked \`path-reports\`, and with no query it then picked the
  alphabetically first worktree. Both are fixed as described above.

### How it was tested

- Matching: \`--print\` with \`notification\`, \`feature/notifications\`, \`production\`, \`reports\` (exact
  beats \`reports-nov\`), \`2027\` (ambiguous), \`billing\`, \`verify\` (fuzzy, ambiguous), \`xyzzy\` (none),
  a folder name, and no query, from both a worktree and the workspace folder.
- Owner detection and the window: a throwaway \`alpine\` container with
  \`--label com.docker.compose.project=example-app -v <worktree>:/app\`. The script reported that worktree
  as owner, warned when another worktree was opened, and lazydocker showed the Services panel
  (db, mailcatcher, rails, plus solid_queue on feature/notifications). A rerun replaced the window
  instead of adding a second one. The container and window were removed afterwards.

## Requirements

- tmux (the agent must be running inside a tmux pane), git, docker, lazydocker (tested with 0.24.4)
- Optional: fzf, for the fuzzy tier (substring and exact matching work without it)

## Directory layout

\`\`\`
~/.agents/skills/docker-view/          # canonical copy (Codex reads ~/.agents/skills)
├── SKILL.md                           # agent instructions
├── SETUP.md                           # this guide (generated)
└── scripts/
    ├── docker-view.sh                 # does the work
    └── make_setup_doc.sh              # regenerates SETUP.md
~/.claude/skills/docker-view -> ../../.agents/skills/docker-view   # Claude Code and opencode
~/.config/opencode/command/docker-view.md                         # makes /docker-view a slash command in opencode
\`\`\`

| Tool | Where it finds the skill | How to invoke |
|---|---|---|
| Claude Code | \`~/.claude/skills/docker-view\` (symlink) | \`/docker-view notification\` |
| opencode | \`~/.claude/skills/\` + \`~/.config/opencode/command/docker-view.md\` | \`/docker-view notification\` |
| Codex | \`~/.agents/skills/docker-view\` | \`\$docker-view notification\` (or pick it from \`/skills\`) |

## Install

Run these blocks in order in a shell.

EOF
embed "SKILL.md" '$HOME/.agents/skills/docker-view/SKILL.md' "$skill/SKILL.md"
embed "scripts/docker-view.sh" '$HOME/.agents/skills/docker-view/scripts/docker-view.sh' "$skill/scripts/docker-view.sh"
embed "scripts/make_setup_doc.sh" '$HOME/.agents/skills/docker-view/scripts/make_setup_doc.sh' "$skill/scripts/make_setup_doc.sh"
embed "opencode command" '$HOME/.config/opencode/command/docker-view.md' "$oc_cmd"
cat <<'EOF'
### Permissions and links

```bash
chmod +x ~/.agents/skills/docker-view/scripts/*.sh
mkdir -p ~/.claude/skills
ln -sfn ../../.agents/skills/docker-view ~/.claude/skills/docker-view
```

The opencode command file names `/Users/raysapida/...` as a fallback path. Change it if the home
directory differs (the other computer uses `/Users/raymond`).

## Verify

```bash
# Matching only, works anywhere inside the repo or workspace:
~/.agents/skills/docker-view/scripts/docker-view.sh --print notification
# From a tmux pane:
~/.agents/skills/docker-view/scripts/docker-view.sh --background notification
tmux list-windows -F '#W #{@docker_view}' | grep docker-    # docker-notifications 1
```

Then check each agent sees it, e.g. `codex exec --sandbox read-only 'Is a skill named "docker-view"
available? yes/no' < /dev/null` (stdin must be closed or `codex exec` waits for input) and the same
question via `opencode run`.
EOF
} > "$out"
echo "wrote $out"
