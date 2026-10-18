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
| 문서 비평 기본 5라운드(RC58) · 대상 하나 · 커밋 강제 · dispatch 수 고정 | `critiquing-artifacts/SKILL.md:72-75, 107-108, 141-151, 258-259, 276` | 루프 · 무결성 | 수정 — 상한에서 사용자가 엶 · 여러 대상 · 「지적만 받기」 읽기 전용 모드(커밋 불필요) · dispatch 수는 기본값 | 3 |
| e2e 시나리오 단일 선택 | `references/e2e.md:34` | 선택지 범람 | 수정 — 여러 선택 | 3 |
| 토픽 선언이면 trivia 우회 불가 | `quality-pipeline/SKILL.md:164-172` | 토픽 일부만 보는 우회 | 수정 — 토픽 diff 전체가 trivia 면 허용, 사유 공시 | 3 |
| 차등 테스트 밖 스위트 실행 금지 | `references/differential-test.md:130` | 판정 오염 | 수정 — 조사용 실행 허용, 「조사용 — 판정에 안 씀」 표시 | 3 |
| project-init 헌장 재질문 3회 뒤 중단(RC53) | `project-init/SKILL.md:160-164` | 빈 헌장 | 제거 — 기계가 정하던 중단을 없애고, 3회 뒤 「건너뛰기 · 계속 묻기 · 중단」을 사용자가 고름(D7.17) | 4 |
| project-init AGENTS.md 이전 거절 → 전체 중단 | `project-init/SKILL.md:48, 199, 201` | 부분 진행(옛 AC21) | 제거 — 기계가 정하던 전체 중단을 없애고, 「CLAUDE.md 에 바로 쓰기」 선택지, 관련 없는 git-workflow 생성은 계속(D7.17) | 4 |
| project-init 질문 ≤4 · 관례 1–3개 | `project-init/SKILL.md:147, 156` | 질문 피로 | 수정 — 기본값, 더 받을 수 있게 | 4 |
| project-init 헌장 단계 직렬 순서(Step 3 이 끝난 뒤에만 시작, 교차 금지) | `project-init/SKILL.md:119` | 질문이 섞여 답이 엉킴 | 수정 — 질문 순서는 기본 직렬로 두고, 질문이 없는 Phase 0 스캔은 질문과 겹쳐 돌려도 된다(D3.11) | 4 |
| project-init 템플릿 브랜치 접두 고정 · 「ALWAYS 브랜치 확인」 | `templates/*/branch-strategy.md` · `templates/*/agents-md-section.md:5` | 브랜치 규칙 일관 | 수정 — 접두는 고른 전략에서 도출 + 더하기(훅 `post-tool-use.py:138-148` 과 같은 규칙), 확인은 변경 작업일 때만. 규칙이 브랜치 전환만 전제하므로(`templates/github-flow/branch-strategy.md:57-61` 등 전략 셋) 브랜치를 worktree 에서 작업하는 길도 같은 규칙으로 적는다(점검 문서의 「worktree 경로」, D3.11) | 4 |
| plugin-audit 근거 약한 지적을 공시 없이 버림(RC54) | `agents/plugin-auditor.md:56-57, 76-77` | 정밀도 · 취향 지적 | 수정 — 버리지 않고 「열린 질문」으로 보고서에 | 4 |
| plugin-audit 반박자 「불확실하면 기각」 | `agents/audit-refuter.md:22-23` | 거짓 양성 증폭 | 수정 — 부록에서 기각과 「불확실」을 나눠 표시 | 4 |
| plugin-audit 6축 고정 · 심층검증 8건 상한 | `scripts/audit-workflow.js:295, 498, 646-650` | fan-out 비용 | 제거 — 축 고정 · 8건 상한을 없앤다. 지출 동의 게이트(유지)에서 쓸 축과 검증 수, 그 규모를 알린다 | 4 |
| plugin-audit 코퍼스에서 펜스 · placeholder 제외 | `scripts/audit-workflow.js:239` | 잡음 | 수정 — 뺀 수를 보고서에 공시 | 4 |

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
2. **공유 엔진 · R2 보안 잔여** — 시작 전에 로드맵 PR(경로 예약)과 R5 계획 1 머지 merge. AC10~AC20.
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
- AC7 `critiquing-artifacts` 가 `artifact-critique` 로 개명돼(디렉토리 = `name`) `/quality-gates:artifact-critique <경로>` 로 불리고, 레포에 옛 이름 `reviewing-spec` · `/qg critique` · `critiquing-artifacts` 를 부르는 곳이 없다(역사 기록 · CHANGELOG 제외).
- AC8 호출 표면 락에 qg 예외가 없고 qg 가 GREEN 이며, `commands/qg.md` 를 되살리는 변이에서 RED 다.
- AC9 qg `plugin.json` 이 major bump 되고 CHANGELOG 에 `Removed`(`/qg` · `/qg critique`) · `Changed`(진입 이름) 와 README 갱신이 있다.

