#!/usr/bin/env bash
# test_entry_safety_e1_e6.sh — 진입·안전 요구 E1~E6 (qg v10 spec §요구 목록).
#
# 각 요구는 「지우면 조용히 통과하는 것」을 막는다. 단언 이름이 요구 번호로 시작한다.
# E3 · E4 는 그 요구를 이미 재는 테스트를 돌려 결과를 받는다(같은 검사를 두 벌 두지 않는다).
# 모든 fixture 는 mktemp 아래에서 돈다 — 실제 리포에서 setup · GC · git 을 돌리지 않는다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
GC="$PLUGIN_ROOT/scripts/qg-gc.py"
TH="$PLUGIN_ROOT/scripts/topic-head.sh"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset CLAUDE_CODE_SESSION_ID DEVBREW_QUALITY_GATES_DISABLE DEVBREW_SKIP_HOOKS \
      DEVBREW_QUALITY_GATES_TTL_HOURS DEVBREW_QUALITY_GATES_GC_VERBOSE

TMP="$(mktemp -d)"
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "mktemp -d 실패 — 아무것도 재지 않았다"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

age() {   # age <경로…> — mtime 을 48시간 전으로 (TTL 24h 를 넘긴다)
  python3 - "$@" <<'PY'
import os, sys, time
t = time.time() - 48 * 3600
for p in sys.argv[1:]:
    os.utime(p, (t, t))
PY
}
stale_session() {   # stale_session <작업 디렉토리> <sid> — 마커가 있는 만료 세션 폴더
  mkdir -p "$1/.claude/quality-gates/$2"
  : > "$1/.claude/quality-gates/$2/pipeline.md"
  age "$1/.claude/quality-gates/$2/pipeline.md" "$1/.claude/quality-gates/$2"
}

note "── E1: 빈 SID · 패턴 밖 SID 로 폴더를 지우지 않는다"
# `../keep` 은 state root 기준으로 `.claude/keep` 을 가리킨다 — 카나리를 바로 그 자리에 둔다.
W="$TMP/e1"; mkdir -p "$W/.claude/quality-gates/siblingsess01" "$W/.claude/keep"
: > "$W/.claude/quality-gates/siblingsess01/pipeline.md"
: > "$W/.claude/keep/canary"
for bad in "short" "../keep" "abc/defghij" "abc defghij" "$(printf 'abcdefgh\nijkl')"; do
  (cd "$W" && "$SETUP" --session-id "$bad" >/dev/null 2>&1); rc=$?
  assert_eq "$rc" "1" "E1: 패턴 밖 SID $(printf '%q' "$bad") 는 exit 1"
