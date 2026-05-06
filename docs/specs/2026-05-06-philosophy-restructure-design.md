---
spec: 2026-05-06-philosophy-restructure
author: Jeongho-K
created: 2026-05-06
status: design-approved (post-adversarial-pass-v2)
parent: docs/philosophy/devbrew-harness-philosophy.md
---

# Philosophy Doc Restructure — Three Laws Taxonomy + Roadmap Absorption

> **Revision history:** v1 spec → adversarial subagent attack → v2 (this doc). v2 applies 1 P0 + 8 P1 findings: dropped proposed P24 (folds into §4.6 expansion per lightness meta-principle), moved P18 from Law 3 to Cross-cutting (stagnation is verification not compounding), recount of "modified principles" from 14 → 16, Appendix A quote policy explicit, header form binding, plugin READMEs scoped out, two-commit boundary inside single PR.

## 1. Context / Why

The devbrew harness philosophy doc was established two commits ago (`3daa324`, 2026-05-01) with §1 Three Laws + §2 P1–P23 + §3 AP1–AP17 + §4 4.0–4.10 primitives. Immediately after, a 69-candidate roadmap (`6f964f9`) was committed on top — but a substantial subset of its 53 Go candidates do not cleanly map to existing P# / AP# IDs, creating a roadmap-philosophy drift.

Three concrete observations triggered this work:

1. **Roadmap candidates without homes.** C20+C30 (verdict schema), C43+C44+C45+C51 (Socratic interview), C56 (autofix tiers), C57 (review modes), C68 (adversarial 4-technique), C3+C4+C25+C69 (compounding discoverability) are first-class operational patterns absorbed into the roadmap as Go items but never elevated to philosophy. Future plugin authors would need to reverse-engineer them from roadmap phase descriptions.
2. **Self-inconsistency in §2 organization.** §2 first sentence reads *"Principles (flow from the three laws)"* — yet §2 is organized as a flat P1–P23 list with no structural mapping to which Law each principle serves.
3. **Concept duplication.** Several principle/anti-pattern pairs restate the same concept (P3↔AP11 tool scoping, P5↔AP10 filesystem-as-memory, P14↔AP17 state-survives-compaction). The "trivia escape" mechanism appears in 4 different sections (Law 1 corollary, P12 exception, AP5, §4.1 escape hatch) — discoverability gap.

This restructure addresses all three by:

- Reorganizing §2 around the Three Laws (§2.1 Law 1 / §2.2 Law 2 / §2.3 Law 3 / §2.4 cross-cutting).
- **Absorbing all 53 Go roadmap candidates into existing principles, §4 primitives, or marking already-covered** — **zero new principles** (lightness meta-principle applied uniformly, including to candidates initially proposed as new principles).
- Nesting 14 APs as anti-corollaries under their parent P, fully absorbing 3 (AP10, AP11, AP17) into parent body.
- Consolidating the "trivia escape" mechanism to a single canonical mention (under P12) with cross-refs from Law 1 corollary / AP5 entry / §4.1 escape hatch.

The restructure is **non-breaking at the citation level** — all P1–P23 IDs remain stable; only their physical location moves. No P24 introduced.

## 2. Goals

1. Reorganize §2 into Three Laws sub-sections (§2.1–§2.4) with anti-patterns nested as anti-corollaries.
2. Absorb roadmap gaps **without adding new principles**: 16 P content/structure modifications + 2 §4 primitive expansions (§4.4 + §4.6) + Law 3 corollary tightening, per §11.1 / §11.3. Zero new principles (lightness binding).
3. **Retire bilingual `*.ko.md` companion model.** Collapse each `*.md`/`*.ko.md` pair into a single Korean-primary `*.md` file. CLAUDE.md "Korean parity, no drift" house rule replaced with new "Korean-primary, English-terms-only" rule.
4. Sync derivative docs: roadmap broken-link cleanup + CLAUDE.md §3 reference update to §2.

## 3. Non-Goals

