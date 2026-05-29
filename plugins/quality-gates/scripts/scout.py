#!/usr/bin/env python3
"""Scout (T3-1 refactor) — deterministic depth/agent dispatch decision.

Replaces agents/scout.md Agent dispatch. The decision rules in v1.x
scout.md L42-44 are already deterministic; the LLM was only applying the
table. Direct rule-based decision saves ~5-15K input + 500 output tokens
per Review gate iteration.

Input (stdin JSON):
  {
    "changed_lines": int,
    "new_files": int,
    "config_touched": bool,
    "type_design": bool,
    "test_change": bool
  }

Output (stdout YAML):
  depth: quick | standard | deep
  phase1_agents: [...]
  phase2_agents: [...]
  rationale: <string>
  fallback: false
"""
import json
import sys


def decide(s):
    changed = int(s.get("changed_lines", 0))
    new_files = int(s.get("new_files", 0))
    config = bool(s.get("config_touched", False))
    type_design = bool(s.get("type_design", False))
    test_change = bool(s.get("test_change", False))

    # Depth decision (v1.x scout.md L42-44)
    if changed >= 200 or new_files >= 1 or config or type_design:
        depth = "deep"
        rationale = "Large or structural change — deep review warranted."
    elif changed >= 50:
        depth = "standard"
        rationale = "Mid-size change — standard depth."
    else:
        depth = "quick"
        rationale = "Small focused change — quick review."

    if depth == "quick":
        phase1 = ["code-reviewer", "security-reviewer"]
    elif depth == "standard":
        phase1 = ["code-reviewer", "silent-failure-hunter", "security-reviewer"]
    else:
        phase1 = [
            "code-reviewer", "silent-failure-hunter",
            "feature-dev:code-reviewer", "security-reviewer",
        ]

    phase2 = []
    if depth != "quick":
        if type_design:
            phase2.append("type-design-analyzer")
        if test_change:
            phase2.append("pr-test-analyzer")
        if new_files > 0:
            phase2.append("feature-dev:code-architect")

    return {
        "depth": depth,
        "phase1_agents": phase1,
        "phase2_agents": phase2,
        "rationale": rationale,
        "fallback": False,
    }


def emit_yaml(d):
    lines = [
        f"depth: {d['depth']}",
        "phase1_agents: [" + ", ".join(d["phase1_agents"]) + "]",
        "phase2_agents: [" + ", ".join(d["phase2_agents"]) + "]",
        f'rationale: "{d["rationale"]}"',
        f"fallback: {'true' if d['fallback'] else 'false'}",
    ]
    return "\n".join(lines) + "\n"


def main():
    try:
        s = json.load(sys.stdin)
    except json.JSONDecodeError:
        s = {}
    sys.stdout.write(emit_yaml(decide(s)))


if __name__ == "__main__":
    main()