계획 2
- AC10 프로필이 `detectors: N`(N ≥ 1)을 받고, 진입이 N 명을 dispatch 하면 라우터가 `--critic` 여러 개를 파일마다 신선도 판별해 합친다. 지적마다 출처 리뷰어가 있고 겹침은 흡수로 센다. 사용자가 `DEVBREW_DOCREVIEW_DETECTORS` 로 N 을 열 수 있고, 이 값이 프로필 · 진입 선언보다 우선한다. 쓰인 수와 출처(기본 · 프로필 · 진입 · 환경)가 라운드 머리 줄에 공시된다(D2.5).
- AC11 탐지 N 중 일부가 재dispatch 뒤에도 죽으면 「탐지 N 중 k 사망」이 degrade 로 공시되고 남은 결과로 간다. 전부 죽으면 「미검증」이다.
- AC12 `rereview_cap` · `render_cap` · `summary_width` 를 프로필 필드와 환경 변수로 바꿀 수 있고(환경이 이긴다) 쓰인 값과 출처가 공시된다. 기본값은 2 · 8 · 60 이다. 접힌 조언 줄은 전문이 있는 곳을 적는다(D6.15).
- AC13 상한 · 정체로 열린 승인 게이트의 첫 줄에 열린 지적 수가, 승인 선택지 이름에 「열린 지적 N개를 두고」가 있다. 라벨 규약 문단에 손잡이 문장이 있다.
- AC14 얼림 검사가 payload §6 끝에 덧붙인 줄만이면 통과하고 이미 있는 줄이 바뀌면 `frozen_change` 다. `docreview_state.py` 인자 파서가 줄인 플래그를 거부한다.
- AC15 `_log_line` 이 쓴 결정 줄은 요약에 줄바꿈 · CR · 제어 문자 · 유니코드 줄 구분자가 있어도 정확히 한 줄이고, 그 줄로 brief `## 6` 의 사용자 문구 줄을 만들 수 없다.
- AC16 `docreview_state.py advice-list` 는 쓰기 플래그가 없는 읽기 전용 하위 명령이고, skill 펜스는 그 결과를 넘기기 없이 받는다. `test_ledger_wiring.sh` 의 원장 쓰기 락(그 테스트의 AC8)은 하위 명령 이름으로만 재며 mktemp · 재대입 · 갈래 파싱 코드가 없고, R2 의 잔여 다섯 꼴이 각각 RED(또는 원인 소거로 해당 없음)다. 다섯째 꼴(엔진 밖 원장 쓰기)은 AC17 (가)로 닫힌다(D2.9).
- AC17 (가) 엔진이 아닌 명령이 원장을 쓰려 하면, frontmatter 상태와 요약값을 함께 바꾸는 시도까지 권한 경계에서 거부된다. 경계를 마련하지 못했으면 이 축을 닫았다고 쓰지 않고, `## 미룸` 에 이유와 받는 곳을 적는다. (나) 요약값이 엔진이 쓴 것과 다르면 `LedgerCorrupt`(「원장이 엔진이 쓴 것과 다르다」)로 멈추고 원장 경로와 복구 길 둘을 낸다. 요약값이 없는 기존 원장은 다음 저장 때 채우고 그 라운드 머리 줄에 한 번 공시한다(D2.9).
- AC18 `check_brief` 와 `check_verbatim_coverage` 가 같은 판독기 모듈을 쓰고, 열 0 · 유니코드 공백 앵커 · 번호 목록 · 인용 꼴 결정 줄 · §3 산문 속 `⟨S<n>⟩` 이 각각 잡힌다. `check_verbatim_coverage` rc 3 이면 게이트가 막히고 「검사 없이 계속」 선택이 audit 에 남는다.
- AC19 markdown-it-py 가 `uv.lock` 의 개발 의존으로 고정되고, 교차 확인 테스트가 우회 사례 전부와 레포의 실제 brief · seed 에서 문법 판정과 파서 토큰이 같음을 잰다. 파서가 없으면 그 테스트는 「확인 못 함」을 내고 rc ≠ 0 이다.
- AC20 R2 「알려진 우회」 나머지마다 재현 · 닫음 · 변이 결과 표가 PR 에 있고, 닫지 못한 것은 이유와 받는 곳이 `## 미룸` 에 있다. 보안 리뷰어 결과가 PR 본문에 있다.

