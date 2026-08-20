#!/bin/bash
# a-b-tester PreToolUse gate.
# Active only when a .ab-test/state.json with phase "testing" exists at or
# above the current working directory. While testing, the primary agent may
# not modify cases/* or lint/TS config files.
AB_GATE_PAYLOAD=$(cat) exec python3 - <<'PY'
import json
import os
import re
import sys

payload = json.loads(os.environ.get("AB_GATE_PAYLOAD") or "{}")
tool = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {}) or {}
cwd = payload.get("cwd") or os.getcwd()

# Find the enclosing test run (walk up looking for .ab-test/state.json).
root = None
d = os.path.abspath(cwd)
while True:
    if os.path.isfile(os.path.join(d, ".ab-test", "state.json")):
        root = d
        break
    parent = os.path.dirname(d)
    if parent == d:
        break
    d = parent

if root is None:
    sys.exit(0)

try:
    with open(os.path.join(root, ".ab-test", "state.json")) as f:
        state = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

if state.get("phase") != "testing":
    sys.exit(0)

LINT_CONFIG = re.compile(
    r"(^|/)(\.eslintrc(\.[a-z]+)?|eslint\.config\.[a-z]+|tsconfig[^/]*\.json|biome\.jsonc?)$"
)

def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"a-b-tester gate: {reason}",
        }
    }))
    sys.exit(0)

def in_cases(path):
    p = os.path.abspath(os.path.join(cwd, path) if not os.path.isabs(path) else path)
    return p.startswith(os.path.join(root, "cases") + os.sep)

if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
    path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    if in_cases(path):
        deny("test is in progress — the primary agent may not modify cases/*. "
             "Case agents own those directories.")
    if LINT_CONFIG.search(path):
        deny("test is in progress — lint/TypeScript config files may not be changed.")

elif tool == "Bash":
    cmd = tool_input.get("command", "")
    write_ish = re.compile(
        r"(\brm\b|\bmv\b|\bcp\b|\btee\b|\btouch\b|\bmkdir\b|\bsed\s+-i|\bln\b|\bchmod\b)"
    )
    redirect_into_cases = re.compile(r">>?\s*\S*cases/")
    # codex runs inside case dirs by design; everything else that references
    # cases/ and looks like a write (or redirects into cases/) is blocked.
    # Reading cases/ and redirecting elsewhere (e.g. metrics into results/)
    # stays allowed.
    if "codex" not in cmd and re.search(r"\bcases/", cmd) and (
        write_ish.search(cmd) or redirect_into_cases.search(cmd)
    ):
        deny("test is in progress — Bash commands may not write inside cases/*.")
    if LINT_CONFIG.search(cmd) and (write_ish.search(cmd) or ">" in cmd):
        deny("test is in progress — lint/TypeScript config files may not be changed.")

sys.exit(0)
PY
