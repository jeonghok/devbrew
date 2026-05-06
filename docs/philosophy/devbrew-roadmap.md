# devbrew Post-Harvest Roadmap

> **Research is done. This is the build sequence.**
>
> *69 candidate patterns from 4 source harnesses, distilled into 6 phases. Each phase has acceptance criteria, ordering constraints, and a version number. Per-plugin specs are written when each phase starts — not before.*

This document is the bridge between research ([`plugin-harvest-rounds.md`](../research/plugin-harvest-rounds.md)) and execution. It turns the Candidate Registry (C1–C69) into Go/Park/Kill decisions with a phased build order. The harvest file has the analysis; this file has the decisions.

**Sources harvested:** oh-my-claudecode v4.9.1 (R1), gstack (R2), ouroboros v0.28.7 (R3), compound-engineering v2.66.1 (R4).

**Validated by:** 4 cross-reference analyses (one per harness), each checking for misassignments, missing acceptance criteria, anti-recommendation violations, and unresolved open questions.

## How to Read This Document

- **Go** — committed to build, assigned to a phase.
- **Park** — deferred with a testable un-parking condition. Not abandoned.
- **Kill** — permanently rejected with rationale.
- Each **Phase** section contains: scope, candidates, within-phase build order, ordering constraints, and exit criteria.
- Candidates are referenced by **ID only** (e.g., "C2 — physical tool scoping"). Full analysis is in the [harvest file](../research/plugin-harvest-rounds.md).
- **Priority rubric** (from harvest): `(laws_covered × gap_severity × round_reinforcement) / build_cost`.

## Decision Summary

| id | pattern | disposition | phase |
|---|---|---|---|
| C1 | Ambiguity-gated spec authoring | Go | 2b |
| C2 | Physical tool scoping (PreToolUse hook) | Go | 1e |
| C3 | Learner skill (3-point extraction gate) | Go | 4a |
| C4 | Wiki/index triad | Go | 4a |
| C5 | PreCompact state snapshot | Go | 3 |
| C6 | Three-tier verification | Go | 1b |
| C7 | Stagnation detection (circuit breaker) | Go | 2a |
| C8 | Keyword pre-routing | Park | — |
| C9 | Dimensional progress tracking | Go | 2e |
| C10 | RALPLAN-DR plan format | Go | 0 |
| C11 | Kill-switch convention | Go | 0 |
| C12 | Hook signal-tag namespacing | Go | 0 |
| C13 | *(retired)* | Kill | — |
| C14 | Agent role-prompt opener | Go | 0 |
| C15 | Commit-trailer audit | Go | 5 |
| C16 | Cross-model adversarial routing | Park | — |
| C17 | Per-agent benchmark harness | Park | — |
| C18 | Agent `level: N` tag | Park | — |
| C19 | Two-stage reviewer protocol | Go | 1b |
| C20 | Standardized verdict schema | Go | 1a |
| C21 | Dual-harness packaging | Park | — |
| C22 | Working agreements block | Go | 0 |
| C23 | Lane-grouped agent catalog | Park | — |
| C24 | Multiple specialized reviewers | Go | 1d |
| C25 | Dual-lifetime memory tags | Go | 4a |
| C26 | Template-driven skill codegen | Park | — |
| C27 | `preamble-tier` frontmatter | Go | 0 |
| C28 | `benefits-from` handoff dependency | Go | 0 |
| C29 | Skill-level PreToolUse hooks | Park | — |
| C30 | Per-finding JSON output contract | Go | 1a |
| C31 | Review army scope-gated dispatch | Go | 1c |
| C32 | Expanded specialist catalog | Go | 1d |
| C33 | Always-on adversarial review | Go | 1c |
| C34 | Plan/audit boomerang | Go | 2d |
| C35 | Two-tier test classification | Go | 1b |
| C36 | Review readiness dashboard | Go | 1f |
| C37 | Retrospective `/retro` | Park | — |
| C38 | Host adapter registry | Park | — |
| C39 | Persistent runtime daemon | Park | — |
| C40 | AI-slop blacklist | Park | — |
| C41 | Prompt-injection defense | Go | 0 |
| C42 | Tiered review gating | Go | 1c |
| C43 | Socratic interview (4-path routing) | Go | 2c |
| C44 | Dialectic rhythm guard | Go | 2c |
| C45 | Breadth-keeper agent | Go | 2c |
| C46 | Lateral thinking personas | Go | 2a |
| C47 | PAL Router | Park | — |
| C48 | Event-sourced state | Kill | — |
| C49 | Seed immutability | Go | 2b |
| C50 | MCP-first with plugin fallback | Go | 0 |
| C51 | Ontological questioning | Go | 2c |
| C52a | Consensus triggers (structural) | Go | 1b |
| C52b | Consensus triggers (drift-aware) | Go | 2d |
| C53 | Answer prefix convention | Go | 2e |
| C54 | Drift measurement formula | Go | 3 |
| C55 | Seed schema (markdown+frontmatter) | Go | 2b |
| C56 | Autofix routing (4-level) | Go | 1a |
| C57 | Review mode detection | Go | 0 |
| C58 | Document-review skill | Go | 2d |
| C59 | Full compound cycle reference | Go | 0 |
| C60 | Scope-adaptive depth | Go | 2d |
| C61 | 5-dimension overlap detection | Go | 4c |
| C62 | Session historian | Park | — |
| C63 | False-positive suppression lists | Go | 1f |
| C64 | `disable-model-invocation` | Go | 0 |
| C65 | Run artifact persistence | Go | 3 |
| C66 | Linked artifact flow | Go | 0 |
| C67 | Execution strategy selector | Go | 0 |
| C68 | Adversarial 4-technique framework | Go | 1f |
| C69 | Grep-first learnings search | Go | 4b |

