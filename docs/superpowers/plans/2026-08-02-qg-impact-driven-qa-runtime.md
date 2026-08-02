# qg 영향-구동 QA Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** quality-gates의 Runtime 게이트를 "전체 앱을 무조건 돌린다"에서 "이번 변경의 영향분을 골라 merge_base 기준선 대비로 돌린다"로 교체하고, fail이 나오면 그것이 내 변경 탓인지를 결정론적으로 귀속한다.

**Architecture:** 3분업 — **판정**(오케스트레이터/모델: 영향 스코프·계획 산문·갭 게이트) · **실행**(판단 있는 부분은 `runtime-verifier`, 판단 없는 테스트 실행은 오케스트레이터가 직접 호출하는 `run-test-selection.sh`) · **대조**(`diff-test-results.py`). 모델이 *무엇을 돌릴지* 한 번 고르면 그 선택을 결정론이 기준선·HEAD 양쪽에서 두 번 실행하고, 짝지어 귀속한다. 기준선 결과는 `(merge_base, runner, unit)` 내용주소 캐시로 상각한다.

**Tech Stack:** bash 3.2 (macOS 기본 셸) · Python 3 표준 라이브러리만 · git worktree · 기존 quality-gates 스크립트/에이전트 계약.

**설계 문서:** `docs/superpowers/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md` (AC1–AC57 / T1–T55 / M1–M26). 이 plan의 모든 task는 그 문서의 AC·T·M id를 인용한다. 인용된 id를 열어보지 않고 구현하지 말 것 — plan은 설계를 요약하지 않고 **실행**한다.

---

## Global Constraints

이 절은 모든 task의 요구사항에 **암묵적으로 포함**된다. 매 task마다 다시 읽을 필요는 없지만, 위반은 그 task의 실패다.

- **작업 위치**: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+qg-impact-driven-runtime` (브랜치 `feature/qg-impact-driven-runtime`). 절대 main 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)에서 편집하지 말 것.
- **플러그인 루트**: `plugins/quality-gates/`. 이 plan의 모든 상대 경로는 별도 명시가 없으면 이 디렉토리 기준이다.
- **셸 호환**: 모든 `.sh`는 `#!/usr/bin/env bash` + macOS 기본 bash **3.2**에서 동작해야 한다. `mapfile`/`readarray`/연관배열(`declare -A`)/`${var^^}` 금지. 빈 배열을 `set -u` 아래서 `"${arr[@]}"`로 전개하면 bash 3.2가 에러를 내므로 전개 전에 `[[ ${#arr[@]} -eq 0 ]]` 가드를 둔다.
- **Python 의존성 0**: 표준 라이브러리만. `PyYAML`·`jq` 금지 (대상 레포에 없을 수 있음). 생성 파일 read는 **반드시** `encoding="utf-8"` 명시 — non-UTF-8 locale에서 조용히 fail-open된다.
- **바이트 무변경 계약** (AC21/AC22): `scripts/detect-runtime.sh` 전체, `scripts/qg-worktree.sh`의 `create-sandbox)` · `mutation-guard)` case 본문은 **한 바이트도** 바꾸지 않는다.
- **증설 금지 3종** (AC24/AC25/AC26): 신규 훅 0 · `hooks/hooks.json` 항목 수 불변 · `agents/` 파일 수 불변 · verdict 토큰 집합은 `PASS`/`FAIL`/`SKIP_WITH_EVIDENCE`/`NEEDS_RESOLUTION` 4종 불변.
- **신규 스크립트는 정확히 5개**: `resolve-baseline.sh` · `run-test-selection.sh` · `baseline-cache.sh` · `diff-test-results.py` · `check_qa_ledger.py`. 6번째 프로덕션 스크립트(공용 lib 포함)를 만들지 말 것 — AC3/AC30/T32/T33이 "5종"을 센다. 특히 `run-test-selection.sh`의 어댑터 표는 **한 파일이 단독 소유**해야 한다(AC38: 오케스트레이터 쪽 재구현 0회).
- **버전**: `.claude-plugin/plugin.json`을 `2.14.3` → `3.0.0`으로 major bump (AC29). 테스트는 major digit만 핀하고 patch digit은 unpin한다(리터럴 `"version": "3.0.0"` 핀 금지 — doc-only bump마다 stale-red).
- **문서 언어**: CHANGELOG/README는 Korean-primary (`scripts/check-changelog-korean-primary.py`가 검사).
- **커밋**: Conventional Commits, scope는 `quality-gates`. 예: `feat(quality-gates): resolve-baseline.sh — 공유 baseline resolution`.
- **테스트 실행 위치**: 리포 루트.
  - bash: `bash plugins/quality-gates/tests/<name>.sh`
  - python: **`python3 -m pytest plugins/quality-gates/tests/test_*.py -q`** (전체 91 tests).
    개별 파일은 `python3 -m pytest plugins/quality-gates/tests/<name>.py -q`.

  > **`python3 <file>.py` 직접 실행 금지 — fail-open이다.** 이 디렉토리의 17개 파일 중
  > **6개**(`test_adversarial_behavior` · `test_agent_stub_harness` · `test_hook_cwd_contract` ·
  > `test_runtime_verifier_behavior` · `test_security_reviewer_behavior` ·
  > `test_test_scope_validator_behavior`)는 pytest 스타일 bare 함수라 `unittest.TestCase`가
  > 없다. 직접 실행하면 **0개 테스트를 돌리고 exit 0**을 낸다(5개는 `__main__` 가드조차 없다).
  > `python3 -m unittest`도 같은 이유로 이 6개에서 0개를 수집한다. 두 방법 다 **29개 테스트를
  > 안 돌리고 "통과"라고 보고**한다 — 이 설계가 러너 감지에서 막으려는 바로 그 누락 방향 실패를
  > 검증 하니스 자신이 저지르는 것이다. `-q` 출력의 **총계 숫자**를 매번 확인할 것.
  >
  > `python3 -m pytest plugins/quality-gates/tests/`(디렉토리 통째)도 금지 — `tests/fixtures/`
  > 아래 픽스처 테스트를 수집해 collection error 3건으로 죽는다. 반드시 `test_*.py` glob.
- **기존 red 베이스라인** (2026-08-02 재측정): bash 78개 중 **6개 red**, python **91 tests 전부 green**. red 6종:
  `test_codex_backward_compat.sh` · `test_codex_reviewer_frontmatter.sh` · `test_consent_marker_write_failure.sh` · `test_sandbox_enforced.sh` · `test_security_reviewer_kill_switch.sh` · `test_skill_codex_skip_prose.sh`.
  **이 6개는 이 작업 이전부터 빨갛다.** 여기에 7번째를 추가하면 그것은 회귀다. 매 task 종료 시 이 목록과 대조한다.
- **락에는 이빨이 있어야 한다**: grep 기반 회귀 락을 추가할 때는 (a) 헤딩이 아니라 **본문에만** 존재하는 문구를 쓰고, (b) 그 문구를 지운 mutation이 실제로 RED가 되는지 손으로 확인한 뒤 되돌린다. 통과하는 assert는 모양만으로 이빨을 증명하지 못한다.

---

## File Structure

### 신규 프로덕션 파일 (5)

| 경로 | 단일 책임 |
|---|---|
| `scripts/resolve-baseline.sh` | `base` / `base_ref` / `merge_base` / `degraded` 4키만 emit. 그 외 아무 판정도 안 함. |
| `scripts/run-test-selection.sh` | 러너 어댑터 8종의 **유일 소유자**. `detect`(감지) / `assign`(파일→unit 배정) / `run`(결정론 실행) 3 서브커맨드. |
| `scripts/baseline-cache.sh` | `(merge_base, runner, unit)` 내용주소 캐시의 `get`/`put`. 조회·검증·부분적중·원자성·손상 처리를 전부 소유. |
| `scripts/diff-test-results.py` | 기준선×HEAD 짝짓기 → 귀속 8종(어댑터별) + `--aggregate`(어댑터 간 집계). |
| `scripts/check_qa_ledger.py` | LD7 원장의 **구조만** 검사 (floor 5키 + derived). 의미 판정 없음. |

### 수정 파일 (7 + 문서 3)

| 경로 | 무엇 |
|---|---|
| `scripts/check-review-scope.sh` | baseline resolution을 `resolve-baseline.sh`에 위임. **출력 5키 + exit 0 계약 불변**. |
| `scripts/compute-test-scope-candidates.sh` | `main` 하드코딩 제거 + `--total` 모드 추가. |
| `scripts/qg-worktree.sh` | `create-baseline` case 절 **추가만**. |
| `scripts/qg-gc.py` | 세션 폴더 식별을 charset → **내용 기반**으로. |
| `scripts/check-allowed-tools-order.sh` | `EXPECTED_ORDER`에 신규 5종 등재. |
| `skills/quality-pipeline/SKILL.md` | Runtime 게이트 전면 개정 + `allowed-tools` 5종 추가 + 락 이전. |
| `agents/runtime-verifier.md` | 페르소나 개정 — 테스트 실행/deps 설치를 책임에서 제외. |
| `.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` | major bump + 항목 + 컴포넌트 트리·Principles Instantiated. |

### 신규 테스트 파일 (9) + 확장 (2)

```
tests/test_resolve_baseline.sh              # T2 T3 T4 T29 · M9
tests/test_run_test_selection.sh            # T7 T35 T36a T43 T50 T52 T54 · M10 M16 M26
tests/test_runner_adapters.sh               # T25 T34 T37 T41 T42 T47 · M14 M17 M20 M23
tests/test_baseline_cache.sh                # T6 T23 T24 T36b T38 · M7 M13 M18
tests/test_diff_test_results.py             # T9 T10 T11 T12 T13 T27 T39 T45 · M4 M22
tests/test_qa_ledger.sh                     # T14 T15 · M8
tests/test_runtime_verdict_precedence.sh    # T8 T21 T26 T31 T40 T51 T53 T55 · M5 M6 M11 M15 M19 M24 M25
tests/test_runtime_contract_invariance.sh   # T5 T16 T17 T18
tests/test_impact_runtime_docs.sh           # T20 T33
tests/test_qg_gc.py                         # (확장) T19 T49 · M1 M2
tests/harness/test_skill_orchestration_behavior.sh  # (확장) T1 T22 T28 T30 T44 T46 T48 · M3 M12
```

---

## Task 1: 공유 baseline resolution (`resolve-baseline.sh` + 두 소비자)

**Files:**
- Create: `plugins/quality-gates/scripts/resolve-baseline.sh`
- Create: `plugins/quality-gates/tests/test_resolve_baseline.sh`
- Modify: `plugins/quality-gates/scripts/check-review-scope.sh:31-65` (base resolution 블록을 위임으로 교체)
- Modify: `plugins/quality-gates/scripts/compute-test-scope-candidates.sh:26-37` (`main` 하드코딩 제거 + `--total`)

**Interfaces:**
- Consumes: 없음 (첫 task, 독립)
- Produces: `scripts/resolve-baseline.sh` — 인자 없음, 항상 exit 0, stdout 4줄:
  ```
  base: <display-name|->
  base_ref: <git-usable-ref|->
  merge_base: <full-sha|->
  degraded: yes|no
  ```
  `degraded: yes`면 나머지 3키는 전부 `-`. Task 11(SKILL R-init)과 Task 5(캐시 키)가 `merge_base`를 소비한다.
  `scripts/compute-test-scope-candidates.sh --total` — stdout에 정수 한 줄(리포 전체 테스트 파일 수). Task 11의 계획 산문 분모 M.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_resolve_baseline.sh`

```bash
#!/usr/bin/env bash
# test_resolve_baseline.sh — scripts/resolve-baseline.sh (design §5.2 R-init, AC4/AC5/AC6/AC37).
# 각 케이스는 mktemp 아래 일회용 git 레포를 만든다 (fail-closed: 실제 레포에서 git 실행 금지).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RESOLVE="$PLUGIN_ROOT/scripts/resolve-baseline.sh"
REVIEW_SCOPE="$PLUGIN_ROOT/scripts/check-review-scope.sh"
CANDIDATES="$PLUGIN_ROOT/scripts/compute-test-scope-candidates.sh"

PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
field() { printf '%s\n' "$2" | awk -v k="$1:" '$1 == k { print $2 }'; }

mk_repo() {   # main + feature(1 commit ahead), CWD = repo
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo base > a.txt; git add a.txt; git commit -qm base
  git checkout -q -b feature
  echo work >> a.txt; git commit -qam work
}
cleanup() { cd / && rm -rf "$REPO"; }

# T2-a: 정상 — 4키 + degraded:no + merge_base가 main의 tip
case_normal() {
  mk_repo
  local out; out=$(bash "$RESOLVE")
  local expect; expect=$(git rev-parse main)
  if [[ "$(field base "$out")" == "main" \
     && "$(field base_ref "$out")" == "main" \
     && "$(field merge_base "$out")" == "$expect" \
     && "$(field degraded "$out")" == "no" ]]; then
    pass "정상 레포 → base/base_ref/merge_base/degraded 4키"
  else fail "정상 (got: $out)"; fi
  cleanup
}

# T2-b: detached HEAD → degraded
case_detached() {
  mk_repo
  git checkout -q --detach HEAD
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field merge_base "$out")" == "-" ]]; then
    pass "detached HEAD → degraded:yes, merge_base:-"
  else fail "detached (got: $out)"; fi
  cleanup
}

# T2-c: shallow clone → degraded  (M9: shallow 감지를 지우면 여기가 RED)
case_shallow() {
  mk_repo
  local src="$REPO" dst; dst=$(mktemp -d)
  git clone -q --depth 1 "file://$src" "$dst/s" 2>/dev/null
  cd "$dst/s" || { fail "shallow clone 실패"; rm -rf "$dst"; cleanup; return; }
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" ]]; then
    pass "shallow clone → degraded:yes"
  else fail "shallow (got: $out)"; fi
  cd / && rm -rf "$dst"; cleanup
}

# T2-d: base 미해결 (main/master 없음) → degraded
case_no_base() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b topic
  echo x > a.txt; git add a.txt; git commit -qm x
  local out; out=$(bash "$RESOLVE")
  if [[ "$(field degraded "$out")" == "yes" && "$(field base "$out")" == "-" ]]; then
    pass "base 미해결 → degraded:yes"
  else fail "no-base (got: $out)"; fi
  cleanup
}

# T3: 두 소비자에 `main` 하드코딩 0회 + 실제 호출 존재
case_no_hardcoded_main() {
  local bad=0
  # `main`을 baseline으로 쓰는 리터럴 패턴만 검사 (주석/산문의 'main' 단어는 무관)
  grep -nE '(verify --quiet main|main\.\.\.HEAD|main\.\.HEAD|log --oneline main)' \
       "$REVIEW_SCOPE" "$CANDIDATES" && bad=1
  if [[ $bad -eq 0 ]]; then pass "두 소비자에 main 하드코딩 baseline 0회"
  else fail "main 하드코딩 잔존"; fi
  if grep -q 'resolve-baseline.sh' "$REVIEW_SCOPE" && grep -q 'resolve-baseline.sh' "$CANDIDATES"; then
    pass "두 소비자가 resolve-baseline.sh를 실제 호출"
  else fail "resolve-baseline.sh 호출 부재"; fi
}

# T4: check-review-scope.sh 출력 계약 불변 (5키 + exit 0)
case_review_scope_contract() {
  mk_repo
  local out rc; out=$(bash "$REVIEW_SCOPE"); rc=$?
  local keys; keys=$(printf '%s\n' "$out" | awk -F: '{print $1}' | tr '\n' ',')
  if [[ $rc -eq 0 && "$keys" == "changes_exist,branch_ahead_count,worktree_dirty,base,degraded," ]]; then
    pass "check-review-scope 5키 순서 + exit 0 불변"
  else fail "check-review-scope 계약 (rc=$rc keys=$keys)"; fi
  cleanup
}

# T29: --total이 리포 전체 테스트 파일 수를 emit
case_total() {
  mk_repo
  mkdir -p tests src
  : > tests/test_a.py; : > tests/test_b.py; : > src/plain.py
  git add -A; git commit -qm tests
  local out; out=$(bash "$CANDIDATES" --total)
  if [[ "$out" == "2" ]]; then pass "--total → 2 (테스트 2, 비테스트 1)"
  else fail "--total (got: '$out', expected 2)"; fi
  cleanup
}

for c in case_normal case_detached case_shallow case_no_base \
         case_no_hardcoded_main case_review_scope_contract case_total; do
  echo "== $c"; $c
done
echo "── resolve-baseline: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_resolve_baseline.sh`
Expected: FAIL — `resolve-baseline.sh: No such file or directory` (7개 케이스 대부분 red)

- [ ] **Step 3: `resolve-baseline.sh` 작성**

`plugins/quality-gates/scripts/resolve-baseline.sh` (신규, `chmod +x`):

```bash
#!/usr/bin/env bash
# resolve-baseline.sh — 공유 baseline resolution (design 2026-08-01 §5.2 R-init, AC4).
# check-review-scope.sh v2.6.0→v2.7.0 3라운드 하드닝의 산물을 단일 모듈로 추출:
# origin/HEAD → origin/main → origin/master → local main → local master 순 resolution
# + merge-base + shallow/detached 감지.
#
# Output (stdout, 항상 4줄):
#   base:       <display short-name | ->      사람에게 보여줄 이름
#   base_ref:   <git-usable ref | ->          존재가 확인된 ref (remote-tracking일 수 있음)
#   merge_base: <full sha | ->                git merge-base <base_ref> HEAD
#   degraded:   yes|no                        yes면 위 3키는 전부 '-'
#
# Exit: 항상 0 (degraded: yes가 fail-open 상태를 실어 나른다). 인자 없음. read-only.
set -u

emit_degraded() {
  echo "base: -"
  echo "base_ref: -"
  echo "merge_base: -"
  echo "degraded: yes"
  exit 0
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD  >/dev/null 2>&1 || emit_degraded
# detached HEAD → 비교할 브랜치 컨텍스트 없음 → degraded.
git symbolic-ref --quiet HEAD        >/dev/null 2>&1 || emit_degraded
# shallow clone → 잘린 히스토리 → merge-base가 grafted boundary로 조용히 resolve될 수 있음.
[[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]] && emit_degraded

base=""; base_ref=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"; base_ref="$ref"
elif git rev-parse --verify --quiet refs/remotes/origin/main   >/dev/null 2>&1; then
  base="main";   base_ref="origin/main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"; base_ref="origin/master"
elif git rev-parse --verify --quiet refs/heads/main            >/dev/null 2>&1; then
  base="main";   base_ref="main"
elif git rev-parse --verify --quiet refs/heads/master          >/dev/null 2>&1; then
  base="master"; base_ref="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

echo "base: $base"
echo "base_ref: $base_ref"
echo "merge_base: $merge_base"
echo "degraded: no"
exit 0
```

- [ ] **Step 4: `check-review-scope.sh`를 위임으로 교체**

`plugins/quality-gates/scripts/check-review-scope.sh`의 31–65행(`# --- git sanity …`부터 `[[ -n "$merge_base" ]] || emit_degraded`까지)을 통째로 아래로 교체한다. **출력부(98–103행)와 `emit_degraded()`는 건드리지 않는다** — AC6이 5키 계약을 잠근다.

```bash
# --- baseline resolution은 resolve-baseline.sh가 단독 소유 (design §5.2 R-init).
#     git sanity(비-git/HEAD 부재/detached/shallow) + base 후보 순서 + merge-base가
#     전부 그 스크립트 안에 있고, 이 스크립트는 4키를 읽어 fail-open 판정만 승계한다.
#     여기서 로직을 복제하면 두 소비자가 서로 다른 baseline을 보게 된다 (C2 재발). ---
_rb_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_rb_out=$("$_rb_dir/resolve-baseline.sh" 2>/dev/null) || emit_degraded
_rb_field() { printf '%s\n' "$_rb_out" | awk -v k="$1:" '$1 == k { print $2 }'; }
[[ "$(_rb_field degraded)" == "no" ]] || emit_degraded
base=$(_rb_field base)
merge_base=$(_rb_field merge_base)
[[ -n "$base" && -n "$merge_base" && "$merge_base" != "-" ]] || emit_degraded
```

- [ ] **Step 5: `compute-test-scope-candidates.sh` 수정**

(a) 26–32행의 `REVIEW_RANGE` 블록을 교체:

```bash
# Review range — baseline은 resolve-baseline.sh가 소유 (C2 수정: `main` 하드코딩 +
# merge-base 부재를 제거). 워킹트리가 깨끗할 때만 브랜치 범위를 본다 (기존 동작 유지).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ]; then
  RB_OUT=$("$SCRIPT_DIR/resolve-baseline.sh" 2>/dev/null || true)
  RB_DEGRADED=$(printf '%s\n' "$RB_OUT" | awk '$1 == "degraded:" { print $2 }')
  RB_MERGE_BASE=$(printf '%s\n' "$RB_OUT" | awk '$1 == "merge_base:" { print $2 }')
  if [ "$RB_DEGRADED" = "no" ] && [ -n "$RB_MERGE_BASE" ] && [ "$RB_MERGE_BASE" != "-" ]; then
    REVIEW_RANGE="$RB_MERGE_BASE..HEAD"
  fi
fi
```

(b) `TESTRE` 정의(34행) **바로 뒤**에 `--total` 모드를 추가한다. 같은 정규식을 재사용하는 것이 요점이다 — 분자(선택 수)와 분모(전체 수)가 다른 기준으로 세어지면 비율이 무의미해진다 (AC37):

```bash
# --total: 리포 전체 테스트 파일 수를 emit (계획 산문의 분모 M — AC37).
# 후보 산출과 **같은 TESTRE**를 전 트리에 적용한다. 분모가 모델 자기보고이면
# 과선택이 심해질수록 분모도 같이 부풀려 비율이 정상으로 보인다.
if [ "${1:-}" = "--total" ]; then
  git ls-files | grep -cE "$TESTRE" || true
  exit 0
fi
```

> **주의**: `grep -c`는 0건일 때 `0`을 출력하고 exit 1을 낸다. `|| true`가 없으면 `set -u`만 걸린 이 스크립트에서도 파이프라인 종료 코드가 새어 나간다.

- [ ] **Step 6: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_resolve_baseline.sh`
Expected: PASS — `resolve-baseline: 7 passed, 0 failed`

Run: `bash plugins/quality-gates/tests/test_check_review_scope.sh` (기존 스위트 — AC6 회귀 방어)
Expected: PASS (변경 전과 동일한 카운트)

Run: `bash plugins/quality-gates/tests/test_compute_test_scope_candidates.sh`
Expected: PASS

- [ ] **Step 7: M9 mutation 확인 (손으로, 되돌릴 것)**

`resolve-baseline.sh`의 shallow 감지 줄을 주석 처리 → `bash plugins/quality-gates/tests/test_resolve_baseline.sh`가 `case_shallow`에서 **RED**여야 한다. 확인 후 주석을 되돌린다.

- [ ] **Step 8: 커밋**

```bash
git add plugins/quality-gates/scripts/resolve-baseline.sh \
        plugins/quality-gates/scripts/check-review-scope.sh \
        plugins/quality-gates/scripts/compute-test-scope-candidates.sh \
        plugins/quality-gates/tests/test_resolve_baseline.sh
git commit -m "feat(quality-gates): resolve-baseline.sh — 공유 baseline resolution + --total 분모

check-review-scope.sh의 하드닝된 resolution(origin/HEAD→main→master→local,
merge-base, shallow/detached 감지)을 단일 모듈로 추출하고 두 소비자가 함께 쓴다.
compute-test-scope-candidates.sh의 \`main\` 하드코딩 + merge-base 부재(C2)를 닫고,
계획 산문의 분모 M을 같은 TESTRE로 산출하는 --total 모드를 추가한다.

AC4 AC5 AC6 AC37 · T2 T3 T4 T29 · M9"
```

---

## Task 2: `run-test-selection.sh detect` — 러너 어댑터 8종

**Files:**
- Create: `plugins/quality-gates/scripts/run-test-selection.sh` (이 task는 `detect`만; `assign`/`run`은 Task 3/4)
- Create: `plugins/quality-gates/tests/test_runner_adapters.sh`

**Interfaces:**
- Consumes: 없음 (독립 — Task 1과 병행 가능)
- Produces:
  ```
  run-test-selection.sh detect <worktree-abs>
    stdout: 감지된 어댑터 하나당 3줄, 어댑터 간 빈 줄 구분, §5.9 표 순서
      runner: pytest|unittest|shell|jest|vitest|go|cargo|make|npm-script
      granularity: file|package|bulk
      setup_cmd: <결정론적 설치 명령 | ->
    exit: 0 (감지 0개 = 빈 stdout + exit 0) · 2 = 사용 오류
  ```
  Task 3(`assign`)·Task 4(`run`)이 같은 파일 안에서 `detect_set()`을 재사용한다. Task 11(SKILL R1a/R4②)이 호출한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_runner_adapters.sh`

```bash
#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh detect의 어댑터 8종 (design §5.9).
# AC34 AC38 AC45 AC56(detect) · T25 T34 T42 · M14 M20
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

PASS=0; FAIL=0; W=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkw()  { W=$(mktemp -d) || exit 1; }
rmw()  { cd / && rm -rf "$W"; }
# runners <worktree> → 감지된 runner 이름을 개행으로
runners() { bash "$RTS" detect "$1" | awk '$1 == "runner:" { print $2 }'; }
gran_of() { bash "$RTS" detect "$1" | awk -v r="$2" '
  $1=="runner:"{cur=$2} $1=="granularity:" && cur==r {print $2}'; }

# T34/T25: 8 어댑터 각각 감지
case_pytest()   { mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "pytest" ]] && pass "pytest.ini → pytest" || fail "pytest ($(runners "$W"))"; rmw; }
case_unittest() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "unittest" ]] && pass "설정 없는 test_*.py → unittest" || fail "unittest ($(runners "$W"))"; rmw; }
case_shell()    { mkw; mkdir -p "$W/tests"; printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  [[ "$(runners "$W")" == "shell" ]] && pass "실행비트 tests/*.sh → shell" || fail "shell ($(runners "$W"))"; rmw; }
case_jest()     { mkw; printf '{"devDependencies":{"jest":"29"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "jest" ]] && pass "devDeps.jest → jest" || fail "jest ($(runners "$W"))"; rmw; }
case_vitest()   { mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "vitest" ]] && pass "devDeps.vitest → vitest" || fail "vitest ($(runners "$W"))"; rmw; }
case_go()       { mkw; printf 'module x\n' > "$W/go.mod"
  [[ "$(runners "$W")" == "go" && "$(gran_of "$W" go)" == "package" ]] \
    && pass "go.mod → go(package)" || fail "go ($(runners "$W"))"; rmw; }
case_cargo()    { mkw; printf '[package]\nname="x"\n' > "$W/Cargo.toml"
  [[ "$(runners "$W")" == "cargo" && "$(gran_of "$W" cargo)" == "bulk" ]] \
    && pass "Cargo.toml → cargo(bulk)" || fail "cargo ($(runners "$W"))"; rmw; }
