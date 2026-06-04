# Design: qg Upfront Gate-Scope Decision (v2.4.0)

> 시작에서 "Review만 / 둘 다"를 묻는 upfront gate-scope 결정. devbrew Law 1 (Clarity Before Code) instantiation — 사용자가 실행 범위를 의식적으로 정하게 한다.

- **Plugin:** quality-gates
- **Version:** 2.3.0 → 2.4.0 (minor — 새 surface/behavior)
- **Branch:** `worktree-feature+qg-upfront-gate-scope` (worktree)
- **Date:** 2026-06-04
- **Status:** design approved → writing-plans 대기

## 1. Context / Why

현재 `/qg`는 두 게이트(Review gate → Runtime gate)를 "zero-click happy path"로 모두 실행한다. gate 범위를 정하려면:

1. 시작 전에 arg를 미리 외워 넣거나 (`/qg review`, `/qg --skip-runtime` → Review만; `/qg runtime` → Runtime만), 또는
2. `requires_decision: true` surface가 있을 때만 뜨는 conditional runtime-scope 질문(`## Upfront Execution Plan`)에 의존해야 한다.

**공백:** "이번엔 Review만" vs "끝까지(Runtime gate)까지"를 *시작에서 인터랙티브하게* 고르는 방법이 없다. 흔한 경우(순수 로컬 테스트 러너 / 위험 surface 없음)에는 Upfront 질문이 아예 안 뜨고 파이프라인이 조용히 두 게이트를 모두 돌린다. 이 spec은 그 upfront 결정을 명시적 질문으로 추가한다.

**원칙 충돌 (의식적 override):** devbrew CLAUDE.md와 이 SKILL은 "Happy path requires zero user clicks"를 명시 원칙으로 둔다. "시작에서 항상 묻기"는 이 원칙과 충돌한다. using-superpowers 위계상 **사용자의 명시적 지시가 최상위**이므로, gate-scope 결정 한 건에 한해 zero-click을 의도적으로 override한다. 문서의 zero-click 주장은 이에 맞게 정합한다.

## 2. Goals

- 모든 full-pipeline `/qg`(gate arg 없음)는 어떤 게이트도 돌기 전(trivia escape 후)에 **단일 gate-scope 질문**(Review만 / 둘 다)을 발화한다.
- `/qg both` = 무클릭 둘 다 실행 (신규 arg, `review`/`runtime`과 대칭).
- 결정은 **순차 + 조건부**: "Review만" → Runtime gate 전체 skip / "둘 다" → 기존 runtime-scope·block-policy 질문은 `requires_decision` surface가 있을 때만 이어서 발화.

## 3. Non-goals

- 게이트 내부 로직 무변경 (Review gate fix-loop, Runtime gate sandbox/mutation-guard/digest-seal).
- gate-scope용 env 기본값 없음 (design-lightness — `/qg both`로 escape 충분).
- 인터랙티브 "Runtime만" 3지 옵션 없음 (`/qg runtime` arg가 담당).
- trivia diff는 여전히 전 게이트 skip — gate-scope 질문도 미발화.
- single-gate mode(`/qg review`, `/qg runtime`) 동작 무변경 — 명명된 게이트만 실행하고 verdict 직접 emit.

## 4. Constraints

- **Law 1/Law 2 무영향** — 이건 orchestration-flow 변경이지 reviewer/writer 분리나 거절 메커니즘 변경이 아니다.
- **AskUserQuestion 앵커 컨벤션 준수**: 질문 prompt TEXT에 고유 앵커 구절을 두고, grep 기반 protocol-shape 테스트로 검증하며, 다른 어떤 decision-tool 호출에도 그 구절이 나타나지 않아야 한다 (기존 `findings remain`(AC6), `Runtime verifier needs`(AC8) 패턴과 동형).
- **single-turn / single-dispatch 불변(R5)** 유지 — 파이프라인은 한 턴에 실행, setup-qg.sh / check-trivia.sh 1회.
- **Doc-convention**: Korean-primary. 섹션명 추가/변경 시 같은 commit에서 TOC 동기화(해당 파일이 TOC 보유 시).
- **버전 bump 필수**: plugins/quality-gates/를 건드리므로 plugin.json bump (feedback_plugin_version_bump).