**Total: 53 Go + 14 Park + 2 Kill = 69.**

---

## Phase 0 — Convention Sweep

Docs, READMEs, and prompt changes only. No new plugin code. Single PR.

**Candidates:** C10, C11, C12, C14, C22, C27, C28, C41, C50, C57, C59, C64, C66, C67.

**Retrofit items:** CHANGELOG.md for both plugins, "Principles Instantiated" README sections, `cost_class` declarations on quality-pipeline skill and runtime-verifier agent, SKILL.md frontmatter schema spec.

**Key deliverable — C57 (review mode detection):** Required prerequisite for Phase 1a. Four modes: `headless` / `autofix` / `report-only` / `interactive`. Detection logic must be documented before Phase 1 begins.

**Reconciliation principle** (R2 "Boil the Lake" vs P8): *"Tests boil the lake; production code deletes ruthlessly."*

**Exit criteria:**
- Both plugins pass full CLAUDE.md Plugin Shape checklist.
- C57 mode detection spec documented.
- quality-gates v1.4.1, project-init v1.1.1.

---

## Phase 1 — quality-gates Reviewer Hardening

**Score:** 8.0 (highest). **Laws:** 1+2. **Cost:** S. **Ships:** quality-gates v1.5.0.

**Candidates (16):** C2, C6, C19, C20, C24, C30, C31, C32, C33, C35, C36, C42, C52a, C56, C63, C68.

### Build order

**1a — Unified review output schema** (foundation; depends on Phase 0 C57):
- C20: Verdict envelope (APPROVE / REQUEST CHANGES / COMMENT × CRITICAL / HIGH / MEDIUM / LOW).
- C30: Per-finding payload (`severity`, `confidence` 1–10, `path`, `line`, `category`, `summary`, `fix`, `fingerprint`, `specialist`). Sentinel: `NO FINDINGS`. Confidence rubric: 9–10 show, 7–8 show, 5–6 caveat, 3–4 suppress, 1–2 P0-only.
- C56: Autofix disposition (4 levels): `safe_auto` → review-fixer, `gated_auto` → downstream-resolver (`AskUserQuestion` per P22), `manual` → human, `advisory` → release.

**1b — Verification tightening** (builds on 1a):
- C6: Tighten 3-tier mapping (Mechanical $0 → Semantic $$ → Consensus $$$).
- C19: Two-stage protocol (spec compliance → code quality).
- C52a: Structural consensus triggers (4 of 7): SEED_MODIFICATION, ONTOLOGY_EVOLUTION, GOAL_INTERPRETATION, MANUAL_REQUEST. Drift-aware triggers (C52b) deferred to Phase 2d.
- C35: Two-tier test classification (gate / periodic) + diff-based selection. Cost tiers: <5s free, E2E ~$3.85/run behind gate, LLM-judge ~$4/run strong gate.

