---
name: dependency-portability
type: design
created_at: 2026-10-20
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R8.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R8 — 의존 선언 · 레포마다 다른 값 · 조용한 오답 · Design

> devbrew 가 devbrew 밖 레포와 여러 작업공간에서도 같은 값을 쓰고, 값이 오류 없이 틀어질 때는 정확성이 걸린 자리에서 멈추며, 나머지는 출처를 보인다 — 장치는 가볍게.

## 목차

- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Anti-goals](#anti-goals)
- [Constraints](#constraints)
- [설계](#설계)
  - [§1 값 해결자 하나](#1-값-해결자-하나)
  - [§2 로드맵 · 인터뷰 폴더](#2-로드맵--인터뷰-폴더)
  - [§3 기본 브랜치 · 원격 · 브랜치 이름](#3-기본-브랜치--원격--브랜치-이름)
  - [§4 머지 판정 — squash · rebase](#4-머지-판정--squash--rebase)
  - [§5 의존 — gh 필수 · 개발 당시 판 · 부재](#5-의존--gh-필수--개발-당시-판--부재)
  - [§6 상태 폴더 · devbrew 밖 레포](#6-상태-폴더--devbrew-밖-레포)
  - [§7 쓰는 세션의 신뢰 — R2a 넘김 넷](#7-쓰는-세션의-신뢰--r2a-넘김-넷)
  - [§8 조용한 오답 — 남긴 것 · 뺀 것](#8-조용한-오답--남긴-것--뺀-것)
  - [§9 작업공간이 여럿일 때](#9-작업공간이-여럿일-때)
  - [§10 위험에 대한 답](#10-위험에-대한-답)
  - [§11 계획 나누기](#11-계획-나누기)
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

묶음 R8 의 의도는 「이 장치들이 devbrew 밖 레포와 superpowers 부재에서도 통하게 한다」였다. 브레인스토밍에서 사용자가 이 방향을 다시 정했다(`## 결정 기록` U1~U7).

- gh 는 기본 의존이다 — 없을 때의 대체 길을 만들지 않는다(U1).
- 호환을 고려하지 않는다. 의존의 최소 판은 그 devbrew 판을 개발 · 검증할 때 쓴 판이다(U2 · U3).
- 장치가 오류 없이 다른 값을 주는 경우를 더 고려한다(U3).
- superpowers 가 없으면 인터뷰는 지금처럼 brief 까지 만들고 멈추고, 나머지 흐름은 진입에서 멈춘다(U6). 묶음 의도 문장의 「superpowers 부재에서도 통하게」는 이 결정으로 바뀐다.
- 과한 장치와 제약(과설계)을 경계한다(U5).

지금 레포에서 확인한 것(origin/main 896fcd71):

- 레포 기본값 모듈 `repo_defaults.py` 는 로드맵 frontmatter 만 읽는다(:44). 로드맵 폴더 · 인터뷰 폴더는 로드맵이 생기기 전에 필요해 이 출처에 담을 수 없고, 여러 파일이 글자로 다시 적는다(`control_plane.py:501,520-552` · request-framing `SKILL.md:178,379-380` · spec-interview `SKILL.md:113` · `finishing.md:525,553-554` · spec-review `SKILL.md:161-162`). machine.md `## 레포 설정`(`merge_check.py:334-376`)은 셋째 출처이고 `test_failure_pattern` 은 해결자를 우회한다(:362).
- 로드맵 목록(`conductor_ledger.py roadmaps`)은 frontmatter `type: roadmap` 만 보고 찾아 템플릿(`templates/roadmap-template.md`)과 테스트 픽스처(`tests/fixtures/conductor-e2e/roadmap.md`)까지 「검사 불가」 후보로 낸다(지휘자 실측).
- 기본 브랜치는 이미 `refs/remotes/origin/HEAD` 하나로 도출한다(`roadmap_model.py:528`, 정의가 하나뿐임을 `test_roadmap_approval.py:133-140` 이 잠근다). 못 찾을 때의 정책이 다섯 갈래로 갈렸다 — 멈춤(`DEFAULT_REF` 사용처 · `finishing.md:541` · qg `resolve-range.sh:110-119`), main/master 로 대체(request-framing `SKILL.md:129-134` · `shared/test-selection/resolve-baseline.sh:64-73`), qg 보호 가드의 고정 목록(`artifact_branch_guard.sh:17-31`).
- GitHub 에서 기본 브랜치를 바꾸면 git 은 기존 `origin/HEAD` 를 고치지 않는다(`fetch.followRemoteHEAD` 기본 `create` — 「An existing symbolic-ref will not be touched」, git-scm.com/docs/git-config, 2026-10-20 확인). 그러면 「기본 브랜치에 직접 커밋하지 않는다」 검사가 진짜 기본 브랜치 위에서 통과한다.
- `finishing.md:541-542` 와 request-framing `SKILL.md:129` 는 `symbolic-ref --short` 결과에서 `origin/` 을 글자로 벗긴다. 로컬에 `origin/main` 이라는 이름의 브랜치가 있으면 결과가 `remotes/origin/main` 이 되어 벗겨지지 않고, 기본 브랜치 검사가 꺼진다.
- 머지됨 자동 판정은 merge commit 문면만 읽는다(`roadmap_status.py:40-61,358-373`). squash · rebase 는 결정 기록의 손 머지 줄로 대신한다(R0 설계 D2.3). gh 를 쓰는 곳은 소유자를 가리지 않는다(`gh pr list --head` — 「"<owner>:<branch>" syntax not supported」, cli.github.com/manual/gh_pr_list). fork 클론에 `upstream` 원격이 있으면 gh 는 묻지 못할 때 부모 레포를 고른다(cli/cli `context/remote.go` remoteNameSortScore).
- 의존 최소 판 선언이 없다(spec-distill `README.md:274` superpowers 「optional」, `:275` qg 「따로 말하지 않는다」, qg `README.md:204` · plugin-audit `README.md:57-61`). 판 확인 코드가 0 이다. 지금 이 지휘 세션은 설치본 spec-distill 7.3.0 으로 도는데 main 은 7.7.0 이다 — 옛 코드는 새 키를 모르는 키로 버리고 기본값을 쓴다.
- `.claude/` 가 git-ignore 된다는 가정이 상태 루트(`state_path.py:65-91`) · merge-check 사본(`merge_check.py:382`) · `WORKTREE_HOME` 에 있다. devbrew 의 `.gitignore:214-220` 만 이를 보장한다.
- R2a 가 넘긴 넷(엔진 밖 원장 쓰기 · 스냅숏 칸 · `--quote` 출처 · 제목 하나 빠진 audit)은 모두 「쓰는 세션 = 제약 대상」 축이다(R2a 설계 `## 미룸` :429-432, 측정 `boundary-measure.md` — 훅 · 권한 · 파일 모드 모두 셸 쓰기를 막지 못했다).

## Goals

- G1 레포마다 다른 값(폴더 · 원격 · 브랜치 접두 · 테스트 명령 등)을 해결자 하나가 출처와 함께 낸다. 어느 작업공간에서 불러도 같은 답이다.
- G2 커밋 범위 · 기본 브랜치 · 머지됨처럼 정확성이 걸린 값은 오류 없이 틀어질 때 멈춘다. 나머지는 출처와 나이를 보인다.
- G3 squash · rebase 로 머지한 레포에서도 머지됨을 자동으로 판정한다.
- G4 의존(git · gh · Claude Code · superpowers · qg)을 개발 당시 판으로 선언하고 진입에서 확인한다. gh 와 superpowers 가 없을 때의 동작이 정해져 있다.
- G5 devbrew 밖 레포(`.claude/` 를 무시하지 않는 레포 · 기본 브랜치가 `main` 이 아닌 레포 · fork 클론)에서 돈다.
- G6 쓰는 세션을 믿는 한계를 정직하게 알리고, 정직한 실수는 값싼 대조로 잡는다.

## Non-goals

- 규칙 문서(CLAUDE.md · 철학 문서)를 고치는 일 — R9.
- superpowers 의 파일 · 동작을 고치는 일(C25 · C35 · D26).
- 옛 판을 위한 호환 코드 · 대체 길(U2).
- qg 판정 상태의 위치(R12 #18).
- 셸이 원장을 쓰는 길을 레포 안에서 막는 일(§7 — 레포 밖 몫).

## Anti-goals

- 조용한 오답 후보마다 멈춤 장치를 다는 것 — 실제로 일어날 법하고 피해가 큰 자리만 멈춘다(§8).
- 쓰기 · 고치기만 막는 부분 훅(B17 — 막는다는 믿음만 준다).
- 인용마다 「출처 미확인」 라벨을 다는 것(늘 붙으면 풍경이 된다).
- 사용자가 관리해야 할 설정 · 키 · 상주 프로세스를 늘리는 것. 새 설정 파일은 하나이고 없어도 된다.
- 있는 것(`repo_defaults` · `DEFAULT_REF` · `test_repo_literals.sh` · 스냅숏 명령)을 다시 만드는 것(C32).

## Constraints

- C25 · C35 · D26 — 외부 플러그인은 건드리지 않고 devbrew 쪽(넘길 때 보내는 글 · 돌아온 결과 검사)만 바꾼다.
- C30 — devbrew 만 생각하지 않는다(다른 레포에서도 쓴다).
- C32 — 원래 있는 것을 다시 만들지 않는다.
- D21 — 묶음의 위험(RC78 · RC82 · RC83 · K11)에 설계가 답한다(§10).
- CLAUDE.md — 기본값과 판단 · 레포 전용 값 금지 · 상류 · 하류 연계 · 진입점에서 따라 내려가기 · 있는 것 먼저 · 모든 훅에 kill switch · 처분 줄 · 마크다운 상태.
- 셸 펜스는 macOS bash 3.2 에서 돈다.
- 레포 경로 예약: 이 에픽은 R10 계획 3(진입 이름 `pm-interview`)이 머지된 뒤 새 이름 자리에서 구현한다(§11).

## 설계

### §1 값 해결자 하나

`repo_defaults.py` 가 레포마다 다른 값을 내는 유일한 해결자다. 새 모듈을 만들지 않는다.

- **출처 넷, 우선순위 순.** ① 로드맵 frontmatter(그 로드맵에만) ② 레포 설정 파일 ③ 기계 상태(machine.md `## 레포 설정` — 지휘자가 찾았지만 아직 레포 설정 파일로 머지하지 못한 임시값, 출처 표시 `기계 상태(임시)`) ④ 상수. 레포 설정 파일은 레포 루트의 `.devbrew.md` 하나이고(지휘자 판단 — 이름은 계획이 바꿀 수 있다), frontmatter 만 읽는다. 없어도 된다. 기계 상태 층을 쓰면 지휘자가 그 값을 레포 설정 파일에 올리자고 알린다.
- **층마다 받는 키가 다르다.** 로드맵을 찾기 전에 필요한 값(`roadmaps_dir` · `interview_dir` · `branch_prefix`)은 로드맵 층에서 받지 않는다(적으면 오류). 기계 상태 층은 `test_command` · `test_failure_pattern` 만 받는다.
- **레포 설정 파일은 기본 브랜치 판에서 읽는다.** `git show <기본 ref>:.devbrew.md`. 작업 브랜치가 자기 검사 범위를 스스로 바꾸지 못하게 하고(Renovate 가 기본 브랜치의 설정을 읽는 것과 같다), 어느 작업공간에서 불러도 같은 값이 나오게 한다. 작업 트리에는 있고 기본 브랜치에는 없으면 「아직 기본 브랜치에 없다 — 기본값을 쓴다」를 알린다(첫 도입 PR).
- **키는 닫힌 집합이다.** `specs_dir` · `plans_dir` · `roadmaps_dir` · `interview_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default` · `branch_prefix`. 모르는 키 · 같은 키 둘 · 값 안의 `#` · 앞뒤 공백 꼴은 오류로 멈춘다. 「frontmatter 를 못 읽음」(BOM · 닫히지 않음 · `--- ` 뒤 공백)은 「키 없음」과 다른 오류다. 폴더 키는 지금처럼 레포 상대경로만 받고 루트 · `.git` 아래를 금지한다.
- **값마다 출처를 낸다.** 결과는 `(값, 출처)` 이고 출처는 `로드맵` · `레포 설정@<커밋 8자>` · `기계 상태(임시)` · `기본값` 이다. 상태줄 · 지휘자 보고 · merge_check 출력이 출처를 보인다.
- **셸 펜스에는 값이 아니라 검사를 넘긴다.** 경로를 조립해 `git add` 범위를 정하는 펜스는 `repo_defaults.py check-path <키> <경로>` 같은 판정 명령을 부르고 rc 로 받는다. 값을 꼭 받아야 하는 펜스는 `get <키>` 의 rc 를 확인하고 빈 값을 거부한다(`$(...)` 의 빈 값이 레포 루트가 되는 사고를 막는다).
- **흡수.** machine.md `## 레포 설정`(merge_check 의 셋째 층)과 `test_failure_pattern` 을 같은 해결자로 옮긴다. 같은 키가 여러 층에 있을 때의 규칙은 위 우선순위 하나이고, 한 층 안에서 같은 키가 둘이면 오류다(지금 frontmatter 는 첫 값, machine.md 는 마지막 값이 이겨 규칙이 반대다).
- 상태 폴더 `.claude/spec-distill` 은 플러그인 namespace 라 설정 키가 아니다.

### §2 로드맵 · 인터뷰 폴더

- **로드맵 찾기 = 정해진 폴더 안 + 표지.** `roadmaps_dir` 아래이고 frontmatter `type: roadmap` 인 파일만 로드맵이다. 찾는 함수 하나를 `control_plane.py` · `conductor_ledger.py roadmaps` · 끝내기 펜스가 함께 쓴다. 폴더는 범위, 표지는 신원이다. 템플릿 · 픽스처가 후보로 잡히던 결함이 닫힌다.
- **끝내기 펜스의 폴더 검사는 정확성 게이트로 남는다.** `finishing.md` 의 부모 폴더 검사는 `git add -- "$RDIR"` 범위를 묶는 유일한 장치다. 위치는 `roadmaps_dir` 에서 얻는다. 설정 폴더가 기본 브랜치 트리에 «없음»과 «비어 있음»을 가르고, 대소문자만 다른 경로(대소문자 무시 파일시스템)는 멈춘다.
- **인터뷰 폴더**는 `state_path.py` 의 `INTERVIEW_DIR` 상수 + `interview_dir` 설정으로 한 곳에서 얻는다. 다시 적은 자리(control_plane · request-framing · 인터뷰 skill)는 해결자를 부른다.
- **spec-review 후보 목록**은 `specs_dir` 을 읽는다(지금 고정 glob).
- 머리말을 못 읽은 후보는 조용히 빼지 않고 「검사 불가」로 센다.

### §3 기본 브랜치 · 원격 · 브랜치 이름

- **지원하는 흐름은 내 레포 안 흐름이다(U8).** PR 과 기본 브랜치는 언제나 `origin` 이다. fork 클론에 `upstream` 원격이 있어도 devbrew 는 `origin` 만 본다. 부모 레포로 PR 을 내는 흐름 · 원격이 없는 로컬 전용 레포는 지원하지 않고 README 에 적는다. 원격 이름 설정 키는 두지 않는다.
- **기본 브랜치는 `DEFAULT_REF`(`refs/remotes/origin/HEAD`) 하나.** main/master 로 대신 쓰는 길(request-framing · `resolve-baseline.sh`)을 지운다. qg 보호 브랜치 가드의 고정 목록은 보안 게이트라 그대로 둔다.
- **못 찾으면 멈추고 고치는 법을 보인다.** 기본 브랜치가 실제로 필요한 자리(request-framing 의 브랜치 만들기 · 인터뷰 끝 커밋 · 지휘자 · merge_check · 상태줄)에서만 멈춘다. 안내는 `origin` 이 없으면 원격을 더하라는 것, 있으면 `git remote set-head origin --auto` 다(`git fetch` 로는 이미 있는 옛 값이 고쳐지지 않는다).
- **두 출처 대조.** 네트워크를 써도 되는 진입(지휘자 진입 · merge_check · 인터뷰 끝 커밋 직전)에서 `git ls-remote --symref origin HEAD` 와 로컬 값을 대조하고 다르면 멈춘다. 상태줄은 네트워크를 쓰지 않고 「기본 브랜치 <이름> · 마지막 받기 N시간 전(어느 원격 · 브랜치든)」만 보인다.
- **전체 참조 이름으로 다룬다.** `refs/remotes/origin/` 접두를 벗겨 짧은 이름을 얻는다. `--short` 결과에서 `origin/` 을 글자로 벗기는 두 자리를 고친다.
- **브랜치 접두**는 `branch_prefix` 설정(기본 `feature/`) 하나다. spec-distill 은 project-init 의 `branch-strategy.md` 를 읽지 않는다(선언 없는 플러그인 간 결합을 만들지 않는다). 브랜치 이름은 이미 분해 표 → 로드맵 `브랜치:` 로 사용자 승인을 거친다.
- **RC82(project-init 훅).** 훅의 정규식은 `worktree add -b` · `branch -m` · `git -C` · `checkout -B` · `switch --create` · 네이티브 EnterWorktree 를 보지 못한다. 정규식을 늘리지 않고, 실행 뒤 `git for-each-ref refs/heads` 로 새로 생긴 브랜치 이름을 관찰해 규칙에 맞지 않으면 알린다(공시, 막지 않음 — 훅은 조언자다). 규칙 파일은 작업 트리가 아니라 기본 브랜치 판에서 읽는다.

### §4 머지 판정 — squash · rebase

gh 가 필수라서 머지됨을 PR 상태로 판정한다. merge commit 문면 판독은 gh 판정의 보조로만 남는다.

- **에픽 브랜치가 머지됨** = `origin` 레포의 gh PR 이 MERGED ∧ `baseRefName` 이 기본 브랜치 ∧ `headRefName` 이 그 브랜치 ∧ `headRefOid` 가 브랜치 끝과 **같다** ∧ `mergeCommit` 이 기본 ref 에서 닿는다. 다섯이 모두 맞을 때만 「머지됨」이다.
  - 브랜치 끝은 원격 추적 ref(`refs/remotes/origin/<브랜치>`), 없으면 로컬 브랜치다. 머지 뒤 커밋이 더 붙으면 끝이 달라 머지됨이 아니다(지금 `roadmap_status.merged_by` 와 같은 방향).
  - 브랜치가 지워져 끝이 없으면 machine.md 에 적어 둔 그 PR 의 `headRefOid` 와 대조하고, 그것도 없으면 나머지 넷으로 판정하되 「브랜치 끝 없이 판정」을 알린다.
  - 같은 이름을 다시 쓴 브랜치의 옛 PR · 남의 fork 에서 온 같은 이름 PR 은 `headRefOid` 가 달라 걸러진다.
  - gh 는 MERGED 인데 기본 ref 에 아직 없으면 「머지됨(받기 전)」으로 알린다. 머지 뒤 revert 는 알리기만 한다.
- **gh 호출마다 대상 레포를 명시한다.** `-R <owner/repo>` 를 `origin` URL 에서 도출한다(fork 클론의 `upstream` 을 gh 가 고르는 일을 막는다). `GH_REPO` · `GH_HOST` 가 설정돼 있으면 알린다.
- **상태줄은 캐시를 읽는다.** 상태줄은 네트워크를 쓰지 않는다. 지휘자가 gh 로 읽은 PR 상태를 machine.md 에 `받은 시각 · headRefOid · 쓴 세션` 과 함께 적고, 상태줄은 그 나이를 보인다. 머지 · 다음 에픽 착수 같은 게이트는 캐시를 읽지 않고 새로 묻는다.
- 결정 기록의 손 머지 줄은 PR 없이 로컬에서 머지한 경우를 위해 남는다.

### §5 의존 — gh 필수 · 개발 당시 판 · 부재

- **선언.** 플러그인마다 자기 의존 목록을 한 파일에 둔다(이름 · 최소 판 · 잰 날짜 · 없을 때 동작). README prerequisites 는 그 파일을 가리킨다. 최소 판은 그 플러그인 판을 개발 · 검증할 때 실제로 깔려 있던 판이다(U3). 판을 재는 작은 명령이 git · gh · Claude Code · superpowers 의 판을 재서 이 파일을 갱신한다 — 손으로 적지 않는다.
- **진입 확인.** 공유 진입 사전 검사(`shared/entry/entry_preflight.py`)는 그대로 둔다(늘 rc 0 · 감시줄 하나). 의존 확인은 플러그인마다 자기 스크립트가 하고, 그 의존을 실제로 쓰는 진입만 부른다. 판 문자열에서 숫자 셋만 뽑아 정수로 비교하고(`2.54.0 (Apple Git-157)` · `2.47.1.windows.2` · gh 의 두 줄 출력), 못 뽑으면 멈춘다. 최소 판보다 낮으면 이유와 업데이트 방법을 보이고 멈춘다.
- **gh 필수.** gh 를 쓰는 진입(지휘자 · merge_check · 분해 뒤 로드맵 흐름 · qg 의 PR 댓글)은 gh 가 없으면 이유와 설치 방법을 보이고 멈춘다. 인증은 첫 gh 호출이 실패할 때 「`gh auth login` 하라」를 보이고 멈춘다 — 진입마다 네트워크로 인증을 묻지 않는다(오프라인 인터뷰를 막지 않는다). gh 를 쓰지 않는 진입(인터뷰 · request-framing · plugin-audit · project-init)은 gh 를 보지 않는다. gh 없을 때의 대체 길(`conductor_ledger.py:465-490,858` · `control_plane.py:763-863` · qg `discover-spec.sh:185` · `publish-comment.sh:43`)은 지운다.
- **실행 중인 코드의 판.** 플러그인 자기 판은 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 에서 읽는다(설치 기록 파일을 추론하지 않는다). 기계 상태(machine.md)를 쓰는 쪽은 자기 판을 찍고, 읽는 쪽 판이 그보다 낮으면 멈춰 「플러그인을 업데이트하라」를 보인다. 설치된 판과 레포 판이 다른 지휘 세션(지금 이 세션)이 조용히 옛 동작을 내는 것을 막는다.
- **superpowers 판.** Claude Code 의 plugin.json `dependencies` 는 쓰지 않는다 — 의존이 없거나 판이 맞지 않으면 플러그인 전체를 끄기 때문에(code.claude.com/docs/en/plugins/dependencies, 2026-10-20) U6 의 「없어도 인터뷰는 brief 까지」가 깨진다. superpowers 를 부르는 자리(인터뷰 끝 · 지휘자)의 모델이 불러온 skill 의 기준 폴더 경로(`…/superpowers/<판>/skills/…`)에서 판을 읽어 의존 목록 파일의 판과 비교하고, 다르면 알린다(멈추지 않음). 읽지 못하면 「superpowers 판을 확인하지 못했다」를 알린다.
- **superpowers 가 없을 때(U6).** 인터뷰는 지금처럼 brief 까지 만들고 크게 알린 뒤 멈춘다(`finishing.md` B-1 의 단독 완결 그대로). 지휘자 · 로드맵 흐름(epic-conductor · 분해 뒤 다음 단계)은 진입에서 「superpowers 가 필요하다」와 설치 방법을 보이고 멈춘다. 새 대체 길은 없다. 있는지는 지금처럼 모델이 skill 목록으로 판단한다.
- **qg 가 없을 때.** 선택 의존이다. 지휘자 걸음 7 은 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 진행한다.
- **K11(외부 문구 변화).** 개발 당시 판 기록 + 진입 확인으로 「설치된 superpowers 가 검증한 판과 다르다」를 알린다. 마지막 그물은 이미 있는 돌아온 결과 대조(R3)다. 문구 비교 장치는 만들지 않는다.

### §6 상태 폴더 · devbrew 밖 레포

- **상태 루트가 스스로를 무시한다.** 상태 루트를 처음 만들 때 그 안에 `*` 한 줄짜리 `.gitignore` 를 둔다(선례: plugin-audit `prepare-run-dir.py:72` — 다른 플러그인이라 같은 플러그인 안에 둔다). 만든 뒤 `git check-ignore` 탐침과 `git ls-files -- <상태 루트>` 가 비어 있는지 확인한다. 이미 추적되는 파일이 있으면 멈춘다(무시 목록은 추적 중인 파일을 빼지 못한다).
- merge-check 사본 · 지휘자 상태는 상태 루트 아래라 같이 덮인다. `.claude/worktrees/` 는 하니스 폴더라 손대지 않고, 레포가 그것을 무시하지 않으면 qg 가 「추적 안 되는 중첩 레포」로 잡는지 계획 단계에서 실측한다(PR #234 넘김).
- `GIT_DIR` · `GIT_WORK_TREE` 가 설정돼 있으면 알린다.
- **RC78(brief 게이트 타입).** `check_brief.py` 가 `type: interview-brief` 만 받는 것은 그대로 둔다. 이 타입은 devbrew 가 만드는 산출물의 이름이지 레포마다 다른 값이 아니다. 에픽 묶음은 이미 `spec_review_bundle.py` 가 따로 받는다.

### §7 쓰는 세션의 신뢰 — R2a 넘김 넷

같은 세션이 원장을 쓰고 원장의 제약을 받는다. 샌드박스는 기본으로 꺼져 있고 플러그인이 켤 수 없으며, 리뷰 엔진도 Bash 로 돌아 함께 막힌다. 훅이 사용자 답을 기록해도 그 파일을 셸이 쓸 수 있다(code.claude.com/docs/en/sandboxing · hooks, 2026-10-20). 이 위험(모델이 자기 세션에서 자기 기록을 위조)에 그 장치들은 과설계다(U5). 원장이 지키는 것은 정직한 실수와 흐름 이탈이고, 그것은 요약값 대조(AC17 나) · 한 줄 계약이 이미 잡는다.

- **스냅숏 대조(정확성).** `begin-round` 가 넘겨받는 스냅숏 칸(해시 · 제목 · 부모 · 앵커)을 엔진이 문서에서 다시 계산하고(`docreview_anchor.py snapshot` 재사용), 다르면 거부한다. 위조뿐 아니라 정직한 실수도 잡는다. 원장에 저장된 스냅숏을 셸로 다시 쓰는 길은 아래 공시에 든다.
- **공시 두 자리.** 리뷰 결과 머리에 한 줄: 「사용자 문구와 원장은 이 세션이 쓴 것이다 — 엔진은 엔진 밖에서 고친 원장 중 요약값이 안 맞는 것만 잡는다」. README 「한계」 절에 같은 문장. 인용마다 라벨은 달지 않는다.
- **엔진 밖 원장 쓰기(AC17 가).** 레포 안에서 닫지 않는다. 받는 곳은 레포 밖(사용자 · 관리 설정의 샌드박스)이고 README 에 「샌드박스를 쓰는 사용자는 원장 폴더 쓰기를 막을 수 있다」를 안내로만 적는다.
- `--quote-file` · `log-decision --quote` · `decide --quote` 출처와 제목 하나 빠진 audit(B16)은 위 공시로 처리한다.

### §8 조용한 오답 — 남긴 것 · 뺀 것

조사한 경우(R8 설계 입력 조사, 지휘 세션 레포 밖 기록)를 과설계 경계로 걸렀다. 멈춤은 커밋 범위 · 기본 브랜치 · 머지됨 · 판 비교에만 둔다.

| 경우 | 처분 | 자리 |
|---|---|---|
| fork 클론에서 gh 가 부모 레포를 봄 · `GH_REPO` | `-R origin` 명시 + 환경 변수 공시 | §4 |
| 기본 브랜치 개명 뒤 옛 `origin/HEAD` | 멈춤(두 출처) | §3 |
| 남의 fork · 재사용 이름 · stacked PR 의 거짓 「머지됨」 | 다섯 조건(`headRefOid` = 끝) | §4 |
| `--short` 접두 벗기기로 기본 브랜치 검사가 꺼짐 | 고침(전체 이름) | §3 |
| 펜스 `$(...)` 빈 값이 레포 루트가 됨 | 멈춤(검사를 넘김) | §1 |
| 모르는 키 · 같은 키 둘 · 못 읽는 머리말 | 멈춤 | §1 |
| 판 문자열 파싱 · 실행 코드 판 ≠ 기록 판 | 멈춤 | §5 |
| 상태 루트 아래 이미 추적되는 파일 | 멈춤 | §6 |
| 대소문자만 다른 폴더 · 폴더 없음 vs 빔 | 멈춤 | §2 |
| 설정 파일이 기본 브랜치에 아직 없음 | 출처 공시 | §1 |
| fetch 안 함 · 받은 시각이 다른 원격 것 | 출처 · 나이 공시 | §3 |
| PR 캐시가 낡음 | 나이 공시(게이트는 안 읽음) | §4 |
| 로컬 브랜치 끝 ≠ 원격 끝 | 둘 다 공시 | §9 |
| 새 브랜치 이름이 규칙 밖 | 공시 | §3 |
| `GIT_DIR` · `GIT_WORK_TREE` 상속 | 공시 | §6 |
| 설정 · 로드맵 파일이 심볼릭 링크 blob | 뺌 — 해결자가 일반 파일만 읽는 한 줄 확인으로 충분, 별도 장치 없음 | §1 |
| `claude --version` ≠ 실행 중인 판 | 뺌 — 플러그인 자기 판으로 판정하고 Claude Code 판은 기록만 | §5 |
| bare 레포 + worktree 배치의 상태 루트 | 뺌 — 계획 단계 실측 픽스처 하나로 확인만 | §9 |

### §9 작업공간이 여럿일 때

- 값의 출처(기본 브랜치 판 · 공용 git 디렉토리의 상태 루트)는 작업공간과 무관하다 — `merge_check` · `roadmap_status` · `control_plane` 이 이미 기본 커밋에서 읽고, 상태 루트는 `--git-common-dir` 에서 얻는다.
- 지금 작업공간 기준으로 읽는 자리는 의도된 것만 남기고 표시한다: 인터뷰 끝 펜스 · `check_brief` · 경로로 넘긴 설계문서. 출력에 「읽은 트리」(기본 브랜치 / 에픽 끝 / 이 작업공간)를 밝힌다.
- 충돌 미리 보기의 브랜치 끝(`conductor_ledger.py:500`)이 로컬과 원격에서 다르면 둘 다 보인다.
- **작업공간 불변 락.** 임시 레포 하나에 서로 다른 브랜치의 작업공간 둘을 두고(한쪽은 로드맵 · 설정 파일을 고침) `repo_defaults get *` · 로드맵 찾기 · `roadmap_status --json` 을 돌려 출력이 바이트까지 같아야 한다(「읽은 트리」가 이 작업공간인 칸만 예외).

### §10 위험에 대한 답

- RC78 — §6: 그대로 둔다(타입은 devbrew 산출물 이름).
- RC82 — §3: 사후 관찰로 알린다.
- RC83 — §5: 의존 목록 파일 · 개발 당시 판 · 진입 확인.
- K11 — §5: 판 기록 + 진입 공시 + R3 돌아온 결과 대조.

### §11 계획 나누기

이 에픽은 R10 계획 3(`spec-interview` → `pm-interview`)이 머지된 뒤 구현한다 — 인터뷰 skill · request-framing 을 같이 고친다. R12 와는 `shared/docreview` 를 같이 고칠 수 있어(§7) 계획 3을 R12 머지 뒤에 둔다.

- 계획 1 — 값 해결자 · 폴더 · 기본 브랜치 · 상태 폴더 · 작업공간 불변 락(§1 · §2 · §3 앞 다섯 불릿 · §6 · §9).
- 계획 2 — gh 필수 · 머지 판정 · 의존 선언 · 판 확인 · superpowers · qg 부재 · K11(§4 · §5) + RC82(§3 끝 불릿, project-init).
- 계획 3 — 쓰는 세션의 신뢰(§7, shared/docreview).

계획 담당자가 일의 모양을 보고 다르게 나눌 수 있다 — 이유를 계획에 적는다.

## 있는 것 검토

- 레포 안: `repo_defaults.py`(해결자) · `DEFAULT_REF` · `NO_DEFAULT`(`roadmap_model.py:528-529`) · `test_repo_literals.sh`(박힌 값 락 — 대상만 넓힌다) · `conductor_ledger.c_roadmaps`(표지 찾기) · `state_path.INTERVIEW_DIR` · `docreview_anchor.py snapshot` · `_digest` · `ERA_FILE` · `LedgerCorrupt` · `seed_review_log.py` 머리의 「한계」 문단 · plugin-audit `prepare-run-dir.py:72`(자기 무시) · `check-staleness.py:327`(설치 판 — 함정 때문에 판정에 쓰지 않음) · `merge_check.py:348-351`(fetch 실패 공시) · `control_plane.fetch_stamp`.
- 레포 밖: Claude Code plugin.json `dependencies`(실측 뒤 사용) · git `remote set-head --auto` · `ls-remote --symref` · gh `-R` · `--json` 필드 · Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다.
- 기각: Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다 — code.claude.com/docs/en/plugins-reference · settings-reference) · `.claude/<plugin>.local.md`(git-ignored 라 새 작업공간에 없다) · 샌드박스 · 훅 출처 · 별도 프로세스(§7).

## 상류 · 하류 연계

- 받는 곳: 묶음 R8.md · R5 설계 `## 미룸` R8 행 · R2a 설계 `## 미룸` R8 행 다섯(:417 · :429-432) · R11 설계 §5 R8 행 · R0 설계 D2.3(squash · rebase) · R5 계획 3 Ruling R27(`resolve-baseline.sh` · control_plane 박힌 값) · PR #231 넘김(`log-decision --quote`) · PR #234 넘김(`.claude/` 무시 안 되는 레포) · R2a 계획 4 결정 6(worktree 로 만든 브랜치 이름) · R10 설계 넘기는 곳(진입 이름 → R8) · 이 세션의 사용자 결정 U1~U7.
- 넘기는 곳: 해결자(→ 모든 spec-distill 스크립트 · skill 펜스 · 상태줄) · 머지됨 판정(→ 상태 계산 · 지휘자 걸음 1 · 6) · 의존 확인(→ 모든 진입) · 공시 문장(→ 리뷰 결과 · README) · CLAUDE.md 규칙 문장(→ R9, `## 미룸`).
- 되돌아오는 길: 계획 · 구현에서 이 설계를 다시 나눌 근거가 보이면 재분해 신호로 지휘 세션에 보고한다(`references/redecompose.md`).
- 같은 상태를 읽는 다른 표면: 상태줄(`control_plane.py`) · `roadmap_status.py` · `conductor_ledger.py` · `merge_check.py` · 인터뷰 끝 펜스 · request-framing · spec-review 후보 목록 · qg(gh · 기본 브랜치) · project-init 훅. 이음매 담당은 이 에픽.

## Acceptance Criteria

**값 해결자(§1)**
- AC1 `repo_defaults` 가 세 출처(로드맵 · 레포 설정 파일@기본 브랜치 · 상수)를 우선순위대로 합치고 값마다 출처를 낸다. 레포 설정 파일은 작업 트리가 아니라 기본 ref 판에서 읽는다.
- AC2 모르는 키 · 같은 키 둘 · 값 안의 `#` · 못 읽는 머리말은 각각 다른 오류로 멈춘다. 「키 없음」은 기본값이다.
- AC3 작업 트리에만 있는 레포 설정 파일은 「아직 기본 브랜치에 없다」를 알리고 기본값을 쓴다.
- AC4 `get` · `check-path` 명령이 있고, 경로로 `git add` 범위를 정하는 펜스는 `check-path` 의 rc 로 판정한다. `get` 을 쓰는 펜스는 rc 를 확인하고 빈 값을 거부한다(박힌 값 락이 이 꼴을 잰다).
- AC5 machine.md `## 레포 설정` 과 `test_failure_pattern` 이 같은 해결자를 지난다.

**폴더(§2)**
- AC6 로드맵 찾기 함수 하나를 상태줄 · 로드맵 목록 · 끝내기 펜스가 쓰고, 템플릿 · 픽스처는 후보가 아니다.
- AC7 끝내기 펜스의 폴더 검사가 `roadmaps_dir` 기준이고, 폴더 없음 · 빈 폴더 · 대소문자만 다른 경로를 가른다.
- AC8 인터뷰 폴더 · 설계문서 폴더를 글자로 다시 적는 자리가 없다(박힌 값 락의 대상이 넓어진다).

**기본 브랜치 · 원격(§3)**
- AC9 main/master 대체가 없고(qg 보호 가드 제외), 못 찾으면 `git remote set-head <원격> --auto` 를 안내하며 멈춘다.
- AC10 네트워크 진입 셋에서 `ls-remote --symref` 와 로컬 기본 ref 가 다르면 멈춘다.
- AC11 기본 브랜치 짧은 이름을 전체 참조 이름에서 얻는다 — 로컬 브랜치 `origin/main` 이 있어도 기본 브랜치 검사가 켜져 있다.
- AC12 브랜치 접두가 설정에서 오고, 글자 `origin/main` · `feature/roadmap-` 를 잠그던 락이 「도출하는가」 락으로 바뀐다.
- AC13 project-init 훅이 실행 뒤 새 브랜치 이름을 관찰해 규칙 밖이면 알린다(`worktree add -b` · `branch -m` 포함). 규칙 파일은 기본 브랜치 판에서 읽는다. kill switch 를 존중한다.

**머지 판정(§4)**
- AC14 squash · rebase 로 머지한 에픽이 손 머지 줄 없이 「머지됨」이다.
- AC15 남의 fork 에서 온 같은 이름 PR · 재사용한 브랜치 이름의 옛 MERGED PR · 기본 브랜치가 아닌 base 로 머지된 PR · 머지 뒤 커밋이 더 붙은 브랜치는 「머지됨」이 아니다. 지워진 브랜치는 적어 둔 `headRefOid` 로 판정하거나 「브랜치 끝 없이 판정」을 알린다.
- AC16 모든 gh 호출이 `origin` 에서 도출한 `-R` 을 쓰고, `GH_REPO` · `GH_HOST` 가 설정돼 있으면 알린다. `upstream` 원격이 있는 fork 클론에서도 `origin` 의 PR 만 본다.
- AC17 상태줄은 네트워크 없이 캐시와 그 나이를 보이고, 게이트는 캐시를 읽지 않는다.

**의존(§5)**
- AC18 플러그인마다 의존 목록 파일(이름 · 최소 판 · 잰 날짜 · 없을 때)이 있고, 판을 재는 명령이 그것을 갱신한다.
- AC19 진입이 git · gh 판을 숫자 셋으로 비교하고, 못 뽑거나 낮으면 멈춘다.
- AC20 gh 가 없거나 인증되지 않았으면 진입에서 멈추고, gh 없을 때의 대체 길이 코드에 없다.
- AC21 machine.md 를 쓰는 쪽이 자기 판을 찍고, 낮은 판의 읽는 쪽은 멈춰 업데이트를 안내한다.
- AC22 superpowers 가 없으면 인터뷰는 brief 까지 만들고 멈추고(현행), 지휘자 · 로드맵 흐름은 진입에서 멈춘다. qg 가 없으면 지휘자가 품질 게이트 없이 간다고 알리고 진행한다.
- AC23 superpowers 를 부르는 자리가 불러온 skill 의 기준 폴더 경로에서 판을 읽어 의존 목록의 판과 다르면 알리고, 읽지 못하면 「superpowers 판을 확인하지 못했다」를 알린다(멈추지 않음). plugin.json `dependencies` 에 superpowers 를 올리지 않는다.
- AC23a gh 를 쓰는 진입만 gh 를 확인하고, 인증 실패는 첫 gh 호출에서 로그인 안내와 함께 멈춘다. gh 를 쓰지 않는 진입은 gh 가 없어도 돈다.
- AC23b 레포 설정의 층별 허용 키가 지켜진다 — 로드맵 층의 `roadmaps_dir` · `interview_dir` · `branch_prefix` 와 기계 상태 층의 다른 키는 오류다.

**상태 폴더(§6)**
- AC24 상태 루트가 자기 `.gitignore` 를 갖고, 추적 중인 파일이 있으면 멈춘다.

**쓰는 세션(§7)**
- AC25 `begin-round` 가 넘겨받은 스냅숏을 다시 계산해 다르면 거부한다.
- AC26 리뷰 결과 머리 한 줄 · README 「한계」 절이 같은 문장으로 있고, 인용마다 라벨은 없다.

**작업공간 · 공통(§9)**
- AC27 작업공간 불변 락이 있고 양성 대조(설정이 다른 두 레포는 다른 답)를 가진다.
- AC28 바뀐 동작마다 락이 있고 변이로 이빨을 확인했다. 음의 락에는 양의 짝이 있다.
- AC29 회귀 픽스처: 기본 브랜치가 `trunk` 인 레포 · 설정 폴더가 다른 레포(`plan/…`) · upstream 원격이 있는 fork(origin 의 PR 만 본다) · origin 이 없는 레포(안내와 함께 멈춤) · 기본 브랜치 개명 뒤 · 상태 루트 아래 추적 파일 · BOM · 같은 키 둘 · 오타 키 · `-suffix` 판 문자열.

## Files to Modify

- `plugins/spec-distill/scripts/repo_defaults.py` · `roadmap_model.py` · `roadmap_status.py` · `control_plane.py` · `conductor_ledger.py` · `merge_check.py` · `state_path.py`
- `plugins/spec-distill/skills/<인터뷰 skill>/references/finishing.md` · request-framing · spec-review `SKILL.md` · `references/redecompose.md` · `references/conducting.md`
- `plugins/spec-distill/tests/test_repo_literals.sh` · `test_decompose_surface.sh` · 새 행동 픽스처 테스트
- `shared/test-selection/resolve-baseline.sh` · `shared/entry/entry_preflight.py`(의존 확인 진입) · `shared/docreview/scripts/docreview_state.py`(스냅숏 대조 · 공시 줄)
- `plugins/quality-gates/scripts/discover-spec.sh` · `publish-comment.sh`(gh 대체 길 제거 · `-R`)
- `plugins/project-init/hooks/post-tool-use.py`
- 플러그인마다 의존 목록 파일 · README prerequisites · 「한계」 절 · CHANGELOG · plugin.json
- 로드맵 R8 블록의 의도 · 범위 문장(U6 반영)

## Verification Plan

- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 변이로 락의 이빨을 확인하고 양성 대조를 둔다.
- 임시 레포 행동 픽스처(AC29)로 끝에서 끝을 돈다: 설정 없는 레포 · `trunk` 레포 · fork 클론에서 상태줄 · 로드맵 찾기 · 인터뷰 끝 커밋 · merge_check 가 맞는 값을 내거나 멈춘다.
- 작업공간 불변 락(AC27).
- gh 실제 호출은 이 레포(이미 머지된 PR)로 판정 다섯 조건을 확인한다.
- plugin.json `dependencies` 는 격리 설치(`CLAUDE_CONFIG_DIR=<tmp>`)로 실측한다.
- 스위트 대조(지휘자 merge_check) · 통합 리뷰.

## Rejected Alternatives

- 로드맵을 표지만으로 찾기 — 끝내기 펜스의 커밋 범위를 묶는 장치가 사라지고 템플릿 · 픽스처가 잡힌다.
- 기본 브랜치를 gh 로 묻기 — 네트워크 · 인증이 필요해 상태줄 · 훅에 쓸 수 없다. 대조용 둘째 출처로만 쓴다.
- 문서마다 frontmatter 에 레포 값을 적기 — 로드맵보다 먼저 필요한 값을 담지 못하고 복제가 어긋난다.
- Claude Code `userConfig` · `.local.md` 설정 — 위 `## 있는 것 검토`.
- 최소 판을 「필요한 만큼」(예: git 2.48)으로 잡기 — U2 · U3 로 대체.
- superpowers 없이 지휘자 흐름을 돌리는 대체 길 — U6.
- 샌드박스 · 훅 출처 기록 · 엔진 별도 프로세스 — §7.
- 부모 레포로 PR 을 내는 fork 흐름 지원 — U8. 원격 둘(올리는 곳 · 머지되는 곳)을 모든 판정이 구별해야 해 계획이 커진다.
- superpowers 를 plugin.json `dependencies` 로 선언 — 없으면 spec-distill 전체가 꺼져 U6 과 충돌한다.
- 진입에서 gh 레포와 원격 URL 을 대조해 멈추기 — `upstream` 이 있는 모든 fork 클론이 멈춘다. `-R` 명시로 충분하다.
- project-init 훅 정규식 넓히기 — 길이 계속 늘어난다(whack-a-mole). 사후 관찰로.
- 조용한 오답 후보 전부를 멈춤으로 — §8.

## 결정 기록

- U1 · 결정 · 2026-10-20 · 사용자 — 「gh는 있어야 한다고 보자 기본적인거야 그리고 너무 낮은 호환을제공하진말자」
- U2 · 결정 · 2026-10-20 · 사용자 — 「내생각에 버전은 그냥 다 최신인게 맞는거 같아 devbrew 는 호환을 고려하지 않아 그리고 장치가 조용히 다른값을 주는경우더 고려해야겠어」
- U3 · 결정 · 2026-10-20 · 사용자 — 「그리고 최신은 오해가 있네 개발 당시 버전 이렇게 하자」 (U2 의 「최신」을 대체)
- U4 · 결정 · 2026-10-20 · 사용자 — 「여기저기 작업공간이 많다보니 지휘자의경우 repo_defaults는 잘못될수도 있는거 아닐까 짐작인데 아닐수도있어 판단해줘 너가 제시한게 가장 좋은 방법일수 있어」 → 지휘자 판단 §9
- U5 · 결정 · 2026-10-20 · 사용자 — 「너무 과한 장치와 제약(과설계)만 경계해 devbrew원칙이야」
- U6 · 결정 · 2026-10-20 · 사용자 — 「지금처럼 + 나머지는 멈춤 (권장)」 (superpowers 가 없을 때)
- U7 · 결정 · 2026-10-20 · 사용자 — 덩어리 3(조용한 오답 · 작업공간 · 개발 당시 판) · 덩어리 4(쓰는 세션 신뢰) 되비춤에 「좋아」
- U8 · 결정 · 2026-10-20 · 사용자 — 「내 레포 안 흐름만 (권장)」 (fork 클론: PR · 기본 브랜치는 언제나 origin, 부모 레포로 PR 내는 흐름은 지원하지 않음, 원격 이름 설정 키 없음)
- 지휘자 판단 · 2026-10-20 — 레포 설정 파일 이름 `.devbrew.md`(계획이 바꿀 수 있다) · spec-distill 은 project-init `branch-strategy.md` 를 읽지 않는다 · qg 는 선택 의존 · RC78 그대로.
- 지휘자 판단 · 2026-10-20 · 설계문서 점검 답 — 머지됨의 끝 대조는 `headRefOid` = 브랜치 끝(원격 추적 ref, 없으면 로컬; 지워졌으면 적어 둔 oid) · superpowers 는 plugin.json `dependencies` 에 올리지 않는다(U6 과 충돌) · machine.md `## 레포 설정` 은 넷째 출처 「기계 상태(임시)」로 남긴다(레포 설정 파일 머지 전 첫 지휘의 테스트 명령) · 로드맵을 찾기 전에 필요한 키는 로드맵 층에서 받지 않는다 · 원격 없는 레포는 기본 브랜치가 필요한 자리에서만 안내와 함께 멈춘다 · gh 확인은 gh 를 쓰는 진입만, 인증은 첫 호출에서 · 공유 `entry_preflight.py` 는 그대로.

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| C25 | 반영 | Constraints · §5(superpowers 는 고치지 않음) |
| C30 | 반영 | Goals G5 · §1~§6 (devbrew 밖 레포) |
| C32 | 반영 | Anti-goals · `## 있는 것 검토` |
| C35 | 반영 | Constraints · Non-goals |
| D21 | 반영 | §10 |
| D26 | 반영 | §5 K11 · superpowers |
| OQ33 | 반영 | §1 · §2 · §6 (위치 · 이름 규약 · 게이트 타입) |
| RC78 | 반영 | §6 · §10 (그대로 두는 이유) |
| RC82 | 반영 | §3 · AC13 |
| RC83 | 반영 | §5 · AC18 · AC19 |
| K11 | 반영 | §5 |
| S1 | 반영 | Context(묶음 의도의 출처) |
| S13 | 반영 | §10 |
| S17 | 반영 | Constraints |
| S18 | 반영 | §5 |
| S27 | 반영 | Goals G5 · §4 |
| S30 | 반영 | Anti-goals · `## 있는 것 검토` |
| S34 | 반영 | Constraints |
| S49 | 반영 | Goals — 묶음 범위 항목을 모두 다룸(superpowers 부재 강등은 U6 으로 다시 정함) |

## 원칙 · 입력 대조

| 입력 | 자리 |
|---|---|
| CLAUDE.md 기본값과 판단 | §11 끝 · §3 RC82(공시) |
| CLAUDE.md 레포 전용 값 금지 | §1 · §2 · §3 |
| CLAUDE.md 상류 · 하류 연계 | `## 상류 · 하류 연계` |
| CLAUDE.md 진입점에서 따라 내려가기 | §1(출처 표시) · §9(읽은 트리) |
| CLAUDE.md 있는 것 먼저 | `## 있는 것 검토` |
| U1 gh 필수 | §5 |
| U2 · U3 개발 당시 판 · 호환 없음 | §5 |
| U2 조용히 다른 값 | §8 |
| U4 작업공간 | §9 |
| U5 과설계 경계 | Anti-goals · §7 · §8 |
| U6 superpowers 부재 | §5 |
| U8 내 레포 안 흐름만 | §3 · §4 |
| R5 설계 미룸(박힌 값 · gh · superpowers) | §1~§5 |
| R2a 설계 미룸 :417 링크 · 경로 · 상한 이식성 | §1 · §6 |
| R2a 설계 미룸 :429-432 | §7 |
| R11 설계 §5 R8 행(의존 최소 판 · README) | §5 |
| R0 D2.3 squash · rebase | §4 |
| R5 Ruling R27 | §3 |
| PR #231 `log-decision --quote` | §7 |
| PR #234 `.claude/` 무시 안 됨 | §6 |
| R2a 계획 4 결정 6 worktree 브랜치 이름 | §3 RC82 |
| R10 넘기는 곳(진입 이름) | §11(R10 계획 3 뒤) |

## 미룸

| 미룸 | 이유 | 받는 곳 |
|---|---|---|
| CLAUDE.md 「최소 버전이 선언된 의존성」 · 「graceful degradation」 문장에 gh 필수 · 개발 당시 판 · superpowers 부재 동작을 반영 | 규칙 문서는 R9 범위 | R9 |
| qg 판정 상태 위치와 그 뒤의 중첩 레포 리뷰 | R12 #18 | R12 |

## 지휘 기록

## Metadata

- 에픽: R8 · 브랜치 `feature/dependency-portability` · 의존 R2a · R5(머지됨), 구현은 R10 계획 3 뒤 · 계획 3은 R12 뒤
- 버전: 계획마다 spec-distill(과 건드린 플러그인) minor bump

### Deferred to plan

- 레포 설정 파일의 최종 이름과 위치 · 의존 목록 파일의 이름과 꼴.
- 판을 재는 명령이 Claude Code 판을 어디서 얻는지(상태줄 입력의 `version` 또는 기록만).
- 네트워크 진입 셋의 정확한 자리와 `ls-remote` 시간 상한.
- machine.md PR 캐시 칸의 꼴.
- `.claude/worktrees/` 를 무시하지 않는 레포에서 qg 가 하는 일의 실측.
