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
