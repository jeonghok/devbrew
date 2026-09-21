---
name: python-floor-and-uv
type: design
created_at: 2026-09-21
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# 출하 Python 바닥 3.12 + uv 도입 · Design

> 바닥을 **선언**하는 것과 **집행**하는 것은 다른 일이다.
> 선언만 한 바닥은 훅이 읽지 않는다.

## Handoff Context

**TL;DR** — devbrew 출하 스크립트의 Python 바닥을 3.12 로 올린다. 그런데 바닥은 선언으로 서지 않는다:
`python3` 가 macOS 기본 3.9.6 인 머신에서는 어디에 무엇을 적든 훅이 3.9.6 을 집는다. 그래서 **훅 자리에만**
인터프리터 해석기(POSIX sh)를 끼운다. 모델이 읽고 돌리는 스킬 지시문의 `python3` 는 손대지 않는다 — 그 자리는
실패가 보이기 때문이다. 개발·검증 쪽은 uv 로 재현 가능하게 만든다(`pyproject.toml` · `uv.lock` ·
`.python-version`). 린터(ruff)와 **출하** PyYAML 조달은 범위 밖이다.

**Implicit context** —

(1) 사용자 요청 원문: 「python 버전을 올려줬으면 해 그리고 여기도 uv로 관리를 해보자」.

(2) 바닥 `3.12` 는 리터럴이 아니라 **도출된 값**이다 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
근거 수치는 §Context/Why. 다음 상향 시점도 이 규칙이 정한다(3.12 EOL = 2028-10).

