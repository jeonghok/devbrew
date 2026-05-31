# quality-gates v2.2.0 — runtime-verifier Sandbox-Executor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform qg's `runtime-verifier` from a read-only "does it run + screenshot" observer into a sandbox-executor that runs the service in a disposable git-worktree, drives real user flows, and asserts behavior against spec Acceptance Criteria — while a pure-git mutation guard structurally blocks Law 2 self-approval and operational systems are never touched.

**Architecture:** The orchestrator SKILL seals the code-under-review into an **immutable baseline commit `B`** inside a throwaway git worktree (`qg-worktree.sh create-sandbox`). The verifier (now `model: inherit`, with `Write`/`Edit` + browser-interaction tools) runs *inside that sandbox*. At gate end, `qg-worktree.sh mutation-guard <sandbox> <B>` computes — purely from git, independent of the verifier's self-judgment — whether any product file changed; a non-empty result forces the verdict to ≤FAIL and the sandbox is discarded. Operational safety comes from never copying git-ignored files (prod `.env`) into the sandbox plus a `detect-runtime.sh` blast-radius classifier that gates process-start/network/destructive surfaces behind a one-time upfront Execution Plan.

**Tech Stack:** Bash (3.2-compatible, macOS + Linux), git worktrees, Python 3 (pytest behavioral stubs), Markdown agent/skill personas, chrome-devtools MCP.

---

## Pre-work context for the implementer

- **Spec:** `docs/superpowers/specs/2026-05-31-qg-runtime-verifier-sandbox-executor-design.md` — read §6.3 (sandbox lifecycle), §6.7 (mutation guard), §6.8 (operational safety) before Task 2/3/5.
- **Branch:** Work on `feature/qg-sandbox-executor` (already checked out; spec committed as `540373b` + `17be93e`).
- **cwd contract:** qg tests run from the **repo root** (`/Users/jeonghokim/Downloads/devbrew`). Bash test scripts compute paths relative to their own location; Python tests are invoked as `python3 plugins/quality-gates/tests/<file>.py` or `pytest plugins/quality-gates/tests/<file>.py` from repo root.
- **Baseline reds:** qg has **no CI** and `main` carries pre-existing stale-red tests (codex/consent/security/sandbox families). Per project memory `project_qg_pre_existing_test_reds`, capture a baseline before editing and judge ONLY new/changed tests for green. Task 0 does this.
- **Version-bump law:** every PR touching `plugins/quality-gates/` MUST bump `plugin.json` `version` in the same change (cache key). This plan bumps `2.1.0 → 2.2.0` in Task 6.
- **Security-sensitive:** `agents/runtime-verifier.md` is a persona file — treat its edits with test-suite-level care (CLAUDE.md "Persona 파일은 보안-민감 코드").

---

## File Structure

**Modified scripts (deterministic core — fully unit-testable):**
- `plugins/quality-gates/scripts/detect-runtime.sh` — adds blast-radius `requires_decision` classification (Task 1).
- `plugins/quality-gates/scripts/qg-worktree.sh` — adds `create-sandbox` + `mutation-guard` subcommands (Tasks 2, 3).
- `plugins/quality-gates/scripts/check-allowed-tools-order.sh` — adds the new Bash allowlist entry to its canonical `EXPECTED_ORDER` array (Task 5; coupled with SKILL.md frontmatter).

**Modified personas / orchestration (LLM-facing — static protocol-shape tested):**
- `plugins/quality-gates/agents/runtime-verifier.md` — frontmatter + body rewrite (Task 4).
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Upfront Execution Plan, sandbox wiring, AC thread, guard call, blocked-path routing, cost heads-up, version (Task 5).

**Metadata / docs:**
- `plugins/quality-gates/.claude-plugin/plugin.json` — `2.2.0` (Task 6).
- `plugins/quality-gates/CHANGELOG.md` — `[2.2.0]` Added/Changed/Security (Task 6).
- `plugins/quality-gates/tests/e2e-scenarios.md` — stale agent-table line (Task 6).
- `plugins/quality-gates/README.md` — Law 2 bullet rewrite + new principle bullets + model/table update (Task 7).
- `docs/philosophy/devbrew-harness-philosophy.md` + `CLAUDE.md` — git-diff-guard scoped-exception note + TOC sync (Task 8).

**New / extended tests + fixtures:**
- `tests/test_detect_runtime.sh` (extend, Task 1) + `tests/fixtures/gate3/cli-tool/`, `tests/fixtures/gate3/danger-signal/` (new fixtures, Task 1).
- `tests/test_qg_runtime_sandbox.sh` (new, Task 2) — sandbox reflection/byte-faithfulness/ignored-exclusion/kill-switch.
- `tests/test_qg_mutation_guard.sh` (new, Task 3) — guard verdict + independence.
- `tests/test_runtime_verifier_frontmatter.sh` (rewrite, Task 4) + `tests/test_runtime_verifier_behavior.py` (extend, Task 4).
- `tests/harness/test_skill_orchestration_behavior.sh` (extend, Task 5) — sandbox/guard/upfront-plan protocol-shape.

---

## Task 0: Baseline capture (no code change)

**Files:** none modified — capture only.

- [ ] **Step 1: Capture the current test baseline**

Run from repo root and save the output so post-change regression judgment is differential, not absolute (qg has stale main reds; project memory `project_qg_pre_existing_test_reds`):

```bash
cd /Users/jeonghokim/Downloads/devbrew
mkdir -p "${CLAUDE_JOB_DIR:-/tmp}/qg-baseline"
for t in plugins/quality-gates/tests/test_detect_runtime.sh \
         plugins/quality-gates/tests/test_qg_worktree_helper.sh \
         plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh \
         plugins/quality-gates/tests/test_check_allowed_tools_order.sh \
         plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh; do
  echo "=== $t ===" ; bash "$t" >/dev/null 2>&1 && echo "GREEN" || echo "RED"
done | tee "${CLAUDE_JOB_DIR:-/tmp}/qg-baseline/baseline.txt"
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh >/dev/null 2>&1 && echo "orchestration GREEN" || echo "orchestration RED"
python3 -m pytest plugins/quality-gates/tests/test_runtime_verifier_behavior.py -q 2>&1 | tail -3
```

Expected: the five bash tests and orchestration are GREEN today (they pass on `main` per the read). Record any RED here so a *pre-existing* red is never attributed to this work.

- [ ] **Step 2: Confirm branch**

Run: `git -C /Users/jeonghokim/Downloads/devbrew branch --show-current`
Expected: `feature/qg-sandbox-executor`. If not, `git checkout feature/qg-sandbox-executor`.

No commit for this task.

---

## Task 1: `detect-runtime.sh` blast-radius classification (AC2, AC5-classification)

**Files:**
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh`
- Create: `plugins/quality-gates/tests/fixtures/gate3/cli-tool/pyproject.toml`
- Create: `plugins/quality-gates/tests/fixtures/gate3/danger-signal/package.json`
- Test: `plugins/quality-gates/tests/test_detect_runtime.sh` (extend)

**What changes:** Process-start kinds (`npm-script` dev/start/serve, `cargo-run`, `go-run`, `makefile` run/serve) gain `requires_decision: true`. Test-runner kinds (`pytest`, `npm-script:test`, `cargo-test`, `go-test`, `makefile:test`) stay automatic (no `requires_decision` line). Any surface whose underlying command string matches a danger signal (`curl|wget|ssh|scp|deploy|kubectl|terraform|rm -rf|git push|npm publish|docker push|--force`) is escalated to `requires_decision: true` even if its kind is normally automatic. `docker-compose` keeps its existing `requires_decision: true`.

- [ ] **Step 1: Create the two new fixtures**

Create `plugins/quality-gates/tests/fixtures/gate3/cli-tool/pyproject.toml`:

```toml
[project]
name = "fixture-cli-tool"
version = "0.1.0"

[project.scripts]
mycli = "mycli:main"
```

Create `plugins/quality-gates/tests/fixtures/gate3/danger-signal/package.json` (a `test` script — normally automatic — that secretly hits the network, so it MUST escalate):

```json
{
  "name": "fixture-danger-signal",
  "scripts": {
    "test": "curl -s https://example.com/telemetry && echo ok",
    "build": "echo build"
  }
}
```

- [ ] **Step 2: Write the failing test additions**

Append the following block to `plugins/quality-gates/tests/test_detect_runtime.sh` immediately before the final `echo ""` / `echo "Tests passed…"` summary (lines 164-166). It adds a per-surface YAML block extractor and AC2/AC5 assertions:

```bash
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
test_block=$(get_surface_block "$OUT" "name: test")
assert_contains "$dev_block" "requires_decision: true" "T8: npm:dev requires_decision"
assert_not_contains "$test_block" "requires_decision" "T8: npm:test stays automatic"

# docker-compose keeps its existing requires_decision
dc_block=$(get_surface_block "$OUT" "kind: docker-compose")
assert_contains "$dc_block" "requires_decision: true" "T8: docker-compose requires_decision (unchanged)"

# --- Test 9: test runners stay automatic (AC2) ---
echo "== Test 9: test runner automatic =="
OUT=$(run_detector "library-tests")
pytest_block=$(get_surface_block "$OUT" "kind: pytest")
assert_not_contains "$pytest_block" "requires_decision" "T9: pytest automatic (no gate)"

# --- Test 10: danger-signal escalates an otherwise-automatic surface (AC5) ---
echo "== Test 10: danger-signal escalation =="
OUT=$(run_detector "danger-signal")
sig_test_block=$(get_surface_block "$OUT" "name: test")
assert_contains "$sig_test_block" "requires_decision: true" "T10: network-signal test script escalated"

