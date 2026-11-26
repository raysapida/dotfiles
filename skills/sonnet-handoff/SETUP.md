# Setting up the sonnet-handoff skill on a new laptop

Generated 2026-11-17 from the skill's current files in `~/.claude/skills/sonnet-handoff/` by
`scripts/make_setup_doc.py`. The install block below contains every file word for word, so this guide is
enough to recreate the skill on another machine. Regenerate it after changing the skill.

## What the skill does

The same division of labour as `opencode-handoff` and `codex-handoff`, with a headless Claude Code run on
**Sonnet** as the executor:

1. **Claude (your session's model, usually Opus) writes an executable plan**: exact steps, a Verify command with
   the expected result for each step, STOP conditions, and the files in scope.
2. **A headless `claude -p --model sonnet` run executes it unattended**, sandboxed to the project.
3. **The planning session monitors the run, then reviews the result itself**: it runs the tests, reads the
   diff, fixes small findings, records lessons, and commits only after you've seen the diff.

Two rules: **one plan per handoff**, and **the planning session always reviews**.

The model you pick in Claude Code only sets the interactive session. This skill hands one plan to a separate
process on another model (`--model sonnet` by default; `haiku` or a full model id also work).

| | `sonnet-handoff` |
|---|---|
| Executor | Claude Code headless (`claude -p --output-format stream-json --verbose`) |
| Default model | `sonnet` (resolved to `claude-sonnet-5-5` on 2026-11-17); `--model <alias or id>` overrides |
| Containment | `--restricted` (ignores your settings files, confines file tools to the project), `--strict-mcp-config` (no MCP), a fixed tool list, and Claude Code's OS sandbox for Bash (writes only in the project and `$TMPDIR`) |
| Network | off; `--localhost` opens 127.0.0.1 only (local Postgres), `--allow-domain <d>` opens one domain |
| Continue a run | `--resume <session id>` (the id stays the same) |
| Triggers | "hand this plan to Sonnet", "run it on Sonnet", "use a cheaper Claude model" |

`sonnet-handoff` doesn't duplicate the shared material: it reads the plan format, prompt template, review
checklist and lessons from the `opencode-handoff` folder. **Install `opencode-handoff` first.** Its setup
guide is the knowledge-base document "Setting up the opencode and Codex handoff skills on a new laptop".

## Directory layout

```
~/.claude/skills/
├── opencode-handoff/          # required: PLAN_FORMAT.md, PROMPT_TEMPLATE.md, REVIEW.md, LESSONS.md, lessons/
└── sonnet-handoff/
    ├── SKILL.md               # triggers, containment table, 10-step workflow, rules
    ├── SETUP.md               # this guide (generated; not needed at run time)
    └── scripts/
        ├── launch.sh          # start or resume a contained `claude -p` run
        ├── status.py          # summarise the stream-json log
        └── make_setup_doc.py  # regenerate SETUP.md
```

Files created at run time (not part of the install), all in `<project>/.handoff-tmp/` (`launch.sh` adds it to
the repo's `.git/info/exclude`):
- `claude-<stamp>.jsonl` (the event log), `claude-<stamp>.err`, `claude-<stamp>.settings.json` (the exact
  sandbox and permission settings that run used)
- `cache/`: tool caches (RuboCop and others) redirected from `~/.cache`

## Prerequisites

1. **Claude Code** with the `--restricted` flag (checked by `launch.sh`; verified on 2.1.327), signed in, with
   access to Sonnet.
2. **The `opencode-handoff` skill folder** (see above). The opencode CLI itself is not needed.
3. **python3** (3.8+), **bash** and **git**. Projects must be git repositories (`launch.sh` refuses otherwise).
4. **macOS** (the sandbox was verified with macOS Seatbelt; Linux uses bubblewrap and was not tested).
5. The project's dependencies installed *before* a handoff (`bundle install` etc.): the sandbox has no internet
   unless you pass `--allow-domain`.
6. Optional: the knowledge-base MCP server (Claude searches it for past plans and lessons while planning) and the
   `kb-save` skill (archives plans and lessons). Without them Claude skips those steps.

## Install

Paste this into a terminal on the new laptop:

```````bash
mkdir -p ~/.claude/skills/sonnet-handoff/scripts

cat > ~/.claude/skills/sonnet-handoff/SKILL.md <<'SONNET_HANDOFF_FILE_EOF'
---
name: sonnet-handoff
description: Writes an executable plan, hands it to a headless Claude Code run on Sonnet (`claude -p --model sonnet`) sandboxed to the project, monitors the run, and reviews the result. Use when the user wants a plan executed "on Sonnet", by a cheaper Claude model, or asks to delegate or hand off a plan to Sonnet (or Haiku).
---

# Sonnet handoff

Same contract as the `opencode-handoff` skill: Claude (the session's model, usually Opus) plans and reviews, a
headless Claude Code run on Sonnet executes, the plan is the contract. Reuse that skill's files instead of copies:

- plan format: `~/.claude/skills/opencode-handoff/PLAN_FORMAT.md`
- prompt template: `~/.claude/skills/opencode-handoff/PROMPT_TEMPLATE.md` (adapt the sandbox wording below)
- review checklist: `~/.claude/skills/opencode-handoff/REVIEW.md`
- lessons: `~/.claude/skills/opencode-handoff/LESSONS.md` and `lessons/<project>.md` (shared by all handoff
  skills; record which tool and model ran in each entry)

Two fixed rules: **one plan per handoff**, and **the planning session always reviews** (never the Sonnet run).

Scripts are in `~/.claude/skills/sonnet-handoff/scripts/`: `launch.sh` (start or resume a run) and `status.py`
(summarise its log). Verified 2026-11-17 with Claude Code 2.1.327.

## How the run is contained

`launch.sh` runs `claude -p` with:

| Flag / setting | Effect (verified) |
|---|---|
| `--restricted` | ignores the user, project and local settings files: their allow rules and hooks (e.g. a Stop hook that kills headless Chrome) don't apply. Confines Read/Edit/Write to the project; refuses bypassPermissions |
| `--strict-mcp-config` | no MCP servers. The project's `.mcp.json` may point at production (knowledge_base's does) |
| `--tools Bash,Read,Edit,Write,Glob,Grep` | no Skill, Agent, WebFetch or WebSearch: the run can't start its own handoff or browse |
| sandbox (`--settings`, written per run to `.handoff-tmp/claude-<stamp>.settings.json`) | Bash writes only inside the project and `$TMPDIR` (`Operation not permitted` elsewhere); network off; `allowUnsandboxedCommands: false` |
| `permissions.allow: ["Bash"]` | needed: without it, commands like `RAILS_ENV=test bundle exec rspec` or `a; b` "require approval", which headless means refused. Still sandboxed |
| `permissions.deny` `git push` | denied outright (and the network is off anyway) |
| `env` `XDG_CACHE_HOME`, `RUBOCOP_CACHE_ROOT` | tool caches go to `.handoff-tmp/cache` (the sandbox can't write `~/.cache`) |
| `--localhost` | `sandbox.network.allowLocalBinding`: 127.0.0.1 services such as Postgres are reachable; the internet stays blocked |
| `--allow-domain <d>` | opens one domain (e.g. `rubygems.org` for a `bundle install`); repeatable |

Differences from Codex worth knowing:
- The shell loads your profile, so mise's Ruby is on `PATH` without help.
- **It can commit from a git worktree** (the sandbox allowed the main repo's `.git`). Still default to "do not
  commit" so you review the diff first, unless the user wants commits.
- Commits get a `Co-Authored-By: Claude Sonnet ...` line on their own; say in the prompt if the project wants
  something else.
- Bundler warns that `$HOME` isn't writable and uses a temp home; harmless.
- It reads `CLAUDE.md` like any Claude Code session; the prompt should still name `AGENTS.md` explicitly.

## Workflow

1. **Write the plan** per `PLAN_FORMAT.md`, after reading `lessons/<project>.md` and searching the knowledge base
   for past plans (the opencode-handoff skill's step 1). Plans for Sonnet should also give the exact environment
   for every command (database URLs, `RAILS_ENV=test`), and say "do not commit, do not `git add`" unless the user
   wants commits.
2. **Prepare the ground:** a git worktree for the branch if the user wants one; local-only files excluded from
   git. Make sure `bundle install` (or the project's equivalent) has run, since the sandbox has no internet. Do the setup a fresh
   worktree needs (e.g. `bin/rails tailwindcss:build` for knowledge_base) and run the baseline suite once so the
   plan's expected numbers are real.
3. **Smoke test** after a Claude Code upgrade or on a new project: a tiny prompt that runs `which ruby`, one spec
   file, and a `touch` outside the project (must fail). Read it with `status.py`.
4. **Write the handoff prompt** from `PROMPT_TEMPLATE.md` to `<project>/.handoff-tmp/<name>_prompt.md`. Replace the
   permission-rule paragraph with: "You run in a sandbox that only allows writes inside <PROJECT_DIR>; a blocked
   write fails with `Operation not permitted`, and a blocked tool call says its permission was denied. If
   anything is blocked, stop and report; don't work around it." Also add: "A mistake in a command you wrote
   yourself (a typo, a missing argument) is not a STOP: fix it and run it again." And: "Bundler's warning that
   your home directory isn't writable is expected and harmless." And, for Rails apps: "Do not run `spec/system`;
   it is run in review." Headless Chrome in this sandbox hasn't been tested.
5. **Launch in the background:**
   `scripts/launch.sh --dir <abs project> --prompt <abs prompt> [--localhost] [--model sonnet|haiku|<id>] [--max-budget <usd>] [--name "<title>"]`.
   Note the `log:` path it prints. Default model is `sonnet`. Use `--localhost` when the plan runs tests against
   a local database, and say so to the user.
6. **Check it started** about 60 s later with `scripts/status.py <log>`. `NO EVENTS` after a few minutes means it
   failed or hung: read the `.err` file, kill the `claude -p` process, fix, relaunch.
7. **When it ends**, `status.py <log> --commands`:
   - The `model:` line must show the model you asked for. A WARNING means part of the run used another model.
   - `BLOCKED` / `DENIED` lines are sandbox or permission blocks: check that the agent stopped rather than
     finding a way around.
   - For a STOP or a follow-up, write a continuation prompt (template's continuation section) and run
     `launch.sh --resume <session id> ...` with the same flags. The session id stays the same.
8. **Review** with `REVIEW.md`: run the tests yourself (and `spec/system`), read the diff. Fix small findings
   directly.
9. **Record lessons** in `lessons/<project>.md` (note "sonnet-handoff, <model>") and save it with `kb-save` if that
   skill is installed.
10. **Commit** after showing the user the diff, then archive the plan with `kb-save` (`status: completed`, tag
    `sonnet-handoff`) once the work is merged or accepted.

## Rules for Claude

- Absolute paths only; launch through `launch.sh`, never a bare `claude -p`: the containment lives in its flags.
- One run per session at a time; wait for the background notification.
- Never add `--dangerously-skip-permissions`, `--permission-mode bypassPermissions`, or MCP servers to a run.
- `--localhost` / `--allow-domain` only when the plan needs them, and say so to the user.
- Prompts go after `--` (`launch.sh` does this): `--tools` takes several values and swallows a prompt placed after it.
SONNET_HANDOFF_FILE_EOF

cat > ~/.claude/skills/sonnet-handoff/scripts/launch.sh <<'SONNET_HANDOFF_FILE_EOF'
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
SONNET_HANDOFF_FILE_EOF

cat > ~/.claude/skills/sonnet-handoff/scripts/status.py <<'SONNET_HANDOFF_FILE_EOF'
#!/usr/bin/env python3
"""Summarise a headless Claude Code run (`claude -p --output-format stream-json --verbose`).

    status.py <log.jsonl> [--commands] [--tail N]

Shows: session id, the model(s) that actually answered, state, tool use, sandbox and permission
blocks, files written, cost, and the final message when the run has ended.
"""
import json
import pathlib
import sys
from collections import Counter

BLOCK_MARKERS = ("Operation not permitted", "operation not permitted", "<sandbox_violations>",
                 "Permission to use", "permission denied")


def load(path):
    events = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return events


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict))
    return str(content or "")


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    log = pathlib.Path(args[0])
    show_commands = "--commands" in args
    tail = int(args[args.index("--tail") + 1]) if "--tail" in args else 5
    events = load(log)

    if not events:
        err = log.with_suffix(".err")
        print("state:    NO EVENTS (still starting, or failed before the first event; check the .err file)")
        if err.exists() and err.read_text().strip():
            print("stderr:   " + " | ".join(err.read_text().strip().splitlines()[-3:]))
        return

    init = next((e for e in events if e.get("type") == "system" and e.get("subtype") == "init"), {})
    result = next((e for e in reversed(events) if e.get("type") == "result"), None)

    tool_uses, results, models, texts = {}, {}, Counter(), []
    for e in events:
        msg = e.get("message") or {}
        if e.get("type") == "assistant":
            if msg.get("model"):
                models[msg["model"]] += 1
            for c in msg.get("content") or []:
                if c.get("type") == "tool_use":
                    tool_uses[c["id"]] = c
                elif c.get("type") == "text" and c.get("text", "").strip():
                    texts.append(c["text"].strip())
        elif e.get("type") == "user":
            for c in msg.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    results[c.get("tool_use_id")] = c

    print(f"session:  {init.get('session_id') or (result or {}).get('session_id')}")
    print(f"model:    init={init.get('model')}  answered={dict(models)}")
    wanted = init.get("model") or ""
    if any(m != wanted for m in models):
        print("  WARNING: a different model answered part of the run (fallback?)")
    print(f"cwd:      {init.get('cwd')}")
    print(f"tools:    {init.get('tools')}  mcp={init.get('mcp_servers')}")

    if result is None:
        state = "RUNNING"
    elif result.get("is_error") or result.get("subtype") != "success":
        state = f"FAILED ({result.get('subtype')}, {result.get('terminal_reason') or result.get('api_error_status') or ''})"
    else:
        state = "FINISHED"
    print(f"state:    {state}")

    names = Counter(t.get("name") for t in tool_uses.values())
    errors = [tid for tid, r in results.items() if r.get("is_error")]
    blocked = [tid for tid, r in results.items() if any(m in text_of(r.get("content")) for m in BLOCK_MARKERS)]
    print(f"tools used: {dict(names)}; {len(errors)} errored, {len(blocked)} blocked by the sandbox/permissions")
    for tid in blocked:
        t = tool_uses.get(tid, {})
        inp = t.get("input") or {}
        print(f"  BLOCKED {t.get('name')} {str(inp.get('command') or inp.get('file_path') or '')[:150]}")
    for d in (result or {}).get("permission_denials") or []:
        inp = d.get("tool_input") or {}
        print(f"  DENIED  {d.get('tool_name')} {str(inp.get('command') or inp.get('file_path') or '')[:150]}")

    files = sorted({(t.get("input") or {}).get("file_path") for t in tool_uses.values()
                    if t.get("name") in ("Write", "Edit") and tid_ok(t, results)} - {None})
    if files:
        print("files:    " + ", ".join(files))

    if show_commands:
        for tid, t in tool_uses.items():
            if t.get("name") == "Bash":
                r = results.get(tid, {})
                flag = "ERR" if r.get("is_error") else ("..." if not r else "ok ")
                print(f"  [{flag}] {(t.get('input') or {}).get('command', '')[:200]}")

    if result is None:
        if texts:
            print("last text:")
            for t in texts[-tail:]:
                print("  " + t.replace("\n", " ")[:200])
        return

    cost = result.get("total_cost_usd")
    mins = (result.get("duration_ms") or 0) / 60000
    print(f"cost:     ${cost:.2f}  turns={result.get('num_turns')}  duration={mins:.1f} min" if cost is not None
          else f"turns={result.get('num_turns')}")
    print("\n--- final message ---\n" + str(result.get("result") or (texts[-1] if texts else "")))


def tid_ok(tool_use, results):
    r = results.get(tool_use.get("id"))
    return bool(r) and not r.get("is_error")


main()
SONNET_HANDOFF_FILE_EOF

cat > ~/.claude/skills/sonnet-handoff/scripts/make_setup_doc.py <<'SONNET_HANDOFF_FILE_EOF'
#!/usr/bin/env python3
"""Generate SETUP.md: a self-contained guide for recreating the sonnet-handoff skill on another
computer, built from the skill's current files so it never drifts.

usage: make_setup_doc.py [OUTPUT]   (default: <skill dir>/SETUP.md)
Re-run after changing any skill file.
"""
import datetime
import os
import sys

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["SKILL.md", "scripts/launch.sh", "scripts/status.py", "scripts/make_setup_doc.py"]
DELIM = "SONNET_HANDOFF_FILE_EOF"
FENCE = "`" * 7  # longer than any fence inside the files, built so the literal never appears here

INTRO = """# Setting up the sonnet-handoff skill on a new laptop

Generated {date} from the skill's current files in `~/.claude/skills/sonnet-handoff/` by
`scripts/make_setup_doc.py`. The install block below contains every file word for word, so this guide is
enough to recreate the skill on another machine. Regenerate it after changing the skill.

## What the skill does

The same division of labour as `opencode-handoff` and `codex-handoff`, with a headless Claude Code run on
**Sonnet** as the executor:

1. **Claude (your session's model, usually Opus) writes an executable plan**: exact steps, a Verify command with
   the expected result for each step, STOP conditions, and the files in scope.
2. **A headless `claude -p --model sonnet` run executes it unattended**, sandboxed to the project.
3. **The planning session monitors the run, then reviews the result itself**: it runs the tests, reads the
   diff, fixes small findings, records lessons, and commits only after you've seen the diff.

Two rules: **one plan per handoff**, and **the planning session always reviews**.

The model you pick in Claude Code only sets the interactive session. This skill hands one plan to a separate
process on another model (`--model sonnet` by default; `haiku` or a full model id also work).

| | `sonnet-handoff` |
|---|---|
| Executor | Claude Code headless (`claude -p --output-format stream-json --verbose`) |
| Default model | `sonnet` (resolved to `claude-sonnet-5-5` on 2026-11-17); `--model <alias or id>` overrides |
| Containment | `--restricted` (ignores your settings files, confines file tools to the project), `--strict-mcp-config` (no MCP), a fixed tool list, and Claude Code's OS sandbox for Bash (writes only in the project and `$TMPDIR`) |
| Network | off; `--localhost` opens 127.0.0.1 only (local Postgres), `--allow-domain <d>` opens one domain |
| Continue a run | `--resume <session id>` (the id stays the same) |
| Triggers | "hand this plan to Sonnet", "run it on Sonnet", "use a cheaper Claude model" |

`sonnet-handoff` doesn't duplicate the shared material: it reads the plan format, prompt template, review
checklist and lessons from the `opencode-handoff` folder. **Install `opencode-handoff` first.** Its setup
guide is the knowledge-base document "Setting up the opencode and Codex handoff skills on a new laptop".

## Directory layout

```
~/.claude/skills/
├── opencode-handoff/          # required: PLAN_FORMAT.md, PROMPT_TEMPLATE.md, REVIEW.md, LESSONS.md, lessons/
└── sonnet-handoff/
    ├── SKILL.md               # triggers, containment table, 10-step workflow, rules
    ├── SETUP.md               # this guide (generated; not needed at run time)
    └── scripts/
        ├── launch.sh          # start or resume a contained `claude -p` run
        ├── status.py          # summarise the stream-json log
        └── make_setup_doc.py  # regenerate SETUP.md
```

Files created at run time (not part of the install), all in `<project>/.handoff-tmp/` (`launch.sh` adds it to
the repo's `.git/info/exclude`):
- `claude-<stamp>.jsonl` (the event log), `claude-<stamp>.err`, `claude-<stamp>.settings.json` (the exact
  sandbox and permission settings that run used)
- `cache/`: tool caches (RuboCop and others) redirected from `~/.cache`

## Prerequisites

1. **Claude Code** with the `--restricted` flag (checked by `launch.sh`; verified on 2.1.327), signed in, with
   access to Sonnet.
2. **The `opencode-handoff` skill folder** (see above). The opencode CLI itself is not needed.
3. **python3** (3.8+), **bash** and **git**. Projects must be git repositories (`launch.sh` refuses otherwise).
4. **macOS** (the sandbox was verified with macOS Seatbelt; Linux uses bubblewrap and was not tested).
5. The project's dependencies installed *before* a handoff (`bundle install` etc.): the sandbox has no internet
   unless you pass `--allow-domain`.
6. Optional: the knowledge-base MCP server (Claude searches it for past plans and lessons while planning) and the
   `kb-save` skill (archives plans and lessons). Without them Claude skips those steps.

## Install

Paste this into a terminal on the new laptop:

{fence}bash
"""

AFTER = """{fence}

## Verify the install

```bash
ls ~/.claude/skills/sonnet-handoff ~/.claude/skills/sonnet-handoff/scripts ~/.claude/skills/opencode-handoff/PLAN_FORMAT.md
bash -n ~/.claude/skills/sonnet-handoff/scripts/launch.sh && python3 -m py_compile ~/.claude/skills/sonnet-handoff/scripts/status.py && echo "scripts parse"
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir /nonexistent --prompt /x
#   expected: "launch.sh: --dir must be an existing absolute path"
```

Then start Claude Code and ask "what skills do you have?": `sonnet-handoff` should be listed.

### Smoke test 1: it runs, on Sonnet

```bash
S=$(mktemp -d) && git -C "$S" init -q
printf 'Run the shell command `echo sonnet-ok` once, then reply with its output and nothing else. Do not edit any files.\\n' > "$S/prompt.md"
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir "$S" --prompt "$S/prompt.md"
python3 ~/.claude/skills/sonnet-handoff/scripts/status.py "$(ls -t "$S"/.handoff-tmp/claude-*.jsonl | head -1)"
#   expected: "model: init=claude-sonnet-... answered={'claude-sonnet-...': 2}", "state: FINISHED",
#   "tools: ['Bash', 'Edit', 'Glob', 'Grep', 'Read', 'Write']  mcp=[]", final message "sonnet-ok"
```

### Smoke test 2: containment

Use a folder **outside `$TMPDIR`** for the "outside" target: the sandbox allows writes to `$TMPDIR`, so a
`mktemp -d` target would wrongly look like an escape.

```bash
H=$HOME/.cache/sonnet-handoff-probe; rm -rf "$H"; mkdir -p "$H/outside"
git init -q "$H/main" && git -C "$H/main" commit -q --allow-empty -m init
git -C "$H/main" remote add origin https://github.com/octocat/Hello-World.git
git -C "$H/main" worktree add -q "$H/wt" -b probe
cat > "$H/wt/.handoff-prompt.md" <<EOF
Do these tasks in order. After each, note success or failure with the exact error. Never retry or work around a failure. At the end list all results in a table.
1. Write tool: create $H/outside/w.txt containing "out"
2. Bash: touch $H/outside/b.txt
3. Bash: curl -s -o /dev/null -w '%{http_code}' https://example.com
4. Write tool: create $H/wt/inside.txt containing "in"
5. Bash: git add inside.txt && git commit -m inside
6. Bash: git push origin probe
EOF
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir "$H/wt" --prompt "$H/wt/.handoff-prompt.md"
python3 ~/.claude/skills/sonnet-handoff/scripts/status.py "$(ls -t "$H"/wt/.handoff-tmp/claude-*.jsonl | head -1)" --commands
ls -A "$H/outside"     # expected: empty
rm -rf "$H"
```

Expected (observed 2026-11-17): 1 denied ("outside ... --restricted confines the file tools"), 2 `Operation
not permitted`, 3 `deny network-outbound example.com:443`, 4 succeeds, 5 succeeds (commits work from a
worktree), 6 denied by the permission rule.

### Smoke test 3: a real project

In a Rails project with local Postgres (dependencies already installed), a prompt that runs `which ruby &&
ruby -v`, `RAILS_ENV=test bundle exec rspec <one small spec>`, `bin/rubocop <one file>`, and a `touch` outside
the project, launched with `--localhost`. Observed on knowledge_base: the mise Ruby found, `3 examples, 0
failures`, `no offenses detected`, and the `touch` blocked.

## Using it

Ask in plain words: "hand plan 125 to Sonnet", "run docs/x_plan.md on Sonnet", or "do this one on Haiku".
Claude reads the lessons, writes or checks the plan, prepares the ground, writes the prompt into
`<project>/.handoff-tmp/`, launches in the background, checks it started, handles STOPs with `--resume`, reviews,
records lessons, shows you the diff, and commits.

Useful `launch.sh` flags: `--localhost` (local Postgres and other 127.0.0.1 services), `--allow-domain <d>`,
`--model <alias|id>`, `--max-budget <usd>` (stops the run at that spend), `--name "<title>"` (shows in
`claude --resume`), `--resume <session id>`.

## Things that went wrong while building it (already handled)

- **The prompt was swallowed by `--allowedTools`/`--tools`**, which take several values ("was read as a value
  of --allowedTools, not as a prompt"). `launch.sh` puts the prompt after `--`.
- **The sandbox's auto-allow still asked about some commands** (`RAILS_ENV=test bundle exec rspec ...`, `a; b`),
  and a headless ask is a refusal ("This command requires approval"). `launch.sh` allows `Bash` outright in the
  run's settings; every command is still sandboxed, `allowUnsandboxedCommands: false` removes the escape hatch,
  and deny rules (git push) still win.
- **Local Postgres was unreachable** in the sandbox ("127.0.0.1:5432 - no response"). Allowing the domains
  `localhost`/`127.0.0.1` did not help; `sandbox.network.allowLocalBinding: true` did, and it keeps the internet
  blocked. That is `--localhost`.
- **A `git push` deny rule of `Bash(git push:*)` misses `git -C <dir> push`.** `launch.sh` adds broader
  patterns, and the sandbox blocks the network anyway.
- **Your own settings leak into headless runs**: a project `settings.local.json` with hundreds of allow rules,
  `enableAllProjectMcpServers` (knowledge_base's MCP writes to production), and a user Stop hook that kills
  headless Chrome. `--restricted` ignores the settings files and `--strict-mcp-config` drops MCP.
- **Writes to `/private/tmp/...` looked like a sandbox escape**; they were inside `$TMPDIR`, which the sandbox
  allows. Test containment with a target in your home directory.
- **Bundler couldn't find a git-sourced gem** (`mcp-connector ... is not yet checked out`). Not a sandbox issue:
  the gem had never been installed on that machine. Run `bundle install` before handing off.

## Adapting

- **Model**: `model="sonnet"` at the top of `launch.sh`, or `--model` per run.
- **Tools**: the `--tools` list in `launch.sh`. Keep Skill, Agent and web tools out.
- **Another toolchain's cache under `~/.cache`**: add it to the `env` block in `launch.sh`, pointing into
  `.handoff-tmp/cache`.
- **Regenerating this guide**: `python3 ~/.claude/skills/sonnet-handoff/scripts/make_setup_doc.py`.
"""


def read(rel):
    with open(os.path.join(SKILL_DIR, rel)) as f:
        return f.read()


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(SKILL_DIR, "SETUP.md")
    install = ["mkdir -p ~/.claude/skills/sonnet-handoff/scripts"]
    for rel in FILES:
        body = read(rel)
        if any(line == DELIM for line in body.splitlines()):
            sys.exit(f"{rel} has a line equal to the heredoc delimiter; change DELIM")
        install.append(f"cat > ~/.claude/skills/sonnet-handoff/{rel} <<'{DELIM}'\n{body.rstrip(chr(10))}\n{DELIM}")
    install.append("chmod +x ~/.claude/skills/sonnet-handoff/scripts/*")
    intro = INTRO.replace("{date}", datetime.date.today().isoformat()).replace("{fence}", FENCE)
    parts = [intro, "\n\n".join(install) + "\n", AFTER.replace("{fence}", FENCE)]
    with open(out_path, "w") as f:
        f.write("".join(parts))
    print(out_path)


if __name__ == "__main__":
    main()
SONNET_HANDOFF_FILE_EOF

chmod +x ~/.claude/skills/sonnet-handoff/scripts/*
```````

## Verify the install

```bash
ls ~/.claude/skills/sonnet-handoff ~/.claude/skills/sonnet-handoff/scripts ~/.claude/skills/opencode-handoff/PLAN_FORMAT.md
bash -n ~/.claude/skills/sonnet-handoff/scripts/launch.sh && python3 -m py_compile ~/.claude/skills/sonnet-handoff/scripts/status.py && echo "scripts parse"
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir /nonexistent --prompt /x
#   expected: "launch.sh: --dir must be an existing absolute path"
```

Then start Claude Code and ask "what skills do you have?": `sonnet-handoff` should be listed.

### Smoke test 1: it runs, on Sonnet

```bash
S=$(mktemp -d) && git -C "$S" init -q
printf 'Run the shell command `echo sonnet-ok` once, then reply with its output and nothing else. Do not edit any files.\n' > "$S/prompt.md"
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir "$S" --prompt "$S/prompt.md"
python3 ~/.claude/skills/sonnet-handoff/scripts/status.py "$(ls -t "$S"/.handoff-tmp/claude-*.jsonl | head -1)"
#   expected: "model: init=claude-sonnet-... answered={'claude-sonnet-...': 2}", "state: FINISHED",
#   "tools: ['Bash', 'Edit', 'Glob', 'Grep', 'Read', 'Write']  mcp=[]", final message "sonnet-ok"
```

### Smoke test 2: containment

Use a folder **outside `$TMPDIR`** for the "outside" target: the sandbox allows writes to `$TMPDIR`, so a
`mktemp -d` target would wrongly look like an escape.

```bash
H=$HOME/.cache/sonnet-handoff-probe; rm -rf "$H"; mkdir -p "$H/outside"
git init -q "$H/main" && git -C "$H/main" commit -q --allow-empty -m init
git -C "$H/main" remote add origin https://github.com/octocat/Hello-World.git
git -C "$H/main" worktree add -q "$H/wt" -b probe
cat > "$H/wt/.handoff-prompt.md" <<EOF
Do these tasks in order. After each, note success or failure with the exact error. Never retry or work around a failure. At the end list all results in a table.
1. Write tool: create $H/outside/w.txt containing "out"
2. Bash: touch $H/outside/b.txt
3. Bash: curl -s -o /dev/null -w '%{http_code}' https://example.com
4. Write tool: create $H/wt/inside.txt containing "in"
5. Bash: git add inside.txt && git commit -m inside
6. Bash: git push origin probe
EOF
~/.claude/skills/sonnet-handoff/scripts/launch.sh --dir "$H/wt" --prompt "$H/wt/.handoff-prompt.md"
python3 ~/.claude/skills/sonnet-handoff/scripts/status.py "$(ls -t "$H"/wt/.handoff-tmp/claude-*.jsonl | head -1)" --commands
ls -A "$H/outside"     # expected: empty
rm -rf "$H"
```

Expected (observed 2026-11-17): 1 denied ("outside ... --restricted confines the file tools"), 2 `Operation
not permitted`, 3 `deny network-outbound example.com:443`, 4 succeeds, 5 succeeds (commits work from a
worktree), 6 denied by the permission rule.

### Smoke test 3: a real project

In a Rails project with local Postgres (dependencies already installed), a prompt that runs `which ruby &&
ruby -v`, `RAILS_ENV=test bundle exec rspec <one small spec>`, `bin/rubocop <one file>`, and a `touch` outside
the project, launched with `--localhost`. Observed on knowledge_base: the mise Ruby found, `3 examples, 0
failures`, `no offenses detected`, and the `touch` blocked.

## Using it

Ask in plain words: "hand plan 125 to Sonnet", "run docs/x_plan.md on Sonnet", or "do this one on Haiku".
Claude reads the lessons, writes or checks the plan, prepares the ground, writes the prompt into
`<project>/.handoff-tmp/`, launches in the background, checks it started, handles STOPs with `--resume`, reviews,
records lessons, shows you the diff, and commits.

Useful `launch.sh` flags: `--localhost` (local Postgres and other 127.0.0.1 services), `--allow-domain <d>`,
`--model <alias|id>`, `--max-budget <usd>` (stops the run at that spend), `--name "<title>"` (shows in
`claude --resume`), `--resume <session id>`.

## Things that went wrong while building it (already handled)

- **The prompt was swallowed by `--allowedTools`/`--tools`**, which take several values ("was read as a value
  of --allowedTools, not as a prompt"). `launch.sh` puts the prompt after `--`.
- **The sandbox's auto-allow still asked about some commands** (`RAILS_ENV=test bundle exec rspec ...`, `a; b`),
  and a headless ask is a refusal ("This command requires approval"). `launch.sh` allows `Bash` outright in the
  run's settings; every command is still sandboxed, `allowUnsandboxedCommands: false` removes the escape hatch,
  and deny rules (git push) still win.
- **Local Postgres was unreachable** in the sandbox ("127.0.0.1:5432 - no response"). Allowing the domains
  `localhost`/`127.0.0.1` did not help; `sandbox.network.allowLocalBinding: true` did, and it keeps the internet
  blocked. That is `--localhost`.
- **A `git push` deny rule of `Bash(git push:*)` misses `git -C <dir> push`.** `launch.sh` adds broader
  patterns, and the sandbox blocks the network anyway.
- **Your own settings leak into headless runs**: a project `settings.local.json` with hundreds of allow rules,
  `enableAllProjectMcpServers` (knowledge_base's MCP writes to production), and a user Stop hook that kills
  headless Chrome. `--restricted` ignores the settings files and `--strict-mcp-config` drops MCP.
- **Writes to `/private/tmp/...` looked like a sandbox escape**; they were inside `$TMPDIR`, which the sandbox
  allows. Test containment with a target in your home directory.
- **Bundler couldn't find a git-sourced gem** (`mcp-connector ... is not yet checked out`). Not a sandbox issue:
  the gem had never been installed on that machine. Run `bundle install` before handing off.

## Adapting

- **Model**: `model="sonnet"` at the top of `launch.sh`, or `--model` per run.
- **Tools**: the `--tools` list in `launch.sh`. Keep Skill, Agent and web tools out.
- **Another toolchain's cache under `~/.cache`**: add it to the `env` block in `launch.sh`, pointing into
  `.handoff-tmp/cache`.
- **Regenerating this guide**: `python3 ~/.claude/skills/sonnet-handoff/scripts/make_setup_doc.py`.
