#!/usr/bin/env python3
"""extract_codex_artifact_yaml.py — parse codex JSONL (stdin) -> artifact Finding YAML.

Pulls the last non-empty agent-message text from the codex --json stream,
extracts a fenced ```yaml block, validates it has a `findings:` list, and emits:
    agent: codex-reviewer
    findings: [...]
On any failure (nonzero codex exit, no message, no fence, unparseable, wrong
shape) emits a degrade meta:
    codex_failed: true
    reason: <str>
so the SKILL can loud-degrade instead of crashing (C7). Mirrors the exit/reason
override contract of codex_findings_to_yaml.py.
"""
import argparse
import json
import re
import sys

import yaml

FENCE = re.compile(r"```(?:ya?ml)?\s*\n(.*?)```", re.DOTALL)


def extract_text(stream):
    text = None
    for ln in stream.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            obj = json.loads(ln)
        except json.JSONDecodeError:
            continue
        msg = obj.get("msg") if isinstance(obj, dict) else None
        candidate = None
        if isinstance(msg, dict):
            candidate = msg.get("message") or msg.get("text") or msg.get("content")
        elif isinstance(obj, dict):
            candidate = obj.get("message") or obj.get("text")
        if isinstance(candidate, str) and candidate.strip():
            text = candidate   # keep the last non-empty message
    return text


def degrade(reason):
    print("codex_failed: true")
    print(f"reason: {reason}")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--meta-override-exit-code", type=int, default=0)
    ap.add_argument("--meta-override-reason", default="")
    a = ap.parse_args()

    if a.meta_override_exit_code != 0:
        return degrade(a.meta_override_reason or "exit_nonzero")

    text = extract_text(sys.stdin.read())
    if not text:
        return degrade("no_agent_message")
    m = FENCE.search(text)
    block = m.group(1) if m else text
    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError:
        return degrade("yaml_parse_failed")
    findings = data.get("findings") if isinstance(data, dict) else None
    if not isinstance(findings, list):
        return degrade("no_findings_list")
    for f in findings:
        if isinstance(f, dict):
            f["agent"] = "codex-reviewer"
    sys.stdout.write(yaml.safe_dump({"agent": "codex-reviewer", "findings": findings},
                                    allow_unicode=True, sort_keys=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
