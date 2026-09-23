---
name: python-floor-and-uv
type: design
created_at: 2026-09-21
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# 출하 Python 바닥 3.12 + uv 도입 · Design

> 바닥을 **선언**하는 것과 **집행**하는 것은 다른 일이다.
> 선언만 한 바닥은 훅이 읽지 않는다. 그리고 아무도 듣지 않는 채널로 낸 경고는 침묵이다.

## Handoff Context

**TL;DR** — devbrew **훅**의 Python 바닥을 3.12 로 올린다. 바닥은 선언으로 서지 않는다: `python3` 가
macOS 기본 3.9.6 인 머신에서는 어디에 무엇을 적든 훅이 3.9.6 을 집는다. 그래서 훅 자리에 인터프리터
해석기(POSIX sh)를 끼우되 **`sh <경로>` 로 부르고 물리 사본으로 배포한다**. 집행 범위는 **훅 4자리와
훅이 spawn 하는 파이썬 자식 1건**뿐 — 스킬·커맨드가 Bash 로 부르는 자리는 범위 밖이고 그 자리는 실패가
보인다. 안내는 **`SessionStart` 한 자리**에서 `additionalContext` + `systemMessage` 로 낸다(stderr 는
실측으로 아무 데도 닿지 않는다). 개발·검증은 uv 로 재현 가능하게 만든다.

**Implicit context** —

(1) 사용자 요청 원문: 「python 버전을 올려줬으면 해 그리고 여기도 uv로 관리를 해보자」.

(2) 바닥 `3.12` 는 리터럴이 아니라 **도출된 값**이다 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
근거는 Context/Why 1. 다음 재검토 시점도 이 규칙이 정한다(3.12 EOL = 2028-10).

(3) 작업 위치: 브랜치 `feature/python-floor-uv`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-floor-uv`, base `d24d3045`(#159 머지).
착수 직전 base 가 17 커밋 움직였고(agent-transparency 제거) 모든 수치는 그 base 에서 다시 잰 값이다.

(4) **이 문서는 세 라운드의 리뷰를 거친 뒤 사용자 지시로 한 번 «줄여졌다».** 리뷰가 잡은 실측 결함은
전부 반영돼 있고, 제거된 것은 **제품이 아니라 이 문서를 만족시키려고 생긴 항목**들이다 — 경위는
「결정 기록」 D25.

(5) **절 인용은 이름으로 한다.** Context/Why 와 설계가 둘 다 하위 §1~ 을 가지므로 bare `§N` 은 쓰지 않고
「Context/Why 4」·「설계 §2」처럼 적는다.

(6) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
  - [1. 생태계는 어디에 있나](#1-생태계는-어디에-있나)
  - [2. devbrew 의 모집단은 PyPI 가 아니다](#2-devbrew-의-모집단은-pypi-가-아니다)
  - [3. 반례 — 이 머신](#3-반례--이-머신)
  - [4. 리포 실측](#4-리포-실측)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계 (Architecture)](#설계-architecture)
  - [1. 해석기 — `devbrew-python`](#1-해석기--devbrew-python)
  - [2. 훅 통합과 안내](#2-훅-통합과-안내)
  - [3. uv 층](#3-uv-층)
  - [4. 두 바닥의 분리](#4-두-바닥의-분리)
  - [5. 범위 밖](#5-범위-밖)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)
  - [Deferred to plan](#deferred-to-plan)

## Goal

devbrew 의 **훅과 훅이 spawn 하는 파이썬 자식**이 Python 3.12 이상에서 돈다는 것을 집행하고,
개발·검증 환경을 uv 로 재현 가능하게 만든다. 바닥 미만 사용자에게는 침묵이 아니라, **도달이 실측된
채널로** 세션당 한 번 안내가 간다.

## Context / Why

### 1. 생태계는 어디에 있나

PyPI 다운로드 로그(`requests`, 2026-03-24 ~ 2026-09-20) 집계:

| 버전 | 점유 | 패치 종료 |
|---|---:|---|
| 3.12 | 30.87% | 2028-10 |
| 3.11 | 24.31% | 2027-10 |
| 3.10 | 14.24% | **2026-10-31** |
| 3.13 | 12.46% | 2029-10 |
| 3.14 | 6.64% | 2030-10 |
| 3.9 | 5.17% | **2025-10 (종료됨)** |
| ≤3.8 | 6.4% | 종료됨 |

3.11 이상 누적 74.3%, 3.12 이상 50.0%.

**이 수치는 사람이 아니라 CI·컨테이너가 대부분이다.** 같은 창에서 `boto3` 를 집계하면 3.9 가 51.5% 로
튀는데 AWS Lambda 런타임이 3.9 에 핀돼 있기 때문이다. 배포판 기준선은 이미 훨씬 위다 — Debian 13 =
3.13, Ubuntu 26.04 LTS = 3.13~3.14. **3.9 를 아직 기본으로 내보내는 주체는 사실상 Apple 뿐이고, 그것이
devbrew 가 부딪히는 벽이다.**

### 2. devbrew 의 모집단은 PyPI 가 아니다

devbrew 는 애플리케이션이 아니라 **플러그인 마켓플레이스**다. `plugins/*/hooks/*.py` 는 메인테이너의
머신이 아니라 **설치한 사람의 머신에서, 그 사람의 PATH `python3` 로** 실행된다. 따라서 「버전을 올린다」는
리팩터링이 아니라 **설치 요구사항을 하나 추가하는 제품 결정**이다. 반대로 `*/tests/` 아래는 이 리포에서만
돈다 — 두 모집단은 다른 규칙을 받는다.

### 3. 반례 — 이 머신

```
python3      -> /usr/bin/python3            3.9.6      ← 훅이 집는 것
python3.12   -> ~/.local/bin/python3.12     3.12.13
uv 가 아는 것: 3.11.15 · 3.12.13 · 3.14.3   (전부 설치돼 있음)
/usr/bin/sh  -> 없음                                   ← sh 는 /bin/sh
```

macOS 26(Darwin 25.6.0)에서도 Apple 의 `/usr/bin/python3` 는 여전히 3.9.6 이다. **이 머신에는 3.12 가
이미 있는데도 `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/x.py` 는 3.9.6 을 집는다.** 즉 어디에 무엇을 적든
훅은 그 선언을 읽지 않는다. 그리고 이것은 메인테이너 본인의 머신이다 — 가장 잘 갖춰진 환경조차 선언만으로는
안 된다는 증명이다.

### 4. 리포 실측

base `d24d3045`. 수치마다 도출 명령을 적는다 — 코퍼스 정의 없이 적힌 수는 다음 사람이 확인할 수 없다.

| 축 | 도출 | 값 |
|---|---|---|
| 플러그인 | `ls plugins` | 4 (plugin-audit · project-init · quality-gates · spec-distill) |
| `.py` 총계 | `git ls-files '*.py' \| wc -l` | 181 (출하 `plugins/*` 비-테스트 70 · 테스트 95 · `shared`·`tools`·`docs` 16) |
| 3.9.6 구문 파싱 | `ast.parse(...)` 전수 (3.9.6 인터프리터) | **181/181, 오류 0** |
| 3.10+ 문법 | `match` · `except*` · `type X` · PEP695 grep | **0건** |
| `hooks.json` | `git ls-files 'plugins/*/hooks/hooks.json'` | 3 파일 · **4 호출 자리** (project-init 만 `matcher: "Bash"`) |
| **훅이 spawn 하는 `python3`** | `plugins/**` 훅·스크립트 `.py` 전수 grep | **1** — `hook_common.py:38-39` 의 TTL-GC |
| 출하 셸의 `python3` (범위 밖) | `plugins/*/scripts/*.sh` | 39건 / 11파일 — **하한**(글롭이 심볼릭 링크를 건너뛴다) |
| 무가드 `import yaml`(출하) | `grep -rlE "^import yaml" plugins --include='*.py' \| grep -v /tests/` | 3 (전부 `quality-gates/scripts/`) |
| 테스트 | bash 205(배제 19) · python 4 디렉토리 648 tests | [baseline](../../audits/2026-09-21-python-floor-baseline.md) |
| `pyproject.toml` · lock · CI · 린터 | Glob | **전부 없음** |
| 플러그인 버전 | `plugin.json` | plugin-audit 0.9.3 · project-init 3.1.1 · quality-gates 7.6.2 · spec-distill 3.2.0 |

