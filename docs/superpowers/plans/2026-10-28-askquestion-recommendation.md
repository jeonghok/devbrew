# AskUserQuestion 추천 표시 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew 가 띄우는 모든 질문에서 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 달게 하고(여럿이면 모두), 질문 자리 전수 검사로 새 자리 · 빠진 표시를 레포 테스트에서 막는다.

**Architecture:** 정본 블록(`shared/style/plain-language.md`)의 두 문장을 고쳐 10개 SKILL.md 에 동기화하고, 질문 자리마다 종류(`꼬리` · `지시` · `비움` · `출처꼬리`)에 맞는 글자를 둔다. 새 검사(`shared/tests/test_ask_recommendation.sh` + 판정 모듈 `ask_recommendation.py` + 목록 `fixtures/ask-sites.tsv`)가 후보 줄을 도출해 목록과 대조한다. 지휘자 옮김 규칙과 relay-checker persona 는 §3 대로 고쳐 쓴다. 실행 중 개입(훅 · 엔진 라벨)은 없다.

**Tech Stack:** bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), Python 3.9 표준 라이브러리, git.

**Spec:** `docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md`

## Global Constraints

- 브랜치: 지금 브랜치(`docs/askquestion-recommendation-brief`)의 끝에서 `fix/askquestion-recommend-label` 을 판다.
- 정본 6행 새 문장(글자 그대로): `추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두, 이유는 질문 위 글에. 추천이 없으면 아무 표시도 쓰지 않는다.`
- 정본 3행에 붙일 문장(글자 그대로): `추천 표시는 그 자리에서도 이 블록을 따른다 — 옮긴 질문과 steelman 질문의 선택지 순서, steelman 질문의 출처 표지만 예외다.`
- 〔지시〕 문장(글자 그대로, 끝 마침표는 문맥대로): `권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다`
- 〔비움〕 문장 머리(글자 그대로): `추천을 달지 않는다 — ` 뒤에 그 자리의 이유. 화면에 내는 글이 아니라 skill 문서의 질문 옆에만 둔다.
- 〔뗌〕 문장(글자 그대로): `라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다`
- 「(Recommended)」도 꼬리로 센다. 스크립트 · 엔진 라벨(`docreview_state.py` `_CHOICE_LABEL` · golden) · `hooks.json` 은 고치지 않는다.
- 레포 전용 값을 박지 않는다 — 검사 대상은 `git ls-files` 글롭과 `find` 로 도출하고 수를 맞춘다.
- 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 가 `100755`. `# guards:` 머리를 달면 `--emit-scanned` 에 답한다. 파이썬은 파일을 열 때 `encoding="utf-8"`, 3.9 문법. 셸에서 한글 바로 앞의 변수는 `${v}`. 테스트는 `PYTHONDONTWRITEBYTECODE=1`.
- 판 올림(마지막 과제에서 한 번): spec-distill `8.11.0`→`8.12.0` · quality-gates `14.7.3`→`14.8.0` · project-init `5.3.3`→`5.4.0` · plugin-audit `1.6.0`→`1.7.0`, CHANGELOG 머리 `## [<판>] — <커밋 날짜>`.
- 커밋: Conventional Commits, 설명은 한국어(예: `fix(spec-distill): 분해 판단 질문에 추천 지시`). 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md`.
- 전체 스위트: 레포 루트에서 `bash tools/suite/run-all.sh`(`FAILED …` 줄이 실패). 스위트 둘을 같은 시각에 돌리지 않는다.
- relay-checker 편집은 persona 편집이다 — 보안 리뷰 대상(Task 6).

## Review Focus

- 〔지시〕 · 〔뗌〕 · 정본 블록 문장 안의 「(권장)」 언급이 `꼬리` 자리의 범위에 들어가 라벨에 꼬리가 없어도 통과하는 경우 — 꺾쇠 바로 뒤의 `(권장)`(「(권장)」)은 꼬리로 세지 않는다(Task 1 fixture).
- 범위 끝을 표시 문장 자체로 잡은 자리에서 표시가 지워지면 범위가 다음 질문까지 늘어나 이웃의 표시로 통과하는 경우 — 질문 범위가 다른 행의 앵커를 넘으면 RED(Task 1 fixture).
- 한 줄에 질문이 둘인 자리(finishing.md 의 승인 · 「계속 고칠까요」, conducting.md 의 승인 · 병렬 질문) — 질문마다 따로 잡은 범위로 판정한다(Task 1 fixture · Task 9 변이 6).
- 같은 파일이 심볼릭 링크로 한 번 더 보이는 경우(`plugins/spec-distill/references/reviewing-document.md` → shared 정본)와 아직 추적되지 않은 새 skill 문서 — 링크는 빼고 추적 안 된 파일은 넣어 git 과 find 수가 같다(Task 1).
- 고른 라벨을 값으로 생성 문서에 넣는 자리(project-init `{{MERGE_STRATEGY}}`) — 「Squash merge (권장)」이 AGENTS.md 에 새지 않게 〔뗌〕을 둔다(Task 8).

## 파일 구조

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `shared/tests/ask_recommendation.py`(새) | 목록 판독 · 범위 계산 · RED 판정, `ok`/`no` 줄 출력 | 1 |
| `shared/tests/test_ask_recommendation.sh`(새, 100755) | 후보 도출(git · find 양의 짝) · 모듈 호출 · fixture 판정 | 1 |
| `shared/tests/fixtures/ask-sites.tsv`(새) | 질문 자리 목록(자리별 표의 행) | 1 · 3–8 |
| `shared/tests/fixtures/ask_recommendation/`(새) | 판정 모듈 fixture(문서 하나 · 목록 하나 · 기대 줄) | 1 |
| `shared/style/plain-language.md` · SKILL.md 10개 블록 | 정본 두 문장 · 동기화 | 2 |
| pm-interview `SKILL.md` · `references/{finishing,saturation,state-file}.md` · `references/trivia-escape.md` | 인터뷰 질문 자리 | 3 |
| `references/proceed-gate.md` · `shared/docreview/references/reviewing-document.md` · spec-review · reviewing-brief SKILL · `references/redecompose.md` · epic-conductor SKILL | 게이트 · 리뷰 결정 질문 | 4 |
| request-framing `SKILL.md` | request-framing 질문 자리 | 5 |
| `references/conductor-dispatch.md` · `references/conducting.md` · `agents/relay-checker.md` | 지휘자 · 옮김 대조(§3) | 6 |
| quality-pipeline · artifact-critique SKILL · `references/e2e.md` | qg 질문 자리 | 7 |
| project-init · plugin-audit SKILL | 두 플러그인 질문 자리 | 8 |
| `plugin.json` 넷 · `CHANGELOG.md` 넷 | 판 · 바뀐 것 · 검사 한계 | 9 |

## AC 대응

| AC | 과제 |
|---|---|
| AC1 · AC2 | 2 |
| AC3 | 2(블록만) · 9(전체) |
| AC4 | 1(자리별 표 · 목록) · 3–8 |
| AC5 · AC11 | 3 |
| AC6 | 4 · 5 |
| AC7 | 4 · 6 |
| AC8 · AC9 | 6 |
| AC10 | 3–8(`떼기` 행) · 6(「차례로」) |
| AC12 | 8 |
| AC13 | 1 |
| AC14 · AC15 · AC16 · AC17 | 9(AC15 의 락 고침은 3–8 각자) |

## 검사의 꼴 (Task 1 이 짓고 3–8 이 채운다)

목록 `ask-sites.tsv` 는 한 줄에 `경로<TAB>종류<TAB>앵커<TAB>끝`. `#` 로 시작하는 줄과 빈 줄은 건너뛴다. 종류는 `꼬리` · `지시` · `비움` · `출처꼬리` · `언급` · `떼기`.

