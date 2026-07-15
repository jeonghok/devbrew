# spec-distill codex co-reviewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill Phase 3(design-doc 리뷰)에 codex를 병렬 독립 co-reviewer로 추가해, 보수적 병합으로 codex가 Claude의 approved를 뒤집을 수 있게 하고 codex 반복 이슈를 stagnation 원장으로 포착한다.

**Architecture:** `reviewing-spec` SKILL이 Claude `spec-reviewer`와 vendored codex 경로를 같은 design doc에 독립 실행 → `merge_review.py`(단일 결정론 merge/ledger 엔진)가 양쪽 출력을 스크립트로 파싱해 보수적 병합·issue_id 중앙화·통합-원장 stagnation 스캔을 수행 → 기존 routing table에 `combined_verdict` + stagnation flags 투입. codex는 `codex exec -s read-only` OS 샌드박스(Law 2 구조적)에서 돌고, 부재/실패 시 Claude-only로 loud degrade한다. quality-gates에 런타임 의존 없이 필요한 스크립트를 vendor한다.

**Tech Stack:** bash (POSIX-ish, macOS `/bin/bash` 3.2 호환), python3 (stdlib only — PyYAML 등 외부 의존 금지), codex CLI(optional, `-s read-only --json`).

## Global Constraints

이 절의 값은 매 task의 요구사항에 암묵적으로 포함된다. spec §4·§6에서 verbatim.

- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json` `version` 0.19.3 → **0.20.0** (minor — 새 review surface). 같은 PR에서 CHANGELOG `## [0.20.0] — 2026-07-15` + README 동기화 (C6).
- **kill switch (두 개, 독립)**: 전역 `DEVBREW_DISABLE_SPEC_DISTILL=1` (기존, 즉시 abort) + codex 전용 **`DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`** (신규 — codex만 skip, Claude 리뷰 정상). 어떤 경로도 kill switch 존중 거부 금지 (C5).
- **python은 stdlib only**: 모든 신규/vendored python 스크립트는 표준 라이브러리만 사용. YAML emit은 hand-roll(형제 `codex_findings_to_yaml.py` 선례), 구조화 파싱이 필요한 지점은 JSON(`json` 모듈)로.
- **결정론 (Law 1/C2)**: routing·병합 precedence·issue_id·stagnation 스캔은 전부 스크립트가 소유. SKILL.md prose의 LLM 암산 금지.
- **순환 AC-주입 회피 (C3)**: codex 경로는 `discover-spec.sh`를 **호출하지 않는다** (리뷰 대상 doc이 `docs/superpowers/specs/` 하위라 자기-주입 순환).
- **mktemp footgun 가드 (C7)**: 모든 scratch dir 대입은 trap arm *전에* `|| exit 0`(또는 `|| { echo ...>out; exit 0; }`) — `cd ""` repo-삭제 footgun 방지. graceful(exit 0) + loud.
- **verbatim 저장 (C8)**: orchestrator(SKILL)는 spec-reviewer subagent raw 출력을 `--claude-output` 파일에 **그대로** 저장 — 요약·바꿔쓰기 금지. 파싱은 `merge_review.py`가 그 파일에서.
- **graceful degradation + loud logging (C4)**: codex 부재/실패는 crash가 아니라 capability downgrade + 사용자가 출력에서 인지하는 loud advisory. fail-open(조용한 통과)도 fail-closed(infra 실패로 spurious block)도 금지.
- **severity vocab**: codex 프롬프트와 spec-reviewer 모두 `{block, high, medium}` (qg의 CRITICAL/IMPORTANT/SUGGESTION 주입 금지 — vocab drift 방지).
- **테스트 실행**: python은 `python3 -m unittest`, bash는 shebang 셸로 repo root에서. 회귀 락은 **body-unique 문구를 섹션 윈도우서 grep + mutation으로 이빨 증명**(header-satisfiable 함정 회피).
- **파일 경로는 전부 `plugins/spec-distill/` 하위**. 이 plan의 상대 경로는 repo root(`/Users/jeonghokim/Downloads/devbrew`) 기준.

### 공유 데이터 계약 (여러 task가 참조 — 한 곳에 고정)

**spec-reviewer sentinel block** (Task 8이 emit, Task 6이 파싱):
- fence info-string은 **정확히** `spec-review-issues` (리뷰 대상 doc의 ` ```yaml `/` ```json ` fence와 구분).
- body는 **JSON**: `{"issues": [{"category": "...", "target_section": "#anchor", "severity": "block|high|medium", "message": "..."}]}`. 이슈 없으면 `{"issues": []}`.
- verdict는 이 블록과 **독립**으로 top-level `**Status:** <verdict>` 라인에 (기존 포맷 유지).

**codex findings YAML** (Task 4가 emit, Task 6이 파싱) — `codex_findings_to_yaml.py` 출력:
```
findings:
  - agent: codex-reviewer
    category: <6-cat>
    target_section: "#anchor"
    severity: block|high|medium
    line: <int, optional>
    confidence: <int>
    summary: "..."
    proposed_fix: "..."
meta:
  codex_failed: false
```

**merge_review stdout YAML** (Task 6/7이 emit, SKILL이 routing에 투입):
```
combined_verdict: approved|needs_revise|needs_interview
claude_verdict: approved|needs_revise|needs_interview|null
codex_verdict: approved|needs_revise|null
codex_degraded: true|false
claude_degraded: true|false
claude_verdict_unrecoverable: true|false
stagnation:
  per_issue: [<id>, ...]
  round_level: true|false|inconclusive
issue_history:
  - {id: <hex12>, raised_count: <int>, dismissed_by_user: <int>, source: claude|codex|both, resolved: true|false}
advisory:
  - "..."
```

**merge_review `--history` 파일**: JSON `{"issue_history": [{"id": "...", "raised_count": N, "dismissed_by_user": N, "source": "...", "resolved": bool}, ...]}`. 부재/빈/파싱불가 → 빈 history(graceful). merge_review가 read-modify-write(원자적) — 모델 전사 없음.

**issue_id**: `sha256_short = hashlib.sha256(f"{category}:{target_section}".encode()).hexdigest()[:12]` (Task 2가 정의, Task 6이 호출).

---

## Task 1: `detect_codex.sh` (vendor+adapt) + detect 테스트 인프라

**Files:**
- Create: `plugins/spec-distill/scripts/detect_codex.sh`
- Create: `plugins/spec-distill/tests/mocks/bin-stubs/timeout`
- Create: `plugins/spec-distill/tests/mocks/bin-stubs/gtimeout`
- Create: `plugins/spec-distill/tests/mocks/safe-v1/codex`
- Create: `plugins/spec-distill/tests/mocks/bad-version/codex`
- Test: `plugins/spec-distill/tests/test_detect_codex.sh`

