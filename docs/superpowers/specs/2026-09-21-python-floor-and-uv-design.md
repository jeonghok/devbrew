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

**TL;DR** — devbrew 훅의 Python 바닥을 3.12 로 올린다. 바닥은 선언으로 서지 않는다: `python3` 가 macOS
기본 3.9.6 인 머신에서는 어디에 무엇을 적든 훅이 3.9.6 을 집는다. 그래서 훅 자리에 인터프리터
해석기(POSIX sh)를 끼우되 **`sh <경로>` 로 부르고**(실행 비트 의존 제거) **물리 사본으로 배포한다**(심볼릭
링크는 감사기를 깬다). 집행 범위는 **훅 4자리와 훅이 자기 안에서 spawn 하는 파이썬 자식**뿐이다 — 스킬·
커맨드가 Bash 로 부르는 자리(출하 셸 포함)는 범위 밖이고, 그 자리는 실패가 보인다. 안내는 stderr 가 아니라
**`hookSpecificOutput.additionalContext` + `systemMessage`** 로 낸다 — stderr 는 실측으로 아무 데도 닿지
않는다. 개발·검증은 uv 로 재현 가능하게 만든다(`pyproject.toml` · `uv.lock` · `.python-version`).
린터(ruff)와 **출하** PyYAML 조달은 범위 밖.

**Implicit context** —

(1) 사용자 요청 원문: 「python 버전을 올려줬으면 해 그리고 여기도 uv로 관리를 해보자」.

(2) 바닥 `3.12` 는 리터럴이 아니라 **도출된 값**이다 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
근거 수치는 §Context/Why. 다음 재검토 시점도 이 규칙이 정한다(3.12 EOL = 2028-10). 이 규칙은 설계문서
밖(해석기 머리 주석 · README)에도 적힌다 — **Goal 6 과 AC15**.

(3) 작업 위치: 브랜치 `feature/python-floor-uv`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-floor-uv`, base `d24d3045`(#159 머지).

(4) 착수 직전 base 가 **17 커밋 움직였다**(#159 = agent-transparency 제거). 이 문서의 모든 수치는 옛 base 가
아니라 `d24d3045` 에서 다시 잰 값이다. 핵심 편집 표면(`hooks.json` 3 파일)은 그 이동에 영향받지 않았다.

(5) **두 바닥은 다른 사실이다.** 출하 바닥(해석기 sh 의 상수)과 개발 바닥(`pyproject.toml` 의
`requires-python`)은 지금 둘 다 `3.12` 지만, 같은 숫자일 뿐 같은 사건이 아니다. §4 가 두 자리를 분리하고
**AC10** 이 관계를 고정하며, `.python-version` 은 **개발** 바닥을 따라간다(**AC9**). 두 바닥이 갈라지는
날의 출하 바닥 검증은 프로젝트 **밖**의 uv 환경이 맡는다(§4 · **AC23**).

(6) 설계 도중 「uv 를 리포에 들이지 말자」(pyproject·lock 없이 `uv run --with pyyaml`)는 초안이 사용자
반론으로 **철회**됐다. 경위는 「결정 기록」 D5.

(7) **리뷰 두 라운드가 이 문서를 두 번 다시 썼다.** 라운드 1 채택분은 D8~D15, 라운드 2 채택분은 D17~D24 다.
라운드 2 가 잡은 것의 절반이 **라운드 1 수정이 만든 회귀**였고, 그 회귀는 전부 **결정 쌍**에서 나왔다
(D8×D11 · D8×AC8 · D10×AC18) — finding 단위 리뷰가 원리적으로 못 보는 축이다. **D11(출하 셸까지
집행)은 라운드 2 근거로 되돌려졌다**(D17).

(8) AC 번호는 **다시 매기지 않는다.** 라운드 2 가 잡은 참조 결함 6건이 전부 라운드 1 의 AC 재번호 때문이었다.
삭제된 항목은 번호를 비우고 새 항목은 AC20+ 로 붙인다.

(9) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

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

devbrew 의 **훅과 훅이 spawn 하는 파이썬 자식**이 Python 3.12 이상에서 돈다는 것을 집행하고,
개발·검증 환경을 uv 로 재현 가능하게 만든다. 바닥 미만 사용자에게는 침묵이 아니라, **실측으로 도달이
확인된 채널로** 안내가 간다.

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
/usr/bin/sh  -> 없음                                   ← sh 는 /bin/sh (AC18 이 여기 걸렸다)
```

macOS 26(Darwin 25.6.0)에서도 Apple 의 `/usr/bin/python3` 는 여전히 3.9.6 이다. **이 머신에는 3.12 가
이미 있는데도 `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/x.py` 는 3.9.6 을 집는다.** 즉 `requires-python` 을
어디에 적든 훅은 그 선언을 읽지 않는다. 그리고 이것은 남의 머신이 아니라 메인테이너 본인의 머신이다 —
가장 잘 갖춰진 환경조차 선언만으로는 안 된다는 증명이다.

### 4. 리포 실측

base `d24d3045`. **모든 수치는 아래 도출 명령의 출력이다** — 재현 가능한 코퍼스 정의 없이 적힌 수는
다음 사람이 확인할 수 없고, **AC12·AC13·AC14** 와 Non-goal 3 이 그 수 위에 선다.

| 축 | 도출 | 값 |
|---|---|---|
| 플러그인 | `ls plugins` | 4 (plugin-audit · project-init · quality-gates · spec-distill) |
| `.py` 총계 | `git ls-files '*.py' \| wc -l` | 181 |
| ├ 출하 | `git ls-files 'plugins/*' \| grep '\.py$' \| grep -v '/tests/'` | 70 |
| └ 테스트 | `git ls-files '*.py' \| grep '/tests/'` | 95 |
| 3.9.6 구문 파싱 | `ast.parse(...)` 전수 (3.9.6 인터프리터) | **181/181, 오류 0** |
| 3.10+ 문법 | `match` · `except*` · `type X` · PEP695 grep | **0건** |
| `__future__` shim | `git grep -l "from __future__ import annotations" -- '*.py'` | 69 파일 |
| `hooks.json` | `git ls-files 'plugins/*/hooks/hooks.json'` | 3 파일 · **4 호출 자리** |
| 무가드 `import yaml`(출하) | `grep -rlE "^import yaml\|^from yaml" plugins --include='*.py' \| grep -v /tests/` | 3 (전부 `quality-gates/scripts/`) |
| `python3` 리터럴 — 출하 | `git ls-files 'plugins/*' 'shared/*' 'tools/*' \| grep -v '/tests/' \| xargs grep -oh 'python3' \| wc -l` | 223 |
| `python3` 리터럴 — 테스트 | `git ls-files \| grep '/tests/' \| xargs grep -oh 'python3' \| wc -l` | 916 |
| `python3` 리터럴 — 문서 | `git ls-files 'docs/*' \| xargs grep -oh 'python3' \| wc -l` | 1213 |
| **훅이 spawn 하는 `python3`** | `hook_common.py:38-39` 의 `subprocess.run(["python3", …])` | **1 (TTL-GC)** ← 집행 대상 |
| 출하 셸의 `python3` (범위 밖) | `plugins/*/scripts/*.sh` | 39건 / 11파일 — **하한이다**(아래) |
| 테스트 | bash 205(배제 19) · python 4 디렉토리 648 tests | [baseline](../../audits/2026-09-21-python-floor-baseline.md) |
| `pyproject.toml` · lock · CI · 린터 | Glob | **전부 없음** |
| 플러그인 버전 | `plugin.json` | plugin-audit 0.9.3 · project-init 3.1.1 · quality-gates 7.6.2 · spec-distill 3.2.0 |