- Adding new Three Laws (Three Laws are frozen).
- Adding any new principle. Lightness is binding even at the cost of "ought-to-be-a-principle" candidates becoming primitive expansions.
- Modifying §0 / §5 / §7 / §8 / §9 / §10 *content* — only mechanical P# / anchor updates + Korean-primary phrasing pass.
- Modifying Appendix A *quotes* — they are preserved verbatim in original language (no glosses added either way).
- Plugin code changes (docs-only PR).
- **Plugin README updates.** `plugins/*/README*.md` and any `plugins/*/README.ko.md` are out of scope. Bilingual policy migration on plugin READMEs is a separate follow-up; this PR's CLAUDE.md house rule update applies to *future* plugin READMEs.
- **Maintaining bilingual `*.ko.md` parity.** That model is RETIRED in this PR (Goal 3); future docs are Korean-primary single-file.
- Translating English-canonical content paragraph-by-paragraph. Korean content already exists in `*.ko.md` and serves as the migration base.
- Polishing Korean prose throughout the doc. Phrasing pass only on changed/restructured sections; unchanged sections inherit existing Korean as-is.
- Cleaning up `docs/git-workflow/` broken links in CLAUDE.md (independent of philosophy restructure; separate PR).
- Synchronizing the untracked `docs/research/plugin-harvest-rounds.md` (out of repo scope until committed).
- Korean-izing the spec file itself (this `docs/specs/*.md` is a planning artifact; policy applies to user-facing output docs).

## 4. Constraints

