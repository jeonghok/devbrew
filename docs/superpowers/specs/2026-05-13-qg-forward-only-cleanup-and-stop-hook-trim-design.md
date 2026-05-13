# Design — `quality-gates` forward-only prose cleanup + stop-hook trim

> **One-liner.** v1.5.0 의 forward-only state machine 패치 이후 stop-hook 의 정당성은 유지되지만 (turn-boundary 자동 진행 + multi-turn within-Gate-2 fix-loop + repeat-detection invariant), prose drift (SKILL.md 가 옛 cross-gate restart 어휘를 유지) 와 dead-weight (deprecated state field, 6-case prompt builder 중복) 가 누적되어 있다. 이 spec 은 양쪽을 한 PR 로 정리한다.

- **Plugin scope**: `plugins/quality-gates/`
- **Type**: Docs + code refactor (no public contract change)
- **CHANGELOG**: `1.9.0` → `1.10.0` (minor — internal refactor + user-visible prompt prose 변경)
- **Owner**: `Jeongho-K`
- **Branch**: `fix/qg-forward-only-cleanup` (worktree branch: `worktree-qg-forward-only-cleanup`)

## Context / Why

### 진화 타임라인

1. **v1.3.0 (`23b12a3`)** — `migrate pipeline to Stop hook-based progression`. In-skill cross-gate loop 을 stop-hook 기반 transition 으로 옮김.
2. **v1.5.0 (`985465b`)** — `cost reduction + Gate 2 redesign`. **Cross-gate restart 자체를 제거**. `total_iterations` / `max_total_iterations` 필드 deprecated. 새 모델: NEEDS_RESTART → user-choice prompt 로 terminate, 사용자가 fix 후 `/qg` 재실행.
3. **v1.6.x ~ v1.9.0** — Kill switch coverage, project-local plan discovery, Gate 3 active runtime verification, test-scope-validator 등 surface 추가. 본질 모델 변경 없음.

### Stop-hook 재검토 (사용자 요청)

> "이제와서는 stop hook 이 반드시 필요할지도 검토해봐"

`hooks/stop-hook.py` (960 LoC) 책임 6 종 inventory:

| # | 책임 | Forward-only 후 정당성 |
|---|---|---|
| 1 | Gate 전이 prompt 자동 주입 (G1 PASS → G2 시작) | **유지** — `/qg` 한 번에 자동 흐름 제공하는 본질적 가치 |
| 2 | Within-Gate-2 fix-loop iteration 주입 (max 5) | **유지** — multi-turn fix→re-review 분산 (context cost ↓, prompt cache TTL 활용) |
| 3 | User-choice prompt 6 종 주입 | **유지** — 다음 턴 자동 재개 가능성 보존 (in-skill `AskUserQuestion` 으로 대체 시 자동 재개 불가) |
| 4 | `pipeline.md` state file 관리 | **유지** — multi-turn persistence 의 storage layer |
| 5 | Repeat detection (`dispatch_hash`/`synth_hash`/`needed_hash`) | **유지/필수** — Plugin Shape *"repeat 감지 없는 loop 금지"* 의 코드 invariant, Law 2 "분리는 프롬프트가 아니라 물리적" 정신상 prose 가 아닌 code 에서 enforced 되어야 함 |
| 6 | 종료 시 `.claude/quality-gates/<session-id>/` rmtree | **유지** — mid-session terminal cleanup 의 유일한 hook point (SessionEnd 는 graceful only) |

**결론**: Stop-hook 은 obsolete 가 아니다. **그러나** 다음 4 가지 *약화/단순화 가능 영역* 이 존재:

- **D1.** `total_iterations` / `max_total_iterations` 필드 — v1.5.0 이후 *"tolerated on read; never written"*. 1년 가까이 dead. `setup-qg.sh --ensure` 가 stale state 를 overwrite 하므로 legacy session protection 도 사실상 무의미.
- **D2.** `build_special_prompt` 의 6 case (현 lines 591–736, 146 LoC) — 모두 동일 patten: header + 상황 설명 + options 3 종 + signal mapping + pipeline context. 단일 template + per-case data dict 로 50% 가까이 LoC 감축 가능.
- **D3.** `main()` 의 transition type 분기 (현 lines 870–942, 73 LoC) — `next_gate` / `retry_gate` / `extend` / `continue` / user-choice 5 종 모두 `compute prompt + sys_msg + print json + exit` 동일 종결. Helper 추출 가능.
- **D4.** SKILL.md / state-file-format.md 의 prose drift (6 위치) — 사용자에게 직접 잘못된 동작 안내. 사용자 prompt UX 와 직결.

