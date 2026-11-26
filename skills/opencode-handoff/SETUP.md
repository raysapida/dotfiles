# Setting up the `opencode-handoff` Claude Code skill

Generated 2026-11-24 from the skill's own files by
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
| `scripts/launch.sh` | Bash | `launch.sh --dir PROJECT --prompt ABS_FILE (--session ID \| --new "title") [--model M] [--log FILE] [--no-permission-check] [--agent NAME] [--archived]`. Validates the inputs, requires opencode v2 and a project `opencode.json` that denies outside work, pins opencode's default model from its config, runs `opencode run --standalone --print-logs --log-level info --format json ...` from the project directory, retries startup hangs, logs to `~/.cache/opencode-handoff/`, and appends `EXIT n`. Prints the log path first. | Step 5 (run in the background). |
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
mkdir -p ~/.claude/skills/opencode-handoff/scripts

cat > ~/.claude/skills/opencode-handoff/SKILL.md <<'OPENCODE_HANDOFF_FILE_EOF'
---
name: opencode-handoff
description: Writes an executable plan, hands it to an opencode session to run unattended on a cheaper model (headless `opencode run`), monitors the run, and reviews the result. Use when the user wants a plan executed "in opencode", by GLM, DeepSeek, Inkling or another smaller model, or asks to delegate/hand off/test a plan with a lower-powered agent.
---

# opencode handoff

Claude plans and reviews; an opencode agent (usually a smaller model) executes.
The plan is the contract: a smaller model does well with exact steps and
stop conditions, and badly with judgement calls.

Two fixed rules:
- **One plan per handoff.** Don't chain plans in one prompt. Review each
  plan's result before handing off the next one.
- **Claude always reviews.** Never delegate the review to another opencode
  agent. Review is where plan mistakes and skipped guards are caught.

