# spec-distill approve→suppress 대칭화 (v0.15.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** approve된 design 문서가 같은 턴에 review hook을 다시 발동시키는 버그를, 억제(suppress) 경로를 트리거 경로만큼 견고하게 만들어 닫는다.

**Architecture:** 두 결정론 fix + 한 prose stance. (A1) `approve_handoff.sh`가 `suppress_state.py add`를 working-tree 존재검사 *앞에* 수행해 상대경로·서브디렉토리·dangling 어떤 경우에도 suppress가 누락되지 않게 한다(`-f`는 early-exit에서 non-blocking advisory로 강등). (A2) Stop hook `review-dispatch.py`가 `suppressed_paths`를 존중 — pending이 suppressed면 `last_dispatched_at`을 건드리지 않고 strip만 하고 dispatch하지 않는다. (A3) W1(모델이 approve_handoff 자체를 미실행)은 `/spec-distill:cancel-review` escape hatch + Law 3 stance로 다루고, SKILL.md prose를 새 exit 의미로 동기화.

**Tech Stack:** bash (`approve_handoff.sh`), python3 stdlib (`review-dispatch.py`, `suppress_state.py`), bash/python 혼합 테스트 스위트. 새 의존성·새 hook 없음.

---

## Orientation — 구현 전 반드시 읽을 것

이 플러그인을 처음 보는 엔지니어 가정. 핵심 메커니즘:

- **세 hook 파이프라인.** `PostToolUse`(`spec-write-validator.py`)가 `docs/superpowers/specs/` 아래 `*-design.md` write를 감지해 `state.local.md`에 `pending_review:` 블록을 *arm*한다. `Stop` hook(`review-dispatch.py`)이 그 pending을 보고 reviewing-spec를 *dispatch*한다(`{"decision":"block"}` emit). dispatch 시 pending을 strip하고 `last_dispatched_at`을 now로 set(30초 TTL 자기참조 가드).
- **억제(suppress).** approve(`approve_handoff.sh`) 또는 cancel(`cancel_review.py`)이 문서의 canonical key를 `state.local.md`의 `suppressed_paths:` 집합에 기록한다. `PostToolUse`는 이미 arm 직전 `suppress_state.is_suppressed`로 arm-skip한다. **`Stop`은 아직 suppressed_paths를 보지 않는다 — 그게 이 작업의 A2.**
- **정규화 단일 소스.** 경로 정규화(`canonical_key`)·pending strip·suppress add/remove는 전부 `scripts/suppress_state.py`에만 존재한다. 호출자는 raw 경로를 넘기고 위임한다. **`approve_handoff.sh`/`cancel_review.py`는 리터럴 `docs/superpowers/specs/` 문자열을 포함하면 안 된다** (`test_cancel_review.py` AC17이 강제 — 위반 시 RED).
- **canonical_key는 파일 존재가 불필요.** `suppress_state.canonical_key(p)`는 `p`에서 `docs/superpowers/specs/` 이후 substring을 반환할 뿐, 디스크 접근이 없다. 그래서 suppress는 파일이 working-tree에 없어도 기록된다 — A1의 핵심.

**근본 원인(격리 재현으로 확정).** approve 시 `approve_handoff.sh`의 `[[ -f "$spec_path" ]]` 검사가 suppress 기록보다 *먼저* 실행돼, 상대경로+서브디렉토리 cwd(C3)나 dangling 경로에서 `exit 1`로 빠지면 suppress조차 못 남긴다 → 같은 턴 Stop이 재dispatch. (W1 = 모델이 bash 자체 미실행 = A3 stance 영역.)

**Fail-safe 방향(절대 규칙).** A2의 모든 불확실/예외 경로는 **dispatch로 귀결**한다 — 과리뷰가 under-review보다 안전(Law 1 게이트). suppress 체크가 import 실패든 무엇이든 깨지면 정상 리뷰가 일어나야 한다.

**테스트 러너 규약** ([[reference_spec_distill_test_runner]]):
- bash: `bash plugins/spec-distill/tests/<name>.sh` (repo root에서).
- python: tests 디렉토리에서 `python3 -m unittest <module>` — 직접 실행(`python3 test_x.py`)은 vacuous. 모듈명은 하이픈 없는 파일명(예: `test_hook_output_schema`).
- repo root: `/Users/jeonghokim/Downloads/devbrew`.

---

## File Structure

수정 파일 7 + 검증 동기화 4. 새 파일 없음.

| 파일 | 책임 | 변경 |
|---|---|---|
| `plugins/spec-distill/scripts/approve_handoff.sh` | approve finalizer | A1: suppress를 `-f` 앞으로, `-f`→advisory, exit 의미·헤더·최종 메시지 갱신 |
| `plugins/spec-distill/hooks/review-dispatch.py` | Stop dispatch | A2: suppressed_paths 존중 분기 + SCRIPTS_DIR import |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | Phase 5 prose | A3: handoff-sequence 절 + 실패-보존 절 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 메타 | 0.14.0 → 0.15.0 |
| `plugins/spec-distill/CHANGELOG.md` | 변경 이력 | `## [0.15.0]` 블록 |
| `plugins/spec-distill/README.md` | 문서 | Flow(v0.15.0) + Principles(Law 2 대칭) |
| `plugins/spec-distill/tests/test_handoff_spec_path_validation.sh` | missing/dangling 계약 | **AC4a/AC4b를 새 계약으로 전환** (설계 미열거 — plan에서 발견) |
| `plugins/spec-distill/tests/test_review_dispatch.sh` | Stop hook | suppress 케이스 추가 |
| `plugins/spec-distill/tests/test_hook_output_schema.py` | hook 스키마 | suppress import fail-open 단언 |
| `plugins/spec-distill/tests/test_readme_sync.sh` | 버전 동기화 | 0.14.0 → 0.15.0 |

