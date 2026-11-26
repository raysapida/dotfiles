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
