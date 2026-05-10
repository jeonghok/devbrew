# qg Gate 1 Plan Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the path mismatch where `quality-gates:plan-verifier` only scans `~/.claude/plans/` while `superpowers:writing-plans` saves to `docs/superpowers/plans/`. Add deterministic source-priority discovery (project-local → legacy fallback) extracted into a unit-tested bash script.

**Architecture:** Extract discovery into `scripts/discover-plan.sh` (priority list + checkbox-eligibility filter, single-line JSON output, exit codes 0/1/2). Rewrite `agents/plan-verifier.md` Step 1 to invoke the script and parse its JSON. Add 9 fixture-based bash tests. Bump plugin version 1.6.3 → 1.7.0 (minor — new surface).

**Tech Stack:** bash 3.2+ (macOS default), POSIX `find` / `stat` / `grep`, no external deps. Tests use the same bash assertion pattern as existing `tests/test_setup_qg.sh`. Markdown for agent / README / CHANGELOG.

**Spec:** `docs/superpowers/specs/2026-05-10-qg-plan-discovery-design.md` (commit `f469ed1`).

---

## Task 1: Branch + failing test scaffold

**Files:**
- Branch: `feature/qg-plan-discovery` from `main`
- Create: `plugins/quality-gates/tests/test_discover_plan.sh`

- [ ] **Step 1: Create branch from main**

```bash
git checkout main
git pull origin main
git checkout -b feature/qg-plan-discovery
```

- [ ] **Step 2: Write the test file with all 9 cases (script does not yet exist — tests will fail)**

Create `plugins/quality-gates/tests/test_discover_plan.sh`:

```bash
#!/usr/bin/env bash
# Tests for scripts/discover-plan.sh
# Uses bash assertions; no external test framework.
# Mirrors style of test_setup_qg.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/discover-plan.sh"
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

# Helper: build a tmp HOME + project root, run script, capture stdout + exit code
run_in_env() {
  # Args: project_dir, [extra script args...]
  local proj="$1"; shift
  cd "$proj"
  HOME="$proj/home" bash "$SCRIPT" "$@" 2>/tmp/discover-plan-err
  return $?
}

write_plan() {
  # write_plan <path> <unchecked_count> <checked_count>
  local path="$1" unchecked="$2" checked="$3"
  mkdir -p "$(dirname "$path")"
  : > "$path"
  for ((i=0; i<unchecked; i++)); do echo "- [ ] item $i" >> "$path"; done
  for ((i=0; i<checked; i++)); do echo "- [x] item $i" >> "$path"; done
}

# --- Test 1: both sources empty → exit 1, source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans" "$TMPDIR/home/.claude/plans"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T1: exit 1 when both empty"
assert_contains "$OUT" '"source":"none"' "T1: source=none"
cd / && rm -rf "$TMPDIR"

# --- Test 2: project-local has 1 unchecked plan → source=project-local ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/foo.md" 3 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T2: exit 0 with project-local plan"
assert_contains "$OUT" '"source":"project-local"' "T2: source=project-local"
assert_contains "$OUT" "foo.md" "T2: plan_path mentions foo.md"
cd / && rm -rf "$TMPDIR"

# --- Test 3: project-local all-checked + legacy unchecked → project-local wins ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/done.md" 0 5
write_plan "$TMPDIR/home/.claude/plans/old.md" 3 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T3: exit 0"
assert_contains "$OUT" '"source":"project-local"' "T3: priority over checkbox status"
assert_contains "$OUT" "done.md" "T3: picks all-checked project-local plan"
cd / && rm -rf "$TMPDIR"

# --- Test 4: project-local empty + legacy has 1 → source=legacy-global ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/docs/superpowers/plans"
write_plan "$TMPDIR/home/.claude/plans/legacy.md" 2 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T4: exit 0 with legacy plan"
assert_contains "$OUT" '"source":"legacy-global"' "T4: legacy fallback fires"
assert_contains "$OUT" "legacy.md" "T4: legacy plan picked"
cd / && rm -rf "$TMPDIR"

# --- Test 5: project-local has README only (0 checkboxes) → source=none ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
mkdir -p "$TMPDIR/docs/superpowers/plans"
echo "# README" > "$TMPDIR/docs/superpowers/plans/README.md"
echo "Some prose without checkboxes." >> "$TMPDIR/docs/superpowers/plans/README.md"
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "1" "T5: exit 1 when only non-plan files exist"
assert_contains "$OUT" '"source":"none"' "T5: source=none for non-plan file"
cd / && rm -rf "$TMPDIR"

# --- Test 6: --plan <existing> → source=explicit ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/custom.md" 1 0
OUT=$(run_in_env "$TMPDIR" --plan "$TMPDIR/custom.md")
RC=$?
assert_eq "$RC" "0" "T6: exit 0 with --plan to existing file"
assert_contains "$OUT" '"source":"explicit"' "T6: source=explicit"
assert_contains "$OUT" "custom.md" "T6: plan_path is the explicit path"
cd / && rm -rf "$TMPDIR"

# --- Test 7: --plan <nonexistent> → exit 2 ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
OUT=$(run_in_env "$TMPDIR" --plan "/tmp/definitely-does-not-exist-xyz123.md")
RC=$?
assert_eq "$RC" "2" "T7: exit 2 with --plan to nonexistent file"
assert_contains "$OUT" '"source":"none"' "T7: source=none"
assert_contains "$OUT" "does not exist" "T7: reason mentions 'does not exist'"
cd / && rm -rf "$TMPDIR"

# --- Test 8: project-local has 2 unchecked plans → most recent mtime wins ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
write_plan "$TMPDIR/docs/superpowers/plans/older.md" 1 0
sleep 1.1
write_plan "$TMPDIR/docs/superpowers/plans/newer.md" 1 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T8: exit 0"
assert_contains "$OUT" "newer.md" "T8: picks most recently modified"
cd / && rm -rf "$TMPDIR"

# --- Test 9: project-local has 2 zero-checkbox files → falls through to legacy ---
TMPDIR=$(mktemp -d); mkdir -p "$TMPDIR/home/.claude/plans"
echo "no checkboxes" > "$TMPDIR/docs/superpowers/plans/a.md"
mkdir -p "$TMPDIR/docs/superpowers/plans"
echo "also none" > "$TMPDIR/docs/superpowers/plans/b.md"
write_plan "$TMPDIR/home/.claude/plans/legacy.md" 2 0
OUT=$(run_in_env "$TMPDIR")
RC=$?
assert_eq "$RC" "0" "T9: exit 0 (fell through to legacy)"
assert_contains "$OUT" '"source":"legacy-global"' "T9: source=legacy-global after fall-through"
assert_contains "$OUT" "legacy.md" "T9: legacy plan picked"
cd / && rm -rf "$TMPDIR"

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
```

