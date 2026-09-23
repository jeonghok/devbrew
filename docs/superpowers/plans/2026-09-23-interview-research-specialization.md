# 인터뷰의 조사 특화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이미 출하돼 있는 조사 주장 계약(`repo_claims[]`/`evidence[]`)을 한 자리에서 꺼내 네 자리에 걸고, 결정 연결 필드(`decides`)와 id(`RC<n>`)를 더해 「어느 결정에도 닿지 않은 조사는 성공이 아니다」를 기계가 읽을 수 있게 만든다.

**Architecture:** 다섯 자리를 순서대로 배선한다 — ①계약 정본 신규 파일 → ②조사 장치 셋의 dispatch 슬롯 둘 → ③커버리지 원장의 이름 있는 derived 축 → ④검문소 셋(V1 라운드 안 · V2 종료 누락 대조 · V3 게이트) → ⑤`check_brief.py` 술어 다섯. 술어 다섯은 payload frontmatter `contract: v2` 옵트인 뒤에 있어 기존 픽스처 81개를 한 글자도 고치지 않는다. 표기층(§H)이 토큰·발급자·정량자·순회 범위·일치 규칙·코퍼스 경계 여섯을 도출형으로 고정하고 나머지 절이 그것을 전제한다.

**Tech Stack:** Python 3.12 바닥(`python3`, 표준 라이브러리 + PyYAML) · bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`) · 마크다운 skill/agent/reference/template · `git`.

**Spec:** `docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md`

## 목차

- [인계받은 세 공시](#인계받은-세-공시-계획이-그대로-물려받는다)
- [Global Constraints](#global-constraints)
- [File Structure](#file-structure)
- [Spec 사상 — AC1–AC24 · Verification 1–8](#spec-사상--ac1ac24--verification-18)
- [Task 1: Baseline 과 전수 재도출 (측정 전용 · 커밋 없음)](#task-1-baseline-과-전수-재도출-측정-전용-커밋-없음)
- [Task 2: 계약 정본 `references/research-claims.md` 신설](#task-2-계약-정본-referencesresearch-claimsmd-신설)
- [Task 3: SKILL.md 의 계약 배달 펜스 (AC3)](#task-3-skillmd-의-계약-배달-펜스-ac3)
- [Task 4: steelman 경로 배선 — 사본 필드 둘 · 슬롯 둘 · 처분 줄](#task-4-steelman-경로-배선-사본-필드-둘-슬롯-둘-처분-줄)
- [Task 5: coverage-mapper 배선 — 슬롯 둘 · 출력 의무 · AC20 검증 의무 · 처분 줄](#task-5-coverage-mapper-배선-슬롯-둘-출력-의무-ac20-검증-의무-처분-줄)
- [Task 6: blind-spot-prober 배선 — 슬롯 둘 · 출력 의무 · 처분 줄](#task-6-blind-spot-prober-배선-슬롯-둘-출력-의무-처분-줄)
- [Task 7: SKILL.md 줄 수 천장 처분과 로드 표면 순증 실측](#task-7-skillmd-줄-수-천장-처분과-로드-표면-순증-실측)
- [Task 8: V1 검문소 — 라운드 규약 안의 무조건 확인 (AC6)](#task-8-v1-검문소-라운드-규약-안의-무조건-확인-ac6)
- [Task 9: C43 경로 (a) 를 계약 산출로 · 리터럴 마커 폐기 (AC15)](#task-9-c43-경로-a-를-계약-산출로-리터럴-마커-폐기-ac15)
- [Task 10: state 스키마 둘 · migration 이월 (AC13 의 state 부분)](#task-10-state-스키마-둘-migration-이월-ac13-의-state-부분)
- [Task 11: 호출 자격 · 예산 · C44 면제 (AC13 나머지 · AC14 · AC22)](#task-11-호출-자격-예산-c44-면제-ac13-나머지-ac14-ac22)
- [Task 12: finishing.md — V2 누락 대조 · 반증 세 칸 · 인계 세 방향 · Step B advisory (AC7 · AC11)](#task-12-finishingmd-v2-누락-대조-반증-세-칸-인계-세-방향-step-b-advisory-ac7-ac11)
- [Task 13: 템플릿 둘 — `contract: v2` 와 세 방향 예시 (AC19 · AC23)](#task-13-템플릿-둘-contract-v2-와-세-방향-예시-ac19-ac23)
- [Task 14: `check_brief.py` — 옵트인 스위치 · 순회 정의 · advisory 둘 (AC9 · AC11 코드 · AC23)](#task-14-checkbriefpy-옵트인-스위치-순회-정의-advisory-둘-ac9-ac11-코드-ac23)
- [Task 15: 술어 ①②③ — 연결 ∀ · 대상 실재 · 역참조 ∀ (AC8)](#task-15-술어-①②③-연결-대상-실재-역참조-ac8)
- [Task 16: 술어 ④ — 이름 정확 일치 derived + `closed` (AC10)](#task-16-술어-④-이름-정확-일치-derived-closed-ac10)
- [Task 17: 술어 ⑤ — 확인 줄 ∀ (AC12)](#task-17-술어-⑤-확인-줄-ac12)
- [Task 18: 새 락 `tests/test_research_claims_contract.sh` — 여섯 축 (AC16 + 이월 해소)](#task-18-새-락-teststestresearchclaimscontractsh-여섯-축-ac16-이월-해소)
- [Task 19: 게이트 술어 다섯의 변이 · 양성 대조 · 픽스처 회귀 0 양방향 (Verification 4·5·7)](#task-19-게이트-술어-다섯의-변이-양성-대조-픽스처-회귀-0-양방향-verification-457)
- [Task 20: 릴리스 — `3.3.0` · 전체 스위트 · baseline 대조 · web-off 실측 (AC17 · AC18 · AC24)](#task-20-릴리스-330-전체-스위트-baseline-대조-web-off-실측-ac17-ac18-ac24)
- [Deferred to plan — 일곱 항목의 처분](#deferred-to-plan--일곱-항목의-처분)
- [Open Questions — 계획이 답하지 않는 것](#open-questions--계획이-답하지-않는-것)

---

## 인계받은 세 공시 (계획이 그대로 물려받는다)

1. **재결정 규약(P23)** — confirmed 항목은 근거 있으면 보고 후 사용자 동의로 재결정 가능하고 임의 변경은 금지다. 설계가 좁힌 것은 ⟨C13⟩ 하나이고 세 칸 기록이 설계 `### 재결정` 에 있다. **이 계획은 confirmed 를 하나도 더 좁히지 않는다** — 좁혀야 할 근거가 생기면 그 Task 를 멈추고 사용자에게 보고한다.
2. **미관측 공시** — reviewing-spec 라운드 2 의 `fix` 6 + 채택 `decide` 11 의 적용은 permit `round: 3` 이 미소모라 **기계 관측을 받지 못했다.** 즉 설계문서의 라운드 2 반영분은 리뷰 엔진의 스냅샷 diff 로 확인되지 않았다.
3. **미검증 공시** — **§H 표기층은 라운드 3 을 돌지 않아 리뷰로 검증되지 않았다.** `RC<n>`/`OQ<n>` 토큰 선택 · `open_decisions[]` 스키마 · `[→ 없음]` sentinel · `contract: v2` 옵트인 넷이 그 절의 산물이고, 이 계획이 그것을 처음 코드로 옮긴다. 각 Task 의 red/green 짝과 변이가 이 절의 유일한 검증이다.

## Global Constraints

spec 의 프로젝트-전역 요구를 값째 옮긴 것이다. **모든 Task 의 요구사항에 이 절이 암묵적으로 포함된다.**

- **워크트리 고정** — 모든 작업은 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden` 에서 한다. 원본 리포 루트로 `cd` 하지 않는다. 브랜치 `feature/interview-research-burden`.
- **`git stash` 금지** — bare `git stash`/`git stash pop` 을 쓰지 않는다(다른 세션의 변경을 pop 할 수 있다). 작업을 치워야 하면 임시 WIP 커밋을 쓴다.
- **커밋 메시지 꼬리** — 모든 커밋 메시지는 다음 두 줄로 끝난다:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
  ```
- **SemVer bump** — `plugins/spec-distill/` 을 건드리는 PR 은 같은 커밋에서 `plugin.json` bump 를 갖는다. 이 작업의 목표값은 `3.2.0 → 3.3.0`(minor = 새 surface). 릴리스 Task 20 에서 한 번에 올린다(브랜치 중간에 올리면 먼저 머지되는 쪽이 이긴다).
- **python 테스트 실행** — python 테스트는 `python3 -m unittest` 로만 돌린다. 파일을 직접 실행하지 않는다.
- **`PYTHONDONTWRITEBYTECODE=1`** — 변이(mutation) 검증 시 필수. 같은 길이 변이는 stale `.pyc` 를 못 넘어 거짓 GREEN·거짓 RED 를 둘 다 낸다.
- **Korean-primary 문서** — 영어는 식별자(`RC<n>`·`OQ<n>`·`contract: v2`·P#·AC#)·고유명사·코드·원문 인용·번역 어색한 기술어(`frontmatter`·`subagent`·`sentinel`)에만.
- **Secret 금지** — state·brief·audit 어디에도 실값을 적지 않는다. `<REDACTED>` / `<REDACTED:라벨>` 형태만.
- **`docs/**.md` ~300줄 이상이면 `## 목차` 필수**, 섹션 추가·이름 변경·삭제 시 같은 커밋에서 TOC 동기화. 이 계획 파일 자신도 대상이다.
- **차단 판정에 개수 술어를 두지 않는다** ⟨C5⟩·X7. red/green 을 가르는 술어는 전부 ∀ 형태이고 순회 항목이 0건이면 공허 통과한다. 개수는 **조건 분기와 advisory 에만** 들어간다. 차단 메시지 문면에도 개수를 넣지 않는다(Task 18 의 축이 그것을 grep 한다).
- **`touches` 불변** — 기존 `touches` 는 전제 `P<n>` 을 담는다. 의미·소비 사슬을 바꾸지 않는다. 결정 연결은 **새 필드 `decides`** 다.
- **`references/steelman.md` Step 2 불변** — 중복 제거하지 않는다. `test_conducting_interview_stage.sh:592-599` 가 그 파일의 `if < else < Agent < fi` 순서를 보안 컨트롤로 못 박는다.
- **네 번째 dispatch 자리 금지** — dispatch 자리는 **셋**(SKILL.md 둘 + steelman.md 하나). C43 경로 (a) 자동확인은 orchestrator 가 자기 `Read`/`Grep` 으로 직접 수행한다.
- **`Phase 0`(`skills/framing-requests/`) 편집 금지** ⟨C4⟩. 의무는 받는 쪽(Phase 1)에 둔다.
- **새 agent 파일 0 · 새 brief 절 0 · 새 floor 키 0 · 삭제 0 · 기존 픽스처 편집 0.**
- **`references/<파일>.md` 표기는 위치가 형태를 정한다.** `shared/tests/test_skill_reference_pointers.sh`
  가 `plugins/*/skills/*/SKILL.md` · `plugins/*/skills/*/references/*.md` · `plugins/*/references/*.md`
  **전부**를 포인터 출처로 훑고, 그 정규식은 **백틱을 접두 문자에서 제외**하므로 코드 스팬 안의
  경로도 포인터로 잡는다. 해석하는 형태는 **셋뿐**이고 그 밖은 조용히 재해석하지 않고 **거부**한다:

  | 쓰는 자리 | 옳은 형태 | 왜 |
  |---|---|---|
  | `skills/conducting-interview/SKILL.md` | 맨몸 `references/steelman.md` **또는** `${CLAUDE_PLUGIN_ROOT}/…` | 그 파일의 디렉토리가 곧 `skills/conducting-interview/` 라 맨몸이 옳게 풀린다 |
  | `skills/conducting-interview/references/*.md` | **`${CLAUDE_PLUGIN_ROOT}/…` 만** | 맨몸은 `…/references/references/x.md` 로 이중 중첩된다 |
  | `references/*.md` (플러그인 레벨) | **`${CLAUDE_PLUGIN_ROOT}/…` 만** | 같은 이중 중첩 |
  | 어디든 | **`$SD/references/…` 금지** | 셋 중 어느 형태도 아니라 「접두사를 알아볼 수 없다」로 red |

  **그리고 두 락이 같은 토큰에 반대 요구를 건다.** `shared/tests/test_plugin_root_no_cwd_fallback.sh`
  의 축 3 은 `references/` 아래 파일의 **본문에 `CLAUDE_PLUGIN_ROOT` 가 있으면** 그 파일을 대상에
  등록하고(`if "CLAUDE_PLUGIN_ROOT" in body`), 그 순간 「어느 SKILL.md 가 이 파일을 절대 형태로
  `Read` 하는 줄 + 같은 절의 치환 안내 문장」을 요구한다. 이 설계는 계약 파일을 **`Read` 하지 않는다** —
  `cat` 으로 dispatch 슬롯에 싣는 것이 요점이다(설치본에서 subagent 의 Read 가 거부되므로). 그래서:

  > **플러그인 레벨 `references/*.md` 의 본문에는 경로도 루트 토큰도 넣지 않는다.** 다른 파일을
  > 가리켜야 하면 **이름만** 쓴다(`steelman.md`) 또는 절차 이름으로 부른다. 리포의 기존 관습이
  > 이미 그것이다 — 형제 넷(`compression.md` · `proceed-gate.md` · `reviewing-document.md` ·
  > `trivia-escape.md`) 전부가 `CLAUDE_PLUGIN_ROOT` 를 **0개** 담는다.

  Task 2 가 이 충돌에 실제로 걸렸다: 포인터 락을 고치려고 루트 토큰을 넣었고 그것이 축 3 을 깨뜨렸다.
  한 RED 를 다른 RED 로 바꾼 것이다. 두 락을 **함께** 돌려야 그 교환이 보인다.

  그래서 이 락을 **그 코퍼스의 파일을 건드리는 모든 Task 의 검증 단계에 넣는다** — Task 2 가 이
  함정에 실제로 걸렸고(맨몸 `references/steelman.md` 를 플러그인 레벨 파일에 써서 소실 1 + 대조
  실패 1), 그 락이 Task 2 의 검증 목록에만 있었으면 Task 20 까지 아무도 몰랐다.

### 착수 전에 반드시 재도출할 것 (열거를 신뢰하지 않는다)

설계 AC22 는 옛 상한 문구를 「여섯 자리」로 열거했다. **그 여섯은 `agents/` 두 파일만의 전수다** — 본 계획이 Task 1 에서 grep 으로 재도출해 SKILL.md 5건 + README.md 3건이 더 있음을 확인했다. 같은 이유로 아래 셋은 **매 착수 시 grep 으로 다시 세고**, 이 문서의 숫자를 기대값으로 고정하지 않는다:

- 두 장치의 옛 상한 문구 자리 (Task 1 · Task 11)
- `[from-code][auto-confirmed]` 리터럴 잔존 (Task 1 · Task 9)
- `## 4. External Landscape` 를 가진 픽스처 수 (Task 1 · Task 19)

---

## File Structure

| 경로 | 책임 | 신규/수정 |
|---|---|---|
| `plugins/spec-distill/references/research-claims.md` | 조사 주장 계약의 **정본** — `evidence[]`·`repo_claims[]` 두 모양 + `decides`·`id`, OQ17 선례 지시, `decides` 의 의미 | **신규** |
| `plugins/spec-distill/agents/steelman-builder.md` | 인라인 스키마 사본에 `decides`·`id` 추가 · `input_slots` 둘 | 수정 |
| `plugins/spec-distill/agents/coverage-mapper.md` | `input_slots` 둘 · 출력 의무 · 자격+예산 문구 | 수정 |
| `plugins/spec-distill/agents/blind-spot-prober.md` | 같음 | 수정 |
| `.../skills/conducting-interview/SKILL.md` | 계약 `cat` 펜스 · dispatch 둘의 슬롯 · V1 · C43 (a) · C44 면제 · 자격·예산 · state 키 둘 · AC20 의무 · 처분 줄 둘 | 수정 |
| `.../conducting-interview/references/finishing.md` | V2 누락 대조 · 반증 세 칸 · 인계 세 방향 · §0 상태 토큰 · Step B advisory | 수정 |
| `.../conducting-interview/references/steelman.md` | dispatch 슬롯 둘 · 처분 줄 (Step 2 는 불변) | 수정 |
| `.../conducting-interview/references/state-migration.md` | `blind_spot_dispatched: true → 1` 이월 + 옛 키 삭제 + `open_decisions` 기본값 | 수정 |
| `plugins/spec-distill/templates/interview-brief-template.md` | frontmatter `contract: v2` · 세 방향 예시 | 수정 |
| `plugins/spec-distill/templates/interview-audit-template.md` | §1 `derived:internal_research` · §5 `확인 RC<n>` 예시 | 수정 |
| `plugins/spec-distill/scripts/check_brief.py` | 옵트인 분기 · 술어 다섯 · advisory 둘 · 순회 정의 주석 | 수정 |
| `plugins/spec-distill/tests/test_research_claims_contract.sh` | 새 락 — 축 A·B·C·X·D·E | **신규** |
| `plugins/spec-distill/tests/test_check_brief.sh` | 술어 다섯의 red/green 짝 | 수정 |
| `plugins/spec-distill/tests/fixtures/interview-brief-v2-*.md` | `contract: v2` green + red 여섯 | **신규** |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | 옮겨간 계약을 따라가는 단언 갱신 + 새 단언 | 수정 |
| `plugins/spec-distill/tests/test_steelman_builder_scope.sh` | 키 앵커 목록에 `decides`·`id`(리스트 첫 키라 `id` 는 dash 를 넘는 앵커가 필요하다) | 수정 |
| `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` · `test_blind_spot_prober_frontmatter.sh` | 슬롯·출력 의무 단언 추가 | 수정 |

**설계 Files to Modify 의 한 행을 정정한다.** 그 표는 `tests/test_brief_agents.sh` 를 「새 슬롯·문구를 반영해 확장」 대상으로 적었지만, **그 락은 세 조사 agent 를 보지 않는다** — `ALL=("doc-critic" "doc-critic-web" "doc-recritic" "brief-readback")` 이고 IB(주입 경계) 블록의 대상은 머리에 `# copy-of:` 마커를 단 엔진 사본 + `brief-readback` 이다. 세 조사 agent 의 도구·스키마 표면을 재는 락은 `test_steelman_builder_scope.sh` · `test_coverage_mapper_frontmatter.sh` · `test_blind_spot_prober_frontmatter.sh` 셋이고, 이 계획은 그 셋을 확장한다. `test_brief_agents.sh` 는 **편집하지 않고 green 유지만 확인한다**(Task 20 Step 1).

| `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` | `3.3.0` + 항목 + Principles Instantiated | 수정 |

**파일을 쪼개지 않는 이유** — 이 리포는 새 책임을 별도 모듈로 내보내고 기존 파일엔 진입 한 줄만 둔다. 계약 정본이 새 파일이 된 것이 그 규율이고, `check_brief.py` 의 술어 다섯은 그 파일의 기존 술어 26개와 **같은 코퍼스·같은 헬퍼**(`_section_text`·`_entry_lines`·`LEDGER_ROW_RE`)를 쓰므로 쪼개면 §6 경계 계산이 두 곳으로 갈린다(그 갈라짐이 v0.47.0 의 통로였다).

## Spec 사상 — AC1–AC24 · Verification 1–8

계획 self-review 의 첫 항목(spec coverage)을 표로 고정한다. **빈 칸이 없다.**

| AC | 어느 Task |
|---|---|
| AC1 계약 정본 + 사본 유지 | Task 2(정본) · Task 4(사본에 `decides`·`id`) |
| AC2 세 dispatch 가 두 슬롯 | Task 4(steelman.md) · Task 5(SKILL.md coverage-mapper) · Task 6(SKILL.md prober) |
| AC3 `cat` 펜스 + 마커 + 실패 rc 1 | Task 3 |
| AC4 세 agent `input_slots` + `kind:` | Task 4 · Task 5 · Task 6 (각 Task 가 선언과 전달을 **함께** 넣는다 — `check_slots.py` 가 양방향이다) |
| AC5 OQ17 지시 + 출처 인용 | Task 2 |
| AC6 V1 다섯 단계 + trigger·웹 스위치 비종속 | Task 8 |
| AC7 V2 + 반증 세 칸 + 사용자 동의 | Task 12 |
| AC8 ①②③⑤ ∀ · 차단에 개수 술어 없음 | Task 15 · Task 17 · **Task 19 g7**(개수 조건을 «넣는» 변이가 RED 를 내는 것이 그 가드의 생존 증거다) |
| AC9 순회 정의가 코드 주석과 설계에 같은 문면 · 위치는 줄 끝 | Task 14 (Step 5 가 문면 일치를 기계로 대조) |
| AC10 이름 정확 일치 derived + `closed` | Task 16 |
| AC11 0건 advisory + Step B 배달 | Task 14(코드) · Task 12(Step B 문면) |
| AC12 확인 줄 ∀ · 웹 주장은 대상 아님 | Task 17 |
| AC13 자격 + 예산 + state 스키마 + migration | Task 10(state · migration) · Task 11(자격 · 예산). **AC13·AC14 의 문면은 `touched_decisions`(list) 를 별 키로 적지만 설계 §H ② 가 그것을 `open_decisions[].touched` 필드로 흡수했다**(같은 절이 「이 키 하나가 라운드 1 이 요구한 `touched_decisions` 를 필드로 흡수한다 — 별 키를 두지 않는다」로 명시한다). §H 가 나중에 쓰인 지배 절이므로 계획은 필드를 구현하고 **옛 키를 되살리지 않는다** |
| AC14 C44 면제 + 산출자 + **계수 먼저, 표시 나중** | Task 11 |
| AC15 리터럴 마커 제거 + `plugins/` 잔존 0 | Task 9 |
| AC16 새 락 다섯 축(+ D 집합 등호) | Task 18 (여섯 축 — 다섯 + 이월 해소 E) |
| AC17 `3.3.0` + CHANGELOG + `test_readme_sync.sh` | Task 20 |
| AC18 새 RED 0 — **실패 줄 수까지** 대조 | Task 1(baseline) · Task 20 Step 1(대조) |
| AC19 템플릿 둘의 예시 = green fixture 모양 | Task 13 |
| AC20 「레포로 확인 가능한 항목마다」 + 빈 문단 시 미발동 공시 | Task 5 |
| AC21 `## 결정 기록` 의 `X<n>` 접두 | **구현 대상이 없다** — 설계문서 자신의 규약이고 이미 충족돼 있다. Task 20 Step 4 의 CHANGELOG 작성 시 설계 인용이 그 접두를 섞지 않는지만 확인한다 |
| AC22 괄호 없는 `fail-closed` 서식 + 옛 상한 문구 전수 갱신 | Task 4 · 5 · 6(처분 줄) · Task 11(상한 문구 14자리) · **Task 1 Step 3**(grep 재도출 — 설계의 「여섯」은 `agents/` 만의 전수였다) |
| AC23 `contract: v2` 옵트인 + 템플릿이 그 필드를 넣는다 | Task 14(코드) · Task 13(템플릿) |
| AC24 dispatch 자리는 셋 · 「앵커 수 == dispatch 수」 green | Task 6 · Task 9(경로 (a) 직접 수행) · Task 20 Step 2 |

| Verification | 어느 Task |
|---|---|
| 1 baseline(rc + **파일별 실패 줄 수**) | Task 1 |
| 2 새 락의 다섯 축 + 마커 요구 | Task 18 |
| 3 red/green 짝 (④ 는 **red 셋**) | Task 15 · Task 16 · Task 17 |
| 4 변이 네 축(표기 · 값 · 위치 · 제약의 부정형) | Task 18 m1–m6 · Task 19 g1–g8 |
| 5 **양성 대조** | Task 18 Step 4 · Task 19 Step 1 |
| 6 기존 스위트 전량 (python 은 `-m unittest`) | Task 20 Step 1 · Step 5 |
| 7 픽스처 회귀 0 **양방향** | Task 15 Step 4(a) · Task 17 Step 4(b) · Task 19 Step 3(둘 다) |
| 8 web-off 세션 실측 | Task 20 Step 3 (구조적 실측 — 한 사이클 e2e 는 Task 20 Step 5 가 사용자에게 넘긴다) |

**Files to Modify 17행**은 위 `## File Structure` 표와 1:1이다. 설계 표의 마지막 행(`tools/adjudication/` — `EXEMPT_SLOTS_BASELINE` bump 여부 확인)만 File Structure 에 파일로 없다: **편집이 필요 없다는 것이 그 행의 결론**이고(Task 4 의 `kind:` 선택 근거 + Task 20 Step 2 실측), 그래서 수정 파일 목록에 오르지 않는다.


---

### Task 1: Baseline 과 전수 재도출 (측정 전용 · 커밋 없음)

**Files:**
- Create: `.superpowers/sdd/2026-09-23-interview-research-specialization/baseline.txt` (SDD 워크스페이스 — 추적 대상 밖이고 커밋하지 않는다)
- Read only: 리포 전역

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `baseline.txt` — Task 20 의 AC18 대조가 이 파일의 «파일별 실패 줄 수» 를 쓴다. 그리고 아래 다섯 재도출 값: `CAP_SITES`(옛 상한 문구 자리 목록) · `MARKER_SITES`(`[from-code][auto-confirmed]` 자리) · `FX_S4`(§4 를 가진 픽스처 수) · `SKILL_LINES`(SKILL.md 줄 수) · `FLOOR_LIT`(floor 리터럴 계수).

**왜 rc 가 아니라 실패 줄 수인가** — rc 만 잡으면 **이미 RED 인 파일 안의 새 실패가 원리적으로 안 보인다.** 이 리포에는 선재 RED 가 있다(워크트리에서 NG9 계열 1건이 관측됐다).

- [ ] **Step 1: 전체 셸 스위트를 돌려 파일별 rc 와 실패 줄 수를 기록**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
B="$W/baseline.txt"
: > "$B"
for f in plugins/*/tests/*.sh shared/tests/*.sh; do
  case "$(basename "$f")" in assert.sh|presence_corpus.sh) continue ;; esac
  out="$(bash "$f" 2>&1)"; rc=$?
  # 접두 `  ✗ ` 로 센다 — `assert.sh` 의 `no()` 가 `printf '  ✗ %s\n'` 로 내고
  # `shared/tests/test_assert_behavior.sh` 가 그 접두를 「진단 grep 다섯 자리의 계약」으로 못 박는다.
  # 접두 없이 세면 설명 문구에 그 글자를 담은 **통과** 줄이 실패로 잡힌다(실측: 그 파일이 rc 0 인데 1).
  nfail="$(printf '%s\n' "$out" | grep -c '^  ✗ ' || true)"
  # **이미 RED 인 파일의 «새» 실패**를 잡는 세 번째 필드. `rc!=0` 인데 `fail_lines=0` 인 파일은
  # (단언 실패가 아니라 조기 중단이라 `  ✗ ` 줄을 안 낸다) 두 술어가 둘 다 포화라 새 실패가
  # 어느 쪽도 움직이지 않는다 — AC18 이 경고하는 바로 그 구멍이다. 실측: 착수 시
  # `plugins/quality-gates/tests/test_codex_backward_compat.sh` 가 `rc=1 fail_lines=0` 이다.
  # 특정 파일 이름을 박지 않고 `rc!=0` 전부에 건다 — 다음에 다른 파일이 RED 가 되어도 자동 대상이다.
  # GREEN 파일은 `-` 로 둔다: 통과 출력의 해시는 무해한 문구 변화에도 흔들려 소음만 된다.
  if [ "$rc" -eq 0 ]; then h="-"; else h="$(printf '%s\n' "$out" | shasum -a 256 | cut -c1-16)"; fi
  printf '%s\trc=%s\tfail_lines=%s\touthash=%s\n' "$f" "$rc" "$nfail" "$h" >> "$B"
done
sort "$B" | tail -n +1
grep -c . "$B"
```

Expected: 각 줄이 `<경로>	rc=<n>	fail_lines=<n>`. 마지막 두 출력은 전체 목록과 줄 수. **`rc=0 fail_lines=0` 이 아닌 줄을 눈으로 확인하고 그 목록을 선재 RED 로 못 박는다.**

- [ ] **Step 2: python 테스트 baseline**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' -v 2>&1 | tail -20 \
  | tee -a "$W/baseline.txt"
```

Expected: `OK` 또는 `FAILED (failures=N)`. 그 값을 baseline 으로 기록한다.

- [ ] **Step 3: 옛 상한 문구 자리를 grep 으로 전수 재도출**

설계 AC22 의 열거를 신뢰하지 않는다. **두 장치(coverage-mapper · blind-spot-prober)의 상한 문구만** 대상이고, 엔진의 `재리뷰 상한 2` · `confirm_repost_count` 의 `상한 2회` · `finishing.md` 재제시 `상한 2회` · `rhythm guard 3` 은 **대상이 아니다**(다른 것을 센다).

**line-wide `grep -v` 를 쓰지 않는다.** 배제 문구가 진짜 자리와 **같은 줄**에 있으면 그 자리까지 함께 버려지고(`README.md:130` 은 `coverage-mapper dispatch 상한 2` 와 `재리뷰 상한 2` 를 한 줄에 담는다), 반대로 배제 문구와 글자가 다른 무관한 자리는 통과한다(`README.md:93` 의 `재제시에는 상한 2회`). 둘 다 실측된 오분류다. 매처를 워크스페이스에 파일로 두고 Task 11 이 **같은 파일을 다시 쓴다** — 사본을 두면 한쪽만 고치는 결함이 된다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
cat > "$W/cap-sites.py" <<'EOS'
#!/usr/bin/env python3
"""두 장치(coverage-mapper · blind-spot-prober)의 옛 상한 문구 자리를 도출한다.

배제는 **개념 정밀**이다 — 줄 단위 `grep -v` 는 같은 줄의 진짜 자리를 함께 버린다(실측:
README.md:130). 다른 것을 세는 상한 셋을 각각 그 자리에서만 뺀다:
  · 엔진 재리뷰 상한   — `상한 2` 바로 앞이 `재리뷰 `
  · 확정 재제시 상한   — `상한 2` 바로 뒤가 `회`
  · confirm_repost_count — 그 식별자를 담은 줄
"""
import re
import sys
from pathlib import Path

TARGET = re.compile(
    r"(?<!재리뷰 )상한 2(?!회)"
    r"|fan-out 1"
    r"|인터뷰당 1회"
    r"|bounded dispatch"
    r"|bounded to two per interview")
root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
hits = 0
for f in sorted(root.glob("plugins/spec-distill/**/*.md")):
    rel = str(f)
    if "/tests/" in rel or f.name == "CHANGELOG.md":
        continue
    for i, ln in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        if "confirm_repost_count" in ln:
            continue
        if TARGET.search(ln):
            hits += 1
            print("%s:%d:%s" % (rel, i, ln.strip()[:150]))
print("총 %d 줄" % hits, file=sys.stderr)
EOS
python3 "$W/cap-sites.py" . | tee "$W/cap-sites.txt"
grep -c . "$W/cap-sites.txt"
```

Expected: **원시 매치 줄 15 · 개념 자리 14.** 수가 하나 어긋나는 이유는 `SKILL.md` 의 한 문장이 두 줄로 줄바꿈돼 있어(`**인터뷰당 1회**` / `dispatch한다(fan-out 1, C8)`) 한 자리가 두 줄로 세어지기 때문이다. 다른 값이 나오면 그 차이를 먼저 설명하고 Task 11 의 대상 목록을 그 실측으로 바꾼다. 세부(개념 자리 14):
- `agents/blind-spot-prober.md` — frontmatter description `(fan-out 1)` · 본문 규칙 4 `**fan-out 1**: 인터뷰당 1회 dispatch(C8).` · 「사용하지 않는 경우」 `재dispatch 금지 — fan-out 1, AC6`
- `agents/coverage-mapper.md` — frontmatter description `dispatch is bounded to two per interview.` · H1 `(상한 2 dispatch …)` · 본문 규칙 4 `**bounded dispatch**: … 상한 2`
- `SKILL.md` — state 주석 `# C8 인터뷰당 1회 보장` · state 주석 `# 상한 2 — R1 첫 질문 전 1 + 재개방 시 ≤1` · 헤딩 `## coverage-mapper dispatch (상한 2)` · 본문 `상한 2, 카운터 …` · 본문 `**인터뷰당 1회** dispatch한다(fan-out 1, C8)`
- `README.md` — `:65` `(적대적 premortem, fan-out 1)` · `:123` `dispatch 상한 2) + … fan-out 1` · `:130` `coverage-mapper dispatch 상한 2 + blind-spot-prober fan-out 1(interview)`.
  **`:93` 은 대상이 아니다** — `재제시에는 상한 2회` 는 확정 재제시 상한(P17)이고 다른 것을 센다.

- [ ] **Step 4: 리터럴 마커 · 픽스처 · 줄 수 · floor 리터럴 계수 재도출**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
echo "--- MARKER_SITES (plugins/ 하위만 — docs/archive 는 이력이라 대상 아님)"
grep -rn 'from-code\]\[auto-confirmed' plugins/ || echo "0건"
echo "--- FX_S4 (§4 를 가진 픽스처 수)"
grep -rl '^## 4\. External Landscape' plugins/spec-distill/tests/fixtures | wc -l
echo "--- SKILL_LINES + 두 천장"
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -n 'SKILL.md 줄 수' plugins/spec-distill/tests/test_conducting_interview_stage.sh
echo "--- FLOOR_LIT (floor 리터럴 계수 — 플러그인 범위로 고정한다)"
grep -ro 'floor:' plugins/spec-distill --include='*.md' --include='*.py' | wc -l
grep -rno 'FLOOR_KEYS' plugins/spec-distill/scripts | wc -l
```

Expected: MARKER_SITES **1건**(`SKILL.md:125`) · FX_S4 **81** · SKILL_LINES **340** · 천장 `< 388`(line 366) 과 `< 408`(line 393) · FLOOR_LIT 은 값을 기록만 한다(**파일 밖 기대값으로 고정하지 않는다** — 같은 축을 세 번 재서 세 값이 나온 이력이 있다. 범위를 「플러그인 범위」로 못 박은 이 값만 baseline 에 남긴다).

- [ ] **Step 5: 커밋하지 않는다 — baseline 을 출력으로 남긴다**

```bash
W=.superpowers/sdd/2026-09-23-interview-research-specialization
cat "$W/baseline.txt"
cat "$W/cap-sites.txt"
```

Expected: 두 파일의 내용이 보인다. **이 Task 는 리포를 바꾸지 않으므로 커밋이 없다.** `git status` 가 clean 이어야 한다:

```bash
git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden status --porcelain
```
Expected: 빈 출력.

---

### Task 2: 계약 정본 `references/research-claims.md` 신설

**Files:**
- Create: `plugins/spec-distill/references/research-claims.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (포인터 한 줄 — 고아 검사 때문에 같은 Task 에서 함께 넣는다)

**Interfaces:**
- Consumes: 없음
- Produces: 계약 정본의 필드 이름 집합 — `evidence[]` = `{url, supports, claim, touches, decides}` · `repo_claims[]` = `{id, path, anchor, line, claim, touches, decides}`. Task 4 의 사본(steelman-builder.md)과 Task 18 축 D 가 이 집합에 **집합 등호**로 묶인다. 상수 `RC<n>`·`OQ<n>` 토큰 표기가 Task 8(확인 줄 형식)·14(게이트 정규식)의 대상이다.

**왜 SKILL.md 를 같은 Task 에서 건드리는가** — `shared/tests/test_skill_reference_pointers.sh` 가 역방향(고아 없음)을 잰다: git-tracked `plugins/*/references/*.md` 는 어떤 SKILL.md 로부터든 가리켜져야 한다. 포인터는 **`${CLAUDE_PLUGIN_ROOT}/references/research-claims.md` 형태로 글자 그대로** 써야 해석된다(접두사 → 루트가 1:1, 열거 밖 접두사는 loud FAIL).

**이 파일이 담아서는 안 되는 토큰** (새 파일이 `test_conducting_interview_stage.sh` 의 `CI_ALL` 부재 코퍼스와 `test_stale_terms.sh` 의 `prod_files` 에 **자동으로 들어간다**):
`drafting-spec` · `no_progress_streak` · `stall_episode` · `coverage_mapper_dispatched_episode` · `pending_locked_decisions` · `teach-lite` · `teach-heavy` · `teach-beat` · `general-purpose` · `4-block` · `막힌 결정` · `interview_round` · `breadth-keeper` · `locked_directions` · `재논쟁 금지` · `Locked Directions` · `다시 묻지 않는다` · `확정·재논쟁` · `suppress_state` · `suppressed_paths` · `cancel_review` · `cancel-review` · `approve_handoff` · `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` · `FIRE_COUNT` · `compact-induction` · `compact-detect` · `review lock` · `suppressed path` · `락이 훅에` · **`§8`/`§9` 형태의 절 참조**(V11 이 은퇴 payload 좌표로 읽는다).

- [ ] **Step 1: 실패하는 락을 먼저 쓴다 — 고아 검사와 부재 스캔**

새 락 파일은 Task 18 이고, 여기서는 **기존 락 둘이 새 파일을 잡는다는 것**을 먼저 확인한다. 파일을 만들기 전에 포인터만 넣어 정방향 실패를 본다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
old = "## C43 3-path routing\n"
new = ("## 조사 주장 계약\n\n"
       "조사 주장(외부 `evidence[]` · 내부 `repo_claims[]`)의 계약 정본은\n"
       "`${CLAUDE_PLUGIN_ROOT}/references/research-claims.md` 다. 이 절은 그 파일을 dispatch 로\n"
       "**배달**하는 책임만 진다 — 계약 본문을 여기 복사하지 않는다.\n\n"
       "## C43 3-path routing\n")
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new), encoding="utf-8")
PY
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | grep -E '✗|Total'
```

Expected: FAIL — `pointer: …/SKILL.md → '${CLAUDE_PLUGIN_ROOT}/references/research-claims.md' 대상 부재` 류 실패 1건 이상.

- [ ] **Step 2: 계약 정본을 쓴다**

`plugins/spec-distill/references/research-claims.md` 전문:

````markdown
# 조사 주장 계약 — `evidence[]` 와 `repo_claims[]`

이 파일이 조사 주장 출력 계약의 **정본**이다. 네 자리가 이 계약을 쓴다 — `coverage-mapper` ·
`blind-spot-prober` · `steelman-builder` 세 dispatch 와, orchestrator 가 직접 수행하는 C43 경로 (a)
자동확인. `agents/steelman-builder.md` 에 같은 스키마의 인라인 사본이 있고, 두 곳의 필드 이름
집합은 `tests/test_research_claims_contract.sh` 축 D 가 집합 등호로 묶는다.

## 형식

```yaml
evidence:                      # 외부(웹) 주장
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: []                # 전제 P<n>
    decides: [OQ1]             # 이 주장이 닿는 «열린 결정». 빈 배열 허용
repo_claims:                   # 내부(레포) 주장
  - id: RC3                    # payload · audit 을 잇는 id
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택 — 보조 정보
    claim: "<주장>"
    touches: []                # 전제 P<n>
    decides: [OQ1]
```

## 두 필드의 뜻이 다르다

- **`touches`** 는 **전제 `P<n>`** 를 담는다.
  `${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/steelman.md` Step 2 가 그 claim 을 지목된
  전제 문장과 대조하고, Step 2.5 가 `premise_refutation.hits` 로 재검토 자격을 판정하며, 의심 게이트의
  제시 형식이 `[반증됨]` 라벨을 붙이고, audit 템플릿이 「부착 주장: <evidence #> → P<n>」 으로 직렬화한다.
- **`decides`** 는 **열린 결정 `OQ<n>`** 를 담는다. 「`<open_decisions>` 에 실제로 있는 결정 중 이
  주장이 닿는 것」이고, 목록에 없는 id 를 지어내지 않는다. **빈 배열은 허용이고 거짓 연결보다 낫다.**

같은 필드에 둘을 넣으면 위 소비 사슬 넷이 무엇을 대조해야 하는지 모른다. 낱말도 가른다 — 「부착」은
`touches` 의 기존 뜻으로만 쓰고, 새 것은 **「결정 연결」** 이라 부른다.

## 판정 전에 구현을 읽는다

> 인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을 읽어라.**

출처: `docs/archive/interview/2026-07-12-project-init-audit-interview.md`. 그 사이클은 「레포에서
auto-confirm 한 사실」 범주를 만들었다가 **4건 중 3건의 전제가 틀린 것**을 확인하고 범주 자체를
폐기했다. 틀린 것은 경로가 아니었다 — 넷 다 실재하는 파일을 가리켰고, 틀린 것은 「그 자리가 주장과
맞는가」였다. 그래서 `path` 와 `anchor` 만으로는 이 실패가 걸러지지 않는다.

## 규칙

1. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않는다. 줄번호는 보조다.
2. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 와 `decides` 를 갖는다. 둘 다 빈 배열이 허용이고
   거짓 부착·거짓 연결보다 낫다.
3. `id: RC<n>` 은 **레포 주장에만** 붙는다. 웹 주장은 payload 의 «출처키» 가 그 자리를 이미 맡는다.
4. `RC<n>` 번호는 **한 인터뷰 안에서만 유일**하다(payload + 그 audit 한 쌍의 범위). `S<N>`·`ST<N>` 과
   같은 규약이고, 코퍼스 전체의 유일성은 요구하지 않는다.
5. 계약을 못 받았으면 조사 주장을 내지 않는다 — 계약 없는 조사는 계약 있는 조사와 산출물에서
   구별되지 않는다.
````

**주의: 위 본문의 ` ```yaml ` 펜스 안에 `[OQ1]` 이 들어간다.** `check_brief.py` 는 이 파일을 읽지
않으므로 게이트와 무관하다.

Expected(Step 2 검증): `test -f plugins/spec-distill/references/research-claims.md && grep -c '^## ' plugins/spec-distill/references/research-claims.md` → 파일 실재 + `## ` 절 4개(형식 · 두 필드의 뜻이 다르다 · 판정 전에 구현을 읽는다 · 규칙).

- [ ] **Step 3: 두 락이 green 으로 돌아오는지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | tail -3
bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -3
```

Expected: 넷 다 `Fail: 0`. `test_no_new_duplication.sh` 가 RED 면 정본과 사본이 20줄 이상 완전히 같다는 뜻이다 — 정본의 주석을 사본과 다르게 쓰는 것이 해소책이고, **사본에 `copy-of:` 마커를 달지 않는다**(사본은 바이트 동일이 아니다).

- [ ] **Step 4: SKILL.md 줄 수가 천장 아래인지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: 345 (340 + 포인터 5줄). `< 388` 이어야 한다 — 헤드룸이 43줄 남는다. **이 값을 Task 마다 다시 재고 Task 11 이 최종 처분한다.**

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/references/research-claims.md \
        plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -F - <<'MSG'
feat(spec-distill): 조사 주장 계약 정본을 references/ 로 꺼낸다

계약은 이미 출하돼 있었다 — `agents/steelman-builder.md` 의 인라인 스키마 하나뿐이고 그
하나가 steelman trigger·웹 스위치 조건부였다. 정본을 파일로 꺼내 네 자리가 같은 계약을 받을
자리를 만든다. 신설 필드 둘(`decides`·`id: RC<n>`)이 여기 정의되고, 기존 `touches`(전제 P<n>)의
뜻은 바뀌지 않는다 — 소비 사슬 넷이 그 키잉에 의존한다.

OQ17 의 선례 지시(「구현을 읽어라」)와 그 출처를 담는다: 폐기된 auto-confirm 범주는 4건 중
3건이 «실재하는 경로 + 틀린 주장» 이었으므로 path+anchor 만으로는 걸러지지 않는다.

SKILL.md 에는 진입 한 줄만 둔다(고아 검사가 요구하는 `${CLAUDE_PLUGIN_ROOT}` 형태 포인터).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 3: SKILL.md 의 계약 배달 펜스 (AC3)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## 조사 주장 계약` 절 안)

**Interfaces:**
- Consumes: Task 2 의 `plugins/spec-distill/references/research-claims.md`
- Produces: 셸 변수 `CLAIMS_CONTRACT` — Task 4·5·6 의 dispatch 슬롯 `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 가 이 값을 싣는다. 마커 `<!-- claims-contract:begin -->` / `<!-- claims-contract:end -->` — Task 18 축 C·X 가 이 마커로 펜스를 잘라 차가운 셸에서 실행한다. 실패 시 rc 1 + stdout 비움.

**왜 경로가 아니라 내용인가** — 설치본에서 플러그인 캐시는 사용자 프로젝트 밖이라 subagent 의 `Read` 가 권한 거부되고, 그러면 agent 는 계약 없이 판정하면서 orchestrator 는 그것을 모른다. 이 리포는 같은 문제를 이미 풀어 두었다(`skills/reviewing-brief/SKILL.md` 의 `${PROFILE}` 관습, `test_dispatch_profile_inline.sh` 네 축).

**왜 마커가 필요한가** — 락의 축 X(차가운 셸 실행)가 성립하려면 펜스를 **결정적으로** 잘라낼 수 있어야 한다. 선례가 `<!-- profile-content:begin/end -->` 를 쓰는 것과 같은 이유다.

- [ ] **Step 1: 실패하는 락을 먼저 쓴다 (임시 검증 스크립트)**

Task 18 의 정식 락 전에, 이 Task 의 산출을 잴 최소 검증을 임시 파일로 둔다(커밋하지 않는다).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
cat > "$W/probe-fence.sh" <<'EOS'
set -u
ROOT="/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden"
SK="$ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
awk '/<!-- claims-contract:begin -->/ {g=1; next}
     /<!-- claims-contract:end -->/ {g=0}
     g && /^```bash$/ {b=1; next}
     g && b && /^```$/ {b=0; next}
     g && b' "$SK" > "$W/fence.sh"
n=$(grep -c . "$W/fence.sh" || true)
echo "fence_lines=$n"
bash -n "$W/fence.sh" && echo "syntax=ok" || echo "syntax=BROKEN"
EOS
bash "$W/probe-fence.sh"
```

Expected: `fence_lines=0` + `syntax=ok`(빈 파일은 문법 통과) — **마커가 없으므로 아직 아무것도 잘리지 않는다.** 이것이 RED 상태다.

- [ ] **Step 2: 펜스를 넣는다**

`## 조사 주장 계약` 절의 산문 뒤에 붙인다:

````markdown
`${CLAIMS_CONTRACT}` 에는 경로가 아니라 **계약 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자
프로젝트 밖이라 subagent 의 Read 가 거부된다. dispatch 직전(재dispatch 포함)에 아래 펜스를 돌려
그 stdout 전문을 세 dispatch 의 `<claims_contract>` 슬롯에 싣는다. rc 가 0 이 아니면 **그 장치를
dispatch 하지 않는다** — 인터뷰는 계속하되 그 차원을 자동으로 닫지 않고, 공시는 loud advisory +
audit §2 unavailable 사유 다.

<!-- claims-contract:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
# 경로는 `${CLAUDE_PLUGIN_ROOT}` 형태로 쓴다 — 포인터 락이 해석하는 형태는 셋뿐이고
# `$SD/references/…` 는 그 셋에 없어 거부된다(조용히 재해석하지 않는다).
CLAIMS="${CLAUDE_PLUGIN_ROOT}/references/research-claims.md"
claims_rc=0; CLAIMS_CONTRACT="$(cat "$CLAIMS")" || claims_rc=$?
if [ "$claims_rc" -ne 0 ] || [ -z "$CLAIMS_CONTRACT" ]; then
  echo "[spec-distill] 조사 주장 계약을 읽지 못했다(cat rc $claims_rc): $CLAIMS — 이 장치를 dispatch 하지 않는다. 인터뷰는 계속하고, 그 차원을 자동으로 닫지 않는다. coverage-mapper 자리면 audit §2 Budget 에 coverage-mapper 0 (unavailable: 계약 배달 실패) 를 적고, blind-spot-prober 자리면 inline premortem 으로 강등한다." >&2
  exit 1
fi
printf '%s\n' "$CLAIMS_CONTRACT"
```
<!-- claims-contract:end -->
````

Expected(Step 2 검증): `grep -c 'claims-contract:' plugins/spec-distill/skills/conducting-interview/SKILL.md` → `2`(begin · end).

- [ ] **Step 3: 펜스가 잘리고 문법이 살아 있는지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
bash "$W/probe-fence.sh"
```

Expected: `fence_lines=9` (± 공백 줄) + `syntax=ok`.

- [ ] **Step 4: 차가운 셸에서 두 방향을 실행한다 (축 X 의 예비 실측)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
SD_REAL="$(pwd)/plugins/spec-distill"
NOPROF="$W/pr-noclaims"; rm -rf "$NOPROF"; mkdir -p "$NOPROF/references"
echo "--- 실제 루트"
( env -i PATH=/usr/bin:/bin CLAUDE_PLUGIN_ROOT="$SD_REAL" bash "$W/fence.sh" ) \
  > "$W/ok.out" 2>"$W/ok.err"; echo "rc=$?"
diff <(cat "$W/ok.out") plugins/spec-distill/references/research-claims.md && echo "stdout == 계약 내용"
echo "--- 계약 없는 루트"
( env -i PATH=/usr/bin:/bin CLAUDE_PLUGIN_ROOT="$NOPROF" bash "$W/fence.sh" ) \
  > "$W/no.out" 2>"$W/no.err"; echo "rc=$?"
grep -c . "$W/no.out"
grep -o 'dispatch 하지 않는다' "$W/no.err"
```

Expected: 실제 루트 `rc=0` + `stdout == 계약 내용` · 계약 없는 루트 `rc=1` + stdout `0` 줄 + stderr 에 `dispatch 하지 않는다`.

- [ ] **Step 5: 기존 스위트 확인 + Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
for t in test_conducting_interview_stage.sh test_stale_terms.sh; do bash plugins/spec-distill/tests/$t 2>&1 | tail -2; done
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -2
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -2
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
git add plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -F - <<'MSG'
feat(spec-distill): 계약 배달 펜스 — 경로가 아니라 내용을 싣는다

설치본에서 플러그인 캐시는 사용자 프로젝트 밖이라 subagent 의 Read 가 거부되고, 그러면 agent
는 계약 없이 판정하면서 orchestrator 는 그것을 모른다. `reviewing-brief` 의 `${PROFILE}` 관습을
그대로 쓴다 — `cat` 으로 내용을 얻고 마커로 펜스를 결정적으로 잘라낼 수 있게 한다.

실패는 fail-closed 다: rc 1 이면 «그 dispatch» 를 하지 않는다. 막는 것은 dispatch 이고
인터뷰가 아니다 — 인터뷰는 계속하고 그 차원을 자동으로 닫지 않으며, 공시가 audit §2 로 간다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: 넷 다 `Fail: 0`, SKILL.md ≈ 357줄 (`< 388`).
---

### Task 4: steelman 경로 배선 — 사본 필드 둘 · 슬롯 둘 · 처분 줄

**Files:**
- Modify: `plugins/spec-distill/agents/steelman-builder.md` (`repo_claims`/`evidence` 인라인 블록 + `input_slots`)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/steelman.md` (dispatch 프롬프트 + 처분 줄 + 배달 산문)
- Modify: `plugins/spec-distill/tests/test_steelman_builder_scope.sh` (키 앵커 목록 확장)

**Interfaces:**
- Consumes: Task 2 의 필드 이름 집합 · Task 3 의 `CLAIMS_CONTRACT`
- Produces: `input_slots` 태그 `claims_contract`(var `CLAIMS_CONTRACT`, kind `repo_context`) · `open_decisions`(var `OPEN_DECISIONS`, kind `task`). Task 5·6 이 **같은 태그·같은 var·같은 kind** 를 쓴다 — `tools/adjudication/check_slots.py` 의 `var_mismatch` 가 갈라짐을 잡는다.

**선언 ↔ 전달은 한 Task 에 묶인다** — `check_slots.py` 의 축 (a) 가 양방향이다: 선언 없는 태그를 전달하면 `undeclared`, 선언했는데 전달하는 dispatch 가 없으면 `undelivered`. 그래서 agent frontmatter 와 dispatch 프롬프트는 반드시 같은 커밋에 들어간다.

**`kind:` 선택과 그 근거** (설계 `### Deferred to plan` 의 `EXEMPT_SLOTS_BASELINE` bump 여부를 여기서 해소한다):
- `claims_contract` → **`repo_context`**. `check_slots.py` 머리의 다섯 분류에서 ⓓ(리포 규약·설계 문서)다. 계약 파일은 orchestrator 의 판단이 아니라 리포의 규약이다.
- `open_decisions` → **`task`**. 같은 분류의 ⓐ(경로·enum·기계 계산 리터럴)다. 선례가 그 파일 안에 있다: `coverage-mapper.ledger_state` 를 「원장 «상태»의 요약이지 판단이 아니다 → ⓐ」로 판정했고, `open_decisions[]` 는 state 리스트의 직렬화로 같은 부류다.
- 둘 다 `ALLOWED_KINDS` 안이므로 **`EXEMPT_SLOTS` 등재도 `EXEMPT_SLOTS_BASELINE`(현재 5) bump 도 필요 없다.** Step 4 가 그것을 실측으로 확인한다.
- `_SUSPECT_VAR`(`VERDICT|SCORE|RANK|SEVERITY|CONFIDENCE`)에 두 var 이름이 걸리지 않는다.

**steelman.md 를 건드릴 때 지킬 것:**
- dispatch 는 `if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then … else … Agent({…}) … fi` 의 **`else` 가지 «안»** 에 있어야 한다. `test_conducting_interview_stage.sh:592-599` 가 `if < else < Agent < fi` 순서를 잰다. 프롬프트를 늘려도 이 순서는 바뀌지 않는다.
- 이 파일에 **`## ` 또는 `### ` 헤딩을 새로 넣지 않는다.** `r3_block` 은 `/^### R3 — Steelman/` 부터 다음 `###`/`##` 직전까지라, 새 `### ` 헤딩 하나가 그 아래 부재 락 셋을 공허하게 만든다. `#### ` 는 안전하다.
- `**처분** —` 앵커는 dispatch 줄 **아래 40줄 안**에 정확히 하나여야 한다(축 A②). 지금처럼 바로 다음 줄에 둔다.
- **축 C**: `disclosure=` 리터럴이 **그 앵커가 사는 파일의 앵커-제외 본문**에 실재해야 한다. 그래서 처분 줄의 disclosure 값과 같은 문자열을 산문에도 넣는다.

- [ ] **Step 1: 실패하는 검증을 먼저 돌린다 — 키 앵커를 락에 먼저 추가**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_steelman_builder_scope.sh")
t = p.read_text(encoding="utf-8")
old = "for tok in recommendation premise_refutation premise_list_challenge touches repo_claims anchor refined_takes refined_drops case_for_alternative case_for_current; do"
new = "for tok in recommendation premise_refutation premise_list_challenge touches decides repo_claims anchor refined_takes refined_drops case_for_alternative case_for_current; do"
assert t.count(old) == 1
t = t.replace(old, new)
# `id:` 는 리스트 첫 키라 `- ` 접두가 붙는다 — 순수 공백 앵커로는 dash 를 못 넘는다
# (evidence[].url · repo_claims[].path 가 이미 같은 이유로 `-?` 를 쓴다).
old2 = """grep -qE '^[[:space:]]*claim:' <<<"$rc_block" \\
  && ok "중첩 키 repo_claims[].claim" || no "중첩 키 repo_claims[].claim 부재\""""
new2 = old2 + """
grep -qE '^[[:space:]]*-?[[:space:]]*id:' <<<"$rc_block" \\
  && ok "중첩 키 repo_claims[].id (payload·audit 을 잇는 RC<n>)" || no "중첩 키 repo_claims[].id 부재"
grep -qE '^[[:space:]]*decides:' <<<"$rc_block" \\
  && ok "중첩 키 repo_claims[].decides (결정 연결)" || no "중첩 키 repo_claims[].decides 부재"
grep -qE '^[[:space:]]*decides:' <<<"$ev_block" \\
  && ok "중첩 키 evidence[].decides (결정 연결)" || no "중첩 키 evidence[].decides 부재"
for tag in claims_contract open_decisions; do
  grep -qE "^  - tag: ${tag}$" <<<"$fm" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재"
done"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_steelman_builder_scope.sh 2>&1 | grep -E '✗|Total'
```

Expected: FAIL — `decides`·`id`·두 슬롯 태그가 없으므로 `✗` 6건, `Fail: 6`.

- [ ] **Step 2: agent 파일에 필드 둘과 슬롯 둘을 넣는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/agents/steelman-builder.md")
t = p.read_text(encoding="utf-8")

# ① input_slots 둘 — 마지막 슬롯(constraints) 뒤에.
old = """  - tag: constraints
    var: CONSTRAINTS
    kind: artifact
"""
new = """  - tag: constraints
    var: CONSTRAINTS
    kind: artifact
  - tag: claims_contract
    var: CLAIMS_CONTRACT
    kind: repo_context
  - tag: open_decisions
    var: OPEN_DECISIONS
    kind: task
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ② evidence[] 에 decides
old = """    touches: [P1]            # 빈 배열 = 어느 전제에도 닿지 않음
"""
new = """    touches: [P1]            # 빈 배열 = 어느 전제에도 닿지 않음
    decides: [OQ1]           # 닿는 «열린 결정». 빈 배열 허용 — 거짓 연결보다 낫다
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ③ repo_claims[] 에 id · decides
old = """repo_claims:
  - path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                # 선택 — 보조 정보
    claim: "<주장>"
    touches: []
"""
new = """repo_claims:
  - id: RC3                  # payload · audit 을 잇는 id (한 인터뷰 안에서 유일)
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                # 선택 — 보조 정보
    claim: "<주장>"
    touches: []
    decides: [OQ1]
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ④ 동작 규칙 5 · 6 갱신 + 규칙 하나 추가
old = """5. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 를 갖습니다. 빈 배열은 허용이고 거짓 부착보다
   낫습니다 — 부착은 orchestrator 가 게이트 전에 확인합니다.
6. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않습니다. 줄번호는 보조입니다.
"""
new = """5. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 와 `decides` 를 갖습니다. 둘 다 빈 배열이
   허용이고 거짓 부착·거짓 연결보다 낫습니다 — 부착은 orchestrator 가 게이트 전에 확인합니다.
   `touches` 는 전제 `P<n>` 을, `decides` 는 `<open_decisions>` 의 열린 결정 `OQ<n>` 을 담습니다 —
   **다른 것을 가리키는 다른 필드**이고 서로 갈음하지 않습니다.
6. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않습니다. 줄번호는 보조입니다. `id: RC<n>` 는
   레포 주장에만 붙습니다.
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ⑤ Input 절에 슬롯 둘
old = """- `<constraints>` 사용자가 지금까지 말한 제약의 원문 전량. 이미 닫힌 경로를 대안으로 내지 않기
  위해 읽는다.
"""
new = """- `<constraints>` 사용자가 지금까지 말한 제약의 원문 전량. 이미 닫힌 경로를 대안으로 내지 않기
  위해 읽는다.
- `<claims_contract>` 조사 주장 계약의 **내용 전문**. 출력의 `evidence[]`·`repo_claims[]` 가 이 계약을
  따른다. 판정 전에 구현을 읽으라는 지시가 그 안에 있다.
- `<open_decisions>` 지금 열린 결정 목록(`OQ<n>` + 한 줄). `decides` 는 **이 목록에 실제로 있는 것**만
  담고 목록에 없는 id 를 지어내지 않는다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. `assert count == 1` 이 하나라도 깨지면 아무것도 쓰이지 않는다.

- [ ] **Step 3: steelman.md 의 dispatch 프롬프트에 슬롯 둘 + 처분 줄을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/references/steelman.md")
t = p.read_text(encoding="utf-8")

old = """  Agent({ description: "Steelman both cases", subagent_type: "spec-distill:steelman-builder",
          prompt: "의심 방향: <direction>${SUSPECT_DIRECTION}</direction>. trigger: <trigger>${TRIGGER}</trigger>. 사용자 goal(원문): <goal>${GOAL}</goal>. 핵심 전제: <premises>${PREMISES}</premises>. 사용자가 지금까지 말한 제약(원문 전량): <constraints>${CONSTRAINTS}</constraints>. 양쪽 최강 케이스를 같은 기준으로, 전제 반증 판정과 추천을." })
  # **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
"""
new = """  Agent({ description: "Steelman both cases", subagent_type: "spec-distill:steelman-builder",
          prompt: "의심 방향: <direction>${SUSPECT_DIRECTION}</direction>. trigger: <trigger>${TRIGGER}</trigger>. 사용자 goal(원문): <goal>${GOAL}</goal>. 핵심 전제: <premises>${PREMISES}</premises>. 사용자가 지금까지 말한 제약(원문 전량): <constraints>${CONSTRAINTS}</constraints>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 양쪽 최강 케이스를 같은 기준으로, 전제 반증 판정과 추천을." })
  # **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + 수동 의심 게이트 전환
"""
assert t.count(old) == 1, t.count(old)
t = t.replace(old, new)

# 계약 배달 + 처분 방향의 층위 + 축 C 의 disclosure 리터럴을 산문에 둔다.
old2 = """한 방향당 steelman 1회 — 새 근거 없으면 재steelman 금지(AP16).
"""
new2 = """한 방향당 steelman 1회 — 새 근거 없으면 재steelman 금지(AP16).

두 슬롯은 `conducting-interview/SKILL.md` 의 `## 조사 주장 계약` 펜스와 `orchestration.open_decisions[]`
에서 온다. 계약 펜스의 rc 가 0 이 아니면 **dispatch 하지 않는다** — `fail-closed` 가 막는 것은 «그
dispatch» 이고 인터뷰가 아니다. 그때 공시는 loud advisory + 수동 의심 게이트 전환 이고, 아래
「Web 부재 시 graceful degradation」 과 같은 경로로 간다(§5 항목은 사용자 판단을 근거로 기록하고
계약 배달 실패 사유를 명시한다).
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. 산문이 `loud advisory + 수동 의심 게이트 전환` 을 **글자 그대로** 담는다(축 C 가 그것을 찾는다).

- [ ] **Step 4: 네 락을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_steelman_builder_scope.sh 2>&1 | tail -2
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -4
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC8:|✗|Total'
```

Expected:
- `test_steelman_builder_scope.sh` → `Fail: 0`
- `test_agent_input_slots.sh` → `Fail: 0` 이고 «면제 목록 5 <= baseline 5» 가 보인다(**bump 불필요 확인**). `undelivered`/`undeclared`/`unknown_kind` 가 0.
- `test_dispatch_disposition.sh` → `Fail: 0`. 특히 「축 A① 앵커 수 == dispatch 수」와 「축 C disclosure 리터럴이 앵커-제외 본문에 실재한다」.
- `test_conducting_interview_stage.sh` → `Fail: 0` 이고 `AC8: steelman dispatch 가 kill switch 의 else 가지 안` 이 ✓.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/agents/steelman-builder.md \
        plugins/spec-distill/skills/conducting-interview/references/steelman.md \
        plugins/spec-distill/tests/test_steelman_builder_scope.sh
git commit -F - <<'MSG'
feat(spec-distill): steelman 경로에 계약 슬롯 둘 — 사본에도 decides·id

인라인 스키마 사본은 **남긴다**: `test_steelman_builder_scope.sh` 가 `repo_claims:`·`touches:`·
`anchor:` 를 그 파일에서 요구하고 블록을 잘라 `path`·`claim` 을 검사한다. 지우면 새 RED 0 과
동시에 성립하지 않는다. 대신 정합을 락이 지킨다 — 정본과 사본의 필드 이름 집합을 집합 등호로
묶는 축이 뒤 Task 에서 붙고, 그 축이 헛돌지 않도록 사본에도 `decides`·`id` 를 넣는다.

Step 2 「게이트-전 확인」은 그대로다 — 중복 제거하지 않는다. dispatch 의 `else` 가지 배치도
그대로다(보안 컨트롤이 그 순서를 잰다). 처분 방향만 fail-open → fail-closed 로 고친다:
막는 것은 «그 dispatch» 이고 인터뷰가 아니다.

`kind:` 는 `repo_context`(계약 = 리포 규약) · `task`(열린 결정 목록 = 원장 상태 요약)로,
둘 다 허용 어휘라 면제 등재도 baseline bump 도 없다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 5: coverage-mapper 배선 — 슬롯 둘 · 출력 의무 · AC20 검증 의무 · 처분 줄

**Files:**
- Modify: `plugins/spec-distill/agents/coverage-mapper.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## coverage-mapper dispatch` 절)
- Modify: `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`

**Interfaces:**
- Consumes: Task 4 의 태그·var·kind 삼중쌍 (`claims_contract`/`CLAIMS_CONTRACT`/`repo_context` · `open_decisions`/`OPEN_DECISIONS`/`task`) — **글자째 같아야 한다**
- Produces: AC20 의무 문면 — Task 8 의 V1 이 그 산출을 받는다.

**AC20 의 범위는 좁혀져 있다** — seed 의 «다시 검증할 것» 문단 중 **레포로 확인 가능한 항목마다** `repo_claims` 를 산출해 V1 을 태울 의무다. 「사용자만 답할 수 있는 것」·「인과 추정」은 대상이 아니다(이 사이클 seed 의 그 문단 여섯 항목 중 레포 대상은 둘뿐이었다). 그 문단이 비었으면(규약 위반 seed — 슬롯 주석이 명시 허용) 의무는 **미발동**이고 그 사실을 audit §5 에 한 줄로 공시한다. **Phase 0 은 건드리지 않는다** ⟨C4⟩.

**갱신해야 하는 기존 단언 둘** (`test_conducting_interview_stage.sh`):
- 단언 `C4: 재개방 시 최대 1회` — 예산이 `1 + Σ(재개방)` 이 되므로 이 문구가 사라진다(Task 11).
- 단언 `C4: 상한 2 + 카운터` — 같은 이유(Task 11). **둘 다 줄 번호가 아니라 이 메시지로 찾는다** —
  앞뒤 Task 들의 편집으로 번호가 밀린다.
두 단언은 Task 11 이 자격·예산과 함께 고친다. **이 Task 는 그 두 문구를 건드리지 않는다** — 슬롯·출력 의무만 더한다.

- [ ] **Step 1: 실패하는 락을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh")
t = p.read_text(encoding="utf-8")
old = """grep -q 'neglect_flag' "$AGENT" \\
  && ok "Output: neglect_flag 키 존재" || no "neglect_flag 키 부재"
finish"""
new = """grep -q 'neglect_flag' "$AGENT" \\
  && ok "Output: neglect_flag 키 존재" || no "neglect_flag 키 부재"

# 조사 주장 계약 배선 — 슬롯 둘의 선언과 출력 의무. 슬롯의 var·kind 는 형제 둘과 글자째 같아야
# 한다(`tools/adjudication/check_slots.py` 의 var_mismatch 가 갈라짐을 잡지만, 그 락이 죽으면
# 이 자리가 마지막 방어선이다).
for tag in claims_contract open_decisions; do
  grep -qE "^  - tag: ${tag}$" <<<"$FM" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재"
done
grep -q 'var: CLAIMS_CONTRACT' <<<"$FM" && ok "슬롯 var CLAIMS_CONTRACT" || no "슬롯 var CLAIMS_CONTRACT 부재"
grep -q 'var: OPEN_DECISIONS' <<<"$FM" && ok "슬롯 var OPEN_DECISIONS" || no "슬롯 var OPEN_DECISIONS 부재"
grep -q 'kind: repo_context' <<<"$FM" && ok "claims_contract 의 kind 가 repo_context" || no "kind: repo_context 부재"
# 출력 의무 — 스키마 키 둘이 본문에 실재한다(존재 검사라 frontmatter 를 뺀 본문에서 잰다:
# description 이 같은 낱말을 담아도 출력 스키마를 지우면 RED 다).
BODY="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$AGENT")"
for tok in repo_claims evidence decides; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${tok}:" <<<"$BODY" \\
    && ok "출력 의무: $tok 키가 본문 스키마에 있다" || no "출력 의무: $tok 키 부재"
done
finish"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh 2>&1 | grep -E '✗|Total'
```

Expected: FAIL — `✗` 8건 (슬롯 태그 2 · var 2 · kind 1 · 출력 의무 3), `Fail: 8`.

- [ ] **Step 2: agent 파일에 슬롯 둘과 출력 의무를 넣는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/agents/coverage-mapper.md")
t = p.read_text(encoding="utf-8")

old = """  - tag: web_disabled
    var: WEB_DISABLED
    kind: task
"""
new = """  - tag: web_disabled
    var: WEB_DISABLED
    kind: task
  - tag: claims_contract
    var: CLAIMS_CONTRACT
    kind: repo_context
  - tag: open_decisions
    var: OPEN_DECISIONS
    kind: task
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """- (있으면) 현재까지의 사용자 제약 요지, External Landscape 발췌.
"""
new = """- (있으면) 현재까지의 사용자 제약 요지, External Landscape 발췌.
- `<claims_contract>` 조사 주장 계약의 **내용 전문**. 아래 출력의 `evidence[]`·`repo_claims[]` 가
  이 계약을 따른다.
- `<open_decisions>` 지금 열린 결정 목록(`OQ<n>` + 한 줄). `decides` 는 이 목록에 실제로 있는 것만
  담고 목록에 없는 id 를 지어내지 않는다.
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """neglected_dimensions:
  - "<focused 집중으로 방치된 차원 이름>"
confidence: 0.0-1.0
```
"""
new = """neglected_dimensions:
  - "<focused 집중으로 방치된 차원 이름>"
confidence: 0.0-1.0
evidence:                      # 외부(웹) 주장 — <claims_contract> 계약 그대로
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: []                # 전제 P<n>
    decides: [OQ1]             # 닿는 «열린 결정». 빈 배열 허용
repo_claims:                   # 내부(레포) 주장 — 같은 계약
  - id: RC3
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택
    claim: "<주장>"
    touches: []
    decides: [OQ1]
```
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """5. **confidence < 0.5** 면 `neglect_flag: false` — 약한 신호로 산만하게 하지 않음.
"""
new = """5. **confidence < 0.5** 면 `neglect_flag: false` — 약한 신호로 산만하게 하지 않음.
6. **차원 제안의 근거를 주장으로 낸다.** 제안한 차원마다 그것을 요구하는 근거를 `repo_claims[]`
   (레포) 또는 `evidence[]`(웹) 로 함께 내고, 레포 주장은 `path`·`anchor` 없이 내지 않는다.
   판정 전에 구현을 읽는다 — 인덱스·목차·description 필드만 읽고 판정하지 않는다.
7. **계약을 못 받았으면**(`<claims_contract>` 가 비었으면) 주장을 내지 않고 그 사실을 첫 줄에
   적는다. 계약 없는 조사는 계약 있는 조사와 산출물에서 구별되지 않는다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh 2>&1 | tail -2
```

Expected: `ok` 다음 `Fail: 0`.

- [ ] **Step 3: SKILL.md dispatch 에 슬롯 둘 · 처분 줄 · AC20 의무**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")

old = '''        prompt: "seed 원문 전량(§6 S1 이 될 값 그대로): <seed>${SEED_TEXT}</seed>. seed 의 «다시 검증할 것 —» 문단(Phase 0 이 추론·외부·열린 것으로 아는 항목. 규약 위반 seed 면 빈 값): <reverify>${SEED_REVERIFY}</reverify>. coverage 원장 상태(열린/닫힌 차원 요약 · focused_dimension · 재개방이면 reopen_log 마지막 항목): <ledger_state>${LEDGER_STATE}</ledger_state>. web_disabled(true면 WebSearch/WebFetch 사용 금지, codebase 근거만): <web_disabled>${WEB_DISABLED}</web_disabled>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
// **처분** — consumer=orchestrator · fail-open · disclosure=advisory
'''
new = '''        prompt: "seed 원문 전량(§6 S1 이 될 값 그대로): <seed>${SEED_TEXT}</seed>. seed 의 «다시 검증할 것 —» 문단(Phase 0 이 추론·외부·열린 것으로 아는 항목. 규약 위반 seed 면 빈 값): <reverify>${SEED_REVERIFY}</reverify>. coverage 원장 상태(열린/닫힌 차원 요약 · focused_dimension · 재개방이면 reopen_log 마지막 항목): <ledger_state>${LEDGER_STATE}</ledger_state>. web_disabled(true면 WebSearch/WebFetch 사용 금지, codebase 근거만): <web_disabled>${WEB_DISABLED}</web_disabled>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + audit §2 unavailable 사유
'''
assert t.count(old) == 1, t.count(old)
t = t.replace(old, new)

old2 = """출력(`derived_dimensions[] + neglect_flag`)은 **advisory** — orchestrator가 원장에 admit할지 판정한다.
`neglect_flag: true`면 다음 probe에서 neglected 차원 하나를 추천 답안으로 제시. 복수 dispatch 시
name 기준 union·dedup.
"""
new2 = """출력(`derived_dimensions[] + neglect_flag` + `evidence[]`/`repo_claims[]`)은 **advisory** —
orchestrator가 원장에 admit할지 판정한다. `neglect_flag: true`면 다음 probe에서 neglected 차원
하나를 추천 답안으로 제시. 복수 dispatch 시 name 기준 union·dedup. 주장은 «지금 이해»에 싣기 전에
라운드 규약의 V1 을 탄다.

**계약 배달 실패 시** — `## 조사 주장 계약` 펜스의 rc 가 0 이 아니면 이 dispatch 를 하지 않는다.
인터뷰는 계속하고, 그 차원을 자동으로 닫지 않으며, 공시는 loud advisory + audit §2 unavailable 사유
다: audit §2 Budget 의 불릿 줄에 `coverage-mapper 0 (unavailable: 계약 배달 실패)` 를 적는다 —
게이트가 advisory 로 통과시키고 Step B 가 사람에게 보인다.

**첫 dispatch 의 검증 의무(D6)** — seed 의 «다시 검증할 것» 문단 중 **레포로 확인 가능한 항목마다**
`repo_claims` 를 산출해 V1 을 태운다. 「사용자만 답할 수 있는 것」과 「인과 추정」은 대상이 아니다.
그 문단이 비어 있으면(규약 위반 seed — 위 슬롯 주석이 명시 허용) 이 의무는 미발동이고, 그 사실을
audit §5 에 한 줄로 공시한다. Phase 0 은 건드리지 않는다 — 의무는 받는 쪽에 있다.
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. 처분 줄이 `fail-(open|closed)` 뒤에 ` · disclosure=` 만 갖고 **괄호 주석이 없다**(락의 `FIELD` 정규식). disclosure 리터럴 `loud advisory + audit §2 unavailable 사유` 가 바로 아래 산문에 글자 그대로 있다(축 C).

- [ ] **Step 4: 락 넷**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh 2>&1 | tail -2
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -4
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
bash plugins/spec-distill/tests/test_web_kill_switch.sh 2>&1 | tail -2
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: 다섯 다 `Fail: 0` — **단 `test_conducting_interview_stage.sh` 의 `C4: 재개방 시 최대 1회`·`C4: 상한 2 + 카운터` 는 아직 green 이다**(이 Task 가 그 문구를 건드리지 않았으므로). SKILL.md ≈ 374줄. `< 388` 확인.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/agents/coverage-mapper.md \
        plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh
git commit -F - <<'MSG'
feat(spec-distill): coverage-mapper 에 계약 슬롯 둘 + 출력 의무 + D6 검증 의무

「전담 장치」의 판별은 도구 부분집합이 아니라 **출력 의무**다 — 세 조사 agent 가 이미 같은
`tools:` 를 갖고 있어 능력을 더하는 것은 새 파일이 될 뿐이다. 그래서 같은 계약을 이 자리에도
걸고 차원 제안의 근거를 주장으로 내게 한다.

D6(검증 축)의 집행 손잡이를 첫 dispatch 절에 둔다 — seed 의 «다시 검증할 것» 중 레포로 확인
가능한 항목마다 주장을 산출해 V1 을 태운다. 그 문단이 비면 미발동이고 audit §5 에 공시한다.
Phase 0 은 건드리지 않는다.

처분 방향을 fail-closed 로 고치고 공시 리터럴을 산문에 함께 둔다 — 락의 축 C 는 disclosure
리터럴이 같은 파일의 앵커-제외 본문에 실재할 것을 요구한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 6: blind-spot-prober 배선 — 슬롯 둘 · 출력 의무 · 처분 줄

**Files:**
- Modify: `plugins/spec-distill/agents/blind-spot-prober.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## blind-spot-prober dispatch` 절)
- Modify: `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`

**Interfaces:**
- Consumes: Task 4·5 의 태그·var·kind 삼중쌍 (같은 글자)
- Produces: web-off 강등 경로에서도 같은 계약을 쓰는 inline premortem 규약 — Task 20 의 web-off 실측이 이것을 잰다.

**E10 락을 밟지 않는다** — `test_blind_spot_prober_frontmatter.sh:45` 가 이 파일에 대해 `최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|[0-9]-[0-9]회|max_[a-z_]+ *= *[0-9]` 부재를 요구한다. 그래서 예산 문구는 `1 + 재개방 횟수` 처럼 쓰고 `최대 N회`·`N회까지`·`N-N회` 를 쓰지 않는다. (상한 문구 자체의 교체는 Task 11 이다 — 이 Task 는 슬롯·출력 의무만.)

- [ ] **Step 1: 실패하는 락을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh")
t = p.read_text(encoding="utf-8")
old = """if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  no "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  ok "E10: 병렬 금지 문구 없음"
fi
finish"""
new = """if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  no "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  ok "E10: 병렬 금지 문구 없음"
fi

# 조사 주장 계약 배선 — 형제 둘과 글자째 같은 삼중쌍.
for tag in claims_contract open_decisions; do
  grep -qE "^  - tag: ${tag}$" <<<"$FM" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재"
done
grep -q 'var: CLAIMS_CONTRACT' <<<"$FM" && ok "슬롯 var CLAIMS_CONTRACT" || no "슬롯 var CLAIMS_CONTRACT 부재"
grep -q 'var: OPEN_DECISIONS' <<<"$FM" && ok "슬롯 var OPEN_DECISIONS" || no "슬롯 var OPEN_DECISIONS 부재"
grep -q 'kind: repo_context' <<<"$FM" && ok "claims_contract 의 kind 가 repo_context" || no "kind: repo_context 부재"
BODY="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$AGENT")"
for tok in repo_claims decides; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${tok}:" <<<"$BODY" \\
    && ok "출력 의무: $tok 키가 본문 스키마에 있다" || no "출력 의무: $tok 키 부재"
done
finish"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh 2>&1 | grep -E '✗|Total'
```

Expected: `✗` 7건, `Fail: 7`.

- [ ] **Step 2: agent 파일을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/agents/blind-spot-prober.md")
t = p.read_text(encoding="utf-8")

old = """  - tag: framing
    var: FRAMING
    kind: orchestrator_framing
"""
new = """  - tag: framing
    var: FRAMING
    kind: orchestrator_framing
  - tag: claims_contract
    var: CLAIMS_CONTRACT
    kind: repo_context
  - tag: open_decisions
    var: OPEN_DECISIONS
    kind: task
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """- (있으면) External Landscape 발췌.
"""
new = """- (있으면) External Landscape 발췌.
- `<claims_contract>` 조사 주장 계약의 **내용 전문**. 아래 출력의 주장이 이 계약을 따른다.
- `<open_decisions>` 지금 열린 결정 목록(`OQ<n>` + 한 줄). `decides` 는 이 목록에 실제로 있는 것만
  담고 목록에 없는 id 를 지어내지 않는다.
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """failure_modes:
  - mode: "<구체적 실패 양식>"
    trigger: "<이 실패를 촉발하는 조건>"
    evidence:
      - "https://..."
confidence: 0.0-1.0
```
"""
new = """failure_modes:
  - mode: "<구체적 실패 양식>"
    trigger: "<이 실패를 촉발하는 조건>"
    evidence:
      - "https://..."
confidence: 0.0-1.0
repo_claims:                   # 내부(레포) 주장 — <claims_contract> 계약 그대로
  - id: RC3
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택
    claim: "<주장>"
    touches: []                # 전제 P<n>
    decides: [OQ1]             # 닿는 «열린 결정». 빈 배열 허용
```
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """5. **confidence < 0.4** 면 "표면화된 blind-spot 약함 — framing 견고"를 명시(억지 premortem 금지).
"""
new = """5. **confidence < 0.4** 면 "표면화된 blind-spot 약함 — framing 견고"를 명시(억지 premortem 금지).
6. **숨은 가정의 근거를 레포에서 댈 수 있으면 `repo_claims[]` 로 낸다.** `path`·`anchor` 없이
   내지 않고, 판정 전에 구현을 읽는다 — 인덱스·목차·description 필드만 읽고 판정하지 않는다.
7. **계약을 못 받았으면**(`<claims_contract>` 가 비었으면) 주장을 내지 않고 그 사실을 첫 줄에 적는다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh 2>&1 | tail -2
```

Expected: `ok` 다음 `Fail: 0`.

- [ ] **Step 3: SKILL.md dispatch 에 슬롯 둘 · 처분 줄 · 강등 규약**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")

old = '''        prompt: "지금까지의 framing(재구성된 문제정의 + 사용자 제약 요지): <framing>${FRAMING}</framing>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
'''
new = '''        prompt: "지금까지의 framing(재구성된 문제정의 + 사용자 제약 요지): <framing>${FRAMING}</framing>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + inline premortem 강등
'''
assert t.count(old) == 1, t.count(old)
t = t.replace(old, new)

old2 = """«지금 이해»에 실어 사용자 처분 S 를 받은 뒤 `blind_spot` floor 차원을 closed 로 전이한다. web 비활성 시 advisory:
`[spec-distill] web 비활성 — blind-spot-prober 자동 생략, inline premortem으로 전환`.
"""
new2 = """«지금 이해»에 실어 사용자 처분 S 를 받은 뒤 `blind_spot` floor 차원을 closed 로 전이한다. web 비활성 시 advisory:
`[spec-distill] web 비활성 — blind-spot-prober 자동 생략, inline premortem으로 전환`.

**계약 배달 실패 시** — `## 조사 주장 계약` 펜스의 rc 가 0 이 아니면 이 dispatch 를 하지 않는다.
공시는 loud advisory + inline premortem 강등 이고, web 비활성 경로와 같은 곳으로 간다. 인터뷰는
계속하고 그 차원을 자동으로 닫지 않는다.

**강등된 inline premortem 도 같은 계약을 쓴다** — orchestrator 가 자기 `Read`/`Grep` 으로 레포
근거를 확인하고 `repo_claims` 를 산출해 V1 을 태운다. 웹 근거만 사라지고 내부 축은 돈다.
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. `inline premortem 강등` 이 바로 아래 산문에 글자 그대로 있다(축 C).

- [ ] **Step 4: 락 다섯**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh 2>&1 | tail -2
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -4
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
bash plugins/spec-distill/tests/test_web_kill_switch.sh 2>&1 | tail -2
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: 다섯 다 `Fail: 0`. 「축 A① 앵커 수 == dispatch 수」가 여전히 ✓ (**새 dispatch 자리를 만들지 않았다** — AC24). SKILL.md ≈ 384줄 — **`< 388` 의 마지막 여유다. Task 8 이 넘길 것이므로 Task 7 이 천장을 처분한다.**

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/agents/blind-spot-prober.md \
        plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh
git commit -F - <<'MSG'
feat(spec-distill): blind-spot-prober 에 계약 슬롯 둘 + 출력 의무

세 dispatch 자리가 이제 같은 계약을 받는다. 자리는 셋으로 고정이다 — 네 번째(기본 탑재 탐색
subagent 배선)를 만들지 않는다: 락이 dispatch 대상 집합을 `plugins/*/agents/*.md` 의 `name:` 에서
도출하므로 기본 탑재 subagent 는 그 집합 밖이고, 처분 앵커만 +1 되어 「앵커 수 == dispatch 수」가
red 가 된다. C43 경로 (a) 는 orchestrator 가 직접 수행한다.

강등된 inline premortem 도 같은 계약을 쓴다 — 웹 근거만 사라지고 내부 축은 돈다. 이 주장은
릴리스 Task 의 web-off 실측이 잰다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```
---

### Task 7: SKILL.md 줄 수 천장 처분과 로드 표면 순증 실측

**Files:**
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (두 천장 단언)

**Interfaces:**
- Consumes: Task 1 의 `SKILL_LINES` baseline (340) · Task 2·3·5·6 의 누적 증가
- Produces: 새 천장 값 둘 — Task 6·8·10·11 이 이 값 아래에 머무는지 매 Step 에서 확인한다. 그리고 `loadsurface.txt` — Task 20 의 CHANGELOG 항목이 이 실측값을 인용한다.

**왜 이 Task 가 여기 있는가** — `test_conducting_interview_stage.sh` 는 SKILL.md 줄 수에 **순감 래칫 둘**을 걸어 두었다: `:366` `< 388` 과 `:393` `< 408`. 무게 감축 작업이 세운 것이다. 이 설계는 로드 표면 순증을 **명시적으로 수용**했고(L7: 「삭제가 0이므로 새 reference 1 + 슬롯 둘 + 술어 다섯이 그대로 더해진다. ⟨C8⟩ 이 그 대가를 명시적으로 수용했고 양은 계획 단계가 실측한다」) `### Deferred to plan` 이 「로드 표면 순증 실측」을 계획에 넘겼다. **래칫을 «없애지» 않고 «실측값 + 1» 로 다시 조인다** — 래칫이 래칫으로 남는다.

**Task 6·8·10·11 이 더 쓸 양의 예측** (Step 1 이 실측으로 교체한다): V1 ≈ 10줄 · C43 행 ≈ 0줄(같은 줄 교체) · state `open_decisions[]` 블록 ≈ 9줄 · 자격·예산 ≈ 12줄 · C44 면제 ≈ 7줄 ⇒ ≈ 38줄.

- [ ] **Step 1: 현재값과 남은 예측을 한 표로 낸다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
now=$(wc -l < "$SK"); echo "now=$now  baseline=340  delta=$((now-340))"
grep -n 'SKILL.md 줄 수' plugins/spec-distill/tests/test_conducting_interview_stage.sh
# 남은 SKILL.md 편집자의 예측은 **관측된 증가율**에서 낸다(계획의 옛 추정 38 은 과소였다):
#   Task 2 +6 · Task 3 +21 · Task 5 +11 이 실측이고, 남은 것은 Task 6 ≈+11 · Task 8 ≈+18 ·
#   Task 9 ≈0(같은 줄 교체) · Task 10 ≈+19 · Task 11 ≈+31 = **≈+79**.
echo "남은 예측 ≈79 → 예상 최종 ≈$((now+79))"
```

Expected: `now=378 baseline=340 delta=38`, 두 천장 `388`·`408`, 예상 최종 ≈`457`. **457 > 408 이므로 천장 둘 다 올려야 하고, 이 Task 는 Task 6 «앞»에서 돈다** — Task 6 만으로 이미 ≈389 가 되어 `< 388` 에 부딪히기 때문이다(Ruling 18).

측정값이 다르면 그 값을 보고하고 남은 예측을 그 자리에서 다시 계산한다. **이 문서의 숫자를 기대값으로 고정하지 않는다** — 관측된 증가율이 계획의 추정보다 정확했다는 것이 이 Task 의 교훈이다.

- [ ] **Step 2: 천장을 «예상 최종 + 8» 로 올린다 — 근거를 주석으로 함께 적는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")

old = '''[[ "$(wc -l < "$SKILL")" -lt 388 ]] \\
  && ok "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") < 388 (순감)" \\
  || no "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 388"'''
new = '''# 2026-09-23 조사 특화: 래칫을 **올린다**(없애지 않는다). 이 설계는 로드 표면 순증을 명시적으로
# 수용했고(설계 L7 · ⟨C8⟩), 더해지는 것은 계약 배달 펜스 · dispatch 슬롯 넷 · V1 검문소 ·
# state 키 둘 · 자격·예산 · C44 면제 규칙이며 **삭제가 0** 이다.
#
# **이 값은 잠정이다.** 한 번에 정한 값은 중간에는 너무 빡빡해 정당한 편집을 막고, 끝에는 너무
# 느슨해 래칫이 뜻을 잃는다 — 이 브랜치가 실측으로 그것을 보였다(원래 계획의 430 은 남은 편집을
# 과소 예측한 값이었다). 그래서 여기서는 **남은 편집을 다 받을 만큼** 열어 두고, SKILL.md 를
# 마지막으로 편집하는 Task 11 이 그 자리에서 **실측 + 8** 로 조인다. 래칫의 뜻은 끝에서 지켜진다.
[[ "$(wc -l < "$SKILL")" -lt 480 ]] \\
  && ok "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") < 480 (조사 특화 순증 수용 — 잠정, Task 11 이 조인다)" \\
  || no "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 480"'''
assert t.count(old) == 1, "천장 1 앵커 불일치"
t = t.replace(old, new)

old2 = '''[[ "$(wc -l < "$SKILL")" -lt 408 ]] && ok "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") < 408 (순감)" || no "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 408"'''
new2 = '''[[ "$(wc -l < "$SKILL")" -lt 480 ]] && ok "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") < 480 (조사 특화 순증 수용 — 잠정, Task 11 이 조인다)" || no "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 480"'''
assert t.count(old2) == 1, "천장 2 앵커 불일치"
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. 두 천장이 같은 값(480)이 된다 — 다른 값 둘을 두면 어느 쪽이 실제 상한인지 모호해진다. **이 값은 잠정이고 Task 11 이 실측 + 8 로 조인다.**

- [ ] **Step 3: 로드 표면 순증을 배포 경로에서 실측한다**

격리 설치로 재지 않고 **파일 바이트**로 잰다(격리 설치 실측은 이 작업의 산출물이 아니다 — 필요한 값은 「하류가 매 세션 읽는 양이 얼마나 늘었나」다). 조건부 로드되는 reference 는 따로 센다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
L="$W/loadsurface.txt"; : > "$L"
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
{
  echo "# 무조건 로드 (SKILL.md 본문)"
  printf 'SKILL.md\t%s줄\t%s바이트\n' "$(wc -l < $SK)" "$(wc -c < $SK)"
  git show HEAD~4:plugins/spec-distill/skills/conducting-interview/SKILL.md > /tmp/sk-base.md 2>/dev/null \
    && printf 'SKILL.md(착수 전)\t%s줄\t%s바이트\n' "$(wc -l < /tmp/sk-base.md)" "$(wc -c < /tmp/sk-base.md)"
  echo "# 조건부 로드 (dispatch 시에만)"
  printf 'references/research-claims.md\t%s줄\t%s바이트\n' \
    "$(wc -l < plugins/spec-distill/references/research-claims.md)" \
    "$(wc -c < plugins/spec-distill/references/research-claims.md)"
} | tee "$L"
```

Expected: 세 줄 + 헤더. **이 값을 Task 20 의 CHANGELOG 가 인용한다.** `git show HEAD~4` 가 실패하면 `git log --oneline -6` 으로 착수 전 커밋(`a539f038`)을 찾아 그 경로로 다시 잰다.

- [ ] **Step 4: 락이 green 인지 확인 + 변이 하나로 이빨을 잰다**

래칫을 올린 뒤 **그 래칫이 여전히 이빨을 갖는지** 확인한다(green-expected 단언은 모양으로 이빨을 판별할 수 없다).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수|Total'
echo "--- 변이: SKILL.md 에 120줄을 더해 래칫이 RED 를 내는지 (잠정 천장 480 을 확실히 넘는 폭)"
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
cp "$SK" "$W/skill.bak"
python3 -c "
import pathlib; p=pathlib.Path('$SK'); p.write_text(p.read_text(encoding='utf-8')+'\n'*120, encoding='utf-8')"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수'
cp "$W/skill.bak" "$SK"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수|Total'
```

Expected: 변이 전 ✓ 둘 → 변이 후 **✗ 둘** → 복원 후 ✓ 둘 + `Fail: 0`. 변이 후 ✓ 가 나오면 래칫이 이빨을 잃은 것이므로 값을 다시 계산한다. 120줄은 잠정 천장 480 을 확실히 넘기려는 폭이고, 이 Task 가 끝난 직후의 실제 줄 수와 무관하게 발화해야 한다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git status --porcelain   # test_conducting_interview_stage.sh 하나만 나와야 한다
git add plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
test(spec-distill): SKILL.md 순감 래칫을 순증 수용으로 다시 조인다

무게 감축이 세운 래칫 둘(< 388 · < 408)이 이 설계와 충돌한다 — 설계 L7 이 「삭제가 0이므로
새 reference 1 + 슬롯 둘 + 술어 다섯이 그대로 더해진다」로 순증을 명시적으로 수용했고 ⟨C8⟩ 이
그 대가를 받아들였으며, 양을 재는 것이 계획의 이월 항목이었다.

래칫을 «없애지» 않고 «실측 + 8» 로 다시 조인다: 다음 편집이 8줄 넘게 늘리면 다시 소리가 난다.
값이 둘로 갈리지 않게 두 단언을 같은 값으로 맞춘다.

이빨 확인: 120줄 변이가 두 단언을 RED 로 만드는 것을 실측했다(잠정 천장 480 을 확실히 넘기는 폭).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 8: V1 검문소 — 라운드 규약 안의 무조건 확인 (AC6)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## 라운드 규약` 절)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (V1 단언 추가)

**Interfaces:**
- Consumes: Task 2 의 `RC<n>` 토큰 · Task 5·6 의 주장 산출
- Produces: audit §5 확인 줄의 **정본 형식** — Task 12(finishing.md V2) · Task 13(audit 템플릿) · Task 17(게이트 술어 ⑤) 세 소비자가 이 문면을 그대로 쓴다:
  ```
  - 확인 RC3 — 확인 — plugins/spec-distill/scripts/check_brief.py#coverage_anchor_failures — 주장과 일치
  - 확인 RC4 — 반증 — <경로>#<앵커> — 그 자리는 <실제>이고 주장은 <주장>이었다
  - 확인 RC5 — 미확인 — <경로>#<앵커> — <왜 확정하지 못했는가>
  ```

**왜 라운드 «안» 인가** — 라운드 1 리뷰가 검문소의 시점을 반증했다: `finishing.md` Step A 는 floor 5 가 **전부 닫힌 뒤**에만 읽히므로(「읽어야 하는 조건: `coverage.floor` 의 다섯 차원이 모두 `status: closed`」) 거기서만 확인하면 반증이 마지막 사용자 라운드 «후» 에 나오고 방향에 영향 줄 라운드가 없다. ⟨C11⟩ 을 구조적으로 못 맞춘다.

**steelman 은 자기 Step 2 를 그대로 유지한다** — V1 은 그 절차를 조사 전체로 일반화한 것이고 steelman 경로는 Step 2 가 V1 의 특수 경우다. 즉 **확인 «행위» 는 한 번**이고 **기록만 두 자리**다(audit §3 `ST<N>` 블록 + audit §5 `확인 RC<n>`). 그 중복이 설계 L10 의 대가다.

**넣는 자리** — `## 라운드 규약` 의 불릿 목록 끝(«답은 `user_statements` 에 …» 뒤). `round_block` 은 `awk '/^```/{c=!c} /^## 라운드 규약/{f=1;print;next} !c && /^## /{f=0} f'` 로 뜨므로 그 절 안이면 잡힌다. **펜스를 새로 열지 않는다**(펜스 안 `## ` 는 무해하지만 불필요한 복잡성이다).

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = """for tok in 'Q1' 'Q2' 'provisional_on' '블록 없이' '직전 답에서'; do"""
new = """# V1 검문소 — 조사 주장을 «지금 이해»에 싣기 **전에** 도는 무조건 확인(설계 §D).
# 라운드 «안» 이라야 반증이 방향에 영향을 줄 라운드가 남는다 — `finishing.md` 는 floor 5 가
# 전부 닫힌 뒤에만 읽히므로 거기서만 확인하면 반증이 마지막 라운드 «후» 에 나온다.
round_flat="$(tr '\\n' ' ' <<<"$round_block" | tr -s ' ')"
{ [[ -n "$round_block" ]] && grep -qF 'V1' <<<"$round_block"; } \\
  && ok "V1: 라운드 규약 절에 V1 검문소가 있다" || no "V1: 라운드 규약 절에 V1 검문소 부재"
for step in '경로 실재' '앵커 실재' '주장이 그 자리와 맞는가'; do
  grep -qF -- "$step" <<<"$round_flat" \\
    && ok "V1: 단계 «${step}»" || no "V1: 단계 «${step}» 부재"
done
grep -qE '확인[^.]{0,6}반증[^.]{0,6}미확인' <<<"$round_flat" \\
  && ok "V1: 결과 어휘 셋 {확인, 반증, 미확인}" || no "V1: 결과 어휘 셋 부재"
grep -qF '확인 RC' <<<"$round_block" \\
  && ok "V1: audit §5 확인 줄 형식(확인 RC<n> — …)" || no "V1: audit §5 확인 줄 형식 부재"
# 비종속 — trigger 도 웹 스위치도 이 검문소를 끄지 않는다. 문구로 못 박는다(설계 AC6).
grep -qF 'steelman trigger 와 DEVBREW_SPEC_DISTILL_DISABLE_WEB 어느 것에도 종속되지 않는다' <<<"$round_flat" \\
  && ok "V1: trigger·웹 스위치 비종속 명시" || no "V1: 비종속 문구 부재 — 조건부로 읽힐 수 있다"
# §3 은 순회 범위 밖이라는 것도 여기서 못 박는다(자기지시 방지 — 설계 §E).
grep -qF '§3 은 연결의 대상이고 출처가 아니다' <<<"$round_flat" \\
  && ok "V1: §3 이 대상이고 출처가 아님을 명시" || no "V1: §3 의 역할 구분 부재"

""" + anchor
assert t.count(anchor) == 1
p.write_text(t.replace(anchor, new), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
```

Expected: `✗` 8건, `Fail: 8`.

- [ ] **Step 2: V1 을 라운드 규약에 넣는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
old = """- 답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`, «기타» 자유 입력 = `verbatim`).
  번호 공식은 «사용자 발화 기록» 절 그대로.
"""
new = """- 답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`, «기타» 자유 입력 = `verbatim`).
  번호 공식은 «사용자 발화 기록» 절 그대로.
- **V1 검문소 — 조사 주장을 «지금 이해»에 싣기 전에.** 계약(`## 조사 주장 계약`)이 산출한
  `repo_claims[]` 항목마다 orchestrator 가 자기 `Read`/`Grep` 으로 ① 경로 실재 → ② 앵커 실재 →
  ③ **주장이 그 자리와 맞는가**(구현을 읽는다 — 인덱스·목차·description 필드만 읽고 판정하지
  않는다) 를 확인하고 ④ 결과를 {확인, 반증, 미확인} 중 하나로 정한 뒤 ⑤ `id: RC<n>` 을 붙여 audit
  `## 5. 프로세스 로그` 에 한 줄로 적는다: `- 확인 RC3 — 확인 — <경로>#<앵커> — 주장과 일치` /
  `- 확인 RC4 — 반증 — <경로>#<앵커> — 그 자리는 <실제>이고 주장은 <주장>이었다` /
  `- 확인 RC5 — 미확인 — <경로>#<앵커> — <왜 확정하지 못했는가>`. `미확인` 은 라벨로 **보인다** —
  조용히 흡수하지 않는다. 이 검문소는 **steelman trigger 와 DEVBREW_SPEC_DISTILL_DISABLE_WEB 어느
  것에도 종속되지 않는다.** steelman 경로는 `references/steelman.md` Step 2 가 V1 의 특수 경우이므로
  두 번 확인하지 않고, 판정만 audit §3 `ST<N>` 과 §5 양쪽에 적는다. 판정이 `반증` 이면 그 항목이
  닿는 확정을 payload §5 에 *원래 / 재결정 / 근거* 세 칸으로 남기고(재결정 자체는 사용자 동의로만
  한다 — P23), 그 차원을 재개방할 수 있다.
- **결정 연결은 §4·§5 에 달고 §3·§0 이 그것을 되가리킨다.** 조사 항목 줄 끝에
  `[RC3 → OQ1]`(레포) · `[→ OQ1]`(웹) · `[→ 없음]`(닿는 결정 없음) 중 하나를 쓴다. 하위 불릿은
  쓰지 않는다 — 게이트가 들여쓴 불릿도 §4 항목으로 세므로 즉시 red 다. **§3 은 연결의 대상이고
  출처가 아니다** — §3 항목은 그 자체가 열린 결정이라 거기에 연결을 걸면 자기지시가 된다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: `ok` 다음 **`Fail: 1`** — V1 단언 여덟은 green 이 되지만 같은 편집이 아래 Step 3 의
충돌을 **이 자리에서** 발화시킨다(`✗ AC3: 라운드 규약 절에 «Q1» 잔존`). `Fail: 0` 이 나오면
`OQ1` 이 절 안에 안 들어갔다는 뜻이므로 새 문면을 다시 본다. SKILL.md 줄 수를 측정해
보고한다(`< 480`).

- [ ] **Step 3: 라운드 규약 절의 기존 부재 락이 여전히 green 인지 확인**

`:362` 가 그 절에서 `'Q1' 'Q2' 'provisional_on' '블록 없이' '직전 답에서'` 부재를 요구한다. 새 문면에 `OQ1` 이 들어가는데 **`grep -qF 'Q1'` 은 `OQ1` 안의 `Q1` 을 매치한다** — 이 락이 RED 가 된다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E "라운드 규약 절에|Total"
```

Expected: **`✗ AC3: 라운드 규약 절에 «Q1» 잔존`** 과 `«Q2»`(있다면). 이것이 예상된 충돌이다 — 락의 주석이 이미 그 위험을 적어 두었다: 「`Q1`·`Q2` 는 `OQ1`·`OQ2` 표기와 겹칠 수 있어 전-파일로 재지 않고 이 절로 좁힌다」. 이제 그 절 안에 `OQ1` 이 들어왔으므로 **술어를 단어 경계로 좁힌다**:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
old = """for tok in 'Q1' 'Q2' 'provisional_on' '블록 없이' '직전 답에서'; do
  grep -qF -- "$tok" <<<"$round_block" \\
    && no "AC3: 라운드 규약 절에 «${tok}» 잔존" || ok "AC3: 라운드 규약 절에 «${tok}» 없음"
done"""
new = """# 2026-09-23: 이 절이 이제 `OQ<n>` 표기를 담는다(결정 연결). 옛 `Q<n>` 어휘의 부재는
# **단어 경계**로 재야 한다 — `-F 'Q1'` 은 `OQ1` 안의 두 글자를 매치해 정당한 입력을 거부한다.
# 락의 머리 주석이 이미 그 겹침을 예고했고(「`Q1`·`Q2` 는 `OQ1`·`OQ2` 표기와 겹칠 수 있어」),
# 이번 편집이 그 예고를 실현시켰다. 좁히기의 방향은 fail-closed 다: `Q1` 단독 표기는 여전히 RED.
for tok in 'Q1' 'Q2'; do
  grep -qE "(^|[^A-Za-z])${tok}([^0-9]|$)" <<<"$round_block" \\
    && no "AC3: 라운드 규약 절에 «${tok}» 잔존 (단어 경계 — OQ<n> 은 대상 아님)" \\
    || ok "AC3: 라운드 규약 절에 «${tok}» 없음 (단어 경계)"
done
for tok in 'provisional_on' '블록 없이' '직전 답에서'; do
  grep -qF -- "$tok" <<<"$round_block" \\
    && no "AC3: 라운드 규약 절에 «${tok}» 잔존" || ok "AC3: 라운드 규약 절에 «${tok}» 없음"
done"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '라운드 규약 절에|Total'
```

Expected: `ok` 다음 ✓ 다섯 + `Fail: 0`.

- [ ] **Step 4: 좁힌 술어가 여전히 이빨을 갖는지 변이로 잰다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
cp "$SK" "$W/skill.bak"
python3 -c "
import pathlib
p=pathlib.Path('$SK'); t=p.read_text(encoding='utf-8')
old='- `## R<n>` 은 1부터 순증한다.'
assert t.count(old)==1
p.write_text(t.replace(old, old+'\n- 옛 표기 Q1 을 쓴다.'), encoding='utf-8')"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '«Q1»'
cp "$W/skill.bak" "$SK"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '«Q1»|Total'
```

Expected: 변이 후 **`✗ … «Q1» 잔존`** → 복원 후 ✓ + `Fail: 0`. 변이 후에도 ✓ 면 좁히기가 이빨을 없앤 것이다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -2
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
feat(spec-distill): V1 검문소를 라운드 규약 «안» 에 둔다

라운드 1 리뷰가 검문소의 시점을 반증했다 — `finishing.md` Step A 는 floor 5 가 전부 닫힌 뒤에만
읽히므로 거기서만 확인하면 반증이 마지막 사용자 라운드 «후» 에 나오고 방향에 영향 줄 라운드가
없다. ⟨C11⟩(조사가 방향에 영향)을 구조적으로 못 맞춘다. 그래서 검문소를 셋으로 가르고 첫째를
라운드 안에 둔다.

세 번째 단계(「주장이 그 자리와 맞는가」)가 OQ17 의 구멍을 막는 것이다 — 폐기된 auto-confirm
범주는 넷 다 실재하는 경로를 가리켰고 틀린 것은 그 자리의 내용이었다.

steelman 은 자기 Step 2 를 유지한다: 확인 «행위» 는 한 번이고 기록만 audit §3·§5 둘이다.

부수 교정: 이 절이 `OQ<n>` 표기를 담게 되어 옛 `Q<n>` 부재 락을 단어 경계로 좁혔다. 락의 머리
주석이 이미 그 겹침을 예고했고 이번 편집이 실현시켰다. 좁히기의 이빨은 변이로 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 9: C43 경로 (a) 를 계약 산출로 · 리터럴 마커 폐기 (AC15)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (C43 표의 (a) 행)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (마커 부재 + 계약 산출 단언)
- Modify: `plugins/spec-distill/tests/test_stale_terms.sh` (**V14 신설** — 마커 리터럴 production 잔존 0. V12·V13 에 얹지 않는다 — 그 메시지들이 다른 릴리스를 말한다)

**Interfaces:**
- Consumes: Task 2 의 계약 · Task 8 의 V1
- Produces: 내부 축의 **주 생산자** 문면 — 웹 스위치 무관. Task 20 의 web-off 실측이 이 주장을 잰다.

**왜 마커를 버리는가** — `[from-code][auto-confirmed]` 는 15사이클 0건이고, **같은 행위가 audit §5 프로세스 로그에 `auto-confirmed:` 라는 다른 표기로 이미 실재한다.** 갈라진 사본은 「한쪽만 고치는」 결함을 부른다. 개념은 계약으로 흡수하고 리터럴은 폐기한다(X8 · R7).

**C43 표의 행 수를 바꾸지 않는다** — `:1046-1061` 이 헤딩의 `## C43 3-path routing` 숫자 · 산문 «다음 3 경로 중» · 표 행 수 셋의 일치를 잰다. (a) 행의 **내용만** 바꾼다.

**`[from-web]` 은 남긴다** — AC15 가 요구하는 것은 `[from-code][auto-confirmed]` 리터럴의 잔존 0이다. 웹 경로의 표기는 이 설계의 범위가 아니다.

- [ ] **Step 1: 실패하는 단언 둘을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = """c43_block=\"$(awk '/^## C43 /{f=1;print;next} /^## /{f=0} f' \"$SKILL\")\""""
assert t.count(anchor) == 1
new = anchor + """
# AC15 — 리터럴 마커 폐기. 개념은 계약으로 흡수된다. 같은 행위가 audit §5 에 `auto-confirmed:`
# 라는 다른 표기로 이미 실재해 표기가 둘로 갈려 있었다(갈라진 사본 = 한쪽만 고치는 결함).
grep -qF '[from-code][auto-confirmed]' "${CI_ALL[@]}" \\
  && no "AC15: 리터럴 마커 [from-code][auto-confirmed] 잔존" \\
  || ok "AC15: 리터럴 마커 폐기됨"
# 양의 짝 — 부재 락은 대상 절을 통째로 지워도 통과하므로, 그 자리에 «무엇이 들어왔는가»를 함께 잰다.
grep -qF 'repo_claims' <<<"$c43_block" \\
  && ok "AC15(양의 짝): C43 표가 계약 산출(repo_claims)을 요구한다" \\
  || no "AC15(양의 짝): C43 표에 계약 산출 요구가 없다 — 마커만 사라지고 대체물이 없다"
grep -qF 'subagent 를 부르지 않는다' <<<"$c43_block" \\
  && ok "AC24: 경로 (a) 는 orchestrator 가 직접 수행한다 (네 번째 dispatch 자리 없음)" \\
  || no "AC24: 경로 (a) 의 직접 수행 문구 부재 — 네 번째 dispatch 자리로 읽힐 수 있다"
"""
p.write_text(t.replace(anchor, new), encoding="utf-8")

q = pathlib.Path("plugins/spec-distill/tests/test_stale_terms.sh")
s = q.read_text(encoding="utf-8")
# V12 의 정규식에 얹지 않는다 — V12 의 메시지가 「v0.57.0 제거 어휘」라고 말하므로 3.3.0 의 마커를
# 거기 넣으면 잔존이 잡힐 때 사람이 엉뚱한 릴리스를 본다. 이 파일이 자기 머리 주석에서 이미 그
# 규칙을 적어 두었다. 다음 빈 번호로 새 블록을 만든다.
v12_end = """  ok "V12: v0.57.0 제거 어휘 production 잔존 0"
fi
"""
assert s.count(v12_end) == 1
v14 = v12_end + r"""
# V14 (3.3.0): 조사 특화가 폐기한 리터럴 마커 — production 잔존 0.
# 번호는 V12 에 얹지 않는다 — 그 블록의 메시지가 「v0.57.0 제거 어휘」라고 말하므로 3.3.0 의
# 마커를 그 정규식에 넣으면 잔존이 잡힐 때 사람이 엉뚱한 릴리스를 본다. 이 파일의 머리 주석이
# 이미 그 규칙이다(「재사용하면 두 무관한 락이 같은 이름으로 헷갈린다」). V11 은 3.0.0 에서
# 대상과 함께 지웠고 번호를 재사용하지 않으므로 다음 빈 번호는 V14 다.
# 개념은 계약(`repo_claims[]`)으로 흡수됐고, 같은 행위의 audit §5 표기(`auto-confirmed:`)는
# **남는다** — 그래서 대괄호 쌍까지 포함해서 잰다. `auto-confirmed` 단독을 재면 정당한 표기가
# RED 가 된다(폐기된 것은 마커 리터럴이고 개념이 아니다).
scan -InE 'from-code\]\[auto-confirmed' "${prod_files[@]}"
if [[ $SCAN_RC -ge 2 ]]; then
  no "V14: grep 자체 실패(exit=$SCAN_RC):"; printf '%s\n' "$SCAN_OUT"
elif [[ $SCAN_RC -eq 0 ]]; then
  no "V14: 3.3.0 이 폐기한 리터럴 마커 [from-code][auto-confirmed] 가 production 에 잔존:"
  printf '%s\n' "$SCAN_OUT"
else
  ok "V14: 리터럴 마커 [from-code][auto-confirmed] production 잔존 0"
fi
"""
q.write_text(s.replace(v12_end, v14), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC15|AC24|Total'
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | grep -E 'V14|Total'
```

Expected: `ok` 다음 — stage 락에서 `✗ AC15: 리터럴 마커 … 잔존` + `✗ AC15(양의 짝)` + `✗ AC24`, stale 락에서 `✗ V14: 3.3.0 이 폐기한 리터럴 마커 … 가 production 에 잔존`.

- [ ] **Step 2: C43 (a) 행을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
old = "| (a) **factual / landscape** | 답이 codebase/git history *또는 외부 prior-art*에 있는 경우 | codebase는 grep/Read *auto-confirm*; 외부는 web sweep(아래 R2). 마커 `[from-code][auto-confirmed]` 또는 `[from-web]`. streak +1. |"
new = "| (a) **factual / landscape** | 답이 codebase/git history *또는 외부 prior-art*에 있는 경우 | codebase 는 **orchestrator 가 자기 `Read`/`Grep` 으로 직접 확인하고 subagent 를 부르지 않는다** — 산출은 계약(`## 조사 주장 계약`)의 `repo_claims[]` 이고 라운드 규약의 V1 을 탄다. 웹 스위치와 무관해서 **내부 축의 주 생산자**다. 외부는 web sweep(아래 R2), 표기 `[from-web]`. streak 은 C44 의 면제 규칙이 정한다. |"
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC15|AC24|C43:|Total'
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | grep -E 'V14|Total'
```

Expected: `ok` 다음 stage 락 `Fail: 0`(AC15 둘 + AC24 ✓, C43 행 수·헤딩·산문 일치 ✓), stale 락 `Fail: 0`.

- [ ] **Step 3: 마커 잔존을 리포 전역에서 재확인 (개념 별칭까지)**

식별자만 grep 하면 다른 이름의 참조가 살아남는다. `docs/archive/` 는 이력이라 대상이 아니다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
echo "--- 리터럴"
grep -rn 'from-code\]\[auto-confirmed' plugins/ shared/ tools/ || echo "0건 ✓"
echo "--- 개념 별칭 (마커 규약을 다른 이름으로 부르는 자리)"
grep -rn '마커 규약\|\[from-code\]' plugins/ shared/ tools/ || echo "0건 ✓"
echo "--- 숨은 디렉토리까지 (셸 grep 은 「.」 재귀서 숨김 디렉토리를 건너뛴다)"
grep -rn --include='*.md' --include='*.py' --include='*.sh' 'from-code\]\[auto-confirmed' . 2>/dev/null | grep -v '^\./docs/archive' | grep -v '^\./docs/superpowers' || echo "0건 ✓"
```

Expected: 첫 둘 `0건 ✓`. 셋째는 `docs/superpowers/` 의 설계·brief 인용이 제외되고 `0건 ✓`(설계문서와 brief 는 이 규약의 폐기를 **서술**하는 자리라 대상이 아니다).

- [ ] **Step 4: C43 세 일치 단언과 README 의 `<n>-path` 표기를 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'C43'
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: `C43(양성대조)` ✓ · `C43: 헤딩이 선언한 경로 수 3 == 표 행 수 3` ✓ · `C43: 산문이 선언한 경로 수 3 == 표 행 수 3` ✓ · `C43: SKILL·README 의 «<n>-path» 표기가 하나뿐이고 표 행 수 3 와 같다` ✓. SKILL.md 는 **401줄에서 변하지 않는다** — 이 Task 는 표 한 행을 (더 긴) 한 행으로 교체하므로
줄 수가 늘지 않는다. 늘어났으면 표 행을 여러 줄로 쪼갠 것이고, 그러면 C43 행 수 일치 단언이
깨진다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh \
        plugins/spec-distill/tests/test_stale_terms.sh
git commit -F - <<'MSG'
feat(spec-distill): C43 경로 (a) 를 계약 산출로 — 리터럴 마커 폐기

마커 `[from-code][auto-confirmed]` 는 15사이클 0건이었고, 같은 행위가 audit §5 프로세스 로그에
`auto-confirmed:` 라는 다른 표기로 이미 실재했다 — 표기가 둘로 갈려 있었고 갈라진 사본은
「한쪽만 고치는」 결함을 부른다. 개념을 계약으로 흡수하고 리터럴을 버린다.

경로 (a) 는 **orchestrator 가 직접 수행한다** — 네 번째 dispatch 자리를 만들지 않는다. 그 자리가
웹 도구를 쓰지 않으므로 스위치와 무관하고, 그래서 내부 축의 주 생산자가 된다. 검문소만
무조건화하면 DISABLE_WEB=1 세션에서 ∀ 술어가 순회할 항목이 0건이라 공허하게 통과한다.

부재 락엔 양의 짝을 둔다 — 마커가 사라진 자리에 계약 산출 요구가 들어왔는지, 그리고 직접 수행
문구가 있는지를 함께 잰다. 마커 리터럴은 `test_stale_terms.sh` 의 **V14 신설**으로 production 부재를
재게 해 되살아나면 소리가 나게 한다 — V12 에 얹지 않는다(그 블록의 메시지가 「v0.57.0 제거 어휘」라고
말하므로 3.3.0 의 마커를 거기 넣으면 잔존이 잡힐 때 엉뚱한 릴리스를 가리킨다).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```
---

### Task 10: state 스키마 둘 · migration 이월 (AC13 의 state 부분)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (State frontmatter schema)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/state-migration.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (단언 셋 갱신 + 새 단언)

**Interfaces:**
- Consumes: 없음(state 는 독립)
- Produces: state 키 둘의 **정본 스키마** — Task 11 의 자격·예산·면제가 이 필드를 읽는다:
  ```yaml
  orchestration:
    focused_dimension: null
    blind_spot_dispatches: 0          # 개명 — 옛 `blind_spot_dispatched: bool`
    coverage_mapper_dispatches: 0
    open_decisions: []                # 신설 — 인터뷰 중 결정의 유일한 거처
  ```
  `open_decisions[]` 항목 스키마: `{id: OQ<n>, text, dimension, status: open|resolved, resolved_by, touched: bool}`.

**왜 `open_decisions[]` 하나인가** — 라운드 2 가 잡은 것: `OQ<n>`·`RC<n>` 을 **인터뷰가 도는 동안 만드는 자리가 없었다.** state 에 결정 목록이 없고 라운드의 «다음 결정» 은 id 없는 문장이고 §0·§3 목록은 종료 시 작성되는 payload 다 — **소비자만 있고 산출자가 없었다.** 이 키 하나가 산출자이고, 라운드 1 이 요구한 `touched_decisions` 를 `touched` **필드로 흡수**하므로 키가 둘로 늘지 않는다.

**왜 개명에 이월 규칙이 필요한가** — `blind_spot_dispatched: bool → blind_spot_dispatches: int` 는 **개명**이라 현행 규칙(「부재 키만 기본값으로 채운다」)으로는 **이미 dispatch 한 세션이 `0` 을 받아 AP16 가드가 재무장된다.** 선례가 같은 파일에 있다: `rereview_count`·`issue_history` 를 「승계하지 않고 지운다」.

**갱신해야 하는 기존 단언 셋** (Task 1 에서 재도출한 것):
- `:183` `has 'blind_spot_dispatched'` — `CI_FILES` 전역 grep 이라 **state-migration.md 의 이월 규칙 문장이 이 단언을 헛만족시킨다.** 앵커를 SKILL.md 의 state 스키마 블록으로 좁히고 새 키를 잰다.
- `:208` `grep -qF '`orchestration`: `{focused_dimension: null, blind_spot_dispatched: false, coverage_mapper_dispatches: 0}`'` — **열거 전체의 동일성**이 이빨이므로 새 열거 리터럴로 바꾼다.
- 단언 `C8: blind_spot_dispatched guard referenced` (`blindspot_block` 을 잰다) — Task 11 이 그 절을
  고치므로 여기서는 손대지 않는다. **줄 번호로 찾지 말고 이 메시지로 grep 하라** — 앞선 Task 들의
  편집으로 번호가 밀려 있다.

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다 (둘 갱신 + 새 것 넷)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")

# ① :183 — 전-파일 grep 은 migration 의 이월 규칙 문장에 헛만족된다. state 스키마 블록으로 좁힌다.
old = """has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema\""""
new = """# 2026-09-23: `blind_spot_dispatched: bool` → `blind_spot_dispatches: int` 개명. 전-파일 `has` 로는
# **state-migration.md 의 이월 규칙 문장이 옛 키 이름을 담아 헛만족된다** — 앵커를 SKILL.md 의 state
# 스키마 블록으로 좁히고, 옛 키의 부재는 그 블록 안에서만 요구한다(migration 은 옛 이름을 알아야 한다).
state_block="$(awk '/^State frontmatter schema:/{f=1;next} f&&/^```yaml$/{y=1;next} y&&/^```$/{exit} y' "$SKILL")"
{ [[ -n "$state_block" ]] && grep -q 'orchestration:' <<<"$state_block"; } \\
  && ok "AC1(양성대조): state 스키마 블록을 잘랐다 ($(grep -c . <<<"$state_block")줄)" \\
  || no "AC1(양성대조): state 스키마 블록을 못 잘랐다 — 아래 단언이 공허하다"
grep -qE '^ +blind_spot_dispatches: 0' <<<"$state_block" \\
  && ok "AC13: orchestration.blind_spot_dispatches (int) in schema" \\
  || no "AC13: orchestration.blind_spot_dispatches (int) 부재"
grep -qE '^ +blind_spot_dispatched:' <<<"$state_block" \\
  && no "AC13: 옛 키 blind_spot_dispatched 가 스키마에 잔존 (개명 미완 — 두 키가 공존하면 소비자가 갈린다)" \\
  || ok "AC13: 옛 키 blind_spot_dispatched 가 스키마에서 사라졌다"
grep -qE '^ +open_decisions:' <<<"$state_block" \\
  && ok "AC13: orchestration.open_decisions (결정의 유일한 거처) in schema" \\
  || no "AC13: orchestration.open_decisions 부재 — OQ<n> 의 산출자가 없다"
# 필드는 `open_decisions:` **하위 블록**에서 잰다. state 블록 전체로 재면 둘이 «이미» 만족된다 —
# `dimension:` 은 `focused_dimension: null` 에, `status: open` 은 coverage floor 다섯 줄에 걸린다.
# 그러면 Step 2 가 그 필드를 안 넣어도 green 이라 단언에 이빨이 없다. 종료 조건은 0 indent 로
# 잡는다 — `{0,2}` 같은 interval 표현은 macOS awk 에서 조용히 매치되지 않는다.
od_block="$(awk '/^ +open_decisions:/{f=1;print;next} f&&/^[a-z_]/{exit} f' <<<"$state_block")"
{ [[ -n "$od_block" ]] && grep -qE '^ +open_decisions:' <<<"$od_block"; } \\
  && ok "AC13(양성대조): open_decisions 하위 블록을 잘랐다 ($(grep -c . <<<"$od_block")줄)" \\
  || no "AC13(양성대조): open_decisions 하위 블록을 못 잘랐다 — 아래 필드 단언이 공허하다"
for fld in 'id: OQ' 'dimension:' 'status: open' 'resolved_by:' 'touched: false'; do
  grep -qE "^ +-? *${fld}" <<<"$od_block" \\
    && ok "AC13: open_decisions 항목 필드 «${fld}»" || no "AC13: open_decisions 항목 필드 «${fld}» 부재"
done"""
assert t.count(old) == 1
t = t.replace(old, new)

# ② :208 — 열거 전체의 동일성. 새 열거로 바꾸고 이월 규칙 셋을 함께 요구한다.
old2 = """{ grep -qF '`orchestration`: `{focused_dimension: null, blind_spot_dispatched: false, coverage_mapper_dispatches: 0}`' <<<"$mig_block"; } \\
  && ok "AC5(v0.57.0): migration 절의 orchestration 열거가 정확히 coverage_mapper_dispatches 로 끝난다 (정체 트리거 필드 없음)" \\
  || no "AC5(v0.57.0): migration 절의 orchestration 열거가 정확히 coverage_mapper_dispatches 로 끝난다 (정체 트리거 필드 없음)\""""
new2 = """{ grep -qF '`orchestration`: `{focused_dimension: null, blind_spot_dispatches: 0, coverage_mapper_dispatches: 0, open_decisions: []}`' <<<"$mig_block"; } \\
  && ok "AC13: migration 절의 orchestration 열거가 새 네 키와 정확히 일치 (정체 트리거 필드 없음)" \\
  || no "AC13: migration 절의 orchestration 열거가 새 네 키와 다르다 (정체 트리거 필드 없음)"
# 개명은 «부재 키만 채운다» 로 안 된다 — 이미 dispatch 한 세션이 0 을 받아 AP16 가드가 재무장된다.
# 이월 규칙 셋(값 이월 · 옛 키 삭제 · 신설 키 기본값)을 문구로 요구한다.
mig_flat="$(tr '\\n' ' ' <<<"$mig_block" | tr -s ' ')"
grep -qF 'blind_spot_dispatched: true` 가 있으면 `blind_spot_dispatches: 1`' <<<"$mig_flat" \\
  && ok "AC13: 이월 규칙 — true → 1" || no "AC13: 이월 규칙(true → 1) 부재 — AP16 가드가 재무장된다"
grep -qE '옛 키 `blind_spot_dispatched` 를 \\*\\*지운다\\*\\*' <<<"$mig_flat" \\
  && ok "AC13: 이월 후 옛 키 삭제" || no "AC13: 옛 키 삭제 규칙 부재 — 두 키가 공존한다"
grep -qF '`open_decisions` 는 부재 시 `[]`' <<<"$mig_flat" \\
  && ok "AC13: open_decisions 기본값 []" || no "AC13: open_decisions 기본값 규칙 부재\""""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
```

Expected: `✗` **정확히 13건**, `Fail: 13`. 내역 — 스키마 셋(`blind_spot_dispatches` 부재 ·
옛 키 잔존 · `open_decisions:` 부재) + `open_decisions` 하위 블록 양성대조 1 + 필드 다섯 +
열거 동일성 1 + 이월 규칙 셋. `AC1(양성대조)`(state 블록 절단)만 이 시점에 ✓ 다.

**숫자가 다르면 멈추고 보고하라.** 이 기대값은 처음 어림수였고, 그때 실제 ✗ 도 그 어림수와 같았다 —
필드 단언 둘이 기존 스키마에 이미 만족돼(위 주석) 애매한 기대값이 그 이빨 공백을 정확히 가렸다.
여기서 숫자를 정확히 요구하는 것은 그 은폐를 다시 열지 않기 위해서다.

- [ ] **Step 2: SKILL.md 의 state 스키마를 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
old = """orchestration:                       # orchestrator 소유, agent read-only
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  blind_spot_dispatched: false       # C8 인터뷰당 1회 보장
  coverage_mapper_dispatches: 0      # 상한 2 — R1 첫 질문 전 1 + 재개방 시 ≤1
"""
new = """orchestration:                       # orchestrator 소유, agent read-only
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  blind_spot_dispatches: 0           # 예산 = 1 + 그 차원의 reopened (자격은 아래 절)
  coverage_mapper_dispatches: 0      # 예산 = 1 + 모든 차원의 reopened 합 (자격은 아래 절)
  open_decisions:                    # 인터뷰 중 결정의 유일한 거처 — OQ<n> 의 산출자
    - id: OQ1
      text: "<한 줄>"
      dimension: blind_spot          # 어느 커버리지 차원에 속하는가 (호출 자격의 입력)
      status: open                   # open | resolved
      resolved_by: null              # resolved 면 그 사용자 발화 S<N>
      touched: false                 # 조사가 닿았는가 (C44 면제의 입력)
"""
assert t.count(old) == 1
t = t.replace(old, new)

old2 = """State body: 각 라운드의 `## R<n>` 기록(«라운드 규약» 형식) + coverage-mapper 출력 transcript.
"""
new2 = """State body: 각 라운드의 `## R<n>` 기록(«라운드 규약» 형식) + coverage-mapper 출력 transcript.

**`open_decisions[]` 의 생명주기.** 발급은 orchestrator 가 «다음 결정» 블록을 쓸 때 그 문장에
`OQ<n>` 을 붙이는 것이다(번호는 순증, 인터뷰 안에서만 유일). `status: open → resolved` 는 사용자
발화로만 바뀌고 **해결돼도 목록에서 지우지 않는다** — 조사가 결정을 해결하는 데 기여했으면 그것이
성공 사례인데 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. `touched` 는
`false → true` 단방향이고 재개방으로도 되돌리지 않는다(되돌리면 면제가 무한해진다). 종료 시
`status: open` 인 것이 payload §3 Open Questions 로, **전량**이 §0 결정 목록으로 직렬화된다 — §0 이
상위집합이고 §3 이 그 중 열린 것이다. `RC<n>` 은 별 state 키를 두지 않는다: V1 이 붙이고 audit §5 의
확인 줄이 곧 레지스터이며, 확인 줄 없는 `RC<n>` 은 게이트가 red 로 잡는다.
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`.

- [ ] **Step 3: state-migration.md 에 이월 규칙을 넣는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/references/state-migration.md")
t = p.read_text(encoding="utf-8")
old = """- `orchestration`: `{focused_dimension: null, blind_spot_dispatched: false, coverage_mapper_dispatches: 0}`
  — 절이 없으면 이 값 그대로 seed. **있으면 부재 키만** 그 기본값으로 추가한다(직전 릴리스
  세션에서 실제로 빠져 있는 것은 `coverage_mapper_dispatches` 하나다).
"""
new = """- `orchestration`: `{focused_dimension: null, blind_spot_dispatches: 0, coverage_mapper_dispatches: 0, open_decisions: []}`
  — 절이 없으면 이 값 그대로 seed. **있으면 부재 키만** 그 기본값으로 추가한다.

**개명은 「부재 키만 채운다」로 안 된다.** `blind_spot_dispatched: bool` 이
`blind_spot_dispatches: int` 로 개명됐다. 부재 키 규칙만 쓰면 **이미 dispatch 한 세션이 새 키의
기본값 `0` 을 받아 AP16 가드가 재무장된다** — 같은 인터뷰가 prober 를 두 번 부른다. 값을 이월한다:

- `blind_spot_dispatched: true` 가 있으면 `blind_spot_dispatches: 1` 로 이월한다. `false` 면 `0`.
- 이월 뒤 옛 키 `blind_spot_dispatched` 를 **지운다** — 두 키가 공존하면 소비자가 어느 쪽을 읽는지
  갈리고, 이 파일은 `rereview_count`·`issue_history` 에서 이미 「승계하지 않고 지운다」 선례를 갖는다.
- `open_decisions` 는 부재 시 `[]` — 부재 키 채우기의 정상 경로다. 진행 중인 인터뷰에는 결정 목록이
  없으므로 빈 목록이 맞고, 그 세션의 면제는 「열린 결정이 0이면 면제도 0」으로 떨어진다.
"""
assert t.count(old) == 1
t = t.replace(old, new)

old2 = """[spec-distill v0.57.0] state schema migration: reopen ledger + coverage_mapper_dispatches added (stall trigger retired).
"""
new2 = """[spec-distill 3.3.0] state schema migration: blind_spot_dispatched -> blind_spot_dispatches (value carried), open_decisions added.
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
```

Expected: `ok` 다음 — **`AC5: migration advisory wording` 하나만 `✗`** (그것은 Step 4 가
처분한다). 나머지 AC1/AC13 단언은 전부 ✓.

**`C8: blind_spot_dispatched guard referenced` 는 ✓ 로 «남는다»** — 이 단언은 (줄 번호가 아니라
이 메시지로 찾는다) blindspot 절의 **산문**을 재는데, 이 Task 는 state **스키마 블록**만 고치므로
`SKILL.md` 의 그 산문은 옛 이름 `blind_spot_dispatched` 를 그대로 갖는다. 없는 red 를 찾지 마라.

그래서 이 커밋은 스키마가 새 이름, 산문이 옛 이름인 상태로 남는다 — **의도된 한 커밋짜리
불일치**다. 산문 개명과 옛 이름의 부재 락(X4)은 Task 11 이 자격·예산 문구와 «함께» 넣는다(그
문구가 새 이름의 의미를 말하는 자리라 쪼개면 산문이 두 번 고쳐진다). Task 11 이 미뤄지면 그
불일치가 락 없이 남는다는 것을 알고 넘긴다.

- [ ] **Step 4: advisory 문구 단언과 interview_round 봉쇄를 확인**

`:201` `has 'state schema migration.*coverage'` 가 advisory 문구를 잰다 — 새 문구에 `coverage` 가 없으면 RED 다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'migration advisory|V9: interview_round|Total'
```

Expected: `✗ AC5: migration advisory wording` 이 **반드시** 나온다 — 그 술어가
`'state schema migration.*coverage'` 이고 Step 3 의 새 advisory 에 `coverage` 가 없기 때문이다.
나오지 않으면 Step 3 의 치환이 안 먹은 것이므로 멈추고 보고한다. 해소는 아래 블록이다: 그 단언의
술어를 이 릴리스의 실제 내용(개명 + 신설 키)으로 바꾼다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
old = """has 'state schema migration.*coverage' "AC5: migration advisory wording\""""
new = """# 2026-09-23: advisory 문구가 이 릴리스의 내용(개명 + 신설 키)을 말한다. 「무엇이 바뀌었는지」를
# 사용자에게 알리는 줄이라 릴리스마다 내용이 바뀌는 것이 정상이고, 락은 그 줄이 **있는가**와
# **이 릴리스의 두 변화를 이름으로 대는가**를 잰다.
has 'state schema migration' "AC5: migration advisory 줄 실재"
has 'blind_spot_dispatched -> blind_spot_dispatches' "AC13: advisory 가 개명을 이름으로 댄다"
has 'open_decisions added' "AC13: advisory 가 신설 키를 이름으로 댄다\""""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'advisory|V9: interview_round|Total'
```

Expected: advisory 단언 셋 ✓ · `V9: interview_round confined` ✓ · **`Fail: 0`**.
`C8: blind_spot_dispatched guard referenced` 는 ✓ 로 **남는다**(Step 3 의 Expected 가 그 이유를
적었다) — 없는 red 를 찾지 마라.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -2
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/skills/conducting-interview/references/state-migration.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
feat(spec-distill): open_decisions[] — OQ<n> 의 산출자를 둔다

라운드 2 가 잡은 것: OQ<n>·RC<n> 을 **인터뷰가 도는 동안 만드는 자리가 없었다.** state 에 결정
목록이 없고 라운드의 «다음 결정» 은 id 없는 문장이고 §0·§3 목록은 종료 시 작성되는 payload 다 —
소비자만 있고 산출자가 없었다. 같은 실패가 한 층 위에서 되풀이된 것이다(라운드 1 이 잡은
`touched_decisions` 의 산출자 부재). 키 하나로 둘을 함께 해소한다: `touched` 가 필드로 흡수된다.

해결된 결정을 목록에서 지우지 않는 것이 요점이다 — 조사가 결정을 해결하는 데 기여했으면 그것이
성공 사례인데, 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 성공을 red 로
만드는 술어는 목표의 반전이다.

개명 `blind_spot_dispatched: bool → blind_spot_dispatches: int` 에는 값 이월이 붙는다 — 부재 키
규칙만 쓰면 이미 dispatch 한 세션이 0 을 받아 AP16 가드가 재무장된다. 옛 키는 지운다(같은 파일의
`rereview_count`·`issue_history` 선례).

락 교정 둘: `:183` 의 전-파일 grep 은 migration 의 이월 규칙 문장에 헛만족되므로 앵커를 state
스키마 블록으로 좁혔고, `:208` 의 열거 동일성 리터럴을 새 네 키로 바꿨다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: stale 락 `Fail: 0`. SKILL.md 줄 수를 측정해 보고한다(`< 480`).

---

### Task 11: 호출 자격 · 예산 · C44 면제 (AC13 나머지 · AC14 · AC22)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (두 dispatch 절 + `## C44` 절)
- Modify: `plugins/spec-distill/agents/coverage-mapper.md` · `agents/blind-spot-prober.md` (상한 문구 여섯)
- Modify: `plugins/spec-distill/README.md` (상한 문구 셋)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (단언 넷 갱신 + 새 단언).
  갱신할 넷은 **메시지로** 찾는다(번호는 앞선 Task 들의 편집으로 밀렸다):
  `C4: 재개방 시 최대 1회` · `C4: 상한 2 + 카운터` · `C8: fan-out 1 (blind_spot_dispatched guard)` ·
  `C8: blind_spot_dispatched guard referenced`

**Interfaces:**
- Consumes: Task 10 의 state 키 둘 (`blind_spot_dispatches` · `open_decisions[].{status,touched,dimension}`)
- Produces: C44 면제 규칙의 **순서** — 「계수 먼저, 표시 나중」. 이 순서가 뒤집히면 면제가 영구히 거짓이 되고 ⟨C13⟩ 재결정의 유한화 논거가 함께 무너진다.

**세 규칙의 문면** (설계 §F 그대로):
1. **호출 자격** = ⟨C12⟩ 문면 그대로 — 「그 장치가 채우는 차원에 닿는 **열린 결정**이 아직 있는가」. 그 차원의 열린 결정이 0이면 자격이 없다 — **예산이 남아도 부르지 않는다.**
2. **예산** = 자격 위의 상한. `blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened` · `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)`. steelman 은 불변(이미 근거-발동).
3. **면제** = 「산출 항목의 `decides` 가 `status: open` 이고 `touched: false` 인 결정을 하나라도 담으면 `non_user_streak` +0. 그렇지 않으면 +1. **그 계수 뒤에** 그 원소들의 `touched` 를 `true` 로 올린다. 열린 결정이 0이면 면제도 0이다.」

**C44 절에 라틴문자 `round` 를 쓰지 않는다** — `:479-481` 이 `grep -qi 'round' <<<"$rhythm_block"` 부재를 요구한다(대소문자 무시). `around`·`background`·`surround` 도 걸린다. 한국어 「라운드」를 쓴다.

**E10 락을 밟지 않는다** — `blind-spot-prober.md` 에 `최대 N회`·`N회까지`·`N–N회`·`N-N회`·`max_x = N` 을 쓰지 않는다. `1 + 재개방 횟수` 형태로 쓴다.

**교체 대상 열거를 신뢰하지 않는다** — Task 1 Step 3 이 낸 `cap-sites.txt` 를 그대로 쓴다. 설계 AC22 의 「여섯」은 `agents/` 만의 전수였다.

**그 매처는 «선언된 리터럴»만 잰다 — 개념 별칭은 따로 훑는다.** `cap-sites.py` 의 키는
`상한 2`·`fan-out 1`·`인터뷰당 1회`·`bounded …` 다. covmap 절은 **같은 하드 카운트를 다른 말로**
세 번 더 말한다 — `dispatch 는 둘뿐이다` · `재개방 시 최대 1회` · `두 번째 재개방부터는 없다`.
매처가 그것을 매치하지 않으므로 **「총 0 줄」이 거짓 clean 이 될 수 있다.** 그 셋은 Step 2 가
교체하고 Step 1 의 부재 락 셋이 지키며 Step 4 가 따로 훑는다. 매처 자신은 손대지 않는다 —
Task 1 이 기록한 15/14 기준선이 그 키에 묶여 있다.

- [ ] **Step 1: cap-sites 를 다시 세고 실패하는 단언을 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
python3 "$W/cap-sites.py" .
```

Task 1 이 워크스페이스에 둔 **같은 매처**를 다시 쓴다 — 여기서 정규식을 다시 적으면 사본이 둘이 되고 「한쪽만 고치는」 결함이 된다.

Expected: Task 10 이 SKILL.md 의 state 주석 둘을 이미 고쳤으므로 **원시 매치 줄 13 · 개념 자리 12** 가 남는다(착수 시 15/14 에서 둘 감소). 다른 값이 나오면 Task 10 이 무엇을 바꿨는지 먼저 확인한다. **이 목록이 이 Task 의 교체 대상 전량이다** — 이 문서의 숫자를 기대값으로 고정하지 않는다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")

# ── covmap: `재개방 최대 1회` · `상한 2` → 자격 + 예산
old = """grep -qE '재개방[^.]{0,20}최대 1회' <<<"$covmap_flat" \\
  && ok "C4: 재개방 시 최대 1회" || no "C4: 재개방 dispatch 규칙 부재\""""
new = """# 2026-09-23: 예산이 `1 + 재개방` 이 되고 그 위에 **자격**(⟨C12⟩ 문면)이 얹혔다. 옛 `재개방 시
# 최대 1회`·`상한 2` 는 이 계약을 더 이상 서술하지 않는다 — 교체한다. 자격과 예산을 **둘 다**
# 요구하는 것이 요점이다: 예산만으로는 「닿는 결정이 아직 열려 있는가」라는 재개 조건을 구현하지
# 못한다(라운드 1 이 그것을 잡았다).
grep -qF '닿는 열린 결정이 아직 있는가' <<<"$covmap_flat" \\
  && ok "C12: 호출 자격 = 그 차원에 닿는 열린 결정이 아직 있는가" || no "C12: 호출 자격 문구 부재"
grep -qF '열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다' <<<"$covmap_flat" \\
  && ok "C12: 자격이 예산보다 앞선다" || no "C12: 자격 우선 문구 부재 — 예산만으로 부를 수 있게 읽힌다"
grep -qF 'coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)' <<<"$covmap_flat" \\
  && ok "X4: coverage-mapper 예산 = 1 + 재개방 합" || no "X4: coverage-mapper 예산 식 부재\""""
assert t.count(old) == 1
t = t.replace(old, new)

old2 = """{ grep -qE '상한[^.]{0,6}2' <<<"$covmap_flat" && grep -qF 'coverage_mapper_dispatches' <<<"$covmap_block"; } \\
  && ok "C4: 상한 2 + 카운터" || no "C4: 상한 2/카운터 부재\""""
new2 = """{ grep -qF '1 + Σ' <<<"$covmap_flat" && grep -qF 'coverage_mapper_dispatches' <<<"$covmap_block"; } \\
  && ok "X4: 예산 식 + 카운터" || no "X4: 예산 식/카운터 부재"
# 옛 어휘의 부재 — 한쪽만 고치면 두 상한이 공존해 어느 쪽이 계약인지 모른다.
grep -qE '상한 2' <<<"$covmap_block" \\
  && no "X4: 옛 «상한 2» 가 이 절에 잔존 (예산 식과 공존)" || ok "X4: 옛 «상한 2» 제거됨\"
# 위에서 지운 `재개방 ... 최대 1회` 단언을 **뒤집어** 되살린다. 그냥 지우면 그 산문이 남아도
# 아무것도 막지 않는다 — 그리고 이 절의 번호 목록은 하드 카운트를 세 가지 «다른 표현»으로
# 말한다(`둘뿐이다` · `최대 1회` · `두 번째 재개방부터는 없다`). 식별자만 재는 매처로는 잡히지
# 않는다. 세 표현 전부의 부재를 요구하고, 양의 짝은 바로 위 예산 식 단언이다.
for tok in '둘뿐이다' '최대 1회' '두 번째 재개방부터는 없다'; do
  grep -qF -- "$tok" <<<"$covmap_block" \\
    && no "X4: 옛 하드 카운트 «${tok}» 가 이 절에 잔존 — 예산 식과 모순한다" \\
    || ok "X4: 옛 하드 카운트 «${tok}» 제거됨"
done"""
assert t.count(old2) == 1
t = t.replace(old2, new2)

# ── blindspot: `fan-out 1|인터뷰당 1회` · `blind_spot_dispatched` → 자격 + 예산 + 새 키
old3 = """grep -qE 'fan-out 1|인터뷰당 1회' <<<"$blindspot_block" \\
  && ok "C8: fan-out 1 (blind_spot_dispatched guard)" \\
  || no "C8: fan-out 1 (blind_spot_dispatched guard)"
grep -q 'blind_spot_dispatched' <<<"$blindspot_block" \\
  && ok "C8: blind_spot_dispatched guard referenced" \\
  || no "C8: blind_spot_dispatched guard referenced\""""
new3 = """grep -qF '닿는 열린 결정이 아직 있는가' <<<"$blindspot_block" \\
  && ok "C12: prober 호출 자격" || no "C12: prober 호출 자격 문구 부재"
grep -qF 'blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened' <<<"$blindspot_block" \\
  && ok "X4: prober 예산 = 1 + 그 차원의 재개방" || no "X4: prober 예산 식 부재"
grep -qE 'blind_spot_dispatched([^e]|$)' <<<"$blindspot_block" \\
  && no "X4: 옛 키 blind_spot_dispatched 가 이 절에 잔존 (개명 미완)" \\
  || ok "X4: 옛 키 blind_spot_dispatched 제거됨"
grep -qE 'fan-out 1|인터뷰당 1회' <<<"$blindspot_block" \\
  && no "X4: 옛 «fan-out 1 / 인터뷰당 1회» 가 이 절에 잔존 (예산 식과 공존)" \\
  || ok "X4: 옛 하드 1회 문구 제거됨\""""
assert t.count(old3) == 1
t = t.replace(old3, new3)

# ── C44 면제 — 순서가 이빨이다.
old4 = """grep -qi 'round' <<<"$rhythm_block" \\
  && no "AC9: rhythm-guard no longer references round" \\
  || ok "AC9: rhythm-guard no longer references round\""""
new4 = """grep -qi 'round' <<<"$rhythm_block" \\
  && no "AC9: rhythm-guard no longer references round" \\
  || ok "AC9: rhythm-guard no longer references round"
# AC14 — 면제 규칙. **순서가 이빨이다**: 표시가 계수보다 앞서면 계수 시점에 「아직 안 닿은 것」이
# 항상 공집합이라 첫 연결부터 +1 이 되고 면제가 영구히 발화하지 않는다. 그러면 ⟨C13⟩ 재결정의
# 유한화 논거(「첫 연결은 +0, 두 번째부터 +1」)가 함께 무너진다(라운드 2 가 이 반전을 잡았다).
rhythm_flat="$(tr '\\n' ' ' <<<"$rhythm_block" | tr -s ' ')"
grep -qF '계수 먼저, 표시 나중' <<<"$rhythm_flat" \\
  && ok "AC14: 면제의 순서 라벨 — 계수 먼저, 표시 나중" || no "AC14: 순서 라벨 부재"
# **라벨만 재면 이빨이 없다.** 라벨 문장과 규칙 본문은 다른 자리이고, 본문의 `뒤에` 를 `전에` 로
# 한 글자 바꾸거나 순서를 통째로 뒤집어 써도 라벨은 그대로 남는다 — 그러면 면제가 영구히
# 발화하지 않는 자기모순 문면이 스위트 green 을 유지한다(리뷰가 실측했다: 본문 반전 후 259/259/0).
# 그래서 규칙 본문의 세 사실 — **순서** · **배정** · **대상 집합** — 을 전부 본문에서 잰다.
#
# 정규화가 인용 계층을 «여러 겹» 벗기고 구분자로 탭도 받는 이유: 그 문장은 blockquote 안에서
# 줄바꿈되므로 마커가 남으면 리터럴이 깨진다. 실측(실제 셸 파이프라인) — `> ` 하나만 벗기는 판은
# 탭 전역 · 중첩 `> >` · 탭+중첩 셋 다에서 **거짓 RED** 였고 이 판은 셋 다 통과한다. 무해한
# 재줄바꿈에도 통과한다(그것이 이 정규화의 목적이다).
# python 흉내로 재면 이 축에서 갈린다 — `re.sub(r'\\s+', ' ')` 는 탭까지 누르지만 `tr -s ' '` 는
# 공백만 누른다. 셸 락은 셸로 재야 한다.
#
# **이 락이 «하지 않는» 것**(공시): 부분문자열 존재 검사라 **모순을 탐지하지 못한다.** 이 리터럴들을
# 그대로 두고 같은 절에 「다만 실제로는 표시가 계수보다 먼저 일어난다」 류의 문장을 더하면 통과한다.
# 그 축은 grep 의 층위가 아니라 **리뷰**의 층위다. 반전 어휘를 금지하는 부정 락으로는 못 막는다 —
# 라벨 문장 자신이 실패 양식을 설명하려고 `표시가 계수보다 앞서면` 을 인용하므로(원본에 1건)
# 그 금지는 정당한 문면을 red 로 만든다.
rhythm_body="$(sed -E 's/^([[:space:]]*>[[:space:]]?)+//' <<<"$rhythm_block" | tr '\\n' ' ' | tr -s ' ')"
grep -qF '계수 **뒤에** 그 원소들의 `touched` 를 `true` 로 올린다' <<<"$rhythm_body" \\
  && ok "AC14: 순서 본문 — 계수 뒤에 표시한다 (본문 고유)" \\
  || no "AC14: 규칙 본문이 «계수 뒤에 표시» 를 말하지 않는다 — 라벨만 남으면 면제가 영구히 거짓이다"
# span 을 **조건절까지** 넓힌다. 배정만 재면 조건절 반전(`하나라도 담으면` → `하나도 담지
# 않으면`)이 리터럴을 그대로 둔 채 규칙 전체를 뒤집는다(재리뷰 실측: 그때 261/261/0). 이로써
# 그 규칙 문장이 말하는 **세 사실 — 조건 · 배정 · 순서 — 이 전부** 본문에서 재어진다. 그 집합이
# 이 자리의 종점이다: 더 넓히는 길은 절 전문 동등 비교로 수렴하고, 그것은 「정당한 재서술도
# 전부 RED」라는 다른 설계 결정이다(여기서 하지 않는다).
grep -qF '결정을 하나라도 담으면 `non_user_streak` **+0**. 그렇지 않으면 **+1**' <<<"$rhythm_body" \\
  && ok "AC14: 조건 + 배정 본문 — 닿는 열린 결정이 있으면 +0, 아니면 +1" \\
  || no "AC14: 조건절이나 +0/+1 배정이 뒤집혔거나 부재 — 순서만 맞아도 규칙 전체가 반대일 수 있다"
grep -qF 'status: open 이고 touched: false 인 결정' <<<"$rhythm_body" \\
  && ok "AC14: 면제 조건의 대상 집합" || no "AC14: 면제 조건의 대상 집합 부재"
grep -qF '열린 결정이 0이면 면제도 0이다' <<<"$rhythm_body" \\
  && ok "AC14: 열린 결정 0 → 면제 0" || no "AC14: 공집합 경로 부재"
grep -qF '산출자는 orchestrator' <<<"$rhythm_flat" \\
  && ok "AC14: touched 의 산출자 명시" || no "AC14: 산출자 부재 — 소비자만 있고 산출자가 없다"
grep -qF 'open_decisions' <<<"$rhythm_block" \\
  && ok "AC14: 면제가 open_decisions 를 읽는다 (거처 일치)" || no "AC14: 거처 참조 부재\""""
assert t.count(old4) == 1
p.write_text(t.replace(old4, new4), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` **정확히 19건**. 내역 — covmap 자격·자격우선·예산식 3 + covmap 예산식·카운터 1 +
covmap 옛 `상한 2` 부재 1 + covmap 옛 하드 카운트 셋 3 + prober 자격·예산·옛키·옛하드 4 +
C44 면제 **일곱**(순서 라벨 · 순서 **본문** · **배정 본문** · 대상 집합 · 공집합 경로 ·
산출자 · 거처) 7 = 19.

**숫자가 다르면 멈추고 보고하라.** 이 기대값은 처음 어림수였다 — 이 브랜치에서 애매한
기대값이 이빨 공백을 정확히 가린 전례가 있으므로(Task 10) 여기서도 정확히 요구한다.

- [ ] **Step 2: SKILL.md 의 두 dispatch 절과 C44 절을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")

# ① 헤딩 + 자격/예산 (coverage-mapper)
old = """## coverage-mapper dispatch (상한 2)
"""
new = """## coverage-mapper dispatch (자격 + 예산)
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """상한 2, 카운터 `orchestration.coverage_mapper_dispatches`. 종료 시 audit §2 에 `coverage-mapper <k>`
"""
new = """**호출 자격이 예산보다 앞선다.** 다시 부를 자격은 「그 장치가 채우는 차원에 **닿는 열린 결정이
아직 있는가**」다 — `orchestration.open_decisions[]` 에서 `dimension` 이 그 차원이고 `status: open`
인 항목이 하나라도 있는가. **열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다.**
자격을 채웠으면 예산을 본다: `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)`.
재개방이 연료다 — 재개방은 정의상 「새 답·외부 근거·코드 사실이 그 차원의 닫힘 근거 S 와 충돌」해야
일어나고 라운드는 사용자 답으로만 도므로 사용자가 시계다.

카운터 `orchestration.coverage_mapper_dispatches`. 종료 시 audit §2 에 `coverage-mapper <k>`
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ①-b 번호 목록도 새 계약을 말해야 한다. 「둘뿐이다」·「최대 1회」·「두 번째 재개방부터는 없다」
# 셋은 예산 `1 + Σ(reopened)` 와 정면으로 모순하고, 남겨 두면 한 절이 두 규칙을 말한다.
old = """orchestrator, G2). dispatch 는 둘뿐이다:
"""
new = """orchestrator, G2). 첫 dispatch 는 필수이고 그 뒤는 자격과 예산이 정한다:
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """2. **재개방 시 최대 1회.** 재개방이 새 파생 차원을 함의할 수 있어서다. 두 번째 재개방부터는 없다.
"""
new = """2. **재개방마다 한 번의 예산이 열린다.** 재개방이 새 파생 차원을 함의할 수 있어서다 — 그래서
   예산이 `1 + 재개방 합` 이다. 자격이 없으면 예산이 남아도 부르지 않는다.
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ② 자격/예산 (blind-spot-prober)
old = """`blind_spot` floor 차원의 **첫 open→in-progress 전이** 시 `blind-spot-prober`를 **인터뷰당 1회**
dispatch한다(fan-out 1, C8). `orchestration.blind_spot_dispatched`가 false일 때만 — dispatch 후
true로 세팅(재dispatch 금지). kill switch"""
new = """`blind_spot` floor 차원의 **첫 open→in-progress 전이** 시 `blind-spot-prober`를 dispatch 한다.
**자격이 예산보다 앞선다** — `orchestration.open_decisions[]` 에 `dimension: blind_spot` 이고
`status: open` 인 항목, 즉 그 차원에 **닿는 열린 결정이 아직 있는가**를 먼저 본다. 열린 결정이
0이면 자격이 없다 — 예산이 남아도 부르지 않는다. 자격을 채웠으면 예산:
`blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened`. dispatch 마다 카운터를 +1 한다.
kill switch"""
assert t.count(old) == 1
t = t.replace(old, new)

# ③ C44 면제 — 라틴문자 `round` 를 쓰지 않는다.
old = """`non_user_streak >= DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 probe의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.
"""
new = """`non_user_streak >= DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 probe의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

**조사 산출의 면제.** 조사가 결정에 닿았으면 그 probe 는 streak 을 올리지 않는다 — 압착의 대가를
가드의 계수 방식에서 지불하되, 면제 예산이 유한하도록 집합 원소에 묶는다. 산출자는 orchestrator
이고 거처는 `orchestration.open_decisions[]` 의 `touched` 필드다(별 키를 두지 않는다).

> 산출 항목의 `decides` 가 status: open 이고 touched: false 인 결정을 하나라도 담으면
> `non_user_streak` **+0**. 그렇지 않으면 **+1**. 그 계수 **뒤에** 그 원소들의 `touched` 를 `true` 로
> 올린다. **열린 결정이 0이면 면제도 0이다.**

**순서가 계약이다 — 「계수 먼저, 표시 나중」.** 표시가 계수보다 앞서면 계수 시점에 「아직 안 닿은
것」이 항상 공집합이라 **첫 연결부터 +1** 이 되고 면제가 영구히 발화하지 않는다.

`touched` 는 단방향이고 재개방으로도 되돌리지 않는다 — 되돌리면 면제가 무한해진다. 그래서 면제
예산은 `|{status: open, touched: false}|` 로 유한하고, **그 집합이 줄어드는 데 의존하지 않는다**:
줄지 않아도 같은 결정의 두 번째 연결이 면제되지 않으므로 예산이 고갈된다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: `ok` 다음 `Fail: 0`. SKILL.md 줄 수를 측정해 보고한다. **480 을 넘으면** 잠정 천장이 모자란 것이므로 이 Task 의 커밋에서 실측 + 8 로 올리고 이유를 적는다.

- [ ] **Step 3: agent 파일 여섯 자리와 README 셋을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
def sub(path, pairs):
    p = pathlib.Path(path); t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        assert t.count(old) == 1, (path, old[:40], t.count(old))
        t = t.replace(old, new)
    p.write_text(t, encoding="utf-8")

sub("plugins/spec-distill/agents/blind-spot-prober.md", [
 ("on the blind_spot floor dimension's first open→in-progress transition (fan-out 1).",
  "on the blind_spot floor dimension's first open→in-progress transition; eligibility is\n  whether an open decision still touches that dimension, and the budget on top of it is\n  1 plus that dimension's reopen count."),
 ("4. **fan-out 1**: 인터뷰당 1회 dispatch(C8).",
  "4. **자격 + 예산**: 다시 부를 자격은 그 차원에 닿는 열린 결정이 아직 있는가다 — 열린 결정이 0이면\n   자격이 없다. 자격을 채웠으면 예산은 `1 + 그 차원의 재개방 횟수` 이고, 통제는\n   conducting-interview 가 한다."),
 ("- blind_spot floor 차원이 이미 closed(재dispatch 금지 — fan-out 1, AC6).",
  "- blind_spot floor 차원에 닿는 열린 결정이 0(자격 없음) 또는 예산 고갈."),
])

sub("plugins/spec-distill/agents/coverage-mapper.md", [
 ("consumed by conducting-interview; dispatch is bounded to two per interview.",
  "consumed by conducting-interview; dispatch eligibility is whether an open decision still\n  touches the dimension, with a budget of 1 plus the total reopen count on top."),
 ("# Coverage-Mapper Agent (상한 2 dispatch 커버리지 계약 공급자)",
  "# Coverage-Mapper Agent (자격 + 예산 dispatch, 커버리지 계약 공급자)"),
 ("4. **bounded dispatch**: R1 첫 질문 전 1회 + 재개방 시 ≤1회, 상한 2(conducting-interview 가 제어).",
  "4. **자격 + 예산**: R1 첫 질문 전 1회는 필수다. 다시 부를 자격은 그 차원에 닿는 열린 결정이 아직\n   있는가이고, 자격 위의 예산은 `1 + 모든 차원의 재개방 합` 이다(conducting-interview 가 제어)."),
])

sub("plugins/spec-distill/README.md", [
 ("`blind-spot-prober`(적대적 premortem, fan-out 1)가 blind-spot floor 차원 구현으로 신설되었다.",
  "`blind-spot-prober`(적대적 premortem)가 blind-spot floor 차원 구현으로 신설되었다."),
 ("- **C4** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자, dispatch 상한 2) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem, fan-out 1).",
  "- **C4** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem). 둘 다 dispatch 는 **자격 + 예산**이다(3.3.0): 자격 = 그 차원에 닿는 열린 결정이 아직 있는가, 예산 = `1 + 재개방`."),
 ("상한이 선언된 것: coverage-mapper dispatch 상한 2 + blind-spot-prober fan-out 1(interview) ·",
  "상한이 선언된 것: coverage-mapper·blind-spot-prober 는 **자격 + 예산**(자격 = 그 차원에 닿는 열린 결정이 아직 있는가 · 예산 = `1 + 재개방`, 3.3.0) ·"),
])
print("ok")
PY
bash plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh 2>&1 | grep -E 'E10|Total'
bash plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh 2>&1 | tail -2
bash plugins/spec-distill/tests/test_readme_sync.sh 2>&1 | tail -2
```

Expected: `ok` 다음 — E10 두 단언 ✓ (`최대 N회`·`N회까지`·`N-N회` 를 쓰지 않았다), 두 frontmatter 락 `Fail: 0`, README 동기화 `Fail: 0`.

- [ ] **Step 4: 상한 문구 전수 재확인 + 무관한 상한이 안 바뀌었는지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
echo "--- 두 장치의 옛 상한 문구 잔존 (0이어야 한다) — Task 1 의 같은 매처로"
W=.superpowers/sdd/2026-09-23-interview-research-specialization
python3 "$W/cap-sites.py" . || true
echo "--- 개념 별칭 — 매처의 키가 못 보는 같은 하드 카운트 (0 이어야 한다)"
CM=plugins/spec-distill/skills/conducting-interview/SKILL.md
covmap="$(awk '/^## coverage-mapper dispatch/{f=1;print;next} /^## /{f=0} f' "$CM")"
for tok in '둘뿐이다' '최대 1회' '두 번째 재개방부터는 없다'; do
  if grep -qF -- "$tok" <<<"$covmap"; then echo "  ✗ «${tok}» 잔존"; else echo "  ✓ «${tok}» 없음"; fi
done
echo "--- 무관한 상한은 그대로여야 한다"
grep -rc '재리뷰 상한 2' plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md
grep -c '상한 2회' plugins/spec-distill/skills/conducting-interview/references/finishing.md
grep -c 'RHYTHM_GUARD_THRESHOLD' plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: 매처의 stdout 이 **비고** stderr 가 `총 0 줄`. 그리고 **개념 별칭 셋 다 `✓`**. 무관한 셋은 각각 `1`·`1`·`2` 이상 — **건드리지 않았다**. 매처가 한 줄이라도 내면 그 자리가 미교체이거나, 새로 쓴 문면이 우연히 옛 표기와 같아진 것이다.

- [ ] **Step 4.5: 잠정 천장을 실측 + 8 로 조인다 (Task 7 이 이 Task 에 넘긴 것)**

Task 7 이 SKILL.md 줄 수 천장을 **잠정 480** 으로 열어 뒀다. 한 번에 정한 값은 중간에는 정당한 편집을 막고 끝에는 래칫의 뜻을 잃기 때문이다. **이 Task 가 SKILL.md 를 마지막으로 편집하므로 여기서 조인다** — 이 절차가 없으면 잠정값이 영구화되고 래칫은 이름만 남는다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
FINAL=$(wc -l < "$SK"); TIGHT=$((FINAL + 8))
echo "실측 $FINAL → 조인 천장 $TIGHT"
python3 - "$TIGHT" <<'PY'
import pathlib, re, sys
tight = sys.argv[1]
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
n = t.count("-lt 480 ")
assert n == 2, "잠정 천장 480 이 %d자리 (2 기대 — Task 7 이 둘을 같은 값으로 뒀다)" % n
t = t.replace("-lt 480 ", "-lt " + tight + " ")
t = t.replace("< 480 (조사 특화 순증 수용 — 잠정, Task 11 이 조인다)",
              "< " + tight + " (조사 특화 순증 수용 — 실측 + 8, Task 11 이 조였다)")
t = t.replace("≥ 480", "≥ " + tight)
p.write_text(t, encoding="utf-8")
print("천장 480 → " + tight)
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수|Total'
```

Expected: `천장 480 → <실측+8>` 다음 ✓ 둘 + `Fail: 0`.

- [ ] **Step 4.6: 조인 천장이 이빨을 갖는지 변이로 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
cp "$SK" "$W/skill-tighten.bak"
python3 -c "
import pathlib; p=pathlib.Path('$SK'); p.write_text(p.read_text(encoding='utf-8')+'\n'*9, encoding='utf-8')"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수'
cp "$W/skill-tighten.bak" "$SK"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '줄 수|Total'
```

Expected: 9줄을 더하면 **✗ 둘**(실측+8 이므로 9줄이 넘긴다) → 복원 후 ✓ 둘 + `Fail: 0`. 9줄 변이가 green 이면 조이기가 안 된 것이다 — `-lt` 값이 실제로 바뀌었는지 확인한다.

- [ ] **Step 5: 전체 확인 + Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
for t in test_conducting_interview_stage.sh test_stale_terms.sh test_readme_sync.sh test_web_kill_switch.sh; do
  printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t 2>&1 | tail -1
done
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -1
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/agents/coverage-mapper.md plugins/spec-distill/agents/blind-spot-prober.md \
        plugins/spec-distill/README.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
feat(spec-distill): 호출 자격 · 예산 · C44 면제 — 순서가 계약이다

세 규칙이 겹쳐 있다. **자격**이 ⟨C12⟩ 문면 그대로 맨 앞이다 — 「그 장치가 채우는 차원에 닿는
열린 결정이 아직 있는가」. 예산만으로는 그 재개 조건을 구현하지 못한다(라운드 1). 자격 위에
**예산** `1 + 재개방` 이 얹히고, 재개방은 사용자 답이 걸린 사건이라 사용자가 시계다.

**면제의 순서가 이빨이다** — 「계수 먼저, 표시 나중」. 반대로 두면 계수 시점에 「아직 안 닿은 것」이
항상 공집합이라 첫 연결부터 +1 이 되고 면제가 영구히 발화하지 않는다. 라운드 2 가 그 반전을 잡았고,
⟨C13⟩ 재결정의 유한화 논거가 이 순서에 걸려 있었다.

옛 상한 문구 교체는 grep 으로 전수 재도출했다 — 설계 AC22 가 열거한 여섯은 `agents/` 만의 전수였고
SKILL.md 5 + README 3 이 더 있었다. 무관한 상한(엔진 재리뷰 상한 2 · 확정 재제시 상한 2회 ·
rhythm guard 3)은 건드리지 않았고 그 사실을 실측으로 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: 다섯 다 `Fail: 0`.
---

### Task 12: finishing.md — V2 누락 대조 · 반증 세 칸 · 인계 세 방향 · Step B advisory (AC7 · AC11)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (Step A/Step B 단언 추가)

**Interfaces:**
- Consumes: Task 8 의 audit §5 확인 줄 형식 · Task 10 의 `open_decisions[]` 종료 시 사상 규칙
- Produces: payload 세 자리의 **직렬화 형식** — Task 13(템플릿)과 Task 15·16·17(게이트 술어)이 이 형식을 그대로 쓴다:
  - §4·§5 항목 줄 **끝**: `[RC3 → OQ1]` · `[→ OQ1]` · `[→ 없음]` (복수는 `[RC3 → OQ1 · OQ4]`)
  - §3 OQ 줄: `→ 근거 RC3`
  - §0 결정 목록 줄: `- OQ1 [열림] — <한 줄> → 근거 RC3` / `- OQ1 [해결 ⟨S10⟩] — <한 줄> → 근거 RC3`

**V2 는 «누락 대조만» 한다** — 확인 «행위» 는 V1 이 라운드 안에서 이미 했다. V2 는 `finishing.md` Step A 에서 **무조건** 돌고 payload 의 모든 `RC<n>` 에 대응하는 확인 줄이 audit §5 에 있는지만 본다. 종속 없음(웹 스위치·trigger 무관).

**§0 이 상위집합이다** — `status: open` 인 것이 §3 으로, **전량**이 §0 으로 간다. `[해결 …]` 이 붙은 결정은 §3 에서 빠지고 §0 에만 남는다. §0 의 결정 목록은 **불릿 줄**이어야 한다 — 게이트의 `_entry_lines` 가 `^\s*[-*]\s` 를 요구한다.

**§2 는 대상이 아니다** — 근거가 사용자 발화(`evidence: S<N>`)이고 ✎ 블록은 `bijection_b_errors` 의 대상 밖이라, 거기에 새 술어를 걸면 그 bijection 과 이음매가 생긴다.

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = """# --- v0.23.0: 발화 기록 producer (AC1 positive, §8.2) ---"""
assert t.count(anchor) == 1
new = """# V2 검문소 + 인계 세 방향 (설계 §D · AC7 · AC19). 절 윈도우는 그것이 사는 $FIN 에서 뜬다.
fin_stepA="$(awk '/^### Step A — brief 작성/{f=1;print;next} /^### /{f=0} f' "$FIN")"
fin_stepA_flat="$(tr '\\n' ' ' <<<"$fin_stepA" | tr -s ' ')"
{ [[ -n "$fin_stepA" ]] && grep -qF 'Coverage Ledger' <<<"$fin_stepA"; } \\
  && ok "V2(양성대조): Step A 절을 잘랐다 ($(grep -c . <<<"$fin_stepA")줄)" \\
  || no "V2(양성대조): Step A 절을 못 잘랐다 — 아래 단언이 공허하다"
grep -qF 'V2' <<<"$fin_stepA" && ok "V2: Step A 에 V2 검문소" || no "V2: Step A 에 V2 검문소 부재"
grep -qF '누락 대조만 한다' <<<"$fin_stepA_flat" \\
  && ok "V2: 누락 대조만 (확인 행위는 V1 이 이미 했다)" || no "V2: 누락 대조 범위 문구 부재"
grep -qF '무조건' <<<"$fin_stepA_flat" && ok "V2: 무조건 발동" || no "V2: 무조건 발동 문구 부재"
grep -qF '*원래 / 재결정 / 근거*' <<<"$fin_stepA_flat" \\
  && ok "AC7: 반증의 세 칸 기록" || no "AC7: 반증 세 칸 부재"
grep -qF '재결정 자체는 사용자 동의로만' <<<"$fin_stepA_flat" \\
  && ok "AC7/P23: 재결정은 사용자 동의로만" || no "AC7/P23: 재결정 권한 문구 부재 — 기록 형식이 판정 권한으로 읽힌다"
for form in '[RC3 → OQ1]' '[→ OQ1]' '[→ 없음]' '→ 근거 RC3' '[해결 ⟨S10⟩]'; do
  grep -qF -- "$form" <<<"$fin_stepA" \\
    && ok "AC19: 직렬화 형식 «${form}»" || no "AC19: 직렬화 형식 «${form}» 부재"
done
grep -qF '§3 은 미해결의 목록이다' <<<"$fin_stepA_flat" \\
  && ok "AC19: §0 이 상위집합 · §3 이 그 중 열린 것" || no "AC19: §0/§3 포함 관계 문구 부재"
grep -qF '§2 는 대상이 아니다' <<<"$fin_stepA_flat" \\
  && ok "AC19: §2 는 새 술어의 대상이 아니다 (bijection B 와의 이음매 회피)" || no "AC19: §2 제외 문구 부재"
# 하위 불릿 금지는 **지시**이고 커버리지가 0 이었다(Task 12 리뷰가 실측: 정반대로 뒤집어도
# 스위트 무변화). 그 금지가 반대로 읽히면 저자가 하위 불릿을 쓰고 게이트가 그것도 §4 항목으로
# 세어 red 를 낸다 — 지시가 사용자를 red 로 이끈다. 리터럴에 부정어 「않는다」 가 들어 있어
# **한 단언이 반전과 삭제를 둘 다** 잡는다(실측: 반전 X · 삭제 X · 무해한 재줄바꿈 O).
grep -qF '하위 불릿으로 쓰지 않는다' <<<"$fin_stepA_flat" \\
  && ok "AC19: 하위 불릿 금지 (지시 — 반전·삭제 둘 다 잡는다)" \\
  || no "AC19: 하위 불릿 금지가 없거나 뒤집혔다 — 게이트가 들여쓴 불릿도 §4 항목으로 센다"
# Step B — 게이트 advisory 배달. 새 advisory 둘의 이름을 대야 한다.
fin_stepB="$(awk '/^#### B-2 —/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
grep -qF '내부 조사 0건' <<<"$fin_stepB" \\
  && ok "AC11: Step B 가 «내부 조사 0건» advisory 를 싣는다" || no "AC11: Step B 에 «내부 조사 0건» 부재"
grep -qF '신 계약 미적용 brief' <<<"$fin_stepB" \\
  && ok "AC23: Step B 가 «신 계약 미적용 brief» advisory 를 싣는다" || no "AC23: Step B 에 «신 계약 미적용 brief» 부재"

""" + anchor
p.write_text(t.replace(anchor, new), encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` **정확히 15건** (양성대조 1건은 ✓). 내역 — V2 검문소·누락대조·무조건 3 +
반증 세 칸·재결정 권한 2 + 직렬화 형식 다섯 5 + §0/§3 포함관계 1 + §2 제외 1 +
Step B advisory 둘 2 + 하위 불릿 금지 1 = 15.

**숫자가 다르면 멈추고 보고하라.** 이 기대값은 처음 어림수였다 — 이 브랜치에서 애매한
기대값이 이빨 공백을 정확히 가린 전례가 있으므로(Task 10) 정확히 요구한다. 선점검에서 확인한 것:
`### Step A — brief 작성` 절 절단이 70줄을 내고 `Coverage Ledger` 가 그 안에 있어 양성대조가
성립하며, `V2` 와 `무조건` 은 지금 그 절에 **0건**이라 두 단언이 미리 만족되지 않는다.

- [ ] **Step 2: Step A 에 V2 와 인계 세 방향을 넣는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/references/finishing.md")
t = p.read_text(encoding="utf-8")
old = """5. **기계적 게이트 검증** — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
"""
new = """5. **조사 주장의 인계 — 세 방향을 같은 id 로 맞물린다.** 하류는 brief 파일 경로를 받으므로
   §4·§5 를 포함한 전문을 읽을 수 있다. 하류에 **지시를 걸지 않고** 「읽을 이유」까지만 만든다.

   - **결정 연결(§4 · §5 → 결정)** — 조사 항목 줄 **끝**에 `[RC3 → OQ1]`(레포) 또는
     `[→ OQ1]`(웹) 또는 `[→ 없음]`(닿는 결정 없음). 복수는 `[RC3 → OQ1 · OQ4]` 로 전부
     직렬화한다. **하위 불릿으로 쓰지 않는다** — 게이트가 들여쓴 불릿도 §4 항목으로 세므로
     즉시 red 다.
   - **역참조(§3 → 근거)** — 그 OQ 줄이 근거의 **id** 를 담는다: `- OQ1: <한 줄> → 근거 RC3`.
     §3 항목은 그 자체가 열린 결정이라 연결의 *대상*이고 출처가 아니다.
   - **요약 상호참조(§0 → 근거)** — §0 의 결정 목록도 같은 id 를 쓰고 **상태 토큰**을 단다:
     `- OQ1 [열림] — <한 줄> → 근거 RC3` / `- OQ1 [해결 ⟨S10⟩] — <한 줄> → 근거 RC3`.
     `[해결 …]` 이 붙은 결정은 §3 에서 빠지고 §0 에만 남는다 — **§3 은 미해결의 목록이다.**
     §0 은 상위집합이므로 state `orchestration.open_decisions[]` **전량**이 여기 직렬화되고,
     그중 `status: open` 인 것만 §3 으로 간다. 이 목록은 **불릿 줄**이어야 한다(게이트가
     `- `/`* ` 로 시작하는 줄만 항목으로 읽는다).

   해결된 결정을 §0 에서 지우지 않는 이유: 조사가 그 결정을 해결하는 데 기여했으면 그것이 성공
   사례인데, 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 「열림」은 상태 토큰이
   말하고 목록에서의 부재가 말하지 않는다.

   **§2 는 대상이 아니다** — 근거가 사용자 발화(`evidence: S<N>`)이고 ✎ 블록은 bijection B(§2 본문
   ↔ frontmatter)의 대상 밖이라, 거기에 새 술어를 걸면 그 bijection 과 이음매가 생긴다.

6. **V2 검문소 — 무조건, 누락 대조만.** payload 의 모든 `RC<n>` 에 대응하는 확인 줄이 audit
   `## 5. 프로세스 로그` 에 있는지 대조한다. **확인 «행위» 는 V1 이 라운드 안에서 이미 했으므로
   여기서 다시 확인하지 않고 누락 대조만 한다.** 이 검문소는 웹 스위치와 steelman trigger 어느
   것에도 종속되지 않는다.

   ```bash
   # payload 의 RC<n> 전량 ↔ audit §5 의 확인 줄 — 차집합이 비어야 한다
   # 한 줄에 두 대입을 쓰지 않는다 — `test_finishing_block_scope.py` 의 `ASSIGN_RE` 는 **줄 시작**
   # 대입만 인식해 두 번째를 미정의 사용으로 오판한다(실측: 이 브랜치가 그 RED 를 만들었다).
   PL="docs/superpowers/interview/<file>"
   AD="${PL%.md}.audit.md"
   comm -23 <(grep -oE '(^|[^A-Za-z])RC[0-9]+' "$PL" | grep -oE 'RC[0-9]+' | sort -u) \\
            <(grep -oE '^- 확인 RC[0-9]+' "$AD" | grep -oE 'RC[0-9]+' | sort -u)
   ```
   출력이 있으면 그 `RC<n>` 의 확인 줄이 없다 — V1 을 태우지 않은 주장이므로 payload 에서 빼거나
   확인해서 줄을 적는다. 게이트도 같은 것을 본다(형태 ∀).

   V1 판정이 `반증` 이었던 항목은 그 항목이 닿는 확정을 payload §5 에 *원래 / 재결정 / 근거* 세 칸으로
   남긴다. **재결정 자체는 사용자 동의로만 한다**(P23) — 이 규약은 기록 형식이고 판정 권한이 아니다.

7. **기계적 게이트 검증** — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`. **Step A 의 번호가 5 → 7 로 늘어난다** — Step 3 이 뒤따르는 참조를 고친다.

- [ ] **Step 3: Step A 번호 참조와 Step B advisory 를 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
echo "--- 'Step A 5' 류 참조 전수"
grep -rn 'Step A 5\|Step A ⑤\|Step A(5)\|위 3의 sentinel\|Step A 4' \
  plugins/spec-distill --include='*.md' | grep -v CHANGELOG
```

Expected: **정확히 세 건**이고 그중 둘만 고친다 (선점검에서 전수 열거했다):

| 자리 | 가리키는 것 | 처분 |
|---|---|---|
| `finishing.md:5` | `아래 Step A ⑤ 의 check_brief.py` | ⑤ → ⑦ |
| `finishing.md:95` | `위 3의 sentinel을 빠뜨리면` | **그대로** — 항목 3 은 번호가 안 바뀐다 |
| `finishing.md:99` | `게이트(Step A 5)를 통과한 payload` | 5 → 7 |

네 건 이상 나오면 멈추고 보고하라 — 아래 python 이 고치는 것은 둘뿐이므로 나머지가 stale 로 남는다.
**그 참조를 새 번호로 고친다:**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/references/finishing.md")
t = p.read_text(encoding="utf-8")
for old, new in [
  ("집행 지점만 seed 와 다르다: seed 는 `check_seed.py`, brief 는 아래 Step A ⑤ 의 `check_brief.py`.",
   "집행 지점만 seed 와 다르다: seed 는 `check_seed.py`, brief 는 아래 Step A ⑦ 의 `check_brief.py`."),
  ("게이트(Step A 5)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고",
   "게이트(Step A 7)를 통과한 payload는 **Law 1 구조 자기검사**를 마친 것이고"),
]:
    assert t.count(old) == 1, old[:40]
    t = t.replace(old, new)

# Step B — 게이트 advisory 의 이름을 둘 더 댄다.
old = '''    question: "interview brief 완결: <brief-path> (구조 게이트 통과, 리뷰 <게이트 결과 한 줄 — 도달 사유 · 열린 항목 수 · 리뷰 완료가 아니면 그 사유(unreviewed_reason)>). 확정 후보·리뷰 게이트 결과·readback gap은 위 목록대로. 게이트 advisory: <check_brief 의 advisories 한 줄씩 (예: coverage-mapper 0 (unavailable: …)) | 없음>. degrade: <record 한 줄씩 | degrade 없음>. 다음 단계?",'''
new = '''    question: "interview brief 완결: <brief-path> (구조 게이트 통과, 리뷰 <게이트 결과 한 줄 — 도달 사유 · 열린 항목 수 · 리뷰 완료가 아니면 그 사유(unreviewed_reason)>). 확정 후보·리뷰 게이트 결과·readback gap은 위 목록대로. 게이트 advisory: <check_brief 의 advisories 한 줄씩 (예: coverage-mapper 0 (unavailable: …) · 내부 조사 0건 · 신 계약 미적용 brief) | 없음>. degrade: <record 한 줄씩 | degrade 없음>. 다음 단계?",'''
assert t.count(old) == 1
t = t.replace(old, new)

old2 = """`check_brief.py gate` 의 `advisories` 도 이 텍스트에 싣습니다 — `coverage-mapper 0
(unavailable: …)` 은 게이트가 관측할 수 없는 사실(실제 dispatch 여부)을 사람에게 넘기는
유일한 자리입니다.
"""
new2 = """`check_brief.py gate` 의 `advisories` 도 이 텍스트에 싣습니다 — `coverage-mapper 0
(unavailable: …)` 은 게이트가 관측할 수 없는 사실(실제 dispatch 여부)을 사람에게 넘기는
유일한 자리입니다. 조사 축의 advisory 둘도 같은 자리로 옵니다:

- **`내부 조사 0건`** — 이 brief 가 레포 주장(`RC<n>`)을 하나도 싣지 않았다. 게이트는 「조사를
  했어야 했는가」를 알 수 없다(이 스크립트는 brief 파일만 읽는다) — 그 판단이 여기서 사람에게 간다.
- **`신 계약 미적용 brief`** — payload frontmatter 에 `contract: v2` 가 없어 조사 축의 술어 다섯이
  전부 미발동이다. 옵트인의 fail-open 방향을 이 줄이 공시한다.
"""
assert t.count(old2) == 1
p.write_text(t.replace(old2, new2), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
```

Expected: `ok` 다음 `Fail: 0`.

- [ ] **Step 4: finishing.md 의 `§8`/`§9` 부재와 절 번호 일관성을 확인**

`:631` 이 `CI_ALL` 전역에서 `§[89]([^.0-9]|$)` 부재를 요구한다. 새 문면에 `§Open Questions`(번호 없음)만 썼으므로 안전하지만 확인한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
grep -nE '§[89]([^.0-9]|$)' plugins/spec-distill/skills/conducting-interview/references/finishing.md \
  plugins/spec-distill/references/research-claims.md || echo "0건 ✓"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'V11|Total'
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -1
```

Expected: `0건 ✓` · `V11: 은퇴 payload 좌표(§8/§9) 잔존 0` ✓ · stale `Fail: 0`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
feat(spec-distill): V2 누락 대조 + 인계 세 방향 + Step B advisory 둘

검문소 셋 중 둘째다. V2 는 **누락 대조만** 한다 — 확인 «행위» 는 V1 이 라운드 안에서 이미 했고,
여기서 다시 확인하면 같은 일을 두 번 한다. 무조건 돌고 웹 스위치·trigger 에 종속되지 않는다.

인계는 「읽을 이유」까지다 — 하류 구속 문구를 두지 않는다(P23·Sealed decision 과 충돌하고,
반증 소비 경로가 최소 형태뿐인 상태에서 구속만 먼저 걸면 위험을 관로화한다). 세 방향이 같은 id 로
맞물리는 것이 하류가 읽을 이유의 전부다.

해결된 결정을 §0 에서 지우지 않는다 — 조사가 결정을 해결하는 데 기여했으면 그것이 성공 사례인데
목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 상태 토큰이 「열림」을 말하고
목록에서의 부재가 말하지 않는다. §2 는 대상이 아니다(bijection B 와의 이음매 회피).

Step A 의 번호가 5 → 7 로 늘어 뒤따르는 참조 둘을 함께 고쳤다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 13: 템플릿 둘 — `contract: v2` 와 세 방향 예시 (AC19 · AC23)

**Files:**
- Modify: `plugins/spec-distill/templates/interview-brief-template.md`
- Modify: `plugins/spec-distill/templates/interview-audit-template.md`
- **재실행만**: `plugins/spec-distill/tests/test_audit_template_gate_shape.py` — 편집하지 않는다.
  audit §5 확인-줄 모양은 셸 락이 이미 `^- 확인 RC[0-9]+ — (확인|반증|미확인) — ` 로 재므로 python
  쪽에 중복 단언을 두지 않는다. Step 4 가 이 파일을 읽기 전용으로 돌려 회귀만 확인한다.

**Interfaces:**
- Consumes: Task 12 의 직렬화 형식 전량
- Produces: **green fixture 와 같은 모양**. Task 15·16·17 의 green fixture 는 이 템플릿을 베이스로 만든다 — 템플릿이 red 를 가르치면 첫 게이트가 항상 red 다(이 플러그인이 sentinel 에서 이미 겪은 결함).

**§0 을 불릿 목록으로 바꾼다** — 현재 §0 은 산문 한 문단이다. 게이트의 `_entry_lines` 가 `^\s*[-*]\s` 를 요구하므로 결정 목록은 불릿이어야 한다. **요약이라는 §0 의 성격은 유지한다** — 결정 목록은 「무엇이 열려 있음」의 렌더이고, 본문을 옮겨 적는 자리가 아니다.

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다 (템플릿 모양 락)**

기존 `test_audit_template_gate_shape.py` 는 audit 템플릿만 본다. payload 템플릿의 새 모양을 잴 단언을 셸 락에 둔다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = "finish\n"
assert t.endswith(anchor)
new = """
# --- 2026-09-23 템플릿 둘이 조사 축의 세 방향을 예시로 보인다 (AC19 · AC23) ------------------
# 템플릿이 red 를 가르치면 첫 게이트가 항상 red 다 — 이 플러그인이 sentinel 에서 이미 겪었다.
TPL_B="$REPO_ROOT/plugins/spec-distill/templates/interview-brief-template.md"
TPL_A="$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md"
[[ -f "$TPL_B" && -f "$TPL_A" ]] && ok "템플릿 둘 실재" || no "템플릿 둘 중 하나가 없다"
grep -qE '^contract: v2$' "$TPL_B" \\
  && ok "AC23: payload 템플릿이 contract: v2 를 넣는다" || no "AC23: contract: v2 부재 — 새 술어가 영구 미발동이다"
for form in '[RC3 → OQ1]' '[→ OQ1]' '[→ 없음]' '→ 근거 RC3'; do
  grep -qF -- "$form" "$TPL_B" && ok "AC19: payload 템플릿 예시 «${form}»" || no "AC19: payload 템플릿 예시 «${form}» 부재"
done
grep -qE '^- OQ1 \\[열림\\] ' "$TPL_B" \\
  && ok "AC19: §0 결정 목록이 불릿 + 상태 토큰" || no "AC19: §0 결정 목록이 불릿 줄이 아니다 (게이트가 항목으로 못 읽는다)"
grep -qF 'OQ4 [해결 ⟨S10⟩]' "$TPL_B" \\
  && ok "AC19: §0 의 해결 상태 토큰 예시" || no "AC19: 해결 상태 토큰 예시 부재"
# span 에 **상태** 를 넣는다. 이름만 재면 `closed` → `open` 변이가 통과하고(리뷰 실측: 287/287/0),
# 그러면 템플릿이 `open` 을 가르쳐 이 템플릿을 베이스로 만든 fixture 가 Task 16 의 술어 ④에서 red 가
# 된다 — 이 Task 가 막으려고 존재하는 실패 그 자체다. 실측 네 칸: 원본 O · closed→open X(잡음) ·
# 유사 이름 X(여전히 잡음) · 근거 문면만 교체 O(거짓 RED 없음).
grep -qF 'derived:internal_research — closed —' "$TPL_A" \\
  && ok "AC19: audit 템플릿 §1 의 derived:internal_research 행이 closed 상태로 있다" \\
  || no "AC19: derived:internal_research 행이 없거나 상태가 closed 가 아니다 — 템플릿이 red 를 가르친다"
grep -qE '^- 확인 RC[0-9]+ — (확인|반증|미확인) — ' "$TPL_A" \\
  && ok "AC19: audit 템플릿 §5 의 확인 줄" || no "AC19: 확인 줄 예시 부재"
finish
"""
p.write_text(t[: -len(anchor)] + new, encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` 9건.

- [ ] **Step 2: payload 템플릿을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/templates/interview-brief-template.md")
t = p.read_text(encoding="utf-8")

# ① frontmatter — 옵트인 스위치
old = "next_phase: superpowers:brainstorming\n"
# 락이 `^contract: v2$`(exact-line)로 재므로 **트레일링 주석을 달지 않는다** — 달면 그 정규식이
# 절대 맞지 않는다. 주석은 윗줄 독립 `#` 로 둔다.
new = ("next_phase: superpowers:brainstorming\n"
       "# contract: v2 — 조사 축 술어 다섯의 옵트인 스위치. 빼면 전부 미발동 + advisory\n"
       "contract: v2\n")
assert t.count(old) == 1
t = t.replace(old, new)

# ② §0 — 결정 목록을 불릿 + 상태 토큰으로
old = """## 0. 한눈에

(무엇 / 왜 / 무엇이 확정 / 무엇이 열려 있음 / 다음 stage. **이 절은 요약이다** — 본문을 여기
 옮겨 적는 자리가 아니라, 다음 세션이 여기만 읽고도 방향을 잡을 수 있어야 하는 자리다.)
"""
new = """## 0. 한눈에

(무엇 / 왜 / 무엇이 확정 / 무엇이 열려 있음 / 다음 stage. **이 절은 요약이다** — 본문을 여기
 옮겨 적는 자리가 아니라, 다음 세션이 여기만 읽고도 방향을 잡을 수 있어야 하는 자리다.)

**결정 목록** — state `orchestration.open_decisions[]` 전량. `[열림]`/`[해결 ⟨S<N>⟩]` 상태 토큰을
달고, 해결된 것도 **지우지 않는다**(조사가 그 결정을 해결하는 데 기여했으면 그것이 성공 사례다).
조사가 닿은 결정은 줄 끝에 `→ 근거 RC<n>` 로 그 근거의 id 를 되가리킨다. 불릿 줄이어야 한다.

- OQ1 [열림] — <한 줄> → 근거 RC3
- OQ4 [해결 ⟨S10⟩] — <한 줄> → 근거 RC3
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ③ §3 — 역참조
old = """- OQ1: ...
"""
new = """- OQ1: ... → 근거 RC3
- OQ4: ... (조사가 닿지 않은 열린 결정은 역참조가 없다)
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ④ §4 — 줄 끝 연결 셋
old = """- ... «example» — [취함] — 이유
"""
new = """- ... «example» — [취함] — 이유 [→ OQ1]
- ... «other» — [중립] — 이유 [→ 없음]
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ⑤ §4 머리 산문 — 연결의 위치 규약
old = """(1항목 = 1줄, **«출처키» 필수** + [취함|피함|중립] + 이유. 그 키가 가리키는 원자료
 URL은 audit `## 7. 확산 원자료`에 선언한다 — payload에는 키만 남는다.)
"""
new = """(1항목 = 1줄, **«출처키» 필수** + [취함|피함|중립] + 이유. 그 키가 가리키는 원자료
 URL은 audit `## 7. 확산 원자료`에 선언한다 — payload에는 키만 남는다.
 **줄 끝에 결정 연결**: `[RC<n> → OQ<n>]`(레포) · `[→ OQ<n>]`(웹) · `[→ 없음]`(닿는 결정 없음).
 복수는 `[RC3 → OQ1 · OQ4]`. 하위 불릿으로 쓰지 않는다 — 들여쓴 불릿도 §4 항목으로 세어져 red 다.)
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ⑥ §5 — RC<n> 을 실은 줄의 예시
old = """- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>
"""
new = """- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>
- 위험 — 숨은 가정 | <내용> — RC3 (plugins/x/y.py#sym) [RC3 → OQ1]
- 기각 — <원래> / <재결정> / <근거 RC4 반증> — V1 판정이 반증이었을 때의 세 칸
"""
assert t.count(old) == 1
t = t.replace(old, new)

# ⑦ §5 머리 산문 — 순회 범위
old = """(`기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
"""
new = """(`기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
 이 절에서 조사 축의 대상은 **`RC<n>` 리터럴을 가진 줄만**이다 — 네 모양(기각·보류·검토·위험) 중
 어느 것인지는 묻지 않는다. `RC<n>` 이 없는 줄은 결정 연결을 요구받지 않는다.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
```

Expected: `ok`.

- [ ] **Step 3: audit 템플릿을 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/templates/interview-audit-template.md")
t = p.read_text(encoding="utf-8")

old = "- derived:<name> — closed — <rationale>; <evidence> (@S1)\n"
new = ("- derived:<name> — closed — <rationale>; <evidence> (@S1)\n"
       "- derived:internal_research — closed — 내부(레포) 조사 축; <evidence> (@S1)\n")
assert t.count(old) == 1
t = t.replace(old, new)

old = """ 아래의 `S1`은 **예시**이며, 실제로는 그 차원의 닫힘을 근거한 실제 `S<N>`으로 — 행마다
 서로 다른 발화로 — 바뀐다.)
"""
new = """ 아래의 `S1`은 **예시**이며, 실제로는 그 차원의 닫힘을 근거한 실제 `S<N>`으로 — 행마다
 서로 다른 발화로 — 바뀐다.
 payload 가 레포 주장(`RC<n>`)을 하나라도 실으면 **정확히 `derived:internal_research`** 라는
 이름의 행이 있고 상태가 `closed` 여야 한다 — 이름이 다른 derived 행이나 `open` 행으로는
 만족되지 않는다. 레포 주장이 0건이면 이 요구가 발동하지 않으므로 `- derived: N/A` 로 통과한다.)
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = "- round <n>: <path (a|b|d)> — <한 줄 요약>\n"
new = """- round <n>: <path (a|b|d)> — <한 줄 요약>

(V1 검문소의 확인 줄 — payload 의 `RC<n>` 마다 한 줄. 판정은 {확인, 반증, 미확인} 셋이고
 `미확인` 은 라벨로 **보인다**(조용히 흡수하지 않는다). 게이트가 이 줄을 payload 의 `RC<n>` 전량과
 대조한다. steelman 경로의 주장도 여기 적는다 — 확인 «행위» 는 한 번이고 기록만 §3·§5 둘이다.)

- 확인 RC3 — 확인 — <경로>#<앵커> — 주장과 일치
- 확인 RC4 — 반증 — <경로>#<앵커> — 그 자리는 <실제>이고 주장은 <주장>이었다
- 확인 RC5 — 미확인 — <경로>#<앵커> — <왜 확정하지 못했는가>

(D6 의무가 미발동이면 그 사실을 한 줄로: `- D6 검증 의무 미발동 — seed 의 «다시 검증할 것» 문단이 비었다`)
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '✗|Total'
```

Expected: `ok` 다음 `Fail: 0`.

- [ ] **Step 4: audit 템플릿 모양 락과 게이트를 템플릿에 직접 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v \
  plugins.spec-distill.tests.test_audit_template_gate_shape 2>&1 | tail -5 || \
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_audit_template_gate_shape.py' -v 2>&1 | tail -8
```

Expected: `OK`. RED 면 `budget_mapper_failures` 가 새로 추가한 산문 줄의 숫자를 데이터 줄로 오독한 것이다 — 새 줄에 `coverage-mapper <숫자>` 패턴을 넣지 않았는지 확인한다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -1
git add plugins/spec-distill/templates/ plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -F - <<'MSG'
feat(spec-distill): 템플릿 둘이 조사 축의 세 방향을 가르친다

템플릿이 red 를 가르치면 첫 게이트가 항상 red 다 — 이 플러그인이 sentinel 에서 이미 겪은 결함이다.
그래서 예시가 곧 green fixture 의 모양이어야 한다.

payload 템플릿에 `contract: v2` 를 넣는다 — 이 필드가 조사 축 술어 다섯의 옵트인 스위치이고,
템플릿이 넣으므로 앞으로의 산출은 전부 발동한다. 기존 코퍼스 81개는 이 필드가 없어 한 글자도
바뀌지 않는다.

§0 의 결정 목록을 불릿으로 바꾼다 — 게이트가 `- `/`* ` 로 시작하는 줄만 항목으로 읽는다. 요약이라는
§0 의 성격은 유지한다: 결정 목록은 「무엇이 열려 있음」의 렌더다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: `test_check_brief.sh` `Fail: 0` — **템플릿은 픽스처가 아니므로 게이트 스위트에 영향이 없어야 한다.** 영향이 있으면 어떤 픽스처가 템플릿을 참조하는지 찾아 기록한다.
---

### Task 14: `check_brief.py` — 옵트인 스위치 · 순회 정의 · advisory 둘 (AC9 · AC11 코드 · AC23)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md` + `.audit.md`
- Modify: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: Task 12·13 의 직렬화 형식
- Produces: 다섯 술어가 공유하는 헬퍼 넷 —
  - `contract_v2(text) -> bool` — 옵트인 스위치
  - `research_entries(text) -> list[str]` — 「조사 항목」 순회 정의
  - `payload_rc_ids(text) -> list[str]` — payload 가 실은 `RC<n>` 전량
  - `LINK_RE` · `RC_RE` · `OQ_RE` — 표기 정규식
  Task 15·16·17 이 이 넷을 그대로 쓴다.

**「조사 항목」의 순회 정의** (설계 §E 와 **같은 문면**이어야 한다 — AC9 가 코드 주석과 설계의 문면 일치를 요구한다):
- payload §4 의 모든 항목 줄
- payload §5 의 항목 줄 중 **`RC<n>` 리터럴을 가진 줄**
- **§3 은 순회 범위에 없다** — 연결의 대상이라 자기지시가 된다

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_check_brief.sh")
t = p.read_text(encoding="utf-8")
anchor = "\nfinish\n"
assert t.endswith(anchor), repr(t[-20:])
new = """
# === 2026-09-23 조사 축 (설계 2026-09-22-interview-research-specialization-design) ==========
# V2-OPT: 옵트인. `contract: v2` 가 없는 payload 는 새 술어 다섯이 전부 미발동이고 advisory 하나.
# V2-DEF: 「조사 항목」 순회 정의 — §4 전부 + §5 의 RC<n> 줄. §3 제외.
FXV="$FX/interview-brief-v2-valid.md"
v2run() {   # v2run <payload> → stdout=JSON, 전역 V2RC 에 rc
  V2OUT="$(python3 "$SCRIPT" gate "$1" 2>/dev/null)"; V2RC=$?
}

# V2-OPT-a: 기존 정상 쌍(contract 키 없음) → green + 「신 계약 미적용」 advisory
v2run "$FX/interview-brief-valid.md"
{ [[ "$V2RC" -eq 0 ]] && grep -q '신 계약 미적용 brief' <<<"$V2OUT"; } \\
  && ok "V2-OPT-a: contract 없는 기존 payload 는 green + 미적용 advisory (침묵과 0 을 가른다)" \\
  || no "V2-OPT-a: rc=$V2RC · advisory 부재 — 옵트인이 조용히 통과한다"

# V2-OPT-b: `contract: v2` green fixture → green + 「내부 조사 0건」 이 **아니다**(RC 를 싣는다)
[[ -f "$FXV" ]] && ok "V2 green fixture 실재" || no "V2 green fixture 부재: $FXV"
v2run "$FXV"
{ [[ "$V2RC" -eq 0 ]] && ! grep -q '신 계약 미적용 brief' <<<"$V2OUT"; } \\
  && ok "V2-OPT-b: contract: v2 green fixture 는 green 이고 미적용 advisory 가 없다" \\
  || no "V2-OPT-b: rc=$V2RC · 미적용 advisory 가 남았다 — 옵트인 판독이 깨졌다"
grep -q '내부 조사 0건' <<<"$V2OUT" \\
  && no "V2-OPT-b: green fixture 가 RC<n> 을 싣는데 «내부 조사 0건» advisory 가 떴다" \\
  || ok "V2-OPT-b: 0건 advisory 가 뜨지 않는다 (양의 짝)"

# V2-OPT-c: contract: v2 인데 RC<n> 0건 → green + 「내부 조사 0건」 advisory
cp "$FXV" "$TMPD/z.md"; cp "${FXV%.md}.audit.md" "$TMPD/z.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: z.audit.md|' "$TMPD/z.md"; rm -f "$TMPD/z.md.bak"
sed -i.bak 's|^payload:.*|payload: z.md|' "$TMPD/z.audit.md"; rm -f "$TMPD/z.audit.md.bak"
python3 - "$TMPD/z.md" "$TMPD/z.audit.md" <<'PYX'
import re, sys, pathlib
# 레포 주장을 통째로 뺀다: §4·§5 의 연결에서 RC 를 지우고(웹 형태로), §3·§0 의 역참조와
# audit 의 확인 줄·derived 행도 함께 뺀다 — 「0건」 상태를 만드는 것이 목적이다.
pl = pathlib.Path(sys.argv[1]); s = pl.read_text(encoding="utf-8")
s = re.sub(r"\\[RC\\d+ → ", "[→ ", s)
s = re.sub(r" ?→ 근거 RC\\d+", "", s)
s = re.sub(r"^- 위험 — .*RC\\d+.*$\\n", "", s, flags=re.M)
pl.write_text(s, encoding="utf-8")
ad = pathlib.Path(sys.argv[2]); a = ad.read_text(encoding="utf-8")
a = re.sub(r"^- 확인 RC\\d+ .*$\\n", "", a, flags=re.M)
# 행을 지우면 기존 AC10(`coverage_ledger_failures` — derived 행 ≥1 또는 N/A sentinel)이 먼저 red 다
a = a.replace("- derived:internal_research — closed — 내부 조사 축 (@S1)\\n", "- derived: N/A\\n")
ad.write_text(a, encoding="utf-8")
PYX
v2run "$TMPD/z.md"
{ [[ "$V2RC" -eq 0 ]] && grep -q '내부 조사 0건' <<<"$V2OUT"; } \\
  && ok "V2-OPT-c: RC<n> 0건이면 green + «내부 조사 0건» advisory (∀ 는 공허 통과)" \\
  || no "V2-OPT-c: rc=$V2RC — 0건이 차단됐거나 advisory 가 없다. 개수 술어가 끼어들었을 수 있다"

# V2-DEF: §3 은 순회 범위 밖 — §3 항목에 연결이 없어도 red 가 아니다.
cp "$FXV" "$TMPD/d.md"; cp "${FXV%.md}.audit.md" "$TMPD/d.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: d.audit.md|' "$TMPD/d.md"; rm -f "$TMPD/d.md.bak"
sed -i.bak 's|^payload:.*|payload: d.md|' "$TMPD/d.audit.md"; rm -f "$TMPD/d.audit.md.bak"
v2run "$TMPD/d.md"
[[ "$V2RC" -eq 0 ]] \\
  && ok "V2-DEF: §3 항목이 줄끝 연결을 갖지 않아도 green (§3 은 대상이고 출처가 아니다)" \\
  || no "V2-DEF: §3 이 순회 범위에 들어갔다 — 자기지시로 술어가 공허해진다"
finish
"""
p.write_text(t[: -len(anchor)] + new, encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` **정확히 5건**, `✓` 1건. 셀별로 재라 — 합계보다 이것이 계약이다:

| 단언 | Step 1 | 왜 |
|---|---|---|
| `V2-OPT-a` (미적용 advisory) | ✗ | advisory 가 아직 없다 |
| `V2 green fixture 실재` | ✗ | `$FXV` 는 Step 2 가 만든다 |
| `V2-OPT-b: green` | ✗ | 없는 파일에 게이트를 돌리면 rc 1 (실측) |
| `V2-OPT-b: 0건 advisory 안 뜬다` | **✓** | **공허하다** — 아래 경고 |
| `V2-OPT-c` (0건 advisory) | ✗ | fixture 가 없어 rc 1 |
| `V2-DEF` (§3 은 범위 밖) | ✗ | fixture 가 없어 rc 1 |

**Step 1 의 ✓ 를 증거로 읽지 마라.** 그 단언은 「advisory 가 뜨지 않는다」를 요구하는데, 지금은
advisory 자체가 구현되지 않아 **어떤 입력에도 안 뜬다** — 통과가 술어의 정확성을 말하지 않는다.
그 ✓ 가 의미를 갖는 것은 Step 2·3 뒤에 **여전히** ✓ 일 때다. 숫자가 다르면 멈추고 보고하라.

- [ ] **Step 2: green fixture 쌍을 만든다**

`interview-brief-valid.md` 를 베이스로 하고 Task 13 의 템플릿 모양을 그대로 쓴다.

`plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md`:

```markdown
---
name: sample-topic-v2
type: interview-brief
created_at: 2026-09-23
session_id: testsessionv2
source: spec-distill conducting-interview 3.3.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: interview-brief-v2-valid.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "대시보드는 SSR로 렌더한다"
    evidence: S1
---

# Sample Topic v2 — Interview Brief

## 0. 한눈에

TTFP를 줄이는 것이 진짜 목표다.

- OQ1 [열림] — 인증 뷰의 캐시 전략 → 근거 RC3
- OQ4 [해결 ⟨S1⟩] — 렌더링 전략 → 근거 RC3

## 1. Goal · Non-goal

- Goal: 대시보드 최초 페인트 시간 단축
- Non-goal: 전체 앱의 렌더링 전략 통일

## 2. 제약

- 🗣 confirmed **C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩

## 3. Open Questions

- OQ1: 인증 뷰의 캐시 전략 → 근거 RC3

## 4. External Landscape

- Next.js app-router SSR «nextjs-docs» — [취함] — 데이터 형태와 부합 [→ OQ1]
- 부분 하이드레이션 «islands» — [중립] — 이 결정과 무관 [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — N/A — 전부 first-time defend+lock
- 검토 — steelman 0건: 검토한 방향 1개 · 전제 P1 · trigger 후보 landscape 모순 → 기각 이유 모순 없음
- 위험 — 숨은 가정 | 캐시 계층이 인증 뷰를 이미 다룬다 — RC3 [RC3 → OQ1 · OQ4]

## 6. 사용자 원문
- **S1** 🗣 최초 요청:
  > "대시보드가 너무 느려요."
## 7. Next Action

이 brief를 context로 brainstorming 호출.
```

`plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.audit.md`:

```markdown
---
type: interview-audit
payload: interview-brief-v2-valid.md
created_at: 2026-09-23
session_id: testsessionv2
source: spec-distill conducting-interview 3.3.0
---

# Sample Topic v2 — Interview Audit

## 1. Coverage Ledger

- floor:root_problem — closed — §1 Goal (@S1)
- floor:landscape — closed — §4 인용 (@S1)
- floor:skepticism — closed — §5 검토 항목 (@S1)
- floor:blind_spot — closed — §5 위험 (@S1)
- floor:open_questions — closed — §3 OQ1 (@S1)
- derived:internal_research — closed — 내부 조사 축 (@S1)

## 2. Budget

- 질문 라운드: 2 · agent dispatch: 1 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-23) — web: enabled

## 5. 프로세스 로그

- round 1: (d) ontological — 진짜 목표 재구성
- 확인 RC3 — 확인 — plugins/spec-distill/scripts/check_brief.py#coverage_anchor_failures — 주장과 일치

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

## 7. 확산 원자료

- «nextjs-docs» — https://nextjs.org/docs/app — 픽스처용 선언
- «other» — https://example.com/other — 무엇을 확인했나
- «islands» — https://example.com/islands — 픽스처용 선언
```

Expected(Step 2 검증): `python3 plugins/spec-distill/scripts/check_brief.py gate plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md` → **이 시점에는** 아직 옵트인 분기가 없으므로 기존 26개 술어만 돌고 `{"pass": true}` rc 0. red 면 fixture 가 기존 술어 하나를 어긴 것이므로 그 failure 를 먼저 고친다(새 술어의 red 가 아니다).

- [ ] **Step 3: `check_brief.py` 에 옵트인·순회 정의·advisory 를 넣는다**

`coverage_anchor_failures` 뒤(`MAPPER_RE` 주석 앞)에 붙인다:

```python
# ── 조사 주장의 결정 연결 (2026-09-22-interview-research-specialization-design §E · §H) ─────
#
# **「조사 항목」의 순회 정의** — 설계 §E 와 같은 문면이고 이 셋이 전부다:
#   · payload §4 의 모든 항목 줄(프로필상 전부 landscape 다)
#   · payload §5 의 항목 줄 중 **`RC<n>` 리터럴을 가진 줄** — 네 모양(기각·보류·검토·위험) 중
#     어느 것인지는 묻지 않는다. `RC<n>` 이 있으면 레포 주장을 실은 줄이고 없으면 아니다.
#   · **§3 은 순회 범위에 없다.** §3 항목은 그 자체가 «열린 결정» 이라 연결의 *대상*이고
#     출처가 아니다 — 거기에 연결을 걸면 자기지시가 되어 술어가 공허해진다.
#
# 연결의 위치는 **줄 끝**이고 하위 불릿은 금지다: `ENTRY_BULLET_RE`(`^\s*[-*]\s`)가 들여쓴
# 불릿도 §4 항목으로 세므로 하위 불릿 형태는 즉시 `unkeyed landscape entries` red 가 된다.
#
# **개수 술어를 두지 않는다**(설계 ⟨C5⟩·X7·AC8). 아래 술어는 전부 ∀ 이고 순회할 항목이 0건이면
# 공허하게 통과한다 — `landscape_unkeyed` 가 §4 에 대해 이미 하는 것과 같은 형태다. 개수가
# 들어가는 곳은 **조건 분기와 advisory** 뿐이고 둘 다 무엇도 막지 않는다. 차단 메시지 문면에도
# 개수를 넣지 않는다.
RC_RE = re.compile(r"(?<![A-Za-z])RC\d+\b")
OQ_RE = re.compile(r"(?<![A-Za-z])OQ\d+\b")
# 줄 끝 연결 — 셋 중 하나(§H ③). `[→ 없음]` sentinel 은 정직한 답이고 red 가 아니다: §A 계약이
# 「빈 배열은 허용이고 거짓 연결보다 낫다」를 못 박으므로 sentinel 없는 ∀ 는 그 계약과 충돌하고
# 「필러 절」 압력을 만든다. **「없음」의 개수는 세지 않는다.**
LINK_RE = re.compile(
    r"\[(?:(RC\d+)\s*→\s*(OQ\d+(?:\s*·\s*OQ\d+)*)"
    r"|→\s*(OQ\d+(?:\s*·\s*OQ\d+)*)"
    r"|→\s*없음)\]\s*$")
CONTRACT_KEY, CONTRACT_V2 = "contract", "v2"
DERIVED_INTERNAL_RESEARCH = "derived:internal_research"
CONFIRM_ROW_RE = re.compile(r"^확인\s+(RC\d+)\s+—\s+(확인|반증|미확인)\s+—\s*(\S.*)$")

INTERNAL_RESEARCH_ZERO_ADVISORY = (
    "[spec-distill] 내부 조사 0건 — 이 brief 는 레포 주장(`RC<n>`)을 하나도 싣지 않았다. 이 게이트는 "
    "brief 파일만 읽으므로 「조사를 했어야 했는가」를 알 방법이 없다 — 그 판단은 Step B 게이트에서 "
    "사람이 한다."
)
CONTRACT_V1_ADVISORY = (
    "[spec-distill] 신 계약 미적용 brief — payload frontmatter 에 `contract: v2` 가 없어 조사 주장의 "
    "결정 연결 술어 다섯(연결 ∀ · 연결 대상 실재 · 역참조 ∀ · 이름 정확 일치 derived · 확인 줄 ∀)이 "
    "전부 미발동이다. 옵트인의 fail-open 방향을 이 줄이 공시한다."
)


def contract_v2(text: str) -> bool:
    """payload frontmatter 의 `contract: v2` 옵트인 스위치 (설계 §H ⑥).

    새 술어 다섯은 이 필드가 있을 때만 발동한다. 없으면 전부 미발동이고 `advisories` 에
    「신 계약 미적용 brief」 한 줄이 실린다 — 침묵과 0 은 다른 사실이다.

    **왜 옵트인인가**: §4 항목에 연결을 ∀ 로 요구하면 `## 4. External Landscape` 를 가진 payload
    픽스처 전량이 red 가 되고 그중 `interview-brief-valid.md` 는 스위트 다수의 베이스다. 일괄
    편집은 회귀 생산원이고 optional 은 이빨 0이다 — 세 번째 길이 이것이다. 값 판독은
    `frontmatter_value` 하나를 쓴다(중복 키·개행 포획·부분 비교를 그 함수가 이미 닫았다).
    """
    return frontmatter_value(CONTRACT_KEY, _frontmatter(text)) == (CONTRACT_V2, None)


def research_entries(text: str) -> list[str]:
    """위 순회 정의 그대로 — §4 의 모든 항목 줄 + §5 에서 `RC<n>` 을 가진 줄. §3 은 제외."""
    out = _entry_lines(_section_text(text, "4", "External Landscape"))
    out += [ln for ln in section5_entries(text) if RC_RE.search(ln)]
    return out


def payload_rc_ids(text: str) -> list[str]:
    """payload 가 실은 레포 주장 id 전량 — **순회 정의 안에서만** 센다.

    코퍼스를 payload 전문으로 넓히지 않는다: §3 의 `→ 근거 RC3` 역참조와 §0 요약도 같은 리터럴을
    담으므로, 전문을 세면 확인 줄 ∀ 가 «출처 없는 역참조» 에도 확인 줄을 요구한다. 출처는 §4·§5 이고
    §3·§0 은 그것을 가리키는 자리다(설계 §D).
    """
    return sorted({rc for ln in research_entries(text) for rc in RC_RE.findall(ln)})
```

Expected(Step 3 검증): `python3 -c "import ast,pathlib; ast.parse(pathlib.Path('plugins/spec-distill/scripts/check_brief.py').read_text(encoding='utf-8')); print('parse ok')"` → `parse ok`. 그리고 `grep -c 'def contract_v2\|def research_entries\|def payload_rc_ids' plugins/spec-distill/scripts/check_brief.py` → `3`.

- [ ] **Step 4: `gate()` 에 옵트인 분기와 advisory 둘을 배선한다**

`coverage anchors` 블록 **뒤**, `ok = not failures` **앞**에 넣는다(그 자리라야 `audit_text` 와 `sec4_absent`·`sec5_absent` 가 이미 있다):

```python
    # --- 조사 주장의 결정 연결 (설계 §E). 다섯 술어 전부 `contract: v2` 옵트인 뒤에 있다.
    #     술어 자체는 뒤따르는 커밋이 채우고, 이 분기는 스위치와 두 advisory 만 세운다.
    if contract_v2(text):
        if not payload_rc_ids(text):
            advisories.append(INTERNAL_RESEARCH_ZERO_ADVISORY)
    else:
        advisories.append(CONTRACT_V1_ADVISORY)
```

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/scripts/check_brief.py gate \
  plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md; echo "rc=$?"
PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/scripts/check_brief.py gate \
  plugins/spec-distill/tests/fixtures/interview-brief-valid.md; echo "rc=$?"
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -3
```

Expected: v2 fixture `{"pass": true, …}` rc=0 이고 advisories 에 미적용 줄이 **없다**. 기존 fixture rc=0 이고 advisories 에 미적용 줄이 **있다**. `test_check_brief.sh` `Fail: 0`.

- [ ] **Step 5: 순회 정의의 문면 일치를 확인하고 Commit**

AC9 는 「순회 정의가 코드 주석과 이 설계에 **같은 문면**으로 있다」를 요구한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
# -F 필수 — `**` 는 BRE 메타문자라 없으면 볼드 없는 문면에도 거짓 ≥1 이 나온다. 셋 다 code·design ≥1 이어야 한다.
for s in '§4 의 모든 항목 줄(프로필상 전부 landscape 다)' '§3 은 순회 범위에 없다' '위치는 **줄 끝**'; do
  printf '%s → code:%s design:%s\n' "$s" \
    "$(grep -cF -- "$s" plugins/spec-distill/scripts/check_brief.py)" \
    "$(grep -cF -- "$s" docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md)"
done
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/
git commit -F - <<'MSG'
feat(spec-distill): contract: v2 옵트인 + 「조사 항목」 순회 정의 + advisory 둘

라운드 2 가 실측했다 — §4 항목에 연결을 ∀ 로 요구하면 `## 4. External Landscape` 를 가진 payload
픽스처 81개가 red 가 되고 그중 `interview-brief-valid.md` 는 스위트 다수의 베이스다. 일괄 편집은
회귀 생산원이고 optional 은 이빨 0이다 — 세 번째 길로 frontmatter 옵트인을 쓴다. 기존 81개는
한 글자도 바뀌지 않고, 템플릿이 새 payload 에 그 필드를 넣으므로 앞으로의 산출은 전부 발동한다.

옵트인의 fail-open 방향은 advisory 가 공시한다 — 침묵과 0 은 다른 사실이다. 「내부 조사 0건」도
같은 채널로 가고, 게이트는 「조사를 했어야 했는가」를 알 방법이 없다(이 스크립트는 brief 파일만
읽는다는 모듈 불변식). 그 판단은 Step B 에서 사람이 한다.

순회 정의는 설계 §E 와 같은 문면으로 코드 주석에 둔다 — 두 곳이 갈라지면 어느 쪽이 계약인지 모른다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: 세 문면이 code·design 양쪽에서 각각 ≥1.

---

### Task 15: 술어 ①②③ — 연결 ∀ · 대상 실재 · 역참조 ∀ (AC8)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Create: `tests/fixtures/interview-brief-v2-nolink.md`(+audit) · `-badtarget.md`(+audit) · `-nobackref.md`(+audit)
- Modify: `plugins/spec-distill/tests/test_check_brief.sh`

**Interfaces:**
- Consumes: Task 14 의 python 헬퍼 넷 · Task 14 가 **같은 락 파일에 이미 세운 셸 헬퍼** `FXV`(green
  fixture 경로) 와 `v2run()`.
- Produces: 술어 셋 `research_link_missing` · `research_link_targets_missing` ·
  `research_backref_missing`. Task 19 의 변이가 이 셋을 흔든다.
  **그리고 셸 헬퍼 `v2mut()`** — `test_check_brief.sh` 안의 함수로, green fixture 쌍을 `$TMPD` 로
  복사해 `audit_file:` 을 고치고 한 가지만 망가뜨린 뒤 게이트를 돌려 `$V2OUT`·`$V2RC` 를 채운다.
  **Task 16·17 이 이 함수를 그대로 쓴다 — 재정의하지 않는다.**

**③ 이 ∀ 인 이유** — 단수·∃ 로 두면 §0 줄 하나로 만족돼 §3 의 `→ 근거 RC3` 을 지워도 통과한다. 라운드 1 이 지목한 구멍이 자리만 옮겨 남는다. 방향을 뒤집어 **`OQ<n>` 줄이 그 근거 id 를 포함하는가**를 본다.

**② 가 상태를 보지 않는 이유(L3)** — §0 은 해결된 결정도 상태 토큰을 붙여 남기므로, 「열려 있는가」를 보면 **결정을 해결하는 데 기여한 조사가 red 가 된다.** 성공을 red 로 만드는 술어는 목표의 반전이다. 의도된 한계다.

- [ ] **Step 1: red fixture 셋과 실패하는 테스트를 먼저 쓴다**

세 red 는 green fixture 에서 **정확히 한 가지만** 망가뜨려 만든다(런타임 생성 — 파일을 늘리지 않는다).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_check_brief.sh")
t = p.read_text(encoding="utf-8")
anchor = "\nfinish\n"
assert t.endswith(anchor)
new = """
# V2-①②③ — red/green 짝. red 는 green 에서 **한 가지만** 망가뜨려 만든다(원인 분리).
v2mut() {   # v2mut <셀> <python 변형 코드> → $TMPD/<셀>.md 를 만들고 게이트를 돌린다
  local cell="$1" code="$2"
  cp "$FXV" "$TMPD/$cell.md"; cp "${FXV%.md}.audit.md" "$TMPD/$cell.audit.md"
  sed -i.bak "s|^audit_file:.*|audit_file: $cell.audit.md|" "$TMPD/$cell.md"; rm -f "$TMPD/$cell.md.bak"
  PYTHONDONTWRITEBYTECODE=1 python3 -c "$code" "$TMPD/$cell.md" "$TMPD/$cell.audit.md"
  V2OUT="$(python3 "$SCRIPT" gate "$TMPD/$cell.md" 2>/dev/null)"; V2RC=$?
}

# ① 연결 ∀ — §4 항목의 줄끝 연결을 지운다
v2mut nolink 'import sys,pathlib,re
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
s=s.replace(" [→ OQ1]\\n","\\n",1); p.write_text(s,encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q '결정 연결 없음' <<<"$V2OUT"; } \\
  && ok "V2-①: §4 항목의 줄끝 연결을 지우면 red" || no "V2-①: 연결 부재가 통과됐다 (rc=$V2RC)"
grep -qE '[0-9]+건|개수' <<<"$(printf '%s' "$V2OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\\n".join(x for x in d["failures"] if "연결" in x))')" \\
  && no "V2-①: 차단 메시지에 개수가 들어갔다 (⟨C5⟩ — 재서 막으면 사후 장치다)" \\
  || ok "V2-①: 차단 메시지에 개수가 없다"

# ① sentinel — `[→ 없음]` 은 red 가 아니다
v2mut sentinel 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
s=s.replace(" [→ OQ1]"," [→ 없음]",1); p.write_text(s,encoding="utf-8")'
[[ "$V2RC" -eq 0 ]] \\
  && ok "V2-①(양의 짝): [→ 없음] sentinel 은 정직한 답이고 red 가 아니다" \\
  || no "V2-①: sentinel 이 red 다 — 계약의 「빈 배열 허용」과 충돌하고 필러 절 압력을 만든다 (rc=$V2RC)"

# ② 연결 대상 실재 — §3·§0 에 없는 OQ 를 가리킨다
v2mut badtarget 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
s=s.replace("[→ OQ1]","[→ OQ9]",1); p.write_text(s,encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q 'OQ9' <<<"$V2OUT"; } \\
  && ok "V2-②: §3·§0 에 없는 OQ 를 가리키면 red (그 id 를 이름으로 댄다)" \\
  || no "V2-②: 없는 대상이 통과됐다 (rc=$V2RC)"

# ② 상태는 보지 않는다 — 해결된 결정에 연결해도 green (L3, 의도된 한계)
v2mut resolved 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
s=s.replace("[RC3 → OQ1 · OQ4]","[RC3 → OQ4]",1)
s=s.replace("- OQ1: 인증 뷰의 캐시 전략 → 근거 RC3","- OQ1: 인증 뷰의 캐시 전략")
s=s.replace("- OQ1 [열림] — 인증 뷰의 캐시 전략 → 근거 RC3","- OQ1 [열림] — 인증 뷰의 캐시 전략")
s=s.replace("[→ OQ1]","[→ OQ4]",1); p.write_text(s,encoding="utf-8")'
[[ "$V2RC" -eq 0 ]] \\
  && ok "V2-②(L3): 해결된 결정에 연결해도 green — 상태를 보면 성공이 red 가 된다" \\
  || no "V2-②: 상태 토큰을 검사한다 (rc=$V2RC) — R11 이 기각한 방향이다"

# ③ 역참조 ∀ — §3 의 역참조만 지운다(§0 은 남긴다). ∃ 면 이것이 통과한다.
v2mut nobackref 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
old="- OQ1: 인증 뷰의 캐시 전략 → 근거 RC3"
assert s.count(old)==1
s=s.replace(old,"- OQ1: 인증 뷰의 캐시 전략"); p.write_text(s,encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q '역참조' <<<"$V2OUT"; } \\
  && ok "V2-③: §3 의 역참조만 지워도 red (∀ 다 — ∃ 면 §0 하나로 만족된다)" \\
  || no "V2-③: ∃ 로 새 있다 — 라운드 1 이 지목한 구멍이 자리만 옮겼다 (rc=$V2RC)"

# ③ §0 쪽도 같은 ∀
v2mut nobackref0 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
old="- OQ1 [열림] — 인증 뷰의 캐시 전략 → 근거 RC3"
assert s.count(old)==1
s=s.replace(old,"- OQ1 [열림] — 인증 뷰의 캐시 전략"); p.write_text(s,encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q '역참조' <<<"$V2OUT"; } \\
  && ok "V2-③: §0 의 역참조만 지워도 red (양쪽 ∀)" || no "V2-③: §0 쪽 ∀ 가 없다 (rc=$V2RC)"
finish
"""
p.write_text(t[: -len(anchor)] + new, encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` **정확히 4건**, `✓` 3건. 셀별로 재라 — 합계보다 이것이 계약이다:

| 단언 | Step 1 | 왜 |
|---|---|---|
| `V2-①` 연결 삭제 → red | ✗ | 술어가 없어 green 이다 |
| `V2-①` 차단 메시지에 개수 없음 | **✓** | **공허하다** — `failures` 가 비어 있다 |
| `V2-①(양의 짝)` sentinel green | **✓** | **공허하다** — 전부 green 이다 |
| `V2-②` 없는 OQ → red | ✗ | 술어가 없다 |
| `V2-②(L3)` 해결된 결정 green | **✓** | **공허하다** — 전부 green 이다 |
| `V2-③` §3 역참조 삭제 → red | ✗ | 술어가 없다 |
| `V2-③` §0 역참조 삭제 → red | ✗ | 술어가 없다 |

**Step 1 의 ✓ 셋을 증거로 읽지 마라.** 술어가 하나도 없으므로 **모든 입력이 green** 이고, 「green
이어야 한다」를 요구하는 단언은 전부 자동으로 통과한다. 그 셋이 의미를 갖는 것은 Step 2 뒤에
**여전히** ✓ 일 때다 — 그때 비로소 「술어가 정직한 답과 의도된 한계를 red 로 만들지 않는다」를 말한다.
숫자가 다르면 멈추고 보고하라.

- [ ] **Step 2: 술어 셋을 구현한다**

Task 14 의 헬퍼 뒤에 붙인다:

```python
def research_link_missing(text: str) -> list[str]:
    """① 연결 ∀ — 조사 항목마다 줄 **끝**에 `[RC<n> → OQ<n>]` · `[→ OQ<n>]` · `[→ 없음]` 하나.

    ∀ 이고 개수 술어가 아니다. 순회할 항목이 0건이면 공허하게 통과한다 — `landscape_unkeyed` 의
    docstring 이 같은 판단을 이미 적었다: 「web-off brief는 §4에 순회할 항목이 없어 공허하게
    통과하는 것이 옳다 — 조사하지 않았으면 인용할 것도 없다」.
    """
    return [ln for ln in research_entries(text) if not LINK_RE.search(ln)]


def _declared_decisions(text: str) -> set:
    """payload §3 Open Questions ∪ §0 한눈에 의 결정 목록에 실재하는 `OQ<n>` 집합.

    §0 이 상위집합이고 §3 이 그 중 열린 것이다(설계 §H ②). **상태 토큰은 보지 않는다** —
    §0 은 해결된 결정도 `[해결 ⟨S<N>⟩]` 를 달고 남으므로, 「열려 있는가」를 보면 그 결정을
    해결하는 데 기여한 조사가 red 가 된다(설계 L3 · R11).
    """
    return set(OQ_RE.findall(_section_text(text, "3", "Open Questions"))) | \
        set(OQ_RE.findall(_section_text(text, "0", "한눈에")))


def research_link_targets_missing(text: str) -> list[str]:
    """② 연결 대상 실재 — 쓰인 `OQ<n>` 이 §3 또는 §0 의 결정 목록에 있는가.

    `[→ 없음]` 은 대상이 아니다. 연결이 0건이면 공허하게 통과한다(① 이 연결 부재를 따로 잡는다).
    """
    declared = _declared_decisions(text)
    fails = set()
    for ln in research_entries(text):
        m = LINK_RE.search(ln)
        if not m:
            continue        # ① 이 잡는다
        for oq in OQ_RE.findall(m.group(0)):
            if oq not in declared:
                fails.add(f"{oq} 가 payload §3·§0 의 결정 목록에 없다")
    return sorted(fails)


def research_backref_missing(text: str) -> list[str]:
    """③ 역참조 ∀ — 연결에 쓰인 `RC<n>` 이 그 `OQ<n>` 줄 **전부**에 되나타난다.

    **∃ 가 아니다**(설계 §H ④). ∃ 로 두면 §0 줄 하나로 만족돼 §3 의 `→ 근거 RC3` 을 지워도
    통과하고, 라운드 1 이 지목한 구멍이 자리만 옮겨 남는다. 방향을 뒤집어 「그 `OQ<n>` 줄이 근거
    id 를 포함하는가」를 §3·§0 **양쪽**에서 본다.

    웹 항목(`[→ OQ…]`)과 sentinel 은 id 가 없으므로 이 검사의 대상이 아니다 — 웹 출처는
    «출처키»↔audit §7(N2)가 이미 결속한다.
    """
    want: dict = {}
    for ln in research_entries(text):
        m = LINK_RE.search(ln)
        if not m or not m.group(1):
            continue
        for oq in OQ_RE.findall(m.group(0)):
            want.setdefault(oq, set()).add(m.group(1))
    if not want:
        return []
    fails = set()
    for num, title in (("3", "Open Questions"), ("0", "한눈에")):
        for ln in _entry_lines(_section_text(text, num, title)):
            for oq in set(OQ_RE.findall(ln)):
                for rc in want.get(oq, ()):
                    if rc not in ln:
                        fails.add(f"§{num} 의 {oq} 줄이 근거 {rc} 를 되가리키지 않는다")
    return sorted(fails)
```

Expected(Step 2 검증): `grep -c 'def research_link_missing\|def research_link_targets_missing\|def research_backref_missing\|def _declared_decisions' plugins/spec-distill/scripts/check_brief.py` → `4`, 그리고 `python3 -c "import ast,pathlib; ast.parse(pathlib.Path('plugins/spec-distill/scripts/check_brief.py').read_text(encoding='utf-8'))"` 가 조용히 끝난다.

- [ ] **Step 3: `gate()` 에 배선한다**

Task 14 가 만든 `if contract_v2(text):` 블록 안, `payload_rc_ids` advisory **앞**에:

```python
        if not sec4_absent and not sec5_absent:
            lm = research_link_missing(text)
            if lm:
                failures.append(
                    "조사 항목에 결정 연결 없음 (줄 끝에 `[RC<n> → OQ<n>]` · `[→ OQ<n>]` · "
                    f"`[→ 없음]` 중 하나): {lm[:3]}")
            tm = research_link_targets_missing(text)
            if tm:
                failures.append(f"결정 연결 대상 부재: {tm[:3]}")
            bm = research_backref_missing(text)
            if bm:
                failures.append(f"역참조 누락: {bm[:3]}")
```

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -3
```

Expected: `Fail: 0`.

- [ ] **Step 4: 기존 픽스처 전량이 red 가 되지 않는지 확인 (양방향 중 (a))**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
n=0; bad=0
for f in plugins/spec-distill/tests/fixtures/*.md; do
  case "$f" in *.audit.md) continue ;; esac
  grep -q '^contract: v2$' "$f" && continue
  grep -q '^## 4\. External Landscape' "$f" || continue
  n=$((n+1))
  out="$(PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/scripts/check_brief.py gate "$f" 2>/dev/null)"
  printf '%s' "$out" | grep -qE '결정 연결|역참조|연결 대상' && { bad=$((bad+1)); echo "REGRESSION: $f"; }
done
echo "§4 보유 · contract 없음 픽스처 $n 개 중 새 술어로 red 가 된 것 $bad 개"
```

Expected: `$n` **= 81**(Task 1 이 실측한 값이다 — `≈` 가 아니다), `$bad` **= 0**. 하나라도 있으면 옵트인 판독이 깨진 것이다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_check_brief.sh
git commit -F - <<'MSG'
feat(spec-distill): 게이트 술어 ①②③ — 연결 ∀ · 대상 실재 · 역참조 ∀

③ 이 ∀ 인 것이 요점이다. 원래 설계는 「OQ<n> 이 §3·§0 에 실재하는가」만 봤고 그것으로 §3 역참조가
닫힌다고 적었는데 **거짓이었다** — §3 의 `→ 근거 RC3` 을 지워도 통과한다. 방향을 뒤집어 「그 OQ 줄이
근거 id 를 포함하는가」를 §3·§0 양쪽에서 본다. ∃ 로 두면 §0 줄 하나로 만족돼 같은 구멍이 자리만
옮겨 남는다(라운드 2 가 그것을 잡았다).

② 는 상태 토큰을 **보지 않는다**. §0 이 해결된 결정도 남기므로 「열려 있는가」를 보면 그 결정을
해결하는 데 기여한 조사가 red 가 된다 — 성공을 red 로 만드는 술어는 목표의 반전이다. 의도된
한계이고 설계 L3 에 공시돼 있다.

`[→ 없음]` sentinel 을 연다 — 계약이 「빈 배열은 허용이고 거짓 연결보다 낫다」를 못 박으므로
sentinel 없는 ∀ 는 그 계약과 충돌하고 「필러 절」 압력을 만든다. 「없음」의 개수는 세지 않는다.

차단 메시지 문면에도 개수를 넣지 않는다 — 재서 막으면 사후 장치이고 재서 보이면 공시다.
그 구분을 테스트가 직접 잰다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```
---

### Task 16: 술어 ④ — 이름 정확 일치 derived + `closed` (AC10)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Modify: `plugins/spec-distill/tests/test_check_brief.sh`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (C43 표 뒤 — 산출자, 아래 Step 0)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (그 산출자의 락 셋)

**Interfaces:**
- Consumes: Task 14 의 `payload_rc_ids` · 기존 `LEDGER_ROW_RE`·`_strip_bullet` · **Task 15 가 같은
  락 파일에 이미 정의한 셸 헬퍼 `v2mut()`**(재정의하지 말고 그대로 호출한다 — 두 정의가 생기면
  뒤의 것이 앞의 것을 조용히 덮는다).
- Produces: `internal_research_dimension_failures(payload_text, audit_text)`.

**red 가 셋 필요하다** — 행 부재 · **이름 다름** · 상태 `open`. 라운드 1 이 실측했다: `- derived:unrelated-ui — open — ` 한 줄이 `coverage_ledger_failures` 와 `coverage_anchor_failures` **둘 다** 통과했다. 그래서 하한은 「행이 하나 있는가」가 아니라 **셋 전부**여야 한다.

**이름은 정확 일치다** — 접두 일치로 두면 무관한 차원으로 갈음된다. 이 사이클의 audit §1 에 이미 `derived:internal_research_apparatus` 가 살아 있고 그것은 「내부 조사 장치의 형태」라는 **다른** 차원이다.

**`closed` 요구가 보는 것은 「앵커 형태의 근거가 적혀 있는가」까지다(L9)** — `coverage_anchor_failures` 가 form-only 이고 `gate()` 가 넘기는 집합이 payload·audit §6 앵커 전량이므로 `⟨S1⟩` 하나로도 통과한다. 그 앵커가 이 차원을 닫는가는 사람과 리뷰의 몫이다. **이 술어는 그 이상을 주장하지 않는다.**

- [ ] **Step 0: 산출자를 먼저 배선한다 — `internal_research` 차원을 누가 원장에 넣는가**

이 Task 의 술어 ④는 「payload 가 레포 주장을 하나라도 실으면 audit §1 에 **정확히**
`derived:internal_research` 라는 이름의 행이 있고 상태가 `closed`」를 요구한다. 그런데 그 이름을
말하는 «지시» 가 리포 어디에도 없다 — 선점검에서 `plugins/spec-distill` 의 production 전체를 훑어
**0건**이었다(계획 안에서는 audit 템플릿·게이트 술어·픽스처에만 나온다).

그 결과가 **게이트가 조사를 한 것을 벌하는** 구조다. audit §1 은 `finishing.md` Step A 항목 4 가
`state.coverage` 를 직렬화한 것이고, **닫힌 행은 그 차원을 닫은 사용자 발화 `S<N>` 을 인용해야
한다**(그 항목이 명시한다). 그러니 이 행은 (1) 인터뷰 중 `coverage.derived[]` 에 admit 되고
(2) 사용자 발화로 닫혀야 존재할 수 있다. 종료 시점에 발견하면 이미 늦다 — 그때 닫으면 닫힘 규칙
(「그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다」)을 어긴다. 그리고 이름이 **정확 일치**라
coverage-mapper 의 자연스러운 제안으로는 맞지 않는다: 이 사이클의 audit §1 에 실제로
`derived:internal_research_apparatus` 가 살아 있고 그것은 **다른** 차원이다.

**술어를 만들기 전에 산출자를 배선한다.** C43 표 바로 뒤, 경로 (a) 의 산출을 말하는 그 자리다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/SKILL.md")
t = p.read_text(encoding="utf-8")
old = """매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지 명시하십시오 — 경로 (a) 로 찾을 수 있는 것은 묻기 전에
먼저 찾아 «지금 이해»에 싣습니다.
"""
new = """매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지 명시하십시오 — 경로 (a) 로 찾을 수 있는 것은 묻기 전에
먼저 찾아 «지금 이해»에 싣습니다.

**경로 (a) 가 `repo_claims[]` 를 처음 산출하면 그 자리에서 derived 차원 internal_research 를 원장에
admit 한다**(coverage-mapper 제안과 무관 — 조사 행위가 그 차원을 함의한다). 이름은 그 글자대로 쓴다:
게이트가 **정확 일치**로 재고 `internal_research_apparatus` 같은 유사 이름으로는 만족되지 않는다.
그 차원은 **레포 주장의 처분 S** 로 닫고 evidence 에 그 S 를 인용한다 — 종료 시점엔 늦다(닫힘 규칙).
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("ok")
PY
wc -l < plugins/spec-distill/skills/conducting-interview/SKILL.md
```

Expected: `ok` 다음 SKILL.md **448줄** — 443 에서 **정확히 +5**(빈 줄 1 + 산문 4). 천장은 Task 11 이
실측+8 로 조인 **451** 이므로 통과하고 여유가 3줄 남는다.

**449 를 넘으면 멈추고 보고하라.** 천장을 다시 올리는 것은 이 Task 의 범위가 아니다 — Task 11 이
그 값을 실측에 근거해 정했고, 래칫이 남긴 여유를 다 쓰는 것은 이 Task 가 결정할 일이 아니다.
산문을 이보다 늘려야 한다고 판단되면 그 판단을 보고하고 멈춘다.

락으로 못 박는다:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = "c43_block=\"$(awk '/^## C43 /{f=1;print;next} /^## /{f=0} f' \"$SKILL\")\""
assert t.count(anchor) == 1, t.count(anchor)
add = """
# AC10 산출자 — 게이트가 요구하는 `derived:internal_research` 를 «누가 원장에 넣는가». 이 지시가
# 없으면 게이트는 레포 주장을 실은 brief 를 막고, 저자는 종료 시점에 그것을 고칠 수 없다(닫힘
# 규칙이 사용자 발화를 요구한다) — 게이트가 조사를 한 것을 벌한다. 소비자는 Task 16 의 술어 ④다.
c43_flat="$(tr '\\n' ' ' <<<"$c43_block" | tr -s ' ')"
grep -qF 'derived 차원 internal_research 를 원장에' <<<"$c43_flat" \\
  && ok "AC10(산출자): 경로 (a) 가 internal_research 차원의 admit 을 지시한다" \\
  || no "AC10(산출자): admit 지시 부재 — 게이트가 산출자 없는 것을 막는다"
grep -qF '레포 주장의 처분 S' <<<"$c43_flat" \\
  && ok "AC10(산출자·닫힘): 그 차원을 닫는 발화를 지목한다" \\
  || no "AC10(산출자·닫힘): 닫는 S 를 지목하지 않는다 — 닫힌 행의 evidence 를 채울 근거가 없다"
grep -qF '정확 일치' <<<"$c43_flat" \\
  && ok "AC10(산출자·이름): 정확 일치를 못 박는다" \\
  || no "AC10(산출자·이름): 정확 일치 문구 부재 — 비슷한 이름으로 갈음된다"
"""
p.write_text(t.replace(anchor, anchor + add), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC10\(산출자|줄 수|Total'
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -1
```

Expected: `ok` 다음 `✓ AC10(산출자)` 셋 + 줄 수 단언 둘 ✓ + `Fail: 0`. stale 락도 `Fail: 0` — 새 문면에
production 금지 어휘(`provisional_on` · `직전 답에서` · `깊이 측정` 등)를 넣지 않았다.

- [ ] **Step 0.5: 세 단언이 서로 다른 것을 재는지 변이 셋으로 잰다**

각 변이는 **정확히 하나**를 ✗ 로 만들어야 한다 — 둘 이상이 함께 ✗ 가 되면 그 단언들이 같은 리터럴을
공유하는 것이다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
mut() {   # $1 = 찾을 문자열, $2 = 바꿀 문자열
  python3 -c "
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
old, new = sys.argv[2], sys.argv[3]
assert t.count(old) == 1, '앵커 %d건' % t.count(old)
p.write_text(t.replace(old, new), encoding='utf-8')" "$SK" "$1" "$2"
  bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '^  ✗ .*AC10\(산출자'
  git checkout HEAD -- "$SK"
}
echo "--- 변이 1 (admit 축)"
mut 'derived 차원 internal_research 를 원장에' 'derived 차원을 원장에'
echo "--- 변이 2 (닫힘 축)"
mut '레포 주장의 처분 S' '어떤 발화'
echo "--- 변이 3 (이름 축)"
mut '정확 일치' '접두 일치'
echo "--- 복원 후"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC10\(산출자|Total'
```

Expected: 변이 1 → `✗ AC10(산출자)` 하나만. 변이 2 → `✗ AC10(산출자·닫힘)` 하나만. 변이 3 →
`✗ AC10(산출자·이름)` 하나만. 복원 후 ✓ 셋 + `Fail: 0`.

한 변이가 둘 이상을 ✗ 로 만들면 공유하지 않는 문구로 갈라 다시 잰다. 아무것도 ✗ 로 만들지 않으면
그 축의 단언이 그 자리를 재지 않는 것이다. 복원은 `git checkout HEAD --` 다(`git checkout --` 는
index 로 되돌아가 변이가 남을 수 있다).

- [ ] **Step 1: red 셋과 양의 짝을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_check_brief.sh")
t = p.read_text(encoding="utf-8")
anchor = "\nfinish\n"
assert t.endswith(anchor)
new = """
# V2-④ — 이름 정확 일치 derived + closed. **red 가 셋** 필요하다: 행 부재 · 이름 다름 · open.
# 라운드 1 실측: `- derived:unrelated-ui — open — ` 한 줄이 기존 두 함수를 **둘 다** 통과했다.
v2mut d4a 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
old="- derived:internal_research — closed — 내부 조사 축 (@S1)\\n"
assert s.count(old)==1
a.write_text(s.replace(old,""),encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q 'derived:internal_research' <<<"$V2OUT"; } \\
  && ok "V2-④ red1: 행 부재 → red (이름을 댄다)" || no "V2-④ red1: 행 부재가 통과됐다 (rc=$V2RC)"

v2mut d4b 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
a.write_text(s.replace("derived:internal_research —","derived:internal_research_apparatus —",1),encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q 'derived:internal_research' <<<"$V2OUT"; } \\
  && ok "V2-④ red2: 이름이 다르면 red (접두 일치가 아니다 — _apparatus 로 갈음되지 않는다)" \\
  || no "V2-④ red2: 접두 일치로 갈음됐다 (rc=$V2RC) — 무관한 차원이 요구를 채운다"

v2mut d4c 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
a.write_text(s.replace("derived:internal_research — closed —","derived:internal_research — open —",1),encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q 'closed' <<<"$V2OUT"; } \\
  && ok "V2-④ red3: 상태가 open 이면 red" || no "V2-④ red3: open 행이 통과됐다 (rc=$V2RC)"

# 양의 짝 — RC<n> 0건이면 요구가 미발동이라 `derived: N/A` sentinel 로 통과한다.
v2mut d4d 'import sys,pathlib,re
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
s=re.sub(r"\\[RC\\d+ → ","[→ ",s); s=re.sub(r" ?→ 근거 RC\\d+","",s)
s=re.sub(r"^- 위험 — .*RC\\d+.*$\\n","",s,flags=re.M); p.write_text(s,encoding="utf-8")
a=pathlib.Path(sys.argv[2]); q=a.read_text(encoding="utf-8")
q=re.sub(r"^- 확인 RC\\d+ .*$\\n","",q,flags=re.M)
q=q.replace("- derived:internal_research — closed — 내부 조사 축 (@S1)","- derived: N/A")
a.write_text(q,encoding="utf-8")'
[[ "$V2RC" -eq 0 ]] \\
  && ok "V2-④(양의 짝): RC<n> 0건이면 derived: N/A sentinel 로 통과 (조건부 발동)" \\
  || no "V2-④: 0건인데 derived 행을 요구했다 (rc=$V2RC) — 기존 픽스처 전량이 red 가 된다"

# 차단 메시지에 개수가 없다 (⟨C5⟩)
v2mut d4e 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
a.write_text(s.replace("- derived:internal_research — closed — 내부 조사 축 (@S1)\\n",""),encoding="utf-8")'
printf '%s' "$V2OUT" | python3 -c 'import json,sys
d=json.load(sys.stdin)
msgs=[x for x in d["failures"] if "internal_research" in x]
import re
print("HASCOUNT" if any(re.search(r"[0-9]+건|[0-9]+개", m) for m in msgs) else "CLEAN")' | grep -q CLEAN \\
  && ok "V2-④: 차단 메시지에 개수가 없다" || no "V2-④: 차단 메시지에 개수가 들어갔다 (⟨C5⟩)"
finish
"""
p.write_text(t[: -len(anchor)] + new, encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` 3건(red 셋이 아직 통과한다).

- [ ] **Step 2: 술어 ④ 를 구현한다**

```python
def internal_research_dimension_failures(payload_text: str, audit_text: str) -> list[str]:
    """④ 이름 정확 일치 derived (조건부) — 레포 주장이 ≥1 이면 audit §1 에 **정확히**
    `derived:internal_research` 행이 있고 상태가 **`closed`** 여야 한다.

    **조건부다.** `landscape_keys_declared` 가 같은 관습을 쓴다: 「payload가 landscape를 실었다는
    사실을 조건으로 건다 — 키가 없으면 공집합 ⊆ 무엇이든으로 자동 만족되므로 kill switch 코드가
    필요 없다」. 여기서는 payload 가 레포 주장을 실었다는 사실이 조건이고, 0건이면 요구가
    발동하지 않으므로 `derived: N/A` sentinel 을 쓰는 기존 픽스처는 red 가 되지 않는다.
    조건을 산출물에 두는 대가는 설계 L1 에 적혀 있다.

    **이름은 정확 일치다.** 접두 일치로 두면 무관한 차원으로 갈음된다 — 실재하는 반례가 있다:
    `derived:internal_research_apparatus` 는 「내부 조사 장치의 형태」라는 **다른** 차원이다.

    **`closed` 요구가 보는 것은 여기까지다**: `coverage_anchor_failures` 가 그 행의 evidence 에서
    실재하는 `S<N>` 앵커를 요구하지만 그 함수는 form-only 라(자기 docstring 이 공시한다) 「그 S 가
    닫힘을 정당화하는가」는 보지 않는다. 즉 이 검사는 **「앵커 형태의 근거가 적혀 있는가」까지**이고
    그 앵커가 이 차원을 닫는가는 사람과 리뷰의 몫이다(설계 L9).

    **개수 술어가 아니다.** `payload_rc_ids` 의 비어 있음/아님만 **조건 분기**로 쓰고, 개수는
    차단 판정에도 메시지 문면에도 넣지 않는다.
    """
    if not payload_rc_ids(payload_text):
        return []
    for ln in _entry_lines(_section_text(audit_text, "1", "Coverage Ledger")):
        m = LEDGER_ROW_RE.match(_strip_bullet(ln).strip())
        if not m or m.group(1).strip() != DERIVED_INTERNAL_RESEARCH:
            continue
        status = m.group(2).strip()
        if status != "closed":
            return [f"{DERIVED_INTERNAL_RESEARCH} 행의 상태가 {status!r} != closed"]
        return []
    return [f"레포 주장이 있는데 audit §1 에 {DERIVED_INTERNAL_RESEARCH} 행이 없다 "
            "(이름 정확 일치 — 다른 derived 행으로는 만족되지 않는다)"]
```

`gate()` 의 `if contract_v2(text):` 블록 안, audit 절 존재 확인과 함께:

```python
        if audit_text and not any(
                m.startswith("1.") for m in find_missing_sections(audit_text, AUDIT_SECTIONS)):
            idf = internal_research_dimension_failures(text, audit_text)
            if idf:
                failures.append(f"내부 조사 차원: {idf}")
```

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -3
```

Expected: `Fail: 0`.

- [ ] **Step 3: 라운드 1 이 실측한 반례를 직접 재현한다**

`- derived:unrelated-ui — open — ` 한 줄이 두 기존 함수를 통과하는지, 그리고 새 술어가 그것을 잡는지.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location(
    "cb", "plugins/spec-distill/scripts/check_brief.py")
cb = importlib.util.module_from_spec(spec); sys.modules["cb"] = cb; spec.loader.exec_module(cb)
audit = pathlib.Path("plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.audit.md").read_text(encoding="utf-8")
payload = pathlib.Path("plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md").read_text(encoding="utf-8")
bad = audit.replace("- derived:internal_research — closed — 내부 조사 축 (@S1)",
                    "- derived:unrelated-ui — open — ")
print("coverage_ledger_failures:", cb.coverage_ledger_failures(bad))
print("coverage_anchor_failures:", cb.coverage_anchor_failures(bad, {"S1"}))
print("internal_research_dimension_failures:", cb.internal_research_dimension_failures(payload, bad))
PY
```

Expected: 앞 둘은 `[]`(라운드 1 의 실측 재현 — 그 한 줄이 둘 다 통과한다), 셋째는 **비어 있지 않다**. 이것이 새 술어가 메우는 구멍이다.

- [ ] **Step 4: 기존 픽스처 회귀 0 재확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bad=0
for f in plugins/spec-distill/tests/fixtures/*.md; do
  case "$f" in *.audit.md) continue ;; esac
  grep -q '^contract: v2$' "$f" && continue
  out="$(PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/scripts/check_brief.py gate "$f" 2>/dev/null)"
  printf '%s' "$out" | grep -q '내부 조사 차원' && { bad=$((bad+1)); echo "REGRESSION: $f"; }
done
echo "새 술어 ④ 로 red 가 된 기존 픽스처 $bad 개"
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2
```

Expected: `0 개` · `Fail: 0`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_check_brief.sh
git commit -F - <<'MSG'
feat(spec-distill): 게이트 술어 ④ — 이름 정확 일치 derived + closed

하한은 「행이 하나 있는가」가 아니다. 라운드 1 이 실측했다 — `- derived:unrelated-ui — open — `
한 줄이 `coverage_ledger_failures`(derived 는 행 수만 센다)와 `coverage_anchor_failures`(상태 토큰이
closed 가 아니면 continue)를 **둘 다** 통과했다. 그래서 셋 전부를 요구한다: 이름 · 닫힘 · 근거.

이름은 정확 일치다. 접두 일치면 무관한 차원으로 갈음되고, 실재하는 반례가 이 사이클 audit §1 에
있다 — `derived:internal_research_apparatus` 는 「내부 조사 장치의 형태」라는 다른 차원이다.

**과대 주장을 하지 않는다**: `closed` 요구가 보는 것은 「앵커 형태의 근거가 적혀 있는가」까지다.
같은 함수가 form-only 임을 자기 docstring 에 이미 공시했고, 그 앵커가 이 차원을 닫는가는 사람과
리뷰의 몫이다(설계 L9).

red 셋(행 부재 · 이름 다름 · open) + 양의 짝(0건이면 sentinel 통과) + 개수 부재 확인.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 17: 술어 ⑤ — 확인 줄 ∀ (AC12)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`
- Modify: `plugins/spec-distill/tests/test_check_brief.sh`
- Modify: `plugins/spec-distill/skills/conducting-interview/references/steelman.md` (§5 기록 의무 — 아래 Step 0)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (그 의무의 락 둘)

**Interfaces:**
- Consumes: Task 8 의 확인 줄 형식 · Task 14 의 `payload_rc_ids` · **Task 15 가 같은 락 파일에 이미
  정의한 셸 헬퍼 `v2mut()`** 과 Task 14 의 `FXV`(재정의하지 않는다).
- Produces: `research_confirm_missing(payload_text, audit_text)` — 두 파일을 잇는 마지막 교차 술어.
  기존 계열과 같은 모양이다: `«출처키»`↔audit §7(`landscape_keys_declared`) · `ST<N>`↔audit §3
  (bijection A) · `S<N>`↔§6(bijection C). **전부 id 로 맞물린다.**

**웹 주장은 대상이 아니다** — N2(`landscape_keys_declared`)가 audit §7 결속을 이미 본다.

**거처가 audit §5 인 이유** — `AUDIT_SECTIONS` 가 이미 요구하는 절이라 **무조건 존재**하고 새 절을 만들지 않는다(⟨C10⟩ · 압축 규약). 무조건 도는 검문소에는 무조건 존재하는 절이 필요하다.

- [ ] **Step 0: 산출자를 먼저 배선한다 — `steelman.md` 가 §5 의무를 말하게 한다**

술어 ⑤ 는 payload 의 **모든** `RC<n>` 마다 audit §5 줄을 요구한다. 그런데 `references/steelman.md`
는 자기 판정을 audit **§3** 의 `ST<N>` 블록에만 적으라고 말한다(`:51` · `:58` · `:60` · `:71` ·
`:74` 다섯 자리 전부 §3 이다). §5 의무는 `SKILL.md` 의 V1 문장 하나에만 있고, R3 에서 **실제로
읽히는 더 구체적인 파일**이 침묵한다.

그 결과가 **소비자만 있고 산출자가 없는** 게이트다 — steelman 경로의 리포 주장이 payload §5 항목에
`[RC3 → OQ1]` 로 실리면 게이트는 `확인 RC3` 을 요구하지만, R3 독자에게 그것을 쓰라고 말하는 지시는
없다. 술어를 만들기 **전에** 산출자를 배선한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/skills/conducting-interview/references/steelman.md")
t = p.read_text(encoding="utf-8")
old = "- 결과는 audit §3 `#### ST<N>` 블록의 「게이트-전 확인」 소절에 주장별 한 줄로 남는다."
add = (
    "\n- **리포 주장(`repo_claims[]`)에는 audit §5 줄도 함께 남긴다** — "
    "`- 확인 RC<n> — {확인|반증|미확인} — <경로>#<앵커> — <사유>`.\n"
    "  확인 «행위» 는 한 번이고(이 Step 2 가 V1 의 특수 경우다) 기록이 두 자리다: §3 은 이\n"
    "  steelman 블록의 문맥을, §5 는 인터뷰 전체의 무조건 원장을 갖는다. §5 를 빼면 구조 게이트의\n"
    "  확인-줄 ∀ 술어가 그 `RC<n>` 을 이름으로 대며 막는다 — 그 술어는 주장이 steelman 에서\n"
    "  왔는지 보지 않는다."
)
assert t.count(old) == 1
p.write_text(t.replace(old, old + add), encoding="utf-8")
print("ok")
PY
```

그 의무를 락으로 못 박는다. 락은 이미 `STEELMAN="$FIN_DIR/steelman.md"` 를 `:527` 에서 세우고
`:528` 에서 실재를 잰다 — 그 변수를 쓴다. **아래 앵커가 그 파일에 정확히 한 번 나오는지 먼저
확인하고**, 이름이 다르면 실제 이름을 찾아 쓰고 그 사실을 보고한다(추측한 이름으로 앵커를 세우지
않는다).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_conducting_interview_stage.sh")
t = p.read_text(encoding="utf-8")
anchor = '[[ -f "$STEELMAN" ]] && ok "코퍼스: references/steelman.md 실재 (AC4)" || no "코퍼스: references/steelman.md 부재 (AC4)"'
assert t.count(anchor) == 1, t.count(anchor)
add = (
    "\n# AC12 산출자 — steelman 경로의 리포 주장이 audit §5 확인 줄을 «낸다». 소비자(구조 게이트의\n"
    "# 확인-줄 ∀ 술어)는 주장의 출처를 보지 않으므로, 이 파일이 §5 를 말하지 않으면 게이트가 아무\n"
    "# 지시도 산출하지 않는 것을 막는다. 술어와 이 문면은 같은 릴리스에서 함께 서야 한다.\n"
    "#\n"
    "# 축을 셋으로 가른다. `확인 RC` 하나로 재면 «어느 절에 쓰는가»를 못 잰다 — 「§5」를 「§3」으로\n"
    "# 바꿔도 그 리터럴은 남아 통과한다. 절 · 형식 · 이중확인-방지를 각각 잰다.\n"
    "grep -qF 'audit §5 줄도 함께 남긴다' \"$STEELMAN\" \\\n"
    "  && ok \"AC12(산출자·절): steelman.md 가 기록 절로 audit §5 를 지목한다\" \\\n"
    "  || no \"AC12(산출자·절): §5 지목이 없다 — 게이트가 산출자 없는 것을 막는다\"\n"
    "grep -qF '확인 RC<n> — {확인|반증|미확인}' \"$STEELMAN\" \\\n"
    "  && ok \"AC12(산출자·형식): 확인 줄 형식이 판정 어휘 셋과 함께 있다\" \\\n"
    "  || no \"AC12(산출자·형식): 확인 줄 형식이 없거나 판정 어휘 셋이 빠졌다\"\n"
    "grep -qF '확인 «행위» 는 한 번이고' \"$STEELMAN\" \\\n"
    "  && ok \"AC12(산출자·1회): 확인 행위 1회 · 기록 두 자리가 명시됐다\" \\\n"
    "  || no \"AC12(산출자·1회): 행위 1회 / 기록 2자리 구분이 없다 — Step 2 를 두 번 돌게 읽힌다\""
)
p.write_text(t.replace(anchor, anchor + add), encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC12\(산출자|Total'
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -1
bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -1
```

Expected: `ok` 둘 다음 `✓ AC12(산출자·절)` · `✓ AC12(산출자·형식)` · `✓ AC12(산출자·1회)` 셋 +
`Fail: 0`. 포인터 락과 stale 락도 `Fail: 0` — `steelman.md` 는 `references/` 아래라 포인터 락의
대상이고, 새 문면에 경로도 루트 토큰도 넣지 않았으므로 변화가 없어야 한다.

- [ ] **Step 0.5: 세 단언이 서로 다른 것을 재는지 변이 셋으로 잰다**

부재 락이 아니라 **존재** 락이므로 통과가 정답이다 — 모양으로는 이빨을 판별할 수 없다. 그리고
세 단언이 같은 것을 재면 축을 셋으로 가른 것이 장식이다. **각 변이는 정확히 하나를 ✗ 로 만들어야
한다** — 둘 이상이 함께 ✗ 가 되면 그 변이가 축을 분리하지 못한 것이다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
ST=plugins/spec-distill/skills/conducting-interview/references/steelman.md
mut() {   # $1 = 찾을 문자열, $2 = 바꿀 문자열
  python3 -c "
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding='utf-8')
old, new = sys.argv[2], sys.argv[3]
assert t.count(old) == 1, '앵커 %d건' % t.count(old)
p.write_text(t.replace(old, new), encoding='utf-8')" "$ST" "$1" "$2"
  bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E '^  ✗ .*AC12\(산출자'
  git checkout HEAD -- "$ST"
}
echo "--- 변이 1 (절 축): §5 → §3"
mut 'audit §5 줄도 함께 남긴다' 'audit §3 줄도 함께 남긴다'
echo "--- 변이 2 (형식 축): 판정 어휘 셋을 지운다"
mut '확인 RC<n> — {확인|반증|미확인}' '확인 RC<n>'
echo "--- 변이 3 (이중확인 축): 행위 1회 문구를 지운다"
mut '확인 «행위» 는 한 번이고' '확인은'
echo "--- 복원 후"
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC12\(산출자|Total'
```

Expected: 변이 1 → `✗ AC12(산출자·절)` **하나만**. 변이 2 → `✗ AC12(산출자·형식)` 하나만.
변이 3 → `✗ AC12(산출자·1회)` 하나만. 복원 후 ✓ 셋 + `Fail: 0`.

한 변이가 **둘 이상**을 ✗ 로 만들면 그 두 단언이 같은 리터럴을 공유하는 것이므로, 공유하지 않는
문구로 갈라 다시 잰다. 한 변이가 **아무것도** ✗ 로 만들지 않으면 그 축의 단언이 그 자리를 재지
않는 것이므로, 그 단언의 `grep` 대상을 변이가 실제로 건드린 문구로 바꾼다. `git checkout HEAD --`
로 복원한다(`git checkout --` 는 index 로 되돌아가 변이가 남을 수 있다).

- [ ] **Step 1: red/green 짝을 먼저 쓴다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/tests/test_check_brief.sh")
t = p.read_text(encoding="utf-8")
anchor = "\nfinish\n"
assert t.endswith(anchor)
new = """
# V2-⑤ — 확인 줄 ∀. payload 의 모든 RC<n> 마다 audit §5 에 `확인 RC<n> — {확인|반증|미확인} — …`.
v2mut c5a 'import sys,pathlib,re
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
s=re.sub(r"^- 확인 RC3 .*$\\n","",s,flags=re.M); a.write_text(s,encoding="utf-8")'
{ [[ "$V2RC" -ne 0 ]] && grep -q 'RC3' <<<"$V2OUT"; } \\
  && ok "V2-⑤ red: 확인 줄을 지우면 red (그 id 를 이름으로 댄다)" || no "V2-⑤: 확인 줄 부재가 통과됐다 (rc=$V2RC)"

# 판정 어휘 밖의 줄은 확인 줄이 아니다 — 모양만 비슷한 줄로 만족되지 않는다.
v2mut c5b 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
a.write_text(s.replace("- 확인 RC3 — 확인 —","- 확인 RC3 — 아마도 —",1),encoding="utf-8")'
[[ "$V2RC" -ne 0 ]] \\
  && ok "V2-⑤: 판정 어휘 밖({확인|반증|미확인})이면 red" || no "V2-⑤: 어휘 밖 판정이 통과됐다 (rc=$V2RC)"

# 사유가 빈 줄은 확인 줄이 아니다.
v2mut c5c 'import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding="utf-8")
i=s.index("- 확인 RC3 "); j=s.index("\\n",i)
a.write_text(s[:i]+"- 확인 RC3 — 확인 — "+s[j:],encoding="utf-8")'
[[ "$V2RC" -ne 0 ]] \\
  && ok "V2-⑤: 사유가 빈 확인 줄은 red (형태만 갖춘 줄로 만족되지 않는다)" || no "V2-⑤: 빈 사유가 통과됐다 (rc=$V2RC)"

# 양의 짝 — 반증·미확인 판정도 확인 줄로 인정된다(라벨은 보이고 조용히 흡수되지 않는다).
for verdict in 반증 미확인; do
  v2mut "c5_$verdict" "import sys,pathlib
a=pathlib.Path(sys.argv[2]); s=a.read_text(encoding='utf-8')
a.write_text(s.replace('- 확인 RC3 — 확인 —','- 확인 RC3 — $verdict —',1),encoding='utf-8')"
  [[ "$V2RC" -eq 0 ]] \\
    && ok "V2-⑤(양의 짝): 판정 «${verdict}» 도 확인 줄로 인정된다" \\
    || no "V2-⑤: «${verdict}» 이 red 다 — 미확인을 조용히 흡수하라는 압력이 된다 (rc=$V2RC)"
done

# 웹 주장은 대상이 아니다 — 확인 줄을 요구받지 않는다(N2 가 audit §7 결속을 이미 본다).
v2mut c5web 'import sys,pathlib
p=pathlib.Path(sys.argv[1]); s=p.read_text(encoding="utf-8")
assert "[→ OQ1]" in s; p.write_text(s,encoding="utf-8")'
[[ "$V2RC" -eq 0 ]] \\
  && ok "V2-⑤: 웹 항목(`[→ OQ<n>]`)은 확인 줄을 요구받지 않는다" || no "V2-⑤: 웹 항목에 확인 줄을 요구했다 (rc=$V2RC)"
finish
"""
p.write_text(t[: -len(anchor)] + new, encoding="utf-8")
print("ok")
PY
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -cE '^  ✗ '
```

Expected: `✗` 3건.

- [ ] **Step 2: 술어 ⑤ 를 구현한다**

```python
def research_confirm_missing(payload_text: str, audit_text: str) -> list[str]:
    """⑤ 확인 줄 ∀ — payload 의 모든 `RC<n>` 마다 audit §5 에
    `확인 RC<n> — {확인|반증|미확인} — <사유>` 줄이 있는가 (설계 §D · AC12).

    거처가 audit `## 5. 프로세스 로그` 인 것은 `AUDIT_SECTIONS` 가 이미 요구하는 절이라 **무조건
    존재**하기 때문이다 — 무조건 도는 검문소에는 무조건 존재하는 절이 필요하고, 새 절을 만들지
    않는다(⟨C10⟩ · 압축 규약). 현행 steelman 의 「게이트-전 확인」은 audit §3 의 `ST<N>` 블록 안이라
    steelman 조건부다.

    두 파일을 잇는 것은 `RC<n>` 이고, 이것은 이 게이트의 기존 교차 술어 계열과 같은 모양이다 —
    `«출처키»`↔audit §7(`landscape_keys_declared`) · `ST<N>`↔audit §3(bijection A) ·
    `S<N>`↔§6(bijection C). 전부 id 로 맞물린다.

    **웹 주장은 이 검사의 대상이 아니다** — N2 가 audit §7 결속을 이미 본다. `RC<n>` 이 0건이면
    공허하게 통과한다(∀).

    판정 어휘는 셋이고 사유는 비어 있을 수 없다(`CONFIRM_ROW_RE`). `미확인` 이 어휘에 **드는**
    것이 계약이다 — 확정도 반증도 못 한 것을 라벨로 보이게 하고 조용히 흡수하지 않는다.
    """
    have = set()
    for ln in _entry_lines(_section_text(audit_text, "5", "프로세스 로그")):
        m = CONFIRM_ROW_RE.match(_strip_bullet(ln).strip())
        if m:
            have.add(m.group(1))
    return [f"{rc}: audit §5 에 `확인 {rc} — {{확인|반증|미확인}} — <사유>` 줄이 없다"
            for rc in payload_rc_ids(payload_text) if rc not in have]
```

`gate()` 의 `if contract_v2(text):` 블록 안:

```python
        if audit_text and not any(
                m.startswith("5.") for m in find_missing_sections(audit_text, AUDIT_SECTIONS)):
            cm = research_confirm_missing(text, audit_text)
            if cm:
                failures.append(f"확인 줄 누락: {cm[:3]}")
```

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -3
```

Expected: `Fail: 0`.

**Task 14·15·16·17 이 함께 만든 `gate()` 블록의 최종 모양** — 조각을 스스로 조립하지 않도록 전문을 둔다. `coverage anchors` 블록 뒤, `ok = not failures` 앞에 이것 하나가 있어야 한다:

```python
    # --- 조사 주장의 결정 연결 (설계 §E). 다섯 술어 전부 `contract: v2` 옵트인 뒤에 있다.
    #     옵트인이 없으면 advisory 한 줄만 나가고 술어는 하나도 돌지 않는다 — 그것이 기존
    #     코퍼스를 한 글자도 고치지 않는 장치다(§H ⑥).
    if contract_v2(text):
        if not sec4_absent and not sec5_absent:
            lm = research_link_missing(text)
            if lm:
                failures.append(
                    "조사 항목에 결정 연결 없음 (줄 끝에 `[RC<n> → OQ<n>]` · `[→ OQ<n>]` · "
                    f"`[→ 없음]` 중 하나): {lm[:3]}")
            tm = research_link_targets_missing(text)
            if tm:
                failures.append(f"결정 연결 대상 부재: {tm[:3]}")
            bm = research_backref_missing(text)
            if bm:
                failures.append(f"역참조 누락: {bm[:3]}")
        if audit_text:
            amiss2 = find_missing_sections(audit_text, AUDIT_SECTIONS)
            if not any(m.startswith("1.") for m in amiss2):
                idf = internal_research_dimension_failures(text, audit_text)
                if idf:
                    failures.append(f"내부 조사 차원: {idf}")
            if not any(m.startswith("5.") for m in amiss2):
                cm = research_confirm_missing(text, audit_text)
                if cm:
                    failures.append(f"확인 줄 누락: {cm[:3]}")
        if not payload_rc_ids(text):
            advisories.append(INTERNAL_RESEARCH_ZERO_ADVISORY)
    else:
        advisories.append(CONTRACT_V1_ADVISORY)
```

**세 가드의 이유** — `sec4_absent`/`sec5_absent` 는 절이 없을 때 그 절을 코퍼스로 쓰는 술어가 「항목 0건」과 「절 부재」를 구별하지 못하는 것을 막는다(절 부재는 `missing payload sections` 가 이미 red 를 낸다). audit 절 부재 가드도 같은 이유이고, `find_missing_sections` 를 한 번만 불러 두 판정이 같은 값을 쓴다.

- [ ] **Step 3: 다섯 술어가 전부 배선됐는지 코드에서 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
python3 - <<'PY'
import ast, pathlib
src = pathlib.Path("plugins/spec-distill/scripts/check_brief.py").read_text(encoding="utf-8")
tree = ast.parse(src)
gate = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "gate")
called = {n.func.id for n in ast.walk(gate)
          if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
want = {"contract_v2", "research_link_missing", "research_link_targets_missing",
        "research_backref_missing", "internal_research_dimension_failures",
        "research_confirm_missing", "payload_rc_ids"}
print("배선됨:", sorted(want & called))
print("누락:", sorted(want - called) or "없음")
assert not (want - called), "gate() 가 부르지 않는 술어가 있다 — 정의만 있고 발동하지 않는다"
PY
```

Expected: `누락: 없음`. 정의만 있고 `gate()` 가 부르지 않는 술어는 이빨이 0이다.

- [ ] **Step 4: 다섯이 전부 발동하는 red 하나를 만들어 확인 (양방향 중 (b))**

옵트인이 「이빨 0」과 구별되는지 — `contract: v2` 를 **넣은** 픽스처에서 다섯이 전부 발동해야 한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FXV=plugins/spec-distill/tests/fixtures/interview-brief-v2-valid
cp "$FXV.md" "$T/all.md"; cp "$FXV.audit.md" "$T/all.audit.md"
sed -i.bak 's|^audit_file:.*|audit_file: all.audit.md|' "$T/all.md"; rm -f "$T/all.md.bak"
python3 - "$T/all.md" "$T/all.audit.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding="utf-8")
s = s.replace(" [→ OQ1]", "", 1)                       # ① 연결 부재
s = s.replace("[→ 없음]", "[→ OQ9]", 1)                 # ② 없는 대상
s = s.replace(" → 근거 RC3", "", 1)                      # ③ 역참조 삭제(§0 쪽)
p.write_text(s, encoding="utf-8")
a = pathlib.Path(sys.argv[2]); q = a.read_text(encoding="utf-8")
q = q.replace("derived:internal_research — closed —", "derived:internal_research — open —", 1)  # ④
q = re.sub(r"^- 확인 RC3 .*$\n", "", q, flags=re.M)      # ⑤
a.write_text(q, encoding="utf-8")
PY
PYTHONDONTWRITEBYTECODE=1 python3 plugins/spec-distill/scripts/check_brief.py gate "$T/all.md" \
  | python3 -c 'import json,sys; [print("-", f) for f in json.load(sys.stdin)["failures"]]'
```

Expected: **다섯 종류의 실패가 전부 나온다** — `조사 항목에 결정 연결 없음` · `결정 연결 대상 부재` · `역참조 누락` · `내부 조사 차원` · `확인 줄 누락`. 하나라도 빠지면 그 술어가 발동하지 않는 조건이 있다.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_check_brief.sh
git commit -F - <<'MSG'
feat(spec-distill): 게이트 술어 ⑤ — 확인 줄 ∀

두 파일을 잇는 마지막 교차 술어다. `RC<n>` 이 그 연결이고, 이것은 이 게이트의 기존 계열과 같은
모양이다 — «출처키»↔audit §7 · ST<N>↔audit §3 · S<N>↔§6. 전부 id 로 맞물린다.

거처가 audit §5 인 것은 `AUDIT_SECTIONS` 가 이미 요구하는 절이라 무조건 존재하기 때문이다 —
무조건 도는 검문소에는 무조건 존재하는 절이 필요하고, 새 절을 만들지 않는다. steelman 의
「게이트-전 확인」은 audit §3 의 ST 블록 안이라 steelman 조건부다.

`미확인` 이 판정 어휘에 **드는** 것이 계약이다 — 확정도 반증도 못 한 것을 라벨로 보이게 하고
조용히 흡수하지 않는다. 그 양의 짝을 테스트가 직접 잰다.

옵트인이 「이빨 0」과 구별되는지 양방향으로 확인했다: contract 없는 픽스처 전량이 무변경으로
통과하고, contract: v2 를 넣은 픽스처에서는 다섯이 전부 발동한다. `ast` 로 gate() 의 호출
그래프를 훑어 정의만 있고 부르지 않는 술어가 없음도 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 18: 새 락 `tests/test_research_claims_contract.sh` — 여섯 축 (AC16 + 이월 해소)

**Files:**
- Create: `plugins/spec-distill/tests/test_research_claims_contract.sh`

**Interfaces:**
- Consumes: Task 2·3·4·5·6 의 산출 전량
- Produces: `# guards:` 선언과 `--emit-scanned` — 커버리지 대조의 대상 목록.

**여섯 축** (설계 AC16 의 다섯 + 이월 항목 하나):

| 축 | 무엇 | 왜 |
|---|---|---|
| **A** | 산문 body-unique 문구 — `경로가 아니라 **계약 파일의 내용**을 싣는다` 가 SKILL.md 의 그 절 **산문(펜스 밖)** 에 | 펜스의 `echo` 가 문구를 대신 만족시키지 못한다 |
| **B** | 양의 짝 — 슬롯 개수: `SKILL.md` 2 + `references/steelman.md` 1 | 부재 락은 대상을 통째로 지워도 통과한다 |
| **C** | 펜스가 마커 사이에서 `cat` 하고, 실패 분기가 「dispatch 하지 않는다」를 말하며 rc 1 로 끝난다 | 선례 `test_dispatch_profile_inline.sh` 축 C |
| **X** | 차가운 셸에서 그 펜스를 실행 — 실제 루트면 stdout == 계약 내용(rc 0), 계약 없는 루트면 rc 1 + 빈 stdout | 문구가 있다는 것과 그 문구가 **돌아간다**는 것은 다른 사실이다 |
| **D** | 정합 — 정본과 `steelman-builder.md` 사본의 필드 이름 집합이 **집합 등호** | ⊇ 와 「사본에 정본에 없는 필드 없음」은 같은 명제라 사본이 `decides`·`id` 를 빠뜨려도 green 이다 |
| **E** | `fail-closed` **값**의 회귀 감지 (이월 항목 해소) | 처분 락은 `fail-(open\|closed)` **어휘**만 보고 값을 단언하지 않는다 — 그 파일이 스스로 「값이 저자 손에 있는 한 축 B 급 이빨은 이 축에서 나오지 않는다」로 공시한다 |

- [ ] **Step 1: 락 파일을 쓴다 (축 A·B·C·D·E)**

`plugins/spec-distill/tests/test_research_claims_contract.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/references/research-claims.md plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/skills/conducting-interview/references/steelman.md plugins/spec-distill/agents/steelman-builder.md
#
# 조사 주장 계약이 **경로가 아니라 내용으로** 세 dispatch 에 배달되는가, 그리고 정본과 사본이
# 갈라지지 않는가. 설치본에서 계약 파일은 플러그인 캐시(사용자 cwd 밖)에 있어 subagent 의 Read 가
# 권한 거부되고, 그러면 agent 는 계약 없이 판정하면서 orchestrator 는 그것을 모른다.
# 구조는 형제 `test_dispatch_profile_inline.sh` 를 상속한다(같은 문제를 이미 네 축으로 잰다).
#
#   A  SKILL.md `## 조사 주장 계약` 절 산문(펜스 밖)에 body-unique 문구
#   B  양의 짝 — 슬롯 `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 가 SKILL.md 2 · steelman.md 1
#   C  `claims-contract` 마커 사이 펜스가 그 절 안에 있고 `cat "$CLAIMS"` 를 부르며 실패 분기가
#      「dispatch 하지 않는다」를 말하고 rc 1 로 끝난다
#   X  그 펜스를 차가운 셸에서 실행 — 실제 루트면 stdout 이 계약 내용(rc 0), 계약 없는 루트면 rc 1 + 빈 stdout
#   D  정합 — 정본의 필드 이름 집합 == steelman-builder 사본의 것 (집합 등호)
#   E  `fail-closed` 값의 회귀 감지 — 처분 락은 어휘만 보고 값을 단언하지 않는다
# 실제 agent 는 부르지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SKILL="$SD/skills/conducting-interview/SKILL.md"
STEEL="$SD/skills/conducting-interview/references/steelman.md"
CANON="$SD/references/research-claims.md"
COPY="$SD/agents/steelman-builder.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/research-claims.md"
  echo "plugins/spec-distill/skills/conducting-interview/SKILL.md"
  echo "plugins/spec-distill/skills/conducting-interview/references/steelman.md"
  echo "plugins/spec-distill/agents/steelman-builder.md"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-claims-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 가 유효한 디렉토리가 아니다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

PHRASE='경로가 아니라 **계약 파일의 내용**을 싣는다'
SLOT='<claims_contract>${CLAIMS_CONTRACT}</claims_contract>'
SLOT2='<open_decisions>${OPEN_DECISIONS}</open_decisions>'

section() {   # section <파일> <제목 정규식> → 그 `## ` 절 본문(다음 `## ` 직전까지, 펜스 인식)
  SEC="$2" awk '
    !on && $0 ~ ("^## " ENVIRON["SEC"]) {on=1; next}
    on && /^```/ {fence=!fence}
    on && !fence && /^## / {exit}
    on
  ' "$1"
}
prose_of() { awk '/^```/ {f=!f; next} !f' <<<"$1"; }
cut_marked() {
  awk '/<!-- claims-contract:begin -->/ {g=1; next}
       /<!-- claims-contract:end -->/ {g=0}
       g && /^```bash$/ {b=1; next}
       g && b && /^```$/ {b=0; next}
       g && b' "$1"
}
fail_branch() {
  awk '!inb && /^if \[ "\$claims_rc" -ne 0 \]/ {inb=1} inb {print} inb && /^fi$/ {exit}' "$1"
}
# YAML 키 이름 집합 — 펜스 안 `키:` 줄에서. 리스트 접두 `- ` 를 허용한다.
keys_of() {   # keys_of <파일> <블록 시작 정규식> <블록 끝 정규식>
  awk -v s="$2" -v e="$3" '$0 ~ s {f=1; next} f && $0 ~ e {f=0} f' "$1" \
    | sed -nE 's/^[[:space:]]*-?[[:space:]]*([a-z_]+):.*/\1/p' | sort -u
}

SEC="$(section "$SKILL" '조사 주장 계약')"
lines_sec="$(printf '%s\n' "$SEC" | grep -c . || true)"
if [ "${lines_sec:-0}" -ge 8 ]; then
  ok "절을 잘랐다 (${lines_sec}줄 — 아래 절 단언이 공허하지 않다)"
else
  no "\`## 조사 주장 계약\` 절을 못 잘랐다 (${lines_sec:-0}줄) — 아래 단언이 공허하다"
fi

# A — 산문에만 산다.
assert_contains "$(prose_of "$SEC")" "$PHRASE" \
  "A: 절 산문이 \`\${CLAIMS_CONTRACT}\` 에 경로가 아니라 계약 파일의 내용을 싣는다고 말한다 (body-unique)"

# B — 양의 짝: 슬롯 개수. SKILL.md 2(coverage-mapper · blind-spot-prober) + steelman.md 1.
n_sk="$(grep -oF "$SLOT" "$SKILL" | wc -l | tr -d ' ')"
n_st="$(grep -oF "$SLOT" "$STEEL" | wc -l | tr -d ' ')"
assert_eq "$n_sk" "2" "B: SKILL.md 의 \`claims_contract\` 슬롯이 2개 (coverage-mapper · blind-spot-prober)"
assert_eq "$n_st" "1" "B: steelman.md 의 \`claims_contract\` 슬롯이 1개"
m_sk="$(grep -oF "$SLOT2" "$SKILL" | wc -l | tr -d ' ')"
m_st="$(grep -oF "$SLOT2" "$STEEL" | wc -l | tr -d ' ')"
assert_eq "$m_sk" "2" "B: SKILL.md 의 \`open_decisions\` 슬롯이 2개 (계약만 있고 결정 목록이 없으면 decides 를 채울 수 없다)"
assert_eq "$m_st" "1" "B: steelman.md 의 \`open_decisions\` 슬롯이 1개"

# C — 내용을 얻는 펜스.
FENCE="$SCRATCH/fence.sh"; cut_marked "$SKILL" > "$FENCE"
n_fence="$(grep -c . "$FENCE" || true)"
if [ "${n_fence:-0}" -ge 5 ] && bash -n "$FENCE" 2>/dev/null; then
  ok "C: claims-contract 펜스 ${n_fence}줄 · bash -n 통과"
else
  no "C: 펜스가 ${n_fence:-0}줄이거나 문법이 깨졌다 — 마커가 없거나 추출이 깨졌다"
fi
grep -qF '<!-- claims-contract:begin -->' <<<"$SEC" \
  && ok "C: 그 펜스가 \`## 조사 주장 계약\` 절 안에 있다" \
  || no "C: 펜스가 그 절 밖이거나 없다"
grep -v '^[[:space:]]*#' "$FENCE" | grep -qF 'cat "$CLAIMS"' \
  && ok "C: 펜스가 실행 줄에서 \`cat \"\$CLAIMS\"\` 로 내용을 얻는다 (Read 가 아니다)" \
  || no "C: 펜스에 \`cat \"\$CLAIMS\"\` 실행 줄이 없다"
FB="$(fail_branch "$FENCE")"
{ grep -qF 'dispatch 하지 않는다' <<<"$FB" && grep -qE '^[[:space:]]*exit 1$' <<<"$FB"; } \
  && ok "C: 실패 분기가 dispatch 하지 않는다고 말하고 rc 1 로 끝난다" \
  || no "C: 실패 분기(\`if [ \"\$claims_rc\" -ne 0 ]\`)가 없거나 dispatch 금지 · rc 1 이 빠졌다"

# D — 정합: 정본과 사본의 필드 이름 집합이 **집합 등호**.
#     ⊇ 하나만 요구하면 사본이 `decides`·`id` 를 빠뜨려도 green 이고, 그 방향이 바로 이 축의
#     근거로 인용한 「한쪽만 고치는」 결함이다.
#     정규식을 한 문자열에 콜론으로 패킹하지 않는다 — 정규식 자체가 `:` 를 담아 구분자와
#     충돌하고, 그 충돌은 조용하지 않지만 **엉뚱하게** 터진다: 실측에서 `s_re` 가 `^evidence`
#     로 잘리고 `e_re` 가 `$:^repo_claims:$` 가 되어 awk 가 「정규식 구문 오류」로 죽었다.
#     블록마다 명시 호출한다.
cmp_block() {   # cmp_block <라벨> <시작 정규식> <끝 정규식>
  local blk="$1" s_re="$2" e_re="$3" k_canon k_copy
  k_canon="$(keys_of "$CANON" "$s_re" "$e_re")"
  k_copy="$(keys_of "$COPY" "$s_re" "$e_re")"
  if [ -z "$k_canon" ] || [ -z "$k_copy" ]; then
    no "D($blk) 양성대조: 키 집합 도출이 비었다 (정본='$k_canon' 사본='$k_copy') — 아래 등호가 공허하다"
  else
    ok "D($blk) 양성대조: 정본 $(printf '%s\n' "$k_canon" | grep -c .)키 · 사본 $(printf '%s\n' "$k_copy" | grep -c .)키 도출"
  fi
  assert_eq "$k_copy" "$k_canon" "D($blk): 정본과 사본의 필드 이름 집합이 같다 (집합 등호 — ⊇ 로는 사본의 누락을 못 잡는다)"
}
# 시작·끝 정규식에 `$` 앵커를 쓰지 않는다 — 정본의 `evidence:` 줄에는 정렬 공백과 주석이 붙어
# 있어 `^evidence:$` 가 매치하지 않는다(실측: 그 앵커로는 정본 쪽 도출이 통째로 비었다).
# `^evidence:` · `^repo_claims:` 는 두 파일에서 각각 정확히 한 줄만 매치하고(실측), 여는 펜스는
# ```yaml 이라 `^```$` 는 닫는 펜스만 잡는다.
cmp_block evidence    '^evidence:'    '^repo_claims:'
cmp_block repo_claims '^repo_claims:' '^```$'
# 신설 필드 둘이 실제로 그 집합에 있는지 — 등호만 요구하면 둘 다 빠져도 green 이다.
for f in decides id; do
  grep -qE "^[[:space:]]*-?[[:space:]]*${f}:" "$CANON" \
    && ok "D: 정본에 신설 필드 \`$f\`" || no "D: 정본에 신설 필드 \`$f\` 부재 (등호가 둘 다 빠진 채로 성립할 수 있다)"
done

# E — `fail-closed` 값의 회귀 감지. 처분 락은 `fail-(open|closed)` 어휘만 보고 값을 단언하지
#     않는다(그 파일이 스스로 공시한다). 세 dispatch 자리의 값이 `closed` 임을 여기서 못 박는다.
#     대상은 «계약 슬롯을 싣는 dispatch» 로 도출한다 — 자리 목록을 리터럴로 열거하지 않는다.
disp_total=0; disp_closed=0
for f in "$SKILL" "$STEEL"; do
  while IFS= read -r ln; do
    disp_total=$((disp_total + 1))
    case "$ln" in *"fail-closed"*) disp_closed=$((disp_closed + 1)) ;; esac
  done < <(grep -nE '^\s*(//|#)?\s*\*\*처분\*\*\s+—' "$f" | cut -d: -f2- )
done
if [ "$disp_total" -ge 3 ]; then
  ok "E 양성대조: 두 파일에서 처분 앵커 ${disp_total}건 도출 (아래 등식이 공허하지 않다)"
else
  no "E 양성대조: 처분 앵커 도출이 ${disp_total}건 — 3 미만이면 아래 등식이 공허하다"
fi
assert_eq "$disp_closed" "$disp_total" \
  "E: 이 자리의 처분 앵커 전부가 fail-closed (계약 배달 실패 시 «그 dispatch» 를 막는다 — 인터뷰는 막지 않는다)"

finish
```

Expected(Step 1 검증): `bash -n plugins/spec-distill/tests/test_research_claims_contract.sh` 가 조용히 끝나고 `grep -c '^# guards:' …` → `1`, `grep -c 'assert_eq\|assert_contains\|ok \|no ' …` → 20 이상.

- [ ] **Step 2: 락을 돌려 A·B·C·D·E 가 green 인지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
chmod +x plugins/spec-distill/tests/test_research_claims_contract.sh
bash plugins/spec-distill/tests/test_research_claims_contract.sh
bash plugins/spec-distill/tests/test_research_claims_contract.sh --emit-scanned | wc -l
```

Expected: `Fail: 0` · `--emit-scanned` 가 `4`. **넷만 선언한다** — 두 agent 파일(`coverage-mapper.md` · `blind-spot-prober.md`)은 이 락의 어느 축도 읽지 않으므로 `# guards:` 에 올리면 거짓 커버리지다. 그 둘의 슬롯은 자기 frontmatter 락이 잰다(Task 5 · Task 6).

- [ ] **Step 3: 축 X 를 더한다 (차가운 셸 실행)**

`finish` 앞에 넣는다:

```bash
# X — 실행. 문구가 있다는 것과 그 문구가 **돌아간다**는 것은 다른 사실이다.
BASE="/usr/bin:/bin"
PR_NOCLAIM="$SCRATCH/pr-noclaim"; mkdir -p "$PR_NOCLAIM/references"
run_fence() {   # run_fence <셀> <펜스> <플러그인 루트>
  local cell="$1" fence="$2" pr="$3"
  ( cd "$SCRATCH" && env -i PATH="$BASE" HOME="$SCRATCH" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$pr" bash "$fence" ) \
      >"$SCRATCH/$cell.out" 2>"$SCRATCH/$cell.err"
  echo $? > "$SCRATCH/$cell.rc"
}
if [ "${n_fence:-0}" -ge 5 ]; then
  FENCE_E="$SCRATCH/fence-errexit.sh"; { echo 'set -euo pipefail'; cat "$FENCE"; } > "$FENCE_E"
  for mode in plain errexit; do
    f="$FENCE"; [ "$mode" = errexit ] && f="$FENCE_E"
    run_fence "ok-$mode" "$f" "$SD"
    assert_eq "$(cat "$SCRATCH/ok-$mode.rc")" "0" "X($mode): 실제 루트면 rc 0"
    assert_eq "$(cat "$SCRATCH/ok-$mode.out")" "$(cat "$CANON")" "X($mode): stdout 이 계약 파일 내용 그대로다"
    run_fence "no-$mode" "$f" "$PR_NOCLAIM"
    assert_eq "$(cat "$SCRATCH/no-$mode.rc")" "1" "X($mode): 계약이 없는 루트면 rc 1"
    assert_eq "$(grep -c . "$SCRATCH/no-$mode.out" || true)" "0" "X($mode): 그때 stdout 은 비었다 (빈 슬롯으로 dispatch 할 거리가 없다)"
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "dispatch 하지 않는다" "X($mode): 그때 loud advisory 가 dispatch 금지를 말한다"
    # 강등 경로 둘을 이름으로 댄다 — 어느 자리가 무엇으로 강등되는지가 사유에 실려야 한다.
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "coverage-mapper 0 (unavailable: 계약 배달 실패)" "X($mode): 사유가 audit §2 문면을 댄다"
    assert_contains "$(cat "$SCRATCH/no-$mode.err")" "inline premortem" "X($mode): 사유가 prober 강등 경로를 댄다"
  done
else
  no "X: 펜스를 못 잘라 실행 축을 재지 못했다"
fi
```

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_research_claims_contract.sh 2>&1 | tail -3
```

Expected: `Fail: 0`. `errexit` 모드도 통과해야 한다(앞 블록의 `set -euo pipefail` 을 물려받아도 같다).

- [ ] **Step 4: 여섯 축이 이빨을 갖는지 변이로 잰다 — 양성 대조 먼저**

**양성 대조 없이는 RED 도 증거가 아니다.** 반드시 RED 가 나와야 하는 변이 하나를 먼저 확인한다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
LOCK=plugins/spec-distill/tests/test_research_claims_contract.sh
BK="$W/mut"; rm -rf "$BK"; mkdir -p "$BK"
for f in plugins/spec-distill/references/research-claims.md \
         plugins/spec-distill/skills/conducting-interview/SKILL.md \
         plugins/spec-distill/skills/conducting-interview/references/steelman.md \
         plugins/spec-distill/agents/steelman-builder.md; do
  cp "$f" "$BK/$(basename "$f")"
done
restore() { for f in "$BK"/*; do
  b="$(basename "$f")"
  case "$b" in
    research-claims.md) cp "$f" plugins/spec-distill/references/"$b" ;;
    SKILL.md) cp "$f" plugins/spec-distill/skills/conducting-interview/"$b" ;;
    steelman.md) cp "$f" plugins/spec-distill/skills/conducting-interview/references/"$b" ;;
    steelman-builder.md) cp "$f" plugins/spec-distill/agents/"$b" ;;
  esac; done; }

echo "=== 양성 대조: 계약 파일을 지운다 → 축 X 가 반드시 RED"
mv plugins/spec-distill/references/research-claims.md "$BK/moved.md"
bash "$LOCK" 2>&1 | tail -1
mv "$BK/moved.md" plugins/spec-distill/references/research-claims.md
echo "=== 복원 확인"
bash "$LOCK" 2>&1 | tail -1
```

Expected: 양성 대조에서 `Fail:` 이 **0 이 아니다** → 복원 후 `Fail: 0`. 양성 대조가 green 이면 계측기가 고장 난 것이므로 아래 변이 결과를 **증거로 쓰지 않는다**.

- [ ] **Step 5: 축별 변이 매트릭스를 돌리고 Commit**

네 축으로 흔든다 — **표기 · 값 · 위치 · 제약의 부정형**. 열거로 축을 만들면 변이가 락의 전제를 공유한다.

| # | 축 | 변이 | RED 를 내야 하는 축 |
|---|---|---|---|
| m1 | 표기 | SKILL.md 의 `<claims_contract>` 를 `<claims-contract>`(하이픈)로 | B |
| m2 | 값 | 세 처분 줄 중 하나를 `fail-open` 으로 | E |
| m3 | 위치 | `<!-- claims-contract:begin -->` 마커를 지운다 | C · X |
| m4 | 제약의 부정형 | 사본(`steelman-builder.md`)에서 `decides:` 를 지운다 | D |
| m5 | 제약의 부정형 | 펜스의 `exit 1` 을 `exit 0` 으로 | C · X |
| m6 | 표기 | 산문의 body-unique 문구를 펜스 안 `echo` 로 옮긴다 | A |

**Bash 도구는 호출마다 새 셸이다** — Step 4 의 `restore()`·`$BK` 는 이 호출로 넘어오지 않는다. 그래서 이 Step 은 자기완결이고 백업을 다시 뜬다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
LOCK=plugins/spec-distill/tests/test_research_claims_contract.sh
BK="$W/mut"; rm -rf "$BK"; mkdir -p "$BK"
for f in plugins/spec-distill/references/research-claims.md \
         plugins/spec-distill/skills/conducting-interview/SKILL.md \
         plugins/spec-distill/skills/conducting-interview/references/steelman.md \
         plugins/spec-distill/agents/steelman-builder.md; do
  cp "$f" "$BK/$(basename "$f")"
done
restore() { for f in "$BK"/*; do
  b="$(basename "$f")"
  case "$b" in
    research-claims.md) cp "$f" plugins/spec-distill/references/"$b" ;;
    SKILL.md) cp "$f" plugins/spec-distill/skills/conducting-interview/"$b" ;;
    steelman.md) cp "$f" plugins/spec-distill/skills/conducting-interview/references/"$b" ;;
    steelman-builder.md) cp "$f" plugins/spec-distill/agents/"$b" ;;
  esac; done; }
run_mut() {  # run_mut <이름> <python 변형>
  PYTHONDONTWRITEBYTECODE=1 python3 -c "$2" || { echo "$1: 변이 적용 실패(앵커 불일치)"; restore; return; }
  printf '%s: ' "$1"; bash "$LOCK" 2>&1 | tail -1
  restore
}
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
CP=plugins/spec-distill/agents/steelman-builder.md
run_mut m1 "import pathlib;p=pathlib.Path('$SK');t=p.read_text(encoding='utf-8');assert t.count('<claims_contract>')==2;p.write_text(t.replace('<claims_contract>','<claims-contract>',1),encoding='utf-8')"
run_mut m2 "import pathlib;p=pathlib.Path('$SK');t=p.read_text(encoding='utf-8');assert t.count('fail-closed')>=2;p.write_text(t.replace('fail-closed','fail-open',1),encoding='utf-8')"
run_mut m3 "import pathlib;p=pathlib.Path('$SK');t=p.read_text(encoding='utf-8');p.write_text(t.replace('<!-- claims-contract:begin -->\n',''),encoding='utf-8')"
run_mut m4 "import pathlib,re;p=pathlib.Path('$CP');t=p.read_text(encoding='utf-8');t2=re.sub(r'\n +decides: \[OQ1\][^\n]*','',t,count=1);assert t2!=t;p.write_text(t2,encoding='utf-8')"
run_mut m5 "import pathlib;p=pathlib.Path('$SK');t=p.read_text(encoding='utf-8');assert t.count('  exit 1\n')>=1;p.write_text(t.replace('  exit 1\n','  exit 0\n',1),encoding='utf-8')"
run_mut m6 "import pathlib;p=pathlib.Path('$SK');t=p.read_text(encoding='utf-8');old='경로가 아니라 **계약 파일의 내용**을 싣는다';assert t.count(old)==1;p.write_text(t.replace(old,'내용을 싣는다'),encoding='utf-8')"
echo "=== 최종 복원 확인"
bash "$LOCK" 2>&1 | tail -1
git status --porcelain
```

Expected: m1–m6 **전부 `Fail:` 이 0 이 아니다**. 최종 복원 후 `Fail: 0` 이고 `git status` 에 새 락 파일만 나온다. 어느 변이가 green 이면 그 축이 그 방향에 대해 이빨이 없다 — 그 사실을 락 머리 주석에 적고 다음 사이클로 넘긴다(숨기지 않는다).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git add plugins/spec-distill/tests/test_research_claims_contract.sh
git commit -F - <<'MSG'
test(spec-distill): 계약 배달 락 여섯 축 — A·B·C·X·D·E

구조는 형제 `test_dispatch_profile_inline.sh` 를 상속한다 — 같은 문제(「dispatch 슬롯에 경로가
아니라 내용을」)를 이미 네 축으로 재고 있다. 이 자리에 둘이 더 붙는다.

축 D 는 **집합 등호**다. ⊇ 와 「사본에 정본에 없는 필드 없음」은 같은 명제라, ⊇ 하나만 요구하면
사본이 `decides`·`id` 를 빠뜨려도 green 이고 그 방향이 바로 이 축의 근거로 인용한 「한쪽만 고치는」
결함이다. 등호가 둘 다 빠진 채로 성립하는 것도 막으려고 신설 필드의 실재를 따로 잰다.

축 E 가 이월 항목을 해소한다 — 처분 락은 `fail-(open|closed)` **어휘**만 보고 값을 단언하지 않고
그 파일이 스스로 그 한계를 공시한다. 이 자리의 세 앵커가 전부 `closed` 임을 등식으로 못 박되,
대상 목록을 리터럴로 열거하지 않고 처분 앵커에서 도출한다.

여섯 축의 이빨을 네 방향 변이(표기 · 값 · 위치 · 제약의 부정형) 여섯으로 확인했고, 그 전에
양성 대조(계약 파일 삭제)로 계측기가 살아 있음을 먼저 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```
---

### Task 19: 게이트 술어 다섯의 변이 · 양성 대조 · 픽스처 회귀 0 양방향 (Verification 4·5·7)

**Files:**
- Modify: `plugins/spec-distill/tests/test_check_brief.sh` (변이 결과가 드러낸 이빨 공백을 메우는 단언만)
- Create: `.superpowers/sdd/2026-09-23-interview-research-specialization/mutation-matrix.txt` (SDD 워크스페이스 — 추적 대상 밖이고 커밋하지 않는다)

**Interfaces:**
- Consumes: Task 15·16·17 의 술어 다섯
- Produces: 변이 매트릭스의 실측 결과 — Task 20 의 CHANGELOG 가 「이빨을 어떻게 쟀는가」로 인용한다.

**같은 길이 변이는 stale `.pyc` 를 못 넘는다** — 거짓 GREEN·거짓 RED 를 둘 다 낸다. 모든 변이 실행에 `PYTHONDONTWRITEBYTECODE=1`.

**`git checkout --` 를 쓰지 않는다** — index 로 되돌리므로 스테이지된 변경이 있으면 원본이 아니다. `checkout HEAD --` 를 쓰고 `git diff HEAD` 로 복원을 확인한다.

**변이 매트릭스 — 네 축** (설계 `### Deferred to plan` 의 「변이 매트릭스의 구체 항목」을 여기서 확정한다):

| # | 축 | 변이 대상 | 기대 |
|---|---|---|---|
| g1 | 표기 | `LINK_RE` 의 `$` (줄 끝 앵커)를 뗀다 | ① 이 줄 중간 연결을 받아들이므로 **하위 불릿 금지가 무력화된다** → V2-① 의 어떤 단언도 RED 가 안 될 수 있다. RED 가 안 나오면 「위치」 축의 이빨이 없다는 관측이다 |
| g2 | 값 | `CONTRACT_V2` 를 `"v3"` 로 | 옵트인이 어느 payload 에도 안 걸려 **다섯이 전부 미발동** → V2-OPT-b RED |
| g3 | 위치 | `research_entries` 에서 §5 줄 수집을 뺀다 | §5 의 `RC<n>` 줄이 순회 밖 → V2-⑤·V2-④ RED |
| g4 | 제약의 부정형 | `research_backref_missing` 의 `for num, title in (...)` 을 `("0", "한눈에")` 하나로 좁힌다 | ③ 이 §3 을 안 봄 → V2-③(nobackref) RED |
| g5 | 제약의 부정형 | `internal_research_dimension_failures` 의 이름 비교를 `startswith` 로 | ④ 가 접두 일치 → V2-④ red2 RED |
| g6 | 제약의 부정형 | `research_confirm_missing` 의 `CONFIRM_ROW_RE` 사유 부분 `(\S.*)` 를 `(.*)` 로 | ⑤ 가 빈 사유를 받음 → V2-⑤ c5c RED |
| g7 | 추가 | `research_link_missing` 에 `if len(...) > 3: return []` 를 넣는다 | **개수 술어가 차단에 끼어드는 형태** → V2-① RED. 이 변이가 RED 를 내는 것이 ⟨C5⟩ 가드가 사는 증거다 |
| g8 | 반전 | `contract_v2` 의 반환을 `not` 으로 반전 | 기존 픽스처 전량이 발동 → V2-OPT-a RED |

- [ ] **Step 1: 양성 대조 먼저 — 계측기가 살아 있는지**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
CB=plugins/spec-distill/scripts/check_brief.py
M="$W/mutation-matrix.txt"; : > "$M"
export PYTHONDONTWRITEBYTECODE=1
find . -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null
echo "=== 양성 대조: gate() 의 실패 목록을 통째로 비운다 → 반드시 대량 RED"
cp "$CB" "$W/cb.bak"
python3 -c "
import pathlib; p=pathlib.Path('$CB'); t=p.read_text(encoding='utf-8')
old='    ok = not failures'
assert t.count(old)==1
p.write_text(t.replace(old,'    failures = []\n    ok = not failures'),encoding='utf-8')"
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -1 | tee -a "$M"
cp "$W/cb.bak" "$CB"
git diff --stat HEAD -- "$CB" | tail -1
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -1
```

Expected: 양성 대조에서 `Fail:` 이 **크게 0 이 아니다**(수십 건) → 복원 후 `git diff` 가 비고 `Fail: 0`. 양성 대조가 green 이면 **아래 변이 결과는 증거가 아니다** — 멈추고 원인을 찾는다.

- [ ] **Step 2: g1–g8 을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
CB=plugins/spec-distill/scripts/check_brief.py
M="$W/mutation-matrix.txt"
export PYTHONDONTWRITEBYTECODE=1
mut() {  # mut <이름> <python 변형>
  cp "$CB" "$W/cb.bak"
  if ! python3 -c "$2"; then echo "$1	변이 적용 실패(앵커 불일치)" | tee -a "$M"; cp "$W/cb.bak" "$CB"; return; fi
  n="$(bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | sed -n 's/.*Fail: \([0-9]*\).*/\1/p' | tail -1)"
  d="$(git diff --numstat HEAD -- "$CB" | awk '{print $1"+/"$2"-"}')"
  printf '%s\tfail=%s\tdiff=%s\n' "$1" "${n:-?}" "${d:-none}" | tee -a "$M"
  cp "$W/cb.bak" "$CB"
}
# python 변형 조각의 변수는 `WR` 다 — `W` 가 **아니다**. `W` 는 이 계획 전체에서 워크스페이스를
# 가리키고, 그 이름을 여기서 다시 쓰면 위 `mut()` 안의 `$W/cb.bak` 이 **호출 시점에** 이 값으로
# 평가돼 `p.write_text(...)/cb.bak` 이 된다 — 백업도 복원도 실패하고, 변이가 추적되는 원본 파일에
# 누적돼 이후 Task 전부가 오염된 `check_brief.py` 위에서 돈다. 같은 글자가 같은 것을 가리키지
# 않는 자리는 이름을 가른다(글자가 같다고 같은 사건이 아니다).
P="import pathlib;p=pathlib.Path('$CB');t=p.read_text(encoding='utf-8')"
WR="p.write_text(t,encoding='utf-8')"
mut g1 "$P;o='|→\\\\s*없음)\\\\]\\\\s*\$\"';assert t.count(o)==1;t=t.replace(o,'|→\\\\s*없음)\\\\]\"');$WR"
mut g2 "$P;o='CONTRACT_KEY, CONTRACT_V2 = \"contract\", \"v2\"';assert t.count(o)==1;t=t.replace(o,'CONTRACT_KEY, CONTRACT_V2 = \"contract\", \"v3\"');$WR"
mut g3 "$P;o='    out += [ln for ln in section5_entries(text) if RC_RE.search(ln)]';assert t.count(o)==1;t=t.replace(o,'    pass');$WR"
mut g4 "$P;o='    for num, title in ((\"3\", \"Open Questions\"), (\"0\", \"한눈에\")):';assert t.count(o)==1;t=t.replace(o,'    for num, title in ((\"0\", \"한눈에\"),):');$WR"
mut g5 "$P;o='if not m or m.group(1).strip() != DERIVED_INTERNAL_RESEARCH:';assert t.count(o)==1;t=t.replace(o,'if not m or not m.group(1).strip().startswith(DERIVED_INTERNAL_RESEARCH):');$WR"
mut g6 "$P;o='—\\\\s+(확인|반증|미확인)\\\\s+—\\\\s*(\\\\S.*)\$';assert t.count(o)==1;t=t.replace(o,'—\\\\s+(확인|반증|미확인)\\\\s+—\\\\s*(.*)\$');$WR"
mut g7 "$P;o='    return [ln for ln in research_entries(text) if not LINK_RE.search(ln)]';assert t.count(o)==1;t=t.replace(o,'    bad = [ln for ln in research_entries(text) if not LINK_RE.search(ln)]\n    return [] if len(bad) > 3 else bad');$WR"
mut g8 "$P;o='    return frontmatter_value(CONTRACT_KEY, _frontmatter(text)) == (CONTRACT_V2, None)';assert t.count(o)==1;t=t.replace(o,'    return frontmatter_value(CONTRACT_KEY, _frontmatter(text)) != (CONTRACT_V2, None)');$WR"
echo "=== 최종 복원 확인"
git diff --stat HEAD -- "$CB"; bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -1
cat "$M"
```

Expected: **g1–g8 전부 `fail=` 이 0 이 아니고 `diff=` 가 `none` 이 아니다**(변이가 실제로 파일을 바꿨다). 복원 후 `git diff` 가 비고 `Fail: 0`.

**어느 변이가 `fail=0` 이면** 그 축에 이빨이 없다는 **관측이다.** 그때:
1. 그 술어에 그 방향을 잡는 단언을 `test_check_brief.sh` 에 더한다.
2. 못 메우면 그 사실을 `check_brief.py` 의 해당 docstring 에 「이 검사가 못 잡는 것」으로 적고 설계의 `## 알려진 한계` 에 추가할 항목으로 보고한다. **숨기지 않는다.**

**`diff=none` 이면 변이가 적용되지 않은 것이다** — 앵커 불일치이므로 그 줄을 다시 찾아 변이를 고친다. `fail=0`+`diff=none` 을 「이빨 있음」으로 읽지 않는다.

- [ ] **Step 3: 픽스처 회귀 0 을 양방향으로 확정한다 (Verification 7)**

**(a) 만 확인하면 옵트인이 「이빨 0」과 구별되지 않는다.**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
export PYTHONDONTWRITEBYTECODE=1
echo "=== (a) contract 없는 픽스처 전량: 새 술어로 red 가 되지 않는다"
tot=0; reg=0
for f in plugins/spec-distill/tests/fixtures/*.md; do
  case "$f" in *.audit.md) continue ;; esac
  grep -q '^contract: v2$' "$f" && continue
  tot=$((tot+1))
  out="$(python3 plugins/spec-distill/scripts/check_brief.py gate "$f" 2>/dev/null)"
  printf '%s' "$out" | grep -qE '결정 연결|역참조|연결 대상|내부 조사 차원|확인 줄 누락' \
    && { reg=$((reg+1)); echo "REGRESSION: $f"; }
done
echo "(a) 검사한 픽스처 $tot · 새 술어로 red $reg"
echo "=== (a2) 그중 §4 를 가진 것 수 (착수 전 81 과 같아야 한다)"
grep -rl '^## 4\. External Landscape' plugins/spec-distill/tests/fixtures | wc -l
echo "=== (a3) 기존 픽스처가 한 글자도 안 바뀌었다"
git diff --stat HEAD~12 -- plugins/spec-distill/tests/fixtures/ | grep -v 'v2-valid' | tail -3 || echo "v2 fixture 외 변경 없음 ✓"
echo "=== (b) contract: v2 를 넣으면 다섯이 전부 발동한다 — Task 17 Step 4 를 재실행"
```

Expected: `(a) … 새 술어로 red 0` · `(a2)` 가 착수 전과 같은 값(81) · `(a3)` 에 `v2-valid` 외 픽스처 변경 없음 · `(b)` 는 Task 17 Step 4 의 다섯 실패가 그대로 재현.

- [ ] **Step 4: 변이가 드러낸 공백을 메운다 (있으면)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
awk -F'\t' '$2=="fail=0"{print "이빨 공백: "$1}' "$W/mutation-matrix.txt" || true
```

Expected: 출력 없음. 있으면 위 Step 2 의 처방대로 단언을 더하거나 한계를 공시하고, 그 편집을 이 Task 의 커밋에 넣는다.

- [ ] **Step 5: Commit (편집이 있을 때만)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git status --porcelain
# 편집이 없으면 이 Task 는 커밋 없이 끝난다 — 측정만 한 Task 다.
# 있으면:
git add plugins/spec-distill/tests/test_check_brief.sh plugins/spec-distill/scripts/check_brief.py
git commit -F - <<'MSG'
test(spec-distill): 변이 여덟이 드러낸 이빨 공백을 메운다

네 축(표기 · 값 · 위치 · 제약의 부정형)에 추가·반전을 더해 여덟으로 흔들었다. 열거로 축을 만들면
변이가 락의 전제를 공유한다 — 그래서 축을 제약의 «부정형» 에서 도출했다.

g7 이 특히 요점이다: 차단 술어에 개수 조건을 **넣는** 변이가 RED 를 내는 것이 ⟨C5⟩ 가드가 살아
있다는 증거다. 그 변이가 green 이면 「개수를 쓰지 않는다」는 주장에 집행이 없다.

양성 대조(gate() 의 실패 목록을 통째로 비움)를 먼저 확인했다 — 그것 없이는 RED 도 증거가 아니다.
같은 길이 변이가 stale .pyc 를 못 넘는 것을 막기 위해 전 구간 PYTHONDONTWRITEBYTECODE=1 이고,
복원은 index 가 아니라 HEAD 대비 diff 로 확인했다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

---

### Task 20: 릴리스 — `3.3.0` · 전체 스위트 · baseline 대조 · web-off 실측 (AC17 · AC18 · AC24)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`

**Interfaces:**
- Consumes: Task 1 의 `baseline.txt` · Task 7 의 `loadsurface.txt` · Task 19 의 `mutation-matrix.txt`
- Produces: 릴리스. 이 Task 뒤에는 사용자 e2e 와 PR 만 남는다.

**버전은 머지 직전에 정한다** — 브랜치 안에서 먼저 올리면 먼저 머지되는 쪽이 이긴다. 그래서 이 Task 가 마지막이다. `3.2.0 → 3.3.0`(minor = 새 surface)이고, 머지 시점에 `origin/main` 의 값이 이미 `3.3.0` 이면 `3.4.0` 으로 올린다.

- [ ] **Step 1: 전체 스위트를 돌려 baseline 과 대조한다 (AC18)**

**rc 뿐 아니라 실패 «줄 수»까지** 대조한다 — 이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
A="$W/after.txt"; : > "$A"
for f in plugins/*/tests/*.sh shared/tests/*.sh; do
  case "$(basename "$f")" in assert.sh|presence_corpus.sh) continue ;; esac
  out="$(bash "$f" 2>&1)"; rc=$?
  # 접두 `  ✗ ` 로 센다 — `assert.sh` 의 `no()` 가 `printf '  ✗ %s\n'` 로 내고
  # `shared/tests/test_assert_behavior.sh` 가 그 접두를 「진단 grep 다섯 자리의 계약」으로 못 박는다.
  # 접두 없이 세면 설명 문구에 그 글자를 담은 **통과** 줄이 실패로 잡힌다(실측: 그 파일이 rc 0 인데 1).
  nfail="$(printf '%s\n' "$out" | grep -c '^  ✗ ' || true)"
  # **이미 RED 인 파일의 «새» 실패**를 잡는 세 번째 필드. `rc!=0` 인데 `fail_lines=0` 인 파일은
  # (단언 실패가 아니라 조기 중단이라 `  ✗ ` 줄을 안 낸다) 두 술어가 둘 다 포화라 새 실패가
  # 어느 쪽도 움직이지 않는다 — AC18 이 경고하는 바로 그 구멍이다. 실측: 착수 시
  # `plugins/quality-gates/tests/test_codex_backward_compat.sh` 가 `rc=1 fail_lines=0` 이다.
  # 특정 파일 이름을 박지 않고 `rc!=0` 전부에 건다 — 다음에 다른 파일이 RED 가 되어도 자동 대상이다.
  # GREEN 파일은 `-` 로 둔다: 통과 출력의 해시는 무해한 문구 변화에도 흔들려 소음만 된다.
  if [ "$rc" -eq 0 ]; then h="-"; else h="$(printf '%s\n' "$out" | shasum -a 256 | cut -c1-16)"; fi
  printf '%s\trc=%s\tfail_lines=%s\touthash=%s\n' "$f" "$rc" "$nfail" "$h" >> "$A"
done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3 | tee -a "$A"
echo "=== baseline 대조 — 데이터 줄 전체를 diff 한다"
# 필드별 join 을 쓰지 않는다: 필드가 넷이 되어 인덱스가 어긋나기 쉽고, 두 파일에는 산문 줄이
# 섞여 있어(python tail · `=== … ===` 블록) 키 추출이 브리틀하다. 탭이 있는 데이터 줄만 골라
# 줄 전체를 비교하면 rc · 실패 줄 수 · 출력 해시 셋이 한 번에 대조된다.
grep '	rc=' "$W/baseline.txt" | sort > "$W/base-data.txt"
grep '	rc=' "$A" | sort > "$W/after-data.txt"
diff "$W/base-data.txt" "$W/after-data.txt" && echo "데이터 줄 완전 동일"
echo "=== baseline 에 없던 파일 (새 락 — 여기 나오는 것은 정상)"
comm -13 <(cut -f1 "$W/base-data.txt") <(cut -f1 "$W/after-data.txt")
echo "=== 지금 RED 인 것 전부"
awk -F'\t' '$2!="rc=0"' "$W/after-data.txt"
```

Expected: `diff` 가 내는 것은 **정확히 한 줄의 추가**여야 한다 — 새 락
`test_research_claims_contract.sh` 의 `rc=0 fail_lines=0 outhash=-`. 그 줄은 `comm -13` 에도 나온다.

근거(선점검에서 실측): baseline 의 글롭은 이 Step 의 것과 **같은 문자열**이고, 지금 그 글롭이 내는
파일은 205개이며 제외 둘(`assert.sh` · `presence_corpus.sh`)을 빼면 **baseline 의 데이터 줄 203개와
정확히 일치**한다. 모든 락이 착수 시에도 지금도 `rc=0 fail_lines=0 outhash=-` 이거나 선재 RED 넷
그대로이므로, 새 락 하나를 뺀 나머지 줄은 **바이트 동일**해야 한다.

**추가 한 줄 말고 무엇이든 나오면 멈추고 보고하라.** 변경(`<`/`>` 짝)이 나오면 그 락의 rc·실패 줄
수·출력 해시 중 무엇이 움직였는지 밝히고, 이 작업이 의도적으로 고친 자리인지 판정한다. 「지금 RED
인 것」은 Task 1 이 못 박은 선재 RED 집합과 **같아야 한다** — 하나라도 늘면 새 RED 이고 AC18 위반이다.

**`outhash` 가 움직였는데 rc·실패 줄 수가 그대로면** 이미 RED 인 파일 «안»에서 실패의 내용이 바뀐 것이다. 그 파일을 직접 돌려 출력을 눈으로 대조하고, 우리가 새 실패를 더한 것인지 기존 실패의 문면이 바뀐 것인지 가른다. 이 필드가 없으면 그 구별이 원리적으로 불가능하다 — 착수 시 `plugins/quality-gates/tests/test_codex_backward_compat.sh` 가 `rc=1 fail_lines=0` 으로 두 술어가 이미 포화였다.

- [ ] **Step 2: `EXEMPT_SLOTS_BASELINE` 과 처분 회계를 최종 확인 (이월 해소 · AC24)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash shared/tests/test_agent_input_slots.sh 2>&1 | grep -E '면제 목록|선언 ↔ 전달|다중-agent|Total'
bash shared/tests/test_dispatch_disposition.sh 2>&1 | grep -E '축 A①|축 C|Total'
echo "=== 새 슬롯의 kind 실측"
grep -A2 'tag: claims_contract' plugins/spec-distill/agents/*.md | grep 'kind:' | sort -u
grep -A2 'tag: open_decisions' plugins/spec-distill/agents/*.md | grep 'kind:' | sort -u
PYTHONDONTWRITEBYTECODE=1 python3 -c "
import sys; sys.path.insert(0,'tools/adjudication')
import check_slots
print('EXEMPT_SLOTS_BASELINE =', check_slots.EXEMPT_SLOTS_BASELINE)
print('EXEMPT_SLOTS 항목 수 =', len(check_slots.EXEMPT_SLOTS))"
```

Expected: 「면제 목록 5 <= baseline 5」 ✓ · 「선언 ↔ 전달 일치, 금지 종류 없음」 ✓ · 축 A① 「앵커 수 == dispatch 수」 ✓ · 축 C ✓. 두 `kind:` 가 각각 `repo_context`·`task` 하나씩. **`EXEMPT_SLOTS_BASELINE` bump 는 불필요** — 이월 항목이 이렇게 해소된다.

- [ ] **Step 3: web-off 세션을 실측한다 (Verification 8 — §B 의 핵심 주장)**

주장: **DISABLE_WEB=1 에서도 내부 축은 돌고 웹 축만 강등된다.** 한 사이클을 실제로 돌리지 않고 **구조적으로** 잰다(e2e 는 사용자 몫).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
W=.superpowers/sdd/2026-09-23-interview-research-specialization
export DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 PYTHONDONTWRITEBYTECODE=1
echo "=== ① 계약 배달 펜스는 웹 스위치와 무관하다 (차가운 셸 실행)"
awk '/<!-- claims-contract:begin -->/ {g=1; next} /<!-- claims-contract:end -->/ {g=0}
     g && /^```bash$/ {b=1; next} g && b && /^```$/ {b=0; next} g && b' \
  plugins/spec-distill/skills/conducting-interview/SKILL.md > "$W/f.sh"
( env -i PATH=/usr/bin:/bin DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 \
    CLAUDE_PLUGIN_ROOT="$(pwd)/plugins/spec-distill" bash "$W/f.sh" ) >/dev/null 2>&1
echo "rc=$?  (0 이어야 한다 — 스위치와 무관)"
echo "=== ② 게이트 술어 다섯이 웹 스위치와 무관하다"
python3 plugins/spec-distill/scripts/check_brief.py gate \
  plugins/spec-distill/tests/fixtures/interview-brief-v2-valid.md 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("pass:",d["pass"]); print("advisories:",len(d["advisories"]))'
echo "=== ③ 내부 축의 주 생산자가 웹 도구를 쓰지 않는다 (C43 (a) 행)"
awk '/^## C43 /{f=1} f && /\(a\) \*\*factual/{print; exit}' \
  plugins/spec-distill/skills/conducting-interview/SKILL.md | grep -c 'subagent 를 부르지 않는다'
echo "=== ④ 강등되는 것은 웹 축뿐이다 — 두 강등 경로가 이름으로 선언돼 있다"
grep -c 'inline premortem' plugins/spec-distill/skills/conducting-interview/SKILL.md
grep -c '수동 의심 게이트' plugins/spec-distill/skills/conducting-interview/references/steelman.md
echo "=== ⑤ 웹 kill switch 락"
bash plugins/spec-distill/tests/test_web_kill_switch.sh 2>&1 | tail -2
unset DEVBREW_SPEC_DISTILL_DISABLE_WEB
```

Expected: ① `rc=0` · ② `pass: True` 이고 advisories 는 `WEB_DISABLED_ADVISORY` 하나(=1) · ③ `1` · ④ 각각 ≥1 · ⑤ `Fail: 0`. **이 다섯이 §B 의 주장을 구조적으로 확인한다.** 실제 한 사이클 e2e 는 자동화하지 않으므로 아래 Step 5 가 사용자에게 넘긴다.

- [ ] **Step 4: 버전 · CHANGELOG · README**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
git fetch origin main --quiet && git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("plugins/spec-distill/.claude-plugin/plugin.json")
d = json.loads(p.read_text(encoding="utf-8"))
assert d["version"] == "3.2.0", d["version"]
d["version"] = "3.3.0"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("version ->", d["version"])
PY
```

Expected: `origin/main` 이 `3.2.0` 이고 새 값이 `3.3.0`. **`origin/main` 이 이미 `3.3.0` 이면 `3.4.0` 으로 올리고 CHANGELOG 헤딩도 맞춘다.**

`CHANGELOG.md` 맨 위(`# Changelog` 다음)에 넣을 항목:

```markdown
## [3.3.0] — 2026-09-23

minor 인 이유 — 새 surface 가 셋이다: 조사 주장 계약의 정본(`references/research-claims.md`)과 그
배달 펜스, 세 dispatch 자리의 입력 슬롯 둘(`claims_contract` · `open_decisions`), 그리고
`check_brief.py` 의 조사 축 술어 다섯. 삭제는 리터럴 마커 하나(`[from-code][auto-confirmed]`,
15사이클 0건)뿐이라 호출 계약은 줄지 않는다. 설계
`docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md`.

### Added

- **조사 주장 계약이 정본을 갖는다.** `references/research-claims.md` 가 `evidence[]`(외부) ·
  `repo_claims[]`(내부) 두 모양을 담고 신설 필드 둘을 정의한다 — `decides`(닿는 열린 결정 `OQ<n>`)와
  `id: RC<n>`(payload·audit 을 잇는 id). 기존 `touches`(전제 `P<n>`)의 뜻은 **바뀌지 않는다**:
  `steelman.md` Step 2 대조 · Step 2.5 재검토 자격 · 4-block 라벨 · audit 템플릿의 「부착 주장 → P<n>」
  넷이 그 키잉에 의존한다.
- **계약이 네 자리에 걸린다.** dispatch 셋(`coverage-mapper` · `blind-spot-prober` ·
  `steelman-builder`)이 `<claims_contract>`·`<open_decisions>` 두 슬롯을 받고, C43 경로 (a) 자동확인은
  orchestrator 가 직접 수행한다(네 번째 dispatch 자리를 만들지 않는다 — 기본 탑재 subagent 는
  처분 락의 agent 집합 밖이라 앵커만 +1 되어 「앵커 수 == dispatch 수」가 red 가 된다).
- **검문소 셋.** V1(라운드 규약 안, 무조건 — 경로 → 앵커 → 「그 자리가 주장과 맞는가」) ·
  V2(`finishing.md`, 무조건, 누락 대조만) · V3(게이트, 형태 ∀). 앞 둘은 웹 스위치와 steelman
  trigger 에 종속되지 않는다.
- **state `orchestration.open_decisions[]`** — 인터뷰 중 결정의 유일한 거처이자 `OQ<n>` 의 산출자.
  해결된 결정도 지우지 않고 상태 토큰으로 구분한다.
- **게이트 술어 다섯** — 연결 ∀ · 연결 대상 실재 · 역참조 ∀(§3·§0 양쪽) · 이름 정확 일치
  `derived:internal_research` + `closed`(조건부) · 확인 줄 ∀. **차단 판정에 개수가 없다** — 전부 ∀ 이고
  순회 항목이 0건이면 공허 통과한다. 개수는 조건 분기와 advisory 에만 들어간다.
- **`contract: v2` 옵트인** — 술어 다섯이 이 frontmatter 필드가 있을 때만 발동한다. 기존 §4 보유
  픽스처 81개를 한 글자도 고치지 않는 장치이고, 없을 때는 advisory 「신 계약 미적용 brief」가
  Step B 게이트로 간다. 「내부 조사 0건」도 같은 채널이다 — 침묵과 0 은 다른 사실이다.
- 락: `tests/test_research_claims_contract.sh` 여섯 축(A 산문 · B 양의 짝 · C 펜스 · X 차가운 셸
  실행 · D 정본↔사본 집합 등호 · E `fail-closed` 값). 축 E 가 처분 락의 공시된 한계(어휘만 보고 값을
  단언하지 않는다)를 이 자리에서 메운다.

### Changed

- **dispatch 통제가 상한에서 «자격 + 예산»으로.** 자격 = 그 장치가 채우는 차원에 닿는 열린 결정이
  아직 있는가(열린 결정이 0이면 예산이 남아도 부르지 않는다) · 예산 = `1 + 재개방`. 옛 문구
  (`상한 2` · `fan-out 1` · `인터뷰당 1회` · `bounded dispatch`)는 두 장치의 **열네 자리**에서
  교체했다 — 착수 시 grep 으로 전수 재도출했고 설계가 열거한 여섯은 `agents/` 만의 전수였다.
  엔진의 `재리뷰 상한 2` · 확정 재제시 `상한 2회` · `rhythm guard 3` 은 **다른 것을 세므로 건드리지
  않았다**.
- **C44 면제.** 산출 항목의 `decides` 가 `status: open` 이고 `touched: false` 인 결정을 하나라도
  담으면 `non_user_streak` +0, 아니면 +1. **순서가 계약이다 — 「계수 먼저, 표시 나중」**: 반대로 두면
  계수 시점에 「아직 안 닿은 것」이 항상 공집합이라 첫 연결부터 +1 이 되고 면제가 영구히 발화하지
  않는다. 면제 예산은 그 집합 크기로 유한하다.
- **처분 방향 셋이 `fail-open` → `fail-closed`.** 막는 것은 «그 dispatch» 이고 인터뷰가 아니다 —
  계약 펜스가 실패하면 그 장치를 부르지 않고, 인터뷰는 계속하며 그 차원을 자동으로 닫지 않고
  advisory 가 사람에게 간다.
- **`blind_spot_dispatched: bool` → `blind_spot_dispatches: int`** — 개명이라 값을 이월한다
  (`true → 1`, `false → 0`)고 옛 키를 지운다. 부재 키 규칙만 쓰면 이미 dispatch 한 세션이 `0` 을
  받아 AP16 가드가 재무장된다.
- 템플릿 둘이 세 방향을 예시로 보인다 — 템플릿이 red 를 가르치면 첫 게이트가 항상 red 다.
- SKILL.md 순감 래칫 둘을 순증 수용으로 다시 조였다(실측 + 8). 설계가 로드 표면 순증을 명시적으로
  수용했고 삭제가 0이다.

### Removed

- 리터럴 마커 `[from-code][auto-confirmed]` — 15사이클 0건이고 같은 행위가 audit §5 에
  `auto-confirmed:` 라는 다른 표기로 이미 실재했다. 갈라진 사본은 「한쪽만 고치는」 결함을 부른다.
  개념은 계약으로 흡수된다.

### 알려진 한계 (설계 §알려진 한계 전량이 그대로 유효하다)

- **조건부 발동이 피검자 산출물에 앵커돼 있다** — `RC<n>` 을 0건 내면 술어 넷이 발동하지 않는다.
  `check_brief.py` 는 brief 파일만 읽으므로(모듈 불변식) 「조사를 했어야 했는가」를 알 방법이 없다.
  backstop 은 0건 advisory 가 Step B 게이트 텍스트로 사람에게 가는 것이다.
- **면제 판정은 자기 신고다** — `non_user_streak`·`touched` 는 세션 state 에만 살고 게이트는 state 를
  읽지 않는다. 이 릴리스가 더한 것은 산출자와 거처이고, 값이 정직한지는 여전히 모델의 자기 신고다.
- **「열려 있음」은 검사하지 않는다** — 연결 대상 실재는 목록에 있는가만 보고 상태 토큰은 보지 않는다.
  의도된 선택이다: 상태를 보면 결정을 해결하는 데 기여한 조사가 red 가 된다.
- **V1 의 3단계는 기계가 대신할 수 없다** — 「주장이 그 자리와 맞는가」는 내용 이해다. V2·V3 가 보는
  것은 「그 확인 줄이 항목마다 있는가」까지다.
- **정본과 사본이 둘 남는다** — 락 축 D 가 필드 이름 집합의 등호를 지키지만 **설명 산문의 갈라짐은
  못 잡는다**.
- **`derived` 행의 `closed` 요구는 「근거가 적혀 있는가」까지다** — `coverage_anchor_failures` 가
  form-only 라 실재하는 아무 `S<N>` 이든 받는다.
- **확인 판정이 두 자리에 기록된다** — steelman 경로는 audit §3(`ST<N>` 블록)과 §5(`확인 RC<n>`)에
  같은 판정을 적는다. 확인 «행위» 는 한 번이고 기록만 둘이다.
- **§H 표기층은 리뷰로 검증되지 않았다** — 설계 라운드 3 을 돌지 않았고, 이 릴리스의 red/green 짝과
  변이가 그 절의 유일한 검증이다.
```

`README.md` 의 `## Principles Instantiated` 에 추가할 줄:

```markdown
- **Law 1 (Clarity) — 조사가 방향에 닿는가 (3.3.0)** — 조사 주장의 계약(`references/research-claims.md`)이
  네 자리에 걸리고 검문소 셋(라운드 안 V1 · 종료 누락 대조 V2 · 게이트 V3)이 그것을 집행한다. 게이트의
  술어 다섯은 **전부 ∀ 형태**이고 차단 판정에 개수가 없다 — 재서 **막으면** 사후 장치이고 재서
  **보이면** 공시다(2026-09-10 에 걷어낸 사후 깊이 측정 계열과 양립하는 근거가 그 구분이다). 「조사를
  했어야 했는가」는 기계가 알 수 없고(`check_brief.py` 는 brief 파일만 읽는다) 0건 advisory 가 Step B
  게이트로 사람에게 간다.
- **P17 (User sovereignty) — dispatch 통제가 자격 + 예산 (3.3.0)** — 다시 부를 «자격» 은 「그 차원에
  닿는 열린 결정이 아직 있는가」이고, 그 위의 예산은 `1 + 재개방` 이다. 재개방은 정의상 사용자 답이
  걸린 사건이라 **사용자가 시계다** — 숫자 상한이 아니라 사용자 참여가 총량을 묶는다.
```

- [ ] **Step 5: 릴리스 락 · 최종 스위트 · Commit · 사용자 인계**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-research-burden
bash plugins/spec-distill/tests/test_readme_sync.sh 2>&1 | tail -2
bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -2
for f in plugins/*/tests/*.sh shared/tests/*.sh; do
  case "$(basename "$f")" in assert.sh|presence_corpus.sh) continue ;; esac
  out="$(bash "$f" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || printf 'RED %s (rc=%s)\n' "$f" "$rc"
done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -F - <<'MSG'
release(spec-distill): 3.3.0 — 인터뷰의 조사 특화

새 surface 셋(계약 정본 + 배달 펜스 · dispatch 슬롯 둘 · 게이트 술어 다섯)이라 minor 다. 삭제는
리터럴 마커 하나뿐이라 호출 계약은 줄지 않는다.

착수 전 baseline(파일별 rc + 실패 줄 수)과 대조해 새 RED 0 을 확인했다 — rc 만 잡으면 이미 RED 인
파일 안의 새 실패가 원리적으로 안 보인다. 픽스처 회귀는 양방향으로 쟀다: contract 없는 것 전량이
무변경으로 통과하고, contract: v2 를 넣은 픽스처에서는 다섯이 전부 발동한다. (a) 만 확인하면
옵트인이 「이빨 0」과 구별되지 않는다.

한계를 CHANGELOG 에 그대로 옮겼다 — 조건부 발동이 피검자 산출물에 앵커돼 있고, 면제는 자기
신고이며, 정본과 사본이 둘 남고, §H 표기층은 리뷰로 검증되지 않았다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01D5Xd9k8aYnt5ojzb9MU1J7
MSG
```

Expected: `test_readme_sync.sh`·`test_changelog_integrity.sh` `Fail: 0`. `RED` 줄은 Task 1 이 못 박은 선재 RED 집합과 **같다**. python `OK`.

**사용자에게 남기는 두 가지 (자동화하지 않는다):**

1. **e2e 수동 검증** — 실제 `/interview` 한 사이클. 확인할 것: ① 계약 펜스가 실제 dispatch 직전에 돌아 `CLAIMS_CONTRACT` 가 채워지는가 ② `OQ<n>` 발급이 «다음 결정» 블록에서 실제로 일어나는가 ③ V1 의 3단계가 사람이 읽을 만한 판정을 내는가 ④ 게이트가 첫 실행에서 red 를 내지 않는가(템플릿이 green 을 가르치는가) ⑤ Step B 게이트 텍스트에 advisory 둘이 실제로 실리는가.
2. **PR 과 머지** — `gh pr create` 로 PR 을 열고, 머지는 사용자가 `! gh pr merge <n> --merge` 로 한다(auto-mode 판정기가 `gh pr merge` 를 막고 `gh api` 우회는 금지다). 머지 직전에 `origin/main` 의 `plugin.json` 버전을 다시 확인한다 — 같은 버전 문자열은 충돌 없이 병합되고 먼저 머지되는 쪽이 이긴다.

---

## Deferred to plan — 일곱 항목의 처분

설계 `### Deferred to plan` 전량이 어디서 해소되는가.

| # | 이월 항목 | 어디서 | 처분 |
|---|---|---|---|
| 1 | floor 리터럴 계수 재도출 | Task 1 Step 4 | **범위를 「플러그인 범위」로 못 박고** 그 값만 baseline 에 기록. 파일 밖 기대값으로 고정하지 않는다(같은 축을 세 번 재서 세 값이 나온 이력) |
| 2 | 로드 표면 순증 실측 | Task 7 Step 3 | 파일 바이트로 측정해 `loadsurface.txt` 에. 무조건 로드(SKILL.md)와 조건부 로드(새 reference)를 **따로** 센다. 격리 설치가 아니라 「하류가 매 세션 읽는 양」이 필요한 값이다 |
| 3 | `EXEMPT_SLOTS_BASELINE` bump 여부 | Task 4 의 kind 결정 + Task 20 Step 2 실측 | **bump 불필요.** `claims_contract` → `repo_context`(ⓓ 리포 규약) · `open_decisions` → `task`(ⓐ 원장 상태 요약 — `coverage-mapper.ledger_state` 선례). 둘 다 `ALLOWED_KINDS` 안이라 면제 등재 자체가 없다 |
| 4 | 변이 매트릭스의 구체 항목 | Task 19 Step 2 (g1–g8) + Task 18 Step 5 (m1–m6) | **열넷을 확정했다.** 축은 표기·값·위치·제약의 부정형 + 추가·반전. g7(차단 술어에 개수 조건을 **넣는** 변이)이 ⟨C5⟩ 가드의 생존 증거다 |
| 5 | 픽스처 파일명 목록 | Task 14 Step 2 | green 쌍 하나만 파일로 둔다: `interview-brief-v2-valid.md` + `.audit.md`. **red 는 런타임 생성**(그 green 에서 한 가지만 망가뜨린다) — 픽스처 수를 늘리지 않고 원인이 분리된다 |
| 6 | `RC<n>` 번호의 유일성 범위 | Task 2 Step 2 (계약 규칙 4) | **한 인터뷰 안에서만 유일**(payload + audit 한 쌍). `S<N>`·`ST<N>` 과 같은 규약이고 코퍼스 전체의 유일성은 요구하지 않는다 |
| 7 | `fail-closed` 값의 회귀 감지 수단 | Task 18 의 **축 E** | 새 락이 처분 앵커에서 대상을 도출해 「이 자리의 앵커 전부가 `closed`」를 등식으로 잰다. 자리 목록을 리터럴로 열거하지 않으므로 자리가 늘어도 자동으로 대상이 된다. 처분 락이 공시한 한계(어휘만 보고 값을 단언하지 않는다)를 이 자리에서 메운다 |

## Open Questions — 계획이 답하지 않는 것

설계 `## Open Questions` 넷은 그대로 열려 있다. **유추하지 않는다.**

- **OQ-A** 이 요청을 다시 꺼내게 만든 구체적 사건 — 사용자만 답할 수 있다.
- **OQ-B** 네 국면·네 축 각각의 구체 사례 — 사용자 판단이고 사례는 수집되지 않았다.
- **OQ-C** 첫 사이클 레포에서의 수익률 — 조건부 발동이 부분 해소이고, 남는 것은 「건질 것이 없는 레포에서 advisory 가 소음이 되는지」의 관측이다. Task 20 Step 5 의 e2e 가 그 첫 관측점이다.
- **OQ-D** 반증 소비 경로의 **해결** — 범위 밖이다. 이 계획은 기록 형식(V1 반증 → §5 세 칸)과 V1 의 라운드-안 배치까지만 구현한다. 전진 경로(반증 → 사용자 게이트 → 확정 전이 → 게이트 처분)는 다음 사이클이다.
