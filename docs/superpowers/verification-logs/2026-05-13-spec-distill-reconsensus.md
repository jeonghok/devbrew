# Verification Log — spec-distill v0.2.0 re-consensus gate

Date: 2026-05-13
Commit range: f68d616..HEAD
Worktree: .claude/worktrees/spec-distill-reconsensus-design

| V# | Description | Result |
|---|---|---|
| V0 | fixture 존재 사전 검증 (8 .md + 1 .sh) | PASS |
| V1 | plugin.json version 0.2.0 | PASS |
| V2 | spec-template locked_decisions frontmatter | FAIL |
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

## V2 FAIL — Detail

Command:
```python
python3 -c "import yaml, re; \
content = open('plugins/spec-distill/templates/spec-template.md').read(); \
fm = re.split(r'^---\s*$', content, maxsplit=2, flags=re.MULTILINE)[1]; \
d = yaml.safe_load(fm); \
assert 'locked_decisions' in d; \
print('V2 PASS')"
```

Output: `AssertionError` (exit code 1)

Root cause: `plugins/spec-distill/templates/spec-template.md` frontmatter does not contain a `locked_decisions` key. Current frontmatter keys are: `name`, `version`, `created_at`, `session_id`, `status`, `next_phase`, `source`. The `locked_decisions` field — required by the v0.2.0 re-consensus gate design — was not added to the template during implementation.

Required fix: add `locked_decisions: []` to the YAML frontmatter of `plugins/spec-distill/templates/spec-template.md`, and update `source` to reflect `spec-distill v0.2.0`.