# --- Test 11: CLI-tool fixture detected as cli project ---
echo "== Test 11: cli-tool fixture =="
OUT=$(run_detector "cli-tool")
RC=$?
assert_eq "$RC" "0" "T11: exit 0"
assert_contains "$OUT" "project_type: cli" "T11: project_type=cli"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`
Expected: FAIL — `T8: npm:dev requires_decision` and `T10` fail because `detect-runtime.sh` does not yet emit `requires_decision` on npm/process-start/signal surfaces. (T9, T11 may pass already.)

- [ ] **Step 4: Implement blast-radius classification in `detect-runtime.sh`**

First, add a danger-signal helper after the `emit()` helper (after line 47). Insert:

```bash
# Returns 0 if the supplied string contains a network/deploy/destructive signal.
# Used to escalate an otherwise-automatic surface to requires_decision.
has_danger_signal() {
  printf '%s' "$1" | grep -qiE 'curl|wget|(^|[^a-z])ssh([^a-z]|$)|scp|rsync|deploy|kubectl|terraform|rm[[:space:]]+-rf|git[[:space:]]+push|npm[[:space:]]+publish|docker[[:space:]]+push|--force'
}
```

Then replace the **npm-scripts** block (lines 98-108) with a version that classifies each script:

```bash
# npm-scripts: dev / start / serve / test (each as its own surface).
# Process-start scripts (dev/start/serve) and any script whose command body
# carries a danger signal require an upfront decision (blast-radius gate).
if [[ -f package.json ]]; then
  for script in dev start serve test; do
    if grep -qE "\"$script\"[[:space:]]*:" package.json 2>/dev/null; then
      rd="false"
      case "$script" in
        dev|start|serve) rd="true" ;;
      esac
      script_line=$(grep -E "\"$script\"[[:space:]]*:" package.json 2>/dev/null | head -1)
      has_danger_signal "$script_line" && rd="true"
      block="$(printf '  - kind: npm-script\n    name: %s\n    command: npm run %s' "$script" "$script")"
      [[ "$rd" == "true" ]] && block="$block$(printf '\n    requires_decision: true')"
      SURFACES+=("$block")
      if [[ "$script" == "test" ]]; then
        add_test_runner "npm"
      fi
    fi
  done
fi
```

Replace the **cargo** block (lines 119-126) so `cargo-run` gates:

```bash
# cargo (test automatic + run gated)
if [[ -f Cargo.toml ]]; then
  SURFACES+=("$(printf '  - kind: cargo-test\n    command: cargo test')")
  add_test_runner "cargo"
  if grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    SURFACES+=("$(printf '  - kind: cargo-run\n    command: cargo run\n    requires_decision: true')")
  fi
fi
```

Replace the **go** block (lines 128-136) so `go-run` gates:

```bash
# go (test automatic + run gated)
if [[ -f go.mod ]]; then
  SURFACES+=("$(printf '  - kind: go-test\n    command: go test ./...')")
  add_test_runner "go"
  if find . -maxdepth 2 -name 'main.go' 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: go-run\n    command: go run ./...\n    requires_decision: true')")
  fi
