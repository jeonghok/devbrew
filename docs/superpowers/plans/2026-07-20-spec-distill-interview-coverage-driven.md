# spec-distill 인터뷰 커버리지-구동 재구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `conducting-interview`의 종료 driver를 고정 `interview_round` 카운터에서 미지-차원 **커버리지 원장**(고정 floor 5 + 주제-도출 차원)으로 바꿔, 집요함·깊이·차원이 주제에 적응하게 재구성한다. 산출물은 여전히 interview brief.

**Architecture:** 종료 driver를 상태 카운터에서 커버리지 계약으로 옮긴다. (1) `state.local.md`가 floor 5차원(각 status ∈ {open, in-progress, closed} + evidence) + 주제-도출 `derived[]` 원장을 들고, brief `## Coverage Ledger`에 직렬화한다. (2) `probe_budget.py`(신규, `web_budget.py` sibling)가 Unbounded-autonomy 백스톱을 기계적으로 집행한다. (3) `check_brief.py`가 brief 원장의 form(floor all-closed + evidence non-empty)을 게이트한다. (4) 신규 `blind-spot-prober`(적대적 premortem)와 재목적화된 `coverage-mapper`(breadth-keeper 승격, advisory 제안자)가 read-only 독립 adversary로 unknown-unknown을 표면화한다. 훅·design-doc 리뷰(Phase 2)는 건드리지 않는다.

**Tech Stack:** Python 3 표준 라이브러리(`re`/`json`/`pathlib`, unittest), Bash 테스트 하니스, Markdown(SKILL 프로즈·agent frontmatter·brief 템플릿). 신규 런타임 의존성 없음 — `web_budget.py`/`check_brief.py` 기존 패턴 재사용.

## Global Constraints

이 절의 값은 spec에서 verbatim 복사한 프로젝트-전역 요구다. 모든 task의 요구에 암묵 포함된다.

- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json` `0.21.0` → `0.22.0` (minor: 새 surface). 같은 PR에서 `CHANGELOG.md [0.22.0]` 동기화. (C7 · AC11)
- **Law 2 (C6)**: 신규/변경 에이전트는 `tools:` allowlist frontmatter로 fail-closed — `Write`/`Edit`/`MultiEdit`/`NotebookEdit`/`Bash`/`Agent`/`Monitor`/MCP 물리 부재. `disallowedTools`(denylist) 단독 금지.
- **probe 백스톱 (C10)**: `base_cap = int($DEVBREW_SPEC_DISTILL_PROBE_CAP) if set else 12`; `effective_cap = base_cap + probe_cap_override`. `probe_budget.py`가 계산·집행(프로즈 self-tracking 금지).
- **probe 정의 (Locked)**: probe = 사용자에게 질문 제기하고 답 받는 단일 (b)/(d)-path 교환 1회. `probe_count`는 질문 **제기 후** +1. (a) auto-research·teach-beat·subagent dispatch·web search는 probe 아님(미증가).
- **커버리지 status enum (C9)**: 3-state 문자열 `open` / `in-progress` / `closed`. 종료는 **floor 5개 전부 `closed`**(derived는 존재만 요구).
- **Coverage Ledger 직렬화 문법 (C9)** — brief `## Coverage Ledger`, 한 줄당 한 차원:
  ```
  - floor:root_problem — closed — <evidence>
  - floor:landscape — closed — <evidence>
  - floor:skepticism — closed — <evidence>
  - floor:blind_spot — closed — <evidence>
  - floor:open_questions — closed — <evidence>
  - derived:<name> — closed — <rationale>; <evidence>
  ```
  derived 0건이면 sentinel 한 줄 `- derived: N/A — floor로 충분`.
