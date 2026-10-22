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
- 기본 브랜치는 이미 `refs/remotes/origin/HEAD` 하나로 도출한다(`roadmap_model.py:528`, 정의가 하나뿐임을 `test_roadmap_approval.py:133-140` 이 잠근다). 못 찾을 때의 정책이 다섯 갈래로 갈렸다 — 멈춤(`DEFAULT_REF` 사용처 · `finishing.md` 끝내기 커밋 펜스 · qg `resolve-range.sh:110-119`), main/master 로 대체(request-framing `SKILL.md:129-134` · `shared/test-selection/resolve-baseline.sh:64-73`), qg 보호 가드의 고정 목록(`artifact_branch_guard.sh:17-31`).
- GitHub 에서 기본 브랜치를 바꾸면 git 은 기존 `origin/HEAD` 를 고치지 않는다(`fetch.followRemoteHEAD` 기본 `create` — 「An existing symbolic-ref will not be touched」, git-scm.com/docs/git-config, 2026-10-20 확인). 그러면 「기본 브랜치에 직접 커밋하지 않는다」 검사가 진짜 기본 브랜치 위에서 통과한다.
- `finishing.md` 끝내기 커밋 펜스와 request-framing `SKILL.md` 의 브랜치 만들기는 `symbolic-ref --short` 결과에서 `origin/` 을 글자로 벗긴다. 로컬에 `origin/main` 이라는 이름의 브랜치가 있으면 결과가 `remotes/origin/main` 이 되어 벗겨지지 않고, 기본 브랜치 검사가 꺼진다.
- 머지됨 자동 판정은 merge commit 문면만 읽는다(`roadmap_status.py:40-61,358-373`). squash · rebase 는 결정 기록의 손 머지 줄로 대신한다(R0 설계 D2.3). gh 를 쓰는 곳은 소유자를 가리지 않는다(`gh pr list --head` — 「"<owner>:<branch>" syntax not supported」, cli.github.com/manual/gh_pr_list). fork 클론에 `upstream` 원격이 있으면 gh 는 묻지 못할 때 부모 레포를 고른다(cli/cli `context/remote.go` remoteNameSortScore).
- 의존 최소 판 선언이 없다(spec-distill `README.md:274` superpowers 「optional」, `:275` qg 「따로 말하지 않는다」, qg `README.md:204` · plugin-audit `README.md:57-61`). 판 확인 코드가 0 이다. 지금 이 지휘 세션은 설치본 spec-distill 7.3.0 으로 도는데 main 은 7.7.0 이다 — 옛 코드는 새 키를 모르는 키로 버리고 기본값을 쓴다.
- `.claude/` 가 git-ignore 된다는 가정이 상태 루트(`state_path.py:65-91`) · merge-check 사본(`merge_check.py:382`) · `WORKTREE_HOME` 에 있다. devbrew 의 `.gitignore:214-220` 만 이를 보장한다.
- R2a 가 넘긴 넷(엔진 밖 원장 쓰기 · 스냅숏 칸 · `--quote` 출처 · 제목 하나 빠진 audit)은 모두 「쓰는 세션 = 제약 대상」 축이다(R2a 설계 `## 미룸` :429-432, 측정 `boundary-measure.md` — 훅 · 권한 · 파일 모드 모두 셸 쓰기를 막지 못했다).

## Goals

- G1 레포마다 다른 값(폴더 · 원격 · 브랜치 접두 · 테스트 명령 등)을 해결자 하나가 출처와 함께 낸다. 어느 작업공간에서 불러도 같은 답이다.
- G2 커밋 범위 · 기본 브랜치 · 머지됨처럼 정확성이 걸린 값은 오류 없이 틀어질 때 멈춘다. 나머지는 출처와 나이를 보인다.
- G3 squash · rebase 로 머지한 레포에서도 머지됨을 자동으로 판정한다.
- G4 의존(Python · git · gh · Claude Code · superpowers · qg)을 개발 당시 판으로 선언하고, 의존마다 정한 강도(멈춤 · 알림 · 기록 — §5 표)로 확인한다. gh 와 superpowers 가 없을 때의 동작이 정해져 있다.
- G5 devbrew 밖 레포(`.claude/` 를 무시하지 않는 레포 · 기본 브랜치가 `main` 이 아닌 레포 · fork 클론)에서 돈다. 지원 범위는 origin 이 GitHub(gh 가 다루는 호스트)인 레포다(U9).
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
- 레포 경로 예약: 이 에픽은 R10 · R12 · R13 이 머지된 뒤 구현한다(U10, §11) — 인터뷰 skill(새 이름 `pm-interview`) · request-framing · spec-review · 재분해 · 지휘 절차 · project-init · 리뷰 엔진을 그 에픽들이 먼저 고친다.

## 설계

### §1 값 해결자 하나

`repo_defaults.py` 가 레포마다 다른 값을 내는 유일한 해결자다. 새 모듈을 만들지 않는다.

- **출처 넷, 우선순위 순.** ① 로드맵 frontmatter(그 로드맵에만) ② 레포 설정 파일 ③ 기계 상태(machine.md `## 레포 설정` — 지휘자가 찾았지만 아직 레포 설정 파일로 머지하지 못한 임시값, 출처 표시 `기계 상태(임시)`) ④ 상수. 레포 설정 파일은 레포 루트의 `.devbrew.md` 하나이고(지휘자 판단 — 이름은 계획이 바꿀 수 있다), frontmatter 만 읽는다. 없어도 된다. 기계 상태 층을 쓰면 지휘자가 그 값을 레포 설정 파일에 올리자고 알린다.
- **층마다 받는 키가 다르다.** 로드맵을 찾기 전에 필요한 값(`roadmaps_dir` · `interview_dir` · `branch_prefix`)은 로드맵 층에서 받지 않는다(적으면 오류). 기계 상태 층은 `test_command` · `test_failure_pattern` 만 받는다. 기계 상태는 로드맵마다 하나라, 해결자는 로드맵을 받았을 때만 이 층을 읽고(`get <키> --roadmap <로드맵>`), 받지 않았으면 이 층을 건너뛰고 출처에 「로드맵 없음 — 기계 상태 층 건너뜀」을 적는다.
- **레포 설정 파일은 기본 브랜치 판에서 읽는다.** `git show <기본 ref>:.devbrew.md`. 작업 브랜치가 자기 검사 범위를 스스로 바꾸지 못하게 하고(Renovate 가 기본 브랜치의 설정을 읽는 것과 같다), 어느 작업공간에서 불러도 같은 값이 나오게 한다. 작업 트리에는 있고 기본 브랜치에는 없으면 「아직 기본 브랜치에 없다 — 기본값을 쓴다」를 알린다(첫 도입 PR). 기본 ref 자체가 없으면(`origin/HEAD` 없음) 해결자는 멈추지 않고 상수를 쓰되 출처를 「기본값(기본 브랜치 없음 — 설정 파일 못 읽음)」으로 내고, 작업 트리에 설정 파일이 있으면 크게 알린다. 기본 브랜치가 실제로 필요한 자리는 §3 대로 멈춘다.
- **키는 닫힌 집합이다.** 설정 키는 `specs_dir` · `plans_dir` · `roadmaps_dir` · `interview_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default` · `branch_prefix` 다. 레포 설정 파일과 기계 상태 층은 이 집합에 대해 닫힌다. 로드맵 층은 로드맵 머리말 키 `type` · `source_brief` 와 그 층이 받는 설정 키(`specs_dir` · `plans_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default`)의 합에 대해 닫힌다 — 이 목록 밖의 키는 오류다. 모르는 키 · 같은 키 둘은 오류로 멈춘다. 값에 `#` 이 필요하면 따옴표로 감싼다 — 따옴표 없는 값의 ` #` 은 주석과 헷갈리므로 오류다. 「frontmatter 를 못 읽음」(BOM · 닫히지 않음 · `--- ` 뒤 공백)은 「키 없음」과 다른 오류다. 폴더 키는 지금처럼 레포 상대경로만 받고 루트 · `.git` 아래를 금지한다.
- **레포 설정 파일은 일반 파일이어야 한다.** 기본 ref 트리에서 그 파일의 mode 가 일반 파일(100644)이 아니면(심볼릭 링크 등) 내용을 읽지 않고 멈춘다. LFS 포인터는 mode 가 같으므로 내용의 첫 줄(`version https://git-lfs…`)로 가려 멈춘다.
- **값마다 출처를 낸다.** 결과는 `(값, 출처)` 이고 출처는 `로드맵` · `레포 설정@<커밋 8자>` · `기계 상태(임시)` · `기본값` 이다. 상태줄 · 지휘자 보고 · merge_check 출력이 출처를 보인다.
- **셸 펜스에는 값이 아니라 검사를 넘긴다.** 경로를 조립해 `git add` 범위를 정하는 펜스는 `repo_defaults.py check-path <키> <경로>` 같은 판정 명령을 부르고 rc 로 받는다. 값을 꼭 받아야 하는 펜스는 `get <키>` 의 rc 를 확인하고 빈 값을 거부한다(`$(...)` 의 빈 값이 레포 루트가 되는 사고를 막는다).
- **흡수.** machine.md `## 레포 설정`(merge_check 의 셋째 층)과 `test_failure_pattern` 을 같은 해결자로 옮긴다. 같은 키가 여러 층에 있을 때의 규칙은 위 우선순위 하나이고, 한 층 안에서 같은 키가 둘이면 오류다(지금 frontmatter 는 첫 값, machine.md 는 마지막 값이 이겨 규칙이 반대다).
- 상태 폴더 `.claude/spec-distill` 은 플러그인 namespace 라 설정 키가 아니다.

### §2 로드맵 · 인터뷰 폴더

- **로드맵 찾기 = 정해진 폴더 안 + 표지.** `roadmaps_dir` 아래이고 frontmatter `type: roadmap` 인 파일만 로드맵이다. 찾는 함수 하나를 `control_plane.py` · `conductor_ledger.py roadmaps` · 끝내기 펜스가 함께 쓴다. 폴더는 범위, 표지는 신원이다. 템플릿 · 픽스처가 후보로 잡히던 결함이 닫힌다.
- **끝내기 펜스의 폴더 검사는 정확성 게이트로 남는다.** `finishing.md` 의 부모 폴더 검사는 `git add -- "$RDIR"` 범위를 묶는 유일한 장치다. 허용 위치(`roadmaps_dir`)는 해결자(기본 브랜치의 설정)에서 얻고, 커밋할 폴더의 존재 · 대소문자 · 경로 안전성은 작업 트리에서, 커밋할 파일은 인덱스에서 확인한다. 새 로드맵 폴더가 기본 브랜치에 아직 없다는 이유로 첫 커밋을 막지 않는다. 대소문자만 다른 경로(대소문자 무시 파일시스템)는 멈춘다.
- **로드맵 폴더 이름**은 지금 규칙 그대로다 — brief 파일 이름에서 `-interview.md` 를 뗀 것(같은 날 같은 주제의 `<주제>-<HHMM>` 포함, R10 계획 2). 해결자는 그 위 폴더(`roadmaps_dir`)만 준다. 로드맵 폴더를 글자로 적는 자리는 끝내기 펜스 말고도 `finishing.md` 의 분해 판단(폴더 안내)과 Step A 의 `--out` 이 있다 — 모두 해결자를 지난다.
- **인터뷰 폴더**의 기본값 상수는 `repo_defaults` 가 소유하고, `state_path.py` 의 `INTERVIEW_DIR` 은 그것을 가져다 쓴다(글자는 한 곳). 다시 적은 자리(control_plane · request-framing · 인터뷰 skill)는 해결자를 부른다. 인터뷰 상태 경로의 두 갈래(`<주제>` · `<주제>-<HHMM>`, R10 계획 2)가 모두 `interview_dir` 을 지난다.
- **spec-review 후보 목록**은 `specs_dir` 을 읽는다(지금 고정 glob).
- 머리말을 못 읽은 후보는 조용히 빼지 않고 「검사 불가」로 센다.

