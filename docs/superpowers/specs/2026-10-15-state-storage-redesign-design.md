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
- 레포 규칙: 플러그인을 건드리는 PR 은 SemVer bump(번호는 머지 직전), 은퇴하는 kill switch 이름은 CHANGELOG `Removed` 와 README 에 공시(이 설계에서 은퇴하는 이름은 없다 — §3-3).

## 설계

### §1 인터뷰 상태 파일

1. **이름은 시작할 때 정한다.** seed 로 시작하면 seed 의 주제 뒤에 `-brief` 를 붙인 것을 인터뷰 주제로 쓰고(seed 파일 이름
   `<날짜>-<주제>-interview.md` 에서 `<주제>` 를 떼어 `<주제>-brief`) 상태 파일을 첫 라운드 전에 만든다. seed 와 seed audit 도
   `<날짜>-<주제>-interview.md` · `.audit.md` 이름 규칙을 쓰므로, 꼬리 `-brief` 가 없으면 같은 날의 brief · audit 가 seed · seed audit
   와 같은 경로가 되어 덮어쓴다 — 인터뷰 산출물은 seed 의 경로를 다시 쓰지 않는다. 거친 요청으로
   시작하면 주제가 첫 라운드에서야 정해지므로, 상태 파일은 첫 라운드에서 주제를 정한 직후 만들고 그 라운드의 기록을 첫 내용으로
   쓴다(그 전까지 라운드 1 기록은 대화 안에만 있다). 끝날 때 쓰는 brief · audit 도 같은 이름 줄기를 써서 세 파일이 나란히 놓인다:
   `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md` · `.audit.md` · `.state.md`(seed 로 시작했으면
   `<kebab-topic>` 이 `<seed 주제>-brief` 다).
2. **경로는 스크립트가 낸다.** `state_path.py interview-state --topic <kebab> [--date <YYYY-MM-DD>] [--cwd <dir>]` 가
   `<작업 트리 루트>/docs/superpowers/interview/<날짜>-<topic>-interview.state.md` 를 낸다. 작업 트리 루트는
   `git rev-parse --show-toplevel` 이다(메인 레포가 아니라 인터뷰가 도는 worktree). git 저장소가 아니면(그 명령이 실패하면)
   `--cwd`(없으면 현재 디렉토리)를 작업 트리 루트로 쓰고 「git 저장소가 아니다 — <디렉토리> 기준으로 경로를 냈다」 한 줄을 stderr
   로 낸다 — §1-5 의 「git 저장소가 아니면 사유를 보이고 진행한다」와 같은 쪽이다. topic 이 kebab 이 아니면 exit 2.
   계산한 세 경로 — 상태(`.state.md`) · brief(`-interview.md`) · audit(`.audit.md`) — 중 이미 있는 파일의 frontmatter `type:` 이
   그 자리의 종류(각각 `interview-state` · `interview-brief` · `interview-audit`)와 다르면(seed 의 `interview-seed` · seed audit 의
   `interview-seed-audit` · `type:` 없음 포함) 경로를 내지 않고 그 파일 경로와 `type:` 값을 stderr 로 내며 exit 2. 진입 단계는 그
   사유를 보이고 멈춘다 — 남의 파일 위에 인터뷰를 시작하지 않는다.
3. **형식.** 지금 `state.local.md` 의 frontmatter 키 · 본문(`## R<n>` 라운드 기록 · 조사 원문 · `## audit §2 대기 줄`)을 그대로 쓰고,
   frontmatter 맨 앞에 `type: interview-state` 와 `seed: <seed 경로 | 없음>` 을 더한다. `seed:` 값은 작업 트리 루트 기준 상대경로
   (`docs/superpowers/interview/…`)로 적는다 — 파일이 커밋되어 다른 worktree · 기기에서 읽히므로 절대경로를 쓰지 않는다. §1-4 의
   「같은 seed 를 가리키는가」 비교는 호출된 seed 경로를 realpath 로 푼 뒤 작업 트리 루트 기준 상대경로로 바꿔 글자 그대로 비교한다. 작업 트리 안이라 `Write` · `Edit` 로 고친다
   (지금의 「Bash 로만 갱신」 지시 PN1 은 작업 트리 밖 경로 때문이었으므로 걷는다).
4. **이어 가기.** 진입 단계가 인자를 본다.
   - `@<…>.state.md` 이고 frontmatter 가 `type: interview-state` 이면 그 파일을 읽어 마지막 라운드 다음부터 이어 간다.
     읽은 뒤 `state-migration.md` 의 스키마 이월을 적용한다(이월 대상이 이 파일로 바뀔 뿐 규칙은 그대로).
   - seed 경로로 불렀는데 같은 디렉토리에 `seed:` 가 그 seed 를 가리키는 상태 파일이 있고 그 짝 brief 가 아직 없으면,
     `AskUserQuestion` 하나로 「이어 감 (권장)」/「새로 시작」을 묻는다. 새로 시작하면 topic 을 `<topic>-<HHMM>` 으로 바꿔 같은
     `state_path.py interview-state --topic <topic>-<HHMM>` 으로 새 경로를 낸다(`<topic>` 은 §1-1 의 `<seed 주제>-brief` 이고,
     `<HHMM>` 은 숫자라 kebab 규칙을 지킨다). 그 인터뷰의
     brief · audit 도 이 줄기를 따른다. 기존 파일은 지우지 않는다.
   - 경로 계산(`interview-state`)은 **새로 만들 때만** 쓴다. 이어 갈 때는 고른 상태 파일의 절대경로가 그 인터뷰의 정체이고,
     §1-6 의 소비자 전부가 그 경로를 받는다. brief · audit 경로는 그 파일 이름에서 `.state.md` 를 떼어 도출한다 — 날짜 · 주제로
     다시 계산하지 않는다(다른 날 이어 가거나 `-<HHMM>` 이 붙은 파일을 놓치지 않기 위해서다).
