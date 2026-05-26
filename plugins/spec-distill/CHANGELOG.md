# Changelog

## [0.8.1] — 2026-05-26

### Fixed
- `agents/spec-reviewer.md` — Input/Design Mode Branch wording이 v0.8.0의 content-aware scope 확대를 반영하지 못하던 drift 정정. Input path는 `<file>-spec.md` 한정에서 `docs/superpowers/specs/` hierarchy 안 임의 `.md`로 일반화. Design Mode Branch trigger는 (a) `*-design.md` suffix, (b) suffix 없는 `.md`가 frontmatter `locked_decisions` 부재로 content-aware 판별, (c) dispatcher `mode: design` 명시 — 세 갈래를 명시. Hook 결정론과 reviewer self-narrative 정렬 (Law 2 baseline operability).
- `hooks/spec-write-validator.py` docstring + `README.md` Hooks 표 + `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 설명에 "sub-folder hierarchy 포함" 명시. v0.8.0 시점부터 `resolve_mode()`의 `PATH_PREFIX in file_path` substring 매칭이 sub-folder를 자동 포함하던 것을 contract로 박제.
- `skills/reviewing-spec/SKILL.md` — `mode: design` 분기 설명에서 "brainstorming의 design.md" → "design 모드 파일 (suffix 또는 content-aware)"로 mechanism-agnostic 표현으로 정정.

### Added
- `tests/test_resolve_mode_scope.sh` — sub-folder 회귀 가드 5 case 추가 (depth-1 `-spec.md`, depth-1 `-design.md`, depth-2 content-aware spec, depth-1 content-aware design, hierarchy boundary 위반 false-positive 차단 `specs_archive/`).

## [0.8.0] — 2026-05-22

### Changed
- `hooks/spec-write-validator.py`:`resolve_mode()` — review 게이트 범위를 `docs/superpowers/specs/` 아래 **모든 `.md`**로 확대(기존: `-spec.md`/`-design.md` suffix만). suffix 없는 `.md`는 신규 `_frontmatter_has_locked_decisions()` inline 헬퍼로 mode 판별: 첫 `---`…`---` frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`. body 언급·unclosed frontmatter·디코드 실패는 `design`(안전 fallback) + loud stderr. reviewing-spec routing·검사 로직·state 스키마 불변. review 강제(Law 2)가 파일명 컨벤션에 의존하던 취약점 제거.

## [0.7.0] — 2026-05-22

### Removed
- `hooks/interview-trigger.sh` + `hooks.json` UserPromptSubmit 등록 — advisory build/make nudge 훅. ~80개 세션 트랜스크립트 hook-attachment 전수 스캔 결과 3주간 0회 발화 (trigger 조건 `키워드 + <20단어`가 실사용 프롬프트와 미매칭). 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview` 직접 호출로 충분 — advisory(`additionalContext`)는 모델이 무시 가능해 비결정적. `hooks.json` `description`에서 "interview" 문구 제거.
- `hooks/state_path.py`:`cleanup_stale_states()` 함수 전체 블록 + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 — v0.6.0에 deprecated된 no-op(약속대로 제거). 호출처 없음 (TTL-GC + SessionEnd hook이 정리 담당). `tests/test_state_cleanup.sh` 삭제.
- 테스트 정리: `tests/test_hook_output_schema.py`의 `TestInterviewTriggerSchema` + `test_global_disable_silences_interview_trigger`, `tests/test_hooks.sh`의 interview-trigger 섹션, `README.md` Hooks Installed 표의 interview-trigger 행.

## [0.6.0] — 2026-05-19

### Added
- `hooks/session-end-cleanup.py` — SessionEnd hook for deterministic per-session state cleanup (qg pattern adaptation, git-aware path).
- `scripts/spec-distill-gc.py` — TTL-based GC (24h) with fcntl lock + double-stat ns + rename-then-rmtree race guard. `.gc-pending-*` orphan sweep (>60s) on each invocation.
- `scripts/approve_handoff.sh` — atomic AC11 approve handoff (4-step: commit / handoff pointer / cleanup / termination). Extracted from `skills/reviewing-spec/SKILL.md` prose.
- `hooks/state_path.py`:`resolve_session_id(payload)` + `SESSION_PATTERN` — single source of truth for session_id, charset/length validation.
- 7 new tests: `test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_stale_state_truncate.sh`, `test_brainstorming_entry.sh`, `test_kill_switches_v060.sh`.

### Changed
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` — session_id source switched from `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` literal fallback to `resolve_session_id(payload)`. Production now resolves from `CLAUDE_CODE_SESSION_ID`. `DEVBREW_SPEC_DISTILL_SESSION_ID` retained as test override.
- `hooks/spec-write-validator.py`:`write_state` — defensive truncate when existing state.local.md frontmatter `session_id` ≠ current (defense-in-depth).
- `hooks/spec-write-validator.py` — AC14 legacy advisory: detect `.claude/spec-distill/default/` and emit one-shot stderr advisory (marker `.legacy-advisory-emitted-v060`).
- `hooks/hooks.json` — SessionEnd event registered.
- `skills/reviewing-spec/SKILL.md` — AC11 4-step prose replaced with 1-line `approve_handoff.sh` script call.

