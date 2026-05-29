# spec-distill Handoff Proceed-Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill의 marker 기반 Stop-hook `/compact` induction을 제거하고, /compact 추천을 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 옮기며, dangling `spec_path` 핸드오프 예외를 `-f` working-tree 가드로 봉쇄한다.

**Architecture:** `approve_handoff.sh`를 thin finalizer(spec_path 존재 검증 + 세션 cleanup)로 축소하고, `compact-induction.py`/`compact-detect.py` hook + `.markers/` 메커니즘 + named-status 상수를 삭제한다. 다음-단계 추천은 hook(텍스트 주입만 가능)이 아니라 skill이 띄우는 interactive 게이트가 담당한다 (AP2 approval-gate 구분 §철학 line 413).

**Tech Stack:** bash (POSIX + git), Python 3 (hooks/GC, stdlib only), markdown skill/docs. 테스트는 bash assertion 스크립트 + Python `unittest`.

**Spec:** `docs/superpowers/specs/2026-05-29-spec-distill-handoff-proceed-gate-design.md` (4-round adversarial review, approved).

**Branch:** `feature/spec-distill-proceed-gate` (이미 생성됨, design doc 2 commits).

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `plugins/spec-distill/scripts/approve_handoff.sh` | 핸드오프 finalizer: spec_path 존재 검증 + cleanup | **rewrite** (marker/packet/named-status 제거, `-f` 가드 추가) |
| `plugins/spec-distill/hooks/compact-induction.py` | (구) Stop hook /compact induction | **delete** |
| `plugins/spec-distill/hooks/compact-detect.py` | (구) UserPromptSubmit marker 삭제 | **delete** |
| `plugins/spec-distill/hooks/hooks.json` | hook 등록 | **edit** (compact-* 2개 항목 제거) |
| `plugins/spec-distill/scripts/spec-distill-gc.py` | 세션 dir TTL-GC | **edit** (`_sweep_markers` 제거) |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | review phase + handoff | **edit** (Phase 5 proceed 게이트) |
| `plugins/spec-distill/tests/test_handoff_spec_path_validation.sh` | AC4a/AC4b 회귀 | **create** |
| `plugins/spec-distill/tests/test_approve_handoff.sh` | approve_handoff 계약 | **rewrite** |
| `plugins/spec-distill/tests/test_handoff_compact_chain.sh` | 핸드오프 end-to-end | **rewrite** |
| `plugins/spec-distill/tests/test_gc.py` | GC | **edit** (marker 케이스 13~16 + `_make_marker` 삭제) |
| `plugins/spec-distill/tests/test_compact_induction_hook.sh` 외 4개 | 구 mechanism 테스트 | **delete** |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 메타 | **edit** (0.11.0) |
| `plugins/spec-distill/CHANGELOG.md` | 변경 이력 | **edit** ([0.11.0]) |
| `plugins/spec-distill/README.md` | 문서 | **edit** (Hooks 표 −2, kill switch −2, Principles) |
| `CLAUDE.md` | devbrew root | **edit** (Polite handoff 항목) |
| `MEMORY 파일` | compounding | **edit** (전환 기록) |

---

## Task 1: approve_handoff.sh thin finalizer + 검증 테스트

**Files:**
- Rewrite: `plugins/spec-distill/scripts/approve_handoff.sh`
- Create: `plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`
- Rewrite: `plugins/spec-distill/tests/test_approve_handoff.sh`
- Delete: `plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh`, `plugins/spec-distill/tests/test_handoff_status_named.sh`

- [ ] **Step 1: Write the new spec_path validation test (AC4a/AC4b)**

Create `plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`:

```bash
#!/usr/bin/env bash
# AC4a/AC4b — approve_handoff.sh spec_path working-tree existence guard (v0.11.0).
# AC4b reproduces the dangling-worktree bug: file tracked in git HEAD but removed
# from the working tree. Without the `-f` guard the test FAILS (git rev-parse
# HEAD succeeds), so this test is the guard's regression detector.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ERR="$TMP/err"

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email t@x.invalid && git config user.name t
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo state > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}

# ── AC4a: spec_path never existed (absent in working tree AND git) ──
WORK=$(mktemp -d); setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/NONEXISTENT.md" >/dev/null 2>"$ERR"; rc=$?
sess_dir="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 1 ]] && grep -q "\[spec-distill\]" "$ERR" && grep -qi "not found\|부재" "$ERR" && [[ -d "$sess_dir" ]]; then
    note PASS "AC4a: absent spec_path → exit 1 + advisory + session dir preserved"
else
    note FAIL "AC4a: rc=$rc, advisory=$(grep -qi 'not found\|부재' "$ERR" && echo y || echo n), sess_preserved=$([[ -d $sess_dir ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ── AC4b: dangling worktree — tracked in git HEAD, removed from working tree ──
WORK=$(mktemp -d); setup_repo "$WORK"
# spec is committed (in HEAD); now delete the working-tree copy → dangling.
rm -f "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>"$ERR"; rc=$?
sess_dir="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 1 ]] && grep -q "\[spec-distill\]" "$ERR" && [[ -d "$sess_dir" ]]; then
    note PASS "AC4b: dangling (HEAD-tracked, worktree-absent) → exit 1 + session dir preserved"
else
    note FAIL "AC4b: rc=$rc (expected 1 — guard missing?), sess_preserved=$([[ -d $sess_dir ]] && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 2 cases"
```

- [ ] **Step 2: Rewrite test_approve_handoff.sh to the v0.11.0 contract**

