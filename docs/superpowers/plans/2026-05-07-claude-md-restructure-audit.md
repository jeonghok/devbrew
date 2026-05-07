# CLAUDE.md Restructure Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `CLAUDE.md` ↔ `docs/philosophy/devbrew-harness-philosophy.md` 사이의 citation/anchor/count drift를 검출·자동수정하는 one-shot audit을 구현하고 실행한다.

**Architecture:** Python 3 stdlib만 사용하는 단일 스크립트(`audit_claude_md.py`). 4개 검증 pass (anchor / citation / count / source-sentinel) → 구조화된 finding 생성 → auto-fix engine이 `COUNT_DRIFT`와 `BROKEN_ANCHOR` (Levenshtein ≤ 2) 처리 → markdown report 렌더링. 영구 기록은 `CLAUDE.md` auto-fix commit (보고서는 ephemeral).

**Tech Stack:** Python 3 (stdlib only — `re`, `pathlib`, `subprocess`, `difflib`, `unittest`).

**Spec와의 deviation 한 가지** (의도적, 명시):

1. **Bash → Python.** Spec은 `bash + standard tools`를 명시했으나 진짜 제약은 "no new dependencies"였음. Python stdlib는 macOS pre-installed로 의존성 추가 없음. Levenshtein·slugify·multi-pass orchestration이 bash보다 실용적으로 단순.

**Mid-flight update (2026-05-07):** Plan 초안은 `docs/superpowers/`가 gitignored임을 가정해 모든 artifact을 ephemeral로 다뤘으나, 사용자가 mid-flight으로 `.gitignore`에서 `superpowers/`와 `research/` 항목을 제거 → 이제 모든 artifact가 committable. Spec acceptance criterion #3 ("report exists and is committed")이 원래대로 충족 가능. Task 7 종료 시 "Add audit script + tests + spec + plan" preparatory commit, Task 9 종료 시 report commit으로 분리.

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `docs/superpowers/scripts/audit_claude_md.py` | Create | Audit driver — 4 passes, auto-fix, report render |
| `docs/superpowers/scripts/test_audit_claude_md.py` | Create | unittest 테스트 |
| `docs/superpowers/reports/2026-05-07-claude-md-audit.md` | Create (output) | 생성된 보고서 |
| `CLAUDE.md` | Modify | Auto-fix만 적용 — `COUNT_DRIFT`로 식별된 숫자 토큰만 |

Commit 분리:
- **Commit 1** (Task 7 종료): `chore: untrack docs/superpowers/ and add CLAUDE.md audit script` — `.gitignore` patch + spec + plan + script + tests
- **Commit 2** (Task 8 종료): `docs(claude-md): fix mechanical drift caught by audit` — `CLAUDE.md` auto-fix만
- **Commit 3** (Task 9 종료): `docs(audit): add CLAUDE.md restructure audit report (post-fix)` — 최종 report

---

### Task 1: 스크립트 scaffold + 테스트 인프라

**Files:**
- Create: `docs/superpowers/scripts/audit_claude_md.py`
- Create: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: Scaffold 작성**

`docs/superpowers/scripts/audit_claude_md.py`:
```python
#!/usr/bin/env python3
"""CLAUDE.md restructure audit — see spec at docs/superpowers/specs/2026-05-07-claude-md-restructure-audit-design.md"""

from __future__ import annotations
import re, sys
from pathlib import Path
from dataclasses import dataclass
from difflib import get_close_matches

REPO_ROOT = Path(__file__).resolve().parents[3]
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
PHILOSOPHY = REPO_ROOT / "docs/philosophy/devbrew-harness-philosophy.md"
REPORT_PATH = REPO_ROOT / "docs/superpowers/reports/2026-05-07-claude-md-audit.md"


@dataclass
class Finding:
    kind: str  # BROKEN_LINK | BROKEN_ANCHOR | UNRESOLVED_CITATION | COUNT_DRIFT | MISSING_SOURCE_SENTINEL
    file: str
    line: int
    detail: str
    auto_fix: str | None = None  # 전체 fixed line (line 단위 치환을 위해)


def main() -> int:
    # passes는 후속 task에서 추가
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`docs/superpowers/scripts/test_audit_claude_md.py`:
```python
import unittest
import audit_claude_md as audit


