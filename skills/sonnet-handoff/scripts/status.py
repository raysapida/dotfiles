#!/usr/bin/env python3
"""Summarise a headless Claude Code run (`claude -p --output-format stream-json --verbose`).

    status.py <log.jsonl> [--commands] [--tail N]

Shows: session id, the model(s) that actually answered, state, tool use, sandbox and permission
blocks, files written, cost, and the final message when the run has ended.
"""
import json
import pathlib
import sys
from collections import Counter

BLOCK_MARKERS = ("Operation not permitted", "operation not permitted", "<sandbox_violations>",
                 "Permission to use", "permission denied")


def load(path):
    events = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return events


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict))
    return str(content or "")


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    log = pathlib.Path(args[0])
    show_commands = "--commands" in args
    tail = int(args[args.index("--tail") + 1]) if "--tail" in args else 5
    events = load(log)

    if not events:
        err = log.with_suffix(".err")
        print("state:    NO EVENTS (still starting, or failed before the first event; check the .err file)")
        if err.exists() and err.read_text().strip():
            print("stderr:   " + " | ".join(err.read_text().strip().splitlines()[-3:]))
        return

    init = next((e for e in events if e.get("type") == "system" and e.get("subtype") == "init"), {})
    result = next((e for e in reversed(events) if e.get("type") == "result"), None)

    tool_uses, results, models, texts = {}, {}, Counter(), []
    for e in events:
        msg = e.get("message") or {}
        if e.get("type") == "assistant":
            if msg.get("model"):
                models[msg["model"]] += 1
            for c in msg.get("content") or []:
                if c.get("type") == "tool_use":
                    tool_uses[c["id"]] = c
                elif c.get("type") == "text" and c.get("text", "").strip():
                    texts.append(c["text"].strip())
        elif e.get("type") == "user":
            for c in msg.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    results[c.get("tool_use_id")] = c

    print(f"session:  {init.get('session_id') or (result or {}).get('session_id')}")
    print(f"model:    init={init.get('model')}  answered={dict(models)}")
    wanted = init.get("model") or ""
    if any(m != wanted for m in models):
        print("  WARNING: a different model answered part of the run (fallback?)")
    print(f"cwd:      {init.get('cwd')}")
    print(f"tools:    {init.get('tools')}  mcp={init.get('mcp_servers')}")

    if result is None:
        state = "RUNNING"
    elif result.get("is_error") or result.get("subtype") != "success":
        state = f"FAILED ({result.get('subtype')}, {result.get('terminal_reason') or result.get('api_error_status') or ''})"
    else:
        state = "FINISHED"
    print(f"state:    {state}")

    names = Counter(t.get("name") for t in tool_uses.values())
    errors = [tid for tid, r in results.items() if r.get("is_error")]
    blocked = [tid for tid, r in results.items() if any(m in text_of(r.get("content")) for m in BLOCK_MARKERS)]
    print(f"tools used: {dict(names)}; {len(errors)} errored, {len(blocked)} blocked by the sandbox/permissions")
    for tid in blocked:
        t = tool_uses.get(tid, {})
        inp = t.get("input") or {}
        print(f"  BLOCKED {t.get('name')} {str(inp.get('command') or inp.get('file_path') or '')[:150]}")
    for d in (result or {}).get("permission_denials") or []:
        inp = d.get("tool_input") or {}
        print(f"  DENIED  {d.get('tool_name')} {str(inp.get('command') or inp.get('file_path') or '')[:150]}")

    files = sorted({(t.get("input") or {}).get("file_path") for t in tool_uses.values()
                    if t.get("name") in ("Write", "Edit") and tid_ok(t, results)} - {None})
    if files:
        print("files:    " + ", ".join(files))

    if show_commands:
        for tid, t in tool_uses.items():
            if t.get("name") == "Bash":
                r = results.get(tid, {})
                flag = "ERR" if r.get("is_error") else ("..." if not r else "ok ")
                print(f"  [{flag}] {(t.get('input') or {}).get('command', '')[:200]}")

    if result is None:
        if texts:
            print("last text:")
            for t in texts[-tail:]:
                print("  " + t.replace("\n", " ")[:200])
        return

    cost = result.get("total_cost_usd")
    mins = (result.get("duration_ms") or 0) / 60000
    print(f"cost:     ${cost:.2f}  turns={result.get('num_turns')}  duration={mins:.1f} min" if cost is not None
          else f"turns={result.get('num_turns')}")
    print("\n--- final message ---\n" + str(result.get("result") or (texts[-1] if texts else "")))


def tid_ok(tool_use, results):
    r = results.get(tool_use.get("id"))
    return bool(r) and not r.get("is_error")


main()