### Deprecated
- `hooks/state_path.py`:`cleanup_stale_states` — no-op + marker-based one-shot deprecation stderr. Removed in v0.7.0.

### Fixed
- 잔여 frontmatter bug (사용자 보고 2026-05-19): `.claude/spec-distill/default/state.local.md`에 이전 세션의 frontmatter가 누적되어 새 세션이 stale data 위에 쓰는 증상. Root cause: `DEVBREW_SPEC_DISTILL_SESSION_ID` 부재 시 모든 hook이 `"default"` literal로 fallback → singleton file 공유. Fix: `CLAUDE_CODE_SESSION_ID` 단일 source + SessionEnd hook + TTL-GC + write_state defensive truncate (4-layer defense).

### Security
- session_id charset validation `^[A-Za-z0-9_-]{8,}$` 모든 cleanup path (SessionEnd hook, TTL-GC, approve_handoff.sh, write_state)에 적용 — `../traversal` 등 path injection 차단.

## [0.5.1] — 2026-05-17

### Fixed
- `reviewing-spec/SKILL.md` Re-review cap drift — v0.3.0가 body section의 hard cap을 `>= 3` → `>= 5`로 상향했으나 동일 파일의 (a) frontmatter description (`max 3`), (b) Deterministic Routing Table 5개 행 (spec `< 3` / `>= 3` × 2 + design `< 3` / `>= 3`), (c) `README.md` ASCII flow `max 3`, (d) `tests/test_reviewing_spec_design_routing.sh`의 `count >= 3` assertion이 갱신되지 않아 cap=5가 *dead code*였음. Routing table의 `>= 3` 행이 먼저 fire하여 v0.2.0의 cap=3과 동등하게 동작. 본 PR이 5개 위치 모두 5로 통일하여 v0.3.0 의도가 비로소 enforce됨. **Behavioral change**: re-review가 이제 실제로 4–5회 반복 가능 (이전엔 3회에서 forced Human Gate).

### Added
- `tests/test_rereview_cap_consistency.sh` — cross-file invariant test. SKILL.md body의 `Hard cap**: \`rereview_count >= N\`` 라인에서 N을 source-of-truth로 추출 후 8개 derived 위치 (SKILL.md frontmatter + routing 4행 + README ASCII flow + README AP16 + design-routing test)가 모두 같은 N을 사용하는지 검증. devbrew Law 3 (Compounding) instantiation — 미래 cap 변경 시 derived 갱신을 빠뜨리면 즉시 fail.

## [0.5.0] — 2026-05-17