class TestScaffold(unittest.TestCase):
    def test_constants_resolve(self):
        self.assertTrue(audit.CLAUDE_MD.exists(), f"{audit.CLAUDE_MD} missing")
        self.assertTrue(audit.PHILOSOPHY.exists(), f"{audit.PHILOSOPHY} missing")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Scaffold 테스트 실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew/docs/superpowers/scripts && python3 -m unittest test_audit_claude_md -v
```

Expected: `test_constants_resolve ... ok` (1 test pass).

- [ ] **Step 3: No commit yet**

Commit은 Task 7 종료 시 한 번에 (script + tests + spec + plan + .gitignore).

---

### Task 2: Pass 1 — Anchor pass (markdown link + slugified fragment)

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`
- Modify: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: `extract_links` 실패 테스트 작성**

`test_audit_claude_md.py`에 추가:
```python
class TestExtractLinks(unittest.TestCase):
    def test_extracts_relative_link(self):
        text = "see [the doc](docs/foo.md) for details"
        self.assertEqual(
            audit.extract_links(text),
            [("the doc", "docs/foo.md", None, 1)],
        )

    def test_extracts_link_with_anchor(self):
        text = "see [§2](docs/foo.md#section-two)"
        self.assertEqual(
            audit.extract_links(text),
            [("§2", "docs/foo.md", "section-two", 1)],
        )

    def test_skips_http_urls(self):
        self.assertEqual(audit.extract_links("see [link](https://example.com)"), [])
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/docs/superpowers/scripts && python3 -m unittest test_audit_claude_md.TestExtractLinks -v
```

Expected: `AttributeError: module 'audit_claude_md' has no attribute 'extract_links'`.

- [ ] **Step 3: `extract_links` 구현**

`audit_claude_md.py`에 추가:
```python
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)#]+)(?:#([^)]+))?\)")


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
```

- [ ] **Step 4: Pass 확인**

Step 2와 같은 명령. Expected: 3 tests pass.

- [ ] **Step 5: `slugify` 실패 테스트 작성**

```python
class TestSlugify(unittest.TestCase):
    def test_lowercase_and_hyphenate(self):
        self.assertEqual(audit.slugify("The Three Laws"), "the-three-laws")

    def test_strips_punctuation(self):
        # GitHub은 em-dash를 drop. 공백은 hyphen으로.
        self.assertEqual(
            audit.slugify("Law 1 — Clarity Before Code"),
            "law-1--clarity-before-code",
        )
```

- [ ] **Step 6: 실패 확인**

Expected: `AttributeError: ... 'slugify'`.

- [ ] **Step 7: `slugify` 구현**

```python
def slugify(heading: str) -> str:
    """GitHub-flavored heading slug: lowercase, spaces→-, drop non-alnum/non-CJK except '-'."""
    s = heading.lower().strip()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s+", "-", s)
    return s
```

- [ ] **Step 8: Pass 확인**

Expected: 2 tests pass. 만약 두 번째 test가 실패하면 (em-dash가 `\w`에 포함되는 경우 등), `python3 -c "from audit_claude_md import slugify; print(repr(slugify('Law 1 — Clarity Before Code')))"`로 실제 출력 확인 후 expected 문자열 조정. 진짜 GitHub anchor와 매칭되는지가 ground truth.

- [ ] **Step 9: `_levenshtein` 실패 테스트 작성**

```python
class TestLevenshtein(unittest.TestCase):
    def test_identical(self):
        self.assertEqual(audit._levenshtein("abc", "abc"), 0)

    def test_one_substitution(self):
        self.assertEqual(audit._levenshtein("abc", "abd"), 1)

    def test_two_edits(self):
        self.assertEqual(audit._levenshtein("kitten", "sittin"), 2)

    def test_empty(self):
        self.assertEqual(audit._levenshtein("abc", ""), 3)
```

- [ ] **Step 10: 실패 확인**

Expected: `AttributeError: ... '_levenshtein'`.

- [ ] **Step 11: `_levenshtein` 구현**

```python
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
```

- [ ] **Step 12: Pass 확인**

Expected: 4 tests pass.

- [ ] **Step 13: `run_anchor_pass` 실패 테스트 작성**

```python
class TestAnchorPass(unittest.TestCase):
    def test_real_claude_md_has_no_broken_links(self):
        findings = audit.run_anchor_pass(audit.CLAUDE_MD.read_text())
        broken = [f for f in findings if f.kind == "BROKEN_LINK"]
        self.assertEqual(broken, [], f"unexpected broken links: {broken}")
```

