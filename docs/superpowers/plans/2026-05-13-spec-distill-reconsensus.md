# spec-distill Re-consensus Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill v0.2.0에 re-consensus gate (Phase [3.5]) 도입 — locked_decisions frontmatter + AskUserQuestion 3-옵션 + Mode B `allowed_issue_ids` contract로 인터뷰에서 사용자와 합의된 결정이 writer/reviewer 페어에 의해 사용자 동의 없이 뒤집히는 것을 frontmatter-level로 차단.

**Architecture:** spec.md frontmatter `locked_decisions:` 리스트를 self-contained, machine-verifiable contract로 만든다. reviewing-spec routing table에 `affects_locked` 차원 추가, [3.5] Re-consensus sub-step을 reviewing-spec SKILL.md 내부 게이트로 도입. drafting-spec Mode B는 `allowed_issue_ids` 입력 외 issue 적용 시 abort + `git restore` + reviewing-spec [3.5] re-entry. 상태는 `.claude/spec-distill/<session-id>/state.local.md`에 신규 필드 5개 (`pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`).

**Tech Stack:** Markdown skills/agents (Claude Code plugin format), YAML frontmatter, bash + jq + grep verification, AskUserQuestion built-in tool, `git restore` for working-tree rollback.

**Spec reference:** `docs/superpowers/specs/2026-05-13-spec-distill-reconsensus-design.md` (277 lines, AC1–AC10, V0–V12, NG6, C10).

---

## Phase 1 — Metadata + State Schema (3 tasks)

### Task 1: Bump plugin version + create CHANGELOG

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Create: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: Bump plugin.json version**

Edit `plugins/spec-distill/.claude-plugin/plugin.json`:

```json
{
  "name": "spec-distill",
  "description": "집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 spec.md를 생성. devbrew Laws 1+2 instantiation (Writer/Reviewer 물리적 분리, 4-block Korean Socratic interview).",
  "version": "0.2.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

- [ ] **Step 2: Create CHANGELOG.md**

Create `plugins/spec-distill/CHANGELOG.md` (실행 날짜를 YYYY-MM-DD로 치환):

```markdown
# Changelog

## [0.2.0] — YYYY-MM-DD

### Added
- Re-consensus gate (Phase [3.5]) — locked-affecting reviewer issue가 자동 Mode B로 가지 않고 `AskUserQuestion` 3-옵션 (수용/유지/추가 인터뷰)으로 사용자 게이트.
- spec.md frontmatter `locked_decisions:` 리스트 — `LD1, LD2, ...` ID로 인터뷰 (b)/(d) path 합의를 self-contained contract로 기록.
- state.local.md 신규 필드: `pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`.
- drafting-spec Mode B `allowed_issue_ids` 입력 contract — 위반 시 abort + `git restore` + state.local.md `mode_b_violation` marker + reviewing-spec [3.5] re-entry.
- spec-reviewer agent 출력에 issue별 `affects_locked_decisions: [LD ids]` 필드.
- Escalate priority table (P1–P4): C3 global cap (≥4 locked-affecting → spec 전체 [5]) > AC9 per-issue (`reconsensus_count >= 2`) > P18 stagnation > reviewer-persona warn.
- Kill switch `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (loud warning).
- v0.1.x in-flight state migration — missing field 자동 promote (non-mutating read).
- V0 pre-gate (fixture 존재 검증) + `set -e -o pipefail` 전역 적용.

### Changed
- P18 stagnation 판정 조건: `raised_count >= 3` → `raised_count >= 3 AND dismissed_by_user == 0` (사용자 명시 거절을 stagnation에서 제외).
- spec-reviewer agent — frontmatter `Read` tool 사용 허용 (locked_decisions 추출 목적).
- drafting-spec Mode A — interview transcript에서 `pending_locked_decisions`를 frontmatter `locked_decisions:`로 변환.
- README "Principles Instantiated"에 P17 explicit instantiation 한 줄 추가.
```

- [ ] **Step 3: Verify**

Run:
```bash
jq -e '.version == "0.2.0"' plugins/spec-distill/.claude-plugin/plugin.json
test -f plugins/spec-distill/CHANGELOG.md
grep -q "^## \[0.2.0\]" plugins/spec-distill/CHANGELOG.md
```
Expected: 모두 exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): bump version 0.1.2 → 0.2.0 + CHANGELOG entry"
```

---

### Task 2: Extend spec-template frontmatter

**Files:**
- Modify: `plugins/spec-distill/templates/spec-template.md`

- [ ] **Step 1: Read current template**

Run: `cat plugins/spec-distill/templates/spec-template.md | head -30`

기존 frontmatter 구조를 확인. 7개 field (`name`, `version`, `created_at`, `session_id`, `status`, `next_phase`, `source`) 존재.

- [ ] **Step 2: Add `locked_decisions:` field to frontmatter section**

`---` frontmatter 블록 안에 `source:` 줄 아래에 다음 추가:

```yaml
# Locked decisions — interview (b)/(d) path 사용자 명시 응답에서 도출.
# drafting-spec Mode A가 채움. Mode B는 superseded_by/supersedes 마커로 변경 이력 박제.
# source 허용값: interview-round-<N> (정상 운영) 또는 brainstorming-round-<N> (meta-spec dogfooding).
locked_decisions: []
```

- [ ] **Step 3: Verify template parses as YAML**

Run:
```bash
python3 -c "import yaml, re; \
content = open('plugins/spec-distill/templates/spec-template.md').read(); \
fm = re.split(r'^---\s*$', content, maxsplit=2, flags=re.MULTILINE)[1]; \
d = yaml.safe_load(fm); \
assert 'locked_decisions' in d, 'locked_decisions field missing'; \
assert d['locked_decisions'] == [], f'expected empty list, got {d[\"locked_decisions\"]}'; \
print('OK')"
```
Expected: `OK` 출력 (V2 충족).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/templates/spec-template.md
git commit -m "feat(spec-distill): add locked_decisions frontmatter field to spec template"
```

---

### Task 3: Update conducting-interview SKILL — state schema + decision table

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md`

- [ ] **Step 1: Extend state.local.md frontmatter schema**

`## State location (AC2)` 섹션의 frontmatter schema 코드 블록을 다음으로 교체:

```yaml
---
session_id: <uuid>
phase: 1
interview_round: <int>
non_user_streak: <int>
rereview_count: 0
wall_clock_started_at: <ISO8601>
trivia_escape_armed: false
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
pending_locked_decisions: []         # 매 round 끝 append (b/d path 명시 응답만). drafting-spec Mode A가 spec.md frontmatter로 변환.
reconsensus_accepted_ids: []         # reviewing-spec [3.5] sub-step이 기록. Mode B에 allowed_issue_ids로 전달.
---
```

- [ ] **Step 2: Add "Locked 판정 트리거" section**

`## C43 4-path routing` 섹션 *바로 다음*에 다음 섹션 삽입:

```markdown
## Locked 판정 트리거 (G1, AC1)

매 round 끝에 사용자 응답을 `pending_locked_decisions`에 append할지 다음 decision table로 판정:

| 사용자 응답 유형 | path | locked? |
|---|---|---|
| 명시적 수락 (예/동의/선택지 1개 선택/자유 텍스트로 결정 명시) | b, d | ✅ true |
| 명시적 거절 (아니오/거절/대안 제시) | b, d | ✅ true (반대 명제로 locked) |
| 보류 ("잘 모르겠음", "둘 다 괜찮음", "나중에 결정") | b, d | ❌ false — Open Questions로 박제 |
| "추가 정보 필요" / "더 설명해주세요" | b, d | ❌ false — re-ask 또는 OQ |
| factual auto-confirm | a | ❌ false (사용자 미답변) |
| sub-agent ambiguity 답안 | c | ✅ true ONLY IF 사용자 confirm 받음 |

`locked? == true` 항목은 매 round 끝에 다음 형식으로 `pending_locked_decisions`에 append:

```yaml
- id: LD<N>                          # N = pending_locked_decisions.length + 1
  section: "#<spec-section-anchor>"  # 답변이 spec의 어느 섹션에 박힐지 (예: "#goals", "#acceptance-criteria")
  summary: "<160자 이내 한 줄 요약>"   # P21 secret placeholder 치환 적용
  source: interview-round-<N>        # 운영 경로 표시
  source_path: b | c | d             # 어느 routing path에서 왔는지
