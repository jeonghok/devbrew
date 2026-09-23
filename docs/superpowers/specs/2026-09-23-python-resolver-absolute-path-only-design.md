---
name: python-resolver-absolute-path-only
type: design
created_at: 2026-09-23
source_interview: 없음 — /brainstorming 직접 진입. 근거는 PR #162 회고 qg 리뷰(격리 재현 포함)이고 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# 해석기는 절대 경로 PATH 항목만 본다 · Design

> PATH 를 불신하는 것이 이 파일의 일이다. — `shared/python/devbrew-python.sh:14`

## Handoff Context

**TL;DR** — devbrew 훅 해석기 `shared/python/devbrew-python.sh` 가 PATH 의 **절대 경로가 아닌 항목**
(빈 필드·`.`·상대 경로)을 통해 **작업 디렉토리 안의 파일을 실행**한다. 훅의 작업 디렉토리는 사용자가 연
리포다. 해석기의 두 탐색 단계(step 2 bare `python3` · step 3 `python3.*` 글롭)가 모두 절대 경로 항목만
보게 고치고, 해석기를 부르는 훅 command 4자리도 bare `sh` 대신 `/bin/sh` 로 부른다. 배포 사본 3개는
재생성하고, 락에 이 축을 새로 세운다. **범위는 devbrew 가 실행하는 명령뿐이다** — 그런 PATH 를 가진 환경은
devbrew 밖에서도 이미 노출돼 있다(Context/Why 5).

**Implicit context** —

(1) 발단: PR #162(`d03fac35`, python 바닥 3.12 + uv) 회고 qg 리뷰의 Tier ②. 같은 리뷰의 Tier ①은 #168 로
머지됐다. Tier ③(기존 락의 이빨 — `test_python_floor.sh:154`·`:168`·`:372`·`:458`)은 이 문서의 범위 밖이며
이 PR 머지 뒤 별도로 진행한다 — 같은 테스트 파일을 건드리므로 **직렬**이다.

