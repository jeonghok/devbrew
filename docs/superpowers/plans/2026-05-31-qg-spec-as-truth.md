# quality-gates v2.1.0 — Spec as Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `quality-gates` read the user's project **spec** as the single source of truth — re-aim `test-scope-validator` from plan items to spec Acceptance Criteria, revive the dead codex `<plan_context>` slot as `<spec_context>`, all advisory-only (never blocks).

**Architecture:** New `scripts/discover-spec.sh` (mirror of `discover-plan.sh`, project-local only, AC-section eligibility) is called script-internally by both consumers. `test-scope-validator` (Runtime gate) emits an advisory `ac_coverage` block when a spec is found; `run_codex_reviewer.sh` (Review gate) extracts the spec's AC section and injects it into the codex prompt. `plan` is demoted to a secondary implementation-method hint (not removed — `discover-plan.sh` stays byte-identical). No spec → loud log + functionally-identical v2.0.0 behavior.

**Tech Stack:** Bash (POSIX/BSD-portable), Python 3 (stdlib only), Markdown agent personas + SKILL, grep/awk mechanical verification, bash + pytest-style behavior tests via the existing `agent_stub` harness.

**Source spec:** `docs/superpowers/specs/2026-05-31-qg-spec-as-truth-design.md` (committed `42db51b`, approved through 3 review rounds). All work is on branch `feature/qg-spec-as-truth`.

---

## Deviations from the Spec (verification-command corrections)

These are corrections to *verification commands* in the spec, not to its requirements. Discovered by smoke-testing during planning:

1. **AC9 `sed` → portable `awk`.** The spec's AC9 verification command `sed -n '1,/^---$/{/^---$/!p}'` **crashes on BSD sed (macOS):** `extra characters at the end of p command`. Worse, the downstream `grep -c → 0` then passes for the *wrong* reason (empty input from the crashed pipe, not genuine absence) — a false-pass. This plan substitutes the portable, genuinely-verifying form:
   ```bash
   awk '/^---$/{c++; next} c==1' skills/quality-pipeline/SKILL.md | grep -c 'discover-spec'   # → 0
   ```
   The assertion target is unchanged (`discover-spec`/`discover-plan` absent from SKILL frontmatter = invocation parity). Only the extraction mechanism changes to a portable equivalent. Smoke-tested: produces 32 lines of genuine frontmatter body, contains `allowed-tools`, excludes the `# Quality Gates` heading, grep returns a real `0`.

2. **Line-number anchors are hints (spec Deferred ⑦).** Every `:NN` in this plan was re-confirmed against the working tree at planning time, but edits shift lines. Where a step pins a line, the accompanying `grep`/identifier match is authoritative — re-locate by content if the line moved.

## Pre-flight: how to run the test suite (spec Deferred ⑤)

`plugins/quality-gates/` has **no CI** and `main` carries **8 pre-existing stale reds** unrelated to this work (memory `project_qg_pre_existing_test_reds`). To tell "I broke it" from "already red":

- **Bash tests:** run from **repo root** — `bash plugins/quality-gates/tests/test_x.sh`. Running from inside the plugin dir doubles `scripts/` paths and spuriously fails.
- **Python tests:** run **individual files** — `python3 plugins/quality-gates/tests/test_x.py`. `pytest tests/` collection-errors on `tests/fixtures/test-scope/*/tests/*.py` DIFF fixtures (`src.` import).
- **Known baseline reds (8, must remain the *only* reds):** `test_codex_backward_compat` · `test_codex_dispatch_invariant` · `test_codex_reviewer_frontmatter` · `test_consent_marker_write_failure` · `test_sandbox_enforced` · `test_scout_codex_integration` · `test_security_reviewer_kill_switch` · `test_skill_codex_skip_prose`.

Regression rule for AC17: after this work, the failing set must be **⊆ the 8 baseline reds, with 0 new reds**.

---

## File Structure

**New files:**
- `plugins/quality-gates/scripts/discover-spec.sh` — project spec discovery. One responsibility: resolve a spec path via `--spec` → `docs/superpowers/specs/*.md` (AC-section-eligible, newest mtime) → none. Emits single-line JSON, exit 0/1/2. Mirror of `discover-plan.sh`; no legacy-global source.
- `plugins/quality-gates/tests/test_discover_spec.sh` — fixture suite for the above (explicit/project-local/none/AC-eligibility/mtime-tiebreak/no-root-miss).

**Modified files (one responsibility each):**
- `agents/test-scope-validator.md` — split fused input into `spec_path` (primary AC truth) + `plan_path` (secondary hint); redefine cherry-pick-suspicion; add advisory `ac_coverage` block; no-spec loud-log; kill-switch handling. `disallowedTools` untouched.
- `scripts/build_codex_prompt.py` — rename the prompt slot `<plan_context>`/`{{PLAN_SUMMARY}}`/`<plan_summary_file>` → `<spec_context>`/`{{SPEC_AC}}`/`<spec_ac_file>`. Stays a dumb opaque-bytes substituter.
- `scripts/run_codex_reviewer.sh` — rename `PLAN_SUMMARY_FILE`/`PLAN_SUMMARY` → `SPEC_AC_FILE`/`SPEC_AC`; resolve spec script-internally (discover-spec.sh + awk AC extraction); kill switch; loud log.
- `skills/quality-pipeline/SKILL.md` — document `spec_path` argument; add `spec_path:` to the test-scope-validator dispatch; kill-switch → `spec_path: none` translation; codex spec-injection note; bump cosmetic version headings. `allowed-tools` frontmatter unchanged (invocation parity).
- `tests/test_build_codex_prompt.sh` — replace `<plan_context>` assertions with `<spec_context>`; re-name (not delete) the `/dev/null` case to "spec AC absent → empty `<spec_context>`".
- `tests/test_test_scope_validator_behavior.py` — add `ac_coverage` schema-contract fixture + no-spec fallback fixture.
- `README.md` — "Spec Discovery Sources" section (mirror of Plan Discovery) + C66 in "Principles Instantiated".
- `CHANGELOG.md` — `## [2.1.0] — 2026-05-31` (Added/Changed/Fixed/Unchanged).
- `.claude-plugin/plugin.json` — `version` → `2.1.0`.

**Byte-identical (must NOT change):** `scripts/discover-plan.sh`, `tests/test_discover_plan.sh`, `docs/philosophy/devbrew-harness-philosophy.md`, every reviewer agent's `disallowedTools` frontmatter.

---

## Phase 0 — Baseline capture

### Task 0: Freeze the pre-existing red set

**Files:** none modified (records to a scratch file outside the repo).

- [ ] **Step 1: Capture the current failing set from repo root**

Run from `/Users/jeonghokim/Downloads/devbrew`:

```bash
mkdir -p "$CLAUDE_JOB_DIR/tmp" 2>/dev/null || true
BASE="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-baseline-reds.txt"
: > "$BASE"
for t in plugins/quality-gates/tests/test_*.sh; do
  if bash "$t" >/dev/null 2>&1; then :; else echo "FAIL(sh): $(basename "$t")" >> "$BASE"; fi
done
for t in plugins/quality-gates/tests/test_*.py; do
  if python3 "$t" >/dev/null 2>&1; then :; else echo "FAIL(py): $(basename "$t")" >> "$BASE"; fi
done
sort "$BASE"
```

Expected: the failing set equals (or is a subset of) the 8 known baseline reds listed in Pre-flight. If a *different* test fails, investigate before proceeding — the baseline must be understood, not assumed.

- [ ] **Step 2: No commit** — this is a measurement, not a change.

---

## Phase 1 — `discover-spec.sh` (foundational; both consumers call it)

### Task 1: Write the failing test for `discover-spec.sh`

**Files:**
- Test: `plugins/quality-gates/tests/test_discover_spec.sh` (create)

- [ ] **Step 1: Write the test (mirror of `test_discover_plan.sh`, AC-eligibility instead of checkboxes)**

