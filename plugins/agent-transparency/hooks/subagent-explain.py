#!/usr/bin/env python3
"""SubagentStop — 에이전트가 끝난 직후 설명 자리를 만든다.

이 훅은 **에이전트의 출력 내용을 검사하지 않고**, 차단하지 않으며, 파일을 쓰지
않는다. `agent_type` **라벨**에 따라 세 갈래(무출력 / 상수 B / 상수 A) 중 하나를
고르는 것은 내용 검사가 아니다. `decision` 키를 어떤 경우에도 내지 않는다.
"""
from __future__ import annotations

import json
import os
import sys

KILL_ENV = "DEVBREW_DISABLE_AGENT_TRANSPARENCY"
SKIP_ENV = "DEVBREW_SKIP_HOOKS"
SKIP_TOKEN = "agent-transparency:subagent-explain"

# `/standup` 의 fork 는 이 값으로 온다(2026-08-08 실측: `<플러그인>:<agent name>`).
# 그 fork 의 산출물이 곧 사용자 답변이므로 그것을 다시 설명하라는 지시는 자기모순이다.
SELF_AGENT_TYPE = "agent-transparency:transcript-reader"
WORKFLOW_AGENT_TYPE = "workflow-subagent"
FALLBACK_AGENT_TYPE = "에이전트"

BASE_CONTEXT = (
    "Report on the `{agent_type}` agent that just finished: who ran / what they found / "
    "where the evidence is / how it changed your judgment. Summarize the finding once; "
    "do not reproduce their response verbatim. "
    "Answer in the language the user is writing in."
)
# 워크플로에서 의미 있는 보고 단위는 에이전트 하나가 아니라 워크플로 전체다.
# 설명을 *줄이라*는 것이 아니라 **보고 단위**를 알려 주는 사실 서술이다(K1 억제 금지).
GROUPING_SENTENCE = (
    " This is one piece of a workflow — if other agents from the same workflow "
    "finished alongside it, report them together as one."
)
SYSTEM_MESSAGE = "[agent-transparency] 에이전트 결과 설명 자리"
EXCEPTION_MESSAGE = (
    "[agent-transparency] 훅 예외로 이번 에이전트 결과에 설명 자리가 붙지 않았습니다 (%s)"
)


def killed() -> bool:
    if os.environ.get(KILL_ENV) == "1":
        return True
    raw = os.environ.get(SKIP_ENV, "")
    tokens = [t.strip() for t in raw.replace(";", ",").replace(" ", ",").split(",")]
    return SKIP_TOKEN in [t for t in tokens if t]


def read_agent_type() -> str:
    """stdin 을 읽고 버린다(파이프 깨짐 방지). 못 읽으면 대체값."""
    try:
        raw = sys.stdin.read()
    except Exception:
        return FALLBACK_AGENT_TYPE
    try:
        payload = json.loads(raw)
    except Exception:
        return FALLBACK_AGENT_TYPE
    if not isinstance(payload, dict):
        return FALLBACK_AGENT_TYPE
    value = payload.get("agent_type")
    if not isinstance(value, str) or not value.strip():
        return FALLBACK_AGENT_TYPE
    return value.strip()


def build_output(agent_type: str):
    """세 갈래. None 이면 무출력 갈래(자기 fork)."""
    if agent_type == SELF_AGENT_TYPE:
        return None
    context = BASE_CONTEXT.format(agent_type=agent_type)
    if agent_type == WORKFLOW_AGENT_TYPE:
        context += GROUPING_SENTENCE
    return {
        "hookSpecificOutput": {
            "hookEventName": "SubagentStop",
            "additionalContext": context,
        },
        "systemMessage": SYSTEM_MESSAGE,
    }


def _degraded(exc: Exception) -> None:
    """알리되 주입하지 않는다 — additionalContext 를 비우는 것이 요점이다.

    `json.dumps` 가 죽은 경우에도 이 경로가 살아야 하므로 직접 조립한다.
    """
    try:
        sys.stderr.write("[agent-transparency] hook exception: %r\n" % (exc,))
    except Exception:
        pass
    reason = str(exc).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
    try:
        sys.stdout.write('{"systemMessage": "%s"}' % (EXCEPTION_MESSAGE % reason))
    except Exception:
        pass


def main() -> int:
    try:
        if killed():
            return 0
        output = build_output(read_agent_type())
        if output is None:
            return 0
        sys.stdout.write(json.dumps(output, ensure_ascii=False))
    except Exception as exc:  # 설명 장치가 작업을 막으면 불변식 위반 — 그러나 조용히 죽지도 않는다
        _degraded(exc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