Replace the entire contents of `plugins/spec-distill/tests/test_approve_handoff.sh`:

```bash
#!/usr/bin/env bash
# approve_handoff.sh thin-finalizer contract (v0.11.0): no marker, no packet,
# no named-status. AC3 (clean → exit 0, no marker), AC5 (dirty → exit 0 + advisory),
# AC3 idempotency (clean re-call), AC6 (cleanup happened), AC7 (kill switch).
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

TMPDIR_TESTRUN=$(mktemp -d); trap 'rm -rf "$TMPDIR_TESTRUN"' EXIT
OUT="$TMPDIR_TESTRUN/out"; ERR="$TMPDIR_TESTRUN/err"

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email test@x.invalid && git config user.name test
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo state > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}
markers_dir() { echo "$1/.claude/spec-distill/.markers"; }

# ── Case 1 (AC3): clean HEAD spec → exit 0, NO marker dir, NO packet text ──
WORK=$(mktemp -d); setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"; rc=$?
md=$(markers_dir "$WORK")
if [[ $rc -eq 0 && ! -d "$md" ]] && ! grep -q "handoff packet" "$OUT" && ! grep -q "STATUS=" "$OUT" "$ERR"; then
    note PASS "case 1 (AC3): clean → exit 0, no marker dir, no packet"
else
    note FAIL "case 1: rc=$rc, no_marker_dir=$([[ ! -d $md ]] && echo y || echo n), no_packet=$(grep -q 'handoff packet' "$OUT" && echo n || echo y)"
fi
rm -rf "$WORK"

# ── Case 2 (AC5 FLIP): dirty spec → exit 0 + non-blocking advisory ──
WORK=$(mktemp -d); setup_repo "$WORK"
echo "uncommitted mod" >> "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"; rc=$?
ok=1
grep -q "\[spec-distill\]" "$ERR" || ok=0
grep -q "git add -- " "$ERR" || ok=0
grep -q "git commit -m " "$ERR" || ok=0
if [[ $rc -eq 0 && "$ok" -eq 1 ]]; then
    note PASS "case 2 (AC5): dirty → exit 0 + advisory (non-blocking)"
else
    note FAIL "case 2: rc=$rc (expected 0), advisory_ok=$ok"
fi
rm -rf "$WORK"

# ── Case 3 (AC3 idempotency): clean re-call → exit 0 again, still no marker ──
WORK=$(mktemp -d); setup_repo "$WORK"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1
# re-create session dir (first call cleaned it up) to confirm second call also exits 0
mkdir -p "$WORK/.claude/spec-distill/test-sid12"; echo state > "$WORK/.claude/spec-distill/test-sid12/state.local.md"
bash "$SCRIPT" "test-sid12" "$spec" >"$OUT" 2>&1; rc=$?
md=$(markers_dir "$WORK")
if [[ $rc -eq 0 && ! -d "$md" ]]; then
    note PASS "case 3 (AC3): clean re-call → exit 0, stateless idempotent"
else
    note FAIL "case 3: rc=$rc, no_marker_dir=$([[ ! -d $md ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ── Case 4 (AC6): session dir present before → removed after approve ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
[[ -d "$sess" ]] || note FAIL "case 4 setup: session dir missing pre-call"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && ! -d "$sess" ]]; then
    note PASS "case 4 (AC6): session dir cleaned up after approve"
else
    note FAIL "case 4: rc=$rc, sess_gone=$([[ ! -d $sess ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ── Case 5: charset reject → exit 1 ──
WORK=$(mktemp -d); setup_repo "$WORK"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>"$ERR"; rc=$?
[[ $rc -ne 0 ]] && grep -q "aborting" "$ERR" \
    && note PASS "case 5: charset reject → exit 1" \
    || note FAIL "case 5: rc=$rc"
rm -rf "$WORK"

# ── Case 6: empty args → exit 1 ──
bash "$SCRIPT" "" "anything" >/dev/null 2>&1; [[ $? -ne 0 ]] && note PASS "case 6a: empty sid rejected" || note FAIL "case 6a"
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1; [[ $? -ne 0 ]] && note PASS "case 6b: empty path rejected" || note FAIL "case 6b"

# ── Case 7 (AC7): kill switch → exit 0, session dir PRESERVED (no side effects) ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && -d "$sess" ]]; then
    note PASS "case 7 (AC7): kill switch → exit 0, session dir preserved"
else
    note FAIL "case 7: rc=$rc, sess_preserved=$([[ -d $sess ]] && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 7 cases"
```

- [ ] **Step 3: Delete the obsolete approve_handoff tests**

```bash
git rm plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh \
       plugins/spec-distill/tests/test_handoff_status_named.sh
```
(packet emit + named-status 기능이 제거되므로 검증 대상 부재 — AC16/AC18.)

- [ ] **Step 4: Run the new tests to verify they FAIL against the current script**

Run: `bash plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`
Expected: FAIL on AC4b (current script has no `-f` guard; `git rev-parse HEAD` succeeds → proceeds).

