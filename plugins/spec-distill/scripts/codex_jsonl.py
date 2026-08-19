# copy-of: shared/codex/codex_jsonl.py
"""codex_jsonl.py — codex JSONL 이벤트 스트림에서 마지막 agent_message 텍스트를 뽑는다.

정본화 이전 이력: 같은 알고리즘이 세 곳에 따로 있었다 — quality-gates·spec-distill의
`codex_findings_to_yaml.py`, plugin-audit의 `codex_audit_to_json.py`. codex가 이벤트
shape을 또 바꾸면 그때마다 고칠 자리가 여러 곳이었다. 이 파일은 그 알고리즘의 정본이다.

**알려진 예외 — 통합 안 함(2026-08-17 fix round 1, F6):**
`plugins/quality-gates/scripts/extract_codex_artifact_yaml.py`의 `extract_text`가
비슷한 일을 하는 **네 번째** 구현이다(이 정본에는 안 들어 있다). 그러므로 "codex가
이벤트 shape을 또 바꾸면 고칠 자리가 하나"는 아직 참이 아니다 — 정본(여기)과
`extract_text` 둘이다. 이름 기반 스코핑(sibling extractor로만 한정)이 의도적으로
옳다고 판단했다 — `extract_text`는 이 정본에 없는 폴백들(최상위
`obj.get("message") or obj.get("text")`, legacy `{"msg": {...}}` 형태, `content`
키)을 받고 `any_parsed`를 내지 않는다. 정본을 그 자리에 밀어넣으면 그 세 형태를
조용히 잃고(기능 축소, C10 방향 회귀), 반대로 그 폴백들을 정본에 흡수하면 findings
경로가 비-`agent_message` 이벤트의 텍스트까지 받아들이게 돼 신뢰 안 되는 산출물
바로 아래에서 표면이 넓어진다. 통합하려면 `accept_shapes` 같은 파라미터 + 그 파라미터를
검증하는 락이 필요한 별건이다.

이 모듈은 import-only다 (`if __name__ == "__main__"` 없음, 실행 지점 아님) — 그래서
shebang이 없다. copy-of 물리 사본은 **소비자가 있는 모든 배포 디렉토리**에 있다 —
`plugins/<plugin>/scripts/` 중 `from codex_jsonl import` 하는 스크립트를 가진 곳
전부다(2026-08-17 fix round 1 CRIT-1 이 pa 한 곳에서 그 전부로 넓혔다: pa 는
`codex_audit_to_json.py` 가 실파일이라, qg·sd 는 설치본에서 심볼릭 링크가 실파일로
역참조된 뒤 자기 옆에서 찾기 때문이다). **이름을 세지 말고 도출하라:**

    git ls-files -- 'plugins/*/scripts/*' | grep -v '/codex_jsonl\.py$' \
      | while IFS= read -r f; do grep -q 'from codex_jsonl import' -- "$f" && echo "$f"; done \
      | sed -E 's#^plugins/([^/]+)/.*#\1#' | sort -u

`grep` 이 심볼릭 링크를 따라가므로 qg·sd 의 `codex_findings_to_yaml.py` 링크가
정본 본문을 통해 걸린다. 두 가지가 필수다:

1. **모듈 자신을 코퍼스에서 뺀다.** 안 빼면 사본이 자기 코드·docstring 때문에 자기
   자신의 "소비자" 로 잡혀, 사본을 지우면 그 플러그인이 기대 집합에서 **함께**
   사라지는 fail-open 이 된다(2026-08-17 fix round 2 실측).
2. **제외는 셸 필터로 한다 — `:(exclude)` pathspec 매직을 쓰지 않는다.** 와일드카드가
   섞인 exclude pathspec 은 이 리포에서 의도한 것보다 훨씬 넓게 걸러냈다(실측:
   `plugins/<p>/scripts/` 20개 중 11개가 사라졌다, git 2.50.1).

도출된 플러그인 수만큼 사본이 있어야 한다. 각 사본은
`{ echo "# copy-of: shared/codex/codex_jsonl.py"; cat <이 파일>; }`로 만들어지는데,
그 마커가 파일 맨 앞줄에 붙는다. 이 파일에 shebang이 있었다면 마커가 그 앞에
끼어들어 shebang을 무력화했을 것이다 — 실행 지점이 아니므로 애초에 문제되지 않는다.

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

    공백 가드 — **판정을 뒤집는다, 라벨만 바뀌는 게 아니다** (2026-08-17 fix round 1,
    F2). `candidate.strip()`이 공백뿐이면 그 후보를 **채택하지 않는다** — 즉 뒤따르는
    비어 있는/비-문자열 후보가 앞선 유효한 메시지를 덮어쓰지 못하게 막는다.
    plugin-audit 사본에만 있던 이 가드를 정본에 흡수했다(2026-08-17 통합). 실측
    효과(파이프라인 수준, 진짜 답 뒤에 빈 `agent_message`가 흐르는 스트림):
    가드 없이는 빈 후보가 `last_text`를 덮어써 파싱이 실패하고
    `codex_failed: true`(`reason: malformed_json`)로 끝난다 — **findings가
    소실된다**. 가드가 있으면 앞선 진짜 메시지가 살아남아 `codex_failed: false`
    + 실제 finding이 출력된다. 즉 이 가드는 fail-open 방향으로 판정을 뒤집는다
    (기존 qg/sd 배포가 이 스트림에서 어떻게 답했는지에 대해). 이 방향이 옳다고 본
    이유는 plugin-audit이 늘 이렇게 해 왔고, 뒤따르는 빈 메시지 하나에 진짜
    findings를 잃는 쪽이 더 나쁜 실패이기 때문이다 — 하지만 방향이 바뀌었다는
    사실 자체는 감춰서는 안 된다. 이 동작을 고정하는 락은 둘이다(2026-08-17 fix
    round 2, R2-4·R2-8 — 앞 판본은 존재하지 않는 파일명을 인용했다):
    `plugins/spec-distill/tests/test_codex_findings_to_yaml.py`의
    `test_trailing_blank_agent_message_does_not_clobber_real_one`(sd 배포 지점을
    CLI 로 태우는 경로)와 `plugins/quality-gates/tests/test_codex_copies_agree.sh`의
    **층⑤**(정본과 모든 copy-of 사본을 git 코퍼스에서 도출해 하나씩 태우는 ∀ 축 —
    앞의 것 하나만 있을 때는 정본이나 qg 사본에서 이 가드를 지워도 전부 GREEN 이었다).
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
