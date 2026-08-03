#!/usr/bin/env bash
# test_runtime_contract_invariance.sh — create-baseline + 기존 계약 바이트 무변경.
# AC7 AC21 AC22 AC24 AC25 AC26 · T5 T16 T17 T18
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# T5 + AC7: create-baseline이 merge_base에 detached worktree를 만들고 경로를 emit
case_create_baseline() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; git add a.txt; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git checkout -q -b feature
  echo v2 > a.txt; git commit -qam v2

  local out rc; out=$(bash "$WT" create-baseline "$base_sha" "sess1234"); rc=$?
  if [[ $rc -ne 0 || ! -d "$out" ]]; then
    fail "create-baseline (rc=$rc out='$out')"; cd / && rm -rf "$REPO"; return
  fi
  pass "create-baseline → 워크트리 경로 emit"

  # 네임스페이스: worktrees/ 아래여야 remove 가드가 적용된다
  case "$out" in
    */.claude/quality-gates/worktrees/*) pass "worktrees/ 네임스페이스 안" ;;
    *) fail "네임스페이스 밖: $out" ;;
  esac
  # 내용이 merge_base 상태인가 (HEAD의 v2가 아니라 v1)
  [[ "$(cat "$out/a.txt")" == "v1" ]] && pass "기준선 트리 내용 == merge_base" \
                                      || fail "기준선 내용 오염 ($(cat "$out/a.txt"))"
  # detached HEAD인가
  ( cd "$out" && ! git symbolic-ref --quiet HEAD >/dev/null 2>&1 ) \
    && pass "기준선 워크트리는 detached" || fail "detached 아님"
  # remove가 동작 (네임스페이스 가드 통과)
  bash "$WT" remove "$out" && [[ ! -d "$out" ]] && pass "remove 적용됨" || fail "remove 실패"
  cd / && rm -rf "$REPO"
}

# 최종 whole-branch 리뷰 (Task 9 이월분 승격) — create-baseline 의 idempotent 정리가
# **사용자 워크트리를 파괴**할 수 있다. `create` 는 `${sanitized}-${sid_short}`,
# create-baseline 은 `base-${sid_short}` 를 쓰므로 같은 세션의 `/qg branch base` 가
# **정확히 같은 경로**를 만들고, 무조건 `--force` 면 미커밋 작업이 되돌릴 수 없이 사라진다.
#
# 판별자로 "HEAD 가 심볼릭 ref 인가"는 쓸 수 없다 — `create` 도 `--detach` 라 둘 다
# detached 다 (위 case_create_baseline 이 기준선 트리의 detached 를 확인하는 것과 같은
# 성질이며, 실측으로 확인했다). 그래서 이 케이스는 **미커밋 파일이 살아남는가**를 직접
# 잰다. 파일 존재는 어떤 판별자 구현에도 의존하지 않는 관측이다.
case_create_baseline_refuses_colliding_user_worktree() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; git add a.txt; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git branch base
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2

  # 사용자가 같은 세션에서 `/qg branch base` 를 돌린 상태를 만든다
  local user_wt; user_wt=$(bash "$WT" create base "sess1234" 2>/dev/null)
  if [[ -z "$user_wt" || ! -d "$user_wt" ]]; then
    fail "픽스처 무효: /qg branch base 워크트리 생성 실패"; cd / && rm -rf "$REPO"; return
  fi
  # 픽스처가 실제로 충돌하는지 먼저 증명한다 (경로가 안 겹치면 이 락은 무의미하다)
  [[ "$(basename "$user_wt")" == "base-sess1234" ]] \
    && pass "픽스처: /qg branch base 와 create-baseline 이 같은 경로를 노린다" \
    || fail "픽스처 무효: 경로 불일치 ($user_wt)"
  echo "uncommitted work" > "$user_wt/WIP.txt"

  local out rc; out=$(bash "$WT" create-baseline "$base_sha" "sess1234" 2>/dev/null); rc=$?
  [[ -f "$user_wt/WIP.txt" ]] \
    && pass "충돌 경로의 미커밋 작업이 살아남음" \
    || fail "create-baseline 이 사용자 워크트리의 미커밋 작업을 파괴함"
  [[ $rc -ne 0 ]] \
    && pass "충돌 시 조용히 진행하지 않고 non-zero 로 죽는다" \
    || fail "충돌인데 exit 0 (rc=$rc out='$out')"
  cd / && rm -rf "$REPO"
}

# 위 가드가 정상 경로(우리가 만든 clean 한 기준선 트리 재사용)를 막지 않는가.
# 가드만 넣고 이것을 안 재면 게이트가 두 번째 실행부터 영구히 죽는 회귀를 못 잡는다.
case_create_baseline_is_still_idempotent() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo v1 > a.txt; printf '/target\n' > .gitignore
  git add a.txt .gitignore; git commit -qm v1
  local base_sha; base_sha=$(git rev-parse HEAD)
  git checkout -q -b feature; echo v2 > a.txt; git commit -qam v2

  local first second rc
  first=$(bash "$WT" create-baseline "$base_sha" "sess9999" 2>/dev/null)
  # 앞선 실행이 남긴 **git-ignored 빌드 산출물**이 있는 상태가 정상 경로다 (C1 수정 이후
  # cargo/venv 산출물은 전부 ignored 로 떨어진다). 여기서 막히면 게이트가 두 번째
  # 실행부터 영구히 죽는다.
  mkdir -p "$first/target/debug" && : > "$first/target/debug/x.o"
  second=$(bash "$WT" create-baseline "$base_sha" "sess9999" 2>/dev/null); rc=$?
  if [[ $rc -eq 0 && "$second" == "$first" && -d "$second" ]]; then
    pass "clean 한 기준선 트리 재실행은 그대로 성공 (idempotent 보존)"
  else
    fail "idempotent 회귀 (rc=$rc first='$first' second='$second')"
  fi
  cd / && rm -rf "$REPO"
}

# 네임스페이스 밖 경로는 remove가 거부한다 (기존 가드가 새 경로에도 유효한지 확인)
case_remove_namespace_guard() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  echo x > a.txt; git add a.txt; git commit -qm x
  mkdir -p "$REPO/outside"
  bash "$WT" remove "$REPO/outside" >/dev/null 2>&1 \
    && fail "네임스페이스 밖 remove가 통과" \
    || pass "네임스페이스 밖 remove 거부"
  [[ -d "$REPO/outside" ]] && pass "거부된 대상이 살아있음" || fail "대상이 삭제됨"
  cd / && rm -rf "$REPO"
}

# T16 + AC21: detect-runtime.sh 바이트 무변경 (sha 핀)
# 값은 최초 구현 시 `shasum -a 256` 결과로 채운다. 이 파일을 고치려면 sha도 함께
# 고쳐야 하므로, "무심코 건드림"은 통과할 수 없다.
DETECT_RUNTIME_SHA256="12d230b248e85ed15e0a910a1979b21c6e0bedb902ea0fd45f2833ae90e97033"
case_detect_runtime_frozen() {
  local got; got=$(shasum -a 256 "$PLUGIN_ROOT/scripts/detect-runtime.sh" | awk '{print $1}')
  [[ "$got" == "$DETECT_RUNTIME_SHA256" ]] \
    && pass "detect-runtime.sh 바이트 무변경" \
    || fail "detect-runtime.sh 변경됨 (got $got, pinned $DETECT_RUNTIME_SHA256)"
}

# T17 + AC22: create-sandbox / mutation-guard case 본문 바이트 무변경
# case 절 본문만 잘라 해시한다 — 파일 전체를 핀하면 create-baseline 추가로 깨진다.
extract_case() {   # extract_case <case-label> → 그 case 절 본문
  awk -v label="  $1)" '
    $0 == label { inblock = 1; next }
    inblock && /^  [a-z][a-z-]*\)$/ { exit }
    inblock { print }
  ' "$WT"
}
CREATE_SANDBOX_SHA256="1f3f545ec57065abffcff36b7df1252bf009e6608c237dd8d9f0fb49bebdf055"
MUTATION_GUARD_SHA256="000c3a26953269b237c4e272bbddfad8ea4a33b2d3f6f5787e80fecbdd1ed830"
case_sandbox_guard_frozen() {
  local a b
  a=$(extract_case create-sandbox | shasum -a 256 | awk '{print $1}')
  b=$(extract_case mutation-guard | shasum -a 256 | awk '{print $1}')
  [[ "$a" == "$CREATE_SANDBOX_SHA256" ]] && pass "create-sandbox 본문 무변경" \
    || fail "create-sandbox 변경 (got $a)"
  [[ "$b" == "$MUTATION_GUARD_SHA256" ]] && pass "mutation-guard 본문 무변경" \
    || fail "mutation-guard 변경 (got $b)"
}

# T18 + AC24/AC25/AC26: 훅 항목 수 · 에이전트 파일 수 · verdict 토큰 집합 불변
case_no_new_surfaces() {
  local hooks agents
  hooks=$(python3 -c "
import json
with open('$PLUGIN_ROOT/hooks/hooks.json', encoding='utf-8') as f:
    d = json.load(f)
print(sum(len(v) for v in d.get('hooks', {}).values()))
")
  agents=$(ls "$PLUGIN_ROOT/agents" | wc -l | tr -d ' ')
  [[ "$hooks" == "4" ]]  && pass "hooks.json 항목 4개 불변" || fail "hooks 항목 수 $hooks (기대 4)"
  [[ "$agents" == "7" ]] && pass "agents/ 파일 7개 불변"    || fail "agents 파일 수 $agents (기대 7)"
  # verdict 토큰은 4종 밖으로 늘지 않는다
  if grep -qE '\bPARTIAL\b|\bINCONCLUSIVE\b|\bDEGRADED_VERDICT\b' "$SKILL"; then
    fail "SKILL.md에 신규 verdict 토큰 등장"
  else
    pass "verdict 토큰 4종 불변"
  fi
}

for c in case_create_baseline case_create_baseline_refuses_colliding_user_worktree \
         case_create_baseline_is_still_idempotent \
         case_remove_namespace_guard case_detect_runtime_frozen \
         case_sandbox_guard_frozen case_no_new_surfaces; do
  echo "== $c"; $c
done
echo "── runtime contract invariance: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