### 본 PR 의 통합 정당성

Drift 정리(D4) 와 dead-weight 제거(D1–D3) 를 두 PR 로 분리할 수 있지만, **둘 다 같은 v1.5.0 forward-only invariant 의 instantiation 이므로 한 PR 로 묶는다.** 분리 시:

- Drift 정리 PR 이 먼저 merge 되면 SKILL.md 의 새 prose 가 stop-hook 의 옛 6-case prompt 와 다시 어긋남 (prose-vs-code drift 2 차 발생).
- Stop-hook trim PR 만 먼저 merge 되면 prompt 변경 후 SKILL.md 의 옛 매핑이 reviewer 를 오도.

단일 PR 로 양쪽을 정렬 → Law 1 *"명확성 먼저"*, Law 3 *"매 cycle 시스템이 똑똑해진다"* 동시 instantiation.

## Goals

### 그룹 A — Prose alignment (drift fix)

- **G1.** SKILL.md / references 의 모든 cross-gate restart 시사 phrase 제거.
- **G2.** Verdict `NEEDS_RESTART` 의 의미를 SKILL.md 에서 명시적으로 재정의 (`= code was changed; pipeline halts with user-choice prompt — does NOT auto-restart from Gate 1`).
- **G3.** SKILL.md GATE3_FAIL 섹션 (현 line 1131–1141) 의 option 1 라벨을 `"Fix and re-run /qg"` 로 정정 — stop-hook.py:663 의 실제 prompt 와 일치.
- **G4.** `references/state-file-format.md` 예시 history 로그에서 `Restarting from Gate 1 (iteration 2)` 라인 제거.

### 그룹 B — Stop-hook trim (dead-weight removal)

- **G5.** `total_iterations` / `max_total_iterations` 필드를 schema, 코드, **그리고 `extend` transition의 dead write** 까지 완전 제거. 정확한 잔존 위치:
  - `parse_state_file` (현 line 89, 92, 101–107) — tolerate 코드 삭제
  - `update_state_file`:
    - line 403 `new_total = state.get("total_iterations", 1)` — 변수 자체 제거
    - line 405 `new_max_total = state.get("max_total_iterations", 5)` — 변수 자체 제거
    - line 419–420 `extend` 분기의 `new_max_total += transition.get("additional", 3)` — **이미 dead write** (line 436–442 의 `replacements` dict 에 `max_total_iterations` 키가 없어 never persisted). G5 의 일부로 line 419–420 삭제 + `extend` transition 의 effective behavior 가 `build_gate_prompt` 재주입뿐임을 코멘트로 명시 (또는 `extend` transition 자체를 `compute_transition` 에서 emit 되지 않는다면 dead branch 로 제거 — 구현 단계 사전 검증 필수)
    - line 433–435 의 forward-only comment 자체도 함께 정리 (필드가 사라지면 comment 도 obsolete)
  - schema doc (`references/state-file-format.md:37-38`) — deprecated note 제거
  - Fixture 파일 정확한 라인:
    - `tests/test_stop_hook_state_machine.py:25-26, 40-41, 56-57, 72-73, 87-88, 161-162` — 6 case 각각의 fixture dict 에서 `"total_iterations": 1,` / `"max_total_iterations": 5,` 2 라인쌍 삭제. `tests/test_stop_hook_state_machine.py:15` 의 `test_no_max_total_iterations_constant` 는 회귀 가드로 *유지*
    - `tests/test_kill_switches.py:49` — `"total_iterations: 0\n"` 라인 삭제
    - `tests/test_session_start_advisor.py:26` — `"total_iterations: 1\n"` 라인 삭제
