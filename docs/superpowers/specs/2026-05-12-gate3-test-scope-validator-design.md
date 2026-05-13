# Gate 3 Test Scope Validator — Design

**작성일:** 2026-05-12
**대상 플러그인:** `quality-gates` (v1.8.1 → v1.9.0)
**관련 sister spec:** [`2026-05-10-gate3-active-verification-design.md`](2026-05-10-gate3-active-verification-design.md) — Gate 3 active verification 도입 (v1.8.0). 이 spec은 그 위에 light-weight pre-execution test scope check 한 단계를 얹는다.

## 1. Context / Why

`/qg`의 Gate 3는 v1.8.0부터 `runtime-verifier` agent가 manifest의 test_runners (e.g., `npm test`, `pytest`)를 실제로 실행하고 exit code로 PASS/FAIL을 판정한다. 그러나 **테스트 자체의 품질·정합성은 검증되지 않는다.** 사용자 보고:

> "gate3상에서 test 코드가 이미 존재할 경우 이번에 할 스콥의 test 대해서는 검증을 진행하고 실행으로 가는게 좋을듯해 엄격한 검증이 아니라 맞는지 아닌지 이러한 느낌으로 test가 outdated하거나 test자체가 writer가 체리피킹하려고 만든 거일수도 있자나 어디서 이 롤을 가져갈지 구현방식은 고민필요"

**두 가지 silent-pass 경로:**

1. **Outdated test silently pass:** 운영 코드의 동작 X가 X'으로 변경되었으나 그 동작을 검증하는 기존 test 파일은 이번 PR에서 수정되지 않아 여전히 X에 대한 assertion을 유지 — `npm test`/`pytest`는 exit code 0이지만 실제로는 잘못된 동작을 보장. Gate 2의 `pr-test-analyzer`는 `test_change==1`일 때만 fire하므로 운영 코드만 바꿨을 때 발견 못 함.
2. **Cherry-picked test:** writer가 coverage 수치를 채우기 위해 `assert True` / `assert obj is not None` 류의 tautological assertion을 추가. Gate 2의 `pr-test-analyzer`는 coverage gap 관점에서 검토하지만 "이 assertion이 실제로 plan scope의 behavior를 검증하는가"는 명시적으로 보지 않음.

**왜 이게 Law 1 / Law 2 / §5.3 이슈인가:**

- **Law 1 (Clarity Before Code → Verification Plan):** spec의 acceptance criteria가 실제 검증되려면 test가 그 AC를 assert해야 함. AC와 test 사이의 silent drift는 Verification Plan의 무력화.
- **Law 2 (Writer/Reviewer separation):** runtime-verifier는 *runner* 역할. *test reviewer* 역할은 같은 agent에 합치면 cognitive boundary가 흐려진다. 3-way 분리 (writer / test-scope-validator / runtime-verifier)가 더 깨끗하다.
- **devbrew §5.3 (no numeric scoring):** 검증은 *시그널* (`aligned | outdated-suspicion | cherry-pick-suspicion | unclear`)이지 수치 스코어가 아니어야 함.

**왜 새 agent인가 (rejected alternatives §9 참조):** Gate 2의 `pr-test-analyzer` 확장은 (a) trigger gate (`test_change==1`)가 outdated-test 케이스를 놓치고, (b) Gate 2/3 책임 경계를 흐리며, (c) upstream 플러그인 (`pr-review-toolkit`) 수정이 필요해 부적합. runtime-verifier 확장은 reviewer/runner 합쳐서 Law 2 spirit 위반.

## 2. Goals

