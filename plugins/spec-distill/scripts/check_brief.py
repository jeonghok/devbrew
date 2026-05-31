#!/usr/bin/env python3
"""spec-distill — interview brief structural gate (AC2/AC4/AC5, V2/V3/V6, PN4).

The Law 1 termination gate for the conducting-interview problem-space stage,
made mechanical. conducting-interview runs `check_brief.py gate <brief>` before
finalizing the brief / before any optional brainstorming invoke; a non-zero exit
BLOCKS termination (one of the 5 통과 의례 unmet).

This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review. It is a
structural self-check (Law 1), analogous to parse_spec_structure.py for specs.

PN4: the steelman "verbatim" guarantee is checked by substring containment — each
Skepticism Log entry must contain >=1 URL + a >=10-char statement + a valid
verdict — NOT exact-string match (avoids flakiness). Whether the steelman is a
genuine counter-argument is V10 manual.

CLI subcommands (all print JSON):
  check_brief.py sections <brief>            → {"missing": [...]}        (AC2)
  check_brief.py landscape-citations <brief> → {"uncited": [...]}        (AC4/V6)
  check_brief.py skepticism <brief>          → {"malformed": [...]}      (AC5/V3)
  check_brief.py tried-discarded <brief>     → {"ok": bool}              (V2/R4)
  check_brief.py frontmatter <brief>         → {"errors": [...]}         (AC1)
  check_brief.py gate <brief>                → {"pass": bool, "failures": [...]}
                                               exit 0 if pass else 1
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
URL_RE = re.compile(r"https?://\S+")
VALID_VERDICTS = ("defended", "switched", "deferred")

SECTIONS = [
    ("1", "Reframed Problem"),
    ("2", "Locked Directions"),
    ("3", "External Landscape"),
    ("4", "Skepticism Log"),
    ("5", "Tried & Discarded"),
    ("6", "Open Questions"),
    ("7", "Concrete Next Action"),
]


def _body(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    return text[m.end():] if m else text


def find_missing_sections(text: str) -> list[str]:
    body = _body(text)
    missing = []
    for num, title in SECTIONS:
        pat = re.compile(
            rf"^##\s+{num}\.\s+{re.escape(title)}\b",
            re.MULTILINE | re.IGNORECASE,
        )
        if not pat.search(body):
            missing.append(f"{num}. {title}")
    return missing


def _section_text(text: str, num: str, title: str) -> str:
    body = _body(text)
    start = re.search(
        rf"^##\s+{num}\.\s+{re.escape(title)}\b", body, re.MULTILINE | re.IGNORECASE
    )
    if not start:
        return ""
    rest = body[start.end():]
    nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
    return rest[: nxt.start()] if nxt else rest


def _entry_lines(section: str) -> list[str]:
    return [
        ln.strip()
        for ln in section.splitlines()
        if ln.lstrip().startswith("- ") and ln.strip() != "-"
    ]


def landscape_uncited(text: str) -> list[str]:
    sec = _section_text(text, "3", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not URL_RE.search(ln)]


def skepticism_malformed(text: str) -> list[str]:
    sec = _section_text(text, "4", "Skepticism Log")
    bad: list[str] = []
    for ln in _entry_lines(sec):
        has_url = bool(URL_RE.search(ln))
        has_verdict = any(v in ln.lower() for v in VALID_VERDICTS)
        stripped = URL_RE.sub("", ln).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_url and has_verdict and has_stmt):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


def tried_discarded_ok(text: str) -> bool:
    sec = _section_text(text, "5", "Tried & Discarded").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b", sec, re.IGNORECASE):
        return True  # explicit "N/A — 전부 first-time defend+lock" sentinel (R4 edge)
    return bool(_entry_lines(sec))


def frontmatter_errors(text: str) -> list[str]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return ["frontmatter absent"]
    fm = m.group(1)
    errs: list[str] = []
    if not re.search(r"^type:\s*interview-brief\s*$", fm, re.MULTILINE):
        errs.append("type != interview-brief")
    if not re.search(r"^next_phase:\s*superpowers:brainstorming\s*$", fm, re.MULTILINE):
        errs.append("next_phase != superpowers:brainstorming")
    if not re.search(r"^locked_directions\s*:", fm, re.MULTILINE):
        errs.append("locked_directions key absent")
    return errs


def gate(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    failures: list[str] = []
    miss = find_missing_sections(text)
    if miss:
        failures.append(f"missing sections: {miss}")
    fe = frontmatter_errors(text)
    if fe:
        failures.append(f"frontmatter: {fe}")
    unc = landscape_uncited(text)
    if unc:
        failures.append(f"uncited landscape entries: {len(unc)}")
    mal = skepticism_malformed(text)
    if mal:
        failures.append(f"malformed skepticism entries: {len(mal)}")
    # Only check content of §5 when the section exists; absence is already in miss.
    sec5_absent = any("5." in m for m in miss)
    if not sec5_absent and not tried_discarded_ok(text):
        failures.append("Tried & Discarded empty (no entries and no N/A sentinel)")
    ok = not failures
    print(json.dumps({"pass": ok, "failures": failures}, ensure_ascii=False))
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: check_brief.py <subcommand> <brief.md>", file=sys.stderr)
        return 64
    sub, path = argv[1], Path(argv[2])
    text = path.read_text(encoding="utf-8")
    if sub == "sections":
        print(json.dumps({"missing": find_missing_sections(text)}, ensure_ascii=False))
        return 0
    if sub == "landscape-citations":
        print(json.dumps({"uncited": landscape_uncited(text)}, ensure_ascii=False))
        return 0
    if sub == "skepticism":
        print(json.dumps({"malformed": skepticism_malformed(text)}, ensure_ascii=False))
        return 0
    if sub == "tried-discarded":
        print(json.dumps({"ok": tried_discarded_ok(text)}, ensure_ascii=False))
        return 0
    if sub == "frontmatter":
        print(json.dumps({"errors": frontmatter_errors(text)}, ensure_ascii=False))
        return 0
    if sub == "gate":
        return gate(path)
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
