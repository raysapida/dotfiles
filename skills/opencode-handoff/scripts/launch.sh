#!/bin/bash
# Hand a prompt to opencode headlessly, with the flags that proved reliable.
#
# usage: launch.sh --dir PROJECT_DIR --prompt ABS_PROMPT_FILE
#                  (--session SESSION_ID | --new "Session title")
#                  [--model provider/model] [--log LOG_FILE] [--no-permission-check]
#                  [--agent NAME] [--archived]
#
# --agent picks an opencode agent (plan_check.sh uses "plan"); --archived keeps
# the session out of session lists.
#
# Needs opencode v2, and a project opencode.json that denies work outside the
# project (checked before launch; see SKILL.md step 2).
#
# Run it in the background (it returns when the opencode turn ends). The
# first line printed is the log path; pass it to status.py.
set -u

DIR="" PROMPT="" SESSION="" TITLE="" MODEL="" LOG="" NO_PERM_CHECK=0
EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) EXTRA+=(--agent "$2"); shift 2 ;;
    --archived) EXTRA+=(--archived); shift ;;
    --dir) DIR="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --session) SESSION="$2"; shift 2 ;;
    --new) TITLE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --no-permission-check) NO_PERM_CHECK=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "launch.sh: $*" >&2; exit 2; }
[ -n "$DIR" ] && [ -d "$DIR" ] || fail "--dir must be an existing directory"
DIR=$(cd "$DIR" && pwd -P)
case "$PROMPT" in /*) ;; *) fail "--prompt must be an absolute path" ;; esac
[ -s "$PROMPT" ] || fail "prompt file $PROMPT is missing or empty"
if [ -n "$SESSION" ] && [ -n "$TITLE" ]; then fail "use --session OR --new, not both"; fi
[ -n "$SESSION$TITLE" ] || fail "choose --session SESSION_ID or --new \"title\""

# Default model: opencode's configured one, pinned explicitly so the run can't drift
if [ -z "$MODEL" ]; then
  MODEL=$(python3 - <<'EOF'
import os, re
for p in ("~/.config/opencode/opencode.json", "~/.config/opencode/opencode.jsonc"):
    p = os.path.expanduser(p)
    if os.path.exists(p):
        m = re.search(r'^\s*"model"\s*:\s*"([^"]+)"', open(p).read(), re.M)
        if m:
            print(m.group(1)); break
EOF
)
fi
[ -n "$MODEL" ] || fail "no --model given and none found in ~/.config/opencode/opencode.json"

# The flags below are opencode v2's; v1 rejects them (and v2 rejects v1's).
case "$(opencode --version 2>/dev/null)" in
  *v2.*|2.*) ;;
  *) fail "needs opencode v2 (found: $(opencode --version 2>&1 | head -1))" ;;
esac

# v2 headless does NOT refuse work outside the project (v1 auto-rejected it).
# Require the project's opencode.json to deny it: external_directory "deny"
# (or {"*": "deny", ...allow-list}) and a shell rule denying "*../*".
[ "$NO_PERM_CHECK" = 1 ] || python3 - "$DIR" <<'EOF' || fail "fix $DIR/opencode.json permissions (see SKILL.md step 2) or pass --no-permission-check"
import json, os, re, sys
d = sys.argv[1]
for name in ("opencode.json", "opencode.jsonc"):
    p = os.path.join(d, name)
    if os.path.exists(p):
        break
else:
    sys.exit(print(f"launch.sh: no opencode.json in {d}", file=sys.stderr) or 1)
txt = re.sub(r"^\s*//.*$", "", open(p).read(), flags=re.M)
perm = json.loads(txt).get("permission", {})
ext = perm.get("external_directory")
ext_ok = ext == "deny" or (isinstance(ext, dict) and ext.get("*") == "deny")
sh = perm.get("shell") or perm.get("bash") or {}
sh_ok = isinstance(sh, dict) and sh.get("*../*") == "deny"
if not (ext_ok and sh_ok):
    print(f"launch.sh: {p}: permission.external_directory must deny '*' and "
          "permission.shell must deny '*../*'", file=sys.stderr)
    sys.exit(1)
EOF

if [ -z "$LOG" ]; then
  mkdir -p "$HOME/.cache/opencode-handoff"
  LOG="$HOME/.cache/opencode-handoff/$(date +%Y%m%d-%H%M%S).log"
fi
echo "$LOG"
echo "launch: dir=$DIR model=$MODEL ${SESSION:+session=$SESSION}${TITLE:+new=\"$TITLE\"} at $(date '+%H:%M:%S')" > "$LOG"

cd "$DIR" || fail "cannot cd to $DIR"

# opencode v2 (2.x). v1's `--dir` flag is gone: the working directory is the
# project. --standalone: a private server per run (instead of the shared
# background service), so --print-logs includes server logs and killing the run
# stops everything. --format json: one JSON event per line (step_start,
# tool_use, text, step_finish) with the session id; status.py parses it.
# --log-level must be lower case in v2.
run_once() {
  if [ -n "$SESSION" ]; then
    opencode run --standalone --print-logs --log-level info --format json --session "$SESSION" -m "$MODEL" ${EXTRA[@]+"${EXTRA[@]}"} "$(cat "$PROMPT")" >> "$LOG" 2>&1 &
  else
    opencode run --standalone --print-logs --log-level info --format json --title "$TITLE" -m "$MODEL" ${EXTRA[@]+"${EXTRA[@]}"} "$(cat "$PROMPT")" >> "$LOG" 2>&1 &
  fi
  PID=$!
}

kill_run() {
  # the standalone server is a child (`opencode serve --stdio`); it outlives a
  # killed parent unless it is killed too
  pkill -P "$1" 2>/dev/null; kill "$1" 2>/dev/null; sleep 2
  pkill -9 -P "$1" 2>/dev/null; kill -9 "$1" 2>/dev/null
}

# Some launches hang at startup without reaching the model (v1: after "init";
# v2: about 1 in 5 launches print nothing at all) (the session is untouched). Retry those automatically.
HANG_SECONDS=45
MAX_RETRIES=2
attempt=0
while :; do
  start_bytes=$(wc -c < "$LOG")
  run_once
  waited=0
  while kill -0 "$PID" 2>/dev/null && [ $waited -lt $HANG_SECONDS ]; do
    if tail -c +"$((start_bytes + 1))" "$LOG" | grep -q '"type":"step_start"'; then
      break
    fi
    sleep 3; waited=$((waited + 3))
  done
  if kill -0 "$PID" 2>/dev/null && ! tail -c +"$((start_bytes + 1))" "$LOG" | grep -q '"type":"step_start"' \
     && [ $attempt -lt $MAX_RETRIES ]; then
    attempt=$((attempt + 1))
    kill_run "$PID"
    echo "launch.sh: no model call ${HANG_SECONDS}s after start; retry $attempt of $MAX_RETRIES at $(date '+%H:%M:%S')" >> "$LOG"
    continue
  fi
  wait "$PID"
  echo "EXIT $?" >> "$LOG"
  break
done