Create `plugins/quality-gates/tests/test_discover_spec.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/discover-spec.sh — mirror of test_discover_plan.sh,
# re-aimed at the SPEC artifact (Acceptance-Criteria-section eligibility,
# project-local only — no legacy-global source).
# Uses bash assertions; no external test framework.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/discover-spec.sh"
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
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in '$haystack')"
  fi
}

# Run from a given dir; capture stdout + exit code.
run_in_env() {
  local proj="$1"; shift
  cd "$proj"
  bash "$SCRIPT" "$@" 2>"$proj/_stderr"
  return $?
}

# write_spec <path> <with_ac:1|0>
write_spec() {
  local path="$1" with_ac="$2"
  mkdir -p "$(dirname "$path")"
  {
    echo "# Some Spec Title"
    echo
    echo "## 1. Context"
    echo "prose"
    if [[ "$with_ac" == "1" ]]; then
      echo "## 5. Acceptance Criteria"
      echo "1. the thing works"
    fi
  } > "$path"
}

# --- Test 1: project-local empty → exit 1, source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/specs"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T1: exit 1 when no spec"
assert_contains "$OUT" '"source":"none"' "T1: source=none"
assert_contains "$OUT" "docs/superpowers/specs" "T1: reason mentions specs path"
cd / && rm -rf "$TMPDIR"

# --- Test 2: project-local has 1 spec WITH AC section → source=project-local ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/foo-design.md" 1
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T2: exit 0 with eligible spec"
assert_contains "$OUT" '"source":"project-local"' "T2: source=project-local"
assert_contains "$OUT" "foo-design.md" "T2: spec_path mentions foo-design.md"
cd / && rm -rf "$TMPDIR"

# --- Test 3: project-local file WITHOUT AC section → ineligible → exit 1 ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/notes.md" 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T3: exit 1 when only non-AC markdown exists"
assert_contains "$OUT" '"source":"none"' "T3: source=none for non-spec file"
cd / && rm -rf "$TMPDIR"

# --- Test 4: --spec <existing> → source=explicit ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/custom.md" 1
OUT=$(run_in_env "$TMPDIR" --spec "$TMPDIR/custom.md")
RC=$?
assert_eq "$RC" "0" "T4: exit 0 with --spec to existing file"
assert_contains "$OUT" '"source":"explicit"' "T4: source=explicit"
assert_contains "$OUT" "custom.md" "T4: spec_path is the explicit path"
cd / && rm -rf "$TMPDIR"

# --- Test 5: --spec <nonexistent> → exit 2 ---
TMPDIR=$(mktemp -d)
OUT=$(run_in_env "$TMPDIR" --spec "/tmp/definitely-no-spec-xyz123.md")
RC=$?
assert_eq "$RC" "2" "T5: exit 2 with --spec to nonexistent file"
assert_contains "$OUT" '"source":"none"' "T5: source=none"
assert_contains "$OUT" "does not exist" "T5: reason mentions 'does not exist'"
cd / && rm -rf "$TMPDIR"

# --- Test 6: two eligible specs → most recent mtime wins ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/older.md" 1
write_spec "$TMPDIR/docs/superpowers/specs/newer.md" 1
touch -t 202601010000 "$TMPDIR/docs/superpowers/specs/older.md"
touch -t 202601010001 "$TMPDIR/docs/superpowers/specs/newer.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T6: exit 0"
assert_contains "$OUT" "newer.md" "T6: picks most recently modified eligible spec"
cd / && rm -rf "$TMPDIR"

# --- Test 7: --spec with no following path → exit 2 (regression) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
OUT=$(bash "$SCRIPT" --spec 2>/dev/null)
RC=$?
assert_eq "$RC" "2" "T7: exit 2 when --spec has no path"
assert_contains "$OUT" '"source":"none"' "T7: source=none"
assert_contains "$OUT" "requires a path argument" "T7: reason mentions path argument requirement"
cd / && rm -rf "$TMPDIR"

# --- Test 8: no-root-miss — eligible spec at proj root is missed from a subdir ---
TMPDIR=$(mktemp -d)
write_spec "$TMPDIR/docs/superpowers/specs/foo-design.md" 1
mkdir -p "$TMPDIR/sub/dir"
OUT=$(run_in_env "$TMPDIR/sub/dir")
RC=$?
assert_eq "$RC" "1" "T8: exit 1 when invoked from a subdir (project-local resolved against \$PWD)"
assert_contains "$OUT" '"source":"none"' "T8: source=none from wrong cwd"
cd / && rm -rf "$TMPDIR"

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails (script does not exist yet)**

Run: `bash plugins/quality-gates/tests/test_discover_spec.sh`
Expected: FAIL — every case errors because `scripts/discover-spec.sh` does not exist (`bash: .../discover-spec.sh: No such file or directory`).

### Task 2: Implement `discover-spec.sh` and make the test pass

**Files:**
- Create: `plugins/quality-gates/scripts/discover-spec.sh`

- [ ] **Step 1: Write `scripts/discover-spec.sh`**

Create `plugins/quality-gates/scripts/discover-spec.sh`:

```bash
#!/usr/bin/env bash
# discover-spec.sh — find a project SPEC file using a priority list.
# Mirror of discover-plan.sh, re-aimed at the spec artifact (the AC truth).
#
# Output (single-line JSON to stdout):
#   {"spec_path":"<absolute-or-empty>",
#    "source":"explicit|project-local|none",
#    "reason":"<human-readable>"}
# Exit codes: 0 = found, 1 = not found, 2 = invalid input
#
# Priority:
#   1. --spec <path>                     (explicit; no fallback if missing)
#   2. ./docs/superpowers/specs/*.md     (project-local)
#
# There is NO legacy-global source: a spec is a project artifact and (unlike a
# plan) has no established global-location convention. project-local only.
#
# IMPORTANT: invoke from the repository root. The project-local source path is
# resolved against $PWD; calling from elsewhere will silently miss project-local
# specs and report "not found".
#
# Eligibility: within the project-local source, only files containing an
# "Acceptance Criteria" section header (regex '^#+ .*Acceptance Criteria') are
# eligible — the spec's AC section is exactly what qg verifies conformance
# against. A markdown file with no AC section is not a spec (mirror of
# discover-plan's "no checkbox -> not a plan"). Among eligible files, the
# most-recent mtime wins.
#
# Path-escape note: emitted JSON uses %s and assumes spec paths do not contain
# double-quote or backslash characters (holds for any sane filesystem layout).

set -euo pipefail

EXPLICIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)
      if [[ $# -lt 2 ]]; then
        printf '{"spec_path":"","source":"none","reason":"--spec requires a path argument"}\n'
        exit 2
      fi
      EXPLICIT="$2"
      shift 2
      ;;
    *)
      printf '{"spec_path":"","source":"none","reason":"Unknown argument: %s"}\n' "$1"
      exit 2
      ;;
  esac
done

emit_json() {
  printf '{"spec_path":"%s","source":"%s","reason":"%s"}\n' "$1" "$2" "$3"
}

# Source 1: explicit override (highest priority; no fallback if missing)
if [[ -n "$EXPLICIT" ]]; then
  if [[ -f "$EXPLICIT" ]]; then
    emit_json "$EXPLICIT" "explicit" "Explicit --spec path"
    exit 0
  else
    emit_json "" "none" "Explicit --spec path does not exist: $EXPLICIT"
    exit 2
  fi
fi

# Portable mtime (BSD stat on macOS, GNU stat on Linux)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Pick the best spec from a directory of *.md files.
# Eligible = contains an Acceptance Criteria header. Among eligible, newest mtime.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 1

  local best="" best_mtime=0
  local f m

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    grep -qE '^#+ .*Acceptance Criteria' "$f" 2>/dev/null || continue
    m=$(get_mtime "$f")
    if [[ "$m" -gt "$best_mtime" ]]; then
      best="$f"
      best_mtime="$m"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
    return 0
  fi
  return 1
}

# Source 2: project-local
# Resolved against $PWD so emitted paths are absolute. Caller must cd to repo
# root before invoking; see header notes.
PROJECT_LOCAL="$PWD/docs/superpowers/specs"
if SPEC=$(pick_best "$PROJECT_LOCAL"); then
  emit_json "$SPEC" "project-local" "Found in docs/superpowers/specs/"
  exit 0
fi