Run: `bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: FAIL on case 1/2/3 (current script writes marker, dirty→exit 1, emits packet).

- [ ] **Step 5: Rewrite approve_handoff.sh as the v0.11.0 thin finalizer**

Replace the entire contents of `plugins/spec-distill/scripts/approve_handoff.sh`:

```bash
#!/usr/bin/env bash
# spec-distill v0.11.0 — proceed-gate handoff finalizer.
# No marker, no packet, no named-status: the next-step recommendation now lives
# in reviewing-spec Phase 5's AskUserQuestion proceed gate (a hook cannot raise
# an AskUserQuestion; the skill can). This script only:
#   (1) validates spec_path exists in the working tree (LD4 — fixes dangling-path bug),
#   (2) emits a NON-BLOCKING advisory if the spec is uncommitted/dirty (LD6/AC5),
#   (3) cleans up the per-session state directory (AC6).
# Idempotent by statelessness: re-running on a clean tree / already-removed
# session dir is a no-op.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — spec exists (committed or dirty-with-advisory); session dir cleaned
#   1 — spec_path missing from working tree, or arg/charset error (no cleanup)
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

# ─── spec_path working-tree existence guard (LD4 — MUST precede ALL git queries) ───
# `git rev-parse HEAD -- "$spec_path"` succeeds whenever HEAD exists, regardless
# of whether spec_path is present on disk. A dangling worktree path (tracked in
# git HEAD but removed from the working tree) would otherwise slip through and
# the handoff would run against a non-existent file. The -f guard closes that
# exact bug (spec-reviewer g7b4d2a9). No cleanup on this path — stale judgement
# is deferred to reviewing-spec (state preserved).
if [[ ! -f "$spec_path" ]]; then
    echo "[spec-distill] approve_handoff: spec_path '$spec_path' not found in working tree — no handoff, session state preserved." >&2
    echo "[spec-distill] stale/dangling 경로일 수 있음 (예: 삭제된 worktree). reviewing-spec에서 current_spec 재선택 또는 세션 리셋 필요." >&2
    exit 1
fi

# ─── Resolve main repo (uses git-common-dir like state_path.py) ───
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"

# ─── Committed check — ADVISORY only (non-blocking, LD6/AC5) ───
# spec은 사용자 소유 (2026-05-27 LD4 계승). 미커밋이어도 차단하지 않음 —
# writing-plans는 working-tree content를 읽으므로 미커밋 spec도 안전.
if ! git diff --quiet -- "$spec_path" 2>/dev/null \
   || ! git diff --quiet --cached -- "$spec_path" 2>/dev/null \
   || [[ -n "$(git ls-files --others --exclude-standard -- "$spec_path" 2>/dev/null)" ]]; then
    {
        echo "[spec-distill] approve_handoff: spec '$spec_path' 미커밋/dirty (advisory — 진행은 계속)."
        echo "기록을 위해 commit 권장:"
        echo "  git add -- \"$spec_path\""
        echo "  git commit -m \"spec: \$(basename \"$spec_path\" .md) (locked)\""
    } >&2
fi

# ─── Session directory cleanup (AC6) ───
rm -rf -- "$main_repo/.claude/spec-distill/$session_id/" 2>/dev/null || \
    echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2

echo "spec-distill v0.11.0 handoff finalized (session: $session_id). 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
```

- [ ] **Step 6: Run all approve_handoff tests to verify they PASS**

Run: `bash plugins/spec-distill/tests/test_handoff_spec_path_validation.sh`
Expected: `PASSED: 2 cases`

Run: `bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: `PASSED: 7 cases`

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/scripts/approve_handoff.sh \
        plugins/spec-distill/tests/test_handoff_spec_path_validation.sh \
        plugins/spec-distill/tests/test_approve_handoff.sh
git rm --cached --ignore-unmatch plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh plugins/spec-distill/tests/test_handoff_status_named.sh 2>/dev/null || true
git commit -m "fix(spec-distill): approve_handoff thin finalizer + spec_path -f guard

marker/packet/named-status 제거. spec_path working-tree 존재 가드를 git 조회
이전에 추가 — dangling worktree 경로 예외 봉쇄(AC4a/AC4b). dirty spec은
advisory+exit 0으로 flip(AC5). 세션 cleanup 유지(AC6).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: compact-induction + compact-detect hook 제거

**Files:**
- Delete: `plugins/spec-distill/hooks/compact-induction.py`, `plugins/spec-distill/hooks/compact-detect.py`
- Delete: `plugins/spec-distill/tests/test_compact_induction_hook.sh`, `plugins/spec-distill/tests/test_compact_induction_stagnation.sh`, `plugins/spec-distill/tests/test_compact_detect_hook.sh`
- Edit: `plugins/spec-distill/hooks/hooks.json`
- Rewrite: `plugins/spec-distill/tests/test_handoff_compact_chain.sh`

- [ ] **Step 1: Rewrite test_handoff_compact_chain.sh to the v0.11.0 contract (no marker/induction)**

Replace the entire contents of `plugins/spec-distill/tests/test_handoff_compact_chain.sh`:

