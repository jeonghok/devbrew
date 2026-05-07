# project-init: rebase→merge default + remove Karpathy attribution

**Status:** Approved (design phase complete, awaiting plan)
**Author:** jeonghokim (via brainstorming skill, hardened by adversarial review)
**Date:** 2026-05-07
**Plugin target:** `plugins/project-init/` v1.2.0 → **v1.2.1** (patch)

## Context / Why

`/project-init` v1.2.0 generates two artifacts that contradict the harness owner's stored conventions:

1. **Branch sync method.** All branching-strategy templates that mention syncing a feature branch use `git rebase origin/main` (or implicitly reference rebase in their "Rules for Claude" section). devbrew's stored memory (`feedback_git_merge_over_rebase.md`) declares `rebase 불가` (rebase not allowed) as a hard rule. The reasoning, rooted in Pro Git §3.6 *"Rebasing"* / "The Perils of Rebasing": rebasing commits that have been pushed or that others may have based work on rewrites history and breaks downstream branches. The user adopts the **strict variant** of this rule (always merge, never rebase) for simplicity and force-push-safety, even on local-only branches. The current v1.2.0 template defaults to the wrong side of that rule for the harness owner's intended audience.

2. **Karpathy attribution blockquote.** `templates/shared/llm-guidelines.md` injects `> Andrej Karpathy의 [LLM 코딩 관찰](https://x.com/karpathy/status/2015883857489522876) 4줄 압축.` directly into the target project's `CLAUDE.md`. Stored preference: attribution should not appear in `CLAUDE.md` itself (it's a context-anchor file for the LLM, not a credit registry). The 4 bullet items are kept; only the source-citation blockquote is removed from the *target project's* CLAUDE.md output. Attribution at the *plugin documentation layer* (README, plugin.json description, prior changelog entries, slash-command confirmation message) is unaffected.

The fix scope also covers devbrew's own `docs/git-workflow/branch-strategy.md`, which is a previously-generated copy of the same template and will otherwise drift from the corrected source.

## Goals

1. `/project-init` (any future invocation, GitHub Flow or Git Flow strategies) writes **`git merge`-based** sync instructions and an explicit prefer-merge rule that matches the existing "Rules for Claude" tone (terse imperative + one-line rationale).
2. `/project-init` writes the LLM Coding Guidelines section to the target project's `CLAUDE.md` **without** the Karpathy attribution blockquote. The 4 bullets are unchanged.
3. devbrew's own copy of the GitHub Flow `branch-strategy.md` receives the same line-level edits as the source template (consistency between source and consumer).
4. Plugin version bumps to `1.2.1` and `CHANGELOG.md` records the fix with rationale.

## Non-goals

- **Not** restoring devbrew's `## Git Workflow` section in its own `CLAUDE.md` (currently English template-form, missing the merge-over-rebase line and the `--delete-branch` line). Out of scope per design Q2 — owner explicitly chose to leave that alone.
- **Not** restoring devbrew's own `docs/git-workflow/commit-conventions.md` plugin-name-aware scope wording. Separate regression, not part of this fix's directive (which targets rebase + attribution only).
- **Not** modifying `templates/trunk-based/branch-strategy.md`. It currently has no rebase mention; adding a "use merge" rule there would expand scope without fixing anything that's broken.
- **Not** modifying `templates/shared/pr-process.md`. Its "Rebase" entry refers to GitHub's PR-merge dropdown option (a distinct concept from local branch sync) and is correct as-is.
- **Not** modifying the slash command's Step 5 confirmation message that mentions Karpathy. That output is shown once during init, not persisted to `CLAUDE.md`. *Acknowledged side-effect:* operators running v1.2.1 will see the confirmation reference Karpathy while the generated CLAUDE.md no longer does. Acceptable — confirmation is ephemeral output for the operator's eye, not the LLM-context anchor.
- **Not** removing "Karpathy" / "Andrej Karpathy" from `README.md`, `.claude-plugin/plugin.json` description, or the v1.2.0 entry in `CHANGELOG.md`. Attribution at the *plugin documentation layer* is acceptable. The directive scope is the *target project's* CLAUDE.md (where the LLM-context anchor lives), not the plugin's own metadata or release history. The v1.2.0 changelog entry is preserved as historical record of what v1.2.0 actually shipped.
- **Not** producing an automated migration tool for projects already initialized with v1.2.0. See §Migration below.

