# spec-distill Hook-Driven Deterministic Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 플러그인에 PostToolUse + Stop 두 hook을 추가해 spec/design 문서 review의 trigger와 dispatch를 LLM 의지에서 분리하고, brainstorming(upstream)이 작성하는 `-design.md`까지 동일 reviewer 파이프라인으로 통합한다.

**Architecture:** 2-layer 결정론. Layer 1 (PostToolUse, Python) = mechanical schema/keyword 검증, exit 2로 즉시 차단. Layer 2 (Stop hook, Python) = `state.local.md`의 `pending_review:` 파일 ledger를 읽어 systemMessage 주입으로 reviewer dispatch를 강제. PostToolUse↔Stop coordination은 transcript signal이 아닌 파일 기반 ledger (quality-gates의 `<qg-signal>` 패턴과 의도적 차별화).

**Tech Stack:** Python 3 (standard library only — `pathlib`, `re`, `json`, `os`, `sys`, `datetime`), Bash (test runner), `jq` (JSON 검증), `grep` (text 검증). 외부 PyPI 의존성 없음.

**Spec:** [`docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md`](../specs/2026-05-16-spec-distill-hook-review-design.md) (v1.3.0, locked).

---

## File Structure

신규 (4):
- `plugins/spec-distill/hooks/spec-write-validator.py` — PostToolUse hook entry. Layer 1 mechanical validation, mode 분기 (spec/design), kill switch, state.local.md ledger write.
- `plugins/spec-distill/hooks/review-dispatch.py` — Stop hook entry. `pending_review:` block 읽어 systemMessage 주입, `last_dispatched_at` 가드.
- `plugins/spec-distill/scripts/parse_spec_structure.py` — 라이브러리. frontmatter 파서, 11 section detector, locked_decisions schema, ambiguity scanner, placeholder scanner. 단위 테스트 가능.
- `plugins/spec-distill/scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 (1 line per pattern, `#` comment).

수정 (6):
- `plugins/spec-distill/hooks/hooks.json` — PostToolUse + Stop event 추가.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — Step 1 갱신 + "Re-review cap" 섹션 hard cap `>= 3` → `>= 5` + round-level stagnation early-exit.
- `plugins/spec-distill/skills/drafting-spec/SKILL.md` — Mode A/B 종료 부분.
- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.2.0` → `0.3.0`.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.3.0] — 2026-05-16` 섹션.
- `plugins/spec-distill/README.md` — "Hooks Installed" 표 + "Principles Instantiated" Law 2 강화.

테스트 신규 (3):
- `plugins/spec-distill/tests/test_spec_write_validator.sh` — AC1–AC10.
- `plugins/spec-distill/tests/test_review_dispatch.sh` — AC11–AC13.
- `plugins/spec-distill/tests/fixtures/` — 7 fixture 파일 (spec-valid.md, spec-missing-goals.md, spec-ambiguity-line12.md, spec-ambiguity-escaped.md, design-no-frontmatter.md, design-tbd.md, state-pending-review.md).

---

## Task 1: V8 Prerequisite — quality-gates hook output protocol 정적 분석

**Files:**
- Read-only: `plugins/quality-gates/hooks/post-tool-use.py`, `plugins/quality-gates/hooks/stop-hook.py`
- Create: `docs/superpowers/plans/2026-05-16-spec-distill-hook-review-prerequisite.md`

C9 / V8을 충족. 다른 task 시작 전 plan 문서에 발견 사항을 fix.

- [ ] **Step 1: Read quality-gates PostToolUse hook**

```bash
grep -nE 'sys.exit|"decision"|"systemMessage"|"additionalContext"|stderr|stdout' plugins/quality-gates/hooks/post-tool-use.py | head -40
```

Expected: exit code usage (특히 exit 2), JSON output 키 발견.

- [ ] **Step 2: Read quality-gates Stop hook**

```bash
grep -nE 'systemMessage|hookSpecificOutput|continue|stopReason|json.dump' plugins/quality-gates/hooks/stop-hook.py | head -40
```

Expected: Stop hook이 stdin에서 무엇을 읽고 stdout에 어떤 JSON을 쓰는지 확인.

- [ ] **Step 3: 결과 기록**

`docs/superpowers/plans/2026-05-16-spec-distill-hook-review-prerequisite.md` 작성. 다음 항목 포함:

```markdown
# Prerequisite — quality-gates hook output protocol (V8)

## PostToolUse (post-tool-use.py)
- Block 메커니즘: <exit code pattern + JSON keys discovered>
- stderr/stdout 사용 패턴: ...

## Stop (stop-hook.py)
- stdin payload schema: ...
- systemMessage 주입 JSON key: ...
- 다음 turn으로의 전달 방식: ...

## 본 plan에 미치는 영향
- spec-write-validator.py 차단 메커니즘: exit 2 + stderr + (도움이 되면) stdout `{"decision": "block", "reason": "..."}`
- review-dispatch.py systemMessage 주입: stdout JSON `{"systemMessage": "..."}` 형식
```

- [ ] **Step 4: Commit prerequisite doc**

```bash
git add docs/superpowers/plans/2026-05-16-spec-distill-hook-review-prerequisite.md
git commit -m "docs(spec-distill-plan): V8 prerequisite — quality-gates hook output protocol analysis"
```

---

## Task 2: Fixtures 생성

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/spec-valid.md`
- Create: `plugins/spec-distill/tests/fixtures/spec-missing-goals.md`
- Create: `plugins/spec-distill/tests/fixtures/spec-ambiguity-line12.md`
- Create: `plugins/spec-distill/tests/fixtures/spec-ambiguity-escaped.md`
- Create: `plugins/spec-distill/tests/fixtures/design-no-frontmatter.md`
- Create: `plugins/spec-distill/tests/fixtures/design-tbd.md`
- Create: `plugins/spec-distill/tests/fixtures/state-pending-review.md`

AC1–AC13 fixtures. *TDD에서 test fixture는 product code 앞에 만든다.*

- [ ] **Step 1: spec-valid.md** (11 sections + valid frontmatter, no ambiguity)

```markdown
---
name: fixture-valid
version: 1.0.0
created_at: 2026-05-16
status: design
source: fixture
next_phase: writing-plans
session_id: fixture-spec-valid
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: 'Fixture LD content.'
    source: fixture
---

# Fixture Spec Valid

> Description line.

## Goal
One sentence describing the goal.

## Context / Why
Motivation paragraph.

## Goals
- G1: First measurable goal under 100 milliseconds.

## Non-goals
- NG1: Out of scope item.

## Constraints
- C1: Time-bound constraint.

## Acceptance Criteria
- AC1: Specific verifiable criterion via `command`.

## Files to Modify
- `path/to/file.py`

## Verification Plan
- V1: Run `command` expect exit 0.

## Rejected Alternatives
- R1: Considered approach, rejected because reason.

## Open Questions
- Q1: Deferred question.

## Concrete Next Action
Run `command`.
```

- [ ] **Step 2: spec-missing-goals.md** — spec-valid의 Goals 섹션 제거 버전. 위 fixture를 베이스로 `## Goals\n- G1: ...` 두 줄만 삭제.

