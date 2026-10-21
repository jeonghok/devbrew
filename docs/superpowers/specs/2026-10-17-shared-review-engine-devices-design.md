---
name: shared-review-engine-devices
type: design
created_at: 2026-10-17
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R2a.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R2a — 공유 리뷰 엔진 · qg 파급 · persona 보안 리뷰 · Design

> 공유 리뷰 엔진과 qg · 다른 플러그인의 의도 왜곡 장치를 제거하거나 고치고, persona 편집은 보안 리뷰를 거친다 — 꼴을 하나씩 막지 않고 원인을 치우거나 허용 문법 하나로 읽는다.

승인된 로드맵(S47)의 에픽 R2a 다. 자리는 `roadmap.md` 의 `### R2a` 블록이고 이웃 R5 · R10 · R11 과 병렬로 간다(의존 R1 · R2 · R7 · R3 · R4 · R6 · P2 · P3 — 모두 머지됨). R5 계획 셋째가 이 에픽의 계획 1(테스트 실행 공유본)을 기다린다.

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 장치 처분표](#1-장치-처분표)
  - [§2 계획 1 — 결함 셋 · 테스트 실행 공유본 · qg 진입 이름](#2-계획-1--결함-셋--테스트-실행-공유본--qg-진입-이름)
  - [§3 계획 2 — 공유 엔진 · R2 보안 잔여](#3-계획-2--공유-엔진--r2-보안-잔여)
  - [§4 계획 3 — qg 장치 · 범위 입력 · persona](#4-계획-3--qg-장치--범위-입력--persona)
  - [§5 계획 4 — project-init · plugin-audit](#5-계획-4--project-init--plugin-audit)
  - [§6 온톨로지](#6-온톨로지)
  - [§7 상류 · 하류 연계](#7-상류--하류-연계)
  - [§8 있는 것 검토 · 레포 전용 값](#8-있는-것-검토--레포-전용-값)
  - [§9 위험에 대한 답](#9-위험에-대한-답)
  - [§10 계획 나누기](#10-계획-나누기)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [결정 기록](#결정-기록)
- [번호 대조](#번호-대조)
- [미룸](#미룸)
- [Metadata](#metadata)
- [판정](#판정)
- [구현 대조 — 계획 1](#구현-대조--docssuperpowersplans2026-10-18-r2a-plan1-defects-test-selection-qg-entrymd)

## Handoff Context

- 묶음: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R2a.md` — 정답 출처. 원본 brief 는 `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md`.
- 범위 입력: 로드맵 R2a 블록 범위 줄 전부, `flexibility-audit.md` 의 「결함」 세 행과 「R2a」 절, R5 설계문서 `## 미룸` 의 R2a 두 행, R2 PR(#217) 본문 「알려진 우회」 · 「통합 리뷰 인계」의 R2a 몫.
- 설계 대화(2026-10-17, 지휘 세션이 직접 brainstorming)의 사용자 결정은 `## 결정 기록` 에 원문 그대로 둔다.

## Context / Why

사용자는 「내 의도를 왜곡하는 장치들 다 제거야」(S3) · 「아님 수정이나」(S4) 라고 했고, 판정 기준은 S10 으로 골랐다 — 장치 전부 대상, 비용 · 절감 · 압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한 · 압축은 공시하고 사용자가 여는 형태로 수정, 그대로 남는 것 0. R2 가 spec-distill 안쪽 장치를 맡았고, 이 에픽은 그 바깥 — 네 진입이 함께 쓰는 공유 리뷰 엔진(`shared/docreview/`), qg, project-init · plugin-audit — 를 맡는다.

그 사이 쌓인 사실:

- 공유 엔진은 탐지 리뷰어를 1명으로 고정하고, 라우터는 같은 이름 지적 블록이 여럿이면 마지막 것만 읽는다(`docreview_route.py:37-42` — 앞 블록이 계수 없이 사라진다). 재리뷰 상한 2 · 조언 8줄 접기 · 60자 자르기는 코드 상수다.
- qg 는 리뷰어 8명을 diff 의 기계 신호로만 고르고, 수정 루프 5회를 「예외 없음」으로 닫으며, 리뷰어 둘을 opus 로 고정했고, 「문서 경로」를 정의 없이 리뷰에서 뺀다. 진입은 아직 `commands/qg.md` 이고(P3 결정은 skill 진입), 의도 출처는 범위 안의 가장 새 `Spec:` 하나에서 멈춘다.
- R2 는 보안 검사 둘(원장 쓰기 락 · brief 쪽 판독)을 꼴을 하나씩 막는 방식으로 고쳤고, 마지막 재리뷰가 남긴 우회 다섯을 「공시하고 R2a 로 (권장)」로 넘겼다. 같은 축에서 우회가 계속 나온 것은 방식(흉내 파서)이 원인이다.
- R5 는 qg 의 테스트 실행 스크립트 셋을 `shared/` 공유본으로 쓰기로 했고(R5 D1.3), 그 이동을 이 에픽에 맡겼다.

## Goals

- §1 처분표의 장치 전부를 제거하거나 수정한다 — 그대로 남는 장치 0(S10 · D18 · C11 · C12 · C13).
- 결함 셋을 먼저 고친다 — 특히 지적 블록 버림은 여러 탐지 리뷰어를 열기 전에.
- R2 보안 잔여를 「허용 문법 + 실제 파서 교차 확인」으로 닫고, 원인을 치울 수 있는 곳은 치운다.
- qg 진입 이름(P3)을 적용하고, 범위 입력과 여러 설계문서 의도를 더하고, 테스트 실행 스크립트를 `shared/test-selection/` 으로 옮긴다.
- persona 편집은 보안 리뷰를 거쳐 PR 에 기록한다 — R2a 가 고치는 리뷰어 persona 전부(qg 의 `security-reviewer` · `code-recritic`, plugin-audit 의 `plugin-auditor` · `audit-refuter`)가 대상이다(D1.2).
- 장치 조사는 계속 연다 — 설계 · 계획 · 구현 중 새로 찾은 장치는 같은 기준으로 §1 에 더한다(D15 · OQ29).

## Non-goals

- spec-distill 안쪽 장치(R2 가 했다). 단 R2 가 넘긴 보안 잔여의 검사 방식 전환은 이 에픽이 spec-distill 스크립트에서 한다(범위 줄).
- 외부 플러그인(superpowers · pr-review-toolkit)의 파일 · 동작(C25 · C35 · D26) — qg 가 dispatch 하는 외부 리뷰어는 부르는 쪽만 바꾼다.
- 지휘 · 에픽 사이 통합 리뷰(R5) — qg 를 통합 리뷰용으로 넓히지 않는다.
- 규칙 문면(R9) · 원칙 문서 정리와 README · CHANGELOG 의 낡은 개념 정리(R11) — 이 설계가 바꾸는 동작을 설명하는 줄만 이 에픽이 고친다.
- 개선을 재는 별도 측정 장치(S32).

## Constraints

- S10 판정 기준(D18). 유지하는 것은 장치가 아니라 안전장치다 — Law 2 · `tools:` allowlist · kill switch · 사용자 승인 게이트 · 루프 상한 · 보안 · 정확성 검사 · security-reviewer 웹 금지.
- 장치를 치우기 전에 그 장치가 지키던 요구를 적는다(«chesterton-fence») — §1 의 「지키던 것」 칸.
- 있는 것을 다시 만들지 않는다(C32 · S30) — 엔진의 사용자 문구 라운드 열기 · 회계 모듈 · 심볼릭 링크 공유 · `seed_body` 의 허용 문법 방식을 그대로 쓴다. 외부 도구는 사용자 검토 뒤에만(markdown-it-py — B2).
- 레포 전용 값을 박지 않는다 — 기본 브랜치는 `origin/HEAD` 에서, 상한 · 문서 경로 패턴은 설정으로(§8).
- 플러그인 버전은 계획마다 bump 하되 번호는 머지 직전에 정한다. 호출 이름이 바뀌는 qg 는 major.
- 셸 테스트는 실행 비트(100755)로, 스크립트 read 는 UTF-8 명시로, 플러그인 `.py` 에 `python3` 리터럴 없이(레포 락).

## 설계

### §1 장치 처분표

처분은 S10 을 그대로 적용한다. 「지키던 것」은 그 장치가 막던 실패다 — 수정은 그 실패를 다른 방법(공시 · 사용자가 여는 길)으로 계속 막는다. 판정 규칙은 D18 원문이다 — 「비용·절감·압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한·압축은 공시하고 사용자가 여는 형태로 수정」(묶음 R2a.md:39, D7.17). 「지키던 것」이 비용뿐인 행은 제거하고, 크게 쓰기 전에 규모만 알린다(C5 · D1.3). 사용자 결정을 덮던 행도 제거다 — 덮던 동작을 없애고 그 자리를 사용자가 고르는 선택지로 돌린다. 안전장치(선언 없는 fan-out 금지 · 루프 상한)는 그대로 지킨다.

| 장치 | 자리 | 지키던 것 | 처분 | 계획 |
|---|---|---|---|---|
| 재리뷰 상한 2 가 코드 상수(RC6 · RC56) | `shared/docreview/scripts/docreview_state.py:41` · `references/reviewing-document.md:5` | 끝없는 리뷰 라운드 | 수정 — 기본 2, 프로필 필드 · 환경 변수로 값, 쓰인 값과 출처 공시. 상한 위 라운드는 지금처럼 사용자가 자기 문구로 연다(RC65) | 2 |
| 상한 · 정체면 열린 지적이 있어도 승인 게이트가 열림(RC56) | `docreview_state.py:1151-1158` · `reviewing-document.md:34-41` | 진행 막힘 | 수정 — 게이트 첫 줄에 열린 지적 수, 승인 선택지 이름에 「열린 지적 N개를 두고」 | 2 |
| 조언 8줄 접기 · 60자 자르기(RC57) | `docreview_advice.py:19-20, 159-171` | 화면 범람 | 수정 — 값은 설정, 접는 줄은 전문이 있는 곳을 늘 적음(「참고 전부 보기」 게이트는 R2 것 그대로) | 2 |
| 탐지 리뷰어 1명 고정 | `docreview_state.py:144-145` · `reviewing-document.md:18` · 프로필 넷 `detectors: 1` | 지적 소실(결함과 짝) | 수정 — 기본 1, 진입 · 프로필이 선언하거나 사용자가 환경 변수로 열면 N, 쓰인 수와 출처 공시(§3) | 1 → 2 |
| 선택지 라벨 1–5 낱말 압축(RC55) | `reviewing-document.md:43` | 라벨만 읽고 고르는 실패 | 수정 — 도구 제약이라 압축은 남되, 전문이 질문 바로 위에 늘 보이고 라벨은 손잡이라고 문면에 밝힘 | 2 |
| qg 리뷰어 최대 8, 기계 신호로만(RC51) | `quality-pipeline/SKILL.md:284-299` | 비용(상한 8) · 선언 없는 fan-out(선언이 지킨다) | 제거 — 상한 8 을 없앤다. 표는 시작 구성이고 모델이 근거를 적어 더하며, 시작 줄에 규모(명수 · 그중 더한 것)를 공시한다 | 3 |
| qg 수정 루프 5회 「예외 없음」(RC51) | `quality-pipeline/SKILL.md:563, 569, 624, 671` | 끝없는 루프(P18) | 수정 — 상한 5 유지, 상한에서 사용자가 자기 문구로 1회씩 연다(엔진과 같은 꼴) | 3 |
| 같은 반복에 같은 리뷰어 다시 부르기 금지 | `quality-pipeline/SKILL.md:1070-1071` | 중복 리뷰 비용 | 제거 — 금지를 없앤다. 다시 부른 리뷰어(일시 실패 재시도 · 분할 병렬 포함)는 시작 줄 규모 공시에 센다 | 3 |
| 재비판 lower(RC52) | `agents/code-recritic.md:63-65` | 이 변경이 안 한 일을 하라는 과잉 처방 — 사용자 의도 보호 | 수정 — 낮추기는 남기고, 낮춘 지적을 보고서 「낮춘 지적」 절에 이유와 함께 싣고 게이트에서 되올릴 것을 여러 개 고름 | 3 |
| 「바뀐 코드만」 | `quality-pipeline/SKILL.md:353` · `agents/security-reviewer.md:112` | 범위 밖 잡음 | 수정 — 「위치는 diff 밖이어도 원인이 이 변경이면 보고」 | 3 |
| 정의 없는 「문서 경로」 제외 | `quality-pipeline/SKILL.md:217, 338` · `agents/security-reviewer.md:40` | 문서 잡음 | 수정 — 정의를 세움(§4), 뺀 경로 수 공시 | 3 |
| 리뷰어 모델 opus 고정 둘 | `agents/security-reviewer.md:6` · `agents/code-recritic.md:13` | 판정 품질 | 제거 — 세션 모델을 따른다(사용자 결정, `flexibility-audit.md`) | 3 |
| 문서 비평 기본 5라운드(RC58) · 대상 하나 · 커밋 강제 · dispatch 수 고정 | `critiquing-artifacts/SKILL.md:72-75, 107-108, 141-151, 258-259, 276` | 루프 · 무결성 | 수정 — 상한에서 사용자가 엶 · 여러 대상 · 「지적만 받기」 읽기 전용 모드(커밋 불필요) · dispatch 수는 기본값이고 기본값과 실제로 쓴 수를 공시하며, 사용자가 그 자리에서 dispatch 수를 지정할 수 있다(D8.18) | 3 |
| e2e 시나리오 단일 선택 | `references/e2e.md:34` | 선택지 범람 | 수정 — 여러 선택 | 3 |
| 토픽 선언이면 trivia 우회 불가 | `quality-pipeline/SKILL.md:164-172` | 토픽 일부만 보는 우회 | 수정 — 토픽 diff 전체가 trivia 면 허용, 사유 공시 | 3 |
| 차등 테스트 밖 스위트 실행 금지 | `references/differential-test.md:130` | 판정 오염 | 수정 — 조사용 실행 허용, 「조사용 — 판정에 안 씀」 표시 | 3 |
| project-init 헌장 재질문 3회 뒤 중단(RC53) | `project-init/SKILL.md:160-164` | 빈 헌장 | 제거 — 기계가 정하던 중단을 없애고, 3회 뒤 「건너뛰기 · 계속 묻기 · 중단」을 사용자가 고름(D7.17) | 4 |
| project-init AGENTS.md 이전 거절 → 전체 중단 | `project-init/SKILL.md:48, 199, 201` | 부분 진행(옛 AC21) | 제거 — 기계가 정하던 전체 중단을 없애고, 「CLAUDE.md 에 바로 쓰기」 선택지, 관련 없는 git-workflow 생성은 계속(D7.17) | 4 |
| project-init 질문 ≤4 · 관례 1–3개 | `project-init/SKILL.md:147, 156` | 질문 피로 | 수정 — 질문 4개 · 관례 1–3개는 기본값이고, 기본값과 실제로 쓴 수를 그 자리에서 공시하며, 사용자가 「더 묻기」로 그 자리에서 더 연다(D8.18) | 4 |
| project-init 헌장 단계 직렬 순서(Step 3 이 끝난 뒤에만 시작, 교차 금지) | `project-init/SKILL.md:119` | 질문이 섞여 답이 엉킴 | 수정 — 질문 순서는 기본 직렬로 두고, 질문이 없는 Phase 0 스캔은 질문과 겹쳐 돌려도 된다(D3.11) | 4 |
| project-init 템플릿 브랜치 접두 고정 · 「ALWAYS 브랜치 확인」 | `templates/*/branch-strategy.md` · `templates/*/agents-md-section.md:5` | 브랜치 규칙 일관 | 수정 — 접두는 고른 전략에서 도출 + 더하기(훅 `post-tool-use.py:138-148` 과 같은 규칙), 확인은 변경 작업일 때만. 규칙이 브랜치 전환만 전제하므로(`templates/github-flow/branch-strategy.md:57-61` 등 전략 셋) 브랜치를 worktree 에서 작업하는 길도 같은 규칙으로 적는다(점검 문서의 「worktree 경로」, D3.11) | 4 |
| plugin-audit 근거 약한 지적을 공시 없이 버림(RC54) | `agents/plugin-auditor.md:56-57, 76-77` | 정밀도 · 취향 지적 | 수정 — 버리지 않고 「열린 질문」으로 보고서에 | 4 |
| plugin-audit 반박자 「불확실하면 기각」 | `agents/audit-refuter.md:22-23` | 거짓 양성 증폭 | 수정 — 부록에서 기각과 「불확실」을 나눠 표시 | 4 |
| plugin-audit 6축 고정 · 심층검증 8건 상한 | `scripts/audit-workflow.js:295, 498, 646-650` | fan-out 비용 | 제거 — 축 고정 · 8건 상한을 없앤다. 지출 동의 게이트(유지)에서 쓸 축과 검증 수, 그 규모를 알린다 | 4 |
| plugin-audit 코퍼스에서 펜스 · placeholder 제외 | `scripts/audit-workflow.js:239` | 잡음 | 수정 — 뺀 수를 보고서에 공시 | 4 |
| qg README 「iteration 당 총 ≤10」 fan-out 상한 | `quality-gates/README.md` Cost Class · 리뷰어 구성 | 비용(총 dispatch 상한) | 제거 — 「최대 8」 행과 함께 지우고 규모는 시작 · 끝 두 줄로 공시(계획 3 이 구현 중 찾음) | 3 |
| qg e2e 시나리오 수 상한(「시나리오를 1~3개 만든다」 · 「선택지는 넷을 넘지 않는다」) | `quality-gates/references/e2e.md` §1 · §2 | 질문 도구의 선택지 4개 제약 · 화면 범람 | 수정 — 도구 제약이라 압축은 남되, 넷째 시나리오부터 만들지 않는다는 사실을 공시하고 「기타」 칸으로 사용자가 그 자리에서 더 연다(계획 3 이 구현 중 찾음 — 이 계획에서는 미구현) 끝냄 — 90449ca0 · 6a6bb759(R12 계획 2) | R12 |

**결함(고정이 아니라 틀린 것 — 계획 1 에서 먼저)**: 같은 이름 지적 블록 중 마지막 것만 읽음(`docreview_route.py:37-42, 153-175, 292`) · 「adversarial 도 egress 도구를 가진다」(`critiquing-artifacts/SKILL.md:210-211`, 실제 `tools:` 는 Read · Grep · Glob) · 지운 「authoring-time hard-review」 인용(`quality-gates/README.md:16`).

**유지(장치 아님)**: agent `tools:` allowlist · kill switch · plugin-audit 지출 동의 게이트 · 훅 timeout · project-init 의 정의된 용어만 수집 · 헌장 요약 25줄(세부는 `docs/project/` 로 옮겨 잃는 것이 없다) · project-init 헌장 갱신 거절 시 단계 건너뛰기(사용자 통제).

### §2 계획 1 — 결함 셋 · 테스트 실행 공유본 · qg 진입 이름

브랜치 하나 · PR 하나로 먼저 머지한다(R5 계획 셋째가 기다린다).

**지적 블록 버림.** `extract_block` 은 같은 이름 블록을 전부 읽어 항목을 합친다. 합쳤으면 「같은 이름 블록 N개를 합쳤다」를 라우팅 보고에 공시하고 회계 모듈(`shared/adjudication/`)에 흡수로 센다(흡수는 소실이 아니다). 블록 하나라도 YAML 로 읽을 수 없으면 지금처럼 그 출력 전체를 탐지 사망으로 본다(재dispatch 1회 → 「미검증」). 재비판 블록도 같은 함수라 같이 바뀐다.

**문서 비평 거짓 문장 · README 인용.** `critiquing-artifacts/SKILL.md:210-211` 을 실제 `tools:` 에 맞게 고치고, 그 문장이 근거로 받치던 판단(산출물 egress 가정)을 다시 확인해 문면을 맞춘다. `quality-gates/README.md:16` 의 지운 게이트 인용을 지금 장치로 바꾼다.

**테스트 실행 공유본.** `run-test-selection.sh` · `diff-test-results.py` · `compute-test-scope-candidates.sh` 를 `shared/test-selection/` 으로 바이트 그대로 `git mv` 하고 qg `scripts/` 에는 같은 이름의 상대 심볼릭 링크를 둔다(`shared/docreview/` 가 쓰는 방식). 셋은 자기 위치를 두 가지로 푼다 — `compute-test-scope-candidates.sh` 는 링크를 풀지 않은 `BASH_SOURCE` 폴더에서 형제 `resolve-baseline.sh` 를 부르고, `diff-test-results.py` 는 `__file__.resolve()` 폴더에서 형제를 찾는다. 그래서 계획 1 은 셋이 부르는 형제를 전수 측정하고, 닫힌 묶음(셋 + 형제)째 옮기거나 소비 플러그인이 형제까지 링크하게 한다 — 어느 쪽인지는 측정이 정하고, 소비자 규칙(「묶음 전체를 링크한다」)을 `shared/test-selection/README.md` 에 적는다. 참조(qg `allowed-tools` · `references/differential-test.md` · qg 테스트 열한 개 · `shared/tests/test_inline_python_isolated.sh` 의 경로 목록)를 고치고, 설치본 경로(`--plugin-dir` 격리)에서 링크를 거쳐 도는지 잰다.

바이트 그대로 옮기므로 qg 이름이 공유 계약에 함께 들어간다 — kill switch `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST`(`run-test-selection.sh:22`)와 꼬리 줄 `#qg-assign` · `#qg-rows`(`:13` · `:15`, `diff-test-results.py` 가 요구한다). 소비자 규칙(`shared/test-selection/README.md`)에 다른 플러그인 소비자가 이 같은 변수로 차등 테스트를 끄고, 두 꼬리 줄을 소유자 이름이 아니라 형식 표지로 읽는다고 적는다. 이름을 바꾸는 일은 계획 1(바이트 그대로) 밖이고, 바꾼다면 kill switch 는 옛 이름을 별칭으로 계속 읽는다.

**qg 진입 이름(P3).** `commands/qg.md` 를 지운다. `quality-pipeline` 이 진입 skill 이 된다(`/quality-gates:quality-pipeline`) — `## 진입 단계` 에 `!` 사전 검사(지금 `setup-qg.sh` 가 하던 인자 확인 · 없어진 인자 안내)를 두고, `entry_preflight.py` 링크를 두고, `allowed-tools` 는 사전 검사 한 줄만 남긴다. `critiquing-artifacts` 는 `artifact-critique` 로 개명한다(`/quality-gates:artifact-critique <경로>`, 디렉토리 = 이름) — `/qg critique` 경로는 사라지고, 파이프라인에 문서 비평 의도가 오면 새 이름을 안내한다. `artifact-critique` 도 사용자가 부르는 진입 skill 이 되므로 `quality-pipeline` 과 같은 진입 조건을 갖는다 — `## 진입 단계` · `!` 사전 검사 줄 · 사전 검사 한 줄짜리 `allowed-tools`(지금은 여러 도구를 열거한다, `critiquing-artifacts/SKILL.md:12-29`) · `entry_preflight.py` 링크. 호출 표면 락의 진입 skill 목록(`check_invocation_surface.py:26-33` 의 `ENTRY_SKILLS`)에 `quality-gates` 의 두 진입(`quality-pipeline` · `artifact-critique`)을 더한다. 옛 이름 `reviewing-spec`(`run_codex_reviewer.sh:49` · `critiquing-artifacts/SKILL.md:168`)도 고친다. 호출 표면 락(`shared/entry/check_invocation_surface.py`)에서 qg 의 「보고만」 예외를 지워 다른 플러그인과 같은 집행으로 올린다. `/qg` · `qg critique` · `critiquing-artifacts` 를 개념 별칭으로 레포 전체에서 찾아 고친다(다른 플러그인 · docs · R5 설계가 부르는 이름). qg 는 major — CHANGELOG `Removed` · `Changed` 와 README 를 함께.

### §3 계획 2 — 공유 엔진 · R2 보안 잔여

**여러 탐지 리뷰어.** 프로필 · 진입이 `detectors: N` 을 선언하면 엔진은 N 을 받는다(1 은 지금 그대로). 진입은 리뷰어 N 명을 dispatch 하고 각자 자기 파일(`critic-<i>.txt`)에 쓴다. 라우터 `prepare-recritic` 은 `--critic` 을 여러 번 받고 신선도(`_round_staleness`)를 파일마다 판별한다. 지적마다 출처 리뷰어를 달고, 같은 지적은 회계 모듈이 흡수로 센다. 일부가 죽으면 재dispatch 1회 뒤 「탐지 N 중 k 사망」을 degrade 로 공시하고 남은 결과로 간다(모델 다양성 손실 — 공시하고 막지 않음). 전부 죽으면 지금처럼 「미검증」. 기본은 1 이다. 진입 · 프로필의 선언 말고도 사용자가 환경 변수(`DEVBREW_DOCREVIEW_DETECTORS` — 아래 상한 값처럼 환경이 이긴다)로 N 을 열 수 있고, 쓰인 수와 출처(기본 · 프로필 · 진입 · 환경)를 라운드 머리 줄에 공시한다(D1.1).

**상한 · 접기 값.** `rereview_cap` · `render_cap` · `summary_width` 를 프로필 frontmatter 필드와 환경 변수(`DEVBREW_DOCREVIEW_REREVIEW_CAP` 등, 환경이 이긴다)로 받는다. 기본은 2 · 8 · 60. 쓰인 값과 출처(기본 · 프로필 · 환경)를 라운드 머리 줄에 공시한다. 값을 잠근 락(`test_rereview_cap_consistency.sh` · `test_reviewing_brief_skill.sh` · `cases_advice.sh` · 골든 둘)은 「기본값 + 덮어쓰기가 먹는다」를 재게 고친다.

**게이트 문구.** 상한 · 정체로 열리는 승인 게이트: 첫 줄에 열린 지적 수, 승인 선택지 이름에 「열린 지적 N개를 두고」. 선택지 라벨 규약 문단에 「라벨은 질문 바로 위 전문을 가리키는 손잡이」를 더한다.

**결정을 한 번에 반영하고 게이트를 혼자 읽히게(짧은 설계, 2026-10-18 — B9~B13).** spec 리뷰 뒤 사용자에게 오는 설명이 매끄럽지 않고 그 설명만 보고 리뷰하기 어렵다는 사용자 지적에서 나온 네 가지다. 엔진을 쓰는 spec 리뷰 · brief 리뷰 · seed 리뷰가 함께 받고, qg 코드 리뷰는 무관하다. 있는 것(permit · 얼림 검사 · `decision_log` · `shared/style/plain-language.md`)을 넓혀 쓰고, 새 장치는 신고 명령 하나다.

- **함께 고친 곳 신고(B9).** 「고친다」(adopt) 결정 뒤 저자가 그 결정 때문에 다른 절(수용 기준 · 처분표 등)도 고치면, 엔진 새 하위 명령 `declare-related --decision <결정 id> --anchors <앵커…>` 로 그 절을 결정에 묶는다. 묶인 절은 다음 라운드의 얼림 면제에 들어가되 숨지 않는다 — 게이트에 「이 결정 때문에 함께 바뀐 곳」 목록으로 보이고, 다음 라운드 탐지 · 재비판 입력에 바뀐 절 목록으로 실린다. 신고 없이 바뀐 곳은 지금처럼 「허가 없이 바뀐 곳」(`frozen_change`)이다. 기존 permit · `exempt_scopes` · `observe_ledger` 를 넓혀 쓴다.
- **결정 반대 본문은 저자 고침(B10 · B18).** 리뷰어가 지적에 그 본문이 반대되는 결정 id 를 달면(지적 필드 `contradicts`), 라우터가 그 id 가 원장 `decision_log` 에서 채택(adopt)되고 대체되지 않은 결정인지, 그 지적 자리(앵커 · edit_scope)가 그 결정의 범위(결정한 지적의 자리 · 살아 있는 허가의 범위) 안인지 본다. 모두 맞으면 참고(advisory)로 쌓이던 그 지적을 저자 고침(`fix`)으로 올린다(지금은 참고로만 쌓인다). 리뷰어가 낸 decide · ask 는 낮추지 않는다. 보호 절이면 살아 있는 허가가 그 자리를 덮을 때만 저자 고침이고, 아니면 사용자에게 묻고 게이트 줄에 인용한 결정 id 를 괄호로 보인다. 고친 곳은 B9 와 같이 보이고 다음 라운드가 확인한다. 조건이 맞지 않는 id(없음 · 채택 아님 · 대체됨 · 범위 밖)는 참고로 남기고 그 사유를 공시한다.
- **추가 라운드 승인(B11).** `begin-round --extra-approval` 의 값은 사용자가 고른 선택지 이름 또는 기타 칸 원문이고, 원장 `extra_rounds` 에 출처(`label` · `typed`)를 함께 적는다. 게이트 문구 「사용자가 직접 쓴 말로 한 번 더 승인」을 지운다(엔진 렌더 `docreview_state.py:1548-1550` 과 `reviewing-document.md` 8단계).
- **게이트 쉬운 말(B12).** 게이트 절 규칙: 질문 · 선택지 이름에 AC 번호 · 지적 id · `§` 기호를 쓰지 않고 설명 괄호에만 쓴다. 리뷰어 지시(`doc-critic` · `doc-critic-web` · `doc-recritic` persona 와 프로필)에 「항목 첫 줄은 내부 기호 없이 무엇이 문제인지 문장으로」를 더한다 — persona 편집이라 보안 리뷰를 거친다(아래 「경계 · 리뷰」). 엔진 렌더 출력에 「괄호 밖 내부 기호 없음」 테스트를 둔다.

**R2 가 넘긴 엔진 몫.** 얼림 검사가 brief payload §6 의 「추가만 허용」을 가린다 — 이미 있는 원문 줄이 바뀌면 `frozen_change`, 끝에 덧붙인 줄만이면 통과. `docreview_state.py` 의 인자 파서에 `allow_abbrev=False`. 로드맵 쪽 `brief_universe` 정규식을 `check_brief.section4_items` 규칙과 맞춘다 — 이 함수는 `roadmap_model.py` 에 있고 R5 계획 1 이 그 파일을 고치는 중이라, 계획 2 는 R5 계획 1 머지 뒤 origin 기본 브랜치를 merge 하고 시작한다(겹침은 정보).

**보안 — 결정 기록 줄 위조.** 엔진 `_log_line`(`docreview_state.py:767-772`)이 지적 요약을 그대로 붙여, 요약 속 줄바꿈으로 brief `## 6` 의 사용자 문구 줄을 위조할 수 있다. 같은 줄에 붙는 다른 칸도 같다 — 선택지 문구(`decide --quote`, `:824-826`)와 버림 사유(`fix --reason`, `:897-904`)가 그대로 들어간다. 그래서 `_log_line` 이 내는 줄 전체를 한 줄 허용 문법으로 쓴다(D5.14) — 요약 · 선택지 문구 · 버림 사유 · supersedes 칸 모두 줄바꿈 · CR · 제어 문자 · 유니코드 줄 구분자를 공백으로, 줄 머리의 목록 · 제목 · 인용 표지는 그 줄 안에서만 쓰이게. 회귀 테스트는 칸마다 위조를 시도하고, 위조 시도 꼴을 허용 문법의 부정형(「한 줄이 아닌 것 전부」)으로 고른다.

**원장 쓰기 락 — 원인 치우기.** 우회 다섯(mktemp 인자 · 재대입 · `||` 갈래 · 명령 앞 넘기기 · 엔진 밖 원장 쓰기)은 모두 「읽기 전용 `advice` 는 예외」를 셸 흉내로 판별하던 데서 나왔다. 읽기 전용 목록을 쓰기 플래그가 아예 없는 하위 명령(`advice-list`)으로 떼고, 결과는 `$(…)` 로 받는다(넘기기 없음). 락(`test_ledger_wiring.sh` AC8)은 「엔진 쓰기 하위 명령 앞에 같은 펜스의 표지 확인이 있다」를 하위 명령 이름으로만 재고, 엔진을 부르는 줄에 넘기기(`>`)가 있으면 거부한다 — mktemp · 재대입 · 갈래를 파싱하던 코드는 지운다. 남는 축 「엔진이 아닌 명령이 원장을 쓴다」는 꼴로 막지 않고, 원장과 함께 바꿀 수 없는 권한 경계에서 집행한다(D1.4). 원장 파일 안에 둔 요약값으로는 이 축을 닫지 못한다 — 엔진은 상태를 frontmatter 의 `docreview:` 트리에서 읽고(`docreview_state.py:7`), 같은 파일을 쓰는 명령은 요약값도 함께 다시 계산해 넣을 수 있어 작성 주체를 가리지 못한다. 계획 2 는 그 경계를 리포에 이미 있는 쓰기 차단 장치부터 측정해 고르고, 상태와 요약값을 함께 바꾸는 시도도 거부되는 것을 통과 조건으로 둔다. 경계를 마련하지 못하면 이 축을 닫았다고 하지 않고 남은 보안 문제로 `## 미룸` 에 이유와 받는 곳을 적는다. 요약값 대조는 frontmatter 와 본문 전체의 우발적 손상 감지로만 남긴다 — 엔진이 저장할 때 요약값을 함께 쓰고, 읽을 때 대조해 다르면 `LedgerCorrupt`(「원장이 엔진이 쓴 것과 다르다」)로 멈춘다. 요약값이 없는 기존 원장(이 변경 전에 쓰인 것 — 원장은 문서별로 세션을 넘어 남는다)은 손상으로 보지 않고 다음 엔진 저장 때 요약값을 채우며, 그 사실을 그 라운드 머리 줄에 한 번 공시한다. 멈출 때는 원장 경로와 복구하는 길 둘을 함께 낸다 — 엔진이 쓴 내용으로 되돌리거나, 그 문서의 상태 폴더를 지우고 1라운드부터 다시 리뷰한다(라운드 · 재리뷰 횟수 · 지적 이력을 잃는다는 사실을 함께 적는다).

**brief 판독기 하나.** `seed_body` 방식대로, brief 의 §6 앵커 줄 · 결정 줄 · §3 열린 줄을 읽는 허용 문법을 한 모듈(`brief_body.py`)에 두고 `check_brief`(N1b)와 `check_verbatim_coverage` 가 함께 쓴다 — 두 판독기가 서로 다르게 읽는 틈을 없앤다. 문법 밖 줄은 사유와 함께 거부한다: 열 0 · 유니코드 공백(NBSP · U+3000 등 `[^\S\n]`)으로 들인 앵커, 번호 목록 · 인용 꼴 결정 줄. §3 산문 속 `⟨S<n>⟩` 은 위치와 무관하게 전부 뽑아 대조한다. `check_verbatim_coverage` rc 3(상태를 못 읽음 · 비었음)은 공시만 하고 넘어가지 않는다 — 게이트를 막고, 사용자가 「검사 없이 계속」을 고르면 그 선택을 audit 에 남긴다.

**실제 파서 교차 확인(B2).** markdown-it-py 를 개발 의존으로 `uv.lock` 에 고정하고, 테스트가 우회 사례 전부와 레포의 실제 brief · seed 들을 파서에 읽혀 「우리 문법이 앵커 · 결정 줄 · 목록이라고 본 줄」과 파서의 토큰(최상위 목록 항목 · 코드 · 인용 · 문단)이 같은지 대조한다. 파서가 없으면 그 락은 통과가 아니라 「확인 못 함(markdown-it-py 없음)」을 내고 rc 를 0 으로 두지 않는다. 런타임 판독기는 표준 라이브러리만 쓴다.

**나머지 알려진 우회.** R2 PR 「알려진 우회」의 나머지(seed frontmatter 문법 밖 · `## 2` 줄 허용 목록 없음 · 인라인 코드 안 `##` · `append-verbatim --section` 무검사 · audit H1~H3 · 확인 표시 변형 · 문자 참조 · `mailto:` · 맨 도메인 · `--quote-file` 은 모델이 씀 · `verbatim_units` 의 `## 1`)도 같은 판독기 방식으로 함께 닫는다(범위를 줄이지 않는다). 계획이 우회마다 재현 → 닫음 → 변이로 잰 표를 만들고, 판독기 방식으로 닫을 수 없는 것(예: 모델이 쓰는 파일의 출처)은 이유와 받는 곳을 `## 미룸` 에 더한다.

**경계 · 리뷰.** 보안 잔여는 spec-distill 스크립트(`check_brief.py` · `check_verbatim_coverage.py` · `seed_body.py` · `check_seed.py` · `seed_review_log.py` · `seed_provenance.py`)와 그 락을 고친다 — 지금 R2a 경로 예약 밖이라, 계획 2 시작 전에 작은 로드맵 PR(R4 규칙: 예약은 설계가 정하면 로드맵 PR 로 더함)로 더한다. 보안 diff 라 qg 보안 리뷰어(웹 도구 없음)를 따로 한 번 돌려 PR 본문에 기록한다. spec-distill 버전 bump.

### §4 계획 3 — qg 장치 · 범위 입력 · persona

**범위 모드.** `range <시작>[..<끝>]` 을 더한다 — 끝을 생략하면 기본 브랜치(`origin/HEAD` 에서 해석). diff 의 기준과 차등 테스트 기준선이 둘 다 `<시작>` 이다. 열린 PR 이 없는 범위라 PR 코멘트 게시를 하지 않고 그렇다고 공시한다. R5 끝 단계와의 계약은 `/quality-gates:quality-pipeline range <로드맵 시작 커밋>` 이다.

**여러 설계문서를 의도로.** `discover-spec.sh` 는 범위 안 `Spec:` 트레일러를 전부 모은다(지금은 트레일러가 있는 가장 새 커밋 하나에서 멈춘다, `discover-spec.sh:68-92`) — 경로 검사(절대 · `..` · 레포 밖 링크 · 추적 안 됨 거부)는 트레일러마다 그대로, 중복 제거, 커밋 순서 유지. 출력 JSON 은 `specs: [...]` 목록이고 의도 줄은 「설계문서 N개」. 리뷰어는 문서마다 지적에 「어느 설계의 어느 AC」를 단다(K10 — 긴 입력의 가운데). 모든 범위 모드에 적용한다 — 트레일러가 하나면 지금과 같다.

**「문서 경로」 정의.** 문서 경로는 사람만 읽는 문서다 — 기본 패턴 `README*` · `CHANGELOG*`(D5.12). `docs/` 아래 문서는 기본으로 리뷰에 들어간다 — 그 아래에 모델의 작업 규칙이나 훅의 입력이 있다(`docs/git-workflow/branch-strategy.md` 는 project-init 훅이 브랜치 규칙으로 읽는다, `post-tool-use.py:83`). docs 아래에서 사람만 읽는 문서는 레포가 아래 변수에 구체적인 경로를 적어 뺀다. 레포는 환경 변수 `DEVBREW_QUALITY_GATES_DOC_PATHS` 로 바꾼다(D2.8) — 쉼표로 나눈 패턴 목록이고(앞뒤 공백은 버린다), 패턴은 git pathspec 의 glob 문법(`**` 포함)이다. 값이 있으면 기본 목록을 통째로 대신하고, 빈 값이면 아무 경로도 빼지 않으며, 없으면 기본 목록이다. 레포는 이 값을 추적되는 `.claude/settings.json` 의 `env` 에 둔다 — 새 설정 파일은 없다. 그 파일은 리뷰 대상 변경이 고칠 수 있으므로, 리뷰 범위 안의 변경이 이 키를 바꾸면 그 iteration 은 기본 목록으로 돌아가고 그렇게 했다고 공시한다(D5.13). 패턴이 문서가 아닌 파일(모델이 읽는 `.md` · 코드)까지 빼면 뺀 경로를 보고서에 이름으로 싣고, 걸러진 diff 가 비면 clean 이 아니라 not-certified 로 낸다. 그 `env` 가 세션 환경 변수로 실리는지는 계획 3 이 실측으로 확인한다. 상한 값들과 같은 꼴(환경이 정한다)이다. 그 밖의 `.md`(skill · agent · reference · 템플릿 · CLAUDE.md · AGENTS.md 등 모델이 읽고 행동하는 것)는 코드로 리뷰한다. 이 정의를 읽는 자리는 하나다 — `quality-pipeline/SKILL.md` Step 1 에서 `FILTERED_DIFF` 를 만드는 자리(지금 `:217` 의 `git diff "$b" "$t"` 에서 문서 경로를 빼는 문장)가 이 변수를 읽고, 쓰인 목록과 출처(기본 · 환경), 뺀 경로 수를 보고서에 공시한다. 리뷰어(`agents/security-reviewer.md:40` 등)는 정의를 다시 갖지 않고 걸러진 diff 만 받는다. 고치는 파일은 Files to Modify 계획 3 의 `quality-pipeline/SKILL.md` · `agents/security-reviewer.md` 에 이미 있다.

**§1 처분의 qg 적용.** 리뷰어 구성(모델이 근거를 적어 더함 · 규모 공시 · 일시 실패 1회 재시도 · 분할 병렬) · 수정 루프 상한에서 사용자 문구로 1회씩 열기 · 「낮춘 지적」 절과 되올리기(multiSelect) · 「원인이 이 변경이면 보고」 · `model: opus` 두 줄 삭제 · e2e multiSelect · 토픽 diff 전체가 trivia 면 우회 허용 · 조사용 스위트 실행 표시 · artifact-critique 의 라운드 열기 · 여러 대상 · 「지적만 받기」 모드 · dispatch 수 기본값.

**persona 보안 리뷰.** 대상은 `agents/security-reviewer.md`(범위 문장 · 문서 경로 · 모델 줄)와 `agents/code-recritic.md`(lower 공시 · 모델 줄). 편집 diff 를 qg 보안 리뷰어(웹 도구 없음)에 따로 한 번 돌리고, 결과와 판단 근거(약화가 아니라 범위 확장 · 모델 핀 제거)를 PR 본문 「보안 리뷰」 절에 적어 머지 전 사용자 확인 항목으로 올린다. `tools:` allowlist 와 웹 금지는 그대로.

### §5 계획 4 — project-init · plugin-audit

**project-init.** 헌장 재질문 3회 뒤 「건너뛰기 · 계속 묻기 · 중단」을 `AskUserQuestion` 으로 고른다. AGENTS.md 이전을 거절하면 「CLAUDE.md 에 바로 쓰기」 선택지를 주고, 관련 없는 git-workflow 생성은 계속한다 — 옛 AC21 「부분 진행 금지」를 바꾸므로 CHANGELOG 에 적는다. 질문 수 · 관례 개수는 기본값으로 두고 더 받는다. 템플릿의 브랜치 접두는 고른 전략에서 도출하고 사용자가 접두(`docs/` · `chore/` 등)를 더할 수 있다 — 훅과 같은 도출 규칙 하나. 「ALWAYS 브랜치 확인」은 변경 작업일 때만.

**plugin-audit.** auditor 의 「or drop it」을 「열린 질문으로 보고」로, 반박자의 불확실을 부록의 「불확실」 칸으로. 동의 게이트에서 축을 고르고 심층검증 상한을 늘린다(기본 6축 · 8건). 코퍼스에서 뺀 펜스 · placeholder 수를 보고서에 공시한다.

### §6 온톨로지

| 객체 | 속성 | 링크 | 주인 |
|---|---|---|---|
| 장치 | 자리(file:line) · 지키던 것 · 처분 · 계획 | 로드맵 R2a 블록 → 이 설계 §1 행 → 계획 과제 | 이 설계(§1) |
| 엔진 프로필 | `detectors` · `rereview_cap` · `render_cap` · `summary_width` · `must_catch` | 진입 skill → 프로필 → 엔진 상태 | 각 진입 플러그인의 `docreview-profiles/` |
| 엔진 상태(리뷰 원장) | 라운드 · 열린 계보 · 결정 · 요약값 | 진입 → `state-dir-for` → 원장 | `shared/docreview/` 엔진(유일 writer) |
| qg 범위 | 모드(session · branch · paths · 토픽 · range) · 기준 커밋 | 진입 인자 → `resolve-baseline.sh` → diff · 차등 테스트 | qg |
| 의도 출처 | 설계문서 목록(`specs`) · 커밋 · PR 본문 | 범위 → `discover-spec.sh` → 리뷰어 | qg |
| 문서 경로 정의 | 패턴 목록(기본 · 레포 설정) | 정의 → `FILTERED_DIFF` → 보고서 공시 | qg |
| 테스트 실행 공유본 | 스크립트 셋 + 형제 · 소비자 규칙 | `shared/test-selection/` ← qg 링크 · spec-distill 링크(R5) | `shared/test-selection/` |
| brief 판독기 | 허용 문법(§6 앵커 · 결정 줄 · §3 열린 줄) | `check_brief` · `check_verbatim_coverage` → 판독기 | spec-distill `brief_body.py` |

### §7 상류 · 하류 연계

- **받는 곳(상류)**: 로드맵 R2a 블록 · 묶음 R2a.md · `flexibility-audit.md` · R2 PR #217 의 넘김 · R5 설계 `## 미룸` 의 R2a 두 행 · P3 결정(`roadmap.md` 결정 줄).
- **넘기는 곳(하류)**:
  - R5 계획 셋째 — `shared/test-selection/` 공유본과 소비자 규칙(묶음 전체 링크), qg 새 진입 이름, 범위 모드 호출 꼴.
  - R10 — brief 판독기의 허용 문법. 인터뷰가 쓰는 brief 가 이 문법을 지켜야 한다. 계획 2 머지 때 R10 담당(지휘자)에게 알린다.
  - R8 — 링크 공유 방식과 문서 경로 · 상한 설정이 devbrew 밖 레포에서 통하는지.
  - R11 — qg · project-init · plugin-audit README · CHANGELOG 의 낡은 개념. 이 설계가 바꾸는 동작의 줄은 R2a 가, 나머지는 R11 이.
- **같은 상태를 읽는 표면**: 리뷰 원장은 spec-distill 진입 셋(request-framing · reviewing-brief · spec-review)과 artifact-critique 가 함께 쓴다 — 엔진 바뀜은 네 소비자의 스위트로 잰다. qg 보고서는 파이프라인 · 판정 · PR 코멘트가 읽는다.
- **되돌아오는 길**: 장치 조사(OQ29)는 열려 있다. R2a 플러그인 안에서 새로 찾은 장치는 §1 에 행을 더하고 계획이 처리한다. R2a 플러그인 밖이면 재분해(`references/redecompose.md`)로 로드맵에 올린다.

### §8 있는 것 검토 · 레포 전용 값

- **레포 안(그대로 씀)**: 엔진의 사용자 문구 라운드 열기(`--extra-approval`) · 회계 모듈(`shared/adjudication/`) · 심볼릭 링크 공유(`shared/docreview/` 선례) · `seed_body.py` 의 허용 문법 방식 · `entry_preflight.py` 진입 단계 · 호출 표면 락 · `resolve-baseline.sh`.
- **레포 밖**: markdown-it-py(MIT · 4.2.0 · 2026-05 · 의존 mdurl) — 사용자 검토 뒤 테스트에서만(B2). bashlex 는 GPLv3 라 쓰지 않고 원인 치우기로 대체.
- **레포 전용 값**: 기본 브랜치는 `origin/HEAD` · 상한 값은 프로필 · 환경 · 문서 경로 패턴은 레포 설정 · 브랜치 접두는 전략에서 도출. `main` · devbrew 경로를 코드에 박지 않는다.

### §9 위험에 대한 답

- **K7 (찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 통제 자리가 섞여 있고 모델은 사용자 말에 맞춘다, «sycophancy»)**: §1 은 장치마다 「지키던 것」을 적고(«chesterton-fence»), 사용자 통제 자리(지출 동의 · 헌장 갱신 거절)는 장치가 아니라고 따로 둔다. 「판정 필요」 둘(RC52 lower · RC54 버림)은 의도를 지키는 쪽이 맞아 낮추기 · 걸러 내기는 남기고 숨김만 없앴다. 목록은 완전하지 않다고 보고 조사를 연다(D15).
- **실패 양식(«mast» — 조기 종료 · 정보 은닉 · 종료 조건 무지)**: 루프 상한은 남기고(qg 5 · 엔진 2) 상한에서 사용자가 연다. 접기 · 자르기 · 버림은 전부 「몇 개를 어디로」 공시로 바꾼다.
- **긴 입력(«chroma-context-rot» · «context-engineering»)**: 여러 설계문서 의도는 문서마다 AC 를 달게 하고, 조언 접기는 화면에서만 접고 전문은 남긴다 — 압축으로 결정적인 맥락을 잃지 않게.
- **지시를 정확히 따르는 모델(«claude4-best-practices»)**: 절감 지시(「최대 N」 · 「바뀐 코드만」)는 그대로 축소로 읽힌다 — 문면을 기본값 + 근거를 적고 넓히는 길로 바꾼다.
- **꼴 막기 재발**: 같은 축의 우회가 대상만 옮겨 다시 나온 것은 방식이 원인이다 — 원인 치우기(원장 쓰기 락) · 허용 문법 하나 + 실제 파서 교차(brief) · 동작 대조(원장 요약값)로 바꾼다.

### §10 계획 나누기

1. **결함 셋 · 테스트 실행 공유본 · qg 진입 이름** — 브랜치 `feature/shared-review-engine-devices`. 먼저 머지(R5 계획 셋째가 기다림). AC1~AC9.
2. **공유 엔진 · R2 보안 잔여** — 시작 전에 로드맵 PR(경로 예약)과 R5 계획 1 머지 merge. AC10~AC20 · AC38~AC41(짧은 설계 B9~B13).
3. **qg 장치 · 범위 입력 · persona** — 계획 1 머지 뒤. AC21~AC30.
4. **project-init · plugin-audit** — 앞의 셋과 독립. AC31~AC35.

계획 2~4 의 브랜치 이름은 계획이 정해 로드맵 블록의 `브랜치:` 칸에(여럿이면 하위 항목) 로드맵 PR 로 더한다. 각 계획은 자기 PR 을 가지며 먼저 끝난 것부터 머지한다.

## Acceptance Criteria

계획 1
- AC1 `docreview_route.py` 가 같은 이름 블록 여럿을 모두 읽어 합치고 「같은 이름 블록 N개를 합쳤다」를 라우팅 보고에 공시하며, 회계에 흡수로 센다. 블록 하나라도 파손이면 출력 전체가 탐지 사망이다.
- AC2 `critiquing-artifacts`(개명 뒤 `artifact-critique`)의 egress 문장이 실제 `tools:` 와 맞고, `quality-gates/README.md` 에 지운 게이트 인용이 없다.
- AC3 테스트 실행 스크립트 셋이 `shared/test-selection/` 에 원래 바이트 그대로 있고(이동 전 blob 해시와 같음), qg `scripts/` 의 같은 이름은 그 파일로 가는 상대 심볼릭 링크다.
- AC4 셋이 부르는 형제 전수가 측정돼 있고, qg 링크로 부를 때와 다른 플러그인 폴더의 링크로 부를 때 둘 다 같은 결과를 낸다. 소비자 규칙이 `shared/test-selection/README.md` 에 있다.
- AC5 qg 스위트 · `shared/tests/test_inline_python_isolated.sh` 가 새 경로로 GREEN 이고, 설치본 경로(`--plugin-dir` 격리)에서 링크를 거쳐 차등 테스트가 돈다.
- AC6 `plugins/quality-gates/commands/` 가 없고, `quality-pipeline` 이 `## 진입 단계` · `!` 사전 검사 · `entry_preflight.py` 링크 · 사전 검사 한 줄짜리 `allowed-tools` 를 가진 진입 skill 이다. 없어진 인자는 안내 한 줄을 내고 실행하지 않는다.
- AC7 `critiquing-artifacts` 가 `artifact-critique` 로 개명돼(디렉토리 = `name`) `/quality-gates:artifact-critique <경로>` 로 불리고, 레포에 옛 이름 `reviewing-spec` · `/qg`(뒤에 `branch` · `critique` 등이 붙은 꼴 포함) · `critiquing-artifacts` 를 부르는 곳이 없다(역사 기록 · CHANGELOG 제외). 호출 표면 락의 옛 이름 축(`OLD_NAME_RE` · 살아 있는 표면)이 `/qg` 와 `critiquing-artifacts` 를 잡아 기계로 잰다(D10.22).
- AC8 호출 표면 락에 qg 예외가 없고 qg 가 GREEN 이며, `commands/qg.md` 를 되살리는 변이에서 RED 다.
- AC9 qg `plugin.json` 이 major bump 되고 CHANGELOG 에 `Removed`(`/qg` · `/qg critique`) · `Changed`(진입 이름) 와 README 갱신이 있다.

계획 2
- AC10 프로필이 `detectors: N`(N ≥ 1)을 받고, 진입이 N 명을 dispatch 하면 라우터가 `--critic` 여러 개를 파일마다 신선도 판별해 합친다. 지적마다 출처 리뷰어가 있고 겹침은 흡수로 센다. 사용자가 `DEVBREW_DOCREVIEW_DETECTORS` 로 N 을 열 수 있고, 이 값이 프로필 · 진입 선언보다 우선한다. 쓰인 수와 출처(기본 · 프로필 · 진입 · 환경)가 라운드 머리 줄에 공시된다(D2.5).
- AC11 탐지 N 중 일부가 재dispatch 뒤에도 죽으면 「탐지 N 중 k 사망」이 degrade 로 공시되고 남은 결과로 간다. 전부 죽으면 「미검증」이다.
- AC12 `rereview_cap` · `render_cap` · `summary_width` 를 프로필 필드와 환경 변수로 바꿀 수 있고(환경이 이긴다) 쓰인 값과 출처가 공시된다. 기본값은 2 · 8 · 60 이다. 접힌 조언 줄은 전문이 있는 곳을 적는다(D6.15).
- AC13 상한 · 정체로 열린 승인 게이트의 첫 줄에 열린 지적 수가, 승인 선택지 이름에 「열린 지적 N개를 두고」가 있다. 라벨 규약 문단에 손잡이 문장이 있다.
- AC14 얼림 검사가 payload §6 끝에 덧붙인 줄만이면 통과하고 이미 있는 줄이 바뀌면 `frozen_change` 다. `docreview_state.py` 인자 파서가 줄인 플래그를 거부한다.
- AC15 `_log_line` 이 쓴 결정 줄은 요약 · 선택지 문구(`decide --quote`) · 버림 사유(`fix --reason`) · supersedes 칸 중 어느 칸에 줄바꿈 · CR · 제어 문자 · 유니코드 줄 구분자가 있어도 정확히 한 줄이고, 어느 칸으로도 brief `## 6` 의 사용자 문구 줄을 만들 수 없다. 회귀 테스트는 칸마다 위조를 시도한다(D9.20).
- AC16 `docreview_state.py advice-list` 는 쓰기 플래그가 없는 읽기 전용 하위 명령이고, skill 펜스는 그 결과를 넘기기 없이 받는다. `test_ledger_wiring.sh` 의 원장 쓰기 락(그 테스트의 AC8)은 하위 명령 이름으로만 재며 mktemp · 재대입 · 갈래 파싱 코드가 없고, R2 의 잔여 다섯 꼴이 각각 RED(또는 원인 소거로 해당 없음)다. 다섯째 꼴(엔진 밖 원장 쓰기)은 AC17 (가)의 미룸(R8)으로 넘어간다(D2.9).
- AC17 (가) 엔진이 아닌 명령이 원장을 쓰려 하면, frontmatter 상태와 요약값을 함께 바꾸는 시도까지 권한 경계에서 거부된다. 경계를 마련하지 못했으면 이 축을 닫았다고 쓰지 않고, `## 미룸` 에 이유와 받는 곳을 적는다. (나) 요약값이 엔진이 쓴 것과 다르면 `LedgerCorrupt`(「원장이 엔진이 쓴 것과 다르다」)로 멈추고 원장 경로와 복구 길 둘을 낸다. 요약값이 없는 기존 원장은 다음 저장 때 채우고 그 라운드 머리 줄에 한 번 공시한다(D2.9).
- AC18 `check_brief` 와 `check_verbatim_coverage` 가 같은 판독기 모듈을 쓰고, 열 0 · 유니코드 공백 앵커 · 번호 목록 · 인용 꼴 결정 줄 · §3 산문 속 `⟨S<n>⟩` 이 각각 잡힌다. `check_verbatim_coverage` rc 3 이면 게이트가 막히고 「검사 없이 계속」 선택이 audit 에 남는다.
- AC19 markdown-it-py 가 `uv.lock` 의 개발 의존으로 고정되고, 교차 확인 테스트가 우회 사례 전부와 레포의 실제 brief · seed 에서 문법 판정과 파서 토큰이 같음을 잰다. 파서가 없으면 그 테스트는 「확인 못 함」을 내고 rc ≠ 0 이다.
- AC20 R2 「알려진 우회」 나머지마다 재현 · 닫음 · 변이 결과 표가 PR 에 있고, 닫지 못한 것은 이유와 받는 곳이 `## 미룸` 에 있다. 보안 리뷰어 결과가 PR 본문에 있다.
- AC38 `docreview_state.py declare-related --decision <결정 id> --anchors <앵커…>` 가 「고친다」 결정에 절을 묶는다(원장에 없는 결정 id · 「고친다」가 아닌 결정은 이름 있는 사유로 거부). 묶인 절이 바뀐 다음 라운드에서 그 절은 `frozen_change` 로 오르지 않고, 게이트 렌더에 「이 결정 때문에 함께 바뀐 곳」 목록으로 보이며, 그 라운드의 탐지 · 재비판 입력에 바뀐 절 목록으로 실린다. 묶지 않은 절이 바뀌면 여전히 `frozen_change` 다(B9).
- AC39 지적 필드 `contradicts` 가 원장 `decision_log` 의 채택(adopt)되고 대체되지 않은 결정 id 를 가리키고 그 지적 자리(앵커 · edit_scope)가 그 결정의 범위 안이면, 라우터가 참고(advisory)로 쌓이던 그 지적을 저자 고침(`fix`)으로 올린다. 리뷰어가 낸 decide · ask 는 낮추지 않는다. 사용자가 승인한 보호 절이면 살아 있는 허가가 그 자리를 덮을 때만 저자 고침이고, 아니면 사용자에게 묻고 게이트 줄에 인용한 결정 id 를 괄호로 보인다. 조건이 맞지 않는 id(없음 · 채택 아님 · 대체됨 · 범위 밖)는 참고로 남고 그 사유가 라우팅 보고에 공시된다(B10 · B18).
- AC40 `begin-round --extra-approval` 이 고른 선택지 이름과 기타 칸 원문을 둘 다 받고, 원장 `extra_rounds` 항목에 출처(`label` 또는 `typed`)가 함께 적힌다. 엔진 게이트 렌더와 `reviewing-document.md` 에 「사용자가 직접 쓴 말로」 문구가 없다(B11).
- AC41 기호 없는 요약을 가진 픽스처로 돌린 엔진 게이트 렌더(`gate --render`)의 모든 줄에 괄호 밖 내부 기호(지적 id · AC 번호 · `§`)가 없음을 테스트가 잰다. `reviewing-document.md` 게이트 절에 「질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만」 규칙이 있고, `doc-critic` · `doc-critic-web` · `doc-recritic` persona 에 「항목 첫 줄은 내부 기호 없이 무엇이 문제인지 문장으로」 규칙이 있다. 그 persona diff 의 보안 리뷰(qg 보안 리뷰어, 웹 도구 없음) 결과가 PR 본문에 있다(B12).

계획 3
- AC21 `range <시작>[..<끝>]` 모드가 있고, 끝 생략 시 `origin/HEAD` 를 쓰며, diff 기준과 차등 테스트 기준선이 `<시작>` 이고 PR 코멘트를 게시하지 않았다고 공시한다.
- AC22 `discover-spec.sh` 가 범위 안 `Spec:` 트레일러를 전부 모아 `specs` 목록을 내고(트레일러마다 경로 검사 · 중복 제거 · 커밋 순서), 의도 줄이 「설계문서 N개」다. 트레일러 하나면 지금과 같은 결과다.
- AC23 문서 경로 정의가 한 곳(`quality-pipeline/SKILL.md` Step 1 의 `FILTERED_DIFF`)에 있다. 기본 목록은 `README*` · `CHANGELOG*` 이고 `docs/` 아래 문서는 기본으로 리뷰에 들어간다. `DEVBREW_QUALITY_GATES_DOC_PATHS` 로 목록을 바꿀 수 있다(값이 있으면 기본 목록을 대신하고, 빈 값이면 아무것도 빼지 않는다). 리뷰 범위 안의 변경이 그 키를 바꾸면 그 iteration 은 기본 목록으로 돌아가고 그 사실이 공시된다. 쓰인 목록 · 출처 · 뺀 경로 수가 공시되고, 걸러진 diff 가 비면 not-certified 다. skill · agent · reference · 템플릿 `.md` 는 리뷰에 들어간다(D6.16).
- AC24 quality-pipeline 문면에 리뷰어 상한(최대 8)과 같은 반복에서 같은 리뷰어를 다시 부르지 말라는 금지가 없다. 구성표는 시작 구성이고, 규모 공시는 두 줄이다 — dispatch 전에 찍는 시작 줄에 계획한 명수와 그중 모델이 근거를 적어 더한 수가 있고, 반복이 끝날 때 찍는 줄에 실제로 다시 부른 리뷰어(일시 실패 재시도 · 분할 병렬)의 수가 있다(D2.6 · D9.21).
- AC25 수정 루프가 상한 5 에 닿으면 사용자가 자기 문구로 1회씩 더 열 수 있고 그 문구가 기록된다. 열지 않으면 지금의 Max-iter 결정으로 간다.
- AC26 재비판이 낮춘 지적이 보고서 「낮춘 지적」 절에 이유와 함께 있고 게이트에서 여러 개를 되올릴 수 있다.
- AC27 qg agent 에 `model:` 고정이 없고, `security-reviewer` 의 범위 문장과 `quality-pipeline/SKILL.md` 의 「바뀐 코드만」 문장이 둘 다 「원인이 이 변경이면 보고」다(D6.15). persona diff 의 보안 리뷰 결과가 PR 본문 「보안 리뷰」 절에 있다.
- AC28 e2e 시나리오 선택이 multiSelect 이고, 토픽 diff 전체가 trivia 면 우회가 사유와 함께 허용되며, 조사용 스위트 실행이 「조사용 — 판정에 안 씀」으로 표시된다.
- AC29 artifact-critique 가 여러 대상과 「지적만 받기」 읽기 전용 모드(커밋 없음)를 받고, 라운드 상한에서 사용자가 연다. dispatch 수는 기본값이고, 기본값과 실제로 쓴 수가 공시되며, 사용자가 그 자리에서 수를 정할 수 있다(D6.15 · D9.19).
- AC30 범위 모드를 설계문서 둘 이상인 버릴 레포에서 실제 명령으로 걸은 기록이 있다.

계획 4
- AC31 project-init 헌장 재질문 3회 뒤 「건너뛰기 · 계속 묻기 · 중단」 선택이 있고, 건너뛰면 미완 항목을 공시한다. 질문 수와 관례 개수는 기본값이고, 기본값과 실제로 쓴 수가 그 자리에서 공시되며, 「더 묻기」 선택으로 그 자리에서 더 열 수 있다(D9.19). 질문 순서는 기본 직렬이지만 질문이 없는 Phase 0 스캔은 질문과 겹쳐 돌 수 있다(D6.15).
- AC32 AGENTS.md 이전 거절 때 「CLAUDE.md 에 바로 쓰기」 선택지가 있고 git-workflow 파일 생성이 계속된다. CHANGELOG 가 옛 AC21 변경을 적는다.
- AC33 템플릿의 브랜치 접두가 고른 전략에서 도출되고 사용자가 접두를 더할 수 있으며 훅과 같은 규칙이다. 「ALWAYS 브랜치 확인」은 변경 작업일 때만이다. 템플릿 브랜치 규칙이 worktree 에서 작업하는 길도 같은 규칙으로 적는다(D6.15).
- AC34 plugin-auditor 가 근거 약한 지적을 「열린 질문」으로 내고, 반박자의 불확실이 부록에 따로 표시되며, 코퍼스에서 뺀 수가 공시된다. plugin-audit persona diff(`agents/plugin-auditor.md` · `agents/audit-refuter.md`)의 보안 리뷰(qg 보안 리뷰어, 웹 도구 없음) 결과가 판단 근거와 함께 PR 본문 「보안 리뷰」 절에 있다(D2.7).
- AC35 plugin-audit 에 6축 고정과 심층검증 8건 상한이 없고, 지출 동의 게이트가 쓸 축 · 검증 수와 그 규모를 알린다(D2.6).

공통
- AC36 계획마다 건드린 플러그인 전부와 shared 의 스위트를 기준선과 실패 «이름»으로 대조해 새 실패가 0 이다(선재 RED 는 이름 집합으로 비교).
- AC37 §1 처분표의 모든 행이 어느 AC 로 닫히고, 구현 중 새로 찾은 장치는 §1 에 행으로 더해졌거나 재분해로 넘겨졌다.

## Files to Modify

- 계획 1: `shared/docreview/scripts/docreview_route.py` · `shared/test-selection/`(새: 스크립트 셋 + 형제 · README) · `plugins/quality-gates/scripts/`(링크) · `plugins/quality-gates/commands/qg.md`(삭제) · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/skills/critiquing-artifacts/` → `skills/artifact-critique/` · `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/references/differential-test.md` · `plugins/quality-gates/README.md` · `CHANGELOG.md` · `plugin.json` · qg 테스트 · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · `shared/tests/test_inline_python_isolated.sh` · `/qg` 를 부르는 문서들.
- 계획 2: `shared/docreview/scripts/docreview_state.py` · `docreview_route.py` · `docreview_advice.py` · `shared/docreview/references/reviewing-document.md` · `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `doc-recritic.md`(persona — 보안 리뷰) · 진입 skill 셋의 펜스(`advice-list`) · 프로필 넷 · `plugins/spec-distill/scripts/brief_body.py`(새) · `check_brief.py` · `check_verbatim_coverage.py` · `seed_body.py` · `check_seed.py` · `seed_review_log.py` · `seed_provenance.py` · `plugins/spec-distill/scripts/roadmap_model.py`(`brief_universe`) · `plugins/spec-distill/tests/test_ledger_wiring.sh` · 값 락 테스트 · `shared/tests/fixtures/docreview/` · `pyproject.toml` · `uv.lock` · spec-distill `CHANGELOG.md` · `plugin.json`.
- 계획 3: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `scripts/discover-spec.sh` · `scripts/setup-qg.sh`(범위 인자) · `scripts/resolve-baseline.sh`(범위 기준) · `FILTERED_DIFF` 를 만드는 자리 · `agents/security-reviewer.md` · `agents/code-recritic.md` · `references/e2e.md` · `references/differential-test.md` · `skills/artifact-critique/SKILL.md` · qg 테스트 · README · CHANGELOG · `plugin.json`.
- 계획 4: `plugins/project-init/skills/project-init/SKILL.md` · `templates/*/branch-strategy.md` · `templates/*/agents-md-section.md` · `plugins/plugin-audit/agents/plugin-auditor.md` · `agents/audit-refuter.md` · `scripts/audit-workflow.js` · `scripts/render-audit-report.py` · `skills/plugin-audit/SKILL.md` · 각 테스트 · README · CHANGELOG · `plugin.json`.
- 로드맵: `roadmap.md` R2a 블록의 `경로 예약`(spec-distill 보안 잔여 스크립트) · `브랜치`(계획 2~4) — 로드맵 PR.

## Verification Plan

- 계획마다 건드린 플러그인 전부 · shared 의 스위트를 기준선(merge-base)과 실패 이름으로 대조한다. 동시에 돌리지 않는다.
- 결함 · 보안 고침은 변이로 잰다 — 고침을 되돌린 사본에서 그 락이 RED, 양성 대조와 함께. 우회 표는 허용 문법의 부정형(추가 · 반전 · 형태 변경 포함)으로 사례를 고른다.
- 테스트 실행 공유본은 qg 링크 · 다른 플러그인 링크 · 설치본 세 경로로 잰다. 설치본은 두 방식을 다 잰다 — `--plugin-dir` 격리(AC5 가 이름 댄 통과 기준, 소스 트리의 링크가 살아 있다)와 `CLAUDE_CONFIG_DIR` 격리 설치(쓰기 전 빈 폴더로 격리 증명, 마켓플레이스 캐시 사본). 캐시 사본은 링크를 실제 파일로 풀어 둔다(지금 `~/.claude/plugins/cache/devbrew/spec-distill/7.0.1/scripts/docreview_anchor.py` 는 일반 파일이고 레포에서는 `shared/docreview/` 로 가는 링크다) — 그래서 `__file__.resolve()` 로 형제를 찾는 스크립트는 두 방식에서 다른 폴더를 본다. 둘의 결과가 다르면 그 차이를 PR 에 적는다.
- 진입 이름은 헤드리스가 아니라 대화형에서 `/quality-gates:quality-pipeline` · `/quality-gates:artifact-critique` 가 뜨는지 실제로 부른다.
- 범위 모드 · 여러 설계문서는 버릴 레포(기본 브랜치 이름이 `main` 이 아닌 것 포함)에서 실제 명령으로 걷는다.
- persona 편집 · 보안 잔여는 qg 보안 리뷰어(웹 도구 없음)로 따로 리뷰한다.

## Rejected Alternatives

- R2a 를 재분해로 여러 에픽으로 — 같은 판정 기준을 여러 번 승인하고 qg 폴더를 나눠 예약해야 한다(B1).
- 계획 하나 · PR 하나 — 계획이 매우 길어지고 R5 계획 셋째가 R2a 전체를 기다린다(B1 · B3).
- 원장 쓰기 락을 셸 파서(bashlex)로 정교하게 — GPLv3 이고, 원인(읽기 전용 예외)을 치우면 파서가 필요 없다.
- markdown-it-py 를 실행 때도 — 사용자 환경에 의존이 생긴다(B2).
- qg 를 넓혀 에픽 사이 통합 리뷰 · 리뷰만 하는 모드 — R5 가 superpowers 리뷰 요청으로 정했다(R5 설계 Rejected).
- 상한 값을 없앰 — 루프 상한은 안전장치다(P18). 공시와 사용자가 여는 길로 고친다.

## 결정 기록

- B1 · 결정 · 2026-10-17 · 나누는 단위 — 「설계 하나, 계획 여럿 (권장)」
- B2 · 결정 · 2026-10-17 · 실제 파서 — 「테스트에서만 씁니다 (권장)」(markdown-it-py, 개발 의존 · `uv.lock` 고정 · 원장 쓰기 락은 원인 치우기)
- B3 · 결정 · 2026-10-17 · 계획 순서 — 「기다리는 것 먼저, 계획마다 PR (권장)」
- B4 · 결정 · 2026-10-17 · 장치 처분표(§1) — 「이대로 (권장)」
- B5 · 결정 · 2026-10-17 · 계획 1(§2) — 「이대로 (권장)」
- B6 · 결정 · 2026-10-17 · 계획 2(§3) — 「이대로 (권장)」
- B7 · 결정 · 2026-10-17 · 계획 3(§4) — 「이대로 (권장)」
- B8 · 결정 · 2026-10-17 · 계획 4 · 연계 · 기각안(§5 · §7 · Rejected) — 「이대로 (권장)」
- D1.1 · r1 · adopt · 0e86d9b7#r1.1 · "고친다 — 사용자가 탐지 수를 엶" — '탐지 리뷰어 1명 고정'의 수정은 진입이나 프로필이 선언할 때만 N 명을 연다. 그런데 이 에픽은 프로필 넷을 모두 1 로 두므로 사용자 쪽에서는 아무것도 바뀌지 않는다. D18 이 요구하는 '사용자가 여는 형태'가 아니다.
- D1.2 · r1 · adopt · 19f7dd62#r1.1 · "고친다 — 모든 리뷰어 persona 보안 리뷰" — 브리프는 'persona 편집은 보안 리뷰를 거친다'고 범위를 정했는데, 문서는 이를 qg 리뷰어 둘로 좁혔다. 그래서 계획 4 가 고치는 plugin-audit 리뷰어 persona 둘(auditor 의 버림 규칙, 반박자의 '불확실하면 기각')은 보안 리뷰 없이 바뀐다.
- D1.3 · r1 · adopt · 3383275a#r1.1 · "고친다 — 비용 장치는 제거" — 문서 스스로 비용·절감으로만 작동한다고 적은 장치 셋(qg 리뷰어 최대 8, plugin-audit 심층검증 8건·6축, 같은 리뷰어 재호출 금지)을 제거하지 않고 '기본값 + 사용자가 여는 길'로 수정한다. 확정 제약 C5·D18 은 이런 장치를 제거하라고 한다.
- D1.4 · r1 · adopt · f070674e#r1.1 · "고친다 — 권한 경계로 막기" — 원장 본문의 요약값으로는 엔진 밖 변경을 막을 수 없다. 실제 엔진은 frontmatter에서 결정·편집 허가·스냅숏을 읽으므로 본문을 그대로 둔 상태 변경이 검사에서 빠진다. 또한 같은 파일을 쓰는 명령은 요약값도 함께 갱신할 수 있어, 이 방식은 작성 주체를 검증하지 못한다.
- 재결정 · 2026-10-18 · B4 장치 처분표(§1) — 원래: 「이대로 (권장)」 / 재결정: 「고친다 — 비용 장치는 제거」(D1.3) / 근거: 확정 C5 「비용을 이유로 품질을 제약하는 장치는 제거하고, 크게 쓰기 전에는 규모만 알린다」(묶음 R2a.md:31)와 D18(R2a.md:39) — §1 에서 비용만 지키던 세 행(qg 리뷰어 최대 8 · 같은 리뷰어 다시 부르기 금지 · plugin-audit 6축과 심층검증 8건)이 수정으로 남아 있었다.
- 재결정 · 2026-10-18 · B6 계획 2(§3) — 원래: 「이대로 (권장)」 / 재결정: 「고친다 — 사용자가 탐지 수를 엶」(D1.1) · 「고친다 — 권한 경계로 막기」(D1.4) / 근거: D18 「상한·압축은 공시하고 사용자가 여는 형태로 수정」(R2a.md:39) — 진입이 선언할 때만 여는 탐지 수는 사용자가 여는 길이 아니었다. 원장 안 요약값은 같은 파일을 쓰는 명령이 함께 고칠 수 있고 엔진은 상태를 frontmatter 에서 읽는다(`shared/docreview/scripts/docreview_state.py:7`).
- 재결정 · 2026-10-18 · B8 계획 4(§5) — 원래: 「이대로 (권장)」 / 재결정: 「고친다 — 모든 리뷰어 persona 보안 리뷰」(D1.2) / 근거: 묶음 의도 「persona 편집은 보안 리뷰를 거친다」(R2a.md:21) — 계획 4 가 고치는 plugin-audit persona 둘(`plugin-auditor` · `audit-refuter`)이 보안 리뷰 대상에서 빠져 있었다.
- 재결정 · 2026-10-18 · B7 계획 3(§4) 문서 경로 기본 패턴 — 원래: 「이대로 (권장)」(기본 패턴 `README*` · `CHANGELOG*` · `docs/**`) / 재결정: 「고친다 — 기본 제외에서 docs/** 뺌」(D5.12) / 근거: `docs/` 아래에 모델 · 훅이 읽는 문서가 있다 — project-init 훅이 `docs/git-workflow/branch-strategy.md` 를 브랜치 규칙으로 읽는다(`plugins/project-init/hooks/post-tool-use.py:83`).
- 재결정 · 2026-10-18 · D2.8 문서 경로 설정 자리 — 원래: 「고친다 — (대체안 미작성) / 후속 질문 답: 환경 변수 + settings.json env (권장)」 / 재결정: 「고친다 — 바꾼 iteration 은 기본 목록」(D5.13 — 자리는 그대로 두고 보호 규칙을 더함) / 근거: 추적되는 `.claude/settings.json` 은 리뷰 대상 변경이 고칠 수 있고, 보안 리뷰어는 걸러진 diff 만 받는다(`plugins/quality-gates/skills/quality-pipeline/SKILL.md:338`).
- 재결정 · 2026-10-18 · B4 장치 처분표(§1) 판정 규칙 · project-init 두 행 — 원래: 「이대로 (권장)」(두 행 처분 「수정」, 3라운드 반영 때 머리말이 사용자 결정을 덮던 자리를 「수정」으로 분류) / 재결정: 「고친다 — D18 원문대로 제거로 분류」(D7.17) / 근거: D18 원문 「비용·절감·압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한·압축은 공시하고 사용자가 여는 형태로 수정」(묶음 R2a.md:39) — 두 행은 기계가 사용자 대신 중단을 정하던 자리다. 동작(사용자가 고르는 선택지)은 그대로다.
- D2.5 · r2 · adopt · 4dd645d5#r2.1 · "고친다 — AC10 에 환경 변수 더함" · supersedes D1.1 — 사용자가 환경 변수로 탐지 리뷰어 수를 열 수 있게 한 결정이 수용 기준에 없습니다. 지금 기준은 프로필 선언만 확인하고, 쓰인 수와 그 출처를 공시하는지도 확인하지 않습니다.
- D2.6 · r2 · adopt · 4dd645d5#r2.2 · "고친다 — AC24·AC35 를 제거로" · supersedes D1.3 — 비용만 지키던 장치 셋을 「제거」로 바꾼 결정이 수용 기준에는 아직 반영되지 않았습니다. plugin-audit 기준은 지금도 「상한을 늘릴 수 있다」로 적혀 있고, qg 기준에는 상한 8과 재호출 금지가 사라졌는지 확인하는 항목이 없습니다.
- D2.7 · r2 · adopt · 89a93115#r2.1 · "고친다 — 계획 4 보안 리뷰 AC" · supersedes D1.2 — plugin-audit 리뷰어 persona 둘도 보안 리뷰 대상에 넣었지만, 계획 4 의 설계 절과 수용 기준에는 그 리뷰가 없습니다. 보안 리뷰 기준은 qg persona(AC27)에만 있습니다.
- D2.8 · r2 · adopt · c7ea8a5f#r2.1 · "고친다 — (대체안 미작성) / 후속 질문 답: 환경 변수 + settings.json env (권장)" — check-intent 거부 후 상향: 문서 경로 패턴을 '레포 설정으로 바꿀 수 있다'고만 적었다. 그 설정이 어느 파일의 어느 키에 사는지, FILTERED_DIFF 를 만드는 자리가 어디인지가 정해지지 않아 Files to Modify 에도 이름 없이 남았다.
- D2.9 · r2 · adopt · e850cf32#r2.1 · "고친다 — AC17 을 둘로 나눔" · supersedes D1.4 — 원장 쓰기를 권한 경계로 막기로 결정했지만, 수용 기준은 여전히 원장 안 요약값이 엔진 밖 변경을 잡는다고 적고 있습니다. 권한 경계를 확인하는 기준은 하나도 없습니다.
- D3.11 · r3 · adopt · 6e2f8815#r3.1 · "고친다 — 처분표에 두 행 더함" — 범위 입력으로 받은 흐름 고정 점검의 project-init 항목 가운데 「Phase 0 스캔은 질문과 겹쳐 돌려도 됨」과 「worktree 경로」가 처분표에 없고, 유지 목록에도 없다. 처분 없이 조용히 빠졌다.
- D5.12 · r5 · adopt · 549f8af9#r5.1 · "고친다 — 기본 제외에서 docs/** 뺌" — 기본 제외 패턴인 docs/**가 행동을 정하는 문서까지 리뷰에서 뺍니다. 실제로 docs/git-workflow/branch-strategy.md는 모델의 작업 규칙이며 project-init 훅이 브랜치 검사 규칙을 읽는 입력입니다. 이를 사람만 읽는 문서로 취급하면 모델이 읽는 문서도 리뷰한다는 범위가 좁아집니다.
- D5.13 · r5 · adopt · 6267a363#r5.1 · "고친다 — 바꾼 iteration 은 기본 목록" — 어떤 파일을 리뷰에서 뺄지 정하는 설정이 리뷰 대상 변경이 직접 고칠 수 있는 파일에 있어서, 변경 하나가 자기 코드를 보안 리뷰에서 빼 버릴 수 있다.
- D5.14 · r5 · adopt · f070674e#r5.1 · "고친다 — 줄 전체를 한 줄 문법" — 결정 기록 줄 위조를 막는 수정이 지적 요약 한 칸에만 걸려 있어서, 같은 줄에 그대로 붙는 다른 칸(사용자가 고른 선택지 문구, 지적을 버릴 때 모델이 적는 사유)으로는 여전히 줄을 위조할 수 있다.
- D6.15 · r6 · adopt · 89a93115#r6.1 · "고친다 — 빠진 행마다 AC 더함" — 장치 처분표의 몇몇 행에는 그 행을 닫는 수용 기준이 없다. 그래서 「처분표의 모든 행이 어느 AC 로 닫힌다」(AC37)를 이 문서 스스로 만족하지 못한다. 3라운드에 더한 project-init 두 행(Phase 0 스캔 겹침 · worktree 경로)도 수용 기준과 계획 4 의 설계 절에 들어가지 않았다.
- D6.16 · r6 · adopt · 89a93115#r6.2 · "고친다 — AC23 을 결정에 맞춤" — 문서 경로 수용 기준(AC23)이 이미 내린 두 결정을 반영하지 않았다. 기본 제외 목록에 지운 docs/** 가 아직 들어 있고, 설정이 바뀐 iteration 은 기본 목록으로 되돌린다는 보호 규칙과 걸러진 diff 가 비면 not-certified 로 낸다는 규칙이 없다.
- D7.17 · r7 · adopt · 3383275a#r7.1 · "고친다 — D18 원문대로 제거로 분류" — 처분표의 판정 규칙이 확정 제약 D18 과 반대로 적혀 있다. D18 은 사용자 결정을 덮는 장치를 「제거」하라고 하는데, 문서는 그런 장치를 「수정」 쪽으로 분류한다.
- D8.18 · r8 · adopt · 3383275a#r8.1 · "고친다 — 쓴 값 공시 + 사용자가 엶" — 처분표에서 '수정'으로 남긴 두 상한(project-init 질문 4개·관례 1–3개, 문서 비평 dispatch 수)이 공시도 없고 사용자가 여는 길도 없이 '기본값, 더 받을 수 있게'로만 적혀 있다. 확정 제약은 상한을 수정할 때 공시하고 사용자가 여는 형태로 하라고 한다.
- D9.19 · r9 · adopt · 89a93115#r9.1 · "고친다 — AC29·AC31 에 공시·여는 길" — 문서 비평의 dispatch 수와 project-init의 질문 수 · 관례 개수에 대해 기본값과 실제로 쓴 수를 그 자리에서 알리고 사용자가 그 자리에서 여는 길을 두기로 했지만, 수용 기준은 여전히 「기본값이고 바꿀 수 있다」만 확인한다.
- D9.20 · r9 · adopt · 89a93115#r9.2 · "고친다 — AC15 를 칸 전체로" — 결정 기록 줄 위조 방지의 수용 기준이 아직 요약 칸만 확인한다. 줄 전체를 한 줄로 만들기로 한 결정이 기준에 들어가지 않아, 선택지 문구나 버림 사유 칸이 위조 경로로 남아도 통과한다.
- D9.21 · r9 · adopt · e850cf32#r9.1 · "고친다 — 공시를 두 줄로 나눔" — qg 리뷰어 수를 알리는 「시작 줄」에 일시 실패 재시도처럼 시작 뒤에야 생기는 호출까지 세라고 해서, 이 줄이 dispatch 전에 찍히는지 후에 찍히는지가 정해지지 않았다. 지금 줄은 dispatch가 돌아온 뒤에 찍히므로 그대로 옮기면 「크게 쓰기 전에 규모를 알린다」는 확정 제약을 지키지 못한다.
- D10.22 · r10 · adopt · 89a93115#r10.1 · "고친다 — AC7 에 /qg 더함" — 설계는 `/qg` 를 레포 전체에서 찾아 고친다고 했지만, 수용 기준은 `/qg critique` 만 검사한다. 그래서 기계가 내는 안내 속 그냥 `/qg`(`/qg branch` 등)가 남아도 통과한다. 호출 표면 락도 `/qg` 를 잡지 못한다.
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r1: advice_new=5 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r2: advice_new=5 · advice_repeat=2 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r3: advice_new=1 · advice_repeat=6 · mc_preexisting_new=1
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r4: advice_new=3 · advice_repeat=6 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r5: advice_new=2 · advice_repeat=7 · mc_preexisting_new=3
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r6: advice_new=0 · advice_repeat=4 · mc_preexisting_new=2
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r7: advice_new=1 · advice_repeat=8 · mc_preexisting_new=1
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r8: advice_new=3 · advice_repeat=7 · mc_preexisting_new=0
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r9: advice_new=0 · advice_repeat=8 · mc_preexisting_new=3
- docreview 계수 — 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7/2026-10-17-shared-review-engine-devices--ef660192c676324e r10: advice_new=1 · advice_repeat=8 · mc_preexisting_new=0
- 승인 게이트 2단계 · 2026-10-18 · 진행 옵션 — 사용자 원문 「2」 / 해석: 지휘자가 보인 순서의 둘째(「① 새 세션에서 계획 쓰기 (권장)」)로 읽든 skill 의 「② compact 후 계획 쓰기」로 읽든 결과는 같다 — 리뷰를 닫고 계획 쓰기로 간다(③ 수정은 고르지 않음). 지휘 아래라 세션을 새로 열지 않고 같은 작업 폴더에서 writing-plans 를 계획 1 부터 쓴다.
- 계획 1 결정 · 2026-10-18 · 재비판 블록 — 원래 설계 문면: §2 「재비판 블록도 같은 함수라 같이 바뀐다」 / 계획의 결정: 지적 목록 블록(층 1 · 층 2)만 합치고, 재비판 매핑 블록은 마지막 블록을 읽되 개수를 공시한다 — 사용자 「계획대로 — 지적만 합침 (권장)」 / 근거: qg 재비판 합성기가 같은 함수를 쓰고(`plugins/quality-gates/scripts/synthesize_findings.py:466-467`) 「펜스가 둘이면 마지막이 판정 — 인용 예시가 판정이 되지 않는다」를 잠근다(`plugins/quality-gates/tests/test_synthesize_recritic.sh:705-712`).
- 계획 1 결정 · 2026-10-18 · qg 인자 확인 자리 — 원래 설계 문면: §2 「`## 진입 단계` 에 `!` 사전 검사(지금 `setup-qg.sh` 가 하던 인자 확인 · 없어진 인자 안내)를 두고」 / 계획의 결정: 사전 검사 줄은 상수 인자만 받고, 인자 확인과 없어진 인자 안내는 본문 첫 단계(P2 의 `setup-qg.sh --ensure $ARGUMENTS`)가 한다 — 사용자 「계획대로 — 본문 첫 단계 (권장)」 / 근거: `shared/entry/entry_preflight.py` 는 사용자 입력을 받지 않고, 호출 표면 락이 사전 검사 줄의 모양을 고정하며 사용자 인자 토큰을 금지한다(`shared/entry/check_invocation_surface.py:47-48 · :213-218` · `axis_d`).
- 계획 1 결정 · 2026-10-18 · 기준선 스크립트 — 원래 설계 문면: §2 「닫힌 묶음(셋 + 형제)째 옮기거나 소비 플러그인이 형제까지 링크하게 한다 — 어느 쪽인지는 측정이 정하고」 · §6 「qg 범위 | … `resolve-baseline.sh` … | qg」 / 계획의 결정: `resolve-baseline.sh` 도 `shared/test-selection/` 으로 함께 옮겨 넷을 닫힌 묶음으로 둔다 — 사용자 「계획대로 — 함께 옮김 (권장)」 / 근거: `compute-test-scope-candidates.sh:18,54` 가 링크를 풀지 않은 자기 폴더에서 `resolve-baseline.sh` 를 부른다 — 다른 플러그인이 qg 안 파일을 링크하면 설치본에서 닿지 못한다. 계획 3 의 범위 기준 변경은 공유본 변경이다.
- 계획 1 실행 방식 · 2026-10-18 — 사용자 「Subagent-driven」.
- B9 · 결정 · 2026-10-18 · 리뷰 엔진 — 결정이 다른 절에 닿을 때(§3 함께 고친 곳 신고 · AC38) — 질문 「리뷰에서 「고친다」로 정한 결정이 문서의 다른 절(수용 기준 · 처분표 등)에도 닿을 때, 그 절들을 어떻게 고치게 할까요?」 → 「같이 고치고 보이고 다시 봄 (권장)」(근거는 B13)
- B10 · 결정 · 2026-10-18 · 리뷰 엔진 — 결정과 반대인 본문(§3 결정 반대 본문은 저자 고침 · AC39) — 질문 「리뷰어가 「이 본문은 사용자가 정한 결정과 반대다」를 찾았을 때(지금은 참고로만 쌓임), 어떻게 처리할까요?」 → 「저자가 바로 고침 (권장)」(근거는 B13)
- B11 · 결정 · 2026-10-18 · 리뷰 엔진 — 추가 라운드 승인(§3 추가 라운드 승인 · AC40) — 질문 「리뷰 추가 라운드를 여는 승인을 어떻게 받을까요?」 → 「고른 선택지를 승인으로 (권장)」(근거는 B13)
- B12 · 결정 · 2026-10-18 · 리뷰 엔진 — 게이트 쉬운 말(§3 게이트 쉬운 말 · AC41) — 질문 「리뷰 게이트 글이 내부 기호 없이 혼자 읽히도록 어떻게 지킬까요?」 → 「규칙 + 엔진 글 검사 (권장)」(근거는 B13)
- B13 · 결정 · 2026-10-18 · 리뷰 엔진 짧은 설계 전체(§3 B9~B12 · AC38~AC41 · 계획 2) — 「이대로 (권장)」 / 근거(사용자): 「지금 스펙리뷰한 이후 나에게 설명이 오는게 매끄럽지 않고 설명을 보고 내가 리뷰해주기에 어려운 상태야 …」 · 「R2a 에 넣기 (권장)」 · 「앞으로도 너가 판단하기에 에픽에 넣더라도 이거 brainstorming 거쳐서 추가해야 겠는지 판단을 할 수 있도록 해줘」 / 경로: 짧은 설계(채팅 안 설계 + 승인) — 사용자에게 보이는 리뷰 동작이자 새 요구라 brainstorming 이 필요하고, 이미 있는 엔진을 고치는 범위라 짧은 설계로 했다.
- B14 · 결정 · 2026-10-18 · 계획 2 — 엔진 값(환경 변수)이 잘못됐을 때(계획 2 「설계에 없던 결정」 2) — 「라운드를 시작하지 않고 이유를 낸다 (권장)」
- B15 · 결정 · 2026-10-18 · 계획 2 — 「반대」 지적이 가리킬 수 있는 결정(계획 2 「설계에 없던 결정」 5) — 「엔진 원장의 결정만 (권장, 설계 문면대로)」
- B16 · 결정 · 2026-10-18 · 계획 2 — 닫지 못한 원장 쓰기 권한 경계(AC17 가)의 받는 곳(계획 2 「설계에 없던 결정」 8) — 「R8」
- B17 · 결정 · 2026-10-18 · 계획 2 — Write · Edit 만 막는 부분 훅을 더할지(계획 2 「설계에 없던 결정」 8) — 「더하지 않는다」
- 계획 2 실행 방식 · 2026-10-18 — 사용자 「Subagent-driven」.
- B18 · 재결정 · 2026-10-19 · 리뷰 엔진 — 결정 반대 라우팅을 보안 수리대로 좁힘(§3 결정 반대 본문 · AC39, 보안 경고 3 · S5~S7) — 질문 「R2a — 결정과 반대인 본문을 저자가 고치는 규칙을 보안 수리대로 좁힐까요? (수용 기준 AC39 문면이 바뀝니다)」 → 「보안 수리대로 (권장)」 · 사용자 「1, 그래 우리 원칙은 각자 역할을 하는거고 서로 건든 충돌이나 회귀 같은 버그가 아니어 다행이네」

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C5 · S1 | 반영 | §1 — 비용 · 절감으로만 작동하던 상한(리뷰어 8 · 심층검증 8 · 질문 ≤4)을 기본값 + 규모 공시 + 사용자가 여는 길로 · AC24 · AC35 |
| C11 · S3 | 반영 | §1 처분표 전부 · AC37 |
| C12 · S4 | 반영 | §1 처분 「수정」 행들 — 제거가 아니면 공시하고 사용자가 여는 형태 |
| C13 · S5 | 반영 | Goals — 장치 제거 · 수정이 이 에픽의 작업 항목 · §10 |
| C25 · C35 · D26 · S17 · S18 · S34 | 반영 | Non-goals · Constraints — superpowers · pr-review-toolkit 파일은 손대지 않고 qg 가 부르는 쪽만 |
| C32 · S30 | 반영 | Constraints · §8 — 엔진 라운드 열기 · 회계 모듈 · 링크 공유 · `seed_body` 방식 재사용 |
| D15 · S7 · OQ2 | 반영 | Goals 끝 줄 · §7 되돌아오는 길 · AC37 — 목록 전부를 대상으로 받고 조사를 계속 |
| D18 · S10 | 반영 | Constraints · §1 머리 — 기준 그대로, 그대로 남는 장치 0 |
| D21 · S13 | 반영 | §9 — 이 조각에 실린 위험 K7 과 실패 양식에 답 |
| OQ29 | 반영 | §1 처분표(이 에픽 몫 장치 각각의 제거/수정 판정) · §7 되돌아오는 길(전수는 계속) |
| OQ31 · RC85 | 반영 | §2 qg 진입 이름(P3 결정 적용) · §4 의도 출처 형식(`specs` 목록 · 범위 모드 계약) · AC6 · AC7 · AC21 · AC22 |
| RC6 · RC56 · RC65 | 반영 | §1 · §3 상한 값 설정 · 게이트 문구 · AC12 · AC13 |
| RC51 | 반영 | §1 · §4 리뷰어 구성 · 수정 루프 · AC24 · AC25 |
| RC52 | 반영 | §1 · §4 낮춘 지적 절 · 되올리기 · AC26 |
| RC53 | 반영 | §1 · §5 · AC31 |
| RC54 | 반영 | §1 · §5 · AC34 |
| RC57 | 반영 | §1 · §3 접기 값 · AC12 |
| RC58 | 반영 | §1 · §4 artifact-critique · AC29 |
| K7 | 반영 | §9 첫 줄 — 지키던 것 칸 · 사용자 통제 자리 분리 · 조사 계속 |
| S33 | 반영 | §1 — 로드맵이 넘긴 장치 밖으로 qg · project-init · plugin-audit 전수 조사한 행들(같은 반복 재호출 · e2e · trivia · 차등 · 코퍼스 제외 등) |
| S49 | 반영 | Goals · §3 「나머지 알려진 우회」 — 작업 범위를 줄이지 않는다 |
| S51 | 반영 | 의존 — qg 를 건드리는 이 에픽은 P2 · P3 머지 뒤(로드맵 블록 의존) · §2 P3 적용 |
| «chesterton-fence» | 반영 | Constraints · §1 「지키던 것」 칸 |
| «chroma-context-rot» | 반영 | §9 긴 입력 |
| «claude4-best-practices» | 반영 | §9 지시를 정확히 따르는 모델 |
| «context-engineering» | 반영 | §9 긴 입력 · §3 접기는 화면에서만 |
| «mast» | 반영 | §9 실패 양식 |
| «sycophancy» | 반영 | §9 K7 |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| qg · project-init · plugin-audit README · CHANGELOG 의 낡은 개념(이 설계가 바꾸는 동작 밖) | 원칙 문서 · 낡은 개념 정리는 R11 범위 | R11 |
| 링크 공유 · 문서 경로 · 상한 설정이 devbrew 밖 레포와 superpowers · gh 부재에서 통하는지 | 경로 규약 범용화 · 부재 강등은 R8 범위 | R8 |
| 「버그가 새면 해결책은 persona 편집」 등 규칙 문면 | 규칙 문면은 R9 범위 | R9 |
| `shared/tests/test_copy_of_contract.sh` 의 소비 도출이 한 플러그인 문서의 다른 플러그인 전체 경로 인용(`plugins/<다른>/scripts/<이름>`)을 소비로 읽는 오탐 — 계획 1 은 spec-distill CHANGELOG 옛 항목 문구 하나를 바꿔 피했다. 같은 락의 양성 짝이 `.md` 전량 제외 같은 넓은 제외를 못 잡고(`doc-critic.md` 짝이 없다) 제외 목록 주석이 낡았다 | 계획 1 범위 밖의 락 도출 고침 — `shared/tests` 는 R2a 영역 (R2a 끝 — 지휘자 판정 2026-10-20) 끝냄 — 9be978f5 · 0f1d9804 | R12 |
| 계획 1 최종 리뷰의 보류 둘 중 하나: `test_qg_critique_routing.sh` 가 P1b 가 P2 보다 앞에 있는 순서를 잠그지 않는다(뒤로 옮겨도 통과) | 기능 결함이 아니라 락 보강 — 뒤 계획이 같은 파일을 고칠 때 — 끝냄: 7a77eb4c(계획 3 Task 1 — P1b 가 P2 앞이라는 순서 락) | R2a |
| 계획 1 최종 리뷰의 보류 둘 중 하나: `case_same_name_block_broken_kills_critic`(파손 블록을 앞에) 하나로는 「첫 블록만 읽는」 구현을 못 가른다(지금은 `case_same_name_blocks_disclosed` 가 잡는다) | 기능 결함이 아니라 락 보강 — 뒤 계획이 같은 파일을 고칠 때 (R2a 끝 — 지휘자 판정 2026-10-20) 끝냄 — a1b3b45d | R12 |
| 라우터 합침의 남은 빈틈: 흡수로 항목을 버리는 분기가 배선 락(`test_adjudication_wiring.sh`) 스캔 밖이라 `ev("absorbed")` 단언 하나가 지킨다 · `tools/adjudication/check_wiring.py` EXEMPT 가 줄번호로 박혀 `docreview_route.py` 위쪽을 고치면 다시 박아야 한다 · 같은 블록 안에서 흡수된 재전송과 새 항목이 같은 임시 번호를 쓰면 마지막 것이 조용히 이긴다 · 바꾼 번호 `<ref>@b<k>` 가 리뷰어의 실제 번호와 겹칠 수 있다 | 계획 2 는 이 넷 중 셋은 고치지 않았다(흡수 분기의 스캔 · `EXEMPT` 줄번호 · 같은 임시 번호) — 리뷰어 사이 겹침을 흡수하는 갈래를 더했고(`ev("absorbed")` 로만 세며 배선 락 스캔 밖이다) `EXEMPT` 줄번호를 다시 박았을 뿐이다. 흡수된 사본의 `blocks` 를 잃던 빈틈과 리뷰어가 쓴 `ref` 의 `@d<i>` 꼬리표가 다른 리뷰어의 번호와 겹치던 빈틈은 계획 2 가 닫았다(`@` 는 `_` 로 바꾸고 센다 — 합치기 단계의 `@b<k>` 겹침, 곧 넷째 항목도 같이 닫혔다. 같은 블록 안에서 같은 임시 번호를 쓰는 둘은 따로 남는다) (R2a 끝 — 지휘자 판정 2026-10-20) · `EXEMPT` 줄번호 끝냄 — bb5571fd · 흡수 분기의 스캔 끝냄 — 8a10e4a7 · 같은 임시 번호 끝냄 — 6b507700 · 6d8425ef(R12 계획 1) | R12 |
| 호출 표면 락의 남은 빈틈: `_LEAD` 가 `*/qg*` · `[/qg]` · 빈칸 없는 표 칸 속 `/qg` · `<code>/qg</code>` 앞 글자를 못 본다 · `_OLD_TRAIL` 이 ` /qg.md` 같은 꼴을 RED 로 본다(안전 쪽 오탐) · 살아 있는 표면에 `docs/git-workflow/` 와 `.claude-plugin/marketplace.json` 이 없어 계획 1 이 쓸어 낸 옛 이름을 기계가 지키지 않는다 | 지금 레포에 해당 꼴이 없고 표면 범위는 계획 1 이전부터의 결정 — 락을 넓힐 때 음성 대조와 함께 (R2a 끝 — 지휘자 판정 2026-10-20) 끝냄 — 9c3372e4 · e3775275 | R12 |
| `setup-qg.sh` 의 `critique` 안내 모서리: 첫 인자 검사는 kill switch 앞(exit 2), 인자 루프는 뒤(exit 1) · `branch critique` 는 브랜치 이름으로, `--paths critique` 는 범위 glob 으로 먹혀 안내가 안 나온다 · `--help` 의 없어진 인자 줄에 `critique` 가 없다 | 계획 3 이 `setup-qg.sh` 에 범위 인자를 더할 때 같은 인자 해석을 고친다 — 끝냄: 7a77eb4c · cc0a33e8(계획 3 Task 1 — kill switch 가 먼저, 위치 무관 안내, `--help` 의 없어진 인자 줄) | R2a |
| artifact-critique 문면: E0 kill switch 메시지의 `critique skipped` · `critique mode disabled` 옛 모드 이름 · egress 문장의 「그 파일로 고정」(E2c 는 경로 문자열을 고정한다 — 「그 경로로」) · 그 줄 150자 · 음성 검사가 고정 문구만 본다(`tools: $tools` 대조가 더 강하다) | 계획 3 이 artifact-critique 를 고친다(AC29) — 끝냄: 807f177c · d3e38af8(계획 3 Task 12 — 옛 모드 이름 · 「그 경로로」 · 실제 `tools:` 줄 대조) | R2a |
| CHANGELOG 다듬기: spec-distill 7.2.1 의 절 순서(Fixed 가 Changed 앞) · 옛 skill 이름 `critiquing-artifacts` 가 Changed 에만 있고 Removed 에 없다 · qg 새 링크 `scripts/entry_preflight.py` 가 CHANGELOG 에 없다 — 끝냄: 5d1796b0 에서 고쳤다(qg 14.0.0 의 절 순서도 함께) | 계획 1 머지 전에 고쳤다 — 남은 일 없음 | R2a |
| 공유본 넷을 모두 링크 — `compute-test-scope-candidates.sh` 가 형제 `resolve-baseline.sh` 를 자기 폴더에서 부른다(R5 설계 §5 · 변경표는 「스크립트 셋」이라 적었다, 소비 규칙은 `shared/test-selection/README.md`). 설치본 캐시 사본에서 형제 경로(compute → resolve-baseline, diff → run-test-selection)는 계획 1 이 `detect` 로만 쟀다 | R5 계획 셋째가 공유본을 링크하고 합친 사본 스위트로 잰다 | R5 |
| qg 새 진입 이름 `/quality-gates:quality-pipeline` · `/quality-gates:artifact-critique` — R5 끝 단계의 qg 호출 꼴은 계획 3 의 범위 모드(`range <시작>[..<끝>]`)에서 정해진다 | 호출 꼴은 범위 모드가 생긴 뒤 확정 — 끝냄: 계획 3 범위 모드(SKILL range 인자 안내 — `range <시작>[..<끝>]`, 끝 생략 시 origin/HEAD) | R5 |
| 엔진이 아닌 명령이 원장을 쓰는 길(AC17 가): 쓰기 · 고치기 도구는 훅이나 권한 설정으로 막을 수 있다(헤드리스 측정에서 둘 다 파일이 그대로였다). 그러나 셸로 상태와 요약값을 함께 다시 계산해 쓰는 시도는 훅 · 권한 설정 · 파일 모드(`chmod a-w`, 소유자가 `chmod u+w` 로 되돌린다) 어느 것도 막지 못했다(측정 기록 `boundary-measure.md`, 레포 밖 sdd-mirror). 측정은 후보 셋 × 시도 셋(파일 모드는 셋째에 되돌리는 시도 하나를 더했다) 전부 파일의 바이트로 판정했다. 요약값 대조(AC17 나)는 엔진 밖에서 상태만 바꾼 원장을 멈추고, 상태 폴더의 시대 표지 파일이 남아 있는 동안은 확인값 줄을 지운 원장도 멈춘다(표지 파일이 지워졌거나 만들지 못했을 때는 이 탐지가 없다 — 만들지 못했으면 엔진이 한 줄로 알린다). 그러나 셸로 쓰는 쪽은 표지 파일을 지우거나 요약값을 다시 계산할 수 있어 같은 셸 축이다 — (나)가 모든 편집을 잡는다고 쓰지 않는다. 같은 축에 남는 것: audit `## 2` 의 여러 줄 사용자 답은 쓰는 쪽 계약(`seed_review_log.py one-line` 을 거친 한 줄)으로 닫았고, 그 계약을 어기는 쓰는 쪽(정직하지 않은 쓰기)만 남는다 | 쓰기 권한 경계가 레포 밖(하니스 권한 · 샌드박스)에 있다. 쓰기 · 고치기만 막는 부분 훅은 더하지 않는다(B17) — 막는다는 믿음만 주고 셸 길은 열려 있다 (결정 B16) | R8 |
| AC20 일부 · 지휘 세션이 `begin-round` 에 넘기는 스냅숏 칸(해시 · 제목 · 부모 · 앵커)을 엔진이 그대로 믿는다: 쓰는 세션 안에서는 엔진이 만든 스냅숏과 쓴 사람이 만든 스냅숏을 가를 수 없어, 위조한 스냅숏이 보호 절의 변경을 가릴 수 있다(AC17 가와 같은 축 — 엔진 밖의 쓰는 쪽을 권한으로 가르지 못하는 문제) | 엔진이 스냅숏을 직접 만들 수는 있다(`docreview_anchor.py snapshot`). 그래도 쓰는 세션이 원장에 저장된 스냅숏까지 다시 쓸 수 있어, 엔진 밖의 쓰는 쪽을 권한으로 가르지 못하는 AC17 (가)와 같은 축에 남는다 (결정 B16) | R8 |
| AC20 일부 · `seed_review_log.py log --quote-file` 과 `log-decision --quote` 는 모델이 쓴다: 파일 경로나 인자는 출처를 보증하지 않아, 그 문구가 사용자가 한 말을 그대로 옮긴 것인지 읽는 쪽이 가를 수 없다(`decide --quote` 와 같은 축) | 모델이 쓰는 파일 · 인자의 출처는 판독기 방식으로 가를 수 없다 — 내용이 아니라 작성 주체의 문제다(AC17 가와 같은 권한 경계 축) (결정 B16) | R8 |
| AC20 일부 · seed audit 의 진짜 템플릿 제목이 없으면 그 제목과 같은 비신뢰 줄(`## 1` 원문 안 줄 등)이 펜스와 무관하게 절이 되어 읽힌다. 빠진 제목이 있는 부분 audit 은 `check_seed` 가 `audit_heading_missing` 으로 닫았다 | 남는 것은 «심은 줄과 같은 바로 그 제목만 빠진» 꼴이다 — 일곱 제목이 모두 있고 순서도 맞아 글자만으로 심은 줄과 진짜 줄을 가를 수 없다. 펜스로 가르는 규칙은 정직한 audit 을 같이 거부한다(`## 1` 의 닫히지 않은 펜스가 `## 3` 코드 블록 여는 줄과 짝지어 `## 2` 가 펜스 안에 든다 — 이 꼴을 읽는 것이 잠긴 결정이다, `test_seed_trust_boundary.sh` 의 정직한 펜스 양성). 남는 꼴은 audit 을 쓴 쪽이 속이는 경우라 AC17 (가) 행과 같은 축이다 (결정 B16) | R8 |
| 합친 보안 리뷰의 가벼운 제안 넷이 계획 2 에서 열린 채다. (1) 리뷰 값을 정하는 환경 변수(`DEVBREW_DOCREVIEW_*`)에 최댓값이 없어, 큰 값을 넣으면 라운드 · 화면이 끝없이 커질 수 있다 (2) 브리프 원문 절(§6)의 마지막 앵커 밑에 이어 붙인 줄은 그 앵커의 일부로 읽혀 중간 리뷰에서 걸러지지 않는다 (3) 문서 제목에 `</related_changes>` 가 들어 있으면 리뷰어에게 넘기는 묶음의 닫는 표시가 일찍 닫힐 수 있다 (4) `declare-related` 는 표지 확인 줄 다음에만 부른다고 글(절차서 · 진입 skill 셋)로 정했지만, 락(`test_ledger_wiring.sh`)이 지키는 펜스는 없다 | 넷 모두 지금 쓰는 길에서 해를 낸 적이 없고 값 · 문서 모양을 더 좁히는 일이라 계획 2 의 보안 잔여 범위를 넘는다 — 각각 최댓값 · 경계 검사 · 펜스를 더하며 음성 대조와 함께 고친다 (엔진 몫 — 남은 R2a 계획 범위 밖, 결정 2026-10-19 새 에픽) 끝냄 — 9a95c253 · 4fb5c4c8 · 31f56239 · 4cb02179(R12 계획 1) | R12 |
| 확인된 결정의 보호가 «붙어 있지 않다»: 보호 절 아래 있던 자식 절이 채택한 제목 삽입 때문에 보호 울타리 밖으로 밀려나도, 울타리를 직전 스냅숏으로만 계산해서 그 뒤 라운드에 보호가 이어지지 않는다 | 울타리를 모든 앞선 스냅숏에서 다시 계산하거나, 보호 절이 울타리를 벗어나면 게이트가 깃발로 알리는 식이 필요하다. 마지막 수정 라운드를 작게 두려고 최종 리뷰로 미뤘고 계획 2 에서는 고치지 않았다 (엔진 몫 — 남은 R2a 계획 범위 밖, 결정 2026-10-19 새 에픽) 끝냄 — caca02f4 · a79c5c4f(R12 계획 1) | R12 |
| 열린 리뷰 안에서 `## 번호 대조` 표의 행 고침(기각 되돌리기)과 `## 미룸` 행 더하기(재분해)를 허가 없이 손으로 하는 길: design-doc 프로필에서 두 절은 울타리 절이 아니라 보통 절이다(`immutable` 이 비었고, 미룬 항목의 박제처는 `### Deferred to plan`). 그래서 허가(permit)나 고침 범위 없이 고친 행은 다음 라운드에 「허가 없이 바뀜」 결정으로 다시 올라온다 | 두 절은 허가 · 고침 범위로 면제할 수 있지만, 기각 되돌리기 · 재분해 절차가 그 면제를 받는 걸음을 적지 않았고 `log-decision` 은 결정 기록 절의 한 줄만 쓴다. 절차에 면제 받기를 더할지, 표 행을 쓰는 엔진 명령(표 문법 검증 포함)을 더할지 정해야 한다 (엔진 몫, 결정 2026-10-19 새 에픽) 끝냄 — 80bb435a · 9aea23a1(R12 계획 1) | R12 |
| 리뷰가 닫힌 뒤 지휘 세션이 손으로 쓴 결정 줄은 원장이 남아 있으면 같은 문서의 재리뷰에서 「허가 없이 바뀜」 결정이 된다 (원장이 없을 때 쓴 줄은 다음 리뷰가 기준으로 삼는다) | 닫힌 리뷰의 원장에 `log-decision` 을 쓰게 할지, 재리뷰 init 이 그 사이 결정 줄을 기준으로 받을지 정해야 한다 — 어느 쪽도 울타리를 넓히지 않게 (엔진 몫, 결정 2026-10-19 새 에픽) 끝냄 — 8d7f9176 · 5ccac632(R12 계획 1) | R12 |
| `log-decision` 을 표지 확인 줄 다음에만 부른다는 가드는 절차 규칙이다 — 펜스가 그 순서를 지키고 원장 쓰기 락(AC8)이 명령 이름을 쓰기 목록에 두지만, 엔진 자신은 표지 확인 없이 불려도 거부하지 않는다 | `declare-related` 와 같은 꼴(위 보안 참고 넷의 (4))이라 함께 고친다 — 엔진이 표지를 직접 확인하게 하거나 펜스를 락으로 잠근다 (엔진 몫, 결정 2026-10-19 새 에픽) 끝냄 — 4cb02179(R12 계획 1) | R12 |
| 요청 프레이밍이 critic 출력을 비우는 자리(`skills/request-framing/SKILL.md` 의 프로필 읽기 실패 펜스 — `critic.txt` 와 번호 붙은 `critic-[0-9]*.txt` 를 `: >` 로 제자리에서 자른다)는 링크를 따라가 상태 폴더 밖 파일을 비울 수 있다. spec-review · reviewing-brief 가 쓰는 공유 `clear_critic_outputs.sh`(링크 · 파일이 아닌 것은 건드리지 않고 지운 뒤 새로 만든다)와 다르다 | 보안 재리뷰가 찾았다(H2). 이 PR 은 spec-review 의 비움만 공유 스크립트로 옮겼고, 요청 프레이밍 펜스를 같은 스크립트로 옮기는 일은 그 skill 을 고치는 에픽 몫이다 끝냄 — dc8ed7f7 | R10 |
| `clear_critic_outputs.sh` 의 `set -C` 창(지운 뒤 새로 만들 때 다른 쓰는 쪽이 같은 이름을 다시 심으면 열지 않고 실패한다)을 재는 시험이 없다 — `set -C` 를 빼도 GREEN 이다. 리뷰어 제안: 지우기 뒤에 하드 링크를 다시 심는 `rm` 대역으로 「다시 심음」 꼴을 만들어 재고, 파일이 아닌 것을 다시 심는 경우의 주석을 바로잡는다 | 보안 재리뷰가 찾았다(H3). 기능 결함이 아니라 락 보강이라 이 PR 의 수정 범위 밖이다 — 같은 스크립트를 다시 고칠 때 음성 대조와 함께 끝냄 — dc8ed7f7 | R10 |
| project-init S4 「CLAUDE.md 는 그대로 두기」 + 헌장 C-S3 (b): AGENTS.md 에 `## Project Charter` 가 생기지 않아 실행마다 CLAUDE.md 의 헌장 절을 다시 읽는다(손실 없음) | 계획 4 가 S4 헌장 이전을 고치며 남은 모서리 — 「그대로 두기」가 관리 절을 담는 파일 둘을 남기는 데서 온다, 계획 4 범위 밖의 규칙 정리 (R2a 소결함 — 사용자 결정 2026-10-19 새 에픽으로) 끝냄 — 00507112 · e3775275 · 02840a49 | R12 |
| project-init AGENTS.md 에 이미 관리 절이 있는 S4 「옮기기」: CLAUDE.md 쪽의 다른 `## Project Charter`(또는 git 규칙을 지킨 실행의 `## Git Workflow`)가 「중복」으로 공시 없이 빠진다 | 계획 4 이전부터 있던 동작 — 판정 범위 밖 (R2a 소결함 — 사용자 결정 2026-10-19 새 에픽으로) 끝냄 — 00507112 | R12 |
| project-init Step 5 보고의 「CLAUDE.md 를 그대로 뒀다면:」 문구 — 「「CLAUDE.md 는 그대로 두기」를 골랐다면:」으로 다듬을지(관리 절이 없는 CLAUDE.md 에도 읽힐 수 있다) | 문구 다듬기 — 바꾸면 테스트 접두도 함께 (R2a 소결함 — 사용자 결정 2026-10-19 새 에픽으로) 끝냄 — 00507112 | R12 |
| plugin-audit 의 kill switch 검사 정규식(`plugins/plugin-audit/scripts/check-shape-completeness.py` 의 `_KILLSWITCH_RE` = `DEVBREW_[A-Z0-9_]*_DISABLE`)이 플러그인 자기 이름에 묶이지 않는다 — 다른 플러그인의 스위치 이름이나 하위 스위치만 있어도 「훅이 kill switch 를 존중한다」로 통과한다 | R11 §5 넘김 — R2a 이번 계획들의 범위 밖, R2a 남은 리뷰 엔진 · qg 소결함(R12) 끝냄 — 0318c135 | R12 |
| docreview 엔진 결함 셋: (1) 한 라운드에 `finalize` 를 두 번 부르면 둘째 호출이 첫 호출이 이미 소비한 준비(`pending_recritic`)를 찾지 못해 `finalize_failed` 를 남기고, 첫 호출이 성공했는데도 그 라운드 게이트가 「미검증」(`finalize_incomplete`)으로 열린다 · (2) 탐지 리뷰어가 `edit_scope` 를 쉼표로 이은 복수 앵커(`#a, #b`)로 내면 라우터는 그대로 통과시키고 `docreview_anchor.py check-intent` 가 앵커 하나와의 문자열 일치만 받아 `anchor_unresolved` 로 그 fix 를 되돌릴 수 없는 escalated 로 굳힌다 · (3) `### §B …` 헤딩을 리뷰어는 `#§b-…` 로 내는데 엔진 slug(`docreview_state.slugify`)는 `§` 를 뺀 `#b-…` 라서, permit 이 스냅숏에 없는 앵커를 가리키고 옳게 적용한 수정도 만료 · 재상승을 되풀이한다(2026-09 실사용에서 재현) | R11 §5 넘김 — R2a 이번 계획들의 범위 밖, R2a 남은 리뷰 엔진 · qg 소결함(R12) 끝냄 — 43a9bbd7 · 6b507700(R12 계획 1) | R12 |
| design-doc 프로필에 대안 비교 축(Rejected Alternatives 의 비교가 실제로 됐는지)이 없다 | R11 §5 넘김 — R2a 이번 계획들의 범위 밖, R2a 남은 리뷰 엔진 · qg 소결함(R12) 끝냄 — 6140a579 | R12 |
| 철학 P3 의 문장 「문서 리뷰 자리 넷(design doc · brief · seed · generic)」이 사실과 어긋난다 — 엔진을 쓰는 자리는 셋이고, qg 의 `generic` 프로필은 엔진 테스트만 읽는다(문서 비평은 별도 루프) | R11 §5 넘김 — R2a 이번 계획들의 범위 밖, R2a 남은 리뷰 엔진 · qg 소결함(R12) 끝냄 — 6140a579 | R12 |
| qg 합성기 `synthesize_findings.py` 의 `finding_id`(= `agent-file-line`)가 같은 리뷰어 · 같은 파일 · 같은 줄의 서로 다른 지적에 같은 id 를 준다(줄이 없거나 `10-12` 같은 범위 줄은 0 으로 접혀 더 자주 겹친다). 재비판이 둘을 다르게 판정하면(하나 기각 · 하나 유지) 합성기가 「같은 finding_id 에 갈린 재비판 판정」으로 hold 해 정당한 실행이 `not-certified (findings-lost)` 가 되고, 둘 다 `lower` 면 첫 지적의 낮춘 이유가 둘째에 붙는다. 실패 방향은 막는 쪽이라 소실은 없다. 고치려면 id 에 요약을 넣어(내용 기반 · 순서 무관) 정체를 가르고 `test_synthesize_recritic.sh` 의 충돌 케이스 넷을 다시 써야 하며, `tools/adjudication/check_wiring.py` 의 dedup 면제 줄번호 핀도 함께 옮겨야 한다 — 작은 수정이 아니다 | R11 §5 넘김 — R2a 이번 계획들의 범위 밖, R2a 남은 리뷰 엔진 · qg 소결함(R12) 끝냄 — 0298af36 · 4f50a950(R12 계획 2 — 면제 줄번호 핀은 #242 가 줄번호 없는 키로 바꿔 할 일이 없다) | R12 |
| qg 판정에 쓰는 상태(세션 폴더 · 표지 · synth.out)가 리뷰 대상 레포 안에 있어, 판정 전에 도는 레포 코드(e2e 부팅 · CLI 걷기 · 차등 테스트)가 그것을 지우거나 바꿀 수 있다 — 상태 위치(레포 밖) · 턴 문맥 운반 · 순서 바꾸기 중 설계 결정 필요(CLAUDE.md 상태 위치 규칙에 걸림, 사용자 결정 대상). 추적 안 되는 중첩 레포 리뷰는 그 결정 뒤에. $RV/synth.out 처럼 레포 밖 임시 폴더라도 같은 사용자로 도는 레포 코드(e2e 걷기)가 판정 전에 닿을 수 있다 — 위치만으로는 지키지 못한다(턴 문맥 운반 · 해시 확인 후보) | R2a 계획 3 보안 재리뷰(CRITICAL) — 이 PR 범위 밖 설계 결정 끝냄 — 31a18dcc · 99df083d(판정은 기계가 낸 줄로만) · 3d7a131d(중첩 레포는 리뷰하지 않고 막는다, R12 설계 U11) | R12 |
| qg e2e 시나리오 수 상한(§1 처분표의 「qg e2e 시나리오 수 상한」 행 — 이 계획에서 미구현): 「시나리오를 1~3개 만든다」 · 「선택지는 넷을 넘지 않는다」 — 넷째 시나리오부터 만들지 않는다는 사실이 공시되지 않고 사용자가 그 자리에서 더 열 수 없다 | 계획 3 이 구현 중 찾은 새 장치 — 이 계획 범위 밖 (R2a 끝 — 지휘자 판정 2026-10-20) 끝냄 — 90449ca0 · 6a6bb759(R12 계획 2) | R12 |

## Metadata

- 에픽: R2a · 브랜치 `feature/shared-review-engine-devices`(계획 1). 계획 2~4 의 브랜치는 계획이 정해 로드맵 PR 로 블록에 더한다(§10).
- 설계: 지휘 세션이 직접 brainstorming(2026-10-17), spec 승인까지만 — 계획 · 구현은 백그라운드 agent.
- 맥락: 설계 대화의 사용자 결정은 `## 결정 기록` 에 전부 있다(레포 밖 메모에 기대지 않는다).

### Deferred to plan

| # | 항목 |
|---|---|
| 6e3a3bff#r1.1 | 참고(component_relations) #2-계획-1--결함-셋--테스트-실행-공유본--qg-진입-이름 — 테스트 실행 공유본의 형제 `resolve-baseline.sh` 가 공유 묶음으로 옮겨질지 qg 에 남을지를 '측정이 정한다'로 열어 두었다. 그런데 계획 3 은 범위 모드 때문에 바로 그 파일을 qg 파일로 고치고, 온톨로지는 그 주인을 qg 로 적는다. 주인이 두 갈래로 읽힌다. — 고치면: 측정은 이미 끝났다(형제는 resolve-baseline.sh). 설계에서 주인을 정한다. (a) resolve-baseline.sh 도 shared/test-selection/ 으로 옮기고 계획 3 의 범위 기준 변경을 공유본 변경으로 다루며, R5 소비자 스위트까지 잰다. 또는 (b) qg 에 두고 다른 소비 플러그인이 qg 쪽 파일을 링크하게 하되, 범위 모드가 추가하는 인자가 공유 소비자에게 닿지 않는 경계를 적는다. |
| a9ec064b#r1.1 | 참고(feasibility) #2-계획-1--결함-셋--테스트-실행-공유본--qg-진입-이름 — 설계는 qg 의 인자 확인과 '없어진 인자 안내'를 진입 사전 검사(`!` 줄)에 맡긴다. 그러나 호출 표면 락은 그 줄을 인자 없는 고정 모양으로 강제하고, 사용자 인자 토큰이 들어가면 RED 로 만든다. 그래서 그 자리에서는 인자를 볼 수 없다. — 고치면: 사전 검사 줄은 락이 정한 모양(entry_preflight.py quality-gates quality-pipeline)만 갖는다. 인자 확인과 없어진 인자 안내는 skill 본문의 첫 단계(setup-qg.sh 호출)에 남긴다. §2·AC6 의 귀속을 그렇게 고치고 setup-qg.sh 를 계획 1 의 Files to Modify 에 더한다. |
| fa444e32#r1.1 | 참고(data_flow) #4-계획-3--qg-장치--범위-입력--persona — 범위의 시작 커밋만 차등 테스트에 연결되고 끝 커밋의 소비 규칙은 빠져 있다. 현재 테스트 절차는 작업트리를 봉인해 실행하고, 설계문서 탐색은 HEAD까지의 커밋과 HEAD의 파일을 읽는다. 끝 커밋이 현재 체크아웃과 다르면 리뷰할 변경과 검증할 코드·의도가 달라진다. — 고치면: 범위 진입 시 시작과 끝을 커밋으로 확정하고, diff·테스트 후보·차등 테스트 대상 트리·설계문서 탐색이 같은 두 커밋을 사용한다. 설계문서 내용도 확정한 끝 커밋에서 읽는다. 수정 루프로 대상이 바뀌면 새 끝 커밋을 공시하고 모든 소비자가 함께 전환한다. 현재 체크아웃과 끝 커밋이 다른 경우에도 이 일치가 유지되는 것을 통과 조건으로 추가한다. |
| c7ea8a5f#r1.1 | 참고(ambiguity) #4-계획-3--qg-장치--범위-입력--persona — 문서 제외 패턴과 모델 행동을 정하는 파일의 포함 규칙이 겹칠 때 우선순위가 없다. 예를 들어 docs 아래의 AGENTS.md나 모델용 템플릿은 기본 제외 패턴에도, 반드시 리뷰한다는 파일 종류에도 해당한다. — 고치면: 모델 행동을 정하는 파일의 포함 규칙을 문서 제외 패턴보다 먼저 적용한다. 해당 파일은 docs 아래에 있거나 제외 패턴과 겹쳐도 리뷰하며, 나머지 파일에만 문서 제외 설정을 적용한다. 포함·제외 규칙이 겹치는 파일이 리뷰에 남는 것을 통과 조건으로 명시한다. |
| 0b618227#r1.2 | 참고(testing) #acceptance-criteria — AC13 의 '라벨 규약 문단에 손잡이 문장이 있다'는 지금 문서에서도 이미 참이라 아무것도 재지 않는다. shared/docreview/references/reviewing-document.md 43행에 '라벨은 그 줄을 가리키는 손잡이다'가 이미 있다. 정작 설계가 바꾸려는 '전문이 질문 바로 위에 늘 보인다'는 관측 기준이 없다. |
| ef7faff6#r2.1 | 참고(ambiguity) #1-장치-처분표 — 처분표 머리말의 「안전장치를 지키던 행만 수정으로 남는다」가 표와 어긋납니다. 표에서는 화면 범람 · 질문 피로 · 문서 잡음 · 선택지 범람처럼 안전장치가 아닌 것을 지키던 행도 수정으로 남아 있습니다. 머리말을 확정 기준 문구(비용만 지키던 것은 제거, 상한 · 압축 · 사용자 결정 자리는 공시하고 사용자가 여는 수정)로 바꿉니다. |
| 769966da#r2.1 | 참고(ambiguity) #3-계획-2--공유-엔진--r2-보안-잔여 — 탐지 리뷰어 수 N 의 결정 순서와 전달 길이 비어 있습니다. 프로필과 진입 선언 중 무엇이 우선하는지가 적혀 있지 않고, 환경 변수로 N 이 정해질 때 진입 skill 이 그 값을 어디서 읽어 N 명을 부르는지(엔진이 해석한 N 을 내보내는 곳)도 없습니다. 「기본 < 프로필 < 진입 < 환경」 같은 순서와 엔진이 정한 N 을 진입에 넘기는 출력을 적습니다. |
| 640db5fa#r2.1 | 참고(ambiguity) #9-위험에-대한-답 — 위험에 대한 답 절이 아직 「동작 대조(원장 요약값)로 바꾼다」를 꼴 막기 재발의 해법으로 듭니다. 지금 설계에서 요약값은 우발적 손상 감지일 뿐이고 엔진 밖 쓰기는 권한 경계가 막으므로, 해법을 「권한 경계」로 바꿉니다. |
| 124a1857#r2.1 | 참고(ambiguity) #rejected-alternatives — 기각안 「상한 값을 없앰」은 상한 일반을 없애는 것을 기각한 것으로 읽힙니다. 그런데 처분표는 qg 리뷰어 최대 8 과 plugin-audit 심층검증 8건 상한을 «제거»합니다. 이 기각안이 루프 상한(qg 수정 루프 5회 · 엔진 재리뷰 2회)만 가리킨다는 점을 문면에 밝혀야 두 결정이 어긋나 보이지 않습니다. — 고치면: 「루프 상한(qg 수정 루프 5회 · 엔진 재리뷰 2회)을 없앰 — 루프 상한은 안전장치다(P18). 공시와 사용자가 여는 길로 고친다. 비용만 지키던 상한(리뷰어 수 · 심층검증 건수)은 §1 에서 제거한다.」 |
| fccf272b#r2.1 | 참고(ambiguity) #acceptance-criteria — AC16 의 「AC8 락」은 다른 문서의 AC 번호로, `test_ledger_wiring.sh` 안의 원장 쓰기 락을 가리킵니다. 그런데 이 문서에도 AC8(호출 표면 락)이 따로 있어서, 읽는 사람은 이 문서의 AC8 로 받아들일 수 있습니다. — 고치면: AC16 의 「AC8 락」을 「`test_ledger_wiring.sh` 의 원장 쓰기 락(그 테스트의 AC8)」으로 바꿉니다. |
| 5c83a7eb#r3.1 | 참고(ambiguity) #5-계획-4--project-init--plugin-audit — 계획 4 본문이 아직 plugin-audit 의 「심층검증 상한을 늘린다(기본 6축 · 8건)」라고 쓴다. 처분표와 수용 기준 AC35 는 6축 고정과 8건 상한을 없애기로 했다. 계획 작성자가 이 절을 따르면 기본값과 상한이 남는다. — 고치면: 계획 4 본문과 번호 대조 표를 고쳐 축 고정과 심층검증 상한은 제거하고, 지출 동의 게이트에서 사용할 축·검증 수와 규모를 알린다고 통일한다. |
| 63cb0475#r4.1 | 참고(feasibility) #7-상류--하류-연계 — 문서 비평 진입을 공유 리뷰 원장의 실제 소비자로 잘못 서술했습니다. 현재 critiquing-artifacts/SKILL.md는 자체 비평·수정 루프와 synthesize_artifact_findings.py를 사용하며 공유 원장을 호출하지 않습니다. 설계에도 이를 연결하는 변경은 없습니다. — 고치면: 공유 리뷰 원장의 실제 소비자는 spec-distill 진입 셋이라고 정정한다. qg는 공유 엔진 파일과 프로필을 배포하지만 문서 비평은 별도 루프로 실행한다고 밝히고, 공유 엔진 검증과 문서 비평 동작 검증을 구분한다. Context의 네 진입 공동 사용 설명도 함께 고친다. |
| 4175608a#r4.1 | 참고(ambiguity) #2-계획-1--결함-셋--테스트-실행-공유본--qg-진입-이름 — 옛 이름을 지운다는 수용 기준이 「역사 기록」은 빼고 잰다고 하면서 역사 기록이 어느 파일인지 정하지 않았다. 계획 1 본문은 같은 docs 폴더에 있는 R5 설계의 이름은 고친다고 하므로, 어디까지 고쳐야 통과인지가 두 가지로 읽힌다. |
| 13c64420#r4.1 | 참고(handoff_incomplete) #3-계획-2--공유-엔진--r2-보안-잔여 — 계획 2 앞의 경로 예약 PR 이 보안 잔여 스크립트만 더한다고 적었지만, 계획 2 는 예약 밖 파일을 더 고친다. spec-distill 진입 skill 펜스, 프로필, roadmap_model.py, test_ledger_wiring.sh, pyproject.toml, uv.lock 이 그렇고, 계획 1 의 shared/entry·shared/tests 도 예약 밖이다. 그중 request-framing·reviewing-brief SKILL 은 지금 병렬로 도는 R10 이 예약해 둔 파일인데, 연계 절에 그 겹침이 적혀 있지 않다. |
| 11ed67a1#r5.1 | 참고(overdesign) #4-계획-3--qg-장치--범위-입력--persona — yagni: 범위 모드의 선택 인자 `..<끝>` 은 부르는 곳이 없다 — 묶음이 요구한 것은 시작 커밋부터 지금 기본 브랜치까지이고, R5 와의 계약도 시작 커밋만 넘긴다. — 고치면: `range <시작>` 하나만 두고 끝은 늘 기본 브랜치(`origin/HEAD` 에서 해석)로 한다. AC21 에서 `[..<끝>]` 을 뺀다. └ 천장: 과거의 두 커밋 사이를 리뷰해야 하는 소비자가 생기면(예: R5 가 로드맵 중간 지점까지만 검사) 그때 `..<끝>` 을 더한다. |
| 17563e51#r5.1 | 참고(ambiguity) #번호-대조 — 번호 대조 표의 C5 행이 재결정 이전 내용 그대로다. 비용 상한을 「기본값 + 사용자가 여는 길」로 고친다고 적혀 있고, 비용 장치가 아닌 「질문 ≤4」까지 같은 묶음에 들어 있다. — 고치면: 번호 대조와 plugin-audit 설계 절을 비용 상한은 제거하고 시작 구성과 실행 규모만 공시한다는 설명으로 통일한다. 질문 수는 처분표에 적힌 질문 피로 방지용 기본값으로 구분한다. |
| 90b57878#r7.1 | 참고(isolation) #3-계획-2--공유-엔진--r2-보안-잔여 — 탐지 리뷰어가 여럿이면 각자 c1·c2… 를 처음부터 매기므로 ref 가 서로 겹친다. 그런데 지금 라우터는 ref 를 「출처 critic + ref」로만 구분한다. 설계에 ref 를 리뷰어마다 따로 구분한다는 말이 없어서, 한 리뷰어의 ask 가 다른 리뷰어의 항목을 막는 것으로 잘못 이어질 수 있다. 또 「출처 리뷰어를 단다」가 재비판에게 보이는 지적에도 실리는지가 정해지지 않았다. 실린다면 지금의 익명화(출처 순서를 복원 못 하게 정렬)와 부딪친다. |
| 985b28d0#r8.1 | 참고(data_flow) #3-계획-2--공유-엔진--r2-보안-잔여 — 탐지 리뷰어 수 N 을 어디서 최종으로 정하고 진입 skill 과 라우터에 어떻게 전하는지가 비어 있다. 프로필 선언과 진입 선언 중 어느 쪽이 이기는지도 적혀 있지 않다. 라우터가 'N 중 k 사망'을 세려면 기대 수 N 이 있어야 하는데, 그 값을 만드는 쪽이 정해져 있지 않다. |
| d83a790c#r8.1 | 참고(feasibility) #4-계획-3--qg-장치--범위-입력--persona — 문서 경로 정의를 'Step 1 의 FILTERED_DIFF 를 만드는 한 자리(:217)'에서 읽는다고 했는데, 실제 :217 은 토픽 범위일 때만 지나가는 문장이다. session·branch·paths 범위와 새 range 범위에는 FILTERED_DIFF 를 만드는 자리가 따로 정해져 있지 않다. |
| e1b5b3be#r8.1 | 참고(handoff_incomplete) #handoff-context — Handoff Context 가 범위 입력으로 flexibility-audit.md 와 'R5 설계문서 ## 미룸'을 경로 없이 이름만 든다. 대화를 압축한 뒤 이 문서만 읽고 이어 가는 사람은 그 파일을 찾을 수 없다. |
| 5bc589cd#r10.1 | 참고(overdesign) #3-계획-2--공유-엔진--r2-보안-잔여 — yagni: 탐지 리뷰어 수를 선언하는 자리가 프로필과 진입 둘인데, 프로필의 주인이 바로 그 진입 플러그인이라 같은 값을 정하는 통로가 둘이다. 둘 사이의 우선순위도 정해져 있지 않다. — 고치면: 프로필의 `detectors` 와 환경 변수 `DEVBREW_DOCREVIEW_DETECTORS` 둘만 둔다. 출처는 기본 · 프로필 · 환경 셋이고 환경이 이긴다. AC10 의 출처 목록도 이에 맞춘다. └ 천장: 한 프로필을 둘 이상의 진입이 함께 쓰고 진입마다 다른 N 이 필요해지면 그때 진입 선언을 더한다. |

## 판정

### docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md

- Ruling: Task 0 reused — baseline captured on 7d716d66 (before.tsv 297 rows · before.names 2 lines: 1 real RED test_hook_output_schema.py::test_python_and_bash_resolvers_agree, 1 false match in test_assert_behavior.sh ✓ line containing ✗) · blobs-before.tsv 4 hashes · surface-before.md. 6b621940 changes only the plan doc, so the tree under test is identical — origin default branch has not moved since — cost if wrong: a pre-existing RED introduced between 7d716d66 and 6b621940 would show as "new"; impossible since 6b621940 touches only docs/superpowers/plans.
- Ruling: R1 — plugin.json/CHANGELOG get concrete provisional numbers derived from current versions (qg 13.0.3 → 14.0.0 major; spec-distill 7.1.0 → 7.1.1; plugin-audit 1.1.2 → 1.1.3; project-init 5.0.2 → 5.0.3, each only if touched), and the hand-off says "번호는 머지 직전에 다시 확인" instead of writing the literal `<머지 때>` — a non-semver string breaks plugin.json and the CHANGELOG/version locks (AC36 new-RED), and the previous epic (#222, 7.1.0) also landed concrete numbers — cost if wrong: the conductor renumbers at merge (one commit), same as with a placeholder.
- Ruling: R2 — keep the plan's AC3 byte check in test_test_selection_bundle.sh reading the mirror blobs file with the `ok` fallback, as written — AC3 evidence on this machine is real; the fallback message discloses it is skipped elsewhere — cost if wrong: on other machines the byte assertion is vacuous (disclosed), the mode/link/behaviour assertions still bite.
- Ruling: R3 — expect_red calls added by T5/T6 must pass a real reason substring as 4th arg (e.g. "commands/" for H, "옛" for I) — 3-arg calls make `grep -qF ""` match any RED row of that axis, a weaker lock than intended — cost if wrong: none beyond a slightly more specific assertion. T5 also fixes the existing `variant g5` (`/quality-gates:qg` resolved via commands/qg.md) to the new reality, as plan Step 5 says leftover rows are fixed in the task.
- Ruling: R4 — Task 3 Step 6 item 2 (CLAUDE_CONFIG_DIR isolated marketplace install) is best-effort with a bounded attempt; if it needs interactive login or network the implementer records "미측정 — 이유" in install-measure.md and the `cp -RL` dereferenced-copy case in the bundle test stands in as the cache-copy proxy; AC5's pass criterion is the `--plugin-dir`/source-tree path — cost if wrong: the real cache-copy path stays unmeasured until the conductor's implementation check (disclosed in hand-off).
- Ruling: R5 — Task 8 Step 2 (interactive call of the two entry names) is a human step; left as an unverified item for the PR body — the plan says so explicitly — cost if wrong: none.
- Ruling: R6 — commit Co-Authored-By names the model that actually authored the commit (Task 2 fede2654 carries 'Claude Haiku 5.5'); rules.md updated to defer to each subagent's own attribution reminder — accurate attribution beats a uniform string, and amend is forbidden anyway — cost if wrong: cosmetic trailer difference on some commits.
- Ruling: R7 — Task 2 README wording: replace the plan's '시작 줄의 리뷰어 구성 공시로 subagent spray를 드러낸다' with wording that describes the mechanism that exists today (the per-iteration reviewer roster line printed after dispatch, quality-pipeline/SKILL.md ~:299-302), and add a README positive assertion — spec §2/AC2 says '지운 게이트 인용을 지금 장치로 바꾼다' (the current mechanism), and citing a not-yet-built line repeats the defect AC2 removes; plan 3 (AC24) rewrites this line again — cost if wrong: one README line reworded twice.
- Ruling: R8 — keep the consumer rule at shared/test-selection/README.md (AC4 names that file) and fix test_copy_of_contract's canonical-basename derivation to exclude README.md under shared/ subfolders, with a positive pair that a real shared/<dir>/<name> canonical still derives — moving the rule into shared/README.md would contradict AC4's literal path — cost if wrong: one lock edit to revisit; lock edit gets re-review.
- Ruling: R9 — artifact-critique entry 'ok' row says only to proceed (no project_dir assignment); E2 stays the single owner of project_dir — two definitions of the frozen coordinate would diverge when the session starts in a subdirectory; the invocation lock only fixes the row's first cell — cost if wrong: none functional (roadmap-status-style wording dropped).
- Ruling: R10 — the guards-coverage RED from Task 2/3 tests is a confirmed real gap; it enters Task 5's fix loop (same implementer already diagnosed it) rather than reopening completed tasks — one fix dispatch, reviewed in Task 5's re-review — cost if wrong: Task 5's diff carries a fix belonging to Task 2/3 files (traceable in commit message).
- Ruling: R11 — critique notice handled position-independently inside setup-qg.sh's argument loop (before any write), tests exercise the real P2 shape '--ensure critique …' plus the direct form — AC6 requires the notice on the real call path; the plan's '$1 at :10' assumption predates removing the qg.md call — cost if wrong: none (strictly broader).
- Ruling: R12 — baseline recaptured on the new base c674e191 in a throwaway clone (/tmp/r2a-base.gFFpAZ/repo, refs aligned: origin/main=origin/HEAD=c674e191, same feature branch name) → sdd-mirror before2.{tsv,names}; final AC36 comparison uses before2 (the merged-in base), not the 7d716d66 baseline — origin moved, and the conductor asked for recapture by failure names — cost if wrong: clone-vs-worktree environment differences could create spurious name diffs (each diff is inspected by hand).
- Ruling: R13 — AC3 vs AC7 tension: the sweep changed one comment in shared/test-selection/resolve-baseline.sh ('/qg iter-7' → 'qg iter-7'), so HEAD blob ≠ pre-move blob. Accept: AC3's byte-identity is evidenced at the move commit (e08e6c77, the four blobs equal blobs-before.tsv) and the bundle test now checks the blob at the commit that added each shared file; the later comment-only edit is required by AC7 (shared/ is a live surface and the lock now flags '/qg '). Both ACs keep their intent (the move altered no bytes; no live old name). — cost if wrong: if the user reads AC3 as 'HEAD bytes equal pre-move forever', the comment edit must be reverted and the lock given a per-line exemption; disclosed in hand-off.
- Ruling: R14 — reopen Task 6 for one fix round (resume its implementer) to rewrite the i_ol negative-control literal so it no longer names the removed '/qg-publish' alias while keeping the control's teeth (mutation) — real new RED vs baseline (AC36) — cost if wrong: none.
- Ruling: R15 — one final fix dispatch covering F1, F2 (a sentence before P2 in quality-pipeline SKILL: a non-code document-critique intent prints the pointer line and stops — spec §2 says so; not an AC change), plus five cheap minors (broken block first; relabel; README:399; git-derived byte check replacing the machine-local mirror dependency of R2; plain-language advisory with internal names in parentheses). AC36 re-measured with an extra runner covering subfolder tests and tools/ on both the base clone and HEAD — cost if wrong: a few more lines touched after review (covered by the scoped re-review).
- Final: minor (parked, residual): P1b-before-P2 order not locked in test_qg_critique_routing.sh (slice still passes if moved after P2) — Ruling: park — order is visible in the SKILL and no later task depends on it; cheap follow-up (line-number comparison)
- Final: minor (parked, residual): M1 broken-first case alone can't distinguish first-block-only; case_same_name_blocks_disclosed covers that — Ruling: park — already covered by another case
- Ruling: R16 — keep this plan's SDD workspace (not rm -rf) after the clean final review — the conductor's instructions require the AC report to stay as an untracked file in the workspace for the implementation check; everything is also mirrored in ~/.claude/sdd-mirror/r2a-plan1/ — cost if wrong: one git-ignored folder left to delete later.

## 구현 대조 — docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md

- 구현 대조: 경고 없음 (AC 11개 · 구현됨 11개 · 미룸 0개 · --acs 로 고른 것 · 뺀 AC 26개) (받는 곳 규칙: 로드맵의 에픽 또는 PR 번호(#숫자))
- 보고: AC 11개 중 구현됨 11 · 미룸 0 · 빠짐 0
