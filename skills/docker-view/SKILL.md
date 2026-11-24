---
name: docker-view
description: Opens a tmux window running lazydocker for one git worktree's docker compose stack, picking the worktree by fuzzy match on its folder name or branch (e.g. "notification" → example-app-rails-notifications, feature/notifications). Use when the user runs /docker-view, or asks to see, manage or open lazydocker for a worktree's containers.
---

# docker-view

Argument: an optional fuzzy query, e.g. `/docker-view notification`, `/docker-view billing`,
`/docker-view production`.

## Run it

Run the script from the repo (any checkout or worktree of it), or from the workspace folder that
holds the checkouts, passing the query through:

```bash
~/.agents/skills/docker-view/scripts/docker-view.sh [query]
```

- Add `-C <dir>` if the current directory isn't inside the repo or workspace.
- Add `--background` only if the user asks not to switch windows.
- `--print` resolves the worktree and prints it (`worktree=`, `branch=`, `owner=`) without opening
  anything. Use it to answer "which worktree is running docker?".
- `--compose <file>` for a compose file other than `local_development/docker-compose.yml`.

**How the query resolves:** it's compared with each worktree's topic (folder name without the
`<repo>-` prefix), folder name and branch. First exact matches, then substrings, then `fzf` fuzzy
matching. The first tier with any match decides. With **no query** it opens the worktree whose code
the compose project's running containers have mounted, or else the current checkout (the main
checkout when run from the workspace folder).

**Exit codes:**
- `3`: several worktrees matched, and they're printed. Show them to the user and ask which one,
  or rerun with a query that makes the choice clear. Don't pick one yourself.
- `4`: no match, and all worktrees are printed.
- `1`: error (not in tmux, missing tool, no compose file, a user window with the same name).

Then report the output in a couple of lines: the window name, the worktree and branch, how to reach
it (`prefix` + `w`), and any `warning:` line verbatim.

## What the user sees

lazydocker, started in the worktree with `-f <compose file>`:
- **Services:** only that compose project's services (for example-app: db, mailcatcher, rails…).
- **Standalone Containers:** everything else on the machine, including other projects. lazydocker
  0.24.4 can't filter this list, though `/` filters it by hand. Its "stop all"/"remove all" act on
  *every* container on the machine, including hidden ones.

The window is named `docker-<topic>`. Running it again for the same worktree replaces it. It's
tagged `@docker_view`, and the script never replaces a window it didn't make.

## The warning that matters

All example-app worktrees share one compose project (`example-app`, fixed container names), and the rails
service mounts `${PWD}`. If the stack is running from another worktree, the script warns. In that
case, up/restart/rebuild in this lazydocker would recreate the stack with *this* worktree's code.
Pass that warning on to the user. Never press keys in the lazydocker pane yourself.

## Rules

- Never send keystrokes to the lazydocker pane.
- It must run inside tmux. If `$TMUX` is empty, give the user the command to run from a tmux
  pane (`--print` works outside tmux).
- Don't kill or reuse windows the user made.