## 5. 설계 — 통합 Upfront Execution Plan 섹션

기존 `## Upfront Execution Plan` 섹션을 확장해 **두 upfront 결정을 순서대로 한 곳에서 소유**한다 (구현 구조: 통합 섹션 선택).

### 상태 전이 (Decision 1 → Decision 2) — 규범적

이 흐름이 §5 전체의 단일 진실 source다. prose 서술이 이 흐름과 충돌하면 이 다이어그램이 우선한다.

```
trivia diff? ──yes──▶ 전 게이트 skip (질문 없음, "Trivia diff — all gates skipped" 출력)
   │ no
   ▼
gate arg 존재? (gate∈{review,runtime,both} | --skip-runtime) ──yes──▶ Q1 skip; arg대로 실행
   │ no
   ▼
Decision 1 = Q1 (Gate scope) ──"Review gate only"──▶ Review gate 실행 → Runtime 단계 short-circuit (종료)
   │ "Run both gates"
   ▼
Decision 2 진입  ◀── (gate=both arg도 Q1 skip 후 여기로 도달)
   │
   ├─ requires_decision surface 있음 AND surface-selection arg 미해결 ──▶ Q2 (runtime scope + block policy) 발화
   └─ 없음 / arg 해결 ──────────────────────────────────────────────▶ Q2 skip (zero-click) → 둘 다 실행
```

### Decision 1 — Gate scope (항상, arg가 pre-answer하지 않는 한)

- **발화 시점:** trivia escape 후, Review gate dispatch 전. Dispatch Loop의 첫 결정.
- **Skip 조건 (arg = 답):** `gate ∈ {review, runtime, both}` 또는 `--skip-runtime` 인자가 있으면 그게 답이므로 질문 생략. **`--skip-runtime`은 "Review만"의 별칭**이다(= `gate=review`와 동일 결과). **Precedence:** 명시적 `gate=` 값이 항상 우선한다 — `--skip-runtime`과 `gate=runtime`/`gate=both`가 함께 오는 모순 입력에서는 명시적 `gate=`가 이기고 `--skip-runtime`은 무시되며 한 줄 advisory를 출력한다(silent 충돌 금지). §5 Arguments 테이블이 normative 기준이며, 이 Skip 조건 서술과 테이블이 충돌하면 테이블이 우선한다.
- **Binary AskUserQuestion** (option label):
  - `Review gate only` → Review gate만 실행, Runtime gate 전체 skip.
  - `Run both gates` → Decision 2로 진행.
- **앵커 구절 (테스트 컨벤션 정합 — issue 2):** "질문 TEXT"는 AskUserQuestion의 `question:` 필드(프롬프트 문장)를 가리킨다 — `options[].label`이 *아니다*. 리터럴 `both gates`는 반드시 `question:` 필드에 포함되어야 한다(예: `question: "Run both gates, or only the Review gate? ..."`). header는 `Gate scope`. option label은 `Review gate only` / `Run both gates`이되, grep-검증 대상은 `question:` 필드다(기존 `findings remain`·`Runtime verifier needs` 앵커가 모두 `question:`에 사는 것과 동형). 이 구절은 고유 — SKILL 내 다른 decision-tool 호출의 `question:`에 미출현. V-test: `first_line 'question:.*both gates'` + `assert_order`(Review gate dispatch 앞, Decision 2 질문 앞) + 고유성(다른 `question:` 라인에 `both gates` 부재).

### Decision 2 — Runtime scope + block policy (조건부)