`.py` 의 세 갈래(70·95·16)는 합이 181 이고 도출 명령이 서로 다르다 — 「출하」는 `plugins/*` 한정이다.

**코드가 3.10+ 문법을 한 줄도 쓰지 않는다**는 사실이 중요하다. 3.9→3.11 과 3.9→3.12 의 마이그레이션 비용이
동일하다는 뜻이고, 따라서 바닥 선택은 코드가 아니라 **지원 기간과 사용자 분포**만으로 결정된다.

## Goals

1. **훅 4자리와 훅이 spawn 하는 파이썬 자식**이 3.12 이상에서 실행됨을 집행한다 — 선언이 아니라 해석으로.
2. 바닥 미만 머신에서 **조용히 죽지 않는다** — 무엇이 없고 어떻게 고치는지가 **도달이 실측된 채널로**
   세션당 한 번 간다.
3. **kill switch 가 해석기보다 위에 선다** — 훅을 끈 사용자는 아무 말도 듣지 않는다. 판정 의미는 파이썬
   정본과 같다(좁히지 않는다).
4. 개발·검증 환경이 **재현 가능**하다 — 인터프리터와 테스트 의존성이 기억이 아니라 파일에 고정된다.
5. 바닥이 **도출 규칙**으로 **산출물에** 기록돼 다음 상향이 임의적이지 않다.

## Non-goals

1. **출하 표면의 PyYAML 조달.** 무가드 `import yaml` 3건은 이 설계와 **독립적으로 지금도 깨져 있다**.
   같이 묶으면 「버전을 올려서 깨진 건가, 원래 깨져 있었나」 판별이 불가능해진다. 별도 PR.
2. **린터(ruff) 도입.** 181 파일 diff 가 버전 회귀와 섞인다.
3. **스킬·커맨드가 Bash 로 부르는 자리의 `python3`** — 출하 셸 39자리, 스킬 지시문, 문서, 테스트 전부.
   모델이 Bash 로 돌리고 traceback 을 직접 보므로 실패가 시끄럽다. 설계 §5.
4. **69개 `__future__` shim 제거.** 3.14 는 PEP 649 로 deferred annotation 이 기본이라 남겨도 무해하고,
   걷으면 69 파일 diff 에 기능 이득이 0 이다.
5. **CI 도입.**
6. **uv 를 출하 요구사항으로 만들기.** 사용자에게 요구하는 것은 Python 하나로 유지한다.
7. **`SessionEnd`·대화형 TUI 에서의 채널 도달 보장.** 감사가 둘 다 **미측정**으로 남겼다 — 안내를
   `SessionStart` 한 자리로 모은 이유이기도 하다(L2).

## Constraints

1. **C1 — 훅의 텍스트 채널은 대부분 아무 데도 닿지 않는다.** 실측(`claude 2.1.252`, 헤드리스 `-p`,
   8회 실행 · 4 이벤트 · 랜덤 카나리 14개,
   `docs/superpowers/interview/2026-09-01-seam-and-adjudication-interview.audit.md` §8):

   | 채널 | 모델 도달 |
   |---|---|
   | stderr + `exit 0` | **0/1** — `SessionStart` · `UserPromptSubmit` · `PostToolUse(Read)` 각각. `PostToolUse(Bash)` 와 `SessionEnd` 는 **미측정** |
   | `systemMessage` | **0/14** — 사람은 transcript 에서 보지만 모델엔 안 닿는다 |
   | `hookSpecificOutput.additionalContext` | **8/8**(`SessionStart` 3/3) |

   §8.1 이 `quality-gates/hooks/session-start-advisor.py:149-161`(stderr + rc 0)을 이름으로 지목해
   「모델에 안 닿는다」고 적는다. **stderr 만으로 Goal 2 를 충족했다고 말할 수 없다.**