**설계 deviation (의식적, 문서화):**
1. 설계 Files-to-Modify는 `test_approve_handoff.sh`에 "Case 8/9"를 추가하라 했으나, missing-spec 계약은 **`test_handoff_spec_path_validation.sh`가 이미 전담**(AC4a/AC4b)하므로 거기서 새 계약으로 전환한다(DRY — 중복 Case 신설 안 함). AC2(charset/arg→exit 1)는 `test_approve_handoff.sh` Case 5/6이 이미 단언하며 그대로 green 유지가 AC2 가드다.
2. 설계 A1 step ③ "main_repo 해석"은 v0.14.0에서 `rm -rf "$main_repo/..."`가 제거된 뒤 **이미 dead code**다(이번 변경이 만든 게 아님). 최소 diff 원칙으로 *그대로 보존*한다 — 제거는 안전한 future trivia. qg가 dead-code로 flag하면 1줄 follow-up.

---

## Task 1: A1 — `approve_handoff.sh` 순서 역전 (suppress before `-f`)

**Files:**
- Modify: `plugins/spec-distill/tests/test_handoff_spec_path_validation.sh` (AC4a/AC4b 계약 전환 + 헤더)
- Modify: `plugins/spec-distill/scripts/approve_handoff.sh` (전면 재구성)
- Regression-only (no edit): `plugins/spec-distill/tests/test_approve_handoff.sh`, `test_handoff_compact_chain.sh`, `test_cancel_review.py`

- [ ] **Step 1: 실패 테스트 작성 — `test_handoff_spec_path_validation.sh`를 새 계약으로 재작성**

전체 파일을 아래로 교체한다. (기존은 missing/dangling → exit 1을 단언 — A1이 뒤집을 바로 그 계약.)

```bash
#!/usr/bin/env bash
# AC1 (v0.15.0) — approve_handoff.sh: in-scope spec_path가 working-tree에 없어도
# suppress를 기록하고 exit 0 + stale advisory를 낸다. (v0.14.0의 `-f` early-exit
# 순서 버그를 닫음 — suppress가 `-f` 검사 *앞*에서 수행되므로 dangling/absent에도
# 누락되지 않는다.) canonical_key는 파일 존재가 불필요.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

KEY="docs/superpowers/specs/2026-01-01-test-spec.md"

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email t@x.invalid && git config user.name t
    echo "# test" > "$wd/$KEY"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
}

# state에 이 문서의 pending_review 블록을 심는다 — same-key strip 단언용.
seed_pending() {
    local wd=$1 spec=$2
    cat > "$wd/.claude/spec-distill/test-sid12/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: design
  worktree_path: $wd
  triggered_at: 2026-01-01T00:00:00Z
EOF
}

# ── AC1a: spec_path가 한 번도 존재한 적 없음 (working-tree·git 모두 부재) ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
spec_abs="$WORK/docs/superpowers/specs/NONEXISTENT-design.md"
seed_pending "$WORK" "$spec_abs"
bash "$SCRIPT" "test-sid12" "$spec_abs" >/dev/null 2>"$ERR"; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
if [[ $rc -eq 0 ]] \
   && grep -q "\[spec-distill\]" "$ERR" \
   && grep -qi "없음\|stale\|dangling" "$ERR" \
   && grep -q "^suppressed_paths:" "$sf" \
   && grep -q "  - docs/superpowers/specs/NONEXISTENT-design.md" "$sf" \
   && ! grep -qE '^pending_review:' "$sf"; then
    note PASS "AC1a: absent spec_path → exit 0 + suppress 기록 + pending strip + advisory"
else
    note FAIL "AC1a: rc=$rc (expected 0), suppress=$(grep -q '^suppressed_paths:' "$sf" && echo y || echo n), pending_stripped=$(grep -qE '^pending_review:' "$sf" && echo n || echo y)"
fi
rm -rf "$WORK"

# ── AC1b: dangling — git HEAD에 tracked, working-tree에서 제거 ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
spec_abs="$WORK/$KEY"
seed_pending "$WORK" "$spec_abs"
rm -f "$WORK/$KEY"   # tracked-but-removed → dangling
bash "$SCRIPT" "test-sid12" "$spec_abs" >/dev/null 2>"$ERR"; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
sess="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 0 && -d "$sess" ]] \
   && grep -q "\[spec-distill\]" "$ERR" \
   && grep -q "^suppressed_paths:" "$sf" \
   && grep -q "  - $KEY" "$sf" \
   && ! grep -qE '^pending_review:' "$sf"; then
    note PASS "AC1b: dangling (HEAD-tracked, worktree-absent) → exit 0 + suppress + strip + dir 보존"
else
    note FAIL "AC1b: rc=$rc (expected 0), suppress=$(grep -q '^suppressed_paths:' "$sf" && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 2 cases"
```