- **앵커** — 그 파일에서 정확히 한 번 나오는 한 줄 안의 글자. 질문의 첫 글자 쪽에 둔다(표시 문장보다 앞).
- **범위** — 끝이 있으면 앵커 시작부터 앵커 뒤 첫 `끝` 의 끝까지. 끝이 비면 앵커가 든 문단(빈 줄 사이).
- **질문 행**(`꼬리` · `지시` · `비움` · `출처꼬리`)의 범위 안에 다른 행(`떼기` 제외)의 앵커 시작이 있으면 안 된다 — 이것이 질문별 범위(결정 D1.2)를 집행한다. 표시 문장을 `끝` 으로 써도 되는 이유가 이것이다: 표시를 지우면 범위가 다음 질문의 앵커를 넘거나 `끝` 을 못 찾아 RED 다.
- **요구 글자** — `꼬리`: 정규식 `(?<!「)\((?:권장|Recommended)\)`(꺾쇠 안의 언급은 세지 않는다) · `지시`: 〔지시〕 · `비움`: `추천을 달지 않는다 — ` 가 있고 꼬리 정규식은 없다 · `출처꼬리`: `추천)` · `떼기`: 〔뗌〕 · `언급`: 없음.
- **후보 줄**(`AskUserQuestion` 이 있는 줄)은 어느 행의 앵커가 시작하는 줄이거나 어느 질문 행의 범위 안이어야 한다. 그래서 펜스 안의 `AskUserQuestion({` 줄은 그 위 산문 앵커의 범위로 덮고 따로 행을 두지 않는다(그 줄은 파일에서 여러 번 나와 앵커가 될 수 없다).
- **RED 넷**(판정 줄 머리에 번호): ① 덮이지 않은 후보 줄 ② 앵커가 0 · 둘 이상 · `끝` 없음 · 범위가 다른 행 앵커를 넘음 · 모르는 종류 ③ 범위에 요구 글자가 없음(또는 `비움` 에 꼬리) ④ 후보 0 이거나 git 수 ≠ find 수.

## 자리별 표 (AC4)

조사 7 의 55곳 · 그 밖 후보 줄 · 문장으로만 묻는 자리를 모두 담는다. 줄 번호는 a56a8054 기준이다. 「(있음)」은 이미 맞아 편집이 없는 자리다. 앵커 · 끝은 표에 적지 않는다 — 위 꼴대로 구현자가 고르고, 검사가 ② 로 잡는다. 〔내 판단〕은 설계가 정하지 않아 이 계획이 정한 것이다 — 계획 승인 때 볼 자리다.

### pm-interview · trivia-escape (Task 3)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| SKILL.md:200–203 라운드 규약 | 꼬리 | — | 「질문마다 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다」→「질문마다 추천이 있으면 첫 선택지에 두고 그 라벨 끝에 `(권장)` 을 단다」(AC11) |
| SKILL.md:190 «다음 결정» 줄 | (규약) | — | `· 추천: <첫 선택지>` →`· 추천: <첫 선택지 \| 없음 — <이유>>`. 180 「같은 형식이다」 뒤에 「— 단 «추천: 없음 — <이유>» 는 상태 파일에만 쓰고 화면의 질문에는 표시를 두지 않는다」. 216 의 「«추천: <첫 선택지>»」 언급도 같은 꼴로 |
| SKILL.md:207 되묻기 | (규약) | — | 「인터뷰어의 추측을 첫 선택지로 둔다」→「…첫 선택지로 두고 「(권장)」을 단다」〔내 판단 — 새 규칙에서 꼬리 없는 첫 자리는 추천이 아니다〕 |
| finishing.md:33–48 분해 판단 | 지시 | 권고 한 줄이 가리키는 쪽 | 펜스 뒤에 「〔지시〕 — 위 권고 한 줄이 가리키는 쪽이다.」 권고 줄(33)은 그대로(AC5). 48 「「spec 하나로」면」 앞에 〔뗌〕 |
| finishing.md:63 승인 질문 | 지시 | — | 모델 분해안 승인(③b). 「…(나누지 않고 Step A 로).」 뒤에 〔지시〕 |
| finishing.md:63 「계속 고칠까요」 | 지시 | — | 같은 줄 둘째 질문. 옵션 괄호 뒤에 〔지시〕 |
| finishing.md:260 닫은 답 되묻기 | 지시 | — | 줄 끝 뒤에 〔지시〕. 261–262 갈래에 〔뗌〕 |
| finishing.md:293 | 언급 | — | 도구 역할 설명 |
| finishing.md:319–334 재제시 상한 | 지시 | — | 펜스 뒤 한 줄 〔지시〕. 644–646 답 갈래에 〔뗌〕 |
| finishing.md:396 참고 접기 | 꼬리 | 참고 전부 보기 | 박제 전에 못 본 참고를 남기지 않는다. 「「참고 전부 보기 (권장)」 · 「접은 채로 둔다」」, 397 갈래에 〔뗌〕 |
| finishing.md:455 · 458 | 언급 | — | 머리말 · 설명 |
| finishing.md:465–520 B-2 게이트 | 꼬리(있음) | ① | — |
| finishing.md:528 게이트 둘째 질문 | 꼬리 | 모델의 제안 | §2 게이트 둘째 질문. 「「brainstorming (권장)」 · 「<모델의 제안>」」→「「<모델의 제안> (권장)」 · 「brainstorming」」 — Task 4 와 같은 꼴 |
| saturation.md:35 조사 상한 | 꼬리 | 같은 크기만큼 연장 | 「(첫 선택지가 추천)」을 지우고 첫 불릿 라벨을 「같은 크기만큼 연장 (권장)」, 이유 한 줄은 질문 위 글로. 37–41 갈래에 〔뗌〕 |
| saturation.md:95 같은 빈 곳 되풀이 | 지시 | — | 「…중 하나를 받는다.」 뒤 〔지시〕, 99–101 에 〔뗌〕 |
| saturation.md:110 판정 불가 | 지시 | — | 같은 꼴, 114–115 에 〔뗌〕 |
| saturation.md:125 판정 상한 | 지시 | — | 같은 꼴, 126–127 에 〔뗌〕 |
| state-file.md:51 | 꼬리(있음) | 이어 감 | — |
| steelman.md:92 | 출처꼬리 | — | 고치지 않는다(D11) |
| steelman.md:104 | 언급 | — | 자유 텍스트 |
| trivia-escape.md:13–28 | 꼬리 | 그대로 | 모델이 trivia 로 판정했을 때만 묻는 자리라 그 판정 쪽. `label: "그대로 (권장)"`, 28 다음에 〔뗌〕(29 · 35 갈래) |
| pm-interview SKILL.md:86 | 떼기 | — | 「「그대로」면 / 「전체 과정으로」면」 문단에 〔뗌〕(63 락 글자는 건드리지 않는다) |