```markdown
---
name: fixture-missing-goals
version: 1.0.0
created_at: 2026-05-16
status: design
source: fixture
next_phase: writing-plans
session_id: fixture-spec-missing-goals
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: 'Fixture LD content.'
    source: fixture
---

# Fixture Missing Goals

## Goal
One sentence describing the goal.

## Context / Why
Motivation paragraph.

## Non-goals
- NG1: Out of scope item.

## Constraints
- C1: Time-bound constraint.

## Acceptance Criteria
- AC1: Specific verifiable criterion via `command`.

## Files to Modify
- `path/to/file.py`

## Verification Plan
- V1: Run `command` expect exit 0.

## Rejected Alternatives
- R1: Considered approach, rejected because reason.

## Open Questions
- Q1: Deferred question.

## Concrete Next Action
Run `command`.
```

- [ ] **Step 3: spec-ambiguity-line12.md** — line 12에 정확히 "works correctly" 키워드 포함. line 번호가 hardcoded이므로 fixture 작성 시 줄 수 정확히 맞추기.

```markdown
---
name: fixture-ambiguity
version: 1.0.0
created_at: 2026-05-16
session_id: fixture-ambiguity
status: design
source: fixture
next_phase: writing-plans
locked_decisions: []
---

# Fixture Ambiguity Hit
## Goals
- G1: System works correctly under load.
```

(*첫 줄 `---` 부터 카운트했을 때 `- G1: System works correctly under load.` 가 line 12. 작성 후 `awk 'NR==12' plugins/spec-distill/tests/fixtures/spec-ambiguity-line12.md` 로 검증.*)

- [ ] **Step 4: spec-ambiguity-escaped.md** — 같은 줄을 `~` escape으로.

```markdown
---
name: fixture-ambiguity-escaped
version: 1.0.0
created_at: 2026-05-16
session_id: fixture-ambiguity-escaped
status: design
source: fixture
next_phase: writing-plans
locked_decisions: []
---

# Fixture Ambiguity Escaped
## Goal
Single sentence.
## Context / Why
Reason.
## Goals
- G1: System ~works correctly under load.
## Non-goals
- NG1: out.
## Constraints
- C1: bounded.
## Acceptance Criteria
- AC1: verifiable.
## Files to Modify
- `f.py`
## Verification Plan
- V1: run.
## Rejected Alternatives
- R1: skipped.
## Open Questions
- Q1: deferred.
## Concrete Next Action
Run.
```

- [ ] **Step 5: design-no-frontmatter.md** — frontmatter 없는 design.md.

```markdown
# Design Doc — No Frontmatter

## Overview

Quick brainstorming output.

## Approach

Two-step approach: A then B.

## Risks

Identified two risks: latency and rollout.
```

- [ ] **Step 6: design-tbd.md** — placeholder "TBD" 포함.

```markdown
# Design Doc — TBD

## Approach

TBD — to be decided next round.

## Risks

None identified yet.
```

- [ ] **Step 7: state-pending-review.md** — Stop hook test용 state.local.md 형태.

```markdown
---
session_id: fixture-state-pending
phase: 3
pending_review:
  path: /abs/path/to/some-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
last_dispatched_at: null
---

# Spec-distill state (fixture)

dummy body.
```

- [ ] **Step 8: Commit fixtures**

```bash
git add plugins/spec-distill/tests/fixtures/
git commit -m "test(spec-distill): add fixtures for AC1–AC13 hook validation"
```

---

## Task 3: `parse_spec_structure.py` — frontmatter 파싱 (TDD)

**Files:**
- Create: `plugins/spec-distill/scripts/parse_spec_structure.py`
- Create: `plugins/spec-distill/tests/test_parse_spec_structure.sh`

라이브러리 *진입점은 CLI subcommand*로 설계 (bash 테스트가 호출하기 쉬움). 첫 subcommand: `frontmatter <path>`.

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_parse_spec_structure.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for parse_spec_structure.py library (CLI subcommand interface).
# Run: bash plugins/spec-distill/tests/test_parse_spec_structure.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/parse_spec_structure.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0
fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

echo "=== frontmatter subcommand ==="

