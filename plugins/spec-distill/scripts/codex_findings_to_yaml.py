#!/usr/bin/env python3
"""codex_findings_to_yaml.py — Convert Codex JSONL stream to finding YAML.

Vendored from quality-gates (spec-distill design §6 #4). ONLY adaptation vs qg:
the emit keyset adds `category` and `target_section` (design-doc review vocab).
Three-stage fallback (fenced JSON → raw JSON → empty+reason), auth-in-stderr
detection, and last-fenced-block anti-injection are preserved verbatim.

Event shape (Codex 0.130+):
  {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
Legacy shape (fallback): {"type":"agent_message","text":"..."}
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any

AUTH_ERROR_RE = re.compile(
    r"(authentication|auth\s+(failed|error)|invalid\s+(api[\s_]?key|token)"
    r"|401|403|forbidden|unauthor|credential|quota|billing|subscription|expired)",
    re.IGNORECASE,
)
FENCED_JSON_RE = re.compile(r"```json\s*\n(.*?)\n?```", re.DOTALL)


def extract_last_agent_message(stdin_text: str) -> tuple[str | None, bool]:
    last_text: str | None = None
    any_parsed = False
    for line in stdin_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        any_parsed = True
        if not isinstance(ev, dict):
            continue
        item = ev.get("item") if isinstance(ev.get("item"), dict) else ev
        if item.get("type") == "agent_message":
            txt = item.get("text") or item.get("message", "")
            if txt:
                last_text = txt
    return last_text, any_parsed


def parse_fenced_json(text: str) -> dict | None:
    matches = re.findall(FENCED_JSON_RE, text)
    if not matches:
        return None
    try:
        return json.loads(matches[-1])  # last block defeats injected earlier blocks
    except json.JSONDecodeError:
        return None


def parse_raw_json(text: str) -> dict | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def yaml_emit(findings: list[dict], meta: dict) -> str:
    out: list[str] = []
    if not findings:
        out.append("findings: []")
    else:
        out.append("findings:")
        for f in findings:
            out.append("  - agent: codex-reviewer")
            # ADAPTATION vs qg: `category` + `target_section` added for design vocab.
            for k in ("file", "line", "category", "target_section",
                      "severity", "confidence", "summary", "proposed_fix"):
                if k in f:
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    out.append("meta:")
    for k, v in meta.items():
        out.append(f"  {k}: {_yaml_scalar(v)}")
    return "\n".join(out) + "\n"


def _yaml_scalar(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--stderr-file", default=None)
    p.add_argument("--meta-override-exit-code", type=int, default=None)
    p.add_argument("--meta-override-reason", default=None)
    args = p.parse_args()

    stdin_text = sys.stdin.read()
    stderr_text = ""
    _stderr_read_error: str | None = None
    if args.stderr_file:
        try:
            with open(args.stderr_file, "r", encoding="utf-8", errors="replace") as fh:
                stderr_text = fh.read()
        except OSError as e:
            stderr_text = ""
            _stderr_read_error = str(e.errno) if e.errno else type(e).__name__

    def has_auth_error() -> bool:
        return bool(stderr_text and AUTH_ERROR_RE.search(stderr_text))

    def apply_overrides(meta: dict) -> dict:
        if args.meta_override_exit_code is not None:
            meta["exit_code"] = args.meta_override_exit_code
        if args.meta_override_reason:
            meta["reason"] = args.meta_override_reason
            meta["codex_failed"] = True
        if _stderr_read_error is not None:
            meta["stderr_read_error"] = _stderr_read_error
        return meta

    last_msg, any_jsonl_parsed = extract_last_agent_message(stdin_text)

    if last_msg is None:
        if has_auth_error():
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        elif stdin_text.strip() and not any_jsonl_parsed:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": stdin_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "missing_result", "exit_code": 0}
        sys.stdout.write(yaml_emit([], apply_overrides(meta)))
        return 0

    parsed = parse_fenced_json(last_msg)
    if parsed is None:
        parsed = parse_raw_json(last_msg.strip())

    if parsed is None or not isinstance(parsed, dict) or "findings" not in parsed:
        if has_auth_error():
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": last_msg[:200]}
        sys.stdout.write(yaml_emit([], apply_overrides(meta)))
        return 0

    raw_findings = parsed.get("findings", [])
    findings = raw_findings if isinstance(raw_findings, list) else []
    meta = {"codex_failed": False}
    if raw_findings is not None and not isinstance(raw_findings, list):
        meta["reason"] = "schema_mismatch"
        meta["raw_findings_type"] = type(raw_findings).__name__
    sys.stdout.write(yaml_emit(findings, apply_overrides(meta)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
