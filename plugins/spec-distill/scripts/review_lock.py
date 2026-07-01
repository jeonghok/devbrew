#!/usr/bin/env python3
"""spec-distill review-in-progress 락 — document-keyed(multi-key) 단일 소스 (v0.18.0).

subagent(async) dispatch 중 메인 `Stop`이 진행 중인 리뷰를 재강제(중복 A/절단 B)하는
오발을, "그 문서의 리뷰가 진행 중"인 동안만 그 문서의 dispatch를 게이트해 봉쇄한다.

락은 세션-전역 스칼라도 단일 {path,since} 쌍도 아니라 **문서별 엔트리 리스트**
(suppressed_paths와 동형)다 — 인터리브 2-문서 리뷰에서 한 문서의 set이 다른 문서
엔트리를 clobber하지 않게 하기 위함(design R7/AC18).

state.local.md 스키마:
  review_in_progress:
    - path: docs/superpowers/specs/2026-07-01-A-design.md   # canonical_key
      since: 2026-07-01T13:23:53Z
    - path: docs/superpowers/specs/2026-07-01-B-design.md
      since: 2026-07-01T13:40:00Z

시그니처 비대칭(round-4 advisory): set_lock/clear_lock/pause는 state_file을 받아
read-modify-write를 스스로 소유하는 CLI 진입점이고, is_review_active는 이미 state를
1회 읽은 훅이 재-read를 피하도록 body(문자열)를 받는 read-only 판정기다.

Python API: canonical_key(재수출), set_lock, clear_lock, pause, is_review_active.
CLI (skill·bash 호출자): python3 review_lock.py {set|clear|pause} <sid> <raw_path>
Kill switch: DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
Env: DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC=<int> (default 1800) — set 시 stale 엔트리
prune 임계(explicit `now` 인자로 결정론적). clear/pause는 그 키 엔트리만 제거하고
나머지는 실시간 staleness와 무관하게 그대로 보존한다 — real-clock 기반 프루닝을
clear에도 걸면 고정 과거 타임스탬프를 쓰는 다른 엔트리가 시간 경과에 따라 비결정적으로
사라지는 부작용이 생긴다(이 클래스 버그는 fixture 타임스탬프가 실제 벽시계보다
TTL 이상 뒤처지는 즉시 재현된다).
"""
from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(HOOKS_DIR))
from state_path import SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from suppress_state import (  # noqa: E402 # pyright: ignore[reportMissingImports]
    canonical_key,
    pending_path,
    state_file_for,
    strip_pending,
)

DEFAULT_TTL_SEC = 1800

# 헤더 + 두-줄 엔트리(  - path: … / 4-space since: …)의 0개 이상. suppressed_paths(단일-줄
# `  - <key>`)나 pending_review와 shape이 달라 상호 오매칭 없음.
LOCK_BLOCK_RE = re.compile(
    r"^review_in_progress:\n(?:  - path: [^\n]+\n    since: [^\n]+\n)*",
    re.MULTILINE,
)
ENTRY_RE = re.compile(r"  - path:\s*(?P<path>[^\n]+)\n\s+since:\s*(?P<since>[^\n]+)")