2. **C2 — kill switch 는 보안 컨트롤이고 해석기가 그 위에 앉는다.** 판정은 현재 훅 파이썬 파일 안에 있어
   (`project-init/hooks/post-tool-use.py:204`) 해석기가 파이썬을 안 돌리면 도달하지 못한다. 그리고 그
   판정은 정본(`shared/killswitch/kill_switch_active.py:29-68`)과 **의미가 같아야 한다** — 쉼표 목록 분리 ·
   공백 제거 · **전체 토큰** 대조(부분 일치 금지) · 훅명 **또는 이벤트명** 별칭 · 변수명 `-`→`_`+대문자
   도출. 좁히면 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` 로 끈 사용자가 Goal 3 을 못 받는다.
3. **C3 — 훅은 조언·청소·검증이지 보안 게이트가 아니다.** 해석 실패의 방향은 fail-open 이다.
4. **C4 — 미래 버전을 오늘 열거할 수 없다.** 마이너 버전을 리터럴로 나열하는 해석기는 시간에 대해
   fail-open 이다.
5. **C5 — `python3` 로의 fallback 은 금지.** 바닥 미만으로 떨어지면, 출하 코드가 3.12 문법을 쓰기 시작한
   순간 안내를 띄우기 전에 `SyntaxError` 로 죽는다.
6. **C6 — 해석기는 stdin 을 건드릴 수 없다.** 훅은 payload 를 stdin 으로 받고 **4자리 전부 그것을 읽는다**
   (실측). 해석기는 그 경로 한가운데 서므로 반드시 `exec` 로 넘기고, 이벤트·플러그인·훅 이름은 **인자로**
   받는다.
7. **C7 — 훅의 stdout 은 JSON 문서 «하나»여야 한다.** 훅 자신이 JSON 을 찍는 자리가 있으므로
   (`post-tool-use.py:205`·`:211`·`:218`·`:239`), 해석기가 stdout 에 무엇을 더 찍고 `exec` 하면 문서가
   둘이 되어 파싱이 깨진다. **`exec` 하는 경로에서 해석기의 stdout 은 비어 있다.**
8. **C8 — 실행 비트가 설치 캐시까지 살아남는지는 이 리포에서 측정된 적이 없다.** 그래서 해석기는
   **`sh <경로>` 로 부른다** — 실행 비트에 의존하지 않으면 측정되지 않은 가정이 설계에서 사라진다.
9. **C9 — 감사기는 확장자로 스크립트를 찾고 plugin root «안»만 판독한다.**
   `plugin-audit/scripts/check-shape-completeness.py:114` 의 `_CMD_SCRIPT_RE` 가 `.py`/`.sh` 접미만
   캡처하고, `:157-171` 이 `cand.relative_to(root)` 실패 시 fail-closed 거부한다(회귀 락
   `test_check_shape_completeness.py:194-212`). 그러므로 해석기는 이름이 `.sh` 로 끝나야 하고
   **심볼릭 링크가 아니라 물리 사본**이어야 한다 — 링크면 `.resolve()` 가 `shared/` 로 풀려 세 플러그인
   모두에 거짓 「kill switch 부재」가 난다.
10. **C10 — 물리 사본은 `copy-of` 계약을 타고, 그 계약엔 머리 20줄 제한이 있다.**
    `shared/tests/test_copy_of_contract.sh:44` 의 `HEAD_WINDOW=20` 안에서만 `# copy-of:` 마커를 찾고
    (`:664-667`), `:599` 가 `sed "${lineno}d" | diff -q` 로 **바이트 동일**을 요구한다. shebang·설명·
    마커·도출 규칙 주석이 그 20줄을 나눠 쓴다. 정본과 사본은 **같은 커밋에서** 고친다.
11. **C11 — 정적 검사로는 3.9 실행 가능성을 보장할 수 없다.** `ast.parse(feature_version=(3,9))` 는
    `match`·`except*`·`type X`·PEP695 를 잡지만 **PEP604(`int | None`)는 통과시킨다**. 이 설계는 해석기를
    sh 로 써서 이 제약을 회피한다.

## 설계 (Architecture)

### 1. 해석기 — `devbrew-python`

`shared/python/devbrew-python.sh`, **POSIX sh**. 각 훅 플러그인에 `# copy-of:` **물리 사본**으로 배포(C9·C10).

**왜 sh 인가.** 파이썬으로 쓰면 *그 파일 자체가 3.9 에서 실행돼야 한다* — 3.9 사용자에게 안내를 띄우려면
3.9 가 그것을 읽고 돌릴 수 있어야 하니까. 그러면 C11 의 PEP604 함정이 살아난다. **sh 는 인터프리터
독립이라 그 사슬이 통째로 사라진다.**

```
0. 출하 바닥 상수: FLOOR_MAJOR=3, FLOOR_MINOR=12     ← 출하 바닥의 정본
   머리 주석에 도출 규칙을 함께 적는다 (20줄 예산 — C10)

1. kill switch 를 먼저 본다 (C2)                     ← 어떤 일보다 앞
     DEVBREW_<PLUGIN>_DISABLE=1                      (변수명은 플러그인명에서 도출)
     DEVBREW_SKIP_HOOKS 를 쉼표로 나눠 공백 제거 후
       «전체 토큰» 이 <plugin>:<hook> 또는
                     <plugin>:<event> 와 같으면 해당  ← 부분 일치 금지, 별칭 둘
     해당하면 -> stdout 에 아무것도 쓰지 않고 exit 0
     (이름들은 인자로 받는다 — stdin 불가침, C6)

2. $DEVBREW_PYTHON 이 있으면 «버전을 물어» 판정
     만족  -> exec
     불만족 -> DEVBREW_PYTHON_IGNORED=<사유> 를 환경에 넣고 3 으로
               (stdout 에 쓰지 않는다 — C7. 이 값은 SessionStart 안내가 싣는다)

3. `python3` 의 «버전을 물어» 판정 -> 만족하면 exec  ← 흔한 경우, spawn 1회로 종료

4. PATH 를 훑어 `python3.*` 글롭으로 후보를 모은다    ← 열거하지 않는다 (C4)
     `*-config` 류 제외 · 실행 가능한 것만
     **각 후보도 3 과 «같은 버전 판정»을 받는다**     ← 이름이나 실행 권한은 근거가 아니다
     바닥을 만족하는 «첫 후보»에서 종료

5. 아무것도 없으면 (= exec 하지 않는다):
     - SessionStart 면 안내 JSON 을 stdout 에 하나 찍는다 (설계 §2)
     - 그 밖의 이벤트면 아무것도 찍지 않는다           ← 중복 주입 방지
     - `python3` 로 내려가지 않는다 (C5)
     - exit 0                                         ← fail-open (C3)
```

