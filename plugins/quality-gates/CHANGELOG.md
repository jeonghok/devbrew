# 변경 로그

`quality-gates` 플러그인의 주요 변경 사항을 기록합니다.
포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 버전 규칙은 [SemVer](https://semver.org/spec/v2.0.0.html)를 따릅니다.

## [1.14.0] — 2026-05-16

### Added
- State file schema field `project_dir` (frontmatter) — single pipeline coordinate frozen at preflight (AC6, B6 fix).
- `project_dir` input contract on 6 Gate-2 agents: scout, codex-reviewer, adversarial, synthesizer, test-scope-validator, security-reviewer (AC2).
- `tests/test_hook_cwd_contract.py` — payload cwd contract for post-tool-use-session-tracker and session-start-advisor.
- `tests/test_worktree.sh` T5/T6/T7/T8/T9 — regression guards for SKILL dispatch, hook AST, codex-reviewer plugin paths, agent.md drift, state schema.
- `tests/test_codex_dispatch_invariant.sh` Scenario 4 — anchor-then-window awk for Pattern-P and Pattern-L dispatch blocks.

### Changed
- `hooks/stop-hook.py`: removed module-level `ROOT` constant; introduced `_state_root(hook_input)` helper deriving state path from payload cwd. `state_file_for(session_id, hook_input)` signature updated.
- `hooks/stop-hook.py:build_gate_prompt()`: all 3 gate branches now inject `project_dir: {state["project_dir"]}` into continuation prompts, ensuring gate-boundary cwd persistence.
- `hooks/stop-hook.py:parse_state_file()`: surfaces `project_dir` with v1.13.x backward-compat fallback (`os.getcwd()` + stderr warning, mirroring `gate3_resolution_iter` pattern at L114-120).
- `hooks/post-tool-use-session-tracker.py`: state path and `abs_path` resolution base both derived from payload cwd.
- `hooks/session-start-advisor.py`: `_scan_agent_frontmatter_keys` now takes payload arg and derives `repo_root` from payload cwd instead of `Path.cwd()`.
- `agents/codex-reviewer.md`: bash block guards empty `project_dir`, `cd "$project_dir"`, `REPO_ROOT="$project_dir"` (no more `git rev-parse`); plugin scripts called via `${CLAUDE_PLUGIN_ROOT}/scripts/` instead of `$REPO_ROOT/plugins/quality-gates/scripts/` (which only existed in devbrew's self-test).
- `skills/quality-pipeline/SKILL.md`: 4 Pattern-P dispatch blocks (scout/adversarial/synthesizer/test-scope-validator) and 1 Pattern-L block (Agent D security-reviewer) now declare `project_dir: <current working directory>` in their prompts.

### Fixed
- **B1**: stop-hook.py `ROOT` constant relative-path bug — state file path now derived from payload cwd (worktree-safe).
- **B2**: post-tool-use-session-tracker.py `Path(".claude/quality-gates")` relative bug + `abs_path` resolution against wrong base.
- **B3**: session-start-advisor.py `Path.cwd()` worktree blindness.
- **B4**: SKILL.md missing `project_dir` in dispatches to scout/codex-reviewer/adversarial/synthesizer/test-scope-validator/security-reviewer.
- **B5**: codex-reviewer.md (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` path broken outside devbrew, (b) missing `cd "$project_dir"` causing subprocess cwd nondeterminism.
- **B6**: state file schema lacked `project_dir`; stop-hook `build_gate_prompt()` never propagated it across gate boundaries — caused gate2/3 continuations to re-evaluate cwd in main repo when pipeline was launched from worktree.
- **B3 completion**: session-start-advisor primary advisory path (sibling-count + self-pipeline check) now derives state root from payload cwd, matching the frontmatter-scan sub-feature fix.
- **B7 (new)**: session-end-cleanup.py removed module-level relative ROOT; per-session folder cleanup now anchored to payload cwd, eliminating silent state-leak when session ends with process-cwd different from worktree.

### Upgrade notes
- In-flight v1.13.x pipelines: state file lacks `project_dir`; `parse_state_file()` falls back to `os.getcwd()` + stderr warning. If your continuation is running from a worktree, expect one warning per gate transition. For clean state, run `/cancel-qg && /qg` after upgrade.
- No state-file format break: v1.13.x state files remain readable; v1.14.0 state files have one additional `project_dir:` line that older code would simply ignore.

## [1.13.0] — 2026-05-16

### Added

- **Phase 1 always-run `security-reviewer` agent.** Code-level security review now runs on every Gate 2 invocation (all 3 depth tiers: quick / standard / deep). Hunts injection, authn/authz bypass, secrets, SSRF + path traversal, insecure deserialization, cryptographic misuse, raw-HTML escape hatches, and dependency manifest changes. Emits canonical finding YAML schema (`adversarial.md:22-30`). Persona declares `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` for Law 2 physical isolation; `cost_class: medium`; `model: inherit`.
- **Kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`.** Mirrors codex-reviewer's `DEVBREW_DISABLE_QG_CODEX` pattern. Loud-logging graceful degradation: stderr emits `security-reviewer disabled via DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` on activation; other Phase 1 reviewers continue to run.
- **Structural tests.** `tests/test_security_reviewer_persona.sh` (frontmatter + schema keyword + role declaration grep) and `tests/test_security_reviewer_kill_switch.sh` (SKILL.md kill switch reference grep).
- **Integration smoke fixtures.** `tests/fixtures/security-reviewer/{sql-concat,clean,expected}/` — opt-in, CI-non-blocking (LLM non-determinism).

### Changed

- **Phase 1 dispatch fan-out.** Phase 1 catalog grows by 1 (now: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer + conditional codex-reviewer). On `deep` depth with codex-reviewer available, `phase1_agents = 4` + `external_reviewers = 1` = 5, exceeding the AskUserQuestion fan-out gate (≥ 4) — users see an explicit confirm before parallel dispatch.
- **Synthesizer suppression rule (`synthesizer.md` step 4).** Was: "Suppress entries where confidence < 7." Now: "Suppress entries where confidence < 7 AND severity != CRITICAL." Honors spec §4.4 "P0 + anchor 50 always reports" — a critical-impact finding surfaces even at low confidence. Applies to all Phase 1 reviewers (not just security-reviewer). Output section label updated to `### Suppressed (confidence < 7, severity != CRITICAL)`.

### Security

- New `security-reviewer` persona file is security-sensitive code per CLAUDE.md ("Persona 파일은 보안-민감 코드"). PRs weakening hunt categories, lowering anchored confidence rubric, or removing the forced-findings prohibition rule require security review.

## [1.12.0] — 2026-05-14

### Added

- `tests/test_agent_frontmatter_keys.sh` — repo-wide agent frontmatter convention deny-list (AC15).
- `hooks/session-start-advisor.py` 에 frontmatter scan sub-feature 확장 + `_subfeature_disabled()` helper (AC14).
- `tests/test_consent_marker_write_failure.sh` (AC11 검증).
- `tests/test_codex_dispatch_invariant.sh` scenario 3 (AC13 fallback).
- `tests/fixtures/codex_findings_dict_input.json`, `codex_findings_string_input.json`, `codex_two_fenced_blocks.json` (AC9 fixtures).

### Changed

- `scripts/detect_codex.sh` — `codex --version` 호출을 `timeout 5` 로 래핑. 7번째 case `skip_reason: timeout_binary_missing` 추가 (AC7).
- `agents/codex-reviewer.md` agent body — TIMEOUT_CMD/REPO_ROOT empty 검사 + prompt builder exit-code 검사 (AC8/AC10).
- `README.md` — 디렉토리 트리에 codex 관련 4파일 추가, Gate 2 stage diagram에 codex-reviewer 노드, Fan-out 11→12, Principles Instantiated에 Law 2/Law 3 instantiation (AC16).
- `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` — 스크립트 파일명 dashes → underscores (AC17).

### Fixed

- `scripts/codex_findings_to_yaml.py`:
  - non-list findings → `meta.reason: schema_mismatch` + `meta.raw_findings_type` surface (silent coerce 종료) (AC9a).
  - `parse_fenced_json` last block 선택 (prompt injection 차단) (AC9b).
  - `AUTH_ERROR_RE` 확장: 401/403/forbidden/quota/expired 등 (AC9c).
  - stderr 읽기 실패 시 `meta.stderr_read_error: <errno>` (AC9d).
- `skills/quality-pipeline/SKILL.md`:
  - cost consent marker write 실패 시 stderr 메시지 — fenced bash block + `# QG-CONSENT-MARKER-WRITE` 식별 주석으로 V14가 추출 검증 가능 (AC11).
  - detect_codex.sh manifest schema validation (AC12).
  - scout-fallback 분기에서도 codex 가용 + consent 시 codex-reviewer dispatch + 명시적 stderr 메시지 (AC13).

### Notes

- Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC7–AC19).
- Audit: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md`.
- Law 2 instantiation: 3-layer reviewer-writer isolation (codex-reviewer)가 v1.11.1에서 복구된 후 v1.12.0에서 schema/auth/timeout 안전성 추가.
- Law 3 instantiation: agent frontmatter convention drift 재발을 차단하는 compounding mechanism (advisor + bash test) 신설.

## [1.11.1] — 2026-05-14

### Fixed

- `agents/codex-reviewer.md` frontmatter key를 `allowed-tools` (kebab-case) → `allowedTools` (camelCase) 로 수정. v1.11.0에서 Layer 2 isolation (narrow Bash whitelist)이 잘못된 키 때문에 실질적으로 비활성이었음. `tests/test_codex_reviewer_frontmatter.sh` 도 같은 잘못된 키를 검사하던 4 occurrences를 함께 수정.
- `agents/scout.md`에서 codex-reviewer dispatch instruction 제거. v1.11.0에서 scout이 `phase1_agents`에 codex-reviewer를 추가하면 SKILL.md validation FAIL → scout-fallback → codex-reviewer silently dropped 상태였음. dispatch 단일 진실은 SKILL.md로 이동 (manifest 가용성 + consent 기반).
- `skills/quality-pipeline/SKILL.md` Phase 1 dispatch logic: codex 가용 + consent OK 시 codex-reviewer를 in-process subagent 3개와 parallel dispatch에 무조건 포함. codex 미가용 시 v1.10.x byte-equivalent 3-agent dispatch 유지.

### Security

- 3-layer reviewer-writer isolation의 Layer 2 (`allowedTools` deny-list/allow-list narrow whitelist) 복구. v1.11.0의 광고된 보안 보장이 실제로 작동 시작.

### Notes

**SemVer 분류 근거**: v1.11.0의 codex-reviewer dispatch는 C1+C2 결함으로 인해 production에서 실제로 작동하지 않았음 — 본 PR의 "scout codex emit 제거"는 SemVer 의미상 "deprecation of never-working behavior" 이므로 backward-incompatible 변경 아님. devbrew CLAUDE.md "one-minor deprecation window" 요건은 본 케이스에 적용되지 않음.

Audit findings: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md` (C1, C2, I-부분).
Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC1–AC6).

## [1.11.0] — 2026-05-14

### Added

- `codex-reviewer` agent: independent code reviewer dispatched as a separate process via `codex exec --json -s read-only` when Codex CLI is detected. Adds OS-process + model-family separation to QG Gate 2 Phase 1, strengthening Law 2 (writer-reviewer physical separation).
- `scripts/detect_codex.sh`: 6-case probe (not_installed, kill_switch, inside_codex_sandbox, auth_missing, known_bad_version, ok). Read-only, exit 0 always. Known-bad version regex covers Codex CLI 0.120.0-0.120.2 (stdin deadlock bug).
- `scripts/codex_findings_to_yaml.py`: JSONL stream parser with 3-stage fallback chain (fenced JSON → raw JSON → malformed_json). Handles both Codex 0.130+ nested `item.completed` event shape and legacy top-level `agent_message` shape. Includes stderr capture for `auth_error_in_stderr` (Codex exit 0 + auth failure pattern). Supports `--meta-override-exit-code` and `--meta-override-reason` flags for agent-side timeout/exit-nonzero classification.
- `scripts/build_codex_prompt.py`: safe prompt construction — reads inputs from file paths, substitutes via `str.replace` with no shell/Python literal injection vector.
- First-use cost consent gate: `AskUserQuestion`-based prompt with marker file at `~/.claude/quality-gates/codex-cost-consent.md`. Silent after first approval. Test harness uses `QG_MOCK_ASKUSER_PATH` env var for deterministic verification.
- Kill switch: `DEVBREW_DISABLE_QG_CODEX=1` disables codex-reviewer globally.
- Task 0 prompt-engineering spike (`tests/spike/`) — empirically validated codex emits fenced JSON in `agent_message` ≥2/3 runs. Frozen sample (`fixtures/codex_jsonl_sample.json`) serves as regression anchor against future codex event-schema drift.

### Changed

- `agents/scout.md`: dispatch input now includes `codex_manifest` (backwards-compatible — when `codex_available: false`, Phase 1 dispatch list is unchanged from prior behavior).
- `skills/quality-pipeline/SKILL.md`: Gate 2 Phase 0 prerequisite now runs `detect_codex.sh` and synthesizes the manifest into Scout's input. Cost consent gate fires between probe and Scout dispatch.

### Security

- 3-layer reviewer-writer isolation for codex-reviewer agent:
  1. Frontmatter `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]`
  2. Frontmatter `allowed-tools` narrow Bash whitelist (no `Bash(cat *)` — prevents redirection bypass)
  3. `codex exec -s read-only` OS-level sandbox
- Closed prompt-injection vector during Task 4 review: agent body now writes inputs to scratch files via single-quoted heredocs (`<<'EOF'`) and substitutes via Python `str.replace` on file paths — adversarial PR content (e.g., `"""` in diff text) cannot escape into outer agent execution.

### Notes

- Bumps QG Gate 2 max parallel fan-out from 11 → 12 (deep depth with codex-reviewer in Phase 1 + all Phase 2 specialists). Still within declared fan-out regime.
- AC7 (backward-compat regression) is verified structurally (probe + scout-rule + existing test suite) rather than via synthesizer baseline diff. See `tests/fixtures/baseline_capture_README.md` for the deferral rationale.
- Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` v3.1 (3 rounds adversarial review, 29 issues addressed).

## [1.10.0] — 2026-05-13

### Changed
- **SKILL.md prose** aligned with the v1.5.0 forward-only state machine. Five
  sites in `skills/quality-pipeline/SKILL.md` had carried the pre-1.5.0
  "auto-restart from Gate 1" vocabulary; they now describe the actual
  Stop-hook behavior (user-choice prompt; user re-runs `/qg`).
- **`GATE3_FAIL` prompt option 1 label** is now `"Fix and re-run /qg"`
  (was `"Fix issues (will restart from Gate 1)"`). User-visible string
  change; semantics already matched the new label since v1.5.0.
- **Example history log** in `references/state-file-format.md` no longer
  shows `Restarting from Gate 1 (iteration 2)` — replaced with the
  forward-only termination line.

### Removed
- **`total_iterations` / `max_total_iterations`** state-file fields. Deprecated
  in v1.5.0, never written since, and (discovered during this cleanup) the
  `extend` branch in `update_state_file` that incremented `new_max_total`
  was already a dead write because `max_total_iterations` had been absent
  from the `replacements` dict for a year. Removed from `parse_state_file`,
  `update_state_file`, schema doc, and three fixture files. The
  `test_no_max_total_iterations_constant` gate test is preserved.

### Fixed
- **Doc-vs-code drift**: SKILL.md verdict definitions, GATE3_FAIL prompt,
  and Gate 2 output format no longer mis-instruct reviewers that the
  pipeline auto-restarts from Gate 1. Locked by the new
  `tests/test_forward_only_prose.sh` grep guard (AC1–AC8 + NG7,
  8 assertions, exit 0 on PASS).
- **Stale comment in `main()` extend branch** (`# State file already
  updated with new max`) replaced with an accurate description: the prior
  `new_max_total += additional` was a silent no-op since v1.5.0 because
  `max_total_iterations` was never in the replacements dict. Caught during
  Task 3 code review; CLAUDE.md Law 3 compounding.

### Internal
- **`build_special_prompt`** refactored from a 6-case if/elif ladder
  (~146 LoC) to a module-level `_SPECIAL_PROMPTS` per-case dict + a 43-line
  dispatcher. Semantics preserved; locked by `tests/test_stop_hook_unit.py`
  (5 invariants: exact case-tag header prefix, length > 200, `<qg-signal`
  ≥ 2 directives, abort option present, exact `PIPELINE_ERROR\n\n`
  prefix on unknown transitions).
- **`main()` transition-handler** collapses 4 duplicated
  `print(json.dumps({...})); sys.exit(0)` blocks into a single
  `emit_continuation` helper called after a small prompt-selector
  dispatch. Handler block shrank ~73 → ~51 LoC (-22).
- **`hooks/stop-hook.py` LoC**: before 960, after 964. The spec's
  ≤ 800 target turned out to be over-optimistic — the `_SPECIAL_PROMPTS`
  dict for 7 cases is roughly as long as the original if/elif ladder
  (data encoding doesn't compress over branches). The realistic floor
  for D1+D2+D3 was ~950–960. The substantive win is structural (one
  source of truth per case, unified trailer) and the unit-test net
  protects against future drift, not raw LoC.

### Notes
- Stop-hook itself remains. The spec's "Stop-hook review" section enumerates
  6 responsibilities (turn-boundary auto-progression, multi-turn Gate 2
  fix-loop, user-choice prompt injection, state-file management, repeat-
  detection invariant, mid-session cleanup); none can be moved into the
  skill without losing automatic continuation or the code-enforced
  AP15 *"loop without repeat detection"* guard. The user-prompted
  re-evaluation ("이제와서는 stop hook이 반드시 필요할지도 검토해봐")
  is preserved in the spec's §Context for future readers.

## [1.9.0] — 2026-05-12

### Added
- **Gate 3 Step 2.5 — Test scope validator** (informational, non-blocking).
  New `test-scope-validator` agent classifies scope-relevant test files as
  `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`
  before `runtime-verifier` executes them. Surfaces silent failure modes
  (outdated tests against post-refactor behavior; tautological assertions
  added for coverage padding) without blocking Gate 3.
- `scripts/compute-test-scope-candidates.sh` — deterministic candidate
  resolver (Python/JS/TS heuristic src→test mapping + changed-test fallback).
- `agents/test-scope-validator.md` — read-only agent with `Write`/`Edit`
  disallowed (Law 2 3-way separation: writer / test-scope-validator /
  runtime-verifier).
- `tests/test_compute_test_scope_candidates.sh`, `tests/test_test_scope_validator_frontmatter.sh`
- `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}/` — reference
  fixtures for manual verification.

### Changed
- `skills/quality-pipeline/SKILL.md` — Gate 3 gained Step 2.5 between
  Step 2 (Upfront resolution) and Step 3 (Dispatch runtime-verifier).
  Existing verdict model and stop-hook continuation prompts unchanged.

### Environment
- New: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` — skip Step 2.5 entirely.
- New: `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` — alternate kill
  switch (consistent with existing skip-hook pattern).

