#!/usr/bin/env python3
"""spec-distill 훅이 공유하는 조각. **사본이 아니다** — 같은 플러그인 안이므로
import 하나로 중복이 소멸한다(설계 §6.1③). 배포 경로는 훅과 같은 플러그인 트리라
`${CLAUDE_PLUGIN_ROOT}/scripts/` 로 함께 실린다. `copy-of` 마커도 사본 동일성 검사도
붙지 않는다 — 지킬 두 번째 파일이 없다.

이름이 hook_common 인데 훅이 아닌 소비자도 있다:

  - `arm_ledger.py`(scripts/) 가 `state_file_for` 를 쓴다. 그 함수는 훅이 읽고 쓰는
    상태 파일의 경로 해석이고, 두 번째 정의가 있다는 사실 자체가 arm_ledger 쪽
    docstring("저장소 위치 변경 시 이 한 곳만 갱신")을 거짓으로 만들고 있었다
    (census #122). 정의가 여기로 오면서 그 문장이 다시 참이 됐다.
  - `merge_review.py` · `merge_brief_review.py` · `brief_review_state.py` 가
    `_yaml_scalar` 을 쓴다(census #45의 spec-distill 부분).

**담지 않는 것** — `kill_switch_active`(Task 19의 `shared/killswitch/` 정본에서
온다. 여기로 다시 가져오면 정본이 둘이 된다) · `resolve_session_id` / `state_root`
(`state_path.py` 소유).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

SCRIPTS_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPTS_DIR.parent / "hooks"

GC_SCRIPT = SCRIPTS_DIR / "spec-distill-gc.py"

PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n"
    r"(?:  worktree_path:\s*(?P<wt>[^\n]+)\n)?"
    r"  triggered_at:\s*(?P<triggered>[^\n]+)\n",
    re.MULTILINE,
)
LAST_DISPATCHED_RE = re.compile(r"^last_dispatched_at:\s*(.+)$", re.MULTILINE)


def configure_utf8_streams() -> None:
    """표준 스트림을 UTF-8 로 고정한다 (v0.25.0).

    `read_text(encoding="utf-8")` 와 달리 stdin 디코딩은 **프로세스 locale** 을
    따르므로, LC_ALL=C 환경에서 훅 payload 의 한국어(UserPromptSubmit 의 user prompt,
    PostToolUse 의 문서 내용)가 UnicodeDecodeError 로 훅을 죽인다 — 이 플러그인이
    [0.24.4] 에서 이미 겪은 실패다. except 절을 늘려 열거하는 대신 클래스 자체를
    없앤다 (check_verbatim_coverage.py 와 동일 패턴).

    훅의 **첫 문장**으로 호출해야 한다. stdin 을 읽은 뒤에 부르면 이미 늦다.
    """
    for _s in (sys.stdin, sys.stdout, sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
        except (AttributeError, OSError):
            pass


def fire_and_forget_gc() -> None:
    """TTL-GC 를 best-effort 로 한 번 돌린다. 실패는 non-fatal 이되 조용하지 않다.

    훅의 본업이 아니므로 결과를 기다려 판단하지 않는다 — 다만 GC 가 멈춘 사실이
    보이지 않으면 상태 폴더가 조용히 쌓이므로, 두 실패 모드(비정상 rc · 실행 자체
    실패) 모두 stderr 로 낸다.
    """
    try:
        result = subprocess.run(
            ["python3", str(GC_SCRIPT)],
            timeout=5, check=False, capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(
                f"[spec-distill] GC exited rc={result.returncode}: {result.stderr.strip()}",
                file=sys.stderr,
            )
    except (subprocess.TimeoutExpired, OSError) as exc:
        print(
            f"[spec-distill] gc fire-and-forget failed (non-fatal): {exc}",
            file=sys.stderr,
        )


def parse_iso(s) -> Optional[datetime]:
    """`YYYY-MM-DDTHH:MM:SSZ` → tz-aware datetime. 판독 불가면 None.

    두 훅이 갈라진 본문을 갖고 있었다(review-dispatch 10줄 / pending-review-reminder
    7줄). 실측하면 **모든 문자열 입력에 대해 두 본문의 결과는 같았고**(빈 문자열과
    `"null"` 은 어느 쪽이든 None — 긴 쪽은 명시 가드로, 짧은 쪽은 strptime 의
    ValueError 로), 유일한 차이는 비-문자열 입력이었다: 짧은 쪽만 `AttributeError`
    를 삼켜 None 을 냈다. 즉 짧은 쪽이 오히려 **더** 관대했다. 그래서 한쪽을 정본으로
    고르지 않고 합집합을 쓴다 — 명시 가드(읽는 사람에게 의도를 보이는 쪽)와 비-문자열
    관용(훅을 traceback 으로 죽이지 않는 쪽)을 함께 담는다.
    """
    try:
        s = s.strip()
    except AttributeError:
        return None
    if not s or s.lower() == "null":
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def state_file_for(session_id: str) -> Path:
    """sid → state.local.md 경로 단일 해석(저장소 위치 변경 시 이 한 곳만 갱신).

    `state_path` import 를 함수 안에 둔다. 이 모듈의 `_yaml_scalar` 만 쓰는 소비자가
    셋 있고(merge_review · merge_brief_review · brief_review_state) 그 셋은 상태 경로를
    전혀 해석하지 않는다 — 모듈 최상단에서 import 하면 그 셋이 훅 트리의
    `state_path.py` 에 import 시점으로 묶인다.
    """
    if str(HOOKS_DIR) not in sys.path:
        sys.path.insert(0, str(HOOKS_DIR))
    from state_path import state_root  # pyright: ignore[reportMissingImports]
    return state_root() / session_id / "state.local.md"


def _yaml_scalar(v) -> str:
    """값 하나를 YAML 인라인 스칼라로. 필요할 때만 인용한다.

    spec-distill 안에 세 벌이 있었고 셋 다 달랐다 — 빈 문자열 가드(`merge_review` 에만
    없었다) · escape 문자 집합(`[]{}` 가 `brief_review_state` 에만 있었다) · 숫자와
    None 처리(`brief_review_state` 는 float 도 None 도 다루지 않았다). **합집합**을
    쓴다: 더 인용하는 것은 파싱 결과를 바꾸지 않고, 덜 인용하는 것만 바꾼다.

    합집합이 실제로 고치는 것(실측):
      - 빈 문자열이 따옴표 없이 나가면 YAML 은 그것을 null 로 읽는다(`merge_review`).
      - `[` 로 시작하고 `:` 를 안 가진 advisory 문구가 인용 없이 나가면 YAML flow
        sequence 로 읽힌다. 두 merge 스크립트의 advisory 리터럴 중 **5건**이 이
        모양이었다(예: "[spec-distill …] review indeterminate …").
      - None 이 `brief_review_state` 에서 `None` 이라는 문자열로 나갔다(도달 경로는
        없다 — 서브커맨드 인자가 전부 required 라 항상 str 이다).

    ensure_ascii=False: 이 리포는 Korean-primary 이고 advisory 는 한국어다 —
    \\uXXXX 로 escape 하면 사람이 읽는 게이트가 판독 불가가 된다. 산출 파일은 UTF-8.
    """
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if s == "" or any(c in s for c in ":#\"'\n[]{}") or s.strip() != s:
        return json.dumps(s, ensure_ascii=False)
    return s
