# Philosophy Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `docs/philosophy/devbrew-harness-philosophy.md` around the Three Laws + absorb 53 roadmap Go candidates into existing principles/primitives + retire bilingual `*.ko.md` companion model — all in one PR with two logical commits (rollback safety).

**Architecture:** Two-commit single PR. Commit-1 keeps bilingual parity (.md and .ko.md updated lockstep) and applies the structural restructure. Commit-2 collapses each `.md`/`.ko.md` pair into a single Korean-primary `.md` and updates CLAUDE.md house rule.

**Tech Stack:** Markdown + git + bash (grep/awk/wc) for verification. Subagent dispatch (`general-purpose`) for adversarial passes.

**Spec reference:** [`docs/specs/2026-05-06-philosophy-restructure-design.md`](../specs/2026-05-06-philosophy-restructure-design.md) v2 (post-adversarial-pass-hardened).

---

## Pre-Flight Decisions

These decisions inform every task. Confirm before starting Task 1.

- **Branch:** `feature/harness-philosophy` (current branch, already exists).
- **Spec commit timing:** This plan assumes the spec (`docs/specs/2026-05-06-...md`) is committed FIRST as a separate commit on the same branch (so the restructure commits can reference it). If user prefers spec stays uncommitted, skip Task 0.
- **Two logical commits within one PR**, squash-merged at end:
  - Commit-1: structural restructure with bilingual parity preserved
  - Commit-2: bilingual retirement
- **Verification cadence:** Each task ends with a grep/awk verification + a per-task mini-commit on the branch (these mini-commits get squashed at PR merge time, so granularity is for review hygiene, not history).
- **Adversarial pass:** Required after Commit-1 and Commit-2 outputs (Tasks 14 + 24).
- **Plan file:** This file. Writing-plans skill default `docs/superpowers/plans/` overridden — using `docs/plans/` to match the user's `docs/specs/` choice.

---

## Task 0: Commit the spec (optional)

**Files:**
- Stage: `docs/specs/2026-05-06-philosophy-restructure-design.md`

**Skip if:** user prefers spec stays uncommitted as working artifact.

- [ ] **Step 0.1: Confirm intent**

Ask user: "Commit the spec as `docs(specs): philosophy restructure design v2` before starting Commit-1 work?" If no, skip Task 0 entirely.

- [ ] **Step 0.2: Stage and commit (only if confirmed)**

```bash
git add docs/specs/2026-05-06-philosophy-restructure-design.md
git commit -m "docs(specs): philosophy restructure design v2

Spec for Three Laws restructure + roadmap absorption + bilingual retirement.
Adversarial-pass-hardened: 1 P0 + 8 P1 findings incorporated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 0.3: Verify**

Run: `git log --oneline -1`
Expected: most recent commit is `docs(specs): philosophy restructure design v2`

---

# COMMIT-1: Three Laws restructure + roadmap absorption (bilingual parity preserved)

Tasks 1–13 build the structural change with `.md` and `.ko.md` updated lockstep. Each task ends with a mini-commit on the branch — these are squashed into Commit-1 at the end of Task 13.

---

## Task 1: Read baseline content of all 3 file pairs

**Purpose:** Internalize current shape so the restructure is mechanical, not interpretive.

**Files (read only — no modification):**
- `docs/philosophy/devbrew-harness-philosophy.md`
- `docs/philosophy/devbrew-harness-philosophy.ko.md`
- `docs/philosophy/devbrew-roadmap.md`
- `docs/philosophy/devbrew-roadmap.ko.md`
- `CLAUDE.md`
- `CLAUDE.ko.md`

- [ ] **Step 1.1: Read each file in full**

Use Read tool for each (philosophy files may need offset/limit for the 690-line ones).

- [ ] **Step 1.2: Note current §-anchor structure**

Run:
```bash
awk '/^## /{print FILENAME": "$0}' docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
```
Expected: parallel `## 0`, `## 1`, ..., `## 10`, `## Appendix A` in both files.

- [ ] **Step 1.3: Confirm baseline P# / AP# counts**

Run:
```bash
grep -c '^### P[0-9]\+ ' docs/philosophy/devbrew-harness-philosophy.md
grep -c '^### AP[0-9]\+ ' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: 23 P, 17 AP.

No commit (read-only task).

---

## Task 2: Write §11 Migration Table to philosophy.md (anchor targets first)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md` — append §11 before Appendix A
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md` — same

**Why first:** Other tasks reference `§11.1`, `§11.B.1` anchors; need the targets before sections that link to them.

- [ ] **Step 2.1: Insert §11 in philosophy.md just before `## Appendix A`**

Content to insert (English first, since §11 is mostly tabular and identifiers are English; narrative explanatory text in Korean comes in Commit-2 phrasing pass):

