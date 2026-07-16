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
    """Extract the last non-empty agent-message text from a codex JSONL stream.

    Real codex 0.130+ event shape (ground truth — see
    tests/spike/fixtures/codex_jsonl_sample.json and the sibling
    codex_findings_to_yaml.py's extract_last_agent_message):
        {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
    Legacy/flat shape (also handled, mirroring the sibling): the event itself
    carries type=="agent_message" with text/message directly on it.
    The old invented {"msg": {...}} shape is retained only as a defensive
    fallback — it does not occur in real codex output.
    """
    text = None
    for ln in stream.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            obj = json.loads(ln)
        except json.JSONDecodeError:
            continue
        if not isinstance(obj, dict):
            continue
        # Drill into nested item if present (Codex 0.130+), else use event directly (legacy).
        raw_item = obj.get("item")
        item = raw_item if isinstance(raw_item, dict) else obj
        candidate = None
        if item.get("type") == "agent_message":
            candidate = item.get("text") or item.get("message") or item.get("content")
        if candidate is None:
            # Defensive fallback for the pre-existing (invented) shape — not real codex output.
            msg = obj.get("msg")
            if isinstance(msg, dict):
                candidate = msg.get("message") or msg.get("text") or msg.get("content")
            else:
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
    # AC9(b) parity with codex_findings_to_yaml.py: pick the LAST fenced block
    # to defeat adversarial diff-injected earlier blocks (the artifact-critique
    # prompt embeds untrusted artifact content codex may quote/echo).
    matches = re.findall(FENCE, text)
    block = matches[-1] if matches else text
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
