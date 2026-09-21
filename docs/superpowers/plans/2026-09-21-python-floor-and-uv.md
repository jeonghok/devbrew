# 출하 Python 바닥 3.12 + uv 도입 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew 훅 4자리와 훅이 spawn 하는 파이썬 자식 1건이 Python 3.12 이상에서 돈다는 것을 **해석으로 집행**하고, 바닥 미만 머신에는 도달이 실측된 채널로 세션당 한 번 안내를 내며, 개발·검증 환경을 uv 로 재현 가능하게 만든다.

**Architecture:** 훅 `command` 가 파이썬을 직접 부르지 않고 POSIX sh 해석기(`devbrew-python.sh`)를 `sh <경로>` 로 경유한다. 해석기는 kill switch 를 **먼저** 보고, `$DEVBREW_PYTHON` → `python3` → PATH 글롭 `python3.*` 순으로 바닥을 만족하는 인터프리터를 찾아 `exec` 한다. 못 찾으면 `python3` 로 내려가지 않고(fail-open, 훅 생략) `SessionStart` 에서만 안내 JSON 하나를 낸다. 해석기는 `shared/python/` 에 정본을 두고 훅을 가진 세 플러그인에 **물리 사본**으로 배포된다(심볼릭 링크는 감사기 containment 를 깬다). uv 는 개발 바닥만 고정하며 출하 요구사항이 아니다.

**Tech Stack:** POSIX sh (dash·ksh·bash 3.2 에서 실측 동치) · Python 3.9+ 로 읽히는 훅 파이썬 · `hooks.json` · uv 0.10 (`pyproject.toml` · `uv.lock` · `.python-version`) · bash 테스트 + `shared/tests/assert.sh`

**Spec:** [`docs/superpowers/specs/2026-09-21-python-floor-and-uv-design.md`](../specs/2026-09-21-python-floor-and-uv-design.md) (커밋 `e683d64f`)

**Baseline:** [`docs/audits/2026-09-21-python-floor-baseline.md`](../../audits/2026-09-21-python-floor-baseline.md) — base `d24d3045`, bash 205 자리 / python 4 디렉토리 648 tests, **선재 RED 4건**이 각각의 이유와 함께 적혀 있다. 회귀 판정은 rc 가 아니라 **자리별 실패 줄 수 + `Ran N` + 실패한 테스트 이름**으로 한다.

**작업 위치:** 브랜치 `feature/python-floor-uv`, 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-floor-uv`. 모든 명령은 이 워크트리 루트에서 돈다.

## 목차

- [Global Constraints](#global-constraints)
- [착수 전 실측으로 확정된 사실](#착수-전-실측으로-확정된-사실)
- [spec 이 plan 으로 미룬 것의 답](#spec-이-plan-으로-미룬-것의-답)
- [File Structure](#file-structure)
- [Task 1: 해석기 `devbrew-python.sh` 와 그 변이 테스트](#task-1-해석기-devbrew-pythonsh-와-그-변이-테스트)
- [Task 2: 물리 사본 배포와 `copy-of` 계약](#task-2-물리-사본-배포와-copy-of-계약)
- [Task 3: `hooks.json` 4 자리 배선과 PATH 격리 시뮬레이션](#task-3-hooksjson-4-자리-배선과-path-격리-시뮬레이션)
- [Task 4: 훅이 spawn 하는 `python3` 제거](#task-4-훅이-spawn-하는-python3-제거)
- [Task 5: `session-start-advisor.py` 의 `DEVBREW_PYTHON_IGNORED` 공시](#task-5-session-start-advisorpy-의-devbrew_python_ignored-공시)
- [Task 6: uv 층 — `pyproject.toml` · `.python-version` · `uv.lock`](#task-6-uv-층--pyprojecttoml--python-version--uvlock)
- [Task 7: 도출 규칙과 prerequisite 를 산출물에 적는다](#task-7-도출-규칙과-prerequisite-를-산출물에-적는다)
- [Task 8: 커버리지 락 동거와 baseline 전수 대조](#task-8-커버리지-락-동거와-baseline-전수-대조)
- [Task 9: version bump 와 CHANGELOG (머지 직전)](#task-9-version-bump-와-changelog-머지-직전)
- [이 계획이 «하지 않는» 일](#이-계획이-하지-않는-일)
- [알려진 한계 (구현이 지우지 못하는 것)](#알려진-한계-구현이-지우지-못하는-것)

## Global Constraints

이 절의 값은 spec 에서 **글자 그대로** 옮긴 것이다. 모든 Task 의 요구사항에 묵시적으로 포함된다.

- **출하 바닥 = 3.12.** 리터럴이 아니라 도출값이다 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」. 다음 재검토는 3.12 EOL(2028-10). 정본은 `shared/python/devbrew-python.sh` 의 `FLOOR_MAJOR`·`FLOOR_MINOR`.
- **개발 바닥 = 3.12.** 정본은 `pyproject.toml` 의 `requires-python`. **출하 바닥과 같은 숫자지만 같은 사실이 아니다** — 한 자리에서 읽어 다른 자리에 쓰지 않는다.
- **집행 범위는 훅 4자리 + 훅이 spawn 하는 파이썬 자식 1건뿐.** 출하 셸 39자리 · 스킬/커맨드 지시문 · 문서 · 테스트의 `python3` 는 **범위 밖**이다(Non-goal 3, D17). 건드리지 않는다.
- **C1 — 훅의 텍스트 채널.** stderr + `exit 0` = 모델 도달 **0/1**(`PostToolUse(Read)` 값이고 이 설계의 자리인 matcher Bash 는 미측정) · `systemMessage` = **0/14**(사람은 transcript 에서 본다) · `hookSpecificOutput.additionalContext` = **8/8**(`SessionStart` 3/3). 안내를 stderr 로 내면 침묵이다.
- **C2 — kill switch 는 보안 컨트롤이고 해석기가 그 위에 앉는다.** 판정 의미는 `shared/killswitch/kill_switch_active.py` 와 같아야 한다: 쉼표 목록 분리 · 공백 제거 · **전체 토큰** 대조(부분 일치 금지) · 훅명 **또는** 이벤트명 별칭 · 변수명 `-`→`_`+대문자 **도출**(표 금지).
- **C3 — 해석 실패의 방향은 fail-open.** 훅은 조언·청소·검증이지 보안 게이트가 아니다. 막지 않는다.
- **C4 — 마이너 버전을 열거하지 않는다.** 내일 추가될 버전을 오늘 적을 수 없다.
- **C5 — `python3` 로의 fallback 금지.**
- **C6 — 해석기는 stdin 을 건드릴 수 없다.** 훅 4자리 전부가 payload 를 stdin 으로 읽는다(실측). 반드시 `exec` 로 넘기고 이름은 **인자로** 받는다.
- **C7 — 훅의 stdout 은 JSON 문서 «하나».** `exec` 하는 경로에서 해석기의 stdout 은 **비어 있다**.
- **C8 — 실행 비트의 설치 캐시 생존은 미측정.** 그래서 `sh <경로>` 로 부른다.
- **C9 — 감사기는 확장자로 스크립트를 찾고 plugin root «안»만 판독한다.** 해석기는 `.sh` 로 끝나야 하고 **심볼릭 링크가 아니라 물리 사본**이어야 한다.
- **C10 — 물리 사본은 `copy-of` 계약을 탄다.** `shared/tests/test_copy_of_contract.sh:44` 의 `HEAD_WINDOW=20` 안에 `# copy-of:` 마커가 있어야 하고, `:599` 가 **그 줄만 빼고 바이트 동일**을 요구한다. 정본과 사본은 **같은 커밋에서** 고친다.
- **C11 — 정적 검사로는 3.9 실행 가능성을 보장할 수 없다.** `ast.parse(feature_version=(3,9))` 는 PEP604 를 통과시킨다. 해석기를 sh 로 쓰는 것이 이 제약의 회피책이다.
- **CLAUDE.md** — `plugins/<name>/` 을 건드리는 PR 은 같은 커밋에서 `plugin.json` version bump(Task 9). 문서는 Korean-primary. 300줄 미만 문서는 `## 목차` 면제.

## 착수 전 실측으로 확정된 사실

이 계획이 기대는 값들이다. **추측이 아니라 이 워크트리에서 잰 것**이고, 각각이 어느 Task 를 좌우하는지 적는다.

| 사실 | 측정 | 영향 |
|---|---|---|
| `/usr/bin/sh` 가 **없다** (`/bin/sh` 만 있다) | `ls -l /usr/bin/sh` → No such file | AC12 의 PATH 에 `/bin` 이 필요하다(D19) |
| `python3` = `/usr/bin/python3` = **3.9.6**, `python3.12` = `~/.local/bin/python3.12` | `python3 -VV` | AC12 의 자기 확인이 오늘은 참이다(L3) |
| `_KILLSWITCH_RE = DEVBREW_[A-Z0-9_]*_DISABLE` 가 **도출형 `DEVBREW_${_up}_DISABLE` 를 못 본다.** `DEVBREW_<PLUGIN>_DISABLE` 같은 꺾쇠 플레이스홀더도 **못 본다** | 실측 — 구체 예시(`DEVBREW_SPEC_DISTILL_DISABLE`)만 MATCH | **Task 1**: 해석기는 구체 예시 한 줄을 머리에 가져야 AC11 의 `hooks_killswitch: true` 가 유지된다. Task 3 이 이것을 변이로 잰다 |
| `tr` 를 쓰면 PATH 에 `/usr/bin` 이 없을 때 **kill switch 가 조용히 fail-open** 한다 | 프로토타입 실측 — `tr: command not found` 두 줄 + AC2 양성대조가 아무것도 안 재고 통과 | **Task 1**: 해석기는 외부 명령을 하나도 부르지 않는다. 그 성질 자체를 락으로 잰다 |
| `/bin/sh` 를 테스트 PATH 로 **복사하면 macOS 코드서명이 SIGKILL** 한다(rc 137) | 실측 | 테스트 fixture 는 셸을 복사하지 말고 실제 `/bin` 을 PATH 에 둔다 |
| `test_command_contract.py:125` 가 `h["command"].split()[-1]` 로 훅 스크립트를 뽑는다 | 소스 | **훅 `.py` 경로가 command 의 «마지막 토큰»이어야 한다** |
| `uv run --python 3.9` 이 `requires-python` 위반으로 **거부된다** | 실측 — `error: The requested interpreter resolved to Python 3.9.6, which is incompatible with the project's Python requirement: >=3.12` | AC9 의 uv 쪽 이빨 |
| `uv run` 은 **상위 디렉토리로 올라가** 루트 `pyproject.toml` 을 찾는다 | 실측(`sub/tests/` 에서 성공) | 기존 테스트 러너가 자리마다 `cd` 해도 그대로 쓴다 |
| `.gitignore` 의 `uv.lock`(:104) · `.python-version`(:91) 은 **주석 처리돼 있고** `.venv`(:143) 는 무시된다 | 소스 | `.gitignore` 를 편집하지 않는다 |
| 해석기 프로토타입이 **dash · ksh · bash-as-sh 에서 동일 동작** | 실측 8케이스 × 3셸 | POSIX 주장이 산문이 아니다 |

---

## spec 이 plan 으로 미룬 것의 답

설계문서 `### Deferred to plan` 일곱 건에 대한 결정이다. **어디서 집행되는지**를 함께 적는다 — 결정만 적고 집행 자리가 없으면 그것이 R8 이 기각한 「집행 없는 선언」이다.

| # | 미뤄진 것 | 결정 | 집행 |
|---|---|---|---|
| 1 | 안내 문구의 정확한 텍스트 | Task 1 Step 4 의 `_msg` 그대로. (a) 발견된 최고 버전 · (b) 요구 바닥 · (c) `uv python install` 또는 `$DEVBREW_PYTHON` | 축 A8 이 세 요소를 각각 본다 |
| 2 | `pyproject.toml` 의 `[project]` 최소 필드 | `name` · `version = "0"` · `requires-python` 셋 + `[tool.uv] package = false`. **`project-init` 이 devbrew 를 「Python 프로젝트」로 판정하게 되는 부작용은 허용한다** — devbrew 는 실제로 `.py` 181개를 담은 파이썬 리포이고, `/project-init` 의 Phase 0 은 manifest **와 디렉토리 구조**를 함께 본다(`commands/project-init.md:93`). 이 파일이 없어도 같은 판정이 났을 것이므로 새 거짓을 만들지 않는다 | 축 H 가 `package = false` 를 본다 |
| 3 | 테스트 파일의 배치 | `shared/tests/test_python_floor.sh` **하나**. 재는 대상이 정본 1 + 사본 3 + `hooks.json` 3 + 루트 파일 3 이라 본래 크로스-플러그인이고, `shared/README.md` 가 그 자리를 「크로스-플러그인 락」으로 이미 정의한다. 플러그인별로 쪼개면 사본 3벌의 **바이트 동일**을 세 파일이 각자 주장하게 된다 | Task 1~7 이 한 파일에 축을 쌓는다 |
| 4 | 플러그인 버전 리터럴 | **머지 직전에 정한다.** 먼저 머지되는 PR 이 이기고, 같은 버전 문자열은 충돌 없이 병합된다 | Task 9 Step 1 이 그때 읽는다 |
| 5 | `DEVBREW_PYTHON_IGNORED` 키 이름과 advisor 코드 형태 | 키 이름은 설계 그대로 `DEVBREW_PYTHON_IGNORED`. 코드는 Task 5 Step 3 의 `_emit_python_ignored_notice()` — `main()` 끝에서 한 번, **이 훅의 유일한 stdout writer** | 축 A12 가 양·음 짝을 둘 다 본다 |
| 6 | AC1·AC14·AC16·AC17 의 관측 절차 | Task 8 Step 4 의 여섯 명령과 기대값 | 그 Step |
| 7 | 해석기 머리 20줄 예산의 배분 | **예산 문제가 성립하지 않는다.** 마커를 shebang 바로 뒤 **2번째 줄**에 두면(`runner_common.sh` 선례) `HEAD_WINDOW=20` 은 언제나 만족된다 — 머리 주석의 길이와 무관해진다 | Task 2 Step 3 의 생성 명령이 그 자리를 고정하고, 축 B 가 줄 번호를 출력한다 |

---

## File Structure

