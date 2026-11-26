---
name: kb-save
description: Saves a finished markdown document (a reviewed plan, design doc, postmortem or write-up) to Raymond's knowledge base at wiki.raymondsapida.com through the SaveMarkdownDocument MCP tool, so it becomes searchable later. Use when another skill says to archive a document with kb-save, or when the user asks to save, upload or archive a markdown file to the knowledge base.
---

# Save a document to the knowledge base

`SaveMarkdownDocument` stores the document as a private bookmark, embeds it and auto-tags it in the
background. Saving the same path again updates the document instead of duplicating it, so re-running
this after an edit is safe.

## When to save

- Only finished documents: a plan whose review passed, a final design doc, a postmortem. Not drafts,
  not plans that stopped with unresolved issues.
- Never a file that contains secrets (tokens, passwords, private keys, connection strings with
  passwords). If unsure, tell the user and don't save it.

## Steps

1. **Pick the tool.** Use the first one available:
   1. `mcp__knowledge-base-http__SaveMarkdownDocument` (the production HTTP endpoint);
   2. `mcp__knowledge-base__SaveMarkdownDocument` (the local stdio server).

   If neither is connected, stop and tell the user the document wasn't saved, and point them to
   `docs/mcp/http_mcp_client_setup.md` in the knowledge_base repo.

2. **Work out the canonical path.** The path is the document's identity, so it must be the same every
   time the document is saved:
   - Make it absolute.
   - If the file is inside a git worktree, use the matching path in the **main** working tree, so a
     plan saved from `.claude/worktrees/<name>/docs/x_plan.md` and later from the main checkout is one
     document:
     ```bash
     abs=$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")
     dir=$(dirname "$abs")
     main_root=$(git -C "$dir" worktree list --porcelain | sed -n '1s/^worktree //p')
     this_root=$(git -C "$dir" rev-parse --show-toplevel)
     echo "$main_root/${abs#"$this_root"/}"
     ```

3. **Read the file** and pass its full content unchanged.

4. **Choose a title and tags.**
   - `title`: the document's first `# ` heading, if it has one; otherwise leave it out (the file name
     is used).
   - `tags`: the document type (`plan`, `design`, `postmortem`, `notes`), the project name (the main
     working tree's directory name, e.g. `knowledge_base`), plus any tags the calling skill asks for.
     Lowercase, no spaces.

5. **Call the tool** with `path`, `content`, `title`, `tags`, and:
   - `project`: the main working tree's directory name (the tool derives it from paths under `~/personal` or
     `~/work`, so pass it explicitly only for other locations);
   - `status` when the calling skill gives one: `proposed`, `in_progress`, `completed` or `superseded`.
     Re-saving without `status` keeps the stored one.

6. **Report** one line: the title, whether it was created or updated, and the link
   `https://wiki.raymondsapida.com/bookmarks/<bookmark_id>`, plus the project and status it returned. If the tool returns an error, show it and
   don't retry with a different path.