case_make()     { mkw; printf 'test:\n\t@true\n' > "$W/Makefile"
  [[ "$(runners "$W")" == "make" ]] && pass "Makefile test: → make" || fail "make ($(runners "$W"))"; rmw; }
case_npmscript(){ mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "npm-script" ]] && pass "scripts.test(비-jest/vitest) → npm-script" || fail "npm-script ($(runners "$W"))"; rmw; }

# T54(detect 절반) + AC56: 감지 0개 → 빈 stdout + exit 0
case_zero_adapters() {
  mkw; : > "$W/README.md"
  local out rc; out=$(bash "$RTS" detect "$W"); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then pass "감지 0개 → 빈 stdout + exit 0"
  else fail "0-어댑터 (rc=$rc out='$out')"; fi
  rmw
}

# T42 + M20: 폴리글랏 — 두 어댑터가 **함께** 반환된다 (단일-어댑터 픽스처로는 못 잡는다)
case_polyglot() {
  mkw; mkdir -p "$W/tests"
  : > "$W/tests/test_a.py"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  local got; got=$(runners "$W" | sort | tr '\n' ',')
  if [[ "$got" == "shell,unittest," ]]; then pass "폴리글랏 → 어댑터 2개 모두 반환"
  else fail "폴리글랏 (got: $got, expected shell,unittest,)"; fi
  rmw
}

# AC54: pytest/unittest 상호배타 · jest/vitest 판별불가 → npm-script 폴백
case_conflict_python() {
  mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "pytest," ]] && pass "pytest 설정 존재 → unittest 미주장" || fail "py 충돌 ($got)"
  rmw
}
case_conflict_js_ambiguous() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"run-tests"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "npm-script," ]] && pass "jest+vitest 판별불가 → npm-script 폴백" || fail "js 모호 ($got)"
  rmw
}
case_conflict_js_resolved() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"vitest run"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "vitest," ]] && pass "scripts.test가 vitest 호출 → vitest" || fail "js 해소 ($got)"
  rmw
}

# T34 후반 + AC38: SKILL.md에 어댑터 감지 조건 재구현이 없다
# (body-unique한 감지 조건 문자열들이 SKILL.md에 등장하면 표를 복제한 것)
case_no_reimpl_in_skill() {
  local bad=0 s
  for s in 'devDependencies' 'pytest.ini' 'Cargo.toml' 'go.mod'; do
    if grep -qF "$s" "$SKILL"; then echo "    SKILL.md가 감지 조건 '$s'를 담고 있음"; bad=1; fi
  done
  [[ $bad -eq 0 ]] && pass "SKILL.md에 어댑터 감지 표 재구현 0회" || fail "SKILL.md 감지 표 재구현"
}

for c in case_pytest case_unittest case_shell case_jest case_vitest case_go case_cargo \
         case_make case_npmscript case_zero_adapters case_polyglot \
         case_conflict_python case_conflict_js_ambiguous case_conflict_js_resolved \
         case_no_reimpl_in_skill; do
  echo "== $c"; $c
done
echo "── runner adapters: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh`
Expected: FAIL — `run-test-selection.sh: No such file or directory`

- [ ] **Step 3: `run-test-selection.sh`의 detect 골격 작성**

`plugins/quality-gates/scripts/run-test-selection.sh` (신규, `chmod +x`):

```bash
#!/usr/bin/env bash
# run-test-selection.sh — 결정론 테스트 러너 어댑터 표면 (design 2026-08-01 §5.4/§5.9).
#
#   detect <worktree-abs>                          → 어댑터 집합 (3줄 × N, 빈 줄 구분)
#   assign <worktree-abs>   < candidate-files      → <unit>\t<runner|unclaimed>\t<granularity>
#   run    <worktree-abs> <runner> <mode> <unit>…  → <unit>\t<status>\t<exit-code>  (총 함수)
#
# 이 스크립트는 어댑터 표의 **유일 소유자**다. 오케스트레이터가 감지 조건이나
# unit 변환을 재구현하는 경로는 없다 (AC38 / AC52).
#
# Exit: 0 = 정상 · 2 = 사용 오류 · 3 = 어댑터 사용 불가(run 전용, 전 unit `unrun` 동반)
set -u

die() { echo "run-test-selection: $*" >&2; exit 2; }

# ── 어댑터 표 (§5.9). 배열 순서 = 소유권 충돌 해소 순서이자 detect 출력 순서. ──
granularity_of() {
  case "$1" in
    pytest|unittest|shell|jest|vitest) echo file ;;
    go)                                echo package ;;
    cargo|make|npm-script)             echo bulk ;;
    *) die "unknown runner: $1" ;;
  esac
}

# package.json의 한 필드를 안전하게 읽는다. grep으로 JSON을 긁으면 description에
# 들어간 "jest" 같은 문자열이 오탐이 되므로 파서를 쓴다. python3 부재 시 실패(=미감지)로
# 떨어지는 것이 fail-closed 방향이다.
pkg_field() {   # pkg_field <worktree> <dotted.path> → 값 출력, 없으면 exit 1
  python3 - "$1/package.json" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        cur = json.load(fh)
except Exception:
    sys.exit(1)
for key in sys.argv[2].split("."):
    if not isinstance(cur, dict) or key not in cur:
        sys.exit(1)
    cur = cur[key]
print(cur if isinstance(cur, str) else "1")
PY
}

has_pytest_config() {
  local w=$1
  [[ -f "$w/pytest.ini" ]] && return 0
  [[ -f "$w/tox.ini"    ]] && grep -q '^\[pytest\]'      "$w/tox.ini"    2>/dev/null && return 0
  [[ -f "$w/setup.cfg"  ]] && grep -q '^\[tool:pytest\]' "$w/setup.cfg"  2>/dev/null && return 0
  [[ -f "$w/pyproject.toml" ]] && grep -q '^\[tool\.pytest' "$w/pyproject.toml" 2>/dev/null && return 0
  return 1
}

has_python_tests() {
  find "$1" -name .git -prune -o -type f \
       \( -name 'test_*.py' -o -name '*_test.py' \) -print 2>/dev/null | head -1 | grep -q .
}

has_exec_shell_tests() {
  find "$1" -name .git -prune -o -type f -perm -u+x -name '*.sh' -path '*/tests/*' \
       -print 2>/dev/null | head -1 | grep -q .
}

setup_cmd_of() {   # setup_cmd_of <worktree> <runner>
  local w=$1
  case "$2" in
    pytest|unittest)
      if   [[ -f "$w/uv.lock"          ]]; then echo 'uv sync --frozen'
      elif [[ -f "$w/poetry.lock"      ]]; then echo 'poetry install --no-interaction'
      elif [[ -f "$w/requirements.txt" ]]; then echo 'python3 -m pip install -q -r requirements.txt'
      else echo '-'; fi ;;
    jest|vitest|npm-script)
      if   [[ -f "$w/pnpm-lock.yaml"    ]]; then echo 'pnpm install --frozen-lockfile'
      elif [[ -f "$w/yarn.lock"         ]]; then echo 'yarn install --frozen-lockfile'
      elif [[ -f "$w/package-lock.json" ]]; then echo 'npm ci'
      else echo 'npm install --no-audit --no-fund'; fi ;;
    shell|go|cargo|make) echo '-' ;;
    *) die "unknown runner: $2" ;;
  esac
}

# detect_set <worktree> → 감지된 runner 이름을 표 순서대로 한 줄씩.
# 감지된 어댑터는 **모두** 반환한다 — 우선순위 1위만 고르면 폴리글랏 레포에서
# 나머지 러너의 테스트가 floor에서 조용히 누락된다 (AC45; 이 레포 실측: .sh 130개).
detect_set() {
  local w=$1 out=""
  # 파이썬: pytest 설정 > (tests/ + pytest 설치) > unittest. 상호배타 (AC54).
  if has_pytest_config "$w"; then
    out="$out pytest"
  elif [[ -d "$w/tests" ]] && python3 -c 'import pytest' >/dev/null 2>&1 && has_python_tests "$w"; then
    out="$out pytest"
  elif has_python_tests "$w"; then
    out="$out unittest"
  fi

  has_exec_shell_tests "$w" && out="$out shell"

  # jest vs vitest: 둘 다 devDeps에 있으면 scripts.test가 호출하는 쪽.
  # 판별 불가면 **둘 다 버리고** npm-script로 폴백 — 잘못된 러너로 돌리느니
  # 그 프로젝트가 정의한 명령을 쓴다 (AC54).
  local has_jest=0 has_vitest=0 js_pick="" test_script=""
  pkg_field "$w" devDependencies.jest   >/dev/null 2>&1 && has_jest=1
  pkg_field "$w" devDependencies.vitest >/dev/null 2>&1 && has_vitest=1
  if [[ $has_jest -eq 1 && $has_vitest -eq 1 ]]; then
    test_script=$(pkg_field "$w" scripts.test 2>/dev/null || true)
    case "$test_script" in
      *vitest*) js_pick=vitest ;;
      *jest*)   js_pick=jest ;;
      *)        js_pick="" ;;
    esac
  elif [[ $has_jest   -eq 1 ]]; then js_pick=jest
  elif [[ $has_vitest -eq 1 ]]; then js_pick=vitest
  fi
  [[ -n "$js_pick" ]] && out="$out $js_pick"

  [[ -f "$w/go.mod"     ]] && out="$out go"
  [[ -f "$w/Cargo.toml" ]] && out="$out cargo"
  [[ -f "$w/Makefile"   ]] && grep -qE '^test:' "$w/Makefile" 2>/dev/null && out="$out make"
  if [[ -z "$js_pick" ]] && pkg_field "$w" scripts.test >/dev/null 2>&1; then
    out="$out npm-script"
  fi

  local r
  for r in $out; do echo "$r"; done
}

case "${1:-}" in
  detect)
    [[ $# -eq 2 ]] || die "usage: detect <worktree-abs>"
    w=$2
    [[ -d "$w" ]] || die "not a directory: $w"
    first=1
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      [[ $first -eq 1 ]] || echo
      first=0
      echo "runner: $r"
      echo "granularity: $(granularity_of "$r")"
      echo "setup_cmd: $(setup_cmd_of "$w" "$r")"
    done < <(detect_set "$w")
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|assign|run)"
    ;;
esac
```

> **왜 `for r in $out`인가** — bash 3.2에는 `readarray`가 없고, runner 이름에는 공백이 없어 word-split이 안전하다. 이 스크립트는 `#!/usr/bin/env bash`로 실행되므로 zsh의 다른 word-split 규칙에 노출되지 않는다. 테스트도 반드시 `bash <path>`로 호출할 것.

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh`
Expected: PASS — `runner adapters: 15 passed, 0 failed`
(단, `case_no_reimpl_in_skill`은 SKILL.md가 아직 미개정이라 이미 통과한다. Task 11 이후 재확인한다.)

- [ ] **Step 5: M20 mutation 확인 (손으로, 되돌릴 것)**

`detect_set()` 끝의 출력 루프를 `for r in $out; do echo "$r"; break; done`(첫 어댑터만)으로 바꾼다 → `case_polyglot`이 **RED**여야 한다. 단일-어댑터 케이스들은 여전히 GREEN이라는 것이 요점이다 — 폴리글랏 픽스처 없이는 이 결함을 못 잡는다. 확인 후 되돌린다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh \
        plugins/quality-gates/tests/test_runner_adapters.sh
git commit -m "feat(quality-gates): run-test-selection.sh detect — 러너 어댑터 8종

감지 지식의 유일 소유자. 감지된 어댑터를 **집합**으로 반환해 폴리글랏 레포에서
우선순위 밖 러너가 floor에서 조용히 누락되는 경로를 봉쇄한다. 표 순서는 배제가
아니라 같은 파일 패턴을 두 어댑터가 주장할 때의 충돌 해소 순서다.

AC34 AC38 AC45 AC54 AC56(detect) · T25 T34 T42 · M14 M20"
```

---

## Task 3: `run-test-selection.sh assign` — 파일 → unit 배정

**Files:**
- Modify: `plugins/quality-gates/scripts/run-test-selection.sh` (`assign` case 추가)
- Create: `plugins/quality-gates/tests/test_run_test_selection.sh`

**Interfaces:**
- Consumes: Task 2의 `detect_set()` · `granularity_of()` (같은 파일 내부 함수)
- Produces:
  ```
  run-test-selection.sh assign <worktree-abs>   # stdin: 후보 파일 경로 (한 줄에 하나, repo-relative)
    stdout: <unit>\t<runner|unclaimed>\t<granularity>
      granularity=file    → unit = 입력 파일 경로 그대로
      granularity=package → unit = 그 파일이 속한 패키지 디렉토리 (중복 제거)
      granularity=bulk    → unit = 리터럴 BULK (흡수 어댑터 1개당 1줄)
      unclaimed           → unit = 입력 경로, granularity 열은 `file`
    stderr: 흡수하지 않은 bulk 어댑터마다 `미실행 러너: <runner>` 한 줄 (loud)
    exit: 0 · 2 = 사용 오류
  ```
  Task 4(`run`)가 이 출력의 `unit` 열을 인자로 받는다. Task 11(SKILL R1b)이 호출하고, `unclaimed` 행이 하나라도 있으면 `verification: degraded`로 라우팅한다.

**왜 스크립트가 소유하는가** — 배정을 모델(R1b)에 맡기면 (a) `assign` 없이는 AC46/AC52/AC54를 오케스트레이션과 분리해 단위 테스트할 수 없고, (b) `a/b/foo_test.go` → `a/b` 같은 순수 결정론 변환이 모델 판단에 섞인다. **모델이 고르는 것은 후보 *파일*이고, 그것을 unit으로 바꾸는 것은 스크립트다.**

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_run_test_selection.sh`

```bash
#!/usr/bin/env bash
# test_run_test_selection.sh — assign/run 서브커맨드 (design §5.4).
# AC9 AC39 AC40 AC46 AC52 AC54 AC56(run) · T7 T35 T36a T43 T50 T52 T54(run) · M10 M16 M26
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
TAB=$'\t'

PASS=0; FAIL=0; W=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkw()  { W=$(mktemp -d) || exit 1; }
rmw()  { cd / && rm -rf "$W"; }

# ── assign ──────────────────────────────────────────────────────────────────

# T50 + M26: go 픽스처 — 파일 경로가 패키지 디렉토리로 축약되고 중복이 제거된다.
# 동종(file-granularity) 레포에서는 배정을 모델이 해도 결과가 같아 이 결함을 못 잡는다.
case_assign_go_package() {
  mkw; printf 'module x\n' > "$W/go.mod"
  mkdir -p "$W/pkg/a" "$W/pkg/b"
  : > "$W/pkg/a/one_test.go"; : > "$W/pkg/a/two_test.go"; : > "$W/pkg/b/three_test.go"
  local out; out=$(printf 'pkg/a/one_test.go\npkg/a/two_test.go\npkg/b/three_test.go\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "pkg/a${TAB}go${TAB}package;pkg/b${TAB}go${TAB}package;" ]]; then
    pass "go: 3파일 → 2패키지 unit (중복 제거)"
  else fail "go assign (got: $out)"; fi
  rmw
}

# T43 + AC46: 어느 어댑터도 주장하지 않는 unit → unclaimed (조용한 누락 0)
case_assign_unclaimed() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"     # unittest만 감지됨
  local out; out=$(printf 'tests/test_a.py\nspec/foo_spec.rb\n' \
                   | bash "$RTS" assign "$W" | sort | tr '\n' ';')
  if [[ "$out" == "spec/foo_spec.rb${TAB}unclaimed${TAB}file;tests/test_a.py${TAB}unittest${TAB}file;" ]]; then
    pass "미주장 파일 → unclaimed 행"
  else fail "unclaimed (got: $out)"; fi
  rmw
}

# T52 + AC54: bulk 어댑터 복수 감지 → 첫 하나만 흡수, 나머지는 stderr `미실행 러너`
case_assign_bulk_conflict() {
  mkw
  printf '[package]\nname="x"\n' > "$W/Cargo.toml"
  printf 'test:\n\t@true\n' > "$W/Makefile"
  local out err
  out=$(printf 'src/lib.rs\nsrc/other.rs\n' | bash "$RTS" assign "$W" 2>"$W/err.txt")
  err=$(cat "$W/err.txt")
  if [[ "$out" == "BULK${TAB}cargo${TAB}bulk" ]] && printf '%s' "$err" | grep -q '미실행 러너: make'; then
    pass "cargo+make → cargo 1행 흡수 + make는 미실행 러너로 loud"
  else fail "bulk 충돌 (out='$out' err='$err')"; fi
  rmw
}

# 잔여 흡수자가 없으면(bulk 어댑터 미감지) 잔여는 unclaimed다 — 조용히 버리지 않는다.
case_assign_residual_no_absorber() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  local out; out=$(printf 'src/main.rs\n' | bash "$RTS" assign "$W")
  [[ "$out" == "src/main.rs${TAB}unclaimed${TAB}file" ]] \
    && pass "흡수자 없음 → 잔여는 unclaimed" || fail "잔여 (got: $out)"
  rmw
}

# ── run ─────────────────────────────────────────────────────────────────────

mk_shell_repo() {   # 통과 1 + 실패 1 셸 테스트
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/ok.sh";  chmod +x "$W/tests/ok.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$W/tests/bad.sh"; chmod +x "$W/tests/bad.sh"
}

# T7 + M10 + AC9: 테스트 실패(exit 0 + `fail`)와 러너 부재(exit 3)가 **분리**된다
case_run_test_failure_vs_absent_runner() {
  mk_shell_repo
  local out rc
  out=$(bash "$RTS" run "$W" shell per-unit tests/ok.sh tests/bad.sh 2>/dev/null); rc=$?
  if [[ $rc -eq 0 ]] \
     && printf '%s\n' "$out" | grep -q "^tests/ok\.sh${TAB}pass${TAB}0$" \
     && printf '%s\n' "$out" | grep -q "^tests/bad\.sh${TAB}fail${TAB}1$"; then
    pass "테스트 실패 → exit 0 + status=fail"
  else fail "테스트 실패 분리 (rc=$rc out='$out')"; fi

  # 같은 트리에서 감지되지 않는 러너 → exit 3 + 전 unit unrun (T54 run 절반, AC56)
  out=$(bash "$RTS" run "$W" cargo bulk BULK 2>/dev/null); rc=$?
  if [[ $rc -eq 3 && "$out" == "BULK${TAB}unrun${TAB}-" ]]; then
    pass "어댑터 사용 불가 → exit 3 + 전 unit unrun"
  else fail "exit 3 (rc=$rc out='$out')"; fi
  rmw
}

# T35 + M16: **총 함수** — 입력 unit 수 == 출력 행 수 (정상 / exit 3 / 일부 absent)
case_run_total_function() {
  mk_shell_repo
  local n
  n=$(bash "$RTS" run "$W" shell per-unit tests/ok.sh tests/bad.sh tests/gone.sh 2>/dev/null \
      | wc -l | tr -d ' ')
  [[ "$n" == "3" ]] && pass "정상+absent 혼합: 3 입력 → 3 행" || fail "총 함수 정상 ($n)"
  n=$(bash "$RTS" run "$W" cargo bulk A B C 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" == "3" ]] && pass "exit 3: 3 입력 → 3 unrun 행" || fail "총 함수 exit3 ($n)"
  rmw
}

# T36a + AC40: 상태 5종 중 absent — 워크트리에 없는 unit
case_run_absent() {
  mk_shell_repo
  local out; out=$(bash "$RTS" run "$W" shell per-unit tests/gone.sh 2>/dev/null)
  [[ "$out" == "tests/gone.sh${TAB}absent${TAB}-" ]] \
    && pass "부재 unit → absent" || fail "absent (got: $out)"
  rmw
}

# AC10 지원: bulk green → 전 unit이 pass 행 (호출자가 per-unit 재실행을 건너뛸 근거)
case_run_bulk_green() {
  mk_shell_repo
  rm "$W/tests/bad.sh"
  cp "$W/tests/ok.sh" "$W/tests/ok2.sh"
  local out passes
  out=$(bash "$RTS" run "$W" shell bulk tests/ok.sh tests/ok2.sh 2>/dev/null)
  passes=$(printf '%s\n' "$out" | grep -c "${TAB}pass${TAB}0$")
  [[ "$passes" == "2" ]] && pass "bulk green → 전 unit pass 행" || fail "bulk green ($out)"
  rmw
}

for c in case_assign_go_package case_assign_unclaimed case_assign_bulk_conflict \
         case_assign_residual_no_absorber case_run_test_failure_vs_absent_runner \
         case_run_total_function case_run_absent case_run_bulk_green; do
  echo "== $c"; $c
done
echo "── run-test-selection: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

> **탭 문자**: assert 문자열의 열 구분자는 `$'\t'`를 담은 `$TAB` 변수로 쓴다. 리터럴 탭을 소스에 박으면 편집기가 스페이스로 바꿔도 눈에 안 보여 전부 조용히 빨개진다.

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_run_test_selection.sh`
Expected: FAIL — `unknown subcommand: assign` (8케이스 전부 red)

- [ ] **Step 3: `assign` case 절 구현**

`run-test-selection.sh`의 `case "${1:-}" in` 안, `detect)` 블록 **뒤**에 삽입:

```bash
  assign)
    [[ $# -eq 2 ]] || die "usage: assign <worktree-abs>   # stdin: candidate file paths"
    w=$2
    [[ -d "$w" ]] || die "not a directory: $w"
    adapters=$(detect_set "$w")
    has_adapter() { printf '%s\n' "$adapters" | grep -qx "$1"; }

    # bulk 잔여 흡수자 = 표 순서상 첫 bulk 어댑터. 나머지는 감지됐어도 실행하지 않는다
    # — 같은 스위트를 두 번 돌리지 않기 위해서다 (AC54). 버리는 대신 loud하게 알린다.
    absorber=""; unused_bulk=""
    for r in cargo make npm-script; do
      if has_adapter "$r"; then
        if [[ -z "$absorber" ]]; then absorber="$r"; else unused_bulk="$unused_bulk $r"; fi
      fi
    done
    py=""; has_adapter pytest && py=pytest; has_adapter unittest && py=unittest
    js=""; has_adapter jest   && js=jest;   has_adapter vitest   && js=vitest

    residual=0
    seen_pkgs=""
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      claimed=""
      # 파일 패턴 소유권. 순서는 §5.9 표 순서 — 한 파일은 정확히 한 어댑터에 간다 (AC46).
      case "$f" in
        *_test.go) has_adapter go && claimed=go ;;
      esac
      if [[ -z "$claimed" && -n "$py" ]]; then
        case "$f" in test_*.py|*/test_*.py|*_test.py) claimed="$py" ;; esac
      fi
      if [[ -z "$claimed" ]] && has_adapter shell; then
        case "$f" in
          *.sh) [[ -x "$w/$f" ]] && claimed=shell ;;
        esac
      fi
      if [[ -z "$claimed" && -n "$js" ]]; then
        case "$f" in
          *.test.ts|*.test.tsx|*.test.js|*.test.jsx| \
          *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) claimed="$js" ;;
        esac
      fi

      if [[ -n "$claimed" ]]; then
        if [[ "$(granularity_of "$claimed")" == "package" ]]; then
          # 파일 → 패키지 디렉토리 축약은 **여기서** 일어난다. 오케스트레이터가
          # 이 변환을 수행하는 경로는 없다 (AC52) — 배정 입력은 언제나 파일 경로다.
          pkg=$(dirname "$f")
          if ! printf '%s\n' "$seen_pkgs" | grep -qx "$pkg"; then
            printf '%s\t%s\tpackage\n' "$pkg" "$claimed"
            seen_pkgs="$seen_pkgs
$pkg"
          fi
        else
          printf '%s\t%s\tfile\n' "$f" "$claimed"
        fi
      elif [[ -n "$absorber" ]]; then
        residual=1
      else
        # 실행 수단이 없다. 조용히 버리지 않고 unclaimed로 표면화한다 —
        # 소비자(SKILL)가 이것을 `verification: degraded`로 라우팅한다 (AC53).
        printf '%s\tunclaimed\tfile\n' "$f"
      fi
    done

    [[ $residual -eq 1 ]] && printf 'BULK\t%s\tbulk\n' "$absorber"
    for r in $unused_bulk; do
      echo "run-test-selection: 미실행 러너: $r (bulk 잔여는 $absorber 가 흡수)" >&2
    done
    exit 0
    ;;
```

- [ ] **Step 4: assign 테스트가 통과하는지 확인**

Run: `bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | head -20`
Expected: assign 4케이스 PASS, run 4케이스는 여전히 FAIL (`unknown subcommand: run`)

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh \
        plugins/quality-gates/tests/test_run_test_selection.sh
git commit -m "feat(quality-gates): run-test-selection.sh assign — unit 배정을 결정론으로

모델이 고르는 것은 후보 파일이고, 그것을 unit으로 바꾸는 것은 스크립트다.
파일→패키지 축약(go)·bulk 흡수·소유권 충돌 해소·unclaimed 표면화가 전부
여기 있어 오케스트레이션과 분리해 단위 테스트된다.

AC46 AC52 AC54 · T43 T50 T52 · M26"
```

---

## Task 4: `run-test-selection.sh run` — 결정론 실행 (총 함수)

**Files:**
- Modify: `plugins/quality-gates/scripts/run-test-selection.sh` (`cargo-target-dir` + `run` case 추가)
- Modify: `plugins/quality-gates/tests/test_runner_adapters.sh` (T37 / T41 / T47 추가)

**Interfaces:**
- Consumes: Task 2의 `detect_set()` / `granularity_of()` / `setup_cmd_of()`
- Produces:
  ```
  run-test-selection.sh run <worktree-abs> <runner> <mode> <unit>...
    mode = bulk | per-unit
    stdout: **입력 unit 하나당 정확히 한 줄** — <unit>\t<status>\t<exit-code>
            status ∈ pass | fail | error | unrun | absent
            exit-code 열은 실행되지 않은 행(absent/unrun)에서 리터럴 `-`
    exit: 0 = 실행 시도 완료(테스트 실패 포함) · 3 = 어댑터 사용 불가(+전 unit `unrun`) · 2 = 사용 오류

  run-test-selection.sh cargo-target-dir <worktree-abs>
    stdout: <worktree-abs>/.qg-cargo-target      # read-only 내성, 아무것도 실행 안 함
  ```
  Task 5(`baseline-cache.sh put`)와 Task 6(`diff-test-results.py --baseline/--head`)이 이 3열 TSV를 그대로 소비한다.

**계약의 핵심 둘:**
1. **총 함수.** 행이 빠지는 것은 계약 위반이다. exit 3에서도 모든 unit에 `unrun` 행을 낸다 — 소비자가 부재를 추론으로 메우지 않게 하기 위해서다.
2. **exit code와 테스트 실패의 분리.** 러너 부재/설치 실패는 exit 3(미실행 축), 테스트 실패는 exit 0 + `fail`(실패 축). 뭉치면 "실행했는데 깨졌다"와 "아예 못 돌렸다"가 같은 결론을 받아 귀속이 무너진다.

