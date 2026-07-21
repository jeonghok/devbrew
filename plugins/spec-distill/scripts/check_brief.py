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
  check_brief.py coverage <brief>            → {"failures": [...]}       (AC2/C9)
  check_brief.py frontmatter <brief>         → {"errors": [...]}         (AC1)
  check_brief.py gate <brief>                → {"pass": bool, "failures": [...]}
                                               exit 0 if pass else 1
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


def _web_disabled() -> bool:
    """AC8 graceful degradation: when web research is killed, URLs cannot be
    obtained, so the gate relaxes the citation requirement on §3/§4 (the SKILL's
    R2/R3 web-absent clauses). The judgment of whether the (URL-less) skepticism
    is genuine stays V10 manual."""
    return os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1"

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
URL_RE = re.compile(r"https?://\S+")
VALID_VERDICTS = ("defended", "switched", "deferred")
# Fenced code blocks are illustrative, not authored content — strip them before
# section/entry detection so headers quoted inside ``` cannot satisfy the gate (F4).
FENCE_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)

SECTIONS = [
    ("1", "Reframed Problem"),
    ("2", "Locked Directions"),
    ("3", "External Landscape"),
    ("4", "Skepticism Log"),
    ("5", "Blind Spots & Premortem"),
    ("6", "Coverage Ledger"),
    ("7", "Tried & Discarded"),
    ("8", "Open Questions"),
    ("9", "Concrete Next Action"),
]

FLOOR_KEYS = ["root_problem", "landscape", "skepticism", "blind_spot", "open_questions"]


def _body(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    body = text[m.end():] if m else text
    return FENCE_RE.sub("", body)


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
    if _web_disabled():
        return []  # web off → no URLs obtainable; citation requirement relaxed (AC8)
    sec = _section_text(text, "3", "External Landscape")
    return [ln for ln in _entry_lines(sec) if not URL_RE.search(ln)]


def landscape_present(text: str) -> bool:
    """§3 External Landscape must carry >=1 entry, OR an explicit web-disabled
    sentinel (AC8 graceful degradation). An empty §3 means no landscape was
    surfaced — R2 unmet. Header presence alone is not research (F3)."""
    sec = _section_text(text, "3", "External Landscape").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b|비활성|생략|web[ -]?disabled", sec, re.IGNORECASE):
        return True
    return bool(_entry_lines(sec))


def steelman_unlogged(text: str) -> int:
    """Count locked directions whose frontmatter claims a steelman outcome
    (`defended` / `switched-to-this`) but which have no corresponding §4
    Skepticism Log entry. The brief template requires every suspicion-triggered
    direction to log a §4 entry; this enforces the count. Whether the entry is a
    genuine counter-argument stays V10 manual (F6)."""
    m = FRONTMATTER_RE.match(text)
    fm = m.group(1) if m else ""
    claimed = len(re.findall(
        r"^\s*steelman\s*:\s*(?:defended|switched-to-this)\s*$", fm, re.MULTILINE))
    logged = len(_entry_lines(_section_text(text, "4", "Skepticism Log")))
    return max(0, claimed - logged)


def skepticism_malformed(text: str) -> list[str]:
    sec = _section_text(text, "4", "Skepticism Log")
    require_url = not _web_disabled()  # AC8: web off → user-judgment skepticism may lack a URL
    bad: list[str] = []
    for ln in _entry_lines(sec):
        has_url = bool(URL_RE.search(ln))
        has_verdict = any(v in ln.lower() for v in VALID_VERDICTS)
        stripped = URL_RE.sub("", ln).lstrip("- ").strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and (has_url or not require_url)):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if require_url and not has_url:
                miss.append("no-url")
            if not has_verdict:
                miss.append("no-verdict")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


def tried_discarded_ok(text: str) -> bool:
    sec = _section_text(text, "7", "Tried & Discarded").strip()
    if not sec:
        return False
    if re.search(r"\bN/?A\b", sec, re.IGNORECASE):
        return True  # explicit "N/A — 전부 first-time defend+lock" sentinel (R4 edge)
    return bool(_entry_lines(sec))


