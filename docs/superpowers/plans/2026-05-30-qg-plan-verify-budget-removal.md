# quality-gates v2.0.0 — Gate 1 (plan verify) 제거 + wall-clock budget 제거 + 비수치 gate 명명 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** quality-gates 파이프라인에서 Gate 1(plan-verifier agent)과 wall-clock budget 잔재를 제거하고, 남는 두 게이트를 비수치 이름(Review gate / Runtime gate)으로 전면 rename하여 v2.0.0로 올린다.

**Architecture:** 순수 제거 + rename 리팩터. 새 코드 거의 없음. plan-verifier agent와 그 behavior test를 삭제하고, SKILL.md·setup-qg.sh·README·philosophy 등 ~25개 파일에서 "Gate 1/2/3" 표시명·서브커맨드·env var·hook 키·내부 식별자(`max_gate2_iterations`, `gate3_max_resolutions`, `gate3-evidence.md` 등)를 비수치 식별자로 치환한다. `discover-plan.sh`는 byte-identical로 유지(Runtime gate의 test-scope-validator가 `plan_path:auto`로 소비). 검증은 기계적 grep sweep(AC) + 기존 테스트 스위트 green.

**Tech Stack:** Bash, Python 3 (stdlib only), Markdown. CI 없음 — 테스트는 repo root에서 `bash`/`python3`로 직접 실행.

---

## ⚠️ 시작 전 필독 — Spec과의 3가지 차이 (writing-plans 단계에서 실측·확정)

이 plan은 spec(`docs/superpowers/specs/2026-05-30-qg-plan-verify-budget-removal-design.md`)을 구현하되, 코드베이스 실측으로 발견한 3가지를 spec과 다르게 처리한다. 모두 **spec 의도를 보존**하며 검증 정확도를 높이는 보정이다.