- [ ] **Step 3: Make the test file executable**

```bash
chmod +x plugins/quality-gates/tests/test_discover_plan.sh
```

- [ ] **Step 4: Run tests — confirm they all fail (script does not exist yet)**

```bash
bash plugins/quality-gates/tests/test_discover_plan.sh
```

Expected: every assertion FAILs (because `bash $SCRIPT` errors with "No such file or directory"). The summary should show `0 passed, N failed` (N ≥ 18 — multiple assertions per test). Exit code non-zero. **This is the expected starting state for TDD.**

- [ ] **Step 5: Commit failing tests**

```bash
git add plugins/quality-gates/tests/test_discover_plan.sh
git commit -m "test(qg): add failing tests for plan discovery script"
```

---

## Task 2: Implement `discover-plan.sh`

**Files:**
- Create: `plugins/quality-gates/scripts/discover-plan.sh`
- Test: `plugins/quality-gates/tests/test_discover_plan.sh` (run only)

- [ ] **Step 1: Write `scripts/discover-plan.sh`**

```bash
#!/usr/bin/env bash
# discover-plan.sh — find a plan file using priority list.
# Output (single-line JSON to stdout):
#   {"plan_path":"<absolute-or-empty>",
#    "source":"explicit|project-local|legacy-global|none",
#    "reason":"<human-readable>"}
# Exit codes: 0 = found, 1 = not found, 2 = invalid input
#
# Priority:
#   1. --plan <path>                    (explicit; no fallback if missing)
#   2. ./docs/superpowers/plans/*.md    (project-local)
#   3. $HOME/.claude/plans/*.md         (legacy global)
#
# Within a chosen source: prefer files with at least one '- [ ]' (unchecked
# checkbox), tiebroken by most-recent mtime; else fall back to most-recent
# file that has at least one checkbox of any kind. Files with zero
# checkboxes are not eligible (a non-plan markdown file should never be
# verified as a plan).
#
# Path-escape note: emitted JSON uses %s and assumes plan paths do not
# contain double-quote or backslash characters. This holds for every plan
# produced by superpowers:writing-plans and any sane filesystem layout.

set -u

EXPLICIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      EXPLICIT="${2:-}"
      shift 2
      ;;
    *)
      printf '{"plan_path":"","source":"none","reason":"Unknown argument: %s"}\n' "$1"
      exit 2
      ;;
  esac
done

emit_json() {
  printf '{"plan_path":"%s","source":"%s","reason":"%s"}\n' "$1" "$2" "$3"
}

# Source 1: explicit override (highest priority; no fallback if missing)
if [[ -n "$EXPLICIT" ]]; then
  if [[ -f "$EXPLICIT" ]]; then
    emit_json "$EXPLICIT" "explicit" "Explicit --plan path"
    exit 0
  else
    emit_json "" "none" "Explicit --plan path does not exist: $EXPLICIT"
    exit 2
  fi
fi

# Portable mtime (BSD stat on macOS, GNU stat on Linux)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Pick the best plan from a directory of *.md files.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 1

  local best_unchecked="" best_unchecked_mtime=0
  local best_checked="" best_checked_mtime=0
  local f cb_total cb_unchecked m

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    cb_total=$(grep -cE '^- \[[ xX]\]' "$f" 2>/dev/null || true)
    [[ -z "$cb_total" || "$cb_total" -eq 0 ]] && continue
    cb_unchecked=$(grep -cE '^- \[ \]' "$f" 2>/dev/null || true)
    m=$(get_mtime "$f")

    if [[ -n "$cb_unchecked" && "$cb_unchecked" -gt 0 ]]; then
      if [[ "$m" -gt "$best_unchecked_mtime" ]]; then
        best_unchecked="$f"
        best_unchecked_mtime="$m"
      fi
    else
      if [[ "$m" -gt "$best_checked_mtime" ]]; then
        best_checked="$f"
        best_checked_mtime="$m"
      fi
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  if [[ -n "$best_unchecked" ]]; then
    printf '%s\n' "$best_unchecked"
    return 0
  fi
  if [[ -n "$best_checked" ]]; then
    printf '%s\n' "$best_checked"
    return 0
  fi
  return 1
}

# Source 2: project-local
PROJECT_LOCAL="docs/superpowers/plans"
if PLAN=$(pick_best "$PROJECT_LOCAL"); then
  emit_json "$PLAN" "project-local" "Found in $PROJECT_LOCAL"
  exit 0
fi

# Source 3: legacy global
LEGACY="$HOME/.claude/plans"
if PLAN=$(pick_best "$LEGACY"); then
  emit_json "$PLAN" "legacy-global" "Found in ~/.claude/plans (legacy)"
  exit 0
fi

emit_json "" "none" "No plan file found. Searched: $PROJECT_LOCAL, ~/.claude/plans"
exit 1
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x plugins/quality-gates/scripts/discover-plan.sh
```