### 게이트 · 리뷰 결정 질문 (Task 4)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| proceed-gate.md:28–30 Step B | 꼬리 | ① 권장 핸드오프 | 30 끝 「…질문 하나」):」→「…질문 하나」) — ① 의 라벨 끝에 `(권장)` 을 단다:」. 표 ① 행은 락이 있어 그대로 |
| proceed-gate.md:56 둘째 질문 | 꼬리 | 모델의 제안 | 「선택지는 그 skill 의 기본 다음 단계 `(권장)` 과 모델의 제안 둘이다.」→「선택지는 모델의 제안 `(권장)` 이 첫 자리, 그 skill 의 기본 다음 단계가 둘째다.」「제안 이유는 게이트 앞 글에」는 그대로(D16) |
| proceed-gate.md:60 지휘자 아래 승인 | 꼬리 | 승인 | 「「승인 — 계획 담당자에게 (권장)」 · 「수정 필요」(③ …) · 「멈춤」(④)」 |
| reviewing-document.md:28 결정 질문 | 지시 | — | 「…다음 호출로 미룬다.」 뒤 〔지시〕(AC6) |
| reviewing-document.md:35 · 36 추가 라운드 두 꼴 | 지시 | — | 각 「질문 하나다.**」 · 「얹지 않는다).」 뒤 〔지시〕. 39 · 80 「「추가 라운드 1회 열기」를 고르면」에 〔뗌〕 |
| reviewing-document.md:42 · profiles brief.md:83 · design-doc.md:97 | 언급 | — | 라벨 조립 규약 · 「네 개씩 나눠 묻는다」 |
| spec-review:184 문서 후보 | 비움 | — | 「…고르게 한다(추천을 달지 않는다 — 어느 문서를 리뷰할지는 사용자가 고른다)」 |
| spec-review:301 · reviewing-brief:177 표지 충돌 | 꼬리(있음) | 그만둠 | — |
| spec-review:552 · reviewing-brief:601 결정 질문 | 지시 | — | reviewing-document 와 같은 자리에 〔지시〕 |
| spec-review:558 · 559, reviewing-brief:607 · 608 추가 라운드 | 지시 | — | 같은 꼴. 562 · 611 갈래에 〔뗌〕 |
| spec-review:574 | 언급 | — | 라벨 조립 규약 |
| spec-review:635 참고 접기 | 꼬리 | 참고 전부 보기 | finishing:396 과 같은 질문 — 같은 판단. 636 갈래에 〔뗌〕 |
| spec-review:688 승인 2단계 | 꼬리(있음) | ① | — |
| spec-review:697 ③ 갈래 | 지시 | — | 지적에 따라 갈린다. 「(사용자 직접 편집).」 뒤 〔지시〕, 문단에 〔뗌〕 |
| spec-review:702 | (규약) | — | 「라벨에 「(권장)」, 설명에 이유 한 줄을 붙인다」→「라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다」(D16 · 정본 「설명에는 달라지는 것만」) |
| spec-review:766 지휘자 아래 승인 | 꼬리 | 승인 | 「「승인 — 계획 담당자에게」(권장)」→「「승인 — 계획 담당자에게 (권장)」」(AC7) |
| reviewing-brief:261 | 꼬리(있음) | 멈춘다 | — |
| reviewing-brief:267 | 언급 | — | 정의는 finishing Step A.5 |
| redecompose.md:52–65 | 꼬리 | 이대로 다시 나눈다 | 모델이 맞다고 본 새 표(③b). `label: "이대로 다시 나눈다 (권장)"` |
| epic-conductor:96 로드맵 고르기 | 비움 | — | 「…고르게 한다(추천을 달지 않는다 — 어느 로드맵을 지휘할지는 사용자가 고른다)」 |
| epic-conductor:116 | 꼬리(있음) | 읽기만 | — |
| epic-conductor:206 | 언급 | — | 질문 문장 규칙(옮김 문장은 Task 6 이 맞춘다) |

### request-framing (Task 5)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| 183–195 worktree | 꼬리(있음) | 만들고 시작 | — |
| 245–272 풀이 확인(다중 · 단일 꼴) | 지시 | — | 모델 풀이 승인(③b — AC4 가 꼬리/지시로 묶음). 272 뒤 「두 꼴 모두 〔지시〕.」, 271–272 갈래에 〔뗌〕 |
| 540 표지 충돌 | 꼬리(있음) | 그만둠 | — |
| 602 막힌 줄 | 꼬리 | 그 줄만 인용 표시로 감싼다 | 손대지 않으면 매 라운드 같은 자리에서 막힌다. 「「그 줄만 인용 표시로 감싼다 (권장) / 멈춘다」」, 603 갈래에 〔뗌〕 |
| 777 리뷰 결정 묶음 | 지시 | — | 「…나눠 띄웁니다.」 뒤 「결정 질문마다 〔지시〕 — 추가 라운드 「열기 / 열지 않음」도 같다.」(AC6) |
| 795 적용 / 적용하지 않음 | 지시 | — | 「…둘이다.」 뒤 〔지시〕, 797 · 799 갈래에 〔뗌〕 |
| 928 저자 편집 덩어리 | 비움 | — | 「**권장 표시를 달지 않는다** —」→「**추천을 달지 않는다** — 」(검사 글자에 맞춤 — 이유 문장 그대로) |
| 932 기준 사본 없음 | 비움 | — | 저자 편집과 승인된 편집을 가를 사본이 없어, 「이대로 둔다」를 권하면 저자가 자기 편집 전부를 스스로 승인한다(D2.4 의 일반형 — AC4 판정). 933 뒤 「추천을 달지 않는다 — 기준 사본이 없어 저자 편집이 섞였는지 가를 수 없고, 권하면 저자가 자기 편집을 스스로 승인한다.」 |
| 1119–1123 4옵션 게이트 | 꼬리 | ① | 비표준 「(권장, 커밋 후)」→「(권장)」, 「커밋 후」는 설명 쪽으로(RC144 와 같은 종류) |
| 1128 게이트 둘째 질문 | 꼬리 | 모델의 제안 | 「「인터뷰 (권장)」 · 「<모델의 제안>」」→「「<모델의 제안> (권장)」 · 「인터뷰」」 |
| 1169 덜어 낸 것 되살리기 | 비움 | — | 덜어 낸 것은 저자의 압축 편집이다(D2.4 의 일반형 — AC4 판정). 「· 「그대로 둔다」.」 뒤 「추천을 달지 않는다 — 덜어 낸 것은 저자의 압축 편집이라, 권하면 저자가 자기 편집을 남길지 스스로 정한다.」 |
| 72 trivia 갈래 | 떼기 | — | 「「그대로」면 / 「전체 과정으로」면」 문단에 〔뗌〕 |

