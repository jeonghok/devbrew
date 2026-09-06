# steelman 목표 적합 — R3 의심 게이트 재설계 · Design

> 대안을 세우는 이유는 원안을 뒤집는 것이 아니라 사용자 goal 에 가장 맞는 방향을 찾는 것이다. 열쇠는 핵심 전제 충돌 하나다.

## Handoff Context

**TL;DR** (무엇을, 왜):
- spec-distill 인터뷰의 R3 steelman 게이트를 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로
  재설계한다 — builder 가 양쪽 케이스를 같은 기준으로 쓰고 전제 충돌만이 재검토를 연다. 판정 어휘는
  유지/보완/전환/보류(kept/refined/switched/deferred).
- 이유: 기준 부재 + 역할 편향이 근거의 강도로 관련성을 대체하게 했고 이분 어휘가 그것을 원장에 굳혔다(brief §0).

**Implicit context** (Constraints 에 안 박힌, 진행에 필요한 외부 사실):
- 입력 brief `docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md`(C1–C26 confirmed, S1–S18) +
  같은 이름의 `.audit.md`. brainstorming 중 사용자 결정은 S15–S18 이고 §11 에 있다.
- 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다.
- 이 문서의 리포 사실은 §5 F1–F6 에 실측으로 있다. spec 리뷰 라운드 1 이 F4 를 정정했다.
- 브랜치는 워크트리 `feature+steelman-goal-fit`(브랜치명 `worktree-feature+steelman-goal-fit`). 파일 경로는 전부 그
  워크트리 기준이다.

**Deferred to plan** (이 spec 이 의도적으로 lock 하지 않은 결정):
- §13 U2–U4: 픽스처 최소 본문 규약 · 수동 e2e 배치 · 커밋 분할.
- 과거 brief 기계 토큰 2줄의 kept/refined 값 — 산문을 읽고 plan 시점에 정한다(D5).

### 이름 규약

**T1–T7** 작업 · **AC1–AC23** 인수 기준 · **D1–D5** 이 단계의 사용자 결정 · **O1–O5** orchestrator 가
묻지 않고 정한 것(되돌리는 말과 함께) · **F1–F6** 이 사이클이 리포에서 실측한 사실 ·
**U2–U4** `writing-plans` 가 정할 미결(U1 은 라운드 1 에서 확정돼 삭제). brief 의 **C<N>**(제약) · **OQ<N>**(열린 질문) ·
**S<N>**(사용자 원문) · **P<N>**(핵심 전제) 은 그대로 쓴다.

## 목차