- [ ] **Step 1: 추가 테스트 작성** — `tests/test_runner_adapters.sh`의 `for c in …` 실행 루프 **위**에 삽입

```bash
# T37 + M17 + AC41: setup_cmd가 양측에서 **동일 문자열**로 나온다.
# 결과값만 보면 두 측이 그럴듯하게 나오므로 호출 문자열 대조로만 잡힌다.
case_setup_cmd_identical_both_sides() {
  local a b t sa sb
  a=$(mktemp -d); b=$(mktemp -d)
  for t in "$a" "$b"; do
    mkdir -p "$t/tests"; : > "$t/tests/test_x.py"; : > "$t/requirements.txt"
  done
  sa=$(bash "$RTS" detect "$a" | awk '$1 == "setup_cmd:" { $1=""; sub(/^ /,""); print }')
  sb=$(bash "$RTS" detect "$b" | awk '$1 == "setup_cmd:" { $1=""; sub(/^ /,""); print }')
  if [[ -n "$sa" && "$sa" == "$sb" && "$sa" != "-" ]]; then
    pass "동일 형상 두 트리 → setup_cmd 동일 문자열 ('$sa')"
  else fail "setup_cmd 비대칭 (a='$sa' b='$sb')"; fi
  rm -rf "$a" "$b"
}

# T47 + M23 + AC50: 빌드 산출물 디렉토리는 트리별로 **다른** 경로여야 한다.
# 공유하면 기준선이 HEAD의 컴파일 결과를 재사용해 조용히 틀린 귀속을 만든다.
case_build_output_not_shared() {
  local a b ta tb
  a=$(mktemp -d); b=$(mktemp -d)
  ta=$(bash "$RTS" cargo-target-dir "$a" 2>/dev/null || true)
  tb=$(bash "$RTS" cargo-target-dir "$b" 2>/dev/null || true)
  if [[ -n "$ta" && -n "$tb" && "$ta" != "$tb" && "$ta" == "$a"* && "$tb" == "$b"* ]]; then
    pass "CARGO_TARGET_DIR가 트리별 독립 ('$ta' != '$tb')"
  else fail "CARGO_TARGET_DIR 공유 위험 (a='$ta' b='$tb')"; fi
  # node_modules / .venv를 트리 밖으로 내보내는 코드 경로가 없어야 한다
  if grep -qE 'NODE_PATH=|VIRTUAL_ENV=|--prefix[[:space:]]' "$RTS"; then
    fail "트리 밖 deps 경로 지정 코드 존재"
  else
    pass "node_modules/.venv 트리 밖 지정 0회"
  fi
  rm -rf "$a" "$b"
}

# T41 + §11 ⑨: 아티팩트 유출 **실측** — make 스텁 레포에서 run 후 비-ignored 신규 파일.
# V1(devbrew self-dogfood)은 Makefile/npm-script 테스트가 없어 이것을 구조적으로 측정
# 못 한다. 이 픽스처가 §11 ⑨의 유일한 측정 경로다.
case_artifact_leak_measurement() {
  local t leaked; t=$(mktemp -d)
  ( cd "$t" && git init -q && git config user.email t@t.test && git config user.name tester )
  printf 'test:\n\t@touch build.log\n' > "$t/Makefile"
  ( cd "$t" && git add -A && git commit -qm init )
  bash "$RTS" run "$t" make bulk BULK >/dev/null 2>&1
  leaked=$( cd "$t" && git ls-files --others --exclude-standard )
  echo "    [측정] make 어댑터 실행 후 비-ignored 신규 파일: ${leaked:-<없음>}"
  # 실패 조건은 **스크립트 자신이** 유출을 만드는 경우뿐이다. 러너가 만든 유출은
  # 통제 밖이므로 §11 ⑨의 잔여 갭으로 기록될 뿐 여기서 RED가 아니다.
  if printf '%s\n' "$leaked" | grep -q '^\.qg-'; then
    fail "run 자신이 비-ignored 아티팩트를 남김"
  else
    pass "run 자신은 비-ignored 아티팩트를 남기지 않음"
  fi
  rm -rf "$t"
}
```

그리고 실행 루프의 `for c in …` 목록에 세 케이스 이름을 추가한다.

> **`cargo-target-dir` 서브커맨드가 필요한 이유**: 파생 경로를 `run` 안에서만 계산하면 T47이 소스 grep(이빨 약함)에 의존하게 된다. read-only 내성 서브커맨드로 노출하면 실행으로 검증된다. 이것은 신규 *파일*이 아니라 같은 스크립트의 case 절이므로 "신규 스크립트 5개" 제약에 영향이 없다.

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | tail -12`
Expected: `case_build_output_not_shared` FAIL (`unknown subcommand: cargo-target-dir`), `case_artifact_leak_measurement` FAIL

- [ ] **Step 3: `cargo-target-dir` + `run` case 절 구현**

`run-test-selection.sh`의 `assign)` 블록 뒤에 삽입:

```bash
  cargo-target-dir)
    # read-only 내성: 이 워크트리에 쓸 CARGO_TARGET_DIR. 트리별 독립임을 밖에서
    # 검증할 수 있게 노출한다 (AC50/T47). 아무것도 실행하지 않는다.
    [[ $# -eq 2 ]] || die "usage: cargo-target-dir <worktree-abs>"
    printf '%s/.qg-cargo-target\n' "$2"
    exit 0
    ;;
  run)
    [[ $# -ge 4 ]] || die "usage: run <worktree-abs> <runner> <mode> <unit>..."
    w=$2; runner=$3; mode=$4; shift 4
    [[ -d "$w" ]] || die "not a directory: $w"
    case "$mode" in bulk|per-unit) ;; *) die "unknown mode: $mode (expected bulk|per-unit)" ;; esac
    gran=$(granularity_of "$runner")   # 닫힌 집합 밖이면 exit 2

    emit_all_unrun() { local u; for u in "$@"; do printf '%s\tunrun\t-\n' "$u"; done; }

    # 어댑터가 **이 트리에서** 쓸 수 있는가. HEAD 감지 결과를 기준선에 재사용하지
    # 않는다 — 인프라를 바꾸는 diff에서 spurious error가 회귀를 PRE_EXISTING으로
    # 은폐할 수 있다 (AC47). 재감지 비용보다 오귀속 비용이 크다.
    if ! detect_set "$w" | grep -qx "$runner"; then
      echo "run-test-selection: 어댑터 사용 불가: $runner (in $w)" >&2
      emit_all_unrun "$@"; exit 3
    fi

    # setup_cmd — 어댑터 소유. 기준선·HEAD 양측에서 **같은 명령**이 돈다 (AC41).
    # 문자열은 위 닫힌 표에서만 오므로 외부 입력이 아니다.
    scmd=$(setup_cmd_of "$w" "$runner")
    if [[ "$scmd" != "-" ]]; then
      if ! ( cd "$w" && sh -c "$scmd" ) >&2 2>&1; then
        echo "run-test-selection: setup 실패: $scmd" >&2
        emit_all_unrun "$@"; exit 3
      fi
    fi

    exists_unit() {
      case "$gran" in
        file)    [[ -e "$w/$1" ]] ;;
        package) [[ -d "$w/$1" ]] ;;
        bulk)    [[ "$1" == "BULK" ]] ;;
      esac
    }

    # exit code만 읽는다 — 러너별 출력 파서 없이 8종 전부에 같은 코드가 적용된다.
    # 0=pass, 1=fail, 그 외=error. error는 §5.5에서 fail 축으로 접히므로 error/fail
    # 사이의 오분류는 귀속을 바꾸지 않는다 (라벨의 `(error)` 병기만 달라진다).
    status_of_exit() { case "$1" in 0) echo pass ;; 1) echo fail ;; *) echo error ;; esac; }

    run_units() {   # run_units <unit>... → 러너의 종료 코드
      local rc=0 u d b dotted
      case "$runner" in
        pytest)
          ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -p no:cacheprovider -q "$@" ) >&2 || rc=$? ;;
        unittest)
          for u in "$@"; do
            d=$(dirname "$u"); b=$(basename "$u")
            if [[ "$d" == "." || -f "$w/$d/__init__.py" ]]; then
              dotted="${u%.py}"; dotted=$(printf '%s' "$dotted" | tr '/' '.')
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest "$dotted" ) >&2 || rc=$?
            else
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$d" -p "$b" ) >&2 || rc=$?
            fi
          done ;;
        shell)
          for u in "$@"; do ( cd "$w" && bash "$u" ) >&2 || rc=$?; done ;;
        jest)
          ( cd "$w" && npx --no-install jest --cache=false --ci "$@" ) >&2 || rc=$? ;;
        vitest)
          ( cd "$w" && npx --no-install vitest run "$@" ) >&2 || rc=$? ;;
        go)
          ( cd "$w" && go test "$@" ) >&2 || rc=$? ;;
        cargo)
          # 빌드 산출물은 트리별 독립 (AC50). 다운로드 캐시(CARGO_HOME/registry)는
          # 내용주소라 공유해도 두 트리가 같은 바이트를 본다 — 기본 위치 그대로 둔다.
          ( cd "$w" && CARGO_TARGET_DIR="$w/.qg-cargo-target" cargo test ) >&2 || rc=$? ;;
        make)
          ( cd "$w" && make test ) >&2 || rc=$? ;;
        npm-script)
          ( cd "$w" && npm test ) >&2 || rc=$? ;;
      esac
      return $rc
    }

    # unit 인자를 그대로 순회한다 (총 함수: 입력 하나당 정확히 한 행).
    present_count=0
    for u in "$@"; do exists_unit "$u" && present_count=$((present_count + 1)); done
    if [[ $present_count -eq 0 ]]; then
      for u in "$@"; do printf '%s\tabsent\t-\n' "$u"; done
      exit 0
    fi

    if [[ "$mode" == "bulk" ]]; then
      present_units=""
      for u in "$@"; do exists_unit "$u" && present_units="$present_units $u"; done
      # shellcheck disable=SC2086  # unit 경로에 공백 없음 (git 경로 계약)
      run_units $present_units; bulk_rc=$?
      bulk_status=$(status_of_exit "$bulk_rc")
      for u in "$@"; do
        if exists_unit "$u"; then printf '%s\t%s\t%s\n' "$u" "$bulk_status" "$bulk_rc"
        else printf '%s\tabsent\t-\n' "$u"; fi
      done
    else
      for u in "$@"; do
        if exists_unit "$u"; then
          run_units "$u"; unit_rc=$?
          printf '%s\t%s\t%s\n' "$u" "$(status_of_exit "$unit_rc")" "$unit_rc"
        else
          printf '%s\tabsent\t-\n' "$u"
        fi
      done
    fi
    exit 0
    ;;
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_run_test_selection.sh`
Expected: PASS — `run-test-selection: 8 passed, 0 failed`

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh`
Expected: PASS — 18 passed (T41 측정 줄이 stdout에 남는다)

- [ ] **Step 5: M16 / M10 / M17 mutation 확인 (손으로, 되돌릴 것)**

| mutation | 편집 | RED가 되어야 할 케이스 |
|---|---|---|
| **M16** | `run` 마지막 루프에서 `absent` 분기의 `printf`를 삭제(행 생략) | `case_run_total_function` — 값은 정상인데 배열이 짧아질 뿐이라 **개수 대조**로만 잡힌다 |
| **M10** | `detect_set` 미포함 시 `exit 3` 대신 `exit 0` + 전 unit `fail` | `case_run_test_failure_vs_absent_runner` 후반 |
| **M17** | `setup_cmd_of`의 pytest 분기 첫 줄에 `[[ "$w" == *b* ]] && { echo 'pip install other'; return; }` 삽입 | `case_setup_cmd_identical_both_sides` |

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh \
        plugins/quality-gates/tests/test_runner_adapters.sh
git commit -m "feat(quality-gates): run-test-selection.sh run — 총 함수 결정론 실행

입력 unit 하나당 정확히 한 행. exit 3에서도 전 unit이 unrun 행으로 나온다 —
소비자가 부재를 추론으로 메우지 않게 하기 위해서다. 러너 부재(exit 3)와 테스트
실패(exit 0 + fail)를 분리하고, setup_cmd를 어댑터가 소유해 양측이 같은 명령으로
준비된다. 빌드 산출물(CARGO_TARGET_DIR)은 트리별 독립.

AC9 AC39 AC40 AC41 AC50 AC56(run) · T7 T35 T36 T37 T41 T47 T54 · M10 M16 M17 M23"
```

---

## Task 5: `baseline-cache.sh` — merge_base 내용주소 캐시

**Files:**
- Create: `plugins/quality-gates/scripts/baseline-cache.sh`
- Create: `plugins/quality-gates/tests/test_baseline_cache.sh`

**Interfaces:**
- Consumes: Task 4의 3열 TSV 형식 (`<unit>\t<status>\t<exit-code>`)
- Produces:
  ```
  baseline-cache.sh get <cache-root> <merge_base> <runner> <unit>...
    stdout: 적중한 항목만 한 줄씩 `<unit>\t<status>\t<exit-code>`
            (미적중 unit은 **출력하지 않는다** → 호출자가 입력과 차집합해 미적중분을 얻는다)
    exit:   0 = 정상(0건 적중 포함) · 4 = 캐시 손상(전량 미적중 취급, stdout 비움, loud)

  baseline-cache.sh put <cache-root> <merge_base> <runner> < results.tsv
    stdin:  `<unit>\t<status>\t<exit-code>` 줄들
    exit:   0 = 기록 완료 · 4 = 기록 실패(advisory, 게이트를 막지 않음)
  ```
  Task 11(SKILL R4①/③)이 호출한다. 저장 위치는 `.claude/quality-gates/baseline-cache/`.

**설계 결정 셋:**
- **무효화 로직이 없다.** rebase나 main 머지로 merge_base가 바뀌면 **키 자체가** 바뀐다. 구조적으로 stale이 불가능하다.
- **락을 쓰지 않는다.** 키가 내용주소라 동시 실행이 쓰는 내용이 동일하므로 rename의 last-write-wins가 안전하다. 이것이 시간주소 캐시(gstack `baseline.json`) 대비 이 설계의 부수 이득이다.
- **`unrun`은 캐시에 넣지 않는다.** 실행하지 못했다는 사실은 환경 상태(설치 실패·네트워크)에 달렸고 merge_base의 함수가 아니다 — 캐시하면 복구 가능한 실패가 영구화된다. `absent`는 merge_base 트리의 함수라 안정적이므로 캐시한다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_baseline_cache.sh`

```bash
#!/usr/bin/env bash
# test_baseline_cache.sh — scripts/baseline-cache.sh (design §5.4).
# AC8 AC32 AC33 AC40(cache) AC42 · T6 T23 T24 T36b T38 · M7 M13 M18
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BC="$PLUGIN_ROOT/scripts/baseline-cache.sh"
TAB=$'\t'
SHA_A=1111111111111111111111111111111111111111
SHA_B=2222222222222222222222222222222222222222

PASS=0; FAIL=0; ROOT=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkroot() { ROOT=$(mktemp -d) || exit 1; }
rmroot() { cd / && rm -rf "$ROOT"; }
seed() {   # seed <sha> <runner> — a=pass, b=fail
  printf 'a.py\tpass\t0\nb.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$1" "$2"
}

# T6 + M7 + AC8: merge_base가 바뀌면 미적중
case_key_includes_merge_base() {
  mkroot; seed "$SHA_A" pytest
  local hit miss
  hit=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | wc -l | tr -d ' ')
  miss=$(bash "$BC" get "$ROOT" "$SHA_B" pytest a.py b.py 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$hit" == "2" && "$miss" == "0" ]]; then
    pass "같은 merge_base 적중 2 / 다른 merge_base 적중 0"
  else fail "merge_base 키 (hit=$hit miss=$miss)"; fi
  rmroot
}

# 같은 merge_base라도 runner가 다르면 미적중 (캐시 키 3요소)
case_key_includes_runner() {
  mkroot; seed "$SHA_A" pytest
  local n; n=$(bash "$BC" get "$ROOT" "$SHA_A" shell a.py | wc -l | tr -d ' ')
  [[ "$n" == "0" ]] && pass "runner가 다르면 미적중" || fail "runner 키 ($n)"
  rmroot
}

# T23-a: 전량 적중 — 값까지 정확히
case_get_full_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;b.py${TAB}fail${TAB}1;" ]] \
    && pass "전량 적중 → 값 보존" || fail "전량 적중 (got: $out)"
  rmroot
}

# T23-b: 부분 적중 — **적중분만** emit (미적중 unit은 무출력)
case_get_partial_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py zzz.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;" ]] \
    && pass "부분 적중 → 적중분만 출력" || fail "부분 적중 (got: $out)"
  rmroot
}

# T23-c + M13 + AC32: 헤더 손상 → exit 4 + **무출력** (부분 파싱해서 일부를 적중으로 내지 않는다)
case_get_corrupt_header() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf 'GARBAGE\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "헤더 손상 → exit 4 + 무출력"
  else fail "헤더 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-c(2): 본문 행 손상(필드 수 불일치)도 전량 미적중 — 반쯤 신뢰한 캐시가
# 조용히 틀린 귀속을 만든다.
case_get_corrupt_body() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "본문 행 손상 → exit 4 + 무출력"
  else fail "본문 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-d: 파일명은 맞는데 본문 merge_base가 다름 (short-sha 충돌) → 무출력
case_get_merge_base_mismatch() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_B" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "본문 merge_base 불일치 → 무출력"
  else fail "sha 불일치 (rc=$rc out='$out')"; fi
  rmroot
}

# T24 + AC33: 원자적 쓰기 — 임시파일 + rename, 중단 시 부분 파일 부재
case_put_atomic() {
  mkroot; seed "$SHA_A" pytest
  if grep -qE 'mv[[:space:]]' "$BC" && grep -qE '\.tmp' "$BC"; then
    pass "put이 tmp + mv rename 사용"
  else fail "원자적 쓰기 코드 부재"; fi
  local strays; strays=$(find "$ROOT" -name '*.tmp*' | wc -l | tr -d ' ')
  [[ "$strays" == "0" ]] && pass "put 후 임시파일 잔존 0" || fail "임시파일 $strays개 잔존"
  rmroot
}

# T36b + AC40: `unrun`은 캐시에 안 들어가고 `absent`는 들어간다
case_unrun_not_cached_absent_cached() {
  mkroot
  printf 'x.py\tunrun\t-\ny.py\tabsent\t-\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest x.py y.py | tr '\n' ';')
  [[ "$out" == "y.py${TAB}absent${TAB}-;" ]] \
    && pass "unrun 미캐시 · absent 캐시" || fail "unrun/absent (got: $out)"
  rmroot
}

# T38 + M18 + AC42: `BULK` 키는 granularity=bulk에서만 생긴다.
# file-granularity의 bulk-green은 호출자가 unit별 pass 행으로 분해해 put하므로
# 캐시에 BULK 키가 남으면 안 된다. 캐시는 받은 것을 그대로 저장하되,
# **BULK 키와 unit 키가 같은 (merge_base, runner)에 공존하면 loud advisory**를 낸다.
case_bulk_key_isolation() {
  mkroot
  printf 'BULK\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" cargo
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" cargo BULK | tr '\n' ';')
  [[ "$out" == "BULK${TAB}pass${TAB}0;" ]] && pass "bulk 어댑터 → BULK 키 정상" || fail "BULK 키 ($out)"
  local err
  printf 'BULK\tpass\t0\na.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>"$ROOT/e.txt"
  err=$(cat "$ROOT/e.txt")
  printf '%s' "$err" | grep -q 'BULK' \
    && pass "file-granularity 러너에 BULK 혼입 → loud advisory" \
    || fail "BULK 혼입 무경고"
  rmroot
}

# 부분 적중 병합: 같은 키에 새 값이 오면 새 값이 이기고, 다른 runner의 행은 보존
case_put_merge_preserves_other_runner() {
  mkroot; seed "$SHA_A" pytest
  printf 'z.sh\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" shell
  local n1 n2
  n1=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | wc -l | tr -d ' ')
  n2=$(bash "$BC" get "$ROOT" "$SHA_A" shell z.sh | wc -l | tr -d ' ')
  [[ "$n1" == "2" && "$n2" == "1" ]] \
    && pass "다른 runner put이 기존 행을 보존" || fail "병합 (pytest=$n1 shell=$n2)"
  printf 'a.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py)
  [[ "$out" == "a.py${TAB}fail${TAB}1" ]] \
    && pass "같은 키 재기록 → 새 값이 이김" || fail "키 충돌 (got: $out)"
  rmroot
}

for c in case_key_includes_merge_base case_key_includes_runner case_get_full_hit \
         case_get_partial_hit case_get_corrupt_header case_get_corrupt_body \
         case_get_merge_base_mismatch case_put_atomic \
         case_unrun_not_cached_absent_cached case_bulk_key_isolation \
         case_put_merge_preserves_other_runner; do
  echo "== $c"; $c
done
echo "── baseline-cache: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_baseline_cache.sh`
Expected: FAIL — `baseline-cache.sh: No such file or directory`

- [ ] **Step 3: `baseline-cache.sh` 작성**

`plugins/quality-gates/scripts/baseline-cache.sh` (신규, `chmod +x`):

```bash
#!/usr/bin/env bash
# baseline-cache.sh — 기준선 테스트 결과의 내용주소 캐시 (design 2026-08-01 §5.4).
#
# 키 = (merge_base sha, runner, unit). 전부 결정론적·내용주소이므로:
#   · 무효화 로직이 필요 없다 — merge_base가 바뀌면 키 자체가 바뀐다.
#   · 락이 필요 없다 — 동시 실행이 쓰는 내용이 동일하므로 rename의
#     last-write-wins가 안전하다.
#
#   get <cache-root> <merge_base> <runner> <unit>...
#     stdout: 적중분만 `<unit>\t<status>\t<exit-code>` (미적중은 무출력)
#     exit:   0 정상(0건 적중 포함) · 4 손상(전량 미적중, stdout 비움)
#   put <cache-root> <merge_base> <runner> < results.tsv
#     exit:   0 기록 완료 · 4 기록 실패(advisory — 게이트를 막지 않는다)
#
# 파일: <cache-root>/<merge_base 앞 12자>.md
#   <!-- qg-baseline-cache:v1 -->
#   merge_base: <full sha>
#   ---
#   <runner>\t<unit>\t<status>\t<exit-code>
set -u

MARKER='<!-- qg-baseline-cache:v1 -->'
die() { echo "baseline-cache: $*" >&2; exit 2; }

cache_file() { printf '%s/%s.md\n' "$1" "${2:0:12}"; }

# 파일이 이 merge_base의 유효한 캐시인지. 유효하면 본문 행을 stdout으로 흘린다.
# 헤더·본문 어느 한 줄이라도 어긋나면 **전량** 미적중이다 — 반쯤 신뢰한 캐시가
# 조용히 틀린 귀속을 만든다.
read_valid_body() {   # read_valid_body <file> <merge_base> → 0=유효(본문 emit) 1=무효
  local f=$1 mb=$2 line1 line2 line3
  [[ -f "$f" ]] || return 1
  IFS= read -r line1 < "$f" || return 1
  [[ "$line1" == "$MARKER" ]] || return 1
  line2=$(sed -n '2p' "$f"); line3=$(sed -n '3p' "$f")
  [[ "$line2" == "merge_base: $mb" ]] || return 1
  [[ "$line3" == "---" ]] || return 1
  # 본문 전량 검증 후에야 emit한다 (마지막 줄이 깨져 있으면 앞 줄도 안 쓴다).
  local body; body=$(sed -n '4,$p' "$f")
  if [[ -n "$body" ]]; then
    printf '%s\n' "$body" | awk -F'\t' '
      NF != 4 { exit 1 }
      $3 !~ /^(pass|fail|error|unrun|absent)$/ { exit 1 }
      { print }
    ' || return 1
  fi
  return 0
}

case "${1:-}" in
  get)
    [[ $# -ge 4 ]] || die "usage: get <cache-root> <merge_base> <runner> <unit>..."
    root=$2; mb=$3; runner=$4; shift 4
    f=$(cache_file "$root" "$mb")
    body=$(read_valid_body "$f" "$mb") || {
      # 파일 부재는 조용한 0건 적중, 손상은 loud exit 4. 둘 다 stdout은 비운다.
      if [[ -f "$f" ]]; then
        echo "baseline-cache: 캐시 손상 — 전량 미적중으로 재계산: $f" >&2
        exit 4
      fi
      exit 0
    }
    for u in "$@"; do
      printf '%s\n' "$body" | awk -F'\t' -v r="$runner" -v u="$u" \
        '$1 == r && $2 == u { printf "%s\t%s\t%s\n", $2, $3, $4; exit }'
    done
    exit 0
    ;;
  put)
    [[ $# -eq 4 ]] || die "usage: put <cache-root> <merge_base> <runner> < results.tsv"
    root=$2; mb=$3; runner=$4
    mkdir -p "$root" 2>/dev/null || { echo "baseline-cache: mkdir 실패: $root" >&2; exit 4; }
    f=$(cache_file "$root" "$mb")

    # 기존 유효 본문에서 **이 runner의 행만** 제거하고 나머지는 보존한다.
    kept=""
    if old=$(read_valid_body "$f" "$mb"); then
      kept=$(printf '%s\n' "$old" | awk -F'\t' -v r="$runner" '$1 != r')
    elif [[ -f "$f" ]]; then
      echo "baseline-cache: 기존 캐시 손상 — 새로 씀: $f" >&2
    fi

    # stdin 정규화. `unrun`은 환경 상태에 달렸고 merge_base의 함수가 아니므로
    # 캐시하지 않는다 — 캐시하면 복구 가능한 실패가 영구화된다.
    fresh=$(awk -F'\t' -v r="$runner" '
      NF != 3 { next }
      $2 == "unrun" { next }
      $2 !~ /^(pass|fail|error|absent)$/ { next }
      { printf "%s\t%s\t%s\t%s\n", r, $1, $2, $3 }
    ')

    # file-granularity 러너에 BULK 키가 섞이면 캐시 오염 신호다 (AC42). 저장은 하되
    # 조용히 넘기지 않는다 — 호출자가 bulk-green을 unit별로 분해하지 않은 것이다.
    if printf '%s\n' "$fresh" | awk -F'\t' '$2 == "BULK"' | grep -q . \
       && printf '%s\n' "$fresh" | awk -F'\t' '$2 != "BULK"' | grep -q .; then
      echo "baseline-cache: 경고 — runner=$runner 에 BULK 키와 unit 키가 공존 (분해 누락?)" >&2
    fi

    tmp="$f.tmp.$$"
    {
      printf '%s\n' "$MARKER"
      printf 'merge_base: %s\n' "$mb"
      printf -- '---\n'
      [[ -n "$kept"  ]] && printf '%s\n' "$kept"
      [[ -n "$fresh" ]] && printf '%s\n' "$fresh"
    } > "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: 임시 파일 쓰기 실패" >&2; exit 4; }
    mv "$tmp" "$f" 2>/dev/null || { rm -f "$tmp"; echo "baseline-cache: rename 실패: $f" >&2; exit 4; }
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected get|put)"
    ;;
esac
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_baseline_cache.sh`
Expected: PASS — `baseline-cache: 13 passed, 0 failed`