5. **끝내기와 커밋.** 세 파일의 경로 지정 커밋은 Step A 가 brief · audit 를 처음 쓴 직후가 아니라 **마지막 확정 뒤** 한 번
   한다 — `finishing.md` Step B-3 의 ①/② 에서 확정 전이(`provisional` → `confirmed`)를 반영하고 `check_brief.py gate` 재실행이
   통과한 뒤(두 줄을 노출하기 전), ④ 「brief 만 종료」에서는 종료 advisory 를 내기 직전이다. ③ 은 B-0 으로 돌아가므로 커밋하지
   않는다. Step A.5 리뷰와 B-3 이 brief 를 고쳐도 커밋이 그 뒤라 마지막 내용이 들어간다. 게이트 재실행이 통과하지 않으면
   커밋하지 않는다. 커밋 꼴은 `git add -- <brief> <audit> <state>` 다음 `git commit --only -- <brief> <audit> <state>` 다
   (새 파일은 git 이 아직 모르므로 경로 지정 `add` 가 먼저다. 다른 staged 작업을 쓸어 담지 않는다).
   - 기본 브랜치는 `git symbolic-ref --short refs/remotes/origin/HEAD` 의 출력(`origin/main` 꼴)에서 `origin/` 접두를 뗀 이름이고,
     현재 브랜치는 `git branch --show-current` 다. 둘이 같으면 커밋하지 않고 세 경로와
     「브랜치에서 커밋하라」 한 줄을 보인다. `origin/HEAD` 가 없어 판정하지 못하면 커밋하지 않고 세 경로와 그 사유를 보인다.
   - git 저장소가 아니거나 커밋이 실패하면 사유를 그대로 보이고 진행한다(파일은 이미 docs 에 있다).
6. **상태 파일을 읽던 곳.** `check_verbatim_coverage.py` · `finishing.md` · audit 템플릿 · reviewing-brief 의 degrade 원장(STATE) 이
   `state.local.md` 를 가리킨다. 모두 그 인터뷰의 상태 파일 경로(§1-4 — 새로 만들 때는 §1-2 의 경로)로 바꾼다.
   - reviewing-brief 는 주제 · 날짜를 모르므로 payload(brief) 경로에서 도출한다: `<줄기>-interview.md` → `<줄기>-interview.state.md`.
   - reviewing-brief 의 `brief-degrade-fallback.txt` 는 세션 폴더(`$ROOT/$harness_sid/`)가 아니라 그 brief 의 원장 폴더
     (§2-1 의 `state-dir-for` 결과) 안으로 옮긴다.
   - request-framing 의 `STATE="$ROOT/$sid/state.local.md"` 줄은 걷는다. 그 degrade 원장은 기존 파일이 있을 때만 쓰였으므로,
     파일이 없을 때의 기존 경로(`no-state-in-phase-0`)가 늘 쓰인다. request-framing 은 세션 폴더를 만들지 않는다(§2-5).
7. **옛 진행 중 인터뷰.** 인터뷰 진입 때 현재 세션의 옛 `<state-root>/<sid>/state.local.md` 가 있으면 §1-2 경로로 한 번 옮기고
   (주제는 그 파일의 기록에서, 없으면 사용자에게 한 번 묻는다) 「옛 위치의 진행 기록을 docs 로 옮겼다 — <경로>」 를 보인다.

### §2 리뷰 원장

1. **경로.** 공유 엔진 `shared/docreview/scripts/docreview_state.py` 의 `state-dir-for` 에서 `--session` 을 뺀다.
   새 경로는 `<state-root>/.docreview/<stem40>-<sha256(문서 realpath)[:16]>` — 해시 규칙은 그대로이고 세션 칸만 빠진다.
   원장 루트 이름은 점으로 시작하는 `.docreview` 다. 옛 버전의 정리 코드(`spec-distill-gc.py`)는 세션 폴더를 이름 정규식
   `^[A-Za-z0-9_-]{8,}$` 로 고르는데, `docreview` 는 이 정규식에 맞아 아직 옛 버전으로 도는 세션이 원장 전체를 옛 세션 폴더로
   보고 지울 수 있다. `.docreview` 는 점 때문에 정규식 밖이라 옛 버전도 건드리지 않는다.
   엔진의 다른 동작은 바꾸지 않는다. 호출하는 곳(spec-review · reviewing-brief · request-framing · `finishing.md` · 엔진 정본
   `reviewing-document.md` 의 펜스 · 픽스처)을 같은 커밋에서 맞춘다.
2. **이어 받기.** 같은 문서를 새 세션에서 리뷰하면 라운드 · 재리뷰 상한을 이어 받는다. 진입 블록이 원장의 라운드가 1 이상이고
   원장 폴더의 `last-session`(§2-4)이 없거나 현재 세션 id 와 다를 때만 「이전 리뷰 라운드 <n> 에서 이어 간다 — <원장 경로>」 한 줄을
   보인다 — 같은 세션 안의 다음 라운드에서는 나오지 않는다. 상한에 닿았으면 지금처럼 승인 게이트에서 사용자가 연다.
3. **worktree.** 해시는 문서의 realpath 라서 worktree 마다 다르다 — 다른 worktree 의 같은 문서는 원장이 따로다. state-root 는 지금처럼
   `git rev-parse --git-common-dir` 로 메인 레포의 `.claude/spec-distill` 이다.
