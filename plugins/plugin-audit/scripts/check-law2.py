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

It is a **best-effort early warning**, not the physical guarantee. Four independent reviewers
(codex twice, two Claude lenses) drove the point home: a static counter cannot catch every way
JS can reach `agent`. It handles the *known* lexical dodges — spacing, optional-call, alias,
`.call`, spread-order, template interpolation, unicode escapes, regex literals, and the four
ECMAScript line terminators in `//` comments (interpolation/regex/unicode are *refused*, not
tokenized around). It does **not** claim to handle every lexical trick — the U+2028-in-comment
dodge was live until a reviewer reproduced it with Node (ledger 41) — and **dynamic dispatch is
out of reach and always will be**: `globalThis['agent']`, `globalThis['ag'+'ent']`,
`eval("agent(p,{})")`. Chasing those with more static analysis is the enumeration game with no end
(ledger 39) — and, per devbrew's own Gate F, a cure worse than the disease.

**The physical Law 2 guarantee is three layers, none of which is this file — but read the residual:**
  (a) the agent files' `tools:` allowlist — no Bash means an interpreted agent *cannot* write;
  (b) the pre-0 smoke — a sentinel file proves on disk whether a probe can actually write;
  (c) the integrity snapshot — if any agent writes anything IN THE REPO, BEFORE≠AFTER catches it.
This gate catches the *honest mistake* (we forgot an agentType) early, before 30 agents spin up.
**Residual, stated honestly (a reviewer's point):** a dispatch with NO agentType falls back to a
write-capable default agent, so (a) has no allowlist to apply; and (c) is a file hash, so a fallen-
back agent doing *network* actions (WebFetch exfiltration, no local write) leaves no delta for (c)
to see. For that specific path — agentType-less dispatch + network-only action — this static gate
is in fact the first and best-positioned line, which is why closing the *known* lexical holes is
load-bearing even though the gate is "best-effort." The residual beyond the known holes is real.

Counting *identifiers*, not syntax. `\\bagent\\(` — the obvious predicate — is defeated
five different ways, all legal JS:

    agent (p, {})            space between callee and paren
    agent?.(p, {})           optional call
    const go = agent; go(p)  alias
    agent.call(null, p, {})  .call
    {agentType: 'x', ...opts}   spread order reversed → caller's opts.agentType wins

The first four change the identifier count (2 → 3), so counting `agent` as a token catches
them. The fifth does not, so the two helper lines are pinned by content (leading/trailing whitespace ignored).

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

# The audit workflow's only two dispatch sites. Pinned by line content (leading/trailing whitespace ignored).
# The spread comes FIRST so agentType cannot be overridden by a caller's opts.
CANONICAL_HELPERS = [
    "const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:plugin-auditor'})",
    "const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:audit-refuter'})",
]
CANONICAL_SMOKE = [
    "const probe = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:smoke-probe'})",
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
    sees only code.

    Deliberately SIMPLE, not clever. An earlier version tried to recursively parse template
    interpolations to keep any `${ agent(...) }` visible; codex then broke it three ways
    (`${"}", agent}`, a comment inside `${}`, and `a++ / b` misread as regex). That is the
    endless enumeration game (ledger 39, 41). The measured fact settles it: the real
    audit-workflow.js has ZERO `/` and ZERO `${}` in code. So we do not parse those cases —
    we REFUSE them:

      - `${` inside a template literal  → BypassError  (would-be interpolation; kills the
                                          `${agent(...)}` and `${"}", agent}` dodges at once)
      - a bare `/` in code (not // or /*) → BypassError (regex-vs-division ambiguity; a
                                          workflow we author needs neither)
      - `\\` (unicode/char escape) in code → BypassError (how `ag\\u0065nt` hid)

    A construct the checker will not cheaply reason about is a RED, not a silent pass.
    Template literals are otherwise blanked exactly like '...' and "..." strings.
    """
    out = list(src)
    n = len(src)
    i = 0
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if c == "/" and nxt == "/":                       # line comment — legitimate
            # ECMAScript defines FOUR line terminators, not one. A `//` comment ends at any of
            # \n \r U+2028 U+2029. Checking only \n let a dispatch hide after a U+2028 inside a
            # comment: Node ends the comment there and RUNS `agent(...)`, while a \n-only stripper
            # thinks the comment continues and blanks the call → GREEN. Reproduced with Node.
            # (Claude regression lens, r14-6.) This is a lexical dodge — the docstring's claim of
            # covering the lexical dodges was false until this line.
            while i < n and src[i] not in ("\n", "\r", "\u2028", "\u2029"):
                out[i] = " "
                i += 1
        elif c == "/" and nxt == "*":                     # block comment — legitimate
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
        elif c == "/":                                    # bare slash = regex or division
            raise BypassError(f"bare '/' (regex or division) at offset {i} — "
                              f"a workflow we author uses neither")
        elif c == "\\":                                   # unicode/char escape in code
            raise BypassError(f"'\\' escape in code at offset {i}")
        elif c in "'\"`":
            quote = c
            out[i] = " "
            i += 1
            while i < n:
                ch = src[i]
                if ch == "\\":                            # escape inside string — blank both
                    if src[i] != "\n":
                        out[i] = " "
                    if i + 1 < n and src[i + 1] != "\n":
                        out[i + 1] = " "
                    i += 2
                    continue
                if quote == "`" and ch == "$" and i + 1 < n and src[i + 1] == "{":
                    raise BypassError(f"template interpolation `${{` at offset {i} — "
                                      f"a dispatch could hide inside it; not parsed, refused")
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
        # tools: MUST live in the frontmatter block (between the first two `---`). A body
        # `tools:` mention is not the allowlist the runtime reads — treating it as one lets a
        # frontmatter-less agent pass while the runtime grants default (write-capable) tools
        # (codex #5, Law 2 hole).
        fm = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
        block = fm.group(1) if fm else ""
        m = re.search(r"^tools:\s*(.+)$", block, re.MULTILINE)
        if not m:
            errs.append(f"{path}: no `tools:` in frontmatter — an agent with no allowlist "
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
    ap.add_argument("--agents-dir", type=Path, default=Path("plugins/plugin-audit/agents"))
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

    # Each occurrence must sit on a pinned helper line, matched by content (leading/trailing whitespace ignored)
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
            errs.append(f"pinned helper line missing (content match, leading/trailing whitespace ignored):\n    {want}")

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