(3) 작업 위치: 브랜치 `feature/python-floor-uv`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-floor-uv`, base `d24d3045`(#159 머지).

(4) 착수 직전 base 가 **17 커밋 움직였다**(#159 = agent-transparency 제거). 이 문서의 모든 수치는 옛 base 가
아니라 `d24d3045` 에서 다시 잰 값이다. 핵심 편집 표면(`hooks.json` 3 파일)은 그 이동에 영향받지 않았다.

(5) **두 바닥은 다른 사실이다.** 출하 바닥(해석기 sh 의 상수)과 개발 바닥(`pyproject.toml` 의
`requires-python`)은 지금 둘 다 `3.12` 지만, 같은 숫자일 뿐 같은 사건이 아니다. 개발만 먼저 올라가는 날이
오면 한 자리에 적힌 값은 조용히 거짓이 된다. §4 가 두 자리를 분리하고 AC8 이 관계를 고정한다.

(6) 설계 도중 「uv 를 리포에 들이지 말자」(pyproject·lock 없이 `uv run --with pyyaml`)는 초안이 사용자
반론으로 **철회**됐다. 경위와 반론의 내용은 「결정 기록」 D5.

(7) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

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
  - [2. 훅 통합과 실패 방향](#2-훅-통합과-실패-방향)
  - [3. uv 층](#3-uv-층)
  - [4. 두 바닥의 분리](#4-두-바닥의-분리)
  - [5. 건드리지 않는 것](#5-건드리지-않는-것)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)
  - [Deferred to plan](#deferred-to-plan)

## Goal

devbrew 출하 스크립트가 **3.12 이상에서 돈다는 것을 집행**하고, 개발·검증 환경을 uv 로 재현 가능하게 만든다.
바닥 미만 사용자에게는 침묵이 아니라 안내가 간다.

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
튀는데, AWS Lambda 런타임이 3.9 에 핀돼 있기 때문이지 사람이 3.9 를 쓰기 때문이 아니다. 패키지 하나로
생태계를 단정하면 안 되고, 이 문서는 두 패키지를 교차로 봤다.

배포판 기준선은 이미 훨씬 위다 — Debian 13 = 3.13, Ubuntu 26.04 LTS = 3.13~3.14. **3.9 를 아직 기본으로
내보내는 주체는 사실상 Apple 뿐이고, 그것이 devbrew 가 부딪히는 벽이다.**

### 2. devbrew 의 모집단은 PyPI 가 아니다

devbrew 는 애플리케이션이 아니라 **플러그인 마켓플레이스**다. `plugins/*/scripts/*.py` 와
`plugins/*/hooks/*.py` 는 메인테이너의 머신이 아니라 **설치한 사람의 머신에서, 그 사람의 PATH `python3` 로**
실행된다. 따라서 여기서 「버전을 올린다」는 리팩터링이 아니라 **설치 요구사항을 하나 추가하는 제품 결정**이다.

반대로 `*/tests/` 아래는 이 리포에서만 돈다. 바닥이 이미 자유롭다. 두 모집단은 다른 규칙을 받아야 한다.

### 3. 반례 — 이 머신

```
python3      -> /usr/bin/python3            3.9.6      ← 훅이 집는 것
python3.12   -> ~/.local/bin/python3.12     3.12.13
uv 가 아는 것: 3.11.15 · 3.12.13 · 3.14.3   (전부 설치돼 있음)
```

macOS 26(Darwin 25.6.0)에서도 Apple 의 `/usr/bin/python3` 는 여전히 3.9.6 이다. **이 머신에는 3.12 가
이미 있는데도 `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/x.py` 는 3.9.6 을 집는다.** 즉 `requires-python` 을
어디에 적든 훅은 그 선언을 읽지 않는다. 그리고 이것은 남의 머신이 아니라 메인테이너 본인의 머신이다 —
가장 잘 갖춰진 환경조차 선언만으로는 안 된다는 증명이다.

### 4. 리포 실측 (base `d24d3045`)

| 축 | 값 |
|---|---|
| 플러그인 | 4 (plugin-audit · project-init · quality-gates · spec-distill) |
| `.py` | 181 = 출하 70 · 테스트 95 · 그 밖(`shared`·`tools`·`docs`) 16 |
| 3.9.6 구문 파싱 | **181/181, 오류 0** |
| 3.10+ 문법 사용 | **0건** (`match` · `except*` · `type X` · PEP695 전부 0) |
| `from __future__ import annotations` | 69 파일 |
| `hooks.json` | 3 파일 · 4 호출 자리 |
| 무가드 `import yaml` (출하) | 3 (전부 `quality-gates/scripts/`) |
| `python3` 리터럴 | 출하 223 · 테스트 916 · 문서 1213 |
| 테스트 | bash 224 · python 모듈 59 |
| `pyproject.toml` · lock · CI · 린터 | **전부 없음** |
| 플러그인 버전 | plugin-audit 0.9.3 · project-init 3.1.1 · quality-gates 7.6.2 · spec-distill 3.2.0 |

**코드가 3.10+ 문법을 한 줄도 쓰지 않는다**는 사실이 중요하다. 3.9→3.11 과 3.9→3.12 의 마이그레이션 비용이
동일하다는 뜻이고, 따라서 바닥 선택은 코드가 아니라 **지원 기간과 사용자 분포**만으로 결정된다.

## Goals

1. 출하 스크립트가 **3.12 이상에서 실행됨을 집행**한다 — 선언이 아니라 해석으로.
2. 바닥 미만 머신에서 **조용히 죽지 않는다** — 무엇이 없고 어떻게 고치는지가 사용자에게 간다.
3. 개발·검증 환경이 **재현 가능**하다 — 인터프리터와 테스트 의존성이 기억이 아니라 파일에 고정된다.
4. 바닥과 천장 **양쪽에서 스위트를 돌릴 수단**을 갖는다 (현재 존재하지 않는 능력).
5. 바닥이 **도출 규칙**으로 기록돼 다음 상향이 임의적이지 않다.

## Non-goals

1. **출하 표면의 PyYAML 조달.** 무가드 `import yaml` 3건은 이 설계와 **독립적으로 지금도 깨져 있다**(그
   PyYAML 은 Apple 기본 탑재가 아니라 사용자 pip). 같이 묶으면 「버전을 올려서 깨진 건가, 원래 깨져 있었나」
   판별이 불가능해진다. 별도 PR.
2. **린터(ruff) 도입.** 181 파일 diff 가 버전 회귀와 섞인다.
3. **스킬·문서·테스트의 `python3` 리터럴 2129개 교정.** §5 참조 — 의도적으로 남긴다.
4. **69개 `__future__` shim 제거.** §5 참조.
5. **CI 도입.** 리포에 CI 가 없다는 사실은 이 설계가 바꾸지 않는다.
6. **uv 를 출하 요구사항으로 만들기.** 사용자에게 요구하는 것은 Python 하나로 유지한다.

## Constraints

1. **C1 — 훅은 조용히 죽는다.** 헤드리스 경로의 훅 실패는 rc=0 으로 관측된 전례가 있다. 해석 실패가 침묵이
   되면 안 된다.
2. **C2 — `PostToolUse` 는 도구 호출마다 뛴다.** 해석 비용이 체감 지연이 된다. 실측: 인터프리터 1회 spawn
   10–17ms, 버전 판정 16ms, 최악 경로(`python3` 불만족 → PATH 글롭 → 히트) 28ms. **증가분 ~20ms.**
3. **C3 — 훅은 조언·청소·검증이지 보안 게이트가 아니다.** 막으면 사용자가 작업 자체를 못 한다. 실패 방향은
   fail-open + loud 여야 한다(kill switch 는 보안 컨트롤이라 별개이며 기존대로 각 훅이 존중한다).
4. **C4 — 미래 버전을 오늘 열거할 수 없다.** 마이너 버전을 리터럴로 나열하는 해석기는 시간에 대해 fail-open
   이다(denylist 가 시간에 대해 fail-open 인 것과 같은 구조).
5. **C5 — `python3` 로의 fallback 은 금지.** 바닥 미만으로 떨어지면, 출하 코드가 3.12 문법을 쓰기 시작한
   순간 안내를 띄우기 전에 `SyntaxError` 로 죽는다.
6. **C6 — 정적 검사로는 3.9 실행 가능성을 보장할 수 없다.** `ast.parse(feature_version=(3,9))` 는
   `match`·`except*`·`type X`·PEP695 를 잡지만 **PEP604(`int | None`)는 통과시킨다** — 3.9 는 그것을
   파싱이 아니라 시그니처 annotation **평가** 시점에 `TypeError` 로 깬다. 이 설계는 해석기를 sh 로 써서 이
   제약을 아예 회피한다(§1).
7. **C7 — 심볼릭 링크는 staging 계약을 탄다.** `shared/` 의 파일이 플러그인에 닿는 경로는 `git ls-files -s`
   의 mode-120000 항목이며, 새 링크는 그 정본 목록에 들어가야 한다.

## 설계 (Architecture)

### 1. 해석기 — `devbrew-python`

`shared/python/devbrew-python`, **POSIX sh**, mode 100755.

**왜 파이썬이 아니라 sh 인가.** 해석기를 파이썬으로 쓰면 *그 파일 자체가 3.9 에서 실행돼야 한다* — 3.9
사용자에게 안내를 띄우려면 3.9 가 그 파일을 읽고 돌릴 수 있어야 하니까. 그러면 C6 의 제약(PEP604 함정)이
살아나고, 그것을 지키는지 증명하려고 「3.9 테스트 레그」가 필요해진다. **sh 는 인터프리터 독립이라 그 사슬이
통째로 사라진다.**

해석 순서:

```
0. 출하 바닥 상수: FLOOR_MAJOR=3, FLOOR_MINOR=12          ← 출하 바닥의 정본
1. $DEVBREW_PYTHON 이 설정돼 있으면 버전을 묻는다
     만족  -> 그것으로 exec
     불만족 -> 무시하되 «무시했다»를 stderr 에 낸다 (조용한 무시 금지), 2 로
