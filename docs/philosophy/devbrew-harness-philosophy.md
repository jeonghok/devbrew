# devbrew Harness Philosophy

> **Specify before you code. Review before you ship. Compound before you forget.**
>
> *The bottleneck is not the model. It's the spec, the review, and the memory. devbrew's job is to fix all three without the user having to remember to.*

This is the philosophy layer that every plugin under `plugins/*` inherits. The repo-level [`CLAUDE.md`](../../CLAUDE.md) is the tight, preloaded context anchor that restates the three laws and the plugin shape in ~130 lines; this file is the full version with attribution, anti-pattern library, direct quotes, and the reasoning behind every principle.

**Sources absorbed:**

- **OMC** — Yeachan-Heo/oh-my-claudecode v4.11.6 (28.9k★, 20 hooks, 32 skills, 19 agents, dedicated benchmark suite)
- **gstack** — garrytan/gstack (23+ skills as "virtual engineering team", ETHOS.md, preamble-tier, multi-host compile targets)
- **Ouroboros** — Q00/ouroboros (14 skills, 9 agents, Pydantic-frozen seeds, ambiguity/convergence math, event-store)
- **Compound-Engineering** — EveryInc/compound-engineering-plugin v2.65.0 (~40 skills, ~45 agents, zero hooks, skills-over-commands axiom) + the canonical every.to essays (Klaassen: *"My AI Had Already Fixed the Code Before I Saw It"*, *"Stop Coding and Start Planning"*, *"Teach Your AI"*; Shipper + Klaassen: *"How Every Codes With Agents"*)
- **Anthropic Engineering & Research** — *Building Effective AI Agents*, *Effective Context Engineering for AI Agents*, *Claude Code: Best Practices for Agentic Coding*, *Writing Effective Tools for AI Agents*, *Effective Harnesses for Long-Running Agents*, *How We Built Our Multi-Agent Research System*, *Code Execution with MCP*, *Skill Authoring Best Practices*
- **devbrew's existing stance** — `plugins/quality-gates/` v1.4.0 (3-gate pipeline delegating to pr-review-toolkit / feature-dev / superpowers; composition over monolith already baked in)

---

## 0. The Thesis

> **The bottleneck in AI-assisted software work is not model capability — it is the clarity of the input, the independence of the reviewer, and the memory of prior cycles. A good harness disciplines all three without the user having to remember to.**

Every subsequent principle, primitive, anti-pattern, and plugin shape must be traceable back to this sentence. If a design decision doesn't serve *input clarity*, *reviewer independence*, or *compounding memory*, it probably doesn't belong.

All four source harnesses converge on this diagnosis. Anthropic's own engineering writing endorses it in different words:

- *"Find the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."* — *Effective Context Engineering*
- *"Prioritize transparency by explicitly showing the agent's planning steps."* — *Building Effective Agents*
- *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* — *Claude Code Best Practices*
- *"Like Claude Code creating a to-do list, or your custom agent maintaining a NOTES.md file, this simple pattern allows the agent to track progress across complex tasks."* — *Effective Context Engineering*

---

## 1. The Three Laws (hierarchical; Law N overrides Law N+1 on conflict)

### Law 1 — Clarity Before Code

No implementation proceeds while the specification is ambiguous. Specification authoring is a first-class *phase*, with its own skills, its own gates, and its own refusal behavior. Whatever numerical or structural mechanism a plugin picks (Ouroboros' `Ambiguity ≤ 0.2`, OMC's `deep-interview` brownfield-aware questioning, gstack's `/office-hours` six forcing questions, CE's `ce-brainstorm`), the harness **must have the ability to say "I refuse to code this yet"**. Trust-the-LLM is insufficient here; Anthropic itself warns that *"letting Claude jump straight to coding can produce code that solves the wrong problem."*

**Corollary:** the spec is a durable, reviewable artifact (markdown file, not just chat history). It can be re-read, diffed, versioned, and fed back into the next cycle.

**Trivia escape:** see canonical statement at §2.1 / P12 (consolidated mention).

### Law 2 — Writer and Reviewer Must Never Share a Pass

The same turn that writes code may not approve it. This is a hard rule, not a heuristic. OMC states it operationally: *"Keep authoring and review as separate passes… Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass."* gstack enforces it with `allowed-tools` frontmatter scoping (office-hours physically cannot ship code). CE enforces it with a parallel 25-persona review pipeline. Ouroboros enforces it with a 3-stage evaluation gate (mechanical → semantic → consensus) where Stage 3 requires multi-model voting. Anthropic's *Multi-Agent Research System* validates the underlying pattern: independent subagents with clean contexts beat a single agent because *"careful handoffs"* break cognitive anchoring.

**Corollary:** verification is load-bearing infrastructure, not an afterthought. The harness owes every code-writing cycle (a) an evidence-gathering step, (b) an independent review step, and (c) a refusal-to-claim-done-without-evidence rule. This is already the spine of `plugins/quality-gates/` — the philosophy generalizes it to every plugin.

### Law 3 — Every Cycle Must Leave the System Smarter

What makes a harness "compound" is that the N+1th task is strictly easier than the Nth. The mechanism is low-tech: **files in the repo that future sessions read**. Klaassen's definition is unambiguous:

> *"Compounding engineering is about building systems with **memory**, where every pull request teaches the system, every bug becomes a permanent lesson, and every code review updates the defaults. AI engineering makes you faster today. Compounding engineering makes you faster tomorrow, and each day after."*

The harness must give every cycle a named compounding step — not optional, not a nice-to-have — that asks "what did we learn that should become a default?" and writes it somewhere a future session will unavoidably encounter. OMC's `learner`+`wiki` triad, CE's `ce-compound` with Discoverability Check that auto-edits `AGENTS.md`/`CLAUDE.md`, and gstack's `learnings.jsonl` are the three templates to study.

**Corollary — the Discoverability Check:** the compounding step must confirm the new learning is reachable from future sessions. Writing a learning to a file that no future agent reads is theater. The write must also update whatever index (CLAUDE.md, skill description, reviewer checklist) makes it findable. The operational mechanics of this corollary — extraction gate, index triad, lifetime tags, grep-recall criterion — live in §4.6 Compounding Skill primitive. This corollary states the *rule*; §4.6 specifies the *how*.

---

## 2. Principles (organized under the Three Laws)

These are the operational commitments. Each is named, attributed, and has a concrete translation into devbrew plugin decisions. Each principle lives under the Law it primarily serves; principles that serve all three are gathered in §2.4 Cross-Cutting Commitments.

### 2.1 Under Law 1 — Clarity Before Code

Principles that serve specification clarity before implementation begins. AP1, AP5 nested as anti-corollaries.

### P1. Specification as Artifact, Not Chat

Specs live as files (markdown or structured YAML), are named, are versionable, are diff-able. The interview that produces them is a named skill with its own loop, not "just ask Claude." Ouroboros' frozen-Pydantic Seed is the far end of this spectrum; CE's `ce-brainstorm → requirements.md` is the softer end; OMC's `deep-interview` with a dimensional ambiguity score is the middle. devbrew picks **markdown spec with optional structured gates**, not freeform chat — so that specs survive compaction and can be grep'd by future cycles.

> *"Most AI coding fails at the input, not the output. The bottleneck is not AI capability — it is human clarity."* — Ouroboros README
>
> *"Before telling AI what to build, define what should be built."* — Ouroboros

### P2. The Ambiguity Gate

A spec has either cleared or not cleared a clarity threshold. The gate must be **visible, declared, and refusable**.

- **Baseline (required for every spec-authoring plugin): Structural.** Mandatory sections (Context/Why, Goals, Non-goals, Constraints, ACs, Files to Modify, Verification Plan, Rejected Alternatives, Metadata) + a "cannot exit without a concrete next action" clause. Modeled on gstack office-hours.
- **Enhancements (optional, layered on top of the baseline):**
  - **Adversarial** (gstack office-hours Phase 5.5, OMC ralplan Planner/Architect/Critic): spawn a sub-agent to attack the draft before it leaves planning. Strongly recommended for any plugin that ships production code.
  - **Numerical** (Ouroboros `Ambiguity ≤ 0.2`): LLM-scored weighted dimensions, temp 0.1, explicit threshold. Allowed but discouraged — §5.3 makes the case that numerical gates are brittle because the scorer and the generator are the same model. Use only when you have a second-model scorer.

Refusal must be real: a plugin that says "spec is unclear" but then lets the user `/continue` is not enforcing P2. No silent pass-through to code.

**Roadmap absorption (C43+C44+C45+C51 — Socratic Interview Discipline):** the interview that produces the spec follows a Socratic 4-path routing (C43): (a) factual questions auto-confirm against the codebase with `[from-code][auto-confirmed]`, (b) human-judgment questions are routed to the user (default path), (c) ambiguity questions dispatch a sub-agent for adversarial draft, (d) ontological questions use the 5-type framework (C51: ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT). A dialectic rhythm guard (C44) enforces that 3 consecutive non-user answers must route the next question to the user. A breadth-keeper agent (C45) — `disallowedTools: Write, Edit` — runs alongside to prevent narrow tunneling.

### AP1. "PRD Theater" (OMC)

*Anti-corollary of P2. Original location: former §3.*

Auto-generated acceptance criteria that are generic placeholders — *"prd.json created with criteria: Implementation is complete, Code compiles. Moving on to coding."* The harness must force refinement or refuse to proceed. Ralph's mechanism: generate a scaffold, force the model to refine, detect unchanged-placeholder phrases as theater.

### P12. Transparency of Planning

The agent must *show its plan before executing it*, and the user must be able to redirect. This is a direct quote from Anthropic's *Building Effective Agents*:

> *"Prioritize transparency by explicitly showing the agent's planning steps."*

