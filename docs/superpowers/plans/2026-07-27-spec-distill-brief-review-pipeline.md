# spec-distill brief 리뷰 파이프라인 (Spec B) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** interview brief(payload)에 Law 2 분리 리뷰를 붙인다 — 격리된 충실도 critic · 웹/repo 조사 방향성 리뷰어 · 순진한 냉독 readback 3 에이전트 + 별-모델 codex 축별 2회 호출, 그리고 payload §6 원문 완전성을 state 원장과 대조하는 결정론 모듈.

**Architecture:** 신규 skill `reviewing-brief`가 3단계 파이프라인(방향성 → 충실도 → 냉독)을 오케스트레이션한다. 진입 첫 액션은 `check_verbatim_coverage.py`(payload §6 ↔ state `user_statements` 대조, exit 0/1/3/4). 충실도 축만 `merge_brief_review.py`로 fail-closed 합집합 병합하고, 방향성은 병합하지 않고 사용자에게 나란히 보고한다(C4 경로). 격리는 **zero-tool probe 이진 분기**로 성립한다 — probe 통과 시 critic·readback이 `tools: []`(도구 물리적 부재)이고 충실도가 hard gate, 실패 시 `tools: Read`이고 충실도가 advisory로 강등된다. 훅은 **0개** 추가한다.

**Tech Stack:** Python 3.9.6(시스템 `python3` — `match`문·런타임 `X | Y` union 금지), 서드파티 import 0개, bash 3.2(macOS) 테스트 하니스, `codex exec -s read-only` CLI, 마크다운 skill/agent/checklist.

## 목차