## [1.8.1] — 2026-05-12

### Added
- **Worktree regression guards** (`tests/test_worktree.sh`, `tests/test_isolation.sh`): hermetic mktemp-based tests that lock in qg's PWD-relative state-path contract — the structural property that makes git-worktree isolation work without any worktree-specific code in the plugin. `test_worktree.sh` (10 assertions) verifies setup/discover/trivia/pre-check all read worktree-local context and never leak into the origin repo's `.claude/`. `test_isolation.sh` (11 assertions) verifies bidirectional isolation under a shared session ID (worktree ↔ origin), distinct-inode property of the two pipeline.md files, and that two concurrent sessions in the same directory remain independent. These tests will fail if anyone introduces `git rev-parse --git-common-dir` / `--show-toplevel`-rooted state paths, which would silently break worktree isolation.

## [1.8.0] — 2026-05-11

### Added
- **Pre-flight runtime detector** (`scripts/detect-runtime.sh`): `project_type`, `runnable_surfaces` (docker-compose / npm-script / pytest / cargo / go / makefile), `test_runners`, `mcp_browser` (chrome-devtools / playwright / none), `app_url_candidates`, `env_status`, `plan_features` (`PLAN_PATH` env에서 추출) 를 YAML manifest로 산출하는 결정적 bash script. read-only.
- **Fast-path SKIP_WITH_EVIDENCE**: detector가 runnable_surfaces / test_runners / plan_features 모두 비어있다고 보고하면 Gate 3가 agent dispatch 없이 즉시 SKIP_WITH_EVIDENCE emit (token cost = 0).
- **Mid-run NEEDS_RESOLUTION escalation**: agent가 fixable한 missing resource에 대해 사용자 해결을 요청 가능. Skill이 3자 ping-pong (skill ↔ user ↔ agent)을 AskUserQuestion 으로 중재. `max_gate3_resolutions` (기본 3) 으로 묶임.
- **`DEVBREW_GATE3_MAX_RESOLUTIONS` env override** (0..10 clamp). `0` 으로 설정 시 mid-run escalation 비활성화 (Approach 2 mode — 첫 NEEDS_RESOLUTION 이 바로 `gate3_fail` transition 으로 가서 user에게 fix/skip/abort 선택 제시).
- **Repeat detection** (`needed_hash` 기반): 같은 missing resource가 2회 연속이면 `gate3_repeat_detected` → user choice (proceed_with_warnings / abort).
- **Evidence-log validation** (skill 측): manifest의 모든 항목이 attempted entry를 가져야 함; 누락된 항목이 있으면 SKIP_WITH_EVIDENCE 를 자동 FAIL 로 격상.
- **Fixture 기반 테스트**: 4개 fixture (web-compose / web-example-only / library-tests / markdown-only), `tests/test_detect_runtime.sh` 의 30+ assertion, `TestGate3ResolutionState` 의 10+ 신규 state-machine 테스트, frontmatter lint 테스트, secret-leakage regression 테스트 (AC12 / P21).