- [ ] **Step 3: Run the test suite**

```bash
bash plugins/quality-gates/tests/test_discover_plan.sh
```

Expected: `Results: N passed, 0 failed` (N ≥ 24 — every assertion across 9 tests). Exit code 0.

If any test fails, read the error message, fix the script, and re-run. Common pitfalls:
- BSD vs GNU `stat` — `get_mtime` already handles both
- `grep -c` with no match returns 1 in some shells — `|| true` neutralizes
- `find -maxdepth 1` does not recurse — intentional (matches spec: glob `*.md` not `**/*.md`)

- [ ] **Step 4: Commit the script**

```bash
git add plugins/quality-gates/scripts/discover-plan.sh
git commit -m "feat(qg): add discover-plan.sh with priority-list discovery"
```

---

## Task 3: Rewrite `plan-verifier.md` Step 1

**Files:**
- Modify: `plugins/quality-gates/agents/plan-verifier.md` (Step 1 fully replaced; Step 5 report template gets a `**Source:**` line)

- [ ] **Step 1: Replace `## Step 1: Find the Plan File` block**

In `plugins/quality-gates/agents/plan-verifier.md`, find this block (lines 32-43):

```markdown
## Step 1: Find the Plan File

If `plan_path` is provided and not "auto", use that file directly.

Otherwise, auto-detect:
1. List files in `~/.claude/plans/` sorted by modification time (most recent first)
2. For each file, check if it contains `- [ ]` (unchecked checkbox)
3. Use the first file that has unchecked checkboxes
4. If no file has unchecked checkboxes, use the most recently modified plan file
5. If `~/.claude/plans/` is empty, return verdict SKIP with reason "No plan file found"

Use Glob and Bash tools for this.
```

