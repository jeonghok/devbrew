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

## What this gate is, and is NOT.

It is a **best-effort early warning**, not the physical guarantee. Three independent reviewers
(codex twice, a Claude lens once) drove the point home: a static counter cannot catch every way
JS can reach `agent`. It handles the *lexical* dodges — spacing, optional-call, alias, `.call`,
spread-order, template interpolation, unicode escapes, regex literals (the last two are *refused*,
not tokenized around) — but **dynamic dispatch is out of reach and always will be**:
`globalThis['agent']`, `globalThis['ag'+'ent']`, `eval("agent(p,{})")`. Trying to catch those with
more static analysis is the enumeration game with no end (handoff ledger 39) — and, per devbrew's
own Gate F, a cure worse than the disease.

**The real, physical Law 2 guarantee is three layers, none of which is this file:**
  (a) the agent files' `tools:` allowlist — no Bash means an interpreted agent *cannot* write;
  (b) the pre-0 smoke — a sentinel file proves on disk whether a probe can actually write;
  (c) the integrity snapshot — if any agent writes anything, BEFORE≠AFTER catches it, with rollback.
This gate exists to catch the *honest mistake* (we forgot an agentType) early and cheaply, before
30 agents spin up. It does not pretend to stop a determined obfuscator, because layers (a)–(c) do.

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


class BypassError(Exception):
    """Raised when the source contains a construct this checker refuses to reason about.

    A regex literal or a unicode identifier escape is not something the audit workflow — a
    file WE author — has any reason to contain. Rather than try to tokenize around them
    (that is the losing enumeration game: codex found `${"}", agent(p,{})}` and `ag\\u0065nt`
    inside the previous "fix"), we refuse them outright. A construct the checker cannot
    reason about is a RED, not a silent pass.
    """


def strip_js_noise(src: str) -> str:
    """Blank comments and string *text*, preserving offsets and lines, so the token counter
    sees only code. Template `${...}` interpolations are code and are kept verbatim —
    RECURSIVELY, because a string inside an interpolation is text again and its braces must
    not be counted (codex: `${"}", agent(p,{})}` slipped through a flat brace counter).

    Refuses (BypassError) two constructs it cannot safely tokenize:
      - unicode escapes in code (`\\uXXXX`) — how `ag\\u0065nt` hid from the regex
      - regex literals — `/agent/` would otherwise inject a phantom token
    Neither has any business in a workflow we author.
    """
    out = list(src)
    n = len(src)

    def blank_range(a: int, b: int):
        for k in range(a, b):
            if src[k] != "\n":
                out[k] = " "

    # Consume a string starting at `i` (src[i] in quotes). For a template literal, recurse
    # into each ${...} so nested strings are stripped and only real code braces are seen.
    def consume_string(i: int) -> int:
        quote = src[i]
        out[i] = " "
        i += 1
        while i < n:
            ch = src[i]
            if ch == "\\":
                blank_range(i, min(i + 2, n))
                i += 2
                continue
            if quote == "`" and ch == "$" and i + 1 < n and src[i + 1] == "{":
                i += 2                       # keep `${` verbatim — it is a code boundary
                i = consume_interp(i)        # recurse: strip strings, count real braces
                continue
            if ch == quote:
                out[i] = " "
                return i + 1
            if ch != "\n":
                out[i] = " "
            i += 1
        return i

    # Inside a ${...}: keep code verbatim, but recurse into nested strings/templates, and
    # stop at the brace that closes THIS interpolation (depth tracked over real braces only).
    def consume_interp(i: int) -> int:
        depth = 1
        while i < n:
            ch = src[i]
            if ch in "'\"`":
                i = consume_string(i)        # nested string — its braces don't count
                continue
            if ch == "\\":
                raise BypassError(f"unicode/char escape in code at offset {i}")
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        return i

    i = 0
    prev_significant = ""     # last non-space code char — distinguishes /regex/ from division
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
        elif c == "/" and nxt == "*":
            j = i + 2
            while j < n and not (src[j] == "*" and j + 1 < n and src[j + 1] == "/"):
                j += 1
            blank_range(i, min(j + 2, n))
            i = j + 2
        elif c == "/" and prev_significant in ("", "(", ",", "=", ":", "[", "!", "&", "|",
                                               "?", "{", ";", "+", "-", "*", "%", "<", ">",
                                               "~", "^", "\n"):
            # A regex literal in a file we author is refused, not tokenized around.
            raise BypassError(f"regex literal at offset {i}")
        elif c in "'\"`":
            i = consume_string(i)
            prev_significant = "'"
        elif c == "\\":
            raise BypassError(f"unicode/char escape in code at offset {i}")
        else:
            if not c.isspace():
                prev_significant = c
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
    try:
        code = strip_js_noise(src)
    except BypassError as e:
        print(f"[check-law2] RED — {args.script} ({args.mode}): "
              f"refused construct the checker will not tokenize around — {e}.\n"
              f"  A workflow we author has no reason to use unicode identifier escapes or "
              f"regex literals; they are exactly how a dispatch hides from a static counter.",
              file=sys.stderr)
        return 1

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