4. **동시 리뷰 표지.** 표지는 원장 폴더의 `reviewing-by` 파일(세션 id 한 줄)이고, 새 모듈
   `scripts/ledger_marker.py` 하나만 다룬다. 리뷰를 부르는 spec-distill 진입 블록이 라운드를 시작할 때 부르고, 엔진은 표지를 모른다.
   - `ledger_marker.py acquire --dir <원장 폴더> --session <sid>` — 배타 생성(`os.open` 의 `O_CREAT|O_EXCL`, 이미 있으면 실패하는
     생성)으로 표지를 잡는다. 잡았거나 이미 자기 세션 id 의 표지면 rc 0, 다른 세션 id 의 표지가 있으면 rc 3 과 그 세션 id 를 낸다.
     확인과 생성이 한 시스템 호출이라 두 세션이 동시에 빈 원장에 들어와도 하나만 잡는다. rc 0 을 받은 세션만 라운드를 시작한다.
   - `ledger_marker.py release --dir <원장 폴더> --session <sid>` — 표지의 세션 id 가 부른 세션과 같을 때만 지운다. 다르거나
     없으면 지우지 않고 rc 0 으로 그 사실을 한 줄 낸다. 진입 블록은 finalize 직후가 아니라 **승인 게이트의 응답을 원장에 다
     적은 뒤**(`decide` · `fix` · `ask` · `defer` 등 게이트 답의 기록이 끝난 뒤) 부른다 — finalize 와 게이트 응답 사이에도 원장 쓰기가
     있으므로 그동안 표지가 남아 있어야 한다. 게이트가 다음 라운드로 이어지면 그 라운드는 다시 `acquire` 로 시작한다.
   - `ledger_marker.py check --dir <원장 폴더> --session <sid>` — 표지의 세션 id 가 부른 세션과 같을 때만 rc 0, 표지가 없거나
     다른 세션 id 면 rc 3 과 사유(「표지 없음」 또는 그 세션 id)를 낸다. 원장에 쓰는 명령(엔진 `docreview_state.py` 의 `init` ·
     `begin-round` · `record-findings` · `decide` · `fix` · `ask` · `defer` · `observe-diff` 등과 라우팅의 finalize)은 모두 진입 블록이
     **먼저** 같은 Bash 호출 안에서 `check` 를 부르고, rc 0 이 아니면 그 명령을 부르지 않고 사유를 보이고 멈춘다. 엔진은 표지를
     모른 채로 두고(Non-goals — 엔진 동작 변경은 R2a), 확인은 호출하는 쪽 펜스가 맡는다.
   - rc 3 이면 진입이 멈추고 `AskUserQuestion` 으로 「그만둠 (권장)」/「이어 씀 — 표지를 내 것으로 바꾼다」 를 묻는다. 「이어 씀」을
     고른 뒤에만 `ledger_marker.py takeover --dir <원장 폴더> --session <sid>` 가 같은 폴더의 임시 파일에 새 세션 id 를 쓰고
     `os.replace` 로 표지를 원자적으로 바꾼다. 세션이 죽어 표지가 남은 경우도 같은 질문으로 풀린다.
   - 표지를 넘겨준 세션은 다음 원장 쓰기 앞의 `check` 에서 rc 3 을 받아 멈추고(라운드 중간이어도 더 쓰지 않는다), release 에서도
     남의 표지를 지우지 않으며, 다음 라운드의 acquire 에서도 rc 3 을 받는다.
   - 세션 id 를 얻지 못하면(`state_path.py session-id` 가 빈 값이나 실패) 표지를 잡을 수 없으므로 리뷰를 시작하지 않는다 — 진입이
     사유를 보이고 멈춘다(지금 펜스의 「세션 상태 디렉토리를 특정할 수 없다 — 리뷰 없이 끝났다」 출구와 같은 꼴). 표지 없이 진행하지 않는다.
   - `release` 는 표지를 지울 때 같은 폴더의 `last-session` 파일에 자기 세션 id 를 원자적으로(임시 파일 + `os.replace`) 남긴다.
     §2-2 의 이어 감 줄은 이 값으로 노출 조건을 가린다.
5. **request-framing 의 이름 파일.** `interview-basename` 을 없앤다. request-framing 은 audit 첫 쓰기 때 audit frontmatter 에
   `session_id: <sid>` 를 적고, 이후 라운드는 `docs/superpowers/interview/*-interview.audit.md` 중 frontmatter 가
   `type: interview-seed-audit` 이고 `session_id` 가 현재 세션인 파일 하나로 이름을 되찾는다(인터뷰 audit 템플릿도 `session_id` 를
   가지므로 `type` 조건이 없으면 같은 세션의 인터뷰 audit 이 함께 걸린다. 둘 이상이면 멈추고 경로들을 보인다). 이로써 `.claude/spec-distill/` 아래에는
   `.docreview/` 만 남는다.

### §3 훅 · 정리 · 끄기 스위치 · 옛 폴더 · 레포 규칙

1. **지운다.** `hooks/hooks.json` 의 SessionEnd 항목, `hooks/session-end-cleanup.py`, `scripts/spec-distill-gc.py`.
   spec-distill 에는 설치되는 훅이 남지 않는다. `hook_common.py` 는 다른 소비자(`brief_review_state.py`)가 쓰는 부분만 남긴다.