- [ ] **Step 14: 실패 확인**

Expected: `AttributeError: ... 'run_anchor_pass'`.

- [ ] **Step 15: `collect_anchors`와 `run_anchor_pass` 구현**

```python
HEADING_RE = re.compile(r"^(#+)\s+(.+?)\s*$", re.MULTILINE)


def collect_anchors(text: str) -> set[str]:
    return {slugify(m.group(2)) for m in HEADING_RE.finditer(text)}


def run_anchor_pass(claude_md_text: str) -> list[Finding]:
    findings = []
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
            fix_anchor = close[0] if close and _levenshtein(anchor, close[0]) <= 2 else None
            findings.append(Finding(
                "BROKEN_ANCHOR", "CLAUDE.md", line_no, f"{path}#{anchor}",
                auto_fix=fix_anchor,  # 단순한 anchor 문자열만 저장 (Task 6에서 line-level apply)
            ))
    return findings
```

- [ ] **Step 16: 전체 테스트 실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew/docs/superpowers/scripts && python3 -m unittest -v
```

Expected: 모든 테스트 pass. 현재 `CLAUDE.md`에는 broken link가 0개로 예상.

- [ ] **Step 17: No commit**

---

### Task 3: Pass 2 — Citation pass (`Law N`, `P##`, `AP##`, `§X.Y` 토큰)

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`
- Modify: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: `extract_tokens` 실패 테스트**

```python
class TestExtractTokens(unittest.TestCase):
    def test_extracts_all_token_kinds(self):
        text = "see Law 1 and P12 and AP3 and §2.1 and §4"
        toks = {t for t, _ in audit.extract_tokens(text)}
        self.assertEqual(toks, {"Law 1", "P12", "AP3", "§2.1", "§4"})
```

- [ ] **Step 2: 실패 확인**

Expected: `AttributeError: ... 'extract_tokens'`.

- [ ] **Step 3: `extract_tokens` 구현**

```python
TOKEN_RE = re.compile(r"\b(Law [1-3]|P[0-9]+|AP[0-9]+|§[0-9]+(?:\.[0-9]+)?)")
# 주의: §는 \b 경계가 아니라 단어 경계 — 그래서 \b를 token 시작에만 두지 않음.


def extract_tokens(text: str) -> list[tuple[str, int]]:
    out = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for m in TOKEN_RE.finditer(line):
            out.append((m.group(1), line_no))
    return out
```

- [ ] **Step 4: Pass 확인**

Expected: 1 test pass.

- [ ] **Step 5: `collect_token_anchors` 실패 테스트**

```python
class TestCollectTokenAnchors(unittest.TestCase):
    def test_real_philosophy_has_known_tokens(self):
        anchors = audit.collect_token_anchors(audit.PHILOSOPHY.read_text())
        for tok in ["Law 1", "Law 2", "Law 3", "P1", "P12", "P21", "P23", "P24",
                    "§2", "§2.1", "§4", "§5.3", "§11.1"]:
            self.assertIn(tok, anchors, f"missing: {tok}")
```

- [ ] **Step 6: 실패 확인**

Expected: `AttributeError: ... 'collect_token_anchors'`.

- [ ] **Step 7: `collect_token_anchors` 구현**

```python
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
```

- [ ] **Step 8: Pass 확인**

Expected: 1 test pass — 모든 알려진 토큰이 anchors set에 존재.

- [ ] **Step 9: `run_citation_pass` 실패 테스트**

```python
class TestCitationPass(unittest.TestCase):
    def test_real_claude_md_citations_resolve(self):
        findings = audit.run_citation_pass(
            audit.CLAUDE_MD.read_text(),
            audit.PHILOSOPHY.read_text(),
        )
        unresolved = [f for f in findings if f.kind == "UNRESOLVED_CITATION"]
        self.assertEqual(unresolved, [], f"unexpected unresolved: {unresolved}")
```

- [ ] **Step 10: 실패 확인**

Expected: `AttributeError: ... 'run_citation_pass'`.

- [ ] **Step 11: `run_citation_pass` 구현**

```python
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
```

- [ ] **Step 12: Pass 확인**

Expected: 0 unresolved finding (사전 manual 검증과 일치).

- [ ] **Step 13: No commit**

---

### Task 4: Pass 3a — Count claim drift detection + auto-fix data

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`
- Modify: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: `count_actual` 실패 테스트**