- [ ] **Step 2: RED 확인**

Run: `bash plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`
Expected: **FAIL** — 현재 스크립트는 missing/dangling에서 `exit 1`로 빠져 AC1a/AC1b 둘 다 실패(rc=1, suppress 미기록).

- [ ] **Step 3: `approve_handoff.sh` 전면 재구성**

전체 파일을 아래로 교체한다. 변경 핵심: kill switch·charset guard 직후 **suppress 기록**, 그 다음 main_repo 해석(보존), 그 다음 `-f` 검사를 **non-blocking advisory**(early-exit 아님)로. exit 1은 charset/arg만. **리터럴 `docs/superpowers/specs/` 문자열 금지(AC17).**

```bash
#!/usr/bin/env bash
# spec-distill v0.15.0 — proceed-gate handoff finalizer.
# 다음-단계 추천은 reviewing-spec Phase 5의 AskUserQuestion proceed 게이트가 담당
# (hook은 AskUserQuestion을 못 띄움; skill은 띄움). 이 스크립트는 순서대로:
#   (1) kill switch + arg/charset guard,
#   (2) approved spec를 suppressed_paths에 기록 + same-key pending strip
#       (suppress_state.py add — canonical_key 기반, 파일 존재 불필요). v0.15.0:
#       이 기록을 working-tree 존재검사 *앞*에 둬서 상대경로·서브디렉토리 cwd·
#       dangling 어떤 경우에도 누락되지 않게 한다(같은-턴 재dispatch 순서 버그 fix).
#   (3) spec_path working-tree 부재 시 NON-BLOCKING stale/dangling advisory (exit 아님),
#   (4) 미커밋/dirty 시 NON-BLOCKING advisory.
# Idempotent by set-membership: 재호출은 키를 최대 1회 추가.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — approved spec suppressed (committed, dirty, OR missing-with-advisory)
#   1 — arg/charset error ONLY (session_id empty/invalid/<8, or missing args)
set -uo pipefail

# ─── Kill switch (CLAUDE.md "kill switch는 보안 컨트롤") ───
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
    echo "[spec-distill] approve_handoff: DEVBREW_DISABLE_SPEC_DISTILL=1 — skip (state preserved)" >&2
    exit 0
fi

# ─── Arg validation ───
session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# ─── session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent) ───
case "$session_id" in
    ''|*[!A-Za-z0-9_-]*)
        echo "[spec-distill] approve_handoff: invalid session_id '${session_id:-<empty>}' — aborting" >&2
        exit 1
        ;;
    *)
        if [[ ${#session_id} -lt 8 ]]; then
            echo "[spec-distill] approve_handoff: session_id length < 8 — aborting" >&2
            exit 1
        fi
        ;;
esac

# ─── Suppress approved doc + strip its same-key pending (v0.15.0, AC1) ───
# MUST precede the working-tree existence check: canonical_key 기반이라 파일이
# 없어도 기록되고, 이 "먼저 기록"이 v0.14.0의 순서 버그(`-f` 조기 exit → suppress
# 누락 → 같은 턴 Stop 재dispatch)를 닫는다. 정규화·strip·add는 suppress_state.py가
# 단일 소스(C4/AC17) — 이 스크립트는 리터럴 specs prefix를 포함하지 않는다.
# 최종 메시지는 suppress 성공 여부에 따라 달라진다(qg codex C1 — 모순 금지).
suppress_cli="$(dirname "$0")/suppress_state.py"
if [[ -f "$suppress_cli" ]]; then
    if python3 "$suppress_cli" add "$session_id" "$spec_path"; then
        suppress_msg="approved spec suppressed for this session."
    else
        suppress_msg="approve recorded; suppression FAILED (advisory above) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능."
        echo "[spec-distill] approve_handoff: suppress 기록 실패 (non-fatal, out-of-scope 경로 등) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능." >&2
    fi
else
    suppress_msg="suppression skipped (suppress_state.py 없음) — 세션 dir는 SessionEnd/GC가 정리."
    echo "[spec-distill] approve_handoff: suppress_state.py 없음 (non-fatal) — 세션 dir는 SessionEnd/GC가 정리." >&2
fi

# ─── Resolve main repo (uses git-common-dir like state_path.py) ───
# NOTE(v0.15.0): v0.14.0에서 `rm -rf "$main_repo/..."`가 제거된 뒤 main_repo는 현재
# 미사용(dead) — 최소 diff로 보존. 제거는 안전한 future trivia.
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"

# ─── spec_path advisory checks (NON-BLOCKING — suppress는 이미 위에서 기록됨) ───
# v0.15.0: `[[ -f ]]`는 early-exit이 아니라 advisory. dangling worktree 경로
# (git HEAD엔 tracked, working-tree엔 부재)는 예전엔 suppress 기록 *전에* exit 1로
# 빠졌다 — 그게 버그. 이제는 사용자에게 stale state만 알린다.
if [[ -f "$spec_path" ]]; then
    # Committed check — ADVISORY only (non-blocking, LD6/AC5). spec은 사용자 소유.
    # 미커밋이어도 차단 안 함 — writing-plans는 working-tree content를 읽음.
    # ls-files: explicit exit-code handling (fail-closed) — corrupt repo / smudge
    # crash가 비-zero+빈 stdout으로 나오면 dirty로 advisory.
    ls_out=$(git ls-files --others --exclude-standard -- "$spec_path" 2>/dev/null); ls_rc=$?
    if ! git diff --quiet -- "$spec_path" 2>/dev/null \
       || ! git diff --quiet --cached -- "$spec_path" 2>/dev/null \
       || [[ $ls_rc -ne 0 || -n "$ls_out" ]]; then
        {
            echo "[spec-distill] approve_handoff: spec '$spec_path' 미커밋/dirty (advisory — 진행은 계속)."
            echo "기록을 위해 commit 권장:"
            echo "  git add -- \"$spec_path\""
            echo "  git commit -m \"spec: \$(basename \"$spec_path\" .md) (locked)\""
        } >&2
    fi
else
    echo "[spec-distill] approve_handoff: spec_path '$spec_path' working-tree에 없음 (advisory — suppress는 기록됨, 진행 계속)." >&2
    echo "[spec-distill] stale/dangling 경로일 수 있음 (예: 삭제된 worktree). reviewing-spec에서 current_spec 재선택 또는 세션 리셋 권장." >&2
fi

echo "spec-distill v0.15.0 handoff finalized (session: $session_id). $suppress_msg 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
```