2. **새 정리 모듈 `scripts/ledger_sweep.py`.** 리뷰를 시작하는 진입 블록 셋(spec-review · reviewing-brief · request-framing 의 리뷰)이
   원장 경로를 연 직후 한 번 부른다.
   - ① `<state-root>/.docreview/*/docreview-state.md` 에 기록된 문서 경로가 더는 없는 원장 폴더를 지운다. `gc_one` 의 TTL 검사를
     그대로 받으므로 「문서 없음 + 원장 폴더에 TTL 동안 쓰기 없음」 일 때만 지운다. 다른 브랜치로 체크아웃해 문서가 잠시 없는 경우는
     TTL 안이면 남는다. TTL 을 넘겨 다른 브랜치에 있다가 돌아오면 원장은 사라지고 리뷰는 라운드 1 부터 다시 센다(알려진 한계 —
     사용자 결정은 문서의 결정 절에 남는다). `docreview-state.md` 가 없거나 읽히지 않거나 기록된 문서 경로를 얻지 못하는
     원장 폴더는 문서가 사라졌는지 알 수 없으므로 지우지 않고 남기며 「원장 정리 — 읽지 못한 원장 <n>개 남김 — <경로들>」 한 줄을
     낸다(진입 블록이 `init` 전에 `mkdir -p` 를 하므로 이런 폴더가 생긴다).
   - ② 옛 세션 폴더 `<state-root>/<sid>/`(세션 이름 정규식 `^[A-Za-z0-9_-]{8,}$` 에 맞는 폴더) 중 `state.local.md` 가 **없고**
     mtime 이 TTL(`DEVBREW_SPEC_DISTILL_TTL_HOURS`, 기본 24)을 넘은 것을 지운다. `.docreview` 는 점으로 시작해 정규식 밖이라
     옛 폴더 후보가 아니다. 지금 도는 옛 버전 세션의 폴더는 TTL 안이라 건드리지 않는다.
     지우기 **전에** 그 폴더의 옛 원장 `docreview/<x>/` 를 하나씩 본다(G4 — 시간 경과가 원장을 지우지 않는다):
     `docreview/<x>/docreview-state.md` 에 기록된 문서(`docreview.doc`)가 아직 있으면 그 원장 폴더를
     `<state-root>/.docreview/<새 키>/` 로 한 번 옮긴다(`os.rename` — 같은 state-root 안이라 원자적). `<새 키>` 는 §2-1 의
     `state-dir-for` 와 같은 규칙(`<stem40>-<sha256(기록된 문서의 realpath)[:16]>`)으로 계산해, 새 버전이 같은 문서를 리뷰할 때
     그 원장을 이어 받는다. 대상 폴더가 이미 있으면 두 원장의 `docreview-state.md` mtime 을 비교해 더 새 쪽을 `.docreview/<새 키>/`
     에 남기고 「옛 원장 충돌 — <새 키>: <옛|새> 쪽을 남겼다」 한 줄을 낸다. 옛 원장이 더 새면 기존 대상을 같은 `.docreview/`
     안의 `.gc-pending-<새 키>-<시각>` 으로 rename 해 비켜 놓고 옮긴다 — 비켜 놓은 폴더는 (c) 의 줍기가 지운다. 단 기존 대상에
     동시 리뷰 표지 `reviewing-by`(§2-4)가 있으면 mtime 과 무관하게 대상을 남긴다(다른 세션이 리뷰 중이다). 기존 대상의
     `docreview-state.md` 가 없거나 읽히지 않아도 비교하지 않고 대상을 남긴다 — 읽지 못한 원장은 남기고 알린다(그 옛 원장도
     옮기지 않고 옛 폴더를 지우지 않으며 「읽지 못한 원장」 줄에 센다).
     기록된 문서 경로를 읽었고 그 문서가 없는 원장만 옮기지 않고 폴더와 함께 지운다. `docreview-state.md` 가 없거나 읽히지
     않거나 문서 경로를 얻지 못하는 원장이 하나라도 있으면 그 옛 폴더는 지우지 않고(옮길 수 있는 원장은 옮긴다) ① 의
     「읽지 못한 원장」 줄에 함께 센다. 옮긴 뒤에 폴더를 지운다.
     ③ 으로 보존되는 폴더와 TTL 안의 폴더의 원장은 옮기지 않는다(옛 버전이 아직 쓰는 중일 수 있다).
   - ③ `state.local.md` 가 있는 옛 세션 폴더는 시간과 무관하게 **지우지 않는다** — 아직 docs 로 옮기지 않은 인터뷰 기록이다
     (§1-7 은 현재 세션의 것만 옮기므로 다른 세션 id 의 기록은 남는다). 그런 폴더가 있으면 「옮기지 않은 옛 인터뷰 기록 <n>개 —
     <경로들>」 한 줄을 낸다. 옮기거나 지우는 일은 사용자의 몫이다.
   - 삭제는 `gc_common.py` 의 `gc_one`(grace · double-stat · rename 후 rmtree)과 루트 탈출 거부를 그대로 쓴다. `gc_one` 이
     전제하던 호출자 쪽 안전 단계는 지워지는 `spec-distill-gc.py` 에만 있었으므로 `ledger_sweep.py` 가 이어 받는다:
     (a) 정리 전체를 `gc_common.py` 의 루트 디렉토리 잠금(`locked_root`) 안에서 돌려 두 세션이 동시에 정리하지 않게 한다.
     (b) `.docreview` 자신이 심볼릭 링크이거나 루트 밖으로 풀리면 ① 을 건너뛰고 「원장 정리 — 셀 수 없음(<사유>)」 을 낸다.
     (c) 삭제 도중 끊겨 남은 중간 폴더 `.gc-pending-*` 를 `gc_one` 이 만드는 두 자리 — `<state-root>/` 와 `<state-root>/.docreview/`
     — 모두에서 줍는다.
   - 결과를 한 줄로 낸다: 「원장 정리 — 문서 없는 원장 <a>개 · 옛 세션 폴더 <b>개 지움 · 옛 원장 <c>개 옮김」(셋 다 0 이면 내지 않는다). ③ 의 줄 · 옛 원장 충돌 줄 · 읽지 못한 원장 줄은
     따로 낸다. 셀 수 없으면 「원장 정리 — 셀 수 없음(<사유>)」. 루트 잠금(`locked_root`)을 다른 세션이 쥐고 있어 이번에 정리하지
     않았으면 「원장 정리 — 건너뜀(다른 세션이 정리 중)」 한 줄을 낸다 — 정리할 것이 없어 내지 않는 경우와 구별된다.