### §3 기본 브랜치 · 원격 · 브랜치 이름

- **지원하는 흐름은 내 레포 안 흐름이다(U8).** PR 과 기본 브랜치는 언제나 `origin` 이다. fork 클론에 `upstream` 원격이 있어도 devbrew 는 `origin` 만 본다. 부모 레포로 PR 을 내는 흐름 · 원격이 없는 로컬 전용 레포는 지원하지 않고 README 에 적는다. 원격 이름 설정 키는 두지 않는다.
- **기본 브랜치는 `DEFAULT_REF`(`refs/remotes/origin/HEAD`) 하나.** main/master 로 대신 쓰는 길(request-framing · 공유 `resolve-baseline.sh`)을 지운다. `resolve-baseline.sh` 의 소비자인 qg(`check-review-scope.sh` · `review-diff.sh` · `discover-spec.sh`)는 지금 이 대체 덕에 기본 브랜치 개명 뒤 남은 옛 `origin/HEAD` 에서도 돌았다 — 대체를 지우면 qg 가 기본 브랜치를 못 찾을 때 degraded 사유와 `git remote set-head origin --auto` 안내를 크게 보인다(조용한 fail-open 이 되지 않게). qg 보호 브랜치 가드의 고정 목록은 보안 게이트라 그대로 둔다.
- **못 찾으면 멈추고 고치는 법을 보인다.** 기본 브랜치가 실제로 필요한 자리(request-framing 의 브랜치 만들기 · 인터뷰 끝 커밋 · 지휘자 · merge_check · 상태줄 · qg 의 리뷰 범위 · 차등 테스트 기준)에서만 멈춘다(qg 는 위처럼 degraded 와 안내로). 안내는 `origin` 이 없으면 원격을 더하라는 것, 있으면 `git remote set-head origin --auto` 다(`git fetch` 로는 이미 있는 옛 값이 고쳐지지 않는다).
- **두 출처 대조.** 네트워크를 써도 되는 진입(지휘자 진입 · merge_check · 인터뷰 끝 커밋 직전)에서 `git ls-remote --symref origin HEAD` 와 로컬 값을 대조하고 다르면 멈춘다. 대조를 못 하면(오프라인 · 시간 상한 초과) 멈추지 않고 로컬 값으로 가며 「원격과 대조하지 못했다 — 로컬 기본 브랜치 <이름> 을 썼다」를 알린다(오프라인 인터뷰를 막지 않는다). 상태줄은 네트워크를 쓰지 않고 「기본 브랜치 <이름> · 마지막 받기 N시간 전(어느 원격 · 브랜치든)」만 보인다.
- **전체 참조 이름으로 다룬다.** `refs/remotes/origin/` 접두를 벗겨 짧은 이름을 얻는다. `--short` 결과에서 `origin/` 을 글자로 벗기는 두 자리를 고친다.
- **브랜치 접두**는 `branch_prefix` 설정(기본 `feature/`) 하나다. spec-distill 은 project-init 의 `branch-strategy.md` 를 읽지 않는다(선언 없는 플러그인 간 결합을 만들지 않는다). 브랜치 이름은 이미 분해 표 → 로드맵 `브랜치:` 로 사용자 승인을 거친다. project-init 의 브랜치 규칙과 `branch_prefix` 가 어긋나면 지휘자가 만드는 브랜치마다 훅이 알리므로, 두 README 에 「둘을 맞춘다」를 적는다(결합하지 않는다).
- **RC82(project-init 훅).** 훅의 정규식은 `worktree add -b` · `branch -m` · `git -C` · `checkout -B` · `switch --create` 를 보지 못하고, 훅은 Bash 도구 뒤에만 불려(`hooks.json` matcher `Bash`) 네이티브 EnterWorktree 도 보지 못한다. matcher 를 `Bash|EnterWorktree` 로 넓히고, 정규식을 늘리지 않고 실행 뒤 상태를 관찰해 규칙에 맞지 않는 새 브랜치 이름을 알린다(공시, 막지 않음 — 훅은 조언자다). 관찰은 상태 파일을 두지 않는다 — 새 브랜치를 가리는 방법(새 worktree 의 현재 브랜치 · 브랜치 reflog 의 생성 시각 등)은 계획이 실측으로 정하되, 규칙 밖 옛 브랜치를 매번 다시 알리지 않아야 한다. EnterWorktree 뒤에 훅이 실제로 불리지 않으면 README 에 「EnterWorktree 브랜치는 검사 밖」을 적고 §10 의 RC82 답을 「부분」으로 고친다. 규칙 파일은 작업 트리가 아니라 기본 브랜치 판에서 읽는다.

### §4 머지 판정 — squash · rebase

gh 가 필수라서 머지 커밋이 없는 squash · rebase 머지도 PR 상태로 판정한다. 판정 순서는 머지 커밋 근거가 먼저다(U17): PR 캐시에 그 브랜치의 줄이 있어도 먼저 `merged_by_tips` 를 본다 — 로컬 끝이 기본 브랜치 머지 커밋의 둘째 부모이거나, 로컬 끝이 없거나 기본 브랜치에 다 들어 있을 때 원격 끝이 그 둘째 부모면 머지됨이다(로컬에만 붙은 후속 커밋이 기본 브랜치 밖에 있으면 원격 끝의 머지는 세지 않는다). 그런 머지 커밋이 없는 squash · rebase 는 아래 여섯 조건의 PR 판정이 채운다. 캐시에 그 브랜치의 줄이 없으면 지금 판정 길 둘(둘째 부모가 브랜치 끝인 머지 커밋 · `Merge pull request #n from <owner>/<브랜치>` 문면)로 판정하고, 문면 길은 `<owner>` 가 origin 소유자일 때만 센다(남의 fork 문면은 세지 않는다). 남은 틈 하나 — 옛 원격 ref 를 지우지 않은 채 같은 이름을 main 에서 새로 딴 브랜치는 원격 끝의 옛 머지 커밋으로 머지됨처럼 보일 수 있다(8.6.0 과 같은 틈).

- **에픽 브랜치가 머지됨** = `origin` 레포의 gh PR 이 MERGED ∧ PR 의 head 레포가 `origin` 레포(`isCrossRepository` 거짓) ∧ `baseRefName` 이 기본 브랜치 ∧ `headRefName` 이 그 브랜치 ∧ `headRefOid` 가 브랜치 끝과 **같다** ∧ `mergeCommit` 이 기본 ref 에서 닿는다. 여섯이 모두 맞을 때만 「머지됨」이다. head 레포 조건은 브랜치가 지워졌어도 늘 건다(지원 흐름이 내 레포 안 흐름이라 fork 에서 온 PR 은 에픽의 PR 이 아니다).
  - 브랜치 끝은 로컬 브랜치(`refs/heads/<브랜치>`), 없으면 원격 추적 ref 다(지금 `roadmap_status` 와 같은 순서). 머지 뒤 커밋이 더 붙으면 끝이 달라 머지됨이 아니다 — 로컬에만 붙은 후속 커밋도 그렇다. 로컬 끝이 원격 끝과 다르고 그 조상이면(받기만 하고 앞당기지 않은 로컬) `headRefOid` 를 원격 끝과 견준다. 로컬과 원격 끝이 다르면 둘 다 보인다.
  - 브랜치가 지워져 끝이 없으면 machine.md 에 적어 둔 그 PR 의 `headRefOid` 와 대조하고, 그것도 없으면 나머지 다섯으로 판정하되 「브랜치 끝 없이 판정」을 알린다.
  - 같은 이름을 다시 쓴 브랜치의 옛 PR 은 `headRefOid` 가, 남의 fork 에서 온 같은 이름 PR 은 head 레포 조건이 거른다.
  - gh 는 MERGED 인데 기본 ref 에 아직 없으면 「머지됨(받기 전)」으로 알리고 `git fetch` 를 안내한다. 이 상태는 머지됨이 아니다 — 끝난 단계로 세지 않고 다음 에픽 착수 같은 게이트를 열지 않는다. 머지 뒤 revert 는 알리기만 한다.
- **gh 호출마다 대상 레포를 명시한다.** `-R <host>/<owner>/<repo>` 를 `origin` URL 에서 호스트까지 보존해 도출한다(fork 클론의 `upstream` 을 gh 가 고르는 일 · `GH_HOST` 가 다른 서버를 가리키는 일을 막는다). 호스트를 확정하지 못하면 그 호출을 멈추고 원격 URL 을 확인하라고 안내한다. `GH_REPO` · `GH_HOST` 가 설정돼 있으면 알린다.
- **판정을 맡는 곳 · 캐시.** PR 상태 캐시는 이미 있다 — machine.md 의 `## PR` 표와 `control_plane.py` 의 「기계 상태 캐시가 먼저, 없으면 gh」 길. 캐시를 채울 때는 그 head 이름의 PR 을 모두 받아(`--state all`, 하나로 자르지 않는다) 여섯 조건에 맞는 것을 고른다 — 가장 최근 하나만 받으면 남의 fork · 다시 쓴 이름의 PR 이 내 머지된 PR 을 가린다. 새 캐시를 만들지 않고 그 표에 칸(`받은 시각 · headRefOid · head 레포(isCrossRepository) · baseRefName · mergeCommit · 쓴 세션`)을 더한다 — 여섯 조건을 네트워크 없이 검사할 입력이 다 든다. 머지됨 판정은 `roadmap_status` 가 하고, gh 를 직접 부르지 않고 그 캐시를 입력으로 받는다. 캐시가 없으면 위 두 길과 손 머지 줄로 판정하고 「PR 상태 미확인 — 지휘자를 돌려라」를 알린다. `control_plane.py` 의 결과 캐시 열쇠에 PR 캐시 표의 지문을 넣어, 지휘자가 PR 캐시를 새로 채우면 상태줄 · 상태 보기가 바로 새 판정을 낸다. 캐시는 지휘자만 채운다 — machine.md 는 지휘 표지를 쥔 세션만 쓰고(`conductor_state.save`), control_plane 은 읽기만 한다. 그래서 상태줄과 `/spec-distill:roadmap-status`(control_plane show)는 gh 를 부르지 않는 진입이다 — control_plane 의 「캐시 없으면 gh」 길과 gh 없음 갈래는 지운다. 그래서 지휘자 밖에서 squash · rebase 로 머지한 에픽은 지휘자가 다음에 들어올 때까지 「PR 상태 미확인」으로 보인다(G3 · AC14 의 범위). 상태줄은 네트워크를 쓰지 않고 캐시의 나이를 보인다. 머지 · 다음 에픽 착수 같은 게이트는 지휘자가 그 직전에 gh 로 캐시를 새로 채운 뒤 `roadmap_status` 를 부른다 — 판정 길은 하나다. 묶음이 넘기라고 한 「R0 상태 계산에」는 이 `roadmap_status` 자리다.
- 결정 기록의 손 머지 줄은 PR 없이 로컬에서 머지한 경우를 위해 남는다.

