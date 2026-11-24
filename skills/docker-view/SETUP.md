# The docker-view skill (/docker-view): how it was built and how to install it

Generated 2026-11-19 from the skill's files in `~/.agents/skills/docker-view/`. The install
blocks contain every file verbatim, so this guide is enough to recreate the skill elsewhere.
Regenerate it with `~/.agents/skills/docker-view/scripts/make_setup_doc.sh` after changing the skill.

## What it does

`/docker-view [query]`, e.g. `/docker-view notification`, opens a tmux window named
`docker-<topic>` running lazydocker for one git worktree's docker compose stack:

- **The query is fuzzy-matched** against each worktree's topic (folder name minus the `<repo>-`
  prefix), folder name and branch. `notification` → `example-app-rails-notifications`
  (`feature/notifications`), `billing` → `example-app-rails-billing`, `production` → the main checkout.
- **lazydocker starts in that worktree** with `-f local_development/docker-compose.yml`, so its
  Services panel holds only that project's services.
- **No query** opens the worktree whose code the stack's running containers have mounted (the
  one that started it), or else the current checkout.

Companion to `/branch-diff` (same layout, same tmux conventions). Works from Claude Code, opencode
and Codex.

## How it was built (2026-11-19)

### The constraint: lazydocker can't filter containers

The goal was "lazydocker, but only for the containers related to the worktrees". Research into the
lazydocker source settled what's possible with the installed **0.24.4** (Homebrew):

- Flags are only `-f/--file` (compose files), `-c`, `-d`. **No `-p` project flag** in 0.24.4.
- Run inside a compose project, the **Services** panel lists the services from
  `docker compose config --services`. The containers panel (called "Standalone Containers") shows
  *everything else on the machine*. Its filter only hides containers linked to a local service
  (`gui.showAllContainers`, default false). There's no project, label or name filter. The `ignore`
  config key exists but isn't applied.
- `/` filters a panel by hand, but nothing on the command line presets it.
- **"Stop all"/"remove all" act on every container**, including ones the panel hides: they iterate
  `GetAllItems()`, the unfiltered list.
- `CONFIG_DIR` sets a separate config dir per run. Not needed in the end.
- lazydocker's **main branch** (unreleased) adds project scoping (`-p`, a Projects panel, a
  `ProjectName` filter). Installing it from source was rejected as unreleased code.

Alternatives considered: build lazydocker from source for real filtering, or put a filtering Docker
API proxy in front of it via `DOCKER_HOST`. Both were rejected as too many extra pieces. Chosen:
scope with `-f`, and make the skill smart about *which worktree* to open.

### Why "which worktree" is the real problem

All example-app checkouts share one compose project (`name: example-app`, fixed container names
`example-app_rails`, `example-app_postgres`, `example-app_mailcatcher`). The rails service mounts `${PWD}:/app`.
So only one worktree's stack runs at a time, and **up/restart/rebuild from lazydocker recreates
the stack with the code of whatever directory lazydocker runs in**. The skill therefore:

1. **Detects the owner**: it lists running containers labelled
   `com.docker.compose.project=<project>`, reads their bind-mount sources with
   `docker inspect -f '{{range .Mounts}}...'`, and matches them against the worktree paths.
2. **Opens lazydocker in the chosen worktree with `PWD` pinned** (`export PWD=<worktree>; exec
   lazydocker ...`). tmux's global environment can carry a stale `PWD`, and compose expands `${PWD}`
   from the environment.
3. **Warns when they differ**: "the 'example-app' stack is running from X, not this worktree; up/restart/
   rebuild in this lazydocker would recreate it with the Y worktree's code".