2. `python3` 의 버전을 묻는다 -> 만족하면 exec        ← 흔한 경우, spawn 1회로 종료
3. PATH 를 훑어 `python3.*` 글롭으로 후보를 모은다     ← 열거하지 않는다 (C4)
     `*-config` 류는 제외, 실행 가능한 것만, 첫 히트에서 종료
4. 아무것도 없으면:
     - stderr 에 안내 (발견된 최고 버전 · 요구 바닥 · 고치는 법 한 줄)
     - exec 하지 않는다 (C5 — `python3` 로 내려가지 않는다)
     - exit 0                                       ← fail-open (C3)
```

**캐시는 두지 않는다.** C2 의 실측 증가분이 ~20ms 다. 캐시를 넣는 순간 「사용자가 새 파이썬을 깔았는데
캐시가 옛것을 가리킨다」는 무효화 버그 계열이 통째로 딸려온다. 측정된 숫자가 캐시를 기각한다.

### 2. 훅 통합과 실패 방향

`hooks.json` 3 파일 · 4 자리가 해석기를 경유한다:

```diff
- "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
+ "command": "${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
```

| 플러그인 | 훅 | 해석 실패 시 |
|---|---|---|
| quality-gates | `SessionStart` advisor | 안내를 내고 조언 없이 종료 (read-only 조언자이므로 무해) |
| quality-gates | `SessionEnd` cleanup | 안내를 내고 청소 생략 — state 가 남으므로 그 사실을 함께 공시 |
| spec-distill | `SessionEnd` cleanup | 위와 같음 |
| project-init | `PostToolUse` | 안내를 내고 검증 생략 — **막지 않는다**(C3) |

**별도 프리플라이트 훅을 신설하지 않는다.** 안내는 해석 실패 경로가 그 자리에서 낸다. 새 훅 0개.

### 3. uv 층

리포 루트에 세 파일:

| 파일 | 역할 | 실측 근거 |
|---|---|---|
| `pyproject.toml` | `requires-python` = **개발** 바닥 · `[dependency-groups] dev` 에 PyYAML | `uv run --python 3.9` 가 `requires-python` 위반으로 거부됨을 확인 |
| `uv.lock` | PyYAML 을 정확한 버전으로 고정, 커밋 | 리포 `.gitignore` 가 `#uv.lock` 항목에 *"generally recommended to include … in version control"* 을 달고 주석 처리해 둠 |
| `.python-version` | `3.12` — bare `uv run` 이 **바닥에서** 돌게 | 이것이 없으면 uv 가 조용히 3.14.3 을 고른다(실측). 바닥을 정해놓고 천장에서만 검증하게 되는 함정 |