### §5 의존 — gh 필수 · 개발 당시 판 · 부재

- **선언.** 플러그인마다 자기 의존 목록을 한 파일에 둔다(이름 · 최소 판 · 잰 날짜 · 없을 때 동작). README prerequisites 는 그 파일을 가리킨다. 최소 판은 그 플러그인 판을 개발 · 검증할 때 실제로 깔려 있던 판이다(U3). 판을 재는 작은 명령이 Python · git · gh · Claude Code · superpowers 의 판을 재서 이 파일을 갱신한다 — 손으로 적지 않는다.
- **진입 확인.** 공유 진입 사전 검사(`shared/entry/entry_preflight.py`)는 그대로 둔다(늘 rc 0 · 감시줄 하나). 의존 확인은 플러그인마다 자기 스크립트가 하고, 그 의존을 실제로 쓰는 진입만 부른다. 판 문자열에서 숫자 셋만 뽑아 정수로 비교하고(`2.54.0 (Apple Git-157)` · `2.47.1.windows.2` · gh 의 두 줄 출력), 못 뽑으면 멈춘다. 최소 판보다 낮으면 이유와 업데이트 방법을 보이고 멈춘다.
- **지원 범위 — GitHub 레포(U9).** origin 이 GitHub(gh 가 다루는 호스트)인 레포만 지원한다. 설계 · README · 수용 기준에 적고, gh 를 쓰는 진입은 origin URL 에서 호스트 · owner · repo 를 뽑지 못하거나 gh 가 그 호스트를 다루지 않으면 이유를 보이고 멈춘다. gh 없는 길은 만들지 않는다.
- **의존마다 확인 강도.**

  | 의존 | 확인하는 진입 | 낮거나 없을 때 |
  |---|---|---|
  | Python | 모든 skill 진입(`python3`) · 훅(`devbrew-python.sh` 의 바닥) | 멈춤 — 경로마다 개발 당시 그 경로가 실제로 쓴 판이 바닥이다(훅: `devbrew-python.sh` 가 고른 해석기의 판 · skill 펜스: 잰 `python3` 판) |
  | git | spec-distill · qg 의 진입 | 멈춤 |
  | gh | gh 를 쓰는 진입 | 멈춤(인증은 첫 호출에서) |
  | superpowers | superpowers 를 부르는 자리 | 판이 다르면 알림 · 없으면 아래 U6 |
  | qg | 지휘자 걸음 7 | 없으면 알리고 진행 |
  | Claude Code | — | 잰 판을 기록만 |

- **gh 필수.** gh 를 쓰는 진입(지휘자 · merge_check · 분해 뒤 로드맵 흐름 · qg 의 PR 댓글)은 gh 가 없으면 이유와 설치 방법을 보이고 멈춘다. 인증은 첫 gh 호출이 실패할 때 「`gh auth login` 하라」를 보이고 멈춘다 — 진입마다 네트워크로 인증을 묻지 않는다(오프라인 인터뷰를 막지 않는다). gh 를 쓰지 않는 진입(인터뷰 · request-framing · roadmap-status · 상태줄 · plugin-audit · project-init)은 gh 를 보지 않는다. gh 없을 때의 대체 길(`conductor_ledger.py` 의 gh 찾기와 대체 길 · `control_plane.py` 의 `gh_lookup_for` 와 대체 길 · qg `discover-spec.sh:185` · `publish-comment.sh:43`)은 지운다.
- **실행 중인 코드의 판.** 플러그인 자기 판은 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 에서 읽는다(설치 기록 파일을 추론하지 않는다). 기계 상태(machine.md)를 쓰는 쪽은 자기 판을 찍고, 읽는 쪽 판이 그보다 낮으면 멈춰 「플러그인을 업데이트하라」를 보인다. 이 검사가 보장하는 것은 이 검사를 갖춘 판끼리다 — 처음 들일 때는 플러그인 갱신과 세션 재시작이 전제이고, 옛 설치본이 혼자 쓰고 혼자 읽으면 걸리지 않는다. 레포의 소스 판과 실행 중인 판의 대조는 이미 있는 `conductor_ledger.version_report` 가 따로 하고(지휘자 진입에서 알림), 둘을 다른 검사로 적는다.
- **superpowers 판.** Claude Code 의 plugin.json `dependencies` 는 쓰지 않는다 — 의존이 없거나 판이 맞지 않으면 플러그인 전체를 끄기 때문에(code.claude.com/docs/en/plugins/dependencies, 2026-10-20) U6 의 「없어도 인터뷰는 brief 까지」가 깨진다. superpowers 를 부르는 자리(인터뷰 끝 · 지휘자)의 모델이 불러온 skill 의 기준 폴더 경로(`…/superpowers/<판>/skills/…`)에서 판을 읽어 의존 목록 파일의 판과 비교하고, 다르면 알린다(멈추지 않음). 읽지 못하면 「superpowers 판을 확인하지 못했다」를 알린다.
- **superpowers 가 없을 때(U6).** 인터뷰는 지금처럼 brief 까지 만들고 크게 알린 뒤 멈춘다(`finishing.md` B-1 의 단독 완결 그대로). 지휘자 · 로드맵 흐름(epic-conductor · 분해 뒤 다음 단계)은 진입에서 「superpowers 가 필요하다」와 설치 방법을 보이고 멈춘다. 새 대체 길은 없다. 있는지는 지금처럼 모델이 skill 목록으로 판단한다.
- **qg 가 없을 때.** 선택 의존이다. 지휘자 걸음 7 은 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 진행한다.
- **K11(외부 문구 변화).** 개발 당시 판 기록 + 진입 확인으로 「설치된 superpowers 가 검증한 판과 다르다」를 알린다. 마지막 그물은 이미 있는 돌아온 결과 대조(R3)다. 문구 비교 장치는 만들지 않는다.

### §6 상태 폴더 · devbrew 밖 레포