### Changed
- **`runtime-verifier.md` 재작성 (v2)**:
  - Frontmatter 가 `allowedTools: [Read, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_*]` 와 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 명시 — CLAUDE.md Plugin Shape "default-everything 금지" 위반 fix.
  - `cost_class: variable` (기존 `low` 에서 변경 — iteration loop 가능).
  - Body: manifest-driven attempt 흐름, evidence-log 작성 의무, 4-verdict 체계 (PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION), secret 값 요청 금지 P21 guard 명시.
- **SKILL.md Gate 3 섹션** 6 단계 재작성 (detect → fast-path → upfront resolution → dispatch → evidence validation → NEEDS_RESOLUTION).
- **stop-hook.py**: 신규 transition `gate3_needs_resolution`, `gate3_repeat_detected`; 신규 state field `gate3_resolution_iter`, `max_gate3_resolutions`, `last_gate3_needed_hash`. 기존 `SKIP` verdict 는 그대로 `complete` 로 라우팅 (back-compat); `SKIP_WITH_EVIDENCE` 와 `PASS_WITH_WARNINGS` 가 같은 complete-bucket 에 합류.

### Fixed
- **Gate 3 의 silent SKIP regression**: 이전엔 project type detection fall-through (`package.json scripts.dev` 없음, `manage.py` 없음) 시 silently `unknown` → SKIP 으로 빠지면서 user 에게 알림이 없었음. 이제 evidence-required SKIP 이 이 경로를 거부; skill 이 fast-path SKIP (evidence log 동반) 으로 처리하거나 incomplete attempt 를 FAIL 로 격상.
- **chrome-devtools MCP under-utilization**: 이전엔 agent 가 사용 가능한 browser MCP tool 을 runtime keyword search 로 발견해야 했음. 이제 detector 가 `mcp_browser: chrome-devtools | playwright | none` 을 manifest 에 결정적으로 inject.

