#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer (v0.25.0: dispatch_attempts
G6 cap via arm_ledger; the review-in-progress lock this file carried since
v0.18.0 was removed in v0.25.0 — re-dispatch is now guarded twice: pending-strip
on reviewing-spec entry (연료 제거) and the `armed_paths` gate in main()
(authoritative veto; 남은 stale pending 은 함께 정리를 **시도**하고 성공 여부를 stderr 로 보고). 진입 strip 하나만으로는 부족했다 —
skill 이 Step 1 과 Step 3 을 분리된 두 bash 블록으로 실행하므로 Step 1 이 빠지면
pending 이 살아남는다).

Reads state.local.md for the current session. If `pending_review:` block
is present AND last_dispatched_at is empty or older than the redispatch TTL,
emits stdout `{"decision":"block","reason":"...","systemMessage":"..."}` —
the `decision:"block"` forces Claude Code to continue immediately (no user
input wait), and `reason` is shown to Claude as a system message so the next
turn first action becomes the reviewing-spec skill call.

Ordering guarantee (AC7.1): `rewrite_state()` must complete (with fsync) BEFORE
the JSON is printed. Reverse ordering races with a second Stop fire and
produces a block storm. On rewrite OSError, the hook exits `{}` 0 (no block)
to preserve the race-free TTL guard (AC7.2) — the L4b UserPromptSubmit
reminder picks up the missed dispatch on the next user prompt.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

# 표준 스트림을 UTF-8 로 고정한다 (v0.25.0). `read_text(encoding="utf-8")` 와 달리
# stdin 디코딩은 **프로세스 locale** 을 따르므로, LC_ALL=C 환경에서 훅 payload 의
# 한국어(UserPromptSubmit 의 user prompt, PostToolUse 의 문서 내용)가
# UnicodeDecodeError 로 훅을 죽인다 — 이 플러그인이 [0.24.4] 에서 이미 겪은 실패다.
# except 절을 늘려 열거하는 대신 클래스 자체를 없앤다 (check_verbatim_coverage.py 와 동일 패턴).
for _s in (sys.stdin, sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, OSError):
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402

GC_SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py"


PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n"
    r"(?:  worktree_path:\s*(?P<wt>[^\n]+)\n)?"
    r"  triggered_at:\s*(?P<triggered>[^\n]+)\n",
    re.MULTILINE,
)
LAST_DISPATCHED_RE = re.compile(r"^last_dispatched_at:\s*(.+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:Stop", "spec-distill:review-dispatch"):
        if token in skip_tokens:
            return True
    return False


def state_file_for(session_id: str) -> Path:
    return _state_root() / session_id / "state.local.md"


def parse_iso(s: str) -> Optional[datetime]:
    s = s.strip()
    if not s or s.lower() == "null":
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def rewrite_state(
    path: Path, body: str, now: datetime, spec_path: str, attempt_n: int,
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
    # AC7.1: explicit flush + fsync for OS-level durability before any emit.
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())


def main() -> int:
    if kill_switch_active():
        return 0
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
    if not state_path.exists():
        return 0
    try:
        body = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        # UnicodeDecodeError 는 ValueError 하위라 OSError 로는 잡히지 않는다 — 좁게
        # 잡으면 판독 불가 원장이 훅을 traceback 으로 죽여 dispatch 자체가 사라진다
        # (리뷰를 *덜* 하는 방향, Law 1 이 금지하는 쪽). spec-write-validator.py 와
        # arm_ledger._read_body 는 이미 두 예외를 함께 잡는다 — 형제 소비자 정렬.
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
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # TTL guard against self-ref cycle
    try:
        ttl_sec = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl_sec = 30
    now = datetime.now(timezone.utc)
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
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
        attempt_n = arm_ledger.next_attempt(body, spec_path)
        cap = arm_ledger.DISPATCH_ATTEMPT_CAP
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
    # 환경변수(DEVBREW_DISABLE_SPEC_DISTILL 등)가 답으로 나왔다 — 수명을 모르면
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
        rewrite_state(state_path, body, now, spec_path, attempt_n)
    except OSError as e:
        print(
            f"[spec-distill] state rewrite failed (non-fatal, dispatch suppressed): {e}",
            file=sys.stderr,
        )
        return 0  # empty stdout, no decision:block — L4b reminder picks up on next prompt
    print(json.dumps({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