The project name comes from the compose file's top-level `name:`, with compose's default (the
file's folder name) as the fallback.

### Fuzzy matching

Matching works in tiers, and the first tier with any match decides:

1. **exact**: topic, folder name, branch, or the branch without its prefix (`feature/x` → `x`).
2. **substring** of topic or branch, case-insensitive.
3. **`fzf --filter`** over "topic branch" (if fzf is installed), best score first.

One match opens it. Several matches print the candidates and **exit 3**, and the agent must ask
rather than guess. For example, `2027` matches two worktrees, and the typo `verify` gets three fzf hits
with the right one first. No match prints every worktree and exits 4. A path to a worktree folder
also works. Worktrees whose folder is missing (`prunable`) are skipped. The script is bash
3.2-safe (parallel indexed arrays, `tr` for lowercasing) even though Homebrew bash 5 is what runs.

### tmux behaviour

- The window is named `docker-<topic>` and **tagged with the window option `@docker_view 1`**.
  A rerun replaces only a tagged window. If the user has a window with the same name, the script
  refuses instead of killing it.
- `--background` opens it without switching.
- `--print` resolves the worktree and prints `worktree= branch= topic= project= owner=` without
  opening anything. It works outside tmux, and it was used to test matching.
- Run from the workspace folder (not a repo), it finds a checkout that has the compose file. It
  must not pick the first `.git` folder alphabetically, which here was the unrelated
  `path-reports`. In that case "this checkout" means the main checkout.

### Bugs found while testing

- `git rev-parse --git-common-dir` returns `.git` *relative to the cwd*, not to `-C`. Use
  `--path-format=absolute`.
- The workspace fallback first picked `path-reports`, and with no query it then picked the
  alphabetically first worktree. Both are fixed as described above.

### How it was tested

- Matching: `--print` with `notification`, `feature/notifications`, `production`, `reports` (exact
  beats `reports-nov`), `2027` (ambiguous), `billing`, `verify` (fuzzy, ambiguous), `xyzzy` (none),
  a folder name, and no query, from both a worktree and the workspace folder.
- Owner detection and the window: a throwaway `alpine` container with
  `--label com.docker.compose.project=example-app -v <worktree>:/app`. The script reported that worktree
  as owner, warned when another worktree was opened, and lazydocker showed the Services panel
  (db, mailcatcher, rails, plus solid_queue on feature/notifications). A rerun replaced the window
  instead of adding a second one. The container and window were removed afterwards.

## Requirements

- tmux (the agent must be running inside a tmux pane), git, docker, lazydocker (tested with 0.24.4)
- Optional: fzf, for the fuzzy tier (substring and exact matching work without it)

## Directory layout

```
~/.agents/skills/docker-view/          # canonical copy (Codex reads ~/.agents/skills)
├── SKILL.md                           # agent instructions
├── SETUP.md                           # this guide (generated)
└── scripts/
    ├── docker-view.sh                 # does the work
    └── make_setup_doc.sh              # regenerates SETUP.md
~/.claude/skills/docker-view -> ../../.agents/skills/docker-view   # Claude Code and opencode
~/.config/opencode/command/docker-view.md                         # makes /docker-view a slash command in opencode
```

| Tool | Where it finds the skill | How to invoke |
|---|---|---|
| Claude Code | `~/.claude/skills/docker-view` (symlink) | `/docker-view notification` |
| opencode | `~/.claude/skills/` + `~/.config/opencode/command/docker-view.md` | `/docker-view notification` |
| Codex | `~/.agents/skills/docker-view` | `$docker-view notification` (or pick it from `/skills`) |

## Install

Run these blocks in order in a shell.

### `SKILL.md`

````bash
mkdir -p "$HOME/.agents/skills/docker-view"
cat > "$HOME/.agents/skills/docker-view/SKILL.md" <<'DOCKER_VIEW_EOF'
---
name: docker-view
description: Opens a tmux window running lazydocker for one git worktree's docker compose stack, picking the worktree by fuzzy match on its folder name or branch (e.g. "notification" → example-app-rails-notifications, feature/notifications). Use when the user runs /docker-view, or asks to see, manage or open lazydocker for a worktree's containers.
---

# docker-view

Argument: an optional fuzzy query, e.g. `/docker-view notification`, `/docker-view billing`,
`/docker-view production`.

## Run it

Run the script from the repo (any checkout or worktree of it), or from the workspace folder that
holds the checkouts, passing the query through:

```bash
~/.agents/skills/docker-view/scripts/docker-view.sh [query]
```

- Add `-C <dir>` if the current directory isn't inside the repo or workspace.
- Add `--background` only if the user asks not to switch windows.
- `--print` resolves the worktree and prints it (`worktree=`, `branch=`, `owner=`) without opening
  anything. Use it to answer "which worktree is running docker?".
- `--compose <file>` for a compose file other than `local_development/docker-compose.yml`.

**How the query resolves:** it's compared with each worktree's topic (folder name without the
`<repo>-` prefix), folder name and branch. First exact matches, then substrings, then `fzf` fuzzy
matching. The first tier with any match decides. With **no query** it opens the worktree whose code
the compose project's running containers have mounted, or else the current checkout (the main
checkout when run from the workspace folder).

