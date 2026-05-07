# Changelog

All notable changes to the `project-init` plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] — 2026-05-07

Same-day patch correcting v1.2.0 template defaults — intentional duplicate date.

### Changed
- `templates/github-flow/branch-strategy.md` and `templates/git-flow/branch-strategy.md` now default to `git merge` for syncing a feature branch with its base. New "Rules for Claude" line cites the *"rebase golden rule"* (Pro Git §3.6 *"Rebasing"*) — rebase rewrites history and is unsafe on any pushed branch. Strict variant chosen (always merge, never rebase) for one-line teachability and force-push safety on local branches.

### Removed
- Andrej Karpathy attribution blockquote (`> Andrej Karpathy의 [LLM 코딩 관찰]...`) is no longer injected into the target project's `CLAUDE.md`. The 4-bullet baseline is unchanged. Attribution preserved at the plugin layer (README, plugin.json description, slash-command confirmation, this changelog) — the directive applies only to the target project's LLM-context anchor.

## [1.2.0] — 2026-05-07

### Added
- `## LLM Coding Guidelines` section injected into target CLAUDE.md alongside `## Git Workflow`. Hybrid format (English headers + Korean explainers), 4 lines compressed from Andrej Karpathy's LLM coding observations.
- New shared template `templates/shared/llm-guidelines.md`.
- README "Principles Instantiated" section citing Law 1 (Clarity Before Code).
- This `CHANGELOG.md` (devbrew rule recovery — was missing for v1.1.0).

### Changed
- `commands/project-init.md` Step 4 now reads and prepends the LLM Guidelines section before the strategy section. Step 5 confirmation lists the new section.
- `plugin.json` description updated to reflect dual-purpose initialization.
- `commands/project-init.md` Step 4c expanded from single-section logic to a 4-state matrix that manages `## LLM Coding Guidelines` and `## Git Workflow` as a contiguous block while preserving all non-managed content.

## [1.1.0] — 2026-04-12

### Added
- Initial public release with three branching strategies: GitHub Flow, Git Flow, Trunk-based.
- `/project-init` interactive command for selecting a strategy and generating CLAUDE.md + `docs/git-workflow/` files.
- PostToolUse hook validating branch naming and Conventional Commits format.
- Templates: shared `commit-conventions.md` and `pr-process.md`; per-strategy `claude-md-section.md` and `branch-strategy.md`.
