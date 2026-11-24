#!/usr/bin/env python3
"""Save ~/.agents/skills/branch-diff/SETUP.md to the knowledge base.

Calls SaveMarkdownDocument on the knowledge-base-http MCP endpoint configured in
~/.claude.json, expanding ${MCP_PRIVATE_TOKEN} from the environment. Saving the
same path again updates the document.
"""
import json
import os
import urllib.request

cfg = json.load(open(os.path.expanduser("~/.claude.json")))["mcpServers"]["knowledge-base-http"]
path = os.path.expanduser("~/.agents/skills/branch-diff/SETUP.md")
args = {
    "path": path,
    "content": open(path).read(),
    "title": "Setting up the branch-diff skill (/branch-diff) on a new machine",
    "tags": ["setup", "branch-diff", "skills", "tmux", "lazygit", "claude-code", "opencode", "codex"],
    "status": "completed",
}
body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                   "params": {"name": "SaveMarkdownDocument", "arguments": args}}).encode()
req = urllib.request.Request(cfg["url"], data=body, method="POST", headers={
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
    "Authorization": os.path.expandvars(cfg["headers"]["Authorization"]),
})
with urllib.request.urlopen(req, timeout=120) as response:
    raw = response.read().decode()
text = "".join(line[5:].strip() for line in raw.splitlines() if line.startswith("data:")) or raw
reply = json.loads(text)
if "error" in reply:
    raise SystemExit(f"error: {reply['error']}")
for part in reply["result"].get("content", []):
    print(part.get("text", ""))