- [ ] **Step 5: M7 / M13 mutation 확인 (손으로, 되돌릴 것)**

| mutation | 편집 | RED가 되어야 할 케이스 |
|---|---|---|
| **M7** | `cache_file()`이 merge_base를 무시하고 고정 이름(`cache.md`)을 쓰게 + `read_valid_body`의 `merge_base:` 비교 삭제 | `case_key_includes_merge_base`, `case_get_merge_base_mismatch` |
| **M13** | `read_valid_body`의 awk 검증을 제거하고 본문을 그대로 emit | `case_get_corrupt_body` — 손상 파일에서 일부가 적중으로 새어 나온다 |

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/baseline-cache.sh \
        plugins/quality-gates/tests/test_baseline_cache.sh
git commit -m "feat(quality-gates): baseline-cache.sh — merge_base 내용주소 캐시

기준선 실행을 /qg 호출당이 아니라 merge_base당 1회로 상각한다. 키가 내용주소라
무효화 로직도 락도 필요 없다. 손상은 부분 파싱하지 않고 전량 미적중으로 떨어뜨린다
— 반쯤 신뢰한 캐시가 조용히 틀린 귀속을 만든다. unrun은 환경 상태라 미캐시.

AC8 AC32 AC33 AC40 AC42 · T6 T23 T24 T36 T38 · M7 M13 M18"
```

---

## Task 6: `diff-test-results.py` — 어댑터별 귀속

**Files:**
- Create: `plugins/quality-gates/scripts/diff-test-results.py`
- Create: `plugins/quality-gates/tests/test_diff_test_results.py`

**Interfaces:**
- Consumes: Task 4의 3열 TSV (`--baseline` / `--head`), Task 3의 unit 목록 (`--expected`), Task 2의 granularity
- Produces:
  ```
  diff-test-results.py --expected <f> --baseline <f> --head <f> --granularity file|package|bulk --runner <id>
    stdout (YAML):
      runner: <id>
      attributions:
        - unit: "<unit>"
          verdict: STILL_GREEN|NEW_REGRESSION|PRE_EXISTING|FIXED|NEW_TEST_GREEN
                   |NEW_TEST_RED|SILENT_DROP|BASELINE_UNRUNNABLE
          note: "<(error) 병기 등>"
      attribution_status: closed | degraded
      counts: {8종 소문자 키: N}
      verdict_input:
        confirmed_product_defect: true|false
        silent_drop: true|false
        baseline_unrunnable: true|false
    exit: 0 · 4 = 입력 파싱 실패 / 중복 unit 행 (fail-closed) · 2 = 사용 오류
  ```
  Task 7(`--aggregate`)이 이 YAML 파일들을 읽는다.

**`--expected`가 독립 입력인 것이 이 계약의 핵심이다.** `SILENT_DROP`을 *두 생산자 산출물의 상호 대조*로 계산하면, 두 스크립트가 같은 unit-이름 정규화 버그로 같은 unit을 **대칭적으로** 누락할 때 아무도 눈치채지 못한다 — "총 함수" 보장이 소비자의 독립 검증이 아니라 생산자의 자기일관성에 기대게 된다. 기준은 R1b가 고른 원본 목록이다.

**16칸 총 함수 표 (구현이 확정해야 할 것).** 설계 §5.5는 8개 귀속을 **이름으로** 열거하고 "총 함수"를 요구한다. 축은 baseline×HEAD 각 4종(`P`=pass / `F`=fail·error / `A`=absent / `U`=unrun)이므로 16칸이다. 8개 이름 밖으로 나가지 않으면서 빈 칸을 보수적으로(낙관 금지) 채운 것이 아래다 — **새 카테고리를 만들지 않는다**:

| b\h | pass | fail | absent | unrun |
|---|---|---|---|---|
| **pass** | STILL_GREEN | NEW_REGRESSION | SILENT_DROP | SILENT_DROP |
| **fail** | FIXED | PRE_EXISTING | SILENT_DROP | SILENT_DROP |
| **absent** | NEW_TEST_GREEN | NEW_TEST_RED | SILENT_DROP | SILENT_DROP |
| **unrun** | BASELINE_UNRUNNABLE | BASELINE_UNRUNNABLE | BASELINE_UNRUNNABLE | BASELINE_UNRUNNABLE |

읽는 법: **baseline이 `unrun`이면 무조건 `BASELINE_UNRUNNABLE`** (귀속의 한쪽 축이 없으므로 다른 판정이 불가능), 그 외에 **HEAD가 `absent`/`unrun`이면 `SILENT_DROP`** (R1b가 영향분으로 고른 것이 HEAD에서 확인되지 않았다 = 백스톱 발화). 둘 다 PASS를 막고 FAIL은 만들지 않는다 — "확인 못 했다"의 정직한 표현이다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_diff_test_results.py`

```python
#!/usr/bin/env python3
"""diff-test-results.py 어댑터별 귀속 (design §5.5).

AC11 AC13 AC14 AC15 AC16 AC36 AC43 AC48 · T9 T10 T11 T12 T13 T27 T39 T45 · M4 M22
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "diff-test-results.py"


def run_diff(expected, baseline, head, granularity="file", runner="pytest"):
    """expected: [unit], baseline/head: [(unit, status, code)] → (rc, stdout, stderr)"""
    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        (p / "e.txt").write_text("\n".join(expected) + "\n", encoding="utf-8")
        for name, rows in (("b.tsv", baseline), ("h.tsv", head)):
            (p / name).write_text(
                "".join(f"{u}\t{s}\t{c}\n" for u, s, c in rows), encoding="utf-8"
            )
        r = subprocess.run(
            [sys.executable, str(SCRIPT),
             "--expected", str(p / "e.txt"),
             "--baseline", str(p / "b.tsv"),
             "--head", str(p / "h.tsv"),
             "--granularity", granularity, "--runner", runner],
            capture_output=True, text=True,
        )
    return r.returncode, r.stdout, r.stderr


def verdict_of(out, unit):
    """YAML에서 unit의 verdict 한 줄을 뽑는다."""
    lines = out.splitlines()
    for i, ln in enumerate(lines):
        if ln.strip() == f'- unit: "{unit}"':
            return lines[i + 1].split("verdict:")[1].strip()
    return None


def flag_of(out, key):
    for ln in out.splitlines():
        if ln.strip().startswith(f"{key}:"):
            return ln.split(":")[1].strip()
    return None


class TestAttribution(unittest.TestCase):
    # T9 — 귀속 8종 각각 1 픽스처 (AC11)
    def test_eight_categories(self):
        cases = [
            ("still",    "pass",   "pass",   "STILL_GREEN"),
            ("regress",  "pass",   "fail",   "NEW_REGRESSION"),
            ("preexist", "fail",   "fail",   "PRE_EXISTING"),
            ("fixed",    "fail",   "pass",   "FIXED"),
            ("newgreen", "absent", "pass",   "NEW_TEST_GREEN"),
            ("newred",   "absent", "fail",   "NEW_TEST_RED"),
            ("dropped",  "pass",   "unrun",  "SILENT_DROP"),
            ("nobase",   "unrun",  "pass",   "BASELINE_UNRUNNABLE"),
        ]
        units = [c[0] for c in cases]
        b = [(u, bs, "0") for u, bs, _, _ in cases]
        h = [(u, hs, "0") for u, _, hs, _ in cases]
        rc, out, err = run_diff(units, b, h)
        self.assertEqual(rc, 0, err)
        for unit, _, _, want in cases:
            self.assertEqual(verdict_of(out, unit), want, f"{unit}: {out}")

    # T10 + M4 — PRE_EXISTING만 있는 입력은 확증 제품결함이 아니다 (AC13)
    def test_pre_existing_is_not_a_defect(self):
        rc, out, _ = run_diff(["a"], [("a", "fail", "1")], [("a", "fail", "1")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "PRE_EXISTING")
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "false")

    # T11 — SILENT_DROP 감지 (AC14)
    def test_silent_drop_flag(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "unrun", "-")])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # T12 — BASELINE_UNRUNNABLE (AC15)
    def test_baseline_unrunnable_flag(self):
        rc, out, _ = run_diff(["a"], [("a", "unrun", "-")], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "baseline_unrunnable"), "true")
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")

    # T45 + M22 — SILENT_DROP은 --expected 기준으로 계산된다 (AC48).
    # 양측이 **대칭으로** 같은 unit을 빠뜨린 픽스처 — 상호 대조로 계산하면 놓친다.
    def test_symmetric_omission_is_caught(self):
        rc, out, _ = run_diff(["a", "b"], [("a", "pass", "0")], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "b"), "SILENT_DROP")
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # T45(2) — 중복 unit 행은 exit 4 (AC48). 조용한 last-wins는 입력 순서 의존.
    def test_duplicate_unit_row_is_exit_4(self):
        rc, out, _ = run_diff(
            ["a"], [("a", "pass", "0"), ("a", "fail", "1")], [("a", "pass", "0")]
        )
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # T27 + AC36 — error는 fail 축으로 접히고 note에 `(error)`가 병기된다
    def test_error_folds_into_fail_with_note(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "error", "2")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "NEW_REGRESSION")
        self.assertIn("(error)", out)

    # T13 + AC16 — degrade 경로의 라벨에는 `_SUSPECT` 접미사가 붙는다
    def test_degrade_labels_carry_suspect_suffix(self):
        rc, out, _ = run_diff(["a"], [("a", "unrun", "-")], [("a", "fail", "1")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "BASELINE_UNRUNNABLE")
        self.assertIn("_SUSPECT", out)

    # T39 + AC43 — bulk에서 PRE_EXISTING이 나오면 원장 차원이 degraded.
    # 귀속 **카테고리**는 8종 밖으로 나가지 않는다.
    def test_bulk_pre_existing_degrades_ledger_not_category(self):
        rc, out, _ = run_diff(
            ["BULK"], [("BULK", "fail", "1")], [("BULK", "fail", "1")],
            granularity="bulk", runner="cargo",
        )
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "BULK"), "PRE_EXISTING")
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")
        # file granularity의 같은 입력은 closed
        rc2, out2, _ = run_diff(["a"], [("a", "fail", "1")], [("a", "fail", "1")])
        self.assertEqual(flag_of(out2, "attribution_status"), "closed")

    # 알 수 없는 상태값은 조용히 통과하지 않는다
    def test_unknown_status_is_exit_4(self):
        rc, out, _ = run_diff(["a"], [("a", "weird", "0")], [("a", "pass", "0")])
        self.assertEqual(rc, 4)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: FAIL — 10 errors (`No such file or directory: .../diff-test-results.py`)

- [ ] **Step 3: `diff-test-results.py` 작성**

`plugins/quality-gates/scripts/diff-test-results.py` (신규, `chmod +x`):

```python
#!/usr/bin/env python3
"""diff-test-results.py — 기준선×HEAD 짝짓기 → 귀속 (design 2026-08-01 §5.5).

두 모드:
  per-adapter : --expected/--baseline/--head/--granularity/--runner  → 어댑터 1개의 귀속 YAML
  aggregate   : --aggregate --expected-adapters N <yaml>...          → verdict_input 집계

결정론이 지키는 것은 *선택*이 아니라 *짝짓기*다. 모델 주장과 독립이어야 백스톱이 된다.
표준 라이브러리만 사용한다 (PyYAML 금지 — 대상 레포에 없을 수 있다).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

STATUSES = {"pass", "fail", "error", "unrun", "absent"}

# 상태값 → 표의 축. `error`는 fail 축으로 접힌다: 수집 에러·import 실패는
# *실제 결함*이지 실행 불능이 아니다 (이번 변경이 import를 깼다면 그것은 회귀다).
AXIS = {"pass": "P", "fail": "F", "error": "F", "absent": "A", "unrun": "U"}

# 16칸 총 함수. 8개 카테고리 밖으로 나가지 않는다.
#   baseline == U        → BASELINE_UNRUNNABLE (귀속의 한쪽 축이 없다)
#   head ∈ {A, U}        → SILENT_DROP        (영향분으로 고른 것이 HEAD에서 미확인)
ATTR = {
    ("P", "P"): "STILL_GREEN",         ("P", "F"): "NEW_REGRESSION",
    ("P", "A"): "SILENT_DROP",         ("P", "U"): "SILENT_DROP",
    ("F", "P"): "FIXED",               ("F", "F"): "PRE_EXISTING",
    ("F", "A"): "SILENT_DROP",         ("F", "U"): "SILENT_DROP",
    ("A", "P"): "NEW_TEST_GREEN",      ("A", "F"): "NEW_TEST_RED",
    ("A", "A"): "SILENT_DROP",         ("A", "U"): "SILENT_DROP",
    ("U", "P"): "BASELINE_UNRUNNABLE", ("U", "F"): "BASELINE_UNRUNNABLE",
    ("U", "A"): "BASELINE_UNRUNNABLE", ("U", "U"): "BASELINE_UNRUNNABLE",
}
CATEGORIES = [
    "STILL_GREEN", "NEW_REGRESSION", "PRE_EXISTING", "FIXED",
    "NEW_TEST_GREEN", "NEW_TEST_RED", "SILENT_DROP", "BASELINE_UNRUNNABLE",
]
# 확증 제품결함 — 이것만 FAIL을 만든다. PRE_EXISTING은 여기 없다: devbrew 자신의
# stale red가 첫 실행부터 게이트를 막으면 이 설계는 쓸 수 없다.
DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}


def fail4(msg: str) -> "NoReturn":  # noqa: F821
    print(f"diff-test-results: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_results(path: str, label: str) -> dict[str, tuple[str, str]]:
    """3열 TSV → {unit: (status, exit)}. 중복 unit / 미지 상태 / 필드 수 오류는 exit 4."""
    rows: dict[str, tuple[str, str]] = {}
    for lineno, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        parts = raw.split("\t")
        if len(parts) != 3:
            fail4(f"{label}:{lineno} 필드 수 {len(parts)} != 3")
        unit, status, code = parts
        if status not in STATUSES:
            fail4(f"{label}:{lineno} 알 수 없는 상태값 '{status}'")
        if unit in rows:
            # 조용한 last-wins는 결과를 입력 순서에 의존하게 만든다.
            fail4(f"{label}:{lineno} 중복 unit 행 '{unit}'")
        rows[unit] = (status, code)
    return rows


def yaml_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def per_adapter(args: argparse.Namespace) -> int:
    expected = [
        ln.strip()
        for ln in Path(args.expected).read_text(encoding="utf-8").splitlines()
        if ln.strip()
    ]
    base = read_results(args.baseline, "baseline")
    head = read_results(args.head, "head")

    attributions = []
    counts = {c.lower(): 0 for c in CATEGORIES}
    for unit in expected:
        notes = []
        b = base.get(unit)
        h = head.get(unit)
        if b is None or h is None:
            # 행 자체가 없는 것은 계약 위반이다. 부재를 추론으로 메우지 않는다.
            verdict = "SILENT_DROP"
            missing = [n for n, v in (("baseline", b), ("head", h)) if v is None]
            notes.append("행 없음: " + ",".join(missing))
        else:
            if b[0] == "error":
                notes.append("baseline=(error)")
            if h[0] == "error":
                notes.append("head=(error)")
            verdict = ATTR[(AXIS[b[0]], AXIS[h[0]])]
        # `_SUSPECT`는 계약이다 — 확증이 아니라는 표시이고, 이 경로에서 verdict는
        # PASS가 될 수 없다 (gbrain skills/testing 선례의 degrade 라벨).
        if verdict == "BASELINE_UNRUNNABLE":
            notes.append("git-귀속 degrade: REGRESSION_SUSPECT/PRE_EXISTING_SUSPECT/UNKNOWN")
        counts[verdict.lower()] += 1
        attributions.append((unit, verdict, "; ".join(notes)))

    degraded = counts["baseline_unrunnable"] > 0 or (
        args.granularity == "bulk" and counts["pre_existing"] > 0
    )

    out = [f"runner: {args.runner}", "attributions:"]
    for unit, verdict, note in attributions:
        out.append(f"  - unit: {yaml_str(unit)}")
        out.append(f"    verdict: {verdict}")
        out.append(f"    note: {yaml_str(note)}")
    out.append(f"attribution_status: {'degraded' if degraded else 'closed'}")
    out.append("counts:")
    for c in CATEGORIES:
        out.append(f"  {c.lower()}: {counts[c.lower()]}")
    out.append("verdict_input:")
    out.append(f"  confirmed_product_defect: "
               f"{'true' if any(counts[d.lower()] for d in DEFECTS) else 'false'}")
    out.append(f"  silent_drop: {'true' if counts['silent_drop'] else 'false'}")
    out.append(f"  baseline_unrunnable: "
               f"{'true' if counts['baseline_unrunnable'] else 'false'}")
    print("\n".join(out))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=True)
    p.add_argument("--expected")
    p.add_argument("--baseline")
    p.add_argument("--head")
    p.add_argument("--granularity", choices=["file", "package", "bulk"])
    p.add_argument("--runner")
    p.add_argument("--aggregate", action="store_true")
    p.add_argument("--expected-adapters", type=int)
    p.add_argument("yamls", nargs="*")
    return p


def main() -> int:
    args = build_parser().parse_args()
    if args.aggregate:
        from_aggregate = _aggregate  # Task 7에서 채운다
        return from_aggregate(args)
    missing = [
        f"--{n}" for n in ("expected", "baseline", "head", "granularity", "runner")
        if getattr(args, n) is None
    ]
    if missing:
        print(f"diff-test-results: 필수 인자 누락: {' '.join(missing)}", file=sys.stderr)
        return 2
    return per_adapter(args)


if __name__ == "__main__":
    sys.exit(main())
```

> **`_aggregate`는 Task 7에서 정의한다.** 이 task 종료 시점에는 `--aggregate` 없이 호출되는 경로만 동작하면 되고, Task 7이 `_aggregate` 함수와 그 import를 채운다. Task 6만 머지된 상태에서 `--aggregate`를 부르면 `NameError`가 나므로, Task 7 없이 SKILL을 배선하지 말 것.

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: PASS — `Ran 10 tests ... OK`

- [ ] **Step 5: M4 / M22 mutation 확인 (손으로, 되돌릴 것)**

| mutation | 편집 | RED가 되어야 할 테스트 |
|---|---|---|
| **M4** | `DEFECTS`에 `"PRE_EXISTING"` 추가 | `test_pre_existing_is_not_a_defect` |
| **M22** | `expected` 대신 `sorted(set(base) | set(head))`를 순회 | `test_symmetric_omission_is_caught` — 양측이 대칭으로 빠뜨린 unit이 아예 표에서 사라져 조용히 통과한다 |

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/diff-test-results.py \
        plugins/quality-gates/tests/test_diff_test_results.py
git commit -m "feat(quality-gates): diff-test-results.py — 기준선×HEAD 귀속 8종

16칸 총 함수. --expected를 독립 입력으로 두어 SILENT_DROP이 생산자의 자기일관성이
아니라 소비자의 독립 검증에서 나온다 — 두 산출물이 같은 정규화 버그로 대칭 누락해도
잡힌다. error는 fail 축으로 접고 note에 (error)를 병기하며, bulk의 PRE_EXISTING은
카테고리가 아니라 원장 상태를 degraded로 만든다.

AC11 AC13 AC14 AC15 AC16 AC36 AC43 AC48 · T9 T10 T11 T12 T13 T27 T39 T45 · M4 M22"
```

---

## Task 7: `diff-test-results.py --aggregate` — 어댑터 간 집계

**Files:**
- Modify: `plugins/quality-gates/scripts/diff-test-results.py` (`_aggregate` 함수 추가)
- Modify: `plugins/quality-gates/tests/test_diff_test_results.py` (`TestAggregate` 클래스 추가)

**Interfaces:**
- Consumes: Task 6이 어댑터마다 emit한 YAML 파일들
- Produces:
  ```
  diff-test-results.py --aggregate --expected-adapters <N> <per-adapter.yaml>...
    stdout (YAML):
      adapters: [<runner>, ...]
      verdict_input:
        confirmed_product_defect: true|false
        silent_drop: true|false
        baseline_unrunnable: true|false
      attribution_status: closed | degraded
      per_adapter:
        <runner>: {new_regression: N, pre_existing: N, ...}
    exit: 0 · 4 = 입력 YAML 개수 != --expected-adapters, 중복 runner, 파싱 실패 · 2 = 사용 오류
  ```
  Task 11(SKILL R6→R8)이 이 `verdict_input`을 §5.7 우선순위 표의 기계 입력으로 쓴다.

**왜 스크립트가 소유하는가** — 다중 어댑터에서는 어댑터마다 YAML이 하나씩 나온다. 그것을 하나의 verdict로 합치는 주체가 없으면 오케스트레이터(모델)가 N개를 읽고 최악값을 고르는 셈이 되어, **불변식 ②가 결과값에서 없앤 "모델 요약이 판정을 결정"이 집계 레이어에서 재입장**한다.

**왜 `--expected-adapters`인가** — 어댑터 하나의 결과 파일이 통째로 빠졌을 때 verdict가 낙관적으로 새는 것을 막는다. 개수가 안 맞으면 조용히 남은 것만 합치지 않고 exit 4로 fail-closed한다. `--expected`가 unit 축에서 하는 일을 어댑터 축에서 반복하는 것이다.

- [ ] **Step 1: 실패하는 테스트 작성** — `tests/test_diff_test_results.py`의 `if __name__` **위**에 추가

```python
def write_adapter_yaml(path: Path, runner, defect, drop, unrunnable, status="closed"):
    """per-adapter 모드의 출력 형상을 최소로 재현한 픽스처."""
    path.write_text(
        f"runner: {runner}\n"
        "attributions: []\n"
        f"attribution_status: {status}\n"
        "counts:\n"
        f"  new_regression: {1 if defect else 0}\n"
        "  pre_existing: 0\n"
        "verdict_input:\n"
        f"  confirmed_product_defect: {'true' if defect else 'false'}\n"
        f"  silent_drop: {'true' if drop else 'false'}\n"
        f"  baseline_unrunnable: {'true' if unrunnable else 'false'}\n",
        encoding="utf-8",
    )


def run_aggregate(specs, expected_adapters=None):
    """specs: [(runner, defect, drop, unrunnable, status)] → (rc, stdout, stderr)"""
    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        files = []
        for i, (runner, defect, drop, unrunnable, status) in enumerate(specs):
            f = p / f"{i}.yaml"
            write_adapter_yaml(f, runner, defect, drop, unrunnable, status)
            files.append(str(f))
        n = len(specs) if expected_adapters is None else expected_adapters
        r = subprocess.run(
            [sys.executable, str(SCRIPT), "--aggregate", "--expected-adapters", str(n)] + files,
            capture_output=True, text=True,
        )
    return r.returncode, r.stdout, r.stderr


class TestAggregate(unittest.TestCase):
    # T53 — 어댑터 A 회귀 + B green → confirmed_product_defect: true (AC55)
    def test_one_adapter_regression_makes_the_whole_run_a_defect(self):
        rc, out, err = run_aggregate([
            ("pytest", True, False, False, "closed"),
            ("shell", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 0, err)
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true")
        self.assertIn("pytest", out)
        self.assertIn("shell", out)

    # T53(2) + M25 — 입력 YAML 개수 부족 → exit 4, 남은 것만 낙관적으로 합치지 않는다
    def test_missing_adapter_yaml_is_exit_4(self):
        rc, out, _ = run_aggregate(
            [("pytest", False, False, False, "closed")], expected_adapters=2
        )
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # 같은 runner의 YAML이 두 번 오면 한 어댑터가 빠진 것을 개수로 못 잡는다 → exit 4
    def test_duplicate_runner_is_exit_4(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("pytest", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 4)

    # T26 + AC35 — 확증 회귀와 SILENT_DROP이 **동시** 성립해도 둘 다 살아남는다.
    # degrade 사실이 확증 결함에 삼켜지지 않고, 확증 결함이 degrade로 downgrade되지도
    # 않는다. §5.7 우선순위 표는 이 두 플래그를 함께 받아야 성립한다.
    def test_defect_and_degrade_are_both_reported(self):
        rc, out, _ = run_aggregate([
            ("pytest", True, False, False, "closed"),
            ("shell", False, True, False, "closed"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true")
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # 어느 한 어댑터라도 degraded면 집계도 degraded (구조적 보장이 없으면 인증 없음)
    def test_degraded_propagates(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("cargo", False, False, False, "degraded"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")

    # 형상이 깨진 YAML은 조용히 무시되지 않는다
    def test_malformed_yaml_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "bad.yaml"
            f.write_text("runner: pytest\n(garbage)\n", encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate",
                 "--expected-adapters", "1", str(f)],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: FAIL — `TestAggregate` 6개 전부 red (`NameError: name '_aggregate' is not defined`)

- [ ] **Step 3: `_aggregate` 구현**

`diff-test-results.py`의 `def build_parser()` **위**에 추가하고, `main()`의 `from_aggregate = _aggregate` 줄을 `return _aggregate(args)`로 단순화한다:

```python
def _one(pattern: str, text: str, path: str, what: str) -> str:
    """정확히 한 번 매치되는 값을 뽑는다. 0회도 2회도 exit 4 — 집계는 fail-closed다."""
    import re

    hits = re.findall(pattern, text, re.M)
    if len(hits) != 1:
        fail4(f"{path}: '{what}' 가 {len(hits)}회 매치 (정확히 1회여야 함)")
    return hits[0]


def parse_adapter_yaml(path: str) -> tuple[str, str, dict[str, bool], dict[str, int]]:
    import re

    text = Path(path).read_text(encoding="utf-8")
    runner = _one(r"^runner: (\S+)$", text, path, "runner")
    status = _one(r"^attribution_status: (closed|degraded)$", text, path, "attribution_status")
    flags: dict[str, bool] = {}
    for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
        flags[key] = _one(rf"^  {key}: (true|false)$", text, path, key) == "true"
    # counts 블록은 2칸 들여쓰기 + 정수값. verdict_input의 값은 true/false라 충돌 없음.
    counts = {k: int(v) for k, v in re.findall(r"^  ([a-z_]+): (\d+)$", text, re.M)}
    if not counts:
        fail4(f"{path}: counts 블록 없음")
    return runner, status, flags, counts


def _aggregate(args: argparse.Namespace) -> int:
    if args.expected_adapters is None:
        print("diff-test-results: --aggregate 에는 --expected-adapters 가 필요합니다",
              file=sys.stderr)
        return 2
    if len(args.yamls) != args.expected_adapters:
        # 어댑터 하나의 결과 파일이 통째로 빠졌을 때 verdict가 낙관적으로 새는 것을
        # 막는다. 남은 것만 조용히 합치지 않는다.
        fail4(f"입력 YAML {len(args.yamls)}개 != --expected-adapters "
              f"{args.expected_adapters} (낙관적 부분 집계 금지)")

    adapters: list[str] = []
    per_adapter: dict[str, dict[str, int]] = {}
    combined = {"confirmed_product_defect": False, "silent_drop": False,
                "baseline_unrunnable": False}
    degraded = False
    for path in args.yamls:
        runner, status, flags, counts = parse_adapter_yaml(path)
        if runner in adapters:
            # 같은 runner가 두 번 오면 개수 대조가 무력해진다 (한 어댑터 누락을 못 잡음).
            fail4(f"중복 runner '{runner}' — 어댑터 축 개수 대조가 무력해짐")
        adapters.append(runner)
        per_adapter[runner] = counts
        for key in combined:
            combined[key] = combined[key] or flags[key]
        degraded = degraded or status == "degraded"

    out = [f"adapters: [{', '.join(adapters)}]", "verdict_input:"]
    for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
        out.append(f"  {key}: {'true' if combined[key] else 'false'}")
    out.append(f"attribution_status: {'degraded' if degraded else 'closed'}")
    out.append("per_adapter:")
    for runner in adapters:
        pairs = ", ".join(f"{k}: {v}" for k, v in sorted(per_adapter[runner].items()))
        out.append(f"  {runner}: {{{pairs}}}")
    print("\n".join(out))
    return 0
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: PASS — `Ran 16 tests ... OK`

- [ ] **Step 5: M25 mutation 확인 (손으로, 되돌릴 것)**

`_aggregate`의 개수 대조 블록을 삭제 → `test_missing_adapter_yaml_is_exit_4`가 **RED**. 결과 YAML이 그럴듯하게 나오므로 **개수 대조**로만 잡힌다는 것이 요점이다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/diff-test-results.py \
        plugins/quality-gates/tests/test_diff_test_results.py
git commit -m "feat(quality-gates): diff-test-results.py --aggregate — 어댑터 간 집계

N개 어댑터 YAML을 하나의 verdict_input으로 합치는 주체를 스크립트가 소유한다.
없으면 오케스트레이터가 N개를 읽고 최악값을 고르는 셈이 되어 불변식 ②가 결과값에서
없앤 '모델 요약이 판정을 결정'이 집계 레이어에서 재입장한다. 입력 개수가
--expected-adapters와 다르면 exit 4 — 어댑터 축의 낙관적 누락 방지.

AC35 AC55 · T26 T53 · M25"
```

---

## Task 8: `check_qa_ledger.py` — LD7 원장 구조 게이트

**Files:**
- Create: `plugins/quality-gates/scripts/check_qa_ledger.py`
- Create: `plugins/quality-gates/tests/test_qa_ledger.sh`

**Interfaces:**
- Consumes: 없음 (독립 — Task 1~7과 병행 가능)
- Produces:
  ```
  check_qa_ledger.py <evidence-log-path>       # 또는 인자 없이 stdin
    exit: 0 = 구조 통과 · 1 = 구조 위반(stderr에 사유) · 2 = 사용 오류
  ```
  Task 11(SKILL R8)이 verdict 결정 직전에 호출한다.

**이 스크립트는 구조만 본다.** floor 5키 존재 + 각 status ∈ {`closed`, `degraded`} + evidence 절이 비어있지 않음 + `derived:` 줄 존재. **의미 판정 없음** — "이 evidence가 충분한가"는 사람과 모델의 몫이다. Law 1의 구조적 게이트가 하는 일은 silent skip을 불가능하게 만드는 것뿐이다.

원장 줄 문법 (§5.6):
```
- floor:changed      — closed   — 4 files, all plugins/x/scripts/; runner=pytest
- floor:verification — degraded — unclaimed 2건(spec/*.rb) — 실행 수단 없음
- derived: 없음 — 순수 로직 변경으로 이 diff 특유의 확인 축 없음
- derived:migration — closed — 스키마 up/down 양방향 확인
```

`degraded`는 실패가 아니라 **1급 상태**다. "확증 못 했다"를 정직하게 표현할 자리가 있어야 "확인했다"로 반올림되지 않는다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_qa_ledger.sh`

```bash
#!/usr/bin/env bash
# test_qa_ledger.sh — scripts/check_qa_ledger.py (design §5.6). AC17 AC18 · T14 T15 · M8
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
LEDGER="$PLUGIN_ROOT/scripts/check_qa_ledger.py"

PASS=0; FAIL=0; TMP=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
setup()   { TMP=$(mktemp -d) || exit 1; }
cleanup() { rm -rf "$TMP"; }

# 완전한 원장을 쓴다. $1이 주어지면 그 floor 차원 줄을 **뺀다**.
write_ledger() {   # write_ledger <file> [omit-dim] [derived-line]
  local f=$1 omit=${2:-} derived=${3:-'- derived: 없음 — 순수 로직 변경으로 이 diff 특유의 확인 축 없음'}
  : > "$f"
  local d
  for d in changed behavior verification attribution gap; do
    [[ "$d" == "$omit" ]] && continue
    printf -- '- floor:%-13s — closed   — evidence for %s\n' "$d" "$d" >> "$f"
  done
  printf '%s\n' "$derived" >> "$f"
}

run_ledger() { python3 "$LEDGER" "$1" >/dev/null 2>&1; }

# T14: 완전한 원장 → 0
case_complete() {
  setup; write_ledger "$TMP/l.md"
  run_ledger "$TMP/l.md" && pass "완전한 원장 → exit 0" || fail "완전 원장이 red"
  cleanup
}

# T14: 5키 각각을 하나씩 뺀 5 픽스처 전부 non-zero
case_each_missing_dimension() {
  setup
  local d ok=1
  for d in changed behavior verification attribution gap; do
    write_ledger "$TMP/l.md" "$d"
    if run_ledger "$TMP/l.md"; then echo "    '$d' 누락인데 통과함"; ok=0; fi
  done
  [[ $ok -eq 1 ]] && pass "5차원 각각 누락 → 전부 non-zero" || fail "누락 감지 실패"
  cleanup
}

# degraded는 1급 상태 — 통과해야 한다 (실패가 아니다)
case_degraded_is_valid() {
  setup
  write_ledger "$TMP/l.md"
  sed -i.bak 's/floor:verification  — closed  /floor:verification  — degraded/' "$TMP/l.md" 2>/dev/null || true
  printf -- '- floor:verification — degraded — unclaimed 2건, 실행 수단 없음\n' >> "$TMP/l.md"
  # 중복 방지를 위해 원본 verification 줄을 제거
  grep -v 'floor:verification — closed' "$TMP/l.md" > "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && pass "status=degraded → exit 0 (1급 상태)" || fail "degraded가 red"
  cleanup
}

# 알 수 없는 status는 통과하지 않는다
case_unknown_status() {
  setup; write_ledger "$TMP/l.md"
  grep -v 'floor:gap' "$TMP/l.md" > "$TMP/l2.md"
  printf -- '- floor:gap — unknown — whatever\n' >> "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && fail "status=unknown이 통과함" || pass "알 수 없는 status → non-zero"
  cleanup
}

# evidence 절이 비면 통과하지 않는다 (구조는 있는데 내용이 없는 형식주의 차단)
case_empty_evidence() {
  setup; write_ledger "$TMP/l.md"
  grep -v 'floor:gap' "$TMP/l.md" > "$TMP/l2.md"
  printf -- '- floor:gap — closed —   \n' >> "$TMP/l2.md"
  run_ledger "$TMP/l2.md" && fail "빈 evidence가 통과함" || pass "빈 evidence → non-zero"
  cleanup
}

# T15 + AC18: derived: 없음 + 이유 → 0 / 이유 없음 → non-zero
case_derived_reason_required() {
  setup
  write_ledger "$TMP/ok.md"   "" '- derived: 없음 — 순수 로직 변경이라 확인 축 추가 없음'
  write_ledger "$TMP/bad.md"  "" '- derived: 없음'
  write_ledger "$TMP/none.md" "" '# derived 줄 자체가 없음'
  run_ledger "$TMP/ok.md"   && pass "derived 없음 + 이유 → exit 0"   || fail "derived 이유 있음이 red"
  run_ledger "$TMP/bad.md"  && fail "이유 없는 'derived: 없음'이 통과" || pass "derived 없음 + 이유 부재 → non-zero"
  run_ledger "$TMP/none.md" && fail "derived 줄 부재가 통과"          || pass "derived 줄 부재 → non-zero"
  cleanup
}

# 명명된 derived 차원도 floor와 같은 문법으로 검사된다
case_derived_named() {
  setup
  write_ledger "$TMP/ok.md"  "" '- derived:migration — closed — 스키마 up/down 양방향 확인'
  write_ledger "$TMP/bad.md" "" '- derived:migration'
  run_ledger "$TMP/ok.md"  && pass "명명 derived + status + evidence → exit 0" || fail "명명 derived가 red"
  run_ledger "$TMP/bad.md" && fail "status/evidence 없는 명명 derived가 통과"   || pass "불완전 명명 derived → non-zero"
  cleanup
}

# M8: 헤딩 매칭으로 완화하면 잡혀야 한다 — 차원 이름이 **헤딩에만** 있고
# 본문 행이 없는 원장은 반드시 non-zero.
case_heading_does_not_satisfy() {
  setup
  write_ledger "$TMP/l.md" gap
  printf '## floor:gap\n\n- floor:gap 이라는 문구가 산문에 등장한다\n' >> "$TMP/l.md"
  run_ledger "$TMP/l.md" && fail "헤딩/산문 언급만으로 gap이 닫힘" \
                         || pass "헤딩·산문 언급은 차원을 닫지 못함 (M8)"
  cleanup
}

for c in case_complete case_each_missing_dimension case_degraded_is_valid \
         case_unknown_status case_empty_evidence case_derived_reason_required \
         case_derived_named case_heading_does_not_satisfy; do
  echo "== $c"; $c
done
echo "── qa ledger: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_qa_ledger.sh`
Expected: FAIL — `can't open file .../check_qa_ledger.py`

- [ ] **Step 3: `check_qa_ledger.py` 작성**

`plugins/quality-gates/scripts/check_qa_ledger.py` (신규, `chmod +x`):

```python
#!/usr/bin/env python3
"""check_qa_ledger.py — LD7 원장의 **구조** 게이트 (design 2026-08-01 §5.6, Law 1).