- Gate 3가 test runner를 실행하기 **전에** 한 단계의 light-weight check 추가 — scope-relevant test 파일들이 plan items + diff의 behavior 변경과 정합하는지 분류.
- 검증 결과는 **informational/warning** — Gate 3의 기존 verdict 모델 (PASS/FAIL/SKIP_WITH_EVIDENCE/NEEDS_RESOLUTION)을 건드리지 않음. stop-hook의 continuation 분기에도 변경 없음.
- 검증 agent는 `Write`/`Edit` 물리 차단 (Law 2). cost_class=`low`, 단일 sonnet 호출.
- "이번 스콥의 test" 결정은 **deterministic bash + LLM 판단** 패턴 — skill이 후보 파일 리스트를 결정론적으로 산출, agent가 정합성을 분류 (quality-pipeline §Phase 0 scout와 동일 패턴).
- Trivia escape는 이미 pipeline 전체에서 동작 — 추가 처리 불필요.
- Kill switch 제공: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1`.
- README "Principles Instantiated"에 Law 2 (3-way 분리 강화), §5.3 (no scoring) 추가.

## 3. Non-goals

- Test 자동 생성 / 수정 — `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`로 물리 차단. 의심 검출 시 사용자에게 informational 전달, 수정은 writer 책임 (다음 turn).
- 수치 스코어 (`80/100` 류) — devbrew §5.3 ban. 4-way categorical classification만.
- Blocking 게이팅 — user가 명시적으로 "엄격하지 않은" 검증을 요청. 검증 결과로 인한 Gate 3 FAIL 격상은 본 spec scope 외.
- Test mutation testing / coverage 정밀 분석 — 별도 도구 영역.
- 모든 언어 지원 — heuristic src→test 매핑은 Python/JavaScript/TypeScript만 v1.9.0에서 지원. 다른 언어는 `changed_test_files` 폴백 (diff에서 직접 식별된 test 파일만).
- Gate 2의 `pr-test-analyzer`와 통합 / 중복 제거 — 책임 분리 유지. 두 agent가 다른 입력 (Gate 2: diff 안의 test 파일 / Gate 3: plan scope ∩ candidate test 파일) 으로 다른 시점에 동작.

## 4. Constraints

- 변경은 단일 PR/commit으로 묶여 `git revert` 한 줄로 롤백 가능.
- `plugin.json` SemVer bump: `1.8.1` → `1.9.0` (minor — 새 agent surface).
- `CHANGELOG.md` `## [1.9.0] — 2026-05-12` entry 필수, Added 섹션에 새 agent + Step 2.5 명시.
- README "Principles Instantiated" 섹션 갱신 — Law 2 3-way 분리, §5.3 categorical signal 추가.
- 새 agent `test-scope-validator.md` frontmatter 필수: `allowedTools: [Read, Grep, Glob, Bash]`, `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`, `model: sonnet`, `cost_class: low` — 기존 runtime-verifier.md / plan-verifier.md와 동일하게 agent 자체 frontmatter에 선언.
- 새 env: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` (default unset = enabled). `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope`도 honor.
- Skill의 Step 2.5는 fail-open — bash 후보 산출 실패 / agent dispatch 실패 / YAML parse 실패 시 silently skip하고 evidence-log에 "validation skipped: <reason>" 한 줄만 남김.
- Agent 출력은 plan, diff 외 다른 컨텍스트를 fetch하지 않음 (no WebFetch, no MCP). Read/Grep/Glob/Bash로 candidate 파일만 검사.
- 검증은 stop-hook 변경 없이 동작 — 새 continuation prompt 추가 금지.

## 5. Acceptance Criteria

1. **AC1 — Aligned case silent pass:** 모든 candidate test가 plan scope와 정합 → skill이 한 줄 ("Test scope: 3/3 aligned")만 출력하고 그대로 Step 3 진행. evidence-log preamble에 `## Test Scope Verdicts` 섹션 (모두 aligned) 기록.
2. **AC2 — Outdated suspicion warning:** 1+ test가 outdated-suspicion으로 분류 → user에게 ⚠️ 강조 출력 (test 경로 + 한 줄 evidence). Gate 3 verdict는 그대로 진행, evidence-log carry-forward.
3. **AC3 — Cherry-pick suspicion warning:** 1+ test가 cherry-pick-suspicion으로 분류 → user에게 ⚠️⚠️ 강조 출력. Gate 3 verdict는 그대로 진행, evidence-log carry-forward.
4. **AC4 — Mixed verdicts:** aligned + outdated + cherry-pick이 혼재 → 각 분류별로 그룹화해서 출력, evidence-log에 모두 기록.
5. **AC5 — Empty candidates fast-skip:** changed src 파일이 0개거나 heuristic 매핑이 빈 결과 → validator dispatch 안 함, evidence-log에 "validation skipped: no candidate tests" 한 줄.
6. **AC6 — Kill switch:** `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1`이면 Step 2.5 entry에서 즉시 skip, evidence-log에 "validation skipped: kill switch" 기록. `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope`도 동일 동작.
7. **AC7 — Plugin Shape 준수:** `test-scope-validator.md` frontmatter에 `allowedTools` (`Read`, `Grep`, `Glob`, `Bash`), `disallowedTools` (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`), `model: sonnet`, `cost_class: low` 모두 선언 존재.
8. **AC8 — Fail-open behavior:** validator agent dispatch가 timeout (>60s) 또는 YAML parse 불가 → skill이 "validation skipped: <reason>" 출력하고 Step 3 진행. Gate 3 진행을 방해하지 않음.
9. **AC9 — Output format:** validator의 YAML 출력에 `test_scope_verdicts: [{file, classification, evidence}]` + `summary` 필드 존재. classification ∈ `{aligned, outdated-suspicion, cherry-pick-suspicion, unclear}`. 다른 값은 unparseable로 간주 → AC8 fallback.
10. **AC10 — No numeric scoring:** validator 출력의 `evidence` 필드와 `summary` 필드에 percentage / confidence 숫자 (`70%`, `0.85`, `8/10` 류) 가 포함되지 않음 — 파일 경로 안의 숫자 (`test_v2.py`) 는 허용. summary는 `N aligned, M outdated-suspicion, K cherry-pick-suspicion, L unclear` 형태의 counter 정수만 허용.
11. **AC11 — Heuristic mapping unit test:** `tests/test_test_scope_candidates.sh` (또는 .py) — Python/JS/TS의 src→test 매핑이 expected에 일치. 다른 언어는 빈 결과 + `changed_test_files` 폴백만.
12. **AC12 — Trivia escape compatibility:** trivia diff (typo, rename only)이면 pipeline 전체가 Gate 1 전에 skip하므로 Step 2.5도 자동 skip — 추가 변경 없음 검증.
13. **AC13 — Backward compatibility:** `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1`을 set하면 v1.8.1 동작과 동일 (Gate 3 진행에 영향 없음, evidence-log 한 줄만 추가).
14. **AC14 — stop-hook untouched:** `hooks/stop-hook.py`의 git diff가 비어있다 (이 spec의 commit에서). 새 continuation prompt 없음.
15. **AC15 — Law 2 verification:** validator agent와 runtime-verifier agent는 각각 별도 sub-agent context로 dispatched되며 (skill의 같은 turn에서 순차 호출이지만 각 Agent() 호출은 독립 context), 두 agent 모두 frontmatter에서 `Write`/`Edit`/`MultiEdit`/`NotebookEdit`을 `disallowedTools`로 명시. writer (originating turn의 사용자/Claude) 는 어느 reviewer agent도 아니다.

## 6. Architecture

### 6.1 Data flow

```
┌───────────────────────────────────────────────────────────────┐
│ Gate 3 skill (quality-pipeline SKILL.md)                       │
│                                                                │
│  Step 0  detect-runtime.sh ──┐                                 │
│                              ▼                                 │
│  Step 1  fast-path SKIP?  no ─► continue                       │
│  Step 2  AskUserQuestion (upfront resolution)                  │
│                                                                │
│  ┌── NEW ──────────────────────────────────────────────┐       │
│  │ Step 2.5  Test scope validation                       │      │
│  │   2.5a  kill-switch check (env) — skip if set         │      │
│  │   2.5b  bash: compute candidate_test_files            │      │
│  │   2.5c  if empty → log+skip, goto Step 3              │      │
│  │   2.5d  Agent(test-scope-validator, plan + diff +     │      │
│  │              candidate list)                          │      │
│  │   2.5e  parse YAML, render to user, prepend to        │      │
│  │              evidence-log                              │      │
│  └───────────────────────────────────────────────────────┘     │
│                                                                │
│  Step 3  Agent(runtime-verifier, manifest) ── unchanged        │
│  Step 4  validate evidence-log                                  │
│  Step 5  NEEDS_RESOLUTION handling                              │
│  Step 6  FAIL handling                                          │
└───────────────────────────────────────────────────────────────┘
```

### 6.2 Candidate test file resolution (Step 2.5b bash block)

```bash
# REVIEW_RANGE must be recomputed here — Gate 2's diff-cache and per-iteration
# variables are cleaned up before Gate 2 emits its signal (SKILL.md §"Cache
# Cleanup"). Use the identical formula from Gate 2 Step 0:
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ] \
   && git rev-parse --verify --quiet main >/dev/null \
   && [ -n "$(git log --oneline main..HEAD 2>/dev/null)" ]; then
  REVIEW_RANGE="main...HEAD"
