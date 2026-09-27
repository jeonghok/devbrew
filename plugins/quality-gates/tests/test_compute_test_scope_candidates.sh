#!/usr/bin/env bash
# Tests for scripts/compute-test-scope-candidates.sh
# Builds temp git repos at runtime; verifies heuristic src→test mapping
# + changed-test fallback + language-unsupported empty result.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/compute-test-scope-candidates.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"





mktemp_repo() {
  # mktemp 실패가 `cd ""` 로 새면 bash 는 조용히 rc 0 · cwd 무변경으로 통과한다(에러
  # 아님) — 이어지는 git init/config 가 **실제 리포**에서 돈다. cd·git 전에 먼저 막는다.
  local d
  d=$(mktemp -d -t qg-cand-XXXXXX) && [ -d "$d" ] || { echo "mktemp_repo: mktemp 실패" >&2; return 1; }
  (
    cd "$d" || exit 1
    git init -q
    git config user.email test@example.com
    git config user.name Test
    git config commit.gpgsign false
  ) || return 1
  echo "$d"
}

run_script() {
  local repo="$1"
  ( cd "$repo" && bash "$SCRIPT" ) 2>/dev/null
}

# mktemp_repo 가 실패하면 REPO 가 비어(또는 디렉토리가 아니어) 있다. 그 값으로
# `cd`·`git`·`mkdir` 를 돌리면 `cd ""` 가 조용히 현재 디렉토리에 머물러(에러 아님)
# 그 뒤 전부가 **실제 리포**에서 돈다 — 모든 호출부에서 먼저 확인한다.

# --- Test 1: Python src change → maps to existing tests/test_foo.py ---
echo "== Test 1: Python mapping =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T1: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    mkdir -p src tests
    echo "def foo(): return 1" > src/foo.py
    echo "from src.foo import foo
def test_foo(): assert foo() == 1" > tests/test_foo.py
    git add . && git commit -q -m "init"
    echo "def foo(): return 2" > src/foo.py
  )
  OUT=$(run_script "$REPO")
  assert_contains "$OUT" "tests/test_foo.py" "T1: maps src/foo.py to tests/test_foo.py"
  rm -rf "$REPO"
fi

# --- Test 2: TypeScript src change → maps to .test.ts neighbor ---
echo "== Test 2: TypeScript mapping =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T2: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    mkdir -p src
    echo "export const bar = () => 1" > src/bar.ts
    echo "import { bar } from './bar'
test('bar', () => { expect(bar()).toBe(1) })" > src/bar.test.ts
    git add . && git commit -q -m "init"
    echo "export const bar = () => 2" > src/bar.ts
  )
  OUT=$(run_script "$REPO")
  assert_contains "$OUT" "src/bar.test.ts" "T2: maps src/bar.ts to src/bar.test.ts"
  rm -rf "$REPO"
fi

# --- Test 3: changed test file is included verbatim ---
echo "== Test 3: changed-test fallback =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T3: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    mkdir -p tests
    echo "def test_x(): pass" > tests/test_x.py
    git add . && git commit -q -m "init"
    echo "def test_x(): assert True" > tests/test_x.py
  )
  OUT=$(run_script "$REPO")
  assert_contains "$OUT" "tests/test_x.py" "T3: changed test file appears in candidates"
  rm -rf "$REPO"
fi

# --- Test 4: unsupported language (Go), no neighbor test → empty result ---
echo "== Test 4: unsupported language =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T4: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    echo "package main
func main() {}" > main.go
    git add . && git commit -q -m "init"
    echo "package main
func main() { println() }" > main.go
  )
  OUT=$(run_script "$REPO")
  assert_eq "$OUT" "" "T4: Go src change without test produces empty output"
  rm -rf "$REPO"
fi

# --- Test 5: no diff (clean working tree, no commits ahead) → empty ---
echo "== Test 5: no diff =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T5: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    echo "x" > a.py
    git add . && git commit -q -m "init"
  )
  OUT=$(run_script "$REPO")
  assert_eq "$OUT" "" "T5: clean tree produces empty output"
  rm -rf "$REPO"