```markdown
## 11. Migration Table — 2026-05-06 Restructure

### 11.1 Anti-Pattern Disposition (B.1)

| AP ID | Disposition | New Location |
|---|---|---|
| AP1  | Nested      | §2.1 / P2 anti-corollary |
| AP2  | Nested      | §2.4 / P17 anti-corollary |
| AP3  | Nested      | §2.2 / P4 anti-corollary |
| AP4  | Nested      | §2.4 / P8 anti-corollary |
| AP5  | Nested      | §2.1 / P12 anti-corollary (single canonical trivia-escape mention) |
| AP6  | Nested      | §2.4 / P8 anti-corollary |
| AP7  | Nested      | §2.4 / P6 anti-corollary |
| AP8  | Nested      | §2.4 / P6 anti-corollary |
| AP9  | Nested      | §2.4 / P22 anti-corollary (cost frame chosen over P9 architectural frame: P22 already encodes fan-out=N gates) |
| AP10 | Absorbed    | §2.3 / P5 body |
| AP11 | Absorbed    | §2.2 / P3 body |
| AP12 | Nested      | §2.4 / P9 anti-corollary |
| AP13 | Nested      | §2.2 / P11 anti-corollary |
| AP14 | Nested      | §2.2 / P11 anti-corollary |
| AP15 | Nested      | §2.4 / P19 anti-corollary |
| AP16 | Nested      | §2.4 / P18 anti-corollary |
| AP17 | Absorbed    | §2.3 / P14 body |

### 11.2 Principle Changes (B.2)

Modification types: **R** = relocated only, **E** = expanded with C# content, **A** = body absorbs AP, **N** = nests AP as anti-corollary.

| ID | Modification | New Location | Source / Notes |
|---|---|---|---|
| P1  | R                  | §2.1 Law 1          | (C49 → already covered: P14+P23) |
| P2  | E + N(AP1)         | §2.1 Law 1          | C43+C44+C45+C51 socratic discipline |
| P3  | A(AP11)            | §2.2 Law 2          | AP11 fully absorbed |
| P4  | E + N(AP3)         | §2.2 Law 2          | C35 two-tier test classification |
| P5  | E + A(AP10)        | §2.3 Law 3          | C66 linked artifact flow + AP10 absorbed |
| P6  | E + N(AP7, AP8)    | §2.4 Cross-cutting  | C57 review mode detection |
| P7  | R                  | §2.4 Cross-cutting  | — |
| P8  | N(AP4, AP6)        | §2.4 Cross-cutting  | — |
| P9  | E + N(AP12)        | §2.4 Cross-cutting  | C61 5-dim overlap detection |
| P10 | E                  | §2.2 Law 2          | C19+C24+C31+C32+C42+C63 |
| P11 | E + N(AP13, AP14)  | §2.2 Law 2          | C33+C52a+C52b+C68 |
| P12 | E + N(AP5)         | §2.1 Law 1          | C34+C60 + canonical trivia-escape mention |
| P13 | R                  | §2.4 Cross-cutting  | — |
| P14 | A(AP17)            | §2.3 Law 3          | AP17 fully absorbed |
| P15 | R                  | §2.3 Law 3          | — |
| P16 | E                  | §2.3 Law 3          | C9+C54 |
| P17 | E + N(AP2)         | §2.4 Cross-cutting  | C56 autofix tiers |
| P18 | E + N(AP16)        | §2.4 Cross-cutting  | C46 lateral personas (Cross-cutting, not Law 3 — stagnation is verification of progress, not compounding) |
| P19 | N(AP15)            | §2.4 Cross-cutting  | — |
| P20 | R                  | §2.3 Law 3          | — |
| P21 | R                  | §2.4 Cross-cutting  | — |
| P22 | N(AP9)             | §2.4 Cross-cutting  | — |
| P23 | R                  | §2.4 Cross-cutting  | — |

**No P24.** Roadmap cluster C3+C4+C25+C69 absorbed into §4.6 + Law 3 corollary instead (lightness meta-principle).

### 11.3 §4 Primitive Expansions

- **§4.4 Reviewer Agents** absorbs C20 (verdict envelope: `APPROVE / REQUEST CHANGES / COMMENT × CRITICAL / HIGH / MEDIUM / LOW`) + C30 (per-finding payload contract: `severity / confidence 1-10 / path / line / category / summary / fix / fingerprint / specialist`; sentinel `NO FINDINGS`; confidence rubric 9-10 show, 7-8 show, 5-6 caveat, 3-4 suppress, 1-2 P0-only).
- **§4.6 Compounding Skill** absorbs C3 (3-point extraction gate: non-Googleable / project-specific / hard-won — all three required) + C4 (wiki/index triad pattern from OMC) + C25 (dual-lifetime memory tags: short-lived task notes vs durable rules) + C69 (grep-first learnings search; no embeddings, no vector store). Law 3 corollary tightened to point at §4.6 for the discoverability mechanism.

### 11.4 Roadmap C# Disposition (53 Go candidates)

| Bucket | Count | Items |
|---|---|---|
| Folded into existing P expansions (per §11.2) | 23 | C9, C19, C24, C31, C32, C33, C34, C35, C42, C43, C44, C45, C46, C51, C52 (a+b), C54, C56, C57, C60, C61, C63, C66, C68 |
| Folded into §4 primitive expansions (per §11.3) | 6 | C3, C4, C25, C69 → §4.6 ; C20, C30 → §4.4 |
| Already covered by existing P / primitive (no doc change) | 17 | C1→P2, C2→P3, C5→P14, C6→P4, C7→P18, C10→§4.2, C11→P13+P21, C12→P13, C14→P3+§4.3, C15→P20, C28→P9, C41→P21, C49→P14+P23, C50→P19, C55→§4.1+P1, C59→P7, C65→P14+§4.8 |
| Operational detail / convention (no doc change) | 7 | C22, C27, C36, C53, C58, C64, C67 |
| **Sum** | **53** | ✓ matches roadmap "53 Go" |

**Parked / Killed (out of scope — reference only):** C8, C16, C17, C18, C21, C23, C26, C29, C37, C38, C39, C40, C47, C62 (Park); C13, C48 (Kill).
```

- [ ] **Step 2.2: Mirror §11 into philosophy.ko.md**

Insert the same §11 content into `philosophy.ko.md` just before `## Appendix A`. Tables stay identical (identifiers/source-names are English). Add a one-line Korean intro before §11.1: `이 표는 2026-05-06 재구조화로 이동/통합된 P# / AP# / C#의 마이그레이션 매핑을 기록합니다.`

- [ ] **Step 2.3: Verify**

```bash
grep -c '^## 11\.' docs/philosophy/devbrew-harness-philosophy.md
grep -c '^## 11\.' docs/philosophy/devbrew-harness-philosophy.ko.md
grep -c '^### 11\.\(1\|2\|3\|4\)' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `1`, `1`, `4`.

- [ ] **Step 2.4: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): add §11 Migration Table (anchor targets for restructure)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Reorganize §2 into 4 sub-sections (move P# headers under §2.1/2.2/2.3/2.4)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md` — restructure §2
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md` — mirror

- [ ] **Step 3.1: Insert §2 sub-section headers in philosophy.md**

Replace the current `## 2. Principles (flow from the three laws)` opening with:

```markdown
## 2. Principles (organized under the Three Laws)

These are the operational commitments. Each is named, attributed, and has a concrete translation into devbrew plugin decisions. Each principle lives under the Law it primarily serves; principles that serve all three are gathered in §2.4 Cross-Cutting Commitments.

### 2.1 Under Law 1 — Clarity Before Code

Principles that serve specification clarity before implementation begins. AP1, AP5 nested as anti-corollaries.

[insert P1, P2, P12 sections here]

### 2.2 Under Law 2 — Writer/Reviewer Independence

Principles that serve verification independence and structural reviewer separation. AP3, AP11 (absorbed into P3), AP13, AP14 nested as anti-corollaries.

[insert P3, P4, P10, P11 sections here]

### 2.3 Under Law 3 — Compounding Memory

Principles that serve memory durability and learning capture across cycles. AP10 (absorbed into P5), AP17 (absorbed into P14) nested as anti-corollaries.

[insert P5, P14, P15, P16, P20 sections here]

### 2.4 Cross-Cutting Commitments (serve all three Laws)

Principles whose service applies to clarity, independence, AND compounding. AP2, AP4, AP6, AP7, AP8, AP9, AP12, AP15, AP16 nested as anti-corollaries.

[insert P6, P7, P8, P9, P13, P17, P18, P19, P21, P22, P23 sections here]
```

- [ ] **Step 3.2: Move each P# section under its assigned sub-section**

Per §11.2 mapping:
- §2.1: P1, P2, P12
- §2.2: P3, P4, P10, P11
- §2.3: P5, P14, P15, P16, P20
- §2.4: P6, P7, P8, P9, P13, P17, P18, P19, P21, P22, P23