**1c — Fan-out trinity** (depends on 1a for dispatch targets):
- C31: Scope-gated dispatch. Always-on: Testing + Maintainability (≥50 LOC). Conditional by `SCOPE_*` env vars. `[NEVER_GATE]` floor for Security + Testing.
- C33: Always-on adversarial. Never conditional on LOC or risk signals. Never gates shipping — advisory only.
- C42: Tiered gating. Eng-review = single hard gate. All specialist reviews = advisory.

**1d — Specialist expansion** (gated on 1c):
- C24: api-reviewer + performance-reviewer.
- C32: data-migration, maintainability, red-team. Each outputs JSON per C30 schema.

**1e — Physical enforcement** (parallel with 1c–1d):
- C2: PreToolUse hook enforcing blanket `disallowedTools: Write, Edit` on ALL review-role agents. Ecosystem-wide, not per-agent.

**1f — Polish** (final):
- C36: Review readiness dashboard (stale = >7 days OR HEAD changed).
- C63: Per-reviewer "What NOT to flag" lists.
- C68: Adversarial 4-technique framework (assumption violation, composition failures, cascade construction, abuse cases). Depth-calibrated: Quick / Standard / Deep.

### Constraints

- All enforcement at agent layer (C2 PreToolUse), NOT skill-level `allowed-tools`.
- Zero Tier 1 self-review. All fixes require Tier 2 or Tier 3 review.

### Exit criteria

- quality-gates v1.5.0.
- Unified 3-layer schema: verdict + per-finding + autofix.
- PreToolUse hook blocks Write/Edit for all review agents (C2).
- Scope-gated dispatch with `[NEVER_GATE]` on Security + Testing (C31).
- Adversarial: always-on, 4 techniques (C33 + C68).
- New specialists: api, performance, data-migration, maintainability, red-team (C24 + C32).
- Two-tier test classification (C35).
- CHANGELOG.md entry.

---

## Phase 2 — spec-authoring Plugin + Stagnation Library

**Score:** 6.0 + 3.0 (stagnation absorbed). **Laws:** 1+3. **Cost:** M. **Ships:** `plugins/spec-authoring/` v0.1.0.

**Candidates (15):** C1, C7, C9, C34, C43, C44, C45, C46, C49, C51, C52b, C53, C55, C58, C60.

### Build order (strictly serialized)

**2a — Stagnation library** (prerequisite for interview loops):
- C7: Circuit breaker. 4 patterns: SPINNING (sha256 repeat, threshold=3), OSCILLATION (A↔B, threshold=2), NO_DRIFT (delta<0.01, threshold=3), DIMINISHING_RETURNS (improvement<0.01, threshold=3).
- C46: Persona recovery. Affinity: HACKER→SPINNING, RESEARCHER→{NO_DRIFT, DIMINISHING_RETURNS}, SIMPLIFIER→{DIMINISHING_RETURNS, OSCILLATION}, ARCHITECT→{OSCILLATION, NO_DRIFT}, CONTRARIAN→all. Deterministic first-match.
- Location: shared `scripts/` for cross-plugin reuse.

**2b — Core gate** (depends on 2a):
- C1: Structural ambiguity gate. Mandatory sections: Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata. Structural first; numerical optional.
- C55: Seed schema as markdown + YAML frontmatter (NOT .yaml files). 7 core fields: `goal`, `task_type`, `constraints`, `acceptance_criteria`, `exit_conditions`, `metadata`, `brownfield_context`. Optional: `ontology_schema`, `evaluation_principles`, `ambiguity_score`.
- C49: Seed immutability via git versioning (NOT event sourcing). Modifications trigger C52a SEED_MODIFICATION.

**2c — Interview system** (depends on 2a + 2b):
- C43: 4-path routing. PATH 1a auto-confirm factual (marked `[from-code][auto-confirmed]`). PATH 2 human judgment = default.
- C44: Dialectic rhythm guard. 3 consecutive non-user answers → force PATH 2.
- C45: Breadth-keeper agent (`disallowedTools: Write, Edit`).
- C51: Ontological questioning (5 types: ESSENCE, ROOT_CAUSE, PREREQUISITES, HIDDEN_ASSUMPTIONS, EXISTING_CONTEXT). Available in Standard/Deep scope; skip Lightweight.