- [ ] **Step 4: GREEN 확인 (새 계약)**

Run: `bash plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`
Expected: `PASSED: 2 cases`

- [ ] **Step 5: 회귀 확인 (기존 approve 테스트 + chain + AC17)**

Run:
```bash
bash plugins/spec-distill/tests/test_approve_handoff.sh
bash plugins/spec-distill/tests/test_handoff_compact_chain.sh
( cd plugins/spec-distill/tests && python3 -m unittest test_cancel_review -v )
```
Expected: `test_approve_handoff.sh` → `PASSED: 7 cases` (Case 5/6이 AC2=charset/arg→exit 1을 계속 단언). `test_handoff_compact_chain.sh` → `PASSED: chain` (존재하는 spec → exit 0 + suppress, 무변경). `test_cancel_review` → OK (특히 `test_no_prefix_slice_outside_suppress_state` AC17 — approve_handoff.sh에 리터럴 specs prefix 없음).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/scripts/approve_handoff.sh \
        plugins/spec-distill/tests/test_handoff_spec_path_validation.sh
git commit -m "fix(spec-distill): suppress before -f in approve_handoff (order bug)

approve_handoff.sh가 suppress_state add를 working-tree 존재검사 앞에서
수행하도록 순서 역전. dangling/상대경로/서브디렉토리 cwd에서 -f가 먼저
exit 1로 빠져 suppress가 누락되던 같은-턴 재dispatch 버그를 닫는다.
-f는 non-blocking advisory로 강등; exit 1은 charset/arg만.
test_handoff_spec_path_validation.sh AC4a/AC4b를 새 계약으로 전환."
```

---

## Task 2: A2 — `review-dispatch.py`가 `suppressed_paths` 존중

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py` (SCRIPTS_DIR import + suppress 분기)
- Modify: `plugins/spec-distill/tests/test_review_dispatch.sh` (Case 16/17)
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (AC4 import fail-open)

- [ ] **Step 1: 실패 테스트 — `test_review_dispatch.sh`에 Case 16/17 추가**

`echo ""` / `echo "summary..."` 라인(파일 끝 127-129) **직전**에 아래 두 케이스를 삽입한다.

```bash
# Case 16 (AC3/AC3b): pending이 suppressed면 dispatch 안 함 + strip +
# last_dispatched_at 불변 (suppress는 dispatch가 아니므로 TTL 시계를 시작 안 함).
setup_state "test-016" "---
session_id: test-016
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-x-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

last_dispatched_at: 2020-01-01T00:00:00Z

suppressed_paths:
  - docs/superpowers/specs/2026-01-01-x-design.md
"
out=$(run_hook "test-016")
rc=$?
sf16="$WORK/.claude/spec-distill/test-016/state.local.md"
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && ! grep -q '^pending_review:' "$sf16" \
  && grep -q '^suppressed_paths:' "$sf16" \
  && grep -q '^last_dispatched_at: 2020-01-01T00:00:00Z$' "$sf16" \
  && note PASS "AC3/AC3b: suppressed pending → no dispatch + strip + last_dispatched_at 불변" \
  || note FAIL "AC3/AC3b failed (rc=$rc out='$out')"

# Case 17 (AC5): suppressed_paths에 다른 키만 있으면 in-scope pending은 정상 dispatch.
setup_state "test-017" "---
session_id: test-017
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-y-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

suppressed_paths:
  - docs/superpowers/specs/2026-01-01-other-design.md
"
out=$(run_hook "test-017")
rc=$?
sf17="$WORK/.claude/spec-distill/test-017/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf17" \
  && grep -q '^last_dispatched_at:' "$sf17" \
  && note PASS "AC5: non-suppressed in-scope pending → 정상 dispatch (회귀)" \
  || note FAIL "AC5 failed (rc=$rc out='$out')"
```