fi

TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|(^|/)tests?/'

# Changed source (non-test) files
CHANGED_SRC=$(git diff $REVIEW_RANGE --name-only \
  | grep -vE "$TESTRE" || true)

# Heuristic src→test mapping (Python, JS, TS only)
MAPPED_TESTS=""
while IFS= read -r src; do
  case "$src" in
    *.py)
      base=$(basename "$src" .py)
      MAPPED_TESTS="$MAPPED_TESTS
$(find . -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) 2>/dev/null)"
      ;;
    *.ts|*.tsx|*.js|*.jsx)
      base=$(basename "$src" | sed 's/\.[^.]*$//')
      MAPPED_TESTS="$MAPPED_TESTS
$(find . -type f \( -name "${base}.test.ts" -o -name "${base}.test.tsx" \
                  -o -name "${base}.test.js" -o -name "${base}.test.jsx" \
                  -o -name "${base}.spec.ts" -o -name "${base}.spec.tsx" \
                  -o -name "${base}.spec.js" -o -name "${base}.spec.jsx" \) 2>/dev/null)"
      ;;
  esac
done <<< "$CHANGED_SRC"

# Changed test files directly in diff
CHANGED_TESTS=$(git diff $REVIEW_RANGE --name-only | grep -E "$TESTRE" || true)