### 지휘자 (Task 6)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| conducting.md:14 넘겨받기 | 꼬리 | 읽기만 | epic-conductor:116 과 같은 질문. 「…사용자에게 묻는다(「읽기만 (권장)」 · 「넘겨받기 — 그 세션은 쓰기를 멈춘다」).」 |
| conducting.md:14 「주인 모름」 worktree | 비움 | — | 「(고른 것만 지운다. 추천을 달지 않는다 — 주인 모를 worktree 를 지울지는 사용자만 안다)」〔내 판단 — 조사 7 밖에서 새로 찾은 자리〕 |
| conducting.md:28 사용자 몫 감사 | 지시 | — | 후보마다 갈린다 |
| conducting.md:29 · 100 | 언급 | — | — |
| conducting.md:35 · 101 흐름 승인 | 꼬리 | 고른 흐름 | 지휘자가 맞다고 판단한 흐름(③b). 「…승인받는다(「<고른 흐름>으로 (권장)」 · 「설계 흐름으로」 — 거절이면 설계 흐름)」 |
| conducting.md:39 · 101 지휘자 아래 승인 | 꼬리 | 승인 | 「「승인 — 계획 담당자에게 (권장)」 · 「수정 필요」 · 「멈춤」」(AC7) |
| conducting.md:40 · 101 병렬 | 꼬리(있음) | 병렬 | — |
| conducting.md:41 · 101 「차례로」 면 | 떼기 | — | 〔뗌〕(AC10 — K10 fail-open) |
| conducting.md:50 계획 검토 · 막힘 · 설계 의도 변경 (셋) | 지시 | — | 지휘자가 만든 질문 — 정본 규칙을 따른다. 102 · 103 의 같은 질문도 |
| conducting.md:71 · 72 · 109 · 114 | 지시 | — | 정리 뒤 남은 것 · 이슈 만들기 · 남은 리뷰 지적(③a 지만 지적을 낮추는 질문이 아님 — AC4) · 지우기 전 수정 파일 |

### quality-gates (Task 7)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| quality-pipeline:9 · 62 | 언급 | — | — |
| quality-pipeline:711 낮춘 지적 게이트 | 비움 | — | 펜스 뒤 「추천을 달지 않는다 — 낮춘 지적을 되올릴지는 리뷰 대상 코드를 쓴 쪽이 권할 수 없는 처분이다.」(D18 · K3) |
| quality-pipeline:819 범위 모드 | 지시 | — | 남은 지적의 무게에 따라 갈린다. 펜스 뒤 〔지시〕, 834–835 굵은 갈래에 〔뗌〕 |
| quality-pipeline:840 Fix-loop 첫 질문 | 지시 | — | §2. 머리(`### Fix-loop decision`)와 펜스 사이에 「첫 질문은 〔지시〕.」 |
| quality-pipeline:855 Fix-loop 둘째 질문(분류표) | 비움 | — | 분류표는 오케스트레이터가 자기 코드의 지적에 매긴 적용/제외다 — 지적을 낮추는 처분과 같은 성격(③a). 펜스 뒤 「추천을 달지 않는다 — 분류표는 오케스트레이터가 자기 코드의 지적에 매긴 적용/제외다.」〔내 판단〕. 873 「Branch on answer:」 다음 줄에 〔뗌〕 |
| quality-pipeline:923 Max-iter | 지시 | — | 머리와 펜스 사이에 「첫 질문은 〔지시〕.」 943 다음 줄에 〔뗌〕. 둘째 질문 자리표는 Fix-loop 둘째와 같다 |
| quality-pipeline:997 수정 실패 | 지시 | — | 실패 원인에 따라 갈린다. 펜스 뒤 〔지시〕 |
| quality-pipeline:1129 E4 걷기 직후 | 떼기 | — | 1150 「「지금 판정으로 끝내기」 · 「멈추기」면」 — 문단에 〔뗌〕 |
| artifact-critique:97 산출물 확인 | 지시 | — | 97 끝에 「〔지시〕 — 「예」 · 「아니오」는 〔뗌〕.」 |
| artifact-critique:134 멈출 때 | 지시 | — | 140 끝에 〔지시〕 |
| artifact-critique:176 첫 질문 | 꼬리 | 실행 | 사용자가 부른 대상 · 모드 그대로다. `**실행**`→`**실행 (권장)**`, 이유 한 줄은 질문 위 글 |
| artifact-critique:185 비평자 수 | 꼬리(있음) | 1명 | — |
| artifact-critique:293 NEEDS_RESOLUTION | 지시 | — | `degraded_reason` 에 따라 갈린다. 296 끝에 〔지시〕 |
| artifact-critique:351 상한 | 지시 | — | §2. 355 문단 앞에 〔지시〕 |
| e2e.md:35 시나리오 고르기 | 비움 | — | 명령 실행 승인(사용자 결정 2026-10-28). 35 줄은 락이 줄 전체를 잠가 그대로 두고 55 다음 새 줄 「추천을 달지 않는다 — 고르는 것이 곧 이 컴퓨터에서 명령을 실행해도 된다는 승인이다. 선택지 순서는 위 규칙 그대로 두고, 꼬리가 없는 첫 선택지도 추천이 아니다.」 |
| e2e.md:100 걷기 직후 게이트 | 지시 | — | 표(102–107) 뒤 새 줄 「〔지시〕. 고른 선택지는 〔뗌〕(이 절과 6 절의 갈래).」 |

### project-init · plugin-audit (Task 8)

| 자리 | 종류 | 추천 선택지 | 이유 · 편집 |
|---|---|---|---|
| project-init:72 · 78 · 132 · 189 · 247 | 꼬리(있음) | 교체 · 옮기기 · 더하지 않음 · 이대로 진행 · 옮기기 | — |
| project-init:106 워크플로 | 지시 | — | 레포 신호(`develop` 브랜치 · release 태그)에 따라 갈린다 — 문서에 고정하면 모든 사용자를 한쪽으로 이끈다(K7). 114 끝에 「〔지시〕 — 근거는 레포 신호(`develop` 브랜치 · release 태그)다.」 |
| project-init:122 commit scope | 비움 | — | 「추천을 달지 않는다 — 커밋 scope 는 팀이 고르는 관례라 모델이 권할 근거가 없다.」 |
| project-init:127 merge 전략 | 꼬리 | Squash merge | 127 끝에 「Squash merge 를 권한다 — 기록이 깔끔하다.」, 128 `- Squash merge (권장)`(AC12) |
| project-init:140 release 이름 | 꼬리 | `release/v*` | 140 끝에 「`release/v*` 를 권한다 — 템플릿의 꼴과 같다.」, 141 `` - `release/v*` (권장) ``(「— default」 제거, AC12) |
| project-init:148 헌장 갱신 | 지시 | — | Phase 0 스캔과 헌장 Tech Stack 이 어긋나는지에 따라 갈린다 |
| project-init:174 | 언급 | — | 머리말 |
| project-init:176–181 Phase 1 | 지시 | — | 자유 입력 셋(vision · non-goals · conventions)에는 선택지가 없어 추천 자리가 아니다. 넷째 tech-stack 확인은 모델 감지 결과 승인 — 181 끝에 〔지시〕. 행 하나(176 앵커, 181 까지) |
| project-init:193 필수 항목 빔 | 꼬리 | 건너뛰기 | 세 번 비었으면 지금은 답이 없다 — git 규칙만 만들고 헌장은 다시 실행해 채운다. 193 끝에 이유, 195 `「건너뛰기 (권장)」`〔내 판단 — 확신 중간〕 |
| project-init:66 · 92 · 245 | 떼기 | — | 「AGENTS.md 로 옮기기」 · 「옮기기」를 부르는 갈래 — 지금도 라벨과 어긋남 |
| project-init:185 · 199 · 261 | 떼기 | — | 「건너뛰기」 갈래 |
| project-init:220 · 229 | 떼기 | — | `<strategy>` 매핑 · `{{MERGE_STRATEGY}}` — 생성 문서에는 꼬리를 뗀 이름을 쓴다 |
| plugin-audit:84 축 고르기 | 꼬리(있음) | 여섯 축 전부 | — |
| plugin-audit:87 · 88 축 1~3 · 4~6 | 비움 | — | 괄호 끝에 「. 추천을 달지 않는다 — 볼 축은 사용자가 정한다」 |
| plugin-audit:88 하나도 안 고름 | 꼬리 | 다시 고르기 | 축 없이는 감사할 것이 없다. 「「다시 고르기 (권장)」 · 「중단」을 묻는다 — …」 |

