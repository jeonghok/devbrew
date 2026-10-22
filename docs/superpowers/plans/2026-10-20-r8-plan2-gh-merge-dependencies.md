# R8 계획 2 — gh 필수 · 머지 판정 · 의존 선언 · 판 확인 · project-init 훅 Implementation Plan

**실행 방식:** Subagent-driven — 사용자 선택 「Subagent-driven (권장)」(2026-10-20)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **시작 조건 — 구현은 R10 · R12 · R13 이 모두 기본 브랜치에 머지되고(사용자 결정 U10) 이 에픽의 계획 1 이 머지된 뒤(또는 계획 1 브랜치 끝 위에 쌓아) 시작한다.** 구현 담당은 먼저 `origin/<기본 브랜치>` 를 merge 하고 이 계획이 인용한 파일 · 함수 · 절을 하나도 빠짐없이 새로 읽어 확인한다(Task 0). 이 계획은 설계 승인(60e21baa) 때 쓰고, R10 · R12(계획 셋) · R13 · 지휘자 수리 3(#245)이 머지된 main(6bd168d1)을 이 브랜치에 합친 트리(d0d787e8)에 맞춰 고쳤다 — 그 사이 `skills/spec-interview` 가 `skills/pm-interview` 로 옮겨졌고, 세 skill 폴더 펜스의 상태 폴더 쓰기가 `nofollow_write.py` 를 지나며(R13), 스위트 대조와 통합 리뷰 묶음이 브랜치 끝을 `branch_tip.py` 하나로 고른다(#245). 계획 1 머지(#249) 뒤 main(c5755690)에서 Task 0 이 인용 자리 · gh 자리 · 각 과제가 건드리는 락을 다시 읽어 과제 본문을 맞췄다. 파일은 줄 번호가 아니라 절 · 함수 이름으로 가리킨다.

**Goal:** gh 를 필수 의존으로 삼아 squash · rebase 로 머지한 에픽도 PR 상태로 「머지됨」을 판정하고(여섯 조건 · 지휘자만 채우는 캐시), 모든 gh 호출이 `origin` 레포를 명시하며, 의존마다 개발 당시 판을 선언하고 정한 강도로 확인하고, project-init 훅이 Bash 와 EnterWorktree 뒤의 새 브랜치 이름을 관찰해 알린다.

**Architecture:** spec-distill 에 gh 호출을 한 곳에 모은 `scripts/gh_repo.py` 를 두고(`-R <host>/<owner>/<repo>` · 없음 · 인증 · 비 GitHub 은 멈춤), 지휘자가 `ledger pr-refresh` 로 기계 상태 `## PR` 표(칸을 늘림)를 채우면 `roadmap_status.py` 가 그 표만 입력으로 머지됨을 판정한다 — 상태줄 · 상태 보기는 gh 를 부르지 않는다. 의존은 플러그인마다 `dependencies.md` 표 하나와 공유 `shared/deps/check_deps.py`(플러그인마다 심볼릭 링크)가 재고 확인한다. project-init 훅은 정규식을 넓히지 않고 실행 뒤 reflog 를 본다.

**Tech Stack:** Python 3(표준 라이브러리), bash 3.2 호환 셸, gh CLI(가짜 gh 를 PATH 앞에 둔 테스트), 레포 셸 테스트 하네스(`shared/tests/assert.sh`), `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-10-20-dependency-portability-design.md` (§4 · §5 · §3 끝 불릿(RC82) · §8 의 해당 행 · §10 · AC13~AC23 · AC23a · AC28 · AC29 의 계획 2 몫)

## 목차

- [Global Constraints](#global-constraints)
- [설계와 다른 점 · 설계에 없던 결정](#설계와-다른-점--설계에-없던-결정)
- [Review Focus](#review-focus)
- [넘김 대조 — 이 계획이 받는 것](#넘김-대조--이-계획이-받는-것)
- [Task 0: 머지 뒤 다시 읽기 · 기준선](#task-0-머지-뒤-다시-읽기--기준선)
- [Task 1: gh_repo.py — origin 명시 · 없음 · 인증 · 비 GitHub (AC16 · AC20 · AC23a 의 코드)](#task-1-gh_repopy--origin-명시--없음--인증--비-github-ac16--ac20--ac23a-의-코드)
- [Task 2: PR 캐시 칸 · ledger pr-refresh (AC17 의 캐시 · §4 판정을 맡는 곳)](#task-2-pr-캐시-칸--ledger-pr-refresh-ac17-의-캐시--4-판정을-맡는-곳)
- [Task 3: 기계 상태의 쓴 판 · 낮은 판 읽기 멈춤 (AC21)](#task-3-기계-상태의-쓴-판--낮은-판-읽기-멈춤-ac21)
- [Task 4: 머지됨 판정 — 여섯 조건 · 받기 전 · 캐시 없음 (AC14 · AC15)](#task-4-머지됨-판정--여섯-조건--받기-전--캐시-없음-ac14--ac15)
- [Task 5: 상태줄 · 상태 보기는 gh 를 부르지 않는다 · 지휘자의 gh 는 gh_repo 로 (AC17 · AC20 · AC23a)](#task-5-상태줄--상태-보기는-gh-를-부르지-않는다--지휘자의-gh-는-gh_repo-로-ac17--ac20--ac23a)
- [Task 6: qg 의 gh — origin 명시 · 대체 길 지움 (AC16 · AC20 의 qg 몫)](#task-6-qg-의-gh--origin-명시--대체-길-지움-ac16--ac20-의-qg-몫)
- [Task 7: 의존 목록 파일 · 측정 · 판 판독 (AC18 · AC19 의 판독)](#task-7-의존-목록-파일--측정--판-판독-ac18--ac19-의-판독)
- [Task 8: 진입 확인 · 훅의 Python 바닥 (AC19 · AC23a 의 진입)](#task-8-진입-확인--훅의-python-바닥-ac19--ac23a-의-진입)
- [Task 9: superpowers 판 알림 · 부재 시 멈춤 · qg 부재 알림 (AC22 · AC23 · K11)](#task-9-superpowers-판-알림--부재-시-멈춤--qg-부재-알림-ac22--ac23--k11)
- [Task 10: project-init 훅 — Bash · EnterWorktree 뒤 새 브랜치 관찰 (AC13 · RC82)](#task-10-project-init-훅--bash--enterworktree-뒤-새-브랜치-관찰-ac13--rc82)
- [Task 11: 회귀 픽스처 · 문서 · 버전 · 스위트 대조 (AC28 · AC29 의 계획 2 몫)](#task-11-회귀-픽스처--문서--버전--스위트-대조-ac28--ac29-의-계획-2-몫)

## Global Constraints

- **시작 시점.** R10 · R12 · R13 · 이 에픽 계획 1 머지 뒤. 브랜치 `feature/gh-merge-dependencies`(로드맵 R8 의 둘째 브랜치 — 기본 브랜치에서 새로 만든다). 시작 때 기본 브랜치를 merge 한다(rebase 금지). 커밋은 pathspec, `git stash` 금지, HEAD 를 뒤로 옮기지 않는다.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 판 번호는 이 계획에 적지 않는다 — 지휘자가 구현 dispatch 때 정해 준다(spec-distill · quality-gates · project-init · plugin-audit 를 올린다). CHANGELOG 머리는 plugin.json 과 같게.
- **세 skill 폴더 펜스의 상태 폴더 쓰기는 `nofollow_write.py` 로.** request-framing · reviewing-brief · spec-review 의 `.md` 펜스에서 상태 폴더에 쓰는 줄은 `"$<루트>/scripts/nofollow_write.py" run|empty|append --out …` 를 지나고, writer 를 부르는 루트 변수는 그 펜스가 다른 스크립트(`check_deps.py` 포함)를 부르는 루트 변수와 같다. 집행은 `plugins/spec-distill/tests/test_state_dir_writes.sh`(`scan_writes`) — 그 폴더의 펜스를 더하거나 고치는 과제는 이 테스트를 Test 목록에 둔다.
- **펜스 사이 변수 나르기 금지.** 한 bash 펜스는 앞 펜스에서만 정의된 변수를 쓰지 않는다. `finishing.md` 와 `references/redecompose.md` 둘 다 `plugins/spec-distill/tests/test_finishing_block_scope.py` 가 잰다 — 두 파일의 펜스를 더하거나 고치는 과제는 이 테스트를 Test 목록에 둔다.
- gh 는 필수다 — gh 가 없을 때의 대체 길 · 강등 길을 코드에 남기지 않는다(U1). 지원 범위는 origin 이 GitHub(gh 가 다루는 호스트)인 레포다(U9). 지원 흐름은 내 레포 안 흐름 — PR · 기본 브랜치는 언제나 `origin`(U8).
- gh 를 쓰지 않는 진입(인터뷰 · request-framing · roadmap-status · 상태줄 · plugin-audit · project-init)은 gh 를 보지 않는다. 인증은 진입마다 묻지 않고 첫 gh 호출이 실패할 때 멈춘다.
- 판 비교는 판 문자열에서 숫자 셋(`\d+\.\d+\.\d+` 첫 일치)만 뽑아 정수로 비교한다. 못 뽑으면 멈춘다. 최소 판은 그 플러그인 판을 개발 · 검증할 때 실제로 깔려 있던 판이다(U2 · U3) — 손으로 적지 않고 측정 명령이 쓴다.
- Claude Code plugin.json `dependencies` 는 쓰지 않는다(superpowers 가 없으면 플러그인 전체가 꺼져 U6 과 충돌).
- 모든 훅에 kill switch(`DEVBREW_PROJECT_INIT_DISABLE=1` · `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` · `:PostToolUse`). 훅은 조언자다 — 막지 않는다.
- 셸은 macOS bash 3.2 · zsh 호환(`$var` 뒤 한글은 `${var}` · `$( )` 안 heredoc 금지 · 배열 첨자 대입 금지). 스크립트 파일 읽기는 `encoding="utf-8"`, 플러그인 `.py` 에 `"python3"` 리터럴 금지, 인라인 python 은 `python3 -I`, 새 셸 테스트는 `chmod +x` 후 `100755` 확인.
- 공유 스크립트를 플러그인에 심볼릭 링크로 둘 때는 형제 모듈을 import 하지 않는다(링크로 돌면 `sys.path[0]` 이 정본 폴더다 — `shared/entry/entry_preflight.py` 머리말과 같다). 플러그인 루트는 인자 `--plugin-root` 로 받는다.
- 사람에게 보이는 새 문면은 `shared/style/plain-language.md`(첫 줄 상태 · 번호는 내용 뒤 괄호 · 끝에 할 일 하나). 모델이 읽는 새 문면에는 출처 · 배경 · 정당화를 쓰지 않는다.
- 락은 변이로 이빨을 확인하고 음의 락에는 양의 짝. 변이 전에 커밋하고 복원은 `git checkout HEAD --` + `git diff HEAD`. `PYTHONDONTWRITEBYTECODE=1`. 가짜 gh 는 받은 인자를 파일에 적어 테스트가 `-R` 값을 단언한다.

## 설계와 다른 점 · 설계에 없던 결정

1. **gh 호출을 모은 새 모듈 `plugins/spec-distill/scripts/gh_repo.py`** — 지휘자(`conductor_ledger.py`) · 상태 계산(origin 소유자만 읽음) 둘이 쓰고 qg 는 같은 일을 하는 셸 `plugins/quality-gates/scripts/gh-repo.sh` 를 둔다(다른 플러그인이라 공유하지 않는다). 설계의 「새 모듈을 만들지 않는다」는 레포 값 해결자에 대한 것이다.
2. **기계 상태 `## PR` 표의 칸은 아홉이다**: `브랜치 · 번호 · 상태 · 확인한 때 · headRefOid · 교차 레포 · baseRefName · mergeCommit · 쓴 세션`(설계의 「받은 시각」 = 지금의 「확인한 때」). 옛 판의 4칸 줄은 읽지 못한다는 오류와 함께 고치는 명령 `ledger pr-refresh --roadmap <로드맵> --session <세션> --reset`(PR 절만 비우고 다시 채움)을 보인다 — 조용히 버리지 않는다.
3. **브랜치 끝이 없을 때**: 다른 다섯 조건에 맞는 캐시 줄이 하나면 그 줄의 `headRefOid` 를 끝으로 쓰고 「브랜치 끝 없이 판정 — 캐시의 headRefOid <8자>」를 알린다. 둘 이상이면(같은 이름을 다시 쓴 브랜치) 「머지됨」이 아니라 「셀 수 없음 — 같은 이름의 머지된 PR 이 여럿이고 브랜치 끝이 없다」.
4. **「머지됨(받기 전)」은 단계가 아니라 경고다** — 단계는 그 전 계산(구현 끝 · PR 등)대로 두고 경고 「머지됨(받기 전) — git fetch 뒤 다시 계산한다」를 단다. 끝난 단계로 세지 않는다.
5. **qg 게시 sink 의 gh 없음은 `failed: gh-unavailable` 이다**(지금 `skipped: gh-unavailable`). 마지막 줄 리터럴에 `failed:` 하나를 더한다 — 「건너뜀」은 대체 길이었다. quality-pipeline 이 이 줄을 오류로 보이고 설치 방법을 낸다.
6. **의존 목록 파일은 `plugins/<플러그인>/dependencies.md`** — 머리말(`type: devbrew-dependencies` · `plugin:`) + 표 `| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |`(강도 ∈ 멈춤 · 알림 · 기록). README prerequisites 는 이 파일을 가리킨다.
7. **확인 · 측정은 공유 `shared/deps/check_deps.py`**(플러그인마다 `scripts/check_deps.py` 링크) 하나의 하위 명령 셋 — `entry` · `superpowers` · `measure`. skill 진입의 의존 확인은 `!` 사전 검사 줄이 아니라 진입 단계 첫 걸음의 Bash 펜스다(`allowed-tools` 는 사전 검사 한 줄만 · `!` 의 rc≠0 은 skill 호출을 통째로 끊는다).
8. **superpowers 판의 출처**: 측정은 개발 세션의 모델이 본 skill 기준 폴더 경로(`…/superpowers/<판>/skills/…`)를 `--superpowers-base` 로 넘긴다. 확인도 같은 꼴 — 부르는 자리의 모델이 불러온 skill 의 기준 폴더 경로를 넘긴다. Claude Code 판은 `claude --version` 의 숫자 셋을 기록만 한다.
9. **plugin-audit · project-init 의 의존 행은 Python · Claude Code 둘**(설계 §5 표대로 git 확인은 spec-distill · qg 진입만). quality-gates 행은 Python · git · gh · Claude Code. spec-distill 행은 Python · git · gh · superpowers · quality-gates · Claude Code. codex CLI 는 이 표에 넣지 않고 README 의 지금 줄을 둔다(설계 표 밖).
10. **merge_check 는 gh 를 부르지 않는다** — 설계 §5 의 「gh 를 쓰는 진입」 목록에 있지만 스위트 대조에는 gh 호출이 없어 gh 확인을 더하지 않는다(지휘자 진입이 이미 gh 를 확인한다).
11. **project-init 훅의 「새 브랜치」**: `refs/heads/<b>` reflog 의 마지막 줄이 만들기(`branch: Created from …`) 또는 이름 바꾸기 · 복사(`Branch: renamed|copied refs/heads/… to refs/heads/<b>`)이고 그 시각이 지금부터 60초 안인 브랜치. reflog 파일은 공용 git 디렉토리의 `logs/refs/heads/` 를 직접 읽는다(브랜치마다 git 을 띄우지 않는다). 상태 파일을 두지 않는다. Task 10 Step 1 실측으로 고쳤다: `checkout -b` · `checkout -B` · `switch --create` 도 브랜치 reflog 에는 `branch: Created from HEAD` 를 남기고(`checkout: …` 줄은 HEAD reflog 에만 있다), `branch -c` 가 `Branch: copied …` 를 남겨 복사를 더했다.
12. **Python 바닥은 경로마다 실측 판이다(설계 U12 「경로마다 실측 판 (권장)」)** — skill 진입의 `python` 행은 잰 `python3` 판(지금 3.9.6), 훅 바닥은 새 `python-hook` 행(훅이 `devbrew-python.sh` 로 실제로 쓰는 해석기 판, 지금 3.12)이다. 설계 §5 표의 옛 글자 「훅 바닥 값도 개발 당시 판에 맞춘다」를 한 행으로 읽어 훅을 3.9 로 내리지 않는다. 설계와 다른 점 9 의 행 목록에 project-init 의 `python-hook` 이 더해진다(Task 8).

## Review Focus

1. **에픽을 지휘자 밖에서 squash 로 머지했다.** 사람은 상태줄 · `/spec-distill:roadmap-status` 가 그 에픽을 「PR 상태 미확인 — 지휘자를 돌려라」로 보이고, 다음 지휘자 진입에서 캐시를 채운 뒤 「머지됨」으로 바뀌길 기대한다. 낡은 캐시로 다음 에픽 착수 게이트가 열리지 않는다. Task 4 · 5 의 사례가 잠근다.
2. **fork 클론에 `upstream` 원격이 있고 `GH_REPO` 까지 설정돼 있다.** 사람은 devbrew 가 부모 레포가 아니라 `origin` 의 PR 만 보고, 환경 변수를 무시했다는 알림을 한 줄 보길 기대한다. Task 1 · 6 의 가짜 gh 인자 단언이 잠근다.
3. **브랜치 이름을 다시 썼다 — 같은 이름의 옛 PR 은 MERGED, 새 PR 은 열림.** 사람은 옛 PR 때문에 에픽이 「머지됨」으로 보이지 않길 기대한다. 머지 뒤 로컬에만 커밋이 더 붙은 브랜치도 그렇다. Task 4 의 `headRefOid` 사례가 잠근다.
4. **gh 는 깔렸지만 로그인하지 않았고 오프라인에서 인터뷰한다.** 사람은 인터뷰가 gh 를 보지 않고 돌며, 지휘자는 첫 gh 호출에서 「gh auth login --hostname <호스트>」를 보이고 멈추길 기대한다. Task 1 의 인증 사례와 Task 8 의 진입 목록 락이 잠근다.
5. **플러그인을 갱신했는데 이 기계의 machine.md 는 옛 판이 썼다(4칸 PR 줄).** 사람은 빈 캐시로 조용히 읽히는 대신 고치는 명령 한 줄과 함께 멈추길 기대한다. 반대로 옛 설치본 세션이 새 판이 쓴 machine.md 를 읽으면 「플러그인을 업데이트하라」로 멈춘다. Task 2 · 3 의 사례가 잠근다.

## 넘김 대조 — 이 계획이 받는 것

전체 표는 계획 1 `## 넘김 대조`. 이 계획 몫:

| 넘김 | 받는 과제 |
|---|---|
| #245 — `branch_tip.py` 공유(merge_check · review-pack) | Task 0 Step 3(다시 읽기) · Task 4 Step 3(상태 계산은 설계 §4 의 로컬 먼저 — `branch_tip.tip` 을 쓰지 않는다) |
| R13 — Global Constraints 두 줄 · 계획 2 Task 8 의 Test 목록에 `test_state_dir_writes.sh` · `test_finishing_block_scope.py` | Global Constraints · Task 8 · Task 9(finishing.md 펜스) |

---

### Task 0: 머지 뒤 다시 읽기 · 기준선

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r8-plan2/baseline.sh` (레포 밖)
- Modify: 이 계획 파일(자리 고침이 있으면)

- [ ] **Step 1: 시작 조건.** R10 · R12 · R13 의 PR 과 이 에픽 계획 1 의 PR 이 MERGED 인지(아니면 계획 1 브랜치 끝 위인지) 확인한다. 아니면 멈추고 지휘 세션에 보고한다.
- [ ] **Step 2: `git merge --no-edit origin/<기본 브랜치>`** (기본 브랜치 이름은 계획 1 의 `repo_defaults.py default-branch` 로).
- [ ] **Step 3: 인용 자리를 다시 읽는다.** `control_plane.py` 의 `gh_lookup_for` · `merged_prs` · `overlay` · `cache_key` · `statusline_text` · `GH_STATES` · `GH_CALL_CAP` · `gather` 의 `use_gh` · `conductor_ledger.py` 의 `_gh` · `_prs` · `c_pr_handoffs` · `c_audit` · `c_review_pack` 의 gh 자리 · `_version_parts` · `version_report` · `branch_tip.py` 전체(#245 — 스위트 대조 · 통합 리뷰 묶음의 끝 고르기, 앞선 쪽을 쓰고 갈라지면 멈춘다) · `conductor_state.py` 의 `SECTIONS` · `_check_row` · `parse_machine` · `render_machine` · `load` · `save` · `roadmap_status.py` 의 `merged_by` · `MERGE_MSG_RE` · `NOTICE` · `compute` 의 브랜치 끝 자리(`refs/heads/` 먼저, 없으면 `refs/remotes/origin/`) · `references/conducting.md` 의 걸음 1 · 5 · 6 · 7 과 손 절차 1 · 5 · 6 · 8 의 gh · PR 문장 · `skills/epic-conductor/SKILL.md` 의 `## 진입 단계`(`### 1. 감시줄 판독` ~ `### 4. 시작 승인`) · `skills/pm-interview/references/finishing.md` 의 superpowers 넘김(`#### B-1` · `#### B-2`) · 모든 skill 의 진입 단계(감시줄 판독 다음 걸음) · qg `discover-spec.sh` 의 PR 본문 읽기 · `publish-comment.sh` 의 gh 자리 · `quality-pipeline/SKILL.md` 의 sink 결과 처리 · `plugins/project-init/hooks/post-tool-use.py`(`BRANCH_CREATE_RE` · `PROTECTED_BRANCHES` · `get_branch_pattern` · `validate_branch` · `main`) · `hooks.json` · `shared/python/devbrew-python.sh` 와 사본 `plugins/project-init/scripts/devbrew-python.sh` 의 `FLOOR_*` · `shared/tests/test_python_floor.sh` · 루트 `README.md` 의 Python 절 · 네 플러그인 README 의 Prerequisites · 락 `plugins/spec-distill/tests/test_state_dir_writes.sh`(세 skill 폴더 펜스) · `tests/test_finishing_block_scope.py`. 이름이 바뀌었으면 이 계획을 고쳐 쓴다.
- [ ] **Step 4: gh 자리를 다시 센다.** `git grep -n -e 'shutil.which("gh")' -e 'command -v gh' -e '"gh"' -e 'gh pr ' -e 'gh api' -- plugins shared ':!*CHANGELOG*' ':!*/tests/*'` — 결과를 아래 목록과 대조하고 더 있으면 Task 1 · 5 · 6 의 고칠 목록에 더한다. d0d787e8 에서 센 것:
  - `plugins/spec-distill/scripts/conductor_ledger.py` 의 `_gh`(`shutil.which("gh")`) — Task 5
  - `plugins/spec-distill/scripts/control_plane.py` 의 `gh_lookup_for`(`shutil.which("gh")` · `gh pr list … --limit 1`) — Task 5(지움)
  - `plugins/spec-distill/references/conducting.md` 의 걸음 4(돌아오기) 구현 agent 보고 거두기 문장(`gh pr create` · `ledger add --section PR` · 괄호의 「`gh` 가 없으면 PR 을 열 명령을 …」) — Task 2 · 손 절차 5 의 「`gh` 가 없으면 PR 을 열 명령을 …」 · 손 절차 8(머지 전 확인)의 통합 리뷰 불릿 「`gh` 가 없거나 GitHub 레포가 아니면 …」 — Task 5
  - `plugins/quality-gates/scripts/discover-spec.sh` 의 `command -v gh` · `gh pr view`(두 자리) — Task 6
  - `plugins/quality-gates/scripts/publish-comment.sh` 의 `command -v gh` · `gh pr view` · `gh pr comment` — Task 6
  - `plugins/quality-gates/README.md` 의 게시 sink 줄 · 의도 출처 줄(`gh 없음`) — Task 6
  - `plugins/project-init/templates/shared/pr-process.md` 의 `gh pr create` — 사용자 레포에 까는 템플릿 문서라 그대로(devbrew 가 부르는 gh 가 아니다)

  c5755690(계획 1 머지 뒤)에서 다시 셌다 — 위 목록 그대로이고, 낱말 `gh` 로 넓혀 센 문장 자리가 더 있다:
  - `plugins/spec-distill/scripts/conductor_ledger.py` 의 `c_pr_handoffs` 첫 줄 `_gh()` — Task 5(`_gh` 를 지울 때 함께)
  - `plugins/spec-distill/scripts/roadmap_status.py` 머리말 「control_plane 이 기계 상태 또는 `gh` 로 덧씌운다」 — Task 5
  - `plugins/quality-gates/README.md` 의 게시 단락 「gh 없음·미인증」 · 인증 확인 단락의 `skipped: gh-unavailable` — Task 6
  - `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 의 sink 사유 목록(`gh-unavailable`) — Task 6
  - `plugins/spec-distill/README.md` Prerequisites 의 「gh CLI (외부, optional) … 강등한다」 — Task 11
- [ ] **Step 5: 기준 스위트.** 계획 1 Task 0 Step 5 와 같은 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r8-plan2/` 에 두고 버릴 clone 에서 `before` 를 잰다.

---

### Task 1: `gh_repo.py` — origin 명시 · 없음 · 인증 · 비 GitHub (AC16 · AC20 · AC23a 의 코드)

**Files:**
- Create: `plugins/spec-distill/scripts/gh_repo.py`
- Test: `plugins/spec-distill/tests/test_gh_repo.sh` (새 — 가짜 gh), `plugins/spec-distill/tests/test_gh_repo.py` (새 — URL 판독)

**Interfaces:**
- Produces:
  - `class GhStop(RuntimeError)` — 사람에게 보일 한 줄을 메시지로.
  - `origin_slug(cwd: str) -> tuple[str, str, str]` — (host, owner, repo). `git config --get remote.origin.url` 를 판독: `https://[user@]host[:port]/owner/repo[.git][/]` · `ssh://[user@]host[:port]/owner/repo[.git]` · `[user@]host:owner/repo[.git]`. 원격이 없거나 못 뽑으면 `GhStop("origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다")`. 호스트는 포트를 떼고 소문자.
  - `gh_exe() -> str` — 없으면 `GhStop("gh 가 없다 — devbrew 는 gh 를 필수로 쓴다. https://cli.github.com 에서 설치한다")`.
  - `env_notices() -> list[str]` — `GH_REPO` · `GH_HOST` 가 설정돼 있으면 「<이름> 이 설정돼 있다(<값>) — devbrew 는 -R 로 origin 을 명시해 쓴다」.
  - `gh_json(cwd: str, args: list[str], timeout: float = 15.0) -> object` — `gh_exe()` 를 먼저, 그다음 `origin_slug` 를 본다(gh 가 없으면 원격과 무관하게 「gh 가 없다」 문장 — Task 5 의 review-pack 사례가 이 문장을 단언한다). `[gh, *args, "-R", "<host>/<owner>/<repo>"]`, env `GH_PROMPT_DISABLED=1 NO_COLOR=1 GH_NO_UPDATE_NOTIFIER=1`. rc≠0 일 때 stderr 를 셋으로 가른다: 인증(`auth login` · `not logged` · `authentication`) → `GhStop("gh 인증이 안 됐다 — gh auth login --hostname <host> 를 돈다")`; 레포를 못 찾음 · 호스트를 모름 → `GhStop("gh 가 origin(<host>/<owner>/<repo>)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 지원한다")`; 그 밖 → `GhStop("gh 실패(rc <n>): <stderr 첫 줄>")`. 시간 초과도 `GhStop`.
  - `pr_list(cwd: str, branch: str, limit: int = 100) -> tuple[list[dict], bool]` — `pr list --state all --head <branch> --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit --limit <limit>`; (목록, 한도에 닿았는가). 모양이 다르면 `GhStop`.
  - CLI `gh_repo.py slug` — stdout `<host>/<owner>/<repo>` · rc 0, 못 뽑으면 rc 3 + 사유(지휘 절차의 `gh pr create -R` 가 쓴다).

- [ ] **Step 1: 실패하는 테스트.** `test_gh_repo.py`: URL 꼴 일곱(https · https+user · https+port · `.git` 없음 · ssh:// · scp 꼴 · 끝 `/`) → 같은 세 값 · 못 뽑는 URL 셋(`file:///x` · 경로만 · owner 없음) → `GhStop`. `test_gh_repo.sh`(임시 레포 + PATH 앞의 가짜 gh — 받은 인자를 파일에 적고 `FAKE_GH_MODE` 로 출력 · rc 를 고름):
  - `fork_with_upstream`: `origin=https://github.com/me/r` · `upstream=https://github.com/up/r` → 가짜 gh 가 받은 인자에 `-R github.com/me/r`(AC16 · AC29 「upstream 원격이 있는 fork」).
  - `ghe_host`: `origin=git@ghe.example.com:o/r.git` → `-R ghe.example.com/o/r`(호스트 보존).
  - `gh_repo_env`: `GH_REPO=up/r` → `env_notices` 한 줄, 그래도 `-R github.com/me/r`.
  - `no_gh`: PATH 에서 gh 를 뺌 → `GhStop` 문장에 `cli.github.com`.
  - `auth_fail`: 가짜 gh rc 4 + `gh auth login` 안내 → 문장에 `gh auth login --hostname github.com`.
  - `non_github`: `origin=https://gitlab.com/o/r` · 가짜 gh 가 「could not resolve」 → 「GitHub 인 레포만」(AC20).
  - `no_origin`: 원격 없음 → `slug` rc 3.
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_gh_repo.py; bash plugins/spec-distill/tests/test_gh_repo.sh` — Expected: 모듈 없음 · `✗`.
- [ ] **Step 3: 구현.** git 은 `subprocess.run(["git", "-C", cwd, "config", "--get", "remote.origin.url"], timeout=5)`.
- [ ] **Step 4: 통과를 본다.** 같은 명령 — Expected: OK · `✗` 0.
- [ ] **Step 5: 변이**: `-R` 을 빼면 `fork_with_upstream` RED · 호스트를 버리고 `owner/repo` 만 → `ghe_host` RED · 인증 갈래를 「그 밖」으로 → `auth_fail` RED.
- [ ] **Step 6: 커밋** — `feat(spec-distill): gh 호출을 origin 명시 · 멈춤 규칙과 함께 한 곳에`

---

### Task 2: PR 캐시 칸 · `ledger pr-refresh` (AC17 의 캐시 · §4 판정을 맡는 곳)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_state.py` (`SECTIONS` 의 PR 칸 · `_check_row` · `load(…, skip=())`), `conductor_ledger.py` (새 하위 명령 `pr-refresh`), `references/conducting.md` (PR 을 연 뒤 · 걸음 1 맞추기 · 머지 전 확인 · 다음 에픽 착수 게이트 직전에 `ledger pr-refresh`, `gh pr create` 에 `-R "$(python3 "<SD>"/scripts/gh_repo.py slug)"`, 걸음 4 의 `ledger add --section PR` 손 적기 문장과 같은 문장 괄호의 「`gh` 가 없으면 PR 을 열 명령을 …」 지움 — 손 절차 5 · 8 의 gh 없음 문장은 Task 5), 4칸 PR 줄을 `cs.save` 로 쓰는 픽스처 둘(`tests/test_control_plane.py` 의 PR 줄 더하기 · `tests/test_control_plane.sh` 의 `d["PR"].append`)을 9칸으로
- Test: `plugins/spec-distill/tests/test_conductor_state.py`, `tests/test_conductor_ledger.py`, `tests/test_conducting_reference.sh`, `tests/test_control_plane.py`, `tests/test_control_plane.sh`(픽스처만 — 이 과제 뒤에도 GREEN)

**Interfaces:**
- Consumes: Task 1 의 `pr_list` · `GhStop`
- Produces:
  - `conductor_state.SECTIONS` 의 `("PR", ("브랜치", "번호", "상태", "확인한 때", "headRefOid", "교차 레포", "baseRefName", "mergeCommit", "쓴 세션"))`. 검사: `headRefOid` 는 40자 16진, `교차 레포` ∈ `예` · `아니오`, `mergeCommit` 은 40자 16진 또는 `-`, 상태 ∈ `열림` · `머지됨` · `닫힘`.
  - 4칸 PR 줄 → `MachineError("<n>줄: 옛 판이 쓴 PR 캐시 줄이다(칸 4개) — ledger pr-refresh --roadmap <로드맵> --session <세션> --reset 으로 다시 채운다")`.
  - `conductor_state.load(path, roadmap_rel, skip: tuple = ())` — `skip` 에 든 절은 줄 검사 없이 비운다(`--reset` 만 쓴다).
  - `ledger pr-refresh --roadmap R --session S [--epic E] [--reset]` — 대상 블록(없으면 로드맵의 끝나지 않은 블록 전부)의 브랜치 목록 — `c_pr_handoffs` 와 같이 상태 계산 보고(`_status`)의 블록 `branches`(기본 브랜치에 아직 없는 로드맵 사본이 더한 브랜치 포함) — 마다 `pr_list` 로 그 head 이름의 PR 을 **모두** 받아 그 브랜치의 PR 줄을 통째로 바꾼다. 한도에 닿으면 경고 한 줄. `env_notices` 를 보인다. 출력 끝 줄 `PR 캐시: 브랜치 <n>개 · PR <m>개를 <때> 에 채웠다`. 표지를 쥔 세션만 쓴다(`cs.save`).

- [ ] **Step 1: 실패하는 테스트.** `test_conductor_state.py`: 9칸 줄 왕복 · 4칸 줄 오류 문장에 `--reset` · `교차 레포: 몰라` 거부 · `skip=("PR",)` 이면 4칸 줄이 있어도 읽힌다. `test_conductor_ledger.py`(가짜 `pr_list` 주입): 같은 head 이름 PR 셋(내 레포 MERGED · 남의 fork MERGED · 내 레포 OPEN)이 모두 줄이 된다 · 표지를 쥐지 않은 세션은 쓰지 못한다 · `--reset` 이 옛 4칸 줄을 지우고 다시 채운다. `test_conducting_reference.sh`: 지휘 절차에 `pr-refresh` 가 걸음 1 과 게이트 직전에 있고 `ledger add --section PR` 손 적기 문장이 없다(양 · 음 짝). 「gh 가 없…」 문장 부재 락은 남은 두 자리를 지우는 Task 5 가 둔다.
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_ledger.py; bash plugins/spec-distill/tests/test_conducting_reference.sh` — Expected: FAIL.
- [ ] **Step 3: 구현.** 확인한 때는 `YYYY-MM-DD HH:MM`(로컬). `mergeCommit` 은 gh JSON 의 `mergeCommit.oid`(없으면 `-`).
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py; bash plugins/spec-distill/tests/test_control_plane.sh`(9칸 픽스처) — Expected: OK · `✗` 0.
- [ ] **Step 5: 변이**: `--limit 1` 로 → 셋 사례 RED · `isCrossRepository` 를 버림 → 칸 검사 RED.
- [ ] **Step 6: 커밋** — `feat(spec-distill): 지휘자가 PR 캐시를 head 이름의 PR 전부로 채운다`

---

### Task 3: 기계 상태의 쓴 판 · 낮은 판 읽기 멈춤 (AC21)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_state.py` (`render_machine` · `parse_machine` · 새 `own_version` · `version_triple`), `conductor_ledger.py` (`_version_parts` 를 `cs.version_triple` 로), `tests/test_conductor_ledger.py` 의 `VersionReport.test_forms`(두 마디 판 `7.3` 은 이제 숫자 셋을 못 뽑아 rc 1 「판을 비교하지 못했다」 — Global Constraints 의 판 비교 규칙. `v7.3.0` · `7.3.1-rc1` 은 그대로 rc 0)
- Test: `plugins/spec-distill/tests/test_conductor_state.py`, `tests/test_conductor_ledger.py`(`VersionReport`)

**Interfaces:**
- Produces:
  - `conductor_state.version_triple(text: str) -> tuple[int, int, int] | None` — 첫 `\d+\.\d+\.\d+`.
  - `conductor_state.own_version() -> str` — `Path(__file__).resolve().parent.parent / ".claude-plugin" / "plugin.json"` 의 `version`(이 파일은 링크가 아니다).
  - 머리말에 `writer: spec-distill <판>` 한 줄. `parse_machine` 은 `writer` 판 > 자기 판이면 `MachineError("이 기계 상태는 더 새 판(spec-distill <쓴 판>)이 썼다 — 플러그인을 업데이트하고 세션을 다시 연다(지금 판 <판>)")`. `writer` 가 없으면 멈추지 않는다(이 검사를 갖추기 전 판이 쓴 파일).

- [ ] **Step 1: 실패하는 테스트.** `test_writer_stamp_roundtrip` · `test_newer_writer_stops_older_reader`(`own_version` 을 `7.0.0` 으로 바꿔 끼우고 `writer: spec-distill 9.1.0` 읽기 → 오류 문장에 「업데이트」) · `test_missing_writer_is_read` · `test_same_or_older_writer_is_read`.
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py -v` — Expected: FAIL.
- [ ] **Step 3: 구현 · 통과.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py` — Expected: OK.
- [ ] **Step 4: 커밋** — `feat(spec-distill): 기계 상태에 쓴 판을 찍고 낮은 판의 읽기는 멈춘다`

---

### Task 4: 머지됨 판정 — 여섯 조건 · 받기 전 · 캐시 없음 (AC14 · AC15)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`merged_by` 를 둘로 · `MERGE_MSG_RE` 에 owner 그룹 · `compute` 의 브랜치 끝 · `NOTICE` · 기계 상태 PR 표 읽기), `plugins/spec-distill/README.md` (상태 계산 줄), `plugins/spec-distill/templates/roadmap-template.md` (결정 기록의 머지 줄 안내)
- Test: `plugins/spec-distill/tests/test_merged_by_pr.py` (새), `tests/test_roadmap_status.sh`, `tests/test_roadmap_render.py`(템플릿 문장)

**Interfaces:**
- Consumes: Task 2 의 PR 표 · Task 1 의 `origin_slug`(owner 만) · 계획 1 의 `repo_defaults.default_branch`
- Produces:
  - `merged_by_pr(rows: list[dict], branch: str, tip_local: str | None, tip_remote: str | None, default_short: str, reachable: Callable[[str], bool]) -> tuple[str | None, list[str]]` — (판정 ∈ `"머지됨"` · `"머지됨(받기 전)"` · `"셀 수 없음"` · `None`, 알림 줄). 후보 = `브랜치 == branch ∧ 상태 == 머지됨 ∧ 교차 레포 == 아니오 ∧ baseRefName == default_short`. 끝 = `tip_local or tip_remote`; 둘 다 있고 다르면 알림 「로컬 끝 <8자> · 원격 끝 <8자>」. 끝이 있으면 `headRefOid == 끝` 인 후보만. 끝이 없으면 「설계와 다른 점 3」. 맞는 줄의 `mergeCommit` 이 기본 ref 에서 닿으면 `"머지됨"`, 아니면 `"머지됨(받기 전)"` + 「git fetch 뒤 다시 계산한다」.
  - `merged_by_git(git, merges, main, branch, tip, origin_owner) -> str | None` — 지금의 두 길. 문면 길은 `Merge pull request #n from <owner>/<브랜치>` 의 owner 가 `origin_owner` 일 때만.
  - `compute` 는 그 브랜치의 PR 줄이 캐시에 하나라도 있으면 `merged_by_pr` 만, 없으면 `merged_by_git` + 손 머지 줄 + 블록 알림 「PR 상태 미확인 — 지휘자를 돌려라」. 기계 상태를 못 읽으면(깨짐) 캐시 없음으로 가고 그 사유를 알림에 싣는다. 머지 뒤 revert(기본 ref 의 그 뒤 커밋 메시지에 `This reverts commit <mergeCommit>`)는 알림만.
  - `NOTICE` 새 문장: 「머지됨은 PR 상태로 판정한다(지휘자가 채운 PR 캐시) — 캐시가 없으면 머지 커밋과 이 레포 소유자의 머지 메시지로 알아보고 「PR 상태 미확인」을 보인다. 결정 기록의 머지 줄은 PR 없이 로컬에서 머지한 경우에만 쓴다. …(경로 예약 문장은 그대로)」. README 상태 계산 줄과 템플릿 머지 줄 안내도 같은 규칙으로.

- [ ] **Step 1: 실패하는 테스트**(`test_merged_by_pr.py`, 순수 함수):

```python
def test_squash_merged_without_manual_line(self):           # AC14
    v, _ = rs.merged_by_pr([row(oid=TIP, merge=M)], "feature/x", TIP, None, "main", lambda c: True)
    self.assertEqual(v, "머지됨")
def test_cross_repo_is_not_merged(self): ...                  # 교차 레포 예 → None (AC15)
def test_cross_repo_even_when_branch_deleted(self): ...       # 끝 없음 + 교차 레포 예 → None
def test_reused_name_old_pr_is_not_merged(self): ...          # 옛 MERGED headRefOid ≠ 끝 → None
def test_non_default_base_is_not_merged(self): ...            # baseRefName "release" → None
def test_commits_after_merge_is_not_merged(self): ...         # 끝이 더 나아감(로컬만 포함) → None
def test_deleted_branch_single_row_notices(self):            # 끝 없음 · 줄 하나 → "머지됨" + 「브랜치 끝 없이 판정」
def test_deleted_branch_two_rows_is_uncountable(self): ...   # → "셀 수 없음"
def test_not_fetched_is_not_merged(self):                     # reachable False → "머지됨(받기 전)", 알림에 git fetch
def test_local_and_remote_tips_differ_both_shown(self): ...
```

`test_roadmap_status.sh`(임시 레포): squash 머지(머지 커밋 없음) + 캐시 줄 → 단계 「머지됨」 · 손 머지 줄 없음 · 캐시 없음 → 알림 「PR 상태 미확인」 · 남의 owner 문면(`Merge pull request #3 from other/feature/x`) 은 세지 않음 · 「머지됨(받기 전)」 블록을 의존하는 다음 블록이 「대기」. 템플릿 · README · NOTICE 의 옛 문장(「squash · rebase 로 머지했거나 … 머지 줄을 적는다」)이 없다는 음의 락과 새 문장 양의 짝.
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_merged_by_pr.py; bash plugins/spec-distill/tests/test_roadmap_status.sh` — Expected: FAIL.
- [ ] **Step 3: 구현.** 상태 계산은 여전히 네트워크를 쓰지 않는다(`GIT_ALLOWED` 에 `config` 를 더하지 않고 owner 는 `gh_repo.origin_slug` 로 — 그 함수의 git 호출 하나만). 브랜치 끝은 설계 §4 대로 로컬 먼저 · 없으면 원격이고 다르면 둘 다 알린다 — `branch_tip.tip`(앞선 쪽을 고르고 갈라지면 멈춘다 — 스위트 대조 · 통합 리뷰 묶음의 규칙)을 이 판정에 쓰지 않는다. ref 를 커밋으로 푸는 데 `branch_tip.resolve` 를 다시 써도 되지만, 상태 계산의 git 은 `roadmap_status.Git` 를 지나야 하므로(허용 하위 명령 목록) 그 클래스의 `commit` 으로 읽는다. `compute` 에서 `merged_by` 를 부르는 자리는 둘이다(블록 `브랜치:` 의 상태 줄 · 로드맵 사본이 더한 브랜치(`extras_for`)) — 두 자리 모두 같은 규칙(그 브랜치의 PR 줄이 캐시에 있으면 `merged_by_pr`, 없으면 `merged_by_git`)을 지난다. `origin_slug` 가 `GhStop`(origin 없음 · 못 뽑음)을 내면 상태 계산은 멈추지 않고 문면 길을 세지 않으며 그 사유를 알림에 싣는다.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py'` — Expected: 새 실패 없음.
- [ ] **Step 5: 변이**: 여섯 조건을 하나씩 지움(교차 레포 · base · head 이름 · oid · mergeCommit 닿음 · 상태) — 각각 그 사례가 RED 인지 표로 남긴다. 문면 길의 owner 비교를 지움 → 남의 owner 사례 RED.
- [ ] **Step 6: 커밋** — `feat(spec-distill): squash · rebase 머지를 PR 캐시의 여섯 조건으로 판정한다`

---

### Task 5: 상태줄 · 상태 보기는 gh 를 부르지 않는다 · 지휘자의 gh 는 `gh_repo` 로 (AC17 · AC20 · AC23a)

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py` (`gh_lookup_for` · `GH_STATES` · `GH_CALL_CAP` 지움 · `merged_prs` · `overlay` 의 gh 갈래 지움 · `cache_key` 에 PR 캐시 지문 · 상태줄의 캐시 나이), `conductor_ledger.py` (`_gh` · `_prs` 를 `gh_repo` 로 — `c_pr_handoffs` 첫 줄의 `_gh()` 포함 · gh 없음의 「설계문서 미룸 표 · 지휘 기록을 쓴다」 대체 지움), `roadmap_status.py` 머리말의 「control_plane 이 기계 상태 또는 `gh` 로 덧씌운다」(기계 상태만), `references/conducting.md` (손 절차 8(머지 전 확인)의 통합 리뷰 불릿 「`gh` 가 없거나 GitHub 레포가 아니면 …」 · 손 절차 5 의 「`gh` 가 없으면 PR 을 열 명령을 …」 지움), `tests/test_roadmap_approval.py`(`cp.merged_prs(b, prs, gh)` · `cp.overlay(…, gh_lookup, use_gh)` 를 새 모양으로)
- Test: `plugins/spec-distill/tests/test_control_plane.py` · `test_control_plane.sh` · `test_conductor_ledger.py` · `test_roadmap_approval.py` · `test_conducting_reference.sh`(「gh 가 없…」 문장 부재 — 백틱 표기 `` `gh` 가 없 `` 까지 — 음의 락과 `gh_repo.py slug` 양의 짝), `plugins/spec-distill/tests/test_gh_single_door.sh` (새)

**Interfaces:**
- Consumes: Task 1 · 2
- Produces:
  - `control_plane.pr_cache_fingerprint(machine: dict | None) -> str` — PR 줄들을 정렬해 sha256. `cache_key` 의 parts 에 더한다.
  - 상태줄 꼴: `… · PR 캐시 <N>시간 전` 또는 `PR 캐시 없음`(가장 최근 `확인한 때` 기준, 네트워크 없음).
  - 캐시에 없는 PR 은 `_pr_unknown("PR 캐시에 없다 — 지휘자가 채운다")`.
  - `conductor_ledger._prs` 는 인계 절을 읽으려고 PR `body` 가 필요하다 — Task 1 의 `pr_list`(필드에 `body` 없음)가 아니라 `gh_repo.gh_json(cwd, ["pr", "list", "--state", "all", "--head", <브랜치>, "--json", "number,state,body", "--limit", str(PR_LIMIT)])` 를 쓴다. `review-pack` · `audit` 가 `Fail` 을 잡아 사유를 싣는 길(공시)은 그대로다 — `test_conductor_ledger.py` 의 gh 없는 PATH 사례(`handoffs.md` 에 「gh 가 없다」)가 GhStop 문장으로 계속 통과한다.

- [ ] **Step 1: 실패하는 테스트.** `test_control_plane.sh`: PATH 에 gh 가 없어도 `statusline` · `show` 가 rc 0 이고 「gh」 낱말이 출력에 없다(AC23a) · PR 캐시 줄만 바꿔도 다시 계산한다(캐시 열쇠) · 상태줄에 `PR 캐시`. `test_gh_single_door.sh`: spec-distill `scripts/*.py` 에서 gh 를 실행하는 줄(`shutil.which("gh")` · `"gh"` 를 argv 첫 칸으로)이 `gh_repo.py` 에만 있다 · qg `scripts/` 에서 `command -v gh` 가 `gh-repo.sh` 에만 있다(Task 6 뒤 GREEN) — 양의 짝: 두 파일에는 있다. 판독은 `ast` 로(문자열 grep 의 헤더 만족 함정 회피).
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_control_plane.sh; bash plugins/spec-distill/tests/test_gh_single_door.sh` — Expected: `✗`.
- [ ] **Step 3: 구현.** `overlay(…, use_gh)` 의 인자 이름을 `detail` 로 바꾼다(원장 · 판정을 읽는가) — gh 와 무관해진다. `conductor_ledger` 의 `GhStop` 은 `Fail(3, <문장>)` 로.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_roadmap_approval.py; bash plugins/spec-distill/tests/test_conducting_reference.sh` — Expected: OK. 단 `test_gh_single_door.sh` 의 qg 쪽(`command -v gh` 가 `gh-repo.sh` 에만) `✗` 줄은 Task 6 이 GREEN 으로 만든다 — 이 과제에서는 그 이름의 줄만 남고 spec-distill 쪽과 양의 짝은 GREEN 이다.
- [ ] **Step 5: 변이**: `gh_lookup_for` 를 되살림 → 단일 문 락 RED · 지문을 열쇠에서 뺌 → 다시 계산 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 상태줄 · 상태 보기는 PR 캐시만 읽고 gh 대체 길을 지운다`

---

### Task 6: qg 의 gh — origin 명시 · 대체 길 지움 (AC16 · AC20 의 qg 몫)

**Files:**
- Create: `plugins/quality-gates/scripts/gh-repo.sh`
- Modify: `plugins/quality-gates/scripts/discover-spec.sh` (PR 본문 읽기), `publish-comment.sh` (gh 확인 · `pr view` · `pr comment` · 머리 주석의 사유 리터럴 줄), `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (sink · 의도 출처 결과 처리 · sink 사유 목록), `plugins/quality-gates/README.md` (게시 sink 줄 · 게시 단락의 「gh 없음·미인증」 · 인증 확인 단락 · 의도 출처 줄)
- Test: `plugins/quality-gates/tests/test_gh_repo.sh` (새), `test_discover_spec.sh`, `test_publish_comment_sink.sh`, `test_publish_gh_two_files.sh`

**Interfaces:**
- Produces: `gh-repo.sh` — stdout `<host>/<owner>/<repo>` · rc 0. origin 없음 · 못 뽑음 → rc 3 + stderr 사유. gh 없음 → rc 4 + stderr 「gh 가 없다 — https://cli.github.com 에서 설치한다」. `GH_REPO` · `GH_HOST` 가 있으면 stderr 알림. URL 판독 규칙은 Task 1 과 같다(사례 표를 같은 일곱으로 맞춘다).
- `discover-spec.sh`: gh 없음 · 못 뽑음 → 지금의 `intent_note: gh 없음` 대신 rc 3 과 사유 줄(`stop: <사유>`) — quality-pipeline 이 그 줄을 보이고 멈춘다. PR 은 `gh pr view "<지금 브랜치>" -R "<slug>"`.
- `publish-comment.sh`: gh 없음 → 마지막 줄 `failed: gh-unavailable`(rc ≠ 0). `pr view` · `pr comment` 에 `-R "<slug>"`. 인증 실패는 지금처럼 첫 호출(`gh auth status --active` — 인자를 바꾸지 않는다, `test_publish_comment_sink.sh` 의 P5 단언)에서 — 메시지에 `gh auth login --hostname <host>`. `skip gh-unavailable` 자리는 다섯이다(gh 없음 · 미인증 · `pr view` 오류 · PR 번호 못 읽음 · 코멘트 쓰기 실패) — `failed:` 로 바뀌는 것은 gh 없음 하나이고 나머지 넷은 지금의 `skipped: gh-unavailable` 그대로다(그 단언들도 그대로).
- 문면 자리: `test_publish_gh_two_files.sh` 는 qg 추적 파일 전부(tests · CHANGELOG · README 빼고)의 산문까지 `gh <하위 명령>` 을 센다 — `gh auth login` 같은 안내 글은 sink · `discover-spec.sh` 의 메시지에만 두고, `gh-repo.sh` · quality-pipeline SKILL.md 는 스크립트가 낸 줄을 보이게만 한다(그 글자를 적지 않는다).

- [ ] **Step 1: 실패하는 테스트.** `test_gh_repo.sh`(qg): URL 일곱 · fork 의 upstream 무시 · gh 없음 rc 4. `test_discover_spec.sh`: gh 없음 → rc 3 · `stop:` 줄(지금 단언 `intent_note: gh 없음` 을 바꾼다) · 가짜 gh 인자에 `-R github.com/me/r`. `test_publish_comment_sink.sh`: gh 없음 → `failed: gh-unavailable`(지금 `skipped:` 단언을 바꾼다) · `pr comment` 인자에 `-R`. `test_publish_gh_two_files.sh`: gh 를 부르는 qg 파일 목록에 `gh-repo.sh` 를 더하고 쓰기는 여전히 `publish-comment.sh` 하나.
- [ ] **Step 2: 실패를 본다.** Run: `for t in test_gh_repo test_discover_spec test_publish_comment_sink test_publish_gh_two_files; do bash plugins/quality-gates/tests/$t.sh; done` — Expected: `✗`.
- [ ] **Step 3: 구현.** 두 스크립트가 `slug="$(bash "$HERE/gh-repo.sh")" || …` 로 받고 빈 값을 거부한다.
- [ ] **Step 4: 통과 · 단일 문 락.** 같은 명령 + `bash plugins/spec-distill/tests/test_gh_single_door.sh` — Expected: `✗` 0.
- [ ] **Step 5: 커밋** — `fix(quality-gates): gh 는 origin 을 명시하고 없으면 멈춘다`

---

### Task 7: 의존 목록 파일 · 측정 · 판 판독 (AC18 · AC19 의 판독)

**Files:**
- Create: `shared/deps/check_deps.py`, `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/scripts/check_deps.py` (→ `../../../shared/deps/check_deps.py` 링크), `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/dependencies.md`
- Modify: `shared/README.md` 의 `## 디렉토리` 표(`deps/` 한 줄)
- Test: `shared/tests/test_check_deps.sh` (새), `shared/tests/test_check_deps.py` (새), `shared/tests/test_copy_of_contract.sh`(새 링크 넷이 심볼릭 링크 계약의 코퍼스에 든다)

**Interfaces:**
- Produces(`check_deps.py`, 형제 import 없음):
  - `version_triple(text: str) -> tuple[int, int, int] | None` — 첫 줄에서 첫 `\d+\.\d+\.\d+`.
  - `read_table(path) -> list[dict]` — 머리말 `type: devbrew-dependencies` 확인, 표 다섯 칸. 깨졌으면 오류(멈춤).
  - `measure --plugin-root R [--superpowers-base <경로>] [--today YYYY-MM-DD]` — 표의 `최소 판` · `잰 날짜` 를 잰 값으로 바꿔 쓴다(강도 · 없을 때 칸은 그대로). python 은 이 스크립트를 돌린 `python3` 의 `sys.version_info`, git 은 `git --version`, gh 는 `gh --version` 첫 줄, claude-code 는 `claude --version`, superpowers 는 `--superpowers-base` 의 `/superpowers/<판>/skills/`, quality-gates 는 레포 사본 `<R>/../quality-gates/.claude-plugin/plugin.json`. 재지 못한 행은 그대로 두고 알린다(손으로 적지 않는다 — 다음 측정에서).
- 각 플러그인 `dependencies.md` 행(설계와 다른 점 9). 처음 값은 이 Task 의 Step 4 측정이 쓴다.

- [ ] **Step 1: 실패하는 테스트.** `test_check_deps.py`: 판 문자열 — `Python 3.9.6` · `git version 2.54.0 (Apple Git-157)` · `git version 2.47.1.windows.2` · `gh version 2.88.1 (2026-03-12)\nhttps://github.com/cli/cli/releases/tag/v2.88.1` · `2.45.0-rc1`(AC29 「-suffix 판 문자열」) · `2.1.303 (Claude Code)` → 셋 · 못 뽑는 `git version unknown` → None. 표 판독 — 칸 넷인 행 · 머리말 없음 → 오류. `test_check_deps.sh`: 임시 플러그인 루트에서 `measure` 가 표를 고치고 강도 칸은 그대로 · 링크 넷이 정본을 가리킨다(`git ls-files -s` 의 120000).
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest shared/tests/test_check_deps.py; bash shared/tests/test_check_deps.sh` — Expected: FAIL.
- [ ] **Step 3: 구현.** 통과 확인에 `bash shared/tests/test_copy_of_contract.sh` 를 더한다 — Expected: `✗` 0.
- [ ] **Step 4: 측정해 네 표를 쓴다.** 개발 세션의 모델이 이 세션에서 불러온 superpowers skill 의 기준 폴더 경로를 넘긴다: `python3 plugins/<p>/scripts/check_deps.py measure --plugin-root plugins/<p> --superpowers-base "<경로>"`(spec-distill 만 superpowers 행이 있다). Expected: 네 파일의 판 칸이 채워짐 — 값은 손으로 고치지 않는다.
- [ ] **Step 5: 커밋** — `feat(devbrew): 플러그인마다 개발 당시 판을 잰 의존 목록`

---

### Task 8: 진입 확인 · 훅의 Python 바닥 (AC19 · AC23a 의 진입)

**Files:**
- Modify: `shared/deps/check_deps.py` (`entry`), 모든 skill 의 진입 단계(spec-distill 여섯 · qg 둘 · project-init · plugin-audit), `shared/deps/check_deps.py` (`measure` 의 `python-hook` 행), `plugins/project-init/dependencies.md`(`python-hook` 행), `shared/python/devbrew-python.sh` 와 그 사본들(머리 주석의 도출 규칙 문장만 — `FLOOR_MAJOR` · `FLOOR_MINOR` 값은 그대로 3.12), `shared/tests/test_python_floor.sh`(축 하나 더 · 축 F 의 `RULE` 리터럴), 루트 `README.md` 의 Python 절, `plugins/project-init/README.md` 의 Python 줄(도출 규칙 문장 — 축 F 가 해석기 · 루트 README 와 함께 이 파일을 잰다)
- Test: `shared/tests/test_check_deps.sh`, `shared/tests/test_entry_dep_needs.sh` (새), `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`(진입 게이트 절에 펜스가 하나 더 든다), `plugins/spec-distill/tests/test_state_dir_writes.sh`(request-framing · reviewing-brief · spec-review 의 진입 펜스 — 쓰기가 없어도 펜스 수 · 루트 변수 대조가 바뀐다), `plugins/spec-distill/tests/test_finishing_block_scope.py`(pm-interview 진입 펜스가 `finishing.md` 를 건드리면), `shared/tests/test_entry_preflight.sh`(감시줄 판독 걸음이 그대로인지)

**Interfaces:**
- Produces: `check_deps.py entry --plugin-root R --need <이름,…>` — 표의 강도대로: `멈춤` 행이 없거나 낮거나 판을 못 뽑으면 stdout `[devbrew-deps] 멈춤 — <이름> <있는 판|없음> · 필요 <최소 판> 이상 · <고치는 법>` · rc 3. 모두 맞으면 `[devbrew-deps] ok — <이름 판 …>` · rc 0. gh 는 판만 본다(인증은 첫 호출).
- 진입 펜스(감시줄 판독 다음 걸음, 한 번의 Bash 호출):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — 멈춘다" >&2; exit 1; }
python3 "$SD/scripts/check_deps.py" entry --plugin-root "$SD" --need python,git
```

  진입별 `--need`: epic-conductor `python,git,gh` · request-framing · reviewing-brief · roadmap-status · pm-interview · spec-review `python,git` · quality-pipeline `python,git,gh` · artifact-critique `python,git` · project-init · plugin-audit `python`. 표: rc 3 이면 그 줄을 보이고 멈춘다.
- 펜스 자리(진입 단계 모양이 셋이다): 번호 걸음이 있는 넷(epic-conductor · pm-interview · request-framing · roadmap-status)은 `### 1. 감시줄 판독` 다음에 `### 1.5 의존 확인` 을 두고 감시줄 표의 ok 줄이 1.5 로 가게 한다(뒤 걸음 번호는 바꾸지 않는다 — spec-review 의 `## 진입 검사`(1.5) 선례). 표만 있는 다섯(spec-review · quality-pipeline · artifact-critique · project-init · plugin-audit)은 감시줄 표 바로 뒤에 같은 펜스를 두고 ok 줄이 그 펜스로 가게 한다(spec-review 는 `## 진입 검사` 앞). reviewing-brief 는 진입 단계가 없다(`user-invocable: false`) — `## 진입 게이트` 의 첫 펜스 앞에 따로 둔다(라운드마다 돈다). 펜스의 루트 변수는 그 파일의 관례를 따른다(reviewing-brief 는 `PR`).
- 훅 바닥 도출 규칙 문장: 축 F 의 `RULE` 리터럴(지금 「2026-10 이후에도 패치를 받는 버전 중 최빈」)을 새 문장의 고정 조각으로 바꾸고, 그 문장을 해석기 정본 · 사본 · 루트 README · project-init README 넷에서 같은 커밋에 바꾼다. 축 F 의 숫자 재도출 · `EOL` 단언은 그대로 둔다.
- 바닥은 경로마다 따로다(U12). skill 진입의 `python` 행 = 측정 때 `python3` 의 판(2026-10-20 실측 `/usr/bin/python3` 3.9.6) — `entry --need python` 이 이것과 비교한다. 훅의 바닥은 `python` 행이 아니라 `python-hook` 행이다.
- `python-hook` 행: 훅이 `devbrew-python.sh` 를 부르는 플러그인(d0d787e8 기준 project-init 하나 — `hooks.json` 에서 센다)의 `dependencies.md` 에만 둔다. `measure` 는 그 플러그인의 `scripts/devbrew-python.sh` 를 `--event measure --plugin <p> --hook measure <임시 탐침.py>` 로 돌려 해석기가 실제로 고른 해석기의 `sys.version_info` 를 적는다(2026-10-20 실측 `~/.local/bin/python3.12` 3.12.13). 강도 `멈춤` · 없을 때 「훅 해석기가 알린다」 — 확인은 `entry` 가 아니라 해석기 자신이 한다(`--need` 목록에 넣지 않는다). 측정이 해석기를 거치므로 값이 지금 바닥 아래로 내려가지 않는다.
- 훅 바닥: `FLOOR_MAJOR.FLOOR_MINOR` 는 그대로 3.12 — `python-hook` 행 앞 두 숫자와 같아야 한다. 머리 주석의 도출 규칙 문장만 「개발 당시 훅이 실제로 쓴 해석기 판(`dependencies.md` 의 `python-hook` 행) — 측정 명령이 잰다」로 바꾼다. 훅 바닥을 skill 의 `python3` 판(3.9)으로 내리지 않는다.

- [ ] **Step 1: 실패하는 테스트.** `test_entry_dep_needs.sh`: 진입마다 `--need` 목록이 위 표와 같다(gh 는 epic-conductor · quality-pipeline 에만 — AC23a 의 진입 쪽, 양 · 음 짝) · 모든 skill 진입에 의존 확인 펜스가 있다. `test_check_deps.sh`: 가짜 `git`(판 `2.0.0`) → rc 3 · 「필요 … 이상」 · 판 못 뽑는 가짜 → rc 3 · gh 없음은 `--need` 에 gh 가 있을 때만 rc 3. `test_check_deps.sh`(이어서): 가짜 `devbrew-python.sh`(탐침을 3.12.13 판 해석기로 exec)를 둔 임시 플러그인 루트에서 `measure` 가 `python-hook` 행을 `3.12.13` 으로, `python` 행을 측정한 `python3` 판으로 따로 쓴다(두 행이 같은 값을 쓰면 실패 — 양 · 음 짝) · `entry --need python` 은 `python-hook` 행을 보지 않는다. `test_python_floor.sh`: 축 하나 더 — 해석기 `FLOOR_MAJOR.FLOOR_MINOR` == `python-hook` 행을 가진 모든 `dependencies.md` 의 그 행 앞 두 숫자(지금 3.12). 「3.9 를 건너뛴다」 음성(`python3.9`)과 `python3.99` 양성 픽스처는 고치지 않는다.
- [ ] **Step 2: 실패를 본다.** Run: `bash shared/tests/test_entry_dep_needs.sh; bash shared/tests/test_check_deps.sh; bash shared/tests/test_python_floor.sh` — Expected: `✗`.
- [ ] **Step 3: 구현 · 사본 동기화.** `devbrew-python.sh` 사본은 copy-of 계약(`shared/tests/test_copy_of_contract.sh`)대로 같이 고친다.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `bash shared/tests/test_copy_of_contract.sh && bash shared/tests/test_invocation_surface.sh && bash shared/tests/test_entry_preflight.sh && bash plugins/spec-distill/tests/test_state_dir_writes.sh && bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh && python3 -m unittest plugins/spec-distill/tests/test_finishing_block_scope.py` — Expected: `✗` 0 · OK.
- [ ] **Step 5: 커밋** — `feat(devbrew): 진입마다 쓰는 의존의 판을 확인하고 훅 바닥을 훅 해석기의 실측 판으로 기록한다`

---

### Task 9: superpowers 판 알림 · 부재 시 멈춤 · qg 부재 알림 (AC22 · AC23 · K11)

**Files:**
- Modify: `shared/deps/check_deps.py` (`superpowers`), `skills/pm-interview/references/finishing.md` (superpowers 로 넘기는 자리 직전), `skills/epic-conductor/SKILL.md` (진입 단계 — superpowers 없음은 멈춤 · 판 알림), `references/conducting.md` (걸음 7 의 qg 없음 문장 · 손 절차 머리), `plugins/spec-distill/README.md` Prerequisites
- Test: `shared/tests/test_check_deps.sh`, `plugins/spec-distill/tests/test_superpowers_presence.sh` (새), `plugins/spec-distill/tests/test_finishing_block_scope.py`(finishing.md 의 판 확인 펜스 — 앞 펜스의 변수를 쓰지 않는다)

**Interfaces:**
- Produces: `check_deps.py superpowers --plugin-root R --base "<불러온 skill 의 기준 폴더 경로>"` — 늘 rc 0. 같으면 `[devbrew-deps] superpowers <판> — 검증한 판과 같다`; 다르면 `[devbrew-deps] 알림 — 설치된 superpowers <판> 이 검증한 판 <판> 과 다르다. 넘김 결과는 돌아온 뒤 대조한다`; 경로에서 판을 못 읽으면 `[devbrew-deps] superpowers 판을 확인하지 못했다`.
- 문면: 인터뷰 — superpowers 가 없으면 지금처럼 brief 까지 만들고 크게 알린 뒤 멈춘다(B-1 그대로). 지휘자 진입 — skill 목록에 superpowers 가 없으면 「superpowers 가 필요하다 — Claude Code 의 /plugin 에서 superpowers 를 설치한 뒤 다시 부른다」를 보이고 멈춘다. 걸음 7 — 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 진행한다.

- [ ] **Step 1: 실패하는 테스트.** `test_check_deps.sh`: 경로 `…/superpowers/7.0.0/skills/writing-plans` · 표 7.0.0 → 「같다」 · 6.4.1 → 「다르다」 · 빈 값 · 판 없는 경로 → 「확인하지 못했다」 · 셋 다 rc 0. `test_superpowers_presence.sh`: 지휘자 진입에 멈춤 문장 · 인터뷰 끝에 판 확인 펜스 · 인터뷰의 superpowers 없음 갈래(B-1 — brief 까지 만들고 크게 알린 뒤 멈춤)가 그대로 있다 · 걸음 7 에 qg 없음 문장 · spec-distill `plugin.json` 에 `dependencies` 키가 없다(음) — 양의 짝: `dependencies.md` 에 superpowers 행이 있다(AC23).
- [ ] **Step 2: 실패를 본다.** Run: `bash shared/tests/test_check_deps.sh; bash plugins/spec-distill/tests/test_superpowers_presence.sh` — Expected: `✗`.
- [ ] **Step 3: 구현 · 통과.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_finishing_block_scope.py` — Expected: `✗` 0 · OK.
- [ ] **Step 4: 실측(설계 Verification Plan).** 격리 설치(`CLAUDE_CONFIG_DIR=<빈 tmp>` — 먼저 빈 폴더로 격리를 증명)에서 superpowers 를 깔지 않고, plugin.json 에 `dependencies` 를 단 spec-distill 사본이 꺼지는지 한 번 재고 결과를 PR 본문에 적는다(쓰지 않는 근거). 하니스 제약으로 못 재면 그 사실을 적는다.
- [ ] **Step 5: 커밋** — `feat(spec-distill): superpowers 판을 알리고 없으면 지휘자 흐름은 진입에서 멈춘다`

---

### Task 10: project-init 훅 — Bash · EnterWorktree 뒤 새 브랜치 관찰 (AC13 · RC82)

**Files:**
- Modify: `plugins/project-init/hooks/hooks.json` (matcher `Bash|EnterWorktree`), `plugins/project-init/hooks/post-tool-use.py` (`BRANCH_CREATE_RE` · `validate_branch` 를 관찰로 · 규칙 파일을 기본 브랜치 판에서), `plugins/project-init/README.md` (Hooks Installed · 「`branch_prefix` 와 맞춘다」 한 줄), `plugins/project-init/tests/test_no_write_matcher_hooks.sh`(양성 대조가 matcher `== "Bash"` 를 요구한다 — 「`Bash` 가 matcher 의 `|` 조각 중 하나」로. 쓰기 도구 음의 축은 그대로), `plugins/project-init/tests/test_post_tool_use.py` · `tests/test_branch_prefix_templates.py`(둘 다 `validate_branch(<명령 문자열>)` · 인자 없는 `get_branch_pattern()` 과 `CLAUDE_PROJECT_DIR` 작업 트리의 규칙 파일로 잰다 — 픽스처를 규칙 파일을 기본 브랜치(`origin/HEAD`)에 커밋한 임시 레포로, 이름 판정은 이름을 받는 함수로 옮긴다. fail-open 다섯 사례(파일 없음 · regex 블록 없음 · 깨진 regex · 빈 블록 · 비 UTF-8)는 기본 ref 판에서 그대로 재고 「기본 ref 없음」 사례를 더한다)
- Test: `plugins/project-init/tests/test_post_tool_use_branch.sh` (새 — 임시 레포 + 훅 입력 JSON), `tests/test_post_tool_use.py`, `tests/test_branch_prefix_templates.py`, `tests/test_no_write_matcher_hooks.sh`

**Interfaces:**
- Produces:
  - `new_branches(cwd: str, now: float, window: float = 60.0) -> list[str]` — 공용 git 디렉토리(`git rev-parse --git-common-dir`)의 `logs/refs/heads/**` 를 읽어 「설계와 다른 점 11」의 규칙. reflog 가 없으면 빈 목록.
  - `get_branch_pattern(cwd)` — `git show refs/remotes/origin/HEAD:docs/git-workflow/branch-strategy.md` 에서 ```` ```regex ```` 블록. 기본 ref 가 없거나 못 읽으면 지금의 fail-open 안내(「규칙을 찾지 못했다 — 검사를 건너뛴다」).
  - `main()` 은 kill switch → `tool_name` 이 `Bash` 이면 커밋 검사(지금 그대로) + 관찰, `EnterWorktree` 면 관찰만. 규칙 밖 이름마다 지금 메시지 꼴(사람 채널 + 모델 채널의 `git branch -m <접두>/<이름>`).

- [ ] **Step 1: 실측 둘.** (a) EnterWorktree 뒤에 PostToolUse 훅이 실제로 불리는가 — 격리 설치(`CLAUDE_CONFIG_DIR=<빈 tmp>`, 쓰기 전 빈 폴더로 격리 증명)에 이 플러그인 사본을 깔고 훅이 받은 입력을 파일로 적게 한 뒤 EnterWorktree 를 한 번 부른다. (b) `git worktree add -b x` · `git branch -m a b` · `git checkout -B c` · `git switch --create d` · `git -C <dir> branch e` · EnterWorktree(`worktree-<이름>`) 뒤 reflog 마지막 줄의 문면과 시각을 표로 적는다. Expected: 표를 이 계획에 붙이고 「설계와 다른 점 11」의 규칙을 확정하거나 고친다. (a) 가 「불리지 않음」이면 README Hooks Installed 에 「EnterWorktree 로 만든 브랜치는 검사 밖」을 적고, 설계문서 §10 의 RC82 답을 「부분」으로 고친 뒤 그 사실을 설계문서 `## 지휘 기록` 에 한 줄로 남긴다.

  **실측 결과 (2026-10-22, git 2.54.0 Apple Git-157, Claude Code 2.1.303).**
  (a) 실측 못 함 — 빈 `CLAUDE_CONFIG_DIR` 의 `claude auth status` 가 `"loggedIn": false` 이고 로그인은 대화형이다(진짜 설정은 건드리지 않았다). Claude Code 훅 문서는 「`PreToolUse` · `PostToolUse` 는 에이전트 루프 안의 모든 도구 호출에서 불린다(`EndConversation` 만 예외)」고 적는다 — 문서 근거, 실측 아님. 그래서 matcher 는 `Bash|EnterWorktree` 로 두고 README 에 공시하고 설계 §10 RC82 답을 「부분 — EnterWorktree 뒤 훅 호출은 실측 못 함」으로 고쳤다.
  (b) 임시 레포(job tmp)에서 각 명령 직후 `logs/refs/heads/<b>` 의 마지막 줄 — 시각은 모두 명령을 돌린 그 초(`1792636950 +0900`, 실행 시각과 같음):

  | 명령 | 브랜치 | 마지막 줄 문면 |
  |---|---|---|
  | `git worktree add -b x <dir>` | `x` | `branch: Created from HEAD` |
  | `git branch -m a b` | `b` | `Branch: renamed refs/heads/a to refs/heads/b` (옛 `a` reflog 파일은 사라짐) |
  | `git checkout -B c` | `c` | `branch: Created from HEAD` (기존 `c` 를 다시 `-B` 해도 같은 줄) |
  | `git switch --create d` | `d` | `branch: Created from HEAD` |
  | `git -C <dir> branch e` | `e` | `branch: Created from d` (`Created from <그때 HEAD 브랜치>`) |
  | `git checkout -b f` · `git switch -c g` | `f` · `g` | `branch: Created from HEAD` |
  | `git branch -c b bcopy` | `bcopy` | `Branch: copied refs/heads/b to refs/heads/bcopy` |
  | `git branch -M bcopy bmoved` | `bmoved` | `Branch: renamed refs/heads/bcopy to refs/heads/bmoved` |
  | 연결 작업 트리 안 `git branch from-wt` | `from-wt` | `branch: Created from x` — 공용 git 디렉토리(`<repo>/.git`)에 쓰인다 |
  | 만든 뒤 커밋 | `d` | `commit: z` — 새 브랜치로 보지 않는다 |
  | `git update-ref refs/heads/raw HEAD` | `raw` | 메시지 없음(탭 없음) — 새 브랜치로 보지 않는다 |
  | EnterWorktree(`worktree-<이름>`) | — | 실측 못 함. 추론: EnterWorktree 는 `git worktree add -b worktree-<이름> <dir> <base>` 꼴이라 첫 행과 같은 `branch: Created from …` 줄을 남긴다(`git worktree add -b worktree-name <dir> HEAD` 로 잰 결과가 `branch: Created from HEAD`) |

  `git pack-refs --all` 뒤에도 `logs/refs/heads/<b>` 파일은 남는다. 이 결과로 「설계와 다른 점 11」을 고쳤다(`checkout: …` 줄은 브랜치 reflog 에 없음 · 복사 추가).
- [ ] **Step 2: 실패하는 테스트.** `test_post_tool_use_branch.sh`: 위 다섯 명령 각각 뒤 규칙 밖 이름 → 알림(AC13 의 `worktree add -b` · `branch -m`) · EnterWorktree 입력(`tool_name: EnterWorktree`) 뒤 `worktree-x` → 알림 · 규칙 안 이름 → 조용 · 61초 전에 만든 규칙 밖 옛 브랜치 → 다시 알리지 않음(시각은 reflog 줄을 고쳐 만든다) · 작업 브랜치에서 규칙 파일을 느슨하게 고쳐도 기본 브랜치 규칙으로 판정 · `DEVBREW_PROJECT_INIT_DISABLE=1` · `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` · `project-init:PostToolUse` 셋 다 출력 `{}` · `hooks.json` matcher 가 `Bash|EnterWorktree`.
- [ ] **Step 3: 실패를 본다.** Run: `bash plugins/project-init/tests/test_post_tool_use_branch.sh` — Expected: `✗`.
- [ ] **Step 4: 구현 · 통과.** 같은 명령 + `python3 -m unittest plugins/project-init/tests/test_post_tool_use.py plugins/project-init/tests/test_branch_prefix_templates.py` + `bash plugins/project-init/tests/test_no_write_matcher_hooks.sh`(쓰기 · 고치기 matcher 금지 락 — 새 matcher 가 걸리지 않고 양성 대조가 `Bash` 조각을 찾는지) — Expected: `✗` 0 · OK.
- [ ] **Step 5: 변이**: 60초 창을 지움 → 옛 브랜치 사례 RED · 규칙 파일을 작업 트리에서 읽게 → 기본 브랜치 규칙 사례 RED · kill switch 확인을 관찰 뒤로 옮김 → kill switch 사례 RED.
- [ ] **Step 6: 커밋** — `fix(project-init): 브랜치 이름 검사를 실행 뒤 관찰로 — EnterWorktree 포함`

---

### Task 11: 회귀 픽스처 · 문서 · 버전 · 스위트 대조 (AC28 · AC29 의 계획 2 몫)

**Files:**
- Modify: 네 플러그인의 `README.md` (Prerequisites 가 `dependencies.md` 를 가리킴 · gh 필수 · 지원 범위 「origin 이 GitHub 인 레포」 · superpowers 부재 동작 · Principles Instantiated 한 줄), `CHANGELOG.md`, `.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_workspace_invariance.sh` (계획 1 의 파일 — fork 사례를 더함)

- [ ] **Step 1: AC29 의 계획 2 몫을 계획 1 의 픽스처 파일에 더한다.** upstream 원격이 있는 fork 클론에서 지휘자 `pr-refresh` 가 가짜 gh 에 `-R <origin>` 을 넘기고 상태 계산이 origin 의 PR 만으로 판정한다 · `-suffix` 판 문자열(`2.45.0-rc1`)의 진입 확인. Run: `bash plugins/spec-distill/tests/test_workspace_invariance.sh` — Expected: `✗` 0.
- [ ] **Step 2: README · CHANGELOG · 판.** 네 플러그인 판 올림(번호는 지휘자가 구현 dispatch 때 준 것). spec-distill CHANGELOG — Added(`gh_repo.py` · `pr-refresh` · 쓴 판 도장 · 의존 목록) · Changed(gh 필수 — 「gh 가 없으면 지휘자 · 머지 판정이 이제 멈춘다」 · squash · rebase 자동 판정 · 상태줄은 gh 를 부르지 않는다 · 옛 판이 쓴 4칸 PR 캐시 줄은 읽지 않고 멈춘다 — 갱신 뒤 지휘자가 `ledger pr-refresh --roadmap <로드맵> --session <세션> --reset` 을 한 번 돈다) · Removed(gh 없을 때의 강등 길). qg — Changed(sink 의 `failed: gh-unavailable` · `-R`). project-init — Changed(matcher · 관찰). plugin-audit — Added(의존 목록). Run: `bash shared/tests/test_changelog_integrity.sh` — Expected: GREEN.
- [ ] **Step 3: 로드맵 R8 블록 문장은 지휘자에게 넘긴다.** 로드맵 수정은 이 PR 이 아니라 지휘자의 로드맵 수정 PR(`references/redecompose.md`)이 한다 — 고칠 의도 · 범위 문장(U1 gh 필수 · U6 superpowers 부재 · U9 GitHub 레포만)을 PR 본문 `## 지휘자에게` 절에 적는다.
- [ ] **Step 4: 전체 스위트 대조.** `baseline.sh` 로 `after` — Expected: 새 실패 0(있으면 고치거나 이유).
- [ ] **Step 5: 커밋** — `docs(devbrew): gh 필수 · 의존 목록 · 판 올림`
- [ ] **Step 6: 마지막 전체 리뷰에 AC 를 싣는다.** 고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC13~AC23 · AC23a · AC28 · AC29) 목록을 싣고 AC 마다 `AC13: 구현됨 — <근거>` 꼴(구현됨 · 미룸 · 빠짐)로 보고하게 한다. 보고를 `$HOME/.claude/sdd-mirror/r8-plan2/ac-report.md`(git 이 추적하지 않음)에 적고, 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 올린 뒤 PR 전에 `python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-dependency-portability-design.md "$HOME/.claude/sdd-mirror/r8-plan2/ac-report.md" --acs "AC13~AC23 · AC28 · AC29"` 의 경고를 사용자에게 보인다.
