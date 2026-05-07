# project-init v1.2.1 — rebase→merge default + drop Karpathy attribution

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the v1.2.1 patch defined in `docs/superpowers/specs/2026-05-07-project-init-rebase-attribution-fix-design.md` — switch branch sync default from `git rebase` to `git merge` across two of three branch-strategy templates, remove the Karpathy attribution blockquote from the `llm-guidelines` template (so it no longer lands in target projects' `CLAUDE.md`), bump the plugin to `1.2.1`, and apply the same merge fix to devbrew's consumer copy at `docs/git-workflow/branch-strategy.md`. Additionally, persist devbrew's `/project-init v1.2.0` strict-replace baseline (CLAUDE.md, commit-conventions.md) so devbrew's checked-in state matches what running `/project-init v1.2.1` would generate.

**Architecture:** Pure documentation/templates fix. Six file edits in the v1.2.1 implementation, plus two file commits to persist devbrew's strict-replace baseline. All string-replacement, line-insertion, and JSON field updates. No code paths change. The plugin's `PostToolUse` hook is untouched. Verification is grep-based against the spec's Acceptance Criteria. Three commits total on `fix/project-init-templates` (already at `1c7c6f3` after the spec commit).

**Tech Stack:** Markdown templates (`.md`), JSON manifest (`.claude-plugin/plugin.json`), `grep`/`sed`/`git` for verification.

---

## File Structure

| # | File | Responsibility | Action |
|---|---|---|---|
| 1 | `plugins/project-init/templates/github-flow/branch-strategy.md` | Generic GitHub Flow branch-strategy doc emitted into target projects | Modify (4 edits) |
| 2 | `plugins/project-init/templates/git-flow/branch-strategy.md` | Generic Git Flow branch-strategy doc emitted into target projects | Modify (2 edits) |
| 3 | `plugins/project-init/templates/shared/llm-guidelines.md` | LLM Coding Guidelines section injected into target `CLAUDE.md` | Modify (delete 2 lines) |
| 4 | `plugins/project-init/.claude-plugin/plugin.json` | Plugin manifest — name/version/description | Modify (version field only) |
| 5 | `plugins/project-init/CHANGELOG.md` | Plugin release history | Modify (insert new top entry) |
| 6 | `docs/git-workflow/branch-strategy.md` | devbrew's own consumer copy of file #1 | Modify (same edits as file #1) |
| 7 | `CLAUDE.md` (devbrew's) | devbrew project memory — already strict-replaced; just commit | Commit only (no further edits) |
| 8 | `docs/git-workflow/commit-conventions.md` (devbrew's) | devbrew commit conventions — already strict-replaced; just commit | Commit only (no further edits) |

Files **not** touched (per spec Non-goals): `templates/trunk-based/branch-strategy.md`, `templates/shared/pr-process.md`, `templates/shared/commit-conventions.md`, `commands/project-init.md`, `README.md`.

---

## Task 1: Verify baseline state of `docs/git-workflow/branch-strategy.md`

**Why first:** Sanity-check what's actually in the working tree before editing. devbrew's `docs/git-workflow/branch-strategy.md` was overwritten by an earlier `/project-init` strict-replace in this session, so the working tree currently holds the **template rebase variant** (NOT main HEAD's customized merge variant). The plan's Task 5 edits assume this template-rebase baseline so its `old_string` patterns match. **Do not `git restore` from main** — that would bring back devbrew's customized variant whose wording differs from the template, and Task 5's edits would then fail to match.

**Files:** read-only verification.

- [ ] **Step 1: Verify the file is modified vs main HEAD**

```bash
git status --short docs/git-workflow/branch-strategy.md
```

Expected: ` M docs/git-workflow/branch-strategy.md`.

- [ ] **Step 2: Verify the working tree holds the template rebase variant**

```bash
grep -c "git rebase origin/main" docs/git-workflow/branch-strategy.md
grep -c "Or keep and rebase from main for follow-up work" docs/git-workflow/branch-strategy.md
grep -c "needs rebase from main" docs/git-workflow/branch-strategy.md
```

Expected: `1`, `1`, `1`. All three "rebase" strings that Task 5 will replace are present.

- [ ] **Step 3: Confirm the new prefer-merge rule line is NOT yet present**

```bash
grep -cE "ALWAYS.* sync .* with .*git merge origin/main" docs/git-workflow/branch-strategy.md
```

Expected: `0`. (Confirmed pre-Task-5 state.)

If any of Steps 1–3 fail, stop and investigate — the working tree is in an unexpected state and applying edits without fixing first will produce wrong end-state.

---

## Task 2: Commit devbrew `/project-init v1.2.0` strict-replace baseline

**Why before the fix:** devbrew's `CLAUDE.md` and `docs/git-workflow/commit-conventions.md` were overwritten earlier in this session by `/project-init v1.2.0` strict-replace. The user has accepted those overwrites as the new baseline (per the brainstorming Q1/Q2 confirmations). Persist them as a separate commit *before* the v1.2.1 fix so the commit history reads as: spec → strict-replace baseline accepted → fix on top. v1.2.1 doesn't change `commit-conventions.md` or the CLAUDE.md template sections, so v1.2.0-strict-replace state == v1.2.1-strict-replace state. After this task + Task 10, devbrew's checked-in state matches what running `/project-init v1.2.1` would generate.

**Files:**
- Commit (no edits): `CLAUDE.md`
- Commit (no edits): `docs/git-workflow/commit-conventions.md`

**Important:** This task does NOT touch `docs/git-workflow/branch-strategy.md`. That file is also modified in working tree but is being re-edited by Task 5; committing it now (in rebase variant) and then re-committing in Task 10 (in merge + new rule variant) would produce churn. Stage exactly the two files listed above.

- [ ] **Step 1: Verify the two files are modified vs main HEAD**

```bash
git status --short CLAUDE.md docs/git-workflow/commit-conventions.md
```

Expected:
```
 M CLAUDE.md
 M docs/git-workflow/commit-conventions.md
```

- [ ] **Step 2: Stage exactly these two files**

```bash
git add CLAUDE.md docs/git-workflow/commit-conventions.md
```

- [ ] **Step 3: Verify the staged set is correct**

```bash
git diff --cached --name-only
```

Expected:
```
CLAUDE.md
docs/git-workflow/commit-conventions.md
```

If `docs/git-workflow/branch-strategy.md` appears in this list, it was accidentally staged — `git restore --staged docs/git-workflow/branch-strategy.md` to unstage it before committing.

- [ ] **Step 4: Create the baseline commit**

```bash
git commit -m "$(cat <<'EOF'
chore(docs): persist /project-init v1.2.0 strict-replace baseline

Earlier in this session /project-init v1.2.0 was run on devbrew with
strict-replace selected. CLAUDE.md and docs/git-workflow/commit-conventions.md
were overwritten with the plugin's template content (English ## Git
Workflow section, generic module/directory scope wording).

This commit persists those overwrites as devbrew's new checked-in
baseline so devbrew's repo state matches what running /project-init
would generate. The fix in the next commit (v1.2.1: rebase→merge,
drop Karpathy attribution) is then layered on top of this baseline,
keeping the audit trail of the strict-replace decision separate from
the v1.2.1 patch logic.

Lost vs prior main:
- CLAUDE.md ## Git Workflow custom Korean wording with merge-over-rebase
  rule and `gh pr merge --squash --delete-branch` line (Q2 of brainstorm:
  user explicitly chose to leave the strict-replaced English template
  in place rather than restore the custom Korean version).
- docs/git-workflow/commit-conventions.md plugin-name-aware scope
  wording ("project-init", "quality-gates") replaced with generic
  module/directory examples.

docs/git-workflow/branch-strategy.md is intentionally NOT in this
commit — it's also modified but being re-edited by the v1.2.1 fix
in the next commit. Committing the rebase variant here and then
re-committing the merge variant would be pure churn.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify the commit landed**

```bash
git log --oneline -3
```

Expected (top entry):
```
<sha> chore(docs): persist /project-init v1.2.0 strict-replace baseline
1c7c6f3 docs(project-init): spec for v1.2.1 merge default + attribution fix
<earlier> ...
```

- [ ] **Step 6: Verify branch-strategy.md is still uncommitted**

```bash
git status --short docs/git-workflow/branch-strategy.md
```

Expected: ` M docs/git-workflow/branch-strategy.md` (still modified, not committed). This is the correct pre-Task-5 state.

---

## Task 3: Edit `templates/github-flow/branch-strategy.md` (4 changes)

**Files:**
- Modify: `plugins/project-init/templates/github-flow/branch-strategy.md`

- [ ] **Step 1: Read the current file to confirm pre-state**

Read `plugins/project-init/templates/github-flow/branch-strategy.md` and verify lines 45, 51, 60 contain the strings the next steps will replace.

- [ ] **Step 2: Edit the example git command (line 45)**

In `plugins/project-init/templates/github-flow/branch-strategy.md`, replace:

```
git rebase origin/main
```

with:

```
git merge origin/main
```

- [ ] **Step 3: Edit the "After PR merge" bullet (line 51)**

Replace:

```
- Or keep and rebase from main for follow-up work
```

with:

```
- Or keep and merge main in for follow-up work
```

- [ ] **Step 4: Edit the existing "Rules for Claude" line (line 60)**

Replace:

```
- When switching to an existing feature branch — check if it needs rebase from main
```

with:

```
- When switching to an existing feature branch — check if it needs sync from main
```

- [ ] **Step 5: Insert the new prefer-merge rule line immediately after the line edited in Step 4**

After the "check if it needs sync from main" line, insert (preserving Markdown list indentation):

```
- **ALWAYS** sync an existing feature branch with `git merge origin/main`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.
```

Use a single Edit operation that takes the line from Step 4 (post-replacement) and replaces it with that line plus the new line below it. This guarantees the placement is "immediately after" the sync-check rule.

- [ ] **Step 6: Verify all four edits landed**

```bash
grep -c "git merge origin/main" plugins/project-init/templates/github-flow/branch-strategy.md
grep -c "git rebase" plugins/project-init/templates/github-flow/branch-strategy.md
grep -c "merge main in for follow-up work" plugins/project-init/templates/github-flow/branch-strategy.md
grep -c "needs sync from main" plugins/project-init/templates/github-flow/branch-strategy.md
grep -cE "ALWAYS.* sync .* with .*git merge origin/main.*never .*git rebase" plugins/project-init/templates/github-flow/branch-strategy.md
```

Expected: `1`, `1` (the one in the new rule line), `1`, `1`, `1`. The second grep is `1` because the new rule line itself contains the word `git rebase` in the warning prose — that's intentional.

---

## Task 4: Edit `templates/git-flow/branch-strategy.md` (2 changes)

**Files:**
- Modify: `plugins/project-init/templates/git-flow/branch-strategy.md`

- [ ] **Step 1: Read the current file to confirm pre-state**

Read `plugins/project-init/templates/git-flow/branch-strategy.md` and verify line 80 contains the rebase-from-develop rule.

- [ ] **Step 2: Edit the existing "Rules for Claude" line (line 80)**

Replace:

```
- When switching to an existing feature branch — check if it needs rebase from `develop`
```

with:

```
- When switching to an existing feature branch — check if it needs sync from `develop`
```

- [ ] **Step 3: Insert the new prefer-merge rule line immediately after the line edited in Step 2**

After the "check if it needs sync from `develop`" line, insert:

```
- **ALWAYS** sync an existing feature branch with `git merge origin/develop`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.
```

Use a single Edit operation combining Step 2's replacement target with the new line below it.

- [ ] **Step 4: Verify both edits landed**

```bash
grep -c "needs sync from .develop." plugins/project-init/templates/git-flow/branch-strategy.md
grep -cE "ALWAYS.* sync .* with .*git merge origin/develop.*never .*git rebase" plugins/project-init/templates/git-flow/branch-strategy.md
grep -c "rebase from .develop." plugins/project-init/templates/git-flow/branch-strategy.md
```

Expected: `1`, `1`, `0`.

---

## Task 5: Apply the same edits to devbrew's consumer copy

**Files:**
- Modify: `docs/git-workflow/branch-strategy.md`

The working tree's version of this file is the template rebase variant (verified in Task 1), byte-identical to the pre-Task-3 state of `templates/github-flow/branch-strategy.md`. Apply the same four edits as Task 3 so it matches the post-fix template state.

- [ ] **Step 1: Apply the rebase→merge example edit**

Replace:

```
git rebase origin/main
```

with:

```
git merge origin/main
```

- [ ] **Step 2: Apply the "After PR merge" wording edit**

Replace:

```
- Or keep and rebase from main for follow-up work
```

with:

```
- Or keep and merge main in for follow-up work
```

- [ ] **Step 3: Apply the "Rules for Claude" wording edit + new rule line**

Replace:

```
- When switching to an existing feature branch — check if it needs rebase from main
```

with:

```
- When switching to an existing feature branch — check if it needs sync from main
- **ALWAYS** sync an existing feature branch with `git merge origin/main`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.
```

(Single Edit operation: the post-replacement wording plus the new rule line directly after, guaranteeing placement.)

- [ ] **Step 4: Verify all four edits landed**

```bash
grep -c "git merge origin/main" docs/git-workflow/branch-strategy.md
grep -c "merge main in for follow-up work" docs/git-workflow/branch-strategy.md
grep -c "needs sync from main" docs/git-workflow/branch-strategy.md
grep -cE "ALWAYS.* sync .* with .*git merge origin/main.*never .*git rebase" docs/git-workflow/branch-strategy.md
```

Expected: `1` (or higher, since the new rule line also contains it), `1`, `1`, `1`.

- [ ] **Step 5: Verify no rebase references remain (other than the warning in the new rule)**

```bash
grep -E "needs rebase|rebase from main|git rebase origin" docs/git-workflow/branch-strategy.md
```

Expected: empty output. (The new rule line mentions `git rebase` in prose, but doesn't match any of these three patterns.)

- [ ] **Step 6: Verify file matches post-fix github-flow template byte-for-byte**

```bash
diff -u plugins/project-init/templates/github-flow/branch-strategy.md docs/git-workflow/branch-strategy.md
```

Expected: empty output (files identical). This is incidental confirmation that Tasks 3 and 5 produced equivalent end-states; not a permanent contract.

---

## Task 6: Remove Karpathy attribution from `llm-guidelines.md`

**Files:**
- Modify: `plugins/project-init/templates/shared/llm-guidelines.md`

- [ ] **Step 1: Read the current file to confirm pre-state**

Read `plugins/project-init/templates/shared/llm-guidelines.md`. Confirm:
- Line 1: `## LLM Coding Guidelines`
- Line 2: blank
- Line 3: `> Andrej Karpathy의 [LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876) 4줄 압축.`
- Line 4: blank
- Line 5: `- Think Before Coding — 가정·혼란·tradeoff 명시, 의심나면 묻기`

- [ ] **Step 2: Delete lines 3 and 4**

Use a single Edit operation that takes a unique enough block (the blockquote line plus the blank line after it) and replaces it with empty string. Specifically, replace:

```
> Andrej Karpathy의 [LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876) 4줄 압축.

```

with empty string. The Edit's `old_string` includes the trailing blank line so we drop both lines together. Line 2 (the blank between the heading and the now-removed blockquote) is preserved — after deletion, the file reads heading → blank → first bullet, which is correct CommonMark.

- [ ] **Step 3: Verify the heading and 4 bullets are intact**

```bash
head -10 plugins/project-init/templates/shared/llm-guidelines.md
```

Expected output:

```
## LLM Coding Guidelines

- Think Before Coding — 가정·혼란·tradeoff 명시, 의심나면 묻기
- Simplicity First — 요청 이상 만들지 않기, 추측 금지
- Surgical Changes — 요청과 직결된 줄만, 인접 코드 청소 금지
- Goal-Driven Execution — 검증 가능한 성공 기준 정의 후 loop
```

(5 lines content + 1 trailing newline. No blockquote line.)

- [ ] **Step 4: Verify the attribution is gone**

```bash
grep -c "Karpathy" plugins/project-init/templates/shared/llm-guidelines.md
grep -c "x.com/karpathy" plugins/project-init/templates/shared/llm-guidelines.md
```

Expected: `0`, `0`.

---

## Task 7: Bump plugin version to `1.2.1`

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`

- [ ] **Step 1: Read the current file to confirm pre-state**

Read `plugins/project-init/.claude-plugin/plugin.json`. Confirm the version field is `"version": "1.2.0"`.

- [ ] **Step 2: Edit the version field**

Replace:

```
  "version": "1.2.0",
```

with:

```
  "version": "1.2.1",
```

(Trailing comma preserved — the field is followed by `"author"`.)

- [ ] **Step 3: Verify the version field**

```bash
grep '"version"' plugins/project-init/.claude-plugin/plugin.json
```

Expected: `  "version": "1.2.1",`.

- [ ] **Step 4: Verify the JSON is still well-formed**

```bash
python3 -c "import json; json.load(open('plugins/project-init/.claude-plugin/plugin.json')); print('OK')"
```

Expected: `OK`.

---

## Task 8: Add `[1.2.1]` entry to `CHANGELOG.md`

**Files:**
- Modify: `plugins/project-init/CHANGELOG.md`

- [ ] **Step 1: Read the current file to confirm pre-state**

Read `plugins/project-init/CHANGELOG.md`. Confirm the first version heading is `## [1.2.0] — 2026-05-07` (line 8).

- [ ] **Step 2: Insert the new entry above `## [1.2.0]`**

Replace:

```
## [1.2.0] — 2026-05-07
```

with:

```
## [1.2.1] — 2026-05-07

Same-day patch correcting v1.2.0 template defaults — intentional duplicate date.

### Changed
- `templates/github-flow/branch-strategy.md` and `templates/git-flow/branch-strategy.md` now default to `git merge` for syncing a feature branch with its base. New "Rules for Claude" line cites the *"rebase golden rule"* (Pro Git §3.6 *"Rebasing"*) — rebase rewrites history and is unsafe on any pushed branch. Strict variant chosen (always merge, never rebase) for one-line teachability and force-push safety on local branches.

### Removed
- Andrej Karpathy attribution blockquote (`> Andrej Karpathy의 [LLM 코딩 관찰]...`) is no longer injected into the target project's `CLAUDE.md`. The 4-bullet baseline is unchanged. Attribution preserved at the plugin layer (README, plugin.json description, slash-command confirmation, this changelog) — the directive applies only to the target project's LLM-context anchor.

## [1.2.0] — 2026-05-07
```

- [ ] **Step 3: Verify the new entry is in place**

```bash
grep -n "^## \[" plugins/project-init/CHANGELOG.md | head -3
```

Expected:
```
8:## [1.2.1] — 2026-05-07
20:## [1.2.0] — 2026-05-07
33:## [1.1.0] — 2026-04-12
```

(Line numbers approximate; what matters is that `[1.2.1]` appears before `[1.2.0]` and both are dated `2026-05-07`.)

- [ ] **Step 4: Verify the entry has Changed and Removed subsections**

```bash
sed -n '/^## \[1.2.1\]/,/^## \[1.2.0\]/p' plugins/project-init/CHANGELOG.md | grep -E "^### "
```

Expected:
```
### Changed
### Removed
```

- [ ] **Step 5: Verify Pro Git citation is §3.6, not §5.3**

```bash
grep -E "Pro Git §" plugins/project-init/CHANGELOG.md
```

Expected: `…Pro Git §3.6 …` (no occurrence of `§5.3`).

---

## Task 9: Run all static-check Acceptance Criteria as a single batch

**Why:** The spec lists ~12 grep/diff bullets. Running them together gives a single pass/fail signal before commit.

**Files:** read-only verification.

- [ ] **Step 1: Run the full AC batch**

```bash
echo "AC1: rebase invocations in templates" && grep -r "git rebase origin" plugins/project-init/templates/ ; echo "(empty = pass)"
echo "AC2: Karpathy in templates" && grep -rn "Karpathy" plugins/project-init/templates/ ; echo "(empty = pass)"
echo "AC3: 'needs rebase' in templates" && grep -r "needs rebase" plugins/project-init/templates/ ; echo "(empty = pass)"
echo "AC4: 'rebase from main' in github-flow" && grep -r "rebase from main" plugins/project-init/templates/github-flow/ ; echo "(empty = pass)"
echo "AC5: 'rebase from develop' in git-flow" && grep -rE "rebase from .develop." plugins/project-init/templates/git-flow/ ; echo "(empty = pass)"
echo "AC6: plugin.json version" && grep '"version"' plugins/project-init/.claude-plugin/plugin.json
echo "AC7: first changelog heading" && grep -m1 "^## \[" plugins/project-init/CHANGELOG.md
echo "AC8: changelog 1.2.1 subsections" && sed -n '/^## \[1.2.1\]/,/^## \[1.2.0\]/p' plugins/project-init/CHANGELOG.md | grep -E "^### "
echo "AC9: new rule line in github-flow" && grep -cE "ALWAYS.* sync .* with .*git merge origin/main" plugins/project-init/templates/github-flow/branch-strategy.md
echo "AC10: new rule line in git-flow" && grep -cE "ALWAYS.* sync .* with .*git merge origin/develop" plugins/project-init/templates/git-flow/branch-strategy.md
echo "AC11: new rule line in devbrew copy" && grep -cE "ALWAYS.* sync .* with .*git merge origin/main" docs/git-workflow/branch-strategy.md
echo "AC12: 6 modified paths (vs Task 2 baseline commit)" && git diff --stat HEAD -- plugins/project-init/ docs/git-workflow/branch-strategy.md
```

- [ ] **Step 2: Confirm expected output**

| AC | Expected |
|---|---|
| AC1 | empty (no `git rebase origin` invocations remain) |
| AC2 | empty (no `Karpathy` in `templates/`) |
| AC3 | empty (no `needs rebase` in `templates/`) |
| AC4 | empty (no `rebase from main` in github-flow) |
| AC5 | empty (no `rebase from develop` in git-flow) |
| AC6 | `  "version": "1.2.1",` |
| AC7 | `## [1.2.1] — 2026-05-07` |
| AC8 | `### Changed` and `### Removed` (two lines) |
| AC9 | `1` |
| AC10 | `1` |
| AC11 | `1` |
| AC12 | exactly 6 file paths in the diff stat (HEAD = Task 2's baseline commit, so this measures only the v1.2.1 fix's changes) |

Any deviation → fix the implementation, re-run.

---

## Task 10: Atomic v1.2.1 fix commit

**Files:** all 6 modified files for the v1.2.1 fix.

- [ ] **Step 1: Stage exactly the 6 files**

```bash
git add plugins/project-init/templates/github-flow/branch-strategy.md \
        plugins/project-init/templates/git-flow/branch-strategy.md \
        plugins/project-init/templates/shared/llm-guidelines.md \
        plugins/project-init/.claude-plugin/plugin.json \
        plugins/project-init/CHANGELOG.md \
        docs/git-workflow/branch-strategy.md
```

- [ ] **Step 2: Verify only those 6 files are staged**

```bash
git diff --cached --stat
git status --short
```

Expected: 6 files in `--cached --stat`. `git status --short` should be empty (no unstaged modifications) because Task 2 already committed `CLAUDE.md` and `commit-conventions.md`.

If `git status --short` shows any unstaged files, investigate before committing — there should be none at this point.

- [ ] **Step 3: Create the commit**

```bash
git commit -m "$(cat <<'EOF'
fix(project-init): default to git merge, drop Karpathy attribution; v1.2.1

Switch branch sync default from `git rebase origin/main` to
`git merge origin/main` across github-flow and git-flow templates.
Insert new "Rules for Claude" rule line: ALWAYS sync via merge, never
rebase (rebase rewrites SHAs; unsafe on pushed branches). Apply the
same edits to devbrew's consumer copy at docs/git-workflow/branch-strategy.md
to keep source/consumer in sync.

Remove the Andrej Karpathy attribution blockquote from
templates/shared/llm-guidelines.md so it's no longer injected into the
target project's CLAUDE.md (LLM-context anchor stays clean). The
4-bullet baseline is unchanged. Attribution preserved at the plugin-doc
layer (README, plugin.json description, slash-command Step 5 message,
v1.2.0 CHANGELOG entry).

Bump plugin to v1.2.1 (patch — fix to existing template behavior, no
new surface, no breaking change to slash-command contract). Same-day
patch with intentional duplicate 2026-05-07 date in CHANGELOG.

Spec: docs/superpowers/specs/2026-05-07-project-init-rebase-attribution-fix-design.md
Plan: docs/superpowers/plans/2026-05-07-project-init-rebase-attribution-fix.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Verify commit landed**

```bash
git log --oneline -4
```

Expected (top entry):
```
<sha> fix(project-init): default to git merge, drop Karpathy attribution; v1.2.1
<sha> chore(docs): persist /project-init v1.2.0 strict-replace baseline
1c7c6f3 docs(project-init): spec for v1.2.1 merge default + attribution fix
<earlier> ...
```

- [ ] **Step 5: Verify the project-init hook validated the commit**

The `project-init/hooks/post-tool-use.py` hook runs on `Bash` tool calls and validates branch naming + Conventional Commits format. If the commit succeeded with no hook complaint, the format is valid. If the hook complained (e.g., scope, type, or imperative-mood violation), fix the commit message and amend.

---

## Task 11: Commit the plan document itself

**Files:**
- Add: `docs/superpowers/plans/2026-05-07-project-init-rebase-attribution-fix.md`

The plan was written *during* this implementation cycle (not before the spec commit), so it's a separate concern from the implementation commit. Commit it as a small follow-up so the implementation commit stays focused on the plugin fix.

- [ ] **Step 1: Stage the plan**

```bash
git add docs/superpowers/plans/2026-05-07-project-init-rebase-attribution-fix.md
```

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
docs(project-init): plan for v1.2.1 implementation

Implementation plan that turned the v1.2.1 spec into 11 bite-sized
tasks (verify baseline → persist /project-init strict-replace baseline
→ apply v1.2.1 fix → run ACs → atomic commit → plan commit → optional
round-trip test). Co-located with the spec under docs/superpowers/ for
the brainstorming → writing-plans → executing-plans audit trail.

Spec: docs/superpowers/specs/2026-05-07-project-init-rebase-attribution-fix-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Verify**

```bash
git log --oneline -5
```

Expected:
```
<sha> docs(project-init): plan for v1.2.1 implementation
<sha> fix(project-init): default to git merge, drop Karpathy attribution; v1.2.1
<sha> chore(docs): persist /project-init v1.2.0 strict-replace baseline
1c7c6f3 docs(project-init): spec for v1.2.1 merge default + attribution fix
<earlier> ...
```

- [ ] **Step 4: Confirm working tree is clean**

```bash
git status
```

Expected: `nothing to commit, working tree clean`. Any remaining unstaged files at this point are unexpected — investigate.

---

## Task 12: (Manual, optional) Round-trip test

**Files:** none (uses a throwaway directory).

This is the spec's Verification Plan #2. It exercises the slash command end-to-end against the new plugin version. Skip if implementation is small and you trust the static checks. Recommended before merging the PR.

- [ ] **Step 1: Reload the plugin cache so v1.2.1 is picked up**

In the running Claude Code session, run `/reload-plugins`. Expected output: a count of plugins, agents, hooks, etc. The cache should now reflect v1.2.1 from this branch.

- [ ] **Step 2: In a throwaway directory, run `/project-init`**

```bash
mkdir -p /tmp/project-init-roundtrip && cd /tmp/project-init-roundtrip && git init -b main && git commit --allow-empty -m "initial"
```

Then in Claude Code with cwd set to `/tmp/project-init-roundtrip`, run `/project-init`. Choose: GitHub Flow → module/directory scope → squash merge.

- [ ] **Step 3: Inspect the generated artifacts**

```bash
grep "git merge origin/main" /tmp/project-init-roundtrip/docs/git-workflow/branch-strategy.md
grep -E "ALWAYS.* sync .* with .*git merge origin/main" /tmp/project-init-roundtrip/docs/git-workflow/branch-strategy.md
grep "Karpathy" /tmp/project-init-roundtrip/CLAUDE.md
```

Expected: first two match, third is empty.

- [ ] **Step 4: Clean up**

```bash
rm -rf /tmp/project-init-roundtrip
```

---

## Rollback

If the merge default proves wrong in a downstream project after this PR merges:

```bash
git revert <merge-commit-sha>
# Plugin auto-bumps to v1.2.2 (revert-of-revert) with restored rebase wording
```

No data migration needed — templates only. Already-initialized downstream projects keep whatever they had at init time; revert affects only future invocations of `/project-init`.
