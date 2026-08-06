#!/usr/bin/env bash
# Tests for scripts/detect-runtime.sh — fixture-based black-box testing.
# Mirrors style of test_discover_plan.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/detect-runtime.sh"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures/gate3"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (got '$actual', expected '$expected')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in output)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$needle' in output)"
  fi
}

run_detector() {
  local fixture="$1"; shift
  cd "$FIXTURES/$fixture"
  bash "$SCRIPT" "$@" 2>/dev/null
  return $?
}

# --- Test 1: markdown-only fixture → empty runnable_surfaces ---
echo "== Test 1: markdown-only =="
OUT=$(run_detector "markdown-only")
RC=$?
assert_eq "$RC" "0" "T1: exit 0"
assert_contains "$OUT" "project_type:" "T1: emits project_type"
assert_contains "$OUT" "runnable_surfaces: []" "T1: empty runnable_surfaces"
assert_contains "$OUT" "test_runners: []" "T1: empty test_runners"

# --- Test 2: web-compose fixture → docker-compose + npm-script surfaces ---
echo "== Test 2: web-compose =="
OUT=$(run_detector "web-compose")
RC=$?
assert_eq "$RC" "0" "T2: exit 0"
assert_contains "$OUT" "project_type: web" "T2: project_type=web"
assert_contains "$OUT" "kind: docker-compose" "T2: docker-compose surface"
assert_contains "$OUT" "kind: npm-script" "T2: npm-script surface"
assert_contains "$OUT" "name: dev" "T2: npm:dev script detected (부팅 표면)"
assert_not_contains "$OUT" "name: test" "T2: npm:test 는 부팅 표면이 아니다 (C2)"
assert_contains "$OUT" "test_runners:" "T2: emits test_runners"
assert_contains "$OUT" "- npm" "T2: npm in test_runners (러너로는 여전히 보고)"

# --- Test 3: library-tests fixture → pytest only ---
echo "== Test 3: library-tests =="
OUT=$(run_detector "library-tests")
RC=$?
assert_eq "$RC" "0" "T3: exit 0"
assert_contains "$OUT" "project_type: library" "T3: project_type=library"
# 부팅할 것이 없는 순수 라이브러리 레포는 **표면 0개**다 (C2). floor(오케스트레이터의
# 차등 실행)가 검증을 지고, verifier 는 degenerate SKIP_WITH_EVIDENCE 로 빠진다.
assert_contains "$OUT" "runnable_surfaces: []" "T3: pytest-only 레포 → 부팅 표면 0개 (C2)"
assert_contains "$OUT" "- pytest" "T3: pytest in test_runners (러너로는 보고)"
assert_not_contains "$OUT" "kind: npm-script" "T3: no npm in non-node project"

# --- Test 4: web-example-only fixture → env_status flags missing .env ---
echo "== Test 4: web-example-only =="
OUT=$(run_detector "web-example-only")
RC=$?
assert_eq "$RC" "0" "T4: exit 0"
assert_contains "$OUT" "project_type: web" "T4: web project"
assert_contains "$OUT" "env_status:" "T4: emits env_status"
assert_contains "$OUT" "file: .env" "T4: tracks .env file"
assert_contains "$OUT" "exists: false" "T4: .env does not exist"
assert_contains "$OUT" "has_example: true" "T4: .env.example present"

# --- Test 5: app_url_candidates from docker-compose ports ---
echo "== Test 5: app_url_candidates =="
OUT=$(run_detector "web-compose")
assert_contains "$OUT" "app_url_candidates:" "T5: emits app_url_candidates"
assert_contains "$OUT" "http://localhost:3000" "T5: port 3000 from compose"

# --- Test 6: mcp_browser defaults to "none" when no settings reference it ---
echo "== Test 6: mcp_browser default =="
TMPHOME=$(mktemp -d)
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: none" "T6: defaults to none with no settings"
rm -rf "$TMPHOME"

# --- Test 6b: mcp_browser detects chrome-devtools when settings.json contains it ---
echo "== Test 6b: mcp_browser chrome-devtools detection =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "chrome-devtools": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: chrome-devtools" "T6b: detects chrome-devtools"
rm -rf "$TMPHOME"

