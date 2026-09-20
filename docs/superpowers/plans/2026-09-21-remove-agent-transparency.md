# agent-transparency 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리포의 살아 있는 표면을 agent-transparency 가 devbrew 에 존재한 적 없는 상태로 되돌린다.

**Architecture:** 플러그인 디렉토리(34 파일)와 마켓플레이스 항목을 지우고, 이 플러그인 **때문에 생긴** 다른 파일의 줄(T1–T9)을 같은 커밋에서 없던 상태로 되돌린다. 중간 상태가 RED 이므로 삭제와 흔적 정리는 한 커밋이다. 흔적의 판정은 설계 §2 의 규칙 R1–R4 가 하고, 목록은 도출 절차 S1–S3 이 확정했다 — 그 확정 표가 이 문서의 「확정 표」 절이며 정본이다.

**Tech Stack:** bash (zsh 가 아니라 `bash <file>` 로 실행), python3 (`-m unittest`), git (worktree · pathspec), 기존 공용 락 스위트.

**Spec:** `docs/superpowers/specs/2026-09-20-remove-agent-transparency-design.md` — 「결정 기록」(D1–D17)과
`### Deferred to plan` 이 정본이다. 실행자는 이 계획과 설계를 함께 읽는다.

## 목차

- [Global Constraints](#global-constraints)
- [확정 표 (설계 D15 — 정본)](#확정-표-설계-d15--정본)
  - [S3 이 훑은 수치 하한 전수 (R3 판정)](#s3-이-훑은-수치-하한-전수-r3-판정)
  - [도출 절차가 남긴 증거](#도출-절차가-남긴-증거)
- [AC 추적](#ac-추적)
- [Deferred to plan 의 처분](#deferred-to-plan-의-처분)
- [File Structure](#file-structure)
- [Task 1: 착수 확인과 baseline 포착](#task-1-착수-확인과-baseline-포착)
- [Task 2: 도출 절차 S1–S3 재현 (AC8)](#task-2-도출-절차-s1s3-재현-ac8)
- [Task 3: 삭제와 흔적 정리 (한 커밋)](#task-3-삭제와-흔적-정리-한-커밋)
- [Task 4: T7 하한의 양성 대조 (AC6)](#task-4-t7-하한의-양성-대조-ac6)
- [Task 5: 구현 리뷰와 PR](#task-5-구현-리뷰와-pr)
- [실패 시 되돌리기](#실패-시-되돌리기)

## Global Constraints

설계의 C1–C5 를 그대로 옮기고, 실행에 필요한 값을 덧붙인다. 모든 Task 의 요구에 이 절이 암묵적으로 포함된다.

- **C1 — 메인 체크아웃을 건드리지 않는다.** 모든 편집·실행은 워크트리
  `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency` 의 **절대경로**로 한다.
  `cd` 후 상대경로로 일하지 말 것 — Bash 도구는 호출마다 새 셸이라 cwd 가 되돌아간다.
- **C2 — 삭제와 흔적 정리는 한 커밋이다.** 중간 상태가 RED 이기 때문이다: T3 만 먼저 지우면 이 플러그인의 처분
  앵커가 짝을 잃어 축 A① 가 23 ≠ 22 로 깨지고, 플러그인만 먼저 지우면 T7 하한이 RED 다. 그래서 Task 3 이 크다 —
  쪼갤 수 없어서지 묶는 게 좋아서가 아니다.
- **C3 — 남는 `plugins/*` 파일을 편집하지 않는다.** 편집 대상은 `.claude-plugin/` · `docs/` · `shared/` · `tools/`
  뿐이다. 확정 표에 `plugins/*` 편집이 하나도 없으므로 **버전 bump·CHANGELOG 는 없다**. 만약 실행 중에
  `plugins/*` 편집이 필요해지면 그 플러그인을 같은 커밋에서 bump 하고, 그 자체가 설계 이탈이니 사용자에게 알린다.
- **C4 — 이력은 고쳐 쓰지 않는다.** 과거 시점의 개수·순번은 이 플러그인을 셌더라도 둔다(R2).
- **C5 — 흔적의 판정 근거는 출생 원인이다.** 이름이 박혀 있다는 것만으로 흔적이 아니고, 이름이 없다는 것만으로
  흔적이 아닌 것도 아니다.
- **용어 — 「이력」의 두 쓰임을 섞지 말 것.**
  - **AC4 의 코퍼스 제외**는 순수하게 **경로 글롭**이다: `**/CHANGELOG.md` · `docs/archive/**` · `docs/audits/**` ·
    `docs/superpowers/{specs,plans,interview}/**`. 이 설계문서와 이 계획서도 이 글롭에 들어가므로 AC4 의 grep
    대상이 **아니다**(둘 다 별칭을 잔뜩 인용한다).
  - **「고쳐 쓰지 않는다」(C4)** 는 **이 제거 작업 이전부터 리포에 있던 문서**에만 적용된다. 이 설계문서와 이
    계획서는 이 작업의 산출물이라 갱신해도 이력 날조가 아니다.
- **base 와 측정값** — 이 계획은 base `b2cab469`(= `origin/main` `02c57204` 를 브랜치에 merge 한 상태)에서 실측한
  값으로 쓰였다. 설계가 쓴 base 는 `84222ee1` 이었고 그 사이 main 이 36커밋 움직였다(#158 포함). 설계
  「Verification Plan」 1 이 요구한 재측정 ①②③④ 는 **이미 끝났다** — 결과는 아래 표다.

| 재측정 | 설계 당시(`84222ee1`) | 지금(`b2cab469`) | 쓰이는 곳 |
|---|---|---|---|
| ② T7 코퍼스 수 | 31 → 제거 후 29 | **31 → 제거 후 29** (불변) | 하한 `-ge 28` |
| ③ dispatch 인쇄값 | 22 → 21 | **23 → 22** (#158 이 하나 늘림) | AC7 |
| ③ˊ agent 수 | 20 → 19 | **19 → 18** (main 이 `seed-critic` 삭제) | 인쇄 ① |
| ④ AC6 기대 ✗ 메시지 | 「27개뿐」 | **「27개뿐」** (29 − 2) | AC6 |
| ① 선재 RED | 7 파일 | **Task 1 이 새로 잰다** — 설계의 7은 참고값이다 | AC5 |

**Task 3 의 편집 블록은 버리는 복사본에서 그대로 돌려 봤다.** 열한 개 앵커 단언이 모두 맞았고, 편집을 전부
적용한 뒤 「삭제를 볼 수 있는 락 38개」가 baseline 과 **완전히 같았다**(새 실패 0). 그 상태에서
`test_dispatch_disposition.sh` 는 19/19, `test_plugin_root_no_cwd_fallback.sh` 는 27/27 이었다. 실행 중 이와
다른 것이 보이면 리포가 그 사이에 움직인 것이다 — 편집을 고치기 전에 base 부터 확인한다.

> **착수 전 확인.** Task 1 Step 1 이 `git rev-parse origin/main` 을 다시 본다. `02c57204` 가 아니면 base 가 또
> 움직인 것이므로 **위 표의 ②③④ 를 다시 재고 이 문서의 값을 고친 뒤** 진행한다. 그 재측정 명령은 Task 1 에 있다.

---

## 확정 표 (설계 D15 — 정본)

설계 §2 의 규칙 R1–R4 로 가른 결과다. 도출 절차 S1–S3 을 base `b2cab469` 에서 끝까지 돌려 확정했다 —
**설계 §2 의 T1–T9 외에 새 행은 없다.** 절차의 증거와 반증된 후보는 이 절 끝에 있다.

줄 번호는 base `b2cab469` 기준이며 Task 3 의 각 편집 단계가 **앵커 문자열로** 검증한 뒤 편집한다(줄 번호에
기대지 않는다).

| # | 파일 : 줄 | 출생(R1 근거) | 지금 | 없던 상태 |
|---|---|---|---|---|
| T1 | `docs/plugin-authoring.md` : 49–56 | `8303cc24` — 이 플러그인 PR 이 추가한 output style 절 | 삭제될 경로로 가는 링크 + 리포에 사례 없는 컴포넌트 설명 | 절 전체(도입 줄 · bullet 셋 · 「subagent 에 닿지 않는다」 단락 · 뒤 빈 줄) 삭제 |
| T2 | `docs/plugin-authoring.md` : 24 | `df47c49a` | 예시 목록이 `smoke-probe`, `transcript-reader`, `pr-understanding-builder` | `transcript-reader` 를 빼고 둘 |
| T3 | `shared/tests/test_dispatch_disposition.sh` : 85 | `8b07f9f3` — 설계 `2026-08-22-subagent-adjudication-contract-design.md:84` 의 표기 전수 조사 ④, 그 유일 실례가 이 플러그인 | `NOTATION` 의 `\|^\s*agent:\s` 갈래가 실례 0 — 아무것도 재지 않는다 | `re.compile(r'subagent_type:\|agentType:\|Agent\(')` |
| T4 | `shared/tests/test_dispatch_disposition.sh` : 142–145 | `f835f31f` | 축 A② 의 방향 근거가 삭제될 파일을 인용 | 네 줄(앞의 빈 `#` 줄 포함) 삭제. 규칙 문장은 `:137–138` 에 그대로 남는다 |
| T5 | `tools/adjudication/check_names.py` : 19 | T3 의 글자 그대로 사본 | docstring 이 `^\\s*agent:` 를 포함해 인용 | T3 와 같은 세 표기만 인용 |
| T6 | `tools/adjudication/check_slots.py` : 46 | 전수 스윕이 이 플러그인의 agent 슬롯을 분류 | `transcript-reader.inventory` bullet 이 없어진 agent·스크립트를 이름으로 가리킴 | bullet 한 줄 삭제. 같은 스윕의 `:26` 「20 개 agent」는 과거 시점의 개수라 둔다(R2) |
| T7 | `shared/tests/test_plugin_root_no_cwd_fallback.sh` : 472 | `aff6a8ee` — 코퍼스 31(이 플러그인의 `briefing-current-state/SKILL.md` · `commands/standup.md` 포함)에 여유 1 | 제거 후 29 → RED (실측 확인) | `-ge 28` — 29 에 원저자와 같은 여유 1 |
| T8 | `shared/tests/test_agent_input_slots.sh` : 86–87 · `shared/tests/fixtures/adjudication/run_slots.py` : 33–35 | 최종 리뷰 K4(`plugins/quality-gates/CHANGELOG.md:235–237`) — 「못 잼」 넷 중 `context: fork` 쪽이 이 플러그인의 `transcript-reader` 하나 | 리포에 실례 없는 갈래를 서술 | 「`context: fork`」 갈래를 걷고 「Workflow JS」만 남긴다 |
| T9 | `shared/tests/test_dispatch_disposition.sh` : 87–89 · 92 | 설계 `2026-08-22-…:350–352` — 「표기 ④는 따옴표가 없으므로 따옴표를 경계로 쓸 수 없다」 | `PRE` 가 줄머리·공백을 경계로 허용, 그 허용의 실례 0 | `PRE = r'(?:["\':])'` 로 좁히고 주석의 「줄머리·공백」 서술을 걷는다 |

**T9 의 경계 문자 집합은 실측으로 정했다**(설계가 plan 에 미룬 항목). 제거 후 남는 dispatch 22줄을 전부 읽어
보니 **이름 앞이 예외 없이 따옴표(`"` 또는 `'`) 또는 접두사 콜론(`:`)** 이다 — 공백 경계에만 기대는 줄이 없다.
좁힌 뒤 도출을 재현해 `DISPATCH 22 · ANCHORS 22 · ZERO_AGENTS 없음 · A③ 위반 없음` 으로 **잃은 줄이 0** 임을
확인했다. 축 A③ 의 이빨도 살아 있다: 경계에 `-` 를 더하는 변이를 넣으면
`plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:197` 이 `adversarial` 과 `artifact-adversarial` 둘에
귀속되어 A③ 가 발화하고 A① 도 23 ≠ 22 로 깨진다.

### S3 이 훑은 수치 하한 전수 (R3 판정)

`shared/tests` · `plugins/*/tests` · `tools` 의 하한·baseline 리터럴을 전수로 모아 가른 결과다.

| 하한 | 모집단 / 실측 | 판정 |
|---|---|---|
| `test_plugin_root_no_cwd_fallback.sh:472` `-ge 30` | 코퍼스 31 → 29 (`aff6a8ee` 핀 당시 31, 여유 1) | **흔적 = T7** |
| `test_variant_of_contract.sh:380` `-ge 19` | V4 코퍼스 22 → 21 (여유 3 → 2) | 둔다 — 붕괴 바닥. ↓「반증된 후보」참고 |
| `test_plugin_root_no_cwd_fallback.sh:491` `-ge 22` (n_a2) | 23 → **23** (이 플러그인 기여 0, 실측) | 둔다 |
| `test_plugin_root_no_cwd_fallback.sh:503` `N_GUARD_FENCE_MIN=45` | 값 불변(실측) | 둔다 |
| `test_codex_runner_no_effort_pin.sh:69` `-ge 4` | 플러그인 4, 핀이 이 플러그인 **이전**(`ecb5bf26`, 2026-08-04) | 둔다 — R1 밖. 제거 뒤 여유 0 은 가장 촘촘한 상태다 |
| `test_agent_model_unpinned_sweep.sh:32` `-ge 10` | agent 19 → 18 | 둔다 — 붕괴 바닥(여유 8) |
| `test_variant_of_contract.sh:64` `-ge 50` · `:132` `-ge 22` | 값 불변 또는 여유 충분(실측 GREEN) | 둔다 |
| `test_no_new_duplication.sh:313` `-ge 50` · `test_docreview_codex.sh:542` `-ge 50` | 값 불변(실측 GREEN) | 둔다 |
| `test_skill_body_no_positional_tokens.sh:166` `-ge 16` | 값 불변(실측 GREEN) | 둔다 |
| `test_adjudication_wiring.sh:198` `COMP_BASELINE=40` · `check_wiring.py:568` `EXEMPT_BASELINE=11` · `check_slots.py:93` `EXEMPT_SLOTS_BASELINE=5` | 값 불변(실측 GREEN) | 둔다 |
| `test_runner_adapters.sh:316` `-lt 10` | 모집단이 `git -C "$PLUGIN_ROOT" ls-files -s -- 'tests/'` 이고 `PLUGIN_ROOT` 는 `plugins/quality-gates` — **자기 플러그인의 테스트만** 센다 | 둔다 — 이 플러그인 기여가 구조적으로 0 |
| `test_governance_no_capability_caps.sh:43` `-ge 20` · `test_skill_drop_notice_consumed.sh:51,73` · spec-distill 의 줄수 하한들 | 값 불변(실측 GREEN) | 둔다 — 모집단에 이 플러그인 기여 0 |

### 도출 절차가 남긴 증거

- **S1(이름).** LIVE 전수 별칭 `git grep` 이 **14 히트**(`.claude-plugin/marketplace.json` 3 +
  `docs/plugin-authoring.md` **5**(`:24` = T2, `:49` · `:52` · `:53` · `:55` = 전부 T1 의 삭제 범위 49–56 안) +
  `shared/tests/fixtures/adjudication/run_slots.py` 1 + `shared/tests/fixtures/seamprobe/MEASUREMENT.md` 2 +
  `shared/tests/test_agent_input_slots.sh` 1 + `shared/tests/test_dispatch_disposition.sh` 1 +
  `tools/adjudication/check_slots.py` 1). `MEASUREMENT.md` 둘은 보존하는 이력 spec 을 가리키는 **경로 리터럴**이라
  AC4 의 유일한 예외다(D7). 나머지 12 는 전부 확정 표가 덮는다.
- **S2(역추적).** 이력 문서에서 이 플러그인의 식별자·경로를 근거로 든 자리를 따라가 T3 · T8 · T9 셋을 얻었다.
  이 셋은 별칭 grep 으로는 나오지 않는다 — 살아 있는 줄에 이름이 없기 때문이다.
- **S3(숫자).** 위 표. 그리고 **삭제를 원리적으로 볼 수 있는 락 38개**(`plugins/*` 를 열거하거나
  `marketplace.json` 을 읽는 것 전부 — 나머지 락은 삭제를 감지할 수단이 없다)에 대해 삭제만 적용한 버리는
  워크트리에서 전후를 돌렸다. **새 RED 은 T7 하나뿐**이고 선재 RED 은
  `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` 하나였다(전후 동일).
- **반증된 후보 1건.** `test_variant_of_contract.sh:380` 의 하한은 main 에서 `-ge 20` → `-ge 19` 로 조여졌고
  (`9781f22a`, `seed-critic` 삭제), agent 정의가 19 → 18 이 되므로 새 RED 으로 **보였다**. 실측하니 그 하한이 재는
  V4 코퍼스는 22(제거 후 21)로 `plugins/*/agents/*.md` 보다 넓어 여유가 2 남는다. **추론이 아니라 측정이 갈랐다** —
  둔다.
- **규칙이 가르지 못한 항목: 0.** 사용자 결정으로 올릴 것이 없다.

---

## AC 추적

설계의 Acceptance Criteria 가 어느 Step 에서 관측되는지. 빈 칸이 없어야 한다.

| AC | 관측 자리 |
|---|---|
| AC1 `git ls-files plugins/agent-transparency` 가 0줄 | Task 3 Step 1 · Step 12 |
| AC2 marketplace 가 파싱되고 남는 이름이 네 개 그 순서 | Task 3 Step 2 · Step 12 |
| AC3 확정 표의 모든 행이 「없던 상태」 열과 일치 | Task 3 Step 3–11 (행마다 기대 출력) |
| AC4 LIVE 에 개념 별칭 0건 (경로 리터럴 예외) | Task 3 Step 12 + **Step 12b(양성 짝)** |
| AC5 새 실패 케이스 집합 공집합 · 파일별 실패 줄 수 동일 · stub 호출 0 | Task 1 Step 4 (baseline) → Task 3 Step 14 (대조) |
| AC6 T7 하한의 양성 대조 — 「27개뿐」 ✗ 와 파서 rc 0 ✓ 를 함께 | Task 4 Step 1–3 |
| AC7 `PRINT_2_dispatch` = `PRINT_3_anchors` = (제거 전 − 1), `ZERO_AGENTS` 빈 값 | Task 3 Step 13 |
| AC8 S1–S3 을 끝까지 돌린 결과가 확정 표에 담겨 있고 증거가 있다 | 「도출 절차가 남긴 증거」(이미 확정) + Task 2 (재현·증거 보관) + Task 5 Step 2 (PR 본문) |

그리고 설계 §3 「불변인 것」 둘:

| 불변 | 관측 자리 |
|---|---|
| dispatch 락의 위치 규칙(앵커는 dispatch 줄 «아래») | Task 3 Step 7 — 「바로 아래」 문장이 남아 있음을 확인 |
| ∀ 도출(`ZERO_AGENTS`) | Task 3 Step 13 — `dispatch 0건인 에이전트가 없다` ✓ |

## Deferred to plan 의 처분

설계가 plan 에 미룬 항목 전부와, 설계 리뷰 라운드 1 이 미룬 `2e6610eb#r1.1`.

| 미뤄진 것 | 이 계획의 처분 |
|---|---|
| 커밋 type · scope, 커밋 순서 | 「커밋 계획」 — 계획서 커밋 → `chore(marketplace)!:` 한 커밋 |
| 측정 러너를 재사용할지 재구성할지 | **재구성**. job 임시 디렉토리는 사라졌다 — Task 1 Step 3 의 `runsuite.sh` 가 정본 |
| T1 삭제 뒤 빈 줄 경계의 정확한 편집 문자열 | Task 3 Step 3 — 앵커 두 줄을 단언하고 절 + 뒤 빈 줄을 지운다 |
| AC6 에서 임시로 지울 마크다운 2개 | `trivia-escape.md` · `proceed-gate.md` — 둘 다 `CLAUDE_PLUGIN_ROOT` 펜스가 0이라 `n_a2` 를 안 건드린다 |
| PR 본문에 적을 사용자 측 영향 | Task 5 Step 2 의 첫 항목 |
| AC4 예외 판정의 구현 형태 | 줄 단위 `sed` 로 경로 리터럴만 지운 뒤 재검사 (Task 3 Step 12) + 양성 짝(Step 12b) |
| T9 의 정확한 경계 문자 집합 | `PRE = r'(?:["\':])'` — 남는 dispatch 22줄 실측으로 확정. 축 A③ 은 경계 확대 변이로 이빨 확인 |
| S1–S3 의 실행 형태와 증거 보관 자리 | Task 2 가 실행 형태. 증거는 **PR 본문** — 리포에 측정 산출물을 커밋하지 않는다(D1 무게 감축) |
| 확정 표가 사는 자리와 형식 | 이 문서의 「확정 표」 절. 설계 §2 표의 다섯 열을 그대로 쓰고 T# 를 잇는다(새 행 0이라 T9 까지) |
| `2e6610eb#r1.1` (1) job 디렉토리가 없을 때의 baseline 경로 | Task 1 Step 4 가 **새 base 에서 baseline 을 다시 잰다.** 설계의 선재 RED 7은 참고값으로만 쓴다 |
| `2e6610eb#r1.1` (2) `.py`·`.mjs` 대상 선택 규칙 | Task 1 Step 3 의 `runsuite.sh` 주석에 세 정규식으로 못 박았다. 오늘 모집단 261(`.sh` 201 · `.py` 60 · `.mjs` 0) |

## File Structure

| 동작 | 파일 | 책임 |
|---|---|---|
| 삭제 | `plugins/agent-transparency/**` (추적 34 파일) | 플러그인 실체 |
| 편집 | `.claude-plugin/marketplace.json` | 카탈로그 항목 제거 (남는 순서: `quality-gates, project-init, spec-distill, plugin-audit`) |
| 편집 | `docs/plugin-authoring.md` | T1 · T2 |
| 편집 | `shared/tests/test_dispatch_disposition.sh` | T3 · T4 · T9 |
| 편집 | `shared/tests/test_plugin_root_no_cwd_fallback.sh` | T7 |
| 편집 | `shared/tests/test_agent_input_slots.sh` | T8 (셸 쪽) |
| 편집 | `shared/tests/fixtures/adjudication/run_slots.py` | T8 (픽스처 쪽) |
| 편집 | `tools/adjudication/check_names.py` | T5 |
| 편집 | `tools/adjudication/check_slots.py` | T6 |
| 추가 | `docs/superpowers/plans/2026-09-21-remove-agent-transparency.md` | 이 문서 |

**커밋 계획** (설계가 plan 에 미룬 항목):

1. 이 계획서 — `docs(plan): agent-transparency 제거 구현 계획` (이미 있는 설계 커밋 뒤)
2. 본 작업 한 커밋 — `chore(marketplace)!: agent-transparency 제거 — 애초에 없던 상태로`
   (`!` 는 마켓플레이스에서 플러그인이 사라지는 breaking change 를 뜻한다. `chore(docreview)!:` 선례가 있다.)

---

## Task 1: 착수 확인과 baseline 포착

**Files:**
- Create: `$WORK/baseline.tsv`, `$WORK/baseline.d/` (측정 산출물 — 리포 밖)
- Read: `.claude-plugin/marketplace.json`, `shared/tests/**`

**Interfaces:**
- Produces: `$WORK/baseline.tsv` (`파일<TAB>rc<TAB>실패줄수` 한 줄씩), `$WORK/expect.txt`(제거 전 인쇄값).
  Task 3 이 같은 러너를 다시 돌려 이 파일과 대조한다.
- Produces: `$WORK/runsuite.sh` — Task 3 이 재사용하는 러너.

> `$WORK` 는 리포 **밖**의 작업 디렉토리다. 세션의 job 임시 디렉토리를 쓰고, 없으면
> `mkdir -p ~/at-removal-work` 를 쓴다. 측정 산출물을 리포에 커밋하지 않는다(D1 — 무게 감축).

- [ ] **Step 1: base 가 계획 작성 시점과 같은지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git fetch origin main --quiet
echo "origin/main = $(git rev-parse origin/main)   (기대: 02c57204...)"
echo "HEAD        = $(git rev-parse HEAD)"
git rev-list --count HEAD..origin/main
```

기대: 마지막 줄이 `0`. **`0` 이 아니면** main 이 또 움직였다 — `git merge origin/main` 으로 따라잡은 뒤
Step 2 의 세 값(②③④)을 다시 재고, 이 계획서의 「base 와 측정값」 표와 아래 기대값을 고친 다음 계속한다.
이 재측정을 건너뛰면 AC5·AC7 의 기대값이 조용히 틀린다.

- [ ] **Step 2: 제거 전 인쇄값·코퍼스 수를 기록**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"; mkdir -p "$WORK"
{
  echo "base=$(git rev-parse HEAD)"
  echo -n "corpus_before="
  git ls-files --cached --others --exclude-standard -- \
    'plugins/*/skills/*.md' 'plugins/*/commands/*.md' 'plugins/*/references/*.md' | wc -l
  bash shared/tests/test_dispatch_disposition.sh 2>&1 | grep -E '에이전트 [0-9]+개 도출|dispatch 줄 [0-9]+건 도출'
} | tee "$WORK/expect.txt"
```

기대 출력:
```
corpus_before=31
  ✓ 에이전트 19개 도출
  ✓ dispatch 줄 23건 도출
```

이 세 수에서 파생값을 계산해 적어 둔다 — **제거 후 기대값**: 코퍼스 `31 − 2 = 29`, T7 하한 `29 − 1 = 28`,
AC7 인쇄값 `23 − 1 = 22`, AC6 기대 ✗ 메시지 `29 − 2 = 27` → 「27개뿐」.

- [ ] **Step 3: 스위트 러너를 만든다**

설계 리뷰 라운드 1(`2e6610eb#r1.1`)이 요구한 **대상 선택 규칙**을 여기서 못 박는다. 측정 당시의 job 임시
디렉토리는 사라졌으므로 러너는 재구성한다.

```bash
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"; mkdir -p "$WORK"
cat > "$WORK/runsuite.sh" <<'RUNNER'
#!/bin/bash
# 사용: runsuite.sh <tree-root> <out.tsv>
# 출력 한 줄: <경로>\t<rc>\t<실패줄수>
ROOT="$1"; OUT="$2"
mkdir -p "${OUT}.d"
STUB="$(mktemp -d)"
export STUB_LOG="${OUT}.stubcalls"; : > "$STUB_LOG"
for c in claude codex; do
  printf '#!/bin/sh\necho "STUB_CALL %s $*" >> "$STUB_LOG"\nexit 97\n' "$c" > "$STUB/$c"
  chmod +x "$STUB/$c"
done
export PATH="$STUB:$PATH"
export PYTHONDONTWRITEBYTECODE=1
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
cd "$ROOT" || exit 2

# 대상 선택 규칙 (전수 · 이름 열거 아님)
#   .sh  : ^(shared/tests|plugins/[^/]+/tests)/(harness/)?test_[^/]*\.sh$
#   .py  : ^(shared/tests|plugins/[^/]+/tests)/test_[^/]*\.py$
#   .mjs : ^(shared/tests|plugins/[^/]+/tests)/test_[^/]*\.mjs$   (오늘 0개)
# 제외  : plugins/quality-gates/tests/spike/test_codex_json_extraction.sh (추적 픽스처를 바꾸는 수동 spike)
LIST="$(git ls-files \
  | grep -E '^(shared/tests|plugins/[^/]+/tests)/(harness/)?test_[^/]*\.(sh|py|mjs)$' \
  | grep -v '^plugins/quality-gates/tests/spike/' | LC_ALL=C sort)"

: > "$OUT"
for t in $LIST; do
  TD="$(mktemp -d)"
  case "$t" in
    *.py)
      d="$(dirname "$t")"; b="$(basename "$t")"
      log="$(TMPDIR="$TD" python3 -m unittest discover -v -s "$d" -t "$d" -p "$b" 2>&1 < /dev/null)"
      rc=$?; n="$(printf '%s\n' "$log" | grep -cE '^(FAIL|ERROR): ')" ;;
    *.mjs)
      log="$(TMPDIR="$TD" node --test --test-reporter=tap "$t" 2>&1 < /dev/null)"
      rc=$?; n="$(printf '%s\n' "$log" | grep -cE '^not ok [0-9]+ -')" ;;
    *)
      # `✗` 는 **줄머리에 앵커한다.** 리포의 assert 라이브러리 계약은 실패 줄의 접두가 `  ✗ ` 라는
      # 것이고(shared/tests/test_assert_behavior.sh 가 그 계약을 단언한다), 앵커 없이 세면 그 계약을
      # «설명하는 통과 줄»까지 실패로 센다 — 실측: test_assert_behavior.sh 는 32/32 GREEN 인데 1로 세진다.
      log="$(TMPDIR="$TD" bash "$t" 2>&1 < /dev/null)"
      rc=$?; n="$(printf '%s\n' "$log" | grep -cE '^[[:space:]]*✗ |^[[:space:]]*FAIL\b|^[[:space:]]*not ok\b')" ;;
  esac
  printf '%s\t%s\t%s\n' "$t" "$rc" "$n" >> "$OUT"
  printf '%s\n' "$log" > "${OUT}.d/$(printf '%s' "$t" | tr '/' '_').log"
  rm -rf "$TD"
done
rm -rf "$STUB"
echo "대상 $(wc -l < "$OUT") 개 · stub 호출 $(wc -l < "$STUB_LOG") 회"
RUNNER
chmod +x "$WORK/runsuite.sh"
```

- [ ] **Step 4: baseline 을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
bash "$WORK/runsuite.sh" "$(pwd)" "$WORK/baseline.tsv"
echo "-- 선재 RED --"
awk -F'\t' '$2!=0 || $3!=0 {printf "%-72s rc=%s fail=%s\n",$1,$2,$3}' "$WORK/baseline.tsv"
```

기대: 대상 **261 개**, stub 호출 **0 회**. 선재 RED 목록이 나오면 그대로 받아들인다 — 이것이 AC5 의 비교
기준이다. **실패 「줄 수」까지 기록하는 이유**는 이미 RED 인 파일 안의 새 실패가 rc 만으로는 보이지 않기
때문이다.

> **설계의 「선재 RED 7 파일」은 여섯이다.** 설계 VP1 이 일곱 번째로 적은
> `shared/tests/test_assert_behavior.sh(rc 0, 의도된 ✗)` 는 애초에 실패가 아니다 — 32/32 GREEN 이고, 그
> `✗` 는 실패 줄 접두 계약을 **설명하는 통과 줄** 안에 있다. 앵커 없이 세던 옛 패턴이 그것을 실패로
> 셌을 뿐이다. 위 러너의 앵커된 패턴에서는 `rc=0 fail=0` 으로 나온다. 이 파일이 목록에 보이면 러너가
> 옛 패턴을 쓰고 있는 것이다.

- [ ] **Step 5: 커밋 없음 — 산출물 확인만**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git status --short   # 비어 있어야 한다. 측정은 리포를 건드리지 않는다.
```

---

## Task 2: 도출 절차 S1–S3 재현 (AC8)

이 Task 는 「확정 표」를 **검증**한다. 표는 이미 확정돼 있고(이 문서가 정본), 여기서는 절차를 기계적으로 다시
돌려 **새 행이 0 임을 보이고 그 출력을 증거로 보관**한다. 새 행이 나오면 멈추고 R1–R4 로 분류해 표에 추가하며,
규칙이 가르지 못하면 사용자에게 올린다.

**Files:**
- Create: `$WORK/sweep-evidence.txt` (Task 5 가 PR 본문에 붙인다)
- Read: 리포 전체

**Interfaces:**
- Consumes: Task 1 의 `$WORK`
- Produces: `$WORK/sweep-evidence.txt`

- [ ] **Step 1: S1 — 별칭 전수 grep**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
ALIAS='agent-transparency|agent_transparency|transcript-reader|briefing-current-state|prepare_standup|standup|ab_gate|ab_judge|ab_seal|ab_driver|AT_ORACLE|comprehension.debt|이해부채|output-styles|output style|force-for-plugin|keep-coding-instructions|context: fork'
{
  echo "=== S1 (제거 전, LIVE) ==="
  git grep -n -I -i -E "$ALIAS" -- . \
    ':(exclude)plugins/agent-transparency/**' \
    ':(exclude)**/CHANGELOG.md' ':(exclude)docs/archive/**' ':(exclude)docs/audits/**' \
    ':(exclude)docs/superpowers/specs/**' ':(exclude)docs/superpowers/plans/**' \
    ':(exclude)docs/superpowers/interview/**'
} | tee "$WORK/sweep-evidence.txt"
```

기대: 정확히 **14 줄**. 파일별로 `marketplace.json` 3 · `plugin-authoring.md` **5** · `run_slots.py` 1 ·
`MEASUREMENT.md` 2 · `test_agent_input_slots.sh` 1 · `test_dispatch_disposition.sh` 1 · `check_slots.py` 1.
`MEASUREMENT.md` 둘을 뺀 12 가 확정 표에 대응한다. **14 가 아니면** 표에 없는 자리가 생긴 것이니 멈추고
분류한다 — 수가 아니라 **파일별 분포**로 판단한다. `plugin-authoring.md` 의 다섯 중 넷(`:49` · `:52` · `:53` ·
`:55`)은 T1 이 절째로 지우는 범위 안이고 하나(`:24`)가 T2 다.

- [ ] **Step 2: S2 — 이력 역추적**

살아 있는 줄에 이름이 없는 흔적은 이 경로로만 나온다. 이력 문서에서 이 플러그인의 식별자·경로를 **근거로 든**
자리를 찾고, 그 근거가 떠받치는 live 파일의 줄을 확인한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
{
  echo; echo "=== S2 (이력 문서 히트) ==="
  git grep -n -I -i -E 'agent-transparency|transcript-reader|briefing-current-state|context: fork|output style' -- \
    '**/CHANGELOG.md' 'docs/archive/**' 'docs/audits/**' 'docs/superpowers/specs/**' 'docs/superpowers/plans/**' \
    | grep -viE '2026-09-2[01]-remove-agent-transparency' \
    | awk -F: '{print $1}' | sort | uniq -c | sort -rn
} | tee -a "$WORK/sweep-evidence.txt"
```

각 파일에 대해 **그 인용이 살아 있는 줄을 떠받치는지** 판단한다. 이미 판정된 셋은 아래와 같고, 새 파일이
나오면 같은 방식으로 따라간다.

| 이력 근거 | 떠받치는 live 줄 | 판정 |
|---|---|---|
| `docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md:84` (표기 전수 조사 ④) | `test_dispatch_disposition.sh:85` | **T3** |
| 같은 문서 `:350–352` (「표기 ④는 따옴표가 없다」) | `test_dispatch_disposition.sh:87–92` | **T9** |
| `plugins/quality-gates/CHANGELOG.md:235–237` (최종 리뷰 K4) | `test_agent_input_slots.sh:86` · `run_slots.py:33` | **T8** |
| `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` | `shared/tests/fixtures/seamprobe/MEASUREMENT.md:22` · `:178` | 흔적 아님 — 보존하는 이력 spec 을 가리키는 경로 인용(D7) |

- [ ] **Step 3: S3 — 수치 하한 전수**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
{
  echo; echo "=== S3 (하한·baseline 리터럴 전수) ==="
  git grep -nE '\-(ge|gt|lt|le) [0-9]{2,}|BASELINE *= *[0-9]+|_MIN *= *[0-9]+|>= *[0-9]{2,}' -- \
    'shared/tests/*' 'plugins/*/tests/*' 'tools/*' | grep -vE '^\S+:[0-9]+:[[:space:]]*#'
} | tee -a "$WORK/sweep-evidence.txt"
```

기대: 이 계획서 「S3 이 훑은 수치 하한 전수」 표의 자리와 일치. **표에 없는 하한이 나오면** R3 으로 가른다 —
그 하한의 모집단에 이 플러그인 파일이 들어가는지 **실측으로** 확인하고(추론 금지: 반증된 후보 참고),
핀 당시 수 − 1 이면 흔적, 여유를 둔 붕괴 바닥이면 둔다.

- [ ] **Step 4: 절차가 끝났음을 기록**

```bash
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
{ echo; echo "=== 판정 ==="; echo "확정 표 밖 새 행: 0 (또는 발견 시 여기에 열거)"; } >> "$WORK/sweep-evidence.txt"
wc -l "$WORK/sweep-evidence.txt"
```

- [ ] **Step 5: 커밋 없음** — 리포는 그대로다. `git status --short` 가 비어 있음을 확인한다.

---

## Task 3: 삭제와 흔적 정리 (한 커밋)

C2 때문에 이 Task 가 크다. 편집은 전부 **앵커 문자열 검증 → 치환 → 재검증** 형태로 한다. 줄 번호에 기대는
편집은 쓰지 않는다 — 앞 편집이 뒤 편집의 줄 번호를 민다.

**Files:**
- Delete: `plugins/agent-transparency/**` (34)
- Modify: `.claude-plugin/marketplace.json`, `docs/plugin-authoring.md`,
  `shared/tests/test_dispatch_disposition.sh`, `shared/tests/test_plugin_root_no_cwd_fallback.sh`,
  `shared/tests/test_agent_input_slots.sh`, `shared/tests/fixtures/adjudication/run_slots.py`,
  `tools/adjudication/check_names.py`, `tools/adjudication/check_slots.py`

**Interfaces:**
- Consumes: Task 1 의 `$WORK/baseline.tsv` · `$WORK/runsuite.sh` · `$WORK/expect.txt`
- Produces: 커밋 하나. Task 4 는 이 커밋 위에서만 의미가 있다.

- [ ] **Step 1: 플러그인 디렉토리 삭제**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git ls-files plugins/agent-transparency | wc -l    # 기대: 34
git rm -r -q plugins/agent-transparency
git ls-files plugins/agent-transparency | wc -l    # 기대: 0  (AC1)
ls plugins/                                         # 기대: plugin-audit project-init quality-gates spec-distill
```

- [ ] **Step 2: 마켓플레이스 항목 삭제**

객체와 **앞 객체 뒤의 쉼표**를 함께 지운다. JSON 전체를 `json.dumps` 로 다시 쓰면 다른 항목의 서식까지
바뀌므로 하지 않는다 — 텍스트 수술이다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io, json
p = ".claude-plugin/marketplace.json"
s = io.open(p, encoding="utf-8").read()
block = '''    },
    {
      "name": "agent-transparency",
      "description": "Reduces comprehension debt — surfaces what delegated agents did and what your judgment rests on, at decision and verdict points",
      "source": "./plugins/agent-transparency",
      "category": "development"
    }
'''
assert s.count(block) == 1, "앵커 블록을 정확히 하나 찾지 못했다 — 파일이 바뀌었다"
s = s.replace(block, '    }\n')
io.open(p, "w", encoding="utf-8").write(s)
d = json.loads(io.open(p, encoding="utf-8").read())
print([x["name"] for x in d["plugins"]])
PY
```

기대 출력: `['quality-gates', 'project-init', 'spec-distill', 'plugin-audit']` (AC2)

- [ ] **Step 3: T1 — `docs/plugin-authoring.md` 의 output style 절 삭제**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "docs/plugin-authoring.md"
lines = io.open(p, encoding="utf-8").read().split("\n")
start = next(i for i, t in enumerate(lines) if t.startswith("**output style 컴포넌트**"))
end   = next(i for i, t in enumerate(lines) if t.startswith("**output style 은 subagent 에 닿지 않는다.**"))
assert lines[end + 1] == "", "절 뒤가 빈 줄이 아니다"
assert lines[end + 2].startswith("**Merge 전:**"), "절 뒤 단락이 기대와 다르다"
assert lines[start - 1] == "", "절 앞이 빈 줄이 아니다"
del lines[start:end + 2]          # 절 본문 + 뒤 빈 줄
io.open(p, "w", encoding="utf-8").write("\n".join(lines))
print(repr(lines[start - 2:start + 1]))
PY
```

기대 출력의 마지막 원소가 `**Merge 전:** ...` 로 시작하고, 그 앞이 빈 줄 하나다.

- [ ] **Step 4: T2 — 예시 목록에서 `transcript-reader` 제거**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "docs/plugin-authoring.md"
s = io.open(p, encoding="utf-8").read()
old = "(예: `smoke-probe`, `transcript-reader`, `pr-understanding-builder`)"
new = "(예: `smoke-probe`, `pr-understanding-builder`)"
assert s.count(old) == 1, "앵커를 정확히 하나 찾지 못했다"
io.open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
echo "잔존: $(grep -cE 'transcript-reader|output style|output-styles|force-for-plugin|keep-coding-instructions' docs/plugin-authoring.md || true)"
```

기대: `잔존: 0` (AC3 T1·T2)

> `grep -c` 는 0건일 때 **rc 1** 을 낸다. `$( … || true )` 로 감싸지 않으면 `set -e` 아래서 여기가 성공인데
> 중단된다. 아래 확인 줄들도 같은 이유로 같은 모양이다.

- [ ] **Step 5: T3 — `NOTATION` 에서 `agent:` 갈래 제거**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "shared/tests/test_dispatch_disposition.sh"
s = io.open(p, encoding="utf-8").read()
old = r"""NOTATION = re.compile(r'subagent_type:|agentType:|Agent\(|^\s*agent:\s')"""
new = r"""NOTATION = re.compile(r'subagent_type:|agentType:|Agent\(')"""
assert s.count(old) == 1, "NOTATION 앵커를 정확히 하나 찾지 못했다"
io.open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
grep -n 'NOTATION = re.compile' shared/tests/test_dispatch_disposition.sh
```

기대: `NOTATION = re.compile(r'subagent_type:|agentType:|Agent\(')` (AC3 T3)

- [ ] **Step 6: T9 — 이름 경계를 따옴표·콜론으로 좁힌다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "shared/tests/test_dispatch_disposition.sh"
s = io.open(p, encoding="utf-8").read()

old_c = """# 경계 규칙: 이름 앞은 줄머리·공백·따옴표·`:` 중 하나, 뒤는 따옴표·공백·
# 쉼표·닫는괄호·줄끝 중 하나. `-` 는 경계가 아니다 — 그래야
"""
new_c = """# 경계 규칙: 이름 앞은 따옴표·`:` 중 하나, 뒤는 따옴표·공백·쉼표·
# 닫는괄호·줄끝 중 하나. `-` 는 경계가 아니다 — 그래야
"""
assert s.count(old_c) == 1, "경계 주석 앵커 실패"
s = s.replace(old_c, new_c)

old_p = """PRE, POST = r'(?:^|[\\s"\\':])', r'(?=["\\'\\s,)]|$)'"""
new_p = """PRE, POST = r'(?:["\\':])', r'(?=["\\'\\s,)]|$)'"""
assert s.count(old_p) == 1, "PRE/POST 앵커 실패"
s = s.replace(old_p, new_p)

io.open(p, "w", encoding="utf-8").write(s)
PY
sed -n '/^# 경계 규칙/,/^PRE, POST/p' shared/tests/test_dispatch_disposition.sh
```

기대: 주석에 「줄머리·공백」이 없고 `PRE, POST = r'(?:["\':])', r'(?=["\'\s,)]|$)'` (AC3 T9)

- [ ] **Step 7: T4 — 축 A② 의 「아래」 근거 문단 삭제**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "shared/tests/test_dispatch_disposition.sh"
s = io.open(p, encoding="utf-8").read()
old = """#
#    방향이 「아래」인 이유: briefing-current-state/SKILL.md 의 dispatch 는
#    frontmatter 안 6행이고 `---` 닫힘이 9행이라 «위»에는 아무것도 놓을 수 없다.
#    「위」로 쓰면 그 파일이 배달 즉시 RED 다.
"""
assert s.count(old) == 1, "근거 문단 앵커 실패"
io.open(p, "w", encoding="utf-8").write(s.replace(old, ""))
PY
echo "잔존: $(grep -c 'briefing-current-state' shared/tests/test_dispatch_disposition.sh || true)"
grep -n '바로 아래' shared/tests/test_dispatch_disposition.sh
```

기대: `잔존: 0`, 그리고 축 A② 의 「**바로 아래**」 규칙 문장은 **남아 있다** (AC3 T4)

- [ ] **Step 8: T7 — 코퍼스 하한을 28 로**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "shared/tests/test_plugin_root_no_cwd_fallback.sh"
s = io.open(p, encoding="utf-8").read()
old = '[ "${n_corpus:-0}" -ge 30 ]'
new = '[ "${n_corpus:-0}" -ge 28 ]'
assert s.count(old) == 1, "하한 앵커 실패"
io.open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
grep -n 'n_corpus:-0.*-ge' shared/tests/test_plugin_root_no_cwd_fallback.sh
```

기대: `-ge 28` (AC3 T7). **Step 1 에서 이미 플러그인을 지웠으므로** 코퍼스는 29다 — 원저자와 같은 여유 1.

- [ ] **Step 9: T5 — `check_names.py` docstring 의 표기 인용 정정**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "tools/adjudication/check_names.py"
s = io.open(p, encoding="utf-8").read()
old = r"기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\(|^\\s*agent:)를"
new = r"기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\()를"
assert s.count(old) == 1, "docstring 앵커 실패"
io.open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
grep -n '기존 dispatch 락의 표기 필터' tools/adjudication/check_names.py
```

기대: `19:기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\()를`
— 한 줄에 두 사실이 같이 보인다: `agent:` 표기 인용이 사라졌고, 나머지 세 표기 인용은 남아 있다 (AC3 T5).

- [ ] **Step 10: T6 — `check_slots.py` 의 죽은 bullet 삭제**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io
p = "tools/adjudication/check_slots.py"
s = io.open(p, encoding="utf-8").read()
old = "#   · `transcript-reader.inventory` — `prepare_standup.py` 출력 → ⓐ.\n"
assert s.count(old) == 1, "bullet 앵커 실패"
io.open(p, "w", encoding="utf-8").write(s.replace(old, ""))
PY
echo "잔존: $(grep -cE 'transcript-reader|prepare_standup' tools/adjudication/check_slots.py || true)"
grep -n '20 개 agent' tools/adjudication/check_slots.py
```

기대: `잔존: 0`, 그리고 둘째 줄이 「20 개 agent」를 **그대로** 보여준다 — 과거 시점의 개수는 이력이다(R2, AC3 T6)

- [ ] **Step 11: T8 — `context: fork` 갈래를 두 자리에서 걷는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
python3 - <<'PY'
import io

p1 = "shared/tests/test_agent_input_slots.sh"
s = io.open(p1, encoding="utf-8").read()
old = """# 대조된 수로 읽힌다 — 실제로는 dispatch 가 Workflow JS 나 `context: fork` 에
# 있는 agent 가 `.md` 코퍼스에 안 보여 선언·전달 대조가 «없다». 셀 수 없으면
"""
new = """# 대조된 수로 읽힌다 — 실제로는 dispatch 가 Workflow JS 에 있는 agent 가
# `.md` 코퍼스에 안 보여 선언·전달 대조가 «없다». 셀 수 없으면
"""
assert s.count(old) == 1, "셸 주석 앵커 실패"
io.open(p1, "w", encoding="utf-8").write(s.replace(old, new))

p2 = "shared/tests/fixtures/adjudication/run_slots.py"
s = io.open(p2, encoding="utf-8").read()
old = """# dispatch 자리가 Workflow JS(`agent(prompt, {agentType})`)나 skill frontmatter
# 의 `context: fork` 에 있는 agent 는 `.md` dispatch 코퍼스에 «구조적으로»
# 안 보인다 — 그 agent 에서는 선언과 전달을 대조할 대상이 애초에 없다.
"""
new = """# dispatch 자리가 Workflow JS(`agent(prompt, {agentType})`)에 있는 agent 는
# `.md` dispatch 코퍼스에 «구조적으로» 안 보인다 — 그 agent 에서는 선언과
# 전달을 대조할 대상이 애초에 없다.
"""
assert s.count(old) == 1, "픽스처 주석 앵커 실패"
io.open(p2, "w", encoding="utf-8").write(s.replace(old, new))
PY
echo "잔존: $(grep -c 'context: fork' shared/tests/test_agent_input_slots.sh shared/tests/fixtures/adjudication/run_slots.py | tr '\n' ' ' || true)"
grep -n 'Workflow JS' shared/tests/test_agent_input_slots.sh shared/tests/fixtures/adjudication/run_slots.py
```

기대: `잔존: …test_agent_input_slots.sh:0 …run_slots.py:0`, 그리고 「Workflow JS」 서술은 두 파일에 남아 있다 (AC3 T8)

- [ ] **Step 12: 정적 확인 — AC1 · AC2 · AC4**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
echo "-- AC1 --"; git ls-files plugins/agent-transparency | wc -l
echo "-- AC2 --"; python3 -c "import json,io;print([x['name'] for x in json.load(io.open('.claude-plugin/marketplace.json',encoding='utf-8'))['plugins']])"
echo "-- AC4 --"
ALIAS='agent-transparency|agent_transparency|transcript-reader|briefing-current-state|prepare_standup|standup|ab_gate|ab_judge|ab_seal|ab_driver|AT_ORACLE|comprehension.debt|이해부채|output-styles|output style|force-for-plugin|keep-coding-instructions|context: fork'
git grep -n -I -i -E "$ALIAS" -- . \
  ':(exclude)**/CHANGELOG.md' ':(exclude)docs/archive/**' ':(exclude)docs/audits/**' \
  ':(exclude)docs/superpowers/specs/**' ':(exclude)docs/superpowers/plans/**' \
  ':(exclude)docs/superpowers/interview/**' \
| sed 's|docs/superpowers/specs/2026-08-05-agent-transparency-design\.md||g' \
| grep -iE "$ALIAS" || echo "AC4 통과 — LIVE 에 별칭 0건"
```

기대: AC1 = `0`, AC2 = 네 이름 그 순서, AC4 = `AC4 통과 — LIVE 에 별칭 0건`.

> **AC4 예외의 구현**(설계가 plan 에 미룬 항목): 파일을 통째로 빼지 않고 **줄 단위로 경로 리터럴만 지운 뒤**
> 다시 별칭을 찾는다. 위 `sed` 가 그 한 줄이다. 그래서 `MEASUREMENT.md` 에 나중에 생기는 **다른** 언급은
> 여전히 걸린다.

- [ ] **Step 12b: AC4 예외의 양성 짝 — 「0건」이 눈먼 것이 아님을 보인다**

부재 단언은 통째로 눈이 멀어도 통과한다. 예외가 파일 전체를 가려 버리지 않았는지 한 번 흔든다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
printf '\n임시: transcript-reader 를 새로 언급한다.\n' >> shared/tests/fixtures/seamprobe/MEASUREMENT.md
ALIAS='agent-transparency|agent_transparency|transcript-reader|briefing-current-state|prepare_standup|standup|ab_gate|ab_judge|ab_seal|ab_driver|AT_ORACLE|comprehension.debt|이해부채|output-styles|output style|force-for-plugin|keep-coding-instructions|context: fork'
git grep -n -I -i -E "$ALIAS" -- . \
  ':(exclude)**/CHANGELOG.md' ':(exclude)docs/archive/**' ':(exclude)docs/audits/**' \
  ':(exclude)docs/superpowers/specs/**' ':(exclude)docs/superpowers/plans/**' \
  ':(exclude)docs/superpowers/interview/**' \
| sed 's|docs/superpowers/specs/2026-08-05-agent-transparency-design\.md||g' \
| grep -iE "$ALIAS" || echo "***실패*** — 예외가 파일 전체를 가리고 있다"
git checkout -- shared/tests/fixtures/seamprobe/MEASUREMENT.md
git status --short shared/tests/fixtures/seamprobe/MEASUREMENT.md   # 비어 있어야 한다
```

기대: `MEASUREMENT.md:<끝줄>:임시: transcript-reader 를 새로 언급한다.` 한 줄이 **잡힌다**.
`***실패***` 가 보이면 예외가 너무 넓은 것이다 — 고치기 전에는 AC4 의 「0건」이 증거가 아니다.
**복원을 빠뜨리지 말 것.**

- [ ] **Step 13: 도출 확인 — AC7**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -25
```

기대: `에이전트 18개 도출` · `dispatch 줄 22건 도출` · `축 A① 앵커 수(22) == dispatch 수(22)` ·
`dispatch 0건인 에이전트가 없다` ✓ · `Fail: 0`.
`22` 는 Task 1 Step 2 가 기록한 제거 전 값 `23` 에서 정확히 1 을 뺀 수다 — **T3 · T9 가 이 플러그인 밖의
dispatch 를 하나도 잃지 않았다는 증거**다(AC7). 22 보다 작으면 T9 의 경계가 너무 좁다.

- [ ] **Step 14: 스위트 전후 대조 — AC5**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
bash "$WORK/runsuite.sh" "$(pwd)" "$WORK/after.tsv"
echo "-- 사라진 대상 (기대: agent-transparency 의 테스트 5개뿐) --"
comm -23 <(cut -f1 "$WORK/baseline.tsv" | sort) <(cut -f1 "$WORK/after.tsv" | sort)
echo "-- 새로 생긴 대상 (기대: 없음) --"
comm -13 <(cut -f1 "$WORK/baseline.tsv" | sort) <(cut -f1 "$WORK/after.tsv" | sort)
echo "-- 양쪽에 있는 대상 중 전후가 다른 것 (기대: 없음) --"
join -t$'\t' -j1 <(sort "$WORK/baseline.tsv") <(sort "$WORK/after.tsv") \
  | awk -F'\t' '$2!=$4 || $3!=$5 {printf "%-72s before rc=%s fail=%s -> after rc=%s fail=%s\n",$1,$2,$3,$4,$5}'
echo "-- stub 호출 (기대: 0) --"; wc -l < "$WORK/after.tsv.stubcalls"
```

기대:
- 사라진 대상 = 정확히 이 다섯: `plugins/agent-transparency/tests/test_ab_runner_contract.py` ·
  `test_output_style.py` · `test_plugin_contract.py` · `test_prepare_standup.py` · `test_readability_parity.py`
- 새로 생긴 대상 = 없음
- **전후가 다른 것 = 없음** ← 이것이 AC5 의 본체다. rc 뿐 아니라 **실패 줄 수**까지 같아야 한다
- stub 호출 = `0`

> 삭제된 다섯은 「새 실패」가 아니라 「부재」다. 그래서 비교는 **양쪽에 있는 대상의 교집합**에서 한다.
> 하나라도 차이가 나면 커밋하지 말고 원인을 잡는다.

- [ ] **Step 15: 커밋**

커밋 메시지는 **파일로 건넨다**. `git commit -m "$(cat <<'MSG' … MSG)"` 형태는 본문에 백틱·괄호가 섞이면
`$( )` 안의 heredoc 파싱이 깨진다(리포 실측 교훈).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
cat > "$WORK/commit-msg.txt" <<'MSG'
chore(marketplace)!: agent-transparency 제거 — 애초에 없던 상태로

플러그인 디렉토리(34 파일)와 마켓플레이스 항목을 지우고, 이 플러그인 때문에
리포의 다른 곳에 생긴 줄을 같은 커밋에서 되돌린다. 중간 상태가 RED 이라
쪼갤 수 없다 — 표기 갈래만 먼저 지우면 축 A① 가 깨지고, 플러그인만 먼저
지우면 코퍼스 하한이 깨진다.

되돌린 흔적:
- docs/plugin-authoring.md — output style 절(리포 유일 사례였다) · model 재량
  예시 목록의 항목 하나
- test_dispatch_disposition.sh — NOTATION 의 frontmatter `agent:` 갈래(실례
  0이 된다) · 그 표기를 위해 넓혀 둔 이름 경계 · 축 A② 방향 근거 문단
- test_plugin_root_no_cwd_fallback.sh — 코퍼스 하한 30 → 28 (원저자와 같은
  여유 1: 코퍼스 29)
- check_names.py · check_slots.py — 표기 필터 인용, 없어진 슬롯 bullet
- test_agent_input_slots.sh · run_slots.py — 실례가 사라진 `context: fork` 갈래

과거 시점의 개수·순번 서술과 이력 문서는 그대로 둔다. 남는 플러그인의 파일은
하나도 편집하지 않으므로 버전 bump 는 없다.

BREAKING CHANGE: 마켓플레이스를 갱신한 설치자에게서 agent-transparency 와
그 force-for-plugin output style 이 사라진다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
git add -A .claude-plugin docs/plugin-authoring.md shared tools plugins
git status --short
git commit -F "$WORK/commit-msg.txt"
git status --short   # 비어 있어야 한다
```

---

## Task 4: T7 하한의 양성 대조 (AC6)

하한을 28 로 바꾼 것이 **실제로 무언가를 재는지** 확인한다. 통과가 정답인 단언은 모양만으로 이빨을 알 수 없다.

**Files:**
- 임시 삭제 후 복원: `plugins/spec-distill/references/trivia-escape.md`,
  `plugins/spec-distill/references/proceed-gate.md`

**Interfaces:**
- Consumes: Task 3 의 커밋 (복원이 `git checkout HEAD --` 로 되므로 커밋 뒤에만 안전하다)
- Produces: 대조 로그 (Task 5 가 PR 본문에 요약)

> **두 파일을 고른 이유**: 둘 다 T7 코퍼스 글롭 안에 있고 `CLAUDE_PLUGIN_ROOT` 펜스가 **0 개**라, 지워도
> 같은 락의 다른 단언(`n_a2 -ge 22`, 현재 23)을 건드리지 않는다. 대조가 재려는 하나만 움직인다.

- [ ] **Step 1: 코퍼스에서 둘을 지운다 — index 와 작업 트리 둘 다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git rm -q plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/references/proceed-gate.md
git ls-files --cached --others --exclude-standard -- \
  'plugins/*/skills/*.md' 'plugins/*/commands/*.md' 'plugins/*/references/*.md' | wc -l
```

기대: `27`.

> **반쪽 삭제는 아무것도 재지 않는다.** 락의 코퍼스는
> `git ls-files --cached --others --exclude-standard` 다(`test_plugin_root_no_cwd_fallback.sh:130–131`).
> 작업 트리에서만 지우면 경로가 `--cached` 로 계속 나와 파서가 없는 파일을 열다 죽고, 그 ✗ 는 하한이 아니라
> 「0개뿐」이 된다. `git rm --cached` 만 하면 파일이 untracked 가 되어 `--others` 로 되돌아와 수가 29 로
> 남고 ✗ 자체가 발화하지 않는다. 그래서 `git rm`(둘 다)이다.

- [ ] **Step 2: 락을 돌려 두 관측을 함께 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -E '파서가 끝까지 돌았다|대상 마크다운'
```

기대 — **둘이 함께** 나와야 한다:
```
  ✓ 파서가 끝까지 돌았다 (rc 0)
  ✗ 대상 마크다운이 27개뿐 — 도출이 무너졌다(글롭 · 경로 변경?)
```

`파서가 끝까지 돌았다` 가 ✗ 이면 대조가 **하한이 아니라 파서 사망을 잰 것**이다 — 실패로 보고 원인을 잡는다.
`27개뿐` 이 아닌 다른 수면 코퍼스 계산이 기대와 다르다.

- [ ] **Step 3: 복원하고 트리가 깨끗한지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git checkout HEAD -- plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/references/proceed-gate.md
git diff HEAD --stat; git diff --cached --stat; git status --short
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -E '대상 마크다운'
```

기대: 세 git 명령이 **전부 빈 출력**, 그리고 `✓ 대상 마크다운 29개 — vacuous 아님`.

- [ ] **Step 4: 커밋 없음** — 이 Task 는 리포를 바꾸지 않는다.

---

## Task 5: 구현 리뷰와 PR

**Files:**
- Create: PR (GitHub)

**Interfaces:**
- Consumes: Task 2 의 `$WORK/sweep-evidence.txt`, Task 3 의 커밋, Task 4 의 대조 로그

- [ ] **Step 1: `/qg review` 를 한 번 돌린다 (Law 2 — 쓴 턴이 승인하지 않는다)**

```
/qg review
```

기대: 리뷰어가 이 커밋의 diff 를 본다. CRITICAL·IMPORTANT 가 나오면 고치고 같은 커밋에 `--amend` 하지 말고
**후속 커밋**으로 쌓는다(리뷰 이력이 보이도록). 고친 뒤 Task 3 Step 13·14 의 확인을 다시 돌린다.

- [ ] **Step 2: PR 을 연다**

본문에 반드시 넣을 것:
- **사용자 측 영향** — 마켓플레이스를 갱신한 설치자에게서 이 플러그인이 사라지고, `force-for-plugin` output
  style 도 함께 사라진다. deprecation 창을 두지 않은 근거: CLAUDE.md 의 one-minor 창은 v1.0.0 이상의 CHANGELOG
  규칙 아래 있고 이 플러그인은 0.4.0 이다(선례 `plugins/spec-distill/CHANGELOG.md:137`).
- **도출 절차 증거**(AC8) — `$WORK/sweep-evidence.txt` 의 S1 히트 수 · S2 판정 표 · S3 하한 표 · 「새 행 0」.
- **양성 대조 결과**(AC6) — Task 4 Step 2 의 두 줄.
- **스위트 대조**(AC5) — 사라진 대상 5 · 전후 차이 0 · stub 호출 0.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
WORK="${CLAUDE_JOB_DIR:-$HOME/at-removal-work}/tmp"
cat > "$WORK/pr-body.md" <<'BODY'
`plugins/agent-transparency/` 와 마켓플레이스 항목을 지우고, 이 플러그인 **때문에** 리포의 다른 곳에 생긴 줄을
같은 커밋에서 되돌린다. 설계: `docs/superpowers/specs/2026-09-20-remove-agent-transparency-design.md`,
계획: `docs/superpowers/plans/2026-09-21-remove-agent-transparency.md`.

## 사용자 측 영향

마켓플레이스를 갱신한 설치자에게서 `agent-transparency` 가 사라지고, `force-for-plugin` output style 도 함께
사라진다. deprecation 창을 두지 않은 근거 — CLAUDE.md 의 one-minor 창은 v1.0.0 이상의 CHANGELOG 규칙 아래 있고
이 플러그인은 0.4.0 이다(선례 `plugins/spec-distill/CHANGELOG.md:137`). 로컬 설치는 없으나 리포가 공개라
제3자 설치를 확인할 수는 없다.

## 도출 절차 증거 (AC8)

- S1(이름) — LIVE 별칭 grep: (히트 수)건. 그중 경로 리터럴 예외 2건.
- S2(역추적) — 이력 문서에서 근거를 댄 자리 → live 줄 판정: (표)
- S3(숫자) — 하한·baseline 리터럴 전수 판정: (표). 흔적 1(T7), 나머지는 붕괴 바닥이라 둔다.
- 확정 표 밖 새 행: (수)

## 검증

- AC5 스위트 대조 — 사라진 대상 5(이 플러그인의 테스트) · 전후 차이 0 · stub 호출 0
- AC7 dispatch 인쇄값 — (제거 전) → (제거 후), 앵커 수 일치, `ZERO_AGENTS` 빈 값
- AC6 양성 대조 — `✓ 파서가 끝까지 돌았다 (rc 0)` 와 `✗ 대상 마크다운이 27개뿐` 을 함께 관측
- AC4 양성 짝 — 경로 리터럴 예외가 같은 파일의 새 언급은 여전히 잡는다

## 버전 bump 없음

남는 플러그인의 파일을 하나도 편집하지 않는다 — 편집은 `.claude-plugin/` · `docs/` · `shared/` · `tools/` 뿐이다.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
git push -u origin feature/remove-agent-transparency
gh pr create --base main \
  --title "agent-transparency 제거 — 애초에 없던 상태로" \
  --body-file "$WORK/pr-body.md"
```

- [ ] **Step 3: 머지는 사용자가 실행한다**

`gh pr merge` 는 이 환경의 판정기가 막는다. 사용자에게 다음을 그대로 실행하도록 안내한다:

```
! gh pr merge <번호> --merge
```

`gh api` 로 우회하지 않는다. 머지 뒤 `gh pr view <번호> --json state` 로 `MERGED` 를 직접 확인한다.

- [ ] **Step 4: 머지 뒤 정리 (리포 밖 — 제안만 한다)**

- 고아 캐시 삭제: `rm -rf ~/.claude/plugins/cache/devbrew/agent-transparency` (1.0M, 0.3.2 · 0.4.0)
- 메모리 갱신: `project_agent_transparency_design` 을 REMOVED 로 표시
- 워크트리 정리: `git worktree remove .claude/worktrees/remove-agent-transparency`
  (먼저 `git merge-base --is-ancestor HEAD origin/main` 으로 머지됐음을 확인 — ExitWorktree 의
  「커밋 N개 손실」 경고는 stale 로컬 main 기준이라 믿지 않는다)

---

## 실패 시 되돌리기

Task 3 은 한 커밋이므로 되돌리기도 하나다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency
git reset --hard HEAD~1    # 커밋 전이면: git checkout -- . && git clean -fd
```

Task 4 중간에 멈췄다면 **반드시** Step 3 의 복원을 먼저 돌린다 — 안 하면 두 reference 파일이 지워진 채 남는다.
