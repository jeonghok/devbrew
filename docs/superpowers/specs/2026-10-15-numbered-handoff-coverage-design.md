---
name: numbered-handoff-coverage
type: design
created_at: 2026-10-15
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R3.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R3 — 번호 인계 · 대조 · 깊이 · Design

> brief 의 모든 번호가 설계문서 · 계획 · 구현까지 가고, 빠지거나 얕거나 미뤄지면 경고된다.

승인된 로드맵(S47)의 에픽 R3 이다. 로드맵 전체에서의 자리는 `roadmap.md` 의 `### R3` 블록이고, 이웃
에픽 R1 · R2 · R4 · R6 · R7 과 병렬로 간다(의존 R0 · P1). R6 이 이 에픽의 경고를 보이고 R5 가 이 에픽의 입력 경로를 부른다.

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 넘김 글](#1-넘김-글)
  - [§2 대조 스크립트 — 설계문서 단계](#2-대조-스크립트--설계문서-단계)
  - [§3 계획 · 구현 대조와 미룬 항목](#3-계획--구현-대조와-미룬-항목)
  - [§4 spec-review 연결 · 깊이 판정 · 승인 때 보일 것](#4-spec-review-연결--깊이-판정--승인-때-보일-것)
  - [§5 위험에 대한 답](#5-위험에-대한-답)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [결정 기록](#결정-기록) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Handoff Context

- 입력: 에픽 묶음 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R3.md` (원본 brief
  `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 와 로드맵을 거꾸로 가리킴).
- 범위 확장: brainstorming 중 사용자가 「구현을 다 안하는거도 문제이고」라고 해 번호 인계를 계획 · 구현까지 넓혔다(B8). 로드맵 ·
  묶음의 의도 · 범위 줄은 로드맵 PR #209 가 같은 문장으로 고친다 — 이 브랜치는 그 PR 머지 뒤 main 을 merge 한다.
- brainstorming 결정: `## 결정 기록` B1~B12.
- 브랜치 `feature/numbered-handoff-coverage` · worktree `.claude/worktrees/numbered-handoff-coverage`.
- 이 문서만 읽고 계획을 쓸 수 있게 줄번호 대신 파일과 리터럴을 적는다(줄번호는 계획 시점에 다시 잰다).

## Context / Why

brief 에는 확정 항목(§2) 말고도 열린 질문(§3) · 조사(§4) · 위험(§5)이 번호를 달고 있다. brainstorming 을 거쳐 설계문서가
나오면 그중 상당수가 경고 없이 사라진다(C1 · C2). 구멍은 넷이다.

1. 인터뷰 끝의 「다음 세션 줄」(`skills/spec-interview/references/finishing.md` B-3)이 「brainstorming 의 『다음은 writing-plans 뿐』
   지시보다 이 순서가 우선한다」로 외부 지시를 덮어쓴다(RC10). brainstorming 은 brief frontmatter 를 읽지 않아 넘김은 첨부와
   지시 문장뿐이다(RC27).
2. `/compact` 요약에서 조사 · 위험이 빠져도 막을 길이 없다(RC9).
3. 설계문서 리뷰 프로필(`references/docreview-profiles/design-doc.md`)의 `ground_truth` 가 「brief §2 확정 항목」뿐이고(RC8),
   spec-review 는 설계문서 경로 하나만 받아 묶음을 넘길 입력이 없다(RC74 · RC75).
4. R0 의 `scripts/check_bundle_coverage.py` 는 번호가 표에 있는지만 보고 답이 구체적인지는 보지 않는다(D40). 설계문서 뒤의
   계획 · 구현 단계에서 빠지거나 미뤄지는 것(SDD 판정 · PR 「후속」 절)은 아무도 대조하지 않는다 — R1 의 후속 넷이 그랬다.

외부 skill(brainstorming · writing-plans · SDD)의 습관 — 첫 조각만 설계(RC40), YAGNI(RC41 · RC45), 모호하면 혼자 고르기(RC42),
작은 일이면 spec 생략(RC43), 간결체(RC44), 명확화 질문 재시작(RC46) — 은 고칠 수 없다(C25). 넘길 때 보내는 글과 돌아온 결과
검사만 devbrew 쪽에서 바꾼다(D26).

## Goals

- G1 넘김 글이 외부 지시를 덮어쓰지 않고, 외부가 받아 주는 입력(첨부 · 지시 문장)만으로 조사 · 위험 · 번호 대조를 요구한다.
- G2 spec-review 가 묶음(또는 brief)을 정해진 입력으로 받아 정답 출처로 쓴다.
- G3 번호마다 빠짐 · 얕음 · 받드는 에픽 없는 발화를 기계가 경고하고, 내용의 구체성은 리뷰어가 판정한다.
- G4 설계문서의 AC 가 계획 · 구현에서 빠지거나 미뤄지면 경고되고, 미룬 항목은 받는 곳이 생길 때까지 경고로 남는다.
- G5 spec 승인 때 로드맵 속 위치와 이웃 에픽의 결정이 함께 보인다.

## Non-goals

- 묶음 생성 — R4. 경고의 화면 표시 — R6. 지휘(검사를 언제 부를지 자동화) — R5.
- 공유 리뷰 엔진(`shared/docreview/`) 동작 변경 — R2a.
- 설계문서 리뷰 프로필의 과설계 절 — R2.

## Constraints

- 외부 플러그인은 건드리지 않고 어그러뜨리지 않는다(C25 · C35 · D26). 넘김 글은 첨부와 지시 문장만 쓴다.
- 있는 것을 다시 만들지 않는다(C32): 번호 문법 · 표 해석은 `check_bundle_coverage.py`, brief 의 번호 집합은 `roadmap_status.py`
  의 brief 번호 계산, 경고는 기존 채널(스크립트 첫 줄 · spec-review 게이트 앞 「경고 N개 — 위에 적었다」)을 쓴다.
- 기계 기준에 숫자 컷오프(글자 수 등)를 두지 않는다 — 숨은 상한이 된다.
- 종료 코드 뜻은 그대로: 0 이상 없음 · 1 경고 · 3 검사 불가. 지휘 절차의 「0 이 나오기 전에는 spec-review 로 가지 않는다」 유지.

## 설계

### §1 넘김 글

1. **덮어쓰기 문장을 뺀다(D42).** 다음 세션 줄에서 「— brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다」를
   지운다. spec-review 를 부르는 자리는 brainstorming 자신의 「사용자 리뷰 게이트」라 그 자리의 할 일로 적으면 된다. 순서
   (brainstorming → spec-review → writing-plans)와 「spec-review 가 게이트 없이 끝나면 사용자 리뷰 게이트로 돌아간다」 분기는 유지.
2. **조사 · 위험을 다시 읽게 한다.** 줄에 다음을 더한다: brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째
   설계의 입력으로 읽고, 설계문서의 `## 번호 대조` 표(칸: 번호 · 반영/기각 · 자리 또는 이유)에 brief 의 모든 번호를 싣는다.
   `/compact` 뒤에도 `@<brief>` 첨부가 파일 전체를 다시 읽힌다(요약에 기대지 않는다).
3. **spec-review 를 brief 와 함께 부르게 한다.** 줄 안의 호출을 `Skill spec-distill:spec-review <설계문서> --bundle <brief-path>` 로 바꾼다.
4. **계획 대조를 시킨다.** 줄에 「writing-plans 가 계획을 쓴 뒤 `check_bundle_coverage.py --plan <설계문서> <계획>` 을 돌리고, 계획에
   없는 AC 는 계획에 더한다」를 더한다(§3-1).
5. **에픽 넘김 줄.** 새 참조 `references/epic-handoff.md` 에 로드맵 에픽용 줄을 둔다. brief 줄과 같은 모양이되 `@<에픽 묶음>` 을
   첨부하고, 「승인된 로드맵 <로드맵 경로> 의 에픽 <번호> 다」를 밝히며, spec-review 를 `--bundle <묶음>` 으로 부르게 한다. 지휘 세션
   (나중에는 R5)이 `<…>` 를 치환해 쓴다. 치환되지 않은 자리표가 남으면 쓰지 않는다(다음 세션 줄의 규칙 5 와 같다).

### §2 대조 스크립트 — 설계문서 단계

`check_bundle_coverage.py <묶음|brief> <설계문서> [--json]` 에 넷을 더한다.

1. **반영 칸의 자리 확인.** 셋째 칸에서 자리 표기를 뽑는다 — `§<n>` · `§<n>-<m>`(설계 절 · 그 안의 번호 목록), `AC<n>`, 그리고
   설계문서 `##` 제목과 같은 낱말(`Goals` · `Constraints` · `Context` 등). 하나도 없거나 가리킨 자리가 설계문서에 없으면
   「얕음 — 가리킨 자리가 없다」. `§<n>` 은 `### §<n>` 제목으로, `AC<n>` 은 `## Acceptance Criteria` 안의 `AC<n>` 으로 찾는다.
2. **기각 칸.** 비지 않았는지는 지금처럼 형식 오류로 본다. 이유에 에픽 번호(`R<n>` · `R<n>a` · `P<n>`)가 있으면 묶음 머리의
   `roadmap:` 로드맵에 그 블록이 있는지 확인하고, 없으면 「얕음 — 넘긴 에픽이 로드맵에 없다」.
3. **받드는 에픽 없는 발화(D41).** 묶음의 S 번호를 이 설계문서가 「기각」했는데 로드맵의 다른 어느 묶음 `ids:` 에도 그 S 가 없으면
   「받드는 에픽 없는 발화」. 로드맵이 없거나 못 읽으면 이 항목은 「셀 수 없음」으로 내고 나머지는 계속한다.
4. **brief 입력.** 첫 인자의 frontmatter `type` 이 `interview-brief` 이면 brief 의 모든 번호(`roadmap_status.py` 의 brief 번호 계산과
   같은 규칙)를 묶음 번호로 쓴다. 이때 3 은 하지 않는다. 함수는 순환 import 가 없게 한 곳으로 옮겨 둘이 함께 쓴다.

출력 첫 줄: `번호 대조: 빠진 번호 <a>개 · 얕은 답 <b>개 · 받드는 에픽 없는 발화 <c>개`(전부 0 이면 지금의 「빠진 번호 없음 (…)」
줄). 이어서 번호별 한 줄. `--json` 은 `missing` · `shallow[{id, reason}]` · `unserved` · `extra` · `status` 를 담는다.
종료 코드 1 은 셋 중 하나라도 있을 때.

### §3 계획 · 구현 대조와 미룬 항목

1. **계획 대조(기계).** `check_bundle_coverage.py --plan <설계문서> <계획>` — 설계문서 `## Acceptance Criteria` 의 `AC<n>` 마다 계획
   본문의 `### Task` 절 안에 그 토큰이 있는지 본다. 없으면 `계획 대조: 계획에 없는 AC <k>개 — AC4 · AC9`, 종료 코드 1.
   AC 절이 없으면 3.
2. **미룬 항목 기록.** 설계문서에 `## 미룸` 절을 둔다. 표 칸은 `항목 · 이유 · 받는 곳`. 항목은 `AC<n>` 이나 리뷰 finding id,
   받는 곳은 에픽 번호 · `#<PR 또는 이슈 번호>` · `없음`. SDD 판정이나 리뷰 후속으로 미룬 것은 브랜치 마무리에서 PR 을 만들기 전에
   이 표에 올린다. 미룬 것이 없으면 절을 두지 않거나 「없음」 한 줄.
3. **미룸 경고.** `roadmap_status.py` 가 에픽의 설계문서(`spec:` 또는 `source_interview` 역탐색으로 이미 찾는다)의 `## 미룸` 을 읽어,
   받는 곳이 `없음` 이거나 로드맵에 없는 에픽 번호이거나 `#<숫자>` 꼴이 아니면 그 에픽에 `받는 곳 없는 미룸 <n>개` 경고를 붙인다.
   에픽이 머지된 뒤에도 남는다. 표가 깨졌으면 「셀 수 없음」.
4. **구현 대조(리뷰어 + 기계).** SDD 의 마지막 전체 리뷰를 부를 때 devbrew 쪽이 보내는 글(에픽 넘김 줄 · 지휘 절차)에 설계문서 AC
   목록을 싣고 AC 마다 「구현됨 · 미룸 · 빠짐」을 적게 한다. 「미룸」 · 「빠짐」은 2 의 표에 올라야 하고, 「빠짐」은 머지 전에 고치거나
   사용자가 미룸으로 옮긴다. 기계는 `--impl <설계문서> <리뷰 보고 파일>` 로 보고의 AC 판정을 읽어, 「미룸」 · 「빠짐」인데 `## 미룸`
   에 없는 AC 를 경고한다. 보고 형식은 `AC<n>: 구현됨|미룸|빠짐 — <한 줄>` 한 줄씩.

### §4 spec-review 연결 · 깊이 판정 · 승인 때 보일 것

1. **입력.** `skills/spec-review/SKILL.md` 의 `## 입력` 이 `<설계문서> [--bundle <묶음|brief>]` 를 받는다. `@` 를 떼고 상대경로는
   레포 루트 기준. `--bundle` 파일이 없거나 frontmatter `type` 이 `epic-bundle` · `interview-brief` 가 아니면 리뷰를 시작하지 않고
   `[spec-distill] --bundle '<값>' 을 정답 출처로 쓸 수 없다 — <사유>.` 와 복귀 문장을 내고 끝낸다. `--bundle` 이 없으면 지금과 같다.
2. **진입 대조.** 라운드 시작 전 §2 스크립트를 돌려 출력 줄을 그대로 보인다. 경고가 있으면 게이트 질문의 「경고 N개 — 위에 적었다」에
   더한다. 종료 코드 3 은 「번호 대조 검사 불가 — <사유>」로 보이고 리뷰는 계속한다(사람이 보는 경고이지 리뷰의 정답이 아니다).
3. **정답 출처와 깊이 판정.** `design-doc.md` 의 `ground_truth` 를 「`--bundle` 이 넘어오면 그 묶음(번호 항목 · 이 에픽의 몫 · 사용자
   원문), 없으면 brief §2 확정 항목 — frontmatter `source_interview`」로 바꾼다. 탐지 · 재비판 dispatch 에 묶음 경로를 함께 넘긴다.
   프로필에 판정 항목 하나를 더한다: 번호 대조 표의 반영 칸이 가리킨 자리가 그 번호에 실제로 답하는가 — 얕으면 고칠 자리를 적어
   낸다. 「목표 · 범위를 바꾸는 수정은 decide」(RC69)는 사용자를 지키는 장치라 유지. R2 와의 경계: R3 는 `ground_truth` 줄과 이 판정
   항목만, 과설계 절은 R2.
4. **승인 때 보일 것(D41).** `--bundle` 이 에픽 묶음이면 게이트 질문 바로 앞에 둘을 보인다.
   - 로드맵 속 위치: `roadmap_status.py` 출력에서 이 에픽 한 줄과, 이 에픽의 의존 에픽 · 이 에픽에 의존하는 에픽의 한 줄씩.
   - 이웃 에픽의 결정: 의존 관계이거나 경로 예약이 겹치는 에픽 중 설계문서가 있는 것마다 `## 결정 기록` 의 사용자 결정 줄
     (`- B<n> · 결정 · …`)을 그대로. 결정 줄이 없으면 「결정 줄 없음 — <경로>」.
   brief 나 로드맵 밖이면 내지 않는다.
5. **계약.** R5 는 `spec-review <설계문서> --bundle <묶음>` 으로 부르고 §2 · §3 스크립트를 지휘 단계에서 부른다. R6 은 §2 의 `--json`
   과 `roadmap_status.py --json` 의 경고를 읽는다.

### §5 위험에 대한 답

- K3(사용자 말이 하류에서 재해석) — 묶음이 원문을 담아 정답 출처가 되고(§4-3), 번호 대조가 빠짐 · 축소를 잡는다(§2).
- K10(두꺼운 brief 의 가운데) — 리뷰어에게 그 에픽 몫의 묶음을 주고(§4-3), 표가 번호를 하나씩 짚는다(§2).
- K11(외부 문구 변화로 넘김 글 무력화) — 돌아온 설계문서 · 계획 · 구현의 대조가 마지막 그물이다(§2 · §3).
- K15(번호 장치 다섯) — 스크립트 하나(§2 · §3)와 spec-review 검사 하나(§4)로 합치고, 다섯 결정(D24 · D40 · D41 · D42 · D45)의
  판정은 모두 남긴다.
- RC40(첫 조각만) — 묶음 하나가 에픽 하나라 나눌 일이 brainstorming 에 오지 않는다(§1-5). RC41 · RC42 · RC44(깎기 · 혼자 고르기 ·
  간결체) — 빠짐 · 얕음 경고(§2 · §4-3). RC43(작은 일이면 spec 없음) — 넘김 줄이 설계문서 작성을 지시하고, 설계문서가 없으면 상태
  계산이 그 에픽을 「설계 중」 이전 단계로 남긴다. RC45(writing-plans YAGNI · 늦은 Scope Check) — 계획 대조(§3-1).
  RC46(명확화 질문 재시작) — 그대로 둔다: 외부 동작이고 해가 작다.

## Acceptance Criteria

- AC1 다음 세션 줄에 「보다 이 순서가 우선한다」가 없고, 순서 · 복귀 분기 문구는 남는다. 줄에 §3 · §4 · §5 번호째 읽기 · `## 번호 대조` · `--bundle <brief-path>` · `--plan` 지시가 있다.
- AC2 `references/epic-handoff.md` 가 에픽 넘김 줄(`@<에픽 묶음>` · 로드맵 경로 · 에픽 번호 · `--bundle`)과 자리표 규칙을 갖는다.
- AC3 `check_bundle_coverage.py` 가 반영 칸에 자리 표기가 없거나 가리킨 `§n` · `AC n` · 제목이 없으면 얕음으로 센다 — 있으면 세지 않는다(양성 짝).
- AC4 기각 칸의 에픽 번호가 로드맵에 없으면 얕음으로 센다.
- AC5 다른 묶음 어디에도 없는 S 를 기각하면 「받드는 에픽 없는 발화」, 로드맵을 못 읽으면 그 항목만 「셀 수 없음」.
- AC6 첫 인자가 `interview-brief` 이면 brief 의 전체 번호로 대조한다(`roadmap_status.py` 와 같은 번호 집합).
- AC7 첫 줄 형식 · `--json` 키 · 종료 코드(0 · 1 · 3)가 §2 대로다.
- AC8 `--plan` 이 계획 Task 절에 없는 AC 를 경고하고, AC 절 없음은 3.
- AC9 `roadmap_status.py` 가 `## 미룸` 의 받는 곳 없는 행을 그 에픽의 경고로 내고, 표가 깨지면 「셀 수 없음」.
- AC10 `--impl` 이 보고의 「미룸 · 빠짐」 중 `## 미룸` 에 없는 AC 를 경고한다.
- AC11 spec-review 가 `--bundle` 을 해석하고, 없는 파일 · 틀린 `type` 이면 리뷰를 시작하지 않고 사유를 보인다. `--bundle` 없는 호출은 지금과 같다.
- AC12 spec-review 진입이 §2 출력을 보이고 경고 수를 게이트에 더한다.
- AC13 `design-doc.md` 의 `ground_truth` 가 §4-3 문장이고 깊이 판정 항목이 있으며, 탐지 · 재비판 dispatch 가 묶음 경로를 싣는다.
- AC14 에픽 묶음으로 불린 spec-review 가 게이트 앞에 로드맵 위치와 이웃 결정 줄을 보인다(픽스처 git 저장소로 확인). brief 로 불리면 내지 않는다.
- AC15 통과가 정답인 새 단언(AC1 부재 · AC3 · AC9)은 변이로 이빨을 확인하고 양성 대조를 둔다.
- AC16 spec-distill minor bump.

## Files to Modify

- `plugins/spec-distill/scripts/check_bundle_coverage.py` (§2 · `--plan` · `--impl`), `plugins/spec-distill/scripts/roadmap_status.py` (`## 미룸` 경고 · brief 번호 계산 공유)
- `plugins/spec-distill/skills/spec-interview/references/finishing.md` (다음 세션 줄), 새 `plugins/spec-distill/references/epic-handoff.md`
- `plugins/spec-distill/skills/spec-review/SKILL.md` (`## 입력` · 진입 대조 · 게이트 앞 두 덩어리 · dispatch), `plugins/spec-distill/references/docreview-profiles/design-doc.md` (`ground_truth` · 판정 항목), `plugins/spec-distill/references/proceed-gate.md` (게이트 앞 경고 · 위치 문구가 계약에 닿으면)
- 테스트: `test_bundle_coverage.sh` · `test_roadmap_status.sh` · `test_review_handoff_order.sh` · spec-review 입력/게이트 테스트(새 파일), 경로 문자열을 단언하는 기존 테스트
- `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- 로드맵 지휘 절차(`roadmap.md` `## 지휘 절차`)의 spec-review 호출과 계획 대조 — 로드맵 수정 PR 로(지휘 절차 6)

## Verification Plan

- 작업 전 기준선: spec-distill · shared 스위트의 FAIL «이름» 집합(선재 RED `test_hook_output_schema.py test_python_and_bash_resolvers_agree`).
- 스크립트 단언은 손으로 만든 묶음 · 설계문서 · 계획 · 로드맵 픽스처(버릴 git 저장소)로. 실데이터: 이 로드맵의 R1 설계문서와 R1 묶음이 §2 로 0 이 나오는지(나오지 않으면 그 결과를 보고하고 R1 문서를 고칠지 사용자에게 묻는다).
- 닿은 소비자 전부의 스위트를 레포 루트에서. 새 셸 테스트는 실행 비트(100755).
- 끝에서 끝: 픽스처에서 묶음 → 설계문서(얕은 행 하나) → spec-review 진입 출력 → 계획(AC 하나 빠짐) → `--plan` → `## 미룸` → `roadmap_status.py` 경고.

## Rejected Alternatives

- 리뷰어에게 존재 · 깊이를 다 맡기기 — 모델이 번호를 빠뜨리면 경고 없는 생략이 리뷰 안에서 다시 생긴다(B2 · B6).
- S 번호 원장 파일 신설 — 묶음 `ids:` 와 설계문서 표에 이미 있는 정보를 두 번 적는다(C32 · B6).
- `/compact` 보존 지시문 줄 — 요약기가 빼면 조용히 사라진다(B1).
- `/compact` 선택지 폐지 — 사용자의 선택지 하나가 사라진다(B1).
- 설계문서 frontmatter 만으로 묶음 찾기 — 묶음 없는 호출과 구분이 어렵다(B3).
- 기각 이유에 글자 수 기준 — 숫자가 판단을 대신하는 숨은 상한이 된다.
- 계획 · 구현 대조를 R5 로 — 번호 장치가 두 곳으로 나뉜다(B8).
- 이웃 결정을 경로와 개수만 — 승인 자리에서 바로 비교할 수 없다(B11).

## 결정 기록

줄 형식은 로드맵과 같다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다.

- B1 · 결정 · 2026-10-15 · /compact 뒤 조사 · 위험 보존 — 「다음 세션 줄이 다시 읽게 (권장)」
- B2 · 결정 · 2026-10-15 · 깊이 판정 — 「형식은 기계 · 내용은 리뷰어 (권장)」
- B3 · 결정 · 2026-10-15 · 묶음 경로 넘기기 — 「인자 추가 --bundle (권장)」
- B4 · 결정 · 2026-10-15 · 번호 장치 합치기(K15) — 「합침 (권장)」
- B5 · 결정 · 2026-10-15 · R3 이해 확인 — 「맞다 (권장)」
- B6 · 결정 · 2026-10-15 · 번호 추적의 모양 — 「A. 스크립트 하나를 넓힘 (권장)」
- B7 · 결정 · 2026-10-15 · 설계 1절 넘김 글(brief 흐름에도 번호 대조) — 「맞다, 다음 절로 (권장)」
- B8 · 결정 · 2026-10-15 · 계획 · 구현 대조의 자리 — 「구현을 다 안하는거도 문제이고」 · 「R3 를 넓힘 (권장)」
- B9 · 결정 · 2026-10-15 · 설계 2절 대조 스크립트 — 「1, 좋아 지금 진행하는 방식보니 잘 이해한 느낌이내」
- B10 · 결정 · 2026-10-15 · 설계 3절 계획 · 구현 대조와 미룬 항목 — 「맞다, 다음 절로 (권장)」
- B11 · 결정 · 2026-10-15 · 설계 4절 · 이웃 결정 보이는 양 — 「맞다 · 결정 줄 그대로 (권장)」
- B12 · 결정 · 2026-10-15 · 설계 5절 위험 · 검증 — 「맞다, 설계문서 작성 (권장)」
- 판정 · 2026-10-15 · 묶음 없는 호출은 지금처럼 brief §2 가 정답(두 모드 병존) — 묶음 모드는 `--bundle` 이 있을 때만이라 기존 호출을 깨지 않는다.
- 판정 · 2026-10-15 · 경고는 기존 채널에 쉬운 첫 줄로 — 새 채널을 만들지 않는다(C32), R6 이 그 채널을 읽는다.

## 번호 대조

| 번호 | 처리 | 자리 · 이유 |
|---|---|---|
| C1 | 반영 | Context — 세 품질 저하 중 「경고 없는 생략」을 §2 · §3 이 잡는다 |
| C2 | 반영 | Context · §1 — 이음매에서 사라지는 조사 · 질문 · 위험을 넘김 글과 정답 출처로 |
| C17 | 반영 | §2 — 「구조적으로 정리」: 번호 장치를 스크립트 하나와 검사 하나로 |
| C25 | 반영 | Constraints — 외부 플러그인을 건드리지 않음 |
| C32 | 반영 | Constraints · §2-4 — 기존 스크립트와 brief 번호 계산 재사용 |
| C35 | 반영 | Constraints — 외부를 어그러뜨리지 않음 |
| D21 | 반영 | §5 — 묶음의 위험에 답함 |
| D24 | 반영 | §2 · §4-2 — 번호 단위 대조와 빠짐 경고 |
| D26 | 반영 | Constraints · §1 — 넘길 때 글과 돌아온 결과 검사만 |
| D40 | 반영 | §2-1 · §4-3 — 형식 깊이는 기계, 내용은 리뷰어 |
| D41 | 반영 | §2-3 · §4-4 — 받드는 발화 경고와 승인 때 위치 · 이웃 결정 |
| D42 | 반영 | §1-1 · §1-5 · §2 · §3 — 덮어쓰기 제거, 로드맵의 한 조각임을 밝힘, 빠짐 · 축소 경고 |
| D45 | 반영 | §4-1 · §4-3 — 묶음을 정해진 입력으로 넘기고 정답 출처로 |
| OQ4 | 반영 | §2 · §4-5 — 생략 경고가 R6 컨트롤 플레인으로 가는 채널 |
| OQ5 | 반영 | §5 — 위험을 받아 답함 |
| OQ8 | 반영 | §1-2 — 조사 · 질문 · 위험을 번호째 읽게 함 |
| OQ9 | 반영 | Constraints · §1 — 외부 개입은 넘김 글과 결과 검사로만 |
| OQ21 | 반영 | §1-5 — 에픽 넘김 줄이 묶음을 첨부 |
| OQ22 | 반영 | §2 · §3 · §4-3 — 깊이 판정과 계획 · 구현 대조 |
| OQ23 | 반영 | §4-4 — 승인 때 로드맵 위치와 이웃 결정 |
| OQ24 | 반영 | §5 — 외부 습관 RC40~46 각각의 답 |
| OQ27 | 반영 | §4-1 · §4-3 — 끊긴 정답 출처를 묶음으로 잇는다 |
| RC8 | 반영 | §4-3 — 정답 출처가 묶음 전체로 |
| RC9 | 반영 | §1-2 — 다음 세션 줄의 다시 읽기 |
| RC10 | 반영 | §1-1 — 덮어쓰기 문장 제거 |
| RC27 | 반영 | §1 — frontmatter 를 안 읽으니 첨부와 지시 문장으로 넘김 |
| RC40 | 반영 | §5 · §1-5 — 묶음 하나가 에픽 하나 |
| RC41 | 반영 | §5 · §2 — 깎인 항목은 빠짐 · 얕음 경고 |
| RC42 | 반영 | §5 · §4-3 — 혼자 고른 해석은 리뷰어 판정과 decide 경로 |
| RC43 | 반영 | §5 — 넘김 줄이 설계문서 작성을 지시하고, 없으면 상태 계산이 이전 단계로 남김 |
| RC44 | 반영 | §5 · §4-3 — 간결체로 얕아진 답을 깊이 판정이 잡음 |
| RC45 | 반영 | §3-1 — 계획 대조 |
| RC46 | 기각 | §5 — 명확화 질문 재시작은 외부 동작이고 해가 작아 그대로 둔다 |
| RC69 | 반영 | §4-3 — 사용자를 지키는 decide 경로 유지 |
| RC74 | 반영 | §4-1 — `--bundle` 이 정답 출처를 채움 |
| RC75 | 반영 | §4-1 — spec-review 호출에 묶음이 실림 |
| K3 | 반영 | §5 — 원문을 담은 묶음 정답과 번호 대조 |
| K10 | 반영 | §5 — 에픽 몫의 묶음과 번호별 표 |
| K11 | 반영 | §5 — 돌아온 결과 대조가 마지막 그물 |
| K15 | 반영 | §5 · §2 — 스크립트 하나와 검사 하나로 합침 |
| S1 | 반영 | Goals — 「경고 없이 생략」과 이음매의 범위 축소를 잡음 |
| S9 | 반영 | §4-5 — 생략 경고를 통제 표면(R6)으로 |
| S13 | 반영 | §5 — 위험 전부를 받아 답함 |
| S16 | 반영 | §2 · §4 — 번호 단위 인계 + 대조 |
| S17 | 반영 | Constraints — 외부는 건드리지 않음 |
| S18 | 반영 | Constraints · §1 — devbrew 쪽만 |
| S30 | 반영 | Constraints — 있는 것을 다시 만들지 않음 |
| S34 | 반영 | Constraints — 외부를 어그러뜨리지 않음 |
| S38 | 반영 | §2 · §3 — 요청이 다 해결되지 않은 채 넘어가는 것을 번호 대조와 미룸 경고로 잡음 |
| S40 | 반영 | §2 · §4-3 — 답할 목록과 깊이 확인 |
| S41 | 반영 | §2-3 · §4-4 — 받드는 발화와 전체 속 위치 |
| S42 | 반영 | §1 · §2 — 받는 입력과 번호 대조 |
| S45 | 반영 | §4 — 묶음을 직접 넘김 |
| S49 | 반영 | Goals · Handoff — 범위를 줄이지 않고 계획 · 구현까지 넓힘 |
| «bmad» | 반영 | §1-5 — 조각이 원문 인용과 자기 맥락(묶음)을 들고 감 |
| «contextchain» | 반영 | §2 — 산문 요약 대신 번호 구조체로 넘김 |
| «lightrun» | 반영 | §1-2 — 요약이 버린 사실을 다시 읽기로 |
| «lost-in-middle» | 반영 | §4-3 · §5 — 에픽 몫의 묶음과 번호별 표 |
| «superpowers-brainstorming-main» | 반영 | §5 — 피함 사례: 첫 조각만 다루는 습관을 묶음 하나 = 에픽 하나로 |

## Metadata

- 에픽: R3 · 브랜치 `feature/numbered-handoff-coverage` · 의존 R0(머지됨 `6e55f593`) · P1(머지됨 `07d8489a`)
- 플러그인: spec-distill minor bump(번호는 머지 직전)
- 경로 예약 밖 편집(정보): `check_bundle_coverage.py` · `roadmap_status.py` (R0 예약), 새 `references/epic-handoff.md`, 로드맵 지휘 절차(로드맵 PR)
- 겹침(정보): `design-doc.md` (R2) · `finishing.md` (R1 · R7) · `roadmap_status.py` (R6)

### Deferred to plan

- 자리 표기 정규식의 정확한 모양(`§<n>-<m>` · 제목 낱말 목록)과 기존 설계문서 셋(R0 · R1 · R7)의 실데이터 결과.
- brief 번호 계산 함수를 어디로 옮길지(순환 import 없는 모듈 위치).
- `--impl` 보고 파일을 누가 어디에 쓰는지(SDD 워크스페이스 · 지휘 절차) — 형식은 §3-4.
- spec-review SKILL 의 줄 예산과 게이트 앞 출력 순서.
