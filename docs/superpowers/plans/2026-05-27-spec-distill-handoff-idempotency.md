# spec-distill handoff idempotency + compact induction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill v0.10.0 — `approve_handoff.sh`를 idempotent state machine으로 재설계해서 (a) 이미 commit된 spec 재진입을 정상 처리하고, (b) handoff packet emit 이후 사용자가 `/compact`를 실행할 때까지 Stop hook이 unmissable SystemMessage로 유도한다.

**Architecture:** Ouroboros `handoff_contract.py` 패턴 instantiation — named-status 상수, replay-safety, dedupe invariant. `approve_handoff.sh`는 git commit 책임을 버리고 working-tree-clean + HEAD-에-spec-있음 *조건* 검증으로 한정. 신규 marker 파일(`.claude/spec-distill/.markers/<sid>.emitted`)이 Stop hook과 UserPromptSubmit hook 사이의 coordinator. Stop hook은 marker 감지 → systemMessage로 `/compact` induce. UserPromptSubmit hook은 `/compact` 또는 `Skill superpowers:writing-plans` 입력 감지 → marker 삭제. 5회 fire 후 self-cleanup으로 무한 fire 차단.

**Tech Stack:** Bash (approve_handoff.sh), Python 3 (hooks, hooks pattern 기존 `pending-review-reminder.py`/`review-dispatch.py` 따름), shell test harness (bash), JSON I/O (Claude Code hook protocol).

**Spec:** `docs/superpowers/specs/2026-05-27-spec-distill-handoff-idempotency-design.md`

**Plugin namespace:** 모든 변경은 `plugins/spec-distill/` 하위 + devbrew root `CLAUDE.md` 한 줄 — spec C1.

**Plan-time advisory notes (round-3 review에서 흡수, non-blocking):**
1. **(Task 4)** UserPromptSubmit hook payload schema는 Claude Code 문서에 명시되어 있지만 본 plan은 실측 우선 — `compact-detect.py` 구현 첫 step에서 payload를 stderr dump해서 `user_message` 필드명 실측 확인 후 dump 코드 제거.
2. **(Task 11)** V6 kill switch verification에서 AC8 경로(`DEVBREW_SKIP_HOOKS=spec-distill:compact-induction`)는 compact-induction.py만 no-op시키므로, compact-detect.py 정상 동작은 V4 (`test_compact_detect_hook.sh`)가 이미 cover. plan task에 한 줄 audit trail comment 추가.

---

## File Structure

생성/수정 파일 책임 매핑:

```
plugins/spec-distill/
├── .claude-plugin/plugin.json          [MODIFY] version 0.9.0 → 0.10.0
├── CHANGELOG.md                        [MODIFY] [0.10.0] entry
├── README.md                           [MODIFY] Hooks Installed + Principles Instantiated
├── hooks/
│   ├── hooks.json                      [MODIFY] Stop/UserPromptSubmit에 신규 hook 등록
│   ├── compact-induction.py            [NEW]    Stop hook — marker 감지 → /compact induce
│   └── compact-detect.py               [NEW]    UserPromptSubmit hook — /compact 감지 → marker 삭제
├── scripts/
│   ├── approve_handoff.sh              [MODIFY] commit 제거, named-status, idempotent
│   └── spec-distill-gc.py              [MODIFY] .markers/ sweep 한 줄 추가
├── skills/reviewing-spec/SKILL.md      [MODIFY] approve handoff 절 갱신 (4-step → 신규)
└── tests/
    ├── test_approve_handoff.sh         [MODIFY] Case 1/5/7 재작성, AC1/AC2/AC3 의미
    ├── test_handoff_status_named.sh    [NEW]    named-status 상수 invariant
    ├── test_compact_induction_hook.sh  [NEW]    Stop hook 동작
    ├── test_compact_detect_hook.sh     [NEW]    UserPromptSubmit hook 동작
    ├── test_compact_induction_stagnation.sh [NEW] 5회 fire self-cleanup
    └── test_handoff_compact_chain.sh   [NEW]    end-to-end JSON contract chain

CLAUDE.md (devbrew root)               [MODIFY] brainstorming → spec-distill handoff 한 줄
```

---

## Phase 1: approve_handoff.sh idempotent refactor (core)

### Task 1: Named-status invariant test (RED)

**Files:**
- Create: `plugins/spec-distill/tests/test_handoff_status_named.sh`

이 test가 먼저 RED 상태여야 한다 — `approve_handoff.sh`에 `readonly HANDOFF_STATUS_*` 상수가 아직 없기 때문.

- [ ] **Step 1: Write the test file**

```bash
#!/usr/bin/env bash
# AC1/AC3 — named-status invariant: approve_handoff.sh exports 3 named status constants.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# Invariant 1: 3 named status constants declared as readonly.
for name in HANDOFF_STATUS_ALREADY_DONE HANDOFF_STATUS_DIRTY_BLOCKED HANDOFF_STATUS_EMITTED; do
    if grep -Eq "^readonly[[:space:]]+${name}=" "$SCRIPT"; then
        note PASS "constant $name declared readonly"
    else
        note FAIL "constant $name missing or not readonly"
    fi
done

# Invariant 2: Status values are named strings (not numeric, not empty).
# Pull the RHS value of each readonly declaration and ensure it's a non-empty quoted string.
for name in HANDOFF_STATUS_ALREADY_DONE HANDOFF_STATUS_DIRTY_BLOCKED HANDOFF_STATUS_EMITTED; do
    value=$(grep -E "^readonly[[:space:]]+${name}=" "$SCRIPT" | sed -E "s/^readonly[[:space:]]+${name}=//; s/^['\"]//; s/['\"]$//")
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
        note PASS "constant $name has named value '$value'"
    else
        note FAIL "constant $name value '$value' is empty or numeric"
    fi
done

# Invariant 3: STATUS= line in .handoff-status uses one of the named constants.
# Search for the literal HANDOFF_STATUS_* variable expansion in marker write logic.
if grep -Eq 'STATUS=\$\{?HANDOFF_STATUS_' "$SCRIPT"; then
    note PASS "marker write uses named status variable expansion"
else
    note FAIL "marker write does not use named status constant"
fi

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail invariant(s)"
    exit 1
fi
echo "PASSED: 7 invariants"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/spec-distill/tests/test_handoff_status_named.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_handoff_status_named.sh`
Expected: FAIL with "constant HANDOFF_STATUS_ALREADY_DONE missing or not readonly" (그리고 다른 invariant들도 FAIL).

- [ ] **Step 4: Commit (test-only commit)**

```bash
git add plugins/spec-distill/tests/test_handoff_status_named.sh
git commit -m "test(spec-distill): add named-status invariant for approve_handoff.sh"
```

---

### Task 2: Refactor approve_handoff.sh — remove commit, add named-status state machine, write marker

**Files:**
- Modify: `plugins/spec-distill/scripts/approve_handoff.sh` (현재 64 라인 전체 재작성)

기존 v0.9.0의 `git add` + `git commit` 단계를 완전히 제거하고, 3-status state machine + marker write로 교체한다.

- [ ] **Step 1: Rewrite approve_handoff.sh**

전체 파일을 다음 내용으로 교체:

