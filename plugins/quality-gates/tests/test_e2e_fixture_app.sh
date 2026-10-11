#!/usr/bin/env bash
# test_e2e_fixture_app.sh — tests/fixtures/e2e-app (설계 v10 §7 ④ 컷오버 조건 · AC19 의 바닥).
#
# 모델의 걷기(AC19)는 결정론으로 잴 수 없다. 이 락이 재는 것은 그 걷기가 기대어 서는 바닥이다:
# fixture 리포가 만들어지고, e2e-ok 에서는 README 의 API 계약이 지켜지고, e2e-bug 에서는 같은 계약이
# 관측 가능하게 깨지며, 두 브랜치 모두 단위 테스트는 통과한다(결함이 HTTP 층에만 산다 — 차등
# 테스트로는 안 잡히고 e2e 로만 잡히는 결함이어야 이 fixture 가 존재 이유를 가진다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ES="$PLUGIN_ROOT/scripts/e2e-state.sh"
MK="$PLUGIN_ROOT/tests/fixtures/e2e-app/make-repo.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_QUALITY_GATES_DISABLE DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST
WORK="$(cd "$(mktemp -d)" && pwd -P)"
REPO="$WORK/repo"
STATE="$REPO/.claude/quality-gates/fixture1"
trap 'bash "$ES" stop --dir "$STATE" >/dev/null 2>&1; rm -rf "$WORK"' EXIT

free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }

case_fixture_repo_has_three_branches() {
  local out rc=0; out=$(bash "$MK" "$REPO") || rc=$?
  assert_eq "$rc" "0" "make-repo.sh exit 0"
  assert_eq "$out" "$REPO" "make-repo.sh 가 리포 경로 한 줄을 낸다"
  local b; b=$(git -C "$REPO" for-each-ref --format='%(refname:short)' refs/heads | sort | tr '\n' ' ')
  assert_eq "$b" "e2e-bug e2e-ok main " "브랜치가 main · e2e-ok · e2e-bug 셋이다"
  assert_eq "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" "main" "끝나면 main 에 있다"
}

walk_api() {   # $1 브랜치 — stdout: POST 상태 코드 한 줄 + GET 본문 한 줄
  local branch="$1" port; port=$(free_port)
  git -C "$REPO" checkout -q "$branch"
  mkdir -p "$STATE"
  (cd "$REPO" && bash "$ES" boot --dir "$STATE" --cmd "python3 app.py --port $port" --ready-port "$port" --timeout 20 >/dev/null) \
    || { echo "BOOT-FAILED"; return; }
  curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' \
    -d '{"name": "apple"}' "http://127.0.0.1:$port/api/items"
  curl -s "http://127.0.0.1:$port/api/items"; echo
  bash "$ES" stop --dir "$STATE" >/dev/null
}

case_ok_branch_keeps_the_api_contract() {
  local out; out=$(walk_api e2e-ok)
  assert_not_grep "$out" 'BOOT-FAILED' "e2e-ok 가 README 의 명령으로 뜬다"
  assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "201" "e2e-ok: POST /api/items {name} 가 201"
  assert_grep "$out" '"items": \["apple"\]' "e2e-ok: GET /api/items 에 apple 이 있다"
}

case_bug_branch_breaks_the_api_contract() {
  local out; out=$(walk_api e2e-bug)
  assert_not_grep "$out" 'BOOT-FAILED' "e2e-bug 가 README 의 명령으로 뜬다"
  assert_eq "$(printf '%s\n' "$out" | sed -n 1p)" "400" "e2e-bug: POST /api/items {name} 가 201 이 아니다(관측 가능한 결함)"
  assert_not_grep "$out" '"apple"' "e2e-bug: GET /api/items 에 apple 이 없다"
}

case_unit_tests_pass_on_both_branches() {
  local b rc
  for b in e2e-ok e2e-bug; do
    git -C "$REPO" checkout -q "$b"
    rc=0; (cd "$REPO" && bash tests/test_store.sh >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "0" "$b: 단위 테스트가 통과한다(결함은 HTTP 층에만 있다)"
  done
  git -C "$REPO" checkout -q main
}

case_fixture_repo_has_three_branches
case_ok_branch_keeps_the_api_contract
case_bug_branch_breaks_the_api_contract
case_unit_tests_pass_on_both_branches
finish
