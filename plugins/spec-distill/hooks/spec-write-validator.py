#!/usr/bin/env python3
"""spec-distill PostToolUse hook — Layer 1 structural validator.

- Reads PostToolUse JSON payload from stdin.
- Filters: tool must be Write/Edit/MultiEdit on a `.md` under docs/superpowers/specs/
  (sub-folder hierarchy 포함).
  Mode: `-spec.md` → spec; `-design.md` → design; other `.md` → spec if its
  frontmatter block has a `locked_decisions` key, else design.
  Out-of-scope paths exit 0 silently.
- spec mode: 11 sections + frontmatter + locked_decisions + ambiguity scan.
- design mode: ambiguity + placeholder scan only.
- On pass: writes `pending_review:` block to .claude/spec-distill/<session>/state.local.md.
- On fail: exit 2 + stderr; stdout `{"decision": "block", "reason": "..."}` for safety.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse  (or :validator)
- DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1  (Layer 1 only; skip state write)
- DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1  (skip design.md)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root  # noqa: E402
PARSE_LIB = SCRIPT_DIR.parent / "scripts" / "parse_spec_structure.py"
BLACKLIST = SCRIPT_DIR.parent / "scripts" / "ambiguity-blacklist.txt"

PATH_PREFIX = "docs/superpowers/specs/"

# arm_ledger 와 같은 패턴이지만 의도적으로 로컬이다. 이 플러그인은 이미
# review-dispatch.py·pending-review-reminder.py·arm_ledger.py
# 세 곳에서 이 정규식을 각자 정의한다 — 새 중복이 아니라 기존 관례.
PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:PostToolUse", "spec-distill:validator"):
        if token in skip_tokens:
            return True
    return False


def _frontmatter_has_locked_decisions(file_path: str) -> bool:
    """첫 ---...--- frontmatter 블록 안에 locked_decisions 키가 있으면 True.

    body의 locked_decisions 언급은 무시. 닫는 ---가 없는 unclosed frontmatter는
    유효 블록이 아니므로 False. 읽기/디코드 실패는 False + loud stderr (caller가
    design으로 매핑)."""
    try:
        text = Path(file_path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] resolve_mode content-peek failed for {file_path}: {exc}",
            file=sys.stderr,
        )
        return False
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False  # frontmatter 블록 없음
    block: list[str] = []
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        block.append(line)
    if not closed:
        return False  # unclosed frontmatter → spec marker로 인정 안 함
    return any(re.match(r"\s*locked_decisions\s*:", b) for b in block)


def resolve_mode(file_path: str) -> Optional[str]:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if not file_path.endswith(".md"):
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    design_disabled = (
        os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1"
    )
    if file_path.endswith("-design.md"):
        return None if design_disabled else "design"
    # suffix 없는 임의 .md — content-aware
    if _frontmatter_has_locked_decisions(file_path):
        return "spec"
    return None if design_disabled else "design"


def call_parser(sub: str, *args: str) -> dict:
    try:
        cp = subprocess.run(
            ["python3", str(PARSE_LIB), sub, *args],
            capture_output=True, text=True, check=False,
            timeout=10,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as exc:
        return {"_error": f"parser failure: {exc}"}
    if cp.returncode != 0:
        return {"_error": cp.stderr.strip() or f"parser rc={cp.returncode}"}
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        return {"_error": f"parser bad json: {e}"}


LEGACY_ADVISORY_MARKER = ".legacy-advisory-emitted-v060"


def _legacy_advisory_check(state_root_path: Path) -> None:
    """AC14 — emit one-shot advisory if `.claude/spec-distill/default/` exists."""
    legacy = state_root_path / "default"
    marker = state_root_path / LEGACY_ADVISORY_MARKER
    if not legacy.exists() or marker.exists():
        return
    try:
        state_root_path.mkdir(parents=True, exist_ok=True)
        marker.write_text("")
        print(
            "[spec-distill] v0.6.0 detected: .claude/spec-distill/default/ "
            "legacy folder, manual cleanup recommended (no auto-delete to "
            "preserve in-flight work — see CHANGELOG [0.6.0]).",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] legacy advisory marker write failed: {exc}",
            file=sys.stderr,
        )


def write_state(session_id: str, path: str, mode: str, worktree_path: str) -> None:
    state_dir = _state_root() / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    _legacy_advisory_check(_state_root())
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  worktree_path: {worktree_path}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if not state_file.exists():
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # File exists — detect stale session_id (AC8 defensive truncate)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as exc:
        print(
            f"[spec-distill] state.local.md unreadable — preserving for debug: {exc}",
            file=sys.stderr,
        )
        return
    fm_match = re.search(r"^session_id:\s*([^\n]+)$", body, flags=re.MULTILINE)
    if fm_match and fm_match.group(1).strip() != session_id:
        old = fm_match.group(1).strip()
        print(
            f"[spec-distill] stale state detected (old sid={old[:32]}, "
            f"current={session_id[:32]}) — truncating",
            file=sys.stderr,
        )
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # Matching session_id (or no frontmatter — backward compat per AC8 case iii)
    # — strip pending_review block and append fresh
    # "pending_review 블록은 정확히 하나" 는 모듈 가용성과 무관하게 성립해야 한다.
    # 두 블록이 생기면 Stop 이 첫 블록(다른 문서)을 소비하고 rewrite_state 의 전역
    # re.sub 가 방금 arm 된 문서의 트리거까지 지운다 — 오류 없는 under-review.
    body = PENDING_RE.sub("", body)
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")


def emit_block(reasons: list[str]) -> None:
    print(
        json.dumps({"decision": "block", "reason": "\n".join(reasons)}),
        flush=True,
    )
    for r in reasons:
        print(f"[spec-distill] {r}", file=sys.stderr)


ARM_SKIP_REASONS = {
    "reviewed": "이 세션에서 리뷰가 이미 완료됨 (arm-once)",
    "capped": (
        "리뷰가 3회 시도됐으나 verdict 없이 끝나 자동 dispatch를 중단함 (G6 상한) "
        "— 리뷰가 필요하면 reviewing-spec을 직접 호출하라"
    ),
    "born": "git이 아는 문서 — 커밋 이후에는 자동 리뷰가 붙지 않는다",
    "out-of-scope": "스코프 밖 경로",
}


def emit_arm_skip_advisory(mode: str, key: str, reason: str) -> None:
    """v0.25.0 — arm-once 게이트가 arm을 건너뛸 때의 advisory.

    기존 'Reviewer will be dispatched' 출력을 *교체*한다(이중 방출 금지). 사유를
    구분해 표시하는 것이 요건이다 — 'reviewed'와 'capped'는 둘 다 armed_paths에
    있지만 사용자가 취해야 할 행동이 다르다(전자는 정상, 후자는 수동 호출 필요).
    """
    why = ARM_SKIP_REASONS.get(reason, reason)
    text = f"[spec-distill] {key} arm skipped — {why}."
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": text,
            },
            "systemMessage": f"[spec-distill] {mode} arm skipped ({reason}) for {key}",
        }),
        flush=True,
    )
    print(text, file=sys.stderr)


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # graceful degradation; not our payload
    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    mode = resolve_mode(file_path)
    if mode is None:
        return 0  # out of scope

    # Layer 1 mechanical checks
    reasons: list[str] = []
    if mode == "spec":
        fm = call_parser("frontmatter", file_path)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        ld = call_parser("locked-decisions", file_path)
        if ld.get("errors"):
            reasons.append("locked_decisions errors: " + "; ".join(ld["errors"]))
        secs = call_parser("sections", file_path)
        missing = secs.get("missing", [])
        if missing:
            reasons.append(f"missing sections: {missing}")

    amb = call_parser("ambiguity", file_path, str(BLACKLIST))
    for hit in amb.get("hits", []):
        reasons.append(
            f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\""
        )

    if mode == "design":
        ph = call_parser("placeholders", file_path)
        for hit in ph.get("hits", []):
            reasons.append(
                f"placeholder hit: {hit['token']} at line {hit['line']}"
            )

    if reasons:
        emit_block(reasons)
        return 2

    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        from state_path import resolve_session_id
        session_id = resolve_session_id(payload)
        if session_id is not None:
            # v0.25.0 arm-once 게이트 (Layer 2). Layer 1 구조 검증은 위에서 이미
            # 실행됐다(G2) — arm이 skip돼도 구조 실패는 exit 2로 차단된다.
            # 판정 실패(모듈 부재·원장 read 실패·git 불능)는 전부 arm 쪽으로
            # fail-open한다 (Law 1: 과리뷰 > under-review). 원장이 1회로 제한하므로
            # storm이 되지 않는다.
            try:
                import arm_ledger  # pyright: ignore[reportMissingImports]
                sfile = arm_ledger.state_file_for(session_id)
                if not arm_ledger.should_arm(sfile, file_path):
                    key = arm_ledger.canonical_key(file_path) or file_path
                    emit_arm_skip_advisory(
                        mode, key, arm_ledger.skip_reason(sfile, file_path))
                    return 0  # arm skip — 기존 advisory 미방출
            except Exception as exc:  # noqa: BLE001 — graceful degradation
                print(
                    f"[spec-distill] arm gate failed "
                    f"(non-fatal, arming normally): {exc}",
                    file=sys.stderr,
                )
            try:
                write_state(session_id, file_path, mode, os.getcwd())
            except (PermissionError, OSError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)

    # Advisory output (v0.5.0 dual-target: additionalContext for Claude + systemMessage trace).
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {mode} structural OK. "
                    "Reviewer will be dispatched at turn end "
                    "(Stop hook will mandate reviewing-spec skill invocation)."
                ),
            },
            "systemMessage": f"[spec-distill] {mode} OK · reviewer dispatch pending",
        }),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