```bash
#!/usr/bin/env bash
# spec-distill v0.10.0 — idempotent handoff state machine.
# Removes git commit responsibility (LD4): spec is user-owned.
# Writes named-status marker (LD3 Ouroboros instantiation) for compact-induction
# Stop hook to detect handoff-pending state.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — handoff packet emitted (status: emitted | already_done)
#   1 — dirty_blocked (uncommitted/dirty spec) or arg error
set -uo pipefail

# ─── Named-status constants (Ouroboros handoff_contract.py pattern) ───
readonly HANDOFF_STATUS_ALREADY_DONE="already_handed_off"
readonly HANDOFF_STATUS_DIRTY_BLOCKED="dirty_blocked"
readonly HANDOFF_STATUS_EMITTED="emitted"

# ─── Kill switch (CLAUDE.md "kill switch는 보안 컨트롤") ───
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
    echo "[spec-distill] approve_handoff: DEVBREW_DISABLE_SPEC_DISTILL=1 — skip (state preserved)" >&2
    exit 0
fi

# ─── Arg validation ───
session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# ─── session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent) ───
cleanup_skipped=0
case "$session_id" in
    ''|*[!A-Za-z0-9_-]*)
        echo "[spec-distill] approve_handoff: cleanup skipped — invalid session_id '${session_id:-<empty>}'" >&2
        cleanup_skipped=1
        ;;
    *)
        if [[ ${#session_id} -lt 8 ]]; then
            echo "[spec-distill] approve_handoff: cleanup skipped — session_id length < 8" >&2
            cleanup_skipped=1
        fi
        ;;
esac

# ─── Resolve marker directory (uses git-common-dir like state_path.py) ───
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"
markers_dir="$main_repo/.claude/spec-distill/.markers"
marker_file="$markers_dir/${session_id}.emitted"

# ─── State machine: determine current handoff status ───
# Priority: existing marker → already_done. Else: check working tree.
if [[ -f "$marker_file" ]]; then
    current_status="$HANDOFF_STATUS_ALREADY_DONE"
else
    # No marker yet — check spec is in HEAD and working tree is clean.
    if ! git rev-parse HEAD -- "$spec_path" >/dev/null 2>&1; then
        # spec_path not tracked yet
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    elif ! git diff --quiet -- "$spec_path" 2>/dev/null; then
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    elif ! git diff --quiet --cached -- "$spec_path" 2>/dev/null; then
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    elif [[ -n "$(git ls-files --others --exclude-standard -- "$spec_path" 2>/dev/null)" ]]; then
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    else
        current_status="$HANDOFF_STATUS_EMITTED"
    fi
fi

# ─── Branch: dirty_blocked → loud advisory + exit 1 (AC2) ───
if [[ "$current_status" == "$HANDOFF_STATUS_DIRTY_BLOCKED" ]]; then
    short_status=$(git status --short -- "$spec_path" 2>/dev/null || echo "??  $spec_path")
    {
        echo "[spec-distill] approve_handoff: $HANDOFF_STATUS_DIRTY_BLOCKED — spec working tree not clean."
        echo "git status --short -- \"$spec_path\":"
        echo "$short_status"
        echo
        echo "사용자 수동 commit 필요. 다음 명령 copy-paste:"
        echo "  git add -- \"$spec_path\""
        echo "  git commit -m \"spec: \$(basename \"$spec_path\" .md) (locked)\""
        echo
        echo "commit 후 approve_handoff.sh 재호출."
    } >&2
    exit 1
fi

# ─── Marker write (emitted path only — already_done preserves existing) ───
mkdir -p "$markers_dir"
if [[ "$current_status" == "$HANDOFF_STATUS_EMITTED" ]]; then
    # First emit — write fresh marker.
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$marker_file" <<MARKER
STATUS=$HANDOFF_STATUS_ALREADY_DONE
TIMESTAMP=$timestamp
FIRE_COUNT=0
SPEC_PATH=$spec_path
MARKER
fi
# else: HANDOFF_STATUS_ALREADY_DONE — preserve TIMESTAMP and FIRE_COUNT (AC3).

# ─── Handoff packet emit (re-emit on every call — idempotent) ───
cat <<EOF

===== spec-distill handoff packet =====
Spec lock 완료: $spec_path

[1] /compact 명령 (지금 복사-실행):

  /compact spec at $spec_path 보존. 그 spec 본문(특히 Handoff Context, Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. 다음 단계는 "Skill superpowers:writing-plans $spec_path" 호출.

[2] /compact 후 첫 메시지 (자동 진행되면 생략):

  Skill superpowers:writing-plans $spec_path

========================================
EOF

# ─── Session directory cleanup (only on first emit; already_done preserves nothing extra) ───
if [[ "$current_status" == "$HANDOFF_STATUS_EMITTED" && "$cleanup_skipped" == "0" ]]; then
    rm -rf -- "$main_repo/.claude/spec-distill/$session_id/" 2>/dev/null || \
        echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2
fi

echo "spec-distill v0.10.0 종료 (status: $current_status)."
```

- [ ] **Step 2: Make it executable (already is, but confirm)**

Run: `chmod +x plugins/spec-distill/scripts/approve_handoff.sh`

- [ ] **Step 3: Re-run named-status invariant test (now GREEN)**

Run: `bash plugins/spec-distill/tests/test_handoff_status_named.sh`
Expected: `PASSED: 7 invariants`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/scripts/approve_handoff.sh
git commit -m "feat(spec-distill): approve_handoff.sh idempotent state machine (no commit)"
```

---

### Task 3: Rewrite test_approve_handoff.sh — AC1/AC2/AC3 semantics

**Files:**
- Modify: `plugins/spec-distill/tests/test_approve_handoff.sh`

기존 Case 1, 5, 7은 v0.9.0의 commit-on-approve 의미를 검증했다. 이제 commit이 사라졌으므로 AC1 (marker creation + STATUS=already_handed_off), AC2 (dirty_blocked stderr 4-token), AC3 (idempotent re-run preserves TIMESTAMP)로 재작성한다.

- [ ] **Step 1: Rewrite test_approve_handoff.sh in full**

전체 파일을 다음으로 교체:

```bash
#!/usr/bin/env bash
# AC1/AC2/AC3/AC7 — approve_handoff.sh idempotent contract (v0.10.0).
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q
    git config user.email test@x.invalid
    git config user.name test
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m "init"
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo "state" > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}

marker_path() {
    local wd=$1 sid=$2
    echo "$wd/.claude/spec-distill/.markers/${sid}.emitted"
}

# ───────── Case 1 (AC1): happy path — clean HEAD spec → marker created, packet emitted ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/tmp/out 2>/tmp/err
rc=$?
m=$(marker_path "$WORK" "test-sid12")
if [[ $rc -eq 0 && -f "$m" ]] && grep -q "STATUS=already_handed_off" "$m" && grep -q "===== spec-distill handoff packet =====" /tmp/out; then
    note PASS "case 1 (AC1): clean HEAD → marker created + packet emitted"
else
    note FAIL "case 1: rc=$rc, marker_exists=$([[ -f $m ]] && echo y || echo n), stdout_ok=$(grep -q handoff /tmp/out && echo y || echo n)"
fi
rm -rf "$WORK"

# ───────── Case 2 (AC2): dirty spec → exit 1 + 4-token stderr advisory ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "uncommitted modification" >> "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/tmp/out 2>/tmp/err
rc=$?
m=$(marker_path "$WORK" "test-sid12")
required_tokens_ok=1
grep -q "\[spec-distill\]" /tmp/err || required_tokens_ok=0
grep -q "dirty_blocked" /tmp/err || required_tokens_ok=0
grep -q "git status --short" /tmp/err || required_tokens_ok=0
grep -q "git add -- " /tmp/err || required_tokens_ok=0
grep -q "git commit -m " /tmp/err || required_tokens_ok=0
if [[ $rc -ne 0 && ! -f "$m" && "$required_tokens_ok" -eq 1 ]]; then
    note PASS "case 2 (AC2): dirty → exit 1 + 4-token advisory + no marker"
else
    note FAIL "case 2: rc=$rc, marker_absent=$([[ ! -f $m ]] && echo y || echo n), tokens_ok=$required_tokens_ok"
fi
rm -rf "$WORK"

# ───────── Case 3 (AC3): idempotent re-run → marker preserved, TIMESTAMP unchanged ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
m=$(marker_path "$WORK" "test-sid12")
ts1=$(grep "^TIMESTAMP=" "$m" | cut -d= -f2-)
sleep 1
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/tmp/out 2>&1
rc=$?
ts2=$(grep "^TIMESTAMP=" "$m" | cut -d= -f2-)
if [[ $rc -eq 0 && -f "$m" && "$ts1" == "$ts2" ]] && grep -q "STATUS=already_handed_off" "$m" && grep -q "handoff packet" /tmp/out; then
    note PASS "case 3 (AC3): re-run preserves TIMESTAMP + re-emits packet"
else
    note FAIL "case 3: rc=$rc, ts_unchanged=$([[ $ts1 == $ts2 ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ───────── Case 4: charset reject (cleanup_skipped) ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>/tmp/err
grep -q "cleanup skipped" /tmp/err \
    && note PASS "case 4: charset reject emits advisory" \
    || note FAIL "case 4: missing cleanup-skipped advisory"
rm -rf "$WORK"