Use Edit tool with surgical moves. P# header level stays `### P\d+` (so `## 2.1` is sub-section, `### P1` is principle within).

- [ ] **Step 3.3: Mirror to philosophy.ko.md**

Apply identical structural moves. Sub-section explanatory paragraphs become Korean (the headers `## 2.1 Under Law 1 — Clarity Before Code` stay English per identifier rule).

Korean intros:
- §2.1: `Law 1을 직접 봉사하는 원칙들. AP1, AP5는 anti-corollary로 nested.`
- §2.2: `Law 2를 직접 봉사하는 원칙들. AP3, AP11(P3에 흡수), AP13, AP14가 anti-corollary로 nested.`
- §2.3: `Law 3을 직접 봉사하는 원칙들. AP10(P5에 흡수), AP17(P14에 흡수)이 anti-corollary로 nested.`
- §2.4: `세 법칙 모두에 봉사하는 원칙들. AP2, AP4, AP6, AP7, AP8, AP9, AP12, AP15, AP16이 anti-corollary로 nested.`

- [ ] **Step 3.4: Verify physical placement**

```bash
awk '
  /^## 2\./ {section=$0; next}
  /^### P[0-9]+ / {print section " :: " $0}
' docs/philosophy/devbrew-harness-philosophy.md
```
Expected output (each line shows which sub-section a P# now lives under):
```
## 2.1 Under Law 1 — Clarity Before Code :: ### P1 ...
## 2.1 Under Law 1 — Clarity Before Code :: ### P2 ...
## 2.1 Under Law 1 — Clarity Before Code :: ### P12 ...
## 2.2 Under Law 2 — Writer/Reviewer Independence :: ### P3 ...
... [continues for all 23 P#]
```

Cross-check against §11.2 — every row's "New Location" column should match the awk output's section.

- [ ] **Step 3.5: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): reorganize §2 into Three Laws sub-sections

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Nest 14 APs as anti-corollaries under parent Ps

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

- [ ] **Step 4.1: For each of the 14 nested APs, move its body from §3 to under its parent P**

Mapping (per §11.1):
- AP1 → after P2 body
- AP2 → after P17 body
- AP3 → after P4 body
- AP4 → after P8 body
- AP5 → after P12 body (this becomes the canonical trivia-escape mention)
- AP6 → after P8 body
- AP7 → after P6 body
- AP8 → after P6 body
- AP9 → after P22 body
- AP12 → after P9 body
- AP13 → after P11 body
- AP14 → after P11 body
- AP15 → after P19 body
- AP16 → after P18 body

Each nested AP keeps its existing `### AP\d+` header so it appears as a sub-section under the parent P. Add a one-line breadcrumb at the top of each nested AP body: `*Anti-corollary of P{N}. Original location: former §3.*` (Korean equivalent in `.ko.md`).

- [ ] **Step 4.2: Mirror to philosophy.ko.md**

Same moves. Breadcrumbs in Korean: `*P{N}의 anti-corollary. 원래 위치: 구 §3.*`

- [ ] **Step 4.3: Verify**

```bash
grep -c '^### AP[0-9]\+ ' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `14` (the nested ones; AP10/AP11/AP17 absorbed in Task 5, not yet here).

```bash
awk '
  /^### P[0-9]+ / {parent=$0; next}
  /^### AP[0-9]+ / {print parent " :: " $0}
' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: 14 lines mapping each AP to its immediately preceding P. Cross-check against §11.1.

- [ ] **Step 4.4: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): nest 14 APs as anti-corollaries under parent Ps

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Absorb 3 APs (AP10, AP11, AP17) into parent P body

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

- [ ] **Step 5.1: Absorb AP11 (Role Leakage) into P3 body**

P3 currently states the principle "Tool Scoping". AP11 was the redundant restatement "A reviewer with Write access is not a reviewer." Append to P3 body (after the existing description, before any anti-corollary subsections):

```markdown
**Anti-pattern absorbed (formerly AP11):** A reviewer with `Write` access is not a reviewer; a planner with mutating `Bash` is not a planner. The default (full tool access) is forbidden for any role-scoped agent. Every agent definition must have explicit `allowedTools` and `disallowedTools` lists.
```

Remove the standalone `### AP11` section from §3.

- [ ] **Step 5.2: Absorb AP10 (Stale Pre-Built Indexes) into P5 body**

P5 is "Filesystem as Memory". Append to P5 body:

```markdown
**Anti-pattern absorbed (formerly AP10):** No pre-baked search trees, vector stores, or cached embeddings of the codebase. Anthropic explicitly says Claude Code avoids this *"effectively bypassing the issues of stale indexing and complex syntax trees."* Glob + grep + read, just-in-time, every time.
```

Remove standalone `### AP10`.

- [ ] **Step 5.3: Absorb AP17 (Chat-Only State) into P14 body**

P14 is "State Survives Compaction". Append:

```markdown
**Anti-pattern absorbed (formerly AP17):** A fact that only lives in the conversation is a fact that's dead after compaction. If a fact is load-bearing for the next turn, it must live in a file before the turn ends.
```

Remove standalone `### AP17`.

- [ ] **Step 5.4: Mirror to philosophy.ko.md**

Korean translations of the absorbed-anti-pattern paragraphs. The English original quotes (e.g., Anthropic *"effectively bypassing..."*) stay verbatim.

- [ ] **Step 5.5: Verify**

```bash
for n in 10 11 17; do
  grep -c "^### AP${n} " docs/philosophy/devbrew-harness-philosophy.md
done
```
Expected: three `0`s (no standalone headers for absorbed APs).

```bash
grep -c "Anti-pattern absorbed (formerly AP" docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `3` (three absorption notes).

- [ ] **Step 5.6: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): absorb AP10/AP11/AP17 into parent P body

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Replace §3 with 3-line redirect

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

- [ ] **Step 6.1: Replace entire §3 body with redirect**

The §3 section currently spans the full anti-pattern catalog (~80 lines). Replace with:

```markdown
## 3. Anti-Corollaries  (formerly "Named Anti-Patterns")

Each anti-pattern (AP1–AP17) now lives as an *anti-corollary* nested under
the principle it negates (§2). For ID-level migration mapping, see §11.1.
Three patterns (AP10, AP11, AP17) are fully absorbed into their parent
principle's body and exist only as redirects in §11.1.
```

- [ ] **Step 6.2: Mirror to .ko.md**

Korean version:

```markdown
## 3. Anti-Corollaries  (구 "Named Anti-Patterns")

