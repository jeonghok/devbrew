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
    import suppress_state  # pyright: ignore[reportMissingImports]
    body = suppress_state.strip_pending(body)
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")


def emit_block(reasons: list[str]) -> None:
    print(
        json.dumps({"decision": "block", "reason": "\n".join(reasons)}),
        flush=True,
    )
    for r in reasons:
        print(f"[spec-distill] {r}", file=sys.stderr)


def emit_suppress_advisory(mode: str, key: str) -> None:
    """v0.14.0 — suppressed 문서 arm skip advisory. 기존 'Reviewer will be
    dispatched' 출력을 *교체*(이중 방출 금지, AC18)."""
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {key} review suppressed this session "
                    "(cancel-review/approved) — arm skipped. "
                    f"Re-enable: /spec-distill:cancel-review --reset {key}"
                ),
            },
            "systemMessage": f"[spec-distill] {mode} arm suppressed for {key}",
        }),
        flush=True,
    )
    print(
        f"[spec-distill] {key} review suppressed this session — arm skipped. "
        f"Re-enable: /spec-distill:cancel-review --reset {key}",
        file=sys.stderr,
    )


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
            # v0.14.0 suppression 게이트 — per-doc, session-scoped (Layer 2).
            # Layer 1 구조 검증은 위에서 이미 실행됨(NG1·AC10): suppressed 문서도
            # 구조 실패면 exit 2로 차단. 여기 도달 = Layer 1 통과.
            try:
                import suppress_state  # pyright: ignore[reportMissingImports]
                sfile = suppress_state.state_file_for(session_id)
                if suppress_state.is_suppressed(sfile, file_path):
                    key = suppress_state.canonical_key(file_path) or file_path
                    emit_suppress_advisory(mode, key)
                    return 0  # arm skip — 기존 advisory 미방출(AC18)
            except Exception as exc:  # noqa: BLE001 — graceful degradation
                print(
                    f"[spec-distill] suppress check failed "
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
