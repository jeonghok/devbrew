# Interview Direction-Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-position spec-distill's `/interview` from a spec generator into a strong problem-space stage (Double Diamond 1st diamond) that produces a self-complete `interview-brief` meta-prompt — adding meta-prompting, embedded web research, adversarial steelman skepticism, and trial-and-error pre-resolution — while preserving Law 2 design-doc review by removing `drafting-spec` entirely and simplifying `reviewing-spec` to design-mode only.

**Architecture:** The interview remains an LLM-prose-driven skill (`conducting-interview/SKILL.md`). Its new mechanical guarantees are extracted into two stdlib-only Python validators that the skill invokes and the tests unit-test directly: `scripts/web_budget.py` (per-sweep ≤4 / per-session ≤8 web-search bounds via state-file counters) and `scripts/check_brief.py` (the 5 통과 의례 termination gate — 7 sections, landscape citations, steelman log well-formedness, tried-&-discarded presence). A new scoped read-only `steelman-builder` agent builds adversarial counter-cases. The brief is written to `docs/superpowers/interview/` (outside the hook's `PATH_PREFIX=docs/superpowers/specs/`, so it gets no Law 2 reviewer — NG3/C8). `drafting-spec/` is deleted; `reviewing-spec` keeps only its design-mode rows + Phase 5 proceed gate to review brainstorming's `-design.md` (Law 2 intact, unchanged hook).

**Tech Stack:** Markdown skills/agents/commands/templates; Python 3.9+ stdlib (`re`, `json`, `pathlib`) for validators (matches `parse_spec_structure.py`); bash `set -u -o pipefail` doc-contract + fixture tests; `python3 -m unittest`-style hook tests. No new runtime dependencies.

**Source spec:** `docs/superpowers/specs/2026-05-31-interview-direction-layer-design.md` (design-approved, 5-round separated reviewer). Branch: `feature/interview-direction-layer` (worktree). Target plugin version: `0.11.3 → 0.12.0`.

---

## File Structure

Each unit has one responsibility; mechanical logic lives in small focused Python scripts (testable without an interview runtime), prose contracts live in skills.

**Create:**
- `plugins/spec-distill/scripts/web_budget.py` — web-search budget enforcer (per-sweep ≤4, per-session ≤8). Reads counters from `state.local.md`. (AC7, PN3, AC8)
- `plugins/spec-distill/scripts/check_brief.py` — interview-brief structural gate (7 sections, citations, steelman log, tried-&-discarded, frontmatter). The Law 1 termination gate, made executable. (AC2, AC4, AC5, V2, V3, V6)
- `plugins/spec-distill/agents/steelman-builder.md` — scoped read-only adversarial counter-case builder. (AC5, AC6, V4)
- `plugins/spec-distill/templates/interview-brief-template.md` — canonical 7-section meta-prompt format. (AC1, AC2)
- `plugins/spec-distill/tests/test_web_sweep_bound.sh` — unit-tests `web_budget.py`. (V5, AC7, AC8)
- `plugins/spec-distill/tests/test_check_brief.sh` — unit-tests `check_brief.py` against valid + broken brief fixtures. (V1, V2, V3, V6, PN4)
- `plugins/spec-distill/tests/test_steelman_builder_scope.sh` — frontmatter `disallowedTools` guard. (V4, AC6)
- `plugins/spec-distill/tests/test_conducting_interview_stage.sh` — contract grep for 5 의례 / web path(a) / steelman gate / brief write / optional invoke / cost_class / kill switch / PN1 state-write contract. (AC3, AC7, AC8, AC13)
- `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` — asserts spec-mode rows / re-consensus / mode_b_violation are ABSENT and design rows present. (PN2, V8)
- `plugins/spec-distill/tests/test_readme_sync.sh` — README keyword sync. (AC12)
- `plugins/spec-distill/tests/fixtures/interview-brief-valid.md` — passes `check_brief.py gate`.
- `plugins/spec-distill/tests/fixtures/interview-brief-no-landscape.md` — R2 unmet (uncited landscape). 
- `plugins/spec-distill/tests/fixtures/interview-brief-unchallenged.md` — R3 unmet (malformed skepticism log).
- `plugins/spec-distill/tests/fixtures/interview-brief-missing-section.md` — AC2 unmet (a numbered section absent).
- `plugins/spec-distill/tests/fixtures/interview-brief-empty-tried.md` — R4 unmet (empty Tried & Discarded, no N/A sentinel).
- `plugins/spec-distill/tests/fixtures/state-web-within.md` / `state-web-over-sweep.md` / `state-web-over-session.md` — web counter fixtures.

**Modify:**
- `plugins/spec-distill/skills/conducting-interview/SKILL.md` — major rewrite: 5 의례 + web path(a) + steelman gate + brief write (terminal) + optional invoke; `cost_class: medium → variable`; PN1 state-write-via-Bash contract.
- `plugins/spec-distill/commands/interview.md` — reframe role to problem-space stage; preserve trivia escape + dispatch line.
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — design-mode only: remove spec-mode rows, `[3.5]` re-consensus, `mode_b_violation`, `SKIP_RECONSENSUS`. Keep design rows + Phase 5 proceed gate + Approve handoff.
- `plugins/spec-distill/agents/spec-reviewer.md` — description: drafting-spec → brainstorming/interview flow; clarify brief is NOT its target (NG3). Keep both mode branches.
- `plugins/spec-distill/tests/test_conducting_interview_internal.sh` — `cost_class: medium → variable`.
- `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh` — design-only assertions (drop spec-mode wording).
- `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` — drop the two spec `< CAP` row assertions; keep design rows + README.
- `plugins/spec-distill/tests/test_hook_output_schema.py` — add `-design.md`-under-specs → design-mode + `pending_review`, and `interview/` path → out-of-scope (C8). (AC9, V7)
- `plugins/spec-distill/README.md` — Flow / Principles Instantiated / Hooks / Kill switches sync. (AC12)
- `plugins/spec-distill/CHANGELOG.md` — `## [0.12.0]` Added/Changed/Removed. (AC11)
- `plugins/spec-distill/.claude-plugin/plugin.json` — `version: 0.11.3 → 0.12.0`. (C6, AC11)

**Delete:**
- `plugins/spec-distill/skills/drafting-spec/` (whole directory — Mode A+B). (AC10, V8)
- `plugins/spec-distill/tests/run-fixture-ac1.sh` + `tests/fixtures/interview-transcript-bbda.md` (test drafting-spec Mode A only).
- `plugins/spec-distill/tests/fixtures/mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md` (orphans — zero test references; subjects removed).

**Leave untouched (in scope, intentionally not changed):**
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, all hooks — `PATH_PREFIX=docs/superpowers/specs/` already detects `-design.md` and auto-excludes `interview/` (C8). Verified by Task 10, not edited (design "hook 무수정").
- `templates/spec-template.md` — now unused (was drafting-spec Mode A scaffold), but in `templates/` (outside AC10's `{skills,hooks,commands}` grep scope) and harmless. Not deleted (lightness; design did not call for it).

---

## Task 1: Pin the green baseline (V9 prerequisite)

Per [[project_qg_pre_existing_test_reds]]: capture the pre-change test state so V9 can prove no regression. Already observed: **bash 26/26 PASS, python 3/3 PASS**. Re-confirm before any edit.

**Files:** none (verification only).

- [ ] **Step 1: Confirm branch + clean tree**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-direction-layer
git branch --show-current   # expect: feature/interview-direction-layer
git status --short          # expect: only the new plan file under docs/superpowers/plans/
```
Expected: branch is `feature/interview-direction-layer`; no unexpected modifications.

- [ ] **Step 2: Run the full baseline suite and record the result**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-direction-layer
pass=0; failed=""
for t in plugins/spec-distill/tests/*.sh; do
  bash "$t" >/dev/null 2>&1 && pass=$((pass+1)) || failed="$failed $(basename "$t")"
done
echo "bash: PASS=$pass FAIL:${failed:- none}"
for p in test_hook_output_schema test_gc test_session_end_cleanup; do
  python3 "plugins/spec-distill/tests/$p.py" >/dev/null 2>&1 && echo "py PASS $p" || echo "py FAIL $p"
done
```
Expected: `bash: PASS=26 FAIL: none` and `py PASS` for all three. **If anything is already red, stop and investigate before proceeding** — V9 compares against this exact baseline.

- [ ] **Step 3: No commit** (verification task — nothing to commit).

---

## Task 2: `web_budget.py` — web-search budget enforcer (AC7, AC8, PN3)

The bound must be mechanical with no manual-review fallback (AC7). Counters live in `state.local.md` frontmatter (**PN3 resolution: state-file counter, not in-memory**). `conducting-interview` increments them via Bash (PN1) before each web call and runs this check; a non-zero exit forces an advisory + `(b)` user question. The web kill switch short-circuits to success (AC8 graceful degradation).

**Files:**
- Create: `plugins/spec-distill/scripts/web_budget.py`
- Create: `plugins/spec-distill/tests/test_web_sweep_bound.sh`
- Create: `plugins/spec-distill/tests/fixtures/state-web-within.md`
- Create: `plugins/spec-distill/tests/fixtures/state-web-over-sweep.md`
- Create: `plugins/spec-distill/tests/fixtures/state-web-over-session.md`

- [ ] **Step 1: Write the three state fixtures**

`tests/fixtures/state-web-within.md`:
```markdown
---
session_id: testsession01
phase: 1
web_sweep_count: 4
web_search_count: 8
---

within budget (sweep at cap, session at cap)
```

`tests/fixtures/state-web-over-sweep.md`:
```markdown
---
session_id: testsession01
phase: 1
web_sweep_count: 5
web_search_count: 6
---

sweep over cap
```

`tests/fixtures/state-web-over-session.md`:
```markdown
---
session_id: testsession01
phase: 1
web_sweep_count: 2
web_search_count: 9
---

session over cap
```

- [ ] **Step 2: Write the failing test**

`tests/test_web_sweep_bound.sh`:
```bash
#!/usr/bin/env bash
# V5 / AC7 / AC8 — web_budget.py enforces sweep<=4, session<=8; kill switch = ok.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/web_budget.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# within budget → exit 0
python3 "$SCRIPT" check "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note PASS "AC7: sweep=4/session=8 within budget (exit 0)" \
  || note FAIL "AC7: within-budget should pass"

# sweep over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note FAIL "AC7: sweep=5 should be rejected" \
  || note PASS "AC7: sweep=5 > 4 rejected (exit 1)"

# session over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-session.md" >/dev/null 2>&1 \
  && note FAIL "AC7: session=9 should be rejected" \
  || note PASS "AC7: session=9 > 8 rejected (exit 1)"

# AC8: kill switch forces ok even when over budget (graceful degradation)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note PASS "AC8: DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → exit 0 (web disabled)" \
  || note FAIL "AC8: kill switch should short-circuit to ok"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_web_sweep_bound.sh`
Expected: FAIL (script does not exist yet — `python3` cannot find `web_budget.py`).

- [ ] **Step 4: Implement `web_budget.py`**

`scripts/web_budget.py`:
```python
#!/usr/bin/env python3
"""spec-distill — web research budget enforcer (AC7, AC8, PN3).

Enforces two bounds on interview web research, reading counters from a
state.local.md frontmatter (PN3: state-file counter, not in-memory):

  - per-sweep:   web_sweep_count  <= SWEEP_CAP (4)   — AP9 fan-out guard
  - per-session: web_search_count <= SESSION_CAP (8) — AP16 unbounded guard

conducting-interview increments these via Bash before each web call (worktree
sessions cannot Edit/Write the main-repo state — PN1) and runs `check`; a
non-zero exit means the next call would breach budget → caller emits advisory +
forces a (b) user question.

Kill switch DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → always exit 0 (web disabled;
caller skips landscape and logs loudly — AC8 graceful degradation).

CLI:
  web_budget.py check <state.local.md>   → exit 0 within budget, 1 if over.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SWEEP_CAP = 4
SESSION_CAP = 8


def _read_counter(text: str, key: str) -> int:
    m = re.search(rf"^{re.escape(key)}\s*:\s*([0-9]+)\s*$", text, re.MULTILINE)
    return int(m.group(1)) if m else 0


def check(state_path: Path) -> int:
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1":
        print(json.dumps({"ok": True, "reason": "web disabled (kill switch)"}))
        return 0
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    sweep = _read_counter(text, "web_sweep_count")
    session = _read_counter(text, "web_search_count")
    over = []
    if sweep > SWEEP_CAP:
        over.append(f"sweep {sweep} > {SWEEP_CAP}")
    if session > SESSION_CAP:
        over.append(f"session {session} > {SESSION_CAP}")
    if over:
        print(json.dumps({"ok": False, "sweep": sweep, "session": session,
                          "reason": "; ".join(over)}))
        return 1
    print(json.dumps({"ok": True, "sweep": sweep, "session": session}))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] != "check":
        print("usage: web_budget.py check <state.local.md>", file=sys.stderr)
        return 64
    return check(Path(argv[2]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_web_sweep_bound.sh`
Expected: `Total: 4 | Pass: 4 | Fail: 0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/scripts/web_budget.py \
        plugins/spec-distill/tests/test_web_sweep_bound.sh \
        plugins/spec-distill/tests/fixtures/state-web-*.md
git commit -m "feat(spec-distill): add web_budget.py search-bound enforcer (AC7/PN3)"
```

---

## Task 3: `interview-brief-template.md` — canonical meta-prompt format (AC1, AC2)

The brief is the terminal deliverable: a meta-prompt for brainstorming. This template defines the exact frontmatter + 7-section shape that `check_brief.py` (Task 4) validates and `conducting-interview` (Task 6) fills.

**Files:**
- Create: `plugins/spec-distill/templates/interview-brief-template.md`

- [ ] **Step 1: Write the template**

`templates/interview-brief-template.md`:
```markdown
---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.12.0
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

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
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

## 5. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.
 **시행착오 0건이면 `N/A — 전부 first-time defend+lock` 한 줄 명시**(빈 섹션 금지, R4 edge).)

- 시도한 방향 → 버린 이유

## 6. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- OQ1: ...

## 7. Concrete Next Action

(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
```

- [ ] **Step 2: Sanity-check section anchors match `check_brief.py` expectations**

Run: `grep -nE '^## [0-9]\.' plugins/spec-distill/templates/interview-brief-template.md`
Expected: exactly 7 lines, numbered `## 1.` through `## 7.` with titles `Reframed Problem`, `Locked Directions`, `External Landscape`, `Skepticism Log`, `Tried & Discarded`, `Open Questions`, `Concrete Next Action`.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/templates/interview-brief-template.md
git commit -m "feat(spec-distill): add interview-brief meta-prompt template (AC1/AC2)"
```

---

## Task 4: `check_brief.py` — the executable 5-의례 termination gate (AC2, AC4, AC5, V2, V3, V6, PN4)

The Law 1 structural gate, made mechanical (AC3: any ritual unmet blocks termination). This is **not** a Law 2 reviewer (NG3) — the brief gets no separated review; this is a structural self-check analogous to `parse_spec_structure.py`. `conducting-interview` runs `check_brief.py gate <brief>` before finalizing.

**PN4 resolution:** the steelman verbatim guarantee is verified by *substring containment* (each §4 entry must contain ≥1 URL + a ≥10-char statement + a valid verdict), **not** exact-string match — avoids flakiness. The genuine "is the steelman a real counter-argument" judgment is V10 manual (acknowledged quality gap; mechanical layer catches empty/formal entries).

**Files:**
- Create: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/test_check_brief.sh`
- Create fixtures: `interview-brief-valid.md`, `interview-brief-no-landscape.md`, `interview-brief-unchallenged.md`, `interview-brief-missing-section.md`, `interview-brief-empty-tried.md`

- [ ] **Step 1: Write the valid fixture (must pass the gate)**

`tests/fixtures/interview-brief-valid.md`:
```markdown
---
name: sample-topic
type: interview-brief
created_at: 2026-05-31
session_id: testsession01
source: spec-distill conducting-interview v0.12.0
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

## 5. Tried & Discarded

- Tried full client SPA → discarded: TTFP regression on cold load.

## 6. Open Questions

- OQ1: caching layer for authenticated views — deferred to solution space.

## 7. Concrete Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
```

- [ ] **Step 2: Write the four broken fixtures (each must fail the gate)**

`tests/fixtures/interview-brief-no-landscape.md` — copy the valid fixture but replace the §3 body with an **uncited** entry:
```markdown
## 3. External Landscape

- islands architecture is popular these days
```
(Keep all other sections identical to the valid fixture so only R2/AC4 fails.)

`tests/fixtures/interview-brief-unchallenged.md` — copy valid but replace §4 with a malformed entry (no URL, no verdict):
```markdown
## 4. Skepticism Log

- we considered alternatives but they seemed worse
```

`tests/fixtures/interview-brief-missing-section.md` — copy valid but **delete the entire `## 5. Tried & Discarded` header and body** (a numbered section absent → AC2 fail).

`tests/fixtures/interview-brief-empty-tried.md` — copy valid but make §5 empty (header present, no entries, no `N/A` sentinel):
```markdown
## 5. Tried & Discarded

## 6. Open Questions
```
(R4 edge: empty section with no `N/A — ...` sentinel must fail.)

- [ ] **Step 3: Write the failing test**

`tests/test_check_brief.sh`:
```bash
#!/usr/bin/env bash
# V1/V2/V3/V6/PN4 — check_brief.py gate: valid brief passes, each ritual-unmet brief fails.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Valid brief → gate exit 0 (AC2/AC4/AC5 all satisfied)
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" >/dev/null 2>&1 \
  && note PASS "valid brief passes gate" \
  || note FAIL "valid brief should pass gate"

# R2/AC4: uncited landscape → fail
python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" >/dev/null 2>&1 \
  && note FAIL "uncited landscape should fail (AC4)" \
  || note PASS "uncited landscape blocks termination (R2/AC4)"

# R3/AC5: malformed skepticism (no URL/verdict) → fail
python3 "$SCRIPT" gate "$FX/interview-brief-unchallenged.md" >/dev/null 2>&1 \
  && note FAIL "malformed skepticism should fail (AC5)" \
  || note PASS "malformed skepticism blocks termination (R3/AC5)"

# AC2: missing numbered section → fail
python3 "$SCRIPT" gate "$FX/interview-brief-missing-section.md" >/dev/null 2>&1 \
  && note FAIL "missing section should fail (AC2)" \
  || note PASS "missing section blocks termination (AC2)"

# R4/V2: empty Tried & Discarded with no N/A sentinel → fail
python3 "$SCRIPT" gate "$FX/interview-brief-empty-tried.md" >/dev/null 2>&1 \
  && note FAIL "empty Tried & Discarded should fail (R4)" \
  || note PASS "empty Tried & Discarded blocks termination (R4/V2)"

# PN4: containment, not exact match — the malformed-skepticism failure is reported as
# malformed (missing url/verdict), confirming the substring-based check fires.
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-url' \
  && note PASS "PN4: skepticism check flags missing URL via substring containment" \
  || note FAIL "PN4: skepticism containment check did not flag missing URL"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: FAIL (`check_brief.py` does not exist).

- [ ] **Step 5: Implement `check_brief.py`**

`scripts/check_brief.py`:
```python
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
    if not tried_discarded_ok(text):
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
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh`
Expected: `Total: 6 | Pass: 6 | Fail: 0`.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/scripts/check_brief.py \
        plugins/spec-distill/tests/test_check_brief.sh \
        plugins/spec-distill/tests/fixtures/interview-brief-*.md
git commit -m "feat(spec-distill): add check_brief.py 5-ritual termination gate (AC2/AC4/AC5)"
```

---

## Task 5: `steelman-builder` agent — scoped read-only counter-case builder (AC5, AC6, V4)

A dedicated scoped agent (not `general-purpose` reuse — decision #8) that builds the strong case for an alternative direction with web grounding. Physically blocked from writing (Law 2 frontmatter scoping). **Security-sensitive persona (C3)** — weakening PRs get security review.

**Model decision:** `model: sonnet` — matches the two sibling read-only agents in this plugin (`spec-reviewer`, `breadth-keeper`); sonnet is proven adequate for the sibling adversarial reviewer, and intra-plugin consistency outweighs cross-plugin "inherit" leanings. `cost_class: variable` (does bounded web research — matches C4's variable web cost). *If V10 e2e shows weak steelmen, escalate model in a follow-up (documented escape hatch).*

**Files:**
- Create: `plugins/spec-distill/agents/steelman-builder.md`
- Create: `plugins/spec-distill/tests/test_steelman_builder_scope.sh`

- [ ] **Step 1: Write the failing test**

`tests/test_steelman_builder_scope.sh`:
```bash
#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" && note PASS "agent file exists" || { note FAIL "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Extract frontmatter block (first ---...second ---)
fm="$(awk '/^---$/{c++} c==1' "$AGENT")"

# AC6: disallowedTools includes all four write tools
for tool in Write Edit MultiEdit NotebookEdit; do
  grep -qE "^\s*-\s*$tool\b" <<<"$fm" \
    && note PASS "AC6: disallowedTools includes $tool" \
    || note FAIL "AC6: disallowedTools MISSING $tool"
done

# allowedTools includes web research surfaces
for tool in WebSearch WebFetch; do
  grep -qE "^\s*-\s*$tool\b" <<<"$fm" \
    && note PASS "allowedTools includes $tool" \
    || note FAIL "allowedTools MISSING $tool"
done

# name + verbatim-output contract present in body
grep -q '^name: steelman-builder$' <<<"$fm" \
  && note PASS "name: steelman-builder" || note FAIL "name field broken"
grep -qiE 'verbatim|약화.*금지|편집.*금지' "$AGENT" \
  && note PASS "AC5: verbatim/no-weakening output contract present" \
  || note FAIL "AC5: verbatim output contract missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_steelman_builder_scope.sh`
Expected: FAIL (`Total: 1 | Pass: 0 | Fail: 1` — agent file missing).

- [ ] **Step 3: Write the agent**

`agents/steelman-builder.md`:
```markdown
---
name: steelman-builder
model: sonnet
cost_class: variable
color: red
allowedTools:
  - Read
  - Grep
  - Glob
  - WebSearch
  - WebFetch
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
description: >
  Use this agent during a spec-distill interview when a direction is suspect
  (landscape contradiction / known anti-pattern / locked-direction conflict /
  breadth-keeper tunneling) to build the STRONGEST case for an alternative,
  grounded in web evidence. Independent skeptic, read-only by design (Law 2
  frontmatter scoping). Output is consumed verbatim by conducting-interview.

  <example>Context: User wants a custom auth system; landscape shows mature OSS.
  user: "이 방향 의심돼 — 대안 steelman 만들어줘"
  assistant: "I'll dispatch the steelman-builder agent to build the alternative's
  strongest evidence-backed case."</example>
---

# Steelman-Builder Agent (R3 의심 게이트, AP14 회피)

당신은 spec-distill 인터뷰의 steelman-builder입니다. 의심 trigger된 *현재 방향*에
대해, 당신은 **반대편(대안)의 가장 강한 케이스**를 웹 근거와 함께 구축하는 독립
skeptic입니다. 당신은 방향을 *결정*하지 않습니다 — 사용자가 결정합니다(P17). 당신은
대안이 이길 수 있는 최선의 논거를 제시할 뿐입니다.

## You are / are not

- You ARE: 대안의 강한 옹호자. confirmation bias의 역행자(Torres). prior-art 발굴자.
- You are NOT: 파일 작성자(Write/Edit 물리 차단), 방향 결정자, 원안의 옹호자.

## Input

- 의심 trigger된 현재 방향(statement)과 trigger 이유(landscape 모순 / anti-pattern /
  LD 충돌 / tunneling 중 하나).
- (있으면) 현재까지의 locked_directions, External Landscape 발췌.

## Required research (출력 전)

1. 대안 방향을 1–2회 web 검색(WebSearch/WebFetch)으로 근거 수집 — prior-art, 벤치마크,
   실패 사례. **순차 호출**(병렬·투기적 금지, C5/AP9).
2. (가능하면) codebase grep로 기존 제약과의 정합 확인.

## Output 형식 (이 형식을 정확히 준수 — conducting-interview가 verbatim 사용)

```yaml
alternative_statement: "<대안 방향 한 문장, 강하게>"
strongest_case: "<대안이 원안을 이기는 핵심 논거 2-4줄>"
evidence:
  - url: "https://..."
    claim: "<이 출처가 뒷받침하는 것>"
  - url: "https://..."
    claim: "..."
weakness_of_current: "<원안의 가장 약한 지점>"
confidence: 0.0-1.0
```

## 동작 규칙

1. **read-only**: 어떤 파일도 Write/Edit/MultiEdit/NotebookEdit 하지 않습니다(frontmatter 강제).
2. **인용 필수**: 모든 외부 주장은 `evidence[].url`을 가져야 합니다(AC4 연계). URL 없는
   주장은 출력하지 마십시오.
3. **verbatim 계약**: 당신의 `alternative_statement` + `evidence`는 conducting-interview가
   Skepticism Log에 **그대로**(약화·편집 없이) 기록합니다(AC5). 따라서 스스로 hedge하지
   말고 가장 강한 형태로 작성하십시오.
4. **한 방향당 1회**: 같은 방향에 대한 재호출은 새 근거가 있을 때만(AP16 harassment 방지).
5. **confidence < 0.4** 면 "대안이 약함 — 원안 defend 합리적"을 명시(억지 steelman 금지).

## 사용하지 않는 경우

- 의심 trigger가 없는 방향(R3 대상 아님).
- trivia 요청(P12).
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_steelman_builder_scope.sh`
Expected: `Total: 9 | Pass: 9 | Fail: 0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/agents/steelman-builder.md \
        plugins/spec-distill/tests/test_steelman_builder_scope.sh
git commit -m "feat(spec-distill): add scoped read-only steelman-builder agent (AC5/AC6)"
```

---

## Task 6: `conducting-interview/SKILL.md` — problem-space stage rewrite (AC1, AC3, AC7, AC8, AC13, R1–R5, G1–G7, PN1, PN3)

The core change. The interview becomes a strong problem-space stage that runs the 5 통과 의례, writes a terminal brief, and optionally invokes brainstorming. Depends on Tasks 2–5 (web_budget.py, check_brief.py, steelman-builder, template).

**PN1 resolution (state writes from a worktree):** `state.local.md` lives in the *main repo* `.claude/spec-distill/<sid>/` (via `state_path.py state-root`), which is **outside the worktree** — the `Write`/`Edit` tools are blocked there. The skill MUST write state via **Bash** (resolve root, then a `python3 -c`/heredoc write). The **brief** itself goes to `docs/superpowers/interview/` which IS inside the worktree, so the `Write` tool is used for the brief.

**PN3 resolution:** web counters (`web_sweep_count`, `web_search_count`) live in `state.local.md` frontmatter and are incremented via the same Bash state-write path before each web call.

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_internal.sh` (cost_class assertion)
- Create: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

- [ ] **Step 1: Write the failing contract test**

`tests/test_conducting_interview_stage.sh`:
```bash
#!/usr/bin/env bash
# AC3/AC7/AC8/AC13 + R1-R5 + PN1/PN3 — conducting-interview problem-space stage contract.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
has() { grep -qiE "$1" "$SKILL" && note PASS "$2" || note FAIL "$2"; }

# cost_class variable (was medium)
grep -q '^cost_class: variable$' "$SKILL" && note PASS "cost_class: variable" || note FAIL "cost_class not variable"

# 5 통과 의례 (R1-R5) named
has 'R1.*Reframe' "R1 Reframe ritual"
has 'R2.*Landscape' "R2 Landscape ritual"
has 'R3.*Skepticism' "R3 Skepticism ritual"
has 'R4.*시행착오|R4.*Tried' "R4 Tried-&-Discarded ritual"
has 'R5.*Open Question|R5.*OQ' "R5 Open-Questions ritual"

# Termination gate calls check_brief.py (AC3) and is blocking
has 'check_brief\.py gate' "termination gate calls check_brief.py gate"
has '차단|block|종료.*금지|finalize.*안' "gate is blocking on failure"

# Web path(a) + bound enforcer + kill switch (AC7/AC8)
has 'web_budget\.py' "web bound calls web_budget.py"
has 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "web kill switch documented (AC8)"
has 'web_sweep_count' "PN3: web_sweep_count counter in state"
has 'web_search_count' "PN3: web_search_count counter in state"

# Steelman dispatch + verbatim (AC5)
has 'steelman-builder' "steelman-builder dispatch"
has 'verbatim|약화.*금지|편집.*금지' "steelman verbatim pass-through (AC5)"

# Brief write to interview/ (terminal) + template
has 'docs/superpowers/interview/' "brief written under docs/superpowers/interview/ (C8)"
has 'interview-brief-template' "uses brief template"

# Optional invoke + superpowers-absent graceful degrade (AC13)
has 'optional|선택' "brainstorming invoke is optional"
has 'superpowers.*(부재|없).*advisory|advisory.*superpowers' "AC13: superpowers-absent loud advisory"

# PN1: state writes via Bash (worktree cannot Edit/Write main-repo state)
has 'state_path\.py state-root|Bash.*state|state.*Bash' "PN1: state-write-via-Bash contract"

# drafting-spec reference removed (AC10 scope)
grep -q 'drafting-spec' "$SKILL" && note FAIL "AC10: drafting-spec still referenced" || note PASS "AC10: no drafting-spec reference"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: FAIL on most assertions (SKILL.md still in old spec-generator form; `drafting-spec` still referenced; `cost_class: medium`).

- [ ] **Step 3: Rewrite the SKILL.md frontmatter + intro**

Replace lines 1–16 (frontmatter + intro through the first paragraph) of `skills/conducting-interview/SKILL.md` with:
```markdown
---
name: conducting-interview
description: >
  Use this skill to run the spec-distill interview — a strong problem-space stage
  (Double Diamond 1st diamond) that reframes the request (meta-prompting), grounds
  it with bounded web research, breaks weak directions with adversarial steelman,
  and pre-resolves trial-and-error. Produces a terminal interview-brief meta-prompt
  at docs/superpowers/interview/. Called by /interview after trivia escape. Runs the
  5 통과 의례 (R1-R5) as a Law 1 structural gate (check_brief.py). Optionally hands the
  brief to superpowers:brainstorming. Persists state to main-repo
  .claude/spec-distill/<session-id>/state.local.md (written via Bash — PN1).
cost_class: variable
user-invocable: false
---

# Conducting Interview — 문제공간 Stage (Phase 1)

당신은 spec-distill의 인터뷰 stage를 진행 중입니다. 이 stage는 *받아적는* 인터뷰가
아니라 **강한 문제공간 stage**입니다(Double Diamond 1st diamond — brainstorming 해답공간
앞단, 상보적·비중복). 4-block Korean Socratic format으로 round를 진행하되, 종료 전 **5
통과 의례**를 모두 통과해야 brief 작성이 허용됩니다(Law 1 구조 게이트).

산출물은 `spec.md`가 아니라 **interview brief**(brainstorming용 meta-prompt)이며, 이
brief는 **단독 완결 terminal 산출물**입니다 — superpowers가 있으면 brainstorming으로
넘기고(optional), 없으면 brief 자체로 완료합니다.
```

- [ ] **Step 4: Update the State section to add web counters + PN1 Bash write contract**

In the "State location" / frontmatter-schema section, add the web counters to the schema and append a state-write contract subsection. Replace the state frontmatter `yaml` block's field list to include (after `non_user_streak`):
```yaml
web_sweep_count: 0                   # 현재 sweep 내 web 검색 호출 수 (AP9, ≤4). sweep 종료 시 0으로 reset.
web_search_count: 0                  # 세션 누적 web 검색 호출 수 (AP16, ≤8 soft cap).
```
And replace `pending_locked_decisions` comment to reference the brief instead of drafting-spec:
```yaml
pending_locked_decisions: []         # 매 round 끝 append (b/d path 명시 응답만). brief frontmatter locked_directions로 변환.
```
Then add this new subsection immediately after the state schema block:
```markdown
### State write contract (PN1 — worktree-safe)

`state.local.md`는 `state_path.py`가 **main repo** `.claude/spec-distill/<sid>/`로 라우팅합니다
(`git rev-parse --git-common-dir`). 워크트리 세션에서 이 경로는 워크트리 *밖*이라 `Write`/`Edit`
tool이 차단됩니다 — state 갱신은 **반드시 Bash**로 하십시오:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# read-modify-write via python3 -c / heredoc (Edit tool 사용 금지 — main-repo 경로)
```

**brief는 예외**: `docs/superpowers/interview/`는 워크트리 *안*이라 `Write` tool로 정상 작성.
```

- [ ] **Step 5: Extend the 4-path routing — path (a) web expansion**

In the C43 routing table, replace the `(a) factual` row with:
```markdown
| (a) **factual / landscape** | 답이 codebase/git history *또는 외부 prior-art*에 있는 경우 | codebase는 grep/Read *auto-confirm*; 외부는 web sweep(아래 R2). 마커 `[from-code][auto-confirmed]` 또는 `[from-web]`. streak +1. |
```
And in the Rhythm Guard section, add after the streak rules:
```markdown
- (a) web auto-research: streak +1 (과도하면 강제 (b)로 사용자를 loop에 유지 — AP16).
```

- [ ] **Step 6: Add the "5 통과 의례" section (the Law 1 gate)**

Insert a new section before "## 종료 조건" (which you will replace in Step 8):
```markdown
## 5 통과 의례 (Law 1 구조 게이트, R1–R5)

brief 작성(+ optional brainstorming invoke)은 다음 5 의례를 **모두 통과**해야 허용됩니다.
하나라도 미충족이면 종료 차단. 종료 직전 `check_brief.py gate`로 **기계적 검증**(AC3):

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Reframe (메타 프롬프트)** | 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal. | (d) ontological 5-type (ESSENCE/ROOT_CAUSE/...) → brief §1 |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 → brief §3 |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *방어 또는 전환*. un-challenged 의심 방향 lock 불가. | steelman-builder dispatch → brief §4 |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* 기록. 0건이면 `N/A — 전부 first-time defend+lock` 명시(빈 섹션 금지). | brief §5 |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | brief §6 |

### R2 — 웹 Landscape (bounded, AC7/AC8)

토픽이 잡히면(round 1–2) landscape sweep **1회**를 수행합니다. 각 web 검색 *전에* state의
`web_sweep_count`/`web_search_count`를 +1 하고(PN1 Bash write) budget을 확인:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/web_budget.py" check "$ROOT/<session-id>/state.local.md" || {
  echo "[spec-distill] web budget 초과 — landscape 중단, 강제 (b) 사용자 질문" ; }
```

- budget 초과(sweep>4 또는 session>8) → advisory + **강제 (b) 사용자 질문**(AP16).
- 모든 외부 주장은 **출처 URL 필수**(AC4) — brief §3에 `[취함|피함|중립]` + 이유와 함께.
- **kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`** 또는 web 도구 부재 → landscape를 **loud하게
  생략**하고 계속(crash 금지, graceful degradation — AC8): `[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용`.
- sweep 종료 시 `web_sweep_count`를 0으로 reset(session 카운터는 유지).

### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 LD 불일치 / breadth-keeper tunneling.

1. `steelman-builder` 에이전트를 **순차** dispatch(병렬·투기적 금지 — C5):
   ```
   Agent({ description: "Steelman alternative", subagent_type: "spec-distill:steelman-builder",
           prompt: "의심 방향: <statement>. trigger: <이유>. 대안의 강한 케이스를 웹근거와 함께." })
   ```
2. builder 출력(`alternative_statement` + `evidence[].url`)을 **verbatim**으로 4-block에 반대
   케이스로 제시 — conducting-interview는 이를 **약화·편집하지 않습니다**(AC5).
3. **게이트**(P17): 사용자가 (방어 → 원안 lock + `defense` 기록, steelman: defended) /
   (전환 → 대안 lock, 원안은 R4로, steelman: switched-to-this) / (보류 → §6 OQ).
4. builder 출력 그대로 brief §4 Skepticism Log에 기록(대안 statement + URL + verdict).
5. 한 방향당 steelman 1회(새 근거 없으면 재steelman 금지 — AP16 harassment 방지).

**Law 2 경계**: steelman 게이트는 Law 2 분리 메커니즘이 *아닙니다* — Law 2 분리 reviewer는
오직 design doc(brainstorming `-design.md`)에만 적용됩니다. steelman은 문제공간 품질을 끌어올리는
Law 1급 skepticism 의례입니다(verbatim pass-through로 무력화 방지).
```

- [ ] **Step 7: Replace the breadth-keeper section's neutral text — leave it (no change needed)**

The breadth-keeper dispatch section stays as-is (still valid — narrow-tunneling detection feeds R3 triggers). No edit. (This step is a no-op confirmation; do not remove the section.)

- [ ] **Step 8: Replace "## 종료 조건" + "## 다음 phase" with brief-write + optional invoke**

Replace the entire "## 종료 조건" section AND the "## 다음 phase" section (currently transitioning to drafting-spec) with:
```markdown
## 종료 — brief 작성 + optional handoff

다음을 모두 만족하고 **5 통과 의례가 모두 통과**하면 brief를 작성합니다:

- Goal/진짜 problem이 한 문장으로 재구성됨(R1).
- Landscape가 인용과 함께 수집됨(R2).
- 의심 방향이 모두 steelman 통과(R3).
- 시행착오가 기록됨(R4).
- Open Questions 박제(R5).

### Step A — brief 작성 (terminal 산출물)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 7-section 구조 확보.
2. 경로: `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md` (워크트리 안 → `Write` tool 사용).
   - frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용 — 새 세션 생성 안 함), `locked_directions[]`
     (state `pending_locked_decisions` + steelman verdict 반영).
3. **기계적 게이트 검증**(AC3) — 작성 직후:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 의례를 보완(누락 섹션/무인용
   landscape/형식 미달 steelman/빈 Tried&Discarded). 통과(exit 0)할 때까지 반복.

### Step B — optional handoff (superpowers 있을 때만)

brief는 **단독 완결**입니다. 다음은 *optional 다음 단계*입니다:

- **superpowers `brainstorming` skill 사용 가능 시**: 이 brief를 rich context로 전달하며
  `superpowers:brainstorming`을 호출(해답공간 설계 → `-design.md` → 기존 hook이 design mode로
  검증 → reviewing-spec → writing-plans).
- **superpowers 부재 시(AC13)**: brief를 완료하고 **loud advisory**를 낸 뒤 정지 — crash·spec-mode
  fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.`

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).
```

- [ ] **Step 9: Update `test_conducting_interview_internal.sh` cost_class assertion**

In `tests/test_conducting_interview_internal.sh`, change line 32 from:
```bash
grep -q '^cost_class: medium$' "$SKILL" \
```
to:
```bash
grep -q '^cost_class: variable$' "$SKILL" \
```
And update the adjacent PASS/FAIL message text from `cost_class preserved` to `cost_class: variable (v0.12.0)`.

- [ ] **Step 10: Run both tests to verify they pass**

Run:
```bash
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
bash plugins/spec-distill/tests/test_conducting_interview_internal.sh
```
Expected: both `Fail: 0` / `all guards green`. In particular the stage test's "AC10: no drafting-spec reference" must pass.

- [ ] **Step 11: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh \
        plugins/spec-distill/tests/test_conducting_interview_internal.sh
git commit -m "feat(spec-distill): rewrite conducting-interview as problem-space stage (R1-R5, AC1/AC3/AC7/AC8/AC13)"
```

---

## Task 7: `commands/interview.md` — reframe role to problem-space stage (G1, NG6)

Reframe the command's description and role text from "→ spec.md" to "→ interview brief / problem-space stage". Preserve the trivia escape (NG6) and the `Skill conducting-interview` dispatch line (guarded by `test_conducting_interview_internal.sh` AC3).

**Files:**
- Modify: `plugins/spec-distill/commands/interview.md`

- [ ] **Step 1: Update the frontmatter description**

Replace line 2:
```markdown
description: 4-block Korean Socratic 인터뷰로 모호한 요청을 spec.md로 변환. devbrew Law 1 instantiation.
```
with:
```markdown
description: 강한 문제공간 stage — 메타프롬프팅·웹리서치·steelman으로 방향을 끌어내 brainstorming용 interview brief를 생성. devbrew Law 1 instantiation.
```

- [ ] **Step 2: Update the entry-point role line**

Replace line 8:
```markdown
당신은 spec-distill 플러그인의 entry point입니다. 사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.
```
with:
```markdown
당신은 spec-distill 플러그인의 entry point입니다. `/interview`는 superpowers brainstorming
**앞단의 강한 문제공간 stage**로, 사용자에게서 방향을 끌어내고(메타프롬프팅), 외부 사례를
웹으로 조사하고, 약한 방향을 steelman으로 깨뜨려 **interview brief**(meta-prompt)를 산출합니다.
사용자가 `/interview`를 호출하면 다음 순서로 진행하십시오.
```

- [ ] **Step 3: Update the "다음 단계" tail**

Replace the final section (lines 49–51, "## 다음 단계 ... trivia escape + skill dispatch 책임만 집니다.") with:
```markdown
## 다음 단계

`conducting-interview` skill로 흐름이 넘어가 5 통과 의례(R1–R5)를 거쳐 interview brief를
`docs/superpowers/interview/`에 생성합니다. 이 command 자체는 trivia escape + skill dispatch
책임만 집니다(NG6 — trivia escape 불변).
```

- [ ] **Step 4: Verify trivia escape + dispatch preserved**

Run:
```bash
grep -q 'Trivia Escape Check' plugins/spec-distill/commands/interview.md && echo "trivia escape preserved" || echo "MISSING trivia escape"
grep -q 'Skill conducting-interview' plugins/spec-distill/commands/interview.md && echo "dispatch preserved" || echo "MISSING dispatch"
bash plugins/spec-distill/tests/test_conducting_interview_internal.sh
```
Expected: both "preserved" lines printed; internal test all green (AC3 dispatch guard intact).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/commands/interview.md
git commit -m "docs(spec-distill): reframe /interview command as problem-space stage (G1)"
```

---

## Task 8: Remove `drafting-spec/` + simplify `reviewing-spec` to design-only (G6, AC10, V8, PN2)

The coupled removal. Spec-mode routing dispatches `drafting-spec`, so removing `drafting-spec` requires removing the spec-mode routing rows, `[3.5]` re-consensus gate, and `mode_b_violation` handling. The design-mode rows + Phase 5 proceed gate (which reviews brainstorming's `-design.md`, Law 2) stay. Then update/delete the tests that reference the removed surfaces so the suite stays green.

**Files:**
- Delete: `plugins/spec-distill/skills/drafting-spec/` (whole dir)
- Delete: `plugins/spec-distill/tests/run-fixture-ac1.sh`, `tests/fixtures/interview-transcript-bbda.md`
- Delete: `tests/fixtures/mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh`
- Modify: `plugins/spec-distill/tests/test_rereview_cap_consistency.sh`
- Create: `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh`

- [ ] **Step 1: Write the failing design-only test (PN2)**

`tests/test_reviewing_spec_design_only.sh`:
```bash
#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Design rows present (Law 2 design-doc review survives)
grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && note PASS "design approved → Human Gate row present" || note FAIL "design approved row missing"
grep -qE 'design\b.*needs_revise.*author' "$SKILL" \
  && note PASS "design needs_revise → author 회귀 row present" || note FAIL "design needs_revise row missing"

# Spec-mode / re-consensus / Mode B removed
grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && note FAIL "re-consensus gate still present (should be removed)" \
  || note PASS "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && note FAIL "mode_b_violation still present" || note PASS "mode_b_violation removed"
grep -qE '^\| spec \|' "$SKILL" \
  && note FAIL "spec-mode routing rows still present" || note PASS "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && note FAIL "drafting-spec still referenced in reviewing-spec" || note PASS "drafting-spec ref removed from reviewing-spec"

# AC10/V8: drafting-spec absent from skills/hooks/commands + directory gone
COUNT=$(grep -rl 'drafting-spec' "$PLUGIN/skills" "$PLUGIN/hooks" "$PLUGIN/commands" 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" == "0" ]] && note PASS "AC10: 0 drafting-spec refs in skills/hooks/commands" \
  || note FAIL "AC10: $COUNT drafting-spec refs remain"
[[ ! -d "$PLUGIN/skills/drafting-spec" ]] && note PASS "drafting-spec/ directory removed" \
  || note FAIL "drafting-spec/ directory still exists"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_design_only.sh`
Expected: FAIL (drafting-spec dir present; spec rows/re-consensus/mode_b present).

- [ ] **Step 3: Delete drafting-spec + orphan fixtures + the Mode-A test**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-direction-layer
git rm -r plugins/spec-distill/skills/drafting-spec
git rm plugins/spec-distill/tests/run-fixture-ac1.sh \
       plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md \
       plugins/spec-distill/tests/fixtures/mode-b-guard-case.md \
       plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md \
       plugins/spec-distill/tests/fixtures/routing-trace-cases.md \
       plugins/spec-distill/tests/fixtures/stagnation-cases.md
```

- [ ] **Step 4: Simplify the routing table in `reviewing-spec/SKILL.md`**

Replace the entire "## Deterministic Routing Table (AC15)" table (the 9-row table with both spec + design rows) with a design-only table:
```markdown
## Deterministic Routing Table (AC15 — design-mode only, v0.12.0)

이 skill은 brainstorming의 `-design.md`만 검토합니다(spec-mode + drafting-spec는 v0.12.0에서
제거됨 — interview는 brief까지 단독 완결, design doc만 Law 2 분리 reviewer 대상).

| Mode | Verdict | rereview_count | → Next Phase |
|---|---|---|---|
| **design** | `approved` | - | **[5] Human Gate** (proceed 게이트 — ①/② → `superpowers:writing-plans`) |
| **design** | `needs_revise` | < 5 | **brainstorming author 회귀**: 메인 agent가 design.md 직접 수정 후 reviewing-spec 재dispatch. |
| **design** | `needs_revise` | >= 5 | **[5] Human Gate** (forced escalate, full issue_history 첨부) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.
```

- [ ] **Step 5: Delete the spec-mode-only sections from `reviewing-spec/SKILL.md`**

Remove these sections entirely (they are spec-mode/drafting-spec dead paths after removal):
- `## [3.5] Re-consensus gate (G4, G5, AC4)` through the end of its `### Escalate priority table` and `### mode_b_violation 감지` subsections — **but keep** `### Re-review cap (rereview_count, ...)`, `### Stagnation detection`, which still apply to design re-review. (Cut from the `## [3.5]` header down to, but not including, `### Re-review cap`.)
- The `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` bullet in the `## kill switch` section.

Update Step 1's prose: remove the `**pending_review.mode** 분기` clause about spec-mode 11-section skip (now only design exists) — replace with:
```markdown
1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기 + `pending_review:` block 확인. 이 skill은 PostToolUse hook이 design 파일 write를 감지해 `pending_review:` block을 기록하고 Stop hook이 다음 turn에 dispatch를 강제했기 때문에 호출됨 — block이 없으면 manual override(loud advisory). v0.12.0부터 **design mode 전용**: 11-section/locked_decisions schema 검사는 적용 안 함(brainstorming의 자유 형식 design doc). 본문의 placeholder/ambiguity/scope-creep/approaches-comparison/isolation/testing/handoff_incomplete만 spec-reviewer에게 요청.
```

Also in Step C of Phase 5, simplify the "③ 수정 필요" branch to remove the Mode B (spec) path:
```markdown
- **③ 수정 필요**: 후속 `AskUserQuestion`으로 분기 — "revise per review" → 메인 agent가 design.md 직접 수정 후 reviewing-spec 재진입; "more interview" → conducting-interview (state phase=1 reset); "edit myself" → 사용자 편집 후 reviewing-spec 재진입.
```

- [ ] **Step 6: Update the frontmatter description of `reviewing-spec/SKILL.md`**

Replace the description (lines 3–10) to drop spec-mode/re-consensus references:
```markdown
description: >
  Use this skill to dispatch the spec-reviewer agent against a brainstorming
  design doc (docs/superpowers/specs/...-design.md) and apply deterministic
  design-mode routing per the verdict table. Manages re-review cap (max 5),
  stagnation detection, wall-clock budget, and the Phase 5 proceed gate +
  approve handoff. v0.12.0: design-mode only (spec-mode + drafting-spec removed).
cost_class: medium
```

- [ ] **Step 7: Update `test_reviewing_spec_design_routing.sh` to design-only**

This test currently asserts `drafting-spec 미호출` and a spec-mode contrast. Replace its body's spec-mode-adjacent assertions. Specifically, replace the "drafting-spec 미호출" assertion block (lines 28–31) with an assertion that spec-mode rows are gone:
```bash
# (spec-mode rows removed in v0.12.0)
grep -qE '^\| spec \|' "$SKILL" \
  && note FAIL "spec-mode routing rows should be removed (v0.12.0)" \
  || note PASS "spec-mode routing rows removed"
```
And update the cap-row assertions: the `design count >= 5` row check (lines 33–36) stays. Keep AC5/AC6 design-row checks. Remove any reference to `< 3`/spec rows. Verify the cap line the consistency test reads still matches (`count >?= ?5` must remain present as a comment/assertion token for `test_rereview_cap_consistency.sh`):
```bash
# Cross-file cap token (read by test_rereview_cap_consistency.sh): design re-review hard cap.
# count >?= ?5
```
Add that comment line so the consistency test's `grep -qF "count >?= ?5"` still finds the token.

- [ ] **Step 8: Update `test_rereview_cap_consistency.sh` — drop the two spec-row assertions**

Remove the spec-row assertion blocks (the `SPEC_LT_COUNT -eq 2` block at lines 38–46 and the `spec '>= CAP'` block) and keep only the design-row assertions + README assertions + the routing-test token check. Replace lines 38–46 (the spec `< CAP` count + spec `>= CAP` blocks) with:
```bash
# v0.12.0: spec-mode rows removed — only design rows carry the cap now.
grep -qE "\*\*design\*\*.*\| < $CAP \|" "$SKILL" \
  && note PASS "SKILL.md routing: design '< $CAP' row" \
  || note FAIL "SKILL.md routing: design '< $CAP' row missing"
```
(Keep the existing `design '>= CAP'` block, README ASCII flow, README AP16, and routing-test token blocks unchanged.)

Note: the SKILL.md source-of-truth line `**Hard cap**: \`rereview_count >= 5\`` must remain in the `### Re-review cap` section you kept in Step 5 — verify it's still there.

- [ ] **Step 9: Run the design-only + cap-consistency + routing tests**

Run:
```bash
bash plugins/spec-distill/tests/test_reviewing_spec_design_only.sh
bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh
bash plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh
```
Expected: all three `Fail: 0`. If `test_rereview_cap_consistency.sh` reports the source-of-truth pattern not found, re-check that the `**Hard cap**: \`rereview_count >= 5\`` line survived Step 5.

- [ ] **Step 10: Commit**

```bash
git add -A plugins/spec-distill/skills/reviewing-spec/SKILL.md \
        plugins/spec-distill/tests/test_reviewing_spec_design_only.sh \
        plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh \
        plugins/spec-distill/tests/test_rereview_cap_consistency.sh
git commit -m "refactor(spec-distill): remove drafting-spec, simplify reviewing-spec to design-only (G6/AC10/V8)"
```

---

## Task 9: `spec-reviewer.md` persona refresh (C3, NG3)

Update the security-sensitive reviewer persona's description to drop the `drafting-spec` reference and clarify that the interview *brief* is **not** its target (NG3 — brief uses the Law 1 gate, only the design doc gets Law 2 review). Keep both mode branches and all categories intact (do not weaken — C3).

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md`

- [ ] **Step 1: Update the description frontmatter**

Replace the `description:` block (lines 16–26) with:
```markdown
description: >
  Use this agent to adversarially review a brainstorming design doc
  (docs/superpowers/specs/...-design.md) in the spec-distill flow. Hunts for
  unstated assumptions, placeholder/ambiguity, weak component isolation, missing
  approaches comparison, untestable verification, and handoff-incompleteness.
  Output: Status / Issues / Recommendations / Stagnation_signal (superpowers
  plan-document-reviewer format). Physically blocked from editing files (Law 2
  frontmatter scoping). NOTE: the interview brief (docs/superpowers/interview/)
  is NOT this agent's target — the brief is gated by the Law 1 5-ritual structural
  check (check_brief.py), not separated review (NG3). This agent reviews the
  design doc only.

  <example>Context: brainstorming just produced a -design.md.
  user: "이 design doc 검토해줘"
  assistant: "I'll dispatch the spec-reviewer agent to adversarially review the design doc."</example>
```

- [ ] **Step 2: Update the title line reference**

Replace line 31's "drafting-spec skill" reference:
```markdown
당신은 spec-distill 플러그인의 spec-reviewer 입니다. 사용자의 인터뷰 결과로 작성된 spec.md draft를 *공격적으로* (adversarially) 리뷰하여 ...
```
with:
```markdown
당신은 spec-distill 플러그인의 spec-reviewer 입니다. brainstorming이 산출한 design doc(또는 드물게 잔존하는 spec 파일)을 *공격적으로* (adversarially) 리뷰하여 unstated assumption, 누락 섹션, untestable AC, concrete-next-action 부재를 찾아냅니다. **interview brief는 검토 대상이 아닙니다**(NG3 — Law 1 check_brief.py 게이트가 담당).
```

- [ ] **Step 3: Verify no regression in reviewer checklist tests**

Run:
```bash
bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh
bash plugins/spec-distill/tests/test_handoff_design_mode.sh
```
Expected: both `Fail: 0` (the 6 design categories + handoff_incomplete + 11-section regression text all preserved — only the description and one prose line changed).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md
git commit -m "docs(spec-distill): refresh spec-reviewer persona for design-only flow (C3/NG3)"
```

---

## Task 10: Prove Law 2 design-doc detection survives + `interview/` auto-exclusion (AC9, V7, C8)

The hook is unmodified, but its behavior is load-bearing: brainstorming's `-design.md` under `docs/superpowers/specs/` must still trigger design mode + a `pending_review` block (Law 2 review of the design doc — AC9), and the interview brief under `docs/superpowers/interview/` must be out-of-scope (C8). Extend the existing Python hook test to lock both in as regressions.

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: Add a test class — write it first (it asserts the unmodified hook's contract)**

Append this class to `tests/test_hook_output_schema.py` (after the existing classes, before the `if __name__ == "__main__"` block). It reuses the file's `_make_temp_repo`, `_run_hook`, and the `subprocess`/`json` imports already present:
```python
class TestInterviewDirectionLayerHook(unittest.TestCase):
    """AC9/V7/C8 — design-doc detection survives; interview/ is out of scope."""

    def setUp(self) -> None:
        self.repo = _make_temp_repo()

    def tearDown(self) -> None:
        shutil.rmtree(self.repo, ignore_errors=True)

    def _post_write(self, rel_path: str) -> subprocess.CompletedProcess:
        """Simulate a PostToolUse Write of a .md file at rel_path under the temp repo."""
        abs_path = self.repo / rel_path
        abs_path.parent.mkdir(parents=True, exist_ok=True)
        abs_path.write_text(
            "---\nname: x\n---\n\n# X\n\nsome design prose with clear components.\n",
            encoding="utf-8",
        )
        return _run_hook(
            "spec-write-validator.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": "hooktestsession"},
            stdin_payload={
                "tool_name": "Write",
                "tool_input": {"file_path": str(abs_path)},
                "session_id": "hooktestsession",
            },
        )

    def test_design_doc_under_specs_triggers_design_mode(self) -> None:
        """AC9: -design.md under specs/ → design mode + pending_review block."""
        cp = self._post_write(
            "docs/superpowers/specs/2026-05-31-interview-direction-layer-design.md"
        )
        self.assertEqual(cp.returncode, 0, cp.stderr)
        out = json.loads(cp.stdout)
        self.assertIn("design", out["hookSpecificOutput"]["additionalContext"])
        state = (
            self.repo / ".claude" / "spec-distill" / "hooktestsession" / "state.local.md"
        )
        self.assertTrue(state.exists(), "pending_review state not written")
        body = state.read_text(encoding="utf-8")
        self.assertIn("pending_review:", body)
        self.assertIn("mode: design", body)

    def test_interview_brief_path_is_out_of_scope(self) -> None:
        """C8: docs/superpowers/interview/ is outside PATH_PREFIX → no review gate."""
        cp = self._post_write(
            "docs/superpowers/interview/2026-05-31-sample-topic-interview.md"
        )
        self.assertEqual(cp.returncode, 0, cp.stderr)
        # Out of scope → hook exits 0 silently, no additionalContext, no state written.
        self.assertEqual(cp.stdout.strip(), "", "interview/ path should produce no output")
        state = (
            self.repo / ".claude" / "spec-distill" / "hooktestsession" / "state.local.md"
        )
        self.assertFalse(state.exists(), "interview/ path must not write pending_review")
```

- [ ] **Step 2: Run the extended test**

Run: `python3 plugins/spec-distill/tests/test_hook_output_schema.py`
Expected: OK (all existing tests + the 2 new methods pass). If `_run_hook`'s signature differs from the call above (verify against the file's definition at lines 70–80), adjust the keyword arguments to match — `hook_relpath`, `cwd`, `env_extra`, `stdin_payload` are the documented params.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): lock design-doc detection + interview/ exclusion (AC9/V7/C8)"
```

---

## Task 11: README + CHANGELOG + plugin.json bump (C6, AC11, AC12)

Version bump + changelog + README sync, all in one PR (C6, [[feedback_plugin_version_bump]]).

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Create: `plugins/spec-distill/tests/test_readme_sync.sh`

- [ ] **Step 1: Write the failing README-sync test**

`tests/test_readme_sync.sh`:
```bash
#!/usr/bin/env bash
# AC12 — README synced with v0.12.0 interview flow.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC11: version bump + changelog entry
grep -q '"version": "0.12.0"' "$PLUGIN_JSON" \
  && note PASS "AC11: plugin.json version 0.12.0" || note FAIL "AC11: plugin.json not 0.12.0"
grep -qE '^## \[0\.12\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.12.0] entry with ISO date" || note FAIL "AC11: CHANGELOG [0.12.0] missing/!ISO"
grep -qE '^## \[0\.12\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC11: CHANGELOG date has XX placeholder" || note PASS "AC11: no XX placeholder in date"

# AC12: README keyword sync
for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'interview-brief' 'steelman-builder'; do
  grep -q "$kw" "$README" \
    && note PASS "AC12: README mentions $kw" || note FAIL "AC12: README missing $kw"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: FAIL (version still 0.11.3; keywords absent).

- [ ] **Step 3: Bump `plugin.json`**

In `plugins/spec-distill/.claude-plugin/plugin.json`, change `"version": "0.11.3"` to `"version": "0.12.0"` and update the `description` to reflect the new role:
```json
  "description": "A strong problem-space interview stage (meta-prompting + bounded web research + adversarial steelman) that produces a superpowers-brainstorming-ready interview brief; design docs reviewed by a physically-separated Law 2 reviewer. A devbrew Laws 1+2 instantiation.",
```

- [ ] **Step 4: Add the CHANGELOG entry**

Insert at the top of `plugins/spec-distill/CHANGELOG.md` (after the `# Changelog` line, before `## [0.11.3]`). Use today's date `2026-05-31`; **confirm it equals the merge date at PR time** (AC11 — no `XX` placeholder):
```markdown
## [0.12.0] — 2026-05-31

### Added
- `scripts/web_budget.py` — interview web-research budget enforcer (per-sweep ≤4 / per-session ≤8, state-file counters). Kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` short-circuits to ok (graceful degradation). (AC7/AC8/PN3)
- `scripts/check_brief.py` — interview-brief structural gate (7 sections / landscape citations / steelman-log well-formedness / tried-&-discarded). The Law 1 5-ritual termination gate, made mechanical. (AC2/AC4/AC5)
- `agents/steelman-builder.md` — scoped read-only adversarial counter-case builder (`disallowedTools: Write/Edit/MultiEdit/NotebookEdit`; `allowedTools` include WebSearch/WebFetch). Security-sensitive persona. (AC5/AC6)
- `templates/interview-brief-template.md` — canonical 7-section meta-prompt format. (AC1)
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` kill switch — disables interview web research, landscape skipped with loud log.
- Tests: `test_web_sweep_bound.sh`, `test_check_brief.sh`, `test_steelman_builder_scope.sh`, `test_conducting_interview_stage.sh`, `test_reviewing_spec_design_only.sh`, `test_readme_sync.sh` + brief/state fixtures; `test_hook_output_schema.py` design-doc + interview/-exclusion regression.

### Changed
- `skills/conducting-interview/SKILL.md` — re-positioned as a strong problem-space stage (Double Diamond 1st diamond): 5 통과 의례 (R1 Reframe / R2 Landscape / R3 Skepticism / R4 Tried-&-Discarded / R5 Open-Questions) as a Law 1 structural gate; web path(a) expansion; steelman gate; terminal interview-brief output at `docs/superpowers/interview/`; optional `superpowers:brainstorming` handoff. `cost_class: medium → variable`. State writes via Bash (worktree-safe — PN1).
- `commands/interview.md` — role reframed to problem-space stage (trivia escape unchanged, NG6).
- `skills/reviewing-spec/SKILL.md` — **design-mode only**: spec-mode routing rows + `[3.5]` re-consensus gate + `mode_b_violation` handling + `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` removed (dead paths after drafting-spec removal). Design-doc review + Phase 5 proceed gate unchanged (Law 2 intact).
- `agents/spec-reviewer.md` — description/role refreshed for the design-only flow; clarified the interview brief is NOT its target (NG3). Mode branches + categories unchanged (C3 — not weakened).

### Removed
- `skills/drafting-spec/` (Mode A + Mode B) — the interview now produces a self-complete brief and brainstorming writes the design doc; design revisions are author-regression edits by the main agent, so the spec-writer skill is obsolete. (decision #10)
- Tests/fixtures for removed paths: `run-fixture-ac1.sh`, `interview-transcript-bbda.md`, `mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md`.

### Notes
- superpowers (`brainstorming`/`writing-plans`) remains an optional external plugin. With it absent, `/interview` completes at the brief and logs a loud advisory — no crash, no spec-mode fallback (AC13).
- Hooks are unchanged: `spec-write-validator.py` already classifies `-design.md` under `docs/superpowers/specs/` as design mode and auto-excludes `docs/superpowers/interview/` (outside `PATH_PREFIX`, C8).
```

- [ ] **Step 5: Sync the README**

Make these edits to `plugins/spec-distill/README.md`:

(a) Replace the top tagline (line 3):
```markdown
> 강한 문제공간 인터뷰(메타프롬프팅 + 웹 리서치 + adversarial steelman)로 방향을 끌어내 superpowers brainstorming용 interview brief를 생성하고, design doc은 물리 분리된 Law 2 reviewer가 검증하는 devbrew-native 플러그인.
```

(b) Replace "What it does" (lines 5–7) to describe the brief output:
```markdown
## What it does

`/interview <rough request>` 호출 시 4-block Korean Socratic 인터뷰가 **강한 문제공간 stage**로
동작합니다: 요청을 재구성(메타프롬프팅)하고, 외부 사례를 웹으로 조사하고(bounded), 약한 방향을
steelman으로 깨뜨려, **interview brief**(brainstorming용 meta-prompt)를
`docs/superpowers/interview/YYYY-MM-DD-<topic>-interview.md`에 산출합니다. 5 통과 의례(R1–R5)가
Law 1 구조 게이트입니다. brief는 단독 완결 산출물이며, superpowers가 있으면 brainstorming
해답공간으로(optional), design doc은 물리 분리된 reviewer가 Law 2로 검증합니다.
```

(c) Replace the "Flow" ASCII block (lines 19–41) with the v0.12.0 flow:
```markdown
## Flow (v0.12.0)

```
/interview ─→ [0] Trivia escape ─→ [1] Interview (문제공간 stage)
                                       · 4-block Socratic + 4-path (web=path(a))
                                       · R1 Reframe / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ
                                       ▼ 5 의례 통과 (check_brief.py gate, Law 1)
                                   interview brief → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ (optional — superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
                                       ▼ [PostToolUse: design mode → pending_review]  (기존 hook)
                                       ▼ brainstorming user-review 정지 → 턴 경계
                                       ▼ [Stop: review-dispatch]  (기존 hook)
                                   [3] reviewing-spec → spec-reviewer (Law 2, design-mode only)
                                       ├─ approved → [5] proceed 게이트 → auto re-review, max 5 → writing-plans
                                       └─ needs_revise → brainstorming author 회귀 → 재검증
```

**v0.12.0**: drafting-spec 제거 + reviewing-spec design-mode 전용. interview는 brief까지 단독 완결.
```

(d) In "Principles Instantiated", add to the Law-1 area a bullet (after the existing Law 1 line):
```markdown
- **Law 1 (Clarity) — 문제공간 게이트 (v0.12.0)** — interview의 5 통과 의례(R1–R5)가 `check_brief.py`로 기계 검증되는 구조 게이트. 약한 방향(무인용 landscape·un-challenged 의심·빈 시행착오)은 brief 종료를 차단.
```
And in "Anti-pattern 회피", update the AP14 line:
```markdown
- **AP14 (Unchallenged consensus)** — sub-agent reviewer adversarial review + **`steelman-builder` 의심 게이트(v0.12.0)**: 의심 방향은 웹근거 기반 대안 steelman을 통과해야 lock.
```

(e) In "Kill switches", add:
```markdown
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` (v0.12.0) — interview 웹 리서치 비활성화. landscape를 loud log와 함께 생략, crash 없음 (graceful degradation, AC8).
```

(f) In "Prerequisites", update the superpowers line:
```markdown
- **superpowers** (외부, optional) — 있으면 brief를 `brainstorming` 해답공간으로 넘기고 `writing-plans`로 이어집니다. 없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
```

- [ ] **Step 6: Run the README-sync test + the cap-consistency test (README flow changed)**

Run:
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh
bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh
```
Expected: `test_readme_sync.sh` all green. `test_rereview_cap_consistency.sh` must still pass — it greps README for `auto re-review, max 5` and `re-review max 5`; **verify the new Flow block contains `auto re-review, max 5`** (it does, in edit (c)) and the AP16 line still says `re-review max 5`. If the AP16 README line was not touched, it's intact; if the flow edit dropped the token, re-add `auto re-review, max 5` to the approved→ branch.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md \
        plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "docs(spec-distill): bump 0.12.0, sync README/CHANGELOG (C6/AC11/AC12)"
```

---

## Task 12: Full-suite regression + V10 manual e2e checklist (V9, V10)

Confirm no regression against the Task 1 baseline and document the manual end-to-end check (the live interview cannot be automated — V10).

**Files:** none (verification + documentation).

- [ ] **Step 1: Run the entire suite from repo root**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-direction-layer
pass=0; failed=""
for t in plugins/spec-distill/tests/*.sh; do
  bash "$t" >/dev/null 2>&1 && pass=$((pass+1)) || failed="$failed $(basename "$t")"
done
echo "bash: PASS=$pass FAIL:${failed:- none}"
for p in test_hook_output_schema test_gc test_session_end_cleanup; do
  python3 "plugins/spec-distill/tests/$p.py" >/dev/null 2>&1 && echo "py PASS $p" || echo "py FAIL $p"
done
```
Expected: **FAIL: none** and all `py PASS`. Net test-file delta vs baseline: removed `run-fixture-ac1.sh` (−1); added `test_web_sweep_bound.sh`, `test_check_brief.sh`, `test_steelman_builder_scope.sh`, `test_conducting_interview_stage.sh`, `test_reviewing_spec_design_only.sh`, `test_readme_sync.sh` (+6) → bash suite `PASS=31`. If any pre-existing test is now red, fix it before proceeding — V9 requires no regression.

- [ ] **Step 2: Confirm AC10 grep (drafting-spec fully gone from skills/hooks/commands)**

Run:
```bash
grep -rl 'drafting-spec' plugins/spec-distill/skills plugins/spec-distill/hooks plugins/spec-distill/commands 2>/dev/null | wc -l
```
Expected: `0`.

- [ ] **Step 3: V10 manual e2e checklist (document the outcome; do not skip silently)**

Run an actual `/interview <a real rough request>` end-to-end and verify by hand (the parts the mechanical gates cannot judge):
- [ ] R2: a web landscape sweep actually ran and surfaced ≥1 cited prior-art entry (or — if `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`/no web tools — the loud landscape-skip advisory printed; no crash).
- [ ] R3: at least one suspect direction triggered a `steelman-builder` dispatch, and the Skepticism Log entry contains a **genuine counter-argument** (not an empty/formal placeholder) — this is the V3-structural-vs-quality gap (G4 直結).
- [ ] brief: `docs/superpowers/interview/<date>-<topic>-interview.md` was created and `python3 scripts/check_brief.py gate <brief>` exits 0.
- [ ] handoff: with superpowers present, `brainstorming` was invoked with the brief as context; the resulting `-design.md` write triggered the design-mode `pending_review` + reviewer dispatch (AC9).
- [ ] AC13: with superpowers absent (temporarily simulate), `/interview` stopped at the brief with the loud advisory — no spec-mode fallback, no crash.

Record the result (pass/fail per item) in the PR description. If the steelman-quality item fails, that is a `steelman-builder` persona/prompt fix (Law 3 compounding — edit the persona, not just the symptom), and per the model-decision note in Task 5, consider escalating the agent model.

- [ ] **Step 4: Final state — branch ready for PR**

Run:
```bash
git status --short        # expect: clean
git log --oneline main..HEAD   # review the 10 task commits
```
Then open the PR per `docs/git-workflow/pr-process.md` (merge commit; SemVer bump present; CHANGELOG dated to the merge day). Do not merge without user direction.

---

## Self-Review

**1. Spec coverage (every AC / V / PN → a task):**

| Spec item | Task(s) |
|---|---|
| AC1 brief frontmatter | T3 (template) + T4 (check_brief frontmatter) + T6 (write) |
| AC2 7 sections, termination block | T4 (gate) + T6 |
| AC3 5 의례 미충족 차단 | T4 (gate, blocking) + T6 (calls gate) |
| AC4 landscape URLs | T4 (landscape-citations) |
| AC5 steelman verbatim + Skepticism Log | T4 (skepticism) + T5 (agent verbatim contract) + T6 (verbatim dispatch) |
| AC6 steelman-builder disallowedTools | T5 |
| AC7 web bound ≤4/≤8 (+ PN3 counter) | T2 |
| AC8 web kill switch graceful | T2 + T6 |
| AC9 hook design-mode survives | T10 |
| AC10 drafting-spec removed (grep=0) | T8 + T12 confirm |
| AC11 plugin.json 0.12.0 + CHANGELOG | T11 |
| AC12 README sync | T11 |
| AC13 superpowers-absent graceful | T6 + T12 manual |
| V1–V10 | T4/T6, T4, T4, T5, T2, T4, T10, T8, T1+T12, T12 |
| PN1 worktree state write | T6 (Bash contract) |
| PN2 design-only test script | T8 (test_reviewing_spec_design_only.sh) |
| PN3 web counter unit | T2 (state-file counters) |
| PN4 verbatim diff criterion | T4 (substring containment, documented) |

No gaps. G1–G7 are realized across T6 (G1/G2/G3/G4/G5/G7), T8 (G6), T5/T2 (G3/G4 mechanics).

**2. Placeholder scan:** No "TBD/TODO/handle edge cases" steps — every code step shows complete code; every test step shows the full test; the one date value (CHANGELOG `2026-05-31`) is concrete with an explicit "confirm = merge date" instruction (AC11 forbids `XX`, which the test enforces). check_brief.py / web_budget.py / steelman-builder / template are full artifacts, not sketches.

**3. Type/name consistency:** Counters `web_sweep_count` / `web_search_count` are used identically in T2 (web_budget.py reader + fixtures), T6 (SKILL.md schema + R2 increment) — matched. `check_brief.py` subcommands (`gate`, `sections`, `landscape-citations`, `skepticism`, `tried-discarded`, `frontmatter`) are defined in T4 and called in T6 (`gate`) and T4's test (`gate`, `skepticism`) — matched. Section titles in the template (T3) exactly match `SECTIONS` in check_brief.py (T4): `Reframed Problem / Locked Directions / External Landscape / Skepticism Log / Tried & Discarded / Open Questions / Concrete Next Action`. Agent subagent_type `spec-distill:steelman-builder` (T6 dispatch) matches `name: steelman-builder` (T5) under the plugin namespace. Brief path `docs/superpowers/interview/` consistent across T3/T6/T10/T11. Re-review cap source-of-truth token `count >?= ?5` preserved for the cross-file invariant (T8 Step 7 + T8 Step 8).

**Ordering safety:** T2–T5 (leaf artifacts, no deps) precede T6 (depends on all four). T6 removes the last `drafting-spec` reference in `skills/` so T8's AC10 grep can reach 0. T8's reviewing-spec edits keep the `**Hard cap**: rereview_count >= 5` source-of-truth line and the README `auto re-review, max 5` token alive so `test_rereview_cap_consistency.sh` stays green; T11's README flow rewrite re-asserts that token (verified in T11 Step 6). Baseline (T1) and final regression (T12) bracket the work per [[project_qg_pre_existing_test_reds]].