```python
class TestCountActual(unittest.TestCase):
    def test_principles(self):
        self.assertEqual(
            audit.count_actual("principles", audit.PHILOSOPHY.read_text()), 24,
        )

    def test_anti_patterns(self):
        self.assertEqual(
            audit.count_actual("anti_patterns", audit.PHILOSOPHY.read_text()), 14,
        )

    def test_primitives(self):
        # §4.0 .. §4.10 → 11
        self.assertEqual(
            audit.count_actual("primitives", audit.PHILOSOPHY.read_text()), 11,
        )

    def test_tensions(self):
        # §5.1 .. §5.6 → 6
        self.assertEqual(
            audit.count_actual("tensions", audit.PHILOSOPHY.read_text()), 6,
        )
```

- [ ] **Step 2: 실패 확인**

Expected: `AttributeError: ... 'count_actual'`.

- [ ] **Step 3: `count_actual` 구현**

```python
COUNT_PATTERNS = {
    "principles":    re.compile(r"^### P\d+\.", re.MULTILINE),
    "anti_patterns": re.compile(r"^### AP\d+\.", re.MULTILINE),
    "primitives":    re.compile(r"^### 4\.\d+", re.MULTILINE),
    "tensions":      re.compile(r"^### 5\.\d+", re.MULTILINE),
}


def count_actual(kind: str, philosophy_text: str) -> int:
    return len(COUNT_PATTERNS[kind].findall(philosophy_text))
```

- [ ] **Step 4: Pass 확인**

Expected: 4 tests pass. 만약 실제 count가 expected와 다르면 → audit이 우리가 spot-check에서 놓친 drift를 잡은 것. 진행 전에 조사 필요 (counter 변경 또는 expected 값 조정).

- [ ] **Step 5: `run_count_pass` 실패 테스트**

```python
class TestCountPass(unittest.TestCase):
    def test_finds_known_drift(self):
        findings = audit.run_count_pass(
            audit.CLAUDE_MD.read_text(),
            audit.PHILOSOPHY.read_text(),
        )
        kinds = [f.detail.split(":")[0] for f in findings if f.kind == "COUNT_DRIFT"]
        self.assertIn("principles", kinds)
        self.assertIn("anti_patterns", kinds)
```

- [ ] **Step 6: 실패 확인**

Expected: `AttributeError: ... 'run_count_pass'`.

- [ ] **Step 7: `run_count_pass` 구현**

```python
CLAIM_PATTERNS = [
    ("principles",    re.compile(r"(\d+)\s*개?\s*원칙")),
    ("anti_patterns", re.compile(r"(\d+)\s*개?\s*anti-pattern")),
    ("primitives",    re.compile(r"(\d+)\s*개?\s*primitive")),
    ("tensions",      re.compile(r"(\d+)\s*개?\s*tension")),
]


def run_count_pass(claude_md_text: str, philosophy_text: str) -> list[Finding]:
    findings = []
    for kind, pat in CLAIM_PATTERNS:
        actual = count_actual(kind, philosophy_text)
        for line_no, line in enumerate(claude_md_text.splitlines(), start=1):
            for m in pat.finditer(line):
                claimed = int(m.group(1))
                if claimed != actual:
                    fixed_match = m.group(0).replace(m.group(1), str(actual), 1)
                    fixed_line = line[:m.start()] + fixed_match + line[m.end():]
                    findings.append(Finding(
                        "COUNT_DRIFT", "CLAUDE.md", line_no,
                        f"{kind}: claimed={claimed} actual={actual}",
                        auto_fix=fixed_line,
                    ))
    return findings
```

`auto_fix`에 *전체 fixed line*을 저장 — Task 6의 apply 단계가 column offset 추적 없이 line 단위로 치환 가능.

- [ ] **Step 8: Pass 확인**

Expected: `principles`와 `anti_patterns` finding 모두 존재.

- [ ] **Step 9: No commit**

---

### Task 5: Pass 3b — Source-sentinel check (report-only)

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`
- Modify: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: 실패 테스트**

```python
class TestSentinelPass(unittest.TestCase):
    def test_real_philosophy_has_all_four_sources(self):
        findings = audit.run_sentinel_pass(
            audit.CLAUDE_MD.read_text(),
            audit.PHILOSOPHY.read_text(),
        )
        self.assertEqual(findings, [], f"unexpected: {findings}")
