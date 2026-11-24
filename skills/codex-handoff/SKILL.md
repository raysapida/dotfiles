---
name: codex-handoff
description: Writes an executable plan, hands it to OpenAI Codex CLI in a right-hand tmux pane with an interactive session inside its OS sandbox, monitors the run, and reviews the result. Use when the user wants a plan executed "in Codex", by a GPT/Codex model, or asks to delegate or hand off a plan to Codex.
---

# Codex handoff

Same contract as the `opencode-handoff` skill: Claude plans and reviews, Codex executes, the plan is the contract.
Reuse that skill's files instead of copies:

- plan format: `~/.claude/skills/opencode-handoff/PLAN_FORMAT.md`
- prompt template: `~/.claude/skills/opencode-handoff/PROMPT_TEMPLATE.md` (adapt the sandbox wording below)
- review checklist: `~/.claude/skills/opencode-handoff/REVIEW.md`
- lessons: `~/.claude/skills/opencode-handoff/LESSONS.md` and `lessons/<project>.md` (shared by both skills;
  record which tool and model ran in each entry)

Use one plan per handoff. The initiating agent reviews the executor's work.

Scripts are in `~/.claude/skills/codex-handoff/scripts/`: `launch.sh` (start or resume a run) and `status.py`
(summarise its log). Tested with codex-cli 0.158.0.

## What's different from opencode

| | opencode | Codex |
|---|---|---|
| Containment | permission rules in the project's `opencode.json`; the shell can still reach absolute paths | **OS sandbox** (`workspace-write`): writes only inside the project and temp dirs; `Operation not permitted` elsewhere. Reads are not restricted |
| Network | open | **off by default**; `--network` turns it on (needed for a local Postgres on 127.0.0.1, also opens the internet) |
| Shell environment | inherits yours | **doesn't load mise**: `launch.sh` puts the project's `.ruby-version` Ruby on `PATH` (`--path` adds more, e.g. a Node bin) |
| Tool caches | — | RuboCop and others cache under `~/.cache`, **outside the sandbox**: `launch.sh` points `XDG_CACHE_HOME` and `RUBOCOP_CACHE_ROOT` into `.handoff-tmp/cache`. Bundler warns that `$HOME` isn't writable and falls back to a temp dir; harmless |
| Stdin | — | **`codex exec` waits on an open stdin** ("Reading additional input from stdin...") and hangs forever; `launch.sh` closes it |
| Git in a worktree | — | a worktree's `.git` lives in the main repo, **outside the sandbox**, so Codex can't commit there. Default: Codex leaves changes uncommitted and Claude commits after review |
| Continue a run | `--session <id>` | `--resume <thread id>` (`codex exec resume`; it takes no `-C`/`-s`, so the script `cd`s and sets the sandbox with `-c`) |
| Instructions | project `AGENTS.md` | Codex also reads `AGENTS.md` automatically |

## Workflow

