#!/usr/bin/env python3
"""CLAUDE.md restructure audit — see spec at docs/superpowers/specs/2026-05-07-claude-md-restructure-audit-design.md"""

from __future__ import annotations
import re, sys
from pathlib import Path
from dataclasses import dataclass
from difflib import get_close_matches
from collections import defaultdict

REPO_ROOT = Path(__file__).resolve().parents[3]
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
PHILOSOPHY = REPO_ROOT / "docs/philosophy/devbrew-harness-philosophy.md"
REPORT_PATH = REPO_ROOT / "docs/superpowers/reports/2026-05-07-claude-md-audit.md"

LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)#]+)(?:#([^)]+))?\)")
HEADING_RE = re.compile(r"^(#+)\s+(.+?)\s*$", re.MULTILINE)
TOKEN_RE = re.compile(r"(?:\b(Law [1-3]|P[0-9]+|AP[0-9]+)|(§[0-9]+(?:\.[0-9]+)?))")

COUNT_PATTERNS = {
    "principles":    re.compile(r"^### P\d+\.", re.MULTILINE),
    "anti_patterns": re.compile(r"^### AP\d+\.", re.MULTILINE),
    "primitives":    re.compile(r"^### 4\.\d+", re.MULTILINE),
    "tensions":      re.compile(r"^### 5\.\d+", re.MULTILINE),
}


@dataclass
class Finding:
    kind: str  # BROKEN_LINK | BROKEN_ANCHOR | UNRESOLVED_CITATION | COUNT_DRIFT | MISSING_SOURCE_SENTINEL
    file: str
    line: int
    detail: str
    auto_fix: tuple[int, int, str] | None = None  # (start, end, replacement) on original line


def extract_links(text: str) -> list[tuple[str, str, str | None, int]]:
    """Return [(text, path, anchor, line_no), ...]; http(s) URL은 skip."""
    out = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for m in LINK_RE.finditer(line):
            text_, path, anchor = m.group(1), m.group(2), m.group(3)
            if path.startswith(("http://", "https://")):
                continue
            out.append((text_, path, anchor, line_no))
    return out


def slugify(heading: str) -> str:
    """GitHub-flavored heading slug: lowercase, spaces→-, drop non-alnum/non-CJK except '-'."""
    s = heading.lower().strip()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s)
    return s


def _levenshtein(a: str, b: str) -> int:
    if len(a) < len(b):
        a, b = b, a
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i] + [0] * len(b)
        for j, cb in enumerate(b, 1):
            cost = 0 if ca == cb else 1
            cur[j] = min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
        prev = cur
    return prev[-1]


def extract_tokens(text: str) -> list[tuple[str, int]]:
    """Return [(token, line_no), ...] for all Law/P##/AP##/§X.Y citations."""
    out = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for m in TOKEN_RE.finditer(line):
            tok = m.group(1) or m.group(2)
            out.append((tok, line_no))
    return out


def collect_token_anchors(philosophy_text: str) -> set[str]:
    """Philosophy.md heading에서 Law/P##/AP##/§X(.Y) 토큰을 추출."""
    anchors: set[str] = set()
    for m in HEADING_RE.finditer(philosophy_text):
        depth = len(m.group(1))
        title = m.group(2)
        if depth == 3:
            for prefix in ("Law 1", "Law 2", "Law 3"):
                if title.startswith(prefix):
                    anchors.add(prefix)
            m2 = re.match(r"^(P\d+|AP\d+)\.", title)
            if m2:
                anchors.add(m2.group(1))
            m4 = re.match(r"^(\d+\.\d+)\b", title)
            if m4:
                anchors.add(f"§{m4.group(1)}")
        if depth == 2:
            m3 = re.match(r"^(\d+)\.", title)
            if m3:
                anchors.add(f"§{m3.group(1)}")
    return anchors


def collect_anchors(text: str) -> set[str]:
    return {slugify(m.group(2)) for m in HEADING_RE.finditer(text)}


