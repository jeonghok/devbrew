#!/usr/bin/env python3
"""spec-distill Stop hook — compact induction (v0.10.0).

If a handoff marker file exists at .claude/spec-distill/.markers/<sid>.emitted,
emit JSON with hookSpecificOutput.additionalContext containing the verbatim
/compact command and the writing-plans pointer. This is the *unmissable*
SystemMessage layer that defeats AP2 "polite stop" — once approve_handoff.sh
writes the marker, every Stop turn re-injects the next-step instruction
until the user actually runs /compact (UserPromptSubmit hook deletes marker)
or 5 fires elapse (stagnation escape, Task 10).

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:compact-induction (or :Stop — shared with review-dispatch)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root, resolve_session_id  # noqa: E402

FIRE_COUNT_RE = re.compile(r"^FIRE_COUNT=(\d+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:compact-induction",
        "spec-distill:Stop",
    })


def read_marker(marker: Path) -> dict[str, str]:
    """Parse the plaintext key=value marker file."""
    out: dict[str, str] = {}
    try:
        for line in marker.read_text(encoding="utf-8").splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                out[k.strip()] = v.strip()
    except OSError:
        pass
    return out


def bump_fire_count(marker: Path, body: str) -> int:
    """Increment FIRE_COUNT line in marker file. Returns new count."""
    m = FIRE_COUNT_RE.search(body)
    current = int(m.group(1)) if m else 0
    new_count = current + 1
    if m:
        new_body = FIRE_COUNT_RE.sub(f"FIRE_COUNT={new_count}", body)
    else:
        new_body = body.rstrip() + f"\nFIRE_COUNT={new_count}\n"
    try:
        marker.write_text(new_body, encoding="utf-8")
    except OSError as exc:
        print(f"[spec-distill] compact-induction marker write failed: {exc}", file=sys.stderr)
    return new_count


def emit_no_op() -> None:
    """Default {} stdout for AC4 miss path — JSON-consistent."""
    print("{}", flush=True)


def emit_induction(spec_path: str) -> None:
    additional_context = (
        "MANDATORY next step: handoff packet emitted — 사용자가 `/compact`를 실행해야 다음 phase 진입.\n\n"
        "다음 명령을 사용자에게 보이도록 *그대로* 노출 (narrate-only 금지):\n\n"
        f"  /compact spec at {spec_path} 보존. 그 spec 본문(특히 Handoff Context, "
        "Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. "
        f"다음 단계는 \"Skill superpowers:writing-plans {spec_path}\" 호출.\n\n"
        "사용자 `/compact` 후 첫 입력 (또는 자동 진행 시 즉시):\n\n"
        f"  Skill superpowers:writing-plans {spec_path}\n\n"
        "주의: 본 메시지는 사용자가 `/compact` 또는 `Skill superpowers:writing-plans`로 시작하는 "
        "프롬프트를 입력할 때까지 매 Stop turn 재발화됨 (compact-induction hook)."
    )
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "Stop",
            "additionalContext": additional_context,
        },
        "systemMessage": "[spec-distill] compact induction — /compact required",
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] compact-induction stdin error: {exc}", file=sys.stderr)
        payload = {}

    session_id = resolve_session_id(payload)
    if session_id is None:
        emit_no_op()
        return 0

    marker = state_root() / ".markers" / f"{session_id}.emitted"
    if not marker.exists():
        emit_no_op()
        return 0

    try:
        body = marker.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"[spec-distill] compact-induction marker read failed: {exc}", file=sys.stderr)
        emit_no_op()
        return 0

    fields = read_marker(marker)
    spec_path = fields.get("SPEC_PATH", "<spec path missing in marker>")

    new_count = bump_fire_count(marker, body)
    if new_count >= 5:
        try:
            marker.unlink()
        except OSError as exc:
            print(
                f"[spec-distill] compact-induction stagnation cleanup failed: {exc}",
                file=sys.stderr,
            )
        print(
            "[spec-distill] compact-induction stagnation: 5 fires without /compact "
            "— manual confirmation required",
            file=sys.stderr,
        )
        emit_no_op()
        return 0
    emit_induction(spec_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
