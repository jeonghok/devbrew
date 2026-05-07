# CLAUDE.md Restructure Audit — Design

**Date:** 2026-05-07
**Status:** Draft
**Author:** brainstormed via `/superpowers:brainstorming`
**Validates:** commits c9e758d, c51d270, a65bbab (CLAUDE.md restructure)

## Context / Why

`CLAUDE.md` was heavily restructured in three recent commits: Three Laws section,
navigation hooks, plugin scaffolding section, Korean-primary single-file model.
The same window saw `docs/philosophy/devbrew-harness-philosophy.md` restructured
around §2 (Three Laws) and gain `P24`. Whenever two documents that cite each
other are restructured concurrently, citation drift is the dominant risk.

A preliminary spot-check already found likely drift: `CLAUDE.md` still claims
*"23 원칙·17 anti-pattern"* in two places, but philosophy.md now has 24
principles (P24 was added in 628b95f) and 14 visible anti-patterns
(AP1–9, AP12–16, post-§11.1 migration).

`/claude-md-improver` is the obvious tool, but its rubric is generic and
English-primary, designed for fitness-against-template rather than cross-doc
citation accuracy. This spec defines a custom validator that targets the
actual drift surface.

## Goals

1. Detect every broken markdown link, broken anchor, unresolved philosophy
   citation, and stale numeric claim in `CLAUDE.md`.
2. Auto-fix mechanical issues (count drift, near-match anchor drift) as a
   single, reviewable commit.
3. Produce a durable, discoverable audit report under
   `docs/superpowers/reports/` so future maintainers can confirm the
   restructure was validated.
4. Be re-runnable: a clean tree produces zero auto-fix findings and a
   `(no findings)` report.

## Non-goals

- Plugin README "Principles Instantiated" cross-checks.
  (Follow-up audit; would 4× implementation effort.)
- Validating `docs/git-workflow/*` content. Only verify `CLAUDE.md` links to
  those files correctly.
- Korean-primary style enforcement. That's a writing convention, not a drift
  check.
- Network-fetched URL validation. `http(s)://` links are skipped.
- Becoming a CI hook. This is a one-shot audit; lifting it into a hook is a
  separate decision.

## Constraints

- **Mechanical fixes only.** Citation typos (e.g. `P25` when `P21` was meant)
  are reported, not auto-fixed — they change meaning. This honors the user's
  explicit decision in brainstorming.
- **No new dependencies.** Audit is bash + standard tools (`grep`, `awk`,
  `git`). No `npm install`, no Python venv. Matches devbrew's
  hooks-and-templates style.
- **Korean-primary docs preserved verbatim.** Auto-fixes touch numeric tokens
  and anchor strings only — never prose.
- **Two-commit pattern required.** Audit report and auto-fix are separate
  commits so `git revert` of the fix doesn't unwind the report.

## Architecture

A single audit script (or short sequence of bash invocations — implementation
choice deferred to plan) runs against `CLAUDE.md` and
`docs/philosophy/devbrew-harness-philosophy.md`. Three independent passes;
a failure in one does not block the others.

| Pass | Input | What it checks |
|------|-------|----------------|
| 1. Anchor | `CLAUDE.md` markdown links | Target file exists; `#fragment` matches a heading |
| 2. Citation | `CLAUDE.md` philosophy tokens | Every `Law N`, `P##`, `AP##`, `§X.Y` resolves to a heading |
| 3. Count | `CLAUDE.md` numeric claims | Each claim matches the actual count in philosophy.md |

Output: one markdown report at
`docs/superpowers/reports/2026-05-07-claude-md-audit.md`. Mechanical fixes
become a separate commit on `CLAUDE.md`.

## Validation Rules

### Pass 1 — Anchor (markdown links)

For every `[text](path)` in `CLAUDE.md`:

- Relative path → file must exist on disk.
- `#fragment` present → fragment must match a heading after Github-flavored
  slugification (lowercase, spaces → `-`, strip punctuation except `-`).
- `http(s)://` URL → skip.

Findings: `BROKEN_LINK`, `BROKEN_ANCHOR`.

### Pass 2 — Citation (philosophy tokens)

Token regex: `\b(Law [1-3]|P[0-9]+|AP[0-9]+|§[0-9]+(\.[0-9]+)?)\b`

For each unique token in `CLAUDE.md`:

- `Law N` → must appear as a `### Law N` heading in philosophy.md.
- `P##` → must appear as a heading starting `### P##.` in philosophy.md.
- `AP##` → must appear as a heading starting `### AP##.` in philosophy.md.
- `§X` → must appear as a `## X.` heading; `§X.Y` → must appear as `### X.Y`.

Findings: `UNRESOLVED_CITATION`.

### Pass 3a — Count claims

| Claim phrase regex | Ground-truth source |
|---|---|
| `(\d+)개? 원칙` / `(\d+) 원칙` | count of `^### P\d+\.` headings |
| `(\d+)개? anti-pattern` | count of `^### AP\d+\.` headings |
| `(\d+)개? primitive` | count of `^### 4\.\d+` headings |
| `(\d+)개? tension` | count of `^### 5\.\d+` headings |

Findings: `COUNT_DRIFT` with `claimed=N, actual=M`. Auto-fixable.

### Pass 3b — Source-sentinel claims

For phrases like `네 소스`, `4 소스`, or `four source`: the four named sources
(`OMC`, `gstack`, `Ouroboros`, `CE`) must all appear at least once in §6
(Attribution Map) of philosophy.md.