**Exit codes:**
- `3`: several worktrees matched, and they're printed. Show them to the user and ask which one,
  or rerun with a query that makes the choice clear. Don't pick one yourself.
- `4`: no match, and all worktrees are printed.
- `1`: error (not in tmux, missing tool, no compose file, a user window with the same name).

Then report the output in a couple of lines: the window name, the worktree and branch, how to reach
it (`prefix` + `w`), and any `warning:` line verbatim.

## What the user sees

lazydocker, started in the worktree with `-f <compose file>`:
- **Services:** only that compose project's services (for example-app: db, mailcatcher, rails…).
- **Standalone Containers:** everything else on the machine, including other projects. lazydocker
  0.24.4 can't filter this list, though `/` filters it by hand. Its "stop all"/"remove all" act on
  *every* container on the machine, including hidden ones.

The window is named `docker-<topic>`. Running it again for the same worktree replaces it. It's
tagged `@docker_view`, and the script never replaces a window it didn't make.

## The warning that matters

All example-app worktrees share one compose project (`example-app`, fixed container names), and the rails
service mounts `${PWD}`. If the stack is running from another worktree, the script warns. In that
case, up/restart/rebuild in this lazydocker would recreate the stack with *this* worktree's code.
Pass that warning on to the user. Never press keys in the lazydocker pane yourself.

## Rules

- Never send keystrokes to the lazydocker pane.
- It must run inside tmux. If `$TMUX` is empty, give the user the command to run from a tmux
  pane (`--print` works outside tmux).
- Don't kill or reuse windows the user made.
DOCKER_VIEW_EOF
````

### `scripts/docker-view.sh`

````bash
mkdir -p "$HOME/.agents/skills/docker-view/scripts"
cat > "$HOME/.agents/skills/docker-view/scripts/docker-view.sh" <<'DOCKER_VIEW_EOF'
#!/usr/bin/env bash
# docker-view.sh [-C <dir>] [--background] [--print] [--compose <file>] [query]
#
# Opens a tmux window named docker-<topic> running lazydocker for one worktree of the repo,
# scoped to its compose file (lazydocker -f <file>), so the Services panel holds only that
# project's services.
#
#   query   fuzzy-matched against each worktree's folder name and branch, in tiers:
#           1. exact (topic, folder, branch, or branch without its prefix: feature/x -> x)
#           2. substring   3. fzf fuzzy match (if fzf is installed)
#           The first tier with matches wins; one match opens it, several print the
#           candidates and exit 3. A path to a worktree folder also works.
#   --print prints the worktree it would open (path, branch, owner) and exits; no window.
#   (none)  the worktree whose code the compose project's containers have mounted
#           (the one that started the stack); if nothing is running, this checkout.
#
# Exit codes: 0 opened, 1 error, 2 usage, 3 ambiguous query (candidates on stdout),
#             4 no match.
set -euo pipefail

usage() { echo "usage: docker-view.sh [-C <dir>] [--background] [--print] [--compose <file>] [query]" >&2; exit 2; }

dir=$PWD background=0 print=0 compose=local_development/docker-compose.yml
while [ $# -gt 0 ]; do
  case $1 in
    -C) dir=$2; shift 2 ;;
    --background) background=1; shift ;;
    --print) print=1; shift ;;
    --compose) compose=$2; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done
