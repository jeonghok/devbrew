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
- Review gate(구 Gate 2) 내부 fix-loop, scout/adversarial/synthesizer,
  Runtime gate(구 Gate 3) verifier·test-scope-validator의 **로직**은 변경하지
  않는다 — 이름·번호만 (신규 이름 선행, 구 수치 이름은 괄호 병기; §5 명명 맵과 일관).
- **`discover-plan.sh`(plan-discovery 유틸)는 제거하지 않는다.** "plan verify
  제거"는 *verifier*(Gate 1 agent + 검증 verdict)에 한정하며, plan-discovery
  인프라는 test-scope-validator가 독립 소비하므로 존속한다 (verifier ≠ discovery).
  **재정의(reframe)의 범위 보장 (h3d9c7f0):** discover-plan.sh 변경은 *주석·문서
  라벨 ONLY* — 실행 로직·stdout 출력 계약(emit하는 `plan_path:` 절대경로 형식)·
  CLI 인터페이스(`--plan` 등)는 **byte-identical**로 불변. 따라서 이 파일을
  소비하는 test-scope-validator와의 계약이 바뀌지 않으며, "이름·번호만 변경" Non-goal과
  충돌하지 않는다 (주석 변경 ≠ 로직 변경). 회귀 가드: AC2가 `test_discover_plan.sh`
  존속을 요구하므로 출력 계약 변경 시 기존 fixture 테스트가 실패한다.
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
`plugins/quality-gates/` 하위에서 `tests/`·`CHANGELOG.md` 제외를 의미하며,
아래 ACs는 다음 **canonical grep**(이하 `SRC_GREP "<pattern>"`)을 그대로 실행한
결과로 판정한다 — copy-pasteable, exit/카운트 규칙 명시:

```bash
SRC_GREP() {  # 매칭 줄 출력; 0줄이면 "부재" 통과
  grep -rniE "$1" plugins/quality-gates \
    --include='*.md' --include='*.py' --include='*.sh' --include='*.json' \
  | grep -vE '/tests/|/CHANGELOG\.md' || true
}
```

대소문자는 `-i`로 일괄 처리(GATE/Gate/gate 동일 취급). "0건"은 `SRC_GREP`이
**0줄을 출력**함을 뜻한다.

**AC3 vs AC8 authority (a3f2c1e8):** AC3은 *Gate-1 프레이밍 문자열*
(`plan-verifier`, `gate 1`)을, AC8은 *모든 수치 gate 식별자*
(`gate [123]`, env var `GATE_[123]`)를 대상으로 한다. 두 sweep은 belt-and-suspenders로
중첩되며 **둘 다 0줄**이어야 한다 (충돌 아님 — 같은 방향의 단언). `discover-plan`이라는
**문자열 자체는 어느 패턴에도 포함되지 않으므로** 어떤 sweep의 매칭 대상도 아니다
(존속하는 discover-plan.sh는 두 AC와 무관).

**Gate 1 제거**

1. `agents/plan-verifier.md` 파일이 존재하지 않는다. `scripts/discover-plan.sh`는
   **유지**된다 (공용 plan-discovery 유틸; test-scope-validator가 소비).
2. `tests/test_plan_verifier_behavior.py`가 존재하지 않는다.
   `tests/test_discover_plan.sh`·`tests/test_worktree.sh`는 **유지**되며
   `tests/test_discover_plan.sh`가 **수정 없이(파일 byte-identical) green**이다 (b2d1e8a3:
   "byte-identical"로 §3과 표현 통일 — test 파일을 건드리지 않음. Phase C가 *다른*
   테스트(`test_detect_codex.sh` 등)의 600s 케이스를 수정하는 것과는 무관). 이
   무수정 green이 곧 discover-plan.sh의 **stdout 출력 계약**(emit하는 `plan_path:`
   절대경로 형식) 불변에 대한 기계적 보장이다 (h3d9c7f0).
   test-scope plan.md fixture는 test-scope-validator용이므로 **유지**된다.
3. `SRC_GREP "plan-verifier|gate ?1"` → 0줄 (`gate ?1`은 `?`로 공백이 optional이라
   "gate1"·"gate 1"을 모두 매칭 — 별도 `gate1` 토큰 불필요). `discover-plan` 참조는
   "Gate 1" 프레이밍 없이 test-scope-validator 컨텍스트로만 존속한다
   (`SRC_GREP "discover-plan.{0,40}gate ?1|gate ?1.{0,40}discover-plan"` → 0줄).
