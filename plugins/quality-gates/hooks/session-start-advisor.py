#!/usr/bin/env python3
"""SessionStart hook: advisory only — never mutates state.

Reads only `.claude/quality-gates/<self-session>/pipeline.md`.
Other sessions' folders are NEVER read or mutated (per CLAUDE.md
"SessionStart never mutates" rule).

Behaviors:
- self in-flight (gate{1,2,3}_running)         → one-line advisory on stdout
- self terminal (completed | aborted)          → silent
- other-session in-flight                      → silent (verbose: sibling count)
- legacy flat state file (v1.5.0) detected     → systemMessage about migration
                                                  (read-only check; setup-qg removes)

Working-directory contract: invoked with cwd = workspace root.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_QUALITY_GATES=1                          - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor   - skip just this one
Verbose: DEVBREW_QG_GC_VERBOSE=1 prints sibling-folder count.

Sub-features (kill switch via DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:<feature>):
  - frontmatter-scan: scan plugins/*/agents/*.md for kebab-case allowed-tools/disallowed-tools keys
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(".claude/quality-gates")
LEGACY_FILES = (
    Path(".claude/quality-gates.local.md"),
    Path(".claude/quality-gates-session.local.md"),
    Path(".claude/quality-gates-branch.local.md"),
    Path(".claude/qg-diff-cache.txt"),
    Path(".claude/qg-code-paths.tmp"),
)
ACTIVE_STATUSES = {"gate1_running", "gate2_running", "gate3_running"}
GATE_RX = re.compile(r"^current_gate:\s*(\S+)", re.MULTILINE)
STARTED_AT_RX = re.compile(r"^started_at:\s*\"?([^\"\n]+)\"?", re.MULTILINE)
STATUS_RX = re.compile(r"^status:\s*\"?(\S+?)\"?\s*$", re.MULTILINE)
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")


def _strip_quotes(value: str) -> str:
    return value.strip().strip('"').strip("'")


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return "quality-gates:session-start-advisor" in tokens


# AC14: sub-feature kill switch
def _subfeature_disabled(feature: str) -> bool:
    if _disabled():
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return f"quality-gates:session-start-advisor:{feature}" in tokens


# AC14: frontmatter scan sub-feature
def _scan_agent_frontmatter_keys() -> None:
    """plugins/*/agents/*.md 스캔, kebab-case allowed-tools/disallowed-tools 발견 시 advice."""
    if _subfeature_disabled("frontmatter-scan"):
        return
    repo_root = Path.cwd()
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


def _verbose() -> bool:
    return os.environ.get("DEVBREW_QG_GC_VERBOSE") == "1"


def _self_session_id() -> str:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return ""
    return payload.get("session_id", "") or ""


def _legacy_present() -> bool:
    return any(p.exists() for p in LEGACY_FILES)


def _sibling_active_count(self_sid: str) -> int:
    if not ROOT.exists():
        return 0
    count = 0
    for child in ROOT.iterdir():
        if not child.is_dir():
            continue
        if not SESSION_PATTERN.match(child.name):
            continue
        if child.name == self_sid:
            continue
        pipeline = child / "pipeline.md"
        if not pipeline.exists():
            continue
        try:
            text = pipeline.read_text()
        except OSError:
            continue
        m = STATUS_RX.search(text)
        if not m:
            continue
        if _strip_quotes(m.group(1)).lower() in ACTIVE_STATUSES:
            count += 1
    return count


def _emit_self_advisory(state_text: str) -> None:
    status_match = STATUS_RX.search(state_text)
    if not status_match:
        return
    status = _strip_quotes(status_match.group(1)).lower()
    if status not in ACTIVE_STATUSES:
        return
    gate_match = GATE_RX.search(state_text)
    gate = _strip_quotes(gate_match.group(1)) if gate_match else "?"
    started_match = STARTED_AT_RX.search(state_text)
    started = _strip_quotes(started_match.group(1)) if started_match else None
    suffix = f" (started {started})" if started else ""
    sys.stdout.write(
        f"[quality-gates] In-flight pipeline at Gate {gate}{suffix}. "
        f"Run `/qg` to resume or `/qg --reset` to clear.\n"
    )


def main() -> int:
    if _disabled():
        return 0
    self_sid = _self_session_id()
    if _legacy_present():
        sys.stdout.write(
            "[quality-gates] Legacy v1.5.0 state files detected. "
            "They will be removed on your next /qg invocation. "
            "If you had an in-flight pipeline, re-run it.\n"
        )
    if self_sid:
        self_pipeline = ROOT / self_sid / "pipeline.md"
        if self_pipeline.exists():
            try:
                text = self_pipeline.read_text()
            except OSError:
                text = ""
            if text:
                _emit_self_advisory(text)
    _scan_agent_frontmatter_keys()
    if _verbose():
        n = _sibling_active_count(self_sid)
        if n > 0:
            sys.stdout.write(
                f"[quality-gates] verbose: {n} sibling session(s) appear active.\n"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