- [ ] **Step 2: 실패 테스트 — `test_hook_output_schema.py`에 AC4 추가**

`TestReviewDispatchSchema` 클래스(현 line 99) 안, `test_rewrite_failure_suppresses_emit` 메서드 뒤에 아래 메서드를 추가한다. `import suppress_state`를 강제 실패시켜(fail-open) **suppressed 문서인데도 dispatch함**을 단언.

```python
    def test_suppress_import_failure_falls_open_to_dispatch(self):
        """AC4 — `import suppress_state`가 실패하면(예: 모킹) 억제된 문서라도
        Stop hook은 정상 dispatch한다 (fail-safe = 리뷰가 일어나는 쪽)."""
        import importlib.util
        import io
        import contextlib
        spec_module = importlib.util.spec_from_file_location(
            "review_dispatch_ac4", HOOKS_DIR / "review-dispatch.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        repo = _make_temp_repo()
        try:
            session_id = "test-ac4-failopen"
            spec = "docs/superpowers/specs/2026-01-01-x-design.md"
            # 진짜 억제된 state: pending + 매칭되는 suppressed_paths.
            state_dir = repo / ".claude" / "spec-distill" / session_id
            state_dir.mkdir(parents=True, exist_ok=True)
            (state_dir / "state.local.md").write_text(
                f"---\nsession_id: {session_id}\n---\n\n"
                f"pending_review:\n  path: {spec}\n  mode: design\n"
                f"  triggered_at: 2026-01-01T00:00:00Z\n\n"
                f"suppressed_paths:\n  - {spec}\n",
                encoding="utf-8",
            )
            out, err = io.StringIO(), io.StringIO()
            # sys.modules['suppress_state'] = None → `import suppress_state` ImportError.
            with mock.patch.dict(sys.modules, {"suppress_state": None}), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=io.StringIO("{}")), \
                 contextlib.redirect_stdout(out), \
                 contextlib.redirect_stderr(err):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    rc = mod.main()
                finally:
                    os.chdir(cwd_before)
        finally:
            shutil.rmtree(repo, ignore_errors=True)
        self.assertEqual(rc, 0)
        stdout = out.getvalue().strip()
        self.assertTrue(
            stdout, msg="fail-open 시에도 decision:block을 emit해야 함",
        )
        payload = json.loads(stdout)
        self.assertEqual(payload.get("decision"), "block")
        self.assertIn("suppress check failed", err.getvalue())
```

- [ ] **Step 3: RED 확인**

Run:
```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
( cd plugins/spec-distill/tests && python3 -m unittest test_hook_output_schema -v )
```
Expected:
- `test_review_dispatch.sh`: Case 16 **FAIL** (현 hook은 suppressed_paths 무시 → dispatch → `out` 비어있지 않고 `last_dispatched_at`이 now로 바뀜). Case 17 **PASS** (현 hook도 dispatch — 회귀 가드라 pre-impl도 green).
- `test_hook_output_schema`: AC4 **FAIL** (현 hook엔 suppress 코드가 없어 stderr에 "suppress check failed"가 안 나옴).

- [ ] **Step 4: `review-dispatch.py` 구현 — SCRIPTS_DIR import**

현재 (line 33-35):
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402
```
로 교체:
```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402
```
(`spec-write-validator.py:33-36`과 동일 패턴. `suppress_state`는 여기서 import하지 *않는다* — main() try 블록 안에서 deferred import해야 import 실패가 fail-open 된다.)

- [ ] **Step 5: `review-dispatch.py` 구현 — suppress 분기**

현재 (line 126-128):
```python
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # TTL guard against self-ref cycle
```
로 교체 (suppress 체크를 TTL 가드 *앞*에 삽입 — 억제는 TTL과 무관하게 항상 우선):
```python
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # A2 (v0.15.0): honor suppressed_paths — approve/cancel된 문서는 절대 재dispatch
    # 안 함(Law 2 트리거/억제 대칭 복원 — Stop이 이제 두 신호를 모두 읽음). suppressed면
    # stale pending을 strip하되 last_dispatched_at은 건드리지 않는다 — suppress는
    # dispatch가 아니므로 TTL 시계를 시작하면 안 됨(cancel-review --reset 직후 정당한
    # pending이 TTL window 동안 막히는 재발 window 방지). fail-safe 방향은 "리뷰가
    # 일어나는 쪽": 이 블록의 어떤 예외(suppress_state import 실패 포함)도 정상
    # dispatch로 귀결(과리뷰가 under-review보다 안전 — Law 1).
    try:
        import suppress_state  # scripts/ — deferred import so failure fails-open (AC4)
        if suppress_state.is_suppressed(state_path, m.group("path").strip()):
            stripped = suppress_state.strip_pending(body).rstrip() + "\n"
            with open(state_path, "w", encoding="utf-8") as f:
                f.write(stripped)
                f.flush()
                os.fsync(f.fileno())
            return 0  # suppressed → no dispatch, no emit, last_dispatched_at 불변
    except Exception as exc:  # noqa: BLE001 — fail-open to dispatch (Law 1, NEW-001)
        print(
            f"[spec-distill] suppress check failed (non-fatal, dispatching): {exc}",
            file=sys.stderr,
        )
    # TTL guard against self-ref cycle