각 anti-pattern (AP1–AP17)은 이제 자신이 negate하는 원칙(§2) 아래에
*anti-corollary*로 nested됩니다. ID 단위 마이그레이션 매핑은 §11.1 참조.
3개 패턴 (AP10, AP11, AP17)은 부모 원칙 body에 완전 흡수되어 §11.1에
redirect로만 존재합니다.
```

- [ ] **Step 6.3: Verify**

```bash
awk '/^## 3\./{flag=1; next} /^## 4\./{flag=0} flag' docs/philosophy/devbrew-harness-philosophy.md | wc -l
```
Expected: `≤ 8` lines (3-line redirect + blank lines + section gap).

- [ ] **Step 6.4: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): collapse §3 to 3-line redirect (APs nested under §2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Tag §4 primitives + expand §4.4 + expand §4.6 + tighten Law 3 corollary

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

- [ ] **Step 7.1: Add `[Serves: L#]` tag to each §4.x header**

Tag mapping (each primitive serves the Laws indicated):
- §4.0 Canonical Plugin Directory Structure: `[Serves: L1, L2, L3]`
- §4.1 Spec Authoring: `[Serves: L1]`
- §4.2 Plan Authoring: `[Serves: L1]`
- §4.3 Writer/Executor Agents: `[Serves: L2]`
- §4.4 Reviewer Agents / Persona Library: `[Serves: L2]`
- §4.5 Verifier: `[Serves: L2]`
- §4.6 Compounding Skill: `[Serves: L3]`
- §4.7 Hook Layer: `[Serves: L1, L2, L3]`
- §4.8 State File: `[Serves: L3]`
- §4.9 Compose-Plugin Dispatch: `[Serves: L1, L2, L3]` (cross-cutting infra)
- §4.10 Benchmark Suite: `[Serves: L2]`

Header format: `### 4.4 Reviewer Agents / Persona Library  [Serves: L2]`

- [ ] **Step 7.2: Expand §4.4 with C20 + C30 (verdict + per-finding contract)**

Append to §4.4 body, after existing bullets:

```markdown
- **Verdict envelope (C20).** Every reviewer emits a top-level verdict in the form `APPROVE | REQUEST CHANGES | COMMENT` × `CRITICAL | HIGH | MEDIUM | LOW`. The dispatcher merges multi-reviewer envelopes into a single PR-level verdict using the most-severe rule.
- **Per-finding payload contract (C30).** Each individual finding inside a verdict has the JSON-shape: `{severity, confidence (1-10), path, line, category, summary, fix, fingerprint, specialist}`. Sentinel: `NO FINDINGS` when a reviewer has nothing to add. Confidence rubric for display: 9-10 show, 7-8 show, 5-6 caveat, 3-4 suppress to appendix, 1-2 P0-only.
```

- [ ] **Step 7.3: Expand §4.6 with C3 + C4 + C25 + C69 (was going to be P24)**

Append to §4.6 body, after existing bullets:

```markdown
- **3-point extraction gate (C3).** Before a learning is written to disk, the compounding skill applies a 3-point gate — all three required: (a) **Non-Googleable** — could a fresh reader find this in 5 minutes via Google? If yes, don't capture. (b) **Project-specific** — is this specific to THIS codebase / THIS team / THIS plugin? If no, don't capture. (c) **Hard-won** — did this take real debugging or design work to discover? If no, don't capture.
- **Wiki/index triad (C4).** OMC's pattern: every captured learning produces three artifacts — the learning itself, an index entry (in `AGENTS.md` / `CLAUDE.md` / a wiki), and a reverse pointer from the file the learning teaches about. The triad is what makes future-find work reliably.
- **Dual-lifetime memory tags (C25).** Each captured learning is tagged for one of two lifetimes: `task` (short-lived, deleted after the current branch merges) or `durable` (long-lived, survives indefinitely). The compounding skill prompts the writer to pick a lifetime explicitly, never defaults.
- **Grep-first learnings search (C69).** Future sessions discover prior learnings via `grep` on the canonical learnings directory + the indexes from C4. No embeddings, no vector store, no RAG. Acceptance: a future session searching for a relevant prior learning finds it via grep with recall ≥ 85% on a sampled benchmark.
```

- [ ] **Step 7.4: Tighten Law 3 corollary to point at §4.6**

Find Law 3 corollary in §1 (the "Discoverability Check" paragraph). Append at the end:

```markdown
The operational mechanics of this corollary — extraction gate, index triad, lifetime tags, grep-recall criterion — live in §4.6 Compounding Skill primitive. This corollary states the *rule*; §4.6 specifies the *how*.
```

- [ ] **Step 7.5: Mirror to .ko.md**

Korean equivalents. The C20/C30/C3/C4/C25/C69 candidate names + rubric labels (`APPROVE`, `CRITICAL`, `task`, `durable`) stay English (technical-term rule).

- [ ] **Step 7.6: Verify**

```bash
grep -c '\[Serves: L' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `11` (one tag per §4.0–§4.10).

```bash
grep -c 'C[0-9]\+\b' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: ≥ 6 (C3, C4, C20, C25, C30, C69 mentioned in §4.4 / §4.6 expansions, plus possibly more from other expansion tasks).

- [ ] **Step 7.7: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): tag §4 primitives + expand §4.4/§4.6 + tighten Law 3 corollary

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Expand 12 existing principles with roadmap C# attributions

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

For each P below, append a `**Roadmap absorption:**` paragraph at the end of the principle body (before its anti-corollary subsection if one exists).

- [ ] **Step 8.1: Expand P2 with C43+C44+C45+C51 (Socratic discipline)**

Append to P2:

```markdown
**Roadmap absorption (C43+C44+C45+C51 — Socratic Interview Discipline):** the interview that produces the spec follows a Socratic 4-path routing (C43): (a) factual questions auto-confirm against the codebase with `[from-code][auto-confirmed]`, (b) human-judgment questions are routed to the user (default path), (c) ambiguity questions dispatch a sub-agent for adversarial draft, (d) ontological questions use the 5-type framework (C51: ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT). A dialectic rhythm guard (C44) enforces that 3 consecutive non-user answers must route the next question to the user. A breadth-keeper agent (C45) — `disallowedTools: Write, Edit` — runs alongside to prevent narrow tunneling.
```

- [ ] **Step 8.2: Expand P4 with C35 (two-tier test classification)**

```markdown
**Roadmap absorption (C35 — Two-Tier Test Classification):** verification tests are split into (a) **gate tier** — runs on every commit / PR; cheap (< 5s); failure blocks; and (b) **periodic tier** — runs on schedule or trigger; expensive (E2E ~$3.85/run, LLM-judge ~$4/run); failure surfaces but doesn't block per-commit. Diff-based selection routes which tier runs.
```

- [ ] **Step 8.3: Expand P5 with C66 (linked artifact flow)**

```markdown
**Roadmap absorption (C66 — Linked Artifact Flow):** files-as-memory primitive extends to *cross-artifact linkage*. Spec links to plan; plan links to code paths; code links back to spec via commit trailer (P20). The chain is grep-traversable: any artifact can recover its full provenance graph via grep on stable IDs.
```

- [ ] **Step 8.4: Expand P6 with C57 (review mode detection)**

