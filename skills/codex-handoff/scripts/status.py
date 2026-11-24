#!/usr/bin/env python3
"""Summarise a Codex --json log: thread id, progress, commands, failures and the final message.

    status.py <log.jsonl> [--commands]
"""
import json
import pathlib
import sys
from collections import Counter


def load(path):
    events = []
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return events


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    log = pathlib.Path(sys.argv[1])
    show_commands = "--commands" in sys.argv
    events = load(log)

    thread = next((e.get("thread_id") for e in events if e.get("type") == "thread.started"), None)
    finished = any(e.get("type") in ("turn.completed", "turn.failed") for e in events)
    failed = [e for e in events if e.get("type") in ("turn.failed", "error")]
    items = [e.get("item", {}) for e in events if e.get("type") == "item.completed"]
    commands = [i for i in items if i.get("type") == "command_execution"]
    bad = [c for c in commands if c.get("exit_code") not in (0, None)]
    denied = [c for c in commands if "Operation not permitted" in (c.get("aggregated_output") or "")]
    edits = [i for i in items if i.get("type") == "file_change"]

    print(f"thread:   {thread}")
    if not events:
        err = log.with_suffix(".err")
        print("state:    NO EVENTS (still starting, or hung; check the .err file)")
        if err.exists():
            print("stderr:   " + " | ".join(err.read_text().strip().splitlines()[-3:]))
        return
    print(f"state:    {'FAILED' if failed else 'FINISHED' if finished else 'RUNNING'}")
    print(f"items:    {dict(Counter(i.get('type') for i in items))}")
    print(f"commands: {len(commands)} run, {len(bad)} non-zero exit, {len(denied)} denied by the sandbox")
    for c in denied:
        print(f"  DENIED  {c.get('command', '')[:160]}")
    for e in failed:
        print(f"  ERROR   {json.dumps(e)[:300]}")
    if edits:
        paths = sorted({ch.get("path", "?") for i in edits for ch in i.get("changes", [])})
        print("files:    " + ", ".join(paths))
    if show_commands:
        for c in commands:
            print(f"  [{c.get('exit_code')}] {c.get('command', '')[:200]}")
    usage = next((e.get("usage") for e in reversed(events) if e.get("type") == "turn.completed"), None)
    if usage:
        print(f"tokens:   {usage}")
    last = log.with_name(log.name.replace(".jsonl", ".last.md"))
    if finished and last.exists():
        print("\n--- final message ---\n" + last.read_text())


main()