**출하 셸 39건은 하한이다.** 글롭·grep 계열 집계가 심볼릭 링크를 건너뛰므로
`plugins/{quality-gates,spec-distill}/scripts/run_docreview_codex_reviewer.sh`(정본
`shared/docreview/scripts/` 로 가는 링크, 그 파일에 `python3` 2자리)가 빠져 있다. 이 설계는 그 39자리를
**집행 범위에 넣지 않으므로**(D17) 정확한 수가 필요하지 않지만, 숫자를 하한으로 읽어야 한다는 사실은
남긴다 — 범위를 다시 넓히는 PR 은 여기서부터 재집계해야 한다.

**코드가 3.10+ 문법을 한 줄도 쓰지 않는다**는 사실이 중요하다. 3.9→3.11 과 3.9→3.12 의 마이그레이션 비용이
동일하다는 뜻이고, 따라서 바닥 선택은 코드가 아니라 **지원 기간과 사용자 분포**만으로 결정된다.

## Goals

1. **훅 4자리와 훅이 spawn 하는 파이썬 자식**이 3.12 이상에서 실행됨을 집행한다 — 선언이 아니라 해석으로.
   (스킬·커맨드가 Bash 로 부르는 자리는 범위 밖이다 — Non-goal 3, §5, L2.)
2. 바닥 미만 머신에서 **조용히 죽지 않는다** — 무엇이 없고 어떻게 고치는지가 **도달이 실측된 채널로**
   사용자와 모델에게 간다.
3. **kill switch 가 해석기보다 위에 선다** — 훅을 끈 사용자는 아무 말도 듣지 않는다. 판정 의미는 파이썬
   정본과 **같다**(좁히지 않는다).
4. 개발·검증 환경이 **재현 가능**하다 — 인터프리터와 테스트 의존성이 기억이 아니라 파일에 고정된다.
5. 바닥과 천장 **양쪽에서 스위트를 돌릴 수단**을 갖고, 그 수단이 **산출물(README)에** 적힌다 — 설계문서
   안에만 있으면 Goal 6 이 자기에게 적용한 술어가 이 목표에도 돌아온다.
6. 바닥이 **도출 규칙**으로 **산출물에** 기록돼 다음 상향이 임의적이지 않다 — 이 설계문서가 아니라
   해석기 머리 주석과 README 에. (설계문서에만 있으면 R8 을 기각한 술어가 자기에게 돌아온다.)

## Non-goals

1. **출하 표면의 PyYAML 조달.** 무가드 `import yaml` 3건은 이 설계와 **독립적으로 지금도 깨져 있다**(그
   PyYAML 은 Apple 기본 탑재가 아니라 사용자 pip). 같이 묶으면 「버전을 올려서 깨진 건가, 원래 깨져 있었나」
   판별이 불가능해진다. 별도 PR.
2. **린터(ruff) 도입.** 181 파일 diff 가 버전 회귀와 섞인다.
3. **스킬·커맨드가 Bash 로 부르는 자리의 `python3`** — 출하 셸 39자리, 스킬 지시문, 문서, 테스트 전부.
   모델이 Bash 로 돌리고 traceback 을 직접 보므로 실패가 시끄럽다. §5·L2·D17.
4. **69개 `__future__` shim 제거.** §5.
5. **CI 도입.** 리포에 CI 가 없다는 사실은 이 설계가 바꾸지 않는다.
6. **uv 를 출하 요구사항으로 만들기.** 사용자에게 요구하는 것은 Python 하나로 유지한다.
7. **`SessionEnd` 와 대화형 TUI 에서의 채널 도달 보장.** 감사 §8.3 이 둘 다 **미측정**이라고 명시한다 —
   도달을 주장하지 않고 한계로 공시한다(L5).

## Constraints

1. **C1 — 훅의 텍스트 채널은 대부분 아무 데도 닿지 않는다.** 실측(`claude 2.1.252`, 헤드리스 `-p`,
   8회 실행 · 4 이벤트 · 랜덤 카나리 14개,
   `docs/superpowers/interview/2026-09-01-seam-and-adjudication-interview.audit.md` §8):

   | 채널 | 모델 도달 |
   |---|---|
   | stderr + `exit 0` | **0/1** (SessionStart · UserPromptSubmit · PostToolUse 각각) |
   | `systemMessage` | **0/14** — 사람은 transcript 에서 보지만 모델엔 안 닿는다 |
   | `hookSpecificOutput.additionalContext` | **8/8 닿는다** |
   | Stop `decision:"block"+reason` | 7/7 닿는다 |

   §8.1 이 `quality-gates/hooks/session-start-advisor.py:149-161`(stderr + rc 0)을 이름으로 지목해
   「모델에 안 닿는다」고 적는다. **따라서 stderr 만으로 Goal 2 를 충족했다고 말할 수 없다.**
   측정 범위의 한계는 L5.
2. **C2 — `PostToolUse` 는 Bash 도구 호출마다 뛴다.** 리포의 유일한 `PostToolUse` 자리가
   `plugins/project-init/hooks/hooks.json:4-6` 의 `"matcher": "Bash"` 이므로 **모든** 도구 호출이 아니라
   Bash 호출에서만 돈다. 실측 비용: 인터프리터 1회 spawn 10–17ms, 버전 판정 16ms, 최악 경로(`python3`
   불만족 → PATH 글롭 → 히트) 28ms. **증가분 ~20ms.**
