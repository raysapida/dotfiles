#!/usr/bin/env bash
# Start (or resume) a headless Claude Code run on a handoff prompt, on Sonnet by default,
# sandboxed to the project.
#
#   launch.sh --dir <abs project dir> --prompt <abs prompt file> [--resume <session id>]
#             [--model <alias|id>] [--localhost] [--allow-domain <domain>]...
#             [--max-budget <usd>] [--name "<title>"]
#
# Containment (verified 2026-11-17, Claude Code 2.1.327):
#   --restricted          ignores user/project/local settings files (their allow rules and hooks),
#                         confines the file tools to the project, refuses bypassPermissions
#   --strict-mcp-config   no MCP servers (the project's may reach production)
#   --tools ...           only Bash, Read, Edit, Write, Glob, Grep (no Skill, Agent or web tools)
#   sandbox (settings)    Bash writes only inside the project and $TMPDIR; network off
#   --localhost           sandbox.network.allowLocalBinding: 127.0.0.1 services (Postgres) reachable,
#                         the internet stays blocked
#   --allow-domain d      opens one internet domain (e.g. rubygems.org); repeatable
#
# Prints the log paths first, then blocks until the run ends.

set -euo pipefail

dir="" prompt="" resume="" model="sonnet" localhost=false budget="" name=""
domains=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --resume) resume="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --localhost) localhost=true; shift ;;
    --allow-domain) domains+=("$2"); shift 2 ;;
    --max-budget) budget="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    *) echo "launch.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done

[[ "$dir" == /* && -d "$dir" ]] || { echo "launch.sh: --dir must be an existing absolute path" >&2; exit 2; }
[[ "$prompt" == /* && -s "$prompt" ]] || { echo "launch.sh: --prompt must be an existing, non-empty absolute file" >&2; exit 2; }
command -v claude >/dev/null || { echo "launch.sh: claude not on PATH" >&2; exit 2; }
claude --help 2>&1 | grep -q -- '--restricted' || { echo "launch.sh: this claude has no --restricted flag; upgrade Claude Code" >&2; exit 2; }

cd "$dir"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "launch.sh: $dir is not a git repository" >&2; exit 2; }

tmp="$dir/.handoff-tmp"
mkdir -p "$tmp/cache"
exclude="$(git rev-parse --git-common-dir)/info/exclude"
grep -qx '.handoff-tmp/' "$exclude" 2>/dev/null || echo '.handoff-tmp/' >> "$exclude"

stamp="$(date +%Y%m%d-%H%M%S)"
log="$tmp/claude-$stamp.jsonl"
err="$tmp/claude-$stamp.err"
settings="$tmp/claude-$stamp.settings.json"

# Settings for this run only (kept beside the log so the containment is auditable).
python3 - "$settings" "$tmp/cache" "$localhost" "${domains[@]+"${domains[@]}"}" <<'EOF'
import json, sys
out, cache, localhost, *domains = sys.argv[1:]
network = {}
if localhost == "true":
    network["allowLocalBinding"] = True
if domains:
    network["allowedDomains"] = domains
settings = {
    "sandbox": {
        "enabled": True,
        "autoAllowBashIfSandboxed": True,
        "allowUnsandboxedCommands": False,
        "network": network,
    },
    "permissions": {
        # autoAllowBashIfSandboxed still asks about some commands (an env prefix such as
        # `RAILS_ENV=test ...`, compound commands); headless, an ask is a refusal. Allowing Bash
        # outright is safe because every command still runs inside the sandbox (and
        # allowUnsandboxedCommands=false removes the escape hatch). Deny rules win over allow.
        "allow": ["Bash"],
        "deny": ["Bash(git push:*)", "Bash(*git push*)", "Bash(git * push*)"],
    },
    "env": {
        # tool caches default to ~/.cache, which the sandbox can't write
        "XDG_CACHE_HOME": cache,
        "RUBOCOP_CACHE_ROOT": cache + "/rubocop",
    },
}
json.dump(settings, open(out, "w"), indent=2)
EOF

echo "log:      $log"
echo "err:      $err"
echo "settings: $settings"
echo "model:    $model${resume:+ (resuming $resume)}  localhost=$localhost  domains=${domains[*]:-none}"

args=(-p --model "$model"
      --restricted --strict-mcp-config
      --tools Bash,Read,Edit,Write,Glob,Grep
      --permission-mode acceptEdits
      --settings "$settings"
      --output-format stream-json --verbose)
[[ -n "$budget" ]] && args+=(--max-budget-usd "$budget")
[[ -n "$name" ]] && args+=(--name "$name")
[[ -n "$resume" ]] && args+=(--resume "$resume")

# The prompt goes after `--`: --tools and friends take several values and would swallow it.
# stdin is closed so nothing can wait on it.
set +e
claude "${args[@]}" -- "$(cat "$prompt")" < /dev/null > "$log" 2> "$err"
status=$?
set -e
echo "launch.sh: claude exited $status"
exit $status