[ $# -le 1 ] || usage
query=${1:-}

for tool in git docker; do
  command -v "$tool" >/dev/null || { echo "error: $tool is not installed" >&2; exit 1; }
done
[ -n "${TMUX:-}" ] || [ "$print" = 1 ] || { echo "error: not inside tmux; run it from a tmux pane" >&2; exit 1; }

# Any checkout works: the worktree list is shared. Fall back to a checkout that has the compose file when
# run from the workspace folder that holds the checkouts.
if ! repo=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
  repo=""
  for d in "$dir"/*/; do
    [ -e "$d.git" ] && [ -f "$d$compose" ] && repo=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) && break
  done
  [ -n "$repo" ] || { echo "error: $dir is not in a git repo and holds no checkouts" >&2; exit 1; }
  from_workspace=1
fi
main=$(cd "$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)
# From the workspace folder, "this checkout" means the main one.
[ "${from_workspace:-0}" = 1 ] && repo=$main
prefix="$(basename "$main")-"

# Worktrees that exist on disk: parallel arrays (bash 3.2 has no associative arrays).
paths=() branches=() topics=()
add_wt() {
  [ -n "$wt" ] && [ -d "$wt" ] || return 0
  local b=${br:-detached} t; t=$(basename "$wt"); t=${t#"$prefix"}
  [ "$wt" = "$main" ] && t=$(basename "$wt")
  paths+=("$wt"); branches+=("$b"); topics+=("$t")
}
wt="" br=""
while IFS= read -r line; do
  case $line in
    "worktree "*) add_wt; wt=${line#worktree } br="" ;;
    "branch "*) br=${line#branch refs/heads/} ;;
  esac
done < <(git -C "$repo" worktree list --porcelain)
add_wt

lc() { printf %s "$1" | tr '[:upper:]' '[:lower:]'; }
list_candidates() { for i in "$@"; do printf '  %-28s %-45s %s\n' "${topics[$i]}" "${branches[$i]}" "${paths[$i]}"; done; }

# Compose project name: the file's top-level `name:`, else compose's default (its folder).
project_of() {
  local f=$1/$compose n
  n=$(sed -n 's/^name:[[:space:]]*["'\'']\{0,1\}\([^"'\'' ]*\).*/\1/p' "$f" 2>/dev/null | head -1)
  [ -n "$n" ] || n=$(basename "$(dirname "$f")" | tr '[:upper:]' '[:lower:]')
  printf %s "$n"
}

# Which worktree the project's containers have mounted (bind mounts whose source is a worktree).
docker_ok=1 owner="" project=""
docker info >/dev/null 2>&1 || docker_ok=0
find_owner() {
  [ $docker_ok = 1 ] || return 0
  local ids src i
  ids=$(docker ps -q --filter "label=com.docker.compose.project=$project")
  [ -n "$ids" ] || return 0
  while IFS= read -r src; do
    for i in "${!paths[@]}"; do
      [ "$src" = "${paths[$i]}" ] && { owner=${paths[$i]}; return 0; }
    done
  done < <(docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{println .Source}}{{end}}{{end}}' $ids)
}

pick=""
if [ -z "$query" ]; then
  project=$(project_of "$repo"); find_owner
  pick=${owner:-$repo}
elif [ -d "$query" ]; then
  q=$(cd "$query" && pwd -P)
  for i in "${!paths[@]}"; do [ "${paths[$i]}" = "$q" ] && pick=$q; done
  [ -n "$pick" ] || { echo "error: $query is not a worktree of $main" >&2; exit 1; }