- **상태 루트가 스스로를 무시한다.** 상태 루트를 처음 만들 때 그 안에 `*` 한 줄짜리 `.gitignore` 를 둔다(선례: plugin-audit `prepare-run-dir.py:72` — 다른 플러그인이라 같은 플러그인 안에 둔다). 만든 뒤 `git check-ignore` 탐침과 `git ls-files -- <상태 루트>` 가 비어 있는지 확인한다. 이미 추적되는 파일이 있으면 멈춘다(무시 목록은 추적 중인 파일을 빼지 못한다).
- merge-check 사본 · 지휘자 상태는 상태 루트 아래라 같이 덮인다. `.claude/worktrees/` 는 하니스 폴더라 손대지 않고, 레포가 그것을 무시하지 않으면 qg 가 「추적 안 되는 중첩 레포」로 잡는지 계획 단계에서 실측한다(PR #234 넘김).
- `GIT_DIR` · `GIT_WORK_TREE` 가 설정돼 있으면 알린다.
- **bare 레포 배치.** 상태 루트는 지금 공용 git 디렉토리의 부모에 붙어(`state_path.state_root_for_common`) 같은 부모 폴더의 bare 레포 둘이 같은 상태 루트를 쓴다. 공용 git 디렉토리가 bare 레포면 상태 루트를 그 안(`<공용 git 디렉토리>/.claude/spec-distill`)에 두어 레포마다 갈리게 한다 — 어느 작업 트리에도 들지 않아 추적될 일이 없다. 이 배치를 픽스처 하나로 확인한다.
- **R2a 가 넘긴 이식성 셋(링크 공유 · 문서 경로 · 상한 설정).** 링크 공유: 레포의 `shared/` 스크립트는 플러그인 폴더에 심볼릭 링크(git mode 120000)로 있고, 설치본에는 일반 파일로 풀려 들어간다(확인: 설치본 spec-distill 7.3.0 `scripts/docreview_state.py` 는 일반 파일). 다른 레포도 같은 설치본을 쓰므로 레포와 무관하다. 문서 경로: §1 · §2. 상한 설정: `DEVBREW_DOCREVIEW_*` 는 사용자 환경 변수라 레포와 무관하고, 최댓값은 R12 가 정한다.
- **RC78(brief 게이트 타입).** `check_brief.py` 가 `type: interview-brief` 만 받는 것은 그대로 둔다. 이 타입은 devbrew 가 만드는 산출물의 이름이지 레포마다 다른 값이 아니다. 에픽 묶음은 이미 `spec_review_bundle.py` 가 따로 받는다.

### §7 쓰는 세션의 신뢰 — R2a 넘김 넷

같은 세션이 원장을 쓰고 원장의 제약을 받는다. 샌드박스는 기본으로 꺼져 있고 플러그인이 켤 수 없으며, 리뷰 엔진도 Bash 로 돌아 함께 막힌다. 훅이 사용자 답을 기록해도 그 파일을 셸이 쓸 수 있다(code.claude.com/docs/en/sandboxing · hooks, 2026-10-20). 이 위험(모델이 자기 세션에서 자기 기록을 위조)에 그 장치들은 과설계다(U5). 원장이 지키는 것은 정직한 실수와 흐름 이탈이고, 그것은 요약값 대조(R2a 설계 AC17 나) · 한 줄 계약이 이미 잡는다.

- **스냅숏은 엔진이 만든다(정확성).** `begin-round` 가 호출자에게 스냅숏을 받지 않고, 원장에 적힌 문서에서 직접 계산한다(`docreview_anchor.py snapshot` 재사용). `--snapshot` 인자를 없애고 진입 skill 들의 호출을 바꾼다(호환을 두지 않는다). 위조된 인자 · 정직한 실수 둘 다 들어올 길이 없다. 원장에 저장된 스냅숏을 셸로 다시 쓰는 길은 아래 공시에 든다. (호출자만 아는 정보 — 여러 파일 번들 · 엔진이 모르는 경로 — 가 스냅숏에 필요해지면 「받고 대조」로 바꾼다.)
- **공시 두 자리.** 리뷰 결과 머리에 한 줄: 「사용자 문구와 원장은 이 세션이 쓴 것이다 — 엔진은 엔진 밖에서 고친 원장 중 요약값이 안 맞는 것만 잡는다」. README 「한계」 절에 같은 문장. 인용마다 라벨은 달지 않는다.
- **엔진 밖 원장 쓰기(R2a 설계 AC17 가).** 레포 안에서 닫지 않는다. 받는 곳은 레포 밖(사용자 · 관리 설정의 샌드박스)이고 README 에 「샌드박스를 쓰는 사용자는 원장 폴더 쓰기를 막을 수 있다」를 안내로만 적는다.
- `--quote-file` · `log-decision --quote` · `decide --quote` 출처와 제목 하나 빠진 audit(B16)은 위 공시로 처리한다.
- **설계 승인 뒤 같은 축으로 넘어온 것(U13 · U14 · U16)도 공시로 처리한다 — 새 장치는 없다.** R13 설계 `## 미룸` 두 행(Write 도구로 상태 폴더에 쓰는 파일의 링크 따라가기 · 실행 중 다시 심는 링크와 `runner_common.sh` `write_failclosed` · `_degrade_if_empty` 의 맨 넘기기)은 README 「한계」 절의 상태 폴더 쓰기 링크 불릿으로, R12 설계 `## 미룸` 의 두 행(`declare-related` · `log-decision` 이 표지 확인 없이 불려도 엔진이 거부하지 않음 · 엔진 명령을 거치지 않는 원장 쓰기)은 위 공시 문장으로 다룬다. qg 판정 줄의 `--optional` 을 묶지 않아 「선택 N」 칸이 낮아질 수 있는 것(PR #243 미룸, 판정값은 그대로)은 quality-gates README 의 한계에 한 줄로 알린다.
- R12 설계 `## 미룸` 의 보호 절 제목 바꿈 정체 추적(후보)은 받지 않는다(U15) — 새 장치라 U5 에 걸리고, R12 가 좁힌 대로 둔다.

### §8 조용한 오답 — 남긴 것 · 뺀 것

조사한 경우(R8 설계 입력 조사, 지휘 세션 레포 밖 기록)를 과설계 경계로 걸렀다. 멈춤은 커밋 범위 · 기본 브랜치 · 머지됨 · 판 비교에만 둔다.

| 경우 | 처분 | 자리 |
|---|---|---|
| fork 클론에서 gh 가 부모 레포를 봄 · `GH_REPO` | `-R origin` 명시 + 환경 변수 공시 | §4 |
| 기본 브랜치 개명 뒤 옛 `origin/HEAD` | 멈춤(두 출처) | §3 |
| 남의 fork · 재사용 이름 · stacked PR 의 거짓 「머지됨」 | 여섯 조건(head 레포 · `headRefOid` = 끝) | §4 |
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
| bare 레포 둘이 같은 상태 루트를 씀 | 고침(bare 면 공용 git 디렉토리 안) | §6 |

### §9 작업공간이 여럿일 때

- 값의 출처(기본 브랜치 판 · 공용 git 디렉토리의 상태 루트)는 작업공간과 무관하다 — `merge_check` · `roadmap_status` · `control_plane` 이 이미 기본 커밋에서 읽고, 상태 루트는 `--git-common-dir` 에서 얻는다.
- 지금 작업공간 기준으로 읽는 자리는 의도된 것만 남기고 표시한다: 인터뷰 끝 펜스 · `check_brief` · 경로로 넘긴 설계문서. 출력에 「읽은 트리」(기본 브랜치 / 에픽 끝 / 이 작업공간)를 밝힌다.
- 충돌 미리 보기의 브랜치 끝(`conductor_ledger.py:500`)이 로컬과 원격에서 다르면 둘 다 보인다.
- **작업공간 불변 락.** 임시 레포 하나에 서로 다른 브랜치의 작업공간 둘을 두고(한쪽은 로드맵 · 설정 파일을 고침) `repo_defaults get *` · 로드맵 찾기 · `roadmap_status --json` 을 돌려 출력이 바이트까지 같아야 한다(「읽은 트리」가 이 작업공간인 칸만 예외).

### §10 위험에 대한 답

- RC78 — §6: 그대로 둔다(타입은 devbrew 산출물 이름).
- RC82 — 부분 — EnterWorktree 뒤 훅 호출은 실측 못 함. §3: matcher 를 넓히고 사후 관찰로 알린다(EnterWorktree 뒤에 훅이 안 불리면 그 브랜치는 검사 밖일 수 있다 — project-init README 공시).
- RC83 — §5: 의존 목록 파일 · 개발 당시 판 · 진입 확인.
- K11 — §5: 판 기록 + 진입 공시 + R3 돌아온 결과 대조.

### §11 계획 나누기

이 에픽은 R10 · R12 · R13 이 머지된 뒤 구현한다(U10). 고칠 파일이 세 에픽의 경로 예약(인터뷰 skill · request-framing · spec-review · 재분해 · 지휘 절차 · project-init · `shared/docreview` · `state_path` · `roadmap_model`)과 겹치기 때문이다. 로드맵의 R8 의존 칸에 R10 · R12 · R13 을 더하고 경로 예약을 채우는 일은 재분해 PR 로 한다. 그동안 계획은 미리 써 둔다.

- 계획 1 — 값 해결자 · 폴더 · 기본 브랜치 · 브랜치 접두 · 상태 폴더 · 작업공간 불변 락(§1 · §2 · §3 의 RC82 를 뺀 불릿 전부 · §6 · §9).
- 계획 2 — gh 필수 · 머지 판정 · 의존 선언 · 판 확인 · superpowers · qg 부재 · K11(§4 · §5) + RC82(§3 끝 불릿, project-init).
- 계획 3 — 쓰는 세션의 신뢰(§7, shared/docreview).

계획 담당자가 일의 모양을 보고 다르게 나눌 수 있다 — 이유를 계획에 적는다.

## 있는 것 검토

- 레포 안: `repo_defaults.py`(해결자) · `DEFAULT_REF` · `NO_DEFAULT`(`roadmap_model.py:528-529`) · `test_repo_literals.sh`(박힌 값 락 — 대상만 넓힌다) · `conductor_ledger.c_roadmaps`(표지 찾기) · `state_path.INTERVIEW_DIR` · `docreview_anchor.py snapshot` · `_digest` · `ERA_FILE` · `LedgerCorrupt` · `seed_review_log.py` 머리의 「한계」 문단 · plugin-audit `prepare-run-dir.py:72`(자기 무시) · `check-staleness.py:327`(설치 판 — 함정 때문에 판정에 쓰지 않음) · `merge_check.py:348-351`(fetch 실패 공시) · `control_plane.fetch_stamp` · machine.md `## PR` 표와 control_plane 의 「캐시 먼저, 없으면 gh」 길(PR 상태 캐시) · `conductor_ledger.version_report`(소스 판 대 실행 판).
- 레포 밖: git `remote set-head --auto` · `ls-remote --symref` · gh `-R` · `--json` 필드 · Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다.
- 기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다 — code.claude.com/docs/en/plugins-reference · settings-reference) · `.claude/<plugin>.local.md`(git-ignored 라 새 작업공간에 없다) · 샌드박스 · 훅 출처 · 별도 프로세스(§7).

## 상류 · 하류 연계

- 받는 곳: 묶음 R8.md · R5 설계 `## 미룸` R8 행 · R2a 설계 `## 미룸` R8 행 다섯(:417 · :429-432) · R11 설계 §5 R8 행 · R0 설계 D2.3(squash · rebase) · R5 계획 3 Ruling R27(`resolve-baseline.sh` · control_plane 박힌 값) · PR #231 넘김(`log-decision --quote`) · PR #234 넘김(`.claude/` 무시 안 되는 레포) · R2a 계획 4 결정 6(worktree 로 만든 브랜치 이름) · R10 설계 넘기는 곳(진입 이름 → R8) · R13 설계 `## 미룸` R8 행 둘(U13) · R12 설계 `## 미룸` R8 행 셋(둘은 U14 로 받고, 정체 추적 하나는 U15 로 받지 않는다) · PR #243 미룸 `--optional`(U16) · 묶음 인터페이스 「받는 것: R0 의 「devbrew 밖 레포」 한계 공시」(squash · rebase 손 머지 줄 공시 — 새 규칙으로 고친다, Files to Modify) · 이 세션의 사용자 결정 U1~U10.
- 넘기는 곳: 해결자(→ 모든 spec-distill 스크립트 · skill 펜스 · 상태줄) · 머지됨 판정(→ 상태 계산 · 지휘자 걸음 1 · 6) · 의존 확인(→ 모든 진입) · 공시 문장(→ 리뷰 결과 · README) · CLAUDE.md 규칙 문장(→ R9, `## 미룸`).
- 되돌아오는 길: 계획 · 구현에서 이 설계를 다시 나눌 근거가 보이면 재분해 신호로 지휘 세션에 보고한다(`references/redecompose.md`).
- 같은 상태를 읽는 다른 표면: 상태줄(`control_plane.py`) · `roadmap_status.py` · `conductor_ledger.py` · `merge_check.py` · 인터뷰 끝 펜스 · request-framing · spec-review 후보 목록 · qg(gh · 기본 브랜치) · project-init 훅. 이음매 담당은 이 에픽.

## Acceptance Criteria

**값 해결자(§1)**
- AC1 `repo_defaults` 가 네 출처(로드맵 · 레포 설정 파일@기본 브랜치 · 기계 상태(임시) · 상수)를 우선순위대로 합치고 값마다 출처를 낸다. 레포 설정 파일은 작업 트리가 아니라 기본 ref 판에서 읽고, 기본 ref 가 없으면 상수를 「기본값(기본 브랜치 없음)」 출처로 낸다.
- AC2 모르는 키 · 같은 키 둘 · 따옴표 없는 값의 ` #` · 못 읽는 머리말은 각각 다른 오류로 멈춘다. 따옴표로 감싼 값의 `#` 은 받는다. 「키 없음」은 기본값이다.
- AC3 작업 트리에만 있는 레포 설정 파일은 「아직 기본 브랜치에 없다」를 알리고 기본값을 쓴다.
- AC4 `get` · `check-path` 명령이 있고, 경로로 `git add` 범위를 정하는 펜스는 `check-path` 의 rc 로 판정한다. `get` 을 쓰는 펜스는 rc 를 확인하고 빈 값을 거부한다(박힌 값 락이 이 꼴을 잰다).
- AC5 machine.md `## 레포 설정` 과 `test_failure_pattern` 이 같은 해결자를 지난다.

**폴더(§2)**
- AC6 로드맵 찾기 함수 하나를 상태줄 · 로드맵 목록 · 끝내기 펜스가 쓰고, 템플릿 · 픽스처는 후보가 아니다.
- AC7 끝내기 펜스의 폴더 검사가 `roadmaps_dir` 기준이고, 폴더 없음 · 빈 폴더 · 대소문자만 다른 경로를 가른다.
- AC8 인터뷰 폴더 · 설계문서 폴더를 글자로 다시 적는 자리가 없다(박힌 값 락의 대상이 넓어진다).

**기본 브랜치 · 원격(§3)**
- AC9 main/master 대체가 없고(qg 보호 가드 제외), 못 찾으면 `git remote set-head origin --auto` 를 안내하며 멈춘다. qg 는 같은 경우 degraded 사유와 그 안내를 크게 보인다.
- AC10 네트워크 진입 셋에서 `ls-remote --symref` 와 로컬 기본 ref 가 다르면 멈춘다.
- AC11 기본 브랜치 짧은 이름을 전체 참조 이름에서 얻는다 — 로컬 브랜치 `origin/main` 이 있어도 기본 브랜치 검사가 켜져 있다.
- AC12 브랜치 접두가 설정에서 오고, 글자 `origin/main` · `feature/roadmap-` 를 잠그던 락이 「도출하는가」 락으로 바뀐다.
- AC13 project-init 훅이 Bash 와 EnterWorktree 뒤에 불리고, 실행 뒤 새 브랜치 이름을 관찰해 규칙 밖이면 알린다(`worktree add -b` · `branch -m` · EnterWorktree 포함 — EnterWorktree 에서 훅이 안 불리면 README 공시). 규칙 밖 옛 브랜치는 다시 알리지 않는다. 규칙 파일은 기본 브랜치 판에서 읽는다. kill switch 를 존중한다.

**머지 판정(§4)**
- AC14 squash · rebase 로 머지한 에픽이 손 머지 줄 없이 「머지됨」이다(지휘자가 PR 캐시를 채운 뒤). 캐시가 없으면 「PR 상태 미확인」을 알리고, 「머지됨(받기 전)」은 머지됨으로 세지 않는다.
- AC15 head 레포가 origin 이 아닌 PR(브랜치가 지워졌어도) · 재사용한 브랜치 이름의 옛 MERGED PR · 기본 브랜치가 아닌 base 로 머지된 PR · 머지 뒤 커밋이 더 붙은 브랜치는 「머지됨」이 아니다. 지워진 브랜치는 적어 둔 `headRefOid` 로 판정하거나 「브랜치 끝 없이 판정」을 알린다.
- AC16 모든 gh 호출이 `origin` URL 에서 호스트까지 도출한 `-R <host>/<owner>/<repo>` 를 쓰고(못 하면 멈춤), `GH_REPO` · `GH_HOST` 가 설정돼 있으면 알린다. `upstream` 원격이 있는 fork 클론에서도 `origin` 의 PR 만 본다.
- AC17 상태줄은 네트워크 없이 캐시와 그 나이를 보이고, 게이트는 지휘자가 그 직전에 gh 로 캐시를 새로 채운 뒤 `roadmap_status` 로 판정한다.

**의존(§5)**
- AC18 플러그인마다 의존 목록 파일(이름 · 최소 판 · 잰 날짜 · 없을 때)이 있고, 판을 재는 명령이 그것을 갱신한다.
- AC19 모든 skill 진입이 `python3` 판을(바닥은 개발 당시 잰 `python3` 판 — 훅은 따로, `devbrew-python.sh` 바닥이 개발 당시 그 해석기가 고른 판), spec-distill · qg 진입이 git 판을, gh 를 쓰는 진입이 gh 판을 숫자 셋으로 비교하고, 못 뽑거나 낮으면 멈춘다. 의존마다 확인 강도가 §5 표와 같다.
- AC20 gh 를 쓰는 진입에서 gh 가 없으면 멈추고, 인증 실패는 첫 호출에서 멈춘다. gh 없을 때의 대체 길이 코드에 없다. origin 이 GitHub(gh 가 다루는 호스트)가 아니면 gh 를 쓰는 진입이 이유를 보이고 멈춘다(U9).
- AC21 machine.md 를 쓰는 쪽이 자기 판을 찍고, 낮은 판의 읽는 쪽은 멈춰 업데이트를 안내한다.
- AC22 superpowers 가 없으면 인터뷰는 brief 까지 만들고 멈추고(현행), 지휘자 · 로드맵 흐름은 진입에서 멈춘다. qg 가 없으면 지휘자가 품질 게이트 없이 간다고 알리고 진행한다.
- AC23 superpowers 를 부르는 자리가 불러온 skill 의 기준 폴더 경로에서 판을 읽어 의존 목록의 판과 다르면 알리고, 읽지 못하면 「superpowers 판을 확인하지 못했다」를 알린다(멈추지 않음). plugin.json `dependencies` 에 superpowers 를 올리지 않는다.
- AC23a gh 를 쓰는 진입만 gh 를 확인하고, 인증 실패는 첫 gh 호출에서 로그인 안내와 함께 멈춘다. gh 를 쓰지 않는 진입은 gh 가 없어도 돈다.
- AC23b 레포 설정의 층별 허용 키가 지켜진다 — 로드맵 층의 `roadmaps_dir` · `interview_dir` · `branch_prefix` 와 기계 상태 층의 다른 키는 오류다.

**상태 폴더(§6)**
- AC24 상태 루트가 자기 `.gitignore` 를 갖고, 추적 중인 파일이 있으면 멈춘다.

**쓰는 세션(§7)**
- AC25 `begin-round` 가 스냅숏을 인자로 받지 않고 원장의 문서에서 직접 계산하며, 진입 skill 들이 `--snapshot` 을 넘기지 않는다.
- AC26 리뷰 결과 머리 한 줄 · README 「한계」 절이 같은 문장으로 있고, 인용마다 라벨은 없다.

**작업공간 · 공통(§9)**
- AC27 작업공간 불변 락이 있고 양성 대조(설정이 다른 두 레포는 다른 답)를 가진다.
- AC28 바뀐 동작마다 락이 있고 변이로 이빨을 확인했다. 음의 락에는 양의 짝이 있다.
- AC29 회귀 픽스처: 기본 브랜치가 `trunk` 인 레포 · 설정 폴더가 다른 레포(`plan/…`) · upstream 원격이 있는 fork(origin 의 PR 만 본다) · origin 이 없는 레포(안내와 함께 멈춤) · 기본 브랜치 개명 뒤(spec-distill · qg 둘 다) · 상태 루트 아래 추적 파일 · BOM · 같은 키 둘 · 오타 키 · `-suffix` 판 문자열.

## Files to Modify

- `plugins/spec-distill/scripts/repo_defaults.py` · `roadmap_model.py` · `roadmap_status.py` · `control_plane.py` · `conductor_ledger.py` · `merge_check.py` · `state_path.py`
- `plugins/spec-distill/skills/<인터뷰 skill>/references/finishing.md` · request-framing · spec-review `SKILL.md` · `references/redecompose.md` · `references/conducting.md`
- `plugins/spec-distill/tests/test_repo_literals.sh` · `test_decompose_surface.sh` · 새 행동 픽스처 테스트
- `shared/test-selection/resolve-baseline.sh` · `shared/docreview/scripts/docreview_state.py`(엔진이 스냅숏을 만듦 · 공시 줄) · 플러그인마다 의존 확인 스크립트(공유 `entry_preflight.py` 는 그대로)
- `plugins/quality-gates/scripts/discover-spec.sh` · `publish-comment.sh`(gh 대체 길 제거 · `-R`)
- `plugins/project-init/hooks/post-tool-use.py` · `plugins/project-init/hooks/hooks.json`(matcher)
- 플러그인마다 의존 목록 파일 · README prerequisites · 「한계」 절 · CHANGELOG · plugin.json
- 로드맵 R8 블록의 의도 · 범위 문장(U1 · U6 · U9 반영)
- 「squash · rebase 는 손 머지 줄」 공시 세 자리: `roadmap_status.py` 의 NOTICE · spec-distill `README.md` 의 상태 계산 줄 · `templates/roadmap-template.md` 의 머지 줄 안내 — 새 규칙(PR 상태로 판정 · 손 머지 줄은 PR 없는 로컬 머지만 · 캐시 없으면 「PR 상태 미확인」)으로

## Verification Plan

- 바뀐 동작마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 변이로 락의 이빨을 확인하고 양성 대조를 둔다.
- 임시 레포 행동 픽스처(AC29)로 끝에서 끝을 돈다: 설정 없는 레포 · `trunk` 레포 · fork 클론에서 상태줄 · 로드맵 찾기 · 인터뷰 끝 커밋 · merge_check 가 맞는 값을 내거나 멈춘다.
- 작업공간 불변 락(AC27).
- gh 실제 호출은 이 레포(이미 머지된 PR)로 판정 여섯 조건을 확인한다.
- plugin.json `dependencies` 는 격리 설치(`CLAUDE_CONFIG_DIR=<tmp>`)로 실측한다.
- 스위트 대조(지휘자 merge_check) · 통합 리뷰.

## Rejected Alternatives

- 로드맵을 표지만으로 찾기 — 끝내기 펜스의 커밋 범위를 묶는 장치가 사라지고 템플릿 · 픽스처가 잡힌다.
- 기본 브랜치를 gh 로 묻기 — 네트워크 · 인증이 필요해 상태줄 · 훅 · gh 를 쓰지 않는 진입에 쓸 수 없다. 대조용 둘째 출처는 `git ls-remote --symref` 다.
- 문서마다 frontmatter 에 레포 값을 적기 — 로드맵보다 먼저 필요한 값을 담지 못하고 복제가 어긋난다.
- Claude Code `userConfig` · `.local.md` 설정 — 위 `## 있는 것 검토`.
- 최소 판을 「필요한 만큼」(예: git 2.48)으로 잡기 — U2 · U3 로 대체.
- superpowers 없이 지휘자 흐름을 돌리는 대체 길 — U6.
- 샌드박스 · 훅 출처 기록 · 엔진 별도 프로세스 — §7.
- 부모 레포로 PR 을 내는 fork 흐름 지원 — U8. 원격 둘(올리는 곳 · 머지되는 곳)을 모든 판정이 구별해야 해 계획이 커진다.
- superpowers 를 plugin.json `dependencies` 로 선언 — 없으면 spec-distill 전체가 꺼져 U6 과 충돌한다.
- GitHub 가 아닌 원격에서 qg 만 gh 없이 계속 진행 — U9. gh 없는 길이 다시 생긴다.
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
- U9 · 결정 · 2026-10-20 · 사용자 — 「GitHub 레포만 지원 (권장)」 (spec 리뷰 1라운드 4072c50f#r1.1)
- U10 · 결정 · 2026-10-20 · 사용자 — 「R10 · R12 · R13 뒤 (권장)」 (R8 구현 순서 — 로드맵 R8 의존 칸에 R10 · R12 · R13, 재분해 PR)
- 지휘자 판단 · 2026-10-20 · spec 리뷰 1라운드 참고 항목 반영 — 기본 ref 없으면 해결자는 상수 + 출처 표시(16e1de69) · 폴더 존재는 작업 트리 · 인덱스로(857a11f3) · project-init matcher 에 EnterWorktree(a6c6dbd6) · head 레포 조건(582211a1#r1.1) · roadmap_status 가 기존 PR 캐시로 판정(582211a1#r1.2) · `-R` 에 호스트(582211a1#r1.3) · 판 검사의 보장 범위와 version_report(151b882b) · 엔진이 스냅숏을 만듦(8d270fe0) · AC 와 본문 맞춤(fccf272b) · 의존마다 확인 강도 표(f7e40deb) · branch_prefix 와 project-init 규칙은 README 로 맞춘다(a430e0e3, 결합 없음).
- 지휘자 판단 · 2026-10-20 · spec 리뷰 2라운드 참고 항목 반영 — PR 캐시는 지휘자만 채우고 게이트는 직전에 새로 채운 뒤 판정(f1 · f7) · 캐시 칸에 baseRefName · mergeCommit · head 레포(f2) · bare 레포는 공용 git 디렉토리 안 상태 루트(f3) · 로드맵 층 키 목록(f4) · 브랜치 접두는 계획 1(f5) · 조건 수 여섯(f6) · 설정 파일 mode 확인(f8) · AC2 의 `#`(f9) · `--snapshot` 테스트는 계획으로(f10) · Metadata 순서(f11) · R2a AC17 표기 · 「머지됨(받기 전)」은 머지됨 아님.
- U12 · 결정 · 2026-10-20 · 사용자 — 「경로마다 실측 판 (권장)」 (훅 바닥은 훅이 실제로 쓰는 해석기 판, skill python3 바닥은 잰 판 — 설계 글자대로 훅을 3.9 로 내리지 않는다) · 「Subagent-driven (권장)」(R8 계획 셋 실행 방식)
- U11 · 결정 · 2026-10-20 · 사용자 — 「넣는다 (권장)」 (Python 도 개발 당시 판 확인에, spec 리뷰 3라운드 19f7dd62#r3.1) · 「고친 대로 둠 (권장)」(2 · 3라운드 반영 절) · 「열지 않음 (권장)」(추가 라운드)
- 지휘자 판단 · 2026-10-20 · spec 리뷰 3라운드 참고 항목 반영 — LFS 는 내용 첫 줄로(f1) · qg 도 기본 브랜치 대체 없이 degraded + 안내(f2) · 브랜치 끝은 로컬 먼저(f3) · control_plane 결과 캐시 열쇠에 PR 캐시 지문(f4) · 기계 상태 층은 로드맵을 받을 때만(f6) · 머지 커밋 · 문면 길의 자리(f7) · 같은 이름 PR 모두 받기(f8) · roadmap-status 는 gh 를 안 쓰는 진입(f9) · superpowers 판 출처는 계획으로(f10) · 로드맵 범위 문장 U1 · U6 · U9(f11) · R0 한계 공시 세 자리(f12).
- U8 · 결정 · 2026-10-20 · 사용자 — 「내 레포 안 흐름만 (권장)」 (fork 클론: PR · 기본 브랜치는 언제나 origin, 부모 레포로 PR 내는 흐름은 지원하지 않음, 원격 이름 설정 키 없음)
- 지휘자 판단 · 2026-10-20 — 레포 설정 파일 이름 `.devbrew.md`(계획이 바꿀 수 있다) · spec-distill 은 project-init `branch-strategy.md` 를 읽지 않는다 · qg 는 선택 의존 · RC78 그대로.
- 지휘자 판단 · 2026-10-20 · 설계문서 점검 답 — 머지됨의 끝 대조는 `headRefOid` = 브랜치 끝(원격 추적 ref, 없으면 로컬; 지워졌으면 적어 둔 oid) — 순서는 3라운드에서 로컬 먼저로 바뀜(§4 본문 · 위 3라운드 지휘자 판단) · superpowers 는 plugin.json `dependencies` 에 올리지 않는다(U6 과 충돌) · machine.md `## 레포 설정` 은 넷째 출처 「기계 상태(임시)」로 남긴다(레포 설정 파일 머지 전 첫 지휘의 테스트 명령) · 로드맵을 찾기 전에 필요한 키는 로드맵 층에서 받지 않는다 · 원격 없는 레포는 기본 브랜치가 필요한 자리에서만 안내와 함께 멈춘다 · gh 확인은 gh 를 쓰는 진입만, 인증은 첫 호출에서 · 공유 `entry_preflight.py` 는 그대로.
- U13 · 결정 · 2026-10-21 · 사용자 — 「§7 공시로 받는다 (권장)」 (R13 설계 미룸 R8 행 둘 — Write 도구 쓰기 링크 · 실행 중 다시 심는 링크와 `runner_common.sh` 두 함수 — 을 §7 공시로 받는다, 장치 없음)
- U14 · 결정 · 2026-10-21 · 사용자 — 「§7 공시로 받는다 (권장)」 (R12 설계 미룸 R8 행 둘 — `declare-related` · `log-decision` 의 표지 없는 호출 · 엔진 명령 밖 원장 쓰기 — 을 §7 공시로 받는다, 장치 없음)
- U15 · 결정 · 2026-10-21 · 사용자 — 「받지 않는다 — 좁힌 대로 둠(U5) (권장)」 (R12 설계 미룸의 보호 절 제목 바꿈 정체 추적은 R8 이 받지 않는다)
- U16 · 결정 · 2026-10-21 · 사용자 — 「qg README 한계에 한 줄 공시로 받는다 (권장)」 (PR #243 미룸 — `--optional` 을 묶지 않아 「선택 N」 칸이 낮아질 수 있음 — 을 quality-gates README 한계 한 줄로 받는다, 코드 없음)
- U17 · 결정 · 2026-10-22 · 사용자 — 「바꾼다 — 머지 커밋 근거 먼저 (권장)」 (§4 판정 순서 재결정 — 「PR 캐시가 있으면 PR 판정이 이기고 둘은 쓰지 않는다」를 「머지 커밋 근거(`merged_by_tips`) 먼저, PR 판정은 squash · rebase 를 채운다, 로컬 끝이 원격 끝보다 뒤면 `headRefOid` 를 원격 끝과 견준다」로 바꾼다. 업그레이드 뒤 `pr-refresh --reset` 에서 이 레포의 머지된 에픽 일곱이 머지 안 됨으로 돌아간 회귀를 막는다 — fcf7d300. AC15 는 그대로)
- D1.1 · r1 · adopt · 4072c50f#r1.1 · "GitHub 레포만 지원 (권장)" — gh 를 필수로 하고 gh 가 없을 때의 길을 지우면 GitHub 가 아닌 원격(GitLab 등)을 쓰는 레포는 지원에서 빠진다. 그런데 문서는 이 축소를 지원하지 않는 흐름 목록에 적지 않았다.
- D2.2 · r2 · adopt · 5b2b32f2#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 있는 것 검토 (modified)
- D2.3 · r2 · adopt · 6697c411#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 원칙 · 입력 대조 (modified)
- D2.4 · r2 · adopt · 8e81e781#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Constraints (modified)
- D2.5 · r2 · adopt · 93a5c0ad#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D2.6 · r2 · adopt · a58ea360#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §7 쓰는 세션의 신뢰 — R2a 넘김 넷 (modified)
- D2.7 · r2 · adopt · c19c6fc3#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Context / Why (modified)
- D2.8 · r2 · adopt · c7f6ab3e#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §10 위험에 대한 답 (modified)
- D2.9 · r2 · adopt · e09185f8#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Goals (modified)
- D2.10 · r2 · adopt · e939aca4#r2.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §11 계획 나누기 (modified)
- D3.11 · r3 · adopt · 0b7af0b4#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Metadata (modified)
- D3.12 · r3 · adopt · 0d834c7c#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §1 값 해결자 하나 (modified)
- D3.13 · r3 · adopt · 1dfa0ba5#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Verification Plan (modified)
- D3.14 · r3 · adopt · 648e1b03#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §4 머지 판정 — squash · rebase (modified)
- D3.15 · r3 · adopt · 6697c411#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: 원칙 · 입력 대조 (modified)
- D3.16 · r3 · adopt · 93a5c0ad#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.17 · r3 · adopt · a4e4e637#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §8 조용한 오답 — 남긴 것 · 뺀 것 (modified)
- D3.18 · r3 · adopt · a58ea360#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §7 쓰는 세션의 신뢰 — R2a 넘김 넷 (modified)
- D3.19 · r3 · adopt · aff062af#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §6 상태 폴더 · devbrew 밖 레포 (modified)
- D3.20 · r3 · adopt · e939aca4#r3.1 · "고친 대로 둠 (권장)" — finding 없이 바뀜: §11 계획 나누기 (modified)
- D3.21 · r3 · adopt · 19f7dd62#r3.1 · "넣는다 (권장)" — 모든 devbrew 스크립트가 쓰는 Python 이 의존 선언 · 개발 당시 판 확인 목록에 없습니다. 사용자는 판 규칙을 의존 전부에 적용하라고 했습니다.
- docreview 계수 — spec-distill/2026-10-20-dependency-portability-design-d95c38d242b0173c r1: advice_new=10 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-20-dependency-portability-design-d95c38d242b0173c r2: advice_new=7 · advice_repeat=5 · mc_preexisting_new=0
- docreview 계수 — spec-distill/2026-10-20-dependency-portability-design-d95c38d242b0173c r3: advice_new=4 · advice_repeat=6 · mc_preexisting_new=1

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
| S49 | 반영 | Goals — 묶음 범위 항목을 모두 다룸(gh 부재 강등은 U1 · U9, superpowers 부재 강등은 U6 으로 다시 정함) |

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
| U9 GitHub 레포만 | §5 · Goals G5 |
| U11 Python 판 | §5 표 · G4 · AC19 |
| U12 경로마다 실측 판 | §5 표 · AC19 |
| U10 R10 · R12 · R13 뒤 | §11 · Constraints |
| R10 계획 2 통합 리뷰 넘김(분해 판단 · Step A `--out` · `<주제>-<HHMM>`) | §2 |
| R5 설계 미룸(박힌 값 · gh · superpowers) | §1~§5 |
| R2a 설계 미룸 :417 링크 · 경로 · 상한 이식성 | §1 · §6 |
| R2a 설계 미룸 :429-432 | §7 |
| R11 설계 §5 R8 행(의존 최소 판 · README) | §5 |
| R0 D2.3 squash · rebase | §4 |
| R5 Ruling R27 | §3 |
| PR #231 `log-decision --quote` | §7 |
| PR #234 `.claude/` 무시 안 됨 | §6 |
| R2a 계획 4 결정 6 worktree 브랜치 이름 | §3 RC82 |
| R10 넘기는 곳(진입 이름) | §11(R10 · R12 · R13 뒤 — 새 이름 자리에서) |
| R13 설계 미룸 R8 행 둘 · R12 설계 미룸 R8 행 셋 · PR #243 미룸 `--optional` | §7(U13 · U14 · U15 · U16) |

## 미룸

| 항목 | 이유 | 받는 곳 |
|---|---|---|
| CLAUDE.md 「최소 버전이 선언된 의존성」 · 「graceful degradation」 문장에 gh 필수 · 개발 당시 판 · superpowers 부재 동작을 반영 | 규칙 문서는 R9 범위 | R9 |
| qg 판정 상태 위치와 그 뒤의 중첩 레포 리뷰 | R12 #18 | R12 |
| AC29 픽스처 중 upstream 원격이 있는 fork(origin 의 PR 만 본다) · `-suffix` 판 문자열 | 판 확인 · PR 판정은 계획 2(§4 · §5) 몫 끝냄 — 79a97dc6(R8 계획 2, `test_workspace_invariance.sh`) | R8 |
| `strict_frontmatter` 가 콜론 없는 머리말 줄을 오류 없이 건너뛴다 | 해결자 줄 규칙을 오류로 조이는 일 — 계획 2 · 3 의 파일 목록에 해결자가 없다 | R14 |
| 설정 값의 pathspec 매직 · 글롭 글자가 `ls-tree` · spec-review 의 pathspec 에 그대로 닿는다 | 계획 1 은 경로 모양(루트 · `.git` · `..`)만 막는다 — 글자 규칙이나 글자 그대로 읽는 pathspec 이 필요하다 | R14 |
| `ledger add --section "레포 설정"` 이 같은 키 둘을 받는데 merge_check 는 그 기계 상태를 거부한다 | 쓰는 쪽에서 막거나 거부 문장에 고치는 명령을 적는 일(`conductor_ledger.py` · 지휘 절차의 `ledger add` 문장을 고친다) | R14 |
| 인터뷰 뒤 brainstorming 을 실제로 부르는 세션(인터뷰가 주는 다음 세션 줄)의 superpowers 판 확인 | 인터뷰 끝(B-1)은 보통 superpowers skill 을 불러오지 않아 판을 읽을 기준 폴더 경로가 없다 — 그때는 판 확인을 하지 않고 「알 수 없음」 한 줄만 쓴다. 넘김 줄에 판 확인을 싣는 일은 그 줄을 잡은 락들과 함께 다뤄야 한다 | R14 |
| 계획 1 리뷰의 작은 동작 빈틈: 묶음 대조의 `specs_dir` 필수화 · 머리말 앞 빈 줄이면 로드맵 아님 · 한 번에 읽기의 크기 상한 · 원장 git 호출의 lazy fetch 끄기 · `.git` 이름 bare 레포의 멈춤 문장 · check-path 가 로드맵 층을 안 봄 | 지금 값은 맞거나 멈춤 쪽으로 틀린다 | R14 |
| 계획 1 리뷰의 작은 문구 · 테스트 빈틈: 해결자 대체 이름표 · 안 쓰는 kind `bad_value` · 리터럴 락의 끝 슬래시 없는 상수 탐침 · 기계 층 unknown_key · check-path `--root` 글자 접두 테스트 · 지휘자 3단계 부분 문자열 락 · 상태줄 「N분」 문구 · test_merge_check 낡은 이름표 · ReadFailed 사유의 고정 rc · 원장 검사 불가 행의 사유 · 멈춤 정규식 느슨함 · 상태 블록 stderr 두 줄 · 해결자 두 번 부름 · 확인과 add 사이 재대입 · 테스트 1b 이름표 · review-diff `degraded_reason: -` · check-review-scope 대체 락 · resolve-baseline 주석 · ensure 락이 `:` 꼴을 통과 | 동작은 맞고 문구 · 락 세기만 다르다 | R14 |
| 상태 계산 읽기 전용 정적 락(`test_roadmap_status.sh`)의 남은 후보 여덟: 함수 안 import 의 import 시점 코드 · 값으로 넘긴 콜백 · 내장 이름 재바인딩 · 클래스 메서드 이름 판정 · 물려받은 메서드 · import 표 스코프 · `print(file=)` · 바깥 검사의 금지 목록 방식 | 정적 락을 더 조이는 일 — 같은 테스트의 행동 검사(읽기 전용 파일 시스템 · git/gh 기록 stub)가 이 길들의 쓰기 · 네트워크를 이미 잡는다 | R14 |
| 끝 없는 브랜치 판정의 여러 브랜치 블록 틈 — 블록의 첫 브랜치가 머지돼 승인된 설계문서가 기본 브랜치에 오면, 아직 만들지 않은 다음 브랜치도 같은 이름의 옛 MERGED PR 로 끝 없이 판정돼 머지됨이 될 수 있다 | 시작 흔적이 블록 단위라 브랜치를 가르지 못한다. 더 단단한 길: 옛 PR 의 `mergeCommit` 이 그 에픽의 설계문서(산출물)를 기본 브랜치에 처음 더한 커밋의 조상이면 그 PR 은 에픽보다 먼저라 세지 않는다 — 승인 줄 없는 산출물 블록도 덮는다 | R14 |

## 지휘 기록

- spec 승인 · 2026-10-20 · 「승인 — 계획 담당자에게 (권장)」
- R8 계획 2 Task 10 · 2026-10-22 · EnterWorktree 뒤 PostToolUse 훅 호출을 실측하지 못했다(격리 설치는 로그인되지 않고 로그인은 대화형이다) — §10 RC82 답을 「부분」으로 고치고 project-init README 에 공시했다. matcher 는 `Bash|EnterWorktree` 로 둔다(안 불려도 비용이 없다). Claude Code 훅 문서는 PostToolUse 가 모든 도구 호출 뒤에 불린다고 적는다 — 문서 근거, 실측 아님.
- R8 계획 2 최종 리뷰 · 2026-10-22 · 끝 없는 브랜치의 PR 판정(§4 「브랜치가 지워져 끝이 없으면」)을 지워진 브랜치로 좁혔다 — 이 에픽의 승인된 설계문서나 그것을 가리키는 계획이 기본 브랜치에 없으면 아직 만들지 않은 브랜치로 보고, 같은 이름의 옛 MERGED PR 을 세지 않고 알림 한 줄을 보인다(AC15). 재결정이 아니다 — §4 · AC15 가 정한 범위로 구현을 맞췄다.
- R8 계획 2 통합 리뷰 · 2026-10-22 · 업그레이드 회귀를 찾았다 — `pr-refresh --reset` 뒤 로컬 끝이 원격에 뒤처진 머지된 에픽 일곱이 「PR 판정이 이긴다」(§4) 때문에 머지 안 됨으로 돌아갔다. 조용히 바꾸지 않고 사용자 동의로 재결정했다(U17) — 머지 커밋 근거 먼저(fcf7d300).

## Metadata

- 에픽: R8 · 브랜치 `feature/dependency-portability` · 의존 R2a · R5(머지됨) · 구현은 R10 · R12 · R13 머지 뒤(U10 — 로드맵 의존 칸은 재분해 PR 로 고친다)
- 버전: 계획마다 spec-distill(과 건드린 플러그인) minor bump

### Deferred to plan

- `--snapshot` 을 넘기는 테스트 · 픽스처 전부(리뷰가 찾은 것만 10개 — test_ledger_wiring · test_reviewing_spec_residue · test_state_storage_e2e · test_seed_review_log · test_framing_review_contract · test_seed_review_profile · test_reviewing_brief_residue · shared fixtures cases.sh · cases_advice.sh · test_docreview_gate_visibility)를 계획이 다시 세어 함께 고친다.

- 레포 설정 파일의 최종 이름과 위치 · 의존 목록 파일의 이름과 꼴.
- 판을 재는 명령이 Claude Code 판 · superpowers 판을 어디서 얻는지(Claude Code 는 상태줄 입력의 `version` 또는 기록만, superpowers 는 스크립트가 skill 기준 폴더를 볼 수 없으므로 개발 세션의 모델이 본 경로를 명령에 넘기는 꼴 등 — 설치 기록 파일은 쓰지 않는다).
- 네트워크 진입 셋의 정확한 자리와 `ls-remote` 시간 상한.
- machine.md PR 캐시 칸의 꼴.
- `.claude/worktrees/` 를 무시하지 않는 레포에서 qg 가 하는 일의 실측.

| # | 항목 |
|---|---|
| 16e1de69#r1.1 | 참고(data_flow) #1-값-해결자-하나 — 레포 설정 파일을 기본 브랜치 판에서만 읽게 해서, 기본 브랜치 참조(origin/HEAD)가 없는 레포에서는 해결자가 무엇을 내는지 정해져 있지 않다. 인터뷰 폴더처럼 어디서나 필요한 값까지 여기에 걸린다. — 고치면: 기본 브랜치 참조가 없을 때 해결자가 할 일을 하나로 정한다. 하나는 모든 키에서 「기본 브랜치를 알 수 없다 — 설정을 읽지 못했다」로 멈추고 `git remote set-head origin --auto` 를 안내하는 것(이러면 인터뷰 진입도 멈춘다). 다른 하나는 기본값을 쓰되 출처를 「기본값(기본 브랜치 없음 — 설정 파일 못 읽음)」으로 표시하고, 작업 트리에 설정 파일이 있으면 크게 알리는 것. 어느 쪽인지 정한 뒤 멈추는 자리 목록과 회귀 픽스처(origin 이 없는 레포, origin/HEAD 가 없는 레포)에 반영한다. |
| ed6d45de#r1.1 | 참고(component_relations) #11-계획-나누기 — 계획 1·2 가 고칠 파일 상당수가 R12 의 경로 예약에 들어 있는데, R12 뒤로 미룬 것은 계획 3 하나뿐이다. 새로 생긴 순서 의존(R10 계획 3 · R12)도 로드맵의 R8 의존 칸에 반영되지 않았다. — 고치면: 겹치는 파일마다 R12 와의 순서를 정한다(계획 1·2 도 R12 뒤로 두거나, 겹치는 부분만 떼어 R12 뒤의 계획으로 옮긴다). R10 계획 3 · R12 에 기대는 순서는 재분해 신호로 올려 사용자 승인을 받은 뒤 로드맵 R8 의존 칸에 싣는다. |
| 857a11f3#r1.1 | 참고(feasibility) #2-로드맵--인터뷰-폴더 — 일반적인 Git 커밋은 빈 디렉터리를 보존하지 않으므로 기본 브랜치 트리만으로 폴더 부재와 빈 폴더를 구별할 수 없다. 새 레포에서 처음 만든 로드맵 폴더도 첫 커밋 전에는 기본 브랜치에 없다. — 고치면: 허용 폴더 경로는 기본 브랜치의 설정에서 얻고, 커밋할 폴더의 존재·대소문자·경로 안전성은 실제 작업공간에서 검사한다. 커밋할 파일 유무는 인덱스에서 확인한다. 새 로드맵 폴더가 기본 브랜치에 없다는 이유만으로 첫 커밋을 막지 않는다. |
| a6c6dbd6#r1.1 | 참고(feasibility) #3-기본-브랜치--원격--브랜치-이름 — project-init 훅은 Bash 도구 뒤에만 불려서, 「실행 뒤 새 브랜치를 관찰한다」고 해도 네이티브 EnterWorktree 로 만든 브랜치는 여전히 보지 못한다. 그런데 이것이 묶음 위험의 핵심 사례다. — 고치면: 훅이 불리는 범위를 정한다. 예: hooks.json 의 matcher 를 Bash 와 EnterWorktree 로 넓히고 Files to Modify 에 hooks.json 을 더한다. AC13 에 EnterWorktree 를 명시하고 픽스처로 확인한다. 다른 길: 관찰을 다른 이벤트(세션 시작 · 지휘자 걸음)로 옮긴다. 아니면 EnterWorktree 는 덮지 못한다고 README 에 공시하고 묶음 위험의 답을 「부분 해소」로 고친다. |
| 582211a1#r1.1 | 참고(data_flow) #4-머지-판정--squash--rebase — 커밋 해시가 같다고 PR의 출처 레포까지 같지는 않다. fork가 같은 커밋과 브랜치 이름을 가지면 다섯 조건을 모두 통과할 수 있고, 브랜치 끝이 없을 때는 해시 비교마저 빠진다. — 고치면: 머지 판정에 PR의 원본 레포가 origin과 같다는 조건을 추가한다. gh가 제공하는 headRepository와 isCrossRepository로 출처를 확인하고, 출처를 확인하지 못한 PR은 자동 완료 판정에 쓰지 않는다. 브랜치 삭제 여부와 무관하게 이 조건을 적용한다. |
| 151b882b#r1.1 | 참고(feasibility) #5-의존--gh-필수--개발-당시-판--부재 — 새 버전 비교 코드를 추가해도 이미 실행 중인 구버전에는 그 검사가 생기지 않는다. 현재 기계 상태 판독기는 추가 frontmatter를 무시하며, 구버전이 처음 상태를 쓰면 비교할 더 높은 작성 버전도 없다. 따라서 이 장치만으로 저장소보다 낡은 실행 코드를 막는다는 보장은 성립하지 않는다. — 고치면: 기계 상태의 버전 검사가 보장하는 범위를 해당 검사를 갖춘 버전 사이로 명시한다. 최초 도입은 플러그인 갱신과 세션 재시작을 전제로 한다. devbrew 저장소의 소스 버전과 실행 버전 대조는 이미 있는 version_report를 재사용하고, 기계 상태 작성 버전 대조와 별개의 검사로 설명한다. |
| 8d270fe0#r1.1 | 참고(overdesign) #7-쓰는-세션의-신뢰--r2a-넘김-넷 — shrink: begin-round 가 호출자에게 스냅숏을 받은 뒤 엔진이 같은 스냅숏을 다시 계산해 대조하는 것은 구조가 하나 더 많다. 엔진이 계산할 수 있다면 받을 필요가 없다. — 고치면: begin-round 가 상태에 적힌 문서에서 스냅숏을 직접 계산하고 `--snapshot` 인자를 없앤다(호환을 고려하지 않으므로 진입 skill 셋의 호출만 바꾼다). 대조와 거부 오류 갈래가 사라진다. └ 천장: 호출자가 넘기는 스냅숏이 엔진이 다시 만들 수 없는 정보를 담는 경우(여러 파일 번들 · 엔진이 모르는 경로)가 있으면 지금 설계(받고 대조)로 올린다. |
| fccf272b#r1.1 | 참고(ambiguity) #acceptance-criteria — 본문은 기계 상태를 포함한 네 출처를 정의하지만 인수 기준은 세 출처만 합치도록 요구한다. 임시 테스트 설정의 우선순위를 검증할 기준이 서로 다르다. — 고치면: 인수 기준을 본문과 같은 네 출처 순서인 로드맵 → 기본 브랜치의 레포 설정 → 기계 상태의 임시 설정 → 상수로 정리한다. |
| f7e40deb#r1.1 | 참고(ambiguity) #goals — 목표는 Claude Code · superpowers · qg 판까지 「진입에서 확인한다」고 적었다. 본문은 Claude Code 판을 기록만, superpowers 는 알리기만 하고, qg 판은 언급하지 않는다. 있는 것 검토의 「plugin.json dependencies(실측 뒤 사용)」가 무엇에 쓰이는지도 본문에 없다. |
| a430e0e3#r1.1 | 참고(component_relations) #3-기본-브랜치--원격--브랜치-이름 — 브랜치 이름 규칙의 출처가 둘로 갈린다. spec-distill 은 레포 설정의 branch_prefix 로 브랜치를 만들고, project-init 훅은 자기 규칙 파일로 새 브랜치를 검사한다. 두 값이 다르면 지휘자가 만드는 브랜치마다 훅이 「규칙 밖」이라고 알린다. 문서는 이 어긋남을 다루지 않는다. — 고치면: 두 규칙이 어긋날 때 어떻게 할지 정한다. (가) 레포 설정 파일의 branch_prefix 를 project-init 훅도 읽는 하나의 출처로 삼는다. 둘 다 같은 레포 파일을 읽으니 플러그인끼리 서로를 부르는 결합은 생기지 않는다. (나) 결합하지 않는 쪽을 유지하고, 두 값이 다를 수 있다는 점과 맞추는 방법을 두 플러그인 README 에 적는다. 어느 쪽이든 회귀 픽스처(접두가 서로 다른 레포)를 하나 둔다. |
| 6028abe1#r2.1 | 참고(feasibility) #9-작업공간이-여럿일-때 — 기존 상태 경로 계산은 bare 레포마다 분리되지 않는다. 실제 함수에 /repos/a.git과 /repos/b.git을 넣으면 둘 다 /repos/.claude/spec-distill을 반환한다. 작업공간 사이의 동일성만 검사하면 서로 다른 레포의 상태 충돌을 놓친다. — 고치면: 상태 루트는 같은 레포의 작업공간끼리는 공유하고 서로 다른 레포끼리는 분리한다. 일반 레포는 기존 위치를 유지하되, bare 기반 작업공간은 해당 공용 git 디렉토리 내부의 전용 위치를 사용한다. 그 위치에 맞춰 Git 추적 검사 적용 여부를 정하고, 같은 부모 폴더에 있는 서로 다른 bare 레포의 상태가 분리되는지도 검증한다. |
| fe43b0e0#r2.1 | 참고(ambiguity) #1-값-해결자-하나 — 로드맵 층은 「`roadmap_model` 이 아는 키 — `type` · `source_brief` 등」에 대해 닫힌 집합이라고 했지만, roadmap_model 에는 그런 키 목록이 없다(source_brief 가 있는지만 검사한다). 「등」 때문에 어떤 키를 모르는 키로 보고 멈출지 정해지지 않는다. 받는 로드맵 머리말 키를 이름으로 모두 적어야 한다. |
| 594338de#r2.1 | 참고(handoff_incomplete) #11-계획-나누기 — 계획 나누기에서 §3 의 브랜치 접두 불릿(여섯째)이 어느 계획에도 들지 않는다. 계획 1 은 「§3 앞 다섯 불릿」, 계획 2 는 「§3 끝 불릿(RC82)」만 가져가서, `branch_prefix` 설정과 AC12 를 맡는 계획이 없다. |
| 4799696d#r2.2 | 참고(ambiguity) #4-머지-판정--squash--rebase — 머지됨 조건의 개수가 문서 안에서 서로 다르다. §4 는 여섯 조건이라 하면서 브랜치 끝이 없으면 「나머지 넷」으로 판정한다고 하는데, 실제로 남는 조건은 다섯이다. §8 표와 검증 계획은 「다섯 조건」이라고 적었다. |
| 7398418d#r2.1 | 참고(handoff_incomplete) #8-조용한-오답--남긴-것--뺀-것 — §8 표에서 두 행이 가리키는 절에 그 내용이 없다. 심볼릭 링크 행은 「해결자가 일반 파일만 읽는 한 줄 확인」을 §1 에 둔다고 하지만 §1 · AC 에 그 줄이 없다. bare 레포 행은 「계획 단계 실측 픽스처 하나」를 §9 에 둔다고 하지만 §9 · AC29 · Deferred to plan 어디에도 없다. |
| f2ae3bc2#r2.1 | 참고(handoff_incomplete) #metadata — Metadata의 구현 순서가 본문에서 확정한 순서와 다르다. 본문은 선행 에픽 세 개가 모두 머지된 뒤 구현하도록 하지만, Metadata에는 일부 선행 조건만 남아 있다. — 고치면: Metadata의 구현 조건을 §11과 동일하게 R10·R12·R13이 모두 머지된 뒤로 고치고, 계획 작성은 미리 가능하다는 구분을 유지한다. |
| 00b21e44#r2.1 | 참고(ambiguity) #7-쓰는-세션의-신뢰--r2a-넘김-넷 — §7 은 「요약값 대조(AC17 나)」와 「엔진 밖 원장 쓰기(AC17 가)」라고 적는데, 이 문서의 AC17 은 상태줄이 캐시와 그 나이를 보이는 기준이다. 이 AC17 은 다른 문서(R2a 설계)의 수용 기준인데 그 문서를 밝히지 않아, 계획 작성자가 이 문서의 AC17 로 읽게 된다. — 고치면: §7 의 두 자리를 「R2a 설계 AC17 가」 · 「R2a 설계 AC17 나」처럼 어느 문서의 기준인지 밝혀 적는다. |
| beb0d8dd#r3.1 | 참고(feasibility) #1-값-해결자-하나 — Git 파일 모드로 LFS 포인터를 판별할 수 없습니다. LFS 포인터도 일반 파일과 같은 100644 모드로 저장되므로, 명시한 검사만으로는 이를 거부하지 못합니다. — 고치면: 파일 모드 검사로 심볼릭 링크 등 허용하지 않는 항목을 거부한다. LFS 포인터는 모드가 아니라 blob 내용으로 식별하고, 설정을 해석하기 전에 지원하지 않는 설정 파일이라는 오류로 멈춘다고 구분해 적는다. |
| e0edd473#r3.1 | 참고(ambiguity) #5-의존--gh-필수--개발-당시-판--부재 — /spec-distill:roadmap-status 가 gh 를 쓰는 진입인지 쓰지 않는 진입인지 문서에 분류가 없습니다. 이 skill 이 부르는 `control_plane.py show` 는 캐시가 없으면 gh 를 직접 부릅니다(gh_lookup_for). 그런데 문서는 이 skill 에 걸친 「gh 없음」 갈래(control_plane.py:763-863)를 지운다고만 적었습니다. 그래서 gh 가 없을 때 지도 보기가 멈추는지, gh 없이 보이는지 알 수 없습니다. |
| 1cdda836#r3.1 | 참고(handoff_incomplete) #files-to-modify — 로드맵 R8 블록의 범위 문장 「gh · superpowers 부재 강등」은 사용자 결정 U1(gh 필수, 대체 길 없음)로도 바뀝니다. 그런데 고칠 파일 목록에는 「(U6 반영)」만 적혀 있습니다. 「U1 · U6 반영」으로 고쳐야 합니다. 번호 대조 S49 행의 「superpowers 부재 강등은 U6 으로 다시 정함」에도 gh 를 더해야 합니다. |
| 89c6be4b#r3.1 | 참고(handoff_incomplete) #상류--하류-연계 — 묶음의 인터페이스 「받는 것: R0 의 『devbrew 밖 레포』 한계 공시」를 어떻게 처리하는지가 없습니다. 「squash · rebase 는 손 머지 줄」이라는 지금의 공시 세 자리를 새 규칙으로 고친다고 적어야 합니다. 세 자리는 roadmap_status.py:40-44 NOTICE · spec-distill README.md:147 · templates/roadmap-template.md:23 입니다. 새 규칙은 다음과 같습니다: PR 상태로 판정한다, 손 머지 줄은 PR 없는 로컬 머지에만 쓴다, 캐시가 없으면 「PR 상태 미확인」을 보인다. |
