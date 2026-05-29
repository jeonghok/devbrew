# Spec: quality-gates v2.0.0 — Gate 1 (plan verify) 제거 + wall-clock budget 제거 + 비수치 gate 명명

## 1. Context / Why

`quality-gates` 파이프라인은 현재 3-게이트 구조 — Gate 1 (Plan Verification) → Gate 2
(PR Review) → Gate 3 (Runtime Verification) — 이다. 두 가지 잔재를 제거하고 남는
게이트를 비수치 이름으로 재명명한다.

- **Gate 1 (plan verify) 중복.** plan 검증은 상류의 `superpowers:writing-plans` /
  `spec-distill`가 이미 담당한다. qg의 Gate 1은 동일 plan checkbox를 다시 교차
  확인하는 중복 단계이며, plan 없는 워크플로우에서는 거슬리는 게이트가 된다.
- **wall-clock budget 잔재.** v1.32.0 single-turn 재설계에서 cross-turn state
  machine과 wall-clock guard가 이미 삭제되었으나, 철학 문서 AP16의 4-guard 중
  `(b) wall-clock budget`, README의 `Wall-clock budget는 deferred` 노트, codex
  reviewer의 per-call 600s timeout이 잔존한다. 시간 기반 budget 개념을 qg와 철학
  문서 양쪽에서 정리한다.
- **수치 gate 이름.** Gate 1 제거 후 남는 두 게이트의 번호(2/3)를 폐기하고
  비수치 이름("Review gate" / "Runtime gate")으로 전환한다. "gate" 명사는
  플러그인 이름(`quality-gates`)·커맨드(`/qg`)와의 정합을 위해 유지한다.

요청자: 사용자 (2026-05-30, brainstorming 세션). 원하는 결과: 2-게이트 비수치
파이프라인 + wall-clock budget 개념 부재.

## 2. Goals

- `plan-verifier` agent + `/qg gate1` 모드 + `scout.py`의 `gate1_verdict` 필드를
  완전히 제거한다. **`discover-plan.sh`와 "Plan Discovery Sources" 문서는 유지**하되
  "Gate 1" 프레이밍만 제거(공용 plan-discovery 유틸리티로 재정의)한다 — Runtime
  gate의 `test-scope-validator`가 `plan_path:auto`로 이 스크립트에 독립적으로
  의존하기 때문이다.
- gate 번호(1/2/3)를 폐기하고 "gate" 명사를 유지한 비수치 이름으로 재명명한다:
  **Review gate**, **Runtime gate**.
- 서브커맨드를 `/qg review`, `/qg runtime`으로 전환한다.
- env var와 hook 키를 비수치화한다 (§4 명명 맵).
- wall-clock budget을 제거한다: 철학 AP16 `(b)` guard, README deferred 노트,
  codex reviewer per-call 600s timeout.
- **즉시 전면 rename, deprecated alias 없음** (P17 사용자 주권 우선, P23 예외로
  명시 문서화).
- SemVer `v1.32.3 → v2.0.0` (agent 제거 + 커맨드/env 표면 rename = breaking).

## 3. Non-goals / Out-of-Scope

- **P22 Cost Awareness·`cost_class`·Cost Class % 표는 변경하지 않는다.** budget 제거는
  *wall-clock(시간)* budget에 한정 (사용자 결정). cost budget은 CLAUDE.md Plugin
  Shape가 강제하므로 유지.
- **철학 §4.1 spec template의 "시간 budget"(Constraints 필드)·AP2 "attention
  budget"(은유)은 유지한다.** autonomous-loop guard와 별개 개념.
- **`docs/superpowers/specs/`·`plans/` 과거 문서, CHANGELOG 과거 항목은 재작성하지
  않는다** (기록물 — CHANGELOG·git 히스토리와 동급).
- Gate 2(Review) 내부 fix-loop, scout/adversarial/synthesizer, Gate 3(Runtime)
  verifier·test-scope-validator의 **로직**은 변경하지 않는다 — 이름·번호만.