Plan mode exists for this reason. devbrew's plugins that do anything complex **should default to plan-then-execute**, with the plan written to a file (not just shown in chat) and the user gets an approval gate. Plan mode is the canonical mechanism; plugins should respect it and, where appropriate, invoke it themselves.

**Exception — small changes:** see *Trivia escape (canonical mention)* paragraph below for the consolidated rule.

**Roadmap absorption (C34+C60):** transparency expands with — (C34) plan/audit boomerang (the plan that authorized the work returns alongside the work for verification; the audit checks plan-vs-code alignment); (C60) scope-adaptive depth (lightweight for trivia escape, standard for normal work, deep for high-stakes — depth is declared up-front, not discovered mid-flight).

**Trivia escape (canonical mention; consolidates Law 1 corollary, AP5, §4.1 escape hatch):** if you could describe the diff in one sentence (Anthropic, *Claude Code Best Practices*), skip the plan and skip the spec gate. Examples that qualify: typos, renames, comment-only edits, single-file formatting. Examples that do NOT qualify: multi-file changes, behavior changes, anything touching public API. Detection of triviality is the *invoking* skill's responsibility, not the spec/plan skill's (which is never given a chance to refuse-for-trivia). Cross-refs: see Law 1 corollary, AP5 nested below, §4.1 escape hatch.

### AP5. Trivia Pipeline Overhead (Anthropic)

*Anti-corollary of P12. Original location: former §3. For the canonical rule see P12 above.*

Running the full pipeline (spec → plan → review → verify → compound) on a typo fix is ceremony for its own sake. Plugins must detect triviality and skip earlier phases. This is Ouroboros' biggest weakness — no documented one-liner escape hatch; devbrew must not inherit it.

### 2.2 Under Law 2 — Writer/Reviewer Independence

Principles that serve verification independence and structural reviewer separation. AP3, AP13, AP14 nested as anti-corollaries; AP11 absorbed into P3 body (no standalone header).

### P3. Writer/Reviewer Isolation via Tool Scoping

Following gstack: use `allowed-tools` frontmatter to make role boundaries *physical*, not just prompt-level. A reviewer agent has no Write/Edit. A planner agent has no Bash-that-mutates. An interviewer has no code-execution. This turns role separation from "trust the prompt" into "the tool literally doesn't exist." OMC implements the same idea via its Delegation Enforcer PreToolUse hook that intercepts Task calls and injects model/tool constraints from agent frontmatter.

> *"Role boundaries are enforced by disallowedTools in frontmatter. Every agent prompt starts with 'You are X. You are responsible for Y. You are NOT responsible for Z' — the negative clause prevents helpful-agent creep."* — OMC architecture

**Anti-pattern absorbed (formerly AP11):** A reviewer with `Write` access is not a reviewer; a planner with mutating `Bash` is not a planner. The default (full tool access) is forbidden for any role-scoped agent. Every agent definition must have explicit `allowedTools` and `disallowedTools` lists.

### P4. Verification Is Infrastructure

Every task ends with a verification pass that produces *evidence*. "Tests pass" is evidence; "I think it works" is not. Anthropic says it plainly: *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* devbrew already has `quality-gates/`; the philosophy makes it the default expectation for every plugin that ships code.

Three verification modalities, in priority order:

1. **Mechanical** — compile, lint, type-check, test. Cheap, binary, non-negotiable.
2. **Semantic** — agent-judged AC compliance against the spec from P1. More expensive, requires an independent reviewer (P3).
3. **Runtime** — actually run the thing (headless browser, CLI invocation, smoke test). Catches the class of bugs the first two miss. This is `quality-gates/` Gate 3 today; it should be the model for every plugin.

No cycle claims "done" without at least one and preferably all three.

**Roadmap absorption (C35 — Two-Tier Test Classification):** verification tests are split into (a) **gate tier** — runs on every commit / PR; cheap (< 5s); failure blocks; and (b) **periodic tier** — runs on schedule or trigger; expensive (E2E ~$3.85/run, LLM-judge ~$4/run); failure surfaces but doesn't block per-commit. Diff-based selection routes which tier runs.

### AP3. Self-Approval (Law 2 corollary)

*Anti-corollary of P4. Original location: former §3.*

The same turn writes and approves. Strictly forbidden by Law 2. The harness must route approval through a structurally independent pass — either a different agent or a different skill or, at minimum, a different invocation of the reviewer skill with fresh context.

### P10. Taste Pluralism — Many Small Reviewers, Not One Big One

The single most stealable idea from CE is the 25-persona reviewer pipeline: `dhh-rails-reviewer`, `kieran-python-reviewer`, `julik-frontend-races-reviewer`, plus functional reviewers (`security-sentinel`, `correctness`, `testing`, `maintainability`, `api-contract`, `schema-drift-detector`). Each is a small markdown file, versionable, edit-able in a single commit when a bug slips through. devbrew's equivalent:

- A `code-review`-style plugin should have a *library* of reviewer personas, not a single reviewer.
- When a bug escapes review, the fix is edit-one-persona-file-and-commit. That commit is the compounding event.
- Persona files should be *named after specific opinions*, not generic roles. Not "security reviewer" but "reviewer that flags input parsing without length caps because CVE-X happened." Specificity is what makes the library grow.

**Roadmap absorption (C19+C24+C31+C32+C42+C63):** the persona library expands operationally — (C19) two-stage protocol (spec compliance check → code quality check, sequential not parallel); (C24) baseline specialists `api-reviewer` + `performance-reviewer` always-on; (C32) extended catalog `data-migration` / `maintainability` / `red-team` each emitting per-finding JSON per §4.4 contract; (C31) scope-gated dispatch — Testing + Maintainability always-on for ≥50 LOC, others conditional via `SCOPE_*` env vars, with `[NEVER_GATE]` floor on Security + Testing; (C42) tiered gating — eng-review is the single hard gate, all specialist reviews are advisory; (C63) per-reviewer "What NOT to flag" lists to suppress reviewer-specific false positives.

### P11. Cross-Model Adversarial at High-Stakes Moments

When the decision is expensive to reverse, a single model's opinion is not enough. gstack's `/codex` and `/review` Step 5.7 deliberately pull in OpenAI Codex for a second opinion; OMC's `ccg` decomposes a question into Codex (arch/correctness/risks) + Gemini (UX/alternatives/docs) prompts and synthesizes with explicit conflict-surfacing; Ouroboros' Stage 3 consensus requires 2/3 majority across 3 models for any seed mutation.

devbrew's position: **single-model is the default, multi-model is a gate for irreversible decisions.** "Irreversible" means: production deploys, spec mutations, architectural commitments, security-critical code, schema migrations. The multi-model layer is opt-in per plugin, not forced.

> *"Agreement is signal, not proof. […] AI models recommend. Users decide."* — gstack ETHOS, "User Sovereignty"
>
> *"Anti-pattern: 'Both models agree, so this must be correct.'"* — gstack ETHOS

**Roadmap absorption (C33+C52+C68):** multi-model adversarial expands operationally — (C33) always-on adversarial review (never conditional on LOC or risk signals; never gates shipping — advisory only); (C52a) structural consensus triggers (4 of 7: SEED_MODIFICATION / ONTOLOGY_EVOLUTION / GOAL_INTERPRETATION / MANUAL_REQUEST require multi-model concurrence); (C52b) drift-aware consensus triggers (when measured drift exceeds threshold, escalate to multi-model); (C68) adversarial 4-technique framework — assumption violation, composition failures, cascade construction, abuse cases. Depth-calibrated: Quick / Standard / Deep based on stakes.

### AP13. "Both Models Agree So It's Correct" (gstack)

*Anti-corollary of P11. Original location: former §3.*

Multi-model concordance is signal, not proof. The harness must explicitly surface *conflicts* when models disagree (OMC ccg pattern) and must never treat agreement as a bypass of the user's final decision (P17).

### AP14. Unchallenged Consensus (Ouroboros weakness, generalized)

*Anti-corollary of P11. Original location: former §3.*

A loop or consensus mechanism that smoothly converges to a wrong answer has no built-in defense. Ouroboros' specific failure mode is ontology-fixed-point convergence, but the pattern generalizes: any time multiple passes agree, the next pass defaults to "looks fine" and the wrong answer ossifies. devbrew's rule: **a final adversarial pass runs on any consensus, not just on stagnation.** When a plan is about to be locked in, when multiple reviewers agree, when a spec is about to be crystallized — one more independent pass attacks it. OMC ralplan's mandatory "steelman antithesis" before synthesis is the pattern to copy. This dovetails with AP13: agreement is an invitation to adversarial review, not a bypass of it.

### 2.3 Under Law 3 — Compounding Memory

Principles that serve memory durability and learning capture across cycles. AP10 absorbed into P5 body; AP17 absorbed into P14 body (no standalone headers).

### P5. Filesystem as Memory (Just-in-Time Context)

State lives in files, not in context. The harness preloads a minimal index (CLAUDE.md, spec, plan, state file) and loads everything else on demand via Glob/Read/Grep. Anthropic:

> *"Rather than pre-processing all relevant data up front, agents built with the 'just in time' approach maintain lightweight identifiers […] and use these references to dynamically load data into context at runtime using tools. […] Claude Code is an agent that employs this hybrid model: CLAUDE.md files are naively dropped into context up front, while primitives like glob and grep allow it to navigate its environment and retrieve files just-in-time."* — *Effective Context Engineering*

devbrew inherits this wholesale. Preloaded context must earn its slot; everything else is discovered by the agent when needed. **No stale-index, no RAG, no vector store.** Grep is the query language.