```markdown
**Roadmap absorption (C57 — Review Mode Detection):** a skill that adapts to its invocation context. 4 modes: `headless` (CI; no prompts; emit machine-readable verdict), `autofix` (apply safe fixes inline), `report-only` (surface findings, take no action), `interactive` (prompt user at decision points). The mode is detected from environment / invocation flags, not assumed; default = `interactive` for explicit user invocation.
```

- [ ] **Step 8.5: Expand P9 with C61 (5-dim overlap detection)**

```markdown
**Roadmap absorption (C61 — 5-Dimension Overlap Detection):** when two plugins propose overlapping capability, the composition discipline applies a 5-dimension check before deciding to merge / coexist / refactor: (a) input contract, (b) output contract, (c) side-effect surface, (d) cost class, (e) failure modes. Two plugins with identical 5-tuples should refactor into a third both depend on.
```

- [ ] **Step 8.6: Expand P10 with C19+C24+C31+C32+C42+C63**

```markdown
**Roadmap absorption (C19+C24+C31+C32+C42+C63):** the persona library expands operationally — (C19) two-stage protocol (spec compliance check → code quality check, sequential not parallel); (C24) baseline specialists `api-reviewer` + `performance-reviewer` always-on; (C32) extended catalog `data-migration` / `maintainability` / `red-team` each emitting per-finding JSON per §4.4 contract; (C31) scope-gated dispatch — Testing + Maintainability always-on for ≥50 LOC, others conditional via `SCOPE_*` env vars, with `[NEVER_GATE]` floor on Security + Testing; (C42) tiered gating — eng-review is the single hard gate, all specialist reviews are advisory; (C63) per-reviewer "What NOT to flag" lists to suppress reviewer-specific false positives.
```

- [ ] **Step 8.7: Expand P11 with C33+C52a+C52b+C68**

```markdown
**Roadmap absorption (C33+C52+C68):** multi-model adversarial expands operationally — (C33) always-on adversarial review (never conditional on LOC or risk signals; never gates shipping — advisory only); (C52a) structural consensus triggers (4 of 7: SEED_MODIFICATION / ONTOLOGY_EVOLUTION / GOAL_INTERPRETATION / MANUAL_REQUEST require multi-model concurrence); (C52b) drift-aware consensus triggers (when measured drift exceeds threshold, escalate to multi-model); (C68) adversarial 4-technique framework — assumption violation, composition failures, cascade construction, abuse cases. Depth-calibrated: Quick / Standard / Deep based on stakes.
```

- [ ] **Step 8.8: Expand P12 with C34+C60 + canonical trivia-escape mention**

```markdown
**Roadmap absorption (C34+C60):** transparency expands with — (C34) plan/audit boomerang (the plan that authorized the work returns alongside the work for verification; the audit checks plan-vs-code alignment); (C60) scope-adaptive depth (lightweight for trivia escape, standard for normal work, deep for high-stakes — depth is declared up-front, not discovered mid-flight).

**Trivia escape (canonical mention; consolidates Law 1 corollary, AP5, §4.1 escape hatch):** if you could describe the diff in one sentence (Anthropic, *Claude Code Best Practices*), skip the plan and skip the spec gate. Examples that qualify: typos, renames, comment-only edits, single-file formatting. Examples that do NOT qualify: multi-file changes, behavior changes, anything touching public API. Detection of triviality is the *invoking* skill's responsibility, not the spec/plan skill's (which is never given a chance to refuse-for-trivia). Cross-refs: see Law 1 corollary, AP5 nested below, §4.1 escape hatch.
```

- [ ] **Step 8.9: Expand P16 with C9+C54**

```markdown
**Roadmap absorption (C9+C54):** measurement expands with — (C9) dimensional progress tracking (per-cycle metrics: ambiguity reduction Δ, convergence Δ, defect-escape rate, stagnation events); (C54) drift measurement formula (a quantitative drift = `0.4·structural_drift + 0.4·semantic_drift + 0.2·behavioral_drift`; threshold for action declared in skill frontmatter).
```

- [ ] **Step 8.10: Expand P17 with C56 (autofix tiers)**

```markdown
**Roadmap absorption (C56 — Autofix Disposition Tiers):** when a reviewer finds a fixable issue, the disposition routes through 4 tiers: (a) `safe_auto` — review-fixer applies inline, no user prompt; (b) `gated_auto` — downstream-resolver applies via `AskUserQuestion` (per P22 cost gate); (c) `manual` — surfaces for human decision; (d) `advisory` — released to PR description, no fix attempted. Tier choice is the reviewer's call; the dispatcher honors it.
```

- [ ] **Step 8.11: Expand P18 with C46 (lateral personas)**

```markdown
**Roadmap absorption (C46 — Lateral Thinking Persona Recovery):** when stagnation is detected, the recovery dispatch uses a persona affinity table (deterministic first-match): HACKER → SPINNING, RESEARCHER → {NO_DRIFT, DIMINISHING_RETURNS}, SIMPLIFIER → {DIMINISHING_RETURNS, OSCILLATION}, ARCHITECT → {OSCILLATION, NO_DRIFT}, CONTRARIAN → all. Each persona arrives with a fresh prompt and lateral-thinking heuristics specific to the stagnation pattern.
```

- [ ] **Step 8.12: Mirror all 11 expansions to .ko.md**

Same structure, Korean prose. C# IDs and technical-term identifiers stay English.

- [ ] **Step 8.13: Verify**

```bash
grep -c "Roadmap absorption" docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `11` (one per expanded P).

- [ ] **Step 8.14: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): expand 11 principles with roadmap C# absorptions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Reduce Law 1 corollary + §4.1 escape hatch trivia mentions to cross-refs

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

P12 (per Task 8.8) now has the canonical trivia-escape mention. Reduce the other 3 sites.

- [ ] **Step 9.1: Reduce Law 1 trivia corollary to cross-ref**

Find Law 1's "Trivia escape" paragraph in §1 (currently ~3 sentences). Replace with:

```markdown
**Trivia escape:** see canonical statement at §2.1 / P12 (consolidated mention).
```

- [ ] **Step 9.2: Reduce §4.1 escape hatch to cross-ref**

Find §4.1's "Escape hatch" bullet (currently 1-2 sentences). Replace with:

```markdown
- **Escape hatch:** trivia diffs bypass spec authoring entirely (see §2.1 / P12 canonical mention).
```

- [ ] **Step 9.3: Verify single canonical mention**

The phrase "describe the diff in one sentence" should appear only twice in the doc:
1. Once verbatim in P12 canonical mention (Task 8.8).
2. Once as part of the cross-ref (no — cross-ref doesn't quote it).

```bash
grep -c "describe the diff in one sentence" docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `1` (only in P12 canonical mention).

```bash
grep -c "Trivia escape\|trivia diffs\|trivia escape" docs/philosophy/devbrew-harness-philosophy.md
```
Expected: ≥ 4 (P12 canonical mention + Law 1 cross-ref + §4.1 cross-ref + AP5 nested entry — but only P12 has the full quote).