4. `SKILL.md`에 "Gate 1: Plan Verification" 섹션과 "Gate 1 FAIL decision" 섹션이
   없고, Dispatch Loop가 Review → Runtime 2단계이며 Contents TOC가 이를 반영한다.
   구체 검증 (full path, copy-pasteable):
   `grep -ciE "Gate 1: Plan Verification|Gate 1 FAIL decision" plugins/quality-gates/skills/quality-pipeline/SKILL.md`
   → `0`; `grep -cE "Dispatch Loop" plugins/quality-gates/skills/quality-pipeline/SKILL.md`
   ≥ `1` (섹션 존속). 그 섹션 본문의 "Gate 1"/"plan-verifier" 디스패치 단계 부재는
   AC3 sweep로 보장.
5. `commands/qg.md`에 `gate1` 모드가 없고 Gates 표/Quick Reference가 2-게이트를
   반영한다.
6. `scout.py`에 `gate1_verdict` 필드가 없다.

**비수치 rename**

7. `setup-qg.sh` arg 파싱이 `review|runtime`을 수용하고 `gate1|gate2|gate3`을
   거부한다. usage 텍스트가 비수치 이름을 쓴다.
8. `SRC_GREP "gate ?[123]|GATE_?[123]"` → 0줄 (`gate1/2/3`·`GATE1/2/3`·공백 변형
   `gate 1/2/3`을 대소문자 무관·env var underscore 변형 포함 전부 커버; AC3의
   gate1과 합쳐 **모든** 수치 gate 참조가 plugin source에서 전무함을 보장).
   신규 식별자 존재 확인(positive): `SRC_GREP "DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS"`,
   `SRC_GREP "DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION"`,
   `SRC_GREP "quality-gates:runtime-test-scope"`가 각각 ≥1줄.
9. `/qg review`, `/qg runtime` 서브커맨드가 `commands/qg.md`·`setup-qg.sh`에
   문서화·구현되어 있다. deprecated alias(`gate2`/`gate3`)는 존재하지 않는다.
   구체 검증 (full path):
   `grep -ciE "gate ?[23]" plugins/quality-gates/commands/qg.md plugins/quality-gates/scripts/setup-qg.sh`
   → `0` (alias 부재; AC8 전역 sweep의 파일-국소 재확인);
   `grep -cE "\\breview\\b" plugins/quality-gates/commands/qg.md` ≥ `1` AND
   `grep -cE "\\bruntime\\b" plugins/quality-gates/commands/qg.md` ≥ `1` (신규 서브커맨드 존재).
10. README 게이트 표가 정확히 2행(Review gate / Runtime gate)이다.

**wall-clock budget 제거**

11. `run_codex_reviewer.sh`에 `timeout 600`·`no_timeout_binary` 분기·
    `OVERRIDE_REASON=timeout`이 없고 `codex exec`를 직접 호출한다
    (`SRC_GREP "no_timeout_binary|OVERRIDE_REASON=timeout"` → 0줄).
12. `SRC_GREP "wall-clock|wall_clock|timeout[[:space:]]+600"` → 0줄.
    **bare `600` 숫자는 검색하지 않는다** — codex per-call ceiling은 오직
    `timeout 600` 구문으로만 존재했으므로 이 구문 부재가 충분조건이며, "무관한
    숫자" 판정 모호성이 제거된다. detect_codex의 5s probe는 `timeout 5`라 이
    패턴에 매칭되지 않아 자연히 보존된다 (AC18에서 별도 positive 확인).
13. README "인스턴스화한 원칙"에서 구 line 17 deferred 노트와 line 110
    "Per-call wall-clock ceiling: 600s (proxy for cost ceiling)" 표현이 제거된다.
14. 철학 AP16에서 `(b) wall-clock budget` guard가 제거되고 guard가 3개(max-iter /
    repeat 감지 / kill switch)로 재번호된다.

**철학 문서 정합**

15. 철학 문서가 quality-gates를 수치 gate로 지칭하지 않는다 (**content-based,
    라인 번호 비의존** — 선행 편집으로 라인이 밀려도 flaky하지 않음):
    `grep -nE "Gate [0-9]" docs/philosophy/devbrew-harness-philosophy.md` → 0줄
    (모든 qg gate 참조가 "Runtime gate"/"Review gate"로 대체). obsolete한
    "Gate 1로 loop back" 서술 부재 — 기계적 규칙(d1a3f609): `grep -in "loop back"
    docs/philosophy/devbrew-harness-philosophy.md`가 **0줄**이거나, 매칭 행에
    `quality-gates`·`qg`·`Gate`가 **하나도 없을 때만** 통과 ("qg 무관" 자의 판단 제거).
    §7 Phase D의 라인 번호는 편집 *위치 힌트*일 뿐 AC 판정 기준이 아니다.
16. canonical cycle "spec→plan→implement→review→verify→compound"는 철학 문서에
    그대로 유지된다 (grep 확인).

**Regression guard (유지 항목)**

