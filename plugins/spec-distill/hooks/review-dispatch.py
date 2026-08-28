#!/usr/bin/env python3
"""spec-distill Stop hook — 발견 · 구조 검증 · 리뷰 dispatch.

세 가지를 이 순서로 한다.

1. **발견** — `discover_candidates.discover()` 가 `git status` 하나로 이 리포의
   dirty·untracked 스코프 문서를 낸다. git 을 쓸 수 없으면 후보 0 과 **구별해서**
   세션당 1회 advisory 를 내고 그 턴은 아무것도 하지 않는다(A16).
2. **구조 검증** — 발견된 문서를 `parse_spec_structure` 의 순수 함수로 검사한다.
   파서를 subprocess 로 부르지 않는다(A4): 훅 timeout 이 10초인데 호출마다
   `timeout=10` 을 걸면 문서 하나가 느려도 훅 전체가 신호 없이 죽는다. 검증은
   TTL 가드보다 **먼저** 돈다(A10) — 가드가 앞이면 dispatch 후 TTL 창 동안 Bash 로
   쓴 깨진 문서의 검증이 통째로 건너뛰어진다. 실패가 하나라도 있으면 그 사유만
   block 으로 나가고 dispatch 는 그 턴에 없다(A11).
3. **dispatch** — 같은 후보 목록에서 하나를 골라(`select_dispatch_target`)
   `reviewing-spec` 을 다음 턴 첫 액션으로 강제한다. 반복 억제는 원장이 맡는다:
   dispatch 시점에 그 문서를 in-flight 로 표시해(A12) 리뷰가 도는 동안 발견
   결과에서 빠지게 하고, `dispatch_attempts`·`armed_paths` 가 그 위에 상한을 준다.

턴당 검증 상한(`CANDIDATE_CAP`)에는 커서 회전을 얹는다(A13). 정렬이 안정적이라는
사실 자체가 기아의 원인이므로, 안정 정렬 위에 회전이 없으면 상한을 넘는 dirty
문서의 뒤쪽이 영구히 검증되지 않는다.

Ordering guarantee (AC7.1): `rewrite_state()` must complete (with fsync) BEFORE
the JSON is printed. Reverse ordering races with a second Stop fire and
produces a block storm. On rewrite failure — `OSError` 든 원장 블록 기록 실패
(`LedgerWriteError`) 든 — the hook exits `{}` 0 (no block) to preserve the
race-free TTL guard (AC7.2·A15) — 발견은 무상태이므로 다음 Stop 이 같은 문서를
다시 찾는다. 둘을 가르지 않는 이유는 잃는 것이 같아서다: 그 write 가 실패하면
`dispatch_attempts`(G6 상한)도 `inflight_paths`(발견 제외)도 남지 않으므로,
block 만 내보내면 남는 상한이 30초 TTL 하나뿐인 루프가 된다.

Kill switches:
- DEVBREW_SPEC_DISTILL_DISABLE=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)

이 훅의 kill switch 는 발견·검증·dispatch 를 **모두** 지배한다(A18) — 셋이 같은
프로세스의 한 진입점 뒤에 있기 때문이다.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import resolve_session_id  # noqa: E402
from kill_switch_active import kill_switch_active  # noqa: E402
# `scripts/` 와 공유하는 조각 — 같은 플러그인 안이라 import 하나로 중복이
# 소멸한다(설계 §6.1③). 사본이 아니다.
from hook_common import (  # noqa: E402
    LAST_DISPATCHED_RE,
    configure_utf8_streams,
    fire_and_forget_gc,
    parse_iso,
    state_file_for,
)
# 구조 검증은 **import 로** 한다 (A4). `cmd_*` CLI 래퍼가 아니라 그 아래의 순수
# 함수를 직접 부른다 — 래퍼는 호출마다 파일을 자기가 다시 읽으므로 spec 모드에서
# 같은 파일을 네 번 읽었고, 그 넷이 각각 자기 timeout 을 들고 훅의 timeout 안에
# 중첩됐다.
from parse_spec_structure import (  # noqa: E402
    find_missing_sections, load_blacklist, parse_frontmatter,
    scan_ambiguity, scan_placeholders, validate_locked_decisions,
)
from resolve_mode import resolve_mode  # noqa: E402
from discover_candidates import Candidate, GitUnavailable, discover  # noqa: E402

# stdin 을 읽기 **전에** 표준 스트림을 UTF-8 로 고정한다. 위 import 들은 stdin 을
# 건드리지 않으므로 이 자리가 여전히 "첫 문장"이다 (근거는 hook_common 쪽 docstring).
configure_utf8_streams()

BLACKLIST = SCRIPTS_DIR / "ambiguity-blacklist.txt"

#: 한 턴에 구조 검증하는 문서 수의 상한. 훅 timeout 안에 들어가야 한다.
#: 상한 단독으로는 기아를 만든다 — `select_keys` 의 회전이 그 짝이다(A13).
CANDIDATE_CAP = 5

GIT_UNAVAILABLE_ADVISORY = (
    "[spec-distill] git 을 쓸 수 없어 스코프 문서 발견이 불가능하다 — 이 세션에서는 "
    "구조 검증도 자동 리뷰 dispatch 도 일어나지 않는다. 리포에서 세션을 열거나 "
    "reviewing-spec 을 직접 호출하라."
)
#: A16 은 advisory 를 **세션당 1회**로 요구한다 — 매 턴 반복하면 무시되는 신호가 된다.
GIT_UNAVAILABLE_MARKER = "git_unavailable_advised: yes"

#: v0.36.0 에서 삭제된 두 훅의 kill-switch 토큰. 훅명 별칭과 이벤트명 별칭을 함께
#: 담는다 — `kill_switch_active` 가 둘 다 받았으므로 사용자가 어느 쪽을 적었는지
#: 알 수 없다.
RETIRED_TOKENS = (
    "spec-distill:validator", "spec-distill:PostToolUse",
    "spec-distill:reminder", "spec-distill:UserPromptSubmit",
)
#: 같은 릴리스에서 함께 죽은 **환경변수** 스위치. 삭제된 write-time validator 훅만이
#: 읽었고 지금은 읽는 곳이 없다. `DEVBREW_SKIP_HOOKS` 의 토큰이 아니라 독립 변수이므로
#: 아래에서 **읽던 방식 그대로** `== "1"` 로 본다.
RETIRED_AUTOREVIEW_VAR = "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW"
#: A19 는 advisory 를 **세션당 1회**로 요구한다 (GIT_UNAVAILABLE_MARKER 와 같은 이유).
RETIRED_MARKER = "retired_token_advised: yes"


def retired_switch_advisory(body: str) -> tuple[str, str | None]:
    """설정된 은퇴 스위치가 있으면 (새 body, advisory) — 세션당 1회.

    두 축을 본다. 공통 규칙은 **각 스위치를 읽던 방식 그대로 읽는다**이다.

      · `DEVBREW_SKIP_HOOKS` 토큰 넷 — `kill_switch_active` 와 같이 콤마로 쪼개고
        양끝 공백을 벗긴 뒤 **전체 토큰**으로 맞춘다. 부분 문자열(`t in raw`)로 재면
        방향만 반대인 같은 결함이 생긴다: `spec-distill:validator-v2` 가 이 advisory
        를 발화시켜, 설정하지도 않은 토큰이 설정돼 있다고 말하게 된다.
      · `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW` — 삭제된 validator 가 `== "1"` 로
        읽었으므로 여기서도 그렇게 읽는다. "설정만 돼 있으면"(`is not None`)으로
        재거나 위 토큰 집합에 끼워 넣으면 `=0` 으로 **꺼 둔** 사용자에게까지
        "당신의 스위치가 죽었다"고 말하게 된다.

    kill switch 를 설명하는 문장이 그 kill switch 와 다르게 매칭하면 언젠가 사용자
    자신의 설정에 대해 거짓을 말한다.

    수명 사실만 적는다. "이제 안 걸린다" 같은 집행 공백은 적지 않는다 — 그것은
    모델이 스스로 리뷰를 면제할 근거가 되어 Law 2 를 뚫는다. 같은 이유로 **없는
    대체재를 가리키지도 않는다**: `SKIP_AUTOREVIEW` 가 주던 것("구조 검증은 유지한
    채 dispatch 만 중단")은 새 설계에 등가물이 없고, `spec-distill:Stop` 을 대안처럼
    적으면 둘을 다 끄는 스위치를 같은 것이라 말하는 거짓이 된다.

    `kill_switch_active` 를 은퇴 쌍마다 부르지 않는 이유: 그 함수는 bool 만 내므로
    **어느 별칭**이 설정됐는지 이름을 댈 수 없다. 사용자 자신의 토큰을 되읽어 주는
    것이 이 문구를 실행 가능하게 만드는 부분이다.
    """
    if RETIRED_MARKER in body:
        return body, None
    raw = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in raw.split(",") if t.strip()}
    hit = [t for t in RETIRED_TOKENS if t in tokens]
    autoreview_set = os.environ.get(RETIRED_AUTOREVIEW_VAR) == "1"
    if not hit and not autoreview_set:
        return body, None
    parts: list[str] = []
    if hit:
        parts.append(
            f"DEVBREW_SKIP_HOOKS 에 은퇴한 토큰이 있다: {', '.join(hit)}. "
            "v0.36.0 에서 그 훅들이 삭제됐고 구조 검증은 Stop 훅으로 옮겨왔다 — "
            "이 토큰들은 더 이상 구조 검증을 끄지 않는다. 끄려면 "
            "DEVBREW_SKIP_HOOKS=spec-distill:Stop 을 쓴다."
        )
    if autoreview_set:
        parts.append(
            f"{RETIRED_AUTOREVIEW_VAR}=1 이 설정돼 있으나 v0.36.0 에서 이 변수를 "
            "읽던 훅이 삭제돼 더 이상 아무것도 끄지 않는다. 이 변수가 주던 것 — "
            "구조 검증은 유지한 채 자동 리뷰 dispatch 만 중단 — 은 이 버전에 "
            "대체 수단이 없다."
        )
    return (
        body.rstrip() + f"\n{RETIRED_MARKER}\n",
        "[spec-distill] " + " ".join(parts),
    )


#: 발견 커서. 0-indent 스칼라라 `arm_ledger._compose` 의 블록 재조립을 통과해도
#: 살아남는다(그 함수는 자기가 아는 네 블록만 벗겨 내고 나머지는 `rest` 로 보존한다).
DISCOVERY_CURSOR_RE = re.compile(r"^discovery_cursor:\s*(.+)$", re.MULTILINE)


def read_cursor(body: str) -> str | None:
    m = DISCOVERY_CURSOR_RE.search(body)
    return m.group(1).strip() if m else None


def set_cursor(body: str, cursor: str | None) -> str:
    """커서를 멱등 기록 (순수 함수). `None` 은 "바꾸지 않는다"이지 "지운다"가 아니다.

    치환에 lambda 를 쓰는 이유: 커서 값은 **경로**라 백슬래시가 들어올 수 있고,
    `re.sub` 의 replacement 문자열은 `\\g` 류를 escape 로 해석한다.
    """
    if cursor is None:
        return body
    line = f"discovery_cursor: {cursor}"
    if DISCOVERY_CURSOR_RE.search(body):
        return DISCOVERY_CURSOR_RE.sub(lambda _m: line, body)
    # 빈 줄로 띄운다 — `arm_ledger._compose` 가 블록을 재조립할 때 쓰는 구분과 같아서,
    # 다음 원장 write 를 거쳐도 파일 모양이 흔들리지 않는다.
    return body.rstrip() + f"\n\n{line}\n"


def seed_body(body: str, state_path: Path) -> str:
    """빈 원장에 최소 frontmatter 를 깐다 — `arm_ledger.mark_reviewed` 와 같은 모양."""
    if body.strip():
        return body
    return f"---\nsession_id: {state_path.parent.name}\n---\n\n"


def write_state_file(path: Path, body: str) -> None:
    """AC7.1 — explicit flush + fsync for OS-level durability before any emit."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())


def validate_document(path: str) -> list[str]:
    """구조 실패 사유 목록. 빈 목록 = 통과. 파서를 subprocess 로 부르지 않는다 (A4)."""
    mode = resolve_mode(path)
    if mode is None:
        return []
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return [f"문서를 읽지 못했다: {exc}"]
    reasons: list[str] = []
    if mode == "spec":
        fm = parse_frontmatter(text)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        errs = validate_locked_decisions(text)
        if errs:
            reasons.append("locked_decisions errors: " + "; ".join(errs))
        missing = find_missing_sections(text)
        if missing:
            reasons.append(f"missing sections: {missing}")
    for hit in scan_ambiguity(text, load_blacklist(BLACKLIST)):
        reasons.append(f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\"")
    if mode == "design":
        for hit in scan_placeholders(text):
            reasons.append(f"placeholder hit: {hit['token']} at line {hit['line']}")
    return reasons


def select_keys(keys: list[str], cursor: str | None, cap: int) -> tuple[list[str], str | None]:
    """정렬된 후보에서 커서 뒤부터 최대 `cap` 개를 고르고 다음 커서를 낸다.

    커서가 없으면 처음부터. 커서가 목록에 없으면(문서가 커밋돼 후보에서 빠졌다)
    그보다 큰 첫 키부터 — 목록이 바뀌어도 회전이 끊기지 않는다. 끝에 닿으면 감는다.
    이것이 A13 의 진행 보장이다: 정렬이 안정적이라는 사실 자체가 기아의 원인이므로,
    안정 정렬 위에 회전을 얹는다.
    """
    ordered = sorted(keys)
    if not ordered:
        return [], None
    start = 0
    if cursor is not None:
        start = next((i for i, k in enumerate(ordered) if k > cursor), 0)
    picked = [ordered[(start + i) % len(ordered)] for i in range(min(cap, len(ordered)))]
    return picked, picked[-1]


def select_dispatch_target(
    cands: list[Candidate], body: str, now: datetime,
) -> Candidate | None:
    """이 턴에 리뷰를 강제할 문서 하나. 없으면 `None`.

    dispatch 연료가 상태 파일의 블록이던 시절에는 반복 억제가 그 블록의 **소진**에서
    나왔다. 발견은 무상태라 소진할 것이 없으므로, 억제는 전부 원장의 표시가 맡는다:

    | 제외 사유 | 근거 |
    |---|---|
    | `born` | git 이 이미 아는 문서 — 저자가 리포에 넣기로 결정했다 (`is_born`) |
    | `armed_paths` | "더 이상 dispatch 안 함" (verdict 완료 · G6 상한 도달) |
    | `dispatch_attempts` ≥ `DISPATCH_ATTEMPT_CAP` | G6 상한 |
    | `validation_attempts` ≥ `VALIDATION_ATTEMPT_CAP` | A14 의 dispatch 절반 |
    | in-flight | A12 — 리뷰가 도는 중 |
    | `resolve_mode` 가 `None` | 리뷰어는 mode 로 라우팅한다 |

    두 상한은 값이 같아도 **별도 상수**를 읽는다 — 그 분리가 설계 §4.4 의 계약이고,
    합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다.

    마지막 줄(`resolve_mode`)이 kill switch 를 지킨다.
    `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 은 design 문서를 `None` 으로
    떨어뜨린다. 그 판정이 dispatch 앞단의 다른 훅에 있던 시절에는 여기서 다시 볼
    이유가 없었지만, 연료가 발견으로 바뀐 지금은 이 훅이 스스로 지켜야 한다 —
    안 지키면 kill switch 가 말없이 죽는다(CLAUDE.md: kill switch 는 보안 컨트롤).

    제외된 후보에서 멈추지 않고 **목록 끝까지 훑는다**. 멈추면 armed 문서 하나가
    그 세션의 모든 dispatch 를 조용히 막는다 — 발견 목록은 정렬돼 있어 그 문서가
    매 턴 같은 자리에 오기 때문이다.

    같은 이유로 armed 검사는 **이 안의 per-candidate skip 이어야 하고**, 선택 밖에서
    그 턴 전체를 끊는 `return 0` 이면 안 된다. 두 모양은 armed 문서가 하나뿐일 때
    같은 답을 내지만, 옆에 미리뷰 문서가 있으면 갈린다 — 후자는 그 문서까지 함께
    굶긴다(측정 확인: 그 변이에서 test_arm_once.sh T13 이 `emit=''` 로 RED).
    """
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
    except ImportError as exc:
        # 방향이 검증 쪽과 같다: 상한을 셀 수 없는 상태에서 dispatch 하면 in-flight
        # 표시도 못 남기므로 다음 Stop 이 같은 문서를 다시 찾아 상한 없는 block 루프가
        # 된다(CLAUDE.md: Unbounded autonomy). **import 프로브의 실패 모드만** 잡는다 —
        # 넓히면 원장 파싱의 진짜 버그가 "조회 실패" 로 둔갑해 게이트가 조용히 꺼진다.
        print(
            f"[spec-distill] 원장 조회 실패 (non-fatal, 이번 턴 dispatch 생략): {exc}",
            file=sys.stderr,
        )
        return None
    armed = set(arm_ledger.armed_keys(body))
    att = arm_ledger.attempts(body)
    val = arm_ledger.validation_attempts(body)
    for c in cands:
        if c.born:
            continue
        if c.key in armed:
            continue
        if att.get(c.key, 0) >= arm_ledger.DISPATCH_ATTEMPT_CAP:
            continue
        if val.get(c.key, 0) >= arm_ledger.VALIDATION_ATTEMPT_CAP:
            continue
        if arm_ledger.is_inflight(body, c.path, now):
            continue
        if resolve_mode(c.path) is None:
            continue
        return c
    return None


def emit_git_unavailable(state_path: Path, body: str) -> int:
    """A16 — git 불능은 후보 0 과 다르다. 세션당 1회만 알린다 (설계 §4.5)."""
    if GIT_UNAVAILABLE_MARKER in body:
        return 0
    try:
        write_state_file(
            state_path,
            seed_body(body, state_path).rstrip() + f"\n{GIT_UNAVAILABLE_MARKER}\n",
        )
    except OSError as exc:
        # 마커를 못 남기면 다음 턴에 같은 advisory 가 다시 나간다. 그 반복은
        # 조용해지는 것보다 낫다 — A16 이 요구하는 것은 사용자가 **알게** 되는 것이다.
        print(
            f"[spec-distill] git-불능 마커 기록 실패 "
            f"(advisory 가 다음 턴에도 반복된다): {exc}",
            file=sys.stderr,
        )
    print(json.dumps({"systemMessage": GIT_UNAVAILABLE_ADVISORY}), flush=True)
    return 0


class LedgerWriteError(Exception):
    """원장 블록(`dispatch_attempts`·`inflight_paths`)을 body 에 못 찍었다.

    `OSError` 와 **같은 처분**을 받는다: 이번 턴의 dispatch 를 접고 emit 하지 않는다.
    그 둘이 잃는 것이 같기 때문이다 — 상태 파일에 남는 억제자다. 연료가
    `pending_review` 이던 시절에는 그 소비가 무조건 일어나 원장 실패의 대가가
    "dispatch 한 번 더"였지만, 발견이 무상태가 된 지금은 소비할 것이 없다.
    `dispatch_attempts`(G6 상한)와 `inflight_paths`(발견 제외)가 **둘 다** 이
    실패 뒤에 있으므로, 그대로 block 을 내면 남는 상한은 30초 TTL 하나뿐이고
    사람의 턴 간격이 그것을 매번 넘긴다 — 상한 없는 block 루프다
    (CLAUDE.md: Unbounded autonomy).

    emit 을 접는 것이 안전한 근거는 이 브랜치 자신의 논거다: 발견은 무상태라
    다음 Stop 이 같은 문서를 다시 찾는다. `select_dispatch_target` 의 원장 조회
    실패가 이미 같은 논거로 같은 선택(그 턴 dispatch 생략)을 한다.
    """


def with_advisory(payload: dict, advisory: str | None) -> dict:
    """advisory 를 payload 의 `systemMessage` 에 합친다 (순수 함수).

    **stdout 에 JSON 은 하나뿐이다.** advisory 를 별도 `print(json.dumps(...))` 로
    내면 그 턴에 block 이 함께 나가는 경우 stdout 에 JSON 두 개가 이어 붙어
    파싱이 깨지고, 그러면 block 자체가 조용히 사라진다 — 게이트가 꺼지는 방향이다.
    그래서 합치기는 emit 지점에서 한다.
    """
    if advisory is None:
        return payload
    existing = payload.get("systemMessage")
    payload["systemMessage"] = f"{existing}\n{advisory}" if existing else advisory
    return payload


def flush_advisory(advisory: str | None) -> int:
    """아무것도 emit 하지 않는 턴에서 advisory 만 낸다. 반환값은 훅의 rc.

    `decision` 키가 없으므로 non-blocking 이다 — AC7.3.1 의 AST 락이 재는
    "decision emit" 도 아니다.
    """
    if advisory is not None:
        print(json.dumps({"systemMessage": advisory}), flush=True)
    return 0


def rewrite_state(
    path: Path, body: str, now: datetime, spec_path: str, attempt_n: int,
    cursor: str | None, inflight_key: str | None,
) -> None:
    # frontmatter 는 **원장 함수를 태우기 전에** 깐다 — 구조 검증 경로가 같은 이유로
    # 같은 일을 한다. `record_attempt` 는 빈 body 를 받으면 블록 하나만 있는 body 를
    # 내놓는데, 그건 이미 비어 있지 않아 나중에 seed 해도 늦다. 그러면 이 파일에서만
    # `session_id:` 가 사라진다 — 다른 writer(구조 검증 · git-불능 · 은퇴 토큰 ·
    # `arm_ledger.mark_reviewed`)는 전부 남긴다.
    body = seed_body(body, path)
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    # §5.2 — dispatch_attempts 증가는 타임스탬프와 **한 write**로 커밋된다.
    # armed_paths는 G6 상한에 닿는 그 순간에만 record_attempt가 함께 찍고, 정상
    # dispatch에서는 원장을 건드리지 않는다(완료 기록 = verdict 시점 mark-reviewed).
    if attempt_n > 0:
        try:
            import arm_ledger  # pyright: ignore[reportMissingImports]
            body = arm_ledger.record_attempt(body, spec_path, attempt_n)
        except Exception as exc:  # noqa: BLE001 — 처분은 호출자가 (LedgerWriteError)
            raise LedgerWriteError(
                f"dispatch_attempts 기록 실패 — G6 상한을 셀 수 없다: {exc}"
            ) from exc
    # A12 — in-flight 표시도 **같은 write** 안에서 찍는다. 별도 write 로 가르면 그
    # 사이에 두 번째 Stop 이 같은 문서를 다시 발견한다. "리뷰 진행 중"을 상태로
    # 표현하는 유일한 자리가 이 표시다(설계 §4.1).
    if inflight_key is not None:
        try:
            import arm_ledger  # pyright: ignore[reportMissingImports]
            body = arm_ledger.mark_inflight(body, inflight_key, new_ts)
        except Exception as exc:  # noqa: BLE001 — 처분은 호출자가 (LedgerWriteError)
            raise LedgerWriteError(
                f"in-flight 표시 실패 — 발견 제외를 남길 수 없다: {exc}"
            ) from exc
    body = set_cursor(body, cursor)
    write_state_file(path, body)


def main() -> int:
    if kill_switch_active("spec-distill", "review-dispatch", "Stop"):
        return 0
    fire_and_forget_gc()
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        # UnicodeDecodeError 는 ValueError 하위 — JSONDecodeError 의 형제이지 OSError 가 아니다.
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] stdin read error: {exc}", file=sys.stderr)
        payload = {}
    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0
    state_path = state_file_for(session_id)
    # 상태 파일 **부재는 빈 원장**이다. 연료가 상태 파일의 블록이던 시절에는 파일이
    # 없으면 볼 것이 정말 없어 여기서 return 0 했다. 발견은 상태가 아니라 git 에서
    # 오므로 이제 파일 없이도 돌아야 한다.
    body = ""
    if state_path.exists():
        try:
            body = state_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as e:
            # UnicodeDecodeError 는 ValueError 하위라 OSError 로는 잡히지 않는다 — 좁게
            # 잡으면 판독 불가 원장이 훅을 traceback 으로 죽여 dispatch 자체가 사라진다
            # (리뷰를 *덜* 하는 방향, Law 1 이 금지하는 쪽). arm_ledger._read_body 는
            # 이미 두 예외를 함께 잡는다 — 형제 소비자 정렬.
            #
            # rc 0 + 조용함은 답이 아니다. 크래시(rc≠0)는 최소한 사용자에게 보였는데,
            # exit 0 의 stderr 는 전달되지 않는다 — 판독 불가 파일은 스스로 낫지 않으므로
            # 이 세션의 리뷰 게이트가 **조용히 영구히** 꺼진다. 그렇다고 `decision:"block"`
            # 을 낼 수도 없다: block storm 가드(AC7.2)가 기대는 `last_dispatched_at` 이
            # 바로 그 못 읽는 파일 안에 있어 매 Stop 마다 무한히 block 을 내게 된다.
            # 그래서 **loud 하되 루프하지 않는** 형태 — systemMessage 만 낸다.
            print(f"[spec-distill] state read failed (non-fatal): {e}", file=sys.stderr)
            print(json.dumps({
                "systemMessage": (
                    f"[spec-distill] arm-once:state-unreadable — state.local.md 판독 불가로 "
                    f"자동 리뷰 dispatch 가 중단됐다 "
                    f"({state_path}). 파일을 복구하거나 reviewing-spec 을 직접 호출하라."
                ),
            }), flush=True)
            return 0
    now = datetime.now(timezone.utc)
    # --- 발견 (A16) — git 은 상계, 판정은 canonical_key ---
    # **`GitUnavailable` 만 잡는다.** 넓히면 발견 모듈의 어떤 결함이든 "git 불능"으로
    # 둔갑해 게이트가 조용히 꺼진다 — 이 릴리스가 없애려는 "리뷰가 덜 되는 방향"
    # 그 자체이고, 게다가 사용자가 보는 문구가 사실과 다르다. 발견 모듈의 버그는
    # 크래시로 보이는 편이 낫다(exit 0 의 stderr 는 전달되지 않는다).
    try:
        cands = discover()
    except GitUnavailable as exc:
        print(f"[spec-distill] 스코프 문서 발견 불가 (git): {exc}", file=sys.stderr)
        return emit_git_unavailable(state_path, body)
    # --- 검증 후보에서 빼는 것: in-flight · 검증 상한 (A12·A14) ---
    #
    # **`armed_paths` 는 여기 없다.** 그 원장의 의미는 "더 이상 **dispatch** 안 함"이고,
    # 구조 검증은 그것과 다른 게이트(Layer 1)다. 둘을 합치면 이번 세션에 리뷰를 마친
    # 문서를 Bash 로 깨뜨렸을 때 구조 검증이 다시 발화하지 않는다 — 쓰기 경로가 게이트를
    # 우회한다는 이 브랜치의 동기가 된 결함이 축소판으로 되살아나고, 방향은 Law 1 이
    # 금지하는 "리뷰가 덜 되는 쪽"이다. 설계 §9 의 A14 는 **검증 실패 상한**만을 검증
    # 제외 사유로 든다 — `armed_paths` 는 한 글자도 나오지 않는다.
    #
    # block storm 은 이 제외 없이도 묶인다: `record_validation` 이 문서별로 세고
    # `VALIDATION_ATTEMPT_CAP` 이 3 에서 끊는다.
    #
    # dispatch 쪽의 armed 게이트는 그대로다 — 아래 `select_dispatch_target` 이 그
    # 자리다. 두 게이트가 이제 서로 다른 술어를 읽는다.
    cursor = read_cursor(body)
    by_key: dict[str, Candidate] = {}
    validation_pool: list[str] = []
    capped: list[str] = []
    val_cap = 0
    ledger = None
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
        ledger = arm_ledger
        val_cap = arm_ledger.VALIDATION_ATTEMPT_CAP
        val_att = arm_ledger.validation_attempts(body)
        for c in cands:
            if arm_ledger.is_inflight(body, c.path, now):
                continue
            if val_att.get(c.key, 0) >= val_cap:
                capped.append(c.key)
                continue
            by_key[c.key] = c
            validation_pool.append(c.key)
    except ImportError as exc:
        # **import 프로브의 실패 모드만** 잡는다. `Exception` 으로 넓히면
        # `validation_attempts`·`is_inflight` 안의 진짜 버그가 "원장 조회 실패" 로
        # 둔갑해 Layer 1 이 그 턴 내내 꺼진다 — 위 발견 except 에 대해 이 파일이
        # 이미 적어 둔 논거("게이트가 조용히 꺼진다")가 여기에도 그대로 적용되고,
        # exit 0 의 stderr 는 전달되지 않으므로 사용자는 알 방법이 없다. 원장 파싱
        # 버그는 크래시로 드러나는 편이 낫다.
        #
        # 이 분기 자체는 거의 도달하지 않는다: `discover_candidates` 가 모듈 최상단에서
        # `arm_ledger` 를 import 하므로, 정말 없다면 훅은 여기 오기 전에 죽는다.
        # 그래도 남긴다 — 상한을 못 세는 상태에서 검증하면 상한 없는 block 루프가
        # 되므로(CLAUDE.md: Unbounded autonomy) 이번 턴의 검증만 접는 것이 옳다.
        ledger = None
        validation_pool = []
        print(
            f"[spec-distill] 원장 조회 실패 (non-fatal, 이번 턴 구조 검증 생략): {exc}",
            file=sys.stderr,
        )
    capped_advisory: str | None = None
    if capped:
        # A14 의 양쪽이 이제 다 집행된다. 검증 절반은 바로 위 루프의 `capped` 이고,
        # dispatch 절반은 `select_dispatch_target` 의 같은 상한 검사다 — 그래서 이
        # 문구가 둘을 함께 주장할 수 있다. 한쪽만 있을 때 이 문장을 내면 없는 집행을
        # 주장하는 것이고, 그것은 그 자체로 결함이다.
        #
        # **채널은 stderr 가 아니다.** 이 파일이 네 곳에서 적어 둔 사실 —
        # exit 0 의 stderr 는 전달되지 않는다 — 이 여기에도 그대로 적용된다. 그리고
        # 이것은 그 문서가 **이 세션의 Law 1 게이트를 영구히 벗어난다**는 통지라,
        # 조용하면 설계 §4.4 가 명시적으로 요구하는 것("조용히가 아니라 advisory 와
        # 함께")이 성립하지 않는다. 같은 턴에 block 이 함께 나갈 수 있으므로 별도
        # emit 이 아니라 `with_advisory` 로 합쳐 내보낸다 (stdout 의 JSON 은 하나).
        #
        # 같은 상한의 **동턴 절반**(`reached_cap`)은 아래 block 의 `reason` 을 타고
        # 이미 전달된다 — 그쪽은 건드리지 않는다.
        capped_advisory = (
            f"[spec-distill] 구조 검증 상한({val_cap}회)에 닿아 이번 세션에서 "
            f"자동 검증·dispatch 를 하지 않는 문서: {', '.join(capped)}"
        )
        print(capped_advisory, file=sys.stderr)
    picked, next_cursor = select_keys(validation_pool, cursor, CANDIDATE_CAP)
    if picked:
        cursor = next_cursor
    # --- 구조 검증 (A10 — TTL 가드보다 먼저) ---
    failures: list[str] = []
    reached_cap: list[str] = []
    # frontmatter 는 **원장 함수를 태우기 전에** 깐다. `record_validation` 은 빈 body 를
    # 받으면 블록 하나만 있는 body 를 내놓는데, 그건 이미 비어 있지 않아 나중에
    # seed 해도 늦다 — 다른 writer 가 전부 남기는 `session_id:` 만 이 파일에서 사라진다.
    body_after = seed_body(body, state_path)
    if ledger is not None:
        for key in picked:
            reasons = validate_document(by_key[key].path)
            if not reasons:
                continue
            failures.append(f"- {key}: " + "; ".join(reasons))
            n = ledger.next_validation(body_after, key)
            body_after = ledger.record_validation(body_after, key, n)
            if n >= val_cap:
                reached_cap.append(key)
    if failures:
        # A11 — 한 턴에 block 은 하나. 구조 실패 사유만 내고 dispatch 는 그 턴에 없다.
        # 구조가 깨진 문서를 리뷰어에게 보내면 그 라운드는 rereview_count 만 태운다.
        lines = [
            "MANDATORY: 다음 turn 첫 액션으로 아래 구조 실패를 고친다. "
            "고치기 전에는 자동 리뷰 dispatch 가 일어나지 않는다.",
        ]
        lines.extend(failures)
        if reached_cap:
            lines.append(
                f"[spec-distill] 다음 문서는 구조 검증이 {val_cap}회 실패해 이 세션에서 "
                f"자동 검증·dispatch 를 중단한다: {', '.join(reached_cap)}. "
                "리뷰가 필요하면 reviewing-spec 을 직접 호출하라."
            )
        body_after = set_cursor(body_after, cursor)
        try:
            write_state_file(state_path, body_after)
        except OSError as e:
            # A15 — loud 하되 루프하지 않는다. 카운터를 못 올린 채 block 을 내면
            # 상한이 영원히 오지 않는다.
            print(
                f"[spec-distill] 구조 검증 기록 실패 (non-fatal, block 생략): {e}",
                file=sys.stderr,
            )
            return flush_advisory(capped_advisory)
        print(json.dumps(with_advisory({
            "decision": "block",
            "reason": "\n".join(lines),
            "systemMessage": "[spec-distill] 스코프 문서 구조 검증 실패 — 이번 turn 은 리뷰 dispatch 없음",
        }, capped_advisory)), flush=True)
        return 0
    if picked and cursor != read_cursor(body):
        # 커서는 **통과했을 때도** 전진해야 한다. 상한을 넘는 dirty 문서가 전부
        # 통과하면 rewrite 가 한 번도 안 일어나고, 그러면 매 턴 같은 앞쪽 N개만
        # 다시 검증돼 뒤쪽이 굶는다 — 상한이 만드는 기아 그 자체(A13).
        try:
            write_state_file(
                state_path, set_cursor(seed_body(body, state_path), cursor))
        except OSError as e:
            print(
                f"[spec-distill] 발견 커서 기록 실패 "
                f"(non-fatal, 다음 턴이 같은 구간을 다시 본다): {e}",
                file=sys.stderr,
            )
    # --- A19 — 은퇴한 kill switch 공시 ---
    # 구조 검증이 이 훅으로 **옮겨왔으므로**, `spec-distill:validator` 로 그 검증을
    # 껐던 사용자는 그것이 말없이 되살아난 것을 보게 된다. project-init 의 은퇴와
    # 다른 점이 이것이다 — 거기서는 사라진 훅이 아무것도 대신하지 않았다.
    #
    # **자리가 구조 검증 뒤인 것이 요점이다.** git-불능 advisory 처럼 훅 앞머리에서
    # 내면 그 턴의 Layer 1 이 통째로 건너뛰어진다 — 세션당 1회뿐이라도 방향이
    # 이 브랜치가 없애려는 그것(게이트가 조용해지는 쪽)이라 안 된다. 여기서는
    # 검증이 이미 끝났고 통과했으므로 **미루는 것은 dispatch 한 턴뿐**이다.
    # 구조 실패가 있던 턴에는 위에서 이미 return 했으니 advisory 는 다음 턴을 기다린다.
    #
    # 쓰는 body 는 바로 위 커서 write 와 **같은 식**이다 — 다른 식으로 쓰면 방금
    # 전진시킨 `discovery_cursor` 를 이 write 가 되돌린다.
    #
    # stderr 로 내지 않는 이유는 이 파일이 여러 번 적어 둔 사실 — exit 0 의 stderr 는
    # 사용자에게 전달되지 않는다.
    body_adv, advisory = retired_switch_advisory(
        set_cursor(seed_body(body, state_path), cursor))
    if advisory is not None:
        try:
            write_state_file(state_path, body_adv)
        except OSError as exc:
            # 마커를 못 남기면 다음 턴에 같은 advisory 가 다시 나간다. 그 반복은
            # 조용해지는 것보다 낫다 — 사용자가 **알게** 되는 것이 목적이다.
            print(
                f"[spec-distill] 은퇴 스위치 마커 기록 실패 "
                f"(advisory 가 다음 턴에도 반복된다): {exc}",
                file=sys.stderr,
            )
        print(json.dumps(with_advisory(
            {"systemMessage": advisory}, capped_advisory)), flush=True)
        return 0
    # --- dispatch 대상 선택 (A12·A14·G6) ---
    # 이미 손에 든 후보 목록에서 고른다 — 발견은 위에서 한 번 했고, 여기서 git 을
    # 다시 부르면 같은 턴 안에서 두 집합을 보게 된다.
    cand = select_dispatch_target(cands, body, now)
    if cand is None:
        # 이 턴에 dispatch 할 문서가 없다 — 그래도 상한 advisory 는 나가야 한다.
        # 상한에 닿은 문서가 유일한 후보인 경우가 정확히 이 경로이기 때문이다.
        return flush_advisory(capped_advisory)
    # TTL guard against self-ref cycle
    try:
        ttl_sec = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl_sec = 30
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl_sec):
            return flush_advisory(capped_advisory)  # within guard window
    spec_path = cand.path
    # `select_dispatch_target` 이 이미 부른 함수를 다시 부른다.
    # **`resolve_mode` 는 순수 함수가 아니다** — 접두 아래의 `.md` 중 `-spec`/`-design`
    # 접미사가 없는 것은 frontmatter 를 읽어 판정한다. 그러므로 "같은 답이 보장된다"는
    # 근거는 틀렸다. 실제 근거는 좁다: `None` 을 내는 분기 넷 중 셋(접두 없음 · `.md`
    # 아님 · `-design.md` + design-mode kill switch)은 경로와 env 에서만 나와 이 프로세스
    # 안에서 불변이고, 읽기 실패는 `design` 으로 떨어지지 `None` 이 되지 않는다.
    # 남는 창은 하나뿐이다: 접미사 없는 `.md` 의 frontmatter 가 두 호출 **사이에** 바뀌고
    # **동시에** design 모드가 꺼져 있을 때. 그 창은 좁히지 않고 열어 둔다(범위 밖).
    # 비용도 적어 둔다 — 접미사 없는 문서는 dispatch 한 번에 파일을 두 번 읽는다.
    mode = resolve_mode(spec_path)
    # §5.2 — 이번 dispatch의 시도 번호는 rewrite *이전에* 순수 함수로 계산한다.
    # rewrite_state를 bare 표현식 호출로 유지해야 AC7.3.1 AST 락(rewrite 먼저,
    # print 나중)이 그대로 성립한다 — 반환값 대입으로 바꾸면 그 락이 호출을 못 본다.
    attempt_n = 0
    cap = 0
    inflight_key = None
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
        attempt_n = arm_ledger.next_attempt(body, spec_path)
        cap = arm_ledger.DISPATCH_ATTEMPT_CAP
        inflight_key = arm_ledger.canonical_key(spec_path)
    except Exception as exc:  # noqa: BLE001 — loud degradation
        print(
            f"[spec-distill] dispatch 시도 카운트 실패 "
            f"(non-fatal, G6 상한 미적용): {exc}",
            file=sys.stderr,
        )
    # 별도의 체크아웃 경로 줄은 없다. 리뷰어에게 "이 문서가 어느 체크아웃에
    # 있는지"를 알리는 일은 발견이 내는 절대경로 `spec path` 가 스스로 한다.
    # 이 훅의 cwd 로 값을 만들어 넣지 않는다 — 리포 서브디렉터리일 수 있어 worktree
    # 경로라고 부를 수 없고, 없는 것보다 틀린 것이 나쁘다.
    msg_lines = [
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    msg_lines.append(
        "호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류."
    )
    # 범위(scope)는 알리되 면제(permission)는 알리지 않는다. 이 mandate 가 언제까지
    # 유효한지 적지 않았더니, "이번 리뷰만 멈춰달라"는 요청에 세션 전체를 끄는
    # 환경변수(DEVBREW_SPEC_DISTILL_DISABLE 등)가 답으로 나왔다 — 수명을 모르면
    # 영구로 가정하고 최대 화력을 고르기 때문이다. 그래서 **수명 사실만** 적는다:
    # "건너뛰어도 된다" 나 "무시하면 재발동하지 않는다" 같은 집행 공백은 적지 않는다.
    # 그것은 모델이 스스로 리뷰를 면제할 근거가 되어 Law 2 를 뚫는다. 반대로 수명
    # 사실은 "지금 안 하면 사라진다" 는 즉시 이행 압력이라 mandate 를 강화한다.
    #
    # 두 문장은 상호배타다. 상한에 닿은 dispatch 에서는 "재편집하면 재발동" 이
    # **거짓**이 된다 — 그 문서는 이 세션에서 이미 중단됐다. 함께 내면 훅이 같은
    # 숨결로 서로 모순되는 두 수명을 주장한다.
    if cap and attempt_n >= cap:
        msg_lines.append(
            f"[spec-distill] '{spec_path}' 리뷰가 {cap}회 시도됐으나 verdict 없이 "
            "끝났다 — 자동 dispatch를 중단한다. 리뷰가 필요하면 reviewing-spec을 "
            "직접 호출하라."
        )
    else:
        # **재발동 조건은 적지 않는다.** 두 번 시도했고 두 번 다 거짓이었다:
        #   (1) "커밋하면 arm되지 않는다" — is_born() 이 git 판정 실패를 arm 쪽으로
        #       fail-open 하므로 커밋된 문서도 arm 될 수 있다.
        #   (2) "재편집하면 재발동한다"  — verdict 후 mark_reviewed 가 armed_paths 에
        #       기록하므로 **정상 경로**에서는 재편집해도 재발동하지 않는다.
        # 재발동은 (원장 ∧ git ∧ 상한) 세 입력의 함수이고 셋 다 emit 시점에 확정되지
        # 않는다. 훅이 모르는 것을 단정하면 그 문장은 언젠가 거짓이 된다.
        # 남기는 것은 emit 시점에 **이미 일어난 사실** 하나뿐이다 — 아래
        # rewrite_state 가 emit 보다 **먼저** 이 문서를 in-flight 로 찍으므로,
        # 다음 Stop 의 발견 결과에서 이 문서가 빠진다. 그래서 이 강제는 이번 턴을
        # 넘기지 않는다.
        msg_lines.append("이 mandate는 이번 dispatch 1회에만 유효하다.")
    msg = " ".join(msg_lines)
    # AC7.1: rewrite BEFORE emit. AC7.2: rewrite-fail → no emit (block storm guard).
    try:
        rewrite_state(state_path, body, now, spec_path, attempt_n, cursor, inflight_key)
    except (OSError, LedgerWriteError) as e:
        # 두 실패가 같은 처분을 받는 이유는 `LedgerWriteError` 의 docstring 에 있다:
        # 잃는 것이 같다 — 이 dispatch 를 다시 억제할 수단이다. block 을 그대로 내면
        # 남는 상한이 30초 TTL 하나뿐이라 사람 턴 간격마다 다시 block 이 나간다.
        print(
            f"[spec-distill] state rewrite failed (non-fatal, dispatch suppressed): {e}",
            file=sys.stderr,
        )
        # empty stdout, no decision:block — 발견은 무상태라 다음 Stop 이 다시 찾는다
        return flush_advisory(capped_advisory)
    print(json.dumps(with_advisory({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }, capped_advisory)), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