- [ ] **Step 9.4: Mirror to .ko.md**

Korean cross-refs:
- Law 1: `**Trivia escape:** §2.1 / P12의 canonical statement 참조 (consolidated mention).`
- §4.1: `- **Escape hatch:** trivia diff는 spec authoring을 우회 (§2.1 / P12 canonical mention 참조).`

- [ ] **Step 9.5: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): consolidate trivia escape to single P12 canonical mention

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Update §6 Attribution Map (expansion notes per modified P)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `docs/philosophy/devbrew-harness-philosophy.ko.md`

- [ ] **Step 10.1: For each row in §6 Attribution Map corresponding to an expanded P, append the new C# sources**

Example: P2 row currently shows `Ouroboros | OMC deep-interview dimensional scoring` for "Supporting source(s)". Append: `+ C43+C44+C45+C51 (roadmap, 2026-05-06 absorption)`.

Apply to all 11 expanded P rows (P2, P4, P5, P6, P9, P10, P11, P12, P16, P17, P18).

- [ ] **Step 10.2: Apply EN-source / KO-prose cell rule**

For modifier-prose cells (e.g., "implicit in all harnesses", "indirect"), translate to Korean. Source-name cells (Anthropic, OMC, gstack, Ouroboros, CE, Klaassen) stay English.

- [ ] **Step 10.3: No P24 row added** (sanity check — P24 was rejected)

```bash
grep -c '^| P24' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `0`.

- [ ] **Step 10.4: Mirror to .ko.md**

- [ ] **Step 10.5: Verify expansion notes count**

```bash
grep -c "(roadmap, 2026-05-06 absorption)" docs/philosophy/devbrew-harness-philosophy.md
```
Expected: `11` (one per expanded P row).

- [ ] **Step 10.6: Mini-commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
git commit -m "docs(philosophy): update §6 Attribution Map with roadmap absorption notes

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Roadmap broken-link cleanup (3 references each in roadmap.md/.ko.md)

**Files:**
- Modify: `docs/philosophy/devbrew-roadmap.md`
- Modify: `docs/philosophy/devbrew-roadmap.ko.md`

- [ ] **Step 11.1: Locate the 3 `_retrofit-status.md` references in roadmap.md**

```bash
grep -n "_retrofit-status" docs/philosophy/devbrew-roadmap.md
```

Expected lines (per spec analysis): 107, 115, 366.

- [ ] **Step 11.2: Edit each reference**

- Line ~107: "**Retrofit items** (from [`_retrofit-status.md`](_retrofit-status.md)): ..." → drop the parenthetical link, keep the body. Result: "**Retrofit items:** CHANGELOG.md for both plugins, ..."
- Line ~115: "- `_retrofit-status.md` docs-debt gaps resolved." → drop the bullet entirely (the gap reference is moot since the file is gone).
- Line ~366: "**Retrofit baseline:** [`docs/philosophy/_retrofit-status.md`](_retrofit-status.md)" → drop the bullet.

- [ ] **Step 11.3: Add cross-ref to §4.6 expansion (optional but recommended)**

Where the roadmap describes Phase 4a (compounding work using C3, C4, C25, C69), add a one-line note:

```markdown
> **Note (2026-05-06):** Phase 4a candidates C3+C4+C25+C69 are now first-class operational content of philosophy §4.6 Compounding Skill primitive (see philosophy.md §4.6 + Law 3 corollary).
```

- [ ] **Step 11.4: Mirror identical edits to roadmap.ko.md**

Korean version of the cross-ref note: `> **참고 (2026-05-06):** Phase 4a 후보 C3+C4+C25+C69는 이제 철학 §4.6 Compounding Skill primitive의 first-class 운영 내용 (philosophy.md §4.6 + Law 3 corollary 참조).`

- [ ] **Step 11.5: Verify zero broken refs**

```bash
grep -c "_retrofit-status" docs/philosophy/devbrew-roadmap.md docs/philosophy/devbrew-roadmap.ko.md
```
Expected: `0` for both files.

- [ ] **Step 11.6: Mini-commit**

```bash
git add docs/philosophy/devbrew-roadmap.md docs/philosophy/devbrew-roadmap.ko.md
git commit -m "docs(roadmap): remove broken _retrofit-status.md links + add §4.6 cross-ref

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: CLAUDE.md §3 reference fix (line 76)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `CLAUDE.ko.md`

- [ ] **Step 12.1: Update CLAUDE.md line 76**

Current: `Full catalog with case studies: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §3. Cite by name in reviews.`

Replace with: `Full catalog with case studies: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §2 (each principle's anti-corollary) + §11.1 (ID migration). Cite by name in reviews.`

- [ ] **Step 12.2: Mirror to CLAUDE.ko.md line 77**

Korean version with the same updated link target.

- [ ] **Step 12.3: Verify**

```bash
grep "§3" CLAUDE.md CLAUDE.ko.md
```
Expected: NO output for the philosophy doc reference (other §3 mentions in unrelated context are OK; the philosophy `§3` reference should be gone).

- [ ] **Step 12.4: Mini-commit**

```bash
git add CLAUDE.md CLAUDE.ko.md
git commit -m "docs(CLAUDE): update §3 catalog reference to §2 + §11.1 (post-restructure)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Adversarial pass on Commit-1 output

**Files (read only):**
- `docs/philosophy/devbrew-harness-philosophy.md`
- `docs/philosophy/devbrew-harness-philosophy.ko.md`
- `docs/philosophy/devbrew-roadmap.md`
- `docs/philosophy/devbrew-roadmap.ko.md`
- `CLAUDE.md`
- `CLAUDE.ko.md`

- [ ] **Step 13.1: Dispatch general-purpose subagent**

Use the Agent tool with `subagent_type: general-purpose`. Prompt verbatim from spec §7.3 (10 attack vectors). Pass the post-Task-12 file paths.

- [ ] **Step 13.2: Process P0/P1 findings**

For each P0 finding: fix inline (return to relevant Task N if structural; otherwise edit directly). For each P1: same. P2 findings → log as follow-up issues at the bottom of this plan file.

- [ ] **Step 13.3: Re-dispatch subagent on the patched output**

Repeat until 0 P0/P1.

- [ ] **Step 13.4: Verify clean**

Subagent verdict: "approve for commit" (or equivalent).

- [ ] **Step 13.5: Squash mini-commits 2-12 into one Commit-1**

```bash
git rebase -i origin/main
# In the editor, mark commits 2-12 as 'squash' into commit 2 (or use 'fixup' to keep first commit's message).
# Final Commit-1 message:
```

```
docs(philosophy): restructure §2 around Three Laws + absorb roadmap (16 modifications, no new P)