`exec` 하는 경로(2·3·4)에서 해석기의 stdout 은 **비어 있다**(C7). 캐시는 두지 않는다 — 실측 증가분이
~20ms(spawn 10–17ms · 판정 16ms · 최악 경로 28ms)이고, 캐시는 「새 파이썬을 깔았는데 캐시가 옛것을
가리킨다」는 무효화 버그를 데려온다.

### 2. 훅 통합과 안내

`hooks.json` 3 파일 · 4 자리가 해석기를 **`sh` 로** 경유한다(C8). 이름들은 인자로 넘어간다(C6):

```diff
- "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
+ "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event SessionEnd --plugin spec-distill --hook session-end-cleanup ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
```

**안내는 `SessionStart` 한 자리에서만.** 그 이벤트는 세션당 한 번 뛰고 `additionalContext` 도달이 3/3 로
실측됐다. `PostToolUse` 는 Bash 호출마다 뛰므로 거기서 내면 같은 블록이 매번 모델 컨텍스트에 재주입되는데,
해석기는 상태가 없어 「이미 알렸다」를 알 수 없다. `SessionEnd` 는 애초에 도달이 미측정이다.

안내 JSON 하나에 두 키를 담는다 — `hookSpecificOutput.additionalContext`(모델) 와
`systemMessage`(사람, transcript). 내용은 (a) 발견된 최고 버전, (b) 요구 바닥, (c) 고치는 법 한 줄이고,
`DEVBREW_PYTHON_IGNORED` 가 있으면 그 사실도 함께 싣는다.

| 플러그인 | 훅 | 이벤트 | 해석 실패 시 |
|---|---|---|---|
| quality-gates | session-start-advisor | `SessionStart` | **안내를 내고** 조언 없이 종료 |
| quality-gates | session-end-cleanup | `SessionEnd` | 조용히 청소 생략 |
| spec-distill | session-end-cleanup | `SessionEnd` | 조용히 청소 생략 |
| project-init | post-tool-use | `PostToolUse`(Bash) | 조용히 검증 생략 — **막지 않는다**(C3) |

### 3. uv 층

리포 루트에 세 파일:

| 파일 | 역할 | 근거 |
|---|---|---|
| `pyproject.toml` | `requires-python` = **개발** 바닥 · `[dependency-groups] dev` 에 PyYAML | `uv run --python 3.9` 가 `requires-python` 위반으로 거부됨을 확인 |
| `uv.lock` | PyYAML 을 정확한 버전으로 고정, 커밋 | `.gitignore:104` 가 `#uv.lock` 에 「generally recommended to include … in version control」을 달고 주석 처리해 둠 |
| `.python-version` | **개발** 바닥 — bare `uv run` 이 그 버전에서 돌게 | 없으면 uv 가 조용히 3.14.3 을 고른다(실측) |

실행(이 두 줄은 루트 README 에도 적는다):

```
uv run -m unittest <module>                    # 개발 바닥
uv run --python 3.14 -m unittest <module>      # 천장
```

uv 가 없으면 기존 `python3 -m unittest` 로 degrade 한다. 러너 스크립트도 매트릭스 하네스도 만들지 않는다.

### 4. 두 바닥의 분리

| | 정본 | 집행자 |
|---|---|---|
| **출하 바닥** | `devbrew-python.sh` 의 `FLOOR_*` 상수 | 훅 (해석기) |
| **개발 바닥** | `pyproject.toml` 의 `requires-python` | uv |

지금은 둘 다 `3.12` 다. 같은 숫자지만 **같은 사실이 아니다** — 한 자리에 적으면 갈라지는 날 조용히 거짓이
된다. `.python-version` 은 **개발** 환경을 고르는 파일이므로 개발 바닥을 따라간다.

AC9 가 `개발 ≥ 출하` 를 고정하되 **두 자리를 각각 읽어서** 비교한다. 두 바닥이 실제로 갈라지는 날의
출하 바닥 검증 수단은 **지금 만들지 않는다** — 그때 다시 연다(L4).

### 5. 범위 밖

- **출하 셸 39자리**(`plugins/*/scripts/*.sh`). 전부 스킬·커맨드가 Bash 로 부르는 자리이고, 훅에서 spawn
  되는 셸은 `qg-worktree.sh` 하나인데 그것은 `python3` 를 쓰지 않는다 — 아래 스킬 지시문과 **같은 술어**가
  적용된다. 게다가 그 자리의 stdout 은 훅 채널이 아니라 **데이터**다
  (`run_audit_codex_reviewer.sh:140-144` 가 파이썬 stdout 을 결과 파일로 받는다).
- **스킬·커맨드 지시문의 `python3`.** 모델이 Bash 로 돌리고 traceback 을 직접 본다.
- **69개 `__future__` shim** · **테스트·문서의 리터럴.**

## Acceptance Criteria

- **AC1** `hooks.json` 3 파일 · 4 자리 전부가 `sh <해석기>` 를 경유한다. `"command"` 값이 bare
  `python3 ` 로 시작하는 자리가 **0** 이다.
- **AC2** 해석기는 마이너 버전을 **열거하지 않는다** — PATH 글롭으로 후보를 찾는다.
  *변이*: 글롭을 리터럴 열거로 바꾸면 RED. *양성 대조*: 바닥을 만족하는 가짜 `python3.99` 를 PATH 앞에
  두면 해석기가 그것을 고른다.
- **AC3** PATH 후보도 `python3` 와 **같은 버전 판정**을 받는다.
  *변이*: 바닥 미만인 가짜 `python3.9` 를 PATH 앞에 두면 해석기가 그것을 **건너뛴다**.
- **AC4** 바닥 미만 인터프리터만 있을 때 해석기는 **`python3` 로 fallback 하지 않는다**.
  *변이*: fallback 한 줄을 추가하면 RED.