## [1.7.0] — 2026-05-10

### Added
- **Project-local plan discovery** (`scripts/discover-plan.sh`): Gate 1 plan-verifier가 `docs/superpowers/plans/` (superpowers:writing-plans 의 기본 저장 경로)을 1순위로, `~/.claude/plans/`를 legacy fallback으로 consult. 이전에는 `~/.claude/plans/`만 봐서 superpowers 워크플로우로 만든 plan이 항상 SKIP 되거나 옛 plan을 false-match 하던 버그 fix.
- **`Source` 필드** Gate 1 report에 추가 — 어떤 source(explicit / project-local / legacy-global)에서 plan을 가져왔는지 사용자가 즉시 인지 가능.
- **단위 테스트 10 개** (`tests/test_discover_plan.sh`): 양쪽 source 비어있음, project-local 우선, legacy fallback, non-plan 파일 필터, explicit override, mtime tiebreaker, `--plan` 인자 누락 regression(T10) 등 매트릭스 커버.

### Changed
- Discovery 알고리즘이 `agents/plan-verifier.md` prose 안의 자유서술에서 결정적 bash script로 이동. 미래 source 추가도 회귀 없이 가능. (Law 2 정신 — agent 자유서술 vs script contract.)
- Legacy source (`~/.claude/plans/`) 사용 시 `agents/plan-verifier.md`가 `⚠️ Legacy plan source ... Consider migrating ...` 1줄 deprecation 경고를 report 헤더 직전에 emit. project-local hit이면 silent.
- README "Principles Instantiated" 섹션에 Law 3 cross-plugin compounding 항목 추가 — `superpowers:writing-plans`의 출력 위치를 sister-plugin contract로 명시.
- `discover-plan.sh`가 `plan_path` 필드를 절대 경로로 emit (Task 2 fix). agent의 `Read` 호출이 cwd와 무관하게 작동.