else
  q=$(lc "$query") hits=()
  for i in "${!paths[@]}"; do                                   # 1. exact
    t=$(lc "${topics[$i]}") b=$(lc "${branches[$i]}")
    if [ "$q" = "$t" ] || [ "$q" = "$(lc "$(basename "${paths[$i]}")")" ] || [ "$q" = "$b" ] || [ "$q" = "${b##*/}" ]; then hits+=("$i"); fi
  done
  if [ ${#hits[@]} -eq 0 ]; then                                # 2. substring
    for i in "${!paths[@]}"; do
      t=$(lc "${topics[$i]}") b=$(lc "${branches[$i]}")
      case "$t" in *"$q"*) hits+=("$i"); continue ;; esac
      case "$b" in *"$q"*) hits+=("$i") ;; esac
    done
  fi
  if [ ${#hits[@]} -eq 0 ] && command -v fzf >/dev/null; then   # 3. fuzzy, best first
    while IFS=$'\t' read -r i _; do hits+=("$i"); done < <(
      for i in "${!paths[@]}"; do printf '%s\t%s %s\n' "$i" "${topics[$i]}" "${branches[$i]}"; done |
        fzf --filter "$query" -i --delimiter=$'\t' --nth=2..)
  fi
  if [ ${#hits[@]} -eq 0 ]; then
    echo "no worktree matches '$query'. Worktrees:"; list_candidates "${!paths[@]}"; exit 4
  elif [ ${#hits[@]} -gt 1 ]; then
    echo "'$query' matches ${#hits[@]} worktrees; be more specific:"; list_candidates "${hits[@]}"; exit 3
  fi
  pick=${paths[${hits[0]}]}
fi

for i in "${!paths[@]}"; do [ "${paths[$i]}" = "$pick" ] && idx=$i; done
topic=${topics[$idx]} branch=${branches[$idx]}
[ -f "$pick/$compose" ] || { echo "error: $pick has no $compose" >&2; exit 1; }
[ -n "$project" ] || { project=$(project_of "$pick"); find_owner; }
if [ $print = 1 ]; then
  printf 'worktree=%s\nbranch=%s\ntopic=%s\nproject=%s\nowner=%s\n' "$pick" "$branch" "$topic" "$project" "${owner:-}"
  exit 0
fi
for tool in tmux lazydocker; do
  command -v "$tool" >/dev/null || { echo "error: $tool is not installed" >&2; exit 1; }
done

session=$(tmux display-message -p -t "${TMUX_PANE:-}" '#S')
slug() { printf %s "$*" | tr -c 'A-Za-z0-9_.-' '-' | sed 's/--*/-/g; s/^-//; s/-$//'; }
name="docker-$(slug "$topic")"
target="$session:=$name"
# Replace only a window this script made (tagged @docker_view), never one the user named the same.
if tmux list-windows -t "$session" -F '#W' | grep -qxF "$name"; then
  if [ "$(tmux show-options -wqv -t "$target" @docker_view)" = 1 ]; then
    tmux kill-window -t "$target"
  else
    echo "error: a window named '$name' already exists and wasn't made by docker-view; rename or close it" >&2; exit 1
  fi
fi
# The compose file mounts ${PWD}: pin it to the worktree so lazydocker's up/rebuild use its code.
tmux new-window -d -t "$session:" -n "$name" -c "$pick" \
  "export PWD=$(printf %q "$pick"); exec lazydocker -f $(printf %q "$compose")"
tmux set-option -w -t "$target" @docker_view 1
[ $background = 1 ] || tmux select-window -t "$target"

echo "opened window '$name' in session '$session'"
echo "  worktree: $pick ($branch)"
echo "  lazydocker -f $compose  (compose project '$project')"
if [ $docker_ok = 0 ]; then
  echo "  warning: Docker isn't reachable; start Docker Desktop, then lazydocker will connect"
else
  running=$(docker ps -a --filter "label=com.docker.compose.project=$project" --format '{{.Names}} ({{.State}})' | paste -sd, - | sed 's/,/, /g')
  echo "  containers: ${running:-none}"
  if [ -n "$owner" ] && [ "$owner" != "$pick" ]; then
    echo "  warning: the '$project' stack is running from $owner, not this worktree; up/restart/rebuild in this lazydocker would recreate it with the $topic worktree's code"
  fi
fi
DOCKER_VIEW_EOF
````

### `scripts/make_setup_doc.sh`

````bash
mkdir -p "$HOME/.agents/skills/docker-view/scripts"
cat > "$HOME/.agents/skills/docker-view/scripts/make_setup_doc.sh" <<'DOCKER_VIEW_EOF'
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
DOCKER_VIEW_EOF
````

### `opencode command`

````bash
mkdir -p "$HOME/.config/opencode/command"
cat > "$HOME/.config/opencode/command/docker-view.md" <<'DOCKER_VIEW_EOF'
---
description: Open lazydocker in a new tmux window for a worktree's compose stack, picked by fuzzy match (e.g. /docker-view notification).
---

Load the `docker-view` skill (from ~/.agents/skills/docker-view/SKILL.md) and execute it now, following its full instructions.

Invocation arguments: $ARGUMENTS

If the skill content is unavailable, read `/Users/raysapida/.agents/skills/docker-view/SKILL.md` directly and follow it.
DOCKER_VIEW_EOF
````

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
