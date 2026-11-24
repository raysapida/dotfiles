# Handoff lessons

Each review finds mistakes a better plan would have prevented. Lessons keep
them, so the next plan for the same project (or model) includes the guard.

## Where they live

- `lessons/<project>.md` in this skill's folder, one file per project.
  `<project>` is the main working tree's directory name
  (`git worktree list --porcelain | sed -n '1s|^worktree .*/||p'`).
- After each update, save the file with the `kb-save` skill (tags `lessons`,
  `opencode-handoff`) so lessons from one project show up when planning
  another. The local file is the source; the knowledge base copy is for search.

## What counts as a lesson

Record a finding when a change to the plan would have prevented it:

- a STOP that fired because a condition was too strict or a fact was wrong;
- a guard the agent skipped, or a path to a dangerous action the plan didn't
  cover;
- a convention the agent broke (line endings, hooks, commit messages, files
  that must not be staged);
- an expected value that was wrong, or a step that was ambiguous.

Don't record one-off slips that no plan text would have caught, and don't
repeat a lesson that is already in the file: add the new date to it instead.

## Entry format

Newest first:

```markdown
## 2026-11-15 — docs/x/y_plan.md (glm-4.6, session ses_abc123)

- **What happened:** the agent rewrote whole files with CRLF line endings.
- **Why the plan allowed it:** Current state didn't say the repo uses LF.
- **Next time:** add "files use LF; run `git diff --stat` and STOP if a file
  shows as fully rewritten" to Current state and the Verify of each edit step.
```

## Promoting a lesson

When the same lesson shows up in two projects, propose adding it to
[PLAN_FORMAT.md](PLAN_FORMAT.md) under "Rules that prevented problems" and
ask the user before editing.
