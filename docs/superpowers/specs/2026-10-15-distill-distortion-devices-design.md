---
name: distill-distortion-devices
type: design
created_at: 2026-10-15
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R2.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R2 — spec-distill 안쪽 압축 · 리뷰 장치 · Design

> 덜어 내는 장치는 덜어 낸 것을 사용자에게 보이고 되살릴 길을 준다. 사용자 결정을 덮는 장치는 걷는다. 근거 없이 남는 장치는 없다.

승인된 로드맵(S47)의 에픽 R2 이다. 로드맵 전체에서의 자리는 `roadmap.md` 의 `### R2` 블록이고, 이웃 에픽 R1 · R3 · R4 ·
R6 · R7 과 병렬로 간다(의존 R0 · P1). 처분 목록을 R2a · R9 에 넘긴다.

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 압축과 seed](#1-압축과-seed)
  - [§2 리뷰 프로필](#2-리뷰-프로필)
  - [§3 인터뷰 끝내기와 brief 형식](#3-인터뷰-끝내기와-brief-형식)
  - [§4 장치별 처분 표](#4-장치별-처분-표)
  - [§5 넘길 목록](#5-넘길-목록)
  - [§6 위험에 대한 답](#6-위험에-대한-답)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [결정 기록](#결정-기록) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Handoff Context

- 입력: 에픽 묶음 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R2.md` (원본 brief
  `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 와 로드맵을 거꾸로 가리킴).
- brainstorming 결정: `## 결정 기록` B1~B15. 장치 전수: 묶음의 12개 + brainstorming 중 읽기 전용 탐색이 찾은 13개(N1~N13) — §4 표.
- 브랜치 `feature/distill-distortion-devices` · worktree `.claude/worktrees/distill-distortion-devices`.
- 이 문서만 읽고 계획을 쓸 수 있게 줄번호 대신 파일과 리터럴을 적는다(줄번호는 계획 시점에 다시 잰다).

## Context / Why

사용자는 spec-distill 로 일을 맡기면 품질이 조용히 떨어지고 의도와 어긋난다고 했고(S1), 의도를 왜곡하는 장치를 다 제거하거나
수정하라고 했다(S3 · S4 · S5). 기준은 S10 으로 정해졌다: 비용 · 절감 · 압축으로만 작동하거나 사용자 결정을 덮는 것은 제거,
상한 · 압축은 공시하고 사용자가 여는 형태로 수정, 그대로 남는 것 0(D18). 장치 목록은 전부 대상이고 새 장치가 안 나올 때까지
찾는다(D15 · S7 · S33).

spec-distill 안의 장치는 셋에 모여 있다. ① request-framing 이 확산 초안을 압축 규약(`references/compression.md`)으로 깎아 seed 로
보낸다(RC30 · RC31). ② seed · brief · 설계문서 리뷰 프로필(`references/docreview-profiles/*.md`)에 절감 쪽 사다리 · 상한 · 고칠 자리
제한이 있다(RC7 · RC32 · RC33 · RC49 · RC66). ③ 인터뷰 끝내기(`skills/spec-interview/references/finishing.md`)와 brief 템플릿이
모델의 선택으로 사용자 발화 · 참고 항목을 덮거나 자동 강등한다(RC28 · RC29 · RC39 · RC50). 장치마다 원래 지키던 것이 있으므로
치우기 전에 그것을 확인한다(«chesterton-fence»). 사용자 자신의 통제 자리가 섞여 있다(K7).

## Goals

- G1 모델이 덜어 낸 것(압축 · 안 올린 발화 · 위험으로 보낸 참고 · 접힌 참고 · 확인 안 된 풀이 · 사실 자동 답)을 사용자가 보는 자리에 보이고 되살릴 길을 준다.
- G2 사용자 결정을 덮는 장치(자동 강등 · 방향 반증의 참고 격하 · 비기면 자르기)를 걷는다.
- G3 리뷰가 빠짐을 찾고 고칠 수 있게 한다(seed omission · brief §3~§5).
- G4 근거 없이 남는 장치가 없다 — 모든 장치가 §4 표에 처분과 근거로 남는다.

## Non-goals

- 인터뷰 조사 장치(R1). 공유 리뷰 엔진(`shared/docreview/`)과 qg(R2a). 번호 인계 · 다음 세션 줄(R3). 상태 저장(R7).
- 공유 문체 규칙(`shared/style/plain-language.md`) 변경.

## Constraints

- 외부 플러그인은 건드리지 않는다(C25 · C35 · D26).
- 있는 것을 다시 만들지 않는다(C32) — 공시는 각 장치가 사용자가 이미 보는 자리(seed 게이트 · B-0 확정 목록 · 리뷰 게이트)에 한 줄로. 새 원장 파일을 만들지 않는다.
- 사용자를 지키는 고정점은 유지한다: URL 비권위화, 「(사용자 확인)」 표시 글자 보존, brief §1 목표 · §6 원문 보호, trivia 우회의 공시 · `force`.
- 공시 줄 말투 하나: `<무엇> 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>`(장치마다 무엇만 다르다).
- 크게 쓰기 전에는 규모만 알린다(C5) — 이 에픽은 지출 승인 게이트를 새로 두지 않는다.

## 설계

### §1 압축과 seed

1. 압축 규약의 깎는 기준(자명 · 하류가 정할 것 · 읽으면 아는 것 · 과정 · 상시 규칙 · 출처 링크)은 남기되, 확산 초안에서 seed 로 가지
   않은 항목을 audit 의 새 표 `## seed 에서 덜어 낸 것`(칸: 항목 · 기준 · 원문 위치 · 되살림)에 한 줄씩 남긴다.
2. seed 게이트 앞에 `seed 에서 덜어 낸 것 <N>개 — …` 를 보이고 선택지에 「되살리기」를 더한다. 되살린 항목은 seed 에 돌아가고 표의
   「되살림」 칸에 표시된다.
3. 출처 링크는 seed 에 넣지 않고(URL 비권위화 유지) 1 의 표에 출처 항목으로 남긴다.
4. seed 템플릿(`templates/interview-seed-template.md`)의 「쓰지 말 것」과 `scripts/check_seed.py` 의 금지 목록이 막는 내용(열린 질문 ·
   대안 · 인수 조건 · 기각 헤딩, 하류가 정할 것)도 1 · 2 를 거친다(N8 · N9). URL 금지와 「(사용자 확인)」 글자 보존은 그대로.
   `check_seed.py` 는 금지 목록을 유지하고, 대신 audit 에 1 의 표가 있는지를 본다(덜어 낸 것이 0 이면 「없음」 한 줄).
5. 라운드당 확인 질문 하나는 유지하되, seed 게이트 앞에 `확인받지 못한 풀이 <N>개 — <seed 문장 위치>` 를 보인다(N4).
   「확인받지 못한 풀이」는 seed 에 남은 풀이 문장 중 «(사용자 확인)» 이 붙지 않은 것 전부다 — 확인 질문에서 사용자가 고르지
   않은 풀이(«기타» 로 다른 말을 적은 것 · 답하지 않은 질문의 풀이 포함)와, 골랐지만 압축으로 글자가 바뀌어 표시가 떨어진 풀이.
   줄마다 둘 중 어느 쪽인지를 이유로 적는다.
6. 압축 규약의 세 물음 중 「어차피 맞게 할 거면 뺀다」 · 「CLAUDE.md 에 있으면 뺀다」를 「빼면 1 의 표에 남긴다」로 고친다. 「상한을
   두지 않는다」 · 「확정 표시는 저자가 다시 쓸 수 없는 고정점」 · URL 비권위화는 그대로.
7. compression 채택자(request-framing 과 compression 을 쓰는 다른 skill)는 같은 규약을 대칭으로 따른다(`test_compression_adopters.sh`).

### §2 리뷰 프로필

1. 과설계 사다리(`brief.md` · `design-doc.md` 의 overdesign 절)의 「성립하는 첫 단에서 멈추고 번호가 작은 쪽」을 고친다: 비기면 자르지
   않는 쪽, 해석이 둘로 갈리면 두 해석을 함께 `decide` 로. 0건 출구 「이 문서는 이미 최소다」에 근거를 허용한다. 과설계 경고 자체는
   남긴다(RC7 · RC49).
2. 과설계 지적이 무언가를 자르라고 하면 리뷰어가 그것이 사용자 원문(brief §6 · audit §6)에 있는지 인용으로 대조하고, 있으면 「자르기」가
   아니라 `decide` 로 올린다(RC66).
3. 판정자당 라운드 3건 상한을 없앤다. 게이트 질문은 네 개씩 여러 번 나눠 묻는다.
4. seed 프로필(`seed.md`) layer1 에 `omission` 을 더한다(RC32). brief 프로필의 `fix_anchors` 를 `^0\.` · `^2\.` · `^3\.` · `^4\.` ·
   `^5\.` 로 넓힌다 — `^1\.` protected · `^6\.` immutable 유지(RC33).
   frontmatter 만 바꾸면 리뷰어가 읽는 본문 지시와 어긋나므로 두 프로필의 본문도 함께 고친다:
   - `seed.md` 본문의 층 1 머리 문장(「뺄셈 검사다 … 원문에 없는 것을 더했거나, 원문에 있는 열림을 닫았는가만 본다」)과 판정 관계
     문장(「정합이 아니라 뺄셈이다」)에 「원문에 있는 요구가 seed 에도, audit 의 덜어 낸 것 표(§1-1)에도 없는가」를 더하고,
     `omission` 범주 정의 줄을 새로 둔다.
   - `brief.md` 본문 처분 안내의 「`fix` 는 §0·§2 에만 낼 수 있다」를 넓힌 `fix_anchors` 와 같은 범위(§0 · §2~§5)로 고친다.
     「§6 원문은 어떤 처분도 바꾸지 못한다」는 그대로.
5. brief 프로필 `must_catch` 에 `direction` 을 더한다 — 사용자 방향에 대한 반증은 승인 게이트에서 묻는다(N1). 나머지 축은 참고로 둔다.
6. 접힌 참고 항목(「외 K건」)에 게이트 선택 「참고 전부 보기」를 더해 박제된 목록을 펼친다(N2). 엔진 쪽 상수는 §5 로 넘긴다.
   다는 자리는 참고 목록을 `--cap 8` 로 접어 보이는 두 곳이다: 설계문서 리뷰(`skills/spec-review/SKILL.md` 승인 게이트 2단계 앞
   목록)와 brief 리뷰(`skills/spec-interview/references/finishing.md` Step B 의 B-A 참고 목록 — §3-8 의 R2 문단에 든다).
7. brief 냉독(`skills/reviewing-brief/SKILL.md`)의 오독 분류에 「그 밖」을 더한다(N10).
8. R3 와의 경계: `design-doc.md` 에서 R2 는 overdesign 절과 3건 상한 줄만, R3 는 `ground_truth` 줄과 깊이 판정 항목만 고친다.

### §3 인터뷰 끝내기와 brief 형식

1. B-0 확정 목록에 `확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>` 를 함께 보인다. 「확정 목록 수정」에서 더할 수 있다(RC28).
2. payload §6 에 S1~Sn 원문 전부를 둔다(N7). 지금 규약은 원문을 나눠 둔다 — S1 은 payload, S2 이상은 audit
   (`scripts/check_verbatim_coverage.py` 머리글 「`S1`은 payload에, `S2` 이상은 audit에」). audit §6 은 지금 가진 S2 이상을 그대로 두고,
   payload 에 같은 원문이 겹쳐 있는 것을 허용한다. 이 변경이 부딪히는 검사 셋을 함께 고친다:
   - `scripts/check_brief.py` 의 N1b — 지금 payload §6 앵커가 정확히 `{"S1"}` 이어야 통과한다. 「S1~Sn 전부」로 바꾼다.
   - `scripts/check_verbatim_coverage.py` 의 `parse_section6_union` — 지금 같은 앵커가 payload · audit 양쪽에 있으면 append-only 위반으로
     거절한다. 양쪽 글자가 같으면 받아들이고, 다르면 거절한다. payload 쪽 누락(S1~Sn 중 빠진 번호)도 잡는다.
   - `references/docreview-profiles/brief.md` 의 `ground_truth` 와 omission 안내 — 원문 자리가 둘(S1 / AUDIT-VERBATIM 뒤 S2 이상)로
     나뉜다는 전제를 「payload §6 이 전량」으로 고친다.
3. 리뷰 참고 항목을 §5 `위험 — 리뷰 참고` 로 보낸 것은 B-0 에 `위험으로 보낸 참고 <N>개 — <id> · <이유>` 로 보이고 열린 질문으로
   올릴 수 있다(N3).
4. 확정 목록 수정 상한(`confirm_repost_count` 2회)에 닿으면 강등 · 종료 대신 `AskUserQuestion` 으로 「계속 고친다(2번 더)」 ·
   「지금 목록으로 확정」 · 「brief 만 종료」를 묻는다. 자동 강등은 없다(RC29).
5. 「지출 통제는 엔진의 재리뷰 상한이 한다」를 「재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다」로 바꾼다(RC50).
6. brief 템플릿 §4 항목은 여러 줄을 허용한다. 결정 연결 `[RC<n> → OQ<m>]` 은 항목 첫 줄 끝에 고정한다. `check_brief.py` 의 하위 불릿
   금지(`ENTRY_BULLET_RE` 계산)를 「첫 줄이 항목, 들여쓴 줄은 그 항목의 본문」으로 바꾼다(RC39).
7. 인터뷰 라운드 요약에 `사실로 보고 직접 답한 질문 <N>개` 를 보인다(N5). 라운드당 질문 하나는 유지하고, 밀린 질문 목록을
   「지금 이해」에 보인다(N6).
8. `finishing.md` 겹침: R3(다음 세션 줄) · R7(커밋 단계). R2 는 Step A.3 · B-0 · B-A(참고 전부 보기, §2-6) · 재제시 상한 문단 · 비용 근거 문장만 고친다.

### §4 장치별 처분 표

처분: 제거 · 수정(공시 + 사용자가 엶) · 유지(근거) · 넘김. 「그대로 남는 것 0」은 「근거 없이 남는 것 0」으로 읽는다.

| 장치 | 지키던 것 | 처분 | 고친 모양 | 바뀌는 락 |
|---|---|---|---|---|
| RC30 압축 깎는 기준 | 하류 맥락 부패 방지 | 수정 | §1-1 · §1-2 · §1-6 | `test_compression_adopters.sh` |
| RC31 seed 는 깎은 것뿐 | seed 를 한 장으로 | 수정 | §1-1 · §1-2 | `test_seed_one_sentence.sh` · `test_framing_review_contract.sh` |
| RC32 seed omission 없음 | 뺄셈 판정 집중 | 수정 | §2-4 | seed 프로필 구조 락 |
| RC33 brief fix §0·§2 만 | 원문 세탁 방지 | 수정 | §2-4 (§1 · §6 보호 유지) | brief 프로필 구조 락 |
| RC39 §4 한 줄 | 결정 연결 기계 판독 | 수정 | §3-6 | `test_check_brief.sh` |
| RC7 과설계 사다리 · 3건 상한 | 과설계 경고 · 게이트 UI 크기 | 수정 · 제거 | §2-1 · §2-3 | `test_overdesign_rubric.sh` |
| RC49 brief 절감 태그 · 3건 상한 | 같음 | 수정 · 제거 | §2-1 · §2-3 | `test_overdesign_rubric.sh` |
| RC66 명시 요청 동작 | 사용자 요청 보호 | 수정 | §2-2 | `test_overdesign_rubric.sh` |
| RC28 §2 승격을 모델이 고름 | brief 를 제약 위주로 | 수정 | §3-1 | finishing 락 |
| RC29 수정 2회 뒤 강등 · 종료 | 끝없는 루프 방지 | 수정 | §3-4 (사용자가 매번 고르므로 상한은 질문으로) | `test_conducting_interview_stage.sh` 의 `confirm_repost_count` 단언 |
| RC50 지출 통제 문장 | 리뷰 비용 | 수정 | §3-5 | finishing 락 |
| RC55 라벨 1~5 낱말 | 게이트 라벨 구별 | 넘김 | §5 R2a | — |
| N1 must_catch 밖 decide 를 참고로 | 게이트 질문 수 | 수정 | §2-5 (`direction` 만) | 프로필 구조 락 |
| N2 참고 8건 · 60자 | 게이트 길이 | 수정 · 넘김 | §2-6 · §5 | finishing · spec-review 락 |
| N3 참고를 §3/§5 로 가름 | brief 를 물을 것 위주로 | 수정 | §3-3 | finishing 락 |
| N4 확인 질문 하나 | 질문 피로 | 수정 | §1-5 | request-framing 락 |
| N5 사실 질문 자동 답 | 사용자에게 사실을 묻지 않음 | 수정 | §3-7 | spec-interview 락 |
| N6 라운드당 질문 하나 · 우선순위 | 한 번에 하나씩(사용자 보호 리듬) | 유지 · 공시 | §3-7 | — |
| N7 payload §6 은 S1 만 | 얇은 payload | 수정 | §3-2 | `check_verbatim_coverage` 테스트 |
| N8 seed 게이트 금지 목록 | seed 형식 · URL 비권위화 | 수정(URL 유지) | §1-4 | `check_seed` 테스트 |
| N9 seed 템플릿 「쓰지 말 것」 | 하류 결정 침범 방지 | 수정 | §1-4 | 템플릿 락 |
| N10 냉독 분류 닫힌 6개 | 판정 일관성 | 수정 | §2-7 | reviewing-brief 락 |
| N11 trivia 우회 | 사소한 일에 의식 과잉 방지 | 유지 | 이미 공시 · `force` 로 되돌림 — S10 의 모양 | — |
| N12 SessionEnd 삭제 | 상태 정리 | 넘김 | R7 설계가 훅을 걷음 | — |
| N13 「이상 없음」 한 줄 | 「없음」 · 「확인 못 함」 구별 | 유지 · 넘김 | 공유 문체 규칙 — §5 R9 | — |

설계 · 구현 중 새 장치가 나오면 이 표에 행을 더한다(D15 · OQ29).

### §5 넘길 목록

| 넘길 곳 | 항목 |
|---|---|
| R2a | RC55 라벨 1~5 낱말 압축(`shared/docreview/references/reviewing-document.md`) · N2 엔진 상수(`RENDER_CAP=8` · `SUMMARY_WIDTH=60`) · 재리뷰 상한 값(RC50 의 상한 자체) |
| R7 | N12 세션 끝 삭제 |
| R9 | N13 공유 문체 「이상 없음」(근거만) · §4 처분 결과의 README · 철학 문서 반영 |

넘긴 항목을 자동으로 경고하는 장치는 지금 리포에 없다(R3 의 `## 미룸` 형식은 아직 없고, `roadmap_status.py` ·
`check_bundle_coverage.py` 도 넘김을 다루지 않는다). 그래서 이 표가 넘김의 유일한 기록이고, 받는 에픽(R2a · R7 · R9)의 설계가 이
표를 입력으로 읽는다. R3 가 미룸 형식과 경고를 만들면 그 꼴로 옮긴다.

### §6 위험에 대한 답

- K7(찾은 목록이 완전하고 전부 왜곡) — 읽기 전용 탐색을 한 번 더 돌려 13개를 더 찾았고, §4 의 「지키던 것」 칸과 「유지」 근거로 보호 장치를 가렸다.
- ST3(일률 제거 · 무변경 유지 · 모델 재량 「안전」 판정 기각) — 처분 기준을 S10 으로 고정하고 「유지」에는 근거를 요구한다.
- «sycophancy» — 방향 반증이 사용자에게 간다(§2-5). 「사용자 요청」 판정은 원문 인용으로(§2-2).
- «claude4-best-practices» — 절감 지시는 그대로 축소로 수행되므로 지시를 고치고(§1-6), 과설계 경향이 있으므로 과설계 경고는 남긴다(§2-1).
- «context-engineering» · «chroma-context-rot»(중립) — 압축은 남기되 덜어 낸 것을 공시한다. payload §6 이 길어지는 비용(§3-2)은 사용자 원문은 깎지 않는다는 기준으로 감수한다.
- «mast»(조기 종료 · 정보 은닉) — 자동 강등 · 종료를 질문으로(§3-4), 숨던 분류를 공시로(§3-1 · §3-3 · §3-7).

## Acceptance Criteria

- AC1 request-framing 이 audit 에 `## seed 에서 덜어 낸 것` 표를 쓰고, seed 게이트 앞에 `seed 에서 덜어 낸 것 <N>개` 줄과 「되살리기」 선택이 있다. 되살린 항목은 seed 에 들어가고 표에 표시된다.
- AC2 `compression.md` 의 세 물음에 「빼면 표에 남긴다」가 있고, 「상한을 두지 않는다」 · 확정 표시 고정점 · URL 비권위화 문면은 그대로다(부재 · 존재 짝).
- AC3 `check_seed.py` 가 URL 금지를 유지하고, audit 에 덜어 낸 것 표(또는 「없음」)가 없으면 실패한다.
- AC4 seed 게이트 앞에 `확인받지 못한 풀이 <N>개` 가 있다.
- AC5 `brief.md` · `design-doc.md` 에 「번호가 작은 쪽」 사다리와 판정자당 3건 상한이 없고, 비기면 자르지 않음 · 두 해석 `decide` · 0건 근거 허용 · 원문 인용 대조 문면이 있다.
- AC6 `seed.md` layer1 에 `omission` 이 있고, `brief.md` `fix_anchors` 가 `^0\.`~`^5\.` 이며 `^1\.` protected · `^6\.` immutable 이 유지된다.
- AC7 `brief.md` `must_catch` 에 `direction` 이 있다.
- AC8 게이트에 「참고 전부 보기」가 있고 고르면 박제 목록 전부를 보인다.
- AC9 냉독 분류에 「그 밖」이 있다.
- AC10 B-0 에 「확정으로 올리지 않은 발화」 · 「위험으로 보낸 참고」 줄이 있다.
- AC11 payload §6 에 S1~Sn 전부가 있고 `check_verbatim_coverage.py` 가 payload 쪽 누락을 잡는다.
- AC12 재제시 상한에서 강등 · 종료 문면이 없고 세 선택 질문이 있다.
- AC13 「지출 통제는 엔진의 재리뷰 상한」 문장이 없고 안전 정지 문장이 있다.
- AC14 brief §4 여러 줄 항목이 `check_brief.py gate` 를 통과하고, 결정 연결이 첫 줄 끝이 아니면 실패한다.
- AC15 라운드 요약에 `사실로 보고 직접 답한 질문 <N>개` 와 밀린 질문 목록이 있다.
- AC16 §4 표가 설계문서에 있고 25행이며 모든 「유지」 행에 근거가 있다. §5 넘길 목록이 있다.
- AC17 통과가 정답인 새 단언(AC2 · AC5 · AC6 · AC12 · AC13)은 변이로 이빨을 확인하고 양성 대조를 둔다.
- AC18 spec-distill minor bump.

## Files to Modify

- `plugins/spec-distill/references/compression.md`, `skills/request-framing/SKILL.md`, `templates/interview-seed-template.md`, `scripts/check_seed.py`, `templates/interview-seed-audit-template.md`(seed audit — §1-1 의 새 표), `scripts/build_seed_inline_blob.py`(seed 리뷰 번들에 덜어 낸 것 표를 싣는다)
- `plugins/spec-distill/references/docreview-profiles/seed.md` · `brief.md` · `design-doc.md`(overdesign 절 · 3건 상한 줄만)
- `plugins/spec-distill/skills/spec-interview/references/finishing.md`(Step A.3 · B-0 · B-A · 재제시 상한 · 비용 문장), `skills/spec-interview/SKILL.md`(라운드 요약 줄), `skills/spec-review/SKILL.md`(참고 전부 보기), `skills/reviewing-brief/SKILL.md`(냉독 분류)
- `plugins/spec-distill/templates/interview-brief-template.md`, `scripts/check_brief.py`, `scripts/check_verbatim_coverage.py`
- 테스트: `test_overdesign_rubric.sh` · `test_compression_adopters.sh` · `test_check_brief.sh` · `test_seed_one_sentence.sh` · `test_framing_review_contract.sh` · `test_brief_no_length_cap.sh` · `test_brief_no_statement_cap.sh` · `test_conducting_interview_stage.sh` · 프로필 구조 · check_seed · check_verbatim_coverage · reviewing-brief 테스트
- `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`

## Verification Plan

- 작업 전 기준선: spec-distill · shared 스위트의 FAIL «이름» 집합(선재 RED `test_hook_output_schema.py test_python_and_bash_resolvers_agree`).
- 장치마다 바뀐 락을 같은 Task 에서 새 동작으로 맞추고, 통과가 정답인 단언은 변이(삭제 · 추가 · 반전)로 RED 를 확인한다.
- 닿은 소비자 전부의 스위트를 레포 루트에서. 새 셸 테스트는 실행 비트(100755).
- 끝에서 끝: 픽스처 요청 → seed(덜어 낸 것 표 · 되살리기 · 확인 안 된 풀이) → 인터뷰 끝(안 올린 발화 · payload 원문 전부 · 재제시 상한 질문) → brief 게이트(§4 여러 줄) → brief 리뷰(omission · direction 질문 · 참고 전부 보기).

## Rejected Alternatives

- 공통 「덜어 낸 것 원장」 파일 — 새 형식 · 검사 · 락이 생기고 R1 · R3 의 audit 와 부딪힌다(B8).
- 장치를 두고 문서로만 공시 — 「근거 없이 남는 것 0」(S10)과 어긋난다.
- 압축 폐기 — 맥락 부패 근거와 「수정이나」(S4)와 부딪히고 채택자 락이 깨진다(B1).
- 위험한 기준 둘만 삭제 — 사용자가 여는 길이 늘지 않는다(B1).
- 과설계 축 전체 제거 / brief 에서만 제거 — 진짜 과설계 경고를 잃는다(B2).
- 3건 상한 유지 + 공시 — 숨은 후순위가 남는다(B3).
- seed 만 omission 보강 — brief 의 빠짐이 결정 한 건씩으로 남는다(B4).
- §4 한 줄 유지 · audit 로 — brief 가 얇아지는 원인이 남는다(B5).
- 모든 발화를 확정 후보로 — 후보가 길어져 도장 찍기로 흐른다(B6).
- 재제시 상한 제거 — 「반복 감지 없는 루프」 규칙과의 관계를 따로 풀어야 하고, 질문이 같은 보호를 더 가볍게 준다(B7).
- S1 만 두고 audit 첨부 — 긴 audit 의 가운데가 덜 읽힌다(B9).
- 모든 축 decide 를 질문으로 — 게이트 질문이 많아져 승인 피로가 커진다(B10).

## 결정 기록

줄 형식은 로드맵과 같다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다.

- B1 · 결정 · 2026-10-15 · 압축 규약 — 「깎은 것을 공시 · 되살리기 (권장)」
- B2 · 결정 · 2026-10-15 · 과설계 사다리 — 「한 방향 압력을 끔 (권장)」
- B3 · 결정 · 2026-10-15 · 판정자당 3건 상한 — 「상한 제거 (권장)」
- B4 · 결정 · 2026-10-15 · 빠짐 검사 — 「둘 다 보강 (권장)」
- B5 · 결정 · 2026-10-15 · brief §4 한 줄 — 「여러 줄 허용 (권장)」
- B6 · 결정 · 2026-10-15 · R2 이해 확인(RC50 문장 · RC55 넘김) — 「맞다 (권장)」
- B7 · 결정 · 2026-10-15 · RC28 확정 후보 선택 — 「안 올린 것도 이유와 함께 보임 (권장)」
- B8 · 결정 · 2026-10-15 · RC29 수정 상한 — 「상한에 닿으면 묻기 (권장)」
- B9 · 결정 · 2026-10-15 · 공시 구현 모양 — 「A. 장치마다 그 자리에서 (권장)」
- B10 · 결정 · 2026-10-15 · N7 payload 원문 — 「payload §6 에 모든 발화 (권장)」
- B11 · 결정 · 2026-10-15 · N1 참고로 접는 축 — 「방향 축만 질문으로 (권장)」
- B12 · 결정 · 2026-10-15 · 설계 1절 압축과 seed — 「맞다, 다음 절로 (권장)」
- B13 · 결정 · 2026-10-15 · 설계 2절 리뷰 프로필 — 「맞다, 다음 절로 (권장)」
- B14 · 결정 · 2026-10-15 · 설계 3절 인터뷰 끝내기와 brief 형식 — 「맞다, 다음 절로 (권장)」
- B15 · 결정 · 2026-10-15 · 설계 4절 처분 표 · 넘길 목록 · 검증 — 「맞다, 설계문서 작성 (권장)」
- 판정 · 2026-10-15 · 신규 장치 N2~N6 · N8~N13 의 처분(§4 표) — 사용자가 고른 기준(B1 · B7 · B9)과 S10 에서 바로 나와 brainstorming 중 표로 보이고 진행했다.
- 판정 · 2026-10-15 · RC28 · RC29 · RC50 은 `finishing.md`(R3 예약)에 있지만 R2 위험 목록 소속이라 R2 가 처분한다 — 고치는 문단을 §3-8 로 나눴다.

## 번호 대조

| 번호 | 처리 | 자리 · 이유 |
|---|---|---|
| C5 | 반영 | Constraints · §3-5 — 비용 이유의 품질 제약 제거, 규모만 알림 |
| C11 | 반영 | Goals · §4 — 왜곡 장치 전부 처분 |
| C12 | 반영 | §4 — 제거가 아니면 수정(공시 + 사용자가 엶) |
| C13 | 반영 | Goals — 이 작업 자체가 항목 |
| C25 | 반영 | Constraints — 외부 무변경 |
| C32 | 반영 | Constraints · §1-1 — 공시는 기존 자리에, 새 원장 없음 |
| C35 | 반영 | Constraints — 외부를 어그러뜨리지 않음 |
| D15 | 반영 | §4 — 탐색으로 13개 추가, 새 장치는 표에 계속 추가 |
| D18 | 반영 | §4 — 처분 기준(제거 · 수정 · 근거 있는 유지 · 넘김) |
| D21 | 반영 | §6 — 위험에 답함 |
| D26 | 반영 | Constraints — devbrew 쪽만 |
| OQ2 | 반영 | §4 — 목록 전부를 대상으로, 조사 계속 |
| OQ29 | 반영 | §4 — 장치별 처분 표가 열린 질문을 이어받음 |
| RC7 | 반영 | §2-1 · §2-3 |
| RC28 | 반영 | §3-1 |
| RC29 | 반영 | §3-4 |
| RC30 | 반영 | §1-1 · §1-6 |
| RC31 | 반영 | §1-1 · §1-2 |
| RC32 | 반영 | §2-4 |
| RC33 | 반영 | §2-4 |
| RC39 | 반영 | §3-6 |
| RC49 | 반영 | §2-1 · §2-3 |
| RC50 | 반영 | §3-5 · §5 — 문장은 R2, 상한 값은 R2a |
| RC55 | 반영 | §4 · §5 — 처분은 넘김. 공유 엔진 문서라 R2a 가 고친다 |
| RC66 | 반영 | §2-2 |
| K7 | 반영 | §6 — 추가 탐색과 「지키던 것」 칸 |
| ST3 | 반영 | §6 · §4 — S10 기준 고정, 유지에 근거 요구 |
| S1 | 반영 | Context · Goals — 조용한 품질 저하와 의도 어긋남 |
| S3 | 반영 | Goals — 왜곡 장치 제거 |
| S4 | 반영 | §4 — 아니면 수정 |
| S5 | 반영 | Goals — 이 작업도 항목 |
| S7 | 반영 | §4 — 전부 대상, 더 찾기 |
| S10 | 반영 | §4 — 제거 · 수정 기준 |
| S13 | 반영 | §6 — 위험 전부 받음 |
| S17 | 반영 | Constraints |
| S18 | 반영 | Constraints |
| S30 | 반영 | Constraints — 새 원장 만들지 않음 |
| S33 | 반영 | §4 — 「더 봐줘」 → 추가 탐색 N1~N13 |
| S34 | 반영 | Constraints |
| S49 | 반영 | Goals · §4 — 범위를 줄이지 않고 신규 13개까지 |
| «chesterton-fence» | 반영 | §4 「지키던 것」 칸 · Constraints 고정점 유지 |
| «chroma-context-rot» | 반영 | §6 — 중립 근거, payload 증가 비용을 원문 기준으로 감수 |
| «claude4-best-practices» | 반영 | §6 · §1-6 · §2-1 |
| «context-engineering» | 반영 | §6 · §1 — 압축 유지 + 공시 |
| «mast» | 반영 | §6 · §3-4 — 조기 종료 · 정보 은닉 대응 |
| «sycophancy» | 반영 | §2-5 · §2-2 · §6 |

## Metadata

- 에픽: R2 · 브랜치 `feature/distill-distortion-devices` · 의존 R0(머지됨 `6e55f593`) · P1(머지됨 `07d8489a`)
- 플러그인: spec-distill minor bump(번호는 머지 직전)
- 겹침(정보): `design-doc.md`(R3) · `finishing.md`(R3 · R7) · `spec-interview/SKILL.md`(R1 · R7) · `spec-review/SKILL.md`(R3)

### Deferred to plan

- audit 템플릿에서 `## seed 에서 덜어 낸 것` 표의 위치와 기존 audit 절 번호와의 관계.
- `check_brief.py` 의 §4 여러 줄 판독 규칙과 기존 fixture 영향 범위.
- B-0 화면 순서(확정 후보 · 안 올린 발화 · 위험으로 보낸 참고)와 줄 수가 많을 때의 접기 — 접으면 「전부 보기」를 함께.
- 프로필 구조 락의 정확한 단언 목록(변이 대상).
| fb7c66c8#r1.1 | 처분 표의 '바뀌는 락' 칸 일부가 파일이 아닌 이름('finishing 락', 'spec-interview 락', 'request-framing 락', '템플릿 락')으로만 적혀 있다. 예를 들어 finishing.md 를 검사 범위에 넣은 test_rereview_cap_consistency.sh 같은 실제 락 파일 목록은 계획 단계에서 찾아 적어야 한다. |
