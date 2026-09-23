# 해석기는 절대 경로 PATH 항목만 본다 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 훅 command 의 `sh` 탐색과 해석기가 인터프리터 파일을 고르는 두 탐색(2단계 `python3` · 3단계 `python3.*`)이 PATH 의 절대 경로가 아닌 항목(빈 항목 · `.` · 상대 경로 · 빈 PATH)을 쓰지 않게 한다.

**Architecture:** 해석기 `shared/python/devbrew-python.sh` 의 2단계를 셸 탐색(`probe python3`) 대신 새 함수 `first_python3` 로 바꾼다 — `scan_path` 와 같은 분할 관용구로 PATH 를 돌며 `/` 로 시작하는 항목만 보고 첫 `-f`·`-x` `python3` 에서 멈춘다. 3단계 `scan_path` 는 빈 항목을 `.` 으로 바꾸던 한 줄을 「절대 경로가 아니면 건너뛴다」로 바꾼다. 훅 command 4자리는 `/bin/sh` 로 해석기를 부른다. 락 `shared/tests/test_python_floor.sh` 에 축 I(실행으로 재는 카나리)와 축 C 의 AC9 실행분을 더한다.

**Tech Stack:** POSIX sh(해석기 — 외부 명령 0개), bash 3.2 셸 테스트(`shared/tests/assert.sh`), python3(편집 확인·변이 스크립트).

**Spec:** `docs/superpowers/specs/2026-09-23-python-resolver-absolute-path-only-design.md` (커밋 `a9590ba8`) — 실행자는 설계의 `## Acceptance Criteria` · `## Verification Plan` · `## 알려진 한계` 를 먼저 읽는다.

## 목차

