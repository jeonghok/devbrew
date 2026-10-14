---
name: state-storage-redesign
type: design
created_at: 2026-10-15
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R7.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R7 — 상태 저장 재설계 흡수 · Design

> 인터뷰 진행 기록은 docs 에, `.claude` 에는 문서 단위 리뷰 원장만. 어떤 세션의 종료나 시간 경과도 남의 기록을 지우지 않는다.

승인된 로드맵(S47)의 에픽 R7 이다. 로드맵 전체에서의 자리는 `roadmap.md` 의 `### R7` 블록이고, 이웃
에픽 R2 · R3 · R4 · R6 과 병렬로 간다(의존 R0 만).

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 인터뷰 상태 파일](#1-인터뷰-상태-파일)
  - [§2 리뷰 원장](#2-리뷰-원장)
  - [§3 훅 · 정리 · 끄기 스위치 · 옛 폴더 · 레포 규칙](#3-훅--정리--끄기-스위치--옛-폴더--레포-규칙)
  - [§4 위험에 대한 답](#4-위험에-대한-답)
  - [§5 인터페이스](#5-인터페이스)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [결정 기록](#결정-기록) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Handoff Context

- 입력: 에픽 묶음 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R7.md` (원본 brief
  `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 와 로드맵을 거꾸로 가리킴).
- 2026-05-29 의 미구현 결정 D1~D4(인터뷰 상태는 docs · `.claude` 는 리뷰 상태만 · 세션 넘는 이어 하기 제거 · 이어 하기 훅 제거)를
  D46 이 이 로드맵으로 흡수했다. 그중 「세션 넘는 이어 하기 제거」는 이 설계에서 「docs 상태 파일에서 이어 간다」로 재결정했다
  (`## 결정 기록` 재결정 절).
- brainstorming 결정: `## 결정 기록` B1~B10.
- 브랜치 `feature/state-storage-redesign` · worktree `.claude/worktrees/state-storage-redesign`.
- 지휘 방식(로드맵 재분해 이력 2026-10-15): superpowers 가 묻는 세 자리는 미리 답해 뒀다 — 실행 방식 Subagent-driven, 머지 메뉴
  Push 후 PR, 계획 검토는 경로를 보이되 기다리지 않는다.
- 이 문서만 읽고 계획을 쓸 수 있게 줄번호 대신 파일과 리터럴을 적는다(줄번호는 계획 시점에 다시 잰다).

## Context / Why

지금 spec-distill 의 런타임 상태는 전부 메인 레포의 `.claude/spec-distill/<세션>/` 한 폴더에 산다.

- 인터뷰 진행 기록 `state.local.md` — 라운드 기록 · 조사 원문 · 커버리지 표 · 사용자 발화 전부. 인터뷰가 끝날 때에야 docs 의
  brief · audit 로 옮겨 적힌다.
- 문서 리뷰 원장 `docreview/<문서 이름>-<경로 해시>/` — 라운드 · 재리뷰 상한 · finding.
- request-framing 의 이름 파일 `interview-basename`.

이 폴더를 지우는 장치가 둘이다. SessionEnd 훅 `session-end-cleanup.py` 는 끝나는 세션의 폴더를 통째로 지운다 — 진행 중이던
인터뷰도 리뷰 원장도 함께. 같은 훅이 부르는 `spec-distill-gc.py` 는 폴더 mtime 이 24시간(`DEVBREW_SPEC_DISTILL_TTL_HOURS`)을 넘은
**다른** 세션의 폴더까지 지운다. 2026-09-18 에 35시간 공백 뒤 다른 세션의 SessionEnd 가 리뷰 원장을 지워 모든 `decide` 가
`state_missing` 으로 끝났다(RC37). 사용자 결정은 엔진이 문서의 결정 절에 매번 적어 두어 살았지만, 라운드 · 상한 이력은 복구하지
못했다.

이 구조는 레포 규칙(CLAUDE.md 「State 는 `.claude/<plugin>/<session-id>/<file>` 에 살음, git-ignored, 성공 시 auto-delete」 — RC15)과
request-framing 의 선례(오래 남을 정보를 세션 state 에 두지 않음 — RC60)에서 나왔다. 짧은 리뷰 루프에는 맞지만, 이 로드맵처럼
에픽 하나가 여러 세션 · 압축 · 병렬 worktree 를 건너는 일에는 맞지 않는다(K5 · K9).

## Goals

- G1 인터뷰 진행 기록이 docs 의 상태 파일에 살아 세션 종료 · 압축 · 다른 세션의 정리로 사라지지 않는다.
- G2 새 세션에서 그 상태 파일로 인터뷰를 이어 간다.
- G3 `.claude/spec-distill/` 에는 문서 단위 리뷰 원장만 남는다.
- G4 어떤 세션의 종료나 시간 경과도 다른 리뷰의 원장을 지우지 않는다. 원장은 리뷰한 문서가 사라졌을 때만 지운다.
- G5 같은 문서를 두 세션이 동시에 리뷰해 원장을 덮어쓰는 일을 막는다.

## Non-goals

- 리뷰 엔진의 동작(라운드 · 상한 · 판정) 변경 — R2a. 이 에픽은 원장 경로 함수 하나만 바꾼다.
- 상태 · 경고를 화면에 보이는 일 — R6.
- 로드맵 기반 이어 하기 장치(지휘자) — R5. 에픽 단위 이어 하기는 R0 의 `roadmap_status.py` 가 이미 git 에서 계산한다.
- 인터뷰 본체의 진행 방식 · brief/audit 형식 변경 — R1 · R2 · R3.

## Constraints

- 외부 플러그인(superpowers)은 건드리지 않는다(C25 · C35 · D26).
- 있는 것을 다시 만들지 않는다(C32) — 안전한 삭제는 `gc_common.py`, 경로 해석은 `state_path.py`, 상태 스키마 이월은
  `state-migration.md` 를 그대로 쓴다.
- 파일을 지우는 장치는 끄기 스위치를 존중한다. 꺼 둔 스위치가 이름 변경으로 조용히 다시 켜지지 않게 한다.
- 레포 규칙: 플러그인을 건드리는 PR 은 SemVer bump(번호는 머지 직전), 은퇴하는 kill switch 이름은 CHANGELOG `Removed` 와 README 에 공시.

## 설계

### §1 인터뷰 상태 파일

1. **이름은 시작할 때 정한다.** 상태 파일은 인터뷰 첫 라운드 전에 만든다. seed 로 시작하면 seed 의 주제를, 거친 요청으로 시작하면
   첫 라운드에서 정한 주제를 쓴다. 끝날 때 쓰는 brief · audit 도 같은 이름 줄기를 써서 세 파일이 나란히 놓인다:
   `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md` · `.audit.md` · `.state.md`.
2. **경로는 스크립트가 낸다.** `state_path.py interview-state --topic <kebab> [--date <YYYY-MM-DD>] [--cwd <dir>]` 가
   `<작업 트리 루트>/docs/superpowers/interview/<날짜>-<topic>-interview.state.md` 를 낸다. 작업 트리 루트는
   `git rev-parse --show-toplevel` 이다(메인 레포가 아니라 인터뷰가 도는 worktree). topic 이 kebab 이 아니면 exit 2.
3. **형식.** 지금 `state.local.md` 의 frontmatter 키 · 본문(`## R<n>` 라운드 기록 · 조사 원문 · `## audit §2 대기 줄`)을 그대로 쓰고,
   frontmatter 맨 앞에 `type: interview-state` 와 `seed: <seed 경로 | 없음>` 을 더한다. 작업 트리 안이라 `Write` · `Edit` 로 고친다
   (지금의 「Bash 로만 갱신」 지시 PN1 은 작업 트리 밖 경로 때문이었으므로 걷는다).
4. **이어 가기.** 진입 단계가 인자를 본다.
   - `@<…>.state.md` 이고 frontmatter 가 `type: interview-state` 이면 그 파일을 읽어 마지막 라운드 다음부터 이어 간다.
     읽은 뒤 `state-migration.md` 의 스키마 이월을 적용한다(이월 대상이 이 파일로 바뀔 뿐 규칙은 그대로).
   - seed 경로로 불렀는데 같은 디렉토리에 `seed:` 가 그 seed 를 가리키는 상태 파일이 있고 그 짝 brief 가 아직 없으면,
     `AskUserQuestion` 하나로 「이어 감 (권장)」/「새로 시작」을 묻는다. 새로 시작하면 기존 상태 파일 이름 뒤에 `-<HHMM>` 을 붙여
     새 이름을 만든다(기존 파일은 지우지 않는다).
5. **끝내기와 커밋.** `finishing.md` Step A 가 brief · audit 를 쓴 뒤 세 파일을 경로 지정 커밋으로 묶는다
   (`git commit --only -- <brief> <audit> <state>` 꼴 — 다른 staged 작업을 쓸어 담지 않는다).
   - 현재 브랜치가 origin 의 기본 브랜치이면 커밋하지 않고 세 경로와 「브랜치에서 커밋하라」 한 줄을 보인다.
   - git 저장소가 아니거나 커밋이 실패하면 사유를 그대로 보이고 진행한다(파일은 이미 docs 에 있다).
6. **상태 파일을 읽던 곳.** `check_verbatim_coverage.py` · `finishing.md` · audit 템플릿 · reviewing-brief 의 degrade 원장(STATE) 이
   `state.local.md` 를 가리킨다. 모두 §1-2 의 경로로 바꾼다.
7. **옛 진행 중 인터뷰.** 인터뷰 진입 때 현재 세션의 옛 `<state-root>/<sid>/state.local.md` 가 있으면 §1-2 경로로 한 번 옮기고
   (주제는 그 파일의 기록에서, 없으면 사용자에게 한 번 묻는다) 「옛 위치의 진행 기록을 docs 로 옮겼다 — <경로>」 를 보인다.

### §2 리뷰 원장

1. **경로.** 공유 엔진 `shared/docreview/scripts/docreview_state.py` 의 `state-dir-for` 에서 `--session` 을 뺀다.
   새 경로는 `<state-root>/docreview/<stem40>-<sha256(문서 realpath)[:16]>` — 해시 규칙은 그대로이고 세션 칸만 빠진다.
   엔진의 다른 동작은 바꾸지 않는다. 호출하는 곳(spec-review · reviewing-brief · request-framing · `finishing.md` · 엔진 정본
   `reviewing-document.md` 의 펜스 · 픽스처)을 같은 커밋에서 맞춘다.
2. **이어 받기.** 같은 문서를 새 세션에서 리뷰하면 라운드 · 재리뷰 상한을 이어 받는다. 진입 블록이 원장의 라운드가 1 이상이면
   「이전 리뷰 라운드 <n> 에서 이어 간다 — <원장 경로>」 한 줄을 보인다. 상한에 닿았으면 지금처럼 승인 게이트에서 사용자가 연다.
3. **worktree.** 해시는 문서의 realpath 라서 worktree 마다 다르다 — 다른 worktree 의 같은 문서는 원장이 따로다. state-root 는 지금처럼
   `git rev-parse --git-common-dir` 로 메인 레포의 `.claude/spec-distill` 이다.
4. **동시 리뷰 표지.** 리뷰를 부르는 spec-distill 진입 블록이 라운드를 시작할 때 원장 폴더에 `reviewing-by` 파일(세션 id 한 줄)을
   쓰고, 그 라운드의 finalize 뒤 지운다. 진입 때 다른 세션 id 의 표지가 있으면 멈추고 `AskUserQuestion` 으로
   「그만둠 (권장)」/「이어 씀 — 표지를 내 것으로 바꾼다」 를 묻는다. 세션이 죽어 표지가 남은 경우도 같은 질문으로 풀린다.
   엔진은 표지를 모른다.
5. **request-framing 의 이름 파일.** `interview-basename` 을 없앤다. request-framing 은 audit 첫 쓰기 때 audit frontmatter 에
   `session_id: <sid>` 를 적고, 이후 라운드는 `docs/superpowers/interview/*-interview.audit.md` 중 frontmatter `session_id` 가
   현재 세션인 파일 하나로 이름을 되찾는다(둘 이상이면 멈추고 경로들을 보인다). 이로써 `.claude/spec-distill/` 아래에는
   `docreview/` 만 남는다.

### §3 훅 · 정리 · 끄기 스위치 · 옛 폴더 · 레포 규칙

1. **지운다.** `hooks/hooks.json` 의 SessionEnd 항목, `hooks/session-end-cleanup.py`, `scripts/spec-distill-gc.py`.
   spec-distill 에는 설치되는 훅이 남지 않는다. `hook_common.py` 는 다른 소비자(`brief_review_state.py`)가 쓰는 부분만 남긴다.
2. **새 정리 모듈 `scripts/ledger_sweep.py`.** 리뷰를 시작하는 진입 블록 셋(spec-review · reviewing-brief · request-framing 의 리뷰)이
   원장 경로를 연 직후 한 번 부른다.
   - ① `<state-root>/docreview/*/docreview-state.md` 에 기록된 문서 경로가 더는 없는 원장 폴더를 지운다.
   - ② 옛 세션 폴더 `<state-root>/<sid>/` 중 mtime 이 TTL(`DEVBREW_SPEC_DISTILL_TTL_HOURS`, 기본 24)을 넘은 것을 지운다.
     `docreview` 는 세션 이름 정규식(`^[A-Za-z0-9_-]{8,}$`)에 맞으므로 **이름으로 명시 제외**한다. 지금 도는 옛 버전 세션의 폴더는
     TTL 안이라 건드리지 않는다.
   - 삭제는 `gc_common.py` 의 `gc_one`(grace · double-stat · rename 후 rmtree)과 루트 탈출 거부를 그대로 쓴다.
   - 결과를 한 줄로 낸다: 「원장 정리 — 문서 없는 원장 <a>개 · 옛 세션 폴더 <b>개 지움」(둘 다 0 이면 내지 않는다). 셀 수 없으면
     「원장 정리 — 셀 수 없음(<사유>)」.
3. **끄기 스위치.** `ledger_sweep.py` 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 과 옛 이름 `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc`
   를 존중한다 — 정리를 꺼 둔 사용자가 조용히 다시 켜지지 않게 옛 이름을 그대로 읽는다. 은퇴: `spec-distill:SessionEnd` ·
   `spec-distill:session-end-cleanup` (끌 대상이 없어진다) — CHANGELOG `Removed` 와 README 에 공시.
4. **버전.** 상태 위치가 바뀌고 훅 · 스위치 이름이 은퇴하므로 spec-distill major bump(번호는 머지 직전).
5. **레포 규칙.** CLAUDE.md 「런타임 상태 & 훅」 절의 state 줄을 고친다: 인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에,
   짧은 리뷰 원장은 `.claude/<plugin>/` 아래 문서 단위로 두고 문서가 사라질 때 정리한다. 「JSON 이 아니라 마크다운」 ·
   「Secret 기록 금지」 · 「plugin namespace 하위」 는 그대로. 다른 줄은 건드리지 않는다(나머지 규칙 정리는 R9).
6. **README.** P14 의 state 서술, Hooks 표(없음), 스위치 목록(은퇴 둘 · 정리 스위치의 새 뜻 · TTL 이 옛 폴더에만 쓰인다는 것).

### §4 위험에 대한 답

- K5(한 세션이 압축을 여러 번 겪어도 의도와 지도를 잃지 않는다는 숨은 가정) · K9(압축 뒤 지도 · 결정 내력 소실) — 인터뷰 진행
  기록이 작업 트리의 docs 파일이 되어(§1) 압축 · 세션 종료 · 다른 세션의 정리로 사라지지 않는다. 에픽 지도는 R0 의 추적 로드맵이
  이미 맡는다(D29 · OQ12). 리뷰 원장은 문서 단위가 되어(§2) 다른 세션의 SessionEnd · TTL 로 지워지지 않는다(RC37).
- RC15(규칙) — §3-5 에서 규칙을 실제와 맞춘다. RC60(선례) — 오래 남을 정보는 docs 로, 세션 state 에는 아무것도 두지 않는다.
- OQ37(로드맵 정의와 살아 있는 단계의 자리) — 정의는 추적 파일, 단계는 git 에서 계산(R0 `roadmap_status.py`). 이 에픽은 바꾸지 않는다.
- 새 위험: 문서 단위 원장의 동시 쓰기 — §2-4 표지. 상태 파일의 작업 트리 노출(커밋 전 untracked) — §1-5 커밋 규칙과 기본 브랜치 거부.

### §5 인터페이스

- 넘기는 것(R1 · R3 · R4): 인터뷰 상태 경로는 `state_path.py interview-state`. R4 가 인터뷰 끝에 쓰는 로드맵 · 묶음은 brief 와 같은
  커밋 규칙(§1-5)을 따른다.
- 넘기는 것(R2a): `state-dir-for` 는 `--root --doc` 만 받는다. 엔진이 원장 디렉토리를 다른 곳에서 계산하지 않게 한다.
- 받는 것(R0): 로드맵 기반 에픽 이어 하기(`roadmap_status.py`).

## Acceptance Criteria

- AC1 `state_path.py interview-state --topic t --date 2026-10-15 --cwd <worktree>` 가 `<worktree>/docs/superpowers/interview/2026-10-15-t-interview.state.md` 를 낸다. kebab 이 아닌 topic 은 exit 2.
- AC2 `plugins/spec-distill` 의 production 표면(SKILL · references · scripts · templates)에서 `state.local.md` 는 §1-7 이월 문면과 `ledger_sweep.py` 의 옛 폴더 정리에만 남는다.
- AC3 상태 파일 frontmatter 첫 키는 `type: interview-state`, 다음 `seed:`. 진입 단계가 `@<…>.state.md` 를 받으면 이어 가는 분기로 간다(SKILL 문면 + 펜스 출력 단언).
- AC4 같은 seed 의 끝나지 않은 상태 파일이 있으면 「이어 감 (권장)」/「새로 시작」 질문이 뜨고, 새로 시작은 기존 파일을 지우지 않는다.
- AC5 `finishing.md` Step A 는 brief · audit · state 세 경로만 `--only` 로 커밋하고, 기본 브랜치에서는 커밋하지 않고 세 경로를 보인다(픽스처 git 저장소로 두 분기 다 확인).
- AC6 `docreview_state.py state-dir-for` 는 `--session` 을 받지 않고(주면 exit 2) `<root>/docreview/<stem40>-<hash16>` 을 낸다. 호출하는 펜스 전부가 `--session` 없이 부른다.
- AC7 원장 라운드가 1 이상이면 진입 블록이 「이전 리뷰 라운드 <n> 에서 이어 간다」 를 낸다.
- AC8 다른 세션 id 의 `reviewing-by` 표지가 있으면 진입이 멈추고 질문한다. 자기 표지는 finalize 뒤 사라진다.
- AC9 `ledger_sweep.py`: 문서 없는 원장만 지운다 · 문서 있는 원장은 남긴다 · `docreview` 는 옛 폴더로 보지 않는다 · TTL 넘은 옛 세션 폴더만 지운다 · 루트 탈출 링크를 거부한다 · `DEVBREW_SPEC_DISTILL_DISABLE=1` 과 `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` 에서 아무것도 지우지 않는다.
- AC10 `hooks/hooks.json` 에 훅 항목이 없고 `session-end-cleanup.py` · `spec-distill-gc.py` 가 없다. 양의 짝: 리뷰 진입 셋이 `ledger_sweep.py` 를 부른다.
- AC11 request-framing 에 `interview-basename` 이 없고, audit frontmatter `session_id` 로 이름을 되찾는다(둘 이상이면 멈춤).
- AC12 옛 `<sid>/state.local.md` 가 있으면 인터뷰 진입이 docs 로 옮기고 그 사실을 보인다.
- AC13 README · CHANGELOG: 은퇴 스위치 둘 공시, 정리 스위치의 새 뜻, TTL 의 범위, Hooks 표. CLAUDE.md 의 state 줄이 §3-5 대로다.
- AC14 spec-distill major bump.
- AC15 통과가 정답인 새 락(AC2 · AC6 · AC9 · AC10)은 변이로 이빨을 확인한다 — 삭제 · 추가 · 반전 축.

## Files to Modify

- `plugins/spec-distill/scripts/state_path.py` (+ `interview-state`), 새 `plugins/spec-distill/scripts/ledger_sweep.py`
- `shared/docreview/scripts/docreview_state.py` (`state-dir-for`), `shared/docreview/references/reviewing-document.md` (펜스), `shared/tests/test_docreview_state.sh` · `shared/tests/fixtures/docreview/cases*.sh` · `shared/tests/test_docreview_mutations.sh`
- `plugins/spec-distill/skills/spec-interview/SKILL.md` · `references/finishing.md` · `references/state-migration.md`
- `plugins/spec-distill/skills/spec-review/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/request-framing/SKILL.md`
- `plugins/spec-distill/scripts/check_verbatim_coverage.py` · `templates/interview-audit-template.md`
- 삭제: `plugins/spec-distill/hooks/session-end-cleanup.py` · `plugins/spec-distill/scripts/spec-distill-gc.py`; 수정: `hooks/hooks.json` · `scripts/hook_common.py`
- 테스트: `test_gc.py` · `test_session_end_cleanup.py` 를 새 `test_ledger_sweep.*` 로, `test_state_path.sh` · `test_reviewing_spec_state_keying.sh` · `test_kill_switches_v060.sh` · `test_hooks.sh` · `test_seed_gate_wiring.sh` · `test_finishing_block_scope.py` · `test_readme_sync.sh` · `test_stale_terms.sh` 및 경로 문자열을 단언하는 테스트들
- `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`, 레포 `CLAUDE.md` (state 줄 하나)

## Verification Plan

- 작업 전 기준선: spec-distill · shared 스위트의 FAIL «이름» 집합을 잰다(선재 RED `test_hook_output_schema.py test_python_and_bash_resolvers_agree` 포함).
- Task 마다 닿은 소비자 전부의 스위트를 레포 루트에서 돈다. 삭제 Task 는 guards 커버리지 락을 돈다.
- 픽스처 git 저장소(버릴 디렉토리, `mktemp` 경로를 `cd` 전에 비지 않았는지 확인)로 §1-5 커밋 두 분기 · §2-4 표지 · §3-2 정리를 확인한다.
- 새 락 넷(AC15)은 변이로 RED 를 확인하고 양성 대조를 둔다.
- 끝에서 끝: 픽스처에서 인터뷰 상태 파일 생성 → 세션 id 바꿔 이어 가기 → 끝내기 커밋 → 같은 문서 리뷰 두 세션 → 정리.

## Rejected Alternatives

- 인터뷰 상태를 `.claude` 에 두고 TTL 만 늘리기 — 시간 기준 삭제가 남아 긴 공백에서 같은 손실이 난다(RC37).
- 세션 단위 원장 + 끝난 세션만 정리 — 새 세션에서 라운드 1부터 다시 시작한다. 사용자가 「문서 단위」를 골랐다(B3).
- audit 를 첫 라운드부터 살아 있는 상태로 쓰기(B5 의 B안) — audit 형식 · 게이트 · 끝내기 흐름을 다시 짜야 하고 R1 · R3 와 부딪힌다.
- 끝날 때 상태 파일 삭제(B5 의 C안) — 「끝날 때 brief 와 함께 커밋」(B2)과 어긋나고 audit 에 없는 라운드 원문을 잃을 수 있다.
- SessionEnd 훅을 좁혀 남기기 — 지울 세션 상태가 없어져 훅의 일이 없다(B4).
- 라운드마다 커밋 — 커밋이 라운드 수만큼 쌓이고 기본 브랜치에 직접 커밋될 수 있다(B2).
- CLAUDE.md 개정을 R9 로 미루기 — 그동안 main 의 규칙이 실제와 다르다(B8).
- 엔진에 잠금을 넣기 — 엔진 동작 변경은 R2a 의 몫이다. 표지는 spec-distill 진입 블록이 다룬다(§2-4).

## 결정 기록

줄 형식은 로드맵과 같다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다.

- B1 · 결정 · 2026-10-15 · 인터뷰 중단 시 — 「docs 상태 파일에서 이어 감 (권장)」
- B2 · 결정 · 2026-10-15 · 상태 파일 커밋 시점 — 「끝날 때 brief 와 함께 (권장)」
- B3 · 결정 · 2026-10-15 · 리뷰 원장 단위와 정리 — 「문서 단위 · 문서가 없어질 때만 (권장)」
- B4 · 결정 · 2026-10-15 · 세션 끝 정리 훅 — 「훅을 없앰 (권장)」
- B5 · 결정 · 2026-10-15 · 진행 중 상태를 맡을 docs 파일 — 「A. 상태 파일을 따로 (권장)」
- B6 · 결정 · 2026-10-15 · 설계 1절 인터뷰 상태 파일 — 「맞다, 다음 절로 (권장)」
- B7 · 결정 · 2026-10-15 · 설계 2절 리뷰 원장 — 「맞다, 다음 절로 (권장)」
- B8 · 결정 · 2026-10-15 · CLAUDE.md state 규칙 — 「R7 에서 그 줄만 고침 (권장)」
- B9 · 결정 · 2026-10-15 · 설계 3절 훅 · 정리 · 스위치 · 옛 폴더 · 버전 — 「맞다 (권장)」
- B10 · 결정 · 2026-10-15 · 설계 4절 검증 · 번호 대조 — 「맞다, 설계문서 작성 (권장)」

### 재결정

- **원래**: 2026-05-29 결정 D3 — 세션 넘는 이어 하기(resume) 기능은 불필요하므로 제거한다(D46 이 「이어 하기는 로드맵 기반」으로 흡수).
- **재결정**: 에픽 단위 이어 하기는 로드맵 기반 그대로 두고, 인터뷰 하나의 이어 하기는 docs 상태 파일을 다시 읽는 것으로 둔다.
  별도 장치 · 복원 훅은 만들지 않는다(D4 는 그대로 — 이어 하기 훅은 없다).
- **근거**: 상태가 docs 에 남으면 이어 가기는 파일을 읽는 것뿐이라 새 장치가 아니다(C32). 사용자 선택 B1.

## 번호 대조

| 번호 | 처리 | 자리 · 이유 |
|---|---|---|
| C25 | 반영 | Constraints — superpowers 파일 · 동작 무변경. 이 에픽은 spec-distill · 공유 엔진 경로 함수만 |
| C32 | 반영 | Constraints · 재결정 근거 — `gc_common.py` · `state_path.py` · `state-migration.md` 재사용, 이어 가기는 새 장치 없이 파일 읽기 |
| C35 | 반영 | Constraints — 외부 플러그인을 어그러뜨리지 않음 |
| D21 | 반영 | §4 — 묶음의 위험 K5 · K9 · RC15 · RC37 · RC60 에 답함 |
| D26 | 반영 | Constraints — devbrew 쪽만 바꿈 |
| D29 | 반영 | §4 · §5 — 에픽 지도는 R0 의 git 추적 로드맵이 맡고, 인터뷰 기록도 같은 원리로 docs 추적 파일 |
| D46 | 반영 | §1 · §2 · §3 전체 — D1~D4 를 구현(D3 는 재결정 절) |
| OQ12 | 반영 | §4 — 로드맵은 레포 추적 파일(해결됨), 이 에픽은 인터뷰 상태를 같은 자리 원리로 |
| OQ20 | 반영 | Handoff · §1~§3 — 흡수해 구현 |
| OQ37 | 반영 | §4 — 정의는 추적 파일, 단계는 git 계산(R0). 이 에픽은 바꾸지 않음을 확인 |
| RC15 | 반영 | §3-5 — CLAUDE.md state 줄을 실제와 맞춤 |
| RC37 | 반영 | Context · §2 · §3-1·2 — SessionEnd 정리와 TTL-GC 를 걷고 문서 기준 정리로 |
| RC60 | 반영 | §2-5 · §4 — 세션 state 에 아무것도 두지 않음(이름 파일 제거) |
| K5 | 반영 | §4 — 진행 기록이 docs 파일이라 압축을 여러 번 겪어도 남음 |
| K9 | 반영 | §4 — 압축 뒤 소실 · 덮어쓰기 대신 git 추적 파일과 문서 단위 원장 |
| S1 | 반영 | Goals — 「통제가 살아 있다는 것은 … 한 곳에서 볼 수 있다」의 저장 쪽 바탕(긴 작업이 세션을 넘어도 기록이 남음) |
| S13 | 반영 | §4 — 위험 전부를 받아 답함 |
| S17 | 반영 | Constraints — 외부는 건드리지 않음 |
| S18 | 반영 | Constraints — devbrew 쪽만 |
| S26 | 반영 | §4 · §1 — 레포 안 추적 파일로 세션 · 압축 · 기기를 넘어 생존 |
| S30 | 반영 | Constraints — 있는 것을 다시 만들지 않음 |
| S34 | 반영 | Constraints — 잘 만든 외부 플러그인을 어그러뜨리지 않음 |
| S46 | 반영 | Handoff · 설계 전체 — 흡수 결정의 원문 |
| S49 | 반영 | Goals — 범위를 줄이지 않음: D1~D4 넷 모두와 「긴 · 병렬 실행 중 원장 소실 방지」(§2-4) 까지 |

## Metadata

- 에픽: R7 · 브랜치 `feature/state-storage-redesign` · 의존 R0(머지됨 `6e55f593`)
- 플러그인: spec-distill major bump(번호는 머지 직전)
- 경로 예약 밖 편집(정보): `shared/docreview/` (R2a 예약 — 경로 함수 하나), `CLAUDE.md` (R9 예약 — state 줄 하나), `finishing.md` (R3 예약), `spec-interview/SKILL.md` (R1 예약)

### Deferred to plan

- `hook_common.py` 에서 남길 함수와 지울 함수의 정확한 경계(소비자 grep).
- `docs/superpowers/interview/` 를 훑는 기존 규칙 · 락(미실행 seed 판별 등)이 `.state.md` 를 오분류하지 않는지 — 금지 토큰 · 코퍼스 선대조.
- 경로 문자열을 단언하는 테스트의 전수 목록(`git grep` 으로 `state.local.md` · `interview-basename` · `--session` · `spec-distill-gc` · `session-end-cleanup`).
- `SKILL.md` 줄 예산(R1 에서 상한 502).