### Fixed
- **Path mismatch (Gate 1 SKIP/false-match bug)**: `superpowers:writing-plans` 가 `docs/superpowers/plans/` 에 plan을 저장하는데 plan-verifier 는 `~/.claude/plans/`만 스캔해서 (a) 사용자의 최신 plan을 찾지 못하거나 (b) `~/.claude/plans/` 의 옛날 무관한 plan을 잘못 verify 하던 문제. 1.7.0 부터 priority 기반 discovery 로 정확히 매칭.
- **`--plan <missing>` 무한 루프**: `discover-plan.sh --plan` (path 인자 누락) 시 `shift 2` 실패가 silent하게 묵살되어 무한 루프에 빠지던 corner case. `[[ $# -lt 2 ]]` 가드 + exit 2 처리 + T10 regression test.

## [1.6.3] — 2026-05-10

### Fixed
- **Step 0 review-range fallback** (skill `quality-pipeline`): 작업 트리가 깨끗할 때(모두 commit됨) 기존 bash block은 빈 `git diff`로 fall-through해 review 대상이 0줄이 되던 문제. 이제 working tree가 dirty면 unstaged diff(기존), clean이면서 `main..HEAD`에 commit이 있으면 자동으로 `main...HEAD` 누적 branch diff로 전환. 6개의 `git diff` 호출 모두 통일된 `$REVIEW_RANGE`를 사용. (qg self-review §5.1 — v1.6.2 dogfood에서 발견)
- **Test detection regex**: `^tests?/`가 top-level `tests/`만 매칭해 nested `<sub>/tests/` (monorepo / plugin marketplace 구조)에서 `test_change=0` false negative 발생. `(^|/)tests?/`로 변경 — top-level + nested 모두 매칭.
- **`set -e` 제거 (Step 0 bash block)**: 모든 명령이 이미 `|| true` / `|| echo 0`으로 실패 처리하고 있어 `set -e`는 redundant했고, subshell command substitution과 상호작용하면서 fix-loop iteration에서 silent abort 유발. 제거 후 각 명령의 failure mode가 local + 예측 가능.