- **G6.** `build_special_prompt` 의 6 case 를 (a) 공통 template 함수 + (b) per-case `dict[case → {header, body, options, signal_mapping}]` 구조로 통합. 외부 호출 면 (`main()` 의 prompt_key 전달) 변경 없음.
- **G7.** `main()` 의 transition-handler 5 종 (`next_gate`, `retry_gate`, `extend`, `continue`, user-choice 5종) 을 `emit_continuation(prompt, transition)` helper 로 통합. `print(json.dumps(...))` boilerplate 1 곳에 모음.

### 그룹 C — Regression guard (compounding)

- **G8.** Forbidden-phrase grep 회귀 테스트 신설 (`tests/test_forward_only_prose.sh`) — drift 재발 자동 차단. Law 3 instantiation: prose contract 를 testable artifact 로 승격.
- **G9.** Stop-hook 단순화 후 LoC 감축 실측 — `wc -l hooks/stop-hook.py` 결과를 PR description 에 기록.

## Non-Goals

- **NG1.** Verdict `NEEDS_RESTART` rename. 외부 호환 (qg-signal XML schema, agent code) 유지.
- **NG2.** `pipeline.md` state file schema breaking change. `total_iterations` / `max_total_iterations` 제거는 *never-written 1년 후* 필드 정리이지 schema rewrite 가 아님 — legacy state file 이 디스크에 있어도 `setup-qg.sh --ensure` 가 새 schema 로 overwrite 하므로 user-facing breaking 아님.
- **NG3.** Gate 2 within-loop fix-loop (`max_gate2_iterations=5`, repeat detection) 동작 변경. **invariant 유지** — repeat detection 이 깨지면 AP15 *"unbounded loop"* 회귀.
- **NG4.** Stop-hook 의 6 책임(§Context 표) 중 어느 하나라도 제거 / skill in-turn 이전. 본 PR 은 *trim* 이지 *remove* 가 아님.
- **NG5.** New user-facing surface. 새 환경변수 / 새 verdict / 새 transition 추가 없음.
- **NG6.** Korean translation pass. 기존 영어 prose 를 한국어로 옮기는 작업은 별도 cycle (CLAUDE.md *"Korean-primary"* 정책의 점진적 적용).
- **NG7.** `setup-qg.sh` 의 `total_iterations` writing 정리 — *이미 v1.5.0 에서 정리됨*. 재현 가능한 사전 검증:
  ```bash
  grep -n 'total_iterations\|max_total_iterations' \
    plugins/quality-gates/scripts/setup-qg.sh
  # → exit 1 (no matches). 2026-05-13 spec author 가 confirmation.
  ```
  No-op file — `Files to Modify` 표에 포함되지 않음.

## Constraints

- **C1.** SKILL.md 헤더 (`"Executes a single gate per turn; the Stop hook manages pipeline progression automatically."`) 는 변경 없이 유지. 본 PR 은 이 description 의 *정확한* 본문화.
- **C2.** Stop-hook `_disabled()` kill-switch (`DEVBREW_DISABLE_QUALITY_GATES`, `DEVBREW_SKIP_HOOKS=quality-gates:stop-hook`) 동작 절대 보존. `tests/test_kill_switches.py` 그대로 통과해야 함.
- **C3.** Stop-hook signal/transition vocabulary 보존. `compute_transition` 의 반환 type (`next_gate` / `retry_gate` / `extend` / `continue` / `gate2_user_choice` / `max_gate2_exceeded` / `gate3_fail` / `gate3_needs_resolution` / `gate3_repeat_detected` / `complete` / `abort`) 그대로. 외부 contract.
- **C4.** Prompt body 의 *semantic* 정보 (어떤 옵션이 어떤 verdict 를 emit 하는지 매핑) 보존. Template 통합은 *내부* 리팩토링 — user-visible 옵션 라벨/순서/의미는 동일 (G3 의 GATE3_FAIL 옵션 1 라벨 변경만 예외, 명시적 의도).
- **C5.** `plugin.json` `version: "1.9.0"` → `"1.10.0"`, `CHANGELOG.md` 에 새 섹션. CLAUDE.md *"Bump plugin.json version on plugin edits"* 준수.
- **C6.** Worktree / per-session isolation (`tests/test_worktree.sh`, `tests/test_isolation.sh`) 회귀 없음.