- **AC5** **kill switch 가 해석보다 먼저고 판정 의미가 정본과 같다** — (a) `DEVBREW_<PLUGIN>_DISABLE=1`,
  (b) `DEVBREW_SKIP_HOOKS` 의 쉼표 목록을 공백 제거 후 **전체 토큰**으로 대조, (c) `<plugin>:<hook>` **과**
  `<plugin>:<event>` 둘 다 별칭, (d) 해당 시 **stdout 이 비어 있고** rc=0.
  *변이*: (b)를 부분 일치로 바꾸면 RED · (c)의 이벤트 별칭을 빼면 RED · 검사를 해석 뒤로 옮기면 RED.
- **AC6** 해석기가 **stdin 을 읽지 않는다** — 훅 4자리가 payload 를 그대로 받는다.
  *변이*: 해석기에 stdin 을 읽는 줄을 넣으면 훅의 payload 파싱이 RED.
- **AC7** 안내는 **`SessionStart` 에서만** 나온다 — 그 밖의 이벤트에서 해석에 실패하면 **stdout 이 비어
  있다**. 안내 JSON 은 문서 **하나**이고 `additionalContext` 와 `systemMessage` 를 **둘 다** 담으며,
  (a) 발견된 최고 버전 · (b) 요구 바닥 · (c) 고치는 법 한 줄을 갖는다.
  *변이*: `PostToolUse` 에서도 찍게 하면 RED · 안내를 stderr 로 되돌리면 RED.
- **AC8** `DEVBREW_PYTHON` 이 바닥을 만족하면 이긴다. 만족하지 못하면 **stdout 에 쓰지 않고** 환경으로
  사유를 넘기며, `SessionStart` 안내가 그 사실을 싣는다.
  *변이*: 해석기가 그 통지를 stdout 에 찍게 하면 JSON 이 둘이 되어 RED · 통지 자체를 없애면 「조용한
  무시」로 RED.
- **AC9** `.python-version` 이 **개발** 바닥과 같은 minor 를 가리키고, 개발 바닥 ≥ 출하 바닥이다.
  테스트가 `pyproject.toml` 과 해석기 **양쪽을 각각 읽어** 비교한다.
  *변이*: `.python-version` 을 지우면 uv 가 천장을 골라 RED · 출하 바닥만 3.13 으로 올리면 RED.
- **AC10** 훅이 spawn 하는 `python3` 가 **0건**이다 — `hook_common.py` 의 TTL-GC 가 `sys.executable` 을
  쓴다(Context/Why 4 의 도출로 코퍼스가 고정된다).
  *변이*: 그 한 자리를 `python3` 로 되돌리면 RED.
- **AC11** 해석기가 **물리 사본**으로 배포된다(`# copy-of:` 머리 주석, 심볼릭 링크 아님) — `plugin-audit`
  의 감사가 세 플러그인에서 `hooks_killswitch` 를 **참**으로 낸다.
  *변이*: 배포를 mode-120000 링크로 바꾸면 그 감사가 거짓 gap 을 내어 RED.
- **AC12** `PATH=/usr/bin:/bin` 로 좁힌 상태에서 훅 4자리를 실행하면 `SessionStart` 만 AC7 의 JSON 을 내고
  나머지 셋은 stdout 이 비며, 넷 다 rc=0 이고 본래 동작은 수행되지 않는다. kill switch 를 켜면
  `SessionStart` 도 조용하다. **테스트는 그 PATH 의 `python3` 가 실제로 바닥 미만인지 먼저 확인한다**(L3).
- **AC13** **도출 규칙이 산출물에 적혀 있다** — 해석기 머리 주석 · 루트 README · 훅을 가진 3개 플러그인의
  README 가 「2026-10 이후에도 패치를 받는 버전 중 최빈 · 다음 재검토는 3.12 EOL(2028-10)」을 담는다.
  *변이*: 그 문장을 지우면 RED.
- **AC14** 훅을 가진 3개 플러그인 README 에 `Python 3.12+` prerequisite 가 있다. **`plugin-audit` 에는
  쓰지 않는다** — 훅이 없고 셸 13자리는 범위 밖이라 그 바닥을 집행하는 주체가 없다.
- **AC15** 신규 락이 `# guards:` 를 선언하고 **`--emit-scanned` 를 지원한다**. 둘 중 하나만 하면
  `test_guards_coverage_bidirectional.sh:71` 이 락을 통째로 실행해 출력을 「스캔한 경로」로 읽고 RED 를 낸다.
- **AC16** `uv.lock` 이 커밋되고 PyYAML 이 정확한 버전으로 고정된다.
- **AC17** 4개 플러그인 모두 version bump + CHANGELOG 항목. **등급은 그 플러그인이 바닥을 집행하는지로
  갈린다** — 훅이 바닥을 집행하는 플러그인(`project-init`·`quality-gates`·`spec-distill`)에서 바닥 상향은
  사용자에게 **breaking** 이므로 breaking 규칙을 따른다(0.x 는 minor, 1.0 이상은 major). 집행하는 훅이
  **없는** 플러그인(`plugin-audit`)에서는 그 바닥을 강제하는 주체가 없어 사용자 쪽 동작이 바뀌지 않으므로
  breaking 이 아니다 — cache key 를 움직이기 위한 **patch** 를 받는다(AC14 의 음의 짝과 같은 근거:
  집행 주체가 없는 자리에 집행의 대가를 물리지 않는다). 리터럴 번호는 머지 직전에 정한다.

## Files to Modify

| 경로 | 종류 | 비고 |
|---|---|---|
| `shared/python/devbrew-python.sh` | 신규 | POSIX sh. 출하 바닥 정본 + 도출 규칙 주석(머리 20줄 — C10) |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` | 신규 | **물리 사본**(`# copy-of:`) — 링크 아님(C9·AC11) |
| `shared/README.md` | 편집 | `## 디렉토리` 표에 `shared/python/` 행 |
| `plugins/{project-init,quality-gates,spec-distill}/hooks/hooks.json` | 편집 | 4 자리 |
| `plugins/quality-gates/hooks/session-start-advisor.py` | 편집 | 안내 JSON 출력 + `DEVBREW_PYTHON_IGNORED` 반영(AC7·AC8) |
| `plugins/spec-distill/scripts/hook_common.py` | 편집 | `subprocess.run(["python3", …])` → `sys.executable` |
| `pyproject.toml` · `uv.lock` · `.python-version` | 신규 | 루트 |
| `README.md` (루트) | 편집 | 실행 두 줄 + 도출 규칙(AC13) |
| `shared/tests/test_python_floor.sh` | 신규 | `# guards:` **+ `--emit-scanned`**(AC15). AC2~AC13 을 덮는다 |
| `plugins/{project-init,quality-gates,spec-distill}/README.md` | 편집 | prerequisite(AC14) + 도출 규칙(AC13) |
| `plugins/*/.claude-plugin/plugin.json` × 4 · `plugins/*/CHANGELOG.md` × 4 | 편집 | version·기록(AC17) |
| `docs/audits/2026-09-21-python-floor-baseline.md` | 신규(완료) | baseline + 러너. 인덱스 등재 완료 |