- [0. 한눈에](#0-한눈에)
- [1. Context — 왜](#1-context--왜)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 실측 사실 F1–F6](#5-실측-사실-f1f6)
- [6. 설계](#6-설계)
  - [6.1 T1 — steelman-builder 페르소나](#61-t1--steelman-builder-페르소나)
  - [6.2 T2 — R3 절차 `references/steelman.md`](#62-t2--r3-절차-referencessteelmanmd)
  - [6.3 T3 — `scripts/skepticism.py` 모듈](#63-t3--scriptsskepticismpy-모듈)
  - [6.4 T4 — 토큰 이관](#64-t4--토큰-이관)
  - [6.5 T5 — 락·픽스처](#65-t5--락픽스처)
  - [6.6 T6 — 템플릿·README·CHANGELOG·버전](#66-t6--템플릿readmechangelog버전)
  - [6.7 T7 — 슬롯 면제 등재](#67-t7--슬롯-면제-등재)
- [7. Acceptance Criteria](#7-acceptance-criteria)
- [8. Files to Modify](#8-files-to-modify)
- [9. Verification Plan](#9-verification-plan)
- [10. Rejected Alternatives](#10-rejected-alternatives)
- [11. 재결정 기록](#11-재결정-기록)
- [12. 위험과 brief §5 대응의 이월](#12-위험과-brief-5-대응의-이월)
- [13. writing-plans 가 정할 미결](#13-writing-plans-가-정할-미결)
- [14. Metadata](#14-metadata)

## 0. 한눈에

**무엇** — spec-distill 인터뷰의 R3(의심된 방향에 대해 steelman-builder 가 케이스를 만들고 사용자가
판정하는 게이트)를 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 다시 세운다.

**어떻게** — 세 파일이 바뀌고 두 파일이 새로 생긴다.

| 대상 | 변화 |
|---|---|
| `agents/steelman-builder.md` | 역할 = 양쪽 케이스를 같은 기준으로 쓰는 분석자. 입력 슬롯 5개(direction · trigger · goal · premises · constraints). 출력 = 대안 → 원안 → 전제 반증 판정 → 추천(kept/refined/switched) → evidence(touches) → repo_claims(path+anchor). `confidence` 삭제 |
| `skills/conducting-interview/references/steelman.md` (신설) | R3 절차 전문 — 전제 도출 · dispatch · 게이트-전 확인 · 4-block · 4값 게이트 · 기록 · 0건 기록 항목 |
| `skills/conducting-interview/SKILL.md` R3 절 | 헤딩 + trigger 3값 + 위 파일 포인터만 남는다 |
| `scripts/skepticism.py` (신설) | §5 skepticism 검사 전부 — `VALID_VERDICTS = (kept, refined, switched, deferred)` · 검토 항목 인식 · 0건 폐쇄 요구 |
| `scripts/check_brief.py` | skepticism 관련 함수가 모듈로 나가고 import + 호출만 남는다 |
| 픽스처 141 · 과거 brief 2줄 · 템플릿 2 · 락 3 | 기계 토큰 `verdict: defended` 이관(kept/refined), neglect 존재락 반전, 새 픽스처 6쌍, 새 스위트 1 |
| `tools/adjudication/check_slots.py` | `(spec-distill:steelman-builder, premises)` 면제 등재, baseline 4→5 |

**바뀌지 않는 것** — 사용자가 게이트를 고른다(C25). builder 의 `tools:` allowlist. bijection A(ST<N>).
brief-direction-reviewer(C13). 개수 상한·티어링·confidence 임계 상향은 쓰지 않는다.

## 1. Context — 왜

현 R3 에는 판정 기준(사용자 goal)이 없고 builder 는 「대안의 강한 옹호자 · 원안의 옹호자 아님」으로
정의돼 있다(F1). 기준 부재와 역할 편향이 함께 근거의 **강도**가 **관련성**을 대체하게 만들고,
방어/전환 이분 어휘가 그 결과를 원장에 굳힌다(C1). Phase 0 표본 판독(brief §0): 8건에서 실질은
전환 3·보완 3·유지 1·불명 1 이었는데 기록은 switched 6·defended 2 였고, 2건에서 builder 가 리포
사실을 틀리거나 사용자가 이미 닫은 경로를 대안으로 냈다 — 그것을 잡은 것은 계약에 없는 orchestrator
의 사후 검증이었다. 사용자의 불만은 오염과 흔들림이다(C20).

이 인터뷰의 R3 자체가 새 계약을 한 번 예행했다(audit §3 ST1): 전제 P1–P4 와 제약을 넘겼고 builder
는 반증 없음 · 보완 추천 · 빠진 전제 P0 을 냈으며 리포 주장 7건이 게이트-전 확인에서 전부 사실이었다.
이 문서의 출력 스키마는 그 예행 출력의 모양을 따른다.

## 2. Goals

- G1: 결정의 기준(사용자 goal)과 핵심 전제가 dispatch 입력에 **명시**되고, 모든 근거가 「어느
  전제에 닿는가」로 라벨된다(C14 · C17 · C23).
- G2: 원안과 대안이 같은 기준 위에서 대칭으로 쓰이고, 판정은 유지/보완/전환/보류 넷 중 하나로
  원장에 남는다(C15 · C22).
- G3: 약하거나 무관한 반론이 확정된 방향(사용자가 답한 것 + seed)을 다시 열지 못한다 — 열쇠는
  핵심 전제 충돌 하나(C14 · C19).
- G4: builder 의 리포 주장과 양성 전제 부착 주장은 게이트 **전에** orchestrator 가 확인하고 그
  결과가 audit 에 남는다(C4 · C24).
- G5: steelman 0건 인터뷰도 「무엇을 검토했고 왜 trigger 가 없었는가」를 남기고서야 skepticism 을
  닫는다(C8 · C26).

## 3. Non-goals

- brief-direction-reviewer 와 reviewing-brief 파이프라인(C13).
- 외부 근거 개수 상한 · 출처 티어링 · confidence 임계 상향(brief ✎ 위임 결정 · C17).
- 새 agent(두 옹호자 설계) — ST1 에서 보완으로 판정.
- 전제를 정면으로 치는 근거의 양을 줄이는 것(C6).
- 게이트-전 확인의 기계화(결정론 스크립트) — §10 R3.
- OQ1–OQ6 을 유추로 닫는 것(C12). 이 문서는 그 여섯을 §12 에 그대로 이월한다.
- 옛 토큰 별칭(ⓔ) — O1.

## 4. Constraints

brief C1–C26 전부가 이 문서의 제약이다. 그중 형태를 직접 정한 것만 여기 옮긴다.

| id | 제약 | 이 문서에서 |
|---|---|---|
| C2 | 전제는 orchestrator 도출 + 게이트 4-block 노출, 별도 확인 라운드 없음 | §6.2 Step 1·3 |
| C3 | P0 명시 · goal 리터럴 · 대안 케이스 선행 | §6.1 스키마 순서, §6.2 Step 1 |
| C4 | 양성 부착 주장만 게이트 전 확인 | §6.2 Step 2 |
| C5 | 비부착 근거 = 라벨 노출 · audit 보존 · 「근거 N 중 부착 M」 계수 · 흡수 | §6.2 Step 3·4 |
| C7 | 출력 순서 대안 → 원안 → 전제 반증 판정 → 추천 | §6.1 |
| C8·C26 | 0건은 §5 기록 항목으로 닫고 check_brief 가 **요구**한다 | §6.2 Step 5 · §6.3 |
| C9 | 리포 주장 = 경로 + 앵커 필수, 줄번호 보조 | §6.1 repo_claims |
| C10 | VALID_VERDICTS 를 kept/refined/switched/deferred 로, 픽스처·과거 brief 이관 | §6.3 · §6.4 |
| C11 | 추천은 나란히, 선택지 순서 고정, Recommended 첫 자리 금지 | §6.2 Step 3 |
| C15 | deferred 는 사람만 고른다 | §6.1 recommendation 열거에 없음 |
| C16 | 전제 목록 반박 허용 | §6.1 `premise_list_challenge` |
| C18 | neglect trigger 제거 | §6.2 trigger · §6.5 L1 |
| C23(S15) | 제약은 user_statements 원문 인용으로 | §6.1 constraints 슬롯 |
| C25 | 게이트 선택은 사용자 | §6.2 Step 3 |

리포 규약: Law 2(builder 도구 표면 불변) · CLAUDE.md 「subagent 발견은 처분을 밝힌다」(dispatch 자리의
**처분** 줄) · Self-narrating artifact 금지(생성 파일에는 지시만, 근거는 CHANGELOG·이 문서에) ·
`plugins/<name>/` 편집엔 같은 커밋에 SemVer bump.

## 5. 실측 사실 F1–F6

이 문서가 서 있는 리포 사실. 전부 이 세션에서 읽었다. 줄번호가 아니라 앵커로 가리킨다.

- **F1** `agents/steelman-builder.md` — `## You are / are not` 에 「You ARE: 대안의 강한 옹호자 …
  You are NOT: … 원안의 옹호자」. 출력 스키마는 `alternative_statement · strongest_case · evidence ·
  weakness_of_current · confidence`. 동작 규칙 5 「confidence < 0.4 면 … 원안 defend 합리적」.
  `input_slots` 는 direction · trigger 둘, kind 모두 `task`.
- **F2** `skills/conducting-interview/SKILL.md` `### R3 — Steelman 의심 게이트 (P17)` — trigger 4값(neglect
  포함), 게이트 3값(방어/전환/보류), `verdict ∈ {defended | switched | deferred}`, ST<N> bijection A.
  파일 길이 408줄. `## 종료` 절차는 이미 `references/finishing.md` 로 분리돼 있다.
- **F3** `scripts/check_brief.py` — `VALID_VERDICTS = ("defended", "switched", "deferred")`,
  `skepticism_malformed()`(containment: verdict 토큰 · statement ≥10자 · ST 참조), `bijection_a_errors()`,
  `tried_discarded_ok()`(`기각` 접두 항목 또는 `기각 — N/A` sentinel), `coverage_ledger_failures()`(형식만:
  status `closed` + evidence 비어 있지 않음). steelman 0건은 아무 흔적 없이 통과한다(`tests/test_check_brief.sh`
  T12, 픽스처 `interview-brief-steelman-empty`). §6 검사는 이미 `scripts/section6.py` 로 분리돼 있다.
- **F4** 옛 토큰 분포(리뷰 라운드 1 이 정정) — 기계 토큰 `verdict: defended`: 픽스처 payload 70파일 71줄
  (`st-orphan-payload` 2줄) · 과거 brief payload **2줄**(08-16 ST1 · 08-22 ST1) · 이 브랜치 brief ST1 1줄 · 브리프 템플릿
  §5 예시 1줄 · `tests/test_check_brief.sh` sed 패턴 1줄. ledger evidence 「steelman defended」: 픽스처 audit 71.
  그 밖의 `defended` 는 **산문·verbatim 원문**이다 — 과거 audit 6줄(`verdict=defended`, 「사용자 판정: `defended`」, 프로세스
  로그) · 이 브랜치 audit 14줄(builder verbatim repo_claims anchor · Phase 0 표본 표 · 「실질 보완, 어휘 부재로 defended」) ·
  `check_brief.py` 의 `VERDICT_CLAUSE_RE` 주석. brief §5 의 「픽스처 10건」과 이 문서 초판의 「과거 brief 7파일 8줄」은
  둘 다 틀렸다 — 이 수가 맞다.
- **F5** 락 — `tests/test_conducting_interview_stage.sh` 가 `r3_block` 을 `$SKILL` 에서 awk 로 뜨고
  `coverage-mapper neglect` **존재**를 GREEN 조건으로 잠근다. 같은 스위트는 `references/*.md` 를 `ls` 로
  도출해 코퍼스에 자동 편입한다(`CI_FILES`). `tests/test_steelman_builder_scope.sh` 는 `verbatim|약화.*금지|
  편집.*금지` 존재를 요구한다.
- **F6** `tools/adjudication/check_slots.py` — `FORBIDDEN_KINDS` 에 `orchestrator_framing`(「오케스트레이터가
  직접 쓴 산문 종합」), `EXEMPT_SLOTS` 4건(각 C6(1) 사유), `EXEMPT_SLOTS_BASELINE = 4`,
  `shared/tests/test_agent_input_slots.sh` 가 총수 > baseline 이면 RED. `ALLOWED_KINDS` 는 `task · artifact ·
  same_origin_history · repo_context`. dispatch 짝 검사는 `skills/**/*.md` 를 글롭한다.

## 6. 설계

### 6.1 T1 — steelman-builder 페르소나

**역할 문장(첫 줄).** "You are the steelman-builder. You are responsible for writing the strongest case for
the alternative *and* for the current direction against the same criterion (the user's goal), judging whether
any evidence refutes a stated core premise, and recommending kept / refined / switched. You are NOT
responsible for deciding direction, for writing files, or for advocating one side."

**You are / are not.** ARE: 양쪽 케이스를 같은 기준으로 쓰는 독립 분석자 · 전제 반증 판정자 · 전제 목록
반박자 · prior-art 발굴자. NOT: 파일 작성자(Write/Edit 물리 차단) · 방향 결정자 · **어느 한 편의 옹호자**.

**frontmatter.** `tools: Read, Grep, Glob, WebSearch, WebFetch` · `model: inherit` · `cost_class: variable`
불변. `description` 의 trigger 열거에서 neglect 삭제, 「build the STRONGEST case for an alternative」를
「build the strongest case for both the alternative and the current direction against the user's goal」로.

**input_slots.**

| tag | var | kind | 내용 |
|---|---|---|---|
| direction | SUSPECT_DIRECTION | task | 의심 방향 한 문장 |
| trigger | TRIGGER | task | enum 3값 — landscape 모순 / anti-pattern / 제약 충돌 |
| goal | GOAL | artifact | 사용자 goal 의 **원문** — 아래 우선순위(§6.2 Step 1)로 고른 S<N> 인용 |
| premises | PREMISES | orchestrator_framing | P1..Pn — orchestrator 도출. T7 에서 면제 등재 |
| constraints | CONSTRAINTS | artifact | state `user_statements` 원문 전량(D1) |

goal·constraints 가 `artifact` 인 근거: 사용자가 쓴 원문 블록이다(F6 의 ⓑ 분류). premises 가
`orchestrator_framing` 인 근거: 정의상 orchestrator 의 종합이고, 이 agent 의 과업(반증 판정 + 목록 반박)이
바로 그 목록을 대상으로 한다 — 다른 값을 넣으면 builder 가 자기 전제를 세우고 그것을 치게 된다.

**출력 스키마(순서 = C7).**

```yaml
case_for_alternative:
  statement: "<대안 한 문장>"
  strongest: "<사용자 goal 기준으로 대안이 이기는 케이스>"
case_for_current:
  strongest: "<같은 기준으로 원안이 이기는 케이스>"
premise_refutation:
  hits: [P2]                 # 빈 배열 허용 = 반증 없음
  why: "<hit 마다: 어느 근거가 어느 전제 문장과 어떻게 충돌하는가>"
premise_list_challenge: "<전제 목록의 결함·빠진 전제 — 없으면 「없음」과 그 이유>"
recommendation: kept | refined | switched      # deferred 는 게이트에서 사람만(C15)
refined_takes: "<refined 일 때 원안에서 취하는 것>"   # refined 가 아니면 생략
refined_drops: "<refined 일 때 버리는 것 — R4 기각 코퍼스로>"
evidence:
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: [P1]            # 빈 배열 = 비부착 (라벨 노출·계수, C5)
repo_claims:
  - path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"   # 필수(C9)
    line: 123                            # 보조·선택
    claim: "<주장>"
    touches: [P1]                        # evidence 와 같은 규칙 — 빈 배열 = 비부착
```
`premise_refutation.hits` 의 `why` 는 근거를 `evidence[].url` **또는** `repo_claims[].path+anchor` 로 지목한다 — 리포 사실만으로
성립하는 반증도 있다.

**동작 규칙.**
1. read-only(불변).
2. 외부 주장은 `evidence[].url` 필수(불변).
3. **verbatim 계약** — 출력 전체를 conducting-interview 가 약화·편집 없이 audit §3 에 남긴다. 스스로
   hedge 하지 않는다. (락 어휘 `verbatim|약화.*금지|편집.*금지` 유지, 대상이 출력 전체로 넓어짐.)
4. `premise_refutation.hits` 가 비어 있지 않으면 `why` 는 hit 마다 근거 → 전제 문장 지목을 갖는다.
   지목 없는 hit 은 내지 않는다.
5. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 를 갖는다. 빈 배열은 허용이고 거짓 부착보다 낫다 — 부착은
   orchestrator 가 확인한다.
6. `repo_claims[]` 는 `path` + `anchor` 없이 내지 않는다.
7. 한 방향당 1회(불변).
8. `recommendation: refined` 면 `refined_takes` · `refined_drops` 둘 다 채운다.

**삭제.** `confidence` 필드와 「confidence < 0.4 면 대안 약함 명시」 규칙(O3). 「사용하지 않는 경우」의
neglect 관련 문구.

**Self-narrating 금지.** 이 파일에는 「왜 바뀌었는가」를 쓰지 않는다 — 근거는 CHANGELOG 와 이 문서.

### 6.2 T2 — R3 절차 `references/steelman.md`

SKILL.md 의 `### R3 — Steelman 의심 게이트 (P17)` 절은 세 줄만 남는다: 헤딩 · trigger 3값 한 줄 ·
「절차 전문은 `references/steelman.md`」 포인터. 아래는 그 파일의 내용이다. 파일은 지시만 담는다.

**trigger.** landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 한 줄 추가: 「커버리지 공백은
R3 대상이 아니다 — probe 질문으로 간다(coverage-mapper 블록)」.

**Step 1 — dispatch 재료 도출 (orchestrator).**
- 핵심 전제 P1..Pn — R1 문제정의·goal 과 그때까지의 `user_statements` 에서 도출. 각 전제 뒤에 근거
  S<N> 을 적고, 적을 수 없으면 「orchestrator 도출」로 표기한다. 개수 상한 없음.
- goal — 사용자 원문에서 고른다(항상 artifact). 규칙: **goal 내용을 담은 사용자 발화 중 가장 최근 것**(S<N> 인용). seed
  S1 의 goal 문장은 그 후보 중 하나이며 더 늦은 발화가 goal 을 고쳤으면 그쪽이 이긴다. 후보가 없거나(확인 발화가 「맞아」류
  동의문뿐), 후보 둘이 서로 충돌하면 orchestrator 는 R3 dispatch **전에** 한 probe 로 goal 한 문장을 사용자에게 받아(4-block
  질문) 그 답 원문을 쓴다. 어느 S<N> 을 골랐는지 audit §3 dispatch 입력에 적는다. orchestrator 가 쓴 재구성 문장은 어떤
  경우에도 goal 슬롯에 넣지 않는다(R6).
- constraints — state `user_statements` 전량 원문.
- dispatch:
  ```
  Agent({ description: "Steelman both cases", subagent_type: "spec-distill:steelman-builder",
          prompt: "의심 방향: <direction>${SUSPECT_DIRECTION}</direction>. trigger: <trigger>${TRIGGER}</trigger>.
  사용자 goal(원문): <goal>${GOAL}</goal>. 핵심 전제: <premises>${PREMISES}</premises>.
  사용자가 지금까지 말한 제약(원문 전량): <constraints>${CONSTRAINTS}</constraints>.
  양쪽 최강 케이스를 같은 기준으로, 전제 반증 판정과 추천을." })
  // **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
  ```
- 한 방향당 1회(AP16). Web kill switch 확인은 dispatch 직전(기존 문구 유지).

**Step 2 — 게이트-전 확인 (orchestrator, Read/Grep).**
- `repo_claims` 전 항목: 경로 실재 → 앵커 실재 → 주장이 그 자리와 맞는가. 결과 ∈ {확인, 반증, 미확인}.
- **양성 부착 주장 전부**(C4): `evidence[]`·`repo_claims[]` 중 `touches` 가 비어 있지 않은 항목마다 `claim` 을 지목된 전제
  문장과 대조한다(repo_claims 는 위 경로·앵커 확인을 먼저 통과한 것만). 결과 ∈ {확인, 반증}. `premise_refutation.hits` 는 그 부분집합(부착 중 「충돌」을 주장하는 것)이라 같은
  대조 안에서 「충돌인가」까지 본다. 음성(`touches` 빈 배열)은 확인하지 않는다.
- 「근거 N 중 부착 M」의 M 은 **확인을 통과한 부착**만 센다. 반증된 부착은 `[부착 주장 반증]` 라벨로 노출되고 M 에 들지
  않는다(N 에는 든다).
- 결과는 audit §3 `#### ST<N>` 블록의 「**게이트-전 확인**」 소절에 주장별 한 줄로 남는다(O4).
- 반증된 항목은 4-block 에서 빼지 않고 「반증됨」 라벨을 단다. orchestrator 는 verdict 를 대신 내지 않는다.

**Step 2.5 — 재검토 자격 판정 (G3 의 실행 지점).** 확인을 통과한 `hits`(전제 충돌) 개수로 둘 중 하나를 4-block 「막힌 결정」 첫
줄에 적는다:
- 충돌 ≥1 → `재검토 열림 — 전제 P<n> 충돌 확인 <k>건`. 4-block 은 아래 Step 3 그대로.
- 충돌 0(hits 가 비었거나 전부 반증) → `재검토 사유 없음 — 확인된 전제 충돌 0건`. 게이트는 **그대로 띄운다**(C25 — 선택은 언제나
  사용자) 단, 「추천 답안」의 orchestrator 줄은 유지 또는 보완 중 하나여야 하고 builder 추천이 switched 면 그 옆에
  `[전제 충돌 없음]` 라벨이 붙는다. 이 상태에서 사용자가 전환을 고르면 그것은 근거-발동 재검토가 아니라 **사용자 override** 다 —
  §5 항목 끝에 `— 사용자 override(전제 충돌 0)` 를 붙이고 audit §3 에도 같은 문구를 남긴다. 봉쇄는 추천·라벨 층에 있고
  선택지를 제한하지 않는다(OQ4 · P23).
- `premise_list_challenge` 가 빠진 전제나 틀린 전제를 지목하면 orchestrator 는 그것을 「막힌 결정」에 그대로 보이고, 사용자가
  받아들이면 전제 목록을 고쳐 audit §3 에 적는다(ST1 의 P0 이 이 경로였다). 목록 수정 자체는 재검토를 열지 않는다 — 고친 전제에
  닿는 확인된 충돌이 있어야 연다. 같은 ST 안에서 재dispatch 는 하지 않는다(한 방향 1회).

**Step 3 — 4-block 제시.**
- 현재 이해: 의심 방향 + trigger.
- 막힌 결정: Step 2.5 의 자격 판정 한 줄 → 전제 목록 P1..Pn **그대로**(C2) + builder 의 `premise_list_challenge` 원문.
- 추천 답안: 두 줄 나란히 — 「builder: <recommendation>」 / 「orchestrator: <의견>」(C11). 아래에
  `case_for_alternative` · `case_for_current` verbatim. evidence 는 항목마다 `[부착 P<n>]` 또는 `[비부착]`
  라벨, 반증된 것은 `[반증됨]` 추가. 마지막 줄 「근거 N 중 부착 M · 리포 주장 K 중 확인 J」(C5) — N·M 은 `evidence[]`, K·J 는
  `repo_claims[]` 로 따로 센다.
- 질문: `AskUserQuestion` 선택지 **고정 순서** 유지 / 보완 / 전환 / 보류. `(Recommended)` 라벨 없음.

**Step 4 — 기록.**
- payload §5 항목은 **사용자가 고른 verdict 별로** 형식이 정해지고 builder 추천과 무관하다:
  - kept: `- 기각 — <대안 statement> → <이유> — verdict: kept — ST<N> — 부착 M/N`
  - switched: `- 기각 — <원안> → <이유> — verdict: switched — ST<N> — 부착 M/N`
  - refined: `- 기각 — <버림> → <이유> — verdict: refined — ST<N> — 부착 M/N`. 「버림」은 builder 추천이 refined 였으면
    `refined_drops` 에서, 아니면(builder 는 kept/switched 를 냈는데 사용자가 보완을 고름) 게이트 **직후** orchestrator 가
    `AskUserQuestion` 1회(자유 텍스트)로 취함/버림을 받아 그 원문을 S<N> 으로 기록하고 그 「버림」을 쓴다(O2).
  - deferred: `- 보류 — <대안 statement> → §3 OQ<k> — verdict: deferred — ST<N> — 부착 M/N`. 접두가 `보류` 인 이유:
    아무것도 버리지 않았으므로 R4 기각 계수(`tried_discarded_ok`)에 들면 안 된다. `verdict:` 를 가지므로 skepticism
    verdict 항목으로는 계수되고 bijection A 에도 든다. §3 OQ 박제는 기존대로.
- audit §3 `#### ST<N> — <요지>` 블록 순서: dispatch 입력(goal S-id · 전제 목록 · 제약 S-id 범위) →
  builder 출력 verbatim → 게이트-전 확인 → 사용자 선택 S<N>.
- bijection A 불변.

**Step 5 — steelman 0건으로 skepticism 을 닫을 때 (C8 · C26).**
payload §5 에 `검토 —` 접두 항목 하나:
`- 검토 — steelman 0건: 검토한 방향 <N>개 · 전제 <P1..Pn> · trigger 후보 <무엇을 봤는가> → 기각 이유 <왜 trigger 가 아닌가>`.
접두가 `기각` 이 아닌 이유: R4 기각 계수에 섞이면 안 된다. coverage 원장 `floor:skepticism` evidence 는 이
항목을 가리킨다. check_brief 가 요구한다(§6.3).

**Web 부재 강등.** 기존 문구 유지. 수동 게이트 어휘만 4값.

**Law 2 경계.** 기존 문단 유지(steelman 은 Law 1급 의례).

### 6.3 T3 — `scripts/skepticism.py` 모듈

**경계(확정).** skepticism.py 는 check_brief 를 import 하지 않는다. 의존 방향은 `check_brief → skepticism` 하나다.
모듈은 **이미 잘린 입력**만 받는다 — payload §5 의 entry 줄 목록(`entries: list[str]`, check_brief 의 `section5_entries()`
가 자른 것)과 audit §3 텍스트(`audit_sec3_text: str`, check_brief 의 `_section_text(audit, "3", "Steelman 원문")` 이 자른 것).
절 자르기·불릿 관례는 check_brief 에 남는다.

옮겨가는 것: `VALID_VERDICTS` · `VERDICT_CLAUSE_RE` · `ST_HEADING_RE` · `ST_REF_RE` · `URL_RE` · `_strip_bullet` ·
`verdict_entries` · `skepticism_malformed` · `bijection_a_errors`. `URL_RE` 와 `_strip_bullet` 은 check_brief 의 다른 검사도
쓰므로 check_brief 가 `from skepticism import URL_RE, strip_bullet` 로 **다시 들여온다**(정의는 한 곳).

시그니처(L6 이 잠근다):
```python
verdict_entries(entries) -> list[str]
review_record_entries(entries) -> list[str]
skepticism_malformed(entries) -> list[str]        # 기존 검사, 입력만 entries 로
review_record_malformed(entries) -> list[str]     # 검토 항목 네 토큰 containment
skepticism_closure_ok(entries) -> bool            # verdict ≥1 or 형식 통과 검토 ≥1
bijection_a_errors(entries, audit_sec3_text) -> list[str]
```
`gate()` 에는 위 함수 호출과 실패 문자열 조립만 남는다. `skepticism` 서브커맨드는
`{"malformed": skepticism_malformed(...), "review_records": review_record_entries(...), "review_malformed": review_record_malformed(...)}`
를 낸다.

새로 생기는 것:

```python
VALID_VERDICTS = ("kept", "refined", "switched", "deferred")
REVIEW_RECORD_RE = re.compile(r"^[-*]\s*검토\s*—\s*steelman\s*0건", re.IGNORECASE)
REVIEW_RECORD_TOKENS = ("검토한 방향", "전제", "trigger 후보", "기각 이유")

```
(시그니처는 위 경계 절.)

`gate()` 추가 실패 문자열: `"§5 skepticism 기록 0건 (verdict 항목도 검토 항목도 없음)"` ·
`"malformed §5 검토 entries: <n>"`. `tried_discarded_ok()` 는 `검토` 접두를 세지 않는다(변경 없음 — 접두가
다르므로 자연히 제외되나 AC12 가 그 사실을 잠근다).

`skepticism` 서브커맨드 출력에 `review_records` 키 추가.

### 6.4 T4 — 토큰 이관

바뀌는 토큰은 하나(`defended → kept`)와 추가 하나(`refined`)다. `switched` · `deferred` 는 그대로.

이관 대상은 **기계 토큰**이다. 산문과 verbatim 원문은 시점 기록이라 건드리지 않는다(§6.1 규칙 3 과 같은 이유).
한 스크립트(`$CLAUDE_JOB_DIR/tmp` 의 일회용, 리포에 남기지 않음)로 **별도 커밋** 1개. **이 커밋은 `check_brief.py` 의
`VALID_VERDICTS` 한 줄(`defended`→`kept`, `refined` 추가)을 함께 바꾼다** — 그러지 않으면 이관 커밋 시점에 GREEN 기대 픽스처
~60개가 옛 어휘의 검증기에서 `no-verdict` RED 가 된다(순서를 뒤집어도 대칭). 토큰 집합과 그 집합을 쓰는 데이터는 한 커밋에
움직여야 매 커밋 스위트가 clean 이다. 모듈 추출(§6.3)은 그 다음 설계 커밋에서 그 줄을 옮긴다.
- 픽스처(역사가 아니다): payload 70파일의 `verdict: defended` → `verdict: kept`, audit 71파일의 evidence `steelman defended`
  → `steelman kept`. 템플릿 §5 예시 줄, `tests/test_check_brief.sh` sed 패턴도 같이.
- 과거 brief payload 기계 토큰 2줄(08-16 ST1 · 08-22 ST1): 산문을 읽고 `kept` 또는 `refined` 를 골라 적고 줄 끝에
  `(이관 2026-09-06)` 를 붙인다(D5). 해당 audit 의 산문(`verdict=defended` 등)은 두고, audit §5 프로세스 로그에 이관 한
  줄을 append 한다.
- 이 브랜치 brief ST1 은 `verdict: refined`(D5 — 사용자가 「보완」으로 판정했고 어휘가 없어 defended 로 적혔다). audit §3
  ST1 의 「payload §5 는 defended」 문장은 그대로 두고 같은 방식으로 로그 한 줄.
- **완료 판정(AC14)은 기계 «형태»로 좁힌다**: 정규식 `— verdict: defended —`(양쪽 em dash 포함 — §5 항목 줄의 실제 모양)로
  `plugins/spec-distill` · `docs/superpowers/interview` 를 grep 해 아래 제외 밖에서 0. 산문 줄(예: 이 브랜치 audit 의
  `verdict: defended|switched|deferred`)은 이 형태가 아니라 자연히 빠진다. 제외는 **grep 범위 안에서만** 도출 — ⑴
  `tests/fixtures/*verdict-defended*`(옛 토큰 RED 픽스처) ⑵ `plugins/spec-distill/CHANGELOG.md`. 그 밖의 `defended` 는 AC14 대상이
  아니다.
- **과거 brief 는 게이트 대상이 아니다.** `check_brief.py gate` 는 현재 세션의 payload 에만 돈다(reviewing-brief 진입·수정 라운드).
  그래서 새 폐쇄 규칙(verdict ≥1 또는 검토 ≥1)이 steelman 0건 과거 brief(`2026-09-01-adjudication-topology-interview.md` ·
  `2026-09-01-seam-and-adjudication-interview.md`, verdict 0건)를 RED 로 만들 수 있어도 그 문서들에 `검토 —` 항목을 append 하지
  않는다 — 시점 기록이다. 이 PR 이 게이트를 돌리는 과거 문서는 이 브랜치 brief 하나(AC18)뿐이고 그것은 ST1 이 있어 verdict ≥1 이다.
- 개념 별칭 스윕은 **R3 어휘**에만 한다: `references/steelman.md` · 페르소나 · 브리프 템플릿 §5 verdict 예시의 「방어」→「유지」,
  「defend」→「keep」. **R4 sentinel `기각 — N/A — 전부 first-time defend+lock` 은 R4 어휘라 제외**한다(SKILL R4 행 · 템플릿 §5
  주석 · `na-tried` 계열 픽스처 · `REJECT_NA_RE`).

별칭 없음(O1).

### 6.5 T5 — 락·픽스처

| id | 락 | 변화 |
|---|---|---|
| L1 | `test_conducting_interview_stage.sh` r3_block | 추출 대상을 `references/steelman.md` 로. 그 파일의 **첫 헤딩은 `### R3 — Steelman 의심 게이트 (P17)`** 로 두어 기존 awk 트리거가 그대로 발화하고, **그 뒤로 파일 끝까지 `##`/`###` 헤딩을 두지 않는다**(Step 1~5 는 `####` 또는 굵은 줄) — awk 는 `/^### /{f=0} /^## /{f=0}` 로 다음 헤딩에서 블록을 끊으므로 중간 헤딩 하나가 부재 락을 공허하게 만든다. 이 제약은 AC23 으로 잠근다. `coverage-mapper neglect` **부재** 락으로 반전 + 양성 짝 — trigger 3값 문구(`landscape 모순`·`anti-pattern`·`제약`) 존재 · `검토 — steelman 0건` 존재 · `보류 —` 존재 — 전부 **같은 `r3_block` 변수**에서 잰다 |
| L2 | 같은 파일 `§3 OQ` ×2 · E10 병렬금지 부재 | 새 r3_block 대상으로 그대로. `§[68] OQ` 부재도 그대로 |
| L3 | `test_steelman_builder_scope.sh` | verbatim 어휘 유지. 추가: `confidence` **부재** + 양성 짝 `recommendation` 존재 · 슬롯 태그 5개 존재 · `kind: orchestrator_framing` 이 premises 에만 |
| L4 | `test_check_brief.sh` — `skepticism_closure_ok` 로 RED 가 되는 GREEN 기대 픽스처 | 열거가 아니라 도출: `grep -L 'verdict:' tests/fixtures/interview-brief-*.md`(payload) ∩ 스위트가 GREEN 을 기대하는 것. 2026-09-06 실측 결과: `interview-brief-steelman-empty`(T12) · `interview-brief-na-tried`(T19) 둘 — 각각 `검토 —` 항목 1줄 추가. `interview-brief-empty-tried`(R4) 와 `interview-brief-sec5-no-entries`(U3-T8 우회 루프) 는 이 스위트에서 RED 기대라 교집합 밖 — 갱신하지 않는다. 새 음성 픽스처 `interview-brief-steelman-empty-norecord`(.md + .audit.md) → RED 기대, 실패 문자열 「skepticism 기록 0건」 |
| L5 | 새 픽스처 | `interview-brief-verdict-refined`(GREEN) · `interview-brief-verdict-defended`(옛 토큰 → RED, no-verdict — AC14 제외 집합 ⑴) · `interview-brief-review-record-malformed`(검토 항목에 「기각 이유」 없음 → RED) · `interview-brief-verdict-deferred-hold`(`보류 —` deferred 1건 + `기각` 0건 + N/A sentinel 없음 → RED 「§5 기각 항목 0건」, AC19) · `interview-brief-review-only-no-reject`(`검토 —` 1건 + `기각` 0건 + sentinel 없음 → RED 「§5 기각 항목 0건」, AC12) |
| L6 | 새 `tests/test_skepticism_module.sh` | 모듈 함수 단위. mutation 네 축 — 토큰 삭제(`kept` 제거 → 픽스처 RED) · 추가(`defended` 재추가 → 옛 픽스처 GREEN 으로 돌아감을 RED 로) · 반전(`skepticism_closure_ok` 의 or→and) · 형태변경(`검토` → `검토함`). 양성 대조 필수 |
| L7 | `shared/tests/test_agent_input_slots.sh` | T7 로 GREEN 유지 |
| L8 | `shared/tests/test_dispatch_disposition.sh` | steelman.md 의 dispatch 자리에 **처분** 줄 — 자동 편입 확인 |

### 6.6 T6 — 템플릿·README·CHANGELOG·버전

- `templates/interview-brief-template.md` §5 — 예시 줄 `verdict: kept — ST1 — 부착 M/N` + `검토 — steelman 0건: …` 예시
  줄 + 주석 한 줄(「verdict 항목 0건이면 검토 항목 필수」).
- `templates/interview-audit-template.md` §3 — ST 블록 골격에 「dispatch 입력」·「게이트-전 확인」 소절.
- `README.md` — P11 줄의 steelman 설명을 목적 문장으로 갱신(「의심 방향은 … 대안 steelman 을 통과해야」 →
  「양쪽 케이스를 같은 기준으로 … 전제 충돌만이 재검토를 연다」). Hooks 변경 없음. `test_readme_sync.sh`
  키워드 `steelman-builder` 유지.
- `CHANGELOG.md` — `## [0.54.0] — 2026-09-06` Added(steelman.md · skepticism.py · 슬롯 3 · 토큰 refined · 검토 항목) /
  Changed(페르소나 역할 · R3 게이트 4값 · defended→kept 이관 · check_brief 위임) / Removed(confidence · neglect trigger).
  v0.x 라 deprecation window 면제임을 한 줄로.
- `.claude-plugin/plugin.json` — `0.53.1 → 0.54.0`(O5).

### 6.7 T7 — 슬롯 면제 등재

`tools/adjudication/check_slots.py`:
- `EXEMPT_SLOTS[("spec-distill:steelman-builder", "premises")]` = 「C6(1) 이 agent 의 과업은 «그 전제 목록에 대한»
  반증 판정과 목록 자체의 반박이다 — 대상이 정의상 orchestrator 가 도출한 그 목록이라 대응물이 없다. 다른 값(사용자
  원문)을 넣으면 builder 가 자기 전제를 세우고 그것을 치게 되어 C16 의 목적(원안 저자의 상상력 경계를 물려받지
  않기)을 잃는다. 잔여 위험은 남는다 — 도출이 이미 잃은 전제는 builder 도 못 본다(OQ2). goal·constraints 는 사용자
  원문(artifact)으로 넘겨 이 면제의 범위를 전제 목록 하나로 좁혔다.」
- `EXEMPT_SLOTS_BASELINE = 5` + 주석에 이 문서 경로와 이유.
- 축 전수 스윕 주석의 「`steelman-builder.direction`/`trigger` — ⓔ 가 아니다」 항목: trigger 를 「네 값 중 하나(… / neglect)」로
  적은 부분을 **3값**으로 고치고(C18 뒤 거짓 인용 방지), 그 뒤에 premises(ⓔ, 면제)·goal·constraints(ⓑ) 판정을 덧붙인다.

## 7. Acceptance Criteria

| id | 기준 | 검증 |
|---|---|---|
| AC1 | `agents/steelman-builder.md` 에 `confidence` 토큰 부재, `recommendation` · `premise_refutation` · `premise_list_challenge` · `touches` · `repo_claims` · `anchor` 존재 | L3 |
| AC2 | 같은 파일 `input_slots` 태그 = {direction, trigger, goal, premises, constraints}, premises 만 `orchestrator_framing` | L3 · L7 |
| AC3 | 같은 파일에 「원안의 옹호자」 부재, 「어느 한 편의 옹호자」 존재, `verbatim|약화.*금지|편집.*금지` 존재 | L3 |
| AC4 | `references/steelman.md` 실재, SKILL.md R3 절이 그 파일을 가리킴, r3_block 이 새 파일에서 뜬다 | L1 |
| AC5 | r3_block 에 `coverage-mapper neglect` 부재 · trigger 3값 문구 존재 · `§3 OQ` ≥2 · 병렬금지 문구 부재 | L1 · L2 |
| AC6 | r3_block 에 `유지`·`보완`·`전환`·`보류` 네 어휘와 `kept`·`refined`·`switched`·`deferred` 네 토큰 존재, `defended`·`방어` 부재 | L1 |
| AC7 | steelman.md 의 dispatch 프롬프트가 `<goal>` `<premises>` `<constraints>` 태그를 전달하고 처분 줄을 갖는다 | L7 · L8 |
| AC8 | `scripts/skepticism.py` 실재, `VALID_VERDICTS == ("kept","refined","switched","deferred")`, check_brief.py 에 `VALID_VERDICTS` 정의 부재 | L6 |
| AC9 | verdict 0건 + 검토 0건 payload → gate RED, 실패 문자열 「skepticism 기록 0건」 | L4 |
| AC10 | verdict 0건 + 형식 통과 검토 1건 → gate GREEN(steelman-empty 갱신 픽스처) | L4 |
| AC11 | 검토 항목에 네 토큰 중 하나라도 없으면 RED | L5 |
| AC12 | `검토 —` 항목만 있고 `기각` 항목 0건이면 R4 실패(「§5 기각 항목 0건」)가 여전히 난다 — 검토가 기각을 대신 못 한다 | L5 (`review-only-no-reject`) |
| AC13 | `verdict: defended` 픽스처 → RED(no-verdict), `verdict: refined` 픽스처 → GREEN | L5 |
| AC14 | 이관 뒤 `grep -rn -- "— verdict: defended —" plugins/spec-distill docs/superpowers/interview` 가 §6.4 제외(⑴⑵) 밖에서 0건. 산문 `defended` 는 형태가 달라 대상 아님 | T4 스크립트 출력 |
| AC15 | `check_slots.EXEMPT_SLOTS` 에 premises 항목, 사유가 `C6(1)` 인용과 최소 분량 통과, baseline 5 | L7 |
| AC16 | 템플릿 §5 예시가 새 토큰과 검토 항목 예시를 갖고 `defended` 부재 | grep |
| AC17 | `plugin.json` 0.54.0, CHANGELOG 0.54.0 항목 존재 | grep |
| AC18 | 이 브랜치의 brief 2026-09-05 가 이관(ST1 → refined) 뒤 gate PASS · 완전성 rc 0 | 직접 실행 |
| AC19 | `보류 —` deferred 항목은 skepticism verdict 항목으로 계수되지만 R4 기각으로는 계수되지 않는다 — deferred 1건 + 기각 0건 + sentinel 없음 → RED 「§5 기각 항목 0건」 | L5 |
| AC20 | steelman.md Step 2 가 「touches 비어 있지 않은 evidence 전부」를 확인 대상으로 적고, 「부착 M/N」 정의가 확인 통과분임을 적는다 | L1 grep |
| AC21 | `scripts/skepticism.py` 에 `import check_brief` 부재, check_brief.py 에 `from skepticism import` 존재 | L6 |
| AC22 | steelman.md 에 `재검토 열림` · `재검토 사유 없음` · `사용자 override` 세 문구 존재(Step 2.5) | L1 |
| AC23 | `references/steelman.md` 에서 첫 줄 `### R3 — Steelman` 이후 `^##`/`^### ` 로 시작하는 줄 0 | L1 |

## 8. Files to Modify

**수정** — `plugins/spec-distill/agents/steelman-builder.md` · `plugins/spec-distill/skills/conducting-interview/SKILL.md` ·
`plugins/spec-distill/scripts/check_brief.py` · `plugins/spec-distill/templates/interview-brief-template.md` ·
`plugins/spec-distill/templates/interview-audit-template.md` · `plugins/spec-distill/README.md` ·
`plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json` ·
`plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `plugins/spec-distill/tests/test_steelman_builder_scope.sh` ·
`plugins/spec-distill/tests/test_check_brief.sh` · `plugins/spec-distill/tests/fixtures/interview-brief-steelman-empty.md` ·
`plugins/spec-distill/tests/fixtures/interview-brief-na-tried.md` · L4 도출이 더 찾는 GREEN 기대 verdict-less 픽스처 ·
`tools/adjudication/check_slots.py` · 픽스처 141 파일 · 과거 brief payload 2 파일(+ 그 audit 2 에 로그 append) · 이 브랜치 brief/audit(이관 커밋).

**신설** — `plugins/spec-distill/skills/conducting-interview/references/steelman.md` · `plugins/spec-distill/scripts/skepticism.py` ·
`plugins/spec-distill/tests/test_skepticism_module.sh` · 픽스처 6쌍(`steelman-empty-norecord` · `verdict-refined` ·
`verdict-defended` · `review-record-malformed` · `verdict-deferred-hold` · `review-only-no-reject`, 각 `.md` + `.audit.md`).

**건드리지 않음** — `agents/brief-direction-reviewer.md` · `skills/reviewing-brief/**` · `hooks/**` · `scripts/section6.py`.

## 9. Verification Plan

1. **baseline** — 착수 전 `plugins/spec-distill/tests/*.sh` · `shared/tests/test_agent_input_slots.sh` ·
   `shared/tests/test_dispatch_disposition.sh` 를 돌려 파일별 **실패 줄 수**를 기록한다(rc 만이 아니라).
2. **이관 커밋**(토큰 집합 + 픽스처·템플릿·sed + 과거 2줄 + 이 브랜치 ST1) 뒤 같은 스위트 — **새 RED 0**. 변하는 것은
   `interview-brief-verdict-no-token` 류 RED 기대 픽스처의 실패 문자열이 아니라 GREEN 기대 픽스처가 그대로 GREEN 인 것이다. T12
   는 이 커밋에서 변하지 않는다(그 픽스처엔 verdict 토큰이 없다). 커밋마다 «기대 RED 파일·줄 수»를 적어 baseline 과 비교한다.
3. **설계 커밋** 뒤 같은 스위트 — 새 RED 0(L4 의 도출 목록이 전부 갱신됐다는 뜻), 새 GREEN 은 L1·L3·L4·L5·L6 항목.
4. **mutation** — L1 (`neglect` 재삽입 → RED) · L3 (`confidence:` 재삽입 → RED) · L4 (검토 항목 삭제 → RED) ·
   L6 네 축. 각 mutation 은 변이 전 커밋 후 `git checkout --` 로 복원. 양성 대조(정상 상태 GREEN) 를 같은 실행에서 확인.
5. **AC18** — 이 브랜치의 brief 에 `check_brief.py gate` · `check_verbatim_coverage.py`.
6. **입력 슬롯 짝** — `shared/tests/fixtures/adjudication/run_slots.py` 출력에서 steelman-builder 의 5 태그가 `undelivered`
   0 · `forbidden_kind` 0(면제) · `exempt_total=5` `exempt_baseline=5`.
7. **수동 e2e(선택, U3)** — 다음 인터뷰에서 R3 가 새 절차로 한 번 돌아 audit §3 블록이 §6.2 Step 4 모양으로 남는지.

## 10. Rejected Alternatives

- **R1 옛 토큰 별칭 one-minor(ⓔ)** — CHANGELOG 가 두 번 「spec-distill 은 v0.x 라 one-minor deprecation window 면제
  → 즉시 제거」를 기록했다(v0.16.0 · v0.17.0). C10 도 이관을 전제한다. → O1.
- **R2 제자리 편집** — SKILL.md 가 ~460줄, check_brief.py 가 ~1200줄이 된다. `finishing.md` · `section6.py` 두 선례가
  같은 플러그인에 있다. → D3.
- **R3 `check_repo_claims.py`(경로+앵커 grep 스크립트)** — 의미 절반(근거가 전제를 치는가)은 기계화 불가, ST1 은 7/7 을
  손으로 확인했고, 하니스 무게 규칙. 형해화 위험은 O4(audit 기록)가 다르게 막는다.
- **R4 제약 「요지」 전달(C23 원안)** — F6 의 금지 kind 에 해당해 면제 2건이 필요하고, prober FM4(조건부 발화의 무조건화).
  → D1.
- **R5 0건은 인식만(현행 T12 유지)** — 원장 행은 형식 검사라 검토 흔적이 남지 않는다. → D2.
- **R6 goal 을 orchestrator 재구성 문장으로 전달** — 금지 kind. 사용자가 그 재구성을 확인한 발화 원문이 같은 정보를 artifact 로
  준다.
- **R7 검토 항목을 `기각 —` 접두로** — R4 기각 계수에 섞여 「기각 0건」 sentinel 을 헛통과시킨다.
- **R8 두 옹호자 agent** — ST1 보완 판정(brief §5 첫 항목).

## 11. 재결정 기록

| id | 무엇 | 원안 | 재결정 | 근거 | 기록 |
|---|---|---|---|---|---|
| D1 | 제약 전달 형태 | C23 「요지」 | user_statements 원문 인용 | F6 금지 kind + 면제 baseline, FM4 | brief C23 갱신 · S15 · §5 기각 |
| D2 | 0건 게이트 | 인식만(현행) | 기록 항목 **요구** | 원장 형식 검사만, R3 「un-challenged … 확정 후보 불가」 | brief C26 신설 · S16 · §5 기각 |
| D3 | 구조 | — | 모듈 분리 | finishing.md · section6.py 선례 | S17 |
| D4 | 리뷰 라운드 | 라우팅 표(needs_revise → 재dispatch, cap 5) | 라운드 1 수정 뒤 재리뷰 **1회만** 더, 그 결과와 무관하게 Human Gate | 사용자가 비용을 정함(P17); 이 문서의 수정 라운드가 새 결함을 낸 이력이 1회 더의 근거 | S18 |
| D5 | 이관 값 | 기계 치환 `defended→kept` | 기계 토큰만, 이 브랜치 ST1 은 `refined`, 과거 2줄은 산문 읽고 판정 | 리뷰 라운드 1: 기계 치환이 ST1 에 이 설계가 잡으려는 양극단화를 다시 새긴다 | S18 |
| O1 | ⓔ 별칭 | 미확정 | 채택 안 함 | CHANGELOG 선례 2건 | 되돌리려면 「별칭 두자」 |
| O2 | ⓐ 취함/버림 | 미확정 | 채택 | compromise-effect 대응 후보, 반대 근거 없음 | 되돌리려면 「취함/버림 빼」 |
| O3 | ⓓ confidence 폐지 | 미확정 | 채택 | C17 은 임계 상향만 금지, recommendation 이 이산값으로 대체 | 되돌리려면 「confidence 남겨」 |
| O4 | ⓒ 확인 기록·반증 라벨 | 미확정 | 채택 | C24 + brief §5 「확인했다 한 줄」 형해화 위험 | 되돌리려면 「확인 기록은 빼」 |
| O5 | 버전 | — | minor 0.54.0 | 새 파일 2 · 새 슬롯 3 · 새 토큰 | — |

brief 의 「픽스처 10건」(§5 기각 항목)과 이 문서 초판의 「과거 brief 7파일 8줄」은 F4 로 정정된다 — 사실 정정이고 C10 의 방향은
같다. brief audit §1 의 derived 행 `verdict_machine_vocab` 은 orchestrator 가 인터뷰 중 「옛 토큰 별칭 · 과거 원장 이관 안 함」으로
정했다고 적고 있는데, 그것은 S11(사용자: 「과거 brief 원장 이관 필요」)과 어긋난 orchestrator 메모다 — 이 문서는 S11·C10·D5 를
따르고 그 메모는 효력이 없다.

## 12. 위험과 brief §5 대응의 이월

brief §5 의 「대응」이 적힌 위험은 전부 이 문서에 실렸다.

| brief 위험 | 이 문서의 대응 |
|---|---|
| P0 분리가 독립을 보장한다는 가정(OQ1) | dispatch 컨텍스트 분리는 유지(P0). 프레임 공유·sycophancy 는 **해결하지 않는다** — OQ1 그대로 이월 |
| 한 builder 양쪽 = 대칭이라는 가정 | 대안 케이스 선행(C7) + `premise_list_challenge` 필수 |
| 전제 도출 신뢰성(OQ2) | `premise_list_challenge` 필수 + 게이트 노출(C2). 오류율 미측정 — OQ2 이월 |
| touches 가 「채워야 통과하는 칸」 | 양성만 확인(C4), 빈 배열 허용을 규칙 5 로 명시 |
| 결과를 치는 반증이 비부착으로 빠짐(OQ4) | 라벨 노출 + 사용자 선택지 무제한. OQ4 이월 |
| 「보완」 중간 착지 | 순서 고정·추천 비승격(C11) + 취함/버림(O2) |
| trigger 제조 / sentinel 제조(OQ5) | 검토 항목은 「무엇을 봤고 왜 아닌가」를 요구해 빈 도장이 아니다. 제조 여부는 측정 불가 — OQ5 이월 |
| 요지 전달의 무조건화 | D1 로 닫힘 |
| repo_claims 확인 형해화 | O4 주장별 기록 |
| 페르소나 락 충돌·이중 상태 | L3 어휘 유지 + 대상 확장을 이 문서와 락 주석 양쪽에 같은 문장으로 |
| neglect 존재락 | L1 반전 + 양성 짝 |
| 어휘 결합 표면 한 곳만 고침 | T4 를 스크립트 1개·커밋 1개로, AC14 의 0건 grep |

**이 문서가 새로 보는 위험.**
- 모듈 분리 시 순환 import — §6.3 이 의존 방향을 `check_brief → skepticism` 하나로 확정해 닫았다(AC21).
- 면제 baseline 을 올리는 첫 커밋 — 「전부 면제로 넣으면 (b) 축이 장식」이라는 그 락의 주석이 이 커밋을 가리킬 것이다. 사유
  문장이 그 우려에 답하도록 §6.7 에 범위 축소(goal·constraints 는 artifact)를 명시했다.
- `검토 —` 접두가 미래에 다른 뜻으로 쓰일 때 검사가 오탐 — `steelman 0건` 리터럴을 정규식에 포함해 좁혔다.
- OQ6(웹 근거 5건 스니펫만) — 이 설계는 그 근거에 의존하지 않는다. 의존하는 것은 리포 실측 F1–F6 과 사용자 결정이다.

## 13. writing-plans 가 정할 미결

- **U2** 픽스처 6쌍의 최소 본문 — 기존 `interview-brief-valid` 계열을 복사해 한 줄만 바꾸는 규약을 따르는지.
- **U3** 수동 e2e 를 이 PR 안에 두는지 다음 인터뷰로 미루는지.
- **U4** 커밋 분할 — 이관 1 · 설계 1 로 최소 둘. 락·픽스처를 설계 커밋에 합치는지 셋으로 나누는지. 브랜치명 `feature/steelman-goal-fit` 정리 시점.

## 14. Metadata

- **작성** 2026-09-06 · brainstorming(architectural) · 세션 `1f5a8290-7b4b-454d-b493-438037a5123f`
- **브랜치** 워크트리 `feature+steelman-goal-fit`(브랜치명 `worktree-feature+steelman-goal-fit` — PR 전 `feature/steelman-goal-fit` 로 정리, U4 와 함께)
- **버전** spec-distill 0.53.1 → 0.54.0 · `tools/adjudication` 은 플러그인 밖(버전 없음)
- **리뷰** Law 2 — 이 문서는 커밋 전에 spec-distill Stop 훅이 `reviewing-spec` 을 dispatch 한다(born 문서는 dispatch 대상에서 제외되므로 커밋은 verdict 뒤)
- **입력 brief** `docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md` (C1–C26 confirmed, S1–S18)
- **리뷰 이력** 라운드 1(2026-09-06): Claude needs_revise(block 1·high 4·medium 3) + codex needs_revise(high 3·medium 1), 10건 전부 수용.
  라운드 2(2026-09-06): Claude needs_revise(high 2·medium 5, 라운드 1 의 8건은 닫힘 확인) + codex needs_revise(high 1·medium 3), 11건 전부
  수용 — Step 2.5(재검토 자격·사용자 override) · repo_claims touches · goal 최신 우선 · 이관 커밋에 VALID_VERDICTS 동반 · AC14 기계 형태 ·
  AC12 픽스처 · AC22·AC23 · 과거 0건 brief 범위 밖. **라운드 2 의 수정은 D4 에 따라 재리뷰되지 않았다** — writing-plans 와 사용자
  검토가 받는다.