3. **C3 — kill switch 는 보안 컨트롤이고, 해석기는 그 위에 앉는다.** 판정은 현재 훅 **파이썬 파일 안**에
   있다(`plugins/project-init/hooks/post-tool-use.py:204`). 해석기가 파이썬을 안 돌리면 그 줄에 도달하지
   못하므로, **해석기 자신이 kill switch 를 먼저 봐야 한다.** 그리고 그 판정은 정본
   (`shared/killswitch/kill_switch_active.py:29-68`)과 **의미가 같아야 한다** — 쉼표 목록 분리 · 공백 제거
   · **전체 토큰** 대조(부분 일치 금지) · 훅명 **또는 이벤트명** 별칭 · 변수명 `-`→`_`+대문자 도출.
   좁히면 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` 로 끈 사용자가 Goal 3 을 못 받는다.
4. **C4 — 훅은 조언·청소·검증이지 보안 게이트가 아니다.** 막으면 사용자가 작업 자체를 못 한다. 해석 실패의
   방향은 fail-open + loud 다.
5. **C5 — 미래 버전을 오늘 열거할 수 없다.** 마이너 버전을 리터럴로 나열하는 해석기는 시간에 대해
   fail-open 이다(denylist 가 시간에 대해 fail-open 인 것과 같은 구조).
6. **C6 — `python3` 로의 fallback 은 금지.** 바닥 미만으로 떨어지면, 출하 코드가 3.12 문법을 쓰기 시작한
   순간 안내를 띄우기 전에 `SyntaxError` 로 죽는다.
7. **C7 — 해석기는 stdin 을 건드릴 수 없다.** 훅은 payload 를 stdin 으로 받고 **4자리 전부 그것을 읽는다**
   (실측). 해석기는 그 경로 한가운데 서므로 반드시 `exec` 로 넘겨야 하며, 이벤트 이름을 stdin 에서 읽으면
   훅이 payload 를 잃는다 — 그래서 이벤트는 **인자로** 받는다(§2).
8. **C8 — 실행 비트가 설치 캐시까지 살아남는지는 이 리포에서 측정된 적이 없다.** 그래서 해석기는
   **`sh <경로>` 로 부른다** — 실행 비트에 의존하지 않으면 측정되지 않은 가정이 설계에서 사라진다.
9. **C9 — 감사기는 확장자로 스크립트를 찾고, plugin root **안**만 판독한다.**
   `plugins/plugin-audit/scripts/check-shape-completeness.py:114` 의 `_CMD_SCRIPT_RE` 가 `.py`/`.sh`
   접미만 캡처하고, 같은 파일 `:157-171` 이 `root = pd.resolve()` · `cand … .resolve()` ·
   `cand.relative_to(root)` 실패 시 `return False` 로 **plugin root 밖을 fail-closed 거부**한다(회귀 락
   `test_check_shape_completeness.py:194-212`). 그러므로 해석기는 (a) 이름이 `.sh` 로 끝나야 하고,
   (b) **심볼릭 링크가 아니라 물리 사본이어야** 한다 — 링크면 `.resolve()` 가 `shared/` 로 풀려 세
   플러그인 모두에 거짓 「kill switch 부재」가 난다.
10. **C10 — 정적 검사로는 3.9 실행 가능성을 보장할 수 없다.** `ast.parse(feature_version=(3,9))` 는
    `match`·`except*`·`type X`·PEP695 를 잡지만 **PEP604(`int | None`)는 통과시킨다** — 3.9 는 그것을
    파싱이 아니라 시그니처 annotation **평가** 시점에 `TypeError` 로 깬다. 이 설계는 해석기를 sh 로 써서
    이 제약을 회피한다(§1).
11. **C11 — `shared/` 정본의 배포는 두 축이고 이 설계는 물리 사본 축을 탄다.** 심볼릭 링크(mode-120000)와
    `# copy-of:` 물리 사본 둘 다 `shared/tests/test_copy_of_contract.sh` 가 집행한다 — 후자는
    `sed "${lineno}d" "$f" \| diff -q - "$target"`(`:599`)로 **바이트 동일**을 요구한다. C9 때문에 해석기는
    물리 사본이며, 따라서 정본과 사본을 **같은 커밋에서** 고쳐야 한다.
12. **C12 — 훅의 stdout 은 JSON 문서 «하나»여야 한다.** 훅 자신이 성공 경로에서 JSON 을 찍으므로
    (`post-tool-use.py:205`·`:211`·`:218`·`:239`), 해석기가 stdout 에 무엇을 더 찍고 `exec` 하면 JSON 이
    둘이 되어 파싱이 깨지고 훅 출력이 조용히 사라진다. **`exec` 하는 경로에서 해석기는 stdout 에 아무것도
    쓰지 않는다** — 전달할 말은 환경변수로 넘기고 훅이 자기 JSON 에 합친다(§1 순서 2).

## 설계 (Architecture)

### 1. 해석기 — `devbrew-python`

`shared/python/devbrew-python.sh`, **POSIX sh**. 각 플러그인에 `# copy-of:` **물리 사본**으로 배포(C9·C11).

**왜 파이썬이 아니라 sh 인가.** 해석기를 파이썬으로 쓰면 *그 파일 자체가 3.9 에서 실행돼야 한다* — 3.9
사용자에게 안내를 띄우려면 3.9 가 그 파일을 읽고 돌릴 수 있어야 하니까. 그러면 C10 의 제약(PEP604 함정)이
살아나고, 그것을 지키는지 증명하려고 「3.9 테스트 레그」가 필요해진다. **sh 는 인터프리터 독립이라 그 사슬이
통째로 사라진다.** 대가는 kill switch 판정의 **네 번째 본문**이 생긴다는 것이고, AC22 의 parity 락이
그것을 정본에 묶는다.

해석 순서:

```
0. 출하 바닥 상수: FLOOR_MAJOR=3, FLOOR_MINOR=12        ← 출하 바닥의 정본
   (머리 주석에 도출 규칙을 함께 적는다 — Goal 6, AC15)

1. kill switch 를 먼저 본다 (C3)                        ← 어떤 일보다 앞
     DEVBREW_<PLUGIN>_DISABLE=1                         (변수명은 플러그인명에서 도출: `-`→`_`, 대문자)
     DEVBREW_SKIP_HOOKS 를 쉼표로 나눠 공백 제거 후
       «전체 토큰» 이 `<plugin>:<hook>` 또는
                     `<plugin>:<event>` 와 같으면 해당   ← 부분 일치 금지, 별칭 둘
     해당하면 -> stdout 에 아무것도 쓰지 않고 exit 0
     (플러그인·훅·이벤트 이름은 인자로 받는다 — stdin 불가침, C7)

2. $DEVBREW_PYTHON 이 설정돼 있으면 «버전을 물어» 판정
     만족  -> exec
     불만족 -> stdout 에 쓰지 않는다 (C12).
               DEVBREW_PYTHON_IGNORED=<사유> 를 «환경으로» 넣고 3 으로.
               훅이 그 값을 읽어 «자기» JSON 의 두 채널에 합친다 (조용한 무시 금지)

3. `python3` 의 «버전을 물어» 판정 -> 만족하면 exec     ← 흔한 경우, spawn 1회로 종료

4. PATH 를 훑어 `python3.*` 글롭으로 후보를 모은다       ← 열거하지 않는다 (C5)
     `*-config` 류 제외 · 실행 가능한 것만
     **각 후보도 3 과 «같은 버전 판정»을 받는다**        ← 이름이나 실행 권한은 근거가 아니다
     바닥을 만족하는 «첫 후보»에서 종료

5. 아무것도 없으면 (= exec 하지 않는다):
     - 이벤트에 맞는 JSON 을 stdout 에 «단 하나» 찍는다 — 채널은 §2
       (발견된 최고 버전 · 요구 바닥 · 고치는 법 한 줄)
     - `python3` 로 내려가지 않는다 (C6)
     - exit 0                                            ← fail-open (C4)
```

`exec` 하는 경로(2·3·4)에서 해석기의 stdout 은 **비어 있다**(C12). 말은 환경으로만 간다.
`exec` 하지 않는 경로(1·5)에서만 해석기가 stdout 의 주인이 된다.

**캐시는 두지 않는다.** C2 의 실측 증가분이 ~20ms 이고 빈도도 Bash 호출 한정이다. 캐시를 넣는 순간
「사용자가 새 파이썬을 깔았는데 캐시가 옛것을 가리킨다」는 무효화 버그 계열이 통째로 딸려온다.

