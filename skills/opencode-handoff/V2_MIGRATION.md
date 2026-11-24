# opencode v1 → v2: what broke the handoff skill, and how it was fixed

2026-11-13. opencode was upgraded to **v2.2.5** (Homebrew `opencode-v2`) while a
handoff was paused on a provider usage limit. The next
launch failed at once. This note records what changed, how each change was
found, and what the `opencode-handoff` skill does about it now.

## How it showed up

The relaunch exited in under a second with
`ERROR Unrecognized flag: --dir in command opencode run` (exit 1). `status.py`
then failed too: `could not read session ... (opencode export): Expecting
value`, because `opencode export` no longer exists.

## How the changes were found

1. Read `opencode --help`, `opencode run --help` and `opencode session --help`.
2. Exported the paused session with the new command and compared its JSON
   with what `status.py` parsed.
3. Ran tiny throwaway sessions in a scratch folder (not the project), each
   asking the model to do one specific thing:
   - "reply hi": flags and log output
   - write a file inside and outside the folder: permission behaviour
   - the same with `permission.external_directory: "deny"`
   - shell commands with `../`, `cd ..`, absolute outside paths, `git push`,
     and secret-path patterns, each under shell deny rules
   - an `external_directory` allow-list for one outside folder

## What changed, and what the skill does now

| Area | v1 | v2 (observed) | Fix |
| --- | --- | --- | --- |
| Project directory | `opencode run --dir DIR` | flag removed; the working directory is the project | `launch.sh` already `cd`s to `--dir`; dropped the flag |
| Log level | `--log-level DEBUG` | only lower case (`debug`, `info`); `DEBUG` is a CLI error | `--log-level info` |
| Process model | one process | a shared background service by default; `--standalone` starts a private server child (`opencode serve --stdio`) | `--standalone`, so `--print-logs` includes server logs and each run is isolated. On a hang, `launch.sh` kills the child too: a plain kill left it running |
| Progress signals | debug lines `message=init`, `message=stream`, `session.id=ses_…`, `permission requested … auto-rejecting` | none of these are logged | `--format json`: one JSON event per line (`step_start`, `tool_use`, `text`, `step_finish`), each with `sessionID`. Hang detection now waits for `"type":"step_start"` |
| Startup hangs | after `init`; `--log-level DEBUG` seemed to help | still happen, silently (2 of 10 test launches printed nothing for 2+ minutes) | `launch.sh`'s retry-on-hang loop kept (45 s, up to 2 retries) |
| Session export | `opencode export ID`; messages `{info:{role,time}, parts:[…]}` | `opencode session export ID`; messages `{type, time, content:[…]}`; tool parts have `name` and `state.input.path`; provider errors are `provider.error` content parts | `status.py` rewritten for the new shape |
| Session list | global, filtered by directory | scoped to the working directory's project | `sessions.py` already ran from `--dir`; no change |
| Tool names | `bash`, file tools take `filePath` | `shell`; file tools take `path` (the old session got a system message about it) | Continuation prompts mention the new names |
| **Permissions** | headless runs auto-rejected anything needing approval (writes outside the project, `/tmp`), and the turn ended | **nothing is refused by default**: a test wrote a file outside the folder with no approval. A denied call returns `Permission denied` to the model and the turn goes on | See below |
| v1 sessions | – | survive the upgrade and can be continued | – |

### The permission change

This was the dangerous one. The skill's safety story leaned on v1 refusing
work outside the project, and on workspace rules such as never touching the
secrets directories. Measured under v2 with a project `opencode.json`:

| Rule | Blocks | Doesn't block |
| --- | --- | --- |
| `"external_directory": "deny"` | read/write/edit tools outside the folder; `cd ..` in the shell | shell commands using absolute outside paths (`head /etc/hosts`, `echo x > /abs/outside`) |
| `"shell": {"*": "allow", "*../*": "deny", "cd *": "deny"}` | `../` paths, `cd` | absolute paths |
| `"*git push*": "deny"`, `"*/work/private-data*": "deny"`, `"*local-credentials.json*": "deny"`, … | any command containing them (matched as text) | paths spelt differently (e.g. through a variable) |
| `"external_directory": {"*": "deny", "/etc/*": "allow"}` | works as an allow-list for file tools | – |

The last matching rule wins, so `"*": "allow"` goes first.

What the skill does now:

- **`launch.sh` refuses to start** unless the project's `opencode.json`
  denies `external_directory` (or has `"*": "deny"` in a map) and has a shell
  `"*../*": "deny"` rule. `--no-permission-check` overrides this.
- **`launch.sh` refuses non-v2 opencode**, since the flags differ both ways.
- **SKILL.md step 2** tells you to add deny rules for every secret location,
  because absolute shell paths aren't otherwise blocked.
- **`status.py` reports `DENIED`** for each blocked call. In v2 the turn goes
  on after a denial, so the reviewer checks whether the agent stopped (as the
  prompt says) or tried a workaround.
- **PROMPT_TEMPLATE.md** says denials return "Permission denied", and treats a
  denial like a STOP: no retries and no workarounds.

Remaining gap: the shell is not a sandbox. A command that reaches an outside
path some other way (a variable, a script file) isn't caught by text
patterns. The prompt rules and Claude's review are still the real defence.
Check `git status`, and look at nothing having changed outside the repo.

## Files changed in the skill

- `scripts/launch.sh`: v2 flags, version check, permission preflight,
  JSON-event hang detection, kills the server child on a hang.
- `scripts/status.py`: parses JSON events (state, `DENIED`, provider limits,
  last events) and the new export format.
- `SKILL.md`: step 2 (permission rules), steps 6–7 (hangs, `DENIED`, exit-1
  flag errors), a "opencode v2 notes" table, and a rule to smoke-test after any
  opencode upgrade.
- `PROMPT_TEMPLATE.md`: the unattended rules for v2's permission behaviour.
- `scripts/make_setup_doc.py` → `SETUP.md` regenerated.

## Lesson

After any opencode upgrade, run a tiny scratch-folder session before the next
handoff. Check the flags, that JSON events arrive, and that a `../` write is
denied. A CLI that changes its defaults can silently remove a safety
guarantee the workflow depends on. Here the visible break (a removed flag)
happened to come first and led to the hidden one.
