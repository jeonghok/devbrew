---
name: askquestion-recommendation
type: design
created_at: 2026-10-28
source_interview: docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md
next_phase: superpowers:writing-plans
---

# AskUserQuestion 추천 표시 · Design

> devbrew 가 띄우는 모든 질문에서 추천이 무엇인지 선택지 라벨로 보이게 한다. 추천이 있으면 첫 자리 + 라벨 끝 「(권장)」(여럿이면 모두), 이유는 질문 위 글에, 추천이 없으면 화면에는 아무 표시도 없다. 지키게 하는 장치는 정본 규칙 한 줄과 레포 테스트 안의 질문 자리 전수 검사뿐이다 — 실행 중인 Claude Code 에는 아무것도 끼우지 않는다.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Anti-goals](#anti-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 정본 규칙](#1-정본-규칙) · [§2 질문 자리](#2-질문-자리) · [§3 지휘자와 옮김 대조](#3-지휘자와-옮김-대조)
  - [§4 고른 라벨 읽기](#4-고른-라벨-읽기) · [§5 전수 검사](#5-전수-검사) · [§6 라벨을 잠근 기존 테스트](#6-라벨을-잠근-기존-테스트)
- [있는 것 검토](#있는-것-검토) · [상류 · 하류 연계](#상류--하류-연계)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [미룸](#미룸) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Context / Why

공통 문체 규칙(`shared/style/plain-language.md`)에는 「추천은 「(권장)」으로 표시한다」가 이미 있고, 이 블록은 모든 진입 SKILL.md(10개)에 바이트 그대로 복제돼 있다. 그런데 사용자에게 선택지를 내는 자리 중 추천 표시가 없는 곳이 55곳이다(brief §2 ✎ · 조사 7). 사용자는 인터뷰 끝의 분해 판단 질문에서 터미널 글의 권고(로드맵)를 보고도 선택지에 표시가 없어 반대(spec 하나)를 골랐다(S3 · S8 — 보였는데 놓침).

원인은 「안 지켜짐」만이 아니다(ST1 보완). 정본 문장은 표기만 정하고 의무를 정하지 않으며(RC126), 같은 블록 3행의 「아래 절차가 출력 형식을 따로 정한 자리에서는 그 절차를 따른다」가 지역 규칙에 우선권을 준다(RC57). 그 지역 규칙들 — 분해 판단의 선택지 밖 문장 권고(RC58), 지휘자 권장을 라벨에 못 달게 한 규칙(conductor-dispatch.md:32 · relay-checker.md:32 · 35), 게이트 정본의 「제안 이유는 게이트 앞 글에」(proceed-gate.md:56) — 과 그 문면을 잠근 테스트가 이겼다.

사용자의 경계(S23 · 이 대화): 「너무 강제하게 만드는 장치는 만들지 마」의 뜻은 **순정 Claude Code 의 동작에 잘못 끼어들어 성능을 해치지 말라**는 것이다. 그래서 이 설계는 실행 중 개입을 두지 않고, 모델이 읽는 지시문을 늘리지 않으며, 규칙의 꼴을 Claude Code 질문 도구가 원래 가진 습관(첫 자리 + 「(Recommended)」 꼬리 «cc-tool-desc»)에 맞춘다. 집행은 devbrew 레포의 테스트 묶음 안에서만 돈다 — 막히는 쪽은 devbrew 를 고치는 사람뿐이고 사용자 세션의 성능과 무관하다(OQ19 — 이 대화에서 사용자 확인).

## Goals

1. devbrew 가 띄우는 모든 질문에서 추천이 무엇인지 선택지 라벨로 분명히 알린다(C1).
2. 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두(D2 · C3 · D12). 이유는 질문 위 글에 둔다(D16).
3. 맞서는 지역 규칙을 먼저 고치고(D6), 표시가 빠진 질문 자리를 고친다.
4. 질문 자리 전수 검사로 새 자리 · 빠진 표시가 레포 테스트에서 드러나게 한다(D9 · D15).

## Non-goals

- devbrew 흐름 안에서 도는 외부 skill(brainstorming · writing-plans 등)의 질문(D13). 단 지휘자가 옮겨 띄우는 질문은 범위 안이다(D14).
- 리뷰어 persona 의 추천 표시 검사(D9 · S20).
- 「(권장)」을 그대로 따르는 비율(과의존)을 재는 장치(K7 — 미룸).

## Anti-goals

이것이 생기면 기술적으로 돌아가도 실패다.

- 실행 중 질문 도구 호출에 끼어드는 훅 · 래퍼(K14 · C17). `hooks.json` 은 바뀌지 않는다.
- 모든 SKILL.md 에 복제되는 블록을 눈에 띄게 늘리는 것 — 압축 뒤 다시 붙는 skill 앞부분에서 다른 절을 밀어낸다(AC3).
- 화면에 「추천 없음 — …」 같은 문구(C7).
- 리뷰 엔진의 라벨 코드 · 정답 파일을 바꾸는 것 — 꼬리는 모델이 질문을 짤 때 붙인다(§6).

## Constraints

- 브리프 §2 의 스무 항목(C1–D20)은 확정이다. 근거가 생기면 보고 뒤 재결정할 수 있고 임의로 바꾸지 않는다.
- 결정론(막는 검사)은 레포 테스트에만 둔다 — 실행 중 결정론은 보안 · 정확성에만(철학 P8).
- 레포 전용 값은 박지 않는다 — 검사 대상 파일은 `git ls-files` 글롭과 `find` 로 도출하고 양의 짝으로 수를 맞춘다(`test_plain_language_block.sh` 와 같은 꼴).
- 플러그인을 건드리는 PR 이므로 바뀐 플러그인마다 `plugin.json` 판을 올리고 CHANGELOG 에 적는다(CLAUDE.md 메타데이터).
- 「(Recommended)」도 같은 표시로 인정한다(D4) — 검사 · 대조는 두 꼬리를 모두 센다(K9).

## 설계

### §1 정본 규칙

`shared/style/plain-language.md` 의 두 자리를 고쳐 쓴다(새 줄을 더하지 않고 있는 문장을 바꾼다).

- **6행 끝 문장** — 「추천은 「(권장)」으로 표시한다.」를 아래로 바꾼다.
  > 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두, 이유는 질문 위 글에. 추천이 없으면 아무 표시도 쓰지 않는다.
- **3행 예외 조항** — 「아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.」 뒤에 「추천 표시는 그 자리에서도 이 블록을 따른다.」를 붙인다(K2 · RC57).

추천이 없어도 되는 경우는 셋이다(✎ brief §2 · D19 · D18): 사용자만 답할 수 있는 것(취향 · 사용자가 가르는 게 목적), 근거가 모자라 모델이 판단하지 못할 때, 모델이 자기 결과에 대한 지적을 낮추거나 되올릴지 묻는 질문. 이 목록은 블록에 싣지 않는다 — 블록은 「추천이 있으면」으로 조건만 둔다. 정해진 질문 자리에서 일부러 비울 때만 그 skill 문서의 질문 옆에 이유를 적는다(D10 · §2).

정본을 고친 뒤 SKILL.md 10개의 블록을 같은 바이트로 맞춘다(K12 · RC124). 「설명에는 고르면 무엇이 달라지는지만」 문장은 그대로 둔다 — 이유는 질문 위 글에 두므로 충돌하지 않는다(✎ brief §2 첫 줄을 이 설계의 판단으로 받음).

### §2 질문 자리

조사 7 의 55곳(① 일부러 뺀 3 · ② 근거 없이 빠진 35 · ③a 자기 처분 10 · ③b 모델 제안 승인 7)을 아래 네 종류로 다시 가른다. 종류는 §5 검사의 목록 칸과 같다.

| 종류 | 뜻 | 쓰는 곳 |
|---|---|---|
| `꼬리` | 문서에 적힌 라벨에 「(권장)」(또는 「(Recommended)」)이 있다 | 추천이 고정인 자리 — 대부분의 ② · 게이트 · 표지 충돌 |
| `지시` | 실행 중 추천이 갈려 라벨을 고정할 수 없다 — 그 자리에 「권하는 쪽을 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」 한 줄이 있다 | 분해 판단 · 리뷰 결정 질문 · e2e 판정안 · 승인 질문 중 결과에 따라 갈리는 것 |
| `비움` | 일부러 추천을 두지 않는다 — 그 자리에 「추천을 달지 않는다 — <이유>」 한 줄이 있다 | 아래 셋뿐 |
| `출처꼬리` | 「(<누가> 추천)」 표지 | steelman 질문만(D11 · RC128) |

`비움` 은 셋으로 닫는다.
1. request-framing 저자 편집 덩어리 질문(「그대로 둔다 / 되돌린다」) — 이유가 이미 적혀 있다(RC129). 문구만 위 꼴로 맞춘다.
2. quality-pipeline 낮춘 지적 게이트(711) — 모델이 자기 코드의 지적을 되올릴지 묻는다(D18 · K3).
3. 같은 성격(모델이 자기 결과의 지적을 낮추거나 되올림)으로 계획이 전수 중 찾는 자리 — 찾으면 이유를 적고 목록에 올린다. 없으면 둘로 닫는다.

나머지는 모두 `꼬리` 나 `지시` 로 간다. 판단이 필요한 자리:
- **분해 판단**(finishing.md:33) — `지시`. 권고 한 줄은 이유로 질문 위 글에 남긴다(RC58 반증 → D2).
- **리뷰 결정 질문**(reviewing-document.md 8단계 · 그것을 다시 적는 spec-review · reviewing-brief · request-framing) — `지시`(D18). 추가 라운드 「열기 / 열지 않음」도 추천을 단다.
- **quality-pipeline Fix-loop · Max-iter**(840 · 923), **artifact-critique 상한**(353), **e2e 걷기 직후 게이트**(e2e.md:100) — 지적을 낮추는 질문이 아니므로 `지시`(D8 · D18).
- **게이트 둘째 질문**(proceed-gate.md:56) — 모델이 다른 다음 단계를 제안하는 것은 그쪽을 권하는 것이다. 제안을 첫 자리 + 「(권장)」, 기본 다음 단계를 둘째로 둔다. 「제안 이유는 게이트 앞 글에」는 「이유는 질문 위 글에」로 읽혀 그대로 둔다(D16). 〔내 판단 — 지금은 기본 단계에 고정 꼬리가 있다〕
- **지휘자 아래 승인 질문**(proceed-gate.md:60 · conducting.md:39 · 101 · spec-review:766) — 「승인 — 계획 담당자에게 (권장)」으로 꺾쇠 안에 꼬리를 넣어 네 곳을 맞춘다(RC131 · RC132).
- **project-init 비표준 표기** — 「Squash merge (clean history 권장)」 · 「— default」를 「(권장)」 꼬리로 바꾸고 이유는 질문 위 글로 옮긴다(RC144).
- **pm-interview 라운드 규약**(SKILL.md:202) — 「질문마다 첫 선택지가 추천이고」를 「추천이 있으면 첫 선택지에 두고」로 고친다(K6 · RC160). «다음 결정» 줄의 「추천: <첫 선택지>」는 추천이 없으면 「추천: 없음 — <이유>」로 상태 파일에만 적는다(화면 아님 — D10 의 실행 중 대응). 「이유 없는 추천 수락 → 되묻기」는 그대로 둔다 — 라운드 질문에는 이미 꼬리가 있어 새로 터질 자리가 없다(K8 · RC161).
- **saturation.md 네 질문**(35 · 96 · 110 · 125) — 35 는 「첫 선택지가 추천」을 꼬리로, 나머지는 자리마다 `꼬리` 또는 `지시`.

### §3 지휘자와 옮김 대조

`conductor-dispatch.md:32` · `conducting.md:102`(같은 규칙의 되풀이)를 고쳐 쓴다.

- **옮긴 질문**(skill · 하위가 돌려보낸 선택지) — 선택지 수 · 순서 · 라벨 글자는 그대로 둔다(D20 — 첫 자리 규칙의 예외). 원문이 문장으로 낸 권장, 또는 지휘자 자신의 권장은 그 라벨 끝에 「(권장)」 꼬리로 단다(D14 · D4). 「지휘자 의견:」 줄은 이유를 쓰는 자리로 남는다(선택 — 이유가 있을 때).
- **지휘자가 만든 질문** — 정본 규칙(§1)을 그대로 따른다: 추천이 있으면 첫 자리 + 꼬리. 「그 선택지에는 「(권장)」을 달지 않는다」 문장은 지운다. conducting.md:40 「병렬 (권장)」은 위반이 아니라 준수가 된다(RC93).

`relay-checker.md`(옮김 대조 agent persona)의 「볼 것」을 맞춘다.
- 3. 라벨 — 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 라벨이 글자 그대로 같은가.
- 4. 「(권장)」 — 원문이 붙인 꼬리가 띄운 질문에서 빠졌으면 어긋남이다(K5 · RC162 — 존재 쪽 대조를 더함). 원문에 없던 꼬리가 붙은 것은 어긋남이 아니다 — 「문장 권장이 라벨 꼬리로 옮겨짐」 어긋남 문장과 35행 「지휘자가 만든 질문의 라벨에 (권장)」 어긋남 문장을 지운다. 지휘자 의견이 선택지 **설명** 안으로 들어간 것은 여전히 어긋남이다.
- 순서 어긋남(2)은 그대로 막는다 — D20 의 순서 유지가 여기서 집행된다.

이 편집은 대조 규칙을 바꾸는 persona 편집이라 보안 리뷰 대상으로 다룬다(CLAUDE.md 「Persona 파일은 보안-민감 코드」) — 없애는 대조는 사용자 결정(D14)이 허용으로 바꾼 것뿐이고, 꼬리 빠짐 대조는 새로 더한다.

### §4 고른 라벨 읽기

라벨은 돌려받는 값이다(OQ14). 꼬리가 붙으면 글자 조건으로 갈래를 나누는 자리가 빗나간다 — conducting.md:41 「「차례로」 면」은 「차례로 (권장)」에 맞지 않아 기본(병렬)으로 새어 나간다(K10 · RC174, fail-open).

- 고른 라벨로 갈래를 나누는 산문 자리(「「X」 면」 · 「「X」 를 고르면」 꼴)는 「라벨 끝의 「(권장)」 꼬리를 뗀 이름으로 읽는다」를 그 자리에 한 번 적는다. 계획이 `git grep` 으로 그 꼴을 전수해 목록을 만든다. finishing.md:554 처럼 이미 「이름이 바뀌어도 절차는 같다」를 가진 자리는 그 문장으로 갈음한다.
- 고른 라벨을 원문 그대로 기록하는 소비자는 바꾸지 않는다 — 기록에 꼬리가 남을 뿐 판정이 바뀌지 않는다: 지휘 승인 줄(`conductor_ledger.py approval_line` — 판정은 `roadmap_model.py approval_date` 가 날짜만 읽음, RC164), quality-pipeline 추가 반복 기록(944 — 상한은 줄 수만 셈, RC168), request-framing 사용자 문구(805, RC171), check_verbatim_coverage(source 칸만 봄, RC167). 스크립트 가운데 라벨 글자를 비교하는 곳은 0 이다(조사 11).

### §5 전수 검사

새 테스트 하나(`shared/tests/test_ask_recommendation.sh` — 이름은 계획이 정해도 된다)와 목록 파일 하나(`shared/tests/fixtures/ask-sites.tsv` 꼴). 둘 다 설치본에 들어가지 않는다 — 모델이 실행 중 읽지 않는다.

- **후보 도출** — 모델이 읽는 문서(`plugins/*/skills/**/*.md` · `plugins/*/references/**/*.md` · `plugins/*/agents/*.md` · `shared/**/references/*.md`, tests 제외)에서 `AskUserQuestion` 이 있는 줄을 `git ls-files` 글롭으로 뽑고, `find` 로 같은 수가 나오는지 양의 짝으로 맞춘다. 지금 75줄이다.
- **목록** — 한 줄에 `경로 · 앵커(그 파일에서 한 번만 나오는 글자) · 종류(§2 의 넷 + 「언급」)`. 「언급」은 질문 자리가 아니라 도구 이름을 말하기만 하는 줄이다. 문장으로만 묻는 자리(conducting.md 의 「사용자에게 묻는다」 꼴 — `AskUserQuestion` 글자가 없는 것)는 조사 7 이 찾은 것을 손으로 목록에 올린다.
- **RED 조건**(넷) — ① 후보 줄인데 목록의 어느 앵커 줄도 아님(새 질문 자리가 분류 없이 생김) ② 앵커가 파일에 없거나 둘 이상(목록이 낡음) ③ 앵커부터 다음 `## `/`### ` 제목 또는 30줄 중 먼저 오는 곳까지의 창에 종류가 요구하는 글자가 없음(`꼬리` = 「(권장)」|「(Recommended)」, `지시` = 지시 문장, `비움` = 「추천을 달지 않는다 —」, `출처꼬리` = 「추천)」) ④ 후보가 0 이거나 git 수와 find 수가 다름(공허한 통과 방지).
- **보지 않는 것** — 문장 표현 · 이유의 질 · 추천이 맞는지. 모델이 즉석에서 만드는 질문(라운드 규약 밖의 대화 중 질문)은 정본 규칙만이 집행한다 — 이 한계를 테스트 머리 주석과 CHANGELOG 에 적는다(D15).
- **실행 지점** — 새로 만들지 않는다. qg 의 차등 테스트가 고를 때와 사람이 돌릴 때만 돈다(`shared/README.md` 의 두 락과 같은 자리).
- **왜 리뷰어가 아니라 검사인가**(D9) — 전수 검사는 PR 마다 모든 질문 자리를 기계로 같은 기준으로 본다. 리뷰어는 diff 의 hunk 만 받고 판정이 흔들린다(RC65 · RC67). CLAUDE.md 「그 버그를 더 잘 잡는 자리가 락이면 그것을 고치고 이유를 적는다」를 따른다 — 이 문단이 그 이유다.

창의 크기(30줄) · 지시 문장의 정확한 글자 · 목록 파일 꼴은 계획이 정한다 — 바꾸면 이 절의 RED 넷이 그대로 성립하는지 변이로 보인다(AC14).

### §6 라벨을 잠근 기존 테스트

라벨 리터럴을 잠근 테스트는 이 변경과 같은 PR 에서 고친다(OQ14). 시작 목록은 조사 11 · 7 이 모은 것이다 — 완전 일치 락 9개 파일 21곳(test_ledger_wiring.sh:39 「그만둠 (권장)」 등, K11 · RC179), 부분 문자열 락 3곳, 규칙 문장 락 7개 파일 19곳(test_conductor_dispatch_reference.sh:26–32 · test_conducting_interview_stage.sh:496 · 812–825 등), 라벨 목록 등호 락(test_plain_qg_templates.sh:165 형제들 · test_decompose_surface.sh:27). 시작 목록은 하한이다(ripgrep · 표본) — **최종 목록은 고친 뒤 네 플러그인 + shared 테스트 전체를 돌려 확정한다.**

- 부재 락 test_conducting_interview_stage.sh:825(steelman 블록에 「(권장)」 · 「(Recommended)」 없음, K9 · RC178)는 그대로 GREEN 이어야 한다 — steelman 은 `출처꼬리` 를 유지한다.
- 지휘자 권장 금지를 잠근 락(conductor-dispatch 문장 락 · relay-checker 4번)은 새 규칙 문장으로 바꿔 잠근다 — 음의 락을 지우면 양의 짝(새 문장의 존재)을 함께 둔다.
- 리뷰 엔진(`docreview_state.py` `_CHOICE_LABEL` · golden/*.gate.json · cases.sh)은 바뀌지 않는다 — 엔진은 「고친다(채택)」 같은 기본 라벨만 내고, 꼬리는 모델이 게이트 질문을 짤 때 붙인다(이 세션의 리뷰 S26–S36 이 그 꼴로 띄워졌다 · RC158).

## 있는 것 검토

- `shared/tests/plain_language_block.py` · `test_plain_language_block.sh` — 블록 동일성 검사. 그대로 쓴다(§1 의 동기화 확인).
- `tools/plain-language/token_boundary.py` — 규칙 블록이 압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계를 얼마나 밀었는지 잰다. 「순정 성능에 영향 없음」의 측정으로 쓴다(AC3).
- `shared/tests/assert.sh` · `presence_corpus.sh` — 새 검사의 단언 · 코퍼스 소유 규칙. 새 검사는 후보 도출이 부재 쪽(분류 안 된 후보 없음)이고 존재 쪽(창 안의 글자)은 목록의 그 파일만 보므로, presence_corpus 의 「공유 계약 파일이 코퍼스에 들어와 앵커를 만족시킴」 함정은 앵커가 파일마다 한 번만 나오게 하는 ② 로 막는다.
- `relay-checker` · `conductor-dispatch.md` — 고쳐 쓴다(§3), 새로 만들지 않는다.
- 레포 밖 후보: 없음. 질문 도구에 추천 필드가 없고(«cc-sdk-approvals»), PreToolUse 훅은 고르지 않은 길이다(K14).

## 상류 · 하류 연계

- **받는 곳** — 인터뷰 brief(`source_interview`) 와 그 audit 의 조사 원문(상태 파일 조사 2 · 7 · 11 · 12).
- **넘기는 곳** — `superpowers:writing-plans` → 구현. 계획은 §2 의 자리 목록과 §6 의 락 목록을 전수로 만든다.
- **되돌아오는 길** — 구현 중 이 설계의 판단(특히 §2 〔내 판단〕 · §4 의 꼬리 떼고 읽기 · §5 창 크기)이 틀린 것으로 드러나면 설계문서를 고치고 사용자에게 알린다. brief 확정 항목과 부딪치면 재결정은 사용자 동의로만(Sealed decision).
- **같은 상태를 읽는 다른 표면** — 옮김 대조 agent(relay 파일) · 지휘 승인 줄과 로드맵 상태 계산 · qg 추가 반복 기록 · request-framing 사용자 문구 · check_verbatim_coverage(§4 — 모두 꼬리에 둔감함을 확인). 사용자 메모리 「AskUserQuestion 추천은 첫 자리 + 「(권장)」」은 이 규칙이 레포에 들어가면 레포 정본을 가리키는 것으로 남는다.
- **이음매 담당** — 정본 규칙과 블록 복제는 shared, 질문 자리는 각 플러그인, 지휘자 · 옮김 대조는 spec-distill, 전수 검사는 shared/tests.

## Acceptance Criteria

- AC1: `shared/style/plain-language.md` 6행의 추천 문장이 §1 의 문장(첫 자리 · 라벨 끝 「(권장)」 · 여럿이면 모두 · 이유는 질문 위 글 · 추천이 없으면 아무 표시도 쓰지 않음)이고, 3행 예외 조항에 「추천 표시는 그 자리에서도 이 블록을 따른다」가 붙어 있다.
- AC2: 진입 SKILL.md 10개의 블록이 정본과 바이트가 같다(`test_plain_language_block.sh` GREEN).
- AC3: `token_boundary.py` 로 잰 결과 블록 변경 때문에 새로 밀려난 `## ` 절이 SKILL.md 10개 어디에도 없다(보수 · 중앙 두 값). 있으면 그 절과 값을 PR 본문에 공시한다.
- AC4: §2 의 ② 35 · ③b 7 자리가 모두 `꼬리` 또는 `지시` 이고, ③a 10 자리 가운데 `비움` 은 §2 의 셋(셋째는 찾은 경우만)뿐이며 나머지는 `꼬리` 또는 `지시` 다.
- AC5: 분해 판단 질문(finishing.md)에 지시 문장이 있고 권고 줄은 질문 위 글로 남아 있다.
- AC6: 리뷰 엔진 게이트 절차(reviewing-document.md 8단계)와 그것을 다시 적는 skill 들에 결정 질문 · 추가 라운드 질문의 지시 문장이 있다.
- AC7: 게이트 둘째 질문(proceed-gate.md)은 모델 제안을 첫 자리 + 「(권장)」으로 두고, 지휘자 아래 승인 질문은 네 곳(proceed-gate.md · conducting.md 두 곳 · spec-review SKILL)이 모두 「승인 — 계획 담당자에게 (권장)」이다.
- AC8: conductor-dispatch.md · conducting.md 의 옮김 규칙이 §3 대로다 — 수 · 순서 · 라벨 글자 유지, 꼬리 더함 허용, 지휘자가 만든 질문은 정본 규칙을 따름, 「(권장)」 금지 문장 없음.
- AC9: relay-checker 의 「볼 것」이 §3 대로다 — 꼬리 뗀 라벨 대조, 원문 꼬리가 빠지면 어긋남, 더한 꼬리는 어긋남 아님, 순서 어긋남은 그대로.
- AC10: 고른 라벨로 갈래를 나누는 산문 자리 전부(계획의 전수 목록)에 꼬리를 뗀 이름으로 읽는다는 문장 또는 그것을 갈음하는 문장이 있다 — conducting.md 「차례로」 확인 포함.
- AC11: pm-interview 라운드 규약이 「추천이 있으면 첫 선택지」로 바뀌고 «다음 결정» 줄이 「추천: 없음 — <이유>」를 허용한다. steelman 질문의 출처 표지는 그대로다.
- AC12: project-init 의 비표준 추천 표기(「clean history 권장」 · 「— default」)가 「(권장)」 꼬리로 바뀌었다.
- AC13: 새 전수 검사가 있고 §5 의 RED 넷을 낸다. 「(권장)」 · 「(Recommended)」 · 출처 꼬리를 종류에 맞게 센다. 지금 레포에서 GREEN 이다.
- AC14: 변이 다섯이 각각 새 검사를 RED 로 만든다 — `꼬리` 자리의 꼬리 지우기 · `지시` 자리의 지시 문장 지우기 · `비움` 자리의 이유 문장 지우기 · 목록에 없는 `AskUserQuestion` 줄 더하기 · 목록 앵커 하나를 파일에서 바꾸기. 양성 대조(변이 없는 원본 GREEN)를 함께 보인다.
- AC15: 라벨을 잠근 기존 테스트가 새 문면으로 고쳐졌고, 네 플러그인 + shared 테스트 전체가 기준(main) 대비 새 실패 없이 돈다. 음의 락을 지운 자리마다 양의 짝이 있다.
- AC16: 실행 중 개입이 없다 — 어느 `hooks.json` 도 바뀌지 않았고, `docreview_state.py` 의 `_CHOICE_LABEL` 과 엔진 정답 파일이 바뀌지 않았다.
- AC17: 바뀐 플러그인마다 `plugin.json` 판이 올랐고(minor — 규칙이 바뀐 새 표면) CHANGELOG 에 바뀐 것과 전수 검사의 한계(즉석 질문은 정본 규칙만이 집행)가 적혀 있다.

## Files to Modify

- `shared/style/plain-language.md` — §1.
- 진입 SKILL.md 10개 — 블록 동기화(plugin-audit · project-init · artifact-critique · quality-pipeline · epic-conductor · pm-interview · request-framing · reviewing-brief · roadmap-status · spec-review), 그리고 아래 질문 자리.
- 질문 자리(조사 7 기준, 계획이 전수로 확정): `plugins/spec-distill/skills/pm-interview/{SKILL.md,references/finishing.md,references/saturation.md,references/state-file.md}` · `plugins/spec-distill/skills/{spec-review,request-framing,reviewing-brief,epic-conductor}/SKILL.md` · `plugins/spec-distill/references/{proceed-gate.md,conducting.md,conductor-dispatch.md,trivia-escape.md,redecompose.md}` · `plugins/spec-distill/agents/relay-checker.md` · `plugins/quality-gates/skills/{quality-pipeline,artifact-critique}/SKILL.md` · `plugins/quality-gates/references/e2e.md` · `plugins/project-init/skills/project-init/SKILL.md` · `plugins/plugin-audit/skills/plugin-audit/SKILL.md` · `shared/docreview/references/reviewing-document.md`.
- 새 파일: `shared/tests/test_ask_recommendation.sh`(+ 필요하면 같은 이름의 `.py` 본체) · `shared/tests/fixtures/ask-sites.tsv`.
- 라벨 락 테스트(§6 목록, 테스트 전체 실행으로 확정).
- `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/.claude-plugin/plugin.json` · 각 `CHANGELOG.md`.

## Verification Plan

1. 고치기 전에 새 검사를 먼저 쓰고 지금 레포에서 RED 인지 본다(빠진 자리들이 ③ 으로 잡힘) — 그다음 자리를 고쳐 GREEN.
2. 변이 다섯 + 양성 대조(AC14). 변이 전에 커밋하고 `git checkout HEAD --` 로 되돌린 뒤 `git diff HEAD` 로 확인한다. `PYTHONDONTWRITEBYTECODE=1`.
3. `token_boundary.py --base main` 으로 SKILL.md 10개를 잰다(AC3).
4. 네 플러그인 + shared 테스트 전체를 main 과 이 브랜치에서 돌려 새 실패를 견준다(AC15). 셸 테스트는 shebang 셸로 돌린다.
5. 손 확인 한 번: 이 브랜치의 설치본으로 pm-interview 를 짧게 돌려 분해 판단 질문 · 리뷰 결정 질문에 꼬리가 실제로 붙는지 본다 — 정적 검사가 못 보는 실행 중 라벨(K4 · K13)의 표본이다. 결과는 PR 본문에 적는다.

## Rejected Alternatives

- 리뷰어 persona 에 추천 표시 검사 — 전수 검사와 겹친다(S16 · S20 · RC67).
- 실행 중 PreToolUse 훅으로 강제 — 범위 밖 외부 skill 질문에도 걸리고 P8 과 부딪치며, 순정 동작에 끼어든다(S13 · S23 · RC64).
- 「추천 없음 — 근거 부족」 남발 감시 — 바탕 자료가 없고(transcript 30일 삭제 «cc-cleanup») 이유 범주 바꿔치기를 부른다(S17 · RC100).
- 화면 본문에 「추천 없음 — <이유>」 — 억지 문구(S17), 이유는 skill 문서에만(S21).
- 출처 꼬리를 모든 질문의 표지로 — 추천이 실제로 갈리는 곳은 steelman 하나(S18 · S22).
- 추천 없는 질문을 위해 정본 블록에 「추천 없음 허용 경우 셋」을 싣기 — 모든 SKILL.md 에 복제돼 지시문이 늘고, 모델의 추천 판단을 오히려 흔든다(이 대화의 성능 걱정). 경우 셋은 이 설계문서와 `비움` 자리의 이유 문장에만 둔다.
- 각 질문 자리에 표식 주석(`<!-- ask: … -->`)을 다는 검사 — 모델이 읽는 파일에 토큰이 늘어난다. 목록은 테스트 쪽 파일에 둔다.
- 리뷰 엔진 라벨 표(`_CHOICE_LABEL`)에 꼬리를 박기 — 추천은 결정마다 갈려 고정할 수 없고 정답 파일 5개를 깨뜨린다.

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| 「(권장)」을 그대로 따르는 비율(과의존) 측정(K7) | 인터뷰 state 는 고른 라벨만, 지휘 relay 는 git 밖, transcript 는 30일 뒤 삭제 — 가를 바탕 자료가 없다 | 바탕 자료가 생기면 따로 설계 |
| 모델이 즉석에서 만드는 질문의 꼬리 빠짐(K5 · K4) | 정적 검사가 볼 수 없는 자리 — 정본 규칙만이 집행한다(D15 공시) | 변경 없음 — CHANGELOG 한계로 공시 |

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C1 · S1 · OQ1 · S3 | 반영 | Goals 1 · Context |
| D2 · S4 · OQ2 · RC58 · RC49 | 반영 | §1 · §2 분해 판단(`지시`) · AC5 |
| C3 · S6 | 반영 | §1 「여럿이면 모두」 · AC1 |
| D4 · S9 · OQ8 | 반영 | §1(도구 안에만) · §2 `비움` · §3(지휘자 규칙) · Constraints(「(Recommended)」 인정) |
| D5 · S11 · OQ5 | 반영 | §2 네 종류 · §5 후보 도출과 손 목록 |
| D6 · S14 · OQ10 · ST1 | 반영 | §1 3행 예외 · §2 분해 판단 · §3 · §6 |
| C7 · S17 · OQ12 · OQ3 · S5 | 반영 | §1 「추천이 없으면 아무 표시도 쓰지 않는다」 · Anti-goals · Rejected(감시 · 화면 문구) |
| D8 · S19 · OQ15 · RC146 | 반영 | §2 ③b · e2e · Fix-loop 를 `지시` |
| D9 · S20 · OQ11 · RC67 · S16 | 반영 | §5 「왜 리뷰어가 아니라 검사인가」 · Rejected |
| D10 · S21 · OQ16 | 반영 | §2 `비움` 이유 문장 · pm-interview «다음 결정» 상태 파일 |
| D11 · S22 · OQ13 · S18 | 반영 | §2 `출처꼬리` · §6 부재 락 유지 · AC11 |
| D12 · S23 · OQ17 · RC160 | 반영 | §1 첫 자리 · §2 pm-interview 202 고침 |
| D13 · S12 | 반영 | Non-goals |
| D14 · S27 | 반영 | §3 옮긴 질문 꼬리 · relay-checker 허용 · AC8 · AC9 |
| D15 · S28 | 반영 | §2 `지시` · §5 보지 않는 것 · AC17 한계 공시 |
| D16 · S29 | 반영 | §1 「이유는 질문 위 글에」 · §2 게이트 둘째 질문 |
| C17 · S23 · OQ19 | 반영 | Context(순정 동작 경계) · Anti-goals · §5 실행 지점 · AC3 · AC16 |
| D18 · S31 | 반영 | §2 리뷰 결정 질문 `지시` · `비움` 은 낮추거나 되올리는 질문만 |
| D19 · S7 · OQ6 | 반영 | §1 추천 없어도 되는 경우(블록 밖) |
| D20 · S35 · S30 | 반영 | §3 순서 · 라벨 글자 유지 · relay-checker 순서 대조 유지 |
| OQ4 · S13 · RC64 · K14 | 반영 | Anti-goals · Rejected(훅) · AC16 |
| OQ7 · S8 | 반영 | Context(보였는데 놓침 → 라벨 표시) |
| OQ9 · S10 | 반영 | Context(«cc-tool-desc» 꼴) · 미룸(과의존) |
| OQ14 · RC179 · RC178 · RC174 · RC124 | 반영 | §4 · §6 — 시작 목록 + 테스트 전체 실행으로 확정 · AC10 · AC15 |
| OQ18 · S24 | 반영 | 인터뷰 종료 결정 — 설계 입력 없음(포화 «아직» 은 §6 「시작 목록은 하한」으로 받음) |
| RC126 · K1 | 반영 | Context · §1(의무 조건 「추천이 있으면」) |
| RC57 · K2 | 반영 | §1 3행 예외 |
| K3 | 반영 | §2 `비움` 둘째(낮춘 지적 게이트) |
| K4 · RC63 · K13 · RC158 | 반영 | Verification 5 손 확인 · 미룸 · §6 엔진 라벨 |
| K5 · RC162 | 반영 | §3 relay-checker 꼬리 빠짐 대조 · 미룸(즉석 질문) |
| K6 | 반영 | §2 pm-interview 202 「추천이 있으면」 |
| K7 · RC163 | 반영 | 미룸 표 첫 줄 — 위험으로 받고 측정은 미룸 |
| K8 · RC161 | 반영 | §2 — 되묻기 규칙 그대로(새로 터질 자리 없음) |
| K9 | 반영 | Constraints · §5 두 꼬리 · §6 825 부재 락 |
| K10 | 반영 | §4 꼬리 떼고 읽기 · AC10 |
| K11 · K12 | 반영 | §6 · §1 블록 동기화 · AC2 · AC15 |
| RC100 | 기각 | Rejected(감시 장치) |
| S2 | 반영 | Goals 3 · 4 |
| S15 | 반영 | §4 · §6(OQ14) · §5(OQ19) — 넘겨받은 열린 질문을 이 설계가 정함 |
| S25 | 반영 | Metadata 크기 — spec 하나(이 문서 하나) |
| S26 | 반영 | brief 리뷰 결정 — Goal 근거(S6 · S20)는 Goals 2 · §5 에 |
| «ms-radio» · «ms-cmdlinks» | 반영 | Context · §1 — 추천은 보충 설명이 아니라 라벨에 |
| «cc-tool-desc» | 반영 | Context · §1 — 첫 자리 + 꼬리 꼴을 도구 습관에 맞춤 |
| «cc-sdk-approvals» | 반영 | 있는 것 검토 — 추천 필드 없음, 라벨 글자로만 |
| «cc-hooks» | 기각 | Rejected Alternatives — 실행 중 훅 |
| «gh-askuserquestion-hides-text» | 반영 | §1 — 표시는 라벨에(질문 위 글은 이유만, 사라져도 표시는 남음) |
| «default-effects» · «ai-overreliance» | 반영 | 미룸 — 과의존 측정 · §2 `비움`(낮춘 지적 게이트) |
| «apple-hig-alerts» | 반영 | §1 — 추천이 없으면 아무 표시도 쓰지 않음 |
| «cc-cleanup» | 반영 | Rejected Alternatives(감시) · 미룸 — 바탕 자료 없음 |
| S32 · S33 · S34 · S36 | 반영 | brief 리뷰 처분(기각 · 추가 라운드 안 함) — 설계 입력 없음 |

## Metadata

- 크기: 설계문서 → spec-review → 계획 → 구현(사용자 선호).
- 리뷰: 설계문서 점검(builder check) → `spec-distill:spec-review --bundle docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md`.
- 브랜치: brief · 설계는 `docs/askquestion-recommendation-brief`. 구현은 이 브랜치를 이어 `fix/askquestion-recommend-label` 로 판다(계획이 정해도 된다).
- 판 올림: spec-distill · quality-gates · project-init · plugin-audit 넷(shared 는 플러그인이 아니다 — brief 의 「다섯 영역」은 shared 를 센 것).
- persona 편집(relay-checker)을 포함한다 — 대조를 바꾸는 편집이라 보안 리뷰 대상으로 다룬다.
