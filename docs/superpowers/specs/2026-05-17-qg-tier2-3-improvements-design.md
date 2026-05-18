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

- **PR 수 + 버전 범위 추정**: Tier 2 = 9 PR (T2-1..8 + T2-9 color), Tier 3 = 4 PR (T3-1/2/3/4; T3-5는 T2-2 안에 absorbed). 추가로 T3-4 선행 stub harness 1 PR. 총 **14 PR**. 각 PR이 plugin.json minor bump이므로 본 design 완수 후 도달 버전은 **`v1.30.0`** (현재 `v1.16.0` + 14 minor). 단, Tier 3 후 일부 PR이 patch bump으로 가능한 경우 (refactor 보조 fix) 도달 버전은 더 낮음. **upper bound `v1.30.0`, lower bound `v1.22.0`** (모든 Tier 3 보조 fix가 patch일 때).
- **CHANGELOG 분리**: 모든 변경은 reviewer-persona 약화로 보이지 않도록 CHANGELOG의 `### Security` / `### Changed` / `### Removed` 분리 유지.
- **Grep-anchored test 영향**: Phase 1 dual-dispatch 통합 (T2-2) 은 `test_codex_dispatch_invariant.sh`, `test_forward_only_prose.sh` 의 anchor와 충돌. **재발급 전략**: 새 통합 section header `### Phase 1 (unified dispatch)` 의 ±20 line 윈도 안에 기존 anchor pattern 재배치, 본 PR에서 test도 함께 갱신 (AC9 참조).
- **Tier 3 isolation 보존**: script-replaces-agent refactor (T3-1/2/3) 는 Law 2 layer-1 (`disallowedTools` frontmatter) 의 default tool-scope를 잃지 않도록 SKILL.md frontmatter `allowed-tools` Bash 항목을 좁게 명시 — 광역 `Bash(*)` 금지, `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/<exact-script>:*)` 형식만 허용.

---

## Tier 2 — Correctness fixes

각 항목은 한 PR로 land 가능; 의존성 명시.

### T2-1. Trivia escape coverage 확장 (`F-1`, `U-1`)

**Why:** CLAUDE.md `P12 anti-corollary` 정의는 typo / rename / comment-only / single-file formatting의 4-axis cover를 약속하지만 `scripts/check-trivia.sh`는 whitespace + rename 2-axis만 cover. 또한 `--paths` scope 인자가 SKILL.md L122에서 trivia 스크립트로 전파되지 않아 user-supplied scope가 무시됨. Untracked single-file (new test fixture 같은) 케이스는 `git diff HEAD --name-only`가 보지 못해 untrivial로 fall through.

**Files to Modify:**
- `plugins/quality-gates/scripts/check-trivia.sh` — comment-only detector (per-language comment regex over unified diff: `^[+-]\s*(#|//|--|/\*)` 그룹), typo detector (single-token same-length replace), `--paths` flag 수용, `git ls-files --others --exclude-standard` 결합으로 untracked 새 파일도 detect.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L~122 — `check-trivia.sh`에 `--paths "$(cat $QG_DIR/code-paths.tmp)"` 전파.
- `plugins/quality-gates/tests/test_check_trivia.sh` (신규) — fixture 기반: comment-only single-file, typo only, untracked new file, --paths-narrowed scope.

**Script output contract (현재 + 확장 후 공통):**

- 성공(trivia 자격): `exit 0` + stdout `trivia: <kind>` 한 줄. `<kind>` enum: `whitespace`, `rename`, **`comment`** (신규), **`typo`** (신규), **`untracked-newfile`** (신규).
- 실패(not trivia): `exit 1`. stdout 없음.

**Acceptance criteria** (모두 fixture-based: 임시 git repo + `git diff HEAD` setup + `check-trivia.sh` 호출 + exit code/stdout assert):

- AC1: 단일 파일의 단일 comment-line 변경 (`^[+-]\s*(#|//|--|/\*)` regex 매칭, 1줄만 변경)에서 `exit 0` + stdout 정확히 `trivia: comment\n`.
- AC2: 단일 파일 within `--paths` scope의 single-token substitution에서 `exit 0` + stdout 정확히 `trivia: typo\n`. **typo 자격 정의 (hard constraint)**: (i) 변경된 line 수 == 1, (ii) 변경된 line의 토큰화(`split on \s+,.;()[]{}`) 후 정확히 1개 토큰만 다름, (iii) 다른 토큰의 길이 차 ≤ 2 (예: `colour → color`, `userId → userPid` OK; `userID → userIdentifier` 거부 — 후자는 *rename*이지 typo가 아님; rename은 T2-1 scope 밖이며 기존 trivia 'rename' kind이 따로 cover). 이 세 조건 모두 충족 시에만 `typo` kind 부여; 하나라도 미충족이면 `exit 1` (not trivia). Rejected Alternative §A.7 참조.
- AC3: `git ls-files --others --exclude-standard`로 발견된 untracked 단일 새 파일이 ≤3줄이고 모든 줄이 (a) 빈 줄, (b) 주석 regex 매칭, (c) shebang 중 하나일 때 `exit 0` + stdout 정확히 `trivia: untracked-newfile\n`. 여기서 "trivia 자격"이란 **위 (a)/(b)/(c) 셋 중 하나에만 매칭**으로 정의 (즉, 새 함수 정의·import·assignment는 trivia 자격 부재).
- AC4: `--paths "<path1> <path2>"`로 호출 시 `gd()`는 `git diff HEAD -- <path1> <path2>`로 좁혀짐. scope 밖 dirty 파일이 추가로 있어도 trivia 판정에 영향 없음 — 두 dirty 파일 (scope-in trivia + scope-out non-trivia) fixture로 검증.
- AC5: 새 `### Trivia detector coverage` subsection이 README.md에 존재하고, 5-row 표 `kind | regex/조건 | example positive | example negative`로 모든 enum kind를 매핑.
- AC6: 기존 `whitespace`/`rename` 두 case는 regression — script가 이전과 정확히 같은 stdout/exit를 emit.

**Verification plan:** 신규 `tests/test_check_trivia.sh` 6 fixture (AC1–AC6 각 1개), + 기존 `tests/test_setup_qg.sh` trivia case 회귀. CI: `bash plugins/quality-gates/tests/test_check_trivia.sh` exit 0 + 6/6 PASS.

### T2-2. Scout fallback AskUserQuestion 게이트 통합 (`F-2`, `U-2`, `A-1`)