emit_json "" "none" "No spec file found. Searched: docs/superpowers/specs/"
exit 1
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/quality-gates/scripts/discover-spec.sh`

- [ ] **Step 3: Run the test to verify it passes**

Run: `bash plugins/quality-gates/tests/test_discover_spec.sh`
Expected: PASS — `Results: 16 passed, 0 failed` (2 assertions per most cases, exit 0).

- [ ] **Step 4: Verify `discover-plan.sh` is byte-identical (AC3)**

Run:
```bash
git diff --quiet HEAD -- plugins/quality-gates/scripts/discover-plan.sh && echo "AC3a: discover-plan.sh byte-identical OK"
bash plugins/quality-gates/tests/test_discover_plan.sh >/dev/null 2>&1 && echo "AC3b: test_discover_plan.sh still green OK"
```
Expected: both lines print OK (we never touched `discover-plan.sh`).

- [ ] **Step 5: Verify AC1/AC2 mechanically**

Run:
```bash
test -x plugins/quality-gates/scripts/discover-spec.sh && echo "AC1: exists+executable OK"
plugins/quality-gates/scripts/discover-spec.sh --spec /nope 2>/dev/null; echo "AC1: invalid-input exit=$? (expect 2)"
```
Expected: `AC1: exists+executable OK`, `exit=2`.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/discover-spec.sh plugins/quality-gates/tests/test_discover_spec.sh
git commit -m "feat(quality-gates): add discover-spec.sh + tests (AC1-AC3)

Project spec discovery (mirror of discover-plan.sh): --spec / project-local
docs/superpowers/specs/*.md, AC-section eligibility, newest-mtime tiebreak,
no legacy-global source. discover-plan.sh kept byte-identical.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 — Codex slot revival (`<plan_context>` → `<spec_context>`)

### Task 3: Update `test_build_codex_prompt.sh` to assert `<spec_context>` (failing)

**Files:**
- Modify: `plugins/quality-gates/tests/test_build_codex_prompt.sh` (full rewrite)

- [ ] **Step 1: Rewrite the test file**

Replace the entire contents of `plugins/quality-gates/tests/test_build_codex_prompt.sh` with:

```bash
#!/usr/bin/env bash
# test_build_codex_prompt.sh — regression guard for the optional spec-AC
# contract (v2.1.0). run_codex_reviewer.sh resolves the spec script-internally
# and passes its extracted Acceptance Criteria section; when no spec exists it
# passes /dev/null. build_codex_prompt.py MUST treat a non-regular-file spec-AC
# argument (/dev/null, missing) as empty <spec_context>, not error — otherwise
# codex review fails with prompt_build_failed (the v2.0.0 silent-break this
# guard was created for, now re-aimed from plan summary to spec AC).

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$SCRIPT_DIR/../scripts/build_codex_prompt.py"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

DIFF="$(mktemp)"; printf 'diff --git a b\n+added line\n' > "$DIFF"
SPEC="$(mktemp)"; printf '## Acceptance Criteria\n1. feature X works\n' > "$SPEC"
trap 'rm -f "$DIFF" "$SPEC"' EXIT

# Case 1: /dev/null spec AC (no spec found) → exit 0, empty <spec_context>.
out="$(python3 "$BUILD" "$DIFF" /dev/null 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "no-spec (/dev/null) → exit 0" || bad "no-spec (/dev/null) → exit $rc (expected 0)"
echo "$out" | grep -q '+added line' && ok "no-spec: diff content present" || bad "no-spec: diff content missing"
# <spec_context> must exist but contain no spec text.
echo "$out" | grep -q '<spec_context>' && ok "no-spec: spec_context block present" || bad "no-spec: spec_context block missing"
echo "$out" | grep -q 'feature X works' && bad "no-spec: leaked spec text" || ok "no-spec: empty spec context"

# Case 2: real spec AC file → content included, exit 0.
out2="$(python3 "$BUILD" "$DIFF" "$SPEC" 2>/dev/null)"; rc2=$?
[ "$rc2" -eq 0 ] && ok "real spec AC → exit 0" || bad "real spec AC → exit $rc2 (expected 0)"
echo "$out2" | grep -q 'feature X works' && ok "real spec AC: content included" || bad "real spec AC: content missing"

# Case 3: missing diff file → exit 2 (diff is still required).
python3 "$BUILD" /nonexistent-qg-diff-xyz "$SPEC" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "missing diff → exit 2" || bad "missing diff → wrong exit"

echo ""
echo "Total: $((PASS + FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails (py still emits `<plan_context>`)**

Run: `bash plugins/quality-gates/tests/test_build_codex_prompt.sh`
Expected: FAIL on "no-spec: spec_context block present" (the script still emits `<plan_context>`, not `<spec_context>`).

### Task 4: Rewrite `build_codex_prompt.py` (plan → spec)

**Files:**
- Modify: `plugins/quality-gates/scripts/build_codex_prompt.py`

- [ ] **Step 1: Replace the whole file**

Replace the entire contents of `plugins/quality-gates/scripts/build_codex_prompt.py` with:

```python
#!/usr/bin/env python3
"""build_codex_prompt.py — Construct codex review prompt from input files.

Reads filtered_diff and an optional spec-AC file from argv file paths. NEVER
takes inline content via argv or stdin — always file paths. Substitutes into a
template using str.replace (no shell, no python eval, no triple-quote).
Writes the assembled prompt to stdout.

Usage:
  python3 build_codex_prompt.py <diff_file> <spec_ac_file>

Why: Inlining reviewed-PR content (diff) into shell or Python string
literals creates an injection vector (Critical issue C1 from Task 4
review). Always pass via filesystem path.

The prompt template is embedded as a Python multiline string. Inputs are
loaded via pathlib.Path.read_text() and substituted via str.replace,
which treats inputs as opaque bytes — no parsing, no escaping, no
evaluation. Output goes to stdout; caller redirects to a scratch file.

The <spec_ac_file> carries the Acceptance Criteria SECTION of the project
spec (extracted upstream by run_codex_reviewer.sh — this script does no
parsing). The caller passes /dev/null (a char device, not a regular file)
when no spec was found; this script treats any non-regular-file as empty
context rather than erroring.
"""

from __future__ import annotations

import pathlib
import sys

PROMPT_TEMPLATE = """You are a code reviewer. Review the diff for bugs, silent failures,
security issues, missing error handling, and design problems. Do not
modify any files; you are in a read-only sandbox.

<diff>
{{FILTERED_DIFF}}
</diff>

<spec_context>
{{SPEC_AC}}
</spec_context>

Output your findings in a fenced JSON code block:

```json
{
  "findings": [
    {
      "file": "<path>",
      "line": <integer>,
      "severity": "CRITICAL | IMPORTANT | SUGGESTION",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<description>"
    }
  ]
}
```

If you find no issues, emit `{"findings": []}` inside the same code fence.
Do not output any text after the closing fence.
"""


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <diff_file> <spec_ac_file>", file=sys.stderr)
        return 2

    diff_path = pathlib.Path(sys.argv[1])
    spec_ac_path = pathlib.Path(sys.argv[2])

    if not diff_path.is_file():
        print(f"diff file not found: {diff_path}", file=sys.stderr)
        return 2

    diff_content = diff_path.read_text(encoding="utf-8", errors="replace")
    # Spec AC is optional. The canonical "no spec found" path passes /dev/null
    # (a char device, not a regular file); upstream run_codex_reviewer.sh also
    # passes /dev/null when DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1. Treat any
    # non-regular-file as empty context rather than erroring — only a real spec
    # AC file contributes text.
    if spec_ac_path.is_file():
        spec_content = spec_ac_path.read_text(encoding="utf-8", errors="replace")
    else:
        spec_content = ""

    out = PROMPT_TEMPLATE.replace("{{FILTERED_DIFF}}", diff_content)
    out = out.replace("{{SPEC_AC}}", spec_content)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `bash plugins/quality-gates/tests/test_build_codex_prompt.sh`
Expected: PASS — `Total: 7, PASS=7, FAIL=0`.

- [ ] **Step 3: Verify AC7 mechanically**

Run:
```bash
cd plugins/quality-gates
grep -c 'spec_context\|SPEC_AC' scripts/build_codex_prompt.py   # expect >= 1
grep -c 'plan_context\|PLAN_SUMMARY' scripts/build_codex_prompt.py  # expect 0
cd ../..
```
Expected: first ≥ 1, second `0`. If the second is non-zero, find and remove the residual `plan_context`/`PLAN_SUMMARY` token (likely in a comment).

### Task 5: Re-aim `run_codex_reviewer.sh` (rename + spec discovery + AC extraction + kill switch + loud log)

**Files:**
- Modify: `plugins/quality-gates/scripts/run_codex_reviewer.sh`

- [ ] **Step 1: Update the header comment block (lines ~1-27)**

Replace the `Optional env:` stanza (currently the `PLAN_SUMMARY_FILE` lines, ~:12-15) with:

```bash
# Optional env:
#   SPEC_AC_FILE — explicit path to a file containing the spec's Acceptance
#                  Criteria section (escape hatch; normally unset). When unset,
#                  the spec is resolved script-internally via discover-spec.sh
#                  and its AC section is extracted. When no spec exists, the
#                  <spec_context> slot is left empty (v2.0.0 behavior).
#   DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — force the no-spec path even when a
#                  spec exists (empty <spec_context>; loud log emitted).
```

- [ ] **Step 2: Replace the prompt-build stanza (currently ~:51-57)**

Replace this block:

```bash
# Build prompt (plan summary from caller-passed file, or empty).
PLAN_SUMMARY="${PLAN_SUMMARY_FILE:-/dev/null}"
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
       "$DIFF_PATH" "$PLAN_SUMMARY" > "$PROMPT_FILE"; then
  echo '{"codex_failed": true, "reason": "prompt_build_failed"}' > "$OUTPUT_PATH"
  exit 0