### 2. 훅 통합과 실패 방향

`hooks.json` 3 파일 · 4 자리가 해석기를 **`sh` 로** 경유한다(C8). 이벤트·플러그인·훅 이름은 인자로
넘어간다(C7 — stdin 은 건드리지 않는다):

```diff
- "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
+ "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event SessionEnd --plugin spec-distill --hook session-end-cleanup ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
```

**안내 채널** — stderr 는 쓰지 않는다(C1). 해석기가 이벤트에 맞는 JSON 을 **stdout** 으로 찍는다:

| 받는 쪽 | 채널 | 실측 |
|---|---|---|
| 모델 | `hookSpecificOutput.additionalContext` | 8/8 도달 (헤드리스 `-p`) |
| 사람 | `systemMessage` | transcript 에 표시(모델엔 0/14) |

둘 다 낸다 — 하나는 모델이, 하나는 사람이 받는다. **`SessionEnd` 와 대화형 TUI 는 감사 §8.3 이 미측정이라고
명시하므로 도달을 주장하지 않는다**(Non-goal 7, L5).

| 플러그인 | 훅 | 이벤트 | 해석 실패 시 |
|---|---|---|---|
| quality-gates | session-start-advisor | `SessionStart` | 안내를 내고 조언 없이 종료 (read-only 조언자) |
| quality-gates | session-end-cleanup | `SessionEnd` | 안내를 내고 청소 생략 — state 가 남는다는 사실을 함께 |
| spec-distill | session-end-cleanup | `SessionEnd` | 위와 같음 |
| project-init | post-tool-use | `PostToolUse`(matcher Bash) | 안내를 내고 검증 생략 — **막지 않는다**(C4) |

**별도 프리플라이트 훅을 신설하지 않는다.** 안내는 해석 실패 경로가 그 자리에서 낸다. 새 훅 0개.

### 3. uv 층

리포 루트에 세 파일:

| 파일 | 역할 | 실측 근거 |
|---|---|---|
| `pyproject.toml` | `requires-python` = **개발** 바닥 · `[dependency-groups] dev` 에 PyYAML | `uv run --python 3.9` 가 `requires-python` 위반으로 거부됨을 확인 |
| `uv.lock` | PyYAML 을 정확한 버전으로 고정, 커밋 | `.gitignore:104` 가 `#uv.lock` 에 *"generally recommended to include … in version control"* 을 달고 주석 처리해 둠 |
| `.python-version` | **개발** 바닥(§4) — bare `uv run` 이 그 버전에서 돌게 | 이것이 없으면 uv 가 조용히 3.14.3 을 고른다(실측) |

실행(이 세 줄은 **README 에도 적힌다** — Goal 5, AC21):

```
uv run -m unittest <module>                      # 개발 바닥
uv run --python 3.14 -m unittest <module>        # 천장
uv run --no-project --python <출하 바닥> --with pyyaml -m unittest <module>   # 출하 바닥 (§4)
```

셋째 줄이 `--no-project` 인 이유는 §4 에 있다. `--with pyyaml` 이 여기서만 다시 나타나는 것은 프로젝트를
벗어나 lock 을 못 쓰기 때문이며, 그 대가(버전 미고정)는 L7 에 적는다.
uv 가 없으면 기존 `python3 -m unittest` 로 degrade 한다(러너 스크립트도 매트릭스 하네스도 만들지 않는다).

### 4. 두 바닥의 분리

| | 정본 | 집행자 | 의미 |
|---|---|---|---|
| **출하 바닥** | `devbrew-python.sh` 의 `FLOOR_*` 상수 | 훅 (해석기) | 사용자 머신에 요구하는 최소 |
| **개발 바닥** | `pyproject.toml` 의 `requires-python` | uv | 이 리포에서 개발·검증하는 최소 |

지금은 둘 다 `3.12` 다. 같은 숫자지만 **같은 사실이 아니다** — 개발만 3.14 로 올라가는 날이 오면 한 자리에
적힌 값은 조용히 거짓이 된다.

**`.python-version` 은 «개발» 바닥을 따라간다.** 이것은 개발 환경을 고르는 파일이기 때문이다. 출하 바닥에
묶으면 개발 바닥이 올라가는 순간 `.python-version` 과 `requires-python` 이 서로를 거부해 bare `uv run` 이
죽는다.

**출하 바닥 검증은 프로젝트 «밖»에서 한다.** uv 는 프로젝트의 `requires-python` 을 집행하므로, 개발 바닥이
출하 바닥보다 높아지면 `uv run --python <출하바닥>` 도 거부된다 — 프로젝트 안에 있는 한 출하 바닥을 잴
방법이 없다. 그래서 그 검증만 `--no-project` 로 프로젝트 컨텍스트를 벗어나 돈다(§3 셋째 줄). 지금은 두
바닥이 같아 이 경로가 없어도 통하지만, **구조가 그날에 의존하지 않도록 지금 정의해 둔다**(AC23).

**AC10** 이 `개발 ≥ 출하` 를 고정하되, **두 자리를 각각 읽어서** 비교한다(한쪽을 상수로 적으면 그 테스트는
아무것도 재지 않는다).

### 5. 건드리지 않는 것

**범위 안**(§Goals 1):
- `hooks.json` 4 자리 — 해석기 경유
- 훅이 자기 안에서 spawn 하는 `python3` — `hook_common.py:38-39` 의 TTL-GC 를 `sys.executable` 로. 이미
  바닥을 만족하는 인터프리터가 자기 자식에게 상속된다. 전수 grep 결과 **이 1건이 전부**다.

**범위 밖**:
- **출하 셸 39자리**(`plugins/*/scripts/*.sh`). 전부 스킬·커맨드가 Bash 로 부르는 자리이고, 훅에서 spawn
  되는 셸은 `qg-worktree.sh` 하나인데 그것은 `python3` 를 쓰지 않는다 — 즉 아래 스킬 지시문과 **같은
  술어**가 적용된다. 게다가 그 자리의 stdout 은 훅 채널이 아니라 **데이터**다(`run_artifact_codex_reviewer.sh:117`
  · `run_audit_codex_reviewer.sh:140-144` 가 파이썬 stdout 을 파일로 받는다) — 훅용 계약을 그대로 씌우면
  데이터 오염 + 조용한 성공이 된다. D17.
- **스킬·커맨드 지시문의 `python3`.** 모델이 Bash 로 돌리고 traceback 을 **직접 본다** — 실패가 시끄럽다.
- **69개 `from __future__ import annotations`.** 걷어내면 69 파일 diff 에 기능 이득 0 이고, 3.14 는
  PEP 649 로 deferred annotation 이 기본이라 남겨도 무해하다.
- **테스트·문서의 `python3` 리터럴.**

## Acceptance Criteria

> 번호는 **고정**이다. 삭제된 항목은 번호를 비우고 새 항목은 뒤에 붙인다(Handoff Context (8)).

- **AC1** `hooks.json` 3 파일 · 4 자리 전부가 `sh <해석기>` 를 경유한다. `"command"` 값이 bare `python3 `
  로 시작하는 자리가 **0** 이다.