**Why:** scout-primary 경로(L497)는 fan-out ≥ 4일 때 AskUserQuestion 발동. scout-fallback 경로(L550-599)는 같은 4-reviewer dispatch를 하면서 게이트를 *의도적으로* skip. 사용자는 정상 경로보다 degraded 경로에서 더 friction을 받아야 마땅 (덜 정확한 review에 더 큰 비용). 또한 이 두 경로는 ~135 LOC 중복: 모든 reviewer-persona 편집이 두 곳에서 drift 가능.

**Files to Modify:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md`:
  - L515-548 + L550-599 → 단일 dispatch builder 함수로 통합. fallback flag가 prompt suffix만 영향, dispatch list/게이트 로직은 공통.
  - AskUserQuestion 게이트를 `phase1_agents ∪ external_reviewers ∪ phase2_agents` 최종 dispatch list 결정 직후로 이동.
  - L554의 "intentional"은 삭제 (반대 방향 reasoning이 옳음).
- `plugins/quality-gates/tests/test_scout_codex_integration.sh` — fallback path도 게이트 발동 검증 추가.

**구조 결정 (lock):** "dispatch builder"는 SKILL.md prose 내의 *단일 section header*로 정의 — 정확히 `### Phase 1 (unified dispatch)` heading이 SKILL.md에 1회만 등장하고, 그 아래에 dispatch list 결정 로직 + AskUserQuestion 게이트 + Task() invocation prose가 일렬로 배치됨. 즉 grep-able invariant: 이 heading의 count = 1, 그 위/아래에 별도 "Phase 1 (legacy/fallback)" 등 중복 dispatch heading 0회.

**Acceptance criteria:**

- AC7-a: `grep -c '^### Phase 1 (unified dispatch)' SKILL.md` == 1.
- AC7-b: `grep -c '^### Phase 1 (legacy/fallback)' SKILL.md` == 0 (제거 확인).
- AC7-c: 단일 dispatch block 안에 정확히 한 번의 `AskUserQuestion(` 호출과 한 번의 `Task(...)` 병렬 dispatch prose가 등장 — grep으로 검증.
- AC8 (재정의): scout-fallback path의 4-reviewer dispatch에서도 AC7-c의 AskUserQuestion이 trigger됨. **구체 grep 검증** — `tests/test_scout_codex_integration.sh`에 Scenario 5 추가:
  - Setup: scout step 0 JSON fixture를 `fallback: true`로 설정.
  - Step 1: `awk '/^### Phase 1 \(unified dispatch\)/,/^### /' plugins/quality-gates/skills/quality-pipeline/SKILL.md` 로 unified dispatch 블록을 추출.
  - Step 2: 추출된 블록에서 `grep -c 'AskUserQuestion('` ≥ 1 (게이트 prose 존재).
  - Step 3: 같은 블록에서 `grep -cE 'fallback|scout.depth'` ≥ 1 (fallback path 분기 명시).
  - Step 4: legacy heading 부재 — `grep -c '^### Phase 1 (legacy/fallback)' SKILL.md` == 0 (AC7-b와 redundant verification).
  네 step 모두 PASS 시 Scenario 5 통과.
- AC9 (재정의, 기존 AC8 대체): 기존 `test_codex_dispatch_invariant.sh` Scenario 1–4 모두 통합된 단일 dispatch block 안에서 매칭. **anchor 재발급 전략:** 기존 grep pattern (`phase1_agents.*\[.*code-reviewer.*silent-failure-hunter.*feature-dev:code-reviewer.*\]`)이 single dispatch heading의 ±20 line 윈도 안에 등장하도록 invariant test를 prose walk으로 갱신. test 자체도 본 PR에서 함께 수정.

### T2-3. Pipeline wall-clock budget (`F-5`)

**Why:** CLAUDE.md `P18 anti-corollary` 4가드 중 wall-clock budget만 부재. 병리적 scout-fallback × codex × NEEDS_RESOLUTION 조합이 사용자를 30+ 분간 `/qg`에 묶을 수 있음.

**구조 결정 (lock):** Deadline 검사는 `main()` 내부의 별도 분기 — `compute_transition()`은 **pure function 계약 유지** (현재 docstring "Pure function: no I/O, no globals" 보존). main() 흐름:
1. `parse_state_file` → state read (이미 io)
2. `parse_signal` → signal extraction
3. `compute_transition(state, signal)` → pure, returns dict
4. **NEW**: `if deadline_exceeded(state): transition = {"type": "wall_clock_exceeded", ...}` — main()의 분기, `datetime.now(timezone.utc)` 사용
5. `update_state_file(state, transition)` → io
6. emit_continuation

`deadline_exceeded(state)`는 module-level helper (pure 입력만 state dict + optional `now` parameter). test에서 `now` arg 주입 → monkeypatch 불필요.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` — module-level `def deadline_exceeded(state, now=None) -> bool` 추가 (`now` 인자 inject 가능). main() 흐름 4번 단계 신설. user-choice prompt 발동 시 `<qg-signal verdict="wall-clock-exceeded">` action 신설 또는 GATE_DEADLINE prompt template inline.
- `plugins/quality-gates/scripts/setup-qg.sh` — state frontmatter에 `wall_clock_deadline_at: "<ISO8601>"` 기록 (현재 `started_at`만 있음). `DEVBREW_QG_DEADLINE_MIN=N` env override (default 30, `0`=disabled).
- `plugins/quality-gates/README.md` §설정 §Tuning knobs — `DEVBREW_QG_DEADLINE_MIN` 행 추가.

**Acceptance criteria** (모두 `tests/test_stop_hook_state_machine.py`에 pytest fixture로 추가):

- AC10: `state = {"wall_clock_deadline_at": "2026-05-17T12:00:00Z", ...}` + `now = datetime(2026,5,17,12,0,1,tzinfo=utc)` → `deadline_exceeded(state, now=now)` returns True.
- AC11: 같은 state + `now = datetime(2026,5,17,11,59,59,tzinfo=utc)` → returns False.
- AC12: `state = {}` (deadline field 부재) → returns False (graceful — feature off).
- AC13: `DEVBREW_QG_DEADLINE_MIN=0` 환경에서 `setup-qg.sh --ensure` 실행 시 state frontmatter에 `wall_clock_deadline_at` 키 **부재** (또는 빈 문자열) — feature off semantics.
- AC14: main() 통합 테스트 fixture — deadline exceeded state + 임의 verdict signal → `update_state_file` 호출 시 transition type `"wall_clock_exceeded"` 가 우선.

### T2-4. Stop-hook no-signal infinite re-injection counter (`U-8`)

**Why:** 모델이 `<qg-signal>`을 emit 안 한 turn이 연속될 때 stop-hook가 영원히 동일 prompt를 re-inject. `max_gate2_iterations`는 verdict 있는 iteration만 카운트하므로 cover 못함.

**구조 결정 (lock, Rejected Alternatives §A.3 참조):** `gate2_iteration`을 재사용하지 않고 별도 state field `consecutive_no_signal` 신설. 이유: `gate2_iteration`은 verdict 받은 round만 카운트 (Gate 1/3에서도 의미 없음); no-signal은 전 게이트 cross-cutting 현상.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` — main() 흐름에서 signal parse 후 `signal == None` 분기에 카운터 +1, 유효 signal에 0 리셋. `≥ DEVBREW_QG_NO_SIGNAL_MAX` (default 3) 도달 시 user-choice prompt template emit.
- `plugins/quality-gates/scripts/setup-qg.sh` — frontmatter에 `consecutive_no_signal: 0` 초기화.
- `plugins/quality-gates/README.md` §설정 — env var 추가.
- `plugins/quality-gates/tests/test_stop_hook_state_machine.py` — fixture 추가.

