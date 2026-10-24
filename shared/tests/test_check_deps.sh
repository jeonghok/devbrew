#!/usr/bin/env bash
# shared/deps/check_deps.py measure · 플러그인 배포 링크 · 플러그인 의존 목록.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
S="$ROOT/shared/deps/check_deps.py"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
PY="$(command -v python3)"
PLUGINS="spec-distill quality-gates project-init plugin-audit"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/checkdeps.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
TMP="$(cd "$TMP" && pwd -P)" || exit 1
case "$TMP" in /*/checkdeps.*) ;; *) echo "임시 폴더 경로가 이상하다: $TMP" >&2; exit 1 ;; esac
trap 'rm -rf "$TMP"' EXIT

# ── 1. 배포 지점 넷이 정본을 가리키는 추적된 심볼릭 링크다 ─────────────────
for p in $PLUGINS; do
  link="plugins/$p/scripts/check_deps.py"
  mode="$(cd "$ROOT" && git ls-files -s -- "$link" | awk '{print $1}')"
  assert_eq "$mode" "120000" "$p: $link 가 인덱스에 심볼릭 링크(120000)로 있다"
  tgt=""
  [ -L "$ROOT/$link" ] && tgt="$(cd "$(dirname "$ROOT/$link")" && cd "$(dirname "$(readlink "$ROOT/$link")")" && pwd -P)/$(basename "$(readlink "$ROOT/$link")")"
  assert_eq "$tgt" "$S" "$p: 링크가 shared/deps/check_deps.py 를 가리킨다"
done

# ── 2. 플러그인마다 의존 목록이 있고, 행이 정해진 이름이고, 판 칸이 재어져 있다 ──
expected_names() {
  case "$1" in
    spec-distill)  echo "python git gh superpowers quality-gates claude-code" ;;
    quality-gates) echo "python git gh claude-code pr-review-toolkit" ;;
    project-init)  echo "python python-hook claude-code" ;;
    *)             echo "python claude-code" ;;
  esac
}
for p in $PLUGINS; do
  f="$ROOT/plugins/$p/dependencies.md"
  got="$(cd "$ROOT" && "$PY" -I -c 'import sys; sys.path.insert(0, "shared/deps"); import check_deps
rows = check_deps.read_table(sys.argv[1])
skipped = [r["name"] for r in rows if r["min_version"] == "—"]
print(" ".join(r["name"] for r in rows))
print("ok" if all(check_deps.version_triple(r["min_version"]) and len(r["measured_on"]) == 10 for r in rows if r["name"] not in skipped) else "unmeasured")
print(" ".join(skipped))' "$f" 2>&1)"
  names="$(printf '%s\n' "$got" | sed -n 1p)"
  measured="$(printf '%s\n' "$got" | sed -n 2p)"
  skipped="$(printf '%s\n' "$got" | sed -n 3p)"
  assert_eq "$names" "$(expected_names "$p")" "$p: dependencies.md 의 행 이름"
  assert_eq "$measured" "ok" "$p: 판을 잴 수 있는 모든 행의 최소 판 · 잰 날짜가 채워져 있다"
  case "$p" in
    quality-gates) assert_eq "$skipped" "pr-review-toolkit" "$p: 판 칸이 —(외부 플러그인)인 행은 이 하나뿐이다" ;;
    *)             assert_eq "$skipped" "" "$p: 판 칸이 —인 행이 없다" ;;
  esac
  if [ -n "$skipped" ]; then
    assert_eq "$(grep -cF -- '판을 잴 길이 없는 외부 플러그인 행만 판 칸 둘에 `—` 를 적는다' "$f")" "1" "$p: 건너뛴 행이 있으면 예외 문장이 한 번 있다"
  fi
  assert_file_grep "$f" "^plugin: ${p}\$" "$p: 머리말 plugin 이 플러그인 이름이다"
done

QGF="$ROOT/plugins/quality-gates/dependencies.md"
prt="$(cd "$ROOT" && "$PY" -I -c 'import sys; sys.path.insert(0, "shared/deps"); import check_deps
r = [x for x in check_deps.read_table(sys.argv[1]) if x["name"] == "pr-review-toolkit"][0]
print("기록" if r["strength"] == "기록" else "다른 강도")
print("있음" if "외부 플러그인" in r["when_missing"] and "재지 못한다" in r["when_missing"] else "없음")' "$QGF" 2>&1)"
assert_eq "$(printf '%s\n' "$prt" | sed -n 1p)" "기록" "qg: pr-review-toolkit 행은 강도 기록이다"
assert_eq "$(printf '%s\n' "$prt" | sed -n 2p)" "있음" "qg: pr-review-toolkit 행의 없을 때 칸이 외부 플러그인이라 재지 못한다고 말한다"
qgout="$(cd "$ROOT" && "$PY" plugins/quality-gates/scripts/check_deps.py entry --plugin-root plugins/quality-gates --need python,git,gh 2>&1)"; qgrc=$?
if [ "$qgrc" = "0" ]; then ok "qg: entry --need python,git,gh 는 새 행과 상관없이 통과한다"
elif printf '%s' "$qgout" | grep -q '필요'; then ok "qg: entry --need python,git,gh — 이 환경 판이 최소 판 밑이라 건너뜀(rc $qgrc)"
else no "qg: entry --need python,git,gh 가 새 행 때문에 멈췄다(rc $qgrc): $qgout"; fi

# ── 3. measure — 임시 플러그인 루트에서 표를 고치고 강도 · 없을 때 칸은 그대로 ──
mkdir -p "$TMP/bin" "$TMP/plugins/demo" "$TMP/plugins/quality-gates/.claude-plugin" \
  "$TMP/cache/superpowers/7.0.0/skills/writing-plans"
printf '#!/bin/sh\necho "git version 2.47.1.windows.2"\n' > "$TMP/bin/git"
printf '#!/bin/sh\necho "gh version 2.88.1 (2026-03-12)"\necho "https://github.com/cli/cli/releases/tag/v9.9.9"\n' > "$TMP/bin/gh"
printf '#!/bin/sh\necho "2.1.303 (Claude Code)"\n' > "$TMP/bin/claude"
chmod +x "$TMP/bin/git" "$TMP/bin/gh" "$TMP/bin/claude"
printf '{"name": "quality-gates", "version": "14.5.0"}\n' > "$TMP/plugins/quality-gates/.claude-plugin/plugin.json"

DEMO="$TMP/plugins/demo/dependencies.md"
write_demo() {   # write_demo [표 끝에 더할 줄]
  printf '%s\n' '---' 'type: devbrew-dependencies' 'plugin: demo' '---' '' '# demo 의존' '' \
    '| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |' \
    '|---|---|---|---|---|' \
    '| python | 1.0.0 | 2000-01-01 | 멈춤 | 파이썬 멈춘다 |' \
    '| git |  |  | 멈춤 | 깃 멈춘다 |' \
    '| gh | 1.0.0 | 2000-01-01 | 멈춤 | 지에이치 멈춘다 |' \
    '| superpowers |  |  | 알림 | 슈퍼 알린다 |' \
    '| quality-gates |  |  | 알림 | 큐지 알린다 |' \
    '| claude-code |  |  | 기록 | 기록만 |' \
    '| mystery | 0.0.1 | 2000-01-01 | 기록 | 모른다 |' > "$DEMO"
  [ -n "${1:-}" ] && printf '%s\n' "$1" >> "$DEMO"
  printf '%s\n' '' '뒷글은 그대로 둔다.' >> "$DEMO"
}
row() { grep -E "^\| $1 \|" "$DEMO"; }

write_demo
PYV="$("$PY" -I -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$ROOT/plugins/spec-distill/scripts/check_deps.py" measure \
  --plugin-root "$TMP/plugins/demo" --superpowers-base "$TMP/cache/superpowers/7.0.0/skills/writing-plans" \
  --today 2026-10-20)"; rc=$?
assert_eq "$rc" "0" "measure: rc 0 (링크로 실행)"
assert_eq "$(row python)" "| python | $PYV | 2026-10-20 | 멈춤 | 파이썬 멈춘다 |" "measure: python 은 돌린 python3 의 판"
assert_eq "$(row git)" "| git | 2.47.1 | 2026-10-20 | 멈춤 | 깃 멈춘다 |" "measure: git 은 git --version 의 숫자 셋"
assert_eq "$(row gh)" "| gh | 2.88.1 | 2026-10-20 | 멈춤 | 지에이치 멈춘다 |" "measure: gh 는 첫 줄의 숫자 셋(둘째 줄 아님)"
assert_eq "$(row superpowers)" "| superpowers | 7.0.0 | 2026-10-20 | 알림 | 슈퍼 알린다 |" "measure: superpowers 는 기준 폴더 경로의 판"
assert_eq "$(row quality-gates)" "| quality-gates | 14.5.0 | 2026-10-20 | 알림 | 큐지 알린다 |" "measure: quality-gates 는 레포 사본 plugin.json 의 판"
assert_eq "$(row claude-code)" "| claude-code | 2.1.303 | 2026-10-20 | 기록 | 기록만 |" "measure: claude-code 는 claude --version 의 판"
assert_eq "$(row mystery)" "| mystery | 0.0.1 | 2000-01-01 | 기록 | 모른다 |" "measure: 잴 방법이 없는 행은 그대로"
assert_contains "$out" "mystery 못 쟀다" "measure: 못 잰 행을 알린다"
assert_contains "$out" "잰 행 6개 · 못 잰 행 1개" "measure: 첫 줄에 잰 · 못 잰 개수"
assert_file_grep "$DEMO" "^뒷글은 그대로 둔다\\.\$" "measure: 표 밖 글은 그대로"
assert_file_grep "$DEMO" "^# demo 의존\$" "measure: 머리 글은 그대로"
"$PY" -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import check_deps; check_deps.read_table(sys.argv[2])' \
  "$ROOT/shared/deps" "$DEMO" >/dev/null 2>&1 \
  && ok "measure: 고친 파일이 다시 읽힌다" || no "measure: 고친 파일이 다시 읽히지 않는다"

# 재지 못하는 의존 — gh 가 PATH 에 없고 superpowers 경로를 받지 않았다. PATH 는 가짜 바이너리 폴더 하나뿐이다
# (/usr/bin 에 gh 가 깔린 기계에서도 gh 없음이다).
write_demo
rm -f "$TMP/bin/gh"
[ ! -e "$TMP/bin/gh" ] && ! PATH="$TMP/bin" command -v gh >/dev/null 2>&1 \
  && ok "전제: 가짜 바이너리 PATH 에 gh 가 없다" || no "전제: 가짜 바이너리 PATH 에 gh 가 있다"
out="$(PATH="$TMP/bin" "$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-10-21)"; rc=$?
assert_eq "$rc" "0" "measure(못 잰 행): rc 0"
assert_eq "$(row gh)" "| gh | 1.0.0 | 2000-01-01 | 멈춤 | 지에이치 멈춘다 |" "measure: gh 가 없으면 gh 행은 그대로"
assert_eq "$(row superpowers)" "| superpowers |  |  | 알림 | 슈퍼 알린다 |" "measure: 기준 폴더 경로가 없으면 superpowers 행은 그대로"
assert_eq "$(row git)" "| git | 2.47.1 | 2026-10-21 | 멈춤 | 깃 멈춘다 |" "measure: 잴 수 있는 행은 같은 실행에서 고친다"
assert_contains "$out" "gh 못 쟀다 — gh 가 없다" "measure: gh 없음을 알린다"
assert_contains "$out" "superpowers 못 쟀다" "measure: superpowers 를 못 쟀다고 알린다"
assert_contains "$out" "할 일: 못 잰 이유를 해결한 뒤" "measure: 끝에 할 일 하나"

# 판을 못 뽑는 출력 — 행은 그대로
printf '#!/bin/sh\necho "git version unknown"\n' > "$TMP/bin/git"
write_demo
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-10-21)"
assert_eq "$(row git)" "| git |  |  | 멈춤 | 깃 멈춘다 |" "measure: git 판을 못 뽑으면 행은 그대로"
assert_contains "$out" "판을 뽑지 못했다" "measure: 못 뽑았다고 알린다"

# 깨진 표 — rc 3 · 파일은 바뀌지 않는다
write_demo '| broken | 1.0.0 | 멈춤 |'
before="$(cat "$DEMO")"
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-10-21)"; rc=$?
assert_eq "$rc" "3" "깨진 표(칸 셋인 행): rc 3"
assert_contains "$out" "멈춤 — 의존 목록을 읽지 못했다" "깨진 표: 멈춤 줄"
assert_contains "$out" "3칸" "깨진 표: 몇 칸인지 보인다"
assert_eq "$(cat "$DEMO")" "$before" "깨진 표: 파일은 그대로"

# 표가 끝난 뒤에 표 줄이 또 있다 — 조용히 건너뛰지 않고 멈춘다
write_demo
printf '%s\n' '| gh | 1.0.0 | 2000-01-01 | 멈춤 | 둘째 표 |' >> "$DEMO"
before="$(cat "$DEMO")"
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-10-21)"; rc=$?
assert_eq "$rc" "3" "표 밖 표 줄: rc 3"
assert_eq "$(cat "$DEMO")" "$before" "표 밖 표 줄: 파일은 그대로"

# 머리말 없는 파일 — rc 3
printf '%s\n' '| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |' '|---|---|---|---|---|' '| python |  |  | 멈춤 | x |' > "$DEMO"
out="$("$PY" "$S" measure --plugin-root "$TMP/plugins/demo")"; rc=$?
assert_eq "$rc" "3" "머리말 없음: rc 3"

# ── 4. measure — python-hook 은 훅 해석기가 고른 해석기의 판, python 은 돌린 python3 의 판 ──
HOOKY="$TMP/plugins/hooky"
mkdir -p "$HOOKY/scripts" "$TMP/hookpy"
# 훅 해석기가 고를 가짜 판 — 돌린 python3 의 판($PYV)과 늘 다르게 도출한다(패치 숫자 + 1)
HOOKV="$(printf '%s' "$PYV" | awk -F. '{printf "%d.%d.%d", $1, $2, $3 + 1}')"
case "$HOOKV" in "$PYV"|""|*[!0-9.]*) no "전제: 가짜 훅 판($HOOKV)을 $PYV 와 다르게 도출하지 못했다" ;; *) ok "전제: 가짜 훅 판 $HOOKV ≠ 돌린 python3 $PYV" ;; esac
# 가짜 해석기 — 넘겨받은 인자를 적고, 탐침을 가짜 판 해석기로 exec 한다
printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "%s/resolver-args"\nshift 6\nexec "%s/hookpy/python3.12" "$@"\n' "$TMP" "$TMP" > "$HOOKY/scripts/devbrew-python.sh"
# 가짜 해석기 — 탐침 파일이 sys.version_info 를 묻는 .py 일 때만 판을 낸다
printf '#!/bin/sh\ncase "$1" in *.py) grep -q version_info "$1" && echo "%s" ;; esac\n' "$HOOKV" > "$TMP/hookpy/python3.12"
chmod +x "$TMP/hookpy/python3.12"
HDEMO="$HOOKY/dependencies.md"
write_hooky() {
  printf '%s\n' '---' 'type: devbrew-dependencies' 'plugin: hooky' '---' '' \
    '| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |' \
    '|---|---|---|---|---|' \
    '| python | 1.0.0 | 2000-01-01 | 멈춤 | 파이썬 멈춘다 |' \
    '| python-hook | 1.0.0 | 2000-01-01 | 멈춤 | 훅이 알림 없이 건너뛴다 |' > "$HDEMO"
}
hrow() { grep -E "^\| $1 \|" "$HDEMO"; }
write_hooky
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$ROOT/plugins/project-init/scripts/check_deps.py" measure \
  --plugin-root "$HOOKY" --today 2026-10-20)"; rc=$?
assert_eq "$rc" "0" "measure(python-hook): rc 0"
assert_eq "$(hrow python-hook)" "| python-hook | $HOOKV | 2026-10-20 | 멈춤 | 훅이 알림 없이 건너뛴다 |" \
  "measure: python-hook 은 훅 해석기가 고른 해석기의 판"
assert_eq "$(hrow python)" "| python | $PYV | 2026-10-20 | 멈춤 | 파이썬 멈춘다 |" "measure: python 은 돌린 python3 의 판(따로)"
[ "$(hrow python | cut -d'|' -f3)" != "$(hrow python-hook | cut -d'|' -f3)" ] \
  && ok "measure: python 과 python-hook 이 다른 값을 쓴다" || no "measure: python 과 python-hook 이 같은 값을 쓴다"
assert_eq "$(cat "$TMP/resolver-args" 2>/dev/null | cut -d' ' -f1-6)" "--event measure --plugin hooky --hook measure" \
  "measure: 해석기를 --event measure --plugin <머리말 plugin> --hook measure 로 부른다"
# 해석기가 죽는다 — rc 와 stderr 마지막 줄을 알리고, 꺼짐 · 해석기 없음으로 말하지 않는다
printf '#!/bin/sh\necho "앞 줄" >&2\necho "resolver boom" >&2\nexit 7\n' > "$HOOKY/scripts/devbrew-python.sh"
write_hooky
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$HOOKY" --today 2026-10-21)"; rc=$?
assert_eq "$rc" "0" "measure(해석기 실패): rc 0"
assert_eq "$(hrow python-hook)" "| python-hook | 1.0.0 | 2000-01-01 | 멈춤 | 훅이 알림 없이 건너뛴다 |" "measure: 해석기가 실패하면 python-hook 행은 그대로"
assert_contains "$out" "python-hook 못 쟀다 — 훅 해석기가 rc 7 로 끝났다: resolver boom" "measure: 해석기 실패의 rc 와 stderr 마지막 줄을 알린다"
assert_not_contains "$out" "kill switch" "measure: 해석기 실패를 꺼짐으로 말하지 않는다"
# 해석기가 판을 내지 않는다(꺼짐 · 바닥 만족 해석기 없음) — 행은 그대로
printf '#!/bin/sh\nexit 0\n' > "$HOOKY/scripts/devbrew-python.sh"
write_hooky
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$HOOKY" --today 2026-10-21)"; rc=$?
assert_eq "$rc" "0" "measure(해석기 침묵): rc 0"
assert_eq "$(hrow python-hook)" "| python-hook | 1.0.0 | 2000-01-01 | 멈춤 | 훅이 알림 없이 건너뛴다 |" "measure: 해석기가 판을 내지 않으면 python-hook 행은 그대로"
assert_contains "$out" "python-hook 못 쟀다 — 훅 해석기가 판을 내지 않았다" "measure: 해석기 침묵을 알린다"
# 해석기가 없다 — 행은 그대로
rm -f "$HOOKY/scripts/devbrew-python.sh"
write_hooky
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$HOOKY" --today 2026-10-21)"
assert_eq "$(hrow python-hook)" "| python-hook | 1.0.0 | 2000-01-01 | 멈춤 | 훅이 알림 없이 건너뛴다 |" "measure: 해석기가 없으면 python-hook 행은 그대로"
assert_contains "$out" "python-hook 못 쟀다 — 훅 해석기가 없다" "measure: 해석기 없음을 알린다"

# ── 5. entry — 진입의 의존 확인 ─────────────────────────────────────────────
EDEMO="$TMP/plugins/edemo"
mkdir -p "$EDEMO" "$TMP/ebin"
write_edemo() {   # write_edemo <python 최소 판> <git 최소 판> <gh 최소 판> [<python-hook 최소 판>]
  printf '%s\n' '---' 'type: devbrew-dependencies' 'plugin: edemo' '---' '' \
    '| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |' \
    '|---|---|---|---|---|' \
    "| python | $1 | 2026-10-20 | 멈춤 | x |" \
    "| git | $2 | 2026-10-20 | 멈춤 | x |" \
    "| gh | $3 | 2026-10-20 | 멈춤 | x |" \
    "| python-hook | ${4:-3.12.13} | 2026-10-20 | 멈춤 | 훅이 알림 없이 건너뛴다 |" \
    '| claude-code | 2.1.303 | 2026-10-20 | 기록 | x |' > "$EDEMO/dependencies.md"
}
run_entry() {   # run_entry <--need 값> → 출력, rc 는 $erc
  out="$(PATH="$TMP/ebin:/bin" "$PY" "$ROOT/plugins/spec-distill/scripts/check_deps.py" entry --plugin-root "$EDEMO" --need "$1")"; erc=$?
}
printf '#!/bin/sh\necho "git version 2.47.1 (Apple Git-157)"\n' > "$TMP/ebin/git"
printf '#!/bin/sh\necho "gh version 2.88.1 (2026-03-12)"\necho "https://github.com/cli/cli/releases/tag/v9.9.9"\n' > "$TMP/ebin/gh"
chmod +x "$TMP/ebin/git" "$TMP/ebin/gh"
write_edemo 1.0.0 2.47.1 2.88.1
run_entry python,git,gh
assert_eq "$erc" "0" "entry: 모두 맞으면 rc 0 (등호 경계 포함)"
assert_eq "$out" "[devbrew-deps] ok — python $PYV · git 2.47.1 · gh 2.88.1" "entry: ok 줄에 이름과 판"
# 낮은 git
printf '#!/bin/sh\necho "git version 2.0.0"\n' > "$TMP/ebin/git"
run_entry python,git
assert_eq "$erc" "3" "entry: git 이 낮으면 rc 3"
assert_contains "$out" "[devbrew-deps] 멈춤 — git 2.0.0 · 필요 2.47.1 이상 · git 을 설치하거나 업데이트한다" "entry: 낮은 판 · 필요 판 · 고치는 법"
# 판을 못 뽑는 git
printf '#!/bin/sh\necho "git version unknown"\n' > "$TMP/ebin/git"
run_entry python,git
assert_eq "$erc" "3" "entry: git 판을 못 뽑으면 rc 3"
assert_contains "$out" "[devbrew-deps] 멈춤 — git 판 못 읽음 · 필요 2.47.1 이상" "entry: 판 못 읽음을 보인다"
printf '#!/bin/sh\necho "git version 2.47.1"\n' > "$TMP/ebin/git"
# gh 없음 — --need 에 gh 가 있을 때만 멈춘다
rm -f "$TMP/ebin/gh"
run_entry python,git
assert_eq "$erc" "0" "entry: gh 를 쓰지 않는 진입은 gh 가 없어도 rc 0"
assert_not_contains "$out" "gh" "entry: gh 를 쓰지 않는 진입은 gh 를 말하지 않는다"
run_entry python,git,gh
assert_eq "$erc" "3" "entry: gh 를 쓰는 진입은 gh 가 없으면 rc 3"
assert_contains "$out" "[devbrew-deps] 멈춤 — gh 없음 · 필요 2.88.1 이상 · gh 를 설치하거나 업데이트한다(https://cli.github.com)" "entry: gh 없음 · 설치 방법"
# python — 돌린 python3 의 판과 python 행을 비교한다 · python-hook 행은 보지 않는다
write_edemo 99.0.0 2.47.1 2.88.1 1.0.0
run_entry python
assert_eq "$erc" "3" "entry: python3 가 python 행보다 낮으면 rc 3"
assert_contains "$out" "[devbrew-deps] 멈춤 — python $PYV · 필요 99.0.0 이상" "entry: python 의 있는 판 · 필요 판"
write_edemo 1.0.0 2.47.1 2.88.1 99.0.0
run_entry python
assert_eq "$erc" "0" "entry --need python: python-hook 행(99.0.0)을 보지 않는다"
assert_not_contains "$out" "python-hook" "entry --need python: python-hook 을 말하지 않는다"
# 표에 없는 이름 · 비운 최소 판 · 깨진 표 — 멈춘다
run_entry python,svn
assert_eq "$erc" "3" "entry: 표에 없는 이름이면 rc 3"
assert_contains "$out" "svn 행이 없다" "entry: 없는 행을 말한다"
write_edemo 1.0.0 "" 2.88.1
run_entry git
assert_eq "$erc" "3" "entry: 최소 판이 빈 행이면 rc 3"
printf 'garbage\n' > "$EDEMO/dependencies.md"
run_entry python
assert_eq "$erc" "3" "entry: 의존 목록이 깨졌으면 rc 3"
assert_contains "$out" "멈춤 — 의존 목록을 읽지 못했다" "entry: 깨진 목록의 멈춤 줄"
err="$("$PY" "$S" entry --plugin-root "$EDEMO" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "entry: --need 없음은 rc 2"
err="$("$PY" "$S" entry --plugin-root "$EDEMO" --need "python,,git" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "entry: 빈 이름이 낀 --need 는 rc 2"

# ── 6. superpowers — 불러온 skill 의 기준 폴더 경로의 판을 표의 판과 비교해 알리기만 한다 ──
SPDEMO="$TMP/plugins/spdemo"
mkdir -p "$SPDEMO"
write_spdemo() {   # write_spdemo <superpowers 최소 판>
  printf '%s\n' '---' 'type: devbrew-dependencies' 'plugin: spdemo' '---' '' \
    '| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |' \
    '|---|---|---|---|---|' \
    '| python | 1.0.0 | 2026-10-20 | 멈춤 | x |' \
    "| superpowers | $1 | 2026-10-20 | 알림 | x |" > "$SPDEMO/dependencies.md"
}
run_sp() {   # run_sp [--base 값] → 출력 $out · rc $src (링크로 돌린다)
  out="$("$PY" "$ROOT/plugins/spec-distill/scripts/check_deps.py" superpowers --plugin-root "$SPDEMO" "$@")"; src=$?
}
SPBASE="$TMP/cache/superpowers/7.0.0/skills/writing-plans"
UNKNOWN="[devbrew-deps] superpowers 판을 확인하지 못했다"
write_spdemo 7.0.0
run_sp --base "$SPBASE"
assert_eq "$src" "0" "superpowers 같음: rc 0"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "[devbrew-deps] superpowers 7.0.0 — 검증한 판과 같다" "superpowers: 경로 판 = 표 판이면 「같다」"
assert_not_contains "$out" "다르다" "superpowers 같음: 「다르다」를 말하지 않는다"
write_spdemo 6.4.1
run_sp --base "$SPBASE"
assert_eq "$src" "0" "superpowers 다름(표가 낮다): rc 0 — 멈추지 않는다"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" \
  "[devbrew-deps] 알림 — 설치된 superpowers 7.0.0 이 검증한 판 6.4.1 과 다르다. 넘김 결과는 돌아온 뒤 대조한다" \
  "superpowers: 경로 판 ≠ 표 판이면 「다르다」와 두 판"
write_spdemo 8.0.0
run_sp --base "$SPBASE"
assert_eq "$src" "0" "superpowers 다름(표가 높다): rc 0"
assert_contains "$out" "설치된 superpowers 7.0.0 이 검증한 판 8.0.0 과 다르다" "superpowers: 높고 낮음이 아니라 같음을 잰다(표가 높아도 「다르다」)"
write_spdemo 7.0.0
run_sp --base ""
assert_eq "$src" "0" "superpowers 빈 경로: rc 0"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: 빈 경로면 「확인하지 못했다」"
run_sp
assert_eq "$src" "0" "superpowers --base 없음: rc 0"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: --base 가 없으면 「확인하지 못했다」"
run_sp --base "$TMP/cache/superpowers/skills/writing-plans"
assert_eq "$src" "0" "superpowers 판 없는 경로: rc 0"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: 경로에 판이 없으면 「확인하지 못했다」"
assert_contains "$out" "superpowers/<판>/skills 꼴이 없다" "superpowers: 판 없는 경로의 이유를 둘째 줄에 보인다"
run_sp --base "$TMP/cache/superpowers/latest/skills/writing-plans"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: 판 자리가 판이 아니면 「확인하지 못했다」"
printf 'garbage\n' > "$SPDEMO/dependencies.md"
run_sp --base "$SPBASE"
assert_eq "$src" "0" "superpowers 깨진 의존 목록: rc 0 — 멈추지 않는다"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: 의존 목록이 깨졌으면 「확인하지 못했다」"
write_edemo 1.0.0 2.47.1 2.88.1
out="$("$PY" "$S" superpowers --plugin-root "$EDEMO" --base "$SPBASE")"; src=$?
assert_eq "$src" "0" "superpowers 행 없음: rc 0"
assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "$UNKNOWN" "superpowers: 표에 superpowers 행이 없으면 「확인하지 못했다」"
err="$("$PY" "$S" superpowers 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "superpowers: --plugin-root 없음은 rc 2"
assert_contains "$err" "--plugin-root" "superpowers: rc 2 의 사유가 빠진 --plugin-root 다(모르는 하위 명령이 아니다)"

# 사용법
err="$("$PY" "$S" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "하위 명령 없음: rc 2"
assert_contains "$err" "usage: check_deps.py" "하위 명령 없음: 사용법을 보인다"
err="$("$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-13-40 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "날짜 꼴이 틀림: rc 2"
assert_contains "$err" "YYYY-MM-DD" "날짜 꼴이 틀림: 이유를 보인다"

finish