### Fixed
- 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) 의 stdout JSON이 Claude LLM context로 도달하지 않던 silent failure. `systemMessage` 필드는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. dual-target 출력 (Claude-target field + `systemMessage` 짧은 흔적, ≤120자, "[spec-distill]" prefix) 으로 정정 — Claude는 context로 받고 user는 transcript에서 발화 흔적 확인 가능.
- `review-dispatch.py` `rewrite_state()` 호출 순서 정정 (write-before-emit, AC7.1). `rewrite_state()` 본문에 `f.flush()` + `os.fsync(f.fileno())` 추가하여 OS-level durability 보장. 이전 ordering (print → rewrite) 은 동일 turn 안에서 두 번째 Stop fire가 stale state를 읽고 두 번째 block 출력하는 block storm을 일으킬 수 있었음.
- `review-dispatch.py` rewrite OSError 시 `{}` exit 0 (block emit 안 함, AC7.2). 이번 dispatch 1회는 누락되나 L4b UserPromptSubmit reminder가 다음 user prompt에서 dispatch를 살림 — block storm 회피가 우선.
- `interview-trigger.sh` no-jq fallback에 `tr -d '\r'` 추가하여 session-anchor.sh와 CR 처리 대칭.

### Changed
- Stop hook (`review-dispatch.py`) 의 `decision:"block"` 이 Stop을 막고 Claude를 즉시 continue 시키므로 "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 30초 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`) 가 무한 block 루프 방지를 그대로 담당.

### Added
- `tests/test_hook_output_schema.py` — Python `unittest` 기반 통합 회귀 방지 test. 5개 hook 모두에 대해 happy-path schema assertion + AC1a 인코딩 round-trip + AC7.2 fault injection + AC7.3 ordering 3-prong (AST inspection + mock-based trace) + AC10/AC11 kill switch + NG9 cross-resolver advisory (skipUnless worktree). bash fallback (jq-없는 환경) 케이스는 `unittest.skipUnless`로 환경 감지.

