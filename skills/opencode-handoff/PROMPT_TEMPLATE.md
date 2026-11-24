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