Scripts are in `~/.claude/skills/opencode-handoff/scripts/`:
`sessions.py` (list sessions), `launch.sh` (start a run), `status.py` (check a run),
`pick_model.py` (recommend a model), `plan_check.sh` (experimental pre-launch plan review).
They target **opencode v2** (2.x); `launch.sh` refuses other versions. See
[opencode v2 notes](#opencode-v2-notes) for what changed from v1.

## Workflow

1. **Write the plan** as a file the agent can read, following
   [PLAN_FORMAT.md](PLAN_FORMAT.md). Every expected number comes from a real
   log or measurement, never an estimate. Commit it if the project tracks plans.
   Before writing, gather what earlier handoffs learned (see [LESSONS.md](LESSONS.md)):
   - Read `lessons/<project>.md` in this skill's folder, if it exists.
   - Search the knowledge base once with `RetrieveContext(query: "<feature or
     area>", kind: "document", project: "<project>")` for past plans, design
     docs and lessons in this project. Drop `project` to find lessons from
     other projects when this one has none.
   - Turn each lesson that applies into plan text: a gotcha under Current
     state, a STOP condition, or a Verify step. Name the lesson's date.
   Skip the search silently if no knowledge-base MCP server is connected.
2. **Prepare the ground** before launching:
   - Create any files only a human may create (allowlists, local config,
     credentials), and exclude them from git (`.gitignore` or `.git/info/exclude`)
     so the agent can't commit them.
   - Create a temp folder **inside the project**, e.g. `<project>/.handoff-tmp/`
     (exclude it too).
   - Give the project an `opencode.json` that **denies work outside it**.
     opencode v2 headless runs don't refuse it on their own. `launch.sh`
     checks for at least the first two rules:
     ```json
     "permission": {
       "external_directory": "deny",
       "shell": { "*": "allow", "*../*": "deny", "cd *": "deny",
                  "*git push*": "deny", "*<secret path>*": "deny" }
     }
     ```
     `external_directory` blocks the file tools outside the project, plus `cd ..`.
     The shell can still read and write absolute paths elsewhere, so add a
     `"*<path>*": "deny"` rule for every secret location. Put `"*"` first
     (the last matching rule wins). To let file tools read one outside folder,
     use `"external_directory": {"*": "deny", "/that/dir/*": "allow"}`.
   - Make sure nothing else will build, flash, or use shared hardware while it runs.
2b. **Plan check (EXPERIMENTAL, optional).** Before choosing the session, you
   may have a cheap model read the plan as the executor would:
   `scripts/plan_check.sh --dir <project> --plan <abs plan>` (background; default
   model `ollama-cloud/deepseek-v4.1-flash`), then `scripts/status.py <log> --report`.
   It runs opencode's read-only `plan` agent in an archived session and lists
   ambiguous steps, stale file:line quotes, vague Verify output and missing STOPs.
   - Its findings are suggestions. Check each against the code yourself; fix
     the plan for real ones and ignore the rest. It never replaces your review.
   - The `plan` agent is only partly read-only (opencode v2.3.2, checked
     2026-11-24 with `opencode debug agents`): its edit tool is denied, but
     its shell inherits the project's `"*": "allow"`, so a redirect could
     write. The model refused writes when asked in a smoke test, but that is
     the model's choice, not a block. The script's guard snapshots git state
     and exits 3 with `PLAN CHECK CHANGED THE REPO` if anything changed:
     stop, show the user, and restore before going on.
   - Tell the user it's experimental, and record in `lessons/<project>.md`
     what it found: useful findings, false alarms, minutes and tokens taken.
     Those notes decide whether it stays, becomes a default step, or goes.
3. **Choose the session and the model.** Run `scripts/sessions.py --dir <project>`
   and `scripts/pick_model.py`, then ask both questions in one AskUserQuestion call:
   - Session: continue one of these (it keeps context from earlier plans) or
     start a new one. Remind them not to type in that session while it runs.
   - Model: **DeepSeek V4 Pro** (`ollama-cloud/deepseek-v4-pro`),
     **GLM-5.3** (`ollama-cloud/glm-5.3`) or **Inkling 2 Small**
     (`ollama-cloud/inkling-2-small`). List `pick_model.py`'s recommendation
     first, marked "(Recommended)", and put its `why` line in the description.
     It recommends DeepSeek off-peak (half price on Ollama Cloud: outside
     12:00–18:00 UTC on weekdays, all weekend) and GLM during peak hours.
     Always list Inkling third, described as "cheapest at any hour; on trial".
     After an Inkling run, record in `lessons/<project>.md` how it followed the
     plan (STOPs honoured, scope kept, stream cutoffs, retries).
   Skip the model question only if the user already named a model for this handoff.
   `sessions.py` shows each session's last handoff model (from the launch logs).
   Recommend a session as follows, and say why in the option's description:
   - **Same model as last time:** continue the project's existing session for
     that model. Fresh sessions re-read AGENTS.md, the plan and the code each
     time, and several fresh sessions on one codebase burned through GLM-5.3
     tokens; a reused session keeps that context.
   - **Switching models:** start a new session. Continuing another model's
     session works, but the new model must process the whole history without
     a cache, and a trial (e.g. Inkling) can't separate one model's habits
     from the other's.
   - **Large or messy history:** start a new session when the session is
     roughly 150–200K tokens, or after a phase with STOPs and long
     back-and-forth. Open it with a compact verified-current-state prompt.
4. **Write the handoff prompt** to an absolute path using
   [PROMPT_TEMPLATE.md](PROMPT_TEMPLATE.md).
5. **Launch in the background** (the command returns when the turn ends):
   `scripts/launch.sh --dir <project> --prompt <abs prompt> --session <id>`
   (or `--new "<title>"`) `--model <model chosen in step 3>`. Always pass
   `--model`; without it `launch.sh` falls back to opencode's configured default.
   Continuations use the same model unless the user changes it. Note the log
   path it prints first.
6. **Confirm it started** about 60 s later with `scripts/status.py <log>`.
   About 1 launch in 5 hangs at startup and prints nothing;
   `launch.sh` kills and retries that itself (up to twice, logged as
   `launch.sh: no model call ...`, shown as `RETRYING`). Only a final
   `HUNG AT STARTUP` needs you to kill the `opencode run` process and its
   `opencode serve --stdio` child, then relaunch; a hang never touches the session. Otherwise wait for the
   background-task notification; use `status.py <log> --session <id>` when
   the user asks for progress.
7. **When it ends**, run `status.py <log> --session <id> --report`:
   - `DENIED` lines are tool calls the permission rules blocked. In v2 the
     agent gets an error and its turn **continues**, so check what it did
     next: it should have stopped and reported, not found a way around.
     If the denial was a plan mistake, change the plan or the rules.
   - `FINISHED (exit 1)` with no model call usually means a CLI flag error:
     read the log's last lines.
   - A STOP report: decide whether the plan or the code is wrong. Fix the plan
     if its condition was too strict, and say so. Then send a continuation that
     states the verified current state and exactly what to do next.
8. **Review** with [REVIEW.md](REVIEW.md) before telling the user it's done.
   Verify safety-critical claims yourself; don't repeat the agent's report.
   Fix small review findings directly instead of another round trip.
9. **Record lessons** from the review in `lessons/<project>.md`, following
   [LESSONS.md](LESSONS.md), then save that file with the `kb-save` skill
   (tags `lessons`, `opencode-handoff`). Do this even when the run stopped:
   STOPs teach the most.
10. **Archive the plan** once the review passes and the plan's status records
    the outcome: save the plan file with the `kb-save` skill, with
    `status: completed` and the tag `opencode-handoff`. Skip this if the run ended on a STOP
    or the review left findings unresolved, and say that it wasn't archived.
    Archive again after any later edit to the plan; saving the same path
    updates it.

## Continuations

Send follow-ups to the same session with a new prompt file. Start by stating
the verified current state (commits, what's staged, what's left). Then give
the rules again, and name the next step. Keep one prompt per file so the
history is auditable.

## opencode v2 notes

opencode 2.x (e.g. 2.2.5, Homebrew `opencode-v2`) changed the headless
interface. Sessions from v1 survive the upgrade and can be continued.

| v1 | v2 | Handled by |
| --- | --- | --- |
| `opencode run --dir DIR` | flag removed; the working directory is the project | `launch.sh` cds to `--dir` |
| `--log-level DEBUG` | lower case only (`debug`, `info`) | `launch.sh` |
| shared process | runs via a background service; `--standalone` gives each run a private server (`opencode serve --stdio` child) | `launch.sh` passes `--standalone` and kills the child on a hang |
| debug log lines `message=stream`, `session.id=` | not logged; use `--format json` (JSON lines: `step_start`, `tool_use`, `text`, `step_finish`, with `sessionID`) | `launch.sh` / `status.py` |
| approvals auto-rejected, turn ends | nothing outside the project is refused by default; denied calls return `Permission denied` and the turn goes on | project `opencode.json` rules (step 2); `status.py` prints `DENIED` |
| `opencode export ID` | `opencode session export ID`; messages are `{type, time, content[]}` (tool parts: `name`, `state.input.path`) | `status.py` |
| tools `bash`, `filePath` | `shell`, `path` | prompts must not name the old tools |
| `opencode session list` | lists the project of the working directory | `sessions.py` runs it from `--dir` |

## Rules for Claude

- Launch from the project directory with absolute paths only. A relative path
  once sent a garbled prompt to the wrong project.
- Never type into or attach to the user's open opencode window.
- After an opencode upgrade, test a tiny run in a scratch folder before the
  next handoff: check the flags, the JSON events, and that the permission
  rules deny a `../` write.
- Never edit `scripts/launch.sh` while a launch is running: bash reads the
  script as it goes, and finishes from the middle of the new version.
- One run per session at a time. Don't start another turn until the notification arrives.
- Code the agent writes follows the project's rules. Check hooks, line endings
  and commit conventions in review.
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/PLAN_FORMAT.md <<'OPENCODE_HANDOFF_FILE_EOF'
# Plan format for a smaller executing model

A plan is executable when a model that can't make judgement calls can still
follow it, and knows when to stop.

## Required sections

1. **Header block**
   - Executor instructions: follow the steps in order, run every Verify, and
     stop and report on any STOP condition.
   - A **drift check**: `git log --oneline -1` must be commit X or a
     descendant, and `git diff --stat X..HEAD -- <files>` must be empty.
     Otherwise STOP.
2. **Status**: priority, effort, risk, dependencies, branch, and the commit the
   plan was written against.
3. **Why this matters**: two or three sentences with evidence (log lines,
   file:line). The agent uses it to judge edge cases.
4. **Current state**: quoted code at exact `file:line`, the facts the steps
   rely on, and gotchas (line endings, hooks that stage files, local edits
   that must never be staged).
5. **Scope**: in scope (the only files to touch) and out of scope.
6. **Git workflow**:
   - branch;
   - commit message(s);
   - project commit conventions;
   - "do not push".
7. **Steps**. Each step has exact edits and ends with a **Verify** command and
   its **expected output**.
8. **Test plan**, **Done criteria** (as a checklist), **STOP conditions**, and
   **Maintenance notes**.

## Rules that prevented problems

- **Expected values come from real data.** Take them from an existing log,
  measurement or test run, and name the source ("reference: bench_020.log,
  W2 recovery 25.1 s, pass ≤ 35 s"). An estimated count ("about 115 frames")
  produced a false STOP.
- **Give ranges, not exact moments, for anything timing-based.** Say when an
  event happens relative to something else ("at the first request after the
  window ends").
- **Write STOP conditions narrowly, and list expected differences.** A parity
  check that ignored known harmless differences (a version stamp, a known
  local edit) would have avoided a false STOP.
- **Nothing interactive.** No `git add -p`, editors or prompts. To stage part
  of a file, write a patch into the project temp folder and run
  `git apply --cached --unidiff-zero`.
- **State the one-thing-at-a-time constraints**: one build at a time,
  exclusive hardware, which folder temp files go in.
- **Name the files for each commit**, and say to check `git show --stat HEAD`
  after committing. That catches hooks that stage extra files.
- **Keep safety checks in code, not in prose**, when the plan builds tooling. A
  guard the agent can skip isn't a guard.
- **Say where things must happen.** "Before anything is written" or "before
  flashing" must be explicit. An agent put a pre-flash check after the flash.
- **Split big work into step groups with one commit each,** so a STOP leaves a
  clean, reviewable state.
- **When a plan removes or renames something, search the whole repo for it
  while planning**, including headers and test mocks. Put every hit in the
  steps or in the expected output. A removal plan that only listed the main
  source file missed a header declaration, a second `#ifdef` and two mock
  files; the agent's Step 0 check caught it and stopped.
- **Leave design-level plans (no numbered steps) for Claude**, or refine them
  into steps before handing them off.
- **When you refresh an old plan, re-check every section, not just the line
  numbers.** That includes the drift check base, the Git workflow (the branch
  name) and the scope. The prompt and the plan must agree: when they
  conflicted over the branch, the agent followed the plan and created a new,
  plan-numbered branch.
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/PROMPT_TEMPLATE.md <<'OPENCODE_HANDOFF_FILE_EOF'
# Handoff prompt template

Fill in the `<...>` parts and save the prompt to an absolute path. Keep the
"unattended" rules word for word: each one prevented a stalled or broken run.

```text
You are working in <PROJECT_DIR>. Your task: execute <PLAN NAME> in <REPO/AREA>, and nothing else.

Before doing anything, read:
1. <project instruction files, e.g. AGENTS.md>
2. <runbooks or docs the plan relies on>
3. The plan in full: <ABSOLUTE PLAN PATH>

You are running UNATTENDED. Permission rules deny work outside <PROJECT_DIR>: a denied call returns "Permission denied". So:
- Write temporary files ONLY under <PROJECT_DIR>/<TEMP DIR>/. Never use /tmp or any path outside <PROJECT_DIR>.
- Your read/edit/write tools are denied for paths outside <PROJECT_DIR>, and so are `cd` and `../` in the shell.
  To READ files elsewhere (SDKs, toolchains, ~/.config), use the shell with absolute paths (cat, grep, sed -n).
  Never modify anything outside <PROJECT_DIR>.
- If any tool call is denied or rejected, stop and report what you were trying to do. Do not retry it or
  find another way around it.
- Never run anything interactive (no `git add -p`, no editors, no prompts waiting for input).
- Always use absolute paths for files you create.

How to work:
- Branch: <BRANCH> in <REPO PATH> (confirm with `git branch --show-current`). Current HEAD is <COMMIT>.
- Follow the plan's steps in order. Run every Verify and compare with the expected result. If a STOP
  condition happens, or anything doesn't match the plan, stop and report. Do not work around it.
- <project rules: build limits, hooks, line endings, files never to stage, commit-message rules>
- Do not push.

Setup already done for you (do not change it):
- <files a human created, e.g. allowlists; say they are excluded from git and must never be committed>

Scope limits for unattended running:
- <steps that need a human: implement but do not run; say so in the report>

When finished:
- <update the plan's status/index, in its own commit>
- Report: every commit (hash + message) per repo, test results, the plan's verification tables
  (observed vs expected), what was not run and why, and anything that didn't match the plan.
```

## Continuation prompt (same session)

```text
<What happened: e.g. "Your STOP report on X is accepted" or "Your last tool call was rejected because Y".>
<The decision, and any plan change: "The plan's STOP condition has been updated; re-read it in <path>.">

Same rules as before: <restate the unattended rules in one line each>.

Verified current state: <commits so far, what is staged/uncommitted, files to leave alone>.

Next: <exact next actions, including any review fix to make first as its own commit>.
Then continue the plan from <step> through the end, and give the full report.
```
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/REVIEW.md <<'OPENCODE_HANDOFF_FILE_EOF'
# Reviewing an opencode run

The agent's report is a claim, not a result. Check it before telling the user
the plan is done.

## Every run

- [ ] **Commits:** `git log --oneline <start>..HEAD` matches the report.
      `git show --stat` for each commit touches only the files the plan
      scoped.
- [ ] **Nothing that must stay out was committed:** local config,
      allowlists, secrets, caches (`__pycache__`, build dirs), result folders,
      stray copies in the wrong folder (`git status --short`, `git ls-files`).
- [ ] **Project conventions:** commit-message rules, line endings (look for
      whole-file diffs), hooks that stage extra files, files never to stage.
- [ ] **Tests:** run the test suites yourself, rather than trusting the
      reported pass count.
- [ ] **Clean end state:** the working tree holds only expected leftovers, and
      shared hardware or services are back in their normal state.

## Read the code, not just the tests

- Read the diff of anything safety-critical, and **trace every path** to the
      dangerous action (e.g. every caller of a flash, delete or deploy
      function). A check that exists but runs too late, or a helper nobody
      calls, won't show up in a passing test.
- Look for dead helpers that skip a guard. A later agent may call them.
- Look for silent degradation: an `#if`/flag that falls back to a no-op, a
      default that disables a check, a missing include that changes behaviour.
- Compare each "expected" value in the report with the plan's source data.

## Decide on each finding

- **Small and clear:** fix it yourself as a follow-up commit, with a message
  that says what the review found.
- **The plan was wrong** (a STOP condition too strict, a bad estimate): fix
  the plan, and say so plainly in the continuation and to the user.
- **The agent's code is wrong and the fix is large:** send a continuation
  with the finding, the verified current state and the exact fix.
- Record the outcome in the plan's status or index: executor model, session
  id, result (done, or STOP and why), number of continuations, and follow-up
  commits.
- Record lessons for every finding a better plan would have prevented
  ([LESSONS.md](LESSONS.md)).

## Tell the user

Give a short verdict, what you verified yourself, any gap you found and how
it was fixed, and what still can't be verified (e.g. steps that need a human).
Say plainly when an issue was the plan's fault rather than the agent's.
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/sessions.py <<'OPENCODE_HANDOFF_FILE_EOF'
#!/usr/bin/env python3
"""List recent opencode sessions for a project directory.

usage: sessions.py [--dir DIR] [--all] [-n N]
Prints: id, last update, last handoff model, title. Default dir is the current
directory. opencode doesn't record a session's model, so it comes from
launch.sh's logs in ~/.cache/opencode-handoff/ ("-" if no handoff used it).
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

LOG_GLOB = os.path.expanduser("~/.cache/opencode-handoff/*.log")


def models_by_session():
    """Map session id -> model of the newest handoff log that used it."""
    found = {}
    for path in sorted(glob.glob(LOG_GLOB), key=os.path.getmtime):  # oldest first; newer wins
        try:
            text = open(path, errors="replace").read()
        except OSError:
            continue
        m = re.search(r"^launch: .*?model=(\S+)", text, re.M)
        if not m:
            continue
        ids = re.findall(r"^launch: .*?session=(ses_\w+)", text, re.M)
        ids += re.findall(r'"sessionID":"(ses_\w+)"', text)[:1]
        for sid in ids:
            found[sid] = m.group(1).split("/", 1)[-1]
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.getcwd())
    ap.add_argument("--all", action="store_true", help="all projects")
    ap.add_argument("-n", type=int, default=10)
    a = ap.parse_args()
    want = os.path.realpath(a.dir)
    try:
        # opencode lists the sessions of the project in its working directory,
        # so run it from the requested directory
        out = subprocess.run(["opencode", "session", "list", "--format", "json",
                              "-n", "200"], capture_output=True, text=True,
                             timeout=60, cwd=want)
        sessions = json.loads(out.stdout or "[]")
    except Exception as e:  # noqa: BLE001
        sys.exit(f"could not list opencode sessions: {e}")
    if not a.all:
        sessions = [s for s in sessions
                    if os.path.realpath(s.get("directory", "")) == want]
    if not sessions:
        print(f"no opencode sessions for {want}" if not a.all else "no sessions")
        return
    models = models_by_session()
    for s in sessions[: a.n]:
        t = datetime.datetime.fromtimestamp(s["updated"] / 1000).strftime("%Y-%m-%d %H:%M")
        where = "" if not a.all else f"  [{s.get('directory')}]"
        print(f"{s['id']}  {t}  {models.get(s['id'], '-'):<16}  {s.get('title', '')}{where}")


if __name__ == "__main__":
    main()
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/launch.sh <<'OPENCODE_HANDOFF_FILE_EOF'
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
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/status.py <<'OPENCODE_HANDOFF_FILE_EOF'
#!/usr/bin/env python3
"""Check an opencode handoff: did it start, is it stuck, what is it doing.

usage: status.py LOG_FILE [--session ID] [--report] [--tail N]

Written for opencode v2 (`opencode run --format json`, as launch.sh runs it).
From the launch log: started / reached the model / HUNG at startup /
permission denials / provider errors / exited, plus the last few events.
With --session: message count, last activity, the last N steps from
`opencode session export`, and with --report the agent's latest full text
(its report when finished).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HANG_SECONDS = 45
LIMIT_RE = re.compile(r"usage limit|rate limit|quota|429|credits", re.I)  # also matches type "provider.quota"


def tool_input(inp):
    if not isinstance(inp, dict):
        return str(inp)
    return str(inp.get("command") or inp.get("path") or inp.get("filePath")
               or inp.get("pattern") or "")


def log_state(path):
    try:
        text = open(path, errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path}: {e}")
    events, denied, errors = [], [], []
    for line in text.splitlines():
        if not line.startswith("{"):
            if "level=ERROR" in line:
                m = re.search(r'message="([^"]{0,200})"', line)
                c = re.search(r'cause="([^"]{0,200})', line)   # v2 puts the provider's text here
                errors.append((m.group(1) if m else line[:200]) + (" — " + c.group(1) if c else ""))
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        events.append(e)
        p = e.get("part") or {}
        st = p.get("state") or {}
        if e.get("type") == "tool_use" and st.get("status") == "error" \
                and "Permission denied" in str(st.get("error", "")):
            denied.append(f"{p.get('tool')} {tool_input(st.get('input'))[:120]} -> {st.get('error')}")
        if "error" in str(e.get("type", "")):
            errors.append(json.dumps(e.get("error") or e.get("message") or e)[:240])
    for m in re.finditer(r'"message":"([^"]{0,240})"', text):
        if LIMIT_RE.search(m.group(1)) and m.group(1) not in errors:
            errors.append(m.group(1))
    lm = re.search(r"^launch: dir=(\S+)", text, re.M)
    return {
        "exited": re.findall(r"^EXIT (\d+)$", text, re.M),
        "reached_model": any(e.get("type") == "step_start" for e in events),
        "init": 'message="cli starting"' in text or "message=init" in text,
        "denied": denied,
        "provider_errors": errors,
        "session_ids": list(dict.fromkeys(re.findall(r'"sessionID":"(ses_\w+)"', text))),
        "events": events,
        "dir": lm.group(1) if lm else None,
        "age_s": time.time() - os.path.getmtime(path),
        "first": text.splitlines()[0] if text else "",
    }


def event_summary(e):
    p = e.get("part") or {}
    st = p.get("state") or {}
    t = e.get("type")
    if t == "tool_use":
        return f"TOOL {p.get('tool')} {st.get('status')} {tool_input(st.get('input'))[:110]}"
    if t == "text":
        return "TEXT " + str(p.get("text", "")).strip().replace("\n", " ")[:150]
    return str(t)


def export(session, cwd):
    # `opencode session export` (v2; v1 was `opencode export`). Written to a
    # file because large JSON read through a pipe has arrived truncated.
    with tempfile.NamedTemporaryFile("w+", suffix=".json", delete=False) as f:
        path = f.name
    try:
        with open(path, "w") as out:
            subprocess.run(["opencode", "session", "export", session], stdout=out,
                           stderr=subprocess.DEVNULL, timeout=120,
                           cwd=cwd if cwd and os.path.isdir(cwd) else None)
        return json.load(open(path))
    except (json.JSONDecodeError, subprocess.TimeoutExpired) as e:
        sys.exit(f"could not read session {session} (opencode session export): {e}")
    finally:
        os.unlink(path)


def ts(ms):
    return datetime.datetime.fromtimestamp(ms / 1000).strftime("%H:%M:%S") if ms else "-"


def step_summary(msg):
    # v2 export: {"type": "assistant"|"user"|"system", "content": [...]}; user
    # and system messages carry "text" directly.
    for p in reversed(msg.get("content") or []):
        t = p.get("type")
        if t == "text" and p.get("text", "").strip():
            return "TEXT " + p["text"].strip().replace("\n", " ")[:160]
        if t == "tool":
            st = p.get("state") or {}
            return f"TOOL {p.get('name')} {st.get('status')} {tool_input(st.get('input'))[:120]}".replace("\n", " ")
        if t == "provider.error":
            return "ERROR " + str(p.get("message", ""))[:160]
    if msg.get("error"):
        return "ERROR " + json.dumps(msg["error"])[:160]
    if msg.get("text"):
        return "TEXT " + msg["text"].strip().replace("\n", " ")[:160]
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--session")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--tail", type=int, default=5)
    a = ap.parse_args()

    st = log_state(a.log)
    print(st["first"])
    if st["exited"]:
        state = f"FINISHED (exit {st['exited'][-1]})"
    elif st["reached_model"]:
        state = "RUNNING (reached the model)"
    elif "launch.sh: no model call" in open(a.log, errors="replace").read() and st["age_s"] < HANG_SECONDS * 4:
        state = "RETRYING (launch.sh restarted a startup hang; check again shortly)"
    elif st["init"] and st["age_s"] > HANG_SECONDS:
        state = (f"HUNG AT STARTUP: no model call {int(st['age_s'])}s after start. "
                 "Kill the opencode run process (and its `opencode serve --stdio` child) "
                 "and relaunch; the session was not touched.")
    else:
        state = "STARTING"
    print("state:", state)
    for r in st["denied"]:
        print("DENIED:", r, "(the agent got an error and its turn went on; check how it reacted)")
    if st["provider_errors"]:
        # any limit/quota error wins: a generic error (e.g. "Failed to drain Session")
        # often follows the quota error as the last line
        limits = [e for e in st["provider_errors"] if LIMIT_RE.search(e)]
        last = limits[-1] if limits else st["provider_errors"][-1]
        kind = "PROVIDER LIMIT" if limits else "PROVIDER ERROR"
        print(f"{kind} ({len(st['provider_errors'])}x): {last}")
        if kind == "PROVIDER LIMIT":
            print("  The model provider refused further calls. Wait for the limit to reset or "
                  "switch --model; the session keeps its history, so a continuation can resume it.")
    if st["exited"] and st["exited"][-1] != "0" and not st["reached_model"]:
        print("  Exit before any model call: read the log's last lines (bad flag? see launch.sh).")
    shown = [e for e in st["events"] if e.get("type") in ("tool_use", "text")][-a.tail:]
    if shown and not a.session:
        print("last events:")
        for e in shown:
            print(f"  {ts(e.get('timestamp'))} {event_summary(e)}".replace("\n", " "))

    session = a.session or (st["session_ids"][-1] if st["session_ids"] else None)
    if not session:
        return
    d = export(session, st["dir"])
    msgs = d.get("messages", [])
    last = msgs[-1].get("time", {}).get("created") if msgs else None
    print(f"session {session}: {len(msgs)} messages, last activity {ts(last)}")
    for m in msgs[-a.tail:]:
        print(f"  {ts(m.get('time', {}).get('created'))} {str(m.get('type'))[:4]} | {step_summary(m)}")
    if a.report:
        for m in reversed(msgs):
            if m.get("type") != "assistant":
                continue
            texts = [p["text"] for p in m.get("content") or []
                     if p.get("type") == "text" and p.get("text", "").strip()]
            if texts:
                print("\n--- latest agent text ---\n" + texts[-1])
                break


if __name__ == "__main__":
    main()
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/pick_model.py <<'OPENCODE_HANDOFF_FILE_EOF'
#!/usr/bin/env python3
"""Recommend the handoff model for right now, from Ollama Cloud's peak hours.

usage: pick_model.py [--json]

Ollama Cloud bills some DeepSeek models at half price off-peak. Off-peak is
outside 12:00-18:00 UTC on weekdays, and all day on weekends (ollama.com/pricing,
checked 2026-11-22). GLM has no off-peak rate, so:
  off-peak -> DeepSeek V4 Pro (cheapest, strong on repo bug-fixing)
  peak     -> GLM-5.3          (DeepSeek at full price loses its cost edge)
Inkling 2 Small is always offered as a third option (cheapest at any hour,
$0.30/$1.00 per 1M; no off-peak rate). It is on trial, so it is never the default.
Prints the recommended model first, then the alternatives, and why.
"""
import datetime
import json
import sys

DEEPSEEK = "ollama-cloud/deepseek-v4-pro"
GLM = "ollama-cloud/glm-5.3"
INKLING = "ollama-cloud/inkling-2-small"
PEAK_START, PEAK_END = 12, 18  # UTC hours, weekdays only


def main():
    now = datetime.datetime.now(datetime.timezone.utc)
    weekend = now.weekday() >= 5
    peak = not weekend and PEAK_START <= now.hour < PEAK_END
    if peak:
        rec, alt = GLM, DEEPSEEK
        ends = now.replace(hour=PEAK_END, minute=0, second=0, microsecond=0)
        why = (f"peak hours (weekday {PEAK_START}:00-{PEAK_END}:00 UTC); "
               f"off-peak resumes in {int((ends - now).total_seconds() // 60)} min")
    else:
        rec, alt = DEEPSEEK, GLM
        why = "off-peak (weekend)" if weekend else "off-peak (outside weekday 12:00-18:00 UTC)"
        why += ": DeepSeek V4 Pro is half price"
    if "--json" in sys.argv:
        print(json.dumps({"recommended": rec, "alternatives": [alt, INKLING], "peak": peak,
                          "utc": now.isoformat(timespec="minutes"), "why": why}))
    else:
        print(f"recommended: {rec}\nalternatives: {alt}, {INKLING} (on trial)\n"
              f"why: {why} (now {now:%a %H:%M} UTC)")


if __name__ == "__main__":
    main()
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/plan_check.sh <<'OPENCODE_HANDOFF_FILE_EOF'
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
OPENCODE_HANDOFF_FILE_EOF

cat > ~/.claude/skills/opencode-handoff/scripts/make_setup_doc.py <<'OPENCODE_HANDOFF_FILE_EOF'
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
OPENCODE_HANDOFF_FILE_EOF

chmod +x ~/.claude/skills/opencode-handoff/scripts/*
`````

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

## File reference

The same contents as the installer, for reading:

### `SKILL.md`

`````markdown
---
name: opencode-handoff
description: Writes an executable plan, hands it to an opencode session to run unattended on a cheaper model (headless `opencode run`), monitors the run, and reviews the result. Use when the user wants a plan executed "in opencode", by GLM, DeepSeek, Inkling or another smaller model, or asks to delegate/hand off/test a plan with a lower-powered agent.
---

# opencode handoff

Claude plans and reviews; an opencode agent (usually a smaller model) executes.
The plan is the contract: a smaller model does well with exact steps and
stop conditions, and badly with judgement calls.

Two fixed rules:
- **One plan per handoff.** Don't chain plans in one prompt. Review each
  plan's result before handing off the next one.
- **Claude always reviews.** Never delegate the review to another opencode
  agent. Review is where plan mistakes and skipped guards are caught.

Scripts are in `~/.claude/skills/opencode-handoff/scripts/`:
`sessions.py` (list sessions), `launch.sh` (start a run), `status.py` (check a run),
`pick_model.py` (recommend a model), `plan_check.sh` (experimental pre-launch plan review).
They target **opencode v2** (2.x); `launch.sh` refuses other versions. See
[opencode v2 notes](#opencode-v2-notes) for what changed from v1.

## Workflow

1. **Write the plan** as a file the agent can read, following
   [PLAN_FORMAT.md](PLAN_FORMAT.md). Every expected number comes from a real
   log or measurement, never an estimate. Commit it if the project tracks plans.
   Before writing, gather what earlier handoffs learned (see [LESSONS.md](LESSONS.md)):
   - Read `lessons/<project>.md` in this skill's folder, if it exists.
   - Search the knowledge base once with `RetrieveContext(query: "<feature or
     area>", kind: "document", project: "<project>")` for past plans, design
     docs and lessons in this project. Drop `project` to find lessons from
     other projects when this one has none.
   - Turn each lesson that applies into plan text: a gotcha under Current
     state, a STOP condition, or a Verify step. Name the lesson's date.
   Skip the search silently if no knowledge-base MCP server is connected.
2. **Prepare the ground** before launching:
   - Create any files only a human may create (allowlists, local config,
     credentials), and exclude them from git (`.gitignore` or `.git/info/exclude`)
     so the agent can't commit them.
   - Create a temp folder **inside the project**, e.g. `<project>/.handoff-tmp/`
     (exclude it too).
   - Give the project an `opencode.json` that **denies work outside it**.
     opencode v2 headless runs don't refuse it on their own. `launch.sh`
     checks for at least the first two rules:
     ```json
     "permission": {
       "external_directory": "deny",
       "shell": { "*": "allow", "*../*": "deny", "cd *": "deny",
                  "*git push*": "deny", "*<secret path>*": "deny" }
     }
     ```
     `external_directory` blocks the file tools outside the project, plus `cd ..`.
     The shell can still read and write absolute paths elsewhere, so add a
     `"*<path>*": "deny"` rule for every secret location. Put `"*"` first
     (the last matching rule wins). To let file tools read one outside folder,
     use `"external_directory": {"*": "deny", "/that/dir/*": "allow"}`.
   - Make sure nothing else will build, flash, or use shared hardware while it runs.
2b. **Plan check (EXPERIMENTAL, optional).** Before choosing the session, you
   may have a cheap model read the plan as the executor would:
   `scripts/plan_check.sh --dir <project> --plan <abs plan>` (background; default
   model `ollama-cloud/deepseek-v4.1-flash`), then `scripts/status.py <log> --report`.
   It runs opencode's read-only `plan` agent in an archived session and lists
   ambiguous steps, stale file:line quotes, vague Verify output and missing STOPs.
   - Its findings are suggestions. Check each against the code yourself; fix
     the plan for real ones and ignore the rest. It never replaces your review.
   - The `plan` agent is only partly read-only (opencode v2.3.2, checked
     2026-11-24 with `opencode debug agents`): its edit tool is denied, but
     its shell inherits the project's `"*": "allow"`, so a redirect could
     write. The model refused writes when asked in a smoke test, but that is
     the model's choice, not a block. The script's guard snapshots git state
     and exits 3 with `PLAN CHECK CHANGED THE REPO` if anything changed:
     stop, show the user, and restore before going on.
   - Tell the user it's experimental, and record in `lessons/<project>.md`
     what it found: useful findings, false alarms, minutes and tokens taken.
     Those notes decide whether it stays, becomes a default step, or goes.
3. **Choose the session and the model.** Run `scripts/sessions.py --dir <project>`
   and `scripts/pick_model.py`, then ask both questions in one AskUserQuestion call:
   - Session: continue one of these (it keeps context from earlier plans) or
     start a new one. Remind them not to type in that session while it runs.
   - Model: **DeepSeek V4 Pro** (`ollama-cloud/deepseek-v4-pro`),
     **GLM-5.3** (`ollama-cloud/glm-5.3`) or **Inkling 2 Small**
     (`ollama-cloud/inkling-2-small`). List `pick_model.py`'s recommendation
     first, marked "(Recommended)", and put its `why` line in the description.
     It recommends DeepSeek off-peak (half price on Ollama Cloud: outside
     12:00–18:00 UTC on weekdays, all weekend) and GLM during peak hours.
     Always list Inkling third, described as "cheapest at any hour; on trial".
     After an Inkling run, record in `lessons/<project>.md` how it followed the
     plan (STOPs honoured, scope kept, stream cutoffs, retries).
   Skip the model question only if the user already named a model for this handoff.
   `sessions.py` shows each session's last handoff model (from the launch logs).
   Recommend a session as follows, and say why in the option's description:
   - **Same model as last time:** continue the project's existing session for
     that model. Fresh sessions re-read AGENTS.md, the plan and the code each
     time, and several fresh sessions on one codebase burned through GLM-5.3
     tokens; a reused session keeps that context.
   - **Switching models:** start a new session. Continuing another model's
     session works, but the new model must process the whole history without
     a cache, and a trial (e.g. Inkling) can't separate one model's habits
     from the other's.
   - **Large or messy history:** start a new session when the session is
     roughly 150–200K tokens, or after a phase with STOPs and long
     back-and-forth. Open it with a compact verified-current-state prompt.
4. **Write the handoff prompt** to an absolute path using
   [PROMPT_TEMPLATE.md](PROMPT_TEMPLATE.md).
5. **Launch in the background** (the command returns when the turn ends):
   `scripts/launch.sh --dir <project> --prompt <abs prompt> --session <id>`
   (or `--new "<title>"`) `--model <model chosen in step 3>`. Always pass
   `--model`; without it `launch.sh` falls back to opencode's configured default.
   Continuations use the same model unless the user changes it. Note the log
   path it prints first.
6. **Confirm it started** about 60 s later with `scripts/status.py <log>`.
   About 1 launch in 5 hangs at startup and prints nothing;
   `launch.sh` kills and retries that itself (up to twice, logged as
   `launch.sh: no model call ...`, shown as `RETRYING`). Only a final
   `HUNG AT STARTUP` needs you to kill the `opencode run` process and its
   `opencode serve --stdio` child, then relaunch; a hang never touches the session. Otherwise wait for the
   background-task notification; use `status.py <log> --session <id>` when
   the user asks for progress.
7. **When it ends**, run `status.py <log> --session <id> --report`:
   - `DENIED` lines are tool calls the permission rules blocked. In v2 the
     agent gets an error and its turn **continues**, so check what it did
     next: it should have stopped and reported, not found a way around.
     If the denial was a plan mistake, change the plan or the rules.
   - `FINISHED (exit 1)` with no model call usually means a CLI flag error:
     read the log's last lines.
   - A STOP report: decide whether the plan or the code is wrong. Fix the plan
     if its condition was too strict, and say so. Then send a continuation that
     states the verified current state and exactly what to do next.
8. **Review** with [REVIEW.md](REVIEW.md) before telling the user it's done.
   Verify safety-critical claims yourself; don't repeat the agent's report.
   Fix small review findings directly instead of another round trip.
9. **Record lessons** from the review in `lessons/<project>.md`, following
   [LESSONS.md](LESSONS.md), then save that file with the `kb-save` skill
   (tags `lessons`, `opencode-handoff`). Do this even when the run stopped:
   STOPs teach the most.
10. **Archive the plan** once the review passes and the plan's status records
    the outcome: save the plan file with the `kb-save` skill, with
    `status: completed` and the tag `opencode-handoff`. Skip this if the run ended on a STOP
    or the review left findings unresolved, and say that it wasn't archived.
    Archive again after any later edit to the plan; saving the same path
    updates it.

## Continuations

Send follow-ups to the same session with a new prompt file. Start by stating
the verified current state (commits, what's staged, what's left). Then give
the rules again, and name the next step. Keep one prompt per file so the
history is auditable.

## opencode v2 notes

opencode 2.x (e.g. 2.2.5, Homebrew `opencode-v2`) changed the headless
interface. Sessions from v1 survive the upgrade and can be continued.

| v1 | v2 | Handled by |
| --- | --- | --- |
| `opencode run --dir DIR` | flag removed; the working directory is the project | `launch.sh` cds to `--dir` |
| `--log-level DEBUG` | lower case only (`debug`, `info`) | `launch.sh` |
| shared process | runs via a background service; `--standalone` gives each run a private server (`opencode serve --stdio` child) | `launch.sh` passes `--standalone` and kills the child on a hang |
| debug log lines `message=stream`, `session.id=` | not logged; use `--format json` (JSON lines: `step_start`, `tool_use`, `text`, `step_finish`, with `sessionID`) | `launch.sh` / `status.py` |
| approvals auto-rejected, turn ends | nothing outside the project is refused by default; denied calls return `Permission denied` and the turn goes on | project `opencode.json` rules (step 2); `status.py` prints `DENIED` |
| `opencode export ID` | `opencode session export ID`; messages are `{type, time, content[]}` (tool parts: `name`, `state.input.path`) | `status.py` |
| tools `bash`, `filePath` | `shell`, `path` | prompts must not name the old tools |
| `opencode session list` | lists the project of the working directory | `sessions.py` runs it from `--dir` |

## Rules for Claude

- Launch from the project directory with absolute paths only. A relative path
  once sent a garbled prompt to the wrong project.
- Never type into or attach to the user's open opencode window.
- After an opencode upgrade, test a tiny run in a scratch folder before the
  next handoff: check the flags, the JSON events, and that the permission
  rules deny a `../` write.
- Never edit `scripts/launch.sh` while a launch is running: bash reads the
  script as it goes, and finishes from the middle of the new version.
- One run per session at a time. Don't start another turn until the notification arrives.
- Code the agent writes follows the project's rules. Check hooks, line endings
  and commit conventions in review.
`````

### `PLAN_FORMAT.md`

`````markdown
# Plan format for a smaller executing model

A plan is executable when a model that can't make judgement calls can still
follow it, and knows when to stop.

## Required sections

1. **Header block**
   - Executor instructions: follow the steps in order, run every Verify, and
     stop and report on any STOP condition.
   - A **drift check**: `git log --oneline -1` must be commit X or a
     descendant, and `git diff --stat X..HEAD -- <files>` must be empty.
     Otherwise STOP.
2. **Status**: priority, effort, risk, dependencies, branch, and the commit the
   plan was written against.
3. **Why this matters**: two or three sentences with evidence (log lines,
   file:line). The agent uses it to judge edge cases.
4. **Current state**: quoted code at exact `file:line`, the facts the steps
   rely on, and gotchas (line endings, hooks that stage files, local edits
   that must never be staged).
5. **Scope**: in scope (the only files to touch) and out of scope.
6. **Git workflow**:
   - branch;
   - commit message(s);
   - project commit conventions;
   - "do not push".
7. **Steps**. Each step has exact edits and ends with a **Verify** command and
   its **expected output**.
8. **Test plan**, **Done criteria** (as a checklist), **STOP conditions**, and
   **Maintenance notes**.

## Rules that prevented problems

- **Expected values come from real data.** Take them from an existing log,
  measurement or test run, and name the source ("reference: bench_020.log,
  W2 recovery 25.1 s, pass ≤ 35 s"). An estimated count ("about 115 frames")
  produced a false STOP.
- **Give ranges, not exact moments, for anything timing-based.** Say when an
  event happens relative to something else ("at the first request after the
  window ends").
- **Write STOP conditions narrowly, and list expected differences.** A parity
  check that ignored known harmless differences (a version stamp, a known
  local edit) would have avoided a false STOP.
- **Nothing interactive.** No `git add -p`, editors or prompts. To stage part
  of a file, write a patch into the project temp folder and run
  `git apply --cached --unidiff-zero`.
- **State the one-thing-at-a-time constraints**: one build at a time,
  exclusive hardware, which folder temp files go in.
- **Name the files for each commit**, and say to check `git show --stat HEAD`
  after committing. That catches hooks that stage extra files.
- **Keep safety checks in code, not in prose**, when the plan builds tooling. A
  guard the agent can skip isn't a guard.
- **Say where things must happen.** "Before anything is written" or "before
  flashing" must be explicit. An agent put a pre-flash check after the flash.
- **Split big work into step groups with one commit each,** so a STOP leaves a
  clean, reviewable state.
- **When a plan removes or renames something, search the whole repo for it
  while planning**, including headers and test mocks. Put every hit in the
  steps or in the expected output. A removal plan that only listed the main
  source file missed a header declaration, a second `#ifdef` and two mock
  files; the agent's Step 0 check caught it and stopped.
- **Leave design-level plans (no numbered steps) for Claude**, or refine them
  into steps before handing them off.
- **When you refresh an old plan, re-check every section, not just the line
  numbers.** That includes the drift check base, the Git workflow (the branch
  name) and the scope. The prompt and the plan must agree: when they
  conflicted over the branch, the agent followed the plan and created a new,
  plan-numbered branch.
`````

### `PROMPT_TEMPLATE.md`

`````markdown
# Handoff prompt template

Fill in the `<...>` parts and save the prompt to an absolute path. Keep the
"unattended" rules word for word: each one prevented a stalled or broken run.

```text
You are working in <PROJECT_DIR>. Your task: execute <PLAN NAME> in <REPO/AREA>, and nothing else.

Before doing anything, read:
1. <project instruction files, e.g. AGENTS.md>
2. <runbooks or docs the plan relies on>
3. The plan in full: <ABSOLUTE PLAN PATH>

You are running UNATTENDED. Permission rules deny work outside <PROJECT_DIR>: a denied call returns "Permission denied". So:
- Write temporary files ONLY under <PROJECT_DIR>/<TEMP DIR>/. Never use /tmp or any path outside <PROJECT_DIR>.
- Your read/edit/write tools are denied for paths outside <PROJECT_DIR>, and so are `cd` and `../` in the shell.
  To READ files elsewhere (SDKs, toolchains, ~/.config), use the shell with absolute paths (cat, grep, sed -n).
  Never modify anything outside <PROJECT_DIR>.
- If any tool call is denied or rejected, stop and report what you were trying to do. Do not retry it or
  find another way around it.
- Never run anything interactive (no `git add -p`, no editors, no prompts waiting for input).
- Always use absolute paths for files you create.

How to work:
- Branch: <BRANCH> in <REPO PATH> (confirm with `git branch --show-current`). Current HEAD is <COMMIT>.
- Follow the plan's steps in order. Run every Verify and compare with the expected result. If a STOP
  condition happens, or anything doesn't match the plan, stop and report. Do not work around it.
- <project rules: build limits, hooks, line endings, files never to stage, commit-message rules>
- Do not push.

Setup already done for you (do not change it):
- <files a human created, e.g. allowlists; say they are excluded from git and must never be committed>

Scope limits for unattended running:
- <steps that need a human: implement but do not run; say so in the report>

When finished:
- <update the plan's status/index, in its own commit>
- Report: every commit (hash + message) per repo, test results, the plan's verification tables
  (observed vs expected), what was not run and why, and anything that didn't match the plan.
```

## Continuation prompt (same session)

```text
<What happened: e.g. "Your STOP report on X is accepted" or "Your last tool call was rejected because Y".>
<The decision, and any plan change: "The plan's STOP condition has been updated; re-read it in <path>.">

Same rules as before: <restate the unattended rules in one line each>.

Verified current state: <commits so far, what is staged/uncommitted, files to leave alone>.

Next: <exact next actions, including any review fix to make first as its own commit>.
Then continue the plan from <step> through the end, and give the full report.
```
`````

### `REVIEW.md`

`````markdown
# Reviewing an opencode run

The agent's report is a claim, not a result. Check it before telling the user
the plan is done.

## Every run

- [ ] **Commits:** `git log --oneline <start>..HEAD` matches the report.
      `git show --stat` for each commit touches only the files the plan
      scoped.
- [ ] **Nothing that must stay out was committed:** local config,
      allowlists, secrets, caches (`__pycache__`, build dirs), result folders,
      stray copies in the wrong folder (`git status --short`, `git ls-files`).
- [ ] **Project conventions:** commit-message rules, line endings (look for
      whole-file diffs), hooks that stage extra files, files never to stage.
- [ ] **Tests:** run the test suites yourself, rather than trusting the
      reported pass count.
- [ ] **Clean end state:** the working tree holds only expected leftovers, and
      shared hardware or services are back in their normal state.

## Read the code, not just the tests

- Read the diff of anything safety-critical, and **trace every path** to the
      dangerous action (e.g. every caller of a flash, delete or deploy
      function). A check that exists but runs too late, or a helper nobody
      calls, won't show up in a passing test.
- Look for dead helpers that skip a guard. A later agent may call them.
- Look for silent degradation: an `#if`/flag that falls back to a no-op, a
      default that disables a check, a missing include that changes behaviour.
- Compare each "expected" value in the report with the plan's source data.

## Decide on each finding

- **Small and clear:** fix it yourself as a follow-up commit, with a message
  that says what the review found.
- **The plan was wrong** (a STOP condition too strict, a bad estimate): fix
  the plan, and say so plainly in the continuation and to the user.
- **The agent's code is wrong and the fix is large:** send a continuation
  with the finding, the verified current state and the exact fix.
- Record the outcome in the plan's status or index: executor model, session
  id, result (done, or STOP and why), number of continuations, and follow-up
  commits.
- Record lessons for every finding a better plan would have prevented
  ([LESSONS.md](LESSONS.md)).

## Tell the user

Give a short verdict, what you verified yourself, any gap you found and how
it was fixed, and what still can't be verified (e.g. steps that need a human).
Say plainly when an issue was the plan's fault rather than the agent's.
`````

### `scripts/sessions.py`

`````python
#!/usr/bin/env python3
"""List recent opencode sessions for a project directory.

usage: sessions.py [--dir DIR] [--all] [-n N]
Prints: id, last update, last handoff model, title. Default dir is the current
directory. opencode doesn't record a session's model, so it comes from
launch.sh's logs in ~/.cache/opencode-handoff/ ("-" if no handoff used it).
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

LOG_GLOB = os.path.expanduser("~/.cache/opencode-handoff/*.log")


def models_by_session():
    """Map session id -> model of the newest handoff log that used it."""
    found = {}
    for path in sorted(glob.glob(LOG_GLOB), key=os.path.getmtime):  # oldest first; newer wins
        try:
            text = open(path, errors="replace").read()
        except OSError:
            continue
        m = re.search(r"^launch: .*?model=(\S+)", text, re.M)
        if not m:
            continue
        ids = re.findall(r"^launch: .*?session=(ses_\w+)", text, re.M)
        ids += re.findall(r'"sessionID":"(ses_\w+)"', text)[:1]
        for sid in ids:
            found[sid] = m.group(1).split("/", 1)[-1]
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.getcwd())
    ap.add_argument("--all", action="store_true", help="all projects")
    ap.add_argument("-n", type=int, default=10)
    a = ap.parse_args()
    want = os.path.realpath(a.dir)
    try:
        # opencode lists the sessions of the project in its working directory,
        # so run it from the requested directory
        out = subprocess.run(["opencode", "session", "list", "--format", "json",
                              "-n", "200"], capture_output=True, text=True,
                             timeout=60, cwd=want)
        sessions = json.loads(out.stdout or "[]")
    except Exception as e:  # noqa: BLE001
        sys.exit(f"could not list opencode sessions: {e}")
    if not a.all:
        sessions = [s for s in sessions
                    if os.path.realpath(s.get("directory", "")) == want]
    if not sessions:
        print(f"no opencode sessions for {want}" if not a.all else "no sessions")
        return
    models = models_by_session()
    for s in sessions[: a.n]:
        t = datetime.datetime.fromtimestamp(s["updated"] / 1000).strftime("%Y-%m-%d %H:%M")
        where = "" if not a.all else f"  [{s.get('directory')}]"
        print(f"{s['id']}  {t}  {models.get(s['id'], '-'):<16}  {s.get('title', '')}{where}")


if __name__ == "__main__":
    main()
`````

### `scripts/launch.sh`

`````bash
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
`````

### `scripts/status.py`

`````python
#!/usr/bin/env python3
"""Check an opencode handoff: did it start, is it stuck, what is it doing.

usage: status.py LOG_FILE [--session ID] [--report] [--tail N]

Written for opencode v2 (`opencode run --format json`, as launch.sh runs it).
From the launch log: started / reached the model / HUNG at startup /
permission denials / provider errors / exited, plus the last few events.
With --session: message count, last activity, the last N steps from
`opencode session export`, and with --report the agent's latest full text
(its report when finished).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HANG_SECONDS = 45
LIMIT_RE = re.compile(r"usage limit|rate limit|quota|429|credits", re.I)  # also matches type "provider.quota"


def tool_input(inp):
    if not isinstance(inp, dict):
        return str(inp)
    return str(inp.get("command") or inp.get("path") or inp.get("filePath")
               or inp.get("pattern") or "")


def log_state(path):
    try:
        text = open(path, errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path}: {e}")
    events, denied, errors = [], [], []
    for line in text.splitlines():
        if not line.startswith("{"):
            if "level=ERROR" in line:
                m = re.search(r'message="([^"]{0,200})"', line)
                c = re.search(r'cause="([^"]{0,200})', line)   # v2 puts the provider's text here
                errors.append((m.group(1) if m else line[:200]) + (" — " + c.group(1) if c else ""))
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        events.append(e)
        p = e.get("part") or {}
        st = p.get("state") or {}
        if e.get("type") == "tool_use" and st.get("status") == "error" \
                and "Permission denied" in str(st.get("error", "")):
            denied.append(f"{p.get('tool')} {tool_input(st.get('input'))[:120]} -> {st.get('error')}")
        if "error" in str(e.get("type", "")):
            errors.append(json.dumps(e.get("error") or e.get("message") or e)[:240])
    for m in re.finditer(r'"message":"([^"]{0,240})"', text):
        if LIMIT_RE.search(m.group(1)) and m.group(1) not in errors:
            errors.append(m.group(1))
    lm = re.search(r"^launch: dir=(\S+)", text, re.M)
    return {
        "exited": re.findall(r"^EXIT (\d+)$", text, re.M),
        "reached_model": any(e.get("type") == "step_start" for e in events),
        "init": 'message="cli starting"' in text or "message=init" in text,
        "denied": denied,
        "provider_errors": errors,
        "session_ids": list(dict.fromkeys(re.findall(r'"sessionID":"(ses_\w+)"', text))),
        "events": events,
        "dir": lm.group(1) if lm else None,
        "age_s": time.time() - os.path.getmtime(path),
        "first": text.splitlines()[0] if text else "",
    }


def event_summary(e):
    p = e.get("part") or {}
    st = p.get("state") or {}
    t = e.get("type")
    if t == "tool_use":
        return f"TOOL {p.get('tool')} {st.get('status')} {tool_input(st.get('input'))[:110]}"
    if t == "text":
        return "TEXT " + str(p.get("text", "")).strip().replace("\n", " ")[:150]
    return str(t)


def export(session, cwd):
    # `opencode session export` (v2; v1 was `opencode export`). Written to a
    # file because large JSON read through a pipe has arrived truncated.
    with tempfile.NamedTemporaryFile("w+", suffix=".json", delete=False) as f:
        path = f.name
    try:
        with open(path, "w") as out:
            subprocess.run(["opencode", "session", "export", session], stdout=out,
                           stderr=subprocess.DEVNULL, timeout=120,
                           cwd=cwd if cwd and os.path.isdir(cwd) else None)
        return json.load(open(path))
    except (json.JSONDecodeError, subprocess.TimeoutExpired) as e:
        sys.exit(f"could not read session {session} (opencode session export): {e}")
    finally:
        os.unlink(path)


def ts(ms):
    return datetime.datetime.fromtimestamp(ms / 1000).strftime("%H:%M:%S") if ms else "-"


def step_summary(msg):
    # v2 export: {"type": "assistant"|"user"|"system", "content": [...]}; user
    # and system messages carry "text" directly.
    for p in reversed(msg.get("content") or []):
        t = p.get("type")
        if t == "text" and p.get("text", "").strip():
            return "TEXT " + p["text"].strip().replace("\n", " ")[:160]
        if t == "tool":
            st = p.get("state") or {}
            return f"TOOL {p.get('name')} {st.get('status')} {tool_input(st.get('input'))[:120]}".replace("\n", " ")
        if t == "provider.error":
            return "ERROR " + str(p.get("message", ""))[:160]
    if msg.get("error"):
        return "ERROR " + json.dumps(msg["error"])[:160]
    if msg.get("text"):
        return "TEXT " + msg["text"].strip().replace("\n", " ")[:160]
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--session")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--tail", type=int, default=5)
    a = ap.parse_args()

    st = log_state(a.log)
    print(st["first"])
    if st["exited"]:
        state = f"FINISHED (exit {st['exited'][-1]})"
    elif st["reached_model"]:
        state = "RUNNING (reached the model)"
    elif "launch.sh: no model call" in open(a.log, errors="replace").read() and st["age_s"] < HANG_SECONDS * 4:
        state = "RETRYING (launch.sh restarted a startup hang; check again shortly)"
    elif st["init"] and st["age_s"] > HANG_SECONDS:
        state = (f"HUNG AT STARTUP: no model call {int(st['age_s'])}s after start. "
                 "Kill the opencode run process (and its `opencode serve --stdio` child) "
                 "and relaunch; the session was not touched.")
    else:
        state = "STARTING"
    print("state:", state)
    for r in st["denied"]:
        print("DENIED:", r, "(the agent got an error and its turn went on; check how it reacted)")
    if st["provider_errors"]:
        # any limit/quota error wins: a generic error (e.g. "Failed to drain Session")
        # often follows the quota error as the last line
        limits = [e for e in st["provider_errors"] if LIMIT_RE.search(e)]
        last = limits[-1] if limits else st["provider_errors"][-1]
        kind = "PROVIDER LIMIT" if limits else "PROVIDER ERROR"
        print(f"{kind} ({len(st['provider_errors'])}x): {last}")
        if kind == "PROVIDER LIMIT":
            print("  The model provider refused further calls. Wait for the limit to reset or "
                  "switch --model; the session keeps its history, so a continuation can resume it.")
    if st["exited"] and st["exited"][-1] != "0" and not st["reached_model"]:
        print("  Exit before any model call: read the log's last lines (bad flag? see launch.sh).")
    shown = [e for e in st["events"] if e.get("type") in ("tool_use", "text")][-a.tail:]
    if shown and not a.session:
        print("last events:")
        for e in shown:
            print(f"  {ts(e.get('timestamp'))} {event_summary(e)}".replace("\n", " "))

    session = a.session or (st["session_ids"][-1] if st["session_ids"] else None)
    if not session:
        return
    d = export(session, st["dir"])
    msgs = d.get("messages", [])
    last = msgs[-1].get("time", {}).get("created") if msgs else None
    print(f"session {session}: {len(msgs)} messages, last activity {ts(last)}")
    for m in msgs[-a.tail:]:
        print(f"  {ts(m.get('time', {}).get('created'))} {str(m.get('type'))[:4]} | {step_summary(m)}")
    if a.report:
        for m in reversed(msgs):
            if m.get("type") != "assistant":
                continue
            texts = [p["text"] for p in m.get("content") or []
                     if p.get("type") == "text" and p.get("text", "").strip()]
            if texts:
                print("\n--- latest agent text ---\n" + texts[-1])
                break


if __name__ == "__main__":
    main()
`````

### `scripts/pick_model.py`

`````python
#!/usr/bin/env python3
"""Recommend the handoff model for right now, from Ollama Cloud's peak hours.

usage: pick_model.py [--json]

Ollama Cloud bills some DeepSeek models at half price off-peak. Off-peak is
outside 12:00-18:00 UTC on weekdays, and all day on weekends (ollama.com/pricing,
checked 2026-11-22). GLM has no off-peak rate, so:
  off-peak -> DeepSeek V4 Pro (cheapest, strong on repo bug-fixing)
  peak     -> GLM-5.3          (DeepSeek at full price loses its cost edge)
Inkling 2 Small is always offered as a third option (cheapest at any hour,
$0.30/$1.00 per 1M; no off-peak rate). It is on trial, so it is never the default.
Prints the recommended model first, then the alternatives, and why.
"""
import datetime
import json
import sys

DEEPSEEK = "ollama-cloud/deepseek-v4-pro"
GLM = "ollama-cloud/glm-5.3"
INKLING = "ollama-cloud/inkling-2-small"
PEAK_START, PEAK_END = 12, 18  # UTC hours, weekdays only


def main():
    now = datetime.datetime.now(datetime.timezone.utc)
    weekend = now.weekday() >= 5
    peak = not weekend and PEAK_START <= now.hour < PEAK_END
    if peak:
        rec, alt = GLM, DEEPSEEK
        ends = now.replace(hour=PEAK_END, minute=0, second=0, microsecond=0)
        why = (f"peak hours (weekday {PEAK_START}:00-{PEAK_END}:00 UTC); "
               f"off-peak resumes in {int((ends - now).total_seconds() // 60)} min")
    else:
        rec, alt = DEEPSEEK, GLM
        why = "off-peak (weekend)" if weekend else "off-peak (outside weekday 12:00-18:00 UTC)"
        why += ": DeepSeek V4 Pro is half price"
    if "--json" in sys.argv:
        print(json.dumps({"recommended": rec, "alternatives": [alt, INKLING], "peak": peak,
                          "utc": now.isoformat(timespec="minutes"), "why": why}))
    else:
        print(f"recommended: {rec}\nalternatives: {alt}, {INKLING} (on trial)\n"
              f"why: {why} (now {now:%a %H:%M} UTC)")


if __name__ == "__main__":
    main()
`````

### `scripts/plan_check.sh`

`````bash
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
`````

### `scripts/make_setup_doc.py`

`````python
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
`````