floor 5키 존재 + status ∈ {closed, degraded} + evidence 절 비어있지 않음
+ `derived:` 줄 존재. **의미 판정은 하지 않는다** — "이 evidence가 충분한가"는
사람과 모델의 몫이고, 이 게이트가 하는 일은 silent skip을 불가능하게 만드는 것뿐이다.

usage: check_qa_ledger.py <evidence-log-path>   (인자 없으면 stdin)
exit:  0 통과 · 1 구조 위반 · 2 사용 오류
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

FLOOR_DIMS = ["changed", "behavior", "verification", "attribution", "gap"]
STATUSES = ("closed", "degraded")

# 줄 시작 `- floor:<dim>` + em-dash 구분 status + **비어있지 않은** evidence.
# 헤딩(`## floor:gap`)이나 산문 언급은 이 문법을 만족할 수 없다 — 이것이 M8의 이빨이다.
FLOOR_RE = re.compile(
    r"^-\s+floor:(?P<dim>[a-z_]+)\s+—\s+(?P<status>\w+)\s+—\s+(?P<evidence>\S.*?)\s*$"
)
DERIVED_ANY_RE = re.compile(r"^-\s+derived:")
DERIVED_NONE_RE = re.compile(r"^-\s+derived:\s*없음\s+—\s+(?P<why>\S.*?)\s*$")
DERIVED_NAMED_RE = re.compile(
    r"^-\s+derived:(?P<name>[^\s—]+)\s+—\s+(?P<status>\w+)\s+—\s+(?P<evidence>\S.*?)\s*$"
)


def check(text: str) -> list[str]:
    errors: list[str] = []
    seen: dict[str, str] = {}

    for line in text.splitlines():
        m = FLOOR_RE.match(line)
        if not m:
            continue
        dim, status = m.group("dim"), m.group("status")
        if dim in seen:
            errors.append(f"floor 차원 '{dim}' 이 두 번 선언됨 (어느 것을 믿을지 불명)")
            continue
        if status not in STATUSES:
            errors.append(f"floor:{dim} 의 status '{status}' 가 {STATUSES} 밖")
            continue
        seen[dim] = status

    for dim in FLOOR_DIMS:
        if dim not in seen:
            errors.append(
                f"floor 차원 '{dim}' 누락 — "
                f"`- floor:{dim} — closed|degraded — <evidence>` 줄이 필요합니다"
            )

    derived_lines = [ln for ln in text.splitlines() if DERIVED_ANY_RE.match(ln)]
    if not derived_lines:
        # derived의 '의무'는 "만들어라"가 아니라 "판단을 기록하라"다. 0개여도 되지만
        # 줄 자체가 없으면 모델이 목록까지만 하고 멈춘 것과 구분할 수 없다.
        errors.append("`- derived:` 줄이 없습니다 (0개여도 판단은 기록해야 합니다)")
    else:
        none_lines = [ln for ln in derived_lines if "없음" in ln]
        named_ok = [ln for ln in derived_lines if DERIVED_NAMED_RE.match(ln)]
        if none_lines and named_ok:
            errors.append("`derived: 없음` 과 명명 derived 차원이 함께 선언됨 (모순)")
        for ln in derived_lines:
            if DERIVED_NONE_RE.match(ln) or DERIVED_NAMED_RE.match(ln):
                continue
            if "없음" in ln:
                errors.append(f"`derived: 없음` 에 이유 절이 없습니다: {ln.strip()}")
            else:
                errors.append(
                    f"derived 줄 문법 위반 (`- derived:<name> — <status> — <evidence>`): "
                    f"{ln.strip()}"
                )
        for ln in named_ok:
            st = DERIVED_NAMED_RE.match(ln).group("status")
            if st not in STATUSES:
                errors.append(f"derived status '{st}' 가 {STATUSES} 밖")

    return errors


def main() -> int:
    args = sys.argv[1:]
    if len(args) > 1:
        print("usage: check_qa_ledger.py [<evidence-log-path>]", file=sys.stderr)
        return 2
    if args:
        try:
            text = Path(args[0]).read_text(encoding="utf-8")
        except OSError as exc:
            print(f"check_qa_ledger: 읽기 실패: {exc}", file=sys.stderr)
            return 2
    else:
        text = sys.stdin.read()

    errors = check(text)
    if errors:
        for e in errors:
            print(f"check_qa_ledger: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_qa_ledger.sh`
Expected: PASS — `qa ledger: 12 passed, 0 failed`

- [ ] **Step 5: M8 mutation 확인 (손으로, 되돌릴 것)**

`FLOOR_RE`를 `re.compile(r"floor:(?P<dim>[a-z_]+)")`(헤딩 매칭 수준)으로 완화 → `case_heading_does_not_satisfy`가 **RED**여야 한다. 완화된 정규식은 `## floor:gap` 헤딩만으로 차원을 닫아버린다. 확인 후 되돌린다.

> 이 mutation이 **이 계획의 취약 지점 셋 중 하나**다. 결과값만 보면 완화된 정규식도 정상 원장에서 GREEN이므로, 헤딩-only 픽스처 없이는 이빨이 없다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/check_qa_ledger.py \
        plugins/quality-gates/tests/test_qa_ledger.sh
git commit -m "feat(quality-gates): check_qa_ledger.py — LD7 원장 구조 게이트

floor 5차원 + derived의 **구조만** 검사한다. 의미 판정 없음 — Law 1의 구조적
게이트가 하는 일은 silent skip을 불가능하게 만드는 것뿐이다. degraded는 실패가
아니라 1급 상태다: '확증 못 했다'를 정직하게 쓸 자리가 있어야 '확인했다'로
반올림되지 않는다. 헤딩/산문 언급은 차원을 닫지 못한다 (M8).

AC17 AC18 · T14 T15 · M8"
```

---

## Task 9: `qg-worktree.sh create-baseline`

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh` (`remove)` 앞에 case 절 추가)
- Create: `plugins/quality-gates/tests/test_runtime_contract_invariance.sh`

**Interfaces:**
- Consumes: Task 1의 `merge_base` sha
- Produces:
  ```
  qg-worktree.sh create-baseline <merge-base-sha> <session-id>
    stdout: 생성된 워크트리 절대경로 한 줄
    exit:   0 · 2 = 사용 오류/생성 실패 (die)
  ```
  같은 `worktrees/` 네임스페이스 아래 만들어지므로 기존 `remove`의 가드(`:516-519`)가 그대로 적용된다. Task 11(SKILL R4②)이 호출하고 R4③에서 `remove`한다.

**기준선 워크트리는 working-tree 오버레이를 하지 않는다.** `create-sandbox`는 code-under-review를 반영하려고 메인 워킹트리를 복사하지만, 기준선은 **merge_base의 순수한 상태**여야 한다. 오버레이하면 기준선이 HEAD의 미커밋 변경을 물고 들어와 차등의 의미가 사라진다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_runtime_contract_invariance.sh`

```bash
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
DETECT_RUNTIME_SHA256="<Step 3에서 채움>"
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
CREATE_SANDBOX_SHA256="<Step 3에서 채움>"
MUTATION_GUARD_SHA256="<Step 3에서 채움>"
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

for c in case_create_baseline case_remove_namespace_guard case_detect_runtime_frozen \
         case_sandbox_guard_frozen case_no_new_surfaces; do
  echo "== $c"; $c
done
echo "── runtime contract invariance: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

> **`hooks`/`agents` 기대값**: 위 `4`/`7`은 현 리포 실측값이다. Step 2에서 실제로 세어 확인하고 다르면 그 값으로 고친다.

- [ ] **Step 2: 테스트가 실패하는지 확인 + 핀 값 산출**

Run: `bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh`
Expected: FAIL — `unknown subcommand: create-baseline` + sha 플레이스홀더 3개 mismatch

핀 값 산출:
```bash
shasum -a 256 plugins/quality-gates/scripts/detect-runtime.sh
awk -v label="  create-sandbox)" '$0==label{i=1;next} i && /^  [a-z][a-z-]*\)$/{exit} i{print}' \
  plugins/quality-gates/scripts/qg-worktree.sh | shasum -a 256
awk -v label="  mutation-guard)" '$0==label{i=1;next} i && /^  [a-z][a-z-]*\)$/{exit} i{print}' \
  plugins/quality-gates/scripts/qg-worktree.sh | shasum -a 256
python3 -c "import json;d=json.load(open('plugins/quality-gates/hooks/hooks.json',encoding='utf-8'));print(sum(len(v) for v in d.get('hooks',{}).values()))"
ls plugins/quality-gates/agents | wc -l
```
세 sha 값을 테스트 파일의 플레이스홀더에 채우고, `hooks`/`agents` 기대값도 실측값으로 맞춘다.

- [ ] **Step 3: `create-baseline` case 절 추가**

`qg-worktree.sh`의 `remove)` case 절 **바로 앞**에 삽입한다. `create-sandbox)` / `mutation-guard)` 본문은 **한 바이트도** 건드리지 않는다 (AC22 — 위 sha 핀이 이것을 잡는다):

```bash
  create-baseline)
    # merge_base 상태의 detached 워크트리. create-sandbox와 달리 **working-tree
    # 오버레이를 하지 않는다** — 기준선이 HEAD의 미커밋 변경을 물면 차등의 의미가
    # 사라진다. 같은 worktrees/ 네임스페이스에 만들어 remove 가드를 그대로 받는다.
    [[ $# -eq 3 ]] || die "usage: create-baseline <merge-base-sha> <session-id>"
    sha="$2"; sid="$3"
    git rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1 \
      || die "not a commit: $sha"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"
    parent="$main_root/.claude/quality-gates/worktrees"
    mkdir -p "$parent" || die "cannot create $parent"
    baseline_wt="$parent/base-${sid_short}"

    # Idempotent: 이전 실행의 기준선 트리가 남아 있으면 갈아엎는다.
    git worktree prune >/dev/null 2>&1 || true
    if [[ -e "$baseline_wt" ]]; then
      git worktree remove --force "$baseline_wt" >/dev/null 2>&1 || rm -rf "$baseline_wt"
      git worktree prune >/dev/null 2>&1 || true
    fi
    git worktree add --detach "$baseline_wt" "$sha" >/dev/null 2>&1 \
      || die "git worktree add failed (baseline: $baseline_wt)"
    printf '%s\n' "$baseline_wt"
    ;;
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh`
Expected: PASS — `runtime contract invariance: 10 passed, 0 failed`

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh` (기존)
Expected: PASS

Run: `bash plugins/quality-gates/tests/test_qg_mutation_guard.sh` (기존)
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh \
        plugins/quality-gates/tests/test_runtime_contract_invariance.sh
git commit -m "feat(quality-gates): qg-worktree.sh create-baseline + 계약 무변경 락

merge_base 상태의 detached 워크트리를 같은 worktrees/ 네임스페이스에 만든다 —
remove 가드가 그대로 적용된다. create-sandbox와 달리 working-tree 오버레이를 하지
않는다: 기준선이 HEAD의 미커밋 변경을 물면 차등의 의미가 사라진다.
detect-runtime.sh 전체와 create-sandbox/mutation-guard case 본문을 sha로 핀한다.

AC7 AC21 AC22 AC24 AC25 AC26 · T5 T16 T17 T18"
```

---

## Task 10: `qg-gc.py` — 내용 기반 세션 식별 (기존 결함 수정)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-gc.py:27` 부근 + `gc()` 루프
- Modify: `plugins/quality-gates/tests/test_qg_gc.py` (케이스 추가)

**Interfaces:**
- Consumes: 없음 (독립 — Task 1~9와 병행 가능)
- Produces: 없음 (동작 수정). Task 5의 `baseline-cache/` 디렉토리와 기존 `worktrees/` 디렉토리가 GC 대상에서 빠진다.

**이것은 신규 위험이 드러낸 *기존* 결함이다.** `SESSION_PATTERN = ^[A-Za-z0-9_-]{8,}$`는 세션 폴더만이 아니라 형제 디렉토리 `worktrees`(9자)·`baseline-cache`(14자)도 매치한다. `worktrees/`엔 직접 파일이 없으므로 `_folder_mtime_ns`가 디렉토리 자신의 mtime으로 떨어지고, 24시간 넘게 새 worktree가 추가되지 않았다면 **안에 살아있는 worktree가 있어도** `rename` → `rmtree`된다.

**수정 방향은 denylist가 아니라 내용 기반 식별이다.** `{"worktrees", "baseline-cache"}` 제외 목록은 공간에는 맞지만 **시간에 fail-open**이다 — 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다. 알려진 세션 상태 파일 중 하나라도 든 디렉토리만 sweep 대상으로 삼으면 미래에 대해 fail-closed다.

- [ ] **Step 1: 실패 재현 테스트를 **먼저** 작성** — `tests/test_qg_gc.py`의 `TestQgGc` 클래스에 추가

```python
    # T49 — **실패 재현**. 이 테스트는 수정 *전에* 빨개져야 한다:
    # TTL 초과 + 직접 파일 없는 `worktrees` 디렉토리가 현재 코드에서 삭제된다.
    def test_worktrees_dir_survives_gc(self):
        root = Path(self.tmp)
        wt = root / ".claude" / "quality-gates" / "worktrees" / "rt-abc12345"
        wt.mkdir(parents=True)
        (wt / "live.txt").write_text("살아있는 워크트리", encoding="utf-8")
        # 부모(`worktrees`)에는 직접 파일이 없다 → _folder_mtime_ns가 디렉토리
        # 자신의 mtime으로 떨어진다. 그것을 TTL 밖으로 밀어낸다.
        old = time.time() - 48 * 3600
        os.utime(root / ".claude" / "quality-gates" / "worktrees", (old, old))
        run_gc(self.tmp)
        self.assertTrue(
            wt.exists(),
            "TTL 초과 worktrees/ 가 GC됨 — 안에 살아있는 워크트리가 있는데도",
        )

    # AC27(2) — baseline-cache/ 도 세션 폴더가 아니다
    def test_baseline_cache_dir_survives_gc(self):
        root = Path(self.tmp)
        cache = root / ".claude" / "quality-gates" / "baseline-cache"
        cache.mkdir(parents=True)
        f = cache / "abc123def456.md"
        f.write_text("<!-- qg-baseline-cache:v1 -->\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(cache, (old, old))
        run_gc(self.tmp)
        self.assertTrue(f.exists(), "TTL 초과 baseline-cache/ 가 GC됨")

    # T19 후반 + M2 — 반대 방향: 진짜 세션 폴더는 **여전히** 삭제된다.
    # 이 assert가 없으면 "아무것도 안 지우게" 만든 mutation이 GREEN이 된다.
    def test_real_session_folder_still_collected(self):
        folder = make_session_dir(Path(self.tmp), "sess" + "a" * 8,
                                  mtime_offset_seconds=-48 * 3600)
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "TTL 초과 세션 폴더가 수집되지 않음")

    # AC28 — 마커 파일이 `files.md` 하나뿐인 세션 폴더도 수집된다
    def test_session_identified_by_files_md(self):
        root = Path(self.tmp)
        folder = root / ".claude" / "quality-gates" / ("sess" + "b" * 8)
        folder.mkdir(parents=True)
        f = folder / "files.md"
        f.write_text("- a.py\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(folder, (old, old))
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "files.md 만 있는 세션 폴더가 수집되지 않음")
```

> **`make_session_dir` 헬퍼는 `pipeline.md` 를 쓴다** (기존 파일 `:27-36`). 위 테스트가 `files.md` 를 직접 쓰는 이유는 마커 **집합**이 동작하는지 보기 위해서다 — `pipeline.md` 하나만 검사하는 구현도 `make_session_dir` 기반 테스트는 전부 통과한다.

- [ ] **Step 2: 재현 테스트가 실패하는지 확인 (이것이 결함의 증거다)**

Run: `python3 plugins/quality-gates/tests/test_qg_gc.py`
Expected: FAIL — `test_worktrees_dir_survives_gc`, `test_baseline_cache_dir_survives_gc` 두 개가 red.
**이 red가 §5.11이 약속한 실행 재현이다.** 코드 경로상의 결함이 실제로 발동함을 눈으로 본 뒤 고친다.

- [ ] **Step 3: 내용 기반 식별로 수정**

`qg-gc.py`의 `SESSION_PATTERN` 정의 아래에 추가:

```python
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
# 이름의 charset만으로는 세션 폴더와 형제 디렉토리를 구분할 수 없다 —
# `worktrees`(9자)·`baseline-cache`(14자)가 위 패턴을 만족한다. 내용으로 식별한다.
#
# denylist({"worktrees", "baseline-cache"} 제외)를 쓰지 않는 이유: 공간에는 맞지만
# **시간에 fail-open**이다. 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다.
# 마커 기반은 반대로 시간에 fail-closed다 — 새 형제 디렉토리는 자동으로 안전하다.
# 오판 방향도 옳다: 안 지우는 누수(빈 디렉토리 0바이트)가 살아있는 것을 지우는
# 것보다 안전하다.
SESSION_MARKERS = ("pipeline.md", "files.md", "publish-eligible.md", "runtime-evidence.md")


def _is_session_folder(folder: Path) -> bool:
    try:
        return any((folder / name).is_file() for name in SESSION_MARKERS)
    except OSError:
        return False
```

그리고 `gc()`의 루프에서 `SESSION_PATTERN` 검사 **직후**에 한 줄 추가:

```python
                if not SESSION_PATTERN.match(child.name):
                    continue
                # 이름 + 내용 **둘 다** 만족해야 sweep — 두 조건의 교집합이
                # 단독보다 좁다. 패턴을 지우지 않고 함께 유지하는 이유가 이것이다.
                if not _is_session_folder(child):
                    continue
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 plugins/quality-gates/tests/test_qg_gc.py`
Expected: PASS — `Ran 13 tests ... OK`

- [ ] **Step 5: M1 / M2 mutation 확인 (손으로, 되돌릴 것)**

| mutation | 편집 | RED가 되어야 할 테스트 |
|---|---|---|
| **M1** | `if not _is_session_folder(child): continue` 삭제 (charset 단독으로 회귀) | `test_worktrees_dir_survives_gc`, `test_baseline_cache_dir_survives_gc` |
| **M2** | `_is_session_folder`가 항상 `False`를 반환 (아무것도 sweep 안 함) | `test_real_session_folder_still_collected`, `test_session_identified_by_files_md` |

**M2가 없으면 M1의 방어가 가짜다** — "안 지우게 만들어도 GREEN"이면 그 테스트는 방향이 하나뿐이다. 양방향이라야 이빨이 있다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/qg-gc.py \
        plugins/quality-gates/tests/test_qg_gc.py
git commit -m "fix(quality-gates): qg-gc.py — 세션 폴더를 이름이 아니라 내용으로 식별

SESSION_PATTERN(charset)이 형제 디렉토리 worktrees(9자)·baseline-cache(14자)도
매치해, 직접 파일이 없는 worktrees/가 TTL 초과 시 안에 살아있는 워크트리를 안고
rmtree되는 경로가 있었다. 알려진 세션 마커 파일을 가진 디렉토리만 sweep한다.

denylist를 쓰지 않는 이유: 공간에는 맞지만 시간에 fail-open이다 — 내일 추가될
형제 디렉토리를 오늘 열거할 수 없다. 마커 기반은 시간에 fail-closed다.

AC27 AC28 · T19 T49 · M1 M2"
```

---

## Task 11: SKILL.md Runtime 게이트 전면 개정

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:628-741` (`## Runtime gate` 섹션 전체 교체)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:22-27` (`allowed-tools` Group 3에 5종 추가)
- Modify: `plugins/quality-gates/scripts/check-allowed-tools-order.sh:22-27` (`EXPECTED_ORDER` 동기화)
- Create: `plugins/quality-gates/tests/test_runtime_verdict_precedence.sh`

**Interfaces:**
- Consumes: Task 1~10의 스크립트 전부 (`resolve-baseline.sh` · `run-test-selection.sh` 3 서브커맨드 · `baseline-cache.sh` · `diff-test-results.py` 2모드 · `check_qa_ledger.py` · `qg-worktree.sh create-baseline`)
- Produces: 개정된 Runtime 오케스트레이션. Task 12(락 이전)와 Task 13(페르소나)이 이 문서의 스텝 라벨과 문장을 참조한다.

**이 task의 두 불변식:**
1. **`run-test-selection.sh`는 기준선 측·HEAD 측 둘 다 오케스트레이터가 직접 호출한다.** verifier가 자기 턴 안에서 테스트를 돌려 결과를 self-report하는 경로는 금지 — 그러면 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 되고, LD5가 정확히 막으려던 *"모델 주장이 자기 검증을 결정"* 이 재입장한다. 이것은 같은 파일에 이미 있는 mutation-guard 패턴의 이식이다(`SKILL.md:702`).
2. **기존 로직 8종이 전부 새 자리를 갖는다.** 자리 없는 기존 로직은 삭제가 아니라 누락이다. Task 12의 T48이 8종을 grep으로 센다.

- [ ] **Step 1: 오케스트레이션 락 테스트 작성** — `plugins/quality-gates/tests/test_runtime_verdict_precedence.sh`

이 테스트는 두 층으로 나뉜다: **(i)** 결정론 산출물(`assign` / `--aggregate` / `run`)에 대한 기계적 assert, **(ii)** SKILL.md 산문의 body-unique 문구를 **섹션 윈도우 안에서** 검사하는 락. verdict 결정 자체는 모델이 §5.7 표를 적용해 수행하므로 (ii)가 이 리포의 기존 관행(`test_skill_orchestration_behavior.sh`)과 같은 형태의 방어다. **결정론 verdict 리졸버를 새로 발명하지 말 것** — 설계에 없는 컴포넌트이고 `check_qa_ledger.py`는 "의미 판정 없음"이 계약이다.

```bash
#!/usr/bin/env bash
# test_runtime_verdict_precedence.sh — verdict 규칙과 갭 게이트의 오케스트레이션 락.
# AC10 AC12 AC19 AC20 AC44 AC49 AC53 AC57 · T8 T21 T31 T40 T46 T51 T55
# · M5 M6 M11 M19 M24
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
TAB=$'\t'

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# section_window <start-anchor> <end-anchor> → 두 앵커 사이의 본문
# 락 문구를 섹션 윈도우 안에서 찾는 이유: 문서 아무 데나 있는 같은 단어가
# 락을 만족시키면 그 락엔 이빨이 없다.
section_window() {
  awk -v s="$1" -v e="$2" '
    index($0, s) { inw = 1 }
    inw && index($0, e) && !index($0, s) { exit }
    inw { print }
  ' "$SKILL"
}

# body_unique_in <window-cmd-output> <needle> → 윈도우 안에 정확히 1회
count_in() { printf '%s\n' "$1" | grep -cF "$2"; }

# ── (i) 결정론 산출물 ────────────────────────────────────────────────────────

# T51 + M24 + AC53: unclaimed unit이 실제로 산출된다 (verdict 라우팅의 입력)
case_unclaimed_row_is_produced() {
  local w; w=$(mktemp -d)
  mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  local out; out=$(printf 'spec/a_spec.rb\n' | bash "$RTS" assign "$w")
  [[ "$out" == "spec/a_spec.rb${TAB}unclaimed${TAB}file" ]] \
    && pass "미지원 레포 → unclaimed 행 산출" || fail "unclaimed 미산출 ($out)"
  rm -rf "$w"
}

# T40 + M19 + AC44: 영향분 러너 부재는 exit 3으로 **구별 가능하게** 나온다
case_runner_absent_is_distinguishable() {
  local w; w=$(mktemp -d); mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  local rc; bash "$RTS" run "$w" cargo bulk BULK >/dev/null 2>&1; rc=$?
  [[ $rc -eq 3 ]] && pass "영향분 러너 부재 → exit 3 (gap과 구별 가능)" || fail "exit 3 아님 ($rc)"
  rm -rf "$w"
}

# ── (ii) SKILL.md 산문 락 (섹션 윈도우 + body-unique) ─────────────────────────

# T51 + AC53: unclaimed → verification degraded → PASS 불가가 verdict 절에 있다.
# needle 은 SKILL.md 본문의 **연속 부분문자열**이어야 한다 — 백틱 하나 어긋나면
# grep -F 가 못 찾고 락은 조용히 통과한다(이 plan 작성 중 실제로 한 번 어긋났다).
case_skill_unclaimed_blocks_pass() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w" '가 하나라도 있으면 `verification: degraded` 이고 verdict 를 PASS 로 올리지 않는다') -ge 1 ]] \
     && [[ $(count_in "$w" '열거가 인증을 대신하지 않는다') -ge 1 ]]; then
    pass "R8 절이 unclaimed → verification degraded → PASS 불가를 명시"
  else fail "R8 절에 unclaimed 라우팅 규칙 부재"; fi
}