```bash
#!/usr/bin/env bash
# V9 — handoff end-to-end (v0.11.0): approve → spec_path validated → session
# cleaned, with NO marker, NO induction hook, NO detect hook. Confirms the
# proceed-gate contract leaves no marker artifact behind.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVE="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# ── Removed hooks must not exist ──
for h in compact-induction.py compact-detect.py; do
    [[ ! -e "$PLUGIN_DIR/hooks/$h" ]] \
        && note PASS "hook removed: $h" \
        || note FAIL "hook still present: $h"
done

WORK=$(mktemp -d)
SID="chainsid12abc"
SPEC_REL="docs/superpowers/specs/2026-01-01-test-spec.md"
mkdir -p "$WORK/docs/superpowers/specs"; cd "$WORK"
git init -q && git config user.email t@x.invalid && git config user.name t
echo "# spec" > "$SPEC_REL"
mkdir -p "$WORK/.claude/spec-distill/$SID"; echo state > "$WORK/.claude/spec-distill/$SID/state.local.md"
git add . && git commit -q -m "init spec"

# ── Step 1: approve_handoff → exit 0, NO marker dir created, session dir gone ──
bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/tmp/chain_out_$$ 2>&1; rc=$?
md="$WORK/.claude/spec-distill/.markers"
sess="$WORK/.claude/spec-distill/$SID"
if [[ $rc -eq 0 && ! -d "$md" && ! -d "$sess" ]]; then
    note PASS "chain: approve → exit 0, no marker dir, session cleaned"
else
    note FAIL "chain: rc=$rc, no_marker=$([[ ! -d $md ]] && echo y || echo n), sess_gone=$([[ ! -d $sess ]] && echo y || echo n) (out: $(cat /tmp/chain_out_$$))"
fi

# ── Step 2: stdout carries NO legacy packet / marker tokens ──
if ! grep -qE "handoff packet|STATUS=|FIRE_COUNT=|HANDOFF_STATUS_|\.markers/" /tmp/chain_out_$$; then
    note PASS "chain: no legacy packet/marker tokens in output"
else
    note FAIL "chain: legacy tokens leaked: $(cat /tmp/chain_out_$$)"
fi

# ── Step 3 (kill switch): DEVBREW_DISABLE → exit 0, no marker, session preserved ──
mkdir -p "$sess"; echo state > "$sess/state.local.md"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && ! -d "$md" && -d "$sess" ]]; then
    note PASS "chain: kill switch → exit 0, no marker, session preserved"
else
    note FAIL "chain: kill switch rc=$rc, sess_preserved=$([[ -d $sess ]] && echo y || echo n)"
fi

rm -rf "$WORK" /tmp/chain_out_$$

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail step(s)"; exit 1; fi
echo "PASSED: chain"
```

- [ ] **Step 2: Edit hooks.json — remove the two compact-* entries**

In `plugins/spec-distill/hooks/hooks.json`, update the top-level `description` and remove the compact-induction (Stop) + compact-detect (UserPromptSubmit) hook objects.

Change `description` from:
```json
  "description": "spec-distill — UserPromptSubmit reminder/compact-detect, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer-dispatch + compact-induction, SessionEnd cleanup.",
```
to:
```json
  "description": "spec-distill — UserPromptSubmit reminder, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer-dispatch, SessionEnd cleanup.",
```

In the `UserPromptSubmit` array, remove the second hook object (compact-detect.py), leaving only pending-review-reminder.py:
```json
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pending-review-reminder.py",
            "timeout": 5
          }
        ]
      }
    ],
```

In the `Stop` array, remove the second hook object (compact-induction.py), leaving only review-dispatch.py:
```json
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/review-dispatch.py",
            "timeout": 10
          }
        ]
      }
    ],
```

- [ ] **Step 3: Delete the two hook files + their three tests**

```bash
git rm plugins/spec-distill/hooks/compact-induction.py \
       plugins/spec-distill/hooks/compact-detect.py \
       plugins/spec-distill/tests/test_compact_induction_hook.sh \
       plugins/spec-distill/tests/test_compact_induction_stagnation.sh \
       plugins/spec-distill/tests/test_compact_detect_hook.sh
```

- [ ] **Step 4: Verify hooks.json is valid JSON and chain test passes**

Run: `python3 -c "import json,sys; json.load(open('plugins/spec-distill/hooks/hooks.json'))" && echo "JSON OK"`
Expected: `JSON OK`

Run: `python3 -c "import json; d=json.load(open('plugins/spec-distill/hooks/hooks.json')); print('compact-induction' in json.dumps(d), 'compact-detect' in json.dumps(d))"`
Expected: `False False`

Run: `bash plugins/spec-distill/tests/test_handoff_compact_chain.sh`
Expected: `PASSED: chain`

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json plugins/spec-distill/tests/test_handoff_compact_chain.sh
git commit -m "feat(spec-distill)!: remove compact-induction + compact-detect hooks

marker 기반 Stop-hook /compact induction + UserPromptSubmit detect 폐기.
hooks.json에서 두 항목 제거(Stop=review-dispatch만, UserPromptSubmit=reminder만).
chain 테스트를 marker/induction 없는 v0.11.0 계약으로 재작성.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: GC `_sweep_markers` dead code 제거

**Files:**
- Edit: `plugins/spec-distill/scripts/spec-distill-gc.py`
- Edit: `plugins/spec-distill/tests/test_gc.py`

- [ ] **Step 1: Delete the marker GC test cases from test_gc.py**

In `plugins/spec-distill/tests/test_gc.py`, delete the entire `# ─── v0.10.0 _sweep_markers tests ───` block: the `_make_marker` helper (around line 125) and `test_13_marker_ttl_reached`, `test_14_marker_ttl_not_reached`, `test_15_marker_dir_missing`, `test_16_non_emitted_file_preserved` (lines ~123–160). The non-marker cases test_1–test_12 remain unchanged.

- [ ] **Step 2: Run test_gc.py to confirm it still imports (will fail at import if `_sweep_markers` referenced)**

Run: `python3 -m pytest plugins/spec-distill/tests/test_gc.py -q` (or `python3 plugins/spec-distill/tests/test_gc.py` if unittest-runnable)
Expected: tests 1–12 PASS (marker tests gone).

- [ ] **Step 3: Remove `_sweep_markers` function + its call site from spec-distill-gc.py**