```

- [ ] **Step 2: 실패 확인**

Expected: `AttributeError: ... 'run_sentinel_pass'`.

- [ ] **Step 3: `run_sentinel_pass` 구현**

```python
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
```

- [ ] **Step 4: Pass 확인**

Expected: 0 finding.

- [ ] **Step 5: No commit**

---

### Task 6: Auto-fix 적용 + 보고서 렌더링

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`
- Modify: `docs/superpowers/scripts/test_audit_claude_md.py`

- [ ] **Step 1: `apply_auto_fixes` 실패 테스트**

**Note:** Task 6 refactored `Finding.auto_fix` from `str | None` to `tuple[int, int, str] | None` to support multi-finding-per-line composition. See Task 6 step 1 in this plan.

```python
class TestApplyFixes(unittest.TestCase):
    def test_count_drift_fix(self):
        original = "this doc has 23 원칙 cataloged\n"
        f = audit.Finding(
            "COUNT_DRIFT", "CLAUDE.md", 1,
            "principles: claimed=23 actual=24",
            auto_fix=(13, 15, "24"),
        )
        self.assertEqual(
            audit.apply_auto_fixes(original, [f]),
            "this doc has 24 원칙 cataloged\n",
        )

    def test_skips_findings_without_auto_fix(self):
        original = "P25 is cited\n"
        f = audit.Finding("UNRESOLVED_CITATION", "CLAUDE.md", 1, "P25", auto_fix=None)
        self.assertEqual(audit.apply_auto_fixes(original, [f]), original)
```

- [ ] **Step 2: 실패 확인**

Expected: `AttributeError: ... 'apply_auto_fixes'`.

- [ ] **Step 3: `apply_auto_fixes` 구현**

```python
def apply_auto_fixes(text: str, findings: list[Finding]) -> str:
    lines = text.splitlines(keepends=True)
    for f in findings:
        if f.auto_fix is None:
            continue
        if f.kind != "COUNT_DRIFT":
            # BROKEN_ANCHOR auto-fix는 별도 (Step 5에서 추가) — 단순한 anchor 문자열을 저장하므로 line replacement가 아님
            continue
        idx = f.line - 1
        if 0 <= idx < len(lines):
            trailing = "\n" if lines[idx].endswith("\n") else ""
            lines[idx] = f.auto_fix + trailing
    return "".join(lines)
```

- [ ] **Step 4: Pass 확인**

Expected: 2 tests pass.

- [ ] **Step 5: BROKEN_ANCHOR auto-fix 추가** (현재 `CLAUDE.md`에서는 fire하지 않을 것이지만, 미래 호출을 위한 구현 필요)

`run_anchor_pass`의 `auto_fix` payload를 *단순 anchor 문자열* → *전체 fixed line*으로 변경. `audit_claude_md.py`의 `run_anchor_pass`를 수정:

```python
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
                # 전체 fixed line 생성
                old_link = f"#{anchor}"
                new_link = f"#{close[0]}"
                fixed_line = lines[line_no - 1].replace(old_link, new_link, 1)
                fix = fixed_line
            else:
                fix = None
            findings.append(Finding(
                "BROKEN_ANCHOR", "CLAUDE.md", line_no,
                f"{path}#{anchor}" + (f" → #{close[0]}" if fix else ""),
                auto_fix=fix,
            ))
    return findings
```

그리고 `apply_auto_fixes`의 guard를 완화:
```python
def apply_auto_fixes(text: str, findings: list[Finding]) -> str:
    lines = text.splitlines(keepends=True)
    for f in findings:
        if f.auto_fix is None:
            continue
        if f.kind not in ("COUNT_DRIFT", "BROKEN_ANCHOR"):
            continue
        idx = f.line - 1
        if 0 <= idx < len(lines):
            trailing = "\n" if lines[idx].endswith("\n") else ""
            lines[idx] = f.auto_fix + trailing
    return "".join(lines)
```