# T31 + M11 + AC15(빈 스코프): 영향분 0개 → SKIP_WITH_EVIDENCE (PASS도 FAIL도 아님)
case_skill_zero_impact_is_skip() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  [[ $(count_in "$w" '영향분 0개 → `SKIP_WITH_EVIDENCE`') -ge 1 ]] \
    && pass "영향분 0개 → SKIP_WITH_EVIDENCE (정확 토큰)" \
    || fail "영향분 0개 규칙 부재/토큰 불일치"
}

# T26 + M5 + M15 + AC35: 확증 제품결함이 terminal이고 degrade가 함께 기록된다
case_skill_precedence_total_order() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w" '확증 제품결함(FAIL, terminal)  >  NEEDS_RESOLUTION  >  SKIP_WITH_EVIDENCE  >  PASS') -eq 1 ]] \
     && [[ $(count_in "$w" 'degrade 사실은 원장과 보고서에 함께 기록된다') -ge 1 ]]; then
    pass "verdict 총 순서 1회 + degrade 동시 기록 명시"
  else fail "verdict 총 순서 / degrade 동시 기록 락 실패"; fi
}

# T21 + M6 + AC12: 재실행은 정확히 1회 (무한 재실행이 false green 경로)
case_skill_rerun_exactly_once() {
  local w; w=$(section_window '**Step R6' '**Step R7')
  if [[ $(count_in "$w" '재실행은 정확히 1회다 — green 이 나올 때까지가 아니다') -eq 1 ]]; then
    pass "재실행 1회 잠금 문장 존재 (body-unique)"
  else fail "재실행 1회 문장 부재/중복"; fi
}

# T8 + AC10: bulk green이면 per-unit 재실행을 하지 않는다 (2단 구조)
case_skill_two_stage() {
  local w; w=$(section_window '**Step R5b' '**Step R6')
  [[ $(count_in "$w" 'bulk 가 green 이면 per-unit 재실행을 하지 않는다') -ge 1 ]] \
    && pass "2단 구조(bulk green → per-unit 0회) 명시" || fail "2단 구조 문장 부재"
}

# T28 + AC19: 계획 산문 6필드가 R2 절에 열거된다
case_skill_plan_prose_six_fields() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local missing=0 f
  for f in '무엇이 바뀌었나' '어떤 행동에 닿나' '무엇을 돌리나' \
           '비용 신호' '무엇을 안 돌리나' 'CI 와 다르면'; do
    [[ $(count_in "$w" "$f") -ge 1 ]] || { echo "    누락 필드: $f"; missing=1; }
  done
  [[ $missing -eq 0 ]] && pass "계획 산문 6필드 전부 R2에 존재" || fail "계획 산문 필드 누락"
  [[ $(count_in "$w" '개 선택 (전체 ') -ge 1 ]] \
    && pass "선택 비율 포맷 `N개 선택 (전체 M개 중)`" || fail "선택 비율 포맷 부재"
}

# T55 + AC57: 비용 신호는 3단계 범주값이고 숫자 시간 추정을 쓰지 않는다
case_skill_cost_signal_categorical() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local ok=1 c
  for c in '즉시' '수 분' '설치 포함'; do
    [[ $(count_in "$w" "$c") -ge 1 ]] || { echo "    누락 등급: $c"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "비용 등급 3단계 존재" || fail "비용 등급 누락"
  # 숫자 시간 추정(예: "약 3분", "5 min")이 R2 절에 없어야 한다.
  # 단위 토큰에 bare `s` 를 넣지 않는다 — "R5b" 같은 식별자를 오탐한다.
  if printf '%s\n' "$w" | grep -qE '(약[[:space:]]+)?[0-9]+[[:space:]]*(초|분|시간|sec|min|hour)'; then
    fail "R2 절에 숫자 시간 추정이 있음"
  else
    pass "숫자 시간 추정 0회 (추정기가 없으므로 지어낸 숫자가 된다)"
  fi
}

# AC20: 갭 게이트는 생략 목록이 **비어 있으면** 발화하지 않는다
case_skill_gap_gate_zero_click() {
  local w; w=$(section_window '**Step R3' '**Step R4')
  if [[ $(count_in "$w" '생략 목록이 비어 있으면 `AskUserQuestion` 을 발화하지 않는다') -ge 1 ]] \
     && [[ $(count_in "$w" 'zero-click') -ge 1 ]]; then
    pass "생략 0 → zero-click 조건 명시"
  else fail "zero-click 조건 부재"; fi
}

# T46 + AC49: bulk 어댑터의 커버리지 미보장 공시가 R2와 R8 **양쪽**에 있다
case_skill_bulk_disclosure() {
  local w2 w8
  w2=$(section_window '**Step R2' '**Step R3')
  w8=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]] \
     && [[ $(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]]; then
    pass "bulk 커버리지 미보장 공시가 계획 산문과 보고서 양쪽에"
  else fail "bulk 공시 누락 (R2=$(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') R8=$(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)'))"; fi
}

# AC47: 기준선 트리에서 detect를 **재실행**한다 (HEAD 집합 재사용 금지)
case_skill_both_side_detect() {
  local w; w=$(section_window '**Step R4' '**Step R5a')
  [[ $(count_in "$w" 'HEAD 의 어댑터 집합을 재사용하지 않는다') -ge 1 ]] \
    && pass "기준선 트리 재감지 명시" || fail "양측 재감지 문장 부재"
}

for c in case_unclaimed_row_is_produced case_runner_absent_is_distinguishable \
         case_skill_unclaimed_blocks_pass case_skill_zero_impact_is_skip \
         case_skill_precedence_total_order case_skill_rerun_exactly_once \
         case_skill_two_stage case_skill_plan_prose_six_fields \
         case_skill_cost_signal_categorical case_skill_gap_gate_zero_click \
         case_skill_bulk_disclosure case_skill_both_side_detect; do
  echo "== $c"; $c
done
echo "── runtime verdict precedence: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_runtime_verdict_precedence.sh`
Expected: FAIL — (i) 2케이스는 PASS(스크립트가 이미 있으므로), (ii) SKILL 락 10케이스 전부 red

- [ ] **Step 3: `allowed-tools` + linter 동기화**

`SKILL.md`의 Group 3 블록(22–27행)을 아래로 교체:

```yaml
  # Group 3 — Runtime gate scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/render-terminal.py:*)
```

`check-allowed-tools-order.sh`의 `EXPECTED_ORDER` Group 3도 **같은 순서로** 갱신한다 (이 스크립트가 canonical source다 — SKILL.md의 주석은 문서화이지 canonical이 아니다).

Run: `bash plugins/quality-gates/scripts/check-allowed-tools-order.sh`
Expected: `check-allowed-tools-order: OK (25 tools in canonical order)`

- [ ] **Step 4: Runtime 게이트 섹션 교체 — 전반부 (R-init ~ R4)**

`SKILL.md`의 `## Runtime gate`(628행)부터 `**Step R-init …**` 문단(632행)까지를 아래로 교체한다:

````markdown
## Runtime gate

If `effective_skip_runtime` was set, skip this entire section.

이 게이트는 **이번 변경의 영향분**을 골라 merge_base 기준선 대비로 돌린다. 모델이
*무엇을 돌릴지* 한 번 고르고, 그 선택을 결정론이 기준선·HEAD 양쪽에서 두 번 실행해
짝짓는다 — 귀속(이 fail 은 내 탓인가)과 백스톱(결과가 조용히 비었나)이 같은
메커니즘에 얹힌다.

> **호출 주체 불변식 (load-bearing).** `run-test-selection.sh` 는 기준선 측(R4)과
> HEAD 측(R5b) **둘 다 오케스트레이터가 직접** 호출한다. `runtime-verifier` 가 자기
> 턴 안에서 테스트를 돌려 결과를 evidence-log 로 self-report 하는 경로는 **금지**다.
> verifier 의 evidence-log 에 적힌 테스트 결과는 advisory 이며, 이 스크립트의
> 오케스트레이터 호출 결과가 authoritative 다 — 둘이 다르면 후자를 쓴다. (R7 의
> mutation-guard 가 verifier 의 `writes:` self-report 를 대하는 방식과 같은 패턴.)

**Step R-init — baseline 확정.**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-baseline.sh"
```

4키(`base` / `base_ref` / `merge_base` / `degraded`)를 캡처한다. `degraded: yes` 면
차등 실행이 불가능하므로 loud advisory 를 내고 **verdict 를 PASS 로 올리지 않는다**:

> `> [quality-gates] baseline 확정 불가 (<사유>) — 차등 귀속 없이 진행, verdict 는 PASS 불가`

**Step R1a — 러너 어댑터 감지 (HEAD 트리).**

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" detect "$project_dir"
```

감지된 어댑터를 **집합으로** 캡처한다(0개 이상 — 폴리글랏 레포는 복수). 각 어댑터는
`runner` / `granularity` / `setup_cmd` 3줄이다. 이 집합이 R2 산문·R4·R5b·R6 의
`--granularity` 로 스레드된다. **감지 표를 여기서 재구현하지 않는다** — 감지 지식은
그 스크립트가 단독 소유한다. 감지 0개(빈 stdout + exit 0)는 오류가 아니라 결과이며,
그 경우 floor 를 제공할 수 없다는 사실이 R8 에서 loud 하게 나온다.

**Step R1b — 영향 판정 (모델 소유) + unit 배정.**

스코프 결정은 **당신**이 한다. 아래 넷은 *입력이지 규칙이 아니다*:

| 스코프 보조 입력 | 무엇 | 신뢰 등급 |
|---|---|---|
| `compute-test-scope-candidates.sh` 후보 목록 | diff 의 src → 이름 매칭 test 파일 | **구조적** — 있으면 강한 신호, 없다고 없는 것은 아님 |
| git diff + commit message + PR description | 무엇이 바뀌었고 무엇을 **의도**했나 | **구조적** |
| 레포 CI 설정의 test-selection | CI 가 무엇을 고르는가 | **참고** — 대체 금지, 차이는 R2 산문에 한 줄 |
| `test-scope-validator` 분류 | `outdated-suspicion`/`cherry-pick-suspicion` | **부정 신호** — 그렇게 찍힌 테스트는 커버리지로 세지 않음 |