`plugin-audit` 에는 해석기도 prerequisite 도 두지 않는다 — version·CHANGELOG 만 건드린다.
`.gitignore` 는 편집하지 않는다(`.venv` 무시, `uv.lock`·`.python-version` 은 주석이라 추적된다).

## Verification Plan

1. **baseline 회귀 대조.** 착수 전 `d24d3045` 에서 bash 205 자리 · python 4 디렉토리(648 tests)를 돌려
   rc 와 실패 줄 수·`Ran N` 을 함께 기록했다. 기록물과 러너는
   [`docs/audits/2026-09-21-python-floor-baseline.md`](../../audits/2026-09-21-python-floor-baseline.md)
   에 있고 **선재 RED 4건이 각각의 이유와 함께** 적혀 있다. 구현 후 같은 러너로 자리별 대조하며, python 쪽은
   `failures` 수뿐 아니라 실패한 **테스트 이름**까지 본다.
2. **해석기 변이 테스트.** AC2·AC3·AC4·AC5·AC7·AC8·AC9·AC10·AC11·AC13 각각에 대해 그 AC 에 적힌 변이를
   넣어 RED 를 확인하고, AC2 는 양성 대조(가짜 `python3.99`)까지 돌린다. 통과가 정답인 단언은 모양으로
   이빨을 판별할 수 없다.
3. **PATH 격리 시뮬레이션** (AC12). `PATH=/usr/bin:/bin` 으로 훅 4자리를 kill switch 켠 경우와 끈 경우
   둘 다 실행. 테스트가 먼저 「그 PATH 의 `python3` 가 정말 바닥 미만인가」를 확인한다.
4. **채널 확인** (AC7·AC8). `SessionStart` 의 stdout 을 JSON 으로 파싱해 **문서가 하나인지**와 두 키가
   함께 있는지 보고, 나머지 세 이벤트의 stdout 이 비었는지 본다.
5. **copy-of 동기화** (C10·AC11). `shared/tests/test_copy_of_contract.sh` 를 돌려 정본과 3 사본의 바이트
   동일과 머리 20줄 마커를 확인한다.
6. **커버리지 락 동거** (AC15). `test_guards_coverage_bidirectional.sh` 가 새 락 때문에 RED 를 내지 않는지.
7. **통과-정답 단언의 관측** (AC1·AC14·AC16·AC17). 각각 무엇을 인쇄해 무엇과 대조하면 통과인지를 plan 이
   정한다 — `hooks.json` 의 bare `python3` 자리 수 0, README 3개의 prerequisite 문자열, `uv.lock` 의
   PyYAML 핀, `plugin.json` 4개의 version diff + CHANGELOG 항목.

## Rejected Alternatives

- **R1 — 전면 해석 shim (스킬 지시문 포함).** 마크다운 지시문까지 고쳐야 해 drift 표면이 커진다. 그
  자리들은 실패가 시끄럽다.
- **R2 — `uv run --script` 로 출하까지 조달.** 요구사항이 「Python」에서 「uv」로 바뀌고 uv 미설치 사용자는
  즉사한다.
- **R3 — 바닥 3.11.** 더 보수적인 도출값. 사용자가 3.12 를 선택(D1).
- **R4 — pyproject·lock 없이 `uv run --with pyyaml`.** 철회(D5) — 플래그를 매번 손으로 타야 하고 PyYAML
  버전도 고정되지 않는다.
- **R5 — ruff 동시 도입.** 181 파일 diff 가 버전 회귀 판별을 오염시킨다.
- **R6 — 마이너 버전 열거식 해석.** 내일 추가될 버전을 오늘 열거할 수 없다(C4).
- **R7 — 해석 결과 캐시.** 실측 증가분 ~20ms 가 기각한다. 무효화 버그만 얻는다.
- **R8 — `plugin.json` 에 `requires-python`.** 그 키를 읽는 주체가 없다 — 집행 없는 선언.
- **R9 — 3.9 테스트 레그 / `ast.parse(feature_version=)` 정적 검사.** 해석기를 sh 로 쓰면 3.9 에서 돌아야
  할 파이썬 파일이 없어 잴 대상이 없고, 정적 검사에는 C11 의 구멍이 있다.
- **R10 — 안내를 stderr 로.** 초판의 선택이었고 실측으로 반증됐다(C1 — 0/1 도달). D8.
- **R11 — 훅이 해석기를 직접 exec.** 실행 비트가 설치 캐시까지 살아남는지 측정된 적이 없다(C8).
- **R12 — 집행을 출하 셸 39자리까지.** 라운드 1 에서 채택됐다가 라운드 2 근거로 되돌려졌다(D17) — 그
  자리는 스킬이 Bash 로 부르는 경로이고 stdout 이 데이터라 훅 계약을 씌우면 오염된다.
- **R13 — 해석기를 심볼릭 링크로 배포.** 감사기의 containment 가 세 플러그인에 거짓 gap 을 낸다(C9).
- **R14 — 모든 이벤트에서 안내.** 바닥 미만 사용자가 Bash 호출마다 같은 블록을 모델 컨텍스트로 받는다.
  `SessionStart` 한 자리로 모으면 상태 없이도 세션당 1회가 된다(D26).
- **R15 — 리터럴 불변 원장 · sh↔python kill switch parity 락 · 출하 바닥 전용 검증 환경.** 셋 다
  **제품이 아니라 이 문서를 만족시키려고 생긴 항목**이라 사용자 지시로 제거했다(D25).

## 알려진 한계