실행:

```
uv run -m unittest <module>                  # 바닥 (3.12)
uv run --python 3.14 -m unittest <module>    # 천장
```

`--with pyyaml` 같은 플래그를 손으로 타지 않는다 — 기억에 의존하는 하니스는 하니스가 아니다.
uv 가 없으면 기존 `python3 -m unittest` 로 degrade 한다(러너 스크립트도 매트릭스 하네스도 만들지 않는다).

### 4. 두 바닥의 분리

| | 정본 | 집행자 | 의미 |
|---|---|---|---|
| **출하 바닥** | `devbrew-python` 의 `FLOOR_*` 상수 | 훅 (해석기) | 사용자 머신에 요구하는 최소 |
| **개발 바닥** | `pyproject.toml` 의 `requires-python` | uv | 이 리포에서 개발·검증하는 최소 |

지금은 둘 다 `3.12` 다. 같은 숫자지만 **같은 사실이 아니다** — 개발만 3.14 로 올라가는 날이 오면 한 자리에
적힌 값은 조용히 거짓이 된다. AC8 이 두 자리를 **각각 읽어서** `개발 ≥ 출하` 를 고정한다(한쪽을 상수로
적으면 그 테스트는 아무것도 재지 않는다).

### 5. 건드리지 않는 것

- **스킬·커맨드 지시문의 `python3`.** 모델이 Bash 로 돌리고 traceback 을 **직접 본다** — 실패가 시끄럽다.
  훅과 달리 침묵하지 않으므로 해석기를 끼울 이유가 없다. 편집하면 2129개 자리에 drift 표면만 생긴다.
- **69개 `from __future__ import annotations`.** 걷어내면 69 파일 diff 에 기능 이득 0 이고, 3.14 는 PEP 649
  로 deferred annotation 이 기본이라 남겨도 무해하다.
- **테스트·문서의 `python3` 리터럴.**

## Acceptance Criteria

- **AC1** `hooks.json` 3 파일 · 4 자리 전부가 해석기를 경유한다. `"command"` 값이 bare `python3 ` 로
  시작하는 자리가 **0** 이다.