- **Single PR, two logical commits within the squash branch.** Commit-1: Three Laws restructure + roadmap absorption (operates on `.md` and `.ko.md` lockstep, parity preserved). Commit-2: Bilingual retirement (overwrite `.md` with `.ko.md` content, `git rm` `.ko.md`, update CLAUDE.md house rule). Squash-merged as one PR; reviewer sees 2 commits in PR; final history has 1 squash commit. Rationale: enables isolated rollback if Commit-2 (bilingual policy) is rejected without losing Commit-1 work.
- **Korean-primary single-file model after Commit-2.** No `*.ko.md` companion. Use `.ko.md` content as migration base (already Korean), apply Three Laws restructure to it, save as `.md` (overwriting English), `git rm` the `.ko.md`.
- **English preserved only for** identifiers (P#, AP#, Law N, §X.Y), proper nouns (OMC, gstack, Ouroboros, CE, Anthropic), source quotes (verbatim, no gloss added), technical terms without natural Korean equivalents (e.g., `frontmatter`, `PreCompact`).
- **Header form binding (resolves former §10 open question):** §-anchored sections and L#/P#/AP# headers stay English (identifier rule). Narrative sub-headers (e.g., "Corollary", "Why this matters") become Korean. Drop bilingual parentheticals like "Law 1 — Clarity Before Code (코드보다 명확성 먼저)" — keep the English title; surrounding prose is Korean.
- **Appendix A quote policy:** Preserved verbatim in original language. Quotes originally in Korean (e.g., Ouroboros README *"AI는 무엇이든 만들 수 있다…"*) stay Korean with no English gloss. Quotes originally in English (Klaassen, Anthropic, OMC) stay English with no Korean gloss. Strip the existing parenthetical translations from `.ko.md` Appendix A only where they were translations of the English-original quotes.
- **Attribution Map (philosophy §6) cell language:** Source-name cells stay English (proper nouns); modifier-prose cells (e.g., "implicit in all harnesses", "indirect") become Korean. Apply consistent pattern across all 41 rows.
- **CLAUDE.md "Forbidden Patterns" anti-pattern names** (Self-approval, Polite stop, Trivia ceremony, Subagent spray, Unbounded autonomy) stay as English identifiers — they are cited verbatim in code reviews.
- **No P# renumbering.** All existing P1–P23 IDs preserved (only relocated). **No new P# introduced** (P24 from v1 spec rejected per Finding 5.1).
- **Physical absorption, not anchor renaming.** When AP10/AP11/AP17 absorb into parent P body, their old IDs become entries in §11 Migration Table (B.1) — no silent removal.
- **All AP IDs remain greppable.** Either (a) nested as anti-corollary with `## AP\d+` header preserved, or (b) recorded in §11.B.1 with new location.
- **"Trivia escape" canonical mention enforcement (resolves Finding 3.1):** ONE canonical statement under P12 exception. Law 1 corollary + AP5 (now nested under P12) + §4.1 escape hatch reduce to 1-line cross-refs pointing to P12.
- **Adversarial pass before commit** (per AP14 Unchallenged Consensus + Law 2). v1 spec already attacked (this v2 incorporates findings); a second pass attacks the implementation output before final commit.
- **Lightness as governing principle** (per session feedback). Default to absorbing roadmap candidates into existing principles or §4 primitives; reject any new P# escalation.

## 5. Acceptance Criteria

### 5.1 Mechanical (greppable / scriptable)
1. **AC1a:** `awk '/^## /{print}' devbrew-harness-philosophy.md` returns headers in exact order `## 1`, `## 2`, `## 2.1 Under Law 1`, `## 2.2 Under Law 2`, `## 2.3 Under Law 3`, `## 2.4 Cross-Cutting Commitments`, `## 3 ...`, `## 4 ...`, ..., `## 11 ...`, `## Appendix A`.
2. **AC1b:** For each P# (P1–P23), the parent `## 2.X` header above it matches §11.1's Law column for that P#.
3. P1–P23 IDs all present in §2 body (verifiable: `for n in $(seq 1 23); do grep -q "^### P$n " devbrew-harness-philosophy.md || echo "MISSING P$n"; done`).
4. **No P24** in §2 body or §6 Attribution Map (verifiable: `grep -c '^### P24 ' devbrew-harness-philosophy.md` returns 0).
5. AP10, AP11, AP17 absorbed into parent P body; zero standalone `## AP10`, `## AP11`, `## AP17` headers.
6. AP1–AP9, AP12–AP16 nested as anti-corollaries with `## AP\d+ ` header preserved (verifiable: `grep -c '^### AP' devbrew-harness-philosophy.md` returns 14).
7. §3 reduced to a 3-line redirect block pointing to §2 + §11.
8. §11 Migration Table present with 2 sub-tables: B.1 Anti-pattern disposition (17 rows), B.2 Principle changes (16 rows: 16 modified existing P, no new P).
9. §4 primitives each tagged `[Serves: L#]` (1, 2, 3, or combinations); verifiable: `grep -c '^### 4\.' philosophy.md` matches `grep -c '\[Serves: L' philosophy.md`.
10. §6 Attribution Map updated: expansion notes per existing P; no P24 row.
11. Post-merge `docs/philosophy/devbrew-roadmap.md`: zero `_retrofit-status.md` references (verifiable: `grep -c '_retrofit-status' docs/philosophy/devbrew-roadmap.md` returns 0).
12. `devbrew-harness-philosophy.ko.md`, `devbrew-roadmap.ko.md`, `CLAUDE.ko.md` deleted (`ls` returns "No such file or directory" for each).
13. CLAUDE.md `When Editing This Repo` section: contains string "Korean-primary, English-terms-only" and does NOT contain "Korean parity, no drift".
14. CLAUDE.md line ~76 §3 reference updated to §2 (verifiable: no `philosophy.md.*§3` link in CLAUDE.md after the redirect).

### 5.2 Semantic (review-judged)
15. 16 existing principles modified per §11.1: P2, P3, P4, P5, P6, P8, P9, P10, P11, P12, P14, P16, P17, P18, P19, P22 (count verifiable against §11.1 / §11.3 ledger; "modification" = expanded with C# OR body-absorbs AP OR nests AP as anti-corollary).
16. §4.6 Compounding Skill primitive expanded with C3+C4+C25+C69 content: 3-point extraction gate, wiki/index triad, dual-lifetime memory tags, grep-first learnings search. Law 3 corollary tightened to point at §4.6 for the discoverability mechanism.
17. §4.4 Reviewer Agents primitive expanded with C20+C30 (verdict envelope + per-finding payload contract).
18. "Trivia escape" rule appears as ONE canonical paragraph under P12 exception; Law 1 corollary + AP5 + §4.1 escape hatch each reduced to a 1-line cross-ref to P12.
19. Adversarial pass on implementation output (separate from this v2 self-review on the spec) produces 0 P0/P1 findings.

## 6. Files to Modify

| File | Change kind | Approx diff |
|---|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | Major restructure (Commit-1) → overwritten with KO content (Commit-2) | ~600 lines |
| `docs/philosophy/devbrew-harness-philosophy.ko.md` | Major restructure mirror (Commit-1) → **DELETED** (Commit-2) | ~600 / -692 |
| `docs/philosophy/devbrew-roadmap.md` | Minor (Commit-1: 3 broken links + cross-ref to §4.6) → overwritten with KO (Commit-2) | ~370 lines |
| `docs/philosophy/devbrew-roadmap.ko.md` | Mirror (Commit-1) → **DELETED** (Commit-2) | ~370 / -367 |
| `CLAUDE.md` | Minor (Commit-1: §3→§2 link) → house rule swap + KO content (Commit-2) | ~140 lines |
| `CLAUDE.ko.md` | Mirror (Commit-1) → **DELETED** (Commit-2) | ~140 / -140 |

Net file change: **3 files modified + 3 files deleted = 6 file changes** in single PR (2 commits).

**PR title:**
```
docs(philosophy): Three Laws restructure + roadmap absorption + retire bilingual model
```

**Commit-1 message:**
```
docs(philosophy): restructure §2 around Three Laws + absorb roadmap (16 modifications, no new P)

- §2/§3 → §2.1 Law 1 / §2.2 Law 2 / §2.3 Law 3 / §2.4 cross-cutting
- 14 APs nested as anti-corollaries; 3 absorbed into parent P body
- §4.4 + §4.6 primitive expansions absorb roadmap candidates (no new P#)
- Trivia escape consolidated to single P12 mention
- Bilingual parity preserved (.md + .ko.md updated lockstep this commit)
```

**Commit-2 message:**
```
docs: retire bilingual .ko.md companion; switch to Korean-primary single-file

- Overwrite *.md with *.ko.md content (Korean primary)
- git rm devbrew-harness-philosophy.ko.md, devbrew-roadmap.ko.md, CLAUDE.ko.md
- CLAUDE.md house rule: "Korean parity" → "Korean-primary, English-terms-only"
```

### 6.1 Build Sequence

```
COMMIT-1 (Three Laws restructure + roadmap absorption):
1.  §11 Migration Table written first (anchor targets for §2 references)
2.  §2 reorganized — 4 sub-sections + nested anti-corollaries (NO P24)
3.  §3 replaced with 3-line redirect
4.  §4 primitives tagged [Serves: L#]; §4.4 expanded (C20+C30); §4.6 expanded (C3+C4+C25+C69)
5.  §6 Attribution Map: expansion notes per modified P; consistent EN-source / KO-prose split
6.  Trivia escape consolidated under P12; cross-refs from Law 1 corollary + AP5 + §4.1
7.  Korean .ko.md mirror in same edit (paragraph-by-paragraph parity preserved)
8.  Roadmap broken-link cleanup (3 each in .md + .ko.md)
9.  CLAUDE.md / .ko.md line 76/77 §3 → §2
10. Adversarial pass dispatch on Commit-1 output (separate from this spec's v2 pass)
11. Fix any P0/P1 → git add → COMMIT-1

COMMIT-2 (retire bilingual model):
12. Overwrite *.md with *.ko.md content for the 3 file pairs
13. git rm *.ko.md (3 files)
14. CLAUDE.md "When Editing This Repo": "Korean parity, no drift" → "Korean-primary, English-terms-only" rule (with what stays English: identifiers / proper nouns / source quotes / technical terms)
15. Apply Korean-primary phrasing pass on changed sections of the new .md files (drop bilingual parentheticals, preserve EN identifiers)
16. Verify Appendix A quotes preserved verbatim in original language; verify §6 Attribution Map cells follow EN-source / KO-prose rule
17. Adversarial pass on Commit-2 output (orphan .ko.md refs / residual EN prose)
18. Fix any P0/P1 → git add → COMMIT-2 → branch push → squash-merge PR
```

## 7. Verification Plan

Three-tier verification per P4 of the philosophy.

### 7.1 Mechanical
- All markdown links resolve (`grep -nE '\]\([^)]*\)'` then click-through verification on changed sections).
- All `§X.Y` anchors in body have matching headers.
- AC1a / AC1b / AC #3-14 commands run and return expected output.
- All `*.ko.md` files in scope are deleted (`ls docs/philosophy/*.ko.md CLAUDE.ko.md 2>&1` returns "No such file or directory" for each).
- Sample 5 paragraphs from each new Korean-primary `.md` — Korean prose with English terms only.

### 7.2 Semantic
- Every old P#·AP# ID appears in §11 OR in §2 body (no silent removal — verified by enumerating P1–P23 + AP1–AP17 against grep).
- Every roadmap Go C# either traces to a P (existing) or §4 primitive (existing) or "already covered" or "operational" per §11.3 ledger; sum = 53 ✓.
- Each §2.4 cross-cutting principle has a 1-line justification "serves laws X, Y, Z" in body.
- Trivia escape canonical mention check: only 1 paragraph defines the rule (under P12); other 3 sites are 1-line cross-refs.

### 7.3 Adversarial (Commit-1 + Commit-2 outputs)
Dispatch a separate `general-purpose` subagent. Prompt skeleton:

```
Read these files: <philosophy.md>, <roadmap.md>, <CLAUDE.md>.
(Note: `*.ko.md` companions were deleted in this PR; their content lives merged into `.md`.)
The philosophy was restructured around Three Laws + migrated to Korean-primary single-file model. Your job: ATTACK it.

Try to find:
1. A roadmap Go candidate (C1–C69) that maps NOWHERE in §2, §4 primitive expansion, or §11 ledger.
2. A P# in §6 Attribution Map that no longer exists in §2.
3. An AP# that grep can't locate from a fresh reader's perspective.
4. A §2.4 cross-cutting entry that actually only serves 1 law.
5. An absorption (P3+AP11, P5+AP10, P14+AP17) where merging lost meaning.
6. Any roadmap cluster that should have escalated to a new P# (challenge the "no new P#" lightness decision with concrete evidence).
7. Any residual English prose in the new Korean-primary `*.md` files that should be Korean (i.e., not an identifier / proper noun / quote / technical term).
8. Any orphan `*.ko.md` reference in CLAUDE.md / `*.md` / scripts / hooks / plugin READMEs (the `.ko.md` files are deleted).
9. Any place where the trivia escape rule still appears as a full definition outside P12 (should be cross-ref only).
10. Whether the new "Korean-primary, English-terms-only" CLAUDE.md house rule is concrete enough that a future PR author knows what to do.

Report findings as: severity (P0/P1/P2), location, concrete fix.
```

P0/P1 findings → fix and re-attack until clean. P2 findings → record as follow-up issues, not blockers.

## 8. Rejected Alternatives

1. **Editorial-only pass.** Reject reason: leaves the §2 self-inconsistency ("flow from three laws" but flat list) and roadmap-philosophy drift unsolved.

2. **Distill to ~12 core principles.** Reject reason: maximum README breakage; P23 (one-minor-version deprecation window) violation. Lightness applied within the existing taxonomy, not by collapsing it.

3. **Lifecycle-phase taxonomy.** Reject reason: cross-cutting principles (P8, P21, P22) become awkward — they don't live in any single phase. Three Laws taxonomy has a natural cross-cutting bucket.

4. **5 new principles (P24–P28) — original v1 brainstorm proposal.** Reject reason: violates P8 + lightness meta-principle. All 5 candidates fold cleanly into expansions of existing P or §4 primitives.

5. **1 new principle (P24 Compounding Discoverability) — v1 spec compromise.** Reject reason (added v2): adversarial pass Finding 5.1 — even P24 violates lightness. The cluster (C3+C4+C25+C69) duplicates content already in Law 3 corollary + §4.6 primitive. Folding into §4.6 expansion + Law 3 corollary tightening is the correct move. Net: v2 has zero new principles.

6. **Move P18 (Stagnation) to §2.3 Law 3.** Reject reason (added v2): Finding 4.1 — stagnation detection is verification of progress (Law 2 angle) and lateral-restart triggering (Law 3 angle), not pure compounding. Cross-cutting (§2.4) is the right home.

7. **2-stage PR (philosophy first, derivative docs later).** Reject reason: leaves broken cross-references in working tree between PRs.

8. **Spec at `docs/superpowers/specs/`.** Reject reason: that directory was abandoned in working tree. Using `docs/specs/` aligns with philosophy §4.1 proposed default and de facto answers §9 Q4.

9. **Keep `.ko.md` companion model + maintain bilingual parity.** Reject reason (added mid-session): user policy update — bilingual parity is high-cost (every PR must update both files in lockstep, drift always sneaks in).

10. **Korean migration in separate PR after restructure.** Reject reason: would create awkward state where `*.md` and `*.ko.md` both exist with restructured content, just to be deleted in the next PR. Bundling avoids the throwaway intermediate state. Two-commit-in-one-PR (Commit-1 / Commit-2) gives the same rollback safety as two PRs without the throwaway state.

## 9. Metadata

- **Spec ID:** 2026-05-06-philosophy-restructure (v2)
- **Author:** Jeongho-K (kimjhq97@gmail.com)
- **Created:** 2026-05-06
- **Branch:** feature/harness-philosophy
- **Parent docs:** `docs/philosophy/devbrew-harness-philosophy.md`, `docs/philosophy/devbrew-roadmap.md`
- **Related deleted file:** `docs/philosophy/_retrofit-status.md` (deleted in working tree as of session start; sets context for derivative cleanup scope)
- **Brainstorm + adversarial transcript:** session 2026-05-06 (Korean conversation, 6 design sections agreed: §1 Goals → §2 Shape → §3 Absorption → §4 Migration → §5 Verification → §6 Inventory) + 1 mid-session course correction (Korean-primary policy added) + 1 adversarial subagent attack on v1 spec (1 P0 + 8 P1 + 3 P2 findings; all P0/P1 incorporated into v2)
- **Governing meta-principles introduced this session:**
  1. "lightness — devbrew designs default to absorbing new patterns into existing principles/primitives; only escalate to new P# when truly orthogonal" (saved as `feedback_devbrew_design_lightness.md`)
  2. "Korean-primary single-file docs — `*.ko.md` companion model retired; English used only for identifiers / proper nouns / source quotes / technical terms" (will save as separate user feedback memory after spec approval)

## 10. Open Questions Carried Forward

These are not blockers for this restructure but should be addressed in future work:

- §9 Q4 "Spec directory convention" — this PR de facto answers it as `docs/specs/` for design specs. Plugin specs may differ; explicit decision deferred.
- §9 Q5 "Compounding destination" — §4.6 primitive expansion (C3+C4+C25+C69 absorbed) names the *requirement* (discoverability) but defers the *destination* decision (e.g., `docs/learnings/` vs `MEMORY.md` vs per-plugin `<plugin>/learnings/`) to a later round.
- `docs/git-workflow/` broken links in CLAUDE.md — independent issue, separate PR.
- Whether §6 Attribution Map should also be reorganized under Three Laws (currently kept flat for grep ergonomics) — defer.
- Plugin READMEs (`plugins/*/README*.md`, `*.ko.md`) bilingual policy migration — explicit follow-up PR after this one merges.
- Adversarial Finding 1.2 (P2): consolidate §11 ledger so each C# appears in exactly one row; cross-check via grep. Defer to follow-up cleanup.
- Adversarial Finding 2.2 (P2): C66 needs an in-spec gloss since it's not defined in `roadmap.md` body. Add when implementing §11.1 in the actual philosophy doc.
- Adversarial Finding 3.2 (P2): AP9 → P22 vs P9 ambiguity. Add a 1-sentence justification in §11.B.1 when implementing.

## 11. Summary Tables

### 11.1 What changes (P# scorecard)

Modification types: **R** = relocated only (no content change), **E** = expanded with C# content, **A** = body absorbs AP, **N** = nests AP as anti-corollary subsection.

| ID | Modification | New location | Source / Notes |
|---|---|---|---|
| P1 | R | §2.1 / Law 1 | (C49 moved to "already covered" per Finding 2.1 — see §11.3) |
| P2 | E + N(AP1) | §2.1 / Law 1 | C43+C44+C45+C51 socratic discipline |
| P3 | A(AP11) | §2.2 / Law 2 | AP11 fully absorbed |
| P4 | E + N(AP3) | §2.2 / Law 2 | C35 two-tier test classification |
| P5 | E + A(AP10) | §2.3 / Law 3 | C66 linked artifact flow + AP10 absorbed |
| P6 | E + N(AP7, AP8) | §2.4 Cross-cutting | C57 review mode detection |
| P7 | R | §2.4 Cross-cutting | — |
| P8 | N(AP4, AP6) | §2.4 Cross-cutting | — |
| P9 | E + N(AP12) | §2.4 Cross-cutting | C61 5-dim overlap detection |
| P10 | E | §2.2 / Law 2 | C19+C24+C31+C32+C42+C63 |
| P11 | E + N(AP13, AP14) | §2.2 / Law 2 | C33+C52a+C52b+C68 |
| P12 | E + N(AP5) | §2.1 / Law 1 | C34+C60 + canonical trivia-escape mention |
| P13 | R | §2.4 Cross-cutting | — |
| P14 | A(AP17) | §2.3 / Law 3 | AP17 fully absorbed |
| P15 | R | §2.3 / Law 3 | — |
| P16 | E | §2.3 / Law 3 | C9+C54 |
| P17 | E + N(AP2) | §2.4 Cross-cutting | C56 autofix tiers |
| P18 | E + N(AP16) | §2.4 Cross-cutting | C46 lateral personas (moved from Law 3 per Finding 4.1) |
| P19 | N(AP15) | §2.4 Cross-cutting | — |
| P20 | R | §2.3 / Law 3 | — |
| P21 | R | §2.4 Cross-cutting | — |
| P22 | N(AP9) | §2.4 Cross-cutting | (AP9 → P22 chosen over P9: P22 already encodes fan-out=N gates) |
| P23 | R | §2.4 Cross-cutting | — |

**No P24.** Roadmap cluster C3+C4+C25+C69 absorbed into §4.6 + Law 3 corollary instead.

**Modified count:** 16 unique P# (P2, P3, P4, P5, P6, P8, P9, P10, P11, P12, P14, P16, P17, P18, P19, P22). 7 P# pure-relocation only (P1, P7, P13, P15, P20, P21, P23).

**Cross-cutting bucket (§2.4):** P6, P7, P8, P9, P13, P17, P18, P19, P21, P22, P23 = 11 principles.

### 11.2 AP scorecard

- **Absorbed (3):** AP10 → P5 body, AP11 → P3 body, AP17 → P14 body. IDs retired; redirects in §11.B.1.
- **Nested as anti-corollary (14):** AP1 → P2, AP2 → P17, AP3 → P4, AP4 → P8, AP5 → P12 (single canonical trivia-escape mention), AP6 → P8, AP7 → P6, AP8 → P6, AP9 → P22 (cost frame chosen over P9 architectural frame), AP12 → P9, AP13 → P11, AP14 → P11, AP15 → P19, AP16 → P18.

### 11.3 §4 primitive expansions

- **§4.4 Reviewer Agents** absorbs C20 (verdict envelope) + C30 (per-finding payload contract). 2 candidates.
- **§4.6 Compounding Skill** absorbs C3 (3-point extraction gate) + C4 (wiki/index triad) + C25 (dual-lifetime memory tags) + C69 (grep-first learnings search). 4 candidates. Law 3 corollary tightened to point at §4.6.

### 11.4 Roadmap C# disposition (verification reference for §7.2)

53 Go candidates total (with C52a/C52b as sub-items of single C52). Disposition for all 53:

| Bucket | Count | Items |
|---|---|---|
| **Folded into existing P expansions (per §11.1)** | 23 | C9, C19, C24, C31, C32, C33, C34, C35, C42, C43, C44, C45, C46, C51, C52 (a+b), C54, C56, C57, C60, C61, C63, C66, C68 |
| **Folded into §4 primitive expansions (per §11.3)** | 6 | C3, C4, C25, C69 → §4.6 ; C20, C30 → §4.4 |
| **Already covered by existing P / primitive (no doc change)** | 17 | C1→P2, C2→P3, C5→P14, C6→P4, C7→P18, C10→§4.2, C11→P13+P21, C12→P13, C14→P3+§4.3, C15→P20, C28→P9, C41→P21, C49→P14+P23 (moved per Finding 2.1), C50→P19, C55→§4.1+P1, C59→P7, C65→P14+§4.8 |
| **Operational detail / convention (no doc change)** | 7 | C22, C27, C36, C53, C58, C64, C67 |
| **Sum** | **53** | ✓ matches roadmap "53 Go" |

**Parked / Killed (out of scope — reference only):** C8, C16, C17, C18, C21, C23, C26, C29, C37, C38, C39, C40, C47, C62 (Park); C13, C48 (Kill).