### 기록만 하는 소비자 (바꾸지 않음, §4)

설계 §4 목록에 더해 조사가 찾은 것: request-framing:953 셸 `case "$choice"`(덩어리 처분 라벨을 글자로 비교 — 928 이 `비움` 이라 꼬리가 붙지 않고 모르는 값은 거부), `roadmap_write.py --approval` 재분해 이력, `--extra-approval` 의 `extra_rounds`. 모두 원문을 기록만 하거나 꼬리 없는 라벨만 받는다. PR 본문에 이 사실을 적는다(Task 9).

---

### Task 1: 전수 검사 · 목록 (AC4 · AC13 · AC17 머리 주석)

**Files:**
- Create: `shared/tests/ask_recommendation.py`
- Create: `shared/tests/test_ask_recommendation.sh` (100755)
- Create: `shared/tests/fixtures/ask-sites.tsv`
- Create: `shared/tests/fixtures/ask_recommendation/doc.md` · `sites.tsv` · `expected.txt`

**Interfaces:**
- Produces: `python3 shared/tests/ask_recommendation.py <root> <후보 파일 목록> <목록 tsv>` — stdout 에 `ok <설명>` / `no <①|②|③> <경로>:<줄> <설명>` 줄, rc 0(판정 완료) · rc 2(인자 · 파일 읽기 실패). 상수 `TAIL_RE` · `DIRECTIVE` · `EMPTY` · `SOURCE` · `STRIP` 는 Global Constraints 글자 그대로.
- Produces: `bash shared/tests/test_ask_recommendation.sh` · `--emit-scanned`.

- [ ] **Step 1: 브랜치를 판다**

```bash
git switch -c fix/askquestion-recommend-label
```

- [ ] **Step 2: 기준 실패 집합을 뜬다** — Run: `bash tools/suite/run-all.sh 2>&1 | grep '^FAILED' | sort > .git/askq-baseline-failed.txt` (편집 전 브랜치 끝 = main + 문서. git 이 추적하지 않는 자리). 뒤 과제의 「새 실패 없음」은 이 파일과 견준다.

- [ ] **Step 3: fixture 를 쓴다**

`doc.md` 에 여섯 경우를 짓는다: (가) 라벨 꼬리가 있는 `꼬리` 질문 (나) 범위에 〔지시〕 문장만 있고 라벨 꼬리는 없는 `꼬리` 질문 (다) 한 줄에 질문 둘 — 앞 질문은 꼬리 없음, 뒤 질문 「병렬 (권장)」 (라) 끝을 표시 문장으로 잡았는데 표시가 없는 `지시` 질문 바로 뒤에 표시가 있는 `지시` 질문 (마) 꼬리가 있는 `비움` 질문 (바) 어느 행에도 덮이지 않는 `AskUserQuestion` 줄. `sites.tsv` 는 그 행들, `expected.txt` 는 나와야 할 `no` 줄 정확히: (나) ③ · (다) 앞 질문 ③ · (라) ② 범위가 다른 행 앵커를 넘음 · (마) ③ · (바) ①. 원본(가)는 `ok`.

- [ ] **Step 4: 셸 테스트를 쓴다**

머리 30줄 안: `# guards: plugins/*/skills/*.md plugins/*/references/*.md plugins/*/agents/*.md shared/*/references/*.md shared/tests/ask_recommendation.py shared/tests/fixtures/ask-sites.tsv shared/tests/fixtures/ask_recommendation/*` 와 한계 둘 주석(「모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다」 · 「도구 이름 없이 문장으로만 묻는 새 질문 자리는 후보로 뽑히지 않는다 — 목록의 손 행은 지금 있는 자리만 덮는다」, AC17). 몸:
- 후보 파일: `git ls-files --cached --others --exclude-standard -- 'plugins/*/skills/*.md' 'plugins/*/references/*.md' 'plugins/*/agents/*.md' 'shared/*/references/*.md'` 에서 `/tests/` 와 심볼릭 링크(`[ -L ]`)를 뺀다. 양의 짝: `find plugins shared -type f \( -path 'plugins/*/skills/*.md' -o -path 'plugins/*/references/*.md' -o -path 'plugins/*/agents/*.md' -o -path 'shared/*/references/*.md' \) ! -path '*/tests/*'` 수와 `assert_eq` (지금 56 = 56). 후보 줄 수가 0 이면 `no ④`.
- `--emit-scanned`: 후보 파일 전부 · 모듈 · 목록 · fixture 파일을 찍고 끝낸다.
- 모듈을 fixture 로 한 번 돌려 `no` 줄이 `expected.txt` 와 같은지 `assert_eq`, 원본 목록으로 한 번 돌려 줄마다 `ok`/`no` 로 옮긴다(`test_plain_language_block.sh` 와 같은 꼴). `finish`.

- [ ] **Step 5: 모듈을 쓴다** — 위 「검사의 꼴」 그대로. 함수: `load_sites(path) -> list[Site]`(Site = 경로 · 종류 · 앵커 · 끝 · 목록 줄 번호), `scope(text, site) -> tuple[int, int] | str`(실패면 ② 사유), `check(root, files, sites) -> list[str]`, `main(argv) -> int`.

- [ ] **Step 6: fixture 판정이 맞는지 돌린다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/ask_recommendation.py shared/tests/fixtures/ask_recommendation <(echo doc.md) shared/tests/fixtures/ask_recommendation/sites.tsv`
Expected: `expected.txt` 의 다섯 `no` 줄과 (가)의 `ok`.

- [ ] **Step 7: 목록을 쓴다** — 자리별 표의 행마다 한 줄(편집 뒤 글자로 앵커 · 끝을 고른다), 그리고 `떼기` 행. 앞머리 `#` 주석에 열 이름. 「(있음)」 자리 · `언급` · `출처꼬리` 는 지금 글자로.

- [ ] **Step 8: 지금 레포에서 돌린다 — RED 가 정상이다(Verification 1)**

Run: `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep -c '✗'`
Expected: fixture · 양의 짝 단언은 ✓, ✗ 는 편집이 남은 행에서만 나온다. ① 이 하나라도 나오면 목록에 빠진 후보다 — 고친다. ✗ 수와 파일별 분포를 커밋 메시지 본문에 적는다(Task 3–8 이 줄여 0 으로 만든다).

