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
