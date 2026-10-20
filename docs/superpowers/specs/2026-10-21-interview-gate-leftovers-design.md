---
name: interview-gate-leftovers
type: design
created_at: 2026-10-21
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R13.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R13 — R10 남은 인터뷰 게이트 · 엔진 skill 소결함 · Design

> R10 과 R12 가 남긴 인터뷰 게이트 · 엔진 skill 의 작은 결함 일곱을 고친다 — 이미 있는 검사 · 인자 · 옮겨 쓰기 길을 쓰고, 새로 만드는 것은 작은 공용 writer 하나와 `state_path.py` 하위 명령 하나다.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Anti-goals](#anti-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 범위](#1-범위)
  - [§2 사용자 답 대조 — 원문 완전성 검사에 얹기](#2-사용자-답-대조--원문-완전성-검사에-얹기)
  - [§3 링크 따라 쓰기 — 작은 공용 writer 하나](#3-링크-따라-쓰기--작은-공용-writer-하나)
  - [§4 V1 확인 줄 — 「대체됨」 과 같은 길](#4-v1-확인-줄--대체됨-과-같은-길)
  - [§5 원장 뿌리 — 문서의 레포에서](#5-원장-뿌리--문서의-레포에서)
  - [§6 로드맵 생성 따옴표](#6-로드맵-생성-따옴표)
  - [§7 템플릿 · 실행 비트](#7-템플릿--실행-비트)
  - [§8 위험에 대한 답](#8-위험에-대한-답)
  - [§9 계획](#9-계획)
- [있는 것 검토](#있는-것-검토)
- [상류 · 하류 연계](#상류--하류-연계)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [결정 기록](#결정-기록)
- [번호 대조](#번호-대조)
- [원칙 · 입력 대조](#원칙--입력-대조)
- [미룸](#미룸)
- [지휘 기록](#지휘-기록)
- [Metadata](#metadata)

## Context / Why

묶음 R13 의 의도는 「R10 이 남긴 인터뷰 게이트 · 엔진 skill 의 작은 결함과 보안 제안을 pm-interview 이름 바꾸기 뒤 고친다」다. 받는 것은 R10 설계문서(`docs/superpowers/specs/2026-10-19-interview-open-research-design.md`) `## 미룸` 의 받는 곳 R13 행 셋(:401-403)이다. 여기에 R12 설계문서(`docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md`) `## 미룸` 의 R13 행 둘(:450 · :451)과 PR #239 넘김 둘이 더해졌다. 같은 표의 :449 는 68a41ab5 가 이미 고쳐 이 에픽의 일이 아니다. 설계 대화의 덩어리 1 되비춤(일곱 항목)을 사용자가 승인했다(U1). 지휘자는 로드맵 R13 의 범위 · 경로 예약을 그에 맞춘다.

지금 레포에서 확인한 것(origin/main 602931e8, `plugins/spec-distill` = SD):

1. **사용자 답 대조.** 「외부 선례 무관(@S<m>)」 닫힘(`check_brief.py` `IRRELEVANT_RE` :808 · `landscape_irrelevant` :823-835)은 audit §6 의 ☑ 표지만 본다. 그 표지는 모델이 쓴다. 「사용자 판단 포화(@S<m>)」(`SAT_USER_RE` :1518 · `saturation_failures` :1573-1603)는 앵커가 있는지만 보고, 결과는 advisory 다. `check_brief` 는 state 를 읽지 않는다는 불변식을 지킨다(docstring :23-27). state 대조는 `check_verbatim_coverage.py` 가 맡는다 — `run(payload, state, audit)` :281 이 state 를 읽는다. 그런데 `parse_user_statements`(:157-220)는 `id` · `text` 만 남기고 `source` 를 버린다. reviewing-brief 진입 펜스가 이 검사를 `$STATE` 로 부르고(RB = `skills/reviewing-brief/SKILL.md` :222), rc 표(:245)가 이미 있다. state 레코드는 `- id / source: verbatim|chosen / round / text` 꼴이다(pm-interview `SKILL.md` :346-360).
2. **링크 따라 쓰기.** 엔진 skill 셋이 상태 폴더에 셸 넘기기로 쓴다. 넘기기는 미리 심어 둔 심볼릭 · 하드 링크를 따라간다. 자리는 다음과 같다.
   - request-framing(RF): :557-558 번들 둘 · :561 · :630 비우기 · :717 · :861 · :883 · :1229 · :1268
   - reviewing-brief(RB): :295 번들 · :211 · :283 · :369 비우기 · `touch` :62 외 여섯 · `>>` degrade 대체 파일 :115 · :452 · :490
   - spec-review(SR): :395
   - 공유 러너 `shared/docreview/scripts/run_docreview_codex_reviewer.sh`: :50 · :67 · :495-498

   이 러너는 링크로 spec-distill 과 quality-gates 두 플러그인에 함께 실려 나간다. 안전한 자리는 `clear_critic_outputs.sh` 와 `mktemp` 로 만든 임시 파일이다.
3. **V1 확인 줄.** pm-interview `SKILL.md` V1 ⑤(:207-219)와 `references/steelman.md`(:59-63)는 확인 줄 `- 확인 RC<n> — …` 을 audit §5 에 적으라 한다. 인터뷰 중에는 audit 이 없다. 「대체됨」 줄은 같은 문제를 이미 풀었다. 인터뷰 중에는 state `## R<n>` «지금 이해» 아래에 적고, finishing Step A 가 audit §5 로 글자 그대로 옮긴다(`references/fresh-evidence.md:21`, finishing.md :136-137). finishing V2(:169-185)와 게이트 ⑤(`check_brief.py` :1485-1510)는 확인 줄 없는 `RC<n>` 을 막는다 — 지금도 조용히 지나가지는 않는다.
4. **원장 뿌리.** 세 skill 의 원장 펜스는 상태 루트를 cwd 에서 찾는다. 해당 자리는 `state_path.py state-root` 호출 22곳이다(RB 10 · SR 9 · RF 1 · finishing.md 2). 결정 줄 펜스(SR :693-724)만 문서의 레포로 들어가 찾고, 레포가 다르면 공시한다. `state-root` 는 이미 선택 인자 `<cwd>` 를 받는다(`state_path.py:9` · :243-246).
5. **로드맵 생성 따옴표.** finishing Step A 8(:202-209)이 `--title "<주제 한 줄>" --approval "<승인 원문>"` 로 사용자 말을 큰따옴표에 싣는다. B-R(:624-631)은 그 명령을 그대로 다시 돌린다. 같은 생성기의 `update` 는 따옴표 heredoc + `=` 꼴로 이미 고쳤다(`references/redecompose.md:69-99`).
6. **템플릿 판 꼬리.** `templates/interview-audit-template.md:6` 은 `pm-interview v0.57.0`, `interview-brief-template.md:6` 은 `v0.23.0` 이다. 이 이름과 판이 함께 존재한 적은 없고, 이 줄을 읽는 코드도 없다.
7. **실행 비트.** 실제 셸 테스트 넷이 mode 100644 다 — `SD/tests/test_brief_bundle.sh` · `test_brief_no_length_cap.sh` · `shared/tests/test_docreview_gate_visibility.sh` · `test_entry_preflight.sh`. 레포 스위트(`tools/suite/run-all.sh`)는 `bash` 로 돌려 보지만, qg 의 테스트 선택(`run-test-selection.sh` :202-205)은 실행 비트가 없는 파일을 집지 못한다. 나머지 100644 셸 파일은 `source` 되는 라이브러리 · 픽스처다(`test_*` 이름이 아니다).

## Goals

- G1 인터뷰를 닫는 사용자 답(외부 선례 무관 · 사용자 판단 포화)은 그 S 가 state 에 고른 선택지(`source: chosen`)로 기록돼 있을 때만 통과한다 — payload · audit 과 state 가 서로 맞는지를 잰다. 사용자가 정말 골랐는지의 증명은 아니다(state 도 모델이 쓴다, §2 한계).
- G2 엔진 skill 셋, 공유 러너, skill 이 부르는 스크립트가 상태 폴더에 쓰는 자리는 미리 심은 링크를 따라가지 않는다. 세 skill 은 펜스 전체를 읽는 도출 락이, 공유 러너는 그 상태 폴더 쓰기 자리를 겨냥한 락이 새 맨 넘기기를 막는다 — 러너의 `$SCRATCH`(`mktemp -d`) 대상은 허용, `runner_common.sh` 의 `write_failclosed` · `_degrade_if_empty` 는 이유와 함께 이름으로 뺀다. 스크립트의 쓰기 자리는 끝에서 끝 확인으로 잰다(AC7).
- G3 V1 확인 줄이 인터뷰 중에 실릴 자리를 갖고, 끝날 때 audit §5 로 그대로 옮겨진다.
- G4 리뷰 원장은 cwd 가 아니라 문서가 사는 레포에서 찾는다. 다르면 한 줄로 알린다.
- G5 사용자 말이 로드맵 생성 명령에서 셸로 새지 않는다.
- G6 템플릿의 거짓 판 표기를 빼고, 실제 셸 테스트가 qg 에도 집힌다.

## Non-goals

- R10 계획 1~3 의 범위.
- R12 범위였고 R12 가 끝낸 엔진 · qg 일과, R12 미룸 중 R13 으로 넘기지 않은 행은 하지 않는다. R13 은 R12 미룸의 R13 행 둘(§5 · §6)과 공유 러너 · writer 링크에 닿는 qg 쪽 최소 변경만 한다.
- 엔진 밖 원장 쓰기의 권한 경계(R8).
- `state_path.py` · `check_brief.py` 의 불변식 · 기존 하위 명령 바꾸기(§5 는 `state_path.py` 에 하위 명령 하나를 더할 뿐이다).
- 조사 agent(repo-researcher · open-researcher)의 출력 계약 바꾸기.
- superpowers 의 파일 · 동작(C25 · C35 · D26).

## Anti-goals

- 새 상태 파일 · 새 state 키 · 새 명령 · 새 rc. 이미 있는 rc 표 · 인자 · 옮겨 쓰기 길로 표현한다. 새로 만드는 것은 작은 공용 writer 하나와 `state_path.py` 의 하위 명령 하나(`state-root-for`, §5)뿐이다(과설계 경계 원칙).
- 쓰기 자리마다 `[ -L … ]` 가드를 따로 박기 — 같은 결함이 자리를 옮겨 다시 나온다.
- 락의 면제 이름 목록을 손으로 키우기. 허용 대상과 테스트 집합은 도출한다.

## Constraints

- C25 · C35 · D26 — 외부 플러그인은 건드리지 않는다.
- C32 — 원래 있는 것을 다시 만들지 않는다(`## 있는 것 검토`).
- D21 — §8 이 원본 brief 의 위험 가운데 이 에픽에 닿는 것에 답한다.
- CLAUDE.md — 기본값과 판단 · 레포 전용 값 금지 · 상류 · 하류 연계 · 진입점에서 따라 내려가기 · 있는 것 먼저 · 공시와 차단 · 마크다운 상태 · 크게 무너지지 않고 강등을 알리기.
- 셸 펜스와 셸 테스트는 macOS bash 3.2 에서 돈다. 새 · 바뀐 셸 테스트는 100755 다.
- 새 스크립트는 레포 락을 지난다 — 중복 감시(`shared/tests/test_no_new_duplication.sh`) · 파이썬 하한 · UTF-8 명시 · 배포 링크 락(`shared/tests/test_copy_of_contract.sh` — 배포 지점 심볼릭 링크를 도출하고 :312-326, 빠짐 · 일반 파일 · 끊김 · 대상 어긋남에 RED :461-476).
- 경로 예약 — R13 예약 밖 파일은 `## Files to Modify` 에 «예약 밖» 으로 적고, 지휘자가 로드맵 PR 로 등록한다. R8 은 이 에픽 뒤에 간다(spec-review `SKILL.md` 겹침). `## 미룸` 의 R8 행은 지휘자가 R13 의 범위 · 경로 예약을 고치는 같은 로드맵 PR 에서 로드맵 R8 범위에 등록한다(사용자가 승인한 재분해) — 받는 곳이 실제로 있게 한다.

## 설계

### §1 범위

| # | 항목 | 출처 | 자리 |
|---|---|---|---|
| 1 | 사용자 답과 state `source: chosen` 대조 | R10 미룸 :401 | §2 |
| 2 | 링크 따라 쓰기 — 함께 쓰는 writer | R10 미룸 :402 | §3 |
| 3 | V1 확인 줄의 자리 | R10 미룸 :403 | §4 |
| 4 | 원장 뿌리를 문서의 레포에서 | R12 미룸 :450 | §5 |
| 5 | finishing Step A 8 `create` 따옴표 | R12 미룸 :451 | §6 |
| 6 | 템플릿 `source:` 판 꼬리 | PR #239 넘김 | §7 |
| 7 | 100644 셸 테스트 실행 비트 | PR #239 넘김 · recon | §7 |
| — | reviewing-brief 추가 라운드 승인 꼴 | R12 미룸 :449 | 이미 고침(68a41ab5) — 일 아님 |

### §2 사용자 답 대조 — 원문 완전성 검사에 얹기

- `check_brief` 는 그대로 둔다. state 를 읽지 않는 불변식(:23-27)이 임의의 brief 에 게이트를 돌리게 한다.
- `check_verbatim_coverage.py` 는 이미 payload · state · audit 셋을 읽고, reviewing-brief 진입 펜스가 이미 부른다. `parse_user_statements` 가 레코드의 `source` 를 남기게 고치고 새 대조를 하나 더한다.
  - 대상 S: brief §4 의 「외부 선례 무관(@S…)」 줄이 가리키는 S 전부, 그리고 audit §2 의 **마지막** 포화 판정 줄이 「사용자 판단 포화(@S…)」 일 때 그 S.
  - 판정: 레코드의 `source` 만으로 가른다. 대상 S 의 state 레코드가 `source: chosen` 이어야 한다. 레코드가 없거나 `source: verbatim` 이면 위반이다(rc 1). 위반한 S 는 결과의 새 목록 키에 실린다. S 번호로 따로 가르지 않는다 — 최초 요청이 없으면 첫 사용자 답이 `S1` 이다(finishing.md :100-101).
  - 레코드는 있는데 `source` 가 없으면 검사 불가다(rc 3, advisory) — 기존 「검사 불가 ≠ 통과」 규칙 그대로다.
- 줄 문법은 `check_brief` 의 것을 import 해서 쓴다(`IRRELEVANT_RE` · `SAT_LINE_RE` · `SAT_USER_RE` · 절 읽기). 베껴 쓰면 두 검사가 갈라진다. 공개 함수 하나로 묶을지는 계획이 정한다.
- 실패 처리는 기존 원문 완전성 위반과 같다 — 새 rc 는 없다. rc 1 이라 건너뛰기 변수(`DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE`)로도 넘지 못하고 reviewing-brief 는 라운드를 시작하지 않고 멈춘다. 고치는 일은 새 자동 장치가 아니라 같은 세션의 finishing(Step A.5 를 부른 자리)이 한다 — 리뷰 진입 때는 brief 가 이미 있어서 인터뷰 진입(`interview_state.py` :80-81 · :105-106)은 그 인터뷰를 「이미 끝난 인터뷰」로 보고 이어 가기를 거부하기 때문이다. RB rc 표에 아래 행을 더한다(기존 `1` 행 아래, 키로 가른다):

  | `vc_rc` | 뜻 | 동작 |
  |---|---|---|
  | `1`(`not_chosen`) | 인터뷰를 닫은 답(외부 선례 무관 · 사용자 판단 포화)의 S 가 state 에 고른 선택지(`source: chosen`)로 기록돼 있지 않다 | **차단 — 건너뛰지 않는다.** 리뷰를 멈추고 사용자에게 「인터뷰를 닫은 답 <S 목록> 이 고른 선택지로 기록되지 않았다 — 마무리 단계가 그 질문을 선택지로 다시 묻는다」를 보인다. finishing Step A.5 는 이 사유로 멈추면 같은 세션에서 그 닫힌 질문을 `AskUserQuestion` 선택지로 다시 묻는다(닫는 선택지 · 「조사 계속」). **닫는 선택지**면 새 `chosen` S 를 state `user_statements` 에 기록하고, 그 S 를 가리키는 새 포화 판정 줄을 state `## audit §2 대기 줄` 블록 **한 곳에만** 덧붙인다(옛 줄은 고치지 않고 기록으로 남긴다 — 게이트는 마지막 줄을 본다. 외부 선례 무관이면 brief §4 줄의 `@S` 를 바꾼다). 그다음 Step A 에서 state 로부터 다시 짓는 걸음(payload §6 · audit §6 · audit §2 옮기기)과 7 게이트 · 8 생성(로드맵이 있을 때)을 다시 돈 뒤 Step A.5 로 돌아간다 — audit §2 는 대기 줄 블록에서 다시 지어지므로 줄이 두 번 실리지 않고, §6 들은 state 에서 다시 지어져 새 S 가 더해질 뿐이다. 어느 걸음이 다시 돌아도 같은 결과를 내는지(멱등)는 계획이 실측한다. **「조사 계속」**이면 같은 세션의 라운드 루프로 돌아가고, 다시 닫을 때 finishing 을 처음부터 돈다 |

  사용자가 다시 답하지 않는 경우를 따로 다루는 장치는 두지 않는다 — 리뷰는 멈춘 채로 남는다. **한계(README 공시):** 되묻기는 Step A.5 를 부른 그 세션의 finishing 에만 있다. 세션을 넘겨 reviewing-brief 를 따로 불러 이 사유로 멈추면, 끝난 인터뷰라 진행 기록에서 다시 이을 수 없다 — 멈춤 문장이 그 사실을 함께 알린다.
- 「사용자 종료(@S…)」 는 대상이 아니다. 사용자가 자유 글로 끝낼 수 있다.
- **한계 둘(README · CHANGELOG 공시 — 둘 다 남긴다).**
  - 시점: 대조는 Step A 7 의 `check_brief gate` 가 아니라 Step A.5 리뷰 진입에서 걸린다. 그 사이 brief 는 이미 쓰였다. 리뷰 진입을 지나지 않는 길에서는 대조가 돌지 않는다.
  - 출처: `user_statements`(그 `source: chosen` 포함)도 모델이 쓴다. 이 대조는 payload · audit 과 state 가 서로 맞는지를 잴 뿐, 사용자가 정말 골랐는지를 증명하지 않는다. R10 이 남긴 「사용자가 골랐는지 증명하지 못한다」 한계 문장은 그대로 두고 시점 한계를 더한다.

### §3 링크 따라 쓰기 — 작은 공용 writer 하나

- `shared/docreview/scripts/nofollow_write.py`(이름은 계획이 다듬을 수 있다)를 둔다. 공유 러너가 quality-gates 에도 실려 나가므로, spec-distill · quality-gates 의 `scripts/` 에 링크한다(다른 docreview 공유본과 같은 꼴). 쓰는 꼴은 `ledger_marker._atomic_write` · `interview_state.py` :150-165 의 `O_EXCL | O_NOFOLLOW` 임시 파일 + `os.replace` 다. 공유 쪽은 플러그인 모듈을 import 할 수 없어 그 몇 줄을 새로 쓴다(중복 감시 한도 안).
- 모드 셋. 셋 다 마지막 경로 성분의 링크를 따라가지 않는다. 링크가 둘 이상인 파일(하드 링크)은 모드마다 다르다 — `run` 과 `empty` 의 이름 바꾸기 갈래는 그 파일 내용을 건드리지 않고 이름만 새 일반 파일로 바꿔 놓는다(거부하지 않는다). `empty` 의 자르기 갈래와 `append` 는 그런 파일에 쓰지 않고 거부한다.

| 모드 | 하는 일 |
|---|---|
| `run --out P -- <명령…>` | 명령을 돌린다. stdout 을 P 옆 임시 파일에 받아 `os.replace` 로 P 에 놓는다. 명령의 rc 를 그대로 낸다. 명령이 0 이 아니어도 stdout 은 놓는다 — 지금 `> "$BUNDLE"` 와 같다(RB 는 rc 3 번들을 쓴다). writer 자신의 실패는 감싸는 명령들이 내지 않는 rc 하나와 stderr 한 줄로 낸다 |
| `empty --out P` | P 를 빈 일반 파일로 만든다. 먼저 임시 파일 + `os.replace` 를 하고, 폴더가 쓰기 불가라 이름을 바꿀 수 없으면 `O_NOFOLLOW` 로 열어 일반 파일 · 링크 하나인지 확인한 뒤 자른다. 둘 다 못 하면 0 아닌 rc 를 낸다. `: >` 비우기 자리를 대신한다 — 그 자리의 「못 지우면 절단, 둘 다 못 하면 멈춤」 갈래는 그대로다 |
| `append --out P` | stdin 을 `O_APPEND | O_CREAT | O_NOFOLLOW` 로 덧붙인다. 일반 파일 · 링크 하나가 아니면 거부한다. 빈 입력이면 파일만 만든다 — `touch` 쓰기 확인 자리를 대신한다 |

- 바꾸는 자리: 세 skill 의 상태 폴더 · degrade 대체 파일 쓰기 전부(Context 2), 그리고 공유 러너의 :50 · :67 · :495-498. `printf … > f` 꼴은 `run` 모드로 감싸거나 `append`/`run` 에 stdin 으로 넘긴다.
- **skill 이 부르는 스크립트의 상태 폴더 쓰기.** stdout 을 writer 로 받아도 스크립트가 스스로 여는 쓰기는 남는다. 이 쓰기도 마지막 경로 성분의 링크를 따라가지 않게 바꾼다 — 닿을 수 있으면 writer 의 함수를 import 하고, 아니면 그 몇 줄을 둔다(계획이 정한다).
  - `plugins/spec-distill/scripts/seed_edit_diff.py` — 기준 사본 `shutil.copyfile(seed, base)`(:132 · :143), `.shown` 표지 `write_text`(:164 · :196), `.reverted` 표지 `write_text`(:197). 기준 사본 `$SEED_BASE` 는 `$STATE_DIR` 안이다(request-framing `SKILL.md` :340 · :392). 세 쓰기 모두 writer 와 같은 꼴(`O_EXCL | O_NOFOLLOW` 임시 파일 + `os.replace`)로 쓴다.
  - `shared/docreview/scripts/docreview_state.py` `save_state` — 원장 `docreview-state.md` 제자리 덮어쓰기(:320 `open(…, "wb")`)와 시대 표지 `docreview-digest-era`(:325 `write_bytes`). 원장은 제자리 덮어쓰기 성질(:318 — 쓰기 불가 폴더 안의 쓰기 가능한 원장도 갱신된다)을 지킨다 — `O_NOFOLLOW` 로 열어 일반 파일 · 링크 하나인지 확인한 뒤 자른다(`empty` 의 자르기 갈래와 같은 꼴). 표지는 `O_CREAT | O_EXCL | O_NOFOLLOW` 로 만든다.
  - 그 밖은 찾지 못했다. 세 skill 이 부르는 스크립트 24개(`state_path.py` · `docreview_state.py` · `docreview_route.py` · `seed_edit_diff.py` 등)에서 `write_text` · `write_bytes` · `copyfile` · 쓰기 모드 `open` · `os.open` · `os.replace`/`rename` · 셸 넘기기를 grep 했다. 이미 안전한 자리 — `ledger_marker.py`(:39 · :49 `O_NOFOLLOW`) · `interview_state.py`(:157) · `ledger_sweep.py`(:143 · :159-163 `os.rename` 은 대상 링크를 따라가지 않는다) · `clear_critic_outputs.sh`. 상태 폴더 밖 — `brief_review_state.py`(인터뷰 state 파일) · `seed_review_log.py`(audit) · `seed_provenance.py` · `seed_edit_diff.py` :195(seed) · `docreview_state._write_atomic`(사용자 문서) · 러너 :401(`$SCRATCH`) · :384(테스트 전용 환경 변수). `docreview_route.py` 는 `save_state` 로만 쓴다. 나머지는 stdout 만 낸다.
- **락.** 세 skill 폴더의 bash 펜스에서 쓰기를 도출한다.
  - 쓰기로 세는 꼴: `>` · `>>` · `>|` · `&>` · `N>` · `{ … } >` · `exec >` · `| tee` · `touch`.
  - 허용 대상: `/dev/null`, fd 복제(`>&2`), 같은 펜스에서 `mktemp` 로 만든 변수(도출). 그 밖은 RED 다.
  - 셸 펜스인데 첫 줄이 정확히 ```` ```bash ```` 가 아닌 펜스(```` ```sh ```` · 들여쓴 펜스 · 꼬리 공백 · CRLF)에 쓰기가 있으면 「검사 밖 펜스」로 거부한다 — R12 `ac8_scan` 의 펜스 모양 축과 같은 규칙이다. 프롬프트 틀 펜스의 `<tag>${VAR}` 는 쓰기가 아니다(오탐 대조로 확인).
  - 락은 새 파일에 둔다. R12 의 원장 쓰기 순서 락(`test_ledger_wiring.sh`)은 엔진 호출 줄만 보고 `| tee` 를 알려진 경계로 남겼다. 새 락은 그 경계를 세 skill 에서 덮는다. R12 락은 그대로 둔다. 그 단언(「`ac8_scan` 은 `| tee` 를 보지 않는다」)은 계속 참이다. 공유 절차서 `reviewing-document.md` 에는 셸 쓰기가 없다.
- **공유 러너 락 — 겨냥한 락.** 공유 러너는 위의 펜스 파서로 읽지 않는다. 러너의 상태 폴더 쓰기 자리(지금 :50 · :67 · :495-498 — `$OUTPUT_PATH` 로 가는 쓰기)가 writer 를 거치는지를 따로 단언한다. `$SCRATCH`(`mktemp -d` 로 만든 폴더) 아래로 가는 쓰기(프롬프트 · codex stdout · stderr)는 허용한다. `runner_common.sh` 의 두 함수 — `write_failclosed` 와 종료 trap 이 부르는 `_degrade_if_empty`(:84 trap → `runner_common.sh` :66 `> "$out"`) — 는 이름으로 빼고 이유를 적는다 — 둘 다 qg 러너와 나누는 사본 쌍에 있고, 러너의 첫 쓰기가 심어 둔 링크를 이미 일반 파일로 바꿔 놓은 뒤에 불린다. 그 밖의 `$OUTPUT_PATH` 맨 넘기기를 다시 넣는 변이에 RED 다.
- **한계(README 공시).**
  - Write 도구로 상태 폴더에 쓰는 파일(`said-*.txt` · `readback.txt`)은 셸 쓰기가 아니라 writer 로 감쌀 수 없다(`## 미룸`).
  - writer 는 마지막 경로 성분만 지킨다. 상태 폴더 자체의 링크는 이미 `path-inside` 가 막는다.
  - 실행 중에 다시 심는 링크(같은 사용자의 경쟁)는 지키지 않는다.
  - 공유 러너가 부르는 `write_failclosed` 와 종료 trap 의 `_degrade_if_empty`(:84 → `runner_common.sh` :66, qg 러너와 나누는 `runner_common.sh` 사본 쌍)는 바꾸지 않는다. 러너의 첫 쓰기(:50)가 심어 둔 링크를 일반 파일로 바꿔 놓은 뒤에 쓰기 때문이다. 러너 락은 두 함수를 이 이유로 이름으로 뺀다.

### §4 V1 확인 줄 — 「대체됨」 과 같은 길

- pm-interview `SKILL.md` V1 ⑤ 와 `references/steelman.md` Step 2 를 바꾼다. 인터뷰 중에는 그 라운드의 state `## R<n>` «지금 이해» 아래에 `- 확인 RC<n> — {확인|반증|미확인} — <경로>#<앵커> — <사유>` 한 줄을 적는다.
- finishing Step A 는 「대체됨」 줄을 옮기는 같은 걸음에서 확인 줄도 라운드 순서대로 audit `## 5. 프로세스 로그` 에 글자 그대로 옮긴다. 다시 짓거나 요약하지 않는다.
- steelman 의 audit §3 `ST<N>` 블록 기록은 그대로다. 「audit §5 의 확인 줄이 곧 레지스터」(:154-155)도 끝난 뒤의 사실로 그대로 둔다.
- 조사 agent 의 출력은 바꾸지 않는다. finishing V2 · 게이트 ⑤ 는 그대로 막는다 — 옮기지 않은 `RC<n>` 은 지금처럼 red 다.

### §5 원장 뿌리 — 문서의 레포에서

- 이미 있는 `plugins/spec-distill/scripts/state_path.py` 에 하위 명령 하나를 더한다 — `state-root-for <문서 경로>`. 문서의 폴더가 git 작업 트리 안이면 `state_root(<문서 폴더>)` 를 내고, 아니면 `state_root()`(cwd)를 내고 stderr 에 공시 한 줄(「문서가 git 작업 트리 밖이다 — 지금 작업 폴더의 레포 원장을 쓴다」 꼴)을 쓴다. 기존 하위 명령 · `state_root` 의 동작은 그대로다.
- RB · SR · finishing.md 의 `state-root` 호출은 모두 `state-root-for "<그 펜스의 문서 변수>"` 로 바뀐다 — RB · finishing.md 는 `"$PAYLOAD"`, SR 은 `"$spec_path"`. 호출을 둘러싼 대입 꼴(`|| true` · `${ROOT:-…}` · `$PR`/`$SD`)은 지금 그대로 둔다. finishing.md 의 두 펜스는 RB 의 원장을 함께 읽으므로 같은 하위 명령을 부른다.
- 공시 횟수.
  - 원장 열기 펜스(RB 의 첫 원장 펜스 · SR `ledger-open`)가 라운드마다 한 번 낸다. 문서 레포의 `git-common-dir` 가 cwd 의 것과 다르면 결정 줄 펜스(SR :698-703)와 같은 비교 · 같은 말투로 한 줄을 낸다. 문서 폴더가 git 작업 트리 밖이면 `state-root-for` 의 stderr 줄이 그 공시다.
  - 결정 줄 펜스는 지금의 레포 다름 줄(SR :703)을 바꾸지 않는다. git 밖 문서면 쓸 때마다 `state-root-for` 의 stderr 로 같은 git 밖 줄을 낸다.
  - 그 밖의 펜스도 git 밖 문서면 `state-root-for` 에서 같은 stderr 줄을 받는다. 같은 사실의 되풀이이고, 공시를 단언하는 자리는 위 둘이다 — 그 줄을 숨기는 장치는 두지 않는다.
- RF 는 바꾸지 않는다 — seed 경로를 cwd 에서 만들기 때문이다(`$(pwd)/$SEED`, :384). 락은 RF 의 유일한 `state-root` 호출(:354)을 그 이유와 함께 이름으로 뺀다.
- 결정 줄 펜스(SR :693-724)도 `state-root-for "$spec_path"` 를 부른다. 문서가 git 작업 트리 밖이면 지금의 거절(:702 rc 1 「결정 줄을 쓰지 않았다」)을 없애고 원장 열기와 같은 cwd 뿌리의 원장에 쓴다 — 그래야 git 밖 문서도 리뷰와 결정 줄이 같은 원장을 쓴다.
- 원장 열기 펜스는 이미 도출한 `ROOT` 를 원장 정리에 넘긴다(`ledger_sweep.py --root "$ROOT"` — SR :237 → :249 · RB :130 → :142). 그래서 §5 뒤 원장 열기의 정리는 문서 레포의 뿌리를 따른다.
- 결과: cwd 가 다른 레포여도 원장 열기와 결정 줄 펜스가 같은 원장을 찾는다. R12 AC15 의 「마지막 원장 열기가 문서의 레포에서 돌았을 때만」 조건이 사라진다.
- **한계(README 공시).** request-framing 의 원장 정리와 지휘자는 여전히 cwd 레포의 뿌리를 쓴다. 다른 레포의 문서를 리뷰하는 동안에는 cwd 레포의 원장이 그때 정리되지 않는다.

### §6 로드맵 생성 따옴표

- finishing Step A 8 펜스는 `redecompose.md` §5 의 꼴을 따른다. 제목은 `IFS= read -r` + 따옴표 heredoc 으로 받는다. 승인 원문은 `mktemp` 임시 파일 + `trap` 에 heredoc 으로 적는다. 생성기에는 `--title="$title"` · `--approval="$(cat "$AF1")"` 의 `=` 꼴로 넘긴다. 구분 줄이 글에 있으면 바꾸는 규칙과 말이 여럿일 때 `AF<k>` 를 더하는 규칙도 같다.
- B-R 은 「Step A 8 의 명령을 그대로」를 유지하므로 바뀐 꼴을 물려받는다. `roadmap_write.py create` 는 이미 같은 인자를 받는다(:489-505). 펜스 글만 바뀐다.

### §7 템플릿 · 실행 비트

- 두 템플릿의 `source:` 줄에서 판 꼬리를 뺀다(`source: spec-distill pm-interview`). seed audit 템플릿과 같은 꼴이다. 테스트 픽스처의 옛 `source:` 줄은 고치지 않는다.
- 셸 테스트 넷을 `chmod +x` 한다(100755). 각각 shebang 이 있고 직접 실행해도 통과해야 한다.
- **락.** 레포 스위트가 고르는 셸 테스트 전부가 git 인덱스에서 100755 여야 한다. 고르는 규칙은 `run-all.sh` 와 같다 — `shared/tests` · `plugins/*/tests` 의 `test_*.sh`, spike · fixtures 제외. 라이브러리 · 픽스처는 `test_*` 이름이 아니라서 이름 목록 없이 빠진다.

### §8 위험에 대한 답

묶음 §5 는 「없음」이다. 원본 brief 의 위험 가운데 이 에픽에 닿는 것과 답:

- 숨은 가정 「멈춤 판정의 주인이 조사하는 모델 자신으로 옮겨 … 조기 「충분」 선언」, 실패 양식 「포화를 가장한 조기 종료」 — §2. 사용자 판단 포화 · 외부 선례 무관은 사용자가 고른 답일 때만 통과한다.
- 숨은 가정 「모델은 사용자 말에 맞추는 경향」 — §2. ☑ 표지는 모델이 쓰지만 `source: chosen` 은 선택지 답에서만 기록된다.
- 실패 양식 「버전 · CHANGELOG 같은 공유 파일 겹침」 — 계획 하나 · 판 번호는 머지 직전에 정한다(Metadata).
- 나머지 위험(분해 봉인 · 압축 · 승인 피로 · 외부 문구 변화 · 두꺼운 brief)은 이 에픽의 변경과 닿지 않는다.

이 설계가 새로 여는 위험:

- writer 가 쓰기를 거부하면 지금 성공하던 라운드가 멈출 수 있다(링크가 둘인 상태 파일 등). 거부는 기존 「못 쓰면 멈춤」 갈래로 가고 사유를 보인다. 상태 폴더는 엔진만 쓰므로 정상 흐름에서 링크가 둘인 파일은 생기지 않는다 — 계획이 실측한다.
- 대조 강화로 지금 통과하던 brief 가 리뷰 진입에서 막힐 수 있다(모델이 자유 글 답에 ☑ 를 붙인 경우). 바라던 동작이다. 고치는 길을 rc 표가 적는다.
- 쓰기 락이 지금 문서를 RED 로 만든다. 그래서 같은 PR 에서 모든 자리를 writer 로 바꾸고, 변이로 이빨을, 양성 대조로 과잉을 확인한다.

### §9 계획

계획 하나, 브랜치 `feature/interview-gate-leftovers`. 일곱 항목은 대부분 다른 파일을 고친다. 순서는 계획이 정한다 — writer(§3)를 먼저 두면 §3 의 skill 고침과 §5 의 펜스 고침이 같은 펜스를 한 번만 연다.

## 있는 것 검토

- 레포 안(쓴다):
  - `check_verbatim_coverage.py` 의 `run` · rc 표 · `ParseError`/검사 불가 갈래(§2)
  - `check_brief.py` 의 닫힘 줄 문법(§2)
  - `ledger_marker._atomic_write` · `interview_state.py` :150-165 의 쓰기 꼴(§3)
  - `clear_critic_outputs.sh`(이미 안전 — 그대로)
  - `state_path.py` 의 `state_root(<cwd>)` — 새 하위 명령 `state-root-for` 는 이것을 부를 뿐이다 · 결정 줄 펜스의 레포 비교(§5)
  - `redecompose.md` §5 의 heredoc · `=` 꼴(§6)
  - 「대체됨」 옮겨 쓰기 길(§4)
  - `run-all.sh` 의 테스트 선택 규칙(§7)
  - R12 `ac8_scan` 의 펜스 모양 규칙(§3 락)
- 레포 안(맞지 않아 쓰지 않는다): `docreview_state._write_atomic` 은 `realpath` 로 링크를 따라간다. `roadmap_write._atomic` 은 생성기 트랜잭션의 일부인 spec-distill 모듈이라 공유 러너가 import 할 수 없다.
- 레포 밖: 쓰지 않는다. 파이썬 표준 `os.open` 플래그만 쓴다.

## 상류 · 하류 연계

- 받는 곳: 묶음 R13.md · R10 설계 `## 미룸` R13 행(:401-403) · R12 설계 `## 미룸` R13 행(:450 · :451, :449 는 이미 끝냄) · PR #239 넘김(템플릿 판 꼬리 · 100644 셸 테스트) · 덩어리 1 되비춤 승인 U1.
- 넘기는 곳: 고친 인터뷰 게이트 · 엔진 skill 셋은 인터뷰 · 리뷰 사용자에게 간다. writer 는 공유 러너를 거쳐 qg 문서 비평에도 간다. 엔진 밖 쓰기의 권한 경계와 Write 도구 쓰기는 R8 에 넘긴다 — R8 은 이 에픽 뒤에 구현한다.
- 되돌아오는 길: 계획 · 구현에서 설계를 다시 나눌 근거가 보이면 재분해 신호 · 설계 변경으로 지휘 세션에 보고한다(`references/redecompose.md`). 예: writer 거부가 정상 흐름을 막음, 대조가 옛 state 를 대량으로 검사 불가로 만듦.
- 같은 상태를 읽는 다른 표면:
  - state `user_statements` — 원문 완전성 검사 · finishing Step A · B-0 확인
  - 리뷰 원장 — RB · SR · finishing.md 두 펜스 · 결정 줄 펜스 · 지휘자 `gate-rows`
  - 상태 폴더의 번들 · critic 산출물 — 탐지 · 재비판 dispatch · codex 게이트 · audit 옮기기
  - 로드맵 표 파일 — 생성기 · 지휘자 상태 계산
  - 이음매 담당은 이 에픽이다.
- 경로 겹침: R8 예약(spec-review `SKILL.md` 등)과 겹친다. R8 이 뒤에 가며 기본 브랜치를 합친다.

## Acceptance Criteria

**사용자 답 대조(§2)**
- AC1 brief §4 「외부 선례 무관(@S<m>)」 이 가리키는 S 의 state 레코드가 `verbatim` 이면 `check_verbatim_coverage.py` 가 rc 1 을 내고 결과의 새 키에 그 S 를 싣는다. `chosen` 이면 그 대조로는 막지 않는다(양 · 음 픽스처).
- AC2 audit §2 마지막 포화 판정 줄이 「사용자 판단 포화(@S<m>)」 이면 같은 판정을 한다. 앞선 줄의 사용자 판단 포화 S 와 「사용자 종료(@S…)」 의 S 는 보지 않는다(각 픽스처).
- AC3 판정은 레코드의 `source` 로만 한다 — 대상 S 의 레코드가 state 에 없거나 `source: verbatim` 이면 rc 1, 레코드에 `source` 가 없으면 rc 3 과 advisory 다. `source: chosen` 인 `S1` 은 통과한다(최초 요청이 없는 인터뷰 픽스처). `check_brief.py` 는 state 를 읽지 않는다(불변식 docstring · 기존 테스트 그대로). RB rc 표에 `1`(`not_chosen`) 행이 있고, finishing Step A.5 에 그 사유의 되묻기 갈래(닫는 선택지 → state 기록 · 대기 줄 한 곳 덧붙이기 · Step A 다시 짓기 · 7 · 8 · A.5 / 「조사 계속」 → 라운드 루프)가 있다(문장 단언). 끝에서 끝: `not_chosen` 픽스처에 새 `chosen` S 와 덧붙인 대기 줄을 넣고 Step A 의 다시 짓는 걸음을 돌리면 audit §2 에 새 줄이 한 번만 실리고, 대조와 `check_brief gate` 가 통과한다(사용자가 다시 답하지 않는 경우의 테스트는 두지 않는다). 건너뛰기 변수가 켜져도 이 rc 1 은 건너뛰지 않는다. README · CHANGELOG 에 §2 의 시점 한계를 더했고, 출처 한계(「사용자가 골랐는지 증명하지 못한다」)는 남아 있다.

**링크 따라 쓰기(§3)**
- AC4 writer `run` 은 P 가 레포 밖 파일을 가리키는 심볼릭 링크이거나 링크가 둘인 파일이어도 그 너머를 바꾸지 않고, P 를 명령 stdout 을 담은 일반 파일로 만든다. 명령 rc(0 · 3 · 그 밖)를 그대로 내고 rc 가 0 이 아니어도 stdout 을 놓는다. writer 자신의 실패는 따로 정한 rc 와 사유 줄이고, P 는 그대로다.
- AC5 `empty` · `append` 는 링크를 따라 쓰지 않는다. `empty` 는 빈 일반 파일을 만들거나 0 아닌 rc 로 거부한다. `append` 는 없으면 만들고 있으면 덧붙이며, 링크 · 링크 둘이면 거부한다. 모두 bash 3.2 펜스에서 돈다.
- AC6 세 skill 폴더의 bash 펜스에 허용 대상(`/dev/null` · fd 복제 · 같은 펜스의 `mktemp` 변수) 밖의 쓰기(`>` · `>>` · `>|` · `&>` · `N>` · `{ … } >` · `exec >` · `| tee` · `touch`)가 없다. 도출 락이 이를 지킨다. 꼴마다 하나씩 다시 넣는 변이에 RED, `mktemp` 대상 heredoc 양성 대조는 GREEN, 검사 밖 펜스의 쓰기는 거부다. 공유 러너는 이 펜스 파서의 대상이 아니다(AC7).
- AC7 공유 러너의 상태 폴더 쓰기 자리(`$OUTPUT_PATH` 로 가는 :50 · :67 · :495-498 자리)가 writer 를 거친다는 겨냥한 락이 있다. `$SCRATCH`(`mktemp -d`) 아래 쓰기는 허용되고, `runner_common.sh` 의 `write_failclosed` · `_degrade_if_empty` 는 이유와 함께 이름으로 빠진다. `$OUTPUT_PATH` 맨 넘기기를 다시 넣는 변이에 RED 다. 실제 펜스와 러너를 임시 레포에서 돌려도 심어 둔 링크(번들 · 재비판 번들 · critic YAML · `hunks.json` · `gate-drops.json` · degrade 대체 파일)의 너머가 바뀌지 않는다 — RB 번들 펜스 · RF 번들 펜스 · 공유 러너 각각 하나 이상. skill 이 부르는 스크립트도 끝에서 끝으로 같다 — `seed_edit_diff.py` 의 기준 사본(`$SEED_BASE`) · `.shown` · `.reverted`, `docreview_state.py` 의 원장 `docreview-state.md` · 시대 표지에 심어 둔 링크를 `init` · `accept` · `hunks` · `revert` 와 원장 저장이 따라가지 않는다(각 자리 하나 이상). writer 가 두 플러그인 `scripts/` 에 링크돼 있고, 배포 링크 락 `shared/tests/test_copy_of_contract.sh` 가 그 두 링크를 잡는다 — 도출이 그 둘을 집지 못하면 writer 테스트에 단언을 더한다. 링크 하나를 지우거나 사본 파일로 바꾸는 변이에 RED 다.

**V1 확인 줄(§4)**
- AC8 V1 ⑤ · steelman Step 2 가 인터뷰 중 확인 줄을 state `## R<n>` «지금 이해» 아래에 적으라 한다. finishing Step A 가 그 줄을 라운드 순서대로 audit `## 5. 프로세스 로그` 에 글자 그대로 옮긴다. 인터뷰 중 audit §5 에 적으라는 문장은 남지 않는다(부재 락 + 양의 짝). `RC<n>` 의 확인 줄이 audit §5 에 없는 brief 는 지금처럼 게이트 ⑤ 에서 red 다.

**원장 뿌리(§5)**
- AC9 `state_path.py state-root-for <문서 경로>` 는 문서 폴더가 git 작업 트리 안이면 그 폴더의 `state_root` 를, 밖이면 cwd 의 `state_root` 와 stderr 공시 한 줄을 낸다(단위 테스트, 기존 하위 명령 출력은 그대로). RB · SR · finishing.md 의 상태 루트 호출은 모두 `state-root-for "<그 펜스의 문서 변수>"` 다. 락은 그 세 파일에 맨 `state-root` 호출이 남지 않았음을 보고(RF `SKILL.md` 의 한 호출은 이유와 함께 이름으로 빠진다), 맨 `state-root` 호출 하나를 다시 넣는 변이에 RED 다.
- AC10 cwd 가 레포 B, 문서가 레포 A 일 때 원장 열기 펜스가 A 의 원장을 열고 공시 줄 하나를 낸다. 이어 결정 줄 펜스가 같은 원장에 쓴다(rc 3 이 아니다, 끝에서 끝). 같은 레포면 공시 줄이 없다. 문서가 git 작업 트리 밖이면 원장 열기가 cwd 뿌리의 원장을 쓰고 공시 줄 하나를 내며, 결정 줄 펜스는 거절하지 않고 같은 원장에 쓰며 같은 git 밖 줄을 낸다(git 밖 픽스처). README 에 request-framing 의 원장 정리 · 지휘자는 cwd 레포 뿌리를 쓰고, 다른 레포의 문서를 리뷰하는 동안에는 cwd 레포의 원장이 그때 정리되지 않는다는 한계가 있다.

**로드맵 생성(§6)**
- AC11 Step A 8 펜스에 넣은 제목 · 승인 원문에 `$` · 역따옴표 · `"` · `'` · 앞 `-` 가 있어도, 임시 레포에서 돈 생성기가 글자 그대로 받는다. B-R 은 「Step A 8 의 명령을 그대로」 다. `test_decompose_surface.sh` 의 Step A 8 리터럴이 새 꼴에 맞다.

**템플릿 · 실행 비트(§7)**
- AC12 두 템플릿의 `source:` 줄에 판 꼬리(`v<숫자>`)가 없다(템플릿을 읽는 기존 테스트에 단언).
- AC13 셸 테스트 넷이 100755 이고 직접 실행해도 통과한다. `run-all.sh` 규칙으로 고른 셸 테스트 전부가 100755 인지 보는 락이 있다. 하나를 100644 로 되돌리는 변이에 RED 이고, 락이 고른 수가 `run-all.sh` 가 고른 수와 같다(양성 대조).

**공통**
- AC14 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고쳤고, 변이로 이빨을 확인했다(변이 전에 커밋). 음의 락에는 양의 짝이 있다. spec-distill 과 quality-gates(공유 러너 · writer 링크)는 머지 시점 기본 브랜치 위의 다음 minor 로 올리고 CHANGELOG 에 적는다. README 에 §2 · §3 · §5 한계가 있다.

## Files to Modify

예약 안(R13): `plugins/spec-distill/scripts/check_brief.py`(문법 공개만, 필요할 때) · `skills/pm-interview/SKILL.md` · `skills/pm-interview/references/finishing.md` · `skills/pm-interview/references/steelman.md` · `skills/request-framing/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/spec-review/SKILL.md`.

예약 밖 — 지휘자가 로드맵 PR 로 R13 경로 예약에 등록한다:

- `plugins/spec-distill/scripts/check_verbatim_coverage.py` · `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` · `plugins/spec-distill/tests/fixtures/`(새 대조 픽스처)(§2)
- `shared/docreview/scripts/nofollow_write.py`(새) · 링크 `plugins/spec-distill/scripts/nofollow_write.py` · `plugins/quality-gates/scripts/nofollow_write.py` · `shared/docreview/scripts/run_docreview_codex_reviewer.sh` · `plugins/spec-distill/scripts/seed_edit_diff.py` · `shared/docreview/scripts/docreview_state.py`(`save_state`) · `shared/tests/test_nofollow_write.sh`(새 — writer 동작 · 공유 러너 겨냥 락 · 배포 링크 단언이 필요하면) · `plugins/spec-distill/tests/test_state_dir_writes.sh`(새, 쓰기 락 · 끝에서 끝)(§3)
- `plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `test_fresh_evidence.sh`(§4)
- `plugins/spec-distill/scripts/state_path.py`(하위 명령 `state-root-for`) · `plugins/spec-distill/tests/test_ledger_root.sh`(새)(§5)
- `plugins/spec-distill/tests/test_decompose_surface.sh`(§6)
- `plugins/spec-distill/templates/interview-audit-template.md` · `interview-brief-template.md` · 템플릿을 읽는 기존 테스트 하나(§7)
- `plugins/spec-distill/tests/test_brief_bundle.sh` · `test_brief_no_length_cap.sh` · `shared/tests/test_docreview_gate_visibility.sh` · `test_entry_preflight.sh`(모드만) · `shared/tests/test_shell_tests_executable.sh`(새)(§7)
- `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md`

## Verification Plan

- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 락은 변이(삭제 · 추가 · 반전 · 형태 변경)로 이빨을 확인하고 양성 대조를 둔다. 변이 전에 커밋한다.
- 링크 픽스처(레포 밖 파일을 가리키는 심볼릭 링크 · 하드 링크)는 격리한 임시 폴더에서만 만든다. 매 실행 뒤 레포 트리가 깨끗한지 확인한다.
- 셸 펜스 · 테스트는 `/bin/bash`(3.2)로 돌린다. `PYTHONDONTWRITEBYTECODE=1`.
- §5 는 임시 레포 둘로 끝에서 끝을 돈다(원장 열기 → 결정 줄).
- 전체 스위트(`bash tools/suite/run-all.sh`) 대조 · qg 테스트 선택이 네 파일을 집는지 확인 · 에픽 사이 통합 리뷰(지휘자).

## Rejected Alternatives

같은 기준으로 견준다 — 막는 힘 · 장치 무게(새 상태 · 명령 · 파일) · 다른 표면과의 이음매.

- `check_brief` 가 state 를 읽어 대조 — 막는 힘은 같고 시점은 이르다. 하지만 임의 brief 에 게이트를 돌리는 불변식이 깨지고, 게이트를 부르는 모든 자리가 state 경로를 알아야 한다.
- finishing Step A 7 에 원문 완전성 검사를 한 번 더 부름 — 시점은 이르다. 하지만 바로 다음 Step A.5 가 같은 검사를 돌려 중복 펜스 · 중복 rc 처리가 생긴다. 시점 한계는 공시로 충분하다.
- 쓰기 자리마다 `[ -L ]` · `[ -f ]` 가드 — 새 파일이 없지만, 확인과 쓰기 사이의 경쟁이 남고 하드 링크를 못 보며 자리마다 사본이 생긴다(Anti-goals).
- `set -C`(noclobber) + 지우고 쓰기 — 장치는 가볍다. 하지만 `: >` 비우기 자리 · `>|` 우회 · 지우기 실패 갈래가 남고, 펜스마다 셸 옵션 상태를 지켜야 한다.
- `docreview_state._write_atomic` 재사용 — 있는 것이지만 `realpath` 로 링크를 따라가 목적과 반대다.
- 기존 `ledger_marker._atomic_write` 를 공개해 import — 공유 러너(quality-gates 에도 실림)가 spec-distill 모듈에 기대게 된다.
- 펜스마다 셸로 문서 폴더를 가려 `state-root <폴더>` 에 넘기기(하위 명령 없음) — 새 표면은 없다. 하지만 펜스마다 대입 꼴(`|| true` · `${ROOT:-…}` · `$PR`/`$SD`)이 달라 「같은 글자의 한 꼴」 을 락이 정의할 수 없고, git 밖 갈래 · 공시 줄이 21곳(RF 제외)에 사본으로 생긴다.
- V1 확인 줄용 새 state 키(`v1_checks:`) — 새 상태다. 「대체됨」 길이 이미 같은 일을 한다.
- 실행 비트 락에 라이브러리 면제 목록 — 목록이 낡는다. `run-all.sh` 의 선택 규칙에서 도출하면 목록이 필요 없다.
- 템플릿 판 꼬리를 지금 판으로 갱신 — 다시 낡고, 읽는 코드가 없어 쓸모도 없다.

## 결정 기록

- U1 · 결정 · 2026-10-21 · 사용자 — 「ok」 (덩어리 1 되비춤 — R13 은 일곱 항목을 다룬다. 4~7 은 R12 와 R10 계획 3 이 넘긴 것이다. 지휘자가 로드맵의 R13 범위와 경로 예약을 그에 맞춰 고친다)
- 원칙 · 2026-10-21 · 사용자 — 「너무 과한 장치와 제약(과설계)만 경계해 devbrew원칙이야」 (이 에픽의 지배 원칙 — 있는 헬퍼 · 인자 먼저, 공용 writer 는 하나까지, 새 상태 · 새 명령 없음)
- 지휘자 판단 · 2026-10-21 · 기본안 일곱:
  - §2 대조는 `check_verbatim_coverage.py` 에 얹고 `check_brief` 불변식은 그대로 · 새 rc 없음 · 시점 한계 공시
  - §3 작은 공용 writer 하나 · 모드 셋 · 세 skill 쓰기 도출 락 · Write 도구 파일은 한계
  - §4 확인 줄은 「대체됨」 길로 · 조사 agent 그대로
  - §5 `state-root <문서 폴더>` · 공시 한 줄 · `state_path.py` 그대로
  - §6 redecompose 꼴 heredoc + `=`
  - §7 판 꼬리 빼기
  - §7 실행 비트 넷 + 도출 락
  - 버전 spec-distill 다음 minor · 계획 하나
- 작성자 판단 · 2026-10-21 · 설계문서 작성(기본안 안에서 다듬음):
  - writer 자리는 `shared/docreview/scripts/` 이고 두 플러그인에 링크한다. 공유 러너가 quality-gates 에도 실려 나가 spec-distill 안에 두면 qg 설치본에서 닿지 않는다. 그래서 quality-gates 도 올린다.
  - `empty` 는 이름 바꾸기를 먼저 하고, 안 되면 `O_NOFOLLOW` 열기 + 일반 파일 · 링크 하나 확인 뒤 자른다. 기존 「못 지우면 절단」 갈래를 살리기 위해서다.
  - `touch` 는 빈 입력 `append` 로 대신한다.
  - 공유 러너의 `write_failclosed`(qg 와 나누는 사본 쌍)는 바꾸지 않고 한계로 공시한다.
  - 쓰기 락의 허용 대상은 이름 목록이 아니라 같은 펜스의 `mktemp` 변수로 도출한다.
  - §5 는 finishing.md 의 두 펜스도 포함한다(같은 원장을 읽는 표면). RF 는 seed 를 cwd 에서 만들어 바꾸지 않고, 락에서 이유와 함께 뺀다.
  - §2 의 「사용자 종료」 는 대상이 아니다. 레코드에 `source` 가 없으면 rc 3, 대상 S 가 state 에 없거나 S1 이면 rc 1 이다. 줄 문법은 `check_brief` 에서 import 한다.
  - §7 실행 비트 락은 `run-all.sh` 선택 규칙에서 도출해 면제 목록이 없다.
- 지휘자 판단 · 2026-10-21 · 설계문서 점검 답 — §2 위반을 고치는 새 자동 장치는 없다. `not_chosen` 은 rc 1 행이라 건너뛸 수 없고, reviewing-brief 는 멈추고 인터뷰로 돌아가 그 질문에 선택지로 다시 답하라고 알린다. 그 뒤는 인터뷰의 보통 흐름이다(조사를 더 원하면 라운드가 이어지고, 닫는 선택지면 새 `chosen` S 로 audit §2 줄 · state `## audit §2 대기 줄` 블록을 다시 쓰고 finishing Step A 를 다시 돈다 — 게이트, 로드맵이 있으면 B-R). 「사용자가 다시 답하지 않음」 은 멈춤 문장이 인터뷰를 가리키는지만 단언한다.
- 지휘자 판단 · 2026-10-21 · 설계문서 점검 답 — README · CHANGELOG 에 한계 둘을 다 남긴다: 시점(리뷰 진입에서 걸린다)과 출처(`source: chosen` 을 포함한 `user_statements` 도 모델이 쓴다 — 대조는 payload · audit 과 state 를 맞출 뿐 사용자가 골랐음을 증명하지 않는다). G1 은 증명을 주장하지 않고, AC3 은 「바꾼다」가 아니라 「더한다」다.
- 지휘자 판단 · 2026-10-21 · 설계문서 점검 답 — 문서 폴더가 git 작업 트리 안일 때만 `state-root` 에 넘기고, 아니면 cwd 뿌리를 쓰고 한 줄로 알린다. AC9 락은 「모든 호출이 문서 폴더 인자를 갖는다」가 아니라 「모든 호출이 하나의 같은 도출을 거친다」다. AC10 에 git 밖 픽스처를 더한다. `ledger_sweep.py` 와 지휘자는 여전히 cwd 레포 뿌리를 정리한다는 한계를 공시한다.
- 지휘자 판단 · 2026-10-21 · 설계문서 점검 답 — 공유 러너는 일반 펜스 파서가 아니라 겨냥한 락을 받는다. 상태 폴더 쓰기 자리(:50 · :67 · :495-498 해당 자리)가 writer 를 거치는지 단언하고, `$SCRATCH`(`mktemp -d`) 대상은 허용, `write_failclosed` 는 이유와 함께 이름으로 뺀다. G2 · AC6 · AC7 이 이것을 그대로 말한다.
- D2.1 · r2 · adopt · 5d1f8fb8#r2.1 · "고친다(채택) — 스크립트 쓰기도 보호 (권장)" — stdout을 안전하게 받아도 호출된 스크립트의 별도 쓰기는 보호되지 않습니다. 실제로 request-framing이 호출하는 seed_edit_diff.py는 기준 사본을 copyfile로 덮어쓰고, .shown·.reverted 파일을 write_text로 씁니다. 여기에 미리 심은 링크는 그대로 따라가므로 상태 폴더 쓰기를 보호한다는 목표가 충족되지 않습니다.
- 지휘자 판단 · 2026-10-21 · spec 리뷰 2라운드 — D2.1 을 skill 이 부르는 스크립트 전부로 적용한다. grep 으로 찾은 둘째 자리 `docreview_state.py` `save_state`(원장 제자리 덮어쓰기 :320 · 시대 표지 :325)도 §3 에 넣는다 — 원장의 제자리 덮어쓰기 성질은 지킨다(`O_NOFOLLOW` 로 열고 일반 파일 · 링크 하나 확인 뒤 자르기). 이 파일은 quality-gates 에도 링크로 실려 나간다.
- 지휘자 판단 · 2026-10-21 · spec 리뷰 2라운드 — 원장 뿌리 도출은 `state_path.py` 에 하위 명령 `state-root-for <문서 경로>` 하나를 더해 모은다(§5). 위 작성자 판단 · 점검 답의 「`state_path.py` 는 그대로」 · 「`state-root` 에 문서 폴더를 넘긴다」를 대체한다. 원장 열기의 정리는 도출된 문서 레포 뿌리를 따르고, 한계는 request-framing 의 정리 · 지휘자만 cwd 뿌리를 쓴다는 것이다.
- 지휘자 판단 · 2026-10-21 · spec 리뷰 2라운드 — 러너 락이 이름으로 빼는 함수는 `write_failclosed` · `_degrade_if_empty` 둘이다(위 「`write_failclosed` 만」을 대체). §2 대조는 레코드의 `source` 로만 판정한다(위 「S1 이면 rc 1」을 대체 — 최초 요청이 없으면 첫 답이 S1 이다). writer 링크는 배포 링크 락(`test_copy_of_contract.sh`)이 잡는다. R8 로 넘기는 두 행은 지휘자가 같은 로드맵 PR 에서 R8 범위에 싣는다.
- U2 · 결정 · 2026-10-21 · 사용자 — 「모두 고친 대로 둠 (권장)」 (spec 리뷰 3라운드 — 2라운드 고침 13곳 채택) · 「열기 — 고치고 한 번 더 본다 (권장)」 (추가 라운드 1회).
- 지휘자 판단 · 2026-10-21 · spec 리뷰 3라운드 — `not_chosen` 되돌아가기는 인터뷰 재진입이 아니라 같은 세션 finishing Step A.5 의 되묻기 갈래다(끝난 인터뷰는 `interview_state.py` 가 이어 가기를 거부한다). 새 포화 줄은 state 대기 줄 블록 한 곳에만 덧붙이고 Step A 가 다시 짓는다. 위 점검 답의 「인터뷰로 돌아가 … 다시 답한다」를 대체한다. 세션을 넘긴 되돌아가기는 한계로 공시한다.
- D3.2 · r3 · adopt · 496041cc#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Rejected Alternatives (modified)
- D3.3 · r3 · adopt · 4ecc2710#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: R13 — R10 남은 인터뷰 게이트 · 엔진 skill 소결함 · Design (modified)
- D3.4 · r3 · adopt · 51d7830c#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: §2 사용자 답 대조 — 원문 완전성 검사에 얹기 (modified)
- D3.5 · r3 · adopt · 5b2b32f2#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: 있는 것 검토 (modified)
- D3.6 · r3 · adopt · 652f36e6#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Non-goals (modified)
- D3.7 · r3 · adopt · 6688c590#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: §5 원장 뿌리 — 문서의 레포에서 (modified)
- D3.8 · r3 · adopt · 6c8b9494#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D3.9 · r3 · adopt · 8e81e781#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Constraints (modified)
- D3.10 · r3 · adopt · 93a5c0ad#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.11 · r3 · adopt · 96a0a3cc#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: 미룸 (modified)
- D3.12 · r3 · adopt · a8a95e6d#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: 번호 대조 (modified)
- D3.13 · r3 · adopt · c6c0ccc8#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Anti-goals (modified)
- D3.14 · r3 · adopt · e09185f8#r3.1 · "모두 고친 대로 둠 (권장)" — finding 없이 바뀜: Goals (modified)

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C25 | 반영 | Constraints · Non-goals — superpowers 파일 · 동작을 건드리지 않음 |
| C32 | 반영 | Anti-goals · `## 있는 것 검토` · §2(있는 검사에 얹음) · §4(있는 옮겨 쓰기 길) · §5(있는 `state_root` 를 부르는 하위 명령 하나) · §6(있는 꼴) |
| C35 | 반영 | Constraints · Non-goals |
| D21 | 반영 | §8 — 원본 brief 위험 가운데 조기 「충분」 선언 · 포화를 가장한 조기 종료 · 사용자 말에 맞추는 경향(§2 로 답), 공유 파일 겹침(계획 하나 · 판 번호 머지 직전). 나머지는 닿지 않음을 적음. 새로 여는 위험 셋에 답함 |
| D26 | 반영 | Constraints — devbrew 쪽(검사 · 펜스 · writer)만 바꿈 |
| S1 | 반영 | Context(묶음 의도의 출처) · G1(경고 없는 생략 대신 막고 이유를 보임) |
| S13 | 반영 | §8 |
| S17 | 반영 | Constraints · Non-goals |
| S18 | 반영 | Constraints |
| S30 | 반영 | Anti-goals · `## 있는 것 검토` · Rejected Alternatives(새 state 키 기각 · 하위 명령은 `state-root-for` 하나) |
| S34 | 반영 | Constraints · Non-goals |
| S49 | 반영 | §1 — 묶음 범위 「한다」 셋(§2 · §3 · §4)을 줄이지 않고, 넘겨받은 넷(§5 · §6 · §7)을 더함 |

## 원칙 · 입력 대조

| 입력 | 자리 |
|---|---|
| CLAUDE.md 기본값과 판단 | §3(writer 이름 · rc 는 계획이 정함) · §9 |
| CLAUDE.md 레포 전용 값 금지 | §3 락(허용 대상 도출) · §5(경로 도출) · §7 락(선택 규칙 도출) |
| CLAUDE.md 상류 · 하류 연계 | `## 상류 · 하류 연계` |
| CLAUDE.md 진입점에서 따라 내려가기 | §2(rc 표 `not_chosen` 행 → finishing Step A.5 되묻기 갈래) · §5(공시 줄) |
| CLAUDE.md 있는 것 먼저 | `## 있는 것 검토` |
| CLAUDE.md 공시와 차단 · 강등 공시 | §2(검사 불가 rc 3) · §3(거부 사유) · README 한계 |
| 과설계 경계 원칙(사용자 원문) | Anti-goals · §3(writer 하나) · Rejected Alternatives |
| U1 일곱 항목 | §1 |
| R10 미룸 :401 | §2 |
| R10 미룸 :402 | §3 |
| R10 미룸 :403 | §4 |
| R12 미룸 :449 | §1(이미 고침 — 68a41ab5) |
| R12 미룸 :450 | §5 |
| R12 미룸 :451 | §6 |
| PR #239 넘김 — 템플릿 판 꼬리 | §7 |
| PR #239 넘김 — 100644 셸 테스트 | §7(넘김의 둘 + recon 이 찾은 shared 둘) |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| Write 도구로 상태 폴더에 쓰는 파일(`said-*.txt` · `readback.txt`)의 링크 따라가기 | 셸 쓰기가 아니라 writer 로 감쌀 수 없다. 하니스 도구 층의 엔진 밖 쓰기라 권한 경계 몫이다 | R8 |
| 실행 중 다시 심는 링크(같은 사용자의 경쟁) · `runner_common.sh` `write_failclosed` · `_degrade_if_empty` 의 맨 넘기기 | writer 는 미리 심은 링크만 막는다. 그 밖은 같은 사용자 권한의 경계라 권한 경계 몫이다 | R8 |

R8 행 둘은 지휘자가 R13 의 범위 · 경로 예약을 고치는 같은 로드맵 PR 에서 로드맵 R8 범위에 등록한다(사용자가 승인한 재분해).

## 지휘 기록

- 2026-10-21 · 읽기 전용 조사로 일곱 항목의 자리를 602931e8 에서 확인했다(기록 `~/.claude/sdd-mirror/epic-decisions/r13/recon.md`). 덩어리 1 되비춤에 사용자 「ok」(U1).
- 2026-10-21 · 설계문서는 하위 agent 가 기본안(지휘자 판단) 안에서 썼다. 기본안 밖의 다듬음은 `## 결정 기록` 「작성자 판단」 에 있다.

## Metadata

- 에픽: R13 · 브랜치 `feature/interview-gate-leftovers` · 묶음 `R13.md`
- 크기: 계획 하나(§9)
- 의존: R10 · R12(머지됨). 뒤에 R8.
- 버전: spec-distill · quality-gates 를 머지 시점 기본 브랜치 위의 다음 minor 로 올린다(지금 main 기준 8.4.0 → 8.5.0 · 14.3.0 → 14.4.0). 번호는 머지 직전에 정한다.

### Deferred to plan

- writer 의 이름 · 자기 실패 rc(감싸는 명령들의 rc 표에서 비는 값) · `printf` 자리를 `run` 으로 감쌀지 stdin 으로 넘길지.
- `check_brief` 문법을 공개 함수 하나로 묶을지, 정규식 · 절 읽기를 그대로 import 할지.
- 쓰기 락의 파서 — 실제 셸 파서(`bash -n`)와 교차 확인할 자리. 줄 이음 · heredoc 본문 건너뛰기.
- 정상 흐름에서 상태 폴더 파일의 링크 수가 1 인지 실측(§8 첫 위험).
- 배포 링크 락 `shared/tests/test_copy_of_contract.sh` 의 도출(:312-326)이 writer 의 두 링크를 집는지 — 못 집으면 writer 테스트에 단언을 더한다.
- `seed_edit_diff.py` · `docreview_state.py` 가 writer 의 함수를 import 할지 그 몇 줄을 둘지.