- **`discover-plan.sh`(plan-discovery 유틸)는 제거하지 않는다.** "plan verify
  제거"는 *verifier*(Gate 1 agent + 검증 verdict)에 한정하며, plan-discovery
  인프라는 test-scope-validator가 독립 소비하므로 존속한다 (verifier ≠ discovery).
- 새 P#/AP# 신설 없음 (devbrew designs default to lightness).
- 마켓플레이스 canonical cycle("spec→plan→implement→review→verify→compound")은
  유지한다 — plan 단계는 writing-plans/spec-distill 소관이지 qg Gate 1이 아니므로
  Gate 1 제거가 이 cycle을 깨지 않는다.

## 4. Constraints

- **devbrew Plugin Shape 준수.** `plugin.json` version bump을 같은 커밋에;
  `CHANGELOG.md`에 v2.0.0 항목 + Migration 노트; README "인스턴스화한 원칙" 갱신.
- **Korean-primary 문서 컨벤션.** 영어는 식별자/고유명사/원문 인용/번역 어색한
  기술 용어에만.
- **즉시 전면 rename, alias 없음.** 구 이름(`gate1/2/3`, `DEVBREW_GATE3_*`)은
  deprecated alias로도 남기지 않는다 (P17 우선). 이는 P23 one-minor deprecation
  window 하우스 룰의 의도적 예외이며 §8/§10에 기록.
- **Law 2 격리 불변.** 모든 reviewer agent의 `disallowedTools: [Write, Edit,
  MultiEdit, NotebookEdit]` frontmatter scoping은 유지. 이 작업은 persona 약화가
  아님.
- **codex 600s 제거의 backstop.** 무한 hang 위험은 Bash 도구 timeout +
  `DEVBREW_DISABLE_QG_CODEX=1` + `/cancel-qg`로 커버 (§8 R1).
- **`detect_codex.sh`의 5s version-probe timeout은 유지** — per-call cost ceiling이
  아니라 탐지 hang 방지 liveness probe (제거 시 `/qg` 시작이 hang 가능).

## 5. 명명 맵 (old → new)

| 구분 | old | new |
|---|---|---|
| 표시명 | Gate 1 Plan Verification | *(제거)* |
| 표시명 | Gate 2: PR Review | **Review gate** |
| 표시명 | Gate 3: Runtime Verification | **Runtime gate** |
| 서브커맨드 | `/qg gate1` | *(제거)* |
| 서브커맨드 | `/qg gate2` | `/qg review` |
| 서브커맨드 | `/qg gate3` | `/qg runtime` |
| env | `DEVBREW_GATE3_MAX_RESOLUTIONS` | `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` |
| env | `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION` |
| hook 키 | `quality-gates:gate3-test-scope` | `quality-gates:runtime-test-scope` |
| scout 필드 | `gate1_verdict` | *(제거)* |

## 6. Acceptance Criteria

각 AC는 grep/파일 부재로 기계적으로 검증 가능하다. "plugin source"는
`plugins/quality-gates/` 하위에서 `tests/`·`CHANGELOG.md` 제외를 의미한다.

**Gate 1 제거**

1. `agents/plan-verifier.md` 파일이 존재하지 않는다. `scripts/discover-plan.sh`는
   **유지**된다 (공용 plan-discovery 유틸; test-scope-validator가 소비).
2. `tests/test_plan_verifier_behavior.py`가 존재하지 않는다.
   `tests/test_discover_plan.sh`·`tests/test_worktree.sh`는 **유지**된다
   (discover-plan 존속). test-scope plan.md fixture는 test-scope-validator용이므로
   **유지**된다.
3. plugin source에서 `grep -rni "gate1\|gate 1\|plan-verifier"` → 0건.
   `discover-plan` 참조는 "Gate 1" 프레이밍 없이 test-scope-validator 컨텍스트로만
   존속한다 (`grep -rni "discover-plan.*Gate 1\|Gate 1.*discover-plan"` → 0건).