# Union, de-dup, strip leading ./
CANDIDATE=$(printf '%s\n%s\n' "$MAPPED_TESTS" "$CHANGED_TESTS" \
  | sed 's|^\./||' | sort -u | grep -v '^$' || true)
```

### 6.3 Agent contract — `test-scope-validator`

**Inputs (skill이 prompt에 inline):**
- `plan_path`: spec/plan 파일 경로
- `gate1_summary.matched_items`: Gate 1이 produce한 YAML (verbatim)
- `## Current Diff` 섹션 (filtered diff ≤50KB, quality-pipeline §LARGE_DIFF_CHARS 일관성)
- `candidate_test_files`: skill이 산출한 후보 경로 리스트

**Output (단일 YAML fenced block, 메시지의 last block):**

```yaml
test_scope_verdicts:
  - file: <path>
    classification: aligned | outdated-suspicion | cherry-pick-suspicion | unclear
    evidence: "<one-line: max 120 chars, no numbers>"
summary: "<N aligned, M outdated-suspicion, K cherry-pick-suspicion, L unclear>"
```

**Classification 가이드라인 (agent system prompt 일부):**

| classification | 시그널 |
|---|---|
| `aligned` | test의 assertion이 plan items 또는 diff의 변경된 behavior와 일치 |
| `outdated-suspicion` | test가 diff에서 제거·변경된 함수/symbol/behavior를 여전히 assert |
| `cherry-pick-suspicion` | assertion이 tautological (`assert True`, `assert obj is not None` 단독) 또는 plan scope 외 behavior만 검증 |
| `unclear` | 위 셋 중 어디에도 자신 있게 분류 못함 (e.g., 외부 의존성 mock heavy) |