# ───────── Case 5: empty session_id arg → exit 1 ─────────
bash "$SCRIPT" "" "anything" >/dev/null 2>&1
[[ $? -ne 0 ]] && note PASS "case 5: empty session_id rejected" || note FAIL "case 5: empty session_id accepted"

# ───────── Case 6: empty spec_path arg → exit 1 ─────────
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1
[[ $? -ne 0 ]] && note PASS "case 6: empty spec_path rejected" || note FAIL "case 6: empty spec_path accepted"

# ───────── Case 7 (AC7): kill switch DEVBREW_DISABLE_SPEC_DISTILL=1 → exit 0, no marker ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
m=$(marker_path "$WORK" "test-sid12")
[[ $rc -eq 0 && ! -f "$m" ]] \
    && note PASS "case 7 (AC7): kill switch → exit 0, no marker" \
    || note FAIL "case 7: rc=$rc, marker_absent=$([[ ! -f $m ]] && echo y || echo n)"
rm -rf "$WORK"

# ───────── Case 8: session folder pre-deleted (SessionEnd preceded) → graceful ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
rm -rf "$WORK/.claude/spec-distill/test-sid12"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && note PASS "case 8: folder pre-deleted graceful" || note FAIL "case 8: rc=$rc"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 8 cases"
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bash plugins/spec-distill/tests/test_approve_handoff.sh`
Expected: `PASSED: 8 cases`

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_approve_handoff.sh
git commit -m "test(spec-distill): rewrite approve_handoff cases for AC1/AC2/AC3"
```

---

## Phase 2: compact-detect.py (UserPromptSubmit hook)

### Task 4: Payload schema probe (advisory #1 — temporary debug pass)

**Files:**
- Create (temporary): `plugins/spec-distill/hooks/compact-detect.py` (probe-only version)

reviewer round-3 advisory: spec는 `user_message` 키를 가정하지만 Claude Code hook payload의 실제 필드명은 실측 확정 후 코드 박제. 이 task는 *1회용 dump*만 수행.

- [ ] **Step 1: Write probe-only compact-detect.py**

```python
#!/usr/bin/env python3
"""compact-detect.py — PROBE STAGE (Task 4 only).

Dumps stdin payload to stderr so we can confirm the actual UserPromptSubmit
key name (spec assumes `user_message`). This is REMOVED in Task 6.

Run manually: echo '{"user_message":"test"}' | python3 compact-detect.py
"""
from __future__ import annotations
import json
import sys


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    print(json.dumps(payload, indent=2, ensure_ascii=False), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/spec-distill/hooks/compact-detect.py`

- [ ] **Step 3: Manual smoke — confirm dump path works**

Run: `echo '{"user_message":"hello","session_id":"abc","other":"x"}' | python3 plugins/spec-distill/hooks/compact-detect.py 2>&1 1>/dev/null`
Expected stderr: `{"user_message": "hello", "session_id": "abc", "other": "x"}` (pretty-printed JSON).

- [ ] **Step 4: Note schema observation**

Verify Claude Code documentation (or existing `pending-review-reminder.py` reference comments) for the actual payload key:
- Run: `grep -rn "user_message\|prompt\|user_input" plugins/spec-distill/hooks/ docs/philosophy/ 2>/dev/null | head -20`
- Existing hooks read `session_id` from payload; UserPromptSubmit's prompt field name is documented in Claude Code hook spec as `prompt` (confirm via grep result above). If grep shows the field name in any existing hook code, use that. Otherwise, in the absence of contradicting evidence, the implementation in Task 6 will support BOTH `user_message` and `prompt` keys (read whichever is present) to be schema-tolerant. This is a defensive 2-key fallback, not feature-flag scope creep.

- [ ] **Step 5: No commit yet** — probe code is temporary, gets overwritten in Task 6. Stage nothing.

---

### Task 5: Write test_compact_detect_hook.sh (RED)

**Files:**
- Create: `plugins/spec-distill/tests/test_compact_detect_hook.sh`

AC5: lstrip + startswith. 두 조건 case-sensitive. ASCII `/compact` 또는 `Skill superpowers:writing-plans`.

- [ ] **Step 1: Write the test file**

```bash
#!/usr/bin/env bash
# AC5 — compact-detect.py: /compact prefix or Skill writing-plans → marker delete.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-detect.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

make_marker() {
    local wd=$1 sid=$2
    mkdir -p "$wd/.claude/spec-distill/.markers"
    cat > "$wd/.claude/spec-distill/.markers/${sid}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=2
SPEC_PATH=/dummy/spec.md
MARKER
}

invoke() {
    local wd=$1 payload=$2
    cd "$wd"
    git init -q 2>/dev/null || true
    git config user.email t@x.invalid 2>/dev/null
    git config user.name t 2>/dev/null
    echo "$payload" | python3 "$HOOK" 2>&1
}

# ───────── Case 1 (AC5.i): /compact prefix → marker deleted ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"/compact preserve spec\",\"prompt\":\"/compact preserve spec\"}" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 1: /compact prefix → marker deleted"
else
    note FAIL "case 1: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 2 (AC5.ii): Skill superpowers:writing-plans → marker deleted ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"Skill superpowers:writing-plans foo.md\",\"prompt\":\"Skill superpowers:writing-plans foo.md\"}" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 2: Skill writing-plans → marker deleted"
else
    note FAIL "case 2: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 3: leading whitespace handled (lstrip semantics) ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"   /compact\",\"prompt\":\"   /compact\"}" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 3: leading whitespace then /compact → marker deleted"
else
    note FAIL "case 3: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 4: substring (mid-message) → marker preserved ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"please run /compact later\",\"prompt\":\"please run /compact later\"}" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 4: substring /compact → marker preserved"
else
    note FAIL "case 4: marker deleted on substring match (false positive)"
fi
rm -rf "$WORK"

# ───────── Case 5: case-sensitive (/Compact rejected) ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"/Compact preserve\",\"prompt\":\"/Compact preserve\"}" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 5: /Compact (uppercase C) → marker preserved (case-sensitive)"
else
    note FAIL "case 5: case-insensitive match leaked"
fi
rm -rf "$WORK"

# ───────── Case 6: unrelated prompt → marker preserved ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "{\"session_id\":\"$SID\",\"user_message\":\"do something else\",\"prompt\":\"do something else\"}" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 6: unrelated prompt → marker preserved"
else
    note FAIL "case 6: marker deleted on unrelated prompt"
fi
rm -rf "$WORK"

# ───────── Case 7 (AC7): kill switch DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
DEVBREW_DISABLE_SPEC_DISTILL=1 bash -c "echo '{\"session_id\":\"$SID\",\"user_message\":\"/compact\",\"prompt\":\"/compact\"}' | python3 \"$HOOK\"" >/dev/null 2>&1
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 7 (AC7): kill switch → marker preserved (hook no-op)"
else
    note FAIL "case 7: kill switch did not no-op"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 7 cases"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/spec-distill/tests/test_compact_detect_hook.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_compact_detect_hook.sh`
Expected: FAIL — current `compact-detect.py` is the Task 4 probe (no marker-delete logic).

- [ ] **Step 4: Commit (test-only)**

```bash
git add plugins/spec-distill/tests/test_compact_detect_hook.sh
git commit -m "test(spec-distill): compact-detect hook lstrip+startswith AC5"
```

---

### Task 6: Implement compact-detect.py (GREEN)

**Files:**
- Modify (overwrite probe): `plugins/spec-distill/hooks/compact-detect.py`

probe 코드 제거 + 실제 marker-delete logic 구현.

- [ ] **Step 1: Rewrite compact-detect.py in full**

