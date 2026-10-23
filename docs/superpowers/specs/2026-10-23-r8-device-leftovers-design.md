---
name: r8-device-leftovers
type: design
created_at: 2026-10-23
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R14.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R14 — R8 남은 장치 결함 · Design

> R8 의 리뷰가 남긴 장치 쪽 결함 열 줄을 닫는다 — 에픽 PR 번호를 적어 그 번호로 머지를 판정하는 길 하나만 새로 만들고, 나머지는 있는 검사에 한 줄씩 더하거나 사람을 헷갈리게 하는 것만 고친다.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Anti-goals](#anti-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 범위](#1-범위)
  - [§2 에픽 PR 번호 — 적고, 번호로 머지를 판정한다](#2-에픽-pr-번호--적고-번호로-머지를-판정한다)
  - [§3 쓰는 세션을 믿는 한계 공시 — 쉬운 말로](#3-쓰는-세션을-믿는-한계-공시--쉬운-말로)
  - [§4 골든 예약과 락 지도 단언](#4-골든-예약과-락-지도-단언)
  - [§5 해결자 · 원장의 거부 셋](#5-해결자--원장의-거부-셋)
  - [§6 인터뷰 다음 세션의 superpowers 판 확인](#6-인터뷰-다음-세션의-superpowers-판-확인)
  - [§7 작은 빈틈 — 고침 · 안 고침](#7-작은-빈틈--고침--안-고침)
  - [§8 위험에 대한 답](#8-위험에-대한-답)
  - [§9 계획 · 병렬](#9-계획--병렬)
  - [§10 조사 — 빠진 항목 · 지금 코드 재확인](#10-조사--빠진-항목--지금-코드-재확인)
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

묶음 R14 의 의도는 「R8 의 리뷰가 남긴 장치 쪽 결함을 고친다」다. 받는 것은 R8 설계문서(`docs/superpowers/specs/2026-10-20-dependency-portability-design.md`) `## 미룸` 의 받는 곳 R14 행 열이다. 설계 대화의 덩어리 1 되비춤(열 항목)을 사용자가 승인했다(U1). 여덟째 항목(같은 이름의 옛 브랜치 틈)은 사용자가 「PR 번호를 적는 길」을 골라 범위가 넓어졌다(U2 · U3) — 로드맵 R14 의 「안 한다: 새 기능」을 이 결정에 맞춰 고친다(재분해, `## 결정 기록`).

지금 레포에서 확인한 것(origin/main ad7efbb6, `plugins/spec-distill` = SD):

1. **머지 판정과 PR 캐시.** 머지됨 판정은 `SD/scripts/roadmap_status.py` `compute` 의 `judge` 가 브랜치마다 한다. 순서는 R8 U17 대로 머지 커밋 근거(`merged_by_tips`, 나이 검사 `age_ok`) → PR 캐시(`_judge_pr` 여섯 조건) → 캐시에 그 브랜치 줄이 없으면 `merged_by_git`(머지 커밋 · 이 레포 소유자의 머지 문면)이다. PR 캐시는 기계 상태(`machine.md`) `## PR` 절이고, 줄은 **브랜치 이름으로** 묶인다(칸: 브랜치 · 번호 · 상태 · 확인한 때 · headRefOid · 교차 레포 · baseRefName · mergeCommit · 쓴 세션 — `SD/scripts/conductor_state.py` `SECTIONS`). 캐시를 채우는 것은 `ledger pr-refresh`(`SD/scripts/conductor_ledger.py` `c_pr_refresh`) 하나이고, `gh pr list --head <브랜치> --state all` 로 그 head 이름의 PR 을 모두 받는다. 번호는 캐시에 있지만 이름으로 찾은 것이다 — 에픽과 PR 사이를 잇는 유일한 열쇠가 브랜치 이름이다.
2. **PR 을 여는 자리.** 지휘 절차 `SD/references/conducting.md` 의 걸음 4(구현 agent 가 돌아온 뒤)와 손 절차 5 가 `gh pr create -R "$(python3 "<SD>"/scripts/gh_repo.py slug)"` 로 PR 을 열고 `ledger pr-refresh --epic <에픽>` 으로 캐시를 채운다. PR 캐시를 손으로 적는 `ledger add … --section PR` 은 지금 절차에 없고, `SD/tests/test_conducting_reference.sh` 의 `pr_by_hand` 락이 그것을 막는다.
3. **옛 꼴.** 이 레포의 지휘 기계 상태(`.claude/spec-distill/conductor/<로드맵>/machine.md`)의 PR 절은 지금 옛 판의 4칸 줄이다 — 「R8 · #252 · 머지됨 · 2026-10-23」(에픽 · 번호 · 상태 · 날짜). 옛 지휘 절차가 PR 을 연 뒤 손으로 적던 꼴로, 에픽과 번호를 직접 이었다. 지금 판은 이 줄을 거부하고(`OldPrRows`) `pr-refresh --reset` 을 안내한다. 사용자가 고른 길은 그 「에픽 · 번호」 고리를 기계가 쓰는 꼴로 되살리는 것이다.
4. **남은 틈.** R8 미룸 행 「같은 이름의 옛 브랜치를 나이로 거르지 못하는 틈」 — 견줄 커밋이 없거나 옛 머지가 이 에픽의 문서보다 뒤면 옛 원격 ref(또는 끝 없는 판정의 옛 MERGED PR)가 거짓 머지됨을 만든다(틈 ①). 거꾸로, 문서가 첫 머지보다 뒤에 들어온 에픽은 로컬 브랜치가 없으면 머지됨이 아니고, `diff.renameLimit` 을 넘는 커밋이면 머지된 에픽이 빠질 수 있다(틈 ②). 둘 다 이름 · 이력 추정의 한계다.
5. **공시 문장.** `shared/docreview/scripts/docreview_state.py` 의 `WRITER_TRUST_NOTICE` 는 「사용자 문구와 원장은 이 세션이 쓴 것이다 — 엔진은 엔진 밖에서 고친 원장 중 요약값이 안 맞는 것만 잡는다」 다. `render_gate` 셋째 줄 · `gate` JSON 의 `writer_trust_notice` · SD `README.md` `## 한계` 첫 줄 · 골든 다섯(`shared/tests/fixtures/docreview/golden/*.gate.txt` 셋째 줄 · `*.gate.json`) · `shared/tests/test_writer_trust_notice.sh` 의 `EXPECTED` 가 같은 글자다. 렌더 둘째 줄은 같은 대상을 이미 「원장 확인값」 이라 부른다.
6. **골든 예약 충돌.** R12(머지됨)가 `shared/tests/fixtures/docreview/` 를 예약했고, 락 지도(`…/locks.md`)에 골든 두 줄(`case_T05_T06_reject.gate.txt:2` · `case_T11_permit_keeps_disposition.gate.txt:2`, 바꿀 에픽 R12)이 있다. `SD/tests/test_roadmap_status.sh` 의 실데이터 단언 `lock_rows` 는 「줄의 에픽이 아닌 다른 에픽이 그 파일을 예약했으면 위반」 이라, R14 가 골든 폴더를 예약하면 두 줄이 위반이 된다(#253 커밋 메시지가 이 이유로 골든을 예약하지 않았다). 이 단언은 git 없이 함수로 잰다(「origin 이 없는 클론에서도 같은 판정」 — 테스트 주석).
7. **해결자 · 원장.** `SD/scripts/repo_defaults.py` `strict_frontmatter` 는 콜론 없는 최상위 줄을 `continue` 로 건너뛴다. 폴더 키 검사 `_folder` 는 루트 · `.git` · `..` 만 막아 글롭 · pathspec 특수 글자가 `ls-tree`(`conductor_ledger._default_roadmaps` · `control_plane` 의 로드맵 목록) · `git grep` 범위(`roadmap_status.Git.grep_files`) · spec-review 후보 목록(`SD/skills/spec-review/SKILL.md` 의 `-- "${SPECS}*-design.md"` — 여기서는 `*` 가 일부러 쓰인 글롭이다)에 그대로 닿는다. `ledger add`(`c_add`)는 `--section "레포 설정"` 에 같은 키 둘을 받고, 읽는 쪽(`conductor_state.repo_settings_rows`)은 그 상태를 거부한다.
8. **인터뷰 다음 세션.** `SD/skills/pm-interview/references/finishing.md` B-1 은 이 세션이 superpowers skill 을 불러오지 않았으면 「알 수 없음 — …(판은 다음 세션에서)」 한 줄만 쓴다. 다음 세션 줄(B-3 「다음 세션 줄 — ①/② 공통」)에는 판 확인 지시가 없다. 그 줄은 `SD/tests/test_review_handoff_order.sh` 가 머리 · 순서 · 포함 문장 · 「줄 안 꺾쇠 자리표는 줄 앞 `@<…>` 이름뿐」(`lead_only`)으로 잡는다. 판 확인 명령은 이미 있다 — `check_deps.py superpowers --plugin-root <루트> --base <기준 폴더>`(늘 rc 0, 알리기만).
9. **작은 빈틈.** 묶음 범위의 「동작 빈틈 여섯」 · 「문구 · 테스트 빈틈 열아홉」 의 자리는 R8 계획 1 진행 기록(`~/.claude/sdd-mirror/r8-plan1/sdd-workspace.tgz` 의 `progress.md` deferred 줄)으로 확인했다. 정적 락 후보 여덟은 같은 테스트의 행동 검사(읽기 전용 파일 시스템 · git/gh 기록 stub · 실행 전후 비교)가 쓰기와 git · gh 호출을 잡는다. `put_snap`(`shared/tests/fixtures/docreview/cases.sh`)은 `$(...)` 안에서 불려 실패 수가 서브셸에서 사라진다.

## Goals

- G1 지휘자가 연 에픽 PR 은 열 때 번호가 기계 상태에 적히고, 그 브랜치의 머지됨은 그 번호의 PR 하나로만 판정된다 — 이름 · 이력 추정을 쓰지 않는다. 번호가 없는 브랜치는 지금과 같고, 틈 ① · ② 가 번호 없는 에픽에만 남는다는 것을 알린다.
- G2 쓰는 세션을 믿는 한계 공시가 사람이 읽는 말로 README 와 렌더 셋째 줄에 같은 글자로 있다.
- G3 쓰는 쪽이 읽는 쪽이 거부할 값을 받지 않는다 — 콜론 없는 머리말 줄 · 폴더 값의 특수 글자 · 레포 설정의 같은 키 둘은 쓰거나 읽는 그 자리에서 이유와 함께 멈춘다.
- G4 인터뷰 뒤 brainstorming 을 부르는 세션이 superpowers 판을 확인한다.
- G5 작은 빈틈 가운데 사람을 헷갈리게 하거나 실제 결함을 통과시키는 것만 고치고, 나머지는 이유와 함께 닫는다.
- G6 R12 가 끝낸 골든을 R14 가 예약할 수 있고, 진행 중 에픽 사이의 락 지도 검사는 약해지지 않는다.

## Non-goals

- 규칙 · 철학 문서(R9). R14 는 R9 가 실을 규칙 문장만 넘긴다(`## 상류 · 하류 연계`).
- R8 이 정한 판정 순서(U17) · 여섯 조건 · 나이 검사 바꾸기 — 번호 없는 브랜치에서는 그대로다.
- 번호를 git 이 추적하는 파일에 남기기(다른 기계 · 새 클론으로 옮기기) — 사용자 결정 U8 「이 기계에만 둔다 (권장)」, Rejected Alternatives.
- 옛 4칸 PR 줄 옮기기 · 머지된 에픽에 번호 채우기 — 머지된 에픽은 지금 판정으로 이미 머지됨이다.
- 게이트 질문 글에 공시 싣기(U5).
- cost_class high skill 의 승인 게이트(`AskUserQuestion`)를 고치거나 지우기 — R9 몫이다(R9 결정, `## 상류 · 하류 연계`).
- superpowers 의 파일 · 동작(C25 · C35 · D26).

## Anti-goals

- 작은 빈틈마다 새 장치를 다는 것 — 고침은 있는 검사 · 메시지 · 테스트에 한 줄씩이다(과설계 경계 원칙).
- 새 상태 파일 · 새 캐시. 새로 만드는 것은 기계 상태의 선택 절 하나(`## 에픽 PR`)와 `ledger` 하위 명령 하나(`pr-record`), `gh_repo.py` 도우미 하나뿐이다.
- 정적 락을 행동 층이 이미 잡는 길까지 조이는 것.

## Constraints

- C25 · C35 · D26 — 외부 플러그인은 건드리지 않는다. superpowers 판 확인은 devbrew 가 넘기는 글(다음 세션 줄)에만 싣는다.
- C32 — 원래 있는 것을 다시 만들지 않는다(`## 있는 것 검토`).
- D21 — §8 이 원본 brief 의 위험 가운데 이 에픽에 닿는 것과 이 설계가 새로 여는 위험에 답한다.
- CLAUDE.md — 기본값과 판단 · 레포 전용 값 금지 · 상류 · 하류 연계 · 진입점에서 따라 내려가기 · 있는 것 먼저 · 공시와 차단 · 마크다운 상태.
- R8 AC17 — 상태 계산(`roadmap_status`) · 상태줄(`control_plane`)은 gh 를 부르지 않는다. 번호 판정도 캐시만 읽는다.
- 셸 펜스와 셸 테스트는 macOS bash 3.2 에서 돈다. 새 · 바뀐 셸 테스트는 100755 다.
- 경로 예약 — R14 예약 밖 파일은 `## Files to Modify` 에 적고 이 브랜치의 로드맵 커밋으로 등록한다. 골든 폴더는 §4 의 단언 변경과 같은 PR 에서 등록한다.

## 설계

### §1 범위

| # | 항목 | 출처(R8 설계 `## 미룸`) | 자리 |
|---|---|---|---|
| 1 | `strict_frontmatter` 콜론 없는 줄 | 해결자 줄 규칙 행 | §5 |
| 2 | 폴더 값의 글롭 · pathspec 특수 글자 | pathspec 행 | §5 |
| 3 | `ledger add --section "레포 설정"` 같은 키 둘 | ledger add 행 | §5 |
| 4 | 인터뷰 다음 세션의 superpowers 판 확인 | superpowers 판 행 | §6 |
| 5 | 계획 1 리뷰의 작은 동작 빈틈 여섯 | 동작 빈틈 행 | §7 |
| 6 | 계획 1 리뷰의 작은 문구 · 테스트 빈틈 열아홉 | 문구 · 테스트 빈틈 행 | §7 |
| 7 | 상태 계산 읽기 전용 정적 락 후보 여덟 | 정적 락 행 | §7 |
| 8 | 같은 이름의 옛 브랜치를 나이로 거르지 못하는 틈 | 옛 브랜치 틈 행 | §2 |
| 9 | 쓰는 세션을 믿는 한계 공시의 문면 · 전달 | 공시 문면 행 | §3 · §4 |
| 10 | `put_snap` 서브셸 실패 수 | `put_snap` 행 | §7 |

### §2 에픽 PR 번호 — 적고, 번호로 머지를 판정한다

번호는 PR 마다 하나뿐이라 이름 · 이력 추정의 틈이 생기지 않는다(U2 · U3). 번호를 쓰는 곳 · 운반하는 곳 · 읽는 곳을 따라 적는다.

**쓰는 곳 — PR 을 열 때.**

- 기계 상태에 선택 절 `## 에픽 PR` 을 더한다 — 칸: 에픽 · 브랜치 · 번호 · 적은 때 · 쓴 세션. `conductor_state.OPTIONAL_SECTIONS` 에 들어 줄이 없으면 머리를 쓰지 않는다(이 절을 모르는 옛 판도 파일을 읽는다). 줄 검사: 번호는 `#<숫자>`, 에픽은 로드맵 블록 번호 꼴, 같은 (에픽, 브랜치) 는 한 줄.
- 새 명령 `ledger pr-record --roadmap R --session S --epic E --pr <PR>` 이 그 절에 쓴다. `<PR>` 은 `gh pr create` 가 낸 PR URL · `<숫자>` 를 받는다. `#<숫자>` 도 받지만 셸에서 맨 `#` 은 주석의 시작이라 따옴표로 감싸야 한다(`--pr '#123'`) — 사람에게 보이는 명령 예시는 모두 숫자만 쓴다(`--pr 123`).
  - 표지를 쥔 세션만 쓴다(`need_holder` — 기계 상태 쓰기 규칙 그대로).
  - URL 이면 호스트 · owner · repo 가 `gh_repo.origin_slug` 와 같아야 한다.
  - 번호로 PR 을 묻는다 — `gh_repo` 에 `pr_view(cwd, number)`(`gh pr view <N> -R <origin> --json <PR_FIELDS>`)를 더한다.
  - 그 PR 의 `headRefName` 이 그 에픽 블록의 브랜치(로드맵 사본이 더한 브랜치 포함 — `pr-refresh --epic` 과 같은 블록 해석) 가운데 하나이고, `isCrossRepository` 가 거짓이고, `baseRefName` 이 기본 브랜치여야 적는다. 하나라도 어긋나면 아무것도 쓰지 않고 rc 4 와 어긋난 칸을 보인다 — 번호를 잘못 옮겨 적는 실수가 쓰는 자리에서 잡힌다. 번호를 못 읽으면 rc 2.
  - 같은 (에픽, 브랜치) 줄이 있으면 새 번호로 바꾼다(닫고 새로 연 PR).
  - 번호를 적을 때 이미 받은 그 PR 로 `## PR` 캐시 줄도 함께 쓴다(`_cache_row` 꼴 — 같은 번호의 옛 줄은 바꾼다). 그래서 이미 머지된 PR 을 적어도 다음 `pr-refresh` 전까지 「캐시에 그 번호가 없다」(판정 없음)로 떨어지지 않고 바로 번호로 판정된다.
  - `--drop` 이면 gh 를 묻지 않고 그 에픽의 `--pr` 번호 줄을 지운다(그 브랜치는 번호 없는 브랜치로 돌아간다). 없는 줄이면 rc 1.
- 지휘 절차 걸음 4 와 손 절차 5 는 `gh pr create -R …` 의 출력(PR URL)을 받아 `ledger pr-record … --epic <에픽> --pr <그 URL>` 을 부른 **뒤** `ledger pr-refresh … --epic <에픽>` 을 부른다. PR 이 이미 있어 `gh pr create` 가 실패하면 그 PR 의 번호를 `--pr <번호>` 로 적는다 — 판단은 지휘자가 하고 이유를 보인다. 앞 계획의 브랜치를 base 로 연 쌓인 PR(stacked PR)은 base 가 기본 브랜치가 아니라 `pr-record` 가 rc 4 로 거부한다 — 이때의 rc 4 는 예상된 결과이지 멈출 오류가 아니다. 지휘자는 적지 않고 넘어가고, 걸음 5 가 그 PR 의 바탕(base)을 기본 브랜치로 바꾼 직후 · 머지 명령을 준비하기 전에 `ledger pr-record --epic <에픽> --pr <번호>` 를 부른다(U9). conducting.md 걸음 4 · 5 와 손 절차 5 의 문장이 이것을 그대로 말한다.
- **번호를 적는 자리는 둘뿐이다(U9).** (가) 걸음 4 · 손 절차 5 — 지휘자가 기본 브랜치를 바탕으로 PR 을 연 직후. (나) 쌓인 PR — 걸음 5 가 바탕을 기본 브랜치로 바꾼 직후, 머지 명령을 준비하기 전. 그 밖의 PR(손으로 연 PR · 이 판 전에 열린 PR — R9 의 PR 등)은 지휘 세션이 `ledger pr-record` 를 한 번 부른다. 자동으로 찾아 적는 길은 없다. PR 캐시를 손으로 적는 `ledger add --section PR` 금지(`pr_by_hand` 락)는 그대로다 — `pr-record` 는 검증하고 쓰는 명령이지 손 적기가 아니다.

**운반하는 곳 — PR 캐시.**

- `pr-refresh` 는 블록의 브랜치마다 지금처럼 head 이름의 PR 을 모두 받고, 그 브랜치에 적은 번호가 있으면 그 번호를 `pr_view` 로 따로 받아 `## PR` 에 그 줄을 둔다(head 목록이 한도에 닿아 빠져도 번호 줄은 있다).
- **적은 번호가 그 브랜치와 더는 맞지 않으면**(head 이름이 바뀜 · 다른 head · 교차 레포가 됨) `pr-refresh` 는 전체를 멈추지 않는다(지휘자 판단(사용자 결정 아님)). 그 브랜치에서는 `## PR` 의 #N 줄 하나만 지운다 — 앞서 맞던 #N 줄이 남아 있으면 그것도 지운다. `## 에픽 PR` 의 번호 기록과 그 브랜치의 다른 PR 줄은 그대로 둔다. 그리고 경고 한 줄을 보인다 — 「적은 PR #N 이 <브랜치> 와 맞지 않는다(<어긋난 칸>: <기대 값> ≠ <gh 값>) — 이 에픽의 PR 이면 `ledger pr-record --epic <에픽> --pr <번호>` 로 다시 적고, 아니면 `ledger pr-record --epic <에픽> --pr <N 의 숫자> --drop`」. 상태 계산은 아래 「캐시에 그 번호가 없다」 갈래로 가서 그 브랜치를 「판정 없음」으로 둔다. 캐시가 바뀌었으므로 상태줄 지문도 바뀐다. 다른 브랜치는 그대로 채운다(지휘자 판단(사용자 결정 아님)). 종료 코드는 그 경고가 있어도 0 이다(경고 줄이 할 일을 싣는다).
- 그 밖의 `pr-refresh` 동작(어느 블록의 브랜치를 묻는지 · 끝난 블록을 건너뛰는지)은 지금 그대로다 — 더하는 것은 적은 번호의 따로 받기와 위 어긋남 갈래뿐이다.
- `--reset` 은 `## PR` 만 비운다. `## 에픽 PR` 은 다시 만들 수 없는 기록이라 남긴다.
- **걸음 7 정리도 `## 에픽 PR` 을 남긴다(지휘자 판단(사용자 결정 아님)).** 로드맵 끝에 conducting.md 걸음 7 이 기계 상태를 정리할 때 `## 에픽 PR` 은 지우지 않는다 — 다시 만들 수 없는 기록이고, 정리 뒤 상태 계산이 머지된 에픽을 다시 이름 · 이력 추정으로 돌리지 않게 한다.
- `control_plane.pr_cache_fingerprint` 는 `## 에픽 PR` 줄도 지문에 넣는다 — 번호를 적으면 상태줄 · 상태 보기가 바로 새 판정을 낸다.

**읽는 곳 — 상태 계산.**

- `roadmap_status.read_pr_cache` 가 `## PR` 과 함께 `## 에픽 PR` 줄을 돌려준다(같은 파일 한 번 읽기, gh 없음).
- `judge(br, block)` 은 (블록 번호, 브랜치) 에 적은 번호 N 이 있으면 **그 길만** 탄다. `merged_by_tips` · `age_ok` · `_judge_pr` 의 끝 대조 · `merged_by_git` 은 부르지 않는다.
  - 캐시에 브랜치 == br ∧ 번호 == #N 인 줄이 없으면 판정 없음 + 「PR #N 이 PR 캐시에 없다 — 지휘자를 돌려 캐시를 채운다」 정보 줄(지금의 「PR 상태 미확인」 과 같은 무게).
  - 그 줄이 상태 머지됨 ∧ 교차 레포 아니오 ∧ baseRefName == 기본 브랜치이고 mergeCommit 이 기본 ref 에서 닿으면 머지됨 — 근거 「PR #N 머지됨(적은 번호로 판정 · mergeCommit <8자>)」.
  - mergeCommit 이 `-` 면 지금처럼 머지됨으로 세지 않고 알린다. 닿지 않으면 「머지됨(받기 전)」 경고 — 머지됨이 아니다(R8 §4 그대로).
  - 그 밖(열림 · 닫힘 · 다른 base · 교차 레포)은 머지됨이 아니다.
  - 적은 PR 이 머지되지 않았는데 같은 브랜치의 다른 줄이 머지됨(교차 아님 · 기본 base)이면 경고 한 줄 — 「적은 PR #N 은 <상태>이고 같은 브랜치의 PR #M 이 머지됐다 — 그 PR 이 이 에픽의 PR 이면 `ledger pr-record --epic <에픽> --pr <M 의 숫자>`」. 판정은 바꾸지 않는다(닫고 새로 연 PR 을 적지 않은 경우가 사람에게 보인다).
  - 머지됨인데 브랜치 끝(로컬 · 원격 가운데 있는 것)이 그 PR 캐시 줄의 `headRefOid` 와 다르면 정보 줄 「머지 뒤 브랜치에 커밋이 더 붙었다(<끝 8자> ≠ PR 의 head <8자> — 번호 판정은 그대로)」(지휘자 판단(사용자 결정 아님)). squash · rebase 머지는 끝이 기본 브랜치의 조상이 아니어도 끝 == `headRefOid` 라 이 줄이 나지 않는다. 끝이 없으면 줄도 없다.
  - 머지 뒤 되돌림 경고(`reverts_of`) · 결정 기록 손 머지 줄을 적용하지 않는다는 경고는 지금 PR 판정 길과 같다.
- 번호가 없는 브랜치는 지금 길 그대로다(U17 순서 · 나이 검사 · 여섯 조건 · `merged_by_git`).

**보이는 곳 — 한 출처(지휘자 판단(사용자 결정 아님)).** 적은 번호가 있는 브랜치는 그 에픽의 PR 을 보이거나 쓰는 모든 표면이 이름으로 고른 줄이 아니라 적은 번호의 줄을 쓴다. 번호 없는 브랜치는 지금 그대로다.

| 표면 | 지금 | 바뀜 |
|---|---|---|
| `control_plane.pr_fact`(「PR #N 열림」 단계 · 보이는 번호) | 브랜치 이름의 캐시 줄에서 고른다 | 적은 번호의 줄 — 없으면 「PR #N 캐시에 없음」 |
| `control_plane.merged_prs` | 브랜치 이름으로 머지된 줄을 모은다 | 적은 번호의 줄이 머지됐을 때만 |
| `ledger pr-handoffs`(`c_pr_handoffs` · `_prs`) | head 이름의 PR 목록 본문에서 인계 절을 읽는다 | 적은 번호의 PR 하나를 번호로 물어(`gh pr view <N> --json number,state,body`) 읽는다 |
| `ledger audit` · `ledger review-pack`(둘 다 `_prs`) | head 이름의 PR 목록 | 적은 번호의 PR 하나만 — `pr-handoffs` 와 같다 |
| `control_plane.pr_cache_fingerprint` | `## PR` 줄 | `## PR` + `## 에픽 PR` 줄(따로 AC6 이 잰다) |
| `roadmap_status.judge` | 위 「읽는 곳」 | 위 「읽는 곳」 |

같은 갈래(적은 번호 있음 / 없음)를 표면마다 다시 짓지 않게, `conductor_state` 에 둘을 둔다(이름은 계획이 정한다) — 「(에픽, 브랜치) → 적은 번호」 찾기와, 그것을 써서 「(에픽, 브랜치) → 적은 번호의 캐시 줄 | 없음 사유」 를 내는 함수. 브랜치마다 PR 줄을 고르는 세 자리 `pr_fact` · `merged_prs` · `judge` 가 뒤 함수를 부른다. `pr-handoffs` · `audit` · `review-pack` 은 캐시 줄이 아니라 번호가 필요해 앞의 찾기를 쓴다(셋 다 `_prs` 를 지나므로 그 한 자리에서 갈린다). 지문은 줄을 고르지 않고 절 둘을 통째로 넣는다(지휘자 판단(사용자 결정 아님)).

**공시.** `roadmap_status.NOTICE` 와 SD README 상태 계산 줄에 한 문장을 더한다 — 「지휘자가 PR 을 열 때 번호를 적은 에픽은 그 PR 로만 머지를 판정한다. 번호가 없는 에픽(이 판 전에 연 PR · 지휘자 밖에서 연 PR · 번호 기록이 없는 다른 기계)은 브랜치 이름과 이력으로 알아보며, 같은 이름의 옛 브랜치가 머지됨으로 보이거나 머지된 에픽이 빠지는 틈이 남는다.」 번호 기록은 기계 상태라 이 기계에만 있다는 사실도 같은 문장에 든다.

**README `## 한계` 두 줄(U8).** 번호 기록은 이 기계에만 둔다. 사용자가 고른 선택지의 약속대로 SD README `## 한계` 에 두 줄을 더한다(첫 줄 공시 뒤 불릿):

- 「에픽 PR 번호 기록은 이 기계의 지휘 기계 상태에만 있다 — 다른 기계나 새 클론에서는 머지 판정이 브랜치 이름과 이력 추정으로 돌아가고, 같은 이름의 옛 브랜치 틈이 다시 열린다.」
- 「지휘자가 연 PR 은 열 때(쌓아 연 PR 은 바탕을 기본 브랜치로 바꾼 직후) 번호가 적힌다. 그 밖의 PR(손으로 연 PR · 이 판 전에 연 PR)은 지휘 세션에서 `ledger pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <번호>` 를 한 번 부르면 된다(번호는 숫자만) — 그 명령이 PR 캐시 줄까지 써서 바로 그 번호로 판정된다. 적기 전까지 그 PR 의 에픽은 브랜치 이름과 이력으로 판정된다. 쓰기는 지휘 표지를 쥔 세션만 한다.」

### §3 쓰는 세션을 믿는 한계 공시 — 쉬운 말로

- 새 `WRITER_TRUST_NOTICE`:

  > 리뷰 기록과 그 안의 사용자 말은 이 대화가 직접 쓴다 — 기록을 리뷰 명령 밖에서 고치면 확인값이 안 맞는 경우만 잡히고, 확인값까지 맞춰 그럴듯하게 고친 것은 잡히지 않는다

  사용자가 동의한 예시 꼴(U5 근거 대화의 「리뷰 기록은 이 대화가 직접 쓴다 — 기록을 엔진 밖에서 고치면 숫자가 안 맞는 경우만 잡히고, 그럴듯하게 고친 것은 잡히지 않는다」)에서 셋을 다듬었다(작성자 판단). 「엔진」 → 「리뷰 명령」. 「숫자」 → 「확인값」 — 렌더 둘째 줄이 같은 대상을 이미 「확인값」 이라 부르고, 실제 값은 숫자가 아니라 해시다. 「그 안의 사용자 말」 — 옛 문장의 「사용자 문구」 몫이고, README 둘째 불릿(`--quote` 출처)이 「위 공시로 다룬다」 고 기대는 자리다. 원장 · 엔진 · 요약값은 문장에 없다.
- 자리는 그대로 둘이다 — 렌더 셋째 줄(+ `gate` JSON `writer_trust_notice`)과 SD README `## 한계` 첫 줄. 게이트 질문 글(`AskUserQuestion`)에는 싣지 않는다(U5 — 되풀이되는 경고는 무시된다).
- README `## 한계` 에서 공시 바로 뒤의 세 불릿(「위 공시로 다룬다」 가 가리키는 자리)을 같은 쉬운 말(리뷰 기록 · 리뷰 명령)로 고친다 — 뜻은 그대로다:
  - 「샌드박스를 쓰는 사용자는 리뷰 기록 폴더(상태 폴더의 `.docreview/`) 쓰기를 막을 수 있다 — 막아도 리뷰 명령은 같은 폴더를 쓰므로 리뷰 명령도 함께 막힌다.」
  - 「`--quote-file` · `log-decision --quote` · `decide --quote` 로 받은 문구의 출처와 제목 하나 빠진 audit 도 위 공시로 다룬다 — 리뷰 명령은 그 문구가 사용자 말인지 확인하지 않는다.」
  - 「`declare-related` · `log-decision` 이 표지 확인 없이 불리거나 리뷰 명령을 거치지 않고 리뷰 기록을 쓰는 길도 위 공시로 다룬다 — 리뷰 명령은 그런 쓰기를 거부하지 않는다.」

  `test_writer_trust_notice.sh` 가 글 그대로 잡는 두 줄(샌드박스 줄 · `declare-related` 줄)의 기대값도 함께 바꾼다(인용 출처 줄은 앞부분만 잡아 그대로 통과한다). 나머지 불릿(P21 · P14)과 §2 의 U8 두 줄은 이 바꿈과 무관하다.
- 같이 바뀌는 것: 골든 다섯의 셋째 줄과 `.gate.json`, `test_writer_trust_notice.sh` 의 `EXPECTED`. CHANGELOG 의 옛 문장 · R8 설계 §7 의 인용은 이력이라 그대로 둔다.

### §4 골든 예약과 락 지도 단언

- 지휘자 판단: 머지된 에픽은 끝났다 — 그 에픽의 예약과 락 지도 줄이 다른 에픽의 예약을 막지 않게 실데이터 단언을 고치고, 그 뒤 골든 폴더를 R14 에 예약한다.
- 실현(작성자 판단): 이 단언은 git 없이 잰다는 계약이 있어 「머지됨」 을 git · PR 캐시에서 읽으면 클론마다 판정이 갈린다. 그래서 「끝남」 을 로드맵 자신의 의존으로 읽는다 — 로드맵의 의존은 「앞 에픽이 머지된 뒤 시작」 이므로, 예약한 에픽이 줄의 에픽에 (건너서라도) 의존하면 줄의 에픽은 그 에픽이 손대기 전에 끝난다. `lock_rows` 의 위반 조건에 한 줄을 더한다: 다른 에픽 Y 가 줄의 에픽 X 에 의존(`roadmap_status._reachable` — `overlaps` 가 쓰는 같은 도달 표)하면 위반이 아니다.
- 약해지지 않는 것: 의존이 없는 두 에픽(병렬)은 지금처럼 위반이다. 방향이 반대인 경우(줄의 에픽이 나중이고 먼저 가는 에픽이 그 파일을 예약)도 위반이다 — 먼저 가는 에픽이 나중 에픽이 맡은 락을 건드릴 수 있다. 이 규칙은 `overlaps` 가 겹침을 정보에서 빼는 규칙과 같은 방향의 좁은 판이다.
- 최소인 이유: 단언 하나의 조건 한 줄이고, 락 지도 줄을 고치지 않는다(줄은 「R12 가 이 동작을 지킨다」 는 기록으로 남는다).
- 순서: 같은 PR 에서 단언을 먼저 고치고, 그다음 `roadmap_write.py update` 로 R14 경로 예약에 `shared/tests/fixtures/docreview/golden/` 와 `plugins/spec-distill/tests/test_review_handoff_order.sh`(§6 — 락 지도에 바꿀 에픽 R3 인 줄이 있다)를 더한다. 폴더 전체(`fixtures/docreview/`)가 아니라 골든 폴더만 — `cases_advice.sh` 의 R12 줄 둘을 건드리지 않는다.
- 실측(이 브랜치, 지금 단언): 둘을 예약에 넣으면 실데이터 단언이 위반 셋을 낸다 — R12 골든 줄 둘 · R3 의 `test_review_handoff_order.sh` 줄. 세 줄 모두 줄의 에픽(R12 · R3)이 R14 의 의존 경로 안이라 고친 단언에서는 위반이 아니다.

### §5 해결자 · 원장의 거부 셋

모두 지휘자 판단이다.

- **(1) 콜론 없는 머리말 줄은 엄격 오류.** `strict_frontmatter` 에서 비지 않은 최상위 줄(들여쓰기 · `-` · `#` 로 시작하지 않는 줄)에 `:` 가 없으면 `SettingsError("unreadable", …)` — 「<자리> 의 머리말에 `키: 값` 꼴이 아닌 줄이 있다(<줄>) — `키: 값` 으로 고치거나 지운다」. 레포 설정 파일과 로드맵 층 둘 다다. 지금 레포의 로드맵 · 템플릿 머리말에는 그런 줄이 없다(확인함). 「키 없음」(기본값)과 다른 오류다.
- **(2) 폴더 값의 특수 글자 거부.** `_folder` 가 값에 `*` · `?` · `[` · `]` · `\` 가 있거나 값이 `:` 로 시작하면(pathspec 매직) 그 키를 쓰지 않고 오류를 낸다 — 「<키> 에 글롭 · pathspec 특수 글자(<찾은 글자>)를 쓰지 않는다 — git 이 경로를 글자 그대로 읽지 않는다: <값>」. 해결자 한 자리에서 막으므로 `ls-tree` · `git grep` · spec-review 의 `"${SPECS}*-design.md"`(뒤 `*` 는 일부러 쓴 글롭) 모두가 글자 그대로의 폴더만 받는다. 폴더 키(`specs_dir` · `plans_dir` · `roadmaps_dir` · `interview_dir`)만이다 — `test_failure_pattern` 처럼 일부러 정규식인 값은 그대로다.
- **(3) 레포 설정의 같은 키는 쓰는 자리에서 거부.** `c_add` 가 `--section "레포 설정"` 일 때 그 키가 이미 있으면 아무것도 쓰지 않고 rc 2 — 「레포 설정 절에 <키> 가 이미 있다 — 바꾸려면 `ledger drop --roadmap <로드맵> --session <세션> --section "레포 설정" --where 키=<키>` 로 지운 뒤 다시 적는다」. 같은 자리에서 기계 상태 층이 받지 않는 키(`repo_defaults.check_layer(meta, "machine")`)도 rc 2 로 거부한다 — 읽는 쪽이 거부하는 상태를 쓰지 않는다는 같은 축이고, 있는 검사를 부를 뿐이다(작성자 판단). 값도 읽는 쪽과 같은 검사를 쓰기 전에 돈다(지휘자 판단(사용자 결정 아님)): 따옴표를 벗긴 뒤 빈 값(`repo_defaults.merge_layers` 가 기계 상태 층 하나로 돌 때 내는 오류를 그대로 본다)과 `test_failure_pattern` 의 정규식 컴파일(merge_check 가 `run` 안에서 하는 `re.compile` 검사 — 그 몇 줄을 `merge_check` 의 작은 함수로 옮겨 `run` 과 `ledger add` 가 함께 부른다, 새로 짓지 않는다). 하나라도 걸리면 rc 2 이고 기계 상태는 바뀌지 않는다. conducting.md 의 `## 레포 설정` 기록 문장에 「같은 키를 바꿀 때는 drop 뒤 add」 를 적는다.

### §6 인터뷰 다음 세션의 superpowers 판 확인

가장 작은 꼴 — 다음 세션 줄에 한 문장을 더한다. 새 스크립트 · 새 펜스는 없다.

- B-3 「다음 세션 줄 — ①/② 공통」 의 첫 문장(「…Skill superpowers:brainstorming 을 시작하라.」) 바로 뒤에:

  > brainstorming 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.

  `${CLAUDE_PLUGIN_ROOT}` 는 이 줄의 다른 자리와 같이 절대경로로 바꿔 노출한다. 꺾쇠 자리표를 쓰지 않는다(`lead_only` 락).
- 「다른 다음 단계의 줄」 은 고른 skill 이 `superpowers:` 일 때만 같은 문장(skill 이름만 바꿔)을 싣는다.
- B-1 의 「알 수 없음 — …(판은 다음 세션에서)」 줄은 그대로다 — 이제 그 약속을 다음 세션 줄이 지킨다.
- 지휘 흐름은 이미 확인한다(epic-conductor 진입의 `check_deps.py superpowers`, 에픽 brainstorming 은 지휘 세션 안에서 돈다) — 에픽 넘김 줄은 바꾸지 않는다.

### §7 작은 빈틈 — 고침 · 안 고침

기준(지휘자 판단, 원칙 「너무 과한 장치와 제약(과설계)만 경계」): 사람을 헷갈리게 하거나 실제 결함을 통과시키는 것만 고친다.

**항목 5 — 동작 빈틈 여섯**

| 하위 항목 | 처분 | 이유 |
|---|---|---|
| 묶음 대조의 `specs_dir` 필수화(`check_bundle_coverage.Repo.specs_for` · `roadmap_status._GitTreeRepo`) | 고침 | 폴더를 빠뜨린 새 호출자가 레포 설정을 조용히 무시하고 기본 폴더를 읽는다 — 인자를 필수로(기본값 갈래 삭제) |
| 머리말 앞 빈 줄이면 로드맵 아님 | 안 고침 | 첫 줄이 `---` 가 아니면 어느 도구도 머리말로 읽지 않는 규약이고, 로드맵은 생성기만 쓴다 |
| 한 번에 읽기(`cat_batch`)의 크기 상한 | 안 고침 | 읽는 것은 레포의 로드맵 폴더 문서이고, 상태줄은 마감 시간이 있다 |
| 원장 git 호출의 lazy fetch 끄기 | 안 고침 | `conductor_ledger` 는 네트워크를 쓰는 진입이고 lazy fetch 는 맞는 값을 가져온다 — 네트워크를 쓰면 안 되는 상태줄 · 상태 계산 쪽은 이미 껐다 |
| `.git` 이름 bare 레포의 멈춤 문장 | 고침 | bare 레포를 `.git` 이라는 이름으로 두고 worktree 를 붙이는 흔한 배치에서 `ensure_state_root` 가 작업 트리 없는 폴더로 무시 탐침을 돌려 할 일 없는 문장으로 멈춘다 — 공용 git 디렉토리가 bare 면(`core.bare`) 추적 검사를 건너뛴다(상태 루트가 어느 작업 트리에도 들지 않는다) |
| check-path 가 로드맵 층을 안 봄 | 고침 | 로드맵 층이 바꿀 수 있는 키(`specs_dir` · `plans_dir`)로 부르면 틀린 판정을 낸다 — 지금 호출자는 `roadmaps_dir` · `interview_dir` 뿐이라 받는 키를 그 둘로 좁힌다 |

**항목 6 — 문구 · 테스트 빈틈 열아홉**

| 하위 항목 | 처분 | 이유 |
|---|---|---|
| 해결자 대체 이름표(`repo_label or "레포 설정"`) | 안 고침 | 실제 호출은 늘 이름표를 넘긴다 — 사람에게 닿지 않는다 |
| 안 쓰는 kind `bad_value` | 안 고침 | docstring 의 이름일 뿐 출력 · 동작이 없다 |
| 리터럴 락의 끝 슬래시 없는 상수 탐침 | 안 고침 | 이미 고쳐졌다(§10) — 슬래시 없는 따옴표 꼴 상수를 잡는 변이가 있다. 남은 왼쪽 경계는 과잉 탐지 쪽이다 |
| 기계 층 unknown_key 테스트 | 고침 | 그 층이 받지 않는 키는 이미 잰다(§10). 오타 키 거부 길에는 테스트가 없다 — §5 (3) 테스트와 함께 |
| check-path `--root` 글자 접두 테스트 | 고침 | `git add` 범위 게이트의 갈래가 테스트 없이 남았다 — 한 경우 |
| 지휘자 3단계 부분 문자열 락 | 안 고침 | 모델이 읽는 문장의 순서 락을 조여도 행동을 보장하지 못한다 |
| 상태줄 「N분」 문구 | 안 고침 | 「받은 지 N분」 은 설계의 「N시간」 보다 정확하다 — 틀린 말이 아니다 |
| test_merge_check 낡은 이름표 | 안 고침 | 이미 사라졌다(§10) — 지금 이름표는 잰 것과 맞다 |
| ReadFailed 사유의 고정 rc | 고침 | git 이 0 으로 끝났는데 짧게 읽은 경우에도 「rc 0」 실패로 보인다 — 실제 원인(짧은 읽기 · rc)을 말한다 |
| 원장 검사 불가 행의 사유 | 고침 | `ledger roadmaps` 가 사유 없이 「검사 불가」 만 보여 사람이 할 일을 모른다 |
| 멈춤 정규식 느슨함(`\|\| echo exit`) | 안 고침 | 행동 테스트가 실제 멈춤을 잡는다 |
| 상태 블록 stderr 두 줄 | 안 고침 | 두 줄 모두 맞는 말이다 |
| 해결자 두 번 부름 | 안 고침 | 성능뿐이고 값은 같다 |
| 확인과 add 사이 재대입 | 고침 | 확인한 변수를 `git add` 전에 다시 대입하는 펜스가 락을 통과한다 — 커밋 범위 게이트 우회라 변이 하나와 탐지를 더한다 |
| 테스트 1b 이름표 | 고침 | 이름표가 잰 것보다 넓게 말한다 — 한 줄 |
| review-diff `degraded_reason: -` | 안 고침 | 그 갈래의 사유는 사용자 화면(Step 4.5)에 닿지 않는다 |
| check-review-scope 대체 락 | 안 고침 | 사유를 잃어도 `degraded: yes` 는 그대로 서서 조용한 통과가 되지 않는다 |
| resolve-baseline 주석 | 안 고침 | 주석이고 동작과 무관하다 |
| ensure 락이 `:` 꼴을 통과 | 고침 | `\|\| :` 로 상태 루트 확인 실패를 삼키는 펜스가 락을 통과한다 — `\|\| true` 와 같은 축으로 잡는다 |

**항목 7 — 정적 락 후보 여덟: 모두 안 고침.** 함수 안 import 의 import 시점 코드 · 값으로 넘긴 콜백 · 내장 이름 재바인딩 · 클래스 메서드 이름 판정 · 물려받은 메서드 · import 표 스코프 · `print(file=)` · 바깥 검사의 금지 목록 방식. 같은 테스트의 행동 검사가 지나는 길의 파일 쓰기(읽기 전용 파일 시스템 · 실행 전후 비교)와 git · gh 호출(기록 stub)을 표기와 무관하게 잡는다. 소켓 수준 네트워크는 정적 검사(`NET_MODS`)만 보는 축인데, 여덟 가운데 지금 코드에서 소켓 길을 여는 것은 없고 §2 의 번호 읽기도 새 import 를 더하지 않는다 — 그래서 덮이지 않은 후보는 찾지 못했다.

**항목 10 — `put_snap`: 고침.** `cases.sh` 에서 `$(put_snap … && …)` 꼴을 `put_snap …` 을 제 줄에서 먼저 부르고 그 rc 를 본 뒤 `$(…)` 로 begin-round 출력만 받는 꼴로 바꾼다. 실패 수가 바깥 셸에 남는다.

### §8 위험에 대한 답

묶음 §5 는 「없음」이다. 원본 brief 의 위험 가운데 이 에픽에 닿는 것:

- 숨은 가정 「인터뷰 시점에 나눈 경계가 맞고 하류가 따른다 — 승인된 분해가 봉인되기 쉽다」(K4) — 설계 대화에서 「새 기능」 경계가 반증되자 사용자 결정으로 범위를 넓히고 재분해로 로드맵에 싣는다(봉인하지 않음).
- 외부 문구 변화(K11) — §6. 다음 세션이 불러온 superpowers 의 판을 개발 당시 판과 대조해 알린다.
- 실패 양식 「버전 · CHANGELOG 같은 공유 파일 겹침」 — 판 번호는 머지 직전에 정한다(Metadata). R9 와 병렬이어도 R9 는 CLAUDE.md · 철학 문서만 고쳐 공유 파일이 겹치지 않는다.

이 설계가 새로 여는 위험:

- 번호를 잘못 적으면 그 에픽이 영영 머지됨이 안 될 수 있다 — `pr-record` 가 head · 교차 · base 를 대조해 쓰는 자리에서 거부하고, 같은 브랜치의 다른 PR 이 머지됐으면 상태 계산이 고칠 명령을 보인다.
- 번호 기록은 이 기계에만 있다 — 다른 기계에서는 지금 추정으로 돌아가고 틈이 다시 열린다. 공시한다(§2).
- 특수 글자 · 콜론 없는 줄 거부가 지금 돌던 레포 설정을 멈출 수 있다 — 바라던 동작이고, 오류 문장이 고칠 꼴을 말한다.
- 자동으로 찾아 적는 길이 없으므로(U9), 번호를 적지 않은 PR 은 누가 `ledger pr-record` 를 부를 때까지 이름 · 이력 추정 길에 남는다 — 그동안은 틈 ① · ② 도 남는다. README 한계 둘째 줄이 이것을 말한다.

### §9 계획 · 병렬

- 계획 하나, 브랜치 `feature/r8-device-leftovers`. 항목 대부분이 다른 파일을 고친다. 순서는 계획이 정하되 §4(단언 → 골든 예약)는 붙어 간다.
- **꼼꼼한 조사는 설계 때 했다(U6 · U7 — §10).** 계획의 첫 Task 는 가벼운 재확인이다 — 이 설계를 쓴 커밋(origin/main ad7efbb6) 뒤 기본 브랜치에 들어온 변경이 §10 표의 자리를 바꿨는지, 받는 곳이 R14 인 행이 새로 생겼는지만 본다. 바뀐 것은 계획에 적고, 설계에 없던 결정이면 지휘 세션에 보고한다.
- **병렬(U6).** R14 는 R9(`feature/rules-docs-cleanup`)와 병렬로 간다. R9 는 규칙 문서와 함께 cost_class high skill 의 승인 게이트를 고치므로 지휘 절차 파일 일부가 겹칠 수 있다(`## 상류 · 하류 연계`의 겹침 줄) — 같은 문단은 아니다. 통합은 그대로 한다 — R14 가 먼저 머지하고, R9 가 기본 브랜치를 merge 한 뒤 스위트 대조와 통합 리뷰를 다시 돈다(지휘자 판정). 회귀가 병렬 진행 탓으로 생기지 않는지 그 두 번째 대조가 본다.

### §10 조사 — 빠진 항목 · 지금 코드 재확인

설계 때 한 전수 조사다(U7). 기준은 origin/main ad7efbb6.

**빠진 받는 곳 R14 항목 찾기.**

| 찾은 곳 | 결과 |
|---|---|
| 모든 설계문서 `## 미룸` 의 받는 곳 R14 행 | R8 설계의 열 행뿐이다(§1). 다른 문서의 「R14」 는 다른 번호 체계(판정 번호 · 위험 번호)다 |
| 모든 설계문서 `## 미룸` 의 받는 곳 R8 행 중 끝냄 · 받지 않음 표지가 없는 행 | 없다. R12 설계의 「보호 절 제목 바꿈 정체 추적」 은 「받지 않음 — 좁힌 대로 둠(U5)」 이 달려 있다(R8 U15) |
| R8 설계 `## 지휘 기록` | 「거꾸로 방향」 · 「미룸 행 이동」 · 「계획 3 리뷰」 줄이 가리키는 일은 모두 §1 의 열 행 안이다 |
| R8 PR 셋(#249 · #251 · #252)과 로드맵 PR(#250 · #253) 본문의 인계 · 「지휘자에게」 · 「확인 못 함」 | 「뒤 에픽이 고침」 은 모두 §1 안이거나 로드맵 PR 로 이미 끝났다. 「확인 못 함 — R9 · R14 브랜치 이름의 gh 옛 PR」 은 지금 확인했다: `feature/r8-device-leftovers` · `feature/rules-docs-cleanup` 이름의 PR 은 0개라, 이 두 에픽은 같은 이름 틈의 대상이 아니다. 「골든 폴더 예약」 은 §4. 「업그레이드 직후 옛 판 PR 캐시 경고」 는 R8 이 공시로 닫은 한계다(R14 일 아님) |
| R8 계획 1 진행 기록의 deferred 줄 전부 | 묶음 범위의 스물다섯과 같다. 그 밖의 deferred 줄(상태줄 권장 수 · 해결자 알림 · `.git` 대소문자 · 따옴표 뒤 주석 등)은 계획 1 마지막 고침 물결(5e9d4ba1 · 29e8a020 등)이 이미 고쳤다 |

빠진 항목은 찾지 못했다.

**항목마다 지금 코드 재확인.**

| 항목 | 지금 코드 | 결과 |
|---|---|---|
| 1 | `repo_defaults.strict_frontmatter` 가 `":" not in line` 이면 `continue` | 그대로 남음 |
| 2 | `_folder` 가 루트 · `.` · `..` · `.git` 만 막음 | 그대로 남음 |
| 3 | `c_add` 가 절 이름 · 칸만 보고 쓴다 | 그대로 남음 |
| 4 | 다음 세션 줄에 판 확인 지시가 없다 | 그대로 남음 |
| 5 · `specs_dir` | `check_bundle_coverage.Repo.specs_for` 가 `specs_dir or SPECS_DIR` | 그대로 남음 |
| 5 · lazy fetch | `repo_defaults._GIT_ENV` 에만 `GIT_NO_LAZY_FETCH`, `conductor_ledger` 에는 없음 | 그대로 남음(안 고침) |
| 5 · `.git` 이름 bare | `state_path._check_state_root` 가 `common.name == ".git"` 이면 본 체크아웃으로 보고 탐침 | 그대로 남음 |
| 5 · check-path | 받는 키 = `_FOLDER_KEYS` 넷, 호출자는 `roadmaps_dir` · `interview_dir` 뿐 | 그대로 남음 |
| 6 · 끝 슬래시 없는 상수 탐침 | `test_repo_literals.sh` 에 슬래시 없는 따옴표 꼴 가짜 상수 변이와 따옴표 없는 음성 대조가 이미 있다 | **이미 고쳐짐** — 남은 것은 왼쪽 경계(과잉 탐지 쪽)뿐이라 안 고침 |
| 6 · 기계 층 키 | `test_merge_check.sh` 가 그 층이 받지 않는 키(`review_model`)와 같은 키 둘을 잰다. 오타 키(unknown_key)는 없다 | 일부 이미 — 오타 키는 §5 (3) 테스트와 함께 |
| 6 · check-path `--root` | `repo_defaults._repo_relative` 의 절대 경로 갈래 — 경로가 `--root` 의 글자 그대로(`pwd -P` 아님) 접두로 시작하면 그 접두를 실제 경로로 바꾸는 자리. `test_repo_defaults_git.sh` 는 `--root` 기준 상대 경로만 재고 이 갈래는 재지 않는다 | 그대로 남음 |
| 6 · test_merge_check 낡은 이름표 | 진행 기록의 자리(:991)가 지금 파일(312줄)에 없고, 같은 키 단언의 이름표는 맞다 | **이미 사라짐** — 안 고침 |
| 6 · ReadFailed | `roadmap_model` 이 「파일을 읽지 못했다(git cat-file rc %d)」 | 그대로 남음 |
| 6 · 검사 불가 행 | `c_roadmaps` 가 `"%s\t검사 불가"` 만 낸다 | 그대로 남음 |
| 6 · 재대입 | `test_repo_literals.sh` `covered_vars` 가 재대입을 보지 않음 | 그대로 남음 |
| 6 · 1b 이름표 | `test_finish_commit_roadmap.sh` 1b 머리 「…돌려도 같다」 | 그대로 남음 |
| 6 · ensure 락 | `test_ledger_root.sh` 의 부재 단언이 `--ensure.*\|\| true` 만 잡는다(R13 이 옮긴 자리) | 그대로 남음 |
| 6 · 나머지 안 고침 열 | 자리는 그대로다 | 처분 그대로 |
| 7 | `test_roadmap_status.sh` 5절 정적 검사 · 행동 검사 | 그대로 — 안 고침 |
| 8 | `roadmap_status.compute.judge` | 그대로 남음 |
| 9 | `WRITER_TRUST_NOTICE` · 골든 다섯 · 테스트 | 그대로 남음 |
| 10 | `cases.sh` 의 `$(put_snap … && …)` 모든 자리(18 — 지금 cases.sh 기준) | 그대로 남음 |

## 있는 것 검토

- 레포 안(쓴다):
  - 기계 상태의 절 · 줄 검사 · 원자 쓰기 · 표지(`conductor_state` — `SECTIONS` · `OPTIONAL_SECTIONS` · `_check_row` · `save`)(§2)
  - `ledger` 의 명령 틀 · `need_holder` · 블록 해석(`_status` · `_block` · `_with_copy_branches`)(§2)
  - `gh_repo` 의 `-R origin` · `PR_FIELDS` · `gh_json` · `origin_slug` · `slug_from_url`(§2)
  - `_cache_row` 의 칸 꼴 · `pr-refresh` 의 브랜치 줄 갈아끼우기(§2)
  - 상태 계산의 PR 판정 조각(교차 · base · mergeCommit 닿음 · 「받기 전」 · 되돌림 경고)과 `control_plane` 의 캐시 지문(§2)
  - `WRITER_TRUST_NOTICE` 한 상수와 그것을 읽는 테스트(§3)
  - `roadmap_status._reachable`(§4)
  - `repo_defaults.check_layer` · `SettingsError` 꼴(§5)
  - `check_deps.py superpowers`(§6)
- 레포 안(맞지 않아 쓰지 않는다): `ledger add --section PR` — 검증 없이 쓰고 `pr_by_hand` 락이 막는다.
- 레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다.

## 상류 · 하류 연계

- 받는 곳: 묶음 R14.md · R8 설계 `## 미룸` 의 받는 곳 R14 행 열 · 덩어리 1 되비춤 승인 U1 · 범위 넓힘 U2 · U3 · 공시 자리 U5 · 조사 · 병렬 U6.
- 넘기는 곳:
  - 번호 판정 → 상태 계산 · 상태줄 · 지휘자 걸음 1 · 3 · 6(머지 · 다음 에픽 착수 게이트) — 모든 에픽 사용자에게 간다.
  - 고친 해결자 · 원장 · 인터뷰 끝 → 모든 spec-distill 사용자.
  - 공시 문장 → 리뷰 결과(spec-distill · quality-gates) · README.
  - **R9 로 넘기는 규칙 문장(U6).** R9 가 머지 판정을 말하는 규칙 문서 자리에 실을 문장: 「에픽의 머지됨은 지휘자가 PR 을 열 때 기계 상태에 적은 PR 번호로 판정한다 — 그 PR 이 기본 브랜치로 머지됐을 때만 머지됨이다. 번호가 없는 에픽만 브랜치 이름과 이력으로 알아보고, 그 추정의 틈(같은 이름의 옛 브랜치 · 늦게 들어온 문서)은 공시한다.」 R9 가 먼저 머지되면 R14 머지 뒤 지휘자가 R9 의 받는 곳에 이 문장이 있는지 확인한다.
- 되돌아오는 길: 계획 · 구현에서 설계를 다시 나눌 근거가 보이면 재분해 신호 · 설계 변경으로 지휘 세션에 보고한다(`references/redecompose.md`). 예: 첫 Task 재확인이 새 받는 곳 R14 행을 찾음, `gh pr create` 출력에서 URL 을 못 얻는 경우가 흔함.
- 같은 상태를 읽는 다른 표면:
  - 기계 상태 `## 에픽 PR` · `## PR` — 상태 계산 · 상태줄(`control_plane` 덧씌움 · 지문) · `ledger pr-refresh` · `ledger pr-handoffs` · `ledger audit` · `merge_check`
  - 해결자 값 — 모든 spec-distill 스크립트 · skill 펜스 · 상태줄
  - 리뷰 렌더 셋째 줄 — spec-distill 진입 skill 셋 · quality-gates 문서 비평
  - 이음매 담당은 이 에픽이다.
- 경로 겹침(R9 · 지휘자 판정 2026-10-23):
  - R9 는 사용자 결정 「모든 high skill 을 규모 공시만으로 (권장)」 · 「R9 가 규칙과 skill 을 함께 (권장)」(2026-10-23)에 따라 cost_class high skill 의 승인 게이트를 지우고 그 락을 고친다. R14 는 승인 게이트를 건드리지 않는다.
  - 머지 순서: R14 가 먼저 머지한다. R9 가 그 뒤 기본 브랜치를 merge 하고 스위트 대조와 통합 리뷰를 다시 돈다.
  - 주인(지휘자 판정): R14 는 PR 번호 기록과 그것에 드는 `conductor_ledger.py` · epic-conductor SKILL 문장을 맡는다. R9 는 high skill 승인 게이트 제거(epic-conductor `### 4` · `conductor_ledger` 의 `approval` · `approve` · plugin-audit · artifact-critique), 쉬운 말 블록의 사본들, 규칙 문장을 맡는다. R14 는 쉬운 말 블록과 그 사본을 고치지 않는다.

  | 파일 | R14 가 고치는 것 | R9 가 고치는 것 |
  |---|---|---|
  | `SD/scripts/conductor_ledger.py` | `pr-record` 명령 · `pr-refresh` 의 번호 줄 · `c_add` 의 레포 설정 거부 · `c_roadmaps` 검사 불가 사유 | `approval` · `approve`(승인 게이트 제거) |
  | `SD/tests/test_epic_conductor_skill.sh` | 고치지 않는다(§7 지휘자 3단계 락은 안 고침, PR 번호 문장은 conducting.md 에 둔다) | 승인 게이트 락 |
  | `SD/README.md` | `## 한계` 첫 줄(§3) · `## 한계` 의 U8 두 줄(§2) · 상태 계산 줄의 번호 판정 공시(§2)만 | 쉬운 말 블록 사본 · 규칙에 닿는 문장 |
  | `SD/skills/spec-review/SKILL.md` · `SD/skills/request-framing/SKILL.md` | 고치지 않는다(§5 (2) 는 해결자에서 막고, §7 의 상태 블록 stderr 는 안 고침) — R14 예약에는 남아 있다 | 쉬운 말 블록 사본 |
  | `SD/references/conducting.md` · `SD/tests/test_conducting_reference.sh` | 걸음 4 · 손 절차 5 의 PR 번호 · 걸음 5 의 쌓인 PR 바탕 바꾼 뒤 번호 · 걸음 7 정리에서 `## 에픽 PR` 남김 · 「레포 설정」 문장과 그 순서 락 | 시작 승인 문장과 그 락 |

  - R14 는 epic-conductor `SKILL.md` 를 고치지 않는다 — PR 번호 걸음은 모두 conducting.md 에 있다. R5 설계 :642 의 SKILL 문장(`approval` rc 가 0 이 아니면 묻는다)도 R14 가 할 일이 없다 — R9 계획 2 가 그 승인 갈래를 지운다. 문단이 달라 기계적 충돌은 작을 것이다.
- 걸음 7 정리: 로드맵 끝의 기계 상태 정리는 `## 에픽 PR` 을 남긴다(§2) — 정리 뒤에도 상태 계산 · 상태줄이 같은 번호로 판정한다.
- R12 예약(골든 폴더 · `test_conducting_reference.sh` 등)은 R12 가 머지돼 의존 순서 안이다.

## Acceptance Criteria

**PR 번호(§2)**
- AC1 `ledger pr-record --roadmap R --session S --epic E --pr <PR>` 이 있다. URL · `#N` · `N` 을 받고, 번호로 `gh pr view` 한 PR 의 head 가 그 에픽의 브랜치이고 교차 레포가 아니고 base 가 기본 브랜치일 때만 `## 에픽 PR` 에 (에픽 · 브랜치 · 번호 · 적은 때 · 쓴 세션) 한 줄을 쓴다(같은 (에픽, 브랜치) 줄은 바꾼다). head 다름 · 교차 · base 다름 · URL 레포가 origin 아님은 각각 rc 4 이고 아무것도 쓰지 않는다. 번호를 못 읽으면 rc 2, 표지가 없으면 지금 쓰기 명령과 같은 멈춤이다(gh stub 픽스처).
- AC17 conducting.md 걸음 5 가 쌓인 PR 의 바탕을 기본 브랜치로 바꾼 뒤 → `ledger pr-record --epic <에픽> --pr <번호>` → 머지 명령 준비 순서다(`test_conducting_reference.sh` 의 `before` 꼴 순서 락 + 뒤집은 글로 양성 대조). 걸음 4 · 손 절차 5 는 쌓인 PR 의 rc 4 를 예상된 결과로 적는다. 걸음 1 에 번호를 자동으로 찾아 적는 걸음이 없다(부재 락 + 위 순서 락이 양의 짝). conducting.md 가 `pr-refresh` 의 어긋남 경고 뒤 할 일(다시 적기 · `--drop`)을 적는다.
- AC2 conducting.md 걸음 4 와 손 절차 5 가 `gh pr create -R …` → `ledger pr-record … --pr <그 출력의 URL>` → `ledger pr-refresh … --epic <에픽>` 순서다(순서 락). `pr_by_hand` 락은 그대로 GREEN 이고, `--section "에픽 PR"` 손 적기도 없다(부재 락 + 양의 짝).
- AC3 `pr-refresh` 는 적은 번호가 있는 브랜치의 그 PR 줄을 head 목록에 없어도 `## PR` 에 둔다(목록 stub 이 그 PR 을 빼는 픽스처). `--reset` 뒤 `## 에픽 PR` 은 그대로다. 적은 번호의 head 가 그 브랜치와 다르거나 교차 레포가 된 픽스처에서 `pr-refresh` 는 rc 0 으로 끝나고, 번호 · 어긋난 칸 · `pr-record` 다시 적기와 `--drop` 을 이름 붙인 경고 한 줄을 낸다. 그 브랜치의 `## PR` 에서 #N 줄만 사라지고 — 앞서 맞던 #N 줄이 있던 픽스처에서도 — `## 에픽 PR` 의 번호 기록과 그 브랜치의 다른 PR 줄은 남는다. 상태 계산은 그 브랜치를 판정 없음으로 두고, 상태줄 지문이 바뀐다. 다른 브랜치의 줄은 채워진다. 번호를 적지 않은 브랜치에 대해 `pr-refresh` 가 `pr-record` 를 부르거나 권하지 않는다(그 밖의 동작은 지금 그대로 — 기존 `pr-refresh` 테스트 GREEN). 경고 · README 의 명령은 모두 `--pr <숫자>` 꼴이고 맨 `#` 이 없다(부재 단언). `pr-record --drop` 은 gh 를 부르지 않고 그 줄을 지운다(없으면 rc 1).
- AC4 상태 계산은 적은 번호가 있는 브랜치를 그 번호의 캐시 줄로만 판정한다 — 머지됨 ∧ 교차 아님 ∧ 기본 base ∧ mergeCommit 닿음이면 머지됨(근거에 「적은 번호로 판정」), mergeCommit 이 닿지 않으면 「머지됨(받기 전)」 경고이고 머지됨이 아니다, 열림 · 닫힘 · 다른 base · 교차 · mergeCommit `-` 는 머지됨이 아니다, 캐시에 그 번호가 없으면 그 번호를 이름 붙인 정보 줄. 픽스처 넷:
  - (가) 같은 이름의 옛 브랜치 머지 커밋이 첫째 부모 줄에 있고 적은 PR 이 열림 → 머지됨 아님(틈 ①이 닫힘).
  - (나) 로컬 브랜치 없이 문서가 첫 머지보다 뒤에 들어왔고 적은 PR 이 squash 머지됨(원격 끝 == 캐시의 `headRefOid`, 끝은 기본 브랜치의 조상이 아님) → 머지됨, 「커밋이 더 붙었다」 줄 없음(틈 ②가 닫힘).
  - (다) 적은 PR 은 닫힘, 같은 브랜치의 다른 PR 이 머지됨 → 머지됨 아님 + `ledger pr-record … --pr <M 의 숫자>` 경고.
  - (라) 머지 뒤 브랜치에 커밋이 더 붙음(끝 ≠ 캐시의 `headRefOid`) → 머지됨 + 「커밋이 더 붙었다」 정보 줄. 대조: rebase 머지 뒤 끝 == `headRefOid` 이면 줄이 없다.

  상태 계산은 gh 를 부르지 않는다(기존 stub 락 GREEN).
- AC5 번호가 없는 브랜치의 판정은 바뀌지 않는다(기존 PR · 머지 테스트 전부 GREEN). SD README `## 한계` 에 §2 의 U8 두 줄이 글 그대로 있다(첫 줄 공시는 그대로 첫 줄). `roadmap_status.NOTICE` 와 SD README 상태 계산 줄에 §2 의 공시 문장이 있다(번호 판정 · 번호 없는 에픽의 추정과 남은 틈 · 번호 기록은 이 기계에만).
- AC19 conducting.md 걸음 7 의 기계 상태 정리 문장이 `## 에픽 PR` 을 남긴다고 말한다(문장 단언 + 지운다는 문장의 부재 락). 정리 뒤(그리고 `pr-refresh --reset` 뒤) 상태 계산이 번호가 적힌 머지된 에픽을 같은 번호로 머지됨이라 판정한다.
- AC20 이미 머지된 PR 을 `pr-record` 로 적은 직후(`pr-refresh` 없이) 상태 계산이 그 브랜치를 그 번호로 머지됨이라 판정한다 — `## PR` 에 그 번호의 줄이 `_cache_row` 꼴로 있다. 같은 번호의 옛 줄이 있으면 바뀐다.
- AC18 적은 번호가 있는 브랜치에서 `control_plane.pr_fact`(단계 「PR」 과 보이는 번호) · `merged_prs` · `roadmap_status.judge` · `ledger pr-handoffs` · `ledger audit` · `ledger review-pack` 이 모두 적은 번호를 쓴다 — 같은 브랜치에 이름으로 먼저 잡히는 다른 PR 줄(더 최근 · 열림)을 둔 픽스처에서 여섯이 같은 번호를 내고, `audit` · `review-pack` 출력에 그 다른 PR 이 나오지 않는다. 번호 없는 브랜치의 출력은 기존 테스트대로다. 줄을 고르는 세 자리(`pr_fact` · `merged_prs` · `judge`)는 `conductor_state` 의 한 함수를 부르고, `pr-handoffs` · `audit` · `review-pack` 은 같은 모듈의 번호 찾기를 쓴다(`_prs` 한 자리). 세 자리 가운데 하나가 그 함수를 우회해 이름으로 고르게 하는 변이마다 RED 다. 지문은 AC6 이 잰다.
- AC6 `## 에픽 PR` 은 선택 절이다 — 줄이 없으면 머리를 쓰지 않는다. 번호 꼴 · 같은 (에픽, 브랜치) 두 줄은 기계 상태를 읽을 때 오류다. `control_plane.pr_cache_fingerprint` 가 이 절을 지문에 넣는다(번호 하나를 더하면 지문이 바뀌는 테스트).

**공시(§3)**
- AC7 `WRITER_TRUST_NOTICE` 가 §3 의 문장 그대로이고, 렌더 셋째 줄 · `gate` JSON · SD README `## 한계` 첫 줄 · 골든 다섯이 같은 글자다(`test_writer_trust_notice.sh` 의 기대값 갱신 · 기존 단언 GREEN). 문장에 「원장」 · 「엔진」 · 「요약값」 이 없다(단언). 진입 skill 셋의 게이트 질문 글에 공시 문장이 없다(부재 락 + 렌더에는 있다는 양의 짝).

**골든 · 락 지도(§4)**
- AC8 `lock_rows` 가 예약한 에픽이 줄의 에픽에 (건너서라도) 의존하면 그 줄을 위반으로 세지 않는다. 양성 대조 넷:
  - R12 골든 줄 + R14 예약 → 위반 아님.
  - 기존 R2 · R1 줄 → 위반 그대로.
  - 줄의 에픽이 나중이고 먼저 가는 에픽이 예약 → 위반.
  - 의존 없는 두 에픽 → 위반.

  그다음 같은 PR 에서 `roadmap_write.py update` 로 R14 경로 예약에 `shared/tests/fixtures/docreview/golden/` 와 `plugins/spec-distill/tests/test_review_handoff_order.sh` 가 더해지고, 실데이터 `LOCKBAD` 는 `[]`, `OVERLAPS` 는 그대로다.

**해결자 · 원장(§5)**
- AC9 `strict_frontmatter` 가 콜론 없는 최상위 줄을 그 줄을 이름 붙인 `unreadable` 오류로 멈춘다(레포 설정 · 로드맵 층 각각). 들여쓴 줄 · 목록 줄 · `#` 줄 · 빈 줄은 그대로 건너뛴다. 레포의 실제 로드맵이 모두 통과한다.
- AC10 폴더 키 값에 `*` · `?` · `[` · `]` · `\` 가 있거나 `:` 로 시작하면 해결자가 그 키를 이름 붙인 오류를 내고 값을 주지 않는다(글자마다 한 경우). 기본값 · 보통 폴더는 통과하고, `test_failure_pattern` 의 `[` 는 받는다(양의 짝).
- AC11 `ledger add --section "레포 설정"` 은 이미 있는 키면 rc 2 와 `ledger drop … --where 키=<키>` 를 담은 문장을 내고 아무것도 쓰지 않는다. 기계 상태 층이 받지 않는 키도 rc 2 다. 따옴표를 벗기면 빈 값 · 컴파일되지 않는 `test_failure_pattern` 도 rc 2 이고, 넷 모두 기계 상태 파일이 바이트까지 그대로다(전후 비교). 값 검사는 읽는 쪽 함수(`merge_layers` · merge_check 의 정규식 검사 함수)를 부른다 — 그 함수를 바꾸면 쓰는 쪽 판정도 함께 바뀌는 테스트. merge_check 가 거부하는 기계 상태를 이 명령으로 만들 수 없다(끝에서 끝). conducting.md 에 「바꿀 때는 drop 뒤 add」 가 있다.

**superpowers 판(§6)**
- AC12 다음 세션 줄(brief 줄, 그리고 고른 skill 이 `superpowers:` 인 다른 다음 단계 줄)이 첫 문장 바로 뒤에 §6 의 판 확인 문장을 싣는다. `test_review_handoff_order.sh` 의 기존 단언(머리 · 순서 · `lead_only`)이 GREEN 이다. 그 문장을 지우는 변이에 RED 다.

**작은 빈틈(§7)**
- AC13 §7 표에서 「고침」 인 하위 항목 열마다 테스트가 있다 — 동작 셋(`specs_dir` 필수 · `.git` 이름 bare 레포에서 상태 루트 확인이 통과하는 픽스처 · check-path 가 `specs_dir` 를 사용법 오류로) · 문구 · 락 일곱(기계 층 오타 키 · `--root` 글자 접두 · 1b 이름표 · ReadFailed 사유 · 검사 불가 행 사유 · 재대입 변이 · `|| :`). 「안 고침」 하위 항목은 코드가 바뀌지 않는다.
- AC14 `cases.sh` 에서 `put_snap` 이 `$(...)` 안에서 불리지 않는다(지금 18 자리 모두 — 부재 단언은 개수를 박지 않고 파일 전체를 본다). `put_snap` 실패를 일부러 낸 경우가 바깥 실패 수에 남는다(테스트).

**조사 · 공통**
- AC15 계획의 첫 Task 가 §9 의 가벼운 재확인이다 — ad7efbb6 뒤 기본 브랜치 변경이 §10 표의 자리를 바꿨는지, 새 받는 곳 R14 행이 있는지. 결과(바뀐 자리 · 새 행, 없으면 「없음」)가 계획에 적혀 있다.
- AC16 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고쳤고, 변이로 이빨을 확인했다(변이 전에 커밋). 음의 락에는 양의 짝이 있다. spec-distill 은 다음 minor(새 명령), quality-gates 는 다음 patch(공유 엔진의 공시 문장)로 머지 시점 기본 브랜치 위에서 올리고 CHANGELOG 에 적는다.

## Files to Modify

**예약 안(R14)** — 처음부터 R14 경로 예약에 있던 파일:

- `plugins/spec-distill/scripts/repo_defaults.py` · `roadmap_status.py` · `conductor_ledger.py` · `control_plane.py` · `merge_check.py`(§5 (3) 정규식 검사 함수) · `roadmap_model.py`(필요할 때) · `check_bundle_coverage.py` · `state_path.py`
- `plugins/spec-distill/references/conducting.md` · `skills/pm-interview/references/finishing.md`
- `plugins/spec-distill/tests/test_roadmap_status.sh` · `test_repo_defaults.py` · `test_repo_literals.sh` · `test_merge_check.sh` · `test_finish_commit_roadmap.sh` · `test_ledger_root.sh`
- `shared/docreview/scripts/docreview_state.py` · `shared/tests/test_writer_trust_notice.sh` · `shared/tests/fixtures/docreview/cases.sh` · `plugins/spec-distill/README.md`

**예약 안이지만 이번 설계로 고칠 자리가 늘어난 곳** — 파일은 위 목록에 있다:

- `control_plane.py` 의 `pr_fact` · `merged_prs` · 지문(§2 「보이는 곳」)
- `conductor_ledger.py` 의 `pr-record`(캐시 줄 쓰기 포함) · `_prs`(`c_pr_handoffs` · `c_audit` · `c_review_pack` 이 지난다) · `pr-refresh` 의 번호 따로 받기 · 어긋남 갈래 · `c_add` 의 값 검사(§2 · §5 (3))
- `merge_check.py` 의 `re.compile` 검사를 작은 함수로 옮김(§5 (3))
- conducting.md 걸음 4 · 손 절차 5 의 번호 적기와 쌓인 PR 문장, 걸음 5 의 바탕 바꾼 뒤 번호 적기, 걸음 7 정리의 `## 에픽 PR` 남김(§2)
- SD README `## 한계` 의 공시 뒤 세 불릿과 U8 두 줄(§2 · §3)

**예약 밖** — 이 브랜치의 로드맵 커밋(0e803d5a)으로 등록했다:

- `plugins/spec-distill/scripts/conductor_state.py`(선택 절 · 적은 번호 찾기와 줄을 내는 함수) · `plugins/spec-distill/scripts/gh_repo.py`(`pr_view`)(§2)
- `plugins/spec-distill/tests/test_conducting_reference.sh` · `test_conductor_ledger.py` · `test_conductor_state.py` · `test_merged_by_pr.py` · `test_control_plane.py` · `test_gh_repo.py`(§2)
- `plugins/spec-distill/tests/test_bundle_coverage.sh` · `test_state_root.sh` · `test_repo_defaults_git.sh` · `test_control_plane.sh`(§7)

**예약 밖 — 구현 PR 에서 등록한다**(§4 의 단언 변경 뒤):

- `shared/tests/fixtures/docreview/golden/`(§3 · §4) · `plugins/spec-distill/tests/test_review_handoff_order.sh`(§6)
- 그 등록은 구현 PR 이 `roadmap_write.py update` 로 로드맵 파일 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` 와 묶음 `R14.md` 를 고쳐 한다

**공유 파일**(겹침에서 빠진다): `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`

## Verification Plan

- 전수 조사는 설계 때 했다(§10). 계획의 첫 Task 는 그 뒤 기본 브랜치 변경만 다시 본다(§9).
- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 락은 변이(삭제 · 추가 · 반전 · 형태 변경)로 이빨을 확인하고 양성 대조를 둔다. 변이 전에 커밋한다. `PYTHONDONTWRITEBYTECODE=1`.
- §2 는 gh stub 으로 `pr-record` · `pr-refresh` 를, 임시 레포 픽스처로 상태 계산 넷(AC4)을 끝에서 끝으로 돈다. 실제 gh 는 이 레포의 이미 머지된 PR 하나로 `pr-record` 의 대조를 한 번 확인한다(쓰기는 임시 기계 상태에).
- 셸 펜스 · 테스트는 `/bin/bash`(3.2)로 돌린다.
- 로드맵을 읽는 테스트(PR #250 목록)와 전체 스위트 대조 · 에픽 사이 통합 리뷰(지휘자). R9 와 병렬이므로 나중에 머지되는 쪽이 기본 브랜치를 merge 하고 대조와 통합 리뷰를 다시 돈다.

## Rejected Alternatives

같은 기준으로 견준다 — 틈을 닫는 힘 · 장치 무게(새 상태 · 명령 · 파일) · 다른 표면과의 이음매.

- 옛 브랜치 틈을 공시로만 닫기 — 장치는 없다. 하지만 틈이 그대로 남는다. 사용자가 「유니크한 값」 쪽을 골랐다(U2 · U3).
- 번호를 설계문서 `## 지휘 기록` 등 git 이 추적하는 곳에 적기(U8 이 기각) — 다른 기계에서도 번호 판정이 된다. 하지만 PR 은 그 커밋 뒤에 열려 번호를 적으려면 커밋이 하나 더 들고, 상태 계산이 기본 브랜치에 없는 브랜치 끝의 문서를 읽어야 한다. 기계 상태로 시작하고 다른 기계는 공시한다.
- `ledger add --section "에픽 PR"` 로 손으로 적기 — 새 명령이 없다. 하지만 검증이 없어 번호를 잘못 옮겨 적는 실수가 그대로 들어온다. `pr_by_hand` 락의 뜻과도 어긋난다.
- PR 캐시 `## PR` 줄에 「에픽의 PR」 표지 칸 더하기 — 절은 하나다. 하지만 `--reset` · `pr-refresh` 가 줄을 통째로 갈아끼워 표지가 사라지고, 옛 9칸 줄과 칸 수가 갈린다.
- 번호가 있어도 여섯 조건(끝 대조 포함)으로 판정 — 머지 뒤 커밋을 더 붙인 브랜치를 머지됨이 아니라고 본다. 하지만 사용자 결정(「번호 있으면 그것으로」)과 다르고, 끝 대조가 이름 · 이력 추정으로 돌아가는 문이다. 정보 줄로 보인다.
- 락 지도 단언에서 「머지됨」 을 git · PR 캐시로 읽기 — 지휘자 판단의 글자 그대로다. 하지만 단언의 git 없는 계약이 깨져 클론마다 판정이 갈린다. 의존 순서가 같은 사실을 git 없이 준다.
- 락 지도의 골든 두 줄을 R14 로 고쳐 적기 — 단언은 그대로다. 하지만 R14 는 그 줄이 잡은 동작(재리뷰 줄)을 바꾸지 않아 줄이 거짓이 되고, 머지된 에픽 줄마다 같은 일이 되풀이된다.
- 판 확인을 다음 세션 줄 대신 brainstorming 앞에 도는 새 펜스 · 훅으로 — 외부 skill 앞에 끼어드는 장치라 C25 · D26 과 과설계 경계에 걸린다.
- 폴더 값을 쓰는 git 호출마다 `--literal-pathspecs` — spec-review 의 `*-design.md` 처럼 일부러 쓰는 글롭이 깨지고, 호출 자리마다 사본이 생긴다.

## 결정 기록

- U1 · 결정 · 2026-10-23 · 사용자 — 「좋아」 (덩어리 1 되비춤 — 열 항목 · 5/6/7/10 다듬기는 최소로 · 8 은 새 기능 우려 · 9 는 골든 예약 문제)
- U2 · 결정 · 2026-10-23 · 사용자 — 「두번째가 더 정확하지 않나? 유니크한 값 쓰니까」 (8번 범위 질문 — 선택지 「공시로 닫는다 (권장)」 / 「PR 번호를 적는 길을 만든다」)
- U3 · 결정 · 2026-10-23 · 사용자 — 「좋아 유니크한거라 이게 더좋지 실수도 적고」 (확인 질문 — PR 을 열 때 번호를 적고 · 번호가 있으면 그것으로 판정 · 없으면 지금처럼 추정 · R14 범위 넓힘. 로드맵 R14 「안 한다: 새 기능」 을 고치는 재분해의 원문)
- U4 · 결정 · 2026-10-23 · 사용자 — 「권장은 뭐야」 (9번 — 공시를 질문 화면에 올릴지 README 로 충분한지)
- U5 · 결정 · 2026-10-23 · 사용자 — 「그래」 (U4 에 답한 권장: README 에 쉬운 말로 · 질문 화면엔 올리지 않음 · 도구 출력 셋째 줄도 같은 쉬운 문장. 근거 대화에서 사용자가 동의한 예시 꼴 「리뷰 기록은 이 대화가 직접 쓴다 — 기록을 엔진 밖에서 고치면 숫자가 안 맞는 경우만 잡히고, 그럴듯하게 고친 것은 잡히지 않는다」)
- U6 · 결정 · 2026-10-23 · 사용자 — 「좋아 그리고 작업하는겇가장 먼저에 꼼꼼히 조사도 넣어주고 놓친거 있을 수 있으니, 파일이 안 겹치면 병렬 권장 이긴한데 회귀나 병렬 진행으로 인한 통한은 여전히 잘해야해」 (§9 · §10 — 빠진 항목 · 이미 고쳐진 항목 조사(U7 로 설계 때로 옮김), R9 와 병렬이되 통합 대조는 그대로, R9 로 넘기는 규칙 문장)
- U7 · 결정 · 2026-10-23 · 사용자 — 「아님 스펙 만들때 조사가 더 좋으려나」 (U6 의 「작업하는겇가장 먼저에 꼼꼼히 조사」 를 설계 때로 옮김 — 조사는 §10, 계획 첫 Task 는 가벼운 재확인. 지휘자가 이 읽기를 확인했다)
- U8 · 결정 · 2026-10-23 · 사용자 — 「이 기계에만 둔다 (권장)」 (PR 번호 기록을 어디에 둘지. 사용자가 본 선택지 설명 원문: 「장치가 가볍다. 다른 기계 · 새 클론에서는 추정으로 돌아간다는 사실과, 손으로 연 PR 은 명령 한 번을 부르면 된다는 것을 README 한계에 적는다.」 — §2 README 한계 두 줄)
- U9 · 결정 · 2026-10-23 · 사용자 — 「PR 을 열 때만 기록 (권장)」 (사용자가 본 선택지 설명 원문: 「지휘자가 PR 을 열 때, 그리고 쌓아 연 PR 의 바탕을 바꾼 직후에만 기록한다. 그 밖의 PR 은 명령 한 번(전에 고르신 말 그대로). 자동 찾기를 빼서 지적 셋이 사라지고 장치가 가벼워진다.」 — 걸음 1 의 자동 채우기 · 「번호를 적지 않은 열린 PR」 알림 · 단계와 무관한 열린 PR 묻기를 지운다. 아래 지휘자 판단 가운데 그것을 정한 줄(1라운드 「채우기는 브랜치마다」 · 점검 답 「걸음 1 에서 … 채운다」 · 2라운드 「단계와 무관하게 묻는다」 · 「걸음 1 의 채우기가 적는다」)과 작성자 판단의 알림 줄을 대체한다)
- U10 · 결정 · 2026-10-23 · 사용자 — 「전부 유지 (권장)」 (spec 리뷰 3라운드 — 2라운드에서 바뀐 일곱 절을 유지)
- U11 · 결정 · 2026-10-23 · 사용자 — 「한 번 더 본다 (권장)」 (리뷰 한 라운드 더)
- R9 결정(이 에픽에 닿는 범위) · 2026-10-23 · 사용자 — 「모든 high skill 을 규모 공시만으로 (권장)」 · 「R9 가 규칙과 skill 을 함께 (권장)」 (R9 가 cost_class high skill 의 승인 게이트를 지운다 — R14 는 게이트를 건드리지 않고 겹침을 `## 상류 · 하류 연계` 에 적는다)
- 원칙 · 2026-10-20 · 사용자 — 「너무 과한 장치와 제약(과설계)만 경계해 devbrew원칙이야」 (R8 U5 — 이 에픽의 지배 원칙, §7 기준)
- 지휘자 판단(사용자 결정 아님) · 2026-10-23:
  - 설계문서 점검 답(2026-10-23) 넷:
    - 「머지 뒤 커밋이 더 붙었다」 줄은 끝 ≠ 적은 PR 의 캐시 `headRefOid` 일 때만 낸다 — 「끝이 기본 브랜치의 조상이 아님」 으로 재면 squash · rebase 머지마다 난다.
    - 적은 번호가 있는 브랜치는 PR 을 보이거나 쓰는 모든 표면(`pr_fact` · `merged_prs` · `pr-handoffs` · 지문 · 상태 계산)이 적은 번호의 줄 하나를 쓴다. 번호 없는 브랜치는 그대로다.
    - 적은 번호가 브랜치와 더는 맞지 않으면 `pr-refresh` 는 전체를 멈추지 않고 그 브랜치만 건너뛰며 다시 적기 · `--drop` 을 안내한다. 그 브랜치는 판정 없음이다.
    - 걸음 1 에서 번호 없는 열린 에픽 PR 을 상태를 세기 전에 한 번 채운다(R9 의 PR 이 이 길을 탄다). 순서 락을 둔다.
  - spec 리뷰 1라운드 반영(2026-10-23):
    - 적은 번호가 브랜치와 어긋나면 `pr-refresh` 는 그 브랜치의 #N 캐시 줄만 지우고 번호 기록은 남긴다 — 판정은 「캐시에 그 번호가 없다」 갈래의 판정 없음, 지문도 바뀐다(옛 「줄을 고치지 않는다」 를 대체).
    - README 둘째 줄은 동작대로 — 열린 PR 은 지휘자가 다음 걸음 1 에서 스스로 적고, 이미 머지된 PR 은 지휘 세션(표지를 쥔 세션)에서 명령 한 번. `need_holder` 는 그대로다. 이렇게 해야 지휘 세션 안에서 U8 의 「명령 한 번」 이 참이다.
    - 채우기는 브랜치마다 — 후보가 하나면 적고, 둘 이상이면 적지 않고 모두 보인 뒤 지휘자가 고른 하나만 적는다.
    - 한 출처 함수는 줄을 고르는 세 자리(`pr_fact` · `merged_prs` · `judge`)가 부르고, `pr-handoffs` 는 같은 모듈의 번호 찾기를, 지문은 AC6 이 따로 잰다. 우회 변이는 세 자리에 건다.
    - 접미가 붙은 두 AC(옛 2a · 6a)를 AC17 · AC18 로 — 레포의 AC 정규식(`AC(\d+)`)이 접미를 버린다.
    - 사람에게 보이는 명령의 PR 번호는 숫자만(`--pr 123`) — 맨 `#` 은 셸 주석이다. `#123` 을 받더라도 따옴표가 든다.
    - §10 에 check-path `--root` 행을 더하고, R8 계획 PR 수를 셋으로 고쳤다(병합된 R8 PR 은 계획 PR #249 · #251 · #252 와 로드맵 PR 들이다).
  - spec 리뷰 2라운드 반영(2026-10-23):
    - `pr-refresh` 는 적은 번호가 없는 브랜치의 열린 PR 을 블록 단계와 무관하게 묻는다 — 거짓 머지됨이 채우기를 막지 않게. 열린 후보에만 채우기 규칙이 걸리고 머지된 옛 PR 은 자동으로 적지 않는다(AC19).
    - 쌓인 PR 은 base 가 기본 브랜치가 아니라 `pr-record` 가 rc 4 로 거부한다 — 그때의 rc 4 는 예상된 결과이고, base 를 바꾼 뒤(걸음 5) 걸음 1 의 채우기가 적는다.
    - `ledger add --section "레포 설정"` 은 쓰기 전에 읽는 쪽과 같은 값 검사(빈 값 · `test_failure_pattern` 정규식)를 읽는 쪽 함수로 돈다. 거부면 기계 상태는 그대로다(AC11).
    - Files to Modify 를 예약 안 · 예약 안에서 늘어난 자리 · 예약 밖(등록함) · 예약 밖(구현 PR 에서) · 공유 파일로 나누고, 구현 PR 의 로드맵 갱신 파일을 적었다.
  - spec 리뷰 3라운드 반영(2026-10-23):
    - 걸음 7 의 기계 상태 정리는 `## 에픽 PR` 을 남긴다 — 다시 만들 수 없는 기록이다(AC19).
    - `ledger audit` · `ledger review-pack` 도 `_prs` 를 지나므로 번호가 적힌 브랜치는 그 번호의 PR 만 쓴다(AC18).
  - R9 와의 통합: R14 가 먼저 머지 · R9 가 merge 뒤 대조와 통합 리뷰. 겹치는 파일의 주인은 `## 상류 · 하류 연계` 표 — R14 는 PR 번호 기록(필요한 `conductor_ledger.py` · epic-conductor SKILL 문장 포함), R9 는 high skill 승인 게이트 제거 · 쉬운 말 블록 사본 · 규칙 문장. R14 는 쉬운 말 블록을 고치지 않고 README 는 `## 한계` 와 상태 계산 줄만 고친다.
  - 골든 예약 충돌은 실데이터 락 지도 단언이 머지된 에픽의 예약 · 줄을 다른 에픽 소유로 세지 않게 고치고, 그 뒤 골든 폴더를 R14 에 예약한다(§4).
  - 5 · 6 · 7 · 10 은 사람을 헷갈리게 하거나 실제 결함을 통과시키는 것만 고치고 나머지는 안 고친다. 7 은 행동 층이 덮으면 안 고침이 기본이다(§7).
  - (1) 콜론 없는 머리말 줄은 엄격 오류 · (2) 폴더 값의 글롭 · pathspec 특수 글자는 거부 · (3) `ledger add --section "레포 설정"` 의 같은 키는 쓰는 자리에서 거부(§5).
  - 4 는 가장 작은 꼴 — 다음 세션 줄이 `check_deps.py superpowers --base <불러온 skill 의 기준 폴더>` 를 돌리게 한다(§6).
  - 10 은 값싼 고침(§7).
- 작성자 판단(사용자 결정 아님) · 2026-10-23 · 설계문서 작성(위 결정 안에서 다듬음):
  - 번호는 새 선택 절 `## 에픽 PR` 에 둔다. `## PR` 칸에 넣지 않는 이유는 `--reset` 이 그 절을 비우기 때문이다.
  - 쓰는 명령은 `pr-record` 하나다. 번호로 PR 을 물어 head · 교차 · base 를 대조한 뒤에만 쓴다. 판정에는 mergeCommit 닿음(「받기 전」)을 남긴다 — 이름 · 이력 추정이 아니라 받기 상태다.
  - 닫힌 번호 · 머지 뒤 커밋은 판정을 바꾸지 않고 줄로 알린다(머지 뒤 커밋의 기준은 위 지휘자 판단의 `headRefOid` 대조).
  - `pr-record --drop` 의 꼴(`--pr <숫자> --drop`, gh 없음)과 「번호를 적지 않은 열린 PR」 알림을 `pr-refresh` 가 내는 것.
  - 공시 문장의 「엔진 → 리뷰 명령」 · 「숫자 → 확인값」 · 「그 안의 사용자 말」(§3).
  - §4 의 「머지됨」 을 단언의 git 없는 계약에 맞춰 로드맵 의존 순서로 읽는다. 방향은 「예약한 에픽이 줄의 에픽에 의존」 한쪽만이다.
  - 이 브랜치의 로드맵 갱신에 골든 폴더와 `test_review_handoff_order.sh` 를 넣지 않는다 — 단언 변경 전에 넣으면 실데이터 단언이 위반 셋으로 RED 다(이 브랜치에서 실측, §4).
  - §5 (3) 에 기계 상태 층 키 검사(`check_layer`)를 함께 건다.
  - §7 하위 항목 스물다섯의 처분.
- D2.1 · r2 · adopt · 7836d322#r2.1 · "유지한다 (권장)" — finding 없이 바뀜: §2 에픽 PR 번호 — 적고, 번호로 머지를 판정한다 (modified)
- D2.2 · r2 · adopt · 93a5c0ad#r2.1 · "유지한다 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D2.3 · r2 · adopt · fa9159b4#r2.1 · "유지한다 (권장)" — finding 없이 바뀜: §10 조사 — 빠진 항목 · 지금 코드 재확인 (modified)
- D3.4 · r3 · adopt · 1970e061#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: §3 쓰는 세션을 믿는 한계 공시 — 쉬운 말로 (modified)
- D3.5 · r3 · adopt · 1a20ae3c#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: §5 해결자 · 원장의 거부 셋 (modified)
- D3.6 · r3 · adopt · 6c8b9494#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D3.7 · r3 · adopt · 7836d322#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: §2 에픽 PR 번호 — 적고, 번호로 머지를 판정한다 (modified)
- D3.8 · r3 · adopt · 93a5c0ad#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.9 · r3 · adopt · c934ff7b#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: 상류 · 하류 연계 (modified)
- D3.10 · r3 · adopt · fa9159b4#r3.1 · "전부 유지 (권장)" — finding 없이 바뀜: §10 조사 — 빠진 항목 · 지금 코드 재확인 (modified)
- D3.11 · r3 · drop · 3a3799f4#r1.1 · "이미 고침 — 59269f7e · 4c2d10ba(엔진 관측 창 밖에서 고쳐 적용으로 잡히지 않음)" — 조사 표는 R8 PR 을 「넷」이라 하면서 번호는 셋(#249 · #251 · #252)만 적었다. 넷째 PR 의 본문을 읽었는지 알 수 없어서, 「빠진 항목은 찾지 못했다」는 전수 조사 결론의 근거가 비어 보인다.
- D3.12 · r3 · drop · 3a3799f4#r2.1 · "이미 고침 — 59269f7e · 4c2d10ba(엔진 관측 창 밖에서 고쳐 적용으로 잡히지 않음)" — 재확인 표는 `put_snap` 이 `$(…)` 안에서 불리는 자리를 다섯이라고 적었지만, 지금 `cases.sh` 에는 열여덟 군데 안팎이 있습니다(47·48·49·53·452·455·658·662·766·769·914·3909·3918·3924·3941·3956·3986·4337행). 수를 바로잡거나 「모든 자리」로 고쳐야 합니다.
- D3.13 · r3 · drop · 72d754cb#r1.1 · "이미 고침 — 59269f7e · 4c2d10ba(엔진 관측 창 밖에서 고쳐 적용으로 잡히지 않음)" — §7 에서 고치기로 한 작은 빈틈 가운데 「check-path `--root` 글자 접두 테스트」만 §10 의 지금 코드 재확인 표에 자리(파일 · 함수)가 없다. 그 자리의 출처는 이 기계에만 있는 압축 파일이다.
- D3.14 · r3 · drop · a6ecc055#r1.1 · "이미 고침 — 59269f7e · 4c2d10ba(엔진 관측 창 밖에서 고쳐 적용으로 잡히지 않음)" — 복구 안내의 PR 번호 앞에 붙은 #을 따옴표로 감싸지 않았습니다. bash에서 안내를 그대로 실행하면 번호와 뒤의 삭제 옵션이 주석으로 처리됩니다.
- D3.15 · r3 · drop · a6ecc055#r2.1 · "이미 고침 — 59269f7e · 4c2d10ba(엔진 관측 창 밖에서 고쳐 적용으로 잡히지 않음)" — README 둘째 줄은 이미 머지된 PR이면 번호 적기 명령을 한 번만 부르라고 합니다. 그런데 그 명령은 번호 기록만 쓰고 PR 캐시 줄은 쓰지 않습니다. 캐시에 그 번호 줄이 없던 에픽은 다음 캐시 채우기 전까지 「판정 없음」으로 바뀝니다.
- docreview 계수 — spec-distill/2026-10-23-r8-device-leftovers-design-6b46557265ea2d88 r1: advice_new=4 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-23-r8-device-leftovers-design-6b46557265ea2d88 r2: advice_new=5 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-23-r8-device-leftovers-design-6b46557265ea2d88 r3: advice_new=1 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-23-r8-device-leftovers-design-6b46557265ea2d88 r4: advice_new=1 · advice_repeat=2 · mc_preexisting_new=0
- D4.16 · r4 · adopt · 6c8b9494#r4.1 · "전부 유지 (권장)" — finding 없이 바뀜: Files to Modify (modified)
- D4.17 · r4 · adopt · 93a5c0ad#r4.1 · "전부 유지 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D4.18 · r4 · adopt · 9a259506#r4.1 · "전부 유지 (권장)" — finding 없이 바뀜: §8 위험에 대한 답 (modified)
- D4.19 · r4 · adopt · c934ff7b#r4.1 · "전부 유지 (권장)" — finding 없이 바뀜: 상류 · 하류 연계 (modified)

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C25 | 반영 | Constraints · Non-goals · §6 — superpowers 파일 · 동작을 건드리지 않고 넘기는 글에만 싣는다 |
| C32 | 반영 | Anti-goals · `## 있는 것 검토` · §2(있는 기계 상태 · gh_repo · 캐시 지문) · §5(있는 `check_layer`) · §6(있는 `check_deps.py`) |
| C35 | 반영 | Constraints · Non-goals · Rejected Alternatives(brainstorming 앞 펜스 · 훅 기각) |
| D21 | 반영 | §8 — K4(봉인하지 않는 재분해) · K11(§6) · 공유 파일 겹침, 그리고 새로 여는 위험 셋 |
| D26 | 반영 | Constraints · §6 — devbrew 쪽(다음 세션 줄)만 바꿈 |
| S1 | 반영 | Context(묶음 의도의 출처) · G1(경고 없이 생기는 거짓 판정 대신 번호로 판정하고 남은 틈을 알림) |
| S13 | 반영 | §8 |
| S17 | 반영 | Constraints · Non-goals |
| S18 | 반영 | Constraints · §6 |
| S30 | 반영 | Anti-goals · `## 있는 것 검토` · Rejected Alternatives(손 적기 · 표지 칸 · `--literal-pathspecs` 기각) |
| S34 | 반영 | Constraints · Non-goals |
| S49 | 반영 | §1 — 묶음 범위 「한다」 열 항목을 모두 다룸(5 · 6 · 7 의 하위 항목은 §7 에서 하나씩 처분), 8 은 U2 · U3 로 넓힘 |

## 원칙 · 입력 대조

| 입력 | 자리 |
|---|---|
| CLAUDE.md 기본값과 판단 | §2(`gh pr create` 실패 때 번호를 손으로 넘김 — 지휘자 판단) · §9(계획이 순서를 정함) |
| CLAUDE.md 레포 전용 값 금지 | §2(`-R origin` · 기본 브랜치 도출) · §5 · §6(`${CLAUDE_PLUGIN_ROOT}` 치환) |
| CLAUDE.md 상류 · 하류 연계 | `## 상류 · 하류 연계` |
| CLAUDE.md 진입점에서 따라 내려가기 | §2(쓰는 곳 → 운반 → 읽는 곳) |
| CLAUDE.md 있는 것 먼저 | `## 있는 것 검토` |
| CLAUDE.md 공시와 차단 | §2(번호 없는 에픽의 틈 공시 · 「받기 전」 은 막음) · §3 |
| 과설계 경계 원칙(사용자 원문) | Anti-goals · §7 · Rejected Alternatives |
| R8 AC17 상태 계산은 gh 를 부르지 않는다 | §2 · AC4 |
| R8 U17 판정 순서 | §2(번호 없는 브랜치는 그대로) · Non-goals |
| U1 열 항목 | §1 |
| U2 · U3 PR 번호 길 · 범위 넓힘 | §2 · 로드맵 재분해 |
| U4 · U5 공시 자리 · 쉬운 말 | §3 |
| U6 · U7 조사 · 병렬 · 통합 · R9 규칙 문장 | §9 · §10 · `## 상류 · 하류 연계` · AC15 |
| R9 결정(high skill 승인 게이트를 규모 공시로) | Non-goals · `## 상류 · 하류 연계` 겹침 줄 |
| R8 미룸 행 열 | §1 표 |

## 미룸

없음 — §7 에서 안 고친 하위 항목은 이유와 함께 닫았고, 번호 없는 에픽에 남는 틈은 §2 의 공시로 닫는다. 계획의 첫 Task 재확인이 새 항목을 찾아 이 에픽이 받지 않기로 하면 여기에 행으로 올린다.

## 지휘 기록

- 2026-10-23 · 설계문서는 하위 agent 가 사용자 결정(U1~U7)과 지휘자 판단 안에서 썼다. 그 밖의 다듬음은 `## 결정 기록` 「작성자 판단」 에 있다.
- 2026-10-23 · 전수 조사(U7)를 설계 때 했다 — 결과는 §10. 빠진 받는 곳 R14 항목은 없고, 하위 항목 둘(끝 슬래시 없는 상수 탐침 · test_merge_check 낡은 이름표)은 이미 고쳐져 안 고침으로 바꿨다.
- 2026-10-23 · 지휘자 기록 · 이 레포의 지휘 기계 상태 PR 절이 옛 판 4칸 줄(「R8 · #252 · 머지됨 · 2026-10-23」 꼴)이다. 지금 판의 `ledger claim` · `pr-refresh` 는 이 줄에서 멈추고 `--reset` 을 안내한다 — 지금 판으로 지휘를 이으면 한 번 `pr-refresh --reset` 이 든다.
- spec 승인 · 2026-10-23 · 「승인하고 계획으로 (권장)」

## Metadata

- 에픽: R14 · 브랜치 `feature/r8-device-leftovers` · 묶음 `R14.md`
- 크기: 계획 하나(§9), 첫 Task 는 설계 뒤 변경의 가벼운 재확인
- 의존: R8(머지됨). R9 와 병렬.
- 버전: spec-distill 다음 minor · quality-gates 다음 patch(지금 main 8.8.0 · 14.7.0). 번호는 머지 직전에 정한다.

### Deferred to plan

- `pr-record` 의 rc 표가 `conductor_ledger` 의 기존 rc(0 · 1 · 2 · 3 · 4 · 5)와 겹치지 않는지 — 대조 실패는 기존 4(「받은 gh 출력이 다르다」)에 들어가는지, 뜻이 달라 새 값이 필요한지.
- `gh pr create` 출력에서 URL 을 얻는 펜스 꼴(마지막 줄 · 실패 출력).
- `.git` 이름 bare 판별의 꼴(`git --git-dir <공용> config --bool core.bare` 또는 `rev-parse --is-bare-repository`)과 픽스처.

| # | 항목 |
|---|---|
| 9fb13e91#r1.1 | 참고(data_flow) #2-에픽-pr-번호--적고-번호로-머지를-판정한다 — PR 정보가 어긋났다는 사실이 상태 계산에 전달되지 않습니다. 기존 캐시를 그대로 보존하면, 캐시만 읽는 상태 계산은 이전의 정상 정보와 검증에 실패한 정보를 구별할 수 없습니다. — 고치면: PR 정보가 어긋나면 해당 브랜치의 PR 캐시 줄을 제거하고 번호 기록은 보존한다. 상태 계산은 기록된 번호의 캐시가 없으므로 판정 없음으로 처리한다. 다른 브랜치는 정상 갱신하고, 캐시 변경으로 상태줄의 지문도 갱신한다. 기존 정상 캐시가 있는 상태에서 검증 실패가 발생하는 경우를 수용 기준에 포함한다. |
| f01c3775#r1.1 | 참고(feasibility) #2-에픽-pr-번호--적고-번호로-머지를-판정한다 — README 에 더할 둘째 줄은 지휘자 밖에서 연 PR 도 명령 한 번이면 번호로 판정된다고 약속한다. 그런데 새 명령은 지휘 표지를 쥔 세션만 쓸 수 있게 설계돼 있어, 지휘 세션 밖에서 부르면 쓰지 못하고 멈춘다. — 고치면: README 둘째 줄을 실제 동작에 맞춘다: 「지휘자 밖에서 연 PR 은, 열려 있으면 지휘자가 다음 맞추기(걸음 1)에서 스스로 적는다. 이미 머지된 PR 은 지휘 세션에서 `ledger pr-record … --pr <번호>` 를 한 번 부른다.」 다른 길로, 사용자의 원래 약속을 글자 그대로 지키려면 pr-record 만 표지 없이 쓰게 하는 예외를 두고 그 예외를 제약에 적는다. |
| cf7e2bc4#r1.1 | 참고(ambiguity) #2-에픽-pr-번호--적고-번호로-머지를-판정한다 — 열린 PR 후보가 여러 개일 때 하나를 고르라는 설명과 후보마다 번호를 기록하라는 절차가 충돌합니다. 같은 브랜치의 기록은 덮어쓰므로 절차대로 실행하면 마지막 후보가 선택됩니다. — 고치면: 번호 채우기는 브랜치별로 수행한다. 후보가 하나면 그 번호를 기록하고, 여러 개면 지휘자가 해당 에픽의 PR을 고른 뒤 선택한 번호 하나만 기록한다. 선택 전에는 번호를 기록하지 않는다. 본문의 채우기 절차와 수용 기준을 이 규칙으로 통일한다. |
| fccf272b#r1.1 | 참고(ambiguity) #acceptance-criteria — 다섯 자리가 「(에픽, 브랜치)를 받아 적은 번호의 캐시 줄을 내는」 한 함수를 부른다고 했다. 그런데 그 가운데 둘(PR 캐시 지문 · PR 인계 읽기)은 그 함수의 출력이 맞지 않는 자리라, 우회 변이를 어떻게 재는지가 정해지지 않는다. — 고치면: 그 함수를 부르는 자리를 브랜치마다 고르는 셋(`pr_fact` · `merged_prs` · `judge`)으로 적는다. pr-handoffs 는 같은 모듈의 「적은 번호」 조회를 쓴다고 적는다. 지문은 그 함수와 따로 「`## 에픽 PR` 줄을 더하면 지문이 바뀐다」(AC6)로 잰다. |
| a6ecc055#r2.2 | 참고(handoff_incomplete) #2-에픽-pr-번호--적고-번호로-머지를-판정한다 — 지휘 절차는 다음 계획의 PR을 앞 계획 브랜치 위에 쌓아 엽니다. 그런데 번호를 적는 명령은 바탕이 기본 브랜치가 아니면 거절하고(rc 4), 설계에는 PR을 연 직후 이 거절을 받았을 때 지휘자가 무엇을 하는지가 없습니다. |
| 9db1c4b0#r2.1 | 참고(ambiguity) #3-쓰는-세션을-믿는-한계-공시--쉬운-말로 — 새 공시 문장은 「리뷰 기록 · 리뷰 명령」이라고 쉬운 말로 바꿨습니다. 하지만 바로 아래 README 불릿은 「원장 · 엔진 명령」이라는 옛 낱말로 「위 공시로 다룬다」고 가리킵니다. 두 낱말이 같은 것을 가리킨다는 연결이 사라집니다. |
| e5d7c790#r2.1 | 참고(ambiguity) #5-해결자--원장의-거부-셋 — 쓰기 단계의 설계는 중복 키와 허용되지 않은 키만 막지만, 통과 기준은 읽는 쪽이 거부하는 설정을 전부 막겠다고 약속합니다. 실제 함수 대조에서 test_command 값으로 빈 따옴표 두 개를 넣으면 칸 검사와 check_layer는 통과하고, 읽는 해결자는 빈 값이라 거부했습니다. 어느 범위까지 쓰기 단계에서 보장하는지 일치하지 않습니다. — 고치면: 쓰기 단계에서 중복·허용 키 검사뿐 아니라 기존 읽기 규칙에 따른 값 검사도 수행한다. 따옴표를 벗긴 빈 값과 잘못된 실패 정규식은 저장 전에 거부하고, 거부된 입력이 기계 상태를 바꾸지 않는 것을 통과 기준에 포함한다. |
| 1cdda836#r2.1 | 참고(handoff_incomplete) #files-to-modify — §4는 구현 PR에서 `roadmap_write.py update`로 로드맵을 고친다고 했는데, 그 로드맵 파일이 Files to Modify에 없습니다. 「예약 밖」 목록 안에 「예약 안이지만 이번에 더한 자리」 불릿이 섞여 있어 어느 파일이 어느 부류인지도 흐립니다. |
| f7b2ece8#r2.1 | 참고(placeholder) #상류--하류-연계 — 「epic-conductor SKILL 에 PR 번호 문장이 필요해지면 R14 가 쓰되」는 조건부 자리표입니다. 그 SKILL 파일은 R14 경로 예약과 Files to Modify 어디에도 없습니다. 지금 고칠지 말지를 정해 적어야 합니다(진입부의 `pr-refresh --reset` 갈래는 번호 기록을 남기므로 고칠 필요가 없어 보입니다). |
| 8ce8e648#r3.1 | 참고(tradeoffs) #2-에픽-pr-번호--적고-번호로-머지를-판정한다 — 지휘자가 맞추기 걸음에서 번호 없는 열린 PR 을 자동으로 적는 규칙이 이미 끝난 에픽에도 걸린다. 진짜로 머지된 에픽의 브랜치 이름을 나중에 다른 일이 다시 쓰면, 그 새 PR 이 그 에픽의 번호로 적혀 끝난 에픽이 '머지 안 됨'으로 되돌아간다. — 고치면: 끝나지 않은 블록에서는 후보가 하나면 지금처럼 자동으로 적는다. 지금 머지됨 · 끝남인 블록에서는 후보를 알림으로만 보이고 자동으로 적지 않는다. 지휘자가 그 PR 이 이 에픽의 것인지 사용자에게 한 번 묻고 답을 받은 뒤에만 적는다. 이 갈래를 §8 새 위험에 한 줄, AC19 에 반대 방향 픽스처(진짜 머지된 에픽 + 같은 이름의 새 열린 PR → 자동으로 적지 않고 머지됨 유지)로 더한다. |
| 64366fc7#r4.1 | 참고(ambiguity) #context--why — Context 2번은 손으로 따르는 절차 5가 PR 을 연 뒤 PR 캐시를 채운다고 적었지만, 지금 문서는 PR 을 열기만 하고 캐시를 채우지 않습니다. |