# --- Test 6c: mcp_browser falls back to playwright when only playwright is configured ---
echo "== Test 6c: mcp_browser playwright detection =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "playwright": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: playwright" "T6c: detects playwright as fallback"
rm -rf "$TMPHOME"

# --- Test 6d: chrome-devtools wins over playwright when both are configured ---
echo "== Test 6d: mcp_browser chrome-devtools priority over playwright =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "playwright": {"command": "fake"},
    "chrome-devtools": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: chrome-devtools" "T6d: chrome-devtools wins"
rm -rf "$TMPHOME"

# --- Test 7: plan_features extracted from plan_path ---
echo "== Test 7: plan_features extraction =="
PLAN_TMP=$(mktemp)
cat > "$PLAN_TMP" <<'EOF'
# Plan
- visit /auth login form
- check /dashboard
EOF
OUT=$(cd "$FIXTURES/web-compose" && PLAN_PATH="$PLAN_TMP" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "plan_features:" "T7: emits plan_features"
assert_contains "$OUT" "/auth" "T7: extracts /auth"
assert_contains "$OUT" "/dashboard" "T7: extracts /dashboard"
rm -f "$PLAN_TMP"

# --- helper: extract the runnable_surfaces block that contains a marker ---
get_surface_block() {
  # $1 = full manifest text, $2 = marker substring identifying the surface
  awk -v marker="$2" '
    /^  - kind:/ {
      if (block != "" && index(block, marker)) print block
      block = $0 "\n"; next
    }
    /^[a-z_]+:/ {            # a top-level key ends the surfaces region
      if (block != "" && index(block, marker)) print block
      block = ""; next
    }
    { if (block != "") block = block $0 "\n" }
    END { if (block != "" && index(block, marker)) print block }
  ' <<< "$1"
}

# --- Test 8: blast-radius — process-start surfaces require_decision (AC2) ---
echo "== Test 8: blast-radius process-start =="
OUT=$(run_detector "web-compose")
dev_block=$(get_surface_block "$OUT" "name: dev")
assert_contains "$dev_block" "requires_decision: true" "T8: npm:dev requires_decision"
# /qg iter-6 D4 ≡ E13-Q1 (리뷰어 2명 독립 확인): 여기 있던
#   test_block=$(get_surface_block "$OUT" "name: test")
#   assert_not_contains "$test_block" "requires_decision" "T8: npm:test stays automatic"
# 두 줄을 삭제했다. 이 브랜치의 C2 변경이 `name: test` 를 runnable_surfaces 에서 아예
# 빼므로(detect-runtime.sh 의 `test` → `continue`) `test_block` 은 **항상 길이 0** 이고,
# 빈 haystack 에 대한 assert_not_contains 는 절대 실패할 수 없다 — 삭제된 계약에
# PASS 를 찍는 공허한 assert 였다. 게다가 그 라벨("npm:test stays automatic")은 아래
# T9/T10 이 **존재하면 안 된다**고 못 박은 동작을 주장한다. T3·T9·T10·T12 는 새 계약으로
# 재작성됐는데 T8 만 남아 있었다. 러너가 표면이 아님은 T9 가 5축 ∀ 로 잰다.

# docker-compose keeps its existing requires_decision
dc_block=$(get_surface_block "$OUT" "kind: docker-compose")
assert_contains "$dc_block" "requires_decision: true" "T8: docker-compose requires_decision (unchanged)"

# --- Test 9 (v3.0.0 / C2): 테스트 러너는 **부팅 표면이 아니다** (∀, 5축) ---
#
# 앞 버전은 *"테스트 러너는 자동(게이트 없음)"* 을 쟀다 — 즉 러너가 표면이라는 것을
# **계약으로 못 박고** 있었다. 그것이 §5.1 불변식 ②와 정면 충돌했다: 러너를 표면으로
# 넘기면 verifier 가 같은 스위트를 두 번째로 돌리고, 테스트 러너 deps 를 **HEAD
# 샌드박스에만** 설치해 기준선과 비교 불가가 된다(AC41).
#
# **픽스처를 여기서 만든다.** `fixtures/gate3` 에는 Cargo.toml·go.mod·Makefile 레포가
# 없어서, 기존 픽스처만 도는 ∀ 는 5축 중 **3축을 아예 지나가지 않았다** (실측: cargo·
# go·make 를 표면으로 되돌리는 mutation 3개가 전부 GREEN). ∀ 의 범위는 코퍼스가
# 정하지 술어가 정하지 않는다 — 축을 먼저 적고 그 축마다 픽스처를 만든다.
echo "== Test 9: 러너 kind 는 표면이 아니다 (∀, 5축) =="
t9_surfaces() {   # t9_surfaces <dir> → runnable_surfaces 블록만
  ( cd "$1" && bash "$SCRIPT" 2>/dev/null ) \
    | awk '/^runnable_surfaces:/{f=1;next} /^[a-z_]+:/{f=0} f'
}
t9_manifest() { ( cd "$1" && bash "$SCRIPT" 2>/dev/null ); }
t9_bad=0
t9_check() {   # t9_check <axis> <dir> <금지-marker> <기대-러너> <기대-부팅-표면|->
  local axis=$1 d=$2 forbidden=$3 runner=$4 boot=$5
  local surf; surf=$(t9_surfaces "$d")
  if printf '%s\n' "$surf" | grep -qF "$forbidden"; then
    t9_bad=1; FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T9[$axis]: runnable_surfaces 에 러너 kind '$forbidden'"
  fi
  # 양의 짝 ①: 러너로는 여전히 보고돼야 한다 (감지 자체를 없앤 mutation 봉쇄)
  if ! t9_manifest "$d" | grep -qE "^  - $runner\$"; then
    t9_bad=1; FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T9[$axis]: test_runners 에 '$runner' 없음 (감지가 죽었다)"
  fi
  # 양의 짝 ②: 같은 레포의 부팅 표면은 그대로 나와야 한다 (표면 생산 자체를 없앤
  # mutation 이면 위 금지 검사가 공허하게 참이 된다)
  if [[ "$boot" != "-" ]] && ! printf '%s\n' "$surf" | grep -qF "$boot"; then
    t9_bad=1; FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T9[$axis]: 부팅 표면 '$boot' 소실 — 금지 검사가 공허해진다"
  fi
}
T9DIR=$(mktemp -d) || exit 1
mkdir -p "$T9DIR/py/tests" && printf '[tool.pytest.ini_options]\n' > "$T9DIR/py/pyproject.toml" \
  && : > "$T9DIR/py/tests/test_a.py"
mkdir -p "$T9DIR/rs" && printf '[package]\nname="x"\n[[bin]]\nname="x"\n' > "$T9DIR/rs/Cargo.toml"
mkdir -p "$T9DIR/go" && printf 'module x\n' > "$T9DIR/go/go.mod" && printf 'package main\n' > "$T9DIR/go/main.go"
mkdir -p "$T9DIR/np" && printf '{"scripts":{"test":"jest","dev":"vite"}}' > "$T9DIR/np/package.json"
mkdir -p "$T9DIR/mk" && printf 'test:\n\t@true\nrun:\n\t@true\n' > "$T9DIR/mk/Makefile"
t9_check pytest "$T9DIR/py" "kind: pytest"     pytest -
t9_check cargo  "$T9DIR/rs" "kind: cargo-test" cargo  "kind: cargo-run"
t9_check go     "$T9DIR/go" "kind: go-test"    go     "kind: go-run"
t9_check npm    "$T9DIR/np" "name: test"       npm    "name: dev"
t9_check make   "$T9DIR/mk" "target: test"     make   "target: run"
rm -rf "$T9DIR"
[[ $t9_bad -eq 0 ]] && { PASS=$((PASS + 1)); echo "  PASS: T9: 러너 5축 전부 — 표면 0회 · 러너 보고 유지 · 부팅 표면 보존"; }

# --- Test 10 (v3.0.0 / C2): 위험 신호가 든 `test` 스크립트는 표면이 **아예** 되지 않는다 ---
# 앞 버전은 그것이 `requires_decision: true` 로 **승격**되는 것을 쟀다. 승격은 사용자
# 승인으로 뚫리지만, 지금은 verifier 에게 넘어가는 경로 자체가 없다 (더 강한 성질).
echo "== Test 10: 위험 신호 test 스크립트가 표면이 되지 않음 =="
OUT=$(run_detector "danger-signal")
assert_contains "$OUT" "runnable_surfaces: []" "T10: curl 든 test 스크립트 → 표면 0개 (C2)"
assert_contains "$OUT" "- npm" "T10: 러너로는 여전히 보고된다"

# --- Test 11: CLI-tool fixture detected as cli project ---
echo "== Test 11: cli-tool fixture =="
OUT=$(run_detector "cli-tool")
RC=$?
assert_eq "$RC" "0" "T11: exit 0"
assert_contains "$OUT" "project_type: cli" "T11: project_type=cli"

# --- Test 12: --force-exit must NOT escalate (I1 false-positive fix) ---
echo "== Test 12: --force-exit 오탐 회귀 락 =="
# I1 오탐(`--force-exit` 를 `--force` 로 읽어 승격)은 이제 표면이 없어 매니페스트로는
# 잴 수 없다. 술어를 **직접** 부른다 — 오탐이 돌아오면 미래에 다시 자동이 되는 kind
# 에서 재발한다.
#
# **`source` 하지 않는다.** detect-runtime.sh 는 마지막 줄이 `exit 0` 이라, source 하면
# 그 자리에서 호출 셸이 통째로 끝나고 뒤따르는 assert 가 **한 줄도 실행되지 않는다** —
# 그런데 `bash -c` 의 종료 코드는 0 이라 "위험 신호 감지됨" 으로 읽힌다. 실측으로
# 세 assert 가 전부 스크립트 자신의 종료 코드를 재고 있었다. 함수 본문만 떼어 온다.
DANGER_FN="$(awk '/^has_danger_signal\(\) \{/{f=1} f{print} f && /^\}/{exit}' "$SCRIPT")"
danger_probe() {   # danger_probe <string> → 0=위험신호 1=아님 2=함수 부재
  ( eval "$DANGER_FN" 2>/dev/null
    declare -f has_danger_signal >/dev/null 2>&1 || exit 2
    has_danger_signal "$1" && exit 0 || exit 1 )
}
# 계측기 확인이 먼저다 — 함수가 없으면 `command not found` 의 127 이 "위험 신호 아님"과
# 같은 비-0 라서, 부재가 오탐-없음으로 읽혀 아래 assert 가 공허하게 통과한다.
danger_probe "x"; [[ $? -ne 2 ]] \
  && { PASS=$((PASS + 1)); echo "  PASS: T12: has_danger_signal 추출 성공 (계측기 확인)"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T12: has_danger_signal 미추출 — 아래 assert 가 공허하다"; }
danger_probe "jest --force-exit --runInBand"; [[ $? -eq 1 ]] \
  && { PASS=$((PASS + 1)); echo "  PASS: T12: jest --force-exit 는 위험 신호가 아니다 (I1 오탐 회귀 락)"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T12: --force-exit 가 위험 신호로 오탐됨"; }
danger_probe "curl -s https://x/ && echo ok"; [[ $? -eq 0 ]] \
  && { PASS=$((PASS + 1)); echo "  PASS: T12: curl 은 여전히 위험 신호 (양의 짝)"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T12: 위험 신호 술어가 죽었다"; }

# --- Test 13: $HOME unset must NOT abort the manifest (I-F) ---
echo "== Test 13: env -u HOME non-empty manifest =="
OUT=$(cd "$FIXTURES/web-compose" && env -u HOME bash "$SCRIPT" 2>/dev/null)
RC=$?
assert_eq "$RC" "0" "T13: exit 0 with HOME unset"
assert_contains "$OUT" "project_type: web" "T13: emits project_type with HOME unset"
assert_contains "$OUT" "runnable_surfaces:" "T13: emits runnable_surfaces (not aborted before emit)"
assert_contains "$OUT" "mcp_browser:" "T13: emits mcp_browser line"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