```

- [ ] **Step 6: GREEN 확인 + 회귀**

Run:
```bash
bash plugins/spec-distill/tests/test_review_dispatch.sh
( cd plugins/spec-distill/tests && python3 -m unittest test_hook_output_schema -v )
```
Expected:
- `test_review_dispatch.sh`: 모든 케이스 PASS (Case 11-15 회귀 포함 — `/tmp/...` pending은 out-of-scope라 `is_suppressed`가 False → 기존대로 dispatch). 마지막 줄 `summary: N passed, 0 failed`.
- `test_hook_output_schema`: AC4 + 기존 전부 PASS. **특히 `test_ast_rewrite_before_print`(AC7.3.1)·`test_mock_trace_rewrite_before_print`(AC7.3.3)이 깨지지 않아야 함** — 추가한 stderr `print`는 except 핸들러 안이고 최종 emit `print`는 여전히 `rewrite_state` 뒤(`min(rewrite_lines) < max(print_lines)` 불변).

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py \
        plugins/spec-distill/tests/test_review_dispatch.sh \
        plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "feat(spec-distill): Stop hook honors suppressed_paths (Law 2 symmetry)

review-dispatch.py가 pending의 path가 현재 세션 suppressed면 dispatch하지
않고 last_dispatched_at을 건드리지 않은 채 strip한다(TTL window 방지).
SCRIPTS_DIR을 sys.path에 추가하고 suppress_state를 main() try 블록 안에서
deferred import — import 포함 모든 suppress-체크 예외는 fail-open(정상
dispatch). 트리거/억제 두 신호를 모두 읽는 권위 레이어로 Stop을 복원."
```

---

## Task 3: A3 prose + 메타데이터 동기화 (0.14.0 → 0.15.0)

**Files:**
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (기대값 bump)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

- [ ] **Step 1: 실패 테스트 — `test_readme_sync.sh` 기대값 0.15.0으로**

`test_readme_sync.sh`에서 아래 3개 치환:
- line 13: `'"version": "0.14.0"'` → `'"version": "0.15.0"'`, 메시지 `0.14.0` → `0.15.0`.
- line 15: `'^## \[0\.14\.0\] — 2026-[0-9]{2}-[0-9]{2}$'` → `'^## \[0\.15\.0\] — 2026-[0-9]{2}-[0-9]{2}$'`, 메시지 동일 bump.
- line 17: `'^## \[0\.14\.0\].*XX'` → `'^## \[0\.15\.0\].*XX'`.

(line 2 주석 `v0.14.0` → `v0.15.0`은 cosmetic, 같이 갱신. line 20 키워드 리스트는 그대로 — 전부 README에 잔존.)

- [ ] **Step 2: RED 확인**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: **FAIL** — plugin.json은 아직 0.14.0, CHANGELOG에 [0.15.0] 없음.

- [ ] **Step 3: `plugin.json` bump**

`"version": "0.14.0"` → `"version": "0.15.0"`.

- [ ] **Step 4: `CHANGELOG.md` — `## [0.15.0]` 블록을 `# Changelog` 다음(line 1과 현 line 3 `## [0.14.0]` 사이)에 삽입**

```markdown
## [0.15.0] — 2026-06-15

### Fixed
- `scripts/approve_handoff.sh` — **같은-턴 재dispatch 순서 버그**: `suppress_state.py add`(approved 키 기록 + same-key pending strip)를 working-tree 존재검사(`[[ -f ]]`) *앞으로* 이동. 기존엔 dangling/상대경로/서브디렉토리 cwd에서 `-f`가 먼저 `exit 1`로 빠져 suppress가 누락 → approve해도 같은 턴에 Stop hook이 재dispatch했다. canonical_key 기반 suppress는 파일 존재가 불필요하므로 이제 무조건 기록된다. (AC1)

### Changed
- `scripts/approve_handoff.sh` — `[[ -f ]]` 존재검사를 early-exit에서 **non-blocking advisory**로 강등. `exit 1`은 이제 **session_id charset/arg 검증 실패에 한정**(AC2). in-scope spec_path가 working-tree에 없어도 suppress 기록 + `exit 0` + stale advisory. 헤더 주석·최종 메시지를 v0.15.0 동작으로 갱신.
- `hooks/review-dispatch.py` (Stop) — pending의 path가 현재 세션 `suppressed_paths`에 있으면 **dispatch하지 않고** stale pending을 `suppress_state.strip_pending`으로 제거한다. **`last_dispatched_at`은 건드리지 않음**(TTL window 방지 — `cancel-review --reset` 직후 정당한 pending이 막히지 않도록, AC3b). `SCRIPTS_DIR`를 sys.path에 추가하고 `import suppress_state`를 `main()` try 블록 안에서 deferred 수행 — import 포함 모든 suppress-체크 예외는 fail-open(정상 dispatch, 과리뷰가 under-review보다 안전). Law 2 트리거/억제 대칭 복원. (AC3/AC4/AC5)
- `skills/reviewing-spec/SKILL.md` — "Approve handoff sequence" + "실패 시 state 보존" 절을 새 순서·exit 의미로 동기화.
- `tests/test_handoff_spec_path_validation.sh` — AC4a/AC4b를 새 계약(missing/dangling in-scope → `exit 0` + suppress 기록 + pending strip + advisory + dir 보존)으로 전환. `tests/test_review_dispatch.sh` — suppressed→no-dispatch+strip+TTL불변 / non-suppressed→dispatch 케이스 추가. `tests/test_hook_output_schema.py` — suppress import 실패 fail-open 단언 추가. `tests/test_readme_sync.sh` — 버전 0.14.0 → 0.15.0.
- `README.md` — Flow(v0.15.0) + Principles(Law 2 트리거/억제 대칭) 동기화.

### Notes
- W1(모델이 approve_handoff 자체를 미실행)은 구조적으로 막을 수단(PostToolUse가 AskUserQuestion approve를 감지)이 공식 문서상 보장되지 않아 제외 — `/spec-distill:cancel-review` escape hatch + (재발 증명 시) Law 3 persona/skill 편집이 stance.
```