def run_anchor_pass(claude_md_text: str) -> list[Finding]:
    findings = []
    lines = claude_md_text.splitlines()
    for text_, path, anchor, line_no in extract_links(claude_md_text):
        target = REPO_ROOT / path
        if not target.exists():
            findings.append(Finding(
                "BROKEN_LINK", "CLAUDE.md", line_no, f"{path} (text: {text_})",
            ))
            continue
        if anchor is None or target.suffix.lower() != ".md":
            continue
        anchors = collect_anchors(target.read_text())
        if anchor not in anchors:
            close = get_close_matches(anchor, anchors, n=1, cutoff=0.7)
            if close and _levenshtein(anchor, close[0]) <= 2:
                # Find #anchor's position in the source line
                line_text = lines[line_no - 1]
                old_frag = "#" + anchor
                pos = line_text.find(old_frag)
                if pos >= 0:
                    auto_fix = (pos, pos + len(old_frag), "#" + close[0])
                    detail = f"{path}#{anchor} → #{close[0]}"
                else:
                    auto_fix = None
                    detail = f"{path}#{anchor}"
            else:
                auto_fix = None
                detail = f"{path}#{anchor}"
            findings.append(Finding(
                "BROKEN_ANCHOR", "CLAUDE.md", line_no, detail, auto_fix=auto_fix,
            ))
    return findings


def run_citation_pass(claude_md_text: str, philosophy_text: str) -> list[Finding]:
    valid = collect_token_anchors(philosophy_text)
    seen: set[str] = set()
    findings = []
    for tok, line_no in extract_tokens(claude_md_text):
        if tok in seen:
            continue
        seen.add(tok)
        if tok not in valid:
            findings.append(Finding("UNRESOLVED_CITATION", "CLAUDE.md", line_no, tok))
    return findings


SENTINEL_NAMES = ["OMC", "gstack", "Ouroboros", "CE"]
SENTINEL_CLAIM_RE = re.compile(r"네\s*소스|four\s*sources?|4\s*소스")
SECTION_6_RE = re.compile(r"^## 6\.[\s\S]+?(?=^## 7\.|\Z)", re.MULTILINE)


def run_sentinel_pass(claude_md_text: str, philosophy_text: str) -> list[Finding]:
    if not SENTINEL_CLAIM_RE.search(claude_md_text):
        return []
    sec6 = SECTION_6_RE.search(philosophy_text)
    if not sec6:
        return [Finding(
            "MISSING_SOURCE_SENTINEL", "philosophy.md", 0,
            "§6 (Attribution Map) not found",
        )]
    body = sec6.group(0)
    missing = [name for name in SENTINEL_NAMES if name not in body]
    if missing:
        return [Finding(
            "MISSING_SOURCE_SENTINEL", "philosophy.md", 0,
            f"missing from §6: {', '.join(missing)}",
        )]
    return []


CLAIM_PATTERNS = [
    ("principles",    re.compile(r"(\d+)\s*개?\s*원칙")),
    ("anti_patterns", re.compile(r"(\d+)\s*개?\s*anti-pattern")),
    ("primitives",    re.compile(r"(\d+)\s*개?\s*primitive")),
    ("tensions",      re.compile(r"(\d+)\s*개?\s*tension")),
]


def count_actual(kind: str, philosophy_text: str) -> int:
    return len(COUNT_PATTERNS[kind].findall(philosophy_text))


def run_count_pass(claude_md_text: str, philosophy_text: str) -> list[Finding]:
    findings = []
    for kind, pat in CLAIM_PATTERNS:
        actual = count_actual(kind, philosophy_text)
        for line_no, line in enumerate(claude_md_text.splitlines(), start=1):
            for m in pat.finditer(line):
                claimed = int(m.group(1))
                if claimed != actual:
                    findings.append(Finding(
                        "COUNT_DRIFT", "CLAUDE.md", line_no,
                        f"{kind}: claimed={claimed} actual={actual}",
                        auto_fix=(m.start(1), m.end(1), str(actual)),  # patch only the captured number
                    ))
    return findings