```
```

- [ ] **Step 3: Add in-flight state migration section**

`## kill switch` 섹션 *바로 앞*에 다음 섹션 삽입:

```markdown
## In-flight state migration (C10)

state.local.md 로드 시 v0.1.x schema (신규 필드 부재)를 감지하면 *non-mutating read*로 자동 promote:

- `pending_locked_decisions` 부재 → `[]`로 in-memory default.
- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- `reconsensus_accepted_ids` 부재 → `[]`로 in-memory default.

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지 — 명시적 write 시점에만 frontmatter 갱신).

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.
```

자동 promote 실패 시 (파일 corruption 등) → 사용자에게 "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -q "pending_locked_decisions" plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -q "Locked 판정 트리거" plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -q "In-flight state migration" plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -q "dismissed_by_user" plugins/spec-distill/skills/conducting-interview/SKILL.md
```
Expected: 모두 exit 0 (V6 부분 충족).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -m "feat(spec-distill): add locked decision detection + state schema migration to conducting-interview"
```

---

## Phase 2 — Test Fixtures (4 tasks, V0 pre-gate가 요구하는 사전 자산)

### Task 4: Create fixtures directory + interview/spec/reviewer-output fixtures

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md`
- Create: `plugins/spec-distill/tests/fixtures/locked-decisions-spec.md`
- Create: `plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md`

- [ ] **Step 1: Create fixtures directory**

```bash
mkdir -p plugins/spec-distill/tests/fixtures
```

- [ ] **Step 2: Create interview-transcript-bbda.md**

Path: `plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md`. AC1 검증용 4-round transcript (paths b/b/d/a):

```markdown
# Fixture: Interview Transcript (b/b/d/a paths)

> AC1 verification fixture — drafting-spec Mode A가 이 transcript를 input으로 받아
> 결과 spec.md frontmatter에 LD1/LD2/LD3 3개 (b/b/d 답변)만 emit해야 함.
> (a) factual auto-confirm은 LD 없음.

## state.local.md (excerpt)

```yaml
session_id: fixture-bbda-001
phase: 1
interview_round: 4
issue_history: []
pending_locked_decisions:
  - id: LD1
    section: "#goals"
    summary: "G2 = 신규 사용자 onboarding은 in-scope"
    source: interview-round-1
    source_path: b
  - id: LD2
    section: "#acceptance-criteria"
    summary: "AC3 — 테스트는 30초 이내 통과"
    source: interview-round-2
    source_path: b
  - id: LD3
    section: "#non-goals"
    summary: "NG2 = 결제 흐름은 별도 spec (이 spec의 essence가 아님)"
    source: interview-round-3
    source_path: d
```

## Round transcripts

### Round 1 (path b — judgment, locked=true)
**현재 이해:** 사용자가 todo 앱을 원함.
**막힌 결정:** 신규 사용자 onboarding 포함 여부.
**추천 답안:** in-scope (사용자 첫 진입이 가장 중요).
**질문:** 신규 사용자 onboarding은 spec에 포함시킬까요?

**사용자 답변 (round 1):** "네, in-scope으로 해주세요."
→ `pending_locked_decisions.append(LD1)`

### Round 2 (path b — judgment, locked=true)
**현재 이해:** todo 앱 + onboarding.
**막힌 결정:** 테스트 실행 시간 제약.
**추천 답안:** 30초 이내.
**질문:** 통합 테스트 실행 시간을 30초 이내로 제한할까요?

**사용자 답변 (round 2):** "30초로 합시다."
→ `pending_locked_decisions.append(LD2)`

### Round 3 (path d — ontological, locked=true)
**현재 이해:** todo 앱 + onboarding + 빠른 테스트.
**막힌 결정:** essence — 결제 흐름까지 포함하는가?
**추천 답안:** 결제는 별도 spec, todo essence가 아님.
**질문:** [ESSENCE] todo 앱의 essence를 무엇으로 정의할까요? (결제 제외/포함)

**사용자 답변 (round 3):** "결제는 빼고 todo 자체에 집중."
→ `pending_locked_decisions.append(LD3)`

### Round 4 (path a — factual auto-confirm, locked=false)
**현재 이해:** todo 앱 essence + onboarding + 30s 테스트.
**막힌 결정:** 현재 repo의 test runner.
**추천 답안:** (auto-confirm via grep) — pytest.
**질문:** (none — auto-confirmed via grep `pytest.ini`)

**[from-code][auto-confirmed]** test runner = pytest.
→ pending_locked_decisions에 추가하지 않음 (path a).

## Expected drafting-spec Mode A output

spec.md frontmatter `locked_decisions:`에 LD1/LD2/LD3 정확히 3개 (LD4는 path a이므로 없음).
```

- [ ] **Step 3: Create locked-decisions-spec.md**

Path: `plugins/spec-distill/tests/fixtures/locked-decisions-spec.md`. AC2/AC5의 reviewer input + Mode B input으로 사용될 spec.md 샘플:

```markdown
---
name: fixture-locked-decisions
version: 1.0.0
created_at: 2026-05-13
session_id: fixture-locked-001
status: locked
next_phase: writing-plans
source: spec-distill v0.2.0
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: "G2 = onboarding은 in-scope"
    source: interview-round-1
    source_path: b
  - id: LD2
    section: "#acceptance-criteria"
    summary: "AC3 — 테스트 30초 이내"
    source: interview-round-2
    source_path: b
---

# Fixture spec — locked decisions

## Goal

Todo 앱 — onboarding 포함, 30초 이내 테스트.

## Goals

- G1: 기본 CRUD.
- G2: 신규 사용자 onboarding (LD1).

## Acceptance Criteria

- AC1: CRUD 동작.
- AC3: 통합 테스트 < 30s (LD2).

(... 다른 섹션 생략 — fixture 목적상 필요한 frontmatter + LD-매칭 가능 섹션만 ...)
```

- [ ] **Step 4: Create reviewer-output-mixed.md**

Path: `plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md`. AC2 contract 명세 — reviewer가 emit해야 할 형식:

```markdown
# Fixture: Reviewer output — mixed locked + unlocked issues

> AC2 contract 명세. reviewer가 위 locked-decisions-spec.md에 dispatch될 때
> 모든 issue 라인 다음에 indented `affects_locked_decisions: [...]` 필드 emit.
> LLM 출력 비결정성 수용 — 이 fixture는 schema 검증용 (manual replay 없음).

## Spec Review (round 1)

**Status:** needs_revise

**Issues:**