**Interfaces:**
- Produces: `detect_codex.sh` — no args; reads env; stdout YAML `codex_available: true|false` (+ `skip_reason:` when false, + `codex_path:`/`codex_version:` when true); always exit 0.
- Consumes: nothing (leaf).

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_detect_codex.sh`

```bash
#!/usr/bin/env bash
# AC1 + AC2 + AC15(codex-only) — 6-case probe + kill-switch var mutation teeth.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
chmod +x "$MOCKS"/bin-stubs/* "$MOCKS"/safe-v1/* "$MOCKS"/bad-version/* 2>/dev/null || true

pass=0; fail=0
ag() { local d="$1" o="$2" p="$3"; if echo "$o" | grep -q "$p"; then echo "  PASS: $d"; pass=$((pass+1)); else echo "  FAIL: $d (want: $p)"; echo "$o" | sed 's/^/    /'; fail=$((fail+1)); fi; }

# Case 1: not installed
ag "not_installed" "$(PATH=/usr/bin:/bin bash "$PROBE")" 'skip_reason: not_installed'
# Case 2: ok
ag "available" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'codex_available: true'
# Case 3: codex-only kill switch (AC1 + AC15 codex-only)
ag "kill_switch" "$(DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1 bash "$PROBE")" 'skip_reason: kill_switch'
# Case 4a/4b: recursion guard
ag "inside CODEX_SANDBOX" "$(CODEX_SANDBOX=1 bash "$PROBE")" 'skip_reason: inside_codex_sandbox'
ag "inside CODEX_SESSION_ID" "$(CODEX_SESSION_ID=abc bash "$PROBE")" 'skip_reason: inside_codex_sandbox'
# Case 5: auth missing
mkdir -p "$TMP/nohome"
ag "auth_missing" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/nohome" bash "$PROBE")" 'skip_reason: auth_missing'
# Case 6: known bad version
ag "known_bad_version" "$(PATH="$MOCKS/bad-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: known_bad_version'
# Case 7: timeout bin missing
ag "timeout_binary_missing" "$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: timeout_binary_missing'

# AC1 regression: qg var DEVBREW_DISABLE_QG_CODEX must NOT affect this script.
ag "qg var inert" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")" 'codex_available: true'

# Teeth: the script must key the kill switch on the spec-distill var (body grep).
grep -q 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$PROBE" \
  && { echo "  PASS: kill-switch var name"; pass=$((pass+1)); } \
  || { echo "  FAIL: kill-switch var name (expect DEVBREW_DISABLE_SPEC_DISTILL_CODEX)"; fail=$((fail+1)); }
grep -q 'DEVBREW_DISABLE_QG_CODEX' "$PROBE" \
  && { echo "  FAIL: stale qg var present"; fail=$((fail+1)); } \
  || { echo "  PASS: no stale qg var"; pass=$((pass+1)); }

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
```

- [ ] **Step 2: Create the mock stubs**

`plugins/spec-distill/tests/mocks/bin-stubs/timeout` (and identical `gtimeout`):
```bash
#!/usr/bin/env bash
# Stub: timeout N cmd [args...] — strip the timeout N and run cmd directly.
shift  # remove N
exec "$@"
```

`plugins/spec-distill/tests/mocks/safe-v1/codex`:
```bash
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "1.0.0" ;;
  *) echo "mock-codex-safe-v1: unexpected arg $*" >&2; exit 2 ;;
esac
```

`plugins/spec-distill/tests/mocks/bad-version/codex`:
```bash
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "0.120.1" ;;
  *) echo "mock-codex-bad-version: unexpected arg $*" >&2; exit 2 ;;
esac
```

- [ ] **Step 3: Run test to verify it fails**

Run: `chmod +x plugins/spec-distill/tests/mocks/bin-stubs/* plugins/spec-distill/tests/mocks/safe-v1/* plugins/spec-distill/tests/mocks/bad-version/*; bash plugins/spec-distill/tests/test_detect_codex.sh`
Expected: FAIL — `detect_codex.sh` does not exist.

- [ ] **Step 4: Write `plugins/spec-distill/scripts/detect_codex.sh`**

qg 원본을 vendor하되 kill-switch var만 교체(그 외 recursion/install/auth/timeout/version 로직 보존):
```bash
#!/usr/bin/env bash
# detect_codex.sh — emit YAML manifest describing Codex CLI availability.
# Vendored from quality-gates (spec-distill design §6 #1). Read-only, exit 0
# always (graceful degradation). ONLY adaptation vs qg: the codex-only kill
# switch var is DEVBREW_DISABLE_SPEC_DISTILL_CODEX (not DEVBREW_DISABLE_QG_CODEX).

set -u

emit_skip() {
  printf 'codex_available: false\n'
  printf 'skip_reason: %s\n' "$1"
}

# 1. Kill switch (codex-only opt-out; spec-distill namespace)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL_CODEX:-0}" == "1" ]]; then
  emit_skip 'kill_switch'
  exit 0
fi

# 2. Recursion guard: already inside a Codex sandbox
if [[ -n "${CODEX_SANDBOX:-}" || -n "${CODEX_SESSION_ID:-}" ]]; then
  emit_skip 'inside_codex_sandbox'
  exit 0
fi

# 3. Install check
CODEX_PATH="$(command -v codex 2>/dev/null || true)"
if [[ -z "$CODEX_PATH" || "$CODEX_PATH" != /* ]]; then
  emit_skip 'not_installed'
  exit 0
fi

# 4. Auth check
if [[ -z "${CODEX_API_KEY:-}" && -z "${OPENAI_API_KEY:-}" && ! -f "${HOME:-/nonexistent}/.codex/auth.json" ]]; then
  emit_skip 'auth_missing'
  exit 0
fi

# 5. Timeout binary check (prevents pipeline freeze on hung version probe)
TIMEOUT_BIN=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)
if [ -z "$TIMEOUT_BIN" ]; then
  cat <<YAML
codex_available: false
codex_path: ""
codex_version: ""
skip_reason: timeout_binary_missing
YAML
  exit 0
fi

# 6. Version check (known-bad regex: 0.120.0/1/2 stdin deadlock)
CODEX_VERSION="$("$TIMEOUT_BIN" 5 codex --version 2>/dev/null | head -1 || echo unknown)"
if echo "$CODEX_VERSION" | grep -Eq '(^|[^0-9.])0\.120\.(0|1|2)([^0-9.]|$)'; then
  printf 'codex_available: false\n'
  printf 'skip_reason: known_bad_version\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  exit 0
fi

# 7. All checks pass
printf 'codex_available: true\n'
printf 'codex_path: %s\n' "$CODEX_PATH"
printf 'codex_version: %s\n' "$CODEX_VERSION"
exit 0
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_detect_codex.sh`
Expected: PASS — Total 11, Fail 0.

- [ ] **Step 6: Commit**

```bash
chmod +x plugins/spec-distill/scripts/detect_codex.sh
git add plugins/spec-distill/scripts/detect_codex.sh plugins/spec-distill/tests/test_detect_codex.sh plugins/spec-distill/tests/mocks/bin-stubs plugins/spec-distill/tests/mocks/safe-v1 plugins/spec-distill/tests/mocks/bad-version
git commit -m "feat(spec-distill): vendor detect_codex.sh with spec-distill kill switch"
```

---

## Task 2: `compute_issue_id.py` (issue_id 중앙화 helper)

**Files:**
- Create: `plugins/spec-distill/scripts/compute_issue_id.py`
- Test: `plugins/spec-distill/tests/test_compute_issue_id.py`

**Interfaces:**
- Produces: `compute_issue_id.py` — CLI `compute_issue_id.py <category> <target_section>` → stdout: 12-hex-char id + newline; importable `compute(category: str, target_section: str) -> str`.
- Consumes: nothing (leaf). Called by `merge_review.py` (Task 6) per issue.

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_compute_issue_id.py`

```python
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "compute_issue_id.py"


def run(cat, sec):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), cat, sec],
        capture_output=True, text=True,
    )
    return r.returncode, r.stdout.strip()


class TestComputeIssueId(unittest.TestCase):
    def test_deterministic(self):
        rc1, id1 = run("ambiguity", "#2-goals")
        rc2, id2 = run("ambiguity", "#2-goals")
        self.assertEqual(rc1, 0)
        self.assertEqual(id1, id2)  # AC8: same input → same id

    def test_shape(self):
        _, id1 = run("isolation", "#6-components")
        self.assertEqual(len(id1), 12)  # 12 hex chars
        self.assertTrue(all(c in "0123456789abcdef" for c in id1))

    def test_different_section_differs(self):
        _, a = run("ambiguity", "#2-goals")
        _, b = run("ambiguity", "#3-non-goals")
        self.assertNotEqual(a, b)  # AC8: different section → different id

    def test_different_category_differs(self):
        _, a = run("ambiguity", "#2-goals")
        _, b = run("testing", "#2-goals")
        self.assertNotEqual(a, b)

    def test_importable(self):
        sys.path.insert(0, str(SCRIPT.parent))
        import compute_issue_id
        self.assertEqual(
            compute_issue_id.compute("ambiguity", "#2-goals"),
            run("ambiguity", "#2-goals")[1],
        )

    def test_arg_error(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "only-one"],
                           capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)  # usage error


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest plugins.spec-distill.tests.test_compute_issue_id -v` (또는 `cd plugins/spec-distill && python3 -m unittest tests.test_compute_issue_id -v` — but this dir has a hyphen; run from repo root with file path:) `python3 plugins/spec-distill/tests/test_compute_issue_id.py`
Expected: FAIL — `compute_issue_id.py` not found.

- [ ] **Step 3: Write `plugins/spec-distill/scripts/compute_issue_id.py`**

```python
#!/usr/bin/env python3
"""compute_issue_id.py — deterministic centralized issue-id helper.

spec-distill design §6 #5 / §8. Both reviewers' issues (Claude sentinel block,
codex findings) go through this single function so that identical
(category, target_section) pairs collide on the same id — the precondition for
cross-reviewer corroboration and cross-round stagnation matching. Replaces the
old LLM in-head sha256 (unreliable). stdlib only.

  issue_id = sha256(f"{category}:{target_section}")[:12 hex]

CLI:  compute_issue_id.py <category> <target_section>   → id + newline on stdout
"""

from __future__ import annotations

import hashlib
import sys

ID_LEN = 12


def compute(category: str, target_section: str) -> str:
    key = f"{category}:{target_section}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:ID_LEN]


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <category> <target_section>", file=sys.stderr)
        return 2
    print(compute(sys.argv[1], sys.argv[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/spec-distill/tests/test_compute_issue_id.py`
Expected: PASS — OK (6 tests).

- [ ] **Step 5: Commit**

```bash
chmod +x plugins/spec-distill/scripts/compute_issue_id.py
git add plugins/spec-distill/scripts/compute_issue_id.py plugins/spec-distill/tests/test_compute_issue_id.py
git commit -m "feat(spec-distill): add compute_issue_id.py deterministic issue-id helper"
```

---

## Task 3: `build_spec_codex_prompt.py` (design-doc 전용 codex 프롬프트)

**Files:**
- Create: `plugins/spec-distill/scripts/build_spec_codex_prompt.py`
- Test: `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`

**Interfaces:**
- Produces: `build_spec_codex_prompt.py <design_doc_file>` → stdout: assembled prompt. **파일 경로만** 입력(inline 금지, injection 안전). 6개 판단형 category + finding당 `category`/`target_section`/`severity`(vocab `block|high|medium`)/`confidence`/`summary`/`proposed_fix`를 fenced JSON으로 요청.
- Consumes: nothing. Called by `run_spec_codex_reviewer.sh` (Task 5).

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`

```bash
#!/usr/bin/env bash
# AC3 + AC4 — 6 judgment categories + structured emit request + path-only input.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD="$PLUGIN_ROOT/scripts/build_spec_codex_prompt.py"
TMP="$(mktemp -d -t sd-build-prompt-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
DOC="$TMP/some-design.md"
printf '# X design\n\n## 2. Goals\nMake it robust.\n' > "$DOC"

pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

OUT="$(python3 "$BUILD" "$DOC")"

# AC3: all 6 judgment categories present in the prompt
for c in placeholder ambiguity scope_creep approaches_comparison isolation testing; do
  echo "$OUT" | grep -q "$c" && note PASS "category $c present" || note FAIL "category $c missing"
done

# AC3: severity vocab is spec-distill {block,high,medium}, NOT qg vocab
echo "$OUT" | grep -qE 'block[^A-Za-z]*\|?[^A-Za-z]*high[^A-Za-z]*\|?[^A-Za-z]*medium' \
  && note PASS "severity vocab block|high|medium" || note FAIL "severity vocab wrong"
echo "$OUT" | grep -qE 'CRITICAL|IMPORTANT|SUGGESTION' \
  && note FAIL "qg vocab leaked (CRITICAL/IMPORTANT/SUGGESTION)" || note PASS "no qg vocab"

# AC3: each finding requests category + target_section
echo "$OUT" | grep -q 'category' && echo "$OUT" | grep -q 'target_section' \
  && note PASS "requests category + target_section" || note FAIL "missing category/target_section request"

# AC3: doc content is embedded (path was read, not ignored)
echo "$OUT" | grep -q 'Make it robust' && note PASS "doc content embedded" || note FAIL "doc content not embedded"

# AC4: path-only — passing inline content as argv must NOT be treated as a doc.
# The script takes exactly one arg (a path); inline string that isn't a file → error.
python3 "$BUILD" '# inline content ## 2. Goals not a path' >/dev/null 2>&1 \
  && note FAIL "AC4: inline content accepted (should require a file path)" \
  || note PASS "AC4: inline non-path rejected"

# handoff_incomplete is OUT of codex scope (mechanical check) — must NOT be requested.
echo "$OUT" | grep -q 'handoff_incomplete' \
  && note FAIL "handoff_incomplete wrongly in codex scope" || note PASS "handoff_incomplete excluded"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Write `plugins/spec-distill/scripts/build_spec_codex_prompt.py`**

```python
#!/usr/bin/env python3
"""build_spec_codex_prompt.py — codex review prompt for a DESIGN DOC.

spec-distill design §6 #2. NOT the qg diff+AC model — this reviews a
brainstorming design doc against the same 6 judgment categories the Claude
spec-reviewer uses (design-mode checklist). Takes the design doc as a FILE PATH
only (never inline content via argv/stdin — injection safety, AC4). The doc is
loaded via read_text and substituted via str.replace (opaque bytes — no parse,
no eval). Output → stdout; caller redirects to a scratch prompt file.

Usage:  build_spec_codex_prompt.py <design_doc_file>

Severity vocab is spec-distill {block, high, medium} to match spec-reviewer.md
and merge_review.py's verdict derivation — NOT qg's CRITICAL/IMPORTANT/SUGGESTION
(vocab drift would break the merge). handoff_incomplete is a mechanical
substring/structure check owned by the existing path, so it is NOT a codex
category here.
"""

from __future__ import annotations

import pathlib
import sys

PROMPT_TEMPLATE = """You are an independent design-doc reviewer. You are reviewing a
brainstorming design document (not code). Do NOT modify any files; you are in a
read-only sandbox.

Review the document below for these SIX judgment categories only:

- placeholder: "TBD", "TODO", "FIXME", "fill in later", or other unfinished text.
- ambiguity: unmeasurable phrasing ("robust", "works correctly", "fast",
  "as needed", "good UX") in goals / acceptance criteria.
- scope_creep: multiple independent subsystems bundled such that a single
  implementation plan cannot cleanly decompose them.
- approaches_comparison: a single approach asserted with no 2-3 alternatives +
  tradeoffs presented.
- isolation: component boundaries / interfaces defined so vaguely that unit
  testing or change isolation is impossible.
- testing: no Verification Plan, or only "manual check" — no automated
  verification procedure.

<design_doc>
{{DESIGN_DOC}}
</design_doc>

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "category": "placeholder | ambiguity | scope_creep | approaches_comparison | isolation | testing",
      "target_section": "<markdown anchor of the offending section, e.g. #2-goals>",
      "severity": "block | high | medium",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<description>"
    }
  ]
}
```

If you find no issues, emit `{"findings": []}` inside the same code fence.
Do not output any text after the closing fence.
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <design_doc_file>", file=sys.stderr)
        return 2

    doc_path = pathlib.Path(sys.argv[1])
    if not doc_path.is_file():
        print(f"design doc file not found: {doc_path}", file=sys.stderr)
        return 2

    doc = doc_path.read_text(encoding="utf-8", errors="replace")
    out = PROMPT_TEMPLATE.replace("{{DESIGN_DOC}}", doc)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`
Expected: PASS — Fail 0.

- [ ] **Step 5: Commit**

```bash
chmod +x plugins/spec-distill/scripts/build_spec_codex_prompt.py
git add plugins/spec-distill/scripts/build_spec_codex_prompt.py plugins/spec-distill/tests/test_build_spec_codex_prompt.sh
git commit -m "feat(spec-distill): add build_spec_codex_prompt.py (6-category design-doc prompt)"
```

---

## Task 4: `codex_findings_to_yaml.py` (vendor+adapt) + codex-exec mocks

**Files:**
- Create: `plugins/spec-distill/scripts/codex_findings_to_yaml.py`
- Create: `plugins/spec-distill/tests/mocks/mock-codex-valid-json.sh`
- Create: `plugins/spec-distill/tests/mocks/mock-codex-exit1.sh`
- Create: `plugins/spec-distill/tests/mocks/mock-codex-auth-stderr.sh`
- Create: `plugins/spec-distill/tests/mocks/mock-codex-bad-json.sh`
- Test: `plugins/spec-distill/tests/test_codex_findings_to_yaml.py`

**Interfaces:**
- Produces: `codex_findings_to_yaml.py` — stdin JSONL, opts `--stderr-file`, `--meta-override-exit-code`, `--meta-override-reason`; stdout YAML `findings:` (each with `agent, category, target_section, severity, line, confidence, summary, proposed_fix` when present) + `meta:` (`codex_failed`, `reason`, `exit_code`, ...). 3단 fallback(auth/malformed/missing) + last-fenced-block 안티인젝션 보존.
- Consumes: nothing. Called by `run_spec_codex_reviewer.sh` (Task 5); output parsed by `merge_review.py` (Task 6).
- Mocks Produce: JSONL on stdout (+ stderr for auth mock) emulating codex `--json`. Reused by Task 5.

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_codex_findings_to_yaml.py`

```python
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "codex_findings_to_yaml.py"


def run(stdin_text, stderr_file=None, argv_extra=()):
    args = [sys.executable, str(SCRIPT), *argv_extra]
    if stderr_file:
        args += ["--stderr-file", str(stderr_file)]
    r = subprocess.run(args, input=stdin_text, capture_output=True, text=True)
    return r.stdout


VALID = (
    '{"type":"item.completed","item":{"type":"agent_message","text":'
    '"```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
    '\\"target_section\\": \\"#2-goals\\", \\"severity\\": \\"high\\", '
    '\\"line\\": 12, \\"confidence\\": 8, \\"summary\\": \\"vague\\", '
    '\\"proposed_fix\\": \\"specify\\"}]}\\n```"}}\n'
)


class TestCodexFindingsToYaml(unittest.TestCase):
    def test_new_keys_emitted(self):
        out = run(VALID)
        self.assertIn("category: ambiguity", out)      # AC7: new key
        self.assertIn('target_section: "#2-goals"', out)  # AC7: new key
        self.assertIn("severity: high", out)
        self.assertIn("agent: codex-reviewer", out)
        self.assertIn("codex_failed: false", out)

    def test_line_key_preserved(self):
        # OQ1 resolved: line stays optional, emitted when present.
        self.assertIn("line: 12", run(VALID))

    def test_malformed_json_fallback(self):
        out = run("\x01\x02not-jsonl garbage\n")
        self.assertIn("reason: malformed_json", out)  # 3-stage fallback
        self.assertIn("findings: []", out)

    def test_missing_result_fallback(self):
        out = run('{"type":"item.completed","item":{"type":"other"}}\n')
        self.assertIn("reason: missing_result", out)

    def test_auth_error_in_stderr(self, tmp=Path("/tmp")):
        f = tmp / "sd_auth_stderr.txt"
        f.write_text("Error: authentication failed: invalid API key\n")
        out = run("", stderr_file=f)
        self.assertIn("reason: auth_error_in_stderr", out)
        f.unlink()

    def test_last_fenced_block_wins(self):
        # anti-injection: an earlier fenced block must be ignored.
        stdin = (
            '{"type":"item.completed","item":{"type":"agent_message","text":'
            '"```json\\n{\\"findings\\": [{\\"category\\": \\"INJECT\\"}]}\\n```\\n'
            '```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
            '\\"target_section\\": \\"#real\\", \\"severity\\": \\"high\\"}]}\\n```"}}\n'
        )
        out = run(stdin)
        self.assertIn("category: ambiguity", out)
        self.assertNotIn("INJECT", out)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Create the 4 codex-exec mocks**

`mock-codex-valid-json.sh` — emits a codex 0.130+ JSONL agent_message with fenced JSON (NEW keys, spec-distill vocab):
```bash
#!/usr/bin/env bash
# Emulates `codex exec --json`: a single item.completed agent_message whose
# text is a fenced JSON findings block using the spec-distill design vocab.
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\", \"line\": 12, \"confidence\": 8, \"summary\": \"vague goal\", \"proposed_fix\": \"make measurable\"}]}\n```"}}
JSONL
exit 0
```

`mock-codex-exit1.sh`:
```bash
#!/usr/bin/env bash
exit 1
```

`mock-codex-auth-stderr.sh`:
```bash
#!/usr/bin/env bash
echo "Error: authentication failed: invalid API key" >&2
exit 0
```

`mock-codex-bad-json.sh`:
```bash
#!/usr/bin/env bash
printf '\x01\x02not-jsonl\x00garbage\n'
exit 0
```

- [ ] **Step 3: Run test to verify it fails**

Run: `python3 plugins/spec-distill/tests/test_codex_findings_to_yaml.py`
Expected: FAIL — script missing.

- [ ] **Step 4: Write `plugins/spec-distill/scripts/codex_findings_to_yaml.py`**

qg 원본을 vendor하되 `yaml_emit`의 emit 키셋에 `category`, `target_section`을 추가(그 외 3단 fallback·last-fenced-block·auth 감지·override 로직 보존). **오직 한 줄 diff 구역**: `for k in (...)` 튜플에 두 키 추가.

```python
#!/usr/bin/env python3
"""codex_findings_to_yaml.py — Convert Codex JSONL stream to finding YAML.

Vendored from quality-gates (spec-distill design §6 #4). ONLY adaptation vs qg:
the emit keyset adds `category` and `target_section` (design-doc review vocab).
Three-stage fallback (fenced JSON → raw JSON → empty+reason), auth-in-stderr
detection, and last-fenced-block anti-injection are preserved verbatim.

Event shape (Codex 0.130+):
  {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
Legacy shape (fallback): {"type":"agent_message","text":"..."}
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any

AUTH_ERROR_RE = re.compile(
    r"(authentication|auth\s+(failed|error)|invalid\s+(api[\s_]?key|token)"
    r"|401|403|forbidden|unauthor|credential|quota|billing|subscription|expired)",
    re.IGNORECASE,
)
FENCED_JSON_RE = re.compile(r"```json\s*\n(.*?)\n?```", re.DOTALL)


def extract_last_agent_message(stdin_text: str) -> tuple[str | None, bool]:
    last_text: str | None = None
    any_parsed = False
    for line in stdin_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        any_parsed = True
        if not isinstance(ev, dict):
            continue
        item = ev.get("item") if isinstance(ev.get("item"), dict) else ev
        if item.get("type") == "agent_message":
            txt = item.get("text") or item.get("message", "")
            if txt:
                last_text = txt
    return last_text, any_parsed


def parse_fenced_json(text: str) -> dict | None:
    matches = re.findall(FENCED_JSON_RE, text)
    if not matches:
        return None
    try:
        return json.loads(matches[-1])  # last block defeats injected earlier blocks
    except json.JSONDecodeError:
        return None


def parse_raw_json(text: str) -> dict | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def yaml_emit(findings: list[dict], meta: dict) -> str:
    out: list[str] = []
    if not findings:
        out.append("findings: []")
    else:
        out.append("findings:")
        for f in findings:
            out.append("  - agent: codex-reviewer")
            # ADAPTATION vs qg: `category` + `target_section` added for design vocab.
            for k in ("file", "line", "category", "target_section",
                      "severity", "confidence", "summary", "proposed_fix"):
                if k in f:
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    out.append("meta:")
    for k, v in meta.items():
        out.append(f"  {k}: {_yaml_scalar(v)}")
    return "\n".join(out) + "\n"


def _yaml_scalar(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--stderr-file", default=None)
    p.add_argument("--meta-override-exit-code", type=int, default=None)
    p.add_argument("--meta-override-reason", default=None)
    args = p.parse_args()

    stdin_text = sys.stdin.read()
    stderr_text = ""
    _stderr_read_error: str | None = None
    if args.stderr_file:
        try:
            with open(args.stderr_file, "r", encoding="utf-8", errors="replace") as fh:
                stderr_text = fh.read()
        except OSError as e:
            stderr_text = ""
            _stderr_read_error = str(e.errno) if e.errno else type(e).__name__

    def has_auth_error() -> bool:
        return bool(stderr_text and AUTH_ERROR_RE.search(stderr_text))

    def apply_overrides(meta: dict) -> dict:
        if args.meta_override_exit_code is not None:
            meta["exit_code"] = args.meta_override_exit_code
        if args.meta_override_reason:
            meta["reason"] = args.meta_override_reason
            meta["codex_failed"] = True
        if _stderr_read_error is not None:
            meta["stderr_read_error"] = _stderr_read_error
        return meta

    last_msg, any_jsonl_parsed = extract_last_agent_message(stdin_text)

    if last_msg is None:
        if has_auth_error():
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        elif stdin_text.strip() and not any_jsonl_parsed:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": stdin_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "missing_result", "exit_code": 0}
        sys.stdout.write(yaml_emit([], apply_overrides(meta)))
        return 0

    parsed = parse_fenced_json(last_msg)
    if parsed is None:
        parsed = parse_raw_json(last_msg.strip())

    if parsed is None or not isinstance(parsed, dict) or "findings" not in parsed:
        if has_auth_error():
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": last_msg[:200]}
        sys.stdout.write(yaml_emit([], apply_overrides(meta)))
        return 0

    raw_findings = parsed.get("findings", [])
    findings = raw_findings if isinstance(raw_findings, list) else []
    meta = {"codex_failed": False}
    if raw_findings is not None and not isinstance(raw_findings, list):
        meta["reason"] = "schema_mismatch"
        meta["raw_findings_type"] = type(raw_findings).__name__
    sys.stdout.write(yaml_emit(findings, apply_overrides(meta)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python3 plugins/spec-distill/tests/test_codex_findings_to_yaml.py`
Expected: PASS — OK (6 tests).

- [ ] **Step 6: Commit**

```bash
chmod +x plugins/spec-distill/scripts/codex_findings_to_yaml.py plugins/spec-distill/tests/mocks/mock-codex-*.sh
git add plugins/spec-distill/scripts/codex_findings_to_yaml.py plugins/spec-distill/tests/test_codex_findings_to_yaml.py plugins/spec-distill/tests/mocks/mock-codex-*.sh
git commit -m "feat(spec-distill): vendor codex_findings_to_yaml.py with category/target_section keys"
```

---

## Task 5: `run_spec_codex_reviewer.sh` (독립 codex subprocess)

**Files:**
- Create: `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh`
- Test: `plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh`

> **Plan gap-fill note (advisory):** design §12는 `test_run_spec_codex_reviewer.sh`를 명시 열거하지 않으나 AC5(no discover-spec)·AC6(C7 guard)·OQ2(medium effort)는 검증처가 필요하다. §13이 "grep으로 스크립트 본문 검증"이라 명시하므로 이 grep-invariant + 1 behavioral(mock codex 통합) 테스트를 여기 추가한다 (scope creep 아님 — 명시 AC의 집).

**Interfaces:**
- Produces: `run_spec_codex_reviewer.sh <doc_path> <project_dir> <out_yaml>` → writes findings YAML (Task 4 shape) to `<out_yaml>`; exit 0 always. `codex exec ... -s read-only -c model_reasoning_effort=medium --json < /dev/null`. **discover-spec.sh 호출 없음** (C3). scratch dir `|| exit 0` 가드 (C7).
- Consumes: `build_spec_codex_prompt.py` (Task 3), `codex_findings_to_yaml.py` (Task 4), `${CLAUDE_PLUGIN_ROOT}`.

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh`

```bash
#!/usr/bin/env bash
# AC5 (no discover-spec.sh) + AC6 (C7 mktemp guard) + OQ2 (medium effort)
# + one behavioral integration through a mock codex on PATH.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN="$PLUGIN_ROOT/scripts/run_spec_codex_reviewer.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-run-codex-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# --- Structural greps (AC5/AC6/OQ2) ---
grep -q 'discover-spec' "$RUN" \
  && note FAIL "AC5: discover-spec.sh referenced (C3 circular-injection risk)" \
  || note PASS "AC5: no discover-spec.sh call"

# C7: the scratch-dir assignment line must be guarded before any trap arms.
grep -qE 'SCRATCH=.*mktemp.*\|\|' "$RUN" \
  && note PASS "AC6: mktemp SCRATCH assignment has '||' guard" \
  || note FAIL "AC6: mktemp SCRATCH assignment not guarded (C7 footgun)"

grep -qE 'model_reasoning_effort.*medium' "$RUN" \
  && note PASS "OQ2: model_reasoning_effort=medium" || note FAIL "OQ2: effort not medium"
grep -qE '\-s read-only' "$RUN" \
  && note PASS "Law2: -s read-only sandbox flag" || note FAIL "-s read-only missing"

# --- Behavioral: mock codex on PATH produces parsed YAML at out path ---
DOC="$TMP/x-design.md"; printf '# X\n\n## 2. Goals\nrobust.\n' > "$DOC"
mkdir -p "$TMP/codexbin"
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
# ignore all args; emit one valid agent_message with findings
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\"}]}\n```"}}
JSONL
exit 0
SH
chmod +x "$TMP/codexbin/codex"
OUT="$TMP/out.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT"
rc=$?
[[ $rc -eq 0 ]] && note PASS "exit 0" || note FAIL "exit $rc (expected 0)"
grep -q 'category: ambiguity' "$OUT" && note PASS "parsed finding written to out" || note FAIL "out yaml missing finding"
grep -q 'codex_failed: false' "$OUT" && note PASS "codex_failed false on success" || note FAIL "codex_failed not false"

# Behavioral: codex exit≠0 → degrade meta (not crash)
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$TMP/codexbin/codex"
OUT2="$TMP/out2.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT2" || true
grep -q 'codex_failed: true' "$OUT2" && note PASS "codex exit1 → codex_failed true" || note FAIL "exit1 not marked failed"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh`
Expected: FAIL — script missing.

- [ ] **Step 3: Write `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh`**

qg `run_codex_reviewer.sh`를 design-doc용으로 재작성: **spec-AC 해상도 블록(discover-spec.sh) 전부 제거**(C3), diff 대신 design doc 경로를 `build_spec_codex_prompt.py`에 넘김. mktemp 가드는 `|| { ...; exit 0; }`(C7). codex 호출 플래그(`-s read-only`, `--json`, `< /dev/null`, `model_reasoning_effort=medium`) 보존.

```bash
#!/usr/bin/env bash
# run_spec_codex_reviewer.sh — independent codex review of a DESIGN DOC.
# spec-distill design §6 #3. Unlike qg's run_codex_reviewer.sh, this NEVER calls
# discover-spec.sh (C3: the reviewed doc lives under docs/superpowers/specs/, so
# AC auto-injection would feed the doc its own content — a circular footgun).
#
# Usage:  run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>
#
# Emits YAML (codex_findings_to_yaml.py schema) to <output_yaml_path>.
# Sandbox: codex exec -s read-only (Layer 3) — codex cannot write the tree.

set -euo pipefail

DOC_PATH="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>" >&2
  exit 2
fi
if [[ -z "$PROJECT_DIR" ]]; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: missing_project_dir' >> "$OUTPUT_PATH"
  exit 0
fi
cd "$PROJECT_DIR" || {
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: project_dir_unreachable' >> "$OUTPUT_PATH"
  exit 0
}

# C7: guard scratch-dir assignment BEFORE any trap arms (cd "" repo-delete footgun).
SCRATCH="$(mktemp -d -t sd-codex-rev-XXXXXX)" || {
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: scratch_dir_uncreatable' >> "$OUTPUT_PATH"
  exit 0
}
trap 'rm -rf "$SCRATCH"' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# Build the design-doc prompt (path-only input — no discover-spec.sh, C3).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_spec_codex_prompt.py" \
       "$DOC_PATH" > "$PROMPT_FILE"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: prompt_build_failed' >> "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (load-bearing flags preserved):
#   -s read-only  : Layer 3 sandbox (writes blocked)   | --json : JSONL stream
#   -C            : working-dir pin                     | </dev/null : stdin detach
EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  OVERRIDE_REASON=exit_nonzero
else
  OVERRIDE_REASON=""
fi

python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
    --stderr-file "$STDERR_FILE" \
    --meta-override-exit-code "$EXIT_CODE" \
    --meta-override-reason "$OVERRIDE_REASON" \
    < "$STDOUT_FILE" > "$OUTPUT_PATH"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh`
Expected: PASS — Fail 0.

- [ ] **Step 5: Commit**

```bash
chmod +x plugins/spec-distill/scripts/run_spec_codex_reviewer.sh
git add plugins/spec-distill/scripts/run_spec_codex_reviewer.sh plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh
git commit -m "feat(spec-distill): add run_spec_codex_reviewer.sh (design-doc codex path, no discover-spec)"
```

---

## Task 6: `merge_review.py` — parse + verdict + 보수적 병합 + degrade 계층 (core)

**Files:**
- Create: `plugins/spec-distill/scripts/merge_review.py`
- Test: `plugins/spec-distill/tests/test_merge_review.py`

**Interfaces:**
- Produces: `merge_review.py --claude-output <p> --codex-yaml <p> --history <json>` → stdout YAML (Global Constraints shape). Parses BOTH reviewer outputs deterministically (no LLM transcription). This task implements: verdict extraction (`**Status:**` line, OQ3), sentinel-block issue parse (last `spec-review-issues` fence, JSON body), codex-yaml parse, `codex_verdict` derivation, conservative merge, 4-branch degrade hierarchy. Ledger keys are pass-through stubs here (`issue_history` echoes `--history` unchanged; `stagnation: {per_issue: [], round_level: false}`) — filled in Task 7.
- Consumes: `compute_issue_id.py` (imported in Task 7; parsing of issues happens here so Task 7 can consume the parsed lists).

- [ ] **Step 1: Write the failing test (core subset)** — `plugins/spec-distill/tests/test_merge_review.py`

```python
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "merge_review.py"


def parse_simple_yaml(text):
    """Tiny parser for merge_review's known flat-ish stdout (test-only)."""
    out, cur_list_key = {}, None
    for raw in text.splitlines():
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        if raw.startswith("  - ") and cur_list_key:
            out[cur_list_key].append(raw.strip()[2:])
            continue
        if not raw.startswith(" "):
            k, _, v = raw.partition(":")
            v = v.strip()
            if v == "":
                out[k] = []
                cur_list_key = k
            else:
                out[k] = v
                cur_list_key = None
    return out


def claude_output(status="approved", issues=None, sentinel=True, echo_fence=False):
    body = ""
    if echo_fence:
        body += "```yaml\nname: some-design\n```\n\n"  # reviewed-doc echo
    body += f"## Spec Review (round 1)\n\n**Status:** {status}\n\n"
    if sentinel:
        payload = json.dumps({"issues": issues or []})
        body += f"```spec-review-issues\n{payload}\n```\n"
    body += "\n**Recommendations (advisory):**\n- Status of X looks fine\n"
    return body


def codex_yaml(findings=None, failed=False, reason=None):
    lines = []
    if findings:
        lines.append("findings:")
        for f in findings:
            lines.append("  - agent: codex-reviewer")
            for k, v in f.items():
                lines.append(f"    {k}: {v}")
    else:
        lines.append("findings: []")
    lines.append("meta:")
    lines.append(f"  codex_failed: {'true' if failed else 'false'}")
    if reason:
        lines.append(f"  reason: {reason}")
    return "\n".join(lines) + "\n"


def run_merge(claude_txt, codex_txt, history=None):
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        (d / "claude.md").write_text(claude_txt)
        (d / "codex.yaml").write_text(codex_txt)
        hist = d / "history.json"
        hist.write_text(json.dumps(history or {"issue_history": []}))
        r = subprocess.run(
            [sys.executable, str(SCRIPT),
             "--claude-output", str(d / "claude.md"),
             "--codex-yaml", str(d / "codex.yaml"),
             "--history", str(hist)],
            capture_output=True, text=True,
        )
        return r.returncode, parse_simple_yaml(r.stdout), r.stdout, json.loads(hist.read_text())


class TestMergeCore(unittest.TestCase):
    # AC9: conservative precedence truth table.
    def test_codex_overturns_claude_approved(self):
        _, y, _, _ = run_merge(
            claude_output("approved", []),
            codex_yaml([{"category": "ambiguity", "target_section": '"#2-goals"', "severity": "high"}]),
        )
        self.assertEqual(y["combined_verdict"], "needs_revise")  # fail-open catch

    def test_claude_needs_revise_codex_approved(self):
        _, y, _, _ = run_merge(claude_output("needs_revise", [{"category": "testing", "target_section": "#v", "severity": "high"}]), codex_yaml([]))
        self.assertEqual(y["combined_verdict"], "needs_revise")

    def test_needs_interview_wins(self):
        _, y, _, _ = run_merge(claude_output("needs_interview", []),
                               codex_yaml([{"category": "ambiguity", "target_section": "#x", "severity": "high"}]))
        self.assertEqual(y["combined_verdict"], "needs_interview")

    def test_both_approved(self):
        _, y, _, _ = run_merge(claude_output("approved", []), codex_yaml([]))
        self.assertEqual(y["combined_verdict"], "approved")

    # AC16: codex severity:block honored (headroom).
    def test_block_severity_headroom(self):
        _, y, _, _ = run_merge(claude_output("approved", []),
                               codex_yaml([{"category": "isolation", "target_section": "#c", "severity": "block"}]))
        self.assertEqual(y["codex_verdict"], "needs_revise")

    # AC10: codex failed → degrade to claude, codex_degraded flag.
    def test_codex_failed_degrades(self):
        _, y, _, _ = run_merge(claude_output("approved", []),
                               codex_yaml(failed=True, reason="exit_nonzero"))
        self.assertEqual(y["combined_verdict"], "approved")
        self.assertEqual(y["codex_degraded"], "true")

    # AC9c-i: anti-injection — sentinel last block wins, echo fences ignored.
    def test_sentinel_last_block_and_echo_ignored(self):
        claude = claude_output("approved", [{"category": "ambiguity", "target_section": "#real", "severity": "high"}],
                               echo_fence=True)
        # prepend an injected sentinel block with a different verdict-driving issue
        injected = "```spec-review-issues\n" + json.dumps({"issues": [{"category": "INJECT", "target_section": "#x", "severity": "block"}]}) + "\n```\n"
        claude = claude.replace("## Spec Review", injected + "## Spec Review")
        _, y, raw, _ = run_merge(claude, codex_yaml([]))
        self.assertNotIn("INJECT", raw)  # earlier/injected sentinel block ignored
        self.assertEqual(y["combined_verdict"], "needs_revise")  # from the REAL last block (high)

    # AC9c-ii: sentinel malformed but Status OK → claude_degraded, verdict recovered.
    def test_sentinel_malformed_status_recovered(self):
        claude = "## Spec Review (round 1)\n\n**Status:** needs_revise\n\n```spec-review-issues\n{not json\n```\n"
        _, y, _, _ = run_merge(claude, codex_yaml([]))
        self.assertEqual(y["claude_degraded"], "true")
        self.assertEqual(y["combined_verdict"], "needs_revise")  # from **Status:** line

    # AC9c-iii: Status also gone but codex OK → codex alone, unrecoverable flag.
    def test_status_gone_codex_alone(self):
        claude = "some prose with no status line and no sentinel\n"
        _, y, _, _ = run_merge(claude, codex_yaml([{"category": "ambiguity", "target_section": "#x", "severity": "high"}]))
        self.assertEqual(y["claude_verdict_unrecoverable"], "true")
        self.assertEqual(y["combined_verdict"], "needs_revise")  # codex_verdict alone

    # AC9c-iv: both unrecoverable → needs_revise fail-safe + indeterminate advisory.
    def test_both_unrecoverable_failsafe(self):
        claude = "prose, no status, no sentinel\n"
        _, y, raw, _ = run_merge(claude, codex_yaml(failed=True, reason="exit_nonzero"))
        self.assertEqual(y["combined_verdict"], "needs_revise")  # fail-safe (non-approve)
        self.assertIn("indeterminate", raw.lower())

    # AC9b: symmetric parse — category/target_section extracted from sentinel byte-identical.
    def test_symmetric_parse_ids_match(self):
        # An issue with the SAME (category, target_section) from both reviewers
        # must land on the SAME id (proves both sides parse, not transcribe).
        claude = claude_output("needs_revise", [{"category": "ambiguity", "target_section": "#2-goals", "severity": "high"}])
        cod = codex_yaml([{"category": "ambiguity", "target_section": '"#2-goals"', "severity": "high"}])
        _, y, raw, hist = run_merge(claude, cod)
        # After Task 7 this asserts source: both; in Task 6 core we only assert both parsed.
        self.assertEqual(y["combined_verdict"], "needs_revise")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 plugins/spec-distill/tests/test_merge_review.py`
Expected: FAIL — script missing.

- [ ] **Step 3: Write `plugins/spec-distill/scripts/merge_review.py` (core)**

전체 파싱·verdict·병합·degrade 계층을 구현. ledger(union/stagnation)는 Task 7에서 채우되, **stdout 형태는 완전한 shape**로 emit(issue_history는 --history 그대로 echo, stagnation 스텁). Task 7이 ledger 함수만 교체.

```python
#!/usr/bin/env python3
"""merge_review.py — deterministic merge/ledger engine for spec-distill Phase 3.

spec-distill design §6 #6 / §7 / §8 / §9. Single verifiable boundary that owns
every deterministic operation of the co-review merge (C2): parse BOTH reviewer
outputs (no LLM transcription — [fc2ef911] sealed), derive codex_verdict,
conservatively merge verdicts, and (Task 7) run the unified-ledger stagnation
scan. stdlib only.

CLI:
  merge_review.py --claude-output <path> --codex-yaml <path> --history <json>

Emits YAML on stdout (see design §5 / plan Global Constraints). Verdict recovery
hierarchy (§9): sentinel OK / sentinel bad→**Status:** recovery / **Status:** bad
→codex alone / both bad→needs_revise fail-safe.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# --- verdict precedence (§7b) ------------------------------------------------
RANK = {"approved": 0, "needs_revise": 1, "needs_interview": 2}
INV_RANK = {v: k for k, v in RANK.items()}
CODEX_SEVERITY_REVISE = {"block", "high"}

SENTINEL_RE = re.compile(r"```spec-review-issues[^\n]*\n(.*?)\n?```", re.DOTALL)
STATUS_RE = re.compile(
    r"^\*\*Status:\*\*\s*(approved|needs_revise|needs_interview)\b", re.MULTILINE
)
SPEC_REVIEW_HEADER_RE = re.compile(r"^##\s+Spec Review\b", re.MULTILINE)


# --- Claude side -------------------------------------------------------------
def extract_claude_verdict(text: str) -> str | None:
    """OQ3: first **Status:** line at/after the '## Spec Review' header; if the
    header is absent, fall back to the first **Status:** line anywhere. Returns
    None if no well-formed Status line exists (unrecoverable)."""
    m = SPEC_REVIEW_HEADER_RE.search(text)
    scope = text[m.start():] if m else text
    sm = STATUS_RE.search(scope)
    if sm:
        return sm.group(1)
    # header found but no Status inside its scope → try whole doc as last resort
    if m:
        sm = STATUS_RE.search(text)
        if sm:
            return sm.group(1)
    return None


def extract_claude_issues(text: str) -> tuple[list[dict] | None, bool]:
    """Parse the LAST ```spec-review-issues fenced block (anti-injection,
    symmetric to codex last-fenced-block). Returns (issues, degraded).
    degraded=True when no well-formed sentinel block yields a JSON {issues:[...]}.
    """
    blocks = SENTINEL_RE.findall(text)
    if not blocks:
        return None, True
    try:
        payload = json.loads(blocks[-1])
    except json.JSONDecodeError:
        return None, True
    if not isinstance(payload, dict) or not isinstance(payload.get("issues"), list):
        return None, True
    issues = []
    for it in payload["issues"]:
        if not isinstance(it, dict):
            continue
        issues.append({
            "category": str(it.get("category", "")),
            "target_section": str(it.get("target_section", "")),
            "severity": str(it.get("severity", "")).lower(),
            "message": str(it.get("message", "")),
        })
    return issues, False


# --- codex side --------------------------------------------------------------
def parse_codex_yaml(path: str) -> tuple[list[dict], bool, str]:
    """Line-parse codex_findings_to_yaml.py output (known shape). Returns
    (findings, codex_failed, reason). Missing file → failed."""
    if not path or not os.path.isfile(path):
        return [], True, "codex_yaml_missing"
    findings: list[dict] = []
    failed = False
    reason = ""
    section = None
    cur: dict | None = None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh.readlines():
            line = raw.rstrip("\n")
            if line.startswith("findings:"):
                section = "findings"
                if "[]" in line:
                    section = None
                continue
            if line.startswith("meta:"):
                if cur:
                    findings.append(cur); cur = None
                section = "meta"
                continue
            if section == "findings":
                if line.strip().startswith("- "):
                    if cur:
                        findings.append(cur)
                    cur = {}
                    # first inline key may follow "- "
                    rest = line.strip()[2:]
                    if ":" in rest:
                        k, _, v = rest.partition(":")
                        cur[k.strip()] = _yaml_unscalar(v.strip())
                elif ":" in line and cur is not None:
                    k, _, v = line.strip().partition(":")
                    cur[k.strip()] = _yaml_unscalar(v.strip())
            elif section == "meta":
                if ":" in line:
                    k, _, v = line.strip().partition(":")
                    k = k.strip(); v = v.strip()
                    if k == "codex_failed":
                        failed = (v == "true")
                    elif k == "reason":
                        reason = _yaml_unscalar(v)
    if cur:
        findings.append(cur)
    return findings, failed, reason


def _yaml_unscalar(v: str):
    v = v.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except json.JSONDecodeError:
            return v[1:-1]
    return v


def derive_codex_verdict(findings: list[dict]) -> str:
    for f in findings:
        if str(f.get("severity", "")).lower() in CODEX_SEVERITY_REVISE:
            return "needs_revise"
    return "approved"


# --- merge -------------------------------------------------------------------
def conservative(a: str, b: str) -> str:
    return INV_RANK[max(RANK[a], RANK[b])]


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def load_history(path: str) -> list[dict]:
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []
    ih = data.get("issue_history") if isinstance(data, dict) else None
    return ih if isinstance(ih, list) else []


def build_ledger(claude_issues, codex_findings, claude_degraded, codex_avail, history):
    """Task 6 STUB — pass-through. Task 7 replaces this with the real
    union-increment + unified-ledger stagnation scan."""
    return history, {"per_issue": [], "round_level": False}


def emit(result: dict) -> str:
    out = []
    for k in ("combined_verdict", "claude_verdict", "codex_verdict",
              "codex_degraded", "claude_degraded", "claude_verdict_unrecoverable"):
        out.append(f"{k}: {_yaml_scalar(result[k])}")
    stg = result["stagnation"]
    out.append("stagnation:")
    out.append(f"  per_issue: {json.dumps(stg['per_issue'])}")
    out.append(f"  round_level: {_yaml_scalar(stg['round_level'])}")
    out.append("issue_history:")
    if not result["issue_history"]:
        out[-1] = "issue_history: []"
    else:
        for r in result["issue_history"]:
            out.append("  - " + json.dumps(r, sort_keys=True))
    out.append("advisory:")
    if not result["advisory"]:
        out[-1] = "advisory: []"
    else:
        for a in result["advisory"]:
            out.append(f"  - {_yaml_scalar(a)}")
    return "\n".join(out) + "\n"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--claude-output", required=True)
    p.add_argument("--codex-yaml", required=True)
    p.add_argument("--history", required=True)
    args = p.parse_args()

    claude_text = ""
    if os.path.isfile(args.claude_output):
        with open(args.claude_output, "r", encoding="utf-8", errors="replace") as fh:
            claude_text = fh.read()

    claude_verdict = extract_claude_verdict(claude_text)
    claude_issues, claude_degraded = extract_claude_issues(claude_text)
    codex_findings, codex_failed, codex_reason = parse_codex_yaml(args.codex_yaml)
    codex_avail = not codex_failed
    codex_verdict = derive_codex_verdict(codex_findings) if codex_avail else None

    advisory: list[str] = []
    claude_unrecoverable = claude_verdict is None

    # --- degrade hierarchy (§9 matrix) ---
    if not claude_unrecoverable and codex_avail:
        combined = conservative(claude_verdict, codex_verdict)
    elif not claude_unrecoverable and not codex_avail:
        combined = claude_verdict
        advisory.append(
            f"[spec-distill v0.20.0] codex co-review degraded (reason: {codex_reason or 'unavailable'}) "
            f"— Claude-only, model diversity 없음. combined = Claude verdict.")
    elif claude_unrecoverable and codex_avail:
        combined = codex_verdict
        advisory.append(
            "[spec-distill v0.20.0] Claude verdict unrecoverable (no **Status:** line) "
            "— combined = codex verdict alone.")
    else:  # both unrecoverable
        combined = "needs_revise"  # fail-safe (non-approve); crash·fail-open 금지
        advisory.append(
            "[spec-distill v0.20.0] review indeterminate (Claude verdict unrecoverable "
            "AND codex unavailable) — combined = needs_revise fail-safe, 원장 미갱신.")

    if claude_degraded and not claude_unrecoverable:
        advisory.append(
            "[spec-distill v0.20.0] Claude issue block unparseable (sentinel malformed) "
            "— verdict recovered from **Status:**, this round's Claude issues skipped in ledger.")

    # --- ledger (Task 6 stub; Task 7 real) ---
    both_dead = claude_unrecoverable and not codex_avail
    history = load_history(args.history)
    if both_dead:
        new_history, stagnation = history, {"per_issue": [], "round_level": "inconclusive"}
    else:
        new_history, stagnation = build_ledger(
            claude_issues if not claude_degraded else [],
            codex_findings if codex_avail else [],
            claude_degraded, codex_avail, history,
        )

    result = {
        "combined_verdict": combined,
        "claude_verdict": claude_verdict if claude_verdict else None,
        "codex_verdict": codex_verdict if codex_verdict else None,
        "codex_degraded": not codex_avail,
        "claude_degraded": claude_degraded,
        "claude_verdict_unrecoverable": claude_unrecoverable,
        "stagnation": stagnation,
        "issue_history": new_history,
        "advisory": advisory,
    }
    sys.stdout.write(emit(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/spec-distill/tests/test_merge_review.py`
Expected: PASS — OK (core tests; `test_symmetric_parse_ids_match` asserts only combined_verdict at this stage).

- [ ] **Step 5: Commit**

```bash
chmod +x plugins/spec-distill/scripts/merge_review.py
git add plugins/spec-distill/scripts/merge_review.py plugins/spec-distill/tests/test_merge_review.py
git commit -m "feat(spec-distill): merge_review.py core — parse, verdict, conservative merge, degrade hierarchy"
```

---

## Task 7: `merge_review.py` — 원장 union + 통합-원장 stagnation 스캔 (ledger)

**Files:**
- Modify: `plugins/spec-distill/scripts/merge_review.py` (replace `build_ledger` stub + wire compute_issue_id)
- Modify: `plugins/spec-distill/tests/test_merge_review.py` (append ledger tests)

**Interfaces:**
- Consumes: `compute_issue_id.compute()` (Task 2), parsed `claude_issues`/`codex_findings` from Task 6.
- Produces: real `issue_history` (union raised_count, 라운드당 1회, source claude|codex|both, resolved) written back to `--history` atomically + emitted in stdout; `stagnation.per_issue` (raised_count>=3 AND dismissed_by_user==0) + `stagnation.round_level` (true|false|inconclusive, OQ4).

- [ ] **Step 1: Append the failing ledger tests** to `test_merge_review.py`

```python
import re as _re


def get_per_issue(raw):
    """Extract stagnation.per_issue precisely (the naive parse_simple_yaml
    flattens nested blocks, so read the JSON list off the per_issue line)."""
    m = _re.search(r'^\s*per_issue:\s*(\[.*\])\s*$', raw, _re.MULTILINE)
    return json.loads(m.group(1)) if m else []


class TestMergeLedger(unittest.TestCase):
    def _issue(self, cat, sec, sev="high"):
        return {"category": cat, "target_section": sec, "severity": sev}

    # AC11: union increments once even when both reviewers flag the same id.
    def test_union_increments_once(self):
        claude = claude_output("needs_revise", [self._issue("ambiguity", "#2-goals")])
        cod = codex_yaml([{"category": "ambiguity", "target_section": '"#2-goals"', "severity": "high"}])
        _, y, _, hist = run_merge(claude, cod)
        ih = hist["issue_history"]
        self.assertEqual(len(ih), 1)
        self.assertEqual(ih[0]["raised_count"], 1)   # not 2
        self.assertEqual(ih[0]["source"], "both")

    # AC14: codex-only id repeated 3x → stagnation, without any Claude signal.
    def test_codex_only_stagnation(self):
        from plugins_helper import cid  # see helper note below
        codex_id = cid("isolation", "#6-components")
        prior = {"issue_history": [
            {"id": codex_id, "raised_count": 2, "dismissed_by_user": 0, "source": "codex", "resolved": False}
        ]}
        claude = claude_output("approved", [])  # Claude sees nothing
        cod = codex_yaml([{"category": "isolation", "target_section": '"#6-components"', "severity": "high"}])
        _, y, raw, hist = run_merge(claude, cod, history=prior)
        self.assertIn(codex_id, get_per_issue(raw))  # per_issue list contains the id
        updated = [r for r in hist["issue_history"] if r["id"] == codex_id][0]
        self.assertEqual(updated["raised_count"], 3)

    # AC14 dismissed_by_user excludes from stagnation (P17).
    def test_dismissed_excluded(self):
        from plugins_helper import cid
        codex_id = cid("isolation", "#6-components")
        prior = {"issue_history": [
            {"id": codex_id, "raised_count": 5, "dismissed_by_user": 1, "source": "codex", "resolved": False}
        ]}
        cod = codex_yaml([{"category": "isolation", "target_section": '"#6-components"', "severity": "high"}])
        _, y, raw, _ = run_merge(claude_output("approved", []), cod, history=prior)
        self.assertNotIn(codex_id, get_per_issue(raw))  # excluded from stagnation (still in history)

    # OQ4: claude_degraded round is inconclusive for round-level stagnation.
    def test_degraded_round_inconclusive(self):
        claude = "## Spec Review (round 1)\n\n**Status:** needs_revise\n\n```spec-review-issues\n{bad\n```\n"
        _, y, raw, _ = run_merge(claude, codex_yaml([]))
        # round_level must be the string 'inconclusive', not a boolean.
        self.assertIn("round_level: inconclusive", raw)
```

> **Helper note:** the two AC14 tests import `cid` to compute the expected id. Add a tiny shim at the top of `test_merge_review.py` instead of a separate module:
> ```python
> sys.path.insert(0, str(SCRIPT.parent))
> import compute_issue_id as _cii
> def cid(c, s): return _cii.compute(c, s)
> ```
> and replace `from plugins_helper import cid` with direct `cid(...)` calls (drop the import lines). This keeps the id expectation deterministic and proves collision integrity end-to-end.

Also strengthen the Task 6 `test_symmetric_parse_ids_match` now that the ledger exists — assert `source: both` and `raised_count: 1`:
```python
    def test_symmetric_parse_ids_match(self):
        claude = claude_output("needs_revise", [{"category": "ambiguity", "target_section": "#2-goals", "severity": "high"}])
        cod = codex_yaml([{"category": "ambiguity", "target_section": '"#2-goals"', "severity": "high"}])
        _, y, raw, hist = run_merge(claude, cod)
        self.assertEqual(len(hist["issue_history"]), 1)   # same id → 1 record
        self.assertEqual(hist["issue_history"][0]["source"], "both")
```

- [ ] **Step 2: Run test to verify the new ledger tests fail**

Run: `python3 plugins/spec-distill/tests/test_merge_review.py`
Expected: FAIL — `build_ledger` is still the stub (raised_count 0, empty stagnation, round_level False not 'inconclusive').

- [ ] **Step 3: Replace `build_ledger` in `merge_review.py` + import compute_issue_id**

Add near the top (after `import sys`):
```python
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compute_issue_id  # noqa: E402  (sibling helper, centralized id — §8)
```

Replace the stub `build_ledger` with the real engine and route round-level `inconclusive` on degraded rounds (OQ4):
```python
def _origin_merge(prior_source: str, this_round: set) -> str:
    seen = set()
    if prior_source in ("claude", "codex", "both"):
        seen.update({"claude", "codex"} if prior_source == "both" else {prior_source})
    seen.update(this_round)
    if {"claude", "codex"} <= seen:
        return "both"
    if "codex" in seen:
        return "codex"
    return "claude"


def build_ledger(claude_issues, codex_findings, claude_degraded, codex_avail, history):
    """Union-increment ledger + unified-ledger stagnation scan (§8).

    - raised_count += 1 per id per ROUND (both reviewers flagging = corroboration,
      not double count — AC11).
    - per-issue stagnation: raised_count>=3 AND dismissed_by_user==0 (AC14),
      dismissed excluded (P17).
    - round-level (§8): no NEW id this round AND unresolved prior ids persist.
      OQ4: when claude_degraded, the round is 'inconclusive' (a parse failure
      must not read as convergence).
    """
    by_id = {r["id"]: dict(r) for r in history if isinstance(r, dict) and "id" in r}
    prior_ids = set(by_id.keys())

    # ids raised THIS round, tagged by origin.
    round_origin: dict[str, set] = {}
    for it in claude_issues:
        iid = compute_issue_id.compute(it["category"], it["target_section"])
        round_origin.setdefault(iid, set()).add("claude")
    for f in codex_findings:
        cat = str(f.get("category", ""))
        sec = str(f.get("target_section", ""))
        if not cat and not sec:
            continue
        iid = compute_issue_id.compute(cat, sec)
        round_origin.setdefault(iid, set()).add("codex")

    this_round_ids = set(round_origin.keys())

    # mark prior ids not raised this round as resolved; increment raised ids.
    for iid, rec in by_id.items():
        if iid not in this_round_ids:
            rec["resolved"] = True
    for iid, origins in round_origin.items():
        rec = by_id.get(iid) or {"id": iid, "raised_count": 0,
                                  "dismissed_by_user": 0, "source": "", "resolved": False}
        rec["raised_count"] = int(rec.get("raised_count", 0)) + 1
        rec["dismissed_by_user"] = int(rec.get("dismissed_by_user", 0))
        rec["source"] = _origin_merge(rec.get("source", ""), origins)
        rec["resolved"] = False
        by_id[iid] = rec

    new_history = list(by_id.values())

    # per-issue stagnation
    per_issue = [rec["id"] for rec in new_history
                 if int(rec.get("raised_count", 0)) >= 3
                 and int(rec.get("dismissed_by_user", 0)) == 0]

    # round-level stagnation (OQ4)
    if claude_degraded:
        round_level = "inconclusive"
    else:
        new_ids = this_round_ids - prior_ids
        unresolved_persist = any(
            (iid in this_round_ids) and int(by_id[iid].get("dismissed_by_user", 0)) == 0
            for iid in prior_ids
        )
        round_level = (len(new_ids) == 0 and unresolved_persist)

    return new_history, {"per_issue": per_issue, "round_level": round_level}
```

Finally, persist the updated history back to `--history` atomically. In `main()`, after computing `new_history` (and only when NOT `both_dead`), add before `emit`:
```python
    if not both_dead:
        _write_history(args.history, new_history)
```
and add the helper:
```python
def _write_history(path: str, issue_history: list[dict]) -> None:
    tmp = path + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"issue_history": issue_history}, fh, sort_keys=True)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    except OSError:
        pass  # graceful — ledger persistence best-effort; stdout still authoritative for this round
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 plugins/spec-distill/tests/test_merge_review.py`
Expected: PASS — OK (all core + ledger tests).

- [ ] **Step 5: Mutation check (teeth)** — temporarily change `+ 1` to `+ 2` in `build_ledger` raised_count; rerun; confirm `test_union_increments_once` + `test_codex_only_stagnation` go red; revert.

Run: `python3 plugins/spec-distill/tests/test_merge_review.py`
Expected (mutated): FAIL. After revert: PASS.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/scripts/merge_review.py plugins/spec-distill/tests/test_merge_review.py
git commit -m "feat(spec-distill): merge_review ledger — union increment + unified-ledger stagnation scan"
```

---

## Task 8: `agents/spec-reviewer.md` — sentinel block emit + issue_id self-report 제거

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md`
- Modify: `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`

**Interfaces:**
- Produces: spec-reviewer now emits (A) top-level `**Status:** <verdict>` line (kept) + (B) a ` ```spec-review-issues ` sentinel-fenced JSON block `{"issues":[{category,target_section,severity,message}]}`. Removes issue_id self-report (merge_review computes ids). codex-존재 blind 유지.
- Consumes: parsed by `merge_review.py` (Task 6). Contract locked by the extended checklist test.

- [ ] **Step 1: Extend the failing test** — append to `test_spec_reviewer_design_checklist.sh` (before the final `echo`/total):

```bash
# --- v0.20.0 co-reviewer contract: sentinel block + Status line + no issue_id self-report ---

# (A) sentinel fence info-string documented (exact token).
grep -q 'spec-review-issues' "$AGENT" \
  && note PASS "v0.20.0: sentinel fence 'spec-review-issues' documented" \
  || note FAIL "v0.20.0: sentinel fence token missing"

# (B) sentinel block JSON keys required (body-unique phrasing, not header-satisfiable).
for key in 'category' 'target_section' 'severity' 'message'; do
  grep -q "$key" "$AGENT" && note PASS "v0.20.0: sentinel key '$key'" || note FAIL "v0.20.0: sentinel key '$key' missing"
done

# (C) top-level **Status:** line still the verdict source of truth.
grep -qE '\*\*Status:\*\*' "$AGENT" \
  && note PASS "v0.20.0: **Status:** verdict line preserved" \
  || note FAIL "v0.20.0: **Status:** line removed"

# (D) issue_id self-report REMOVED — reviewer must no longer be told to emit
#     sha256_short itself (merge_review + compute_issue_id own it). Teeth: the
#     old self-report instruction phrase must be gone from the Output contract.
grep -q 'sha256_short(category' "$AGENT" \
  && note FAIL "v0.20.0: issue_id self-report (sha256_short) still instructed" \
  || note PASS "v0.20.0: issue_id self-report removed"

# (E) compute_issue_id referenced as the id authority.
grep -q 'compute_issue_id' "$AGENT" \
  && note PASS "v0.20.0: compute_issue_id referenced" \
  || note FAIL "v0.20.0: compute_issue_id reference missing"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`
Expected: FAIL — new assertions (sentinel/compute_issue_id) not yet in the agent; and the `sha256_short(category` self-report still present.

- [ ] **Step 3: Edit `agents/spec-reviewer.md`**

Make these surgical edits (preserve everything the existing test already locks — 6 categories, `## Spec Review (round N)`, `Stagnation_signal`, 11-section spec-mode text):

1. Replace the **"Issue ID 정의 (rephrase dodge 방지)"** section body:
```markdown
## Issue ID (중앙화 — merge_review가 계산)

issue_id는 **당신이 계산하지 않는다**. 각 issue에 `(category, target_section)`만 구조적으로 emit하면(아래 sentinel block), orchestrator의 `scripts/compute_issue_id.py`(= `sha256_short(category + ":" + target_section)`)가 결정론적으로 id를 부여한다. LLM in-head 해싱은 신뢰 불가하므로 self-report하지 말 것 — collision integrity(두 리뷰어 corroboration + cross-round stagnation)는 중앙 helper만 보장한다.
```

2. Replace the **"Output 형식"** section so it emits BOTH artifacts:
```markdown
## Output 형식 (이 형식을 정확히 준수, AC5)

두 산출물을 분리 emit — verdict(정본)와 issue list를 독립적으로:

```markdown
## Spec Review (round N)

**Status:** approved | needs_revise | needs_interview

(사람 가독 요약을 여기 자유롭게 병기 가능.)

**Recommendations (advisory):**
- ...

**Stagnation_signal:** true | false
```

그리고 issue list는 **sentinel-fenced block**으로 (info-string은 정확히 `spec-review-issues`, body는 JSON):

```spec-review-issues
{"issues": [
  {"category": "<6개 중 하나>", "target_section": "#anchor", "severity": "block|high|medium", "message": "<한 문장>"}
]}
```

- verdict는 **위의 `**Status:**` 라인**이 정본 — sentinel block이 malformed여도 verdict는 Status에서 회수된다.
- issue가 없으면 `{"issues": []}`를 sentinel block에 emit.
- `category`는 design mode 6개(placeholder/ambiguity/scope_creep/approaches_comparison/isolation/testing) 중 하나. `severity` vocab은 `block|high|medium` (CRITICAL/IMPORTANT/SUGGESTION 아님).
- sentinel block은 **하나만** emit하고, 리뷰 대상 doc의 ` ```yaml `/` ```json ` fence와 구별되게 반드시 info-string `spec-review-issues`를 쓴다. orchestrator는 마지막 sentinel block만 파싱한다(anti-injection).
```

3. Update the frontmatter `description` line that says "Output: Status / Issues / Recommendations / Stagnation_signal" → "Output: **Status:** line + `spec-review-issues` sentinel JSON block (category/target_section/severity/message) + Recommendations / Stagnation_signal". Keep everything else.

4. In **"Locked decisions 매핑"** / any place that says issue emit format `[<issue_id>] [<#section>]: <category>` — update to note ids are assigned downstream; the reviewer emits `(category, target_section)` via the sentinel block. (Leave `affects_locked_decisions` behavior as-is; it is orthogonal.)

> **Blind invariant:** do NOT add any mention of codex to this agent (NG6 — reviewers are blind at the review pass). The only new coupling is the structured output shape.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`
Expected: PASS — all pre-existing + new assertions green.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh
git commit -m "feat(spec-distill): spec-reviewer emits sentinel-fenced issue block, drops issue_id self-report"
```

---

## Task 9: `skills/reviewing-spec/SKILL.md` — codex 배선 + Stagnation 절 재작성 + wiring test

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`
- Create: `plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh`

**Interfaces:**
- Produces: SKILL now (⟦detect⟧ detect_codex.sh) → (⟦review-claude⟧ spec-reviewer, verbatim to `--claude-output`) + (⟦review-codex⟧ run_spec_codex_reviewer.sh when available) → (⟦merge⟧ merge_review.py) → routing table consumes `combined_verdict` + `stagnation` flags. "Stagnation detection" 절이 merge_review의 통합-원장 스캔 flag를 escalate 조건으로 사용. degrade advisory 추가. blind: each reviewer gets same-origin history only.
- Consumes: Tasks 1,5,6/7 scripts.

- [ ] **Step 1: Write the failing test** — `plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh`

```bash
#!/usr/bin/env bash
# AC12 + AC15(global) + C8 + wiring invariants — structural grep on SKILL.md.
# Teeth: body-unique phrasing grepped inside section windows (header-satisfiable
# 함정 회피). Mutation proof described in the plan Step 5.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# (1) merge_review.py invoked.
grep -q 'merge_review.py' "$SKILL" && note PASS "merge_review.py invoked" || note FAIL "merge_review.py not wired"
# (2) detect + codex run wired.
grep -q 'detect_codex.sh' "$SKILL" && note PASS "detect_codex.sh wired" || note FAIL "detect_codex.sh missing"
grep -q 'run_spec_codex_reviewer.sh' "$SKILL" && note PASS "run_spec_codex_reviewer.sh wired" || note FAIL "run_spec_codex_reviewer.sh missing"
# (3) combined_verdict feeds routing.
grep -q 'combined_verdict' "$SKILL" && note PASS "combined_verdict → routing" || note FAIL "combined_verdict not fed to routing"

# (4) Stagnation detection section uses merge_review stagnation flag (not Claude self-report ALONE).
#     Body-unique phrase inside the Stagnation section window.
awk '/^### Stagnation detection/{f=1} f{print} /^## /{if(f && !/Stagnation/)exit}' "$SKILL" > /tmp/sd_stag_$$ || true
grep -q 'stagnation' /tmp/sd_stag_$$ && grep -qE 'merge_review|통합.?원장|unified' /tmp/sd_stag_$$ \
  && note PASS "Stagnation section wired to merge_review unified-ledger flag" \
  || note FAIL "Stagnation section still Claude-self-report only"
rm -f /tmp/sd_stag_$$

# (5) C8 verbatim: spec-reviewer raw output stored to --claude-output without summarizing.
grep -qE 'verbatim|그대로|요약.*(금지|말)' "$SKILL" && grep -q -- '--claude-output' "$SKILL" \
  && note PASS "C8: verbatim --claude-output store" || note FAIL "C8: verbatim store not specified"

# (6) AC12 blind-across-rounds: each reviewer gets same-origin history only.
grep -qE 'same-origin|same origin|동일 출처|codex 과거' "$SKILL" \
  && note PASS "AC12: same-origin history (blind)" || note FAIL "AC12: blind history not specified"

# (7) AC15 global kill switch: DEVBREW_DISABLE_SPEC_DISTILL skips the codex path;
#     and Claude review is NOT nested under codex-availability (codex kill != Claude block).
grep -q 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$SKILL" \
  && note PASS "AC15: codex-only kill switch documented" || note FAIL "AC15: codex-only kill switch missing"
grep -qE 'DEVBREW_DISABLE_SPEC_DISTILL\b' "$SKILL" \
  && note PASS "AC15: global kill switch referenced" || note FAIL "AC15: global kill switch missing"

# (8) degrade advisory present.
grep -qE 'degraded|degrade|model diversity 없음' "$SKILL" \
  && note PASS "degrade advisory present" || note FAIL "degrade advisory missing"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh`
Expected: FAIL — SKILL.md not yet wired.

- [ ] **Step 3: Edit `skills/reviewing-spec/SKILL.md`**

Insert a new subsection after Step 2 (Dispatch spec-reviewer) and before Step 3 (Parse output), and rewrite Steps 3-5 + the "Stagnation detection" section. Concretely:

(a) After the spec-reviewer dispatch block, add:
```markdown
### Step 2.5 — codex 병렬 co-review + 결정론 병합 (v0.20.0)

전역 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL=1`)면 이 스텝 전체를 진입하지 않는다(Step 0에서 이미 abort). 아래는 codex 경로이며, **Claude 리뷰(Step 2)는 codex 가용성과 무관하게 항상 수행**된다 — codex kill switch가 Claude 리뷰를 막지 않는다(AC15).

1. **⟦review-claude⟧ verbatim 저장 (C8)**: Step 2에서 받은 spec-reviewer의 **raw 출력을 요약·바꿔쓰기 없이 그대로** scratch 파일 `$CLAUDE_OUT`에 저장한다. 파싱은 merge_review가 그 파일에서 수행하므로, orchestrating 세션이 여기서 category/target_section을 전사하면 안 된다([fc2ef911] 재도입 금지).

2. **⟦detect⟧**:
   ```bash
   codex_avail="$(bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/detect_codex.sh" | sed -n 's/^codex_available: //p')"
   ```
   `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`이면 `codex_available: false` + `skip_reason: kill_switch` — codex만 skip, Claude 리뷰는 이미 정상 수행됨.

3. **⟦review-codex⟧** (codex_avail=true일 때만):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/run_spec_codex_reviewer.sh" \
     "$spec_path" "$(pwd)" "$CODEX_YAML"
   ```
   codex_avail=false면 이 스텝 skip + loud degrade advisory:
   > `[spec-distill v0.20.0] codex co-review SKIPPED (reason: <skip_reason>) — Claude-only, model diversity 없음 (degraded).`

4. **⟦merge⟧ (barrier)** — 두 리뷰가 끝난 뒤 결정론 병합:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/merge_review.py" \
     --claude-output "$CLAUDE_OUT" \
     --codex-yaml "${CODEX_YAML:-/nonexistent}" \
     --history "$LEDGER_JSON"
   ```
   `$LEDGER_JSON`은 **continuity(interview-UUID) state dir**에 둔다(harness-sid로 collapse 금지 — /compact 넘어 re-review cap/stagnation 보존, N1). merge_review가 read-modify-write하므로 issue_history id/count를 세션이 전사하지 않는다.

   merge_review stdout(`combined_verdict` / `stagnation` / `codex_degraded` / `claude_degraded` / `claude_verdict_unrecoverable` / `advisory`)을 파싱한다. `advisory:` 항목은 사용자에게 **그대로 표시**(degrade 인지). codex 미부재여도 `--codex-yaml`이 없으면 merge_review가 `codex_degraded: true`로 처리한다.

5. **blind-across-rounds (AC12, NG6)**: 각 리뷰어에게는 **same-origin history만** 전달한다 — Step 2의 spec-reviewer 프롬프트에 codex 과거 findings를 넣지 않는다(리뷰 pass 상호 blind). 통합 판정은 merge_review(orchestrator-side)만 수행.
```

(b) Rewrite Step 3-5 to consume merge_review output:
```markdown
3. **Parse merge_review output** — `combined_verdict`, `stagnation.per_issue`, `stagnation.round_level`, degrade flags, advisory. (Claude raw output의 Status/Recommendations는 사람 표시용으로만.)
4. **Apply routing table** — `combined_verdict`를 그대로 표에 투입(표 불변).
5. **Ledger는 merge_review가 소유** — `rereview_count += 1`은 기존 continuity 메커니즘대로. `issue_history`는 merge_review가 `$LEDGER_JSON`에 기록하므로 세션이 손으로 갱신하지 않는다(id/count 전사 금지). 세션은 merge_review가 emit한 `issue_history`를 표시만 한다.
```

(c) Rewrite the **"### Stagnation detection"** section:
```markdown
### Stagnation detection (v0.20.0 — 통합-원장 스캔)

stagnation escalate는 이제 **merge_review.py의 통합-원장 스캔** 결과(`stagnation` flag)로 발동한다 — Claude의 `Stagnation_signal: true` self-report 단독이 아니라. blind-across-rounds 때문에 Claude는 codex가 과거에 올린 이슈를 못 보므로, codex-only로 반복된 이슈는 Claude self-report로 절대 잡히지 않는다([6647ebfa] fail-open). merge_review가 통합 원장 위에서 독립 스캔한다:

- **per-issue**: `stagnation.per_issue`에 든 issue_id는 `raised_count >= 3 AND dismissed_by_user == 0` — 두 조건 충족 시 [5] Human Gate forced escalate.
- **round-level**: `stagnation.round_level == true`(새 issue_id 無 + 미해결 잔존)면 즉시 [5] Human Gate escalate. `round_level == inconclusive`(claude_degraded 라운드 — 파싱 실패를 수렴으로 오독 금지, OQ4)면 escalate 트리거로 쓰지 않는다.

Claude의 `Stagnation_signal: true`는 **보조 신호**로 남는다(유일 트리거 아님) — merge_review flag가 primary. `dismissed_by_user >= 1`인 issue는 stagnation에서 제외(P17).
```

(d) Add the codex kill switch to the SKILL's `## kill switch` section:
```markdown
- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`: codex co-review만 skip(Claude 리뷰 정상). combined = Claude verdict + loud degrade advisory.
```

> **Note on scratch paths:** `$CLAUDE_OUT`, `$CODEX_YAML`은 `mktemp`로 만들되 C7 가드(`|| ...`)를 SKILL prose에 명시할 필요는 없다(스크립트가 아니라 세션이 만드는 임시파일이고, 실패해도 merge_review가 `/nonexistent` fallback으로 degrade). `$LEDGER_JSON`만 continuity dir에 안정 경로로 둔다.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh`
Expected: PASS — Fail 0.

- [ ] **Step 5: Mutation check (teeth)** — temporarily delete the `merge_review` mention from the "Stagnation detection" section body only (leave the header); rerun; confirm assertion (4) goes red (proves body-scoped grep, not header-satisfiable); revert.

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh`
Expected (mutated): FAIL on (4). After revert: PASS.

- [ ] **Step 6: Run the full existing SKILL regression suite** (guard against breaking routing/cap tests)

Run:
```bash
for t in test_reviewing_spec_design_routing.sh test_rereview_cap_consistency.sh test_reviewing_spec_design_only.sh test_review_dispatch_design_mandate.sh; do
  echo "== $t =="; bash "plugins/spec-distill/tests/$t" || echo "FAILED: $t"
done
```
Expected: all PASS (routing table + cap invariants untouched).

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh
git commit -m "feat(spec-distill): wire codex co-review + unified-ledger stagnation into reviewing-spec"
```

---

## Task 10: 버전 bump + docs 동기화 (plugin.json / CHANGELOG / README)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh`

**Interfaces:**
- Produces: plugin.json 0.20.0 + CHANGELOG `## [0.20.0] — 2026-07-15` + README (prerequisites codex optional, Principles Instantiated model-diversity, kill switch table entry). test_readme_sync locks the new keywords + version.
- Consumes: nothing.

- [ ] **Step 1: Update the failing test** — `test_readme_sync.sh`

Bump the version invariant to 0.20.x, add the 0.20.0 CHANGELOG entry assertion, and add the codex keyword to the README keyword loop:
```bash
grep -qE '"version": "0\.20\.[0-9]+"' "$PLUGIN_JSON" \
  && note PASS "plugin.json version 0.20.x" || note FAIL "plugin.json not 0.20.x"
grep -qE '^## \[0\.20\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "CHANGELOG [0.20.0] entry with ISO date" || note FAIL "CHANGELOG [0.20.0] missing/!ISO"
grep -qE '^## \[0\.20\.0\].*XX' "$CHANGELOG" \
  && note FAIL "CHANGELOG date has XX placeholder" || note PASS "no XX placeholder in date"
```
And add to the README keyword loop list: `'DEVBREW_DISABLE_SPEC_DISTILL_CODEX'` and `'model diversity'` (keep the existing keywords):
```bash
for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC' 'review_in_progress' 'interview-brief' 'steelman-builder' 'cancel-review' 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' 'model diversity'; do
```
> Keep the existing header comment's version reference generic or bump it to 0.20.0; the pin rationale (unpin patch digit, pin minor) is unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: FAIL — plugin.json still 0.19.3, no 0.20.0 CHANGELOG, README lacks codex keywords.

- [ ] **Step 3: Bump `plugin.json`**

Edit `plugins/spec-distill/.claude-plugin/plugin.json`: `"version": "0.19.3"` → `"version": "0.20.0"`.

- [ ] **Step 4: Add the `CHANGELOG.md` entry** (top, above `## [0.19.0]`)

```markdown
## [0.20.0] — 2026-07-15

### Added
- **codex 병렬 독립 co-reviewer (Phase 3 design-doc 리뷰)** — model diversity를 quality-gates code-review에서 spec-distill의 design-doc 리뷰로 이식. `reviewing-spec`가 Claude `spec-reviewer`와 나란히 codex를 독립 실행하고, `scripts/merge_review.py`(결정론 merge/ledger 엔진)가 **보수적 병합**(precedence `needs_interview > needs_revise > approved`)으로 두 verdict를 합친다 — codex가 Claude의 approved를 needs_revise로 뒤집을 수 있다(fail-open 포착). codex는 `codex exec -s read-only` OS 샌드박스(Law 2 구조적).
- `scripts/detect_codex.sh` (vendored) — codex 가용성 감지. kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`.
- `scripts/build_spec_codex_prompt.py` — design-doc 전용 codex 프롬프트(6 판단형 category, path-only 입력, severity vocab `block|high|medium`).
- `scripts/run_spec_codex_reviewer.sh` — 독립 codex subprocess(**discover-spec.sh AC 주입 없음** — 순환 footgun 회피, C3; mktemp C7 가드).
- `scripts/codex_findings_to_yaml.py` (vendored) — codex JSONL→YAML, emit 키셋에 `category`/`target_section` 추가.
- `scripts/compute_issue_id.py` — 중앙화 issue_id helper(`sha256_short(category + ":" + target_section)`). 두 리뷰어 이슈 모두 여기로 — cross-reviewer collision integrity.
- `scripts/merge_review.py` — 결정론 merge/ledger 엔진: 양쪽 출력 스크립트 파싱(LLM 전사 없음), verdict 유도, 보수적 병합, 4-branch degrade 계층(sentinel/`**Status:**`/codex-alone/fail-safe), 통합-원장 stagnation 스캔.
- tests: `test_detect_codex.sh`, `test_build_spec_codex_prompt.sh`, `test_codex_findings_to_yaml.py`, `test_compute_issue_id.py`, `test_run_spec_codex_reviewer.sh`, `test_merge_review.py`, `test_reviewing_spec_codex_merge.sh` + codex mocks.

### Changed
- `skills/reviewing-spec/SKILL.md` — ⟦detect⟧/⟦review-codex⟧/⟦merge⟧ 스텝 추가, "Stagnation detection" 절을 merge_review의 **통합-원장 스캔 flag**로 재작성(codex-only 반복 이슈 escalate; Claude self-report는 보조 신호). combined_verdict를 기존 routing table에 투입(표 불변). C8 verbatim `--claude-output` 저장.
- `agents/spec-reviewer.md` — issue를 **sentinel-fenced JSON block**(` ```spec-review-issues `, category/target_section/severity/message)으로 emit + top-level `**Status:**` verdict 라인 유지. issue_id self-report 제거(compute_issue_id가 계산). codex 존재 blind 유지.

### Security
- 두 리뷰어 모두 write-denied(codex `-s read-only` 샌드박스 + Claude disallowedTools), 리뷰 pass 상호 blind. codex 부재/실패는 fail-open(조용한 통과)도 fail-closed(spurious block)도 아닌 loud degrade.
```

- [ ] **Step 5: Update `README.md`** (three edits)

1. **Prerequisites** 절에 codex 항목 추가:
```markdown
- **codex CLI** (외부, optional) — 있으면 Phase 3 design-doc 리뷰에 병렬 독립 co-reviewer로 참여(model diversity). 없거나 auth 미설정이면 Claude-only로 graceful degrade + loud advisory(crash 없음). kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`.
```

2. **Principles Instantiated → Law 3 (Compounding)** 근처에 model-diversity 한 줄:
```markdown
- **Law 3 (Compounding) — model diversity (v0.20.0)** — codex 병렬 co-reviewer를 design-doc 리뷰에 추가. codex가 Claude persona가 반복해 놓치는 결함류(fail-open)를 잡으면 → `spec-reviewer.md` 체크리스트 편집(persona = 보안-민감 코드)이 compounding 이벤트. quality-gates codex 패턴의 실증 이력을 상속.
```

3. **Kill switches** 절에 항목 추가(전역 항목 바로 아래):
```markdown
- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` (v0.20.0) — codex 병렬 co-review만 skip. Claude 리뷰는 정상 동작, combined = Claude verdict + loud degrade advisory. 전역 `DEVBREW_DISABLE_SPEC_DISTILL`과 독립.
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: PASS — Fail 0.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "chore(spec-distill): bump 0.20.0 + CHANGELOG + README codex co-reviewer docs"
```

---

## Final Verification (after all tasks)

- [ ] **Run the full spec-distill test suite** and confirm no regressions vs baseline.

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/spec-distill/tests/*.sh; do echo "== $t =="; bash "$t" >/dev/null 2>&1 && echo PASS || echo "FAIL: $t"; done
for t in plugins/spec-distill/tests/test_*.py; do echo "== $t =="; python3 "$t" >/dev/null 2>&1 && echo PASS || echo "FAIL: $t"; done
```
Expected: all new tests PASS; pre-existing tests unchanged (note the known env-dependent reds documented in memory, if any, are pre-existing and unrelated).

- [ ] **Manual e2e (deferred, needs codex installed)** — real design doc through `reviewing-spec`: codex independent review + merge; codex block overturns Claude approved; same codex issue 3x unresolved → unified-ledger stagnation escalate (AC14 e2e); `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` → degrade advisory. (§13 수동 e2e.)

---

## Spec Coverage Map (self-review)

| Spec item | Task |
|---|---|
| AC1 (detect kill switch + qg-var inert) | 1 |
| AC2 (detect skip reasons, exit 0) | 1 |
| AC3 (6 category + vocab block/high/medium) | 3 |
| AC4 (path-only input) | 3 |
| AC5 (no discover-spec.sh) | 5 |
| AC6 (C7 mktemp guard) | 5 |
| AC7 (findings yaml category/target_section + fallback + anti-injection) | 4 |
| AC8 (compute_issue_id determinism/collision) | 2 |
| AC9 (conservative precedence table) | 6 |
| AC9b (symmetric deterministic parsing) | 6 + 7 |
| AC9c (anti-injection + 4-branch verdict recovery) | 6 |
| AC10 (codex failed → degrade to claude) | 6 |
| AC11 (union increment once) | 7 |
| AC12 (same-origin history / blind) | 9 |
| AC13 (0.20.0 + CHANGELOG + README kill switch) | 10 |
| AC14 (unified-ledger codex-only stagnation) | 7 |
| AC15 (kill switch independence: global vs codex-only) | 1 (codex-only) + 9 (global) |
| AC16 (block severity headroom) | 6 |
| OQ1 (line key kept optional) | 4 |
| OQ2 (medium reasoning effort) | 5 |
| OQ3 (Status anchor regex — header-scoped first match) | 6 |
| OQ4 (claude_degraded round inconclusive for round-level) | 7 |
| C7 (mktemp guard) | 5 |
| C8 (verbatim --claude-output) | 9 |