### Changed
- Step 0 JSON output에 `review_range` 필드 추가 — 어떤 모드(unstaged / `main...HEAD`)로 review됐는지 사용자가 보이도록.

## [1.6.2] — 2026-05-10

### Fixed
- v1.6.1의 kill switch fix가 5개 hook 중 3개만 다룬 상태였음 — `session-start-advisor.py`와 `session-end-cleanup.py`는 글로벌 `DEVBREW_DISABLE_QUALITY_GATES=1`만 honor하고 per-hook `DEVBREW_SKIP_HOOKS=quality-gates:<key>`을 무시했음. 두 hook 모두 `_disabled()`에 SKIP_HOOKS 체크 추가 (skip key: `quality-gates:session-start-advisor`, `quality-gates:session-end-cleanup`). 이제 README의 "All hooks honor..." 약속이 5/5 hook에서 코드로 지켜짐.
- **CRITICAL — substring prefix collision**: 5개 hook 모두 `_disabled()`에서 raw `"quality-gates:<key>" in skip` 형태의 substring match를 사용해, 사용자가 `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker`을 설정하면 (script filename을 key로 잘못 사용한 자연스러운 실수) `quality-gates:post-tool-use`가 그 안에 prefix로 포함되어 `post-tool-use.py`도 함께 silently 비활성화됨. 5개 hook 모두 whole-token match로 변경 — `skip.split(",")` 후 `t.strip()`된 토큰 set에 정확히 매칭. CLAUDE.md "kill switch는 보안 컨트롤" 규정의 contract 위반 fix. (Gate 2 pipeline review에서 발견)

