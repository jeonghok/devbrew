# qg Tier 2/3 개선 — design spec

> Tier 1 (safety + docs)는 PR `feature/qg-tier1-safety-docs`로 분리되어 v1.16.0에 포함. 본 문서는 Tier 2 (correctness) + Tier 3 (refactor)의 정의·acceptance criteria·verification plan을 기록.

**Metadata**
- 출처: 2026-05-17 세션의 3개 병렬 감사 (devbrew philosophy / adversarial UX / architecture)
- 감사 finding 합집합: 23개. Tier 1 (6) 완료, Tier 2 (8), Tier 3 (5)
- 대상 플러그인: `plugins/quality-gates/` (현재 v1.16.0)
- 작성자: Claude Opus 4.7 (1M context)

## Context / Why

3개 시각으로 qg를 감사했을 때 6개 위험 카테고리가 떠올랐고, 각각 finding이 ≥2명에서 수렴함:

1. **Constitution-vs-implementation gap** — README가 약속하는 보장(trivia escape, AP9 fan-out 게이트, AP16 wall-clock)이 코드에 partial하게 구현됨.
2. **Stuck state edge cases** — stop-hook이 모델 신호를 못 받았을 때, state-write가 실패했을 때 정상 복구 경로 없음.
3. **Silent skips** — codex 미설치, scout fallback이 사용자 비용 prompt 우회 — *graceful degradation의 loud-logging* 약속 위반.
4. **Hidden cost** — adversarial이 opus + AskUserQuestion 카운트 제외 = 사용자가 동의한 비용보다 큰 dispatch.
5. **Architectural debt** — Phase 1 dual-dispatch ~135 LOC duplication, scout/synthesizer/codex-reviewer가 deterministic하지만 LLM dispatch 비용을 지불.
6. **Test drift** — 8개 leaf agent 중 7개가 behavioral test 부재. v1.11.1 silent-drop 버그가 user runtime에서만 잡힌 전례.

## Goals

- Constitution이 약속하는 보장과 코드를 align — README의 anti-corollary cite가 거짓말이 되지 않음.
- 모든 silent-skip을 loud-skip으로 격상; 모든 hidden cost를 disclosed cost로 격상.
- Phase 1 dispatch 단일 경로화 (~135 LOC dedup) → 향후 persona 편집이 두 곳에서 drift 안 함.
- 8개 leaf agent 모두 fixture-based behavioral test 보유.

## Non-goals

- Gate 2의 8-agent 구조 자체는 유지 (refactor scope는 *deterministic layer를 script로 내리는 것*; agent persona는 보존).
- Gate 1/3의 surface 변경 없음. 추가 surface도 없음.
- 새 dependency, 새 MCP server, 새 외부 모델 추가 없음.

## Constraints

- 각 PR은 plugin.json minor bump (`1.16.0 → 1.17.0`, `→ 1.18.0`, ...). 모든 변경은 reviewer-persona 약화로 보이지 않도록 CHANGELOG의 `### Security` / `### Changed` 분리 유지.
- Phase 1 dual-dispatch 통합은 grep-anchored 테스트 (`test_codex_dispatch_invariant.sh`, `test_forward_only_prose.sh`)와 충돌 가능 — 통합 후 anchor 재발급 필요.
- Tier 3 refactor (script-replaces-agent)는 Law 2 layer-1 (`disallowedTools` frontmatter)의 default tool-scope를 잃지 않도록 SKILL.md의 Bash allowlist를 좁게 명시.

---

## Tier 2 — Correctness fixes

각 항목은 한 PR로 land 가능; 의존성 명시.

### T2-1. Trivia escape coverage 확장 (`F-1`, `U-1`)

**Why:** CLAUDE.md `P12 anti-corollary` 정의는 typo / rename / comment-only / single-file formatting의 4-axis cover를 약속하지만 `scripts/check-trivia.sh`는 whitespace + rename 2-axis만 cover. 또한 `--paths` scope 인자가 SKILL.md L122에서 trivia 스크립트로 전파되지 않아 user-supplied scope가 무시됨. Untracked single-file (new test fixture 같은) 케이스는 `git diff HEAD --name-only`가 보지 못해 untrivial로 fall through.

**Files to Modify:**
- `plugins/quality-gates/scripts/check-trivia.sh` — comment-only detector (per-language comment regex over unified diff: `^[+-]\s*(#|//|--|/\*)` 그룹), typo detector (single-token same-length replace), `--paths` flag 수용, `git ls-files --others --exclude-standard` 결합으로 untracked 새 파일도 detect.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L~122 — `check-trivia.sh`에 `--paths "$(cat $QG_DIR/code-paths.tmp)"` 전파.
- `plugins/quality-gates/tests/test_check_trivia.sh` (신규) — fixture 기반: comment-only single-file, typo only, untracked new file, --paths-narrowed scope.

