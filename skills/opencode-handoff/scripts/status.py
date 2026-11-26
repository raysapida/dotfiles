#!/usr/bin/env python3
"""Check an opencode handoff: did it start, is it stuck, what is it doing.

usage: status.py LOG_FILE [--session ID] [--report] [--tail N]

Written for opencode v2 (`opencode run --format json`, as launch.sh runs it).
From the launch log: started / reached the model / HUNG at startup /
permission denials / provider errors / exited, plus the last few events.
With --session: message count, last activity, the last N steps from
`opencode session export`, and with --report the agent's latest full text
(its report when finished).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
import time

HANG_SECONDS = 45
LIMIT_RE = re.compile(r"usage limit|rate limit|quota|429|credits", re.I)  # also matches type "provider.quota"


def tool_input(inp):
    if not isinstance(inp, dict):
        return str(inp)
    return str(inp.get("command") or inp.get("path") or inp.get("filePath")
               or inp.get("pattern") or "")


def log_state(path):
    try:
        text = open(path, errors="replace").read()
    except OSError as e:
        sys.exit(f"cannot read {path}: {e}")
    events, denied, errors = [], [], []
    for line in text.splitlines():
        if not line.startswith("{"):
            if "level=ERROR" in line:
                m = re.search(r'message="([^"]{0,200})"', line)
                c = re.search(r'cause="([^"]{0,200})', line)   # v2 puts the provider's text here
                errors.append((m.group(1) if m else line[:200]) + (" — " + c.group(1) if c else ""))
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        events.append(e)
        p = e.get("part") or {}
        st = p.get("state") or {}
        if e.get("type") == "tool_use" and st.get("status") == "error" \
                and "Permission denied" in str(st.get("error", "")):
            denied.append(f"{p.get('tool')} {tool_input(st.get('input'))[:120]} -> {st.get('error')}")
        if "error" in str(e.get("type", "")):
            errors.append(json.dumps(e.get("error") or e.get("message") or e)[:240])
    for m in re.finditer(r'"message":"([^"]{0,240})"', text):
        if LIMIT_RE.search(m.group(1)) and m.group(1) not in errors:
            errors.append(m.group(1))
    lm = re.search(r"^launch: dir=(\S+)", text, re.M)
    return {
        "exited": re.findall(r"^EXIT (\d+)$", text, re.M),
        "reached_model": any(e.get("type") == "step_start" for e in events),
        "init": 'message="cli starting"' in text or "message=init" in text,
        "denied": denied,
        "provider_errors": errors,
        "session_ids": list(dict.fromkeys(re.findall(r'"sessionID":"(ses_\w+)"', text))),
        "events": events,
        "dir": lm.group(1) if lm else None,
        "age_s": time.time() - os.path.getmtime(path),
        "first": text.splitlines()[0] if text else "",
    }


def event_summary(e):
    p = e.get("part") or {}
    st = p.get("state") or {}
    t = e.get("type")
    if t == "tool_use":
        return f"TOOL {p.get('tool')} {st.get('status')} {tool_input(st.get('input'))[:110]}"
    if t == "text":
        return "TEXT " + str(p.get("text", "")).strip().replace("\n", " ")[:150]
    return str(t)


def export(session, cwd):
    # `opencode session export` (v2; v1 was `opencode export`). Written to a
    # file because large JSON read through a pipe has arrived truncated.
    with tempfile.NamedTemporaryFile("w+", suffix=".json", delete=False) as f:
        path = f.name
    try:
        with open(path, "w") as out:
            subprocess.run(["opencode", "session", "export", session], stdout=out,
                           stderr=subprocess.DEVNULL, timeout=120,
                           cwd=cwd if cwd and os.path.isdir(cwd) else None)
        return json.load(open(path))
    except (json.JSONDecodeError, subprocess.TimeoutExpired) as e:
        sys.exit(f"could not read session {session} (opencode session export): {e}")
    finally:
        os.unlink(path)


def ts(ms):
    return datetime.datetime.fromtimestamp(ms / 1000).strftime("%H:%M:%S") if ms else "-"


def step_summary(msg):
    # v2 export: {"type": "assistant"|"user"|"system", "content": [...]}; user
    # and system messages carry "text" directly.
    for p in reversed(msg.get("content") or []):
        t = p.get("type")
        if t == "text" and p.get("text", "").strip():
            return "TEXT " + p["text"].strip().replace("\n", " ")[:160]
        if t == "tool":
            st = p.get("state") or {}
            return f"TOOL {p.get('name')} {st.get('status')} {tool_input(st.get('input'))[:120]}".replace("\n", " ")
        if t == "provider.error":
            return "ERROR " + str(p.get("message", ""))[:160]
    if msg.get("error"):
        return "ERROR " + json.dumps(msg["error"])[:160]
    if msg.get("text"):
        return "TEXT " + msg["text"].strip().replace("\n", " ")[:160]
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--session")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--tail", type=int, default=5)
    a = ap.parse_args()

    st = log_state(a.log)
    print(st["first"])
    if st["exited"]:
        state = f"FINISHED (exit {st['exited'][-1]})"
    elif st["reached_model"]:
        state = "RUNNING (reached the model)"
    elif "launch.sh: no model call" in open(a.log, errors="replace").read() and st["age_s"] < HANG_SECONDS * 4:
        state = "RETRYING (launch.sh restarted a startup hang; check again shortly)"
    elif st["init"] and st["age_s"] > HANG_SECONDS:
        state = (f"HUNG AT STARTUP: no model call {int(st['age_s'])}s after start. "
                 "Kill the opencode run process (and its `opencode serve --stdio` child) "
                 "and relaunch; the session was not touched.")
    else:
        state = "STARTING"
    print("state:", state)
    for r in st["denied"]:
        print("DENIED:", r, "(the agent got an error and its turn went on; check how it reacted)")
    if st["provider_errors"]:
        # any limit/quota error wins: a generic error (e.g. "Failed to drain Session")
        # often follows the quota error as the last line
        limits = [e for e in st["provider_errors"] if LIMIT_RE.search(e)]
        last = limits[-1] if limits else st["provider_errors"][-1]
        kind = "PROVIDER LIMIT" if limits else "PROVIDER ERROR"
        print(f"{kind} ({len(st['provider_errors'])}x): {last}")
        if kind == "PROVIDER LIMIT":
            print("  The model provider refused further calls. Wait for the limit to reset or "
                  "switch --model; the session keeps its history, so a continuation can resume it.")
    if st["exited"] and st["exited"][-1] != "0" and not st["reached_model"]:
        print("  Exit before any model call: read the log's last lines (bad flag? see launch.sh).")
    shown = [e for e in st["events"] if e.get("type") in ("tool_use", "text")][-a.tail:]
    if shown and not a.session:
        print("last events:")
        for e in shown:
            print(f"  {ts(e.get('timestamp'))} {event_summary(e)}".replace("\n", " "))

    session = a.session or (st["session_ids"][-1] if st["session_ids"] else None)
    if not session:
        return
    d = export(session, st["dir"])
    msgs = d.get("messages", [])
    last = msgs[-1].get("time", {}).get("created") if msgs else None
    print(f"session {session}: {len(msgs)} messages, last activity {ts(last)}")
    for m in msgs[-a.tail:]:
        print(f"  {ts(m.get('time', {}).get('created'))} {str(m.get('type'))[:4]} | {step_summary(m)}")
    if a.report:
        for m in reversed(msgs):
            if m.get("type") != "assistant":
                continue
            texts = [p["text"] for p in m.get("content") or []
                     if p.get("type") == "text" and p.get("text", "").strip()]
            if texts:
                print("\n--- latest agent text ---\n" + texts[-1])
                break


if __name__ == "__main__":
    main()