- **AC2** 해석기는 마이너 버전을 **열거하지 않는다** — PATH 글롭으로 후보를 찾으므로 미래 버전이 파일 수정
  없이 잡힌다.
  *변이*: 글롭을 리터럴 열거로 바꾸면 RED. *양성 대조*: 바닥을 만족하는 가짜 `python3.99` 를 PATH 앞에 두면
  해석기가 그것을 고른다.
- **AC3** PATH 후보도 `python3` 와 **같은 버전 판정**을 받는다 — 이름이나 실행 권한만으로 통과하지 않는다.
  *변이*: 바닥 미만인 가짜 `python3.9` 를 PATH 앞에 두면 해석기가 그것을 **건너뛴다**.
- **AC4** 바닥 미만 인터프리터만 있을 때 해석기는 **`python3` 로 fallback 하지 않는다**.
  *변이*: fallback 한 줄을 추가하면 RED.
- **AC5** 해석 실패(순서 5) 안내가 **stdout JSON 하나**로 나가며 `hookSpecificOutput.additionalContext` 와
  `systemMessage` 를 **둘 다** 담고, 내용에 (a) 발견된 최고 버전, (b) 요구 바닥, (c) 고치는 법 한 줄이 있다.
  *변이*: 안내를 stderr 로 되돌리면 RED.
- **AC6** **kill switch 가 해석보다 먼저고, 판정 의미가 파이썬 정본과 같다.** 아래 넷이 전부 성립한다 —
  (a) `DEVBREW_<PLUGIN>_DISABLE=1`(변수명은 플러그인명에서 도출), (b) `DEVBREW_SKIP_HOOKS` 의 쉼표 목록을
  공백 제거 후 **전체 토큰**으로 대조(부분 일치 금지), (c) `<plugin>:<hook>` **과** `<plugin>:<event>` 둘 다
  별칭으로 받음, (d) 해당 시 **stdout 이 비어 있고** rc=0.
  *변이*: (b)를 부분 일치로 바꾸면 RED · (c)의 이벤트 별칭을 빼면 RED · kill switch 검사를 해석 뒤로 옮기면 RED.
- **AC7** 해석기가 **stdin 을 읽지 않는다** — 훅 4자리가 payload 를 그대로 받는다.
  *변이*: 해석기에 stdin 을 읽는 줄을 넣으면 훅의 payload 파싱이 RED.
- **AC8** `DEVBREW_PYTHON` 이 바닥을 만족하면 이긴다. 만족하지 못하면 **stdout 에 쓰지 않고**
  `DEVBREW_PYTHON_IGNORED` 를 환경으로 넘기며, 훅이 그것을 자기 JSON 의 두 채널에 합쳐 **JSON 문서가
  하나로 유지된다**.
  *변이*: 해석기가 그 통지를 stdout 에 찍게 하면 훅 출력이 JSON 둘이 되어 파싱 RED · 통지 자체를 없애면
  「조용한 무시」로 RED.
- **AC9** `.python-version` 이 **개발** 바닥과 같은 minor 를 가리킨다.
  *변이*: `.python-version` 을 지우면 uv 가 천장을 골라 RED · 출하 바닥에 묶으면 개발 바닥을 올렸을 때
  bare `uv run` 이 죽는 회귀 케이스가 RED.
- **AC10** 개발 바닥 ≥ 출하 바닥. 테스트가 `pyproject.toml` 과 해석기 **양쪽을 각각 읽어** 비교한다.
  *변이*: 출하 바닥만 3.13 으로 올리면 RED.
- **AC11** `uv.lock` 이 커밋되고 PyYAML 이 정확한 버전으로 고정된다. *관측*: Verification Plan 8.
- **AC12** 훅이 spawn 하는 `python3` 가 **0건**이다 — `hook_common.py` 의 TTL-GC 가 `sys.executable` 을
  쓴다. **출하 셸 39자리는 범위 밖이므로 불변이다**(D17).
  *변이*: 그 한 자리를 `python3` 로 되돌리면 RED.
- **AC13** 69개 `from __future__ import annotations` 가 **전부 그대로**다 (개수가 아니라 **파일 목록** 동일).
- **AC14** 스킬·커맨드·문서·테스트·출하 셸의 `python3` 리터럴은 불변이다 (자리별 원장으로 대조).
- **AC15** **도출 규칙이 산출물에 적혀 있다** — 해석기 머리 주석과 4개 플러그인 README 가 「2026-10 이후에도
  패치를 받는 버전 중 최빈 · 다음 재검토는 3.12 EOL(2028-10)」을 담는다.
  *변이*: 그 문장을 지우면 RED.
- **AC16** 4개 플러그인 README 에 `Python 3.12+` prerequisite 가 있다. *관측*: Verification Plan 8.
- **AC17** 4개 플러그인 모두 version bump + CHANGELOG 항목. 바닥 상향은 **breaking** 이므로 bump 등급은
  breaking 규칙을 따른다(0.x 는 minor, 1.0 이상은 major). 리터럴 번호는 머지 직전에 정한다.
  *관측*: Verification Plan 8.
- **AC18** `PATH=/usr/bin:/bin` 로 좁힌 상태에서 훅 4자리를 실행하면, 각각 AC5 의 JSON 이 나오고 rc=0 이며
  본래 동작은 수행되지 않는다. **kill switch 가 켜져 있으면 stdout 이 비어야 한다**(AC6 과 함께 잰다).
  `/bin` 을 넣는 이유는 이 머신에 `/usr/bin/sh` 가 없어서이고(실측), `/bin` 에는 `python3` 가 없어 바닥
  미만 조건은 유지된다. **테스트는 자기가 실제로 바닥 미만을 보고 있는지 먼저 확인한다**(L4).
- **AC19** 신규 락이 `# guards:` 를 선언하고 **`--emit-scanned` 를 지원한다**. 둘 중 하나만 하면 안 된다 —
  `# guards:` 만 붙이면 `test_guards_coverage_bidirectional.sh:71` 이 락을 통째로 실행해 그 출력을
  「스캔한 경로」로 읽고 RED 를 낸다.
- **AC20** 해석기가 **물리 사본**으로 배포된다(`# copy-of:` 머리 주석, mode 100644, 심볼릭 링크 아님) —
  `plugins/plugin-audit/scripts/check-shape-completeness.py` 의 containment 검사가 세 플러그인에서
  `hooks_killswitch` 를 **참**으로 낸다.
  *변이*: 배포를 mode-120000 링크로 바꾸면 그 감사가 거짓 gap 을 내어 RED.
- **AC21** 바닥·천장·출하바닥 실행 명령 세 줄이 **루트 README 에** 있다(Goal 5).
  *변이*: 그 절을 지우면 RED.
- **AC22** sh 해석기의 kill switch 판정이 파이썬 정본과 **같은 결과**를 낸다 — 두 구현에 같은 입력
  (플러그인·훅·이벤트 × `DEVBREW_SKIP_HOOKS` 변형)을 주고 결과를 대조한다.
  *변이*: 정본의 별칭 규칙을 바꾸면 sh 쪽이 따라오지 않아 RED.
- **AC23** 출하 바닥 검증 경로가 **프로젝트 밖에서** 실제로 돈다 — `uv run --no-project --python <출하바닥>`
  가 개발 바닥과 무관하게 실행된다.
  *변이*: `--no-project` 를 빼고 `requires-python` 을 출하 바닥보다 높게 두면 거부되어 RED.