17. P22 Cost Awareness·`cost_class`·Cost Class % 표·철학 §4.1 "시간 budget"·
    AP2 "attention budget"이 유지된다 — 구체 grep (각 ≥1줄):
    `grep -ciE "cost_class" plugins/quality-gates/skills/quality-pipeline/SKILL.md`,
    `grep -cE "Cost Class" plugins/quality-gates/README.md`,
    `grep -cE "P22|Cost Awareness" docs/philosophy/devbrew-harness-philosophy.md`,
    `grep -cE "시간 budget" docs/philosophy/devbrew-harness-philosophy.md`,
    `grep -cE "attention budget" docs/philosophy/devbrew-harness-philosophy.md`.
18. `detect_codex.sh`의 5s probe가 유지된다:
    `grep -cE "timeout.{0,4}5 codex --version" plugins/quality-gates/scripts/detect_codex.sh`
    ≥ `1`.
19. 모든 reviewer agent가 `disallowedTools` 격리를 유지한다:
    `grep -lE "disallowedTools" plugins/quality-gates/agents/adversarial.md \`
    `plugins/quality-gates/agents/runtime-verifier.md \`
    `plugins/quality-gates/agents/security-reviewer.md \`
    `plugins/quality-gates/agents/test-scope-validator.md` → 4개 파일 전부 매칭
    (plan-verifier 제거 후 남는 4개 reviewer agent).

**메타데이터·버전**

20. `plugin.json` version = `2.0.0`.
21. `CHANGELOG.md`에 `## [2.0.0] — 2026-05-30` 항목이 Removed/Changed +
    Migration 노트(old→new 매핑, alias 없음 경고)와 함께 추가된다.
22. **(Semantic AC — §8 "Semantic" 양식이 검증)** 전체 테스트 스위트가 green이다
    (삭제/수정/rename된 테스트 반영 후). AC1~AC21은 Mechanical, AC22가 유일한
    Semantic AC — §6↔§8 추적 일대일.

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

**Phase C — wall-clock budget 제거** (파일별 delete/modify/keep 명시)
- **수정** `scripts/run_codex_reviewer.sh` — `timeout 600` 래퍼·`no_timeout_binary`
  분기·`OVERRIDE_REASON=timeout` 제거 → `codex exec` 직접 호출.
- **수정** `README.md` — wall-clock budget deferred 노트(구 line 17) + codex
  "Per-call wall-clock ceiling: 600s (proxy for cost ceiling)" 표현(구 line 110) 제거.
- **수정** (삭제 아님) `test_codex_dispatch_invariant.sh`,
  `test_scout_codex_integration.sh`, `test_skill_codex_skip_prose.sh` — 600s
  ceiling·`no_timeout_binary` 경로 단언만 제거; codex dispatch 커버리지는 존속.
- **유지(불변)** `test_detect_codex.sh` — 5s probe·`timeout_binary_missing` skip은
  detect 경로라 유효; 600s 단언이 있을 경우에만 그 케이스 제거.
- **유지(불변)** `tests/mocks/bin-stubs/{gtimeout,timeout}` — **삭제 금지**:
  `detect_codex.sh`의 5s version probe가 여전히 timeout 바이너리를 요구하므로 mock이
  계속 사용된다 (Phase C의 핵심 함정 — self-review가 잡음).
- **유지(불변)** `detect_codex.sh` 5s probe + `timeout_binary_missing` skip 로직
  (per-call ceiling이 아니라 detect hang 방지; AC18).