def apply_auto_fixes(text: str, findings: list[Finding]) -> str:
    """Compose all per-line patches from findings. Sort right-to-left within a line so earlier offsets remain valid."""
    by_line: dict[int, list[tuple[int, int, str]]] = defaultdict(list)
    for f in findings:
        if f.auto_fix is None:
            continue
        by_line[f.line].append(f.auto_fix)

    lines = text.splitlines(keepends=True)
    for line_no, patches in by_line.items():
        idx = line_no - 1
        if not (0 <= idx < len(lines)):
            continue
        line = lines[idx]
        # Sort right-to-left so leftward offsets remain stable
        for start, end, repl in sorted(patches, key=lambda p: -p[0]):
            line = line[:start] + repl + line[end:]
        lines[idx] = line
    return "".join(lines)


REPORT_TEMPLATE = """# CLAUDE.md Audit — 2026-05-07

**Scope:** CLAUDE.md ↔ docs/philosophy/devbrew-harness-philosophy.md
**Restructure context:** Validates commits c9e758d, c51d270, a65bbab.

## Summary

- Pass 1 (Anchor): {n_link} broken-link, {n_anchor} broken-anchor ({n_anchor_fixed} auto-fixed)
- Pass 2 (Citation): {n_cit} findings (report-only)
- Pass 3a (Count): {n_count} findings ({n_count_fixed} auto-fixed)
- Pass 3b (Source sentinel): {n_sentinel} findings (report-only)

## Findings

### BROKEN_LINK
{broken_link}

### BROKEN_ANCHOR
{broken_anchor}

### UNRESOLVED_CITATION
{unresolved}

### COUNT_DRIFT
{count_drift}

### MISSING_SOURCE_SENTINEL
{sentinel}
"""


def _section(findings: list[Finding], kind: str) -> str:
    rows = [f for f in findings if f.kind == kind]
    if not rows:
        return "(no findings)"
    out = []
    for f in rows:
        marker = " **Auto-fixed**" if f.auto_fix else ""
        out.append(f"- `{f.file}:{f.line}` — {f.detail}{marker}")
    return "\n".join(out)


def render_report(findings: list[Finding]) -> str:
    auto_fixed = lambda kind: sum(1 for f in findings if f.kind == kind and f.auto_fix)
    of_kind = lambda kind: sum(1 for f in findings if f.kind == kind)
    return REPORT_TEMPLATE.format(
        n_link=of_kind("BROKEN_LINK"),
        n_anchor=of_kind("BROKEN_ANCHOR"),
        n_anchor_fixed=auto_fixed("BROKEN_ANCHOR"),
        n_cit=of_kind("UNRESOLVED_CITATION"),
        n_count=of_kind("COUNT_DRIFT"),
        n_count_fixed=auto_fixed("COUNT_DRIFT"),
        n_sentinel=of_kind("MISSING_SOURCE_SENTINEL"),
        broken_link=_section(findings, "BROKEN_LINK"),
        broken_anchor=_section(findings, "BROKEN_ANCHOR"),
        unresolved=_section(findings, "UNRESOLVED_CITATION"),
        count_drift=_section(findings, "COUNT_DRIFT"),
        sentinel=_section(findings, "MISSING_SOURCE_SENTINEL"),
    )


def main() -> int:
    claude = CLAUDE_MD.read_text()
    phil = PHILOSOPHY.read_text()
    findings = (
        run_anchor_pass(claude)
        + run_citation_pass(claude, phil)
        + run_count_pass(claude, phil)
        + run_sentinel_pass(claude, phil)
    )

    fixed = apply_auto_fixes(claude, findings)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(render_report(findings))

    if fixed != claude:
        CLAUDE_MD.write_text(fixed)
        print(f"Auto-fixes applied to {CLAUDE_MD}")
    print(f"Report written to {REPORT_PATH}")
    print(f"Total findings: {len(findings)}")
    print(f"Auto-fixed: {sum(1 for f in findings if f.auto_fix)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