## Files to Modify

| 경로 | 종류 | 비고 |
|---|---|---|
| `shared/python/devbrew-python.sh` | 신규 | POSIX sh. 출하 바닥 정본 + 도출 규칙 주석(AC15) |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` | 신규 | **물리 사본**(`# copy-of:`), mode 100644 — 링크 아님(C9·AC20) |
| `shared/README.md` | 편집 | `## 디렉토리` 표(23–32줄)에 `shared/python/` 행 추가 |
| `plugins/{project-init,quality-gates,spec-distill}/hooks/hooks.json` | 편집 | 4 자리 |
| `plugins/spec-distill/scripts/hook_common.py` | 편집 | `subprocess.run(["python3", …])` → `sys.executable` |
| `plugins/{project-init,quality-gates,spec-distill}/hooks/*.py` | 편집 | `DEVBREW_PYTHON_IGNORED` 를 읽어 자기 JSON 에 합침(AC8) |
| `pyproject.toml` | 신규 | 루트. **개발** 바닥 + dev 의존성 |
| `uv.lock` | 신규 | 루트. 커밋 |
| `.python-version` | 신규 | 루트. **개발** 바닥 |
| `README.md` (루트) | 편집 | 실행 명령 세 줄(AC21) + 도출 규칙 |
| `shared/tests/test_python_floor.sh` | 신규 | `# guards:` **+ `--emit-scanned`**(AC19). AC2~AC10·AC12·AC18·AC20·AC22·AC23 |
| `plugins/*/README.md` × 4 | 편집 | prerequisites(AC16) + 도출 규칙(AC15) |
| `plugins/*/.claude-plugin/plugin.json` × 4 | 편집 | version |
| `plugins/*/CHANGELOG.md` × 4 | 편집 | |
| `docs/audits/2026-09-21-python-floor-baseline.md` | 신규(완료) | baseline 기록 + 러너. 인덱스 등재 완료 |

**`plugin-audit` 에는 해석기를 배포하지 않는다** — 훅이 없고(`hooks/` 디렉토리 자체가 없다) 셸 13자리는
범위 밖이기 때문이다(D17). README·version·CHANGELOG 만 편집한다.

`.gitignore` 는 **편집하지 않는다** — `.venv`(`:143`)는 이미 무시되고 `uv.lock`(`:104`)·
`.python-version`(`:91`)은 주석 처리돼 있어 추적된다.

## Verification Plan

1. **baseline 회귀 대조.** 착수 전 `d24d3045` 에서 bash 205 자리 · python 4 디렉토리(648 tests)를 돌려
   **rc 와 실패 줄 수·`Ran N` 을 함께** 기록했다. 기록물과 러너는
   [`docs/audits/2026-09-21-python-floor-baseline.md`](../../audits/2026-09-21-python-floor-baseline.md)
   에 있고 선재 RED 4건이 **각각의 이유와 함께** 거기 적혀 있다. 구현 후 같은 러너로 재실행해 자리별로
   대조하며, python 쪽은 `failures` 수뿐 아니라 실패한 **테스트 이름**까지 본다.
2. **해석기 변이 테스트.** AC2·AC3·AC4·AC5·AC6·AC7·AC8·AC9·AC10·AC15·AC20·AC21·AC22·AC23 각각에 대해
   그 AC 에 명시된 변이를 넣어 RED 를 확인하고, AC2 는 양성 대조(가짜 `python3.99`)까지 돌린다. 통과가
   정답인 단언은 모양으로 이빨을 판별할 수 없다.
3. **PATH 격리 시뮬레이션** (AC18). `PATH=/usr/bin:/bin` 으로 훅 4자리를 실행 — kill switch 켠 경우와
   끈 경우를 **둘 다**. 테스트가 먼저 「그 PATH 의 `python3` 가 정말 바닥 미만인가」를 확인한다(L4).
4. **채널 확인** (AC5·AC8). 훅의 stdout 을 JSON 으로 파싱해 **문서가 하나인지** 그리고 두 키가 함께 있는지
   본다. stderr 로 되돌리는 변이, 해석기가 통지를 stdout 에 찍는 변이가 각각 RED 를 내는지도.
5. **uv 버전 인쇄** (AC9·AC23). bare `uv run` 이 개발 바닥을, `--no-project --python <출하바닥>` 이 출하
   바닥을, `--python 3.14` 가 천장을 인쇄하는지.
6. **자리별 원장** (AC12·AC13·AC14). 합계가 아니라 **자리별로** 전후를 인쇄해 등호로 대조한다 — 한 자리의
   증가가 다른 자리의 소실을 갚는 대체를 막는다.
7. **커버리지 락 동거** (AC19). `test_guards_coverage_bidirectional.sh` 를 돌려 새 락이 RED 를 만들지
   않는지 확인한다.
8. **통과-정답 단언의 관측** (AC1·AC11·AC16·AC17). 각각 무엇을 인쇄해 무엇과 대조하면 통과인지를
   정한다 — `hooks.json` 의 bare `python3` 자리 수 0, `uv.lock` 의 PyYAML 핀, README 4개의 prerequisite
   문자열, `plugin.json` 4개의 version diff + CHANGELOG 항목. 구체 절차와 변이는 `Deferred to plan` 7.
9. **copy-of 동기화** (C11·AC20). `shared/tests/test_copy_of_contract.sh` 를 돌려 정본과 3 사본의 바이트
   동일이 유지되는지 확인한다.

## Rejected Alternatives

- **R1 — 전면 해석 shim (스킬 지시문 포함 전 경로).** 마크다운 지시문까지 고쳐야 해 drift 표면이 커진다.
  그 자리들은 실패가 시끄럽다(§5).
- **R2 — `uv run --script` 로 출하까지 조달.** 요구사항이 「Python」에서 「uv」로 바뀌고 uv 미설치 사용자는
  즉사한다(fail-closed).
- **R3 — 바닥 3.11.** 더 보수적인 도출값. 사용자가 3.12 를 선택(D1).
- **R4 — pyproject·lock 없이 `uv run --with pyyaml`.** 철회(D5). 플래그를 매번 손으로 타야 하고 PyYAML
  버전도 고정되지 않는다.
- **R5 — ruff 동시 도입.** 181 파일 diff 가 버전 회귀 판별을 오염시킨다.
- **R6 — 마이너 버전 열거식 해석.** 내일 추가될 버전을 오늘 열거할 수 없다(C5).
- **R7 — 해석 결과 캐시.** C2 의 실측 증가분 ~20ms + Bash 호출 한정 빈도가 캐시를 기각한다.
- **R8 — `plugin.json` 에 `requires-python`.** 그 키를 읽는 주체가 없다 — 집행 없는 선언.
- **R9 — 프리플라이트 전용 훅 신설.** 안내는 해석 실패 경로가 낸다.
- **R10 — 3.9 테스트 레그 / `ast.parse(feature_version=)` 정적 검사.** 해석기를 sh 로 쓰면 3.9 에서 돌아야
  할 파이썬 파일이 없어 잴 대상이 없다. 정적 검사에는 C10 의 구멍도 있다.