**Acceptance criteria** (pytest fixture):

- AC15: state `consecutive_no_signal: 2` + `signal = None` → transition type `"no_signal_inc"`, state field 3으로 증가.
- AC16: state `consecutive_no_signal: 3` + `signal = None` → transition type `"no_signal_max"`, user-choice prompt 발동.
- AC17: 임의 유효 signal 받으면 `consecutive_no_signal` 0 리셋 (state.transition을 통해 확인).
- AC18: `DEVBREW_QG_NO_SIGNAL_MAX=0` 환경에서 feature off — 이 분기 자체가 skip. **Edge case lock**: 두 stuck-state 보호 (T2-3 wall-clock + T2-4 no-signal)을 *동시에* off (`DEVBREW_QG_DEADLINE_MIN=0` + `DEVBREW_QG_NO_SIGNAL_MAX=0`) 하는 것은 "power user opt-out — 자동 stuck 탐지 모두 disable" 모드로 명시적 지원. 이 조합에서는 stop-hook가 어떤 stuck-state 탐지도 하지 않음 (사용자 명시 `/cancel-qg` 외 종료 방법 없음). Rejected Alternative §A.8 참조 — 두 kill switch 중 하나라도 활성화되어야 강제하는 hard-fail은 거부 (kill switch는 user sovereignty이고 둘 다 off는 power user의 명시 선택).
- AC18b: `DEVBREW_QG_NO_SIGNAL_MAX=0` + `DEVBREW_QG_DEADLINE_MIN=0` 환경에서 stop-hook가 no-signal turn 시 transition type `"continue"` (re-inject) 만 emit, 어떤 user-choice prompt도 발동하지 않음. 의도된 power-user 모드 fixture로 검증. (AC19로 시작되는 T2-5와의 충돌 회피를 위해 AC18b로 명명.)

### T2-5. Codex 미설치 시 loud skip (`U-9`)

**Why:** `detect_codex.sh`가 `skip_reason`을 emit하지만 SKILL.md가 사용자에게 안 surface. CLAUDE.md `loud logging을 동반한 graceful degradation` 약속 위반. 사용자가 Codex 구독 비용을 내고도 dispatch 안 되는 이유를 모름.

**skip_reason 전체 enum** (`scripts/detect_codex.sh` 참조, 6값): `kill_switch`, `inside_codex_sandbox`, `not_installed`, `auth_missing`, `timeout_binary_missing`, `known_bad_version`.

**구조 결정 (lock):** "사용자-가시"는 *SKILL.md prose에 명시된 stderr emit 패턴*으로 정의. grep으로 검증 가능. 메시지 noise 정책:

| skip_reason | 사용자-가시 메시지? | 이유 |
|---|---|---|
| `kill_switch` | ❌ 안내 없음 | 사용자가 명시 disable함 — noise만 추가 |
| `inside_codex_sandbox` | ❌ 안내 없음 | 재귀 가드, 정상 동작 |
| `not_installed` | ✅ "Codex CLI not installed; model-family diversity layer skipped." |
| `auth_missing` | ✅ "Codex CLI detected but auth missing; set CODEX_API_KEY/OPENAI_API_KEY or run `codex login`." |
| `timeout_binary_missing` | ✅ "Codex skipped: no `timeout`/`gtimeout` binary (install coreutils)." |
| `known_bad_version` | ✅ "Codex version known-bad ({version}); upgrade." |

**Files to Modify:**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L484 — 위 표에 따라 prose에 6-way switch (kill_switch/inside_codex_sandbox는 silent, 나머지 4는 stderr emit).

**Acceptance criteria** (grep-based on SKILL.md prose; integration test는 codex 환경 의존성 때문에 deferred):

- AC19: SKILL.md L484 근방 ±30 line 윈도 안에 다음 정확히 4개 메시지 패턴이 grep으로 발견됨 — `not_installed`, `auth_missing`, `timeout_binary_missing`, `known_bad_version` 각각의 사용자-가시 prose 문구가 1회씩.
- AC20: 동일 윈도 안에 `kill_switch` / `inside_codex_sandbox`에 매칭되는 사용자-가시 prose 문구는 0회 (정확한 grep으로 확인 — "noise suppression" 정책 유지).
- AC21: `tests/test_skill_codex_skip_prose.sh` 신규 — 위 6 enum × {visible/silent} 매트릭스를 SKILL.md prose에서 검증.

### T2-6. State-write 실패 시 forward-progress routing (`U-10`)

**Why:** `update_state_file` 예외가 `gate3_needs_resolution`/`gate3_repeat_detected`에서만 PIPELINE_ERROR로 라우팅. `next_gate`/`retry_gate` 실패 시 stale in-memory state로 fall through → counter drift, 무한 replay.

**Files to Modify:**
- `plugins/quality-gates/hooks/stop-hook.py` L912-925 — 조건 broaden: `transition['type'] not in ('complete', 'abort')` → PIPELINE_ERROR.
- `plugins/quality-gates/tests/test_stop_hook_state_machine.py` — AC22/23 fixture 추가.
- `plugins/quality-gates/tests/test_failure_injection.sh` — AC22 end-to-end fixture: state file을 read-only로 chmod한 뒤 next_gate transition을 trigger, PIPELINE_ERROR 응답 검증.

**Acceptance criteria** (pytest + bash fixture):

