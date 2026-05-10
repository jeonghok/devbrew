#!/usr/bin/env python3
"""PostToolUse hook for quality-gates plugin.

Detects when `gh pr create` succeeds and injects a system message
to trigger the quality pipeline. Self-session scope: checks only
`.claude/quality-gates/<session-id>/pipeline.md` for the active flag.
Passes --session-id explicitly to setup-qg.sh in case env var is unset.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_QUALITY_GATES=1                     - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use      - skip just this one
"""

import json
import os
import re
import sys


def _disabled() -> bool:
    """Honor devbrew kill switches before any side effect."""
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    return "quality-gates:post-tool-use" in skip


def main():
    if _disabled():
        print(json.dumps({}))
        sys.exit(0)
    try:
        input_data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print(json.dumps({}))
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_response = input_data.get("tool_response", {})
    session_id = input_data.get("session_id", "")

    if tool_name != "Bash" or not session_id:
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get("command", "")
    if not re.search(r"gh\s+pr\s+create", command):
        print(json.dumps({}))
        sys.exit(0)

    project_dir = input_data.get("cwd", os.getcwd())
    state_file = os.path.join(
        project_dir, ".claude", "quality-gates", session_id, "pipeline.md"
    )
    if os.path.exists(state_file):
        print(json.dumps({}))
        sys.exit(0)

    if isinstance(tool_response, dict):
        stdout = tool_response.get("stdout", "")
    else:
        stdout = str(tool_response)
    pr_url_match = re.search(r"https://github\.com/[^\s]+/pull/\d+", stdout)
    pr_url = pr_url_match.group(0) if pr_url_match else ""

    if not pr_url:
        print(json.dumps({}))
        sys.exit(0)

    plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    setup_script = os.path.join(plugin_root, "scripts", "setup-qg.sh")

    result = {
        "systemMessage": (
            f"Quality Gates: PR created at {pr_url}. "
            "You MUST now initialize the quality-gates pipeline. "
            f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
            "Then invoke Skill(\"quality-gates:quality-pipeline\") with gate=1 "
            "to begin Gate 1."
        )
    }

    print(json.dumps(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