## Constraints

- **devbrew rule (CLAUDE.md `## When Editing This Repo`):** every PR touching `plugins/<name>/` must bump that plugin's `version` in the same commit, otherwise the cache key stays stale silently. SemVer interpretation here: this is a **patch** — fix to existing template behavior, no new surface, no breaking change to slash-command contract. Patch is correct vs. minor.
- **Same-day patch release.** v1.2.0 in `CHANGELOG.md` is dated `2026-05-07`. v1.2.1 ships the same day. The duplicate `2026-05-07` heading in `CHANGELOG.md` is intentional — this is a genuine same-day patch correcting v1.2.0 template defaults, not a typo.
- **devbrew rule (memory):** Korean-primary user-facing docs. This spec is written in English because it's an internal technical design doc, not a user-facing CLAUDE.md or philosophy document. Templates remain English (upstream convention).
- **Trivia escape (CLAUDE.md Law 1) does not apply:** this fix touches multiple files, includes new rule wording, and bumps version. Full design ceremony justified.
- **Persona file caveat (CLAUDE.md `## Plugin Shape` last bullet) does not apply:** this fix does not touch any reviewer persona file. Pure template content + bookkeeping.

## Acceptance Criteria

Static-checkable bullets (run as a single batch of grep + git commands at the end of implementation):