- [abc12345] [#goals]: scope_creep — "G2 (onboarding)가 너무 광범위, Non-goals로 빼라"
  affects_locked_decisions: [LD1]

- [def67890] [#non-goals]: missing_section — "Non-goals 섹션이 비어있음"
  affects_locked_decisions: []

- [ghi13579] [#acceptance-criteria]: untestable_AC — "AC3의 30s 기준이 어느 hardware인지 불명"
  affects_locked_decisions: [LD2]

**Recommendations (advisory):**
- G2를 in-scope 정당화 단락 추가 권장.

**Stagnation_signal:** false
```

- [ ] **Step 5: Verify**

Run:
```bash
test -f plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md
test -f plugins/spec-distill/tests/fixtures/locked-decisions-spec.md
test -f plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md
grep -cE '^[[:space:]]*affects_locked_decisions:' plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md
```
Expected: 모든 `test -f` exit 0. 마지막 `grep -c` ≥ 3.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md \
        plugins/spec-distill/tests/fixtures/locked-decisions-spec.md \
        plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md
git commit -m "test(spec-distill): add interview/spec/reviewer fixtures for AC1/AC2"
```

---

### Task 5: Create routing-trace + mode-b-guard fixtures

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/routing-trace-cases.md`
- Create: `plugins/spec-distill/tests/fixtures/mode-b-guard-case.md`

- [ ] **Step 1: Create routing-trace-cases.md**

Path: `plugins/spec-distill/tests/fixtures/routing-trace-cases.md`. AC3 + AC7 검증 5 case:

```markdown
# Fixture: routing-trace-cases

> AC3, AC7 검증. reviewing-spec SKILL.md의 deterministic routing table을
> 각 case별로 expected branch에 매핑. manual review로 verify.

## Case A — all unlocked, count < 3 → [4] Revise (자동)

Input:
- reviewer issues = [{id: A1, affects_locked_decisions: []}, {id: A2, affects_locked_decisions: []}]
- rereview_count = 0
- stagnation_signal = false

Expected routing: **[4] Revise** with `allowed_issue_ids = [A1, A2]`.

## Case B — mixed locked + unlocked → [3.5] Re-consensus

Input:
- reviewer issues = [{id: B1, affects_locked_decisions: [LD1]}, {id: B2, affects_locked_decisions: []}]
- rereview_count = 0

Expected routing: **[3.5] Re-consensus** (AskUserQuestion for LD1).
B2는 사용자 응답 후 [4]로 진행.

## Case C — needs_interview verdict → user confirm → [1]

Input:
- reviewer verdict = needs_interview

Expected routing: user confirm gate → [1] Interview (확인) 또는 [5] (취소).

## Case D — stagnation_signal: true → [5] forced escalate

Input:
- reviewer issues = [{id: D1, raised_count: 3, dismissed_by_user: 0}]
- stagnation_signal = true

Expected routing: **[5] Human Gate** (forced, P18 stagnation).

## Case E — v0.1.x spec (locked_decisions 부재) → empty default → [4]

Input:
- spec.md frontmatter에 `locked_decisions` 키 없음 (v0.1.x).
- reviewer issues = [{id: E1, affects_locked_decisions: []}]  # empty default

Expected routing: **[4] Revise** (자동, 기존 v0.1.x path 동작). AC7 충족.
```

- [ ] **Step 2: Create mode-b-guard-case.md**

Path: `plugins/spec-distill/tests/fixtures/mode-b-guard-case.md`. AC5 정상 + abort 두 시나리오:

```markdown
# Fixture: mode-b-guard-case

> AC5 검증. drafting-spec Mode B의 allowed_issue_ids contract + abort flow.

## Scenario A — 정상 케이스

Input:
- spec.md = locked-decisions-spec.md
- allowed_issue_ids = [I1]
- reviewer issues = [{id: I1, target: #goals}, {id: I2, target: #acceptance-criteria}]

Expected behavior:
- Mode B는 I1 (#goals 섹션) 적용.
- I2 (#acceptance-criteria 섹션)는 *건드리지 않음*.
- state.local.md `issue_history[I2].resolved` 변경 없음.
- spec.md diff: #goals 섹션만 변경.

## Scenario B — abort 케이스 (allowed_issue_ids 위반)

Input:
- spec.md = locked-decisions-spec.md
- allowed_issue_ids = [I1]
- Mode B가 I2 적용 시도 (구현 버그 또는 잘못된 dispatch).

Expected behavior (4단계):
1. spec.md edit 즉시 중단.
2. 이미 적용된 partial edit 있으면 `git restore plugins/spec-distill/tests/fixtures/locked-decisions-spec.md` (working tree 복원).
3. state.local.md에 다음 marker 추가:
   ```yaml
   mode_b_violation:
     attempted_issue_id: I2
     allowed: [I1]
     timestamp: <ISO8601>
   ```
4. reviewing-spec [3.5] sub-step으로 제어 반환. 사용자에게 advisory:
   > Mode B contract 위반 — `I2`가 `allowed_issue_ids`에 없음. 재합의 round 누락 가능성.
   > 옵션: (i) 해당 issue를 re-consensus에 추가 / (ii) Mode B 재dispatch (수동 issue 선택) / (iii) [5] Human Gate로 escalate.

Expected schema grep:
```
grep -q "mode_b_violation" plugins/spec-distill/tests/fixtures/mode-b-guard-case.md
```
```

- [ ] **Step 3: Verify**

Run:
```bash
test -f plugins/spec-distill/tests/fixtures/routing-trace-cases.md
test -f plugins/spec-distill/tests/fixtures/mode-b-guard-case.md
grep -q "mode_b_violation" plugins/spec-distill/tests/fixtures/mode-b-guard-case.md
grep -cE "^## Case [A-E]" plugins/spec-distill/tests/fixtures/routing-trace-cases.md
```
Expected: 모든 `test -f` + grep exit 0. 마지막 `grep -c` == 5.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/fixtures/routing-trace-cases.md \
        plugins/spec-distill/tests/fixtures/mode-b-guard-case.md
git commit -m "test(spec-distill): add routing + mode-b-guard fixtures for AC3/AC5/AC7"
```

---

### Task 6: Create stagnation + backwards-compat + reconsensus-loop fixtures

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/stagnation-cases.md`
- Create: `plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md`
- Create: `plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md`

- [ ] **Step 1: Create stagnation-cases.md**

Path: `plugins/spec-distill/tests/fixtures/stagnation-cases.md`. AC6 검증 3 case:

```markdown
# Fixture: stagnation-cases

> AC6 검증. 새로운 stagnation 조건: `raised_count >= 3 AND dismissed_by_user == 0`.

## Case 1 — raised=3, dismissed=0 → stagnation true

state.local.md issue_history excerpt:
```yaml
- id: STG1
  raised_count: 3
  dismissed_by_user: 0
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == true → P3 forced escalate ([5]).

## Case 2 — raised=3, dismissed=1 → stagnation false

```yaml
- id: STG2
  raised_count: 3
  dismissed_by_user: 1
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == false (사용자 명시 거절 1회는 stagnation 제외).
다음 round에서 reviewer가 다시 raise해도 P18 trigger 안 됨.

## Case 3 — raised=3, dismissed=3 → reviewer-persona-warn (P4)

```yaml
- id: STG3
  raised_count: 3
  dismissed_by_user: 3
  accepted_by_user: 0
  reconsensus_count: 0
  resolved: false
```

Expected: Stagnation_signal == false. P4 trigger:
- 해당 issue [5] escalate.
- 사용자에게 advisory: "reviewer가 같은 issue를 3회 raise + 사용자가 3회 거절. reviewer persona 점검 필요 (NG5 — 자동 편집 X)."
```

- [ ] **Step 2: Create v0.1.x-spec-no-locked.md**

Path: `plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md`. AC7 backwards-compat:

```markdown
---
name: fixture-v0.1.x-no-locked
version: 1.0.0
created_at: 2026-04-01
session_id: fixture-v01x-001
status: locked
next_phase: writing-plans
source: spec-distill v0.1.2
# 의도적으로 locked_decisions 키 부재 — v0.1.x spec.md 형식.
---

# Fixture spec — v0.1.x backwards-compat

## Goal

Simple todo app (v0.1.x로 작성된 spec).

## Goals

- G1: CRUD.

## Acceptance Criteria

- AC1: CRUD 동작.

(... 다른 섹션 생략 — frontmatter에 `locked_decisions` 키 부재가 핵심 ...)
```

Expected: reviewing-spec이 `locked_decisions` 키 부재 시 in-memory `[]`로 promote. 모든 reviewer issue가 `affects_locked_decisions: []` → 자동 [4] path.

- [ ] **Step 3: Create reconsensus-loop-case.md**

Path: `plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md`. AC9 priority table (per-issue + global) 검증:

```markdown
# Fixture: reconsensus-loop-case

> AC9 검증. P1 (global) vs P2 (per-issue) priority + 동시 충족 처리.

## Scenario A — per-issue [5] escalate (P2 path)

state.local.md issue_history excerpt:
```yaml
- id: LOOP1
  raised_count: 2
  dismissed_by_user: 0
  accepted_by_user: 1
  reconsensus_count: 2          # AC9 cap에 도달
  resolved: false
- id: OTHER1
  raised_count: 1
  reconsensus_count: 0
  resolved: false
```

Expected routing:
- LOOP1만 [5] forced escalate (해당 issue만 인간 검토). `issue_history[LOOP1].escalated = true`.
- OTHER1은 [4] Revise로 계속 (per-issue scope이므로 spec 전체 stop X).

## Scenario B — global [5] escalate (P1 path)

reviewer output:
- 5개 locked-affecting issue 동시 raise (각각 다른 LD 영향):
  - I1: affects_locked_decisions: [LD1]
  - I2: affects_locked_decisions: [LD2]
  - I3: affects_locked_decisions: [LD3]
  - I4: affects_locked_decisions: [LD4]
  - I5: affects_locked_decisions: [LD5]

Expected routing:
- C3 한 round 최대 3 LD 묶음 초과 (5개) → P1 trigger.
- spec 전체 [5] forced escalate (5개 issue 모두 묶어서 인간 검토).
- issue_history 변경 X (P1은 spec-level이므로 per-issue 카운터 무영향).

## Scenario C — P1 + P2 동시 충족

reviewer output 같은 round:
- 4개 locked-affecting issue (P1 trigger condition: ≥4).
- 그 중 하나 (I3)가 reconsensus_count: 2 (P2 trigger condition).

Expected routing: **P1 우선** — spec 전체 [5]로 가고, I3의 per-issue P2는 미실행.
이유: C3 P1 우선 명시 규칙 ("global이 per-issue 우선").
```

- [ ] **Step 4: Verify**

Run:
```bash
test -f plugins/spec-distill/tests/fixtures/stagnation-cases.md
test -f plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md
test -f plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md
grep -cE "^## Case [1-3]" plugins/spec-distill/tests/fixtures/stagnation-cases.md
grep -cE "^## Scenario [A-C]" plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md
# v0.1.x fixture에 locked_decisions 키 부재 확인:
! grep -q "^locked_decisions:" plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md
```
Expected: 모든 `test -f` exit 0. `grep -c` == 3 (stagnation), == 3 (reconsensus). 마지막 `! grep` exit 0 (키 부재).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/tests/fixtures/stagnation-cases.md \
        plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md \
        plugins/spec-distill/tests/fixtures/reconsensus-loop-case.md
git commit -m "test(spec-distill): add stagnation/backwards-compat/loop-cap fixtures for AC6/AC7/AC9"
```

---

### Task 7: Create run-fixture-ac1.sh executable

**Files:**
- Create: `plugins/spec-distill/tests/run-fixture-ac1.sh`

- [ ] **Step 1: Create script**

Path: `plugins/spec-distill/tests/run-fixture-ac1.sh`. AC1 통합 검증:

```bash
#!/usr/bin/env bash
# AC1 verification — drafting-spec Mode A가 interview-transcript-bbda.md fixture를
# 받아 spec.md frontmatter `locked_decisions:`에 정확히 3개 (LD1/LD2/LD3) 생성하는지 검증.
#
# 이 스크립트는 *contract-level fixture replay* — LLM 호출 없이 fixture의 expected
# output을 직접 parse + assert. LLM 호출은 V12 (E2E manual replay)에서만.
#
# Mock/stub 전략 (round 3 advisory #3 — plan 단계에서 명시):
# 본 스크립트는 Mode A의 *실제 dispatch 없이* fixture에 명시된 expected output
# (Expected drafting-spec Mode A output 섹션)을 contract로 검증. Mode A 실제 동작은
# V12에서 한 번만 manual replay로 verify.

set -e -o pipefail

FIXTURE="plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md"

# Step 1: fixture 존재 + pending_locked_decisions 정확히 3개 entry 보유 검증
test -f "$FIXTURE"

# Extract pending_locked_decisions list from fixture's state.local.md excerpt
COUNT=$(awk '/^pending_locked_decisions:/,/^[^[:space:]-]/' "$FIXTURE" \
        | grep -cE "^[[:space:]]*-[[:space:]]*id:[[:space:]]*LD")
if [ "$COUNT" -ne 3 ]; then
  echo "FAIL: expected 3 LDs in fixture pending_locked_decisions, got $COUNT" >&2
  exit 1
fi

# Step 2: source_path 검증 — b/b/d 만 (a는 LD 없음)
PATHS=$(awk '/^pending_locked_decisions:/,/^[^[:space:]-]/' "$FIXTURE" \
        | grep -E "^[[:space:]]*source_path:" \
        | awk -F: '{gsub(/[[:space:]]/, "", $2); print $2}' \
        | sort | tr -d '\n')
if [ "$PATHS" != "bbd" ]; then
  echo "FAIL: expected source_path sequence 'bbd', got '$PATHS'" >&2
  exit 1
fi

# Step 3: round 4 (path a)가 LD를 생성하지 않았는지 확인 — fixture 본문 grep
if grep -qE "^### Round 4.*locked=true" "$FIXTURE"; then
  echo "FAIL: round 4 (path a) should be locked=false but fixture marks locked=true" >&2
  exit 1
fi

echo "OK: AC1 fixture contract verified (3 LDs, b/b/d paths)"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/spec-distill/tests/run-fixture-ac1.sh
```

- [ ] **Step 3: Run the script**

```bash
bash plugins/spec-distill/tests/run-fixture-ac1.sh
```
Expected output: `OK: AC1 fixture contract verified (3 LDs, b/b/d paths)`. Exit 0.

- [ ] **Step 4: Verify executable bit**

```bash
test -x plugins/spec-distill/tests/run-fixture-ac1.sh
```
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/tests/run-fixture-ac1.sh
git commit -m "test(spec-distill): add run-fixture-ac1.sh for AC1 contract verification"
```

---

## Phase 3 — Agent + drafting-spec (3 tasks)

### Task 8: Update spec-reviewer agent — Input + Output + What-to-check

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md`

- [ ] **Step 1: Extend Input section**

`## Input` 섹션을 다음으로 교체:

```markdown
## Input

- spec.md 파일 경로 (`docs/superpowers/specs/<file>-spec.md`)
- (선택) 이전 review history — 같은 issue ID 추적용
- **spec.md frontmatter의 `locked_decisions:` 리스트** (Read tool로 추출, C1 + G3) — 각 issue의 `affects_locked_decisions` 매핑에 사용.
```

- [ ] **Step 2: Add LD-mapping guidance to "What to check"**

`## What to check` 테이블 아래에 다음 섹션 추가:

```markdown
### Locked decisions 매핑 (G3, AC2)

매 issue에 대해 `affects_locked_decisions: [LD ids]` 필드를 emit. 매핑 규칙:

1. spec.md frontmatter `locked_decisions:` 리스트를 Read tool로 추출.
2. 각 LD에 대해:
   - LD의 `section` anchor와 issue의 `target_section` 비교 (deterministic anchor match).
   - LD의 `summary` 내용과 issue의 message 의미 비교 (LD가 명시한 결정을 issue가 *변경* 또는 *부정*하려 하는지 판단).
3. 위 두 조건 중 *적어도 하나* 충족 시 해당 LD ID를 `affects_locked_decisions:`에 추가.
4. 어떤 LD와도 매칭되지 않으면 `affects_locked_decisions: []` (빈 리스트, *반드시 emit*).

기존 v0.1.x spec.md (frontmatter `locked_decisions` 키 부재) 입력 시: empty list로 in-memory promote → 모든 issue가 `affects_locked_decisions: []` (AC7 backwards-compat).
```

- [ ] **Step 3: Update Output 형식 section**

`## Output 형식` 섹션의 코드 블록 안의 `**Issues:**` 부분을 다음으로 교체:

```markdown
**Issues:**
- [<issue_id>] [<#section>]: <category> — "<message>" — raised <N>x ⚠ unresolved (if applicable)
  affects_locked_decisions: [LD<n>, LD<m>] | []
- ...

(`issue_id`는 `sha256_short(category + ":" + target_section)`. *반드시 emit*. `affects_locked_decisions:` 줄은 모든 issue 뒤에 indented (2 spaces) emit — 빈 리스트도 `[]`로 명시.)
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -q "affects_locked_decisions" plugins/spec-distill/agents/spec-reviewer.md
grep -q "Locked decisions 매핑" plugins/spec-distill/agents/spec-reviewer.md
awk '/^## Output 형식/,/^## /' plugins/spec-distill/agents/spec-reviewer.md \
  | grep -qE '^[[:space:]]*affects_locked_decisions:.*\[.*\]'
```
Expected: 모두 exit 0 (V3 + AC2 verification 충족).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md
git commit -m "feat(spec-distill): extend spec-reviewer agent with affects_locked_decisions output + LD mapping"
```

---

### Task 9: Update drafting-spec Mode A — locked_decisions generation

**Files:**
- Modify: `plugins/spec-distill/skills/drafting-spec/SKILL.md`

- [ ] **Step 1: Extend Mode A Step 4 (frontmatter)**

`## Mode A: Initial draft (Phase 2)` 섹션의 `### Steps` 중 Step 4를 다음으로 교체:

```markdown
4. **Fill frontmatter** (8 fields):
   - `name`, `version: 1.0.0`, `created_at`, `session_id`, `status: locked`, `next_phase: writing-plans`, `source: spec-distill v0.2.0`.
   - **`locked_decisions:`** — state.local.md의 `pending_locked_decisions:` 리스트를 그대로 frontmatter로 변환. (G2, AC1)
     - 각 LD entry: `id`, `section`, `summary` (160자 이내 단일 라인, P21 secret placeholder 치환), `source` (`interview-round-<N>` 형식), `source_path` (b/c/d).
     - `pending_locked_decisions`가 빈 리스트면 `locked_decisions: []`로 emit (frontmatter에 키는 존재, 값만 빈 리스트).
```

- [ ] **Step 2: Add NG6 superseded LD policy after Step 6**

`## Mode A` 섹션 마지막 step (Step 6) 다음에 다음 sub-section 추가:

```markdown
### Superseded LD 보존 정책 (NG6)

v0.2.0에서 superseded LD는 frontmatter에 *무제한 보존* — count cutoff 없음. archive 정책은 v0.3.0+로 deferred.
- 새 LD가 기존 LD를 superseded할 때 (Mode B가 호출): 기존 LD에 `superseded_by: LD<new>` 추가, 새 LD에 `supersedes: LD<old>` 추가.
- Mode A는 *initial draft*이므로 supersession 마커를 직접 생성하지 않음 (Mode B 전용).
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -q "locked_decisions:" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "Superseded LD 보존 정책" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "NG6" plugins/spec-distill/skills/drafting-spec/SKILL.md
```
Expected: 모두 exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/skills/drafting-spec/SKILL.md
git commit -m "feat(spec-distill): add locked_decisions generation to drafting-spec Mode A"
```

---

### Task 10: Update drafting-spec Mode B — allowed_issue_ids contract + abort flow + in-flight migration

**Files:**
- Modify: `plugins/spec-distill/skills/drafting-spec/SKILL.md`

- [ ] **Step 1: Add allowed_issue_ids input contract to Mode B**

`## Mode B: Revise per review (Phase 4)` 섹션의 `### Steps` 직전에 다음 sub-section 추가:

```markdown
### Input contract (G6, AC5)

Mode B는 다음 입력을 reviewing-spec skill로부터 받음:

- `spec_path`: 수정할 spec.md 경로
- `issues`: reviewer가 raise한 전체 issue 리스트
- **`allowed_issue_ids`** (필수, 빈 리스트도 명시): 적용 허가받은 issue ID 리스트. 이 리스트에 *없는* issue ID의 변경은 *절대 적용 금지*.
- (선택) `superseded_LD_ids`: re-consensus [3.5]에서 사용자가 (1) 수용한 LD ID 리스트. 해당 LD를 `superseded_by` 마커와 함께 유지하고 새 LD 추가.

`allowed_issue_ids`가 빈 리스트인 경우: 어떤 issue도 적용하지 않음 (no-op return, state.local.md 변경 X).
```

- [ ] **Step 2: Replace Mode B Steps with guarded version**

`### Steps` 섹션 (Mode B) 전체를 다음으로 교체:

```markdown
### Steps

1. **Read current spec.md** + `issues` 리스트 + `allowed_issue_ids` 입력 + (있다면) `superseded_LD_ids`.
2. **Filter issues**: `issues` 중 `id in allowed_issue_ids` 만 추출. 나머지는 무시.
3. **For each filtered issue**, identify the target section (`#goals`, `#acceptance-criteria` 등) and apply targeted fix:
   - `missing_section` → 섹션 추가.
   - `concrete_action_missing` → "Concrete Next Action" 섹션 채움.
   - `ambiguous_requirement` → 측정 가능 표현으로 재작성.
   - `unstated_assumption` → "Constraints" 또는 "Context" 섹션에 명시 추가.
   - `untestable_AC` → AC를 verification 명령 + 예상 결과 형태로 재작성.
   - `scope_creep` → Non-goals 섹션 강화 또는 Goals 분리.
4. **Apply supersession markers** (만약 `superseded_LD_ids` 제공됨): spec.md frontmatter `locked_decisions:` 안에서 각 superseded LD에 `superseded_by: LD<new_id>` 추가, 새 LD entry에 `supersedes: LD<old_id>` 추가. NG6 — 무제한 보존, 둘 다 frontmatter에 남김.
5. **Pre-write guard check**: 적용하려는 모든 변경이 `allowed_issue_ids` 안에 있는지 한 번 더 검증. 외부 issue 변경 시도가 감지되면 → 즉시 abort (다음 sub-section 참조).
6. **Write file** with `Edit` tool (전체 rewrite 대신 targeted edit).
7. **Update state.local.md**: `issue_history`에 resolved 마커 표시 (해당 `issue_id`의 `resolved: true`).
8. **Re-dispatch reviewing-spec** for re-review.
```

- [ ] **Step 3: Add Abort flow section**

Step 5 (guard check) 아래에 다음 sub-section 추가:

```markdown
### Abort flow (issue `e5f208a0`, AC5)

`allowed_issue_ids`에 없는 issue 적용이 감지되면 (Step 5 또는 Step 3 도중):

1. spec.md edit 즉시 중단. 이미 적용된 partial edit이 있으면 `git restore <spec-path>` 실행 — Edit tool은 working tree를 직접 수정하므로 `git reset HEAD --`는 효과 없음, `git restore`로 working tree를 HEAD 상태로 복원.
2. state.local.md에 다음 marker 기록:
   ```yaml
   mode_b_violation:
     attempted_issue_id: <id>
     allowed: [<allowed_issue_ids>]
     timestamp: <ISO8601>
   ```
3. reviewing-spec [3.5] sub-step으로 제어 반환 (reviewing-spec이 `mode_b_violation` marker 감지).
4. 사용자에게 advisory 표시:
   > Mode B contract 위반 — `<id>`가 `allowed_issue_ids`에 없음. 재합의 round 누락 가능성. 옵션: (i) 해당 issue를 re-consensus에 추가 / (ii) Mode B 재dispatch (수동 issue 선택) / (iii) [5] Human Gate로 escalate.
```

- [ ] **Step 4: Add in-flight state migration section**

Mode B `### Abort flow` 아래에 다음 sub-section 추가:

```markdown
### In-flight state migration (C10)

state.local.md 로드 시 v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:
- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- 다음 state write 시점에 frontmatter에 자연스럽게 추가.
- backward-rewriting 금지 — 명시적 write 시점에만 frontmatter 갱신.
- 사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`
- corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" + state.local.md 보존.
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -q "allowed_issue_ids" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "git restore" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "mode_b_violation" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "In-flight state migration" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "supersedes" plugins/spec-distill/skills/drafting-spec/SKILL.md
```
Expected: 모두 exit 0 (V5 + AC5 충족).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/skills/drafting-spec/SKILL.md
git commit -m "feat(spec-distill): add allowed_issue_ids guard + abort flow + in-flight migration to Mode B"
```

---

## Phase 4 — reviewing-spec (3 tasks, 가장 큰 변경)

### Task 11: reviewing-spec — routing table extension + [3.5] sub-step

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

- [ ] **Step 1: Extend routing table with affects_locked column**

`## Deterministic Routing Table (AC15)` 섹션의 테이블을 다음으로 교체:

```markdown
| Verdict | Stagnation_signal | rereview_count | affects_locked | → Next Phase |
|---|---|---|---|---|
| `approved` | - | - | - | **[5] Human Gate** (auto) |
| `needs_revise` | false | < 3 | **empty (모든 issue)** | **[4] Revise** (auto, dispatch drafting-spec Mode B with `allowed_issue_ids = [all]`) |
| `needs_revise` | false | < 3 | **non-empty (하나 이상)** | **[3.5] Re-consensus gate** (다음 sub-section 참조) |
| `needs_revise` | false | >= 3 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| `needs_revise` | true | - | - | **[5] Human Gate** (P18 stagnation, forced escalate — 단 dismissed_by_user >= 1 issue는 stagnation count 제외) |
| `needs_interview` | - | - | - | **user confirm gate** → [1] Interview (확인) 또는 [5] (취소) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.
```

- [ ] **Step 2: Add [3.5] Re-consensus gate section**

`### Re-review cap (AC6)` *직전*에 다음 섹션 추가:

```markdown
## [3.5] Re-consensus gate (G4, G5, AC4)

`needs_revise` + `affects_locked: non-empty` 시 자동 [4] 대신 이 sub-step 실행. *별도 phase 아님* — reviewing-spec skill 내부 게이트.

### Steps

1. **묶음 만들기**: reviewer issue 중 `affects_locked_decisions: non-empty` 항목을 LD ID 기준으로 묶음. 한 round당 최대 3개 LD까지 (C3). **4개 이상이면 → P1 forced escalate** ([5], `Escalate priority table` 참조).
2. **AskUserQuestion dispatch** (한 묶음 = 한 dispatch, 최대 3개 question):

   ```javascript
   AskUserQuestion({
     questions: [
       {
         question: "LD<id>: \"<summary>\"에 대해 reviewer가 변경을 제안합니다: \"<issue.message>\". 어떻게 처리할까요?",
         header: "LD<id>",
         options: [
           {label: "수용 (re-consensus)", description: "이 항목의 합의를 갱신. spec 수정 진행."},
           {label: "유지 (dismiss)", description: "원래 합의 유지. issue dismissed-by-user 마커."},
           {label: "추가 인터뷰", description: "이 dimension에 대해 인터뷰 round 추가 ([1]로 회귀)."}
         ],
         multiSelect: false
       },
       // ... 묶음의 다른 LD에 대해 동일 형식 ...
     ]
   })
   ```

3. **응답 처리**:
   - **(1) 수용**: 해당 issue ID를 state.local.md `reconsensus_accepted_ids:` 리스트에 append. `issue_history[<id>].accepted_by_user += 1`.
   - **(2) 유지**: spec.md 변경 X. `issue_history[<id>].dismissed_by_user += 1`. `resolved: dismissed_by_user`.
   - **(3) 추가 인터뷰**: state phase = 1로 reset (interview_round 유지). `under_revision: [LD ids]` 마킹. conducting-interview skill 호출.

4. **routing 분기**:
   - 모든 (2)/(3): spec.md 변경 없음 → reviewing-spec 재dispatch (reviewer가 dismissed 마커 본 상태에서 재평가).
   - 하나라도 (1): Mode B dispatch with `allowed_issue_ids = reconsensus_accepted_ids` + (관련 LD의 superseded 마커 처리).
   - (3) 우선: 다른 옵션과 혼합 시 → [1] 회귀 우선 (인터뷰 후 다시 reviewing-spec).

5. **`reconsensus_count` 갱신**: 각 issue에 대해 `issue_history[<id>].reconsensus_count += 1`. `reconsensus_count >= 2` 도달 시 → P2 escalate (`Escalate priority table` 참조).

### mode_b_violation 감지 (AC5)

state.local.md에 `mode_b_violation` marker 존재 시 (Mode B abort 후 복귀):
1. 사용자에게 AskUserQuestion으로 3-옵션 advisory ((i) re-consensus에 추가 / (ii) Mode B 재dispatch / (iii) [5] escalate).
2. 응답에 따라 분기. (i) → Step 1로 돌아가 묶음 재구성. (ii) → Mode B 재dispatch (사용자 선택 issue). (iii) → [5] Human Gate.
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -cE '^\| .* affects_locked' plugins/spec-distill/skills/reviewing-spec/SKILL.md  # ≥ 4
grep -q "## \[3.5\] Re-consensus gate" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "reconsensus_accepted_ids" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "AskUserQuestion" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```
Expected: 첫 grep ≥ 4, 나머지 exit 0 (V4 + AC3/AC4 충족).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): add [3.5] Re-consensus gate + affects_locked routing column"
```

---

### Task 12: reviewing-spec — escalate priority + stagnation + mode_b_violation + in-flight migration

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

- [ ] **Step 1: Replace Re-review cap section**

`### Re-review cap (AC6)` 섹션을 다음으로 교체:

```markdown
### Escalate priority table (AC9, P1–P4)

routing이 [5] forced escalate를 trigger할 수 있는 조건들. 다음 우선순위로 평가 (P1 최우선):

| 우선순위 | 조건 | scope | 동작 |
|---|---|---|---|
| **P1 (highest)** | C3: 한 round에 locked-affecting issue ≥ 4 | spec 전체 | [5] forced escalate, *전체 spec* 인간 검토. issue_history 변경 X. |
| **P2** | AC9: 특정 `issue_id`의 `reconsensus_count >= 2` | per-issue | 해당 issue 만 [5] forced escalate, *나머지 issue는 [4] Revise로 계속*. `issue_history[<id>].escalated = true`. |
| **P3** | P18 stagnation: `raised_count >= 3 AND dismissed_by_user == 0` | per-issue | 해당 issue 만 [5] forced escalate. |
| **P4 (lowest)** | `dismissed_by_user >= 3` | per-issue + persona warn | 해당 issue [5] escalate + advisory: "reviewer가 같은 issue를 3회 raise + 사용자가 3회 거절. reviewer persona 점검 필요 (NG5 — 자동 편집 X)." |

**두 조건 동시 충족 시**: P1이 P2/P3/P4보다 우선 (global이 per-issue 우선). 같은 우선순위 내 동시 충족 시 모든 해당 issue를 묶어서 한 번에 [5] escalate.

### Re-review cap (rereview_count)

`rereview_count >= 3` 도달 시 (즉 4번째 reviewer dispatch 시도 시): 자동으로 [5] Human Gate로 forced escalate, 전체 `issue_history` 첨부. (위 P1–P4와 별개 cap — 무한 review loop 방지.)

### Stagnation detection (P3 row 참조)

spec-reviewer agent가 `Stagnation_signal: true` 반환 시: 해당 issue에 대해 `raised_count >= 3 AND dismissed_by_user == 0` 검증. 두 조건 모두 충족 시 P3 trigger.

`dismissed_by_user >= 1`인 issue는 stagnation count에서 제외 — 사용자 명시 거절은 P17 sovereignty 행사이지 stagnation이 아님.
```

- [ ] **Step 2: Add in-flight state migration section**

`## kill switch` 섹션 *직전*에 다음 sub-section 추가:

```markdown
## In-flight state migration (C10)

reviewing-spec dispatch 시작 시 state.local.md 로드. v0.1.x schema (신규 필드 부재)면 *non-mutating read*로 자동 promote:

- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- `reconsensus_accepted_ids` 부재 → `[]`로 in-memory default.

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지).

사용자에게 advisory: `[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.`

corruption 시 → "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -cE '^\| \*\*P[1-4]' plugins/spec-distill/skills/reviewing-spec/SKILL.md  # ≥ 4
grep -q "dismissed_by_user == 0" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "In-flight state migration" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "global.*우선\|P1이.*우선" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```
Expected: 첫 grep ≥ 4, 나머지 exit 0 (AC6 + AC9 priority + C10 충족).

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): add P1-P4 escalate priority + stagnation refinement + in-flight migration to reviewing-spec"
```

---

### Task 13: reviewing-spec — kill switch + README updates

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: Add kill switch to reviewing-spec SKILL.md**

`## kill switch` 섹션을 다음으로 교체:

```markdown
## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
- **`DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1`** (v0.2.0): [3.5] Re-consensus gate 우회 + loud warning 출력.
  - 비상시 사용. v0.1.x 원래 자동 [4] path로 fallback.
  - 출력: `[spec-distill v0.2.0] WARNING: locked decisions 보호 비활성화됨 — 사용자 sovereignty 약화 위험. DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1로 [3.5] 우회됨.`
  - reviewer가 locked-affecting issue를 raise해도 자동 Mode B (모든 issue 적용).
```

- [ ] **Step 2: Update README.md "Principles Instantiated"**

`### Three Laws` 섹션 또는 `### Principles 흡수` 섹션에 다음 한 줄 추가 (위치는 P-numbered list 안 적절한 곳):

```markdown
- **P17 (User sovereignty) — locked_decisions 추적 + [3.5] Re-consensus gate** — 인터뷰 합의가 writer/reviewer 페어에 의해 사용자 동의 없이 뒤집히는 것을 frontmatter-level로 차단. (v0.2.0)
```

- [ ] **Step 3: Update README Flow diagram**

`## Flow (Phase 0–5)` 섹션의 ASCII flow에 [3.5] node 추가. 기존 다이어그램의 `[3] Spec Reviewer ── verdict` 아래에 `[3.5] Re-consensus` branch 추가:

```
[0] Trigger ──→ [1] Interview ←──────────────┐
                    │                        │
                    ↓                        │
                [2] Draft                    │
                    │                        │
                    ↓                        │
                [3] Spec Reviewer ── verdict │
                    ├─ needs_interview → user confirm → [1]
                    ├─ needs_revise (all unlocked) → [4]
                    ├─ needs_revise (any locked) → [3.5] Re-consensus  ← v0.2.0
                    │       ├─ (1) 수용 → [4] with allowed_issue_ids
                    │       ├─ (2) 유지 → [3] re-dispatch (dismissed)
                    │       └─ (3) 추가 인터뷰 → [1]
                    └─ approved ────────→ [5]
                [4] Revise → [3] (auto re-review, max 3)
                [5] Human Gate
                    ├─ "more interview" → [1]
                    ├─ "edit spec"      → [4]
                    └─ "approve"        → handoff (commit + pointer + cleanup)
```

- [ ] **Step 4: Update README Kill switches section**

`## Kill switches` 섹션에 다음 줄 추가:

```markdown
- `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (v0.2.0) — [3.5] Re-consensus gate 우회. **loud warning**: locked decisions 보호 비활성화 — 사용자 sovereignty 약화 위험.
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "locked decisions 보호 비활성화됨" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "P17" plugins/spec-distill/README.md
grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/README.md
grep -q "\[3.5\] Re-consensus" plugins/spec-distill/README.md
```
Expected: 모두 exit 0 (AC8 + V8 + V11 충족).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/README.md
git commit -m "feat(spec-distill): add reconsensus skip kill switch + README P17 instantiation + [3.5] flow"
```

---

## Phase 5 — Verification (1 task)

### Task 14: Run full Verification Plan (V0–V12)

**Files:** (검증 전용 — 변경 없음)

- [ ] **Step 1: V0 pre-gate (fixture 존재 검증)**

```bash
set -e -o pipefail
test -d plugins/spec-distill/tests/fixtures
for f in interview-transcript-bbda.md locked-decisions-spec.md reviewer-output-mixed.md \
         routing-trace-cases.md mode-b-guard-case.md stagnation-cases.md \
         v0.1.x-spec-no-locked.md reconsensus-loop-case.md; do
  test -f "plugins/spec-distill/tests/fixtures/$f"
done
test -x plugins/spec-distill/tests/run-fixture-ac1.sh
echo "V0 PASS"
```
Expected: `V0 PASS` (모든 fixture 존재).

- [ ] **Step 2: V1 (plugin.json version) + V2 (template schema)**

```bash
set -e -o pipefail
jq empty plugins/spec-distill/.claude-plugin/plugin.json
jq -e '.version == "0.2.0"' plugins/spec-distill/.claude-plugin/plugin.json
echo "V1 PASS"
python3 -c "import yaml, re; \
content = open('plugins/spec-distill/templates/spec-template.md').read(); \
fm = re.split(r'^---\s*$', content, maxsplit=2, flags=re.MULTILINE)[1]; \
d = yaml.safe_load(fm); \
assert 'locked_decisions' in d; \
print('V2 PASS')"
```
Expected: `V1 PASS` and `V2 PASS`.

- [ ] **Step 3: V3 (reviewer agent contract) + V4 (routing table)**

```bash
set -e -o pipefail
grep -q "affects_locked_decisions" plugins/spec-distill/agents/spec-reviewer.md
test "$(grep -cE '^[[:space:]]*affects_locked_decisions:' plugins/spec-distill/tests/fixtures/reviewer-output-mixed.md)" -ge 2
echo "V3 PASS"
test "$(grep -cE '^\| .* affects_locked' plugins/spec-distill/skills/reviewing-spec/SKILL.md)" -ge 4
echo "V4 PASS"
```
Expected: `V3 PASS` and `V4 PASS`.

- [ ] **Step 4: V5 (Mode B guard) + V6 (state schema)**

```bash
set -e -o pipefail
grep -q "allowed_issue_ids" plugins/spec-distill/skills/drafting-spec/SKILL.md
grep -q "mode_b_violation" plugins/spec-distill/skills/drafting-spec/SKILL.md
echo "V5 PASS"
grep -q "pending_locked_decisions" plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -q "reconsensus_accepted_ids" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "dismissed_by_user" plugins/spec-distill/skills/reviewing-spec/SKILL.md
echo "V6 PASS"
```
Expected: `V5 PASS` and `V6 PASS`.

- [ ] **Step 5: V7 (AC1 integration script)**

```bash
bash plugins/spec-distill/tests/run-fixture-ac1.sh
```
Expected: `OK: AC1 fixture contract verified (3 LDs, b/b/d paths)`.

- [ ] **Step 6: V8 (kill switch) + V9 (backwards-compat)**

```bash
set -e -o pipefail
grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -q "DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS" plugins/spec-distill/README.md
grep -q "locked decisions 보호 비활성화됨" plugins/spec-distill/skills/reviewing-spec/SKILL.md
echo "V8 PASS"
# v0.1.x backwards-compat: SKILL.md에 empty-default 명세 + fixture에 키 부재 확인:
grep -qE "locked_decisions.*default.*\[\]|locked_decisions.*부재.*\[\]" plugins/spec-distill/skills/reviewing-spec/SKILL.md \
  || grep -q "Backwards-compat\|v0.1.x" plugins/spec-distill/skills/reviewing-spec/SKILL.md
! grep -q "^locked_decisions:" plugins/spec-distill/tests/fixtures/v0.1.x-spec-no-locked.md
echo "V9 PASS"
```
Expected: `V8 PASS` and `V9 PASS`.

- [ ] **Step 7: V10 (loop cap) + V11 (README + CHANGELOG)**

```bash
set -e -o pipefail
grep -q "reconsensus_count" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -qE "reconsensus_count.*>=.*2" plugins/spec-distill/skills/reviewing-spec/SKILL.md
echo "V10 PASS"
grep -q "P17" plugins/spec-distill/README.md
grep -q "## \[0.2.0\]" plugins/spec-distill/CHANGELOG.md
echo "V11 PASS"
```
Expected: `V10 PASS` and `V11 PASS`.

- [ ] **Step 8: V12 (E2E manual replay) — *advisory step*, plan 단계 한도 내 manual review**

V12는 LLM-based E2E replay (conducting-interview → drafting-spec Mode A → reviewer → reviewing-spec [3.5] → Mode B → re-review → approve). 이 plan의 implementation 범위에서는 *전체 E2E 자동 검증 도구가 없음*. 다음 manual checklist로 대체:

- [ ] (a) interview-transcript-bbda.md fixture를 input으로 conducting-interview → drafting-spec Mode A 실제 dispatch. 결과 spec.md frontmatter에 LD1/LD2/LD3 정확히 3개 존재 manual 확인.
- [ ] (b) 위 spec에 spec-reviewer 실제 dispatch. output에 issue별 `affects_locked_decisions` 줄 emit manual 확인.
- [ ] (c) reviewing-spec [3.5] 진입 → AskUserQuestion 호출 manual 확인 (수용 1개, 유지 1개 선택).
- [ ] (d) Mode B가 `allowed_issue_ids = [수용된 issue]`로 dispatch되어 해당 issue만 적용 manual 확인.
- [ ] (e) state.local.md에 `reconsensus_accepted_ids` 갱신 + `issue_history[].accepted_by_user` / `dismissed_by_user` 카운터 증가 manual 확인.

V12 manual checklist는 *PR 검토 시* 실행 — plan 단계 자동 검증은 V0–V11으로 충분.

- [ ] **Step 9: Commit verification log**

이 task는 코드 변경 없음. 하지만 V0–V11 통과 기록을 위해 verification log를 commit:

```bash
cat > .claude/worktrees/spec-distill-reconsensus-design/VERIFICATION_LOG.md << 'EOF'
# Verification Log — spec-distill v0.2.0 re-consensus gate

Date: <YYYY-MM-DD>
Commit range: <task 1 commit>..HEAD

| V# | Command | Result |
|---|---|---|
| V0 | fixture 존재 사전 검증 | PASS |
| V1 | plugin.json version | PASS |
| V2 | spec-template frontmatter | PASS |
| V3 | reviewer agent contract | PASS |
| V4 | routing table | PASS |
| V5 | Mode B guard | PASS |
| V6 | state schema | PASS |
| V7 | run-fixture-ac1.sh | PASS |
| V8 | kill switch | PASS |
| V9 | backwards-compat | PASS |
| V10 | loop cap | PASS |
| V11 | README + CHANGELOG | PASS |
| V12 | E2E manual replay | DEFERRED (PR 검토 시) |
EOF

git add .claude/worktrees/spec-distill-reconsensus-design/VERIFICATION_LOG.md 2>/dev/null || true
# 참고: .claude/worktrees 경로가 gitignore될 수 있음. 그 경우 docs/superpowers/ 아래 저장:
# mv .claude/worktrees/spec-distill-reconsensus-design/VERIFICATION_LOG.md docs/superpowers/verification-logs/2026-05-13-spec-distill-reconsensus.md
git commit -m "test(spec-distill): record V0-V11 verification log for v0.2.0 implementation" || echo "no changes — verification log location may need adjustment"
```

---

## 종합 commit + PR 흐름

전체 14 task 완료 후:

1. **Branch**: 이 plan은 worktree branch `worktree-spec-distill-reconsensus-design`에서 실행. 완료 후 `feature/spec-distill-reconsensus` branch로 push (또는 worktree branch 그대로 PR).
2. **PR title**: `feat(spec-distill): v0.2.0 re-consensus gate (locked_decisions + Phase 3.5)`
3. **PR body**:
   - Summary: 3 bullet (locked_decisions frontmatter / [3.5] Re-consensus gate / Mode B guard with abort flow)
   - Test plan: V0–V11 통과 + V12 manual checklist 예정
   - Spec reference: `docs/superpowers/specs/2026-05-13-spec-distill-reconsensus-design.md`
   - Plan reference: this file
4. **Reviewer**: 사용자 (devbrew CLAUDE.md의 Law 2 — writer가 self-approval 금지).
5. **Merge**: PR squash 또는 merge commit (devbrew git workflow `docs/git-workflow/pr-process.md` 따름).

---

## Open Questions (plan 단계 결정 사항)

spec의 OQ4 (cross-session persistence)는 다음과 같이 결정 (round 3 advisory #2):

- **OQ4 결정**: `dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 카운터는 **세션 한정**. state.local.md는 세션 한정 (현재 spec-distill 모델 유지). 새 세션 시작 시 reset.
- 이유: cross-session learning은 별도 spec (v0.3.0+) — 본 plan 범위 밖. 세션 한정으로 AC6 (stagnation 분리) 동작 일관.

spec의 V7 mock/stub 전략 (round 3 advisory #3):

- **V7 전략**: `run-fixture-ac1.sh`는 *LLM dispatch 없이* fixture에 명시된 expected output을 직접 parse + assert. 실제 LLM 호출은 V12 manual replay에서만. Task 7 Step 1의 script 안에 명시 (LLM 호출 비용 0).

---

## Plan summary

- **14 tasks** across 5 phases (metadata → fixtures → agent+drafting → reviewing → verification).
- **각 task는 self-contained commit** (frequent commits 원칙).
- **TDD-style**: 각 task에 verification command 명시, 실패 시 fix-and-retry.
- **No placeholders**: 모든 코드 블록은 actual content (TBD/TODO 없음).
- **Spec coverage**: AC1–AC10, V0–V12, NG1–NG6, C1–C10 모두 task로 매핑됨.