### Added
- `tests/test_kill_switches.py` 회귀 테스트: 5개 hook 모두에 대해 글로벌 + per-hook + CSV 형태 SKIP_HOOKS가 side effect를 차단하는지 검증. side effect 검출은 hook별로 differentiated (state mutation / `systemMessage` injection / `files.md` 생성 / advisor stdout / 폴더 삭제). sanity test로 *kill switch 없을 때* setup이 실제로 side effect를 일으키는지도 검증해 trivial pass 방지.
- `test_per_hook_skip_does_not_cross_contaminate` — 위 substring prefix collision 회귀 가드. `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker` 설정 시 `post-tool-use.py`가 *여전히* 작동(`systemMessage` emit) 확인.
- `test_all_hooks_declare_kill_switch_strings` — `hooks/*.py`를 동적으로 enumerate해서 각 파일에 `DEVBREW_DISABLE_QUALITY_GATES`와 `DEVBREW_SKIP_HOOKS` 문자열이 모두 존재하는지 source-text static check. 새 hook이 `HOOK_CONTRACTS` static list에 추가되지 않은 채 kill switch 없이 ship되는 회귀 패턴(v1.6.1, v1.6.2의 동일 원인)을 merge time에 잡음.
- `_assert_no_side_effect`의 stop-hook assertion에 `proc.stdout.strip() == ""` 추가 — 기존엔 `pipeline.md` 미변경만 체크해 `_disabled()`가 silently broken되어도 통과했음 (no-signal stop-hook 정상 path도 pipeline.md를 변경하지 않으므로). stdout 체크가 두 path를 discriminate.
- sanity test의 stop-hook 분기를 bare `pass`에서 `assertIn("decision", proc.stdout)`로 교체 — sanity test가 stop-hook에 대해서도 진짜 차이를 검증.

## [1.6.1] — 2026-05-10

### Fixed
- **CRITICAL**: `stop-hook.py`와 `post-tool-use.py`에 `DEVBREW_DISABLE_QUALITY_GATES=1` 및 hook 단위 `DEVBREW_SKIP_HOOKS=quality-gates:<hook>` kill switch 누락. README는 "All hooks honor..."를 보장하지만 두 hook은 환경변수를 무시하고 fire하던 상태. CLAUDE.md "kill switch는 보안 컨트롤" 규정 위반 fix. fail-closed 패턴(부수효과 발생 전 `sys.exit(0)`)으로 main() 진입점 최상단에 추가.
- README "Principles Instantiated" 섹션의 stale 문구 *"once that file lands on `main`"* 제거 — `docs/philosophy/devbrew-harness-philosophy.md`는 이미 main에 있음.

### Changed
- `README.md`를 Korean-primary로 재작성. CLAUDE.md "Korean-primary, English-terms-only" 정책 적용 (식별자·고유명사·원문 인용·번역 어색한 기술 용어에만 영어 허용).
- `CHANGELOG.md`를 Korean-primary로 재작성. 기존 영문 prose를 한국어로 번역, Keep a Changelog 섹션 헤더(Added/Changed/Fixed/Security 등)는 컨벤션상 영어 유지.

### Removed
- `README.ko.md`와 `CHANGELOG.ko.md` 동반 파일 삭제. CLAUDE.md "`*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치)" 규정 적용.

## [1.6.0] — 2026-05-08

### Added
- SessionEnd hook (`session-end-cleanup.py`) — 정상 종료 시 per-session state cleanup.
- `scripts/qg-gc.py`: `fcntl` lock + double-stat ns race guard + rename-then-rmtree로 보호된 TTL 기반 GC 헬퍼.
- 환경변수: `DEVBREW_QG_TTL_HOURS` (기본 24), `DEVBREW_QG_GC_VERBOSE` (기본 off).
- `/cancel-qg --gc` (TTL sweep)와 `/cancel-qg --all` (active sibling 리스트 + confirm 후 전체 wipe).
- `/qg --gc` flag — 명시적 GC 호출.
- `setup-qg.sh --session-id <id>` 인자 — `CLAUDE_CODE_SESSION_ID` env var 미설정 시 fallback.
- `post-tool-use.py`를 `hooks.json`에 PostToolUse(Bash) hook으로 등록 (이전엔 orphan 상태).

### Changed
- state 위치를 flat `.claude/quality-gates*.local.md` (5 파일)에서 per-session `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` + `{diff-cache,code-paths}` 로 이동.
- `session-start-advisor.py`가 이제 현재 세션만 scope하고 read-only (CLAUDE.md "SessionStart never mutates" 룰).
- `setup-qg.sh`가 `CLAUDE_CODE_SESSION_ID`도 `--session-id`도 없으면 hard-fail.
- `setup-qg.sh`가 시작 시 `qg-gc.py` 호출 (best-effort; 실패해도 setup은 abort 안 함).
- `/qg --reset`이 현재 세션 폴더 + legacy v1.5.0 파일을 wipe (이전엔 flat 파일만).
- README "Principles Instantiated": P21 mis-citation을 P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)로 정정. state 파일 룰은 P21 (Security & Supply Chain)에 속한 적이 없음.

### Fixed
- 같은 프로젝트의 동시 세션이 더 이상 서로의 state를 corrupt하지 않음 (이전엔 5개 공유 `.claude/` 파일).
- crash/close된 세션의 stale state가 무관한 새 세션에서 misleading "in-flight pipeline" advice를 트리거하지 않음.
- `post-tool-use.py`의 "active pipeline" 체크가 호출 세션만 scope (이전엔 어느 세션의 파이프라인이라도 auto-trigger를 차단).

### Removed
- flat per-project state file 모델. 5개 legacy 파일(`quality-gates.local.md`, `quality-gates-session.local.md`, `quality-gates-branch.local.md`, `qg-diff-cache.txt`, `qg-code-paths.tmp`)은 upgrade 후 첫 `/qg` 실행 시 stderr 경고와 함께 unlink.