done
(cd "$W" && CLAUDE_CODE_SESSION_ID="" "$SETUP" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "1" "E1: 빈 SID 는 exit 1"
[ -f "$W/.claude/keep/canary" ] && ok "E1: 거부된 실행 뒤 「../keep」 이 가리키는 폴더가 그대로다" || no "E1: 거부된 실행이 state root 밖 폴더를 지웠다"
[ -f "$W/.claude/quality-gates/siblingsess01/pipeline.md" ] \
  && ok "E1: 거부된 실행 뒤 형제 세션 폴더가 그대로다" || no "E1: 형제 세션 폴더가 사라졌다"

# 양의 짝 — 패턴을 통과한 SID 는 자기 폴더만 지우고 다시 만든다(그래서 위 거부가 공허하지 않다).
SID="e1session0001"
(cd "$W" && "$SETUP" --session-id "$SID" >/dev/null 2>&1)
: > "$W/.claude/quality-gates/$SID/leftover.md"
(cd "$W" && "$SETUP" --session-id "$SID" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "0" "E1: 같은 세션의 다시 실행은 exit 0 (활성 파이프라인 거부가 없다)"
[ ! -e "$W/.claude/quality-gates/$SID/leftover.md" ] \
  && ok "E1: 다시 실행이 자기 세션 폴더를 지우고 새로 만든다" || no "E1: 이전 실행의 파일이 남았다"
[ -f "$W/.claude/quality-gates/$SID/pipeline.md" ] && ok "E1: 새 pipeline.md 가 있다" || no "E1: pipeline.md 가 없다"
[ -f "$W/.claude/quality-gates/siblingsess01/pipeline.md" ] \
  && ok "E1: 다시 실행 뒤에도 형제 세션 폴더가 그대로다" || no "E1: 다시 실행이 형제 폴더를 지웠다"
: > "$W/.claude/quality-gates/$SID/kept-by-ensure.md"
(cd "$W" && "$SETUP" --ensure --session-id "$SID" >/dev/null 2>&1)
[ -f "$W/.claude/quality-gates/$SID/kept-by-ensure.md" ] \
  && ok "E1: --ensure 는 있는 세션 폴더를 지우지 않는다" || no "E1: --ensure 가 세션 폴더를 지웠다"

# state root 가 링크로 밖에 풀리면 지우지 않는다.
W2="$TMP/e1link"; OUT="$TMP/e1outside"
mkdir -p "$W2/.claude" "$OUT/qgroot/$SID"
: > "$OUT/qgroot/$SID/keep.md"
ln -s "$OUT/qgroot" "$W2/.claude/quality-gates"
err="$(cd "$W2" && "$SETUP" --session-id "$SID" 2>&1 >/dev/null)"
[ -f "$OUT/qgroot/$SID/keep.md" ] \
  && ok "E1: 링크로 밖에 풀린 state root 아래 세션 폴더를 지우지 않는다" || no "E1: 링크 너머 폴더를 지웠다"
assert_contains "$err" "지우지 않는다" "E1: 지우지 않은 사실을 한 줄로 알린다"

# 거부했으면 링크 너머에 아무것도 쓰지 않는다 — pipeline.md 를 그 길로 쓰면 거부가 공허하다.
snap() { (cd "$1" && find . | LC_ALL=C sort); }   # snap <디렉토리> — 트리 목록
W2b="$TMP/e1linkb"; OUTb="$TMP/e1outsideb"
mkdir -p "$W2b/.claude" "$OUTb/qgroot/$SID"
: > "$OUTb/qgroot/$SID/keep.md"
ln -s "$OUTb/qgroot" "$W2b/.claude/quality-gates"
before="$(snap "$OUTb")"
(cd "$W2b" && "$SETUP" --session-id "$SID" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "1" "E1: 링크로 밖에 풀린 state root 는 exit 1 로 거부한다"
assert_eq "$(snap "$OUTb")" "$before" "E1: 거부된 실행이 링크 너머에 아무 파일도 쓰지 않는다 (pipeline.md 포함)"

# 세션 폴더 자신이 링크여도 같다.
W2c="$TMP/e1linkc"; OUTc="$TMP/e1outsidec"
mkdir -p "$W2c/.claude/quality-gates" "$OUTc"
: > "$OUTc/keep.md"
ln -s "$OUTc" "$W2c/.claude/quality-gates/$SID"
before="$(snap "$OUTc")"
(cd "$W2c" && "$SETUP" --session-id "$SID" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "1" "E1: 세션 폴더 자신이 링크면 exit 1 로 거부한다"
assert_eq "$(snap "$OUTc")" "$before" "E1: 링크인 세션 폴더 너머에 아무 파일도 쓰지 않는다"

# `.claude` 자체가 리포 밖을 가리키는 링크 — 안에 quality-gates 가 아직 없다(루프의 .claude 항목만 잡는 자리).
W2d="$TMP/e1linkd"; OUTd="$TMP/e1outsided"
mkdir -p "$W2d" "$OUTd"
: > "$OUTd/keep.md"
ln -s "$OUTd" "$W2d/.claude"
before="$(snap "$OUTd")"
err="$(cd "$W2d" && "$SETUP" --session-id "$SID" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "E1: .claude 자체가 밖을 가리키는 링크면 exit 1 로 거부한다"
assert_eq "$(snap "$OUTd")" "$before" "E1: 링크인 .claude 너머에 아무 파일도 쓰지 않는다"
assert_contains "$err" "지우지 않는다" "E1: .claude 링크 거부도 한 줄로 알린다"

# kill switch — setup 직접 호출도 막는다. (test_kill_switches.py 의
# test_skill_setup_qg_honors_disable_kill_switch 를 이어받는 자리: 그 파일이 지워져도 이 단언이 남는다.)
WK="$TMP/ks"; mkdir -p "$WK"
(cd "$WK" && DEVBREW_QUALITY_GATES_DISABLE=1 "$SETUP" --session-id "kssession0001" >/dev/null 2>&1); rc=$?
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "E1(kill switch): DEVBREW_QUALITY_GATES_DISABLE=1 이면 setup 이 0 이 아닌 코드로 끝난다"
[ ! -e "$WK/.claude/quality-gates/kssession0001" ] \
  && ok "E1(kill switch): 스위치가 켜져 있으면 세션 폴더를 만들지 않는다" || no "E1(kill switch): 스위치가 켜졌는데 세션 폴더가 생겼다"
(cd "$WK" && "$SETUP" --session-id "kssession0001" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "0" "E1(kill switch): 스위치가 없으면 같은 호출이 폴더를 만든다 (양의 짝)"

note "── E1(비-세션 폴더): SID 패턴을 통과해도 세션 폴더가 아니면 지우지 않는다"
refusal_check() {   # refusal_check <라벨> <작업 디렉토리> <sid> [setup 추가 인자…] — rc 1 · stderr 정확히 한 줄 · 트리 불변
  local label="$1" w="$2" sid="$3"; shift 3
  local before after e rc
  before="$(snap "$w")"
  e="$(cd "$w" && "$SETUP" "$@" --session-id "$sid" 2>&1 >/dev/null)"; rc=$?
  after="$(snap "$w")"
  assert_eq "$rc" "1" "E1: $label — exit 1"
  assert_eq "$(printf '%s\n' "$e" | grep -c .)" "1" "E1: $label — stderr 가 정확히 한 줄이다"
  assert_eq "$after" "$before" "E1: $label — 아무것도 지우거나 쓰지 않았다"
}
for reserved in worktrees baseline-cache; do
  WR="$TMP/e1res-$reserved"
  mkdir -p "$WR/.claude/quality-gates/$reserved/qg-baseline-abc"
  : > "$WR/.claude/quality-gates/$reserved/qg-baseline-abc/file"
  refusal_check "예약 이름 $reserved" "$WR" "$reserved"
  refusal_check "예약 이름 $reserved (--ensure)" "$WR" "$reserved" --ensure
  [ ! -e "$WR/.claude/quality-gates/$reserved/pipeline.md" ] \
    && ok "E1: 예약 이름 $reserved 아래에 pipeline.md 를 심지 않는다" || no "E1: 예약 폴더에 pipeline.md 가 생겼다"
  # 마커 가드가 못 막는 모양 — 이미 마커가 심긴 예약 폴더(이름 검사만이 막는다).
  WR2="$TMP/e1res2-$reserved"
  mkdir -p "$WR2/.claude/quality-gates/$reserved/keepdir"
  : > "$WR2/.claude/quality-gates/$reserved/pipeline.md"
  refusal_check "예약 이름 $reserved (마커가 이미 있어도)" "$WR2" "$reserved"
done
WM="$TMP/e1nomarker"
mkdir -p "$WM/.claude/quality-gates/unrelatedfolder1"
: > "$WM/.claude/quality-gates/unrelatedfolder1/notes.txt"
refusal_check "마커 없는 비어 있지 않은 폴더" "$WM" "unrelatedfolder1"
WF="$TMP/e1notdir"
mkdir -p "$WF/.claude/quality-gates"
: > "$WF/.claude/quality-gates/afilenotdir1"
refusal_check "폴더가 아닌 항목" "$WF" "afilenotdir1"
# 양의 짝 — 이전 실행의 세션 폴더(마커 있음)는 다시 만든다. 빈 폴더도 같다.
WP="$TMP/e1prev"
mkdir -p "$WP/.claude/quality-gates/prevsession01" "$WP/.claude/quality-gates/emptysession1"
: > "$WP/.claude/quality-gates/prevsession01/pipeline.md"; : > "$WP/.claude/quality-gates/prevsession01/extra.md"
(cd "$WP" && "$SETUP" --session-id prevsession01 >/dev/null 2>&1); rc=$?
assert_eq "$rc" "0" "E1: 이전 실행(pipeline.md 있음)의 세션 폴더는 다시 만든다"
[ ! -e "$WP/.claude/quality-gates/prevsession01/extra.md" ] && ok "E1: 이전 실행의 파일을 지웠다" || no "E1: 이전 실행의 파일이 남았다"
(cd "$WP" && "$SETUP" --session-id emptysession1 >/dev/null 2>&1); rc=$?
assert_eq "$rc" "0" "E1: 빈 폴더는 다시 만든다"
# 링크 거부들도 정확히 한 줄이다.
refusal_check "링크로 풀린 state root" "$W2b" "$SID"
refusal_check "링크인 세션 폴더" "$W2c" "$SID"
refusal_check "링크인 .claude" "$W2d" "$SID"
# setup 의 마커 목록은 qg-gc.py 와 같아야 한다.
gcm="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import importlib.util as u; s=u.spec_from_file_location("qg_gc", sys.argv[1]+"/qg-gc.py"); m=u.module_from_spec(s); s.loader.exec_module(m); print(" ".join(sorted(m.SESSION_MARKERS + m.LEGACY_SESSION_MARKERS)))' "$PLUGIN_ROOT/scripts")"
sm="$(sed -n 's/^SESSION_MARKERS=(\(.*\))$/\1/p' "$SETUP" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
assert_eq "$sm" "$gcm" "E1: setup 의 SESSION_MARKERS 가 qg-gc.py 의 마커 합집합과 같다"

note "── E2: 플러그인 루트를 cwd 로 대체하지 않는다"
W="$TMP/e2"; mkdir -p "$W/scripts"
printf 'open("E2-CANARY", "w").close()\n' > "$W/scripts/qg-gc.py"
stale_session "$W" "stalee2sess01"
(cd "$W" && "$SETUP" --session-id "e2session0001" >/dev/null 2>&1)
[ ! -e "$W/E2-CANARY" ] && ok "E2: cwd 의 scripts/qg-gc.py 를 실행하지 않는다" || no "E2: cwd 의 스크립트가 돌았다"
[ ! -e "$W/.claude/quality-gates/stalee2sess01" ] \
  && ok "E2: 플러그인 자신의 GC 가 돌았다 (양의 짝 — 만료 폴더가 회수됐다)" || no "E2: 플러그인 GC 가 돌지 않았다"

note "── E3: skill · 커맨드 본문에 셸 위치 인자를 쓰지 않는다"
scanned="$(bash "$ROOT/shared/tests/test_skill_body_no_positional_tokens.sh" --emit-scanned)"
for f in plugins/quality-gates/commands/qg.md plugins/quality-gates/skills/quality-pipeline/SKILL.md; do
  printf '%s\n' "$scanned" | grep -qxF "$f" \
    && ok "E3: $f 가 위치 인자 검사의 코퍼스에 있다" || no "E3: $f 가 위치 인자 검사에서 빠졌다"
done
bash "$ROOT/shared/tests/test_skill_body_no_positional_tokens.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "E3: 위치 인자 검사(shared/tests/test_skill_body_no_positional_tokens.sh)가 통과한다"

note "── E4: GC 는 루트 탈출 · 심링크 루트를 거부하고 안전 삭제한다"
out="$(cd "$SCRIPT_DIR" && python3 -m unittest test_qg_gc.QgGcRootSafetyTest 2>&1)"; rc=$?
assert_eq "$rc" "0" "E4: test_qg_gc.QgGcRootSafetyTest 가 통과한다"
assert_grep "$out" '^Ran [1-9][0-9]* tests' "E4: 루트 안전 테스트가 실제로 돌았다 (0건이 아니다)"

note "── E5: kill switch 는 전체 토큰으로 일치시킨다"
e5() {   # e5 <DEVBREW_SKIP_HOOKS 값> → 만료 세션 폴더가 남았으면 kept, 지워졌으면 gone
  local w="$TMP/e5-$RANDOM"
  stale_session "$w" "stalee5sess01"
  (cd "$w" && DEVBREW_SKIP_HOOKS="$1" python3 "$GC" >/dev/null 2>&1)
  if [ -d "$w/.claude/quality-gates/stalee5sess01" ]; then echo kept; else echo gone; fi
}
assert_eq "$(e5 'quality-gates:qg-gc')" "kept" "E5: 전체 토큰 quality-gates:qg-gc 는 GC 를 끈다"
assert_eq "$(e5 ' quality-gates:qg-gc ,other:x')" "kept" "E5: 앞뒤 공백 · 쉼표 목록 안의 전체 토큰도 끈다"
assert_eq "$(e5 'quality-gates:qg')" "gone" "E5: 부분 일치 quality-gates:qg 는 끄지 않는다"
assert_eq "$(e5 'quality-gates:qg-gc:sub')" "gone" "E5: 더 긴 토큰 quality-gates:qg-gc:sub 는 끄지 않는다"
assert_eq "$(e5 '')" "gone" "E5: 스위치가 없으면 GC 가 돈다 (양의 짝)"

note "── E6: 리뷰 대상 리포의 git 훅을 끈다 (core.hooksPath)"
R="$TMP/e6"; M="$TMP/e6-marks"; mkdir -p "$R" "$M"
(
  cd "$R" || exit 1
  git init -q .; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; git add f.txt; git commit -qm r0
  mkdir -p docs; echo '# design' > docs/x-design.md; git add docs/x-design.md; git commit -qm doc
  mkdir -p hooks
  for h in post-index-change post-checkout reference-transaction pre-auto-gc; do
    printf '#!/bin/sh\necho %s >> %s/ran\n' "$h" "$M" > "hooks/$h"; chmod +x "hooks/$h"
  done
  git add hooks; git commit -qm hooks
  git config core.hooksPath hooks
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt
  git commit -qm "a1

Spec: docs/x-design.md#e6"
  echo dirty > wip.txt
) >/dev/null 2>&1
rm -f "$M/ran"
out="$(cd "$R" && DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$TH" "e6session0001" 2>/dev/null)"
assert_eq "$(field status "$out")" "ok" "E6: topic-head 가 봉인 · 합치기까지 돌았다 (status: ok)"
assert_eq "$([ -e "$M/ran" ] && cat "$M/ran" || echo none)" "none" "E6: topic-head 가 저장소 git 훅을 하나도 돌리지 않는다"
(cd "$R" && git add wip.txt) >/dev/null 2>&1
assert_grep "$([ -e "$M/ran" ] && cat "$M/ran" || echo none)" '^post-index-change$' \
  "E6: 같은 fixture 에서 git add 를 직접 하면 훅이 돈다 (양의 짝)"

finish
