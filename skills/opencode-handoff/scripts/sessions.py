#!/usr/bin/env python3
"""List recent opencode sessions for a project directory.

usage: sessions.py [--dir DIR] [--all] [-n N]
Prints: id, last update, last handoff model, title. Default dir is the current
directory. opencode doesn't record a session's model, so it comes from
launch.sh's logs in ~/.cache/opencode-handoff/ ("-" if no handoff used it).
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess
import sys

LOG_GLOB = os.path.expanduser("~/.cache/opencode-handoff/*.log")


def models_by_session():
    """Map session id -> model of the newest handoff log that used it."""
    found = {}
    for path in sorted(glob.glob(LOG_GLOB), key=os.path.getmtime):  # oldest first; newer wins
        try:
            text = open(path, errors="replace").read()
        except OSError:
            continue
        m = re.search(r"^launch: .*?model=(\S+)", text, re.M)
        if not m:
            continue
        ids = re.findall(r"^launch: .*?session=(ses_\w+)", text, re.M)
        ids += re.findall(r'"sessionID":"(ses_\w+)"', text)[:1]
        for sid in ids:
            found[sid] = m.group(1).split("/", 1)[-1]
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.getcwd())
    ap.add_argument("--all", action="store_true", help="all projects")
    ap.add_argument("-n", type=int, default=10)
    a = ap.parse_args()
    want = os.path.realpath(a.dir)
    try:
        # opencode lists the sessions of the project in its working directory,
        # so run it from the requested directory
        out = subprocess.run(["opencode", "session", "list", "--format", "json",
                              "-n", "200"], capture_output=True, text=True,
                             timeout=60, cwd=want)
        sessions = json.loads(out.stdout or "[]")
    except Exception as e:  # noqa: BLE001
        sys.exit(f"could not list opencode sessions: {e}")
    if not a.all:
        sessions = [s for s in sessions
                    if os.path.realpath(s.get("directory", "")) == want]
    if not sessions:
        print(f"no opencode sessions for {want}" if not a.all else "no sessions")
        return
    models = models_by_session()
    for s in sessions[: a.n]:
        t = datetime.datetime.fromtimestamp(s["updated"] / 1000).strftime("%Y-%m-%d %H:%M")
        where = "" if not a.all else f"  [{s.get('directory')}]"
        print(f"{s['id']}  {t}  {models.get(s['id'], '-'):<16}  {s.get('title', '')}{where}")


if __name__ == "__main__":
    main()