- **L1** 해석기는 `python3.*` 라는 **이름 규약**에 의존한다. conda 나 이름이 다른 shim 은 못 찾는다.
  `DEVBREW_PYTHON` 이 탈출구이며 AC7 의 안내가 그 존재를 알린다.
- **L2** **채널 실측은 헤드리스 `-p` 전용이고 `SessionEnd`·`PostToolUse(Bash)` 는 미측정이다.** 안내를
  `SessionStart`(3/3 측정됨) 한 자리로 모은 것이 이 한계에 대한 대응이지만, 대화형 TUI 는 여전히 미측정이다.
- **L3** AC12 의 시뮬레이션은 `PATH=/usr/bin:/bin` 이 바닥 미만 `python3` 를 준다는 **이 머신의 사실**에
  의존한다. Apple 이 그것을 올리면 테스트가 조용히 아무것도 재지 않게 되므로 자기 확인을 넣는다.
- **L4** **두 바닥이 갈라지는 날의 출하 바닥 검증 수단이 없다.** uv 가 `requires-python` 을 집행하므로
  개발 바닥이 높아지면 프로젝트 안에서 출하 바닥을 잴 수 없다. 지금은 두 값이 같아 드러나지 않는다 —
  갈라뜨리는 PR 이 이 자리를 다시 열어야 한다.
- **L5** 스킬·커맨드가 Bash 로 부르는 자리(출하 셸 39자리 포함)는 여전히 사용자의 `python3` 를 집는다.
  의도적이다(D17) — 그 자리는 모델이 실패를 본다. 다만 **출하 파이썬이 3.12 문법을 쓰기 시작하면 이
  한계가 실제 고장이 된다.**
- **L6** 출하 PyYAML 은 여전히 사용자 책임이다(Non-goal 1).
- **L7** 출하 셸 「39건 / 11파일」은 **하한**이다 — 글롭이 심볼릭 링크를 건너뛴다. 범위 밖이라 무해하지만,
  범위를 넓히는 PR 은 거기서부터 재집계해야 한다.
- **L8** 설치 캐시에서의 배포 동작은 비문서다. 물리 사본은 링크 역참조 의존을 제거하지만 설치본의 배치
  자체를 보장하지는 못한다.
- **L9** **안내 채널은 「어느 플러그인을 설치했나」에 달려 있다.** 해석기는 `EVENT = SessionStart` 일 때만
  안내를 내고, `SessionStart` 훅 자리는 `quality-gates` 하나뿐이다. `.claude-plugin/marketplace.json` 은
  네 플러그인을 각각 설치 가능한 것으로 싣는데, `quality-gates` 없이 `spec-distill` 또는 `project-init` 만
  설치한 바닥 미만 사용자는 훅이 조용히 건너뛰어지는 것을 **아무 안내 없이** 겪는다 — 그 사용자에게는
  Goal 2 가 충족되지 않는다. 자리를 늘리는 것은 설계 변경이라 후속으로 미루고, 이 버전에서는 세 README 와
  루트 README 의 산문이 그 의존을 **명시한다**(안내가 온다고 약속하지 않는다).

## Concrete Next Action

`superpowers:writing-plans` 로 구현 계획을 만든다. 첫 Task 는 해석기(`devbrew-python.sh`)와 그 변이
테스트이며, `hooks.json` 편집은 해석기가 변이 테스트로 검증된 **뒤에** 온다.

## 결정 기록

- **D1 — 출하 바닥은 3.12.** 제안은 3.11 이었고 근거는 3.12 가 3.11 사용자 24.3% 를 추가로 잘라내는데
  마이그레이션 비용은 동일하다는 것이었다. 사용자가 실측 분포를 보고 3.12 를 선택했다 — 단일 최빈(30.9%),
  runway 1년 김, 사용자층이 자기 Python 을 직접 관리하는 개발자.
- **D2 — 해석은 훅에만.** 훅과 스킬 지시문의 **실패 가시성 비대칭**이 근거다.
- **D3 — 해석기는 sh.** 파이썬이면 그 파일이 3.9 에서 돌아야 한다는 제약이 생긴다.
- **D4 — 매트릭스 레그를 만들지 않는다.** 사용자 질문(「레그를 꼭 해야할까」)에서 재검토.
- **D5 — uv 를 리포에 들인다.** 초안은 「pyproject·lock 없이 `uv run --with pyyaml`」이었고 사용자 반론
  (「같은걸 안들이는 이유가 있어? 들이는게 좋지않나」)으로 철회했다. 초안 논거의 절반이 이미 무효였다 —
  *「`requires-python` 을 적으면 3.9 레그가 막힌다」* 는 D4 로 레그가 사라지면서 소멸했는데 결론만 남아
  있었다.
- **D6 — ruff 는 제외** · **D7 — 출하 PyYAML 은 별도 PR.**

리뷰 라운드 1 채택:

- **D8 — 안내 채널을 바꾼다.** stderr + exit 0 이 실측으로 반증됐다(0/1 도달).
- **D9 — kill switch 가 해석기보다 위에 선다.**
- **D10 — `sh <경로>` 로 부른다.** 실행 비트가 설치 캐시까지 사는지 측정된 적이 없다.
- **D11 — 집행을 훅의 자식과 출하 셸까지 넓힌다.** **D17 이 되돌렸다.**
- **D12 — Goals 를 실제 범위로 기술한다** · **D13 — 도출 규칙을 산출물에 적는다** ·
  **D14 — `.python-version` 은 개발 바닥을 따라간다** · **D15 — PATH 후보도 같은 버전 판정을 받는다.**
- **D16 — baseline 을 리포에 커밋한다**(차단 ask).

리뷰 라운드 2 채택 — **라운드 1 수정이 만든 회귀를 잡은 라운드다**:

- **D17 — D11 을 되돌린다. 출하 셸 39자리는 범위 밖.** 그 39자리가 전부 스킬·커맨드가 Bash 로 부르는
  자리이고 훅에서 spawn 되는 셸은 `python3` 를 쓰지 않는다는 실측이 근거다. 이 한 결정이 파생 결함 4건을
  함께 해소했다.