4. `SKILL.md`에 "Gate 1: Plan Verification" 섹션과 "Gate 1 FAIL decision" 섹션이
   없고, Dispatch Loop가 Review → Runtime 2단계이며 Contents TOC가 이를 반영한다.
5. `commands/qg.md`에 `gate1` 모드가 없고 Gates 표/Quick Reference가 2-게이트를
   반영한다.
6. `scout.py`에 `gate1_verdict` 필드가 없다.

**비수치 rename**

7. `setup-qg.sh` arg 파싱이 `review|runtime`을 수용하고 `gate1|gate2|gate3`을
   거부한다. usage 텍스트가 비수치 이름을 쓴다.
8. plugin source에서 `grep -rno "GATE3\|gate3\|gate2\|gate 2\|gate 3"` → 0건.
   `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`, `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`,
   `quality-gates:runtime-test-scope`가 존재한다.
9. `/qg review`, `/qg runtime` 서브커맨드가 `commands/qg.md`·`setup-qg.sh`에
   문서화·구현되어 있다. deprecated alias(`gate2`/`gate3`)는 존재하지 않는다.
10. README 게이트 표가 정확히 2행(Review gate / Runtime gate)이다.

**wall-clock budget 제거**

11. `run_codex_reviewer.sh`에 `timeout 600`·`no_timeout_binary` 분기·
    `OVERRIDE_REASON=timeout`이 없고 `codex exec`를 직접 호출한다.
12. plugin source에서 `grep -rni "wall-clock\|wall_clock\|600"` → codex per-call
    ceiling 관련 0건 (detect_codex의 5s probe·무관한 숫자 제외).
13. README "인스턴스화한 원칙"에서 구 line 17 deferred 노트와 line 110
    "Per-call wall-clock ceiling: 600s (proxy for cost ceiling)" 표현이 제거된다.
14. 철학 AP16에서 `(b) wall-clock budget` guard가 제거되고 guard가 3개(max-iter /
    repeat 감지 / kill switch)로 재번호된다.

**철학 문서 정합**

15. 철학 gate 참조가 비수치화된다: line 201 "Gate 3"→"Runtime gate",
    line 363·456 "Gate 2"→"Review gate", line 329의 qg 절이 "review → runtime"으로
    갱신되고 obsolete한 "Gate 1로 loop back" 서술이 제거된다.
16. canonical cycle "spec→plan→implement→review→verify→compound"는 철학 문서에
    그대로 유지된다 (grep 확인).

**Regression guard (유지 항목)**

17. P22 Cost Awareness 전체, 모든 `cost_class` 선언, Cost Class % 표, 철학 §4.1
    "시간 budget", AP2 "attention budget"이 유지된다 (grep 확인).
18. `detect_codex.sh`의 `timeout 5 codex --version` probe가 유지된다.
19. 모든 reviewer agent의 `disallowedTools` 격리가 유지된다.

**메타데이터·버전**

20. `plugin.json` version = `2.0.0`.
21. `CHANGELOG.md`에 `## [2.0.0] — 2026-05-30` 항목이 Removed/Changed +
    Migration 노트(old→new 매핑, alias 없음 경고)와 함께 추가된다.
22. 전체 테스트 스위트가 green이다 (삭제/rename된 테스트 반영 후).

## 7. Files to Modify

**Phase A — Gate 1 (verifier) 제거**
- 삭제: `agents/plan-verifier.md`, `tests/test_plan_verifier_behavior.py`.
- **유지/재정의** (삭제 아님): `scripts/discover-plan.sh`("Gate 1" 주석/라벨 →
  공용 plan-discovery 유틸 프레이밍), `tests/test_discover_plan.sh`,
  `tests/test_worktree.sh`(불변), test-scope plan.md fixture(불변).
