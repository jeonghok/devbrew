#!/usr/bin/env bash
# test_e2e_state.sh — scripts/e2e-state.sh (설계 v10 §4 · X1 · X2 · X4 · X5 · AC17 · AC18 · AC20 · AC20a · AC21).
#
# 각 케이스는 mktemp 아래 일회용 git 리포에서 돈다 — 라이브 리포의 워킹트리를 건드리지 않는다.
# 부팅 케이스가 띄우는 프로세스는 이름에 고유 표지(`$MARK`)를 실어, 정지 뒤 남은 것이 없는지를
# 프로세스 그룹이 아니라 **이름**으로 다시 센다(그룹 계수만 보면 그룹을 벗어난 자식을 못 본다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ES="$PLUGIN_ROOT/scripts/e2e-state.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_QUALITY_GATES_DISABLE DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST
MARK="300.$$"   # 띄우는 sleep 의 인자 — 프로세스 명령줄에 남는 고유 표지
TMPS=()
cleanup() {
  pkill -f "sleep $MARK" 2>/dev/null
  local d; for d in "${TMPS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done
}
trap cleanup EXIT

new_repo() {   # stdout = 일회용 리포 경로(커밋 하나 · 추적 파일 a.txt · 무시 규칙 ignored/ · 기존 untracked u.txt)
  local d; d="$(cd "$(mktemp -d)" && pwd -P)"; TMPS+=("$d")
  git -C "$d" init -q -b main
  printf 'a\n' >"$d/a.txt"; printf 'ignored/\n' >"$d/.gitignore"
  git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m init
  printf 'u1\n' >"$d/u.txt"
  mkdir -p "$d/.claude/quality-gates/sid12345"
  printf '%s\n' "$d"
}

fp() { (cd "$1" && bash "$ES" fingerprint --out "$2" >/dev/null); }
cmp_out() { (cd "$1" && bash "$ES" compare "$2" "$3"); }

# ── X2 · AC17 — 지문은 HEAD · 추적 파일 · 무시되지 않는 untracked 를 본다 ─────────────
case_X2_AC17_unchanged_is_same() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "0" "X2: 바뀐 것이 없으면 exit 0"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "same" "X2: 마지막 줄이 same"
}

case_X2_AC17_tracked_edit_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'changed\n' >>"$d/a.txt"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: 추적 파일 변경은 exit 1"
  assert_grep "$out" '^changed: a\.txt$' "AC17: 바뀐 추적 파일이 경로로 나온다"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "changed: 1" "AC17: 마지막 줄이 changed: 1"
}

case_X2_AC17_head_move_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m moved
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: HEAD 이동은 exit 1"
  assert_grep "$out" '^changed: HEAD \(' "AC17: HEAD 이동이 나온다"
}

case_X2_AC17_existing_untracked_edit_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'u2\n' >"$d/u.txt"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: 이미 있던 untracked 소스의 내용 변경은 exit 1"
  assert_grep "$out" '^changed: u\.txt$' "AC17: 그 untracked 경로가 나온다"
}

case_X2_untracked_add_and_delete_invalidate() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'n\n' >"$d/new.txt"; rm -f "$d/u.txt"; fp "$d" "$s/a"
  local out; out=$(cmp_out "$d" "$s/b" "$s/a")
  assert_grep "$out" '^changed: new\.txt$' "X2: untracked 추가가 나온다"
  assert_grep "$out" '^changed: u\.txt$'   "X2: untracked 삭제가 나온다"
}

case_X2_ignored_and_own_namespace_do_not_invalidate() {
  # 양의 짝 — 무시된 파일과 qg 자신의 상태 폴더는 지문 밖이다(그렇지 않으면 매 걷기가 무효다).
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  mkdir -p "$d/ignored"; printf 'log\n' >"$d/ignored/app.log"; printf 'x\n' >"$s/evidence.tsv"
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "0" "X2: 무시된 파일 · .claude/quality-gates 쓰기는 무효가 아니다"
}

case_V8_malformed_fingerprint_is_not_same() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'garbage\n' >"$s/a"
  local rc=0; cmp_out "$d" "$s/b" "$s/a" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "판독할 수 없는 지문은 same 이 아니라 exit 4"
}