Replace with:

````markdown
## Step 1: Find the Plan File

Discovery is delegated to a deterministic script (`scripts/discover-plan.sh`)
so the priority list, glob, and checkbox-eligibility filter are unit-tested.
Do not implement these rules yourself — call the script and parse its JSON.

Run via Bash:

```bash
if [[ "$plan_path" == "auto" || -z "$plan_path" ]]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/discover-plan.sh"
else
  "${CLAUDE_PLUGIN_ROOT}/scripts/discover-plan.sh" --plan "$plan_path"
fi
```

The script emits a single-line JSON object on stdout:

```json
{"plan_path":"<absolute-or-empty>","source":"explicit|project-local|legacy-global|none","reason":"<human-readable>"}
```

Exit-code branching:

| Exit | Meaning | Action |
|---|---|---|
| `0` | Plan found | Capture `plan_path` and `source` from JSON. Continue to Step 2. |
| `1` | No plan in any source | Verdict `SKIP` with `reason` from JSON (e.g., `"No plan file found. Searched: docs/superpowers/plans/, ~/.claude/plans"`). Skip Steps 2–5. |
| `2` | `--plan` path is invalid | Verdict `SKIP` with reason `"Explicit --plan path does not exist: <path>"` (use the `reason` field verbatim). Skip Steps 2–5. |

If `source == "legacy-global"`, immediately before the report header in Step 5 emit one warning line:

```
⚠️ Legacy plan source: ~/.claude/plans/. Consider migrating to docs/superpowers/plans/ (where superpowers:writing-plans saves by default).
```

Project-local hits stay silent; explicit hits stay silent.
````

- [ ] **Step 2: Add `**Source:**` line to the Step 5 report template**

Find this block in Step 5:

```markdown
## Plan Verification Report (Gate 1)

**Plan:** [filename]
**Total Items:** [N]
```

Replace with:

```markdown
## Plan Verification Report (Gate 1)

**Plan:** [filename]
**Source:** [project-local | legacy-global | explicit]
**Total Items:** [N]
```

- [ ] **Step 3: Verify the file still parses cleanly**

```bash
head -1 plugins/quality-gates/agents/plan-verifier.md
grep -n "^## Step" plugins/quality-gates/agents/plan-verifier.md
```

Expected output:
- First line: `---` (YAML frontmatter delimiter)
- Step headings: `## Step 1`, `## Step 2`, `## Step 3`, `## Step 4`, `## Step 4.5`, `## Step 5` (all six present, in order)

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/agents/plan-verifier.md
git commit -m "feat(qg): rewrite plan-verifier Step 1 to use discover-plan.sh

Adds Source field to report and legacy-source deprecation warning."
```

---

## Task 4: Version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: Bump `plugin.json` version 1.6.3 → 1.7.0**

In `plugins/quality-gates/.claude-plugin/plugin.json`, change:

```json
  "version": "1.6.3",
```

to:

```json
  "version": "1.7.0",
```

- [ ] **Step 2: Add a `## [1.7.0]` section to CHANGELOG.md**

In `plugins/quality-gates/CHANGELOG.md`, insert this block immediately after the `## [1.6.3]` heading section (right before `## [1.6.3] — 2026-05-10`):