**Acceptance criteria:**
- AC1: Single-file 단일 comment-line diff (`^[+-]\s*(#|//)`)은 `triviaSkip` 반환.
- AC2: 같은 파일 within `--paths` scope의 typo-only diff (single-token same-length substitution)은 `triviaSkip`.
- AC3: Untracked 새 파일 ≤3줄은 `triviaSkip` (단, content가 trivia 자격을 충족할 때).
- AC4: `--paths`가 제공되면 그 path subset에 대해서만 검사; 외부 dirty 파일은 무시.
- AC5: README의 trivia 약속과 스크립트의 cover가 1:1 매칭 — 추가 `### Trivia detector coverage` subsection으로 명시.

**Verification plan:** 새 unit test 5 cases + 기존 `test_setup_qg.sh`의 trivia 케이스 회귀 통과.

### T2-2. Scout fallback AskUserQuestion 게이트 통합 (`F-2`, `U-2`, `A-1`)

**Why:** scout-primary 경로(L497)는 fan-out ≥ 4일 때 AskUserQuestion 발동. scout-fallback 경로(L550-599)는 같은 4-reviewer dispatch를 하면서 게이트를 *의도적으로* skip. 사용자는 정상 경로보다 degraded 경로에서 더 friction을 받아야 마땅 (덜 정확한 review에 더 큰 비용). 또한 이 두 경로는 ~135 LOC 중복: 모든 reviewer-persona 편집이 두 곳에서 drift 가능.

**Files to Modify:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md`:
  - L515-548 + L550-599 → 단일 dispatch builder 함수로 통합. fallback flag가 prompt suffix만 영향, dispatch list/게이트 로직은 공통.
  - AskUserQuestion 게이트를 `phase1_agents ∪ external_reviewers ∪ phase2_agents` 최종 dispatch list 결정 직후로 이동.
  - L554의 "intentional"은 삭제 (반대 방향 reasoning이 옳음).
- `plugins/quality-gates/tests/test_scout_codex_integration.sh` — fallback path도 게이트 발동 검증 추가.

**Acceptance criteria:**
- AC6: scout-fallback path의 4-reviewer dispatch가 AskUserQuestion을 fire.
- AC7: dispatch builder는 단일 호출 (Phase 1 prompt template 중복 0).
- AC8: `test_codex_dispatch_invariant.sh`의 grep anchor가 통합된 단일 dispatch block에서 여전히 매칭.

### T2-3. Pipeline wall-clock budget (`F-5`)

**Why:** CLAUDE.md `P18 anti-corollary` 4가드 중 wall-clock budget만 부재. 병리적 scout-fallback × codex × NEEDS_RESOLUTION 조합이 사용자를 30+ 분간 `/qg`에 묶을 수 있음.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` — 모든 gate-transition 진입에서 `now - started_at > DEVBREW_QG_DEADLINE_MIN` 검사 (default 30, env override, `0`=disabled). 초과 시 user-choice prompt (extend +10m / accept-with-warnings / abort).
- `plugins/quality-gates/scripts/setup-qg.sh` — state frontmatter `wall_clock_deadline_at` 기록.
- `README.md` §설정 — env var 추가.

**Acceptance criteria:**
- AC9: deadline 초과 시 user-choice prompt 발동, default action 없이 정지.
- AC10: `DEVBREW_QG_DEADLINE_MIN=0` 설정 시 기존 동작 (deadline 검사 안 함).
- AC11: 새 unit test in `test_stop_hook_state_machine.py` — fake clock으로 deadline 초과 inject 후 transition type 검증.

### T2-4. Stop-hook no-signal infinite re-injection counter (`U-8`)