In `plugins/spec-distill/scripts/spec-distill-gc.py`:

Delete the entire `_sweep_markers` function (lines 103–135, from `def _sweep_markers(root: Path, ttl_ns: int) -> int:` through its closing `return removed`).

Remove its call in `gc()` — change:
```python
            removed += _sweep_gc_pending(root)
            removed += _sweep_markers(root, ttl_ns)
            for child in root.iterdir():
```
to:
```python
            removed += _sweep_gc_pending(root)
            for child in root.iterdir():
```

- [ ] **Step 4: Verify no `_sweep_markers` / `.markers` references remain in GC**

Run: `grep -c "_sweep_markers\|\.markers" plugins/spec-distill/scripts/spec-distill-gc.py`
Expected: `0`

Run: `python3 -m pytest plugins/spec-distill/tests/test_gc.py -q`
Expected: all remaining cases PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/spec-distill-gc.py plugins/spec-distill/tests/test_gc.py
git commit -m "refactor(spec-distill): drop _sweep_markers from GC (markers removed)

marker가 더는 생성되지 않으므로 .markers/ TTL sweep dead code 제거 + test_13~16 삭제.
marker GC coverage 포기는 의도적(AC18).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: reviewing-spec Phase 5 proceed 게이트

**Files:**
- Edit: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (replace "Phase 5 Human Gate" + "Approve handoff sequence" + "실패 시 state 보존" sections, ~lines 121–144)

- [ ] **Step 1: Replace the Phase 5 + Approve handoff sections in SKILL.md**

In `plugins/spec-distill/skills/reviewing-spec/SKILL.md`, replace from `## Phase 5 Human Gate` through the end of the `### 실패 시 state 보존 (P14)` subsection with:

````markdown
## Phase 5 Human Gate — proceed 게이트

### Step A — spec_path 선검증 (AC9, 게이트 *이전* 필수)

`current_spec`(= spec_path)이 working-tree에 존재하는지 먼저 확인. 부재 시(예: 삭제된 worktree 경로) **proceed 게이트를 띄우지 말고** loud advisory + 사용자에게 재선택/리셋 요청, handoff 진행 금지:

> `[spec-distill] current_spec '<path>' 부재 (working-tree에 없음) — stale state. current_spec 재선택 또는 세션 리셋 필요. handoff 진행 안 함.`

### Step B — 단일 `AskUserQuestion` proceed 게이트 (AC8)

spec_path 유효 시, reviewer 결과를 표시하고 **한 번의** `AskUserQuestion`으로 다음 단계를 제안 (approve 후 별도 2차 질문 없음):

```javascript
AskUserQuestion({
  questions: [{
    question: "spec '<path>' review: <verdict 요약>. 다음 단계?",
    header: "Proceed",
    options: [
      {label: "/compact 후 writing-plans (권장)", description: "approve_handoff(검증+cleanup) 후 verbatim /compact 명령 노출 → 사용자 /compact 실행 시 writing-plans. 긴 인터뷰 context 정리 이점."},
      {label: "바로 writing-plans", description: "approve_handoff 후 즉시 Skill superpowers:writing-plans <path> 호출 (compact 없이)."},
      {label: "수정 필요", description: "approve 아님 — 후속 질문으로 revise per review / more interview / edit myself 분기."},
      {label: "멈춤 (나중에)", description: "state 보존하고 종료."}
    ],
    multiSelect: false
  }]
})
```

### Step C — 응답 처리

- **① /compact 후 writing-plans**: Approve handoff sequence 실행 → 사용자에게 verbatim `/compact` 명령을 *그대로 보이게* 노출 + "compact 후 writing-plans 진입 준비됨" 안내 → **여기서 턴을 종료(STOP). 같은 턴에서 `writing-plans`를 호출하지 말 것** (compact 전 writing-plans 진입 = 옵션 ① 무력화). `Skill superpowers:writing-plans <path>` 진입은 사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write plan`처럼 compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동 진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17). compact된 fresh context에서 plan 작성 (AC19).
- **② 바로 writing-plans**: Approve handoff sequence 실행 → 즉시 `Skill superpowers:writing-plans <path>` 호출.
- **③ 수정 필요**: 후속 `AskUserQuestion`으로 분기 — "revise per review" → drafting-spec Mode B (spec mode) / 메인 agent design.md 직접 수정 (design mode); "more interview" → conducting-interview (state phase=1 reset, interview_round 유지); "edit spec myself" → 사용자 편집 후 reviewing-spec 재진입.
- **④ 멈춤**: state 보존, 종료.

### polite stop 금지 (AP2 — verifiable, AC11)

approve(①/②) 선택 후 "approved!"만 narrate하고 Approve handoff sequence 호출/다음 phase 진입을 skip하는 것은 **polite stop**. Phase 5를 *종료*하는 모든 경로는 (a) 위 proceed 게이트 제시를 거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외 경로(Step A spec_path 부재, kill switch)는 명시적 advisory 단락을 동반해야 한다 — 게이트-less silent 종료 금지. (게이트는 사용자가 redirect 가능한 approval gate이므로 P17 주권에 기여하며 polite-stop이 아니다 — 철학 §AP2.)

### cross-compact 조기 진행 금지 (AC19 — polite stop의 *반대* 실패 모드, verifiable)

옵션 ① 선택 시 `/compact`를 노출한 *직후* 같은 턴에서 `writing-plans`로 직진하는 것은 금지. compact가 무거운 plan-write *뒤에* 오면 context 위생 이점이 사라져 옵션 ①이 무의미해진다 (2026-05-29 본 design 세션에서 실측된 실패: "handoff"라 말하고 compact 전에 plan을 그대로 써버림). 다음 턴 진입은 *사용자 트리거*(예: `/compact write plan` 인자)로만 일어나며 모델 자동 진입이 아니다(NG4·P17). polite stop이 "진행해야 할 때 멈춤"이라면 이것은 "멈춰야 할 때 진행" — 두 방향 모두 게이트의 사용자-주권(P17)을 우회한다. **verifiable (두-레이어, AC11 선례)**: (i) `grep -cE "턴 종료|다음 턴"` ≥ 1, **AND** (ii) 옵션 ① 서술 *블록 안에서* 'turn-ending(STOP)' + 'writing-plans 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거'가 *함께* 명시됐음을 리뷰에서 확인 (grep 단독 false-positive — '턴 종료' 문구와 '같은 턴 호출' 문구 공존 — 차단은 리뷰 레이어 담당; mechanical 한계는 AC11과 동일 수준 인정). 옵션 ②는 이 정지 요건의 *명시적 예외*(compact 없이 즉시 writing-plans). **AC8 경계** (round-2 advisory 반영): AC8 '추가 AskUserQuestion 없음'은 *approve 옵션이 최종 확정된 그 어시스턴트 응답 턴*에 한정한다 (Phase 5 내 revise/interview 루프의 다른 턴이 아님 — 그 턴들은 본래 질문을 띄움). 다음 턴에 진입한 writing-plans가 자체 실행-방식 선택 게이트를 띄우는 것은 별개 skill scope이므로 AC8 해당 없음.

## Approve handoff sequence (①/② 공통)

approve(①/②) 시:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/approve_handoff.sh" "$session_id" "$spec_path"
```