## Acceptance Criteria

### 그룹 A — Prose

- **AC1.** `grep -rn 'restart from Gate 1' plugins/quality-gates/skills plugins/quality-gates/references` → no matches.
- **AC2.** `grep -rn 'loop-back' plugins/quality-gates/skills` → no matches.
- **AC3.** `grep -rn 'Restarting from Gate 1' plugins/quality-gates/skills plugins/quality-gates/references` → no matches.
- **AC4.** SKILL.md verdict 정의 (현 line 1204) 에 `forward-only` 키워드 + *does NOT auto-restart* 명시.
- **AC5.** SKILL.md GATE3_FAIL prompt section option 1 label = `"Fix and re-run /qg"`. 부연 본문에 `"pipeline does not auto-restart"` 또는 동등 표현 포함.
- **AC6.** SKILL.md GATE2_NEEDS_RESTART section 본문이 *no auto-restart* 명시 (현재 stop-hook.py:680 의 prose 와 일치하도록).
- **AC7.** `references/state-file-format.md` 예시 history 로그에서 `Restarting from Gate 1` 라인 제거; 대체 라인은 forward-only 모델 종료 (`user-choice (terminate; user re-runs /qg)`) 반영. Deprecated `total_iterations` note (현 line 37–38) 도 같이 제거 (G5 의 일부).

### 그룹 B — Stop-hook trim

- **AC8.** `parse_state_file` (현 stop-hook.py:89,92,101–107) 와 `update_state_file` (현 line 403, 405, 433) 에 `total_iterations` / `max_total_iterations` 처리 없음. `references/state-file-format.md:37-38` 의 deprecated note 제거. 다음 grep 의 hits 는 **CHANGELOG.md (역사 기록 보존)** 와 **`tests/test_stop_hook_state_machine.py::test_no_max_total_iterations_constant` (회귀 가드로 유지)** 두 곳만 허용:
  ```bash
  grep -rn 'total_iterations\|max_total_iterations' plugins/quality-gates/ \
    | grep -v 'CHANGELOG.md' \
    | grep -v 'test_stop_hook_state_machine.py.*test_no_max_total_iterations_constant'
  # → 0 hits
  ```
  Pre-existing 테스트 fixture (`tests/test_stop_hook_state_machine.py` 의 다른 라인들, `tests/test_kill_switches.py:49`, `tests/test_session_start_advisor.py:26`) 의 `total_iterations: ...` 라인은 함께 정리.
- **AC9.** `build_special_prompt` LoC ≤ 80 (현 146 LoC). 6 case data 는 module-level `dict` 또는 함수-local data structure 에 분리. 측정:
  ```bash
  awk '/^def build_special_prompt/{flag=1} flag{print; if(/^def [a-z_]+\(/ && !/^def build_special_prompt/)exit}' \
    plugins/quality-gates/hooks/stop-hook.py | wc -l
  ```