**2d — Document review** (depends on Phase 1 reviewers):
- C58: 2 always-on (coherence + feasibility) + 5 conditional. Dispatches to Phase 1 reviewer pool.
- C34: Plan/audit boomerang (symmetric pre-work + post-work review).
- C60: Scope-adaptive depth. Lightweight / Standard / Deep. LLM auto-assess + `AskUserQuestion` override.
- C52b: Drift-aware triggers (SEED_DRIFT_ALERT >0.3, STAGE2_UNCERTAINTY >0.3, LATERAL_THINKING_ADOPTION). Partial until Phase 3 ships drift measurement.

**2e — Provenance** (additive):
- C53: Answer prefixes: `[from-code][auto-confirmed]`, `[from-code]`, `[from-user]`, `[from-research]`.
- C9: Dimensional scoring (optional — adopt only if structural gate proves insufficient).

### Constraints

- User confirmation gate between all pipeline stages (no auto-decide).
- Structural gate first; numerical scoring never primary.
- Seed schema = markdown + frontmatter, never raw YAML.

### Exit criteria

- `plugins/spec-authoring/` v0.1.0 (Principles Instantiated: Law 1 / P1 / P2).
- Stagnation library: 4 patterns, sha256, persona recovery (C7 + C46).
- Structural gate with mandatory sections (C1).
- Seed schema: 7 core fields, markdown + frontmatter (C55).
- Interview: 4-path routing, rhythm guard, breadth-keeper (C43 + C44 + C45).
- Document-review dispatching to Phase 1 reviewers (C58).
- CHANGELOG.md.

---

## Phase 3 — State Persistence + Drift Libraries

**Score:** 3.0. **Cost:** M. **Ships:** shared library modules.

**Candidates (3):** C5, C54, C65.

- C5: PreCompact state snapshot. Markdown: `.claude/<plugin>.local.md`. Fallback to Stop-hook if PreCompact unreliable.
- C54: Drift measurement. 3-axis weighted Jaccard (Goal 0.5, Constraint 0.3, Ontology 0.2). Threshold ≤ 0.3. Start point-in-time; add continuous in v0.2.0.
- C65: Per-run artifacts as `.claude/<plugin>-<run-id>.local.md`. Markdown, not directories.

**Exit criteria:**
- PreCompact hook with Stop-hook fallback (C5).
- Drift library: 3-axis Jaccard, configurable thresholds (C54).
- Per-run markdown artifacts (C65).
- `trusted: false` default on cross-project state.
- Kill switch: `DEVBREW_SKIP_HOOKS=state-persistence:pre-compact`.

---

## Phase 4 — compounding-learnings Plugin

**Score:** 2.25. **Laws:** 3. **Cost:** M. **Ships:** `plugins/compounding-learnings/` v0.1.0.

**Candidates (5):** C3, C4, C25, C61, C69. Depends on Phase 3.

**4a — Core** (first compound cycle):
- C3: Learner skill with 3-point gate (non-Googleable / context-specific / hard-won).
- C4: Wiki/index triad (write → SessionStart reads → PreCompact persists).
- C25: Dual-lifetime tags (7-day / permanent). `trusted: false` for cross-project.

> **Note (2026-05-06):** Phase 4a candidates C3+C4+C25+C69 are now first-class operational content of philosophy §4.6 Compounding Skill primitive (see philosophy.md §4.6 + Law 3 corollary).

**4b — Read side:** C69. Grep-first 7-step search. Acceptance: recall >85%, precision >80%.

**4c — Write side:** C61. 5-dimension overlap (problem, root cause, solution, files, prevention). High (4-5) → update. Moderate (2-3) → create + flag. Low (0-1) → create.

**Exit criteria:**
- `plugins/compounding-learnings/` v0.1.0 (Principles Instantiated: Law 3 / P5 / P14).
- 3-point extraction gate (C3). Discoverability check (Law 3 corollary).
- Overlap detection: 5-dimension, zero false-negatives >70% (C61).
- Grep search: recall >85%, precision >80% (C69).
- Kill switch: `DEVBREW_DISABLE_COMPOUNDING_LEARNINGS=1`.

---

## Phase 5 — project-init Enhancements

**Cost:** S. **Ships:** project-init v1.2.0. Independent — parallel with Phases 2–4.

**Candidate (1):** C15. Commit-trailer schema: `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:`. Trivia escape: skip for one-sentence diffs.

