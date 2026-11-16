# 앞단의 끝 (F4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 끝맺음이 넘김 글을 짧은 줄 하나와 지시 파일로 쓰고, 모델이 이유를 적고 건너뛴 조사 · 리뷰를 구조 검사가 받아 끝 질문 앞에서 사용자에게 보이며, superpowers 가 없어도 끝 질문으로 확정 · 커밋까지 가고, 머지된 PR #274 의 잔여 셋을 고친다.

**Architecture:** 끝맺음 절차 파일(`finishing.md`)과 그 이웃 넷(구조 검사 `check_brief.py` · 인터뷰 본문 · 포화 판정 reference · 결과물 리뷰 skill)을 고친다. 넘김 지시는 새 지시 파일 `references/brief-handoff.md` 로 옮기고 넘김 줄은 그 파일의 절을 가리킨다. 건너뜀은 한 줄 문법 하나로 흐른다 — 쓰는 곳(인터뷰 본문 · 리뷰 skill) → 상태 파일의 `## audit §2 대기 줄` 블록 → audit §2 → `check_brief.py` 의 검사와 advisory → 끝 질문 앞 글. 머지 잔여는 `finishing.md` 의 셸 펜스 안에서만 고친다(공유 엔진 · 설정 해결자 · gh 모듈은 그대로다).

**Tech Stack:** Python 3.9 표준 라이브러리(`check_brief.py`), bash 3.2 · zsh 양쪽에서 도는 마크다운 안 셸 펜스, 셸 테스트(`shared/tests/assert.sh`), skill · reference 마크다운.

**Spec:** `docs/superpowers/specs/2026-11-15-front-stage-exit-design.md`

**짝 문서:** `docs/superpowers/plans/2026-11-15-front-stage-exit-edits.md` — 바꿀 글(찾을 글 → 바꿀 글) · 새 파일 전문 · 테스트 블록 · 시제품 패치 · 변이 표. 이 계획의 과제가 「편집 F10」 · 「블록 T6」 · 「패치 A」 처럼 가리킨다. 전부 계획 단계에서 제자리에 걸어 돌려 본 글이다 — 구현자는 그 글을 그대로 쓰고, 지금 코드와 맞지 않으면(찾을 글이 한 번이 아니다 · 패치가 걸리지 않는다) 멈춰 보고한다.

## Global Constraints

- **브랜치 · 커밋.** 브랜치는 이미 서 있는 `feature/front-stage-exit` 다. 커밋은 pathspec 으로만 한다. 쓰지 않는 것: `git add -A` · `git stash` · reset · rebase · force.
- **커밋 메시지.** Conventional Commits, 설명은 한국어, scope 는 `spec-distill`(예: `feat(spec-distill): 건너뜀 줄을 구조 검사가 받는다 (F4)`). 구현 커밋에 트레일러 `Spec: docs/superpowers/specs/2026-11-15-front-stage-exit-design.md` 를 달고, 끝줄은 그 세션의 attribution 지시를 따른다.
- **고치지 않는 파일.** `shared/docreview/**`(공유 엔진과 절차서 정본) · `plugins/spec-distill/references/proceed-gate.md` · `references/reviewing-document.md` · `references/epic-handoff.md` · `scripts/repo_defaults.py` · `scripts/gh_repo.py`. 설계문서 본문도 고치지 않는다 — 마지막 과제의 `## 미룸` 표 행 추가만 예외다.
- **건너뜀 줄 문법**(글자 그대로): `- 모델 판단으로 건너뜀 — <자리>: <이유>`. `<자리>` 는 `범위 조사` · `맹점 조사` · `포화 판정` · `재비판` · `codex` · `읽어 보기` 가운데 하나, `<이유>` 는 빈칸이 아닌 글. 줄의 집은 상태 파일의 `## audit §2 대기 줄` 블록이다.
- **advisory**(글자 그대로): `건너뜀 — <자리>: <이유> (모델 판단 — 사람이 확인할 것)`.
- **나눈 일 선.** brief §7 에 `분해됨 — ` 줄이 있는데 건너뜀 줄이 하나라도 있으면 구조 검사가 실패하고, 사유 글에 「나눈 일은 건너뛸 수 없다」 를 싣는다.
- **지시 파일의 절 이름**(글자 그대로): `## brainstorming 지시` · `## 공통 지시`. 한 절이 다른 절을 가리키지 않는다. 그 파일은 지시만 담는다(출처 · 이력을 쓰지 않는다).
- **머지 펜스의 줄**(글자 그대로): 표시 줄 `interview-merge-requested: <PR 번호>`, 판결 줄 `interview-merge: MERGED` · `interview-merge: NONE`.
- **셸.** 펜스와 테스트는 bash 3.2 와 zsh 양쪽에서 돈다는 전제로 쓴다 — 한글 바로 앞 변수는 `${v}`, heredoc 을 `$( )` 안에 넣지 않는다, `PIPESTATUS` 를 쓰지 않는다. 새 셸 테스트 파일을 만들면 실행 비트(100755)를 준다 — 없으면 스위트가 세지 않는다.
- **레포 전용 값.** 경로 · 브랜치 · 테스트 명령을 박지 않는다 — 해결자(`repo_defaults.py`)에서 읽는다.
- **질문 자리.** 질문 자리를 더하거나 바꾸면 `shared/tests/fixtures/ask-sites.tsv` 를 같은 커밋에서 고친다.
- **판 번호.** 박지 않는다 — 마지막 과제가 머지 직전 기본 브랜치 위의 다음 minor 를 그때 읽어 쓴다(옆 로드맵의 PR 과 다른 에픽이 같은 번호를 노린다).
- **테스트 실행.** 과제 안에서는 좁은 테스트와 좁은 러너(과제 1 이 만든다)만 돌린다. 전체 스위트의 러너는 `bash tools/suite/run-all.sh` 이고 아래 잠금 줄로만 돌린다 — `--owner` 값은 그 담당자에게 지휘자가 준 이름으로 바꾸고, 기다림은 줄이며, 못 잡으면(종료 코드 75) 그 줄의 주인 · 잡은 시각을 보고한다. 하위 agent 에게 보내는 글에도 이 줄을 그대로 싣는다.

  ```
  python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/suite_lock.py" run --lock "/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock" --owner f4-plan --wait 2400 -- bash -c 'bash tools/suite/run-all.sh'
  ```

- **이빨 확인.** 통과가 정답인 단언을 더한 과제는 변이 걸음을 건너뛰지 않는다. 변이는 그 과제의 커밋 뒤에 한다 — `cp` 로 백업 → 고침 → 테스트 → 백업에서 되돌림 → `git status --short` 가 비었는지 확인. 살아남는 변이가 있으면 단언을 보강해 다시 잰다. 파이썬 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. 변이 표(변이 · 실패한 단언)를 과제 보고에 싣는다.
- **사람에게 쓰는 글.** 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일(기본 하나 — 여럿이거나 병렬이면 밝힌다).

## Review Focus

설계가 뜻하지만 설계의 검증 계획이 재지 않는 입력 다섯 — 사람을 가장 먼저 물 것부터. 줄마다 그것을 박는 테스트가 그 과제에 있다.

1. **건너뛴 조사를 뒤에 돌리고 건너뜀 줄을 지우지 않았다** — `coverage-mapper 2` 인데 `범위 조사` 줄이 남았다 · 포화 판정 줄이 있는데 `포화 판정` 줄이 남았다 · 사용자 발화로 닫힌 맹점 차원인데 `맹점 조사` 줄이 남았다. 사용자는 돌린 조사가 「건너뛴 것」 으로 보이지 않기를 기대한다 — 구조 검사가 실패로 막고 그 줄을 지우라고 말한다. → 과제 2
2. **건너뜀 줄의 이유 글에 다른 줄의 글자가 섞인다** — `coverage-mapper 3` · `포화 판정 1: 포화 — …` · `:` · `—`. 문법은 첫 `: ` 에서만 자리와 이유를 가르고, mapper · 포화 판정 검사는 그 줄을 자기 줄로 읽지 않는다. → 과제 2
3. **건너뜀 줄이 `*` 불릿이거나 들여 쓴 줄이다** — 형제 줄(mapper · 포화 판정)과 같은 불릿 어휘로 읽는다. 한 꼴에서만 통과하고 다른 꼴에서 조용히 사라지지 않는다. → 과제 2
4. **다시 확인 펜스가 PR 을 읽지 못한다**(gh 인증 만료 · 네트워크) — 머지됨으로 읽지 않고, 읽지 못했다는 사실과 PR 주소를 내고 `interview-merge: NONE` 으로 끝난다. → 과제 8
5. **다음 세션이 지시 파일을 읽지 못한다**(넘김 줄을 만든 뒤 플러그인 판이 바뀜 · 읽기 승인 거절) — 지시 없이 조용히 시작하지 않는다. 넘김 줄이 「읽지 못하면 추측하지 말고 멈춰 보고한다」 를 싣는다(등호 단언). → 과제 3

## 다시 확인 · 설계와 어긋나는 자리 · 계획이 정한 것

**다시 확인(계획을 쓴 시점, 브랜치 끝 6b923b62).** 설계문서가 근거로 든 자리 서른여덟 곳(줄 번호 · 함수 · 문장)이 지금 코드에서도 그대로다 — 과제 1 의 스크립트로 쟀다. 과제 1 이 구현 시점에 다시 잰다.

**설계와 어긋나는 자리.** 설계 본문은 고치지 않았다. 구현은 아래대로 간다.

