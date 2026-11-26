#!/bin/bash
# EXPERIMENTAL: have a cheap model read a plan before handoff and list what an
# executor would find ambiguous, stale or unverifiable. Findings are suggestions
# for Claude to weigh; they never replace Claude's own plan review.
#
# usage: plan_check.sh --dir PROJECT_DIR --plan ABS_PLAN_FILE [--model provider/model]
#
# Runs through launch.sh with opencode's read-only "plan" agent in a new,
# archived session (kept out of sessions.py). The plan agent denies its edit
# tool but its shell inherits the project's "*": "allow" (opencode v2.3.2), so
# this script snapshots git state before and after, and exits 3 loudly if
# anything in the repo changed.
# Run it in the background; read the result with:
#   status.py <log> --report
set -u

DIR="" PLAN="" MODEL="ollama-cloud/deepseek-v4.1-flash"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "plan_check.sh: $*" >&2; exit 2; }
[ -n "$DIR" ] && [ -d "$DIR" ] || fail "--dir must be an existing directory"
DIR=$(cd "$DIR" && pwd -P)
case "$PLAN" in /*) ;; *) fail "--plan must be an absolute path" ;; esac
[ -s "$PLAN" ] || fail "plan file $PLAN is missing or empty"
git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || fail "$DIR is not a git repo (the change guard needs git)"

snapshot() { git -C "$DIR" rev-parse HEAD; git -C "$DIR" status --porcelain --untracked-files=all; }
BEFORE=$(snapshot)

mkdir -p "$HOME/.cache/opencode-handoff"
TS=$(date +%Y%m%d-%H%M%S)
PROMPT="$HOME/.cache/opencode-handoff/plan-check-$TS.prompt"
LOG="$HOME/.cache/opencode-handoff/plan-check-$TS.log"
cat > "$PROMPT" <<EOF
You are reviewing a plan BEFORE another agent executes it unattended. You are READ-ONLY:
do not create, edit or delete any file, do not run builds or tests, and do not run any git
command that changes state (commit, checkout, stash, reset, add). Reading files and running
read-only commands (cat, grep, sed -n, ls, git log, git diff, git show) is fine. Stay inside
$DIR.

1. Read the project's AGENTS.md (if present) and the plan in full: $PLAN
2. Check every file:line the plan quotes against the current code.
3. Imagine you must execute the plan with no one to ask. List every problem you would hit:
   - a step that needs a judgement call or has two reasonable readings;
   - a quoted file:line or code snippet that doesn't match the current code;
   - a Verify command whose expected output is missing, vague, or looks wrong;
   - a file a step needs to touch that is not in scope, or a commit that names no files;
   - a failure the plan has no STOP condition for;
   - anything the plan and the project's AGENTS.md disagree on.

Report a numbered list. For each item: the step, the problem (quote the plan text), and a
one-line suggested fix. Most important first, at most 15 items. Do not restate parts of the
plan that are fine. If you find nothing, reply exactly: NO ISSUES FOUND.
EOF

echo "$LOG"
"$(dirname "$0")/launch.sh" --dir "$DIR" --prompt "$PROMPT" --new "plan check: $(basename "$PLAN")" \
  --model "$MODEL" --agent plan --archived --log "$LOG" >/dev/null
RC=$?

AFTER=$(snapshot)
if [ "$BEFORE" != "$AFTER" ]; then
  echo "PLAN CHECK CHANGED THE REPO — the read-only guard failed. Inspect before anything else:" | tee -a "$LOG"
  diff <(echo "$BEFORE") <(echo "$AFTER") | tee -a "$LOG"
  exit 3
fi
echo "plan_check.sh: repo unchanged; launch exit $RC" | tee -a "$LOG"
exit $RC