**Exit criteria:** project-init v1.2.0. Trailer template + optional PostToolUse validation hook. CHANGELOG.md entry.

---

## Parked Items

| id | pattern | reason | un-parking condition |
|---|---|---|---|
| C8 | Keyword pre-routing | S cost, not in top-6 | >3 plugins with keyword-triggered skills |
| C16 | Cross-model adversarial | L cost, multi-model required | Multi-model API verified + C7 shipped |
| C17 | Per-agent benchmark | L cost | User budgets 1 week |
| C18 | Agent `level: N` | Philosophy-only | Philosophy revision cycle |
| C21 | Dual-harness | Claude-Code-only | devbrew targets other runtimes |
| C23 | Lane-grouped catalog | Low agent count | Agent count > 10 |
| C26 | Skill codegen | Build step overhead | >10 plugins + authoring bottleneck |
| C29 | Skill-level hooks | Q9 unresolved | Claude Code docs confirm SKILL.md hooks |
| C37 | Retrospective | Not core to Three Laws | Phase 4 shipped |
| C38 | Host adapters | Out of scope | Same as C21 |
| C39 | Runtime daemon | L cost | User budgets + runtime-verifier insufficient |
| C40 | AI-slop blacklist | Unverified (reported) | Main-thread cite obtained |
| C47 | PAL Router | Multi-model required | Same as C16 |
| C62 | Session historian | Cross-platform | Phase 4 shipped + Claude-Code-only scoped |

## Killed Items

| id | pattern | reason |
|---|---|---|
| C13 | *(original benchmark)* | Retired R1, superseded by C17 |
| C48 | Event-sourced state | Permanent conflict with markdown-state mandate |

---

## Phase Dependency Graph

```
Phase 0 ─── C57 required ──→ Phase 1
                                 │
                    ┌────────────┼────────────┐
                    ▼            │            ▼
                Phase 2         │        Phase 5
                    │           │      (parallel)
                    ▼           │
                Phase 3         │
                    │           │
                    ▼           │
                Phase 4         │
```

**Parallelization:** Phase 5 with anything after Phase 0. Phase 2a can start parallel with Phase 1d–1f. Phases 3→4 strictly sequential. C52 split: C52a in Phase 1b, C52b in Phase 2d.

---

## Open Questions

### Resolved

| Q | Decision | Rationale |
|---|---|---|
| Q1 | C2 = ecosystem-wide blanket | OMC's agent-by-agent is inconsistent |
| Q2 | Learnings index = per-plugin `docs/learnings/` | Plugin-local, grep-discoverable |
| Q8 | Fan-out via C31 + C33 + C42 trinity | Scope gating + advisory tiers |
| Q13 | `[NEVER_GATE]` for Security + Testing | Others gate after 0-finding runs |
| Q15 | PATH 1a allowed, marked `[from-code]` | 3 sources converge; provenance preserves trust |
| Q18 | Frozen specs via git versioning | C48 killed |
| Q19 | C51 in Standard/Deep, not Lightweight | Available when scope warrants |
| Q22 | 7 core seed fields; 3 optional | Start minimal, expand when proven |
| Q23 | 4-level autofix | CE shipped 60+ versions |
| Q24 | `mode:headless` adopted | Required for composition |
| Q25 | C58 bundled in Phase 2d | Related workflow |
| Q30 | `.claude/<plugin>-<run-id>.local.md` | Markdown convention |

### Carried Forward

| Q | Blocks | Decision deferred to |
|---|---|---|
| Q3 | Phase 3 | PreCompact reliability; Stop-hook fallback |
| Q9 | C29 un-parking | Claude Code docs |
| Q17 | Phase 2a | Start deterministic, measure |
| Q21 | Phase 3 | Point-in-time first, continuous v0.2.0 |
| Q26 | Phase 2d | LLM auto-assess + override |
| Q27 | Phase 4c | Adapt dimensions to devbrew |

---

## Metadata

- **Created:** 2026-04-16
- **Branch:** `feature/harness-philosophy`
- **Harvest source:** [`docs/research/plugin-harvest-rounds.md`](../research/plugin-harvest-rounds.md) (4 rounds, 69 candidates)
- **Philosophy anchor:** [`docs/philosophy/devbrew-harness-philosophy.md`](devbrew-harness-philosophy.md) (3 Laws, 23 principles, 17 anti-patterns)