- **도달 조건:** gate scope = "둘 다"일 때만 (인터랙티브 `Run both gates` 또는 `/qg both` arg).
- **발화 조건:** 기존 mechanical 조건 그대로 — 매니페스트에 `requires_decision: true` surface ≥1 AND arg 미해결.
- **기존 질문 그대로 재사용 — 손대지 않는다.** runtime-scope + block-policy(`stop`/`skip`/`ask`) 선택은 현행 템플릿 유지.
- gate scope = "둘 다"인데 `requires_decision` surface가 없으면 → Decision 2도 zero-click으로 통과(현행과 동일).
- **명확화 (arg 상호작용):** `gate=both` / `Run both gates`는 gate scope*만* 답하지 runtime scope(어떤 surface를 돌릴지)는 답하지 않는다. 따라서 `/qg both`는 Decision 2를 **suppress하지 않는다** — `requires_decision` surface가 있으면 Decision 2가 그대로 발화한다(즉 `/qg both`의 runtime-scope 거동은 오늘날의 무인자 `/qg`와 동일). Decision 2의 "arg가 pre-answer" suppress 절은 surface-selection 인자에만 적용되며 `gate=both`는 포함하지 않는다.

### Arguments — `gate` 도메인 확장 (normative)

이 테이블이 arg → 발화/실행 매핑의 **규범적 기준**이다. 본문 prose와 충돌하면 이 테이블이 우선한다.

`gate ∈ {review, runtime, both, absent}`:

| Invocation | Gate-scope Q? | 실행 게이트 |
|---|---|---|
| `/qg` | **예** | 답변대로 (Review만 또는 둘 다) |
| `/qg both` | 아니오 | 둘 다 (**신규**) |
| `/qg review` / `/qg --skip-runtime` | 아니오 | Review gate만 |
| `/qg runtime` | 아니오 | Runtime gate만 (single-gate) |
| trivia diff | 아니오 | 없음 (전 게이트 skip) |

`branch` / `--paths` / `--plan` / `--pr-url` 등 scope 수식 인자는 gate를 pre-answer하지 않는다 — 예: `/qg branch`는 여전히 gate-scope를 묻고, `/qg branch --skip-runtime`은 Review만.

## 6. Files to Modify

> **편집 타깃 규약 (issue a3b4):** 아래 "line ~N"은 *근사 힌트*이며 merge/rebase로 drift할 수 있다. **규범적 locating 기준은 섹션 헤더 / 리터럴 문자열 anchor**다(예: `## Upfront Execution Plan` 헤더, frontmatter `description:` 키, `## Arguments` 헤더). 구현자는 라인 번호가 아니라 anchor로 편집 지점을 찾는다.

1. **`skills/quality-pipeline/SKILL.md`**
   - frontmatter `description` (line ~10): "Happy path (all gates pass) requires zero user clicks." 정합 → gate-scope는 1회 upfront 클릭(또는 `/qg both|review|runtime`이면 0클릭); 그 이후 happy path는 무클릭.
   - `## Arguments` (line ~132): `gate` 도메인에 `both` 추가 + 의미 문서화.
   - `## Upfront Execution Plan` (line ~154): Decision 1(gate scope, 항상) + Decision 2(runtime scope, 조건부)로 재구성. 새 gate-scope AskUserQuestion 템플릿(앵커 `both gates`, header `Gate scope`) 추가. 기존 mechanical firing condition 텍스트는 Decision 2에만 적용되도록 명확화.
   - `## Dispatch Loop` (line ~184): step 2를 "Decision 1(gate scope) 발화 → Review만이면 Runtime 단계 short-circuit"으로 갱신.
   - 버전 문자열: title(line ~37) + Final Summary 템플릿(line ~567) → v2.4.0.
2. **`commands/qg.md`**
   - `argument-hint` (line 3): `both` 추가.
   - Quick Reference 테이블: `/qg both` 행 추가.
   - zero-click 관련 문구(Scope/Cost/Pipeline Rules) 정합.
