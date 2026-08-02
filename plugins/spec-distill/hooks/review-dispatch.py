#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer (v0.18.0).

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
    except json.JSONDecodeError:
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
    except OSError as e:
        print(f"[spec-distill] state read failed (non-fatal): {e}", file=sys.stderr)
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
    if cap and attempt_n >= cap:
        msg_lines.append(
            f"[spec-distill] '{spec_path}' 리뷰가 {cap}회 시도됐으나 verdict 없이 "
            "끝났다 — 자동 dispatch를 중단한다. 리뷰가 필요하면 reviewing-spec을 "
            "직접 호출하라."
        )
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