# T3-1: valid frontmatter → exit 0 + JSON에 expected keys
out=$(python3 "$SCRIPT" frontmatter "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"name": "fixture-valid"' \
  && note PASS "valid frontmatter parsed (name)" \
  || note FAIL "valid frontmatter parse failed (rc=$rc out=$out)"

# T3-2: missing frontmatter (design mode case) → exit 0 + empty object
out=$(python3 "$SCRIPT" frontmatter "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '{}' \
  && note PASS "no frontmatter returns empty object" \
  || note FAIL "no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 테스트가 fail 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: 2 fails (스크립트 미존재).

- [ ] **Step 3: minimal `parse_spec_structure.py` 작성**

```python
#!/usr/bin/env python3
"""spec-distill — Spec/design structure parser library.

CLI subcommand interface so bash tests and hook scripts can invoke
specific checks deterministically:

  parse_spec_structure.py frontmatter <path>   # JSON
  parse_spec_structure.py sections <path>      # JSON (missing list)
  parse_spec_structure.py locked-decisions <path>  # JSON (errors list)
  parse_spec_structure.py ambiguity <path> <blacklist_path>  # JSON (hits)
  parse_spec_structure.py placeholders <path>  # JSON (hits)
"""
import json
import re
import sys
from pathlib import Path


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Parse YAML-ish frontmatter into a flat dict. Returns {} if absent."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    body = m.group(1)
    out: dict = {}
    current_list_key = None
    for line in body.split("\n"):
        if not line.strip():
            continue
        if line.startswith("  - ") or line.startswith("    "):
            # list item or nested — keep raw for downstream parsers
            if current_list_key is not None:
                out.setdefault(current_list_key, []).append(line.rstrip())
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if value == "":
                current_list_key = key
                out[key] = []
            else:
                current_list_key = None
                # strip surrounding quotes
                if value.startswith(("'", '"')) and value.endswith(value[0]):
                    value = value[1:-1]
                out[key] = value
    return out


def cmd_frontmatter(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps(parse_frontmatter(text)))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: parse_spec_structure.py <subcommand> <args>", file=sys.stderr)
        return 64
    sub = argv[1]
    if sub == "frontmatter":
        return cmd_frontmatter(Path(argv[2]))
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
chmod +x plugins/spec-distill/scripts/parse_spec_structure.py
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: `summary: 2 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/tests/test_parse_spec_structure.sh
git commit -m "feat(spec-distill): add parse_spec_structure.py frontmatter subcommand + tests"
```

---

## Task 4: `parse_spec_structure.py` — 11 section detection (TDD)

**Files:**
- Modify: `plugins/spec-distill/scripts/parse_spec_structure.py` (add `sections` subcommand)
- Modify: `plugins/spec-distill/tests/test_parse_spec_structure.sh` (add T4 cases)

- [ ] **Step 1: 실패하는 테스트 추가**

`test_parse_spec_structure.sh` 의 `summary` 줄 *위*에 다음 추가:

```bash
echo ""
echo "=== sections subcommand ==="

# T4-1: spec-valid → no missing sections
out=$(python3 "$SCRIPT" sections "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"missing": \[\]' \
  && note PASS "valid spec has no missing sections" \
  || note FAIL "valid spec sections check failed (rc=$rc out=$out)"

# T4-2: spec-missing-goals → missing includes "#goals"
out=$(python3 "$SCRIPT" sections "$FIX/spec-missing-goals.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '#goals' \
  && note PASS "spec-missing-goals reports #goals as missing" \
  || note FAIL "missing-goals detection failed (rc=$rc out=$out)"
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: T4 두 케이스 fail ("unknown subcommand: sections").

- [ ] **Step 3: `sections` subcommand 구현**

`parse_spec_structure.py`에 다음 추가:

```python
# 11 required sections (anchor form for output mapping)
REQUIRED_SECTIONS = [
    ("Goal", "#goal"),
    ("Context", "#context"),
    ("Goals", "#goals"),
    ("Non-goals", "#non-goals"),
    ("Constraints", "#constraints"),
    ("Acceptance Criteria", "#acceptance-criteria"),
    ("Files to Modify", "#files-to-modify"),
    ("Verification Plan", "#verification-plan"),
    ("Rejected Alternatives", "#rejected-alternatives"),
    ("Open Questions", "#open-questions"),
    ("Concrete Next Action", "#concrete-next-action"),
]


def find_missing_sections(text: str) -> list[str]:
    """Return anchor list for sections whose `## <title>` header is absent.

    'Context' matches both `## Context` and `## Context / Why`. Match is
    case-insensitive on the section title.
    """
    missing = []
    for title, anchor in REQUIRED_SECTIONS:
        pattern = re.compile(rf"^##\s+{re.escape(title)}\b", re.MULTILINE | re.IGNORECASE)
        if not pattern.search(text):
            missing.append(anchor)
    return missing


def cmd_sections(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    missing = find_missing_sections(text)
    print(json.dumps({"missing": missing}))
    return 0
```

그리고 `main()` 에 분기 추가:

```python
    if sub == "sections":
        return cmd_sections(Path(argv[2]))
```

- [ ] **Step 4: 테스트 통과**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: `4 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/tests/test_parse_spec_structure.sh
git commit -m "feat(spec-distill): parse_spec_structure sections subcommand (11 required)"
```

---

## Task 5: `parse_spec_structure.py` — locked_decisions schema 검증 (TDD)

**Files:**
- Modify: `plugins/spec-distill/scripts/parse_spec_structure.py` (add `locked-decisions` subcommand)
- Modify: `plugins/spec-distill/tests/test_parse_spec_structure.sh` (add T5 cases)

- [ ] **Step 1: 실패하는 테스트 추가**

`test_parse_spec_structure.sh` 의 `summary` 줄 *위*에 다음 추가:

```bash
echo ""
echo "=== locked-decisions subcommand ==="

# T5-1: spec-valid → no errors (LD1만 있고 모든 sub-field 존재)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "valid spec locked_decisions has no errors" \
  || note FAIL "valid locked_decisions check failed (rc=$rc out=$out)"

# T5-2: design-no-frontmatter → no errors (locked_decisions 부재 = 미적용, design mode에서 정상)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "design-mode no-frontmatter has no errors" \
  || note FAIL "design no-frontmatter case failed (rc=$rc out=$out)"
```

- [ ] **Step 2: 실패 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: T5 두 케이스 fail.

- [ ] **Step 3: `locked-decisions` subcommand 구현**

`parse_spec_structure.py`에 추가:

```python
LD_FIELDS = ("id", "section", "summary", "source")


def validate_locked_decisions(text: str) -> list[str]:
    """Each LD entry must have id/section/summary/source. Returns error list."""
    errors: list[str] = []
    m = FRONTMATTER_RE.match(text)
    if not m:
        return errors  # no frontmatter → design mode → no LD constraint
    body = m.group(1)
    # Locate `locked_decisions:` block and its entries (lines starting with "  - id:")
    in_block = False
    entries: list[dict] = []
    current: dict = {}
    for line in body.split("\n"):
        if re.match(r"^locked_decisions\s*:\s*\[\s*\]\s*$", line):
            return errors  # explicitly empty
        if re.match(r"^locked_decisions\s*:\s*$", line):
            in_block = True
            continue
        if in_block:
            if re.match(r"^[a-zA-Z_]", line):  # next top-level key → block end
                if current:
                    entries.append(current)
                break
            m_id = re.match(r"^\s*-\s*id\s*:\s*(.+)$", line)
            m_field = re.match(r"^\s+([a-z_]+)\s*:\s*(.+)$", line)
            if m_id:
                if current:
                    entries.append(current)
                current = {"id": m_id.group(1).strip()}
            elif m_field:
                key = m_field.group(1).strip()
                val = m_field.group(2).strip()
                current[key] = val
    if current:
        entries.append(current)
    for idx, entry in enumerate(entries):
        for f in LD_FIELDS:
            if f not in entry or not entry[f]:
                errors.append(f"LD[{idx}] missing required field '{f}'")
    return errors


def cmd_locked_decisions(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps({"errors": validate_locked_decisions(text)}))
    return 0
```

`main()` 분기 추가:

```python
    if sub == "locked-decisions":
        return cmd_locked_decisions(Path(argv[2]))
```

- [ ] **Step 4: 통과 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: `6 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/tests/test_parse_spec_structure.sh
git commit -m "feat(spec-distill): parse_spec_structure locked-decisions schema validation"
```

---

## Task 6: ambiguity-blacklist.txt + scanner subcommand (TDD)

**Files:**
- Create: `plugins/spec-distill/scripts/ambiguity-blacklist.txt`
- Modify: `plugins/spec-distill/scripts/parse_spec_structure.py` (add `ambiguity` subcommand)
- Modify: `plugins/spec-distill/tests/test_parse_spec_structure.sh` (add T6 cases)

- [ ] **Step 1: blacklist 파일 작성**

`plugins/spec-distill/scripts/ambiguity-blacklist.txt`:

```
# spec-distill ambiguity blacklist
# One pattern per line. Lines starting with # are comments.
# Escape: prepend `~` to a word in spec.md to opt out of scan for that occurrence.
works correctly
fast
good UX
as needed
properly
efficient
seamless
robust
easy to use
intuitive
```

- [ ] **Step 2: 실패하는 테스트 추가**

`test_parse_spec_structure.sh` 의 `summary` 줄 *위*에 다음 추가:

```bash
echo ""
echo "=== ambiguity subcommand ==="
BL="$REPO_ROOT/plugins/spec-distill/scripts/ambiguity-blacklist.txt"

# T6-1: spec-valid → no hits
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-valid.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "valid spec has no ambiguity hits" \
  || note FAIL "valid ambiguity scan failed (rc=$rc out=$out)"

# T6-2: spec-ambiguity-line12 → hit "works correctly" on line 12
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-line12.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q 'works correctly' \
  && echo "$out" | grep -q '"line": 12' \
  && note PASS "ambiguity hit detected on line 12" \
  || note FAIL "ambiguity-line12 detection failed (rc=$rc out=$out)"

# T6-3: spec-ambiguity-escaped → no hits (~ prefix excludes)
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-escaped.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "~escape prefix excludes from scan" \
  || note FAIL "escape syntax failed (rc=$rc out=$out)"
```

- [ ] **Step 3: 실패 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: 3 fails.

- [ ] **Step 4: `ambiguity` subcommand 구현**

`parse_spec_structure.py`에 추가:

```python
def load_blacklist(blacklist_path: Path) -> list[str]:
    patterns: list[str] = []
    for raw in blacklist_path.read_text(encoding="utf-8").split("\n"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(line)
    return patterns


def scan_ambiguity(text: str, patterns: list[str]) -> list[dict]:
    """Find lines containing any blacklisted phrase. `~phrase` opt-out applies
    to that specific occurrence (match must NOT be preceded by `~`).
    """
    hits: list[dict] = []
    for lineno, line in enumerate(text.split("\n"), start=1):
        for phrase in patterns:
            # Search for phrase, ensure the character immediately before is not `~`
            for m in re.finditer(re.escape(phrase), line, flags=re.IGNORECASE):
                start = m.start()
                if start > 0 and line[start - 1] == "~":
                    continue
                hits.append({"line": lineno, "phrase": phrase, "text": line})
                break  # one hit per phrase per line is enough
    return hits


def cmd_ambiguity(path: Path, blacklist_path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    patterns = load_blacklist(blacklist_path)
    print(json.dumps({"hits": scan_ambiguity(text, patterns)}))
    return 0
```

`main()` 분기 추가:

```python
    if sub == "ambiguity":
        return cmd_ambiguity(Path(argv[2]), Path(argv[3]))
```

- [ ] **Step 5: 통과 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: `9 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/scripts/ambiguity-blacklist.txt plugins/spec-distill/tests/test_parse_spec_structure.sh
git commit -m "feat(spec-distill): ambiguity blacklist + scanner with ~escape"
```

---

## Task 7: placeholder scanner (design mode TBD/TODO, TDD)

**Files:**
- Modify: `plugins/spec-distill/scripts/parse_spec_structure.py` (add `placeholders` subcommand)
- Modify: `plugins/spec-distill/tests/test_parse_spec_structure.sh`

- [ ] **Step 1: 실패하는 테스트**

`test_parse_spec_structure.sh` 의 `summary` 줄 *위*에 추가:

```bash
echo ""
echo "=== placeholders subcommand ==="

# T7-1: design-no-frontmatter → no hits
out=$(python3 "$SCRIPT" placeholders "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "clean design has no placeholder hits" \
  || note FAIL "clean design placeholder scan failed (rc=$rc out=$out)"

# T7-2: design-tbd → TBD hit
out=$(python3 "$SCRIPT" placeholders "$FIX/design-tbd.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"token": "TBD"' \
  && note PASS "TBD placeholder detected" \
  || note FAIL "TBD placeholder detection failed (rc=$rc out=$out)"
```

- [ ] **Step 2: 실패 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: 2 fails.

- [ ] **Step 3: `placeholders` subcommand 구현**

`parse_spec_structure.py`에 추가:

```python
PLACEHOLDER_TOKENS = ("TBD", "TODO", "FIXME", "<placeholder>")


def scan_placeholders(text: str) -> list[dict]:
    """Find lines containing placeholder tokens. Frontmatter and `~`-escaped
    occurrences are excluded."""
    hits: list[dict] = []
    # Skip frontmatter
    m = FRONTMATTER_RE.match(text)
    body_start = m.end() if m else 0
    offset_line = text[:body_start].count("\n")
    body = text[body_start:]
    for idx, line in enumerate(body.split("\n"), start=offset_line + 1):
        for token in PLACEHOLDER_TOKENS:
            for m2 in re.finditer(re.escape(token), line):
                start = m2.start()
                if start > 0 and line[start - 1] == "~":
                    continue
                hits.append({"line": idx, "token": token, "text": line})
                break
    return hits


def cmd_placeholders(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps({"hits": scan_placeholders(text)}))
    return 0
```

`main()` 분기 추가:

```python
    if sub == "placeholders":
        return cmd_placeholders(Path(argv[2]))
```

- [ ] **Step 4: 통과 확인**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
```

Expected: `11 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/tests/test_parse_spec_structure.sh
git commit -m "feat(spec-distill): placeholder scanner (TBD/TODO/FIXME)"
```

---

## Task 8: `spec-write-validator.py` PostToolUse hook (TDD)

**Files:**
- Create: `plugins/spec-distill/hooks/spec-write-validator.py`
- Create: `plugins/spec-distill/tests/test_spec_write_validator.sh`

AC1–AC10. matcher는 hooks.json의 tool-name regex (Task 10); 여기서는 *script 내부* path-suffix 분기 + kill switch + structural calls + state.local.md write.

- [ ] **Step 1: Test scaffold + AC1 (valid spec → exit 0 + state write)**

`plugins/spec-distill/tests/test_spec_write_validator.sh`:

```bash
#!/usr/bin/env bash
# AC1-AC10 cases for PostToolUse hook spec-write-validator.py
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/spec-write-validator.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
WORK=$(mktemp -d -t specdistill-validator-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

# Helper: simulate PostToolUse stdin payload, optional env vars
run_hook() {
  local fpath="$1"
  local extra_env="${2:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath")
  cd "$WORK" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>&1
}

# Helper: read pending_review block from state.local.md (if any)
state_pending() {
  local f="$WORK/.claude/spec-distill/$1/state.local.md"
  [[ -f "$f" ]] && grep -E '^pending_review:' "$f"
}

# Case 1: AC1 — valid spec → exit 0 + state write
cp "$FIX/spec-valid.md" "$WORK/spec.md"
out=$(run_hook "$WORK/spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-1")
rc=$?
[[ $rc -eq 0 ]] && state_pending "test-1" >/dev/null \
  && note PASS "AC1: valid spec exits 0 + pending_review recorded" \
  || note FAIL "AC1 failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 실패 확인**

```bash
bash plugins/spec-distill/tests/test_spec_write_validator.sh
```

Expected: 1 fail (hook 미존재).

- [ ] **Step 3: Hook 골격 작성 — `spec-write-validator.py` 최소 동작 (AC1 통과)**

```python
#!/usr/bin/env python3
"""spec-distill PostToolUse hook — Layer 1 structural validator.

- Reads PostToolUse JSON payload from stdin.
- Filters: tool must be Write/Edit/MultiEdit on `docs/superpowers/specs/**-{spec,design}.md`.
- spec mode: 11 sections + frontmatter + locked_decisions + ambiguity scan.
- design mode: ambiguity + placeholder scan only.
- On pass: writes `pending_review:` block to .claude/spec-distill/<session>/state.local.md.
- On fail: exit 2 + stderr; stdout `{"decision": "block", "reason": "..."}` for safety.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse  (or :validator)
- DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1  (Layer 1 only; skip state write)
- DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1  (skip design.md)
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PARSE_LIB = SCRIPT_DIR.parent / "scripts" / "parse_spec_structure.py"
BLACKLIST = SCRIPT_DIR.parent / "scripts" / "ambiguity-blacklist.txt"
PATH_PREFIX = "docs/superpowers/specs/"


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:PostToolUse", "spec-distill:validator"):
        if token in skip_tokens:
            return True
    return False


def resolve_mode(file_path: str) -> str | None:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    if file_path.endswith("-design.md"):
        if os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1":
            return None
        return "design"
    return None


def call_parser(sub: str, *args: str) -> dict:
    cp = subprocess.run(
        ["python3", str(PARSE_LIB), sub, *args],
        capture_output=True, text=True, check=False,
    )
    if cp.returncode != 0:
        return {"_error": cp.stderr.strip() or f"parser rc={cp.returncode}"}
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        return {"_error": f"parser bad json: {e}"}


def write_state(session_id: str, path: str, mode: str) -> None:
    state_dir = Path(".claude/spec-distill") / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if state_file.exists():
        body = state_file.read_text(encoding="utf-8")
        # Remove existing pending_review: block (deterministic re-write)
        body = re.sub(r"^pending_review:\n(?:  .*\n)*", "", body, flags=re.MULTILINE)
        state_file.write_text(body.rstrip() + "\n" + block, encoding="utf-8")
    else:
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )


def emit_block(reasons: list[str]) -> None:
    print(
        json.dumps({"decision": "block", "reason": "\n".join(reasons)}),
        flush=True,
    )
    for r in reasons:
        print(f"[spec-distill] {r}", file=sys.stderr)


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # graceful degradation; not our payload
    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    mode = resolve_mode(file_path)
    if mode is None:
        return 0  # out of scope

    # Layer 1 mechanical checks
    reasons: list[str] = []
    if mode == "spec":
        fm = call_parser("frontmatter", file_path)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        ld = call_parser("locked-decisions", file_path)
        if ld.get("errors"):
            reasons.append("locked_decisions errors: " + "; ".join(ld["errors"]))
        secs = call_parser("sections", file_path)
        missing = secs.get("missing", [])
        if missing:
            reasons.append(f"missing sections: {missing}")

    amb = call_parser("ambiguity", file_path, str(BLACKLIST))
    for hit in amb.get("hits", []):
        reasons.append(
            f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\""
        )

    if mode == "design":
        ph = call_parser("placeholders", file_path)
        for hit in ph.get("hits", []):
            reasons.append(
                f"placeholder hit: {hit['token']} at line {hit['line']}"
            )

    if reasons:
        emit_block(reasons)
        return 2

    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
        write_state(session_id, file_path, mode)

    # Advisory systemMessage
    print(
        json.dumps({
            "systemMessage": (
                f"[spec-distill] {mode} structural OK. "
                "Reviewer will be dispatched at turn end."
            )
        }),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: AC1 통과 확인**

```bash
chmod +x plugins/spec-distill/hooks/spec-write-validator.py
bash plugins/spec-distill/tests/test_spec_write_validator.sh
```

Expected: `1 passed, 0 failed`.

- [ ] **Step 5: AC2–AC10 케이스 추가**

`test_spec_write_validator.sh` 의 `summary` 줄 *위*에 다음 추가:

```bash
# Case 2: AC2 — missing Goals → exit 2 + stderr matches
cp "$FIX/spec-missing-goals.md" "$WORK/spec2.md"
out=$(run_hook "$WORK/spec2.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:.*#goals" \
  && [[ ! -f "$WORK/.claude/spec-distill/test-2/state.local.md" ]] \
  && note PASS "AC2: missing Goals → exit 2 + matching stderr + no state" \
  || note FAIL "AC2 failed (rc=$rc out=$out)"

# Case 3: AC3 — ambiguity hit on line 12
cp "$FIX/spec-ambiguity-line12.md" "$WORK/spec3.md"
out=$(run_hook "$WORK/spec3.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-3")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q "ambiguity hit:" \
  && echo "$out" | grep -q "line 12" \
  && echo "$out" | grep -q "works correctly" \
  && note PASS "AC3: ambiguity hit at line 12 detected" \
  || note FAIL "AC3 failed (rc=$rc out=$out)"

# Case 4: AC4 — ~escape allowed → exit 0
cp "$FIX/spec-ambiguity-escaped.md" "$WORK/spec4.md"
out=$(run_hook "$WORK/spec4.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-4")
rc=$?
[[ $rc -eq 0 ]] && note PASS "AC4: ~escape prefix passes" \
  || note FAIL "AC4 failed (rc=$rc out=$out)"

# Case 5: AC5 — out-of-scope path → silent exit 0
echo "# unrelated" > "$WORK/README.md"
payload='{"tool_name":"Write","tool_input":{"file_path":"'"$WORK/README.md"'"}}'
out=$(echo "$payload" | python3 "$HOOK" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && note PASS "AC5: out-of-scope path silent exit 0" \
  || note FAIL "AC5 failed (rc=$rc out=$out)"

# Case 6: AC6 — design.md no-frontmatter → exit 0 + mode: design
# We need an in-scope path; rename our fixture
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-test-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-6")
rc=$?
[[ $rc -eq 0 ]] && grep -q 'mode: design' "$WORK/.claude/spec-distill/test-6/state.local.md" \
  && note PASS "AC6: design.md no-frontmatter exits 0 + mode: design" \
  || note FAIL "AC6 failed (rc=$rc out=$out)"

# Case 7: AC7 — design.md with TBD → exit 2 + placeholder hit
cp "$FIX/design-tbd.md" "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-7")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q 'placeholder hit:' \
  && echo "$out" | grep -q 'TBD' \
  && note PASS "AC7: design.md TBD detected" \
  || note FAIL "AC7 failed (rc=$rc out=$out)"

# Case 8: AC8 — DEVBREW_DISABLE_SPEC_DISTILL=1 silent
cp "$FIX/spec-valid.md" "$WORK/spec8.md"
out=$(run_hook "$WORK/spec8.md" "DEVBREW_DISABLE_SPEC_DISTILL=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-8")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-8/state.local.md" ]] \
  && note PASS "AC8: DEVBREW_DISABLE_SPEC_DISTILL=1 silent" \
  || note FAIL "AC8 failed (rc=$rc out=$out)"

# Case 9: AC9 — DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1: Layer 1 runs, no state write
cp "$FIX/spec-valid.md" "$WORK/spec9.md"
out=$(run_hook "$WORK/spec9.md" "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-9")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-9/state.local.md" ]] \
  && note PASS "AC9: SKIP_AUTOREVIEW skips Layer 2" \
  || note FAIL "AC9 failed (rc=$rc out=$out)"

# Case 10: AC10 — DESIGN_MODE_DISABLE skips design.md
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md" "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-10")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-10/state.local.md" ]] \
  && note PASS "AC10: DESIGN_MODE_DISABLE skips design.md silently" \
  || note FAIL "AC10 failed (rc=$rc out=$out)"
```

- [ ] **Step 6: 모든 케이스 통과 확인**

```bash
bash plugins/spec-distill/tests/test_spec_write_validator.sh
```

Expected: `10 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/tests/test_spec_write_validator.sh
git commit -m "feat(spec-distill): PostToolUse hook spec-write-validator with AC1-AC10"
```

---

## Task 9: `review-dispatch.py` Stop hook (TDD)

**Files:**
- Create: `plugins/spec-distill/hooks/review-dispatch.py`
- Create: `plugins/spec-distill/tests/test_review_dispatch.sh`

AC11–AC13. Stop hook은 *state.local.md를 직접 read*해서 `pending_review:` block 존재 시 systemMessage 주입 → dispatch 후 block 제거 + `last_dispatched_at` set.

- [ ] **Step 1: Test scaffold (AC11)**

`plugins/spec-distill/tests/test_review_dispatch.sh`:

```bash
#!/usr/bin/env bash
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-dispatch-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

setup_state() {
  local sid="$1"; shift
  local body="${1:-}"
  mkdir -p "$WORK/.claude/spec-distill/$sid"
  printf '%s' "$body" > "$WORK/.claude/spec-distill/$sid/state.local.md"
}

run_hook() {
  local sid="$1"
  cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    bash -c "echo '{}' | python3 '$HOOK'" 2>&1
}

# Case 11: AC11 — pending_review present → systemMessage emit
setup_state "test-11" "---
session_id: test-11
---

pending_review:
  path: /tmp/some-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-11")
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"systemMessage"' \
  && echo "$out" | grep -q 'MANDATORY' \
  && echo "$out" | grep -q '/tmp/some-spec.md' \
  && echo "$out" | grep -q 'reviewing-spec' \
  && note PASS "AC11: pending_review triggers systemMessage with required tokens" \
  || note FAIL "AC11 failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 실패 확인**

```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
```

Expected: 1 fail (hook 미존재).

- [ ] **Step 3: Stop hook 구현**

`plugins/spec-distill/hooks/review-dispatch.py`:

```python
#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer.

Reads state.local.md for the current session.  If `pending_review:` block
is present AND last_dispatched_at is empty or older than the redispatch TTL,
emits stdout `{"systemMessage": "..."}` to mandate next-turn dispatch of
reviewing-spec skill against the recorded spec path.

After emit, rewrites state.local.md: pending_review block removed, `last_dispatched_at`
set to now.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)
"""
import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>.+)\n  mode:\s*(?P<mode>.+)\n  triggered_at:\s*(?P<triggered>.+)\n",
    re.MULTILINE,
)
LAST_DISPATCHED_RE = re.compile(r"^last_dispatched_at:\s*(.+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:Stop", "spec-distill:review-dispatch"):
        if token in skip_tokens:
            return True
    return False


def state_file_for(session_id: str) -> Path:
    return Path(".claude/spec-distill") / session_id / "state.local.md"


def parse_iso(s: str) -> datetime | None:
    s = s.strip()
    if not s or s.lower() == "null":
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def rewrite_state(path: Path, body: str, now: datetime) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  .*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    path.write_text(body, encoding="utf-8")


def main() -> int:
    if kill_switch_active():
        return 0
    session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
    state_path = state_file_for(session_id)
    if not state_path.exists():
        return 0
    body = state_path.read_text(encoding="utf-8")
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # TTL guard against self-ref cycle
    ttl_sec = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    now = datetime.now(timezone.utc)
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl_sec):
            return 0  # within guard window
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    msg = (
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출. "
        f"spec path: {spec_path}. mode: {mode}. "
        "다른 작업을 시작하기 전 reviewer agent dispatch."
    )
    print(json.dumps({"systemMessage": msg}), flush=True)
    rewrite_state(state_path, body, now)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: AC11 통과 확인**

```bash
chmod +x plugins/spec-distill/hooks/review-dispatch.py
bash plugins/spec-distill/tests/test_review_dispatch.sh
```

Expected: `1 passed, 0 failed`.

- [ ] **Step 5: AC12 + AC13 추가**

`test_review_dispatch.sh` 의 `summary` 줄 *위*에 추가:

```bash
# Case 12: AC12 — no pending_review → silent exit 0
setup_state "test-12" "---
session_id: test-12
---
"
out=$(run_hook "test-12")
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && note PASS "AC12: no pending_review silent" \
  || note FAIL "AC12 failed (rc=$rc out=$out)"

# Case 13: AC13 — dispatch removes pending_review + sets last_dispatched_at;
# second call within TTL is silent.
setup_state "test-13" "---
session_id: test-13
---

pending_review:
  path: /tmp/p.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out1=$(run_hook "test-13")
rc1=$?
out2=$(run_hook "test-13")
rc2=$?
[[ $rc1 -eq 0 ]] && [[ $rc2 -eq 0 ]] && [[ -z "$out2" ]] \
  && ! grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-13/state.local.md" \
  && grep -q '^last_dispatched_at:' "$WORK/.claude/spec-distill/test-13/state.local.md" \
  && note PASS "AC13: dispatch consumes block; re-fire within TTL silent" \
  || note FAIL "AC13 failed (rc1=$rc1 rc2=$rc2 out2=$out2)"
```

- [ ] **Step 6: 모두 통과 확인**

```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
```

Expected: `3 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_review_dispatch.sh
git commit -m "feat(spec-distill): Stop hook review-dispatch with AC11-AC13"
```

---

## Task 10: `hooks.json` PostToolUse + Stop 등록

**Files:**
- Modify: `plugins/spec-distill/hooks/hooks.json`

- [ ] **Step 1: 현 상태 확인**

```bash
jq . plugins/spec-distill/hooks/hooks.json
```

Expected: 기존 UserPromptSubmit + SessionStart hook 표시.

- [ ] **Step 2: PostToolUse + Stop 추가**

`plugins/spec-distill/hooks/hooks.json` 전체를 다음으로 교체:

```json
{
  "description": "spec-distill — UserPromptSubmit interview suggestion + SessionStart anchor + PostToolUse spec/design validator + Stop reviewer dispatch.",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/interview-trigger.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-anchor.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/spec-write-validator.py",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/review-dispatch.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: JSON validity 확인**

```bash
jq . plugins/spec-distill/hooks/hooks.json > /dev/null
```

Expected: exit 0.

- [ ] **Step 4: 기존 hook regression 확인**

```bash
bash plugins/spec-distill/tests/test_hooks.sh
```

Expected: 기존 test_hooks.sh 결과 변동 없음 (AC16).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json
git commit -m "feat(spec-distill): register PostToolUse + Stop hooks in hooks.json"
```

---

## Task 11: `reviewing-spec/SKILL.md` — Step 1 + Re-review cap update

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

C10 / G8 / AC18 충족.

- [ ] **Step 1: Step 1 텍스트 갱신 (file-based dispatch trigger 명시)**

`plugins/spec-distill/skills/reviewing-spec/SKILL.md`의 `## Steps` 섹션 첫 항목 (1. **Load state.local.md** ... 으로 시작):

```diff
-1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기. ...
+1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기. 또한 `pending_review:` block 존재 여부 확인. *이 skill은 PostToolUse hook이 spec/design 파일 write를 감지해 file ledger에 `pending_review:` block을 기록한 직후, Stop hook이 다음 turn에 systemMessage로 dispatch를 강제했기 때문에* 호출됨 — `pending_review:` block이 *없는 채로* invoke되면 manual override로 간주 (loud advisory). `session_id`가 unbound이거나 placeholder `<session-id>` 인 채로면 Step 3 cleanup이 charset 검증으로 자동 skip되지만, 사용자에게 명시적 통보 필요 (P14 + AP2).
```

(직접 편집: 위 변경의 *new* line으로 기존 line 교체.)

- [ ] **Step 2: "Re-review cap" 섹션 hard cap + stagnation early-exit 갱신**

기존:

```
### Re-review cap (rereview_count)

`rereview_count >= 3` 도달 시 (즉 4번째 reviewer dispatch 시도 시): 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부. (위 P1–P4와 별개 cap — 무한 review loop 방지.)
```

새로:

```
### Re-review cap (rereview_count, hybrid policy — v0.3.0 hook 통합)

두 조건 중 *하나라도* 충족 시 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부:

1. **Hard cap**: `rereview_count >= 5` 도달 시 (즉 6번째 reviewer dispatch 시도 시). 기존 v0.2.0의 cap=3을 v0.3.0에서 cap=5로 상향 — multi-round drift detection을 위한 budget 확장.
2. **Round-level stagnation early-exit**: spec-reviewer가 `verdict: needs_revise` + `Stagnation_signal: true` 를 반환한 경우, `rereview_count`와 무관하게 즉시 [5] Human Gate로 escalate. 이는 *수렴 실패 조기 감지* — issue가 새로 발견되지 않고 같은 항목이 반복 raise되는 상황을 한 라운드 안에 끝낸다.

기존 P3 row (`raised_count >= 3 AND dismissed_by_user == 0`)는 *per-issue* stagnation, 위 (2)는 *round-level* stagnation으로 trigger가 다르다.
```

- [ ] **Step 3: 갱신 검증 (AC18, V12)**

```bash
grep -E 'rereview_count >= 5' plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -E 'Stagnation_signal.*true.*Human Gate' plugins/spec-distill/skills/reviewing-spec/SKILL.md
```

Expected: 두 grep 모두 1+ matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): reviewing-spec hybrid cap (5 + stagnation early-exit) + hook trigger note"
```

---

## Task 12: `drafting-spec/SKILL.md` — Mode A/B handoff

**Files:**
- Modify: `plugins/spec-distill/skills/drafting-spec/SKILL.md`

- [ ] **Step 1: Mode A 종료 부분 갱신**

`Mode A: Initial draft` 의 마지막 step에서 *"reviewing-spec skill 호출"* 표현을 *"file write 직후 PostToolUse hook이 dispatch 강제 — 별도 호출 불필요"* 로 교체.

기존 (또는 유사 텍스트):

```
6. **Update state.local.md**: `phase: 3` (다음은 reviewer phase).
```

다음 문장 *바로 위*에 한 줄 추가:

```
> **v0.3.0+ 변경**: Step 5의 `Write` 직후 PostToolUse hook이 spec.md를 감지해 `pending_review:` block을 state.local.md에 기록하고, Stop hook이 다음 turn에 reviewer dispatch를 systemMessage로 강제한다. drafting-spec skill 본체가 `reviewing-spec` skill을 명시 호출하지 않아도 trigger 결정론적으로 발동.
```

- [ ] **Step 2: Mode B 종료 부분 같은 변경**

`Mode B: Revise per review` 의 마지막 step `8. **Re-dispatch reviewing-spec** for re-review.` 위에 동일 한 줄 추가.

```
> **v0.3.0+ 변경**: Step 6의 `Edit` 직후 hook이 동일 메커니즘으로 reviewing-spec dispatch를 강제. 단 `last_dispatched_at` TTL 가드로 self-ref cycle 방지 — Mode B의 정상 edit cycle은 TTL 만료 후 통과.
```

- [ ] **Step 3: 명시 reference 검증**

```bash
grep -c "v0.3.0+ 변경" plugins/spec-distill/skills/drafting-spec/SKILL.md
```

Expected: `2` (Mode A + Mode B 각 한 번).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/skills/drafting-spec/SKILL.md
git commit -m "docs(spec-distill): drafting-spec Mode A/B handoff note for v0.3.0 hooks"
```

---

## Task 13: README.md — Hooks Installed + Principles Instantiated

**Files:**
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: "Hooks Installed" 섹션 추가/갱신**

README 마지막 section *바로 앞*에 (혹은 기존 hooks 표가 있으면 그 표에) 다음 표 추가:

```markdown
## Hooks Installed

| Event | Script | 책임 | 왜 skill이 아닌가 |
|---|---|---|---|
| UserPromptSubmit | `hooks/interview-trigger.sh` | vague build/make 요청 감지 → advisory | 사용자 자동 prompt에 반응해야 함 (skill은 사용자가 invoke해야 동작). |
| SessionStart | `hooks/session-anchor.sh` | resumed session에 spec-distill anchor 표시 | session-level lifecycle event는 hook 전용. |
| PostToolUse | `hooks/spec-write-validator.py` | spec/design 파일 write 시 mechanical Layer 1 검증 + `pending_review:` ledger 기록 (v0.3.0) | spec writer가 *자기 작업을 자기가 검증*하는 회색지대를 file-system level에서 가로채는 것이 Law 2의 가장 강력한 구현. skill은 LLM이 invoke해야 동작하므로 trigger 결정론이 부족함. |
| Stop | `hooks/review-dispatch.py` | `pending_review:` block 있으면 systemMessage 주입으로 reviewer dispatch 강제 (v0.3.0) | turn boundary는 LLM의 메시지 형식과 무관한 결정론적 지점 — skill로는 hit 불가. |
```

- [ ] **Step 2: "Principles Instantiated" 섹션 갱신 — Law 2 강화 한 줄 추가**

기존 `### Three Laws` 의 `Law 2` 줄 *바로 아래*에 한 줄 추가:

```markdown
- **Law 2 강화 (v0.3.0)** — Writer/Reviewer 분리를 turn-boundary 결정론으로 끌어올림. PostToolUse가 spec/design write를 감지해 *해당 turn 안* structural gate를 차단(exit 2)하고, Stop hook이 *다음 turn 첫 액션*으로 reviewer dispatch를 systemMessage 주입으로 강제. file-based ledger (`state.local.md` `pending_review:` block)가 trans-hook coordination을 LLM 의지에서 분리.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): README Hooks Installed + Law 2 hook-level enforcement note"
```

---

## Task 14: plugin.json version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: plugin.json version bump 0.2.0 → 0.3.0**

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `"version": "0.2.0"` 를 `"version": "0.3.0"` 으로 교체.

- [ ] **Step 2: 검증 (AC14, V4)**

```bash
jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json
```

Expected: `0.3.0`.

- [ ] **Step 3: CHANGELOG entry 추가**

`plugins/spec-distill/CHANGELOG.md` 최상단 `# Changelog` 줄 *바로 아래* 다음 추가 (기존 `## [0.2.0]` 위):

```markdown

## [0.3.0] — 2026-05-16

### Added
- PostToolUse hook `hooks/spec-write-validator.py` — spec/design 파일 write를 file-system level에서 가로채 Layer 1 mechanical 검증 (11 sections, frontmatter, locked_decisions schema, ambiguity blacklist, design-mode placeholder scan).
- Stop hook `hooks/review-dispatch.py` — `pending_review:` ledger 기반 결정론적 reviewer dispatch (systemMessage 주입).
- `scripts/parse_spec_structure.py` — frontmatter / sections / locked-decisions / ambiguity / placeholders CLI subcommand 라이브러리.
- `scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 + `~` escape 지원.
- design.md (brainstorming upstream 산출물) 커버리지 — suffix-based mode 분기, frontmatter optional, ambiguity + placeholder만 검사.
- 7 fixture 파일 (`tests/fixtures/`) + `test_spec_write_validator.sh` + `test_review_dispatch.sh`.
- Kill switches: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<sec>`.

### Changed
- `reviewing-spec/SKILL.md` Step 1 — dispatch trigger가 hook-driven (file ledger `pending_review:` block) 임을 명시.
- `reviewing-spec/SKILL.md` Re-review cap — hard cap `>= 3` → `>= 5` + round-level stagnation early-exit (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate). multi-round drift detection을 위한 budget 확장.
- `drafting-spec/SKILL.md` Mode A/B — handoff 단계에서 명시 reviewing-spec 호출 불필요, hook이 결정론 dispatch함을 note.

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- PostToolUse exit 2 + stderr 차단 패턴 + stdout `{"decision":"block"}` 이중 안전.
```

- [ ] **Step 4: 검증 (AC15, V5)**

```bash
grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md
```

Expected: 1+ matches.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): bump to v0.3.0 + CHANGELOG entry"
```

---

## Task 15: Full automated suite + E2E manual evidence

**Files:**
- (no edits; verification only)
- Optional: `docs/superpowers/plans/2026-05-16-spec-distill-hook-review-evidence.md` (E2E log)

- [ ] **Step 1: 모든 자동 test 통과 확인 (V1, V2, V3, V12)**

```bash
bash plugins/spec-distill/tests/test_parse_spec_structure.sh
bash plugins/spec-distill/tests/test_spec_write_validator.sh
bash plugins/spec-distill/tests/test_review_dispatch.sh
bash plugins/spec-distill/tests/test_hooks.sh
grep -E 'rereview_count >= 5' plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -E 'Stagnation_signal.*true.*Human Gate' plugins/spec-distill/skills/reviewing-spec/SKILL.md
```

Expected: 모든 script exit 0 + 두 grep 모두 1+ matches.

- [ ] **Step 2: hooks.json + plugin.json validity (V4, V6)**

```bash
jq . plugins/spec-distill/hooks/hooks.json > /dev/null
jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json
```

Expected: exit 0, output `0.3.0`.

- [ ] **Step 3: Kill switch 회귀 (V7)**

```bash
DEVBREW_DISABLE_SPEC_DISTILL=1 bash plugins/spec-distill/tests/test_spec_write_validator.sh \
  || echo "expected: AC1 fails (state not written), AC8 passes"
```

(test script 자체는 fail nodes를 기록함. 정확한 검증: silent 동작 확인은 AC8이 통과하는 것.)

- [ ] **Step 4: E2E manual evidence (V9, V10, V11) — 사용자 확인 필요**

> 다음 시나리오를 실제 Claude Code 세션에서 수행하고 결과를 `docs/superpowers/plans/2026-05-16-spec-distill-hook-review-evidence.md`에 기록:
>
> **V9**: `/interview` 명령으로 spec-distill 워크플로우 시작 → spec.md 작성 → 다음 turn에 reviewer dispatch 강제됐는지 확인. structural fail 케이스 (예: Goals 섹션 누락)에서 tool result에 "blocked" 표시 확인.
>
> **V10**: superpowers brainstorming 세션 시작 → `-design.md` 작성 → reviewer agent dispatch 강제됐는지 확인.
>
> **V11**: 본 spec 파일 자체 (`docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md`)를 `touch` + 한 줄 수정 → hook 1회 fire 후 TTL 가드로 추가 fire 방지 확인. `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=10` fixture로 테스트 가능.

- [ ] **Step 5: Final commit + PR**

```bash
git log --oneline -20  # verify clean history
git push -u origin worktree-feature+spec-distill-hook-review
gh pr create --base main --title "feat(spec-distill): hook-driven deterministic spec/design review (v0.3.0)" --body "$(cat <<'EOF'
## Summary
- Adds PostToolUse + Stop hooks to spec-distill that move spec/design review trigger AND dispatch out of LLM volition into file-system + turn-boundary mechanisms.
- Covers both spec-distill (`-spec.md`) and brainstorming-upstream (`-design.md`) via path-suffix routing.
- Updates reviewing-spec cap policy: hard cap 3 → 5 + stagnation early-exit (validated by this PR's own 5-round spec review trajectory).

## Spec
- [docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md](docs/superpowers/specs/2026-05-16-spec-distill-hook-review-design.md) (v1.3.0, locked after 5 rounds of adversarial review)

## Test plan
- [ ] `bash plugins/spec-distill/tests/test_parse_spec_structure.sh` (11 passed)
- [ ] `bash plugins/spec-distill/tests/test_spec_write_validator.sh` (10 passed, AC1–AC10)
- [ ] `bash plugins/spec-distill/tests/test_review_dispatch.sh` (3 passed, AC11–AC13)
- [ ] `bash plugins/spec-distill/tests/test_hooks.sh` (regression, AC16)
- [ ] `jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json` → "0.3.0" (AC14)
- [ ] `grep -E '^## \[0\.3\.0\]' plugins/spec-distill/CHANGELOG.md` (AC15)
- [ ] Two grep checks for reviewing-spec hybrid cap (AC18)
- [ ] Manual: V9 spec-distill /interview cycle (E2E)
- [ ] Manual: V10 brainstorming `-design.md` cycle (E2E)
- [ ] Manual: V11 self-referential cycle with TTL guard (E2E)
EOF
)"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Implemented in task |
|---|---|
| G1 (확장 PostToolUse + Stop in spec-distill) | T8, T9, T10 |
| G2 (2-layer 결정론) | T8 (Layer 1), T9 (Layer 2) |
| G3 (matcher tool-name regex + in-script path filter) | T8 `resolve_mode`, T10 hooks.json matcher |
| G4 (brainstorming -design.md 통합 무수정) | T8 design mode, fixtures T2 |
| G5 (reviewing-spec routing table 무수정 + Step 1 갱신만) | T11 |
| G6 (kill switches) | T8/T9 env var handling |
| G7 (file-based coordination, not transcript signal) | T9 state.local.md read |
| G8 (hybrid cap=5 + stagnation early-exit) | T11 |
| LD1–LD10 | 모두 위 task 합으로 implementation |
| C1 (10s timeout) | T10 hooks.json timeout |
| C2 (exit 2 + JSON block 이중 안전) | T8 `emit_block` |
| C3 (state.local.md in-flight migration) | T8 write_state preserves existing body |
| C5 (ambiguity-blacklist.txt separate) | T6 |
| C7 (state.local.md ledger coordination) | T8 + T9 |
| C8 (Concrete Next Action verdict branching) | spec only — 이 plan은 모든 path 명시 |
| C9 (V8 plan-phase prereq) | T1 |
| C10 (reviewing-spec SKILL.md cap update) | T11 |
| AC1–AC10 (spec-write-validator) | T8 |
| AC11–AC13 (review-dispatch) | T9 |
| AC14 (plugin.json version) | T14 |
| AC15 (CHANGELOG entry) | T14 |
| AC16 (regression hooks.sh) | T10 step 4 |
| AC17 (self-reference V11) | T15 manual |
| AC18 (grep cap) | T11 step 3 + T15 step 1 |
| AC19 (meta evidence) | PR description |
| V1–V13 | T15 |
| Files to Modify 신규 4 / 수정 6 / 테스트 신규 3 | T2–T14 모두 cover |

Gap 없음.

### Placeholder scan

`grep -nE 'TBD|TODO|XXX|FIXME|fill in|Similar to' docs/superpowers/plans/2026-05-16-spec-distill-hook-review.md` 결과 본 파일에는 spec의 TBD를 *언급*하는 텍스트만 있고 plan 자체에는 unresolved placeholder 없음. Plan steps의 모든 code block은 완전한 동작 가능 코드.

### Type consistency

- `parse_spec_structure.py` 의 CLI subcommand 이름: `frontmatter` / `sections` / `locked-decisions` / `ambiguity` / `placeholders` — T3–T7 일관 사용.
- `state.local.md` field 이름: `pending_review:` block (path/mode/triggered_at), `last_dispatched_at` — T8, T9, fixtures 모두 동일.
- env var 이름: `DEVBREW_SPEC_DISTILL_SESSION_ID`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`, `DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS` — T8, T9, T15 모두 일치.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-distill-hook-review.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