- **D18 — 해석기를 물리 사본으로 배포한다.** 링크면 감사기 containment 가 세 플러그인에 거짓 「kill
  switch 부재」를 낸다. 감사기 완화도 검토했으나 보안 감사기를 약화시키므로 기각.
- **D19 — AC12 의 PATH 에 `/bin` 을 넣는다.** 이 머신에 `/usr/bin/sh` 가 없어 D10 이 그 테스트를 조용히
  무효화하고 있었다.
- **D20 — `DEVBREW_PYTHON` 통지를 환경변수로 넘긴다.** stdout JSON 으로 내고 `exec` 하면 훅 자신의
  JSON 과 합쳐져 문서가 둘이 된다.
- **D21 — kill switch 판정 의미를 정본 그대로 보존한다.**
- **D22 — 출하 바닥 검증을 프로젝트 밖에 둔다.** **D25 가 제거했다**(L4 로 강등).
- **D23 — Goal 5 의 수단도 산출물(README)에 적는다** · **D24 — C2 의 빈도 서술을 정확히 고친다.**

리뷰 라운드 3 채택 + 사용자 단순화 지시:

- **D25 — 단순화. 「제품이 아니라 문서를 만족시키려고 생긴 것」을 걷어낸다.** 사용자 지시 원문:
  「너무 복잡한 구조를 만들 필요가 있을까? 그리고 제약을 맞추기 위해 억지스러운 방향으로 구현하지 마」.
  발단은 AC14(리터럴 불변)가 **자기 설계가 만드는 신규 파일 때문에 위반이 되는** 모순이었고, 그 모순을
  봉합하는 두 방법 중 고르라고 물은 것 자체가 증상이었다. 제거한 넷 — (a) 리터럴 불변 원장(「다른 걸
  건드리지 않았다」는 `git diff` 가 답한다), (b) sh↔python kill switch parity 락, (c) 출하 바닥 전용
  검증 환경(D22 — L4 로 강등), (d) `DEVBREW_PYTHON_IGNORED` 의 4훅 릴레이(D26 으로 한 자리가 됐다).
  AC 23 → 17.
- **D26 — 안내는 `SessionStart` 한 자리에서만.** 바닥 미만 머신에서 `PostToolUse` 안내는 Bash 호출마다
  모델 컨텍스트에 재주입되는데 해석기는 상태가 없어 억제할 수 없다. `SessionStart` 는 세션당 1회이고
  도달이 3/3 로 실측됐다. 이 결정이 D20 의 릴레이를 한 자리로 줄였다.
- **D27 — `plugin-audit` 는 prerequisite 주장에서 뺀다.** 훅이 없고 셸 13자리는 범위 밖이라 그 바닥을
  집행하는 주체가 없다 — R8 이 기각한 술어가 그대로 돌아온다. version·CHANGELOG 만 건드린다.
- **D28 — C1 의 근거 범위를 정확히 적는다.** stderr `0/1` 은 `PostToolUse(Read)` 값이고 이 설계의 자리
  (matcher Bash)와 `SessionEnd` 는 감사가 미측정으로 남겼다.
- **D29 — `HEAD_WINDOW=20` 을 제약으로 적는다**(C10). 머리 20줄을 shebang·설명·`# copy-of:` 마커·도출
  규칙 주석이 나눠 쓴다.
- **얼림 검사 재가 7건** — 라운드 2 반영 때 permit 밖 앵커(제목·Goal·반례·Non-goals·uv층·Rejected
  Alternatives·Next Action)를 고친 것을 사용자가 재가했다. 채택된 결정을 적용하려면 건드리지 않을 수 없었다.

리뷰 절차에 대한 기록:

- **세 라운드의 finding** — 17 → 23 → 13, codex 산출물 4930 → 6785 → 2084 바이트. 재비판은
  15/22/11 confirm 이었고 **`source_interview` 오탐을 세 번 다 기각**했다.
- **라운드 2·3 이 잡은 것의 상당수가 직전 수정의 회귀였고, 그 회귀는 전부 «결정 쌍»에서 나왔다** —
  D8×D11 · D8×AC8 · D10×AC12 · D18×D17 · D20×D8. 각 결정은 따로 보면 옳았다. finding 단위로 판정하고
  한꺼번에 적용하면 이 축이 원리적으로 보이지 않는다.
- **저자의 절차 실수** — 라운드 1 채택분을 적용할 때 편집을 `begin-round` **뒤에** 넣어 8건이 전부
  「채택 후 미적용」으로 재상승했다. **올바른 순서는 편집 → begin-round** 다.
- **깨진 목차 링크** — 초판 목차의 링크 하나가 헤딩의 괄호 때문에 깨져 있었고, **세 리뷰어 누구도 잡지
  못했다**(셋 다 목차를 정답으로 읽었다). 앵커 해석기가 잡았다.
- **저자가 찾아 넣은 것** — 해석 실패 시 훅이 JSON 을 아예 출력하지 않는다는 파생 결과, 그리고 훅 4자리가
  전부 stdin 을 읽으므로 해석기가 stdin 불가침이라는 제약(C6).

### Deferred to plan

1. 해석기 안내 문구의 **정확한 텍스트** (AC7 의 세 요소를 담되 표현은 plan 이 정한다).
2. `pyproject.toml` 의 `[project]` 최소 필드 구성 — devbrew 는 배포되는 패키지가 아니다. `project-init`
   이 이 파일을 보고 devbrew 를 「Python 프로젝트」로 판정하게 되는 부작용의 허용 여부도 여기서 확정한다.
3. 테스트 파일의 배치 — `shared/tests/` 단일인지 플러그인별로 쪼개는지.
4. 플러그인 버전 리터럴 (머지 직전 확정, AC17).
5. `DEVBREW_PYTHON_IGNORED` 의 정확한 키 이름과 `session-start-advisor.py` 가 그것을 싣는 코드 형태.
6. AC1·AC14·AC16·AC17 의 관측 절차 (Verification Plan 7).
7. 해석기 머리 20줄 예산의 실제 배분 (shebang · 설명 · `# copy-of:` 마커 · 도출 규칙 — C10).

> 이전 라운드의 defer 세 건(리터럴 불변 원장의 자리별 형식 · parity 락 케이스 축 · 출하 바닥 검증 환경의
> 변이 격리)은 D25 가 그 대상을 제거해 **소멸했다**.