Findings: `MISSING_SOURCE_SENTINEL` listing which named sources are absent.
**Report-only** — restoring a missing source is editorial, not mechanical.

### Auto-fix matrix

| Finding | Action |
|---|---|
| `BROKEN_LINK` | Report only |
| `BROKEN_ANCHOR` | Auto-fix if exactly one near-match (Levenshtein ≤ 2); else report |
| `UNRESOLVED_CITATION` | Report only (citation typos change meaning) |
| `COUNT_DRIFT` | Auto-fix |
| `MISSING_SOURCE_SENTINEL` | Report only |

## Files to Modify

- **Create:** `docs/superpowers/reports/2026-05-07-claude-md-audit.md`
- **Modify (auto-fix only):** `CLAUDE.md`
- **No other files touched.**

The audit script's location is an implementation choice deferred to the plan
phase. Candidate locations: `scripts/audit-claude-md.sh`, ad-hoc bash in the
session. Either is acceptable — the spec does not mandate persistence of the
script itself.

## Output Format

### Report at `docs/superpowers/reports/2026-05-07-claude-md-audit.md`

```markdown
# CLAUDE.md Audit — 2026-05-07

**Scope:** CLAUDE.md ↔ docs/philosophy/devbrew-harness-philosophy.md
**Restructure context:** Validates commits c9e758d, c51d270, a65bbab.

## Summary

- Pass 1 (Anchor): N findings, M auto-fixed
- Pass 2 (Citation): N findings, M auto-fixed
- Pass 3a (Count): N findings, M auto-fixed
- Pass 3b (Source sentinel): N findings (report-only)

## Findings

### BROKEN_LINK
(no findings) | bullets with `file:line` and reason

### BROKEN_ANCHOR
(no findings) | bullets; auto-fixed entries note the replacement

### UNRESOLVED_CITATION
(no findings) | bullets with `file:line` and the unresolved token

### COUNT_DRIFT
(no findings) | bullets with claimed/actual and **Auto-fixed** marker

### MISSING_SOURCE_SENTINEL
(no findings) | bullets listing which named sources are absent from §6

## Auto-fix diff

[git diff of the auto-fix commit, inlined]

## Recommended manual actions

[bullets, only present if there are report-only findings]
```

### Auto-fix commit message

```
docs(claude-md): fix mechanical drift caught by audit

- COUNT_DRIFT: 23 원칙 → 24 원칙 (P24 added in 628b95f)
- COUNT_DRIFT: 17 anti-pattern → 14 anti-pattern (post-restructure)
- BROKEN_ANCHOR: #three-laws-three → #the-three-laws

Audit report: docs/superpowers/reports/2026-05-07-claude-md-audit.md
```

If the audit finds zero auto-fixable findings, no auto-fix commit is created.

## Acceptance Criteria

The audit is complete when **all four** hold:

1. All three passes execute and produce findings. A pass that crashes
   mid-run is a failure; partial reports are not acceptable.
2. Auto-fixes applied as a single commit distinct from the report-write
   commit. Diff touches only `CLAUDE.md`. Empty auto-fix commits are not
   created.
3. Report at `docs/superpowers/reports/2026-05-07-claude-md-audit.md` exists
   and is committed, with all sections populated (empty subsections collapse
   to `(no findings)`).
4. Re-running the audit on the post-fix tree produces zero `COUNT_DRIFT` and
   zero `BROKEN_ANCHOR` findings. Report-only findings may persist.

## Verification Plan

1. Run audit on the current tree (HEAD = `feature/harness-philosophy` @ 628b95f).
2. Inspect generated report — confirm all four pass sections present.
3. Inspect auto-fix commit diff — confirm only `CLAUDE.md` modified, only
   numeric tokens and anchor strings changed.
4. Re-run audit on post-fix tree — confirm zero `COUNT_DRIFT` and zero
   `BROKEN_ANCHOR`.
5. Confirm report and fix-commit are visible in `git log` and the report
   file is grep-able from the repo root (Law 3 discoverability check).

## Rejected Alternatives

**A. Run `/claude-md-improver` as-is.** Rejected: rubric is English-primary
and assumes generic project structure, conflicting with devbrew's
Korean-primary, philosophy-anchored conventions
(`feedback_devbrew_korean_primary_docs`). Will produce false positives on
intentional structure choices and miss the cross-doc citation drift that
matters here.

**C. Hybrid (improver pass + custom validator).** Rejected: the improver's
generic findings would mostly be noise the user has to triage, adding
orchestration overhead for marginal additional value. The custom validator
alone targets the actual drift surface.

**Auto-fix `UNRESOLVED_CITATION` typos via Levenshtein.** Rejected: a
1-edit-distance match between citation tokens (e.g. `P12` → `P21`) is
phonetically/visually plausible but semantically distinct — wrong principle
changes meaning. User explicitly chose "auto-fix mechanical only" in
brainstorming.

**Plugin README cross-check in this spec.** Rejected from this iteration:
4× implementation effort, separable concern. Natural follow-up audit if
this one proves valuable.

## Metadata

- **Brainstorm date:** 2026-05-07
- **Brainstorming session decisions:** goal=validate restructure;
  scope=CLAUDE.md+philosophy cross-check; action mode=report+auto-fix
  mechanical; approach=B (custom validator only)
- **Next step:** invoke `superpowers:writing-plans` to produce
  implementation plan.
- **Out-of-band invariants:** spec must be self-contained — readable without
  re-reading the brainstorming transcript.