| 경로 | 신규/편집 | 책임 |
|---|---|---|
| `shared/python/devbrew-python.sh` | 신규 | **출하 바닥의 정본**. 해석 + kill switch + 안내. 외부 명령 의존 0 |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` | 신규 | 위의 **물리 사본**(`# copy-of:` 2번 줄). 설치본에서 도달 가능한 유일한 형태 |
| `plugins/{project-init,quality-gates,spec-distill}/hooks/hooks.json` | 편집 | 4 자리의 `command` 를 `sh <해석기> … <훅.py>` 로 |
| `plugins/quality-gates/hooks/session-start-advisor.py` | 편집 | `DEVBREW_PYTHON_IGNORED` 공시 (해석이 **성공한** 경로의 절반) |
| `plugins/spec-distill/scripts/hook_common.py` | 편집 | 훅 자식 spawn 을 `sys.executable` 로 |
| `pyproject.toml` · `.python-version` · `uv.lock` | 신규(루트) | **개발** 바닥과 테스트 의존성 |
| `README.md`(루트) · `plugins/{project-init,quality-gates,spec-distill}/README.md` | 편집 | 도출 규칙(AC13) + prerequisite(AC14) |
| `shared/README.md` | 편집 | `## 디렉토리` 표에 `shared/python/` 행 |
| `shared/tests/test_python_floor.sh` | 신규 | 축 A~H. `# guards:` + `--emit-scanned` |
| `plugins/*/.claude-plugin/plugin.json` ×4 · `plugins/*/CHANGELOG.md` ×4 | 편집 | version·기록 |

**`plugin-audit` 에는 해석기도 prerequisite 도 두지 않는다** — 훅이 없고 셸 13자리는 범위 밖이라 그 바닥을 집행하는 주체가 없다(D27). version·CHANGELOG 만 건드린다.

---

### Task 1: 해석기 `devbrew-python.sh` 와 그 변이 테스트

**Files:**
- Create: `shared/python/devbrew-python.sh`
- Create: `shared/tests/test_python_floor.sh` (축 A — 해석기 행동. 축 B~H 는 Task 2·3·4·5·6·7 이 채운다)

**Interfaces:**
- Produces: 호출 규약 `sh <해석기> --event <E> --plugin <P> --hook <H> <훅.py> [인자…]`. `--` 로 옵션을 끊을 수 있다. 인자를 알아보지 못하면 그 자리부터 전부 exec 대상으로 넘긴다.
- Produces: 자식 환경변수 `DEVBREW_PYTHON_IGNORED` — `$DEVBREW_PYTHON` 이 바닥을 못 넘겨 무시됐을 때만 설정되고, 값은 사람이 읽는 한 줄 사유다. Task 5 가 읽는다.
- Produces: 파일 상수 `FLOOR_MAJOR` · `FLOOR_MINOR` — **줄 머리에 `FLOOR_MAJOR=3` 형태**로 선다. Task 6·7 의 테스트가 `sed -n 's/^FLOOR_MINOR=\([0-9][0-9]*\)$/\1/p'` 로 읽는다.
- Produces: 테스트 헬퍼 함수 `emit_scanned` 계약 — `bash shared/tests/test_python_floor.sh --emit-scanned` 는 **이 락이 실제로 읽는 경로**를 한 줄에 하나씩 내고 즉시 `exit 0`.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`shared/tests/test_python_floor.sh` 를 만든다. **`# guards:` 줄은 2번째 줄**이어야 한다 — `test_guards_coverage_bidirectional.sh` 가 `head -30` 안에서 찾는다.

````bash
#!/usr/bin/env bash
# guards: shared/python/** plugins/*/scripts/devbrew-python.sh plugins/*/hooks/hooks.json plugins/quality-gates/hooks/session-start-advisor.py plugins/spec-distill/scripts/hook_common.py plugins/*/README.md README.md pyproject.toml .python-version uv.lock
#
# 출하 Python 바닥의 «집행» 이 살아 있는가. 선언은 여기서 재지 않는다 — 선언만 한 바닥은
# 훅이 읽지 않는다는 것이 이 설계의 출발점이다(설계 Context/Why 3).
#
# 축 A 해석기 행동 · B 배포(물리 사본) · C 배선(hooks.json) · D 두 바닥 · E 훅 자식 ·
# F 도출 규칙의 산출물 기록 · G prerequisite · H uv.lock 핀.
#
# **이 락이 스스로 못 지키는 것** — fixture 로 쓰는 가짜 인터프리터가 「바닥을 만족한다」고
# 거짓말하는 것 자체는 못 잰다. 그것이 이 락의 «측정 수단»이기 때문이다. 대신 축 A 는 같은
# fixture 로 양성(3.99 를 고른다)과 음성(3.9 를 건너뛴다)을 **둘 다** 요구한다 — 한쪽만
# 통과시키는 고장은 없다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

RESOLVER="shared/python/devbrew-python.sh"

# `--emit-scanned` — 이 락이 **실제로 읽는** 경로. 선언에서 도출하면 선언의 자기 반복이라
# 커버리지 증거가 안 된다(Task 6 의 양방향 검사가 이것을 읽는다). assert.sh 를 source 하기
# **전에** 답한다 — 헬퍼가 깨져도 커버리지 대조는 답을 받아야 한다.
SCANNED="shared/python/devbrew-python.sh
plugins/project-init/scripts/devbrew-python.sh
plugins/quality-gates/scripts/devbrew-python.sh
plugins/spec-distill/scripts/devbrew-python.sh
plugins/project-init/hooks/hooks.json
plugins/quality-gates/hooks/hooks.json
plugins/spec-distill/hooks/hooks.json
plugins/quality-gates/hooks/session-start-advisor.py
plugins/spec-distill/scripts/hook_common.py
plugins/plugin-audit/README.md
plugins/project-init/README.md
plugins/quality-gates/README.md
plugins/spec-distill/README.md
README.md
pyproject.toml
.python-version
uv.lock"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$SCANNED"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

# 출하 바닥은 **해석기에서 도출한다** — 숫자를 이 락에 리터럴로 핀하면 바닥이 움직이는 날
# stale-red 가 된다(리포에 전례가 있다). 도출이 비면 아래 대조가 전부 헛돌므로 **증인을
# 먼저 세운다** — 재도출 락은 보간 실패를 스스로 못 잡는다.
FLOOR_MAJOR_VAL="$(sed -n 's/^FLOOR_MAJOR=\([0-9][0-9]*\)$/\1/p' "$RESOLVER" 2>/dev/null | head -1)"
FLOOR_MINOR_VAL="$(sed -n 's/^FLOOR_MINOR=\([0-9][0-9]*\)$/\1/p' "$RESOLVER" 2>/dev/null | head -1)"
case "${FLOOR_MAJOR_VAL:-x}.${FLOOR_MINOR_VAL:-x}" in
  *[!0-9.]*|.*|*.) no "증인: 해석기에서 FLOOR_MAJOR/FLOOR_MINOR 를 못 읽었다 — 축 C2·D·F·G 의 대조는 무의미하다" ;;
  *) ok "증인: 출하 바닥 ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL} 를 해석기에서 도출했다" ;;
esac

# ── fixture: 가짜 인터프리터 ────────────────────────────────────────────────
# 셸을 **복사하지 않는다** — /bin/sh 사본은 macOS 코드서명 위반으로 SIGKILL(rc 137) 된다
# 〔실측〕. 좁힌 PATH 에는 실제 `/bin` 을 둔다(이 머신엔 /usr/bin/sh 가 없다 — D19).
TMP="$(mktemp -d)"
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "mktemp -d 실패 — 아무것도 재지 않았다"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/floor" "$TMP/sub" "$TMP/plain"

cat > "$TMP/floor/python3.99" <<'FAKE'
#!/bin/sh
# 바닥을 만족한다고 «답하고», 그 밖에는 **건네받은 스크립트를 실제로 실행한다** — 진짜
# 인터프리터가 하는 일이 그것이다. 자기 마커만 찍고 끝내면 argv 전달도 stdin 전달도 재지
# 못하고, A9 의 「사유가 자식 환경으로 간다」는 원리적으로 관측 불가가 된다.
[ "$1" = "-c" ] && { echo "3 99"; exit 0; }
exec "$@"
FAKE
cat > "$TMP/sub/python3.9" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && { echo "3 9"; exit 0; }
echo "EXECED-SUBFLOOR"
exit 0
FAKE
cat > "$TMP/plain/python3" <<'FAKE'
#!/bin/sh
[ "$1" = "-c" ] && { echo "3 9"; exit 0; }
echo "EXECED-PLAIN-PYTHON3"
exit 0
FAKE
chmod +x "$TMP/floor/python3.99" "$TMP/sub/python3.9" "$TMP/plain/python3"
# `python3.12-config` 류가 후보로 새지 않는지 — 실행 가능하고 이름이 맞아도 제외돼야 한다
cat > "$TMP/floor/python3.12-config" <<'FAKE'
#!/bin/sh
echo "CONFIG-SHOULD-NOT-RUN"; exit 0
FAKE
chmod +x "$TMP/floor/python3.12-config"

TARGET="$TMP/target.sh"      # 훅 대역 — exec 됐는지와 stdin 이 온전한지를 함께 증명한다
cat > "$TARGET" <<'T'
#!/bin/sh
# **내장 명령만 쓴다** — A4b 는 coreutils 가 하나도 없는 PATH 로 돈다(`cat` 이 없다).
# `|| [ -n "$_line" ]` 는 장식이 아니다: payload 는 `printf '%s'` 로 와서 **끝에 개행이
# 없고**, 그 가드가 없으면 마지막(=유일한) 줄이 통째로 버려져 A10 이 조용히 RED 다
# 〔/bin/sh · dash · ksh 셋 다 실측〕. 리포의 같은 관용구:
# plugins/spec-distill/tests/test_seed_agents.sh:173
echo "TARGET-RAN"
while IFS= read -r _line || [ -n "$_line" ]; do printf '%s\n' "$_line"; done
T
chmod +x "$TARGET"

PAY='{"event":"probe","canary":"PAYLOAD-INTACT"}'
# 인자는 `env` 에 **그대로** 넘긴다. 환경 할당을 한 문자열로 모아 unquoted 확장하면
# 값에 공백이 있는 순간(예: `DEVBREW_SKIP_HOOKS= a , b`) 쪼개져서 env 가 둘째 조각을
# 명령으로 읽는다 — 그 케이스가 바로 아래 A3 이다.
run_resolver() {   # run_resolver <PATH> [VAR=val …] /bin/sh <해석기> <인자…>
  _p="$1"; shift
  printf '%s' "$PAY" | env PATH="$_p" "$@" 2>/dev/null
}

PATH_FLOOR="$TMP/floor:$TMP/plain:/bin"     # 바닥 만족 후보가 있다
PATH_SUB="$TMP/sub:$TMP/plain:/bin"         # 바닥 미만만 있다
PATH_BARE="$TMP/floor"                      # coreutils 가 **하나도 없다** (A4 용)
R="$ROOT/$RESOLVER"

note "── 축 A: 해석기 행동 ───────────────────────────────────────────────"

# A1 (AC5a) 전역 스위치가 해석보다 먼저다 — 바닥 만족 인터프리터가 있어도 아무것도 안 한다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_QUALITY_GATES_DISABLE=1 /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A1/AC5a: DEVBREW_QUALITY_GATES_DISABLE=1 이면 stdout 이 비고 훅이 안 돈다"

# A2 (AC5b) 전체 토큰 — 부분 일치는 끄지 않는다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A2/AC5b: 부분 일치 'quality-gates:session-start' 는 끄지 않는다"
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A2/AC5b: 전체 토큰 훅명은 끈다"

# A3 (AC5c) 이벤트 별칭 + 공백 제거 + 쉼표 목록
out="$(run_resolver "$PATH_FLOOR" "DEVBREW_SKIP_HOOKS= quality-gates:SessionStart ,other:x" /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_eq "$out" "" "A3/AC5c: 이벤트 별칭 + 앞뒤 공백 + 쉼표 목록이 정본과 같게 판정된다"
# 하위 기능 토큰은 훅 전체를 끄지 않는다 — 정본의 의미를 «넓히지도» 않는다
out="$(run_resolver "$PATH_FLOOR" DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan /bin/sh "$R" \
        --event SessionStart --plugin quality-gates --hook session-start-advisor "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A3/AC5c: 하위 기능 토큰은 훅 전체를 끄지 않는다(정본과 동치)"

# A4 (AC5 순서 + PATH 불신) — 해석기가 외부 명령에 기대지 않는다는 것을 **행동으로** 잰다.
#    〔실측〕 kill switch 의 변수명 도출을 `tr` 로 쓰면 PATH 에 /usr/bin 이 없을 때
#    `tr: command not found` 로 판정이 **조용히 fail-open** 하고, PATH 분리를 `tr` 로 쓰면
#    글롭 스캔이 통째로 죽는다. 둘 다 텍스트 grep 이 아니라 실행으로 잡는다 — 해석기 본문이
#    그 명령 «이름» 을 주석에서 언급하므로 텍스트 락은 자기 주석에 걸린다.
out="$(printf '%s' "$PAY" | env -i PATH= DEVBREW_SKIP_HOOKS=quality-gates:SessionStart \
        /bin/sh "$R" --event SessionStart --plugin quality-gates \
        --hook session-start-advisor "$TARGET" 2>/dev/null)"
assert_eq "$out" "" "A4a: PATH 가 비어도 kill switch 가 발동한다"
out="$(printf '%s' "$PAY" | env -i PATH="$PATH_BARE" \
        /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET" 2>/dev/null)"
assert_contains "$out" "TARGET-RAN" "A4b: coreutils 가 하나도 없는 PATH 에서도 글롭 스캔이 python3.99 를 찾는다"

# A5 (AC2 양성 대조) 바닥을 만족하는 python3.99 를 고른다 — 리터럴 열거였다면 «오늘 쓴
#    어떤 목록에도 3.99 가 없으므로» 못 고른다. 이것이 AC2 의 변이(글롭→열거)와 같은 자리다.
out="$(run_resolver "$PATH_FLOOR" /bin/sh "$R" --event SessionStart --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A5/AC2: PATH 글롭이 python3.99 를 찾아 exec 한다 (양성 대조)"
assert_not_contains "$out" "CONFIG-SHOULD-NOT-RUN" "A5/AC2: python3.12-config 류는 후보가 아니다"

# A6 (AC3) 후보도 같은 판정을 받는다 — 바닥 미만 python3.9 는 건너뛴다
out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_not_contains "$out" "EXECED-SUBFLOOR" "A6/AC3: 바닥 미만 python3.9 후보를 exec 하지 않는다"
assert_eq "$out" "" "A6/AC3: 건너뛴 뒤 SessionEnd 는 아무것도 찍지 않는다"

# A7 (AC4) python3 로 fallback 하지 않는다
assert_not_contains "$out" "EXECED-PLAIN-PYTHON3" "A7/AC4: 바닥 미만 python3 로 내려가지 않는다"