```markdown
## [1.7.0] — 2026-05-10

### Added
- **Project-local plan discovery** (`scripts/discover-plan.sh`): Gate 1 plan-verifier now scans `docs/superpowers/plans/` (superpowers:writing-plans 의 기본 저장 경로)을 1순위로, `~/.claude/plans/`를 legacy fallback으로 consult. 이전에는 `~/.claude/plans/`만 봐서 superpowers 워크플로우로 만든 plan이 항상 SKIP 되던 버그 fix.
- **`Source` 필드** Gate 1 report에 추가 — 어떤 source(explicit / project-local / legacy-global)에서 plan을 가져왔는지 사용자가 즉시 인지 가능.
- **9개 fixture 단위 테스트** (`tests/test_discover_plan.sh`): 양쪽 source 비어있음, project-local 우선, legacy fallback, non-plan 파일 필터, explicit override, mtime tiebreaker 등 매트릭스 커버.

### Changed
- Discovery 알고리즘이 `agents/plan-verifier.md` prose 안의 자유서술에서 결정적 bash script로 이동. 미래 source 추가 (예: monorepo sub-package별 plan)도 회귀 없이 가능. (Law 2 정신 — agent 자유서술 vs script contract.)
- Legacy source (`~/.claude/plans/`) 사용 시 `⚠️ Legacy plan source ... Consider migrating ...` 1줄 deprecation 경고 출력. project-local hit이면 silent.
- README "Principles Instantiated" 섹션에 Law 3 cross-plugin compounding 항목 추가 — `superpowers:writing-plans`의 출력 위치를 sister-plugin contract로 명시.

### Fixed
- **Path mismatch (Gate 1 SKIP/false-match bug)**: `superpowers:writing-plans` 가 `docs/superpowers/plans/` 에 plan을 저장하는데 plan-verifier 는 `~/.claude/plans/`만 스캔해서 (a) 사용자의 최신 plan을 찾지 못하거나 (b) `~/.claude/plans/` 의 옛날 무관한 plan을 잘못 verify 하던 문제. 1.7.0 부터 priority 기반 discovery 로 정확히 매칭.

```

- [ ] **Step 3: Verify both files**

```bash
grep -n '"version"' plugins/quality-gates/.claude-plugin/plugin.json
head -20 plugins/quality-gates/CHANGELOG.md
```

Expected:
- `plugin.json`: line shows `"version": "1.7.0",`
- `CHANGELOG.md`: `## [1.7.0] — 2026-05-10` appears within the first 20 lines, ahead of `## [1.6.3]`.

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "chore(qg): bump 1.6.3 → 1.7.0 + CHANGELOG entry"
```

---

## Task 5: README — Plan Discovery Sources section + Principles update

**Files:**
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: Add cross-plugin compounding line to "인스턴스화한 원칙"**

In `plugins/quality-gates/README.md`, find the bullet list under `## 인스턴스화한 원칙` (lines 9-16). After the `**Law 3 (Compounding)** ...` bullet (line 12), insert this new sub-bullet on a new line:

```markdown
- **Law 3 (Compounding) — cross-plugin reader contract** — Gate 1 plan-verifier가 sister-plugin (`superpowers:writing-plans`)의 출력 경로 `docs/superpowers/plans/`를 1순위 source로 명시 consume; convention drift가 silent breakage가 되지 않도록 README "Plan Discovery Sources" 섹션이 reader/writer 약속을 문서화.
```

- [ ] **Step 2: Add "Plan Discovery Sources" section after "## 사용"**

Find the end of the `## 사용` code block (the `/cancel-qg --all` line and its closing triple-backtick). Insert the following section IMMEDIATELY after the closing triple-backtick and the blank line, before the next `## ` heading:

```markdown
## Plan Discovery Sources (Gate 1)

`/qg gate1`이 `--plan <path>`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 (위→아래로 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--plan <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/plans/*.md` (project-local) | checkbox `- [ ]` / `- [x]` 1개 이상 |
| 3 | `~/.claude/plans/*.md` (legacy global) | project-local 비었을 때만 consult. hit 시 deprecation 경고 출력 |

선택된 source 내부에서: unchecked checkbox 있는 파일 우선, 동률이면 mtime 가장 최근. 모두 all-checked면 mtime 가장 최근 ("방금 끝낸 plan, PASS 처리 정상").

**Soft dependency:** project-local source는 `superpowers:writing-plans` skill이 plan을 저장하는 경로 (`docs/superpowers/plans/`) 와 동일합니다. superpowers 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-plan.sh`에 분리되어 `tests/test_discover_plan.sh` 9개 fixture로 검증됩니다.

```

- [ ] **Step 3: Verify the README still renders**

```bash
grep -n "^## " plugins/quality-gates/README.md | head -20
```