**Why:** 모델이 `<qg-signal>`을 emit 안 한 turn이 연속될 때 stop-hook가 영원히 동일 prompt를 re-inject. `max_gate2_iterations`는 verdict 있는 iteration만 카운트하므로 cover 못함.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` — state file의 `consecutive_no_signal` 필드 증가/리셋. `≥3` 도달 시 user-choice prompt ("stuck — abort?").
- `plugins/quality-gates/scripts/setup-qg.sh` — 초기화.
- `tests/test_stop_hook_state_machine.py` — 3-연속 empty-signal fixture.

**Acceptance criteria:**
- AC12: 3개 연속 no-signal turn에서 abort-prompt 발동.
- AC13: 유효 signal 받으면 counter 0 리셋.

### T2-5. Codex 미설치 시 loud skip (`U-9`)

**Why:** `detect_codex.sh`가 `skip_reason`을 emit하지만 SKILL.md가 사용자에게 안 surface. CLAUDE.md `loud logging을 동반한 graceful degradation` 약속 위반. 사용자가 Codex 구독 비용을 내고도 dispatch 안 되는 이유를 모름.

**Files to Modify:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L484 — `[quality-gates] codex-reviewer skipped: $skip_reason`을 stderr로 출력. actionable reason (`auth_missing`, `not_installed`, `timeout_binary_missing`)은 inline 안내.

**Acceptance criteria:**
- AC14: codex_available=false일 때 정확히 1번의 사용자-가시 메시지.
- AC15: kill-switch 경로(`DEVBREW_DISABLE_QG_CODEX=1`)는 안내 없음 (의도된 disable).

### T2-6. State-write 실패 시 forward-progress routing (`U-10`)

**Why:** `update_state_file` 예외가 `gate3_needs_resolution`/`gate3_repeat_detected`에서만 PIPELINE_ERROR로 라우팅. `next_gate`/`retry_gate` 실패 시 stale in-memory state로 fall through → counter drift, 무한 replay.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` L912-925 — 조건 broaden: `transition['type'] not in ('complete', 'abort')` → PIPELINE_ERROR.

**Acceptance criteria:**
- AC16: 임의 forward-progress transition에서 write 실패 → PIPELINE_ERROR.
- AC17: `complete`/`abort` 경로의 write 실패는 silent (이미 terminal — 손실 0).

### T2-7. README state-machine diagram (Mermaid) (`A-3`)

**Why:** stop-hook이 8개 transition type을 가지지만 README는 4-arrow 선형 flow만 표시. 신규 contributor가 forward-only 약속(NEEDS_RESTART → user gate, not auto-retry)을 못 봄.

**Files to Modify:**
- `plugins/quality-gates/README.md` §파이프라인 흐름 — Mermaid `stateDiagram-v2` 블록 (8 transitions + terminal + user-choice intercepts).

**Acceptance criteria:**
- AC18: 모든 8 transition type이 diagram에 표시.
- AC19: terminal states (`completed`, `aborted`)와 user-choice intercepts 별도 마킹.

### T2-8. Adversarial cost prompt + downgrade (`A-4`)

**Why:** adversarial agent는 opus + AskUserQuestion 카운트 제외 → 사용자가 "4 agents" prompt에 동의했는데 실제로는 6+ dispatch. 동시에 adversarial의 task는 calibration (verdict mapping)이지 generation 아님 — opus는 over-spec.

**Files to Modify:**
- `plugins/quality-gates/agents/adversarial.md` frontmatter — `model: opus` → `model: sonnet`. 또는 model 유지하고 AskUserQuestion 카운트에 포함.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L497 — 카운트 정책 명시.

**Acceptance criteria:**
- AC20: 사용자 동의 시점에 보이는 fan-out 숫자가 실제 dispatch 수와 일치.
- AC21: model downgrade 시 기존 adversarial test (`test_findings_parser.sh` 등) 통과.

---

## Tier 3 — Refactor (별도 PR cluster)

### T3-1. scout-as-script (`A-8`)

**Why:** scout의 depth-decision은 `scout.md` L42-44에 결정적 테이블로 명시. agent dispatch (~5-15K input + 500 output, opus 또는 sonnet)을 60줄 Python 휴리스틱으로 대체 가능. Step 0 JSON에 이미 모든 신호 (CHANGED_LINE_COUNT, NEW_FILES, CONFIG_TOUCHED, TYPE_DESIGN, TEST_CHANGE) 있음.

**Files to Modify:**
- `plugins/quality-gates/scripts/scout.py` (신규) — 60줄.
- `plugins/quality-gates/agents/scout.md` 삭제 또는 fallback-only로 격하.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Bash dispatch로 교체.

**Trade-off:** LLM 판단을 잃지만 결정적 테이블이 이미 LLM 판단을 거의 대체. fallback path (deterministic)가 이미 production 경로로 검증됨 — 사실상 primary path를 fallback과 통합하는 것.

### T3-2. synthesizer-as-script (`A-5`)

**Why:** synthesizer의 알고리즘은 `synthesizer.md` L23-31에 5단계 결정적 절차 (dedup + apply-verdict + sort + suppress<7). LLM 판단 없음. 모든 input은 adversarial.yaml + raw findings.yaml로 이미 구조화됨.

