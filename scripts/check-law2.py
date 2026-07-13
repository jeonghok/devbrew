#!/usr/bin/env python3
"""check-law2.py — AC-1a. Static proof that a Workflow script can only dispatch
write-denied agents.

Runs in pre-0, BEFORE a single agent is spawned. A post-mortem is not a gate.

Law 2 (writer and reviewer must never share a pass) is enforced physically, and in the
Workflow tool the *only* lever is agentType: agent() has no tool-scoping option, and an
agent() call with no agentType silently falls back to a write-capable default. So the
whole of Law 2 rests on two claims:

    every agent() call carries an agentType from a fixed allowlist, and
    every agent in that allowlist declares tools: ⊆ {Glob, Grep, Read, WebSearch, WebFetch}

Counting *identifiers*, not syntax. `\\bagent\\(` — the obvious predicate — is defeated
five different ways, all legal JS:

    agent (p, {})            space between callee and paren
    agent?.(p, {})           optional call
    const go = agent; go(p)  alias
    agent.call(null, p, {})  .call
    {agentType: 'x', ...opts}   spread order reversed → caller's opts.agentType wins

The first four change the identifier count (2 → 3), so counting `agent` as a token catches
them. The fifth does not, so the two helper lines are pinned byte-for-byte instead.

`agentType` does not match the token regex (a `T` follows), so the helpers' own
`agentType:` keys never pollute the count.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SAFE_TOOLS = {"Glob", "Grep", "Read", "WebSearch", "WebFetch"}

# Identifier `agent`, not preceded by a word char / $ / dot, not followed by a word char.
AGENT_TOKEN = re.compile(r"(?<![\w$.])agent(?![\w$])")

# The audit workflow's only two dispatch sites. Pinned byte-for-byte.
# The spread comes FIRST so agentType cannot be overridden by a caller's opts.
CANONICAL_HELPERS = [
    "const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-auditor'})",
    "const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'audit-refuter'})",
]
CANONICAL_SMOKE = [
    "const probe = (prompt, opts) => agent(prompt, {...opts, agentType: 'smoke-probe'})",
]


def strip_js_noise(src: str) -> str:
    """Blank out comments and string literals, preserving offsets and line structure.

    A gap cited from inside a comment or a prompt string is not a dispatch site, and a
    prompt that merely contains the word "agent" must not trip the count.
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
        elif c == "/" and nxt == "*":
            out[i] = out[i + 1] = " "
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                if src[i] != "\n":
                    out[i] = " "
                i += 1
            if i < n:
                out[i] = " "
                if i + 1 < n:
                    out[i + 1] = " "
                i += 2
        elif c in "'\"`":
            quote = c
            out[i] = " "
            i += 1
            depth = 0          # brace depth inside a ${...} interpolation
            while i < n:
                ch = src[i]
                if ch == "\\":
                    if src[i] != "\n":
                        out[i] = " "
                    if i + 1 < n and src[i + 1] != "\n":
                        out[i + 1] = " "
                    i += 2
                    continue
                # A `${...}` interpolation is CODE, not string text. Blanking it hides a
                # real dispatch: `${agent(p, {})}` is an agent() call with no agentType —
                # a silent fallback to a write-capable default agent, which is the one way
                # Law 2 dies here. Leave the expression intact so the token counter sees it.
                if quote == "`" and depth == 0 and ch == "$" and i + 1 < n and src[i + 1] == "{":
                    i += 2                       # keep `${` verbatim
                    depth = 1
                    continue
                if depth > 0:
                    if ch == "{":
                        depth += 1
                    elif ch == "}":
                        depth -= 1
                    i += 1                       # keep interpolated code verbatim
                    continue
                if ch == quote:
                    out[i] = " "
                    i += 1
                    break
                if ch != "\n":
                    out[i] = " "
                i += 1
        else:
            i += 1
    return "".join(out)


def check_agent_files(agents_dir: Path, names: list[str]) -> list[str]:
    """Every dispatchable agent must declare tools: ⊆ SAFE_TOOLS."""
    errs: list[str] = []
    for name in names:
        path = agents_dir / f"{name}.md"
        if not path.is_file():
            errs.append(f"agent file missing: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        m = re.search(r"^tools:\s*(.+)$", text, re.MULTILINE)
        if not m:
            errs.append(f"{path}: no `tools:` frontmatter — an agent with no allowlist "
                        f"inherits everything, including Bash")
            continue
        declared = {t.strip() for t in m.group(1).split(",") if t.strip()}
        unsafe = declared - SAFE_TOOLS
        if unsafe:
            errs.append(f"{path}: tools outside the safe set: {sorted(unsafe)}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("script", type=Path)
    ap.add_argument("--mode", choices=["audit", "smoke"], default="audit")
    ap.add_argument("--agents-dir", type=Path, default=Path(".claude/agents"))
    args = ap.parse_args()

    if not args.script.is_file():
        print(f"[check-law2] RED: script not found: {args.script}", file=sys.stderr)
        return 1

    src = args.script.read_text(encoding="utf-8")
    code = strip_js_noise(src)

    if args.mode == "audit":
        helpers, agents, expect = CANONICAL_HELPERS, ["plugin-auditor", "audit-refuter"], 2
    else:
        helpers, agents, expect = CANONICAL_SMOKE, ["smoke-probe"], 1

    errs: list[str] = []

    hits = list(AGENT_TOKEN.finditer(code))
    if len(hits) != expect:
        lines = sorted({code[: h.start()].count("\n") + 1 for h in hits})
        errs.append(
            f"identifier `agent` appears {len(hits)}x (expected exactly {expect}) "
            f"on lines {lines} — every dispatch must go through the pinned helper(s)"
        )

    # Each occurrence must sit on a pinned helper line, matched byte-for-byte on the
    # ORIGINAL source (not the noise-stripped copy).
    src_lines = src.splitlines()
    for h in hits:
        lineno = code[: h.start()].count("\n")
        actual = src_lines[lineno] if lineno < len(src_lines) else ""
        if actual.strip() not in helpers:
            errs.append(
                f"line {lineno + 1}: `agent` used outside a pinned helper:\n"
                f"    got:      {actual.strip()!r}\n"
                f"    expected: one of {[h_ for h_ in helpers]}"
            )

    for want in helpers:
        if not any(l.strip() == want for l in src_lines):
            errs.append(f"pinned helper line missing (byte-exact match required):\n    {want}")

    errs.extend(check_agent_files(args.agents_dir, agents))

    if errs:
        print(f"[check-law2] RED — {args.script} ({args.mode})", file=sys.stderr)
        for e in errs:
            print(f"  ✗ {e}", file=sys.stderr)
        return 1

    print(f"[check-law2] GREEN — {args.script} ({args.mode}): "
          f"`agent` x{expect}, all via pinned helpers; agents {agents} tools ⊆ {sorted(SAFE_TOOLS)}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