### Migration
- `session-start-advisor`가 legacy 파일 발견 시 일회성 stdout 메시지 (read-only — 절대 삭제 안 함).
- in-flight v1.5.0 파이프라인은 자동 마이그레이션되지 않음. 이전 session_id는 그 prior 세션에만 의미가 있으므로, `/qg` 재실행.

## [1.5.0] — 2026-04-30

### Added
- Phase 0 `scout` agent: Sonnet, 모델 기반 Gate 2 dispatch planner. 필터링된 diff + Gate 1 summary를 읽어 구조화된 YAML dispatch plan (depth + phase1_agents + phase2_agents + rationale)을 생성.
- Phase 1.5 `adversarial` agent: Opus, Phase 1+2 finding의 false-positive 사냥 (confirm/downgrade/reject 판정). 노이즈에 의한 fix-loop 반복을 줄이며 리뷰를 강화.
- Phase 1.6 `synthesizer` agent: Sonnet, finding을 dedupe/rank (severity × confidence), confidence < 7 suppress, 사용자에게 보일 prioritized Markdown 산출.
- `PostToolUse` hook `post-tool-use-session-tracker.py`: Edit/Write/MultiEdit 파일 경로를 `.claude/quality-gates-session.local.md`에 누적해 `/qg` scope을 좁힘.
- `SessionStart` hook `session-start-advisor.py`: 변경 없는 read-only advisor — in-flight 파이프라인을 알림 (CLAUDE.md hook coexistence 룰 준수).
- `/qg branch`, `/qg --paths <glob>`, `/qg --reset` flag 지원.
- pipeline skill과 모든 신규 agent에 `cost_class` 선언.
- Trivia escape (`scripts/check-trivia.sh`): 단일 파일·≤3줄 whitespace/rename 시 파이프라인 전체 자동 skip.
- Docs 필터 (`scripts/filter-docs.sh`): `*.md` / `docs/**` / `CHANGELOG*` / `README*`을 코드 reviewer scope에서 제외 (Gate 1 plan-verifier는 raw diff를 그대로 봄).
- Repeat-detection: 두 iteration 연속으로 scout dispatch plan + synthesizer 출력이 동일하면 `gate2_repeat_detected` user choice 발동 (philosophy AP15 인스턴스화).
- Gate 1 → Gate 2 핸드오프 포맷: 구조화된 `gate1_summary` YAML 블록; FAIL 시 Gate 2 진입 차단 (Law 1).
- Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion hard gate (philosophy AP9 인스턴스화).
- Pre-pipeline check (`scripts/pre-pipeline-check.sh`): 세션 라이프사이클 처리 (active resume / branch mismatch / staleness / fresh start).
- `tests/` 신규 테스트: `test_session_tracker.py` (7), `test_session_start_advisor.py` (10), `test_stop_hook_state_machine.py` (6).

### Changed
- 기본 review scope이 풀 브랜치 diff가 아니라 **현재 Claude Code 세션에서 편집한 파일들**로 변경. 기존 동작은 `/qg branch`로 사용.
- Gate 2 Phase 1 fan-out이 scout의 plan에 따라 depth별로 다름 (1 / 2 / 3 agent; 더 이상 항상 3개 아님).
- Gate 2 내부 fix-loop이 매 iteration마다 delta diff (이전 iter 이후 변경된 파일만)로 scout을 재실행.
- `total_iterations`와 `max_total_iterations`는 더 이상 `setup-qg.sh`가 작성하지 않음; `stop-hook.py`는 stale state 파일 호환을 위해 읽기만 함.
- 시스템 메시지 포맷 갱신: `iter N/M`은 Gate 2만 표시; 다른 게이트는 게이트 이름만 표시.

### Removed
- **Cross-gate restart 루프**: Gate 2 / Gate 3 `NEEDS_RESTART`가 더 이상 Gate 1으로 자동 재진입하지 않음. user-choice prompt ("변경을 적용하고 /qg 재실행")로 종료.
- `MAX_TOTAL_ITERATIONS` 상수와 `restart` transition을 `stop-hook.py`와 `setup-qg.sh` 양쪽에서 모두 제거.
- SKILL.md의 룰 기반 `SCOPE_*` env-var Phase 2 게이팅 제거 (scout의 `phase2_agents` 필드로 대체; scout 실패 시 fallback으로 레거시 코드 유지).

### Fixed
- Gate 1 plan-verifier 출력 포맷 표준화: 구조화된 `gate1_summary` YAML 블록 필수 (이전엔 자유 산문). 결정론적 Gate 2 dispatch 가능.
- Stop-hook state machine: `compute_transition`을 top-level 순수 함수로 추출 (이전엔 `main()` 안에 inline). 단위 테스트 가능.

### Security
- 모든 신규 reviewer agent (`scout`, `adversarial`, `synthesizer`)가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (Law 2 강제).

## [1.4.0] — 이전

- Gate 2 orchestration을 `quality-pipeline` skill 안으로 이동 (PR #14).

## [1.3.0] — 이전

- Stop-hook 기반 파이프라인 진행 + Gate 2 토큰 절감 (PR #12).

## 그 이전

- 초기 Stop-hook 기반 파이프라인 (PR #10), 시그널 검출 수정 (PR #11).