- **AC2** 해석기는 마이너 버전을 **열거하지 않는다** — PATH 글롭으로 후보를 찾으므로 미래 버전이 파일 수정
  없이 잡힌다.
  *변이*: 글롭을 리터럴 열거로 바꾸면 RED. *양성 대조*: 바닥을 만족하는 가짜 `python3.99` 를 PATH 앞에 두면
  해석기가 그것을 고른다.
- **AC3** 바닥 미만 인터프리터만 있을 때 해석기는 **`python3` 로 fallback 하지 않는다**.
  *변이*: fallback 한 줄을 추가하면 RED.
- **AC4** 해석 실패 안내는 (a) 발견된 최고 버전, (b) 요구 바닥, (c) 고치는 법 한 줄 을 모두 포함한다.
- **AC5** `DEVBREW_PYTHON` 이 바닥을 만족하면 이긴다. 만족하지 못하면 무시하되 **무시했다는 사실이 stderr
  에 나온다**(조용한 무시 금지).
- **AC6** 해석기와 그 링크 3개가 실행 가능하다 — `git ls-files -s` 에서 원본 `100755`, 링크 `120000`.
  *이것이 틀리면 훅 4자리가 전부 조용히 죽는다.*
- **AC7** `.python-version` 이 출하 바닥과 같은 minor 를 가리켜 bare `uv run` 이 **바닥에서** 돈다.
  *변이*: `.python-version` 을 지우면 uv 가 천장을 골라 RED.
- **AC8** 개발 바닥 ≥ 출하 바닥. 테스트가 `pyproject.toml` 과 해석기 **양쪽을 각각 읽어** 비교한다.
  *변이*: 출하 바닥만 3.13 으로 올리면 RED.
- **AC9** `uv.lock` 이 커밋되고 PyYAML 이 정확한 버전으로 고정된다.
- **AC10** 69개 `from __future__ import annotations` 가 **전부 그대로**다 (개수 및 파일 목록 동일).
- **AC11** 출하 `python3` 리터럴 223개 중 **훅 4자리만** 바뀐다. 테스트 916 · 문서 1213 은 불변.
- **AC12** 4개 플러그인 README 에 `Python 3.12+` prerequisite 가 있다.
- **AC13** 4개 플러그인 모두 version bump + CHANGELOG 항목. 바닥 상향은 **breaking** 이므로 bump 등급은
  breaking 규칙을 따른다(0.x 는 minor, 1.0 이상은 major). 리터럴 번호는 머지 직전에 정한다.
- **AC14** PATH 를 `/usr/bin` 만으로 좁힌(=3.9.6 만 보이는) 상태에서 훅 4자리를 실행하면, 각각 안내가 나오고
  rc=0 이며 본래 동작은 수행되지 않는다.

## Files to Modify