**Anti-pattern absorbed (formerly AP10):** No pre-baked search trees, vector stores, or cached embeddings of the codebase. Anthropic explicitly says Claude Code avoids this *"effectively bypassing the issues of stale indexing and complex syntax trees."* Glob + grep + read, just-in-time, every time.

**Roadmap absorption (C66 — Linked Artifact Flow):** files-as-memory primitive extends to *cross-artifact linkage*. Spec links to plan; plan links to code paths; code links back to spec via commit trailer (P20). The chain is grep-traversable: any artifact can recover its full provenance graph via grep on stable IDs.

### P14. State Survives Compaction

The context window will compact. The harness must assume it will and design for it. OMC's PreCompact hook snapshots state to `.omc/notepad.md` and `.omc/project-memory.json` *before* compaction so the next session has something to read. Anthropic endorses this as a first-class pattern:

> *"In Claude Code, for example, we implement this by passing the message history to the model to summarize and compress the most critical details. The model preserves architectural decisions, unresolved bugs, and implementation details while discarding redundant tool outputs or messages."* — *Effective Context Engineering*

devbrew's rule: **if a fact is load-bearing for the next turn, it must live in a file before the turn ends.** Plan file, state file, spec file, commit message, CLAUDE.md, review findings markdown — something durable. Chat-only facts are assumed dead after compaction.

**Anti-pattern absorbed (formerly AP17):** A fact that only lives in the conversation is a fact that's dead after compaction. If a fact is load-bearing for the next turn, it must live in a file before the turn ends.

### P15. The Initializer/Resumer Split for Long-Running Work

Anthropic's *Effective Harnesses for Long-Running Agents* describes a pattern that devbrew absorbs:

> *"Initializer agent: The very first agent session uses a specialized prompt that asks the model to set up the initial environment: an init.sh script, a claude-progress.txt file that keeps a log of what agents have done, and an initial git commit that shows what files were added. Coding agent: Every subsequent session asks the model to make incremental progress, then leave structured updates."*

For any plugin that runs work across multiple sessions (ralph-loop, schedule, background tasks), the first session's job is *different* from the Nth session's job. The first bootstraps durable state; every subsequent session resumes from that state. This is the shape `quality-gates`' Stop-hook state machine already has; devbrew generalizes it.

### P16. Measure, Don't Trust

Every claim the harness makes ("3× faster," "catches more bugs") should be backed by a benchmark. OMC is the cautionary tale: it has `benchmarks/harsh-critic/`, `/code-reviewer/`, `/debugger/`, `/executor/` suites *with ground-truth JSONs and runners*, but the README's numeric claims aren't cited from the benchmark output. devbrew adopts the infrastructure and closes the gap: any plugin that claims a quantitative improvement must have a benchmark in `plugins/<name>/benchmarks/` whose output produces the claimed number.

**Roadmap absorption (C9+C54):** measurement expands with — (C9) dimensional progress tracking (per-cycle metrics: ambiguity reduction Δ, convergence Δ, defect-escape rate, stagnation events); (C54) drift measurement formula (a quantitative drift = `0.4·structural_drift + 0.4·semantic_drift + 0.2·behavioral_drift`; threshold for action declared in skill frontmatter).

### P20. Commit Trailers as Decision Audit Trail

OMC uses structured commit trailers — `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:` — to encode *why* into git history. This is unusually powerful and cheap: the *why* survives as git metadata, queryable forever, and next-session agents can read `git log --format="%B"` to recover decision context. devbrew adopts this as a convention, not a requirement — plugins that care about decision history should use it, and `project-init` should document it in the repo's git-workflow docs.

### 2.4 Cross-Cutting Commitments (serve all three Laws)

Principles whose service applies to clarity, independence, AND compounding. AP2, AP4, AP6, AP7, AP8, AP9, AP12, AP15, AP16 nested as anti-corollaries.

### P6. Progressive Disclosure for Skills

*Serves L1, L2, L3:* skill name + 1-line description give the spec-time interface (L1); body is reviewable in isolation as a single contract (L2); compounding adds skills and anti-examples without changing preload cost (L3).

Skill name + 1-line description are the *only* preloaded parts. The body is read when triggered. References and scripts cost zero until invoked. This is Anthropic's explicit skill-authoring best practice and the reason CE migrated commands → skills in v2.39.0. devbrew commits to it unreservedly.

**Consequences for authoring (skills, NOT commands):**

- **Skill names are gerunds** (`running-quality-gates`, `authoring-specs`, `compounding-learnings`), following Anthropic's skill-authoring best practice. Never vague (`helper`, `utils`, `tools`).
- **Command names are short imperative verbs or nouns** (`qg`, `review`, `commit`, `plan`), not gerunds. Commands are user-typed rituals; they optimize for typing speed, not for description-triggered matching. CE's `ce-plan`/`ce-work`/`ce-review` and gstack's `/office-hours`/`/ship` are the templates.
- **Descriptions are declarative** (`what + when`), never first-person (`"I can help you…"` is forbidden — it forces the model to parse an invitation instead of a condition).
- **Skill bodies are complete contracts**, not loaders for deeper content. OMC's skill-section schema (`<Purpose>`, `<Use_When>`, `<Do_Not_Use_When>`, `<Why_This_Exists>`, `<Steps>`, `<Good>`/`<Bad>` examples, `<Escalation_And_Stop_Conditions>`, `<Final_Checklist>`) is the template to copy.
- **Anti-examples are first-class.** `<Bad>` with "Why bad:" belongs in every skill that handles tricky judgment.

**Roadmap absorption (C57 — Review Mode Detection):** a skill that adapts to its invocation context. 4 modes: `headless` (CI; no prompts; emit machine-readable verdict), `autofix` (apply safe fixes inline), `report-only` (surface findings, take no action), `interactive` (prompt user at decision points). The mode is detected from environment / invocation flags, not assumed; default = `interactive` for explicit user invocation.

### AP7. Vague Skill Names and Capability Descriptions (Anthropic skill best practices)

*Anti-corollary of P6. Original location: former §3.*

*"Helper," "Utils," "I can help you…"* — all forbidden. Skill descriptions must be declarative, specific, and use action verbs. The description is the skill's only chance to earn its slot in the preloaded system prompt; wasted words cost every session.

### AP8. Technical-Identifier Pollution in Tool Responses (Anthropic writing-tools)

*Anti-corollary of P6. Original location: former §3.*

Returning `uuid`, `mime_type`, `256px_image_url` when the agent needs `name`, `caption`, `file_type` crowds out signal. Tool responses in devbrew plugins are curated for model downstream decisions, not API completeness.

### P7. Loops, Not One-Shots

*Serves L1, L2, L3:* the loop's first phase is spec authoring (L1); its review phase is structurally separate (L2); its compound tail is the named learning-capture step (L3).

Work flows through cycles, not single passes. The unit is "spec → plan → implement → review → verify → compound," and the entire loop runs per task, not per session. CE's four-step `Plan → Work → Review → Compound` is the canonical named cycle; OMC's `autopilot` 5-phase pipeline (Expansion → Planning → Execution → QA → Validation → Cleanup) is a more elaborate instance; Ouroboros' nested inner/outer loop with Wonder/Reflect is the most ambitious. devbrew's `quality-gates` already has the spine (Gate 1 plan → Gate 2 review → Gate 3 runtime, loop back to Gate 1 on change).

**What devbrew adds to quality-gates post-philosophy:** an explicit `compound` step at the tail — a sixth gate or a post-pipeline skill — whose only job is to capture learnings to files.

### P8. Maintain Simplicity (YAGNI, delete-over-add)

*Serves L1, L2, L3:* less surface to specify (L1); less for the reviewer to disagree about (L2); deletion is the cheapest compounding move (L3).

Anthropic's first principle in *Building Effective Agents* is literal: *"Maintain simplicity in your agent's design."* OMC's `AGENTS.md` states it as *"Prefer deletion over addition when the same behavior can be preserved."* gstack's ETHOS bundles the "boil the lake" principle with an explicit compression table and a corollary: *"The last 10% of completeness that teams used to skip? It costs seconds now."* These aren't in tension if you read carefully — Anthropic warns against *architectural* complexity (frameworks, abstraction layers, agents when workflows suffice); gstack urges *task-completion* completeness (don't skip the test; don't skip the error path).

devbrew's position: **architectural simplicity, completion maximalism.** Plugins do one thing, compose with others, avoid framework abstractions, but when they act, they act thoroughly.

> *"For many applications, optimizing single LLM calls with retrieval and in-context examples is usually enough. […] Don't hesitate to reduce abstraction layers and build with basic components as you move to production."* — Anthropic, *Building Effective Agents*
>
> *"AI-assisted coding makes the marginal cost of completeness near-zero."* — gstack ETHOS

### AP4. LOC as Success Metric (gstack backlash)

*Anti-corollary of P8. Original location: former §3.*

Tan's public claim of *"600,000+ lines of production code, 10,000–20,000 lines per day"* draws rightful criticism. LOC measures activity, not outcome. devbrew never ships a metric that rewards code volume; it ships metrics that reward *closing tickets, passing verification, reducing regressions, cutting iteration count*.

### AP6. Framework Abstraction in Production (Anthropic)

*Anti-corollary of P8. Original location: former §3.*

> *"Don't hesitate to reduce abstraction layers and build with basic components as you move to production."*

No internal frameworks that wrap Claude Code primitives. When a plugin needs a script, it writes a script — not a DSL, not a config-generating config, not a class hierarchy. OMC's `run.cjs` central dispatcher is the cautionary tale; every hook shells through it, which creates a Node.js dependency for Python/Rust shops.

### P9. Composition Over Monolith

*Serves L1, L2, L3:* per-plugin specs stay narrow (L1); per-plugin reviewers don't bleed scope (L2); per-plugin learnings stay scoped to the plugin's domain (L3).

