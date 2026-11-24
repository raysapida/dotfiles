#!/usr/bin/env python3
"""Generate SETUP.md: a self-contained guide for recreating this skill on
another computer, built from the skill's current files so it never drifts.

usage: make_setup_doc.py [OUTPUT]   (default: <skill dir>/SETUP.md)
Re-run after changing any skill file.
"""
import datetime
import os
import sys

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [
    "SKILL.md",
    "PLAN_FORMAT.md",
    "PROMPT_TEMPLATE.md",
    "REVIEW.md",
    "scripts/sessions.py",
    "scripts/launch.sh",
    "scripts/status.py",
    "scripts/pick_model.py",
    "scripts/plan_check.sh",
    "scripts/make_setup_doc.py",
]
DELIM = "OPENCODE_HANDOFF_FILE_EOF"
LANG = {".md": "markdown", ".py": "python", ".sh": "bash"}


def read(rel):
    with open(os.path.join(SKILL_DIR, rel)) as f:
        return f.read()


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(SKILL_DIR, "SETUP.md")
    parts = []
    parts.append(f"""# Setting up the `opencode-handoff` Claude Code skill

Generated {datetime.date.today().isoformat()} from the skill's own files by
`scripts/make_setup_doc.py`. Regenerate it after changing the skill.

## What the skill does

Claude writes an **executable plan**: exact steps, verify commands with
expected output, and stop conditions. It hands the plan to an **opencode**
session, which runs it unattended on a cheaper model (headless
`opencode run`). Claude then monitors the run and **always reviews the
result itself**. It uses one plan per handoff.

It triggers when you ask to run a plan "in opencode", "on GLM", or with a
smaller or lower-powered model.

## What's in the directory

```
~/.claude/skills/opencode-handoff/
├── SKILL.md                 # the skill itself: triggers, fixed rules, 8-step workflow
├── PLAN_FORMAT.md           # how to write a plan a smaller model can execute
├── PROMPT_TEMPLATE.md       # the handoff prompt and the continuation prompt
├── REVIEW.md                # Claude's review checklist after a run
├── SETUP.md                 # this guide (generated; not needed at run time)
└── scripts/
    ├── sessions.py          # list recent opencode sessions for a project
    ├── launch.sh            # start a headless run with the reliable flags
    ├── status.py            # check a run: started, hung, refused, finished, report
    ├── pick_model.py        # recommend DeepSeek (off-peak) or GLM (peak); Inkling as a third option
    ├── plan_check.sh        # EXPERIMENTAL: cheap read-only model reviews a plan before launch
    └── make_setup_doc.py    # regenerate SETUP.md from the files above
```

| File | Kind | What it's for | When it's used |
|---|---|---|---|
| `SKILL.md` | Skill entry point | Frontmatter `name`/`description` (what Claude sees when choosing a skill), the two fixed rules (one plan per handoff; Claude always reviews), the workflow and rules for Claude. | Loaded whenever the skill triggers. |
| `PLAN_FORMAT.md` | Reference | Required plan sections: drift check, current state, scope, steps with Verify and expected output, STOP conditions. Also the rules learned the hard way (expected values from real data, narrow STOP conditions, nothing interactive, say *where* a check must run). | Workflow step 1, while Claude writes the plan. |
| `PROMPT_TEMPLATE.md` | Reference | Fill-in handoff prompt with the unattended-mode rules word for word (temp files inside the project, read outside files via the shell, stop on any refusal, nothing interactive), plus a continuation template. | Step 4, and any follow-up to the same session. |
| `REVIEW.md` | Reference | Checklist: commits and scope, nothing committed that shouldn't be, project conventions, run tests yourself, trace every path to anything risky, look for dead helpers that skip a guard, decide on findings, report to the user. | Step 8, after every run. |
| `SETUP.md` | Generated doc | Everything needed to recreate the skill elsewhere: overview, this directory map, prerequisites, installer, verification, pitfalls, full file contents. | Only for installing or sharing the skill. |
| `scripts/sessions.py` | Python (stdlib) | `sessions.py [--dir DIR] [--all] [-n N]`: lists sessions from `opencode session list --format json`, filtered to the project directory, newest first, with each session's last handoff model read from `launch.sh`'s logs (opencode doesn't record it). | Step 3, so Claude can recommend which session to use. |
| `scripts/launch.sh` | Bash | `launch.sh --dir PROJECT --prompt ABS_FILE (--session ID \\| --new "title") [--model M] [--log FILE] [--no-permission-check] [--agent NAME] [--archived]`. Validates the inputs, requires opencode v2 and a project `opencode.json` that denies outside work, pins opencode's default model from its config, runs `opencode run --standalone --print-logs --log-level info --format json ...` from the project directory, retries startup hangs, logs to `~/.cache/opencode-handoff/`, and appends `EXIT n`. Prints the log path first. | Step 5 (run in the background). |
| `scripts/status.py` | Python (stdlib) | `status.py LOG [--session ID] [--report] [--tail N]`: state from the log (`STARTING`, `RUNNING`, `HUNG AT STARTUP` after 45 s with no model call, `FINISHED`), `DENIED` tool calls, provider errors and limits, the last events, then (`opencode session export`) the session's last steps and, with `--report`, the agent's latest full text. Exports to a temp file, because piped output can arrive truncated. | Step 6 (confirm start and progress) and step 7 (read the report). |
| `scripts/pick_model.py` | Python (stdlib) | `pick_model.py [--json]`: recommends `ollama-cloud/deepseek-v4-pro` during Ollama Cloud off-peak hours (outside 12:00–18:00 UTC on weekdays, all weekend; DeepSeek is half price then) and `ollama-cloud/glm-5.3` during peak, with the alternatives (including `ollama-cloud/inkling-2-small`, always offered third) and the reason. | Step 3, to order the model question. |
| `scripts/plan_check.sh` | Bash | EXPERIMENTAL. `plan_check.sh --dir PROJECT --plan ABS_PLAN [--model M]`: runs `launch.sh` with opencode's read-only `plan` agent (`--agent plan --archived`, default `ollama-cloud/deepseek-v4.1-flash`) to list ambiguous steps, stale quotes, vague Verify output and missing STOPs. Snapshots git state before and after and exits 3 if the repo changed. | Optional step 2b, before choosing the session. |
| `scripts/make_setup_doc.py` | Python (stdlib) | Rebuilds `SETUP.md` from the files listed in `FILES`. Refuses if a file has a line equal to the heredoc delimiter. | After any change to the skill. |

Runtime files the skill creates (not part of the install):
- `~/.cache/opencode-handoff/<timestamp>.log`: one log per launch.
- `<project>/.handoff-tmp/`: temp folder for the agent, which Claude creates and excludes from git before launching.

## Prerequisites on the new computer

1. **Claude Code**, installed. Personal skills live in `~/.claude/skills/`.
2. **opencode v2** (2.x), installed and logged in, with a default model in
   `~/.config/opencode/opencode.json`, e.g. `"model": "ollama-cloud/glm-5.3"`.
   Check with `opencode --version` (must print v2.x), then `opencode run "say hi"`.
3. **python3** (3.8+) and **bash**. The scripts use only the standard library.
4. The project you'll hand plans to, cloned locally. `launch.sh` runs opencode
   from the folder passed to `--dir`. v2 doesn't refuse work outside it, so
   the project needs an `opencode.json` with deny rules (SKILL.md, step 2).

## Install

**Option A: paste into a terminal.** This recreates every file below:

`````bash
""")
    install = ["mkdir -p ~/.claude/skills/opencode-handoff/scripts"]
    for rel in FILES:
        body = read(rel)
        if any(line == DELIM for line in body.splitlines()):
            sys.exit(f"{rel} has a line equal to the heredoc delimiter; change DELIM")
        install.append(f"cat > ~/.claude/skills/opencode-handoff/{rel} <<'{DELIM}'\n"
                       f"{body.rstrip(chr(10))}\n{DELIM}")
    install.append("chmod +x ~/.claude/skills/opencode-handoff/scripts/*")
    parts.append("\n\n".join(install) + "\n`````\n")
    parts.append("""
**Option B: ask Claude Code** on the new computer: "Create the skill described
in this document under ~/.claude/skills/opencode-handoff, with exactly these
file contents." Give it this file, or the knowledge-base entry.

## Verify the install

```bash
ls ~/.claude/skills/opencode-handoff ~/.claude/skills/opencode-handoff/scripts
python3 ~/.claude/skills/opencode-handoff/scripts/sessions.py --dir <your project>
~/.claude/skills/opencode-handoff/scripts/launch.sh --dir /nonexistent --prompt /x --session s
#   expected: "launch.sh: --dir must be an existing directory"
```

Start a new Claude Code session. `opencode-handoff` should appear in its
skills list.

## First real handoff (smoke test)

1. In your project, ask Claude: "Write a tiny plan that adds a comment line
   to README and commits it, then hand it to opencode."
2. Claude lists the project's sessions and asks whether to continue one or
   start a new one. Then it launches in the background and checks
   `status.py` about 30 s later.
3. When it finishes, Claude reviews the commit and reports.

## Things that went wrong before (already handled by the skill)

- **Some launches hang at startup and never reach the model** (about 1 in 5
  with opencode v2). `launch.sh` retries them itself, up to twice, and kills
  the `opencode serve --stdio` child as well. `status.py` reports
  `HUNG AT STARTUP` if the retries also hang; kill the processes and relaunch
  (a hang never touches the session).
- **opencode v2 changed the headless interface** (`--dir` removed, lower-case
  `--log-level`, JSON events instead of debug log lines, `opencode session
  export`, tools renamed to `shell`/`path`). The scripts target v2 and
  `launch.sh` refuses v1. SKILL.md's "opencode v2 notes" has the full table.
- **v2 headless runs don't refuse work outside the project** (v1 auto-rejected
  it and ended the turn). Each project needs an `opencode.json` with
  `permission.external_directory: "deny"` and shell deny rules (`*../*`,
  `cd *`, secret paths); `launch.sh` checks for them. Denied calls return an
  error and the turn goes on; `status.py` lists them as `DENIED`.
- **A launch from the wrong directory sent a garbled prompt.** `launch.sh`
  requires an absolute prompt path and runs from `--dir`.
- **Session export read through a pipe arrived truncated.** `status.py`
  exports to a file.
- **An open opencode window can't show a headless run live.** It only sees
  saved messages after a refresh. Don't type in the session during a run.

## Adapting to another setup

- **Different models:** Claude asks which model to use for each handoff
  (DeepSeek V4 Pro, GLM-5.3 or Inkling 2 Small, ordered by `pick_model.py`).
  Edit the `DEEPSEEK`/`GLM`/`INKLING` constants there, and the model question in SKILL.md step 3,
  to offer other models.
- **Project conventions** (commit rules, hooks, line endings, files never to
  stage) belong in each plan's Git workflow section and in the prompt's "How
  to work" list, not in the skill.
""")
    parts.append("\n## File reference\n\nThe same contents as the installer, for reading:\n")
    for rel in FILES:
        body = read(rel).rstrip("\n")
        lang = LANG.get(os.path.splitext(rel)[1], "")
        parts.append(f"\n### `{rel}`\n\n`````{lang}\n{body}\n`````\n")
    with open(out_path, "w") as f:
        f.write("".join(parts))
    print(out_path)


if __name__ == "__main__":
    main()