# A8 (AC7) 안내는 SessionStart 에서만. 문서 «하나» 에 두 키.
out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event SessionStart --plugin qg --hook h "$TARGET")"
guide_report="$(printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)          # 문서가 둘이면 여기서 깨진다 (C7)
except ValueError as e:
    print("parse_error: %s" % e); raise SystemExit(0)
ctx = d.get("hookSpecificOutput", {}).get("additionalContext", "")
print("one_doc: yes")
print("has_system_message: %s" % ("yes" if d.get("systemMessage") else "no"))
print("has_additional_context: %s" % ("yes" if ctx else "no"))
print("event_name: %s" % d.get("hookSpecificOutput", {}).get("hookEventName", ""))
print("mentions_found: %s" % ("yes" if "3.9" in ctx else "no"))
print("mentions_floor: %s" % ("yes" if "3.12" in ctx else "no"))
print("mentions_fix: %s" % ("yes" if "DEVBREW_PYTHON" in ctx or "install" in ctx else "no"))
')"
assert_eq "$(field one_doc "$guide_report")" "yes" "A8/AC7: SessionStart stdout 이 JSON 문서 «하나» 다"
assert_eq "$(field has_system_message "$guide_report")" "yes" "A8/AC7: systemMessage 가 있다 (사람)"
assert_eq "$(field has_additional_context "$guide_report")" "yes" "A8/AC7: additionalContext 가 있다 (모델)"
assert_eq "$(field event_name "$guide_report")" "SessionStart" "A8/AC7: hookEventName 이 SessionStart 다"
assert_eq "$(field mentions_found "$guide_report")" "yes" "A8/AC7: (a) 발견된 최고 버전을 싣는다"
assert_eq "$(field mentions_floor "$guide_report")" "yes" "A8/AC7: (b) 요구 바닥을 싣는다"
assert_eq "$(field mentions_fix "$guide_report")" "yes" "A8/AC7: (c) 고치는 법을 싣는다"
for ev in SessionEnd PostToolUse; do
  out="$(run_resolver "$PATH_SUB" /bin/sh "$R" --event "$ev" --plugin qg --hook h "$TARGET")"
  assert_eq "$out" "" "A8/AC7: $ev 는 해석에 실패해도 stdout 이 비어 있다 (중복 주입 방지)"
done

# A9 (AC8) $DEVBREW_PYTHON — 만족하면 이기고, 불만족이면 stdout 무기록 + 환경으로 사유
out="$(run_resolver "$PATH_SUB" "DEVBREW_PYTHON=$TMP/floor/python3.99" /bin/sh "$R" \
        --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_contains "$out" "TARGET-RAN" "A9/AC8: 바닥을 만족하는 \$DEVBREW_PYTHON 이 이긴다"
REPORT_ENV="$TMP/report_env.sh"
cat > "$REPORT_ENV" <<'R'
#!/bin/sh
# stdin 을 읽지 않는다 — 여기서 재는 것은 «환경» 이고, payload 는 파이프 버퍼에 이미
# 다 쓰여 있다(수십 바이트). 읽지 않는 쪽이 움직이는 부품이 하나 적고, 위 $TARGET 의
# 가드 없는 사본이 이 파일에 남아 복사되는 일도 없다.
echo "ignored=${DEVBREW_PYTHON_IGNORED-}"
R
chmod +x "$REPORT_ENV"
out="$(run_resolver "$PATH_FLOOR" "DEVBREW_PYTHON=$TMP/sub/python3.9" /bin/sh "$R" \
        --event SessionEnd --plugin qg --hook h "$REPORT_ENV")"
assert_grep "$out" '^ignored=.+python3\.9' "A9/AC8: 불만족 \$DEVBREW_PYTHON 사유가 자식 «환경» 으로 간다"
assert_not_grep "$out" '^\{' "A9/AC8: 그 통지를 stdout JSON 으로 찍지 않는다 (문서가 둘이 되면 C7 위반)"

# A10 (AC6) stdin 불가침
out="$(run_resolver "$PATH_FLOOR" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$TARGET")"
assert_contains "$out" "PAYLOAD-INTACT" "A10/AC6: payload 가 훅에 그대로 간다 (해석기는 stdin 을 읽지 않는다)"

# A11 (AC11 의 파일-국소 전제) plugin-audit 의 kill switch 판정기 정규식은
#     `DEVBREW_[A-Z0-9_]*_DISABLE` 이라 **도출형 이름도 꺾쇠 플레이스홀더도 못 본다**
#     〔실측〕. 그래서 머리에 구체 예시 한 줄이 필요하다. 진짜 소비자를 보는 것은 Task 2 의
#     축 B(감사기를 실제로 돌린다)이고, 이 단언은 축 B 가 붙기 전까지의 대역이자
#     「어느 파일이 원인인지」를 바로 가리키는 국소 신호다.
assert_file_grep "$ROOT/$RESOLVER" 'DEVBREW_[A-Z0-9_]+_DISABLE' \
  "A11: 해석기 본문에 plugin-audit 가 읽을 수 있는 구체 kill switch 이름이 있다"

finish
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `assert_file_grep` 이 `(파일 없음: …/shared/python/devbrew-python.sh)` 를 내고, 나머지 축 A 단언이 빈 출력으로 떨어진다. `Total:` 줄이 **나와야** 한다(안 나오면 스크립트 자체가 죽은 것이다 — fixture 생성 실패를 의심하라).

- [ ] **Step 3: `--emit-scanned` 가 커버리지 계약을 만족하는지 먼저 본다**

Run: `bash shared/tests/test_python_floor.sh --emit-scanned`
Expected: 17줄. 첫 줄 `shared/python/devbrew-python.sh`, 마지막 줄 `uv.lock`. **rc 0.**

- [ ] **Step 4: 해석기를 쓴다**

`shared/python/devbrew-python.sh` 를 아래 내용 그대로 만든다. 이 본문은 프로토타입으로 **dash · ksh · bash-as-sh 에서 8케이스 실측**을 통과한 것이다.

````sh
#!/bin/sh
# devbrew 훅의 Python 인터프리터 해석기. 훅 `command` 가
# `sh <이 파일> --event E --plugin P --hook H <훅.py>` 로 부르고,
# 바닥을 만족하는 인터프리터를 찾아 exec 한다.
#
# 출하 바닥 도출 규칙 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
#   2026-09 시점의 그 값이 3.12 다. 다음 재검토 시점은 3.12 EOL(2028-10).
#   숫자를 손으로 올리지 않는다 — 이 규칙을 다시 적용한다.
FLOOR_MAJOR=3
FLOOR_MINOR=12

# 이 스크립트는 **외부 명령을 하나도 부르지 않는다**(자기가 판정하는 파이썬 제외).
# `tr`·`sed` 를 쓰면 PATH 에 /usr/bin 이 없을 때 `command not found` 로 아래 kill switch
# 판정이 조용히 fail-open 한다 — 실측했다. PATH 를 불신하는 것이 이 파일의 일이다.

EVENT=""; PLUGIN=""; HOOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --event)  [ $# -ge 2 ] || exit 0; EVENT="$2";  shift 2 ;;
    --plugin) [ $# -ge 2 ] || exit 0; PLUGIN="$2"; shift 2 ;;
    --hook)   [ $# -ge 2 ] || exit 0; HOOK="$2";   shift 2 ;;
    --)       shift; break ;;
    *)        break ;;
  esac
done
[ $# -ge 1 ] || exit 0

# ── kill switch (C2) — 어떤 일보다 앞. 의미는 정본과 같다:
#    shared/killswitch/kill_switch_active.py
#      DEVBREW_<플러그인>_DISABLE=1  — 이름을 플러그인명에서 **도출한다**(`-`→`_`, 대문자).
#                                     예: spec-distill -> DEVBREW_SPEC_DISTILL_DISABLE=1
#      DEVBREW_SKIP_HOOKS=<plugin>:<hook>  또는  <plugin>:<event>  (쉼표 목록, 전체 토큰)
#    위 「예:」 줄은 장식이 아니다 — plugin-audit 의 `_KILLSWITCH_RE`
#    (`DEVBREW_[A-Z0-9_]*_DISABLE`)가 도출형 이름을 못 읽어서, 이 줄이 없으면 세 플러그인
#    모두에 거짓 「kill switch 부재」 gap 이 난다. shared/tests/test_python_floor.sh 축 B 가 잰다.
_ks_trim() {   # 앞뒤 공백 제거 — 정본의 `.strip()` 자리
  _s="$1"
  _s="${_s#"${_s%%[![:space:]]*}"}"
  _s="${_s%"${_s##*[![:space:]]}"}"
  printf '%s' "$_s"
}

_ks_skip_has() {   # DEVBREW_SKIP_HOOKS 에 «전체 토큰» $1 이 있는가 (부분 일치 금지)
  [ -n "${DEVBREW_SKIP_HOOKS-}" ] || return 1
  _ifs_save="$IFS"; IFS=","
  for _tok in ${DEVBREW_SKIP_HOOKS}; do
    IFS="$_ifs_save"
    [ "$(_ks_trim "$_tok")" = "$1" ] && return 0
    IFS=","
  done
  IFS="$_ifs_save"
  return 1
}

kill_switch_active() {   # $1 plugin, $2 hook, $3 event(빈 값 가능)
  _up=""; _rest="$1"
  while [ -n "$_rest" ]; do
    _ch="${_rest%"${_rest#?}"}"; _rest="${_rest#?}"
    case "$_ch" in
      a) _ch=A;; b) _ch=B;; c) _ch=C;; d) _ch=D;; e) _ch=E;; f) _ch=F;; g) _ch=G;;
      h) _ch=H;; i) _ch=I;; j) _ch=J;; k) _ch=K;; l) _ch=L;; m) _ch=M;; n) _ch=N;;
      o) _ch=O;; p) _ch=P;; q) _ch=Q;; r) _ch=R;; s) _ch=S;; t) _ch=T;; u) _ch=U;;
      v) _ch=V;; w) _ch=W;; x) _ch=X;; y) _ch=Y;; z) _ch=Z;; -) _ch=_;;
      [A-Z0-9_]) ;;
      *) _ch="" ;;   # eval 에 들어갈 «이름» 이므로 그 밖의 글자는 버린다
    esac
    _up="$_up$_ch"
  done
  eval "_dis=\${DEVBREW_${_up}_DISABLE-}"
  [ "$_dis" = "1" ] && return 0
  # 별칭 둘: 훅명 **또는** 이벤트명. 빈 이벤트는 별칭을 만들지 않는다(정본과 같다 —
  # `<plugin>:` 꼴의 문서화되지 않은 와일드카드가 생기지 않게).
  _ks_skip_has "$1:$2" && return 0
  [ -n "$3" ] && _ks_skip_has "$1:$3" && return 0
  return 1
}

if kill_switch_active "$PLUGIN" "$HOOK" "$EVENT"; then
  exit 0
fi

# ── 버전 판정 — 이름이나 실행 권한이 아니라 «물어본 답» 이 근거다 ──────────────
PROBE_MAJOR=0; PROBE_MINOR=0
probe() {   # $1 = 인터프리터. rc 0 이면 PROBE_MAJOR/PROBE_MINOR 가 채워진다
  _out="$("$1" -c 'import sys;print("%d %d"%(sys.version_info[0],sys.version_info[1]))' 2>/dev/null)" || return 1
  case "$_out" in
    [0-9]*' '[0-9]*) ;;
    *) return 1 ;;
  esac
  PROBE_MAJOR="${_out%% *}"; PROBE_MINOR="${_out##* }"
  return 0
}

BEST_MAJOR=0; BEST_MINOR=-1     # 안내에 실을 「발견된 최고 버전」
note_best() {
  if [ "$PROBE_MAJOR" -gt "$BEST_MAJOR" ] ||
     { [ "$PROBE_MAJOR" -eq "$BEST_MAJOR" ] && [ "$PROBE_MINOR" -gt "$BEST_MINOR" ]; }; then
    BEST_MAJOR="$PROBE_MAJOR"; BEST_MINOR="$PROBE_MINOR"
  fi
}

satisfies() {
  [ "$PROBE_MAJOR" -gt "$FLOOR_MAJOR" ] && return 0
  [ "$PROBE_MAJOR" -eq "$FLOOR_MAJOR" ] && [ "$PROBE_MINOR" -ge "$FLOOR_MINOR" ] && return 0
  return 1
}

# ── 1. $DEVBREW_PYTHON (탈출구) ─────────────────────────────────────────────
IGNORED=""
if [ -n "${DEVBREW_PYTHON-}" ]; then
  if probe "$DEVBREW_PYTHON"; then
    note_best
    if satisfies; then exec "$DEVBREW_PYTHON" "$@"; fi
    IGNORED="$DEVBREW_PYTHON (Python ${PROBE_MAJOR}.${PROBE_MINOR} < ${FLOOR_MAJOR}.${FLOOR_MINOR})"
  else
    IGNORED="$DEVBREW_PYTHON (실행할 수 없거나 버전을 물을 수 없다)"
  fi
  # stdout 에 쓰지 않는다 (C7) — 이 사실은 환경으로 넘기고 SessionStart 안내가 싣는다.
  DEVBREW_PYTHON_IGNORED="$IGNORED"; export DEVBREW_PYTHON_IGNORED
fi

# ── 2. python3 — 흔한 경우, spawn 1회로 끝난다 ──────────────────────────────
if probe python3; then
  note_best
  if satisfies; then exec python3 "$@"; fi
fi

# ── 3. PATH 글롭 — 마이너 버전을 열거하지 않는다 (C4) ───────────────────────
FOUND=""
scan_path() {   # 함수 안이라 `set --` 가 **이 함수의** 위치인자만 건드린다 — 훅의 argv 는 그대로다
  _ifs_save="$IFS"
  IFS=":"; set -f
  set -- ${PATH-}
  set +f; IFS="$_ifs_save"
  for _dir in "$@"; do
    [ -n "$_dir" ] || _dir="."
    for _cand in "$_dir"/python3.*; do
      [ -f "$_cand" ] || continue
      [ -x "$_cand" ] || continue
      case "$_cand" in *-config) continue ;; esac
      probe "$_cand" || continue
      note_best
      if satisfies; then FOUND="$_cand"; return 0; fi
    done
  done
  return 1
}
scan_path

if [ -n "$FOUND" ]; then
  exec "$FOUND" "$@"
fi