- AC22: pytest fixture — `transition = {"type": "next_gate", ...}` + monkeypatch `update_state_file` to raise → main() flow에서 PIPELINE_ERROR system message 발화 + emit_continuation 호출되지 않음.
- AC23: pytest fixture — `transition = {"type": "complete", ...}` + monkeypatch `update_state_file` to raise → silent path (이미 terminal). stderr에는 warning만, PIPELINE_ERROR systemMessage 없음.
- AC24: integration — `test_failure_injection.sh`에 read-only state-file 케이스 추가; stop-hook이 `forward-progress write failure → PIPELINE_ERROR` 메시지를 stderr로 emit하고 exit code 0 (사용자 input 대기).

**Verification plan:** 위 3 AC를 `python3 -m pytest plugins/quality-gates/tests/test_stop_hook_state_machine.py -k 'state_write_failure'` 및 `bash plugins/quality-gates/tests/test_failure_injection.sh` 로 검증. 두 명령 모두 exit 0 + 새 fixture 100% PASS.

### T2-7. README state-machine diagram (Mermaid) (`A-3`)

**Why:** stop-hook이 8개 transition type을 가지지만 README는 4-arrow 선형 flow만 표시. 신규 contributor가 forward-only 약속(NEEDS_RESTART → user gate, not auto-retry)을 못 봄.

**Transition type 완전 enumeration** (stop-hook.py `compute_transition()` 기준, T2-3/T2-4 추가 포함; 본 design의 single-source-of-truth):

| # | Transition type | Origin gate | Terminal? |
|---|---|---|---|
| 1 | `next_gate` | 1→2, 2→3 | no |
| 2 | `retry_gate` | 2 (Gate 2 fix-loop) | no |
| 3 | `complete` | any | yes (status=completed) |
| 4 | `abort` | any | yes (status=aborted) |
| 5 | `continue` | 2 (scout fallback) | no |
| 6 | `gate2_user_choice` | 2 (NEEDS_RESTART user prompt) | no |
| 7 | `max_gate2_exceeded` | 2 | no (user choice intercept) |
| 8 | `gate3_fail` | 3 | no (user choice intercept) |
| 9 | `gate3_needs_resolution` | 3 (mid-run loop) | no |
| 10 | `gate3_repeat_detected` | 3 | no (user choice intercept) |
| 11 | `wall_clock_exceeded` | any (T2-3, NEW) | no (user choice intercept) |
| 12 | `no_signal_inc` | any (T2-4, NEW) | no |
| 13 | `no_signal_max` | any (T2-4, NEW) | no (user choice intercept) |

**13 transition** (이전 design 본문 "8"은 오류 — AC25에서 grep 검증으로 강제).

**Files to Modify:**
- `plugins/quality-gates/README.md` §파이프라인 흐름 — Mermaid `stateDiagram-v2` 블록. 13 transition + 2 terminal state + 6 user-choice intercept arrow를 모두 표기.

**Acceptance criteria** (모두 grep-based):