- [ ] **Step 6: 전체 테스트 재실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew/docs/superpowers/scripts && python3 -m unittest -v
```

Expected: 모든 기존 test pass (anchor pass test가 여전히 0 broken link 보고).

- [ ] **Step 7: `render_report` 실패 테스트**

```python
class TestRenderReport(unittest.TestCase):
    def test_empty_findings(self):
        report = audit.render_report([])
        self.assertIn("(no findings)", report)
        for kind in ["BROKEN_LINK", "BROKEN_ANCHOR", "UNRESOLVED_CITATION",
                     "COUNT_DRIFT", "MISSING_SOURCE_SENTINEL"]:
            self.assertIn(kind, report)

    def test_count_drift_listed(self):
        f = audit.Finding(
            "COUNT_DRIFT", "CLAUDE.md", 5,
            "principles: claimed=23 actual=24",
            auto_fix=(0, 2, "24"),
        )
        report = audit.render_report([f])
        self.assertIn("**Auto-fixed**", report)
        self.assertIn("CLAUDE.md:5", report)
```

- [ ] **Step 8: 실패 확인**

Expected: `AttributeError: ... 'render_report'`.

- [ ] **Step 9: `render_report` 구현**

```python
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
```

- [ ] **Step 10: Pass 확인**

Expected: 2 tests pass.

- [ ] **Step 11: No commit**

---

### Task 7: `main()` orchestration

**Files:**
- Modify: `docs/superpowers/scripts/audit_claude_md.py`

- [ ] **Step 1: `main()` 본체 구현**

기존 `main()` 교체:
```python
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
```

- [ ] **Step 2: 전체 unit test 실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew/docs/superpowers/scripts && python3 -m unittest -v
```

Expected: 모든 test pass.

- [ ] **Step 3: Preparatory commit (Commit 1)**

이 시점까지의 모든 artifact (audit script + tests + spec + plan + .gitignore patch)을 한 commit으로:

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add .gitignore \
        docs/superpowers/specs/2026-05-07-claude-md-restructure-audit-design.md \
        docs/superpowers/plans/2026-05-07-claude-md-restructure-audit.md \
        docs/superpowers/scripts/audit_claude_md.py \
        docs/superpowers/scripts/test_audit_claude_md.py
git commit -m "$(cat <<'EOF'
chore: untrack docs/superpowers/ and add CLAUDE.md audit script

- .gitignore: superpowers/ and research/ entries removed
- Audit spec and plan (specs/, plans/)
- Python audit script + unittest tests (scripts/)

Implements design from docs/superpowers/specs/2026-05-07-claude-md-restructure-audit-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 1 commit created on `feature/harness-philosophy`. Verify with `git log -1 --stat`.

---

### Task 8: 실제 트리에서 첫 실행

**Files:**
- Read: `CLAUDE.md`
- Generate: `docs/superpowers/reports/2026-05-07-claude-md-audit.md`
- Modify: `CLAUDE.md` (auto-fix)

- [ ] **Step 1: Audit 실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 docs/superpowers/scripts/audit_claude_md.py
```

Expected output:
```
Auto-fixes applied to /Users/jeonghokim/Downloads/devbrew/CLAUDE.md
Report written to /Users/jeonghokim/Downloads/devbrew/docs/superpowers/reports/2026-05-07-claude-md-audit.md
Total findings: 5
Auto-fixed: 5
```

The 5 findings are: principles 23→24 (×2 occurrences on lines 8 and 104), anti_patterns 17→14 (×2), primitives 10→11 (×1, on line 104). The original spot-check anticipated only the first two; primitives drift was discovered by the audit itself.

- [ ] **Step 2: 보고서 inspection**

`docs/superpowers/reports/2026-05-07-claude-md-audit.md` 읽기. 확인:
- 5개 finding section 모두 존재
- `COUNT_DRIFT` section에 두 개 finding (둘 다 **Auto-fixed**)
- 다른 section은 모두 `(no findings)`

- [ ] **Step 3: Auto-fix diff inspection**

```bash
git -C /Users/jeonghokim/Downloads/devbrew diff CLAUDE.md
```

Expected: 숫자 토큰만 변경 (`23` → `24`, `17` → `14`). 산문 변경 없음. CLAUDE.md에서 각 phrase가 두 번씩 등장하므로 최대 4 라인 변경.

**diff가 expected와 다르면 commit 전에 멈추고 사용자에게 문의.** Count regex가 의도하지 않은 곳을 매칭했을 가능성.

- [ ] **Step 4: Auto-fix commit 생성 (Commit 2)**

```bash
git -C /Users/jeonghokim/Downloads/devbrew add CLAUDE.md
git -C /Users/jeonghokim/Downloads/devbrew commit -m "$(cat <<'EOF'
docs(claude-md): fix mechanical drift caught by audit