3. **`README.md`**
   - P18 bullet (line ~22): gate-scope는 항상 질문(runtime scope는 여전히 `requires_decision` 조건부) 명시. **신규 P# 추가 없이 기존 P18 bullet에 흡수** (feedback_devbrew_design_lightness).
4. **`.claude-plugin/plugin.json`**: `version` 2.3.0 → 2.4.0.
5. **`CHANGELOG.md`**: `## [2.4.0] — 2026-06-04` —
   - Added: upfront gate-scope 결정(Review만 / 둘 다), `/qg both` arg.
   - Changed: full `/qg`의 기본이 더 이상 무클릭 둘 다가 아님 — 무클릭 둘 다는 `/qg both` 사용.
6. **`tests/harness/test_skill_orchestration_behavior.sh`**
   - line ~151 `v2.3.0` 앵커 → `v2.4.0`.
   - **신규 assertion:**
     - gate-scope 질문 존재: `question:.*both gates` 그리고 header `Gate scope`.
     - 순서: gate-scope 질문이 (a) Review gate dispatch **앞**, (b) requires_decision/runtime-scope 질문 **앞** (`assert_order`).
     - `gate` 도메인에 `both` 문서화 확인.
     - (방어) 앵커 `both gates`가 다른 decision-tool 질문에 미출현(고유성).

## 7. Verification Plan

- **자동:** repo root에서 `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` → 신규 포함 전 protocol-shape assertion PASS.
  - **Stale-red 베이스라인 (작업 전 캡처 필수 — issue b1a2):** main에 이 작업과 무관한 pre-existing red ~8개 존재(codex / consent / security / sandbox 계열 — project_qg_pre_existing_test_reds 메모리). 작업 전 전체 테스트를 1회 돌려 baseline red 집합을 기록하고, 회귀는 "baseline에 없던 새 red"로만 판정한다. 단, 본 작업이 직접 건드리는 `test_skill_orchestration_behavior.sh`는 변경 후 **green이어야** 한다(신규 gate-scope assertion 3종 포함).
- **수동 trace (관찰 기준 — issue c9d0):** §5 상태 전이 + 매핑 테이블 각 행을 재구성된 SKILL.md 흐름으로 추적. PASS 기준(관찰 가능):
  - `/qg` (무인자, non-trivia): Decision 1 AskUserQuestion이 `question:`에 `both gates` + header `Gate scope`로 발화.
  - `/qg review` / `--skip-runtime`: Decision 1 미발화, Review gate만 실행, Runtime 단계 skip.
  - `/qg both` + requires_decision surface 존재: Decision 1 미발화, Decision 2(runtime scope) 발화.
  - `/qg both` + surface 없음: 두 질문 모두 미발화, 둘 다 실행.
  - trivia diff: 어떤 질문도 미발화, `Trivia diff — all gates skipped` 출력.
- **Dogfood:** 브랜치에서 `/qg both`로 무클릭 둘 다 경로 확인(`/qg` 무인자는 이제 자기 자신에게 gate scope를 물어 메타 순환이므로 dogfood엔 `/qg both`·`/qg review` 사용).
- **TOC/문서 정합:** 섹션명 변경 시 해당 파일 TOC 동기화, README/CHANGELOG/plugin.json 버전 일치 확인.

## 8. Rejected Alternatives

- **config opt-in / env 기본값** (Q1 기각): zero-click 기본 유지 + opt-in. 사용자가 명시적으로 "항상 묻기"를 원함.
- **한 화면 통합 질문** (Q2 기각): 위험 surface 있을 때 gate-scope + runtime-scope를 한 AskUserQuestion에 2개 질문으로. "Review만" 골라도 runtime-scope 답을 낭비.
- **3지 (+Runtime만)** (Q3 기각): `/qg runtime` arg와 중복, 인터랙티브 옵션 군더더기.
- **escape 없음 / 항상 ask** (Q4 기각): 비인터랙티브 "둘 다" 실행 차단.
- **surgical 삽입** (구조 Q 기각): gate-scope sub-step을 Dispatch Loop에 따로 끼우고 기존 Upfront 섹션은 별도 유지 — upfront 로직이 2곳 분산. 통합 섹션이 단일 mental model.
- **신규 P# 원칙 추가**: design-lightness로 기존 P18에 흡수 — gate-scope upfront ask는 P18(Upfront 1-회 결정)의 자연 확장이지 직교 패턴이 아님.