- §2/§3 → §2.1 Law 1 / §2.2 Law 2 / §2.3 Law 3 / §2.4 cross-cutting
- 14 APs nested as anti-corollaries; 3 absorbed into parent P body
- §4.4 + §4.6 primitive expansions absorb roadmap candidates (no new P#)
- Trivia escape consolidated to single P12 mention
- Bilingual parity preserved (.md + .ko.md updated lockstep this commit)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

- [ ] **Step 13.6: Push branch**

```bash
git push origin feature/harness-philosophy
```

---

# COMMIT-2: Retire bilingual `.ko.md` companion model

Tasks 14–24 collapse the bilingual model. After Commit-2, `.md` files contain Korean primary content; `.ko.md` files are deleted.

---

## Task 14: Overwrite philosophy.md with .ko.md content

**Files:**
- Overwrite: `docs/philosophy/devbrew-harness-philosophy.md`
- Source: `docs/philosophy/devbrew-harness-philosophy.ko.md` (post-Commit-1 state)

- [ ] **Step 14.1: Copy .ko.md → .md**

```bash
cp docs/philosophy/devbrew-harness-philosophy.ko.md docs/philosophy/devbrew-harness-philosophy.md
```

- [ ] **Step 14.2: Verify byte-equality before phrasing pass**

```bash
diff docs/philosophy/devbrew-harness-philosophy.md docs/philosophy/devbrew-harness-philosophy.ko.md
```
Expected: no output (identical).

No mini-commit yet (Task 15 deletes the .ko.md, then Task 16 does the phrasing pass; commit after both).

---

## Task 15: `git rm` philosophy.ko.md

- [ ] **Step 15.1: Stage deletion**

```bash
git rm docs/philosophy/devbrew-harness-philosophy.ko.md
```

- [ ] **Step 15.2: Verify**

```bash
ls docs/philosophy/devbrew-harness-philosophy.ko.md 2>&1
```
Expected: `ls: ...: No such file or directory`.

```bash
git status --short docs/philosophy/devbrew-harness-philosophy.ko.md
```
Expected: `D  docs/philosophy/devbrew-harness-philosophy.ko.md` (staged deletion).

---

## Task 16: Korean-primary phrasing pass on philosophy.md

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`

- [ ] **Step 16.1: Drop bilingual parentheticals from headers**

Find all headers of form `## Law N — Title (한국어 번역)` and reduce to `## Law N — Title` (English title only; Korean was the parenthetical).

```bash
grep -E '^## .*\(.*[가-힣].*\)' docs/philosophy/devbrew-harness-philosophy.md
```

For each match, edit to drop the Korean parenthetical from the header.

- [ ] **Step 16.2: Verify Appendix A quotes preserved verbatim**

Per §4 Constraints — Appendix A quotes stay in original language with no glosses.

```bash
awk '/^## Appendix A/{flag=1; next} /^## /{flag=0} flag' docs/philosophy/devbrew-harness-philosophy.md > /tmp/appendix_a.txt
cat /tmp/appendix_a.txt
```

Verify by inspection: each quote is in its original language; no `(English: ...)` or `(한국어: ...)` glosses added.

- [ ] **Step 16.3: Verify §6 Attribution Map cell rule**

Source-name cells stay English (Anthropic, OMC, gstack, Ouroboros, CE, Klaassen). Modifier-prose cells become Korean (e.g., "implicit in all harnesses" → "모든 하니스에 암묵적").

```bash
awk '/^## 6\./{flag=1; next} /^## 7\./{flag=0} flag' docs/philosophy/devbrew-harness-philosophy.md
```

Inspect each row. If any modifier-prose cell is still English, edit to Korean.

- [ ] **Step 16.4: Sample 5 paragraphs to confirm Korean-primary**

Pick 5 random non-table, non-quote paragraphs. Each should be Korean prose with English limited to identifiers / proper nouns / technical terms.

No commit yet (Tasks 17–22 modify the other 2 file pairs; one Commit-2 covers all).

---

## Task 17: Repeat Tasks 14–16 for roadmap.md / .ko.md

- [ ] **Step 17.1: Copy roadmap.ko.md → roadmap.md**

```bash
cp docs/philosophy/devbrew-roadmap.ko.md docs/philosophy/devbrew-roadmap.md
```

- [ ] **Step 17.2: `git rm` roadmap.ko.md**

```bash
git rm docs/philosophy/devbrew-roadmap.ko.md
```

- [ ] **Step 17.3: Phrasing pass on roadmap.md**

Drop bilingual parentheticals from headers; verify cell rule on tables; sample 3 paragraphs.

- [ ] **Step 17.4: Verify**

```bash
ls docs/philosophy/devbrew-roadmap.ko.md 2>&1
```
Expected: `No such file or directory`.

---

## Task 18: Repeat Tasks 14–16 for CLAUDE.md / .ko.md

- [ ] **Step 18.1: Copy CLAUDE.ko.md → CLAUDE.md**

```bash
cp CLAUDE.ko.md CLAUDE.md
```

- [ ] **Step 18.2: `git rm` CLAUDE.ko.md**

```bash
git rm CLAUDE.ko.md
```

- [ ] **Step 18.3: Phrasing pass on CLAUDE.md**

Drop bilingual parentheticals; verify Forbidden Patterns names stay English (identifier rule); sample 3 paragraphs.

- [ ] **Step 18.4: Verify**

```bash
ls CLAUDE.ko.md 2>&1
```
Expected: `No such file or directory`.

---

## Task 19: CLAUDE.md house rule swap

**Files:**
- Modify: `CLAUDE.md` (the now-Korean-primary version from Task 18)

- [ ] **Step 19.1: Locate "Korean parity, no drift" rule in `When Editing This Repo` section**

```bash
grep -n "Korean parity\|한국어 패리티" CLAUDE.md
```

- [ ] **Step 19.2: Replace with new rule**

Old text (Korean):
```
- **Korean parity, no drift.** `CLAUDE.md`와 `docs/philosophy/*.md`는 영문이 canonical로 작성. 모든 `*.ko.md` 동반 문서는 **full content parity** — summary나 gloss 아님. 같은 PR에서 영문과 한국어 함께 업데이트. 하나만 업데이트한 PR은 거절.
```

New text:
```
- **Korean-primary, English-terms-only.** `CLAUDE.md`와 `docs/philosophy/*.md` 등 user-facing 문서는 한국어를 primary로 작성. 영어는 **식별자**(P#, AP#, Law N, §X.Y, plugin 이름), **고유명사**(OMC, gstack, Ouroboros, CE, Anthropic 등), **원문 인용**(verbatim, 어느 방향으로도 gloss 추가 안 함), **기술 용어 중 자연스러운 한국어 대응이 없는 것**(`frontmatter`, `PreCompact`, `subagent`, `hook`, `skill` 등)에 한정. `*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치).
```

- [ ] **Step 19.3: Verify**

```bash
grep -c "Korean parity, no drift\|한국어 패리티" CLAUDE.md
```
Expected: `0` (old rule removed).

```bash
grep -c "Korean-primary, English-terms-only" CLAUDE.md
```
Expected: `1` (new rule present).

---

## Task 20: Adversarial pass on Commit-2 output

**Files (read only):**
- All post-Task-19 files: `docs/philosophy/*.md`, `CLAUDE.md`

- [ ] **Step 20.1: Dispatch general-purpose subagent**

Prompt focuses on Commit-2-specific concerns (per spec §7.3 attack vectors 7, 8, 9, 10):

```
Read these files: <list>. The bilingual `*.ko.md` companion model was just retired; .md files now contain Korean primary content. Attack:

7. Any residual English prose that should be Korean (i.e., not identifier / proper noun / quote / technical term).
8. Any orphan `*.ko.md` reference in CLAUDE.md / `*.md` / scripts / hooks / plugin READMEs.
9. Any place where the trivia escape rule still appears as a full definition outside P12 (should be cross-ref only).
10. Whether the new "Korean-primary, English-terms-only" CLAUDE.md house rule is concrete enough that a future PR author knows what to do.

Plus general checks: §6 Attribution Map cell rule applied; Appendix A quotes verbatim; CLAUDE.md Forbidden Patterns names still English.

Report severity P0/P1/P2 with location + concrete fix.
```

- [ ] **Step 20.2: Apply P0/P1 fixes inline**

- [ ] **Step 20.3: Re-dispatch until clean**

---

## Task 21: Squash Commit-2 mini-edits + final commit

- [ ] **Step 21.1: Stage all Commit-2 changes**

```bash
git add -A docs/philosophy/ CLAUDE.md
```

(The deletions from Tasks 15, 17, 18 are already staged via `git rm`.)

- [ ] **Step 21.2: Commit**

```bash
git commit -m "docs: retire bilingual .ko.md companion; switch to Korean-primary single-file

- Overwrite *.md with *.ko.md content (Korean primary)
- git rm devbrew-harness-philosophy.ko.md, devbrew-roadmap.ko.md, CLAUDE.ko.md
- CLAUDE.md house rule: 'Korean parity' → 'Korean-primary, English-terms-only'
- Apply EN-source / KO-prose cell rule to §6 Attribution Map
- Preserve Appendix A quotes verbatim (no glosses added either direction)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 21.3: Verify two-commit branch state**

```bash
git log --oneline origin/main..HEAD
```
Expected: 2 commits — Commit-1 (Task 13.5 squash) and Commit-2 (this task).

- [ ] **Step 21.4: Push branch**

```bash
git push origin feature/harness-philosophy
```

---

## Task 22: Open PR

- [ ] **Step 22.1: Create PR**

```bash
gh pr create --title "docs(philosophy): Three Laws restructure + roadmap absorption + retire bilingual model" --body "$(cat <<'EOF'
## Summary

- Restructure §2 around Three Laws (§2.1 Law 1 / §2.2 Law 2 / §2.3 Law 3 / §2.4 cross-cutting); 14 APs nested as anti-corollaries; 3 absorbed into parent P body
- Absorb 53 Go roadmap candidates into existing principles + §4 primitives — **no new principles** (lightness applied uniformly)
- Retire bilingual `*.ko.md` companion model — collapse to Korean-primary single-file `.md`
- Update CLAUDE.md house rule: "Korean parity" → "Korean-primary, English-terms-only"

Two commits in this PR (squash-merged):
- **Commit 1** = structural restructure with bilingual parity preserved
- **Commit 2** = bilingual retirement + house rule swap

## Test plan

- [ ] CI / hooks pass
- [ ] Spec acceptance criteria 1–19 verified manually (see [`docs/specs/2026-05-06-philosophy-restructure-design.md`](docs/specs/2026-05-06-philosophy-restructure-design.md) §5)
- [ ] Adversarial pass clean (0 P0/P1) on both commits
- [ ] Korean-primary sample check (5 paragraphs in each new `.md` confirm Korean prose with English terms only)
- [ ] CLAUDE.md links validate (no orphan `.ko.md` refs; §3 catalog redirect to §2 works)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 22.2: Verify PR created**

PR URL is returned by `gh pr create`. Open in browser to confirm.

- [ ] **Step 22.3: Squash-merge after review**

```bash
gh pr merge --squash --delete-branch
```

(Per user memory: `--delete-branch` is house default; force-delete local branch after squash merge.)

```bash
git checkout main && git pull && git branch -D feature/harness-philosophy
```

---

## Self-Review (run after writing the plan)

**1. Spec coverage:**

| Spec section | Plan task |
|---|---|
| Goal 1 (§2 reorganized) | Task 3 |
| Goal 2 (16 mods + 2 §4 expansions) | Tasks 4, 5, 7, 8 |
| Goal 3 (retire bilingual) | Tasks 14–19 |
| Goal 4 (sync derivative) | Tasks 11, 12 |
| AC 1–14 (mechanical) | Verified at end of each task |
| AC 15–19 (semantic) | Tasks 8, 7.3, 9 |
| §6 Files to Modify | All 6 files touched across tasks |
| §6.1 Build Sequence | Tasks 1–22 mirror this sequence |
| §7.3 Adversarial pass | Tasks 13, 20 |
| Trivia consolidation (Constraint) | Tasks 8.8, 9 |
| Header form binding (Constraint) | Tasks 3, 7.1, 16.1, 17.3, 18.3 |
| Appendix A quote policy | Task 16.2 |
| Attribution Map cell rule | Tasks 10.2, 16.3 |
| Plugin READMEs out-of-scope | Confirmed — no plan task touches `plugins/` |

**No gaps detected.**

**2. Placeholder scan:** None found. All steps contain executable commands or specific edit content.

**3. Type/identifier consistency:**
- §2.X header form is `## 2.X Under Law N — Description` (consistent across Tasks 3, 13.5 verification, 16.1).
- C# IDs match between §11.1 / §11.2 / §11.4 references in Tasks 2, 8, 10.
- Anti-corollary breadcrumb format `*Anti-corollary of P{N}. Original location: former §3.*` consistent (Task 4).

---

## Follow-up Issues (recorded; not blocking)

These came up during planning or are P2 findings from prior adversarial passes. Open as separate issues after PR merge:

- **`docs/git-workflow/` broken links in CLAUDE.md** — independent of philosophy restructure. Separate PR.
- **Plugin READMEs bilingual policy migration** — explicit follow-up after this PR.
- **§11 ledger unification (Finding 1.2 P2)** — consolidate so each C# appears in exactly one row; cross-check via grep.
- **C66 in-spec gloss (Finding 2.2 P2)** — `linked artifact flow` not defined in roadmap body; add gloss in philosophy §2.3 / P5 expansion paragraph.
- **AP9 → P22 vs P9 justification (Finding 3.2 P2)** — already added 1-line note in §11.B.1; confirm reviewer accepts.