### Security
- kill switch 5개 (`DEVBREW_DISABLE_SPEC_DISTILL=1` 전역 + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` hook 단위) 모두 무변경. 신규 env var 없음.
- bash hook no-jq fallback escape scope: backslash + double-quote + LF + CR만 처리. null byte / 기타 control char / non-BMP unicode는 처리 범위 밖 — jq path에서 full JSON escape 처리.

## [0.4.0] — 2026-05-17

### Added
- `hooks/state_path.py` — main repo root 해석 helper (`git rev-parse --git-common-dir` 기반). state 파일을 항상 main repo `.claude/spec-distill/` 아래에 기록 (worktree 호출 시에도). cwd fallback + stderr loud log (philosophy §4.8 instantiation).
- `hooks/pending-review-reminder.py` — UserPromptSubmit hook. pending_review가 살아있고 last_dispatched_at > TTL(30s)이면 mandate 재emit (L4b redundancy). Kill switch `spec-distill:UserPromptSubmit` / `spec-distill:reminder`.
- State cleanup 정책: pending_review `triggered_at` > 24h → block auto-purge, last_dispatched_at만 있는 state file > 7일 → file auto-delete. 신규 env var 없이 하드코딩.
- reviewing-spec SKILL.md — Step 1 `pending_review.mode` 분기 + Routing Table에 design rows 3개 추가 (approved → writing-plans, needs_revise < 3 → brainstorming author 회귀, needs_revise ≥ 3 → forced Human Gate). drafting-spec Mode B는 design.md에 호출하지 *않음*.
- agents/spec-reviewer.md — design mode checklist 분기 섹션 6 카테고리 (placeholder / ambiguity / scope_creep / approaches_comparison / isolation / testing). spec mode 본문 무손상.
- 신규 test 6개: `test_state_path.sh`, `test_state_cleanup.sh`, `test_design_mode_validator.sh`, `test_review_dispatch_design_mandate.sh`, `test_reminder_hook.sh`, `test_reviewing_spec_design_routing.sh`, `test_spec_reviewer_design_checklist.sh`.
- 신규 fixture 2개: `tests/fixtures/2026-05-17-test-design.md` (valid), `tests/fixtures/2026-05-17-test-design-bad.md` (placeholder + ambiguity hits).

### Changed
- `hooks/spec-write-validator.py` — state path을 `state_path.state_root()`로 해석, pending_review block에 `worktree_path:` 필드 추가.
- `hooks/review-dispatch.py` — state path을 state_path helper로 해석, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path 포함, fire마다 `cleanup_stale_states` 호출.
- `hooks/hooks.json` — UserPromptSubmit에 reminder hook 등록 (기존 interview-trigger.sh 옆).

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중. 신규 env var 없음 (LD10 일관성).
- bare repo / submodule / nested worktree / `.git` symlink는 supported scope 밖 — state_path cwd fallback + loud log로 운영자 인지 (NG6).

## [0.3.0] — 2026-05-16

### Added
- PostToolUse hook `hooks/spec-write-validator.py` — spec/design 파일 write를 file-system level에서 가로채 Layer 1 mechanical 검증 (11 sections, frontmatter, locked_decisions schema, ambiguity blacklist, design-mode placeholder scan).
- Stop hook `hooks/review-dispatch.py` — `pending_review:` ledger 기반 결정론적 reviewer dispatch (systemMessage 주입).
- `scripts/parse_spec_structure.py` — frontmatter / sections / locked-decisions / ambiguity / placeholders CLI subcommand 라이브러리.
- `scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 + `~` escape 지원.
- design.md (brainstorming upstream 산출물) 커버리지 — suffix-based mode 분기, frontmatter optional, ambiguity + placeholder만 검사.
- 7 fixture 파일 (`tests/fixtures/`) + `test_spec_write_validator.sh` + `test_review_dispatch.sh`.
- Kill switches: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<sec>`.

### Changed
- `reviewing-spec/SKILL.md` Step 1 — dispatch trigger가 hook-driven (file ledger `pending_review:` block) 임을 명시.
- `reviewing-spec/SKILL.md` Re-review cap — hard cap `>= 3` → `>= 5` + round-level stagnation early-exit (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate). multi-round drift detection을 위한 budget 확장.
- `drafting-spec/SKILL.md` Mode A/B — handoff 단계에서 명시 reviewing-spec 호출 불필요, hook이 결정론 dispatch함을 note.

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- PostToolUse exit 2 + stderr 차단 패턴 + stdout `{"decision":"block"}` 이중 안전.

## [0.2.0] — 2026-05-13

### Added
- Re-consensus gate (Phase [3.5]) — locked-affecting reviewer issue가 자동 Mode B로 가지 않고 `AskUserQuestion` 3-옵션 (수용/유지/추가 인터뷰)으로 사용자 게이트.
- spec.md frontmatter `locked_decisions:` 리스트 — `LD1, LD2, ...` ID로 인터뷰 (b)/(d) path 합의를 self-contained contract로 기록.
- state.local.md 신규 필드: `pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`.
- drafting-spec Mode B `allowed_issue_ids` 입력 contract — 위반 시 abort + `git restore` + state.local.md `mode_b_violation` marker + reviewing-spec [3.5] re-entry.
- spec-reviewer agent 출력에 issue별 `affects_locked_decisions: [LD ids]` 필드.
- Escalate priority table (P1–P4): C3 global cap (≥4 locked-affecting → spec 전체 [5]) > AC9 per-issue (`reconsensus_count >= 2`) > P18 stagnation > reviewer-persona warn.
- Kill switch `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (loud warning).
- v0.1.x in-flight state migration — missing field 자동 promote (non-mutating read).
- V0 pre-gate (fixture 존재 검증) + `set -e -o pipefail` 전역 적용.

### Changed
- P18 stagnation 판정 조건: `raised_count >= 3` → `raised_count >= 3 AND dismissed_by_user == 0` (사용자 명시 거절을 stagnation에서 제외).
- spec-reviewer agent — frontmatter `Read` tool 사용 허용 (locked_decisions 추출 목적).
- drafting-spec Mode A — interview transcript에서 `pending_locked_decisions`를 frontmatter `locked_decisions:`로 변환.
- README "Principles Instantiated"에 P17 explicit instantiation 한 줄 추가.