3. **끄기 스위치.** `ledger_sweep.py` 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 과 옛 `DEVBREW_SKIP_HOOKS` 토큰 셋
   `spec-distill:SessionEnd` · `spec-distill:session-end-cleanup` · `spec-distill:spec-distill-gc` 를 모두 존중한다 — 지금 이 셋은
   다 시간 기준 정리를 멈추므로(앞의 둘은 훅 전체, 셋째는 GC 만), 훅이 없어져도 정리를 꺼 둔 사용자에게 삭제가 조용히 다시
   켜지지 않게 셋 다 그대로 읽는다. 은퇴하는 이름은 없다 — 셋 다 「리뷰 진입 때의 원장 정리를 끈다」는 새 뜻을 갖고, README 의
   스위치 목록과 CHANGELOG `Changed` 에 그 뜻을 적는다.
4. **버전.** 상태 위치가 바뀌고 훅이 없어지므로 spec-distill major bump(번호는 머지 직전).
5. **레포 규칙.** CLAUDE.md 「런타임 상태 & 훅」 절의 state 줄을 고친다: 인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에,
   짧은 리뷰 원장은 `.claude/<plugin>/` 아래 문서 단위로 두고 문서가 사라질 때 정리한다. 「JSON 이 아니라 마크다운」 ·
   「Secret 기록 금지」 · 「plugin namespace 하위」 는 그대로. 다른 줄은 건드리지 않는다(나머지 규칙 정리는 R9).
6. **README.** P14 의 state 서술, Hooks 표(없음), 스위치 목록(옛 토큰 셋이 이제 리뷰 진입 정리를 끈다는 것 · TTL 이 두 자리에 쓰인다는 것 —
   문서가 사라진 원장의 삭제 유예(§3-2 ①)와 옛 세션 폴더의 정리 판정(§3-2 ②) · `state.local.md` 가 있는 옛 폴더는 지우지 않는다는 것).

### §4 위험에 대한 답

- K5(한 세션이 압축을 여러 번 겪어도 의도와 지도를 잃지 않는다는 숨은 가정) · K9(압축 뒤 지도 · 결정 내력 소실) — 인터뷰 진행
  기록이 작업 트리의 docs 파일이 되어(§1) 압축 · 세션 종료 · 다른 세션의 정리로 사라지지 않는다. 에픽 지도는 R0 의 추적 로드맵이
  이미 맡는다(D29 · OQ12). 리뷰 원장은 문서 단위가 되어(§2) 다른 세션의 SessionEnd · TTL 로 지워지지 않는다(RC37).
- RC15(규칙) — §3-5 에서 규칙을 실제와 맞춘다. RC60(선례) — 오래 남을 정보는 docs 로, 세션 state 에는 아무것도 두지 않는다.
- OQ37(로드맵 정의와 살아 있는 단계의 자리) — 정의는 추적 파일, 단계는 git 에서 계산(R0 `roadmap_status.py`). 이 에픽은 바꾸지 않는다.
- 새 위험: 문서 단위 원장의 동시 쓰기 — §2-4 표지(배타 생성 · 원장 쓰기마다 소유자 확인 · 게이트 응답 기록 뒤 소유자만 해제). 옛 버전 정리 코드의 원장 삭제 — §2-1 `.docreview`.
  옛 세션 폴더의 미이월 인터뷰 기록 — §3-2 ③ 보존. 옛 세션 폴더 안의 리뷰 원장 — §3-2 ② 가 지우기 전에 새 자리로 옮긴다.
  seed 와 같은 날 인터뷰의 경로 겹침 — §1-1 `-brief` 꼬리와 §1-2 의 종류 다른 파일 거부. 상태 파일의 작업 트리 노출(커밋 전 untracked) — §1-5 커밋 규칙과 기본 브랜치 거부.

### §5 인터페이스

- 넘기는 것(R1 · R3 · R4): 인터뷰 상태 경로는 `state_path.py interview-state`. R4 가 인터뷰 끝에 쓰는 로드맵 · 묶음은 brief 와 같은
  커밋 규칙(§1-5)을 따른다.
- 넘기는 것(R2a): `state-dir-for` 는 `--root --doc` 만 받는다. 엔진이 원장 디렉토리를 다른 곳에서 계산하지 않게 한다.
- 받는 것(R0): 로드맵 기반 에픽 이어 하기(`roadmap_status.py`).

## Acceptance Criteria