`test-scope-validator` 를 여기서 dispatch 한다 (read-only reviewer; `project_dir` 는
*preflight* 디렉토리 — 실제 diff 를 본다). Per [Reviewer dispatch contract](#reviewer-dispatch-contract):

```
Agent({
  subagent_type: "quality-gates:test-scope-validator",
  description: "Classify scope-relevant test files (Runtime gate)",
  prompt: "Validate test scope against current diff, spec acceptance criteria, and plan items.
    project_dir: \"$project_dir\"
    spec_path: <path or 'auto'; pass 'none' if DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1>
    plan_path: <path or 'auto'>
    candidate_test_files: <compute-test-scope-candidates.sh 출력>"
})
```

**빈 스코프 fail-safe**: 후보 목록이 비었다고 검증을 건너뛰지 않는다. 백엔드·설정·
인프라 변경도 앱 동작에 영향을 준다 — 영향분이 안 잡히면 그것 자체를 `gap` 차원에
기록하고, 러너 전체 실행 또는 smoke 로 폭을 넓힐지 R2 산문에 쓴다.

고른 **후보 파일 경로**를 배정 스크립트에 넘긴다. 당신이 고르는 것은 *파일*이고,
그것을 unit 으로 바꾸는 것은 스크립트다 — 파일→패키지 축약 같은 결정론 변환을
여기서 손으로 하지 않는다:

```bash
printf '%s\n' "${candidate_files[@]}" \
  | "${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" assign "$project_dir"
```

`<unit>\t<runner|unclaimed>\t<granularity>` 행을 캡처한다. stderr 의 `미실행 러너:`
줄도 함께 잡아 `gap` 차원에 열거한다. **`unclaimed` 행이 하나라도 있으면** 그 목록을
R8 의 `verification` 차원으로 가져간다 (`gap` 이 아니다 — 이유는 R8).

**Step R2 — 계획 산문 + 비용 신호.**

사람 말로 쓴다. 전문용어 나열은 산출물 실패다. 어투는 재량이지만 **여섯 필드는 필수**:

1. **무엇이 바뀌었나** — 파일 나열이 아니라 "무엇을 하는 코드가"
2. **어떤 행동에 닿나** — 행동/경로를 이름으로 지목
3. **무엇을 돌리나 + 선택 비율** — `영향 테스트 12개 선택 (전체 47개 중)` 형태.
   분모는 반드시 `compute-test-scope-candidates.sh --total` 의 출력이다 —
   당신이 센 값이 아니다. 분모가 모델 자기보고이면 과선택이 심해질수록 분모도 같이
   부풀려 비율이 정상으로 보인다.
4. **비용 신호** — `즉시`(캐시 전량 적중·설치 불필요) / `수 분`(기준선 실행 필요·
   설치 불필요) / `설치 포함`(deps 설치 필요) 셋 중 하나. **숫자 시간 추정을 쓰지
   않는다** — 추정기가 없으므로 지어낸 숫자가 된다.
5. **무엇을 안 돌리나** — 미선택분 · 자동화 불가 플로우 · blocked 표면 · `unclaimed`
   · `미실행 러너`
6. **CI 와 다르면 그 차이** — 한 줄. 대체하지 않고 설명만 한다.

`granularity: bulk` 어댑터가 하나라도 있으면 이 산문에 **항상** 다음을 넣는다:

> `커버리지 미보장(러너가 선택을 무시함)`

그리고 정확히 한 줄의 scope transparency 앵커를 emit 한다:

> `> Runtime scope: 영향 테스트 <N>개 선택 (전체 <M>개 중), 러너 <runners> — 이번 변경의 영향분만 기준선 대비로 돌린다.`

**Step R3 — 갭 게이트 (생략이 있을 때만).**

R2 의 5번이 곧 생략 목록이다. **생략 목록이 비어 있으면 `AskUserQuestion` 을 발화하지 않는다** — 계획 한 줄만 출력하고 zero-click 으로 R4 로 간다.

비어 있지 않으면 정확히 1회 `AskUserQuestion`: 생략 목록을 보여주고
`그대로 진행` / `범위 넓혀서 다시 계획` / `중단`. 질문 빈도가 생략의 양에
비례하므로, 질문이 뜰 때는 반드시 정보가 있다.

**Step R4 — 기준선 측 (오케스트레이터 단독 — verifier 미개입).**

`degraded: yes` 면 이 스텝 전체를 건너뛰고 R8 에서 `BASELINE_UNRUNNABLE` 로 처리한다.

① 캐시 조회 — 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" get \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner" "${units[@]}"
```

적중분만 나온다. 입력 목록과 차집합해 **미적중분**을 얻는다. exit 4(손상)는 전량
미적중으로 취급하고 loud advisory 를 낸다.

② 미적중분이 있을 때만 기준선 워크트리를 만든다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-baseline "$merge_base" "<session-id>"
```

그 트리에서 **`detect` 를 다시 실행한다 — HEAD 의 어댑터 집합을 재사용하지 않는다.**
diff 가 테스트 인프라 자체를 바꾸는 경우(unittest→pytest 마이그레이션, `package.json`
에 jest 신규 추가) 두 집합이 다를 수 있고, HEAD 감지를 기준선에 그대로 쓰면 spurious
`error` 가 나와 진짜 회귀를 `PRE_EXISTING` 으로 은폐한다. 두 집합이 다르면 한쪽에만
있는 어댑터의 unit 은 반대편에서 `unrun` 이 되어 귀속이 degrade 되고, 그 사실을 R2
산문과 `gap` 에 명시한다.

그다음 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$baseline_wt" "$runner" bulk "${miss_units[@]}"
```

bulk 가 red 면 실패한 unit 에 대해서만 `per-unit` 으로 재실행한다 (2단 구조).

③ 결과를 캐시에 기록하고 기준선 워크트리를 폐기한다:

```bash
printf '%s\n' "${rows[@]}" | "${CLAUDE_PLUGIN_ROOT}/scripts/baseline-cache.sh" put \
  ".claude/quality-gates/baseline-cache" "$merge_base" "$runner"
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "$baseline_wt"
```

`granularity ∈ {file, package}` 에서 bulk-green 이 나오면 **unit 별 `pass` 행으로
분해해** 기록한다 — 집합 전체가 통과했으므로 각 unit 이 통과했다. `BULK` 키는
`granularity: bulk` 어댑터에서만 생긴다.

**R4 가 R5 보다 먼저인 이유** — 기준선 실행이 HEAD 샌드박스와 **다른 트리에서,
verifier 개입 없이** 끝나야 한다. 같은 트리에서 코드를 되감았다 복원하면
mutation-guard 의 의미가 흐려지고, verifier 가 기준선을 조작해 진짜 회귀를
`PRE_EXISTING` 으로 위장할 수 있는 경로가 생긴다.
````

- [ ] **Step 5: Runtime 게이트 섹션 교체 — 중반부 (R5a⁰ ~ R5b)**

기존 `**Step R0 …**`(634행)부터 `**Step R3 — dispatch runtime-verifier …**` 블록 끝(694행)까지를 아래로 교체한다. **기존 내용은 이름만 바뀌고 계약은 그대로다** — 자리 없는 기존 로직은 삭제가 아니라 누락이다.

````markdown
**Step R5a⁰ — Runtime-scope inputs (every path that reaches this gate).** The R5a³
dispatch requires `manifest`, `approved_surfaces`, and `block_policy`. The
full-pipeline `Run both gates` / `gate=both` path produced them in
[Decision 2](#decision-2--runtime-scope--block-policy-conditional). **Single-gate
`/qg runtime` bypassed the Dispatch Loop, so if `approved_surfaces` / `block_policy`
are still unset on entry here, produce them now**: run
`${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the `manifest`, then apply
Decision 2's firing logic on the result — fire the runtime-scope `AskUserQuestion`
only if ≥1 `requires_decision` surface exists and no surface-selection arg
pre-answers it; otherwise zero-click with the automatic test runners as
`approved_surfaces` and a default `block_policy=skip`. (`gate=runtime` pre-answers
gate scope, NOT surface selection.) After this step `manifest` /
`approved_surfaces` / `block_policy` are guaranteed defined for R5a³. If Decision 2
already ran (gate scope = both), this step is a no-op.

> **매니페스트의 `test_runners` 필드는 이 게이트의 실행 경로에서 소비되지 않는다.**
> 매니페스트는 **부팅 표면**(`runnable_surfaces` / `approved_surfaces`)만 정하고,
> 실행할 테스트 러너 식별은 R1a 가 소유한다. 두 집합이 다른 것은 결함이 아니라 축이
> 다르기 때문이다.

**Step R5a¹ — Create the sandbox (or fall back).** Seal the code-under-review into
a disposable git-worktree:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-sandbox "<session-id>"
```

- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**, **line 3
  = `snapshot_digest`**. Parse contract (fixed): read exactly three lines with three
  successive `IFS= read -r` and strip trailing whitespace/CR from `snapshot_digest`
  (`tr -d '[:space:]'` or equivalent) — a stray newline/space in the hex makes the
  guard fail-closed on every run. Hold all three as orchestrator variables
  (verifier-unreachable). Set `runtime_project_dir = sandbox_dir`.
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback
  (no sandbox): set `runtime_project_dir = project_dir`. The verdict is **capped at
  SKIP_WITH_EVIDENCE — never PASS** (no sandbox = no structural Law-2 guarantee = no
  certification). BEFORE the R5a³ dispatch, capture `fallback_pre` = `git -C
  "$project_dir" status --porcelain --untracked-files=all` plus a tracked content
  tree-hash baseline. Print: `> [quality-gates] runtime sandbox disabled — read-only
  smoke mode on the real tree; verdict capped at SKIP_WITH_EVIDENCE
  (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1).`
- Any other non-zero → surface stderr verbatim and mark the Runtime gate failed.

**Step R5a² — gather spec Acceptance Criteria.** Resolve the spec (reuse
`discover-spec.sh` semantics) and build `spec_acceptance_criteria` as a
`{ac_id, text}` list. If no spec, pass an empty list (the verifier falls back to
plan_features → smoke).

Also derive `evidence_dir = "$project_dir/.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/"`
(the preflight main-repo `project_dir`, NOT the sandbox — so it survives the R9
sandbox discard).

**Step R5a³ — dispatch runtime-verifier (executor).** 이 dispatch 는 **판단이 필요한
것만** 맡는다: 앱 부팅용 setup fix · 상황별 부팅 · 브라우저/CLI 플로우. **테스트 실행도,
테스트 러너용 deps 설치도 여기 없다.**

```
Agent({
  subagent_type: "quality-gates:runtime-verifier",
  description: "Runtime verification (Runtime gate, sandbox executor)",
  prompt: "Boot the declared surfaces in the sandbox, drive flows, assert against spec AC, write an evidence-log.
    project_dir: \"$runtime_project_dir\"
    evidence_dir: \"$evidence_dir\"
    spec_acceptance_criteria: <{ac_id,text} list or []>
    manifest: <output of detect-runtime.sh>
    approved_surfaces: <surfaces opted in at the Upfront Execution Plan>
    block_policy: <stop|skip|ask>
    resolution_iter: <N (1..DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)>"
})
```

**Step R5b — HEAD 측 테스트 실행 (verifier 턴 *종료 후*, 오케스트레이터가 직접).**

verifier 의 dispatch 가 **끝난 뒤**, 어댑터마다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-test-selection.sh" run \
  "$runtime_project_dir" "$runner" bulk "${units[@]}"
```

**bulk 가 green 이면 per-unit 재실행을 하지 않는다** — 집합 전체가 통과했으므로 귀속할
것이 없다. red 일 때만 실패한 unit 에 대해 `per-unit` 으로 재실행한다. 흔한 경우 2회,
비싼 경우에만 정밀해진다.

이 호출은 R5a³ 의 `Agent({…})` 블록 **밖**에 있어야 한다 — 위 호출 주체 불변식.
verifier 가 디버깅 중 테스트를 돌리는 것 자체를 막지는 않지만(Bash 를 갖고 있고 setup
확인에 필요하다), **그 결과가 판정에 들어가는 경로**를 막는다. verifier 의 evidence-log
테스트 결과는 advisory 이고 이 호출 결과가 authoritative 다.
````

- [ ] **Step 6: Runtime 게이트 섹션 교체 — 후반부 (R6 ~ R9)**

기존 `**Step R4 — Mutation guard …**`(696행)부터 publish sentinel 문단 끝(741행)까지를 아래로 교체한다:

````markdown
**Step R6 — 대조 (결정론).** 어댑터마다 한 번씩:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" \
  --expected "$expected_units_file" \
  --baseline "$baseline_rows_file" --head "$head_rows_file" \
  --granularity "$granularity" --runner "$runner" > "$per_adapter_yaml"
```

`--expected` 는 R1b 가 고른 unit 목록이다 — **두 산출물의 상호 대조가 아니라 독립
입력**이라야 두 스크립트가 같은 정규화 버그로 같은 unit 을 대칭 누락할 때 잡힌다.

**flaky — 재실행은 정확히 1회다 — green 이 나올 때까지가 아니다.** `NEW_REGRESSION`
후보만 HEAD 에서 1회 재실행한다. 또 fail 이면 확증 `NEW_REGRESSION`, pass 면 `FLAKY`
로 기록하고 게이트를 FAIL 시키지 않되 **보고서에 올린다**. 기준선에서 이미 red 인 것은
재실행 대상이 아니다(이미 `PRE_EXISTING`). 재실행 후에는 갱신된 `--head` 로
`diff-test-results.py` 를 다시 호출하고, **그 마지막 호출의 결과가 authoritative** 다.
여기서 위험은 false green 이 아니라 false red 이고, **무한 재실행이 바로 false green
경로**이므로 1회로 잠근다.

그다음 어댑터 YAML 들을 집계한다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/diff-test-results.py" --aggregate \
  --expected-adapters "$adapter_count" "${per_adapter_yamls[@]}"
```

`verdict_input`(`confirmed_product_defect` / `silent_drop` / `baseline_unrunnable`)과
`attribution_status` 를 캡처한다. 이 집계를 손으로 하지 않는다 — N 개 YAML 을 읽고
최악값을 고르면 불변식 ②가 결과값에서 없앤 "모델 요약이 판정을 결정"이 집계 레이어에서
재입장한다. 입력 개수가 안 맞으면 스크립트가 exit 4 로 fail-closed 한다.

**Step R7 — Mutation guard (authoritative verdict cap).** Unless in read-only
fallback, compute the product-mutation oracle:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>" "<snapshot_digest>"
```

Read the YAML. **If `forced_downgrade: yes`**, the verdict is capped at FAIL
regardless of the verifier's emitted verdict (Law 2 — the verifier cannot
self-approve a product change). Surface `tracked_diff` + `disallowed_new_files` as
evidence. The verifier's own `writes:` self-report is advisory only; this git result
is authoritative.

**R7 exit-code routing (an indeterminate guard is never a PASS).** Capture BOTH the
guard's stdout YAML AND its exit code:

| Guard result | R7 routing |
|---|---|
| exit 0 + `forced_downgrade: no` | no product mutation → proceed to R8 normally |
| exit 0 + `forced_downgrade: yes` | cap verdict at FAIL; surface `tracked_diff` / `disallowed_new_files` / `guard_flags` as evidence |
| **exit 4** (`guard_fail`), OR any other non-zero exit, OR a missing/invalid `forced_downgrade` key, OR a `guard_error:` line present | treat as `forced_downgrade: yes` → cap verdict at FAIL; surface the guard's `guard_error` + **stderr verbatim**; mark the Runtime gate failed. **Never read an errored or garbled guard as PASS** (indeterminate ≠ clean). |

A digest mismatch (the verifier forged the snapshot) surfaces here as **exit 4** with
`guard_error: snapshot integrity check failed` — the seal the guard checks is held by
the orchestrator, out of the verifier's reach.

**Fallback working-tree guard (read-only mode only).** When the sandbox was disabled
(Exit 3), do NOT run the sandbox `mutation-guard`. The verdict is already capped at
SKIP_WITH_EVIDENCE (R5a¹); this guard is a pure SAFETY SIGNAL, not a verdict input.
After the R5a³ dispatch, recompute `fallback_post`. If anything changed, emit a loud
warning to user-visible stdout AND record it in `evidence_dir`:
`> [quality-gates] WARNING: runtime fallback 에서 working tree 가 변경됨 — <changed files>. sandbox 미사용으로 구조적 보호 없음; 검토 요망 (git diff 후 revert 권장).`
git-ignored files do not appear in `--porcelain`, so a setup-only `.env` fix is
correctly NOT flagged. The warning does not change the verdict and does not block
the gate.

**Step R8 — 원장 + verdict + outcome routing.**

evidence-log 에 floor 5차원 원장을 쓴다 (spec-distill 커버리지 원장과 같은 줄 모양):

```
- floor:changed      — closed   — <무엇이 바뀌었나; 러너 특정>
- floor:behavior     — closed   — <어떤 행동/경로에 닿나>
- floor:verification — closed   — <실행된 것 + 실행 방식(차등/bulk)>
- floor:attribution  — closed   — <모든 fail 의 귀속 라벨>
- floor:gap          — closed   — <못 확인한 것 전부 열거 (0개면 "없음"도 명시)>
- derived: 없음 — <왜 0개인지>
```

`degraded` 는 실패가 아니라 **1급 상태**다. 다음 라우팅으로 status 를 정한다:

| 못 확인한 것 | 원장 | PASS |
|---|---|---|
| **영향분**을 못 돌림 (러너 부재 exit 3 · baseline 불가 · 귀속 불가 · `unclaimed` 존재) | `verification` 또는 `attribution` 이 **`degraded`** | **불가** |
| **영향분과 무관한** 표면을 안 돌림 (다른 러너 부재 · 자동화 불가 플로우 · 미선택분 · `미실행 러너`) | `gap` 에 **열거하고 `closed`** | 가능 |

`gap: closed` 와 `verification: degraded` 는 다른 뜻이다 — `gap` 은 *"못 확인한 것을
빠짐없이 열거했다"* 이므로 열거가 곧 닫힘이고, `degraded` 는 *"확인하기로 한 것을 못
확인했다"* 이므로 인증 불가다.

> **`unclaimed` 가 하나라도 있으면 `verification: degraded` 이고 verdict 를 PASS 로 올리지 않는다.**
>
> 목록은 `gap` 에도 열거하되, **열거가 인증을 대신하지 않는다.** `unclaimed` unit 은
> 정의상 R1b 가 **영향분으로 판정한** 것이고, 실행 수단이 없다는 것은 위 표의
> "영향분을 못 돌림"을 만족한다. 이 규칙이 없으면 8종 미지원 레포에서 **테스트가 한
> 개도 안 돈 채 PASS** 가 나온다.

구조 게이트를 돌린다:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/check_qa_ledger.py" "<evidence-log-path>"
```

non-zero 면 stderr 를 verbatim 으로 노출하고 **verdict 를 PASS 로 올리지 않는다**.

verdict 결정:

| verdict | 조건 |
|---|---|
| `PASS` | floor 5차원 전부 `closed` **and** `confirmed_product_defect: false` **and** `silent_drop: false` **and** `forced_downgrade: no` **and** 상황별 층 통과 |
| `FAIL` | `confirmed_product_defect: true` **or** `forced_downgrade: yes` **or** 상황별 층(부팅/플로우) 실패 |
| `SKIP_WITH_EVIDENCE` | 영향분 0개 → `SKIP_WITH_EVIDENCE` **or** `baseline_unrunnable: true` **or** `silent_drop: true` **or** 어느 floor 차원이 `degraded` |
| `NEEDS_RESOLUTION` | setup-fixable 잔존 — **기존 무변경** |

**동시 성립 시 총 순서** (표의 행은 배타가 아니다):

```
확증 제품결함(FAIL, terminal)  >  NEEDS_RESOLUTION  >  SKIP_WITH_EVIDENCE  >  PASS
```

- **확증 제품결함**(`confirmed_product_defect: true` · `forced_downgrade: yes`)은
  **terminal** 이며 어떤 degrade 사유로도 downgrade 되지 않는다. `silent_drop` 이나
  floor degraded 가 같이 성립해도 verdict 는 `FAIL` 이다.
  그리고 **degrade 사실은 원장과 보고서에 함께 기록된다** — 삼켜지지 않는다.
- 그 외의 FAIL 사유(부팅 실패 등)와 `NEEDS_RESOLUTION` 이 동시면 `NEEDS_RESOLUTION`
  이 이긴다 (기존 `runtime-verifier.md` 선례 승계).
- **어느 방향으로도 degrade 사유가 PASS 를 만들지 못하고, degrade 사유가 확증 결함을
  지우지도 못한다.**

`granularity: bulk` 어댑터가 실행됐으면 최종 보고서에도 **항상**
`커버리지 미보장(러너가 선택을 무시함)` 을 남긴다 — 그 실행의 주장은 "영향분을
확인했다"가 아니라 "러너 전체를 돌렸고 그 안에 영향분이 포함되기를 기대한다"이다.
양쪽 red 인 bulk 어댑터에는 다음을 그대로 쓴다:

> `기준선도 빨간 상태입니다. 이 러너(<runner>)는 파일 단위 지목이 안 되므로 그 안에 새 회귀가 숨었는지 구분하지 못했습니다.`

**Outcome routing** (verdict = min(위 verdict, guard cap, fallback cap)):

- **Fallback mode (sandbox disabled)** → a `PASS` becomes **SKIP_WITH_EVIDENCE**;
  `FAIL`/`NEEDS_RESOLUTION` pass through unchanged.
- **Clean (PASS) AND `forced_downgrade: no`** → print `## Runtime gate — clean` and
  continue to final summary.
- **`forced_downgrade: yes`** → print the Runtime gate FAIL block including the
  surfaced diff; emit final summary marked Runtime gate failure. Do NOT auto-restart,
  do NOT apply the diff.
- **FAIL** → print verdict block (귀속 표 + 원장 포함); final summary marked failure.
- **SKIP_WITH_EVIDENCE** → print evidence (원장 포함); continue.
- **NEEDS_RESOLUTION** → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision).

**Publish-eligible sentinel (single-gate `/qg runtime` — non-aborted terminal
only).** `/qg runtime` 은 Dispatch Loop 를 우회하므로 Final Summary 기록 지점에
도달하지 않을 수 있다. R8 이 **비중단 terminal**(clean / `forced_downgrade: yes` /
FAIL / SKIP_WITH_EVIDENCE)로 종결하면 여기서
`.claude/quality-gates/<sid>/publish-eligible.md` 에 [Publish-eligible
sentinel](#publish-eligible-sentinel)을 `Write` 한다(`<verdict>` = 그 R8 verdict
token). **NEEDS_RESOLUTION → Stop 및 사용자 Stop 경로에서는 쓰지 않는다.** Final
Summary 도 도달했다면 idempotent overwrite 라 무해.

**Step R9 — Discard the sandbox** (verdict-independent), unless in read-only fallback:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "<sandbox_dir>"
```
````

- [ ] **Step 7: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_runtime_verdict_precedence.sh`
Expected: PASS — `runtime verdict precedence: 14 passed, 0 failed`

Run: `bash plugins/quality-gates/scripts/check-allowed-tools-order.sh`
Expected: OK

Run: `bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh`
Expected: PASS

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh`
Expected: PASS — 특히 `case_no_reimpl_in_skill` (SKILL.md 에 감지 조건 문자열 0회)

Run: `bash plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh`
Expected: PASS (신규 스크립트가 좁은 allowlist 규칙을 만족)

- [ ] **Step 8: M6 / M19 / M24 mutation 확인 (손으로, 되돌릴 것)**

| mutation | 편집 | RED가 되어야 할 케이스 |
|---|---|---|
| **M6** | R6 의 "재실행은 정확히 1회다" 문장을 "green 이 나올 때까지 재실행한다"로 | `case_skill_rerun_exactly_once` |
| **M19** | R8 라우팅 표에서 "러너 부재"를 `gap: closed` 행으로 옮김 | `case_skill_unclaimed_blocks_pass` (같은 윈도우의 규칙 문장이 사라짐) |
| **M24** | `unclaimed` 인용 블록을 삭제 | `case_skill_unclaimed_blocks_pass` |

- [ ] **Step 9: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/scripts/check-allowed-tools-order.sh \
        plugins/quality-gates/tests/test_runtime_verdict_precedence.sh
git commit -m "feat(quality-gates)!: Runtime 게이트를 영향-구동 차등 실행으로 개정

'전체 앱을 무조건 돌린다'를 지우고 그 자리에 영향-구동 + merge_base 기준선 대비
차등 실행을 놓는다. run-test-selection.sh는 기준선 측(R4)·HEAD 측(R5b) 둘 다
오케스트레이터가 직접 호출한다 — verifier가 테스트 결과를 self-report하는 경로는
금지다. 그러면 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 되고,
LD5가 막으려던 '모델 주장이 자기 검증을 결정'이 재입장한다.

기존 스텝 8종(detect-runtime · zero-click 폴백 · create-sandbox 3줄 파싱 ·
test-scope-validator · spec AC · verifier dispatch · mutation-guard · publish
sentinel)은 전부 새 자리를 갖는다 — 자리 없는 로직은 삭제가 아니라 누락이다.

BREAKING CHANGE: /qg runtime 인터페이스는 유지되지만 '전체 앱을 돌린다'에
의존하던 동작이 사라진다.

AC1 AC2 AC10 AC12 AC19 AC20 AC23 AC31 AC35 AC44 AC47 AC49 AC53 AC57
· T8 T21 T28 T30 T31 T40 T46 T51 T55 · M5 M6 M11 M15 M19 M24"
```

---

## Task 12: 락 이전 — `test_skill_orchestration_behavior.sh`

**Files:**
- Modify: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (`:205-207`, `:300-306`, `:406-417`, `:450`)

**Interfaces:**
- Consumes: Task 11의 개정된 SKILL.md 스텝 라벨
- Produces: 이전된 회귀 락. 이후 어떤 task 도 이 라벨들을 옮기려면 이 파일도 같이 고쳐야 한다.

**락 이전이지 삭제가 아니다.** 라벨만 지우고 테스트를 남기면 스위트가 빨개지고, 테스트만 지우면 회귀 방어가 사라진다. 두 실패 모드 모두 피하는 유일한 방법은 **같은 커밋에서 새 라벨로 옮기는 것**이다.

**라벨 매핑 (Task 11이 확정한 것):**

| 기존 락 라벨 | 새 라벨 | 기존 내용 |
|---|---|---|
| `Step R-init` | `Step R5a⁰` | `detect-runtime.sh` manifest + zero-click 폴백 |
| `Step R0` | `Step R5a¹` | `create-sandbox` 3줄 파싱 + digest |
| `Step R1` | `Step R1b` | `test-scope-validator` dispatch |
| `Step R2` | `Step R5a²` | spec AC 수집 |
| `Step R3` | `Step R5a³` | `runtime-verifier` dispatch |
| `Step R4` | `Step R7` | `mutation-guard` |
| `Step R5` | `Step R9` | sandbox `remove` |
| `Step R6` | `Step R8` | outcome routing + publish sentinel |

> **`Step R-init` 은 이름이 재사용된다** — 새 문서에서 `Step R-init` 는 *baseline 확정*을 뜻한다. 그래서 기존 `R-init` 락(detect-runtime 실행 검사)을 `Step R5a⁰` 으로 옮기지 않으면, 락은 통과하는데 검사 대상이 바뀌어 조용히 무의미해진다. 이것이 이 task 에서 가장 놓치기 쉬운 지점이다.

- [ ] **Step 1: 새 락을 먼저 추가 (T48 · AC51)**

`test_skill_orchestration_behavior.sh` 끝부분에 추가:

```bash
# ── T48 / AC51: 스텝 락 이전 + 기존 로직 8종이 전부 새 자리를 갖는다 ──
# 자리 없는 기존 로직은 삭제가 아니라 누락이다. 8종을 이름으로 센다.
echo "== 락 이전 검사"
legacy_logic=(
  'detect-runtime.sh'                       # 매니페스트
  'block_policy'                            # zero-click 폴백
  'snapshot_digest'                         # create-sandbox 3줄 파싱
  'quality-gates:test-scope-validator'      # 분류 dispatch
  'spec_acceptance_criteria'                # spec AC 수집
  'quality-gates:runtime-verifier'          # verifier dispatch
  'mutation-guard'                          # Law 2 오라클
  'publish-eligible.md'                     # publish sentinel
)
missing_logic=0
for lg in "${legacy_logic[@]}"; do
  if ! grep -qF "$lg" "$SKILL_MD"; then
    echo "FAIL: 기존 로직 '$lg' 가 새 SKILL.md 에 없음 (자리 없는 로직 = 누락)"
    missing_logic=$((missing_logic + 1))
  fi
done
[[ $missing_logic -eq 0 ]] && echo "PASS: 기존 로직 8종 전부 새 자리에 존재" || FAILURES=$((FAILURES + 1))

# 새 라벨 5종이 실제로 존재하고 순서가 맞다
r5a0=$(first_line 'Step R5a⁰'); r5a1=$(first_line 'Step R5a¹')
r5a2=$(first_line 'Step R5a²'); r5a3=$(first_line 'Step R5a³')
r8=$(first_line 'Step R8')
for pair in "R5a⁰:$r5a0" "R5a¹:$r5a1" "R5a²:$r5a2" "R5a³:$r5a3" "R8:$r8"; do
  assert_line "새 라벨 ${pair%%:*} 존재" "${pair#*:}"
done
assert_order "R5a⁰ precedes R5a¹" "$r5a0" "$r5a1"
assert_order "R5a¹ precedes R5a²" "$r5a1" "$r5a2"
assert_order "R5a² precedes R5a³" "$r5a2" "$r5a3"

# 기존 R-init 락이 검사하던 것(detect-runtime 실행)은 이제 R5a⁰ 의 책임이다
assert_line "R5a⁰ runs detect-runtime" "$(first_line_after 'detect-runtime' "$r5a0")"

# ── T1 / AC1 / AC2 / M3: 앵커 이전 ──
echo "== transparency 앵커 이전"
old_literal=$(grep -cF 'regardless of Review scope' "$SKILL_MD" || true)
if [[ "$old_literal" -eq 0 ]]; then
  echo "PASS: 구 리터럴 'regardless of Review scope' 0회"
else
  echo "FAIL: 구 리터럴이 ${old_literal}회 잔존"; FAILURES=$((FAILURES + 1))
fi
new_anchor='이번 변경의 영향분만 기준선 대비로 돌린다'
anchor_count=$(grep -cF "$new_anchor" "$SKILL_MD" || true)
if [[ "$anchor_count" -eq 1 ]]; then
  echo "PASS: 신 앵커 정확히 1회"
else
  echo "FAIL: 신 앵커가 ${anchor_count}회 (정확히 1회여야 함)"; FAILURES=$((FAILURES + 1))
fi
# 앵커는 R2(계획 산문)와 R3(갭 게이트) 사이에 있어야 한다
anchor_line=$(first_line "$new_anchor")
r2_marker=$(first_line '^\*\*Step R2'); r3_marker=$(first_line '^\*\*Step R3')
if [[ -n "$anchor_line" && "$anchor_line" -gt "$r2_marker" && "$anchor_line" -lt "$r3_marker" ]]; then
  echo "PASS: 앵커가 Step R2($r2_marker)와 Step R3($r3_marker) 사이 ($anchor_line)"
else
  echo "FAIL: 앵커 위치 ($anchor_line, R2=$r2_marker R3=$r3_marker)"; FAILURES=$((FAILURES + 1))
fi

# ── T22 / AC31 / M12: 호출 주체 — run-test-selection.sh 가 verifier dispatch 블록 밖 ──
echo "== 호출 주체 불변식"
r5b=$(first_line 'Step R5b')
in_block=0
while IFS= read -r ln; do
  n="${ln%%:*}"
  if [[ "$n" -gt "$r5a3" && "$n" -lt "$r5b" ]]; then in_block=$((in_block + 1)); fi
done < <(grep -n 'run-test-selection.sh' "$SKILL_MD")
if [[ "$in_block" -eq 0 ]]; then
  echo "PASS: run-test-selection.sh 호출이 verifier dispatch 블록(R5a³..R5b) 안에 0회"
else
  echo "FAIL: verifier dispatch 블록 안에서 run-test-selection.sh 호출 ${in_block}회"
  FAILURES=$((FAILURES + 1))
fi
if grep -qF '이 호출 결과가 authoritative' "$SKILL_MD"; then
  echo "PASS: authoritative 문장 존재"
else
  echo "FAIL: authoritative 문장 부재"; FAILURES=$((FAILURES + 1))
fi
```

> **`FAILURES` / `SKILL_MD` / `first_line` / `first_line_after` / `assert_line` / `assert_order`** 는 이 파일에 이미 있는 헬퍼다. 이름을 확인하고 그대로 쓴다 — 새로 정의하면 두 카운터가 갈린다.

- [ ] **Step 2: 새 락이 통과하는지 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: 새 블록은 PASS. **기존 락(`:205` `Step R0`, `:303` `Step R-init`, `:406-417`, `:450` `Step R6`)은 FAIL** — 라벨이 사라졌기 때문이다.

- [ ] **Step 3: 기존 락 4곳을 새 라벨로 이전**

| 위치 | 편집 |
|---|---|
| `:205-207` | `first_line 'Step R0'` → `first_line 'Step R5a¹'`, 주석의 "R0 must capture snapshot_digest in the R0 section" → "R5a¹ …" |
| `:300-306` | `first_line 'Step R-init'` → `first_line 'Step R5a⁰'`, 관련 assert 메시지 3개도 라벨 갱신 |
| `:406-417` | 이 블록은 Step 1에서 추가한 **transparency 앵커 이전** 블록이 대체한다. 통째로 삭제 (중복 검사 금지 — 두 곳이 다른 문구를 잠그면 drift 한다) |
| `:450` | `first_line 'Step R6'` → `first_line 'Step R8'` |

- [ ] **Step 4: 전체 통과 확인**

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — `FAILURES=0`

Run: `bash plugins/quality-gates/tests/test_skill_orchestration.sh` (형제 스위트)
Expected: PASS

- [ ] **Step 5: M3 mutation 확인 (손으로, 되돌릴 것)**

SKILL.md 의 앵커 문장을 (a) 삭제 → 앵커 카운트 0 → RED, (b) 한 번 더 복사 → 카운트 2 → RED. **양방향 둘 다** 확인한다 — 존재만 검사하는 락은 중복 삽입을 못 잡는다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "test(quality-gates): 스텝 락을 새 라벨로 이전 + 호출 주체 락 추가

라벨만 지우고 테스트를 남기면 스위트가 빨개지고, 테스트만 지우면 회귀 방어가
사라진다. 같은 커밋에서 8종 라벨을 옮기고, 기존 로직 8종이 전부 새 자리를 갖는지
이름으로 센다. 새로 추가: transparency 앵커 양방향 락(존재+유일성)과
run-test-selection.sh 호출이 verifier dispatch 블록 밖에 있는지의 **위치** 검사 —
결과값이 같아 보이므로 위치로만 잡힌다.

AC1 AC2 AC31 AC51 · T1 T22 T48 · M3 M12"
```

---

## Task 13: `runtime-verifier.md` 페르소나 개정

**Files:**
- Modify: `plugins/quality-gates/agents/runtime-verifier.md` (역할 경계 절 + assertion-basis 절)
- Modify: `plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` (본문 락 2줄 추가)

**Interfaces:**
- Consumes: Task 11의 R5a³ dispatch 계약 (입력 필드는 **무변경**)
- Produces: 개정된 페르소나. 입출력 필드도, `tools:` allowlist 도 바뀌지 않는다.

**바꾸지 않는 것 (중요):**
- **`tools:` allowlist** — `test_runtime_verifier_frontmatter.sh` 가 22+1 집합을 정확히 잠근다. 한 줄이라도 건드리면 그 테스트가 빨개진다. verifier 는 여전히 Bash 를 갖는다 — 디버깅 중 테스트를 돌리는 것 자체를 막지 않기 때문이다. 막는 것은 **그 결과가 판정에 들어가는 경로**이고, 그것은 도구 deny 가 아니라 오케스트레이터의 별도 호출로 보장된다.
- **dispatch 입력 필드** · **verdict 4종** · **evidence-log 의 `functional_assertions` / `ac_id` 스키마** — 각각 기존 테스트가 잠근다.

**바꾸는 것:** 역할 경계 두 줄. verifier 는 이제 floor 가 아니라 **floor 위의 상황별 층**을 담당한다.

- [ ] **Step 1: 락을 먼저 추가** — `tests/test_runtime_verifier_frontmatter.sh` 의 본문 assert 블록(`assert_grep "sandbox" …` 근처)에 추가

```bash
# AC31 — 테스트 실행 결과 self-report 가 판정에 쓰이지 않음을 페르소나가 명시한다.
# 이 문장이 없으면 verifier 는 자기 턴에서 돌린 테스트 결과를 evidence-log 에 실어
# 보내도 된다고 읽고, 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 된다.
assert_grep "테스트 실행 결과는 판정에 들어가지 않는다" "AC31: self-report 배제 문구"

# AC41 — 테스트 러너용 deps 설치는 verifier 의 책임이 아니다. 어댑터의 setup_cmd 가
# 양측에서 같은 명령으로 돌아야 차등 비교가 사과와 오렌지가 되지 않는다.
assert_grep "테스트 러너용 deps 설치는 하지 않는다" "AC41: deps 설치 배제 문구"
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`
Expected: FAIL — 새 assert 2개 red

- [ ] **Step 3: 페르소나 본문 개정**

(a) 역할 선언부(dispatch 입력 필드 목록 **바로 뒤**)에 **You are NOT responsible for** 절을 추가한다. 기존에 이 절이 있으면 항목만 덧붙인다:

```markdown
## 당신이 책임지지 **않는** 것

- **테스트 러너 실행 결과의 제출.** 디버깅 중 테스트를 돌리는 것은 자유다 — setup 이
  됐는지 확인하려면 필요하다. 하지만 **테스트 실행 결과는 판정에 들어가지 않는다.**
  오케스트레이터가 당신의 턴이 끝난 뒤 `run-test-selection.sh` 를 직접 호출하고, 그
  결과가 authoritative 다. evidence-log 에 테스트 결과를 적더라도 그것은 advisory 이며,
  둘이 다르면 오케스트레이터의 호출 결과를 쓴다. (`writes:` self-report 를
  mutation-guard 가 대하는 방식과 같다.)
- **테스트 러너용 deps 설치.** **테스트 러너용 deps 설치는 하지 않는다** — 그것은
  어댑터의 `setup_cmd` 이고 기준선·HEAD 양측에서 **같은 명령**으로 돌아야 한다. 두 측이
  다른 명령·다른 환경으로 준비되면 차등 비교가 사과와 오렌지가 된다. 당신이 하는 setup
  은 **앱 부팅용**(서버 `.env`, 서비스 기동 전제 등)에 한정된다.
- **무엇을 검증할지의 스코프 판정.** 영향 스코프는 오케스트레이터가 정한다 (기존 계약
  유지). 매니페스트는 verbatim 으로 읽고 재감지하지 않는다.

HEAD 에만 적용한 추가 setup 이 있으면 그것은 양측 비대칭이므로 evidence-log 에
**기록하고 표면화**한다 — 조용히 넘어가면 기준선에 없는 환경 차이가 회귀로 오인된다.
```

(b) 역할 요약 첫 문단에서 "전체 앱을 부팅해 AC 를 단언한다" 취지의 서술을 **"승인된 표면을 부팅하고 플로우를 구동해 AC 를 단언한다"** 로 좁힌다. 기존 `approved_surfaces` 계약과 동어반복이 되므로 새 개념이 아니라 정확화다.

(c) frontmatter `description` 의 첫 문장에서 "Runtime gate" 정의는 그대로 두되, 이 게이트가 floor 를 소유한다는 함의가 있으면 제거한다. **`tools:` 줄은 건드리지 않는다.**

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`
Expected: PASS

Run: `python3 plugins/quality-gates/tests/test_runtime_verifier_behavior.py`
Expected: PASS (evidence-log 스키마 무변경)

Run: `bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh`
Run: `bash plugins/quality-gates/tests/test_agent_tools_lock_differential.sh`
Run: `bash plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh`
Expected: 셋 다 PASS (도구 표면 무변경)

Run: `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/agents/runtime-verifier.md \
        plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh
git commit -m "feat(quality-gates): runtime-verifier 페르소나 — floor 위의 상황별 층만

verifier는 이제 setup·부팅·플로우만 담당한다. 테스트 실행 결과는 판정에 들어가지
않고(오케스트레이터의 별도 호출이 authoritative), 테스트 러너용 deps 설치도 하지
않는다(어댑터의 setup_cmd가 양측에서 같은 명령으로 돈다).

tools: allowlist는 무변경 — 분리는 도구 deny가 아니라 호출 지점의 구조로 보장된다.
verifier는 여전히 Bash를 갖고 디버깅 중 테스트를 돌릴 수 있다.

AC25 AC31 AC41 · T22 T37"
```

---

## Task 14: 버전 · CHANGELOG · README

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (`2.14.3` → `3.0.0`)
- Modify: `plugins/quality-gates/CHANGELOG.md` (`## [3.0.0] — <오늘 UTC 날짜>` 항목)
- Modify: `plugins/quality-gates/README.md` (인스턴스화한 원칙 3줄 + 구조 트리 5종)
- Create: `plugins/quality-gates/tests/test_impact_runtime_docs.sh`

**Interfaces:**
- Consumes: Task 1~13의 전체 산출물
- Produces: 없음 (문서). 이것이 마지막 task 다.

- [ ] **Step 1: 실패하는 테스트 작성** — `plugins/quality-gates/tests/test_impact_runtime_docs.sh`

```bash
#!/usr/bin/env bash
# test_impact_runtime_docs.sh — 버전 · README 문서 락. AC29 AC30 · T20 T33
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"
README="$PLUGIN_ROOT/README.md"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

NEW_SCRIPTS=(resolve-baseline.sh run-test-selection.sh baseline-cache.sh
             diff-test-results.py check_qa_ledger.py)

# T20 + AC29: major digit 만 핀한다. `"version": "3.0.0"` 리터럴을 핀하면
# doc-only patch bump 마다 stale-red 가 된다 — 불변식만 검사하고 patch 는 unpin.
case_major_bump() {
  local v major
  v=$(python3 -c "
import json
with open('$MANIFEST', encoding='utf-8') as f:
    print(json.load(f)['version'])
")
  major="${v%%.*}"
  [[ "$major" == "3" ]] && pass "plugin.json major digit == 3 (v$v)" \
                        || fail "major digit $major (기대 3, v$v)"
}

# AC29: CHANGELOG 에 3.0.0 항목이 있고 날짜가 리터럴 placeholder 가 아니다
case_changelog_entry() {
  if grep -qE '^## \[3\.0\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$CHANGELOG"; then
    pass "CHANGELOG [3.0.0] 항목 + 실제 날짜"
  else
    fail "CHANGELOG [3.0.0] 항목 부재 또는 날짜 형식 위반 (placeholder 금지)"
  fi
  local sec ok=1
  for sec in Added Changed Removed; do
    awk '/^## \[3\.0\.0\]/{i=1;next} i && /^## \[/{exit} i' "$CHANGELOG" \
      | grep -q "^### $sec" || { echo "    누락 섹션: $sec"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "CHANGELOG 3.0.0 에 Added/Changed/Removed" || fail "CHANGELOG 섹션 누락"
}

# T33 + AC30: README 컴포넌트 트리에 신규 5종이 전부 등재
case_readme_component_tree() {
  local s missing=0
  for s in "${NEW_SCRIPTS[@]}"; do
    grep -qF "$s" "$README" || { echo "    README 미등재: $s"; missing=1; }
  done
  [[ $missing -eq 0 ]] && pass "README 에 신규 스크립트 5종 등재" || fail "README 컴포넌트 트리 누락"
}

# T33 + AC30: 인스턴스화한 원칙에 LD3/LD5/LD7 줄
case_readme_principles() {
  local w ok=1 tok
  w=$(awk '/^## 인스턴스화한 원칙/{i=1;next} i && /^## /{exit} i' "$README")
  for tok in 'LD3' 'LD5' 'LD7'; do
    printf '%s\n' "$w" | grep -qF "$tok" || { echo "    누락: $tok"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "인스턴스화한 원칙에 LD3/LD5/LD7" || fail "원칙 줄 누락"
}

# 신규 스크립트 5종이 실제로 존재하고 실행 가능 (6번째가 생기지 않았는지도 확인)
case_exactly_five_new_scripts() {
  local s ok=1
  for s in "${NEW_SCRIPTS[@]}"; do
    [[ -x "$PLUGIN_ROOT/scripts/$s" ]] || { echo "    부재/비실행: $s"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "신규 스크립트 5종 존재 + 실행 가능" || fail "신규 스크립트 문제"
}

for c in case_major_bump case_changelog_entry case_readme_component_tree \
         case_readme_principles case_exactly_five_new_scripts; do
  echo "== $c"; $c
done
echo "── impact runtime docs: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `bash plugins/quality-gates/tests/test_impact_runtime_docs.sh`
Expected: FAIL — major digit 2, CHANGELOG 항목 부재, README 미등재

- [ ] **Step 3: `plugin.json` major bump**

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `"version": "2.14.3"` → `"version": "3.0.0"`.

- [ ] **Step 4: `CHANGELOG.md` 항목 추가**

`## [2.14.3]` **위**에 삽입한다. `<오늘>` 은 이 커밋을 만드는 날의 UTC `YYYY-MM-DD` 로 치환 (`date -u +%F`) — 리터럴 placeholder 금지:

```markdown
## [3.0.0] — <오늘>

### Changed
- **Runtime 게이트가 "전체 앱을 무조건 돌린다"를 버리고 영향-구동 차등 실행으로 바뀌었다.**
  `SKILL.md` 의 *"Runtime runs the whole app regardless of Review scope."* 리터럴이
  사라지고 그 자리에 *"이번 변경의 영향분만 기준선 대비로 돌린다"* 가 들어간다. 모델이
  무엇을 돌릴지 한 번 고르고, 그 선택을 결정론이 merge_base 기준선과 HEAD 양쪽에서 두 번
  실행해 짝짓는다 — 귀속(이 fail 은 내 탓인가)과 백스톱(결과가 조용히 비었나)이 같은
  메커니즘에 얹힌다.
- **`runtime-verifier` 는 floor 가 아니라 floor 위의 상황별 층을 담당한다.** setup·부팅·
  플로우만 맡고, 테스트 실행 결과는 판정에 들어가지 않는다 — 오케스트레이터가 verifier 턴
  *밖에서* `run-test-selection.sh` 를 직접 호출한 결과가 authoritative 다. verifier 가 자기
  결과를 self-report 하면 오케스트레이터가 받는 것이 raw 출력이 아니라 모델의 요약이 되고,
  결정론 백스톱이 모델 주장과 독립이라는 전제가 무너진다.
- **baseline resolution 이 공유 모듈로 추출됐다.** `check-review-scope.sh` 의 하드닝된
  resolution(origin/HEAD→main→master→local · merge-base · shallow/detached 감지)을
  `resolve-baseline.sh` 가 소유하고, Review·Runtime 양쪽이 함께 쓴다.

### Added
- `scripts/resolve-baseline.sh` — `base`/`base_ref`/`merge_base`/`degraded` 4키.
- `scripts/run-test-selection.sh` — 러너 어댑터 8종(pytest·unittest·shell·jest·vitest·
  go·cargo·make·npm-script)의 유일 소유자. `detect`(감지, **집합** 반환) /
  `assign`(파일→unit 배정) / `run`(총 함수 결정론 실행).
- `scripts/baseline-cache.sh` — `(merge_base, runner, unit)` 내용주소 캐시. 기준선 실행이
  `/qg` 호출당이 아니라 merge_base 당 1회가 된다.
- `scripts/diff-test-results.py` — 귀속 8종 + 어댑터 간 `--aggregate`.
- `scripts/check_qa_ledger.py` — floor 5차원(changed/behavior/verification/attribution/gap)
  구조 게이트.
- `qg-worktree.sh create-baseline` · `compute-test-scope-candidates.sh --total`.

### Removed
- `SKILL.md` 의 `regardless of Review scope` 리터럴과 그것이 서술하던 동작.

### Fixed
- **`qg-gc.py` 가 살아있는 `worktrees/` 를 삭제할 수 있던 결함** — `SESSION_PATTERN`
  (charset)이 형제 디렉토리 `worktrees`(9자)·`baseline-cache`(14자)도 매치했다.
  `worktrees/` 엔 직접 파일이 없어 폴더 mtime 으로 TTL 이 계산되고, 24시간 넘게 새
  worktree 가 추가되지 않으면 **안에 살아있는 worktree 를 안고** rmtree 됐다. 이제 알려진
  세션 마커 파일을 가진 디렉토리만 sweep 한다. denylist 를 쓰지 않은 이유는 공간에는 맞지만
  **시간에 fail-open** 이기 때문이다 — 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다.
- **`compute-test-scope-candidates.sh` 의 `main` 하드코딩 + merge-base 부재** — Review
  게이트가 이미 고친 버그 클래스가 Runtime 쪽에 남아 있었다.
```

- [ ] **Step 5: `README.md` 개정**

(a) `## 인스턴스화한 원칙` 절에 세 줄 추가:

```markdown
- **LD3 (floor 는 실행이다) — 영향분 테스트의 실제 실행** (v3.0.0) — Runtime 게이트의 floor
  가 "전체 앱 부팅"이 아니라 *"레포에 이미 있는 테스트 중 영향분을 실제로 돌리는 것"*이다.
  `run-test-selection.sh` 가 어댑터 8종을 **집합으로** 감지해 전부 실행한다 — 폴리글랏
  레포에서 우선순위 밖 러너를 버리면 floor 가 의미를 잃는다(이 리포 실측: `.sh` 130개 /
  `.py` 50개). 부팅·플로우는 floor 가 아니라 그 위의 상황별 층이다.
- **LD5 (결정론은 모델 주장과 독립인 백스톱) — 호출 주체 분리** (v3.0.0) — 영향 스코프
  판정은 모델이 하되, `run-test-selection.sh` 는 기준선 측·HEAD 측 **둘 다 오케스트레이터가
  직접** 호출한다. verifier 가 테스트 결과를 self-report 하면 오케스트레이터가 받는 것이 raw
  출력이 아니라 모델의 요약이 되어 백스톱이 백스톱이 아니게 된다. `diff-test-results.py` 의
  `--expected` 도 같은 이유로 **독립 입력**이다 — 두 생산자의 상호 대조로 계산하면 대칭
  누락을 아무도 못 잡는다. regression: `tests/harness/test_skill_orchestration_behavior.sh`
  (호출 위치), `tests/test_diff_test_results.py` (대칭 누락).
- **LD7 (질문형 루브릭) — floor 5차원 원장** (v3.0.0) — `changed`/`behavior`/`verification`/
  `attribution`/`gap` 다섯 **질문**과 의무 `derived`. `check_qa_ledger.py` 는 **구조만** 본다
  (의미 판정 없음) — Law 1 의 구조적 게이트가 하는 일은 silent skip 을 불가능하게 만드는
  것뿐이다. `degraded` 는 실패가 아니라 1급 상태다: "확증 못 했다"를 정직하게 쓸 자리가
  있어야 "확인했다"로 반올림되지 않는다. 점수형·테스트종류 메뉴는 두지 않는다.
```

(b) `## 구조` 트리의 `scripts/` 블록에 5줄 추가 (기존 항목 사이 적절한 위치):

```
│   ├── resolve-baseline.sh                   # 공유 baseline resolution (base/base_ref/merge_base/degraded)
│   ├── run-test-selection.sh                 # Runtime floor — 러너 어댑터 8종 detect/assign/run (유일 소유자)
│   ├── baseline-cache.sh                     # (merge_base, runner, unit) 내용주소 기준선 캐시 get/put
│   ├── diff-test-results.py                  # 기준선×HEAD 귀속 8종 + 어댑터 간 --aggregate
│   ├── check_qa_ledger.py                    # LD7 floor 5차원 원장 구조 게이트 (Law 1)
```

(c) `## 게이트` 절의 Runtime 게이트 설명을 새 동작으로 갱신하고, `## 설정` 절에
`.claude/quality-gates/baseline-cache/` 의 존재와 `/cancel-qg --all` 로 정리한다는 사실을
한 줄 적는다 (자동 GC 대상이 아님 — 설계 §11 ⑩).

- [ ] **Step 6: 전체 통과 확인**

Run: `bash plugins/quality-gates/tests/test_impact_runtime_docs.sh`
Expected: PASS — `impact runtime docs: 6 passed, 0 failed`

Run: `python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py`
Expected: PASS

Run: `bash plugins/quality-gates/tests/test_readme_scope_reconcile.sh`
Run: `bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh`
Expected: 둘 다 PASS (README 구조 정합)

**전체 스위트 회귀 확인** — Global Constraints 의 기존 red 6종과 대조한다:

```bash
for t in plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh; do
  bash "$t" >/dev/null 2>&1; echo "$? $t"
done | awk '$1 != 0'
for t in plugins/quality-gates/tests/test_*.py; do
  python3 "$t" >/dev/null 2>&1; echo "$? $t"
done | awk '$1 != 0'
```
Expected: bash red 는 **정확히 그 6종**, python red 는 **0개**. 7번째가 나오면 회귀다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/README.md \
        plugins/quality-gates/tests/test_impact_runtime_docs.sh
git commit -m "docs(quality-gates): v3.0.0 — 영향-구동 QA Runtime

major bump: /qg runtime 인터페이스는 유지되지만 '전체 앱을 돌린다'에 의존하던
동작이 사라진다. README에 LD3/LD5/LD7 instantiation 3줄과 신규 스크립트 5종을
등재한다. 버전 테스트는 major digit만 핀하고 patch는 unpin — 리터럴을 핀하면
doc-only bump마다 stale-red가 된다.

AC29 AC30 · T20 T32 T33"
```

---

## 남은 수동 검증 (§8.3)

구현 완료 후 사람이 실행한다. **V1·V4·V6·V8 은 머지 전에 돌리는 것을 권한다** — 나머지는 시계 조작이나 외부 레지스트리가 필요해 시간이 걸린다.

| id | 시나리오 | 왜 수동인가 |
|---|---|---|
| **V1** | devbrew 자신에 `/qg runtime` self-dogfood — 실측상 `unittest`(50개) + `shell`(130개) **두 어댑터가 감지되어 둘 다 실행되는지**, 어느 쪽도 조용히 누락되지 않는지 | 실제 폴리글랏 레포의 전체 파이프라인 동작은 픽스처로 근사만 가능 |
| **V2** | 기준선 캐시 적중 — 같은 브랜치에서 `/qg runtime` 2회, 두 번째가 기준선을 안 돌리는지 | 캐시 수명이 세션을 넘음 |
| **V3** | stale red 위에서의 첫 실행 — 알려진 pre-existing red 6종이 `PRE_EXISTING` 으로 찍히고 FAIL 을 안 만드는지 | 실제 red 목록이 환경 의존 |
| **V4** | 갭 게이트 zero-click — 생략 0인 diff 에서 질문이 안 뜨는지 (**AC20 의 유일한 검증 경로**) | `AskUserQuestion` 발화는 대화형 |
| **V5** | 갭 게이트 발화 — 자동화 불가 플로우가 있는 diff 에서 질문이 뜨고 redirect 가 되는지 | 위와 동일 |
| **V6** | Node 레포에서 기준선 deps 설치 — 실제 비용과 실패율 | 외부 레지스트리 의존 |
| **V7** | `worktrees` 생존 — 실제 `/qg branch` 워크트리를 만들고 TTL 초과 후 GC 를 돌려 생존 확인 | 실제 worktree + 시계 조작 |
| **V8** | 계획 산문의 가독성 — LD4 *"전문용어 나열은 산출물 실패"* 판정 | 사람만 판정 가능 |

**V6 의 결과가 이 설계를 되돌릴 수 있다.** 기준선 deps 설치 실패율이 높으면 `BASELINE_UNRUNNABLE` degrade 가 흔해지고 OQ1 의 답이 실질적으로 기각안 2번(git-귀속 단독)으로 미끄러진다 — 그때는 설계 문서를 다시 연다 (설계 §11 ②).

---

## Self-Review

이 plan 을 설계 문서와 대조한 결과.

**1. Spec coverage — AC57개 전부 task 에 배정됐는가**

| AC | Task | AC | Task | AC | Task |
|---|---|---|---|---|---|
| AC1 | 11·12 | AC20 | 11 (+V4) | AC39 | 4 |
| AC2 | 11·12 | AC21 | 9 | AC40 | 4·5 |
| AC3 | 11 | AC22 | 9 | AC41 | 4·13 |
| AC4 | 1 | AC23 | 11 | AC42 | 5 |
| AC5 | 1 | AC24 | 9 | AC43 | 6 |
| AC6 | 1 | AC25 | 9·13 | AC44 | 11 |
| AC7 | 9 | AC26 | 9 | AC45 | 2 |
| AC8 | 5 | AC27 | 10 | AC46 | 3 |
| AC9 | 4 | AC28 | 10 | AC47 | 4·11 |
| AC10 | 11 | AC29 | 14 | AC48 | 6 |
| AC11 | 6 | AC30 | 14 | AC49 | 11 |
| AC12 | 11 | AC31 | 11·12·13 | AC50 | 4 |
| AC13 | 6 | AC32 | 5 | AC51 | 12 |
| AC14 | 6 | AC33 | 5 | AC52 | 3 |
| AC15 | 6 | AC34 | 2 | AC53 | 3·11 |
| AC16 | 6 | AC35 | 7·11 | AC54 | 2·3 |
| AC17 | 8 | AC36 | 6 | AC55 | 7 |
| AC18 | 8 | AC37 | 1 | AC56 | 2·4 |
| AC19 | 11 | AC38 | 2·11 | AC57 | 11 |

**갭 없음.** T1–T55 도 각 task 의 Files/Steps 에 인용됐고, M1–M26 은 해당 task 의 "mutation 확인" 단계에 배정됐다.

**2. 설계가 요구했으나 plan 이 다르게 처리한 것 — 세 가지 (구현자가 알아야 함)**

| 항목 | 설계 | plan | 왜 |
|---|---|---|---|
| **verdict 결정의 검증 형태** | T10/T11/T12/T26/T40/T51 이 "verdict ≠ PASS" 를 assert | 결정론 산출물(`verdict_input` 플래그·`assign` 행·exit 3)에 대한 기계 assert **+** SKILL.md 산문의 body-unique 락(섹션 윈도우) 두 층 | verdict 는 §5.7 표를 모델이 적용해 정한다. 결정론 리졸버를 새로 만들면 설계에 없는 컴포넌트가 되고 `check_qa_ledger.py` 의 "의미 판정 없음" 계약과 충돌한다. **두 층 락은 이 리포의 기존 관행**(`test_skill_orchestration_behavior.sh`)과 같은 형태다 |
| **`diff-test-results.py` per-adapter 출력에 `verdict_input:` 추가** | 스키마에 `runner`/`attributions`/`attribution_status`/`counts` 만 열거 | `verdict_input:` 3키를 **추가**로 emit | `--aggregate` 가 PyYAML 없이 결정론적으로 읽을 기계 입력이 필요하다. 설계의 aggregate 출력에 이미 같은 키가 있으므로 어휘를 늘리지 않았고, 기존 키는 하나도 안 바뀐다 |
| **`assign` 의 `미실행 러너` 전달 경로** | "`gap` 에 `미실행 러너` 로 열거" | stdout 스키마(`<unit>\t<runner>\t<granularity>`)를 깨지 않기 위해 **stderr loud 줄**로 emit, 오케스트레이터가 `gap` 에 옮김 | 4번째 열이나 특수 행을 만들면 소비자 파서가 갈라진다. stderr 는 CLAUDE.md 의 loud degradation 관행 |

**3. 16칸 총 함수 표 (Task 6)** — 설계 §5.5 는 8개 귀속을 이름으로 열거하고 "총 함수"를 요구하지만 16칸 중 8칸만 명시한다. plan 이 나머지 8칸을 보수적으로(낙관 금지) 채웠고 **새 카테고리를 만들지 않았다**. 이 표는 Task 6 본문에 명시돼 있다.

**4. Type/이름 일관성** — 스크립트 이름·서브커맨드·상태값(`pass|fail|error|unrun|absent`)·귀속 8종·verdict 4종·원장 5차원 키를 task 간 교차 확인했다. `granularity` 값(`file|package|bulk`)과 `mode` 값(`bulk|per-unit`)이 서로 다른 어휘라는 점에 주의 — Task 4 의 `run` 은 `mode` 를 받고 `granularity` 는 러너에서 파생한다.

**5. Placeholder 스캔** — 의도적 플레이스홀더 4개가 남아 있고 전부 **산출 명령과 함께** 제시했다: `DETECT_RUNTIME_SHA256` / `CREATE_SANDBOX_SHA256` / `MUTATION_GUARD_SHA256` (Task 9 Step 2 에 `shasum` 명령), CHANGELOG 의 `<오늘>` (Task 14 Step 4 에 `date -u +%F`). 그 외 "TBD"/"적절히 처리"류 없음.

**6. 취약 mutation 셋 — 구현 순서 주의**

`M6`(재실행 카운트) · `M8`(원장 헤딩 매칭) · `M12`(호출 위치) 는 전부 **"결과가 같아 보이는"** mutation 이라 결과값만 보는 assert 로는 GREEN 이 나온다. 각각 **호출 카운터 + 유한 종료 stub** / **body-unique + 섹션 윈도우** / **호출 위치** 가 필요하고, 해당 task(11 · 8 · 12)의 테스트 단계에서 **구현보다 먼저** 작성하도록 배치했다.

**7. 미검토 표면 — 가장 먼저 검증할 것**

`run-test-selection.sh assign`(Task 3)과 `diff-test-results.py --aggregate`(Task 7)는 설계 라운드 4 수정으로 추가돼 **어떤 리뷰 라운드도 보지 못한 계약**이다. 두 task 의 테스트를 특히 꼼꼼히 읽고, 구현 후 이웃 task 로 넘어가기 전에 리뷰를 받는다.

---

## 병행 가능성

설계 §7의 의존 순서:

```
Task 1 (resolve-baseline)     ─┐
Task 2 (detect)               ─┤ 독립 — 병행 가능
Task 8 (check_qa_ledger)      ─┤
Task 9 (create-baseline)      ─┤
Task 10 (qg-gc)               ─┘

Task 2 → Task 3 (assign) → Task 4 (run) → Task 5 (baseline-cache) → Task 6 (diff) → Task 7 (aggregate)

Task 1~10 전부 → Task 11 (SKILL) → Task 12 (락 이전)
Task 11 → Task 13 (페르소나)
Task 1~13 전부 → Task 14 (문서)
```

subagent-driven 으로 실행한다면 {1, 2, 8, 9, 10} 을 첫 배치로 병행하고, 3→4→5→6→7 은 직렬, 11→12·13, 마지막에 14.