- [ ] **Step 9: 커밋**

```bash
chmod +x shared/tests/test_ask_recommendation.sh
git add shared/tests/ask_recommendation.py shared/tests/test_ask_recommendation.sh shared/tests/fixtures/ask-sites.tsv shared/tests/fixtures/ask_recommendation
git ls-files -s shared/tests/test_ask_recommendation.sh   # 100755
git commit   # test(shared): 질문 자리 추천 표시 전수 검사 — Task 3–8 전까지 RED
```

### Task 2: 정본 규칙 · 블록 동기화 (AC1 · AC2 · AC3 블록 몫)

**Files:**
- Modify: `shared/style/plain-language.md:3,6`
- Modify: 블록 영역 — `plugins/*/skills/*/SKILL.md` 10개
- Modify: `shared/tests/test_plain_language_block.sh`(양의 락 둘)

**Interfaces:** 없음(문서).

- [ ] **Step 1: 실패하는 락을 더한다** — `test_plain_language_block.sh` 에 `assert_eq "$(grep -cF -- '<6행 새 문장>' "$ROOT/shared/style/plain-language.md")" "1" "AC1: 추천 문장"` 과 3행 예외 문장의 같은 단언, 그리고 옛 문장 「추천은 「(권장)」으로 표시한다.」 의 `assert_not_contains`.
- [ ] **Step 2: 돌려 RED 를 본다** — Run: `bash shared/tests/test_plain_language_block.sh` · Expected: 새 단언 셋 ✗.
- [ ] **Step 3: 정본 두 줄을 Global Constraints 글자대로 고친다**(3행은 「…그 절차를 따른다.」 바로 뒤에 붙인다).
- [ ] **Step 4: 10개 SKILL.md 의 `<!-- plain-language:begin -->` ~ `<!-- plain-language:end -->` 영역을 정본 내용으로 바꾼다**(파이썬 한 번 — 영역 밖 바이트는 건드리지 않는다).
- [ ] **Step 5: GREEN** — Run: `bash shared/tests/test_plain_language_block.sh` · Expected: ✗ 0.
- [ ] **Step 6: 블록만의 경계 이동을 잰다** — Run: `python3 tools/plain-language/token_boundary.py --base main` · 출력 전체를 `.git/askq-boundary-block.txt` 에 남긴다(git 이 추적하지 않는다). 「새로 밀린 절」이 `없음` 이 아닌 행이 있으면 그 절과 값을 Task 9 PR 본문 몫으로 메모한다(AC3).
- [ ] **Step 7: 커밋** — `fix(shared): 추천 표시 정본 — 첫 자리 · 꼬리 · 표시 없음`.

### Task 3: pm-interview · trivia-escape 질문 자리 (AC4 · AC5 · AC10 · AC11)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md`, `references/finishing.md`, `references/saturation.md`
- Modify: `plugins/spec-distill/references/trivia-escape.md`
- Modify(락): `plugins/spec-distill/tests/test_conducting_interview_stage.sh:496` · `test_saturation_reference.sh:60` · `test_distortion_devices.sh:57 · 125`

**Interfaces:** 자리별 표 「pm-interview · trivia-escape」 행. 〔지시〕 · 〔뗌〕 · 〔비움〕 글자는 Global Constraints. finishing.md:528 은 Task 4 의 게이트 둘째 질문 꼴과 같게 바꾼다(이 과제에서 바꾼다).

- [ ] **Step 1: 락을 새 글자로 먼저 바꾼다** — 496 은 「질문마다 추천이 있으면 첫 선택지에 두고 그 라벨 끝에 `(권장)` 을 단다」, saturation 60 은 「같은 크기만큼 연장 (권장)」, distortion 57 은 `label: "그대로 (권장)"`, 125 는 「「참고 전부 보기 (권장)」」(이빨 강화). `test_end_gates.sh:47` 은 「「<모델의 제안> (권장)」 · 「brainstorming」」.
- [ ] **Step 2: RED** — Run: 위 넷 + `test_end_gates.sh` · Expected: 바꾼 단언이 ✗.
- [ ] **Step 3: 표대로 편집한다.**
- [ ] **Step 4: GREEN** — Run: 위 테스트 + `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep '✗' | grep -E 'pm-interview|trivia-escape'` · Expected: 앞 테스트 ✗ 0, 둘째 명령 출력 없음.
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Run: `bash tools/suite/run-all.sh 2>&1 | grep '^FAILED' | grep -v test_ask_recommendation | sort | comm -13 .git/askq-baseline-failed.txt -` · Expected: 출력 없음.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 인터뷰 질문 자리 추천 표시`.

### Task 4: 게이트 · 리뷰 결정 질문 (AC4 · AC6 · AC7 · AC10)

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md`, `plugins/spec-distill/references/redecompose.md`
- Modify: `shared/docreview/references/reviewing-document.md`
- Modify: `plugins/spec-distill/skills/{spec-review,reviewing-brief,epic-conductor}/SKILL.md`
- Modify(락): `test_entry_guidance.sh:46` · `test_seed_at_path_handoff.sh:154` · `test_decompose_surface.sh:120` · `test_review_handoff_order.sh:193`

**Interfaces:** 자리별 표 「게이트 · 리뷰 결정 질문」 행. 승인 질문 꼴 「승인 — 계획 담당자에게 (권장)」은 Task 6 의 conducting.md 두 곳과 글자가 같다(AC7). 게이트 둘째 질문 꼴은 Task 3 · 5 의 finishing:528 · request-framing:1128 과 같다.

- [ ] **Step 1: 락을 새 글자로 바꾼다** — 46 · 154 는 「「승인 — 계획 담당자에게 (권장)」 · …」, 120 은 `"이대로 다시 나눈다 (권장)"`, 193 은 spec-review:702 새 문장. `shared/tests/test_docreview_round_gate_split.sh` 에 reviewing-document.md 의 〔지시〕 존재 단언 하나를 더한다(AC6 양의 락).
- [ ] **Step 2: RED** — Run: 위 테스트들 · Expected: 바꾼 · 더한 단언 ✗.
- [ ] **Step 3: 표대로 편집한다.** reviewing-document.md 는 shared 정본만 고친다(spec-distill 쪽은 링크).
- [ ] **Step 4: GREEN** — Run: 위 테스트 + `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep '✗' | grep -E 'proceed-gate|redecompose|reviewing-document|spec-review|reviewing-brief|epic-conductor|docreview-profiles'` · Expected: 앞 ✗ 0, 둘째 출력 없음.
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Run: `bash tools/suite/run-all.sh 2>&1 | grep '^FAILED' | grep -v test_ask_recommendation | sort | comm -13 .git/askq-baseline-failed.txt -` · Expected: 출력 없음.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 게이트 · 리뷰 결정 질문 추천 표시`.

### Task 5: request-framing 질문 자리 (AC4 · AC6 · AC10)

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`
- Modify(락): `test_request_framing_open.sh:102` · `test_framing_review_contract.sh:141`

**Interfaces:** 자리별 표 「request-framing」 행. 1128 의 꼴은 Task 4 의 proceed-gate:56 과 같다.