- **R11 — 훅이 해석기를 직접 exec.** 실행 비트가 설치 캐시까지 살아남는지가 측정된 적이 없다(C8).
- **R12 — 안내를 stderr 로.** 초판의 선택이었고 실측으로 반증됐다(C1 — 0/1 도달). D8.
- **R13 — 집행을 출하 셸 39자리까지.** 라운드 1 에서 채택(D11)됐다가 라운드 2 근거로 **되돌려졌다**(D17) —
  그 자리는 스킬이 Bash 로 부르는 경로라 §5 의 술어가 그대로 적용되고, stdout 이 데이터라 훅 계약을 씌우면
  오염된다.
- **R14 — 해석기를 심볼릭 링크로 배포.** `check-shape-completeness.py` 의 containment 가 `.resolve()` 로
  plugin root 밖을 보고 세 플러그인에 거짓 「kill switch 부재」를 낸다(C9). 감사기를 완화하는 쪽도
  검토했으나 보안 감사기를 약화시키므로 기각 — 물리 사본이 답이다(D18).
- **R15 — `DEVBREW_PYTHON` 불만족 통지를 없앤다.** 출력 충돌은 사라지지만 사용자가 오타 난 override 를
  영원히 모른다. 환경변수 경유로 둘 다 얻는다(D20).
- **R16 — 두 바닥이 갈라지는 날을 한계로만 공시.** 가장 가볍지만, 구조가 「그날」에 의존하게 둔다.
  사용자가 별도 검증 환경 설계를 선택(D22).
- **R17 — AC10 을 「개발 = 출하」 등호로.** 모순은 사라지나 §4 의 「두 바닥은 다른 사실」이라는 주장도
  함께 사라진다.

## 알려진 한계

- **L1** 해석기는 `python3.*` 라는 **이름 규약**에 의존한다. conda 나 이름이 다른 shim 은 못 찾는다.
  `DEVBREW_PYTHON` 이 그 탈출구이며, AC5 의 안내가 그 존재를 알린다.
- **L2** 스킬·커맨드가 Bash 로 부르는 자리(출하 셸 39자리 포함)는 여전히 사용자의 `python3`(3.9 일 수 있음)를
  집는다. 의도적이다(D17·Non-goal 3) — 그 자리는 모델이 실패를 본다. 다만 **출하 파이썬이 3.12 문법을
  쓰기 시작하면 이 한계가 실제 고장이 된다.** 이 설계는 3.12 문법 사용을 요구하지도 금지하지도 않으므로,
  실제로 쓰기 시작하는 PR 이 이 자리를 다시 열어야 한다.
- **L3** 출하 PyYAML 은 여전히 사용자 책임이다(Non-goal 1).
- **L4** AC18 의 시뮬레이션은 `PATH=/usr/bin:/bin` 이 바닥 미만 `python3` 를 준다는 **이 머신의 사실**에
  의존한다. Apple 이 `/usr/bin/python3` 를 올리면 그 테스트는 조용히 아무것도 재지 않게 되므로, 테스트가
  실제로 바닥 미만을 보고 있는지 **자기 확인**한다(AC18).
- **L5** **채널 실측은 헤드리스 `-p` 전용이고 `SessionEnd` 는 미측정이다**(감사 §8.3 — 「대화형 TUI 미측정.
  헤드리스 `-p` 만 쟀다.」). 훅 4자리 중 **둘이 SessionEnd** 이고, 실제 사용의 대부분은 TUI 다. 두 축 모두
  도달을 주장하지 않는다. 측정은 plan 의 선택 항목이다.
- **L6** 설치 캐시에서의 배포 동작은 비문서다. 물리 사본은 링크 역참조 의존을 제거하지만, 설치본이 파일을
  어떻게 배치하는지 자체를 이 설계가 보장하지는 못한다.
- **L7** 출하 바닥 검증(`--no-project`)은 프로젝트 lock 밖이라 **PyYAML 버전이 고정되지 않는다**. 그
  경로에서 PyYAML 이 깨지면 출하 바닥 검증만 빨개질 수 있고, 그것은 제품 결함이 아니다.
- **L8** 출하 셸 「39건 / 11파일」은 **하한**이다(§4). 범위 밖이라 이 설계엔 무해하지만, 범위를 다시 넓히는
  PR 은 심볼릭 링크 배포 지점과 `copy-of` 사본을 포함해 재집계해야 한다.

## Concrete Next Action

`superpowers:writing-plans` 로 구현 계획을 만든다. 첫 Task 는 해석기(`devbrew-python.sh`)와 그 변이
테스트이며, `hooks.json` 편집은 해석기가 변이 테스트로 검증된 **뒤에** 온다.

## 결정 기록

- **D1 — 출하 바닥은 3.12.** 사용자 결정. 제안은 3.11 이었고 근거는 3.12 가 3.11 사용자 24.3% 를 추가로
  잘라내는데 마이그레이션 비용은 동일하다는 것이었다. 사용자가 실측 분포를 보고 3.12 를 선택했다 — 단일
  최빈(30.9%)이고 runway 가 1년 길며, devbrew 사용자층은 자기 Python 을 직접 관리하는 개발자다.
- **D2 — 해석은 훅에만(초판).** 사용자 선택(「훅만 해석 · 나머지는 프리플라이트」). 근거는 훅과 스킬
  지시문의 **실패 가시성 비대칭**. D11 이 넓혔다가 **D17 이 되돌렸다**.
- **D3 — 해석기는 sh.** 파이썬으로 쓰면 그 파일이 3.9 에서 돌아야 한다는 제약이 생기고 3.9 테스트 레그가
  파생된다. 대가는 kill switch 의 네 번째 본문이며 AC22 가 그것을 묶는다.
- **D4 — 매트릭스 레그를 만들지 않는다.** 사용자 질문(「레그를 꼭 해야할까」)에서 재검토.
- **D5 — uv 를 리포에 들인다.** 초안은 「pyproject·lock 없이 `uv run --with pyyaml`」이었고 사용자 반론
  (「같은걸 안들이는 이유가 있어? 들이는게 좋지않나」)으로 철회했다. 초안 논거의 절반이 이미 무효였다 —
  *「`requires-python` 을 적으면 3.9 레그가 막힌다」* 는 D4 로 레그가 사라지면서 소멸했는데 결론만 남아
  있었다.
- **D6 — ruff 는 제외.** 회귀 판별 오염(R5).
- **D7 — 출하 PyYAML 은 별도 PR.**

라운드 1 채택(사용자 판정 8건 전부 채택):

- **D8 — 안내 채널을 바꾼다.** stderr + exit 0 이 실측으로 반증됐다(0/1 도달). C1·§2·AC5.
- **D9 — kill switch 가 해석기보다 위에 선다.** C3·AC6.
- **D10 — `sh <경로>` 로 부른다.** 실행 비트가 설치 캐시까지 사는지 측정된 적이 없다. C8·R11·AC1.
- **D11 — 집행을 훅의 자식과 출하 셸까지 넓힌다.** 제안은 「파이썬 자식만」이었으나 사용자가 「파이썬 +
  셸 39건까지」를 골랐다. **D17 이 되돌렸다.**
