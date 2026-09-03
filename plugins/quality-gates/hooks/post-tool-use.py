#!/usr/bin/env python3
"""PostToolUse hook for quality-gates plugin.

Detects when `gh pr create` succeeds and emits two channels to trigger
the quality pipeline: a human-facing fact on systemMessage and the
model-facing setup + Skill-invoke instruction on
hookSpecificOutput.additionalContext. Self-session scope: checks only
`.claude/quality-gates/<session-id>/pipeline.md` for the active flag.
Passes --session-id explicitly to setup-qg.sh in case env var is unset.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_QUALITY_GATES_DISABLE=1                     - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use      - skip just this one
  DEVBREW_SKIP_HOOKS=quality-gates:PostToolUse        - skip every PostToolUse hook here

토큰은 **전체 토큰**으로 대조된다(정본 `shared/killswitch/kill_switch_active.py`)
— 부분 문자열 접두 일치로는 이 훅이 다른 키 지정 때 조용히 함께 꺼지지 않는다
(예: `quality-gates:session-start-advisor`와 `quality-gates:session-start-advisor:frontmatter-scan`처럼
한쪽이 다른 쪽의 리터럴 접두인 경우도 각각 독립적으로 켜고 끌 수 있다).
"""

import json
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402


def main():
    if kill_switch_active("quality-gates", "post-tool-use", "PostToolUse"):
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

    publish_sentinel = os.path.join(
        project_dir, ".claude", "quality-gates", session_id, "publish-active.md"
    )
    if os.path.exists(publish_sentinel):
        # A /qg-publish run created this PR; do not re-trigger the pipeline (AC11).
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

    # 채널 분리 (N1): 사람에게는 사실을, 모델에게는 지시를 — **둘 다** 낸다.
    # `systemMessage` 는 사용자 표시용이고, 모델 컨텍스트에 주입되는 필드는
    # `hookSpecificOutput.additionalContext` 다. 한쪽으로 옮기면 다른 쪽 수신자를
    # 잃는다 — 지시가 사람 채널에만 있으면 강제처럼 보이는 서술이 된다.
    result = {
        "systemMessage": f"Quality Gates: PR created at {pr_url}.",
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": (
                f"Quality Gates: a PR was created at {pr_url}. "
                "You MUST now initialize the quality-gates pipeline. "
                f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
                'Then invoke Skill("quality-gates:quality-pipeline") '
                "to begin the pipeline (Review gate → Runtime gate)."
            ),
        },
    }

    print(json.dumps(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