fi

# --- Test 6: de-duplication (src change + same test also touched) ---
echo "== Test 6: de-dup =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T6: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    mkdir -p src tests
    echo "def f(): return 1" > src/f.py
    echo "from src.f import f
def test_f(): assert f() == 1" > tests/test_f.py
    git add . && git commit -q -m "init"
    echo "def f(): return 2" > src/f.py
    echo "from src.f import f
def test_f(): assert f() == 2" > tests/test_f.py
  )
  OUT=$(run_script "$REPO")
  # tests/test_f.py should appear exactly once
  COUNT=$(echo "$OUT" | grep -c '^tests/test_f.py$' || true)
  assert_eq "$COUNT" "1" "T6: tests/test_f.py appears exactly once"
  rm -rf "$REPO"
fi

# --- Test 7 (/qg iter-6 D1): 분모(--total)가 분자(후보)를 반드시 포함한다 ---
#
# `TESTRE` 에 `test_*.py` 가 없어서, 매퍼가 명시적으로 찾는 `test_${base}.py` 가
# **분자에는 들어가고 분모에는 안 들어갔다** (실측: N=1, M=0). SKILL 은
# `영향 테스트 N개 선택 (전체 M개 중)` 의 분모를 비율 부풀리기를 막으려고 이 스크립트에서
# 강제로 가져오므로, M < N 이면 그 보증이 통째로 무너진다.
#
# 관계로 잰다 (∀, 값 핀 아님): 후보로 나온 **모든** 경로가 분모 집합에도 있어야 한다.
# 값을 핀하면 픽스처가 바뀔 때마다 무의미하게 red 가 된다.
echo "== Test 7: --total 분모 ⊇ 후보 분자 =="
REPO=$(mktemp -d)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T7: mktemp 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    git init -q .
    echo "def f(): return 1" > mod.py
    echo "from mod import f
def test_f(): assert f() == 1" > test_mod.py          # 루트의 test_*.py — 매퍼가 찾는 형태
    mkdir -p pkg && echo "def g(): return 1" > pkg/g.py
    echo "def test_g(): pass" > pkg/g_test.py           # 이미 덮이던 형태(대조군)
    git add -A && git -c user.email=t@t -c user.name=t commit -qm init
    echo "def f(): return 2" > mod.py
    echo "def g(): return 2" > pkg/g.py
  )
  CANDS=$(run_script "$REPO")
  TOTAL_LIST=$( ( cd "$REPO" && git ls-files | grep -E '(test|spec)\.[jt]sx?$|_test\.py$|(^|/)test_[^/]*\.py$|\.test\.|\.spec\.|(^|/)tests?/' ) || true )
  TOTAL_N=$( ( cd "$REPO" && bash "$SCRIPT" --total ) 2>/dev/null )
  MISSING=""
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    printf '%s\n' "$TOTAL_LIST" | grep -qxF -- "$c" || MISSING="$MISSING $c"
  done <<< "$CANDS"
  # 양의 짝: 후보가 0개면 위 ∀ 는 공허하게 참이다.
  CAND_N=$(printf '%s\n' "$CANDS" | grep -c . || true)
  if [[ "$CAND_N" -lt 1 ]]; then
    no "T7 후보가 0개 — ∀ 가 공허하게 통과할 뻔했다"
  else
    assert_eq "$MISSING" "" "T7: 후보 ${CAND_N}개 전부가 --total 분모에 포함 (∀)"
    # 분모가 분자보다 작아질 수 없다
    if [[ "$TOTAL_N" -ge "$CAND_N" ]]; then
      ok "T7: 분모 M=$TOTAL_N ≥ 분자 N=$CAND_N"
    else
      no "T7: 분모 M=$TOTAL_N < 분자 N=$CAND_N"
    fi
  fi
  rm -rf "$REPO"
fi