Agent는 자유 서술 / 수치 스코어 / 추가 추천 금지 — 분류 + 한 줄 evidence만.

### 6.4 SKILL.md Step 2.5 의사코드

```
if env.DEVBREW_DISABLE_GATE3_TEST_VALIDATION == "1"
   or "quality-gates:gate3-test-scope" in env.DEVBREW_SKIP_HOOKS:
  evidence_preamble += "validation skipped: kill switch\n"
  goto Step 3

CANDIDATE = <bash block §6.2>
if CANDIDATE is empty:
  evidence_preamble += "validation skipped: no candidate tests\n"
  goto Step 3

try:
  report = Agent(
    subagent_type="quality-gates:test-scope-validator",
    model="sonnet",
    prompt=template(plan_path, gate1_summary, diff, CANDIDATE)
  )
  verdicts = parse_yaml(report.last_yaml_block)
  validate_schema(verdicts)  # AC9, AC10
except (Timeout, ParseError, SchemaError) as e:
  evidence_preamble += f"validation skipped: {e}\n"
  goto Step 3

render_to_user(verdicts)
evidence_preamble += render_evidence_section(verdicts)
goto Step 3
```

### 6.5 Output format (user-facing)

```
## Gate 3 — Test Scope Check
- tests/test_auth.py: aligned
- tests/test_legacy.py: ⚠️ outdated-suspicion — asserts removed parse_v1(); behavior changed in diff but test unchanged
- tests/test_new.py: ⚠️⚠️ cherry-pick-suspicion — single tautological assertion `assert True`; no behavior tested

Summary: 1 aligned, 1 outdated-suspicion, 1 cherry-pick-suspicion. Proceeding to runtime execution; review flagged tests after Gate 3.
```

## 7. Files to Modify

**New:**
- `plugins/quality-gates/agents/test-scope-validator.md` — agent definition (frontmatter scoping + system prompt)
- `plugins/quality-gates/tests/test_test_scope_candidates.sh` — heuristic src→test 매핑 unit test (AC11)
- `plugins/quality-gates/tests/fixtures/test-scope-aligned/` — AC1 fixture
- `plugins/quality-gates/tests/fixtures/test-scope-outdated/` — AC2 fixture
- `plugins/quality-gates/tests/fixtures/test-scope-cherry-pick/` — AC3 fixture

**Modified:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Gate 3 섹션에 Step 2.5 삽입 (Step 2 다음, Step 3 직전)
- `plugins/quality-gates/.claude-plugin/plugin.json` — `1.8.1` → `1.9.0`
- `plugins/quality-gates/CHANGELOG.md` — `## [1.9.0] — 2026-05-12` Added 섹션
- `plugins/quality-gates/README.md` — Principles Instantiated (Law 2 3-way, §5.3 signal) + Agents 섹션에 test-scope-validator 추가 + Hooks/Env 표에 `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` 추가

**Untouched (AC14):**
- `plugins/quality-gates/hooks/stop-hook.py` — 변경 없음, 새 continuation prompt 없음
- `plugins/quality-gates/agents/runtime-verifier.md` — 변경 없음
- `plugins/quality-gates/scripts/detect-runtime.sh` — 변경 없음 (Step 2.5의 candidate 산출은 skill이 inline bash로 수행)

## 8. Verification Plan

