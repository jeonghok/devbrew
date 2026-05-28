#!/usr/bin/env python3
"""SessionStart hook: advisory only — never mutates state.

v1.32.0 behaviors:
- Legacy v1.x per-session pipeline.md (with stop-hook-era keys) → stderr
  one-shot advisory pointing to `/cancel-qg`.
- Legacy v1.5.0 flat state files (.claude/quality-gates.local.md etc.) →
  stderr one-shot advisory pointing to `/qg --reset`.
- frontmatter-scan sub-feature: warn about kebab-case allowed-tools /
  disallowed-tools in plugins/*/agents/*.md (unchanged from v1.x).

In-flight pipeline detection was removed in v1.32.0 — pipelines no longer
span turns, so there is nothing to "resume" across sessions.

Working-directory contract: state root derived from payload['cwd']; falls
back loudly.

Kill switches:
  DEVBREW_DISABLE_QUALITY_GATES=1                          - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor   - skip just this one

Sub-feature kill switch:
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

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


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return "quality-gates:session-start-advisor" in tokens


def _state_root(hook_input: dict) -> Path:
    """Resolve state root from hook stdin payload cwd; fall back loudly."""
    cwd = hook_input.get("cwd") if hook_input else None
    if not cwd:
        print("[quality-gates] session-start-advisor payload missing 'cwd'; "
              "falling back to process cwd",
              file=sys.stderr)
        cwd = os.getcwd()
    return Path(cwd) / ".claude" / "quality-gates"


# AC14: sub-feature kill switch
def _subfeature_disabled(feature: str) -> bool:
    if _disabled():
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return f"quality-gates:session-start-advisor:{feature}" in tokens


# AC14: frontmatter scan sub-feature
def _scan_agent_frontmatter_keys(payload: dict) -> None:
    """plugins/*/agents/*.md 스캔, kebab-case allowed-tools/disallowed-tools 발견 시 advice."""
    if _subfeature_disabled("frontmatter-scan"):
        return
    repo_root = Path(payload.get("cwd") or os.getcwd())
    for agent_file in repo_root.glob("plugins/*/agents/*.md"):
        try:
            parts = agent_file.read_text().split("---", 2)
            if len(parts) < 3:
                continue
            frontmatter = parts[1]
            for bad_key in ("allowed-tools", "disallowed-tools"):
                if re.search(rf"^{re.escape(bad_key)}:", frontmatter, re.MULTILINE):
                    correct = "".join(
                        p.capitalize() if i else p
                        for i, p in enumerate(bad_key.split("-"))
                    )
                    sys.stderr.write(
                        f"⚠️ {agent_file.relative_to(repo_root)}: agent frontmatter에 "
                        f"kebab-case '{bad_key}' 발견. '{correct}' (camelCase)가 올바른 컨벤션.\n"
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
        per_session = _state_root(payload) / self_sid / "pipeline.md"
        if per_session.exists():
            try:
                text = per_session.read_text()
            except OSError as e:
                print(f"[qg-advisor] legacy-v1 scan skipped: {e}", file=sys.stderr)
                text = ""
            if any(key in text for key in LEGACY_V1_KEYS):
                sys.stderr.write(
                    "[quality-gates v1.32.0] Legacy v1.x pipeline state detected "
                    "in current session. Run `/cancel-qg` to clear before invoking "
                    "`/qg` (v1.32.0 single-turn pipeline cannot resume v1.x state).\n"
                )
                found = True
    # 2. Flat v1.5.0 state files.
    if _legacy_present(payload):
        sys.stderr.write(
            "[quality-gates v1.32.0] Legacy v1.5.0 flat state files detected. "
            "Run `/qg --reset` or `/cancel-qg` to remove. They will also be "
            "removed automatically on next `/qg` invocation.\n"
        )
        found = True
    return found


def main() -> int:
    if _disabled():
        return 0
    payload = _load_payload()
    self_sid = _self_session_id(payload)
    _emit_legacy_v1_advisory(payload, self_sid)
    _scan_agent_frontmatter_keys(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