# --- Test 8 (/qg iter-6 E10 ≡ §6.7 F6): 소유자 부재가 조용한 빈 결과가 되지 않는다 ---
#
# `RB_OUT=$(... || true)` 는 `resolve-baseline.sh` 의 부재·실패를 빈 문자열로 바꿔
# `REVIEW_RANGE=""` 로 조용히 떨어뜨렸다. 형제 `check-review-scope.sh` 는 같은 자리에서
# `|| emit_degraded` 로 fail-closed 다. 후보 목록은 힌트라 verdict 를 직접 막지 않지만,
# "영향 테스트 0개" 가 "영향이 없다" 로 읽히면 R2 선택 근거가 거짓이 된다.
#
# 양의 짝: 소유자가 **있을 때는** 이 경고가 나오면 안 된다.
echo "== Test 8: resolve-baseline.sh 부재 → loud =="
ORPHAN=$(mktemp -d)
if [ -z "$ORPHAN" ] || [ ! -d "$ORPHAN" ]; then
  no "T8: mktemp 가 사용 가능한 경로를 내지 못했다(ORPHAN) — 이후 단언을 건너뛴다"
else
  cp "$SCRIPT" "$ORPHAN/compute-test-scope-candidates.sh"     # 형제 스크립트 없이 고립
  (
    cd "$ORPHAN" || exit 1
    git init -q .
    echo "x" > a.py
    git add -A && git -c user.email=t@t -c user.name=t commit -qm i
  )
  ORPHAN_ERR=$( ( cd "$ORPHAN" && bash "$ORPHAN/compute-test-scope-candidates.sh" ) 2>&1 >/dev/null )
  assert_contains "$ORPHAN_ERR" "resolve-baseline.sh 실행 실패" "T8: 소유자 부재가 loud (조용한 빈 결과 아님)"
  rm -rf "$ORPHAN"
fi

REPO=$(mktemp -d)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T8: mktemp 가 사용 가능한 경로를 내지 못했다(REPO) — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    git init -q .
    echo "x" > a.py
    git add -A && git -c user.email=t@t -c user.name=t commit -qm i
  )
  NORMAL_ERR=$( ( cd "$REPO" && bash "$SCRIPT" ) 2>&1 >/dev/null )
  assert_not_contains "$NORMAL_ERR" "resolve-baseline.sh 실행 실패" "T8: 소유자가 있으면 무경고 (양의 짝)"
  rm -rf "$REPO"
fi