스크립트(v0.11.0+)가 thin finalizer로 동작: (1) kill switch + charset guard, (2) **spec_path working-tree 존재 검증** (`[[ -f ]]`, 모든 git 조회 이전 — 부재 시 exit 1 + advisory + cleanup 미수행, state 보존), (3) 미커밋 spec advisory (non-blocking, exit 0), (4) 세션 디렉토리 cleanup. **marker/packet/named-status 없음** — 다음-단계 추천은 proceed 게이트가 담당. idempotent by statelessness(재호출은 clean tree에서 no-op).

**polite stop 금지** (AP2): approve인데 스크립트 호출/게이트를 skip하고 narrate만 하지 말 것. SessionEnd hook이 backup cleanup이나 user-explicit approve 의도는 즉시 반영.

### 실패 시 state 보존 (P14)

approve_handoff.sh가 spec_path 부재로 exit 1 시 + state.local.md 보존 + 세션 cleanup 미수행 (사용자 재선택 대기). cleanup rm 실패는 advisory only — SessionEnd hook이 재시도. git commit 실패 경로는 존재하지 않음 (스크립트가 commit 시도 안 함; 미커밋은 advisory).
````

- [ ] **Step 2: Verify no stale marker/induction references + verifiable AC11 tokens**

Run: `grep -c "compact-induction\|compact-detect\|\.markers\|marker\|packet\|HANDOFF_STATUS\|already_handed_off\|dirty_blocked" plugins/spec-distill/skills/reviewing-spec/SKILL.md`
Expected: `0`

Run: `grep -c "AskUserQuestion" plugins/spec-distill/skills/reviewing-spec/SKILL.md` → ≥ 1 (Phase 5 gate; the [3.5] re-consensus gate already uses it).
Run: `grep -ci "polite" plugins/spec-distill/skills/reviewing-spec/SKILL.md` → ≥ 1.
Run: `grep -cE "턴 종료|다음 턴" plugins/spec-distill/skills/reviewing-spec/SKILL.md` → ≥ 1 (AC19 (i) — mechanical layer).
**리뷰 레이어 (AC19 (ii), round-2 advisory)**: 옵션 ① 서술 *블록 안에서* 'turn-ending(STOP)' + 'writing-plans 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거' 3요소가 *함께* 있는지 육안 확인 (grep 단독은 공존 보장 불가 — false-positive 차단은 이 레이어가 담당).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): Phase 5 AskUserQuestion proceed gate

marker/packet induction 의존 제거. 단일 게이트(① /compact 후 writing-plans 권장 /
② 바로 writing-plans / ③ 수정 / ④ 멈춤)로 다음 단계 제안. spec_path 선검증 추가.
polite-stop(AP2) 금지 verifiable 기준 명문화.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 메타 + 문서 (plugin.json, CHANGELOG, README, CLAUDE.md)

**Files:**
- Edit: `plugins/spec-distill/.claude-plugin/plugin.json`
- Edit: `plugins/spec-distill/CHANGELOG.md`
- Edit: `plugins/spec-distill/README.md`
- Edit: `CLAUDE.md`

- [ ] **Step 1: Bump plugin.json version**

In `plugins/spec-distill/.claude-plugin/plugin.json`, change `"version": "0.10.0"` to `"version": "0.11.0"`.

- [ ] **Step 2: Prepend the [0.11.0] CHANGELOG entry**

In `plugins/spec-distill/CHANGELOG.md`, insert after the `# Changelog` header (before `## [0.10.0]`):