(2) 작업 위치: 브랜치 `fix/python-path-absolute-only`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-path-absolute-only`, base `0af757ee`(#168 머지).

(3) 범위(step 2 까지 막는다)는 사용자가 골랐다 — 결정 기록 D1. 훅 command 의 `/bin/sh` 와 Goal 을
devbrew 몫으로 좁힌 것은 설계 리뷰 라운드 1 의 결정이다 — D4.

## 목차

- [Goal](#goal) · [Context / Why](#context--why) · [Goals](#goals) · [Non-goals](#non-goals) ·
  [Constraints](#constraints) · [설계](#설계) · [Acceptance Criteria](#acceptance-criteria) ·
  [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan) ·
  [Rejected Alternatives](#rejected-alternatives) · [알려진 한계](#알려진-한계) · [결정 기록](#결정-기록) ·
  [Metadata](#metadata)

## Goal

**devbrew 가 실행하는 명령**(훅 command 의 셸 · 해석기가 고르는 인터프리터)이, PATH 에 어떤 항목이 있든
**작업 디렉토리의 파일로 풀리지 않게** 한다.

## Context / Why

### 1. 어떻게 실행되나

해석기의 탐색은 두 단계다.

- **step 2** (`:150`) `probe python3` — 이름만 주고 셸의 명령 탐색에 맡긴다. POSIX 셸은 PATH 의 빈 항목을
  현재 디렉토리로 해석하므로, PATH 에 빈 항목이나 `.` 이 있으면 cwd 의 `./python3` 가 실행된다.
- **step 3** (`:163`) `[ -n "$_dir" ] || _dir="."` — 빈 항목을 **명시적으로** `.` 으로 바꾼다. 이어서 `:164`
  글롭이 그 디렉토리의 `python3.*` 를 전부 모으고 `:168` 의 `probe` 가 **바닥 판정 전에** 각각을 실행한다.
  바닥을 만족하는 후보는 `:178` 이 훅 인터프리터로 exec 하고, 훅 JSON payload 가 그 프로세스의 stdin 으로 간다.

`probe` 는 버전을 «물어보는» 함수라, 탈락할 후보도 한 번은 실행된다. 즉 이 경로에서 필요한 것은
「cwd 에 실행 가능한 `python3.<무엇이든>` 파일이 있다」뿐이다.

### 2. 격리 재현 (PR #162 회고, `/bin/sh` = bash 3.2, 시스템 `python3` = 3.9)

리포 밖 임시 디렉토리에서, cwd 에 카나리 `python3.*` 를 두고 해석기를 실행했다.

| PATH | cwd 후보 실행 |
|---|---|
| `:/usr/bin:/bin` (앞 빈 항목) | 실행됨 — 탈락 후보 + 채택 후보 + payload 전달 |
| `/usr/bin::/bin` (중간 빈 항목) | 실행됨 |
| `.:/usr/bin:/bin` (리터럴 `.`) | 실행됨 |
| `/usr/bin:/bin:` (끝 빈 항목) | 미접촉 — IFS 필드 분할에서 끝 빈 필드가 소실 |
| `/usr/bin:/bin` (절대만) | 미접촉 — 음성 대조 |

끝 빈 항목이 step 3 에서 안전한 것은 설계가 아니라 필드 분할의 우연이다.

step 2 는 따로 쟀다(2026-09-23, 격리 임시 디렉토리, cwd 에 `python3` 와 `rel/python3`, 절대 부분 `/bin` 에는
파이썬 없음). `/bin/sh`(bash 3.2) · `dash` · `ksh` · `zsh` **넷 모두**에서 `:/bin` · `/bin::/usr/sbin` · `.:/bin` ·
`/bin:` · `rel:/bin` 다섯 형태가 전부 cwd 쪽 파일을 실행했고, `/bin` 만일 때는 `not found` 였다. 즉 step 2 에서는
**끝 빈 항목과 상대 경로도** cwd 를 연다. **PATH 전체가 빈 문자열**(`PATH=`)이면 `/bin/sh` · `dash` · `zsh` 는 cwd 의
`python3` 를 실행했고 `ksh` 만 `not found` 였다. PATH 가 아예 없으면(unset) 넷 다 실행하지 않았다.

훅 command 의 모양(`/bin/sh -c "sh <스크립트>"`)도 쟀다. cwd 에 카나리 `sh` 를 두면 `:/usr/bin:/bin` · `.:/usr/bin:/bin`
에서 **카나리 `sh` 가 돌았고** 스크립트는 돌지 않았다. `/usr/bin:/bin:`(끝 빈 항목)과 `/usr/bin:/bin` 에서는 진짜 `sh` 가
돌았다 — 끝 빈 항목은 `/bin/sh` 를 먼저 만나서 안전했을 뿐이다. 즉 해석기에 닿기 **전에** 훅 command 의 bare `sh`
가 같은 방식으로 cwd 를 연다.

### 3. 상속인가 신규인가

**상속된 노출의 증폭**이다. #162 이전 hooks.json 의 `python3 <훅>.py` 도 같은 셸 탐색을 했고, step 2 가
그것을 그대로 보존한다. #162 의 diff 가 넓힌 것은 (a) 파일명 1개(`python3`) → `python3.*` 전부,
(b) PATH 첫 매치 → 모든 항목, (c) 탈락 후보의 실행이다. 이 설계는 증폭분(step 3)과 상속분(step 2)을
함께 닫는다(D1).

### 4. 누가 그런 PATH 를 갖나

`export PATH=$PATH:` · `PATH=:$PATH` 처럼 셸 설정에서 구분자를 하나 더 붙이는 실수가 빈 항목을 만든다.
`.` 을 PATH 에 넣는 설정도 드물지만 존재한다. 공격자는 PATH 를 바꿀 필요가 없다 — 그런 PATH 를 가진
사용자가 **공격자가 만든 리포를 열기만** 하면 된다. `SessionStart` 훅이 세션 시작 시 자동으로 돈다.

### 5. devbrew 밖의 노출 — 이 설계가 닫지 못하는 것

같은 격리 디렉토리에서 node 의 `child_process` 를 쟀다(2026-09-23). cwd 에 카나리 `git` 을 두면
`execFileSync('git')` · `spawnSync('git')` · `execSync('git …')` 셋 모두 `:/usr/bin:/bin` 과 `.:/usr/bin:/bin` 에서
**카나리를 실행했고**, `/usr/bin:/bin` 에서만 진짜 `git` 을 실행했다. 즉 PATH 에 절대 경로가 아닌 항목이 있는
사용자는 **bare 이름으로 명령을 부르는 모든 도구**에 대해 이미 노출돼 있다. Claude Code 가 세션 시작에 bare
`git` 을 부르는지는 재지 않았다.

그래서 이 설계의 몫은 「그런 환경을 안전하게 만든다」가 아니라 **「devbrew 가 그 노출을 더하거나 증폭하지
않는다」**다. 방어 심층의 한 겹이고, Security 항목도 그 범위로 적는다(D4).

## Goals

1. step 2 와 step 3 모두 PATH 의 **절대 경로 항목만** 탐색한다.
2. 절대 경로 항목만 있는 PATH 에서는 해석 결과가 지금과 **같다** — 같은 인터프리터를 고른다.
3. 훅 command 4자리가 해석기를 `/bin/sh` 로 부른다 — bare `sh` 탐색을 거치지 않는다.
4. 새 축이 락에 선다: 절대 경로가 아닌 항목이 cwd 파일을 실행하지 못한다는 것을 **실행으로** 잰다.
5. 배포 사본 3개가 정본과 계약대로 일치한다.

## Non-goals

- **`DEVBREW_PYTHON` 의 상대 경로.** 사용자가 명시적으로 지정한 값이다 — step 1 은 그대로 둔다.
- **훅 자식 프로세스가 받는 PATH 정리.** 훅 파이썬이 이후에 spawn 하는 명령의 PATH 는 이 해석기의 일이 아니다.
- **bash 의 exported function**(`BASH_FUNC_python3%%`). 환경 변수를 조작할 수 있는 공격자는 이미 다른 수단이 있다.
  더구나 이 설계 이후 step 2 는 이름 `python3` 를 셸 탐색에 맡기지 않고 절대 경로로 exec 하므로 함수 이름
  해석을 타지 않는다.
- **Tier ③**(기존 락의 이빨) — Handoff Context (1).
- **환경 전체의 노출.** Claude Code 나 다른 도구가 bare 이름으로 부르는 명령(Context/Why 5)은 devbrew 가 고칠 수
  없다.

## Constraints

1. **C1 — 외부 명령 0개.** 해석기 머리말(`:12-14`)의 불변식이다: `tr`·`sed` 를 쓰면 PATH 에 `/usr/bin` 이
   없을 때 kill switch 판정이 fail-open 한다(실측). 새 코드도 셸 내장(`case`·`[`·`set`)만 쓴다. 락의 축 A4 가
   coreutils 없는 PATH 로 이것을 이미 잰다.
2. **C2 — kill switch 가 모든 탐색보다 앞선다.** 변경은 step 2·3 안에서만 일어난다.
3. **C3 — stdin 을 건드리지 않는다.** `probe` 의 `</dev/null` 계약(`:90-95`)은 그대로다.
4. **C4 — 배포 사본은 `copy-of` 계약을 탄다.** 정본을 고치면 `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh`
   3개를 재생성해야 하고, 아니면 `test_python_floor.sh` 축 B 가 RED 다.
5. **C5 — `set -f` 는 분할 동안만.** PATH 항목에 글롭 문자가 있어도 분할이 파일시스템을 보지 않게 한다 — 기존
   `scan_path` 의 관용구를 그대로 쓴다.
6. **C6 — 락은 리포 밖에서 재현한다.** 새 축의 cwd 는 락의 `$TMP` 아래 디렉토리다. 리포 작업 트리에 카나리를
   만들지 않는다.

## 설계

### 1. 판정 규칙

PATH 항목 `d` 는 `case "$d" in /*)` 에 걸릴 때만 탐색 대상이다. 그 밖(빈 문자열 · `.` · `..` · `bin` ·
`./x` · `~/bin` 처럼 셸이 전개하지 않은 틸드)은 **건너뛴다.** 경고도 내지 않는다 — 이 해석기의 stdout 은
C7(#162 설계)에 묶여 있고, 건너뛴 항목은 사용자에게 알릴 사건이 아니다.

### 2. step 3 — `scan_path`

`:163` 의 `[ -n "$_dir" ] || _dir="."` 를 `case "$_dir" in /*) ;; *) continue ;; esac` 로 바꾼다. 나머지
(글롭 · `-f`·`-x` · `-config` 배제 · probe · 바닥 판정)는 그대로다.

### 3. step 2 — `first_python3`

`probe python3` / `exec python3` 를 새 함수로 바꾼다. 함수는 `scan_path` 와 같은 관용구로 PATH 를 분할하고,
절대 경로 항목만 **PATH 순서대로** 보며 `-f` 이고 `-x` 인 첫 `$d/python3` 를 찾는다. 찾으면 그 **절대 경로**를
probe 하고, 바닥을 만족하면 그 경로로 exec 한다.

셸 탐색과 달라지는 것은 절대 경로가 아닌 항목을 건너뛴다는 한 가지다:

- 첫 번째 `python3` 만 본다 — 셸 탐색도 그렇다. 그것이 probe 에 실패하거나 바닥 미만이면 **다음 `python3` 를
  찾지 않고** step 3 로 간다(지금과 같다 — D3). **`scan_path` 와 다른 점이 여기다**: `scan_path` 는 후보가
  탈락하면 `continue` 해 다음 후보를 보지만, `first_python3` 는 분할 관용구만 빌리고 **첫 `-f`·`-x` 매치에서
  루프를 끝낸다.** 탈락 판정은 루프 밖에서 한다.
- `-f` 는 심볼릭 링크를 따라간다 — 홈브루·pyenv shim 처럼 링크인 `python3` 가 지금처럼 잡힌다.
- 디렉토리나 실행 비트 없는 파일은 건너뛴다 — 셸 탐색도 그렇다.

### 4. 두 함수의 분할 코드

PATH 분할 4줄(`_ifs_save` · `IFS=":"; set -f` · `set -- ${PATH-}` · 복원)은 두 함수에 각각 둔다. POSIX sh
함수는 목록을 돌려줄 수 없어서, 공용화하면 위치인자를 전역에서 덮어쓰거나 문자열을 다시 분할해야 한다 —
둘 다 지금의 4줄보다 읽기 어렵다.

### 5. 안내 문구

절대 경로가 아닌 항목에만 인터프리터가 있던 사용자는 이제 step 4(fail-open)로 떨어지고 `SessionStart` 안내를
받는다. 기존 문구(「PATH 에 두거나 … `$DEVBREW_PYTHON` 에 그 경로를 지정하라」)가 이미 해법 둘을 담고
있으므로 문구는 바꾸지 않는다.

### 6. 훅 command — `/bin/sh`

훅 4자리(`plugins/quality-gates/hooks/hooks.json` 의 두 자리 · `plugins/spec-distill/hooks/hooks.json` ·
`plugins/project-init/hooks/hooks.json`)의 `"sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh …"` 를
`"/bin/sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh …"` 로 바꾼다. #162 가 `sh <경로>` 를 고른 근거(실행
비트가 설치 캐시까지 살아남는지 모른다 — #162 설계 C8)는 `/bin/sh <경로>` 도 그대로 만족한다. `/bin/sh` 는
POSIX 가 경로를 정하지는 않지만 macOS·Linux 에서 실재하고, 해석기의 shebang(`#!/bin/sh`)이 이미 같은 경로를
전제한다.

## Acceptance Criteria

카나리 = 실행되는 순간 **자기 마커 파일을 남기고** 바닥을 만족한다고 답하는 가짜 인터프리터. 마커 기록은
셸 내장 리다이렉션으로 한다(C1 과 같은 이유 — 좁힌 PATH 에 `touch` 가 없을 수 있다).

- **AC1** step 3 — cwd 에 카나리 `python3.99` 를 두고, PATH 의 절대 경로 부분에는 파이썬이 없는 상태에서
  PATH 네 형태(앞 빈 항목 · 중간 빈 항목 · `.` · 상대 경로 `rel` 과 cwd 의 `rel/python3.99`)마다 해석기를
  실행한다. **마커가 생기지 않는다.**
  *변이*: `case` 한 줄을 원래의 `[ -n "$_dir" ] || _dir="."` 로 되돌리면 넷 모두 RED — 원래 줄은 빈 항목을
  `.` 으로 바꾸고, `.` 과 `rel` 은 빈 값이 아니라 그대로 글롭된다.
- **AC2** step 2 — cwd 에 카나리 `python3`(점 없음)와 `rel/python3` 를 두고, PATH 여섯 형태(AC1 의 넷 + 끝 빈
  항목 + 빈 문자열 `PATH=`)마다 해석기를 실행한다. 상대 경로 형태는 `rel/python3` 를, 나머지는 cwd 의 `python3`
  를 겨눈다. **마커가 생기지 않는다.**
  *변이*: step 2 를 `probe python3` / `exec python3` 로 되돌리면 여섯 모두 RED(Context/Why 2 의 step 2 측정 —
  빈 PATH 는 `/bin/sh` 에서 cwd 로 풀린다). AC2 의 cwd 에는 점 있는 `python3.*` 가 없으므로 step 3 변이(m1)로는
  RED 가 되지 않는다 — 두 축이 갈린다.
- **AC3** 양성 대조 — AC1·AC2 의 카나리 디렉토리를 **절대 경로로** PATH 에 넣으면 마커가 생기고 대상이 돈다.
  이것이 없으면 AC1·AC2 의 「마커 없음」은 카나리가 고장 나도 통과한다.
- **AC4** 올바른 선택 — PATH 가 앞 빈 항목 + 바닥 만족 인터프리터가 있는 절대 디렉토리일 때, cwd 카나리가
  아니라 **그 절대 디렉토리의 인터프리터로** 대상이 돌고 payload 가 온전하다.
- **AC5** 무회귀 — `shared/tests/test_python_floor.sh` 의 기존 단언이 전부 통과한다(현재 131/131, 축 C 의 기대
  형태는 AC9 에 맞춰 갱신한 뒤). 해석 경로(step 2·3)에 닿는 기존 케이스는 전부 절대 경로 PATH 를 쓰고(Goal 2),
  `PATH=` 로 도는 A4a 는 kill switch 에서 먼저 끝난다.
- **AC6** 배포 — `test_python_floor.sh` 축 B 와 `shared/tests/test_copy_of_contract.sh` 가 통과한다(사본 3개 재생성).
- **AC7** 버전 — 사본을 가진 세 플러그인 `plugin.json` 이 각각 patch bump 되고, 각 CHANGELOG 에 `### Security`
  항목이 있다. `shared/tests/test_changelog_integrity.sh` 가 통과한다.
- **AC8** 첫 `python3` 만 본다(D3) — PATH 가 절대 디렉토리 둘 `A:B` 이고 `A/python3` 는 바닥 미만, `B/python3` 는
  바닥 만족 카나리(마커를 남긴다)이며 어디에도 `python3.*` 가 없다. 대상이 **돌지 않고** `B` 의 마커가 **생기지
  않는다.**
  *변이* m3: `first_python3` 가 첫 후보 탈락 시 다음 `python3` 로 `continue` 하게 바꾸면 **이 AC 만** RED.
- **AC9** 훅 command — 훅 4자리의 command 가 `/bin/sh ` 로 시작한다(축 C 의 기대 형태). 그리고 실행으로도 잰다:
  각 command 를 `CLAUDE_PLUGIN_ROOT=<그 플러그인 디렉토리>` 와 그 플러그인의 kill switch(`DEVBREW_<PLUGIN>_DISABLE=1`
  — 해석기에 닿아도 아무것도 안 하게) 아래에서 `/bin/sh -c "<command>"` 로, cwd 에 카나리 `sh` 를 두고
  PATH `:/usr/bin:/bin` 으로 돌린다. **카나리 마커가 생기지 않는다.**
  *변이* m4: command 한 자리를 `sh …` 로 되돌리면 그 자리가 RED(Context/Why 2 의 훅 형태 측정).

## Files to Modify

| 파일 | 변경 |
|---|---|
| `shared/python/devbrew-python.sh` | step 2 → `first_python3`, step 3 `:163` 교체 |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` | 정본에서 재생성(copy-of) |
| `plugins/quality-gates/hooks/hooks.json` · `plugins/spec-distill/hooks/hooks.json` · `plugins/project-init/hooks/hooks.json` | 훅 4자리 `sh` → `/bin/sh` (AC9) |
| `shared/tests/test_python_floor.sh` | 새 축(AC1~AC4 · AC8 · AC9 실행분) + 축 C 기대 형태 갱신(AC9). `# guards:` 는 이미 `shared/python/**` 와 `plugins/*/hooks/hooks.json` 을 덮는다 |
| `plugins/{project-init,quality-gates,spec-distill}/.claude-plugin/plugin.json` | patch bump |
| `plugins/{project-init,quality-gates,spec-distill}/CHANGELOG.md` | `### Security` |

## Verification Plan

1. `bash shared/tests/test_python_floor.sh` — 기존 131 + 새 축 전부 PASS.
2. **변이 4종** (커밋 후, `git checkout HEAD --` 로 복원하고 `git diff HEAD` 로 확인):
   (m1) step 3 의 `case` 를 원래 줄로 → AC1 의 네 형태가 RED, AC2 · AC8 · AC9 는 GREEN.
   (m2) step 2 를 `probe python3`/`exec python3` 로 → AC2 의 여섯 형태가 RED, AC1 · AC9 는 GREEN.
   (m3) `first_python3` 가 첫 후보 탈락 시 다음 `python3` 로 `continue` → AC8 만 RED.
   (m4) 훅 command 한 자리를 `sh …` 로 → AC9 의 그 자리만 RED.
   각 변이가 **자기 축만** RED 로 만들어야 한다 — 한 변이가 여러 축을 무너뜨리면 축이 분리되지 않은 것이다.
   m2 가 AC8 을 함께 RED 로 만드는지는 m2 의 모양에 달렸다(셸 탐색은 첫 매치만 본다) — 결과를 그대로 기록한다.
3. `bash shared/tests/test_copy_of_contract.sh` · `bash shared/tests/test_changelog_integrity.sh` ·
   `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` 통과.
4. 회고 리뷰의 재현표와 step 2 측정(Context/Why 2)을 격리 디렉토리에서 다시 돌려, 전부 「미접촉」으로 바뀐 것을 본다.
5. 셸 셋(`/bin/sh` · `dash` · `ksh` 중 이 머신에 있는 것)에서 새 축을 돌린다 — 해석기는 `sh` 로 불린다.

## Rejected Alternatives

- **R1 — 끝 빈 항목도 살려서 cwd 로 해석한다** (codex 회고 리뷰 제안). 「`PATH=/x:` 에서 cwd 의 `python3.12` 를
  못 찾는다」는 비대칭 지적은 사실이지만, 처방이 실행 표면을 **넓히는** 방향이다. 이 설계는 같은 비대칭을
  반대 방향으로 — 모든 비-절대 항목을 똑같이 무시하는 쪽으로 — 해소한다. 다음에 누가 「PATH 의미에 맞추자」며
  이것을 되살리지 않도록 여기에 적는다.
- **R2 — step 3 만 고친다.** #162 가 넓힌 부분만 되돌리는 최소 수정. 사용자가 D1 에서 기각했다: step 2 가 같은
  경로로 cwd 의 `./python3` 를 실행하는 한 Goal 을 못 이룬다.
- **R3 — 절대 경로가 아닌 항목을 `$PWD` 기준 절대 경로로 바꿔 탐색한다.** 이름만 바뀔 뿐 cwd 를 여전히 탐색한다.
- **R4 — 해석기 시작 시 PATH 를 정리해 export 한다.** 훅 자식 프로세스의 동작까지 바꾼다(Non-goal) — 해석기의
  책임을 넘는다.
- **R5 — 건너뛴 항목을 stderr 로 경고한다.** #162 설계 C1 이 실측으로 반증했다 — 훅 stderr 는 사용자에게 닿지 않는다.

## 알려진 한계

- **L1** PATH 에 상대 경로(예: `.venv/bin`)를 넣어 인터프리터를 쓰던 사용자는 훅이 그 인터프리터를 못 찾는다.
  `SessionStart` 안내가 `DEVBREW_PYTHON` 을 알려 준다(설계 §5).
- **L2** 절대 경로 항목이라도 쓰기 가능한 디렉토리(예: `/tmp`)라면 이 설계는 막지 못한다. 그것은 PATH 를 설정한
  사람의 선택이고, cwd 가 공격자 리포인 이 문서의 위협과 다르다.
- **L3** 끝 빈 항목의 step 3 케이스는 이 설계 전에도 안전했다(필드 분할). AC1 이 그 형태를 싣지 않는 이유다 —
  m1 변이로 RED 가 될 수 없는 케이스는 단언이 아니라 장식이다.
- **L4** 환경 전체의 노출(Context/Why 5). PATH 에 절대 경로가 아닌 항목이 있는 사용자는 devbrew 밖에서 이미
  노출돼 있다 — 이 설계는 devbrew 가 그것을 더하지 않게 할 뿐이다.
- **L5** `/bin/sh` 의 실재는 macOS(이 머신)에서만 쟀다. Linux 는 관례상 실재하고 해석기 shebang 이 이미 같은
  경로를 전제하지만, Windows(Git Bash 등) 경로는 이 리포가 잰 적이 없다.

## 결정 기록

- **D1 — step 2 까지 막는다.** 사용자가 「둘 다 막기」를 골랐다(2026-09-23). 절대 경로 항목만 있는 PATH 에서
  결과가 같다는 것(Goal 2)과, 파일 머리말이 밝힌 「PATH 불신」과 맞는다는 것이 근거다. 대가는 L1.
- **D2 — 건너뛰되 경고하지 않는다.** R5.
- **D3 — step 2 는 첫 `python3` 만 본다.** 셸 탐색과 같은 의미를 유지해 Goal 2 를 지킨다. 두 번째 `python3` 까지
  보는 것은 동작 변경이라 이 PR 의 범위가 아니다. AC8 이 잰다(리뷰 라운드 1 채택).
- **D4 — 훅 command 를 `/bin/sh` 로 부르고 Goal 을 devbrew 몫으로 좁힌다.** 설계 리뷰 라운드 1 이 훅 command 의
  bare `sh` 도 같은 탐색을 거친다는 것을 지적했고(측정으로 확인 — Context/Why 2), 같은 날 node 도 bare 이름을
  cwd 로 푼다는 것을 쟀다(Context/Why 5). 사용자가 「`/bin/sh` + Goal 좁힘」을 골랐다(2026-09-23). 기각한 쪽은
  「Goal 만 좁히고 `sh` 를 한계로 둔다」 — devbrew 자신이 여는 자리를 남겨 둘 이유가 없다.
- **D5 — 빈 PATH 를 AC2 의 여섯째 형태로, AC2 의 상대 경로 카나리를 `rel/python3` 로 명시한다.** 리뷰 라운드 1 채택.

## Metadata

- 위협 모델: 로컬 — 공격자가 만든 리포를 사용자가 열 때, 사용자의 PATH 에 절대 경로가 아닌 항목이 있으면 코드 실행.
- 심각도 근거: 조건부(PATH 설정 실수 필요) · 자동 트리거(`SessionStart`) · 사용자 권한. 그 조건의 환경은 devbrew
  밖에서도 이미 노출돼 있으므로(L4) 방어 심층의 한 겹이다.
- 관련: PR #162(`d03fac35`) · #168(`0af757ee`) · 설계 `docs/superpowers/specs/2026-09-21-python-floor-and-uv-design.md`.
- 회고 산출물: `~/Downloads/devbrew-qg-pr162-review/`(`HANDOFF.md` ②).

### Deferred to plan

1. 카나리 fixture 의 정확한 모양과 축 이름(기존 축 A~H 옆에 둘지, 축 A 안에 둘지).
2. AC1 의 상대 경로 형태에서 cwd 아래 디렉토리 이름.
3. hooks.json 의 command 문자열을 재는 **다른 락** 전수 — `sh ${CLAUDE_PLUGIN_ROOT}` 를 리터럴로 기대하는 자리를
   리포 전체에서 grep 해 함께 갱신한다(축 C 만이라고 가정하지 않는다).