- [ ] **Step 1: 락을 새 글자로** — 102 는 「「<모델의 제안> (권장)」 · 「인터뷰」」, 141 은 「추천을 달지 않는다 — 」.
- [ ] **Step 2: RED** — 두 테스트 · Expected: 바꾼 단언 ✗.
- [ ] **Step 3: 표대로 편집한다.**
- [ ] **Step 4: GREEN** — 두 테스트 + `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep '✗' | grep request-framing` · Expected: ✗ 0, 출력 없음.
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Task 3 Step 5 와 같다.
- [ ] **Step 6: 커밋** — `fix(spec-distill): request-framing 질문 자리 추천 표시`.

### Task 6: 지휘자 · 옮김 대조 (AC4 · AC7 · AC8 · AC9 · AC10) — persona 편집, 보안 리뷰 대상

**Files:**
- Modify: `plugins/spec-distill/references/conductor-dispatch.md:32`
- Modify: `plugins/spec-distill/references/conducting.md`(14 · 28 · 35 · 39 · 41 · 50 · 71 · 72 · 101 · 102 · 103 · 109 · 114)
- Modify: `plugins/spec-distill/agents/relay-checker.md:6,31–33,35`
- Modify: `plugins/spec-distill/skills/epic-conductor/SKILL.md:206`(옮김 문장)
- Modify(락): `test_conductor_dispatch_reference.sh:24–34` · `test_conducting_reference.sh:62,117–118` · `test_conducting_loop.sh:31` · `test_epic_conductor_skill.sh:72–77`

**Interfaces:** 자리별 표 「지휘자」 행과 아래 새 규칙 글자.

새 규칙 글자(설계 §3):
- conductor-dispatch.md:32 — 선택지 수 · 순서 · 라벨 글자 유지와 「고르면 무엇이 달라지나」는 그대로 두고, 「지휘자 자신의 권장은 라벨 안 … 지휘자가 만든 질문에서도 같다.」 · 「skill 이 문장으로 낸 권장 … 라벨은 원문 라벨 그대로다.」 · 「그 선택지에는 「(권장)」을 달지 않는다」를 지우고 이 셋을 넣는다:
  - `원문이 라벨에 붙인 「(권장)」 꼬리는 그대로 둔다. 꼬리를 더하는 길은 둘이다 — 원문이 문장으로 낸 권장(예: 「I recommend …」)은 그 선택지 라벨 끝에 「(권장)」을 달고, 지휘자 자신의 권장도 그 선택지 라벨 끝에 「(권장)」을 단다(원문 권장과 다른 선택지면 둘 다 단다). 지휘자가 꼬리를 달면 선택지 밖 「지휘자 의견:」 한 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다.`
  - 지휘자가 만든 질문: `… 「지휘자가 만든 질문」 으로 표시하고, 정본 규칙대로 추천이 있으면 첫 자리에 두고 라벨 끝에 「(권장)」을 단다(…).`
  - 답: `사용자 답은 지휘자가 더한 꼬리를 뗀 원문 라벨 글자로 같은 agent 에 돌려준다.`
- conducting.md:102 — 같은 뜻으로: 수 · 순서 · 라벨 글자와 원문 꼬리는 그대로, 꼬리를 더하는 길은 `conductor-dispatch.md` 의 둘, 지휘자가 단 꼬리는 「지휘자 의견:」 한 줄에 출처와 이유, 답은 지휘자가 더한 꼬리를 뗀 원문 라벨 글자로 돌려보낸다.
- relay-checker.md 「볼 것」:
  - 3: `3. 라벨 — 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 라벨(돌려줄 값)이 글자 그대로 같은가.`
  - 4: `4. 「(권장)」 — 원문이 붙인 꼬리가 띄운 질문에 그대로 있는가 — 빠졌으면 어긋남이다(「원문 꼬리 빠짐」). 원문에 없던 꼬리는 둘 중 하나일 때만 일치다: 원문이 문장으로 낸 권장이 가리킨 선택지이거나, 「지휘자 의견:」 줄이 그 선택지를 지휘자 권장으로 밝히고 이유를 단 경우. 그 밖의 꼬리는 어긋남이다 — 「출처 없는 꼬리」 라고 적는다. 지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다(「지휘자 의견:」 은 선택지 밖 한 줄이다).`
  - 5: `5. 사용자 답 — 하위에게 돌려보낸 글에 꼬리를 뗀 원문 라벨 글자 그대로 있는가.`
  - 35: 「그때도 그 질문의 선택지 … 「지휘자가 만든 질문의 라벨에 (권장)」 이라고 적는다(…).」를 `그 질문은 정본 규칙을 따르므로 라벨의 「(권장)」 꼬리는 일치이고, 지휘자 의견이 선택지 설명 안에 들어간 것만 어긋남이다.` 로, 끝의 「표시 없이 원문에 없는 선택지 · 「(권장)」 이 띄운 질문에 있어도 어긋남이다」를 `표시 없이 원문에 없는 선택지가 띄운 질문에 있어도 어긋남이다(원문에 없는 꼬리는 4 대로 본다)` 로. 2(순서)는 그대로(D20).
  - description(6): `compares choices (count · order · labels with the 「(권장)」 tail stripped · where each 「(권장)」 tail came from)`.

- [ ] **Step 1: 락을 새 규칙 글자로 바꾼다** — 지운 문장의 음의 락(「지휘자 자신의 권장은 라벨 안 …」 · 「그 선택지에는 「(권장)」을 달지 않는다」 · 「문장 권장이 라벨 꼬리로 옮겨짐」 · 「지휘자가 만든 질문의 라벨에 (권장)」)마다 양의 짝(새 문장의 존재 — 「출처 없는 꼬리」 · 「원문 꼬리 빠짐」 · 「지휘자가 더한 꼬리를 뗀 원문 라벨 글자」 · 「둘 다 단다」)을 둔다(AC15). 지운 문장은 부재 단언으로 바꾼다. conducting 승인 글자는 「「승인 — 계획 담당자에게 (권장)」」.
- [ ] **Step 2: RED** — Run: 위 넷 · Expected: 바꾼 단언 ✗.
- [ ] **Step 3: 새 규칙 글자와 표대로 편집한다.**
- [ ] **Step 4: GREEN** — 위 넷 + `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep '✗' | grep -E 'conducting|conductor-dispatch|relay-checker'` · Expected: ✗ 0, 출력 없음. 「차례로」 `떼기` 행 ✓(AC10).
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Task 3 Step 5 와 같다.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 지휘자 옮김 꼬리 두 길 · relay-checker 대조`. 본문에 「persona 편집 — 푸는 대조: 문장 권장 꼬리(D14) · 지휘자 권장 꼬리(설계 판단). 새로 막는 대조: 원문 꼬리 빠짐 · 출처 없는 꼬리」.

### Task 7: quality-gates 질문 자리 (AC4 · AC10)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`, `skills/artifact-critique/SKILL.md`, `references/e2e.md`
- Modify(락): `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh:73`

**Interfaces:** 자리별 표 「quality-gates」 행. `label: "<l>"` 닫는 따옴표를 잠근 `test_plain_qg_templates.sh:54-55` · e2e.md:35 줄 전체 락(`test_e2e_docs.sh:319,328`) · 「Branch on answer:」 줄 락(`test_plain_qg_templates.sh:166`)은 건드리지 않는 자리에 글을 넣는다.