# --- Test 9: 토픽 모드 분모 --total --tree <tree> ---
#
# 토픽(선언) 경로는 분자를 경계..합친 트리로 보충하지만(differential-test.md R1b), 분모
# (--total)는 현재 체크아웃만 셌다 — N > M 이 나올 수 있다. `--total --tree <tree>` 는
# 그 트리 안의 테스트 파일 수를 낸다.
#
# `cd ""` 함정: mktemp_repo 가 실패(빈 문자열)를 내면 그 값으로 cd 하지 않는다 — 확인 후 진행.
echo "== Test 9: --total --tree <tree> (토픽 분모) =="
REPO=$(mktemp_repo)
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  no "T9: mktemp_repo 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$REPO" || exit 1
    git checkout -q -b main
    mkdir -p tests
    echo "echo calc" > tests/test_calc.sh
    git add . && git commit -q -m "main: test_calc"
    git checkout -q -b topicA
    echo "echo sub" > tests/test_sub.sh
    git add . && git commit -q -m "topicA: test_sub"
    git checkout -q main
    git checkout -q -b topicB
  )

  TOTAL_MAIN=$( ( cd "$REPO" && bash "$SCRIPT" --total ) 2>/dev/null )
  assert_eq "$TOTAL_MAIN" "1" "T9: --tree 없는 --total(topicB 체크아웃 중)은 1(형제 topicA 미포함)"

  TOPICA_TREE_SHA=$( ( cd "$REPO" && git rev-parse "topicA^{tree}" ) )
  TOTAL_TREE_SHA=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree "$TOPICA_TREE_SHA" ) 2>/dev/null )
  assert_eq "$TOTAL_TREE_SHA" "2" "T9: --total --tree <topicA 트리 SHA> = 2(합친 트리 전체를 센다)"

  TOTAL_TREE_NAME=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree topicA ) 2>/dev/null )
  assert_eq "$TOTAL_TREE_NAME" "2" "T9: --total --tree topicA(커밋 이름도 트리로 풀린다) = 2"

  TOTAL_BAD_OUT=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree deadbeefdeadbeef ) 2>/dev/null )
  TOTAL_BAD_RC=$?
  TOTAL_BAD_ERR=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree deadbeefdeadbeef ) 2>&1 >/dev/null )
  assert_eq "$TOTAL_BAD_RC" "4" "T9: --total --tree deadbeefdeadbeef → rc 4(트리로 못 푼다)"
  assert_eq "$TOTAL_BAD_OUT" "" "T9: --total --tree deadbeefdeadbeef → stdout 비었음"
  assert_contains "$TOTAL_BAD_ERR" "분모를 셀 수 없다" "T9: --total --tree deadbeefdeadbeef → stderr 에 분모를 셀 수 없다"

  TOTAL_NOVAL_OUT=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree ) 2>/dev/null )
  TOTAL_NOVAL_RC=$?
  assert_eq "$TOTAL_NOVAL_RC" "4" "T9: --total --tree(값 없음) → rc 4"
  assert_eq "$TOTAL_NOVAL_OUT" "" "T9: --total --tree(값 없음) → stdout 비었음"

  # 인자 모양이 정확히 `--total --tree <tree>`(3개) 가 아니면 조용히 무시되지 않고
  # exit 4 여야 한다. `--tree=<T>`(합쳐 쓴 값)와 뒤에 남는 인자를 각각 잰다.
  TOTAL_EQFORM_OUT=$( ( cd "$REPO" && bash "$SCRIPT" --total "--tree=$TOPICA_TREE_SHA" ) 2>/dev/null )
  TOTAL_EQFORM_RC=$?
  assert_eq "$TOTAL_EQFORM_RC" "4" "T9: --total --tree=<T>(합쳐 쓴 값) → rc 4"
  assert_eq "$TOTAL_EQFORM_OUT" "" "T9: --total --tree=<T> → stdout 비었음"

  TOTAL_EXTRA_OUT=$( ( cd "$REPO" && bash "$SCRIPT" --total --tree "$TOPICA_TREE_SHA" extra ) 2>/dev/null )
  TOTAL_EXTRA_RC=$?
  assert_eq "$TOTAL_EXTRA_RC" "4" "T9: --total --tree <tree> extra(뒤에 남는 인자) → rc 4"
  assert_eq "$TOTAL_EXTRA_OUT" "" "T9: --total --tree <tree> extra → stdout 비었음"

  # cwd 가 서브디렉토리(tests/, main·topicB 양쪽에 존재)여도(--full-tree) 루트에서
  # 부른 것과 같은 값을 낸다.
  TOTAL_SUBCWD=$( ( cd "$REPO/tests" 2>/dev/null && bash "$SCRIPT" --total --tree "$TOPICA_TREE_SHA" ) 2>/dev/null )
  assert_eq "$TOTAL_SUBCWD" "$TOTAL_TREE_SHA" "T9: 서브디렉토리 cwd 에서도 --total --tree <tree> 가 루트와 같은 값(--full-tree)"

  rm -rf "$REPO"
fi

