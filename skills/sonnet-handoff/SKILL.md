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