| 경로 | 종류 | 비고 |
|---|---|---|
| `shared/python/devbrew-python` | 신규 | POSIX sh, mode 100755. 출하 바닥의 정본 |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python` | 신규 링크 | mode 120000. C7 의 staging 목록에 등재 |
| `plugins/{project-init,quality-gates,spec-distill}/hooks/hooks.json` | 편집 | 4 자리 |
| `pyproject.toml` | 신규 | 루트. 개발 바닥 + dev 의존성 |
| `uv.lock` | 신규 | 루트. 커밋 |
| `.python-version` | 신규 | 루트. `3.12` |
| `shared/tests/test_python_floor.sh`(가칭) | 신규 | AC2·AC3·AC4·AC5·AC8·AC14 |
| `plugins/*/README.md` × 4 | 편집 | prerequisites |
| `plugins/*/.claude-plugin/plugin.json` × 4 | 편집 | version |
| `plugins/*/CHANGELOG.md` × 4 | 편집 | |

`.gitignore` 는 **편집하지 않는다** — `.venv` 는 이미 무시되고 `uv.lock` 은 주석 처리돼 있어 추적된다.

## Verification Plan

1. **baseline 회귀 대조.** 착수 전 `d24d3045` 에서 bash 224 · python 59 모듈을 돌려 **rc 와 실패 줄 수를
   함께** 기록했다(rc 만 보면 이미 RED 인 파일 *안*의 새 실패가 원리적으로 안 보인다). 구현 후 같은 러너로
   재실행해 자리별로 대조한다. 선재 RED 는 이름과 **이유**를 함께 적는다.
2. **해석기 변이 테스트.** AC2·AC3·AC5·AC7·AC8 각각에 대해 명시된 변이를 넣어 RED 를 확인하고, AC2 는
   양성 대조(가짜 `python3.99`)까지 돌린다. 통과가 정답인 단언은 모양으로 이빨을 판별할 수 없다.
3. **PATH 격리 시뮬레이션** (AC14). `PATH=/usr/bin` 으로 훅 4자리를 실행. 이것이 이 설계의 **유일한 실사용
   실패 경로**이므로 수동이 아니라 테스트로 고정한다.
4. **mode 확인** (AC6). `git ls-files -s` 로 `100755` / `120000` 을 인쇄해 대조.
5. **uv 버전 인쇄** (AC7). `uv run python -c 'import sys;print(sys.version)'` 가 바닥을 인쇄하는지,
   `--python 3.14` 가 천장을 인쇄하는지.
6. **불변 확인** (AC10·AC11). `__future__` 파일 목록과 `python3` 리터럴 수를 전후로 인쇄해 등호로 대조.

## Rejected Alternatives

- **R1 — 전면 해석 shim (출하 223 자리 전부).** 사용자 무작업이라는 장점은 있으나 마크다운 지시문까지
  고쳐야 해 drift 표면이 커진다. 훅과 달리 그 자리들은 실패가 시끄럽다(§5).
- **R2 — `uv run --script` 로 출하까지 조달.** PEP 723 shebang 이면 인터프리터와 PyYAML 이 동시에 해결되나,
  요구사항이 「Python」에서 「uv」로 바뀌고 uv 미설치 사용자는 즉사한다(fail-closed). graceful degradation
  원칙과 충돌.
- **R3 — 바닥 3.11.** 「2026-10 이후에도 패치받는 가장 낮은 버전」이라는 더 보수적인 도출값. 사용자가
  3.12 를 선택(D1) — 단일 최빈이고 runway 가 1년 길다.
- **R4 — pyproject·lock 없이 `uv run --with pyyaml`.** 파일 0개라는 이유로 초안에 있었으나 **철회**(D5).
  플래그를 매번 손으로 타야 하므로 하니스를 사람 기억으로 옮긴 것이고, PyYAML 버전도 고정되지 않는다.
- **R5 — ruff 동시 도입.** 181 파일 diff 가 버전 회귀 판별을 오염시킨다.
- **R6 — 마이너 버전 열거식 해석** (`python3.12`/`3.13`/`3.14` 나열). 내일 추가될 버전을 오늘 열거할 수
  없다(C4).
- **R7 — 해석 결과 캐시.** C2 의 실측 증가분 ~20ms 가 캐시를 기각한다. 무효화 버그만 얻는다.
- **R8 — `plugin.json` 에 `requires-python`.** 그 키를 읽는 주체가 없다 — 집행 없는 선언.
- **R9 — 프리플라이트 전용 훅 신설.** 안내는 해석 실패 경로가 낸다. 새 훅은 무게만 는다.
- **R10 — 3.9 테스트 레그 / `ast.parse(feature_version=)` 정적 검사.** 해석기를 sh 로 쓰면 3.9 에서 돌아야
  할 파이썬 파일이 존재하지 않으므로 둘 다 잴 대상이 없다. 게다가 정적 검사에는 C6 의 구멍이 있다.

## 알려진 한계

- **L1** 해석기는 `python3.*` 라는 **이름 규약**에 의존한다. conda 나 이름이 다른 shim 은 못 찾는다.
  `DEVBREW_PYTHON` 이 그 탈출구이며, AC4 의 안내가 그 존재를 알린다.
- **L2** 스킬 지시문이 돌리는 스크립트는 여전히 사용자의 `python3`(3.9 일 수 있음)를 집는다. 의도적이다(D2)
  — 그 자리는 모델이 실패를 본다. 다만 **출하 코드가 3.12 문법을 쓰기 시작하면 이 한계가 실제 고장이 된다.**
  이 설계는 3.12 문법 사용을 요구하지도 금지하지도 않으므로, 실제로 쓰기 시작하는 PR 이 이 자리를 다시 열어야
  한다.
- **L3** 출하 PyYAML 은 여전히 사용자 책임이다(Non-goal 1). 이 설계는 그것을 고치지도, 악화시키지도 않는다.
- **L4** AC14 의 시뮬레이션은 `PATH=/usr/bin` 이 3.9.6 을 준다는 **이 머신의 사실**에 의존한다. Apple 이
  `/usr/bin/python3` 를 올리면 그 테스트는 조용히 아무것도 재지 않게 된다 — 테스트가 실제로 바닥 미만을
  보고 있는지 자기 확인해야 한다.

## Concrete Next Action

`superpowers:writing-plans` 로 구현 계획을 만든다. 첫 Task 는 해석기(`devbrew-python`)와 그 변이 테스트이며,
`hooks.json` 편집은 해석기가 변이 테스트로 검증된 **뒤에** 온다.

## 결정 기록

- **D1 — 출하 바닥은 3.12.** 사용자 결정. 제안은 3.11(「2026-10 이후에도 패치받는 가장 낮은 버전」)이었고
  근거는 3.12 로 올리면 3.11 사용자 24.3% 를 추가로 잘라내는데 마이그레이션 비용은 동일하다는 것이었다.
  사용자가 실측 분포를 보고 3.12 를 선택했다 — 단일 최빈(30.9%)이고 runway 가 1년 길며, devbrew 사용자층은
  자기 Python 을 직접 관리하는 개발자라 실제 탈락률이 PyPI 수치보다 낮다.
- **D2 — 해석은 훅에만.** 사용자 선택(「훅만 해석 · 나머지는 프리플라이트」). 근거는 훅과 스킬 지시문의
  **실패 가시성 비대칭**이다 — 훅은 조용히 죽고 지시문은 모델이 traceback 을 본다.
- **D3 — 해석기는 sh.** 파이썬으로 쓰면 그 파일이 3.9 에서 돌아야 한다는 제약이 생기고, 그로부터 3.9 테스트
  레그가 파생된다. sh 는 그 사슬을 끊는다.
- **D4 — 매트릭스 레그를 만들지 않는다.** 사용자 질문(「레그를 꼭 해야할까」)에서 재검토한 결과, 3.9 레그는
  D3 으로 대상이 사라졌고 3.14 확인은 하네스가 아니라 명령 한 줄이다.
- **D5 — uv 를 리포에 들인다.** 초안은 「pyproject·lock 없이 `uv run --with pyyaml`」이었고, 사용자 반론
  (「같은걸 안들이는 이유가 있어? 들이는게 좋지않나」)으로 철회했다. 초안 논거의 절반이 이미 무효였다 —
  *「`requires-python` 을 적으면 3.9 레그가 막힌다」* 는 D4 로 레그가 사라지면서 소멸했는데 결론만 남아
  있었다. 추가로: `--with` 플래그는 사람 기억에 의존하고, PyYAML 버전이 고정되지 않으며,
  `requires-python` 은 uv 가 실제로 집행하므로 theater 가 아니다.
- **D6 — ruff 는 제외.** D5 로 uv 를 들이면서도 린터는 분리한다. 회귀 판별 오염(R5).
- **D7 — 출하 PyYAML 은 별도 PR.** 이 설계와 독립적으로 이미 깨져 있는 건이므로 섞지 않는다.

### Deferred to plan

1. 해석기 안내 문구의 **정확한 텍스트** (AC4 의 세 요소를 담되 표현은 plan 이 정한다).
2. `pyproject.toml` 의 `[project]` 최소 필드 구성 — devbrew 는 배포되는 패키지가 아니므로 `name`/`version`
   을 어떻게 둘지. `project-init` 이 이 파일을 보고 devbrew 를 「Python 프로젝트」로 판정하게 되는 부작용의
   허용 여부도 여기서 확정한다.
3. 테스트 파일의 배치 — `shared/tests/` 단일인지 플러그인별로 쪼개는지.
4. 플러그인 버전 리터럴 (머지 직전 확정, AC13).
5. 선재 RED 목록과 각각의 **이유** (Verification Plan 1 의 baseline 이 확정되면).