- `skills/quality-pipeline/SKILL.md` — Gate 1 섹션·FAIL decision·Dispatch Loop
  step 2·Final summary·Contents TOC 제거. 단 test-scope-validator dispatch의
  `plan_path: <path or 'auto'>`(auto = discover-plan.sh)는 **유지**.
- `commands/qg.md` — `gate1` 모드, Gates 표, Quick Reference.
- `scripts/setup-qg.sh` — arg 파싱·usage.
- `scripts/scout.py` — `gate1_verdict` 필드.
- `README.md` — 인스턴스화한 원칙(구 11·14), 게이트 표, 사전요건 표.
  "Plan Discovery Sources" 섹션·구조 트리의 discover-plan 라벨은 "(Gate 1)" →
  "(Runtime gate test-scope-validator)" 프레이밍으로 **재서술**(삭제 아님).
- 잔여 참조 audit: `scripts/build_codex_prompt.py`, `scripts/run_codex_reviewer.sh`
  (plan 컨텍스트 문자열).

**Phase B — 비수치 rename** (§5 맵)
- `skills/quality-pipeline/SKILL.md`, `commands/qg.md`, `commands/cancel-qg.md`,
  `scripts/setup-qg.sh`, `scripts/detect-runtime.sh`,
  `scripts/compute-test-scope-candidates.sh`,
  `skills/quality-pipeline/references/dependency-check.md`,
  `skills/quality-pipeline/references/state-file-format.md`, `README.md`.
- 관련 테스트: `test_setup_qg.sh`, `test_detect_runtime.sh`,
  `test_compute_test_scope_candidates.sh`, `test_runtime_verifier_*`,
  `test_test_scope_validator_*`, `check-allowed-tools-order.sh` 등 GATE3/gate2
  참조 전부.

**Phase C — wall-clock budget 제거**
- `scripts/run_codex_reviewer.sh` — `timeout 600` 래퍼·`no_timeout_binary`·
  `OVERRIDE_REASON=timeout`.
- `README.md` — 구 line 17·110.
- 테스트: `test_codex_dispatch_invariant.sh`, `test_detect_codex.sh`,
  `test_scout_codex_integration.sh`, `test_skill_codex_skip_prose.sh`,
  `tests/mocks/bin-stubs/{gtimeout,timeout}` — timeout 케이스/mock 의존 정리.
- 유지: `detect_codex.sh` 5s probe.

**Phase D — 철학 문서**
- `docs/philosophy/devbrew-harness-philosophy.md` — AP16 line 434, gate 참조
  line 201·329·363·456. (§4.1 line 561·P22·AP2는 손대지 않음.)
- TOC(`## 목차`) 영향 없음 (섹션 추가/삭제/rename 없음).

**Phase E — 메타데이터**
- `.claude-plugin/plugin.json` — version 2.0.0.
- `CHANGELOG.md` — v2.0.0 항목 + Migration 노트.

## 8. Verification Plan

AC와 1:1 매핑. devbrew §4.5 세 양식(mechanical / semantic / runtime).

- **Mechanical (AC1–AC18):**
  `grep -rni "gate1\|gate 1\|plan-verifier\|GATE3\|gate2\|gate 2\|gate 3\|wall-clock\|wall_clock\|timeout 600"`
  를 plugin source(tests/CHANGELOG 제외)에 실행 → 0건. (`discover-plan`은 존속하므로
  0-count grep에서 제외; 대신 "Gate 1" 프레이밍 부재만 확인.) 삭제 파일 부재 확인
  (`test ! -f plan-verifier.md`), 존속 파일 존재 확인 (`test -f discover-plan.sh`).
  신규 env/서브커맨드 존재 확인 (grep positive). 유지 항목 regression grep
  (cost_class·P22·5s probe·disallowedTools positive). 기존 린터
  (`check-allowed-tools-order.sh`) 통과.