1. **AC22 scope (사용자 확정 — "집중 scope").** `main`에 plan-verify/budget와 **무관한 9개 pre-existing red 테스트**가 있다(CI 부재로 미발견; v1.32.0 SKILL 리팩터 #71 + v1.27.0 `codex-reviewer.md` 삭제 잔재). spec AC22("전체 스위트 green")는 literal로는 main에서 이미 거짓이다. **사용자 결정: 집중 scope** — 8개 orthogonal stale red는 그대로 두고 baseline 문서화. **이 plan에서 AC22 재정의 = "내가 생성/수정/rename한 테스트는 green + 새 red 0개 + 9-red baseline이 8-red로 축소(test_skill_orchestration.sh가 green화)".** 8개 orthogonal red 목록은 Task 0에 박제.

2. **AC18 grep 오류 (보정).** spec AC18 `grep -cE "timeout.{0,4}5 codex --version"`는 unchanged `detect_codex.sh`에 대해서도 **0을 반환**한다(실제 probe는 `"$TIMEOUT_BIN" 5 codex --version` — `timeout`과 `5` 사이가 `_BIN" ` 6자 + 대소문자 불일치라 `.{0,4}`로 매칭 불가). spec 의도("5s probe 유지")는 명확하므로 **보정된 grep** `grep -cE '"\$TIMEOUT_BIN" 5 codex --version' detect_codex.sh ≥ 1`을 Task 14에서 사용. detect_codex.sh는 **무수정**.

3. **Spec Phase C 테스트 목록 부정확 (무시).** spec은 `test_codex_dispatch_invariant.sh`·`test_scout_codex_integration.sh`·`test_skill_codex_skip_prose.sh`에서 "600s ceiling·no_timeout_binary 단언 제거"를 지시하나, 실측 결과 이 3개 테스트에는 `600`/`no_timeout_binary` 단언이 **없다**(셋 다 codex 관련 orthogonal stale red). 유일한 `timeout 600` in tests는 `tests/spike/test_codex_json_extraction.sh`(spike 아티팩트, `/tests/`라 SRC_GREP 제외). 따라서 **이 3개 테스트는 건드리지 않는다**(집중 scope). 프로덕션 `timeout 600` 제거 대상은 `run_codex_reviewer.sh` 단 하나.

---

## 명명 맵 (Canonical — 모든 Task가 이 표를 단일 진실 소스로 사용)

타입 일관성(type-consistency)을 위해 **모든 rename은 이 표를 따른다.** Task별로 재정의하지 말 것.

| 범주 | old | new |
|---|---|---|
| 표시명 | `Gate 1` / `Gate 1: Plan Verification` | *(제거)* |
| 표시명 | `Gate 2` / `Gate 2: PR Review` | **Review gate** |
| 표시명 | `Gate 3` / `Gate 3: Runtime Verification` | **Runtime gate** |
| 서브커맨드 | `/qg gate1` | *(제거)* |
| 서브커맨드 | `/qg gate2` | `/qg review` |
| 서브커맨드 | `/qg gate3` | `/qg runtime` |
| SKILL 섹션 | `## Gate 2 iter boundary decision` | `## Review iter boundary decision` |
| SKILL 섹션 | `## Gate 2 max-iter decision` | `## Review max-iter decision` |
| SKILL 섹션 | `## Gate 3 NEEDS_RESOLUTION decision` | `## Runtime NEEDS_RESOLUTION decision` |
| AskUserQuestion header 텍스트 | `Gate 2 iter N` | `Review iter N` |
| AskUserQuestion header 텍스트 | `Gate 2 max-iter` | `Review max-iter` |
| AskUserQuestion header 텍스트 | `Gate 3 resolve` | `Runtime resolve` |
| 라벨 텍스트 | `Proceed to Gate 3` | `Proceed to Runtime gate` |
| 내부 상수 | `max_gate2_iterations` | `max_review_iterations` |
| doc 상수명 | `MAX_GATE2_ITERATIONS` | `MAX_REVIEW_ITERATIONS` |
| state 필드 | `gate3_max_resolutions` | `runtime_max_resolutions` |
| bash 변수(setup-qg) | `gate3_max` | `runtime_max` |
| persona prose 변수 | `max_gate3_resolutions` | `runtime_max_resolutions` |
| env | `DEVBREW_GATE3_MAX_RESOLUTIONS` | `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` |
| env | `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION` |
| hook 키 | `quality-gates:gate3-test-scope` | `quality-gates:runtime-test-scope` |
| evidence 경로 | `gate3-evidence.md` | `runtime-evidence.md` |
| verdict 마커 | `gate3_fail` | `runtime_fail` |
| signal 마커 | `gate3_repeat_detected` | `runtime_repeat_detected` |
| synthesize heading | `## Gate 2 Findings (Synthesized)` | `## Review Findings (Synthesized)` |
| scout 입력 필드 | `gate1_verdict` | *(제거)* |
| codex plan handoff | `gate1_summary` | *(제거 — Gate 1 없으면 빈 plan context)* |

**검증 규칙:** rename 후 어떤 source 파일(plugins/quality-gates, `tests/`·`CHANGELOG.md` 제외)에도 `gate ?[123]`·`GATE_?[123]`·`gate1_summary`·`gate1_verdict`·`plan-verifier`·`wall-clock`·`wall_clock`·`timeout 600`이 남으면 안 된다. "Review gate iter"/"Runtime gate dispatch"처럼 `gate` 뒤에 숫자가 아닌 문자가 오는 것은 안전(`gate ?[123]` 미매칭).

---

## Task 0: Baseline 캡처 + 브랜치 확인

**Files:** (읽기 전용)

- [ ] **Step 1: 브랜치 확인**

이 작업은 spec이 커밋된 기존 feature 브랜치에서 계속한다.

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
git branch --show-current
git log --oneline -2
```
Expected: 브랜치 = `feature/qg-plan-budget-removal`, 최근 커밋에 spec 문서(`docs/superpowers/specs/2026-05-30-qg-plan-verify-budget-removal-design.md`)가 있음. 만약 `main`이면 `git checkout feature/qg-plan-budget-removal` (없으면 `git checkout -b feature/qg-plan-budget-removal`).

- [ ] **Step 2: 테스트 baseline 캡처 (반드시 repo root에서 실행)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $(basename $t)" || echo "FAIL $(basename $t)"
done | sort | tee /tmp/qg_v2_baseline.txt
```
Expected (이 9개가 pre-existing **RED**, 나머지 bash 테스트는 GREEN):
```
FAIL test_codex_backward_compat.sh
FAIL test_codex_dispatch_invariant.sh
FAIL test_codex_reviewer_frontmatter.sh
FAIL test_consent_marker_write_failure.sh
FAIL test_sandbox_enforced.sh
FAIL test_scout_codex_integration.sh
FAIL test_security_reviewer_kill_switch.sh
FAIL test_skill_codex_skip_prose.sh
FAIL test_skill_orchestration.sh
```
이 9개 = baseline red. 이 중 `test_skill_orchestration.sh`만 이 작업으로 green화될 것(Task 3). 나머지 8개는 codex/consent/security/sandbox 관련 orthogonal stale red — **이 작업의 scope 밖, 그대로 둔다**(집중 scope 결정). Task 14는 "최종 red 집합 = 이 8개 정확히, 그 외 새 red 0개"를 검증한다.

- [ ] **Step 3: Python 단위 테스트 baseline (fixtures 제외, 개별 실행)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/quality-gates/tests/test_*.py; do
  python3 "$t" >/dev/null 2>&1 && echo "PASS $(basename $t)" || echo "FAIL $(basename $t)"
done | tee -a /tmp/qg_v2_baseline.txt
```
Expected: 12개 모두 PASS (`test_plan_verifier_behavior.py` 포함 — Task 1에서 삭제 예정). `pytest tests/`로 디렉토리 통째 실행 **금지** — `tests/fixtures/test-scope/*/tests/*.py`는 test-scope-validator용 DIFF fixture라 `src.` import로 collection error 발생. 항상 개별 파일 `python3 <file>`로 실행.

이 Task는 커밋 없음 (읽기 전용 baseline).

---

## Task 1: plan-verifier agent + behavior test 삭제 (Phase A)

**Files:**
- Delete: `plugins/quality-gates/agents/plan-verifier.md`
- Delete: `plugins/quality-gates/tests/test_plan_verifier_behavior.py`

- [ ] **Step 1: 두 파일 삭제**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
git rm plugins/quality-gates/agents/plan-verifier.md \
       plugins/quality-gates/tests/test_plan_verifier_behavior.py
```

- [ ] **Step 2: 부재 확인**

Run:
```bash
test ! -f plugins/quality-gates/agents/plan-verifier.md && echo "AC1 agent gone OK"
test ! -f plugins/quality-gates/tests/test_plan_verifier_behavior.py && echo "AC2 test gone OK"
test -f plugins/quality-gates/scripts/discover-plan.sh && echo "discover-plan KEPT OK"
```
Expected: 세 줄 모두 출력. (`discover-plan.sh`는 **유지** — Runtime gate test-scope-validator가 소비.)

- [ ] **Step 3: discover-plan.sh가 gate 참조 없는지 확인 (무수정 보장)**

Run:
```bash
grep -niE "gate ?[123]|plan-verifier" plugins/quality-gates/scripts/discover-plan.sh || echo "discover-plan.sh clean (no edit needed)"
```
Expected: `discover-plan.sh clean` — 이 스크립트는 이미 "Gate 1" 참조가 없으므로 **byte-identical 유지**. (Gate 1 프레이밍은 README에만 존재 → Task 11에서 reframe.)

- [ ] **Step 4: discover-plan 테스트 무수정 green (AC2)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_discover_plan.sh && echo "AC2 discover-plan green OK"
```
Expected: PASS — discover-plan.sh stdout 출력 계약(`plan_path:` 절대경로) 불변의 기계적 보장.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(quality-gates)!: remove plan-verifier agent (Gate 1) — v2.0.0 prep

Gate 1 plan verification은 상류 superpowers:writing-plans / spec-distill가
담당하는 중복 단계. discover-plan.sh는 Runtime gate test-scope-validator가
plan_path:auto로 소비하므로 유지.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: scout.py — gate1_verdict 입력 필드 제거 (Phase A)

**Files:**
- Modify: `plugins/quality-gates/scripts/scout.py:9-25` (docstring), `:36` (g1 읽기), `:39-41` (NEEDS_CLARIFICATION 분기)
- Test: `plugins/quality-gates/tests/test_scout_script.sh` (수정 불필요 — 5 케이스 모두 gate1_verdict 미사용; green 확인만)

- [ ] **Step 1: docstring에서 gate1_verdict 입력 줄 제거**

`scout.py`의 input 스키마 docstring에서 `gate1_verdict` 줄을 제거한다.

기존 (lines 9-17):
```python
Input (stdin JSON):
  {
    "changed_lines": int,
    "new_files": int,
    "config_touched": bool,
    "type_design": bool,
    "test_change": bool,
    "gate1_verdict": "PASS"|"FAIL"|"NEEDS_CLARIFICATION"|""
  }
```
변경 후 (마지막 필드의 trailing comma 정리):
```python
Input (stdin JSON):
  {
    "changed_lines": int,
    "new_files": int,
    "config_touched": bool,
    "type_design": bool,
    "test_change": bool
  }
```

- [ ] **Step 2: decide()에서 g1 읽기 + NEEDS_CLARIFICATION 분기 제거**

기존 (lines 30-50, decide 함수 도입부):
```python
def decide(s):
    changed = int(s.get("changed_lines", 0))
    new_files = int(s.get("new_files", 0))
    config = bool(s.get("config_touched", False))
    type_design = bool(s.get("type_design", False))
    test_change = bool(s.get("test_change", False))
    g1 = s.get("gate1_verdict", "")

    # Depth decision (v1.x scout.md L42-44)
    if g1 == "NEEDS_CLARIFICATION":
        depth = "deep"
        rationale = "Gate 1 NEEDS_CLARIFICATION — scope itself uncertain."
    elif changed >= 200 or new_files >= 1 or config or type_design:
        depth = "deep"
        rationale = "Large or structural change — deep review warranted."
    elif changed >= 50:
        depth = "standard"
        rationale = "Mid-size change — standard depth."
    else:
        depth = "quick"
        rationale = "Small focused change — quick review."
```
변경 후 (`g1` 변수 + 첫 `if` 분기 삭제, `elif` → `if`):
```python
def decide(s):
    changed = int(s.get("changed_lines", 0))
    new_files = int(s.get("new_files", 0))
    config = bool(s.get("config_touched", False))
    type_design = bool(s.get("type_design", False))
    test_change = bool(s.get("test_change", False))

    # Depth decision (v1.x scout.md L42-44)
    if changed >= 200 or new_files >= 1 or config or type_design:
        depth = "deep"
        rationale = "Large or structural change — deep review warranted."
    elif changed >= 50:
        depth = "standard"
        rationale = "Mid-size change — standard depth."
    else:
        depth = "quick"
        rationale = "Small focused change — quick review."
```

- [ ] **Step 3: scout.py에 gate 참조 잔존 없음 확인 (AC6)**

Run:
```bash
grep -niE "gate ?1|gate1_verdict|NEEDS_CLARIFICATION" plugins/quality-gates/scripts/scout.py || echo "AC6 scout.py clean OK"
```
Expected: `AC6 scout.py clean OK`.

- [ ] **Step 4: scout 테스트 green (repo root)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_scout_script.sh && echo "scout test green OK"
```
Expected: `Total: 5, PASS=5, FAIL=0` — 5 케이스 모두 gate1_verdict 미사용이므로 분기 제거 후에도 동일 결과.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/scout.py
git commit -m "refactor(quality-gates): drop gate1_verdict from scout depth decision

Gate 1 제거로 scout 입력에 plan verdict가 더 이상 없음. NEEDS_CLARIFICATION→deep
분기 제거; 크기/구조 기반 depth 결정만 잔존.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: SKILL.md 재작성 + orchestration 테스트 갱신 (Phase A+B+C 일부)

가장 큰 Task. SKILL.md에서 Gate 1 섹션 2개를 삭제하고, Gate 2/3 → Review/Runtime rename, 내부 식별자 rename, frontmatter 주석 reframe, Dispatch Loop·Final Summary·Contents·TOC 갱신. 그리고 coupled 테스트 2개 갱신.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (다수 구간)
- Modify: `plugins/quality-gates/tests/test_skill_orchestration.sh`
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`

- [ ] **Step 1: frontmatter 주석 reframe (lines 17, 21)**

```
# Group 2 — Gate 2 PR review scripts
```
→
```
# Group 2 — Review gate scripts
```
그리고
```
# Group 3 — Gate 3 runtime verification scripts
```
→
```
# Group 3 — Runtime gate scripts
```
(allowed-tools 배열 자체·도구 순서는 불변 — `check-allowed-tools-order.sh` 린터는 `EXPECTED_ORDER` 배열을 단일 소스로 쓰므로 주석 텍스트 변경은 무해. Step 12에서 린터 green 확인.)

- [ ] **Step 2: description + 본문 도입부 (lines 1-11, 36-43) gate 표현 갱신**

frontmatter `description:` (lines 6-9) 중:
```
  three gates (plan verification, PR review, runtime verification)
```
→
```
  two gates (review, runtime verification)
```
본문 제목 (line 36) `# Quality Gates — In-Turn Orchestrator (v1.32.0)` → `# Quality Gates — In-Turn Orchestrator (v2.0.0)`.
도입부 (lines 38-43):
```
turn. You dispatch the three gates serially in order. At decision points
(plan-verification failure, review-iter boundary, runtime needs-resolve) you call
```
→
```
turn. You dispatch the two gates serially in order. At decision points
(review-iter boundary, runtime needs-resolve) you call
```
Law 2 단락 (line 49) `"Retry" path on the review gate` → 그대로 유지(이미 "review gate" 표현).

- [ ] **Step 3: Contents 섹션 (lines 56-77) 2-gate로 갱신**

기존 Contents 블록(lines 60-77)을 아래로 교체:
```markdown
1. **Workflow (top-to-bottom on invocation):**
   - [Preflight](#preflight) — kill switch / setup-qg / pre-pipeline-check
   - [Arguments](#arguments) — `/qg` flags 파싱
   - [Dispatch Loop](#dispatch-loop) — two gates serialized in order with per-gate iteration
2. **Per-gate dispatch logic:**
   - [Trivia escape](#trivia-escape) — one-sentence diff → all gates skipped
   - [Review gate](#review-gate) — scout + Phase 1 + adversarial + synthesizer; iter loop with decision tool at every boundary
   - [Runtime gate](#runtime-gate) — test-scope-validator + runtime-verifier
3. **Decision points (AskUserQuestion templates):**
   - [Review iter boundary decision](#review-iter-boundary-decision)
   - [Review max-iter decision](#review-max-iter-decision)
   - [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision)
4. **Output templates** (verbatim, field substitution):
   - Review / Runtime result templates
   - Final summary template
   - [Rules](#rules) — Law 2 invariants, state file invariants
```

- [ ] **Step 4: Preflight 마지막 줄 (line 120) gate 참조**

```
Do NOT proceed to Gate 1 with degraded state.
```
→
```
Do NOT proceed to the Review gate with degraded state.
```

- [ ] **Step 5: Arguments 섹션 (lines 137-146) 갱신**

기존:
```markdown
Parse from `/qg` invocation:
- `gate` (optional): `gate1`, `gate2`, `gate3`, or absent (full pipeline).
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
- `pr_url` (optional).
- `skip_runtime` (flag): if set, skip Gate 3.
- `paths` (optional, repeatable): scope override for Gate 2 diff.

Single-gate mode (`gate1`/`gate2`/`gate3`) runs ONLY the named gate and
emits its verdict directly — no decision-tool call, no inter-gate
transition.
```
변경 후:
```markdown
Parse from `/qg` invocation:
- `gate` (optional): `review`, `runtime`, or absent (full pipeline).
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
  Consumed only by the Runtime gate's test-scope-validator (no Gate-1 verifier).
- `pr_url` (optional).
- `skip_runtime` (flag): if set, skip the Runtime gate.
- `paths` (optional, repeatable): scope override for the Review gate diff.

Single-gate mode (`review`/`runtime`) runs ONLY the named gate and
emits its verdict directly — no decision-tool call, no inter-gate
transition.
```

- [ ] **Step 6: Dispatch Loop (lines 148-169) — Gate 1 단계 삭제 + renumber**

기존 Dispatch Loop 본문(lines 150-169)을 아래로 교체:
```markdown
Full pipeline mode:

1. Run [Trivia escape](#trivia-escape). If trivia detected, print "Trivia
   diff — all gates skipped" and return.
2. Run [Review gate](#review-gate). Iterate (review → fix?) up
   to 5 times. At the end of EACH iteration:
   - findings empty → print "Review gate iter N: clean" and continue to the Runtime gate.
   - findings non-empty → invoke [Review iter boundary decision](#review-iter-boundary-decision).
3. If `skip_runtime`, skip the Runtime gate and emit final summary.
4. Otherwise run [Runtime gate](#runtime-gate).
   - On clean verdict → continue to final summary.
   - On failure → final summary with Runtime gate failure marker; do not auto-restart.
   - On needs-resolution → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision)
     up to `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` times (default 3, env override,
     clamp 0..10).
5. Emit final summary.
```

- [ ] **Step 7: Trivia escape 마지막 줄 (line 176) gate 참조**

```
- 1 = non-trivia → proceed to Gate 1.
```
→
```
- 1 = non-trivia → proceed to the Review gate.
```

- [ ] **Step 8: Gate 1 섹션 2개 통째 삭제 (lines 180-249)**

`## Gate 1: Plan Verification` 섹션 시작(line 180)부터 `## Gate 1 FAIL decision` 섹션 끝(line 249, "to avoid loops).")까지 **전부 삭제**. 즉 line 180~249 제거 → 다음 줄은 `## Gate 2: PR Review`(현 line 251)가 와야 함. (삭제 대상: "## Gate 1: Plan Verification" 본문 + `---` 구분선 + 설명 단락 + "## Gate 1 FAIL decision" 본문 + AskUserQuestion 템플릿 + branch 설명.)

- [ ] **Step 9: Review gate 섹션 (구 Gate 2, lines 251-348) rename**

- `## Gate 2: PR Review` → `## Review gate`
- `Iterative fix-loop, \`max_gate2_iterations = 5\` (hard-coded constant).` → `Iterative fix-loop, \`max_review_iterations = 5\` (hard-coded constant).`
- `description: "Security review (Gate 2 iter N)",` → `description: "Security review (Review gate iter N)",`
- `description: "Adversarial review of Phase-1 findings (Gate 2 iter N)",` → `description: "Adversarial review of Phase-1 findings (Review gate iter N)",`
- `- findings empty → print \`## Gate 2 iter N: clean\` and exit the loop (continue to Gate 3).` → `- findings empty → print \`## Review gate iter N: clean\` and exit the loop (continue to the Runtime gate).`
- `findings non-empty → invoke [Gate 2 iter boundary decision](#gate-2-iter-boundary-decision).` → `findings non-empty → invoke [Review iter boundary decision](#review-iter-boundary-decision).`
- `If iteration N=5 ends with findings still non-empty: invoke [Gate 2 max-iter decision](#gate-2-max-iter-decision) instead of the` → `... invoke [Review max-iter decision](#review-max-iter-decision) instead of the`
- `template (iter-boundary) and on the iteration-5` 단락의 `This phrase is Gate 2-iter-specific` → `This phrase is Review-iter-specific`

- [ ] **Step 10: Review 결정 템플릿 2개 (lines 312-431) rename**

`## Gate 2 iter boundary decision` → `## Review iter boundary decision`. 그 안:
- spec anchor 주석 `This phrase is Gate 2-iter-specific` → `This phrase is Review-iter-specific`
- `question: "Gate 2 iter N: findings remain (<summary>). What next?",` → `question: "Review gate iter N: findings remain (<summary>). What next?",`
- `header: "Gate 2 iter N",` → `header: "Review iter N",`
- 라벨 `{label: "Proceed to Gate 3",  description: "Accept current findings as-is and continue to runtime verification."},` → `{label: "Proceed to Runtime gate",  description: "Accept current findings as-is and continue to runtime verification."},`
- branch 설명: `loop back to step 1 of the Gate 2 section.` → `loop back to step 1 of the Review gate section.`; `**Proceed to Gate 3** → exit the loop, continue to Gate 3 with current` → `**Proceed to Runtime gate** → exit the loop, continue to the Runtime gate with current`; `**Stop** → emit final summary marked aborted at Gate 2.` → `... aborted at the Review gate.`
- "Retry: error handling" 블록(lines 369-392) 중 `surface as failure to the Gate 2 verdict.` → `surface as failure to the Review gate verdict.`

`## Gate 2 max-iter decision` → `## Review max-iter decision`. 그 안:
- `question: "Gate 2 reached max 5 iterations. Last findings: <summary>. Proceed to Gate 3 or stop?",` → `question: "Review gate reached max 5 iterations. Last findings: <summary>. Proceed to the Runtime gate or stop?",`
- `header: "Gate 2 max-iter",` → `header: "Review max-iter",`
- `{label: "Proceed to Gate 3", description: "Accept residual findings and continue."},` → `{label: "Proceed to Runtime gate", description: "Accept residual findings and continue."},`

- [ ] **Step 11: Runtime gate 섹션 (구 Gate 3, lines 436-529) rename**

- `## Gate 3: Runtime Verification` → `## Runtime gate`
- `If \`skip_runtime\` was set in arguments, skip this entire section.` (유지)
- `description: "Classify scope-relevant test files (Gate 3)",` → `description: "Classify scope-relevant test files (Runtime gate)",`
- `description: "Runtime verification (Gate 3)",` → `description: "Runtime verification (Runtime gate)",`
- `resolution_iter: <N (1..DEVBREW_GATE3_MAX_RESOLUTIONS)>"` → `resolution_iter: <N (1..DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)>"`
- Outcome routing:
  - `**Clean verdict** → print \`## Gate 3: Runtime Verification — clean\` and continue` → `**Clean verdict** → print \`## Runtime gate — clean\` and continue`
  - `**Failure verdict** → print full Gate 3 verdict block, then emit final summary marked Gate 3 failure.` → `... print full Runtime gate verdict block, then emit final summary marked Runtime gate failure.`
  - `**NEEDS_RESOLUTION** → invoke [Gate 3 NEEDS_RESOLUTION decision](#gate-3-needs_resolution-decision).` → `... invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision).`
- 설명 단락: `The NEEDS_RESOLUTION branch is the only Gate 3 outcome` → `... the only Runtime gate outcome`; `bounded by \`DEVBREW_GATE3_MAX_RESOLUTIONS\` so a` → `bounded by \`DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS\` so a`
- `## Gate 3 NEEDS_RESOLUTION decision` → `## Runtime NEEDS_RESOLUTION decision`. 그 안:
  - `Loop up to \`DEVBREW_GATE3_MAX_RESOLUTIONS\` times (default 3, env override` → `Loop up to \`DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS\` times (default 3, env override`
  - `header: "Gate 3 resolve",` → `header: "Runtime resolve",`
  - 라벨 `{label: "Yes, retry", description: "I've added the missing resource on disk. Re-run Gate 3."},` → `... Re-run the Runtime gate."},`
  - `{label: "Skip with evidence", description: "Mark Gate 3 SKIP_WITH_EVIDENCE with reason."},` → `... Mark the Runtime gate SKIP_WITH_EVIDENCE with reason."},`
  - `{label: "Stop", description: "Abort the pipeline at Gate 3."}` → `... at the Runtime gate."}`
  - branch: `**Stop** → final summary aborted at Gate 3.` → `... aborted at the Runtime gate.`
  - **주의:** "Runtime verifier needs" anchor 문구(`question:` 줄)는 **그대로 유지**(test_skill_orchestration.sh가 검증).

- [ ] **Step 12: Final Summary 템플릿 (lines 531-546) — Gate 1 줄 삭제 + rename**

기존:
```markdown
## Quality Gates Pipeline — Complete (v1.32.0)

- **Gate 1**: <clean|failed-continued|SKIP>
- **Gate 2**: <clean iter N | proceeded-with-findings iter N | aborted iter N | skipped>
- **Gate 3**: <clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>
```
변경 후:
```markdown
## Quality Gates Pipeline — Complete (v2.0.0)

- **Review gate**: <clean iter N | proceeded-with-findings iter N | aborted iter N | skipped>
- **Runtime gate**: <clean | failed | SKIP_WITH_EVIDENCE | aborted | skipped>
```

- [ ] **Step 13: Rules 섹션 (lines 548-569) gate 참조**

- `**R1 (Law 2 — physical):** ... The orchestrator may edit working-tree files for user-consented Gate 2 fixes only.` → `... for user-consented Review gate fixes only.`
- `**R4 (P21 secret policy):** ... For Gate 3 missing-credential resolution, ask` → `... For Runtime gate missing-credential resolution, ask`
- `**R5 (single dispatch per turn):** ... Do not re-dispatch the same Gate 2 reviewer for the same iteration.` → `... the same Review gate reviewer for the same iteration.`

- [ ] **Step 14: SKILL.md file-local gate sweep (0건)**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]|gate1_summary|gate1_verdict|plan-verifier" plugins/quality-gates/skills/quality-pipeline/SKILL.md || echo "SKILL.md gate-clean OK"
grep -cE "Dispatch Loop" plugins/quality-gates/skills/quality-pipeline/SKILL.md   # expect >=1
grep -ciE "Gate 1: Plan Verification|Gate 1 FAIL decision" plugins/quality-gates/skills/quality-pipeline/SKILL.md  # expect 0
grep -cE "findings remain|Runtime verifier needs" plugins/quality-gates/skills/quality-pipeline/SKILL.md  # expect >=2 (anchors kept)
```
Expected: `SKILL.md gate-clean OK`; Dispatch Loop ≥1; Gate-1 anchors = 0; anchors ≥2.

- [ ] **Step 15: test_skill_orchestration.sh 갱신**

V2a awk(line 28)를 Review/Runtime 순서로, V2b의 Gate-1-FAIL 체크 3줄 삭제 + "Proceed to Gate 3" 라벨 갱신.

헤더 주석(line 5) `V2a — AC5: Gate 1 → Gate 2 → Gate 3 first-mention line order monotonic` → `V2a: Review gate → Runtime gate first-mention line order monotonic`.

V2a 블록(lines 27-34) 교체:
```bash
# ============== V2a: Gate label order ==============
awk '/Review gate/{if(!r)r=NR} /Runtime gate/{if(!rt)rt=NR} END{
  if (!(r && rt && r<rt)) {
    print "FAIL V2a: gate label order broken. review=" r " runtime=" rt
    exit 1
  }
}' "$S" || exit 1
echo "PASS V2a (gate-label order: review < runtime)"
```

V2b의 Gate-1-FAIL 체크(lines 45-48) **삭제**:
```bash
# Gate 1 FAIL context
check "Plan verification failed" "Gate 1 FAIL anchor"
check "Continue anyway"          "Gate 1 FAIL option"
check "View detail"              "Gate 1 FAIL option"
```
→ 이 4줄 제거(주석 포함).

`check "Proceed to Gate 3"        "Gate 2 iter option"` → `check "Proceed to Runtime gate"  "Review iter option"`.
나머지 check(`findings remain`, `Retry`, `Runtime verifier needs`, `Yes, retry`, `Skip with evidence`, `P21`)는 유지. 주석의 `Gate 2 iter`/`Gate 3` 라벨 텍스트는 cosmetic(테스트 파일이라 AC 제외)이나 일관성 위해 `Review iter`/`Runtime`으로 갱신 권장.

- [ ] **Step 16: harness/test_skill_orchestration_behavior.sh 갱신**

Gate 1 dispatch 단언 + Gate1<2<3 ordering 제거, renamed 식별자 패턴 갱신.

- 헤더 주석(lines 10-15) "Gate 1 → Gate 2 → Gate 3" → "Review gate → Runtime gate"; `DEVBREW_GATE3_MAX_RESOLUTIONS` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`.
- lines 77-88 교체:
```bash
# Gate dispatch lines.
review_line=$(first_line 'subagent_type.*quality-gates:adversarial')
runtime_line=$(first_line 'subagent_type.*runtime-verifier')

assert_line "Review gate adversarial dispatch"   "$review_line"
assert_line "Runtime gate runtime-verifier dispatch" "$runtime_line"

# Ordering: Review gate < Runtime gate.
assert_order "Review precedes Runtime" "$review_line" "$runtime_line"
```
- line 105 `itercap_line=$(first_line 'max_gate2_iterations')` → `itercap_line=$(first_line 'max_review_iterations')`
- line 106 `assert_proximity "iter cap near Gate 2 AskUserQuestion" "$askuser_g2_line" "$itercap_line" 80` 의 변수/라벨: `askuser_g2_line` 계산(line 104)을 `askuser_review_line=$(first_line_after 'AskUserQuestion' "$review_line")`로, 라벨 `"iter cap near Review gate AskUserQuestion"`, 인자 `"$askuser_review_line" "$itercap_line" 80`.
- line 111 `gate3_max_line=$(first_line_after 'DEVBREW_GATE3_MAX_RESOLUTIONS' "$gate3_line")` → `runtime_max_line=$(first_line_after 'DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS' "$runtime_line")`
- line 112 `assert_proximity "GATE3_MAX_RESOLUTIONS near Gate 3 dispatch" "$gate3_line" "$gate3_max_line" 100` → `assert_proximity "RUNTIME_MAX_RESOLUTIONS near Runtime dispatch" "$runtime_line" "$runtime_max_line" 100`
- Retry-path 블록(lines 114-121): `gate2_line`/`gate3_line` 변수를 `review_line`/`runtime_line`으로, 라벨의 "Gate 2"/"Gate 3" → "Review"/"Runtime".
- 4-agent fan-out 루프(lines 90-98)는 **불변**(adversarial/test-scope-validator/security-reviewer/runtime-verifier — plan-verifier 미포함).

- [ ] **Step 17: 두 orchestration 테스트 + 린터 green (repo root)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_skill_orchestration.sh && echo "orchestration green OK"
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh && echo "harness green OK"
bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh && echo "allowed-tools-order green OK"
```
Expected: 세 줄 모두 출력. (`test_skill_orchestration.sh`는 baseline RED → 이제 GREEN으로 flip = 9→8 red 축소.)

- [ ] **Step 18: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/test_skill_orchestration.sh \
        plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates)!: SKILL.md 2-gate rename (Review/Runtime), drop Gate 1

Gate 1 섹션 2개 삭제; Gate 2→Review gate, Gate 3→Runtime gate; 내부 식별자
(max_review_iterations, DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS) rename. orchestration
테스트 2개 동기화 — test_skill_orchestration.sh가 pre-existing red→green.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: setup-qg.sh + test_setup_qg.sh (Phase A+B)

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` (arg parse, usage, env/field/var, single-gate 로직, 메시지)
- Modify: `plugins/quality-gates/tests/test_setup_qg.sh` (field/env 단언)

- [ ] **Step 1: arg 파싱 (lines 33-45) — gate1 제거, review/runtime 수용**

```bash
    gate1|gate2|gate3)
      SINGLE_GATE="$1"
      shift
      ;;
```
→
```bash
    review|runtime)
      SINGLE_GATE="$1"
      shift
      ;;
```
그리고 branch peek(line 40)의 `[[ ! "$1" =~ ^gate[123]$ ]]` → `[[ ! "$1" =~ ^(review|runtime)$ ]]`.

- [ ] **Step 2: usage 텍스트 (lines 82-103) 2-gate로 재작성**

```
USAGE:
  /qg [gate1|gate2|gate3] [OPTIONS]

ARGUMENTS:
  gate1          Run Plan Verification only
  gate2          Run PR Review only
  gate3          Run Runtime Verification only
  (none)         Run full pipeline (Gate 1 → 2 → 3)
```
→
```
USAGE:
  /qg [review|runtime] [OPTIONS]

ARGUMENTS:
  review         Run the Review gate only
  runtime        Run the Runtime gate only
  (none)         Run full pipeline (Review gate → Runtime gate)
```
그리고 OPTIONS 블록의 `--skip-runtime       Skip Gate 3 (runtime verification)` → `--skip-runtime       Skip the Runtime gate (runtime verification)`.
PIPELINE 블록(lines 100-103):
```
PIPELINE:
  Gate 1: Plan Verification — checks all planned items are implemented
  Gate 2: PR Review — iterative code review (review → fix → re-review)
  Gate 3: Runtime Verification — launches app and verifies behavior
```
→
```
PIPELINE:
  Review gate — iterative code review (review → fix → re-review)
  Runtime gate — launches app and verifies behavior
```

- [ ] **Step 3: env/var/field rename (lines 259-280)**

```bash
# --- Validate DEVBREW_GATE3_MAX_RESOLUTIONS (P18 unbounded-autonomy guard) ---
# Default 3. Clamped to 0..10. Non-numeric → warning + default.

gate3_max="${DEVBREW_GATE3_MAX_RESOLUTIONS:-3}"
if ! [[ "$gate3_max" =~ ^[0-9]+$ ]]; then
  echo "setup-qg: DEVBREW_GATE3_MAX_RESOLUTIONS='$gate3_max' is not numeric; defaulting to 3" >&2
  gate3_max=3
elif (( gate3_max > 10 )); then
  echo "setup-qg: DEVBREW_GATE3_MAX_RESOLUTIONS='$gate3_max' exceeds maximum 10; clamping to 10" >&2
  gate3_max=10
fi
```
→
```bash
# --- Validate DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS (P18 unbounded-autonomy guard) ---
# Default 3. Clamped to 0..10. Non-numeric → warning + default.

runtime_max="${DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS:-3}"
if ! [[ "$runtime_max" =~ ^[0-9]+$ ]]; then
  echo "setup-qg: DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS='$runtime_max' is not numeric; defaulting to 3" >&2
  runtime_max=3
elif (( runtime_max > 10 )); then
  echo "setup-qg: DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS='$runtime_max' exceeds maximum 10; clamping to 10" >&2
  runtime_max=10
fi
```
state 파일 작성(line 280) `gate3_max_resolutions: $gate3_max` → `runtime_max_resolutions: $runtime_max`.

- [ ] **Step 4: single-gate + full-pipeline 메시지 (lines 304-318) 비수치화**

```bash
GATE_NAMES=("" "Plan Verification" "PR Review" "Runtime Verification")

if [[ -n "$SINGLE_GATE" ]]; then
  GATE_NUM=${SINGLE_GATE//gate/}
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_NUM} (${GATE_NAMES[$GATE_NUM]})"
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: 1 (Plan Verification) → 2 (PR Review) → 3 (Runtime Verification)"
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    echo "       Gate 3 skipped (--skip-runtime)"
  fi
fi
```
→
```bash
if [[ -n "$SINGLE_GATE" ]]; then
  case "$SINGLE_GATE" in
    review)  GATE_LABEL="Review gate" ;;
    runtime) GATE_LABEL="Runtime gate" ;;
  esac
  echo "🔄 Quality Gates Pipeline — Single Gate Mode"
  echo ""
  echo "Gate: ${GATE_LABEL}"
else
  echo "🔄 Quality Gates Pipeline — Full Pipeline"
  echo ""
  echo "Gates: Review gate → Runtime gate"
  if [[ "$SKIP_RUNTIME" == "true" ]]; then
    echo "       Runtime gate skipped (--skip-runtime)"
  fi
fi
```

- [ ] **Step 5: 의존성 체크 주석 (lines 227, 236-237) gate 참조**

`# Check pr-review-toolkit (required for Gate 2)` → `# Check pr-review-toolkit (required for the Review gate)`. echo 줄 `Gate 2 (PR Review) requires this plugin...` → `The Review gate (PR Review) requires this plugin...`; `Pipeline will continue but Gate 2 may have limited functionality` → `... but the Review gate may have limited functionality`.

- [ ] **Step 6: setup-qg.sh file-local sweep**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]" plugins/quality-gates/scripts/setup-qg.sh || echo "setup-qg gate-clean OK"
```
Expected: `setup-qg gate-clean OK`.

- [ ] **Step 7: test_setup_qg.sh 단언 갱신**

- 헤더 주석(line 4) `... (gate3_resolution_iter:, max_gate3_resolutions:, project_dir:) and` → `... (runtime_max_resolutions:, project_dir:) and` (cosmetic — tests/ 제외이나 일관성).
- line 31 `assert "state contains gate3_max_resolutions default 3" "grep -q 'gate3_max_resolutions: 3' '$STATE_FILE'"` → `assert "state contains runtime_max_resolutions default 3" "grep -q 'runtime_max_resolutions: 3' '$STATE_FILE'"`
- line 49 주석 `# --- Case 3: clamp DEVBREW_GATE3_MAX_RESOLUTIONS=99 → 10 (C3) ---` → `... DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 ...`
- line 53 `DEVBREW_GATE3_MAX_RESOLUTIONS=99 "$SCRIPT" ...` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 "$SCRIPT" ...`
- line 55 `assert "DEVBREW_GATE3_MAX_RESOLUTIONS=99 clamped to 10" "grep -q 'gate3_max_resolutions: 10' '$STATE_FILE'"` → `assert "DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 clamped to 10" "grep -q 'runtime_max_resolutions: 10' '$STATE_FILE'"`
- line 63 `DEVBREW_GATE3_MAX_RESOLUTIONS=abc "$SCRIPT" ...` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=abc "$SCRIPT" ...`
- line 65 `assert "non-numeric env defaults to 3" "grep -q 'gate3_max_resolutions: 3' '$STATE_FILE'"` → `... "grep -q 'runtime_max_resolutions: 3' '$STATE_FILE'"`
- line 33 `assert "v1.32.0 schema: no gate2_iteration phantom" "! grep -q '^gate2_iteration:' '$STATE_FILE'"` → **유지**(부재 단언 — 새 필드도 추가 안 하므로 여전히 참; `gate2_iteration` 문자열은 tests/라 AC 무관).

- [ ] **Step 8: test_setup_qg green + gate1/2/3 rejection 확인 (AC7) (repo root)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_setup_qg.sh && echo "setup-qg test green OK"
# AC7: review|runtime 수용, gate1|gate2|gate3 거부 (unknown arg → exit 1)
for bad in gate1 gate2 gate3; do
  if bash plugins/quality-gates/scripts/setup-qg.sh "$bad" --session-id qgrejecttest12345 >/dev/null 2>&1; then
    echo "AC7 FAIL: '$bad' was accepted (expected rejection)"
  else
    echo "AC7 OK: '$bad' rejected"
  fi
done
for good in review runtime; do
  bash plugins/quality-gates/scripts/setup-qg.sh "$good" --session-id "qgaccept-$good-12345" >/dev/null 2>&1 \
    && echo "AC7 OK: '$good' accepted" || echo "AC7 FAIL: '$good' rejected"
  rm -rf ".claude/quality-gates/qgaccept-$good-12345"
done
```
Expected: `setup-qg test green OK`; `gate1/2/3 rejected` ×3; `review/runtime accepted` ×2. (gate1/2/3는 case 문에서 빠져 `*)` unknown-arg 분기 → exit 1.)

- [ ] **Step 9: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_setup_qg.sh
git commit -m "feat(quality-gates)!: setup-qg subcommands review|runtime, rename env+state field

gate1|gate2|gate3 → review|runtime (gate1 제거). DEVBREW_GATE3_MAX_RESOLUTIONS →
DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS; state 필드 gate3_max_resolutions →
runtime_max_resolutions.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: commands/qg.md + commands/cancel-qg.md (Phase A+B)

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md`
- Modify: `plugins/quality-gates/commands/cancel-qg.md:39`

- [ ] **Step 1: qg.md frontmatter (lines 2-3)**

- line 2 `description: "Run the quality gates pipeline (plan verification → PR review → runtime verification)"` → `description: "Run the quality gates pipeline (review → runtime verification)"`
- line 3 `argument-hint: "[gate1|gate2|gate3] [branch ...]"` → `argument-hint: "[review|runtime] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"`

- [ ] **Step 2: qg.md Instructions 단락 (lines 50-53)**

```
arguments. The skill runs the complete pipeline in this turn — Gate 1 →
Gate 2 (with internal fix-loop) → Gate 3 — and surfaces decision points
```
→
```
arguments. The skill runs the complete pipeline in this turn — the
Review gate (with internal fix-loop) → the Runtime gate — and surfaces decision points
```

- [ ] **Step 3: qg.md Quick Reference 표 (lines 59-67)**

- line 59 `| \`/qg\` | Full pipeline (Gate 1 → 2 → 3), session-scoped diff |` → `| \`/qg\` | Full pipeline (Review gate → Runtime gate), session-scoped diff |`
- line 65 `| \`/qg gate1\` | Plan verification only |` → **삭제**(행 제거)
- line 66 `| \`/qg gate2\` | PR review only |` → `| \`/qg review\` | Review gate only |`
- line 67 `| \`/qg gate3\` | Runtime verification only |` → `| \`/qg runtime\` | Runtime gate only |`
- `| \`/qg --skip-runtime\` | Gates 1 & 2 only (skip runtime) |` → `| \`/qg --skip-runtime\` | Review gate only (skip runtime) |`

- [ ] **Step 4: qg.md Pipeline Rules + Gates 섹션 (lines 102-120)**

- 제목 `### Gates`(line 102) 하위 리스트(lines 104-106):
```
1. **Plan Verification** — Checks all planned items are implemented
2. **PR Review** — Iterative code review (scout → Phase 1+2 → adversarial → synthesizer); within-gate fix-loop up to 5 iterations
3. **Runtime Verification** — Launches app and verifies behavior with browser automation
```
→
```
- **Review gate** — Iterative code review (scout → Phase 1+2 → adversarial → synthesizer); within-gate fix-loop up to 5 iterations
- **Runtime gate** — Launches app and verifies behavior with browser automation
```
- `### Pipeline Rules (v1.32.0)` → `### Pipeline Rules (v2.0.0)`
- `from Gate 1.`(line 114, "does NOT auto-restart from Gate 1.") → `from an earlier gate.`
- `Gate 2 iterates up to 5 times internally; ... \`Retry\` / \`Proceed to Gate 3\` / \`Stop\`.`(lines 115-116) → `The Review gate iterates up to 5 times internally; AskUserQuestion fires at every iteration boundary with \`Retry\` / \`Proceed to Runtime gate\` / \`Stop\`.`
- `AskUserQuestion also fires on Gate 1 FAIL, Gate 2 max-iter, and Gate 3 NEEDS_RESOLUTION.`(lines 117-118) → `AskUserQuestion also fires on Review gate max-iter and Runtime gate NEEDS_RESOLUTION.`
- line 119 `State tracked minimally in \`.claude/quality-gates/<session-id>/pipeline.md\``(유지). `Gate 2 fix-loop applies user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart`(lines 112-114) → `The Review gate fix-loop applies user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart`.

- [ ] **Step 5: cancel-qg.md state 필드 참조 (line 39)**

`v1.32.1 minimal schema의 실제 필드: \`session_id\`, \`started_at\`, \`gate3_max_resolutions\` (v1.32.1 C3 복구), optional \`worktree_path\` / \`target_branch\`. (v1.5.x의 \`status\` / \`current_gate\` / \`gate2_iteration\`은 ...)` 중:
- `gate3_max_resolutions` → `runtime_max_resolutions`
- `gate2_iteration`은 v1.5.x 제거 이력 서술이라 그대로 둬도 되나, `gate2`가 AC8 매칭 → **반드시 reword**. `(v1.5.x의 \`status\` / \`current_gate\` / \`gate2_iteration\`은 v1.32.0/v1.32.1에서 제거됨 ...)` → `(v1.5.x의 \`status\` / \`current_gate\` / review-iteration 필드는 v1.32.0/v1.32.1에서 제거됨 — 실제 iteration counter는 \`## History\` 섹션의 append-only 라인으로 추적.)`

- [ ] **Step 6: file-local sweep**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]" plugins/quality-gates/commands/qg.md plugins/quality-gates/commands/cancel-qg.md || echo "commands gate-clean OK"
grep -cE "\breview\b" plugins/quality-gates/commands/qg.md   # expect >=1
grep -cE "\bruntime\b" plugins/quality-gates/commands/qg.md  # expect >=1
```
Expected: `commands gate-clean OK`; review ≥1; runtime ≥1.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/commands/qg.md plugins/quality-gates/commands/cancel-qg.md
git commit -m "feat(quality-gates)!: /qg review|runtime subcommands, 2-gate Quick Reference

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: run_codex_reviewer.sh + build_codex_prompt.py — wall-clock 600s 제거 + gate1_summary 정리 (Phase A+C)

**Files:**
- Modify: `plugins/quality-gates/scripts/run_codex_reviewer.sh` (timeout 600, no_timeout_binary, OVERRIDE_REASON=timeout, plan-verifier 주석)
- Modify: `plugins/quality-gates/scripts/build_codex_prompt.py:4` (gate1_summary 주석)

`set -euo pipefail` 하에서 codex가 non-zero를 반환해도 `EXIT_CODE`를 안전하게 캡처하도록 `|| EXIT_CODE=$?` 패턴을 쓴다(기존 timeout 래퍼가 set -e와 어떻게 공존했든, timeout 제거 후에도 exit1 mock 경로가 OUTPUT_PATH를 정상 작성해야 함 — Layer 3 sandbox는 codex `-s read-only` 플래그로 유지).

**핵심 함정 (spec §7 Phase C 강조 — self-review가 잡음): `tests/mocks/bin-stubs/{gtimeout,timeout}` 및 `detect_codex.sh`는 절대 건드리지 않는다.** run_codex_reviewer.sh에서 timeout 의존을 제거하더라도 `detect_codex.sh`의 5s version probe(`"$TIMEOUT_BIN" 5 codex --version`, AC18)가 여전히 timeout 바이너리를 요구하므로 bin-stub mock이 계속 사용된다. 이 Task에서 mock·detect_codex.sh를 삭제/수정하지 말 것.

- [ ] **Step 1: timeout 바이너리 분기 제거 (lines 47-51)**

```bash
TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"
if [[ -z "$TIMEOUT_CMD" ]]; then
  echo '{"codex_failed": true, "reason": "no_timeout_binary"}' > "$OUTPUT_PATH"
  exit 0
fi

```
→ **전부 삭제**(이어지는 빈 줄 포함). (run_codex_reviewer는 더 이상 timeout 바이너리를 요구하지 않음. detect_codex.sh의 5s probe는 별도로 timeout을 요구하며 그대로 유지 — Task 14 AC18.)

- [ ] **Step 2: codex 호출에서 timeout 래퍼 제거 + EXIT_CODE 안전 캡처 (lines 66-82)**

```bash
"$TIMEOUT_CMD" 600 codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 124 ]]; then
  OVERRIDE_REASON=timeout
elif [[ $EXIT_CODE -ne 0 ]]; then
  OVERRIDE_REASON=exit_nonzero
else
  OVERRIDE_REASON=""
fi
```
→
```bash
# Direct codex invocation — no per-call timeout (hang risk accepted; backstops:
# Bash tool timeout, DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg). Layer 3 sandbox
# (-s read-only) preserved. `|| EXIT_CODE=$?` keeps capture safe under set -e.
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
```

- [ ] **Step 3: 주석의 plan-verifier 참조 정리 (line 13)**

```bash
#   PLAN_SUMMARY_FILE — path to YAML file with plan-verifier matched_items
#                       (omit for empty plan context).
```
→
```bash
#   PLAN_SUMMARY_FILE — path to YAML file with an optional plan summary
#                       (omit for empty plan context; Gate 1 verifier removed
#                       in v2.0.0, so callers normally leave this unset).
```
(PLAN_SUMMARY 메커니즘 자체는 유지 — 설정 안 하면 `/dev/null` → 빈 plan context, 기존 "no plan" 동작과 동일. Review gate 로직 byte-동등. line 54 `PLAN_SUMMARY="${PLAN_SUMMARY_FILE:-/dev/null}"` 불변.)

- [ ] **Step 4: build_codex_prompt.py 주석 (line 4)**

```python
Reads filtered_diff and gate1_summary from argv file paths. NEVER takes
```
→
```python
Reads filtered_diff and an optional plan summary from argv file paths. NEVER takes
```
(`<plan_context>{{PLAN_SUMMARY}}</plan_context>` 템플릿 + `plan_summary_file` 인자는 **유지** — Gate 1 없으면 빈 파일이 들어와 빈 context가 됨. 로직 불변.)

- [ ] **Step 5: file-local sweep**

Run:
```bash
grep -niE "no_timeout_binary|OVERRIDE_REASON=timeout|timeout[[:space:]]+600|gate1_summary|plan-verifier" \
  plugins/quality-gates/scripts/run_codex_reviewer.sh plugins/quality-gates/scripts/build_codex_prompt.py \
  || echo "codex scripts clean OK"
```
Expected: `codex scripts clean OK`.

- [ ] **Step 6: codex exit-path 동작 확인 (no_timeout_binary 제거 후 exit1 mock 정상)**

Run (mock codex로 non-zero 경로 — OUTPUT_PATH가 정상 작성되는지):
```bash
cd /Users/jeonghokim/Downloads/devbrew
OUT=$(mktemp)
CLAUDE_PLUGIN_ROOT="$PWD/plugins/quality-gates" \
PATH="$PWD/plugins/quality-gates/tests/mocks:$PATH" \
bash -c '
  mkdir -p /tmp/qgcodexchk && echo "diff" > /tmp/qgcodexchk/d.txt
  cp plugins/quality-gates/tests/mocks/mock-codex-exit1.sh /tmp/qgcodexchk/codex 2>/dev/null || true
' 2>/dev/null
echo "(이 step은 mock 경로 sanity; 실제 검증은 test 스위트가 담당)"
rm -f "$OUT"
```
참고: codex exit-path의 정식 회귀 커버리지는 codex 관련 테스트(orthogonal stale red, scope 밖)에 있다. 이 작업의 목적은 `no_timeout_binary` 분기 제거가 정상 경로를 깨지 않음을 확인하는 것이며, Task 14의 전체 스위트 실행에서 **새 red가 생기지 않음**으로 검증한다(이 step의 수동 확인은 non-binding sanity).

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/run_codex_reviewer.sh plugins/quality-gates/scripts/build_codex_prompt.py
git commit -m "feat(quality-gates)!: remove codex per-call 600s timeout (wall-clock budget)

per-call wall-clock ceiling 제거. hang 위험은 수용 — backstop: Bash tool timeout,
DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg. set -e 하에서 EXIT_CODE 안전 캡처(|| EXIT_CODE=\$?).
gate1_summary 주석을 generic plan summary로 정리(메커니즘 불변).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: agents — 4개 persona의 gate 참조 + gate1_summary 입력 제거 (Phase B)

**Files:**
- Modify: `plugins/quality-gates/agents/adversarial.md` (Gate 2 prose)
- Modify: `plugins/quality-gates/agents/security-reviewer.md` (Gate 2 prose + gate1_summary 입력 제거 + plan-verifier 언급)
- Modify: `plugins/quality-gates/agents/test-scope-validator.md` (Gate 3/Gate 1 prose + gate1_summary 입력 제거)
- Modify: `plugins/quality-gates/agents/runtime-verifier.md` (Gate 3 prose + evidence log header + verdict/signal 마커 rename + Gate 1/2 언급)

**Law 2 주의:** persona의 *"You are NOT responsible for..."* 책임 경계는 **불변**(약화 금지). gate 번호 라벨과 더 이상 존재하지 않는 Gate 1 핸드오프(`gate1_summary`)만 제거/rename. 책임 자체("plan-level threat modeling은 내 일이 아님")는 유지하되, 그 근거가 "Gate 1 plan-verifier가 커버"였던 부분은 근거 문구만 갱신.

- [ ] **Step 1: adversarial.md (lines 3, 10, 12)**

- line 3 `description: Phase 1.5 of Gate 2 — adversarially reviews findings ...` → `description: Phase 1.5 of the Review gate — adversarially reviews findings ...`
- line 10 `You are **Adversarial**, the false-positive hunter for Gate 2.` → `... for the Review gate.`
- line 12 `You are the **single model-based judgment gate** in Gate 2: the Phase 1/2` → `... in the Review gate: the Phase 1/2`

- [ ] **Step 2: security-reviewer.md (lines 3, 14, 18, 26)**

- line 3 `description: Phase 1 of Gate 2 — always-run code-level security review. ...` → `description: Phase 1 of the Review gate — always-run code-level security review. ...`
- line 14 `You are **security-reviewer**, the code-level security specialist for Gate 2 Phase 1.` → `... for the Review gate Phase 1.`
- line 18 `You are NOT responsible for: code style, design or architecture critique, performance issues, plan-level threat modeling (Gate 1 plan-verifier already covers spec coverage), or proposing alternative fixes when the existing approach is sound.` → `You are NOT responsible for: code style, design or architecture critique, performance issues, plan-level threat modeling (out of scope — upstream writing-plans/spec-distill owns spec coverage), or proposing alternative fixes when the existing approach is sound.`
- line 26 (gate1_summary 입력 contract) `- \`gate1_summary\`: YAML block from plan-verifier (matched_items / unmatched_items / unexpected_files / verdict). Use only for context — do not flag plan-level gaps.` → **삭제**(이 input 줄 전체 제거 — Gate 1 verifier 없으면 gate1_summary가 dispatch되지 않음). 인접 input 리스트의 형식(불릿)이 깨지지 않게 확인.

- [ ] **Step 3: test-scope-validator.md (lines 17, 23-24, 32, 34, 55, 65)**

- line 17 `Light-weight pre-execution check (Gate 3 Step 2.5 of the quality-gates` → `Light-weight pre-execution check (Runtime gate Step 2.5 of the quality-gates`
- line 23-24 `<example>Context: Gate 3 Step 2.5 — skill provides plan_path, Gate 1 matched_items, filtered diff, and candidate_test_files.` → `<example>Context: Runtime gate Step 2.5 — skill provides plan_path, filtered diff, and candidate_test_files.` (Gate 1 matched_items 언급 제거)
- line 32 `# Test Scope Validator Agent (Gate 3 Step 2.5)` → `# Test Scope Validator Agent (Runtime gate Step 2.5)`
- line 34 `... **You are advisory** — your output never blocks Gate 3.` → `... never blocks the Runtime gate.`
- line 36 `... quality and security judgment is Gate 2's territory.` → `... is the Review gate's territory.`
- line 55 `- \`gate1_summary\`: verbatim YAML from Gate 1 with \`matched_items\`` → **삭제**(input contract 줄 제거)
- lines 65 부근 `- \`matched_items\` from \`gate1_summary\` — what features were planned` → 이 단계 설명을 plan_path 기반으로 재서술: `- \`plan_path\` (auto = discover-plan.sh) — what features were planned, if a plan file exists`. (test-scope-validator는 plan_path를 직접 받으므로 gate1_summary 없이도 plan-scope 비교 가능; discover-plan.sh가 plan을 공급 — 이것이 spec에서 discover-plan 유지 이유.)
- line 103 부근 `... Whether the user fixes the flagged tests is their decision in the next turn, after Gate 3 completes.` → `... after the Runtime gate completes.`

**주의:** test-scope-validator는 SKILL dispatch에서 `plan_path: <path or 'auto'>`를 받는다(SKILL Task 3 Step 11에서 유지됨). gate1_summary 입력만 제거되고 plan_path 경로는 유지되므로, plan-scope 비교(cherry-pick-suspicion 판정) 로직은 약화되지 않는다.

- [ ] **Step 4: runtime-verifier.md (lines 25, 33, 43, 48, 50, 52, 119, 159, 164, 194)**

- line 25 `Use this agent for runtime verification of applications as Gate 3 of the` → `... as the Runtime gate of the`
- line 33 `<example>Context: Quality pipeline Gate 3 — manifest declares docker-compose,` → `<example>Context: Quality pipeline Runtime gate — manifest declares docker-compose,`
- line 43 `user: "Run gate 3 with this manifest."` → `user: "Run the runtime gate with this manifest."`
- line 48 `# Runtime Verifier Agent (Gate 3)` → `# Runtime Verifier Agent (Runtime gate)`
- line 50 `You are the Runtime Verifier — Gate 3 of the quality-gates pipeline.` → `You are the Runtime Verifier — the Runtime gate of the quality-gates pipeline.`
- line 52 `... Plan-vs-diff matching is Gate 1; code-quality and security judgment is Gate 2. Stay on the "does it run, and what's the evidence" axis.` → `... Plan-vs-diff matching is the test-scope-validator's concern; code-quality and security judgment is the Review gate's. Stay on the "does it run, and what's the evidence" axis.` (Gate 1 언급 제거 — 더 이상 plan-verify gate 없음; plan-vs-diff 관점은 test-scope-validator로 이관)
- line 119 `# Gate 3 Evidence Log — iteration N` → `# Runtime gate Evidence Log — iteration N`
- line 159 `... the skill will eventually escalate to \`gate3_fail\` after \`max_gate3_resolutions\`. ...` → `... escalate to \`runtime_fail\` after \`runtime_max_resolutions\`. ...`
- line 164 `## Runtime Verification Report (Gate 3, iter N)` → `## Runtime Verification Report (Runtime gate, iter N)`
- line 194 `... identical hashes for two consecutive NEEDS_RESOLUTION emit signals trigger \`gate3_repeat_detected\`.` → `... trigger \`runtime_repeat_detected\`.`

- [ ] **Step 5: agents file-local sweep + gate1_summary 부재**

Run:
```bash
grep -rniE "gate ?[123]|GATE_?[123]|gate1_summary|plan-verifier" plugins/quality-gates/agents/ || echo "agents gate-clean OK"
```
Expected: `agents gate-clean OK`. (adversarial/runtime-verifier/security-reviewer/test-scope-validator만 남음 — 4개.)

- [ ] **Step 6: agent 테스트 green (frontmatter + behavior + persona)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_runtime_verifier_frontmatter.sh test_test_scope_validator_frontmatter.sh \
         test_security_reviewer_persona.sh test_adversarial_model_consistency.sh; do
  bash "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done
for t in test_runtime_verifier_behavior.py test_test_scope_validator_behavior.py \
         test_security_reviewer_behavior.py test_adversarial_behavior.py; do
  python3 "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done
```
Expected: 8개 모두 PASS (behavior/frontmatter 테스트는 gate 문자열을 단언하지 않음 — 실측 확인됨).

**주의 (AC19):** `disallowedTools` 격리는 4개 agent 모두 유지되어야 한다. Step 4-5 편집 중 frontmatter를 건드리지 말 것. Task 14 AC19가 4개 파일 전부 `disallowedTools` 보유를 검증.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/agents/
git commit -m "refactor(quality-gates): rename gate labels in 4 reviewer personas, drop gate1_summary input

Gate 2→Review gate, Gate 3→Runtime gate. security-reviewer/test-scope-validator의
gate1_summary 입력 contract 제거(Gate 1 verifier 부재). 책임 경계·disallowedTools
격리 불변 (persona 약화 아님). runtime-verifier 마커 gate3_fail→runtime_fail,
gate3_repeat_detected→runtime_repeat_detected.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 기타 스크립트 — synthesize/detect-runtime/compute-test-scope/linter (Phase B)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:103,107` (heading)
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh:16,24,253` (evidence 경로 + 주석)
- Modify: `plugins/quality-gates/scripts/compute-test-scope-candidates.sh:7,26` (주석)
- Modify: `plugins/quality-gates/scripts/check-allowed-tools-order.sh:17,21` (주석)
- Modify: `plugins/quality-gates/tests/test_synthesize_findings.sh:60` (heading 단언)

- [ ] **Step 1: synthesize_findings.py heading (lines 103, 107)**

두 곳 모두:
```python
"## Gate 2 Findings (Synthesized)\n\n"
```
및
```python
out = ["## Gate 2 Findings (Synthesized)", ""]
```
→ `## Review Findings (Synthesized)`로 (각각 `## Gate 2 Findings` → `## Review Findings`).

- [ ] **Step 2: detect-runtime.sh evidence 경로 (lines 16, 24, 253)**

- line 16 주석 `# Output (single multi-line YAML to stdout, expected by SKILL.md Gate 3):` → `... expected by SKILL.md Runtime gate):`
- line 24 주석 `#   attempted_log_path: .claude/quality-gates/<sid>/gate3-evidence.md` → `#   attempted_log_path: .claude/quality-gates/<sid>/runtime-evidence.md`
- line 253 `emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/gate3-evidence.md"` → `emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/runtime-evidence.md"`

- [ ] **Step 3: compute-test-scope-candidates.sh 주석 (lines 7, 26)**

- line 7 `#   (no env vars)   — review range is computed identically to SKILL.md Gate 2 Step 0` → `... identically to SKILL.md Review gate Step 0`
- line 26 `# Review range — identical formula to Gate 2 Step 0 (SKILL.md §"Step 0").` → `# Review range — identical formula to the Review gate Step 0 (SKILL.md §"Step 0").`

- [ ] **Step 4: check-allowed-tools-order.sh 주석 (lines 17, 21)**

- line 17 `  # Group 2 — Gate 2 PR review scripts` → `  # Group 2 — Review gate scripts`
- line 21 `  # Group 3 — Gate 3 runtime verification scripts` → `  # Group 3 — Runtime gate scripts`
(이 주석들은 `EXPECTED_ORDER` 배열 항목이 아니라 그룹 라벨. 배열 내용·검증 로직 불변.)

- [ ] **Step 5: test_synthesize_findings.sh heading 단언 (line 60)**

```bash
  '## Gate 2 Findings.*### CRITICAL' ''
```
→
```bash
  '## Review Findings.*### CRITICAL' ''
```

- [ ] **Step 6: file-local sweep + detect_runtime 테스트 gate3-evidence 단언 확인**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]" \
  plugins/quality-gates/scripts/synthesize_findings.py \
  plugins/quality-gates/scripts/detect-runtime.sh \
  plugins/quality-gates/scripts/compute-test-scope-candidates.sh \
  plugins/quality-gates/scripts/check-allowed-tools-order.sh || echo "scripts gate-clean OK"
# detect_runtime 테스트가 gate3-evidence를 단언하는지 (있으면 같이 갱신 필요)
grep -n "gate3-evidence\|runtime-evidence" plugins/quality-gates/tests/test_detect_runtime.sh || echo "test_detect_runtime: no evidence-path assertion"
```
Expected: `scripts gate-clean OK`; `test_detect_runtime: no evidence-path assertion` (실측상 단언 없음 — 만약 출력되면 그 단언도 `runtime-evidence.md`로 갱신).

- [ ] **Step 7: 관련 테스트 green**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_synthesize_findings.sh test_detect_runtime.sh test_compute_test_scope_candidates.sh test_check_allowed_tools_order.sh; do
  bash "plugins/quality-gates/tests/$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done
```
Expected: 4개 모두 PASS.

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py \
        plugins/quality-gates/scripts/detect-runtime.sh \
        plugins/quality-gates/scripts/compute-test-scope-candidates.sh \
        plugins/quality-gates/scripts/check-allowed-tools-order.sh \
        plugins/quality-gates/tests/test_synthesize_findings.sh
git commit -m "refactor(quality-gates): rename gate labels in scripts (synthesize heading, evidence path, comments)

## Gate 2 Findings → ## Review Findings; gate3-evidence.md → runtime-evidence.md.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: hooks — post-tool-use.py + session-tracker 주석 (Phase B)

**Files:**
- Modify: `plugins/quality-gates/hooks/post-tool-use.py:86`
- Modify: `plugins/quality-gates/hooks/post-tool-use-session-tracker.py:65`

- [ ] **Step 1: post-tool-use.py (line 86)**

`/qg` 시작 안내 메시지 중:
```python
            "to begin Gate 1."
```
→
```python
            "to begin the Review gate."
```
(주변 문자열 연결 맥락 확인 — 이 줄은 멀티라인 메시지의 일부. "to begin Gate 1." → "to begin the Review gate."로 치환하되 문장 흐름 유지.)

- [ ] **Step 2: post-tool-use-session-tracker.py (line 65) 주석**

```python
    # — Gate 2 review found this hook's earlier silent fallback was the only
```
→
```python
    # — a Review gate review found this hook's earlier silent fallback was the only
```

- [ ] **Step 3: file-local sweep**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]" plugins/quality-gates/hooks/*.py || echo "hooks gate-clean OK"
```
Expected: `hooks gate-clean OK`.

- [ ] **Step 4: hook 테스트 green**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 plugins/quality-gates/tests/test_session_tracker.py >/dev/null 2>&1 && echo "PASS session_tracker"
python3 plugins/quality-gates/tests/test_hook_cwd_contract.py >/dev/null 2>&1 && echo "PASS hook_cwd"
bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh >/dev/null 2>&1 && echo "PASS advisor"
```
Expected: 3개 모두 PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/hooks/post-tool-use.py plugins/quality-gates/hooks/post-tool-use-session-tracker.py
git commit -m "refactor(quality-gates): rename gate labels in hook prose/comments

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: references — dependency-check.md + state-file-format.md (Phase A+B+C)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/dependency-check.md`
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (gate refs + field rename + **wall_clock_deadline_at 제거** — AC12)

- [ ] **Step 1: dependency-check.md gate 참조 (lines 8, 11, 13-14, 16, 24, 32, 36-37)**

- line 8 `1. Check Gate 2 core dependency (pr-review-toolkit) [REQUIRED]:` → `1. Check Review gate core dependency (pr-review-toolkit) [REQUIRED]:`
- line 11 `Gate 2 (PR Review) will not function correctly.` → `The Review gate (PR Review) will not function correctly.`
- line 13 `→ Ask: "Continue without Gate 2, or abort?"` → `... without the Review gate, or abort?"`
- line 14 `→ If continue: mark Gate 2 as SKIP in pipeline` → `... mark the Review gate as SKIP in pipeline`
- line 16 `2. Check Gate 1/2 optional dependency (feature-dev) [OPTIONAL]:` → `2. Check Review gate optional dependency (feature-dev) [OPTIONAL]:`
- line 24 `3. Check Gate 1/2 optional dependency (superpowers) [OPTIONAL]:` → `3. Check Review gate optional dependency (superpowers) [OPTIONAL]:`
- line 32 `4. Check Gate 3 dependency (browser automation) [OPTIONAL]:` → `4. Check Runtime gate dependency (browser automation) [OPTIONAL]:`
- line 36 `Gate 3 (Runtime Verification) will fall back to curl/test-based checks only."` → `The Runtime gate (Runtime Verification) will fall back ...`
- line 37 `→ This is informational only — Gate 3 has built-in fallback, so proceed automatically` → `... — the Runtime gate has built-in fallback ...`

(Gate 1 dependency 항목이 별도로 없으므로 "Gate 1/2" → "Review gate"로 흡수.)

- [ ] **Step 2: state-file-format.md (lines 5, 7-8, 28, 40-43, 54, 56-60, 66)**

- line 5 `> tracking + Gate 3 resolution-cap reporting**만 보존한다.` → `> tracking + Runtime gate resolution-cap reporting**만 보존한다.`
- line 7 `> v1.32.1 (review-driven): \`gate2_iteration: 0\` phantom 필드 제거(I11),` → `> v1.32.1 (review-driven): review-iteration phantom 필드 제거(I11),`
- line 8 `> \`gate3_max_resolutions:\` 필드 추가(C3).` → `> \`runtime_max_resolutions:\` 필드 추가(C3).`
- line 28 `gate3_max_resolutions: 3             # DEVBREW_GATE3_MAX_RESOLUTIONS clamped 0..10` → `runtime_max_resolutions: 3           # DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS clamped 0..10`
- lines 40-43 History 예시:
```
- [2026-05-27T10:02:00Z] Gate 1: PASS
- [2026-05-27T10:05:00Z] Gate 2 iter 1: FAIL → user chose Retry
- [2026-05-27T10:08:00Z] Gate 2 iter 2: PASS
- [2026-05-27T10:12:00Z] Gate 3: PASS
```
→
```
- [2026-05-27T10:05:00Z] Review gate iter 1: FAIL → user chose Retry
- [2026-05-27T10:08:00Z] Review gate iter 2: PASS
- [2026-05-27T10:12:00Z] Runtime gate: PASS
```
(Gate 1: PASS 줄 삭제 — Gate 1 없음.)
- line 54 `| \`current_gate\` | SKILL dispatches Gate 1 → 2 → 3 inline. |` → `| \`current_gate\` | SKILL dispatches Review gate → Runtime gate inline. |`
- line 56 `| \`max_gate2_iterations\` | Hard-coded constant in SKILL (5). |` → `| \`max_review_iterations\` | Hard-coded constant in SKILL (5). |`
- line 57 `| \`gate3_resolution_iter\` | Hard-coded constant in SKILL (default 3, env override). |` → `| \`runtime_resolution_iter\` | Hard-coded constant in SKILL (default 3, env override). |`
- line 58 `| \`last_gate3_needed_hash\` | Repeat detection moves to inline AskUserQuestion. |` → `| \`last_runtime_needed_hash\` | Repeat detection moves to inline AskUserQuestion. |`
- line 59 `| \`max_gate3_resolutions\` | Renamed to \`gate3_max_resolutions:\` (C3 restored in v1.32.1). |` → `| \`max_runtime_resolutions\` | Renamed to \`runtime_max_resolutions:\` (C3 restored in v1.32.1). |`
- line 60 `| \`gate2_iteration\` | Phantom field — counter lives in \`## History\` section only (I11 v1.32.1). |` → `| \`review_iteration\` | Phantom field — counter lives in \`## History\` section only (I11 v1.32.1). |`
- line 66 `| \`wall_clock_deadline_at\` | Wall-clock guard removed (AskUserQuestion = in-loop user consent). |` → **삭제**(행 제거 — AC12 `wall_clock` 0건 위해 필수). 이 표는 "제거된 필드" 목록이므로 행 하나 빠져도 무해.

- [ ] **Step 3: file-local sweep (gate + wall_clock)**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]|wall.?clock|wall_clock" \
  plugins/quality-gates/skills/quality-pipeline/references/dependency-check.md \
  plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md || echo "references clean OK"
```
Expected: `references clean OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/
git commit -m "docs(quality-gates): rename gate refs in reference docs, drop wall_clock_deadline_at row

state-file-format: gate3_max_resolutions→runtime_max_resolutions, wall_clock_deadline_at
행 제거(AC12). dependency-check: Gate 2/3→Review/Runtime gate.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: README.md 전면 갱신 (Phase A+B+C) + test_readme_state_diagram_complete.sh

가장 많은 산문 변경. 인스턴스화한 원칙·구조 트리·Cost·게이트 표·다이어그램·사용·Plan Discovery·사전요건·Tuning·kill switch.

**Files:**
- Modify: `plugins/quality-gates/README.md` (다수 구간)
- Modify: `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` (diagram markers)

- [ ] **Step 1: 제목 + 인스턴스화한 원칙 (lines 3, 11, 14, 17)**

- line 3 `Claude Code용 3-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.` → `Claude Code용 2-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.`
- line 11 `- **Law 1 (Clarity Before Code)** — Gate 1 plan-verifier가 FAIL 시 \`gate1_summary\` YAML 핸드오프로 Gate 2 진입을 차단.` → **삭제**(Gate 1 전용 원칙 — 제거). 대체로 R3(Law 1 잔존)을 line 19가 이미 커버하므로 별도 추가 불필요.
- line 14 `- **Law 3 (Compounding) — cross-plugin reader contract** — Gate 1 plan-verifier가 sister-plugin (\`superpowers:writing-plans\`)의 출력 경로 ... reader/writer 약속을 문서화.` → **재서술**(Gate 1 제거하되 reader contract는 test-scope-validator가 잇는다): `- **Law 3 (Compounding) — cross-plugin reader contract** — Runtime gate의 test-scope-validator(\`scripts/discover-plan.sh\`)가 sister-plugin (\`superpowers:writing-plans\`)의 출력 경로 \`docs/superpowers/plans/\`를 1순위 source로 명시 consume; convention drift가 silent breakage가 되지 않도록 README "Plan Discovery Sources" 섹션이 reader/writer 약속을 문서화.`
- line 17 `- **P18 anti-corollary (former AP16, unbounded autonomy) 회피** — Gate 2 내부 fix-loop이 \`max_gate2_iterations=5\` + repeat-detection (no-progress check) + kill switch로 묶임. *Wall-clock budget는 deferred — Tier 2 spec 참조.*` → `- **P18 anti-corollary (former AP16, unbounded autonomy) 회피** — Review gate 내부 fix-loop이 \`max_review_iterations=5\` + repeat-detection (no-progress check) + kill switch로 묶임.` (wall-clock 문장 **삭제** — AC12·AC13).
- line 21 `- **P18 anti-corollary ... — Gate 3** (v1.8.0) — Gate 3의 NEEDS_RESOLUTION mid-run 루프가 \`max_gate3_resolutions\` (기본 3, env override \`DEVBREW_GATE3_MAX_RESOLUTIONS=0..10\`)로 묶임. ...` → `- **P18 anti-corollary ... — Runtime gate** (v1.8.0) — Runtime gate의 NEEDS_RESOLUTION mid-run 루프가 \`runtime_max_resolutions\` (기본 3, env override \`DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=0..10\`)로 묶임. ...`
- line 19 `- **Law 1 (Verification Plan)** (v1.8.0) — Gate 3가 evidence-required SKIP을 강제. ...` → `... — Runtime gate가 evidence-required SKIP을 강제. ...` (R3 — Law 1 잔존; **유지** but Gate 3→Runtime gate)
- 기타 인스턴스화 줄들(line 23 "Gate 3가 3-way", line 32 "Gate 2 iter counter", line 34-35 "every gate boundary and Gate 2 fix-loop") 의 Gate 2/3 → Review/Runtime gate. line 32 `... worktree tracking + Gate 2 iter counter reporting만 보존.` → `... + Review gate iter counter reporting만 보존.`

- [ ] **Step 2: 구조 트리 (lines 44-73)**

- line 44 `├── agents/                 # Gate agent (leaf agent; 파이프라인이 dispatch)` (유지)
- line 45 `│   ├── plan-verifier.md         # Gate 1` → **삭제**(파일 없음)
- line 46 `│   ├── runtime-verifier.md      # Gate 3 Step 3 (runner)` → `# Runtime gate Step 3 (runner)`
- line 47 `│   ├── test-scope-validator.md  # Gate 3 Step 2.5 (pre-exec test scope check)` → `# Runtime gate Step 2.5 ...`
- line 48 `│   ├── scout.md                 # Gate 2 Phase 0 ...` → `# Review gate Phase 0 ...`
  - **주의:** `scout.md`/`codex-reviewer.md`/`synthesizer.md`는 실제로 `agents/`에 **없다**(scout/synthesize는 .py 스크립트, codex-reviewer는 v1.27.0 삭제). 이 트리는 이미 부정확. 본 작업 scope는 gate rename이므로 **최소 변경**: 존재하지 않는 파일 라벨의 gate 참조만 비수치화하고, 부정확한 파일 목록 정리는 별도 hygiene(out of scope). 단 line 45 plan-verifier.md는 우리가 방금 삭제했으므로 **제거**.
- line 49 `│   ├── adversarial.md           # Gate 2 Phase 1.5 ...` → `# Review gate Phase 1.5 ...`
- line 50 `│   ├── synthesizer.md           # Gate 2 Phase 1.6 ...` → `# Review gate Phase 1.6 ...`
- line 51 `│   ├── codex-reviewer.md        # Gate 2 Phase 1 ...` → `# Review gate Phase 1 ...`
- line 52 `│   └── security-reviewer.md     # Gate 2 Phase 1 always-run ...` → `# Review gate Phase 1 always-run ...`
- line 67 `│   ├── discover-plan.sh                      # Plan 파일 우선순위 탐색 (Gate 1)` → `# Plan 파일 우선순위 탐색 (Runtime gate test-scope-validator)` (AC3: discover-plan이 "gate 1" 근처에 없게)
- line 68 `│   ├── detect-runtime.sh                     # Gate 3 런타임 surface 탐지 ...` → `# Runtime gate 런타임 surface 탐지 ...`
- line 69 `│   ├── compute-test-scope-candidates.sh      # Gate 3 Step 2.5 ...` → `# Runtime gate Step 2.5 ...`
- line 71 `│   ├── build_codex_prompt.py                 # Gate 2 Phase 1 codex-reviewer용 prompt builder` → `# Review gate Phase 1 codex-reviewer용 prompt builder`

- [ ] **Step 3: Cost 섹션 (lines 110, 114) — wall-clock ceiling 제거 (AC13)**

- line 110 `The optional \`codex-reviewer\` agent has \`cost_class: variable\` — it invokes the user's Codex CLI subscription/API on each \`standard\`/\`deep\` Gate 2 dispatch. First-use cost consent gate prompts via \`AskUserQuestion\`. Per-call wall-clock ceiling: 600s (proxy for cost ceiling — Codex CLI does not currently expose a token cap flag). Disable globally with \`DEVBREW_DISABLE_QG_CODEX=1\`.` → `The optional \`codex-reviewer\` agent has \`cost_class: variable\` — it invokes the user's Codex CLI subscription/API on each \`standard\`/\`deep\` Review gate dispatch. First-use cost consent gate prompts via \`AskUserQuestion\`. Disable globally with \`DEVBREW_DISABLE_QG_CODEX=1\`.` (wall-clock 문장 삭제)
- line 114 (adversarial) `... so adversarial is the *single model-based judgment gate* in Gate 2 ... Runs ~once per Gate 2 fix-loop iteration (≤5×). ... To reduce its cost, lower the *number* of Gate 2 iterations or the diff scope ...` → `Gate 2` 3곳 모두 `Review gate`로.

- [ ] **Step 4: 게이트 표 (lines 116-124) — 2행으로 (AC10)**

```
| Gate | 주체 | 목적 | 위임 대상 |
|------|-----|------|---------|
| 1 | plan-verifier agent | plan checkbox와 git diff 교차 확인; `gate1_summary` YAML을 Gate 2로 핸드오프 | feature-dev:code-explorer (구현 추적), superpowers:verification-before-completion (증거) |
| 2 | quality-pipeline skill (inline) | scout 주도 orchestration: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (review agent들) |
| 3 | runtime-verifier agent | 앱 시작, 콘솔 에러 확인, 스크린샷 | chrome-devtools-mcp 또는 playwright |
```
→
```
| 게이트 | 주체 | 목적 | 위임 대상 |
|------|-----|------|---------|
| Review gate | quality-pipeline skill (inline) | scout 주도 orchestration: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (review agent들) |
| Runtime gate | runtime-verifier agent | 앱 시작, 콘솔 에러 확인, 스크린샷 | chrome-devtools-mcp 또는 playwright |
```
- line 124 아키텍처 메모 `**아키텍처 메모 — 왜 Gate 2는 agent가 없는가**: ... Gate 2는 여러 Phase로 ... Gate 1과 3은 leaf agent ...` → `**아키텍처 메모 — 왜 Review gate는 agent가 없는가**: Claude Code는 skill만 (agent가 아닌) \`Agent()\`의 \`subagent_type\`을 사용 가능. Review gate는 여러 Phase로 review agent를 dispatch해야 하므로 orchestration 로직이 \`skills/quality-pipeline/SKILL.md\`에 직접 있습니다. Runtime gate는 leaf agent (sub-agent dispatch 안 함).`

- [ ] **Step 5: Gate 2 단계 헤딩 + 흐름 (lines 126, 148-208)**

- line 126 `## Gate 2 리뷰 단계 (v1.5.0 재설계)` → `## Review gate 리뷰 단계 (v1.5.0 재설계)`
- line 146 `... 최대 fan-out: Phase 1 (4) + ...` (유지 — gate 참조 없음)
- line 150 `... Inter-gate progression과 Gate 2 fix-loop iteration은 ...` → `... Review gate fix-loop iteration은 ...`
- **다이어그램 (lines 153-206)** 재작성 — Gate 1 dispatch 박스 제거, Gate 2/3 → Review/Runtime gate. test_readme_state_diagram_complete.sh marker와 정확히 일치해야 함(Step 9). 핵심 marker 텍스트: `setup-qg.sh`, `SKILL preflight`, `trivia escape`, `Review gate iter loop`, `Runtime gate dispatch`, `AskUserQuestion`, `findings remain`, `Runtime`, `Final summary`. Gate 1 dispatch 블록(lines 168-177)과 FAIL 분기를 제거하고 trivia escape → Review gate iter loop로 직결. 예:
```
│   trivia escape? ─── yes ──▶ "Trivia diff — all gates skipped"        │
│       │ no                                                            │
│       ▼                                                               │
│   Review gate iter loop (≤5)                                          │
│       ├── findings empty ──▶ Runtime gate                             │
│       └── findings remain ──▶ AskUserQuestion                         │
│                              ("findings remain..."                    │
│                               Retry / Proceed to Runtime gate / Stop) │
│                                       │                               │
│   Runtime gate dispatch (runtime-verifier)                            │
│       ├── PASS / FAIL / SKIP_WITH_EVIDENCE                            │
│       └── NEEDS_RESOLUTION ──▶ AskUserQuestion                        │
│                               ("Runtime verifier needs..." P21)       │
│       ▼                                                               │
│   Final summary                                                       │
```
(ASCII 박스 정렬은 엄밀할 필요 없음 — test는 marker 문자열 존재만 grep. 단 위 9개 marker가 README에 정확히 등장해야 함.)
- line 208 `**v1.32.0 변경 요약**: ... AskUserQuestion이 subagent fan-out gate와 inter-gate progression gate를 함께 담당합니다.` (gate 참조 없음 — 유지) 단 위 단락에 `Gate 2`가 있으면 Review gate로.

- [ ] **Step 6: 사용 블록 (lines 232-235) 서브커맨드**

```
/qg gate1                      # plan 검증만
/qg gate2                      # PR 리뷰만
/qg gate3                      # 런타임 검증만
/qg --skip-runtime             # Gate 1 & 2만
```
→
```
/qg review                     # Review gate만
/qg runtime                    # Runtime gate만
/qg --skip-runtime             # Review gate만 (런타임 skip)
```
- line 257 (worktree recipe) `2. 그 안에서 Gate 1 → 2 → 3 실행, ...` → `2. 그 안에서 Review gate → Runtime gate 실행, ...`

- [ ] **Step 7: Plan Discovery Sources (lines 276-278) reframe (AC3)**

- line 276 `## Plan Discovery Sources (Gate 1)` → `## Plan Discovery Sources (Runtime gate test-scope-validator)`
- line 278 `\`/qg gate1\`이 \`--plan <path>\`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 ...` → `Runtime gate의 test-scope-validator가 \`--plan <path>\`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 (\`scripts/discover-plan.sh\`) ...`

- [ ] **Step 8: 사전요건 표 (lines 296-299) + Tuning knobs (305, 309) + kill switch (333, 345)**

- line 296 `| pr-review-toolkit | 예 | Gate 2 | 핵심 review agent |` → `| pr-review-toolkit | 예 | Review gate | 핵심 review agent |`
- line 297 `| feature-dev | 아니오 | Gate 1, 2 | 컨벤션 리뷰, 아키텍처, 구현 추적 |` → `| feature-dev | 아니오 | Review gate | 컨벤션 리뷰, 아키텍처, 구현 추적 |`
- line 298 `| superpowers | 아니오 | Gate 1, 2 | plan 정합성, 증거 검증 |` → `| superpowers | 아니오 | Review gate | plan 정합성, 증거 검증 |`
- line 299 `| chrome-devtools-mcp / playwright | 아니오 | Gate 3 | 브라우저 자동화 |` → `| ... | 아니오 | Runtime gate | 브라우저 자동화 |`
- line 305 `- \`MAX_GATE2_ITERATIONS\`: 5 (Gate 2 내부 review-fix 사이클 수)` → `- \`MAX_REVIEW_ITERATIONS\`: 5 (Review gate 내부 review-fix 사이클 수)`
- line 309 `- \`DEVBREW_GATE3_MAX_RESOLUTIONS\`: 3 (\`0..10\`, Gate 3 NEEDS_RESOLUTION mid-run 루프 cap)` → `- \`DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS\`: 3 (\`0..10\`, Runtime gate NEEDS_RESOLUTION mid-run 루프 cap)`
- line 322 `**Reviewer 단위 disable (Gate 2):**` → `**Reviewer 단위 disable (Review gate):**`
- line 329 `**Gate 3 단위 disable:**` → `**Runtime gate 단위 disable:**`
- line 333 `| \`DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1\` | Gate 3 Step 2.5 (test scope validation) 완전 skip. \`DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope\`과 동일. |` → `| \`DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION=1\` | Runtime gate Step 2.5 (test scope validation) 완전 skip. \`DEVBREW_SKIP_HOOKS=quality-gates:runtime-test-scope\`과 동일. |`
- line 345 `| \`quality-gates:gate3-test-scope\` | (위 \`DEVBREW_DISABLE_GATE3_TEST_VALIDATION\`과 동의어) | Gate 3 Step 2.5 |` → `| \`quality-gates:runtime-test-scope\` | (위 \`DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION\`과 동의어) | Runtime gate Step 2.5 |`
- line 353 (파이프라인 state 설명) `\`pipeline.md\` — 파이프라인 frontmatter (status, current_gate, iteration counters) ...` (gate 참조 없음 — 유지)

- [ ] **Step 9: test_readme_state_diagram_complete.sh marker 갱신 (lines 30-41)**

EXPECTED_MARKERS 배열에서:
```bash
  "Gate 1 dispatch"
  "Gate 2 iter loop"
  "Gate 3 dispatch"
```
→
```bash
  "Review gate iter loop"
  "Runtime gate dispatch"
```
("Gate 1 dispatch" 줄 제거; 나머지 marker `setup-qg.sh`/`SKILL preflight`/`trivia escape`/`AskUserQuestion`/`findings remain`/`Runtime`/`Final summary`는 유지). PASS 메시지의 marker count 자동 반영.

- [ ] **Step 10: README file-local sweep**

Run:
```bash
grep -niE "gate ?[123]|GATE_?[123]|gate1_summary|wall.?clock|wall_clock" plugins/quality-gates/README.md || echo "README clean OK"
```
Expected: `README clean OK`. (주의: "Review gate"/"Runtime gate"는 미매칭.)

- [ ] **Step 11: README 게이트 표 2행 + diagram 테스트 green**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh && echo "diagram test green OK"
# 게이트 표 2 데이터행 확인 (Review gate / Runtime gate)
grep -cE "^\| (Review gate|Runtime gate) \|" plugins/quality-gates/README.md   # expect 2
```
Expected: `diagram test green OK`; 게이트 표 데이터행 = 2.

- [ ] **Step 12: Commit**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
git commit -m "docs(quality-gates)!: README 2-gate (Review/Runtime), drop wall-clock ceiling note

게이트 표 2행, 다이어그램에서 Gate 1 dispatch 박스 제거, codex wall-clock ceiling
문장 삭제(AC13), 서브커맨드 review|runtime, env/hook 키 rename.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: philosophy — AP16 wall-clock guard 제거 + gate 참조 비수치화 (Phase D)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md` (lines ~201, 329, 363, 434, 456 — 편집 위치 힌트, 패턴으로 재확인)

라인 번호는 위치 힌트일 뿐. AC15는 content-based(`grep -nE "Gate [0-9]"` → 0).

- [ ] **Step 1: AP16 guard 목록에서 wall-clock 제거 (line ~434, AC14)**

```
... 모든 autonomous 루프는 다음을 가져야 함: (a) max iteration 카운트, (b) wall-clock budget, (c) repeat 감지 (P18), (d) 사용자-overrideable kill switch (OMC의 `DISABLE_OMC=1`과 `cancel-qg`가 템플릿).
```
→
```
... 모든 autonomous 루프는 다음을 가져야 함: (a) max iteration 카운트, (b) repeat 감지 (P18), (c) 사용자-overrideable kill switch (OMC의 `DISABLE_OMC=1`과 `cancel-qg`가 템플릿).
```

- [ ] **Step 2: §4.5 Runtime 항목 gate 참조 (line ~201)**

```
... 이것이 오늘의 `quality-gates/` Gate 3이며, 모든 플러그인의 모델이 되어야 함.
```
→
```
... 이것이 오늘의 `quality-gates/` Runtime gate이며, 모든 플러그인의 모델이 되어야 함.
```

- [ ] **Step 3: cycle spine 서술 (line ~329) — Gate 1 + loop back 제거 (AC15·AC16)**

```
... devbrew의 `quality-gates`는 이미 spine이 있습니다 (Gate 1 plan → Gate 2 review → Gate 3 runtime, 코드 변경 시 Gate 1로 loop back).
```
→
```
... devbrew의 `quality-gates`는 이미 spine이 있습니다 (Review gate → Runtime gate; plan 단계는 상류 writing-plans / spec-distill 소관).
```
**AC16 주의:** 같은 문장 앞부분의 canonical cycle `"spec → plan → implement → review → verify → compound"`는 **그대로 보존**(별도 문장). `loop back` 문구는 이 줄에서 완전 제거 → AC15의 loop-back 규칙 통과.

- [ ] **Step 4: marketplace 위임 예시 (line ~363)**

```
... `quality-gates`가 이미 이 모델입니다 — Gate 2가 pr-review-toolkit, feature-dev, superpowers agent들에 dispatch.
```
→
```
... `quality-gates`가 이미 이 모델입니다 — Review gate가 pr-review-toolkit, feature-dev, superpowers agent들에 dispatch.
```

- [ ] **Step 5: supply-chain 리뷰 (line ~456)**

```
... 여러 플러그인이 관여할 때 supply-chain 리뷰는 `quality-gates` Gate 2의 일부.
```
→
```
... supply-chain 리뷰는 `quality-gates` Review gate의 일부.
```

- [ ] **Step 6: content-based AC15·AC16·AC17 검증**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
P=docs/philosophy/devbrew-harness-philosophy.md
echo "AC15 'Gate [0-9]' count (expect 0):"; grep -cnE "Gate [0-9]" "$P" || true
echo "AC15 'loop back' lines (expect 0, or no qg/gate match):"; grep -in "loop back" "$P" || echo "  (0 loop back lines OK)"
echo "AC16 cycle preserved (expect >=1):"; grep -cE "spec → plan → implement → review → verify → compound" "$P"
echo "AC17 KEEP markers (each expect >=1):"
grep -cE "P22|Cost Awareness" "$P"; grep -cE "시간 budget" "$P"; grep -cE "attention budget" "$P"
```
Expected: `Gate [0-9]` = 0; `loop back` = 0줄; cycle ≥1; P22/시간 budget/attention budget 각 ≥1. (AP16의 wall-clock guard만 제거; §4.1 "시간 budget"·AP2 "attention budget"·P22 전체 보존.)

**주의:** 본 작업은 `(b) wall-clock budget` guard 한 줄만 제거. P18(정체 감지)의 핵심(max-iter + repeat)은 유지 → unbounded-autonomy 방어 성립(R4). philosophy의 `MAX_GATE2_ITERATIONS` 잔존 참조(line ~772, "하우스 default" 토론 섹션)는 `grep -nE "Gate [0-9]"`(공백+숫자, case-sensitive)에 **미매칭**이고 spec의 enumerated 편집 라인 밖이므로 **건드리지 않는다**(known non-blocking residual — focused scope).

- [ ] **Step 7: Commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md
git commit -m "docs(philosophy): drop AP16 (b) wall-clock budget guard, rename qg gate refs

AP16 autonomous-loop guard 4→3개 (max-iter / repeat / kill switch). qg gate 참조
비수치화(Gate 2/3→Review/Runtime gate), 'Gate 1로 loop back' 제거. P22·시간
budget·attention budget·canonical cycle 보존.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: 메타데이터 — plugin.json v2.0.0 + CHANGELOG (Phase E)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json:4` (version)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json:3` (description "3-gate" → "2-gate")
- Modify: `plugins/quality-gates/CHANGELOG.md` (v2.0.0 항목 추가 — 최상단)

- [ ] **Step 1: plugin.json version + description**

```json
  "description": "3-gate quality verification pipeline with multi-plugin review delegation. Invoke manually via /qg.",
  "version": "1.32.3",
```
→
```json
  "description": "2-gate quality verification pipeline (review + runtime) with multi-plugin review delegation. Invoke manually via /qg.",
  "version": "2.0.0",
```

- [ ] **Step 2: CHANGELOG v2.0.0 항목 추가 (line 5, `## [1.32.3]` 직전)**

`## [1.32.3] — 2026-05-28` 줄 바로 위에 아래 블록 삽입(Korean-primary, Keep a Changelog 포맷):
```markdown
## [2.0.0] — 2026-05-30

**BREAKING.** Gate 1(plan verification) 제거 + wall-clock budget 제거 + 두 게이트
비수치 rename. plan 검증은 상류 `superpowers:writing-plans` / `spec-distill`가 담당하는
중복 단계였고, v1.32.0 single-turn 재설계 후 남은 wall-clock 잔재를 정리.

### Removed
- **`agents/plan-verifier.md`** + **`tests/test_plan_verifier_behavior.py`**: Gate 1
  plan-verifier agent 완전 제거. plan 검증은 writing-plans/spec-distill 소관.
- **`/qg gate1` 서브커맨드**: 제거 (alias 없음).
- **scout `gate1_verdict` 입력 필드** + reviewer dispatch의 `gate1_summary` 핸드오프: 제거.
- **codex per-call 600s wall-clock timeout** (`run_codex_reviewer.sh`의 `timeout 600`
  래퍼·`no_timeout_binary` 분기·`OVERRIDE_REASON=timeout`): 제거. hang 위험은 수용 —
  backstop은 Bash tool timeout + `DEVBREW_DISABLE_QG_CODEX=1` + `/cancel-qg`.
- **README wall-clock budget deferred 노트** + codex "Per-call wall-clock ceiling: 600s"
  표현: 제거.
- **철학 문서 AP16 `(b) wall-clock budget` guard**: 제거 (autonomous-loop guard 4→3개:
  max-iter / repeat 감지 / kill switch).
- **state-file-format `wall_clock_deadline_at`** 행: 제거.

### Changed
- **게이트 비수치 rename**: `Gate 2: PR Review` → **Review gate**, `Gate 3: Runtime
  Verification` → **Runtime gate**. "gate" 명사는 플러그인 이름·`/qg`와 정합 위해 유지.
- **서브커맨드**: `/qg gate2` → `/qg review`, `/qg gate3` → `/qg runtime`.
- **env var**: `DEVBREW_GATE3_MAX_RESOLUTIONS` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`;
  `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` → `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`.
- **hook 키**: `quality-gates:gate3-test-scope` → `quality-gates:runtime-test-scope`.
- **state 필드**: `gate3_max_resolutions` → `runtime_max_resolutions`.
- **내부 식별자**: `max_gate2_iterations` → `max_review_iterations`; `gate3-evidence.md`
  → `runtime-evidence.md`; `gate3_fail` → `runtime_fail`; `gate3_repeat_detected` →
  `runtime_repeat_detected`; synthesize heading `## Gate 2 Findings` → `## Review Findings`.
- **유지**: `scripts/discover-plan.sh` + "Plan Discovery Sources" 문서 (Runtime gate의
  test-scope-validator가 `plan_path:auto`로 소비 — plan *verify*만 제거, plan *discovery*는 존속).
  P22 Cost Awareness·`cost_class`·Cost Class % 표·`detect_codex.sh` 5s probe도 유지.

### Migration (1.32.3 → 2.0.0)

**Deprecated alias 없음** — clean break (P17 사용자 주권 우선, P23 deprecation-window
하우스 룰의 의도적 예외; major bump가 breaking을 신호). 구→신 매핑:

| old | new |
|---|---|
| `/qg gate1` | *(제거 — plan 검증은 writing-plans/spec-distill)* |
| `/qg gate2` | `/qg review` |
| `/qg gate3` | `/qg runtime` |
| `DEVBREW_GATE3_MAX_RESOLUTIONS` | `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` |
| `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION` |
| `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` | `...=quality-gates:runtime-test-scope` |

구 `gate1`/`gate2`/`gate3` 서브커맨드와 `DEVBREW_GATE3_*` env는 **즉시 무효** — 스크립트·CI에서
참조 중이면 위 표대로 갱신 필요.
```

- [ ] **Step 3: CHANGELOG Korean-primary 검증 (있으면)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py 2>&1 | tail -5 || echo "(checker는 [1.32.0] 전용일 수 있음 — 출력 확인)"
```
Expected: 통과 또는 `[1.32.0]` 전용이라 신규 항목 미검사. 신규 v2.0.0 항목은 Korean-primary(영어는 식별자/원문 인용에 한정)로 작성됨을 육안 확인.

- [ ] **Step 4: plugin.json 유효성 + 버전 확인**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 -c "import json; d=json.load(open('plugins/quality-gates/.claude-plugin/plugin.json')); print('version', d['version']); assert d['version']=='2.0.0'"
grep -c "## \[2.0.0\] — 2026-05-30" plugins/quality-gates/CHANGELOG.md   # expect 1
```
Expected: `version 2.0.0`; CHANGELOG 항목 1개.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "chore(quality-gates): v2.0.0 — plugin.json bump + CHANGELOG + Migration note

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: 최종 검증 — AC battery + 전체 스위트 + R1 backstop (Verification Plan)

모든 AC를 기계적으로 검증하고, 테스트 스위트가 baseline 대비 악화되지 않았음(9→8 red, 새 red 0)을 확인한다. 이 Task는 코드 변경 없음(검증만; 실패 시 해당 Task로 회귀).

- [ ] **Step 1: Canonical SRC_GREP 0-count sweeps (AC3·AC8·AC11·AC12)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
SRC_GREP() { grep -rniE "$1" plugins/quality-gates --include='*.md' --include='*.py' --include='*.sh' --include='*.json' | grep -vE '/tests/|/CHANGELOG\.md' || true; }
echo "AC3 plan-verifier|gate ?1 (expect 0):"; SRC_GREP "plan-verifier|gate ?1" | wc -l
echo "AC3 discover-plan near gate1 (expect 0):"; SRC_GREP "discover-plan.{0,40}gate ?1|gate ?1.{0,40}discover-plan" | wc -l
echo "AC8 gate ?[123]|GATE_?[123] (expect 0):"; SRC_GREP "gate ?[123]|GATE_?[123]" | wc -l
echo "AC11 no_timeout_binary|OVERRIDE_REASON=timeout (expect 0):"; SRC_GREP "no_timeout_binary|OVERRIDE_REASON=timeout" | wc -l
echo "AC12 wall-clock|wall_clock|timeout 600 (expect 0):"; SRC_GREP "wall-clock|wall_clock|timeout[[:space:]]+600" | wc -l
echo "--- gate1_summary|gate1_verdict (expect 0) ---"; SRC_GREP "gate1_summary|gate1_verdict" | wc -l
```
Expected: 모든 줄이 `0`. 0이 아니면 매칭 파일을 해당 Task로 회귀 수정.

- [ ] **Step 2: 신규 식별자 positive 확인 (AC8 후반)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
SRC_GREP() { grep -rniE "$1" plugins/quality-gates --include='*.md' --include='*.py' --include='*.sh' --include='*.json' | grep -vE '/tests/|/CHANGELOG\.md' || true; }
for id in "DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS" "DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION" "quality-gates:runtime-test-scope"; do
  n=$(SRC_GREP "$id" | wc -l); echo "$id: $n (expect >=1)"
done
```
Expected: 세 식별자 모두 ≥1.

- [ ] **Step 3: SKILL/commands 구체 검증 (AC4·AC5·AC9)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
S=plugins/quality-gates/skills/quality-pipeline/SKILL.md
echo "AC4 Gate 1 sections (expect 0):"; grep -ciE "Gate 1: Plan Verification|Gate 1 FAIL decision" "$S"
echo "AC4 Dispatch Loop (expect >=1):"; grep -cE "Dispatch Loop" "$S"
echo "AC9 qg.md/setup-qg gate2|gate3 alias (expect 0):"; grep -ciE "gate ?[23]" plugins/quality-gates/commands/qg.md plugins/quality-gates/scripts/setup-qg.sh | paste -sd+ | bc 2>/dev/null || grep -ciE "gate ?[23]" plugins/quality-gates/commands/qg.md plugins/quality-gates/scripts/setup-qg.sh
echo "AC9 review/runtime present in qg.md (each expect >=1):"; grep -cE "\breview\b" plugins/quality-gates/commands/qg.md; grep -cE "\bruntime\b" plugins/quality-gates/commands/qg.md
echo "AC10 README 게이트 표 2행:"; grep -cE "^\| (Review gate|Runtime gate) \|" plugins/quality-gates/README.md
```
Expected: Gate-1 sections = 0; Dispatch Loop ≥1; gate2|gate3 alias = 0; review/runtime ≥1; 게이트 표 = 2.

- [ ] **Step 4: 철학 + regression KEEP 검증 (AC14·AC15·AC16·AC17·AC18·AC19)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
P=docs/philosophy/devbrew-harness-philosophy.md
echo "AC15 Gate [0-9] in philosophy (expect 0):"; grep -cnE "Gate [0-9]" "$P" || echo 0
echo "AC15 loop back (expect 0):"; grep -ic "loop back" "$P"
echo "AC16 canonical cycle (expect >=1):"; grep -cE "spec → plan → implement → review → verify → compound" "$P"
echo "AC14 AP16 guard no wall-clock (expect 0 within guard line):"; grep -nE "max iteration .* wall-clock" "$P" || echo "0 (guard cleaned)"
echo "AC17 KEEP cost_class (expect >=1):"; grep -cE "cost_class" plugins/quality-gates/skills/quality-pipeline/SKILL.md
echo "AC17 KEEP Cost Class table (expect >=1):"; grep -cE "Cost Class" plugins/quality-gates/README.md
echo "AC17 KEEP P22 (expect >=1):"; grep -cE "P22|Cost Awareness" "$P"
echo "AC17 KEEP 시간 budget (expect >=1):"; grep -cE "시간 budget" "$P"
echo "AC17 KEEP attention budget (expect >=1):"; grep -cE "attention budget" "$P"
echo "AC18 detect_codex 5s probe (CORRECTED grep — see plan note #2; expect >=1):"; grep -cE '"\$TIMEOUT_BIN" 5 codex --version' plugins/quality-gates/scripts/detect_codex.sh
echo "AC19 reviewer disallowedTools (expect 4 files):"; grep -lE "disallowedTools" plugins/quality-gates/agents/adversarial.md plugins/quality-gates/agents/runtime-verifier.md plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/test-scope-validator.md | wc -l
```
Expected: Gate[0-9]=0; loop back=0; cycle≥1; guard cleaned; cost_class≥1; Cost Class≥1; P22≥1; 시간 budget≥1; attention budget≥1; **AC18 corrected grep ≥1** (spec의 원본 AC18 grep은 `.{0,4}`+대소문자 문제로 0 반환 — plan 상단 차이 #2 참조); disallowedTools = 4.

- [ ] **Step 5: 메타데이터 (AC20·AC21)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
echo "AC20 version 2.0.0:"; python3 -c "import json;print(json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])"
echo "AC21 CHANGELOG entry:"; grep -c "## \[2.0.0\] — 2026-05-30" plugins/quality-gates/CHANGELOG.md
echo "AC21 Migration note:"; grep -c "Migration" plugins/quality-gates/CHANGELOG.md
```
Expected: `2.0.0`; CHANGELOG 항목=1; Migration≥1.

- [ ] **Step 6: 전체 테스트 스위트 — baseline 대비 검증 (AC22, 집중 scope)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
echo "===== BASH ====="
for t in plugins/quality-gates/tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS $(basename $t)" || echo "FAIL $(basename $t)"
done | tee /tmp/qg_v2_after.txt
echo "===== HARNESS ====="
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh >/dev/null 2>&1 && echo "PASS harness" || echo "FAIL harness"
echo "===== PYTHON (개별) ====="
for t in plugins/quality-gates/tests/test_*.py; do
  python3 "$t" >/dev/null 2>&1 && echo "PASS $(basename $t)" || echo "FAIL $(basename $t)"
done | tee -a /tmp/qg_v2_after.txt
echo "===== FAIL 집합 (정확히 아래 8개여야 함) ====="
grep '^FAIL' /tmp/qg_v2_after.txt | sort
```
Expected FAIL 집합 = **정확히 이 8개** (baseline 9개에서 `test_skill_orchestration.sh`가 빠진 것):
```
FAIL test_codex_backward_compat.sh
FAIL test_codex_dispatch_invariant.sh
FAIL test_codex_reviewer_frontmatter.sh
FAIL test_consent_marker_write_failure.sh
FAIL test_sandbox_enforced.sh
FAIL test_scout_codex_integration.sh
FAIL test_security_reviewer_kill_switch.sh
FAIL test_skill_codex_skip_prose.sh
```
- `test_plan_verifier_behavior.py`는 삭제됨(목록에 없어야 정상).
- 위 8개 외 **새 FAIL이 하나라도 있으면** 해당 테스트가 가리키는 source/test를 회귀 수정.
- `test_skill_orchestration.sh`가 FAIL이면 Task 3 Step 15 재확인.

**AC22 판정 (집중 scope):** PASS 조건 = "(i) 위 8개 정확히 FAIL, (ii) 그 외 모든 테스트 PASS, (iii) `test_skill_orchestration.sh` 포함 내가 수정/생성한 테스트 전부 PASS." 8개는 codex/consent/security/sandbox 관련 pre-existing stale red(이 작업 scope 밖, Task 0 baseline에 박제).

- [ ] **Step 7: R1 backstop 수동 확인 (의도적 non-AC, 1행 기록)**

codex 600s 제거의 hang 위험 backstop 2개가 동작함을 확인(non-blocking). 실제 `/qg` 실행은 대화형이므로, kill-switch/detect 경로만 sanity 확인:
```bash
cd /Users/jeonghokim/Downloads/devbrew
echo "(i) kill switch — detect_codex가 skip 반환:"
DEVBREW_DISABLE_QG_CODEX=1 bash plugins/quality-gates/scripts/detect_codex.sh
echo "(ii) /cancel-qg core 스크립트 존재·실행 가능:"
test -x plugins/quality-gates/scripts/cancel-qg-core.sh && echo "cancel-qg-core present & executable"
```
Expected: (i) `codex_available: false` + `skip_reason: kill_switch`; (ii) present & executable. 1행 기록: "R1 backstop 확인 — DEVBREW_DISABLE_QG_CODEX=1 → codex skip, /cancel-qg 스크립트 정상. 둘 다 hang 없음."

- [ ] **Step 8: (변경 없으면 커밋 불필요) 최종 상태 정리**

검증만 수행했으면 커밋 없음. 회귀 수정이 있었으면 해당 Task 패턴으로 커밋. 마지막으로:
```bash
cd /Users/jeonghokim/Downloads/devbrew
git status
git log --oneline -13
```
Expected: working tree clean; Task 1~13의 커밋 + spec 커밋이 브랜치에 누적.

---

## 부록: 작업 순서 의존성 + 회귀 가이드

- **Task 0 → 1 → 2 → 3 → … → 14** 순서 권장. Task 3(SKILL)·Task 4(setup-qg)·Task 11(README)는 internal 식별자(`max_review_iterations`, `runtime_max_resolutions`, env)를 **명명 맵 그대로** 써야 타입 일관성 유지.
- 각 Task의 file-local sweep은 그 파일만 검사 → 통과해도 **전역 AC8/AC3/AC12 sweep(Task 14 Step 1)은 모든 Task 완료 후에만** 0이 된다(중간 커밋에서 전역 sweep이 0이 아닌 것은 정상 — WIP 브랜치).
- 테스트는 **항상 repo root에서** 실행(`bash plugins/quality-gates/tests/test_x.sh`). 플러그인 디렉토리 안에서 실행하면 경로 doubling으로 spurious FAIL(예: `synthesize_findings.py`/`scout.py` 경로 doubling).
- Python 테스트는 **개별 파일 `python3 <file>`**. `pytest tests/`는 `tests/fixtures/test-scope/*/tests/*.py`(DIFF fixture)를 collection error로 잡으니 금지.
- 8개 orthogonal stale red(Task 0)는 **건드리지 않는다**. 만약 v2.0.0에서 이들도 정리하길 원하면 별도 spec/plan(집중 scope 결정에 따라 이 작업 밖).
- **`tests/e2e-scenarios.md`** (수동 시나리오 문서, 비실행)도 gate 참조·`/qg --gate3` 표기를 보유하나 `tests/`라 SRC_GREP 제외 + 테스트 러너가 실행하지 않음 → **out of scope**(집중 scope; 별도 hygiene). README 구조 트리의 부정확한 `scout.md`/`codex-reviewer.md`/`synthesizer.md` agent 파일 라벨(실제 부재)도 같은 사유로 본 작업 밖 — gate 번호만 비수치화하고 파일 목록 정합은 건드리지 않음.
- **`tests/mocks/bin-stubs/{gtimeout,timeout}`·`detect_codex.sh`는 절대 삭제/수정 금지**(Task 6 핵심 함정) — detect_codex 5s probe가 timeout 바이너리를 계속 요구.
