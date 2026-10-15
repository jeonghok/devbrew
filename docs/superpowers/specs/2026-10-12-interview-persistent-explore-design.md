---
name: interview-persistent-explore
type: design
created_at: 2026-10-12
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R1.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R1 — 인터뷰 탐색 개편 · Design

> 인터뷰가 한 번에 닫지 않고, 더 조사해도 결정에 닿는 새 사실이 없을 때까지 조사한다.

승인된 로드맵(S47)의 에픽 R1 이다. 로드맵 전체에서의 자리는 `roadmap.md` 의 `### R1` 블록이고, 이웃
에픽 R2 · R3 · R4 · R6 · R7 과 병렬로 간다(의존 R0 만).

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 조사의 흐름과 멈춤](#1-조사의-흐름과-멈춤)
  - [§2 장치별 처분](#2-장치별-처분)
  - [§3 새 agent 둘](#3-새-agent-둘)
  - [§4 상태 · 환경 변수 · audit 줄](#4-상태--환경-변수--audit-줄)
  - [§5 구조 게이트](#5-구조-게이트)
  - [§6 파일 배치와 락](#6-파일-배치와-락)
  - [§7 위험에 대한 답](#7-위험에-대한-답)
  - [§8 인터페이스](#8-인터페이스)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [결정 기록](#결정-기록) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Handoff Context

- 입력: 에픽 묶음 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R1.md` (원본 brief
  `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 와 로드맵을 거꾸로 가리킴).
- brainstorming 결정: `## 결정 기록` B1~B8. 재결정 1건: 2026-09-22 설계 §F(자격 · 예산 · 면제) — `## 결정 기록` 재결정 절.
- 브랜치 `feature/interview-persistent-explore` · worktree `.claude/worktrees/interview-persistent-explore`.
- 락 지도: brainstorming 중 읽기 전용 탐색으로 만든 장치별 락 목록을 §6 에 옮겼다. 이 문서만 읽고 계획을 쓸 수 있게 줄번호
  대신 파일과 리터럴을 적는다(줄번호는 계획 시점에 다시 잰다).

## Context / Why

사용자는 spec-distill 결과물의 품질 저하가 brief 가 얇은 데서 가장 크게 나타난다고 했고(C1), 그 원인 하나로 인터뷰가
floor 다섯을 한 번 채우면 닫고 조사에 제약이 많아 맥락이 부족한 채 넘어간다는 것을 들었다(S1). 풀 제약으로 조사 장치의
호출 예산과 자격, 사용자 질문 리듬 강제, 조사 subagent 를 정해진 몇 자리에서만 쓰는 것을 지목했다(C3). 멈춤은
「한 번 더 조사해도 결정에 닿는 새 사실이 없을 때」이고 횟수 상한은 안전장치로만 둔다(C4).

지금 인터뷰(`plugins/spec-distill/skills/spec-interview/SKILL.md`)에서 그 제약의 실체는 이렇다 (번호는 묶음 §5):

- coverage-mapper 재호출은 「그 차원에 닿는 열린 결정」이 있어야 하고(자격) 그 위에 `1 + 재개방 합`(예산)이다(RC1).
  blind-spot-prober 도 같고 예산은 `1 + 그 차원 재개방`이다(RC2). 재개방은 충돌 때만 일어나므로 충돌 없는 인터뷰에서
  조사 장치는 사실상 1회다(RC21).
- C44 Dialectic Rhythm Guard: 사용자 답 없는 조사가 3회 이어지면 다음 질문을 사용자 질문으로 강제한다(RC3).
- 레포 조사는 인터뷰 본체만 하고 subagent 자리는 셋뿐이다(RC23).
- 웹 landscape 는 「≥1회 · round 1–2」(RC4), steelman 은 방향당 1회(RC5 · RC67), 되묻기는 같은 주제 2회까지(RC24).
- 종료는 floor 다섯이 닫히면 열리고 포화를 보는 조건이 없다(RC25).
- 문제 재구성 의례 R1 은 「seed 의 문장을 되풀이하는 것은 통과가 아니다」로 사용자 말을 다시 쓰게 한다(RC48) —
  사용자는 이 단계 자체를 제거하라고 했다(C14 · S6).

자격 · 예산 · 면제는 2026-09-22 설계 §F 가 「사용자가 시계다」(라운드는 사용자 답으로만 돈다)를 무한 루프 방지 근거로
정했다(RC16 · RC59). 그 울타리가 지키던 것은 AP16 Unbounded autonomy 다(RC14). 그래서 장치를 걷으면서 같은 요구 —
상한 · 반복 감지 · kill switch — 를 다른 장치로 채운다(«chesterton-fence»).

## Goals

- G1 조사 subagent 를 자격 · 예산 없이 결정에 닿을 수 있을 때마다 부를 수 있다. 첫 호출 필수 자리(하한)는 남는다.
- G2 레포 조사도 subagent 로 할 수 있다 — 새 읽기 전용 `repo-researcher`.
- G3 모델이 스스로 인터뷰를 끝내려면 쓰기 권한 없는 독립 판정자 `saturation-judge` 가 「포화」를 내야 한다(D23).
- G4 조사 subagent 호출이 인터뷰 하나에서 상한(기본 20)에 닿으면 멈추고 사용자에게 연장 · 판정 · 종료를 묻는다. 상한은 환경
  변수로 바꾸고 사용자가 연장한다(D43).
- G5 문제 재구성 단계를 없애고 root_problem 칸을 사용자 원문 인용으로 닫는다(C14).
- G6 리듬 강제 · 되묻기 상한 · steelman 횟수 · 웹 시점 강제를 §2 표대로 제거 또는 수정한다(C3 · D18).
- G7 판정 · 호출 수 · 도달 · 연장이 사용자에게 보이고 R6 이 읽을 자리(audit §2 · state)에 남는다.
- G8 구조 게이트가 포화 판정 없는 종료를 거절한다(Law 1).
- G9 조사를 크게 쓰기 전에 규모를 알린다(C5) — 인터뷰의 첫 조사 subagent dispatch 직전에 한 줄
  `[spec-distill] 이 인터뷰는 조사 subagent 를 최대 <limit>회까지 부른다(웹 포함 · 승인 없이 진행 · 연장은 닿을 때 묻는다).`
  를 낸다. 승인은 묻지 않는다.

## Non-goals

- 압축 규약 · request-framing · seed/brief/설계문서 리뷰 프로필 · brief 템플릿 형식(R2) — `interview-brief-template.md` 를 고치지 않는다.
- 공유 리뷰 엔진 · qg · 다른 플러그인 장치(R2a).
- 번호 인계 · 깊이 검사 · spec-review 묶음 입력(R3), 분해(R4), 화면 표시(R6), 상태 저장 재설계(R7).
- superpowers 파일 · 동작(C25 · C35 · D26).
- 「Phase 0 이 웹을 안 본다」는 사실(RC19)의 변경 — request-framing 은 R2 몫이다.
- 개선을 재는 별도 측정 장치(S32).

## Constraints

- 외부 플러그인을 건드리지 않는다(C25 · C35). 원래 있는 것을 다시 만들지 않는다(C32) — 새 agent 둘은 기존 것이 그 역할을
  못 하는 이유를 `## Rejected Alternatives` 에 적는다.
- 장치는 전부 제거 또는 수정이고 그대로 남는 것은 없다(D15 · D18). 기준은 S10: 비용 · 절감으로만 작동하거나 사용자 결정을
  덮으면 제거, 상한은 공시하고 사용자가 여는 형태로 수정.
- 쓰기 권한 있는 판정자는 판정자가 아니다(Law 2) — 새 agent 둘은 `tools:` allowlist 에 쓰기 · Bash · 웹이 없다.
- 모든 dispatch 자리는 처분 줄을 갖는다(RC18 · CLAUDE.md «subagent 발견은 처분을 밝힌다»).
- `SKILL.md` 자기 줄 수 상한 504(현재 여유 0) — 새 절차는 조건부 reference 로 뺀다.
- AP16: 상한 · 반복 감지 · kill switch 셋이 모두 있어야 한다(RC14).

## 설계

### §1 조사의 흐름과 멈춤

**부르기.** 인터뷰 본체(orchestrator)는 조사 subagent 넷 — `coverage-mapper` · `blind-spot-prober` · `steelman-builder` ·
`repo-researcher` — 을 자격 · 예산 없이 부른다. 부르는 기준은 하나다: 그 호출이 열린 결정을 바꾸거나 새 결정을 열 수 있다고
볼 때. 지금의 필수 자리 둘은 하한이라 남는다 — R1 첫 질문 전 coverage-mapper 1회, blind_spot 칸의 첫 open→in-progress 전이 때
blind-spot-prober 1회. steelman 의 trigger(landscape 모순 · anti-pattern · 사용자 제약 충돌)도 남는다 — 그것은 «언제 부르나»의
조건이지 횟수 상한이 아니다.

**세기와 상한.** 조사 subagent 를 dispatch 할 때마다 `research_dispatches` 의 그 장치 칸을 +1 한다. 합이 `research_limit` 에
닿으면 다음 조사 dispatch **전에** 멈추고 `AskUserQuestion` 1회로 묻는다:

- 「같은 크기만큼 연장」 — `research_limit += DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT`(기본 20). 답은 사용자 발화 S 로 기록한다.
- 「지금 포화 판정으로」 — floor 가 다 닫혔으면 판정자를 부르고, 아니면 남은 floor 를 사용자 질문으로 닫는다.
- 「인터뷰 종료」 — 기존 「나가는 문」(사용자-승인 박제)으로 간다.

도달 순간에 한 줄을 낸다: `[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.` 판정자 호출은
세지 않는다(B4). 인터뷰 본체의 직접 `Read`/`Grep`/웹 검색도 세지 않는다(B4). 그쪽을 묶는 것은 라운드 규약이다 — 라운드마다
`AskUserQuestion` 1회로 사용자에게 질문 하나를 내고 답을 받아야 다음 라운드가 돈다. 본체 직접 조사는 그 라운드의 «지금 이해»에 싣기
위한 것이라, 한 라운드 안의 직접 조사가 끝나면 질문이 나가고 턴이 사용자에게 간다. 그래서 floor 가 닫히기 전 구간의 시계는 여전히
사용자 답이다(RC59 의 근거가 이 구간에는 그대로 남는다). 대신 보이게 한다: 그 라운드의 «지금 이해» 한 줄에 그 라운드의 본체 직접
조사 수(`research_log` 의 `device: orchestrator` 항목 수)를 조사 호출 `<n>/<limit>` 과 함께 싣는다(D1.3).

**멈춤 — 이중 종료(B5).** floor 다섯이 사용자 답으로 모두 `closed` 가 되면 brief 작성으로 가기 **전에** `saturation-judge` 를
부른다. 판정자는 D23 의 기준 「조사를 더 해도 열린 결정을 바꾸거나 새 결정을 여는 사실이 없음」으로 둘 중 하나를 낸다.

- `saturated` — brief 작성(`references/finishing.md`)으로 간다.
- `not_saturated` — `gaps[]` 를 낸다. 빈 곳마다 «무엇을 보면 · 어느 결정이 바뀔 수 있나 · 어느 장치로». 인터뷰는 그 빈 곳을
  먼저 조사한다(같은 질문을 되묻지 않고 다른 접근 — P18 · «arxiv-2608.15191» 의 「개입 먼저」). 조사가 결정을 바꾸거나 열면
  라운드가 사용자에게 돌아오고 floor 가 재개방될 수 있다. floor 가 다시 모두 닫히면 판정자를 다시 부른다.

**판정 횟수 상한(D2.5).** floor 다섯이 닫힌 뒤 구간은 「판정자 → 빈 곳 조사(본체 직접 조사 포함) → 판정자」 고리가 사용자 턴 없이
돌 수 있다. 그래서 판정자 호출에도 인터뷰당 상한을 둔다 — `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT`(기본 5 · 양의 정수가 아니면 5 로
두고 한 줄로 알린다), state `orchestration.saturation_limit`(연장 반영 값). 판정자 호출 수가 상한에 닿으면 다음 판정자 dispatch **전에**
멈추고 `AskUserQuestion` 1회로 「같은 크기만큼 연장 / 포화로 보고 종료 / 인터뷰 종료」를 묻는다. 도달 순간 한 줄
`[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.` 를 내고, audit §2 에
`- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료` 를 남긴다. 「포화로 보고 종료」는 §4 의
`사용자 판단 포화(@S<m>)` 줄(사유 `판정 상한`)로, 「인터뷰 종료」는 `사용자 종료(@S<m>)` 줄로 이어진다. 조사 호출 상한(B4 의 계수 대상)은
그대로다 — 판정 상한은 판정자 호출만 센다.

판정자가 `saturated` 를 내려면 조사 기록에서 **최근 조사 두 번이 모두 결정을 바꾸지도 열지도 않았음**을 확인해야 한다(새로움
신호가 여러 번 0 일 때만 멈춘다 — «arxiv-2608.15191»; 사전 충분 조건 — «arxiv-2604.24978»). 「충분해 보인다」는 근거가 아니다.

**반복 감지.** 반복 감지는 판정자가 아니라 **인터뷰 본체**가 한다(판정자는 앞 판정을 받지 않는다 — §3). 판정자가 `not_saturated`
를 내면 본체는 각 빈 곳을 `saturation_log` 의 이전 빈 곳들과 비교한다. 같음의 기준은 둘이 모두 같을 때다: `may_change` 결정 집합 · `device`
(D2.5 — 판정자는 앞 판정을 못 보므로 같은 빈 곳을 매번 다른 문장으로 쓸 수 있어 `look_at` 문장은 기준에서 뺀다. `may_change` 가 빈
빈 곳은 `opens` 문장의 공백 정규화 일치를 함께 본다). 하나라도 같은 빈 곳이 있으면 인터뷰는 혼자 다시 돌리지 않고 그 빈 곳을
사용자에게 보인 뒤 「한 번 더 조사 / 포화로 보고 종료 / 인터뷰 종료」를 묻는다(줄 형식은 §4). 같은 입력의 steelman 재호출도 하지
않는다(§2).

**판정 불가.** Agent 도구가 없거나, 판정자 dispatch 가 실패하거나, 출력이 깨졌으면(`not_saturated` 인데 `gaps` 가 빔 · 필드
누락) 모델이 혼자 끝내지 않는다. `[spec-distill] 포화 판정 불가 — <사유>` 를 내고 「포화로 보고 종료 / 조사 계속」을 사용자에게
묻는다. 고른 답은 S 로 기록하고 audit 에 고른 행동을 담은 줄을 남긴다(§4 — 「포화로 보고 종료」와 「조사 계속」은 다른 줄이고
게이트 결과도 다르다, §5).

**사용자의 문.** 사용자는 언제든 끝낼 수 있다(기존 「나가는 문은 floor 뒤에만 있지 않다」 — RC26). `not_saturated` 가 막는 것은
«모델이 스스로 끝내는 것» 뿐이다. 포화 판정 전에 사용자가 끝내면 audit 에 `사용자 종료(@S<n>) — 포화 판정 전` 을 남긴다.

**보이는 자리.** 판정 결과(판정 · 빈 곳 수 · 다음에 볼 것)와 호출 수(`<n>/<limit>`)는 그 라운드의 «지금 이해»에 한 줄로,
audit §2 에 데이터 줄로 남는다(§4). R6 이 나중에 그 자리를 읽는다.

### §2 장치별 처분

기준 S10. OQ29 중 R1 몫이다.

| 장치 (근거) | 처분 | 바뀐 뒤 |
|---|---|---|
| coverage-mapper 재호출 자격 · 예산 `1 + Σ reopened` (RC1 · RC21) | 제거 | R1 첫 질문 전 필수 1회(하한)만. 그 뒤는 §1 «부르기» 기준 |
| blind-spot-prober 재호출 자격 · 예산 `1 + reopened` (RC2) | 제거 | 첫 전이 필수 1회(하한)만 |
| C44 Dialectic Rhythm Guard · `touched` 면제 · `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` (RC3) | 제거 | 없음. 무한 조사 방지는 §1 상한 · 판정자 |
| landscape 「web sweep ≥1회」 · 「round 1–2」 (RC4) | 수정 | 「≥1회」는 하한이라 유지(RC22 의 기각 이유와 같다). 시점 강제를 빼고 「토픽이 잡히면, 그리고 결정에 닿을 때마다」 |
| steelman 「한 방향당 1회 — 새 근거 없으면 재steelman 금지」 · 「같은 ST 안에서 재dispatch 는 하지 않는다」 (RC5 · RC67) | 수정 | 횟수 대신 반복 감지: 새 근거 또는 바뀐 전제(사용자가 받아들인 `premise_list_challenge` 포함)가 있으면 같은 방향도 다시 부른다. 입력이 같으면 다시 부르지 않는다 |
| C43 path (a) 「subagent 를 부르지 않는다」 · subagent 자리 셋 (RC23) | 제거 | path (a) 는 본체 직접 확인 또는 `repo-researcher` dispatch. 주장은 둘 다 V1 을 탄다 |
| 같은 주제 연속 되묻기 최대 2회 (RC24) | 수정 | 2회 뒤에도 약한 답이면 다음 질문 선택지에 「이 주제를 더 파기」를 둔다 — 상한을 공시하고 사용자가 연다 |
| floor 다섯 closed → 종료 (RC25) | 수정 | §1 이중 종료 |
| 문제 재구성 의례 R1 「Problem Reframe」 · root_problem 닫힘 「재구성 동의 S」 (RC48) | 제거 | 의례 표의 R1 행을 「사용자 말 그대로」로 바꾼다: root_problem 은 S1 과 문제를 서술한 이후 사용자 발화를 원문 그대로 인용해 닫는다. 다시 쓴 문장 · 확인 질문 없음. 재구성을 전제하던 자리도 함께 바꾼다 — ① `SKILL.md` 라운드 규약 «지금 이해» 정의 「문제의 현재 재구성」 → 「확인한 사실과 그 라운드에 바뀐 것」(사용자 문제 서술은 다시 쓰지 않는다), ② `SKILL.md` blind-spot-prober prompt 와 `agents/blind-spot-prober.md` Input 의 「재구성된 문제정의(Reframed Problem)」 → 「사용자 원문(S1 과 문제를 서술한 발화) + 확인한 사실」, ③ `references/steelman.md` Step 1 「R1 문제정의·goal」 → 「사용자 원문·goal」, ④ `references/finishing.md` 종료 체크리스트 「진짜 problem이 한 문장으로 재구성」 → 「root_problem 이 사용자 원문 인용으로 닫힘」, ⑤ README 의 R1 Problem Reframe 서술. 이 다섯 자리의 옛 문구(「문제의 현재 재구성」 · 「재구성된 문제정의」 · `Reframed Problem` · 「R1 문제정의」 · 「한 문장으로 재구성」)가 부재 락의 대상이다 |
| coverage-mapper 「사용하지 않는 경우 — floor 전부 closed」 · 「confidence < 0.5 면 neglect_flag: false」 (S2 · C10) | 수정 | 첫째는 지운다(이중 종료 뒤 판정자가 다시 부를 수 있다). 둘째는 신호를 끄지 않고 `confidence` 를 붙여 보인다 — 범위를 줄이지 않는다 |

처분 대상이 아닌 사실 항목:

- RC59 「사용자가 시계다」 — 근거가 상한(§1) · 판정자(§1)로 바뀐다. 재개방 무상한은 그대로다.
- RC26 사용자 종료 박제 — 사용자 자신의 통제 자리라 유지한다(K7). 포화 전 종료 표식만 더한다(§1).
- RC19 「Phase 0 이 웹을 안 봐 인터뷰 상한이 사슬 전체의 바깥 조사 상한」 — 조사 subagent 몫의 상한이 이제 `research_limit`(기본 20, 연장
  가능)이고 본체 직접 웹 검색은 라운드 규약이 묶는다는 사실을 README 에 공시한다. request-framing 은 R2 몫이라 고치지 않는다.
- RC22 기각(「웹 1회 이상 기준이 조사를 묶는 제약」) — 그대로 기각이다. 그 기준은 하한이다.

### §3 새 agent 둘

두 파일 모두 `plugins/spec-distill/agents/` 에 두고 `tools: Read, Grep, Glob`(allowlist — 쓰기 · Bash · 웹 없음),
`cost_class`, `input_slots`, 「You are / are NOT」 절을 갖는다. 웹이 없으므로 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인
자리가 필요 없다.

**`saturation-judge`** — `cost_class: low`.

- You are: 포화 판정자. You are responsible for D23 기준의 판정과 빈 곳 목록. You are NOT responsible for 조사 수행 ·
  원장 쓰기 · 사용자에게 묻기 · 방향 결정.
- 입력 슬롯 셋과 그 종류(`input_slots` 의 `kind` — `tools/adjudication/check_slots.py` 가 잰다):
  - `<decisions>` — `open_decisions[]` 전량(상태 포함, `OQ<n>: <한 줄>`). `kind: task` — 기존 조사 agent 셋의
    `<open_decisions>` 와 같은 종류다.
  - `<research_outputs>` — 조사 산출 **원문**을 시간 순으로 번호 붙여 싣는다: 조사 subagent 출력 verbatim, 그리고 본체 직접
    조사는 audit §5 에 남은 확인 줄(`- 확인 RC<n> — …`) · §4 의 웹 항목 줄 그대로. `kind: artifact`. 본체가 매긴
    `research_log` 의 `changed` · `opened` 와 `summary` 는 싣지 **않는다** — 그것은 멈추려는 쪽이 쓴 산문 종합(금지 종류
    `orchestrator_framing`)이고, 판정의 필수 조건을 본체의 자기 표시에 맡기지 않기 위해서다.
  - `<ledger_state>` — floor + derived 상태(원장 행 그대로). `kind: task`.
  - 앞 판정(빈 곳 목록)은 넘기지 않는다 — 금지 종류 `prior_verdict` 이고, 반복 감지는 본체가 한다(§1). 그래서 금지 종류
    슬롯이 없고 `check_slots.py` 의 면제 목록을 늘리지 않는다.
- 출력:

  ```yaml
  verdict: saturated | not_saturated
  novelty:                    # 판정자가 원문에서 직접 매긴다 — 최근 두 항목은 필수
    - n: <research_outputs 번호>
      changed: [OQ3]          # 이 산출이 바꾼 결정 — 없으면 []
      opened: "<이 산출이 연 새 결정 한 줄 | 없음>"
  basis: "<최근 두 항목의 novelty 요지 · 근거 줄>"
  gaps:                       # not_saturated 면 1개 이상
    - kind: explore | confirm # explore = 아직 안 본 곳 · confirm = 최근 바뀐 결정의 확인
      look_at: "<무엇을 보면>"
      may_change: [OQ3]       # 바뀔 수 있는 결정 — 없으면 opens 로
      opens: "<새로 열릴 수 있는 결정 한 줄 | 없음>"
      device: coverage-mapper | blind-spot-prober | steelman-builder | repo-researcher | orchestrator
  ```

- 규칙:
  - `saturated` 는 판정자가 매긴 `novelty` 에서 **최근 두 항목이 둘 다** `changed: []` 이고 `opened: 없음` 이며, 더 볼 빈 곳이
    없을 때만 낸다. 둘 중 하나라도 결정을 바꿨거나 열었으면 `saturated` 를 내지 않는다.
  - 최근 두 항목 중 하나라도 결정을 바꿨거나 열었는데 더 볼 곳이 떠오르지 않으면, 그것은 출력 오류가 아니라 정상 판정이다 —
    `not_saturated` 와 `kind: confirm` 빈 곳(그 바뀐 결정을 한 번 더 확인할 대상과 장치)을 낸다.
  - `<research_outputs>` 가 두 항목 미만이면 `not_saturated` 와 `kind: confirm` 빈 곳 하나(「조사가 두 번 미만 — 열린 결정에
    닿는 조사를 하나 더」)를 낸다.
  - 「충분해 보인다」를 근거로 쓰지 않는다. 사용자 원문은 받지 않는다 — 판정은 사용자 말에 맞추는 쪽이 아니라 조사 원문과 결정
    목록을 본다(«sycophancy»).
  - 본체는 판정자의 `novelty` 와 자기 `research_log` 표시가 다르면 그 차이를 그 라운드의 «지금 이해»에 한 줄로 보이고, 멈춤은
    판정자의 것을 따른다.
- dispatch 자리: `references/saturation.md` · 처분 `consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택`.

**`repo-researcher`** — `cost_class: low`.

- You are: 레포 조사자. You are responsible for 주어진 질문에 대한 레포 근거를 조사 주장 계약대로 내는 것. You are NOT
  responsible for 판정 · 웹 조사 · 원장 쓰기 · 결정 연결의 확정(본체가 V1 로 확인한다).
- 입력 슬롯: `<question>` · `<claims_contract>`(계약 내용 전문) · `<open_decisions>`.
- 출력: 계약 그대로의 `repo_claims[]`(`id` · `path` · `anchor` · `claim` · `touches` · `decides`). 판정 전에 구현을 읽는다.
- dispatch 자리: `SKILL.md` C43 절 · 처분 `consumer=orchestrator · fail-closed · disclosure=loud advisory + 본체 직접 조사로 강등`.
  계약 배달 실패면 dispatch 하지 않고 본체가 직접 조사한다.
- 첫 `repo_claims[]` 산출이면 C43 절의 internal_research admit 이 여기서도 돈다 — 그 문장의 산출자 열거에 `repo-researcher` 를 더한다.

### §4 상태 · 환경 변수 · audit 줄

**state frontmatter `orchestration`.**

- 뺀다: `coverage_mapper_dispatches` · `blind_spot_dispatches` · 최상위 `non_user_streak` · `open_decisions[]` 항목의 `touched`.
- 더한다:
  - `research_dispatches: {coverage_mapper: 0, blind_spot_prober: 0, steelman_builder: 0, repo_researcher: 0}`
  - `research_limit: <int>` — 시작값은 환경 변수, 연장마다 더한다.
  - `research_log: []` — 조사 dispatch 마다, 그리고 본체의 직접 조사(경로 (a) 확인 · web sweep)를 «지금 이해»에 실을
    때마다 한 항목 `{n, device, round, changed: [OQ…], opened: [OQ…], summary}`. 직접 조사는 `device: orchestrator` 로
    적고 상한 계수에는 넣지 않는다(B4). `changed` · `opened` 는 그 산출이 «지금 이해»에 실린 뒤 본체가 채운다 — 이 표시는 보이기와
    판정자 `novelty` 와의 대조용이고, 판정자에게는 넘기지 않는다(§3). 판정자가 받는 `<research_outputs>` 의 번호는 이 목록의 `n` 과 같다.
  - `saturation_log: []` — 판정마다 `{k, round, verdict, gaps: […], user_choice: S<n> | null}`.
- 이름은 락이 금지한 `probe_count|probe_cap|effective_cap|PROBE_CAP|web_budget|SWEEP_CAP|SESSION_CAP|web_sweep_count|web_search_count`
  와 V13 금지어(`판정자 조건` · `판정자 투입` 등)를 피한다.

**옛 세션 이월**(`references/state-migration.md`): `coverage_mapper_dispatches: k` → `research_dispatches.coverage_mapper: k`,
`blind_spot_dispatches: k` → `research_dispatches.blind_spot_prober: k`, 옛 키 둘과 `non_user_streak` · `touched` 는 지운다
(옛 키 제거 선례가 같은 파일에 있다). 부재 키는 기본값으로 채운다 — `research_limit` 은 환경 변수 값.

**환경 변수.**

- 더한다: `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT` (기본 20 · 양의 정수가 아니면 20 으로 두고 그 사실을 한 줄로 알린다).
- 뺀다: `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` — kill switch 가 아니라 임계 조정이고, 사용자가 결정한 제거라 유예 없이
  CHANGELOG `Removed` · README 에 공시한다.
- kill switch `DEVBREW_SPEC_DISTILL_DISABLE=1` · `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 은 그대로다.

**audit §2 Budget 데이터 줄**(`- ` 로 시작):

- 기존 줄 `- 질문 라운드: <n> · agent dispatch: <n> · coverage-mapper <k> · codex 실호출: <n> (성공 <n>)`(템플릿의 한 줄 —
  `coverage-mapper <k>` 는 그 줄 안의 일부다)은 **그대로**이고 §2 의 첫 데이터 줄로 남는다. 게이트의 하한 검사(`MAPPER_RE` 의
  첫 매치)가 이 줄을 읽는다.
- 새 줄은 그 정규식(`coverage-mapper\s+(\d+)`)에 걸리지 않게 장치 이름을 쓰지 않는다:
  `- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)` — 본체 직접 `<e>` 는
  상한 계수 밖이고 보이기만 한다(§1). 순서가 바뀌어도 판정이 바뀌지 않는 것을 fixture 로 잰다.
- 상한 도달마다: `- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료`
- 포화 판정 줄 — 판정자 판정:
  - `- 포화 판정 <k>: 포화 — <basis 요지>`
  - `- 포화 판정 <k>: 아직 — 빈 곳 <g>개`
- 포화 판정 줄 — 사용자가 고른 것(같은 차례 `<k>` 에 이어 적는다):
  - 반복 빈 곳 뒤 「포화로 보고 종료」 · 판정 불가 뒤 「포화로 보고 종료」:
    `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>)>`
  - 판정 불가 뒤 「조사 계속」: `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)`
  - 반복 빈 곳 뒤 「한 번 더 조사」: `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)`
- 사용자가 어느 자리에서든 「인터뷰 종료」를 고르거나 스스로 끝내면(상한 도달 · 반복 빈 곳 · 나가는 문):
  - 판정 줄이 아직 없을 때: `- 사용자 종료(@S<m>) — 포화 판정 전`
  - 마지막 판정이 `아직` 일 때: `- 사용자 종료(@S<m>) — 마지막 판정 아직`

`interview-audit-template.md` §2 에 위 형식을 싣는다.

### §5 구조 게이트

`check_brief.py gate` 에 검사 하나를 더한다 — `saturation_failures`:

- audit §2 데이터 줄 중 `포화 판정 <k>:` 또는 `사용자 종료(@S<n>)` 로 시작하는 줄의 **마지막**을 본다(줄 형식은 §4).
- 통과:
  - `포화 판정 <k>: 포화 — …` — 판정자의 포화.
  - `포화 판정 <k>: 사용자 판단 포화(@S<n>) — …` — 사용자가 「포화로 보고 종료」를 고른 기록. S 앵커 실재를 검사하고 advisory 로
    통과한다(Step B 가 사람에게 보인다 — 기존 `coverage-mapper 0 (unavailable: …)` 와 같은 결).
  - `사용자 종료(@S<n>) — 포화 판정 전 | 마지막 판정 아직` — S 앵커 실재 검사.
- 실패: 그런 줄이 없음 · 마지막이 `아직 — …`(반복 빈 곳 재조사 포함) · 마지막이 `판정 불가(…) — 조사 계속(@S<n>)`(사용자가 조사를
  계속하라고 했으므로 뒤에 포화 판정이나 사용자 종료가 와야 한다 — D1.1) · 형식 밖. 실패 사유는 다른 게이트 항목과 같은 형식으로 한 줄.
- fixture: 위 통과 셋 · 실패 넷(줄 없음 · `아직` · `조사 계속` · 형식 밖)이 각각 그 결과를 내야 한다.

그대로 두는 것: floor 다섯 검사(`FLOOR_KEYS` · `coverage_ledger_failures` · `coverage_anchor_failures`), `budget_mapper_failures`
(k≥1 하한), `landscape_present`. root_problem 은 여전히 S 앵커를 인용해야 하고 S1 인용이 그것을 만족한다.

기존 커밋된 brief 들(`docs/superpowers/interview/*`)은 이 검사 이전에 만들어졌다. 그것을 게이트에 다시 태우는 테스트가 있으면
계획에서 찾아 처리한다(그 brief 를 고치지 않는다 — 날짜 기준 면제가 아니라 fixture 분리로).

### §6 파일 배치와 락

**파일 배치.** `SKILL.md` 는 504 줄 상한(여유 0)이라 새 절차를 조건부 reference `references/saturation.md` 에 둔다 — 상한 도달 시와
floor 다섯이 모두 닫힐 때 읽는다. `SKILL.md` 에는 진입 몇 줄 · `repo-researcher` dispatch 블록 · 상태 스키마만 남기고, C44 절 ·
자격/예산 문단 · R1 Reframe 문구를 걷어 생기는 줄로 갚는다. 상한 숫자는 올리지 않는 것이 목표이고, 올려야 하면 이유를 같은 커밋
메시지에 적는다.

**락 — 지우지 않고 뒤집는다.** 걷는 장치를 고정하던 존재 락은 «옛 문구 부재» 락과 «새 장치 존재» 락 한 쌍으로 바꾼다(부재 락만
두면 통째 삭제에도 GREEN 이다). 대상 (파일 · 리터럴 요지):

| 장치 | 지금 락 | 바뀐 뒤 |
|---|---|---|
| A coverage-mapper 자격 · 예산 | `test_conducting_interview_stage.sh`(TCIS) covmap 절 「닿는 열린 결정이 아직 있는가」 · 「열린 결정이 0이면 자격이 없다」 · `coverage_mapper_dispatches < 1 + Σ` · 존재 검사 `coverage_mapper_dispatches` · `test_coverage_mapper_frontmatter.sh` 요구 문구 `dispatch eligibility is whether an open decision still` · `1 plus the total reopen count` | 부재: 자격 · 예산 문구 · 옛 카운터. 존재: 첫 호출 필수 문구 · `research_dispatches` · §1 «부르기» 기준 문구. frontmatter 락은 새 description 문구로 |
| B blind-spot-prober 자격 · 예산 | TCIS 「재호출부터는 자격이 예산보다 앞선다」 · `blind_spot_dispatches < 1 + …` · 스키마 `blind_spot_dispatches: 0` · `test_blind_spot_prober_frontmatter.sh` 요구 문구 셋 | 같은 방식. 옛 키 `blind_spot_dispatched` 부재 락은 유지 |
| C 리듬 강제 | TCIS `## C44 Dialectic Rhythm Guard` 절 단언 여럿 · `non_user_streak` · `touched: false` | 부재: 절 머리 · `non_user_streak` · `touched` · 임계 환경 변수(README 포함). 존재: 상한 도달 문구 |
| G 되묻기 | TCIS · `test_stale_terms.sh` V13 양성 짝 「같은 주제의 연속 되묻기는 최대 2회」 | 부재: 「최대 2회」. 존재: 「이 주제를 더 파기」 선택지 문구 |
| I 재구성 | TCIS `| R1 |` 행 리터럴 셋 · `R1.*Reframe` | 부재: `Problem Reframe` · 「되풀이하는 것은 통과가 아니다」. 존재: 「사용자 말 그대로」 행 · root_problem 원문 인용 문구 |
| F subagent 금지 | TCIS C43 절 「subagent 를 부르지 않는다」 · internal_research admit 산출자 열거 리터럴 · `test_research_claims_contract.sh` 슬롯 수(SKILL 2·2) · 처분 `fail-closed` | 부재: 금지 문구. 존재: `repo-researcher` dispatch · 산출자 열거에 `repo-researcher`. 슬롯 수 숫자 갱신 |
| state 스키마 | TCIS state-migration 열거 정확 일치 `{focused_dimension: null, blind_spot_dispatches: 0, coverage_mapper_dispatches: 0, open_decisions: []}` | 새 열거로 정확 일치 |
| K 처분 회계 | `shared/tests/test_dispatch_disposition.sh` 축 A①~⑤ · C · `test_agent_input_slots.sh` · `test_dispatch_name_defined.sh` | 새 dispatch 둘의 앵커 · 슬롯 · 이름. 축 C 의 disclosure 리터럴이 본문에 실재하게 |
| E steelman · D landscape | 리터럴 락 없음 | 존재 락 새로: 반복 감지 문구 · 「결정에 닿을 때마다」. 금지 패턴 `최대 N회` 류를 쓰지 않는다 |
| 새 게이트 | 없음 | `test_check_brief.sh` fixture 넷(포화 · 아직 · 사용자 종료 · 판정 불가) + 줄 없음 |

새 이름 · 문구가 기존 부재 락(V10 · V13 · probe residue · web kill switch)에 걸리지 않는지는 쓰기 전에 그 금지 토큰을 먼저
뽑아 대조한다. 새로 생기는 문면은 부재 코퍼스에 자동 편입되기 때문이다.

### §7 위험에 대한 답

D21 은 조각마다 설계가 그 위험에 답하라고 한다. R1 묶음의 위험 셋:

- **K1** (장치를 없애면 멈춤의 주인이 조사하는 모델 자신으로 옮겨 무한 조사 · 조기 「충분」이 사용자 모르게 열린다) — 멈춤의
  주인을 모델이 아니라 쓰기 권한 없는 판정자(§3)로 옮기고, 판정 근거를 «최근 두 번의 새로움 0»으로 못 박는다. 무한 쪽은 상한
  (§1)이 막고 도달 · 연장 · 판정이 모두 보인다(§1 «보이는 자리»).
- **K7** (찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 자신의 통제 자리가 섞여 있다) — 사용자 종료 문(RC26)은 사용자의
  통제 자리라 유지하고, 되묻기 상한은 없애는 대신 사용자가 여는 선택지로 바꿨다(§2). 목록의 완전성은 이 에픽이 단정하지 않는다 —
  OQ29 는 R2 · R2a 가 이어서 찾는다.
- **K12** (무한 조사 또는 포화를 가장한 조기 종료) — 무한: 상한 + 반복 감지. 가장한 조기 종료: 판정자가 독립이고 「충분해
  보인다」를 근거로 쓸 수 없으며, 게이트가 마지막 판정이 `포화`이거나 사용자가 고른 종료일 때만 통과시킨다(§5).

### §8 인터페이스

- 받는 것: R0 의 다섯 형식(묶음 · 로드맵 · `roadmap_status.py` 출력 · 번호 대조 · `Spec:` 트레일러). 구현 커밋에
  `Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md` 트레일러를 단다.
- R6 에 넘기는 것: audit §2 의 `조사 호출 <n>/<limit>` · `상한 도달 … — 사용자 선택 S<m>: 연장`(연장 뒤 한도는 state `research_limit`) · `포화 판정` · `사용자 종료` 줄 형식(§4)과 state 키
  `research_dispatches` · `research_limit` · `saturation_log`. R6 은 이 형식을 읽기만 한다.
- R3 · R4 에 넘기는 것: 인터뷰 종료 조건이 이중 종료로 바뀐다(floor 다섯 + 포화 판정 또는 사용자 종료). brief 형식(payload
  섹션)은 바뀌지 않는다 — 바뀌는 것은 audit §2 줄뿐이다.

## Acceptance Criteria

- **AC1** `SKILL.md` · `coverage-mapper.md` · `blind-spot-prober.md` 에 자격 · 예산 문구(「열린 결정이 0이면 자격이 없다」 ·
  `1 + Σ` · `1 + coverage.floor.blind_spot.reopened` · `eligibility is` · `1 plus … reopen count`)가 없고, 첫 호출 필수 문구 둘은
  있다.
- **AC2** production 표면(skills · agents · references · scripts · README)에 `## C44 Dialectic Rhythm Guard` · `non_user_streak` ·
  `touched` 필드 · `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` 가 없다. CHANGELOG `Removed` 에 그 셋이 적혀 있다.
- **AC3** `agents/repo-researcher.md` 가 있고 `tools:` 가 정확히 `Read, Grep, Glob` 이다. `SKILL.md` C43 절에 그 dispatch 블록과
  처분 줄이 있고 「subagent 를 부르지 않는다」는 없다.
- **AC4** `agents/saturation-judge.md` 가 있고 `tools:` 가 정확히 `Read, Grep, Glob` 이다. `references/saturation.md` 에 그
  dispatch 블록 · 처분 줄 · 「최근 조사 두 번」 기준 · 반복 감지 · 판정 불가 경로가 있다.
- **AC5** `references/saturation.md` 에 상한 도달 시 세 선택지(연장 · 판정 · 종료)와 도달 한 줄 문구가 있고, 기본값 20 ·
  `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT` 가 README 환경 변수 표에 있다. 첫 조사 subagent dispatch 직전의 규모 한 줄(G9)이 SKILL 조사 상한 절에 있고 승인을 묻지 않는다. 포화 판정 상한 도달 한 줄과 세 선택지가 `references/saturation.md` 에 있다.
- **AC6** `check_brief.py gate` 가 audit §2 의 마지막 포화 판정 줄로 거절한다: `포화` 통과 · `사용자 판단 포화(@S<n>)` advisory 통과(S 실재) · `사용자 종료(@S<n>)` 통과(S 실재) · 줄 없음 실패 · `아직` 실패(반복 빈 곳 재조사 포함) · `판정 불가(…) — 조사 계속(@S<n>)` 실패 · 형식 밖 실패. 케이스마다 그 결과를 낸다(§5).
- **AC7** `steelman.md` · `steelman-builder.md` 에 「한 방향당 1회」 · 「같은 ST 안에서 재dispatch 는 하지 않는다」가 없고,
  「새 근거 또는 바뀐 전제가 있으면 다시 부른다 · 입력이 같으면 부르지 않는다」 취지 문구가 있다. `최대 N회` 류 표현이 없다.
- **AC8** `SKILL.md` 에 「최대 2회」가 없고 「이 주제를 더 파기」 선택지 문구가 있다.
- **AC9** `SKILL.md` 에 「round 1–2」가 없고 landscape 「결정에 닿을 때마다」 문구가 있다. 「≥1회」 하한은 남는다.
- **AC10** `SKILL.md` · `finishing.md` · README 에 `Problem Reframe` · 「되풀이하는 것은 통과가 아니다」 · 「재구성 동의 S」가
  없고, 의례 표 R1 행이 「사용자 말 그대로」이며 root_problem 닫힘 발화가 원문 인용으로 적혀 있다.
- **AC11** `coverage-mapper.md` 에 「floor 가 이미 전부 closed」 비사용 항목이 없고 `confidence < 0.5` 가 신호를 끄지 않는다.
- **AC12** state 스키마와 `state-migration.md` 가 §4 대로이고, 옛 카운터 이월 규칙(값 보존 · 옛 키 제거)이 적혀 있다.
- **AC13** 새 dispatch 둘이 `test_dispatch_disposition.sh` · `test_agent_input_slots.sh` · `test_dispatch_name_defined.sh` ·
  `test_research_claims_contract.sh` 를 통과한다.
- **AC14** AC1~AC12 의 부재 락마다 양성 짝이 있고, 대표 변이(옛 문구 복원 · 새 문구 삭제 · 게이트 분기 반전)가 각각 RED 를
  낸다(양성 대조 포함).
- **AC15** spec-distill 테스트 전부와 `shared/tests/*.sh` 가 착수 전 baseline 과 비교해 새 실패가 없다(실패 «이름» 집합 비교).
- **AC16** `plugin.json` minor bump · CHANGELOG 항목(Added 새 agent 둘 · 상한 · 포화 게이트 / Changed / Removed) · README
  「Principles Instantiated」 · 환경 변수 표 갱신. `SKILL.md` 줄 수가 상한 안이다.

## Files to Modify

- `plugins/spec-distill/skills/spec-interview/SKILL.md` — 스키마 · 라운드 규약(되묻기) · C43(repo-researcher) · C44 절 삭제 ·
  coverage-mapper/blind-spot 자격 · 예산 문단 · 닫힘 절 root_problem · 의례 표 R1 행 · R2 시점 · 종료 절 진입(이중 종료) · kill switch 절.
- `plugins/spec-distill/skills/spec-interview/references/saturation.md` — 새로.
- `plugins/spec-distill/skills/spec-interview/references/steelman.md` — 횟수 → 반복 감지.
- `plugins/spec-distill/skills/spec-interview/references/finishing.md` — 종료 driver · root_problem 규약 · audit §2 줄 (R3 예약 파일 — 정보).
- `plugins/spec-distill/skills/spec-interview/references/state-migration.md` — 이월 규칙.
- `plugins/spec-distill/agents/coverage-mapper.md` · `blind-spot-prober.md` · `steelman-builder.md` — 규칙 · description.
- `plugins/spec-distill/agents/saturation-judge.md` · `repo-researcher.md` — 새로.
- `plugins/spec-distill/scripts/check_brief.py` — `saturation_failures`.
- `plugins/spec-distill/templates/interview-audit-template.md` — §2 줄 형식.
- `plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `test_coverage_mapper_frontmatter.sh` ·
  `test_blind_spot_prober_frontmatter.sh` · `test_stale_terms.sh` · `test_research_claims_contract.sh` · `test_check_brief.sh` (+ fixtures).
- `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`.

## Verification Plan

1. 착수 전 baseline: spec-distill 테스트 전부와 `shared/tests/*.sh` 를 돌려 실패 «이름» 집합을 파일로 남긴다(선재 RED 구분).
2. 각 Task 뒤 그 Task 가 닿은 락 파일과 소비자 테스트를 리포 루트에서 돌린다.
3. 게이트: fixture 다섯(AC6)으로 `check_brief.py gate` 의 rc 와 사유 줄을 함께 확인한다.
4. 변이(AC14): 커밋 뒤 복사본에서 옛 문구 복원 · 새 문구 삭제 · 게이트 분기 반전을 하나씩 하고 RED 를 확인한다. 양성 대조
   (변이 없는 복사본 GREEN)를 먼저 잰다. `PYTHONDONTWRITEBYTECODE=1`.
5. 마지막: 1 과 같은 집합을 다시 돌려 새 실패가 없음을 확인한다(AC15).
6. 실제 인터뷰 한 번을 돌리는 끝에서 끝 시험은 하지 않는다 — 사용자가 쓰면서 판단한다(S32). 대신 판정자 · 조사자 agent 를
   장난감 입력으로 한 번씩 dispatch 해 출력 형식을 확인한다.

## Rejected Alternatives

- **포화만 종료 조건(B)** — floor 를 점검 목록으로 낮춘다. 구조 게이트 · R3/R4 인터페이스가 크게 바뀌고 사용자 답으로 닫는 보장이
  약해진다(B5).
- **칸마다 포화 판정(C)** — 판정 호출이 다섯 배 이상이고 칸 사이에 걸친 결정을 못 본다(B5).
- **기존 재비판 agent(`doc-recritic`) 재사용** — finding 목록을 판정하도록 짜여 있어 persona 를 고쳐야 하고 persona 편집은 보안
  리뷰 대상이다. C32(다시 만들지 않기)보다 역할 왜곡이 크다(B1).
- **웹을 쓰는 판정자** — 판정자가 직접 조사하면 조사와 판정이 한 몸이 되고 웹 kill switch 자리가 하나 더 는다(B1).
- **내장 Explore 로 레포 조사** — C32 쪽이지만 Bash 가 있어 쓰기를 물리적으로 못 막고(Law 2 결), 처분 회계 락의 agent 집합 밖이라
  호출이 락에 안 보인다(B3).
- **기존 셋만 자유롭게** — 레포 조사 subagent 금지(RC23)를 그대로 남긴다(B3).
- **판정자 호출도 20회에 포함 / 본체 직접 조사도 계수** — 앞은 조사에 쓸 횟수를 줄이고, 뒤는 「한 묶음」 경계를 모델이 판단해야
  해 셀 때마다 흔들린다(B4).
- **root_problem 칸 삭제** — 게이트 · state · migration · fixture · 「floor 5차원」 문구 락과 다른 에픽이 받는 brief 형식이 바뀐다(B2).
- **상한 · 압축 계열까지 일률 제거 · 무변경 유지 분기 · 모델 재량의 「안전」 판정** — ST3 이 이미 기각했다(S10 이 고친 기준).

## 결정 기록

줄 형식은 로드맵과 같다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다.

- B1 · 결정 · 2026-10-12 · 포화 판정자 — 「새 판정자 agent (권장)」
- B2 · 결정 · 2026-10-12 · root_problem 칸 — 「칸 유지, 원문으로 닫음 (권장)」
- B3 · 결정 · 2026-10-12 · 레포 조사 subagent — 「새 읽기 전용 조사 agent (권장)」
- B4 · 결정 · 2026-10-12 · 20회 계수 대상 — 「조사 subagent 호출만 (권장)」
- B5 · 결정 · 2026-10-12 · 종료 구조 — 「A 이중 종료 (권장)」
- B6 · 결정 · 2026-10-12 · 설계 1/3 조사의 흐름과 멈춤 — 「맞다, 다음 절로 (권장)」
- B7 · 결정 · 2026-10-12 · 설계 2/3 장치별 처분 — 「맞다, 다음 절로 (권장)」
- B8 · 결정 · 2026-10-12 · 설계 3/3 새 agent · 상태 · 게이트 · 락 — 「맞다, 설계문서로 (권장)」
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-12-interview-persistent-explore--fcb018899538759f r1: advice_new=3 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-12-interview-persistent-explore--fcb018899538759f r2: advice_new=5 · advice_repeat=4 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-12-interview-persistent-explore--fcb018899538759f r3: advice_new=3 · advice_repeat=8 · mc_preexisting_new=0

### 재결정

- **원래**: 2026-09-22 설계 §F — 조사 장치 재호출은 「그 차원에 닿는 열린 결정」 자격 위에 `1 + 재개방` 예산, 사용자 답 없는 조사는
  C44 가 3회에서 사용자 질문으로 강제하되 `touched` 면제로 유한하게. 무한 루프가 아닌 근거는 「사용자가 시계다」(RC16 · RC59).
- **재결정**: 자격 · 예산 · C44 · 면제를 제거하고(§2), 무한 루프 방지는 조사 호출 상한(기본 20, 사용자 연장) · 인터뷰 본체의 반복 감지(판정자가 낸 빈 곳을 이전 빈 곳과 비교) ·
  기존 kill switch 로 옮긴다(§1).
- **근거**: 사용자 원문 S1(「풀고 싶은 제약은 조사 장치의 호출 예산과 자격, 사용자 질문 리듬 강제…」 · 「횟수 상한은 안전장치로만」) ·
  S10(장치 전부 제거 또는 수정) · S15(포화 기준 + 독립 판정) · S43(조사 호출 20회). 브레인스토밍 결정 B1 · B4 · B5.
- D1.1 · r1 · adopt · 121f3fc0#r1.1 · "고친다(채택) — 종료 선택만 통과 (권장)" — 판정 실패 뒤 사용자가 ‘조사 계속’을 선택해도 종료 게이트가 통과한다. 기록 형식과 통과 조건이 사용자의 종료 승인 여부를 구별하지 않는다.
- D1.2 · r1 · adopt · 53459216#r1.1 · "고친다(채택) — 첫 조사 전 한 줄 (권장)" — 사용자가 확정한 「크게 쓰기 전에는 규모만 알린다」가 설계에 없다. 설계는 상한에 닿은 뒤에 알리는 것만 하고, 조사를 크게 쓰기 시작하기 전에 규모를 미리 알리는 자리는 두지 않는다.
- D1.3 · r1 · adopt · e8784824#r1.1 · "고친다 — 시계를 사실대로 (권장)" — 리듬 강제를 없애면 인터뷰 본체가 직접 하는 조사(레포 읽기·웹 검색)는 상한도 세기도 없다. 설계는 「그쪽의 멈춤은 판정자가 가른다」고 하지만 판정자는 floor 다섯이 모두 닫힌 뒤에야 불린다. 그 전 구간은 멈출 장치가 없다.
- D2.4 · r2 · adopt · 720d4cf6#r2.1 · "현재 변경 유지(채택) — 결정 줄 (권장)" — finding 없이 바뀜: 재결정 (modified)
- D2.5 · r2 · adopt · e8784824#r2.1 · "고친다 — 판정 횟수 상한 (권장)" — floor 다섯이 닫힌 뒤에는 판정자를 부르고, 본체가 직접 조사하고, 다시 판정자를 부르는 고리가 돈다. 이 고리에는 세는 것도 사용자에게 돌아가는 턴도 없고, 반복 감지도 사실상 걸리지 않는다. 그래서 무한 루프 방지 요구(상한·반복 감지·kill switch)의 상한이 이 구간에서 비어 있다.
- D3.6 · r3 · adopt · 720d4cf6#r3.1 · "현재 변경 유지(채택) — D2 결정 줄 (권장)" — finding 없이 바뀜: 재결정 (modified)

## 번호 대조

| 번호 | 처리 | 자리 · 이유 |
|---|---|---|
| C1 | 반영 | Context — brief 가 얇은 원인 중 인터뷰 쪽을 이 에픽이 맡는다 |
| C3 | 반영 | §2 — 예산 · 자격 · 리듬 강제 · subagent 자리 제한 넷 모두 처분 |
| C4 | 반영 | §1 — 멈춤은 포화 판정, 상한은 안전장치 |
| C5 | 반영 | §2 — 비용 이유 장치 제거 · G9 — 첫 조사 전 규모 한 줄(승인 없이) · §1 상한 도달 공시 |
| C10 | 반영 | §2 마지막 행 — coverage-mapper 의 비사용 · 신호 끄기 수정 |
| C11 | 반영 | §2 — R1 몫 장치 전부 |
| C12 | 반영 | §2 — 제거 아니면 수정 |
| C13 | 반영 | §2 — 의도 왜곡 장치의 제거 · 수정 처분 전부 · AC1 ~ AC11 |
| C14 | 반영 | §2 재구성 행 · B2 |
| C25 | 반영 | Non-goals · Constraints — superpowers 무변경 |
| C32 | 반영 | Rejected Alternatives — 새 agent 둘의 재사용 불가 이유 |
| C35 | 반영 | Constraints — 외부 플러그인 무변경 |
| D15 | 반영 | §2 — 목록 전부 처분, 남은 찾기는 §7 K7 대로 R2 · R2a |
| D16 | 반영 | 묶음 §4 의 바깥 근거 12건을 brief 가 매긴 처분 그대로 쓴다 — 취함 10건(§1 · §3 · §2 · Context 에서, 각 행은 아래 «key» 행), 중립 2건(«chroma-context-rot» · «saunders-saturation»). brief · audit 에는 8건의 번호가 남아 있지 않아 「피할 반대 사례 7·8」이 어느 출처인지 이 문서는 확인하지 못했다 — R1 묶음의 12건 중 [피함] 표시는 0건이다. 확인 못 한 것으로 공시하고 지어내지 않는다 |
| D18 | 반영 | §2 기준 · 처분 칸 |
| D21 | 반영 | §7 — K1 · K7 · K12 에 답 |
| D23 | 반영 | §1 · §3 saturation-judge · §8 보이는 자리 |
| D26 | 반영 | Non-goals — devbrew 쪽만 |
| D43 | 반영 | §1 상한 · §4 환경 변수 |
| OQ1 | 반영 | §2 재구성 행 — 해결(S6)을 구현 |
| OQ2 | 반영 | §2 — 목록 전부 대상 |
| OQ3 | 반영 | Context · §1 · §2 · §3 — 바깥 근거 처분(각 «key» 행이 가리키는 절). 7·8 미식별 공시 포함 |
| OQ7 | 반영 | §1 · §3 — 기준과 판정자 |
| OQ25 | 반영 | §1 · §4 — 20 · 환경 변수 · 연장 |
| OQ29 | 반영 | §2 — R1 몫 장치의 처분. 나머지는 R2 · R2a |
| OQ32 | 반영 | §3 — 새 판정자, 처분 줄 · 회계(B1) |
| RC1 | 반영 | §2 — 제거 |
| RC2 | 반영 | §2 — 제거 |
| RC3 | 반영 | §2 — 제거 |
| RC4 | 반영 | §2 — 시점 강제 제거, 하한 유지 |
| RC5 | 반영 | §2 — 반복 감지로 수정 |
| RC14 | 반영 | Constraints · §1 — 상한 · 반복 감지 · kill switch |
| RC16 | 반영 | 결정 기록 재결정 |
| RC18 | 반영 | §3 — 새 dispatch 둘의 처분 줄 · §6 K 행 |
| RC19 | 반영 | §2 사실 항목 — README 공시, request-framing 은 R2 |
| RC21 | 반영 | §2 — 예산과 함께 제거 |
| RC22 | 기각 | 원래 기각 유지 — 웹 1회 이상은 하한이고 묶는 제약이 아니다(§2) |
| RC23 | 반영 | §2 · §3 repo-researcher |
| RC24 | 반영 | §2 — 사용자가 여는 선택지로 수정 |
| RC25 | 반영 | §1 이중 종료 |
| RC26 | 반영 | §1 사용자의 문 · §2 사실 항목 — 유지 + 포화 전 표식 |
| RC34 | 반영 | §1 — 빈 곳은 다른 접근을 먼저(P18) |
| RC35 | 반영 | §6 락 표 A 행 — 예산 식 락을 부재 · 존재 쌍으로 |
| RC36 | 반영 | §5 — 하한 검사 유지 + 포화 검사 추가 |
| RC48 | 반영 | §2 재구성 행 — 제거 |
| RC59 | 반영 | §2 사실 항목 — 근거 교체 |
| RC67 | 반영 | §2 steelman 행 |
| K1 | 반영 | §7 |
| K7 | 반영 | §7 |
| K12 | 반영 | §7 |
| ST3 | 반영 | §2 기준(S10 이 고친 기준) · Rejected 마지막 줄 |
| S1 | 반영 | Context · 재결정 근거 |
| S2 | 반영 | §2 마지막 행 |
| S3 | 반영 | §2 |
| S4 | 반영 | §2 수정 처분들 |
| S5 | 반영 | §2 — 의도 왜곡 장치의 제거 · 수정 처분 전부 · AC1 ~ AC11 |
| S6 | 반영 | §2 재구성 행 · B2 |
| S7 | 반영 | §2 · §7 K7 — 계속 찾기는 R2 · R2a 로 |
| S8 | 반영 | Context · §1 · §2 · §3 — 바깥 근거 처분(각 «key» 행이 가리키는 절). 7·8 미식별 공시 포함 |
| S10 | 반영 | §2 기준 |
| S13 | 반영 | §7 |
| S15 | 반영 | §1 · §3 |
| S17 | 반영 | Non-goals |
| S18 | 반영 | Non-goals — devbrew 쪽만 |
| S30 | 반영 | Rejected Alternatives — 재사용 검토 |
| S33 | 반영 | §2 — 묶음 밖 장치(coverage-mapper 의 비사용 · 신호 끄기)까지 더 봤다 |
| S34 | 반영 | Constraints |
| S43 | 반영 | §1 · §4 |
| S49 | 반영 | Goals — 작업 범위를 줄이지 않는다(R1 몫 전부) |
| «anthropic-multiagent» | 반영 | §1 — 조사량을 결정에 맞춰 늘리고 「충분한데 계속」은 판정자가 끊는다 |
| «arxiv-2604.24978» | 반영 | §1 — 사전 충분 조건(최근 두 번 새로움 0) |
| «arxiv-2608.15191» | 반영 | §1 — 새로움 0 여러 번 · 개입 먼저 |
| «chesterton-fence» | 반영 | Context — 울타리가 지키던 AP16 을 다른 장치로 채움 |
| «chroma-context-rot» | 반영 | §3 — 판정자는 조사 원문 전량을 받는다(본체 요약을 거치지 않기 위해서이고 긴 입력 위험은 감수한다), 중립 근거 |
| «claude4-best-practices» | 반영 | §2 — 절감 지시가 그대로 축소로 읽히는 문구(횟수 · 비사용) 제거 |
| «context-engineering» | 반영 | §4 — 조사 산출 원문은 state 본문에 두고 판정자에 그대로 넘긴다 |
| «infinite-agentic-loops» | 반영 | §1 상한 |
| «mast» | 반영 | §1 · §5 — 조기 종료 · 종료 조건 무지를 판정자와 게이트로 |
| «saunders-saturation» | 반영 | §1 — 포화의 운용 정의를 «최근 두 번 새로움 0 + 빈 곳 없음»으로 못 박음 |
| «sycophancy» | 반영 | §7 K7 — 사용자 통제 자리 보존 · §3 — 판정자는 사용자 말이 아니라 조사 원문과 결정 목록을 본다 |
| «tianpan-convergence» | 반영 | §3 — 빈 곳 목록이 결정별 커버리지 체크리스트 구실 |

## Metadata

- 에픽: R1 · 브랜치 `feature/interview-persistent-explore` · 의존 R0(머지됨 `6e55f593`)
- 플러그인: spec-distill 5.3.0 → minor bump(번호는 머지 직전)
- 경로 예약 밖 편집(정보): `finishing.md`(R3), `state-migration.md`, `interview-audit-template.md`, 새 agent 둘, `references/saturation.md`

### Deferred to plan

- `SKILL.md` 줄 예산 계산(걷는 줄 vs 더하는 줄)과 상한 숫자 유지 여부.
- 커밋된 brief 를 게이트에 태우는 테스트가 있는지와 fixture 분리 방식.
- `research_log[].changed` · `opened` 를 채우는 정확한 시점 문구(V1 뒤 «지금 이해»에 실을 때).
- 부재 락의 코퍼스(production 표면 글롭)와 금지 토큰 선대조 목록.

| # | 항목 |
|---|---|
| 3b6675a2#r1.1 | 참고(data_flow) #3-새-agent-둘 — 더 조사할 빈 곳은 없지만 최근 두 번의 조사 중 결정이 바뀐 경우를 표현할 정상 판정이 없다. 포화는 금지되고, 미포화에는 빈 곳을 반드시 요구한다. — 고치면: ‘조사할 빈 곳이 있음’과 ‘빈 곳은 없지만 포화를 확인할 관측이 부족함’을 구별한다. 관측 부족에는 확인할 대상과 조사 방법을 명시하고, 확인 조사를 거쳐 다시 판정하도록 한다. 이 상태를 출력 오류로 취급하지 않으며 판정 형식·기록·검증 기준에도 반영한다. |
| fccf272b#r1.1 | 참고(ambiguity) #acceptance-criteria — 옛 상태 키를 없애라는 기준과 그 키를 이름으로 찾아 삭제하는 이월 규칙이 충돌한다. 부재 검사에 이월 문서까지 포함되어 있어 정상적인 호환 처리도 실패로 잡힐 수 있다. — 고치면: 옛 상태 키의 부재 기준을 새 상태 스키마와 실행 중 소비 경로에 적용한다. 이월 문서에서 옛 키를 식별하고 삭제하기 위한 언급은 허용하며, 이월 후 저장된 상태에 해당 키가 없는 것을 통과 기준으로 삼는다. |
| 0b618227#r1.1 | 참고(testing) #acceptance-criteria — AC1 이 열거한 부재 문구가 실제 남아 있는 자격·예산 문구를 다 덮지 못한다. agent 두 파일의 한국어 규칙과 「사용하지 않는 경우」 항목이 남아도 AC1 은 통과한다. |
| fa43c3f4#r2.1 | 참고(feasibility) #2-장치별-처분 — README 에 「사슬 전체의 바깥 조사 상한이 이제 research_limit 이다」라고 공시하겠다고 적었다. 하지만 같은 설계에서 본체가 직접 하는 웹 검색은 그 상한에 세지 않으므로, 이 공시는 사실과 다르다. |
| dacada0a#r2.1 | 참고(ambiguity) #4-상태--환경-변수--audit-줄 — 본체 조사 기록의 `opened` 는 결정 번호 목록(`[OQ…]`)인데, 판정자 출력의 `opened` 는 「새 결정 한 줄 \| 없음」 문자열이다. 그런데 설계는 둘이 「다르면」 사용자에게 보이라고 한다. 모양이 달라 무엇을 비교해 같고 다름을 정하는지가 정해지지 않았다. |
| f8f1ca38#r2.1 | 참고(handoff_incomplete) #4-상태--환경-변수--audit-줄 — 판정자는 조사 산출 원문 전체를 요구하지만, 새 상태 기록에는 요약만 있고 원문의 저장 위치와 연결 규칙이 없습니다. 기존 저장 규약도 모든 조사자의 출력 원문을 보존하지 않습니다. — 고치면: 각 조사 산출 원문을 기존 상태 본문이나 audit에 보존하는 위치와 시점을 명시하고, 조사 번호로 해당 원문을 복원하도록 연결한다. 재개 시 원문이 없으면 요약으로 대체하지 않고 판정 불가 경로로 보낸다. |
| d8cac288#r2.1 | 참고(handoff_incomplete) #8-인터페이스 — 화면 표시를 맡는 후속 작업에는 “상한 연장” 줄을 읽으라고 넘기지만, 실제 기록 형식에는 그 줄이 없습니다. 생산자와 소비자가 서로 다른 형식을 구현하게 됩니다. — 고치면: 인터페이스의 “상한 연장”을 실제 생산 형식인 “상한 도달 … — 사용자 선택 …: 연장”으로 고치고, 연장 후 한도는 갱신된 상태 값에서 읽는다고 명시한다. |
| cf8808d8#r2.1 | 참고(ambiguity) #재결정 — 결정 기록의 재결정 문단은 무한 루프를 막는 장치 중 하나를 「판정자의 반복 감지」라고 적었다. 그런데 설계 본문은 반복 감지를 판정자가 아니라 인터뷰 본체가 한다고 정하고, 판정자에게는 앞 판정을 넘기지 않는다. 무한 루프 방지 요구(상한·반복 감지·kill switch)를 무엇이 채우는지에 대해 두 자리가 다른 주인을 가리킨다. — 고치면: 재결정 문단의 「판정자의 반복 감지」를 「인터뷰 본체의 반복 감지(판정자가 낸 빈 곳을 이전 빈 곳과 비교)」로 고친다. |
| 5576bd0c#r3.1 | 참고(overdesign) #4-상태--환경-변수--audit-줄 — yagni: 조사 기록마다 본체가 적는 「바꾼 결정 · 연 결정 · 요약」 칸은 판정에 쓰이지 않고 판정자 결과와 비교해 한 줄로 보여 주는 데에만 쓰인다. — 고치면: 조사 기록 한 항목은 번호 · 장치 · 라운드(와 원문이 있는 자리)만 남기고, 바꾼 결정 · 연 결정 · 요약 칸과 그 차이를 보여 주는 규칙을 뺀다. 결정이 바뀌었는지는 판정자가 매긴 결과 하나로 보인다. └ 천장: 판정자 결과와 본체 판단이 자주 어긋나 그 차이를 사용자가 봐야 한다는 관측이 나오거나, 화면 표시 에픽이 판정 전 구간의 조사별 새로움 표시를 요구하면 이 칸을 되살린다. |
| 037a02d1#r3.1 | 참고(ambiguity) #3-새-agent-둘 — 레포 조사자의 입력 칸 셋에 종류가 정해져 있지 않다. 특히 본체가 직접 쓰는 질문 칸은 금지 종류(본체 산문)로 읽힐 수도 있다. — 고치면: 칸마다 종류를 적는다. 예: `question` — task(본체가 정한 조사 과업 한 줄, 기대 결론을 싣지 않는다), `claims_contract` — repo_context(기존 셋과 같다), `open_decisions` — task. 면제 목록을 늘리지 않는다고 판정자 쪽처럼 명시한다. |
| 17563e51#r3.1 | 참고(ambiguity) #번호-대조 — 번호 대조 표가 판정자에게 「가벼운 참조만」 넘기고 「긴 입력을 피한다」고 적었는데, 설계 본문은 인터뷰 전체의 조사 원문을 통째로 넘긴다. — 고치면: 두 행을 본문 그대로 고쳐 쓴다(판정자는 조사 원문 전량을 받는다 — 본체 요약을 거치지 않기 위해서이고, 긴 입력 위험은 감수한다). 아니면 「가벼운 참조」를 살려 판정자에게는 최근 항목의 원문과 나머지의 위치만 넘기도록 §3 을 바꾼다. 둘 중 하나로 표와 본문을 맞춘다. |