- **Semantic (AC22):** `plugins/quality-gates/tests/` 전체 스위트 실행 → green.
  삭제/rename 반영된 테스트가 의도대로 통과/제거됨.
- **Runtime (AC4–AC10):** `/qg`(full = review→runtime), `/qg review`,
  `/qg runtime` smoke 실행. codex 설치 환경에서 detect→dispatch 정상,
  미설치 환경에서 graceful skip(loud log) 정상.

## 9. Rejected Alternatives

- **게이트 번호 유지(gap) 또는 재배정(2→1, 3→2).** 비수치 명명이 더 깔끔하다는
  사용자 결정으로 기각. (gap은 blast radius 최소였으나 "빈 번호"가 어색;
  재배정은 env rename + major churn.)
- **deprecated alias 1-minor 유지 (P23 준수).** 사용자가 "즉시 전면 rename, alias
  없음" 선택. v2.0.0 clean break로 정당화. **이는 P23 deprecation-window 하우스
  룰의 의도적 예외** — 사용자 주권(P17)이 하우스 룰에 우선하며, major bump가
  breaking을 신호하고 Migration 노트가 이행 경로를 문서화한다.
- **P22/cost_class 제거.** budget 제거를 wall-clock에 한정하는 사용자 결정 +
  CLAUDE.md Plugin Shape가 cost_class를 강제하므로 기각.
- **codex 600s timeout 유지(표현만 정리).** 사용자가 timeout 자체 제거 선택.
  Hang 위험은 §8 R1 backstop으로 수용.
- **`detect_codex.sh` 5s probe도 제거.** 탐지 hang 방지 liveness probe이지
  per-call budget이 아니므로 유지 (사용자 설계 승인 시 이견 없음).
- **`discover-plan.sh` 전면 제거.** self-review에서 Runtime gate의
  test-scope-validator가 `plan_path:auto`로 discover-plan에 의존함을 발견. 전면
  제거 시 test-scope-validator의 plan-scope 비교(cherry-pick-suspicion 판정)가
  약화 = Runtime 로직 변경이 되어 Non-goal과 충돌. 사용자가 "verifier만 제거,
  discover-plan 유지" 선택으로 기각 — plan *verify*(Gate 1 agent)와 plan
  *discovery*(공용 유틸) 분리.

## 10. Risks / 의도적 일탈

- **R1 — codex hang.** 600s 제거로 codex 서브프로세스 무한 hang 가능.
  Backstop: Bash 도구 timeout, `DEVBREW_DISABLE_QG_CODEX=1`, `/cancel-qg`.
- **R2 — P23 deprecation 위반.** alias 없는 즉시 rename. v2.0.0 clean break +
  P17 사용자 선택으로 정당화, §9에 기록.
- **R3 — Law 1 instantiation 축소.** Gate 1 제거 후 qg의 Law 1은 Runtime gate의
  evidence-required SKIP(구 README line 19)으로 잔존 — 손실 아님.
- **R4 — AP16 guard 약화.** wall-clock 제거로 guard가 (a)max-iter (b)repeat 감지
  (c)kill switch 3개로 축소. P18(정체 감지)의 핵심(max-iter+repeat)은 유지되어
  unbounded-autonomy 방어는 성립.

## 11. Metadata

- **Author:** 사용자 + Claude (brainstorming 세션)
- **Created:** 2026-05-30 (ISO 8601)
- **Plugin:** `plugins/quality-gates/` v1.32.3 → v2.0.0
- **Parent:** brainstorming 세션 (인자: "qg에서 plan verify 제거 및 버짓과 관련된
  부분 제거(철학에서도 제거)")
- **Spec version:** 1.0
- **관련 원칙:** Law 1 (구조적 게이트), Law 2 (격리 불변), P17 (사용자 주권),
  P18/AP16 (unbounded autonomy — wall-clock guard 제거 후 3-guard), P22 (Cost
  Awareness — 유지), P23 (SemVer·deprecation — 의도적 예외).