A plugin should do one thing well and delegate everything else to other plugins. `quality-gates` already models this — Gate 2 dispatches pr-review-toolkit, feature-dev, superpowers agents. The philosophy generalizes it: **every plugin in devbrew is a citizen of a marketplace, not a self-contained kingdom.** Where two plugins overlap, refactor into a third that both use; where a plugin needs a capability that exists elsewhere, depend on it explicitly in `README.md` prerequisites.

This is the anti-OMC-monolith move. OMC ships 20 hooks + 32 skills + 19 agents as one plugin; that buys convenience but inherits every coupling cost and makes per-capability adoption impossible. devbrew prefers many small plugins that interoperate.

**Corollary — the delegation convention:** when a plugin dispatches another plugin's agent via `subagent_type: "other-plugin:agent-name"`, that dependency is declared in the plugin's README prerequisites table (quality-gates already does this). Undeclared dependencies are a bug.

**Roadmap absorption (C61 — 5-Dimension Overlap Detection):** when two plugins propose overlapping capability, the composition discipline applies a 5-dimension check before deciding to merge / coexist / refactor: (a) input contract, (b) output contract, (c) side-effect surface, (d) cost class, (e) failure modes. Two plugins with identical 5-tuples should refactor into a third both depend on.

### AP12. Undeclared Plugin Dependencies (quality-gates lesson)

*Anti-corollary of P9. Original location: former §3.*

A plugin that dispatches `other-plugin:agent-name` must declare `other-plugin` in its README prerequisites table. Silent coupling is a bug. If the dependency is missing, the plugin must degrade gracefully (P19), not hard-fail.

### P13. Hooks for Enforcement, Skills for Capability, Agents for Personas

*Serves L1, L2, L3:* skill names are the spec-time discoverable surface (L1); agents enforce role separation (L2); hooks are durable enforcement that survives across cycles (L3).

A clear division of labor across Claude Code primitives:

- **Hooks** are the harness's enforcement layer. They run regardless of what the agent thinks to do. Use them for things the agent cannot be trusted to remember: state preservation before compaction (OMC's PreCompact hook), refusal-to-stop when a job isn't verified done (OMC's `persistent-mode.cjs`), pattern-matched prompt redirection (Ouroboros' `keyword-detector.py`), PR-shape validation, branch-name checks.
- **Skills** are the capability surface. The agent invokes a skill when it recognizes a situation. Use them for reusable procedures: `authoring-specs`, `running-quality-gates`, `compounding-learnings`, `reviewing-with-personas`.
- **Agents** are personas with scoped tool access. The agent dispatches an agent when it needs an *independent pass* over something. Use them for role separation (P3): writer, reviewer, critic, verifier.
- **Commands** are user-invoked rituals. Use them sparingly — skills with declarative triggers are usually better. CE migrated away from commands in v2.39.0 for this reason.

**Hook coexistence rules (P9 × P13 interaction).** Because devbrew prefers many small plugins (P9), multiple plugins may install hooks on the same event. The house rules:

1. **Namespace your hooks.** Hook scripts live under `plugins/<name>/hooks/` and declare themselves in `hooks/hooks.json` scoped to the plugin. Never assume you are the only hook on an event.
2. **Hooks must be commutative within an event.** A plugin's hook must produce the same outcome regardless of whether another plugin's hook ran first on the same event. If order matters, that's a design bug — refactor to a skill that the ordering-sensitive plugin explicitly dispatches.
3. **`Stop` hook idempotency.** If a plugin's `Stop` hook reads a signal tag (like quality-gates' `<qg-signal>`) and injects a next-turn prompt, that signal tag must be unique to the plugin and must not collide with other plugins' signals. Use `<{plugin}-signal>` as the convention.
4. **Mutation-free `SessionStart` hooks.** `SessionStart` hooks are read-only advisors. They load state and surface status; they never mutate. This is the only way two plugins' session-start hooks can coexist.
5. **Declare your hook surface.** Every plugin's README lists which hook events it installs on and which signals/namespaces it owns. Collisions between plugins are a bug to be caught in code review.
6. **Kill switch per plugin.** Every hook installed by a plugin has a per-plugin opt-out env var (`DEVBREW_DISABLE_<PLUGIN>=1` + `DEVBREW_SKIP_HOOKS=<plugin>:<hook-name>`). OMC's `DISABLE_OMC=1` / `OMC_SKIP_HOOKS=...` is the template.

### P17. User Sovereignty

*Serves L1, L2, L3:* approval gates are declared in the spec (L1); the user is the final reviewer (L2); user-confirmed decisions become recorded defaults (L3).

The user makes decisions; the agent recommends. gstack's ETHOS states it as *"AI models recommend. Users decide. This is the one rule that overrides all others."* Ouroboros encodes it as the Dialectic Rhythm Guard (*"after 3 consecutive non-user answers, the next question MUST be routed to the human"*). Anthropic's writing endorses the same stance through its emphasis on plan mode, transparency, and explicit approval gates.

devbrew's translation: **risky, irreversible, or shared-state actions always go through a confirmation gate.** Any plugin that adds new action surface must decide which of its actions are risky and wire them through `AskUserQuestion` or an `ExitPlanMode` approval.

**Roadmap absorption (C56 — Autofix Disposition Tiers):** when a reviewer finds a fixable issue, the disposition routes through 4 tiers: (a) `safe_auto` — review-fixer applies inline, no user prompt; (b) `gated_auto` — downstream-resolver applies via `AskUserQuestion` (per P22 cost gate); (c) `manual` — surfaces for human decision; (d) `advisory` — released to PR description, no fix attempted. Tier choice is the reviewer's call; the dispatcher honors it.

### AP2. "Polite Stop" (OMC)

*Anti-corollary of P17. Original location: former §3.*

Claude's instinct to pause and **narrate a summary** after a positive review. OMC Ralph step 7: *"Treating an approved verdict as a reporting checkpoint is a polite-stop anti-pattern."* When the review passes, the next action is `/cancel` or the next cycle, not a narrative recap. devbrew's plugins must not insert reporting pauses between verified-done and next-action.

**Distinction — polite stop vs approval gate.** §5.2 says "pause at decision boundaries, run hard within." This is NOT polite stop. An **approval gate** is a pause *before* a decision so the user can redirect (`ExitPlanMode`, `AskUserQuestion` for risky actions, spec crystallization checkpoint). A **polite stop** is a pause *after* a decision has been verified done, inserting a narrative summary the user didn't ask for. Approval gates serve user sovereignty (P17); polite stops waste the user's attention budget. When in doubt: if the user can *redirect* by answering, it's an approval gate. If the user can only *acknowledge*, it's a polite stop — skip it.

### P18. Stagnation Is a Failure Mode, Not a Natural End

*Serves L1, L2, L3:* the declared max-iter / kill-switch is part of the spec (L1); detection is a verification of progress (L2); lateral persona dispatch on stagnation is a compound event (L3).

A loop that keeps retrying the same thing is not making progress; it's stuck. All four harnesses have explicit stagnation-detection logic:

- OMC's `ultraqa` stops early if the same error repeats 3 times.
- OMC's `self-improve` stops on plateau detection.
- Ouroboros detects A→B→A→B oscillation and ≥70% repeated questions as `stagnated`, then invokes `unstuck` with lateral-thinking personas.
- gstack's `/investigate` iron law: *"no fixes without investigation."*

devbrew's rule: every loop-bearing plugin ships with a circuit breaker — a maximum iteration count, a repeat-detection heuristic, and an escape hatch that invokes a *different* approach (fresh subagent, different reviewer, human prompt) rather than retrying.

**Roadmap absorption (C46 — Lateral Thinking Persona Recovery):** when stagnation is detected, the recovery dispatch uses a persona affinity table (deterministic first-match): HACKER → SPINNING, RESEARCHER → {NO_DRIFT, DIMINISHING_RETURNS}, SIMPLIFIER → {DIMINISHING_RETURNS, OSCILLATION}, ARCHITECT → {OSCILLATION, NO_DRIFT}, CONTRARIAN → all. Each persona arrives with a fresh prompt and lateral-thinking heuristics specific to the stagnation pattern.

### AP16. Unbounded Autonomy Without Stop Conditions (all harnesses, worst in OMC)

*Anti-corollary of P18. Original location: former §3.*