- **AC10.** `main()` 의 transition-handler section (현 line 870–942, 73 LoC) LoC ≤ 35. `emit_continuation` 또는 동등 helper 1 개로 통합. 자동 측정 명령:
  ```bash
  awk '/^def main\(\)/{f=1; n=0} f{n++; if(/^def [a-z_]+\(/ && !/^def main\(\)/){print n-1; exit}}' \
    plugins/quality-gates/hooks/stop-hook.py
  # → main() 전체 LoC. transition-handler 만의 라인 수는 PR diff 의
  # `# 9. Handle completion/abort` ~ `# 13. Build next gate prompt` 블록
  # 의 before/after LoC 를 비교 — diff 에서 - 블록 행수 - + 블록 행수 ≤ -38
  # (현 73 → 목표 ≤ 35).
  ```
- **AC11.** 전체 `hooks/stop-hook.py` LoC ≤ 800 (현 960). PR description 에 정확한 before/after 수치 기록.

### 그룹 C — Regression guard

- **AC12.** 신규 `tests/test_forward_only_prose.sh` 생성. AC1–AC3 의 grep 을 assertion 으로 wrapping + AC4/AC5 의 required-phrase 검사 + AC8 의 deprecated field grep. 다른 `tests/*.sh` 와 동일한 bash 형식, exit 0 이 PASS.
- **AC13.** 기존 회귀 테스트 모두 그대로 통과:
  - `tests/test_kill_switches.py` (fixture 정리 후에도)
  - `tests/test_worktree.sh`, `tests/test_isolation.sh`
  - `tests/test_discover_plan.sh`
  - `tests/test_detect_runtime.sh`
  - `tests/test_compute_test_scope_candidates.sh`
  - `tests/test_test_scope_validator_frontmatter.sh`
  - `tests/test_stop_hook_state_machine.py` (fixture state 의 옛 필드 제거 후 모든 case 동작)
  - `tests/test_session_start_advisor.py`
- **AC14.** 새 회귀 가드 추가: `tests/test_stop_hook_unit.py` (또는 동등) — 다음 invariant 를 unit 으로 검증:
  - `build_special_prompt` 가 6 transition_type (`max_gate2_exceeded`, `gate3_needs_resolution`, `gate3_repeat_detected`, `gate3_fail`, `gate2_user_choice` with `prompt_key="gate2_needs_restart"`, `gate2_user_choice` with `prompt_key="gate2_repeat_detected"`) 각각에 대해 다음을 동시 만족:
    - 반환값 길이 > 200 자
    - case-specific header (`"GATE2_NEEDS_RESTART\n\n"` / `"GATE2_REPEAT_DETECTED\n\n"` / `"GATE2_MAX_EXCEEDED\n\n"` / `"GATE3_FAIL\n\n"` / `"GATE3_NEEDS_RESOLUTION\n\n"` / `"GATE3_REPEAT_DETECTED\n\n"`) prefix 포함
    - 본문에 `<qg-signal` 문자열 ≥ 2 회 (옵션-결과 매핑 의도 검증)
    - `"abort"` 문자열 포함 (3 옵션 중 abort 항목 보장)
  - 알려지지 않은 transition_type 에 대해 반환 문자열이 정확히 `"PIPELINE_ERROR\n\n"` prefix 로 시작 (단순 non-empty 가 아님 — reviewer 가 빈 문자열로 swap 시 우회 가능 우려 차단)
  - `gate2_user_choice` with `prompt_key=None` (generic fallback) 도 동일 invariant 검증 (현 line 708–720)

### 그룹 D — Versioning

- **AC15.** `.claude-plugin/plugin.json` `version: "1.10.0"`.
- **AC16.** `CHANGELOG.md` 에 `## [1.10.0] — 2026-05-13` 섹션. `### Changed` (prose alignment + user-visible GATE3_FAIL 라벨), `### Removed` (deprecated state fields), `### Fixed` (drift), `### Internal` (stop-hook trim + LoC 수치) 포함.

## Files to Modify

| File | Type | 변경 요약 |
|---|---|---|
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Edit | 5 prose site: L15 헤더, L749–752 + L757 Gate 2 output, L778 Gate 2 rules, L1131–1141 GATE3_FAIL, L1200–1206 verdict 정의 |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` | Edit | 예시 history 로그 (L60–64) 정리 + deprecated total_iterations note (L37–38) 제거 |
| `plugins/quality-gates/hooks/stop-hook.py` | Edit | `parse_state_file` 의 deprecated 필드 처리 제거; `update_state_file` 의 잔존 reference 제거; `build_special_prompt` 6-case → template; `main()` transition-handler → helper |
| `plugins/quality-gates/tests/test_stop_hook_state_machine.py` | Edit | Fixture state 에서 `total_iterations` / `max_total_iterations` 라인 제거. `test_no_max_total_iterations_constant` 는 그대로 유지 (회귀 가드) |
| `plugins/quality-gates/tests/test_kill_switches.py` | Edit | Fixture (line 49) `total_iterations: 0` 라인 제거 |
| `plugins/quality-gates/tests/test_session_start_advisor.py` | Edit | Fixture (line 26) `total_iterations: 1` 라인 제거 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | Edit | `version: "1.9.0"` → `"1.10.0"` |
| `plugins/quality-gates/CHANGELOG.md` | Edit | Prepend `## [1.10.0] — 2026-05-13` block |
| `plugins/quality-gates/tests/test_forward_only_prose.sh` | Create | AC12 (forbidden + required phrase grep + deprecated field grep) |
| `plugins/quality-gates/tests/test_stop_hook_unit.py` | Create | AC14 (build_special_prompt invariants) |

총 8 edit + 2 create = 10 file touches. `setup-qg.sh` 는 사전 grep 결과 `total_iterations` writing 잔존 없음 → no-op (NG7).

## Verification Plan

### 1. Static — forbidden phrase grep (AC1–AC3, AC8, NG7)

```bash
cd plugins/quality-gates

# 그룹 A — prose drift
grep -rn 'restart from Gate 1' skills references && exit 1 || true
grep -rn 'loop-back' skills && exit 1 || true
grep -rn 'Restarting from Gate 1' skills references && exit 1 || true

# 그룹 B — deprecated state fields (역사 기록과 의도된 가드는 제외)
COUNT=$(grep -rn 'total_iterations\|max_total_iterations' . \
  | grep -v 'CHANGELOG.md' \
  | grep -v 'test_stop_hook_state_machine.py.*test_no_max_total_iterations_constant' \
  | wc -l)
test "$COUNT" -eq 0 || { echo "FAIL: $COUNT residual hits"; exit 1; }

# NG7 — setup-qg.sh 가 deprecated 필드를 writing 하지 않음을 명시 검증
grep -n 'total_iterations\|max_total_iterations' scripts/setup-qg.sh \
  && { echo "FAIL: setup-qg.sh has unexpected deprecated field reference"; exit 1; } \
  || true

echo "PASS"
```

### 2. Static — required phrase grep (AC4–AC6)

```bash
grep -n 'forward-only' skills/quality-pipeline/SKILL.md | head -1  # ≥ 1 hit in verdict area
grep -c 'Fix and re-run /qg' skills/quality-pipeline/SKILL.md      # = 1
grep -cE 'does (not|NOT) auto-restart' skills/quality-pipeline/SKILL.md  # ≥ 2 hits (verdict def + GATE3_FAIL)
```

### 3. Static — LoC budgets (AC9–AC11)

```bash
wc -l hooks/stop-hook.py  # ≤ 800

awk '/^def build_special_prompt/{flag=1; n=0} flag{n++; if(/^def [a-z_]+\(/ && !/^def build_special_prompt/){print n-1; exit}}' \
  hooks/stop-hook.py  # ≤ 80

# main() transition-handler section: measured by re-reading the post-edit file
# and confirming the helper function replaces the multi-block ladder.
```

### 4. Regression — existing test suite (AC13)

```bash
cd plugins/quality-gates && for t in tests/test_*.sh; do bash "$t" || { echo "FAIL: $t"; exit 1; }; done
for t in tests/test_*.py; do python3 "$t" || { echo "FAIL: $t"; exit 1; }; done
```

### 5. Regression — new guards (AC12, AC14)

```bash
bash tests/test_forward_only_prose.sh
python3 tests/test_stop_hook_unit.py
```

### 6. Manual smoke — full /qg cycle

작은 plan 으로 `/qg` 실행. 다음 5 가지 user-visible 확인:

- Gate 1 → Gate 2 자동 진행 (stop-hook 책임 #1)
- Gate 2 within-loop iteration 시 spinner 메시지 변화 (책임 #2 + `build_system_message`)
- Gate 3 가 SKIP_WITH_EVIDENCE 로 끝나는 docs-only repo 에서 정상 종료
- `/cancel-qg` 가 mid-pipeline cleanup 정상 작동 (책임 #6)
- 강제로 GATE3_FAIL 시 옵션 1 라벨이 `"Fix and re-run /qg"` 표시 (AC5)

### 7. Self-dogfooding

본 PR 의 branch 에서 `/qg` 실행 (Gate 1 plan 검증은 본 spec 파일을 plan 으로 매칭). Gate 2 reviewer 가 추가 prose drift / dead code 를 발견하면 그 cycle 안에서 fix.

## Rejected Alternatives

- **(A) Stop-hook 자체 제거** — §Context 의 책임 inventory 결과 6 책임이 모두 정당화됨. 특히 #1 (turn-boundary 자동 진행) 과 #5 (repeat detection invariant) 는 architectural primitive. 제거 시 `/qg` 의 user UX 와 AP15 hard guard 모두 손상.
- **(B) Prose-only PR + Stop-hook-trim 별도 PR** — 두 PR 사이 prose-vs-code drift 2 차 발생 위험. 같은 v1.5.0 invariant 의 instantiation 이므로 한 PR 로 묶는 것이 Law 3 *"compounding"* 에 부합.
- **(C) Verdict rename (`NEEDS_RESTART` → `NEEDS_USER_FIX`)** — `qg-signal` XML schema 호환성 깨짐. Semantics 만 prose 에서 재정의로 충분.
- **(D) State schema breaking change (`pipeline.md` v2 migration)** — `total_iterations` 필드 제거는 *removal* 이지 *migration* 이 아님. 1년간 never-written 이고 `setup-qg.sh --ensure` 가 overwrite 하므로 breaking 아님. v2.0.0 major bump 불필요.
- **(E) 6 case → 1 generic prompt 로 추가 단순화** — 각 case 의 contextual prose (e.g. GATE3_NEEDS_RESOLUTION 의 secret-value 금지 안내) 가 case-specific 가치를 가짐. Template + data dict 까지가 단순화의 정당한 한계.
- **(F) D1 (deprecated field 제거) 와 D2/D3 (template / helper 리팩토링) 을 별도 commit 으로 분리** — bisect 비용 측면에서 매력적이지만 거절. 근거: (1) D1 의 fixture 라인 정리가 D2 의 template unit test 작성과 같은 파일 (`test_stop_hook_state_machine.py`) 을 건드림 — 두 commit 사이 충돌 가능성. (2) D1 의 `extend` dead-write 발견 자체가 D3 (`main()` helper 추출) 와 같은 함수 영역 — 분리 시 두 PR 모두 `update_state_file` 을 건드림. (3) v1.5.0 forward-only invariant 의 단일 instantiation 이므로 commit 단위 분리는 *세분화의 코스트* 가 *bisect 의 이득* 을 초과. 다만 implementation 단계의 plan 에서는 step 으로 분리 (D1 → D2 → D3 → D4 순서, 각 step 후 `tests/` 통과 확인) — 같은 PR 안의 점진 commit 로 bisect 가능성 보존.

## Metadata

- **Created**: 2026-05-13
- **Plugin**: `quality-gates`
- **Spec author**: Claude Opus 4.7 (1M context) + user (`kimjhq97@gmail.com`)
- **Cites philosophy**: Law 1 (Clarity Before Code — spec-first), Law 2 (Writer/Reviewer 분리 — repeat detection invariant 은 code-enforced), Law 3 (Every cycle leaves system smarter — testable prose contract + LoC trim), Plugin Shape *"Forward-only state machine"*, *"version bump on plugin edits"*, *"kill switch 는 보안 컨트롤"*, AP15 *"loop without repeat detection"*.
- **Related commits**: `23b12a3` (v1.3.0 stop-hook migration), `985465b` (v1.5.0 cross-gate restart removal + total_iterations deprecation), `1166daf` (v1.8.0 Gate 3 active runtime verification), `a98fccb` (v1.9.0 test-scope-validator).
- **Trivia escape**: ❌ N/A — 10 file touches, code refactor 포함, user-visible prompt 변경 포함.
- **Stop-hook 검토 분기점**: 사용자 메시지 *"이제와서는 stop hook 이 반드시 필요할지도 검토해봐"* 가 본 spec 의 scope 을 prose-only → prose + trim 으로 확장한 분기점. 검토 자체는 §Context "Stop-hook 재검토" 표에 보존.
- **Self-review notes (2026-05-13)**: AC8 grep 에서 CHANGELOG 와 의도된 회귀 가드 두 hit 은 허용된 잔존으로 명시. Files-to-Modify 에 사전에 누락되었던 3 fixture 파일 추가. `setup-qg.sh` 는 grep 후 잔존 없음 확인하여 NG7 로 명시. LoC 수치 (main transition handler 72→73) 정정.