# ── 4. 아무것도 없다 — fail-open (C3). 안내는 SessionStart 에서만 (D26) ─────
# 여기서만 stdout 에 쓴다. exec 하는 경로(1·2·3)의 stdout 은 비어 있다.
# 메시지에 `"` 와 `\` 를 넣지 않는다 — 아래 printf 가 JSON 을 손으로 조립한다.
if [ "$EVENT" = "SessionStart" ]; then
  if [ "$BEST_MINOR" -ge 0 ]; then
    _seen="발견된 최고 버전 Python ${BEST_MAJOR}.${BEST_MINOR}"
  else
    _seen="PATH 에서 Python 을 찾지 못했다"
  fi
  _extra=""
  [ -n "$IGNORED" ] && _extra=" \$DEVBREW_PYTHON 은 무시했다: ${IGNORED}."
  _msg="[devbrew] 이 세션에서 devbrew 훅이 비활성이다 — ${_seen}, 요구 바닥은 Python ${FLOOR_MAJOR}.${FLOOR_MINOR}+ 다.${_extra} 고치는 법: Python ${FLOOR_MAJOR}.${FLOOR_MINOR} 이상을 설치해 PATH 에 두거나(uv python install ${FLOOR_MAJOR}.${FLOOR_MINOR}), 이미 있다면 \$DEVBREW_PYTHON 에 그 경로를 지정하라."
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$_msg" "$_msg"
fi
exit 0
````

- [ ] **Step 5: 세 셸에서 문법과 동작을 확인한다**

```bash
for s in /bin/sh /bin/dash /bin/ksh; do
  [ -x "$s" ] || continue
  "$s" -n shared/python/devbrew-python.sh && echo "syntax OK: $s"
done
bash shared/tests/test_python_floor.sh
```
Expected: 세 셸 모두 `syntax OK`. 테스트는 축 A 전부 `✓`, `Fail: 0`.
`/bin/dash`·`/bin/ksh` 가 없는 머신이면 그 줄은 건너뛴다 — **없다는 사실을 보고하라**. macOS `/bin/sh` 는 bash 3.2 라 그것만으로는 POSIX 주장이 아니다.

- [ ] **Step 6: 변이로 이빨을 확인한다**

아래 일곱을 **하나씩** 넣고 매번 `bash shared/tests/test_python_floor.sh` 를 돌린다. 각각 RED 를 확인한 뒤 `git checkout HEAD -- shared/python/devbrew-python.sh` 로 되돌린다(`git checkout --` 은 index 로 되돌아가므로 `HEAD` 를 명시한다). **먼저 Step 7 의 커밋을 하고 변이를 돌려라** — 커밋 전에는 되돌릴 기준이 없다.

표의 「죽는 단언」은 **2026-09-22 에 실제로 변이를 넣어 확인한 값**이다. 어느 단언이 어느 스위치 «분기» 를 타는지가 결과를 정하므로, 그 분기를 함께 적는다 — 이것을 틀리게 적으면 다음 사람이 애초에 움직일 리 없는 단언을 보며 「이빨이 있다」고 결론 내린다.

| 스위치 | 그 단언이 타는 분기 |
|---|---|
| A1 | `DEVBREW_QUALITY_GATES_DISABLE=1` → **`_up` 도출 + `eval`** · PATH 에 만족 인터프리터 **있음** |
| A2 · A3 · A4a | `DEVBREW_SKIP_HOOKS` → **`_ks_skip_has`** (`_up` 을 타지 않는다) |
| A4a | 그중 PATH 가 **완전히 비어** 해석이 반드시 실패하는 자리 |

| # | 변이 | 죽는 단언 (실측) |
|---|---|---|
| M1 | `if kill_switch_active …` 블록을 **`scan_path` 호출 바로 뒤**(`if [ -n "$FOUND" ]` 앞)로 옮긴다 | **A1** — PATH_FLOOR 는 해석에 «성공» 하므로 검사가 그 뒤면 아예 도달하지 못하고 훅이 돈다. **A4a 는 죽지 않는다**: 빈 PATH 라 해석이 실패해 끝까지 내려오고 거기서 검사가 걸린다 |
| M2 | `_ks_skip_has` 의 `[ "$(_ks_trim "$_tok")" = "$1" ]` 를 `case "$_tok" in *"$1"*)` 부분 일치로 바꾼다 | **A3 둘째 케이스** — 부분 일치 버그는 「설정 토큰이 검사값을 **포함**」 방향에서 문다(`…advisor:frontmatter-scan` ⊃ `…advisor`). **A2 는 GREEN 으로 남는다**: 그 비활성 케이스의 설정 토큰이 더 «짧아» 그 방향에 걸리지 않는다 |
| M3 | `[ -n "$3" ] && _ks_skip_has "$1:$3"` 줄을 지운다 | **A3 첫째 케이스**(이벤트 별칭으로 못 끈다) **그리고 A4a**(끄지 못해 SessionStart 안내가 찍힌다) |
| M4 | 변수명 도출의 `case` 블록을 `_up="$(printf '%s' "$1" \| tr 'a-z-' 'A-Z_')"` 로 되돌린다 | **A1 만** — 이 머신의 `tr` 은 `/usr/bin/tr` 이고 fixture PATH 에는 `/bin` 만 있어 `_up` 이 비고 변수명이 어긋난다. **A4a 는 무관**하다: `DEVBREW_SKIP_HOOKS` 경로라 `_up` 을 아예 타지 않는다 |
| M5 | `scan_path` 의 글롭 `"$_dir"/python3.*` 를 열거 `"$_dir"/python3.12 "$_dir"/python3.13 "$_dir"/python3.14` 로 바꾼다 | **A5**(python3.99 를 못 찾는다) · A4b 도 함께 |
| M6 | `if [ "$EVENT" = "SessionStart" ]; then` 을 지워 모든 이벤트에서 안내를 찍게 한다 | **A8**(SessionEnd·PostToolUse stdout 이 안 비었다) |
| M7 | 머리의 `예: spec-distill -> DEVBREW_SPEC_DISTILL_DISABLE=1` 줄을 지운다 | **A11** |

**M1 은 놓을 자리를 위 표대로 정확히 잡는다.** 「`scan_path` 뒤 어딘가」로 두면 일부 위치에서 `Fail: 0` 이 난다 — 변이가 애매하면 이빨이 없다는 결론과 변이가 빗나갔다는 사실을 구별할 수 없다. 되돌림은 `git diff HEAD --stat` 으로 매번 확인한다(블록 이동은 눈으로 놓치기 쉽다).
**어떤 변이가 통과해 버리면 그 축이 아무것도 재고 있지 않다는 뜻이다** — 계측기를 먼저 의심하라(fixture 미생성 · `$PATH_BARE` 공백 · 변이가 다른 분기에 떨어짐).

- [ ] **Step 7: 커밋**

```bash
git add shared/python/devbrew-python.sh shared/tests/test_python_floor.sh
git commit -m "feat(shared): 출하 Python 바닥 해석기 — POSIX sh, 외부 명령 의존 0

kill switch 가 해석보다 먼저 서고(C2), 마이너 버전을 열거하지 않으며(C4),
python3 로 fallback 하지 않는다(C5). exec 경로의 stdout 은 비어 있다(C7).

tr 를 쓰면 PATH 에 /usr/bin 이 없을 때 kill switch 판정이 조용히 fail-open 한다
— 실측했다. 그래서 대문자 변환도 PATH 분리도 셸 내장으로만 한다.

dash · ksh · bash-as-sh 8케이스 실측 동치.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 물리 사본 배포와 `copy-of` 계약

**Files:**
- Create: `plugins/project-init/scripts/devbrew-python.sh`
- Create: `plugins/quality-gates/scripts/devbrew-python.sh`
- Create: `plugins/spec-distill/scripts/devbrew-python.sh`
- Modify: `shared/README.md` (`## 디렉토리` 표)
- Modify: `shared/tests/test_python_floor.sh` (축 B 추가)

**Interfaces:**
- Consumes: Task 1 의 `shared/python/devbrew-python.sh`.
- Produces: 설치본에서 `${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh` 로 도달 가능한 세 경로. Task 3 의 `hooks.json` 이 이 경로를 가리킨다.

- [ ] **Step 1: 축 B 를 먼저 쓴다 (실패하는 테스트)**

`shared/tests/test_python_floor.sh` 의 `finish` **앞**에 붙인다.

````bash
note "── 축 B: 배포 — 물리 사본 (AC11 · C9 · C10) ───────────────────────────"

COPY_PLUGINS="project-init quality-gates spec-distill"
n_copy=0
for p in $COPY_PLUGINS; do
  c="plugins/$p/scripts/devbrew-python.sh"
  n_copy=$((n_copy+1))
  if [ -L "$c" ]; then
    no "B/AC11: $c 가 심볼릭 링크다 — 감사기 containment 가 shared/ 로 풀려 거짓 gap 을 낸다"
  elif [ -f "$c" ]; then
    ok "B/AC11: $c 가 물리 파일이다"
  else
    no "B/AC11: $c 가 없다"
    continue
  fi
  # 마커는 머리 20줄 안(HEAD_WINDOW). 2번째 줄에 두는 것이 이 리포의 선례다
  # (shared/codex/runner_common.sh ↔ plugins/*/scripts/runner_common.sh).
  marker="$(head -20 "$c" | grep -nE '^[[:space:]]*#[[:space:]]*copy-of:[[:space:]]*shared/python/devbrew-python\.sh')"
  if [ -n "$marker" ]; then
    ok "B/C10: $c 의 copy-of 마커가 머리 20줄 안에 있다 (${marker%%:*}번째 줄)"
    lineno="${marker%%:*}"
    if sed "${lineno}d" "$c" | diff -q - "$ROOT/$RESOLVER" >/dev/null 2>&1; then
      ok "B/C10: $c ≡ 정본 (마커 줄 제외 바이트 동일)"
    else
      no "B/C10: $c 가 정본과 갈라졌다"
      sed "${lineno}d" "$c" | diff - "$ROOT/$RESOLVER" | head -10
    fi
  else
    no "B/C10: $c 에 copy-of 마커가 없다 — 위 바이트 비교에서 조용히 빠진다"
  fi
done
[ "$n_copy" -eq 3 ] && ok "B: 사본 자리 3건을 훑었다 (vacuous 아님)" || no "B: 사본 자리가 3이 아니다 ($n_copy)"

# plugin-audit 의 kill switch 판정이 **참** 인가 — A11 의 구체 예시 줄이 load-bearing 이다.
for p in $COPY_PLUGINS; do
  v="$(python3 plugins/plugin-audit/scripts/check-shape-completeness.py "plugins/$p" 2>/dev/null \
      | python3 -c 'import json,sys
try: d = json.load(sys.stdin)["shape_gaps"]
except Exception: print("unreadable"); raise SystemExit(0)
m = [g["present"] for g in d if g["requirement"] == "hooks_killswitch"]
print(m[0] if m else "absent")')"
  assert_eq "$v" "True" "B/AC11: plugin-audit 가 $p 의 hooks_killswitch 를 참으로 낸다"
done
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `plugins/*/scripts/devbrew-python.sh 가 없다` ×3.

- [ ] **Step 3: 사본 셋을 만든다**

```bash
for p in project-init quality-gates spec-distill; do
  {
    head -1 shared/python/devbrew-python.sh
    echo "# copy-of: shared/python/devbrew-python.sh"
    tail -n +2 shared/python/devbrew-python.sh
  } > "plugins/$p/scripts/devbrew-python.sh"
done
```

마커가 **2번째 줄**(shebang 바로 뒤)에 선다. `runner_common.sh` 쌍과 같은 배치이고, 이렇게 두면 C10 의 20줄 예산이 아예 문제가 되지 않는다 — 머리 주석을 아무리 길게 써도 마커는 2번째 줄에 있다. 설계의 `Deferred to plan` 7 은 이것으로 닫힌다.

실행 비트는 **주지 않는다**. `sh <경로>` 로 부르므로 필요 없고(C8), 없는 편이 「실행 비트가 설치 캐시까지 산다」는 미측정 가정을 설계에서 지운다.

- [ ] **Step 4: `shared/README.md` 의 `## 디렉토리` 표에 행을 더한다**

`| `killswitch/` | kill switch 판정 |` 줄 **다음**에 넣는다:

```markdown
| `python/` | 훅의 Python 인터프리터 해석기 — 출하 바닥(`FLOOR_*`)의 정본. 세 플러그인에 **물리 사본**으로 배포된다(심볼릭 링크는 `plugin-audit` 의 containment 검사를 깬다) |
```

- [ ] **Step 5: 돌려서 통과를 확인한다**

```bash
bash shared/tests/test_python_floor.sh
bash shared/tests/test_copy_of_contract.sh
bash shared/tests/test_no_new_duplication.sh
```
Expected: 셋 다 `Fail: 0`.
`test_copy_of_contract.sh` 는 축 1b 에서 새 사본 3건을 `후보 … 마커를 갖는다` + `≡ 정본` 으로 세야 한다. `test_no_new_duplication.sh` 는 20줄 이상 동일 블록 3벌을 `copy-of` 마커로 면제해야 한다 — **면제되지 않으면 마커 정규식이 그 락과 다른 것이니 마커 형식을 먼저 의심하라.**

- [ ] **Step 6: 변이로 이빨을 확인한다**

```bash
# 링크로 바꾸면 축 B 와 plugin-audit 둘 다 RED 여야 한다
rm plugins/spec-distill/scripts/devbrew-python.sh
ln -s ../../../shared/python/devbrew-python.sh plugins/spec-distill/scripts/devbrew-python.sh
bash shared/tests/test_python_floor.sh   # Expected: FAIL (심볼릭 링크다 + hooks_killswitch)
git checkout HEAD -- plugins/spec-distill/scripts/devbrew-python.sh 2>/dev/null || true
rm -f plugins/spec-distill/scripts/devbrew-python.sh
# 다시 만든다
{ head -1 shared/python/devbrew-python.sh; echo "# copy-of: shared/python/devbrew-python.sh"; tail -n +2 shared/python/devbrew-python.sh; } > plugins/spec-distill/scripts/devbrew-python.sh
```

**주의** — 이 시점에 사본은 아직 커밋되지 않았으므로 `git checkout HEAD --` 가 복원하지 못한다. 위 마지막 줄이 재생성이다. 변이 실험은 **커밋 뒤에** 하는 편이 안전하다(Step 7 뒤로 미뤄도 된다).

- [ ] **Step 7: 커밋**