def _ttl_sec() -> int:
    try:
        return int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", str(DEFAULT_TTL_SEC)))
    except ValueError:
        return DEFAULT_TTL_SEC


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s: str):
    try:
        return datetime.strptime(s.strip(), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return None


def _parse_entries(body: str) -> list[tuple[str, str]]:
    """review_in_progress 블록의 (canonical_key, since) 리스트. 없으면 []."""
    m = LOCK_BLOCK_RE.search(body)
    if not m:
        return []
    out: list[tuple[str, str]] = []
    for em in ENTRY_RE.finditer(m.group(0)):
        out.append((em.group("path").strip(), em.group("since").strip()))
    return out


def _strip_lock(body: str) -> str:
    return LOCK_BLOCK_RE.sub("", body)


def _render_lock(entries: list[tuple[str, str]]) -> str:
    lines = ["review_in_progress:"]
    for path, since in entries:
        lines.append(f"  - path: {path}")
        lines.append(f"    since: {since}")
    return "\n".join(lines) + "\n"


def _read_or_init(state_file: Path) -> str:
    if state_file.exists():
        try:
            return state_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(f"[spec-distill] review_lock: state unreadable, re-init: {exc}", file=sys.stderr)
    sid = state_file.parent.name
    return f"---\nsession_id: {sid}\n---\n\n"


def _atomic_write(state_file: Path, body: str) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    with open(state_file, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())


def _is_stale(since: str, now: datetime, ttl: int) -> bool:
    dt = parse_iso(since)
    if dt is None:
        return True  # unparseable → prune (fail-safe)
    return (now - dt).total_seconds() >= ttl


def _write_entries(state_file: Path, body: str, entries: list[tuple[str, str]]) -> None:
    """entries를 staleness와 무관하게 그대로 렌더+원자적 write. clear/pause 전용 경로."""
    body = _strip_lock(body).rstrip()
    if entries:
        body = body + "\n\n" + _render_lock(entries).rstrip()
    _atomic_write(state_file, body + "\n")


def _commit(state_file: Path, body: str, entries: list[tuple[str, str]], now: datetime, ttl: int) -> None:
    """stale 엔트리를 explicit now 기준으로 prune 후 write. set_lock 전용(결정론적)."""
    fresh = [(p, s) for (p, s) in entries if not _is_stale(s, now, ttl)]
    _write_entries(state_file, body, fresh)


def set_lock(state_file: Path, raw_path: str, now: datetime) -> None:
    """그 문서 엔트리를 {path, since: now}로 upsert(refresh). 다른 엔트리 보존.

    매 reviewing-spec 진입(최초 + revise 재진입)에서 호출 — 라운드-간 gap만 TTL에
    걸리고 누적 리뷰시간은 걸리지 않게 하는 refresh-on-reentry(AC1/AC15).
    스코프 밖(canonical_key None) 경로는 no-op.
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    body = _read_or_init(state_file)
    entries = [(p, s) for (p, s) in _parse_entries(body) if p != key]
    entries.append((key, _iso(now)))
    _commit(state_file, body, entries, now, _ttl_sec())


def clear_lock(state_file: Path, raw_path: str) -> None:
    """그 문서 엔트리만 제거. 다른 엔트리 보존. 멱등. approve/cancel이 호출.

    다른 엔트리는 실시간 staleness 재평가 없이 그대로 write-back한다 — 여기서
    real-clock 기반 prune을 걸면 fixture/과거 타임스탬프를 가진 엔트리가 벽시계
    경과에 따라 비결정적으로 사라진다(set_lock만 explicit now로 결정론적 prune).
    """
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    entries = [(p, s) for (p, s) in _parse_entries(body) if p != key]
    _write_entries(state_file, body, entries)


def pause(state_file: Path, raw_path: str) -> None:
    """④ 멈춤: 그 문서 엔트리 제거 + 같은-키 pending strip(suppress 없음 — resumable).

    엔트리만 제거하고 pending을 남기면 즉시 재발동([83dc5425]), 엔트리를 남기면
    bounded under-review 창([fa17d241]) — 둘을 함께 닫는다(AC17). 다른 문서 엔트리·
    pending은 불변.
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    clear_lock(state_file, raw_path)
    if not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    pend = pending_path(body)
    if pend is not None and canonical_key(pend) == key:
        _atomic_write(state_file, strip_pending(body).rstrip() + "\n")


def is_review_active(body: str, pending_key: str | None, now: datetime, ttl: int) -> bool:
    """그 pending 문서의 락 엔트리가 존재 + 신선일 때만 True. 그 외 전부 False.

    False(엔트리 부재 / stale / 파싱 불가) → 훅이 정상 dispatch(fail-safe = 강제, Law 1).
    다른 문서 엔트리가 신선해도 pending_key로 조회하므로 이 문서엔 영향 없음(AC16).
    """
    if not pending_key:
        return False
    for path, since in _parse_entries(body):
        if path == pending_key:
            dt = parse_iso(since)
            if dt is None:
                return False
            if (now - dt).total_seconds() >= ttl:
                return False
            return True
    return False


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print("[spec-distill] review_lock: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op", file=sys.stderr)
        return 0
    if len(argv) < 4:
        print("usage: review_lock.py {set|clear|pause} <sid> <raw_path>", file=sys.stderr)
        return 2
    cmd, sid, raw_path = argv[1], argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(f"[spec-distill] review_lock: session_id rejected: '{trunc}'", file=sys.stderr)
        return 2
    sf = state_file_for(sid)
    if cmd == "set":
        set_lock(sf, raw_path, datetime.now(timezone.utc))
        return 0
    if cmd == "clear":
        clear_lock(sf, raw_path)
        return 0
    if cmd == "pause":
        pause(sf, raw_path)
        return 0
    print(f"[spec-distill] review_lock: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