```markdown
## [0.11.0] — 2026-05-29

### Removed
- `hooks/compact-induction.py` — marker 기반 Stop-hook `/compact` 재주입 폐기. /compact 추천은 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 이동 (hook은 AskUserQuestion을 띄울 수 없음).
- `hooks/compact-detect.py` — marker 삭제용 UserPromptSubmit hook. marker 부재로 무의미.
- `.claude/spec-distill/.markers/` marker 메커니즘 전체 + `approve_handoff.sh`의 named-status 상수(`HANDOFF_STATUS_*`)·packet emit·`dirty_blocked` exit-1.
- `scripts/spec-distill-gc.py`의 `_sweep_markers` — marker 미생성으로 sweep 대상 부재. **marker GC coverage 포기는 의도적.**
- 테스트: `test_compact_induction_hook.sh`, `test_compact_induction_stagnation.sh`, `test_compact_detect_hook.sh`, `test_handoff_approve_packet_emit.sh`, `test_handoff_status_named.sh`, `test_gc.py`의 marker 케이스(test_13~16).

### Changed
- `skills/reviewing-spec/SKILL.md` Phase 5 — 단일 `AskUserQuestion` proceed 게이트(① /compact 후 writing-plans 권장 / ② 바로 writing-plans / ③ 수정 / ④ 멈춤)로 재구성. approve 후 2차 질문 없음. polite-stop(AP2) 금지 verifiable 기준 명문화.
- `scripts/approve_handoff.sh` — thin finalizer로 축소: spec_path working-tree 존재 검증 + 세션 cleanup. 미커밋 검사는 advisory(non-blocking).

### Fixed
- dangling `spec_path` 핸드오프 예외 — `[[ -f "$spec_path" ]]` working-tree 가드를 모든 git 조회 *이전*에 수행. 삭제된 worktree 경로(git HEAD tracked but working-tree absent)가 `git rev-parse HEAD` 성공으로 통과하던 결함 봉쇄.

### Added
- `tests/test_handoff_spec_path_validation.sh` — AC4a(부재) + AC4b(dangling worktree) 회귀.

### Security
- 없음 (persona/reviewer 약화 없음 — review-dispatch / pending-review-reminder hook은 그대로).

```

- [ ] **Step 3: Edit README.md — remove the two hook rows + two kill-switch lines + update Principle**

In `plugins/spec-distill/README.md`:

(a) Delete the `Stop (2)` row (compact-induction.py, line ~106) and the `UserPromptSubmit (2)` row (compact-detect.py, line ~107) from the "Hooks Installed" table.

(b) Delete the two kill-switch bullets (lines ~129–130):
```
- `DEVBREW_SKIP_HOOKS=spec-distill:compact-induction` (v0.10.0) — Stop hook compact-induction.py만 skip. review-dispatch.py는 정상.
- `DEVBREW_SKIP_HOOKS=spec-distill:compact-detect` (v0.10.0) — UserPromptSubmit hook compact-detect.py만 skip. pending-review-reminder.py는 정상.
```

(c) Replace the Principle bullet (line ~55) — change the Ouroboros named-status/marker text:
```markdown
- **Law 3 (Compounding) + Ouroboros instantiation (v0.10.0)** — `scripts/approve_handoff.sh`가 Ouroboros `handoff_contract.py` 패턴을 차용: named-status 3개 상수 (`HANDOFF_STATUS_*`), replay-safety (재호출 시 TIMESTAMP 보존), dedupe invariant (marker 존재 = 이미 처리됨). 미래 search가 "handoff invariant"로 두 instantiation을 같이 찾도록 README + CHANGELOG에 명시.
```
to:
```markdown
- **AP2 approval-gate 구분 (v0.11.0)** — handoff 다음-단계 추천을 hook(텍스트 주입만 가능)이 아니라 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 전달. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 polite-stop 봉쇄 장치 (철학 §AP2 line 413). `approve_handoff.sh`는 spec_path 존재 검증 + 세션 cleanup만 수행하는 stateless finalizer.
```

- [ ] **Step 4: Edit CLAUDE.md — Polite handoff Forbidden Pattern**

In `CLAUDE.md`, replace line ~92:
```markdown
- **Polite handoff** — brainstorming/spec-distill review-approved 후 `/compact` 안내만 narrate하고 spec-distill 의 `approve_handoff.sh`를 호출하지 않음. 호출하면 marker가 생성되고 Stop hook이 unmissable하게 `/compact`를 induce하므로 narrate-only는 polite-stop의 한 종류 (AP2 variant).
```
with:
```markdown
- **Polite handoff** — brainstorming/spec-distill review-approved 후 다음 단계를 narrate만 하고 spec-distill reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트를 띄우지 않음. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 봉쇄 장치 — 게이트를 skip한 narrate-only 종료가 polite-stop의 한 종류 (AP2 variant). (v0.11.0 이전엔 marker + Stop-hook induction이 이 역할을 했으나, hook은 AskUserQuestion을 띄울 수 없어 게이트로 전환.)
```

- [ ] **Step 5: Verify version, JSON, and token absence**

Run: `python3 -c "import json; print(json.load(open('plugins/spec-distill/.claude-plugin/plugin.json'))['version'])"`
Expected: `0.11.0`

Run: `head -3 plugins/spec-distill/CHANGELOG.md` → shows `## [0.11.0] — 2026-05-29`.

Run: `grep -c "compact-induction\|compact-detect" plugins/spec-distill/README.md`
Expected: `0`

Run: `grep -c "marker가 생성\|unmissable하게" CLAUDE.md`
Expected: `0`

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md CLAUDE.md
git commit -m "docs(spec-distill): v0.11.0 — CHANGELOG, README, CLAUDE.md, version bump

