# R8 계획 1 — 값 해결자 · 폴더 · 기본 브랜치 · 상태 폴더 · 작업공간 불변 Implementation Plan

**실행 방식:** Subagent-driven — 사용자 선택 「Subagent-driven (권장)」(2026-10-20)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **시작 조건 — 구현은 R10 · R12 · R13 이 모두 기본 브랜치에 머지된 뒤 시작한다(사용자 결정 U10).** 구현 담당은 먼저 `origin/<기본 브랜치>` 를 이 브랜치에 merge 하고, 이 계획이 인용한 파일 · 함수 · 절을 하나도 빠짐없이 새로 읽어 확인한다(Task 0). 이 계획은 설계 승인(60e21baa) 때 쓰고, R10 · R12(계획 셋) · R13 · 지휘자 수리 3(#245)이 머지된 main(6bd168d1)을 이 브랜치에 합친 트리(d0d787e8)에 맞춰 고쳤다 — 그 사이 `skills/spec-interview` 가 `skills/pm-interview` 로 옮겨졌고, 세 skill 폴더(request-framing · reviewing-brief · spec-review) 펜스의 상태 폴더 쓰기가 `nofollow_write.py` 를 지나며(R13), 원장 펜스가 문서가 사는 레포의 상태 루트를 `state_path.py state-root-for <문서>` 로 얻고(R13), 스위트 대조와 통합 리뷰 묶음이 브랜치 끝을 `branch_tip.py` 하나로 고른다(#245). 파일은 줄 번호가 아니라 절 · 함수 이름으로 가리킨다.

**Goal:** 레포마다 다른 값(폴더 · 테스트 명령 · 브랜치 접두 등)을 `repo_defaults.py` 하나가 출처와 함께 내고, 기본 브랜치는 `origin/HEAD` 하나에서 전체 참조 이름으로 얻으며, 정확성이 걸린 자리(커밋 범위 · 기본 브랜치)는 값이 오류 없이 틀어질 때 멈추고, 상태 폴더가 devbrew 밖 레포에서도 추적되지 않게 한다.

**Architecture:** `repo_defaults.py` 에 엄격한 frontmatter 판독 · 닫힌 키 집합 · 층 넷(로드맵 · `.devbrew.md`@기본 ref · 기계 상태(임시) · 상수) 합치기 · CLI(`get` · `check-path` · `roadmap-check` · `default-branch`)를 더한다. 로드맵 찾기는 `roadmap_model.py` 의 판정 함수 하나를 상태줄 · 로드맵 목록 · 끝내기 펜스가 함께 쓴다. 셸 펜스는 값을 조립하지 않고 판정 명령의 rc 를 받는다. 상태 루트는 처음 만들 때 자기 `.gitignore` 를 두고, bare 레포면 공용 git 디렉토리 안으로 간다.

**Tech Stack:** Python 3(표준 라이브러리), bash 3.2 호환 셸 펜스, 레포 셸 테스트 하네스(`shared/tests/assert.sh`), `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-10-20-dependency-portability-design.md` (§1 · §2 · §3 의 RC82 를 뺀 불릿 · §6 · §9 · AC1~AC12 · AC23b · AC24 · AC27 · AC28 · AC29 의 계획 1 몫)

## 목차

- [Global Constraints](#global-constraints)
- [설계와 다른 점 · 설계에 없던 결정](#설계와-다른-점--설계에-없던-결정)
- [Review Focus](#review-focus)
- [넘김 대조 — 앞선 머지가 R8 에 넘긴 것](#넘김-대조--앞선-머지가-r8-에-넘긴-것)
- [Task 0: 머지 뒤 다시 읽기 · 기준선 · 실측 하나](#task-0-머지-뒤-다시-읽기--기준선--실측-하나)
- [Task 1: 해결자 — 엄격한 머리말 · 닫힌 키 · 층 넷 합치기 (AC1 의 합치기 · AC2 · AC5 의 층 · AC23b)](#task-1-해결자--엄격한-머리말--닫힌-키--층-넷-합치기-ac1-의-합치기--ac2--ac5-의-층--ac23b)
- [Task 2: 해결자 — 기본 브랜치 판의 설정 파일 · resolve · CLI get · check-path (AC1 · AC3 · AC4 의 명령)](#task-2-해결자--기본-브랜치-판의-설정-파일--resolve--cli-get--check-path-ac1--ac3--ac4-의-명령)
- [Task 3: 기본 브랜치 — 전체 참조 이름 · 고치는 법 · 원격 대조 (AC9 의 spec-distill 몫 · AC10 · AC11)](#task-3-기본-브랜치--전체-참조-이름--고치는-법--원격-대조-ac9-의-spec-distill-몫--ac10--ac11)
- [Task 4: 흡수 — 상태 계산 · 상태줄 · 스위트 대조가 해결자를 지난다 (AC1 의 소비자 · AC5)](#task-4-흡수--상태-계산--상태줄--스위트-대조가-해결자를-지난다-ac1-의-소비자--ac5)
- [Task 5: 로드맵 찾기 하나 (AC6)](#task-5-로드맵-찾기-하나-ac6)
- [Task 6: 박힌 값 — 인터뷰 · 설계문서 폴더 · 브랜치 접두 (AC8 · AC12 · §2 의 인터뷰 폴더 · spec-review 후보)](#task-6-박힌-값--인터뷰--설계문서-폴더--브랜치-접두-ac8--ac12--2-의-인터뷰-폴더--spec-review-후보)
- [Task 7: 끝내기 커밋 펜스 · request-framing 의 기본 브랜치 (AC7 · AC9 · AC10 · AC11 의 펜스 몫)](#task-7-끝내기-커밋-펜스--request-framing-의-기본-브랜치-ac7--ac9--ac10--ac11-의-펜스-몫)
- [Task 8: qg · 공유 기준선 — main/master 대체 지움 · 사유와 안내 (AC9 의 qg 몫)](#task-8-qg--공유-기준선--mainmaster-대체-지움--사유와-안내-ac9-의-qg-몫)
- [Task 9: 상태 루트 — 자기 무시 · 추적 파일이면 멈춤 · bare 레포 · 환경 변수 공시 (AC24 · §6)](#task-9-상태-루트--자기-무시--추적-파일이면-멈춤--bare-레포--환경-변수-공시-ac24--6)
- [Task 10: 작업공간 불변 락 · 읽은 트리 · 회귀 픽스처 (AC27 · AC29 의 계획 1 몫 · §9)](#task-10-작업공간-불변-락--읽은-트리--회귀-픽스처-ac27--ac29-의-계획-1-몫--9)
- [Task 11: 문서 · 버전 · 스위트 대조 (AC28 마감)](#task-11-문서--버전--스위트-대조-ac28-마감)

## Global Constraints

- **시작 시점.** R10 · R12 · R13 머지 뒤(U10). 브랜치 `feature/dependency-portability`. 시작 때 기본 브랜치를 merge 한다(rebase 금지). 커밋은 pathspec(`git commit -- <경로…>`), `git stash` 금지. HEAD 를 뒤로 옮기지 않는다.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 판 번호는 이 계획에 적지 않는다 — 지휘자가 구현 dispatch 때 정해 준다(spec-distill · quality-gates 를 올린다). CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- **세 skill 폴더 펜스의 상태 폴더 쓰기는 `nofollow_write.py` 로.** request-framing · reviewing-brief · spec-review 의 `.md` 펜스에서 상태 폴더에 쓰는 줄(`>` · `>>` · `tee` · `touch`)은 `"$<루트>/scripts/nofollow_write.py" run|empty|append --out …` 를 지나고, writer 를 부르는 루트 변수는 그 펜스가 다른 스크립트(`repo_defaults.py` 포함)를 부르는 루트 변수와 같다. 집행은 `plugins/spec-distill/tests/test_state_dir_writes.sh` 의 도출 락(`scan_writes`) — 그 폴더의 펜스를 고치는 과제는 이 테스트를 Test 목록에 둔다.
- **펜스 사이 변수 나르기 금지.** 한 bash 펜스는 앞 펜스에서만 정의된 변수를 쓰지 않는다(Bash 호출마다 새 셸). `finishing.md` 와 `references/redecompose.md` 둘 다 `plugins/spec-distill/tests/test_finishing_block_scope.py`(`test_redecompose_fences_same_rule` 포함)가 잰다 — 두 파일의 펜스를 더하거나 고치는 과제는 이 테스트를 Test 목록에 둔다.
- 호환 코드 · 옛 판 대체 길을 만들지 않는다(U2). gh 를 이 계획에서 새로 부르지 않는다(gh 는 계획 2).
- 지원 흐름은 내 레포 안 흐름이다 — PR · 기본 브랜치는 언제나 `origin`(U8). 원격 이름 설정 키를 두지 않는다.
- 설정 키는 닫힌 집합이다: `specs_dir` · `plans_dir` · `roadmaps_dir` · `interview_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default` · `branch_prefix`. 로드맵 층이 받는 키: `type` · `source_brief` · `specs_dir` · `plans_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default`. 기계 상태 층이 받는 키: `test_command` · `test_failure_pattern`.
- 출처 표기는 글자 그대로 `로드맵` · `레포 설정@<커밋 8자>` · `기계 상태(임시)` · `기본값` · `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)`.
- 레포 전용 값(경로 · 브랜치 이름 · 접두 · 모델)은 `repo_defaults.py` 의 상수에만 글자로 둔다. 다른 파일은 해결자를 부른다. 상수가 아닌 이름(`roadmap_model` 등)을 `repo_defaults` 이름공간에 대문자로 끌어오지 않는다(`test_repo_literals.sh` 의 허용 목록이 `vars(R)` 의 대문자 문자열에서 도출된다 — `import roadmap_model as _rm` 꼴로).
- 셸 펜스는 macOS bash 3.2 · zsh 에서 돈다: `$var` 바로 뒤 한글은 `${var}`, `$( )` 안 heredoc 금지, 배열 첨자 대입 · 맞는 파일 없는 글롭 금지. 펜스는 값이 아니라 판정 rc 를 받고, 값을 받으면 rc 와 빈 값을 확인한다.
- 스크립트 파일 읽기는 `encoding="utf-8"`. 플러그인 `.py` 에 `"python3"` 리터럴 금지(`sys.executable`). 인라인 python 은 `python3 -I`. 새 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 `100755`.
- 사람에게 보이는 새 문면(안내 · 실패 메시지 · README · CHANGELOG)은 `shared/style/plain-language.md` — 첫 줄에 상태, 번호 · 해시는 내용 뒤 괄호, 끝에 할 일 하나. 모델이 읽는 새 문면(skill · reference)에는 출처 · 배경 · 정당화를 쓰지 않는다.
- 락은 변이로 이빨을 확인한다(표기 · 값 · 위치 · 부정문 네 축 + 추가 · 반전). 음의 락에는 양의 짝. 변이 전에 커밋하고 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 로 확인. `PYTHONDONTWRITEBYTECODE=1`.
- 임시 레포 픽스처는 `mktemp -d` 결과가 비었거나 폴더가 아니면 바로 끝낸다(`cd ""` 사고). macOS `/tmp` → `/private/tmp` 를 경로 비교 전에 `pwd -P` 로 맞춘다.

## 설계와 다른 점 · 설계에 없던 결정

1. **레포 설정 파일 이름은 설계의 잠정 이름 `.devbrew.md` 그대로다** — 레포 루트, frontmatter 만 읽는다.
2. **CLI 종료 코드.** `get <키>`: 0 값 있음(stdout 한 줄) · 1 값 없음(기본값이 없는 키 — `test_command` 등, stdout 빈 줄 없음) · 2 사용법 · 3 설정이 깨짐(모르는 키 · 같은 키 둘 · 못 읽는 머리말 · 층 위반 · 일반 파일 아님 · LFS). `check-path` · `roadmap-check`: 0 통과 · 3 거부(사유 한 줄). `default-branch`: 0 짧은 이름 · 3 기본 브랜치 없음(고치는 법 안내) · 5 원격과 다름. 출처 · 알림은 stderr 한 줄씩 `[spec-distill] …`.
3. **`check-path <키> <경로>` 의 뜻은 「경로의 부모 폴더가 그 키의 폴더와 글자까지 같다」 하나다.** 대소문자만 다르거나, 디스크에 있는 경로 성분의 실제 이름이 대소문자만 다르면 rc 3 「대소문자만 다른 경로」. 로드맵 폴더(부모 = `roadmaps_dir`) · 인터뷰 파일(부모 = `interview_dir`)이 같은 명령을 쓴다.
4. **기본 브랜치 도출 · 대조는 `repo_defaults.py` 의 `default_branch()` · `check_remote_head()` 와 CLI `default-branch [--check-remote]` 가 맡는다.** `DEFAULT_REF` · `NO_DEFAULT` 정의는 `roadmap_model.py` 하나로 남고(`test_roadmap_approval.py` `OneDefaultRef` 에 `repo_defaults` 를 더한다), 원격이 없을 때의 안내 `NO_ORIGIN` 을 그 옆에 더한다.
5. **원격 대조의 시간 상한은 10초**(`git ls-remote --symref origin HEAD`, `GIT_TERMINAL_PROMPT=0`). 네트워크 진입 셋은 지휘자 진입 단계(표지 잡기 뒤) · `merge_check run`(fetch 뒤) · 인터뷰 끝 커밋 펜스(커밋 직전)다.
6. **로드맵의 모양은 `<roadmaps_dir><폴더>/<파일>.md` (한 단계 아래) ∧ frontmatter `type: roadmap`.** 파일 이름 `roadmap.md` 는 더 요구하지 않는다(지금 `control_plane.ROADMAP_RE` 만 요구했다). 기계 상태 폴더가 로드맵의 부모 폴더 이름을 쓰므로 한 단계가 필요하다.
7. **bare 판정은 git 을 부르지 않는 규칙이다**: 공용 git 디렉토리의 이름이 `.git` 이면 지금처럼 그 부모, 아니면 그 안(`<공용 git 디렉토리>/.claude/spec-distill`). `state_root_for_common` 은 순수 함수로 남는다. devbrew 처럼 평범한 레포는 경로가 바뀌지 않는다.
8. **상태 루트 쓰기 보장은 `state_path.ensure_state_root(root)` 하나**를 상태 루트 아래에 폴더를 만드는 모든 자리가 부르고, skill 펜스는 CLI 플래그 `--ensure` 로 부른다 — `state-root [<cwd>] [--ensure]` · `state-root-for <DOC> [--ensure]` 둘 다. 지금 두 하위 명령은 `argv[2]` 만 읽고 남는 인자를 조용히 버린다(`state-root --ensure` 는 `--ensure` 를 cwd 로 읽는다) — 인자를 옵션으로 읽고 모르는 인자 · 남는 인자는 rc 2 로 거부한다. `--ensure` 가 멈추면(추적 파일 등) rc 3 · stdout 비움 · stderr 에 고치는 법. `--ensure` 를 붙이는 펜스는 문서별 상태 폴더를 처음 만드는 자리(절차서 선결의 `mkdir -p <state-dir>` 를 도는 펜스)이고, 그 펜스는 `|| true` 로 rc 를 삼키지 않는다. 읽기만 하는 자리(상태줄 · 상태 보기 · 펜스의 경로 도출만 하는 호출)는 플래그 없이 부른다.
9. **project-init README 의 「`branch_prefix` 와 브랜치 규칙을 맞춘다」 한 줄은 계획 2 에 둔다** — project-init 은 계획 2(RC82)가 고치고 판을 올린다. 이 계획은 spec-distill README 쪽 한 줄만 쓴다.
10. **해결자 CLI 는 `--root <레포>` 를 받는다(없으면 cwd).** R13 뒤 원장 · 끝내기 펜스는 cwd 가 아니라 문서가 사는 레포(`git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel` 의 `top`)를 기준으로 돈다. 그 펜스의 `get` · `check-path` · `roadmap-check` · `default-branch` 는 `--root "$top"` 으로 부른다 — 문서와 다른 레포의 설정으로 커밋 범위를 정하지 않게.
11. **충돌 미리 보기 · 스위트 대조의 브랜치 끝은 `branch_tip.py` 가 이미 고른다(#245)** — 로컬과 원격 중 앞선 쪽을 쓰고 갈라지면 멈춘다. 설계 §9 의 「로컬과 원격이 다르면 둘 다 보인다」는 그 알림 줄에 두 끝(8자)을 함께 싣는 것으로 채운다(Task 10). 상태 계산(`roadmap_status`)의 끝 순서(로컬 먼저)는 설계 §4 대로 계획 2 가 다룬다 — `branch_tip.tip` 의 「앞선 쪽」 규칙을 상태 계산에 들이지 않는다.

## Review Focus

1. **설정 파일이 없는 새 레포에서 인터뷰를 처음 연다(오프라인, `origin/HEAD` 없음).** 사람은 인터뷰가 막히지 않고 기본 폴더로 가며, 한 줄로 「기본 브랜치 없음 — 설정 파일을 읽지 못해 기본값을 썼다」를 보길 기대한다. 커밋 직전에야 기본 브랜치가 필요해 멈춘다. Task 2 의 `test_no_default_ref_uses_constants_with_source` 와 Task 7 의 무원격 픽스처가 잠근다.
2. **작업 브랜치에서 `.devbrew.md` 를 처음 더하고(아직 기본 브랜치에 없음) 같은 브랜치에서 인터뷰 끝 커밋을 한다.** 사람은 새 값이 아니라 기본값으로 가고 「아직 기본 브랜치에 없다 — 기본값을 쓴다」를 보길 기대한다(작업 브랜치가 자기 검사 범위를 바꾸지 못한다). Task 2 의 `test_worktree_only_file_notice` 가 잠근다.
3. **값에 `#` 이 든 테스트 명령(`test_command: pytest -k "not slow" # 빠른 것만`).** 사람은 주석이 값에 섞여 다른 명령이 도는 대신 멈추고 「따옴표로 감싸라」를 보길 기대한다. Task 1 의 `test_unquoted_hash_is_error` 가 잠근다.
4. **대소문자를 무시하는 파일시스템에서 brief §7 이 `Docs/Superpowers/roadmaps/…` 로 적혔다.** 사람은 다른 폴더를 커밋하는 대신 멈추길 기대한다. Task 7 의 대소문자 사례가 잠근다(macOS 기본 APFS 에서 실제로 돈다).
5. **GitHub 에서 기본 브랜치를 `main` → `trunk` 로 바꾼 뒤 `git fetch` 만 했다(옛 `origin/HEAD` 남음).** 사람은 지휘자 · merge_check · 인터뷰 끝 커밋이 옛 기본 브랜치 위에서 「기본 브랜치에 직접 커밋하지 않는다」 검사를 통과하지 않고 멈춰 `git remote set-head origin --auto` 를 안내하길 기대한다. 오프라인이면 멈추지 않고 「원격과 대조하지 못했다」. Task 3 의 개명 픽스처가 잠근다.
6. **레포 A 에서 일하며 레포 B 의 brief 로 인터뷰를 끝낸다.** 사람은 끝내기 커밋이 B 의 설정(`roadmaps_dir`)과 B 의 기본 브랜치로 판정하고, 상태 루트 보장도 B 에 하길 기대한다. Task 2 의 `--root` 사례 · Task 9 의 다른 레포 문서 사례가 잠근다.

## 넘김 대조 — 앞선 머지가 R8 에 넘긴 것

| 넘김 | 받는 과제 |
|---|---|
| #243 — qg Step 1c 는 `review-diff: ` 로 시작하는 stderr 줄만 옮긴다(`[resolve-baseline]` 줄은 안 감) | 이 계획 Task 8(review-diff 가 `review-diff: ` 안내 줄을 낸다) |
| #243 — `degraded_reason:` 을 더하면 review-diff stdout 줄 수 계약 · `test_review_diff.sh` 단언도 | 이 계획 Task 8(10 → 11줄) |
| #243 — `.claude/worktrees/` 실측 결론은 새 문구(「이전 qg 실행이 남긴 worktree」 · 「추적 안 되는 중첩 레포」) | 이 계획 Task 0 Step 6 · Task 9 Step 6 |
| #243 — `--optional` 을 묶지 않아 「선택 N」 칸이 낮아질 수 있다 | 설계 U16 — qg README 한계 한 줄(계획 3 Task 2) |
| R12 계획 1 통합 리뷰 — R12 설계 `## 미룸` 의 R8 행 셋 | 설계 U14(둘 — §7 공시로 받음) · U15(정체 추적 — 받지 않음), 계획 3 Task 2 |
| R12 계획 1 통합 리뷰 — 스냅숏 동치 칸에 `item_marks` | 계획 3 Task 1 |
| #245 — `branch_tip.py` 공유(merge_check · review-pack) | 이 계획 Task 0 Step 3 · 「설계에 없던 결정 11」 · Task 10 Step 4, 계획 2 Task 0 · Task 4 |
| R13 — 펜스가 `state-root-for <doc>` 를 부르고 남는 인자를 조용히 버린다 · `--ensure` 인터페이스 · 다른 레포 문서 사례 | 이 계획 「설계에 없던 결정 8」 · Task 9 |
| R13 — `--snapshot` 호출자에 `test_state_dir_writes.sh` 링크 거절 세 사례 · 절차서 `> snap.json` 줄을 되살리지 않는다 | 계획 3 Task 0 Step 4 · Task 1 |
| R13 — `test_decompose_surface.sh` Step A 8 e2e 치환을 해결자 값으로 · 「폴더를 만들지 않는다」에 rc 0 양의 짝 | 이 계획 Task 6 Step 2b |
| R13 — 미룸 두 행(Write 도구 쓰기 링크 · 실행 중 다시 심는 링크/`runner_common.sh` 두 함수) | 설계 U13 — §7 공시로 받음, 계획 3 Task 2 |
| R13 — README 한계 불릿(P21 · P14)을 계획 3 의 `## 한계` 절에 합치고 `test_state_dir_writes.sh` 끝의 README 락을 맞춘다 · R13 설계 `## 미룸` 두 행에 끝냄 | 계획 3 Task 2 |
| R13 — Global Constraints 두 줄(세 skill 폴더 쓰기는 `nofollow_write.py` · 펜스 사이 변수 나르기 금지는 redecompose.md 에도) · Task 6 · 7 · 계획 2 Task 8 의 Test 목록 | 세 계획의 Global Constraints · 이 계획 Task 6 · 7 · 9 · 10 · 계획 2 Task 8 · 9 |

---

### Task 0: 머지 뒤 다시 읽기 · 기준선 · 실측 하나

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r8-plan1/baseline.sh` (레포 밖)
- Modify: 이 계획 파일(자리 고침이 있으면)

- [ ] **Step 1: 시작 조건을 확인한다.** 기본 브랜치 이름은 `git symbolic-ref refs/remotes/origin/HEAD` 로 도출한다. R10(브랜치 셋) · R12 · R13 · 지휘자 수리 3 의 PR 이 모두 MERGED 인지 `gh pr list --state merged --head <브랜치>` 로 본다(d0d787e8 에서 넷 다 머지됨). 하나라도 아니면 멈추고 지휘 세션에 「R8 시작 조건 미충족 — <에픽>」을 보고한다.
- [ ] **Step 2: `git merge --no-edit origin/<기본 브랜치>`.** 충돌이 나면 설계문서 · 계획은 이 브랜치 쪽을 둔다.
- [ ] **Step 3: 인용 자리를 다시 읽고 이 계획을 맞춘다.** 읽을 것:
  - spec-distill 스크립트: `repo_defaults.py` 전체 · `roadmap_model.py` 의 `frontmatter` · `DEFAULT_REF` · `NO_DEFAULT` · `state_path.py` 의 `state_root_for_common` · `state_root` · `INTERVIEW_DIR` · `interview_state_path` · `payload_root` · `main` 의 `state-root` · `state-root-for` 인자 처리 · `branch_tip.py` 전체 · `roadmap_status.py` 의 `Git.default_branch` · `build` · `control_plane.py` 의 `candidates` · `ROADMAP_RE` · `interview_files` · `read_interviews` · `default_ref` · `gather` · `statusline_text` · `save_cache` · `conductor_ledger.py` 의 `c_roadmaps` · `_roadmap_blocks` · `c_review_pack`(충돌 미리 보기 — `branch_tip.tip`) · `c_resource_dir` · `merge_check.py` 의 `branch_tip` · `machine_settings` · `run` · `conductor_state.py` 의 `acquire` · `suite_lock.py` · `interview_state.py` · `ledger_sweep.py` 의 상태 루트 쓰기 자리.
  - skill · reference: `skills/pm-interview/SKILL.md` 의 `## State location` · `skills/pm-interview/references/finishing.md` 의 `### 분해 판단 — Step A 직전`(폴더 안내 · 분해안 표의 브랜치 칸) · `### Step A`(8 의 `BRIEF_REL` · `--out` · `--plan-table` · `--audit`) · Step A.5 의 `PAYLOAD` · 끝내기 커밋 펜스(`<!-- interview-commit:begin -->` 표지 사이) · `#### B-1` 안내 · `skills/request-framing/SKILL.md` 의 `## 워크트리 — 진입 직후`(base 도출 펜스 · 승낙 절차 2 의 `git branch -m` · 3 의 audit · seed 폴더) · `## 상태` 블록(`AUDIT` · `SEED` 도출과 맨 `state-root` 호출) · 끝 안내의 넘김 경로 예시 · `skills/spec-review/SKILL.md` 의 설계문서 후보 펜스(`--diff-filter=A … -- '<specs>*-design.md'` 두 줄) · `skills/reviewing-brief/SKILL.md` · `skills/spec-review/SKILL.md` 의 `state-root-for` 펜스들 · `references/redecompose.md` 의 `## 2. 지금 표` 작업 브랜치 문장과 끝맺음의 브랜치 문장 · `shared/docreview/references/reviewing-document.md` 의 「선결」(`mkdir -p <state-dir>`).
  - qg · 공유: `shared/test-selection/resolve-baseline.sh` · 그 소비자 전부 — `plugins/quality-gates/scripts/check-review-scope.sh` · `review-diff.sh` · `discover-spec.sh` · `resolve-topic.sh`(두 자리) · `shared/test-selection/compute-test-scope-candidates.sh` · `quality-pipeline/references/differential-test.md` 의 기준선 펜스 · `resolve-range.sh` 의 끝 도출 · `quality-pipeline/SKILL.md` Review Step 1c(`review-diff: ` 로 시작하는 stderr 줄만 사용자에게 옮기는 규칙 · `degraded:` 갈래 · 「리뷰하지 않았다」 줄).
  - 락: `tests/test_state_dir_writes.sh`(`scan_writes` · 세 skill 폴더 대상 도출 · writer 루트 변수 대조) · `tests/test_finishing_block_scope.py`(`test_redecompose_fences_same_rule`) · `tests/test_ledger_root.sh`(`root_lock` — RB · SR · finishing 은 문서 변수를 넘기는 `state-root-for` 만, RF 는 `## 상태` 의 맨 `state-root` 하나 · `grep -c 'state_path.py" state-root)'`) · `tests/test_decompose_surface.sh`(커밋 펜스의 `"${top}/docs/superpowers/roadmaps"` 글자 단언 · redecompose 글자 단언 · Step A 8 e2e 의 `e2e_run` 치환 · 「거절되면 폴더를 만들지 않는다」 사례) · `tests/test_conducting_reference.sh` 의 `banned` 목록 · `plugins/quality-gates/tests/test_review_diff.sh` 의 「stdout 10줄」 단언(세 자리) · `plugins/quality-gates/tests/test_resolve_baseline.sh` 의 `case_degraded_emits_all_keys`(키 여섯의 순서를 글자로 단언 — 「6키」).
  이름이 바뀌었으면 이 계획의 이름을 고쳐 쓴다.
- [ ] **Step 4: 박힌 값 자리를 다시 센다.** `git grep -n -e 'docs/superpowers/interview' -e 'docs/superpowers/roadmaps' -e 'docs/superpowers/specs' -e "origin/main" -e "symbolic-ref --short" -e 'feature/' -- plugins/spec-distill/skills plugins/spec-distill/references plugins/spec-distill/scripts plugins/spec-distill/templates ':!*CHANGELOG*'` — 결과를 아래 목록과 대조하고, 더 있으면 Task 6 · 7 의 고칠 목록에 더한다. d0d787e8 에서 센 것:
  - `references/redecompose.md` — `## 2. 지금 표` 의 작업 브랜치 문장(`origin/main` · `feature/roadmap-<요지>`) · 끝맺음의 「2 에서 만든 `feature/roadmap-<요지>` 브랜치」 (Task 6)
  - `scripts/control_plane.py` — `ROADMAP_RE` · `candidates` 의 `ls-tree … docs/superpowers/roadmaps/` (Task 5) · `interview_files` 의 세 폴더 성분 · 파일 경로 접두 · `read_interviews` 의 오류 경로 (Task 6)
  - `scripts/repo_defaults.py` 의 `SPECS_DIR` (상수 — 그대로) · `scripts/roadmap_render.py` 머리 주석의 R0 설계 경로(문서 인용 — 그대로) · `scripts/state_path.py` 의 `interview_state_path` docstring (Task 6)
  - `skills/pm-interview/SKILL.md` — frontmatter `description` 의 인터뷰 폴더 · `## State location` (Task 6)
  - `skills/pm-interview/references/finishing.md` — 분해 판단 5(기록)의 로드맵 폴더 문장 · Step A 의 payload 예시 · `PL=` · `check_brief.py gate` 인자 · Step A 8 의 `BRIEF_REL=` · `--out` · Step A.5 의 `PAYLOAD=` · Step B 의 proceed-gate 경로 문장(`plugins/spec-distill/references/proceed-gate.md` — 위 grep 밖, `test_repo_literals.sh` 스캐너가 잡는다) · B-1 안내 문장 (Task 6) · 끝내기 커밋 펜스 앞 문단과 펜스의 `symbolic-ref --short` · `${def#origin/}` · `"${top}/docs/superpowers/roadmaps"` · `*/roadmap.md` (Task 7)
  - `skills/pm-interview/references/state-file.md` 머리 문장 (Task 6)
  - `skills/request-framing/SKILL.md` — `## 워크트리 — 진입 직후` 의 `feature/<kebab-topic>` 세 자리(빈 요청 문단 · 워크트리 질문 · 승낙 절차 2 의 `git branch -m`) · 승낙 절차 3 의 폴더 · `## 상태` 의 산출물 표 · `AUDIT=` · `SEED=` · 끝 안내의 넘김 경로 두 자리 (Task 6) · `origin/main` 설명 · base 펜스의 `origin/main origin/master` 후보 · 「main/master 둘 다 부재」 문장 (Task 7)
  - `skills/spec-review/SKILL.md` — frontmatter `description` · 설계문서 후보 펜스의 `'docs/superpowers/specs/*-design.md'` 두 줄 (Task 6)
  - 위 grep 밖, Task 6 의 넓힌 `test_repo_literals.sh` 스캐너(「레포 구조 경로」 규칙의 `plugins/spec-distill`)가 더 잡는 줄: `skills/request-framing/SKILL.md` · `skills/spec-review/SKILL.md` 의 처분 앵커 넷(`consumer=plugins/spec-distill/scripts/docreview_route.py` — `shared/tests/test_dispatch_disposition.sh` 축 A④ · A⑤ 가 레포 기준 추적 경로를 요구한다). Task 6 Step 1 이 이 줄 꼴만 스캔에서 뺀다.
- [ ] **Step 5: 기준 스위트.** R2a 계획 1(`docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md` Task 0 Step 1)의 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r8-plan1/baseline.sh` 로 쓰고, 버릴 clone(`git clone --no-local` 로 merge 한 HEAD)에서 `bash … "$HOME/.claude/sdd-mirror/r8-plan1/before"`. Expected: 실패 줄 «이름» 집합 파일 생성. 다른 스위트와 동시에 돌리지 않는다.
- [ ] **Step 6: 실측 — `.claude/worktrees/` 를 무시하지 않는 레포에서 qg(설계 §6 · PR #234 넘김).** 임시 레포(`.gitignore` 없음, 기본 브랜치 `trunk`, 원격은 로컬 bare)에 두 꼴을 두고 `bash plugins/quality-gates/scripts/review-diff.sh --dir <out> --iter 1 --mode session` 을 돈다: (가) 하니스 worktree `git worktree add .claude/worktrees/wt -b feature/wt trunk` (나) 다른 세션의 qg worktree 꼴 `.claude/quality-gates/worktrees/base-abcd1234/`(`git worktree add` 로 등록). Expected: (가)는 「추적 안 되는 중첩 레포」(리뷰하지 않고 막음, `degraded: yes` · `files:` 수) · (나)는 「이전 qg 실행이 남긴 worktree」(stale · `degraded: yes`). stdout 의 `degraded:` 값과 stderr 의 `review-diff: ` 줄을 그대로 Task 9 Step 6 에 적는다. (가)가 막으면 README 의 devbrew 밖 레포 절(Task 11)에 「`.claude/worktrees/` 를 `.gitignore` 에 더하라」로 싣는다.

---

### Task 1: 해결자 — 엄격한 머리말 · 닫힌 키 · 층 넷 합치기 (AC1 의 합치기 · AC2 · AC5 의 층 · AC23b)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`, `plugins/spec-distill/tests/test_repo_literals.sh` (「상수 반복」 판정)
- Test: `plugins/spec-distill/tests/test_repo_defaults.py`, `plugins/spec-distill/tests/test_repo_literals.sh`

**Interfaces:**
- Produces:
  - 상수 `KEYS` (위 아홉, 순서 그대로) · `ROADMAP_LAYER_KEYS` · `ROADMAP_META_KEYS = ("type", "source_brief")` · `MACHINE_LAYER_KEYS = ("test_command", "test_failure_pattern")` · `ROADMAPS_DIR = "docs/superpowers/roadmaps/"` · `INTERVIEW_DIR = "docs/superpowers/interview/"` · `BRANCH_PREFIX = "feature/"` · `SETTINGS_FILE = ".devbrew.md"`
  - `class SettingsError(ValueError)` — 속성 `kind` ∈ `"unreadable"` · `"unknown_key"` · `"duplicate_key"` · `"unquoted_hash"` · `"layer_key"` · `"bad_value"` · `"not_regular_file"` · `"lfs_pointer"`, 속성 `where`(층 이름)
  - `strict_frontmatter(text: str, where: str) -> dict[str, str]` — 머리말이 없으면 `{}`(로드맵 층은 머리말이 늘 있다; 설정 파일은 `"unreadable"`). BOM · 안 닫힘 · `--- ` 뒤 공백 · 같은 키 둘 · 따옴표 없는 값의 ` #` → `SettingsError`. 값은 따옴표를 벗긴 글자.
  - `check_layer(meta: dict, layer: str) -> None` — `layer` ∈ `"roadmap"` · `"repo"` · `"machine"`; 허용 밖 키 → `SettingsError("layer_key" 또는 "unknown_key")`
  - `merge_layers(roadmap: dict | None, repo: dict | None, repo_label: str | None, machine: dict | None, notices: list[str]) -> dict` — 반환 `{"values": {키: 값|None}, "sources": {키: 출처}, "errors": [...], "warnings": [...], "notices": [...]}`. 폴더 키는 기존 `_folder` 규칙 + `.git` 아래 · 루트(`.`) 금지. `parallel_default` 의 「깨지면 기본값 + 경고」 규칙은 그대로.
- `repo_settings(meta)` 는 이 과제에서 지우지 않는다 — `roadmap_status.py` 가 모듈 머리에서 import 하고 `merge_check.run` 이 부르므로, 지우면 Task 2~3 사이 그 둘이 죽는다. Task 4 Step 3 이 호출자를 `resolve` 로 옮긴 뒤 지운다.
- `BRANCH_PREFIX = "feature/"` 를 더하면 `test_repo_literals.sh` 의 「상수 반복」 허용 목록(`vars(R)` 의 `/` 든 대문자 문자열, 판정 `c.rstrip("/") in line`)에 들어가 `feature` 가 부분 문자열로 걸린다 — 기존 음성 대조 「`prefix/feature/x` 는 잡지 않는다」가 RED 가 된다(실측). 이 과제가 그 판정을 고친다(Step 3b).

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_repo_defaults.py` 에 클래스 `StrictFrontmatter` · `Layers` · `Merge`)

```python
def test_bom_is_unreadable(self):
    with self.assertRaises(rd.SettingsError) as c: rd.strict_frontmatter("﻿---\na: b\n---\n", "repo")
    self.assertEqual(c.exception.kind, "unreadable")
def test_unclosed_and_trailing_space_fence_are_unreadable(self): ...   # "---\na: b\n" · "--- \na: b\n---\n" → kind "unreadable"
def test_duplicate_key(self): ...                                       # "---\nspecs_dir: a/\nspecs_dir: b/\n---\n" → "duplicate_key"
def test_unquoted_hash_is_error(self): ...                              # 'test_command: pytest # 빠른 것' → "unquoted_hash"
def test_quoted_hash_is_value(self):
    self.assertEqual(rd.strict_frontmatter('---\ntest_command: "pytest -k \'a#b\' # x"\n---\n', "repo")["test_command"], "pytest -k 'a#b' # x")
def test_missing_key_is_default_not_error(self):
    m = rd.merge_layers(None, {}, "레포 설정@0123abcd", None, [])
    self.assertEqual((m["values"]["interview_dir"], m["sources"]["interview_dir"]), (rd.INTERVIEW_DIR, "기본값"))
def test_typo_key_is_unknown(self): ...                                 # repo 층 {"spec_dir": "x/"} → check_layer kind "unknown_key"
def test_roadmap_layer_rejects_pre_roadmap_keys(self):                  # AC23b
    for k in ("roadmaps_dir", "interview_dir", "branch_prefix"):
        with self.assertRaises(rd.SettingsError) as c: rd.check_layer({k: "x/"}, "roadmap")
        self.assertEqual(c.exception.kind, "layer_key")
def test_roadmap_layer_accepts_meta_and_its_settings(self): ...         # type · source_brief · specs_dir · … 통과
def test_machine_layer_accepts_two_keys_only(self): ...                 # review_model → "layer_key", test_command 통과
def test_priority_roadmap_repo_machine_constant(self):
    m = rd.merge_layers({"test_command": "a"}, {"test_command": "b"}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("a", "로드맵"))
    m = rd.merge_layers({}, {"test_command": "b"}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual(m["sources"]["test_command"], "레포 설정@0123abcd")
    m = rd.merge_layers({}, {}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual(m["sources"]["test_command"], "기계 상태(임시)")
def test_folder_under_git_or_root_is_error(self): ...                   # ".git/x/" · "." · "./" · "/abs/" · "a/../b/" → errors 에 한 줄
```

- [ ] **Step 2: 돌려 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py -v` — Expected: `AttributeError: module 'repo_defaults' has no attribute 'strict_frontmatter'` 류 FAIL.
- [ ] **Step 3: `strict_frontmatter` · `check_layer` · `merge_layers` 를 구현한다.** 판독은 `roadmap_model.frontmatter` 와 같은 줄 규칙(들여쓴 줄 · 목록 줄 · `#` 줄은 건너뜀)에 위 오류만 더한다. ` #` 판정은 따옴표를 벗기기 전 값에서 「따옴표로 시작하지 않고 ` #` 를 품음」.
- [ ] **Step 3b: `test_repo_literals.sh` 의 「상수 반복」 판정을 고친다.** `/` 로 끝나는 상수 값은 끝 `/` 를 남긴 채, 「브랜치 접두」 규칙과 같은 왼쪽 경계(`(?<![\w/.-])`)로 잰다(`c.rstrip("/") in line` 대신). `/` 로 끝나지 않는 값은 지금처럼. 음성 대조 「`prefix/feature/x` 는 잡지 않는다」는 그대로 둔다. Run: `bash plugins/spec-distill/tests/test_repo_literals.sh` — Expected: `✗` 0.
- [ ] **Step 4: 통과를 본다.** 같은 명령 둘(`test_repo_defaults.py` · `test_repo_literals.sh`) — Expected: OK · `✗` 0. 옛 `repo_settings` 테스트와 같은 뜻의 `merge_layers` 테스트를 더한다(옛 테스트와 `repo_settings` 는 Task 4 가 지운다).
- [ ] **Step 5: 변이 하나씩**(복원은 `git checkout HEAD --`): ` #` 판정을 지움 · 층 표에서 `branch_prefix` 를 로드맵 층에 넣음 · 우선순위의 repo/machine 순서 반전 — 셋 다 RED 를 본다. `test_repo_literals.sh` 의 상수 반복 판정을 `c.rstrip("/") in line` 로 되돌림 → 음성 대조 `prefix/feature/x` RED · 경계를 지워 `feature/` 를 그냥 부분 문자열로 → 같은 음성 대조 RED · 사본에 `x = "feature/y"` 를 넣음 → 잡힘(양의 짝).
- [ ] **Step 6: 커밋** — `git commit -m "feat(spec-distill): 해결자의 엄격한 머리말 · 닫힌 키 · 층 넷 합치기" -- plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_repo_literals.sh`

---

### Task 2: 해결자 — 기본 브랜치 판의 설정 파일 · `resolve` · CLI `get` · `check-path` (AC1 · AC3 · AC4 의 명령)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`
- Test: `plugins/spec-distill/tests/test_repo_defaults_git.sh` (새, 임시 레포)

**Interfaces:**
- Consumes: Task 1 의 `strict_frontmatter` · `check_layer` · `merge_layers`
- Produces:
  - `read_repo_file(cwd: str) -> tuple[dict | None, str | None, list[str]]` — (레포 층, 출처 라벨 `레포 설정@<8자>`, 알림). 기본 ref 커밋에서 `git ls-tree <커밋> -- .devbrew.md` 의 mode 가 `100644` 가 아니면 `SettingsError("not_regular_file")`, 내용 첫 줄이 `version https://git-lfs` 로 시작하면 `"lfs_pointer"`. 기본 ref 에 파일이 없고 작업 트리에 있으면 알림 「레포 설정 파일(.devbrew.md)이 아직 기본 브랜치에 없다 — 기본값을 쓴다」. 기본 ref 가 없으면 (None, None, [알림]) — 이때 `merge_layers` 의 기본값 출처는 `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)` 이고, 작업 트리에 파일이 있으면 알림을 「크게」(앞에 `[주의]`).
  - `resolve(cwd: str, roadmap: str | None = None, roadmap_text: str | None = None, machine_reader=None) -> dict` — `merge_layers` 의 반환. 로드맵을 받지 않으면 기계 상태 층을 건너뛰고 알림 「로드맵 없음 — 기계 상태 층 건너뜀」. `roadmap_text` 를 안 주면 기본 ref 의 로드맵을 읽는다. `machine_reader(roadmap) -> dict` 는 Task 4 가 넣는다 — 이 과제에서 기본값은 `None` 이고, `None` 이면 기계 상태 층을 건너뛰고 알림 「기계 상태 층 건너뜀 — 읽는 함수 없음」(그 읽는 함수 `conductor_state.repo_settings_rows` 는 Task 4 가 만든다; 깨졌으면 `SettingsError("unreadable", where="machine")`).
  - CLI `repo_defaults.py get <키> [--roadmap <레포 상대 경로>] [--root <레포>]` · `check-path <키> <경로> [--root <레포>]` (종료 코드는 위 「설계에 없던 결정 2 · 3」, `--root` 는 「설계에 없던 결정 10」). 모든 하위 명령이 같은 `--root` 를 받는다.
  - 경로 인자(`check-path` · 뒤 과제의 `roadmap-check`)의 꼴: 상대 경로는 `--root`(없으면 cwd) 기준, 절대 경로는 `--root` 의 `pwd -P` 아래면 그 기준 상대 경로로 바꿔 판정하고 밖이면 rc 3 「레포 밖 경로」. 판정은 바꾼 상대 경로로만 한다(절대 경로를 글자 그대로 폴더 키와 비교하지 않는다).

- [ ] **Step 1: 실패하는 셸 테스트를 쓴다** — 임시 레포 셋(`trunk` 기본 · 원격은 로컬 bare · `git remote set-head origin --auto`). 사례:
  - `test_default_ref_file_wins_over_worktree`: 기본 브랜치에 `.devbrew.md`(`interview_dir: notes/iv/`), 작업 브랜치에서 `interview_dir: other/` 로 고침 → `get interview_dir` = `notes/iv/`, stderr 에 `레포 설정@<8자>`.
  - `test_worktree_only_file_notice`: 기본 브랜치에 없음 · 작업 트리에만 있음 → 값 = 기본값, stderr 에 「아직 기본 브랜치에 없다」.
  - `test_no_default_ref_uses_constants_with_source`: `origin/HEAD` 를 지움 → rc 0, 값 = 기본값, stderr 에 `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)`. 작업 트리에 파일이 있으면 `[주의]`.
  - `test_symlink_and_lfs_refused`: 기본 브랜치의 `.devbrew.md` 가 링크(120000) → rc 3 「일반 파일이 아니다」; LFS 포인터 내용 → rc 3 「LFS」.
  - `test_get_no_value_rc1`: `get test_command`(어디에도 없음) → rc 1, stdout 비었음.
  - `test_get_broken_rc3`: 같은 키 둘 · BOM · 오타 키 → 셋 다 rc 3, stderr 사유가 서로 다르다(AC2 · AC29).
  - `test_check_path`: `check-path roadmaps_dir docs/superpowers/roadmaps/x` rc 0 · `…/Roadmaps/x` rc 3 「대소문자만 다른 경로」 · 디스크의 실제 폴더가 `Roadmaps` 인데 인자는 `roadmaps` → rc 3 (macOS APFS 기본에서만 돈다 — 대소문자 구별 파일시스템이면 이 사례는 건너뛰고 그 사실을 `note` 줄(`shared/tests/assert.sh`)로 낸다; 건너뛴 사례를 `ok` 로 세지 않는다) · `docs/x` rc 3 「부모 폴더가 다르다」 · 절대 경로 `"$(pwd -P)/docs/superpowers/roadmaps/x"` rc 0 · 레포 밖 절대 경로 rc 3 「레포 밖 경로」.
  - 양성 대조 하나: 설정이 다른 두 레포에서 `get interview_dir` 결과가 다르다.
  - `test_root_flag_reads_other_repo`: 레포 A 에서 `get interview_dir --root <레포 B>` = B 의 값(cwd 의 A 값이 아니다).
- [ ] **Step 2: 돌려 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_repo_defaults_git.sh` — Expected: `✗` 줄들(`get` 하위 명령 없음).
- [ ] **Step 3: `read_repo_file` · `resolve` · CLI 를 구현한다.** git 은 `subprocess.run([... "git", "-c", "core.quotePath=false", ...], timeout=5, env=GIT_TERMINAL_PROMPT=0 · GIT_OPTIONAL_LOCKS=0)`. 기본 ref 는 `roadmap_model.DEFAULT_REF` (`import roadmap_model as _rm`).
- [ ] **Step 4: 통과를 본다.** 같은 명령 — Expected: `✗` 0. `chmod +x` 후 `git ls-files -s` 로 100755 확인.
- [ ] **Step 5: 변이**: 기본 ref 대신 작업 트리를 읽게 바꿈 → `test_default_ref_file_wins_over_worktree` RED · mode 검사를 지움 → 링크 사례 RED · `get` 의 빈 값 rc 를 0 으로 → `test_get_no_value_rc1` RED.
- [ ] **Step 6: 커밋** — `feat(spec-distill): 해결자가 기본 브랜치의 레포 설정 파일을 읽고 get · check-path 를 낸다`

---

### Task 3: 기본 브랜치 — 전체 참조 이름 · 고치는 법 · 원격 대조 (AC9 의 spec-distill 몫 · AC10 · AC11)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` (`NO_ORIGIN` 만 더함), `repo_defaults.py`, `roadmap_status.py` (`Git.default_branch`), `control_plane.py` (`default_ref` · `statusline_text` · `gather` 의 `no_default`), `conductor_ledger.py` (`NO_DEFAULT` 를 내는 자리 셋), `merge_check.py` (`run` 의 `--abbrev-ref` 자리 · fetch 뒤 대조), `skills/epic-conductor/SKILL.md` (진입 단계 3 뒤 대조 펜스 한 줄)
- Test: `plugins/spec-distill/tests/test_default_branch.sh` (새), `tests/test_roadmap_approval.py` (`OneDefaultRef`)

**Interfaces:**
- Produces:
  - `roadmap_model.NO_ORIGIN = "기본 브랜치를 알 수 없다 — origin 원격이 없다. git remote add origin <URL> 로 더한 뒤 git remote set-head origin --auto 를 돈다"`
  - `repo_defaults.default_branch(cwd) -> tuple[str | None, str | None, str | None]` — (커밋, 짧은 이름, 못 찾은 사유). 짧은 이름은 `git rev-parse --symbolic-full-name refs/remotes/origin/HEAD` 의 결과에서 접두 `refs/remotes/origin/` 을 벗긴 것; 접두가 아니면 사유. 사유는 `origin` 원격이 없으면 `NO_ORIGIN`, 있으면 `NO_DEFAULT`.
  - `repo_defaults.check_remote_head(cwd, local_short: str, timeout: float = 10.0) -> tuple[str, str]` — (`"same"` · `"differs"` · `"unchecked"`, 한 줄). `differs` 문장: 「원격 기본 브랜치(<원격>)가 로컬 기본 브랜치(<로컬>)와 다르다 — git remote set-head origin --auto 로 맞춘 뒤 다시 돈다」. `unchecked` 문장: 「원격과 대조하지 못했다 — 로컬 기본 브랜치 <이름> 을 썼다」.
  - CLI `default-branch [--check-remote] [--root <레포>]` — 종료 코드 0 · 3 · 5. `--root` 가 있으면 그 레포의 `origin/HEAD` · 원격으로 판정한다(Task 7 의 끝내기 펜스가 `--root "$top"` 으로 부른다).

- [ ] **Step 1: 실패하는 테스트.** `test_default_branch.sh` 사례:
  - `trunk_repo`: 기본 `trunk` → `default-branch` 가 `trunk`.
  - `local_branch_named_origin_main`: 로컬 브랜치 `origin/main` 을 만든 레포 → 여전히 `main`(AC11 — `--short` 결과 벗기기의 회귀 증인).
  - `no_origin`: 원격 없음 → rc 3, stderr 에 `git remote add origin` (AC29 「origin 이 없는 레포」).
  - `no_head`: 원격은 있고 `origin/HEAD` 없음 → rc 3, stderr 에 `git remote set-head origin --auto`.
  - `renamed_default`: bare 원격의 HEAD 를 `trunk` 로 바꾸고 클론에서 `git fetch` 만 → `--check-remote` rc 5, 문장에 두 이름(AC10 · AC29 「기본 브랜치 개명 뒤」).
  - `offline`: 원격 URL 을 없는 경로로 바꿈 → `--check-remote` rc 0, stderr 에 「원격과 대조하지 못했다」.
  - `merge_check_stops_on_rename`: 같은 개명 레포에서 `merge_check.py run --roadmap … --branch …` rc 3, 출력에 `set-head`.
  - `statusline_names_default`: `control_plane.py statusline` 출력에 `기본 브랜치 trunk` 와 「(어느 원격 · 브랜치든)」.
  - `root_flag_other_repo`: 기본 `main` 레포 A 를 cwd 로 두고 `default-branch --root <기본 trunk 레포 B>` → `trunk`(cwd 의 `main` 이 아니다).
  - `OneDefaultRef` 에 `self.assertIs(rd._rm.DEFAULT_REF, M.DEFAULT_REF)` 와 「`repo_defaults.py` 에 `DEFAULT_REF = "` 가 없다」를 더한다.
- [ ] **Step 2: 돌려 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_default_branch.sh` — Expected: `✗` 줄들.
- [ ] **Step 3: 구현.** `roadmap_status.Git.default_branch` · `control_plane.default_ref` · `conductor_ledger` 의 세 자리 · `merge_check.run` 이 `repo_defaults.default_branch` 의 짧은 이름과 사유를 쓴다(사유 그대로 보인다). `merge_check.run` 은 fetch 뒤 `check_remote_head` 가 `differs` 면 `Stop(3, …)`. 지휘자 진입 단계 3 의 펜스 끝에 `python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote` 를 더하고, 표에 「rc 3 · 5 면 그 줄을 보이고 멈춘다 · rc 0 의 「대조하지 못했다」 줄은 보이고 간다」 한 줄. 상태줄은 네트워크를 쓰지 않고 `기본 브랜치 <이름> · 받은 지 N분(어느 원격 · 브랜치든)`.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py plugins/spec-distill/tests/test_control_plane.py` — Expected: OK.
- [ ] **Step 5: 변이**: 접두 벗기기를 `rsplit("/",1)[-1]` 로(→ `feature/x` 꼴 기본 브랜치 사례를 하나 더해 RED) · `differs` 를 무시 → `renamed_default` RED · 오프라인을 멈춤으로 → `offline` RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 기본 브랜치를 전체 참조 이름에서 얻고 원격과 대조한다`

---

### Task 4: 흡수 — 상태 계산 · 상태줄 · 스위트 대조가 해결자를 지난다 (AC1 의 소비자 · AC5)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`build` 의 `repo_settings` 자리), `control_plane.py` (설정을 쓰는 자리), `merge_check.py` (`machine_settings` · `run` 의 설정 · 패턴 자리 · 출처가 `기계 상태(임시)` 면 「이 값을 레포 설정 파일(.devbrew.md)에 올린다」 한 줄), `conductor_state.py` (`## 레포 설정` 읽기 함수 하나), `repo_defaults.py` (`repo_settings` 지움 — 호출자를 옮긴 뒤), `references/conducting.md` (걸음 5 의 종료 코드 6 문장 — 「다음 로드맵 수정 PR 에서 frontmatter `test_command` 로 올리고」를 「레포 설정 파일에 올리자고 알리고」로 · 머리 규칙 줄과 손 절차의 같은 규칙 줄 둘 — 「레포마다 다른 값은 … 로드맵 frontmatter 의 `specs_dir` · `plans_dir` · `test_command` · `review_model` 이다」 · 「한 번 물어 정한 값은 다음 로드맵 수정 PR 에 frontmatter 로 올린다」를 「해결자(`repo_defaults.py get`)가 로드맵 · 레포 설정 파일 · 기본값에서 낸다 · 정한 값은 레포 설정 파일에 올리자고 알린다」로)
- Test: `plugins/spec-distill/tests/test_merge_check.sh`, `tests/test_roadmap_status.sh`, `tests/test_repo_defaults.py`(옛 `repo_settings` 테스트 지움)

**Interfaces:**
- Consumes: Task 2 의 `resolve(cwd, roadmap, roadmap_text, machine_reader)`
- Produces: `conductor_state.repo_settings_rows(path, roadmap_rel) -> dict[str, str]` — `## 레포 설정` 의 키 → 값. 같은 키 둘이면 `MachineError`(지금의 「마지막 줄이 이김」을 없앤다). `merge_check.machine_settings` 는 지우고 이것을 `machine_reader` 로 넘긴다 — 기계 상태 층을 쓰는 소비자(`merge_check` · `roadmap_status`)가 `resolve(..., machine_reader=…)` 로 넘긴다(Task 2 의 기본값 `None` 은 그대로).
- `roadmap_status` 의 보고 `settings` 에 `notices` 를 더한다. `report["settings"]["sources"]` 의 값은 위 출처 표기다.

- [ ] **Step 1: 실패하는 테스트.**
  - `test_merge_check.sh`: 기계 상태 `## 레포 설정` 에 `test_command` 가 둘 → rc 3 「같은 키」 · 로드맵에 `test_failure_pattern` 이 있으면 기계 상태 값은 안 쓴다(출처 `로드맵`) · 로드맵에 없고 `.devbrew.md` 에 있으면 출처 `레포 설정@<8자>` · 기계 상태에 `review_model` → rc 3 「기계 상태 층이 받지 않는 키」(AC23b).
  - `test_roadmap_status.sh`: `--json` 의 `settings.sources.specs_dir` 가 `.devbrew.md` 가 있으면 `레포 설정@` 로 시작한다 · 로드맵 머리말에 `roadmaps_dir` 가 있으면 `format_errors` 에 「로드맵 층이 받지 않는 키」.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_merge_check.sh; bash plugins/spec-distill/tests/test_roadmap_status.sh` — Expected: 새 사례 `✗`.
- [ ] **Step 3: 구현.** 세 스크립트가 `repo_settings(meta)` 대신 `resolve(...)` 를 부른다. `merge_check.run` 의 `pattern` 은 `resolve` 의 `test_failure_pattern` 값과 출처로(직접 `meta[...]` 를 읽지 않는다). `SettingsError` 는 각 스크립트의 「검사 불가」(rc 3 · `format_errors`)로. 호출자를 다 옮긴 뒤 `repo_defaults.repo_settings` 와 그 옛 테스트를 지운다(`git grep -n 'repo_settings(' -- plugins` 가 `repo_settings_rows` 밖에서 0). `conducting.md` 의 세 문장을 위 Files 대로 맞춘다.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py'` — Expected: 새 실패 없음.
- [ ] **Step 5: 커밋** — `refactor(spec-distill): 상태 계산 · 상태줄 · 스위트 대조의 레포 설정을 해결자 하나로`

---

### Task 5: 로드맵 찾기 하나 (AC6)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py`, `control_plane.py` (`candidates` · `ROADMAP_RE` 지움 · `GIT_OK` 에 `cat-file`), `conductor_ledger.py` (`c_roadmaps`), `repo_defaults.py` (CLI `roadmap-check`)
- Test: `plugins/spec-distill/tests/test_roadmap_model.py`, `tests/test_control_plane.sh`, `tests/test_conductor_ledger.py`, `tests/test_repo_defaults_git.sh`(`roadmap-check` 사례)

**Interfaces:**
- Produces:
  - `roadmap_model.roadmap_verdict(path: str, text: str | None, roadmaps_dir: str) -> tuple[str, str]` — (`"roadmap"` · `"not_roadmap"` · `"unreadable"`, 사유). 모양: `path` 가 `roadmaps_dir` 바로 아래 폴더 한 단계 안의 `.md` ∧ 머리말 `type: roadmap`. 머리말을 못 읽으면 `"unreadable"`(조용히 빼지 않는다).
  - `roadmap_model.find_roadmaps(paths: list[str], read: Callable[[str], str | None], roadmaps_dir: str) -> tuple[list[str], list[tuple[str, str]]]` — (로드맵, [(검사 불가 경로, 사유)]).
  - CLI `repo_defaults.py roadmap-check <경로> [--root <레포>]` — 작업 트리 파일로 `roadmap_verdict`; 0 · 3. `roadmaps_dir` 는 `--root` 레포의 해결자 값. 경로 꼴은 Task 2 의 `check-path` 와 같다: 상대 경로는 `--root`(없으면 cwd) 기준, 절대 경로는 `--root` 의 `pwd -P` 아래면 상대 경로로 바꿔 판정하고 밖이면 rc 3 「레포 밖 경로」(Task 7 의 끝내기 펜스는 물리 절대 경로를 넘긴다).
- `control_plane.candidates` 와 `c_roadmaps` 는 기본 ref 의 `ls-tree -r -z <main> -- <roadmaps_dir>` 목록과 blob 읽기로 `find_roadmaps` 를 부른다. 검사 불가는 지금처럼 「검사 불가」 행으로 센다.

- [ ] **Step 1: 실패하는 테스트.** `test_roadmap_model.py`: `test_template_and_fixture_are_not_roadmaps`(`plugins/spec-distill/templates/roadmap-template.md` · `plugins/spec-distill/tests/fixtures/conductor-e2e/roadmap.md` 경로 + `type: roadmap` 글 → `not_roadmap`, 사유 「로드맵 폴더 밖」) · `test_two_levels_deep_is_not_roadmap` · `test_unreadable_frontmatter_is_counted` · `test_other_type_in_folder`(`type: epic-bundle` → `not_roadmap`) · `test_any_md_name_in_folder_is_roadmap`(`<dir>x/plan.md` + `type: roadmap` → `roadmap`). `test_control_plane.sh` · `test_conductor_ledger.py`: 설정 폴더가 `plan/roadmaps/` 인 임시 레포에서 두 진입이 같은 목록을 낸다(AC29 「설정 폴더가 다른 레포」). `test_repo_defaults_git.sh`: `roadmap-check` 가 상대 경로 · 같은 파일의 물리 절대 경로에 같은 rc 0 · 레포 밖 절대 경로 rc 3 · 레포 A 를 cwd 로 두고 `--root <레포 B>`(`roadmaps_dir: plan/roadmaps/`)로 B 의 `plan/roadmaps/x/roadmap.md` 가 rc 0(A 의 설정이면 rc 3).
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py -v; bash plugins/spec-distill/tests/test_repo_defaults_git.sh` — Expected: `roadmap_verdict` 없음 · 새 사례 `✗`.
- [ ] **Step 3: 구현.** 두 진입과 CLI 가 `find_roadmaps` · `roadmap_verdict` 만 부른다(같은 판정의 복제가 없다 — Task 10 의 락이 잰다).
- [ ] **Step 4: 통과를 본다.** 같은 명령들 — Expected: OK.
- [ ] **Step 5: 변이**: `roadmap_verdict` 의 폴더 검사를 지움 → 템플릿 사례 RED · 표지 검사를 지움 → `epic-bundle` 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 로드맵은 정해진 폴더 안 표지로 하나의 함수가 찾는다`

---

### Task 6: 박힌 값 — 인터뷰 · 설계문서 폴더 · 브랜치 접두 (AC8 · AC12 · §2 의 인터뷰 폴더 · spec-review 후보)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` (`INTERVIEW_DIR` 를 `repo_defaults` 에서 · `interview_state_path` 가 `resolve` 의 `interview_dir`), `control_plane.py` (`interview_files` · `read_interviews` 의 글자 경로), `skills/request-framing/SKILL.md` (`## 상태` 블록의 `AUDIT` · `SEED` · 산출물 표 · `## 워크트리 — 진입 직후` 의 빈 요청 문단 · 워크트리 질문의 `feature/<kebab-topic>` · 승낙 절차 2 의 `git branch -m` · 3 의 폴더 · 끝 안내의 넘김 경로 예시 · `## 확정 — proceed 게이트` 의 handoff 직전 커밋 펜스 앞 `check-path interview_dir` 단순 명령), `skills/pm-interview/SKILL.md` (frontmatter `description` · `## State location`), `skills/pm-interview/references/finishing.md` (Task 0 Step 4 목록의 인터뷰 경로 · 분해 판단의 로드맵 폴더 안내 · 분해안 표의 브랜치 칸 안내 · Step A 8 의 `BRIEF_REL` · `--out` · Step A.5 의 `PAYLOAD` · Step B 의 proceed-gate 경로 문장 · B-1 안내), `skills/pm-interview/references/state-file.md` (머리 문장), `skills/spec-review/SKILL.md` (frontmatter `description` · 설계문서 후보 펜스), `references/redecompose.md` (작업 브랜치 두 문장)
- Test: `plugins/spec-distill/tests/test_repo_literals.sh`, `tests/test_decompose_surface.sh`, `tests/test_interview_state.py`, `tests/test_state_dir_writes.sh`(request-framing · spec-review 펜스), `tests/test_finishing_block_scope.py`(finishing · redecompose 펜스), `tests/test_ledger_root.sh`(RF `## 상태` 의 맨 `state-root` 하나)

**Interfaces:**
- Consumes: CLI `get interview_dir` · `get specs_dir` · `get roadmaps_dir` · `get branch_prefix` · `default-branch`
- 펜스 꼴(값이 필요한 자리 — rc 와 빈 값을 확인):

```bash
IDIR="$(python3 "$SD/scripts/repo_defaults.py" get interview_dir)" || IDIR=""
[ -n "$IDIR" ] || { echo "[spec-distill] 인터뷰 폴더를 정하지 못했다 — 위 줄의 사유를 고친 뒤 다시 돌린다" >&2; exit 1; }
```

- [ ] **Step 1: 락을 먼저 넓힌다(실패를 본다).** `test_repo_literals.sh` 의 `TARGETS` 에 `skills/request-framing/SKILL.md` · `skills/pm-interview/SKILL.md` · `skills/pm-interview/references/finishing.md` · `skills/pm-interview/references/state-file.md` · `skills/spec-review/SKILL.md` · `references/redecompose.md` · `scripts/control_plane.py` · `scripts/state_path.py` · `scripts/roadmap_status.py` 를 더한다. 새 대상마다 「대상이 있다」 · 변이 사본 잡힘 사례가 자동으로 붙는다(기존 `mut` 루프). 「레포 구조 경로」 규칙은 frontmatter `description` 줄(pm-interview · spec-review)과 사람에게 보이는 예시 경로(request-framing 끝 안내)도 잡는다 — 「인터뷰 폴더(`interview_dir`)」 · 「설계문서 폴더(`specs_dir`)」처럼 키 이름으로 바꾼다. 면제는 줄 꼴 하나만 더한다 — 처분 앵커 줄(`**처분** — consumer=` 꼴, 앞의 `//` · `#` 주석 표지 허용)은 스캔에서 뺀다. 그 줄은 `consumer=plugins/spec-distill/scripts/docreview_route.py` 처럼 레포 기준 추적 경로를 적어야 하고(`shared/tests/test_dispatch_disposition.sh` 축 A④ 실재 · A⑤ 같은 플러그인), 그 꼴은 그 락이 집행한다(request-framing · spec-review 에 네 줄). 그 밖의 면제는 늘리지 않는다. 변이 짝: 대상 사본에 앵커 꼴이 아닌 줄 `see plugins/spec-distill/scripts/docreview_route.py` 를 넣으면 잡히고(같은 경로라도 앵커 밖은 잡는다), `  // **처분** — consumer=plugins/spec-distill/scripts/docreview_route.py · fail-open · disclosure=x` 를 넣으면 잡히지 않는다. Run: `bash plugins/spec-distill/tests/test_repo_literals.sh` — Expected: 새 대상의 박힌 줄이 `✗`(앵커 넷은 아님).
- [ ] **Step 1b: 펜스 꼴 락을 더한다(AC4).** 같은 테스트에 축 하나 — 대상 파일에서 `repo_defaults.py" get ` 을 품은 줄은 `<V>="$(… get …)" || <V>=""` 꼴이고 그 뒤 첫 비지 않은 줄에 `[ -n "$<V>" ]` 가 있다. 경로로 `git add` 범위를 정하는 펜스(정규식 `git( -C \S+)? add --` 에 맞는 줄을 품은 펜스 — finishing 의 `git -C "$top" add -- …` 와 request-framing handoff 펜스의 `git add -- "$AUDIT" "$SEED"` 둘 다)는 `check-path` 또는 `roadmap-check` 를 부른다. 펜스 판독은 기존 테스트의 펜스 추출기를 쓰고, 변이(rc 확인 줄 지움 · 빈 값 확인 줄 지움 · request-framing handoff 펜스의 `check-path` 줄 지움 · finishing 커밋 펜스의 `check-path` · `roadmap-check` 줄 지움 — 뒤 둘은 Task 7 뒤에 RED)가 RED 인지 본다. 양의 짝: 위 꼴의 줄이 대상에 하나 이상 있다(공허 통과 방지).
- [ ] **Step 2: `test_decompose_surface.sh` 의 글자 락을 「도출하는가」 락으로 바꾼다(AC12).** 지금의 redecompose 글자 단언 둘(`'feature/roadmap-<요지>'` · `'새로 fetch 한 \`origin/main\` 에서 \`feature/roadmap-<요지>\` 브랜치를 전용 worktree'`)을 지우고, `redecompose.md` 가 `repo_defaults.py" default-branch` 와 `repo_defaults.py" get branch_prefix` 를 가리키고 `origin/main` · `feature/` 글자가 없음을 함께 단언한다(양 · 음 짝). 같은 일을 `test_conducting_reference.sh` 의 `banned` 목록(대상은 `conducting.md` 하나)이 하는지 확인하고, redecompose 를 그 목록 대상에 더하는 쪽과 겹치면 한 곳에 둔다. 브랜치를 만드는 문장을 펜스로 바꾸면 그 펜스 안에서 `SD` 를 다시 정의한다(펜스 사이 변수 나르기 금지 — `test_finishing_block_scope.py` `test_redecompose_fences_same_rule`). Run — Expected: `✗`(아직 글자).
- [ ] **Step 2b: Step A 8 e2e 의 치환을 해결자 값으로 바꾼다.** `test_decompose_surface.sh` 의 `e2e_run` 은 펜스의 `docs/superpowers/interview/<file>` · `docs/superpowers/roadmaps/<…>/` 글자를 치환해 돈다 — Step A 8 이 `BRIEF_REL` · `--out` 을 해결자에서 얻으면 그 치환이 공허해진다. 임시 레포에 `.devbrew.md`(`interview_dir: docs/iv/` · `roadmaps_dir: docs/`)를 기본 브랜치에 커밋해 두고 펜스를 손대지 않고 돌리거나, 설정 없이 기본 폴더를 쓰고 결과 폴더가 `get roadmaps_dir` 아래에 생겼음을 단언한다. 「거절되면 폴더를 만들지 않는다」(`stepa8_multiline_approval_verbatim`) 사례에는 같은 픽스처의 한 줄 승인이 rc 0 으로 폴더를 만드는 양의 짝을 붙인다(치환이 깨져 펜스가 아무 데도 못 쓰는 공허 통과 방지).
- [ ] **Step 3: 고친다.** 파이썬은 `resolve(...)["values"][...]`, 펜스는 위 꼴. `state_path.INTERVIEW_DIR` 은 `repo_defaults.INTERVIEW_DIR` 를 나눈 튜플로 남기되 `interview_state_path` 는 `resolve(root)` 의 값을 쓴다(설정이 깨졌으면 `(None, [사유])`). 인터뷰 상태 경로 두 갈래(`<주제>` · `<주제>-<HHMM>`)가 모두 그 폴더를 지난다. 분해안 표의 브랜치 칸 안내는 「`<branch_prefix><kebab>` — 접두는 `get branch_prefix`」. spec-review 후보 펜스는 `"${SPECS}*-design.md"` 로. request-framing `## 상태` 블록은 맨 `state-root` 호출 하나를 그대로 두고(`test_ledger_root.sh` `root_lock`), 그 블록이 `repo_defaults.py` 를 부르면 같은 루트 변수(`$SD`)로 부른다. 세 skill 폴더 펜스에 새 쓰기를 두면 `nofollow_write.py` 로(Global Constraints). request-framing `## 확정 — proceed 게이트` 의 handoff 직전 커밋 펜스(「단순 명령 둘」 — 격리 세션 git 가드가 복합 명령을 막는다)는 앞에 단순 명령 하나 `python3 "$SD/scripts/repo_defaults.py" check-path interview_dir "$AUDIT"` 를 더하고, 그 rc 가 0 이 아니면 그 사유를 보이고 뒤 두 git 명령을 돌리지 않는다(게이트 앞 글에 «미커밋 — <사유>»). 펜스 위 설명 문장의 「단순 명령 둘」도 셋으로 맞춘다.
- [ ] **Step 4: 통과를 본다.** Run: `bash plugins/spec-distill/tests/test_repo_literals.sh; bash plugins/spec-distill/tests/test_decompose_surface.sh && python3 -m unittest plugins/spec-distill/tests/test_interview_state.py plugins/spec-distill/tests/test_finishing_block_scope.py && bash plugins/spec-distill/tests/test_state_dir_writes.sh && bash plugins/spec-distill/tests/test_ledger_root.sh` — Expected: `test_repo_literals.sh` 는 Task 7 이 고칠 다섯 줄만 `✗` 로 남는다 — `finishing.md` 끝내기 커밋 펜스 앞 문단의 「폴더의 부모가 `docs/superpowers/roadmaps` 가 아니거나」 줄 · 펜스의 `[ "$(dirname -- "$RDIR")" = "${top}/docs/superpowers/roadmaps" ]` 줄 · 그 사유 줄(「docs/superpowers/roadmaps 바로 아래가 아니다」), `request-framing/SKILL.md` `## 워크트리 — 진입 직후` 설명 문단의 「`origin/main` 과 발산해 있을 수 있다」 줄 · base 펜스의 `for cand in origin/main origin/master; do` 줄 — 그리고 Step 1b 의 `git add` 축이 `finishing.md` 의 `interview-commit` 펜스(아직 `check-path` · `roadmap-check` 를 부르지 않음)에 내는 `✗` 하나(그 밖의 `✗` 는 0; GREEN 은 Task 7 Step 4 에서 본다). 나머지는 `✗` 0 · OK.
- [ ] **Step 5: 변이**: 새 대상 하나에 `docs/superpowers/interview/x` 를 되돌려 넣음 → RED · `redecompose.md` 에 `feature/roadmap-` 를 되돌림 → RED · `interview_state_path` 가 상수를 쓰게 → `interview_dir: notes/` 레포 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 인터뷰 · 설계문서 폴더와 브랜치 접두를 해결자에서 얻는다`

---

### Task 7: 끝내기 커밋 펜스 · request-framing 의 기본 브랜치 (AC7 · AC9 · AC10 · AC11 의 펜스 몫)

**Files:**
- Modify: `skills/pm-interview/references/finishing.md` (끝내기 커밋 펜스 `interview-commit` 과 그 앞 문단), `skills/request-framing/SKILL.md` (`## 워크트리 — 진입 직후` 의 base 도출 펜스와 그 위아래 설명 문단)
- Test: `plugins/spec-distill/tests/test_finish_commit_roadmap.sh`, `tests/test_request_framing_entry.sh`, `tests/test_decompose_surface.sh`(커밋 펜스의 `"${top}/docs/superpowers/roadmaps"` 글자 단언을 `check-path roadmaps_dir` · `roadmap-check` 를 부르는가로), `tests/test_finishing_block_scope.py`, `tests/test_state_dir_writes.sh`(request-framing 펜스), `tests/test_repo_literals.sh`(Task 6 가 남긴 이 과제 몫 — Task 6 Step 4 의 다섯 줄과 `interview-commit` 펜스의 `git add` 축 — 이 사라져 GREEN)

**Interfaces:**
- Consumes: `roadmap-check` · `check-path roadmaps_dir` · `default-branch --check-remote` (셋 다 `--root "$top"`, 경로는 물리 절대 경로 — Task 2 · 5 의 경로 꼴)
- 펜스가 가르는 다섯(그대로 메시지 · 동작):
  - 폴더 없음 → 「brief §7 의 로드맵 폴더가 없어 빼고 진행한다」(지금처럼).
  - 폴더는 있는데 인덱스에 커밋할 파일 없음(빈 폴더) → 「로드맵 폴더에 커밋할 파일이 없어 빼고 진행한다」(지금처럼).
  - 부모가 `roadmaps_dir` 아님 · 대소문자만 다름 · `roadmap-check` 거부 → 커밋하지 않는다(사유 한 줄).
  - 기본 브랜치 없음(rc 3) · 원격과 다름(rc 5) → 커밋하지 않는다, `default-branch` 의 stderr 그대로.
  - 원격 대조 못 함 → 「원격과 대조하지 못했다 …」를 보이고 커밋은 한다.

- [ ] **Step 1: 실패하는 테스트.** `test_finish_commit_roadmap.sh` 에 사례 — 설정 `roadmaps_dir: plan/roadmaps/` 레포에서 §7 이 `plan/roadmaps/x/roadmap.md` 면 커밋에 폴더가 든다 · §7 이 `docs/superpowers/roadmaps/x/roadmap.md`(기본값 자리, 설정과 다름)면 커밋하지 않는다 · 대소문자만 다른 경로 · 빈 폴더 · 폴더 없음 · 로컬 브랜치 `origin/main` 이 있는 레포에서 기본 브랜치(`main`) 위 커밋이 거부된다(AC11 — 지금은 통과해 버린다) · 기본 브랜치 개명 뒤 거부 · 오프라인이면 알림 뒤 커밋. `test_request_framing_entry.sh`: `origin/HEAD` 없음 + `origin/main` 있음 → 「확인 못함」(main/master 대체가 없다) · 로컬 브랜치 `origin/main` 이 있어도 base 가 `origin/<기본>` 전체 이름에서 온다.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh; bash plugins/spec-distill/tests/test_request_framing_entry.sh` — Expected: 새 사례 `✗`.
- [ ] **Step 3: 펜스를 고친다.** 끝내기 펜스는 문서가 사는 레포(`top` — brief 폴더의 `--show-toplevel`)를 기준으로 돈다 — 해결자 호출은 모두 `--root "$top"`(「설계에 없던 결정 10」). `def` 를 `default-branch --check-remote --root "$top"` 의 stdout 으로(rc 3 · 5 면 커밋 갈래를 「기본 브랜치를 판정하지 못했다」로 — `|| def=""` 로 rc 를 삼키지 않고 rc 를 따로 받는다), §7 경로는 `roadmap-check` → `check-path roadmaps_dir "$(dirname -- "$r7")"`, 지금의 `*/roadmap.md` 이름 검사는 지운다(「설계에 없던 결정 6」 — `roadmap-check` 가 모양을 잰다), 존재 · 대소문자는 작업 트리, 커밋할 파일은 `git ls-files -- "$RDIR"`(인덱스). 펜스 앞 문단의 「`roadmap.md` 로 끝나지 않거나 · 부모가 `docs/superpowers/roadmaps` 가 아니거나」 문장도 같은 규칙으로. request-framing base 펜스: `git symbolic-ref --quiet refs/remotes/origin/HEAD` 전체 이름을 쓰고 main/master 후보 루프를 지운다 — 못 찾으면 「확인 못함」 그대로. 위 설명 문단의 `origin/main` 예시와 아래 「main/master 둘 다 부재」 문장을 맞춘다. 두 펜스 모두 앞 펜스의 변수를 쓰지 않는다.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `bash plugins/spec-distill/tests/test_decompose_surface.sh && python3 -m unittest plugins/spec-distill/tests/test_finishing_block_scope.py && bash plugins/spec-distill/tests/test_state_dir_writes.sh && bash plugins/spec-distill/tests/test_repo_literals.sh`(GREEN — Task 6 Step 1b 의 `git add` 축 변이 중 finishing 커밋 펜스 몫도 여기서 RED 를 본다) + 펜스를 `bash -n` 과 `zsh -n` 으로(펜스 추출은 기존 테스트의 추출기) — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `${def#origin/}` 꼴로 되돌림 → AC11 사례 RED · 인덱스 대신 작업 트리로 빈 폴더 판정 → 빈 폴더 사례 RED · 대조 rc 5 무시 → 개명 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 인터뷰 끝 커밋 펜스의 로드맵 폴더 · 기본 브랜치 검사를 해결자로`

---

### Task 8: qg · 공유 기준선 — main/master 대체 지움 · 사유와 안내 (AC9 의 qg 몫)

**Files:**
- Modify: `shared/test-selection/resolve-baseline.sh`(qg · spec-distill 에 링크로 들어 있다), 그 소비자 전부 — `plugins/quality-gates/scripts/check-review-scope.sh` · `review-diff.sh` · `discover-spec.sh` · `resolve-topic.sh`(두 자리) · `shared/test-selection/compute-test-scope-candidates.sh` · `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`(기준선 펜스), `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (Review Step 1c 의 출력 키 읽기 · degraded 사유를 보이는 자리), `shared/test-selection/README.md`
- Test: `plugins/quality-gates/tests/test_resolve_baseline.sh`, `plugins/quality-gates/tests/test_review_diff.sh`, `shared/tests/test_test_selection_bundle.sh`, `plugins/spec-distill/tests/test_merge_check.sh`

**Interfaces:**
- Produces: `resolve-baseline.sh` 출력에 키 하나 — `degraded_reason: <-|no-default-branch|not-a-repo|no-head|detached|shallow|merge-base>`(6줄 → 7줄, 자리는 review-diff 와 같이 `degraded:` 바로 다음 줄 — 키 순서 `base,base_ref,merge_base,degraded,degraded_reason,same_as_head,ahead`; 소비자는 키로 읽는다 — 머리 주석의 「항상 6줄」도 고친다). `no-default-branch` 면 stderr 에 한 줄: `[resolve-baseline] 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다`. 기준은 `refs/remotes/origin/HEAD` 하나 — 대체 후보(`origin/main` · `origin/master` · 로컬 `main` · `master`) 없음. `base` 짧은 이름은 전체 이름에서 `refs/remotes/origin/` 을 벗겨 얻는다.
- `review-diff.sh`: stdout 에 `degraded_reason:` 키를 `degraded:` 다음 줄에 더한다(10줄 → 11줄). 머리 주석의 「stdout 10줄」 문장과 키 목록, `test_review_diff.sh` 의 「stdout 10줄」 단언 세 자리를 함께 고친다. 기준선이 `no-default-branch` 로 degraded 면 review-diff 가 stderr 에 **`review-diff: ` 로 시작하는** 안내 한 줄(`review-diff: 기본 브랜치를 찾지 못해 리뷰 범위를 정하지 못했다 — git remote set-head origin --auto 로 고친다`)을 낸다 — Review Step 1c 는 `review-diff: ` 로 시작하는 stderr 줄만 사용자에게 옮기고 `[resolve-baseline] …` 줄은 옮기지 않는다(#243). Step 1c 의 옮김 규칙은 넓히지 않는다.
- 다른 소비자: `check-review-scope.sh` 는 자기 출력에 `degraded_reason:` 을 싣는다 · `discover-spec.sh` · `resolve-topic.sh` · `compute-test-scope-candidates.sh` 는 지금처럼 키로 읽되 `2>/dev/null` 이 안내를 삼키는 자리는 사유 키로 같은 문장을 자기 채널에 낸다 · `differential-test.md` 의 펜스는 resolve-baseline stderr 가 그대로 보인다(그대로 둔다). quality-pipeline 이 그 사유와 안내를 크게 보인다(조용한 fail-open 금지). qg 보호 브랜치 가드(`artifact_branch_guard.sh`)의 고정 목록은 그대로다.

- [ ] **Step 1: 실패하는 테스트.** `test_resolve_baseline.sh`: `origin/HEAD` 없음 + `origin/main` 있음 → `degraded: yes` · `degraded_reason: no-default-branch` · stderr 안내(지금은 `origin/main` 으로 대체해 `no`) · 개명 뒤 dangling `origin/HEAD` → 같은 사유 · `trunk` 기본 → `base: trunk` · `case_degraded_emits_all_keys` 의 키 순서 단언(6키)을 7키로. `test_review_diff.sh`: 「stdout 10줄」 세 자리를 11줄로 · `origin/HEAD` 없는 레포의 session 모드 → stdout `degraded_reason: no-default-branch` · stderr 에 `review-diff: ` 로 시작하는 `set-head` 안내 줄. `check-review-scope.sh` 출력에 `degraded_reason:` 이 실린다.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/quality-gates/tests/test_resolve_baseline.sh; bash plugins/quality-gates/tests/test_review_diff.sh` — Expected: `✗`.
- [ ] **Step 3: 구현.** 대체 `elif` 넷을 지우고 사유 키를 모든 `emit_degraded` 에 인자로. 위 Interfaces 의 소비자 자리를 모두 맞춘다(`git grep -n 'resolve-baseline' -- plugins shared ':!*CHANGELOG*' ':!*/tests/*'` 로 다시 세어 빠진 소비자가 없는지 본다).
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `bash shared/tests/test_test_selection_bundle.sh && bash plugins/spec-distill/tests/test_merge_check.sh` + qg 의 `resolve-topic` · `check-review-scope` · `discover-spec` 테스트 — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `origin/main` 대체 한 줄을 되돌림 → 첫 사례 RED · 사유를 `-` 로 → 사유 사례 RED.
- [ ] **Step 6: 커밋** — `fix(quality-gates): 기준선을 origin/HEAD 하나로 — 못 찾으면 사유와 고치는 법을 보인다`

---

### Task 9: 상태 루트 — 자기 무시 · 추적 파일이면 멈춤 · bare 레포 · 환경 변수 공시 (AC24 · §6)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` (`state_root_for_common` · 새 `ensure_state_root` · `main` 의 `state-root` · `state-root-for` 인자 처리와 `--ensure`), 상태 루트 아래 폴더를 만드는 모든 자리(Step 3 에서 센다 — d0d787e8 기준 후보: `conductor_state.acquire` · `conductor_ledger` 의 `c_review_pack` · `c_resource_dir` · `merge_check.run`(사본 · 줄 폴더) · `suite_lock` 의 잠금 만들기 · `control_plane.save_cache` · `interview_state.py`(옛 세션 기록 자리) · `ledger_sweep.py` · `seed_edit_diff.py` 의 기준 사본 폴더 — spec-distill 에는 훅이 없다(6.0.0)), 문서별 상태 폴더를 처음 만드는 skill 펜스(절차서 선결의 `mkdir -p <state-dir>` 를 도는 펜스 — reviewing-brief · spec-review 는 `state-root-for "<문서 변수>"`, request-framing 은 `## 상태` 의 맨 `state-root`), `tests/test_ledger_root.sh`(`root_lock` 의 RF 양의 짝 `grep -c 'state_path.py" state-root)'` 이 `--ensure` 를 붙인 꼴을 세게)
- Test: `plugins/spec-distill/tests/test_state_root.sh` (새), `tests/test_ledger_root.sh`, `tests/test_state_dir_writes.sh`(세 skill 폴더 펜스), `tests/test_finishing_block_scope.py`(finishing 펜스)

**Interfaces:**
- Produces:
  - `state_root_for_common(common: Path) -> Path` — `common.name == ".git"` 이면 `common.parent / ".claude/spec-distill"`, 아니면 `common / ".claude/spec-distill"`.
  - `class StateRootError(RuntimeError)`; `ensure_state_root(root: Path, cwd: str | None = None) -> list[str]` (알림) — 폴더를 만들고, `.gitignore` 가 없으면 `*` 한 줄로 쓴다(링크면 거부 — 쓰기는 마지막 성분 링크를 따라가지 않는 `O_NOFOLLOW` · `O_EXCL`). 그 뒤 `git -C <공용 git 디렉토리의 부모(본 체크아웃)> check-ignore -q <root>/probe` 가 무시하지 않거나 같은 자리의 `git ls-files -- <root>` 가 비지 않으면 `StateRootError`(「상태 폴더 아래 파일이 이미 추적된다 — git rm --cached -r <루트> 로 추적을 푼 뒤 다시 돈다」). 두 검사는 cwd 에서 돌리지 않는다 — 연결된 worktree 에서 돌리면 상태 루트(본 체크아웃 아래)가 「outside repository」 rc 128 이다(실측; devbrew 의 SDD 가 늘 이 꼴). 상태 루트가 공용 git 디렉토리 안(bare — `common.name != ".git"`)이면 git 이 그 아래를 추적할 수 없으므로 두 검사를 건너뛴다(그 자리도 cwd 에서는 rc 128, 실측); `.gitignore` 는 그대로 쓴다. `GIT_DIR` · `GIT_WORK_TREE` 가 설정돼 있으면 알림 한 줄.
  - CLI `state-root [<cwd>] [--ensure]` · `state-root-for <DOC> [--ensure]` — 「설계에 없던 결정 8」. `state-root-for` 의 `--ensure` 는 `payload_root(DOC)` 로 고른 레포(문서가 사는 레포)의 상태 루트를 보장한다. 모르는 인자 · 남는 인자 → rc 2.
- [ ] **Step 1: 실패하는 테스트**(`test_state_root.sh`): `.gitignore` 가 `.claude/` 를 무시하지 않는 레포에서 `state-root --ensure` 뒤 `git status --porcelain` 이 비었다 · 같은 레포를 cwd 로 두고 다른 레포 B 의 문서로 `state-root-for <B 문서> --ensure` → B 의 상태 루트에 `.gitignore` 가 생기고 cwd 레포에는 생기지 않는다 · `state-root-for <문서> --bogus` · `state-root-for <문서> x` · `state-root --ensure x y` → rc 2(지금은 남는 인자를 조용히 버린다) · `state-root --ensure` 가 `--ensure` 를 cwd 로 읽지 않는다 · 상태 루트 아래 파일을 `git add -f` 로 추적시킨 레포 → rc 3 · stdout 비었음 · 안내 문장(AC29 「상태 루트 아래 추적 파일」) · 같은 부모 폴더의 bare 레포 둘(`a.git` · `b.git`)에 각각 worktree 를 두고 `state-root` 가 서로 다르고 각 bare 안이다 · bare 레포의 worktree 에서 `state-root --ensure` 가 rc 0(추적 검사를 건너뛰고 `.gitignore` 는 쓴다) · 평범한 레포의 **연결된 worktree** 를 cwd 로 `state-root --ensure` 가 rc 0 이고 본 체크아웃의 상태 루트에 `.gitignore` 가 생기며, 본 체크아웃에서 상태 루트 아래 파일을 `git add -f` 로 추적시키면 연결된 worktree 에서도 rc 3 · 평범한 레포는 `<레포>/.claude/spec-distill` 그대로 · `GIT_DIR` 설정 시 알림 · 지휘자 표지 잡기(`conductor_ledger.py claim`)가 추적 파일 레포에서 멈춘다(쓰기 자리가 실제로 부른다는 증인).
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_state_root.sh` — Expected: `✗`.
- [ ] **Step 3: 쓰기 자리를 센다.** `git grep -n -e 'mkdir' -e 'state_root(' -e 'state-root' -- plugins/spec-distill/scripts plugins/spec-distill/skills shared/docreview` 결과에서 상태 루트 아래를 만드는 자리를 이 계획에 목록으로 적고(위 Files 후보와 대조) 각 자리가 `ensure_state_root` 를 부르게 한다. 읽기 자리(상태줄 · `conductor_state.py path/show` · `machine_for` · 경로 도출만 하는 펜스 호출)는 부르지 않는다. skill 펜스에서 `--ensure` 를 붙인 호출은 `ROOT="$(… --ensure)" || ROOT=""` 뒤 `[ -n "$ROOT" ]` 로 멈춘다(`|| true` 로 삼키지 않는다) — 그 펜스는 세 skill 폴더면 `test_state_dir_writes.sh`, finishing 이면 `test_finishing_block_scope.py` 를 함께 돌린다.
  - 센 결과(416e5428 기준). **부른다** — `conductor_ledger.py` 의 `mdir_for_write`(`claim` · `takeover` · `review-pack` 기본 폴더 · `resource-dir`) · `merge_check.run`(사본 · 줄 폴더 · 잠금을 만들기 전) · 원장 열기 펜스 둘(reviewing-brief · spec-review 의 `state-root-for "<문서 변수>" --ensure`) · request-framing `## 상태` 의 `state-root --ensure`(이 블록을 앞에 이어 붙이는 펜스 전부가 같은 보장을 받는다).
  - **부르지 않는다** — `conductor_state.acquire` · `save`(`claim` 이 먼저 보장한 폴더에 쓴다) · `suite_lock.take`(경로만 받는 도구 — 경로는 표지를 잡은 지휘자에게서 오고, `merge_check` 는 먼저 보장한다) · `control_plane.save_cache`(공용 git 디렉토리 아래 `devbrew/` — 상태 루트 밖) · `interview_state.py migrate-legacy`(옮긴 파일은 인터뷰 폴더에 쓴다 — 상태 루트에는 쓰지 않는다) · `ledger_sweep.py`(루트가 없으면 아무것도 하지 않고, 부르는 원장 열기 펜스가 같은 루트를 먼저 보장한다) · `seed_edit_diff.py`(경로만 받는 도구 — `## 상태` 를 이어 붙인 펜스에서만 돈다) · 원장 열기 뒤에 도는 펜스의 `mkdir -p "$STATE_DIR"`(reviewing-brief 번들 · 두 codex 게이트 — 원장 열기가 이미 보장한 루트 아래다) · `finishing.md` 의 두 펜스(이미 있는 원장 자리만 쓴다 — `[ -d "$STATE_DIR" ]`) · 읽기 자리(`conductor_state.py path/show` · `machine_for` · 상태줄).
  - 보장은 상태 루트 경로의 링크(`.claude` · `spec-distill`)도 거부한다 — 원장 열기가 그 너머에 `.gitignore` 를 쓰지 않게(`test_ledger_wiring.sh` A1(iii) 「상태 루트가 링크면 NO_DIR」).
- [ ] **Step 4: 구현 · 통과.** 같은 명령 + `bash plugins/spec-distill/tests/test_ledger_root.sh && bash plugins/spec-distill/tests/test_state_dir_writes.sh && python3 -m unittest plugins/spec-distill/tests/test_finishing_block_scope.py` — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `.gitignore` 쓰기를 지움 → 첫 사례 RED · `ls-files` 검사를 지움 → 추적 사례 RED · bare 규칙을 지움 → bare 사례 RED · `state-root-for` 가 남는 인자를 다시 버리게 → 거부 사례 RED · `--ensure` 를 cwd 레포에 적용 → 다른 레포 문서 사례 RED · 두 검사를 `-C` 없이 cwd 에서 돌리게 → 연결된 worktree 사례 RED · bare 건너뛰기를 지움 → bare `--ensure` 사례 RED. 양성 짝: 평범한 레포 경로 불변 사례가 모두에서 GREEN.
- [ ] **Step 6: Task 0 Step 6 의 실측 결과를 여기 적는다.** `.claude/worktrees/` 에 대한 결론을 한 문단으로 — 하니스 worktree(`QG_WT_ANY_RE` 밖)는 「추적 안 되는 중첩 레포」(리뷰하지 않고 막음), 다른 세션의 qg worktree 는 「이전 qg 실행이 남긴 worktree」(stale · degraded)로 적고, 실측이 이와 다르면 실측대로.
  - 실측(2026-10-21, `.claude/worktrees/` 를 무시하지 않는 임시 레포, 기본 브랜치 `trunk`): 하니스 worktree(`.claude/worktrees/wt`)는 qg `review-diff` 가 「추적 안 되는 중첩 레포 .claude/worktrees/wt/ 는 리뷰하지 않았다」로 막는다(`degraded: yes`, `files:` 가 그 수 — 리뷰하지 못한 항목으로 세어 clean 이 아니다). 다른 세션의 qg worktree(`.claude/quality-gates/worktrees/base-abcd1234`)는 「이전 qg 실행이 남긴 worktree … 는 리뷰하지 않았다 — git worktree remove --force … 로 지운 뒤 다시 돌려라」(stale · `degraded: yes`)다. 기대와 같고, 기대에 없던 사실 하나 — 둘째 줄은 worktree 를 레포 상대 경로가 아니라 물리 절대 경로로 댄다. `.gitignore` 에 `.claude/worktrees/` 한 줄을 더하면 같은 레포가 `degraded: no` 가 된다 — 그래서 Task 11 의 README devbrew 밖 레포 절에 그 한 줄을 싣는다.
- [ ] **Step 7: 커밋** — `fix(spec-distill): 상태 폴더가 스스로를 무시하고 bare 레포마다 갈린다`

---

### Task 10: 작업공간 불변 락 · 읽은 트리 · 회귀 픽스처 (AC27 · AC29 의 계획 1 몫 · §9)

**Files:**
- Create: `plugins/spec-distill/tests/test_workspace_invariance.sh`
- Modify: `plugins/spec-distill/scripts/branch_tip.py` (`tip` 의 알림 줄 — 로컬 · 원격 끝이 다르면 둘 다; 충돌 미리 보기 `c_review_pack` 과 스위트 대조 `merge_check` 가 이미 이 함수를 쓴다), `roadmap_status.py` (보고에 `read_tree`: `기본 브랜치` · `에픽 끝` · `이 작업공간`), `skills/pm-interview/references/finishing.md` (끝 펜스 출력에 「읽은 트리: 이 작업공간」 한 줄), `scripts/check_brief.py` (게이트 출력 머리에 같은 한 줄 — 출력 모양을 잠근 테스트가 있으면 그 기대도), `skills/spec-review/SKILL.md` (경로로 받은 설계문서를 읽는다고 알리는 진입 줄에 같은 꼴)
- Test: 위 새 파일 · `tests/test_check_brief.sh` 에 「읽은 트리」 줄 사례 하나 · `tests/test_finishing_block_scope.py`(finishing 펜스) · `tests/test_state_dir_writes.sh`(spec-review 펜스) · `tests/test_conductor_ledger.py` · `tests/test_merge_check.sh`(Step 4)

- [ ] **Step 1: 락을 쓴다.** 임시 레포 하나 — 기본 브랜치에 로드맵과 `.devbrew.md` 를 먼저 커밋해 둔다(없으면 고친 쪽 worktree 만 「아직 기본 브랜치에 없다」 알림을 내 정당한 차이로 RED — 그 사례는 Task 2 가 잰다). 서로 다른 브랜치의 worktree 둘(한쪽은 로드맵과 `.devbrew.md` 를 고치고 자기 브랜치에 커밋만, 기본 브랜치에는 안 넣음). 두 자리에서 `repo_defaults.py get <키>`(아홉 키 전부) · `conductor_ledger.py roadmaps` · `roadmap_status.py --json <로드맵>` 을 돌려 stdout · stderr 둘 다 바이트까지 같다 — `read_tree` 가 `이 작업공간` 인 칸만 비교에서 뺀다. 양성 대조: 설정이 다른 두 레포는 `get interview_dir` 가 다르다(AC27). AC29 의 계획 1 몫을 이 파일에 모은다: `trunk` 레포 끝에서 끝(상태줄 · 로드맵 찾기 · 인터뷰 끝 커밋 · merge_check 가 맞는 값을 낸다) · 설정 폴더 `plan/…` 레포 · origin 없는 레포(안내와 함께 멈춤) · 기본 브랜치 개명(spec-distill `default-branch` rc 5 · qg `resolve-baseline` 사유 — qg 는 원격과 대조하지 않으므로 `origin/HEAD` 가 dangling 일 때만 사유를 낸다: 픽스처는 원격에서 옛 브랜치를 지우고 `git fetch --prune` 해 dangling 으로 만든 뒤 `degraded_reason: no-default-branch` 를 단언하고, `fetch` 만 한(옛 브랜치가 남은) 개명은 qg 가 옛 기준으로 조용히 풀리는 경우로 이 파일 머리 주석의 한계 한 줄에 적는다) · 상태 루트 아래 추적 파일 · BOM · 같은 키 둘 · 오타 키.
- [ ] **Step 2: 돌린다.** Run: `bash plugins/spec-distill/tests/test_workspace_invariance.sh` — Expected: 앞 과제들이 끝났으면 GREEN. GREEN 이 정답인 락이라 변이로 이빨을 본다.
- [ ] **Step 3: 변이**: `resolve` 가 작업 트리 `.devbrew.md` 를 읽게 → 바이트 비교 RED · `roadmap_status` 가 작업 트리 로드맵을 읽게(`--roadmap-file` 기본) → RED · 비교에서 빼는 칸을 넓혀 전체를 뺌 → 양성 대조가 여전히 다름을 보이는지(공허 확인).
- [ ] **Step 4: 충돌 미리 보기 · 읽은 트리.** `branch_tip.tip` 은 이미 로컬과 원격 추적 ref 를 함께 읽어 앞선 쪽을 고르고 갈라지면 `TipError` 다(#245). 두 끝이 다를 때 내는 알림 줄 둘에 「로컬 끝 <8자> · 원격 끝 <8자>」를 함께 싣는다(지금은 고른 쪽 하나만). 고르는 규칙은 바꾸지 않는다. `test_conductor_ledger.py`(review-pack) · `test_merge_check.sh`(스위트 대조)의 branch_tip 사례에 두 8자가 다 보이는지 한 줄씩 더한다.
- [ ] **Step 5: 커밋** — `test(spec-distill): 작업공간 불변 락과 devbrew 밖 레포 회귀 픽스처`

---

### Task 11: 문서 · 버전 · 스위트 대조 (AC28 마감)

**Files:**
- Modify: `plugins/spec-distill/README.md` (레포 설정 파일 절 · 지원하는 흐름 · 설정 키 표 · 「`branch_prefix` 와 project-init 브랜치 규칙을 맞춘다」 한 줄 · Principles Instantiated 한 줄), `plugins/spec-distill/CHANGELOG.md`, `plugins/spec-distill/.claude-plugin/plugin.json`, `plugins/quality-gates/README.md` (기준선 문장), `plugins/quality-gates/CHANGELOG.md`, `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: README.** spec-distill 의 `## 설정` 에 `.devbrew.md` 예시(아홉 키 · 기본값 · 층마다 받는 키 · 「기본 브랜치에 머지된 판만 읽는다」 · 따옴표 규칙), 지원 흐름(「origin 의 기본 브랜치 · PR 만 본다 — fork 의 부모 레포로 PR 을 내는 흐름 · 원격 없는 로컬 레포는 지원하지 않는다」), devbrew 밖 레포 절(상태 폴더 자기 무시 · Task 9 Step 6 결론). 「한계」 꼴 문장은 이 계획에서 새 절을 만들지 않는다 — README 의 `## 한계` 절은 계획 3 Task 2 가 만들고 그때 `### Principles 흡수` 의 한계 불릿(P21 · P14)을 합친다. 이 계획이 계획 3 보다 뒤에 머지되면 한계 꼴 문장은 그 절에 둔다. Principles Instantiated 에 「CLAUDE.md 레포 전용 값 금지 — 레포 값은 `scripts/repo_defaults.py` 하나가 출처와 함께 낸다」.
- [ ] **Step 2: 버전.** spec-distill · quality-gates 판 올림(번호는 지휘자가 구현 dispatch 때 준 것). CHANGELOG `## [<판>] — <날짜>` 에 Added(설정 파일 · CLI · 상태 폴더 자기 무시) · Changed(기본 브랜치 대체 제거 — 「origin/HEAD 가 없으면 이제 멈춘다: `git remote set-head origin --auto`」) · Fixed(로드맵 후보에 템플릿 · 픽스처 · `--short` 접두 벗기기). Run: `bash shared/tests/test_changelog_integrity.sh` — Expected: GREEN.
- [ ] **Step 3: 전체 스위트 대조.** Task 0 의 `baseline.sh` 로 `after` 를 재고 이름 집합 차를 본다. Expected: 새 실패 0 — 있으면 고치거나 이유를 적는다.
- [ ] **Step 4: 커밋** — `docs(spec-distill): 레포 설정 파일 · 지원 흐름 · 판 올림`
- [ ] **Step 5: 마지막 전체 리뷰에 AC 를 싣는다.** 고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC1~AC12 · AC23b · AC24 · AC27 · AC28 · AC29) 목록을 싣고, AC 마다 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐)로 보고하게 한다. 그 보고를 git 이 추적하지 않는 파일(`$HOME/.claude/sdd-mirror/r8-plan1/ac-report.md`)에 적고, 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린 뒤 PR 전에 `python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-dependency-portability-design.md "$HOME/.claude/sdd-mirror/r8-plan1/ac-report.md" --acs "AC1~AC12 · AC23 · AC24 · AC27~AC29"` 를 돌려 경고를 사용자에게 보인다(`AC23b` 는 도구가 `AC23` 으로 센다 — AC23 의 나머지 몫은 계획 2).