- [ ] **Step 1: 락을 새 글자로** — 73 은 `'**실행 (권장)**'`.
- [ ] **Step 2: RED** — Run: `bash plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh` · Expected: 그 단언 ✗.
- [ ] **Step 3: 표대로 편집한다.**
- [ ] **Step 4: GREEN** — 그 테스트 + `test_plain_qg_templates.sh` · `test_e2e_docs.sh` · `test_range_wiring.sh` · `test_lowered_gate_wiring.sh` + `bash shared/tests/test_ask_recommendation.sh 2>&1 | grep '✗' | grep quality-gates` · Expected: ✗ 0, 출력 없음.
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Task 3 Step 5 와 같다.
- [ ] **Step 6: 커밋** — `fix(qg): 질문 자리 추천 표시`.

### Task 8: project-init · plugin-audit 질문 자리 (AC4 · AC10 · AC12)

**Files:**
- Modify: `plugins/project-init/skills/project-init/SKILL.md`, `plugins/plugin-audit/skills/plugin-audit/SKILL.md`
- Modify(락): `plugins/project-init/tests/test_command_contract.py:458-459`

**Interfaces:** 자리별 표 「project-init · plugin-audit」 행.

- [ ] **Step 1: 락** — 458-459 를 「「건너뛰기 (권장)」」 로 강화하고, AC12 양 · 음 단언을 더한다: 「Squash merge (권장)」 존재 · 「clean history 권장」 · 「— default」 부재.
- [ ] **Step 2: RED** — Run: `python3 -m unittest discover -s plugins/project-init/tests -p 'test_command_contract.py'` · Expected: 새 단언 FAIL.
- [ ] **Step 3: 표대로 편집한다.**
- [ ] **Step 4: GREEN** — 그 테스트 + `plugins/plugin-audit/tests/test_skill_orchestration.py`(84 줄 `count==1` 락) + `bash shared/tests/test_ask_recommendation.sh` · Expected: 셋 다 실패 0. 전수 검사가 이제 처음으로 전부 ✓(AC13).
- [ ] **Step 5: 새 실패 없음(기준 대비)** — Run: `bash tools/suite/run-all.sh 2>&1 | grep '^FAILED' | sort | comm -13 .git/askq-baseline-failed.txt -` · Expected: 출력 없음(전수 검사도 이제 실패가 없어야 한다).
- [ ] **Step 6: 커밋** — `fix(project-init): 비표준 추천 표기를 꼬리로` (plugin-audit 포함).

### Task 9: 변이 · 대조 · 판 (AC3 · AC14 · AC15 · AC16 · AC17)

**Files:**
- Modify: `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/.claude-plugin/plugin.json` · 각 `CHANGELOG.md`

- [ ] **Step 1: 변이 여섯 + 양성 대조(AC14)** — 작업 트리가 깨끗한지 `git status --porcelain` 으로 보고(빈 출력), 변이마다 한 파일을 고쳐 `bash shared/tests/test_ask_recommendation.sh` 가 ✗ 를 내는지 보고 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 빈 출력을 확인한다. `PYTHONDONTWRITEBYTECODE=1`. 변이: ① `꼬리` 자리(proceed-gate.md:60)의 「(권장)」 지우기 → ③ ② `지시` 자리(finishing.md 분해 판단)의 〔지시〕 지우기 → ③ 또는 ② ③ `비움` 자리(e2e.md 새 줄)의 이유 문장 지우기 → ③ 또는 ② ④ 어느 질문 범위 밖(예: plugin-audit SKILL 끝)에 `AskUserQuestion` 줄 더하기 → ① ⑤ 목록 앵커 하나(spec-review:184 행)를 파일에서 바꾸기 → ② ⑥ conducting.md 승인 질문의 「(권장)」만 지우고 바로 다음 병렬 질문의 「병렬 (권장)」은 남기기 → ③. 변이 없는 원본은 ✗ 0(양성 대조). 결과 표(변이 · 기대 · 실제 판정 줄)를 PR 본문 몫으로 남긴다.
- [ ] **Step 2: 전체 스위트를 기준과 견준다(AC15)** — Task 8 Step 5 명령을 판 올림 뒤에 다시 돌린다(Step 5 다음). Expected: 기준에 없는 실패 0. 셸 테스트는 shebang 셸로 돈다(스위트가 그렇게 부른다). 기준 파일이 편집 전 브랜치 끝(main + 문서 커밋)에서 뜬 것임을 PR 본문에 적는다.
- [ ] **Step 3: 실행 중 개입 없음(AC16)** — Run: `git diff main --stat -- 'plugins/*/hooks/hooks.json' shared/docreview/scripts/docreview_state.py 'shared/docreview/tests/golden'` · Expected: 빈 출력.
- [ ] **Step 4: 경계 전체를 잰다(AC3)** — Run: `python3 tools/plain-language/token_boundary.py --base main > .git/askq-boundary-all.txt`. Task 2 의 블록만 값과 견주어, 새로 밀린 절이 있으면 절 · 값 · 민 쪽(블록 · 질문 자리 문장)을 PR 본문 몫으로 적는다.
- [ ] **Step 5: 판 · CHANGELOG(AC17)** — Global Constraints 의 네 판으로 올리고, 각 CHANGELOG 에 `### Changed`(정본 추천 규칙 · 그 플러그인의 질문 자리) 와 spec-distill 에 `### Security`(relay-checker 대조 변경 — 푸는 것 · 새로 막는 것), 그리고 전수 검사의 한계 둘(테스트 머리 주석과 같은 글)을 적는다. Run: `bash shared/tests/test_changelog_integrity.sh` · Expected: ✗ 0.
- [ ] **Step 6: 커밋** — `chore: 판 올림 — 추천 표시 규칙`.
- [ ] **Step 7: 손 확인 자리(Verification 5)** — 이 브랜치 설치본으로 pm-interview 를 짧게 돌려 분해 판단 · 리뷰 결정 질문에 꼬리가 붙는지 보는 일은 사람이 한다(헤드리스는 Skill 도구를 거부한다). PR 본문에 「손 확인: 미실행 — 사람 몫」 칸을 두고, 사람이 돌리면 결과를 적는다.

## 마지막 전체 리뷰 (실행 방식 공통)

- 브랜치 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC1–AC17 을 싣고, 리뷰가 AC 마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거>` 로 보고하게 한다. 그 보고를 `.git/askq-ac-report.txt`(git 이 추적하지 않는 자리)에 적는다.
- 리뷰에 함께 묻는다: Task 사이 이음매(승인 질문 글자 네 곳 · 게이트 둘째 질문 세 곳이 같은가), 목록 행과 실제 편집의 대응, relay-checker 편집의 보안 측면(푸는 대조 · 새로 막는 대조), 계획이 쓴 테스트 코드(Task 1 fixture · 모듈)도 같은 기준으로 볼 것.
- 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다.
- PR 을 만들기 전에 `python3 <spec-distill 플러그인 루트>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md .git/askq-ac-report.txt` 를 돌려 경고를 사용자에게 보인다.