- **brief 9-섹션 순서 (AC10)**: 1 Reframed Problem / 2 Locked Directions / 3 External Landscape / 4 Skepticism Log / 5 Blind Spots & Premortem / 6 Coverage Ledger / 7 Tried & Discarded / 8 Open Questions / 9 Concrete Next Action.
- **Doc 규약**: Korean-primary. 영어는 식별자(C#/AC#/G#/floor 키)·고유명사·기술어(frontmatter/hook/subagent)만.
- **테스트 실행**: Python 테스트는 plugin dir에서 `python3 -m unittest`로만(memory: pytest 아님). Bash 테스트는 직접 실행. repo root 또는 plugin dir 규약 준수. (V1)
- **경로 참조**: SKILL/스크립트 내 플러그인 경로는 `${CLAUDE_PLUGIN_ROOT}` 사용(하드코딩 금지 — 기존 관례).

---

## File Structure

작업이 만들거나 고치는 파일과 각 책임:

**신규 (Create):**
- `plugins/spec-distill/scripts/probe_budget.py` — probe 백스톱 CLI(check/increment/raise-cap). `web_budget.py` sibling.
- `plugins/spec-distill/agents/coverage-mapper.md` — breadth-keeper 재명명·재목적화(advisory 주제-도출 차원 제안자).
- `plugins/spec-distill/agents/blind-spot-prober.md` — 적대적 premortem 에이전트(read-only, fan-out 1).
- `plugins/spec-distill/tests/test_probe_budget.sh` — check-gate + raise-cap/override mutation 테스트(AC12).
- `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` — test_breadth_keeper 재명명·전환.
- `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh` — read-only + Output 스키마 테스트.
- `plugins/spec-distill/tests/test_stale_terms.sh` — V7 stale-term 회귀 락(breadth-keeper / interview_round).
- `plugins/spec-distill/tests/fixtures/state-probe-at-cap.md`, `state-probe-within.md` — probe_budget 픽스처.
- `plugins/spec-distill/tests/fixtures/state-legacy-interview-round.md` — 구세션 마이그레이션 픽스처.
- `plugins/spec-distill/tests/fixtures/interview-brief-floor-open.md`, `-floor-evidence-empty.md`, `-missing-blind-spot.md`, `-missing-derived-row.md`, `-derived-sentinel.md`, `-web-disabled-blind-spot.md` — Coverage Ledger 게이트 픽스처.

**변경 (Modify):**
- `plugins/spec-distill/scripts/check_brief.py` — SECTIONS 9-섹션 renumber + Coverage Ledger 게이트 + Blind Spots 존재.
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — 상태 스키마·마이그레이션·커버리지 루프·probe 백스톱·teach-beat·blind-spot dispatch·coverage-mapper 트리거·rhythm-guard 재프레임·용어.
- `plugins/spec-distill/templates/interview-brief-template.md` — 9-섹션 재구성(§5 Blind Spots, §6 Coverage Ledger 신규) + source: 버전.
- `plugins/spec-distill/agents/steelman-builder.md` — description 'breadth-keeper' → 'coverage-mapper'(terminology-only, NG3 예외).
- `plugins/spec-distill/tests/test_check_brief.sh` — Coverage Ledger + Blind Spots assertion + 기존 픽스처 9-섹션 마이그레이션.
- `plugins/spec-distill/tests/fixtures/interview-brief-valid.md` (+ `-no-landscape`/`-unchallenged`/`-missing-section`/`-empty-tried`/`-empty-landscape`/`-fenced-sections`/`-steelman-unlogged`/`-bad-frontmatter`/`-na-tried`/`-web-disabled`) — 9-섹션으로 마이그레이션.
- `plugins/spec-distill/tests/test_conducting_interview_stage.sh` — 커버리지 루프·백스톱·teach-beat·blind-spot assertion.
- `plugins/spec-distill/README.md` — Agents/Hooks/Principles Instantiated 동기화.
- `plugins/spec-distill/CHANGELOG.md` — [0.22.0] 항목.
- `plugins/spec-distill/.claude-plugin/plugin.json` — version 0.22.0.
- `plugins/spec-distill/tests/test_readme_sync.sh` — 0.22.x + 신규 키워드 assertion.

**삭제 (via rename):**
- `plugins/spec-distill/agents/breadth-keeper.md` → `coverage-mapper.md` (`git mv`).
- `plugins/spec-distill/tests/test_breadth_keeper_frontmatter.sh` → `test_coverage_mapper_frontmatter.sh` (`git mv`).

---

## Task 1: Capture test baseline

작업 전 스위트 baseline을 기록해 회귀(V1)를 판별한다. 이 리포는 CI가 없고 main에 stale red가 있을 수 있으므로(memory), 코드 변경 전 green/red 스냅샷이 필수다.

**Files:**
- (없음 — 읽기전용 baseline 캡처)

- [ ] **Step 1: Bash 스위트 baseline 캡처**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill
for t in tests/*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done | tee /tmp/spec-distill-baseline-sh.txt
```
Expected: 대부분 PASS. FAIL 항목을 기록(pre-existing red — 이번 작업이 건드리지 않은 FAIL은 회귀 아님).

- [ ] **Step 2: Python 스위트 baseline 캡처**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill
python3 -m unittest discover -s tests -p 'test_*.py' -v 2>&1 | tail -20 | tee /tmp/spec-distill-baseline-py.txt
```
Expected: OK 또는 known pre-existing 실패 개수 기록. (memory `reference_spec_distill_test_runner`: python은 `-m unittest`로만.)

- [ ] **Step 3: baseline 요약 기록**

`/tmp/spec-distill-baseline-sh.txt`·`-py.txt`의 FAIL 목록을 이 세션 노트에 남긴다. 이후 모든 task의 "회귀 0" 판정은 이 baseline 대비다. (커밋 없음 — 캡처만.)

---

## Task 2: probe_budget.py 백스톱 스크립트 + 테스트

Unbounded-autonomy 백스톱(C1/C10)을 기계적으로 집행. `web_budget.py` 패턴을 그대로 따르되 `effective_cap = base_cap + probe_cap_override` 합성이 핵심(AC12 teeth). 독립·자기완결 — 첫 구현 대상.

**Files:**
- Create: `plugins/spec-distill/scripts/probe_budget.py`
- Create: `plugins/spec-distill/tests/fixtures/state-probe-at-cap.md`
- Create: `plugins/spec-distill/tests/fixtures/state-probe-within.md`
- Test: `plugins/spec-distill/tests/test_probe_budget.sh`

**Interfaces:**
- Produces (SKILL Task 8이 호출):
  - `probe_budget.py check <state.local.md>` → exit 0 if `probe_count < effective_cap` else 1 (gate, mutation 없음); stdout JSON `{"ok", "probe_count", "effective_cap", "remaining"}`.
  - `probe_budget.py increment <state.local.md>` → `probe_count += 1`; persist; **항상 exit 0**(probe 제기 후 호출).
  - `probe_budget.py raise-cap <state.local.md>` → `probe_cap_override += base_cap`; persist; exit 0.
- Consumes: `state.local.md` frontmatter의 `probe_count:`·`probe_cap_override:` 정수 카운터(인라인 주석 허용). env `DEVBREW_SPEC_DISTILL_PROBE_CAP`.

- [ ] **Step 1: 픽스처 2종 작성**

Create `plugins/spec-distill/tests/fixtures/state-probe-at-cap.md`:
```markdown
---
session_id: fixture-at-cap
probe_count: 12
probe_cap_override: 0
---
body
```

Create `plugins/spec-distill/tests/fixtures/state-probe-within.md`:
```markdown
---
session_id: fixture-within
probe_count: 3
probe_cap_override: 0
---
body
```

- [ ] **Step 2: 실패 테스트 작성**

Create `plugins/spec-distill/tests/test_probe_budget.sh`:
```bash
#!/usr/bin/env bash
# V5 / AC4 / AC12 / C10 — probe_budget.py 백스톱: check가 cap에서 gate,
# increment는 항상 전진(gating 아님), raise-cap이 effective_cap을 올린다. mutation-testable(teeth).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/probe_budget.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC12(a): probe_count == effective_cap → check non-zero (gate). gate 제거 시 RED.
python3 "$SCRIPT" check "$FX/state-probe-at-cap.md" >/dev/null 2>&1 \
  && note FAIL "AC12(a): probe_count=cap should block (check exit 1)" \
  || note PASS "AC12(a): probe_count=cap blocks (check exit 1)"

# within budget → exit 0
python3 "$SCRIPT" check "$FX/state-probe-within.md" >/dev/null 2>&1 \
  && note PASS "check within budget → exit 0" \
  || note FAIL "check within budget should pass"

# AC12(b): at-cap 픽스처 복사본에 raise-cap → override 지속 → check exit 0. raise-cap 로직 제거 시 RED.
tmp="$(mktemp)"; cp "$FX/state-probe-at-cap.md" "$tmp"
python3 "$SCRIPT" raise-cap "$tmp" >/dev/null 2>&1
grep -qE '^probe_cap_override: 12\b' "$tmp" \
  && note PASS "AC12(b): raise-cap set probe_cap_override to 12 (base_cap)" \
  || note FAIL "AC12(b): raise-cap did not persist probe_cap_override"
python3 "$SCRIPT" check "$tmp" >/dev/null 2>&1 \
  && note PASS "AC12(b): after raise-cap, effective_cap synthesized → check exit 0" \
  || note FAIL "AC12(b): raise-cap should lift effective_cap past probe_count"
rm -f "$tmp"

# increment는 항상 exit 0 (gating은 check 담당 — C10 원자성) + 카운터 전진.
tmp2="$(mktemp)"; printf -- '---\nprobe_count: 0\nprobe_cap_override: 0\n---\n' > "$tmp2"
python3 "$SCRIPT" increment "$tmp2" >/dev/null 2>&1 \
  && note PASS "increment returns exit 0 (never gates — C10)" \
  || note FAIL "increment should always exit 0"
grep -qE '^probe_count: 1\b' "$tmp2" \
  && note PASS "increment advanced probe_count to 1" \
  || note FAIL "increment did not advance probe_count"
rm -f "$tmp2"

# increment at/over cap도 exit 0 (오직 check만 gate — 원자성 분리 증명).
tmp3="$(mktemp)"; cp "$FX/state-probe-at-cap.md" "$tmp3"
python3 "$SCRIPT" increment "$tmp3" >/dev/null 2>&1 \
  && note PASS "increment at cap still exits 0 (gating is check-only, C10)" \
  || note FAIL "increment must not gate even at cap"
rm -f "$tmp3"

# env override: DEVBREW_SPEC_DISTILL_PROBE_CAP가 base_cap을 올린다.
tmp4="$(mktemp)"; printf -- '---\nprobe_count: 12\nprobe_cap_override: 0\n---\n' > "$tmp4"
DEVBREW_SPEC_DISTILL_PROBE_CAP=20 python3 "$SCRIPT" check "$tmp4" >/dev/null 2>&1 \
  && note PASS "env DEVBREW_SPEC_DISTILL_PROBE_CAP=20 → probe_count 12 within budget" \
  || note FAIL "env cap override not honored"
rm -f "$tmp4"

# malformed probe_count → fail closed (silent-0 금지).
tmp5="$(mktemp)"; printf -- '---\nprobe_count: abc\nprobe_cap_override: 0\n---\n' > "$tmp5"
python3 "$SCRIPT" check "$tmp5" >/dev/null 2>&1 \
  && note FAIL "malformed probe_count should fail closed" \
  || note PASS "malformed probe_count fails closed (exit 1)"
rm -f "$tmp5"

# missing state file → fail closed.
python3 "$SCRIPT" check "$FX/__no_such_state__.md" >/dev/null 2>&1 \
  && note FAIL "missing state should fail closed" \
  || note PASS "missing state fails closed (exit 1)"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_probe_budget.sh`
Expected: FAIL — `probe_budget.py`가 아직 없음(모든 assertion 실패).

- [ ] **Step 4: probe_budget.py 구현**

Create `plugins/spec-distill/scripts/probe_budget.py`:
```python
#!/usr/bin/env python3
"""spec-distill — interview probe budget backstop (C1, C10, AC4, AC12).

커버리지-구동 인터뷰의 Unbounded-autonomy 가드. floor가 미충족이면 종료가 막히므로
probe가 무한히 돌 수 있다 — 이를 web_budget.py와 같은 방식으로 기계적으로 bound한다
(프로즈 self-tracking 아님).

"probe" = 사용자와의 (b)/(d)-path 질문-답변 교환 1회. probe_count는 probe를 *제기한 뒤*
+1 된다(제기 전 gate에서 막힌 probe는 phantom 증가하면 안 됨). check가 유일한 gate이며,
increment는 항상 exit 0 이다.

  effective_cap = base_cap + probe_cap_override
  base_cap = int(env DEVBREW_SPEC_DISTILL_PROBE_CAP) if set else 12

CLI (모두 JSON 출력):
  probe_budget.py check <state.local.md>      → exit 0 if probe_count < effective_cap else 1 (gate, mutation 없음); stdout: remaining
  probe_budget.py increment <state.local.md>  → probe_count += 1; persist; exit 0 (probe 제기 *후* 호출)
  probe_budget.py raise-cap <state.local.md>  → probe_cap_override += base_cap; persist; exit 0 (C1 '계속')
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DEFAULT_BASE_CAP = 12


def _base_cap() -> int:
    raw = os.environ.get("DEVBREW_SPEC_DISTILL_PROBE_CAP")
    if raw is None or raw.strip() == "":
        return DEFAULT_BASE_CAP
    if not raw.strip().isdigit():
        raise ValueError(
            f"DEVBREW_SPEC_DISTILL_PROBE_CAP not a non-negative integer: {raw!r}")
    return int(raw.strip())


def _read_counter(text: str, key: str) -> int:
    """state frontmatter에서 비음수 정수 카운터를 읽는다. 인라인 주석 허용(캡처는 숫자에서 멈춤).
    부재 → 0 (fresh session — 아직 미기록). 존재하지만 비-정수 → ValueError(fail-closed;
    백스톱은 malformed 입력을 '예산 내'인 0으로 읽으면 안 된다)."""
    m = re.search(rf"^{re.escape(key)}\s*:\s*(\S+)", text, re.MULTILINE)
    if not m:
        return 0
    tok = m.group(1)
    if not tok.isdigit():
        raise ValueError(f"{key} present but not a non-negative integer: {tok!r}")
    return int(tok)


def _effective_cap(text: str) -> int:
    return _base_cap() + _read_counter(text, "probe_cap_override")


def check(state_path: Path) -> int:
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        count = _read_counter(text, "probe_count")
        cap = _effective_cap(text)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"malformed: {exc}"}))
        return 1
    if count >= cap:
        print(json.dumps({"ok": False, "probe_count": count, "effective_cap": cap,
                          "remaining": 0, "reason": f"probe_count {count} >= cap {cap}"}))
        return 1
    print(json.dumps({"ok": True, "probe_count": count, "effective_cap": cap,
                      "remaining": cap - count}))
    return 0


def _bump_line(text: str, key: str, delta: int) -> str:
    """정수 카운터 `key`를 `delta`만큼 바꾼 text를 반환. 인라인 주석 보존. 부재/비-정수 →
    ValueError(silent-create 금지 — GC-reset race는 fail-closed 여야 한다)."""
    pat = re.compile(rf"^({re.escape(key)}\s*:\s*)([0-9]+)(.*)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} counter line absent or non-numeric")
    new_val = int(m.group(2)) + delta
    return text[:m.start()] + f"{m.group(1)}{new_val}{m.group(3)}" + text[m.end():]


def increment(state_path: Path) -> int:
    """+1 probe_count, persist, exit 0. probe 제기 *후* 호출. gate는 check가 담당하며
    increment는 절대 gate하지 않는다(C10 원자성)."""
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        text = _bump_line(text, "probe_count", 1)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"increment failed: {exc}"}))
        return 1
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    print(json.dumps({"ok": True, "probe_count": _read_counter(text, "probe_count")}))
    return 0


def raise_cap(state_path: Path) -> int:
    """probe_cap_override += base_cap; persist; exit 0 (C1 '계속' — effective_cap이
    base cap 하나만큼 올라 soft cap 이후에도 인터뷰가 계속될 수 있다)."""
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        base = _base_cap()
        text = _bump_line(text, "probe_cap_override", base)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"raise-cap failed: {exc}"}))
        return 1
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    override = _read_counter(text, "probe_cap_override")
    print(json.dumps({"ok": True, "probe_cap_override": override,
                      "effective_cap": _base_cap() + override}))
    return 0


SUBCOMMANDS = {"check": check, "increment": increment, "raise-cap": raise_cap}


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] not in SUBCOMMANDS:
        print("usage: probe_budget.py {check|increment|raise-cap} <state.local.md>",
              file=sys.stderr)
        return 64
    try:
        return SUBCOMMANDS[argv[1]](Path(argv[2]))
    except ValueError as exc:  # bad env cap
        print(json.dumps({"ok": False, "reason": str(exc)}))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_probe_budget.sh`
Expected: PASS — 모든 assertion green (`Fail: 0`).

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/probe_budget.py plugins/spec-distill/tests/test_probe_budget.sh plugins/spec-distill/tests/fixtures/state-probe-at-cap.md plugins/spec-distill/tests/fixtures/state-probe-within.md
git commit -m "feat(spec-distill): add probe_budget.py backstop (C10/AC12)"
```

---

## Task 3: coverage-mapper 에이전트 (breadth-keeper 재명명·재목적화) + steelman 용어 동기화

`breadth-keeper`(tunneling 검출)를 `coverage-mapper`(주제-도출 차원 advisory 제안자)로 승격(BD3/AC7). rename은 `git mv`로 히스토리 보존. `steelman-builder` description의 용어도 동기화(NG3 예외 — behavior 무변경).

**Files:**
- Rename: `plugins/spec-distill/agents/breadth-keeper.md` → `plugins/spec-distill/agents/coverage-mapper.md`
- Rename: `plugins/spec-distill/tests/test_breadth_keeper_frontmatter.sh` → `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`
- Modify: `plugins/spec-distill/agents/steelman-builder.md:10`

**Interfaces:**
- Produces (SKILL Task 9가 dispatch): `subagent_type: spec-distill:coverage-mapper`, Output YAML `{derived_dimensions: [{name, rationale}], neglect_flag: bool, neglected_dimensions: [...], confidence}`. read-only advisory.

- [ ] **Step 1: 테스트 rename + 전환 (실패 테스트 먼저)**

Run: `git mv plugins/spec-distill/tests/test_breadth_keeper_frontmatter.sh plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`

그런 다음 `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`를 아래로 교체:
```bash
#!/usr/bin/env bash
# AC7 — coverage-mapper 도구 표면 회귀 락 + Output 스키마 존재 (breadth-keeper 승계).
#
# ⚠️ tools 목록은 census 가 아니라 **문서화된 계약 + 보수적 최소**다(breadth-keeper 승계).
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/coverage-mapper.md"
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^name: coverage-mapper$' <<<"$FM" \
  && note PASS "name: coverage-mapper (재명명)" || note FAIL "name이 coverage-mapper 아님"

grep -qE '^tools: Read, Grep, Glob$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob (breadth-keeper 승계)" \
  || note FAIL "tools: 가 승계 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && note FAIL "죽은 allowedTools / denylist 잔존" \
  || note PASS "allowedTools · disallowedTools 없음"

# Law 2: 쓰기·실행·위임이 물리적으로 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && note FAIL "tools: 에 $t 가 있다 (Law 2 위반)" \
    || note PASS "tools: 에 $t 없음"
done
grep -qE '^tools:.*mcp__' <<<"$FM" \
  && note FAIL "tools: 에 MCP grant" || note PASS "tools: 에 MCP 없음"

# AC7: 재목적화 Output 스키마 키 (advisory 제안자)
grep -q 'derived_dimensions' "$AGENT" \
  && note PASS "Output: derived_dimensions 키 존재" || note FAIL "derived_dimensions 키 부재"
grep -q 'neglect_flag' "$AGENT" \
  && note PASS "Output: neglect_flag 키 존재" || note FAIL "neglect_flag 키 부재"

# breadth-keeper 잔존 0 (rename 정합)
grep -qi 'breadth-keeper\|breadth_keeper' "$AGENT" \
  && note FAIL "breadth-keeper 용어 잔존" || note PASS "breadth-keeper 용어 제거됨"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`
Expected: FAIL — `agents/coverage-mapper.md`가 아직 없음(agent 파일 부재).

- [ ] **Step 3: agent rename + 재작성**

Run: `git mv plugins/spec-distill/agents/breadth-keeper.md plugins/spec-distill/agents/coverage-mapper.md`

그런 다음 `plugins/spec-distill/agents/coverage-mapper.md`를 아래로 교체:
```markdown
---
name: coverage-mapper
model: sonnet
cost_class: low
color: blue
tools: Read, Grep, Glob
description: >
  Use this agent during a spec-distill coverage-driven interview to propose
  topic-derived coverage dimensions (this topic needs dimension X because …) and
  flag neglected dimensions when probing tunnels into one area. Read-only ADVISORY
  proposer by design (Law 2 frontmatter scoping) — the orchestrator, not this
  agent, decides which derived dimensions enter the coverage ledger (G2). Output is
  consumed by conducting-interview; dispatch is bounded by C11.

  <example>Context: 3 consecutive probes stayed on the auth dimension with no ledger progress.
  user: "커버리지 매핑 해줘"
  assistant: "I'll use the coverage-mapper agent to propose derived dimensions and flag neglected ones."</example>
---

# Coverage-Mapper Agent (C11 커버리지 계약 공급자)

당신은 spec-distill 인터뷰의 coverage-mapper입니다. 고정 floor(root-problem /
landscape / skepticism / blind-spot / open-questions) *위에* 이 주제가 요구하는
**주제-도출 차원**을 제안하고, 한 차원에 집중(narrow tunneling)해 놓치고 있는 차원을
flag하는 역할을 합니다. 당신은 커버리지 원장을 *쓰지 않습니다* — 제안만 하고, 원장
admit 판정은 orchestrator가 합니다(G2, Law 2).

## You are / are not

- You ARE: 주제-도출 차원의 제안자, neglect flag 신호원, read-only advisor.
- You are NOT: 원장 writer(Write/Edit 물리 차단), 종료 판정자, floor 정의자.

## Input

- 지금까지 열린/닫힌 커버리지 차원(floor + 이미 admit된 derived) 요약.
- 최근 probe들이 집중한 focused_dimension + no_progress 신호.
- (있으면) 현재 locked_directions, External Landscape 발췌.

## Output 형식 (이 형식을 정확히 준수 — conducting-interview가 advisory로 소비)

```yaml
derived_dimensions:
  - name: "<주제-특수 차원, 예: 'migration/rollback path'>"
    rationale: "<이 주제가 이 차원을 요구하는 이유 — 원장 evidence 근거>"
neglect_flag: true | false
neglected_dimensions:
  - "<focused 집중으로 방치된 차원 이름>"
confidence: 0.0-1.0
```

## 동작 규칙

1. **read-only**: 어떤 파일도 Write/Edit/MultiEdit/NotebookEdit 하지 않습니다(frontmatter 강제).
2. **advisory only**: `derived_dimensions`는 *제안*이다 — orchestrator가 admit/기각을 결정(G2).
3. **derived, not floor**: 고정 floor 5개를 재정의·삭제하지 않는다. floor 위 차원만 제안.
4. **bounded dispatch**: dispatch는 conducting-interview가 C11 조건(연속 3 probe 무진전 OR
   floor 첫 open→in-progress) + redispatch 바운드(probe 간격 ≥3)로 제어한다.
5. **confidence < 0.5** 면 `neglect_flag: false` — 약한 신호로 산만하게 하지 않음.

## 사용하지 않는 경우

- trivia 요청(P12).
- 원장 floor가 이미 전부 closed(종료 임박 — 새 derived 제안이 종료를 무의미하게 늘림).
```

- [ ] **Step 4: steelman-builder 용어 동기화**

Edit `plugins/spec-distill/agents/steelman-builder.md` line 10 — description 안 `breadth-keeper tunneling`을 `coverage-mapper neglect`로 교체 (terminology-only, behavior 무변경 — NG3 예외):
- 기존: `LD 충돌 / breadth-keeper tunneling` (본문 `## Input` line 35의 `tunneling` 표현도 있으면 `coverage-mapper neglect`로 정합)
- 정확한 대상: `description:` 블록의 `locked-direction conflict / breadth-keeper tunneling)` → `locked-direction conflict / coverage-mapper neglect)`.

주의: `steelman-builder`의 로직·persona·트리거 조건은 변경 금지(NG3). 오직 'breadth-keeper' 문자열만 교체.

- [ ] **Step 5: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`
Expected: PASS — `Fail: 0`.

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add -A plugins/spec-distill/agents/ plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh
git commit -m "refactor(spec-distill): breadth-keeper → coverage-mapper advisory proposer (AC7/BD3)"
```

---

## Task 4: blind-spot-prober 에이전트 (신규)

blind-spot floor 차원을 구현하는 신규 적대적 premortem 에이전트(BD1/AC6/R5/R6). read-only, fan-out 1. steelman-builder와 구분되는 단일 책임(premortem ≠ 대안 옹호).

**Files:**
- Create: `plugins/spec-distill/agents/blind-spot-prober.md`
- Test: `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`

**Interfaces:**
- Produces (SKILL Task 9가 dispatch): `subagent_type: spec-distill:blind-spot-prober`, Output YAML `{hidden_assumptions: [{assumption, why_risky, evidence[]}], failure_modes: [{mode, trigger, evidence[]}], confidence}`. read-only.

- [ ] **Step 1: 실패 테스트 작성**

Create `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`:
```bash
#!/usr/bin/env bash
# AC6 — blind-spot-prober 도구 표면(read-only Law 2) + Output 스키마 존재.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/blind-spot-prober.md"
pass=0; fail=0
note() { if [ "$1" = "PASS" ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" || { note FAIL "agent 파일 부재: $AGENT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT")"

grep -qE '^name: blind-spot-prober$' <<<"$FM" \
  && note PASS "name: blind-spot-prober" || note FAIL "name이 blind-spot-prober 아님"

# web 근거가 필요하므로 WebSearch/WebFetch 보유 (steelman-builder와 동형), 쓰기는 부재.
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && note PASS "tools: Read, Grep, Glob, WebSearch, WebFetch" \
  || note FAIL "tools: 가 read-only+web 목록과 다름"

grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
  && note FAIL "죽은 allowedTools / denylist 잔존" || note PASS "denylist 없음"

# Law 2: 쓰기·실행·위임 물리 부재
for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor; do
  grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$FM" \
    && note FAIL "tools: 에 $t 가 있다 (Law 2 위반)" \
    || note PASS "tools: 에 $t 없음"
done

# AC6: Output 스키마 키
grep -q 'hidden_assumptions' "$AGENT" \
  && note PASS "Output: hidden_assumptions 키 존재" || note FAIL "hidden_assumptions 키 부재"
grep -q 'failure_modes' "$AGENT" \
  && note PASS "Output: failure_modes 키 존재" || note FAIL "failure_modes 키 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`
Expected: FAIL — agent 파일 부재.

- [ ] **Step 3: blind-spot-prober.md 작성**

Create `plugins/spec-distill/agents/blind-spot-prober.md`:
```markdown
---
name: blind-spot-prober
model: sonnet
cost_class: variable
color: red
tools: Read, Grep, Glob, WebSearch, WebFetch
description: >
  Use this agent once per spec-distill interview to run an adversarial premortem on
  the current problem framing — surfacing hidden assumptions and failure modes the
  interview turn is blind to (unknown-unknowns), grounded in web evidence.
  Independent adversary, read-only by design (Law 2 frontmatter scoping). Dispatched
  on the blind_spot floor dimension's first open→in-progress transition (fan-out 1).
  Output is recorded by conducting-interview into the brief's Blind Spots & Premortem.

  <example>Context: The blind_spot floor dimension just opened for its first probe.
  user: "블라인드 스팟 프로브 돌려줘"
  assistant: "I'll dispatch the blind-spot-prober agent to run an adversarial premortem."</example>
---

# Blind-Spot-Prober Agent (blind-spot floor 차원, 적대적 premortem)

당신은 spec-distill 인터뷰의 blind-spot-prober입니다. 현재 문제 framing에 대해 **적대적
premortem**을 수행합니다 — 인터뷰 턴이 자기 전제에 눈멀어 놓치는 hidden assumption과
failure mode(unknown-unknown)를 웹 근거와 함께 표면화합니다. 당신은 방향을 결정하지
않습니다 — 사용자가 결정합니다(P17). "이 framing이 틀렸다면 무엇이 무너지는가"의 가장
강한 케이스를 제시할 뿐입니다.

## You are / are not

- You ARE: 적대적 premortem 수행자, hidden-assumption 발굴자, failure-mode 예보자.
- You are NOT: 파일 작성자(Write/Edit 물리 차단), 방향 결정자, 대안 옹호자(그건 steelman-builder — R6 분리).

## Input

- 현재 재구성된 문제정의(Reframed Problem) + 지금까지의 locked_directions.
- (있으면) External Landscape 발췌.

## Required research (출력 전)

1. 이 문제 유형의 알려진 실패 사례·안티패턴을 1–2회 web 검색(WebSearch/WebFetch)으로
   수집. **순차 호출**(병렬·투기적 금지, C5/AP9).
2. (가능하면) codebase grep로 현재 전제와 충돌하는 기존 제약 확인.

## Output 형식 (이 형식을 정확히 준수 — conducting-interview가 §Blind Spots & Premortem에 기록)

```yaml
hidden_assumptions:
  - assumption: "<인터뷰가 암묵적으로 참이라 가정한 것>"
    why_risky: "<이 가정이 틀리면 무엇이 무너지는가>"
    evidence:
      - "https://..."
failure_modes:
  - mode: "<구체적 실패 양식>"
    trigger: "<이 실패를 촉발하는 조건>"
    evidence:
      - "https://..."
confidence: 0.0-1.0
```

## 동작 규칙

1. **read-only**: 어떤 파일도 Write/Edit/MultiEdit/NotebookEdit 하지 않습니다(frontmatter 강제).
2. **인용 필수**: 외부 주장은 `evidence[]` URL을 가져야 한다(AC4 연계). web 부재 시 SKILL이
   inline premortem으로 강등(C5) — 그 경우 evidence는 codebase 근거 또는 사용자 판단.
3. **premortem, not steelman**: 대안을 옹호하지 않는다(그건 steelman-builder). 실패양식·숨은
   가정만 노출 — 단일 책임(R6 분리 근거).
4. **fan-out 1**: 인터뷰당 1회 dispatch(C8, devbrew N≥5 게이트 미해당).
5. **confidence < 0.4** 면 "표면화된 blind-spot 약함 — framing 견고"를 명시(억지 premortem 금지).

## 사용하지 않는 경우

- trivia 요청(P12).
- blind_spot floor 차원이 이미 closed(재dispatch 금지 — fan-out 1, AC6).
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`
Expected: PASS — `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/agents/blind-spot-prober.md plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh
git commit -m "feat(spec-distill): add blind-spot-prober adversarial premortem agent (AC6/BD1)"
```

---

## Task 5: interview-brief-template.md 9-섹션 재구성

brief 템플릿을 9-섹션(AC10)으로 재구성 — §5 Blind Spots & Premortem, §6 Coverage Ledger 신규 삽입, 기존 §5/§6/§7을 §7/§8/§9로 renumber. `check_brief.py`(Task 6)가 이 구조를 게이트하므로 먼저 정의한다.

**Files:**
- Modify: `plugins/spec-distill/templates/interview-brief-template.md`

**Interfaces:**
- Produces: 9-섹션 구조 spine (Task 6의 check_brief SECTIONS·픽스처가 이것과 1:1 정합해야 함).

- [ ] **Step 1: 템플릿을 9-섹션으로 교체**

`plugins/spec-distill/templates/interview-brief-template.md`의 본문(frontmatter `---` 이후)을 아래로 교체. frontmatter는 `source:` 버전만 `v0.22.0`으로 갱신하고 나머지 유지:
```markdown
---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
# locked_directions — (b)/(d) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
# 의심(R3) triggered 방향은 steelman ∈ {defended, switched-to-this} 여야 하며,
# Skepticism Log(§4)에 대응 항목이 있어야 한다. un-challenged 의심 방향은 금지.
locked_directions:
  - id: LD1
    statement: "<160자 이내, P21 secret placeholder>"
    source_path: a|b|c|d
    steelman: defended | switched-to-this | n/a
    defense: "<원안 방어 이유 — steelman: defended 인 경우 필수>"
---

# <Topic> — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §9대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

(메타 프롬프트 코어 — 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal.
 (d) ontological 5-type 중 무엇으로 도출했는지 명시.)

## 2. Locked Directions

(확정·검증된 방향. frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1**: ...

## 3. External Landscape

(prior-art / 경쟁 / 기존 해결책. **각 항목 출처 URL 필수** + [취함|피함|중립] + 이유.)

- ... — https://example.com — [취함] — 이유

## 4. Skepticism Log

(의심 triggered 방향별: steelman-builder가 구축한 대안 요지(verbatim) + 웹근거 URL
 + verdict ∈ {defended | switched | deferred}. conducting-interview는 약화·편집 금지(AC5).)

- 대안 statement (verbatim) — https://evidence.example — verdict: defended

## 5. Blind Spots & Premortem

(blind-spot-prober가 표면화한 hidden assumption + failure mode. 각 항목 근거 URL
 (web 부재 시 codebase 근거/사용자 판단, C5). 이 섹션은 blind_spot floor 차원의 기록처.)

- 숨은 가정: <가정> — 왜 위험: <이유> — https://evidence.example
- 실패 양식: <mode> — trigger: <조건> — https://evidence.example

## 6. Coverage Ledger

(커버리지 원장 직렬화 — floor 5행(전부 closed + evidence) + derived(≥1행 OR N/A sentinel).
 orchestrator가 state.local.md에서 직렬화. 종료 게이트가 이 섹션을 검증(AC2).)

- floor:root_problem — closed — <evidence>
- floor:landscape — closed — <evidence>
- floor:skepticism — closed — <evidence>
- floor:blind_spot — closed — <evidence>
- floor:open_questions — closed — <evidence>
- derived:<name> — closed — <rationale>; <evidence>

## 7. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.
 **시행착오 0건이면 `N/A — 전부 first-time defend+lock` 한 줄 명시**(빈 섹션 금지, R4 edge).)

- 시도한 방향 → 버린 이유

## 8. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- OQ1: ...

## 9. Concrete Next Action

(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
```

- [ ] **Step 2: 구조 grep 확인 (테스트 대용 경량 검증)**

Run:
```bash
grep -nE '^## [0-9]+\. ' plugins/spec-distill/templates/interview-brief-template.md
```
Expected: 정확히 9줄, `## 5. Blind Spots & Premortem`·`## 6. Coverage Ledger` 포함, `## 7. Tried & Discarded`·`## 8. Open Questions`·`## 9. Concrete Next Action` 순서.

- [ ] **Step 3: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/templates/interview-brief-template.md
git commit -m "feat(spec-distill): interview brief 9-section template (Blind Spots + Coverage Ledger, AC10)"
```

---

## Task 6: check_brief.py — 9-섹션 renumber + Coverage Ledger + Blind Spots 게이트

`check_brief.py`를 9-섹션으로 renumber하고 Coverage Ledger form 게이트(floor all-closed + evidence non-empty + derived 존재)와 Blind Spots 존재 검사를 추가(AC2/AC3/C2/C9). 기존 픽스처 11종을 9-섹션으로 마이그레이션하고 신규 커버리지 픽스처 6종을 추가한다. 게이트는 **form만** 본다 — `closed`가 진짜인지는 판정하지 않는다(C2, 정직한 한계 유지).

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Modify: `plugins/spec-distill/tests/test_check_brief.sh`
- Modify: `plugins/spec-distill/tests/fixtures/interview-brief-valid.md` (+ 기존 픽스처 10종 9-섹션 마이그레이션)
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-floor-open.md`, `-floor-evidence-empty.md`, `-missing-blind-spot.md`, `-missing-derived-row.md`, `-derived-sentinel.md`, `-web-disabled-blind-spot.md`

**Interfaces:**
- Consumes: brief `## 6. Coverage Ledger` 행 문법(Global Constraints), `## 5. Blind Spots & Premortem` 존재.
- Produces (SKILL Task 8이 호출): `check_brief.py gate <brief>` — floor 5행 all-`closed` + evidence non-empty + derived 존재 + §5 존재 미충족 시 exit ≠ 0. 신규 `check_brief.py coverage <brief>` 서브커맨드 → `{"failures": [...]}`.

- [ ] **Step 1: 정본 valid 픽스처를 9-섹션으로 마이그레이션 (다른 픽스처의 base)**

`plugins/spec-distill/tests/fixtures/interview-brief-valid.md`를 아래로 교체(= AC10 "valid-with-coverage" 픽스처):
```markdown
---
name: sample-topic
type: interview-brief
created_at: 2026-05-31
session_id: testsession01
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD1
    statement: "use server-side rendering for the dashboard"
    source_path: b
    steelman: defended
    defense: "client hydration cost measured higher for this data shape"
---

# Sample Topic — Interview Brief (meta-prompt for brainstorming)

## 1. Reframed Problem

The real goal is reducing time-to-first-paint, not "make it a SPA" (ESSENCE).

## 2. Locked Directions

- **LD1**: use server-side rendering for the dashboard.

## 3. External Landscape

- Next.js app-router SSR — https://nextjs.org/docs/app — [취함] — matches data shape

## 4. Skepticism Log

- Alternative: islands architecture could beat full SSR here — https://jasonformat.com/islands-architecture/ — verdict: defended

## 5. Blind Spots & Premortem

- 숨은 가정: SSR host가 항상 저지연 — 왜 위험: cold start 시 TTFP 역전 — https://vercel.com/docs/functions/serverless-functions

## 6. Coverage Ledger

- floor:root_problem — closed — §1 Reframed Problem (ROOT_CAUSE)
- floor:landscape — closed — §3 Next.js SSR 인용
- floor:skepticism — closed — §4 islands steelman defended
- floor:blind_spot — closed — §5 cold-start premortem
- floor:open_questions — closed — §8 caching OQ1
- derived:rendering-strategy — closed — 이 대시보드는 SSR/islands 선택이 핵심; §4 근거

## 7. Tried & Discarded

- Tried full client SPA → discarded: TTFP regression on cold load.

## 8. Open Questions

- OQ1: caching layer for authenticated views — deferred to solution space.

## 9. Concrete Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
```

- [ ] **Step 2: 기존 defect 픽스처 10종을 9-섹션으로 마이그레이션**

아래 각 픽스처는 valid(Step 1)를 base로 하되 **의도한 단일 defect만** 유지한다(나머지는 valid 9-섹션이어야 test가 올바른 이유로 실패). 각 파일을 9-섹션 구조로 갱신:

- `interview-brief-no-landscape.md`: base valid → §3 External Landscape의 URL 제거(uncited entry). §5·§6 valid 유지.
- `interview-brief-unchallenged.md`: base valid → §4 Skepticism Log entry의 URL·verdict 제거(malformed). §5·§6 valid 유지.
- `interview-brief-missing-section.md`: base valid → 임의의 번호 섹션 1개(예: `## 2. Locked Directions`) 삭제. §5·§6 나머지 유지.
- `interview-brief-empty-tried.md`: base valid → §7 Tried & Discarded 비움(entry·N/A 없음). §5·§6 valid 유지.
- `interview-brief-empty-landscape.md`: base valid → §3 External Landscape 비움(header만). §5·§6 valid 유지.
- `interview-brief-fenced-sections.md`: 모든 §헤더를 fenced code block(```) 안에 넣어 authored content 아님을 검증. (기존 의도 유지, 9-섹션으로.)
- `interview-brief-steelman-unlogged.md`: base valid → frontmatter에 `steelman: defended` 항목 추가하되 §4 Skepticism Log는 비움(cross-consistency). §5·§6 valid 유지.
- `interview-brief-bad-frontmatter.md`: base valid → frontmatter `type`/`next_phase`/`locked_directions` 중 하나 깨뜨림. 본문 §1–§9 valid 유지.
- `interview-brief-na-tried.md`: base valid → §7 Tried & Discarded를 `- N/A — 전부 first-time defend+lock`로. §5·§6 valid 유지(게이트 통과 대상).
- `interview-brief-web-disabled.md`: base valid → §4 Skepticism Log entry가 URL 없이 verdict만(web-disabled 시 통과 대상). §5·§6 valid 유지.

주의: 각 파일 수정 후 그 파일의 §6 Coverage Ledger가 floor 5행 all-`closed` + evidence non-empty로 valid해야, 의도한 defect 외의 이유로 gate가 실패하지 않는다(masking 방지).

- [ ] **Step 3: 신규 커버리지 픽스처 6종 작성 (실패 테스트 입력)**

각각 valid(Step 1)를 base로 하되 §6/§5의 단일 defect:

- `interview-brief-floor-open.md`: §6에서 `floor:landscape` 행을 `- floor:landscape — open — §3 인용`으로(status open → gate fail).
- `interview-brief-floor-evidence-empty.md`: §6에서 `floor:skepticism` 행을 `- floor:skepticism — closed — `로(evidence 공백 → gate fail).
- `interview-brief-missing-blind-spot.md`: base valid에서 `## 5. Blind Spots & Premortem` 섹션 전체 삭제(missing section → gate fail). §6 유지(단, 번호 정합상 §6 Coverage Ledger는 그대로 `## 6.`으로 남김 — find_missing_sections가 §5 부재를 잡는다).
- `interview-brief-missing-derived-row.md`: §6에서 `- derived:...` 행 삭제 + N/A sentinel도 없음(derived 부재 → gate fail). floor 5행은 유지.
- `interview-brief-derived-sentinel.md`: §6에서 `- derived:...` 행을 `- derived: N/A — floor로 충분`으로(sentinel → gate pass).
- `interview-brief-web-disabled-blind-spot.md`: §5 Blind Spots 항목이 URL 없이 codebase 근거로(`- 숨은 가정: ... — 근거: state_path.py 라우팅`) + §4도 URL 없는 user-judgment(web-disabled 시 gate pass 대상). §6 valid 유지.

- [ ] **Step 4: test_check_brief.sh에 Coverage/Blind Spots assertion 추가 (실패 테스트)**

`plugins/spec-distill/tests/test_check_brief.sh`의 마지막 `echo` 직전에 아래 블록 추가:
```bash
# --- v0.22.0: Coverage Ledger + Blind Spots 게이트 (AC2/AC3/C9) ---

# valid-with-coverage → gate exit 0 (이미 위에서 valid 통과 확인됨; 명시 재확인)
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" >/dev/null 2>&1 \
  && note PASS "coverage: valid 9-section brief passes gate" \
  || note FAIL "coverage: valid 9-section brief should pass"

# floor status open → fail (AC2)
python3 "$SCRIPT" gate "$FX/interview-brief-floor-open.md" >/dev/null 2>&1 \
  && note FAIL "AC2: floor:open should block termination" \
  || note PASS "AC2: floor status open blocks termination"

# floor evidence empty → fail (AC2)
python3 "$SCRIPT" gate "$FX/interview-brief-floor-evidence-empty.md" >/dev/null 2>&1 \
  && note FAIL "AC2: floor evidence empty should block" \
  || note PASS "AC2: floor evidence empty blocks termination"

# §5 Blind Spots 섹션 부재 → fail (AC3)
python3 "$SCRIPT" gate "$FX/interview-brief-missing-blind-spot.md" >/dev/null 2>&1 \
  && note FAIL "AC3: missing Blind Spots section should block" \
  || note PASS "AC3: missing Blind Spots section blocks termination"

# derived 행·sentinel 둘 다 부재 → fail (C9)
python3 "$SCRIPT" gate "$FX/interview-brief-missing-derived-row.md" >/dev/null 2>&1 \
  && note FAIL "C9: missing derived row + no sentinel should block" \
  || note PASS "C9: missing derived (no sentinel) blocks termination"

# derived N/A sentinel → pass (C9 edge)
python3 "$SCRIPT" gate "$FX/interview-brief-derived-sentinel.md" >/dev/null 2>&1 \
  && note PASS "C9: derived N/A sentinel passes gate" \
  || note FAIL "C9: derived sentinel should pass"

# web-disabled → URL-less §4/§5가 통과 (AC8 대칭)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled-blind-spot.md" >/dev/null 2>&1 \
  && note PASS "AC8: web-disabled brief with URL-less blind spots passes" \
  || note FAIL "AC8: web-disabled gate should accept URL-less blind spots"

# coverage 서브커맨드: floor-open이 실패 리스트를 emit
python3 "$SCRIPT" coverage "$FX/interview-brief-floor-open.md" 2>/dev/null | grep -q 'floor:landscape' \
  && note PASS "coverage subcommand flags floor:landscape not closed" \
  || note FAIL "coverage subcommand should flag the open floor row"
```

- [ ] **Step 5: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL — check_brief.py가 아직 9-섹션·Coverage Ledger를 모름(SECTIONS §5/§6 부재로 valid도 missing-section 실패, coverage 서브커맨드 없음).

- [ ] **Step 6: check_brief.py 구현 — SECTIONS renumber**

Edit `plugins/spec-distill/scripts/check_brief.py` SECTIONS 상수(현재 line 49-57)를 9-섹션으로 교체:
```python
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
```

- [ ] **Step 7: check_brief.py — Tried & Discarded §5 → §7 재지정**

`tried_discarded_ok`(현재 line 153-159)의 `_section_text(text, "5", "Tried & Discarded")`를 `_section_text(text, "7", "Tried & Discarded")`로 교체. 그리고 `gate()`(현재 line 205-208)의 §5 부재 가드를 §7로 재지정:
```python
    # §7 Tried & Discarded 내용은 섹션이 존재할 때만 검사(부재는 이미 miss에 있음).
    sec7_absent = any(m.startswith("7.") for m in miss)
    if not sec7_absent and not tried_discarded_ok(text):
        failures.append("Tried & Discarded empty (no entries and no N/A sentinel)")
```

- [ ] **Step 8: check_brief.py — coverage_ledger_failures 함수 추가**

`tried_discarded_ok` 함수 아래에 추가:
```python
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
```

Note: 구분자 `—`는 U+2014 em-dash(직렬화 문법과 동일). floor 행의 evidence·derived rationale이 내부에 `—`를 포함해도 status는 `(\S+)`가 첫 `closed` 토큰만 잡으므로 안전.

- [ ] **Step 9: check_brief.py — gate()에 coverage 검사 통합 + coverage 서브커맨드**

`gate()`의 `sec7_absent` 블록 다음(ok 계산 전)에 추가:
```python
    # §6 Coverage Ledger 내용은 섹션이 존재할 때만 검사(부재는 이미 miss에 있음).
    sec6_absent = any(m.startswith("6.") for m in miss)
    if not sec6_absent:
        cov = coverage_ledger_failures(text)
        if cov:
            failures.append(f"coverage ledger: {cov}")
```

그리고 `main()`의 서브커맨드 분기(현재 `if sub == "frontmatter":` 위)에 추가:
```python
    if sub == "coverage":
        print(json.dumps({"failures": coverage_ledger_failures(text)}, ensure_ascii=False))
        return 0
```

또한 모듈 docstring의 CLI 목록(현재 line 17-24)에 `check_brief.py coverage <brief> → {"failures": [...]} (AC2/C9)` 한 줄 추가.

- [ ] **Step 10: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: PASS — 기존 assertion + 신규 coverage/Blind Spots assertion 전부 green (`Fail: 0`).

- [ ] **Step 11: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_check_brief.sh plugins/spec-distill/tests/fixtures/interview-brief-*.md
git commit -m "feat(spec-distill): check_brief 9-section + Coverage Ledger + Blind Spots gate (AC2/AC3/C9)"
```

---

## Task 7: SKILL.md — 상태 스키마 교체 + in-flight 마이그레이션

`conducting-interview/SKILL.md` 상태 frontmatter에서 `interview_round`를 제거하고 `coverage`(floor 5 + derived[]) + `probe_count` + `probe_cap_override` + `orchestration`을 추가(AC1/C9). `## In-flight state migration` 섹션을 AC5로 재작성(구세션 감지 → fresh seed). 기존 필드는 전부 유지(AC1 non-exhaustive).

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (state 스키마 블록 line 30-42; migration 섹션 line 310-324)
- Create: `plugins/spec-distill/tests/fixtures/state-legacy-interview-round.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (schema·migration assertion 추가)

**Interfaces:**
- Produces: state 스키마 필드 `coverage.floor.<key>.{status,evidence}`, `coverage.derived[]`, `orchestration.{focused_dimension,no_progress_streak,blind_spot_dispatched,coverage_mapper_last_probe}`, `probe_count`, `probe_cap_override` — Task 8/9가 읽고 쓴다.

- [ ] **Step 1: 레거시 마이그레이션 픽스처 작성**

Create `plugins/spec-distill/tests/fixtures/state-legacy-interview-round.md` (V4/V7b 예외 경로 — interview_round 포함):
```markdown
---
session_id: legacy-session-01
phase: 1
interview_round: 5
non_user_streak: 1
web_sweep_count: 2
web_search_count: 3
rereview_count: 0
trivia_escape_armed: false
issue_history: []
pending_locked_decisions: []
---
legacy body — v0.21.x schema (coverage 부재, interview_round 존재)
```

- [ ] **Step 2: stage 테스트에 schema·migration assertion 추가 (실패 테스트)**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh`의 마지막 `echo` 직전에 추가:
```bash
# --- v0.22.0: 커버리지 상태 스키마 + 마이그레이션 (AC1/AC5) ---
has 'coverage:' "AC1: coverage ledger in state schema"
has 'probe_count' "AC1: probe_count counter in state schema"
has 'probe_cap_override' "AC1: probe_cap_override in state schema"
has 'no_progress_streak' "AC1: orchestration.no_progress_streak in schema"
has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema"
has 'coverage_mapper_last_probe' "AC1: orchestration.coverage_mapper_last_probe in schema"
# AC1: 기존 필드 보존
has 'non_user_streak' "AC1: non_user_streak retained"
has 'pending_locked_decisions' "AC1: pending_locked_decisions retained"
# AC5: 마이그레이션 — 구세션 감지 + fresh seed + advisory
has 'coverage.*부재|coverage 부재|interview_round.*존재' "AC5: legacy detection (interview_round present / coverage absent)"
has 'state schema migration.*coverage|coverage/probe_count added' "AC5: migration advisory wording"
has 'probe_count.*0|probe_count=0' "AC5: probe_count seeded fresh (not from interview_round)"

# state 스키마 블록(첫 yaml)에서 interview_round가 능동 필드로 남지 않았는지 (V7b)
# — 마이그레이션 섹션의 언급은 허용, 스키마 선언은 금지.
schema_block="$(awk '/^State frontmatter schema:/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' "$SKILL")"
grep -q 'interview_round' <<<"$schema_block" \
  && note FAIL "V7b: interview_round still an active schema field" \
  || note PASS "V7b: interview_round removed from active state schema"
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL — SKILL에 coverage/probe_count 등이 아직 없음.

- [ ] **Step 4: 상태 스키마 블록 교체**

SKILL.md의 State frontmatter schema 블록(line 30-42의 ```yaml ... ```)을 아래로 교체 — `interview_round` 삭제, 신규 필드 추가, 기존 필드 유지:
```yaml
---
session_id: <uuid>
phase: 1
coverage:                            # G1 커버리지 원장 (floor 5 + derived[]). 종료 driver.
  floor:
    root_problem:   {status: open, evidence: ""}
    landscape:      {status: open, evidence: ""}
    skepticism:     {status: open, evidence: ""}
    blind_spot:     {status: open, evidence: ""}
    open_questions: {status: open, evidence: ""}
  derived: []                        # 주제-도출 차원 (coverage-mapper 제안 → orchestrator admit; {name, rationale, status, evidence})
orchestration:                       # C11/C8 across-resumption 상태 (orchestrator 소유, agent read-only)
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  no_progress_streak: 0              # C11 연속 무진전 probe 수; focused 변경·진전 시 0 reset
  blind_spot_dispatched: false       # C8 인터뷰당 1회 보장; 첫 dispatch 시 true
  coverage_mapper_last_probe: null   # 마지막 coverage-mapper dispatch 시 probe_count (C11 rate-limit)
probe_count: 0                       # C10 probe 백스톱 카운터 (probe 제기 *후* +1)
probe_cap_override: 0                # C1 '계속'이 base cap(12)만큼 raise
non_user_streak: <int>
web_sweep_count: 0                   # 현재 sweep 내 web 검색 호출 수 (AP9, ≤4). sweep 종료 시 0으로 reset.
web_search_count: 0                  # 세션 누적 web 검색 호출 수 (AP16, ≤8 soft cap).
rereview_count: 0
trivia_escape_armed: false
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
pending_locked_decisions: []         # 매 round 끝 append (b/d path 명시 응답만). brief frontmatter locked_directions로 변환.
---
```

또한 line 44의 `State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) breadth-keeper 출력 transcript.`에서 `breadth-keeper` → `coverage-mapper`로 교체(용어 정합).

- [ ] **Step 5: In-flight state migration 섹션 재작성 (AC5)**

SKILL.md의 `## In-flight state migration (C10)` 섹션(line 310-324) 전체를 아래로 교체:
```markdown
## In-flight state migration (AC5)

state.local.md 로드 시 **구세션 스키마**(`interview_round` 존재 / `coverage` 부재)를 감지하면
*non-mutating read*로 fresh 초기화(승격):

- `coverage.floor`의 5개 차원(root_problem/landscape/skepticism/blind_spot/open_questions) 전부
  `{status: open, evidence: ""}`로 seed.
- `coverage.derived`: `[]`.
- `probe_count`: **0** (interview_round 값 승계 금지 — 라운드 수는 probe 수가 아니다).
- `probe_cap_override`: `0`.
- `orchestration`: `{focused_dimension: null, no_progress_streak: 0, blind_spot_dispatched: false, coverage_mapper_last_probe: null}`.

기존 필드(`non_user_streak`·`web_*`·`issue_history`·`pending_locked_decisions` 등)는 유지.
다음 명시적 state write 시점에만 frontmatter에 신규 필드를 추가(backward-rewrite 금지 —
`interview_round` 필드는 그 write에서 자연 소멸하되, 그 전까지 파일 내용을 되쓰지 않는다).

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.22.0] state schema migration: coverage/probe_count added (interview_round retired).
```

자동 promote 실패 시(파일 corruption 등) → "구세션 in-flight state 호환 실패 — 세션 재시작 권장"
알림 + state.local.md 보존 (P14).
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: schema·migration·V7b assertion PASS. (다른 기존 assertion 중 커버리지 루프 관련은 Task 8/9에서 추가되므로, 이 시점에 stage 테스트가 완전 green이 아닐 수 있음 — Step 2에서 추가한 assertion만 green이면 진행.)

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/tests/fixtures/state-legacy-interview-round.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): SKILL coverage state schema + AC5 migration (AC1/AC5)"
```

---

## Task 8: SKILL.md — 커버리지 루프 + 종료 게이트 + probe 백스톱 + escalation

종료 driver를 "5 통과 의례 all pass"에서 "floor 5차원 all closed"로 전환(G1/AC2). probe 조립 전 `probe_budget.py check`(gate), 제기 후 `increment`; cap 도달 & floor 미충족 시 C1 3옵션 escalation. Step A brief 작성 시 `## Coverage Ledger` 직렬화(C9).

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (종료 섹션 line 203-225 + probe 백스톱 신규 섹션)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: `probe_budget.py check/increment/raise-cap` (Task 2), `check_brief.py gate` + `## Coverage Ledger` 문법 (Task 6), state `coverage`/`probe_count` (Task 7).

- [ ] **Step 1: stage 테스트에 커버리지 루프·백스톱 assertion 추가 (실패 테스트)**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh`의 마지막 `echo` 직전에 추가:
```bash
# --- v0.22.0: 커버리지 종료 루프 + probe 백스톱 (G1/AC2/AC4/C1/C10) ---
has 'probe_budget\.py' "AC4: probe backstop calls probe_budget.py"
has 'probe_budget\.py"? check' "C10: check gate before posing a probe"
has 'probe_budget\.py"? increment' "C10: increment after posing a probe"
has 'probe_budget\.py"? raise-cap' "C1: raise-cap on '계속' escalation"
has 'floor.*(closed|전부.*closed|모두.*closed)' "G1/AC2: termination = floor all closed"
has 'Coverage Ledger' "AC2/C9: brief Coverage Ledger serialization"
has 'AskUserQuestion' "AC4: cap escalation uses AskUserQuestion"
has '박제|abort|계속' "C1: 3-option escalation semantics"
has '9-section|9-섹션|9 섹션' "AC10: Step A references 9-section template"
# 종료 로직에 interview_round 잔존 0 (AC9/V7b)
term_block="$(awk '/^## 종료/{f=1} f&&/^## [^종]/{exit} f' "$SKILL")"
grep -q 'interview_round' <<<"$term_block" \
  && note FAIL "AC9/V7b: interview_round in termination block" \
  || note PASS "AC9/V7b: no interview_round in termination logic"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL — probe_budget 호출·floor closed 종료·escalation 프로즈 부재.

- [ ] **Step 3: probe 백스톱 프로토콜 섹션 신규 추가**

SKILL.md의 `## C44 Dialectic Rhythm Guard` 섹션 다음에 신규 섹션 삽입:
```markdown
## probe 백스톱 (C1/C10 — Unbounded-autonomy 가드)

floor 미충족이면 종료가 막히므로 probe가 무한히 돌 수 있다. `probe_budget.py`가 이를 기계적으로
bound한다(프로즈 self-tracking 금지). **원자성**: probe(= (b)/(d)-path 질문 1회)를 조립하기
*전에* `check`(gate)를 호출하고, 질문을 실제로 제기한 *후에만* `increment`한다.

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# 1) probe 조립 전 gate
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/probe_budget.py" check "$STATE"; then
  : # probe_count >= effective_cap — floor 미충족이면 아래 C1 escalation, 질문 미제기(increment 안 함)
fi
# 2) 질문 실제 제기 후에만
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/probe_budget.py" increment "$STATE"
```

`check`가 non-zero(`probe_count ≥ effective_cap`) & floor 미충족이면 **C1 escalation**을 발화한다
(`AskUserQuestion`, 3옵션):

- **① 계속**: `probe_budget.py raise-cap "$STATE"` — `probe_cap_override`를 base cap(12)만큼 올려
  `effective_cap = base + override`로 상향(persist) 후 진행.
- **② 박제 후 종료**: 미충족 floor 행을 `status: closed` + evidence `사용자-승인 박제(@probe N) —
  §Open Questions 참조`로 기록하고 그 내용을 brief §8 Open Questions로 이동 → AC2 게이트 통과(floor
  closed)하되 박제 표식이 원장에 가시적(silent bypass 아님).
- **③ abort**: brief 미작성, state 보존.

`increment`는 질문 제기 후에만 호출돼 phantom 증가가 없다(gate에서 막힌 probe는 카운트 안 됨).
`increment`는 gate하지 않는다 — gating은 오직 `check`(C10 원자성).

kill switch: `DEVBREW_SPEC_DISTILL_PROBE_CAP=N` 으로 base cap override.
```

- [ ] **Step 4: 종료 섹션을 커버리지 루프로 재작성**

SKILL.md의 `## 종료 — brief 작성 + optional handoff` 섹션(line 203-211)의 종료 기준을 아래로 교체:
```markdown
## 종료 — brief 작성 + optional handoff

종료 driver는 **커버리지 원장의 floor 5차원이 전부 `closed`** 인 것이다(고정 라운드 수 아님, G1).
다음을 모두 만족하면 brief를 작성한다:

- floor `root_problem` closed — 진짜 problem이 한 문장으로 재구성(R1 계열).
- floor `landscape` closed — landscape가 인용과 함께 수집(R2 계열, web sweep 메커니즘 유지).
- floor `skepticism` closed — 의심 방향이 steelman 통과(R3 계열, steelman-builder 게이트 유지).
- floor `blind_spot` closed — blind-spot-prober가 unknown-unknown을 표면화하고 §5에 기록.
- floor `open_questions` closed — 미해결 명시(박제, "유추 금지").

각 차원의 status 전이(open→in-progress→closed)와 evidence 기록은 **orchestrator만** 수행하며
(coverage-mapper·blind-spot-prober는 read-only 제안자, Law 2), state.local.md에 쓰는 동시에
brief §6 `## Coverage Ledger`에 직렬화한다.
```

그리고 `### Step A — brief 작성` 섹션(line 213-225):
- line 215 `7-section 구조 확보` → `9-section 구조 확보(§5 Blind Spots & Premortem, §6 Coverage Ledger 포함)`.
- Step A에 원장 직렬화 단계 추가(check_brief 호출 *전*):
```markdown
   - **Coverage Ledger 직렬화**: state.local.md의 `coverage`를 brief §6 `## Coverage Ledger`에
     한 줄당 한 차원으로 직렬화(floor 5행 + derived; 문법은 §Coverage Ledger 참조). floor 전부
     `closed`가 아니면 이 시점에 도달하면 안 된다(종료 driver 위반).
```
- check_brief 게이트 설명(line 220-225)은 유지하되, 실패 사유에 `floor open/evidence 공백/Blind Spots 부재`를 추가 언급.

- [ ] **Step 5: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: Step 1 추가 assertion PASS. (teach-beat·blind-spot dispatch 관련 assertion은 Task 9에서 추가.)

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): coverage-driven termination + probe backstop + C1 escalation (G1/AC2/AC4/C1)"
```

---

## Task 9: SKILL.md — teach-beat + blind-spot dispatch + coverage-mapper 트리거 + rhythm 재프레임

행동 beat들: teach-beat(AC8/C3/C12), blind-spot-prober dispatch(AC6), `## breadth-keeper dispatch (C45)` → `## coverage-mapper dispatch (C11)` 트리거 교체(AC7/C11), rhythm-guard probe 재프레임(AC9). SKILL 본문 잔여 breadth-keeper 용어 정리.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (breadth-keeper dispatch 섹션 line 130-138; R3 line 177; teach-beat 신규; blind-spot dispatch 신규)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: `coverage-mapper`·`blind-spot-prober` subagent_type (Task 3/4), state `orchestration.{no_progress_streak,blind_spot_dispatched,coverage_mapper_last_probe}` (Task 7).

- [ ] **Step 1: stage 테스트에 teach-beat·dispatch assertion 추가 (실패 테스트)**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh`의 마지막 `echo` 직전에 추가:
```bash
# --- v0.22.0: teach-beat + blind-spot/coverage-mapper dispatch (AC6/AC7/AC8/AC9/C11/C12) ---
has 'teach-lite|teach-beat' "AC8: teach-beat present"
has 'teach-lite.*≤1|≤1문장|한 문장' "AC8: teach-lite size bound (<=1 sentence)"
has 'teach-heavy.*URL|≥1.*URL|prior-art.*URL' "AC8: teach-heavy needs >=1 URL"
has '단정.*금지|질문 형태' "C3: teach as question, not assertion"
has 'blind-spot-prober' "AC6: blind-spot-prober dispatch"
has 'blind_spot.*open→in-progress|첫 open→in-progress' "AC6: dispatch on blind_spot first transition"
has 'coverage-mapper' "AC7: coverage-mapper dispatch"
has 'no_progress|무진전|연속 3 probe' "C11: coverage-mapper trigger (3 no-progress probes)"
has 'coverage_mapper_last_probe' "C11: redispatch bound via last_probe"

# C45 interview_round>=2 트리거가 제거됐는지 (AC7)
grep -q 'interview_round >= 2\|interview_round>=2' "$SKILL" \
  && note FAIL "AC7: C45 interview_round>=2 trigger still present" \
  || note PASS "AC7: interview_round>=2 dispatch trigger replaced by C11"

# breadth-keeper 용어 잔존 0 (SKILL 본문, AC7/V7a)
grep -qi 'breadth-keeper\|breadth_keeper' "$SKILL" \
  && note FAIL "V7a: breadth-keeper term remains in SKILL" \
  || note PASS "V7a: breadth-keeper term removed from SKILL"
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL — teach-beat·blind-spot dispatch·coverage-mapper 트리거 부재, breadth-keeper 잔존.

- [ ] **Step 3: teach-beat 섹션 신규 추가**

SKILL.md의 `## C43 4-path routing` 섹션 다음에 신규 섹션 삽입:
```markdown
## teach-beat (AC8/C3/C12 — 미지를 드러내 가르치기)

매 probe에 **teach-lite**를 붙인다: prior-art/trade-off를 **≤1문장**, **web 호출 없이**, 그리고
**단정이 아닌 질문 형태**로 제시해 사용자가 모르는 지형을 살짝 연다(C3 — 공유된 전제가 사용자 답을
오염시키지 않게).

다음 **열거 신호** 중 하나가 발화하면 그 probe의 teach-lite를 **teach-heavy**로 *대체*한다
(추가 아님 — probe당 teach-beat 최대 1회). teach-heavy = **≥1 prior-art/URL 또는 landscape 인용**:

1. 사용자 답이 `## External Landscape` 한 항목과 모순.
2. hold·satisficing 답("모르겠음/둘 다/아무거나" — locked-판정 트리의 "보류" 분기 재사용).
3. floor 차원의 첫 open→in-progress 전이(그 차원에 첫 probe 착수).
4. coverage-mapper/blind-spot-prober 출력이 비어있지 않음.

복수 신호 동시 발화 시 heavy beat 1회로 합친다. **발화 시점은 모델 판단 적응 행동**이다(C12 —
결정론 게이트로 기계화하지 않는다; 위 신호는 결정 규칙이 아니라 휴리스틱 가이드). 검증 가능한 것은
이 신호 목록 + 크기 한도(teach-lite ≤1문장 / teach-heavy ≥1 URL)뿐이며, 각 발화의 per-firing
결정성은 non-goal(모델 판단을 결정론으로 대체하지 않음 — 이 재구성의 핵심 논지).
```

- [ ] **Step 4: breadth-keeper dispatch → coverage-mapper dispatch 트리거 교체**

SKILL.md의 `## breadth-keeper dispatch (C45, AC13)` 섹션(line 130-138) 전체를 아래로 교체:
```markdown
## coverage-mapper dispatch (C11, AC7)

`coverage-mapper`는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(원장 admit
판정은 orchestrator, G2). 다음 조건 중 하나에서 dispatch:

1. 한 focused 차원이 **연속 3 probe** 동안 status·evidence 무변경(진전 없음), OR
2. floor 차원의 **첫 open→in-progress 전이**.

진전 = status 전이(open→in-progress→closed) 또는 evidence append. `orchestration.no_progress_streak`는
focused 차원이 바뀌거나 진전 발생 시 0으로 reset.

**redispatch 바운드(Unbounded-autonomy 가드)**: dispatch 시 `orchestration.coverage_mapper_last_probe =
probe_count` 기록. 재dispatch는 `probe_count - coverage_mapper_last_probe >= 3`일 때만 허용(무진전이
지속돼도 최소 3 probe 간격 — 레벨-트리거 무한 재dispatch 방지). `coverage_mapper_last_probe == null`이면
첫 dispatch 허용.

```
Agent({ description: "Map coverage dimensions", subagent_type: "spec-distill:coverage-mapper",
        prompt: "열린/닫힌 차원 요약: <...>. focused_dimension: <...>, no_progress_streak: <N>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
```

출력(`derived_dimensions[] + neglect_flag`)은 **advisory** — orchestrator가 원장에 admit할지 판정한다.
`neglect_flag: true`면 다음 probe에서 neglected 차원 하나를 추천 답안으로 제시. 복수 dispatch 시
name 기준 union·dedup.
```

- [ ] **Step 5: blind-spot-prober dispatch 섹션 신규 추가**

Step 4에서 교체한 coverage-mapper dispatch 섹션 다음에 신규 섹션 삽입:
```markdown
## blind-spot-prober dispatch (AC6, C8 — blind_spot floor 차원)

`blind_spot` floor 차원의 **첫 open→in-progress 전이**(그 차원에 첫 probe 착수) 시 `blind-spot-prober`를
**인터뷰당 1회** dispatch한다(fan-out 1, C8). `orchestration.blind_spot_dispatched`가 false일 때만
dispatch하고, dispatch 후 true로 세팅(재dispatch 금지).

```
Agent({ description: "Adversarial premortem", subagent_type: "spec-distill:blind-spot-prober",
        prompt: "재구성된 문제정의: <...>. locked_directions: <...>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
```

출력(`hidden_assumptions[] + failure_modes[]`)을 orchestrator가 brief §5 `## Blind Spots & Premortem`에
기록하고, `blind_spot` floor 차원을 in-progress→closed로 전이(사용자에게 표면화된 blind-spot 확인 후).

**Web 부재 시 graceful degradation (C5)**: kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web
도구 부재로 blind-spot-prober를 돌릴 수 없으면 — R2/R3 web-absent 강등과 대칭으로 — opaque gate-fail로
떨어뜨리지 말고 **loud advisory** 후 **inline premortem**으로 전환:
`[spec-distill] web 비활성 — blind-spot-prober 자동 생략, inline premortem으로 전환`. 이 경우 §5는
codebase 근거 또는 사용자 판단으로 기록(URL 부재 사유 명시).
```

- [ ] **Step 6: R3 트리거 용어 + rhythm-guard 재프레임**

- SKILL.md line 177 `의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 LD 불일치 / breadth-keeper tunneling.`에서 `breadth-keeper tunneling` → `coverage-mapper neglect`.
- `## C44 Dialectic Rhythm Guard` 섹션(line 116-128): `non_user_streak`을 **probe 기준**으로 재프레임. "직전 N round" → "직전 N probe"; 종료-scoped round 언급 제거. 빈도-scoped 표현("round당 max 1" 류)이 남아있다면 교체 대상 아님(AC9 — 빈도 언급 유지 허용). streak threshold(default 3, `DEVBREW_RHYTHM_GUARD_THRESHOLD`) 유지.

- [ ] **Step 7: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: PASS — 전체 stage 테스트 green (`Fail: 0`). 기존 R1-R5·web_budget·steelman·AskUserQuestion Step B assertion도 유지 green인지 확인(R2 Landscape/R3 Skepticism 메커니즘은 floor로 살아있음).

- [ ] **Step 8: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): teach-beat + blind-spot/coverage-mapper dispatch + rhythm reframe (AC6/AC7/AC8/AC9/C11)"
```

---

## Task 10: 메타데이터 동기화 + README + stale-term 회귀 락

`plugin.json` 0.22.0 + `CHANGELOG [0.22.0]` + README(Agents/Hooks/Principles) 동기화(C7/AC11). `test_readme_sync.sh`를 0.22.x + 신규 키워드로 갱신. V7 stale-term 회귀 락(`test_stale_terms.sh`) 신설 — 모든 rename task의 teeth.

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh`
- Create: `plugins/spec-distill/tests/test_stale_terms.sh`

- [ ] **Step 1: stale-term 회귀 락 작성 (실패 테스트)**

Create `plugins/spec-distill/tests/test_stale_terms.sh`:
```bash
#!/usr/bin/env bash
# V7 — stale-term 회귀 락. (a) breadth-keeper는 릴리스된 CHANGELOG 외 전부 coverage-mapper로
# 재명명. (b) interview_round는 SKILL 마이그레이션 블록 + 레거시 픽스처에만 존재.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# V7a: breadth-keeper 제거 (릴리스 CHANGELOG + mocks 제외)
hits="$(grep -rn 'breadth-keeper\|breadth_keeper\|Breadth-Keeper' "$SD" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.json' \
  | grep -v '/CHANGELOG.md:' | grep -v '/tests/mocks/' || true)"
[[ -z "$hits" ]] \
  && note PASS "V7a: no breadth-keeper outside released CHANGELOG" \
  || { note FAIL "V7a: stale breadth-keeper references:"; printf '%s\n' "$hits"; }

# V7b-1: SKILL.md의 interview_round는 In-flight migration 섹션에만.
mig="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
all_ir=$(grep -c 'interview_round' "$SKILL" || true)
mig_ir=$(printf '%s\n' "$mig" | grep -c 'interview_round' || true)
{ [[ "$all_ir" -ge 1 ]] && [[ "$all_ir" -eq "$mig_ir" ]]; } \
  && note PASS "V7b: interview_round in SKILL confined to migration section ($all_ir)" \
  || note FAIL "V7b: interview_round leaks outside SKILL migration (total=$all_ir mig=$mig_ir)"

# V7b-2: interview_round는 SKILL + 레거시 픽스처 외 어떤 파일에도 없음.
other="$(grep -rln 'interview_round' "$SD" \
  --include='*.md' --include='*.sh' --include='*.py' --include='*.json' \
  | grep -v '/skills/conducting-interview/SKILL.md$' \
  | grep -v '/tests/fixtures/state-legacy-interview-round.md$' || true)"
[[ -z "$other" ]] \
  && note PASS "V7b: no interview_round outside SKILL migration + legacy fixture" \
  || { note FAIL "V7b: interview_round in unexpected files:"; printf '%s\n' "$other"; }

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_stale_terms.sh`
Expected: FAIL — README에 breadth-keeper 잔존(line 59/84/92).

- [ ] **Step 3: README breadth-keeper → coverage-mapper + blind-spot-prober 추가**

Edit `plugins/spec-distill/README.md`:
- line 59: `spec-reviewer + breadth-keeper agent의 *물리적* 분리` → `spec-reviewer + coverage-mapper + blind-spot-prober agent의 *물리적* 분리`.
- line 84: `- **C45** breadth-keeper agent (...)` → `- **C11** coverage-mapper agent (`tools: Read, Grep, Glob` — advisory 주제-도출 차원 제안자) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem, fan-out 1).`
- line 92: `AP9 (Subagent spray) — agent 2개, breadth-keeper round당 max 1 invoke.` → `AP9 (Subagent spray) — agent 4종(spec-reviewer/steelman-builder/coverage-mapper/blind-spot-prober), coverage-mapper C11 rate-limit + blind-spot-prober fan-out 1.`
- Principles Instantiated 또는 관련 절에 probe 백스톱 한 줄 추가: `- **C10** probe_budget.py 백스톱 — Unbounded-autonomy 가드(effective_cap = base 12 + override, DEVBREW_SPEC_DISTILL_PROBE_CAP).`
- Flow 절 헤더 `## Flow (v0.15.0)` → `## Flow (v0.22.0)`이 맞으면 갱신(커버리지-구동 언급 한 줄 추가 권장이나 필수 아님).

- [ ] **Step 4: plugin.json + CHANGELOG 버전 bump**

Edit `plugins/spec-distill/.claude-plugin/plugin.json`: `"version": "0.21.0"` → `"version": "0.22.0"`.

Edit `plugins/spec-distill/CHANGELOG.md` — `# Changelog` 다음에 신규 엔트리 삽입:
```markdown
## [0.22.0] — 2026-07-21

### Added
- **커버리지-구동 인터뷰 재구성** — 종료 driver를 고정 `interview_round` 카운터에서 미지-차원
  커버리지 원장(고정 floor 5 + 주제-도출 차원, 각 status ∈ {open, in-progress, closed})으로 교체.
  집요함·깊이·차원이 주제에 적응한다(길이 아님).
- `scripts/probe_budget.py` — Unbounded-autonomy 백스톱(check/increment/raise-cap; base_cap 12 +
  probe_cap_override; env `DEVBREW_SPEC_DISTILL_PROBE_CAP`). `web_budget.py` sibling, mutation-testable.
- `agents/blind-spot-prober.md` — blind_spot floor 차원을 구현하는 적대적 premortem 에이전트
  (read-only, fan-out 1, hidden_assumptions/failure_modes 출력).
- brief 템플릿 §5 Blind Spots & Premortem + §6 Coverage Ledger 신규 섹션. `check_brief.py`가 원장 form
  (floor all-closed + evidence non-empty + derived)을 게이트.
- teach-beat — 모든 probe teach-lite(≤1문장) + 열거 신호 시 evidence-heavy(≥1 URL). 발화 시점은
  model-judged(C12, 결정론 미기계화).

### Changed
- `agents/breadth-keeper.md` → `agents/coverage-mapper.md` 재명명·재목적화 — tunneling 검출에서
  주제-도출 차원 advisory 제안자로 승격(원장 admit 판정은 orchestrator, Law 2). `coverage-mapper`
  dispatch 트리거를 `interview_round >= 2`에서 C11 커버리지 조건(연속 3 probe 무진전 OR floor 첫
  open→in-progress) + redispatch 바운드로 교체.
- `skills/conducting-interview/SKILL.md` — 상태 스키마(interview_round 제거, coverage/probe_count/
  probe_cap_override/orchestration 추가), 종료 게이트(floor all-closed), probe 백스톱 호출, rhythm-guard
  probe 재프레임, in-flight 마이그레이션(구세션 fresh seed).
- `agents/steelman-builder.md` — description 용어 'breadth-keeper' → 'coverage-mapper'(terminology-only).

### Security
- 신규/변경 에이전트(coverage-mapper·blind-spot-prober)는 `tools:` allowlist fail-closed(Write/Edit 물리
  부재) — Law 2 read-only 불변. probe 백스톱은 기계적 집행(프로즈 self-tracking 아님).
```

- [ ] **Step 5: test_readme_sync.sh 갱신 (실패 테스트 → 통과)**

Edit `plugins/spec-distill/tests/test_readme_sync.sh`:
- line 17 version assert: `'"version": "0\.21\.[0-9]+"'` → `'"version": "0\.22\.[0-9]+"'`, 실패 메시지도 0.22.x로.
- CHANGELOG 엔트리 assert 추가(기존 [0.20.0] 유지 + [0.22.0] 추가):
```bash
grep -qE '^## \[0\.22\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.22.0] entry with ISO date" || note FAIL "AC11: CHANGELOG [0.22.0] missing/!ISO"
```
- README 키워드 루프(line 24)에 신규 키워드 추가: `'coverage-mapper' 'blind-spot-prober' 'probe_budget'`. (기존 `'steelman-builder'` 등 유지.)

- [ ] **Step 6: 테스트 통과 확인**

Run:
```bash
bash plugins/spec-distill/tests/test_stale_terms.sh && bash plugins/spec-distill/tests/test_readme_sync.sh
```
Expected: 둘 다 PASS (`Fail: 0`).

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh plugins/spec-distill/tests/test_stale_terms.sh
git commit -m "chore(spec-distill): v0.22.0 metadata + README + stale-term regression lock (C7/AC11/V7)"
```

---

## Task 11: 전체 스위트 회귀 + 수동 e2e 체크리스트

전체 테스트 스위트를 baseline(Task 1) 대비 회귀 0으로 확인(V1)하고, 수동 e2e(V9)를 위한 체크리스트를 사용자에게 제시한다.

**Files:**
- (없음 — 검증 전용)

- [ ] **Step 1: Bash 스위트 전체 실행**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill
for t in tests/*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done | tee /tmp/spec-distill-after-sh.txt
diff <(sort /tmp/spec-distill-baseline-sh.txt) <(sort /tmp/spec-distill-after-sh.txt)
```
Expected: 신규 테스트(test_probe_budget/test_coverage_mapper_frontmatter/test_blind_spot_prober_frontmatter/test_stale_terms)는 PASS로 추가. baseline에서 PASS였던 항목이 FAIL로 바뀐 것 **0건**. (test_breadth_keeper_frontmatter.sh는 rename으로 사라지고 test_coverage_mapper_frontmatter.sh로 대체 — diff에서 이 pairing 확인.)

- [ ] **Step 2: Python 스위트 전체 실행**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill
python3 -m unittest discover -s tests -p 'test_*.py' -v 2>&1 | tail -15
```
Expected: baseline(Task 1 Step 2) 대비 회귀 0.

- [ ] **Step 3: 회귀 판정**

baseline 대비 새로운 FAIL이 있으면 해당 task로 돌아가 수정. FAIL이 pre-existing(baseline에도 있던 것)이면 이 작업 범위 밖 — 기록만 하고 진행. 회귀 0 확인 시 다음 단계.

- [ ] **Step 4: 수동 e2e 체크리스트 제시 (V9 — 사용자 실행)**

아래를 사용자에게 제시(모델이 대신 실행 불가 — 실제 인터뷰 세션 필요):
```
수동 e2e (V9) — 실제 토픽으로 /spec-distill:interview 1회:
1. 원장이 floor(root_problem/landscape/skepticism/blind_spot/open_questions)를 하나씩 closed로 닫아가는가.
2. 종료 시 brief §6 Coverage Ledger에 floor 5행이 closed로 직렬화되는가.
3. blind-spot-prober가 unknown-unknown(hidden assumption / failure mode)을 §5에 표면화하는가.
4. teach-beat가 신호(landscape 모순/hold 답/floor 첫 개방/subagent 출력)에서만 heavy로 발화하는가.
5. probe_count가 cap(12) 초과 시 3옵션 escalation(계속/박제/abort)이 뜨는가.
6. 구세션(interview_round 상태) 로드 시 마이그레이션 advisory가 뜨고 probe_count=0으로 seed되는가.
```

- [ ] **Step 5: 최종 상태 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && git log --oneline feature/interview-coverage-driven -12 && git status`
Expected: Task 2-10의 커밋 8개 + design/brief 커밋. working tree clean. 브랜치 `feature/interview-coverage-driven`, 미푸시.

---

## Self-Review

플랜 작성 후 spec 대비 fresh-eyes 점검(체크리스트 — subagent dispatch 아님).

**1. Spec coverage** — 각 AC/C/V가 task에 매핑되는가:
- AC1(스키마) → Task 7. AC2(종료 게이트) → Task 6+8. AC3(check_brief) → Task 6. AC4(probe check) → Task 2+8. AC5(마이그레이션) → Task 7. AC6(blind-spot-prober) → Task 4+9. AC7(coverage-mapper) → Task 3+9. AC8(teach-beat) → Task 9. AC9(rhythm reframe) → Task 9. AC10(템플릿) → Task 5. AC11(메타데이터) → Task 10. AC12(probe mutation) → Task 2.
- C1(escalation) → Task 8. C2(form-only) → Task 6. C3(teach 질문) → Task 9. C4(마이그레이션) → Task 7. C5(web 강등) → Task 9(blind-spot). C6(Law 2) → Task 3+4. C7(버전) → Task 10. C8(fan-out 1) → Task 4+9. C9(원장 스키마) → Task 6+7+8. C10(백스톱) → Task 2. C11(coverage-mapper 트리거) → Task 9. C12(model-judged) → Task 9.
- V1 → Task 1+11. V2 → Task 6. V3 → Task 3+4. V4 → Task 7. V5 → Task 2. V6 → Task 10. V7 → Task 10. V8(design 리뷰) → 이미 완료(설계 5라운드). V9 → Task 11.
- 갭 없음. (V8은 design-phase 검증으로 구현 범위 밖.)

**2. Placeholder scan** — "TBD/적절히/필요시" 류 없음. 모든 코드 step은 완전한 Python/Bash/Markdown 블록. 프로즈(SKILL) step은 정확한 교체 블록 또는 line-targeted 편집 + grep assertion으로 검증.

**3. Type consistency** — probe_budget.py 서브커맨드(check/increment/raise-cap)가 SKILL Task 8 호출과 일치. Coverage Ledger 행 문법(`floor:KEY — closed — evidence`)이 템플릿(Task 5)·check_brief 파서(Task 6)·SKILL 직렬화(Task 8)에서 동일. floor 키(root_problem/landscape/skepticism/blind_spot/open_questions)가 스키마(Task 7)·check_brief FLOOR_KEYS(Task 6)·종료 섹션(Task 8)에서 동일. agent subagent_type(`spec-distill:coverage-mapper`/`spec-distill:blind-spot-prober`)이 dispatch(Task 9)와 일치.

**주의(구현자 향)**: SKILL.md는 프로즈라 line 번호가 앞 task 편집으로 이동한다 — 각 편집 전 앵커 문자열(섹션 헤더)로 위치를 재확인할 것. 기존 stage 테스트의 R1-R5·web_budget·steelman assertion은 floor 메커니즘으로 살아있으므로 삭제하지 말 것(R2 Landscape/R3 Skepticism은 floor로 존속).