fi
```

with:

```bash
# --- Spec AC resolution (v2.1.0: codex review is spec-aware) ----------------
# The spec is the AC truth. Inject only the spec's Acceptance Criteria SECTION
# (not the whole spec — prompt-bloat mitigation, spec R3) into <spec_context>.
# Resolution is script-internal: invocation parity with discover-plan.sh means
# the SKILL allowed-tools list is NOT touched. Graceful + LOUD on every branch.
SPEC_AC="/dev/null"
if [[ "${DEVBREW_QG_DISABLE_SPEC_CONFORMANCE:-}" == "1" ]]; then
  echo "[quality-gates] codex spec context: DISABLED via DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — empty <spec_context>." >&2
elif [[ -n "${SPEC_AC_FILE:-}" && -f "${SPEC_AC_FILE}" ]]; then
  SPEC_AC="$SPEC_AC_FILE"
  echo "[quality-gates] codex spec context: using explicit SPEC_AC_FILE=$SPEC_AC_FILE" >&2
else
  SPEC_JSON="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/discover-spec.sh" 2>/dev/null || true)"
  SPEC_PATH="$(printf '%s' "$SPEC_JSON" | sed -n 's/.*"spec_path":"\([^"]*\)".*/\1/p')"
  if [[ -n "$SPEC_PATH" && -f "$SPEC_PATH" ]]; then
    SPEC_AC="$SCRATCH/spec_ac.md"
    awk '/^#/{is_ac=($0~/[Aa]cceptance [Cc]riteria/);is_b=($0~/^## /||$0~/^# /);if(is_ac){inac=1;print;next}if(inac&&is_b)exit} inac' "$SPEC_PATH" > "$SPEC_AC"
    echo "[quality-gates] codex spec context: injected Acceptance Criteria from $SPEC_PATH" >&2
  else
    echo "[quality-gates] codex spec context: no project spec found (searched docs/superpowers/specs/) — empty <spec_context>, v2.0.0 behavior." >&2
  fi
fi

# Build prompt (spec AC from resolution above, or empty when /dev/null).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
       "$DIFF_PATH" "$SPEC_AC" > "$PROMPT_FILE"; then
  echo '{"codex_failed": true, "reason": "prompt_build_failed"}' > "$OUTPUT_PATH"
  exit 0
fi
```

Note: `$SCRATCH` and `$PROMPT_FILE` are already defined above this block (lines ~43-47); the awk is the exact extraction smoke-tested during planning (matches both `## N. Acceptance Criteria` and `## Acceptance Criteria` styles, stops at the next `## `/`# ` header).

- [ ] **Step 3: Run the codex prompt test (still green — contract unchanged)**

Run: `bash plugins/quality-gates/tests/test_build_codex_prompt.sh`
Expected: PASS — `Total: 7, PASS=7, FAIL=0`.

- [ ] **Step 4: Verify AC8 + AC10 (codex side) mechanically**

Run:
```bash
cd plugins/quality-gates
grep -c 'PLAN_SUMMARY' scripts/run_codex_reviewer.sh   # expect 0
grep -c 'SPEC_AC' scripts/run_codex_reviewer.sh        # expect >= 1
grep -c 'DEVBREW_QG_DISABLE_SPEC_CONFORMANCE' scripts/run_codex_reviewer.sh  # expect >= 1
bash -n scripts/run_codex_reviewer.sh && echo "syntax OK"
cd ../..
```
Expected: `0`, ≥1, ≥1, `syntax OK`.

- [ ] **Step 5: Behavior smoke for the no-spec loud log (AC11 codex side)**

Run (drives the no-spec branch in a temp dir with no specs):
```bash
cd plugins/quality-gates
( export CLAUDE_PLUGIN_ROOT="$(pwd)"
  TMP=$(mktemp -d); cd "$TMP"
  D=$(mktemp); printf 'diff --git a b\n+x\n' > "$D"
  bash "$CLAUDE_PLUGIN_ROOT/scripts/run_codex_reviewer.sh" "$D" "$TMP" "$TMP/out.yaml" 2> "$TMP/err.txt" || true
  grep -q 'no project spec found' "$TMP/err.txt" && echo "AC11(codex): loud log emitted OK" || echo "AC11(codex): MISSING loud log"
  rm -rf "$TMP" "$D" )
cd ../..
```
Expected: `AC11(codex): loud log emitted OK`. (codex itself may fail/`codex_failed` if the CLI is absent — irrelevant here; we only assert the loud log fired before the codex call.)

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/build_codex_prompt.py \
        plugins/quality-gates/scripts/run_codex_reviewer.sh \
        plugins/quality-gates/tests/test_build_codex_prompt.sh
git commit -m "feat(quality-gates): revive codex slot as <spec_context> (AC7,AC8,AC10,AC11)

build_codex_prompt.py: <plan_context>/{{PLAN_SUMMARY}} -> <spec_context>/{{SPEC_AC}}.
run_codex_reviewer.sh: rename PLAN_SUMMARY* -> SPEC_AC*; resolve spec via
discover-spec.sh + awk-extract AC section; kill switch + loud fallback log.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — `test-scope-validator` re-aim (Runtime gate)

### Task 6: Add `ac_coverage` schema-contract + no-spec fixtures to the behavior test

**Files:**
- Modify: `plugins/quality-gates/tests/test_test_scope_validator_behavior.py`

> Note: the `agent_stub` harness validates *frozen* YAML fixtures — it does not dispatch the real agent. These additions lock the `ac_coverage` SCHEMA the persona must emit (Deferred ②: `ac_coverage` is a mapping `{note, items[]}`; each item `{id, status, covered_by}`, `status ∈ {covered, uncovered}`). The persona edit in Task 7 is what makes the live agent conform; that side is checked by the mechanical greps in Task 7 Step 6.

- [ ] **Step 1: Append two test functions + two fixtures**

Append to `plugins/quality-gates/tests/test_test_scope_validator_behavior.py` (after the existing `test_AC47_*` function):

```python

# --- v2.1.0: ac_coverage advisory block (spec present) + no-spec fallback ---

TEST_SCOPE_WITH_AC = """
test_scope_verdicts:
  - file: tests/test_foo.py
    classification: aligned
    evidence: matches AC3 behavior
ac_coverage:
  note: "advisory only — does not block the Runtime gate"
  items:
    - id: AC1
      status: covered
      covered_by: ["tests/test_foo.py::test_ac1"]
    - id: AC2
      status: uncovered
      covered_by: []
summary: 1 aligned, 0 outdated-suspicion, 0 cherry-pick-suspicion, 0 unclear
"""

TEST_SCOPE_NO_SPEC = """
test_scope_verdicts:
  - file: tests/test_foo.py
    classification: aligned
    evidence: matches plan item P3
summary: 1 aligned, 0 outdated-suspicion, 0 cherry-pick-suspicion, 0 unclear
"""


def test_ac_coverage_schema_when_spec_present():
    """When a spec is found, ac_coverage carries per-AC verdicts + advisory note."""
    parsed = run_agent_stub("test-scope-validator", "p", TEST_SCOPE_WITH_AC)
    assert_yaml_schema(
        parsed,
        required_keys=["test_scope_verdicts", "ac_coverage", "summary"],
    )
    ac = parsed["ac_coverage"]
    assert_yaml_schema(ac, required_keys=["note", "items"])
    # AC5: note declares advisory posture (two stable tokens — robust to dash glyph).
    assert "advisory only" in ac["note"]
    assert "does not block" in ac["note"]
    for item in ac["items"]:
        assert_yaml_schema(
            item,
            required_keys=["id", "status", "covered_by"],
            enum={"status": ["covered", "uncovered"]},
        )


def test_fallback_omits_ac_coverage_when_no_spec():
    """No spec -> ac_coverage omitted; plan-based per-file verdicts still emitted."""
    parsed = run_agent_stub("test-scope-validator", "p", TEST_SCOPE_NO_SPEC)
    assert_yaml_schema(parsed, required_keys=["test_scope_verdicts", "summary"])
    assert "ac_coverage" not in parsed
```

- [ ] **Step 2: Run the behavior test**

Run: `python3 plugins/quality-gates/tests/test_test_scope_validator_behavior.py`
If it reports nothing / exits 0, the file may rely on pytest collection. Run instead:
```bash
python3 -m pytest plugins/quality-gates/tests/test_test_scope_validator_behavior.py -q 2>&1 | tail -5
```
Expected: all tests pass (the new schema-contract fixtures are internally consistent). If `pytest` is unavailable, run `python3 -c "import sys; sys.path.insert(0,'plugins/quality-gates/tests'); import test_test_scope_validator_behavior as t; t.test_ac_coverage_schema_when_spec_present(); t.test_fallback_omits_ac_coverage_when_no_spec(); print('OK')"`.

### Task 7: Edit `test-scope-validator.md` (split inputs, redefine cherry-pick, ac_coverage, fallback, kill switch)

**Files:**
- Modify: `plugins/quality-gates/agents/test-scope-validator.md`

- [ ] **Step 1: Update the frontmatter `<example>` block (line ~23)**

Replace:
```
  <example>Context: Runtime gate Step 2.5 — skill provides plan_path,
  filtered diff, and candidate_test_files.
  user: "Validate that the candidate test files match the planned scope
  of the diff."
  assistant: "I'll read each candidate test file, compare its assertions
  to the plan items and changed behavior in the diff, and emit a
  test_scope_verdicts YAML block."</example>
```
with:
```
  <example>Context: Runtime gate Step 2.5 — skill provides spec_path and
  plan_path, filtered diff, and candidate_test_files.
  user: "Validate that the candidate test files match the planned scope
  of the diff."
  assistant: "I'll read each candidate test file, compare its assertions
  to the spec acceptance criteria (primary) and plan items (secondary
  hint) and changed behavior in the diff, and emit a test_scope_verdicts
  YAML block (plus an advisory ac_coverage block when a spec is found)."</example>
```

- [ ] **Step 2: Split the fused input declaration (line ~54)**

Replace the single line:
```
- `plan_path`: path to the spec/plan markdown (auto = `scripts/discover-plan.sh`; may be absent)
```
with:
```
- `spec_path`: path to the project **spec** markdown — the Acceptance Criteria truth, your PRIMARY reference axis (auto = `scripts/discover-spec.sh`; may be absent, or the literal `none` when the SKILL disabled spec conformance). When present, you also emit an `ac_coverage` block (Step 3).
- `plan_path`: path to the **plan** markdown — a SECONDARY implementation-method hint, not the truth (auto = `scripts/discover-plan.sh`; may be absent)
```

- [ ] **Step 3: Add a `spec_path` cross-reference to Step 1 (line ~63-65)**

Replace:
```
3. Cross-reference with:
   - `plan_path` (auto = discover-plan.sh) — what features were planned, if a plan file exists
   - the `## Current Diff` — what symbols/behaviors were added/changed/removed
```
with:
```
3. Cross-reference with:
   - `spec_path` (auto = discover-spec.sh) — the **Acceptance Criteria the code must satisfy** (your primary truth axis), if a spec file exists
   - `plan_path` (auto = discover-plan.sh) — what features were planned (secondary implementation-method hint), if a plan file exists
   - the `## Current Diff` — what symbols/behaviors were added/changed/removed
```

- [ ] **Step 4: Redefine cherry-pick-suspicion (line ~75)**

Replace:
```
| `cherry-pick-suspicion` | Assertions are tautological (`assert True`, `assert obj is not None` as the only assertion in a test function) OR coverage exists but the behavior tested is orthogonal to plan scope |
```
with:
```
| `cherry-pick-suspicion` | Assertions are tautological (`assert True`, `assert obj is not None` as the only assertion in a test function) OR coverage exists but the behavior tested is **orthogonal to spec acceptance criteria** scope (plan scope is only a secondary hint when no spec is present) |
```

- [ ] **Step 5: Add the `ac_coverage` block + no-spec fallback to Step 3 (after the existing YAML block, before "## Notes")**

Insert this subsection immediately before the `## Notes` heading (currently line ~100):

```markdown
## Step 3.5: Spec AC coverage (only when `spec_path` resolves to a real spec)

If `spec_path` is present (not absent, not the literal `none`), read it and
extract its Acceptance Criteria. Then **append** an `ac_coverage` block to the
SAME YAML document, after `summary:`. This is your PRIMARY axis — the per-file
verdicts above are scope hygiene; this block answers "does the shipped
code/test set cover what the spec promised?"

```yaml
ac_coverage:
  note: "advisory only — does not block the Runtime gate"
  items:
    - id: AC1
      status: covered          # covered | uncovered
      covered_by: ["tests/test_x.py::test_ac1"]
    - id: AC2
      status: uncovered
      covered_by: []
```

Rules:
- `status` is exactly `covered` or `uncovered` — no third value, no numeric score.
- `covered_by` is a list of test refs (file or file::test); `[]` when uncovered.
- The `note` line MUST contain the literal phrase `advisory only — does not block`.
- Bias toward `uncovered` only when you genuinely cannot find a covering test;
  prefer focusing on ACs whose scope overlaps the `## Current Diff` (spec R1 —
  stale ACs far from the diff are noise).

**No-spec fallback (loud).** If `spec_path` is absent or the literal `none`
(the SKILL passes `none` when `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`), do NOT
emit `ac_coverage`. Instead, emit exactly one diagnostic line as prose BEFORE
your YAML block (the "one YAML block, nothing after it" rule forbids trailing
prose, not a leading diagnostic):

> `[test-scope-validator] no spec found (spec_path absent) — AC coverage skipped; per-file scope is plan-based only (v2.0.0 behavior).`

This keeps the no-spec path functionally identical to v2.0.0 while making the
downgrade visible (spec R4 — never let a missing spec read as "checked").
```

- [ ] **Step 6: Verify AC4, AC5(grep side), AC6, AC11(validator side), AC14 mechanically**

Run:
```bash
cd plugins/quality-gates
echo "AC4a (fusion gone):"; grep -c 'spec/plan markdown' agents/test-scope-validator.md   # expect 0
echo "AC4b (spec_path >=3):"; grep -c 'spec_path' agents/test-scope-validator.md            # expect >= 3
echo "AC4c (plan_path >=1):"; grep -c 'plan_path' agents/test-scope-validator.md            # expect >= 1
echo "AC5 (advisory note literal):"; grep -c 'advisory only — does not block' agents/test-scope-validator.md  # expect >= 1
echo "AC5 (fields):"; grep -cE 'covered_by' agents/test-scope-validator.md                  # expect >= 1
echo "AC6 (cherry-pick redefinition):"; grep -cE 'orthogonal to.{0,40}(spec|acceptance criteria)' agents/test-scope-validator.md  # expect >= 1
echo "AC11 (validator loud log):"; grep -c 'no spec found' agents/test-scope-validator.md   # expect >= 1
echo "AC14 (isolation intact):"; grep -c 'disallowedTools' agents/test-scope-validator.md   # expect >= 1
cd ../..
```
Expected: `0`, ≥3, ≥1, ≥1, ≥1, ≥1, ≥1, ≥1. (The AC5 literal grep uses em-dash U+2014; the persona text in Step 5 uses the same glyph — keep them identical.)

- [ ] **Step 7: Confirm the frontmatter test still passes**

Run: `bash plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh`
Expected: PASS (we never touched the frontmatter tool lists).

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/agents/test-scope-validator.md \
        plugins/quality-gates/tests/test_test_scope_validator_behavior.py
git commit -m "feat(quality-gates): re-aim test-scope-validator to spec AC (AC4,AC5,AC6,AC11)

Split fused spec/plan input into spec_path (primary AC truth) + plan_path
(secondary hint); redefine cherry-pick-suspicion vs spec AC scope; add advisory
ac_coverage block (never blocks); loud no-spec fallback. disallowedTools intact.

Fixes test-scope-validator.md:54 spec/plan fusion.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 — SKILL wiring

### Task 8: Wire `spec_path` into `SKILL.md` (argument, dispatch, kill-switch translation, codex note)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

- [ ] **Step 1: Add the `spec_path` argument (Arguments section, after the `plan_path` bullet, ~:137-138)**

After:
```
- `plan_path` (optional): defaults to "auto" (`scripts/discover-plan.sh`).
  Consumed only by the Runtime gate's test-scope-validator (no Gate-1 verifier).
```
insert:
```
- `spec_path` (optional): defaults to "auto" (`scripts/discover-spec.sh`).
  The project spec is the Acceptance Criteria truth. Consumed by the Runtime
  gate's test-scope-validator (primary AC axis → advisory `ac_coverage`) and by
  the Review gate codex path (spec AC injected into `<spec_context>`,
  script-internal in `run_codex_reviewer.sh`). If
  `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`, pass `spec_path: none` to the
  test-scope-validator dispatch — this forces the no-spec fallback (ac_coverage
  omitted, plan-based scope only). All spec behavior is advisory; it never
  blocks a gate.
```

- [ ] **Step 2: Add `spec_path:` to the test-scope-validator dispatch (Runtime gate, ~:373-377)**

Replace the dispatch prompt body:
```
  prompt: "Validate test scope against current diff and plan items.
    project_dir: \"$project_dir\"
    plan_path: <path or 'auto'>
    candidate_test_files: <list from scope-detection step>"
```
with:
```
  prompt: "Validate test scope against current diff, spec acceptance criteria, and plan items.
    project_dir: \"$project_dir\"
    spec_path: <path or 'auto'; pass 'none' if DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1>
    plan_path: <path or 'auto'>
    candidate_test_files: <list from scope-detection step>"
```
(`project_dir:` stays the first dispatch field, so the reviewer-dispatch-contract proximity check — `project_dir:` within 10 lines of `subagent_type:` — still holds.)

- [ ] **Step 3: Add a one-line codex spec-injection note (Review gate section, after the codex-reviewer mention ~:210-213)**

After the paragraph describing `pr-review-toolkit:code-reviewer` and the codex reviewer dispatch, add:
```
   The codex reviewer additionally injects the project spec's Acceptance
   Criteria into its `<spec_context>` slot — resolved **script-internally** by
   `run_codex_reviewer.sh` (via `discover-spec.sh`), so no `spec_path` dispatch
   field and no `allowed-tools` change are needed here (invocation parity with
   the existing `discover-plan.sh` mechanism). `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`
   empties the slot.
```

- [ ] **Step 4: Bump the two cosmetic version headings**

Replace `# Quality Gates — In-Turn Orchestrator (v2.0.0)` (line ~36) with `(v2.1.0)`, and `## Quality Gates Pipeline — Complete (v2.0.0)` (line ~460) with `(v2.1.0)`. (Confirmed during planning: no test pins these strings.)

- [ ] **Step 5: Verify AC9 mechanically (including the corrected portable parity check)**

Run:
```bash
cd plugins/quality-gates
echo "AC9a (spec_path >=2):"; grep -cE 'spec_path' skills/quality-pipeline/SKILL.md   # expect >= 2
echo "AC9b (frontmatter parity — discover-spec absent):"
awk '/^---$/{c++; next} c==1' skills/quality-pipeline/SKILL.md | grep -c 'discover-spec'   # expect 0
echo "AC9c (frontmatter parity — discover-plan absent):"
awk '/^---$/{c++; next} c==1' skills/quality-pipeline/SKILL.md | grep -c 'discover-plan'   # expect 0
echo "AC10 (validator-path kill switch present):"; grep -c 'DEVBREW_QG_DISABLE_SPEC_CONFORMANCE' skills/quality-pipeline/SKILL.md  # expect >= 1
cd ../..
```
Expected: ≥2, `0`, `0`, ≥1. (AC9b/c use the portable `awk` form — see "Deviations from the Spec" #1.)

- [ ] **Step 6: Confirm orchestration tests still pass**

Run from repo root:
```bash
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | tail -3
bash plugins/quality-gates/tests/test_skill_orchestration.sh 2>&1 | tail -3
bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh 2>&1 | tail -3
bash plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh 2>&1 | tail -3
```
Expected: all PASS (we only added prose + a dispatch field + a bumped heading; ordering/proximity invariants and the Bash allowlist are unchanged). If any newly fails, it was not in the baseline set — fix before committing.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "feat(quality-gates): wire spec_path into SKILL (AC9,AC10)

Document spec_path arg; add spec_path: to test-scope-validator dispatch;
DEVBREW_QG_DISABLE_SPEC_CONFORMANCE -> spec_path: none translation; codex
spec-injection note (invocation parity — no allowed-tools change). Version
headings -> v2.1.0.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 — Meta, docs, isolation guards

### Task 9: README — "Spec Discovery Sources" + C66 in "Principles Instantiated"

**Files:**
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: Add the C66 bullet to "Principles Instantiated" (인스턴스화한 원칙)**

Add this bullet at the end of the "인스턴스화한 원칙" list (right before the `## 구조` heading):
```
- **C66 (Linked Artifact Flow) — spec을 truth로 instantiate** (v2.1.0) — qg가 처음으로 사용자 프로젝트 spec을 읽어(`scripts/discover-spec.sh`) test-scope-validator의 기준 축을 plan items → **spec Acceptance Criteria**로 전환하고, AC별 커버리지를 advisory `ac_coverage` 블록으로 surface하며, codex 경로(`run_codex_reviewer.sh`)가 spec AC를 `<spec_context>`에 주입. cycle 위계(spec=truth ⊃ plan=구현 방식)를 instantiate — spec→test 커버리지를 역방향 walk. plan은 구현-방식 보조 hint로 강등(제거 아님; `discover-plan.sh` byte-identical). **advisory only — Runtime gate를 block하지 않음.** spec 부재 시 loud log + v2.0.0 기능 동작 fallback. kill switch `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`.
```

- [ ] **Step 2: Add the "Spec Discovery Sources" section (after "Plan Discovery Sources", before "## 사전 요건")**

Insert after the `## Plan Discovery Sources (Runtime gate test-scope-validator)` section (it ends just before `## 사전 요건`):
```markdown
## Spec Discovery Sources (Runtime gate test-scope-validator + Review gate codex)

qg는 사용자 프로젝트의 **spec**(Acceptance Criteria의 truth)을 다음 우선순위로 탐색합니다 (`scripts/discover-spec.sh`; 위→아래 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--spec <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/specs/*.md` (project-local) | `^#+ .*Acceptance Criteria` 섹션 헤더 1개 이상 |

plan과 달리 **legacy-global 소스는 없습니다** — spec은 프로젝트 artifact (글로벌 위치 관행 부재). 자격 파일 중 mtime 가장 최근이 선택됩니다.

**advisory only.** spec이 발견되면 test-scope-validator가 `ac_coverage` 블록(AC별 covered/uncovered + covered_by 테스트 ref)을 emit하고, codex 경로(`run_codex_reviewer.sh`)가 spec의 AC 섹션을 `<spec_context>`에 script-internal로 주입합니다. 어느 경우에도 Runtime gate verdict를 **block하지 않습니다.** spec이 없으면 loud log를 출력하고 v2.0.0 동작(plan-기반 scope)으로 fallback합니다.

**kill switch:** `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` — spec이 있어도 no-spec 경로를 강제 (ac_coverage 생략, codex `<spec_context>` 비움; validator는 plan-기반 계속).

**Soft dependency:** project-local source는 `superpowers:brainstorming` / `spec-distill`이 spec을 저장하는 경로 (`docs/superpowers/specs/`)와 동일합니다.

알고리즘은 `scripts/discover-spec.sh`에 분리되어 `tests/test_discover_spec.sh` fixture로 검증됩니다.
```

- [ ] **Step 3: (optional consistency) add discover-spec.sh to the scripts/ tree listing**

In the `## 구조` directory tree, add a line under `scripts/` next to `discover-plan.sh`:
```
│   ├── discover-spec.sh                      # Spec 파일 우선순위 탐색 (test-scope-validator + codex; AC-섹션 적격성)
```

- [ ] **Step 4: Verify AC12 mechanically**

Run:
```bash
cd plugins/quality-gates
grep -c 'Spec Discovery' README.md   # expect >= 1
grep -c 'C66' README.md              # expect >= 1
cd ../..
```
Expected: ≥1, ≥1.

- [ ] **Step 5: Confirm the README state-diagram test still passes**

Run: `bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh 2>&1 | tail -3`
Expected: PASS (unless it was in the baseline red set — check Phase 0). The added sections do not touch the state diagram.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/README.md
git commit -m "docs(quality-gates): Spec Discovery Sources + C66 instantiation (AC12)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 10: Version bump + CHANGELOG

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: Bump `plugin.json` version**

In `plugins/quality-gates/.claude-plugin/plugin.json`, change `"version": "2.0.0"` to `"version": "2.1.0"`.

- [ ] **Step 2: Prepend the v2.1.0 CHANGELOG entry**

Insert immediately after the header block (before `## [2.0.0] — 2026-05-30`):
```markdown
## [2.1.0] — 2026-05-31

qg가 처음으로 **사용자 프로젝트 spec을 단일 truth로 read**. cycle 위계(spec=truth ⊃
plan=구현 방식)를 instantiate — 그동안 qg는 plan만 읽고 spec은 한 번도 읽지 않아
`test-scope-validator`가 입력을 "spec/plan"으로 융합하고 있었음. spec-conformance는
코드가 *존재*해야만 가능하므로 review/verify 단계인 qg만 닫을 수 있는 비중복 루프
(plan-verify를 v2.0.0이 제거한 것과 비대칭). **advisory only — gate를 block하지 않음.**

### Added
- **`scripts/discover-spec.sh`** + **`tests/test_discover_spec.sh`**: 프로젝트 spec
  우선순위 탐색(`--spec` → `docs/superpowers/specs/*.md`). AC-섹션 적격성 + 최신 mtime
  tiebreak. legacy-global 소스 없음(spec은 프로젝트 artifact). `discover-plan.sh` 거울.
- **`test-scope-validator` `ac_coverage` advisory 블록**: spec 발견 시 AC별
  covered/uncovered + `covered_by` 테스트 ref. note "advisory only — does not block".
- **codex `<spec_context>` 슬롯**: v2.0.0에서 `/dev/null`로 죽어 있던 `<plan_context>`
  슬롯을 부활 — `run_codex_reviewer.sh`가 spec AC 섹션을 script-internal로 추출·주입.
- **kill switch `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`**: spec이 있어도 no-spec 경로
  강제(ac_coverage 생략, codex spec context 비움; validator는 plan-기반 계속).
- **README "Spec Discovery Sources"** 절 + "Principles Instantiated"에 **C66**.

### Changed
- **`test-scope-validator` 기준 축 전환**: 입력 융합(`spec/plan markdown`)을
  `spec_path`(AC truth, primary) + `plan_path`(구현-방식 보조 hint)로 분리.
  cherry-pick-suspicion 기준이 "plan scope" → "spec acceptance criteria scope에
  orthogonal"로 재정의. plan은 강등(제거 아님).
- **`build_codex_prompt.py`**: `<plan_context>`/`{{PLAN_SUMMARY}}`/`<plan_summary_file>`
  → `<spec_context>`/`{{SPEC_AC}}`/`<spec_ac_file>`.
- **`run_codex_reviewer.sh`**: `PLAN_SUMMARY_FILE`/`PLAN_SUMMARY` → `SPEC_AC_FILE`/`SPEC_AC`;
  spec discovery + AC 섹션 awk 추출 + spec 부재 시 loud log를 script-internal로 추가.
- **`SKILL.md`**: `spec_path` 인자 문서화 + test-scope-validator dispatch에 `spec_path:` 줄.
  `allowed-tools` frontmatter는 불변(invocation parity).

### Fixed
- **`agents/test-scope-validator.md:54` spec/plan 융합 해소**: 입력을 문자 그대로
  "path to the spec/plan markdown"으로 적어 spec(truth)과 plan(파생 hint)을 교환 가능한
  한 덩어리로 취급하던 버그 수정 — 위계 복원.

### Unchanged (의도적 보존)
- **`scripts/discover-plan.sh` + `tests/test_discover_plan.sh`**: byte-identical.
  plan *discovery*는 존속(보조 hint), plan *verify*만 v2.0.0이 제거.
- **철학 문서**: 새 P#/AP# 없음 — C66 + Law 1 instantiation(devbrew design-lightness).
- **reviewer agent `disallowedTools` 격리**: 불변(Law 2). spec 읽기는 read-only.
- **advisory invariant**: `ac_coverage`·spec-conformance는 Runtime gate를 block 안 함.
```

- [ ] **Step 3: Verify AC15, AC16 mechanically**

Run:
```bash
cd plugins/quality-gates
grep -c '"version": "2.1.0"' .claude-plugin/plugin.json     # expect 1
grep -c '## \[2.1.0\] — 2026-05-31' CHANGELOG.md            # expect 1
grep -c 'test-scope-validator.md:54' CHANGELOG.md           # expect >= 1 (AC16: Fixed names the fusion)
python3 -c "import json;json.load(open('.claude-plugin/plugin.json'));print('plugin.json valid JSON')"
cd ../..
```
Expected: `1`, `1`, ≥1, `plugin.json valid JSON`.

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "chore(quality-gates): v2.1.0 — plugin.json bump + CHANGELOG (AC15,AC16)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6 — Final verification (all ACs + regression)

### Task 11: Full mechanical sweep + regression gate

**Files:** none modified (verification only; commit any doc fix discovered).

- [ ] **Step 1: AC13 — philosophy doc untouched**

Run:
```bash
git diff --quiet HEAD -- docs/philosophy/devbrew-harness-philosophy.md && echo "AC13: philosophy byte-identical OK" || echo "AC13: FAIL — philosophy changed"
```
Expected: `AC13: philosophy byte-identical OK`.

- [ ] **Step 2: AC14 — all four reviewer agents keep isolation**

Run:
```bash
cd plugins/quality-gates
n=$(grep -lE 'disallowedTools' agents/adversarial.md agents/runtime-verifier.md agents/security-reviewer.md agents/test-scope-validator.md | wc -l | tr -d ' ')
[ "$n" = "4" ] && echo "AC14: 4/4 reviewers isolated OK" || echo "AC14: FAIL ($n/4)"
cd ../..
```
Expected: `AC14: 4/4 reviewers isolated OK`.

- [ ] **Step 3: AC3 byte-identical guard (final)**

Run:
```bash
git diff --quiet HEAD -- plugins/quality-gates/scripts/discover-plan.sh && echo "AC3: discover-plan.sh byte-identical OK" || echo "AC3: FAIL"
git diff --quiet HEAD -- plugins/quality-gates/tests/test_discover_plan.sh && echo "AC3: test_discover_plan.sh byte-identical OK" || echo "AC3: FAIL"
```
Expected: both OK.

- [ ] **Step 4: Run the full AC mechanical sweep in one pass**

Run from repo root (this aggregates every grep-based AC):
```bash
cd plugins/quality-gates
echo "AC1:";  test -x scripts/discover-spec.sh && echo " exec OK"
echo "AC4:";  echo "  fusion=$(grep -c 'spec/plan markdown' agents/test-scope-validator.md) spec_path=$(grep -c 'spec_path' agents/test-scope-validator.md) plan_path=$(grep -c 'plan_path' agents/test-scope-validator.md)"
echo "AC6:";  echo "  $(grep -cE 'orthogonal to.{0,40}(spec|acceptance criteria)' agents/test-scope-validator.md)"
echo "AC7:";  echo "  spec=$(grep -c 'spec_context\|SPEC_AC' scripts/build_codex_prompt.py) plan=$(grep -c 'plan_context\|PLAN_SUMMARY' scripts/build_codex_prompt.py)"
echo "AC8:";  echo "  PLAN_SUMMARY=$(grep -c 'PLAN_SUMMARY' scripts/run_codex_reviewer.sh) SPEC_AC=$(grep -c 'SPEC_AC' scripts/run_codex_reviewer.sh)"
echo "AC9:";  echo "  spec_path=$(grep -cE 'spec_path' skills/quality-pipeline/SKILL.md) fm_spec=$(awk '/^---$/{c++;next}c==1' skills/quality-pipeline/SKILL.md|grep -c discover-spec) fm_plan=$(awk '/^---$/{c++;next}c==1' skills/quality-pipeline/SKILL.md|grep -c discover-plan)"
echo "AC10:"; echo "  $(grep -rc 'DEVBREW_QG_DISABLE_SPEC_CONFORMANCE' . | grep -v ':0' | wc -l | tr -d ' ') files reference kill switch"
echo "AC12:"; echo "  SpecDiscovery=$(grep -c 'Spec Discovery' README.md) C66=$(grep -c 'C66' README.md)"
echo "AC15:"; echo "  $(grep -c '\"version\": \"2.1.0\"' .claude-plugin/plugin.json)"
echo "AC16:"; echo "  $(grep -c '## \[2.1.0\]' CHANGELOG.md) fixed-names-fusion=$(grep -c 'test-scope-validator.md:54' CHANGELOG.md)"
cd ../..
```
Expected: AC1 exec OK; AC4 fusion=0, spec_path≥3, plan_path≥1; AC6 ≥1; AC7 spec≥1, plan=0; AC8 PLAN_SUMMARY=0, SPEC_AC≥1; AC9 spec_path≥2, fm_spec=0, fm_plan=0; AC10 ≥1 files; AC12 both ≥1; AC15 =1; AC16 ≥1 and fixed-names-fusion≥1.

- [ ] **Step 5: AC17 — regression gate (no new reds)**

Run from repo root:
```bash
BASE="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-baseline-reds.txt"
NOW="${CLAUDE_JOB_DIR:-/tmp}/tmp/qg-now-reds.txt"; : > "$NOW"
for t in plugins/quality-gates/tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 || echo "FAIL(sh): $(basename "$t")" >> "$NOW"
done
for t in plugins/quality-gates/tests/test_*.py; do
  python3 "$t" >/dev/null 2>&1 || echo "FAIL(py): $(basename "$t")" >> "$NOW"
done
echo "=== NEW reds (in NOW but not BASELINE — must be empty) ==="
comm -13 <(sort "$BASE") <(sort "$NOW")
echo "=== (informational) reds fixed since baseline ==="
comm -23 <(sort "$BASE") <(sort "$NOW")
```
Expected: the "NEW reds" list is **empty**. (The new `test_discover_spec.sh`, the rewritten `test_build_codex_prompt.sh`, and the extended behavior test must all be green; any new failure here is a regression to fix before finishing.) Note: `test_test_scope_validator_behavior.py` and other `*_behavior.py` files may need `python3 -m pytest <file>` rather than `python3 <file>` — if a `*_behavior.py` appears as a new red, re-run it under pytest to confirm it is genuinely green before treating it as a regression.

- [ ] **Step 6: Runtime sanity (non-binding, spec §7 Runtime)**

These are behavioral smoke checks, NOT a substitute for the mechanical greps above. Optional but recommended if `codex`/a real spec branch is handy:
- On this branch (a spec exists at `docs/superpowers/specs/`), `/qg runtime` → test-scope-validator output should include an `ac_coverage` block, and the codex stderr should log `injected Acceptance Criteria`.
- `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 /qg runtime` → no `ac_coverage`; codex stderr logs `DISABLED via DEVBREW_QG_DISABLE_SPEC_CONFORMANCE`.

- [ ] **Step 7: Final commit (only if Step 4/5 surfaced a doc fix)**

If any mechanical assertion needed a fix, commit it:
```bash
git add -A plugins/quality-gates
git commit -m "fix(quality-gates): final AC sweep corrections (v2.1.0)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run by the plan author, not a subagent)

**1. Spec coverage — every AC maps to a task:**

| AC | Where verified |
|---|---|
| AC1 (discover-spec exists/JSON/exit) | Task 1-2 (test) + Task 2 Step 5 + Task 11 Step 4 |
| AC2 (priority + AC-eligibility + mtime) | Task 1 (T2/T3/T6/T8) |
| AC3 (discover-plan byte-identical) | Task 2 Step 4 + Task 11 Step 3 |
| AC4 (split inputs; :23/:54/:64) | Task 7 Steps 1-3 + Step 6 |
| AC5 (ac_coverage fields + note; fallback) | Task 6 + Task 7 Step 5 + Step 6 |
| AC6 (cherry-pick redefinition) | Task 7 Step 4 + Step 6 grep |
| AC7 (build_codex_prompt spec slot) | Task 4 Step 3 |
| AC8 (run_codex rename + callsite) | Task 5 Steps 2,4 + Task 3 test |
| AC9 (SKILL spec_path + parity) | Task 8 Steps 1-2,5 (portable awk) |
| AC10 (kill switch both paths) | Task 5 (codex) + Task 8 (validator) |
| AC11 (loud log both paths) | Task 5 Step 5 (codex) + Task 7 Step 5/6 (validator) |
| AC12 (README Spec Discovery + C66) | Task 9 |
| AC13 (philosophy untouched) | Task 11 Step 1 |
| AC14 (4 reviewers isolated) | Task 11 Step 2 |
| AC15 (plugin.json 2.1.0) | Task 10 Step 1,3 |
| AC16 (CHANGELOG v2.1.0 + Fixed) | Task 10 Step 2,3 |
| AC17 (new tests green, no new reds) | Task 0 + Task 11 Step 5 |

No AC is unmapped.

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" — every code step shows full content. The two carried-forward Deferred items (① extraction location, ④ kill-switch location) are resolved concretely in Tasks 5 and 8; Deferred ② (ac_coverage shape) is locked in Task 6/7; Deferred ⑥ (phase order) is the Phase 1→6 sequence; Deferred ⑦ (line anchors) is handled by the "grep is authoritative" deviation note.

**3. Type/identifier consistency:** `spec_path` (dispatch field + persona input), `SPEC_AC`/`SPEC_AC_FILE` (shell var), `{{SPEC_AC}}`/`<spec_context>`/`<spec_ac_file>` (python), `ac_coverage.{note,items[].{id,status,covered_by}}` (YAML), `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE` (kill switch) — all spelled identically across tasks. The codex no-spec path passes `/dev/null` → `build_codex_prompt.py` `is_file()` → empty `<spec_context>` (same invariant the existing test_build_codex_prompt.sh Case 1 protects, re-aimed).