계획 3
- AC21 `range <시작>[..<끝>]` 모드가 있고, 끝 생략 시 `origin/HEAD` 를 쓰며, diff 기준과 차등 테스트 기준선이 `<시작>` 이고 PR 코멘트를 게시하지 않았다고 공시한다.
- AC22 `discover-spec.sh` 가 범위 안 `Spec:` 트레일러를 전부 모아 `specs` 목록을 내고(트레일러마다 경로 검사 · 중복 제거 · 커밋 순서), 의도 줄이 「설계문서 N개」다. 트레일러 하나면 지금과 같은 결과다.
- AC23 문서 경로 정의가 한 곳(`quality-pipeline/SKILL.md` Step 1 의 `FILTERED_DIFF`)에 있다. 기본 목록은 `README*` · `CHANGELOG*` 이고 `docs/` 아래 문서는 기본으로 리뷰에 들어간다. `DEVBREW_QUALITY_GATES_DOC_PATHS` 로 목록을 바꿀 수 있다(값이 있으면 기본 목록을 대신하고, 빈 값이면 아무것도 빼지 않는다). 리뷰 범위 안의 변경이 그 키를 바꾸면 그 iteration 은 기본 목록으로 돌아가고 그 사실이 공시된다. 쓰인 목록 · 출처 · 뺀 경로 수가 공시되고, 걸러진 diff 가 비면 not-certified 다. skill · agent · reference · 템플릿 `.md` 는 리뷰에 들어간다(D6.16).
- AC24 quality-pipeline 문면에 리뷰어 상한(최대 8)과 같은 반복에서 같은 리뷰어를 다시 부르지 말라는 금지가 없다. 구성표는 시작 구성이고, 모델이 근거를 적어 더한 리뷰어와 다시 부른 리뷰어(일시 실패 재시도 · 분할 병렬)가 시작 줄 규모 공시에 따로 센다(D2.6).
- AC25 수정 루프가 상한 5 에 닿으면 사용자가 자기 문구로 1회씩 더 열 수 있고 그 문구가 기록된다. 열지 않으면 지금의 Max-iter 결정으로 간다.
- AC26 재비판이 낮춘 지적이 보고서 「낮춘 지적」 절에 이유와 함께 있고 게이트에서 여러 개를 되올릴 수 있다.
- AC27 qg agent 에 `model:` 고정이 없고, `security-reviewer` 의 범위 문장과 `quality-pipeline/SKILL.md` 의 「바뀐 코드만」 문장이 둘 다 「원인이 이 변경이면 보고」다(D6.15). persona diff 의 보안 리뷰 결과가 PR 본문 「보안 리뷰」 절에 있다.
- AC28 e2e 시나리오 선택이 multiSelect 이고, 토픽 diff 전체가 trivia 면 우회가 사유와 함께 허용되며, 조사용 스위트 실행이 「조사용 — 판정에 안 씀」으로 표시된다.
- AC29 artifact-critique 가 여러 대상과 「지적만 받기」 읽기 전용 모드(커밋 없음)를 받고, 라운드 상한에서 사용자가 연다. dispatch 수는 기본값이고 바꿀 수 있다(D6.15).
- AC30 범위 모드를 설계문서 둘 이상인 버릴 레포에서 실제 명령으로 걸은 기록이 있다.

