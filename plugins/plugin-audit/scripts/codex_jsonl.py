# copy-of: shared/codex/codex_jsonl.py
"""codex_jsonl.py — codex JSONL 이벤트 스트림에서 마지막 agent_message 텍스트를 뽑는다.

정본화 이전 이력: 같은 알고리즘이 세 곳에 따로 있었다 — quality-gates·spec-distill의
`codex_findings_to_yaml.py`, plugin-audit의 `codex_audit_to_json.py`. codex가 이벤트
shape을 또 바꾸면 그때마다 고칠 자리가 여러 곳이었다. 이 파일은 그 알고리즘의 정본이다.

이 모듈은 import-only다 (`if __name__ == "__main__"` 없음, 실행 지점 아님) — 그래서
shebang이 없다. copy-of 물리 사본(`plugins/plugin-audit/scripts/codex_jsonl.py`)은
`{ echo "# copy-of: ..."; cat <이 파일>; }`로 만들어지는데, 그 마커가 파일 맨 앞줄에
붙는다. 이 파일에 shebang이 있었다면 마커가 그 앞에 끼어들어 shebang을 무력화했을
것이다 — 실행 지점이 아니므로 애초에 문제되지 않는다.

Event shape (Codex 0.130+, discovered in Task 0 spike):
  {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
Legacy shape (still supported as fallback):
  {"type":"agent_message","text":"..."} or {"type":"agent_message","message":"..."}
"""

from __future__ import annotations

import json


def extract_last_agent_message(stdin_text: str) -> tuple[str | None, bool]:
    """Extract text of the last agent_message event.

    Returns (last_text, any_jsonl_parsed). any_jsonl_parsed distinguishes
    "stdin had valid JSONL but no agent_message" (missing_result) from
    "stdin was entirely unparseable bytes" (malformed_json).

    Handles two event shapes:
      1. Codex 0.130+: {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
      2. Legacy:       {"type":"agent_message","text":"..."} or {"type":"agent_message","message":"..."}

    Discovery: Task 0 spike — see fixture
    plugins/quality-gates/tests/spike/fixtures/codex_jsonl_sample.json.

    공백 가드: 후보 텍스트가 공백뿐이면 채택하지 않는다 — plugin-audit 사본에만 있던
    `candidate.strip()` 가드를 정본에 흡수했다(2026-08-17 통합). 이 가드를 빼면
    plugin-audit이 지금 걸러내던 공백-only 메시지를 통과시키게 된다(기능 축소).
    """
    last_text: str | None = None
    any_parsed = False
    for line in stdin_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        any_parsed = True

        if not isinstance(ev, dict):
            continue
        # Drill into nested item if present (Codex 0.130+), else use event directly (legacy).
        item = ev.get("item") if isinstance(ev.get("item"), dict) else ev
        if item.get("type") == "agent_message":
            candidate = item.get("text") or item.get("message")
            if isinstance(candidate, str) and candidate.strip():
                last_text = candidate
    return last_text, any_parsed