- AC1 `state_path.py interview-state --topic t --date 2026-10-15 --cwd <worktree>` 가 `<worktree>/docs/superpowers/interview/2026-10-15-t-interview.state.md` 를 낸다. kebab 이 아닌 topic 은 exit 2. 같은 날 seed `2026-10-15-t-interview.md`(`type: interview-seed`) 또는 seed audit `2026-10-15-t-interview.audit.md`(`type: interview-seed-audit`)가 있으면 `--topic t` 는 경로를 내지 않고 exit 2 이고, `--topic t-brief` 는 `2026-10-15-t-brief-interview.state.md` 를 낸다(픽스처 — 상태 · brief · audit 세 자리 각각의 종류 다른 파일과 양성 대조).
- AC2 `plugins/spec-distill` 의 production 표면(SKILL · references · scripts · templates)에서 `state.local.md` 는 §1-7 이월 문면과 `ledger_sweep.py` 의 옛 폴더 정리에만 남는다.
- AC3 상태 파일 frontmatter 첫 키는 `type: interview-state`, 다음 `seed:`. 진입 단계가 `@<…>.state.md` 를 받으면 이어 가는 분기로 간다(SKILL 문면 + 펜스 출력 단언). seed `<날짜>-<주제>-interview.md` 로 시작한 인터뷰는 `--topic <주제>-brief` 로 경로를 내므로 그 brief · audit · 상태 파일 경로가 seed · seed audit 경로와 겹치지 않는다(SKILL 문면 + 같은 날 픽스처).
- AC4 같은 seed 의 끝나지 않은 상태 파일이 있으면 「이어 감 (권장)」/「새로 시작」 질문이 뜨고, 새로 시작은 기존 파일을 지우지 않는다.
- AC5 `finishing.md` 는 brief · audit · state 세 경로만 `--only` 로 커밋하고, 그 커밋은 Step A 직후가 아니라 Step B-3 ①/② 의 확정 반영과 `check_brief.py gate` 재실행 통과 뒤(④ 는 종료 advisory 직전) 한 번이다 — Step A 와 Step A.5 에는 커밋 문면이 없고, ③ 은 커밋하지 않는다(문면 순서 단언). 기본 브랜치에서는 커밋하지 않고 세 경로를 보인다(픽스처 git 저장소로 두 분기 다 확인).
- AC6 `docreview_state.py state-dir-for` 는 `--session` 을 받지 않고(주면 exit 2) `<root>/.docreview/<stem40>-<hash16>` 을 낸다. 호출하는 펜스 전부가 `--session` 없이 부른다. 옛 버전 `spec-distill-gc.py` 의 세션 이름 정규식은 `.docreview` 에 맞지 않는다. TTL 0 은 `ttl_ns` 가 0 이하를 기본 24시간으로 바꾸므로 검증에 쓰지 않는다. 픽스처: 옛 GC 를 `DEVBREW_SPEC_DISTILL_TTL_HOURS=1` 로 두고 `.docreview/` 와 그 아래 모든 항목의 mtime 을 2시간 전으로 돌린 뒤(옛 GC 는 폴더 아래 최신 mtime 을 나이로 잰다) 돌려도 새 원장이 남는다. 같은 실행의 양성 짝 둘: mtime 이 같은 2시간 전인 정규식에 맞는 이름 폴더(옛 `docreview` 이름 포함)는 지워지고 — 이 설정이 실제로 지운다는 증거 — mtime 이 지금인 정규식에 맞는 폴더는 남는다 — 지움이 TTL 1시간으로 갈린다는 증거.
- AC7 원장 라운드가 1 이상이고 원장 폴더의 `last-session` 이 없거나 현재 세션 id 와 다를 때만 진입 블록이 「이전 리뷰 라운드 <n> 에서 이어 간다」 를 낸다 — 같은 세션의 다음 라운드(`last-session` 이 현재 세션 id)에서는 내지 않는다(두 분기 픽스처).
- AC8 `ledger_marker.py`: 빈 원장에 두 세션이 동시에 `acquire` 하면 하나만 rc 0 이다(배타 생성) · 다른 세션 id 의 표지가 있으면 rc 3 이고 진입이 멈춰 질문한다 · `release` 는 남의 표지를 지우지 않는다 · 자기 표지는 finalize 직후에는 남아 있고 승인 게이트 응답을 원장에 적은 뒤에 사라진다(문면 순서 + 픽스처) · `check` 는 표지가 부른 세션의 것일 때만 rc 0 이고 표지가 없거나 다른 세션이면 rc 3 이다 — 원장에 쓰는 진입 펜스의 명령마다 그 앞에 `check` 가 있고 rc 0 이 아니면 그 명령이 돌지 않는다(남의 표지 · 표지 없음 두 분기 픽스처, 원장 파일이 바뀌지 않음을 단언) · `takeover` 는 「이어 씀」 선택 뒤에만 불리고 표지를 임시 파일 + `os.replace` 로 바꾼다.
- AC9 `ledger_sweep.py`: 문서 없는 원장만 지운다 · 문서 있는 원장은 남긴다 · `.docreview` 는 옛 폴더로 보지 않는다 · TTL 넘은 옛 세션 폴더 중 `state.local.md` 가 없는 것만 지운다 · 그 폴더를 지우기 전에 기록된 문서가 있는 `docreview/<x>/` 원장을 `.docreview/<새 키>/` 로 옮기고, 옮긴 경로는 `state-dir-for` 가 같은 문서에 내는 경로와 같다 · 대상이 이미 있으면 `docreview-state.md` mtime 이 더 새 쪽을 남기고(대상에 `reviewing-by` 가 있으면 대상을 남긴다) 충돌 줄을 낸다 · 기록된 문서가 없는 옛 원장만 폴더와 함께 지운다 · `docreview-state.md` 가 없거나 읽히지 않는 원장(새 자리 · 옛 폴더 · 충돌한 기존 대상 모두)은 지우지 않고 「읽지 못한 원장」 줄을 낸다 — 읽지 못한 원장을 지우는 분기는 없다 · `state.local.md` 가 있는 옛 폴더는 TTL 을 넘어도 남기고 「옮기지 않은 옛 인터뷰 기록 <n>개 — <경로들>」 을 낸다 · 루트 탈출 링크를 거부한다 · `DEVBREW_SPEC_DISTILL_DISABLE=1` 과 `DEVBREW_SKIP_HOOKS` 의 `spec-distill:SessionEnd` · `spec-distill:session-end-cleanup` · `spec-distill:spec-distill-gc` 각각에서 아무것도 지우지 않는다.
- AC10 `hooks/hooks.json` 에 훅 항목이 없고 `session-end-cleanup.py` · `spec-distill-gc.py` 가 없다. 양의 짝: 리뷰 진입 셋이 `ledger_sweep.py` 를 부른다.
- AC11 request-framing 에 `interview-basename` 이 없고, audit frontmatter `session_id` 로 이름을 되찾는다(둘 이상이면 멈춤).
- AC12 옛 `<sid>/state.local.md` 가 있으면 인터뷰 진입이 docs 로 옮기고 그 사실을 보인다.
- AC13 README · CHANGELOG: 옛 스위치 토큰 셋이 리뷰 진입 정리를 끈다는 새 뜻(CHANGELOG `Changed`), TTL 의 범위, `state.local.md` 가 있는 옛 폴더의 보존, Hooks 표. CLAUDE.md 의 state 줄이 §3-5 대로다.
- AC14 spec-distill major bump, quality-gates patch bump(공유 엔진 파일의 심볼릭 링크 — Metadata).
- AC15 통과가 정답인 새 락(AC2 · AC6 · AC8 · AC9 · AC10)은 변이로 이빨을 확인한다 — 삭제 · 추가 · 반전 축.