1. **Write the plan** per `PLAN_FORMAT.md`, after reading `lessons/<project>.md` and searching the knowledge base
   for past plans (the opencode-handoff skill's step 1). Plans for Codex should also:
   - give the exact environment for every command (database URLs, `RAILS_ENV=test`), since each shell call is
     separate;
   - say "do not commit, do not `git add`" unless the run is in the main checkout and the user wants commits;
   - make every expected number come from a real run.
2. **Prepare the ground:** a git worktree for the branch; local-only files excluded from git. `launch.sh` creates
   `<project>/.handoff-tmp/` and excludes it. Do the setup a fresh worktree needs before tests pass (e.g.
   `bin/rails tailwindcss:build` for knowledge_base) yourself, and run the baseline suite once so the plan's
   expected numbers are real.
3. **Smoke test** after a Codex upgrade or on a new project: a tiny prompt that runs `which ruby`, one spec file,
   and a `touch` outside the project (must fail). Read the result with `status.py`.
4. **Write the handoff prompt** from `PROMPT_TEMPLATE.md` to `<project>/.handoff-tmp/<name>_prompt.md`. Replace the
   permission-rule paragraph with: "You run in a sandbox that only allows writes inside <PROJECT_DIR>; a blocked
   write fails with `Operation not permitted`. If anything is blocked, stop and report; don't work around it."
   Also add: "A mistake in a command you wrote yourself (a typo, a missing argument) is not a STOP: fix it and
   run it again." Codex otherwise stops on its own typos.
   And: "Bundler's warning that your home directory isn't writable (it falls back to a temp directory) is
   expected and harmless; a sandbox STOP is a command that fails with `Operation not permitted`."
5. **Open Codex in a right-hand tmux pane.** Split the invoking pane with
   `tmux split-window -h` for side-by-side sessions. Use `-d` to leave the
   current pane focused. Set `handoff_pane` to the invoking pane's ID
   (`$TMUX_PANE`), plus the absolute checkout and prompt paths. Default
   `handoff_model` to `gpt-6-luna` unless the user requests another model.

   ```bash
   tmux split-window -h -d -P -F '#{pane_id}' \
     -t "$handoff_pane" -c "$handoff_checkout" \
     codex --sandbox workspace-write --ask-for-approval on-request \
     --model "$handoff_model" -- "$(cat "$handoff_prompt")"
   ```

   Validate the inherited pane before splitting. `TMUX_PANE` can refer to
   a pane that has closed or to the terminal where the agent server started.
   Use `tmux display-message -p -t "$TMUX_PANE"` with a format that includes
   `#{pane_id}`, `#{pane_current_command}`, and `#{pane_current_path}`.
   Confirm the pane matches the initiating Codex session and checkout.

   If the variable is missing, stale, or points elsewhere, list live panes
   with `tmux list-panes -a -F '#{session_name}:#{window_index} #{pane_id} #{pane_active} #{pane_current_command} #{pane_current_path}'`.
   Use the explicit pane ID if exactly one pane matches the initiating Codex
   session and checkout. Ask for the target if multiple panes match. If tmux
   socket access is blocked, request approval for the specific lookup or split
   command. If there is no tmux session, report that the side-by-side launch
   needs one. When reopening a saved handoff, use `codex resume <thread-id>`
   in the split.
6. **Verify the handoff.** Run `tmux capture-pane -p -t <new-pane-id>` to
   confirm Codex received the prompt and check the pane's directory. Verify
   that the new pane is to the right and the initiating pane remains active.
   Report the pane ID and how to switch. The default bindings are tmux
   prefix then Right or Left. `tmux select-pane -t <pane-id>` is an alternative.
7. **Monitor the interactive run.** Check the pane for progress, approval
   prompts, and completion. Surface a pending approval with its exact command
   and pane ID. For follow-up, use the existing interactive pane or resume
   the saved thread in a new split if its earlier pane is gone.

   When the user explicitly wants a headless run, use
   `scripts/launch.sh --dir <abs project> --prompt <abs prompt> [--network] [--model <m>|config]`
   and monitor the printed log with `scripts/status.py <log> --commands`.
   For headless continuation, use `launch.sh --resume <thread id>` with the same
   settings. Check the `.err` file if no events appear.
8. **Review** with `REVIEW.md`: run the tests yourself, read the diff. Fix small findings directly.
9. **Record lessons** in `lessons/<project>.md` (note "codex, <model>") and save it with `kb-save`.
10. **Commit** after showing the user the diff (the user reviews before commits), then archive the plan with
    `kb-save` (`status: completed`, tag `codex-handoff`) once the work is merged or accepted. A plan kept out
    of the repo (in `.handoff-tmp/`) is archived from there; its path still identifies it.

## Execution rules

- Use absolute checkout and prompt paths. Use `launch.sh` for headless runs so stdin closes.
- Run one executor per thread at a time.
- Never use `--dangerously-bypass-approvals-and-sandbox`.
- `--network` only when the plan needs it, and say so to the user when you use it.