| # | 설계 | 계획 | 까닭 |
|---|---|---|---|
| 가 | 설계 1 은 넘김 줄의 경로를 `<플러그인 절대경로>` 자리표로 적는다 | 줄에는 `${CLAUDE_PLUGIN_ROOT}` 로 쓴다(뜻은 같다 — 555행 규칙이 절대경로로 바꿔 노출한다) | 줄 안의 꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름뿐이어야 한다는 락(`test_review_handoff_order.sh` 의 `lead_only`)이 있다 |
| 나 | Files to Modify 에 `dependencies.md` 가 없다 | superpowers 행의 「없을 때」 칸을 고친다(과제 10) | 그 칸이 「알린 뒤 멈추고」 라고 옛 동작을 말한다. 이 파일은 로드맵 F4 의 경로 예약에 없다 |
| 다 | audit 템플릿 행이 「§2 줄 모양을 싣고 있으면」 조건부다 | `templates/interview-audit-template.md` §2 설명 두 문단을 고친다(과제 2) | 그 설명이 「사유 없는 0은 게이트 red」 · 「줄이 없거나 … red 다」 를 싣는다(리뷰 지적 641c4e4c#r4.1). 이 파일도 로드맵 F4 의 경로 예약에 없다 |
| 라 | 설계 2 「skill 글」 은 「필수 자리 둘」 세 곳(298 · 386 · 532행)만 든다 | 같은 필수 규칙을 말하는 두 곳(408 · 479행)에도 가리킴 구절을 더한다(과제 4) | 한 곳이라도 「필수」 로만 남으면 어긋난 두 규칙이 된다 |
| 마 | Verification Plan 「끝 화면: 건너뜀 0개 · 1개 · 여럿의 앞 글과 상태 줄을 글자로 본다」 | 끝 질문 앞 글은 모델이 쓰는 글이라 실행 출력으로 재지 못한다 — 그 글을 정하는 규칙 문장(0개면 쓰지 않는다 · 경고 수에 센다 · 한 번만 센다)을 글자로 단언한다(과제 6) | 정적 락의 한계 — 모델이 그 문장을 따르는지는 재지 못한다 |
| 바 | Verification Plan 「리뷰 뒤 다시 짓기」 | 다시 짓는 것은 모델이다 — 다시 지은 «결과» audit 을 픽스처로 만들어 구조 검사가 advisory 를 내는지 · 나눈 일이면 막는지 · 줄을 지우면 통과하는지를 잰다(과제 2). 다시 짓는 걸음이 글에 있는지는 과제 6 이 글자로 단언한다 | 위와 같다 |
| 사 | Files to Modify 의 테스트 목록 | 그 일곱에 더해 옛 문장을 글자로 단언하던 테스트를 고친다 — 과제 1 의 「알려진 자리」 표 | 리뷰가 계획에 넘긴 일(1b5475ac#r1.1) |

**계획이 정한 것(설계가 비워 두었거나 계획에 넘긴 것).**

| # | 정한 것 | 과제 | 사람 결정이 필요한가 |
|---|---|---|---|
| 1 | 지시 파일의 꼴 — 절마다 불릿 한 줄에 문장 하나, 머리에 「가리킨 절 하나만 읽는다 · 플러그인 루트 변수를 읽는 법」 한 줄 | 3 | 아니다 |
| 2 | 엔진의 재비판 경고 줄이 괄호에 `kill switch` 라고 적는 것 — 엔진은 그대로 두고, 끝 질문 앞 글이 그 줄을 쓸 때 `재비판` 건너뜀 줄이 있으면 「끄기 스위치가 아니라 모델 판단」 이라고 덧붙인다(지휘자의 기본 판단 그대로 — 안 되는 까닭을 찾지 못했다) | 6 | 아니다 |
| 3 | 재리뷰 상한이 찬 뒤 건너뛴 재비판 · codex 를 돌릴 때 — 리뷰 skill 의 「추가 라운드 1회 열기」 질문의 답으로만 연다(끝 질문의 기타 칸에 적은 말은 그 승인이 아니다). 열지 않으면 줄을 되돌리고 끝 질문으로 돌아간다 | 6 | 아니다(지금 있는 장치다) |
| 4 | **나눈 일인데 사용자가 추가 라운드를 열지 않을 때** — 끝 질문으로 가지 못한다. 줄을 되돌리고 「나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면 그렇게 말해 달라」 를 보이고 턴을 끝낸다 | 6 | **그렇다** — 설계에 없던 갈래다 |
| 5 | superpowers 가 없는 끝 질문에서 「확정 목록 수정」 을 거듭해 뜨는 재제시 상한 질문의 「지금 목록으로 확정」 은 선택지 셋의 그 끝 질문으로 돌아간다 | 7 | 아니다 |
| 6 | **남은 건너뜀 줄은 실패다** — 건너뛴 조사를 뒤에 돌리고 줄을 지우지 않으면(`coverage-mapper` 1회 이상인데 `범위 조사` 줄 · 판정 줄이 있는데 `포화 판정` 줄 · 발화로 닫힌 맹점 차원인데 `맹점 조사` 줄) 구조 검사가 막는다 | 2 | **그렇다** — 설계의 검사 넷에 없는 검사다(Review Focus 1) |
| 7 | superpowers 가 없는 끝 질문의 글자 — 머리글 `끝내기`, 설명, 끝 안내 줄, 나눈 일이면 보이는 다음 세션 줄은 지휘자 줄 | 7 | 아니다 |
| 8 | 건너뜀 규칙의 정의는 인터뷰 본문 `## 조사 상한 · 포화 판정` 절에 한 번, 줄 모양과 때는 포화 판정 reference 의 새 절 `### 건너뜀` 에 | 4 | 아니다 |
| 9 | 판은 머지 직전 기본 브랜치를 받아들인 뒤 그 위의 다음 minor | 10 | 아니다 |
| 10 | codex 펜스의 건너뜀 입력 — 펜스 지역 변수 `model_skip_codex` 를 따옴표 heredoc(`DEVBREW_MODEL_SKIP_EOF`)으로 읽는다. 다른 사유(끄기 스위치 · 미설치 · 입력 부재 · 중화 실패)가 서면 그 사유가 이기고, 그 라운드에는 건너뜀 줄을 적지 않는다 | 5 | 아니다(설계가 「입력의 모양은 계획이 정한다」 로 넘겼다) |
| 11 | 머지됨 판정은 상태 · 바탕 · 브랜치 · 같은 레포로 한다(끝 커밋은 대조하지 않는다). gh 가 실패로 끝난 뒤 머지된 경우는 「실패로 끝났지만 머지돼 있다」 는 다른 줄을 낸다 | 8 | 아니다 |
| 12 | 다시 확인은 머지 펜스의 갈래가 아니라 읽기만 하는 새 펜스(`interview-merge-recheck`)다. 갈래 넷 — 머지됨 · 끝까지 열림 · 읽지 못함 · 머지됨인데 다른 PR | 8 | 아니다 |
| 13 | 「값의 출처」 줄은 PR 펜스가 설정 해결자 호출 둘의 stderr 에서 그 줄만 걸러 뺀다(해결자는 고치지 않는다). 임시 파일을 못 만들면 거르지 않는다 | 9 | 아니다 |
| 14 | 인터뷰 본문이 끝맺음 절차를 여는 `Read` 블록에 지시 파일 한 줄을 더한다(「여기서 계속」 을 받았을 때만 읽는다) — 플러그인 루트 변수를 담은 reference 는 SKILL.md 의 `Read` 줄이 있어야 한다는 락을 채운다 | 3 | 아니다 |

**계획 단계에서 드러난 기존 흔들림 셋**(이 에픽이 만든 것이 아니다 — 구현 중 만나면 다시 돌려 가른다).
- `plugins/spec-distill/tests/test_finish_commit_roadmap.sh` 의 「다른 이름의 로드맵: 세 파일과 로드맵 폴더가 한 커밋에」 — 기준 트리에서도 늘 실패한다(파일 정렬 순서).
- `test_hook_output_schema.TestCrossResolverAdvisory` — worktree 에서만 나는 기존 실패다.
- `plugins/spec-distill/tests/test_web_kill_switch.sh` 의 argv 관측 칸 · `test_conducting_interview_stage.sh` 의 「AC13: B-1 블록 …」 칸 — `pipefail` 아래의 `printf | grep -q` 라 기계 부하가 높으면 맞는 글인데도 떨어진다(출력에 `Broken pipe`). 뒤의 것은 과제 7 이 here-string 으로 고치고, 앞의 것은 이 에픽 밖이다.

## File Structure

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `plugins/spec-distill/scripts/check_brief.py` | 건너뜀 줄의 문법 · 완화 셋(범위 조사 · 포화 판정 · 맹점 차원) · 나눈 일 선 · 남은 줄 · advisory. `(unavailable:)` 의 빈 이유는 실패 | 2 |
| `plugins/spec-distill/templates/interview-audit-template.md` | §2 설명 — 새 규칙에 맞춘다(본보기 줄에 건너뜀 줄을 넣지 않는다) | 2 |
| `plugins/spec-distill/references/brief-handoff.md` (새 파일) | 다음 세션이 읽는 지시 — 절 둘. 지시만 담는다 | 3 |
| `plugins/spec-distill/skills/pm-interview/references/finishing.md` | 끝맺음 절차 — 넘김 줄(3) · 건너뜀을 적는 자리(4) · 끝 질문 앞 글과 B-S(6) · superpowers 가 없는 끝 질문(7) · 머지 펜스와 다시 확인 펜스(8) · PR 펜스(9) | 3 · 4 · 6 · 7 · 8 · 9 |
| `plugins/spec-distill/skills/pm-interview/SKILL.md` | 지시 파일을 여는 `Read` 줄(3) · 건너뜀 규칙의 정의 한 곳과 그것을 가리키는 네 곳(4) | 3 · 4 |
| `plugins/spec-distill/skills/pm-interview/references/saturation.md` | 건너뜀 줄의 모양과 포화 판정을 건너뛰는 때 | 4 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 리뷰 부품 셋의 건너뜀 규칙 · codex 펜스의 건너뜀 입력 | 5 |
| `shared/tests/fixtures/ask-sites.tsv` | 새 질문 자리(끝 질문) 두 행 | 7 |
| `plugins/spec-distill/README.md` · `dependencies.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md` | 사람에게 보이는 글과 판 | 10 |

한 구현 담당자가 과제마다 새 하위 agent 를 띄워 순서대로 돈다(1 → 10). `finishing.md` 를 고치는 과제가 여섯이라 과제를 병렬로 돌리지 않는다. 과제 사이에 넘어가는 이름은 과제마다의 **Interfaces** 와 Global Constraints 의 글자 그대로 항목이다.

---

### Task 1: 다시 확인 · 글자로 박은 자리 찾기 · 기준선

코드를 고치지 않는다. 뒤 과제 아홉이 딛는 사실을 지금 코드에서 다시 잰다. 이 과제가 받드는 수용 기준은 뒤 과제 전부다(AC1–AC15 의 전제).

**Files:**
- Create(git 이 추적하지 않는다): `.claude/tmp/f4/recheck.sh` · `.claude/tmp/f4/sweep.sh` · `.claude/tmp/f4/narrow.sh` — 짝 문서 「도구 셋」 의 세 스크립트 그대로
- Create(git 이 추적하지 않는다): `.claude/tmp/f4/recheck.out` · `.claude/tmp/f4/sweep.out` · `.claude/tmp/f4/narrow-base.out`

**Interfaces:**
- Produces: `bash .claude/tmp/f4/narrow.sh <라벨> '<ERE 패턴>'` → `.claude/tmp/f4/narrow-<라벨>.out`(정렬된 `FAILED <파일>: <이름>` 줄). 뒤 과제의 「넓은 락」 걸음이 이 러너와 기준선 `narrow-base.out` 을 쓴다.

- [ ] **Step 1: 도구 셋을 쓴다**

`mkdir -p .claude/tmp/f4` 뒤 짝 문서 「도구 셋」 의 세 블록을 그 이름으로 쓴다. `git check-ignore -q .claude/tmp/f4/x` 가 rc 0 인지 본다(무시되지 않으면 멈춰 보고한다).

- [ ] **Step 2: 설계가 근거로 든 자리를 다시 본다**

Run: `bash .claude/tmp/f4/recheck.sh | tee .claude/tmp/f4/recheck.out`
Expected: 마지막 줄 `합계: NO 0개`, rc 0. 줄 서른여덟이 전부 `ok` 다(끝맺음 절차 파일 835줄 · 553행 넘김 줄 2,018자 · 818행 지휘자 줄 · 442–448행 B-1 · 434행 리뷰 뒤 검사 · 788–797행 머지 뒤 상태 읽기 · `MAPPER_RE` 1546–1548행 · 필수 자리 둘 298 · 386 · 532행 · 리뷰 skill 237 · 360 · 384 · 646행 · audit 템플릿 40 · 47행 · 판 8.14.0).

`NO` 줄이 하나라도 있으면 **멈춘다** — 그 줄과 지금 그 자리의 글을 지휘자에게 보고하고 뒤 과제로 가지 않는다. 계획을 쓴 시점(브랜치 끝 6b923b62)에는 전부 `ok` 였다.

- [ ] **Step 3: 바뀌는 문장을 글자로 박아 둔 자리를 전수로 찾는다**

Run: `bash .claude/tmp/f4/sweep.sh > .claude/tmp/f4/sweep.out`
그 출력의 파일 목록을 아래 「알려진 자리」 표와 맞춘다(`grep -v '^---' .claude/tmp/f4/sweep.out | cut -d: -f1 | sort -u`).

알려진 자리 — 계획 단계에서 시제품을 걸고 좁은 러너로 실제로 깨지는지 본 것:

| 파일 | 박혀 있는 것 | 고치는 과제 |
|---|---|---|
| `plugins/spec-distill/tests/test_review_handoff_order.sh` | 넘김 줄의 지시 문장 · 순서 · 「사용자 선호:」 · 「다른 다음 단계의 줄」 의 판 확인 문장 | 3 |
| `plugins/spec-distill/tests/test_end_gates.sh` | 「다른 다음 단계의 줄」 의 공통 지시 네 문장 · brief 줄과 에픽 넘김 줄의 같은 원칙 문장 | 3 · 6 · 7 |
| `plugins/spec-distill/tests/test_plain_gate_templates.sh` | 넘김 줄의 낱말 규칙 구절과 그 구절이 든 줄 수(2) | 3 |
| `plugins/spec-distill/tests/test_superpowers_presence.sh` | B-1 의 「brief를 완료하고 · loud advisory · 정지(STOP)」 와 멈춤 안내 원문 · README · dependencies.md 의 superpowers 줄 | 7 · 10 |
| `plugins/spec-distill/tests/test_interview_state_flow.sh` | B-1 의 「brief · audit · 상태 파일은 커밋하지 않았다」 · 「커밋 펜스 자리」(Step A 와 B-3 사이에 커밋 글이 없어야 한다는 파이썬 조각) | 7 |
| `plugins/spec-distill/tests/test_decompose_surface.sh` | B-1 의 분해된 일 미커밋 안내 | 7 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | 넘김 줄의 「보고 후 재결정」 · 「임의 변경 … 금지」(C4) · 재제시 상한의 「B-2 게이트를 다시 띄운다」 두 곳 · B-1 블록의 `superpowers…advisory` 정규식 | 3 · 7 |
| `plugins/spec-distill/tests/test_open_research.sh` | 「필수 자리 둘 — … — 은 그대로」(앞부분이 같아 깨지지 않는다 — 가리킴 단언을 더한다) | 4 |
| `plugins/spec-distill/tests/test_saturation_reference.sh` | saturation.md 첫 문단의 읽는 때(깨지지 않는다 — 건너뜀 단언을 더한다) | 4 |
| `plugins/spec-distill/tests/test_check_brief.sh` · `test_audit_template_gate_shape.py` | `coverage-mapper 0` 의 사유 규칙 · 템플릿 §2 | 2 |
| `plugins/spec-distill/tests/test_finish_pr_merge.sh` | 머지 펜스의 gh 호출 횟수 · 판결 줄 | 8 · 9 |
| `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` · `test_brief_codex_axes.sh` | codex 펜스의 줄과 사유 글 | 5 |
| `shared/tests/fixtures/ask-sites.tsv` | finishing.md 의 질문 자리 행 | 7 |
| `plugins/spec-distill/README.md` · `dependencies.md` | superpowers 가 없을 때의 문장 · 흐름 그림 · reference 목록 · 「판정 없는 종료를 거절한다」 | 10 |
| `shared/tests/test_plugin_root_no_cwd_fallback.sh`(고치지 않는다 — 요구를 채운다) | 플러그인 루트 변수를 담은 reference 는 그것을 여는 `Read` 줄이 SKILL.md 에 있어야 한다 | 3 |
| `plugins/spec-distill/templates/interview-audit-template.md` | §2 설명의 옛 규칙 둘 | 2 |

글자가 같지만 고치지 않는 자리(다른 일의 것): `references/epic-handoff.md` 의 에픽 넘김 줄과 `test_epic_handoff.sh`(옆 로드맵의 예약 — 「사용자 선호:」 라벨은 미룸 표의 일이다) · `skills/spec-review/SKILL.md` · `skills/request-framing/SKILL.md` 의 codex 펜스와 그 테스트 · `shared/docreview/**` · `scripts/seed_provenance.py` · `scripts/repo_defaults.py` 와 그 테스트.

표에 없는 파일이 훑기에 나오면: 그 줄이 이 에픽이 바꾸는 문장을 단언하거나 옮겨 적은 것인지 열어 보고, 그렇다면 그 문장을 바꾸는 과제의 고칠 파일에 더한 뒤 과제 보고에 「새로 찾은 자리」 로 적는다. 아니면 「다른 일의 것」 으로 적는다. 판단이 서지 않으면 멈춰 보고한다.

- [ ] **Step 4: 기준선을 뜬다**

Run: `bash .claude/tmp/f4/narrow.sh base 'finishing|brief-handoff|pm-interview|reviewing-brief|saturation|ask-sites|interview-audit-template|check_brief|references/|skills/|CHANGELOG|README|plugin\.json|proceed-gate|templates/|dependencies\.md'`
Expected: 끝 줄이 `테스트 <n>개를 돌렸다 · FAILED 줄 <k>개`. `<k>` 가 0 이 아니면 그 줄들이 이 worktree 의 기존 실패다 — `narrow-base.out` 에 그대로 두고 과제 보고에 적는다(뒤 과제는 이 기준선과의 차이만 본다). 이 러너는 길다(계획 단계에서 테스트 백여 개에 수십 분) — 백그라운드로 돌리고 끝나길 기다린다.

- [ ] **Step 5: 보고**

커밋할 것이 없다. 보고에 싣는다: 다시 확인의 합계 줄 · 훑기에서 새로 찾은 자리(없으면 「없음」) · 기준선의 FAILED 줄 수와 그 줄들.

---

### Task 2: 구조 검사 — 건너뜀 줄 (AC4 · AC5 · AC6 · AC7)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py` — 패치 A 의 그 파일 부분(새 상수 여섯 · 새 함수 여섯 · 기존 함수 셋의 완화 · `gate()` 의 세 줄)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md` — 패치 A 의 그 파일 부분(§2 설명)
- Test: `plugins/spec-distill/tests/test_check_brief.sh` — 패치 A 의 그 파일 부분(마지막 `finish` 앞, 라벨 접두 `F4/건너뜀`, 단언 150)

**Interfaces:**
- Consumes: 없음.
- Produces(뒤 과제가 글자 그대로 쓴다):
  - 상수 — `SKIP_PREFIX = "모델 판단으로 건너뜀"` · `SKIP_SPOTS = ("범위 조사", "맹점 조사", "포화 판정", "재비판", "codex", "읽어 보기")` · `SKIP_LINE_RE = re.compile(r"^모델 판단으로 건너뜀 — ([^:]+):(?:[ \t]+(\S.*))?$")` · `SKIP_ADVISORY = "건너뜀 — {spot}: {reason} (모델 판단 — 사람이 확인할 것)"` · `SPLIT_LINE_PREFIX = "분해됨 — "`. `SAT_EVENT_PREFIXES` 에 `SKIP_PREFIX` 를 더한다(mapper 첫 매치가 건너뛰는 사건 줄).
  - 함수 — `_skip_bodies(audit_text: str) -> list[str]` · `skip_lines(audit_text: str) -> tuple[dict[str, str], list[str]]`(문법 맞는 줄의 `{자리: 이유}` 와 문법 실패 사유) · `payload_is_split(payload_text: str) -> bool` · `skip_split_failures(payload_text: str, audit_text: str) -> list[str]` · `_mapper_match(audit_text: str)` · `skip_conflict_failures(audit_text: str) -> list[str]`.
  - 기존 함수(시그니처 그대로) — `coverage_anchor_failures` · `budget_mapper_failures` · `saturation_failures` 가 안에서 `skip_lines(audit_text)[0]` 을 부른다.
  - 실패 접두 `건너뜀 줄: `(advisory 의 `건너뜀 — ` 와 글자가 달라 끝 질문 앞 글이 접두로 모을 때 섞이지 않는다). 나눈 일 사유는 `나눈 일은 건너뛸 수 없다 — …` 로 시작한다.
  - advisory 는 지금 것과 같은 길(gate JSON 의 `advisories` + stderr)로, §2 에 적힌 순서로, 실패한 실행에서도 문법 맞는 줄의 것은 나간다.

정한 것(설계가 비워 둔 자리 — 시제품이 고른 좁은 해석).
- 줄 문법: 구분자는 ` — ` 하나, 자리는 글자 그대로 여섯 중 하나, 자리와 이유는 **첫** `: ` 에서 가른다(콜론 뒤 공백 필수). 건너뜀 줄은 §2 불릿 본문이 접두로 «시작»하는 줄만이다 — 불릿은 형제 줄과 같은 어휘(`-` · `*`, 들여쓰기 허용).
- 문법이 틀린 줄은 완화를 열지 못한다. 같은 자리 두 줄이면 실패 사유는 중복 하나다.
- 범위 조사: `coverage-mapper 0` + `범위 조사` 줄이면 통과. mapper 줄이 없으면 건너뜀 줄이 있어도 실패. `(unavailable:)` 빈 이유(공백뿐 포함)는 실패 — `(unavailable: 이유)` 는 지금처럼 advisory 통과.
- 포화 판정: 판정 · 사용자 종료 줄이 하나도 없고 `포화 판정` 줄이 있으면 통과.
- 맹점 차원: `floor:blind_spot` 의 근거가 `모델 판단으로 건너뜀` 으로 시작하고 `맹점 조사` 줄이 있으면 「앵커가 하나도 없음」 만 면제한다(인용한 S 가 있으면 실재해야 한다). 근거가 그렇게 시작하는데 줄이 없으면 실패. 다른 floor 는 지금 규칙 그대로다.
- 나눈 일: brief §7 안에서 앞 공백 · `- ` · 백틱을 뗀 뒤 `분해됨 — ` 로 시작하는 «첫 맞는 줄»이 있으면 나눈 일이다(끝내기 커밋 펜스의 awk 와 같은 뜻 — 설계의 「§7 첫 줄」 은 이 뜻으로 읽는다). 문법이 틀린 건너뜀 줄도 센다.
- **남은 줄(Review Focus 1 — 설계의 검사 넷에 없는 검사다).** (a) `범위 조사` 줄이 있는데 mapper 가 1회 이상 (b) `포화 판정` 줄이 있는데 판정 · 사용자 종료 줄이 있다 (c) `맹점 조사` 줄이 있는데 맹점 차원의 근거가 건너뜀으로 시작하지 않는다 — 셋 다 실패이고 사유가 그 줄을 지우라고 말한다. 리뷰 부품 셋에는 이 검사가 없다(구조 검사는 그 부품이 돌았는지 보지 못한다).
- 템플릿: §2 의 두 문단을 새 규칙으로 고치고 건너뜀 줄 꼴을 적는 괄호 문단 하나를 더한다. 불릿 본보기에는 건너뜀 줄을 넣지 않는다 — 템플릿을 그대로 옮긴 audit 이 건너뜀으로 읽히면 안 된다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

패치 A 에서 `test_check_brief.sh` 부분만 건다 — `git apply --include='plugins/spec-distill/tests/test_check_brief.sh' <패치 A 를 담은 파일>`(짝 문서의 패치 A 블록을 `.claude/tmp/f4/patch-a.diff` 로 떠 놓고 쓴다). 칸은 열이다:

| 칸 | 재는 것 | 단언 |
|---|---|---|
| 양성 대조 | 건너뜀 줄 없는 정상 쌍은 그대로 통과 | 1 |
| (1) 자리 여섯 | 줄 하나 통과 + advisory · 같은 audit 에 §7 만 바꿔 나눈 일 실패 · 모르는 자리 · 빈 이유 · 공백뿐인 이유 · 같은 자리 두 줄 | 42 |
| (2) 문법 | 모르는 자리 셋 · 형식 밖 다섯 · `*` 불릿 · advisory 세 줄과 순서 | 11 |
| (3) 범위 조사 | 0 + 줄 통과 ↔ 그 줄만 지우면 실패 · 다른 자리 줄 · mapper 줄 없음(이유에 `coverage-mapper 3` 을 섞어도) · `(unavailable:)` 빈 이유 셋 + 양의 짝 | 20 |
| (4) 포화 판정 | 판정 줄 없음 + 줄 통과 ↔ 지우면 실패 · 다른 자리 줄 | 7 |
| (5) 맹점 조사 | 통과 ↔ 지우면 실패 · 근거 접두가 아님 · 없는 S · 다른 차원 셋 | 11 |
| (6) 나눈 일 | 나눈 일 + 줄 없음 통과 · awk 꼴 다섯 · §7 밖의 글은 나눈 일이 아니다 · 문법 틀린 줄도 센다 | 11 |
| (7) 출하 템플릿 | 건너뜀 꼴을 적는다 · 채운 쌍은 건너뜀 advisory 0줄로 통과 | 2 |
| (8) 남은 줄 | (a)(b)(c) 각각 「남으면 실패 ↔ 그 줄만 지우면 통과」 | 10 |
| (9) 입력 꼴 | 불릿 꼴 셋 × 문법 · advisory · 완화 · 남은 줄 · 나눈 일 · 이유 글 속의 판정 줄 글자 · `: ` 와 ` — ` 가 여럿인 이유 | 35 |

「리뷰 뒤 다시 짓기」(설계 Verification Plan)는 칸 (1) 의 리뷰 부품 셋이 잰다 — 리뷰 부품 줄이 든 audit 이 advisory 를 내고, 같은 audit 에 §7 만 나눈 일로 바꾸면 실패하고, 줄이 없으면 통과한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh | grep -cE '✗.*F4/건너뜀'`
Expected: 0 이 아니다(완화 · 실패 · advisory 가 아직 없다). 기존 칸의 `✗` 는 0 이다 — `bash plugins/spec-distill/tests/test_check_brief.sh | grep '✗' | grep -vc 'F4/건너뜀'` 가 0.

- [ ] **Step 3: 구조 검사와 템플릿을 고친다**

패치 A 의 나머지를 건다 — `git apply --exclude='plugins/spec-distill/tests/test_check_brief.sh' .claude/tmp/f4/patch-a.diff`. 걸리지 않으면 위 **Interfaces** 와 「정한 것」 대로 손으로 옮긴다. `gate()` 에 끼우는 자리는 `if not any(m.startswith("2.") for m in amiss):` 블록 안, 포화 검사 바로 뒤다:

```python
skips, kf = skip_lines(audit_text)
failures += [f"건너뜀 줄: {x}" for x in kf + skip_conflict_failures(audit_text) + skip_split_failures(text, audit_text)]
advisories += [SKIP_ADVISORY.format(spot=s, reason=r) for s, r in skips.items()]
```

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh | tail -1; python3 tools/suite/run_unittest_dir.py plugins/spec-distill/tests test_audit_template_gate_shape.py | tail -1`
Expected: `Total: 571 | Pass: 571 | Fail: 0`(기준 421 + 새 150) · `OK`.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/templates/interview-audit-template.md plugins/spec-distill/tests/test_check_brief.sh
git commit -m "feat(spec-distill): 건너뜀 줄을 구조 검사가 받는다 (F4)" -- plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/templates/interview-audit-template.md plugins/spec-distill/tests/test_check_brief.sh
```

- [ ] **Step 6: 이빨 확인**

짝 문서 「변이 표 — 과제 2」 의 변이 열여덟(m1–m18)을 `check_brief.py` 사본에 하나씩 걸어 새 칸을 돌린다(`PYTHONDONTWRITEBYTECODE=1`). 전부 새 칸의 단언을 하나 이상 떨어뜨려야 한다. 계획 단계에서는 여기에 추가 · 반전 · 형태 변경 서른하나를 더한 마흔아홉이 전부 죽었다. 단언 하나만 무는 변이가 열아홉이다 — 칸을 줄이거나 합치지 않는다.

| 변이 | 무엇을 흔드나 |
|---|---|
| m1 · m2 · m3 | 문법 검사에서 자리 집합 · 빈 이유 · 중복 검사를 뗀다 |
| m4 · m5 | 범위 조사 완화를 「항상 통과」 로 · 완화를 뗀다 |
| m6 | 포화 판정 완화를 「판정 줄이 있어도 통과」 로 |
| m7 · m8 | 맹점 면제를 모든 floor 로 넓힌다 · §2 줄을 보지 않는다 |
| m9 · m10 | 나눈 일 검사를 뗀다 · §7 밖의 `분해됨 — ` 글자에도 걸린다 |
| m11 | advisory 를 내지 않는다 |
| m12 | `(unavailable:)` 빈 이유를 다시 통과시킨다 |
| m13 | 사건 줄 접두를 뗀다 |
| m14 · m15 · m16 | 남은 줄 검사 (a) · (b) · (c) 를 뗀다 |
| m17 · m18 | 건너뜀 줄 판독을 `-` 불릿으로만 좁힌다 · 자리와 이유를 마지막 `: ` 에서 가른다 |

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t2 'check_brief|interview-audit-template'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t2.out`
Expected: 출력 없음. 커밋된 brief · 픽스처의 판정이 달라지지 않는다(계획 단계에서 123개의 rc · JSON 을 전후로 비교해 차이 0).

알아 둘 것: `check_brief.py coverage` 서브커맨드도 `coverage_anchor_failures` 를 부른다 — 맹점 면제와 새 실패 문장이 그 출력에도 나온다. `test_conducting_interview_stage.sh` 의 「AC13: B-1 블록 …」 칸과 `test_web_kill_switch.sh` 의 argv 관측 칸은 기계 부하가 높으면 이 변경과 무관하게 흔들린다(둘 다 `pipefail` 아래의 `printf | grep -q` — 앞의 것은 과제 7 이 고친다). 흔들리면 다시 돌려 가른다.

---

### Task 3: 넘김 글 — 지시 파일과 짧은 줄 (AC1 · AC2 · AC3)

**Files:**
- Create: `plugins/spec-distill/references/brief-handoff.md` — 짝 문서 「새 파일 — brief-handoff.md」 전문 그대로
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 편집 F9(규약의 거처) · F10(다음 세션 줄) · F11(다른 다음 단계의 줄)
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md` — 편집 S6 · S7(끝맺음 절차를 여는 `Read` 블록에 지시 파일 한 줄과 그 줄을 읽는 때)
- Test: `plugins/spec-distill/tests/test_review_handoff_order.sh` · `test_end_gates.sh` · `test_plain_gate_templates.sh` · `test_conducting_interview_stage.sh` — 블록 T3-a · T3-b · T3-c · T3-d

**Interfaces:**
- Consumes: 없음.
- Produces: 지시 파일의 절 둘 `## brainstorming 지시`(불릿 열여섯) · `## 공통 지시`(불릿 다섯). 넘김 줄의 가리킴 문장 — `시작하기 전에 ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다 — 그 파일의 플러그인 루트 변수는 ${CLAUDE_PLUGIN_ROOT} 로 읽는다. 읽지 못하면 추측하지 말고 멈춰 보고한다.` 과제 7 의 끝 안내가 이 다음 세션 줄을 그대로 보인다.

넘김 줄의 플러그인 경로는 새 꺾쇠 자리표가 아니라 이미 치환 규칙이 있는 `${CLAUDE_PLUGIN_ROOT}` 로 쓴다 — 줄 안의 꺾쇠 자리표는 줄 앞 `@<…>` 토큰의 이름뿐이어야 한다는 락(`lead_only`)이 있고, 그 변수를 절대경로로 바꿔 노출하는 규칙(555–557행)이 그대로 맡는다. 줄은 한 겹 백틱 안이라 안쪽에 백틱을 쓰지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

짝 문서의 블록 셋을 그 자리에 넣는다.
- T3-a(`test_review_handoff_order.sh`) — `ONE="$(nsl "$FIN")"` 줄부터 `assert_file_absent "$FIN" '/compact interview brief at'` 줄 앞까지를 블록으로 통째로 바꾼다. `# guards:` 줄과 `--emit-scanned` 목록에 `plugins/spec-distill/references/brief-handoff.md` 를 더한다. 블록이 단언하는 것:
  - 넘김 줄의 토큰 뒤 글이 `이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. <가리킴 문장>` 과 **같다**(등호 — 문장 하나가 더 붙어도 실패한다).
  - 지시 파일 `## brainstorming 지시` 절의 불릿 글이 옛 줄의 지시 문장 열여섯과 **같다**(등호 — 빠짐 · 순서 바뀜 · 더해짐 · 글자 바뀜 모두 실패). 「사용자 선호:」 가 그 절에 없다.
  - 그 열여섯 문장 하나하나가 넘김 줄에 없다(양의 짝: 같은 문장이 지시 파일에 있다).
  - 순서(판 확인 → spec-review → writing-plans, `--plan` → `--impl`)는 지시 절 안에서 잰다.
  - 「다른 다음 단계의 줄」 문단이 `## 공통 지시` 절을 가리키는 문장을 싣고, 공통 지시 다섯 문장은 문단에 글자로 없으며, 그 절의 불릿 글이 다섯 문장과 **같다**.
  - 두 절은 서로의 이름을 싣지 않는다.
- T3-b(`test_end_gates.sh`) — 「다른 다음 단계의 줄」 문단의 needle 목록에서 공통 지시 네 문장을 빼고 가리킴 needle 둘을 더한다. 네 문장은 지시 파일의 `## 공통 지시` 절에서 재고 문단에는 없음을 함께 단언한다. 「brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다」 는 지시 파일의 `## brainstorming 지시` 절로 옮겨 재고, brief 줄에는 없음을 더한다. `# guards:` · `--emit-scanned` 에 지시 파일을 더한다.
- T3-c(`test_plain_gate_templates.sh`) — 낱말 규칙 구절: finishing.md 에는 0 줄, 지시 파일에는 정확히 2 줄(두 절에 하나씩), 넘김 줄과 「다른 다음 단계의 줄」 은 각자의 절을 가리킨다. `spec-review` 쪽 단언은 그대로다.
- T3-d(`test_conducting_interview_stage.sh`) — 재결정 규약(「보고 후 재결정」 · 「임의 변경 … 금지」)을 넘김 줄이 아니라 지시 파일의 `## brainstorming 지시` 절에서 재고, 넘김 줄은 그 절을 가리키는지 잰다.

- [ ] **Step 2: 실패를 확인한다**

Run: `for t in test_review_handoff_order test_end_gates test_plain_gate_templates test_conducting_interview_stage; do bash plugins/spec-distill/tests/$t.sh | grep -E '✗|FAIL:'; done`
Expected: FAIL(계획 단계에서 차례로 32 · 13 · 6 · 3 줄) — `지시 파일이 없다: references/brief-handoff.md` · `F4 AC1: 다음 세션 줄은 시작 문장과 지시 파일을 가리키는 문장뿐이다` · `F4 AC2(양성 대조): brainstorming 지시 절에서 문장 열여섯을 읽었다` · `F4 AC3: …` 줄들.

- [ ] **Step 3: 지시 파일을 만들고 넘김 줄을 줄인다**

1. `plugins/spec-distill/references/brief-handoff.md` 를 짝 문서 전문 그대로 쓴다.
2. 편집 F10 — 553행의 인용 줄 전체를 짧은 줄로 바꾼다. F11 — 560행 문단 전체를 바꾼다. F9 — 「규약의 거처」 문단의 한 구절을 바꾼다.
3. 555–557행(자리표 치환 · 거부 · 위치 공시)은 건드리지 않는다.
4. 편집 S6 · S7 — 인터뷰 본문이 끝맺음 절차를 여는 `Read` 블록에 `Read ${CLAUDE_PLUGIN_ROOT}/references/brief-handoff.md` 한 줄과 「셋째 줄은 「여기서 계속」 을 받았을 때만 읽는다」 를 더한다. 플러그인 루트 변수를 담은 reference 는 그것을 여는 `Read` 줄이 SKILL.md 에(치환 안내 문장과 같은 절에) 있어야 한다는 락(`shared/tests/test_plugin_root_no_cwd_fallback.sh` 축 3)이 있다 — 계획 단계에서 이 줄이 없어 실제로 떨어졌다.

- [ ] **Step 4: 통과를 확인한다**

Run: Step 2 의 명령과 `bash shared/tests/test_plugin_root_no_cwd_fallback.sh | grep -E '✗'; bash shared/tests/test_skill_reference_pointers.sh | grep -E '✗'`. Expected: 출력 없음.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/references/brief-handoff.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_plain_gate_templates.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): 넘김 지시를 지시 파일로 옮기고 다음 세션 줄을 줄인다 (F4)" -- plugins/spec-distill/references/brief-handoff.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_plain_gate_templates.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh
```

- [ ] **Step 6: 이빨 확인**

변이 열둘을 하나씩 걸고 세 테스트를 돌린다 — 전부 새 실패가 하나 이상 나야 한다(짝 문서 「변이 표 — 과제 3」 이 계획 단계의 결과다).

| 변이 | 대상 | 무는 단언 |
|---|---|---|
| L1 넘김 줄 끝에 옛 지시 문장 하나를 되붙인다 | finishing.md | F4 AC1 등호 · 「옛 지시 문장 2 이 … 없다」 |
| L2 넘김 줄에서 가리킴 문장을 뗀다 | finishing.md | F4 AC1 등호 |
| L3 넘김 줄이 `## 공통 지시` 를 가리킨다 | finishing.md | F4 AC1 등호 |
| O1 「다른 다음 단계의 줄」 이 `## brainstorming 지시` 를 가리킨다 | finishing.md | F4 AC3 가리킴 |
| O2 그 문단에 공통 지시 문장을 글자로 되싣는다 | finishing.md | F4 AC3 「문단에 글자로 없다」 |
| B1 brainstorming 절의 문장 하나를 지운다 | brief-handoff.md | F4 AC2 등호 · 열여섯 계수 |
| B2 두 문장의 순서를 바꾼다 | brief-handoff.md | F4 AC2 등호 |
| B3 「사용자 선호: 」 라벨을 되붙인다 | brief-handoff.md | F4 AC2 등호 · 라벨 부재 |
| B4 문장 하나를 더한다 | brief-handoff.md | F4 AC2 등호 · 열여섯 계수 |
| B5 한 문장의 글자를 바꾼다(「번호째 설계의 입력으로」 → 「번호째 입력으로」) | brief-handoff.md | F4 AC2 등호 |
| C1 공통 지시 절의 판 확인 문장을 지운다 | brief-handoff.md | F4 AC3 등호 |
| C2 공통 지시 절이 brainstorming 절을 가리킨다 | brief-handoff.md | 「두 절은 서로를 가리키지 않는다」 · F4 AC3 등호 |

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t3 'finishing|brief-handoff|references/|pm-interview'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t3.out`
Expected: 출력 없음(기준선에 없던 FAILED 줄 0). 새 줄이 있으면 그 테스트가 요구하는 것을 읽고 고친다 — 새 reference 파일이 걸리는 락은 「어느 SKILL.md 로부터든 가리켜지는가」(`shared/tests/test_skill_reference_pointers.sh`) · 옛 토큰(`test_stale_terms.sh`) · 질문 자리(`shared/tests/test_ask_recommendation.sh`) · 플러그인 루트(`shared/tests/test_plugin_root_no_cwd_fallback.sh`)다.

---

### Task 4: 인터뷰 본문 · 포화 판정 reference 의 건너뜀 규칙 (AC9 · AC14)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md` — 편집 S1 · S2 · S3(설계가 든 298 · 386 · 532행) · S4 · S5(같은 필수 규칙을 말하는 408 · 479행)
- Modify: `plugins/spec-distill/skills/pm-interview/references/saturation.md` — 편집 T1(새 절 `### 건너뜀`) · T2(줄 목록) · T3(읽는 때)
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 편집 F1(맹점 조사를 건너뛴 차원은 §3 으로) · F2(`coverage-mapper 0` 과 건너뜀 줄) · F3(대기 줄 블록의 줄 종류)
- Test: `plugins/spec-distill/tests/test_saturation_reference.sh`(블록 T4-a) · `test_open_research.sh`(블록 T4-b)

**Interfaces:**
- Consumes: 과제 2 의 문법 — 조사 자리 셋의 줄 `- 모델 판단으로 건너뜀 — <범위 조사 | 맹점 조사 | 포화 판정>: <이유>`, 범위 조사를 건너뛰면 mapper 줄은 `coverage-mapper 0`, 맹점 차원의 근거는 `모델 판단으로 건너뜀 — <이유>` 로 시작한다.
- Produces: SKILL.md `## 조사 상한 · 포화 판정` 절의 「**건너뜀.**」 문단(규칙의 정의 한 곳)과 그것을 가리키는 구절 `작은 일의 건너뜀은 \`## 조사 상한 · 포화 판정\` 의 「건너뜀」`(네 곳). saturation.md 의 `### 건너뜀` 절. 과제 5 · 6 의 글이 이 절 이름을 부른다.

규칙은 SKILL.md 에 한 번만 정하고(S2) 나머지 넷은 가리킨다 — 어긋난 두 규칙이 있으면 모델이 아무 쪽이나 따른다. 조사 agent 의 frontmatter(`agents/coverage-mapper.md` 의 「R1 첫 질문 전 1회는 필수다」)는 고치지 않는다 — 건너뛸지는 본체가 정하고 agent 는 불렸을 때의 일만 한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- 블록 T4-a 를 `test_saturation_reference.sh` 의 마지막 `finish` 줄 앞에 넣는다. 단언하는 것: saturation.md `### 건너뜀` 절의 여덟 문장(줄 모양 셋 · mapper 0 · 맹점 근거 꼴 · 판정 줄이 있으면 쓰지 않는다 · 이유는 비우지 않는다 · 나누기로 정하면 돌리고 지운다 · 리뷰 쪽 셋) · `### audit §2 줄` 목록의 건너뜀 줄(자리 여섯) · 첫 문단의 읽는 때 · SKILL 조사 상한 절의 네 문장 · 「**건너뜀.**」 이 SKILL 에 정확히 한 번 · 가리키는 구절이 정확히 네 줄 · finishing.md 의 네 문장.
- 블록 T4-b 를 `test_open_research.sh` 의 `"AC14: R2 — 필수 자리 둘을 이름으로 댄다"` 줄 바로 뒤에 넣는다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_saturation_reference.sh; bash plugins/spec-distill/tests/test_open_research.sh`
Expected: FAIL — `F4: saturation.md 「### 건너뜀」 절 부재 — 아래가 공허하다` 와 `F4 AC9 …` 줄들.

- [ ] **Step 3: 글을 고친다**

편집 S1–S5 · T1–T3 · F1–F3 을 건다(짝 문서 「바꿀 글」 — 찾을 글이 정확히 한 번 있는지 먼저 센다).

- [ ] **Step 4: 통과를 확인한다**

Run: Step 2 의 두 테스트. Expected: `✗` 줄 0.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/skills/pm-interview/references/saturation.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_saturation_reference.sh plugins/spec-distill/tests/test_open_research.sh
git commit -m "feat(spec-distill): 인터뷰 본문과 포화 판정 reference 에 건너뜀 규칙을 적는다 (F4)" -- plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/skills/pm-interview/references/saturation.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_saturation_reference.sh plugins/spec-distill/tests/test_open_research.sh
```

- [ ] **Step 6: 이빨 확인**

블록의 needle 마다 대상 파일에서 그 글을 지우고(백업 → 지움 → 테스트 → 되돌림) 테스트가 새 실패를 내는지 본다. 계수 단언 둘은 따로 흔든다 — 「**건너뜀.**」 문단을 한 번 더 붙이면(2회) 실패, 가리키는 구절 하나를 지우면(3줄) 실패. 짝 문서 「변이 표 — 글 needle」 이 계획 단계의 결과다(전부 KILLED).

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t4 'pm-interview|saturation|finishing'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t4.out`
Expected: 출력 없음(기준선에 없던 FAILED 줄 0).

---

### Task 5: 결과물 리뷰 skill — 건너뜀 규칙과 codex 펜스의 건너뜀 입력 (AC9 · AC14)

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — 패치 C 의 그 파일 부분(codex 펜스: 입력 여덟 줄 · 갈래 열한 줄 · 공시 한 줄) + 편집 R1(새 절 `## 건너뜀 — 모델 판단`)
- Test: `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` — 패치 C 의 그 파일 부분(단언 72 → 153) · `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` — 블록 T5-a

**Interfaces:**
- Consumes: 과제 2 의 줄 문법(리뷰 부품 셋: `재비판` · `codex` · `읽어 보기`) · 과제 4 의 대기 줄 블록 규칙.
- Produces:
  - codex 펜스의 입력 — 펜스 지역 변수 `model_skip_codex`, 따옴표 heredoc 구분자 `DEVBREW_MODEL_SKIP_EOF`(두 구분 줄 사이의 빈 줄이 기본값 「건너뛰지 않음」). 모델은 그 빈 줄만 이유 한 줄로 바꿔 펜스를 그대로 돌린다.
  - 사유 값 `model_skip` — 공시 줄 `[spec-distill] codex 리뷰를 건너뛰었다 (reason: model_skip) — … (degraded). 모델 판단으로 건너뛰었다 — 이유: <이유>`.
  - 새 절 이름 `## 건너뜀 — 모델 판단`. 과제 6 의 B-S 가 이 skill 의 `## 냉독` · `## 게이트` 를 부른다(지금 있는 절).

정한 것(설계가 「입력의 모양은 계획이 정한다」 로 넘긴 것 — 시제품이 골랐다).
- **입력은 큰따옴표 대입이 아니라 따옴표 heredoc 이다.** 큰따옴표 대입은 이유 글의 `"` · `$( )` · 역따옴표가 그대로 돈다(시제품의 양성 대조가 표지 파일 둘로 쟀다). 같은 skill 의 `extra-approval` 펜스가 같은 꼴의 선례다.
- **사유가 겹칠 때.** `residue_unclearable` > `gate_inputs_missing` > 감지기 사유(`kill_switch` · `not_installed` 등) > `model_skip`. 모델 건너뜀은 codex 가 «돌 수 있던» 라운드만 바꾼다 — 끄기 스위치 사유는 가려지지 않고, 적은 이유는 같은 줄 끝에 함께 실린다. 잔존물 중화는 어느 경우든 가용성 판정보다 앞에서 그대로 돈다.
- **겹친 라운드에는 건너뜀 줄을 적지 않는다.** 펜스가 `(reason: model_skip)` 을 냈을 때만 적는다 — 스위치가 끈 라운드에 줄을 적으면 끝 질문이 「하게 하려면 기타 칸에」 를 보이는데 다시 돌려도 돌지 않는다.
- **공시 줄은 `echo` 가 아니라 `printf '%s\n'` 이다.** zsh 의 `echo` 는 역슬래시를 풀어 이유 글의 `\n` · `\c` 가 줄을 쪼개거나 자른다(bash 3.2 만으로는 보이지 않는다).
- **빈 값 대입 줄과 공백 떼기 줄은 지우지 않는다.** 앞의 것이 없으면 zsh 가 heredoc 임시 파일을 못 만들 때 펜스가 중화 전에 죽거나 환경의 같은 이름이 건너뜀을 고른다. 뒤의 것이 없으면 빈 입력이 건너뜀이 된다.
- 재비판 건너뜀에는 리터럴 게이트가 없다(지금의 끄기 스위치도 같다) — skill 글이 「6단계 dispatch 를 하지 않고 7단계 라우팅을 `--recritic` 대신 `--recritic-skipped` 로」 를 명령 글자로 적는다. 절차서(`references/reviewing-document.md`)와 공유 엔진은 고치지 않는다.
- 나눈 일이면 건너뛰지 않는다는 규칙은 펜스가 집행하지 않는다 — skill 글의 규칙이고 구조 검사(과제 2)가 받친다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

1. 패치 C 에서 `test_reviewing_brief_residue.sh` 부분만 건다(`.claude/tmp/f4/patch-c.diff` 로 떠 놓고 `git apply --include='plugins/spec-distill/tests/test_reviewing_brief_residue.sh'`). 하네스에서 바뀌는 것은 `fire` 의 마지막 줄(`bash` → `"${WITH_SH:-bash}"`)과 sid 목록뿐이고, 새 칸은 K · Q 절이다:

   | 칸 | 재는 것 |
   |---|---|
   | K 추출 | 입력 자리(여는 줄 · 빈 줄 · 닫는 줄)가 한 번 있고 채운 펜스가 `bash -n` 을 통과한다 |
   | K1 | codex 가용 + 직전 산출물 + 이유 → 산출물이 지워진다 · 러너가 불리지 않는다 · 공시 한 줄 · `model_skip` · 이유가 글자 그대로 |
   | K2 | 양의 짝 — 같은 환경에 입력이 없으면 러너가 인자 넷으로 불린다. 공백뿐인 입력 · 같은 이름의 환경 변수도 같다. 입력 없는 끄기 스위치 공시 줄은 지금 글자 그대로다 |
   | K3 · K3b | 끄기 스위치 · 번들 부재와 겹치면 그 사유가 남는다 |
   | K4 | 중화 실패와 겹치면 `residue_unclearable` 이 이긴다(스위치 없이 codex 가용인 환경에서 잰다) |
   | K5 | 적대 이유(`"` · `'` · `$(touch …)` · 역따옴표 · `$HOME` · `\n` · `\c`) — 양성 대조(큰따옴표 대입이면 표지 파일이 생긴다) 뒤, 펜스에서는 표지 파일 0 · 이유가 글자 그대로 한 줄 |
   | K6 · KD · KE | 두 줄 이유는 한 줄로 · 하류 `prepare-recritic` 이 codex 부재로 읽는다 · errexit 를 물려받아도 같다 |
   | KZ | zsh 다섯(모델 건너뜀 · 입력 없음 · 적대 이유 · 스위치 겹침 · 입력 읽기 실패). zsh 가 없으면 한 줄 알리고 건너뛴다 |
   | Q | brief 프로필로 `finalize --recritic-skipped` → 게이트 첫 줄에 재비판 경고 · 양의 짝(재비판 블록이 온 라운드에는 그 경고가 없다) |

   그 파일의 `# guards:` 줄과 `--emit-scanned` 목록에 `shared/docreview/scripts/docreview_route.py` 를 더한다(D · KD · Q 절이 그 스크립트에 기댄다).
2. 블록 T5-a 를 `test_reviewing_brief_skill.sh` 의 마지막 `finish` 줄 앞에 넣는다. **그 파일의 `has` 는 판정만 돌려주고 세지 않는다**(`has() { grep -qF -- "$2" <<<"$1"; }`) — 블록은 `has … && ok … || no …` 꼴이다. 같은 이름의 `has` 가 `test_decompose_surface.sh` 에서는 라벨을 받아 센다 — 옮겨 적을 때 섞지 않는다(계획 단계에서 실제로 섞여 단언 열둘이 아무것도 재지 않았다).

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_reviewing_brief_residue.sh | grep -cE '✗'; bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh | grep -E '✗'`
Expected: 첫 수가 0 이 아니다(K 추출 칸 — 입력 자리가 아직 없다). 둘째는 `F4: 「## 건너뜀 — 모델 판단」 절 부재 — 아래가 공허하다` 와 `F4 AC9 · AC14: 건너뜀 절 «…» 부재` 열다섯.

- [ ] **Step 3: 펜스와 글을 고친다**

1. 패치 C 의 SKILL.md 부분을 건다(`git apply --exclude='plugins/spec-distill/tests/*' .claude/tmp/f4/patch-c.diff`). 입력 블록의 넷째 줄(두 구분 줄 사이)은 **빈 줄**이다 — 끝 공백 정리나 빈 줄 접기로 사라지면 K 추출 칸이 실패한다. `$'\n'` 은 셸 파일 층위의 글자다.
2. 편집 R1 — `## 진입 게이트 — 매 라운드, 번들보다 먼저` 제목 앞에 새 절을 끼운다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_reviewing_brief_residue.sh | tail -1; bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh | grep -cE '✗'`
Expected: `Total: 153 | Pass: 153 | Fail: 0`(zsh 가 없으면 KZ 만큼 적다) · `0`.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/tests/test_reviewing_brief_residue.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh
git commit -m "feat(spec-distill): 결과물 리뷰가 재비판 · codex · 읽어 보기를 이유를 적고 건너뛸 수 있다 (F4)" -- plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/tests/test_reviewing_brief_residue.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh
```

- [ ] **Step 6: 이빨 확인**

짝 문서 「변이 표 — 과제 5」 의 펜스 변이를 SKILL.md 사본에 걸어 residue 테스트를 돌린다 — 변이 스물다섯이 계획 단계에서 전부 죽었다(양성 대조 153/0). 변이마다 채운 펜스가 `bash -n` · `zsh -n` 을 통과하는지 먼저 본다(문법이 깨져 죽은 변이는 세지 않는다).

| 변이 | 무엇을 흔드나 |
|---|---|
| m1 | 건너뜀 갈래를 뗀다 |
| m2a · m2b | 갈래를 중화 «앞»으로 옮겨 직전 산출물이 남는다 |
| m3 | 건너뛰어도 러너를 부른다 |
| m4 | 건너뜀이 끄기 스위치 사유를 덮는다 |
| m5 · m5b · m5c | 건너뜀이 `residue_unclearable` · `gate_inputs_missing` 을 덮는다 |
| m6 · m6b · m6c · m6d | 공시 줄에서 이유 · 사유 값을 뺀다 |
| m7 · m7b · m7c · m7d | 빈 입력에서도 건너뛴다(공백 떼기 줄을 뗀다 포함) |
| m8a–m8e | 입력의 꼴 · 환경 변수 물려받기 · 빈 값 대입 줄을 뗀다(m8e 는 zsh 가 있어야 죽는다) |
| m9 · m10 | 공시를 `echo` 로 되돌린다 · 줄 펴기를 뗀다 |
| m13a · m13b | 엔진의 재비판 경고(Q 칸) |

블록 T5-a 의 needle 은 SKILL.md 에서 그 글을 지워 `test_reviewing_brief_skill.sh` 가 새 실패를 내는지 본다(「변이 표 — 글 needle」).

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t5 'reviewing-brief|codex-gate|run_docreview_codex_reviewer'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t5.out`. 다른 플러그인의 관측 테스트도 한 번 돌린다 — `bash plugins/quality-gates/tests/test_codex_gate_observation.sh | tail -1`(이 펜스를 진짜 러너 + 가짜 codex 로 돌려 호출 수를 센다).
Expected: 출력 없음 · 관측 테스트의 실패 0. `test_web_kill_switch.sh` 의 argv 관측 칸이 떨어지면 출력에 `Broken pipe` 줄이 있는지 보고 다시 돌려 가른다(기준에서도 부하가 높으면 9번에 2번 떨어지는 기존 flake 다 — 이 에픽이 고치지 않는다).

---

### Task 6: 끝 질문 앞 글 — 건너뛴 것 보이기 · 리뷰 뒤 다시 짓기 · 나중에 돌리는 길 (AC8 · AC14)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 편집 F16(Step A 의 게이트 걸음: 나눈 일 사유를 줄 지우기로 넘기지 않는다) · F5(B-A 끝: 리뷰 뒤 audit §2 를 다시 짓고 구조 검사를 다시 돈다) · F6a(새 절 `#### B-S — 건너뛴 것을 나중에 돌릴 때`) · F7(B-2 목록 4 의 엔진 경고 덧붙임 + 목록 5 「건너뛴 것 <N>개」) · F8(기타 칸 — 건너뛴 것을 하라는 말)
- Test: `plugins/spec-distill/tests/test_end_gates.sh` — 블록 T6

**Interfaces:**
- Consumes: 과제 2 의 advisory `건너뜀 — <자리>: <이유> (모델 판단 — 사람이 확인할 것)` 와 실패 사유 「나눈 일은 건너뛸 수 없다」. 과제 5 의 리뷰 skill 절 `## 건너뜀 — 모델 판단` · `## 냉독` · `## 게이트` 의 「추가 라운드 1회 열기」 질문. 과제 4 의 Step A.5 「조사 계속」 갈래(지금 있는 글).
- Produces: `#### B-S` 절(과제 5 의 글과 과제 7 의 끝 질문이 이 이름을 부른다) · B-2 게이트 앞 글의 목록 5.

세 가지를 이 과제가 정한다(설계가 계획에 넘긴 것 — 머리의 「계획이 정한 것」 표 2 · 3 번).
- **엔진의 재비판 경고 줄.** 엔진은 재비판을 건너뛴 라운드의 경고 괄호에 `kill switch` 라고 적는다(`재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: kill switch, skipped)` — 계획 단계에서 brief 가 아닌 프로필로 돌려 확인했다). 공유 엔진은 고치지 않는다. 끝 질문 앞 글이 그 줄을 쓸 때 `재비판` 건너뜀 줄이 있는 라운드면 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다.
- **재리뷰 상한이 찬 뒤.** 건너뛴 재비판 · codex 를 돌리는 라운드는 리뷰 skill 의 「추가 라운드 1회 열기」 질문의 답으로만 연다 — 끝 질문의 기타 칸에 적은 말을 그 승인으로 쓰지 않는다. 사용자가 열지 않으면 지운 줄을 되돌리고 끝 질문으로 돌아간다(건너뛴 것이 그대로 보인다).
- **나눈 일인데 추가 라운드를 열지 않으면.** 끝 질문으로 가지 못한다 — 줄을 되돌리고 사유 한 줄을 보인 뒤 턴을 끝낸다. 이것은 설계에 없던 결정이다(지휘자가 사용자에게 올린다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

블록 T6 을 `test_end_gates.sh` 의 `# CHANGELOG · README — 사람에게 보이는 글은 내부 단계 이름 대신 쉬운 말로` 줄 앞에 넣는다. 그 파일의 `win`(절 창을 한 줄로 편다) · `B2` · `BA` 를 쓴다. 단언하는 것:
- B-2 창 — 목록 5 의 다섯 문장(무엇을 한 줄씩 쓰나 · 경고 수에 센다 · 「(경고에도 있다)」 와 한 번만 센다 · 기타 칸 안내 · 0개면 쓰지 않는다) · 엔진 경고 덧붙임 문장 · 기타 칸 문단의 두 문장.
- B-A 창 — 참고 항목이 없어도 다시 짓고 다시 돈다 · advisory 는 이 실행의 것 · 나눈 일 사유면 B-S 로.
- Step A 창 — 「나눈 일은 건너뛸 수 없다」 사유면 건너뜀 줄만 지워 통과시키지 않고 B-S 대로 돌린 뒤 지운다(나눈 일이 건너뛴 채 통과하지 않게 하는 문장이다 — 구조 검사의 실패를 「줄을 지우면 통과」 로 읽는 것을 막는다).
- B-S 창 — 열세 문장(줄은 블록에서 지우고 다시 짓는다 · 조사는 「조사 계속」 갈래 · 맹점 차원은 다시 열린다 · 재비판 · codex 는 한 라운드 더 · 줄만 지우면 다시 막힌다 · 읽어 보기는 냉독만 · 재리뷰 상한을 쓰지 않는다 · 나눈 일은 리뷰 부품 줄을 전부 지운다 · 줄 하나만 지우면 다시 막힌다 · 추가 라운드 질문으로만 연다 · 열지 않으면 되돌린다 · 나눈 일의 멈춤 줄 · brief 가 바뀌면 리뷰를 다시 지난다).

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_end_gates.sh`
Expected: FAIL — `F4: B-S 부재 — 아래가 공허하다` 와 `F4 AC8 …` · `F4 AC14 …` 줄들.

- [ ] **Step 3: 글을 고친다**

편집 F16 · F5 · F6a · F7 · F8 을 건다. F6a 는 `#### B-1 — superpowers 가용성 분기` 제목 줄 바로 앞에 새 절을 끼운다(B-A 와 B-1 사이).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_end_gates.sh`. Expected: `✗` 줄 0.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_end_gates.sh
git commit -m "feat(spec-distill): 끝 질문 앞에서 건너뛴 것을 보이고 나중에 돌리는 길을 적는다 (F4)" -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_end_gates.sh
```

- [ ] **Step 6: 이빨 확인**

블록 T6 의 needle 마다 finishing.md 에서 그 글을 지우고 `test_end_gates.sh` 가 새 실패를 내는지 본다(짝 문서 「변이 표 — 글 needle」). 한 needle 이 창 밖의 다른 자리 글로도 채워지지 않는지(같은 글이 두 곳) 를 「지운 자리 1곳」 으로 함께 본다.

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t6 'finishing'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t6.out`
Expected: 출력 없음.

---

### Task 7: superpowers 가 없을 때의 끝 질문 (AC10)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 편집 F6b(B-1 의 「superpowers 부재 시」 갈래 — 선택지 셋의 끝 질문) · F4 · F12(재제시 상한 질문의 「지금 목록으로 확정」 이 돌아갈 자리) · F13 · F14(B-R 의 갈래 목록과 커밋 문장) · F15(B-4 의 예외 문장)
- Modify: `shared/tests/fixtures/ask-sites.tsv` — 새 질문 자리 두 행
- Test: `plugins/spec-distill/tests/test_superpowers_presence.sh`(블록 T7-a) · `test_end_gates.sh`(블록 T7-b) · `test_interview_state_flow.sh` · `test_decompose_surface.sh` · `test_conducting_interview_stage.sh`(블록 T7-c — 옛 문장을 단언하던 다섯 자리)

**Interfaces:**
- Consumes: 과제 3 의 다음 세션 줄 · 과제 6 의 `#### B-S` 와 B-2 게이트 앞 글 목록(1–5) · 지금 있는 B-3 의 확정 반영 절차 · ③ · ④ · 커밋 펜스(`interview-commit`) · B-R.
- Produces: B-1 의 끝 질문 — 머리글 `끝내기`, 선택지 셋 `확정하고 끝낸다 (권장)` · `확정 목록 수정` · `brief만 종료`.

이 질문은 공통 계약(`proceed-gate.md` Step B)의 질문이 아니다 — 그 파일은 고치지 않고, B-2 의 「선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로」 도 그대로 둔다. 「④ · B-1 은 PR 을 열지 않는다」(「PR 과 머지」 절)도 그대로다 — 「확정하고 끝낸다」 는 나눈 일이어도 커밋에서 멈춘다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- 블록 T7-a — `test_superpowers_presence.sh` 에서 `assert_contains "$absent" "brief를 완료하고"` 줄부터 `printf '%s\n' "$B1" > "$TMP/b1.md"` 줄 앞까지(옛 단언 넷)를 블록으로 바꾼다. 단언하는 것: 부재 갈래가 「**선택지 셋의 따로 된 끝 질문**」 을 띄운다 · 공통 계약의 질문이 아니다 · `{label: ` 줄이 정확히 셋 · 세 선택지의 이름과 설명 글자 · 앞 글 목록 · 상태 줄 · 「확정하고 끝낸다」 의 절차와 PR 을 열지 않음 · 끝 안내 줄 · 분해된 일의 한 줄 · 「확정 목록 수정」 이 이 끝 질문으로 돌아옴 · 「여기서 계속」 의 한 줄 · 건너뛴 것은 B-S 로 · 옛 멈춤 안내가 파일에 없음.
- 블록 T7-b — `test_end_gates.sh` 의 블록 T6 바로 뒤에 넣는다. B-0 · B-3 의 「지금 목록으로 확정」 이 「왔던 끝 질문」 으로 돌아간다 · B-R 의 갈래 목록과 커밋 문장 · B-4 의 끝내는 경로 둘 · 옛 문장 셋의 부재(양의 짝과 함께) · B-2 의 선택지 넷 문장은 그대로.
- 블록 T7-c — 옛 문장을 단언하던 자리 다섯:
  - `test_interview_state_flow.sh` — 「brief · audit · 상태 파일은 커밋하지 않았다」 줄을 끝 질문의 커밋 설명 단언과 옛 미커밋 안내의 부재로 바꾼다. 「AC5: 커밋 펜스 자리」 의 파이썬 조각은 B-1 창을 따로 잰다 — Step A~B-1 앞과 B-2~B-3 사이에는 커밋 글이 없고, B-1 창에는 `interview-commit` 이 정확히 한 번 있고 `git commit` 은 없다(펜스 자체는 B-3 에만 있다).
  - `test_decompose_surface.sh` — 분해된 일의 미커밋 안내 단언을 「분해된 일이어도 「PR 과 머지」 로 가지 않는다」 · 「분해된 일이면 그 앞에 지휘 세션을 …」 둘로 바꾼다.
  - `test_conducting_interview_stage.sh` — B-1 블록의 정규식을 `superpowers 부재 시.*끝 질문` 으로, 재제시 상한의 두 needle 을 새 문장으로 바꾼다. **그 두 줄의 `printf '%s' "$b1_block" | grep -q…` 를 here-string(`grep -q… <<<"$b1_block"`)으로 바꾼다** — 그 파일은 `pipefail` 을 켜 두었고, B-1 블록이 커지면 `grep -q` 가 먼저 닫아 `printf` 가 SIGPIPE 로 죽어 맞는 글인데도 실패한다(계획 단계에서 실제로 났다).

- [ ] **Step 2: 실패를 확인한다**

Run: `for t in test_superpowers_presence test_end_gates test_interview_state_flow test_decompose_surface test_conducting_interview_stage; do bash plugins/spec-distill/tests/$t.sh | grep -E '✗|FAIL:'; done; bash shared/tests/test_ask_recommendation.sh | grep -E '✗|FAIL:'`
Expected: FAIL — `F4 AC10: …` 줄들 · `B-1: 끝 질문의 커밋 설명이 없다` · `AC13: B-1 블록 안에 graceful-degradation 지시가 없다`. 질문 자리 락은 아직 통과다(새 질문이 없다).

- [ ] **Step 3: 글과 질문 자리 목록을 고친다**

1. 편집 F6b · F4 · F12 · F13 · F14 · F15 를 건다.
2. `shared/tests/fixtures/ask-sites.tsv` 의 finishing.md 행 가운데 `#### B-2 — 단일 \`AskUserQuestion\` proceed 게이트` 언급 행 **앞**에 두 행을 더한다(칸은 탭):

   ```
   plugins/spec-distill/skills/pm-interview/references/finishing.md	꼬리	**선택지 셋의 따로 된 끝 질문**을 띄운다	multiSelect: false	1
   plugins/spec-distill/skills/pm-interview/references/finishing.md	떼기	끝 질문의 답은 라벨 끝의	
   ```

- [ ] **Step 4: 통과를 확인한다**

Run: Step 2 의 명령. Expected: 출력 없음(여섯 테스트 모두 `✗` 줄 0).

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/pm-interview/references/finishing.md shared/tests/fixtures/ask-sites.tsv plugins/spec-distill/tests/test_superpowers_presence.sh plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_interview_state_flow.sh plugins/spec-distill/tests/test_decompose_surface.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): superpowers 가 없어도 끝 질문으로 확정과 커밋까지 간다 (F4)" -- plugins/spec-distill/skills/pm-interview/references/finishing.md shared/tests/fixtures/ask-sites.tsv plugins/spec-distill/tests/test_superpowers_presence.sh plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_interview_state_flow.sh plugins/spec-distill/tests/test_decompose_surface.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh
```

- [ ] **Step 6: 이빨 확인**

블록 T7-a · T7-b 의 needle 마다 finishing.md 에서 그 글을 지우고 그 테스트가 새 실패를 내는지 본다. 따로 흔들 것 셋: (가) 끝 질문에 넷째 선택지를 더한다 → 「선택지는 셋이다」 실패 (나) B-1 에 `interview-commit` 을 한 번 더 적는다 → 「AC5: 커밋 펜스 자리」 실패 (다) `ask-sites.tsv` 의 새 꼬리 행을 지운다 → 질문 자리 락 실패(덮이지 않은 질문 자리).

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t7 'finishing|ask-sites|ask_recommendation'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t7.out`
Expected: 출력 없음.

---

### Task 8: 머지 펜스 — 이미 머지됨 · 실패 뒤 머지됨 · 취소 경쟁 (AC11 · AC12)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 패치 B1 의 그 파일 부분(머지 펜스 `interview-merge` · 새 펜스 `interview-merge-recheck` · 「PR 과 머지」 절의 문장 넷)
- Test: `plugins/spec-distill/tests/test_finish_pr_merge.sh` — 패치 B1 의 그 파일 부분(단언 200 → 435, bash · zsh 두 구역)

**Interfaces:**
- Consumes: 지금 있는 `gh_repo.py` 하위 명령 `pr-number` · `pr-identity`(출력 `<state> <base> <head> <true|false> <head 커밋>`) — 새 하위 명령은 필요 없다(시제품이 확인했다).
- Produces:
  - 표시 줄 `interview-merge-requested: <PR 번호>` — 방식마다 `pr-merge` 를 부르는 줄 바로 앞.
  - 도우미 `merged()` — origin 을 받고(실패하면 지금의 「머지 뒤 origin 을 받지 못했다」 줄) `interview-merge: MERGED` 를 내고 끝난다. 정상 경로 · 이미 머지됨 · 실패 뒤 머지됨 셋이 같은 줄을 쓴다.
  - 새 펜스 마커 `<!-- interview-merge-recheck:begin -->` … `<!-- interview-merge-recheck:end -->`(머지 펜스 바로 아래). 입력은 `BRIEF` · `URL` 자리표 둘 — 끝 커밋은 받지 않는다. 읽기만 한다(`pr-merge` · `pr-checks` 를 부르지 않는다).
  - 새 줄(글자 그대로): `[spec-distill] PR 이 이미 머지돼 있다 — <URL>` · `[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — <URL>` · `[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — <URL>` · `[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: <상태>) — … <URL>` · `[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: <URL>`.

정한 것(설계가 비워 둔 자리 — 시제품이 고른 좁은 해석).
- **머지됨 판정은 상태 · 바탕 · 브랜치 · 같은 레포다.** `pr-identity` 가 `MERGED <기본 브랜치> <지금 브랜치> false …` 꼴이면 머지됨으로 읽는다. 끝 커밋은 대조하지 않는다(설계가 「상태가 머지됨이고 바탕 · 브랜치가 같으면」 이라고만 한다 — 물은 뒤 커밋이 더 올라온 채 머지됐어도 머지됨이다. 칸 11b 가 이 해석을 박는다).
- **이미 머지됨의 자리는 입력 가드 뒤, 「열린 PR 인가」 확인 앞이다.** CI 검사를 기다리지 않는다.
- **실패 뒤 머지됨은 다른 줄을 낸다.** 위에 gh 의 실패 사유가 보이므로 「실패로 끝났지만 머지돼 있다」 고 말한다. 다음 방식을 시도하지 않는다.
- **다시 확인은 새 펜스다.** 머지 펜스의 정상 경로가 머지 뒤 상태를 읽는 것과 같은 간격 · 횟수(5초 간격 네 번까지)로 읽는다 — 두 펜스의 sleep 기록을 등호로 대조해 박는다. 갈래는 넷이다: 머지됨 · 끝까지 열림 · 읽지 못함(Review Focus 4) · 머지됨인데 다른 PR(「아직 머지되지 않았다(읽은 상태: MERGED)」 라는 모순된 줄을 피한다).
- **표시 줄은 요청 «앞»에 낸다.** 그래서 표시 줄과 gh 시작 사이에 끊기면 요청이 나가지 않았어도 다시 확인이 돈다 — 판결은 `NONE` 이라 해는 없다.
- **본문의 판결 읽기 문장.** 「PR 과 머지」 절 머리와 3 걸음 「머지」 의 「판결 줄 없이 끝나면 … `NONE` 으로 읽는다」 를 고친다: 머지 펜스의 출력에 판결 줄이 없고 표시 줄이 있으면 `NONE` 으로 읽지 않고 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 지금처럼 `NONE` 이다. 절 머리의 「두 펜스는 gh 를 …」 은 「이 절의 펜스는 gh 를 …」 이 된다(펜스가 셋이다). 「④ · B-1 은 PR 을 열지 않는다」 문장과 PR 펜스의 글(1 걸음)은 그대로다.
- 다시 확인 펜스는 백그라운드로 띄우지 않는다(기다림이 15초까지다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

패치 B1 에서 테스트 부분만 건다(`.claude/tmp/f4/patch-b1.diff` 로 떠 놓고 `git apply --include='plugins/spec-distill/tests/test_finish_pr_merge.sh'`). 가짜 gh 에 모드가 더해진다 — `FAKE_MERGE=failmerged`(원격을 머지하고 rc 1) · `FAKE_MERGE=cut`(원격을 머지한 뒤 펜스의 pid 를 죽인다 — 펜스 앞에 테스트만의 한 줄 `echo $$ > "$FAKE_GH_DIR/fence.pid"` 를 붙여 돌린다) · `pr view` 의 `FAKE_VIEW_MERGED_AT=n` · `FAKE_HEAD_FROM2` · `FAKE_BASE` · `FAKE_CROSS` · `FAKE_VIEW_AUTH`. 가짜 sleep 은 인자를 적는다(간격을 잰다). 새 칸:

| 칸 | 재는 것 |
|---|---|
| 머리 | 다시 확인 펜스가 읽기만 한다(끝 커밋 자리표 · `pr-merge` · `pr-checks` · `pr-create` · push 없음) · 가드 줄이 다른 펜스와 글자 그대로 같다 · 본문 문장 셋을 글자로, 옛 문장 둘의 부재를 짝으로 |
| 5 · 7 · 9(기존 칸에 더함) | 표시 줄이 머지한 줄보다 먼저 한 번 · 검사 실패와 검사가 끝나지 않음에는 표시 줄이 없다 · 방식 거절은 「표시 → 거절 → 표시 → 머지」 순서 |
| 11 · 11b · 11c | 물을 때 이미 머지됨 → `MERGED` · 그 줄 · gh 로그에 `pr merge` · `pr checks` 없음 · 로컬 `refs/remotes/origin/main` 이 머지된 끝으로. 대조 셋(다른 브랜치 · 다른 바탕 · 다른 레포의 브랜치) → `NONE`. 끝 커밋이 달라도 `MERGED`. fetch 실패면 알리고 `MERGED` |
| 12 · 12b | 머지 명령 실패 뒤 머지됨 → `MERGED` · origin 받음 · `pr merge` 한 번. 대조: 다시 읽은 것이 다른 브랜치면 `NONE` |
| 13 | 요청 표시 뒤 끊김 → 출력에 표시 줄 하나 · 판결 줄 없음 → 다시 확인 펜스 `MERGED` · gh 로그가 `pr view` 한 줄뿐 · origin 받음 |
| 13b · 13c | 2번째 · 4번째 읽기에 머지됨 → `MERGED`. 5번째에야 머지됨 → 네 번에서 멈춰 `NONE`. 끝까지 열림 → `NONE` · 그 줄 전체(요청 사실 · 읽은 상태 · 주소) · sleep 기록이 머지 펜스의 것과 같다 |
| 13d | 자리표 그대로 · 다른 레포 주소 → `NONE` · gh 호출 0 |
| 13e | 읽지 못함(원격은 머지된 채) → `NONE` · 「읽지 못했다」 와 주소가 든 줄 · origin 을 받지 않는다. 짝: 같은 픽스처에서 읽을 수 있으면 `MERGED` |
| 13f | 머지됨인데 브랜치 · 바탕 · 레포가 다름 → `NONE` · 「다른 PR」 줄. 짝: 같으면 `MERGED` |

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_finish_pr_merge.sh | tail -1`
Expected: `Fail:` 이 0 이 아니다(머리 칸이 다시 확인 펜스를 뽑지 못한다 — 「전제: … 아래 칸이 공허하다」). 이 테스트는 길다(계획 단계에서 83–143초).

- [ ] **Step 3: 펜스와 글을 고친다**

패치 B1 의 finishing.md 부분을 건다(`git apply --exclude='plugins/spec-distill/tests/*' .claude/tmp/f4/patch-b1.diff`). 짝 문서의 패치 B1 은 과제 7 까지 건 트리에서 다시 뜬 것이다 — 시제품의 원래 패치(기준 6b923b62)는 과제 7 이 「PR 과 머지」 절 바로 위 줄을 바꾼 뒤 첫 hunk 가 걸리지 않았다. 그래도 걸리지 않으면 첫 hunk 는 짝 문서의 「찾을 구절 → 바꿀 구절」 로 손으로 걸고, 나머지는 위 **Interfaces** 와 「정한 것」 대로 마커 이름과 글자로 찾아 옮긴다(줄 번호는 앞 과제들이 밀어 놓았다). 펜스 첫 줄의 플러그인 루트 가드는 다른 펜스와 글자 그대로 같게 둔다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_finish_pr_merge.sh | tail -1; bash plugins/spec-distill/tests/test_gh_single_door.sh | tail -1; python3 tools/suite/run_unittest_dir.py plugins/spec-distill/tests test_finishing_block_scope.py | tail -1`
Expected: `Total: 435 | Pass: 435 | Fail: 0`(zsh 가 없으면 그 구역만큼 적다) · 실패 0 · `OK`.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_finish_pr_merge.sh
git commit -m "fix(spec-distill): 이미 머지된 PR 과 끊긴 머지 요청을 머지됨으로 읽는다 (F4)" -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_finish_pr_merge.sh
```

- [ ] **Step 6: 이빨 확인**

짝 문서 「변이 표 — 과제 8 · 9」 에서 패치 칸이 b1 인 변이를 finishing.md 사본에 걸어 돌린다. 변이마다 변이된 펜스가 `bash -n` · `zsh -n` 을 통과하는지 먼저 본다. 최소한 아래 열한 개가 전부 실패를 내야 한다(계획 단계에서는 b1 · b2 를 합쳐 예순셋이 전부 죽었고, 한 셸에서만 실패한 변이는 없었다).

| 변이 | 무엇을 흔드나 |
|---|---|
| m1 · m2 · m3 | 이미 머지됨 갈래를 뗀다 · 브랜치 · 레포를 대조하지 않는다 · origin 을 받지 않는다 |
| m4 | 실패 뒤 머지됨 갈래를 뗀다 |
| m5 · m6 | 표시 줄을 뗀다 · 표시 줄을 `pr-merge` 뒤로 옮긴다 |
| m7 · m8 · m9 | 다시 확인 펜스가 한 번만 읽는다 · 머지됨에서 origin 을 받지 않는다 · 끝까지 열림일 때 PR 주소를 싣지 않는다 |
| m13 · m14 | 읽기 실패를 머지됨으로 읽는다 · 읽기 실패 때 PR 주소를 싣지 않는다 |

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t8 'finishing|gh_repo'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t8.out`
Expected: 출력 없음. `test_finish_commit_roadmap.sh` 의 「다른 이름의 로드맵: 세 파일과 로드맵 폴더가 한 커밋에」 는 기준선에도 있는 기존 실패다(파일 정렬 순서 — 이 에픽과 무관하다).

---

### Task 9: PR 단계의 「값의 출처」 줄 (AC13)

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 패치 B2 의 그 파일 부분(PR 펜스 `interview-pr` 의 작은 함수 `nosrc` 와 그 함수를 앞에 붙인 호출 둘)
- Test: `plugins/spec-distill/tests/test_finish_pr_merge.sh` — 패치 B2 의 그 파일 부분(단언 435 → 511)

**Interfaces:**
- Consumes: 과제 8 을 건 `test_finish_pr_merge.sh`(패치 B2 는 B1 의 줄에 기댄다 — 기준 트리에 바로는 걸리지 않는다). 설정 해결자가 stderr 로 내는 줄 `[spec-distill] 값의 출처: <출처>(<키>)`(`repo_defaults.py` 의 `get` · `check-path` 만 낸다 — 그 스크립트는 고치지 않는다).
- Produces: PR 펜스의 `nosrc <명령…>` — 받은 명령의 stderr 를 임시 파일로 받아 `^\[spec-distill\] 값의 출처: ` 줄만 뺀 나머지를 stderr 로 다시 내고, 임시 파일을 지우고, 명령의 종료 코드를 그대로 돌려준다. 임시 파일을 만들지 못하면 거르지 않고 명령을 그대로 돈다.

정한 것.
- 거르는 것은 PR 펜스의 `check-path interview_dir` · `check-path roadmaps_dir` 두 호출뿐이다(끝내기 커밋 펜스가 같은 키로 이미 보였다). 끝내기 커밋 펜스 · Step A · 리뷰가 내는 줄은 건드리지 않는다. 머지 · 다시 확인 펜스에는 그 줄이 원래 없다(`default-branch` 만 부른다).
- 호출 줄의 `repo_defaults.py" check-path <키>` 글자는 그대로 둔다 — 함수 안에 숨기지 않는다(그 글자를 찾는 락과 grep 이 계속 닿는다).
- **짝으로 잰다**(리뷰 지적 2e6610eb#r4.1): 「값의 출처」 줄만 빠지고, 경로 판정의 실패 사유 줄 · 알림 줄 · 경고 줄은 PR 단계 출력에 그대로 남고, 종료 코드도 그대로다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

패치 B2 에서 테스트 부분만 건다(`.claude/tmp/f4/patch-b2.diff` · `git apply --include='plugins/spec-distill/tests/test_finish_pr_merge.sh'`). 가짜 mktemp 가 더해진다(`FAKE_MKTEMP_FAIL` · 만든 경로를 적는다). 새 칸:

| 칸 | 재는 것 |
|---|---|
| 14a | PR 펜스 출력에 「값의 출처」 가 없다 + 짝 1 — 같은 픽스처에서 `check-path` 를 키 둘로 직접 부르면 rc 0 이고 그 줄이 나온다(펜스가 걸러서 없는 것이지 원래 없는 것이 아니다) |
| 짝 2(칸 3b · 3c 안) | 해결자의 사유 줄(「부모 폴더가 다르다: …(roadmaps_dir)」 · 「…(interview_dir)」)이 PR 펜스 출력에 그대로 있다 · 사유 줄은 stderr 로, 펜스의 줄은 stdout 으로 간다 |
| mktemp 실패 | 거부되는 판정 — `OPEN` · `MIXED` · 그 폴더의 파일이 목록에 · 「빼지 않은 사실」 줄 · 사유 줄 · 「값의 출처」 줄 둘(거르지 않는다). 통과하는 판정 — `ONLY` · 「값의 출처」 줄 둘 |
| 14b | 끝내기 커밋 펜스를 같은 방식으로 뽑아 돌리면 「값의 출처」 줄이 키마다 하나씩 나오고, 이어 돈 PR 펜스에는 없다 · 임시 파일 셋을 만들고 하나도 남기지 않는다 |
| 14c · 14d | 알림 줄(「레포 설정 파일(.devbrew.md)이 아직 기본 브랜치에 없다」)과 경고 줄(「동시 작업 권장 수는 1 이상의 정수다」)이 판정마다 그대로 남는다 |

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_finish_pr_merge.sh | grep -E '✗' | head`
Expected: FAIL — 「값의 출처」 가 PR 펜스 출력에 아직 있다는 칸들.

- [ ] **Step 3: PR 펜스를 고친다**

패치 B2 의 finishing.md 부분을 건다(`git apply --exclude='plugins/spec-distill/tests/*' .claude/tmp/f4/patch-b2.diff`).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_finish_pr_merge.sh | tail -1`
Expected: `Total: 511 | Pass: 511 | Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_finish_pr_merge.sh
git commit -m "fix(spec-distill): PR 단계가 값의 출처 줄을 한 번 더 보이지 않는다 (F4)" -- plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/tests/test_finish_pr_merge.sh
```

- [ ] **Step 6: 이빨 확인**

패치 칸이 b2 인 변이를 건다. 최소한 넷이 실패를 내야 한다:

| 변이 | 무엇을 흔드나 |
|---|---|
| m10 | 「값의 출처」 거름을 뗀다 |
| m11 | 거름이 stderr 전체를 버린다(사유 줄까지) |
| m12 | 거름이 종료 코드를 삼킨다 |
| m12c · m12d | 임시 파일을 못 만들 때 종료 코드를 삼킨다 · 임시 파일을 지우지 않는다 — 계획 단계의 첫 실행에서 둘 다 살아남아 단언을 보강했다(「MIXED」 만으로는 가르지 못했고, macOS 의 인자 없는 `mktemp` 는 `TMPDIR` 을 따르지 않아 남은 파일을 보는 단언이 공허했다) |

- [ ] **Step 7: 넓은 락**

Run: `bash .claude/tmp/f4/narrow.sh t9 'finishing|repo_defaults'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-t9.out`
Expected: 출력 없음.

---

### Task 10: 판 · CHANGELOG · README · 의존 표 — 그리고 전체 확인 (AC15)

**Files:**
- Modify: `plugins/spec-distill/README.md` — 편집 M1(흐름 그림) · M2(핸드오프 문구의 자리) · M3(reference 목록에 지시 파일) · M4(Prerequisites 의 superpowers 줄) · M5(「판정 없는 종료를 거절한다」 에 건너뜀을 더한다)
- Modify: `plugins/spec-distill/dependencies.md` — 편집 D1(superpowers 행의 「없을 때」 칸. 판 칸은 건드리지 않는다)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` — `version`
- Modify: `plugins/spec-distill/CHANGELOG.md` — 새 머리와 항목
- Modify: `docs/superpowers/specs/2026-11-15-front-stage-exit-design.md` — `## 미룸` 표에 행 추가만(본문은 그대로)
- Create(git 이 추적하지 않는다): `.claude/tmp/f4/ac-report.txt`

**Interfaces:**
- Consumes: 과제 2–9 의 커밋 전부.
- Produces: PR 을 열 수 있는 브랜치 끝과 AC 보고 파일.

- [ ] **Step 1: 기본 브랜치를 받아들인다**

기본 브랜치 이름은 해결자에서 읽는다 — `python3 plugins/spec-distill/scripts/repo_defaults.py default-branch --check-remote`. `git fetch origin` 뒤 `git merge origin/<기본 브랜치>`(rebase 가 아니다). 충돌이 나면: `finishing.md` · `check_brief.py` 는 이 에픽의 글을 지키되 저쪽이 더한 줄을 버리지 않는다. `CHANGELOG.md` · `plugin.json` · `README.md` 는 저쪽 것을 받은 뒤 아래 걸음에서 이 에픽의 것을 얹는다. 충돌을 푼 뒤 과제 2–9 의 좁은 테스트를 전부 다시 돌린다. 충돌이 이 에픽의 글과 뜻이 부딪히면(같은 문장을 저쪽도 고쳤다) 멈춰 보고한다.

- [ ] **Step 2: README 와 의존 표를 맞춘다**

편집 M1–M5 · D1 을 건다. `test_superpowers_presence.sh` 가 재는 구절(「지휘자」 · 「진입에서 멈춘다」 · 「다르면 알린다」)은 그 줄들에 그대로 남는다.

Run: `bash plugins/spec-distill/tests/test_superpowers_presence.sh | grep -E '✗|FAIL:'; bash plugins/spec-distill/tests/test_readme_sync.sh | grep -E '✗|FAIL:'`
Expected: 출력 없음.

- [ ] **Step 3: 판과 CHANGELOG 를 올린다**

1. 그때의 판을 읽는다 — `git show origin/<기본 브랜치>:plugins/spec-distill/.claude-plugin/plugin.json` 의 `version`. 새 판은 그 minor 를 하나 올리고 patch 를 0 으로 둔 것이다(이 에픽은 새 표면을 더한다 — 건너뜀 줄 · 지시 파일 · 끝 질문). 번호를 이 계획에서 옮겨 적지 않는다.
2. `plugin.json` 의 `version` 을 그 값으로 바꾼다.
3. `CHANGELOG.md` 맨 위(`# Changelog` 아래)에 `## [<새 판>] — <그날 날짜 YYYY-MM-DD>` 머리를 두고 아래를 쉬운 말로 적는다(내부 단계 이름 · 지적 번호를 쓰지 않는다):
   - `### Added` — 건너뜀 줄(모델이 이유를 적고 범위 조사 · 맹점 조사 · 포화 판정 · 재비판 · codex · 읽어 보기를 건너뛰면 구조 검사가 받고 끝 질문 앞에서 무엇을 왜 건너뛰었는지 보인다 · 나눈 일은 받지 않는다) · 지시 파일 `references/brief-handoff.md` · superpowers 가 없을 때의 끝 질문(선택지 셋) · 머지 다시 확인 펜스와 표시 줄.
   - `### Changed` — 인터뷰 끝의 다음 세션 줄이 짧아졌다(지시는 지시 파일에) · 「사용자 선호:」 라벨을 뗐다 · `coverage-mapper 0 (unavailable:)` 의 빈 이유는 이제 실패다 · superpowers 가 없어도 확정 · 커밋까지 간다(전에는 커밋하지 않고 멈췄다).
   - `### Fixed` — 이미 머지된 PR 과 gh 가 실패로 끝났는데 머지된 PR 을 머지됨으로 읽고 origin 을 받는다 · 머지 요청 직후 끊겨도 다시 확인한다 · PR 단계가 「값의 출처」 줄을 한 번 더 보이지 않는다.

Run: `bash shared/tests/test_changelog_integrity.sh | grep -E '✗|FAIL:'; bash shared/tests/test_plugin_description_parity.sh | grep -E '✗|FAIL:'`
Expected: 출력 없음.

- [ ] **Step 4: 커밋**

```bash
git add -- plugins/spec-distill/README.md plugins/spec-distill/dependencies.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): 판을 올리고 변경 기록 · README · 의존 표를 맞춘다 (F4)" -- plugins/spec-distill/README.md plugins/spec-distill/dependencies.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
```

- [ ] **Step 5: 넓은 락과 전체 스위트**

1. Run: `bash .claude/tmp/f4/narrow.sh final '<과제 1 Step 4 의 패턴 그대로>'` 뒤 `LC_ALL=C comm -13 .claude/tmp/f4/narrow-base.out .claude/tmp/f4/narrow-final.out` — Expected: 출력 없음.
2. 전체 스위트를 Global Constraints 의 잠금 줄로 한 번 돌린다(`--owner` 는 지휘자가 준 이름). Expected: `FAILED` 줄이 기준선(과제 1 의 기존 실패)과 같다. 잠금을 못 잡으면(종료 코드 75) 그 줄의 주인 · 잡은 시각을 보고하고 기다린다.

- [ ] **Step 6: 마지막 전체 리뷰와 AC 보고**

고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC1–AC15 를 그대로 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 한다. 그 보고를 `.claude/tmp/f4/ac-report.txt` 에 적는다. 리뷰에는 끝에서 끝 흐름도 묻는다 — 건너뜀 줄이 「쓰는 곳 → 대기 줄 블록 → audit §2 → 구조 검사 → 끝 질문 앞 글」 로 끊기지 않는지, 그리고 건너뛴 것을 나중에 돌리는 네 갈래가 어디로 돌아오는지.

미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 행으로 올리고 그 변경만 따로 커밋한다(`docs(spec): 앞단의 끝 설계 — 구현에서 미룬 것 (F4)`).

- [ ] **Step 7: PR 앞 확인**

Run: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-15-front-stage-exit-design.md .claude/tmp/f4/ac-report.txt`
경고가 나오면 그대로 사용자에게 보인다(지휘자가 옮긴다). PR 은 지휘자가 연다 — 이 과제는 push 하지 않는다.
