---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

## Codex CLI handoffs

When the user asks for a live Codex handoff, launch the requested model in a visible tmux pane in the intended worktree. Confirm the pane is running and share its ID. If asked to monitor, check for progress, approval prompts, and completion.

Before launch, check the worktree and its tool setup. For mise projects, inspect the worktree config and check whether mise trusts it. Use existing approved command forms where possible. Include those exact forms and any remaining prerequisites in the handoff. Keep approvals scoped to the task and request any missing permission through the normal approval flow.