def coverage_ledger_failures(text: str) -> list[str]:
    """§6 Coverage Ledger form 검증 (C9 직렬화 / AC2 / AC3).
    Form-level only (C2): floor 5행 각 존재 + status 토큰 'closed' + evidence 세그먼트
    non-empty; derived는 >=1 derived 행 OR N/A sentinel. 'closed'가 실질적으로 참인지는
    검사하지 않는다(모델 + 독립 adversary의 몫 — 게이트는 이 한계를 숨기지 않는다)."""
    sec = _section_text(text, "6", "Coverage Ledger")
    if not sec.strip():
        return ["Coverage Ledger empty or absent"]
    fails: list[str] = []
    floor_rows: dict[str, tuple[str, str]] = {}
    derived_rows = 0
    derived_sentinel = False
    for ln in _entry_lines(sec):
        body = ln.lstrip("- ").strip()
        fm = re.match(r"^floor:(\w+)\s*—\s*(\S+)\s*—\s*(.*)$", body)
        if fm:
            floor_rows[fm.group(1)] = (fm.group(2).strip(), fm.group(3).strip())
            continue
        if re.match(r"^derived:\s*N/?A\b", body, re.IGNORECASE):
            derived_sentinel = True
            continue
        if body.startswith("derived:"):
            derived_rows += 1
    for key in FLOOR_KEYS:
        if key not in floor_rows:
            fails.append(f"floor:{key} row missing")
            continue
        status, evidence = floor_rows[key]
        if status != "closed":
            fails.append(f"floor:{key} status {status!r} != closed")
        if not evidence:
            fails.append(f"floor:{key} evidence empty")
    if derived_rows == 0 and not derived_sentinel:
        fails.append("derived: no derived row and no N/A sentinel")
    return fails


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
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"pass": False, "failures": [f"brief unreadable: {exc}"]},
                         ensure_ascii=False))
        return 1
    failures: list[str] = []
    miss = find_missing_sections(text)
    if miss:
        failures.append(f"missing sections: {miss}")
    fe = frontmatter_errors(text)
    if fe:
        failures.append(f"frontmatter: {fe}")
    # Only check §3 content when the section exists; absence is already in miss.
    sec3_absent = any(m.startswith("3.") for m in miss)
    if not sec3_absent and not landscape_present(text):
        failures.append("External Landscape empty (no entries and no web-disabled sentinel)")
    unc = landscape_uncited(text)
    if unc:
        failures.append(f"uncited landscape entries: {len(unc)}")
    mal = skepticism_malformed(text)
    if mal:
        failures.append(f"malformed skepticism entries: {len(mal)}")
    shortfall = steelman_unlogged(text)
    if shortfall:
        failures.append(
            f"{shortfall} steelman-claimed direction(s) without a §4 Skepticism Log entry")
    # §7 Tried & Discarded 내용은 섹션이 존재할 때만 검사(부재는 이미 miss에 있음).
    sec7_absent = any(m.startswith("7.") for m in miss)
    if not sec7_absent and not tried_discarded_ok(text):
        failures.append("Tried & Discarded empty (no entries and no N/A sentinel)")
    # §6 Coverage Ledger 내용은 섹션이 존재할 때만 검사(부재는 이미 miss에 있음).
    sec6_absent = any(m.startswith("6.") for m in miss)
    if not sec6_absent:
        cov = coverage_ledger_failures(text)
        if cov:
            failures.append(f"coverage ledger: {cov}")
    ok = not failures
    print(json.dumps({"pass": ok, "failures": failures}, ensure_ascii=False))
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: check_brief.py <subcommand> <brief.md>", file=sys.stderr)
        return 64
    sub, path = argv[1], Path(argv[2])
    if sub == "gate":
        return gate(path)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"brief unreadable: {exc}", file=sys.stderr)
        return 1
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
    if sub == "coverage":
        print(json.dumps({"failures": coverage_ledger_failures(text)}, ensure_ascii=False))
        return 0
    if sub == "frontmatter":
        print(json.dumps({"errors": frontmatter_errors(text)}, ensure_ascii=False))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