```python
#!/usr/bin/env python3
"""spec-distill UserPromptSubmit hook — compact detect (v0.10.0).

Watches for /compact or Skill superpowers:writing-plans at the *start* of
the user message (lstrip + startswith, case-sensitive). On match, deletes
the handoff marker file at .claude/spec-distill/.markers/<sid>.emitted
so the compact-induction Stop hook stops firing.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:compact-detect (or :UserPromptSubmit — shared with reminder)

Note: shares UserPromptSubmit with pending-review-reminder.py; both are
no-ops when their respective triggers are absent.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root, resolve_session_id  # noqa: E402

COMPACT_PREFIXES = ("/compact", "Skill superpowers:writing-plans")


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:compact-detect",
        "spec-distill:UserPromptSubmit",
    })


def extract_user_text(payload: dict) -> str:
    """Read prompt text from payload; tolerant to schema drift.

    Claude Code's UserPromptSubmit payload uses `prompt` (per hook docs);
    we also accept `user_message` as a defensive fallback so the spec's
    documented field name continues to work if the schema reverts.
    """
    for key in ("prompt", "user_message"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] compact-detect stdin error: {exc}", file=sys.stderr)
        payload = {}

    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0

    text = extract_user_text(payload).lstrip()
    if not any(text.startswith(p) for p in COMPACT_PREFIXES):
        return 0

    marker = state_root() / ".markers" / f"{session_id}.emitted"
    if not marker.exists():
        return 0

    try:
        marker.unlink()
        print(
            f"[spec-distill] compact-detect: /compact|writing-plans observed — marker deleted ({marker.name})",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] compact-detect: marker unlink failed (non-fatal): {exc}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run test to verify GREEN**

Run: `bash plugins/spec-distill/tests/test_compact_detect_hook.sh`
Expected: `PASSED: 7 cases`

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/compact-detect.py
git commit -m "feat(spec-distill): compact-detect UserPromptSubmit hook"
```

---

## Phase 3: compact-induction.py (Stop hook)

### Task 7: Write test_compact_induction_hook.sh (RED)

**Files:**
- Create: `plugins/spec-distill/tests/test_compact_induction_hook.sh`

AC4: marker 존재 → JSON stdout w/ `hookSpecificOutput.additionalContext` containing verbatim `/compact` + `Skill superpowers:writing-plans`. marker 부재 → stdout `{}` + exit 0.

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# AC4 — compact-induction.py Stop hook contract.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-induction.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

make_marker() {
    local wd=$1 sid=$2
    mkdir -p "$wd/.claude/spec-distill/.markers"
    cat > "$wd/.claude/spec-distill/.markers/${sid}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=0
SPEC_PATH=/dummy/spec.md
MARKER
}

invoke() {
    local wd=$1 sid=$2
    cd "$wd"
    git init -q 2>/dev/null || true
    git config user.email t@x.invalid 2>/dev/null
    git config user.name t 2>/dev/null
    echo "{\"session_id\":\"$sid\"}" | python3 "$HOOK"
}

# ───────── Case 1 (AC4 hit): marker present → JSON with /compact + writing-plans ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
out=$(invoke "$WORK" "$SID" 2>/dev/null || true)
echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ac = d['hookSpecificOutput']['additionalContext']
assert '/compact' in ac, f'/compact missing in: {ac}'
assert 'Skill superpowers:writing-plans' in ac, f'writing-plans missing in: {ac}'
assert d['hookSpecificOutput']['hookEventName'] == 'Stop'
print('OK')
" >/dev/null 2>&1 \
    && note PASS "case 1 (AC4): marker → JSON has /compact + writing-plans" \
    || note FAIL "case 1: stdout malformed: $out"
rm -rf "$WORK"

# ───────── Case 2 (AC4 miss): marker absent → stdout exactly {} ─────────
WORK=$(mktemp -d)
out=$(invoke "$WORK" "sess1234abc" 2>/dev/null || true)
trimmed=$(echo "$out" | tr -d '[:space:]')
if [[ "$trimmed" == "{}" ]]; then
    note PASS "case 2 (AC4): marker absent → stdout '{}'"
else
    note FAIL "case 2: stdout '$trimmed' (expected '{}')"
fi
rm -rf "$WORK"

# ───────── Case 3 (AC6): FIRE_COUNT increments on each fire ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
invoke "$WORK" "$SID" >/dev/null 2>&1
fc1=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
invoke "$WORK" "$SID" >/dev/null 2>&1
fc2=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
if [[ "$fc1" == "1" && "$fc2" == "2" ]]; then
    note PASS "case 3 (AC6): FIRE_COUNT 0→1→2"
else
    note FAIL "case 3: fc1=$fc1, fc2=$fc2 (expected 1,2)"
fi
rm -rf "$WORK"