- **D12 — Goals 를 실제 범위로 기술한다.**
- **D13 — 도출 규칙을 산출물에 적는다.** Goal 6·AC15.
- **D14 — `.python-version` 은 개발 바닥을 따라간다.** AC9.
- **D15 — PATH 후보도 같은 버전 판정을 받는다.** AC3.
- **D16 — baseline 을 리포에 커밋한다**(차단 ask). `docs/audits/2026-09-21-python-floor-baseline.md`.

라운드 2 채택(사용자 판정 — 리뷰가 라운드 1 수정의 회귀를 잡은 라운드):

- **D17 — D11 을 되돌린다. 출하 셸 39자리는 범위 밖.** 근거는 그 39자리가 전부 스킬·커맨드가 Bash 로
  부르는 자리이고 훅에서 spawn 되는 셸(`qg-worktree.sh`)은 `python3` 를 쓰지 않는다는 실측이다 — §5 가
  스킬을 범위 밖으로 민 술어가 그대로 적용된다. 이 한 결정이 파생 결함 4건(셸 stdout 계약 충돌 · 39건
  하한 재집계 · plugin-audit 배포 경로 · kill switch 무언 종료가 사용자 스크립트를 죽이는 것)을 함께
  해소했다. Goals 1 · Non-goal 3 · §5 · AC12 · AC14 · Files to Modify · R13 · L2 · L8.
- **D18 — 해석기를 물리 사본으로 배포한다.** 심볼릭 링크면 `check-shape-completeness.py` 의 containment 가
  `.resolve()` 로 plugin root 밖을 보고 세 플러그인에 거짓 「kill switch 부재」를 낸다. 감사기 완화도
  검토했으나 보안 감사기를 약화시키므로 기각. C9·C11·AC20·R14.
- **D19 — AC18 의 PATH 에 `/bin` 을 넣는다.** 이 머신에 `/usr/bin/sh` 가 없어(실측) D10 이 AC18 을 조용히
  무효화하고 있었다. `/bin` 에는 `python3` 가 없어 바닥 미만 조건은 유지된다. AC18·VP3.
- **D20 — `DEVBREW_PYTHON` 통지를 환경변수로 넘긴다.** stdout JSON 으로 내고 `exec` 하면 훅 자신의 JSON 과
  합쳐져 문서가 둘이 되어 파싱이 깨진다. C12·§1 순서 2·AC8·R15.
- **D21 — kill switch 판정 의미를 정본 그대로 보존한다.** 쉼표 목록 · 전체 토큰 · 훅명/이벤트명 별칭 ·
  변수명 도출. 좁히면 `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` 사용자가 Goal 3 을 못 받는다.
  C3·AC6·AC22.
- **D22 — 출하 바닥 검증을 프로젝트 밖에 둔다.** 제안은 「한계로만 공시」였으나 사용자가 별도 검증 환경
  설계를 선택했다. uv 가 `requires-python` 을 집행하므로 개발 바닥이 높아지면 프로젝트 안에서는 출하
  바닥을 잴 수 없다. §3·§4·AC23·R16·L7.
- **D23 — Goal 5 의 수단도 산출물(README)에 적는다.** Goal 6 에 적용한 술어를 Goal 5 에도 적용한다.
  Goals 5·AC21.
- **D24 — C2 를 정확히 고친다.** 유일한 `PostToolUse` 자리가 `matcher: "Bash"` 이므로 「도구 호출마다」가
  아니라 「Bash 호출마다」다. 캐시 기각(R7) 결론은 유지하되 근거를 정확한 빈도 위에 세운다.

리뷰 절차에 대한 기록:

- **재비판이 기각한 것** — 「`source_interview` 가 파일을 안 가리켜 정본 대조가 불가능하다」는 codex
  finding 이 **두 라운드 연속** 나왔고 **두 번 다 오탐으로 기각**됐다. 리포의 설계문서 3개가 글자 그대로
  같은 frontmatter 를 달고 머지됐고 그중 셋째의 머지 커밋이 이 브랜치의 base 다.
- **저자의 절차 실수** — 라운드 1 채택분 8건을 적용할 때 편집을 `begin-round` **뒤에** 넣어, 라운드 2 의
  스냅샷이 편집 전 상태를 찍었다. 그 결과 8건이 전부 「채택 후 미적용(expired)」으로 재상승했다. 문서에
  실제로 적용돼 있음을 grep 으로 확인하고 재채택했다(D2.10~D2.17). **올바른 순서는 편집 → begin-round** 다.
- **permit 을 소비하지 못한 fix** — 라운드 1 의 「코퍼스 정의」 fix 는 `edit_scope` 가 실재 앵커가 아니었다.
  초판 목차의 링크가 깨져 있었고(헤딩의 괄호가 앵커에 들어갔다) 리뷰어가 그 깨진 링크를 받아 적었다.
  **세 리뷰어 누구도 이 링크를 잡지 못했다** — 셋 다 목차를 정답으로 읽었기 때문이다. 내용과 헤딩·목차
  교정은 수행했다.
- **저자가 찾아 넣은 것** — 리뷰어가 짚지 않은 두 자리: (1) 해석 실패 시 훅이 JSON 을 아예 출력하지
  않는다는 파생 결과(§2 가 해석기 자신이 JSON 을 찍게 한다), (2) 훅 4자리가 전부 stdin 을 읽으므로
  해석기는 stdin 불가침이고 `exec` 가 필수다(C7·AC7).
- **라운드 2 의 교훈** — 잡힌 것의 절반이 라운드 1 수정이 만든 회귀였고, 그 회귀는 전부 **결정 쌍**에서
  나왔다(D8×D11 · D8×AC8 · D10×AC18). finding 단위로 판정하고 한꺼번에 적용하면 이 축이 보이지 않는다.

### Deferred to plan

1. 해석기 안내 문구의 **정확한 텍스트** (AC5 의 세 요소를 담되 표현은 plan 이 정한다).
2. `pyproject.toml` 의 `[project]` 최소 필드 구성 — devbrew 는 배포되는 패키지가 아니므로 `name`/`version`
   을 어떻게 둘지. `project-init` 이 이 파일을 보고 devbrew 를 「Python 프로젝트」로 판정하게 되는 부작용의
   허용 여부도 여기서 확정한다.
3. 테스트 파일의 배치 — `shared/tests/` 단일인지 플러그인별로 쪼개는지.
4. 플러그인 버전 리터럴 (머지 직전 확정, AC17).
5. `DEVBREW_PYTHON_IGNORED` 의 정확한 키 이름과 훅 4자리가 그것을 합치는 코드 형태(AC8).
6. `SessionEnd`·대화형 TUI 채널 도달 측정 여부 (L5) — 잴지 말지.
7. **통과-정답 단언의 관측 절차와 변이 설계** — AC1·AC11·AC13·AC14·AC16·AC17. 자리별 원장 형식을
   포함한다. 개수 등호는 한 자리의 증가가 다른 자리의 소실을 갚아 대체 가능하므로, 합계가 아니라 자리별
   원장과 파일 밖 기대값으로 잰다.
8. AC22 parity 락의 케이스 축 — `DEVBREW_SKIP_HOOKS` 의 어떤 변형들을 두 구현에 먹일지.