- [ ] `grep -r "git rebase origin" plugins/project-init/templates/` returns empty
- [ ] `grep -rn "Karpathy" plugins/project-init/templates/` returns empty (template directory only — `README.md`, `plugin.json`, `CHANGELOG.md` retain attribution per Non-goals)
- [ ] `grep -r "needs rebase" plugins/project-init/templates/` returns empty
- [ ] `grep -r "rebase from main" plugins/project-init/templates/github-flow/` returns empty
- [ ] `grep -rE "rebase from .develop." plugins/project-init/templates/git-flow/` returns empty
- [ ] `plugins/project-init/.claude-plugin/plugin.json` has `"version": "1.2.1"`
- [ ] `plugins/project-init/CHANGELOG.md` first `## [...]` heading is `## [1.2.1] — 2026-05-07`
- [ ] `plugins/project-init/CHANGELOG.md` 1.2.1 entry has both **Changed** (rebase→merge default + new rule line) and **Removed** (Karpathy attribution from template output) subsections, each with one-line rationale
- [ ] `docs/git-workflow/branch-strategy.md` (devbrew's consumer copy) receives the same three line-level edits and the same new rule line as `templates/github-flow/branch-strategy.md` (the two files happen to be byte-identical today and remain so after this fix; the AC verifies the edits, not the equality)
- [ ] All three modified `branch-strategy.md` files (two plugin templates + one devbrew copy) contain the new rule line: *"**ALWAYS** sync an existing feature branch with `git merge origin/main`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch."* (with `origin/develop` substituted for `origin/main` in the git-flow file)
- [ ] `git diff --stat HEAD -- plugins/project-init/ docs/git-workflow/branch-strategy.md` shows exactly 6 modified paths (the spec file at `docs/superpowers/specs/...` is excluded from this AC because it's tracked but not part of the implementation surface)

## Files to Modify

### Plugin source (`plugins/project-init/`)

1. **`templates/github-flow/branch-strategy.md`**
   - Line ~45 (the "Continuing work on an existing branch" code block): replace `git rebase origin/main` with `git merge origin/main`.
   - Line ~51 (the "After PR merge" bullet): replace `Or keep and rebase from main for follow-up work` with `Or keep and merge main in for follow-up work`.
   - Line ~60 (Rules for Claude): replace `When switching to an existing feature branch — check if it needs rebase from main` with `When switching to an existing feature branch — check if it needs sync from main`.
   - **Insert** a new rule line in "Rules for Claude" *immediately after* the existing "When switching to an existing feature branch..." line (so the sync-check rule and the sync-method rule are colocated):
     > `- **ALWAYS** sync an existing feature branch with `git merge origin/main`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.`

2. **`templates/git-flow/branch-strategy.md`**
   - Line ~80 (Rules for Claude): replace `When switching to an existing feature branch — check if it needs rebase from `develop`` with `When switching to an existing feature branch — check if it needs sync from `develop``.
   - **Insert** the same new rule line *immediately after* that line, with `origin/develop` substituted for `origin/main`:
     > `- **ALWAYS** sync an existing feature branch with `git merge origin/develop`, never `git rebase`. Rebase rewrites commit SHAs — unsafe on any pushed branch.`

3. **`templates/shared/llm-guidelines.md`**
   - Delete line 3 (the blockquote: `> Andrej Karpathy의 [LLM 코딩 관찰]...`) and line 4 (the blank line immediately following the blockquote).
   - Preserve line 2 (the blank line between the `## LLM Coding Guidelines` heading and what becomes the first bullet) — this maintains single-blank spacing between heading and first bullet, matching CommonMark conventions.
   - Heading and the 4 bullets remain unchanged.

4. **`.claude-plugin/plugin.json`**
   - `"version": "1.2.0"` → `"version": "1.2.1"`. No other field changes.

5. **`CHANGELOG.md`**
   - Insert a new entry directly above the `## [1.2.0] — 2026-05-07` heading:
     ```markdown
     ## [1.2.1] — 2026-05-07

     Same-day patch correcting v1.2.0 template defaults — intentional duplicate date.

     ### Changed
     - `templates/github-flow/branch-strategy.md` and `templates/git-flow/branch-strategy.md` now default to `git merge` for syncing a feature branch with its base. New "Rules for Claude" line cites the *"rebase golden rule"* (Pro Git §3.6 *"Rebasing"*) — rebase rewrites history and is unsafe on any pushed branch. Strict variant chosen (always merge, never rebase) for one-line teachability and force-push safety on local branches.

     ### Removed
     - Andrej Karpathy attribution blockquote (`> Andrej Karpathy의 [LLM 코딩 관찰]...`) is no longer injected into the target project's `CLAUDE.md`. The 4-bullet baseline is unchanged. Attribution preserved at the plugin layer (README, plugin.json description, slash-command confirmation, this changelog) — the directive applies only to the target project's LLM-context anchor.
     ```

### Devbrew project (consumer)

6. **`docs/git-workflow/branch-strategy.md`**
   - Apply the exact same edits as file #1 (rebase→merge example, three wording changes, plus the new rule line inserted at the same relative position). After this fix, file #6 and file #1 are byte-identical (incidental, not contractual).

## Migration

Projects already initialized with v1.2.0 retain their old artifacts:
- Karpathy blockquote in their `CLAUDE.md` `## LLM Coding Guidelines` section
- `git rebase origin/main` example in their `docs/git-workflow/branch-strategy.md`

**No automated migration is provided.** Two manual paths:
1. **Re-run `/project-init`.** Step 4c's 4-state matrix overwrites both managed CLAUDE.md sections (`## LLM Coding Guidelines` and `## Git Workflow`) and overwrites `docs/git-workflow/*.md` files in place. Custom non-managed content elsewhere in CLAUDE.md is preserved.
2. **Hand-edit.** Delete the Karpathy blockquote from CLAUDE.md and replace `git rebase origin/main` with `git merge origin/main` in `docs/git-workflow/branch-strategy.md`.

devbrew itself is migrated manually as file #6 in §Files to Modify above.

## Verification Plan

1. **Static checks (deterministic).** Run all bullets in §Acceptance Criteria as a single batch of grep + cat + git commands. Expected: all bullets pass.
2. **Round-trip test (manual).** In a throwaway directory:
   - Reload plugins (`/reload-plugins`) so the harness picks up v1.2.1 from the cache
   - Run `/project-init` in a fresh git repo, choose GitHub Flow + module scope + squash merge
   - Confirm: generated `docs/git-workflow/branch-strategy.md` uses `git merge origin/main` and contains the new rule line; generated `CLAUDE.md` `## LLM Coding Guidelines` section has the 4 bullets and **no** Karpathy blockquote
3. **No regression of unrelated content.** `git diff plugins/project-init/templates/` should show changes only on the lines specified in §Files to Modify. No reformatting, no whitespace churn, no other rule rewordings.
4. **Rollback path.** If the merge default proves wrong in a downstream project, `git revert <commit>` restores v1.2.0 templates. Plugin auto-bumps to v1.2.2 (revert-of-revert pattern) with restored rebase wording. No data migration needed — templates only.

## Rejected Alternatives

- **Apply the merge default to `templates/trunk-based/branch-strategy.md` for consistency.** Rejected: trunk-based currently has no rebase mention. Adding a rule there is *adding* content rather than *fixing* a regression. Out of scope.
- **Keep Karpathy attribution but wrap it in an HTML comment so it doesn't render.** Rejected: HTML comments still occupy the CLAUDE.md context buffer when the LLM reads it. The attribution is preserved at the plugin layer (README, plugin.json, slash-command confirmation, changelog) and in this design doc, which is sufficient for credit.
- **Fix all of devbrew's prior strict-replace regressions in this PR (CLAUDE.md Korean-primary, force-delete-branch line, plugin-name commit scope).** Rejected during Q1: owner chose plugin + minimal devbrew (just `branch-strategy.md`). Other regressions remain explicitly out of scope.
- **Use the standard "rebase golden rule" wording (allows rebase on personal pre-push branches).** Rejected: stored preference is the strict variant (`rebase 불가`, hard rule). The strict variant is also more newcomer-safe — no force-push surprises, no mental-model branching for "is this branch pushed yet?" — and the rule fits in one line. Accepted trade-off: experienced users who'd benefit from rebase on personal branches must opt out by ignoring the rule (which is fine — rules document the default, not a prohibition).
- **Bump to v1.3.0 (minor) instead of v1.2.1 (patch).** Rejected: no new user-facing capability is added. The slash command's interface is unchanged. Per SemVer, this is a patch.
- **Strip "Karpathy" from README, plugin.json, and the v1.2.0 CHANGELOG entry too.** Rejected: directive scope is *target project's* CLAUDE.md only. Plugin-layer attribution is fine and the v1.2.0 changelog entry is historical record (CHANGELOGs describe what *that version* shipped; v1.2.0 did ship with the blockquote, so the entry is accurate as-is).

## Metadata

- **Brainstorm session:** in-conversation, 2026-05-07
- **Approval gates passed:**
  - Q1 (scope): plugin + minimal devbrew (just `branch-strategy.md`)
  - Q2 (rule wording): explicit prefer-merge rule added to "Rules for Claude" sections
  - Technical validity (in-conversation): rebase-rewrites-history claim verified true; "unsafe on shared branches" verified true (Pro Git §3.6); strict prescription confirmed as defensible team default
  - Adversarial review (subagent, 2026-05-07): 12 findings; 8 important+critical applied, 1 minor (rule wording tone) applied; remaining minors (redundant ACs, blank-line precision wording) deemed not worth churn
- **Next step:** `superpowers:writing-plans` skill to produce a step-by-step implementation plan
- **References:**
  - Pro Git, Chapter 3.6 *"Rebasing"* — *"The Perils of Rebasing"* subsection (the canonical "rebase golden rule")
  - devbrew memory: `feedback_git_merge_over_rebase.md` (rebase 불가 hard rule)
  - devbrew memory: `feedback_plugin_version_bump.md` (cache-key invalidation requires version bump)
  - devbrew memory: `feedback_devbrew_design_lightness.md` (no new P# unless orthogonal — this fix instantiates existing rule, no philosophy edit)
  - devbrew CLAUDE.md `## When Editing This Repo` (plugin version bump rule)
  - devbrew CLAUDE.md `## Plugin Shape` first bullet (SemVer policy: major/minor/patch semantics)