1. **Unit test (AC11):** `bash plugins/quality-gates/tests/test_test_scope_candidates.sh` — Python/JS/TS 매핑이 expected에 일치, 다른 언어는 빈 결과 + diff fallback.
2. **Schema validation (AC9, AC10):** validator의 YAML 출력을 합성 케이스 3개 (aligned-only / mixed / cherry-pick) 로 검증. 수치 토큰 없음, classification enum 준수.
3. **Kill switch (AC6):** `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1 /qg --gate3` 실행 시 evidence-log에 "kill switch" 한 줄만 추가되고 Step 3 진행.
4. **Fail-open (AC8):** validator dispatch에 timeout=1s를 합성 주입 → skill이 Step 3 진행, "validation skipped: timeout" 로그.
5. **Backward compatibility (AC13):** v1.8.1 fixture (이전 Gate 3 active verification spec의 fixture 재사용) 에서 `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` set → evidence-log diff가 한 줄 추가 외 동일.
6. **End-to-end (AC1–AC4):** 3개 fixture (`test-scope-aligned`, `test-scope-outdated`, `test-scope-cherry-pick`) 각각에서 `/qg --gate3` 실행, validator의 분류 + skill의 user-facing 출력 + evidence-log entry가 expected와 일치.
7. **Plugin Shape (AC7):** `grep -E "(allowedTools|disallowedTools|model)" plugins/quality-gates/agents/test-scope-validator.md` — 세 필드 모두 존재. README의 Principles Instantiated 섹션이 Law 2 + §5.3 를 cite.
8. **stop-hook untouched (AC14):** `git diff main...HEAD -- plugins/quality-gates/hooks/stop-hook.py` 빈 출력.

## 9. Rejected Alternatives

**R1 — runtime-verifier에 Step 1.5로 통합:** reviewer/runner 책임 합치면 Law 2 spirit 위반. runtime-verifier의 system prompt 부피 증가, cost_class도 변동. 분리 유지가 cognitive boundary와 일관성 모두 우월.

**R2 — Gate 2의 `pr-test-analyzer` prompt 확장:**
- (a) Trigger gate가 `test_change==1`이라 *운영 코드만 바꾸고 기존 test는 unchanged* 케이스 (outdated-test 시그널의 주요 trigger) 를 놓침.
- (b) Gate 2 = code review / Gate 3 = runtime 책임 경계 흐림.
- (c) Upstream 플러그인 (`pr-review-toolkit`) 의 agent를 qg가 prompt-override만 하면 upstream 변경이 silent하게 깨질 위험. devbrew memory `feedback_respect_upstream_model_hardcoding`의 spirit (upstream 존중).

**R3 — Numeric scoring (e.g., test-quality score 0–100):** devbrew §5.3 ban. Adversarial self-review가 categorical signal로 충분. 수치는 false precision을 주고 자동 게이팅 압력을 만든다.

**R4 — Blocking (NEEDS_RESOLUTION) on cherry-pick:** user가 explicit "엄격하지 않은" 검증 요청. Blocking은 stop-hook continuation prompt 추가 필요 → AC14 위반, change surface 확대. Informational warning이면 다음 PR review turn (writer 책임)에서 처리 가능.

**R5 — Static analyzer 통합 (mutmut, mutpy 등):** 외부 의존성 도입, 언어별 분기 폭증, cost_class 상승. devbrew §"default to lightness" memory 위반. LLM 기반 light validator로 v1.9.0 충분.

**R6 — Heuristic 매핑 대신 LLM이 후보 파일 선택:** LLM에 file-system 탐색 추가 권한 → cost 증가, 결정론 약화. quality-pipeline §Phase 0 scout의 "deterministic bash + model judgment" 패턴 유지가 일관성과 비용 모두 우월.

## 10. Metadata

- **SemVer impact:** minor (`1.8.1` → `1.9.0`) — 새 agent surface 추가, 기존 API 변경 없음.
- **Plugins touched:** `quality-gates` only.
- **Discoverability (Law 3):** README "Principles Instantiated"에 신규 entry 두 줄 — Law 2 3-way 분리, §5.3 categorical signal. devbrew memory에는 별도 entry 불필요 (per-PR finding, 원칙 재발견 아님).
- **Rollback:** 단일 commit revert로 모든 surface 제거. kill switch (`DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1`) 로도 즉시 사실상 비활성화 가능.
- **Stagnation signal:** v1.9.0 release 후 30일 동안 cherry-pick-suspicion / outdated-suspicion fire 횟수가 0이면 (a) 모델이 너무 conservative, (b) 실제로 그런 케이스가 없음 중 하나 — manual review 후 prompt 보정.