# ── X5 · AC20 — kill switch 둘(+전역) 중 하나라도 켜지면 측정·실행 전에 exit 3 ─────────
case_X5_AC20_kill_switch_refuses_fingerprint_compare() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  local v rc
  for v in DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST DEVBREW_QUALITY_GATES_DISABLE; do
    rm -f "$s/x"
    rc=0; (cd "$d" && env "$v=1" bash "$ES" fingerprint --out "$s/x" >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "3" "X5: $v=1 이면 fingerprint 가 exit 3"
    [ ! -e "$s/x" ] && ok "X5: $v=1 이면 지문 파일이 생기지 않는다" || no "X5: $v=1 인데 지문 파일이 생겼다"
    rc=0; (cd "$d" && env "$v=1" bash "$ES" compare "$s/b" "$s/b" >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "3" "X5: $v=1 이면 compare 가 exit 3"
  done
}

case_X5_only_exact_one_disables() {
  # 양의 짝 — 전체 토큰 일치(E5). `1` 이 아닌 값은 끄지 않는다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local rc=0; (cd "$d" && DEVBREW_QUALITY_GATES_DISABLE_E2E=true bash "$ES" fingerprint --out "$s/x" >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "0" "X5: DISABLE_E2E=true 는 끄지 않는다(1 만 끈다)"
}

case_RF3_odd_path_names_are_reported() {
  # Review Focus 3 — 공백 · 한글 · 줄바꿈이 든 경로도 무효 판정과 경로 목록에 나온다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  printf 'x\n' >"$d/a b.txt"; printf 'x\n' >"$d/한글.txt"; printf 'x\n' >"$d/$(printf 'n\nl.txt')"
  fp "$d" "$s/b"
  printf 'y\n' >"$d/a b.txt"; printf 'y\n' >"$d/한글.txt"; printf 'y\n' >"$d/$(printf 'n\nl.txt')"
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "RF3: 이상한 이름의 파일 변경도 무효다"
  assert_grep "$out" '^changed: a b\.txt$' "RF3: 공백 든 경로"
  assert_grep "$out" '^changed: 한글\.txt$' "RF3: 한글 경로"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "changed: 3" "RF3: 줄바꿈 든 경로까지 셋 다 센다"
}

# ── X1 · AC18 — 판정안은 증거표에서 코드가 낸다 ──────────────────────────────────────
prop() { local f; f="$(mktemp)"; TMPS+=("$f"); printf '%b' "$1" >"$f"; bash "$ES" propose "$f"; }

case_X1_all_met_with_evidence_is_pass() {
  local out; out=$(prop '기대 상태\t판정\t증거\nPOST 201\t충족\tHTTP/1.0 201 Created\nGET 에 apple\t충족\t{"items": ["apple"]}\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: pass" "X1: 전부 충족이고 증거가 있으면 pass"
}

case_X1_AC18_met_without_evidence_is_unconfirmed() {
  local out; out=$(prop 'POST 201\t충족\tHTTP/1.0 201 Created\nGET 에 apple\t충족\t-\n')
  assert_grep "$out" '^coerced: 2 충족 → 미확인' "X1: 증거 없는 충족은 미확인으로 강제된다"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: 미확인" "AC18: 증거 인용 없는 기대 상태가 있고 불충족이 없으면 미확인"
}

case_X1_unmet_is_fail() {
  local out; out=$(prop 'POST 201\t불충족\tHTTP/1.0 400 Bad Request\nGET 에 apple\t충족\t\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: fail" "X1: 불충족이 하나라도 있으면 fail"
}

case_X1_empty_table_is_not_pass() {
  local out; out=$(prop '기대 상태\t판정\t증거\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: 미확인" "X1: 기대 상태가 없으면 pass 가 아니라 미확인"
}

case_V8_malformed_table_is_unreadable() {
  local rc=0; prop 'POST 201\t아마도\tx\n' >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 판정은 exit 4"
  rc=0; prop 'POST 201\t충족\n' >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "칸 수가 셋이 아니면 exit 4"
}

for c in $(declare -F | awk '{print $3}' | grep '^case_'); do
  note "── $c"
  "$c"
done
finish