```bash
git add shared/python/devbrew-python.sh shared/README.md shared/tests/test_python_floor.sh plugins/project-init/scripts/devbrew-python.sh plugins/quality-gates/scripts/devbrew-python.sh plugins/spec-distill/scripts/devbrew-python.sh
git commit -m "feat(shared): 해석기를 세 플러그인에 물리 사본으로 배포

심볼릭 링크면 plugin-audit 의 containment 가 .resolve() 로 shared/ 를 만나
세 플러그인 모두에 거짓 kill switch 부재 gap 을 낸다(C9·R13). 마커는 2번째 줄
— runner_common.sh 선례와 같고, 그러면 HEAD_WINDOW=20 예산이 문제가 되지 않는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `hooks.json` 4 자리 배선과 PATH 격리 시뮬레이션

**Files:**
- Modify: `plugins/project-init/hooks/hooks.json:10`
- Modify: `plugins/quality-gates/hooks/hooks.json:9`, `:19`
- Modify: `plugins/spec-distill/hooks/hooks.json:9`
- Modify: `shared/tests/test_python_floor.sh` (축 C 추가)

**Interfaces:**
- Consumes: Task 2 의 `${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh`.
- Produces: 4 자리의 `command` 문자열. **훅 `.py` 경로가 마지막 토큰**이라는 계약(`test_command_contract.py:125` 가 `.split()[-1]` 로 읽는다).

- [ ] **Step 1: 축 C 를 먼저 쓴다 (실패하는 테스트)**

`finish` 앞에 붙인다.

````bash
note "── 축 C: 배선 — hooks.json 4 자리 (AC1) ──────────────────────────────"

cmds_of() {   # hooks.json 하나의 command 문자열을 전부
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
out = []
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "command" and isinstance(v, str): out.append(v)
            else: walk(v)
    elif isinstance(o, list):
        for x in o: walk(x)
walk(d)
for c in out:
    print(c)
PY
}

n_cmd=0; n_bare=0
for hj in plugins/project-init/hooks/hooks.json \
          plugins/quality-gates/hooks/hooks.json \
          plugins/spec-distill/hooks/hooks.json; do
  # 명령 치환을 heredoc 본문에 **직접** 넣지 않는다 — 그 형태가 본문 내용에 따라 파싱이
  # 깨진 전례가 이 리포에 있다. 변수에 먼저 받는다(형제 락 test_copy_of_contract.sh 와 같은 꼴).
  hj_cmds="$(cmds_of "$hj")"
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    n_cmd=$((n_cmd+1))
    case "$cmd" in
      "python3 "*) n_bare=$((n_bare+1)); no "C/AC1: bare python3 로 시작하는 자리가 남아 있다: $hj — $cmd" ;;
      "sh \${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh "*)
        ok "C/AC1: $hj 의 자리가 sh <해석기> 를 경유한다" ;;
      *) no "C/AC1: $hj 의 command 가 기대 형태가 아니다: $cmd" ;;
    esac
    # 훅 .py 는 «마지막 토큰» 이어야 한다 — project-init 의 test_command_contract.py:125 가
    # `h["command"].split()[-1]` 로 훅 스크립트를 뽑는다. 순서를 바꾸면 그 락이 조용히
    # 엉뚱한 파일명을 본다.
    last="${cmd##* }"
    case "$last" in
      *.py) ok "C/AC1: 마지막 토큰이 훅 .py 다 ($last)" ;;
      *)    no "C/AC1: 마지막 토큰이 훅 .py 가 아니다 ($last) — test_command_contract.py 가 깨진다" ;;
    esac
    # --event / --plugin / --hook 셋이 다 있어야 kill switch 가 정본과 같은 판정을 한다
    for flag in --event --plugin --hook; do
      case "$cmd" in *"$flag "*) ;; *) no "C/AC1: $hj 의 자리에 $flag 가 없다" ;; esac
    done
  done <<EOF
$hj_cmds
EOF
done
assert_eq "$n_cmd" "4" "C/AC1: hooks.json 3 파일에서 호출 자리 4건을 셌다"
assert_eq "$n_bare" "0" "C/AC1: bare python3 로 시작하는 자리가 0 이다"

note "── 축 C2: PATH 격리 시뮬레이션 (AC12 · L3) ───────────────────────────"
# **먼저 이 PATH 의 python3 가 정말 바닥 미만인지 확인한다.** Apple 이 그것을 올리면
# 이 시뮬레이션은 «조용히 아무것도 재지 않게» 된다 — 그때는 통과가 아니라 RED 로 알린다.
# FLOOR_*_VAL 은 파일 머리에서 도출됐다(증인 포함).
iso_ver="$(PATH=/usr/bin:/bin python3 -c 'import sys;print("%d %d"%sys.version_info[:2])' 2>/dev/null || true)"
iso_ma="${iso_ver%% *}"; iso_mi="${iso_ver##* }"
iso_ok=0
if [ -z "$iso_ver" ]; then
  ok "C2/AC12: PATH=/usr/bin:/bin 에 python3 가 없다 — 해석 실패 경로를 그대로 잰다"; iso_ok=1
elif [ -z "${FLOOR_MAJOR_VAL:-}" ] || [ -z "${FLOOR_MINOR_VAL:-}" ]; then
  no "C2/AC12: 출하 바닥을 못 읽어 격리 PATH 의 유효성을 판정할 수 없다"
elif [ "$iso_ma" -gt "$FLOOR_MAJOR_VAL" ] || { [ "$iso_ma" -eq "$FLOOR_MAJOR_VAL" ] && [ "$iso_mi" -ge "$FLOOR_MINOR_VAL" ]; }; then
  no "C2/AC12: **이 시뮬레이션이 아무것도 재지 않는다** — PATH=/usr/bin:/bin 의 python3 가 ${iso_ma}.${iso_mi} 로 이미 바닥 이상이다. 격리 PATH 를 다시 골라라 (L3)"
else
  ok "C2/AC12: PATH=/usr/bin:/bin 의 python3 = ${iso_ma}.${iso_mi} < 바닥 (시뮬레이션이 유효하다)"; iso_ok=1
fi

if [ "$iso_ok" -eq 1 ]; then
  # 실제 훅 «넷» 을 그대로 쓴다 — AC12 가 말하는 것이 그것이다. 해석에 실패하면 해석기가
  # exec 하지 않으므로 훅 파이썬은 한 줄도 돌지 않는다.
  for spec in "SessionStart:quality-gates:session-start-advisor:plugins/quality-gates/hooks/session-start-advisor.py" \
              "SessionEnd:quality-gates:session-end-cleanup:plugins/quality-gates/hooks/session-end-cleanup.py" \
              "SessionEnd:spec-distill:session-end-cleanup:plugins/spec-distill/hooks/session-end-cleanup.py" \
              "PostToolUse:project-init:post-tool-use:plugins/project-init/hooks/post-tool-use.py"; do
    ev="${spec%%:*}"; r1="${spec#*:}"; pl="${r1%%:*}"; r2="${r1#*:}"; hk="${r2%%:*}"; tgt="${r2#*:}"
    out="$(printf '{"session_id":"00000000-0000-0000-0000-0000000000c2","cwd":"%s","tool_name":"Bash","tool_input":{"command":"true"}}' "$TMP" \
           | env PATH=/usr/bin:/bin /bin/sh "$R" \
             --event "$ev" --plugin "$pl" --hook "$hk" "$ROOT/$tgt" 2>/dev/null)"; rc=$?
    assert_eq "$rc" "0" "C2/AC12: $pl/$hk 가 rc 0 이다 (fail-open, 막지 않는다)"
    if [ "$ev" = "SessionStart" ]; then
      assert_grep "$out" 'additionalContext' "C2/AC12: SessionStart 는 안내 JSON 을 낸다"
    else
      assert_eq "$out" "" "C2/AC12: $ev($pl) 는 stdout 이 비어 있다"
    fi
    out_ks="$(printf '{"session_id":"x"}' \
           | env PATH=/usr/bin:/bin DEVBREW_SKIP_HOOKS="$pl:$ev" /bin/sh "$R" \
             --event "$ev" --plugin "$pl" --hook "$hk" "$ROOT/$tgt" 2>/dev/null)"
    assert_eq "$out_ks" "" "C2/AC12: kill switch 를 켜면 $pl/$ev 는 안내도 내지 않는다"
  done

  # 「본래 동작은 수행되지 않는다」 — 위 넷은 실패 경로에서 부작용이 없어 관측할 것이
  # 없으므로, **메커니즘** 을 카나리아로 직접 잰다: exec 이 없으면 대상 코드가 한 줄도 안 돈다.
  CANARY="$TMP/canary.sh"; CANARY_MARK="$TMP/canary.ran"
  printf '#!/bin/sh\ntouch "%s"\n' "$CANARY_MARK" > "$CANARY"; chmod +x "$CANARY"
  rm -f "$CANARY_MARK"
  printf '{}' | env PATH=/usr/bin:/bin /bin/sh "$R" \
    --event PostToolUse --plugin project-init --hook post-tool-use "$CANARY" >/dev/null 2>&1
  [ -f "$CANARY_MARK" ] \
    && no "C2/AC12: 해석에 실패했는데 대상이 실행됐다 — exec 하지 않는다는 계약이 깨졌다" \
    || ok "C2/AC12: 해석 실패 시 대상이 한 줄도 돌지 않는다 (본래 동작 미수행)"
fi
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `bare python3 로 시작하는 자리가 남아 있다` ×4, `n_bare` 가 4.

- [ ] **Step 3: `hooks.json` 4 자리를 고친다**

`plugins/project-init/hooks/hooks.json` — `"command"` 한 줄:
```diff
-            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py",
+            "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event PostToolUse --plugin project-init --hook post-tool-use ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py",
```

`plugins/quality-gates/hooks/hooks.json` — 두 줄:
```diff
-            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-start-advisor.py"
+            "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event SessionStart --plugin quality-gates --hook session-start-advisor ${CLAUDE_PLUGIN_ROOT}/hooks/session-start-advisor.py"
```
```diff
-            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
+            "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event SessionEnd --plugin quality-gates --hook session-end-cleanup ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
```

`plugins/spec-distill/hooks/hooks.json` — 한 줄:
```diff
-            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py",
+            "command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event SessionEnd --plugin spec-distill --hook session-end-cleanup ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py",
```

`--plugin`·`--hook` 값은 각 훅이 `kill_switch_active(...)` 에 실제로 넘기는 값과 **글자 그대로 같아야** 한다. 확인된 값: `project-init`/`post-tool-use` · `quality-gates`/`session-start-advisor` · `quality-gates`/`session-end-cleanup` · `spec-distill`/`session-end-cleanup`.

- [ ] **Step 4: 돌려서 통과를 확인하고, 결합된 락들도 함께 돌린다**

```bash
bash shared/tests/test_python_floor.sh
python3 -m unittest discover -s plugins/project-init/tests -t plugins/project-init/tests -p 'test_command_contract.py'
python3 -m unittest discover -s plugins/spec-distill/tests -t plugins/spec-distill/tests -p 'test_review_hook_removed.py'
bash plugins/project-init/tests/test_no_write_matcher_hooks.sh
bash plugins/quality-gates/tests/test_no_write_matcher_hooks.sh
bash plugins/spec-distill/tests/test_hooks.sh
bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh
python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_check_*.py'
```
Expected: 전부 통과. **`test_no_write_matcher_hooks_repo.sh` 는 선재 RED 다**(baseline §2 — 양성 대조가 Bash matcher ≥2 를 기대하는데 리포엔 1개) — 새로 깨진 것이 아닌지 확인만 하고 고치지 않는다.

- [ ] **Step 5: 설치본 모양으로 한 번 실행해 본다 (모의)**

```bash
tmp=$(mktemp -d); mkdir -p "$tmp/scripts" "$tmp/hooks"
cp plugins/spec-distill/scripts/devbrew-python.sh "$tmp/scripts/"
cp plugins/spec-distill/hooks/session-end-cleanup.py "$tmp/hooks/"
cp plugins/spec-distill/scripts/*.py "$tmp/scripts/" 2>/dev/null
printf '{"session_id":"00000000-0000-0000-0000-000000000000","cwd":"%s"}' "$PWD" \
  | sh "$tmp/scripts/devbrew-python.sh" --event SessionEnd --plugin spec-distill \
       --hook session-end-cleanup "$tmp/hooks/session-end-cleanup.py"; echo "rc=$?"
rm -rf "$tmp"
```
Expected: `rc=0`. 실행 비트 없이 `sh <경로>` 가 도는 것과, 형제 사본 import 가 `${CLAUDE_PLUGIN_ROOT}` 배치에서 풀리는 것을 함께 본다. **stdout 에 JSON 이 둘 찍히면 C7 위반이다.**

- [ ] **Step 6: 커밋**

```bash
git add plugins/project-init/hooks/hooks.json plugins/quality-gates/hooks/hooks.json plugins/spec-distill/hooks/hooks.json shared/tests/test_python_floor.sh
git commit -m "feat(hooks): 훅 4 자리가 sh <해석기> 를 경유한다

실행 비트가 설치 캐시까지 사는지 측정된 적이 없어 sh <경로> 로 부른다(C8·D10).
이름 셋은 인자로 넘어간다 — 해석기는 stdin 을 건드릴 수 없다(C6).
훅 .py 는 마지막 토큰이다 — test_command_contract.py:125 가 split()[-1] 로 읽는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 훅이 spawn 하는 `python3` 제거

**Files:**
- Modify: `plugins/spec-distill/scripts/hook_common.py:38-39`
- Modify: `shared/tests/test_python_floor.sh` (축 E 추가)

**Interfaces:**
- Consumes: 해석기가 `exec` 한 인터프리터가 `sys.executable` 로 보인다는 사실.

- [ ] **Step 1: 축 E 를 먼저 쓴다**

````bash
note "── 축 E: 훅 자식 (AC10) ──────────────────────────────────────────────"

# 코퍼스는 설계 Context/Why 4 의 도출을 그대로 쓴다 — 「훅·스크립트 .py 전수 grep」.
# **BRE 의 `\|` 를 쓰지 않는다** — GNU 확장이라 macOS/BSD grep 에서는 alternation 이 아니라
# 리터럴 `|` 로 읽혀 이 검사가 조용히 아무것도 안 찾는다. 따옴표 두 모양을 각각 훑는다.
child_spawns="$( { grep -rn '"python3"' plugins --include='*.py'
                   grep -rn "'python3'" plugins --include='*.py'; } 2>/dev/null \
  | grep -v '/tests/' || true)"
if [ -z "$child_spawns" ]; then
  ok "E/AC10: 훅·스크립트가 spawn 하는 python3 가 0 건이다"
else
  no "E/AC10: 훅·스크립트가 여전히 python3 를 spawn 한다"
  printf '%s\n' "$child_spawns" | head -5
fi
assert_file_grep plugins/spec-distill/scripts/hook_common.py 'sys\.executable' \
  "E/AC10: hook_common.py 가 sys.executable 을 쓴다 (양의 짝 — 위는 음의 락)"
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `여전히 python3 를 spawn 한다`, `hook_common.py:39` 가 찍힌다.

- [ ] **Step 3: `hook_common.py` 를 고친다**

```diff
         result = subprocess.run(
-            ["python3", str(GC_SCRIPT)],
+            # **`python3` 가 아니라 자기 자신이다.** 훅은 `devbrew-python.sh` 가 고른
+            # 인터프리터로 돌고 있는데, 자식을 PATH 의 `python3` 로 띄우면 그 자식만
+            # 바닥 미만으로 떨어진다 — 해석의 효력이 프로세스 경계에서 끊긴다.
+            [sys.executable, str(GC_SCRIPT)],
             timeout=5, check=False, capture_output=True, text=True,
         )
```

`sys` 는 이미 import 돼 있다(`hook_common.py:21`). 추가 import 없음.

- [ ] **Step 4: 돌려서 통과를 확인한다**

```bash
bash shared/tests/test_python_floor.sh
python3 -m unittest discover -s plugins/spec-distill/tests -t plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -5
```
Expected: 축 E `✓`. spec-distill 스위트는 **`Ran 157`, `failures=1`** 이어야 한다 — 그 하나는 baseline 의 선재 RED(`TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`, 워크트리에서 항상 실패)다. **실패한 테스트 «이름» 을 확인하라** — 수만 같고 이름이 다르면 새 회귀다.

- [ ] **Step 5: 실제로 자식이 같은 인터프리터로 뜨는지 본다**

```bash
python3.12 - <<'PY'
import subprocess, sys, pathlib
sys.path.insert(0, "plugins/spec-distill/scripts")
import hook_common
print("GC_SCRIPT:", hook_common.GC_SCRIPT.exists())
out = subprocess.run([sys.executable, "-c", "import sys;print(sys.version_info[:2])"],
                     capture_output=True, text=True)
print("child sees:", out.stdout.strip())
PY
```
Expected: `child sees: (3, 12)` — 부모가 3.12 면 자식도 3.12.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/hook_common.py shared/tests/test_python_floor.sh
git commit -m "fix(spec-distill): TTL-GC 자식을 sys.executable 로 띄운다

해석기가 고른 인터프리터의 효력이 프로세스 경계에서 끊기던 유일한 자리다
— 훅·스크립트 .py 전수 grep 에서 나온 1건(AC10).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `session-start-advisor.py` 의 `DEVBREW_PYTHON_IGNORED` 공시

**Files:**
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py`
- Modify: `shared/tests/test_python_floor.sh` (축 A 에 A12 추가)

**Interfaces:**
- Consumes: Task 1 의 `DEVBREW_PYTHON_IGNORED` 환경변수.
- **왜 여기가 따로 필요한가** — 해석기가 직접 안내를 내는 경로는 「아무 인터프리터도 못 찾았다」일 때뿐이고, 그때 이 훅은 **아예 돌지 않는다**. `$DEVBREW_PYTHON` 을 버리고 **다른 인터프리터로 exec 한** 경우는 그 반대다: 해석기는 침묵하고(C7) 훅이 돈다. 두 출구는 배타적이라 JSON 이 둘이 되지 않는다.

- [ ] **Step 1: 축 A12 를 먼저 쓴다**

`finish` 앞에 붙인다.

````bash
note "── 축 A12: 해석 성공 경로의 IGNORED 공시 (AC8 의 나머지 절반) ─────────"

ADVISOR="plugins/quality-gates/hooks/session-start-advisor.py"
adv_out="$(printf '{"session_id":"","cwd":"%s"}' "$TMP" \
  | env DEVBREW_PYTHON_IGNORED='/usr/bin/python3 (Python 3.9 < 3.12)' python3 "$ADVISOR" 2>/dev/null)"
adv_report="$(printf '%s' "$adv_out" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("emitted: no"); raise SystemExit(0)
try:
    d = json.loads(raw)
except ValueError as e:
    print("emitted: broken (%s)" % e); raise SystemExit(0)
print("emitted: yes")
print("both_keys: %s" % ("yes" if d.get("systemMessage") and
      d.get("hookSpecificOutput", {}).get("additionalContext") else "no"))
print("carries_reason: %s" % ("yes" if "3.9" in json.dumps(d) else "no"))
')"
assert_eq "$(field emitted "$adv_report")" "yes" "A12/AC8: IGNORED 가 있으면 advisor 가 JSON 을 낸다"
assert_eq "$(field both_keys "$adv_report")" "yes" "A12/AC8: 두 키를 함께 담는다"
assert_eq "$(field carries_reason "$adv_report")" "yes" "A12/AC8: 사유를 그대로 싣는다"

# 음의 짝 — 평소에는 stdout 이 비어야 한다 (이 훅은 원래 stdout 을 쓰지 않는다)
adv_quiet="$(printf '{"session_id":"","cwd":"%s"}' "$TMP" | env -u DEVBREW_PYTHON_IGNORED python3 "$ADVISOR" 2>/dev/null)"
assert_eq "$adv_quiet" "" "A12/AC8: IGNORED 가 없으면 advisor 의 stdout 은 비어 있다"

# kill switch 가 이 자리도 지배한다
adv_ks="$(printf '{"session_id":"","cwd":"%s"}' "$TMP" \
  | env DEVBREW_PYTHON_IGNORED=x DEVBREW_SKIP_HOOKS=quality-gates:SessionStart python3 "$ADVISOR" 2>/dev/null)"
assert_eq "$adv_ks" "" "A12/AC8: kill switch 가 켜지면 이 공시도 나가지 않는다"
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `emitted: no` (지금은 stdout 에 아무것도 안 쓴다).

- [ ] **Step 3: advisor 를 고친다**

`_self_session_id` 정의 **앞**에 함수를 넣는다:

```python
def _emit_python_ignored_notice() -> None:
    """해석기가 `$DEVBREW_PYTHON` 을 버렸다는 사실을 모델·사람 양쪽에 알린다.

    이 자리가 사는 경우는 하나다 — 해석기가 **다른** 인터프리터로 exec 했을 때.
    해석이 통째로 실패하면 이 훅은 아예 돌지 않고 해석기가 직접 안내를 낸다
    (`shared/python/devbrew-python.sh` 4단계). 두 출구는 배타적이라 stdout 에
    JSON 문서가 둘이 되지 않는다.

    `ensure_ascii` 를 끄지 않는다 — 비-UTF-8 locale 에서 print 가
    UnicodeEncodeError 로 죽으면 조언 훅이 세션 시작을 시끄럽게 만든다.
    \\uXXXX 이스케이프는 같은 JSON 이다.
    """
    reason = os.environ.get("DEVBREW_PYTHON_IGNORED", "")
    if not reason:
        return
    msg = (
        f"[devbrew] $DEVBREW_PYTHON 을 쓰지 않았다: {reason}. "
        "이 세션의 훅은 PATH 에서 찾은 다른 인터프리터로 돌고 있다."
    )
    print(json.dumps({
        "systemMessage": msg,
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": msg,
        },
    }))
```

`main()` 을 고친다:

```diff
 def main() -> int:
     if kill_switch_active("quality-gates", "session-start-advisor", "SessionStart"):
         return 0
     payload = _load_payload()
     self_sid = _self_session_id(payload)
     _emit_legacy_v1_advisory(payload, self_sid)
     _scan_agent_frontmatter_keys(payload)
+    # stdout 을 쓰는 **유일한** 자리다. 위 둘은 전부 stderr 로 나간다 —
+    # 여기에 두 번째 print 를 더하면 훅의 stdout 이 JSON 문서 둘이 된다(C7).
+    _emit_python_ignored_notice()
     return 0
```

모듈 머리 docstring 의 `v1.32.0 behaviors:` 목록에 한 줄을 더한다:

```diff
 - frontmatter-scan sub-feature: warn about the dead `allowedTools` key and
   wrong-layer kebab keys in plugins/*/agents/*.md (v2.11.0: the advice used
   to point at camelCase `allowedTools`, which is not a real subagent field).
+- `$DEVBREW_PYTHON` was ignored by the interpreter resolver (env
+  `DEVBREW_PYTHON_IGNORED`) -> one stdout JSON doc carrying both
+  `systemMessage` and `additionalContext`. This is the only stdout writer
+  in this hook; everything else goes to stderr.
```

- [ ] **Step 4: 돌려서 통과를 확인한다**

```bash
bash shared/tests/test_python_floor.sh
bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh
```
Expected: 둘 다 `Fail: 0`. 기존 advisor 스위트는 `DEVBREW_PYTHON_IGNORED` 를 설정하지 않으므로 stdout 이 그대로 비어 있다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/hooks/session-start-advisor.py shared/tests/test_python_floor.sh
git commit -m "feat(quality-gates): \$DEVBREW_PYTHON 무시 사실을 SessionStart 에서 공시한다

해석기가 다른 인터프리터로 exec 한 경우 해석기 자신은 침묵해야 하므로(C7),
그 사실을 아는 유일한 자리가 이 훅이다. 해석이 통째로 실패한 경우는 이 훅이
아예 안 돌고 해석기가 직접 안내를 낸다 — 두 출구는 배타적이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: uv 층 — `pyproject.toml` · `.python-version` · `uv.lock`

**Files:**
- Create: `pyproject.toml`
- Create: `.python-version`
- Create: `uv.lock` (생성물, 커밋)
- Modify: `shared/tests/test_python_floor.sh` (축 D·H 추가)

**Interfaces:**
- Produces: `requires-python` — **개발** 바닥의 정본. 축 D 가 해석기의 `FLOOR_*` 와 **각각 읽어** 비교한다.
- Produces: `[dependency-groups] dev` — 테스트 의존성. 지금은 PyYAML 하나.

- [ ] **Step 1: 축 D·H 를 먼저 쓴다**

````bash
note "── 축 D: 두 바닥의 분리 (AC9) ────────────────────────────────────────"
# **두 자리를 각각 읽는다.** 한 자리에서 읽어 다른 자리에 쓰면, 갈라지는 날 조용히
# 거짓이 된다(설계 §4). 그리고 도출값이 비어 있으면 아래 비교가 전부 헛돈다 —
# 보간 실패를 먼저 증인으로 잡는다.
DEV_MINOR="$(sed -n 's/^requires-python = ">=3\.\([0-9][0-9]*\)"$/\1/p' pyproject.toml 2>/dev/null | head -1)"
PV_MINOR="$(sed -n 's/^3\.\([0-9][0-9]*\)$/\1/p' .python-version 2>/dev/null | head -1)"
case "${DEV_MINOR:-x}" in *[!0-9]*|'') no "D/AC9: pyproject.toml 에서 개발 바닥을 못 읽었다" ;;
  *) ok "D/AC9: 개발 바닥 3.${DEV_MINOR} 를 pyproject.toml 에서 도출했다 (증인)" ;; esac
case "${PV_MINOR:-x}" in *[!0-9]*|'') no "D/AC9: .python-version 을 못 읽었다" ;;
  *) ok "D/AC9: .python-version = 3.${PV_MINOR} (증인)" ;; esac
assert_eq "$FLOOR_MAJOR_VAL" "3" "D/AC9: 출하 바닥의 major 가 3 이다 (아래 minor-only 비교의 전제)"
assert_eq "${PV_MINOR:-}" "${DEV_MINOR:-}" "D/AC9: .python-version 이 개발 바닥과 같은 minor 를 가리킨다"
if [ -n "${DEV_MINOR:-}" ] && [ -n "${FLOOR_MINOR_VAL:-}" ] && [ "$DEV_MINOR" -ge "$FLOOR_MINOR_VAL" ]; then
  ok "D/AC9: 개발 바닥 3.$DEV_MINOR >= 출하 바닥 ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL}"
else
  no "D/AC9: 개발 바닥이 출하 바닥보다 낮다 — uv 가 출하 바닥을 못 재게 된다"
fi

note "── 축 H: uv.lock 핀 (AC16) ───────────────────────────────────────────"
if [ -f uv.lock ]; then
  ok "H/AC16: uv.lock 이 추적된다"
  pin="$(awk '/^name = "pyyaml"$/{f=1;next} f&&/^version = /{print;exit}' uv.lock)"
  assert_grep "${pin:-}" '^version = "[0-9]+\.[0-9]+' "H/AC16: uv.lock 이 PyYAML 을 정확한 버전으로 고정한다 ($pin)"
  assert_file_grep uv.lock "^requires-python = \">=3\.${DEV_MINOR:-x}\"" \
    "H/AC16: uv.lock 의 requires-python 이 pyproject.toml 과 같다"
else
  no "H/AC16: uv.lock 이 없다"
fi
assert_file_grep pyproject.toml '^package = false$' \
  "H: [tool.uv] package = false — devbrew 는 빌드되는 패키지가 아니다"
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — `pyproject.toml 에서 개발 바닥을 못 읽었다`, `uv.lock 이 없다`.

- [ ] **Step 3: `pyproject.toml` 을 만든다**

```toml
# devbrew 는 배포되는 패키지가 아니다 — 이 파일이 고정하는 것은 **개발·검증 환경** 뿐이다.
# `package = false` 가 uv 에게 빌드하지 말라고 말한다(uv.lock 에 source = { virtual = "." }).
#
# 출하 요구사항은 여전히 Python 하나다. uv 는 여기(리포)에서만 쓴다 — 사용자에게 요구하는
# 것을 늘리지 않는다(Non-goal 6).
[project]
name = "devbrew"
version = "0"
# **개발** 바닥. 출하 바닥의 정본은 `shared/python/devbrew-python.sh` 의 FLOOR_* 다.
# 지금 두 숫자는 같지만 **같은 사실이 아니다** — 한 자리에 적으면 갈라지는 날 조용히
# 거짓이 된다(설계 §4). 집행자도 다르다: 이쪽은 uv, 저쪽은 훅의 해석기.
requires-python = ">=3.12"

[dependency-groups]
dev = ["pyyaml"]

[tool.uv]
package = false
```

- [ ] **Step 4: `.python-version` 을 만든다**

```bash
printf '3.12\n' > .python-version
```

없으면 uv 가 **조용히 가장 새 버전을 고른다**(실측: 3.14.3). 이 파일은 **개발** 바닥을 따라간다(D14).

- [ ] **Step 5: 락을 만든다**

```bash
uv lock
```
Expected: `Resolved 2 packages`. **네트워크가 필요하다** — 실패하면 그 사실을 보고하고 멈춘다(락을 손으로 쓰지 않는다).

생성 확인:
```bash
grep -n 'requires-python\|name = "pyyaml"' uv.lock | head
git status --porcelain --ignored -- uv.lock .python-version .venv
```
Expected: `uv.lock`·`.python-version` 은 `??`(추적 예정), `.venv` 는 `!!`(무시됨). **`.gitignore` 를 편집하지 않는다** — `uv.lock`(:104)·`.python-version`(:91) 규칙은 이미 주석 처리돼 있고 `.venv`(:143) 는 무시된다.

- [ ] **Step 6: 두 줄이 실제로 도는지 확인한다**

```bash
uv run -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_check_shape_completeness.py' 2>&1 | tail -4
uv run --python 3.14 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_check_shape_completeness.py' 2>&1 | tail -4
uv run --python 3.9 python -c 'print(1)' 2>&1 | tail -2
```
Expected: 앞 둘은 `OK`. 셋째는 **거부**여야 한다 —
`error: The requested interpreter resolved to Python 3.9.6, which is incompatible with the project's Python requirement: >=3.12`.
거부가 안 나면 `requires-python` 이 안 읽히고 있는 것이다.

**알아둘 것** — `--python` 을 바꿔 가며 부르면 uv 가 `.venv` 를 매번 다시 만든다(실측). 정상이고 느릴 뿐이다.

- [ ] **Step 7: 돌려서 통과를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: 축 D·H `✓`.

- [ ] **Step 8: 변이로 이빨을 확인한다**

```bash
# (a) .python-version 을 지우면 uv 가 천장을 고르고 축 D 가 RED 다
mv .python-version .python-version.away
bash shared/tests/test_python_floor.sh | grep -E 'D/AC9'   # RED 기대
mv .python-version.away .python-version

# (b) 출하 바닥만 올리면 개발 바닥 < 출하 바닥이 되어 RED 다
sed -i.away 's/^FLOOR_MINOR=12$/FLOOR_MINOR=13/' shared/python/devbrew-python.sh
bash shared/tests/test_python_floor.sh | grep -E 'D/AC9'   # RED 기대
mv shared/python/devbrew-python.sh.away shared/python/devbrew-python.sh
```

**주의** — `FLOOR_MINOR` 를 되돌린 뒤 `plugins/*/scripts/devbrew-python.sh` 사본 셋이 정본과 다시 같은지 `bash shared/tests/test_copy_of_contract.sh` 로 확인한다. 정본만 되돌리고 사본을 잊으면 copy-of 계약이 깨진다(C10 — 정본과 사본은 같은 커밋에서 고친다).

- [ ] **Step 9: 커밋**

```bash
git add pyproject.toml .python-version uv.lock shared/tests/test_python_floor.sh
git commit -m "feat: uv 로 개발·검증 환경을 고정한다

requires-python 은 **개발** 바닥이다 — 출하 바닥의 정본은 해석기의 FLOOR_* 이고
둘은 같은 숫자지만 같은 사실이 아니다(설계 §4). .python-version 이 없으면 uv 가
조용히 가장 새 버전을 고른다(실측 3.14.3).

uv run --python 3.9 가 requires-python 위반으로 거부됨을 실측했다.
러너 스크립트도 매트릭스 하네스도 만들지 않는다 — uv 가 없으면 기존
python3 -m unittest 로 degrade 한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: 도출 규칙과 prerequisite 를 산출물에 적는다

**Files:**
- Modify: `README.md` (루트)
- Modify: `plugins/project-init/README.md` (`## 통합` 앞에 새 `## Prerequisites`)
- Modify: `plugins/quality-gates/README.md` (기존 Prerequisites 단락 앞)
- Modify: `plugins/spec-distill/README.md:197` `## Prerequisites` 의 첫 항목으로
- Modify: `shared/tests/test_python_floor.sh` (축 F·G 추가)

**Interfaces:**
- Produces: 다섯 산출물에 공통으로 박히는 **도출 규칙 문장** — `2026-10 이후에도 패치를 받는 버전 중 최빈`. 축 F 가 이 문장을 **리터럴로** 고정하고, 버전 숫자는 해석기에서 **재도출**해 비교한다(숫자를 락에 핀하면 bump 규칙과 충돌한다).

- [ ] **Step 1: 축 F·G 를 먼저 쓴다**

````bash
note "── 축 F: 도출 규칙이 산출물에 적혀 있다 (AC13) ───────────────────────"
RULE='2026-10 이후에도 패치를 받는 버전 중 최빈'
for f in "$RESOLVER" README.md \
         plugins/project-init/README.md plugins/quality-gates/README.md plugins/spec-distill/README.md; do
  assert_file_grep "$f" "$RULE" "F/AC13: $f 가 도출 규칙을 담는다"
  # 버전 숫자는 **재도출**해서 본다 — 리터럴로 핀하면 바닥이 움직일 때 stale-red 가 된다.
  assert_file_grep "$f" "${FLOOR_MAJOR_VAL}\.${FLOOR_MINOR_VAL}" \
    "F/AC13: $f 가 현재 바닥 ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL} 를 말한다"
  assert_file_grep "$f" "EOL" "F/AC13: $f 가 다음 재검토 시점(EOL)을 말한다"
done

note "── 축 G: prerequisite (AC14) ─────────────────────────────────────────"
PREREQ="Python ${FLOOR_MAJOR_VAL}.${FLOOR_MINOR_VAL}+"
for p in project-init quality-gates spec-distill; do
  assert_file_grep "plugins/$p/README.md" "$PREREQ" "G/AC14: $p README 에 '$PREREQ' prerequisite 가 있다"
done
# 음의 짝 — plugin-audit 에는 **쓰지 않는다**. 훅이 없고 셸 13자리는 범위 밖이라
# 그 바닥을 집행하는 주체가 없다(D27 — R8 이 기각한 「집행 없는 선언」이 그대로 돌아온다).
assert_file_absent plugins/plugin-audit/README.md "$PREREQ" \
  "G/AC14: plugin-audit README 에는 그 prerequisite 를 쓰지 않는다 (집행 주체가 없다)"
````

- [ ] **Step 2: 돌려서 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh`
Expected: FAIL — README 넷에서 `도출 규칙을 담는다` 실패. **해석기는 통과해야 한다**(Task 1 에서 이미 적었다) — 해석기까지 실패하면 머리 주석이 유실된 것이다.

- [ ] **Step 3: 루트 `README.md` 에 `## Python` 절을 더한다**

`## 구조` 절 **앞**에 넣는다:

```markdown
## Python

devbrew의 **훅**은 Python 3.12 이상을 요구합니다. 이 숫자는 리터럴이 아니라 도출된 값입니다 —
「2026-10 이후에도 패치를 받는 버전 중 최빈」. 다음 재검토 시점은 3.12 EOL(2028-10)이고,
올릴 때는 숫자를 손으로 바꾸는 게 아니라 이 규칙을 다시 적용합니다. 정본은
`shared/python/devbrew-python.sh`의 `FLOOR_MAJOR`/`FLOOR_MINOR`.

바닥 미만 머신에서 훅은 **막지 않고 건너뜁니다**. 대신 세션 시작에 안내가 한 번 나가고,
`$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다. 스킬·커맨드가 Bash로 부르는
자리는 이 해석의 범위 밖이라 여전히 사용자의 `python3`를 집습니다.

개발·검증은 uv로 재현합니다. 개발 바닥은 `pyproject.toml`의 `requires-python`이며,
출하 바닥과 **같은 숫자지만 같은 사실이 아닙니다** — 집행자가 다릅니다(uv vs 훅의 해석기).

```
uv run -m unittest <module>                    # 개발 바닥 (.python-version)
uv run --python 3.14 -m unittest <module>      # 천장
```

uv가 없으면 기존 `python3 -m unittest`로 degrade합니다 — uv는 출하 요구사항이 아닙니다.
```

- [ ] **Step 4: 세 플러그인 README 에 같은 문단을 넣는다**

세 파일에 **글자 그대로 같은** 블록을 넣는다(축 F·G 가 같은 문자열로 셋을 본다):

```markdown
- **Python 3.12+** — 이 플러그인의 훅이 요구하는 바닥입니다. 숫자는 도출된 값입니다 —
  「2026-10 이후에도 패치를 받는 버전 중 최빈」, 다음 재검토는 3.12 EOL(2028-10).
  바닥 미만이면 훅은 **막지 않고** 건너뛰며 세션 시작에 안내가 한 번 나갑니다.
  `$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다.
```

자리는 셋이 각각 다르다:

- `plugins/spec-distill/README.md` — `## Prerequisites`(:197) 헤딩 바로 아래, **superpowers 항목 앞**에 넣는다(요구가 optional 보다 먼저 온다).
- `plugins/quality-gates/README.md` — `**Prerequisites (Tier C optional dependencies):**` 로 시작하는 단락 **앞**에 빈 줄 하나를 두고 단독 bullet 으로 넣는다. 그 단락은 optional 의존성을 말하므로 **합치지 않는다** — 하나는 요구이고 하나는 선택이다.
- `plugins/project-init/README.md` — `## 통합`(:73) **앞**에 절을 새로 만든다:

  ```markdown
  ## Prerequisites

  - **Python 3.12+** — 이 플러그인의 훅이 요구하는 바닥입니다. 숫자는 도출된 값입니다 —
    「2026-10 이후에도 패치를 받는 버전 중 최빈」, 다음 재검토는 3.12 EOL(2028-10).
    바닥 미만이면 훅은 **막지 않고** 건너뛰며 세션 시작에 안내가 한 번 나갑니다.
    `$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다.
  ```

**`plugins/plugin-audit/README.md` 는 건드리지 않는다** — 그 플러그인엔 훅이 없어 이 바닥을 집행하는 주체가 없다. 축 G 의 음의 짝이 그것을 잰다.

- [ ] **Step 5: 돌려서 통과를 확인한다**

```bash
bash shared/tests/test_python_floor.sh
bash plugins/spec-distill/tests/test_readme_sync.sh
bash plugins/spec-distill/tests/test_stale_terms.sh
grep -c 'Prerequisites' plugins/project-init/README.md
```
Expected: 넷 다 통과. `plugin-audit` 의 음의 짝도 `✓`(그 README 를 건드리지 않았으므로).
`test_readme_sync.sh` 는 spec-distill README 의 `## Principles Instantiated` 절과 plugin.json 버전 floor 를 본다 — 새 bullet 은 그 절 밖이고 버전은 아직 안 건드렸으므로 통과해야 한다. `test_stale_terms.sh` 는 `plugins/spec-distill/` 전체를 훑으므로 **Task 2 가 넣은 사본도 그 스윕에 든다** — 금지 토큰(`breadth-keeper`·`interview_round` 등)이 없어야 한다.

- [ ] **Step 6: 커밋**

```bash
git add README.md plugins/project-init/README.md plugins/quality-gates/README.md plugins/spec-distill/README.md shared/tests/test_python_floor.sh
git commit -m "docs: 바닥의 도출 규칙과 prerequisite 를 산출물에 적는다

숫자가 아니라 규칙을 적는다 — 「2026-10 이후에도 패치를 받는 버전 중 최빈」.
다음 상향이 임의적이지 않으려면 그 규칙이 다음 사람이 읽는 자리에 있어야 한다.

plugin-audit 에는 쓰지 않는다: 훅이 없고 셸 13자리는 범위 밖이라 그 바닥을
집행하는 주체가 없다(D27).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: 커버리지 락 동거와 baseline 전수 대조

**Files:**
- Test only: 실행과 대조. 결함이 나오면 해당 Task 의 파일을 고친다.

**Interfaces:**
- Consumes: Task 1~7 의 전부.

- [ ] **Step 1: 양방향 커버리지 검사 (AC15)**

```bash
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh
```
Expected: `Fail: 0`. 출력에 새 락에 대한 줄이 **양방향 모두** 있어야 한다:
- `guards: shared/tests/test_python_floor.sh — 읽은 경로가 전부 선언 안`
- `guards: shared/tests/test_python_floor.sh — 글롭 '<각 글롭>' 가 실제 N건을 덮는다` ×10

어느 글롭이 `아무것도 안 덮는다` 로 나오면 그 글롭을 지우거나 `--emit-scanned` 에 그 경로를 더한다. **「미지원」으로 넘어가면 `--emit-scanned` 가 빈 출력을 냈다는 뜻이다** — 그 분기는 조용히 통과하므로 출력 줄을 직접 확인하라.

- [ ] **Step 2: 전수 baseline 대조**

baseline 문서는 **원시 출력 파일이 아니라 요약과 러너**를 남겼다. 그러므로 「두 파일을 diff」하는 것이 아니라, **지금을 재서 문서에 적힌 집합과 대조**한다. 러너는 `docs/audits/2026-09-21-python-floor-baseline.md` §3 의 것이고, 아래는 그것을 이 워크트리에 맞춘 그대로다.

```bash
cat > "$HOME/pyfloor-runner.sh" <<'RUNNER'
#!/bin/bash
set -u
W="/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/python-floor-uv"
OUT="$1"; TMO=$(command -v timeout || command -v gtimeout); LIMIT="${2:-90}"
export PYTHONDONTWRITEBYTECODE=1
cd "$W" || exit 1
: > "$OUT"
printf '# after @ %s  %s\n' "$(git rev-parse --short HEAD)" "$(date -u +%FT%TZ)" >> "$OUT"
printf '# interpreter: %s\n' "$(python3 -V 2>&1)" >> "$OUT"
echo "## BASH" >> "$OUT"
git ls-files '*/tests/*.sh' | grep -vE '/(mocks|lib|harness|fixtures|spike)/' | sort | while IFS= read -r t; do
  o=$("$TMO" "$LIMIT" bash "$t" 2>&1); rc=$?
  n=$(printf '%s\n' "$o" | grep -ciE '^(not ok|FAIL|✗|ERROR)')
  echo "$rc $n $t" >> "$OUT"
done
echo "## PYTHON" >> "$OUT"
git ls-files '*/tests/test_*.py' | grep -vE '/(mocks|lib|harness|fixtures|spike)/' \
  | xargs -n1 dirname | sort -u | while IFS= read -r d; do
  o=$(cd "$W/$d" && "$TMO" "$LIMIT" python3 -m unittest discover -s . -t . -p 'test_*.py' 2>&1); rc=$?
  ran=$(printf '%s\n' "$o" | grep -oE 'Ran [0-9]+ test' | grep -oE '[0-9]+' | tail -1)
  fe=$(printf '%s\n' "$o" | grep -oE '(failures|errors)=[0-9]+' | tr '\n' ',')
  names=$(printf '%s\n' "$o" | grep -oE '^(FAIL|ERROR): [A-Za-z_.]+' | tr '\n' ' ')
  echo "$rc ran=${ran:-?} ${fe:-ok} $d :: $names" >> "$OUT"
done
RUNNER
bash "$HOME/pyfloor-runner.sh" "$HOME/pyfloor-after.txt" 90
```

`timeout` 은 coreutils 의 것이다(macOS 기본이 아니다). 없으면 그 사실을 보고하고 멈춘다 — 상한 없이 돌리면 `mock-codex-hang.sh` 계열에서 매달린다.

**대조 1 — RED 집합이 baseline 의 4건과 «정확히» 같은가:**

```bash
awk '/^## BASH/{s=1;next} /^## PYTHON/{s=2;next} s==1 && $1!=0 {print "BASH  " $0} s==2 && $1!=0 {print "PY    " $0}' \
  "$HOME/pyfloor-after.txt"
```
기대 — 정확히 넷, 그리고 각각 baseline §2 에 적힌 이유를 가진 그것들이어야 한다:

| 자리 | baseline 이 적은 값 |
|---|---|
| `plugins/spec-distill/tests` | `ran=157`, `failures=1`, 이름 `TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree` |
| `plugins/quality-gates/tests/test_runner_adapters.sh` | `rc 1`, 실패 1 (`test_cancel_all_fence.sh` 가 mode 100644) |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 126초 뒤 `rc 1` — 90초 상한에서는 **`rc 124`** 로 보인다 |
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | `rc 1` (양성 대조가 Bash matcher ≥2 를 기대, 리포엔 1) |

**대조 2 — `rc 124` 두 자리를 600초로 갈라낸다.** 같은 `rc 124` 가 «113초 GREEN» 과 «126초 RED» 를 함께 덮고 있었다:

```bash
export PYTHONDONTWRITEBYTECODE=1
TMO=$(command -v timeout || command -v gtimeout)
"$TMO" 600 bash shared/tests/test_docreview_mutations.sh >/dev/null 2>&1; echo "docreview_mutations rc=$?  (기대 0)"
"$TMO" 600 bash plugins/quality-gates/tests/test_codex_backward_compat.sh >/dev/null 2>&1; echo "codex_backward_compat rc=$? (기대 1 — 선재 RED)"
```

**대조 3 — python 총계.** 이 PR 은 파이썬 테스트를 **추가하지 않는다**. 네 디렉토리의 `ran=` 합이 baseline 의 **648** 과 같아야 한다:

```bash
awk '/^## PYTHON/{s=1;next} s&&/ran=/{sub(/^.*ran=/,"");print $1+0}' "$HOME/pyfloor-after.txt" \
  | awk '{t+=$1} END{print "python total:", t, "(기대 648)"}'
```

**판정 규칙:**
- bash 자리 — `rc` 와 **실패 줄 수** 가 둘 다 같아야 한다. rc 만 보면 **이미 RED 인 자리 «안» 의 새 실패가 원리적으로 안 보인다.**
- python 자리 — `failures=` 수뿐 아니라 **실패한 테스트 이름**을 본다(위 러너가 `::` 뒤에 낸다). 수는 같고 이름이 다르면 회귀 하나와 수정 하나가 서로를 가린 것이다.
- **선재 RED 가 «고쳐진» 것도 보고 대상이다.** 이 PR 이 왜 그것을 고쳤는지 설명할 수 없으면 우연이고, 우연은 다음에 우연히 되돌아간다.
- 정리: `rm -f "$HOME/pyfloor-runner.sh" "$HOME/pyfloor-after.txt"` — 다만 **결과 요약은 PR 본문에 남긴다.**

- [ ] **Step 3: 신규 락이 새 RED 를 만들지 않았는지 본다**

```bash
bash shared/tests/test_copy_of_contract.sh   | tail -3
bash shared/tests/test_no_new_duplication.sh | tail -3
bash shared/tests/test_python_floor.sh       | tail -3
```
Expected: 셋 다 `Fail: 0`.

- [ ] **Step 4: 통과-정답 단언의 관측 (Verification Plan 7)**

수치를 **인쇄해서** 대조한다. 통과가 정답인 단언은 모양으로 이빨을 판별할 수 없다.

```bash
echo "=== AC1: bare python3 로 시작하는 훅 자리 (0 이어야) ==="
grep -h '"command"' plugins/*/hooks/hooks.json | grep -c '"command": "python3 ' || echo 0

echo "=== AC1: sh <해석기> 를 경유하는 자리 (4 여야) ==="
grep -h '"command"' plugins/*/hooks/hooks.json | grep -c 'devbrew-python\.sh'

echo "=== AC11: plugin-audit hooks_killswitch ==="
for p in project-init quality-gates spec-distill; do
  printf '%-14s ' "$p"
  python3 plugins/plugin-audit/scripts/check-shape-completeness.py "plugins/$p" \
    | python3 -c 'import json,sys;d=json.load(sys.stdin)["shape_gaps"];print([g["present"] for g in d if g["requirement"]=="hooks_killswitch"][0])'
done

echo "=== AC14: prerequisite 문자열 (3/1/0) ==="
grep -c 'Python 3.12+' plugins/project-init/README.md plugins/quality-gates/README.md plugins/spec-distill/README.md plugins/plugin-audit/README.md

echo "=== AC16: uv.lock 의 PyYAML 핀 ==="
awk '/^name = "pyyaml"$/{f=1;next} f&&/^version = /{print;exit}' uv.lock

echo "=== AC10: 훅·스크립트의 python3 spawn (0 이어야) ==="
# `grep -vc` 는 빈 입력에 0 을 «찍고» rc 1 로 끝나므로 `|| echo 0` 을 달면 0 이 두 번 나온다.
{ grep -rn '"python3"' plugins --include='*.py'; grep -rn "'python3'" plugins --include='*.py'; } 2>/dev/null \
  | grep -v '/tests/' | wc -l | tr -d ' '
```

기대값: `0` · `4` · `True True True` · `plugin-audit/README.md:0` · `version = "6.0.3"` 형태 · `0`.

- [ ] **Step 5: 결과를 보고하고(고칠 게 있으면 고치고) 커밋**

수정이 없으면 커밋할 것이 없다. 있으면 해당 Task 의 커밋 메시지 규약을 따른다.

---

### Task 9: version bump 와 CHANGELOG (머지 직전)

**Files:**
- Modify: `plugins/{plugin-audit,project-init,quality-gates,spec-distill}/.claude-plugin/plugin.json`
- Modify: `plugins/{plugin-audit,project-init,quality-gates,spec-distill}/CHANGELOG.md`

**Interfaces:**
- Consumes: 앞 Task 전부.

- [ ] **Step 1: 지금의 버전을 읽는다 — 리터럴을 미리 적지 않는다**

```bash
for p in plugin-audit project-init quality-gates spec-distill; do
  printf '%-14s ' "$p"
  python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "plugins/$p/.claude-plugin/plugin.json"
done
```

착수 시점의 값은 `0.9.3` · `3.1.1` · `7.6.2` · `3.2.0` 이었다. **머지 직전에 다시 읽는다** — 먼저 머지되는 PR 이 이긴다.

- [ ] **Step 2: bump 등급을 정한다**

등급은 **플러그인마다 다르다** — 무엇이 바뀌었는지가 다르기 때문이다.

| 플러그인 | 무엇이 바뀌나 | 등급 | 착수 시점 값 기준 |
|---|---|---|---|
| `project-init` | 훅이 Python 3.12+ 를 요구한다 = **설치 요구사항 추가** | breaking → 1.0 이상이므로 **major** | `3.1.1 → 4.0.0` |
| `quality-gates` | 같음 + advisor 의 새 stdout 채널 | breaking → **major** | `7.6.2 → 8.0.0` |
| `spec-distill` | 같음 + GC 자식 인터프리터 변경 | breaking → **major** | `3.2.0 → 4.0.0` |
| `plugin-audit` | **자기 표면은 안 바뀐다.** 감사 «대상» 이 바뀌어 cache key 만 무효화하면 된다 | **patch** | `0.9.3 → 0.9.4` |

리터럴은 Step 1 에서 **다시 읽은 값**으로 계산한다 — 오른쪽 열은 착수 시점의 값일 뿐이고, 먼저 머지되는 PR 이 이긴다.

- [ ] **Step 3: `plugin.json` 넷을 고친다**

`"version"` 값만 바꾼다. 다른 필드는 건드리지 않는다.

- [ ] **Step 4: CHANGELOG 넷에 항목을 더한다**

각 파일 **맨 위 헤딩 위**에 새 절을 «끼운다». **제자리에서 덮어쓰지 않는다** — 덮어쓰면 앞 릴리스의 본문이 새 버전 안으로 흡수되고 `test_changelog_integrity.sh` 의 gap 래칫이 그 틈을 잡는다.

세 플러그인(예: `quality-gates`):

```markdown
## [8.0.0] — 2026-09-21

major 인 이유 — **설치 요구사항이 하나 늘어난다.** 이 플러그인의 훅은 이제 Python 3.12
이상을 요구하고, 바닥 미만 머신에서는 돌지 않는다(막지는 않는다 — 건너뛴다).

### Changed

- **훅이 `python3` 를 직접 부르지 않는다.** `hooks.json` 의 자리가 `sh
  ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event … --plugin … --hook … <훅.py>` 로
  바뀌었다. 해석기는 kill switch 를 먼저 보고(정본과 같은 판정), `$DEVBREW_PYTHON` →
  `python3` → PATH 의 `python3.*` 순으로 바닥을 만족하는 인터프리터를 찾아 `exec` 한다.
  마이너 버전을 열거하지 않으며 `python3` 로 fallback 하지 않는다.

### Added

- `scripts/devbrew-python.sh` — `shared/python/devbrew-python.sh` 의 물리 사본
  (`# copy-of:`). 심볼릭 링크면 `plugin-audit` 의 containment 검사가 `shared/` 로 풀려
  거짓 「kill switch 부재」를 낸다.
- README 에 `Python 3.12+` prerequisite 와 바닥의 **도출 규칙**.
- (quality-gates 만) `session-start-advisor` 가 `$DEVBREW_PYTHON` 무시 사실을
  `additionalContext` + `systemMessage` 로 공시한다 — stderr 는 모델에 닿지 않는다(실측 0/1).
```

`spec-distill` 에는 위에 더해:
```markdown
- **TTL-GC 자식을 `sys.executable` 로 띄운다** (`scripts/hook_common.py`). `python3` 로
  띄우면 해석의 효력이 프로세스 경계에서 끊겨 자식만 바닥 미만으로 떨어진다.
```

`plugin-audit` (patch):
```markdown
## [0.9.4] — 2026-09-21

### Changed

- 감사 대상 세 플러그인의 `hooks.json` 과 `scripts/` 가 바뀌어 cache key 를 무효화한다.
  이 플러그인 자신의 표면·동작은 바뀌지 않았다. 훅이 없고 셸 자리는 Python 바닥 집행의
  범위 밖이라 `Python 3.12+` prerequisite 를 주장하지 않는다 — 집행하는 주체가 없는
  선언은 두지 않는다.
```

- [ ] **Step 5: CHANGELOG 락을 돌린다**

```bash
bash shared/tests/test_changelog_integrity.sh
python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_check_staleness.py'
```
Expected: `Fail: 0`. gap 래칫이 걸리면 **맨 위 헤딩을 덮어썼다는 뜻이다** — 새 절을 끼웠는지 확인하라.

- [ ] **Step 6: 커밋**

```bash
git add plugins/*/.claude-plugin/plugin.json plugins/*/CHANGELOG.md
git commit -m "chore: 네 플러그인 version bump + CHANGELOG

바닥 상향은 설치 요구사항을 하나 늘리므로 breaking 이다 — 1.0 이상 셋은 major,
plugin-audit 은 자기 표면이 안 바뀌므로 patch(cache key 무효화 목적).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 이 계획이 «하지 않는» 일

착수자가 범위를 넓히지 않도록 명시한다. 아래를 하고 싶어지면 **멈추고 물어라** — 전부 의도적으로 뺀 것이다.

1. **출하 셸 39자리(`plugins/*/scripts/*.sh`)의 `python3`.** 전부 스킬·커맨드가 Bash 로 부르는 자리이고 그 자리의 stdout 은 훅 채널이 아니라 **데이터**다(D17·R12·L5).
2. **스킬·커맨드 지시문 · 문서 · 테스트의 `python3` 리터럴.** 모델이 traceback 을 직접 본다.
3. **출하 표면의 무가드 `import yaml` 3건.** 이 설계와 **독립적으로 지금도 깨져 있다** — 같이 묶으면 「올려서 깨진 건가」 판별이 불가능해진다(Non-goal 1, 별도 PR).
4. **ruff 도입** · **69개 `__future__` shim 제거** · **CI 도입** · **3.9 테스트 레그**.
5. **두 바닥이 갈라지는 날의 출하 바닥 검증 수단**(L4). 지금 두 값이 같아 드러나지 않는다 — 갈라뜨리는 PR 이 그 자리를 연다.
6. **`.gitignore` 편집.** `uv.lock`·`.python-version` 규칙은 이미 주석이고 `.venv` 는 무시된다.

## 알려진 한계 (구현이 지우지 못하는 것)

- **L1** 해석기는 `python3.*` 라는 **이름 규약**에 의존한다. conda 나 이름이 다른 shim 은 못 찾는다. `$DEVBREW_PYTHON` 이 탈출구이고 안내가 그 존재를 알린다.
- **L2** 채널 실측은 헤드리스 `-p` 전용이다. `SessionEnd`·`PostToolUse(Bash)`·대화형 TUI 는 **미측정**이다. 안내를 `SessionStart`(3/3 측정됨) 한 자리로 모은 것이 이 한계에 대한 대응이다.
- **L3** AC12 는 `PATH=/usr/bin:/bin` 이 바닥 미만 `python3` 를 준다는 **이 머신의 사실**에 의존한다. Task 3 축 C2 의 자기 확인이 그 사실이 깨지는 날 **조용히 아무것도 재지 않는 대신 RED 를 낸다.**
- **L7** 출하 셸 「39건 / 11파일」은 **하한**이다 — 글롭이 심볼릭 링크를 건너뛴다. 범위를 넓히는 PR 은 거기서부터 재집계해야 한다.
- **L8** 설치 캐시에서의 배포 동작은 비문서다. 물리 사본은 링크 역참조 의존을 지우지만 설치본의 배치 자체를 보장하지는 못한다. Task 3 Step 5 의 모의는 «모의» 다.
- **축 B 의 fixture 한계** — 가짜 인터프리터가 「바닥을 만족한다」고 거짓말하는 것 자체는 이 락이 못 잰다(그것이 측정 수단이다). 양성(3.99 를 고른다)과 음성(3.9 를 건너뛴다)을 **둘 다** 요구하는 것이 그 자리의 최선이다.