## 9. Handoff Context

writing-plans / 새 세션 구현자가 이 design을 재구성하는 데 필요한 맥락 (issue d5c6).

**TL;DR — 인터뷰 4결정 (brainstorming):**
1. 발화 조건 = **항상 묻기** (zero-click happy-path를 gate-scope 한 건에 한해 의도적 override; 사용자 명시 지시 > 기본 원칙, using-superpowers 위계).
2. 기존 runtime-scope 질문과의 관계 = **순차 + 조건부** (Q1 먼저; "Review만" → 종료, "둘 다" → requires_decision일 때만 Q2).
3. Q1 선택지 = **2지** (Review만 / 둘 다). Runtime만은 `/qg runtime` arg가 담당.
4. 무클릭 escape = **`/qg both` arg** (env 기본값 없음 — design-lightness).
   - 구현 구조 = **통합 Upfront Execution Plan 섹션** (surgical 삽입 아님).

**Implicit context (왜 이렇게):**
- "zero-click" 원칙은 폐기가 아니라 *재정의*된다: gate-scope는 1회 upfront 클릭, 그 외 happy path는 무클릭. `/qg both|review|runtime`이면 gate-scope도 0클릭.
- `both`를 `gate` 토큰에 넣는 이유: `review`/`runtime`과 대칭 → 멘탈 모델 단일화, 새 env surface 없음.
- Decision 2 suppress 예외(`gate=both`는 runtime-scope를 답하지 않음): `/qg both`의 runtime 거동을 오늘날 무인자 `/qg`와 동일하게 보존하기 위함.

**Deferred to writing-plans:**
- 정확한 question/option 문구 확정 (앵커 `both gates`는 `question:` 필드 필수).
- SKILL.md `## Upfront Execution Plan` 재구성의 정확한 텍스트 + `## Dispatch Loop` step 2 재작성.
- `--skip-runtime` × `gate=` 충돌 advisory의 정확한 문구.
- 신규 V-test assertion 3종(존재 / 순서 / 고유성) 작성 + `v2.3.0`→`v2.4.0` 앵커 갱신.
- TDD: 테스트 먼저(red) → SKILL/command/문서 편집(green) → stale-red 베이스라인 대비 회귀 0 확인.
- (round-2 reviewer 9f3c1a72) `--skip-runtime` × `gate=runtime`/`gate=both` 모순 입력의 advisory 출력 PASS 기준(V-test 또는 수동 trace 한 줄) 추가.
- (round-2 reviewer b82e4d19) `## Dispatch Loop` step 2 ↔ `## Upfront Execution Plan` 정합성 grep assertion 1종 검토 — 예: Dispatch Loop에 Decision 1 short-circuit("Review만 → runtime skip") 키워드 존재 확인(두 섹션 drift 방지).
- (round-2 reviewer, low) §7 Dogfood `/qg both` 항목에 관찰 기준 한 줄("어떤 질문도 미발화 + 두 게이트 모두 실행") 보완.

## 10. Metadata

- Plugin: quality-gates, 2.3.0 → **2.4.0** (minor).
- Laws instantiated: Law 1 (Clarity Before Code — 실행 범위를 의식적 결정으로 승격), P18 (Upfront 1-회 결정 + 폐기 — 확장).
- 종속: 없음 (orchestration SKILL + command + 문서 + 테스트만; 새 스크립트/에이전트 없음).