**Phase D — 철학 문서** (라인 번호는 *현재 기준 위치 힌트*, 편집 시점에 패턴으로
재확인 — AC15는 content-based)
- `docs/philosophy/devbrew-harness-philosophy.md` — AP16의 `(b) wall-clock budget`
  guard 제거(현 ~line 434) + gate 참조 비수치화(현 ~line 201 "Gate 3"→"Runtime
  gate", ~363·456 "Gate 2"→"Review gate", ~329 qg 절 "review → runtime" + "Gate 1로
  loop back" 제거). **§4.1 "시간 budget"(현 ~561)·P22 전체·AP2 "attention budget"은
  손대지 않는다.**
- TOC(`## 목차`) 영향 없음 (섹션 추가/삭제/rename 없음).

**Phase E — 메타데이터**
- `.claude-plugin/plugin.json` — version 2.0.0.
- `CHANGELOG.md` — v2.0.0 항목 + Migration 노트.

## 8. Verification Plan

AC와 1:1 매핑. devbrew §4.5 세 양식(mechanical / semantic / runtime).

- **Mechanical — AC1~AC21 전부 (AC22 제외).** AC4·AC5·AC6·AC7·AC9도 grep/파일
  검사로 Mechanical에 속한다 (런타임 아님). §6의 `SRC_GREP` 0-count ACs
  (AC3·AC8·AC11·AC12) + 파일 존재/부재(`test ! -f plan-verifier.md`,
  `test -f discover-plan.sh`) + 신규 식별자 positive grep(AC8) + 철학 content
  grep(AC15·AC16) + regression positive grep(AC17·AC18·AC19: cost_class·P22·
  `timeout 5`·disallowedTools) + 버전(AC20) + CHANGELOG 항목(AC21) + 기존 린터
  (`check-allowed-tools-order.sh`) 통과. (`discover-plan`은 존속하므로 0-count
  대상에서 제외 — AC3가 "Gate 1" 프레이밍 부재만 확인.)
- **Semantic (AC22):** `plugins/quality-gates/tests/` 전체 스위트 실행 → green.
  삭제/수정/rename 반영된 테스트가 의도대로 통과/제거됨.
- **Runtime (행위 검증 — Mechanical을 대체하지 않음).** `/qg`(full =
  review→runtime), `/qg review`, `/qg runtime` smoke가 2-게이트 파이프라인을 실제
  dispatch하는지, codex 설치 시 detect→dispatch 정상·미설치 시 graceful
  skip(loud log) 정상인지 확인. **관찰 가능 pass 기준 (9e3c5d72):** `/qg` full 실행
  시 stdout에 "Review gate"·"Runtime gate" 헤더가 각각 ≥1회 출력되고 exit 0; "Gate
  1"/"Plan Verification" 헤더는 출력되지 않음. (이 smoke는 non-binding sanity —
  grep ACs 판정을 대체하지 않음.) **주의(false-pass 방지, e9b2d054): grep 기반
  ACs(AC3~AC12 등)는 반드시 Mechanical 결과로 판정한다 — "smoke green"이 grep
  부재 단언을 대체하지 못한다.** Runtime smoke 통과만으로 AC 충족을 주장하지 않는다.
- **R1 backstop (의도적 non-AC, g2e1a851):** codex 600s 제거의 hang 위험은
  설계상 "수용"이며 별도 AC로 강제하지 않는다. 단 backstop 존재를 다음 **구체
  2-명령 수동 확인**으로 기록한다 (검증 *면제*가 아니라 non-blocking 확인):
  (i) `DEVBREW_DISABLE_QG_CODEX=1 /qg runtime` 실행 → 출력에 codex skip loud log가
  보이고 codex 미dispatch; (ii) `/cancel-qg` 실행 → 프롬프트 정상 복귀(활성 세션
  취소 가능). 둘 중 어느 것도 hang하지 않음을 1행으로 기록.

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

## Handoff Context

*(compact 후 fresh-context writing-plans가 대화 없이 복원할 핵심. /compact 시
이 섹션·Acceptance Criteria·Files to Modify는 보존, 인터뷰 대화·중간 추론은 drop.)*

- **TL;DR:** quality-gates v1.32.3 → **v2.0.0**. Gate 1(plan-verifier agent) 제거 +
  wall-clock budget 제거(AP16 (b) guard, README deferred 노트, codex per-call 600s
  timeout) + 게이트 **비수치 rename**("Review gate" / "Runtime gate", 서브커맨드
  `/qg review`·`/qg runtime`, env `DEVBREW_QG_RUNTIME_*`). **즉시 전면 rename, alias
  없음 = v2.0.0 clean break.**
- **Implicit context (사용자-locked 결정, 재논의 불필요):**
  - budget 제거는 **wall-clock(시간)에 한정** — P22 Cost Awareness·`cost_class`·
    Cost Class % 표·§4.1 "시간 budget"·AP2 "attention budget"은 **유지** (CLAUDE.md
    Plugin Shape가 cost_class 강제).
  - **alias 없는 즉시 rename은 P23 deprecation-window 하우스 룰의 의도적 예외** —
    P17 사용자 주권이 하우스 룰에 우선. major bump가 breaking 신호, CHANGELOG
    Migration 노트가 이행 경로.
  - **`discover-plan.sh`는 제거하지 않는다** — plan *verify*(Gate 1 agent)만 제거.
    Runtime gate의 test-scope-validator가 `plan_path:auto`로 이 유틸에 독립 의존하므로
    존속(주석/라벨 reframe ONLY, stdout 계약 byte-identical).
  - codex 600s 제거의 hang 위험은 수용(§10 R1) — backstop은 Bash timeout +
    `DEVBREW_DISABLE_QG_CODEX=1` + `/cancel-qg`. detect_codex.sh의 **5s probe는 유지**.
- **Deferred to plan (writing-plans에서 확정):** Phase A–E 실행 순서, 각 테스트
  파일의 수정 범위(특히 Phase C의 600s 단언 제거 vs 케이스 보존), 철학 문서 편집의
  정확한 라인(AC15 content-grep으로 재확인), CHANGELOG Migration 노트 문구.