plugin.json 0.10.0→0.11.0. Hooks 표 −2 + kill switch −2. Principle을
AP2 approval-gate 구분으로 갱신. CLAUDE.md Polite handoff 항목을 게이트 기준으로.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: full suite 회귀 + memory compounding

**Files:**
- Memory: `project_spec_distill_review_hardening.md` (auto-memory) + `MEMORY.md` 인덱스 한 줄

- [ ] **Step 1: Run the full spec-distill test suite**

Run every test in `plugins/spec-distill/tests/`:
```bash
for t in plugins/spec-distill/tests/test_*.sh; do echo "=== $t ==="; bash "$t" || echo "!!! FAIL: $t"; done
python3 -m pytest plugins/spec-distill/tests/test_gc.py plugins/spec-distill/tests/test_session_end_cleanup.py -q
```
Expected: 모든 테스트 PASS. 특히 범위에서 제외된 5개(`test_handoff_kill_switch.sh`, `test_handoff_context_section_required.sh`, `test_handoff_context_empty_subsections.sh`, `test_handoff_design_mode.sh`, `test_handoff_conversation_reference.sh`)는 **unchanged green** (spec-reviewer persona 검증, marker 무관 — V9).

- [ ] **Step 2: Confirm no orphan references repo-wide**

Run: `grep -rn "compact-induction\|compact-detect\|_sweep_markers" plugins/spec-distill/ --include='*.py' --include='*.sh' --include='*.json' --include='*.md' | grep -v CHANGELOG`
Expected: 빈 출력 (CHANGELOG의 Removed 항목만 historical 참조로 허용).

- [ ] **Step 3: Update the project memory (Law 3 compounding)**

Update `project_spec_distill_review_hardening.md` in the auto-memory dir — append the v0.11.0 transition:

> v0.11.0(#TBD-PR): marker-induction(compact-induction/compact-detect/.markers/) 제거 → reviewing-spec Phase 5 `AskUserQuestion` proceed 게이트로 전환. 근거: hook은 AskUserQuestion을 띄울 수 없음 + dangling spec_path 예외. 핵심: AP2 방어가 hook 인프라 → skill의 approval gate로 이동(철학 §AP2 line 413 approval-gate ≠ polite-stop). approve_handoff.sh는 spec_path `-f` 존재 가드(git 조회 이전) + 세션 cleanup만 하는 stateless finalizer. **원칙 갱신**: "훅 가치=marker-induction(unmissable)"은 더 이상 아님 — unmissable은 이제 사용자 응답을 강제하는 AskUserQuestion 게이트.

(파일이 없으면 메모리 frontmatter 규칙대로 생성하고 `MEMORY.md` 인덱스에 한 줄 추가. PR 번호는 PR 생성 후 채움.)

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore(spec-distill): v0.11.0 memory compounding + suite green

전체 테스트 suite PASS 확인. project_spec_distill_review_hardening 메모리에
marker-induction → proceed-gate 전환 기록 (Law 3).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (AC1–AC19 → task):**
- AC1 (hook 파일/등록 부재) → Task 2; AC2 (review-dispatch/reminder 잔존) → Task 2 Step 4.
- AC3 (clean→exit0 no marker, idempotency) → Task 1 Case 1/3; AC4a/AC4b (spec_path 부재/dangling) → Task 1 spec_path_validation; AC5 (dirty→exit0 advisory) → Task 1 Case 2; AC6 (cleanup) → Task 1 Case 4; AC7 (kill switch) → Task 1 Case 7.
- AC8 (proceed 게이트 4옵션) / AC9 (spec_path 선검증) / AC10 (marker 참조 제거) / AC11 (polite-stop verifiable) / **AC19 (cross-compact 조기 진행 금지 — 옵션 ① 턴 경계 정지)** → Task 4 (Step C 옵션 ① + cross-compact 금지 subsection + Step 2 grep 검증).
- AC12 (`_sweep_markers` 제거) → Task 3.
- AC13 (0.11.0 + CHANGELOG) / AC14 (README hooks/kill switch) / AC15 (CLAUDE.md) / AC17 (README kill switch 토큰 부재) → Task 5.
- AC16 (테스트 삭제/재작성) → Task 1 Step 3 + Task 2 Step 3 + Task 4; AC18 (test_gc marker 케이스 삭제) → Task 3.
- 모든 AC에 대응 task 존재. gap 없음.

**2. Placeholder scan:** Task 6 Step 3의 "#TBD-PR"는 PR 번호 — PR 생성 후 채우는 의도적 deferral(코드 placeholder 아님). 그 외 TBD/TODO 없음. 모든 코드 step에 full 코드 블록 존재.

**3. Type/name consistency:** `approve_handoff.sh` 인자 순서 `<session_id> <spec_path>` 전 task 일관. 마커 경로 `.claude/spec-distill/.markers/<sid>.emitted` — Task 1/2 테스트에서 *부재* 단언으로만 등장(일관). `DEVBREW_DISABLE_SPEC_DISTILL` kill switch 이름 일관. Phase 5 옵션 ①~④ 라벨 Task 4 ↔ CHANGELOG(Task 5) 일치.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-29-spec-distill-handoff-proceed-gate.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — 각 task마다 fresh subagent dispatch, task 사이 two-stage 리뷰, 빠른 iteration.

**2. Inline Execution** — 이 세션에서 executing-plans로 batch 실행 + checkpoint 리뷰.

**Which approach?**