A loop that "never stops" (Sisyphus framing) will burn tokens and make the user distrust the system. Every autonomous loop must have: (a) max iteration count, (b) wall-clock budget, (c) repeat detection (P18), and (d) user-overrideable kill switch (OMC's `DISABLE_OMC=1` and `cancel-qg` are the templates).

### P19. Graceful Degradation of External Dependencies

*Serves L1, L2, L3:* fallback behavior is declared in the spec (L1); loud logging makes degradation reviewable (L2); failure-mode notes flow into compounding (L3).

OMC's `ccg`, `codex`, `gemini`, `deslop` skills all have graceful-degradation clauses — if the external tool is missing, the skill downgrades but doesn't fail. devbrew inherits this: **a plugin that depends on an optional external tool must continue to function (with reduced capability and an explicit log) when the tool is absent.** Hard blocks are reserved for things the plugin genuinely cannot live without.

### AP15. Silent Fallback Demotion (OMC weakness)

*Anti-corollary of P19. Original location: former §3.*

When an optional dependency is missing (`--critic=codex` with no Codex CLI installed), silently falling back to a lesser critic hides a degradation. devbrew's rule (combining P19 + evidence discipline): **graceful degradation must log loudly.** The user must be able to tell, from the output, whether the intended reviewer ran or a fallback did.

### P21. Security & Supply Chain

*Serves L1, L2, L3:* the threat model is declared in the spec (L1); persona-files-as-code policy makes security reviewable (L2); kill-switch + integrity field compound across plugin updates (L3).

Plugins are code and agents are prompts — both are attack surface. devbrew's minimum security posture:

- **State file secret hygiene.** State files (`.claude/<plugin>.local.md`) are git-ignored (P5, §4.8) but may be shared unintentionally (backup, copy, attached to a bug report). Plugins must not write secrets (tokens, API keys, full PII) to state files. Use placeholder references (`$GITHUB_TOKEN`, path references) instead of values.
- **Persona files are code.** Reviewer persona files (P10, §4.4) are load-bearing defaults that catch bugs. A PR that weakens a persona checklist (removes a rule, relaxes a threshold) is a **security-sensitive change** and requires the same scrutiny as modifying a test suite. PR templates should flag persona file changes as "security-relevant" when `git diff` touches any file under `plugins/*/reviewers/`.
- **Plugin-to-plugin trust.** When plugin A dispatches `plugin-b:agent-name`, plugin A inherits plugin B's agent behavior. If plugin B is updated with a malicious prompt injection, plugin A's users are affected. Mitigations: (a) declared dependencies with minimum versions (P9, AP12) so plugin A can pin plugin B to a known-good version; (b) `plugin.json` should include an optional `integrity` field (git SHA or tag) for critical dependencies; (c) supply-chain review is part of `quality-gates` Gate 2 when multiple plugins are in play.
- **Prompt injection in descriptions.** Skill descriptions are preloaded into every session's system prompt. A malicious skill description could contain prompt-injection payloads. Review skill descriptions for anomalies (unusual instructions, role-override attempts, Unicode tricks) as part of any plugin-to-plugin merge.
- **Kill switches are also security controls.** Per-plugin kill switches (`DEVBREW_DISABLE_<PLUGIN>=1`, see P13) let users disable a plugin instantly if it's compromised. Every plugin MUST honor its kill switch even when running autonomously; no hook may inspect the kill switch and refuse to respect it.

This is a floor, not a ceiling. Plugins handling secrets, credentials, or production systems need more.

### P22. Cost Awareness

*Serves L1, L2, L3:* cost class is declared in skill frontmatter (L1); fan-out caps gate the reviewer fan-out (L2); budget-vs-actual data compounds across cycles (L3).

AI-assisted workflows can be expensive. OMC's `ccg` decomposes one question into Codex + Gemini + Claude calls; gstack's `/review` fan-outs to 25 specialist sub-agents; Ouroboros' consensus gate uses 3 models. A thoughtless plugin can spend $10+ per invocation without warning. devbrew's cost discipline:

- **Declare cost class in the skill frontmatter.** Every skill declares `cost_class: low | medium | high | variable` based on worst-case behavior. `low` = single-model, bounded iterations. `medium` = multi-step or multi-agent fan-out. `high` = multi-model (cross-vendor) or N-parallel where N ≥ 5. `variable` = reserved for skills whose cost depends on input size (e.g., large file processing).
- **High-cost skills require an explicit user gate.** A `cost_class: high` skill must invoke `AskUserQuestion` (or an equivalent approval gate per P17) before spending. The user's approval is consent to cost, not just to behavior.
- **Default to the cheapest tier that meets the quality bar.** OMC's `haiku/sonnet/opus` tier variants are the template (§5.4). A reviewer persona that can run on Haiku should run on Haiku; escalation to Sonnet/Opus is explicit, not default.
- **Declare fan-out factor.** Any skill that dispatches N parallel sub-agents declares N (literal or computed) in its `<Use_When>` section. `N ≥ 5` is a hard gate; `N ≥ 10` requires multi-model adversarial pass (P11) or tier enforcement on sub-agents.
- **Budget, not promise.** Cost numbers are budgets (ceiling), not promises (floor). A skill may run cheaper than its `cost_class` suggests — that's fine. A skill that runs **more** expensive than its class is a bug.
- **No infinite loops.** P18 (stagnation detection) and AP16 (unbounded autonomy) already require max-iteration counts. P22 adds: max iterations must be multiplied by worst-case per-iteration cost to yield a declared budget ceiling for the whole skill.

### AP9. Over-Dispatching Subagents (Anthropic multi-agent)

*Anti-corollary of P22. Original location: former §3.*

> *"[Early agents] made errors like spawning 50 subagents for simple queries."*

The 4× token cost of multi-agent research is only worth it when breadth is actually needed. devbrew plugins should default to single-agent and justify fan-out case by case.

### P23. Versioning & Deprecation

*Serves L1, L2, L3:* version-as-contract is declared (L1); CHANGELOG entries are reviewable (L2); deprecation windows are institutional memory (L3).

Plugins evolve. The philosophy needs a shared vocabulary for compatibility:

- **SemVer for `.claude-plugin/plugin.json#version`:**
  - **Major** bump (X.0.0 → Y.0.0) — a breaking change to any public surface: removing a command/skill/agent, changing an agent's `allowedTools` in a way that removes capabilities, renaming the plugin, changing dependency version requirements in a backward-incompatible way, changing a kill-switch env var name.
  - **Minor** bump (X.Y.0 → X.(Y+1).0) — additive: a new command/skill/agent/hook, a new optional dependency, a new `cost_class` enhancement, a new persona file.
  - **Patch** bump (X.Y.Z → X.Y.(Z+1)) — fix: typo, prompt tightening, anti-example addition, bug fix in a hook script, persona checklist expansion that doesn't change the public contract.
- **Bump on every PR touching `plugins/<name>/`.** The SemVer rules above determine *which* version component bumps.
- **Deprecation window — one minor version.** When removing a public surface, first mark it deprecated in a minor version (with a warning in the skill/command description), then remove in the next major. A removal without a prior deprecation minor is a house violation.
- **CHANGELOG.md required for plugins at v1.0.0 and above.** Every plugin that reaches `1.0.0` ships a `CHANGELOG.md` at the plugin root with the entry format `## [version] — YYYY-MM-DD\n### Added/Changed/Deprecated/Removed/Fixed/Security`. Plugins below `1.0.0` are considered experimental; the house requirement starts at `1.0.0`.
- **Breaking changes annotated in CHANGELOG with a migration note** — not just the fact of the change but the minimal user action to adapt.

---

## 3. Anti-Corollaries  (formerly "Named Anti-Patterns")

Each anti-pattern (AP1–AP17) now lives as an *anti-corollary* nested under
the principle it negates (§2). For ID-level migration mapping, see §11.1.
Three patterns (AP10, AP11, AP17) are fully absorbed into their parent
principle's body and exist only as redirects in §11.1.

---

## 4. Primitives the Harness Must Provide (the shape of a devbrew plugin)

Applying the principles above, every plugin in `devbrew/plugins/*` should be structured around these primitives. Not every plugin needs every primitive — pick the ones that serve the plugin's purpose — but each primitive below has a single canonical shape.

### 4.0 Canonical Plugin Directory Structure  [Serves: L1, L2, L3]

Every plugin under `plugins/<name>/` uses this layout. Deviations must be justified in the plugin's README:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json         # REQUIRED: name, description, version; optional: author, license, repository, integrity
├── .mcp.json               # OPTIONAL: MCP server declarations
├── README.md               # REQUIRED: prerequisites, principles-instantiated, hooks-installed, kill-switches, cost_class summary
├── CHANGELOG.md            # REQUIRED from v1.0.0 onward (P23)
├── commands/               # OPTIONAL: short-imperative names (qg, review, commit)
│   └── <command>.md
├── skills/                 # OPTIONAL: gerund names (running-quality-gates)
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/     # OPTIONAL: deeper content loaded on demand (P6)
├── agents/                 # OPTIONAL: role-scoped with allowedTools/disallowedTools (P3)
│   └── <agent>.md
├── hooks/                  # OPTIONAL: harness enforcement (P13)
│   ├── hooks.json
│   └── <hook-name>.(py|sh|mjs)
├── scripts/                # OPTIONAL: helpers invoked by skills/hooks (not an abstraction layer — AP6)
├── templates/              # OPTIONAL: boilerplate the plugin generates into the user's repo
├── reviewers/              # OPTIONAL: persona files (P10) if this plugin provides a review library
│   └── <persona-name>.md
└── benchmarks/             # REQUIRED if any README claim is quantitative (P16)
    ├── fixtures/
    ├── ground-truth.json
    └── run.(py|sh)
```

**Rules of this layout:**

- No `src/` directory wrapping the plugin contents. The plugin *is* the directory; helper code lives directly under `scripts/` as flat files (AP6 — framework abstraction is forbidden).
- No `lib/` or `vendor/` — if a plugin needs a dependency, it either shells out to a globally-installed tool (with P19 graceful degradation) or vendors a single file with explicit attribution.
- No `.github/` inside the plugin directory — CI/CD concerns live at the devbrew repo root, not per plugin.
- `README.md` contains a mandatory "Principles Instantiated" section listing which of the 20+ principles this plugin embodies, with a one-line explanation each. This is the compounding substrate for Law 3: future-you can search all plugin READMEs for a principle and find every instantiation.

### 4.1 Spec Authoring (P1, P2)  [Serves: L1]

- A skill that authors a spec markdown file in a known location (proposed default: `docs/specs/YYYY-MM-DD-<topic>.md`, git-tracked — final convention is an open question; see §9).
- The skill has a structural baseline gate (P2 baseline). It refuses to exit until the gate is met.
- The skill's `<Steps>` include an adversarial self-review pass before exit (gstack Phase 5.5 + OMC ralplan Critic) — this is an enhancement over the baseline but strongly recommended.
- **Spec format — mandatory sections:**
  1. **Context/Why** — what problem this solves, who requested it, what the desired outcome is
  2. **Goals** — bulleted, measurable
  3. **Non-goals / Out-of-Scope** — explicit exclusions to prevent scope drift
  4. **Constraints** — language, deps, filesystem scope, performance budgets, time budgets
  5. **Acceptance Criteria** — numbered, checkable, independently verifiable
  6. **Files to Modify** — repo-relative paths, grouped by phase if multi-step
  7. **Verification Plan** — which of the three modalities (mechanical/semantic/runtime, P4) prove the ACs
  8. **Rejected Alternatives** — which approaches were considered and why they lost. At least one entry required; "none considered" is grounds for the adversarial review pass to reject the spec.
  9. **Metadata** — author, created date (ISO 8601), parent issue/PR link, spec version
- **Escape hatch:** trivia diffs bypass spec authoring entirely (see §2.1 / P12 canonical mention).

### 4.2 Plan Authoring (P1, P7, P12)  [Serves: L1]

- A skill that takes a spec and produces an implementation plan markdown file.
- The plan is *readable without the spec* (context is re-stated at the top).
- The plan has numbered, checkable steps and a verification section.
- The plan is approved via `ExitPlanMode` — the user gates on reading the file, not a chat summary.

### 4.3 Writer/Executor Agents (P3, P8)  [Serves: L2]

- Code-writing agents are named (`executor`, not `developer`), have `allowedTools` frontmatter scoping, and their system prompts begin with *"You are X. You are responsible for Y. You are NOT responsible for Z."*
- Executors do not approve their own work.
- Executors prefer **deletion over addition** when behavior is preserved.
- Executors keep diffs small, reversible, and scoped.

### 4.4 Reviewer Agents / Persona Library (P3, P10)  [Serves: L2]

- Review is decomposed into multiple persona-named files (`kieran-python-reviewer.md`, `security-sentinel.md`, `correctness-checker.md`).
- Each persona is a small, edit-able markdown file — bug-fixes grow the library by updating *one persona's checklist*.
- Reviews produce **structured findings** (severity, confidence 1–10, location, exploit/impact, recommended fix), and the dispatcher merges + dedupes them.
- Findings below a confidence threshold are suppressed to appendix (gstack: 7+ shown, 5–6 flagged, <5 suppressed).
- Critical failures are surfaced with "why this matters" context, not stack traces.
- **Verdict envelope (C20).** Every reviewer emits a top-level verdict in the form `APPROVE | REQUEST CHANGES | COMMENT` × `CRITICAL | HIGH | MEDIUM | LOW`. The dispatcher merges multi-reviewer envelopes into a single PR-level verdict using the most-severe rule.
- **Per-finding payload contract (C30).** Each individual finding inside a verdict has the JSON-shape: `{severity, confidence (1-10), path, line, category, summary, fix, fingerprint, specialist}`. Sentinel: `NO FINDINGS` when a reviewer has nothing to add. Confidence rubric for display: 9-10 show, 7-8 show, 5-6 caveat, 3-4 suppress to appendix, 1-2 P0-only.

### 4.5 Verifier (P4)  [Serves: L2]

- Verification produces evidence artifacts (log files, test output, screenshots) written to disk.
- The verifier has three tiers — mechanical, semantic, runtime — and runs them in order, short-circuiting on cheap failures.
- The verifier never infers success from "compiled without errors" alone. Runtime is load-bearing.

### 4.6 Compounding Skill (Law 3, P10)  [Serves: L3]

- A skill named `compounding-learnings` (gerund, per P6) that runs at the end of every cycle.
- The skill reads recent work (git diff, review findings, fix history), extracts root causes, and writes to a canonical learnings directory (destination is an open question; see §9) with YAML frontmatter.
- **Discoverability check:** the skill confirms the new learning is reachable from future sessions — either via `AGENTS.md` / `CLAUDE.md` references, or by being in a directory a relevant future skill scans. If not reachable, the skill auto-edits the index (CE pattern).
- The compounding step may update reviewer persona files directly (P10) — "this bug escaped because `security-sentinel.md` didn't check for input length caps; adding that check."
- **Architectural owner TBD** (§9): `compounding-learnings` may live as a standalone plugin (`plugins/compound/`), a shared skill imported by every plugin, or a terminal gate of `quality-gates`. This philosophy asserts the *principle* (Law 3) and the *primitive shape* (this section); the *ownership decision* is deferred to a subsequent planning round. Until resolved, plugins may implement a local `compound` step inline but must structure it as the primitive specified here so a future refactor can extract it cleanly.
- **3-point extraction gate (C3).** Before a learning is written to disk, the compounding skill applies a 3-point gate — all three required: (a) **Non-Googleable** — could a fresh reader find this in 5 minutes via Google? If yes, don't capture. (b) **Project-specific** — is this specific to THIS codebase / THIS team / THIS plugin? If no, don't capture. (c) **Hard-won** — did this take real debugging or design work to discover? If no, don't capture.
- **Wiki/index triad (C4).** OMC's pattern: every captured learning produces three artifacts — the learning itself, an index entry (in `AGENTS.md` / `CLAUDE.md` / a wiki), and a reverse pointer from the file the learning teaches about. The triad is what makes future-find work reliably.
- **Dual-lifetime memory tags (C25).** Each captured learning is tagged for one of two lifetimes: `task` (short-lived, deleted after the current branch merges) or `durable` (long-lived, survives indefinitely). The compounding skill prompts the writer to pick a lifetime explicitly, never defaults.
- **Grep-first learnings search (C69).** Future sessions discover prior learnings via `grep` on the canonical learnings directory + the indexes from C4. No embeddings, no vector store, no RAG. Acceptance: a future session searching for a relevant prior learning finds it via grep with recall ≥ 85% on a sampled benchmark.

### 4.7 Hook Layer (P13, P14, P16)  [Serves: L1, L2, L3]

- **SessionStart hook**: load plugin state from file, advise on pipeline status. Never mutates.
- **PreCompact hook**: snapshot critical in-context state to a file. Non-negotiable for plugins that carry state across turns.
- **PostToolUse hook**: for plugins that care about drift (Ouroboros' drift-monitor pattern), check spec-vs-code alignment after Write/Edit.
- **Stop hook**: for loop-bearing plugins, implement the state machine. This is exactly what `quality-gates` already does — generalize the pattern.
- **PreToolUse hook**: reserve for *validation*, not behavior injection. Block dangerous commands; don't silently rewrite arguments.
- Every hook has a kill switch (env var or settings.local.md flag) for debugging. OMC's `DISABLE_OMC=1` and `OMC_SKIP_HOOKS=name1,name2` are the templates.

### 4.8 State File (P5, P14)  [Serves: L3]

- State lives in `.claude/<plugin>.local.md` (markdown with YAML frontmatter), not JSON. Markdown because: human-editable, easy to diff, survives as a conversation record if ever committed.
- **Gitignore rule (enforced at repo root `.gitignore`):** `.claude/*.local.md` MUST be git-ignored across the entire devbrew repo. State files can contain paths, secrets-adjacent strings, branch names, PR URLs — not intended to be shared. Any plugin's setup script that creates a state file is responsible for verifying the gitignore line exists and adding it if missing.
- Frontmatter has the structured fields (step, iteration, last-verdict, etc.); body has the narrative (what happened, what's next).
- State files are auto-deleted on successful completion, preserved on failure for debugging.
- State files are the *only* durable inter-turn channel the harness is allowed to assume exists (P14).

### 4.9 Compose-Plugin Dispatch (P9)  [Serves: L1, L2, L3]

- When a plugin needs a capability another plugin provides, it dispatches via `subagent_type: "other-plugin:agent-name"` or invokes the other plugin's skill via Skill tool.
- The dependency is declared in the plugin's README Prerequisites table with the minimum-required plugin version.
- If the dependency is absent, the plugin degrades gracefully (P19) with a loud log (AP15).

### 4.10 Benchmark Suite (P16)  [Serves: L2]

- Any plugin that makes a quantitative claim ships `plugins/<name>/benchmarks/` with fixtures, ground-truth, scoring, and a runner.
- Benchmark output is checked into the repo (or cited in the README with the version it was produced from). OMC has the infrastructure but not the citation discipline; devbrew aims for both.

---

## 5. Philosophical Stance on Genuine Tensions

These are the places where the source harnesses disagree with each other, and where devbrew has to pick a side.

### 5.1 "Don't learn the tool" vs. "The tool is your interface"

OMC's tagline is *"Don't learn Claude Code. Just use OMC."* It hides the surface and prescribes a workflow. gstack takes the opposite stance: ETHOS.md and the compression table are *meant to be read*; the user is expected to internalize the philosophy. Anthropic's skill-authoring best practices implicitly side with gstack — skills should be *learnable*, descriptions should be *self-explanatory*, the agent should surface its reasoning.

**devbrew's pick:** gstack side. Philosophy is documented, principles are quotable, every plugin's README explains *why*. We want sophisticated users who understand what the harness is doing; we don't want a black box. The "zero learning curve" framing is a marketing trap that contradicts itself the moment something breaks.

### 5.2 "Never stop" vs. "Pause for user confirmation"

OMC's Sisyphus pattern refuses to stop until the verdict is pass. gstack and CE explicitly pause at every major step and wait for user input. Ouroboros is in the middle — pauses at spec-crystallization and at ambiguity gates, runs autonomously inside execution.

**devbrew's pick:** pause at *decision boundaries*, run autonomously *within a bounded decision*. The user approves the plan (`ExitPlanMode`), then the executor runs to verified-done without pausing for report. The user approves a PR, then `/qg` runs three gates without pausing between them. The user approves a spec, then the implementor runs until it has evidence. No "polite stop" (AP2), but also no unbounded autonomy without a user-gated starting point (AP16).

### 5.3 Numerical rigor vs. structural rigor

Ouroboros uses numerical gates (ambiguity, convergence). OMC and gstack use structural gates (mandatory sections, adversarial passes, checklists). Anthropic's writing is agnostic.

**devbrew's pick:** structural by default, numerical when the signal is strong. Numerical gates are seductive but brittle (the LLM that judges ambiguity is the same LLM that would generate an ambiguous spec — reproducibility ≠ correctness, Ouroboros' own weakness). Structural gates (mandatory sections, adversarial review passes, "cannot exit without ACs") are harder to Goodhart.

### 5.4 Role-scoped personas (gstack) vs. shared-pool agents (OMC)

gstack's roles are differentiated by `allowedTools` frontmatter and artifact conventions. OMC's 19 agents share most tools; differentiation is by prompt and model tier (haiku/sonnet/opus variants).

**devbrew's pick:** hard scoping (gstack side) for role separation, tier variants (OMC side) for capability-cost matching. A reviewer physically cannot write code; but a "small reviewer" and "big reviewer" variant can both exist, routed to cheaper/more-capable models based on what's being reviewed. The gstack `allowed-tools` mechanism is the enforcement; the OMC tier mechanism is the optimization. They're orthogonal.

### 5.5 "Boil the Lake" (gstack completeness) vs "Prefer Deletion" (OMC minimalism)

gstack's ETHOS says *"AI-assisted coding makes the marginal cost of completeness near-zero… do the complete thing every time."* OMC's AGENTS.md says *"Prefer deletion over addition when the same behavior can be preserved… the most common failure mode is doing too much, not too little."* These read as opposites.

**devbrew's pick:** *architectural* minimalism + *task-execution* completeness. When **building** — skip frameworks, skip abstractions, skip speculative generalization, delete unused code (OMC wins here). When **finishing a committed task** — don't skip the error path, the test, the edge case, the docs update, the CHANGELOG entry (gstack wins here). The two rules apply to different questions: "how much code should exist at all?" (minimalism) vs "given the code that does exist, how thoroughly should this task cover it?" (completeness). P8 encodes this as *"architectural simplicity, completion maximalism."*

### 5.6 "Zero hooks" (CE declarative) vs "Many hooks" (OMC enforcement)

CE ships the compound-engineering plugin with **zero hooks** on principle — the bet is that skills with declarative descriptions are strictly better than harness-level behavior injection because the agent can reason about when a skill applies. OMC ships **20 hooks** across 11 lifecycle events — the bet is that some behaviors (persistence, state preservation, prompt redirection) cannot be left to the agent's judgment and need harness-level enforcement.

**devbrew's pick:** hooks are the right tool **when and only when** trust in the agent is insufficient and the cost of forgetting is high. Specifically: PreCompact (state preservation — AP17), Stop (pipeline state machine — quality-gates), PreToolUse for validation (not behavior injection — see P13), SessionStart read-only advisors. For everything else — prefer skills with declarative triggers. This is CE's insight (hooks are coarse, skills are precise) applied at the category level rather than the plugin level. Plugins may install hooks but must justify each in the README's "Hooks Installed" section with a one-line "why this couldn't be a skill."

---

## 6. Attribution Map (every idea → where it came from)

This map makes compounding-on-attribution possible: if we learn a principle was wrong, we know which source to re-evaluate.

| Principle / Primitive | Primary source | Supporting source(s) |
|---|---|---|
| Clarity Before Code (Law 1) | Ouroboros | OMC deep-interview, gstack office-hours, CE ce-brainstorm, Anthropic plan mode |
| Writer/Reviewer Isolation (Law 2) | OMC execution_protocols | gstack allowed-tools, CE parallel review, Ouroboros 3-stage gate, Anthropic subagent pattern |
| Compounding Cycle (Law 3) | CE / Klaassen essays | OMC learner+wiki, gstack learnings.jsonl, Anthropic filesystem-as-memory |
| Ambiguity Gate (P2) | Ouroboros | OMC deep-interview dimensional scoring + C43+C44+C45+C51 (roadmap, 2026-05-06 absorption) |
| Tool Scoping (P3; AP11 absorbed) | gstack | OMC Delegation Enforcer hook |
| Verification Infrastructure (P4) | devbrew quality-gates / Anthropic | gstack /qa, OMC ultraqa, Ouroboros Stage-1 mechanical + C35 (roadmap, 2026-05-06 absorption) |
| Filesystem as Memory (P5, AP10) | Anthropic *Effective Context Engineering* | OMC .omc/, CE docs/solutions + C66 (roadmap, 2026-05-06 absorption) |
| Progressive Disclosure (P6) | Anthropic Skill Authoring Best Practices | CE skills-over-commands migration + C57 (roadmap, 2026-05-06 absorption) |
| Looping Cycles (P7) | CE Plan→Work→Review→Compound | OMC autopilot, Ouroboros inner/outer |
| Simplicity / Delete-over-Add (P8, AP6) | Anthropic *Building Effective Agents* | OMC AGENTS.md, gstack ETHOS |
| Composition over Monolith (P9) | devbrew quality-gates existing | implicit in all harnesses + C61 (roadmap, 2026-05-06 absorption) |
| Persona Pluralism (P10) | CE review personas | OMC code-reviewer tier variants + C19+C24+C31+C32+C42+C63 (roadmap, 2026-05-06 absorption) |
| Multi-Model Adversarial (P11) | gstack /codex | OMC ccg, Ouroboros consensus + C33+C52+C68 (roadmap, 2026-05-06 absorption) |
| Transparency of Planning (P12) | Anthropic *Building Effective Agents* | Claude Code plan mode + C34+C60 (roadmap, 2026-05-06 absorption) |
| Primitive Division of Labor (P13) | Anthropic plugin docs | CE skills-over-commands, OMC hook layering |
| State Survives Compaction (P14, AP17) | Anthropic *Effective Context Engineering* | OMC PreCompact hook |
| Initializer/Resumer (P15) | Anthropic *Effective Harnesses for Long-Running Agents* | OMC ralph, devbrew quality-gates stop-hook |
| Measurement (P16) | OMC benchmarks/ infrastructure | gstack confidence gating + C9+C54 (roadmap, 2026-05-06 absorption) |
| User Sovereignty (P17) | gstack ETHOS | Anthropic plan mode, Ouroboros Dialectic Rhythm Guard + C56 (roadmap, 2026-05-06 absorption) |
| Stagnation Detection (P18) | Ouroboros stagnated/unstuck | OMC ultraqa 3-repeat rule, OMC self-improve plateau + C46 (roadmap, 2026-05-06 absorption) |
| Graceful Degradation (P19) | OMC "never block on external tools" | — |
| Commit Trailer Protocol (P20) | OMC | — |
| Security & Supply Chain (P21) | devbrew own (synthesized from AP12, P10, §5.6) | Anthropic *Writing Effective Tools* (indirect) |
| Cost Awareness (P22) | OMC tier variants + gstack confidence gating + `ccg` decomposition | Anthropic *Multi-Agent Research System* (4× token cost warning) |
| Versioning & Deprecation (P23) | devbrew own; inherited from plugin.json cache-key requirement | SemVer |
| Tool Scoping Enforcement (AP11) | gstack `allowed-tools` | OMC Delegation Enforcer |
| Undeclared Plugin Dependency (AP12) | devbrew quality-gates existing | — |
| PRD Theater (AP1) | OMC | — |
| Polite Stop (AP2) | OMC | — |
| Self-Approval (AP3) | Law 2 corollary | OMC execution_protocols |
| LOC as Success Metric (AP4) | gstack public backlash | — |
| Trivia Pipeline Overhead (AP5) | Anthropic Claude Code Best Practices | — |
| Framework Abstraction in Prod (AP6) | Anthropic *Building Effective Agents* | OMC `run.cjs` cautionary tale |
| Vague Skill Names (AP7) | Anthropic skill-authoring best practices | — |
| Technical-Identifier Pollution (AP8) | Anthropic *Writing Effective Tools for AI Agents* | — |
| Over-Dispatching Subagents (AP9) | Anthropic *Multi-Agent Research System* | OMC subagent-tracker hook |
| Stale Pre-Built Indexes (AP10) | Anthropic *Effective Context Engineering* | — |
| Both-Models-Agree (AP13) | gstack ETHOS | — |
| Unchallenged Consensus (AP14) | Ouroboros convergence weakness + OMC ralplan steelman | — |
| Silent Fallback (AP15) | OMC weakness analysis (negative lesson) | — |
| Unbounded Autonomy (AP16) | OMC Sisyphus weakness (negative lesson) | gstack/CE/Ouroboros circuit breakers |
| Chat-Only State (AP17) | Anthropic PreCompact pattern + OMC notepad | — |

---

## 7. What This Philosophy Is NOT

Important to state the rejections explicitly so future design decisions don't drift into them.

- **Not an OMC clone.** devbrew rejects the monolith, the "don't learn it" framing, the hook-coupled Node runtime, the always-on autonomy, the tight coupling to undocumented CC internals.
- **Not a gstack clone.** devbrew rejects the role marketing ("CEO, Designer, Eng Manager…"), LOC metrics, the multi-host compile target (devbrew targets Claude Code first, other hosts via separate work if ever).
- **Not an Ouroboros clone.** devbrew rejects numerical-gates-as-only-mechanism, the heavy MCP runtime dependency, the lack of a trivia escape hatch, the "stop prompting" absolutism. devbrew keeps the "specify first" thesis and the event-store-as-state idea.
- **Not a CE clone.** devbrew adopts the skills-over-commands stance and the compounding discipline, but rejects the hook-avoidance (CE ships zero hooks — devbrew considers hooks the right tool for enforcement; see P13) and won't target 11 other harnesses (single-target discipline).
- **Not a "framework."** No DSLs, no code-generating configs, no class hierarchies wrapping Claude Code primitives. The plugin's files ARE the interface (AP6).
- **Not autonomous in the Sisyphus sense.** User approves at decision boundaries; inside a bounded decision, the harness runs hard. But "never stop" is rejected.

---

## 8. Tagline & North-Star Candidates

Four candidates were considered; the first is the adopted tagline.

1. ***"Specify before you code. Review before you ship. Compound before you forget."*** ← **Adopted.** Three-beat imperative that maps 1:1 onto the Three Laws. Memorable, quotable, prescriptive.
2. *"The bottleneck is not the model. It's the spec, the review, and the memory. devbrew's job is to fix all three without the user having to remember to."* ← Used as the secondary thesis sentence under the tagline in CLAUDE.md. Diagnostic rather than prescriptive.
3. *"devbrew plugins discipline the input, isolate the reviewer, and compound the memory. Everything else is negotiable."*
4. *"A good devbrew plugin knows what it's allowed to do, what it's forbidden from doing, and where its learnings go. If any of those three are missing, it isn't ready to ship."*

---

## 9. Roadmap: Open Questions for Future Rounds

These are the places this philosophy is intentionally silent. Each is a real design choice for a subsequent planning round, not a gap to paper over.

1. **Granularity of devbrew's ambiguity gate.** Does every plugin adopt the same mechanism (structural baseline + optional adversarial), or is per-plugin variation allowed beyond that?
2. **Who owns the compound step?** Is `compounding-learnings` a plugin of its own (`devbrew/compound`), a skill inside `quality-gates`, or a shared skill imported by every plugin? The CE model (skill-per-plugin) vs the devbrew shared-skill model has real trade-offs.
3. **Persona library hosting.** If devbrew adopts the CE persona-pluralism pattern, where do the persona files live? In a `code-review` plugin? In a dedicated `review-personas` plugin? In each domain-specific plugin (e.g., `frontend-design` ships its own frontend reviewers)?
4. **Spec directory convention.** Ouroboros uses `~/.ouroboros/seeds/` (global), OMC uses `.omc/plans/` (project-local), CE uses `docs/plans/` (project-local, git-tracked). What's devbrew's canonical spec directory? Git-tracked vs gitignored?
5. **Compounding destination.** `docs/solutions/` (CE), `docs/learnings/` (proposed), `MEMORY.md` index (auto-memory style), or a plugin-local `<plugin>/learnings/`? The Discoverability Check needs a consistent destination to edit.
6. **Multi-model gate scope.** Which decisions are "irreversible enough" to trigger the multi-model adversarial layer? Spec mutation (Ouroboros's answer), production deploy, merge to main, architectural commitments — or only the first one for now?
7. **Stop-condition defaults.** For loop-bearing plugins, what are the default limits — max iterations, wall-clock, repeat-detection window? `quality-gates` currently uses `MAX_TOTAL_ITERATIONS=5`, `MAX_GATE2_ITERATIONS=5`. Is that the house default?
8. **Plan-mode integration depth.** Does every devbrew plugin invoke `ExitPlanMode` for its plan step, or do plugins opt in?
9. **Benchmark culture.** Do all plugins ship benchmarks from v1.0, or only those making quantitative claims?
10. **Rollout path.** Does the existing `quality-gates` plugin get retrofit to this philosophy, or do we leave it as-is and hold new plugins to the standard? Retrofit risks thrashing a working plugin; holding two standards risks the philosophy being "for new stuff only" and drifting.

---

## 10. How This Doc Evolves

This philosophy is versioned alongside the repo. New principles, anti-patterns, and primitives can be added when the ecosystem produces evidence they're needed. Existing principles can be *revised* with a dated note but should not be silently removed — removal is a breaking change to every plugin that cites them in its README's "Principles Instantiated" section.

Cadence of subsequent planning rounds:

- **Round N+1 — Primitives specification.** Formalize §4 into concrete file templates. Define the spec format, the plan format, the state-file schema, the review-finding JSON shape, the commit trailer grammar. Answers §9 Q4 (spec directory) and Q5 (compounding destination).
- **Round N+2 — Plugin shape exemplar.** Apply the philosophy to a worked example — pick one proposed plugin (spec-authoring, persona-review, or compound) and fully design it so we can test the philosophy against a real target. Answers §9 Q2 and Q3 in the context of that exemplar.
- **Round N+3 — Retrofit plan for quality-gates and project-init.** Decide which parts of the philosophy the existing plugins adopt in their next minor version bump. Answers §9 Q10.
- **Round N+4 — Compounding step design.** The single highest-leverage primitive; deserves its own planning round. Finalizes §9 Q2 architecturally if Round N+2 didn't already.

---

## 11. Migration Table — 2026-05-06 Restructure

This table records the 2026-05-06 restructure that reorganized §2 around the Three Laws and absorbed roadmap candidates. Redirects are permanent (one row per moved/absorbed ID).

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
- **§4.6 Compounding Skill** absorbs C3 (3-point extraction gate: non-Googleable / project-specific / hard-won — all three required) + C4 (wiki/index triad pattern from OMC) + C25 (dual-lifetime memory tags: short-lived `task` vs durable `durable`) + C69 (grep-first learnings search; no embeddings, no vector store; recall ≥ 85% acceptance criterion). Law 3 corollary tightened to point at §4.6 for the discoverability mechanism.

### 11.4 Roadmap C# Disposition (53 Go candidates)

| Bucket | Count | Items |
|---|---|---|
| Folded into existing P expansions (per §11.2) | 23 | C9, C19, C24, C31, C32, C33, C34, C35, C42, C43, C44, C45, C46, C51, C52 (a+b), C54, C56, C57, C60, C61, C63, C66, C68 |
| Folded into §4 primitive expansions (per §11.3) | 6 | C3, C4, C25, C69 → §4.6 ; C20, C30 → §4.4 |
| Already covered by existing P / primitive (no doc change) | 17 | C1→P2, C2→P3, C5→P14, C6→P4, C7→P18, C10→§4.2, C11→P13+P21, C12→P13, C14→P3+§4.3, C15→P20, C28→P9, C41→P21, C49→P14+P23, C50→P19, C55→§4.1+P1, C59→P7, C65→P14+§4.8 |
| Operational detail / convention (no doc change) | 7 | C22, C27, C36, C53, C58, C64, C67 |
| **Sum** | **53** | ✓ matches roadmap "53 Go" |

**Parked / Killed (out of scope — reference only):** C8, C16, C17, C18, C21, C23, C26, C29, C37, C38, C39, C40, C47, C62 (Park); C13, C48 (Kill).

---

## Appendix A — Direct Quotes Preserved

Load-bearing quotes, kept verbatim so future rounds can cite them without re-fetching:

**Ouroboros (Korean README):**

> *"AI는 무엇이든 만들 수 있다. 어려운 건 무엇을 만들어야 하는지 아는 것이다."* — AI can build anything. The hard part is knowing what to build.
>
> *"Ouroboros는 기계가 아닌 인간을 바로잡습니다."* — Ouroboros fixes the human, not the machine.
>
> *"Do not build until you are clear (Ambiguity ≤ 0.2), do not stop evolving until you are stable (Similarity ≥ 0.95)."*
>
> *"When you answer 'What IS a task?' — deletable or archivable? solo or team? — you eliminate an entire class of rework. The ontological question is the most practical question."*

**OMC:**

> *"Don't learn Claude Code. Just use OMC."* ("Claude Code를 배우지 마세요. 그냥 OMC를 쓰세요.") [rejected as devbrew tagline; kept as a diagnostic — the framing is a trap]
>
> *"Keep authoring and review as separate passes… Never self-approve in the same active context."*
>
> *"A false approval costs 10-100x more than a false rejection."* — agents/critic.md
>
> *"Prefer deletion over addition when the same behavior can be preserved."* — AGENTS.md
>
> *"Could someone Google this in 5 minutes? → NO / Is this specific to THIS codebase? → YES / Did this take real debugging effort to discover? → YES."* — learner quality gate, all three must be true

**gstack ETHOS:**

> *"AI-assisted coding makes the marginal cost of completeness near-zero. When the complete implementation costs minutes more than the shortcut — do the complete thing. Every time."*
>
> *"AI models recommend. Users decide. This is the one rule that overrides all others."*
>
> *"Anti-pattern: 'Both models agree, so this must be correct.' (Agreement is signal, not proof.)"*
>
> *"Cognitive gearing: forcing a large language model into distinct roles to simulate a high-functioning software team's workflow."* — Epsilla writeup

**Compound-Engineering (Klaassen essays):**

> *"Compounding engineering is about building systems with memory, where every pull request teaches the system, every bug becomes a permanent lesson, and every code review updates the defaults. AI engineering makes you faster today. Compounding engineering makes you faster tomorrow, and each day after."*
>
> *"The fastest way to teach is not through code you write, but through plans you review."*
>
> *"We forgot to retry once. The system won't let us forget again."*

**Anthropic Engineering:**

> *"Maintain simplicity in your agent's design."* — *Building Effective Agents*
>
> *"Find the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."* — *Effective Context Engineering*
>
> *"Rather than pre-processing all relevant data up front, agents built with the 'just in time' approach maintain lightweight identifiers […] and use these references to dynamically load data into context at runtime."* — *Effective Context Engineering*
>
> *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* — *Claude Code Best Practices*
>
> *"If you could describe the diff in one sentence, skip the plan."* — *Claude Code Best Practices*
>
> *"Prioritize transparency by explicitly showing the agent's planning steps."* — *Building Effective Agents*
>
> *"Initializer agent: The very first agent session uses a specialized prompt that asks the model to set up the initial environment […] Coding agent: Every subsequent session asks the model to make incremental progress, then leave structured updates."* — *Effective Harnesses for Long-Running Agents*
