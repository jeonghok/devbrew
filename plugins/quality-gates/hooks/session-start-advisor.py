#!/usr/bin/env python3
"""SessionStart hook: advisory only — never mutates state.

v1.32.0 behaviors:
- Legacy v1.x per-session pipeline.md (with stop-hook-era keys) → stderr
  one-shot advisory pointing to `/cancel-qg`.
- Legacy v1.5.0 flat state files (.claude/quality-gates.local.md etc.) →
  stderr one-shot advisory pointing to `/qg --reset`.
- frontmatter-scan sub-feature: warn about the dead `allowedTools` key and
  wrong-layer kebab keys in plugins/*/agents/*.md (v2.11.0: the advice used
  to point at camelCase `allowedTools`, which is not a real subagent field).

In-flight pipeline detection was removed in v1.32.0 — pipelines no longer
span turns, so there is nothing to "resume" across sessions.

Working-directory contract: state root derived from payload['cwd']; falls
back loudly.

Kill switches:
  DEVBREW_QUALITY_GATES_DISABLE=1                          - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor   - skip just this one
  DEVBREW_SKIP_HOOKS=quality-gates:SessionStart            - skip every SessionStart hook here

Sub-feature kill switch:
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402
from state_path import state_root  # noqa: E402

LEGACY_RELATIVE = (
    ".claude/quality-gates.local.md",
    ".claude/quality-gates-session.local.md",
    ".claude/quality-gates-branch.local.md",
    ".claude/qg-diff-cache.txt",
    ".claude/qg-code-paths.tmp",
)
# Invariant: the two compound v1.x keys MUST use string concatenation to
# evade source-grep — a future test asserting "no v1.x token leaks into
# this advisor source" would otherwise fire on these literals. The single-
# word `status:` token is left unsplit because (a) it lacks the
# v1.x-distinguishing compound substrings (the `_gate` and `_no_signal`
# suffixes) and (b) `status:` is too generic to ever be source-grepped in
# isolation.
#
# AC17 has two layers of enforcement:
#   1. Behavioral (V8c in test_session_start_advisor_v2.sh): each legacy
#      key, written into a fixture pipeline.md, must trigger the advisory.
#   2. Source-text (V8d, added v1.32.2): both compound-key split forms
#      ("current" + "_gate:", "consecutive_no" + "_signal:") must appear
#      on the LEGACY_V1_KEYS line AND no unsplit literal form may appear
#      anywhere else in this file. V8d catches naive ruff/black auto-fix
#      merging of the concat strings.
#
# v1.32.0: in-flight detection removed — legacy v1.x markers are detected
# for one-shot advisory only (see _emit_legacy_v1_advisory).
LEGACY_V1_KEYS = ("status:", "current" + "_gate:", "consecutive_no" + "_signal:")


# AC14: sub-feature kill switch
def _subfeature_disabled(feature: str) -> bool:
    if kill_switch_active("quality-gates", "session-start-advisor", "SessionStart"):
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return f"quality-gates:session-start-advisor:{feature}" in tokens


# AC14: frontmatter scan sub-feature
def _scan_agent_frontmatter_keys(payload: dict) -> None:
    """plugins/*/agents/*.md 스캔 — 죽은 allowedTools / 잘못된 계층의 kebab 키 경고.

    v2.11.0 정정: 이 스캐너는 kebab -> camelCase 를 권고했으나 `allowedTools` 는
    공식 subagent frontmatter 필드가 아니다 (실재 키는 `tools` / `disallowedTools`).
    잘못된 방향의 권고가 결함을 매 세션 재확인해 주고 있었다.
    """
    if _subfeature_disabled("frontmatter-scan"):
        return
    repo_root = Path(payload.get("cwd") or os.getcwd())
    for agent_file in repo_root.glob("plugins/*/agents/*.md"):
        try:
            # encoding 명시: agent 파일은 한국어를 담는다. 비-UTF-8 locale 에서
            # UnicodeDecodeError 가 아래 except 에 삼켜지면 스캐너가 조용히 fail-open 한다.
            parts = agent_file.read_text(encoding="utf-8").split("---", 2)
            if len(parts) < 3:
                continue
            frontmatter = parts[1]
            for bad_key, why in (
                ("allowedTools", "공식 subagent 규격에 없는 필드 — 런타임이 조용히 무시한다"),
                ("allowed-tools", "command/skill 계층의 키 — agent 에는 없다"),
                ("disallowed-tools", "kebab 변종 — agent 의 실재 키는 disallowedTools"),
            ):
                # '^' 앵커 필수: 앵커 없이 검사하면 'disallowedTools:' 안의
                # 'allowedTools' 부분문자열에 매칭돼 정상 파일에 false-positive.
                if re.search(rf"^{re.escape(bad_key)}:", frontmatter, re.MULTILINE):
                    sys.stderr.write(
                        f"⚠️ {agent_file.relative_to(repo_root)}: agent frontmatter 에 "
                        f"'{bad_key}' 발견 ({why}). Law 2 격리는 `tools:` allowlist 로 "
                        f"선언할 것 — denylist 는 시간에 대해 fail-open 이다.\n"
                    )
        except (OSError, UnicodeDecodeError):
            continue


def _self_session_id(payload: dict) -> str:
    return payload.get("session_id", "") or ""


def _load_payload() -> dict:
    try:
        return json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"[qg-advisor] payload parse failed: {e}", file=sys.stderr)
        return {}
    except OSError as e:
        print(f"[qg-advisor] payload read failed: {e}", file=sys.stderr)
        return {}


def _legacy_present(payload: dict) -> bool:
    """Resolve legacy v1.5.0 marker paths against payload cwd (Gate-2 review C1)."""
    cwd = payload.get("cwd") if payload else None
    base = Path(cwd) if cwd else Path.cwd()
    return any((base / rel).exists() for rel in LEGACY_RELATIVE)


def _emit_legacy_v1_advisory(payload: dict, self_sid: str) -> bool:
    """Detect legacy v1.x state file (per-session or flat) and emit one-shot
    `/cancel-qg` guidance on stderr. Returns True if anything was found."""
    found = False
    # 1. Per-session v1.x state file with stop-hook-era keys.
    if self_sid:
        per_session = state_root(payload, "session-start-advisor") / self_sid / "pipeline.md"
        if per_session.exists():
            try:
                text = per_session.read_text(encoding="utf-8")
            except OSError as e:
                print(f"[qg-advisor] legacy-v1 scan skipped: {e}", file=sys.stderr)
                text = ""
            if any(key in text for key in LEGACY_V1_KEYS):
                sys.stderr.write(
                    "[quality-gates] Legacy v1.x pipeline state detected "
                    "in current session. Run `/cancel-qg` to clear before invoking "
                    "`/qg` (single-turn pipeline cannot resume v1.x state).\n"
                )
                found = True
    # 2. Flat v1.5.0 state files.
    if _legacy_present(payload):
        sys.stderr.write(
            "[quality-gates] Legacy v1.5.0 flat state files detected. "
            "Run `/qg --reset` or `/cancel-qg` to remove. They will also be "
            "removed automatically on next `/qg` invocation.\n"
        )
        found = True
    return found


def main() -> int:
    if kill_switch_active("quality-gates", "session-start-advisor", "SessionStart"):
        return 0
    payload = _load_payload()
    self_sid = _self_session_id(payload)
    _emit_legacy_v1_advisory(payload, self_sid)
    _scan_agent_frontmatter_keys(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