## Files to Modify

- `plugins/spec-distill/scripts/state_path.py` (+ `interview-state`), 새 `plugins/spec-distill/scripts/ledger_sweep.py` · 새 `plugins/spec-distill/scripts/ledger_marker.py`
- `shared/docreview/scripts/docreview_state.py` (`state-dir-for`), `shared/docreview/references/reviewing-document.md` (펜스), `shared/tests/test_docreview_state.sh` · `shared/tests/fixtures/docreview/cases*.sh` · `shared/tests/test_docreview_mutations.sh`
- `plugins/spec-distill/skills/spec-interview/SKILL.md` · `references/finishing.md` · `references/state-migration.md`
- `plugins/spec-distill/skills/spec-review/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/request-framing/SKILL.md`
- `plugins/spec-distill/scripts/check_verbatim_coverage.py` · `templates/interview-audit-template.md`
- 삭제: `plugins/spec-distill/hooks/session-end-cleanup.py` · `plugins/spec-distill/scripts/spec-distill-gc.py`; 수정: `hooks/hooks.json` · `scripts/hook_common.py`
- 테스트: `test_gc.py` · `test_session_end_cleanup.py` 를 새 `test_ledger_sweep.*` 로, 새 `test_ledger_marker.*`, `test_state_path.sh` · `test_reviewing_spec_state_keying.sh` · `test_kill_switches_v060.sh` · `test_hooks.sh` · `test_seed_gate_wiring.sh` · `test_finishing_block_scope.py` · `test_readme_sync.sh` · `test_stale_terms.sh` 및 경로 문자열을 단언하는 테스트들
- `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`, 레포 `CLAUDE.md` (state 줄 하나)
- `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md` (patch — `plugins/quality-gates/scripts/docreview_state.py` 가 공유 엔진 파일의 심볼릭 링크라 배포 바이트가 바뀐다)

## Verification Plan

- 작업 전 기준선: spec-distill · shared 스위트의 FAIL «이름» 집합을 잰다(선재 RED `test_hook_output_schema.py test_python_and_bash_resolvers_agree` 포함).
- Task 마다 닿은 소비자 전부의 스위트를 레포 루트에서 돈다. 삭제 Task 는 guards 커버리지 락을 돈다.
- 픽스처 git 저장소(버릴 디렉토리, `mktemp` 경로를 `cd` 전에 비지 않았는지 확인)로 §1-5 커밋 두 분기 · §2-4 표지(동시 `acquire` 두 프로세스 · 남의 표지 `release` · `takeover` · 넘겨준 세션의 다음 쓰기가 `check` 에서 멈춤 · 게이트 응답 기록 전에는 표지가 남음) · §3-2 정리(옛 GC 로도 `.docreview` 가 남음 · `state.local.md` 가 있는 옛 폴더 보존 · 옛 원장 이월과 대상 충돌 · 옛 토큰 셋) · §1-2 seed 와 같은 날 경로 거부를 확인한다.
- 새 락 다섯(AC15 — AC2 · AC6 · AC8 · AC9 · AC10)은 변이로 RED 를 확인하고 양성 대조를 둔다.
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

### 리뷰 결정