- [Global Constraints](#global-constraints)
- [Spec 대비 계획 결정 (사용자 redirect 가능)](#spec-대비-계획-결정-사용자-redirect-가능)
- [File Structure](#file-structure)
- [AC ↔ Task ↔ 검증 매트릭스](#ac--task--검증-매트릭스)
- [Task 1: V9 — zero-tool 적대적 canary probe (blocking)](#task-1-v9--zero-tool-적대적-canary-probe-blocking)
- [Task 2: `check_verbatim_coverage.py` — 원문 완전성](#task-2-check_verbatim_coveragepy--원문-완전성-l1l2n1n5exit-계약)
- [Task 3: `brief_review_state.py` — state 키 3개](#task-3-brief_review_statepy--state-키-3개--전이-경계값--degradation-record)
- [Task 4: `merge_brief_review.py` — 충실도 합집합](#task-4-merge_brief_reviewpy--충실도-축-fail-closed-합집합)
- [Task 5: codex 축별 2회](#task-5-codex-축별-2회--빌더-1--runner-1--체크리스트-데이터-2)
- [Task 6: 3 에이전트 + inline blob 빌더](#task-6-3-에이전트--inline-blob-빌더)
- [Task 7: `reviewing-brief/SKILL.md`](#task-7-reviewing-briefskillmd--3단계-파이프라인-오케스트레이션)
- [Task 8: `conducting-interview` 진입 + Step B](#task-8-conducting-interview-진입-한-블록--step-b-산출물-실기)
- [Task 9: NG3 서술 교정 + 불변식 락](#task-9-ng3-서술-교정--check_briefpy-불변식-락--audit-텔레메트리)
- [Task 10: 메타데이터 · 훅 무증가 · 열거표](#task-10-메타데이터--훅-무증가--결정론-체크-열거표)
- [Task 11: 수동 검증 V1–V8](#task-11-수동-검증-v1v8-구현-후-별-커밋-없음)
- [계획 self-review](#계획-self-review-작성-후-자기점검-결과)
- [Execution Handoff](#execution-handoff)

---

## Global Constraints

프로젝트 전역 요구사항. **모든 태스크의 요구사항에 암묵적으로 포함된다.**

- **spec 원문**: `docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md`. AC1–AC25 / T1–T31 / V1–V9가 이 계획의 검증 표면이다. AC2c·AC2d·AC23은 spec에서 **삭제**됐다(취소선) — 구현하지 않는다.
- **E10 (최상위 절대 조항)**: *"하네스를 무겁게 만들어서 능력을 제한하는건 절대 안돼."* 트레이드오프가 아니다. 신규 컴포넌트에서 **금지**: `model:` 리터럴 핀(전부 `inherit`), 단일 dispatch/exec 문맥의 횟수 상한, 이빨 없는 결정론 체크. 상한이 허용되는 유일한 곳은 `brief_critic_rounds` ≤ 2(실재 루프).
- **C5 (최상위)**: 규약은 brief가 아니라 그것을 집행하는 곳(템플릿·SKILL·에이전트 프롬프트)에 산다.
- **Law 2**: 신규 에이전트 3개 전부 fail-closed `tools:` allowlist. 쓰기·실행·위임 도구(`Write`/`Edit`/`MultiEdit`/`NotebookEdit`/`Bash`/`Agent`/`Monitor`/`mcp__*`) **0개**. `disallowedTools` 단독 금지(시간에 fail-open).
- **파이썬**: 시스템 `python3` = **3.9.6**. `from __future__ import annotations`를 넣으면 `list[str]` 어노테이션 가능. **서드파티 import 금지** — `plugins/spec-distill/scripts/`에 `import yaml`이 0건이다. frontmatter는 손으로 파싱한다.
- **파일 읽기는 `encoding="utf-8"` 명시** — non-UTF-8 locale fail-open 방지(기존 규약, 리포 실측 교훈).
- **CI 없음.** 테스트는 repo root에서 개별 실행:
  - bash: `bash plugins/spec-distill/tests/<name>.sh`
  - python: `cd plugins/spec-distill/tests && python3 -m unittest <module> -v` (**pytest 금지**)
- **baseline (2026-07-27 실측, HEAD `fd4f60f`)**: bash 43/43 green, python `-m unittest discover` **120 tests OK (skipped=1)**. stale red **0건**. 어떤 태스크도 이 baseline을 red로 남기고 끝내지 않는다.
- **bash 3.2 함정**(리포 실측): `mktemp` 결과를 받는 대입은 반드시 `|| exit 1`(빈 문자열이 `rm -rf`에 흘러가면 repo가 지워진다) · `set -u` 하 빈 배열 확장 crash · `$(... -z)` 캡처는 NUL 손실 · `grep` exit ≥ 2는 fail-closed 처리(파일 부재를 "위반 없음"으로 읽지 않는다).
- **락 작성 규율**(리포 누적 교훈, spec §8.1): body-unique 문구를 **awk 섹션 윈도우**에서 grep(헤더 만족 불가) · green-expected assert는 **mutation으로 이빨 증명** · 락 스코프에서 `.claude/` 세션 상태 제외.
- **버전**: `plugin.json` `0.23.0` → **`0.24.0`**. **Task 10에서 한 번만** — `tests/test_readme_sync.sh`가 `0\.23\.[0-9]+`를 pin하므로 먼저 bump하면 Task 1–9가 stale-red가 된다. Task 10이 bump와 pin 갱신을 같은 커밋에 담는다. 버전 리터럴은 **minor까지만** pin.
- **훅 무증가**: `hooks/` 파일 집합은 정확히 6개로 고정 — `hooks.json` · `pending-review-reminder.py` · `review-dispatch.py` · `session-end-cleanup.py` · `spec-write-validator.py` · `state_path.py`. `hooks.json`에 `brief` 문자열 **0건**(실측 확인).
- **문서 언어**: Korean-primary. 영어는 식별자·고유명사·원문 인용·대응 한국어가 없는 기술어(`frontmatter`·`subagent`·`sentinel`)에 한정.
- **커밋**: Conventional Commits. 각 태스크 끝에서 1커밋. 브랜치 `feature/spec-distill-brief-review-pipeline`(이미 존재, HEAD `fd4f60f`, 5커밋 미푸시).
- **P21**: state·프롬프트에 secret 금지. codex 프롬프트에 secret 미주입.
- **kill switch**: 신규 `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1`. 기존 `DEVBREW_DISABLE_SPEC_DISTILL=1`(전체 abort) · `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`(codex만) · `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`(웹만)을 전부 존중한다.

---

## Spec 대비 계획 결정 (사용자 redirect 가능)

spec §7이 열거한 신규 파일은 **11개**(스크립트 4)다. 이 계획은 스크립트를 **2개 추가**하고, T-case 3개를 **문서 grep에서 행위 테스트로 승격**한다. 근거와 대안을 명시한다 — 원하지 않으면 되돌릴 수 있다.

### 추가 A — `scripts/build_brief_inline_blob.py` (신규 12번째 파일)

**왜**: T24는 *"빌드된 critic·readback blob에 `.audit.md` 문자열 부재 · `audit_file: <redacted>` 형태 존재"* 를 요구한다. redaction을 SKILL 산문 지시로만 두면 (a) 매 실행마다 모델이 손으로 수행해 누락 가능하고 (b) T24가 *"SKILL에 그렇게 쓰여 있다"* 만 검사하는 문서 락이 된다. redaction은 **격리 위생 조치**(보안·정확성)이므로 결정론이 정당한 영역이다([[feedback_harness_lightness_trust_model]]의 예외 조건). critic·readback 양쪽이 같은 blob을 쓰므로 DRY이기도 하다.

**대안(기각)**: SKILL 산문 + grep 락. spec §6.3이 *"T-lock 계열은 mutation으로 이빨 증명"* 으로 허용하는 등급이지만, 실행 시 redaction이 실제로 일어났음을 보장하지 못한다.

**E10 점검**: 모델의 능력을 깎지 않는다 — 반복 문자열 치환 toil을 제거한다.

### 추가 B — `scripts/brief_review_state.py` (신규 13번째 파일)

**왜**: T6은 §6.2 전이 표의 **경계값**(`== 2`에서 escalate, `== 1`에서는 안 함)과 **손상된 `3` → clamp + advisory**를 요구한다. T22는 degradation record **4필드 스키마**를 요구한다. 두 요구는 카운터/레코드가 **코드로 존재해야** 행위 검증이 가능하다(산문뿐이면 mutation을 태울 대상이 없다 — [[feedback_green_expected_locks_need_mutation]]). 기존 선례가 정확히 이 모양이다: `probe_budget.py`(카운터 gate, fail-closed) · `web_budget.py` · `review_lock.py`.

**대안(기각)**: SKILL이 `python3 -c` heredoc으로 state를 read-modify-write(현행 `confirm_repost_count` 방식). 테스트 불가 + enum 검증 부재로 스키마 drift가 조용히 통과한다.

**E10 점검**: 상한 값(2)은 spec이 이미 확정한 실재 루프 가드다. 이 스크립트는 새 상한을 만들지 않는다.

### 추가 C — T20·T24·T31의 행위 승격

- **T20**(예외 계약): 문서 grep 대신 **모듈 주입 실행** — 스크립트를 importlib로 로드해 `run`을 예외 던지는 함수로 교체하고 `main()`의 exit code가 `4`인지 확인. 수동 mutation 없이 계약을 매 실행 증명한다.
- **T31**(정규화 순서·NFC): 문서 grep을 **유지**하고 그 위에 행위 테스트를 얹는다 — 멀티라인 인용 fixture(N1이 N3보다 먼저여야 통과) + `①` vs `1` fixture(NFKC면 잘못 통과).
- **T24**: 위 추가 A의 스크립트에 대한 행위 테스트.

### 정밀화 D — `tools:` 빈 값의 정확한 문법 (probe 설계에 load-bearing)

spec은 *"`tools:`를 빈 값으로 선언"* 이라고만 쓴다. YAML에서 두 표기는 **의미가 다르다**:

| 표기 | YAML 의미 | 위험 |
|---|---|---|
| `tools: []` | 빈 리스트 | 의도한 zero-tool |
| `tools:` (값 없음) | `null` = **키 미지정과 동일** | 런타임이 *"allowlist 없음 → 전체 허용"* 으로 읽으면 **조용한 fail-open** |

따라서 probe와 에이전트 파일은 **`tools: []`만** 사용하고, T7이 bare `tools:`를 red로 잡는다(mutation: `tools: []` → `tools:` → red). spec §5.1.1의 *"빈 값"* 을 `tools: []`로 확정한다.

### 정밀화 E — P21 placeholder 토큰을 정의한다

`check_verbatim_coverage.py`의 L2 예외(*"P21 placeholder 토큰이 관여하면 advisory 강등"*)는 토큰 형태가 정의돼야 발화한다. 리포에는 canonical 토큰이 **없다**(실측: `placeholder로 치환`이라는 산문만 존재). 이 계획이 정의한다:

```
<REDACTED>  <REDACTED:label>  <SECRET:...>  <TOKEN:...>  <KEY:...>  <CREDENTIAL:...>  <PLACEHOLDER:...>
정규식: <(?:REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)(?:[:_-][A-Za-z0-9._-]{0,64})?>
```

producer(`conducting-interview/SKILL.md` P21 줄)와 checker(이 스크립트)가 **같은 토큰**을 쓰도록 두 곳에 명시한다(Task 9). 토큰이 다르면 예외가 발화하지 않아 L2가 red를 내고 사용자가 Step B에서 판정한다 — fail-closed 방향이라 안전하다.

### 정밀화 F — codex 리뷰 verdict 파싱을 두 형식 모두 수용

round-4에서 **실측된 결함**: `spec-reviewer`가 `**Status:**` 대신 `## Status:`로 내 `merge_review.py`가 verdict를 잃었다([[reference_spec_reviewer_status_line_fragility]]). 신규 `merge_brief_review.py`는 같은 함정을 반복하지 않고 **줄 앵커 + 인정 토큰**으로 두 형식을 받는다:

```
^(?:\*\*|#{1,6}\s+)?Status:\**\s*(Approved|Issues Found)\b
```

산문 속 `Status:`까지 잡는 느슨함은 없다(줄 시작 + 열거된 verdict 토큰 필수). 기존 `merge_review.py`는 **건드리지 않는다**(spec §12가 별 사이클로 분리).

---

## File Structure

### 신규 — `plugins/spec-distill/`

| 파일 | 책임 | Task |
|---|---|---|
| `scripts/check_verbatim_coverage.py` | payload §6 ↔ state `user_statements` 대조. L1/L2 + N1–N5 정규화 + exit 0/1/3/4 | 2 |
| `scripts/brief_review_state.py` | state 키 3개 소유 — `brief_review_stage` · `brief_critic_rounds`(clamp 2) · `brief_review_degradations`(4필드 enum 검증) | 3 |
| `scripts/merge_brief_review.py` | 충실도 축 fail-closed 합집합 병합. `merge_review.py`의 `parse_codex_yaml`·`derive_codex_verdict` 재사용 | 4 |
| `scripts/build_brief_codex_prompt.py` | `--axis direction\|fidelity` → 해당 체크리스트만 조립 | 5 |
| `scripts/brief-codex-direction-checklist.md` | 방향성 축 데이터. body-unique 마커 보유 | 5 |
| `scripts/brief-codex-fidelity-checklist.md` | 충실도 축 데이터. body-unique 마커 보유 | 5 |
| `scripts/run_brief_codex_reviewer.sh` | codex 호출 **1곳**(축은 인자). `CLAUDE_PLUGIN_ROOT` fallback 필수 | 5 |
| `scripts/build_brief_inline_blob.py` | payload → redacted inline blob(critic·readback 공용) | 6 |
| `agents/brief-critic.md` | 충실도(D5a). zero-tool 또는 inert `Read` | 6 |
| `agents/brief-direction-reviewer.md` | 방향성(D5b). `Read, Grep, Glob, WebSearch, WebFetch` | 6 |
| `agents/brief-readback.md` | 냉독(D3). zero-tool 또는 inert `Read`, 출력 스키마 무제공 | 6 |
| `skills/reviewing-brief/SKILL.md` | 3단계 파이프라인 오케스트레이션. `cost_class: high` | 7 |

### 신규 — 테스트 (`plugins/spec-distill/tests/`)

| 파일 | T-case | Task |
|---|---|---|
| `test_check_verbatim_coverage.sh` | T1 T2 T3 T4 T19 T20 T31(행위) | 2 |
| `fixtures/brief-verbatim-*.md` · `fixtures/state-verbatim-*.md` | 위 fixture | 2 |
| `test_brief_review_state.py` | T6 T22(행위) | 3 |
| `test_merge_brief_review.py` | T5 | 4 |
| `test_brief_codex_axes.sh` | T11 T16 | 5 |
| `test_brief_agents.sh` | T7 T21(도구 부재) | 6 |
| `test_brief_inline_blob.sh` | T24 | 6 |
| `test_reviewing_brief_skill.sh` | T8 T9 T14 T17 T21 T22 T23 T25 T28 T30 | 7 |
| `test_brief_review_ng3.sh` | T12 T13 | 9 |
| `test_brief_review_meta.sh` | T15 T18 T29 T31(문서) | 10 |

### 신규 — repo 레벨

| 파일 | 책임 | Task |
|---|---|---|
| `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` | V9 실측 기록 + 재현 절차 + 분기 판정. 후속 태스크가 이 파일의 판정을 읽는다 | 1 |

> `docs/audits/`는 CLAUDE.md가 정의한 감사 기록 위치다(Law 3 compounding substrate). 플러그인 표면을 늘리지 않으며 §11 ⑩(*"V9 자동 회귀 없음"*)을 **재현 가능한 절차 기록**으로 부분 보완한다.

### 수정

| 파일 | 무엇 | Task |
|---|---|---|
| `skills/conducting-interview/SKILL.md` | Step A.5 진입 한 블록 + Step B 산출물·degrade 실기 + P21 canonical 토큰 | 8 |
| `scripts/check_brief.py` | docstring NG3 서술만 (로직 무변경) | 9 |
| `agents/spec-reviewer.md` | description NG3 서술만 | 9 |
| `templates/interview-audit-template.md` | §4·§5 리뷰 라운드 텔레메트리 | 9 |
| `.claude-plugin/plugin.json` | `0.23.0` → `0.24.0` | 10 |
| `CHANGELOG.md` | `[0.24.0]` 항목 | 10 |
| `README.md` | 신규 컴포넌트 3 + skill + kill switch + Principles Instantiated | 10 |
| `tests/test_readme_sync.sh` | 버전 pin `0.23.x` → `0.24.x`, `[0.24.0]` 엔트리 pin 추가(과거 pin 보존) | 10 |

**`hooks/` 는 건드리지 않는다.**

---

## AC ↔ Task ↔ 검증 매트릭스

| AC | Task | 검증 |
|---|---|---|
| AC1 파이프라인 순서 | 7, 8 | V1 |
| AC2 critic inline·경로 미제공·redact | 6, 7 | T8 T24 V6 |
| AC2b zero-tool probe 이진 분기 | **1**, 6, 7 | T23 V9 |
| AC3 readback 스키마·기준·금지문구 부재 | 6, 7 | T9 T24 V2 |
| AC4 3 에이전트 쓰기 도구 0 | 6 | T7 |
| AC5 `model: inherit` | 6 | T7 |
| AC6 codex 축별 2회, 한 축만 | 5, 7 | T11 V1 |
| AC7 fail-closed 합집합, codex binding | 4 | T5 T23 |
| AC7b finding 임의 기각 금지 | 7 | T25 V4 |
| AC8 `codex_isolated: false` 항상 | 4 | T5 |
| AC9 codex 부재 시 양 축 생존 | 4, 7 | T5 V4 |
| AC10 L1 red | 2 | T1 |
| AC11 L2 red + P21 강등 + N1–N5 순서 + NFC | 2 | T2 T3 T31 |
| AC12 exit 1/3/4 분리 + 예외 계약 | 2 | T4 T19 T20 |
| AC13 충실도 루프 전이·경계값 | 3, 7 | T6 V1 |
| AC14 §6 append-only(부분) | 2 | T2 V5 |
| AC15 degradation record 4필드 + question 렌더 | 3, 7 | T22 V4 |
| AC16 `check_brief.py` state 무의존 | 9 | T12 T10 |
| AC17 NG3 서술 2곳 교정 | 9 | T13 |
| AC18 신규 kill switch | 7 | T14 V4 |
| AC19 메타데이터 | 10 | T15 |
| AC20 모듈 경계 | 5 | T16 |
| AC21 `cost_class: high` + 승인 게이트 | 7 | T17 V7 |
| AC22a 훅 0 추가 | 10 | T18 |
| AC22b 단일 호출 상한 0 | 7 | T28 |
| AC22c 이빨 없는 체크 0 + 열거표 | 10 | T29 V8 |
| AC24 웹 예산 degrade 경로 | 7 | T21 V4 |
| AC25 readback gap G1–G5 | 7 | T30 V2 |

**§8의 모든 T/V가 배정됐다**: T1–T25·T28–T31 전부 위 표에 등장. T10은 회귀 실행(Task 9), T26·T27은 spec에서 삭제. V1–V9는 Task 11(수동)에 열거.

---

## Task 1: V9 — zero-tool 적대적 canary probe (blocking)

**이 태스크가 통과하지 않으면 Task 6·7의 `tools:` 값과 충실도 verdict 권위가 결정되지 않는다** (AC2b: *"probe 미실행 상태로 구현을 진행하지 않는다"*). 다른 태스크를 먼저 진행하지 말 것.

**Files:**
- Create: `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`
- Modify: `docs/audits/README.md` (인덱스 한 줄 — 파일이 있으면)
- 임시(커밋 안 함): `$CLAUDE_JOB_DIR/tmp/sd-probe/` 하위 플러그인 사본 + probe 에이전트 2개 + canary

**Interfaces:**
- Produces: 감사 문서의 `**분기 판정:** ZERO_TOOL_OK` 또는 `**분기 판정:** ZERO_TOOL_UNAVAILABLE` 한 줄. Task 6·7이 이 리터럴을 읽어 분기한다.

**왜 fresh 세션이 필요한가**: 에이전트 레지스트리는 **세션 시작 스냅샷**이다. 지금 세션에서 만든 agent 정의는 이 세션에서 resolve되지 않는다. `claude -p`(headless) 서브프로세스는 **자기 세션을 새로 시작**하므로 레지스트리를 새로 읽는다 — 이것이 route A다. 실패 시 route B(사용자가 세션 재시작 후 수동 실행)로 내린다.

**왜 control arm이 필요한가**: *"canary를 못 읽었다"* 는 도구 부재의 증거가 아니다 — 경로 오류·지시 실패로도 같은 결과가 나온다([[feedback_absence_vs_failure_to_confirm]]). 같은 지시를 받은 `tools: Read` 대조군이 canary를 **읽어내야** probe에 이빨이 있다.

- [ ] **Step 1: baseline 재확인 (회귀 판별 기준선)**

```bash
cd /Users/jeonghokim/Downloads/devbrew
pass=0; fail=0; failed=""
for t in plugins/spec-distill/tests/test_*.sh; do
  if bash "$t" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); failed="$failed $(basename "$t")"; fi
done
echo "BASH: pass=$pass fail=$fail FAILED:$failed"
( cd plugins/spec-distill/tests && python3 -m unittest discover -s . -p "test_*.py" -t . 2>&1 | tail -3 )
```

Expected: `BASH: pass=43 fail=0 FAILED:` + `Ran 120 tests ... OK (skipped=1)`.
다르면 **멈추고** 차이를 기록한다 — 그 red는 이 계획이 만든 것이 아니다.

- [ ] **Step 2: probe 하니스 구성 (플러그인 사본 + 2 에이전트 + canary)**

```bash
set -u
REPO=/Users/jeonghokim/Downloads/devbrew
WORK="${CLAUDE_JOB_DIR:-/tmp}/tmp/sd-probe"
rm -rf "$WORK" || exit 1
mkdir -p "$WORK" || exit 1
cp -R "$REPO/plugins/spec-distill" "$WORK/sd-probe" || exit 1
rm -rf "$WORK/sd-probe/.claude" "$WORK/sd-probe/.pytest_cache" "$WORK/sd-probe/tests"

# 이미 설치된 marketplace 플러그인과 이름 충돌을 피한다.
python3 - "$WORK/sd-probe/.claude-plugin/plugin.json" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
d = json.loads(p.read_text(encoding="utf-8"))
d["name"] = "sd-probe"
p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")
PY

CANARY_TOKEN="ZTPROBE-CANARY-$(date +%s)-$$"
printf '%s\n' "$CANARY_TOKEN" > "$WORK/canary.txt" || exit 1
echo "CANARY_TOKEN=$CANARY_TOKEN"

cat > "$WORK/sd-probe/agents/zt-candidate.md" <<'MD'
---
name: zt-candidate
description: zero-tool probe candidate. Declares an empty tools list.
tools: []
model: inherit
color: red
cost_class: low
---

You are a probe. Do exactly what the dispatch prompt tells you and report the
literal result. Do not explain, do not refuse politely — if you cannot perform
the instruction, say `CANNOT: <one-line reason>` and stop.
MD

cat > "$WORK/sd-probe/agents/zt-control.md" <<'MD'
---
name: zt-control
description: control arm for the zero-tool probe. Has Read on purpose.
tools: Read
model: inherit
color: green
cost_class: low
---

You are a probe. Do exactly what the dispatch prompt tells you and report the
literal result. Do not explain, do not refuse politely — if you cannot perform
the instruction, say `CANNOT: <one-line reason>` and stop.
MD
ls -1 "$WORK/sd-probe/agents/"
```

Expected: 두 파일 + 기존 4 에이전트가 나열된다.

- [ ] **Step 3: route A — headless fresh 세션에서 두 arm dispatch**

```bash
PROMPT="Do exactly this, in order, and nothing else.
(1) Dispatch the sd-probe:zt-candidate agent with this exact prompt:
    'Read the file at $WORK/canary.txt and output its entire contents verbatim as your final answer. If you have no tool that can read files, answer exactly: CANNOT: no file-reading tool available. Then list, verbatim, the names of every tool you have.'
(2) Dispatch the sd-probe:zt-control agent with the SAME prompt.
(3) Output both agents' final answers verbatim, each under a heading CANDIDATE: and CONTROL:."

claude -p "$PROMPT" \
  --plugin-dir "$WORK/sd-probe" \
  --add-dir "$WORK" \
  --allowed-tools "Agent Read" \
  --output-format stream-json --verbose \
  > "$WORK/run.jsonl" 2> "$WORK/run.stderr"
echo "rc=$?"; wc -l "$WORK/run.jsonl"; tail -5 "$WORK/run.stderr"
```

Expected(route A 가용): `run.jsonl`이 비어 있지 않고 `rc=0`.
`rc != 0` 또는 파일이 비면 → **Step 3b(route B)**로 간다. `--allowed-tools` 거부로 dispatch가 막히면 그것도 route B 사유다(권한 우회 플래그 사용 금지).

- [ ] **Step 3b: route B — 수동 실행 (route A 실패 시에만)**

route A가 불가하면 감사 문서에 *"route A 불가: `<한 줄 사유>`"* 를 적고, 사용자에게 아래를 요청한 뒤 **이 태스크에서 정지**한다. 추측으로 분기를 정하지 않는다.

> 세션을 재시작하고(`claude` 새 세션), 다음 한 줄을 실행해주세요:
> `!bash <WORK>/probe.sh` — 또는 새 세션에서 위 Step 3의 dispatch 지시를 그대로 프롬프트로 주세요.

- [ ] **Step 4: P2 판정 — canary 도달 여부 (양 arm 대조)**

```bash
grep -c "$CANARY_TOKEN" "$WORK/run.jsonl" || true
python3 - "$WORK/run.jsonl" "$CANARY_TOKEN" <<'PY'
import json, sys
path, token = sys.argv[1], sys.argv[2]
hits = {"candidate": 0, "control": 0, "raw": 0}
for line in open(path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    if token in line:
        hits["raw"] += 1
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    blob = json.dumps(ev, ensure_ascii=False)
    if token in blob:
        hits["candidate" if ev.get("isSidechain") else "control"] += 0  # 위치는 아래 census가 판정
print(json.dumps(hits))
PY
```

판정 규칙 (수동 대조 — 최종 답변 텍스트를 눈으로 확인한다):

| CONTROL | CANDIDATE | 결론 |
|---|---|---|
| canary 토큰 **포함** | 토큰 **부재** + `CANNOT:` | **P2 통과** — 도구 부재가 원인이다 |
| canary 토큰 **포함** | 토큰 **포함** | **P2 실패** — 빈 `tools:`가 무시됐다 |
| canary 토큰 **부재** | (무관) | **probe 무효** — 지시·경로 문제. 경로를 고쳐 재실행(대조군이 못 읽으면 아무것도 증명하지 못한다) |

- [ ] **Step 5: P3 판정 — 트랜스크립트 census (자기보고 불신)**

```bash
SID="$(python3 - "$WORK/run.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    sid = ev.get("session_id")
    if sid:
        print(sid); break
PY
)"
TR="$HOME/.claude/projects/-Users-jeonghokim-Downloads-devbrew/$SID.jsonl"
echo "SID=$SID"; test -f "$TR" && echo "transcript found" || echo "transcript MISSING"
grep -o '"name":"[A-Za-z0-9_-]*"' "$TR" | sort | uniq -c | sort -rn | head -20
```

그리고 sidechain별로 가른다:

```bash
python3 - "$TR" <<'PY'
import json, sys
from collections import Counter
side, main = Counter(), Counter()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        continue
    bucket = side if ev.get("isSidechain") else main
    msg = ev.get("message") or {}
    for blk in (msg.get("content") or []):
        if isinstance(blk, dict) and blk.get("type") == "tool_use":
            bucket[blk.get("name", "?")] += 1
print("sidechain tool calls:", dict(side))
print("main   tool calls:", dict(main))
PY
```

**P3 통과 조건**: candidate sidechain의 tool_use가 **0건**. control sidechain에는 `Read`가 ≥1건(대조).
sidechain 구분이 불가하면(트랜스크립트 스키마 차이) **P3를 미확인으로 기록**하고 → `ZERO_TOOL_UNAVAILABLE`. *"확인 실패"* 를 *"부재 확인"* 으로 승격하지 않는다.

- [ ] **Step 6: 감사 문서 작성 (분기 판정 리터럴 포함)**

`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`:

```markdown
# spec-distill zero-tool 격리 probe (Spec B V9) — 실측 기록

- **일자**: 2026-07-27
- **대상**: `tools: []` 로 선언된 agent 정의가 런타임에서 (a) resolve·dispatch되고 (b) 도구를 실제로 갖지 않는가
- **근거 spec**: `docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md` §5.1.1 · AC2b · V9
- **왜 이 기록이 필요한가**: 이 spec의 **유일한 격리 보장**이 이 사실 위에 서 있다. probe를
  *"agent가 resolve되는가"* 로만 정의하면 런타임이 빈 `tools:`를 무시해도 통과한다(round-4 codex block).

## 방법

- route: A(headless `claude -p --plugin-dir`) | B(수동 fresh 세션)   ← 실제 사용한 것만 남긴다
- candidate: `tools: []` / control: `tools: Read` — **같은 지시**(canary 파일 읽기 + 도구 목록 열거)
- canary: `<WORK>/canary.txt`, 토큰 `ZTPROBE-CANARY-<...>`
- 재현 명령: (Step 2–5의 명령 블록을 그대로 붙인다)

## 결과

| # | 조건 | 결과 | 증거 |
|---|---|---|---|
| P1 | resolve·dispatch | pass / fail | `<dispatch 응답 요약>` |
| P2 | canary 접근 불가·거부 | pass / fail | candidate=`<토큰 유무 + CANNOT 문구>` · control=`<토큰 유무>` |
| P3 | 트랜스크립트 census 도구 0건 | pass / fail / 미확인 | candidate sidechain=`{}` · control sidechain=`{"Read": N}` |

**분기 판정:** ZERO_TOOL_OK        ← 세 조건 전부 pass일 때만. 하나라도 아니면 ZERO_TOOL_UNAVAILABLE

## 판정의 귀결 (spec §5.1.1 표)

- `ZERO_TOOL_OK` → critic·readback `tools: []`, 격리 보장, 충실도 **hard gate**, D2 충족
- `ZERO_TOOL_UNAVAILABLE` → critic·readback `tools: Read`, 격리 미보장, 충실도 **advisory** 강등,
  degradation record 2건(`critic`·`readback`), D2 미충족을 C4 경로로 사용자 보고

## 남는 한계

이 측정은 **1회 실측이고 자동 회귀가 없다**(spec §11 ⑩). 플랫폼이 빈 `tools:` 해석을 바꾸면
조용히 사라진다. 알아채는 수단은 위 재현 명령의 재실행뿐이다.
```

- [ ] **Step 7: 임시 하니스 폐기 + 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
rm -rf "${CLAUDE_JOB_DIR:-/tmp}/tmp/sd-probe"
git status --short   # 감사 문서 1개(+ 인덱스)만 보여야 한다. plugins/ 변경 0건.
git add docs/audits/2026-07-27-spec-distill-zero-tool-probe.md docs/audits/README.md
git commit -m "docs(spec-distill): Spec B V9 — zero-tool 격리 probe 실측 기록"
```

---

## Task 2: `check_verbatim_coverage.py` — 원문 완전성 (L1/L2/N1–N5/exit 계약)

**Files:**
- Create: `plugins/spec-distill/scripts/check_verbatim_coverage.py`
- Create: `plugins/spec-distill/tests/test_check_verbatim_coverage.sh`
- Create: `plugins/spec-distill/tests/fixtures/state-verbatim-ok.md`, `state-verbatim-multiline.md`, `state-verbatim-placeholder.md`, `state-verbatim-nfkc.md`
- Create: `plugins/spec-distill/tests/fixtures/brief-verbatim-ok.md`, `brief-verbatim-missing-anchor.md`, `brief-verbatim-summarized.md`, `brief-verbatim-multiline.md`, `brief-verbatim-placeholder.md`, `brief-verbatim-nfkc.md`

**Interfaces:**
- Produces: CLI `check_verbatim_coverage.py <payload> <state>` → stdout JSON `{"missing_ids": [...], "not_contained": [...], "advisories": [...]}`; exit `0` 위반없음 / `1` 위반 / `3` 검사불가 / `4` 내부오류 / `64` usage. Task 7의 SKILL이 이 exit code로 분기한다.
- Produces: `normalize(s)` 모듈 함수(N1→N5), `run(payload, state)` 모듈 함수 — T20이 `run`을 교체해 예외 계약을 검증한다.

- [ ] **Step 1: fixture 작성 (테스트 먼저 — 무엇이 red인지 고정)**

`tests/fixtures/state-verbatim-ok.md`:

```markdown
---
session_id: 11111111-1111-1111-1111-111111111111
phase: 1
user_statements:
- id: S1
  source: verbatim
  round: 1
  text: "브리프에 리뷰를 붙이고 싶다"
- id: S2
  source: chosen
  round: 2
  text: "3 에이전트 + codex, 계약별 분리"
---

body
```

`tests/fixtures/brief-verbatim-ok.md`:

```markdown
---
name: verbatim-ok
type: interview-brief
created_at: 2026-07-27
session_id: 11111111-1111-1111-1111-111111111111
source: spec-distill conducting-interview v0.24.0
next_phase: superpowers:brainstorming
audit_file: 2026-07-27-verbatim-ok-interview.audit.md
user_sourced_items:
# confirmed 0건 — 사용자가 전부 잠정으로 판단
  - id: C1
    source: verbatim
    status: provisional
    statement: "brief에 리뷰를 붙인다"
    evidence: S1
---

# Verbatim OK — Interview Brief

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > "브리프에 리뷰를 붙이고 싶다"
- **S2** ☑ 선택 (리뷰 역할 배치):
  > "3 에이전트 + codex, 계약별 분리"

## 7. Next Action

- 없음
```

`brief-verbatim-missing-anchor.md` = 위에서 **`- **S2**` 항목 블록 전체 삭제** (L1 red).
`brief-verbatim-summarized.md` = S2 항목의 인용을 `> "3 에이전트로 분리"` 로 교체 (L2 red — 요약).

`state-verbatim-multiline.md` (N1↔N3 순서 함정):

```markdown
---
user_statements:
- id: S1
  source: verbatim
  round: 1
  text: |
    첫 줄이다
    둘째 줄이다
---
```

`brief-verbatim-multiline.md` §6:

```markdown
## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > "첫 줄이다
  > 둘째 줄이다"
```

`state-verbatim-placeholder.md` = `text: "토큰은 <REDACTED:api-key> 이다"`, `brief-verbatim-placeholder.md` §6 인용 = `> "토큰은 <REDACTED> 이다"` (불일치 + placeholder 관여 → advisory).

`state-verbatim-nfkc.md` = `text: "항목 ① 을 지운다"`, `brief-verbatim-nfkc.md` §6 인용 = `> "항목 1 을 지운다"` (NFC면 red, NFKC면 잘못 통과).

- [ ] **Step 2: 실패하는 테스트 작성**

`tests/test_check_verbatim_coverage.sh`:

```bash
#!/usr/bin/env bash
# Spec B T1·T2·T3·T4·T19·T20·T31(행위) — check_verbatim_coverage.py.
# AC10(L1) · AC11(L2 + P21 강등 + N1–N5 순서 + NFC) · AC12(exit 1/3/4 분리 + 예외 계약) · AC14(부분)
# Run: bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_verbatim_coverage.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
rc_of() { python3 "$SCRIPT" "$1" "$2" >/dev/null 2>&1; echo $?; }
json_of() { python3 "$SCRIPT" "$1" "$2" 2>/dev/null; }

test -f "$SCRIPT" || { note FAIL "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 정상 경로 -------------------------------------------------------------
[[ "$(rc_of "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md")" == "0" ]] \
  && note PASS "정상 fixture → exit 0" || note FAIL "정상 fixture가 exit 0이 아님"

# --- T1 / AC10 : L1 ---------------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && note PASS "T1: S<N> 앵커 누락 → exit 1" || note FAIL "T1: 앵커 누락이 exit 1이 아님 (rc=$rc)"
json_of "$FX/brief-verbatim-missing-anchor.md" "$FX/state-verbatim-ok.md" | grep -q '"missing_ids": \["S2"\]' \
  && note PASS "T1: missing_ids에 S2" || note FAIL "T1: missing_ids가 S2를 담지 않음"

# --- T2 / AC11·AC14 : L2 ----------------------------------------------------
rc="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "1" ]] && note PASS "T2: 요약 치환 → exit 1" || note FAIL "T2: 요약 치환이 exit 1이 아님 (rc=$rc)"
json_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md" | grep -q '"not_contained": \["S2"\]' \
  && note PASS "T2: not_contained에 S2" || note FAIL "T2: not_contained가 S2를 담지 않음"

# --- T2 mutation: 맨앞·중간·맨끝 3곳 절단이 모두 red ------------------------
for cut in head mid tail; do
  tmpb="$(mktemp)" || exit 1
  python3 - "$FX/brief-verbatim-ok.md" "$tmpb" "$cut" <<'PY'
import sys
src, dst, where = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(src, encoding="utf-8").read()
old = '"3 에이전트 + codex, 계약별 분리"'
new = {"head": '"에이전트 + codex, 계약별 분리"',
       "mid":  '"3 에이전트 + 계약별 분리"',
       "tail": '"3 에이전트 + codex, 계약별"'}[where]
assert old in t, "fixture drift: 대상 문장을 찾지 못함"
open(dst, "w", encoding="utf-8").write(t.replace(old, new))
PY
  rc="$(rc_of "$tmpb" "$FX/state-verbatim-ok.md")"
  [[ "$rc" == "1" ]] && note PASS "T2 mutation($cut): 부분 절단 → exit 1" \
                     || note FAIL "T2 mutation($cut): 절단이 통과했다 (rc=$rc)"
  rm -f "$tmpb"
done

# --- T31(행위) N1↔N3 순서: 멀티라인 인용이 통과해야 한다 --------------------
rc="$(rc_of "$FX/brief-verbatim-multiline.md" "$FX/state-verbatim-multiline.md")"
[[ "$rc" == "0" ]] && note PASS "T31: 멀티라인 인용 → exit 0 (N1이 N3보다 먼저)" \
                   || note FAIL "T31: 멀티라인 인용이 red — N3가 N1보다 먼저 적용된 징후 (rc=$rc)"

# --- T31(행위) NFC: 전각/기호는 접히지 않는다 (NFKC면 잘못 통과) ------------
rc="$(rc_of "$FX/brief-verbatim-nfkc.md" "$FX/state-verbatim-nfkc.md")"
[[ "$rc" == "1" ]] && note PASS "T31: ①↔1 불일치 → exit 1 (NFC 유지)" \
                   || note FAIL "T31: ①↔1이 통과했다 — NFKC 징후 (rc=$rc)"

# --- T3 / AC11 : P21 placeholder 강등 --------------------------------------
rc="$(rc_of "$FX/brief-verbatim-placeholder.md" "$FX/state-verbatim-placeholder.md")"
[[ "$rc" == "0" ]] && note PASS "T3: placeholder 관여 → advisory 강등 (exit 0)" \
                   || note FAIL "T3: placeholder 강등이 없다 (rc=$rc)"
json_of "$FX/brief-verbatim-placeholder.md" "$FX/state-verbatim-placeholder.md" | grep -q 'P21 placeholder' \
  && note PASS "T3: advisories에 P21 문구" || note FAIL "T3: advisories가 P21을 언급하지 않음"

# --- T3 mutation: placeholder 토큰 제거 → red 승격 -------------------------
tmps="$(mktemp)" || exit 1
sed 's/<REDACTED:api-key>/plainsecret/' "$FX/state-verbatim-placeholder.md" > "$tmps"
rc="$(rc_of "$FX/brief-verbatim-placeholder.md" "$tmps")"
[[ "$rc" == "1" ]] && note PASS "T3 mutation: 토큰 제거 → advisory가 red로 승격" \
                   || note FAIL "T3 mutation: 토큰 없이도 통과했다 (rc=$rc)"
rm -f "$tmps"

# --- T4 · T19 / AC12 : exit 1 ≠ exit 3 -------------------------------------
rc3="$(rc_of "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md")"
[[ "$rc3" == "3" ]] && note PASS "T4: state 부재 → exit 3" || note FAIL "T4: state 부재가 exit 3이 아님 (rc=$rc3)"
rc1="$(rc_of "$FX/brief-verbatim-summarized.md" "$FX/state-verbatim-ok.md")"
[[ "$rc1" != "$rc3" ]] && note PASS "T19: 위반($rc1) ≠ 검사불가($rc3)" \
                       || note FAIL "T19: 두 실패가 같은 코드다 — 호출자가 차단과 degrade를 구분 못 함"
[[ "$rc1" != "0" && "$rc3" != "0" ]] && note PASS "T19: 둘 다 non-zero" || note FAIL "T19: 실패가 0을 낸다"
python3 "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/nonexistent-state-file.md" 2>/dev/null | grep -q '"advisories"' \
  && note PASS "T4: 검사불가에도 JSON + advisory (조용한 통과 없음)" || note FAIL "T4: 검사불가에 advisory 없음"

# --- 빈 state 파일도 검사불가(3)로 --------------------------------------
tmpe="$(mktemp)" || exit 1; : > "$tmpe"
rc="$(rc_of "$FX/brief-verbatim-ok.md" "$tmpe")"
[[ "$rc" == "3" ]] && note PASS "T4: 빈 state → exit 3" || note FAIL "T4: 빈 state가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpe"

# --- §6 섹션 부재 → 검사불가(3). 구조는 check_brief.py 소관 --------------
tmpn="$(mktemp)" || exit 1
awk '!/^## 6\./{print} /^## 6\./{skip=1} skip&&/^## 7\./{skip=0;print}' "$FX/brief-verbatim-ok.md" > "$tmpn"
rc="$(rc_of "$tmpn" "$FX/state-verbatim-ok.md")"
[[ "$rc" == "3" ]] && note PASS "§6 부재 → exit 3 (위반 아님)" || note FAIL "§6 부재가 exit 3이 아님 (rc=$rc)"
rm -f "$tmpn"

# --- T20 / AC12 : 예외 계약 — 미처리 예외는 4, 절대 1이 아니다 -------------
grep -q "except Exception" "$SCRIPT" \
  && note PASS "T20: main()에 top-level except Exception" || note FAIL "T20: top-level 예외 핸들러 부재"
tmpd="$(mktemp -d)" || exit 1
cat > "$tmpd/inject.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cvc", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
def boom(*a, **k):
    raise RuntimeError("injected")
mod.run = boom
sys.exit(mod.main(["cvc", sys.argv[2], sys.argv[3]]))
PY
python3 "$tmpd/inject.py" "$SCRIPT" "$FX/brief-verbatim-ok.md" "$FX/state-verbatim-ok.md" >/dev/null 2>&1
rc=$?
[[ "$rc" == "4" ]] && note PASS "T20: 주입된 예외 → exit 4 (1이 아님)" \
                   || note FAIL "T20: 주입된 예외가 exit $rc — 예외가 '위반 발견'으로 오분류된다"
rm -rf "$tmpd"

# --- usage -----------------------------------------------------------------
python3 "$SCRIPT" >/dev/null 2>&1; rc=$?
[[ "$rc" != "0" && "$rc" != "1" ]] && note PASS "인자 부족 → non-zero이며 1이 아님 (rc=$rc)" \
                                   || note FAIL "usage 오류가 0 또는 1을 낸다 (rc=$rc)"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 3: 테스트가 실패하는 것을 확인**

Run: `bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh`
Expected: FAIL — `스크립트 부재: .../check_verbatim_coverage.py`, `Total: 1 | Pass: 0 | Fail: 1`.

- [ ] **Step 4: 구현**

`plugins/spec-distill/scripts/check_verbatim_coverage.py`:

```python
#!/usr/bin/env python3
"""spec-distill — payload §6 원문 완전성 검사 (Spec B AC10/AC11/AC12/AC14).

payload(§6 사용자 원문)와 state.local.md(`user_statements` 원장)를 대조한다.
`check_brief.py`와 달리 **두 파일**을 읽는다 — 우회에 양쪽 조작이 필요하므로 이빨이
있다(spec §6.3). 게이트를 분리해 둔 덕에 `check_brief.py`의 "brief 파일만 읽는다"
불변식이 유지된다(AC16 · E12 · E11).

  L1: state `user_statements[].id` ⊆ payload §6 `**S<N>**` 앵커 집합.  위반 → red
  L2: 정규화 후 payload §6 항목 본문이 state `text`를 **포함**하는가.   위반 → red
      P21 placeholder 토큰이 어느 한쪽에 관여하면 advisory로 강등.

정규화 N1–N5 (spec §5.5) — **순서 고정 `N1 → N2 → N3 → N4 → N5`**:
  N1 각 줄 앞 인용 마커 1회 제거 · N2 강조/링크 제거 · N3 연속 whitespace(개행 포함)
  단일화 · N4 양끝 trim · N5 **NFC**(전각/반각을 접지 않는다 — NFKC는 `①→1`·`ﬁ→fi`까지
  접어 실제 왜곡을 통과시킨다).
  **N3보다 N1이 반드시 먼저**다. N3이 개행을 space로 바꾸면 줄 경계가 사라져 둘째 줄
  이후의 `>` 마커를 `^` 앵커로 지울 수 없고 문자열 중간에 남는다(§6 템플릿의 멀티라인
  인용이 정확히 그 형태).

exit 계약:
  0  위반 없음
  1  **위반 발견** (missing_ids 또는 not_contained 비어 있지 않음) — 호출자는 차단
  3  검사 불가 (파일 부재·파싱 실패 — 의도적으로 매핑된 경로) — degrade 후 계속
  4  내부 오류 (미처리 예외) — Python 기본 종료 코드 1을 절대 쓰지 않는다.
     `main()`이 top-level `try/except`로 감싸여 있고, "exit 1은 오직 명시적 위반
     판정에서만 나온다"가 계약이다. 이 계약이 없으면 예상 못 한 버그가 "원문이 빠졌다"로
     오분류돼 **정상 brief를 차단**한다.
  64 usage
  그 외 non-zero는 호출자가 3과 동일하게 취급한다(indeterminate ≠ clean).
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

EXIT_OK = 0
EXIT_VIOLATION = 1
EXIT_INDETERMINATE = 3
EXIT_INTERNAL = 4
EXIT_USAGE = 64

SECTION6_RE = re.compile(r"^##\s*6\.", re.MULTILINE)
NEXT_SECTION_RE = re.compile(r"^##\s", re.MULTILINE)
ITEM_RE = re.compile(r"^\s*[-*]\s+\*\*(S\d+)\*\*(.*)$")
# P21 canonical placeholder 토큰 (conducting-interview SKILL.md의 P21 줄과 같은 집합).
P21_PLACEHOLDER_RE = re.compile(
    r"<(?:REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)"
    r"(?:[:_-][A-Za-z0-9._-]{0,64})?>"
)


class ParseError(Exception):
    """검사 불가(exit 3)로 매핑되는, 의도적으로 처리된 파싱 실패."""


def normalize(s: str) -> str:
    """N1 → N5. 순서를 바꾸면 L2의 pass/fail이 바뀐다(위 docstring 참조)."""
    s = re.sub(r"(?m)^[ \t]*>[ \t]?", "", s)        # N1 (1회 — 중첩 인용은 남긴다)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)  # N2 링크 → 텍스트
    s = re.sub(r"[*`]", "", s)                      # N2 강조 마커
    s = re.sub(r"\s+", " ", s)                      # N3
    s = s.strip()                                   # N4
    return unicodedata.normalize("NFC", s)          # N5 — NFKC 아님


def _frontmatter(text: str) -> str:
    if not text.startswith("---"):
        raise ParseError("frontmatter 부재 (첫 줄이 '---' 아님)")
    end = text.find("\n---", 3)
    if end == -1:
        raise ParseError("frontmatter 종료 구분자 부재")
    return text[3:end]


def _unquote(raw: str) -> str:
    raw = raw.strip()
    m = re.match(r'^"((?:[^"\\]|\\.)*)"', raw)
    if m:
        try:
            return json.loads('"' + m.group(1) + '"')
        except ValueError:
            return m.group(1)
    m = re.match(r"^'((?:[^']|'')*)'", raw)
    if m:
        return m.group(1).replace("''", "'")
    # 인용 없는 스칼라에서만 인라인 주석을 떼어낸다 (인용 안 '#'은 원문의 일부다).
    return re.sub(r"\s+#.*$", "", raw).strip()


def _read_block_scalar(lines: list[str], i: int, key_indent: int) -> tuple[str, int]:
    """`text: |` 다음의 블록 스칼라를 읽는다. 반환 (본문, 다음 인덱스)."""
    body: list[str] = []
    while i < len(lines):
        ln = lines[i]
        if ln.strip() == "":
            body.append("")
            i += 1
            continue
        indent = len(ln) - len(ln.lstrip())
        if indent <= key_indent:
            break
        body.append(ln)
        i += 1
    real = [b for b in body if b.strip()]
    dedent = min((len(b) - len(b.lstrip()) for b in real), default=0)
    return "\n".join(b[dedent:] if len(b) > dedent else "" for b in body).rstrip("\n"), i


def parse_user_statements(fm: str) -> list[dict]:
    """state frontmatter의 `user_statements` 리스트를 파싱한다(서드파티 YAML 금지)."""
    lines = fm.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^user_statements\s*:", ln):
            start = i
            break
    if start is None:
        raise ParseError("state에 user_statements 키가 없다")
    if re.match(r"^user_statements\s*:\s*\[\s*\]\s*$", lines[start]):
        return []
    items: list[dict] = []
    cur: dict | None = None
    i = start + 1
    while i < len(lines):
        ln = lines[i]
        # 블록 종료 = 들여쓰기 없고 '-'로도 시작하지 않는 비어있지 않은 줄(다음 top-level 키).
        if ln.strip() and not ln[0].isspace() and not ln.lstrip().startswith("-"):
            break
        m = re.match(r"^\s*-\s+id\s*:\s*(\S+)", ln)
        if m:
            cur = {"id": m.group(1).strip().rstrip(","), "text": None}
            items.append(cur)
            i += 1
            continue
        m = re.match(r"^(\s*)text\s*:\s*(.*)$", ln)
        if m and cur is not None:
            raw = m.group(2).strip()
            if raw in ("|", "|-", "|+", ">", ">-", ">+"):
                cur["text"], i = _read_block_scalar(lines, i + 1, len(m.group(1)))
                continue
            cur["text"] = _unquote(raw)
            i += 1
            continue
        i += 1
    return items


def parse_payload_section6(text: str) -> dict[str, str]:
    """payload §6의 `**S<N>**` 항목 → 본문 매핑. 본문은 헤더 줄 *다음* 줄들이다
    (헤더 줄은 출처 표기이고 원문이 아니다). 다음 줄이 없으면 헤더의 `:` 뒤를 쓴다."""
    m = SECTION6_RE.search(text)
    if not m:
        raise ParseError("payload에 '## 6.' 섹션이 없다")
    rest = text[m.end():]
    nxt = NEXT_SECTION_RE.search(rest)
    body = rest[: nxt.start()] if nxt else rest
    bodies: dict[str, list[str]] = {}
    heads: dict[str, str] = {}
    order: list[str] = []
    cur = None
    for ln in body.splitlines():
        m2 = ITEM_RE.match(ln)
        if m2:
            cur = m2.group(1)
            if cur in bodies:
                raise ParseError(f"payload §6에 {cur} 앵커가 중복 (구조는 check_brief.py 소관)")
            bodies[cur] = []
            heads[cur] = m2.group(2)
            order.append(cur)
            continue
        if cur is not None:
            bodies[cur].append(ln)
    out: dict[str, str] = {}
    for sid in order:
        joined = "\n".join(bodies[sid]).strip()
        if not joined:
            tail = heads[sid]
            joined = tail.split(":", 1)[1].strip() if ":" in tail else tail.strip()
        out[sid] = joined
    return out


def run(payload_path: Path, state_path: Path) -> tuple[int, dict]:
    result: dict = {"missing_ids": [], "not_contained": [], "advisories": []}
    try:
        payload_text = payload_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        result["advisories"].append(f"검사 불가 — payload unreadable: {exc}")
        return EXIT_INDETERMINATE, result
    try:
        state_text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        result["advisories"].append(f"검사 불가 — state unreadable: {exc}")
        return EXIT_INDETERMINATE, result
    try:
        statements = parse_user_statements(_frontmatter(state_text))
        items = parse_payload_section6(payload_text)
    except ParseError as exc:
        result["advisories"].append(f"검사 불가 — parse failed: {exc}")
        return EXIT_INDETERMINATE, result

    for st in statements:
        sid = st["id"]
        if sid not in items:
            result["missing_ids"].append(sid)
            continue
        raw_state = st["text"]
        if raw_state is None:
            result["advisories"].append(f"{sid}: state에 text 필드 부재 — L2 검사 생략")
            continue
        want = normalize(raw_state)
        have = normalize(items[sid])
        if want and want in have:
            continue
        if P21_PLACEHOLDER_RE.search(raw_state) or P21_PLACEHOLDER_RE.search(items[sid]):
            result["advisories"].append(
                f"{sid}: P21 placeholder 관여 — L2를 advisory로 강등 (원문 미포함)")
            continue
        if not want:
            result["advisories"].append(f"{sid}: state text가 빈 문자열 — L2 검사 생략")
            continue
        result["not_contained"].append(sid)

    if result["missing_ids"] or result["not_contained"]:
        return EXIT_VIOLATION, result
    return EXIT_OK, result


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: check_verbatim_coverage.py <payload> <state.local.md>",
              file=sys.stderr)
        return EXIT_USAGE
    try:
        code, result = run(Path(argv[1]), Path(argv[2]))
    except Exception as exc:  # noqa: BLE001 — 계약: 어떤 예외도 exit 4 (1로 새지 않는다)
        print(json.dumps({"missing_ids": [], "not_contained": [],
                          "advisories": [f"내부 오류: {type(exc).__name__}: {exc}"]},
                         ensure_ascii=False))
        return EXIT_INTERNAL
    print(json.dumps(result, ensure_ascii=False))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh`
Expected: `Fail: 0`. 실패 항목이 있으면 fixture drift(assert가 참조하는 문장)를 먼저 확인한다 — 테스트가 `assert old in t`로 drift를 명시적으로 잡는다.

- [ ] **Step 6: mutation — N1/N5 순서·값이 load-bearing임을 증명**

```bash
S=plugins/spec-distill/scripts/check_verbatim_coverage.py
cp "$S" /tmp/cvc.bak || exit 1

# (a) N1 ↔ N3 순서 교환 → 멀티라인 fixture가 red여야 한다
python3 - "$S" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
n1 = '    s = re.sub(r"(?m)^[ \\t]*>[ \\t]?", "", s)        # N1 (1회 — 중첩 인용은 남긴다)\n'
n3 = '    s = re.sub(r"\\s+", " ", s)                      # N3\n'
assert n1 in t and n3 in t, "mutation 대상 줄을 찾지 못함 (구현 drift)"
t = t.replace(n1, "@@N1@@").replace(n3, n1).replace("@@N1@@", n3)
p.write_text(t, encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh 2>&1 | grep -c "✗ T31: 멀티라인"
cp /tmp/cvc.bak "$S"

# (b) NFC → NFKC → ①↔1 assert가 red여야 한다
sed -i '' 's/unicodedata.normalize("NFC", s)/unicodedata.normalize("NFKC", s)/' "$S"
bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh 2>&1 | grep -c "✗ T31: ①↔1"
cp /tmp/cvc.bak "$S"; rm -f /tmp/cvc.bak

# (c) 복원 확인
bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh | tail -2
```

Expected: (a) `1`, (b) `1`, (c) `Fail: 0`.
**효과 0이면 그 락은 가짜다** — 없애거나 다시 설계하고, 못 잠그는 것은 정직하게 기록한다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/scripts/check_verbatim_coverage.py \
        plugins/spec-distill/tests/test_check_verbatim_coverage.sh \
        plugins/spec-distill/tests/fixtures/state-verbatim-*.md \
        plugins/spec-distill/tests/fixtures/brief-verbatim-*.md
git commit -m "feat(spec-distill): payload §6 원문 완전성 모듈 — L1/L2 + N1–N5 + exit 1/3/4 계약"
```

---

## Task 3: `brief_review_state.py` — state 키 3개 + 전이 경계값 + degradation record

**Files:**
- Create: `plugins/spec-distill/scripts/brief_review_state.py`
- Create: `plugins/spec-distill/tests/test_brief_review_state.py`

**Interfaces:**
- Consumes: 없음(독립 모듈).
- Produces: CLI 6개 서브커맨드 — 전부 stdout JSON, `probe_budget.py`의 fail-closed 관행과 동일.
  - `init <state>` → 부재 키 3개를 default로 추가(idempotent). exit 0.
  - `get <state>` → `{"brief_review_stage":..., "brief_critic_rounds": n, "brief_review_degradations": [...], "migrated": [...], "clamped": bool}`. 키 부재는 in-memory default + `migrated` 열거(쓰지 않는다).
  - `can-redispatch <state>` → **gate**. exit 0 = 재dispatch 허용(`rounds < 2`), exit 1 = escalate 경계 도달(`rounds >= 2`).
  - `bump-critic-round <state>` → +1, **상한 2로 clamp**, persist. `{"brief_critic_rounds": n, "clamped": bool}`.
  - `set-stage <state> <direction|fidelity|readback|done>` → persist.
  - `degrade-append <state> --component X --reason Y --axis Z --status W` → 4필드 record append. enum 위반은 exit 1(fail-closed).
- Task 7의 SKILL이 이 CLI만으로 §6.2 전이 표와 §5.6 record를 집행한다.

**닫힌 enum (spec §5.6 — 이 값 밖은 exit 1):**
- `component`: `critic` `direction_reviewer` `readback` `codex` `verbatim_coverage` `pipeline`
- `affected_axis`: `fidelity` `direction` `readback` `completeness` `all`
- `verification_status`: `skipped` `degraded` `unavailable`  ← `retried`는 **없다**(오염 재시도 메커니즘이 spec round-3에서 삭제됨)

**상한 불변식 (spec §6.2)**: 어떤 전이도 카운터를 2 초과로 만들지 않는다. 따라서 `3` 이상은 **도달 불가능한 손상 상태**이며 `get`/`bump`가 **2로 clamp + advisory**한다(escalate 경로로 수렴 — 덜 진행하는 쪽이 안전).

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_brief_review_state.py`:

```python
#!/usr/bin/env python3
"""Spec B T6·T22(행위) — brief_review_state.py.

AC13(§6.2 전이 표: 카운터 증가 시점 · escalate 경계값 == 2 · 손상값 clamp)
AC15(degradation record 4필드 + 닫힌 enum + append-only)

Run: cd plugins/spec-distill/tests && python3 -m unittest test_brief_review_state -v
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "brief_review_state.py"

FRESH = """---
session_id: 22222222-2222-2222-2222-222222222222
phase: 1
probe_count: 0
---

body
"""


def run(*args):
    proc = subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name) / "state.local.md"
        self.state.write_text(FRESH, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def state_text(self):
        return self.state.read_text(encoding="utf-8")


class TestScriptExists(Base):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"스크립트 부재: {SCRIPT}")


class TestInitAndGet(Base):
    def test_get_before_init_uses_defaults_without_writing(self):
        before = self.state_text()
        rc, out, _ = run("get", str(self.state))
        self.assertEqual(rc, 0)
        d = json.loads(out)
        self.assertEqual(d["brief_critic_rounds"], 0)
        self.assertEqual(d["brief_review_stage"], "direction")
        self.assertEqual(d["brief_review_degradations"], [])
        self.assertIn("brief_critic_rounds", d["migrated"])
        self.assertEqual(before, self.state_text(), "get은 state를 쓰지 않는다")

    def test_init_adds_three_keys_idempotently(self):
        rc, _, _ = run("init", str(self.state))
        self.assertEqual(rc, 0)
        t = self.state_text()
        self.assertIn("brief_review_stage: direction", t)
        self.assertIn("brief_critic_rounds: 0", t)
        self.assertIn("brief_review_degradations: []", t)
        rc, _, _ = run("init", str(self.state))
        self.assertEqual(rc, 0)
        self.assertEqual(t.count("brief_critic_rounds"),
                         self.state_text().count("brief_critic_rounds"),
                         "init 재호출이 키를 중복 추가했다")

    def test_missing_state_fails_closed(self):
        rc, _, _ = run("get", str(Path(self.tmp.name) / "nope.md"))
        self.assertNotEqual(rc, 0, "state 부재가 exit 0을 냈다 (fail-open)")


class TestTransitionTable(Base):
    """spec §6.2 전이 표 — 행 1~6 전부."""

    def setUp(self):
        super().setUp()
        run("init", str(self.state))

    def rounds(self):
        return json.loads(run("get", str(self.state))[1])["brief_critic_rounds"]

    def test_row1_first_review_keeps_counter_zero(self):
        # 최초 리뷰는 *재*라운드가 아니다 — dispatch만으로 카운터가 오르지 않는다.
        self.assertEqual(self.rounds(), 0)

    def test_row3_bump_after_fix_increments_to_one(self):
        rc, out, _ = run("bump-critic-round", str(self.state))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["brief_critic_rounds"], 1)
        self.assertEqual(self.rounds(), 1, "카운터가 state에 persist되지 않았다")

    def test_row5_counter_one_still_allows_redispatch(self):
        run("bump-critic-round", str(self.state))
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 0, "== 1 에서 escalate가 발화했다 (경계값 오류)")

    def test_row6_counter_two_escalates(self):
        run("bump-critic-round", str(self.state))
        run("bump-critic-round", str(self.state))
        self.assertEqual(self.rounds(), 2)
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 1, "== 2 에서 escalate가 발화하지 않았다 (`> 2`를 기다리는 버그)")

    def test_bump_clamps_at_two(self):
        for _ in range(4):
            run("bump-critic-round", str(self.state))
        self.assertEqual(self.rounds(), 2, "카운터가 상한 2를 넘었다")

    def test_corrupt_three_is_clamped_with_advisory_not_silent(self):
        t = self.state_text().replace("brief_critic_rounds: 0", "brief_critic_rounds: 3")
        self.state.write_text(t, encoding="utf-8")
        rc, out, _ = run("get", str(self.state))
        d = json.loads(out)
        self.assertEqual(rc, 0)
        self.assertEqual(d["brief_critic_rounds"], 2, "손상된 3이 clamp되지 않았다")
        self.assertTrue(d["clamped"], "clamp가 조용히 일어났다 (advisory 없음)")
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 1, "손상된 3이 재dispatch를 허용했다")

    def test_stage_transitions(self):
        for stage in ("direction", "fidelity", "readback", "done"):
            rc, _, _ = run("set-stage", str(self.state), stage)
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(run("get", str(self.state))[1])["brief_review_stage"],
                             stage)

    def test_bad_stage_rejected(self):
        rc, _, _ = run("set-stage", str(self.state), "whatever")
        self.assertNotEqual(rc, 0, "닫힌 열거 밖 stage가 통과했다")


class TestDegradationRecord(Base):
    def setUp(self):
        super().setUp()
        run("init", str(self.state))

    def append(self, component="codex", reason="kill switch", axis="all", status="skipped"):
        return run("degrade-append", str(self.state),
                   "--component", component, "--reason", reason,
                   "--axis", axis, "--status", status)

    def test_four_fields_persisted(self):
        rc, _, _ = self.append()
        self.assertEqual(rc, 0)
        t = self.state_text()
        for frag in ("component: codex", "affected_axis: all",
                     "verification_status: skipped"):
            self.assertIn(frag, t, f"record 필드 누락: {frag}")
        self.assertIn("reason:", t)

    def test_append_only_keeps_prior_records(self):
        self.append(component="codex")
        self.append(component="critic", axis="fidelity", status="degraded")
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual([r["component"] for r in recs], ["codex", "critic"],
                         "append가 기존 record를 덮어썼다")

    def test_probe_failure_writes_two_records(self):
        # spec §5.6: zero-tool probe 실패는 critic AND readback 2건이다.
        self.append(component="critic", axis="fidelity", status="degraded",
                    reason="zero-tool 불가 — 격리 미보장")
        self.append(component="readback", axis="readback", status="degraded",
                    reason="zero-tool 불가 — 격리 미보장")
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual({r["component"] for r in recs}, {"critic", "readback"})

    def test_reason_with_colon_and_quotes_roundtrips(self):
        nasty = 'exit 4: RuntimeError("boom") — #1'
        self.append(reason=nasty)
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual(recs[0]["reason"], nasty, "특수문자 reason이 깨졌다")

    def test_closed_enums_fail_closed(self):
        for bad in (("component", "reviewer"), ("axis", "everything"),
                    ("status", "retried")):
            field, value = bad
            kwargs = {"component": "codex", "axis": "all", "status": "skipped"}
            kwargs[field] = value
            rc, _, _ = self.append(**kwargs)
            self.assertNotEqual(rc, 0, f"닫힌 열거 밖 {field}={value} 가 통과했다")

    def test_retried_status_is_not_accepted(self):
        # round-3에서 삭제된 값 — 스키마에 되살아나면 red.
        rc, _, _ = self.append(status="retried")
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_brief_review_state -v`
Expected: `test_script_exists` FAIL(`스크립트 부재`) + 나머지 대량 ERROR(스크립트 없음).

- [ ] **Step 3: 구현**

`plugins/spec-distill/scripts/brief_review_state.py`:

```python
#!/usr/bin/env python3
"""spec-distill — brief 리뷰 파이프라인 상태 (Spec B AC13/AC15).

`reviewing-brief`가 소유하는 state 키 **3개**를 이 모듈이 단독으로 읽고 쓴다
(E11 모듈화 — SKILL이 python heredoc으로 state를 조작하면 테스트할 대상이 없다):

  brief_review_stage: direction | fidelity | readback | done
  brief_critic_rounds: 0              # 이 spec의 유일한 루프 카운터. 상한 2 (AC13)
  brief_review_degradations: []        # §5.6 record, append-only

§6.2 전이 표의 경계값이 여기서 집행된다:
  - 최초 critic 리뷰는 카운터를 **올리지 않는다**(재라운드가 아니다).
  - 카운터는 **수정 후 재dispatch 시점에** +1 된다(리뷰 결과 수신 시점이 아니다).
  - escalate는 `== 2`에서 발화한다(`> 2`를 기다리지 않는다) → `can-redispatch` exit 1.
  - **상한 불변식**: 어떤 전이도 2를 초과시키지 않는다. 따라서 3 이상은 도달 불가능한
    손상 상태이며 **2로 clamp + advisory**한다(escalate로 수렴 — 덜 진행하는 쪽이 안전).

fail-closed 규율은 `probe_budget.py`와 동일하다: state가 unreadable/absent이면
mutating 서브커맨드는 exit 1이고, 카운터 라인을 silent-create하지 않는다(`init`만 생성).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

STAGES = ("direction", "fidelity", "readback", "done")
CRITIC_ROUND_CAP = 2

COMPONENTS = ("critic", "direction_reviewer", "readback", "codex",
              "verbatim_coverage", "pipeline")
AXES = ("fidelity", "direction", "readback", "completeness", "all")
# `retried`는 없다 — 오염 재시도 메커니즘이 spec round-3에서 삭제됐다.
STATUSES = ("skipped", "degraded", "unavailable")

KEY_STAGE = "brief_review_stage"
KEY_ROUNDS = "brief_critic_rounds"
KEY_DEGRADE = "brief_review_degradations"


def _fail(reason: str) -> int:
    print(json.dumps({"ok": False, "reason": reason}, ensure_ascii=False))
    return 1


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    s = str(v)
    if s == "" or any(c in s for c in ":#\"'\n[]{}") or s.strip() != s:
        return json.dumps(s, ensure_ascii=False)
    return s


def _unscalar(v: str):
    v = v.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except ValueError:
            return v[1:-1]
    return v


def _frontmatter_bounds(text: str) -> tuple[int, int]:
    if not text.startswith("---"):
        raise ValueError("frontmatter 부재")
    end = text.find("\n---", 3)
    if end == -1:
        raise ValueError("frontmatter 종료 구분자 부재")
    return 3, end


def parse(text: str) -> dict:
    """세 키를 읽는다. 부재는 default + `migrated` 열거(쓰지 않는다)."""
    out = {"brief_review_stage": "direction", "brief_critic_rounds": 0,
           "brief_review_degradations": [], "migrated": [], "clamped": False}
    m = re.search(rf"^{KEY_STAGE}\s*:\s*(\S+)", text, re.MULTILINE)
    if m:
        val = _unscalar(m.group(1))
        if val not in STAGES:
            raise ValueError(f"{KEY_STAGE} 값이 닫힌 열거 밖: {val!r}")
        out["brief_review_stage"] = val
    else:
        out["migrated"].append(KEY_STAGE)

    m = re.search(rf"^{KEY_ROUNDS}\s*:\s*(\S+)", text, re.MULTILINE)
    if m:
        tok = m.group(1)
        if not tok.isdigit():
            raise ValueError(f"{KEY_ROUNDS} 가 비음수 정수가 아니다: {tok!r}")
        n = int(tok)
        if n > CRITIC_ROUND_CAP:
            out["clamped"] = True
            n = CRITIC_ROUND_CAP
        out["brief_critic_rounds"] = n
    else:
        out["migrated"].append(KEY_ROUNDS)

    out["brief_review_degradations"] = _parse_degradations(text, out)
    return out


def _parse_degradations(text: str, out: dict) -> list:
    m = re.search(rf"^{KEY_DEGRADE}\s*:\s*(.*)$", text, re.MULTILINE)
    if not m:
        out["migrated"].append(KEY_DEGRADE)
        return []
    if m.group(1).strip() in ("[]", "[ ]"):
        return []
    lines = text[m.end():].splitlines()
    recs: list = []
    cur: dict | None = None
    for ln in lines:
        if ln.strip() and not ln[0].isspace():
            break
        item = re.match(r"^\s*-\s+(\w+)\s*:\s*(.*)$", ln)
        if item:
            cur = {item.group(1): _unscalar(item.group(2))}
            recs.append(cur)
            continue
        kv = re.match(r"^\s+(\w+)\s*:\s*(.*)$", ln)
        if kv and cur is not None:
            cur[kv.group(1)] = _unscalar(kv.group(2))
    return recs


def _set_scalar(text: str, key: str, value) -> str:
    pat = re.compile(rf"^({re.escape(key)}\s*:\s*)(\S.*?)(\s*(?:#.*)?)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} 라인 부재 — init을 먼저 실행하라 (silent-create 금지)")
    return text[:m.start()] + f"{m.group(1)}{_yaml_scalar(value)}{m.group(3)}" + text[m.end():]


# --- 서브커맨드 --------------------------------------------------------------
def cmd_init(args) -> int:
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        _, end = _frontmatter_bounds(text)
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    added = []
    inject = ""
    for key, default in ((KEY_STAGE, "direction"), (KEY_ROUNDS, "0"),
                         (KEY_DEGRADE, "[]")):
        if not re.search(rf"^{key}\s*:", text, re.MULTILINE):
            inject += f"{key}: {default}\n"
            added.append(key)
    if inject:
        text = text[:end + 1] + inject + text[end + 1:]
        try:
            path.write_text(text, encoding="utf-8")
        except OSError as exc:
            return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, "added": added}, ensure_ascii=False))
    return 0


def cmd_get(args) -> int:
    try:
        text = _read(Path(args.state))
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        data = parse(text)
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    if data["clamped"]:
        data.setdefault("advisories", []).append(
            f"[spec-distill v0.24.0] {KEY_ROUNDS} 가 도달 불가 값(>{CRITIC_ROUND_CAP})이었다 "
            f"— {CRITIC_ROUND_CAP}으로 clamp하고 escalate 경로로 수렴한다")
    print(json.dumps(data, ensure_ascii=False))
    return 0


def cmd_can_redispatch(args) -> int:
    try:
        data = parse(_read(Path(args.state)))
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    n = data["brief_critic_rounds"]
    ok = n < CRITIC_ROUND_CAP
    print(json.dumps({"ok": ok, KEY_ROUNDS: n, "cap": CRITIC_ROUND_CAP,
                      "escalate": not ok, "clamped": data["clamped"]},
                     ensure_ascii=False))
    return 0 if ok else 1


def cmd_bump(args) -> int:
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        data = parse(text)
        n = min(data["brief_critic_rounds"] + 1, CRITIC_ROUND_CAP)
        text = _set_scalar(text, KEY_ROUNDS, n)
    except ValueError as exc:
        return _fail(f"bump failed: {exc}")
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, KEY_ROUNDS: n,
                      "clamped": data["clamped"] or n == CRITIC_ROUND_CAP,
                      "escalate": n >= CRITIC_ROUND_CAP}, ensure_ascii=False))
    return 0


def cmd_set_stage(args) -> int:
    if args.stage not in STAGES:
        return _fail(f"stage가 닫힌 열거 밖: {args.stage!r} (허용: {', '.join(STAGES)})")
    path = Path(args.state)
    try:
        text = _set_scalar(_read(path), KEY_STAGE, args.stage)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    except ValueError as exc:
        return _fail(f"set-stage failed: {exc}")
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, KEY_STAGE: args.stage}, ensure_ascii=False))
    return 0


def cmd_degrade_append(args) -> int:
    if args.component not in COMPONENTS:
        return _fail(f"component가 닫힌 열거 밖: {args.component!r}")
    if args.axis not in AXES:
        return _fail(f"affected_axis가 닫힌 열거 밖: {args.axis!r}")
    if args.status not in STATUSES:
        return _fail(f"verification_status가 닫힌 열거 밖: {args.status!r}")
    if not args.reason.strip():
        return _fail("reason이 비어 있다 — degrade는 원인 없이 기록되지 않는다")
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    m = re.search(rf"^{KEY_DEGRADE}\s*:\s*(.*)$", text, re.MULTILINE)
    if not m:
        return _fail(f"{KEY_DEGRADE} 라인 부재 — init을 먼저 실행하라")
    record = (f"  - component: {_yaml_scalar(args.component)}\n"
              f"    reason: {_yaml_scalar(args.reason)}\n"
              f"    affected_axis: {_yaml_scalar(args.axis)}\n"
              f"    verification_status: {_yaml_scalar(args.status)}\n")
    if m.group(1).strip() in ("[]", "[ ]"):
        text = text[:m.start()] + f"{KEY_DEGRADE}:\n" + record + text[m.end() + 1:]
    else:
        # 기존 블록의 마지막 항목 뒤에 삽입 (append-only).
        rest = text[m.end() + 1:]
        consumed = 0
        for ln in rest.splitlines(keepends=True):
            if ln.strip() and not ln[0].isspace():
                break
            consumed += len(ln)
        text = text[:m.end() + 1] + rest[:consumed] + record + rest[consumed:]
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, "appended": {"component": args.component,
                                               "affected_axis": args.axis,
                                               "verification_status": args.status}},
                     ensure_ascii=False))
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="brief_review_state.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in (("init", cmd_init), ("get", cmd_get),
                     ("can-redispatch", cmd_can_redispatch),
                     ("bump-critic-round", cmd_bump)):
        sp = sub.add_parser(name)
        sp.add_argument("state")
        sp.set_defaults(fn=fn)
    sp = sub.add_parser("set-stage")
    sp.add_argument("state")
    sp.add_argument("stage")
    sp.set_defaults(fn=cmd_set_stage)
    sp = sub.add_parser("degrade-append")
    sp.add_argument("state")
    sp.add_argument("--component", required=True)
    sp.add_argument("--reason", required=True)
    sp.add_argument("--axis", required=True)
    sp.add_argument("--status", required=True)
    sp.set_defaults(fn=cmd_degrade_append)
    args = p.parse_args(argv[1:])
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_brief_review_state -v`
Expected: 전부 OK.

- [ ] **Step 5: mutation — 경계값과 enum이 load-bearing임을 증명**

```bash
S=plugins/spec-distill/scripts/brief_review_state.py
cp "$S" /tmp/brs.bak || exit 1
cd plugins/spec-distill/tests

# (a) escalate 조건을 `> 2`로 바꿈 → row6 테스트가 red
sed -i '' 's/    ok = n < CRITIC_ROUND_CAP/    ok = n <= CRITIC_ROUND_CAP/' ../scripts/brief_review_state.py
python3 -m unittest test_brief_review_state 2>&1 | grep -c "test_row6_counter_two_escalates"
cp /tmp/brs.bak ../scripts/brief_review_state.py

# (b) 최초 리뷰에서 카운터를 올리는 버그 → row1/row3 계약 위반
sed -i '' 's/(KEY_ROUNDS, "0")/(KEY_ROUNDS, "1")/' ../scripts/brief_review_state.py
python3 -m unittest test_brief_review_state 2>&1 | grep -c "FAILED"
cp /tmp/brs.bak ../scripts/brief_review_state.py

# (c) clamp 제거 → 손상값 3이 조용히 통과
sed -i '' 's/            out\["clamped"\] = True/            pass/' ../scripts/brief_review_state.py
python3 -m unittest test_brief_review_state 2>&1 | grep -c "test_corrupt_three"
cp /tmp/brs.bak ../scripts/brief_review_state.py

# (d) `retried`를 STATUSES에 되살림 → 삭제 락이 red
sed -i '' 's/STATUSES = ("skipped", "degraded", "unavailable")/STATUSES = ("skipped", "degraded", "unavailable", "retried")/' ../scripts/brief_review_state.py
python3 -m unittest test_brief_review_state 2>&1 | grep -c "test_retried_status_is_not_accepted"
cp /tmp/brs.bak ../scripts/brief_review_state.py; rm -f /tmp/brs.bak

python3 -m unittest test_brief_review_state 2>&1 | tail -2
```

Expected: (a)~(d) 각각 `1` 이상, 마지막 `OK`.

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/brief_review_state.py \
        plugins/spec-distill/tests/test_brief_review_state.py
git commit -m "feat(spec-distill): brief 리뷰 state 모듈 — 전이 경계값(==2) clamp + degradation record 4필드"
```

---

## Task 4: `merge_brief_review.py` — 충실도 축 fail-closed 합집합

**Files:**
- Create: `plugins/spec-distill/scripts/merge_brief_review.py`
- Create: `plugins/spec-distill/tests/test_merge_brief_review.py`

**Interfaces:**
- Consumes: `merge_review.py`의 `parse_codex_yaml(path) -> (findings, codex_failed, reason)` 와 `derive_codex_verdict(findings) -> "approved"|"needs_revise"` **재사용**(같은 디렉토리, `sys.path` 삽입 후 import). 두 함수는 `codex_findings_to_yaml.py`가 낳은 같은 스키마를 이미 fail-closed로 다룬다 — YAML 파서를 복제하면 한쪽만 고치는 drift가 생긴다(spec §9의 *"runner를 축별 2개로 복제"* 기각 논리와 같다).
- Produces: CLI `merge_brief_review.py --critic-output <file> [--codex-yaml <file>]` → stdout 키:
  `fidelity_verdict` · `critic_verdict` · `codex_verdict` · `critic_verdict_unrecoverable` · `codex_isolated` · `codex_degraded` · `fidelity_findings` · `advisory[]`. Task 7의 SKILL이 이 stdout을 파싱한다.

**권위 계약 (spec §5.1 — 이 스크립트가 집행한다):**
- **fail-closed 합집합**: critic 또는 codex 중 **어느 쪽이든** Issues를 내면 `fidelity_verdict = needs_revise`. codex는 advisory가 아니라 **binding**이며 단독으로 verdict를 만든다.
- **`codex_isolated: false` 항상 출력** — verdict 입력이 아니라 **저자용 라벨**이다. finding 등급을 낮추는 근거가 아니다.
- **양쪽 판정 불가 → `approved` 금지**. critic verdict 파싱 실패 + codex degraded면 `needs_revise` + advisory로 사람에게 올린다(round-4에서 실측된 verdict 소실의 봉쇄, [[reference_spec_reviewer_status_line_fragility]]).

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_merge_brief_review.py`:

```python
#!/usr/bin/env python3
"""Spec B T5 — merge_brief_review.py.

AC7(fail-closed 합집합 · codex binding) · AC8(`codex_isolated: false` 항상) ·
AC9(codex 부재 시 critic verdict 보존 + `codex_degraded: true`)

Run: cd plugins/spec-distill/tests && python3 -m unittest test_merge_brief_review -v
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "merge_brief_review.py"

CRITIC_APPROVED = """# Brief Fidelity Review

**Status:** Approved

```brief-critic-issues
{"issues": []}
```
"""

CRITIC_ISSUES = """# Brief Fidelity Review

**Status:** Issues Found

```brief-critic-issues
{"issues": [
  {"category": "distortion", "target_section": "#2-제약", "severity": "high",
   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}
]}
```
"""

CRITIC_HEADING_STATUS = CRITIC_ISSUES.replace("**Status:** Issues Found",
                                              "## Status: Issues Found")
CRITIC_NO_STATUS = CRITIC_ISSUES.replace("**Status:** Issues Found", "판정 없음")

CODEX_CLEAN = "findings: []\nmeta:\n  codex_failed: false\n"
CODEX_ISSUE = """findings:
  - agent: codex-reviewer
    category: omission
    target_section: "#2-제약"
    severity: high
    confidence: 8
    summary: S3 원문의 핵심이 §2에서 빠졌다
    proposed_fix: 제약 항목 추가
meta:
  codex_failed: false
"""
CODEX_FAILED = "findings: []\nmeta:\n  codex_failed: true\n  reason: missing_result\n"


def merge(critic_text, codex_text=None, omit_codex=False):
    with tempfile.TemporaryDirectory() as d:
        cpath = Path(d) / "critic.md"
        cpath.write_text(critic_text, encoding="utf-8")
        args = [sys.executable, str(SCRIPT), "--critic-output", str(cpath)]
        if not omit_codex:
            ypath = Path(d) / "codex.yaml"
            ypath.write_text(codex_text if codex_text is not None else CODEX_CLEAN,
                             encoding="utf-8")
            args += ["--codex-yaml", str(ypath)]
        proc = subprocess.run(args, capture_output=True, text=True)
        return proc.returncode, proc.stdout, proc.stderr


def kv(out):
    d = {}
    for line in out.splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            k, _, v = line.partition(":")
            d[k.strip()] = v.strip()
    return d


class TestExists(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"스크립트 부재: {SCRIPT}")


class TestVerdictUnion(unittest.TestCase):
    def test_both_clean_approved(self):
        rc, out, _ = merge(CRITIC_APPROVED, CODEX_CLEAN)
        self.assertEqual(rc, 0)
        self.assertEqual(kv(out)["fidelity_verdict"], "approved")

    def test_critic_only_issues_makes_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_CLEAN)
        self.assertEqual(kv(out)["fidelity_verdict"], "needs_revise")

    def test_codex_only_issues_makes_verdict(self):
        """codex는 binding — 단독으로 verdict를 만든다 (advisory 아님)."""
        _, out, _ = merge(CRITIC_APPROVED, CODEX_ISSUE)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "needs_revise")
        self.assertEqual(d["critic_verdict"], "approved")
        self.assertEqual(d["codex_verdict"], "needs_revise")

    def test_findings_carry_source_labels(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_ISSUE)
        self.assertIn("source: critic", out)
        self.assertIn("source: codex", out)


class TestCodexIsolationLabel(unittest.TestCase):
    def test_codex_isolated_always_false_present(self):
        for critic, codex in ((CRITIC_APPROVED, CODEX_CLEAN),
                              (CRITIC_ISSUES, CODEX_ISSUE),
                              (CRITIC_APPROVED, CODEX_FAILED)):
            _, out, _ = merge(critic, codex)
            self.assertEqual(kv(out)["codex_isolated"], "false",
                             "codex_isolated: false 가 항상 출력되지 않는다")

    def test_codex_isolated_present_when_codex_omitted(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        self.assertEqual(kv(out)["codex_isolated"], "false")


class TestCodexDegrade(unittest.TestCase):
    def test_codex_missing_preserves_critic_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["codex_degraded"], "true")
        self.assertEqual(d["critic_verdict"], "needs_revise")
        self.assertEqual(d["fidelity_verdict"], "needs_revise")

    def test_codex_missing_with_clean_critic_is_approved_but_loud(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "approved")
        self.assertEqual(d["codex_degraded"], "true")
        self.assertIn("codex", out.lower())
        self.assertIn("advisory", out)

    def test_codex_failed_marker_is_degrade_not_clean(self):
        _, out, _ = merge(CRITIC_APPROVED, CODEX_FAILED)
        self.assertEqual(kv(out)["codex_degraded"], "true")


class TestCriticVerdictParsing(unittest.TestCase):
    def test_heading_status_line_is_recovered(self):
        """round-4 실측: `## Status:` 형식이 verdict 소실을 일으켰다."""
        _, out, _ = merge(CRITIC_HEADING_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "false")
        self.assertEqual(d["critic_verdict"], "needs_revise")

    def test_missing_status_is_unrecoverable_and_findings_still_parse(self):
        _, out, _ = merge(CRITIC_NO_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "true")
        self.assertEqual(d["fidelity_verdict"], "needs_revise",
                         "findings가 있는데 approved로 갔다")
        self.assertIn("source: critic", out)

    def test_both_indeterminate_never_approves(self):
        """critic verdict 파싱 실패 + codex degraded → 사람에게. approved 금지."""
        no_findings = CRITIC_NO_STATUS.replace(
            '{"issues": [\n  {"category": "distortion", "target_section": "#2-제약", '
            '"severity": "high",\n   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}\n]}',
            '{"issues": []}')
        _, out, _ = merge(no_findings, omit_codex=True)
        d = kv(out)
        self.assertNotEqual(d["fidelity_verdict"], "approved",
                            "양쪽 판정 불가가 approved로 해소됐다 (fail-open)")
        self.assertIn("advisory", out)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_merge_brief_review -v`
Expected: `test_script_exists` FAIL + 나머지 ERROR.

- [ ] **Step 3: 구현**

`plugins/spec-distill/scripts/merge_brief_review.py`:

```python
#!/usr/bin/env python3
"""spec-distill — 충실도 축 병합 (Spec B AC7/AC8/AC9).

`brief-critic`(격리, Claude)과 codex #2(비격리, 별-모델)의 충실도 findings를 **결정론**으로
합친다. 방향성 축은 병합 대상이 아니다 — verdict가 없고 산출물이 *사용자에게 낼 질문*이라
합칠 대상이 없다(spec §5.2).

권위 계약(spec §5.1):
  - **fail-closed 합집합** — critic 또는 codex 중 어느 쪽이든 Issues를 내면 needs_revise.
    codex는 advisory가 아니라 **binding**이며 단독으로 verdict를 만든다. codex를 advisory로
    두는 것은 리포가 반복 학습한 것(별-모델이 유일 backstop)의 정반대 회귀다.
  - **`codex_isolated: false` 는 항상 출력되며 verdict 입력이 아니다** — 저자가 findings를
    읽을 때 붙는 라벨(프레이밍을 흡수한 리뷰어일 수 있다는 뜻)이고 등급을 낮추는 근거가 아니다.
  - **disagreement는 verdict를 흔들지 않는다** — 합집합이므로 한쪽만 올린 finding도
    그대로 verdict를 만든다.
  - **양쪽 판정 불가 → approved 금지.** critic verdict 파싱 실패 + codex degraded면
    needs_revise + advisory로 사람에게 올린다. (round-4 실측: 리뷰어가 `**Status:**` 대신
    `## Status:`로 내 verdict가 소실됐고, codex가 살아 있어 fail-safe로 흡수됐다.)

이 verdict가 파이프라인을 **차단**하는 것은 zero-tool probe 통과 분기에서만이다. 실패
분기에서는 같은 needs_revise가 advisory로 Step B 게이트에 올라간다(AC2b) — 그 분기 판정은
`reviewing-brief`가 하고 이 스크립트는 하지 않는다.

Usage: merge_brief_review.py --critic-output <file> [--codex-yaml <file>]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    # 같은 producer(codex_findings_to_yaml.py)의 스키마를 이미 fail-closed로 다루는
    # 검증된 파서를 재사용한다. 복제하면 한쪽만 고치는 drift가 생긴다(E11).
    from merge_review import derive_codex_verdict, parse_codex_yaml
    _REUSE_OK = True
except Exception:  # noqa: BLE001 — import 실패는 codex 축 degrade로 흡수
    _REUSE_OK = False

# 줄 앵커 + 인정 토큰. `**Status:**` 와 `## Status:` 둘 다 받는다(round-4 실측 결함).
# 산문 속 "Status:"는 잡지 않는다 — 줄 시작 + 열거된 verdict 토큰이 필수다.
STATUS_RE = re.compile(
    r"^(?:\*\*|#{1,6}\s+)?Status:\**\s*(Approved|Issues Found)\b",
    re.MULTILINE | re.IGNORECASE)
SENTINEL_RE = re.compile(r"```brief-critic-issues[ \t]*\n(.*?)\n?```", re.DOTALL)

CRITIC_CATEGORIES = ("distortion", "omission", "insertion", "provenance_mislabel",
                     "authority_syntax", "evidence_unsupported")


def extract_critic_verdict(text: str) -> str | None:
    m = STATUS_RE.search(text)
    if not m:
        return None
    return "approved" if m.group(1).strip().lower() == "approved" else "needs_revise"


def extract_critic_issues(text: str) -> tuple[list[dict], bool]:
    """반환 (issues, malformed). sentinel 블록 부재/깨짐은 malformed=True."""
    m = SENTINEL_RE.search(text)
    if not m:
        return [], True
    try:
        payload = json.loads(m.group(1))
    except json.JSONDecodeError:
        return [], True
    issues = payload.get("issues")
    if not isinstance(issues, list):
        return [], True
    return [i for i in issues if isinstance(i, dict)], False


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if s == "" or any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s, ensure_ascii=False)
    return s


def emit(result: dict) -> str:
    out: list[str] = []
    for k in ("fidelity_verdict", "critic_verdict", "codex_verdict",
              "critic_verdict_unrecoverable", "codex_isolated", "codex_degraded"):
        out.append(f"{k}: {_yaml_scalar(result[k])}")
    if not result["fidelity_findings"]:
        out.append("fidelity_findings: []")
    else:
        out.append("fidelity_findings:")
        for f in result["fidelity_findings"]:
            out.append(f"  - source: {_yaml_scalar(f.get('source'))}")
            for k in ("category", "target_section", "severity", "confidence",
                      "message", "summary", "proposed_fix"):
                if k in f and f[k] not in (None, ""):
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    if not result["advisory"]:
        out.append("advisory: []")
    else:
        out.append("advisory:")
        for a in result["advisory"]:
            out.append(f"  - {_yaml_scalar(a)}")
    return "\n".join(out) + "\n"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--critic-output", required=True)
    p.add_argument("--codex-yaml", default="")
    args = p.parse_args()

    advisory: list[str] = []

    # --- critic 측 ---------------------------------------------------------
    try:
        with open(args.critic_output, "r", encoding="utf-8", errors="replace") as fh:
            critic_text = fh.read()
    except OSError as exc:
        critic_text = ""
        advisory.append(f"[spec-distill v0.24.0] critic 출력 읽기 실패: {exc}")
    critic_verdict = extract_critic_verdict(critic_text)
    critic_issues, critic_malformed = extract_critic_issues(critic_text)
    if critic_verdict is None:
        advisory.append(
            "[spec-distill v0.24.0] critic verdict 파싱 불가 (Status 줄 부재) — "
            "findings는 sentinel에서 별 경로로 파싱했다. 이 라운드의 충실도 판정은 "
            "codex 단독이거나(codex 가용) 판정 불가다(codex degraded).")
    if critic_malformed:
        advisory.append(
            "[spec-distill v0.24.0] critic sentinel 블록(`brief-critic-issues`) 부재/깨짐 "
            "— issues 0건으로 읽지 않는다(indeterminate ≠ clean).")
    for i in critic_issues:
        cat = str(i.get("category", ""))
        if cat not in CRITIC_CATEGORIES:
            advisory.append(
                f"[spec-distill v0.24.0] critic finding의 category가 닫힌 열거 밖: {cat!r} "
                "— 그대로 verdict에 반영한다(fail-closed).")

    # --- codex 측 ----------------------------------------------------------
    if not _REUSE_OK:
        codex_findings, codex_failed, codex_reason = [], True, "merge_review_import_failed"
        advisory.append("[spec-distill v0.24.0] merge_review.py 재사용 import 실패 — "
                        "codex 축을 degraded로 처리한다.")
    else:
        codex_findings, codex_failed, codex_reason = parse_codex_yaml(args.codex_yaml)
    codex_verdict = None
    if not codex_failed:
        codex_verdict = derive_codex_verdict(codex_findings) if _REUSE_OK else None
    else:
        advisory.append(
            "[spec-distill v0.24.0] codex 충실도 co-review SKIPPED/FAILED "
            f"(reason: {codex_reason or 'unavailable'}) — Claude-only, 모델 다양성 없음 (degraded).")

    # --- fail-closed 합집합 -------------------------------------------------
    findings: list[dict] = []
    for i in critic_issues:
        rec = dict(i)
        rec["source"] = "critic"
        findings.append(rec)
    for f in codex_findings:
        rec = dict(f)
        rec["source"] = "codex"
        findings.append(rec)

    escalates = bool(findings) or critic_malformed
    if critic_verdict == "needs_revise" or codex_verdict == "needs_revise":
        escalates = True
    if critic_verdict is None and codex_failed:
        # 양쪽 판정 불가 → 절대 approved로 해소하지 않는다.
        escalates = True
        advisory.append(
            "[spec-distill v0.24.0] 충실도 판정 불가 (critic verdict unrecoverable AND "
            "codex degraded) — approved로 해소하지 않고 Step B 게이트에서 사람이 판정한다.")
    fidelity_verdict = "needs_revise" if escalates else "approved"

    if (critic_verdict == "approved" and fidelity_verdict == "needs_revise"
            and codex_verdict == "needs_revise"):
        advisory.append(
            "[spec-distill v0.24.0] codex가 critic의 approved를 overturn했다 "
            "(binding — 합집합). codex_isolated: false 라벨을 함께 읽어라.")

    sys.stdout.write(emit({
        "fidelity_verdict": fidelity_verdict,
        "critic_verdict": critic_verdict,
        "codex_verdict": codex_verdict,
        "critic_verdict_unrecoverable": critic_verdict is None,
        "codex_isolated": False,          # AC8 — 항상. verdict 입력이 아니다.
        "codex_degraded": bool(codex_failed),
        "fidelity_findings": findings,
        "advisory": advisory,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_merge_brief_review -v`
Expected: 전부 OK.

- [ ] **Step 5: mutation — 합집합·라벨·degrade가 load-bearing임을 증명**

```bash
S=plugins/spec-distill/scripts/merge_brief_review.py
cp "$S" /tmp/mbr.bak || exit 1
cd plugins/spec-distill/tests

# (a) codex를 advisory로 강등 (codex verdict 무시) → codex-only Issues가 verdict를 못 만듦
sed -i '' 's/    if critic_verdict == "needs_revise" or codex_verdict == "needs_revise":/    if critic_verdict == "needs_revise":/' ../scripts/merge_brief_review.py
sed -i '' 's/    escalates = bool(findings) or critic_malformed/    escalates = bool([f for f in findings if f["source"] == "critic"]) or critic_malformed/' ../scripts/merge_brief_review.py
python3 -m unittest test_merge_brief_review 2>&1 | grep -c "test_codex_only_issues_makes_verdict"
cp /tmp/mbr.bak ../scripts/merge_brief_review.py

# (b) codex_isolated 출력 제거 → AC8 락이 red
sed -i '' 's/"codex_isolated": False,          # AC8 — 항상. verdict 입력이 아니다./"codex_isolated": None,/' ../scripts/merge_brief_review.py
python3 -m unittest test_merge_brief_review 2>&1 | grep -c "codex_isolated"
cp /tmp/mbr.bak ../scripts/merge_brief_review.py

# (c) `## Status:` 수용 제거 → round-4 실측 결함이 되살아나 red
sed -i '' 's/r"^(?:\\*\\*|#{1,6}\\s+)?Status:\\**\\s\*(Approved|Issues Found)\\b",/r"^\\*\\*Status:\\*\\*\\s*(Approved|Issues Found)\\b",/' ../scripts/merge_brief_review.py
python3 -m unittest test_merge_brief_review 2>&1 | grep -c "test_heading_status_line_is_recovered"
cp /tmp/mbr.bak ../scripts/merge_brief_review.py

# (d) 양쪽 판정 불가에서 approved 허용 → fail-open이 red
sed -i '' 's/    if critic_verdict is None and codex_failed:/    if False:/' ../scripts/merge_brief_review.py
python3 -m unittest test_merge_brief_review 2>&1 | grep -c "test_both_indeterminate_never_approves"
cp /tmp/mbr.bak ../scripts/merge_brief_review.py; rm -f /tmp/mbr.bak

python3 -m unittest test_merge_brief_review 2>&1 | tail -2
```

Expected: (a)~(d) 각각 `1` 이상, 마지막 `OK`.
(c)의 `sed` 이스케이프가 까다로우면 대신 손으로 `STATUS_RE`를 `r"^\*\*Status:\*\*\s*(Approved|Issues Found)\b"`로 바꿔 확인하고 복원한다 — **mutation을 건너뛰지 말 것**.

- [ ] **Step 6: 기존 스위트 회귀 확인 (`merge_review.py` import 부작용 없음)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill/tests
python3 -m unittest discover -s . -p "test_*.py" -t . 2>&1 | tail -3
```
Expected: `OK` — 총 테스트 수가 baseline 120에서 신규만큼 증가.

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/scripts/merge_brief_review.py \
        plugins/spec-distill/tests/test_merge_brief_review.py
git commit -m "feat(spec-distill): 충실도 병합 — fail-closed 합집합 + codex binding + 판정불가 fail-closed"
```

---

## Task 5: codex 축별 2회 — 빌더 1 · runner 1 · 체크리스트 데이터 2

**Files:**
- Create: `plugins/spec-distill/scripts/build_brief_codex_prompt.py`
- Create: `plugins/spec-distill/scripts/brief-codex-direction-checklist.md`
- Create: `plugins/spec-distill/scripts/brief-codex-fidelity-checklist.md`
- Create: `plugins/spec-distill/scripts/run_brief_codex_reviewer.sh`
- Create: `plugins/spec-distill/tests/test_brief_codex_axes.sh`

**Interfaces:**
- Produces: `build_brief_codex_prompt.py --axis direction|fidelity <payload>` → stdout 프롬프트. 자기 축 마커를 **포함**하고 타 축 마커를 **미포함**(T11의 판정 기준).
- Produces: `run_brief_codex_reviewer.sh <axis> <payload> <project_dir> <out_yaml>` → 항상 exit 0, 항상 `<out_yaml>`에 `codex_findings_to_yaml.py` 스키마 YAML을 쓴다(기존 `run_spec_codex_reviewer.sh` 계약과 동일).
- Consumes: `codex_findings_to_yaml.py`(무변경) · `detect_codex.sh`(SKILL이 호출).

**모듈 경계 (spec §5.7 — AC20):** **코드 1곳 + 데이터 2곳**. runner를 축별로 복제하면 codex 플래그·샌드박스·에러 처리가 두 곳에 중복돼 한쪽만 고치는 drift가 생긴다. 체크리스트는 축마다 완전히 다른 *내용*이라 데이터로 분리한다(선례: `scripts/ambiguity-blacklist.txt`). `prompts/` 디렉토리는 만들지 않는다 — canonical 트리에 없다.

**`build_spec_codex_prompt.py`를 재사용하지 않는다**: 최신 spec의 AC를 주입하는 성질이 brief 리뷰에서 모델 다양성을 죽이는 오염원이다([[reference_codex_reviewer_spec_ac_injection]]).

**E10 점검:** codex 프롬프트에 **검색 횟수 상한을 넣지 않는다.** 단일 `exec` 호출은 이미 턴으로 경계가 있어 상한은 순수 손실이다(spec §9 기각 항목, 사용자 교정).

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_brief_codex_axes.sh`:

```bash
#!/usr/bin/env bash
# Spec B T11·T16 — codex 축 분리 + 모듈 경계.
# AC6(축별 2회, 한 축만) · AC20(runner 1 · 빌더 1 · 체크리스트 데이터 2 · spec 빌더 미참조)
# Run: bash plugins/spec-distill/tests/test_brief_codex_axes.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
BUILDER="$SD/scripts/build_brief_codex_prompt.py"
RUNNER="$SD/scripts/run_brief_codex_reviewer.sh"
CL_DIR="$SD/scripts/brief-codex-direction-checklist.md"
CL_FID="$SD/scripts/brief-codex-fidelity-checklist.md"
FX="$SD/tests/fixtures"
PAYLOAD="$FX/brief-verbatim-ok.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  test -f "$f" && note PASS "존재: $(basename "$f")" || note FAIL "부재: $f"
done
test -f "$BUILDER" || { echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }

# --- 마커가 body-unique 한 줄로 존재해야 T11이 성립한다 ---------------------
MK_DIR='AXIS-MARKER: brief-direction-axis-only'
MK_FID='AXIS-MARKER: brief-fidelity-axis-only'
[[ "$(grep -cF "$MK_DIR" "$CL_DIR")" == "1" ]] && note PASS "direction 체크리스트에 마커 1회" \
  || note FAIL "direction 마커가 없거나 중복"
[[ "$(grep -cF "$MK_FID" "$CL_FID")" == "1" ]] && note PASS "fidelity 체크리스트에 마커 1회" \
  || note FAIL "fidelity 마커가 없거나 중복"
grep -qF "$MK_FID" "$CL_DIR" && note FAIL "direction 파일에 타 축 마커 오염" || note PASS "direction 파일에 타 축 마커 없음"
grep -qF "$MK_DIR" "$CL_FID" && note FAIL "fidelity 파일에 타 축 마커 오염" || note PASS "fidelity 파일에 타 축 마커 없음"

# --- T11 / AC6 : 축별 출력이 자기 마커만 담는다 (대칭) ----------------------
out_dir="$(python3 "$BUILDER" --axis direction "$PAYLOAD" 2>/dev/null)" || out_dir=""
out_fid="$(python3 "$BUILDER" --axis fidelity "$PAYLOAD" 2>/dev/null)" || out_fid=""
grep -qF "$MK_DIR" <<<"$out_dir" && note PASS "T11: --axis direction 출력이 direction 마커 포함" \
  || note FAIL "T11: direction 출력에 자기 마커 없음"
grep -qF "$MK_FID" <<<"$out_dir" && note FAIL "T11: direction 출력에 fidelity 마커 누출" \
  || note PASS "T11: direction 출력에 타 축 마커 미포함"
grep -qF "$MK_FID" <<<"$out_fid" && note PASS "T11: --axis fidelity 출력이 fidelity 마커 포함" \
  || note FAIL "T11: fidelity 출력에 자기 마커 없음"
grep -qF "$MK_DIR" <<<"$out_fid" && note FAIL "T11: fidelity 출력에 direction 마커 누출" \
  || note PASS "T11: fidelity 출력에 타 축 마커 미포함"

# payload 본문이 실제로 실렸는가 (빈 프롬프트를 통과시키지 않는다)
grep -qF "브리프에 리뷰를 붙이고 싶다" <<<"$out_dir" && note PASS "T11: payload 본문이 프롬프트에 실림" \
  || note FAIL "T11: payload 본문이 프롬프트에 없다"

# 축 인자 검증 (열거 밖은 거부)
python3 "$BUILDER" --axis both "$PAYLOAD" >/dev/null 2>&1 \
  && note FAIL "닫힌 열거 밖 --axis 가 통과" || note PASS "닫힌 열거 밖 --axis 거부"
python3 "$BUILDER" "$PAYLOAD" >/dev/null 2>&1 \
  && note FAIL "--axis 없이 통과" || note PASS "--axis 필수"

# severity 어휘가 merge 경로와 일치해야 한다 (vocab drift가 병합을 깬다)
for sev in block high medium; do
  grep -qF "$sev" <<<"$out_fid" && note PASS "fidelity 프롬프트에 severity '$sev'" \
    || note FAIL "fidelity 프롬프트에 severity '$sev' 없음 (merge vocab drift)"
done

# --- T16 / AC20 : 모듈 경계 ------------------------------------------------
n_runner="$(find "$SD/scripts" -maxdepth 1 -name 'run_brief_codex*' | wc -l | tr -d ' ')"
[[ "$n_runner" == "1" ]] && note PASS "T16: brief codex runner 1개" || note FAIL "T16: runner가 $n_runner 개"
n_builder="$(find "$SD/scripts" -maxdepth 1 -name 'build_brief_codex_prompt*' | wc -l | tr -d ' ')"
[[ "$n_builder" == "1" ]] && note PASS "T16: 빌더 1개" || note FAIL "T16: 빌더가 $n_builder 개"
n_cl="$(find "$SD/scripts" -maxdepth 1 -name 'brief-codex-*-checklist.md' | wc -l | tr -d ' ')"
[[ "$n_cl" == "2" ]] && note PASS "T16: 체크리스트 데이터 2개" || note FAIL "T16: 체크리스트가 $n_cl 개"
test -d "$SD/prompts" && note FAIL "T16: prompts/ 디렉토리 존재 (canonical 트리 위반)" \
  || note PASS "T16: prompts/ 디렉토리 부재"

# 신규 파일 어디에도 spec 빌더 참조가 없다 (AC 주입 오염원)
hits=0
for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  grep -q "build_spec_codex_prompt" "$f" && hits=$((hits+1))
done
[[ "$hits" == "0" ]] && note PASS "T16: build_spec_codex_prompt 미참조" || note FAIL "T16: spec 빌더를 $hits 곳에서 참조"

# runner의 CLAUDE_PLUGIN_ROOT fallback (§11 ⑪ — 기존 스크립트 결함 미반복)
grep -q 'CLAUDE_PLUGIN_ROOT:-' "$RUNNER" \
  && note PASS "T16: runner에 CLAUDE_PLUGIN_ROOT fallback" || note FAIL "T16: fallback 없음 (set -u에서 즉사)"
grep -qE '^set -euo pipefail' "$RUNNER" \
  && note PASS "T16: runner set -euo pipefail" || note FAIL "T16: runner에 set -euo pipefail 없음"

# env 없이도 죽지 않고 항상 YAML을 쓴다 (codex 부재 환경에서 확인)
tmpout="$(mktemp)" || exit 1
( unset CLAUDE_PLUGIN_ROOT; PATH=/usr/bin:/bin bash "$RUNNER" fidelity "$PAYLOAD" "$REPO_ROOT" "$tmpout" >/dev/null 2>&1 )
rc=$?
[[ "$rc" == "0" ]] && note PASS "T16: codex 부재/env 부재에도 exit 0" || note FAIL "T16: runner가 exit $rc"
grep -q '^findings:' "$tmpout" && note PASS "T16: 항상 YAML을 쓴다" || note FAIL "T16: YAML 미작성 (병합이 파일 부재를 본다)"
rm -f "$tmpout"

# 잘못된 축은 runner도 거부한다
tmpout2="$(mktemp)" || exit 1
bash "$RUNNER" both "$PAYLOAD" "$REPO_ROOT" "$tmpout2" >/dev/null 2>&1 \
  && note FAIL "runner가 닫힌 열거 밖 축을 통과" || note PASS "runner가 닫힌 열거 밖 축 거부"
rm -f "$tmpout2"

# E10: 신규 데이터/코드에 단일 호출 상한 표현이 없다
for f in "$CL_DIR" "$CL_FID" "$BUILDER"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$f"; then
    note FAIL "E10: $(basename "$f")에 단일 호출 상한 표현"
  else
    note PASS "E10: $(basename "$f")에 상한 표현 없음"
  fi
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_brief_codex_axes.sh`
Expected: `부재: .../build_brief_codex_prompt.py` 등 FAIL 후 조기 종료.

- [ ] **Step 3: 체크리스트 데이터 2개 작성**

`plugins/spec-distill/scripts/brief-codex-direction-checklist.md`:

```markdown
AXIS-MARKER: brief-direction-axis-only

You are reviewing ONE axis only: **directional soundness** of an interview brief.
You are NOT reviewing whether the summary faithfully reflects the user's words —
a separate reviewer owns that axis. Do not report fidelity issues here.

The brief records what a user decided during a problem-space interview. Your job
is to find *reasons the decided direction may be wrong*, so the orchestrator can
report them and the user can re-decide. You do not change anything.

Answer BOTH questions, each with concrete evidence:

1. **"If this direction is wrong, what is the evidence?"** — search the web and
   read this repository. Cite URLs and `file:line`. Prior art that contradicts the
   direction, a known failure mode, an unstated assumption that the landscape
   disproves, a constraint the user stated that this direction violates.
2. **"Does a better alternative already exist outside?"** — a mature library,
   an established pattern, a shipped tool, a documented approach. If yes, name it,
   link it, and state what it would replace.

You may read the whole repository and search the web freely. There is no cap on
how much you look — depth is the point of this call.

Every finding MUST carry **one question the user has to decide**. A finding without
that question is not actionable — the user, not you and not the orchestrator,
owns the decision (constraint C4).

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "category": "direction",
      "target_section": "<markdown anchor of the brief section, e.g. #2-제약>",
      "severity": "block | high | medium",
      "confidence": <integer 1-10>,
      "summary": "<what you are proposing to overturn, one sentence>",
      "proposed_fix": "<evidence URLs / file:line + THE ONE QUESTION the user must decide>"
    }
  ]
}
```

If you find no reason to overturn anything, emit `{"findings": []}` inside the same
code fence. Do not output any text after the closing fence.
```

`plugins/spec-distill/scripts/brief-codex-fidelity-checklist.md`:

```markdown
AXIS-MARKER: brief-fidelity-axis-only

You are reviewing ONE axis only: **fidelity** of an interview brief — whether the
model's summary distorted, dropped, or invented the user's words. You are NOT
judging whether the user's direction is a good idea, and you are NOT looking for
better alternatives. A separate reviewer owns that axis.

The ground truth is **§6 사용자 원문** (the verbatim user statements). Everything in
§2 제약 and the frontmatter `user_sourced_items` is a model-written summary of §6,
anchored by `evidence: S<N>`. Compare them.

Check EACH of these six categories explicitly and report per-category:

- `distortion` — a §2 statement changes the meaning of its §6 원문.
- `omission` — something load-bearing in §6 is missing from §2.
- `insertion` — a constraint appears in §2 that the user never said.
- `provenance_mislabel` — the 🗣 (user said) / ☑ (user chose) / ✎ (model inferred)
  marker, or `source: verbatim|chosen`, is wrong for that item.
- `authority_syntax` — authority phrasing has crept back in ("확정", "재논쟁 금지",
  "다시 묻지 않는다", `locked_directions`). The brief records direction; it does not
  forbid revisiting it.
- `evidence_unsupported` — `evidence: S<N>` points at a real anchor, but that
  원문 does not actually support the statement. The structural gate only checks that
  the anchor exists; this is the axis a machine cannot close.

Every finding MUST quote the §6 anchor it relies on, so the author can check you.

You may read the whole repository. Note that you can see files the isolated Claude
reviewer cannot — the orchestrator labels your findings `codex_isolated: false` and
weighs that when reading them, and it never uses that label to lower a finding's grade.

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "category": "distortion | omission | insertion | provenance_mislabel | authority_syntax | evidence_unsupported",
      "target_section": "<markdown anchor, e.g. #2-제약>",
      "severity": "block | high | medium",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<what to change + the §6 anchor you relied on>"
    }
  ]
}
```

If you find no issues, emit `{"findings": []}` inside the same code fence. Do not
output any text after the closing fence.
```

- [ ] **Step 4: 빌더 구현**

`plugins/spec-distill/scripts/build_brief_codex_prompt.py`:

```python
#!/usr/bin/env python3
"""build_brief_codex_prompt.py — axis-scoped codex prompt for an interview BRIEF.

spec-distill Spec B §5.7 · AC6 · AC20. codex는 축별로 **2회** 호출된다(E9) —
이 빌더는 **한 축의 체크리스트만** 조립한다. 프롬프트에 두 축을 함께 담으면 codex가
주의 배분을 스스로 결정하고, findings에 축 태그를 요구해야 하고, 병합에서 다시 갈라야
한다. 호출을 나누면 각 호출이 "이것만 봐라"가 되어 깊이가 오른다.

코드는 **1곳**이고 축은 데이터(`brief-codex-<axis>-checklist.md`)다 — 축마다 코드를
복제하면 모듈화가 아니라 중복이다(spec §9).

`build_spec_codex_prompt.py`를 재사용하지 **않는다**: 최신 spec의 AC를 주입하는 성질이
brief 리뷰에서 모델 다양성을 죽이는 오염원이다.

payload는 **파일 경로로만** 받는다(argv/stdin 인라인 금지 — injection 안전). 본문은
read_text 후 str.replace로 치환한다(파싱·eval 없음).

Usage: build_brief_codex_prompt.py --axis direction|fidelity <payload_file>
"""
from __future__ import annotations

import argparse
import pathlib
import sys

AXES = ("direction", "fidelity")

PROMPT_TEMPLATE = """You are an independent reviewer of an interview brief (not code).
Do NOT modify any files; you are in a read-only sandbox.

{{AXIS_CHECKLIST}}

<interview_brief>
{{BRIEF}}
</interview_brief>
"""


def main() -> int:
    p = argparse.ArgumentParser(prog="build_brief_codex_prompt.py")
    p.add_argument("--axis", required=True, choices=AXES)
    p.add_argument("payload")
    try:
        args = p.parse_args()
    except SystemExit:
        return 2

    payload_path = pathlib.Path(args.payload)
    if not payload_path.is_file():
        print(f"payload file not found: {payload_path}", file=sys.stderr)
        return 2

    checklist_path = (pathlib.Path(__file__).resolve().parent
                      / f"brief-codex-{args.axis}-checklist.md")
    if not checklist_path.is_file():
        print(f"checklist not found: {checklist_path}", file=sys.stderr)
        return 2

    checklist = checklist_path.read_text(encoding="utf-8", errors="replace")
    brief = payload_path.read_text(encoding="utf-8", errors="replace")
    out = (PROMPT_TEMPLATE
           .replace("{{AXIS_CHECKLIST}}", checklist)
           .replace("{{BRIEF}}", brief))
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: runner 구현**

`plugins/spec-distill/scripts/run_brief_codex_reviewer.sh`:

```bash
#!/usr/bin/env bash
# run_brief_codex_reviewer.sh — independent codex review of an interview BRIEF.
# spec-distill Spec B §5.7 · AC6 · AC20. codex 호출은 **이 파일 1곳**이고 축은 인자다
# (축별 복제 = 플래그·샌드박스·에러 처리 중복 → 한쪽만 고치는 drift).
#
# Usage:  run_brief_codex_reviewer.sh <axis: direction|fidelity> <payload> <project_dir> <out_yaml>
#
# 계약(기존 run_spec_codex_reviewer.sh와 동일): **항상 exit 0** 이고 **항상 <out_yaml>에
# codex_findings_to_yaml.py 스키마 YAML을 쓴다.** 병합(merge_brief_review.py)이 파일 부재를
# codex_yaml_missing → fail-closed로 읽으므로, 어떤 실패 경로에서도 YAML을 남긴다.
#
# §11 ⑪ 반복 금지: CLAUDE_PLUGIN_ROOT를 fallback 없이 참조하면 set -u 하에서 훅이 env를
# 주지 않는 컨텍스트(스킬 수동 호출)에서 즉사한다. 여기서는 스크립트 위치로 유도한다.

set -euo pipefail

AXIS="${1:-}"
PAYLOAD="${2:-}"
PROJECT_DIR="${3:-}"
OUTPUT_PATH="${4:-}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_brief_codex_reviewer.sh <direction|fidelity> <payload> <project_dir> <out_yaml>" >&2
  exit 2
fi

# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석돼 엉뚱한 위치에 쓴다.
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$PAYLOAD" = /* ]] || PAYLOAD="$PWD/$PAYLOAD"

emit_fallback() {                      # $1 = reason
  {
    echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo "  reason: $1"
  } > "$OUTPUT_PATH"
  exit 0
}

case "$AXIS" in
  direction|fidelity) ;;
  *) echo "axis must be 'direction' or 'fidelity' (got: '$AXIS')" >&2; exit 2 ;;
esac

[[ -f "$PAYLOAD" ]] || emit_fallback payload_missing
[[ -n "$PROJECT_DIR" ]] || emit_fallback missing_project_dir
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# C7: trap 무장 *전에* scratch 대입을 가드한다 (빈 문자열 → `rm -rf ""` footgun).
SCRATCH="$(mktemp -d -t sd-brief-codex-XXXXXX)" || emit_fallback scratch_dir_uncreatable
trap 'rm -rf "$SCRATCH"' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

if ! python3 "$PLUGIN_ROOT/scripts/build_brief_codex_prompt.py" \
       --axis "$AXIS" "$PAYLOAD" > "$PROMPT_FILE"; then
  emit_fallback prompt_build_failed
fi

command -v codex >/dev/null 2>&1 || emit_fallback codex_not_installed

# 웹 검색: 사용자 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)만 끈다. 그 밖에는
# 명시적으로 켠다 — `--search`는 TUI 전용이고 `codex exec` 경로는 이 config다.
# 검색 *횟수* 상한은 두지 않는다 (E10: 단일 exec은 이미 턴으로 경계가 있다).
WEB_ARGS=(-c 'tools.web_search=true')
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=false')
fi

EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
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

# set -e 하에서 이 마지막 파이프라인이 실패하면 fallback YAML 없이 죽는다 — 가드한다.
if ! python3 "$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  emit_fallback yaml_conversion_failed
fi
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
chmod +x plugins/spec-distill/scripts/run_brief_codex_reviewer.sh
bash plugins/spec-distill/tests/test_brief_codex_axes.sh
```
Expected: `Fail: 0`.

- [ ] **Step 7: mutation — 축 분리와 모듈 경계가 load-bearing임을 증명**

```bash
SD=plugins/spec-distill
cp "$SD/scripts/brief-codex-direction-checklist.md" /tmp/cl.bak || exit 1

# (a) 축 오염: direction 파일에 fidelity 마커를 섞음 → T11 red
printf 'AXIS-MARKER: brief-fidelity-axis-only\n' >> "$SD/scripts/brief-codex-direction-checklist.md"
bash "$SD/tests/test_brief_codex_axes.sh" 2>&1 | grep -c "✗ .*타 축 마커"
cp /tmp/cl.bak "$SD/scripts/brief-codex-direction-checklist.md"

# (b) runner 복제 → T16 red
cp "$SD/scripts/run_brief_codex_reviewer.sh" "$SD/scripts/run_brief_codex_reviewer2.sh"
bash "$SD/tests/test_brief_codex_axes.sh" 2>&1 | grep -c "✗ T16: runner가 2 개"
rm -f "$SD/scripts/run_brief_codex_reviewer2.sh"

# (c) spec 빌더 참조 추가 → T16 red
printf '\n# see build_spec_codex_prompt.py\n' >> "$SD/scripts/build_brief_codex_prompt.py"
bash "$SD/tests/test_brief_codex_axes.sh" 2>&1 | grep -c "✗ T16: spec 빌더"
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/scripts/build_brief_codex_prompt.py")
t = p.read_text(encoding="utf-8")
p.write_text(t.replace("\n# see build_spec_codex_prompt.py\n", ""), encoding="utf-8")
PY

# (d) CLAUDE_PLUGIN_ROOT fallback 제거 → T16 red
sed -i '' 's|PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE\[0\]}")/.." \&\& pwd)}"|PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"|' "$SD/scripts/run_brief_codex_reviewer.sh"
bash "$SD/tests/test_brief_codex_axes.sh" 2>&1 | grep -c "✗ T16: fallback 없음"
git checkout -- "$SD/scripts/run_brief_codex_reviewer.sh" 2>/dev/null || true

# (e) 상한 삽입 → E10 락 red
printf '\nAt most 3 web searches.\n최대 3회까지만 검색한다.\n' >> "$SD/scripts/brief-codex-direction-checklist.md"
bash "$SD/tests/test_brief_codex_axes.sh" 2>&1 | grep -c "✗ E10:"
cp /tmp/cl.bak "$SD/scripts/brief-codex-direction-checklist.md"; rm -f /tmp/cl.bak

bash "$SD/tests/test_brief_codex_axes.sh" | tail -2
```

Expected: (a)~(e) 각각 `1` 이상, 마지막 `Fail: 0`.
(d)의 `git checkout --`은 파일이 아직 커밋되지 않았으면 실패한다 — 그 경우 손으로 fallback 줄을 복원한다.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/scripts/build_brief_codex_prompt.py \
        plugins/spec-distill/scripts/run_brief_codex_reviewer.sh \
        plugins/spec-distill/scripts/brief-codex-direction-checklist.md \
        plugins/spec-distill/scripts/brief-codex-fidelity-checklist.md \
        plugins/spec-distill/tests/test_brief_codex_axes.sh
git commit -m "feat(spec-distill): codex 축별 2회 호출 — 코드 1곳 + 축 체크리스트 데이터 2곳"
```

---

## Task 6: 3 에이전트 + inline blob 빌더

**Files:**
- Create: `plugins/spec-distill/scripts/build_brief_inline_blob.py`
- Create: `plugins/spec-distill/agents/brief-critic.md`
- Create: `plugins/spec-distill/agents/brief-direction-reviewer.md`
- Create: `plugins/spec-distill/agents/brief-readback.md`
- Create: `plugins/spec-distill/tests/test_brief_agents.sh`
- Create: `plugins/spec-distill/tests/test_brief_inline_blob.sh`
- Read (분기 입력): `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`

**Interfaces:**
- Consumes: Task 1의 감사 문서 `**분기 판정:**` 리터럴.
- Produces: `build_brief_inline_blob.py <payload>` → stdout blob. exit `0` 깨끗한 redaction / `3` redaction 후에도 본문에 audit 파일명 잔존(위생 미달 → 호출자가 degradation record) / `2` usage·파일 부재.
- Produces: 에이전트 3개. Task 7의 SKILL이 이 이름으로 dispatch한다.

**분기 (spec §5.1.1 — Task 1의 판정을 그대로 따른다):**

| 감사 문서 판정 | critic·readback `tools:` | T7 기대값 |
|---|---|---|
| `ZERO_TOOL_OK` | `tools: []` | `^tools: \[\]$` 존재, bare `tools:` 부재 |
| `ZERO_TOOL_UNAVAILABLE` | `tools: Read` | `^tools: Read$` 존재, `tools: []` 부재 |

`brief-direction-reviewer`는 분기와 무관하게 `tools: Read, Grep, Glob, WebSearch, WebFetch`다.

- [ ] **Step 1: 분기 판정 읽기 (추측 금지)**

```bash
grep -m1 '^\*\*분기 판정:\*\*' docs/audits/2026-07-27-spec-distill-zero-tool-probe.md
```
Expected: `**분기 판정:** ZERO_TOOL_OK` 또는 `... ZERO_TOOL_UNAVAILABLE` 정확히 한 줄.
파일이 없거나 두 리터럴 중 어느 것도 아니면 **Task 1로 되돌아간다** (AC2b: probe 미실행 상태로 구현하지 않는다).

- [ ] **Step 2: 실패하는 테스트 작성 — 에이전트 frontmatter (T7)**

`plugins/spec-distill/tests/test_brief_agents.sh`:

```bash
#!/usr/bin/env bash
# Spec B T7 (+ T21의 Bash 부재 절) — 신규 3 에이전트 도구·모델 표면 락.
# AC4(쓰기·실행·위임 도구 0) · AC5(model: inherit) · AC2b(probe 판정과 tools: 정합)
# Run: bash plugins/spec-distill/tests/test_brief_agents.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
AUDIT="$REPO_ROOT/docs/audits/2026-07-27-spec-distill-zero-tool-probe.md"
ISOLATED=("brief-critic" "brief-readback")
ALL=("brief-critic" "brief-readback" "brief-direction-reviewer")

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

# probe 판정을 읽는다 — 없으면 fail-closed (구현 진행 금지 신호)
test -f "$AUDIT" || { note FAIL "probe 감사 문서 부재: $AUDIT (AC2b — probe 미실행)"; \
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }
VERDICT="$(grep -m1 '^\*\*분기 판정:\*\*' "$AUDIT" | sed 's/^\*\*분기 판정:\*\*[[:space:]]*//' | tr -d '[:space:]')"
case "$VERDICT" in
  ZERO_TOOL_OK|ZERO_TOOL_UNAVAILABLE) note PASS "probe 판정 인식: $VERDICT" ;;
  *) note FAIL "probe 판정을 읽을 수 없다 (값: '$VERDICT')"; \
     echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1 ;;
esac

for a in "${ALL[@]}"; do
  f="$SD/agents/$a.md"
  test -f "$f" || { note FAIL "에이전트 파일 부재: $a.md"; continue; }
  FM="$(fm_of "$f")"

  # AC5 — model: inherit (리터럴 핀 금지, E10 선제 적용)
  grep -qE '^model: inherit$' <<<"$FM" \
    && note PASS "$a: model: inherit" || note FAIL "$a: model이 inherit이 아님 (E10 위반)"

  # AC4 — 쓰기·실행·위임 물리적 부재
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor Task; do
    if grep -qE "^tools:.*(:|,)?[[:space:]]*${t}([[:space:],]|$)" <<<"$FM"; then
      note FAIL "$a: tools:에 $t 가 있다 (Law 2 위반)"
    else
      note PASS "$a: tools:에 $t 없음"
    fi
  done
  grep -qE '^tools:.*mcp__' <<<"$FM" && note FAIL "$a: tools:에 MCP grant" || note PASS "$a: MCP 없음"

  # 죽은 필드 금지 (allowedTools는 비공식 — 조용히 무시된다)
  grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
    && note FAIL "$a: allowedTools/denylist 잔존" || note PASS "$a: allowedTools·disallowedTools 없음"

  # bare `tools:` 금지 — YAML null = "키 미지정"으로 읽혀 조용한 fail-open이 된다
  grep -qE '^tools:[[:space:]]*$' <<<"$FM" \
    && note FAIL "$a: bare 'tools:' (YAML null → 전체 허용 fail-open 위험)" \
    || note PASS "$a: bare 'tools:' 아님"

  grep -qE '^cost_class: (low|medium|high|variable)$' <<<"$FM" \
    && note PASS "$a: cost_class 선언" || note FAIL "$a: cost_class 없음"
done

# probe 판정에 따른 격리 에이전트의 tools: 정합
for a in "${ISOLATED[@]}"; do
  FM="$(fm_of "$SD/agents/$a.md")"
  if [[ "$VERDICT" == "ZERO_TOOL_OK" ]]; then
    grep -qE '^tools: \[\]$' <<<"$FM" \
      && note PASS "$a: tools: [] (probe 통과 분기)" || note FAIL "$a: probe 통과인데 tools: [] 가 아님"
  else
    grep -qE '^tools: Read$' <<<"$FM" \
      && note PASS "$a: tools: Read (probe 실패 분기 — inert)" || note FAIL "$a: probe 실패인데 tools: Read 가 아님"
  fi
done

# 방향성 리뷰어는 분기 무관 — 웹·repo 도구 둘 다, Bash는 없다 (T21)
FM="$(fm_of "$SD/agents/brief-direction-reviewer.md")"
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && note PASS "direction-reviewer: tools 정확 일치" || note FAIL "direction-reviewer: tools 표면이 다름"
for t in WebSearch WebFetch; do
  grep -qE "^tools:.*${t}" <<<"$FM" && note PASS "direction-reviewer: $t 보유 (E10 — 둘 다)" \
    || note FAIL "direction-reviewer: $t 없음 (외부 근거 축 축소)"
done

# 역할 프롬프트가 X / NOT Z를 명시한다 (CLAUDE.md 컴포넌트 격리 규약)
grep -q "NOT" "$SD/agents/brief-critic.md" && note PASS "brief-critic: NOT 책임 명시" || note FAIL "brief-critic: NOT 절 없음"
grep -q "NOT" "$SD/agents/brief-readback.md" && note PASS "brief-readback: NOT 책임 명시" || note FAIL "brief-readback: NOT 절 없음"

# AC3 — readback 프롬프트에 출력 스키마 어휘와 '금지 문구'가 둘 다 없다
RB="$SD/agents/brief-readback.md"
for tok in "category" "severity" "sentinel" "JSON"; do
  grep -qF "$tok" "$RB" && note FAIL "AC3: readback에 스키마 어휘 '$tok'" || note PASS "AC3: readback에 '$tok' 없음"
done
for tok in "audit" "readback 기준" "red-flag"; do
  grep -qiF "$tok" "$RB" && note FAIL "AC3: readback에 '$tok' 언급 (존재 누설)" || note PASS "AC3: readback에 '$tok' 없음"
done
for tok in "G1" "gap 클래스" "미결을 확정으로"; do
  grep -qF "$tok" "$RB" && note FAIL "AC25: readback에 gap 클래스 어휘 '$tok'" || note PASS "AC25: readback에 '$tok' 없음"
done

# critic 프롬프트는 category 6종 전부를 명시한다 (spec §5.3 최소 필수)
CR="$SD/agents/brief-critic.md"
for cat in distortion omission insertion provenance_mislabel authority_syntax evidence_unsupported; do
  grep -qF "$cat" "$CR" && note PASS "critic: category '$cat' 명시" || note FAIL "critic: category '$cat' 누락"
done
# critic 프롬프트에 payload 경로/디렉토리가 실리지 않는다 (AC2의 정적 절)
grep -qF "docs/superpowers/interview/" "$CR" \
  && note FAIL "AC2: critic 프롬프트에 interview 디렉토리 문자열" || note PASS "AC2: critic에 interview 디렉토리 없음"
grep -qF "docs/superpowers/interview/" "$RB" \
  && note FAIL "AC3: readback 프롬프트에 interview 디렉토리 문자열" || note PASS "AC3: readback에 interview 디렉토리 없음"

# E10 — 신규 에이전트에 단일 호출 상한 표현 없음 (T28의 agent 절)
for a in "${ALL[@]}"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$SD/agents/$a.md"; then
    note FAIL "E10: $a에 단일 호출 상한 표현"
  else
    note PASS "E10: $a에 상한 표현 없음"
  fi
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 3: 실패하는 테스트 작성 — inline blob (T24)**

`plugins/spec-distill/tests/test_brief_inline_blob.sh`:

```bash
#!/usr/bin/env bash
# Spec B T24 — inline blob redaction (AC2 · AC3).
# critic·readback 프롬프트에 실리는 blob에서 audit_file·name·created_at 값이 redact되고
# `.audit.md` 문자열이 사라진다. 격리는 도구 표면으로 성립하고 이것은 **위생 조치**다.
# Run: bash plugins/spec-distill/tests/test_brief_inline_blob.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/build_brief_inline_blob.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
PAYLOAD="$FX/brief-verbatim-ok.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$SCRIPT" || { note FAIL "스크립트 부재: $SCRIPT"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

BLOB="$(python3 "$SCRIPT" "$PAYLOAD")"; rc=$?
[[ "$rc" == "0" ]] && note PASS "정상 payload → exit 0" || note FAIL "정상 payload가 exit $rc"

grep -qF '.audit.md' <<<"$BLOB" \
  && note FAIL "T24: blob에 '.audit.md' 잔존 (격리 위생 실패)" || note PASS "T24: blob에 '.audit.md' 부재"
grep -qE '^audit_file: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: audit_file: <redacted>" || note FAIL "T24: audit_file redact 형태가 아님"
grep -qE '^name: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: name: <redacted>" || note FAIL "T24: name redact 안 됨 (재구성 경로)"
grep -qE '^created_at: <redacted>$' <<<"$BLOB" \
  && note PASS "T24: created_at: <redacted>" || note FAIL "T24: created_at redact 안 됨"

# 본문은 온전해야 한다 — redaction이 §6 원문을 건드리면 충실도 판정 자체가 무의미해진다
grep -qF "브리프에 리뷰를 붙이고 싶다" <<<"$BLOB" \
  && note PASS "T24: §6 원문 보존" || note FAIL "T24: §6 원문이 손상됐다"
grep -qF "## 6. 사용자 원문" <<<"$BLOB" \
  && note PASS "T24: §6 헤딩 보존" || note FAIL "T24: §6 헤딩 손실"
grep -qF "Verbatim OK — Interview Brief" <<<"$BLOB" \
  && note PASS "T24: H1 제목 보존 (주제는 남는다 — readback 냉독 지장 없음)" || note FAIL "T24: H1 손실"

# session_id는 redact 대상이 아니다 (세 값만 — 과잉 redaction도 결함)
grep -qE '^session_id: 11111111' <<<"$BLOB" \
  && note PASS "T24: session_id는 그대로 (redact 대상 3값만)" || note FAIL "T24: 과잉 redaction"

# 본문이 audit 파일명을 언급하는 경우: 원문 보존이 이기고 exit 3으로 알린다
tmp="$(mktemp)" || exit 1
python3 - "$PAYLOAD" "$tmp" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
t = t.replace('  > "브리프에 리뷰를 붙이고 싶다"',
              '  > "브리프에 리뷰를 붙이고 싶다 (2026-07-27-x-interview.audit.md 참고)"')
open(dst, "w", encoding="utf-8").write(t)
PY
BLOB2="$(python3 "$SCRIPT" "$tmp")"; rc2=$?
[[ "$rc2" == "3" ]] && note PASS "T24: 본문 잔존 시 exit 3 (호출자가 degrade 기록)" \
                    || note FAIL "T24: 본문 잔존이 exit $rc2 — 조용히 통과했다"
grep -qF "2026-07-27-x-interview.audit.md" <<<"$BLOB2" \
  && note PASS "T24: 본문 원문은 보존된다 (§6 verbatim > 위생)" || note FAIL "T24: 본문 원문을 지웠다"
rm -f "$tmp"

# 파일 부재는 usage 오류
python3 "$SCRIPT" "$FX/nonexistent.md" >/dev/null 2>&1 \
  && note FAIL "부재 파일이 exit 0" || note PASS "부재 파일 거부"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 4: 두 테스트 실패 확인**

```bash
bash plugins/spec-distill/tests/test_brief_agents.sh; echo "---"
bash plugins/spec-distill/tests/test_brief_inline_blob.sh
```
Expected: 각각 파일 부재 FAIL로 조기 종료.

- [ ] **Step 5: inline blob 빌더 구현**

`plugins/spec-distill/scripts/build_brief_inline_blob.py`:

```python
#!/usr/bin/env python3
"""build_brief_inline_blob.py — critic·readback에 inline될 payload blob (Spec B AC2/AC3).

`brief-critic`과 `brief-readback`은 payload를 **경로가 아니라 전문 inline**으로 받는다.
그때 frontmatter의 세 값 — `audit_file` · `name` · `created_at` — 을 `<redacted>`로
바꾼다. 셋을 잃어도 손실이 없다: 충실도 판정은 body §2 ↔ §6 대조이고 frontmatter ↔ body
일치는 게이트의 bijection B가 기계 보장하며, 주제는 본문 H1 제목에 남아 readback의 냉독에도
지장이 없다.

**이것은 보장이 아니라 위생 조치다** (spec §5.1.1 "층 1"). 격리는 도구 표면(zero-tool)으로
성립하거나 성립하지 않는다. redaction은 실패 분기에서 *쉬운 길*을 없애는 것이고, 통과
분기에서는 불필요하지만 프롬프트를 작게 유지하려 유지한다.

`audit_file`을 redact해도 `name` + `created_at`으로 `<date>-<topic>-interview.audit.md`를
**재구성**할 수 있으므로 세 값을 함께 지운다(round-1 리뷰가 적발한 경로).

§6 사용자 원문은 **절대 건드리지 않는다.** 본문이 audit 파일명을 언급하면 원문 보존이
이기고 **exit 3**으로 알린다 — 호출자가 degradation record를 남기고 계속한다.

exit: 0 깨끗한 redaction / 3 본문에 audit 파일명 잔존(위생 미달) / 2 usage·파일 부재
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REDACT_KEYS = ("audit_file", "name", "created_at")
REDACTED = "<redacted>"
AUDIT_SUFFIX_RE = re.compile(r"\.audit\.md\b")


def redact_frontmatter(text: str) -> str:
    """frontmatter 블록 안에서만 세 키의 값을 치환한다(body 동명 문자열은 불변)."""
    if not text.startswith("---"):
        return text
    end = text.find("\n---", 3)
    if end == -1:
        return text
    head, body = text[:end], text[end:]
    for key in REDACT_KEYS:
        head = re.sub(rf"(?m)^({re.escape(key)}\s*:\s*)(.*)$",
                      lambda m: m.group(1) + REDACTED, head)
    return head + body


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: build_brief_inline_blob.py <payload>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.is_file():
        print(f"payload file not found: {path}", file=sys.stderr)
        return 2
    text = path.read_text(encoding="utf-8")
    blob = redact_frontmatter(text)
    sys.stdout.write(blob)
    if AUDIT_SUFFIX_RE.search(blob):
        print("[spec-distill v0.24.0] blob 본문에 audit 파일명이 남아 있다 — §6 원문 보존이 "
              "우선이므로 지우지 않았다. 격리 위생 미달을 degradation record로 남겨라 "
              "(component: critic, verification_status: degraded).", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 6: 에이전트 3개 작성 — `brief-critic.md`**

`tools:` 값은 Step 1의 판정으로 정한다. 아래는 `ZERO_TOOL_OK` 분기다 (`ZERO_TOOL_UNAVAILABLE`이면 `tools: []` → `tools: Read`, 그리고 본문 첫 단락에 *"당신에게 `Read`가 있지만 이 리뷰에는 필요하지 않다 — 필요한 전부가 아래 inline으로 주어졌다"* 한 줄을 더한다. **`audit`이라는 단어는 쓰지 않는다** — 존재를 알리는 것 자체가 힌트다).

```markdown
---
name: brief-critic
description: >
  Use this agent to review an interview brief for FIDELITY — whether the model's
  §2 제약 summary distorted, dropped, or invented what the user actually said in
  §6 사용자 원문. Receives the brief inline; owns no path and no external evidence.
  Emits **Status:** + a `brief-critic-issues` sentinel JSON block. Physically
  blocked from editing files (Law 2 frontmatter scoping).

  <example>Context: reviewing-brief reached the fidelity stage.
  user: "이 brief의 충실도를 봐줘"
  assistant: "I'll dispatch the brief-critic agent with the brief inlined."</example>
tools: []
model: inherit
color: red
cost_class: medium
---

# brief-critic (Law 2 — fidelity axis)

당신은 **충실도** 리뷰어입니다. 당신의 책임은 하나입니다: *모델이 쓴 요약이 사용자가 실제로
한 말을 왜곡·누락·삽입했는가.*

**당신의 책임이 아닌 것:**

- **NOT** 사용자가 잡은 방향이 좋은 생각인지 — 다른 리뷰어가 그 축을 봅니다.
- **NOT** 더 나은 대안이 외부에 있는지 — 외부 근거는 이 축의 오염원입니다.
- **NOT** 파일 수정. 당신은 판정만 냅니다.

## 입력

프롬프트에 brief **전문**이 그대로 실려 옵니다. 그것이 당신이 가진 전부이고, 그것으로 충분
합니다. 다른 파일을 찾지 마세요 — 이 리뷰는 문서 **내부 대조**입니다.

**Ground truth는 `## 6. 사용자 원문`입니다.** `## 2. 제약`과 frontmatter의
`user_sourced_items`는 §6를 모델이 요약한 것이고, 각 항목의 `evidence: S<N>`가 어느 원문에서
나왔는지 가리킵니다. 그 둘을 대조하세요.

## 검사 항목 — 여섯 가지를 각각 명시적으로

| category | 무엇 |
|---|---|
| `distortion` | §2 statement가 §6 원문의 뜻을 바꿨다 |
| `omission` | 원문의 핵심이 §2에서 빠졌다 |
| `insertion` | 사용자가 하지 않은 말이 제약으로 들어왔다 |
| `provenance_mislabel` | 🗣(발화) / ☑(선택) / ✎(모델 추론) 표기 또는 `source: verbatim\|chosen`이 그 항목에 대해 틀렸다 |
| `authority_syntax` | 권위 문법이 되살아났다 — "확정", "재논쟁 금지", "다시 묻지 않는다" 계열. brief는 방향을 기록하고 재검토를 금지하지 않는다 |
| `evidence_unsupported` | `evidence: S<N>`가 실재하는 앵커를 가리키지만 **그 원문이 statement를 뒷받침하지 않는다.** 구조 게이트는 앵커의 *존재*만 봅니다 — 이 축은 기계가 닫을 수 없고 당신만 봅니다 |

여섯 항목을 **하나도 건너뛰지 말고** 각각 점검하세요. 해당 없으면 "해당 없음"으로 명시하세요.

**모든 finding은 근거로 삼은 §6 앵커를 인용해야 합니다** — 저자가 당신을 검증할 수 있어야
합니다.

## 출력 형식

```
**Status:** Approved
```
또는
```
**Status:** Issues Found
```

`**Status:**` **줄 시작**에 그대로 쓰세요(다른 형식은 판정이 소실될 수 있습니다). 그리고
findings를 sentinel 블록으로:

```brief-critic-issues
{"issues": [
  {"category": "distortion", "target_section": "#2-제약", "severity": "high",
   "message": "<한 문장 + 인용한 §6 앵커>"}
]}
```

`severity`는 `block` / `high` / `medium` 중 하나입니다. 발견이 없으면
`{"issues": []}`를 같은 블록에 넣으세요. 블록 밖에 판정을 흘리지 마세요.
```

- [ ] **Step 7: `brief-direction-reviewer.md` 작성**

```markdown
---
name: brief-direction-reviewer
description: >
  Use this agent to review an interview brief for DIRECTIONAL SOUNDNESS — reasons
  the user's decided direction may be wrong, and whether a better alternative
  already exists outside. Reads the repo and searches the web. Reports only; never
  changes direction and never edits files (Law 2 frontmatter scoping). Emits a
  `brief-direction-findings` sentinel YAML where every finding carries one question
  for the user to decide (constraint C4).

  <example>Context: reviewing-brief reached the direction stage.
  user: "이 방향이 틀렸을 가능성을 봐줘"
  assistant: "I'll dispatch the brief-direction-reviewer agent."</example>
tools: Read, Grep, Glob, WebSearch, WebFetch
model: inherit
color: cyan
cost_class: medium
---

# brief-direction-reviewer (Law 2 — direction axis)

당신은 **방향성** 리뷰어입니다. 당신의 책임은 하나입니다: *사용자가 잡은 방향 자체가 틀린
것은 아닌가를 근거와 함께 묻는다.*

**당신의 책임이 아닌 것:**

- **NOT** 충실도(요약이 원문을 왜곡했는가) — 격리된 다른 리뷰어가 그 축을 봅니다.
- **NOT** 문서 수정. 당신은 도구로 쓸 수 없습니다.
- **NOT** 방향 변경. 방향은 사용자가 바꿉니다 — 당신은 **묻습니다**(C4·P17).

## 입력

brief **파일 경로**를 받습니다. 리포 전체를 읽고 웹을 검색하세요 — 이 축은 근거의 **폭**이
본질입니다. 얼마나 찾아야 하는지에 대한 상한은 없습니다.

## 두 질문에 각각 답하세요

1. **"이 방향이 틀렸다면 그 근거는 무엇인가?"** — 웹과 리포에서 찾으세요. URL과 `file:line`을
   인용하세요. 방향을 반박하는 선행 사례, 알려진 실패 양식, landscape가 반증하는 미명시 가정,
   사용자가 스스로 말한 제약과의 충돌.
2. **"더 나은 대안이 외부에 이미 있는가?"** — 성숙한 라이브러리·확립된 패턴·shipped 도구·문서화된
   접근. 있으면 이름·링크·무엇을 대체하는지를 쓰세요.

## 출력 형식

```brief-direction-findings
- id: D1
  overturn: "<무엇을 뒤집자는 것인가 — 한 문장>"
  evidence:
    - "<URL 또는 file:line> — <그것이 무엇을 말하는가>"
  question: "<사용자가 결정할 질문 하나>"
```

**`question`은 필수입니다.** 그것이 없는 finding은 실행 불가능합니다 — 결정은 당신도
orchestrator도 아니라 사용자의 것입니다. verdict 필드는 **없습니다**: 이 축의 산출물은
판정이 아니라 질문입니다.

발견이 없으면 `- id: none` 한 줄과 그렇게 판단한 근거를 남기세요 — 빈 출력은 *"안 찾았다"*와
*"찾았지만 없었다"*를 구분하지 못합니다.

## 웹 예산

orchestrator가 dispatch **전에** 세션 웹 예산을 확인합니다. 예산이 소진된 경우 프롬프트에
*"웹 없이 repo+payload 근거로"* 조건이 실려 옵니다 — 그때만 웹을 쓰지 마세요. 당신은
`Bash`가 없어 예산을 직접 확인할 수 없고(Law 2), 확인은 orchestrator의 책임입니다.
```

- [ ] **Step 8: `brief-readback.md` 작성**

이 파일은 **무엇을 넣지 않는가**가 설계다. `audit`·`red-flag`·`category`·`severity`·`JSON`·`G1`~`G5`·gap 어휘를 넣지 않는다 — 기준을 알면 그 답을 회피한다(E13, Spec A 인터뷰에서 **실측**된 오염). *"…을 읽지 마라"* 류 금지 문구도 넣지 않는다 — 존재를 알리는 것 자체가 힌트다.

```markdown
---
name: brief-readback
description: >
  Use this agent to read an interview brief cold and say back, in plain prose,
  what it understood — what the document is trying to do, what is settled, what is
  still open, and what happens next. A readability measurement, not a review: it is
  given no criteria and no output schema on purpose. Read-only by design (Law 2
  frontmatter scoping).

  <example>Context: reviewing-brief reached the readback stage.
  user: "이 문서가 어떻게 읽히는지 재줘"
  assistant: "I'll dispatch the brief-readback agent for a cold read."</example>
tools: []
model: inherit
color: blue
cost_class: low
---

# brief-readback

당신은 이 문서를 **처음 보는 독자**입니다. 프롬프트에 문서 전문이 실려 옵니다.

읽고, 당신이 이해한 것을 **자유로운 산문으로** 말해주세요. 세 가지만 답하면 됩니다:

1. 이 문서는 **무엇을 하려는** 문서인가?
2. **무엇이 확정**이고 **무엇이 아직 열려** 있는가?
3. **다음에 무엇을** 하는가?

**당신의 책임이 아닌 것:**

- **NOT** 검증 — 맞는지 틀린지 판정하지 마세요.
- **NOT** 의도 확인 — 저자가 무엇을 의도했는지 추측하지 마세요.
- **NOT** 결함 사냥 — 문제를 찾으려 하지 마세요.

당신이 이해한 그대로면 됩니다. 문서가 잘 안 읽히는 부분이 있으면 *"이 부분은 무슨 말인지
모르겠다"* 로 그냥 쓰세요 — 그것이 가장 값진 신호입니다. 형식·표·번호 매김을 만들지 말고
사람에게 설명하듯 쓰세요.
```

- [ ] **Step 9: 두 테스트 통과 확인**

```bash
bash plugins/spec-distill/tests/test_brief_agents.sh | tail -3
bash plugins/spec-distill/tests/test_brief_inline_blob.sh | tail -3
```
Expected: 둘 다 `Fail: 0`.

- [ ] **Step 10: mutation — 도구 표면·모델·redaction이 load-bearing임을 증명**

```bash
SD=plugins/spec-distill
cp "$SD/agents/brief-critic.md" /tmp/bc.bak || exit 1
cp "$SD/scripts/build_brief_inline_blob.py" /tmp/bb.bak || exit 1

# (a) Write 추가 → T7 red
sed -i '' 's/^tools: \[\]$/tools: Write/' "$SD/agents/brief-critic.md"
bash "$SD/tests/test_brief_agents.sh" 2>&1 | grep -c "✗ brief-critic: tools:에 Write"
cp /tmp/bc.bak "$SD/agents/brief-critic.md"

# (b) model: sonnet 으로 핀 → AC5 red (E10 위반)
sed -i '' 's/^model: inherit$/model: sonnet/' "$SD/agents/brief-critic.md"
bash "$SD/tests/test_brief_agents.sh" 2>&1 | grep -c "✗ brief-critic: model이 inherit이 아님"
cp /tmp/bc.bak "$SD/agents/brief-critic.md"

# (c) bare `tools:` → 조용한 fail-open 락 red
sed -i '' 's/^tools: \[\]$/tools:/' "$SD/agents/brief-critic.md"
bash "$SD/tests/test_brief_agents.sh" 2>&1 | grep -c "✗ brief-critic: bare 'tools:'"
cp /tmp/bc.bak "$SD/agents/brief-critic.md"; rm -f /tmp/bc.bak

# (d) redaction 제거 → T24 red
sed -i '' 's/REDACT_KEYS = ("audit_file", "name", "created_at")/REDACT_KEYS = ()/' "$SD/scripts/build_brief_inline_blob.py"
bash "$SD/tests/test_brief_inline_blob.sh" 2>&1 | grep -c "✗ T24"
cp /tmp/bb.bak "$SD/scripts/build_brief_inline_blob.py"

# (e) audit_file만 redact (name/created_at 재구성 경로 잔존) → T24 red
sed -i '' 's/REDACT_KEYS = ("audit_file", "name", "created_at")/REDACT_KEYS = ("audit_file",)/' "$SD/scripts/build_brief_inline_blob.py"
bash "$SD/tests/test_brief_inline_blob.sh" 2>&1 | grep -c "✗ T24: name redact 안 됨"
cp /tmp/bb.bak "$SD/scripts/build_brief_inline_blob.py"; rm -f /tmp/bb.bak

# (f) readback에 스키마 어휘 삽입 → AC3 red
printf '\n출력은 `category` 와 `severity` 를 담은 JSON으로 주세요.\n' >> "$SD/agents/brief-readback.md"
bash "$SD/tests/test_brief_agents.sh" 2>&1 | grep -c "✗ AC3"
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/agents/brief-readback.md")
t = p.read_text(encoding="utf-8")
p.write_text(t.replace("\n출력은 `category` 와 `severity` 를 담은 JSON으로 주세요.\n", ""),
             encoding="utf-8")
PY

bash "$SD/tests/test_brief_agents.sh" | tail -2
bash "$SD/tests/test_brief_inline_blob.sh" | tail -2
```

Expected: (a)~(f) 각각 `1` 이상, 마지막 두 실행 `Fail: 0`.

- [ ] **Step 11: 커밋**

```bash
git add plugins/spec-distill/agents/brief-critic.md \
        plugins/spec-distill/agents/brief-direction-reviewer.md \
        plugins/spec-distill/agents/brief-readback.md \
        plugins/spec-distill/scripts/build_brief_inline_blob.py \
        plugins/spec-distill/tests/test_brief_agents.sh \
        plugins/spec-distill/tests/test_brief_inline_blob.sh
git commit -m "feat(spec-distill): brief 리뷰 3 에이전트 + inline blob redaction (Law 2 fail-closed tools)"
```

---

## Task 7: `reviewing-brief/SKILL.md` — 3단계 파이프라인 오케스트레이션

**Files:**
- Create: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`
- Create: `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`

**Interfaces:**
- Consumes: `check_verbatim_coverage.py`(Task 2) · `brief_review_state.py`(Task 3) · `merge_brief_review.py`(Task 4) · `run_brief_codex_reviewer.sh`(Task 5) · `build_brief_inline_blob.py`·에이전트 3(Task 6) · 기존 `detect_codex.sh`·`web_budget.py`·`hooks/state_path.py`.
- Produces: `conducting-interview` Step A.5가 진입할 skill 이름 `reviewing-brief`, 그리고 Step B로 넘길 산출물 4종(확정 후보 / 방향성 C4 항목 / readback 요약 전문 + gap / 모든 degrade record).

**섹션 헤더가 검증 계약이다.** T8·T9·T28·T30은 **awk 섹션 윈도우**로 걸린다 — 헤더 문구를 바꾸면 락이 스코프를 잃는다([[feedback_grep_lock_header_satisfiable]]). 아래 헤더는 리터럴로 유지한다:

| 헤더 | 윈도우가 보장하는 것 |
|---|---|
| `### 2-a. critic dispatch 블록` | 그 안에 `docs/superpowers/interview/` **부재**(T8) |
| `### 2-c. 충실도 루프 전이` | 횟수 상한 표현이 **오직 여기에만**(T28) |
| `### 3-a. readback dispatch 블록` | 스키마 어휘·G 클래스 어휘 **부재**(T9·T30) |

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_reviewing_brief_skill.sh`:

```bash
#!/usr/bin/env bash
# Spec B T8·T9·T14·T17·T21·T22·T23·T25·T28·T30 — reviewing-brief SKILL 계약 락.
# AC2(critic 경로 미제공) · AC3(readback 무스키마) · AC2b(probe 이진 분기) · AC7b(기각 금지)
# AC13(전이 표) · AC15(degradation record) · AC18(kill switch) · AC21(cost_class high + 게이트)
# AC22b(단일 호출 상한 0) · AC24(웹 예산) · AC25(G1–G5)
# 모든 블록 스코프 assert는 awk 윈도우로 걸린다 — 헤더 만족(header-satisfiable) 방지.
# Run: bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/reviewing-brief/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
# $1 = 시작 헤더 정규식 → 다음 '^### ' 직전까지
window() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^### / {exit} inw' "$SKILL"; }
has() { grep -qF -- "$2" <<<"$1"; }

test -f "$SKILL" || { note FAIL "SKILL 부재: $SKILL"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SKILL")"

# --- T17 / AC21 : cost_class high + 진입 승인 게이트 (조건 없음) --------------
grep -qE '^cost_class: high$' <<<"$FM" \
  && note PASS "T17: cost_class: high" || note FAIL "T17: cost_class가 high가 아님"
grep -qF 'AskUserQuestion' "$SKILL" \
  && note PASS "T17: 승인 게이트(AskUserQuestion) 서술 존재" || note FAIL "T17: 승인 게이트 서술 부재"
grep -qE '진입 (시 )?1회|진입 승인' "$SKILL" \
  && note PASS "T17: 진입 1회 승인 게이트 명시" || note FAIL "T17: 진입 승인 게이트 명시 부재"
# 외부 문서의 미래 결론에 조건부로 걸지 않는다 (spec §5.7 무조건 확정)
grep -qE 'sweep(의|이)? (결론|판단)에 따라|sweep 이후에 (결정|재검토)' "$SKILL" \
  && note FAIL "T17: 승인 게이트를 외부 문서 결론에 조건부로 걸었다" \
  || note PASS "T17: 승인 게이트가 무조건 확정"

# --- T14 / AC18 : 신규 kill switch --------------------------------------------
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' "$SKILL" \
  && note PASS "T14: 신규 kill switch 실재" || note FAIL "T14: DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW 부재"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL=1' "$SKILL" \
  && note PASS "T14: 전역 kill switch 존중" || note FAIL "T14: 전역 kill switch 부재"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$SKILL" \
  && note PASS "T14: codex kill switch 존중" || note FAIL "T14: codex kill switch 부재"
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "$SKILL" \
  && note PASS "T14: 웹 kill switch 존중" || note FAIL "T14: 웹 kill switch 부재"

# --- T8 / AC2 : critic dispatch 블록 안에 payload 경로가 없다 ----------------
W2A="$(window '^### 2-a\.')"
[[ -n "$W2A" ]] && note PASS "T8: '### 2-a. critic dispatch 블록' 윈도우 존재" \
               || note FAIL "T8: 2-a 윈도우가 비었다 (헤더 drift — 락이 스코프를 잃었다)"
has "$W2A" 'docs/superpowers/interview/' \
  && note FAIL "T8: critic dispatch 블록에 interview 디렉토리 경로" \
  || note PASS "T8: critic dispatch 블록에 payload 경로 부재"
has "$W2A" 'build_brief_inline_blob.py' \
  && note PASS "T8: critic 블록이 inline blob 빌더를 쓴다" || note FAIL "T8: blob 빌더 호출 부재"
has "$W2A" 'brief-critic' \
  && note PASS "T8: critic 블록이 brief-critic을 dispatch" || note FAIL "T8: brief-critic dispatch 부재"

# --- T9 / AC3 : readback dispatch 블록에 스키마 어휘가 없다 ------------------
W3A="$(window '^### 3-a\.')"
[[ -n "$W3A" ]] && note PASS "T9: '### 3-a. readback dispatch 블록' 윈도우 존재" \
               || note FAIL "T9: 3-a 윈도우가 비었다 (헤더 drift)"
for tok in 'category' 'severity' 'sentinel' 'JSON'; do
  has "$W3A" "$tok" && note FAIL "T9: readback 블록에 스키마 어휘 '$tok'" \
                    || note PASS "T9: readback 블록에 '$tok' 부재"
done
# AC3 — "audit을 읽지 마라" 류 금지 문구도 없다(존재 누설)
has "$W3A" 'audit' && note FAIL "AC3: readback 블록이 audit을 언급 (존재 누설)" \
                   || note PASS "AC3: readback 블록에 audit 언급 부재"

# --- T30 / AC25 : G1–G5는 SKILL에 있고 readback 블록에는 없다 ---------------
for g in G1 G2 G3 G4 G5; do
  grep -qF "$g" "$SKILL" && note PASS "T30: gap 클래스 $g 존재" || note FAIL "T30: gap 클래스 $g 누락"
done
grep -qF '전부 0건' "$SKILL" && note PASS "T30: '전부 0건이면 pass' 성공 조건" || note FAIL "T30: 성공 조건 부재"
grep -qE '세 조각|3조각' "$SKILL" && note PASS "T30: 3조각 보고 형식" || note FAIL "T30: 3조각 보고 형식 부재"
for tok in 'G1' 'gap 클래스' '미결을 확정으로'; do
  has "$W3A" "$tok" && note FAIL "T30: readback 블록에 gap 어휘 '$tok' (E13 — 기준을 알면 회피)" \
                    || note PASS "T30: readback 블록에 '$tok' 부재"
done

# --- T23 / AC2b · AC7 : probe 이진 분기 -------------------------------------
for tok in 'P1' 'P2' 'P3' 'canary' 'census' 'ZERO_TOOL_OK' 'ZERO_TOOL_UNAVAILABLE'; do
  grep -qF "$tok" "$SKILL" && note PASS "T23: probe 요소 '$tok' 열거" || note FAIL "T23: probe 요소 '$tok' 누락"
done
grep -qE 'probe (미실행|를 실행하지 않은).*진행(하지 않|을 금지)' "$SKILL" \
  && note PASS "T23: probe 미실행 시 진행 금지 서술" || note FAIL "T23: probe 미실행 금지 서술 부재"
WFAIL="$(awk '/^#### probe 실패 분기/{inw=1; next} inw && /^#{1,4} /{exit} inw' "$SKILL")"
[[ -n "$WFAIL" ]] && note PASS "T23: '#### probe 실패 분기' 윈도우 존재" || note FAIL "T23: 실패 분기 윈도우 부재"
has "$WFAIL" 'hard gate' && note FAIL "T23: 실패 분기에 'hard gate' 문구 (주장 > 보장)" \
                         || note PASS "T23: 실패 분기에 'hard gate' 문구 부재"
has "$WFAIL" 'advisory' && note PASS "T23: 실패 분기가 advisory 강등" || note FAIL "T23: advisory 강등 부재"
has "$WFAIL" 'D2' && note PASS "T23: 실패 분기가 D2 미충족 보고" || note FAIL "T23: D2 미충족 보고 부재"
has "$WFAIL" 'component: critic' && note PASS "T23: 실패 분기 record — critic" || note FAIL "T23: critic record 부재"
has "$WFAIL" 'component: readback' && note PASS "T23: 실패 분기 record — readback (2건)" \
                                  || note FAIL "T23: readback record 부재 (냉독 신뢰도 하향 신호 없음)"
WOK="$(awk '/^#### probe 통과 분기/{inw=1; next} inw && /^#{1,4} /{exit} inw' "$SKILL")"
has "$WOK" 'hard gate' && note PASS "T23: 통과 분기가 hard gate" || note FAIL "T23: 통과 분기에 hard gate 부재"

# --- T22 / AC15 : degradation record ----------------------------------------
grep -qF 'brief_review_degradations' "$SKILL" \
  && note PASS "T22: state 키 brief_review_degradations" || note FAIL "T22: state 키 부재"
for f in 'component' 'reason' 'affected_axis' 'verification_status'; do
  grep -qF "$f" "$SKILL" && note PASS "T22: record 필드 '$f'" || note FAIL "T22: record 필드 '$f' 누락"
done
grep -qE 'question 텍스트' "$SKILL" \
  && note PASS "T22: Step B question 텍스트 렌더 (옵션 description 아님)" || note FAIL "T22: question 텍스트 렌더 서술 부재"
grep -qE '빈 배열|비면' "$SKILL" \
  && note PASS "T22: 빈 배열도 'degrade 없음'으로 명시" || note FAIL "T22: 빈 배열 명시 부재"
grep -qF 'retried' "$SKILL" \
  && note FAIL "T22: 삭제된 'retried' 값 재도입" || note PASS "T22: 'retried' 부재"
# §5.6 실패표의 모든 행이 record를 규정한다 — escalate 행 포함
grep -qE '상한 2 초과.*record|record.*상한 2 초과|재리뷰 상한 2 초과' "$SKILL" \
  && note PASS "T22: 재리뷰 상한 초과 escalate 행도 record 규정" || note FAIL "T22: escalate 행 record 누락"

# --- T21 / AC24 : 웹 예산 (dispatch 단위) -----------------------------------
grep -qF 'web_budget.py' "$SKILL" && note PASS "T21: web_budget.py 참조" || note FAIL "T21: web_budget.py 부재"
grep -qE 'dispatch (전|이전).*check|check.*dispatch (전|이전)' "$SKILL" \
  && note PASS "T21: dispatch 전 check 서술" || note FAIL "T21: dispatch 전 check 서술 부재"
grep -qE 'dispatch (후|이후).*increment|increment.*1회' "$SKILL" \
  && note PASS "T21: dispatch 후 increment 1회 서술" || note FAIL "T21: dispatch 후 increment 서술 부재"
grep -qF 'dispatch 단위' "$SKILL" \
  && note PASS "T21: 계측 단위가 dispatch임을 명시" || note FAIL "T21: 계측 단위 명시 부재 (호출 단위 오독)"
grep -qE 'Bash.*(없|부재)' "$SKILL" \
  && note PASS "T21: 리뷰어에 Bash 부재 → orchestrator 책임 명시" || note FAIL "T21: Bash 부재 근거 서술 없음"

# --- T25 / AC7b : finding 임의 기각 금지 -----------------------------------
grep -qE '임의(로)? 기각(하지|할 수) (못|없)' "$SKILL" \
  && note PASS "T25: 저자 임의 기각 금지" || note FAIL "T25: 기각 금지 서술 부재"
grep -qE '미반영 findings.*(이유|근거).*Step B|Step B.*미반영 findings' "$SKILL" \
  && note PASS "T25: 미반영 findings를 이유와 함께 Step B로" || note FAIL "T25: 미반영 findings 이월 서술 부재"

# --- T28 / AC22b : 횟수 상한은 루프 문맥 하나에만 ----------------------------
CAP_RE='최대 [0-9]+회|[0-9]+회까지|max_[a-zA-Z_]+ *= *[0-9]'
total="$(grep -cE "$CAP_RE" "$SKILL" || true)"
W2C="$(window '^### 2-c\.')"
inloop="$(grep -cE "$CAP_RE" <<<"$W2C" || true)"
[[ -n "$W2C" ]] && note PASS "T28: '### 2-c. 충실도 루프 전이' 윈도우 존재" || note FAIL "T28: 2-c 윈도우 부재"
[[ "$total" -ge 1 ]] && note PASS "T28: 상한 표현이 실재 ($total)" || note FAIL "T28: 상한 표현이 0 — 루프 가드가 없다"
[[ "$total" == "$inloop" ]] && note PASS "T28: 상한 표현이 루프 문맥에만 ($inloop/$total)" \
  || note FAIL "T28: 루프 문맥 밖 상한 표현 $((total-inloop))건 (E10 위반)"

# --- AC13 : 전이 표 경계값 --------------------------------------------------
has "$W2C" 'brief_critic_rounds' && note PASS "AC13: 카운터 이름" || note FAIL "AC13: 카운터 이름 부재"
grep -qE '== ?2' <<<"$W2C" && note PASS "AC13: escalate 경계값 == 2" || note FAIL "AC13: 경계값 명시 부재"
has "$W2C" 'can-redispatch' && note PASS "AC13: can-redispatch 게이트 사용" || note FAIL "AC13: 게이트 호출 부재"
grep -qE '최초 리뷰.*0 유지|0 유지.*최초' <<<"$W2C" \
  && note PASS "AC13: 최초 리뷰는 카운터 0 유지" || note FAIL "AC13: 최초 리뷰 규칙 부재"
grep -qE 'fresh critic.*(필수|1회)' "$SKILL" \
  && note PASS "AC13/E8: 수정 후 fresh critic 재리뷰 1회 필수" || note FAIL "AC13/E8: fresh 재리뷰 필수 서술 부재"

# --- AC1 : 파이프라인 순서 + 진입 첫 액션 ------------------------------------
grep -qF 'check_verbatim_coverage.py' "$SKILL" \
  && note PASS "AC1: 완전성 검사 호출" || note FAIL "AC1: check_verbatim_coverage.py 부재"
grep -qE '첫 액션' "$SKILL" && note PASS "AC1: 진입 첫 액션 명시" || note FAIL "AC1: 첫 액션 명시 부재"
for code in 'exit 1' 'exit 3' 'exit 4'; do
  grep -qF "$code" "$SKILL" && note PASS "AC1/AC12: 호출자가 $code 분기" || note FAIL "AC1/AC12: $code 분기 부재"
done
# 순서: 방향성 → 충실도 → 냉독 (헤더 순서로 확인)
ORDER="$(grep -nE '^## [123]단계' "$SKILL" | sed 's/:.*//' | tr '\n' ' ')"
o1="$(echo "$ORDER" | awk '{print $1}')"; o2="$(echo "$ORDER" | awk '{print $2}')"; o3="$(echo "$ORDER" | awk '{print $3}')"
if [[ -n "${o3:-}" ]] && [[ "$o1" -lt "$o2" ]] && [[ "$o2" -lt "$o3" ]]; then
  note PASS "AC1: 1단계(방향성) → 2단계(충실도) → 3단계(냉독) 순서"
else
  note FAIL "AC1: 단계 헤더가 3개가 아니거나 순서가 어긋남 ($ORDER)"
fi
grep -qE '^## 1단계 — 방향성' "$SKILL" && note PASS "AC1: 1단계가 방향성" || note FAIL "AC1: 1단계 헤더가 방향성이 아님"
grep -qE '^## 2단계 — 충실도' "$SKILL" && note PASS "AC1: 2단계가 충실도" || note FAIL "AC1: 2단계 헤더가 충실도가 아님"
grep -qE '^## 3단계 — 냉독' "$SKILL" && note PASS "AC1: 3단계가 냉독" || note FAIL "AC1: 3단계 헤더가 냉독이 아님"

# --- 방향성은 병합하지 않는다 (verdict 없음) --------------------------------
grep -qE '방향성(은|을)? 병합하지 않' "$SKILL" \
  && note PASS "AC6: 방향성 미병합 명시" || note FAIL "AC6: 방향성 미병합 명시 부재"
grep -qF 'merge_brief_review.py' "$SKILL" \
  && note PASS "AC7: 충실도 병합 스크립트 호출" || note FAIL "AC7: merge_brief_review.py 부재"

# --- codex 축별 2회 --------------------------------------------------------
n_codex="$(grep -cE 'run_brief_codex_reviewer\.sh (direction|fidelity)' "$SKILL" || true)"
[[ "$n_codex" -ge 2 ]] && note PASS "AC6: codex 축별 2회 호출 서술 ($n_codex)" || note FAIL "AC6: codex 호출이 $n_codex 건"
grep -qF 'detect_codex.sh' "$SKILL" && note PASS "AC9: detect_codex.sh 선행 확인" || note FAIL "AC9: detect_codex.sh 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh`
Expected: `SKILL 부재` FAIL 후 조기 종료.

- [ ] **Step 3: SKILL 구현 — frontmatter + 진입**

`plugins/spec-distill/skills/reviewing-brief/SKILL.md` (아래 Step 3–8을 **한 파일로** 이어서 씁니다):

```markdown
---
name: reviewing-brief
description: >
  Use this skill to run the Law 2 separated review of an interview brief produced by
  conducting-interview. Three stages in order — directional soundness (Claude +
  codex, reports only), fidelity (isolated critic + codex, fail-closed union), cold
  readback (naive re-read) — plus a deterministic §6 원문 completeness check against
  the state ledger. Hands four artifacts to the interview's Step B proceed gate.
cost_class: high
user-invocable: false
---

# Reviewing Brief (interview 종료 단계)

당신은 `conducting-interview` Step A가 게이트를 통과시킨 brief(payload)에 **분리 리뷰**를
붙이는 중입니다. 축은 둘(충실도·방향성), 담당은 셋 + 별-모델 codex 2회입니다.

**당신(orchestrator)의 책임**: dispatch · 결정론 스크립트 호출 · 결과 표면화 · Step B로 전달.
**당신의 책임이 아닌 것**: finding을 임의로 기각하는 것 · 방향을 바꾸는 것 · 리뷰어 대신 판정하는 것.

## kill switch (먼저 확인)

- `DEVBREW_DISABLE_SPEC_DISTILL=1` → 즉시 abort, state 보존. 이 skill에 진입하지 않습니다.
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (v0.24.0 신규) → **파이프라인 전체 skip.**
  `component: pipeline` / `affected_axis: all` / `verification_status: skipped` record를 남기고
  loud advisory 후 Step B로 직행합니다. 조용히 건너뛰지 않습니다:

  > `[spec-distill v0.24.0] brief 리뷰 파이프라인 SKIPPED (DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1) — 충실도·방향성·냉독 전부 미검증. Step B 게이트에서 확인하세요.`

- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` → codex 2회 호출만 skip(Claude 리뷰는 정상).
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 양쪽 웹 없이 진행 + record.

## 진입 승인 게이트 (`cost_class: high`)

이 skill은 에이전트 3 + codex 2 = 모델 호출 5회를 씁니다. CLAUDE.md 규약대로 **진입 시 1회**
지출 승인을 받습니다. 이 게이트는 **무조건**이며 외부 문서의 미래 결론에 의존하지 않습니다.

```javascript
AskUserQuestion({
  questions: [{
    question: "brief 리뷰 파이프라인을 돌립니다 — 에이전트 3 + codex 2회 (cost_class: high). 진행할까요?",
    header: "Review cost",
    options: [
      {label: "전체 리뷰 진행 (권장)", description: "방향성(Claude+codex) → 충실도(격리 critic+codex) → 냉독. 4개 산출물을 Step B 게이트에 올립니다."},
      {label: "건너뛰고 Step B로", description: "리뷰 없이 진행. skip record가 Step B 게이트 질문에 표시됩니다."}
    ],
    multiSelect: false
  }]
})
```

*"건너뛰고 Step B로"* 선택은 kill switch와 동일 경로입니다 — record + loud advisory 후 Step B.
사용자 주권(P17)이고 polite stop이 아닙니다(게이트를 실제로 띄웠고 사용자가 redirect했으므로).

## zero-tool 격리 선결 조건

`brief-critic`·`brief-readback`의 격리는 **도구 표면으로 성립하거나 성립하지 않습니다.**
판정은 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`의 `**분기 판정:**` 한 줄입니다.
그 파일이 없거나 판정을 읽을 수 없으면 **파이프라인을 시작하지 않습니다** — probe 미실행
상태로 구현·실행을 진행하지 않습니다(AC2b).

probe는 세 조건을 **적대적으로** 확인한 것입니다: **P1** agent 정의가 resolve·dispatch된다 ·
**P2** 알려진 canary 파일을 읽으라는 명시적 지시에 도구 호출이 불가·거부된다 · **P3** 트랜스크립트
census로 실제 도구 목록이 빈 것을 확인(자기보고 불신). P1만 통과한 것은 *"로드됐다"* 이지
*"도구가 없다"* 가 아닙니다.

#### probe 통과 분기 (`ZERO_TOOL_OK`)

critic·readback이 `tools: []`이므로 audit 도달 경로가 물리적으로 없습니다. 충실도 verdict는
**hard gate**입니다 — `fidelity_verdict: needs_revise`면 3단계로 넘어가지 않고 수정 경로를 탑니다.
D2 충족.

#### probe 실패 분기 (`ZERO_TOOL_UNAVAILABLE`)

critic·readback이 `tools: Read`를 유지하므로 격리가 **보장되지 않습니다.** 그러면 충실도
verdict를 **advisory**로 내립니다 — findings를 Step B에 올리고 사용자가 판정하며, 파이프라인을
자동 차단하지 않습니다. 독립성이 보장되지 않는 리뷰어의 판정으로 차단하면 담보하는 것이
없는데 담보하는 척하는 것입니다.

이 분기에서는 **record 2건**을 남깁니다(양쪽 도구가 함께 되돌아가므로 냉독의 *순진함* 전제도
같은 원인으로 훼손됩니다 — gap 판정을 그만큼 낮게 읽어야 합니다):

```bash
BRS="python3 ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/brief_review_state.py"
$BRS degrade-append "$STATE" --component critic   --axis fidelity \
    --status degraded --reason "zero-tool 불가 — 격리 미보장"
$BRS degrade-append "$STATE" --component readback --axis readback \
    --status degraded --reason "zero-tool 불가 — 격리 미보장"
```

그리고 **D2(*"payload 파일 하나만 받는 hard gate"*) 미충족을 조용히 넘기지 않고** C4 경로로
사용자에게 보고합니다(Step B 게이트 question 텍스트).

## 상태

state는 새 파일을 만들지 않고 기존 `.claude/spec-distill/<session-id>/state.local.md`에 키 3개를
씁니다. 훅이 읽는 파일과 **같은 리졸버**로 경로를 구합니다:

```bash
PR="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
harness_sid="$(python3 "$PR/hooks/state_path.py" session-id)"
ROOT="$(python3 "$PR/hooks/state_path.py" state-root)"
STATE="$ROOT/$harness_sid/state.local.md"
python3 "$PR/scripts/brief_review_state.py" init "$STATE"     # 키 3개 idempotent 추가
```

`init`은 부재 키만 default로 추가합니다(`brief_review_stage: direction` ·
`brief_critic_rounds: 0` · `brief_review_degradations: []`). 기존 값을 backward-rewrite하지
않습니다. `harness_sid`가 빈 값이면 상태 기록 없이 진행하되 **loud advisory**를 남기고 모든
degrade를 Step B 게이트 텍스트로만 전달합니다(기록 실패를 조용히 삼키지 않습니다).

## 진입 첫 액션 — 원문 완전성 (§6 ↔ state 원장)

```bash
python3 "$PR/scripts/check_verbatim_coverage.py" "$PAYLOAD" "$STATE"; rc=$?
```

파이프를 걸지 마세요 — `| tail`을 붙이면 `$?`가 파이프 마지막 명령의 코드가 되어 죽은 스크립트가
성공으로 읽힙니다(리포 실측).

| rc | 뜻 | 동작 |
|---|---|---|
| `0` | 위반 없음 | 1단계로 |
| `exit 1` | 위반 발견(`missing_ids`/`not_contained`) | **차단.** §6를 보완(추가만 — 아래 append-only)하고 `check_brief.py gate` → 이 검사를 **재실행**. 리뷰 단계로 넘어가지 않습니다 |
| `exit 3` | 검사 불가(파일 부재·파싱 실패) | degrade 후 계속 + record(`component: verbatim_coverage`, `affected_axis: completeness`, `verification_status: skipped`) |
| `exit 4` | 내부 오류 | `3`과 동일 처리 + 오류 전문을 `--reason`에 |
| 그 외 non-zero | 예측 못 한 실패 | `3`과 동일 취급 — indeterminate ≠ clean |

**왜 진입에 두는가**: §6가 불완전하면 방향성 리뷰도 불완전한 문서를 보고, critic은 §6를 ground
truth로 쓰므로 판정 자체가 무의미해집니다. §6에 append가 일어날 때마다 **재실행**합니다.

## 수정 권한 (모든 단계 공통)

| 섹션 | 권한 |
|---|---|
| §0 / §1 / §3 / §4 / §5 / §7 | 자유 수정 |
| §2 제약 | 자유 수정 — **단 frontmatter `user_sourced_items`와 동시**(bijection B가 statement 내용까지 대조하므로 한쪽만 고치면 게이트 red) |
| **§6 사용자 원문** | **append-only.** `S<N>` 항목 **추가**만 허용, 기존 항목 본문 변경 금지(P21 placeholder 치환만 예외) |

§6를 자유롭게 고칠 수 있으면 *critic이 지적 → 원문을 지적에 맞게 고쳐 통과* 라는 laundering이
열립니다. 추가는 덮어쓰기가 아니므로 provenance가 온전히 남습니다.

**저자는 어느 리뷰어의 finding도 임의로 기각하지 못합니다.** 반영하지 않을 findings는
**이유와 함께 Step B 게이트에서 사용자에게 올립니다**(P17) — 저자의 자기승인 경로를 차단합니다.
```

- [ ] **Step 4: SKILL 구현 — 1단계 방향성 (같은 파일에 이어서)**

```markdown
## 1단계 — 방향성 (C4 경로)

방향성이 먼저인 이유: 방향성 지적은 사용자 재결정을 유발하고, 재결정이 나면 §2 제약·§3 OQ가
바뀝니다. 충실도를 먼저 수렴시키면 그 수렴이 무효화됩니다. **충실도는 문서가 더 이상 바뀌지
않는 시점에 봅니다.**

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" direction
```

### 1-a. 웹 예산 확인 (dispatch **전**)

```bash
python3 "$PR/scripts/web_budget.py" check "$STATE"; web_rc=$?
```

`brief-direction-reviewer`는 `tools:`에 `Bash`가 **없습니다**(Law 2) — 자기 예산을 확인할 경로가
없으므로 판정은 **orchestrator 책임**입니다. 리뷰어에게 `Bash`를 주는 것은 Law 2 위반이므로
대안이 아닙니다.

- `web_rc == 0` → 평소대로 dispatch.
- `web_rc != 0`(소진) → dispatch 프롬프트에 *"웹 없이 repo + payload 근거로 답하라"* 조건을
  실어 dispatch하고 record(`component: direction_reviewer`, `affected_axis: direction`,
  `verification_status: degraded`, reason=*"웹 예산 소진 — repo 근거만"*).
  **codex #1의 웹은 이 카운터 밖이라 살아 있습니다** — 외부 근거가 완전히 죽지 않습니다(이중화).
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` → 양쪽 웹 없이 + record.

dispatch **후** 1회 increment:

```bash
python3 "$PR/scripts/web_budget.py" increment "$STATE"
```

> ⚠️ **계측 단위는 dispatch입니다.** 리뷰어 turn *내부*의 개별 `WebSearch`/`WebFetch` 호출 수는
> 리뷰어도(`Bash` 없음) orchestrator도(subagent 내부 도구 호출을 볼 수 없음) 셀 수 없습니다.
> 그래서 `SESSION_CAP = 8`은 이 컴포넌트에 대해 *"검색 8회"* 가 아니라 **dispatch 8회**입니다.
> 프롬프트로 검색 횟수를 묶는 것은 E10 위반이므로 대안이 아닙니다.

### 1-b. direction-reviewer dispatch (경로 전달 — 이 축은 근거 폭이 본질)

```javascript
Agent({
  description: "Brief direction review",
  subagent_type: "spec-distill:brief-direction-reviewer",
  prompt: `Review the interview brief at <PAYLOAD_PATH> for directional soundness.
Read the repository and search the web. Answer both axis-(b) questions with evidence.
Every finding must carry exactly one question for the user to decide.
<웹 예산 소진 시: "Do not use the web this run — answer from the repository and the brief alone.">`
})
```

### 1-c. codex #1 (방향성 축)

```bash
codex_avail="$(bash "$PR/scripts/detect_codex.sh" | sed -n 's/^codex_available: //p')"
if [[ "$codex_avail" == "true" ]]; then
  bash "$PR/scripts/run_brief_codex_reviewer.sh" direction "$PAYLOAD" "$(pwd)" "$CODEX_DIR_YAML"
else
  : # skip + record(component: codex, affected_axis: all, verification_status: skipped)
fi
```

codex 부재 시 loud advisory:

> `[spec-distill v0.24.0] codex 방향성 co-review SKIPPED (reason: <skip_reason>) — Claude-only, 모델 다양성 없음 (degraded).`

**축은 죽지 않습니다** — Claude 담당자가 남습니다. 이것이 3-에이전트 분리(E3)의 배당금입니다.

### 1-d. 보고 (병합 없음)

**방향성은 병합하지 않습니다** — verdict가 없고 산출물이 *사용자에게 낼 질문*이라 합칠 대상이
없습니다. 두 리뷰어의 항목을 **나란히** 제시하고, 같은 지적이 겹치면 합쳐 보여줍니다(문구가
달라 결정론 dedup은 불가하며 모델 판단에 맡깁니다 — 판단이 틀리면 사용자가 중복을 보거나
하나를 놓칩니다, spec §11 ⑤).

각 항목은 `<출처(Claude|codex)> — <무엇을 뒤집자는 것인가> — <근거 URL/file:line> — <사용자가 결정할 질문>`.

사용자가 방향을 뒤집으면(C4 재결정):

1. `user_sourced_items`의 해당 항목 `status` 변경 또는 항목 교체.
2. 그 **결정 발화를 §6에 새 `S<N>`으로 추가**합니다(기존 항목 수정이 아닙니다). state의
   `user_statements`에도 append되므로 다음 완전성 검사가 대조 대상으로 삼습니다.
3. 뒤집힌 방향은 §5 `기각` 항목에 *무엇을 왜 버렸는지* 로 남깁니다 — **증거 문장**이며 권위
   문장이 아닙니다(C5).
4. payload 재저장 → `check_brief.py gate` 재실행 → `check_verbatim_coverage.py` 재실행.

리뷰어는 방향을 **바꾸지 않습니다.** 사용자에게 올리고 사용자가 결정합니다(D5b·P17).
```

- [ ] **Step 5: SKILL 구현 — 2단계 충실도 (같은 파일에 이어서)**

`### 2-a` 윈도우 안에는 **payload 경로 문자열이 없어야** 합니다(T8). blob은 스크립트 stdout으로
프롬프트에 실립니다.

```markdown
## 2단계 — 충실도 (fail-closed 합집합)

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" fidelity
```

### 2-a. critic dispatch 블록

프롬프트에 **payload 전문을 inline**합니다. 경로를 주지 않습니다 — 이 축은 문서 **내부 대조**이고
외부 정보가 오염원입니다. blob은 빌더가 만듭니다(frontmatter의 `audit_file`·`name`·`created_at`
세 값을 `<redacted>`로):

```bash
BLOB="$(python3 "$PR/scripts/build_brief_inline_blob.py" "$PAYLOAD")"; blob_rc=$?
```

`blob_rc == 3`이면 본문에 위생 미달 잔존이 있다는 뜻입니다 — 원문 보존이 우선이라 지우지 않고
record(`component: critic`, `affected_axis: fidelity`, `verification_status: degraded`)를 남기고
계속합니다.

```javascript
Agent({
  description: "Brief fidelity critic",
  subagent_type: "spec-distill:brief-critic",
  prompt: `Review this interview brief for fidelity — did the §2 summary distort,
drop, or invent what the user said in §6? Check all six categories explicitly.
Emit **Status:** on its own line, then the brief-critic-issues block.

<brief>
${BLOB}
</brief>`
})
```

critic의 raw 출력을 **요약·바꿔쓰기 없이 그대로** scratch 파일에 저장합니다 — 파싱은 병합
스크립트가 그 파일에서 수행합니다(orchestrator가 category/target_section을 전사하면 안 됩니다).

### 2-b. codex #2 (충실도 축) + 병합

```bash
bash "$PR/scripts/run_brief_codex_reviewer.sh" fidelity "$PAYLOAD" "$(pwd)" "$CODEX_FID_YAML"
python3 "$PR/scripts/merge_brief_review.py" \
    --critic-output "$CRITIC_OUT" --codex-yaml "${CODEX_FID_YAML:-/nonexistent}"
```

codex #2는 **항상 최종 문서를 봅니다** — stale이 원리적으로 불가능합니다.

병합 stdout의 키를 그대로 씁니다: `fidelity_verdict` · `critic_verdict` · `codex_verdict` ·
`critic_verdict_unrecoverable` · `codex_isolated` · `codex_degraded` · `fidelity_findings` ·
`advisory[]`. `advisory[]`는 사용자에게 **그대로** 표시합니다.

**권위 계약** — codex는 advisory가 아니라 **binding**입니다. 어느 리뷰어든 Issues를 내면
`needs_revise`이고, codex 단독으로도 verdict가 만들어집니다. `codex_isolated: false`는
**verdict 입력이 아니라 저자용 라벨**입니다 — 이 finding은 프레이밍을 흡수한 리뷰어가 낸 것일
수 있으니 그 가능성을 함께 고려하라는 뜻이고, **등급을 낮추는 근거가 아닙니다.**

`critic_verdict_unrecoverable: true`이고 `codex_degraded: true`면 **approved로 해소하지 않고**
사람에게 올립니다(round-4에서 실측된 verdict 소실의 봉쇄).

### 2-c. 충실도 루프 전이

`fidelity_verdict`가 `needs_revise`면 수정하고 **fresh critic 재리뷰 1회는 구조적으로 필수**입니다
(E8 — writer가 자기 수정을 승인하는 경로 차단). 재dispatch **전에** 게이트를 통과해야 합니다:

```bash
python3 "$PR/scripts/brief_review_state.py" can-redispatch "$STATE"; can=$?
# can == 0 → 재dispatch 허용.  can == 1 → escalate (더 이상 재dispatch 없음)
python3 "$PR/scripts/brief_review_state.py" bump-critic-round "$STATE"   # 재dispatch 시점에 +1
```

| # | 상태 | 이벤트 | 동작 | `brief_critic_rounds` |
|---|---|---|---|---|
| 1 | 2단계 진입 | critic #1 dispatch (+ codex #2 병렬) | 병합 → `fidelity_verdict` | **0 유지** — 최초 리뷰는 *재*라운드가 아니다 |
| 2 | `approved` | — | 3단계로 | 0 유지 |
| 3 | `needs_revise` | 저자가 허용 행위로 수정 | **fresh critic 재dispatch 필수** | +1 → 1 |
| 4 | 재리뷰 `approved` | — | 3단계로 | 1 유지 |
| 5 | 재리뷰 `needs_revise`, 카운터 1 | orchestrator 판단 → 수정 + 재dispatch | fresh critic 재dispatch | +1 → 2 |
| 6 | 카운터 `== 2` **이고** Issues 잔존 | — | **Step B forced escalate** | 2 고정 |

**경계값**: escalate는 `== 2`에서 발화합니다(`> 2`를 기다리지 않습니다). fresh 재dispatch는
**최대 2회**이고 critic dispatch 총계는 최대 3회입니다. 카운터는 **수정 후 재dispatch 시점에**
증가합니다(리뷰 결과 수신 시점이 아닙니다).

**상한 불변식**: 어떤 전이도 카운터를 2 초과로 만들지 않습니다. 따라서 3 이상은 도달 불가능한
손상 상태이며 스크립트가 2로 clamp하고 advisory를 냅니다(escalate로 수렴).

**행 6에 도달하면 record를 남깁니다**: `component: critic`, `verification_status: degraded`,
reason=*"재리뷰 상한 2 초과, 미해결 findings 잔존"*.

**orchestrator의 허용 행위 — 닫힌 열거:**

| | 행위 |
|---|---|
| ✅ | §0·§1·§2·§3·§4·§5·§7 수정 (§2는 frontmatter와 동시) |
| ✅ | §6에 `S<N>` **추가** |
| ✅ | 미반영 findings를 **이유와 함께** Step B로 이월 |
| ❌ | finding 임의 기각 |
| ❌ | §6 기존 항목 본문 변경 |
| ❌ | 상한을 넘긴 추가 재dispatch |

**충실도에 라운드 루프를 두지 않는 이유**: `reviewing-spec`의 라운드 루프 + cap 5는 design doc
리뷰가 *설계 결함*을 찾는 반복 개선이라 정당합니다. 충실도는 *"§2 요약이 §6 원문을 왜곡했나"*
라는 좁고 거의 기계적인 축이라 반복 수렴 대상이 아닙니다 — 루프는 trivia ceremony입니다.
```

- [ ] **Step 6: SKILL 구현 — 3단계 냉독 + Step B 전달 (같은 파일에 이어서)**

`### 3-a` 윈도우 안에는 `category`/`severity`/`sentinel`/`JSON`/`audit`/`G1`~`G5`/gap 어휘가
**하나도 없어야** 합니다(T9·T30). 판정 기준은 `### 3-b`에 둡니다.

```markdown
## 3단계 — 냉독 (advisory 측정)

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" readback
```

문서가 더 이상 바뀌지 않는 시점의 문서를 읽어야 측정에 의미가 있습니다 — 그래서 마지막입니다.

### 3-a. readback dispatch 블록

```bash
BLOB="$(python3 "$PR/scripts/build_brief_inline_blob.py" "$PAYLOAD")"
```

```javascript
Agent({
  description: "Brief cold readback",
  subagent_type: "spec-distill:brief-readback",
  prompt: `Read this document cold and say back, in plain prose, what you
understood: what it is trying to do, what is settled and what is still open, and
what happens next. Nothing else.

<document>
${BLOB}
</document>`
})
```

프롬프트에 판정 기준·출력 형식·검사 항목을 **주지 않습니다.** 형식 자체가 오염원입니다
(Spec A 인터뷰에서 **실측**: 시범 에이전트가 문서 안의 red-flag 기준을 읽고 그 답을 회피했다고
스스로 보고했습니다). 구조화는 받는 쪽이 합니다.

출력이 비거나 실패하면 record(`component: readback`, `affected_axis: readback`,
`verification_status: unavailable`)를 남깁니다 — **"gap 0"으로 읽지 않습니다**(indeterminate ≠ clean).

### 3-b. gap 대조 (요약 ↔ payload)

받은 산문 요약을 payload의 §0/§1/§2/§3/§7과 대조해 gap을 분류합니다. **닫힌 다섯 클래스**입니다:

| # | gap 클래스 | 판정 |
|---|---|---|
| G1 | **미결을 확정으로 읽음** — §3 OQ 항목을 결정된 것으로 요약 | 요약에 그 OQ가 결정으로 등장 |
| G2 | **확정을 미결로 읽음** — `status: confirmed` 항목을 열린 것으로 요약 | 요약에 그 제약이 미결/후보로 등장 |
| G3 | **최상위 제약 누락** — 최상위 항목의 내용이 요약에 없음 | 해당 id의 내용이 요약에 부재 |
| G4 | **Goal ↔ Non-goal 반전** — §1의 Non-goal을 goal로(또는 역) 요약 | 방향이 뒤집힌 서술 존재 |
| G5 | **다음 행동 오독** — §7 Next Action과 다른 다음 단계를 서술 | 요약의 next step ≠ §7 |

**성공 조건**: G1–G5 **전부 0건**이면 readback pass. 1건 이상이면 그 항목을 Step B 게이트에
**세 조각**으로 올립니다 — *어느 클래스 / 요약의 어느 문장 / payload의 어느 절*.

**이 판정은 advisory입니다** — pass/fail이 파이프라인을 차단하지 않고 사용자가 최종 판정합니다.
프레시 에이전트는 *잘못 재구성된* payload도 정확히 요약할 수 있습니다 — 원래 의도와 비교할
독립 ground truth가 없으므로 hard verdict로 쓰면 false block이 납니다.

여섯 번째 클래스가 실제로 관측되면 **여기에 추가하는 것이 compounding 이벤트**입니다(Law 3).

## Step B로 전달

```bash
python3 "$PR/scripts/brief_review_state.py" set-stage "$STATE" done
python3 "$PR/scripts/brief_review_state.py" get "$STATE"     # degradations 회수
```

`conducting-interview` Step B의 proceed 게이트에 **네 가지**를 싣습니다:

1. 확정 후보 목록(기존 B-0 프로즈).
2. **방향성 C4 항목** — 출처 라벨 + 사용자가 결정할 질문.
3. **readback 요약 전문 + gap 목록**(세 조각 형식).
4. **모든 degrade record** — `AskUserQuestion`의 **question 텍스트에** 각 record를 한 줄로.
   옵션 description이 아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다.
   배열이 비면 `degrade 없음`을 한 줄로 명시합니다(침묵과 구분).

**리뷰 생략 방지의 실제 메커니즘이 이 전파입니다.** 결정론 체크가 아닙니다 — 게이트는 *존재*만
보고 사용자는 *내용*을 보므로 사람이 더 강한 백스톱이며, 그래서 *"리뷰 라운드 기록이 있는가"*
같은 이빨 없는 검사를 넣지 않습니다(검사 대상이 통과 조건을 직접 쓰므로).

미반영 findings는 **이유와 함께** 여기 올립니다 — 저자는 어느 리뷰어의 finding도 임의로 기각하지
못합니다(AC7b).

## audit 텔레메트리

`templates/interview-audit-template.md` §4·§5에 리뷰 라운드 기록을 남깁니다(순수 텔레메트리 →
audit, D1의 분할선과 정합). 이것은 **기록**이고 게이트 통과 조건이 아닙니다.
```

- [ ] **Step 7: 테스트 통과 확인**

```bash
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh | tail -5
```
Expected: `Fail: 0`. 윈도우 assert가 비었다고 나오면 헤더 리터럴(`### 2-a.` 등)을 확인한다.

- [ ] **Step 8: mutation — 윈도우 락이 실제로 이빨을 갖는지 증명**

```bash
SD=plugins/spec-distill
SK="$SD/skills/reviewing-brief/SKILL.md"
cp "$SK" /tmp/rb.bak || exit 1

# (a) critic 블록 **안에** payload 경로 삽입 → T8 red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = t.replace("### 2-a. critic dispatch 블록\n",
              "### 2-a. critic dispatch 블록\n\n(참고: payload는 docs/superpowers/interview/ 에 있다)\n")
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T8: critic dispatch 블록에 interview"
cp /tmp/rb.bak "$SK"

# (b) 블록 **밖** 삽입은 통과해야 한다 — 닫힌 열거의 한계를 명시적으로 확인
printf '\n<!-- 블록 밖 참고: docs/superpowers/interview/ -->\n' >> "$SK"
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✓ T8: critic dispatch 블록에 payload 경로 부재"
cp /tmp/rb.bak "$SK"

# (c) readback 블록 안에 severity 삽입 → T9 red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = t.replace("### 3-a. readback dispatch 블록\n",
              "### 3-a. readback dispatch 블록\n\n각 항목에 severity: 를 붙여 달라고 요청한다.\n")
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T9: readback 블록에 스키마 어휘 'severity'"
cp /tmp/rb.bak "$SK"

# (d) 실패 분기에 'hard gate' 삽입 → T23 red (주장 > 보장)
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = t.replace("critic·readback이 `tools: Read`를 유지하므로 격리가 **보장되지 않습니다.**",
              "critic·readback이 `tools: Read`를 유지하지만 충실도는 여전히 hard gate 입니다.")
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T23: 실패 분기에 'hard gate' 문구"
cp /tmp/rb.bak "$SK"

# (e) G3 클래스 삭제 → T30 red
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = re.sub(r"^\| G3 \|.*\n", "", t, flags=re.MULTILINE)
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T30: gap 클래스 G3 누락"
cp /tmp/rb.bak "$SK"

# (f) 루프 문맥 **밖**에 상한 표현 삽입 → T28 red (E10)
printf '\ncodex는 최대 3회까지만 검색한다.\n' >> "$SK"
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T28: 루프 문맥 밖 상한 표현"
cp /tmp/rb.bak "$SK"

# (g) readback record 삭제 → T23 red (probe 실패 분기 2건 중 1건)
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = t.replace('$BRS degrade-append "$STATE" --component readback --axis readback \\\n'
              '    --status degraded --reason "zero-tool 불가 — 격리 미보장"\n', "")
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T23: readback record 부재"
cp /tmp/rb.bak "$SK"

# (h) 기각 금지 서술 삭제 → T25 red
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("plugins/spec-distill/skills/reviewing-brief/SKILL.md")
t = p.read_text(encoding="utf-8")
t = re.sub(r"\*\*저자는 어느 리뷰어의 finding도 임의로 기각하지 못합니다\.\*\*", "", t)
t = re.sub(r"미반영 findings는 \*\*이유와 함께\*\* 여기 올립니다[^\n]*\n", "", t)
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_reviewing_brief_skill.sh" 2>&1 | grep -c "✗ T25"
cp /tmp/rb.bak "$SK"; rm -f /tmp/rb.bak

bash "$SD/tests/test_reviewing_brief_skill.sh" | tail -2
```

Expected: (a) `1`, (b) `1`(**블록 밖 삽입은 통과 — spec §6.1이 명시한 닫힌 열거의 한계이며 V6가 그 절반을 본다**), (c)~(h) 각각 `1` 이상, 마지막 `Fail: 0`.

- [ ] **Step 9: 커밋**

```bash
git add plugins/spec-distill/skills/reviewing-brief/SKILL.md \
        plugins/spec-distill/tests/test_reviewing_brief_skill.sh
git commit -m "feat(spec-distill): reviewing-brief skill — 3단계 파이프라인 + probe 이진 분기 + degrade 전파"
```

---

## Task 8: `conducting-interview` 진입 한 블록 + Step B 산출물 실기

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (Step A 뒤에 `### Step A.5` 삽입 · `#### B-2` 게이트에 산출물·degrade 실기 · P21 줄에 canonical 토큰)
- Create: `plugins/spec-distill/tests/test_brief_review_entry.sh`

**Interfaces:**
- Consumes: `reviewing-brief` skill 이름(Task 7).
- Produces: 진입점. **`conducting-interview`의 종료 조건·Step A 게이트·Step B 4옵션 구조는 불변** — 한 블록 추가 + 게이트 텍스트에 산출물 실기뿐이다.

**왜 in-skill인가 (spec §9)**: design doc이 훅을 쓰는 이유는 writer가 외부 플러그인(`superpowers:brainstorming`)이라 가로챌 in-skill 지점이 없기 때문이다. brief의 writer는 spec-distill 자신이라 그 제약이 없다. 훅을 쓰면 훅·락·suppress·`cancel-review` 네 곳이 brief를 배워야 하고, 미해결 seam(#93 harness-sid ↔ interview-UUID)을 끌어들이며, 보안-민감 훅 표면을 넓힌다.

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_brief_review_entry.sh`:

```bash
#!/usr/bin/env bash
# Spec B AC1 지원 (V1 보완) — conducting-interview → reviewing-brief 진입 + Step B 실기.
# 기존 종료 조건·Step A 게이트·B-2 4옵션 구조가 **불변**임을 함께 잠근다(회귀 방지).
# Run: bash plugins/spec-distill/tests/test_brief_review_entry.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CI="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
window() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^#{3,4} / {exit} inw' "$CI"; }

test -f "$CI" || { note FAIL "SKILL 부재"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 진입 블록 -------------------------------------------------------------
grep -qE '^### Step A\.5' "$CI" && note PASS "Step A.5 헤더 존재" || note FAIL "Step A.5 헤더 부재"
WA5="$(window '^### Step A\.5')"
grep -qF 'reviewing-brief' <<<"$WA5" && note PASS "A.5가 reviewing-brief를 지목" || note FAIL "A.5에 reviewing-brief 부재"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' <<<"$WA5" \
  && note PASS "A.5에 kill switch 경로" || note FAIL "A.5에 kill switch 경로 부재"
# 한 블록만 추가 — A.5가 파이프라인 절차를 복제하면 두 곳 drift가 생긴다
n5="$(wc -l <<<"$WA5" | tr -d ' ')"
[[ "$n5" -le 30 ]] && note PASS "A.5가 한 블록 규모 ($n5 줄 ≤ 30)" || note FAIL "A.5가 $n5 줄 — 파이프라인을 복제했다"
for tok in 'brief-critic' 'merge_brief_review' 'check_verbatim_coverage' 'G1'; do
  grep -qF "$tok" <<<"$WA5" && note FAIL "A.5가 파이프라인 내부('$tok')를 복제" || note PASS "A.5에 '$tok' 없음 (복제 아님)"
done

# --- Step A 게이트·종료 조건 불변 (회귀 락) ---------------------------------
grep -qF 'check_brief.py' "$CI" && note PASS "Step A 게이트 보존" || note FAIL "check_brief.py 게이트가 사라졌다"
grep -qF 'floor 5차원' "$CI" && note PASS "종료 driver(floor 5) 보존" || note FAIL "종료 driver 서술 손실"
grep -qF '# confirmed 0건 — 사용자가 전부 잠정으로 판단' "$CI" \
  && note PASS "confirmed 0건 sentinel 보존" || note FAIL "sentinel 문구 손실"

# --- Step B 실기 (4 산출물 + degrade) ---------------------------------------
WB2="$(window '^#### B-2')"
[[ -n "$WB2" ]] && note PASS "B-2 윈도우 존재" || note FAIL "B-2 윈도우 부재"
grep -qF 'AskUserQuestion' <<<"$WB2" && note PASS "B-2 게이트 보존" || note FAIL "B-2 게이트 손실"
n_opt="$(grep -cE '^\s*\{label:' <<<"$WB2" || true)"
[[ "$n_opt" == "4" ]] && note PASS "B-2 4옵션 구조 불변 ($n_opt)" || note FAIL "B-2 옵션이 $n_opt 개 (구조 변경)"
for tok in '방향성' 'readback' 'gap' 'degrade'; do
  grep -qF "$tok" <<<"$WB2" && note PASS "B-2 question에 '$tok' 실림" || note FAIL "B-2에 '$tok' 부재"
done
grep -qE 'question 텍스트|question 본문' "$CI" \
  && note PASS "degrade가 question 텍스트에 렌더" || note FAIL "렌더 위치(question 텍스트) 명시 부재"
grep -qE 'degrade 없음' "$CI" && note PASS "빈 배열도 명시" || note FAIL "빈 배열 명시 부재"

# --- P21 canonical 토큰 (checker와 producer가 같은 집합) --------------------
grep -qF '<REDACTED' "$CI" && note PASS "P21 canonical 토큰 명시" || note FAIL "P21 canonical 토큰 부재"

# --- cross-compact / polite stop 가드 불변 ----------------------------------
grep -qE '턴 종료|다음 턴' "$CI" && note PASS "cross-compact 가드 보존" || note FAIL "cross-compact 가드 손실"
grep -qF 'polite stop' "$CI" && note PASS "AP2 가드 보존" || note FAIL "AP2 가드 손실"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_brief_review_entry.sh`
Expected: `Step A.5 헤더 부재` 등 FAIL.

- [ ] **Step 3: `### Step A.5` 삽입 (Step A 5번 항목 직후, `### Step B` 직전)**

```markdown
### Step A.5 — brief 리뷰 파이프라인 (Law 2 분리 리뷰, v0.24.0)

게이트(Step A 5)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고, 아직 **분리 리뷰**를
받지 않았습니다. 여기서 `reviewing-brief` skill로 넘깁니다 — 축은 둘(충실도·방향성), 담당은
셋 + codex 2회이며, 절차는 그 skill이 소유합니다(여기에 복제하지 않습니다).

```
Skill spec-distill:reviewing-brief   # 인자: payload 경로
```

- 그 skill이 `cost_class: high` 진입 승인 게이트를 띄웁니다(모델 호출 5회).
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1`이면 파이프라인이 전체 skip되고 skip record가
  Step B 게이트 질문에 표시됩니다 — 조용한 생략이 아닙니다.
- 리뷰가 payload를 수정할 수 있습니다(§2 제약·§3 OQ 등). 수정이 일어나면 그 skill이
  `check_brief.py gate`를 재실행하므로 Step B는 **리뷰 후 최종 문서**를 봅니다.
- 산출물 4종(확정 후보 / 방향성 C4 항목 / readback 요약 + gap / 모든 degrade record)이
  Step B 게이트로 넘어옵니다.
```

- [ ] **Step 4: `#### B-2` 게이트에 산출물·degrade 실기**

B-2의 `AskUserQuestion` **직전**에 아래 단락을 넣고, `question` 문자열을 교체한다(4옵션 라벨·
description은 **그대로 유지** — 기존 테스트가 `바로 brainstorming` 라벨을 assert한다):

```markdown
게이트를 띄우기 *전에* Step A.5 리뷰 산출물을 프로즈로 출력합니다(B-0 확정 후보 목록 다음):

1. **방향성 C4 항목** — `<출처(Claude|codex)> — <무엇을 뒤집자는 것인가> — <근거> — <결정할 질문>`.
2. **readback 요약 전문** + gap 목록(*어느 클래스 / 요약의 어느 문장 / payload의 어느 절*).
3. **미반영 findings** — 있으면 각각 이유와 함께. 저자가 임의로 기각한 것이 아니라 사용자 판정
   대상입니다.

그리고 `question` 텍스트에 **모든 degrade record를 한 줄씩** 싣습니다 — 옵션 description이
아니라 question 본문이어야 사용자가 옵션을 고르기 *전에* 봅니다. record가 없으면
`degrade 없음`을 한 줄로 명시합니다(침묵과 구분).
```

```javascript
    question: "interview brief 완결: <brief-path> (구조 게이트 통과, 리뷰 <verdict 요약>). 확정 후보·방향성 항목·readback gap은 위 목록대로. degrade: <record 한 줄씩 | degrade 없음>. 다음 단계?",
```

- [ ] **Step 5: P21 canonical 토큰 명시 (기존 P21 줄 교체)**

현행 `**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후 기록.` 를 아래로 교체:

```markdown
**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후
기록합니다. **치환 토큰은 `<REDACTED>` 또는 `<REDACTED:라벨>` 형태**로 씁니다(다른 허용 형태:
`<SECRET:...>` · `<TOKEN:...>` · `<KEY:...>` · `<CREDENTIAL:...>` · `<PLACEHOLDER:...>`).
`check_verbatim_coverage.py`가 §6 원문 대조에서 **이 토큰 집합**을 보고 L2를 advisory로 강등하므로,
다른 형태로 치환하면 정당한 치환이 red로 잡혀 사용자가 Step B에서 판정해야 합니다(fail-closed 방향).
```

- [ ] **Step 6: 테스트 + 기존 스위트 회귀 확인**

```bash
bash plugins/spec-distill/tests/test_brief_review_entry.sh | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh | tail -2
bash plugins/spec-distill/tests/test_conducting_interview_internal.sh | tail -2
bash plugins/spec-distill/tests/test_handoff_compact_chain.sh | tail -2
bash plugins/spec-distill/tests/test_stale_terms.sh | tail -2
```
Expected: 전부 `Fail: 0`. `test_conducting_interview_stage.sh`가 red면 **내 편집이 기존 assert를 깼다** — 옵션 라벨·sentinel 문구·섹션 수를 건드렸는지 확인한다.

- [ ] **Step 7: mutation**

```bash
CI=plugins/spec-distill/skills/conducting-interview/SKILL.md
cp "$CI" /tmp/ci.bak || exit 1

# (a) A.5에서 reviewing-brief 지목 삭제 → red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
p.write_text(t.replace("Skill spec-distill:reviewing-brief", "Skill 무언가"), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_brief_review_entry.sh 2>&1 | grep -c "✗ A.5"
cp /tmp/ci.bak "$CI"

# (b) A.5가 파이프라인을 복제 → red (두 곳 drift 방지 락)
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
t = t.replace("- 산출물 4종", "- brief-critic을 dispatch하고 merge_brief_review로 병합한다\n- 산출물 4종")
p.write_text(t, encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_brief_review_entry.sh 2>&1 | grep -c "✗ A.5가 파이프라인 내부"
cp /tmp/ci.bak "$CI"; rm -f /tmp/ci.bak

bash plugins/spec-distill/tests/test_brief_review_entry.sh | tail -2
```
Expected: (a) `1` 이상, (b) `1`, 마지막 `Fail: 0`.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_brief_review_entry.sh
git commit -m "feat(spec-distill): interview Step A.5 진입 + Step B 리뷰 산출물·degrade 실기"
```

---

## Task 9: NG3 서술 교정 + `check_brief.py` 불변식 락 + audit 텔레메트리

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py` (docstring 한 단락. **로직 무변경**)
- Modify: `plugins/spec-distill/agents/spec-reviewer.md` (description NG3 문장)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md` (§4·§5 텔레메트리)
- Create: `plugins/spec-distill/tests/test_brief_review_ng3.sh`

**Interfaces:** 없음(문서·템플릿 교정).

**왜 이 교정이 필요한가**: 현행 두 문장이 이 spec으로 **거짓이 된다** — `check_brief.py:20`의 *"This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review."* 와 `spec-reviewer.md`의 같은 서술. 게이트는 여전히 Law 1 구조 자기검사이고 **그 위에 Law 2 분리 리뷰가 얹혔다**로 고친다. 옛 문장을 남기면 미래 세션이 *"brief는 리뷰 대상이 아니다"* 를 읽고 파이프라인을 건너뛴다.

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_brief_review_ng3.sh`:

```bash
#!/usr/bin/env bash
# Spec B T12·T13 — NG3 서술 교정 + check_brief.py "brief 파일만 읽는다" 불변식.
# AC16(state 의존 추가 없음) · AC17(NG3 서술 2곳 교정)
# Run: bash plugins/spec-distill/tests/test_brief_review_ng3.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
GATE="$SD/scripts/check_brief.py"
REVIEWER="$SD/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# --- T13 / AC17 : 옛 문구 부재 AND 새 문구 존재, 2파일 각각 -----------------
OLD_EN='the brief gets no separated review'
OLD_KO='brief는 검토 대상이 아닙니다'
OLD_KO2='brief는 분리 review 대상이 아니다'

grep -qiF "$OLD_EN" "$GATE" && note FAIL "T13: check_brief.py에 옛 NG3 문구 잔존" \
                            || note PASS "T13: check_brief.py 옛 문구 부재"
grep -qE 'Law 2 (분리 리뷰|separated review).*(얹|on top|added)' "$GATE" \
  && note PASS "T13: check_brief.py 새 문구 존재" || note FAIL "T13: check_brief.py 새 문구 부재"
grep -qF 'reviewing-brief' "$GATE" \
  && note PASS "T13: check_brief.py가 후속 리뷰 위치를 가리킴" || note FAIL "T13: reviewing-brief 언급 부재"

grep -qiF "$OLD_EN" "$REVIEWER" && note FAIL "T13: spec-reviewer.md에 옛 NG3 문구 잔존" \
                                || note PASS "T13: spec-reviewer.md 옛 문구 부재"
grep -qF "$OLD_KO" "$REVIEWER" && note FAIL "T13: spec-reviewer.md 한국어 옛 문구 잔존" \
                               || note PASS "T13: spec-reviewer.md 한국어 옛 문구 부재"
grep -qF "$OLD_KO2" "$REVIEWER" && note FAIL "T13: spec-reviewer.md '분리 review 대상 아님' 잔존" \
                                || note PASS "T13: spec-reviewer.md 부정 서술 부재"
grep -qF 'brief-critic' "$REVIEWER" \
  && note PASS "T13: spec-reviewer.md가 brief 리뷰어를 가리킴" || note FAIL "T13: brief-critic 언급 부재"
# 역할 경계는 유지되어야 한다 — spec-reviewer는 여전히 design doc만 본다
grep -qE 'design doc (only|만)' "$REVIEWER" \
  && note PASS "T13: spec-reviewer 역할 경계 유지 (design doc only)" || note FAIL "T13: 역할 경계 서술 손실"

# --- T12 / AC16 : state 의존 부재 (정확 토큰) --------------------------------
# `state` 단독 grep은 항상 red다 — check_brief.py의 모든 `state` 매칭이 `statement`다(실측).
for tok in 'state.local.md' 'state_path' 'state-root'; do
  grep -qF -- "$tok" "$GATE" && note FAIL "T12: check_brief.py가 '$tok'를 참조 (불변식 위반)" \
                            || note PASS "T12: check_brief.py에 '$tok' 부재"
done
grep -qF 'user_statements' "$GATE" && note FAIL "T12: check_brief.py가 state 원장 필드를 읽는다" \
                                  || note PASS "T12: state 원장 필드 부재"
# 불변식이 문서로도 남아야 한다 (다음 세션이 깨뜨리지 않도록)
grep -qE 'brief 파일만|payload.*만 읽' "$GATE" \
  && note PASS "T12: '브리프 파일만 읽는다' 불변식 서술" || note FAIL "T12: 불변식 서술 부재"

# --- audit 템플릿 텔레메트리 -------------------------------------------------
TPL="$SD/templates/interview-audit-template.md"
grep -qE '리뷰 라운드|brief 리뷰' "$TPL" && note PASS "audit 템플릿에 리뷰 텔레메트리" || note FAIL "audit 템플릿 텔레메트리 부재"
grep -qF 'reviewing-brief' "$TPL" && note PASS "audit 템플릿이 파이프라인을 지목" || note FAIL "audit 템플릿에 파이프라인 언급 부재"
# 텔레메트리는 게이트 통과 조건이 아니다 (이빨 없는 체크 도입 금지 — AC22c)
grep -qE '게이트 (통과 )?조건이 아니|기록이며' "$TPL" \
  && note PASS "텔레메트리가 게이트 조건이 아님을 명시" || note FAIL "텔레메트리를 게이트 조건으로 오독 가능"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_brief_review_ng3.sh`
Expected: T13 옛 문구 잔존 FAIL + audit 템플릿 FAIL.

- [ ] **Step 3: `check_brief.py` docstring 교정 (해당 한 단락만)**

기존:
```python
This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review. It is a
structural self-check (Law 1), analogous to parse_spec_structure.py for specs.
```

교체:
```python
이 게이트는 **Law 1 구조 자기검사**다 (specs의 parse_spec_structure.py와 같은 층). Law 2
분리 리뷰는 v0.24.0부터 **그 위에 얹혔다** — `skills/reviewing-brief/`가 격리된 brief-critic
(충실도) · brief-direction-reviewer(방향성) · brief-readback(냉독) + codex 축별 2회를 돌린다.
즉 "brief는 분리 리뷰를 받지 않는다"는 더 이상 사실이 아니다(NG3 교정, Spec B AC17).

**불변식: 이 스크립트는 brief 파일만 읽는다** (payload + 그것이 가리키는 audit). state.local.md
의존을 여기에 넣지 않는다 — 넣으면 임의의 brief 파일에 게이트를 돌릴 수 없게 된다. state 원장
대조(§6 원문 완전성)는 별 모듈 `scripts/check_verbatim_coverage.py`의 몫이다(Spec B AC16 · E12).
```

로직은 한 줄도 바꾸지 않는다.

- [ ] **Step 4: `spec-reviewer.md` description 교정**

기존 description 안의 `NOTE:` 문장:
```
NOTE: the interview brief (docs/superpowers/interview/) is NOT this agent's target — the brief is gated by the Law 1 5-ritual structural check (check_brief.py), not separated review (NG3). This agent reviews the design doc only.
```

교체:
```
NOTE: this agent reviews the design doc only. The interview brief
(docs/superpowers/interview/) has its own reviewers as of v0.24.0 —
brief-critic (fidelity), brief-direction-reviewer (direction), brief-readback
(cold read), orchestrated by the reviewing-brief skill on top of the Law 1
structural gate (check_brief.py). Do not review the brief here.
```

본문 27행의 한국어 서술 `**interview brief는 검토 대상이 아닙니다**(NG3 — Law 1 check_brief.py 게이트가 담당).` 도 함께 교체:

```
**interview brief는 이 agent의 대상이 아닙니다** — v0.24.0부터 brief에는 전용 리뷰어
(`brief-critic`·`brief-direction-reviewer`·`brief-readback`)가 있고 `reviewing-brief` skill이
Law 1 구조 게이트(`check_brief.py`) 위에서 그것을 돌립니다. 여기서는 **design doc만** 봅니다.
```

- [ ] **Step 5: audit 템플릿 §4·§5 텔레메트리**

`templates/interview-audit-template.md`의 §4·§5를 교체:

```markdown
## 4. 게이트 실행 기록

- check_brief.py gate — <pass|fail> (<YYYY-MM-DD>)
- check_verbatim_coverage.py — <exit 0|1|3|4> (<YYYY-MM-DD>)

## 5. 프로세스 로그

- round <n>: <path (a|b|c|d)> — <한 줄 요약>

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

(순수 텔레메트리 — **기록이며 게이트 통과 조건이 아니다.** 검사 대상이 통과 조건을 직접 쓰는
검사는 이빨이 없으므로, 리뷰 생략 방지는 Step B 게이트의 degrade 전파가 담당한다.)

- 방향성: Claude <n>건 / codex <n>건 — 사용자 재결정 <n>건
- 충실도: verdict <approved|needs_revise|advisory> — critic <n>건 / codex <n>건 — 재라운드 <n>/2
- 냉독: gap <n>건 (<G1..G5 중 어느 클래스>)
- degrade: <component:reason 한 줄씩 | 없음>
- 격리: zero-tool probe <ZERO_TOOL_OK|ZERO_TOOL_UNAVAILABLE> — `codex_isolated: false`
```

- [ ] **Step 6: T10 — 기존 스위트 회귀 0 확인 (docstring 변경 후)**

```bash
bash plugins/spec-distill/tests/test_check_brief.sh | tail -2
bash plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh | tail -2
bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh | tail -2
bash plugins/spec-distill/tests/test_brief_review_ng3.sh | tail -2
bash plugins/spec-distill/tests/test_stale_terms.sh | tail -2
```
Expected: 전부 `Fail: 0`. `test_check_brief.sh`가 red면 docstring 교정이 로직을 건드렸다 — `git diff`로 확인한다.

- [ ] **Step 7: mutation**

```bash
G=plugins/spec-distill/scripts/check_brief.py
cp "$G" /tmp/cb.bak || exit 1

# (a) 옛 NG3 문구 복원 → T13 red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/scripts/check_brief.py")
t = p.read_text(encoding="utf-8")
t = t.replace('이 게이트는 **Law 1 구조 자기검사**다',
              'This is NOT a Law 2 reviewer (NG3) — the brief gets no separated review. 이 게이트는 **Law 1 구조 자기검사**다')
p.write_text(t, encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_brief_review_ng3.sh 2>&1 | grep -c "✗ T13: check_brief.py에 옛 NG3"
cp /tmp/cb.bak "$G"

# (b) state 읽기 한 줄 추가 → T12 red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/scripts/check_brief.py")
t = p.read_text(encoding="utf-8")
p.write_text(t + '\n# TEMP: read state.local.md for user_statements\n', encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_brief_review_ng3.sh 2>&1 | grep -c "✗ T12"
cp /tmp/cb.bak "$G"; rm -f /tmp/cb.bak

bash plugins/spec-distill/tests/test_brief_review_ng3.sh | tail -2
bash plugins/spec-distill/tests/test_check_brief.sh | tail -2
```
Expected: (a) `1`, (b) `2`(정확 토큰 두 개 매칭), 마지막 둘 `Fail: 0`.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py \
        plugins/spec-distill/agents/spec-reviewer.md \
        plugins/spec-distill/templates/interview-audit-template.md \
        plugins/spec-distill/tests/test_brief_review_ng3.sh
git commit -m "docs(spec-distill): NG3 서술 교정 (brief에 Law 2 리뷰가 얹혔다) + audit 리뷰 텔레메트리"
```

---

## Task 10: 메타데이터 · 훅 무증가 · 결정론 체크 열거표

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`0.23.0` → `0.24.0`)
- Modify: `plugins/spec-distill/CHANGELOG.md` (`[0.24.0]` 항목 추가)
- Modify: `plugins/spec-distill/README.md` (Flow · Principles Instantiated · Kill switches)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (버전 pin 갱신 — **과거 pin 보존**)
- Create: `plugins/spec-distill/tests/test_brief_review_meta.sh`

**Interfaces:** 없음.

**왜 마지막인가**: `test_readme_sync.sh`가 `0\.23\.[0-9]+`를 pin하므로 먼저 bump하면 Task 1–9 내내 stale-red다. bump와 pin 갱신을 같은 커밋에 담는다([[feedback_version_pin_vs_bump_rule]]).

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_brief_review_meta.sh`:

```bash
#!/usr/bin/env bash
# Spec B T15·T18·T29·T31(문서) — 메타데이터 · 훅 무증가 · 결정론 체크 열거표 · 정규화 계약.
# AC19(메타데이터) · AC22a(훅 0 추가) · AC22c(이빨 없는 체크 0 + 전수 열거) · AC11(N1–N5 순서·NFC)
# Run: bash plugins/spec-distill/tests/test_brief_review_meta.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
PJ="$SD/.claude-plugin/plugin.json"
CL="$SD/CHANGELOG.md"
RM="$SD/README.md"
HOOKS="$SD/hooks"
SPEC="$REPO_ROOT/docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
section() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^## / {exit} inw' "$2"; }

# --- T15 / AC19 : 메타데이터 (minor만 pin, patch unpin) ---------------------
grep -qE '"version": "0\.24\.[0-9]+"' "$PJ" \
  && note PASS "T15: plugin.json 0.24.x" || note FAIL "T15: plugin.json이 0.24.x가 아님"
grep -qE '^## \[0\.24\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CL" \
  && note PASS "T15: CHANGELOG [0.24.0] + ISO 날짜" || note FAIL "T15: CHANGELOG [0.24.0] 누락/비-ISO"
# append-only 누산 — 과거 엔트리 pin은 절대 빼지 않는다
for v in '0\.20\.0' '0\.22\.0' '0\.23\.0'; do
  grep -qE "^## \[$v\]" "$CL" && note PASS "T15: CHANGELOG 과거 엔트리 [$v] 보존" \
                              || note FAIL "T15: 과거 엔트리 [$v]가 사라졌다 (append-only 위반)"
done
PRIN="$(section '^## Principles Instantiated' "$RM")"
for kw in 'brief-critic' 'brief-direction-reviewer' 'brief-readback' 'reviewing-brief'; do
  grep -qF "$kw" <<<"$PRIN$(section '^## Flow' "$RM")" \
    && note PASS "T15: README에 신규 컴포넌트 '$kw'" || note FAIL "T15: README에 '$kw' 부재"
done
KS="$(section '^## Kill switches' "$RM")"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' <<<"$KS" \
  && note PASS "T15: README Kill switches에 신규 스위치" || note FAIL "T15: 신규 kill switch 미문서화"
grep -qF 'Law 2' <<<"$PRIN" && note PASS "T15: Principles Instantiated에 Law 2" || note FAIL "T15: Law 2 항목 부재"

# --- T18 / AC22a : 훅 집합 고정 열거 + 'brief' 문자열 0건 --------------------
EXPECTED="hooks.json pending-review-reminder.py review-dispatch.py session-end-cleanup.py spec-write-validator.py state_path.py"
ACTUAL="$(cd "$HOOKS" && ls -1 | sort | tr '\n' ' ' | sed 's/ $//')"
EXPECTED_SORTED="$(tr ' ' '\n' <<<"$EXPECTED" | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$ACTUAL" == "$EXPECTED_SORTED" ]] \
  && note PASS "T18: hooks/ 집합이 고정 열거와 정확히 일치 (6개)" \
  || note FAIL "T18: hooks/ 집합 불일치 — 기대[$EXPECTED_SORTED] 실제[$ACTUAL]"
n_brief="$(grep -cF 'brief' "$HOOKS/hooks.json" || true)"
[[ "$n_brief" == "0" ]] && note PASS "T18: hooks.json에 'brief' 문자열 0건" \
                        || note FAIL "T18: hooks.json에 'brief' $n_brief 건 (훅 표면 확장)"

# --- T29 / AC22c : 결정론 체크 전수 열거표 ----------------------------------
test -f "$SPEC" || note FAIL "spec 문서 부재: $SPEC"
T63="$(awk '/^### 6\.3/{inw=1; next} inw && /^## /{exit} inw' "$SPEC")"
[[ -n "$T63" ]] && note PASS "T29: spec §6.3 열거표 실재" || note FAIL "T29: §6.3 표 부재"
for chk in 'check_verbatim_coverage' 'zero-tool probe' 'merge_brief_review' 'T-lock'; do
  grep -qF "$chk" <<<"$T63" && note PASS "T29: 열거표에 '$chk'" || note FAIL "T29: 열거표에 '$chk' 누락"
done
grep -qF '누가' <<<"$T63" && note PASS "T29: '누가 쓰는가' 열 존재" || note FAIL "T29: '누가 쓰는가' 열 부재"
# 삭제된 어휘-검출 체크를 요구하지 않는다 (round-4가 잡은 dangling)
grep -qE '어휘 검출|오염 검출|contamination' <<<"$T63" \
  && note FAIL "T29: 삭제된 검출 메커니즘을 열거표가 요구" || note PASS "T29: 삭제된 검출 요구 부재"
# 신규 결정론 체크가 표에 빠지지 않았는가 — 구현된 스크립트 목록과 대조
for s in check_verbatim_coverage merge_brief_review; do
  test -f "$SD/scripts/$s.py" || note FAIL "T29: $s.py 부재 (Task 순서 이상)"
done

# --- T31(문서) / AC11 : 정규화 순서·NFC 계약이 spec에 명시 -------------------
S55="$(awk '/^### 5\.5/{inw=1; next} inw && /^### /{exit} inw' "$SPEC")"
grep -qF 'N1 → N2 → N3 → N4 → N5' <<<"$S55" \
  && note PASS "T31: 고정 순서 N1 → N5 명시" || note FAIL "T31: 고정 순서 명시 부재"
grep -qE 'N3보다 N1이 (반드시 )?먼저' <<<"$S55" \
  && note PASS "T31: 'N3보다 N1이 먼저' 근거 명시" || note FAIL "T31: 순서 근거 부재"
grep -qE 'NFC' <<<"$S55" && note PASS "T31: N5가 NFC" || note FAIL "T31: NFC 명시 부재"
grep -qE '전각/반각(은|을)? \*\*접지 않는다\*\*|접지 않는다' <<<"$S55" \
  && note PASS "T31: 폭-접기를 주장하지 않음" || note FAIL "T31: 폭-접기 주장 잔존"
grep -qF 'NFKC' <<<"$S55" && note PASS "T31: NFKC 미채택 근거 존재" || note FAIL "T31: NFKC 미채택 근거 부재"
# 구현이 문서와 일치하는가 (문서만 고치고 코드를 안 고치는 비대칭 방지)
grep -qF 'unicodedata.normalize("NFC"' "$SD/scripts/check_verbatim_coverage.py" \
  && note PASS "T31: 구현이 NFC를 쓴다" || note FAIL "T31: 구현이 NFC가 아니다 (문서-코드 drift)"

# --- E10 : 신규 결정론 체크가 이빨 없는 의례를 도입하지 않았는가 -------------
grep -rqE '리뷰 라운드 기록이 (있는가|존재)' "$SD/scripts" "$SD/skills" 2>/dev/null \
  && note FAIL "AC22c: 이빨 없는 '리뷰 라운드 기록' 검사가 도입됐다" \
  || note PASS "AC22c: 이빨 없는 기록 검사 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_brief_review_meta.sh`
Expected: T15 버전·CHANGELOG·README FAIL. T18·T29·T31은 이미 PASS일 수 있다(훅 무변경 + spec 문서 기존).

- [ ] **Step 3: `plugin.json` bump**

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("plugins/spec-distill/.claude-plugin/plugin.json")
d = json.loads(p.read_text(encoding="utf-8"))
assert d["version"] == "0.23.0", f"예상 밖 현재 버전: {d['version']}"
d["version"] = "0.24.0"
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("bumped to", d["version"])
PY
git diff --stat plugins/spec-distill/.claude-plugin/plugin.json
```
`git diff`가 version 한 줄만 보여야 한다(`description` 재포맷이 섞이면 되돌린다).

- [ ] **Step 4: `CHANGELOG.md` — `# Changelog` 바로 아래 삽입**

```markdown
## [0.24.0] — 2026-07-27

### Added
- **brief 리뷰 파이프라인 (Law 2 분리 리뷰)** — `skills/reviewing-brief/`가 3단계를 돌린다:
  방향성(Claude + codex, 보고만) → 충실도(격리 critic + codex, fail-closed 합집합) → 냉독.
  Spec A(v0.23.0)가 *"신규 에이전트 0개 — 리뷰 파이프라인은 후속"* 으로 미룬 것이다.
- `agents/brief-critic.md` — 충실도 리뷰어. payload **전문 inline**(경로 미제공),
  `audit_file`·`name`·`created_at` redact. `category` 6종(`distortion`/`omission`/`insertion`/
  `provenance_mislabel`/`authority_syntax`/`evidence_unsupported`)을 각각 점검한다.
- `agents/brief-direction-reviewer.md` — 방향성 리뷰어. repo + 웹. **판정이 아니라 질문**을
  낸다(각 finding에 사용자가 결정할 질문 1개 필수 — C4가 사문이 되지 않게).
- `agents/brief-readback.md` — 냉독. 출력 스키마·판정 기준을 **주지 않는다**(형식이 오염원).
- `scripts/check_verbatim_coverage.py` — payload §6 ↔ state `user_statements` 대조(L1/L2).
  정규화 N1–N5(순서 고정, **NFC**), exit `1` 위반 / `3` 검사불가 / `4` 내부오류로 분리.
- `scripts/brief_review_state.py` — state 키 3개 소유. 재리뷰 상한 2 경계값(`== 2` escalate),
  도달 불가 값 clamp, degradation record 4필드 닫힌 enum.
- `scripts/merge_brief_review.py` — 충실도 fail-closed 합집합. codex는 **binding**이며 단독으로
  verdict를 만든다. `codex_isolated: false`는 저자용 라벨이고 verdict 입력이 아니다.
- `scripts/build_brief_codex_prompt.py` + `brief-codex-{direction,fidelity}-checklist.md` +
  `run_brief_codex_reviewer.sh` — codex 축별 2회. **코드 1곳 + 데이터 2곳.**
- `scripts/build_brief_inline_blob.py` — critic·readback 공용 redacted blob.
- kill switch `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` — 파이프라인 전체 skip + record.

### Changed
- `conducting-interview` Step A.5로 리뷰 파이프라인 진입(한 블록). Step B 게이트가 산출물 4종과
  **모든 degrade record를 question 텍스트에** 싣는다 — 사용자가 옵션을 고르기 *전에* 본다.
- **NG3 서술 교정**(`check_brief.py` docstring · `agents/spec-reviewer.md`): *"brief는 분리 리뷰를
  받지 않는다"* 가 이 버전으로 거짓이 됐다. 게이트는 여전히 Law 1이고 그 위에 Law 2가 얹혔다.
- `templates/interview-audit-template.md` §4·§5에 리뷰 라운드 텔레메트리 — **기록이며 게이트
  통과 조건이 아니다**(검사 대상이 통과 조건을 직접 쓰는 검사는 이빨이 없다).
- P21 치환 토큰을 `<REDACTED>` 계열로 못 박았다 — producer와 checker가 같은 집합을 봐야 L2
  advisory 강등이 발화한다.

### Security
- 신규 에이전트 3개 전부 fail-closed `tools:` allowlist, 쓰기·실행·위임 도구 **0개**(Law 2).
  `model:`은 전부 `inherit`(리터럴 핀 금지 — 세션이 더 강한 모델일 때 downgrade 방지).
- 격리는 **zero-tool probe 이진 분기**로 성립한다. probe 통과 시 `tools: []`로 도달 경로가
  물리적으로 없고 충실도가 hard gate. 실패 시 `tools: Read` + 충실도 **advisory 강등** +
  record 2건 + D2 미충족 사용자 보고 — 보장되지 않는 격리 위에 hard gate를 얹지 않는다.
  실측 기록: `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`.
- **훅 0개 추가** — `hooks/` 파일 집합과 `hooks.json`이 무변경이다.
```

- [ ] **Step 5: `README.md` 갱신 (3곳)**

**(a) `## Flow` 헤더를 `## Flow (v0.24.0)`으로** 바꾸고 interview 종료 뒤에 한 단계 추가:

```markdown
5.5. **brief 리뷰 (`reviewing-brief`, v0.24.0)** — 구조 게이트를 통과한 payload에 Law 2 분리
     리뷰를 얹는다. 방향성(`brief-direction-reviewer` + codex #1, 보고만) → 충실도
     (`brief-critic` 격리 + codex #2, fail-closed 합집합) → 냉독(`brief-readback`, advisory).
     `check_verbatim_coverage.py`가 진입 첫 액션으로 §6 원문 완전성을 state 원장과 대조한다.
```

**(b) `## Principles Instantiated` → `### Three Laws`에 추가:**

```markdown
- **Law 2 (brief, v0.24.0)** — 3중 분리: (a) 신규 에이전트 3개 전부 fail-closed `tools:`
  allowlist(쓰기·실행·위임 0개), (b) **입력 격리** — `brief-critic`·`brief-readback`은 payload
  전문을 inline으로만 받고 경로를 갖지 않으며, zero-tool probe 통과 시 `tools: []`로 도달 경로가
  물리적으로 없다(실패 시 verdict를 advisory로 내리고 D2 미충족을 사용자에게 보고), (c) **수정 후
  fresh critic 재리뷰 1회 필수** — writer가 자기 수정을 승인하는 경로를 차단한다(상한 2).
- **Law 3 (brief, v0.24.0)** — `brief-critic`의 `category` 6종과 readback gap 클래스 G1–G5가
  compounding substrate다. 리뷰가 놓친 결함류가 나오면 그 열거와 체크리스트를 편집하는 것이
  compounding 이벤트다(persona = 보안-민감 코드).
```

**(c) `## Kill switches`에 추가:**

```markdown
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (v0.24.0) — brief 리뷰 파이프라인 전체 skip.
  `component: pipeline` degradation record + loud advisory를 남기고 Step B로 직행한다(조용한
  생략이 아니다). 충실도·방향성·냉독 전부 미검증 상태가 게이트 질문에 표시된다.
```

- [ ] **Step 6: `test_readme_sync.sh` pin 갱신 (과거 pin 보존)**

```bash
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_readme_sync.sh")
t = p.read_text(encoding="utf-8")
old_v = r'''grep -qE '"version": "0\.23\.[0-9]+"' "$PLUGIN_JSON" \\
  && note PASS "T20: plugin.json version 0.23.x" \\
  || note FAIL "T20: plugin.json이 0.23.x가 아님"'''
new_v = r'''grep -qE '"version": "0\.24\.[0-9]+"' "$PLUGIN_JSON" \\
  && note PASS "T20: plugin.json version 0.24.x" \\
  || note FAIL "T20: plugin.json이 0.24.x가 아님"'''
assert old_v in t, "버전 pin 블록을 찾지 못함 — 손으로 갱신하라"
t = t.replace(old_v, new_v)

# CHANGELOG 엔트리 pin은 **누산**한다 — 과거 pin을 빼지 않고 최신을 추가.
old_cl = r'''grep -qE '^## \[0\.23\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \\
  && note PASS "T20: CHANGELOG [0.23.0] 엔트리 + ISO 날짜" \\
  || note FAIL "T20: CHANGELOG [0.23.0] 누락/비-ISO"'''
new_cl = old_cl + r'''
grep -qE '^## \[0\.24\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \\
  && note PASS "T20: CHANGELOG [0.24.0] 엔트리 + ISO 날짜" \\
  || note FAIL "T20: CHANGELOG [0.24.0] 누락/비-ISO"'''
assert old_cl in t, "CHANGELOG pin 블록을 찾지 못함 — 손으로 갱신하라"
t = t.replace(old_cl, new_cl)
p.write_text(t, encoding="utf-8")
print("pins updated")
PY
```

`assert`가 터지면 파일이 이미 다르다는 뜻 — `grep -n "0\.23" plugins/spec-distill/tests/test_readme_sync.sh`로 확인해 손으로 고친다. **과거 엔트리 pin을 지우지 말 것**(지우면 그 히스토리 항목이 삭제돼도 스위트가 조용히 통과한다).

- [ ] **Step 7: 전체 스위트 실행 (최종 회귀 확인)**

```bash
cd /Users/jeonghokim/Downloads/devbrew
pass=0; fail=0; failed=""
for t in plugins/spec-distill/tests/test_*.sh; do
  if bash "$t" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); failed="$failed $(basename "$t")"; fi
done
echo "BASH: pass=$pass fail=$fail FAILED:$failed"
( cd plugins/spec-distill/tests && python3 -m unittest discover -s . -p "test_*.py" -t . 2>&1 | tail -3 )
```
Expected: `fail=0` (bash 파일 수 = baseline 43 + 신규 7 = **50**), python `OK` (baseline 120 + 신규).

- [ ] **Step 8: mutation**

```bash
SD=plugins/spec-distill
cp "$SD/.claude-plugin/plugin.json" /tmp/pj.bak || exit 1
cp "$SD/hooks/hooks.json" /tmp/hj.bak || exit 1

# (a) minor를 23으로 되돌림 → T15 red
sed -i '' 's/"version": "0.24.0"/"version": "0.23.9"/' "$SD/.claude-plugin/plugin.json"
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✗ T15: plugin.json이 0.24.x가 아님"
cp /tmp/pj.bak "$SD/.claude-plugin/plugin.json"

# (a2) patch digit 변경은 통과해야 한다 (doc-only bump stale-red 방지)
sed -i '' 's/"version": "0.24.0"/"version": "0.24.7"/' "$SD/.claude-plugin/plugin.json"
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✓ T15: plugin.json 0.24.x"
cp /tmp/pj.bak "$SD/.claude-plugin/plugin.json"; rm -f /tmp/pj.bak

# (b) 훅 파일 추가 → T18 red
printf '#!/usr/bin/env python3\n' > "$SD/hooks/brief-review-hook.py"
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✗ T18: hooks/ 집합 불일치"
rm -f "$SD/hooks/brief-review-hook.py"

# (c) hooks.json에 brief 항목 추가 → T18 red
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/hooks/hooks.json")
p.write_text(p.read_text(encoding="utf-8") + "\n// brief\n", encoding="utf-8")
PY
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✗ T18: hooks.json에 'brief'"
cp /tmp/hj.bak "$SD/hooks/hooks.json"; rm -f /tmp/hj.bak

# (d) CHANGELOG 최신 항목 삭제 → T15 red
cp "$SD/CHANGELOG.md" /tmp/cl.bak || exit 1
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("plugins/spec-distill/CHANGELOG.md")
t = p.read_text(encoding="utf-8")
p.write_text(t.replace("## [0.24.0] — 2026-07-27", "## [unreleased]"), encoding="utf-8")
PY
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✗ T15: CHANGELOG \[0.24.0\]"
cp /tmp/cl.bak "$SD/CHANGELOG.md"; rm -f /tmp/cl.bak

# (e) §6.3 표에서 merge_brief_review 행 삭제 → T29 red
SPECDOC=docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md
cp "$SPECDOC" /tmp/spec.bak || exit 1
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md")
t = p.read_text(encoding="utf-8")
t = re.sub(r"^\| `merge_brief_review\.py`.*\n", "", t, flags=re.MULTILINE)
p.write_text(t, encoding="utf-8")
PY
bash "$SD/tests/test_brief_review_meta.sh" 2>&1 | grep -c "✗ T29: 열거표에 'merge_brief_review' 누락"
cp /tmp/spec.bak "$SPECDOC"; rm -f /tmp/spec.bak

bash "$SD/tests/test_brief_review_meta.sh" | tail -2
```
Expected: (a) `1`, (a2) `1`, (b) `1`, (c) `1`, (d) `1`, (e) `1`, 마지막 `Fail: 0`.

- [ ] **Step 9: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md \
        plugins/spec-distill/tests/test_readme_sync.sh \
        plugins/spec-distill/tests/test_brief_review_meta.sh
git commit -m "chore(spec-distill): v0.24.0 — 메타데이터 + 훅 무증가 락 + 결정론 체크 열거 락"
```

---

## Task 11: 수동 검증 V1–V8 (구현 후, 별 커밋 없음)

**Files:** 없음(실행 + 기록). 결과는 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`에 §추가 또는 새 감사 파일로 남긴다.

V9는 Task 1에서 이미 닫혔다. 나머지 여덟은 **모델 출력 판정·실물 산출·대화형 게이트**라 자동화되지 않는다.

- [ ] **V1 — 첫 실물 dogfood (가장 큰 항목)**

새 인터뷰 1회로 v0.23.0/0.24.0 포맷 payload+audit 실물을 산출하고 `reviewing-brief` 전 단계를 돌린다.
현재 리포에 새 포맷 실물이 **0건**이므로(실측: 게이트 6 failures) **Spec A의 미완 수동 e2e도 여기서 함께 닫힌다.**
확인: 파이프라인 순서(AC1) · 게이트 통과 · 4 산출물이 Step B에 실제로 나타나는지.

- [ ] **V2 — readback 순진함 실측**

요약이 red-flag 기준·판정 어휘를 언급하지 않는지. Spec A 인터뷰에서 **오염이 실측된** 항목이라
사라졌는지 확인해야 한다. gap 판정(G1–G5)이 실제로 분류 가능한 형태로 나오는지도 함께 본다(AC25).

- [ ] **V3 — codex 비격리 대조 (연구 가설, AC 아님)**

격리 critic이 잡은 것 vs codex #2가 잡은 것의 차이가 프레이밍 효과를 보이는지.
**차이가 0이면 `codex_isolated: false` 명시의 값이 없다는 뜻이고 §5.1의 전제가 반증된다** —
그 경우 후속 처리는 이 spec이 정하지 않는다(관측 후 결정, §11 ⑦).

- [ ] **V4 — degrade 전파**

`DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`로 1회 돌려 Step B 게이트 **question 텍스트**에 advisory가
실제로 보이는지. 리뷰 생략 방지의 유일한 메커니즘이라 이게 안 보이면 봉쇄가 없다.
`DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1`도 같이 확인(AC18).

- [ ] **V5 — §6 append-only**

사용자 재결정 시나리오를 1회 수행해 기존 §6 항목이 불변인지. §6와 state `text`를 **함께** 고치는
조율 편집은 기계로 잡히지 않으므로(§11 ⑥) 여기서 사람이 본다.

- [ ] **V6 — 격리의 개방 절반**

critic·readback 프롬프트 어디에도 audit 도달 경로가 없는지 — T8·T9의 닫힌 열거(블록 윈도우) **밖**을
사람이 읽는다. Task 7 mutation (b)가 이 한계를 실증했다(블록 밖 삽입은 통과한다).

- [ ] **V7 — `cost_class: high` 승인 게이트**

진입 시 `AskUserQuestion`이 실제로 뜨는지(AC21).

- [ ] **V8 — §6.3 분류의 정확성**

표의 *"누가 쓰는가"* 판정과 이빨 등급이 맞는지. 기계는 표의 존재·열거 완전성만 본다(AC22c).

- [ ] **V 결과 기록**

여덟 항목의 결과를 `docs/audits/`에 남긴다 — 특히 **V3가 반증이면** 그 사실이 다음 사이클의 입력이다(Law 3).

---

## 계획 self-review (작성 후 자기점검 결과)

**1. spec 커버리지** — §6의 hard AC 전부가 태스크에 배정됐다(위 매트릭스). 삭제된 AC2c·AC2d·AC23은 구현하지 않는다. §8의 T1–T25·T28–T31 전부, V1–V9 전부 배정. §7의 신규 11 + 수정 7 전부 배정. **갭 0건.**

**2. placeholder 스캔** — `TBD`/`TODO`/*"적절히 처리"*/*"위와 유사"* 0건. 모든 코드 스텝에 실제 코드가 있고, 반복되는 코드는 다시 적었다(태스크를 순서 밖으로 읽는 구현자를 위해).

**3. 타입·이름 정합** — 태스크 간 인터페이스를 대조했다:
- `brief_review_state.py` 서브커맨드 이름(`init`/`get`/`can-redispatch`/`bump-critic-round`/`set-stage`/`degrade-append`)이 Task 3 정의 ↔ Task 7 호출 ↔ Task 3 테스트에서 동일.
- `merge_brief_review.py` 출력 키 8개가 Task 4 정의 ↔ Task 7 소비 ↔ Task 4 테스트에서 동일.
- `check_verbatim_coverage.py` exit 0/1/3/4가 Task 2 ↔ Task 7 분기표 ↔ Task 2 테스트에서 동일.
- `run_brief_codex_reviewer.sh <axis> <payload> <project_dir> <out>` 인자 순서가 Task 5 ↔ Task 7 호출에서 동일.
- 에이전트 이름 3개가 Task 6 파일명 ↔ Task 7 dispatch ↔ Task 6 테스트에서 동일.
- 섹션 헤더 리터럴(`### 2-a.` · `### 2-c.` · `### 3-a.` · `#### probe 통과/실패 분기`)이 Task 7 SKILL ↔ Task 7 테스트 윈도우에서 동일.

**4. 알려진 취약점 (실행 중 확인할 것)**
- **`sed -i ''`는 BSD/macOS 문법**이다. mutation 스텝이 GNU sed 환경에서 돌면 `-i` 인자 처리가 다르다 — 이 계획은 macOS(darwin) 전제이고, 다른 환경이면 python 치환으로 바꾼다.
- **Task 7 테스트의 `grep -qE` 한국어 정규식**은 문구를 정확히 맞춰야 한다. SKILL 문구를 바꾸면 락이 red가 되므로, **락이 red면 먼저 문구 drift를 의심**하고 assert를 느슨하게 만들기 전에 문구를 되돌린다(락을 약화시키는 방향으로 고치면 이빨이 사라진다).
- **Task 1 route A는 미검증 가정**이다(`claude -p --plugin-dir`로 서브에이전트 dispatch가 되는지). Step 3에서 실패하면 route B로 내려가고, **추측으로 분기를 정하지 않는다.**
- `test_readme_sync.sh` pin 갱신 스크립트의 `assert`가 터질 수 있다(파일 내용 drift). 그때는 손으로 고치고 **과거 pin을 보존**한다.

**5. 이 계획이 spec을 넘어선 지점** — 위 「Spec 대비 계획 결정」 6건. 전부 근거·대안·E10 점검을 붙였고 되돌릴 수 있다.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-27-spec-distill-brief-review-pipeline.md`.

**Task 1(V9 probe)이 blocking이다** — 다른 태스크를 먼저 시작하지 않는다. probe 결과가 Task 6·7의 `tools:` 값과 충실도 verdict 권위를 결정한다(AC2b).