- AC49: `grep -E '(next_gate|retry_gate|complete|abort|continue|gate2_user_choice|max_gate2_exceeded|gate3_fail|gate3_needs_resolution|gate3_repeat_detected|wall_clock_exceeded|no_signal_inc|no_signal_max)' plugins/quality-gates/README.md | wc -l` ≥ 13 (Mermaid 블록 내 등장).
- AC50: `grep -c 'stateDiagram-v2' plugins/quality-gates/README.md` == 1 (정확히 한 Mermaid 다이어그램).
- AC51: `grep -cE '\[\*\]|completed|aborted' plugins/quality-gates/README.md` ≥ 2 (terminal state marker, Mermaid syntax `[*]` 사용 시).
- AC52: design 본문의 transition table과 README diagram의 transition 집합이 *정확히 일치* (집합 동등성, 중복 무관). 신규 `tests/test_readme_state_diagram_complete.sh` 구체 구현:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  PATTERN='\b(next_gate|retry_gate|complete|abort|continue|gate2_user_choice|max_gate2_exceeded|gate3_fail|gate3_needs_resolution|gate3_repeat_detected|wall_clock_exceeded|no_signal_inc|no_signal_max)\b'
  # README의 Mermaid stateDiagram-v2 블록만 추출하여 transition 이름 집합 추출
  README_SET=$(awk '/^```mermaid$/,/^```$/' plugins/quality-gates/README.md \
    | grep -oE "$PATTERN" | sort -u)
  # 기대 집합 (본 design 13-row 표와 1:1)
  EXPECTED_SET=$(printf '%s\n' \
    next_gate retry_gate complete abort continue gate2_user_choice \
    max_gate2_exceeded gate3_fail gate3_needs_resolution gate3_repeat_detected \
    wall_clock_exceeded no_signal_inc no_signal_max | sort -u)
  # 양방향 차집합 모두 비어 있어야 통과
  diff <(echo "$README_SET") <(echo "$EXPECTED_SET")
  ```
  exit code 0 + 양방향 차 0이면 PASS. README diagram에 누락된 transition이나 superset 추가 모두 fail (drift detection).

### T2-8. Adversarial cost prompt + downgrade (`A-4`)

**Why:** adversarial agent는 opus + AskUserQuestion 카운트 제외 → 사용자가 "4 agents" prompt에 동의했는데 실제로는 6+ dispatch. 동시에 adversarial의 task는 calibration (verdict mapping)이지 generation 아님 — opus는 over-spec.

**구조 결정 (lock):** **model downgrade 경로 선택** (`adversarial.md` frontmatter `model: opus` → `model: sonnet`). 이유:

1. **Cost 회수 가장 큼** — sonnet은 opus 대비 ~5× 저렴. adversarial은 매 Gate 2 iter마다 호출되므로 5-iter loop에서 절약 ~$0.40-0.80.
2. **Task 적합성** — adversarial의 작업은 calibration (verdict mapping: confirm/downgrade/reject). 새 generation이 아닌 *판단* 작업이라 sonnet 충분.
3. **AskUserQuestion noise 절약** — count 포함 경로는 사용자 prompt 숫자가 매번 ~7로 표시되어 cost-fatigue 유발. downgrade 경로는 prompt 숫자 유지 + 비용 자체 절약.

**대안 거부 근거** (Rejected Alternatives §A.4 참조): "count 포함" 경로는 AC가 prose-only AskUserQuestion 문구 검증으로 reduce되어 testable하지만 cost는 그대로.

**Files to Modify:**
- `plugins/quality-gates/agents/adversarial.md` frontmatter — `model: opus` → `model: sonnet`.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L497 근방 — AskUserQuestion fan-out count 정책 prose에 명시: "scout/adversarial/synthesizer는 sonnet 기반 infrastructure dispatch — 사용자 prompt에 표시되는 카운트에서 제외" (현재 implicit, post-fix 명시화).
- `plugins/quality-gates/README.md` "Cost Class" 섹션 — adversarial이 sonnet으로 다운그레이드된 이유 한 줄 기록 (compounding).

**Acceptance criteria** (모두 grep-based on agents/adversarial.md, SKILL.md, README.md):

- AC25: `grep '^model: sonnet' plugins/quality-gates/agents/adversarial.md` 매칭 == 1 (frontmatter 값 변경).
- AC26: `grep 'adversarial.*sonnet\|sonnet.*adversarial' plugins/quality-gates/README.md` 매칭 ≥ 1 (cost 섹션에 기록).
- AC27: 기존 `tests/test_findings_parser.sh`의 adversarial verdict mapping 회귀 통과 — model downgrade가 verdict enum (confirm/downgrade/reject) 출력 형식을 깨지 않음.
- AC28: `tests/test_agent_frontmatter_keys.sh` 통과 — frontmatter key validation 유지.

### T2-9. Subagent color frontmatter discipline (`U-13`, 사용자 요청)

**Why:** 현재 qg agent 8개 중 **5개가 `color:` frontmatter 부재** — `adversarial`, `codex-reviewer`, `scout`, `security-reviewer`, `synthesizer`. Claude Code UI는 agent dispatch 시 color로 thread를 구분하므로 부재 agent들은 default(흰색/회색)로 표시되어 *다중 agent 병렬 dispatch 시 시각적 구분 불가* — Gate 2 deep dispatch에서 5+ agent가 동시에 fire할 때 사용자가 어떤 thread가 어떤 reviewer인지 식별 어려움. 동일 plugin (`spec-distill`)은 모든 agent에 color 부여 (`breadth-keeper: blue`, `spec-reviewer: orange`) — qg는 partial.

**Color 할당 (lock)** — 의미적 grouping 기반:

| Agent | 현재 | 신규 color | 근거 |
|---|---|---|---|
| `plan-verifier` | cyan | (유지) | Gate 1 — 차분한 분석 |
| `runtime-verifier` | green | (유지) | Gate 3 — 실행/PASS 의미 |
| `test-scope-validator` | yellow | (유지) | Gate 3 advisory — warning hue |
| `scout` | (없음) | **purple** | Gate 2 planner — neutral leadership |
| `security-reviewer` | (없음) | **red** | Phase 1 always-run — 보안 위협 hue |
| `adversarial` | (없음) | **orange** | Phase 1.5 calibrator — caution hue (spec-reviewer와 의미 호환) |
| `synthesizer` | (없음) | **blue** | Phase 1.6 aggregator — informational |
| `codex-reviewer` | (없음) | **pink** | external model-family — distinct from anthropic-side reviewers |

Color 선택은 Claude Code의 표준 8-color 팔레트 (`cyan/green/yellow/blue/red/purple/orange/pink`) 안에서 — custom hex 사용 안 함 (Claude Code UI가 enum만 인식).

**Files to Modify:**
- `plugins/quality-gates/agents/adversarial.md` frontmatter — `color: orange` 추가.
- `plugins/quality-gates/agents/codex-reviewer.md` frontmatter — `color: pink` 추가.
- `plugins/quality-gates/agents/scout.md` frontmatter — `color: purple` 추가.
- `plugins/quality-gates/agents/security-reviewer.md` frontmatter — `color: red` 추가.
- `plugins/quality-gates/agents/synthesizer.md` frontmatter — `color: blue` 추가.
- `plugins/quality-gates/README.md` (option) — agent 표 (line ~38-46)에 color 컬럼 추가하여 future contributor가 color 컨벤션을 spec-distill 처럼 한 눈에 볼 수 있게.

**Acceptance criteria** (모두 grep-based):

- AC53 (dynamic existence — Order of Land에 독립적): **현존하는 모든** `plugins/quality-gates/agents/*.md` 파일이 `color:` frontmatter를 보유. T3-1/2/3 refactor가 일부 agent를 삭제해도 검증 통과해야 함. 구체 명령:
  ```bash
  for f in plugins/quality-gates/agents/*.md; do
    grep -q '^color:' "$f" || { echo "FAIL: $f missing color"; exit 1; }
  done
  echo "PASS: all extant agents have color"
  ```
  (T2-9 land 시점에는 8개 모두; T3-1 후 7개; T3-2 후 6개; T3-3 후 5개 — 어느 시점에도 PASS.)
- AC54: 각 agent 의 color 값이 위 표와 정확히 일치 — 5개 신규 색상에 대해 *해당 agent 파일이 존재하는 한* `grep '^color: <expected>' plugins/quality-gates/agents/<agent>.md` 매칭 == 1. 파일이 T3 refactor로 삭제된 경우 그 agent의 AC54는 N/A (skip with note).
- AC55: Claude Code 표준 8-color enum 내 값만 사용 — `grep '^color:' plugins/quality-gates/agents/*.md | awk '{print $2}' | sort -u` 출력이 `{cyan, green, yellow, blue, red, purple, orange, pink}`의 subset (현존 파일 기준).
- AC56: `tests/test_agent_frontmatter_keys.sh` 의 frontmatter validation이 통과 (기존 key 형식 검증 회귀).

**Verification plan:**
```bash
# AC53-AC55 검증
bash -c '
total=$(grep -l "^color:" plugins/quality-gates/agents/*.md | wc -l)
[ "$total" -eq 8 ] || { echo "FAIL AC53: $total ≠ 8"; exit 1; }
unique=$(grep "^color:" plugins/quality-gates/agents/*.md | awk "{print \$2}" | sort -u | tr "\n" " ")
echo "Colors in use: $unique"
'
# AC56 회귀
bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh
```

**Trade-off**: persona-as-security-code 관점에서 color 추가는 *role*이 아니라 *visual cue* — 약화/강화 평가 대상 아님. 단, color 표가 변경되면 후속 reviewer가 spec과 코드를 cross-check할 수 있도록 README 표 동기화 권장 (drift 방지).

---

## Tier 3 — Refactor (별도 PR cluster)

### T3-1. scout-as-script (`A-8`)

**Why:** scout의 depth-decision은 `scout.md` L42-44에 결정적 테이블로 명시. agent dispatch (~5-15K input + 500 output, opus 또는 sonnet)을 60줄 Python 휴리스틱으로 대체 가능. Step 0 JSON에 이미 모든 신호 (CHANGED_LINE_COUNT, NEW_FILES, CONFIG_TOUCHED, TYPE_DESIGN, TEST_CHANGE) 있음.

**Files to Modify:**
- `plugins/quality-gates/scripts/scout.py` (신규) — 60줄. argparse로 step 0 JSON 받고 same YAML schema (`depth`, `phase1_agents`, `phase2_agents`, `rationale`, `fallback: false`) emit.
- `plugins/quality-gates/agents/scout.md` 삭제.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — agent dispatch prose → `Bash("python3 ${CLAUDE_PLUGIN_ROOT}/scripts/scout.py < $STEP0_JSON")`.
- `plugins/quality-gates/tests/test_scout_script.sh` (신규).

**Trade-off:** LLM 판단을 잃지만 결정적 테이블이 이미 LLM 판단을 거의 대체. fallback path (deterministic)가 이미 production 경로로 검증됨 — 사실상 primary path를 fallback과 통합하는 것.

**Acceptance criteria** (각 fixture는 신규 `tests/test_scout_script.sh`에서 step 0 JSON 입력 + 기대 YAML 출력 검증):

- AC29 (output schema equivalence): scout.py 가 emit하는 YAML keys는 기존 `agents/scout.md` 의 dispatch contract와 정확히 일치 — `depth ∈ {quick, standard, deep}`, `phase1_agents: [list]`, `phase2_agents: [list]`, `rationale: <string>`, `fallback: false`. 외부 키 없음.
- AC30 (depth-decision regression): 5개 frozen fixture (small whitespace-only / medium new-files / large config-touched / large+type-design / large+test-only) → 기존 scout.md L42-44 결정 테이블과 같은 `depth`를 emit. 5/5 일치.
- AC31 (phase1 subset regression): 같은 5 fixture에서 `phase1_agents` set이 기존 fallback path (SKILL.md L539-548)가 emit하던 set과 정확히 같음.
- AC32 (test_scout_codex_integration 회귀): 기존 4 scenario 통과 (anchor prose는 `agents/scout.md` 대신 `scripts/scout.py` 호출 prose로 갱신; 갱신 자체가 본 PR의 일부).
- AC33 (fallback flag): scout.py 는 항상 `fallback: false` emit (rule-based primary path). 기존 fallback path는 본 PR로 제거되므로 dual-path 자체 사라짐.

### T3-2. synthesizer-as-script (`A-5`)

**Why:** synthesizer의 알고리즘은 `synthesizer.md` L23-31에 5단계 결정적 절차 (dedup + apply-verdict + sort + suppress<7). LLM 판단 없음. 모든 input은 adversarial.yaml + raw findings.yaml로 이미 구조화됨.

**Files to Modify:**
- `plugins/quality-gates/scripts/synthesize_findings.py` (신규) — adversarial.yaml + findings.yaml → Markdown.
- `plugins/quality-gates/agents/synthesizer.md` 삭제.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` Phase 1.6 분기 → Bash invocation.
- `plugins/quality-gates/tests/test_synthesize_findings.sh` (신규).

**Acceptance criteria:**

- AC34 (dedup): 동일 (`file`, `line_range`, `severity`) 키의 finding 2개 입력 → 출력에 1개만 (lower-confidence drop).
- AC35 (verdict application): adversarial.yaml 가 `verdict: reject`인 finding은 출력에서 제외; `verdict: downgrade`는 `adjusted_severity` 적용; `verdict: confirm`은 그대로.
- AC36 (suppress<7 except CRITICAL): `confidence < 7 && severity != CRITICAL` 인 finding은 suppress 처리되어 출력 Markdown에 부재.
- AC37 (sort order): 출력은 severity desc (CRITICAL > IMPORTANT > SUGGESTION) → confidence desc → file asc 순으로 정렬.
- AC38 (output schema): 출력 Markdown은 기존 synthesizer.md L40-60에 명시된 표/heading 구조와 동일 — `## Critical Issues`, `## Important Issues`, `## Suggestions (non-blocking)` 세 섹션 헤더가 정확히 등장.
- AC39 (empty input): adversarial.yaml 빈 입력 → 출력 Markdown은 세 빈 섹션 (`No critical issues.` 등 placeholder 라인) 유지.

### T3-3. codex-reviewer-as-script (`A-11`)

**Why:** codex-reviewer agent body는 75줄의 mechanical bash. LLM 판단 0. Layer 1 (`disallowedTools`)은 SKILL.md의 Bash allowlist로 대체 가능.

**Files to Modify:**
- `plugins/quality-gates/scripts/run_codex_reviewer.sh` (신규) — 기존 `agents/codex-reviewer.md` L40-114 bash 인보케이션을 그대로 이전. argv: `<diff_path> <project_dir> <output_yaml_path>`.
- `plugins/quality-gates/agents/codex-reviewer.md` 삭제.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` L483 — Task dispatch → `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh ...")`. SKILL.md frontmatter `allowed-tools`의 Bash allowlist에 새 스크립트 경로 추가.

**Layer 2/3 isolation 보존 전략:** 기존 codex-reviewer.md 의 3-layer isolation (frontmatter disallowedTools + narrow Bash allowlist + `codex -s read-only`) 중 Layer 1(frontmatter) 은 사라짐. 대신 SKILL.md 의 narrow Bash allowlist (`Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)`) 가 Layer 1을 대체. Layer 3 (`codex exec -s read-only`)는 스크립트 안에 그대로.

**Isolation 동등성 threat model** (AC44 근거):

| 위협 vector | Agent 경로 (현재) | Script 경로 (T3-3 후) | 동등성 |
|---|---|---|---|
| Reviewer가 Write/Edit으로 코드 수정 | `disallowedTools: [Write,Edit,...]` frontmatter로 차단 | Agent 자체가 없음 — Bash allowlist가 `run_codex_reviewer.sh:*` 단일 entry만 허용, Write/Edit invocation 자체 불가능 | ✅ 동등 (또는 강함) |
| Script 내부 하위 프로세스가 임의 tool 호출 | 해당 없음 (agent context 내부에서만 tool dispatch) | Script는 stdlib bash + `codex` binary 호출만; subshell이 Claude Code tool API에 access 불가 (process isolation) | ✅ 동등 (subshell ≠ tool dispatch surface) |
| Codex 자체의 file write | `codex exec -s read-only` (Layer 3)으로 차단 | 동일 — script 안에 그대로 보존 | ✅ 동일 |
| SKILL.md Bash allowlist의 광범위 fallback | 해당 없음 | 만약 `Bash(*)`로 늘리면 위협. **본 spec에서는 `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)` 단일 entry로 lock** (AC44 검증) | ✅ AC44가 강제 |

**반례 검토**: SKILL.md frontmatter가 후속 PR에서 `Bash(*)`로 wide-allow되는 경우 isolation이 깨짐. 이 회귀를 막기 위해 `tests/test_skill_bash_allowlist_narrow.sh` 신규 — SKILL.md `allowed-tools` 항목이 정확히 enumerated list (와일드카드 `Bash(*)` 불허) 인지 검증.

**Acceptance criteria:**

- AC40 (output schema equivalence): `run_codex_reviewer.sh` 가 emit하는 YAML 은 기존 codex-reviewer agent dispatch output과 schema-동등 — `agent: codex-reviewer`, `findings: [...]` 구조. 기존 `tests/test_findings_parser.sh` 의 codex-reviewer 입력 fixture를 그대로 사용해 검증.
- AC41 (sandbox 보존): script 는 `codex exec -s read-only` invocation 을 반드시 포함 (grep). non-read-only invocation 은 0회.
- AC42 (kill switch 보존): `DEVBREW_DISABLE_QG_CODEX=1` 또는 `detect_codex.sh` 의 `codex_available: false` 응답 시 SKILL.md 가 script 호출 자체를 skip — prose 검증.
- AC43 (test anchor 갱신): `test_codex_dispatch_invariant.sh`, `test_codex_reviewer_frontmatter.sh`, `test_scout_codex_integration.sh` 의 grep anchor 가 새 script 경로 기반으로 갱신; 갱신 자체가 본 PR 의 일부. 갱신 후 세 test 모두 PASS.
- AC44 (sentry — Layer 1 sub): SKILL.md frontmatter Bash allowlist 가 `${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*` 단일 entry로 좁혀짐 (광범위 `Bash(*)` 회피). frontmatter audit test 통과.

### T3-4. 8 leaf agent behavioral test backfill (`A-2`)

**Why:** 현재 8 agent 중 1개만 behavioral test 보유. 7개는 frontmatter grep만. v1.11.1 silent-drop 버그가 user runtime에서만 잡힌 전례 — Law 3 compounding의 핵심 인프라가 비어있음.

**선행 task (prerequisite — T3-4 본 작업 전에 land):**

- `plugins/quality-gates/tests/harness/agent_stub.py` (신규) — Agent dispatch를 monkeypatch하는 fixture provider. Interface:
  - `run_agent_stub(agent_name: str, prompt: str, frozen_output: str) -> ParsedYAML` — Agent SDK Task call을 short-circuit해서 `frozen_output`을 그대로 반환하고 parsed YAML 리턴.
  - `assert_yaml_schema(parsed, schema_keys: list[str], enum: dict[str, list[str]])` — required keys 존재 + 값이 enum에 포함됨을 검증.
  - 위 두 helper는 `tests/test_*_behavior.{sh,py}` 에서 import.
- 본 harness 가 land된 다음 commit 부터 8개 behavioral test 추가 가능.

**Files to Modify:**

- `plugins/quality-gates/tests/harness/agent_stub.py` (신규, 선행).
- 8개 behavioral test (각 PR로 분리 가능; T3-1/2/3 refactor 와 함께 land되는 것은 script-level test로 대체):
  - `tests/test_plan_verifier_behavior.py`
  - `tests/test_security_reviewer_behavior.py`
  - `tests/test_adversarial_behavior.py`
  - `tests/test_synthesizer_behavior.py` (T3-2 시 `test_synthesize_findings.sh` 로 대체)
  - `tests/test_scout_behavior.py` (T3-1 시 `test_scout_script.sh` 로 대체)
  - `tests/test_codex_reviewer_behavior.py` (T3-3 시 stub-codex로 갱신)
  - `tests/test_test_scope_validator_behavior.py`
  - `tests/test_runtime_verifier_behavior.py`

**Per-agent verdict enum** (AC45 fixture의 ground truth). **Backfill 범위 (Order of Land #10과 일치)**: 5개 *agent* (T3-1/2/3 refactor에서 살아남는 agent). T3-1/2/3로 script로 대체되는 3개 (scout, synthesizer, codex-reviewer)는 *script-level test로 대체*되며 본 T3-4 scope 아님 — 표에서 명시:

| Agent | Backfill scope | Required YAML keys | Verdict enum |
|---|---|---|---|
| `plan-verifier` | **T3-4 (behavioral test)** | `verdict`, `matched_items`, `unmatched_items`, `possibly_implemented` | `PASS` / `FAIL` / `SKIP` |
| `security-reviewer` | **T3-4 (behavioral test)** | `agent`, `findings: [...]` (each: `severity`, `confidence`, `file`, `line`) | `severity ∈ {CRITICAL, IMPORTANT, SUGGESTION}`, `confidence ∈ [1..10]` |
| `adversarial` | **T3-4 (behavioral test)** | `verdicts: [...]` (each: `finding_id`, `verdict`, `adjusted_severity?`) | `verdict ∈ {confirm, downgrade, reject}` |
| `synthesizer` | T3-2 (script-level test in `test_synthesize_findings.sh`) | `final_findings: [...]` + sectioned Markdown | (no verdict enum — pure post-processing) |
| `scout` | T3-1 (script-level test in `test_scout_script.sh`) | `depth`, `phase1_agents`, `phase2_agents`, `rationale`, `fallback` | `depth ∈ {quick, standard, deep}` |
| `codex-reviewer` | T3-3 (script-level test refit, anchor 갱신) | `agent: codex-reviewer`, `findings: [...]` | same as security-reviewer enum |
| `test-scope-validator` | **T3-4 (behavioral test)** | `test_scope_verdicts: [...]` | `aligned / outdated-suspicion / cherry-pick-suspicion / unclear` |
| `runtime-verifier` | **T3-4 (behavioral test)** | `verdict`, `evidence_log: [...]`, `needed_hash?` | `PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION` |

**T3-4 backfill 대상은 위 표의 "T3-4 (behavioral test)" 행 5개** — 이전 round의 "표에 8개 vs Order of Land에 5개" 모순 해소.

**Acceptance criteria per agent** (각 behavioral test 가 충족):

- AC45 (verdict enum match): test 가 fixture frozen output을 stub harness 로 inject → parsed YAML 의 verdict field 가 위 표의 enum 내에 있음을 assert.
- AC46 (schema completeness): required key 누락 시 `assert_yaml_schema` 가 명시적 AssertionError 발생.
- AC47 (graceful failure on bad input): 잘못된 frozen output (예: 유효하지 않은 YAML, missing key) → graceful error message + non-zero exit; **silent skip 없음**.
- AC48 (frontmatter invariant): agent frontmatter (`allowedTools` / `disallowedTools` / `model`) 가 expected와 일치 — 기존 `test_agent_frontmatter_keys.sh` 가 cover (관련 PR에서 회귀 확인).

**Verification plan:** 다음 명령으로 통과 검증, 모두 exit 0 + 100% PASS:
```bash
python3 -m pytest plugins/quality-gates/tests/test_plan_verifier_behavior.py \
                  plugins/quality-gates/tests/test_security_reviewer_behavior.py \
                  plugins/quality-gates/tests/test_adversarial_behavior.py \
                  plugins/quality-gates/tests/test_test_scope_validator_behavior.py \
                  plugins/quality-gates/tests/test_runtime_verifier_behavior.py -v
bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh   # AC48 회귀
```
CI hook은 `tests/test_*_behavior.py` glob을 새 fixture pattern으로 인식.

### T3-5. Phase 1 dual-dispatch 통합 (T2-2와 연동) (`A-1`)

T2-2가 dispatch builder를 만들 때 함께 land. Tier 3가 아니라 T2-2의 부산물이지만, ~135 LOC dedup이라 별도 finding으로 남김.

---

## Rejected Alternatives

- **§A.1 scout/synthesizer agent를 통합해서 단일 "review-arbiter" agent로**: agent 수는 줄지만 LLM 판단 (있지도 않은) 가짜를 합쳐 더 큰 dispatch가 됨. script 분리가 더 정직.
- **§A.2 trivia detection을 LLM-based로 격상**: 정확도↑이지만 매번 LLM call이 cost surprise. CLAUDE.md *trivia escape*은 cheap-by-design.
- **§A.3 (T2-3) wall-clock budget을 hook hardcoded 30분**: env override 없으면 강제 — power user의 long-running pipeline (large codebase deep review)이 막힘. `DEVBREW_QG_DEADLINE_MIN=0` opt-out 필수. **추가 거부 대안**: SKILL.md prose-level deadline emit (LLM이 timestamp 직접 계산해서 stderr emit) — LLM judgment에 critical safety control을 위임하는 anti-pattern. hook-level deterministic compare가 옳음.
- **§A.4 (T2-4) `consecutive_no_signal` 을 별도 state field 신설 대신 `gate2_iteration` 재사용**: gate2_iteration 은 verdict 받은 round만 카운트하므로 reset semantics가 다름. 같은 필드에 두 의미를 overload하면 stop-hook의 transition logic이 ambiguous. 별도 field 가 정직.
- **§A.5 (T2-8) adversarial 비용 disclosure를 model downgrade 대신 AskUserQuestion count 포함**: count 포함은 prose-only AC ("문구에 7이 표시됨")라 testable하지만 비용 절약 0. downgrade 가 cost-회수 + test-회귀 둘 다 잡음.
- **§A.6 (T3-3) codex-reviewer 를 script 완전 대체 대신 thin agent wrapper 유지**: thin wrapper 도 Layer 1 frontmatter 를 보존하지만 dispatch overhead (3K input + Task() call) 그대로. Layer 1 보존은 SKILL.md frontmatter Bash allowlist 좁히기로 동일 효과 달성 (AC44).
- **§A.7 (T2-1) typo 자격을 length-agnostic 으로 정의**: 길이 차 제한 없이 1-token substitution이면 typo 로 인정하면 대부분의 rename (e.g., `userID → userIdentifier`) 도 typo 로 분류되어 ceremony skip 대상이 너무 광범위해짐. 길이 차 ≤ 2 hard constraint이 *진짜 오타* 와 *rename* 의 경계 — typo는 ≤ 2자 차, rename은 ≥ 3자 차로 lock. rename은 기존 `trivia: rename` kind이 cover (별 경로).
- **§A.8 (T2-4) 두 stuck-state 보호 (T2-3 wall-clock + T2-4 no-signal) 둘 중 하나라도 반드시 활성화되도록 hard-enforce**: kill switch는 user sovereignty 원칙 (P17). 둘 다 off는 power user의 명시 선택 — qg가 사용자보다 "더 잘 안다"고 가정해 강제하면 P17 위반. 명시 opt-out 모드는 지원 + 두 env var 모두 0인 상태에서는 `/cancel-qg` 외 종료 수단 없음을 README §설정에서 loud-document.

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
4. **T2-2 + A-1 / T3-5** (fan-out 게이트 + dual-dispatch dedup) — 단일 결합 PR. *T3-1 (scout-as-script)는 이 PR에 absorbed되지 **않는다*** (단일 PR이 fallback 게이트, ~135 LOC dedup, scout 전체 script 대체의 세 surface를 함께 담으면 "PR은 한 PR 단위로 land 가능" 원칙 위반). T3-1은 별도 PR.
5. **T2-5, T2-6, T2-7, T2-8, T2-9** — parallelizable except **T2-8 ↔ T2-9 sequencing**: 두 PR 모두 `agents/adversarial.md` frontmatter를 편집(T2-8: `model: sonnet`, T2-9: `color: orange`)하므로 동시 land 시 merge conflict. **T2-8 먼저, 그다음 T2-9** 순으로 land하거나 단일 PR로 병합. 다른 페어에는 충돌 없음.
6. **T3-4 선행 stub harness** (`tests/harness/agent_stub.py`) — T3-1/2/3 의 behavioral test 가 의존.
7. **T3-3** (codex-reviewer-as-script) — 가장 작은 refactor, 위험 낮음.
8. **T3-2** (synthesizer-as-script).
9. **T3-1** (scout-as-script) — 독립 PR. T2-2 와 통합 금지 (위 4번 항목 참조).
10. **T3-4** (behavioral test backfill) — 위 refactor 후 새 surface에서 testify. 일부 agent (synthesizer, scout, codex-reviewer)는 refactor와 함께 script-level test로 대체되므로 backfill 대상은 5개 (plan-verifier, security-reviewer, adversarial, test-scope-validator, runtime-verifier).

각 PR은 plugin.json minor bump, CHANGELOG entry, "Principles Instantiated" 추가/갱신.