- [ ] **Step 5: `README.md` 동기화 (3곳)**

(a) line 23 `## Flow (v0.14.0)` → `## Flow (v0.15.0)`.

(b) line 45 (`**v0.14.0**: per-doc·session-scoped ...`) **다음 줄**에 추가:
```markdown
**v0.15.0**: approve→suppress 대칭화 — `approve_handoff.sh`가 suppress를 working-tree 존재검사 *앞에* 기록(순서 버그 fix) + Stop hook(`review-dispatch.py`)이 `suppressed_paths`를 존중해 승인/취소된 문서를 재dispatch하지 않음(트리거/억제 대칭).
```

(c) line 60 (AP2 bullet). 현재 끝부분:
> `approve_handoff.sh`(v0.14.0)는 spec_path 존재 검증 + approved 문서를 `suppressed_paths`에 기록(same-key pending strip 포함)하는 finalizer — 세션 dir 삭제는 SessionEnd/TTL-GC로 이관(더 이상 rm 기반 stateless cleanup 아님).

를 아래로 교체:
> `approve_handoff.sh`(v0.15.0)는 approved 문서를 `suppressed_paths`에 기록(same-key pending strip 포함)하는 finalizer로, suppression을 working-tree 존재검사 *앞*에 수행해 dangling/상대경로 경우에도 누락되지 않게 한다. 대칭으로 Stop hook(`review-dispatch.py`)이 `suppressed_paths`를 존중 — 트리거(강제)와 억제(approve/cancel)가 모두 hook 권위 레이어에 존재(Law 2 대칭). 세션 dir 삭제는 SessionEnd/TTL-GC로 이관.

- [ ] **Step 6: `SKILL.md` 동기화 (2 블록)**

(a) "Approve handoff sequence" 절 (현 line 115). 전체 문단을 아래로 교체:
```markdown
스크립트(v0.15.0+)가 thin finalizer로 동작: (1) kill switch + charset guard, (2) **approved spec를 `suppressed_paths`에 기록 + 같은-키 pending strip** (`suppress_state.py add` — canonical_key 기반, 파일 존재 불필요; 가장 먼저 수행돼 상대경로·서브디렉토리 cwd·dangling 경로 어떤 경우에도 기록 보장), (3) spec_path working-tree 존재 검증을 **non-blocking advisory로** (부재 시 stale/dangling 안내; suppress는 이미 (2)에서 기록됨, exit 0), (4) 미커밋 spec advisory (non-blocking, exit 0). 세션 dir는 더 이상 여기서 삭제하지 않음 — SessionEnd hook / TTL-GC가 정리(승인 기억을 세션 동안 보존). 다음-단계 추천은 proceed 게이트가 담당. idempotent by set-membership(재호출은 키를 최대 1회 추가). (v0.15.0: (2)↔(3) 순서 역전이 같은-턴 재dispatch 순서 버그를 닫음.)
```

(b) "실패 시 state 보존 (P14)" 절 (현 line 121). 전체 문단을 아래로 교체:
```markdown
approve_handoff.sh의 exit 1은 **session_id charset/arg 검증 실패에 한정**한다(v0.15.0). spec_path가 in-scope(`docs/superpowers/specs/` prefix)이면 working-tree 부재여도 suppress를 기록하고 exit 0 + stale advisory를 낸다 — 부재는 더 이상 abort가 아니다(Step A 통과 후 race로 사라진 경우 포함). 에이전트는 스크립트 stderr advisory를 그대로 노출한다. suppress 기록 실패(out-of-scope 경로 등)는 advisory only (non-fatal) — 사용자가 `/spec-distill:cancel-review`로 수동 억제 가능, 세션 dir 정리는 SessionEnd/TTL-GC. git commit 실패 경로는 존재하지 않음 (스크립트가 commit 시도 안 함; 미커밋은 advisory).
```

- [ ] **Step 7: GREEN + prose 자기 점검**