# ───────── Case 4 (AC8): kill switch DEVBREW_SKIP_HOOKS=spec-distill:compact-induction → exit 0 no-op ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
out=$(DEVBREW_SKIP_HOOKS="spec-distill:compact-induction" bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" 2>/dev/null)
fc=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
if [[ -z "$out" || "$out" == "" ]] && [[ "$fc" == "0" ]]; then
    note PASS "case 4 (AC8): hook-specific kill switch → no JSON, no FIRE_COUNT bump"
else
    note FAIL "case 4: out='$out', fc=$fc"
fi
rm -rf "$WORK"

# ───────── Case 5 (AC7): DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
out=$(DEVBREW_DISABLE_SPEC_DISTILL=1 bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" 2>/dev/null)
fc=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
[[ -z "$out" && "$fc" == "0" ]] \
    && note PASS "case 5 (AC7): plugin disable → no-op" \
    || note FAIL "case 5: out='$out', fc=$fc"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 5 cases"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/spec-distill/tests/test_compact_induction_hook.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_compact_induction_hook.sh`
Expected: FAIL — `compact-induction.py` doesn't exist yet.

- [ ] **Step 4: Commit (test-only)**

```bash
git add plugins/spec-distill/tests/test_compact_induction_hook.sh
git commit -m "test(spec-distill): compact-induction Stop hook AC4/AC6/AC7/AC8"
```

---

### Task 8: Implement compact-induction.py (GREEN — basic emit + FIRE_COUNT)

**Files:**
- Create: `plugins/spec-distill/hooks/compact-induction.py`

stagnation cap (5회)은 Task 10에서 추가. 이 task는 marker 감지 + JSON emit + FIRE_COUNT bump까지.

- [ ] **Step 1: Write the hook**

```python
#!/usr/bin/env python3
"""spec-distill Stop hook — compact induction (v0.10.0).

If a handoff marker file exists at .claude/spec-distill/.markers/<sid>.emitted,
emit JSON with hookSpecificOutput.additionalContext containing the verbatim
/compact command and the writing-plans pointer. This is the *unmissable*
SystemMessage layer that defeats AP2 "polite stop" — once approve_handoff.sh
writes the marker, every Stop turn re-injects the next-step instruction
until the user actually runs /compact (UserPromptSubmit hook deletes marker)
or 5 fires elapse (stagnation escape, Task 10).

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:compact-induction (or :Stop — shared with review-dispatch)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root, resolve_session_id  # noqa: E402

FIRE_COUNT_RE = re.compile(r"^FIRE_COUNT=(\d+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:compact-induction",
        "spec-distill:Stop",
    })


def read_marker(marker: Path) -> dict[str, str]:
    """Parse the plaintext key=value marker file."""
    out: dict[str, str] = {}
    try:
        for line in marker.read_text(encoding="utf-8").splitlines():
            if "=" in line:
                k, _, v = line.partition("=")
                out[k.strip()] = v.strip()
    except OSError:
        pass
    return out


def bump_fire_count(marker: Path, body: str) -> int:
    """Increment FIRE_COUNT line in marker file. Returns new count."""
    m = FIRE_COUNT_RE.search(body)
    current = int(m.group(1)) if m else 0
    new_count = current + 1
    if m:
        new_body = FIRE_COUNT_RE.sub(f"FIRE_COUNT={new_count}", body)
    else:
        new_body = body.rstrip() + f"\nFIRE_COUNT={new_count}\n"
    try:
        marker.write_text(new_body, encoding="utf-8")
    except OSError as exc:
        print(f"[spec-distill] compact-induction marker write failed: {exc}", file=sys.stderr)
    return new_count


def emit_no_op() -> None:
    """Default {} stdout for AC4 miss path — JSON-consistent."""
    print("{}", flush=True)


def emit_induction(spec_path: str) -> None:
    additional_context = (
        "MANDATORY next step: handoff packet emitted — 사용자가 `/compact`를 실행해야 다음 phase 진입.\n\n"
        "다음 명령을 사용자에게 보이도록 *그대로* 노출 (narrate-only 금지):\n\n"
        f"  /compact spec at {spec_path} 보존. 그 spec 본문(특히 Handoff Context, "
        "Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. "
        f"다음 단계는 \"Skill superpowers:writing-plans {spec_path}\" 호출.\n\n"
        "사용자 `/compact` 후 첫 입력 (또는 자동 진행 시 즉시):\n\n"
        f"  Skill superpowers:writing-plans {spec_path}\n\n"
        "주의: 본 메시지는 사용자가 `/compact` 또는 `Skill superpowers:writing-plans`로 시작하는 "
        "프롬프트를 입력할 때까지 매 Stop turn 재발화됨 (compact-induction hook)."
    )
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "Stop",
            "additionalContext": additional_context,
        },
        "systemMessage": "[spec-distill] compact induction — /compact required",
    }
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] compact-induction stdin error: {exc}", file=sys.stderr)
        payload = {}

    session_id = resolve_session_id(payload)
    if session_id is None:
        emit_no_op()
        return 0

    marker = state_root() / ".markers" / f"{session_id}.emitted"
    if not marker.exists():
        emit_no_op()
        return 0

    try:
        body = marker.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"[spec-distill] compact-induction marker read failed: {exc}", file=sys.stderr)
        emit_no_op()
        return 0

    fields = read_marker(marker)
    spec_path = fields.get("SPEC_PATH", "<spec path missing in marker>")

    bump_fire_count(marker, body)
    emit_induction(spec_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/spec-distill/hooks/compact-induction.py`

- [ ] **Step 3: Run test to verify GREEN**

Run: `bash plugins/spec-distill/tests/test_compact_induction_hook.sh`
Expected: `PASSED: 5 cases`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/hooks/compact-induction.py
git commit -m "feat(spec-distill): compact-induction Stop hook (basic emit)"
```

---

### Task 9: Write test_compact_induction_stagnation.sh (RED)

**Files:**
- Create: `plugins/spec-distill/tests/test_compact_induction_stagnation.sh`

AC6: `FIRE_COUNT >= 5` → marker 자동 삭제 + stderr advisory containing `stagnation`.

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# AC6 — compact-induction stagnation: 5 fires without /compact → self-cleanup.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-induction.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

WORK=$(mktemp -d)
SID="sess1234abc"
mkdir -p "$WORK/.claude/spec-distill/.markers"
cat > "$WORK/.claude/spec-distill/.markers/${SID}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=0
SPEC_PATH=/dummy/spec.md
MARKER

cd "$WORK"
git init -q
git config user.email t@x.invalid
git config user.name t

# Fire 5 times
for i in 1 2 3 4 5; do
    echo "{\"session_id\":\"$SID\"}" | python3 "$HOOK" >/dev/null 2>/tmp/induct_err_$i || true
done

# Check FIRE_COUNT progression and final self-cleanup behavior.
# At FIRE_COUNT == 5 the hook should delete the marker AND advisory mentions "stagnation".
marker_file="$WORK/.claude/spec-distill/.markers/${SID}.emitted"
if [[ ! -f "$marker_file" ]]; then
    note PASS "case 1: marker auto-deleted after 5 fires"
else
    note FAIL "case 1: marker still exists ($(cat $marker_file 2>/dev/null | tr '\n' ' '))"
fi

# Advisory check on the 5th fire's stderr
if grep -q "stagnation" /tmp/induct_err_5 2>/dev/null; then
    note PASS "case 2: stagnation advisory emitted on 5th fire"
else
    note FAIL "case 2: stagnation keyword missing in stderr: $(cat /tmp/induct_err_5 2>/dev/null)"
fi

# 6th fire should be a no-op (marker absent) — emit {}
out6=$(echo "{\"session_id\":\"$SID\"}" | python3 "$HOOK" 2>/dev/null | tr -d '[:space:]')
if [[ "$out6" == "{}" ]]; then
    note PASS "case 3: 6th fire (post-cleanup) → stdout '{}'"
else
    note FAIL "case 3: 6th fire stdout '$out6' (expected '{}')"
fi

rm -rf "$WORK" /tmp/induct_err_*

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 3 cases"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/spec-distill/tests/test_compact_induction_stagnation.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_compact_induction_stagnation.sh`
Expected: FAIL — current hook doesn't implement 5-fire self-cleanup.

- [ ] **Step 4: Commit (test-only)**

```bash
git add plugins/spec-distill/tests/test_compact_induction_stagnation.sh
git commit -m "test(spec-distill): compact-induction stagnation AC6 (5-fire cap)"
```

---

### Task 10: Add stagnation cap to compact-induction.py (GREEN)

**Files:**
- Modify: `plugins/spec-distill/hooks/compact-induction.py`

5회 fire 도달 시 marker 삭제 + stderr advisory + emit `{}`.

- [ ] **Step 1: Modify the `main()` function**

`bump_fire_count(...)` 호출 직후, 결과 count가 5 이상이면 marker 삭제 + advisory + `emit_no_op()`. 다음 블록을 `bump_fire_count(marker, body)` 한 줄 자리에 교체:

기존 코드 (Task 8):
```python
    bump_fire_count(marker, body)
    emit_induction(spec_path)
    return 0
```

신규 코드:
```python
    new_count = bump_fire_count(marker, body)
    if new_count >= 5:
        try:
            marker.unlink()
        except OSError as exc:
            print(
                f"[spec-distill] compact-induction stagnation cleanup failed: {exc}",
                file=sys.stderr,
            )
        print(
            "[spec-distill] compact-induction stagnation: 5 fires without /compact "
            "— manual confirmation required",
            file=sys.stderr,
        )
        emit_no_op()
        return 0
    emit_induction(spec_path)
    return 0
```

- [ ] **Step 2: Run stagnation test (GREEN)**

Run: `bash plugins/spec-distill/tests/test_compact_induction_stagnation.sh`
Expected: `PASSED: 3 cases`

- [ ] **Step 3: Re-run basic induction test (still GREEN)**

Run: `bash plugins/spec-distill/tests/test_compact_induction_hook.sh`
Expected: `PASSED: 5 cases`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/hooks/compact-induction.py
git commit -m "feat(spec-distill): compact-induction stagnation cap (5 fires)"
```

---

## Phase 4: Integration

### Task 11: Register hooks in hooks.json

**Files:**
- Modify: `plugins/spec-distill/hooks/hooks.json`

신규 hook 2개를 등록. UserPromptSubmit에는 compact-detect.py 추가 (pending-review-reminder.py와 공존). Stop에는 compact-induction.py 추가 (review-dispatch.py와 공존).

> **Audit trail (plan advisory #2):** AC8 (`DEVBREW_SKIP_HOOKS=spec-distill:compact-induction`) verification은 V6 환경변수 테스트가 compact-induction.py만 no-op로 만들고 compact-detect.py 정상 동작은 V4 (`test_compact_detect_hook.sh` Case 7)가 이미 cover. 신규 통합 테스트(V9, Task 12)는 두 hook 모두 정상 동작 흐름의 chain 검증.

- [ ] **Step 1: Overwrite hooks.json**

전체 파일을 다음으로 교체:

```json
{
  "description": "spec-distill — UserPromptSubmit reminder/compact-detect, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer-dispatch + compact-induction, SessionEnd cleanup.",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pending-review-reminder.py",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/compact-detect.py",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-anchor.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/spec-write-validator.py",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/review-dispatch.py",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/compact-induction.py",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json; json.load(open('plugins/spec-distill/hooks/hooks.json'))"`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json
git commit -m "feat(spec-distill): register compact-detect + compact-induction hooks"
```

---

### Task 12: End-to-end chain test (V9)

**Files:**
- Create: `plugins/spec-distill/tests/test_handoff_compact_chain.sh`

V9 — approve_handoff.sh → marker → compact-induction (JSON) → compact-detect → marker delete. 전체 JSON contract을 spec-distill external 환경에서 검증.

- [ ] **Step 1: Write the integration test**

```bash
#!/usr/bin/env bash
# V9 — full hook chain: approve → marker → induction JSON → detect → marker gone.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVE="$PLUGIN_DIR/scripts/approve_handoff.sh"
INDUCT="$PLUGIN_DIR/hooks/compact-induction.py"
DETECT="$PLUGIN_DIR/hooks/compact-detect.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

WORK=$(mktemp -d)
SID="chainsid12abc"
SPEC_REL="docs/superpowers/specs/2026-01-01-test-spec.md"

mkdir -p "$WORK/docs/superpowers/specs"
cd "$WORK"
git init -q
git config user.email t@x.invalid
git config user.name t
echo "# spec" > "$SPEC_REL"
mkdir -p "$WORK/.claude/spec-distill/$SID"
echo "state" > "$WORK/.claude/spec-distill/$SID/state.local.md"
git add . && git commit -q -m "init spec"

# ───── Step 1: approve_handoff.sh → marker should exist ─────
bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/tmp/chain_out 2>&1
m="$WORK/.claude/spec-distill/.markers/${SID}.emitted"
if [[ -f "$m" ]] && grep -q "STATUS=already_handed_off" "$m"; then
    note PASS "chain step 1: approve_handoff → marker created"
else
    note FAIL "chain step 1: marker missing (output: $(cat /tmp/chain_out))"
fi

# ───── Step 2: compact-induction.py with marker → JSON has /compact + writing-plans ─────
induct_out=$(echo "{\"session_id\":\"$SID\"}" | python3 "$INDUCT" 2>/dev/null)
echo "$induct_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ac = d['hookSpecificOutput']['additionalContext']
assert '/compact' in ac and 'Skill superpowers:writing-plans' in ac
assert d['hookSpecificOutput']['hookEventName'] == 'Stop'
" 2>/dev/null \
    && note PASS "chain step 2: induction emits /compact + writing-plans" \
    || note FAIL "chain step 2: induction JSON malformed: $induct_out"

# ───── Step 3: compact-detect.py with /compact prompt → marker deleted ─────
echo "{\"session_id\":\"$SID\",\"user_message\":\"/compact preserve spec\",\"prompt\":\"/compact preserve spec\"}" \
    | python3 "$DETECT" >/dev/null 2>&1
if [[ ! -f "$m" ]]; then
    note PASS "chain step 3: detect deletes marker on /compact"
else
    note FAIL "chain step 3: marker still exists after /compact prompt"
fi

# ───── Step 4: induction post-delete → stdout {} ─────
post_out=$(echo "{\"session_id\":\"$SID\"}" | python3 "$INDUCT" 2>/dev/null | tr -d '[:space:]')
[[ "$post_out" == "{}" ]] \
    && note PASS "chain step 4: induction post-delete → stdout '{}'" \
    || note FAIL "chain step 4: induction post-delete stdout='$post_out'"

# ───── Step 5 (V6 kill switch path): DEVBREW_DISABLE_SPEC_DISTILL=1 prevents marker ─────
rm -rf "$WORK/.claude/spec-distill/.markers"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/dev/null 2>&1
if [[ ! -f "$m" ]]; then
    note PASS "chain step 5 (V6): kill switch prevents marker creation"
else
    note FAIL "chain step 5: kill switch leaked marker"
fi

rm -rf "$WORK" /tmp/chain_out

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail step(s)"
    exit 1
fi
echo "PASSED: 5 chain steps"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/spec-distill/tests/test_handoff_compact_chain.sh`

- [ ] **Step 3: Run integration test**

Run: `bash plugins/spec-distill/tests/test_handoff_compact_chain.sh`
Expected: `PASSED: 5 chain steps`

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/tests/test_handoff_compact_chain.sh
git commit -m "test(spec-distill): V9 end-to-end handoff→induction→detect chain"
```

---

### Task 13: spec-distill-gc.py extend for .markers/ TTL sweep

**Files:**
- Modify: `plugins/spec-distill/scripts/spec-distill-gc.py`

기존 fcntl lock / double-stat ns / rename-then-rmtree race guard 패턴을 재사용해 `.markers/` 디렉토리의 24h+ stale marker 파일을 정리. 새 GC 신설 안 함.

- [ ] **Step 1: Add marker sweep function**

`_sweep_gc_pending()` 함수 *바로 아래에* 다음 함수를 추가:

```python
def _sweep_markers(root: Path, ttl_ns: int) -> int:
    """Remove .markers/<sid>.emitted files older than TTL.

    Markers live outside per-session folders (LD5) and outlive their owning
    session by design. TTL-GC sweep prevents indefinite accumulation on
    machines where Stop/UserPromptSubmit hooks never resolve the marker
    (e.g., abandoned sessions).

    Race-safe via individual file unlink (no rename-then-rmtree needed —
    markers are single files, not directories).
    """
    markers_dir = root / ".markers"
    if not markers_dir.exists():
        return 0
    removed = 0
    now_ns = time.time_ns()
    for child in markers_dir.iterdir():
        if not child.is_file():
            continue
        if not child.name.endswith(".emitted"):
            continue
        try:
            age_ns = now_ns - child.stat().st_mtime_ns
        except OSError:
            continue
        if age_ns < ttl_ns:
            continue
        try:
            child.unlink()
            removed += 1
        except OSError:
            continue
    return removed
```

- [ ] **Step 2: Wire it into `gc()` after `_sweep_gc_pending` call**

`gc()` 함수 안에서 `removed += _sweep_gc_pending(root)` 라인 *바로 다음*에 한 줄 추가:

```python
            removed += _sweep_gc_pending(root)
            removed += _sweep_markers(root, ttl_ns)
            for child in root.iterdir():
```

- [ ] **Step 3: Quick sanity test (manual)**

Run:
```bash
mkdir -p /tmp/gc-test/.claude/spec-distill/.markers
touch -d "2 days ago" /tmp/gc-test/.claude/spec-distill/.markers/sess12345678.emitted
echo "test" > /tmp/gc-test/.claude/spec-distill/.markers/sess12345678.emitted
touch -d "2 days ago" /tmp/gc-test/.claude/spec-distill/.markers/sess12345678.emitted
cd /tmp/gc-test
git init -q
DEVBREW_SPEC_DISTILL_GC_VERBOSE=1 python3 "$OLDPWD/plugins/spec-distill/scripts/spec-distill-gc.py"
[[ ! -f /tmp/gc-test/.claude/spec-distill/.markers/sess12345678.emitted ]] && echo "PASS" || echo "FAIL"
rm -rf /tmp/gc-test
cd "$OLDPWD"
```

Expected: `PASS` (marker file removed because mtime > 24h).

- [ ] **Step 4: Run existing GC test to ensure no regression**

Run: `python3 -m pytest plugins/spec-distill/tests/test_gc.py -v` (or `python3 plugins/spec-distill/tests/test_gc.py`)
Expected: all pre-existing tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/spec-distill-gc.py
git commit -m "feat(spec-distill): TTL-GC sweeps .markers/ stale files"
```

---

## Phase 5: Documentation, version bump, SKILL update

### Task 14: plugin.json version bump 0.9.0 → 0.10.0

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`

CLAUDE.md "모든 PR마다 SemVer bump" + spec C3 (minor bump for new surface).

- [ ] **Step 1: Edit plugin.json**

`"version": "0.9.0"` → `"version": "0.10.0"`

- [ ] **Step 2: Verify**

Run: `jq -r .version plugins/spec-distill/.claude-plugin/plugin.json`
Expected: `0.10.0`

- [ ] **Step 3: Commit (defer to Task 15 to bundle with CHANGELOG)** — leave staged but don't commit standalone. Actually, since CHANGELOG must accompany version bump per CLAUDE.md, bundle in Task 15.

---

### Task 15: CHANGELOG.md entry for 0.10.0

**Files:**
- Modify: `plugins/spec-distill/CHANGELOG.md`

`## [0.10.0] — 2026-05-27` entry insertion at top.

- [ ] **Step 1: Insert new entry above current `## [0.9.0]` heading**

`CHANGELOG.md` 파일 최상단의 `# Changelog` 라인 바로 다음에 다음 블록을 삽입 (기존 `## [0.9.0]` 위에 위치):

```markdown
## [0.10.0] — 2026-05-27

### Added
- `hooks/compact-induction.py` — Stop event hook. `.claude/spec-distill/.markers/<sid>.emitted` marker 감지 시 `hookSpecificOutput.additionalContext`로 verbatim `/compact` 명령 + `Skill superpowers:writing-plans` 안내 emit. 5회 fire 도달 시 self-cleanup + stagnation advisory.
- `hooks/compact-detect.py` — UserPromptSubmit event hook. `user_message`/`prompt` 필드 lstrip + startswith로 `/compact` 또는 `Skill superpowers:writing-plans` 시작 감지 시 marker 삭제.
- `tests/test_handoff_status_named.sh` — Ouroboros named-status invariant (3 readonly 상수).
- `tests/test_compact_induction_hook.sh` — AC4/AC6/AC7/AC8 Stop hook contract.
- `tests/test_compact_detect_hook.sh` — AC5 lstrip+startswith 7-case.
- `tests/test_compact_induction_stagnation.sh` — AC6 5-fire self-cleanup.
- `tests/test_handoff_compact_chain.sh` — V9 end-to-end hook chain JSON contract.

### Changed
- `scripts/approve_handoff.sh` — **commit 단계 완전 제거** (LD4: spec은 사용자 책임). idempotent state machine으로 재설계: `HANDOFF_STATUS_ALREADY_DONE` / `HANDOFF_STATUS_DIRTY_BLOCKED` / `HANDOFF_STATUS_EMITTED` 3-status named-status (Ouroboros `handoff_contract.py` 패턴). marker file `.claude/spec-distill/.markers/<sid>.emitted`에 `STATUS=`/`TIMESTAMP=`/`FIRE_COUNT=`/`SPEC_PATH=` plaintext key=value 기록. 재호출 시 TIMESTAMP 보존 (dedupe invariant).
- `hooks/hooks.json` — UserPromptSubmit에 compact-detect.py, Stop에 compact-induction.py 등록 (기존 hook과 공존).
- `tests/test_approve_handoff.sh` — Case 1/5/7을 AC1/AC2/AC3 의미로 재작성. dirty_blocked stderr 4-token assertion + idempotent re-run TIMESTAMP preservation 검증.
- `scripts/spec-distill-gc.py` — `_sweep_markers()` 신규 헬퍼 + `gc()` 메인 루프에 한 줄 추가. `.markers/` 디렉토리의 24h+ stale marker 파일 정리 (기존 fcntl lock / TTL 패턴 재사용).
- `skills/reviewing-spec/SKILL.md` — "Approve handoff sequence" 절의 "4-step" 표현을 신규 step (validate / state-machine / marker-write / packet-emit / cleanup)에 맞춰 갱신. 실패 경로 명시: `dirty_blocked` 상태에서 state.local.md 보존.
- `README.md` — Hooks Installed 표에 compact-induction/compact-detect 2행 추가. Principles Instantiated에 Ouroboros `handoff_contract.py` replay-safety/named-status/dedupe instantiation 한 줄.

### Notes
- v0.9.0 에서 생성된 spec 파일은 grandfather migration 없음 (NG5). 기존 `.handoff-status` marker 부재 시 첫 approve_handoff.sh 호출에서 정상 생성.
- compact-detect.py는 `prompt`/`user_message` 두 키 모두 읽음 (Claude Code hook schema tolerance — 둘 중 하나 존재 시 처리).
- compact-induction.py와 review-dispatch.py는 같은 Stop 이벤트에 공존. 실 운영에서는 pending_review block 정리 후 marker가 생성되므로 두 hook이 동시에 emit하지는 않음.
```

- [ ] **Step 2: Verify entry header format**

Run: `head -5 plugins/spec-distill/CHANGELOG.md`
Expected: `# Changelog` followed by `## [0.10.0] — 2026-05-27`.

- [ ] **Step 3: Commit (bundles Task 14 plugin.json + this CHANGELOG)**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): v0.10.0 — plugin.json + CHANGELOG"
```

---

### Task 16: README.md updates

**Files:**
- Modify: `plugins/spec-distill/README.md`

(a) Hooks Installed 표에 2행 추가, (b) Principles Instantiated에 Ouroboros 인용 한 줄, (c) Kill switches에 신규 토큰 2개.

- [ ] **Step 1: Add 2 rows to Hooks Installed table**

`| SessionEnd | hooks/session-end-cleanup.py | ... |` 라인 *바로 위에* 다음 2행 삽입:

```markdown
| Stop (2) | `hooks/compact-induction.py` | v0.10.0 — `.claude/spec-distill/.markers/<sid>.emitted` 존재 시 systemMessage로 `/compact` 명령 + `Skill superpowers:writing-plans` 안내 inject. 5회 fire 후 self-cleanup. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:compact-induction` (또는 `:Stop`). | turn boundary 이벤트 + marker-based 상태 추적은 LLM이 invoke해서 닿을 수 없음 — hook 전용. AP2 polite-stop 봉쇄 핵심 인프라. |
| UserPromptSubmit (2) | `hooks/compact-detect.py` | v0.10.0 — `prompt`/`user_message` lstrip + startswith로 `/compact` 또는 `Skill superpowers:writing-plans` 감지 시 marker 삭제. Stop hook 무한 fire 차단. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:compact-detect` (또는 `:UserPromptSubmit`). | 사용자 입력의 turn boundary 감지는 hook 전용 이벤트. compact-induction과 페어로 작동. |
```

- [ ] **Step 2: Add one line under Three Laws / "Law 3 (Compounding)" section**

`### Principles 흡수` 헤더 *위*에, 마지막 "Law 3" bullet 다음에 추가:

```markdown
- **Law 3 (Compounding) + Ouroboros instantiation (v0.10.0)** — `scripts/approve_handoff.sh`가 Ouroboros `handoff_contract.py` 패턴을 차용: named-status 3개 상수 (`HANDOFF_STATUS_*`), replay-safety (재호출 시 TIMESTAMP 보존), dedupe invariant (marker 존재 = 이미 처리됨). 미래 search가 "handoff invariant"로 두 instantiation을 같이 찾도록 README + CHANGELOG에 명시.
```

- [ ] **Step 3: Add 2 kill switch bullets**

`## Kill switches` 섹션 마지막에 다음 2줄 추가:

```markdown
- `DEVBREW_SKIP_HOOKS=spec-distill:compact-induction` (v0.10.0) — Stop hook compact-induction.py만 skip. review-dispatch.py는 정상.
- `DEVBREW_SKIP_HOOKS=spec-distill:compact-detect` (v0.10.0) — UserPromptSubmit hook compact-detect.py만 skip. pending-review-reminder.py는 정상.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): README — v0.10.0 hooks, principles, kill switches"
```

---

### Task 17: reviewing-spec SKILL.md — approve handoff section update

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

"Approve handoff sequence (AC11)" 섹션의 "4-step" 표현 갱신 + 실패 경로 명시.

- [ ] **Step 1: Find existing approve handoff section**

`## Approve handoff sequence (AC11)` 섹션 (현재 130–144행 부근). 핵심 문장 2개를 다음과 같이 수정:

기존 문장:
```
스크립트가 4-step (commit / handoff pointer / cleanup / termination) atomic 실행. session_id charset guard 내장 — invalid 시 cleanup skip + advisory. commit 실패 시 state.local.md 보존, exit 1.
```

신규 문장으로 교체:
```
스크립트(v0.10.0+)가 idempotent state machine 실행: (1) kill switch + charset guard, (2) marker/HEAD/working-tree 검사로 named status 판정 (`already_handed_off` / `dirty_blocked` / `emitted`), (3) emitted 경로에서 `.claude/spec-distill/.markers/<sid>.emitted` marker write, (4) 모든 정상 경로에서 packet stdout re-emit (재호출 시 TIMESTAMP 보존, dedupe), (5) emitted 경로에서 session 디렉토리 cleanup. `dirty_blocked` 상태에서는 exit 1 + copy-pasteable `git add`/`git commit` advisory를 stderr에 출력 — *commit은 사용자 책임*이며 스크립트가 직접 시도하지 않음 (v0.9.0과 다름).
```

또한 기존 `### 실패 시 state 보존 (P14)` 하위 문단을 다음으로 교체:

```
approve_handoff.sh가 `dirty_blocked` 판정 시 exit 1 + state.local.md 보존 + marker 미생성. cleanup rm 실패는 advisory only — SessionEnd hook이 재시도. v0.10.0부터 git commit 실패는 발생 가능 경로가 아님 (스크립트가 commit 시도 안 함).
```

- [ ] **Step 2: Use Edit tool to apply the two replacements**

Edit 1: 기존 4-step 한 문단 → 신규 5-step 한 문단.

Edit 2: 기존 P14 보존 문단 → 신규 P14 문단.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "docs(spec-distill): reviewing-spec — v0.10.0 approve handoff state machine"
```

---

### Task 18: devbrew root CLAUDE.md — brainstorming → spec-distill handoff guide (one line)

**Files:**
- Modify: `CLAUDE.md` (devbrew root)

spec C1: "변경되는 모든 파일은 plugins/spec-distill/와 devbrew root CLAUDE.md 한 줄 외부로 spillover하지 않는다." 따라서 한 줄만 추가.

- [ ] **Step 1: Add one bullet to Forbidden Patterns section**

`## Forbidden Patterns` 섹션의 5개 bullet 리스트 마지막 (`Unbounded autonomy` 다음, 다음 단락 `**버그가 리뷰를 탈출하면**` 앞)에 다음 한 줄 추가:

```markdown
- **Polite handoff** — brainstorming/spec-distill review-approved 후 `/compact` 안내만 narrate하고 spec-distill 의 `approve_handoff.sh`를 호출하지 않음. 호출하면 marker가 생성되고 Stop hook이 unmissable하게 `/compact`를 induce하므로 narrate-only는 polite-stop의 한 종류 (AP2 variant).
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(devbrew): forbidden pattern — polite handoff for brainstorming/spec-distill"
```

---

## Phase 6: Verification (full V1–V10 sweep)

### Task 19: Run all plugin tests

**Files:** (read-only)

V1–V9 자동 검증. V10 manual smoke는 PR merge 전 사용자가 별도 수행.

- [ ] **Step 1: Run each test sequentially**

```bash
cd plugins/spec-distill
for t in \
    tests/test_approve_handoff.sh \
    tests/test_handoff_status_named.sh \
    tests/test_compact_induction_hook.sh \
    tests/test_compact_detect_hook.sh \
    tests/test_compact_induction_stagnation.sh \
    tests/test_handoff_compact_chain.sh; do
    echo "=== $t ==="
    bash "$t" || { echo "FAILED: $t"; exit 1; }
done
echo "ALL NEW TESTS PASSED"
```

Expected: All PASSED messages, no FAILED.

- [ ] **Step 2: Run existing tests as regression check**

```bash
cd plugins/spec-distill
for t in tests/test_handoff_*.sh tests/test_review_dispatch*.sh tests/test_session_id_resolution.sh tests/test_state_path.sh tests/test_resolve_mode_scope.sh; do
    echo "=== $t ==="
    bash "$t" >/dev/null 2>&1 && echo "PASS: $t" || echo "FAIL: $t"
done
```

Expected: All `PASS:` lines, no `FAIL:`.

- [ ] **Step 3: Run Python tests**

```bash
cd plugins/spec-distill
python3 tests/test_gc.py
python3 tests/test_session_end_cleanup.py
python3 -m unittest tests/test_hook_output_schema.py
```

Expected: all PASS (or `OK` for unittest).

- [ ] **Step 4: Verify version + CHANGELOG**

Run:
```bash
[[ "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" == "0.10.0" ]] && echo "PASS: version" || echo "FAIL: version"
head -3 plugins/spec-distill/CHANGELOG.md | grep -q "0.10.0.*2026-05-27" && echo "PASS: changelog" || echo "FAIL: changelog"
```

Expected: `PASS: version` and `PASS: changelog`.

- [ ] **Step 5: Verify kill switch matrix (V6)**

```bash
WORK=$(mktemp -d)
cd "$WORK"
git init -q
git config user.email t@x.invalid
git config user.name t
mkdir -p docs/superpowers/specs
echo "# spec" > docs/superpowers/specs/2026-01-01-test-spec.md
git add . && git commit -q -m "init"

# Combination A: full disable
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$OLDPWD/plugins/spec-distill/scripts/approve_handoff.sh" "sess1234abc" "docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc1=$?
[[ ! -f .claude/spec-distill/.markers/sess1234abc.emitted ]] && [[ $rc1 -eq 0 ]] \
    && echo "PASS: V6 plugin-disable" || echo "FAIL: V6 plugin-disable rc=$rc1"

# Combination B: hook-specific skip — should NOT prevent approve_handoff
rm -rf .claude
DEVBREW_SKIP_HOOKS="spec-distill:compact-induction" bash "$OLDPWD/plugins/spec-distill/scripts/approve_handoff.sh" "sess1234abc" "docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
[[ -f .claude/spec-distill/.markers/sess1234abc.emitted ]] \
    && echo "PASS: V6 hook-specific-skip (approve unaffected)" \
    || echo "FAIL: V6 hook-specific-skip"

cd "$OLDPWD"
rm -rf "$WORK"
```

Expected: both `PASS: V6 ...` lines.

- [ ] **Step 6: No commit needed** — verification only. If any step fails, return to the corresponding task and fix.

---

### Task 20: V10 manual smoke checklist (advisory — PR pre-merge)

**Files:** (read-only — this task documents the manual check, doesn't write code)

V9 automates the JSON contract; V10 confirms a *real* Claude Code session sees the SystemMessage. Document this in the PR description, not in code.

- [ ] **Step 1: Add manual smoke note to PR description (template)**

When opening the PR, paste this checklist in the PR body:

```markdown
## V10 Manual Smoke (run in a real Claude Code session before merge)

1. brainstorming → 임의 design.md 생성 (`/superpowers:brainstorming foo`)
2. spec-distill review-dispatch fires → reviewing-spec dispatch passes → approve
3. `approve_handoff.sh` runs (called from skill, no commit attempted)
4. Confirm: stdout contains `===== spec-distill handoff packet =====` block
5. Confirm: next assistant turn (Stop event) re-injects `/compact` instruction visibly
6. Type `/compact ...` in session
7. Confirm: subsequent Stop turn no longer re-injects (marker deleted by compact-detect)
8. Confirm: `Skill superpowers:writing-plans <path>` proceeds normally
```

- [ ] **Step 2: This task has no commit** — it's a PR-time checklist, executed once before merge.

---

## Self-Review Checklist (for plan author)

After writing this plan, the author confirmed:

**1. Spec coverage:**
- G1 (no commit in approve_handoff): Task 2 ✓
- G2 (dirty_blocked user-fixable): Task 2 + Task 3 Case 2 ✓
- G3 (unmissable systemMessage): Task 8 ✓
- G4 (UserPromptSubmit deletes marker): Task 6 ✓
- G5 (5-fire stagnation escape): Task 10 ✓
- G6 (crash/resume safe marker dedupe): Task 2 (already_handed_off branch) + Task 3 Case 3 ✓
- AC1: Task 3 Case 1 ✓
- AC2: Task 3 Case 2 ✓ (4 required tokens)
- AC3: Task 3 Case 3 ✓ (TIMESTAMP preservation)
- AC4: Task 7 Cases 1/2 ✓
- AC5: Task 5 Cases 1/2/3/4/5 ✓
- AC6: Task 9 + Task 7 Case 3 ✓
- AC7: Task 3 Case 7 + Task 5 Case 7 + Task 7 Case 5 ✓
- AC8: Task 7 Case 4 ✓
- AC9: Task 14 + Task 15 + Task 19 Step 4 ✓
- AC10: Task 3 (full rewrite covers Cases 1/5/7 → AC1/AC2/AC3 + new tests) ✓
- C1 (scope to plugin + 1-line CLAUDE.md): Task 18 ✓
- C2 (kill switches): all hooks + script ✓
- C3 (version bump + CHANGELOG): Tasks 14/15 ✓
- C4 (GC duty): Task 13 ✓
- C5 (no secrets in marker): Task 2 (only STATUS/TIMESTAMP/FIRE_COUNT/SPEC_PATH) ✓
- C6 (README Principles): Task 16 ✓
- OQ2 (edge case scope — ASCII-only `/compact`, no fullwidth `／`): Task 5/6 ASCII-only test cases. (No regex extension — first-cut deferral noted in spec.)

**2. Placeholder scan:** No "TBD"/"TODO"/"add appropriate error handling" patterns in plan. All code blocks complete.

**3. Type consistency:**
- `HANDOFF_STATUS_ALREADY_DONE` / `HANDOFF_STATUS_DIRTY_BLOCKED` / `HANDOFF_STATUS_EMITTED` — same names across Tasks 1/2/3/15.
- `.handoff-status` file format: `STATUS=` / `TIMESTAMP=` / `FIRE_COUNT=` / `SPEC_PATH=` — same fields across Tasks 2/7/8/13/15.
- Marker path `.claude/spec-distill/.markers/<sid>.emitted` — same across all tasks.
- Hook payload keys `prompt`/`user_message` (compact-detect) and `session_id` (both hooks) — consistent.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-27-spec-distill-handoff-idempotency.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
