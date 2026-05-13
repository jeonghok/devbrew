# Verification Log — spec-distill v0.2.0 re-consensus gate

Date: 2026-05-13
Commit range: f68d616..HEAD
Worktree: .claude/worktrees/spec-distill-reconsensus-design

| V# | Description | Result |
|---|---|---|
| V0 | fixture 존재 사전 검증 (8 .md + 1 .sh) | PASS |
| V1 | plugin.json version 0.2.0 | PASS |
| V2 | spec-template locked_decisions frontmatter | PASS (after worktree cherry-pick fix) |
| V3 | reviewer agent affects_locked_decisions contract | PASS |
| V4 | routing table affects_locked column + [3.5] row | PASS |
| V5 | Mode B allowed_issue_ids + mode_b_violation | PASS |
| V6 | state schema 신규 필드 (pending_locked_decisions, reconsensus_accepted_ids, dismissed_by_user) | PASS |
| V7 | run-fixture-ac1.sh (AC1 integration) | PASS |
| V8 | DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS kill switch | PASS |
| V9 | v0.1.x backwards-compat (no locked_decisions key + migration spec) | PASS |
| V10 | reconsensus_count loop cap | PASS |
| V11 | README P17 + CHANGELOG 0.2.0 | PASS |
| V12 | E2E manual replay | DEFERRED (post-merge manual checklist) |

## Notes

- V3 and V4 used FIXED commands (replacing broken plan awk/grep — plan-level errata to address in v0.2.1).
- V12 is manual checklist deferred to PR review.
- All other commands run via grep/test directly on committed file state.

## V2 FAIL → Recovery — Detail

Initial run: V2 failed with `AssertionError`. Root cause: T2 implementer subagent committed `a9ed571` to **main branch** (not the worktree branch `worktree-spec-distill-reconsensus-design`) — likely due to absolute path resolution leaking outside the worktree during git operations. Worktree branch lacked the Task 2 commit.

Recovery: `git cherry-pick a9ed571` brought the template change into the worktree branch as commit `94282ac`. V2 re-run: PASS (`locked_decisions: []` present in frontmatter).

Side effect: `main` branch on the underlying repository (`/Users/jeonghokim/Downloads/devbrew`) now contains the orphan T2 commit (`a9ed571`) outside the worktree's PR. To clean up on the user's side (after PR merge): `git checkout main && git reset --hard origin/main` (or whatever is the appropriate upstream). This is a Subagent-Driven Development gotcha to be noted for the plugin retrospective — implementer subagents should be sandboxed strictly to worktree paths.
