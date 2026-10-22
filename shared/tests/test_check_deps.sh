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
    quality-gates) echo "python git gh claude-code" ;;
    *)             echo "python claude-code" ;;
  esac
}
for p in $PLUGINS; do
  f="$ROOT/plugins/$p/dependencies.md"
  got="$(cd "$ROOT" && "$PY" -I -c 'import sys; sys.path.insert(0, "shared/deps"); import check_deps
rows = check_deps.read_table(sys.argv[1])
print(" ".join(r["name"] for r in rows))
print("ok" if all(check_deps.version_triple(r["min_version"]) and len(r["measured_on"]) == 10 for r in rows) else "unmeasured")' "$f" 2>&1)"
  names="$(printf '%s\n' "$got" | sed -n 1p)"
  measured="$(printf '%s\n' "$got" | sed -n 2p)"
  assert_eq "$names" "$(expected_names "$p")" "$p: dependencies.md 의 행 이름"
  assert_eq "$measured" "ok" "$p: 모든 행의 최소 판 · 잰 날짜가 채워져 있다"
  assert_file_grep "$f" "^plugin: ${p}\$" "$p: 머리말 plugin 이 플러그인 이름이다"
done

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

# 재지 못하는 의존 — gh 가 PATH 에 없고 superpowers 경로를 받지 않았다
write_demo
rm -f "$TMP/bin/gh"
out="$(PATH="$TMP/bin:/usr/bin:/bin" "$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-10-21)"; rc=$?
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

# 사용법
err="$("$PY" "$S" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "하위 명령 없음: rc 2"
assert_contains "$err" "usage: check_deps.py" "하위 명령 없음: 사용법을 보인다"
err="$("$PY" "$S" measure --plugin-root "$TMP/plugins/demo" --today 2026-13-40 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "2" "날짜 꼴이 틀림: rc 2"
assert_contains "$err" "YYYY-MM-DD" "날짜 꼴이 틀림: 이유를 보인다"

finish