# --- Test 10: ls-tree 자체의 실패를 삼키지 않는다 ---
#
# `ls-tree ... | grep -cE ... || true` 는 파이프 rc 가 마지막 명령(grep) 것이라, `ls-tree`
# 가 실패(예: 손상·부재 서브트리 오브젝트)해 빈 stdout 을 내도 grep 은 "0 매치"로 rc 0·
# "0" 을 낸다 — "분모를 못 셌다"가 "분모는 0" 으로 둔갑한다. 서브트리 오브젝트를 오브젝트
# 스토어에서 직접 지워 `ls-tree -r`이 그 서브트리를 재귀하다 실패하게 만든다(실측: rc 1,
# 부분 stdout + stderr 에러).
echo "== Test 10: ls-tree 실패 → exit 4(빈 결과 0으로 둔갑하지 않는다) =="
LTREPO=$(mktemp -d)
if [ -z "$LTREPO" ] || [ ! -d "$LTREPO" ]; then
  no "T10: mktemp 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$LTREPO" || exit 1
    git init -q .
    git config user.email t@t.test
    git config user.name tester
    mkdir -p sub
    echo "def test_x(): pass" > sub/test_x.py
    echo "root" > root.py
    git add -A && git commit -q -m init
  )
  LT_TREE=$( ( cd "$LTREPO" && git rev-parse HEAD^{tree} ) 2>/dev/null )
  LT_SUB_SHA=$( ( cd "$LTREPO" && git ls-tree HEAD -- sub | awk '{print $3}' ) 2>/dev/null )
  if [ -z "$LT_TREE" ] || [ -z "$LT_SUB_SHA" ]; then
    no "T10: 픽스처 준비 실패(tree 또는 서브트리 SHA 를 못 얻었다) — 이후 단언을 건너뛴다"
  else
    LT_OBJDIR="${LT_SUB_SHA:0:2}"
    LT_OBJFILE="${LT_SUB_SHA:2}"
    rm -f "$LTREPO/.git/objects/$LT_OBJDIR/$LT_OBJFILE"
    LT_OUT=$( ( cd "$LTREPO" && bash "$SCRIPT" --total --tree "$LT_TREE" ) 2>/dev/null )
    LT_RC=$?
    LT_ERR=$( ( cd "$LTREPO" && bash "$SCRIPT" --total --tree "$LT_TREE" ) 2>&1 >/dev/null )
    assert_eq "$LT_RC" "4" "T10: 서브트리 오브젝트가 없으면 --total --tree → rc 4"
    assert_eq "$LT_OUT" "" "T10: 그 경우 stdout 이 비었음(부분 결과·0 으로 둔갑하지 않는다)"
    assert_contains "$LT_ERR" "분모를 셀 수 없다" "T10: stderr 에 분모를 셀 수 없다"
  fi
  rm -rf "$LTREPO"
fi

# --- Test 11: 평범한 --total(ls-files)의 실패도 exit 4 로(부분 결과·0 이 아니다) ---
#
# `.git/index`를 깨뜨려 `git ls-files`자체가 실패(rc 128)하게 만든다. 캡처-후-카운트가
# 아니면 이 실패가 파이프 마지막 명령(grep)의 rc 0·"0"으로 삼켜진다 — Test 10 이 `--tree`
# 쪽에서 잡는 것과 같은 결함의 기본 `--total` 쪽 반쪽.
echo "== Test 11: 손상된 .git/index → 평범한 --total 도 exit 4 =="
IDXREPO=$(mktemp -d)
if [ -z "$IDXREPO" ] || [ ! -d "$IDXREPO" ]; then
  no "T11: mktemp 가 사용 가능한 경로를 내지 못했다 — 이후 단언을 건너뛴다"
else
  (
    cd "$IDXREPO" || exit 1
    git init -q .
    git config user.email t@t.test
    git config user.name tester
    mkdir -p tests
    echo "x" > tests/test_a.sh
    git add -A && git commit -q -m init
  )
  printf 'garbage' > "$IDXREPO/.git/index"
  IDX_OUT=$( ( cd "$IDXREPO" && bash "$SCRIPT" --total ) 2>/dev/null )
  IDX_RC=$?
  IDX_ERR=$( ( cd "$IDXREPO" && bash "$SCRIPT" --total ) 2>&1 >/dev/null )
  assert_eq "$IDX_RC" "4" "T11: 손상된 .git/index 에서 평범한 --total → rc 4"
  assert_eq "$IDX_OUT" "" "T11: 그 경우 stdout 이 비었음(부분 결과·0 으로 둔갑하지 않는다)"
  assert_contains "$IDX_ERR" "분모를 셀 수 없다" "T11: stderr 에 분모를 셀 수 없다"
  rm -rf "$IDXREPO"
fi

finish