- D2.1 · r2 · adopt · 3d76d97e#r1.1 · "넷 모두 고친다 (권장)" — 표지 확인과 쓰기가 분리돼 있어 두 세션이 동시에 빈 원장에 들어오면 둘 다 리뷰를 시작할 수 있다. 표지를 빼앗는 경우에도 기존 세션의 쓰기를 막지 못한다.
- D2.2 · r2 · adopt · 3d76d97e#r2.1 · "넷 모두 고친다 (권장)" · supersedes D2.1 — 표지 확인과 쓰기가 분리돼 있어, 두 세션이 동시에 빈 원장에 들어오면 둘 다 리뷰를 시작한다. 표지를 넘겨받은 뒤에도 원래 세션이 finalize 에서 새 주인의 표지를 지울 수 있다.
- D2.3 · r2 · adopt · 44e246a3#r1.1 · "넷 모두 고친다 (권장)" — 옛 세션 폴더를 시간만으로 삭제하면 아직 옮기지 않은 인터뷰와 리뷰 원장도 삭제된다. 오래 기록하지 않았다는 사실은 세션이 끝났거나 기록이 불필요하다는 증거가 아니다.
- D2.4 · r2 · adopt · 44e246a3#r1.2 · "넷 모두 고친다 (권장)" — 은퇴시키는 두 스위치는 기존 코드에서 시간 기준 정리 실행까지 막았다. 새 정리 모듈이 이 이름을 무시하면 정리를 꺼 둔 사용자의 삭제 동작이 다시 켜진다.
- D2.5 · r2 · adopt · 44e246a3#r2.1 · "넷 모두 고친다 (권장)" · supersedes D2.4 — 은퇴시키는 두 끄기 스위치(SessionEnd · session-end-cleanup)는 지금 시간 기준 정리까지 함께 멈춘다. 새 정리 모듈은 이 둘을 읽지 않으므로, 이 이름으로 정리를 꺼 둔 사용자에게는 삭제가 조용히 다시 켜진다. 문서 자신의 제약과 어긋난다.
- D2.6 · r2 · adopt · 7ec95fa7#r1.1 · "넷 모두 고친다 (권장)" — 실행 중인 옛 버전의 정리 코드는 새 `docreview` 폴더를 세션 폴더로 인식한다. 현재 코드의 이름 검사와 시간 기준을 대조하면, 새 버전에서만 이름을 제외해도 옛 버전의 삭제는 막을 수 없다.
- D3.1 · r3 · adopt · 3d2c93fa#r1.1 · "둘 다 고친다 (권장)" — seed 로 시작한 인터뷰가 seed 의 주제를 이름으로 쓰면 같은 날의 brief · audit 경로가 seed · seed audit 와 같아져 덮어쓴다. seed 에서 온 인터뷰 주제에 `-brief` 꼬리를 붙이고, 경로 스크립트는 계산한 경로에 종류 다른 파일이 있으면 exit 2 로 거부한다(§1-1 · §1-2 · AC1 · AC3).
- D3.2 · r3 · adopt · acc785c7#r1.1 · "둘 다 고친다 (권장)" — 옛 세션 폴더 안의 리뷰 원장이 새 자리로 옮겨지지 않고 TTL 뒤 폴더째 지워져 G4 와 어긋난다. 정리 모듈이 옛 폴더를 지우기 전에 기록된 문서가 있는 원장을 `.docreview/<새 키>/` 로 한 번 옮기고(충돌 시 더 새 쪽을 남기고 알림) 문서 없는 원장만 지운다(§3-2 ② · AC9).
- 결정 · 2026-10-15 · 표지 해제 시점과 쓰기 전 소유자 확인(3d76d97e#r1.1) — 「넷 다 고치고 승인으로 (권장)」 · 리뷰 뒤 반영(이 변경은 리뷰 라운드를 거치지 않았다) — `reviewing-by` 는 finalize 직후가 아니라 승인 게이트 응답을 원장에 적은 뒤 해제하고, 원장에 쓰는 명령마다 먼저 `ledger_marker.py check` 로 표지 주인이 자기 세션인지 확인해 아니면 사유를 보이고 멈춘다(§2-4 · AC8).
- 결정 · 2026-10-15 · 읽지 못한 옛 원장의 처리 확인(44e246a3#r1.1) — 「넷 다 고치고 승인으로 (권장)」 · 리뷰 뒤 반영(이 변경은 리뷰 라운드를 거치지 않았다) — 「읽지 못한 옛 원장은 남기고 알린다」를 유지하고, 옛 원장 충돌에서 기존 대상이 읽히지 않는 경우도 남기도록 맞췄다(§3-2 ② · AC9).
- 결정 · 2026-10-15 · 세 파일 커밋 시점(866b69d6#r1.1) — 「넷 다 고치고 승인으로 (권장)」 · 리뷰 뒤 반영(이 변경은 리뷰 라운드를 거치지 않았다) — 커밋은 Step A 의 첫 쓰기 직후가 아니라 Step B-3 의 확정 반영과 마지막 게이트 재실행 통과 뒤 한 번이다(§1-5 · AC5).
- 결정 · 2026-10-15 · 옛 GC 검증의 TTL(7b7d0951) — 「넷 다 고치고 승인으로 (권장)」 · 리뷰 뒤 반영(이 변경은 리뷰 라운드를 거치지 않았다) — `ttl_ns` 가 0 이하를 24시간으로 바꿔 「TTL 0」 검증이 공허하므로, TTL 1시간과 2시간 전 mtime 으로 돌리고 양성 짝(늙은 정규식 폴더는 지워짐 · 새 폴더는 남음)을 둔다(AC6).

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
- 플러그인: spec-distill major bump(번호는 머지 직전). quality-gates 도 bump — `plugins/quality-gates/scripts/docreview_state.py` 가
  `shared/docreview/scripts/docreview_state.py` 의 심볼릭 링크라 그 파일의 배포 바이트가 바뀐다(patch, 번호는 머지 직전)
- 경로 예약 밖 편집(정보): `shared/docreview/` (R2a 예약 — 경로 함수 하나), `CLAUDE.md` (R9 예약 — state 줄 하나), `finishing.md` (R3 예약), `spec-interview/SKILL.md` (R1 예약)

### Deferred to plan

- `hook_common.py` 에서 남길 함수와 지울 함수의 정확한 경계(소비자 grep).
- `docs/superpowers/interview/` 를 훑는 기존 규칙 · 락(미실행 seed 판별 등)이 `.state.md` 를 오분류하지 않는지 — 금지 토큰 · 코퍼스 선대조.
- 경로 문자열을 단언하는 테스트의 전수 목록(`git grep` 으로 `state.local.md` · `interview-basename` · `--session` · `spec-distill-gc` · `session-end-cleanup`).
- `SKILL.md` 줄 예산(R1 에서 상한 502).
| ef79c297#r1.1 | 계획 단계의 낡은 문구 전수 검색이 식별자만 찾는다. 그래서 같은 개념을 다른 말로 쓴 문장이 남는다 — 예: finishing.md B-3 ④ 「state는 SessionEnd hook이 cleanup」, README P14 「SessionEnd 가 지운다」, spec-interview/SKILL.md 「per-session 격리」·「PN1 Bash write contract」. 「SessionEnd」·「TTL-GC」·「세션 수명」·「Bash 로만 갱신」 같은 개념 별칭도 검색 목록에 넣는다. |