Run:
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh
grep -c "v0.15.0" plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -n "exit 1은 \*\*session_id charset" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```
Expected: `test_readme_sync.sh` → 모든 PASS. SKILL.md에 `v0.15.0` ≥ 2회 등장. exit-code 서술 갱신 라인 존재.

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md \
        plugins/spec-distill/skills/reviewing-spec/SKILL.md \
        plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "docs(spec-distill): sync prose + metadata to v0.15.0 approve-suppress symmetry

SKILL.md handoff-sequence/실패-보존 절을 새 exit 의미로, README Flow +
Law 2 대칭 한 줄, CHANGELOG [0.15.0], plugin.json bump, readme-sync 기대값."
```

---

## Task 4: 전체 회귀 + 격리 재현(AC6) + qg 게이트

코드 변경 없음 — 검증만. (qg가 fix를 요구하면 해당 Task로 회귀.)

- [ ] **Step 1: 전체 spec-distill 스위트**

Run (repo root):
```bash
# bash 스위트
for t in plugins/spec-distill/tests/test_*.sh; do echo "=== $t ==="; bash "$t" || echo "!!! FAIL: $t"; done
# python 스위트 (tests 디렉토리에서 -m unittest)
( cd plugins/spec-distill/tests && python3 -m unittest test_hook_output_schema test_cancel_review test_gc test_session_end_cleanup -v )
```
Expected: 모든 bash 스위트 PASS, python 4 모듈 OK. ([[reference_spec_distill_test_runner]]: 워크트리에선 NG9 cross-resolver 테스트 1개가 환경 의존 pre-existing red일 수 있음 — 본 작업과 무관, baseline 대비 신규 red 0이 기준.)

- [ ] **Step 2: 격리 재현 하니스 재실행 (AC6 런타임)**

Run: `bash /Users/jeonghokim/.claude/jobs/a88fd0de/tmp/repro.sh`
Expected: **C3(상대경로+서브디렉토리)이 이제 `no fire`** (A1 fix 후 suppress가 기록됨). C1/C2 여전히 `no fire`. **C4(W1, approve_handoff 미실행)는 여전히 `FIRES`** — 정상(A3 stance대로 escape hatch가 정답이지 A1/A2가 막는 대상 아님). 이 결과가 design §Context 4-조건 표가 의도대로 바뀌었음을 확인.

- [ ] **Step 3: qg review 게이트**

`/qg` (또는 `/qg review`)로 spec-conformance 리뷰 — 기준은 design의 AC1–AC7/AC3b. codex 모델-다양성 포함(보안/fail-open은 codex 독립 리뷰가 강함, [[project_qg_detector_simplification]]). qg가 REAL 버그를 잡으면 TDD로 수정 후 재게이트.

- [ ] **Step 4: AC ↔ 구현 매핑 자기 점검**

| AC | 충족 위치 |
|---|---|
| AC1 (missing in-scope → suppress+strip+exit0) | Task1: `test_handoff_spec_path_validation.sh` AC1a/AC1b |
| AC2 (charset/arg만 exit 1) | Task1: `test_approve_handoff.sh` Case 5/6 (회귀 green) |
| AC3 (suppressed → no dispatch + strip) | Task2: `test_review_dispatch.sh` Case 16 |
| AC3b (last_dispatched_at 불변) | Task2: Case 16의 `2020-01-01` 불변 단언 |
| AC4 (suppress 체크 예외 → dispatch) | Task2: `test_hook_output_schema.py` AC4 |
| AC5 (non-suppressed → dispatch) | Task2: Case 17 + 기존 Case 11/13 |
| AC6 (런타임 4-조건) | Task4 Step 2: repro.sh |
| AC7 (기존 스위트 회귀 0) | Task4 Step 1 |

---

## Self-Review (작성자 점검 결과)

- **Spec coverage:** Goals G1(C3 결정론 제거)=Task1, G2(Stop 대칭)=Task2, G3(W1 stance+prose)=Task3 A3. Non-goals NG1(새 hook 없음)/NG2(강제경로 불변)/NG3(state 위치 불변)/NG4(라우팅 불변) — 본 plan은 기존 3 스크립트 + prose만 건드려 전부 준수.
- **설계 미열거 파일 발견:** `test_handoff_spec_path_validation.sh`가 구 계약(exit 1) 단언 → A1로 깨짐. plan이 Task1에서 명시적 전환. (design Files-to-Modify 갭, plan-time 보강.)
- **AC17 제약:** `approve_handoff.sh`는 리터럴 `docs/superpowers/specs/`를 포함하지 않음 — advisory가 `$spec_path` 변수만 사용. Task1 Step5가 `test_cancel_review` AC17로 검증.
- **AST 순서 불변:** Task2의 추가 stderr print는 except 핸들러 내부이며 최종 emit print는 여전히 `rewrite_state` 뒤 → `test_ast_rewrite_before_print`/`test_mock_trace_rewrite_before_print` 불변. Task2 Step6에서 명시 확인.
- **TDD-RED 정직성:** Case 16·AC4·AC1a/b는 pre-impl RED. Case 17은 회귀 가드(green-stays-green) — vacuous 아님, AC5 보호용. AC4는 stderr 로그 단언으로 pre-impl RED 보장.
- **Placeholder 스캔:** TBD/TODO 없음. 모든 step에 실제 코드/명령/기대출력.
- **커밋 분리:** 테스트와 구현을 **같은 커밋**으로 묶음(TDD RED는 로컬에서만, CI 깨는 test-only 커밋 금지 — design Verification 주석).
```