- COUNT_DRIFT: 23 원칙 → 24 원칙 (P24 added in 628b95f)
- COUNT_DRIFT: 17 anti-pattern → 14 anti-pattern (post-§11.1 restructure)

Audit report: docs/superpowers/reports/2026-05-07-claude-md-audit.md (committed in follow-up)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Commit 확인**

```bash
git -C /Users/jeonghokim/Downloads/devbrew log -1 --stat
```

Expected: 1 file changed (`CLAUDE.md`), 작은 line count.

---

### Task 9: 검증 — 재실행 시 zero auto-fix finding

**Files:**
- Read: `CLAUDE.md` (post-fix)

- [ ] **Step 1: Audit 재실행**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 docs/superpowers/scripts/audit_claude_md.py
```

Expected output:
```
Report written to /Users/jeonghokim/Downloads/devbrew/docs/superpowers/reports/2026-05-07-claude-md-audit.md
Total findings: 0
Auto-fixed: 0
```

(`Auto-fixes applied` 라인 없음 — `fixed == claude`이므로.)

- [ ] **Step 2: 재생성된 보고서 확인**

모든 section이 `(no findings)`. Spec acceptance criterion #4 충족.

- [ ] **Step 3: `CLAUDE.md` 변경 없음 확인**

```bash
git -C /Users/jeonghokim/Downloads/devbrew diff CLAUDE.md
```

Expected: empty diff.

- [ ] **Step 4: 최종 report commit (Commit 3)**

재실행으로 갱신된 report (모든 section `(no findings)`)를 commit:

```bash
git -C /Users/jeonghokim/Downloads/devbrew add docs/superpowers/reports/2026-05-07-claude-md-audit.md
git -C /Users/jeonghokim/Downloads/devbrew commit -m "$(cat <<'EOF'
docs(audit): add CLAUDE.md restructure audit report (post-fix)

Final report after auto-fixes applied — all sections show (no findings).
Validates spec acceptance criterion #4 (re-run produces zero drift).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Spec acceptance criteria 최종 점검**

- [x] (1) 모든 pass 실행 — Task 7 main() 호출
- [x] (2) Auto-fix 단일 commit, distinct — Task 8 step 4 (Commit 2)
- [x] (3) Report exists at specified path and is committed — Task 9 step 4 (Commit 3)
- [x] (4) 재실행 시 zero `COUNT_DRIFT` & zero `BROKEN_ANCHOR` — Task 9 step 1

---

## Self-Review

**Spec coverage:**
- Pass 1 (Anchor) → Task 2 ✓
- Pass 2 (Citation) → Task 3 ✓
- Pass 3a (Count) → Task 4 ✓
- Pass 3b (Sentinel) → Task 5 ✓
- Auto-fix matrix → Task 4(COUNT) + Task 6(BROKEN_ANCHOR + others report-only) ✓
- Report at specified path → Task 6+7 ✓
- 단일 auto-fix commit, no empty commits → Task 8 step 4 (`if fixed != claude:`) ✓
- 재실행 zero findings → Task 9 ✓
- Spec deviation 한 가지(Bash→Python); ephemeral-report 가정은 mid-flight gitignore 변경으로 무효화 (header note 참조) ✓

**Placeholder scan:** TBD/TODO/"implement later" 없음. Task 2 step 8의 fallback("expected가 GitHub 실제 출력과 다르면 조정")은 fragile point에 대한 명시적 안내 — placeholder 아님.

**Type consistency:**
- `Finding(kind, file, line, detail, auto_fix=None)` — Task 1 정의, 모든 task에서 일관 사용
- `auto_fix`는 `tuple[int, int, str] | None` — `(start, end, replacement)` (Task 6에서 multi-finding-per-line composition을 위해 spec의 단순 string format에서 refactor; line-level apply는 sort right-to-left로 composition)
- `extract_links` → `(text, path, anchor, line_no)` / `extract_tokens` → `(token, line_no)` — 형태가 다르지만 각각 고유 호출자만 가짐, 충돌 없음

**Self-review에서 잡힌 issue:** Task 6에서 `auto_fix` payload semantics를 변경(anchor 문자열 → 전체 line)하면서 Task 2의 초기 구현과 일관되지 않음을 발견 → Task 6 step 5에서 `run_anchor_pass`를 backfill하는 단계를 명시.