**Files to Modify:**
- `plugins/quality-gates/scripts/synthesize_findings.py` (신규) — adversarial.yaml + findings.yaml → Markdown.
- `plugins/quality-gates/agents/synthesizer.md` 삭제.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` Phase 1.6 분기 → Bash.

### T3-3. codex-reviewer-as-script (`A-11`)

**Why:** codex-reviewer agent body는 75줄의 mechanical bash. LLM 판단 0. Layer 1 (`disallowedTools`)은 SKILL.md의 Bash allowlist로 대체 가능.

**Files to Modify:**
- `plugins/quality-gates/scripts/run_codex_reviewer.sh` (신규).
- `plugins/quality-gates/agents/codex-reviewer.md` 삭제.
- SKILL.md L483 — Task dispatch → Bash invocation.

**Verification:** 기존 `test_codex_dispatch_invariant.sh`, `test_codex_reviewer_frontmatter.sh`, `test_scout_codex_integration.sh` 모두 anchor 갱신 필요.

### T3-4. 8 leaf agent behavioral test backfill (`A-2`)

**Why:** 현재 8 agent 중 1개만 behavioral test 보유. 7개는 frontmatter grep만. v1.11.1 silent-drop 버그가 user runtime에서만 잡힌 전례 — Law 3 compounding의 핵심 인프라가 비어있음.

**Files to Modify:**
- `plugins/quality-gates/tests/test_{plan_verifier,security_reviewer,adversarial,synthesizer,scout,codex_reviewer,test_scope_validator,runtime_verifier}_behavior.sh` (8개; 3-4개는 Tier 3 refactor와 함께 사라질 수 있음 — refactor 후 backfill).
- 각 test: minimal fixture (frozen prompt) → stub Agent harness → YAML output schema assertion.

**Acceptance criteria per agent:**
- 정확한 verdict enum (PASS/FAIL/SKIP/...) emit.
- `disallowedTools` / `allowedTools` frontmatter가 prompt-level invariant와 일치 (예: synthesizer의 ≤7 suppress except CRITICAL).
- 입력 누락 시 graceful error (not silent skip).

### T3-5. Phase 1 dual-dispatch 통합 (T2-2와 연동) (`A-1`)

T2-2가 dispatch builder를 만들 때 함께 land. Tier 3가 아니라 T2-2의 부산물이지만, ~135 LOC dedup이라 별도 finding으로 남김.

---

## Rejected Alternatives

- **scout/synthesizer agent를 통합해서 단일 "review-arbiter" agent로**: agent 수는 줄지만 LLM 판단 (있지도 않은) 가짜를 합쳐 더 큰 dispatch가 됨. script 분리가 더 정직.
- **trivia detection을 LLM-based로 격상**: 정확도↑이지만 매번 LLM call이 cost surprise. CLAUDE.md *trivia escape*은 cheap-by-design.
- **wall-clock budget을 hook hardcoded 30분**: env override 없으면 강제 — power user의 long-running pipeline (large codebase deep review)이 막힘. `DEVBREW_QG_DEADLINE_MIN=0` opt-out 필수.

## Verification Plan (cross-cutting)

각 Tier 2/3 PR은:

1. **Tier 1 회귀 검증** — README/persona/cancel-qg 가드 변경이 풀리지 않음.
2. **Existing test suite green** — `bash plugins/quality-gates/tests/test_*.sh` + `python3 -m pytest plugins/quality-gates/tests/test_*.py`.
3. **신규 acceptance criteria 별 unit test** (위 AC 번호 명시).
4. **E2E sanity** — `tests/e2e-scenarios.md`의 한 scenario를 실제 `/qg`로 실행 + commit.
5. **Persona-as-security-code review** — adversarial agent / security-reviewer / runtime-verifier persona를 weaken하는 PR은 explicit security-review 패스.

## Order of Land

권장 순서 (의존성):

1. **T2-3** (wall-clock budget) — 후속 PR이 deadlines를 안전하게 hit할 수 있게.
2. **T2-4** (no-signal counter) — 후속 디버깅 중 stuck loop을 막아줌.
3. **T2-1** (trivia 확장) — independent.
4. **T2-2 + A-1** (fan-out 게이트 + dual-dispatch dedup) — 결합 PR.
5. **T2-5, T2-6, T2-7, T2-8** — independent, parallelizable.
6. **T3-3** (codex-reviewer-as-script) — 가장 작은 refactor, 위험 낮음.
7. **T3-2** (synthesizer-as-script).
8. **T3-1** (scout-as-script) — 가장 큰 surface 변경; T2-2와 통합 가능.
9. **T3-4** (behavioral test backfill) — 위 refactor 후 새 surface에서 testify.

각 PR은 plugin.json minor bump, CHANGELOG entry, "Principles Instantiated" 추가/갱신.