fi
```

Replace the **Makefile** block (lines 138-148) so run/serve gate, test stays automatic unless its recipe carries a danger signal:

```bash
# Makefile targets (run/serve gated; test automatic unless danger recipe)
if [[ -f Makefile ]]; then
  for target in run serve test; do
    if grep -qE "^${target}:" Makefile 2>/dev/null; then
      rd="false"
      case "$target" in
        run|serve) rd="true" ;;
      esac
      # Scan the target's recipe block for danger signals.
      recipe=$(awk -v t="^${target}:" '
        $0 ~ t { inblk=1; next }
        inblk && /^[^[:space:]]/ { inblk=0 }
        inblk { print }
      ' Makefile 2>/dev/null)
      has_danger_signal "$recipe" && rd="true"
      block="$(printf '  - kind: makefile\n    target: %s\n    command: make %s' "$target" "$target")"
      [[ "$rd" == "true" ]] && block="$block$(printf '\n    requires_decision: true')"
      SURFACES+=("$block")
      if [[ "$target" == "test" ]]; then
        add_test_runner "make"
      fi
    fi
  done
fi
```

Also update the script's header doc comment (the per-kind schema list, lines 26-34) so the schema notes match: add `requires_decision` to the npm-script / cargo-run / go-run / makefile lines. Replace lines 27-34 with:

```bash
#   docker-compose   — {kind, path, requires_decision}
#   npm-script       — {kind, name ∈ {dev,start,serve,test}, command, requires_decision?}
#   pytest           — {kind, command}
#   cargo-test       — {kind, command}
#   cargo-run        — {kind, command, requires_decision}  (only when Cargo.toml has [[bin]])
#   go-test          — {kind, command}
#   go-run           — {kind, command, requires_decision}  (only when main.go found)
#   makefile         — {kind, target ∈ {run,serve,test}, command, requires_decision?}
#
# Blast-radius rule: process-start kinds (dev/start/serve/run/serve) and any
# surface whose command body matches a network/deploy/destructive signal carry
# requires_decision: true. Test-runner kinds are automatic (no requires_decision).
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`
Expected: PASS — `Tests passed: N, failed: 0`. The original Tests 1-7 still pass (they never asserted absence of `requires_decision` on npm, and `assert_contains "$OUT" "kind: npm-script"` etc. remain true).

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/detect-runtime.sh \
        plugins/quality-gates/tests/test_detect_runtime.sh \
        plugins/quality-gates/tests/fixtures/gate3/cli-tool \
        plugins/quality-gates/tests/fixtures/gate3/danger-signal
git commit -m "feat(quality-gates): blast-radius requires_decision in detect-runtime (AC2)"
```

---

## Task 2: `qg-worktree.sh create-sandbox` subcommand (AC3, AC5-exclusion, AC12)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Test: `plugins/quality-gates/tests/test_qg_runtime_sandbox.sh` (new)

**What it does:** `create-sandbox <session-id>` creates a detached git worktree at `.claude/quality-gates/worktrees/rt-<sid_short>` from `HEAD`, overlays the **main working-tree state byte-faithfully** (tracked content + untracked-not-ignored; honoring deletions; preserving mode/symlink/binary; **never copying git-ignored files**), then seals an immutable baseline commit `B`. Output contract: **line 1 = sandbox abs path, line 2 = baseline SHA**. Kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` → exit 3 + loud stderr.

- [ ] **Step 1: Write the failing test**

Create `plugins/quality-gates/tests/test_qg_runtime_sandbox.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for qg-worktree.sh create-sandbox subcommand.
# Validates: working-tree reflection, byte-faithful copy (binary/mode/symlink),
# git-ignored exclusion (operational safety), deletion honoring, kill switch.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# --- Build a realistic repo with committed + uncommitted + ignored state ---
mk_repo() {
  local r; r=$(mktemp -d)
  (cd "$r" && git init -q -b main && git config user.email t@t && git config user.name t)
  # committed tracked files
  printf 'orig\n' > "$r/tracked.txt"
  printf 'console.log(1)\n' > "$r/src_app.js"
  mkdir -p "$r/src"
  printf 'v1\n' > "$r/src/mod.js"
  printf 'node_modules/\n.env\n' > "$r/.gitignore"
  (cd "$r" && git add -A && git commit -q -m init)
  # uncommitted modification to a tracked file
  printf 'orig\nMODIFIED\n' > "$r/tracked.txt"
  # new untracked-but-not-ignored file (code under review)
  printf 'NEW SOURCE\n' > "$r/src/newfix.js"
  # git-ignored prod secret — MUST NOT be copied into the sandbox
  printf 'DB_URL=postgres://prod/secret\n' > "$r/.env"
  mkdir -p "$r/node_modules/x" && printf 'dep\n' > "$r/node_modules/x/i.js"
  echo "$r"
}

echo "[create-sandbox: reflection + exclusion]"
REPO=$(mk_repo)
SID="sandbox01234567"
OUT=$(cd "$REPO" && "$WT" create-sandbox "$SID" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
BASE=$(printf '%s\n' "$OUT" | sed -n '2p')

[ -d "$SANDBOX" ] && pass "sandbox dir created" || fail "no sandbox: '$SANDBOX'"
[ -n "$BASE" ] && pass "baseline SHA emitted" || fail "no baseline SHA"

# uncommitted modification reflected
grep -q "MODIFIED" "$SANDBOX/tracked.txt" 2>/dev/null \
  && pass "uncommitted modification reflected" || fail "modification missing"
# untracked-not-ignored new file reflected
[ -f "$SANDBOX/src/newfix.js" ] && pass "untracked-not-ignored copied" \
  || fail "newfix.js missing"
# git-ignored prod .env NOT copied (operational safety, §6.3c / AC5)
[ ! -f "$SANDBOX/.env" ] && pass "git-ignored .env NOT copied" \
  || fail "prod .env leaked into sandbox"
# git-ignored node_modules NOT copied
[ ! -e "$SANDBOX/node_modules" ] && pass "git-ignored node_modules NOT copied" \
  || fail "node_modules leaked"
# baseline B is a real commit and working tree is clean against it
( cd "$SANDBOX" && git cat-file -e "$BASE^{commit}" 2>/dev/null ) \
  && pass "baseline B is a commit" || fail "B not a commit"
clean=$(cd "$SANDBOX" && git status --porcelain 2>/dev/null)
[ -z "$clean" ] && pass "sandbox clean at baseline B" || fail "sandbox dirty after seal: $clean"
rm -rf "$REPO"

echo "[create-sandbox: byte-faithful binary / mode / symlink]"
REPO=$(mk_repo)
# binary change
printf '\x00\x01\x02BIN\xff' > "$REPO/blob.bin"
# mode change on a tracked file (chmod +x)
chmod +x "$REPO/src_app.js"
# new symlink (untracked-not-ignored)
ln -s tracked.txt "$REPO/link_to_tracked"
OUT=$(cd "$REPO" && "$WT" create-sandbox "fidelity01234567" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
# binary content identical
if cmp -s "$REPO/blob.bin" "$SANDBOX/blob.bin"; then pass "binary byte-identical"; else fail "binary differs"; fi
# exec bit preserved
[ -x "$SANDBOX/src_app.js" ] && pass "mode (chmod +x) preserved" || fail "exec bit lost"
# symlink preserved as a symlink
[ -L "$SANDBOX/link_to_tracked" ] && pass "symlink preserved as symlink" \
  || fail "symlink not preserved"
rm -rf "$REPO"

echo "[create-sandbox: deletion honored]"
REPO=$(mk_repo)
rm "$REPO/src/mod.js"   # delete a tracked file in the working tree
OUT=$(cd "$REPO" && "$WT" create-sandbox "deletion01234567" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ ! -f "$SANDBOX/src/mod.js" ] && pass "tracked deletion honored in sandbox" \
  || fail "deleted file survived in sandbox"
rm -rf "$REPO"

echo "[create-sandbox: kill switch]"
REPO=$(mk_repo)
( cd "$REPO" && DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 "$WT" create-sandbox "kill01234567" 2>/dev/null )
rc=$?
[ "$rc" -eq 3 ] && pass "kill switch → exit 3" || fail "kill switch exit was $rc (want 3)"
rm -rf "$REPO"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

Make it executable in the same step: `chmod +x plugins/quality-gates/tests/test_qg_runtime_sandbox.sh`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh`
Expected: FAIL — `unknown subcommand: create-sandbox` (the `die` path), so most assertions fail.

- [ ] **Step 3: Implement `create-sandbox` in `qg-worktree.sh`**

Add a new `case` branch. Insert it **before** the `remove)` branch (i.e. after the `create)` branch closes at line 68, before line 69 `remove)`):

```bash
  create-sandbox)
    # Disposable git worktree reflecting the main working tree (code-under-
    # review), sealed into an immutable baseline commit B. §6.3 of the spec.
    [[ $# -eq 2 ]] || die "usage: create-sandbox <session-id>"
    if [[ "${DEVBREW_QG_DISABLE_RUNTIME_SANDBOX:-0}" == "1" ]]; then
      echo "qg-worktree: runtime sandbox disabled via DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 — orchestrator must fall back to read-only smoke mode" >&2
      exit 3   # distinct from die's exit 2 → SKILL branches on this
    fi
    sid="$2"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
    main_root=$(cd "$main_root" && pwd -P)
    parent="$main_root/.claude/quality-gates/worktrees"
    mkdir -p "$parent" || die "cannot create $parent"
    sandbox="$parent/rt-${sid_short}"

    # Idempotent: clear any stale sandbox so a fresh baseline can't inherit
    # prior-run state.
    git worktree prune >/dev/null 2>&1 || true
    if [[ -e "$sandbox" ]]; then
      git worktree remove --force "$sandbox" >/dev/null 2>&1 || rm -rf "$sandbox"
      git worktree prune >/dev/null 2>&1 || true
    fi
    git worktree add --detach "$sandbox" HEAD >/dev/null 2>&1 \
      || die "git worktree add failed (sandbox: $sandbox)"

    # Overlay the main working-tree state, byte-faithfully, EXCLUDING
    # git-ignored files (prod .env / deps / build — §6.3c operational safety).
    # Per-file `cp -a` loop is the portable choice: rsync --ignore-missing-args
    # and tar --null are unreliable across macOS bsdtar / old rsync.
    tmp_list=$(mktemp) || die "mktemp failed"
    {
      git -C "$main_root" ls-files -z                          # tracked (any state)
      git -C "$main_root" ls-files --others --exclude-standard -z  # untracked, not ignored
    } > "$tmp_list"
    while IFS= read -r -d '' rel; do
      [[ -z "$rel" ]] && continue
      case "$rel" in
        .claude/quality-gates/worktrees/*) continue ;;  # never copy a sandbox into itself
      esac
      src="$main_root/$rel"
      if [[ -e "$src" || -L "$src" ]]; then
        mkdir -p "$sandbox/$(dirname "$rel")"
        rm -rf "$sandbox/$rel"          # make type-change (file→symlink) faithful
        cp -a "$src" "$sandbox/$rel"    # -a preserves mode, symlink, binary
      fi
    done < "$tmp_list"
    rm -f "$tmp_list"

    # Honor deletions: a tracked file deleted in the working tree must not
    # survive in the sealed baseline.
    while IFS= read -r -d '' rel; do
      rm -f "$sandbox/$rel"
    done < <(git -C "$main_root" ls-files -d -z)

    # Seal the immutable baseline commit B. --no-verify skips any repo hooks;
    # -c identity makes the commit succeed even when git identity is unset.
    git -C "$sandbox" add -A >/dev/null 2>&1
    git -C "$sandbox" \
      -c user.email=qg-sandbox@devbrew.local -c user.name='qg sandbox' \
      -c commit.gpgsign=false \
      commit -q --no-verify --allow-empty -m "qg runtime sandbox baseline" \
      >/dev/null 2>&1 || die "baseline commit failed"
    base=$(git -C "$sandbox" rev-parse HEAD) || die "cannot read baseline SHA"

    # Output contract: line 1 = sandbox abs path, line 2 = baseline SHA.
    printf '%s\n%s\n' "$sandbox" "$base"
    ;;
```

Also extend the header doc comment (lines 4-8 subcommand list) to document the new subcommand. Add after the `remove <abs-path>` line:

```bash
#   create-sandbox <session-id> -> echoes 2 lines: sandbox abs path, baseline SHA
#                                  (disposable worktree mirroring the working tree,
#                                   git-ignored files excluded; sealed as commit B)
#   mutation-guard <sandbox> <B> -> echoes YAML: tracked_diff / disallowed_new_files /
#                                    forced_downgrade (pure git; see Task 3)
```

And add a line to the kill-switch doc (after line 15):

```bash
# Kill switch: DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 — `create-sandbox` exits 3
# (distinct from die's exit 2) so the orchestrator can fall back to read-only.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh`
Expected: PASS — `Result: N passed, 0 failed`.

- [ ] **Step 5: Confirm the existing worktree-helper test still passes (no regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: PASS — the existing `sanitize`/`validate-branch`/`create`/`remove` branches are untouched.

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/qg-worktree.sh \
        plugins/quality-gates/tests/test_qg_runtime_sandbox.sh
git commit -m "feat(quality-gates): qg-worktree create-sandbox (byte-faithful, ignored-excluded) (AC3/AC5/AC12)"
```

---

## Task 3: `qg-worktree.sh mutation-guard` subcommand (AC7 — the Law 2 structural guard)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Test: `plugins/quality-gates/tests/test_qg_mutation_guard.sh` (new)

**What it does:** `mutation-guard <sandbox> <baseline-sha>` computes — **purely from git, never reading any verifier output** — whether the verifier mutated product. Emits `tracked_diff` (net diff vs `B`, commit-agnostic), `disallowed_new_files` (new files that are NOT git-ignored, plus ALL new symlinks regardless of target), and `forced_downgrade: yes|no`. This is the structural authority over the verdict (§6.7).

- [ ] **Step 1: Write the failing test**

Create `plugins/quality-gates/tests/test_qg_mutation_guard.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for qg-worktree.sh mutation-guard subcommand (§6.7 / AC7).
# The guard is pure git: its verdict depends ONLY on (sandbox, baseline) —
# never on any verifier self-claim. That is the structural Law 2 defense.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

mk_sandbox() {
  # Build a repo, seal a sandbox via create-sandbox, echo "<sandbox>\n<base>".
  local r; r=$(mktemp -d)
  (cd "$r" && git init -q -b main && git config user.email t@t && git config user.name t)
  printf 'orig\n' > "$r/tracked.txt"
  printf 'node_modules/\n.env\n' > "$r/.gitignore"
  (cd "$r" && git add -A && git commit -q -m init)
  (cd "$r" && "$WT" create-sandbox "guard0123456789" 2>/dev/null)
}

field() { printf '%s\n' "$1" | awk -v k="$2" '$0 ~ "^" k ":" {print; exit}'; }

echo "[mutation-guard: clean sandbox → no downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "clean sandbox → forced_downgrade: no" || fail "clean misreported: $(field "$G" forced_downgrade)"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: tracked change → forced downgrade]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'orig\nHACKED TO PASS\n' > "$SANDBOX/tracked.txt"   # product source mutation
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "tracked change → forced_downgrade: yes" || fail "tracked change not caught"
printf '%s' "$G" | grep -q "tracked.txt" \
  && pass "changed file surfaced in tracked_diff" || fail "tracked.txt not surfaced"

echo "[mutation-guard: independence — verdict ignores any verifier claim]"
# The guard takes only (sandbox, base); there is no input channel for a
# verifier claim. Re-running on the SAME mutated sandbox must still say yes,
# proving the result is git-derived, not passthrough.
G2=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G2" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "independent re-run still forced_downgrade: yes" || fail "non-deterministic guard"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: git-ignored new file → non-product (no downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'DB_URL=local\n' > "$SANDBOX/.env"   # ignored — setup-only fix, PASS-able
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: no" ] \
  && pass "ignored new file → no downgrade (setup-only PASS path)" || fail "ignored file wrongly downgraded"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: non-ignored new file → product (downgrade)]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
printf 'export const fix = 1\n' > "$SANDBOX/newfix.js"   # NOT ignored → product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "non-ignored new file → forced_downgrade: yes" || fail "new product file not caught"
printf '%s' "$G" | grep -q "newfix.js" \
  && pass "new file in disallowed_new_files" || fail "newfix.js not surfaced"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo "[mutation-guard: new symlink → product regardless of ignore]"
OUT=$(mk_sandbox); SANDBOX=$(sed -n '1p' <<<"$OUT"); BASE=$(sed -n '2p' <<<"$OUT")
( cd "$SANDBOX" && ln -s /etc/hosts .env_link )   # name unlikely-ignored; symlink always product
G=$("$WT" mutation-guard "$SANDBOX" "$BASE" 2>/dev/null)
[ "$(field "$G" forced_downgrade)" = "forced_downgrade: yes" ] \
  && pass "new symlink → forced_downgrade: yes" || fail "new symlink not caught"
rm -rf "$(dirname "$SANDBOX")/../../.." 2>/dev/null

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

> Note on the `rm -rf "$(dirname "$SANDBOX")/../../.."` cleanup: the sandbox lives at `<repo>/.claude/quality-gates/worktrees/rt-xxx`, so three levels up from its parent reaches the temp repo root created by `mk_sandbox`. This is intentional best-effort cleanup of the throwaway temp repo; failure is harmless (temp dirs).

Make it executable: `chmod +x plugins/quality-gates/tests/test_qg_mutation_guard.sh`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: FAIL — `unknown subcommand: mutation-guard`.

- [ ] **Step 3: Implement `mutation-guard` in `qg-worktree.sh`**

Add this `case` branch immediately after the `create-sandbox)` branch from Task 2 (before `remove)`):

```bash
  mutation-guard)
    # Pure-git product-mutation oracle. Inputs are ONLY (sandbox, baseline B).
    # There is no channel for a verifier self-claim — that is the structural
    # Law 2 self-approval defense (§6.7). Authoritative over the verdict.
    [[ $# -eq 3 ]] || die "usage: mutation-guard <sandbox-abs> <baseline-sha>"
    sandbox="$2" base="$3"
    [[ -d "$sandbox" ]] || die "sandbox not found: $sandbox"
    git -C "$sandbox" cat-file -e "${base}^{commit}" 2>/dev/null \
      || die "bad baseline sha: $base"

    # (1) tracked net diff vs the immutable baseline B. Comparing B↔working-tree
    # is commit-agnostic: any intermediate `git commit` the verifier ran inside
    # the sandbox cannot hide a net change. Also fold in staged-vs-B (defensive).
    tracked=$(git -C "$sandbox" diff --name-only "$base" -- 2>/dev/null)
    tracked_cached=$(git -C "$sandbox" diff --name-only --cached "$base" -- 2>/dev/null)
    tracked_all=$(printf '%s\n%s\n' "$tracked" "$tracked_cached" | sed '/^$/d' | sort -u)

    # (2) new files (untracked relative to B's index). Classification:
    #   symlink  → always product-affecting (target-agnostic, conservative)
    #   ignored  → non-product (cannot normally enter product) → skip
    #   else     → product-affecting
    # NOTE: plain `--others` (NOT --exclude-standard) so ignored files appear
    # and we can classify them explicitly via check-ignore.
    disallowed=()
    while IFS= read -r -d '' rel; do
      [[ -z "$rel" ]] && continue
      if [[ -L "$sandbox/$rel" ]]; then
        disallowed+=("$rel"); continue
      fi
      if git -C "$sandbox" check-ignore -q -- "$rel" 2>/dev/null; then
        continue   # git-ignored → non-product
      fi
      disallowed+=("$rel")
    done < <(git -C "$sandbox" ls-files --others -z 2>/dev/null)

    forced="no"
    [[ -n "$tracked_all" ]] && forced="yes"
    [[ ${#disallowed[@]} -gt 0 ]] && forced="yes"

    if [[ -n "$tracked_all" ]]; then
      echo "tracked_diff:"
      while IFS= read -r f; do echo "  - $f"; done <<< "$tracked_all"
    else
      echo "tracked_diff: []"
    fi
    if [[ ${#disallowed[@]} -gt 0 ]]; then
      echo "disallowed_new_files:"
      for f in "${disallowed[@]}"; do echo "  - $f"; done
    else
      echo "disallowed_new_files: []"
    fi
    echo "forced_downgrade: $forced"
    ;;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_mutation_guard.sh`
Expected: PASS — `Result: N passed, 0 failed`.

- [ ] **Step 5: Re-run the create-sandbox test (shared file, no regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh && bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/scripts/qg-worktree.sh \
        plugins/quality-gates/tests/test_qg_mutation_guard.sh
git commit -m "feat(quality-gates): mutation-guard pure-git product-mutation oracle (AC7)"
```

---

## Task 4: `runtime-verifier.md` frontmatter + body rewrite (AC1, AC6, AC8-agent, AC13-cost)

**Files:**
- Modify: `plugins/quality-gates/agents/runtime-verifier.md`
- Test: `plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` (rewrite)
- Test: `plugins/quality-gates/tests/test_runtime_verifier_behavior.py` (extend)

- [ ] **Step 1: Rewrite the failing frontmatter test**

Replace the entire body of `plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` with:

```bash
#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter + body for the v2.2.0 sandbox-
# executor contract. The agent is now an executor: model inherit, Write/Edit
# in allowedTools, browser-interaction tools, NotebookEdit still denied, and
# the body declares the sandbox / no-commit / product-fix-forbidden contract.

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/runtime-verifier.md"
PASS=0
FAIL=0

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not in file)"
  fi
}
assert_nogrep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' unexpectedly present)"
  else
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  fi
}

# --- frontmatter ---
assert_grep "^model: inherit" "model is inherit (was sonnet)"
assert_grep "^cost_class: variable" "cost_class stays variable"
assert_grep "^allowedTools:" "allowedTools declared"
assert_grep "^disallowedTools:" "disallowedTools declared (not default-everything)"

# Write/Edit/MultiEdit now ALLOWED (sandbox executor)
assert_grep "^[[:space:]]+- Write([[:space:]]|$)" "Write present"
assert_grep "^[[:space:]]+- Edit([[:space:]]|$)" "Edit present"
assert_grep "^[[:space:]]+- MultiEdit([[:space:]]|$)" "MultiEdit present"

# NotebookEdit still DENIED (deny list non-empty, not default-everything)
assert_grep "^[[:space:]]+- NotebookEdit([[:space:]]|$)" "NotebookEdit still in disallowedTools"

# Write/Edit/MultiEdit must NOT appear in the disallowedTools section.
# Verify by extracting the disallowedTools block and grepping within it.
DISALLOWED_BLOCK=$(awk '
  /^disallowedTools:/ {indis=1; next}
  /^[a-zA-Z]/ {indis=0}
  indis {print}
' "$FILE")
if printf '%s' "$DISALLOWED_BLOCK" | grep -qE -- '- (Write|Edit|MultiEdit)\b'; then
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: Write/Edit/MultiEdit must NOT be in disallowedTools"
else
  PASS=$((PASS + 1)); echo "  PASS: Write/Edit/MultiEdit absent from disallowedTools"
fi

# Browser interaction tools present (subset; at least click + fill + type_text)
assert_grep "chrome-devtools__click" "chrome-devtools click tool"
assert_grep "chrome-devtools__fill" "chrome-devtools fill tool"
assert_grep "chrome-devtools__type_text" "chrome-devtools type_text tool"

# --- body contract ---
assert_grep "sandbox" "body references the sandbox"
assert_grep "functional_assertions" "evidence-log functional_assertions section"
assert_grep "ac_id" "functional assertions bind to ac_id"
assert_grep "mutation_guard" "body references orchestrator mutation_guard"
# Must forbid fixing product source to fabricate PASS
assert_grep "product" "body addresses product-source rule"
assert_grep "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`
Expected: FAIL — current frontmatter has `model: sonnet`, Write/Edit in disallowedTools, no interaction tools, no `functional_assertions`/`mutation_guard` in body.

- [ ] **Step 3: Rewrite `runtime-verifier.md` frontmatter**

Replace lines 1-23 (the frontmatter top through `disallowedTools` list) with:

```markdown
---
name: runtime-verifier
model: inherit
cost_class: variable
color: green
allowedTools:
  - Read
  - Bash
  - Grep
  - Glob
  - Write
  - Edit
  - MultiEdit
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__get_console_message
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__close_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__click
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill_form
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__type_text
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__hover
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__press_key
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script
disallowedTools:
  - NotebookEdit
```

> The interaction-tool names are taken verbatim from the deferred-tool list available in this environment (`mcp__plugin_chrome-devtools-mcp_chrome-devtools__click` etc.), satisfying spec §11's "confirm available subset". `evaluate_script` is included for DOM-state assertions; `drag`/`upload_file`/`handle_dialog` are intentionally omitted (not needed for AC flows, keep the surface minimal).

- [ ] **Step 4: Update the frontmatter `description` block**

Replace the `description:` block (current lines 24-45) with one that reflects the executor role:

```markdown
description: >
  Use this agent for runtime verification of applications as the Runtime gate of
  the quality-gates pipeline. It runs INSIDE a disposable git-worktree sandbox
  (project_dir = sandbox path) where it may freely Write/Edit and drive the
  browser to exercise real user flows, asserting behavior against the spec's
  Acceptance Criteria. It emits one of four verdicts (PASS / FAIL /
  SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION). Law 2 self-approval is blocked
  structurally by the orchestrator's git-diff mutation guard — not by tool
  denial — so any product-source change the agent makes is caught and forces
  the verdict to at most FAIL; the sandbox is discarded, nothing is committed.

  <example>Context: Runtime gate — manifest declares a web app + a spec with
  Acceptance Criteria for a login flow. The agent boots the app in the sandbox,
  fills and submits the login form, and asserts the post-login state against the
  AC, capturing screenshot + DOM snapshot + network status as evidence.
  user: "Verify the app behaves per the spec in the sandbox."
  assistant: "I'll boot the service in the sandbox, drive the login flow, and
  assert each Acceptance Criterion with evidence."</example>

  <example>Context: A surface needs a missing .env. The agent copies
  .env.example to .env IN THE SANDBOX (git-ignored → non-product), retries, and
  proceeds. If the app only boots after editing tracked source, the agent stops
  and emits FAIL with evidence — it never fabricates a green by patching product.
  user: "Run the runtime gate."
  assistant: "Setup-only fixes I apply in the sandbox; a product bug becomes FAIL
  with the offending diff surfaced as evidence."</example>
---
```

- [ ] **Step 5: Rewrite the body**

Replace the entire body (everything from line 48 `# Runtime Verifier Agent (Runtime gate)` to end of file) with:

````markdown
# Runtime Verifier Agent (Runtime gate — sandbox executor)

You are the Runtime Verifier — the Runtime gate of the quality-gates pipeline. You run **inside a disposable git-worktree sandbox** that mirrors the code under review. There you **boot the declared runnable surfaces, drive real user flows, and assert behavior against the spec's Acceptance Criteria**, producing an **evidence-log** and exactly one verdict.

**You are NOT responsible for, and MUST NOT:**
- **Fabricate a green by patching product source.** You may Write/Edit freely in the sandbox, but if booting the app or passing an AC requires changing *tracked* source (or adding a non-ignored new file), that is a **product bug → FAIL + evidence**, never a PASS. The orchestrator independently detects any product mutation via a git-diff guard against an immutable baseline; you cannot out-argue it.
- **Touch operational systems.** No production DB, network endpoint, deploy, or external mutation. The sandbox excludes git-ignored prod config (`.env`) by design; if a surface can only run against prod credentials/endpoints, do NOT run it — record `blocked-for-safety`.
- Judge plan completeness, review code quality, or re-classify test scope — those belong to test-scope-validator and the Review gate.

## Input

The skill dispatches you with a prompt containing:

- `project_dir`: **the sandbox path** (absolute) — the single coordinate, frozen by the SKILL. NEVER re-derive (`git rev-parse`, `Path.cwd()`, `pwd` all forbidden).
- `plan_path`: path to plan file (or `auto`).
- `spec_acceptance_criteria`: a structured list of `{ac_id, text}` extracted from the project spec (may be empty — then use the fallback chain below).
- **Manifest** — YAML from `scripts/detect-runtime.sh`. Read verbatim; do NOT re-detect. Surfaces carry `requires_decision` flags.
- `approved_surfaces`: the surfaces the user opted into in the upfront Execution Plan. Only run `requires_decision` surfaces that appear here.
- `block_policy`: `stop` | `skip` | `ask` — what to do when a surface is blocked after setup retries are exhausted.
- `iteration`: 0-based resolution iteration counter.
- `previous_evidence_log_path`: present only when `iteration > 0`.

## Hard Rules

1. **Product source is sacred.** Setup-only fixes that touch ONLY git-ignored files (e.g. `cp .env.example .env`, installing deps) are allowed in the sandbox and can lead to PASS. Any change to tracked source, or any new non-ignored file, or any new symlink, makes PASS impossible — emit FAIL with the offending change described as evidence. Do not `git commit` to try to hide it; the guard compares against an immutable baseline and the sandbox is discarded regardless.
2. **Operational safety first.** Never run a surface that requires production credentials/endpoints. Prefer `.env.example` / `.env.test`. A `requires_decision` surface runs ONLY if it is in `approved_surfaces`.
3. **Bounded setup auto-fix.** For setup-fixable blocks (missing `.env`, missing deps), auto-fix and retry **at most 3 times per dispatch**. On exhaustion, emit `NEEDS_RESOLUTION` and let the SKILL apply `block_policy`.
4. **Attempt every surface; per-surface isolation.** One blocked surface does not abort the others. Attempt all, then aggregate.
5. **Evidence-grounded assertions.** Every functional PASS must cite concrete evidence (screenshot path + DOM-snapshot text + network status, or for CLI: command + stdout + exit code). No evidence → not a PASS.
6. **No secrets in output.** Never echo secret values into the evidence-log or any `needed` block; reference paths/decisions only (P21).
7. **Do not re-resolve cwd** — use `project_dir` (the sandbox) verbatim.

## Step 1: Parse inputs

Read the manifest YAML and the `spec_acceptance_criteria` list. Extract `project_type`, `runnable_surfaces` (with `requires_decision`), `test_runners`, `mcp_browser`, `app_url_candidates`, `env_status`, `plan_features`, `attempted_log_path`. If `iteration > 0`, Read `previous_evidence_log_path` first and skip surfaces already `attempted=ok`.

## Step 2: Boot surfaces and drive flows

For each surface in `runnable_surfaces`:

- If it carries `requires_decision: true` and is NOT in `approved_surfaces` → record `needs-decision`, do not run.
- If it requires prod config/endpoints → record `blocked-for-safety`, do not run.
- Otherwise boot it (test runners run directly; process-start surfaces with `run_in_background`).

Then derive flows. **Assertion-basis fallback chain (log which mode, loudly):**
- `spec_acceptance_criteria` present → for each *testable* AC, reason out a concrete flow and assert the expected result.
- else `plan_features` present → exercise those routes/labels (the older crude path).
- else → no functional assertion; smoke-test only (boot + console-error check). Log `functional-mode: smoke (no spec, no plan_features)`.

For **web** flows (per `mcp_browser`): navigate → interact (`click`/`fill`/`fill_form`/`type_text`/`hover`/`press_key`) → assert the expected DOM/network result. Capture screenshot to `.claude/quality-gates/<sid>/screenshots/<surface>.png`, a DOM snapshot, and the network status.

For **CLI** flows: run the command, capture stdout/stderr/exit-code, and assert against the AC text with `grep`.

**Always stop background processes** (`docker compose down`, kill node) when finished, regardless of verdict.

## Step 3: Write the evidence-log

Write to `manifest.attempted_log_path` using a Bash heredoc (the log lives under `.claude/quality-gates/<sid>/`, scratch — not project source). Include these sections:

```markdown
# Runtime gate Evidence Log — iteration N

## Attempts
- kind: npm-script | name: dev
  attempted: yes
  outcome: started
  url_probed: http://localhost:3000
  console_errors: 0

## writes
# Advisory self-report ONLY. The orchestrator's mutation_guard is authoritative.
- path: .env
  class: non-product        # git-ignored setup fix
  committed: never
- path: src/app.js
  class: product            # if you (wrongly) had to touch this, it is a FAIL
  committed: never

## functional_assertions
- ac_id: AC1
  flow: "navigate /login → fill #email,#password → click submit"
  expected: "redirect to /dashboard, greeting shows user name"
  observed: "redirected to /dashboard; greeting 'Hello, Dana'"
  evidence_refs:
    - .claude/quality-gates/<sid>/screenshots/login.png
    - "network: POST /api/login → 200"
  verdict: PASS
```

Every `runnable_surface` MUST have an `## Attempts` entry. When `spec_acceptance_criteria` is non-empty, there MUST be at least one `functional_assertions` entry binding an `ac_id` to a flow and `evidence_refs`. The `mutation_guard` section is **owned and written by the orchestrator**, not by you — do not fabricate it.

## Step 4: Emit verdict

| Verdict | Condition |
|---|---|
| `PASS` | Every attempted surface booted; every asserted AC observed == expected with evidence; `console_errors == 0`; only non-product (git-ignored) writes. |
| `FAIL` | An AC failed (form rendered but behavior wrong), OR booting required a product-source change, OR an unrecoverable boot failure (`resolvable: no`). Attach expected-vs-observed evidence and, when product change was attempted, describe the offending diff. |
| `SKIP_WITH_EVIDENCE` | Zero runnable_surfaces / zero test_runners / zero functional basis (degenerate), OR a surface was `blocked-for-safety` / `needs-decision` and `block_policy` resolved to skip. |
| `NEEDS_RESOLUTION` | A setup-fixable block remains after ≤3 retries. |

**Precedence:** if both `FAIL` and `NEEDS_RESOLUTION` match, choose `NEEDS_RESOLUTION` (give the user a chance to unblock). Product-bug FAIL is terminal — never downgrade a product bug to NEEDS_RESOLUTION just to retry.

Output the verdict block in this exact shape at the end of your message:

```
## Runtime Verification Report (Runtime gate, iter N)

**Manifest:** [summary]
**Mode:** [spec-AC | plan-feature | smoke]
**Attempts:** [N total, M booted, K failed, L blocked]
**Evidence Log:** [path]

### Verdict: [PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION]
```

For `NEEDS_RESOLUTION` ONLY, append:

```yaml
needed:
  - kind: <missing-env-var | missing-deps | ...>
    description: "<actionable, decision-form. Never request secret values.>"
    actions:
      - retry
      - skip_surface
      - abort
needed_hash: "<sha256 of sorted concatenated needed.kind values>"
```

Compute `needed_hash` portably:

```bash
HASH=$(printf '%s\n' "${kinds[@]}" | sort | { command -v sha256sum >/dev/null && sha256sum || shasum -a 256; } | cut -d' ' -f1)
```

The skill compares this against the previous iteration's hash; identical hashes for two consecutive NEEDS_RESOLUTION emits trigger `runtime_repeat_detected`.

## Notes

- If `mcp_browser: none`, record browser steps as `attempted: no, reason: "MCP unavailable"`; PASS is still possible if all other surfaces succeeded and any spec AC could be asserted without the browser (e.g. CLI).
- For `requires_decision: true` surfaces NOT in `approved_surfaces`, do not run — the user did not opt in during the upfront Execution Plan.
- Be specific. The orchestrator validates that every manifest surface has an entry; missing entries escalate SKIP→FAIL.
````

- [ ] **Step 6: Run the frontmatter test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`
Expected: PASS.

- [ ] **Step 7: Extend the behavior test**

Replace the `RUNTIME_VERIFIER_FROZEN` constant and add a new test in `plugins/quality-gates/tests/test_runtime_verifier_behavior.py`. Replace lines 16-23 (the frozen constant) with:

```python
RUNTIME_VERIFIER_FROZEN = """
verdict: PASS
evidence_log:
  - surface: npm-script:dev
    result: started; /login flow asserted
writes:
  - path: .env
    class: non-product
    committed: never
functional_assertions:
  - ac_id: AC1
    flow: "navigate /login → submit → expect /dashboard"
    expected: "redirect to /dashboard"
    observed: "redirected to /dashboard"
    evidence_refs:
      - screenshots/login.png
    verdict: PASS
"""
```

Then add this test function after `test_AC47_runtime_verifier_invalid_yaml_raises` (end of file):

```python
def test_v220_runtime_verifier_functional_assertions_schema():
    """v2.2.0: executor output carries functional_assertions bound to ac_id."""
    parsed = run_agent_stub("runtime-verifier", "p", RUNTIME_VERIFIER_FROZEN)
    assert_yaml_schema(
        parsed,
        required_keys=["verdict", "evidence_log", "functional_assertions"],
    )
    fa = parsed["functional_assertions"]
    assert isinstance(fa, list) and len(fa) >= 1, "functional_assertions must be a non-empty list"
    entry = fa[0]
    for k in ("ac_id", "flow", "expected", "observed", "evidence_refs", "verdict"):
        assert k in entry, f"functional_assertions entry missing '{k}'"
```

- [ ] **Step 8: Run the behavior test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m pytest plugins/quality-gates/tests/test_runtime_verifier_behavior.py -q`
Expected: PASS (4 tests). The original three still pass (the frozen output keeps `verdict` + `evidence_log`).

- [ ] **Step 9: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/agents/runtime-verifier.md \
        plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh \
        plugins/quality-gates/tests/test_runtime_verifier_behavior.py
git commit -m "feat(quality-gates): runtime-verifier sandbox-executor persona (model inherit, AC1/AC6/AC8/AC13)"
```

---

## Task 5: `SKILL.md` orchestration rewrite + allowlist linter (AC4, AC7-wiring, AC8-SKILL, AC9, AC12-fallback, AC13-headsup)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Modify: `plugins/quality-gates/scripts/check-allowed-tools-order.sh` (coupled — canonical allowlist)
- Test: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (extend)

> **Coupling warning:** `check-allowed-tools-order.sh` holds the canonical allowlist in `EXPECTED_ORDER`, and `test_check_allowed_tools_order.sh` + `test_skill_bash_allowlist_narrow.sh` verify SKILL.md against it. Adding the `qg-worktree.sh` Bash entry to SKILL.md REQUIRES adding the identical entry to `EXPECTED_ORDER` in the same task, or the canonical scenario goes red.

- [ ] **Step 1: Extend the failing protocol-shape test**

Append the following assertions to `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`, inserting them right before the final `if [[ "$fail" -eq 0 ]]` summary (line 120):

```bash
# --- v2.2.0 sandbox-executor protocol-shape ---

# create-sandbox must be invoked, and BEFORE the runtime-verifier dispatch.
sandbox_line=$(first_line 'create-sandbox')
assert_line "create-sandbox invoked" "$sandbox_line"
assert_order "create-sandbox precedes runtime-verifier dispatch" "$sandbox_line" "$runtime_line"

# mutation-guard must be invoked AFTER the runtime-verifier dispatch.
guard_line=$(first_line_after 'mutation-guard' "$runtime_line")
assert_line "mutation-guard invoked after runtime dispatch" "$guard_line"

# forced_downgrade must be referenced (verdict gating on the guard result).
assert_line "forced_downgrade referenced" "$(first_line 'forced_downgrade')"

# Upfront Execution Plan section present, and before the Review gate dispatch.
upfront_line=$(first_line 'Upfront Execution Plan|Execution Plan')
assert_line "Upfront Execution Plan section present" "$upfront_line"

# requires_decision drives the upfront gate.
assert_line "requires_decision referenced in plan gate" "$(first_line 'requires_decision')"

# Blocked-path routing references the three policies.
assert_line "block policy stop/skip/ask present" "$(first_line 'block_policy|stop / skip / ask|stop/skip/ask')"

# Kill-switch fallback present.
assert_line "runtime sandbox kill switch present" "$(first_line 'DEVBREW_QG_DISABLE_RUNTIME_SANDBOX')"

# spec_acceptance_criteria threaded to the verifier.
assert_line "spec_acceptance_criteria threaded" "$(first_line 'spec_acceptance_criteria')"

# Version bumped to 2.2.0 (final summary).
assert_line "v2.2.0 in SKILL" "$(first_line 'v2.2.0|2\\.2\\.0')"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: FAIL — new assertions (`create-sandbox`, `mutation-guard`, `Upfront Execution Plan`, etc.) not found.

- [ ] **Step 3: Add the `qg-worktree.sh` allowlist entry to SKILL.md frontmatter**

In `plugins/quality-gates/skills/quality-pipeline/SKILL.md`, under `# Group 3 — Runtime gate scripts` (after line 24, the `compute-test-scope-candidates.sh` entry), add:

```yaml
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)
```

- [ ] **Step 4: Add the identical entry to the linter's `EXPECTED_ORDER`**

In `plugins/quality-gates/scripts/check-allowed-tools-order.sh`, in the `EXPECTED_ORDER` array, after the `compute-test-scope-candidates.sh` line (line 24), add:

```bash
  'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh:*)'
```

- [ ] **Step 5: Bump the version strings in SKILL.md**

Replace `# Quality Gates — In-Turn Orchestrator (v2.1.0)` (line 36) with `(v2.2.0)`, and in the Final Summary template replace `## Quality Gates Pipeline — Complete (v2.1.0)` (line 478) with `(v2.2.0)`.

- [ ] **Step 6: Rewrite the Law 2 preamble**

Replace the Law 2 paragraph (lines 45-51) with:

```markdown
**Law 2 (Writer ≠ Reviewer):** you are the orchestrator (writer). `security-reviewer`, `adversarial`, and `test-scope-validator` are read-only reviewers (`disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`). The `runtime-verifier` is a **sandbox executor**: it CAN Write/Edit, but only inside a disposable git-worktree sandbox, and you enforce Law 2 *structurally* — after it runs you compute `qg-worktree.sh mutation-guard <sandbox> <baseline>` and, if `forced_downgrade: yes`, you cap the verdict at FAIL regardless of what the verifier claimed. Nothing is committed; the sandbox is discarded. You may also apply user-approved Review-gate fixes ("Retry" path) via Edit/Write — those are user-consented.
```

- [ ] **Step 7: Add the "Upfront Execution Plan" section**

Insert a new section between the `## Arguments` section and `## Dispatch Loop` (after line 156, before line 158 `## Dispatch Loop`):

```markdown
## Upfront Execution Plan

Decide runtime scope ONCE, before any gate runs, but only when there is something risky to decide. After [Preflight](#preflight) and [Arguments](#arguments), and before the [Dispatch Loop](#dispatch-loop):

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh` to get the manifest with `requires_decision` flags.
2. **Gate firing condition (mechanical):** fire an `AskUserQuestion` **only if** the manifest has ≥1 surface with `requires_decision: true` AND no argument already pre-answers it (`gate=`, `skip_runtime`, or an explicit surface selection). Otherwise (pure-local test runners only / review-only / arg-answered) print a one-line plan and proceed **zero-click**.
3. When firing, confirm in ONE question: **gate scope** (review / runtime / both), **runtime scope** (which `requires_decision` surfaces to opt into — test runners are automatic), and **block policy** (`stop` / `skip` / `ask`). Record the opted-in surfaces as `approved_surfaces` and the chosen `block_policy`.

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime scope: these surfaces can start processes or reach outside (requires_decision): <list>. Which should I run, and what should I do if one stays blocked after setup retries?",
      header: "Runtime scope",
      options: [
        {label: "Run all + skip blocked", description: "Opt into all listed surfaces; block_policy=skip (SKIP_WITH_EVIDENCE, continue)."},
        {label: "Run all + ask on block", description: "Opt into all; block_policy=ask (mid-run question, bounded by DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)."},
        {label: "Test runners only",       description: "Skip every requires_decision surface; run only automatic test runners."},
        {label: "Stop on block",            description: "Opt into all; block_policy=stop (abort the gate at the first unrecoverable block)."}
      ],
      multiSelect: false
    }
  ]
})
```

**Upfront approval is authoritative.** A surface opted in here is NOT re-asked mid-run. A mid-run question fires only for a *newly discovered* block when `block_policy=ask`, and the total number of such mid-run questions is itself bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`.

**Cost heads-up (AC13):** if the plan includes a web process-start surface (a heavy interactive flow on the inherited model), print one line before dispatching: `> Runtime gate will boot a web app and drive browser flows (heavier; inherited model).`
```

- [ ] **Step 8: Rewrite the Runtime gate section**

Replace the entire `## Runtime gate` section (lines 377-471, through the end of the `## Runtime NEEDS_RESOLUTION decision` branch list) with the sandbox-wired version:

```markdown
## Runtime gate

If `skip_runtime` was set, skip this entire section.

**Step R0 — Create the sandbox (or fall back).** Seal the code-under-review into a disposable git-worktree:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" create-sandbox "<session-id>"
```

- Exit 0 → capture **line 1 = `sandbox_dir`**, **line 2 = `baseline_sha`**. The verifier's `project_dir` for this gate is `sandbox_dir` (frozen — overrides the preflight `project_dir` for the Runtime gate only).
- **Exit 3** (kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`) → graceful fallback: dispatch the verifier in **read-only smoke mode** against the real `project_dir`, and print the loud line: `> [quality-gates] runtime sandbox disabled — read-only smoke verification only (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1).` Skip the mutation guard (Step R4) in this mode.
- Any other non-zero → surface stderr verbatim and mark the Runtime gate failed.

**Step R1 — test-scope-validator** (read-only reviewer; `project_dir` is the *preflight* dir, not the sandbox — it reviews the real diff). Per [Reviewer dispatch contract](#reviewer-dispatch-contract):

```
Agent({
  subagent_type: "quality-gates:test-scope-validator",
  description: "Classify scope-relevant test files (Runtime gate)",
  prompt: "Validate test scope against current diff, spec acceptance criteria, and plan items.
    project_dir: \"$project_dir\"
    spec_path: <path or 'auto'; pass 'none' if DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1>
    plan_path: <path or 'auto'>
    candidate_test_files: <list from scope-detection step>"
})
```

**Step R2 — gather spec Acceptance Criteria.** Resolve the spec (reuse `discover-spec.sh` semantics already used by test-scope-validator) and build `spec_acceptance_criteria` as a `{ac_id, text}` list. If no spec, pass an empty list (the verifier falls back to plan_features → smoke).

**Step R3 — dispatch runtime-verifier (executor)** with `project_dir = sandbox_dir`, the spec AC, the approved surfaces, and the block policy:

```
Agent({
  subagent_type: "quality-gates:runtime-verifier",
  description: "Runtime verification (Runtime gate, sandbox executor)",
  prompt: "Boot the declared surfaces in the sandbox, drive flows, assert against spec AC, write an evidence-log.
    project_dir: \"$sandbox_dir\"
    spec_acceptance_criteria: <{ac_id,text} list or []>
    manifest: <output of detect-runtime.sh>
    approved_surfaces: <surfaces opted in at the Upfront Execution Plan>
    block_policy: <stop|skip|ask>
    resolution_iter: <N (1..DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS)>"
})
```

**Step R4 — Mutation guard (authoritative verdict cap).** Unless in read-only fallback, compute the product-mutation oracle:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" mutation-guard "<sandbox_dir>" "<baseline_sha>"
```

Read the YAML. **If `forced_downgrade: yes`**, the verdict is capped at FAIL regardless of the verifier's emitted verdict (Law 2 — the verifier cannot self-approve a product change). Surface `tracked_diff` + `disallowed_new_files` as evidence ("the app only ran after this change — fix it in a normal writer→review cycle"). The verifier's own `writes:` self-report is advisory only; this git result is authoritative.

**Step R5 — Discard the sandbox** (verdict-independent), unless in read-only fallback:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/qg-worktree.sh" remove "<sandbox_dir>"
```

**Step R6 — Outcome routing** (verdict = min(verifier verdict, guard cap)):

- **Clean (PASS) AND `forced_downgrade: no`** → print `## Runtime gate — clean` and continue to final summary.
- **`forced_downgrade: yes`** → print the Runtime gate FAIL block including the surfaced diff; emit final summary marked Runtime gate failure. Do NOT auto-restart, do NOT apply the diff (in-gate accept is out of scope — §3 of the spec).
- **FAIL** (product bug / unrecoverable) → print verdict block; final summary marked failure.
- **SKIP_WITH_EVIDENCE** → print evidence; continue.
- **NEEDS_RESOLUTION** → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision).

## Blocked-path routing

A surface is *blocked* when the executor cannot complete it. Routing (per-surface — one block never aborts the others):

| Block kind | Handling |
|---|---|
| setup-fixable (.env/deps) | executor auto-fixes in sandbox + retries (≤3/dispatch). Success → continue; exhausted → `NEEDS_RESOLUTION`. |
| operational-safety (prod config/network needed) | NOT run. Recorded `blocked-for-safety` → SKIP_WITH_EVIDENCE or NEEDS_RESOLUTION("provide test config"). |
| needs-decision (`requires_decision` not in `approved_surfaces`) | NOT run → SKIP_WITH_EVIDENCE. |
| product bug (AC unmet / won't boot from product defect) | FAIL + evidence. Not a retry. |
| hang/timeout | per-surface wall-clock kill; record blocked; continue with remaining surfaces. |

On executor `NEEDS_RESOLUTION` (setup retries exhausted), apply the upfront `block_policy`:
- `stop` → abort the gate at the block; terminal summary.
- `skip` → record SKIP_WITH_EVIDENCE for that surface; finalize with partial results.
- `ask` → invoke [Runtime NEEDS_RESOLUTION decision](#runtime-needs_resolution-decision) (retry / skip-with-evidence / stop). Total `ask` mid-run questions are bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`; on exhaustion, fall through to skip-with-evidence.

---

The NEEDS_RESOLUTION branch is the only Runtime gate outcome that surfaces a user question when `block_policy=ask`. It is bounded by `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` so a mis-configured environment cannot loop indefinitely.

Per spec AC8 and the secret-policy rule (P21), the prompt body asks the user to place secrets on disk first and respond yes/no. Never request a secret value as a literal string.

## Runtime NEEDS_RESOLUTION decision

> **Spec anchor (AC8):** the literal phrase `Runtime verifier needs` MUST appear in the prompt — V2b grep checks this. **P21 reaffirmation MUST also appear in the prompt body** (literal token `P21`).

Loop up to `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` times (default 3, env override clamped 0..10):

```
AskUserQuestion({
  questions: [
    {
      question: "Runtime verifier needs: <missing resource description>. (P21: never paste secrets into this prompt — add them to .env / config on disk first, then choose Yes, retry.)",
      header: "Runtime resolve",
      options: [
        {label: "Yes, retry",         description: "I've added the missing resource on disk. Re-run the Runtime gate."},
        {label: "Skip with evidence", description: "Mark the Runtime gate SKIP_WITH_EVIDENCE with reason."},
        {label: "Stop",               description: "Abort the pipeline at the Runtime gate."}
      ],
      multiSelect: false
    }
  ]
})
```

Branch:
- **Yes, retry** → increment resolution counter; if exceeds env limit, fall through to Skip with evidence. Otherwise re-dispatch runtime-verifier (re-create the sandbox at Step R0 so retries start from a clean baseline).
- **Skip with evidence** → record SKIP_WITH_EVIDENCE and continue.
- **Stop** → final summary aborted at the Runtime gate.
```

> When re-dispatching after "Yes, retry", recreate the sandbox (Step R0) before Step R3 so the new attempt seals a fresh baseline `B` reflecting any on-disk fix the user made.

- [ ] **Step 9: Add the upfront-plan call into the Dispatch Loop**

In the `## Dispatch Loop` section, insert the upfront plan step. Replace the Dispatch Loop list item 1 (line 162-164) so the plan is computed first:

```markdown
Full pipeline mode:

1. Run [Trivia escape](#trivia-escape). If trivia detected, print "Trivia diff — all gates skipped" and return.
2. Run [Upfront Execution Plan](#upfront-execution-plan) to fix gate scope, runtime scope (`approved_surfaces`), and `block_policy`. Zero-click unless a `requires_decision` surface exists and is not arg-answered.
3. Run [Review gate](#review-gate) (unless gate scope excludes it). Iterate up to 5 times; at each iteration end: findings empty → continue; non-empty → [Review iter boundary decision](#review-iter-boundary-decision).
4. If `skip_runtime` or gate scope excludes runtime, skip the Runtime gate and emit final summary.
5. Otherwise run [Runtime gate](#runtime-gate) (R0–R6).
6. Emit final summary.
```

- [ ] **Step 10: Run the protocol-shape test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`
Expected: PASS — all original + new assertions pass. (The original `adversarial < runtime-verifier` order and the retry-block-between assertions still hold; the Review gate dispatch blocks were not moved.)

- [ ] **Step 11: Run the allowlist linter + its tests**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh
bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh
bash plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh
```
Expected: all PASS. `check-allowed-tools-order.sh` reports `OK (16 tools in canonical order)` (was 15 + the new qg-worktree.sh = 16). The order test's canonical scenario passes because SKILL.md and `EXPECTED_ORDER` now agree; the swap/move/unknown scenarios still FAIL-as-expected.

- [ ] **Step 12: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/scripts/check-allowed-tools-order.sh \
        plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
git commit -m "feat(quality-gates): SKILL upfront plan + sandbox wiring + mutation-guard cap (AC4/AC7/AC9/AC12)"
```

---

## Task 6: Version + CHANGELOG + e2e stale fix (AC11)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md`

- [ ] **Step 1: Bump plugin.json**

In `plugins/quality-gates/.claude-plugin/plugin.json`, change `"version": "2.1.0"` to `"version": "2.2.0"`.

- [ ] **Step 2: Add the CHANGELOG entry**

Insert a new top entry in `plugins/quality-gates/CHANGELOG.md` immediately after the header block (before `## [2.1.0] — 2026-05-31` at line 6):

```markdown
## [2.2.0] — 2026-05-31

`runtime-verifier`를 read-only 관찰자에서 **git-worktree 샌드박스 기능-executor**로 전환.
서비스를 띄우고 real user flow를 구동하며 spec Acceptance Criteria 대비 동작을
**증거-접지** 방식으로 단언한다. Write를 허용하되, orchestrator가 immutable baseline
commit 대비 `git diff`로 product 변경을 ground-truth로 잡아 **PASS를 구조적으로 차단**하고
무커밋·샌드박스 폐기로 Law 2 self-approval을 물리적으로 봉쇄한다. 운영 DB/네트워크는
git-ignored 파일(prod `.env`) 미복사로 원천 미접근.

### Added
- **`scripts/qg-worktree.sh create-sandbox`**: working-tree를 byte-faithful 반영한
  일회용 detached worktree 생성(`cp -a`로 mode/symlink/binary 보존, git-ignored 미복사,
  deletion 반영) + immutable baseline commit `B` 봉인. 출력=경로+SHA 2줄.
- **`scripts/qg-worktree.sh mutation-guard`**: `(sandbox, B)`만 입력받는 순수-git product-
  mutation oracle. `tracked_diff` / `disallowed_new_files`(신규 non-ignored 파일 + 모든 신규
  symlink) / `forced_downgrade` emit. verifier 자기판단과 독립 → Law 2 구조적 가드.
- **`detect-runtime.sh` blast-radius 분류**: process-start kind(dev/start/serve, cargo-run,
  go-run, makefile run/serve) + 네트워크/배포/파괴 신호 매칭 surface에 `requires_decision: true`.
  test runner kind은 자동.
- **Upfront Execution Plan** (SKILL): `requires_decision` surface가 있을 때만 1회 발화해
  gate 범위·runtime 범위(`approved_surfaces`)·block 정책(`stop`/`skip`/`ask`)을 확정.
  그 외 zero-click.
- **신규 테스트**: `test_qg_runtime_sandbox.sh`, `test_qg_mutation_guard.sh`,
  `test_detect_runtime.sh` blast-radius 확장, fixtures `gate3/cli-tool`·`gate3/danger-signal`.
- **kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`**: 샌드박스 끄고 read-only smoke
  fallback + loud log.

### Changed
- **`agents/runtime-verifier.md`**: `model: sonnet → inherit`; `allowedTools`에
  `Write`/`Edit`/`MultiEdit` + chrome-devtools 상호작용 도구(click/fill/fill_form/type_text/
  hover/press_key/evaluate_script) 추가; `disallowedTools`는 `NotebookEdit`만 유지.
  body를 sandbox-executor 정체성 + spec AC 기능 단언 + evidence-log
  `writes`/`functional_assertions` 섹션으로 재작성.
- **`SKILL.md`**: Runtime gate를 R0(sandbox)~R6(routing)로 재배선, mutation-guard 결과로
  verdict ≤FAIL 강제, spec AC thread, blocked-path 정책 라우팅, cost heads-up. v2.2.0.
- **`check-allowed-tools-order.sh`**: 정전 allowlist에 `qg-worktree.sh` 추가(16개).

### Security
- **Law 2 메커니즘 이전 (도구 deny → git-diff 가드).** `runtime-verifier`의 self-approval
  방지가 `disallowedTools: [Write]`(behavioral tool deny)에서 **orchestrator의 immutable-
  baseline git-diff 가드**(구조적, verifier 주장과 독립)로 이동. 외부 표면(`/qg`)은
  하위호환(additive + gated)이라 minor bump. `test-scope-validator`/`security-reviewer`/
  `adversarial`은 read-only reviewer로 불변. persona 편집은 보안-민감 변경.
- **운영 안전.** 샌드박스가 git-ignored 파일(prod `.env`/자격증명/deps)을 복사하지 않아
  운영 DB/네트워크 접근 경로를 원천 차단. process-start/네트워크/파괴 surface는 upfront
  승인 게이트(blast-radius) 뒤로. OS-수준 egress 격리는 명시적 non-goal(한계 인정).
```

- [ ] **Step 3: Fix the stale e2e agent-table line**

In `plugins/quality-gates/tests/e2e-scenarios.md`, in the block around lines 131-141, change:

```
  plan-verifier: model=sonnet, cost_class=low
  runtime-verifier: model=sonnet, cost_class=low
```

to (drop the removed `plan-verifier`, fix runtime-verifier, bump the version line):

```
  runtime-verifier: model=inherit, cost_class=variable
```

And change `plugin.json version: 1.32.x` (line 138 region) to `plugin.json version: 2.2.x`.

- [ ] **Step 4: Verify version consistency**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
grep -n '"version"' plugins/quality-gates/.claude-plugin/plugin.json
grep -n '## \[2.2.0\]' plugins/quality-gates/CHANGELOG.md
grep -n 'model=sonnet' plugins/quality-gates/tests/e2e-scenarios.md || echo "no stale sonnet lines"
grep -rn 'v2.2.0\|2\.2\.0' plugins/quality-gates/skills/quality-pipeline/SKILL.md | head
```
Expected: plugin.json shows `2.2.0`; CHANGELOG has the `[2.2.0]` header; `no stale sonnet lines`; SKILL shows the 2.2.0 strings.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/tests/e2e-scenarios.md
git commit -m "chore(quality-gates): v2.2.0 version bump + CHANGELOG + e2e stale fix (AC11)"
```

---

## Task 7: README — Law 2 rewrite + new principle bullets + table/model update (AC10-README)

**Files:**
- Modify: `plugins/quality-gates/README.md`
- Test: `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` (run to confirm no regression)

- [ ] **Step 1: Rewrite the runtime-verifier Law 2 bullet**

In `plugins/quality-gates/README.md`, replace the v1.8.0 Law 2 bullet (line 19, the one beginning `- **Law 2 (Writer ≠ Reviewer, frontmatter tool scoping으로 물리적 분리)** (v1.8.0) — `runtime-verifier` agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언...`) with:

```markdown
- **Law 2 (Writer ≠ Reviewer, git-diff 구조적 가드)** (v2.2.0; supersedes v1.8.0 tool-deny) — `runtime-verifier`는 이제 **sandbox-executor**다. Write/Edit가 허용되지만 *일회용 git-worktree 샌드박스 안에서만* 의미를 가지며, orchestrator(SKILL)가 샌드박스 생성 시 code-under-review를 immutable baseline commit `B`로 봉인하고 gate 종료 시 `qg-worktree.sh mutation-guard`(순수 git, verifier 주장과 독립)로 product 변경을 ground-truth로 산출 — 비어있지 않으면 verdict가 구조적으로 ≤FAIL로 강제되고 아무것도 commit되지 않으며 샌드박스는 폐기된다. 즉 self-approval 방지의 *물리적 보장 형태*가 "도구 deny" → "git ground-truth 가드"로 바뀐 것이지 보장이 사라진 것이 아니다. **대비: `test-scope-validator`/`security-reviewer`/`adversarial`은 순수 read-only reviewer로 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 불변.** 운영 DB/네트워크는 git-ignored 파일(prod `.env`) 미복사로 미접근. regression: `tests/test_qg_mutation_guard.sh`(가드 독립성), `tests/test_qg_runtime_sandbox.sh`(ignored 미복사).
```

- [ ] **Step 2: Add new principle bullets**

Immediately after the bullet rewritten in Step 1, add three bullets:

```markdown
- **Law 1 (Clarity / evidence-required) — 기능 단언** (v2.2.0) — Runtime gate가 spec Acceptance Criteria를 verifier에 thread해, 단순 "떴나?"가 아니라 AC별 flow를 구동하고 expected-vs-observed를 evidence(screenshot + DOM snapshot + network status)와 함께 단언. evidence 없는 "동작함"은 거부. spec 부재 시 plan_feature → smoke fallback(loud log).
- **운영-안전 게이트 (blast-radius)** (v2.2.0) — `detect-runtime.sh`가 process-start/네트워크/파괴 신호 surface를 `requires_decision: true`로 분류하고, SKILL의 Upfront Execution Plan이 그것들을 1회 사용자 승인 뒤로 둔다(deny-by-default). 운영 DB/네트워크는 샌드박스가 git-ignored prod config를 복사하지 않아 원천 차단(OS-수준 egress 격리는 명시적 non-goal — 한계 인정).
- **P18 — Upfront 1-회 결정 + 폐기** (v2.2.0) — runtime 범위·block 정책을 `requires_decision` surface가 있을 때만 1회 확정(없으면 zero-click). executor-내부 setup retry ≤3/dispatch, SKILL re-dispatch ≤`runtime_max_resolutions`; 곱이 hard ceiling. kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`.
```

- [ ] **Step 3: Update the agent table / model references**

Find the README agent/model table and the `runtime-verifier.md` structure comment (line 45 region: `runtime-verifier.md # Runtime gate Step 3 (runner)`) and update to `# Runtime gate Step 3 (sandbox executor — model inherit)`. If there is a model column listing `runtime-verifier ... sonnet`, change to `inherit`. (Run `grep -n 'runtime-verifier' plugins/quality-gates/README.md` first to find all sites; update each that states a model/role.)

- [ ] **Step 4: Run the README state-diagram test (no regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh`
Expected: PASS (this test checks the state diagram completeness; the bullet edits don't touch it, but confirm).

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/quality-gates/README.md
git commit -m "docs(quality-gates): README Law 2 git-diff-guard scoped exception + new principles (AC10)"
```

---

## Task 8: Philosophy + CLAUDE.md scoped-exception note + TOC sync (AC10-philosophy)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `CLAUDE.md`

> Keep this light-touch (a documented exception note, NOT a Law 2 rewrite — per spec §6.9 and project memory `feedback_devbrew_design_lightness`). No new P#/AP#.

- [ ] **Step 1: Add the scoped-exception note to the philosophy doc**

In `docs/philosophy/devbrew-harness-philosophy.md`, append a note to the Law 2 따름정리 paragraph (after line 94, the paragraph ending `...철학은 이것을 모든 플러그인으로 일반화합니다.`):

```markdown

**Scoped exception — executor with structural guard (R6, 2026-05-31, quality-gates v2.2.0):** Law 2의 *물리적 분리*는 보통 reviewer에게서 `Write`를 deny하는 형태다. 그러나 "실제 서비스를 실행하며 테스트"하는 executor(qg `runtime-verifier`)는 쓰기가 필요하다. 이 경우 분리는 **orchestrator가 immutable baseline commit 대비 `git diff`로 product 변경을 산출하는 구조적 가드**로 보장된다 — executor가 자유롭게 써도 product 변경은 git ground-truth가 잡아 verdict를 ≤FAIL로 강제하고, 무커밋·샌드박스 폐기로 product에 닿지 못한다. 핵심 불변식은 유지된다: *코드를 쓴 pass는 그것을 product에 approve할 수 없다.* 보장의 *형태*가 "도구 deny"에서 "git-diff 가드"로 바뀌었을 뿐 사라지지 않았다. behavioral 규칙(프롬프트)이 아니라 verifier 주장과 독립적인 구조이므로 self-approval이 구조적으로 불가능하다.
```

- [ ] **Step 2: Sync the philosophy TOC if a new anchor was added**

The note above is appended to an existing paragraph (no new `##`/`###` heading), so the `## 목차` (TOC) needs **no** new anchor. Confirm: `grep -n '^### \|^## ' docs/philosophy/devbrew-harness-philosophy.md | head -30` — if the Law 2 section gained no new heading, the TOC is already in sync (skip editing it). If you chose to add a sub-heading instead of an inline note, add the matching anchor to `## 목차`.

- [ ] **Step 3: Add the scoped-exception clause to CLAUDE.md**

In `CLAUDE.md`, in the **Law 2** paragraph (the one beginning `**Law 2 — Writer and Reviewer Must Never Share a Pass.**`), append one sentence at the end of that paragraph:

```markdown
 *Scoped exception (qg v2.2.0):* 실제 서비스를 실행해야 하는 executor(runtime-verifier)는 `Write`를 갖되, 분리는 도구 deny가 아니라 **orchestrator가 immutable baseline 대비 `git diff`로 product 변경을 잡아 verdict를 ≤FAIL로 강제 + 무커밋 + 샌드박스 폐기**하는 구조적 가드로 보장 — verifier 주장과 독립이라 self-approval이 구조적으로 불가능 (철학 §1 Law 2 R6 note).
```

- [ ] **Step 4: Verify cross-references resolve**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
grep -n "Scoped exception\|git-diff 가드\|구조적 가드" docs/philosophy/devbrew-harness-philosophy.md CLAUDE.md
```
Expected: both files contain the note; the references are consistent.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add docs/philosophy/devbrew-harness-philosophy.md CLAUDE.md
git commit -m "docs(philosophy): note qg v2.2.0 executor scoped exception (git-diff structural guard) (AC10)"
```

---

## Task 9: Full regression + self-review + spec-coverage check

**Files:** none (verification only).

- [ ] **Step 1: Run every new/changed test green**

Run from repo root:
```bash
cd /Users/jeonghokim/Downloads/devbrew
echo "== detect-runtime ==";       bash plugins/quality-gates/tests/test_detect_runtime.sh        | tail -2
echo "== sandbox ==";              bash plugins/quality-gates/tests/test_qg_runtime_sandbox.sh    | tail -2
echo "== mutation-guard ==";       bash plugins/quality-gates/tests/test_qg_mutation_guard.sh     | tail -2
echo "== worktree helper ==";      bash plugins/quality-gates/tests/test_qg_worktree_helper.sh    | tail -2
echo "== rv frontmatter ==";       bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh | tail -2
echo "== rv behavior ==";          python3 -m pytest plugins/quality-gates/tests/test_runtime_verifier_behavior.py -q | tail -2
echo "== orchestration ==";        bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh | tail -2
echo "== allowed-tools order ==";  bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh | tail -2
echo "== bash allowlist narrow =="; bash plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh | tail -1
echo "== readme diagram ==";       bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh | tail -1
```
Expected: every line reports 0 failures / PASS.

- [ ] **Step 2: Confirm no NEW reds vs Task 0 baseline**

Re-run the Task 0 baseline command set and diff against `${CLAUDE_JOB_DIR:-/tmp}/qg-baseline/baseline.txt`. Any test GREEN in baseline must still be GREEN. Pre-existing reds (codex/consent/security/sandbox) stay red — do not attribute them to this work.

- [ ] **Step 3: Self-review — spec AC coverage**

Verify each spec AC maps to an implemented + tested behavior:

| AC | Where | Test |
|---|---|---|
| AC1 frontmatter | Task 4 | `test_runtime_verifier_frontmatter.sh` |
| AC2 blast-radius | Task 1 | `test_detect_runtime.sh` T8/T9/T10 |
| AC3 sandbox byte-faithful | Task 2 | `test_qg_runtime_sandbox.sh` |
| AC4 upfront plan | Task 5 | `test_skill_orchestration_behavior.sh` (Upfront/requires_decision) |
| AC5 operational safety | Tasks 1,2 | detect T10 + sandbox `.env`-not-copied |
| AC6 functional assertion | Task 4 | `test_runtime_verifier_behavior.py` + frontmatter body greps |
| AC7 verdict + guard | Task 3 | `test_qg_mutation_guard.sh` (incl. independence) |
| AC8 fix-loop bounded | Tasks 4,5 | agent body ≤3 + SKILL `runtime_max_resolutions` |
| AC9 blocked-path | Task 5 | orchestration test `block_policy` + Blocked-path routing section |
| AC10 Law 2 docs | Tasks 7,8 | README/philosophy/CLAUDE greps |
| AC11 version/CHANGELOG/e2e | Task 6 | version-consistency greps |
| AC12 kill switch | Tasks 2,5 | `test_qg_runtime_sandbox.sh` exit-3 + SKILL fallback |
| AC13 cost | Tasks 4,5 | frontmatter cost_class + SKILL heads-up line |

If any row has no test, add it before proceeding.

- [ ] **Step 4: Placeholder + consistency scan**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
grep -rn 'TODO\|TBD\|FIXME\|XXX' plugins/quality-gates/scripts/detect-runtime.sh plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/agents/runtime-verifier.md plugins/quality-gates/skills/quality-pipeline/SKILL.md || echo "no placeholders"
# project_dir for runtime-verifier must be the sandbox in SKILL Step R3
grep -n 'sandbox_dir' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```
Expected: `no placeholders`; the SKILL threads `sandbox_dir` into the verifier dispatch.

- [ ] **Step 5: Final verification commit (if Step 3/4 surfaced fixes)**

If any gap-fill edits were made in this task, commit them:
```bash
cd /Users/jeonghokim/Downloads/devbrew
git add -A
git commit -m "test(quality-gates): close v2.2.0 AC coverage gaps from self-review"
```
Otherwise, no commit — the implementation is complete across Tasks 1-8.

---

## Notes for the implementer

- **Order matters for Tasks 2→3:** `mutation-guard`'s test builds its sandbox via `create-sandbox`, so Task 2 must land first.
- **The mutation guard is the design centerpiece.** Resist any "optimization" that lets the verifier's self-reported `writes:` short-circuit the git computation — that reintroduces the self-approval hole the spec's round-1 review caught. The guard must remain a pure function of `(sandbox, baseline)`.
- **Don't widen the chrome-devtools tool set** beyond the frontmatter list without re-checking availability; `drag`/`upload_file`/`handle_dialog` were intentionally omitted.
- **Korean-primary docs:** README/CHANGELOG/philosophy/CLAUDE edits follow the repo's Korean-primary, English-terms-only convention (identifiers, proper nouns, verbatim quotes, untranslatable tech terms in English).
