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
3. **dispatch** — `pending_review:` 블록이 있으면 `reviewing-spec` 을 다음 턴 첫
   액션으로 강제한다. dispatch 시점에 그 문서를 in-flight 로 표시해(A12) 리뷰가
   도는 동안 발견 결과에서 빠지게 한다.

턴당 검증 상한(`CANDIDATE_CAP`)에는 커서 회전을 얹는다(A13). 정렬이 안정적이라는
사실 자체가 기아의 원인이므로, 안정 정렬 위에 회전이 없으면 상한을 넘는 dirty
문서의 뒤쪽이 영구히 검증되지 않는다.

Ordering guarantee (AC7.1): `rewrite_state()` must complete (with fsync) BEFORE
the JSON is printed. Reverse ordering races with a second Stop fire and
produces a block storm. On rewrite OSError, the hook exits `{}` 0 (no block)
to preserve the race-free TTL guard (AC7.2·A15) — 발견은 무상태이므로 다음 Stop 이
같은 문서를 다시 찾는다.

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
# 형제 훅(pending-review-reminder.py)과 공유하는 조각 — 같은 플러그인 안이라
# import 하나로 중복이 소멸한다(설계 §6.1③). 사본이 아니다.
from hook_common import (  # noqa: E402
    LAST_DISPATCHED_RE,
    PENDING_RE,
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


def rewrite_state(
    path: Path, body: str, now: datetime, spec_path: str, attempt_n: int,
    cursor: str | None, inflight_key: str | None,
) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    # §5.2 — dispatch_attempts 증가는 pending strip·타임스탬프와 **한 write**로
    # 커밋된다. armed_paths는 G6 상한에 닿는 그 순간에만 record_attempt가 함께 찍고,
    # 정상 dispatch에서는 원장을 건드리지 않는다(완료 기록 = verdict 시점 mark-reviewed).
    if attempt_n > 0:
        try:
            import arm_ledger  # pyright: ignore[reportMissingImports]
            body = arm_ledger.record_attempt(body, spec_path, attempt_n)
        except Exception as exc:  # noqa: BLE001 — loud degradation
            print(
                f"[spec-distill] dispatch_attempts 기록 실패 "
                f"(non-fatal, 이번 dispatch에 G6 상한 미적용): {exc}",
                file=sys.stderr,
            )
    # A12 — in-flight 표시도 **같은 write** 안에서 찍는다. 별도 write 로 가르면 그
    # 사이에 두 번째 Stop 이 같은 문서를 다시 발견한다(설계 §4.1 이 pending 은퇴로
    # 잃는 "리뷰 진행 중" 상태의 대체재가 바로 이 표시다).
    if inflight_key is not None:
        try:
            import arm_ledger  # pyright: ignore[reportMissingImports]
            body = arm_ledger.mark_inflight(body, inflight_key, new_ts)
        except Exception as exc:  # noqa: BLE001 — loud degradation
            print(
                f"[spec-distill] in-flight 표시 실패 "
                f"(non-fatal, 리뷰 중인 문서가 다시 발견될 수 있다): {exc}",
                file=sys.stderr,
            )
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
    # 상태 파일 **부재는 빈 원장**이다. 예전에는 여기서 return 0 했는데, 그때는
    # `pending_review:` 가 유일한 연료라 파일이 없으면 볼 것이 정말 없었다. 발견은
    # 상태가 아니라 git 에서 오므로 이제 파일 없이도 돌아야 한다.
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
    # dispatch 쪽의 armed 게이트는 그대로다 — 아래 pending 경로의 `_vetoed` 판정이
    # 그 자리다. 두 게이트가 이제 서로 다른 술어를 읽는다.
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
    if capped:
        # A14 의 **검증 절반**만 여기서 집행된다. 나머지 절반(상한 도달 문서를 dispatch
        # 대상에서도 빼기)은 dispatch 대상 선택 술어 자체이므로 그 선택을 만드는 Task
        # 12b 의 몫이다. 그러니 이 문구도 검증만 주장한다 — 없는 집행을 주장하는 메시지는
        # 그것만으로 결함이고, 다른 Task 를 기다린다고 참이 되지 않는다.
        print(
            f"[spec-distill] 구조 검증 상한({val_cap}회)에 닿아 이번 세션에서 "
            f"자동 구조 검증을 하지 않는 문서: {', '.join(capped)}",
            file=sys.stderr,
        )
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
                f"자동 구조 검증을 중단한다: {', '.join(reached_cap)}. "
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
            return 0
        print(json.dumps({
            "decision": "block",
            "reason": "\n".join(lines),
            "systemMessage": "[spec-distill] 스코프 문서 구조 검증 실패 — 이번 turn 은 리뷰 dispatch 없음",
        }), flush=True)
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
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # TTL guard against self-ref cycle
    try:
        ttl_sec = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl_sec = 30
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl_sec):
            return 0  # within guard window
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    # G1 — 원장이 "더 이상 dispatch 안 함"이라고 말하는 문서는 stale pending 이 남아
    # 있어도 발동하지 않는다. pending 을 유일한 연료로 두면, skill 이 Step 1
    # (strip-pending)과 Step 3(mark-reviewed)을 분리된 두 bash 블록으로 실행한다는
    # 사실만으로 재발동이 되살아난다 — Step 1 이 빠지면 pending 이 남고, 실제 리뷰는
    # 30초 TTL 을 넘기므로 다음 Stop 이 이미 리뷰된 문서에 다시 block 을 낸다.
    # 여기서 pending 을 치우는 것은 §5.4 의 진입 strip 과 같은 연산이며 armed_paths 는
    # 건드리지 않는다 — T10(상한 미달 dispatch 단독으로는 Stop 이 원장에 쓰지 않는다)은
    # 그대로 성립한다.
    # 조회 실패는 dispatch 쪽으로 fail-open: 리뷰를 덜 하는 방향으로 떨어지지 않는다.
    # strip 결과는 반드시 확인하고 보고한다 — 판독 불가 원장에서 strip_pending_file 은
    # False 를 내므로, 결과를 안 보고 "정리했다"고 쓰면 일어나지 않은 일을 주장하게 된다
    # (이 릴리스가 고치던 바로 그 결함류를 fix 안에서 재생산하는 꼴).
    _ledger = None  # veto 가 True 면 반드시 bound — 그 불변식을 코드로 보이게 둔다.
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
        # 이미 손에 든 `body` 로 판정한다 — `is_armed()` 는 파일을 다시 읽는데,
        # 그 두 번째 read 가 실패하면 False 로 degrade 해 게이트를 통과시키고,
        # 훅은 이어서 **첫 번째 스냅샷**(`body`)으로 rewrite_state 를 돌려
        # 그 사이 바뀐 파일을 옛 내용으로 덮는다(TOCTOU). 순수 함수로 읽으면
        # 창 자체가 없다.
        _ledger = arm_ledger
        _key = arm_ledger.canonical_key(spec_path)
        _vetoed = _key is not None and _key in arm_ledger.armed_keys(body)
    except Exception as exc:  # noqa: BLE001 — loud degradation
        # **조회 실패만** 여기로 온다. fail-open 방향은 dispatch(과리뷰) 가 맞다 —
        # 원장을 못 읽었다고 리뷰를 건너뛰면 Law 1 게이트가 조용히 꺼진다.
        print(
            f"[spec-distill] 원장 조회 실패 (non-fatal, dispatch 계속): {exc}",
            file=sys.stderr,
        )
        _vetoed = False
    if _vetoed and _ledger is not None:
        # veto 는 이 시점에 **확정**됐다. 정리(sweep)와 보고는 그 뒤의 부작용이므로
        # 판정과 같은 try 를 공유하면 안 된다 — 공유하면 sweep 중의 예외가
        # `except` 로 떨어져 dispatch 경로로 흘러, 원장이 "끝났다"고 못 박은 문서를
        # 다시 dispatch 한다(이 릴리스가 없애려는 재발동 그 자체). 게다가 그때
        # 출력되는 문구는 "원장 조회 실패"라 사실과도 다르다 — 조회는 성공했다.
        try:
            swept = _ledger.strip_pending_file(state_path, spec_path)
        except Exception as exc:  # noqa: BLE001 — sweep 실패는 veto 를 뒤집지 않는다
            swept = False
            print(
                f"[spec-distill] stale pending 정리 실패 (veto 유지): {exc}",
                file=sys.stderr,
            )
        tail = "stale pending 정리함" if swept else "stale pending 은 남음"
        print(
            f"[spec-distill] '{spec_path}'는 원장에 이미 기록된 문서 — "
            f"dispatch 생략 (arm-once); {tail}.",
            file=sys.stderr,
        )
        return 0
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
    msg_lines = [
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        msg_lines.append(f"worktree_path: {wt}.")
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
        # 남기는 것은 emit 시점에 **이미 일어난 사실** 하나뿐이다 — rewrite_state 가
        # 위에서 pending 을 소진했으므로 이 강제는 이번 턴을 넘기지 않는다.
        msg_lines.append("이 mandate는 이번 dispatch 1회에만 유효하다.")
    msg = " ".join(msg_lines)
    # AC7.1: rewrite BEFORE emit. AC7.2: rewrite-fail → no emit (block storm guard).
    try:
        rewrite_state(state_path, body, now, spec_path, attempt_n, cursor, inflight_key)
    except OSError as e:
        print(
            f"[spec-distill] state rewrite failed (non-fatal, dispatch suppressed): {e}",
            file=sys.stderr,
        )
        return 0  # empty stdout, no decision:block — 발견은 무상태라 다음 Stop 이 다시 찾는다
    print(json.dumps({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
