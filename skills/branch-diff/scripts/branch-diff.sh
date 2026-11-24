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
