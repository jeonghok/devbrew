# CLAUDE.md

> **Specify before you code. Review before you ship. Compound before you forget.**
>
> *The bottleneck is not the model. It's the spec, the review, and the memory. devbrew's job is to fix all three without the user having to remember to.*

devbrew is a plugin marketplace for Claude Code. Every plugin under `plugins/*` inherits the principles below. The full philosophy — attribution, 23 principles, 17 anti-patterns, direct quotes from the source harnesses (oh-my-claudecode, gstack, ouroboros, compound-engineering) and Anthropic's engineering writing — lives at [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md). This file is the preloaded context anchor: invariants, checklists, and pointers — nothing that belongs in the philosophy doc.

> **New here?** Building a plugin → [§Building a New Plugin](#building-a-new-plugin). Reviewing code → [§The Three Laws](#the-three-laws) and [§Forbidden Patterns](#forbidden-patterns). Want the reasoning → the [philosophy doc](docs/philosophy/devbrew-harness-philosophy.md).

## The Three Laws

**Law 1 — Clarity Before Code.** No implementation proceeds while the spec is ambiguous. Every plugin that ships code must have a real refusal mechanism — at minimum a **structural gate** (mandatory sections: Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata) that the plugin cannot silently skip. Adversarial self-review is strongly recommended on top; numerical scoring is discouraged (philosophy §5.3). *Trivia escape:* changes whose **diff can be described in one sentence** (Anthropic, *Claude Code Best Practices*) bypass the gate — typos, renames, comment-only edits, single-file formatting. Anything multi-file or behavior-changing goes through.

**Law 2 — Writer and Reviewer Must Never Share a Pass.** The same turn that writes code may not approve it. Isolation is physical, not prompted: use `allowed-tools` / `disallowed-tools` frontmatter so a reviewer literally cannot `Write`/`Edit`. A reviewer with write access is not a reviewer. Verification is load-bearing infrastructure, not an afterthought.

**Law 3 — Every Cycle Must Leave the System Smarter.** Compounding is a named step with a discoverability check, not an optional wrap-up. When a cycle produces a lesson, the harness captures it to a file AND verifies the next session will actually find it — auto-editing the index (`AGENTS.md`/`CLAUDE.md`) when discoverability is at risk. Writing to a file no future agent reads is theater.

*Hierarchy:* Law N overrides Law N+1 on conflict. Clarity first, independence second, compounding third.

## Plugin Shape

Every plugin in `plugins/*` follows the canonical directory structure in [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §4.0 and satisfies all of the following. Deep corollaries and "why" live in philosophy §4 / §P1–P23.

- **`plugin.json` with SemVer bump on every PR.** Required: `name`, `description`, `version`. Bump on every plugin-touching PR (major = breaking, minor = new surface, patch = fix) or cache keys silently stale. Security-critical deps: pin via optional `integrity` field.
- **`CHANGELOG.md` once version ≥ v1.0.0.** `## [version] — YYYY-MM-DD` with Added/Changed/Deprecated/Removed/Fixed/Security. One-minor deprecation window before removal.
- **`README.md` lists "Principles Instantiated"** — which philosophy laws/principles this plugin embodies, one line each. Compounding substrate for Law 3: future search finds every instantiation.
- **Scoped agents — no default-everything.** Every agent declares `allowedTools`/`disallowedTools`. Role prompts begin with *"You are X. You are responsible for Y. You are NOT responsible for Z."* A reviewer with `Write` is a Law 2 violation.
- **Declared dependencies with min versions.** Dispatching `other-plugin:agent` without listing `other-plugin` in README prerequisites is silent coupling.
- **`cost_class` declared for every skill** (`low`|`medium`|`high`|`variable`). `high` must invoke an explicit `AskUserQuestion` approval gate before spending. Fan-out factor N ≥ 5 is a hard review gate.
- **Markdown state, not JSON.** State lives in `.claude/<plugin>.local.md` (git-ignored, auto-deleted on success, preserved on failure). **Never write secrets** — use placeholder references (philosophy P21).
- **Kill switches on every hook.** `DEVBREW_DISABLE_<PLUGIN>=1` or `DEVBREW_SKIP_HOOKS=<plugin>:<hook>`. No hook may refuse to honor its kill switch — kill switches are security controls.
- **Hook coexistence.** Hooks must be commutative within one event. Signal tags use `<{plugin}-signal>` namespace. `SessionStart` hooks are read-only advisors, never mutate. Each hook documented in README's "Hooks Installed" with a one-line "why not a skill?" justification.
- **Progressive disclosure.** Skill names are gerunds (`running-quality-gates`, `authoring-specs`); command names are short imperatives (`qg`, `review`). No vague names (`helper`, `utils`, `"I can help you..."`).
- **Graceful degradation with loud logging.** Missing optional deps downgrade capability, not crash — and the user must be able to tell from output that a fallback ran.
- **Persona files are security-sensitive code.** PRs that weaken a reviewer persona (remove a rule, relax a threshold) are flagged for security review. Treat persona edits like test-suite edits.

## Building a New Plugin

**Starter directory tree** — `.claude-plugin/` and `README.md` are required; every other subdir is optional and only added when the plugin ships that surface:

```
plugins/<your-plugin>/
├── .claude-plugin/
│   └── plugin.json           # required — name, version (start 0.1.0), description
├── README.md                 # required — must list "Principles Instantiated"
├── CHANGELOG.md              # required once version ≥ v1.0.0
├── commands/                 # optional — short imperatives: qg.md, review.md
├── skills/<gerund-name>/     # optional — running-x, authoring-y (gerunds)
│   └── SKILL.md              # declares cost_class, frontmatter triggers
├── agents/                   # optional — each declares allowedTools/disallowedTools
├── hooks/                    # optional — each with DEVBREW_DISABLE_<PLUGIN>=1 opt-out
├── scripts/                  # optional — shell/python helpers called by hooks
└── templates/                # optional — static files the plugin installs
```

**Reference implementations** — read the one that matches your plugin's shape:

- [`plugins/quality-gates/`](plugins/quality-gates/) — **writer + reviewer + hook pipeline**. Embodies Laws 1–2 via 3-gate `allowedTools`/`disallowedTools` isolation. Ships `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`.
- [`plugins/project-init/`](plugins/project-init/) — **git-workflow enforcement**. Embodies Law 3 via compounding hooks and branching-strategy templates. Ships `commands/`, `hooks/`, `templates/`. No `agents/` or `skills/` — a hooks-and-templates plugin is a valid shape.

**First-plugin checklist** (every box before merge):

- [ ] `plugin.json` has `name`, `version`, `description` (start at `0.1.0`)
- [ ] `README.md` has a "Principles Instantiated" section citing laws/principles by number
- [ ] Every agent declares `allowedTools`/`disallowedTools` — no default-everything
- [ ] Every skill declares `cost_class`
- [ ] Every hook has a `DEVBREW_DISABLE_<PLUGIN>=1` kill switch
- [ ] `CHANGELOG.md` exists if version ≥ v1.0.0
- [ ] `*.ko.md` Korean companion exists for every user-facing doc (full parity, not summary)

Full plugin primitives reference: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §4.

## Forbidden Patterns

Full catalog with case studies: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) §2 (each principle's anti-corollary) + §11.1 (ID migration). Cite by name in reviews. The five that fire most often in this repo:

- **Self-approval** — writer and reviewer in the same turn (Law 2 violation).
- **Polite stop** — narrating a summary after a positive review instead of proceeding to the next action. Distinct from an approval gate: a gate lets the user redirect; a polite stop only lets them acknowledge.
- **Trivia ceremony** — running the full pipeline on a one-sentence diff (Anthropic *Best Practices*).
- **Subagent spray** — fan-out ≥ 5 without declared justification; default to single-agent.
- **Unbounded autonomy** — a loop without max-iter count, wall-clock budget, repeat detection, and user-override kill switch.

## Git Workflow

GitHub Flow. Branch from `main`, merge back via PR. Details in [`docs/git-workflow/`](docs/git-workflow/).

- Branch: `feature/*` or `fix/*` from `main`. Kebab-case, 2-4 words.
- Commit: Conventional Commits (`<type>(<scope>): <description>`).
- PR: squash merge. See [`docs/git-workflow/pr-process.md`](docs/git-workflow/pr-process.md).
- `project-init` plugin auto-validates branch naming and commit format.
- Prefer `git merge` over `git rebase` when updating feature branches from `main`.
- Default `gh pr merge --squash --delete-branch`; force-delete local branch after squash merge.

## When Editing This Repo

- **Bump plugin version** on every PR that touches `plugins/<name>/`.
- **Korean parity, no drift.** `CLAUDE.md` and `docs/philosophy/*.md` are authored in English as canonical. Every `*.ko.md` companion has **full content parity** — not summaries, not glosses. Update English and Korean in the same PR. A PR that updates one without the other is rejected.
- **New plugins cite which philosophy principles they instantiate** in their README (e.g., *"Implements Laws 1 and 2 via gate-based pipeline dispatch"*).
- **When a bug escapes review**, the fix is to edit the reviewer persona file that should have caught it, not just patch the code. That commit is the compounding event (Law 3).

## References

- [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md) — full philosophy: 23 principles, 17 anti-patterns, 10 primitives, 6 tensions with picks, attribution map, direct quotes preserved verbatim.
- [`docs/philosophy/devbrew-harness-philosophy.ko.md`](docs/philosophy/devbrew-harness-philosophy.ko.md) — Korean companion.
- [`docs/git-workflow/`](docs/git-workflow/) — branching, commits, PR process.
- [`plugins/quality-gates/README.md`](plugins/quality-gates/README.md) — reference implementation of Laws 1–2 via a 3-gate pipeline that dispatches to pr-review-toolkit, feature-dev, and superpowers agents.
- [`plugins/project-init/README.md`](plugins/project-init/README.md) — git-workflow enforcement and branch/commit validation.