- [Global Constraints](#global-constraints)
- [Review Focus](#review-focus)
- [File Structure](#file-structure)
- [Task 1: 해석기 2·3단계를 절대 경로 항목만 보게 한다 (축 I)](#task-1-해석기-23단계를-절대-경로-항목만-보게-한다-축-i)
- [Task 2: 훅 command 를 `/bin/sh` 로 부른다 (AC9)](#task-2-훅-command-를-binsh-로-부른다-ac9)
- [Task 3: 세 플러그인 patch bump + `### Security`](#task-3-세-플러그인-patch-bump--security)
- [Task 4: 검증 — 변이 · 형제 스위트 · 재현표 · 셸 셋 · base](#task-4-검증--변이--형제-스위트--재현표--셸-셋--base)
- [이 plan 이 끝난 뒤](#이-plan-이-끝난-뒤)

## Global Constraints

- **C1 — 해석기는 외부 명령 0개.** 새 코드도 셸 내장(`case`·`[`·`set`)만 쓴다. `tr`·`sed` 를 쓰면 PATH 에 `/usr/bin` 이 없을 때 kill switch 판정이 fail-open 한다(실측). 락의 A4 가 잰다.
- **C2 — kill switch 가 모든 탐색보다 앞선다.** 변경은 2·3단계 안에서만.
- **C3 — `probe` 의 `</dev/null` 계약은 그대로다.**
- **C4 — 배포 사본은 `copy-of` 계약을 탄다.** 정본을 고치면 `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` 3개를 재생성한다(1줄 shebang · 2줄 `# copy-of: shared/python/devbrew-python.sh` · 나머지 = 정본 2줄~). 모드는 `100644` 그대로.
- **C5 — `set -f` 는 분할 동안만.** 기존 `scan_path` 관용구를 그대로 쓴다.
- **C6 — 락은 리포 밖에서 재현한다.** 새 축의 cwd 는 락의 `$TMP` 아래다. 리포 작업 트리에 카나리를 만들지 않는다.
- **판정 규칙** — PATH 항목 `d` 는 `case "$d" in /*)` 에 걸릴 때만 탐색 대상. 경고는 내지 않는다(설계 R5).
- **2단계는 첫 `python3` 만 본다**(설계 D3). 그것이 바닥 미만이면 다음 `python3` 를 찾지 않고 3단계로 간다.
- **버전** — 사본을 가진 세 플러그인 patch bump: project-init `4.0.0 → 4.0.1` · quality-gates `8.2.2 → 8.2.3` · spec-distill `4.2.1 → 4.2.2`. 각 CHANGELOG 에 `### Security`. 번호는 머지 직전에 `origin/main` 기준으로 다시 확인한다(Task 4 Step 7).
- **문서 언어** — 한국어 primary. 커밋은 Conventional Commits.
- **기준선(2026-09-24, 이 워크트리 HEAD `a9590ba8`)** — `test_python_floor.sh` 131/131 · `test_copy_of_contract.sh` 200/200 · `test_changelog_integrity.sh` 27/27 · `test_guards_coverage_bidirectional.sh` 268/268 · `test_command_contract.py` 10 OK.

## Review Focus

`first_python3` 는 셸의 명령 탐색을 손으로 흉내 낸다. 흉내가 어긋나기 쉬운 자리는 AC 가 싣지 않으므로 아래 다섯을 Task 1 의 테스트(`I/RF1`~`I/RF5`)로 못 박는다.

1. **심볼릭 링크 `python3`(홈브루 모양)** — 셸 탐색처럼 골라야 한다. `-f` 가 링크를 따라가는지. → `I/RF1`
2. **이름이 `python3` 인 디렉토리가 앞 항목에 있다** — 셸은 건너뛰고 다음 항목의 `python3` 를 쓴다. → `I/RF2`
3. **실행 비트 없는 `python3` 가 앞 항목에 있다** — 셸은 건너뛴다. → `I/RF3`
4. **PATH 에 글자 그대로의 `~/bin`** — macOS `/bin/sh` 는 전개하지만 이제는 건너뛴다(설계 L1 이 받아들인 동작 변경). 그 변경이 의도대로 일어나는지. → `I/RF4`
5. **2단계 exec 의 argv 보존** — 새 exec 자리(`exec "$FIRST_PY3" "$@"`)가 공백 든 인자 · 빈 인자를 그대로 넘기는지. → `I/RF5`

---

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `shared/python/devbrew-python.sh` | 해석기 정본. 2단계 `first_python3` · 3단계 판정 한 줄 · 머리말 호출 형태 | 1, 2 |
| `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh` | 배포 사본(재생성만) | 1, 2 |
| `plugins/{quality-gates,spec-distill,project-init}/hooks/hooks.json` | 훅 command 4자리 `sh` → `/bin/sh` | 2 |
| `shared/tests/test_python_floor.sh` | 축 I 신설 · 축 C 기대 형태와 AC9 실행분 · 머리 축 목록 | 1, 2 |
| `plugins/{project-init,quality-gates,spec-distill}/.claude-plugin/plugin.json` | patch bump | 3 |
| `plugins/{project-init,quality-gates,spec-distill}/CHANGELOG.md` | `### Security` | 3 |

**설계가 plan 으로 넘긴 두 항목의 답:**
1. 축 이름과 자리 — 해석기 행동은 새 **축 I**(축 A 의 A11 뒤, 축 B `note` 바로 앞). 훅 command 실행분은 hooks.json 을 이미 읽는 **축 C** 안(개수 단언 `n_bare` 뒤)에 `C/AC9` 로 둔다. cwd 는 셋으로 가른다 — c1(점 있는 카나리만 · 3단계 전용) · c2(점 없는 카나리만 · 2단계 전용) · c4(둘 다 · AC4). 한 cwd 에 섞으면 변이 하나가 두 축을 함께 RED 로 만든다.
2. `sh ${CLAUDE_PLUGIN_ROOT}` 를 리터럴로 기대하는 다른 락 — 전수 조사 결과 **`test_python_floor.sh` 축 C(`:471`) 하나뿐**이다(`git ls-files` 전체 grep, 2026-09-24). 나머지 hooks.json 소비자는 모양에 무관하다: `plugins/project-init/tests/test_command_contract.py:125` 는 `split()[-1]`(마지막 토큰)만, `plugins/plugin-audit/scripts/check-shape-completeness.py` 의 `_CMD_SCRIPT_RE` 는 `\.(py|sh)` 로 끝나는 경로만 잡는다 — `/bin/sh` 는 점이 없어 걸리지 않는다. 그 감사기 판정은 축 C 의 `C/AC11` 이 이미 실행으로 잰다.

**이 plan 의 코드 블록은 전부 스크래치 사본(`git archive HEAD`)에서 실제로 돌려 본 것이다** — 적용 후 173/173, 변이 m1~m4 의 RED 집합이 설계 Verification 2 와 정확히 일치, `dash`·`ksh` 로 해석기를 불러도 173/173. 블록을 옮길 때 **글자 그대로** 옮긴다.

---

### Task 1: 해석기 2·3단계를 절대 경로 항목만 보게 한다 (축 I)

**Files:**
- Modify: `shared/python/devbrew-python.sh:149-153` (2단계), `:163` (3단계)
- Modify: `shared/tests/test_python_floor.sh` — 축 B `note` 줄(현재 `:370`) 바로 앞에 축 I 삽입, 머리 축 목록(`:8`)
- Regenerate: `plugins/{project-init,quality-gates,spec-distill}/scripts/devbrew-python.sh`

**Interfaces:**
- Consumes: 락의 기존 fixture — `$TMP` · `$R`(정본 해석기 절대 경로) · `$TARGET`(stdout 에 `TARGET-RAN` 과 stdin 을 찍는 대상) · `$PAY`(`PAYLOAD-INTACT` 포함) · `$TMP/plain/python3`(바닥 미만, 점 없음) · `$TMP/plainfloor/python3`(바닥 만족, 점 없음) · `$PATH_PLAINFLOOR` · `FLOOR_MAJOR_VAL`/`FLOOR_MINOR_VAL` · `assert.sh` 의 `ok`/`no`/`assert_contains`/`assert_not_contains`.
- Produces: 해석기 전역 `FIRST_PY3` 와 함수 `first_python3`(rc 0 이면 `FIRST_PY3` = 첫 절대 경로 `python3`). 락 쪽 `I_MARK` · `mk_canary <경로>` · `run_in <cwd> <PATH>` — Task 2 는 이것을 쓰지 않는다(자기 fixture 를 따로 둔다).

- [ ] **Step 1: 락 머리의 축 목록을 고친다**

`shared/tests/test_python_floor.sh` 에서

```
# F 도출 규칙의 산출물 기록 · G prerequisite · H uv.lock 핀.
```

을

```
# F 도출 규칙의 산출물 기록 · G prerequisite · H uv.lock 핀 · I 비-절대 PATH 항목.
```

로.

- [ ] **Step 2: 축 I 를 넣는다 (실패하는 테스트)**

`shared/tests/test_python_floor.sh` 의 줄

```
note "── 축 B: 배포 — 물리 사본 (AC11 · C9 · C10) ───────────────────────────"
```

바로 **앞에** 아래 블록을 넣고, 블록과 그 `note` 줄 사이에 빈 줄 하나를 둔다. 블록 안의 `printf` 형식 문자열·작은따옴표를 바꾸지 않는다(bash 3.2 에서 돌려 본 그대로다).

```bash
note "── 축 I: 비-절대 PATH 항목 (설계 2026-09-23 AC1~AC4 · AC8) ──────────────"
# 해석기의 두 탐색(2단계 `python3` · 3단계 `python3.*`)이 PATH 의 절대 경로가 아닌 항목
# (빈 항목 · `.` · 상대 경로 · 빈 PATH)을 쓰지 않는다는 것을 **실행으로** 잰다. 훅의 cwd 는
# 사용자가 연 리포라, 그런 항목을 쓰는 것은 곧 「리포 안의 파일을 실행한다」다.
#
# 카나리 = 실행되는 순간 자기 마커를 남기고 바닥을 만족한다고 답하는 가짜 인터프리터. 마커는
# 셸 내장 리다이렉션으로 남긴다 — 좁힌 PATH 에 `touch` 가 없다. cwd 는 셋으로 가른다:
# c1 은 점 있는 카나리만(3단계만 겨눈다), c2 는 점 없는 카나리만(2단계만 겨눈다), c4 는 둘 다.
# 한 cwd 에 섞으면 한 변이가 두 탐색을 함께 RED 로 만들어 어느 쪽이 새는지 가를 수 없다.
I_MARK="$TMP/i-canary.ran"
mk_canary() {   # mk_canary <경로> — 실행되면 $I_MARK 를 남기고, -c 에는 출하 바닥을 답한다
  printf '#!/bin/sh\n: > "%s"\n[ "$1" = "-c" ] && { echo "%s %s"; exit 0; }\nexec "$@"\n' \
    "$I_MARK" "$FLOOR_MAJOR_VAL" "$FLOOR_MINOR_VAL" > "$1"
  chmod +x "$1"
}
mkdir -p "$TMP/c1/rel" "$TMP/c2/rel" "$TMP/c4" "$TMP/a8b"
mk_canary "$TMP/c1/python3.99"
mk_canary "$TMP/c1/rel/python3.99"
mk_canary "$TMP/c2/python3"
mk_canary "$TMP/c2/rel/python3"
mk_canary "$TMP/c4/python3"
mk_canary "$TMP/c4/python3.99"
mk_canary "$TMP/a8b/python3"

run_in() {   # run_in <cwd> <PATH> — SessionEnd 라 해석에 실패하면 stdout 이 비어 있다
  rm -f "$I_MARK"
  (cd "$1" && printf '%s' "$PAY" | env PATH="$2" /bin/sh "$R" \
     --event SessionEnd --plugin qg --hook h "$TARGET" 2>/dev/null)
}

# 증인 — 절대 경로 부분(`/bin`·`/usr/sbin`)에 python 이 있으면 되돌린 셸 탐색이 그것을 먼저
# 만나 cwd 에 닿지 않는다(끝 빈 항목 형태). 그러면 아래 단언은 변이로도 RED 가 안 되는 장식이다.
for d in /bin /usr/sbin; do
  i_py=""
  for f in "$d"/python3*; do [ -e "$f" ] && i_py="$f"; done
  if [ -n "$i_py" ]; then no "I: 증인 — $d 에 python 이 있다($i_py). 축 I 의 절대 경로 부분을 다시 골라라"
  else ok "I: 증인 — $d 에 python3* 가 없다"; fi
done

# AC1 — 3단계. 끝 빈 항목은 싣지 않는다: 그 형태는 IFS 분할이 끝 빈 필드를 버려 수정 전에도
# 안전했고, 변이로 RED 가 될 수 없는 케이스는 단언이 아니라 장식이다(설계 L3).
for p in ":/bin" "/bin::/usr/sbin" ".:/bin" "rel:/bin"; do
  run_in "$TMP/c1" "$p" >/dev/null
  if [ -f "$I_MARK" ]; then no "I/AC1: PATH='$p' — 3단계가 cwd 의 python3.* 를 실행했다"
  else ok "I/AC1: PATH='$p' — 3단계가 cwd 의 python3.* 를 실행하지 않는다"; fi
done

# AC2 — 2단계. 셸 탐색은 끝 빈 항목·상대 경로·빈 PATH 도 cwd 로 푼다〔설계 Context/Why 2 실측〕.
for p in ":/bin" "/bin::/usr/sbin" ".:/bin" "rel:/bin" "/bin:" ""; do
  run_in "$TMP/c2" "$p" >/dev/null
  if [ -f "$I_MARK" ]; then no "I/AC2: PATH='$p' — 2단계가 cwd 의 python3 를 실행했다"
  else ok "I/AC2: PATH='$p' — 2단계가 cwd 의 python3 를 실행하지 않는다"; fi
done

# AC3 — 양성 대조. 같은 카나리를 절대 경로로 주면 돈다. 이것이 없으면 위 「마커 없음」은
# 카나리가 고장 나도 통과한다.
for d in c1 c1/rel c2 c2/rel a8b; do
  out="$(run_in "$TMP" "$TMP/$d:/bin")"
  if [ -f "$I_MARK" ]; then ok "I/AC3: 절대 경로로 준 카나리는 돈다 ($d)"
  else no "I/AC3: 절대 경로로 준 카나리도 안 돈다 ($d) — 축 I 의 「마커 없음」이 헛돈다"; fi
  assert_contains "$out" "TARGET-RAN" "I/AC3: 그 카나리가 대상을 exec 한다 ($d)"
done

# AC4 — 올바른 선택. cwd 에 점 없는 것과 있는 것을 **둘 다** 둔다: `python3.99` 만 두면 원래
# 코드도 2단계에서 절대 디렉토리로 끝나 어떤 변이에서도 GREEN 이다.
out="$(run_in "$TMP/c4" ":$TMP/plainfloor")"
if [ -f "$I_MARK" ]; then no "I/AC4: 앞 빈 항목이 cwd 카나리를 집었다"
else ok "I/AC4: cwd 카나리(python3 · python3.99)가 돌지 않는다"; fi
assert_contains "$out" "TARGET-RAN" "I/AC4: 절대 디렉토리의 바닥 만족 python3 로 대상이 돈다"
assert_contains "$out" "PAYLOAD-INTACT" "I/AC4: payload 가 온전하다"

# AC8 — 2단계는 첫 `python3` 만 본다(설계 D3). plain/python3 는 바닥 미만, a8b/python3 는 바닥 만족
# 카나리이고, 어디에도 `python3.*` 가 없어 3단계는 빈손이다. 셸 탐색도 첫 매치에서 멈추므로 2단계를
# 셸 탐색으로 되돌려도 GREEN 이고, 「다음 python3 를 찾는」 변이에서만 RED 다.
out="$(run_in "$TMP" "$TMP/plain:$TMP/a8b")"
if [ -f "$I_MARK" ]; then no "I/AC8: 첫 python3 가 바닥 미만인데 다음 python3 로 넘어갔다"
else ok "I/AC8: 첫 python3 가 바닥 미만이면 다음 python3 를 찾지 않는다"; fi
assert_not_contains "$out" "TARGET-RAN" "I/AC8: 대상이 돌지 않는다"

# 설계 Goal 2 의 경계 — 셸 탐색과 같은 것을 고르는가. `first_python3` 는 셸 탐색을 흉내 내므로,
# 흉내가 어긋나기 쉬운 자리를 셸 탐색의 답과 대조한다(Review Focus). 대상이 돌면 절대 디렉토리
# `$TMP/plainfloor` 의 python3 가 골라진 것이다 — 다른 후보는 전부 바닥 미만이거나 실행 불가다.
mkdir -p "$TMP/lnk" "$TMP/dirpy/python3" "$TMP/noexec"
ln -s "$TMP/plainfloor/python3" "$TMP/lnk/python3"
printf '#!/bin/sh\necho "%s %s"\n' "$FLOOR_MAJOR_VAL" "$FLOOR_MINOR_VAL" > "$TMP/noexec/python3"   # 실행 비트 없음
out="$(run_in "$TMP" "$TMP/lnk:/bin")"
assert_contains "$out" "TARGET-RAN" "I/RF1: 심볼릭 링크인 python3(홈브루 모양)를 고른다"
out="$(run_in "$TMP" "$TMP/dirpy:$TMP/plainfloor")"
assert_contains "$out" "TARGET-RAN" "I/RF2: 이름이 python3 인 디렉토리는 건너뛰고 다음 항목의 python3 를 고른다"
out="$(run_in "$TMP" "$TMP/noexec:$TMP/plainfloor")"
assert_contains "$out" "TARGET-RAN" "I/RF3: 실행 비트 없는 python3 는 건너뛰고 다음 항목의 python3 를 고른다"

# 전개되지 않은 틸드(`PATH="~/tb:…"` 처럼 따옴표 안의 `~`)도 절대 경로가 아니다. macOS /bin/sh 는
# 명령 탐색에서 그것을 $HOME 으로 전개하므로 2단계를 셸 탐색으로 되돌리면 이 단언이 RED 다 —
# 설계 L1 이 받아들인 동작 변경이 이것이다.
mkdir -p "$TMP/home/tb"
mk_canary "$TMP/home/tb/python3"
rm -f "$I_MARK"
(cd "$TMP" && printf '%s' "$PAY" | env HOME="$TMP/home" PATH='~/tb:/bin' /bin/sh "$R" \
   --event SessionEnd --plugin qg --hook h "$TARGET" >/dev/null 2>&1)
if [ -f "$I_MARK" ]; then no "I/RF4: PATH 의 글자 그대로 '~/tb' 를 따라 python3 를 실행했다"
else ok "I/RF4: PATH 의 글자 그대로 '~/tb' 는 절대 경로가 아니라 건너뛴다 (설계 L1)"; fi

# 2단계가 exec 할 때 훅 argv 가 공백까지 그대로 가는가 — 새 exec 자리다.
ARGS_TARGET="$TMP/args.sh"
printf '#!/bin/sh\necho "argc=$#"\nfor a in "$@"; do echo "arg=[$a]"; done\n' > "$ARGS_TARGET"; chmod +x "$ARGS_TARGET"
out="$(printf '%s' "$PAY" | env PATH="$PATH_PLAINFLOOR" /bin/sh "$R" \
   --event SessionEnd --plugin qg --hook h "$ARGS_TARGET" "a b" "" "c" 2>/dev/null)"
assert_contains "$out" "argc=3" "I/RF5: 2단계 exec 가 훅 인자 개수를 보존한다 (빈 인자 포함)"
assert_contains "$out" "arg=[a b]" "I/RF5: 공백이 든 인자가 쪼개지지 않는다"
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh 2>&1 | grep -E '✗|^Total'`

Expected — 정확히 이 12줄과 합계:

```
  ✗ I/AC1: PATH=':/bin' — 3단계가 cwd 의 python3.* 를 실행했다
  ✗ I/AC1: PATH='/bin::/usr/sbin' — 3단계가 cwd 의 python3.* 를 실행했다
  ✗ I/AC1: PATH='.:/bin' — 3단계가 cwd 의 python3.* 를 실행했다
  ✗ I/AC1: PATH='rel:/bin' — 3단계가 cwd 의 python3.* 를 실행했다
  ✗ I/AC2: PATH=':/bin' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC2: PATH='/bin::/usr/sbin' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC2: PATH='.:/bin' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC2: PATH='rel:/bin' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC2: PATH='/bin:' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC2: PATH='' — 2단계가 cwd 의 python3 를 실행했다
  ✗ I/AC4: 앞 빈 항목이 cwd 카나리를 집었다
  ✗ I/RF4: PATH 의 글자 그대로 '~/tb' 를 따라 python3 를 실행했다
Total: 164 | Pass: 152 | Fail: 12
```

`I/AC8` · `I/AC3` · `I/RF1~3·5` 가 여기서 GREEN 인 것은 정상이다 — 셸 탐색도 첫 매치에서 멈추고(AC8), 나머지는 수정 전에도 성립하는 성질이다. 증인 두 줄(`I: 증인 — /bin …`, `/usr/sbin …`)이 `✗` 면 멈추고 보고한다 — 축 I 전체가 헛돈다.

- [ ] **Step 4: 2단계를 `first_python3` 로 바꾼다**

`shared/python/devbrew-python.sh` 에서 아래 5줄(현재 `:149-153`)을

```sh
# ── 2. python3 — 흔한 경우, spawn 1회로 끝난다 ──────────────────────────────
if probe python3; then
  note_best
  if satisfies; then exec python3 "$@"; fi
fi
```

다음으로 바꾼다:

```sh
# ── 2. python3 — 흔한 경우, spawn 1회로 끝난다 ──────────────────────────────
# 이름을 셸 탐색에 맡기지 않는다. 셸은 PATH 의 빈 항목·`.`·상대 경로(빈 PATH 포함)를 cwd 로
# 풀고, 훅의 cwd 는 사용자가 연 리포다 — 거기의 `./python3` 가 실행된다〔/bin/sh·dash·ksh·zsh
# 실측〕. 절대 경로 항목만 PATH 순서대로 보고 **첫** `python3` 에서 멈춘다. 셸 탐색도 첫 매치에서
# 멈추므로 절대 경로만 있는 PATH 에서는 결과가 같다 — 그것이 바닥 미만이면 다음 `python3` 를
# 찾지 않고 3단계로 간다.
FIRST_PY3=""
first_python3() {   # scan_path 와 같은 분할 관용구. 함수 안이라 `set --` 가 훅의 argv 를 건드리지 않는다
  _ifs_save="$IFS"
  IFS=":"; set -f
  set -- ${PATH-}
  set +f; IFS="$_ifs_save"
  for _dir in "$@"; do
    case "$_dir" in /*) ;; *) continue ;; esac
    if [ -f "$_dir/python3" ] && [ -x "$_dir/python3" ]; then
      FIRST_PY3="$_dir/python3"; return 0
    fi
  done
  return 1
}
if first_python3 && probe "$FIRST_PY3"; then
  note_best
  if satisfies; then exec "$FIRST_PY3" "$@"; fi
fi
```

- [ ] **Step 5: 3단계의 한 줄을 바꾼다**

같은 파일 `scan_path` 안의

```sh
    [ -n "$_dir" ] || _dir="."
```

를

```sh
    case "$_dir" in /*) ;; *) continue ;; esac   # 빈 항목·`.`·상대 경로는 cwd 다 (2단계 주석)
```

로(들여쓰기 4칸 그대로).

- [ ] **Step 6: 정본만 고친 상태를 돌린다**

Run: `bash shared/tests/test_python_floor.sh 2>&1 | grep -E '✗|^Total'`

Expected — 축 I 는 전부 GREEN, 사본이 아직 옛것이라 축 B 셋만 RED:

```
  ✗ B/C10: plugins/project-init/scripts/devbrew-python.sh 가 정본과 갈라졌다
  ✗ B/C10: plugins/quality-gates/scripts/devbrew-python.sh 가 정본과 갈라졌다
  ✗ B/C10: plugins/spec-distill/scripts/devbrew-python.sh 가 정본과 갈라졌다
Total: 164 | Pass: 161 | Fail: 3
```

- [ ] **Step 7: 사본 셋을 재생성한다**

리포 루트에서:

```bash
for p in project-init quality-gates spec-distill; do
  { head -1 shared/python/devbrew-python.sh
    echo '# copy-of: shared/python/devbrew-python.sh'
    tail -n +2 shared/python/devbrew-python.sh; } > "plugins/$p/scripts/devbrew-python.sh"
done
git diff --stat -- plugins/*/scripts/devbrew-python.sh
```

Expected: 사본 3개가 정본과 같은 줄 수만큼 바뀐다. `git ls-files -s plugins/*/scripts/devbrew-python.sh` 의 모드가 `100644` 그대로다(리다이렉션은 기존 파일 모드를 유지한다).

- [ ] **Step 8: 전부 통과를 확인한다**

Run: `bash shared/tests/test_python_floor.sh 2>&1 | tail -1`
Expected: `Total: 164 | Pass: 164 | Fail: 0`

Run: `bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -1`
Expected: `Total: 200 | Pass: 200 | Fail: 0`

- [ ] **Step 9: 커밋**

```bash
git add shared/python/devbrew-python.sh shared/tests/test_python_floor.sh \
  plugins/project-init/scripts/devbrew-python.sh \
  plugins/quality-gates/scripts/devbrew-python.sh \
  plugins/spec-distill/scripts/devbrew-python.sh
git commit -m "fix(python): 해석기가 절대 경로 PATH 항목만 탐색한다

2단계 python3 는 셸 탐색 대신 first_python3 로, 3단계 python3.* 글롭은
빈 항목을 '.' 으로 바꾸던 줄 대신 비-절대 항목을 건너뛴다. 빈 항목 · '.' ·
상대 경로 · 빈 PATH 가 훅 cwd(사용자가 연 리포)의 파일을 실행하던 경로다.
락 축 I 가 카나리로 잰다(AC1~AC4 · AC8 · RF1~RF5).

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git status --short
```

Expected: 커밋 파일 5개, `git status --short` 가 비어 있다. 버전 bump 는 Task 3 에서 세 플러그인을 한 번에 한다 — 이 브랜치는 PR 하나로 머지되고, 리포 규칙(플러그인을 건드리는 PR 마다 bump)은 PR 단위다.

---

### Task 2: 훅 command 를 `/bin/sh` 로 부른다 (AC9)

**Files:**
- Modify: `plugins/quality-gates/hooks/hooks.json:9,19` · `plugins/spec-distill/hooks/hooks.json:9` · `plugins/project-init/hooks/hooks.json:10`
- Modify: `shared/python/devbrew-python.sh:3` (머리말 호출 형태)
- Modify: `shared/tests/test_python_floor.sh` — 축 C 기대 형태(현재 `:471-473`), AC9 실행분(`n_bare` 단언 뒤)
- Regenerate: 사본 3개

**Interfaces:**
- Consumes: 락 축 C 의 `cmds_of <hooks.json>`(한 줄 = `<이벤트> <command>`) · `flag_val <플래그> <command>` · `$ROOT` · `$TMP`.
- Produces: 훅 command 형태 `/bin/sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event E --plugin P --hook H ${CLAUDE_PLUGIN_ROOT}/hooks/<훅>.py`. 락 쪽 `SH_CWD` · `SH_MARK` · `run_hook_cmd <플러그인 디렉토리> <kill switch 변수> <command>`.

- [ ] **Step 1: 축 C 기대 형태를 바꾼다 (실패하는 테스트)**

`shared/tests/test_python_floor.sh` 에서

```bash
      "sh \${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh "*)
        ok "C/AC1: $hj 의 자리가 sh <해석기> 를 경유한다" ;;
      *) no "C/AC1: $hj 의 command 가 기대 형태가 아니다: $cmd" ;;
```

를

```bash
      "/bin/sh \${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh "*)
        ok "C/AC9: $hj 의 자리가 /bin/sh <해석기> 를 경유한다" ;;
      *) no "C/AC9: $hj 의 command 가 기대 형태(/bin/sh <해석기>)가 아니다: $cmd" ;;
```

로.

- [ ] **Step 2: AC9 실행분을 넣는다 (실패하는 테스트)**

같은 파일의 줄

```bash
assert_eq "$n_bare" "0" "C/AC1: bare python3 로 시작하는 자리가 0 이다"
```

바로 **뒤에** 빈 줄 하나와 아래 블록을 넣는다(블록 뒤에는 원래 있던 빈 줄과 `# ── AC11 의 «감사기» 절반` 주석이 이어진다):

```bash
# AC9 (설계 2026-09-23) — 위는 command 의 «모양» 이다. 실제로 cwd 의 `sh` 를 안 집는지는 실행으로
# 잰다: 훅처럼 `/bin/sh -c "<command>"` 로, cwd 에 카나리 `sh` 를 두고 PATH 앞에 빈 항목을 둔다.
# 해석기에 닿으면 그 플러그인의 kill switch 가 곧바로 끝내 훅 파이썬은 돌지 않는다.
# 양의 짝: 같은 command 의 앞 `/bin/sh ` 를 bare `sh ` 로 바꾸면 카나리가 돌아야 한다 — 이것이
# 없으면 「카나리 없음」은 카나리가 고장 나도 통과한다.
SH_CWD="$TMP/shcwd"; SH_MARK="$TMP/sh-canary.ran"
mkdir -p "$SH_CWD"
printf '#!/bin/sh\n: > "%s"\n' "$SH_MARK" > "$SH_CWD/sh"; chmod +x "$SH_CWD/sh"
run_hook_cmd() {   # run_hook_cmd <플러그인 디렉토리> <kill switch 변수> <command>
  rm -f "$SH_MARK"
  (cd "$SH_CWD" && env PATH=":/usr/bin:/bin" CLAUDE_PLUGIN_ROOT="$ROOT/$1" "$2=1" \
     /bin/sh -c "$3" </dev/null >/dev/null 2>&1)
}
n_shexec=0
for hj in plugins/project-init/hooks/hooks.json \
          plugins/quality-gates/hooks/hooks.json \
          plugins/spec-distill/hooks/hooks.json; do
  hj_cmds="$(cmds_of "$hj")"
  plugin_dir="${hj%/hooks/hooks.json}"
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    cmd="${pair#* }"
    pl_arg="$(flag_val --plugin "$cmd")"
    ks_var="DEVBREW_$(printf '%s' "$pl_arg" | tr 'a-z-' 'A-Z_')_DISABLE"
    n_shexec=$((n_shexec+1))
    run_hook_cmd "$plugin_dir" "$ks_var" "$cmd"
    if [ -f "$SH_MARK" ]; then no "C/AC9: $hj ($pl_arg) — command 가 cwd 의 sh 를 실행했다: $cmd"
    else ok "C/AC9: $hj ($pl_arg) — command 가 cwd 의 sh 를 집지 않는다"; fi
    run_hook_cmd "$plugin_dir" "$ks_var" "sh ${cmd#/bin/sh }"
    if [ -f "$SH_MARK" ]; then ok "C/AC9: 양의 짝 — 같은 command 를 bare sh 로 부르면 카나리가 돈다 ($pl_arg)"
    else no "C/AC9: 양의 짝이 안 돈다 ($pl_arg) — 위 「카나리 없음」이 헛돈다"; fi
  done <<EOF
$hj_cmds
EOF
done
assert_eq "$n_shexec" "4" "C/AC9: 실행으로 잰 command 자리가 4건이다"
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash shared/tests/test_python_floor.sh 2>&1 | grep -E '✗|^Total'`

Expected — 기대 형태 4 + 실행 4, 합계 173:

```
  ✗ C/AC9: plugins/project-init/hooks/hooks.json 의 command 가 기대 형태(/bin/sh <해석기>)가 아니다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/quality-gates/hooks/hooks.json 의 command 가 기대 형태(/bin/sh <해석기>)가 아니다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/quality-gates/hooks/hooks.json 의 command 가 기대 형태(/bin/sh <해석기>)가 아니다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/spec-distill/hooks/hooks.json 의 command 가 기대 형태(/bin/sh <해석기>)가 아니다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/project-init/hooks/hooks.json (project-init) — command 가 cwd 의 sh 를 실행했다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/quality-gates/hooks/hooks.json (quality-gates) — command 가 cwd 의 sh 를 실행했다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/quality-gates/hooks/hooks.json (quality-gates) — command 가 cwd 의 sh 를 실행했다: sh ${CLAUDE_PLUGIN_ROOT}/…
  ✗ C/AC9: plugins/spec-distill/hooks/hooks.json (spec-distill) — command 가 cwd 의 sh 를 실행했다: sh ${CLAUDE_PLUGIN_ROOT}/…
Total: 173 | Pass: 165 | Fail: 8
```

(`…` 는 command 나머지.) 양의 짝 4줄(`C/AC9: 양의 짝 — …`)이 여기서 이미 `✓` 여야 한다 — 옛 command 앞에 `sh ` 가 하나 더 붙어도 bare `sh` 라 카나리가 돈다. 양의 짝이 `✗` 면 카나리 fixture 가 고장 난 것이니 멈추고 보고한다.

- [ ] **Step 4: 훅 command 4자리를 바꾼다**

세 파일에서 `"command": "sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh ` 를 `"command": "/bin/sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh ` 로 바꾼다 — quality-gates 2곳, spec-distill 1곳, project-init 1곳. 나머지 글자(인자 순서 · `timeout`)는 그대로.

확인:

```bash
grep -c '"command": "/bin/sh \${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh ' \
  plugins/quality-gates/hooks/hooks.json plugins/spec-distill/hooks/hooks.json plugins/project-init/hooks/hooks.json
python3 -c 'import json,sys; [json.load(open(f, encoding="utf-8")) for f in sys.argv[1:]]; print("json ok")' \
  plugins/quality-gates/hooks/hooks.json plugins/spec-distill/hooks/hooks.json plugins/project-init/hooks/hooks.json
```

Expected: `…quality-gates…:2`, `…spec-distill…:1`, `…project-init…:1`, `json ok`.

- [ ] **Step 5: 해석기 머리말의 호출 형태를 고친다**

`shared/python/devbrew-python.sh:3` 의

```sh
# `sh <이 파일> --event E --plugin P --hook H <훅.py>` 로 부르고,
```

를

```sh
# `/bin/sh <이 파일> --event E --plugin P --hook H <훅.py>` 로 부르고,
```

로. 그리고 Task 1 Step 7 의 사본 재생성 루프를 **그대로** 다시 돌린다.

- [ ] **Step 6: 전부 통과를 확인한다**

Run: `bash shared/tests/test_python_floor.sh 2>&1 | tail -1`
Expected: `Total: 173 | Pass: 173 | Fail: 0`

Run: `bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -1`
Expected: `Total: 200 | Pass: 200 | Fail: 0`

Run: `python3 -m unittest plugins/project-init/tests/test_command_contract.py 2>&1 | tail -1`
Expected: `OK` (마지막 토큰이 여전히 훅 `.py` 다)

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/hooks/hooks.json plugins/spec-distill/hooks/hooks.json \
  plugins/project-init/hooks/hooks.json shared/python/devbrew-python.sh \
  shared/tests/test_python_floor.sh \
  plugins/project-init/scripts/devbrew-python.sh \
  plugins/quality-gates/scripts/devbrew-python.sh \
  plugins/spec-distill/scripts/devbrew-python.sh
git commit -m "fix(hooks): 훅 command 가 해석기를 /bin/sh 로 부른다

bare sh 도 PATH 탐색을 타서 앞 빈 항목 · '.' 이 있으면 훅 cwd 의 sh 를
실행했다. 네 자리 모두 /bin/sh 로. 락 축 C 가 모양(AC9)과 실행
(cwd 카나리 sh + 양의 짝)을 함께 잰다.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git status --short
```

Expected: 커밋 파일 8개, 작업 트리 깨끗.

---

### Task 3: 세 플러그인 patch bump + `### Security`

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json` (`4.0.0` → `4.0.1`), `plugins/quality-gates/.claude-plugin/plugin.json` (`8.2.2` → `8.2.3`), `plugins/spec-distill/.claude-plugin/plugin.json` (`4.2.1` → `4.2.2`)
- Modify: 세 `CHANGELOG.md` — 맨 위 `## [` 헤딩 바로 앞에 새 절

**Interfaces:**
- Consumes: Task 1·2 의 결과(바뀐 파일 목록이 CHANGELOG 문면의 근거).
- Produces: 없음.

- [ ] **Step 1: 착수 전 base 를 확인한다**

```bash
git fetch origin main
git log --oneline HEAD..origin/main
```

Expected: 출력 없음(base `0af757ee` 이후 main 이 안 움직였다). 출력이 있으면 그 커밋들이 세 플러그인의 `plugin.json` 을 건드렸는지 `git diff HEAD...origin/main --stat -- plugins/project-init plugins/quality-gates plugins/spec-distill` 로 보고, 건드렸다면 **그 버전 다음 patch** 로 번호를 바꾼다(아래 문면의 번호도 함께).

- [ ] **Step 2: `plugin.json` 셋을 bump 한다**

각 파일의 `"version": "<옛>"` 한 줄만 바꾼다. 확인:

```bash
grep -h '"version"' plugins/project-init/.claude-plugin/plugin.json \
  plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json
```

Expected: `"version": "4.0.1",` · `"version": "8.2.3",` · `"version": "4.2.2",`

- [ ] **Step 3: quality-gates CHANGELOG**

`plugins/quality-gates/CHANGELOG.md` 의 `## [8.2.2] — 2026-09-23` 줄 바로 앞에:

```markdown
## [8.2.3] — 2026-09-24

patch 인 이유 — 보안 수정이다. 절대 경로 항목만 있는 PATH 에서는 고르는 인터프리터가 전과 같다.

### Security

- **훅 해석기가 PATH 의 절대 경로가 아닌 항목을 통해 작업 디렉토리의 파일을 실행했다.** 빈 항목 · `.` · 상대 경로 · 빈 PATH 는 셸이 cwd 로 풀고, 훅의 cwd 는 사용자가 연 리포다. 그런 PATH 를 가진 사용자가 공격자가 만든 리포를 열면 `SessionStart` 에서 리포 안의 `python3` · `python3.<무엇이든>` 이 실행됐다(격리 재현). `scripts/devbrew-python.sh` 의 두 탐색 — 2단계 `python3` 와 3단계 `python3.*` 글롭 — 이 이제 절대 경로 항목만 본다. `hooks/hooks.json` 의 두 자리도 해석기를 bare `sh` 대신 `/bin/sh` 로 부른다 — bare `sh` 도 같은 탐색으로 cwd 의 `sh` 를 집었다.
- **대가** — PATH 에 상대 경로나 따옴표 안의 `~`(전개되지 않은 틸드)로 인터프리터를 두던 사용자는 훅이 그것을 못 찾는다. `SessionStart` 안내대로 `$DEVBREW_PYTHON` 에 절대 경로를 지정하라.
- **범위** — 훅 command 의 `sh` 탐색과 해석기가 인터프리터 파일을 고르는 탐색만 닫는다. 고른 인터프리터가 `#!/usr/bin/env` shim(pyenv · asdf)일 때 그 안의 탐색, SessionEnd 훅이 띄우는 `scripts/qg-worktree.sh`(`#!/usr/bin/env bash`), 그리고 그런 PATH 가 devbrew 밖에서 이미 여는 노출은 이 수정 밖이다. 설계 `docs/superpowers/specs/2026-09-23-python-resolver-absolute-path-only-design.md` 의 L4 · L6 · L7.
```

- [ ] **Step 4: spec-distill CHANGELOG**

`plugins/spec-distill/CHANGELOG.md` 의 `## [4.2.1] — 2026-09-23` 줄 바로 앞에:

```markdown
## [4.2.2] — 2026-09-24

patch 인 이유 — 보안 수정이다. 절대 경로 항목만 있는 PATH 에서는 고르는 인터프리터가 전과 같다.

### Security

- **훅 해석기가 PATH 의 절대 경로가 아닌 항목을 통해 작업 디렉토리의 파일을 실행했다.** 빈 항목 · `.` · 상대 경로 · 빈 PATH 는 셸이 cwd 로 풀고, 훅의 cwd 는 사용자가 연 리포다. 그런 PATH 를 가진 사용자가 공격자가 만든 리포를 열면 `SessionEnd` 에서 리포 안의 `python3` · `python3.<무엇이든>` 이 실행됐다(격리 재현). `scripts/devbrew-python.sh` 의 두 탐색 — 2단계 `python3` 와 3단계 `python3.*` 글롭 — 이 이제 절대 경로 항목만 본다. `hooks/hooks.json` 의 자리도 해석기를 bare `sh` 대신 `/bin/sh` 로 부른다 — bare `sh` 도 같은 탐색으로 cwd 의 `sh` 를 집었다.
- **대가** — PATH 에 상대 경로나 따옴표 안의 `~`(전개되지 않은 틸드)로 인터프리터를 두던 사용자는 훅이 그것을 못 찾는다. `$DEVBREW_PYTHON` 에 절대 경로를 지정하라.
- **범위** — 훅 command 의 `sh` 탐색과 해석기가 인터프리터 파일을 고르는 탐색만 닫는다. 고른 인터프리터가 `#!/usr/bin/env` shim(pyenv · asdf)일 때 그 안의 탐색과, 그런 PATH 가 devbrew 밖에서 이미 여는 노출은 이 수정 밖이다. 설계 `docs/superpowers/specs/2026-09-23-python-resolver-absolute-path-only-design.md` 의 L4 · L7.
```

- [ ] **Step 5: project-init CHANGELOG**

`plugins/project-init/CHANGELOG.md` 의 `## [4.0.0] — 2026-09-22` 줄 바로 앞에:

```markdown
## [4.0.1] — 2026-09-24

patch 인 이유 — 보안 수정이다. 절대 경로 항목만 있는 PATH 에서는 고르는 인터프리터가 전과 같다.

### Security

- **훅 해석기가 PATH 의 절대 경로가 아닌 항목을 통해 작업 디렉토리의 파일을 실행했다.** 빈 항목 · `.` · 상대 경로 · 빈 PATH 는 셸이 cwd 로 풀고, 훅의 cwd 는 사용자가 연 리포다. 그런 PATH 를 가진 사용자가 공격자가 만든 리포에서 Bash 도구를 쓰면 `PostToolUse` 에서 리포 안의 `python3` · `python3.<무엇이든>` 이 실행됐다(격리 재현). `scripts/devbrew-python.sh` 의 두 탐색 — 2단계 `python3` 와 3단계 `python3.*` 글롭 — 이 이제 절대 경로 항목만 본다. `hooks/hooks.json` 의 자리도 해석기를 bare `sh` 대신 `/bin/sh` 로 부른다 — bare `sh` 도 같은 탐색으로 cwd 의 `sh` 를 집었다.
- **대가** — PATH 에 상대 경로나 따옴표 안의 `~`(전개되지 않은 틸드)로 인터프리터를 두던 사용자는 훅이 그것을 못 찾는다. `$DEVBREW_PYTHON` 에 절대 경로를 지정하라.
- **범위** — 훅 command 의 `sh` 탐색과 해석기가 인터프리터 파일을 고르는 탐색만 닫는다. 고른 인터프리터가 `#!/usr/bin/env` shim(pyenv · asdf)일 때 그 안의 탐색과, 그런 PATH 가 devbrew 밖에서 이미 여는 노출은 이 수정 밖이다. 설계 `docs/superpowers/specs/2026-09-23-python-resolver-absolute-path-only-design.md` 의 L4 · L7.
```

- [ ] **Step 6: 확인**

Run: `bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1`
Expected: `Total: 27 | Pass: 27 | Fail: 0` (C2 가 맨 위 헤딩 = `plugin.json` 버전을 잰다)

- [ ] **Step 7: 커밋**

```bash
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md \
  plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
  plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(release): project-init 4.0.1 · quality-gates 8.2.3 · spec-distill 4.2.2

해석기 절대 경로 PATH 수정의 Security 항목. patch 인 이유 — 보안 수정이고
훅 command · 인자 · 출력 계약이 그대로다(설계 AC7). 사용자에게 보이는 변화는
비-절대 PATH 항목에만 인터프리터를 둔 경우뿐이다(설계 L1).

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git status --short
```

Expected: 커밋 파일 6개, 작업 트리 깨끗.

---

### Task 4: 검증 — 변이 · 형제 스위트 · 재현표 · 셸 셋 · base

**Files:** 없음(리포를 바꾸지 않는다). 스크래치 파일은 전부 `/Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/` 아래에 둔다 — 아래 `$V`.

**Interfaces:**
- Consumes: Task 1~3 의 커밋(HEAD).
- Produces: 검증 보고(PR 본문에 싣는다).

변이는 설계 Verification 2 대로 하되 **작업 트리가 아니라 `git archive HEAD` 스크래치 사본에서** 한다 — 설계가 요구한 「커밋 후 복원 · `git diff HEAD` 확인」의 목적(리포에 변이가 남지 않는다)을 복원 없이 구조로 만족한다.

- [ ] **Step 1: 변이 스크립트를 쓴다**

`$V/mutate.py`:

```python
#!/usr/bin/env python3
"""mutate.py <루트> <m1|m2|m3|m4> — 설계 Verification 2 의 변이 하나를 적용한다."""
import pathlib, sys

root, which = pathlib.Path(sys.argv[1]), sys.argv[2]
R = root / "shared/python/devbrew-python.sh"

def sub1(p, old, new):
    t = p.read_text(encoding="utf-8")
    assert t.count(old) == 1, (p, which, t.count(old))
    p.write_text(t.replace(old, new, 1), encoding="utf-8")

if which == "m1":    # 3단계를 원래 줄로
    sub1(R, '    case "$_dir" in /*) ;; *) continue ;; esac   # 빈 항목·`.`·상대 경로는 cwd 다 (2단계 주석)\n',
            '    [ -n "$_dir" ] || _dir="."\n')
elif which == "m2":  # 2단계를 셸 탐색으로
    sub1(R, 'if first_python3 && probe "$FIRST_PY3"; then\n  note_best\n  if satisfies; then exec "$FIRST_PY3" "$@"; fi\nfi\n',
            'if probe python3; then\n  note_best\n  if satisfies; then exec python3 "$@"; fi\nfi\n')
elif which == "m3":  # 첫 후보가 탈락하면 다음 python3 로
    sub1(R, '      FIRST_PY3="$_dir/python3"; return 0\n',
            '      probe "$_dir/python3" && satisfies || continue\n      FIRST_PY3="$_dir/python3"; return 0\n')
elif which == "m4":  # 훅 command 한 자리를 bare sh 로
    sub1(root / "plugins/spec-distill/hooks/hooks.json",
         '"command": "/bin/sh ${CLAUDE_PLUGIN_ROOT}/', '"command": "sh ${CLAUDE_PLUGIN_ROOT}/')
else:
    sys.exit("unknown mutation " + which)
print("mutated", which)
```

`$V/run.sh`:

```bash
#!/bin/bash
# HEAD 스크래치 사본마다: 추출 → (변이) → 락 → 새 단언(I/… · C/AC9)의 RED 집합과 그 밖의 RED
V=/Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify
[ -f "$V/tree.tar" ] || { echo "tree.tar 없음 — git archive 를 먼저"; exit 1; }
for m in clean m1 m2 m3 m4; do
  rm -rf "$V/tree"; mkdir -p "$V/tree"
  tar -xf "$V/tree.tar" -C "$V/tree" || exit 1
  if [ "$m" != clean ]; then python3 "$V/mutate.py" "$V/tree" "$m" >/dev/null || exit 1; fi
  out="$(bash "$V/tree/shared/tests/test_python_floor.sh" 2>&1)"
  echo "== $m  $(printf '%s\n' "$out" | tail -1)"
  printf '%s\n' "$out" | grep -E '✗ (I[:/]|C/AC9)' | cut -c1-110 | sed 's/^/   new: /'
  printf '%s\n' "$out" | grep '✗' | grep -vE '✗ (I[:/]|C/AC9)' | cut -c1-110 | sed 's/^/   other: /'
done
rm -rf "$V/tree"
```

- [ ] **Step 2: 변이를 돌린다**

Run: `git archive --format=tar -o /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/tree.tar HEAD` 그다음 `bash /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/run.sh`

Expected — 새 단언(`I/…` · `C/AC9`)의 RED 집합이 **정확히** 이것이다:

| 변이 | 새 단언 RED | 그 밖의 RED (판정 제외) |
|---|---|---|
| clean | 없음 — `Total: 173 \| Pass: 173 \| Fail: 0` | 없음 |
| m1 (3단계 원래 줄) | `I/AC1` 4줄(`:/bin` · `/bin::/usr/sbin` · `.:/bin` · `rel:/bin`) | `B/C10` 3줄 |
| m2 (2단계 셸 탐색) | `I/AC2` 6줄 + `I/AC4` 1줄 + `I/RF4` 1줄 | `B/C10` 3줄 |
| m3 (다음 python3 로 continue) | `I/AC8` 2줄 | `B/C10` 3줄 |
| m4 (spec-distill command 를 bare `sh`) | `C/AC9` 2줄(그 자리의 기대 형태 · 실행) | 없음 |

`B/C10` 은 정본만 변이해 사본과 어긋났다는 정상 신호다(설계 Verification 2). `I/RF4` 가 m2 에서 RED 인 것은 설계 L1 이 받아들인 동작 변경을 그 단언이 잡는다는 뜻이다 — 설계의 m2 RED 집합(AC2 여섯 + AC4)은 AC 단언만 센 것이고 RF 단언은 이 plan 이 더했다. 표와 한 줄이라도 다르면 멈추고 보고한다.

- [ ] **Step 3: 형제 스위트**

```bash
bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -1
bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | tail -1
python3 -m unittest plugins/project-init/tests/test_command_contract.py 2>&1 | tail -1
```

Expected: `Total: 200 | Pass: 200 | Fail: 0` · `Total: 27 | Pass: 27 | Fail: 0` · `Total: 268 | Pass: 268 | Fail: 0` · `OK`. 기준선보다 줄면(특히 guards 268) 새 축이 읽는 경로가 `SCANNED`/`# guards:` 와 어긋난 것이다 — 이 plan 은 새 경로를 읽지 않으므로 그대로여야 한다.

- [ ] **Step 4: 회고 재현표를 다시 돌린다 (설계 Verification 4)**

`$V/repro.sh`:

```bash
#!/bin/bash
# 회고 재현표(설계 Context/Why 2) 재실행 — 리포 밖 임시 디렉토리. 인자: 해석기 경로
R="$1"; [ -f "$R" ] || { echo "해석기 없음: $R"; exit 1; }
D="$(mktemp -d)" || exit 1
[ -n "$D" ] && [ -d "$D" ] || exit 1
mkdir -p "$D/rel"
for f in "$D/python3.99" "$D/python3" "$D/rel/python3" "$D/rel/python3.99"; do
  printf '#!/bin/sh\necho "CWD-HIT %s" >> "%s/hits"\n[ "$1" = "-c" ] && { echo "3 99"; exit 0; }\nexec "$@"\n' "$f" "$D" > "$f"
  chmod +x "$f"
done
printf '#!/bin/sh\necho TARGET-RAN\n' > "$D/target.sh"; chmod +x "$D/target.sh"
for P in ':/usr/bin:/bin' '/usr/bin::/bin' '.:/usr/bin:/bin' '/usr/bin:/bin:' 'rel:/usr/bin:/bin' '' '/usr/bin:/bin'; do
  rm -f "$D/hits"
  (cd "$D" && printf '{}' | env PATH="$P" /bin/sh "$R" --event SessionEnd --plugin qg --hook h "$D/target.sh" >/dev/null 2>&1)
  if [ -f "$D/hits" ]; then echo "PATH='$P' -> 실행됨: $(tr '\n' ' ' < "$D/hits")"; else echo "PATH='$P' -> 미접촉"; fi
done
rm -rf "$D"
```

Run: `bash /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/repro.sh /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/old-resolver.sh` 와 `bash /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/repro.sh <워크트리>/shared/python/devbrew-python.sh` — 이전 해석기는 `git show a9590ba8:shared/python/devbrew-python.sh > /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/old-resolver.sh` 로 뽑는다(파일 쓰기만, 작업 트리 무변경). 지금 해석기는 워크트리의 `shared/python/devbrew-python.sh` 절대 경로.

Expected — 이전: `:/usr/bin:/bin` · `/usr/bin::/bin` · `.:/usr/bin:/bin` · `rel:/usr/bin:/bin` · `''` 다섯이 `실행됨`, `/usr/bin:/bin:` 와 `/usr/bin:/bin` 이 `미접촉`. 지금: **일곱 전부 `미접촉`**.

- [ ] **Step 5: 셸 셋 (설계 Verification 5)**

`$V/shells.sh` — 축 I 의 `run_in` 이 해석기를 부르는 셸만 바꿔 스크래치 사본에서 돌린다:

```bash
#!/bin/bash
# 축 I 의 run_in 이 해석기를 부르는 셸만 바꿔 HEAD 스크래치 사본에서 돌린다.
V=/Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify
[ -f "$V/tree.tar" ] || { echo "tree.tar 없음 — git archive 를 먼저"; exit 1; }
for sh in /bin/dash /bin/ksh; do
  [ -x "$sh" ] || { echo "== $sh 없음"; continue; }
  rm -rf "$V/tree"; mkdir -p "$V/tree"
  tar -xf "$V/tree.tar" -C "$V/tree" || exit 1
  python3 - "$V/tree/shared/tests/test_python_floor.sh" "$sh" <<'PY'
import sys
p, sh = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read()
old = '(cd "$1" && printf \'%s\' "$PAY" | env PATH="$2" /bin/sh "$R" \\'
assert t.count(old) == 1, t.count(old)
open(p, "w", encoding="utf-8").write(t.replace(old, old.replace("/bin/sh", sh)))
PY
  out="$(bash "$V/tree/shared/tests/test_python_floor.sh" 2>&1)"
  echo "== $sh: $(printf '%s\n' "$out" | tail -1)"
  printf '%s\n' "$out" | grep '✗' | head
done
rm -rf "$V/tree"
```

Run: `bash /Users/jeonghokim/.claude/jobs/bd9390e0/tmp/verify/shells.sh`
Expected: `== /bin/dash: Total: 173 | Pass: 173 | Fail: 0` · `== /bin/ksh: Total: 173 | Pass: 173 | Fail: 0` (없는 셸은 `없음` 한 줄).

- [ ] **Step 6: 작업 트리가 깨끗한지 확인한다**

```bash
git status --short
git log --oneline f19184ac..HEAD
```

Expected: `git status` 출력 없음. plan 수정 커밋 1개(`docs(plan): …`) 위에 Task 1·2·3 의 커밋 3개(`fix(python)` · `fix(hooks)` · `chore(release)`). `f19184ac` 는 이 plan 의 첫 커밋이다.

- [ ] **Step 7: 머지 직전 base 재확인**

```bash
git fetch origin main
git log --oneline HEAD..origin/main
```

출력이 있으면 `git merge-tree --write-tree HEAD origin/main` 로 충돌을 보고, 그 커밋이 세 플러그인의 `plugin.json` 을 바꿨다면 Task 3 의 번호를 그 다음 patch 로 올려 다시 커밋한다 — 같은 버전 문자열은 충돌 없이 병합되므로 눈으로 확인해야 한다.

---

## 이 plan 이 끝난 뒤

`/qg` → PR(`fix/python-path-absolute-only` → `main`, 본문에 Task 4 의 변이 표 · 재현표) → 사용자가 `! gh pr merge <n> --merge`. 그 다음이 Tier ③(같은 테스트 파일이라 이 PR 머지 뒤).