Expected: `## 인스턴스화한 원칙`, `## 구조`, ..., `## 사용`, `## Plan Discovery Sources (Gate 1)`, ... appear in that order.

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/README.md
git commit -m "docs(qg): document Plan Discovery Sources + cross-plugin contract"
```

---

## Task 6: Manual end-to-end verification on the current repo

**Files:** none modified — verification only.

- [ ] **Step 1: Confirm `docs/superpowers/plans/` already has plans (it does)**

```bash
ls -1 docs/superpowers/plans/*.md
```

Expected: at least 4 files, including `2026-05-10-qg-plan-discovery-plan.md` (this very plan).

- [ ] **Step 2: Run the discover-plan.sh script directly from the repo root**

```bash
bash plugins/quality-gates/scripts/discover-plan.sh
```

Expected stdout (one line, JSON):
- `"source":"project-local"`
- `"plan_path"` ends with one of the project-local plan files (most recently modified one with unchecked checkboxes — likely this very plan during execution)
- Exit code: `0` (check with `echo $?` after the call)

- [ ] **Step 3: Force the legacy-fallback path**

```bash
mv docs/superpowers/plans /tmp/plans-backup
bash plugins/quality-gates/scripts/discover-plan.sh
EXIT=$?
mv /tmp/plans-backup docs/superpowers/plans
echo "exit=$EXIT"
```

Expected:
- Stdout JSON shows `"source":"legacy-global"` and a path inside `~/.claude/plans/`.
- `exit=0`.

(If `~/.claude/plans/` has no markdown files on this machine, the source will be `none` and exit 1 — that is also a valid expected output. Note which case applied.)

- [ ] **Step 4: Force the not-found path**

```bash
mv docs/superpowers/plans /tmp/plans-backup
HOME=/tmp/no-such-home bash plugins/quality-gates/scripts/discover-plan.sh
EXIT=$?
mv /tmp/plans-backup docs/superpowers/plans
echo "exit=$EXIT"
```

Expected: stdout JSON has `"source":"none"`, reason mentions both searched paths, `exit=1`.

- [ ] **Step 5: Force the explicit-invalid path**

```bash
bash plugins/quality-gates/scripts/discover-plan.sh --plan /tmp/definitely-missing-xyz.md
echo "exit=$?"
```

Expected: stdout JSON has `"source":"none"`, reason starts with `"Explicit --plan path does not exist:"`, `exit=2`.

- [ ] **Step 6: Re-run unit tests one final time**

```bash
bash plugins/quality-gates/tests/test_discover_plan.sh
```

Expected: `Results: N passed, 0 failed`.

- [ ] **Step 7: No commit needed for this task** — Task 6 is verification-only. Skip directly to Task 7.

---

## Task 7: Push branch + open PR

**Files:** none.

- [ ] **Step 1: Push the branch and set upstream**

```bash
git push -u origin feature/qg-plan-discovery
```

- [ ] **Step 2: Open the PR with `gh`**

```bash
gh pr create --base main --title "fix(qg): Gate 1 plan discovery — project-local + legacy fallback (1.7.0)" --body "$(cat <<'EOF'
## Summary

- Gate 1 (`plan-verifier`)이 `superpowers:writing-plans` 저장 경로 (`docs/superpowers/plans/`)를 1순위로 발견하도록 fix. 이전에는 `~/.claude/plans/`만 스캔해서 superpowers 워크플로우 plan이 항상 SKIP 되거나 옛 plan을 false-match.
- Discovery 알고리즘을 `scripts/discover-plan.sh`로 분리 + 9개 fixture 단위 테스트.
- Report에 `**Source:**` 필드 추가 (explicit / project-local / legacy-global). Legacy hit 시 deprecation 1줄 경고.
- Plugin version 1.6.3 → 1.7.0 (minor — 새 surface).

## Spec / Plan

- Spec: `docs/superpowers/specs/2026-05-10-qg-plan-discovery-design.md`
- Plan: `docs/superpowers/plans/2026-05-10-qg-plan-discovery-plan.md`

## Test plan

- [x] `bash plugins/quality-gates/tests/test_discover_plan.sh` — all 9 fixtures pass
- [x] Manual: `bash plugins/quality-gates/scripts/discover-plan.sh` from repo root returns project-local plan
- [x] Manual: legacy fallback fires when project-local hidden
- [x] Manual: `--plan <missing>` returns exit 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Confirm PR URL is returned**

`gh pr create` output should end with a `https://github.com/.../pull/N` URL. Note it for handoff.

---

## Done

All seven tasks complete. The pipeline now correctly discovers project-local plans, falls back to legacy with a deprecation hint, and the discovery contract is unit-tested.

**Single-PR rollback:** `git revert <merge-sha>` undoes everything (script, tests, agent, version, CHANGELOG, README) atomically.