계획 4
- AC31 project-init 헌장 재질문 3회 뒤 「건너뛰기 · 계속 묻기 · 중단」 선택이 있고, 건너뛰면 미완 항목을 공시한다. 질문 수와 관례 개수는 기본값이고 더 받을 수 있다. 질문 순서는 기본 직렬이지만 질문이 없는 Phase 0 스캔은 질문과 겹쳐 돌 수 있다(D6.15).
- AC32 AGENTS.md 이전 거절 때 「CLAUDE.md 에 바로 쓰기」 선택지가 있고 git-workflow 파일 생성이 계속된다. CHANGELOG 가 옛 AC21 변경을 적는다.
- AC33 템플릿의 브랜치 접두가 고른 전략에서 도출되고 사용자가 접두를 더할 수 있으며 훅과 같은 규칙이다. 「ALWAYS 브랜치 확인」은 변경 작업일 때만이다. 템플릿 브랜치 규칙이 worktree 에서 작업하는 길도 같은 규칙으로 적는다(D6.15).
- AC34 plugin-auditor 가 근거 약한 지적을 「열린 질문」으로 내고, 반박자의 불확실이 부록에 따로 표시되며, 코퍼스에서 뺀 수가 공시된다. plugin-audit persona diff(`agents/plugin-auditor.md` · `agents/audit-refuter.md`)의 보안 리뷰(qg 보안 리뷰어, 웹 도구 없음) 결과가 판단 근거와 함께 PR 본문 「보안 리뷰」 절에 있다(D2.7).
- AC35 plugin-audit 에 6축 고정과 심층검증 8건 상한이 없고, 지출 동의 게이트가 쓸 축 · 검증 수와 그 규모를 알린다(D2.6).

공통
- AC36 계획마다 건드린 플러그인 전부와 shared 의 스위트를 기준선과 실패 «이름»으로 대조해 새 실패가 0 이다(선재 RED 는 이름 집합으로 비교).
- AC37 §1 처분표의 모든 행이 어느 AC 로 닫히고, 구현 중 새로 찾은 장치는 §1 에 행으로 더해졌거나 재분해로 넘겨졌다.

## Files to Modify

- 계획 1: `shared/docreview/scripts/docreview_route.py` · `shared/test-selection/`(새: 스크립트 셋 + 형제 · README) · `plugins/quality-gates/scripts/`(링크) · `plugins/quality-gates/commands/qg.md`(삭제) · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/skills/critiquing-artifacts/` → `skills/artifact-critique/` · `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/references/differential-test.md` · `plugins/quality-gates/README.md` · `CHANGELOG.md` · `plugin.json` · qg 테스트 · `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` · `shared/tests/test_inline_python_isolated.sh` · `/qg` 를 부르는 문서들.
- 계획 2: `shared/docreview/scripts/docreview_state.py` · `docreview_route.py` · `docreview_advice.py` · `shared/docreview/references/reviewing-document.md` · 진입 skill 셋의 펜스(`advice-list`) · 프로필 넷 · `plugins/spec-distill/scripts/brief_body.py`(새) · `check_brief.py` · `check_verbatim_coverage.py` · `seed_body.py` · `check_seed.py` · `seed_review_log.py` · `seed_provenance.py` · `plugins/spec-distill/scripts/roadmap_model.py`(`brief_universe`) · `plugins/spec-distill/tests/test_ledger_wiring.sh` · 값 락 테스트 · `shared/tests/fixtures/docreview/` · `pyproject.toml` · `uv.lock` · spec-distill `CHANGELOG.md` · `plugin.json`.
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

## Metadata

- 에픽: R2a · 브랜치 `feature/shared-review-engine-devices`(계획 1). 계획 2~4 의 브랜치는 계획이 정해 로드맵 PR 로 블록에 더한다(§10).
- 설계: 지휘 세션이 직접 brainstorming(2026-10-17), spec 승인까지만 — 계획 · 구현은 백그라운드 agent.
- 맥락: 설계 대화의 사용자 결정은 `## 결정 기록` 에 전부 있다(레포 밖 메모에 기대지 않는다).
