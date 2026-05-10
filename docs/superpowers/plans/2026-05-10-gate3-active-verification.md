# Gate 3 Active Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gate 3 (`runtime-verifier`)가 silent SKIP으로 빠지지 않도록 deterministic pre-flight detector + evidence-required SKIP + mid-run NEEDS_RESOLUTION 3-way ping-pong 구조를 구현한다.

**Architecture:** Hybrid (Approach 3) — `scripts/detect-runtime.sh`가 manifest를 생성, skill이 missing 자원은 upfront로 묻고, runtime-verifier는 manifest 기반으로 모든 surface를 attempt하며 evidence-log를 작성. fixable한 mid-run 실패는 `NEEDS_RESOLUTION` verdict + skill의 AskUserQuestion으로 escalation (max 3회). evidence 미달 SKIP은 자동 FAIL 격상.

**Tech Stack:** bash 5+, python3 (stop-hook), markdown (skill prose), unittest, fixture-based shell tests.

**Spec:** `docs/superpowers/specs/2026-05-10-gate3-active-verification-design.md`

**Branch:** `feature/gate3-active-verification` (이미 생성됨, spec commit `6abd9c4` 위에 stack)

---

## File Structure

**신규:**
- `plugins/quality-gates/scripts/detect-runtime.sh` — pre-flight detector (~150 LoC), stdout YAML manifest
- `plugins/quality-gates/tests/test_detect_runtime.sh` — fixture-based bash test
- `plugins/quality-gates/tests/fixtures/gate3/web-compose/` — happy-path fixture
- `plugins/quality-gates/tests/fixtures/gate3/web-example-only/` — upfront resolution fixture
- `plugins/quality-gates/tests/fixtures/gate3/library-tests/` — pytest-only library
- `plugins/quality-gates/tests/fixtures/gate3/markdown-only/` — fast-path SKIP fixture
- `plugins/quality-gates/tests/test_no_secret_prompts.py` — AskUserQuestion 옵션 라벨에 secret-like input 부재 검증

**수정:**
- `plugins/quality-gates/scripts/setup-qg.sh` — state schema에 `gate3_resolution_iter`, `max_gate3_resolutions` 추가, env override
- `plugins/quality-gates/hooks/stop-hook.py` — `gate3_needs_resolution` transition + prompt builder + repeat detection + state field 파싱
- `plugins/quality-gates/agents/runtime-verifier.md` — frontmatter scoping, 4종 verdict, manifest 입력, evidence-log 의무
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Gate 3 섹션 재작성 (detector dispatch, AskUserQuestion, fast-path SKIP, agent dispatch, evidence 검증, NEEDS_RESOLUTION 루프)
- `plugins/quality-gates/tests/test_stop_hook_state_machine.py` — gate3 transition 신규 테스트
- `plugins/quality-gates/tests/e2e-scenarios.md` — 시나리오 4종 추가
- `plugins/quality-gates/CHANGELOG.md` — `## [1.8.0]` entry
- `plugins/quality-gates/.claude-plugin/plugin.json` — version `1.7.0` → `1.8.0`
- `plugins/quality-gates/README.md` — "Principles Instantiated" 갱신

---

## Task 1: Add `gate3_resolution_iter` / `max_gate3_resolutions` state fields

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:238-251` (state file YAML frontmatter)
- Modify: `plugins/quality-gates/hooks/stop-hook.py:79` (`required_numeric` tuple)
- Test: `plugins/quality-gates/tests/test_stop_hook_state_machine.py` (신규 테스트 추가)

- [ ] **Step 1: Write failing tests for state field parsing**

`plugins/quality-gates/tests/test_stop_hook_state_machine.py` 끝에 신규 클래스 추가:

```python
class TestGate3ResolutionState(unittest.TestCase):
    def test_gate3_resolution_iter_parsed_as_int(self):
        # parse_state_file이 새 필드를 int로 변환하는지 확인.
        import tempfile, textwrap
        content = textwrap.dedent("""\
            ---
            status: gate3_running
            current_gate: 3
            gate2_iteration: 0
            max_gate2_iterations: 5
            gate3_resolution_iter: 1
            max_gate3_resolutions: 3
            skip_runtime: false
            single_gate: null
            session_id: "abc12345"
            started_at: "2026-05-10T00:00:00Z"
            ---

            # Pipeline State
            """)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            path = f.name
        state, _ = stop_hook.parse_state_file(path)
        self.assertEqual(state["gate3_resolution_iter"], 1)
        self.assertEqual(state["max_gate3_resolutions"], 3)
        self.assertIsInstance(state["gate3_resolution_iter"], int)
        self.assertIsInstance(state["max_gate3_resolutions"], int)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest plugins.quality-gates.tests.test_stop_hook_state_machine.TestGate3ResolutionState -v`

또는 ()
```
cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState -v
```

Expected: FAIL — state["gate3_resolution_iter"] KeyError 또는 string 그대로 (int 변환 안 됨).

- [ ] **Step 3: Add fields to setup-qg.sh state file template**

`plugins/quality-gates/scripts/setup-qg.sh:238-251` 의 heredoc을 다음으로 교체 (line 241 `current_gate:` 다음 줄과 line 244 `skip_runtime:` 사이에 두 줄 삽입):

```bash
cat > "$TEMP_FILE" << EOF
---
status: $STATUS
current_gate: $CURRENT_GATE
gate2_iteration: 0
max_gate2_iterations: 5
gate3_resolution_iter: 0
max_gate3_resolutions: $MAX_GATE3_RESOLUTIONS
skip_runtime: $SKIP_RUNTIME
single_gate: ${SINGLE_GATE:-null}
plan_file: "$PLAN_FILE"
pr_url: "$PR_URL"
available_plugins: "$AVAILABLE_PLUGINS"
session_id: "$SESSION_ID"
started_at: "$TIMESTAMP"
---
```

또한 `setup-qg.sh:160` (mkdir 직전) 위에 env override 처리 추가:

```bash
# DEVBREW_GATE3_MAX_RESOLUTIONS env override (default 3, integer 0..10 clamp)
RAW_MAX="${DEVBREW_GATE3_MAX_RESOLUTIONS:-3}"
if [[ ! "$RAW_MAX" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Quality Gates: DEVBREW_GATE3_MAX_RESOLUTIONS='$RAW_MAX' is not numeric; using default 3" >&2
  MAX_GATE3_RESOLUTIONS=3
elif [[ "$RAW_MAX" -gt 10 ]]; then
  MAX_GATE3_RESOLUTIONS=10
else
  MAX_GATE3_RESOLUTIONS="$RAW_MAX"
fi
```

- [ ] **Step 4: Add fields to stop-hook.py parse_state_file**

`plugins/quality-gates/hooks/stop-hook.py:79` 의 `required_numeric` 튜플을 다음으로 변경:

```python
    required_numeric = ("current_gate", "gate2_iteration", "max_gate2_iterations",
                        "gate3_resolution_iter", "max_gate3_resolutions")
```

(같은 함수 아래 int 변환 루프는 변경 없음 — 새 필드도 자동으로 int 변환됨.)

- [ ] **Step 5: Run state-field test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState -v`

Expected: PASS.

- [ ] **Step 6: Run full state-machine test suite (regression check)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine -v`

Expected: 모든 기존 테스트 PASS (state 필드 추가는 후방호환 — 기존 테스트의 state dict에 새 필드를 명시 안 해도 transition 로직은 영향 없음. 단 parse_state_file을 호출하는 테스트가 있으면 새 필드를 parse 가능해야 하므로 test 픽스처에 새 필드도 포함시킬 것).

- [ ] **Step 7: Run setup-qg.sh integration test**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && bash tests/test_setup_qg.sh`

Expected: 모든 테스트 PASS — 새 두 필드가 state file에 기록되는지 (필요하면 grep 어션을 한 줄 추가):

`tests/test_setup_qg.sh`에서 state file 기록 어션이 있는 부분에 다음 추가:

```bash
assert_contains "$(cat $STATE_FILE)" "gate3_resolution_iter: 0" "state file has gate3_resolution_iter"
assert_contains "$(cat $STATE_FILE)" "max_gate3_resolutions: 3" "state file has max_gate3_resolutions default"
```

(파일에 `assert_contains` 헬퍼가 없으면 추가 — `test_discover_plan.sh:23-30` 참고.)

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh \
        plugins/quality-gates/hooks/stop-hook.py \
        plugins/quality-gates/tests/test_stop_hook_state_machine.py \
        plugins/quality-gates/tests/test_setup_qg.sh
git commit -m "feat(qg): add gate3 resolution iteration state fields

State schema에 gate3_resolution_iter (default 0) +
max_gate3_resolutions (default 3, env override
DEVBREW_GATE3_MAX_RESOLUTIONS로 0..10 clamp) 추가.
stop-hook이 새 필드를 int로 parse. 향후 NEEDS_RESOLUTION
루프 카운터로 사용."
```

---

## Task 2: Add `NEEDS_RESOLUTION` → `gate3_needs_resolution` transition

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py:278-285` (Gate 3 transition logic in `compute_transition`)
- Test: `plugins/quality-gates/tests/test_stop_hook_state_machine.py` (TestGate3ResolutionState 클래스 확장)

- [ ] **Step 1: Write failing tests for transition**

`tests/test_stop_hook_state_machine.py` 의 `TestGate3ResolutionState` 클래스에 추가:

```python
    def _gate3_state(self, resolution_iter=0, max_resolutions=3):
        return {
            "current_gate": 3,
            "gate2_iteration": 5,
            "max_gate2_iterations": 5,
            "gate3_resolution_iter": resolution_iter,
            "max_gate3_resolutions": max_resolutions,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }

    def test_gate3_needs_resolution_under_cap_returns_resolution_transition(self):
        state = self._gate3_state(resolution_iter=0)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "docker daemon down"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_needs_resolution")

    def test_gate3_needs_resolution_at_cap_escalates_to_fail(self):
        state = self._gate3_state(resolution_iter=3, max_resolutions=3)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "still missing"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")

    def test_gate3_needs_resolution_with_max_zero_escalates_immediately(self):
        # DEVBREW_GATE3_MAX_RESOLUTIONS=0 (Approach 2 mode)
        state = self._gate3_state(resolution_iter=0, max_resolutions=0)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "no resolution allowed"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")

    def test_gate3_skip_with_evidence_completes(self):
        state = self._gate3_state()
        signal = {"gate": "3", "verdict": "SKIP_WITH_EVIDENCE",
                  "summary": "no runnable surfaces detected"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")

    def test_gate3_legacy_skip_still_completes(self):
        # Backward compat: bare SKIP verdict from older agents still completes.
        state = self._gate3_state()
        signal = {"gate": "3", "verdict": "SKIP", "summary": "user opted out"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState -v`

Expected: 새 4개 테스트가 FAIL — 현재 `compute_transition`은 `NEEDS_RESOLUTION` / `SKIP_WITH_EVIDENCE` 모르므로 default `abort` 반환.

- [ ] **Step 3: Implement transition logic in stop-hook.py**

`plugins/quality-gates/hooks/stop-hook.py:278-288` (Gate 3 분기) 를 다음으로 교체:

```python
    # --- Gate 3 transitions ---
    if gate == "3":
        if verdict in ("PASS", "SKIP", "SKIP_WITH_EVIDENCE"):
            return {"type": "complete"}
        if verdict == "NEEDS_RESOLUTION":
            iter_now = state.get("gate3_resolution_iter", 0)
            max_now = state.get("max_gate3_resolutions", 3)
            if iter_now < max_now:
                return {"type": "gate3_needs_resolution"}
            # max reached → escalate to gate3_fail (existing prompt)
            return {"type": "gate3_fail"}
        if verdict in ("NEEDS_RESTART", "FAIL"):
            # Forward-only: Gate 3 issues require user attention; no auto-restart.
            # build_special_prompt("gate3_fail") covers both paths uniformly.
            return {"type": "gate3_fail"}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState -v`

Expected: 모든 테스트 PASS.

- [ ] **Step 5: Run full state-machine suite (regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine -v`

Expected: 모든 기존 + 신규 테스트 PASS. 특히 `test_gate3_needs_restart_terminates_with_user_choice` (line 37) 는 여전히 NEEDS_RESTART → gate3_fail 매핑을 verify하며 통과.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py \
        plugins/quality-gates/tests/test_stop_hook_state_machine.py
git commit -m "feat(qg): NEEDS_RESOLUTION transition with iteration cap

Gate 3가 NEEDS_RESOLUTION verdict emit 시 iter < max이면
gate3_needs_resolution transition으로 user choice 주입,
iter == max이면 gate3_fail로 격상. SKIP_WITH_EVIDENCE는
PASS/SKIP과 동등하게 complete로 종료. DEVBREW_GATE3_MAX_RESOLUTIONS=0
환경에서 첫 NEEDS_RESOLUTION이 즉시 fail로 escalate (Approach 2 모드)."
```

---

## Task 3: Add `gate3_needs_resolution` prompt builder + iteration counter increment

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py:478` (build_special_prompt) — 신규 transition_type 처리
- Modify: `plugins/quality-gates/hooks/stop-hook.py` (update_state_file 또는 동등 위치) — gate3_resolution_iter 증가
- Test: `plugins/quality-gates/tests/test_stop_hook_state_machine.py`

- [ ] **Step 1: Write failing test for prompt builder**

`TestGate3ResolutionState`에 추가:

```python
    def test_gate3_needs_resolution_prompt_contains_user_choices(self):
        state = self._gate3_state(resolution_iter=1, max_resolutions=3)
        gate_results = "### Gate 3 (iter 1)\n**Summary:** docker daemon down\n"
        prompt = stop_hook.build_special_prompt(
            "gate3_needs_resolution", state, gate_results
        )
        # Prompt must surface the actionable choices (retry/skip/abort) and
        # explicit guidance to NOT request secret values from the user.
        self.assertIn("GATE3_NEEDS_RESOLUTION", prompt)
        self.assertIn("retry", prompt.lower())
        self.assertIn("skip", prompt.lower())
        self.assertIn("abort", prompt.lower())
        # iteration counter visible to user
        self.assertIn("1", prompt)
        self.assertIn("3", prompt)
        # Explicit guard: prompt instructs not to ask for secret values
        self.assertIn("decision", prompt.lower())  # 결정만 묻기
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState.test_gate3_needs_resolution_prompt_contains_user_choices -v`

Expected: FAIL — `build_special_prompt`이 `gate3_needs_resolution`을 모르므로 빈 문자열 또는 기존 fallback 반환.

- [ ] **Step 3: Add prompt builder for gate3_needs_resolution**

`plugins/quality-gates/hooks/stop-hook.py:478` 의 `if transition_type == "gate3_fail":` 직후에 추가:

```python
    if transition_type == "gate3_needs_resolution":
        iter_now = state.get("gate3_resolution_iter", 0)
        max_now = state.get("max_gate3_resolutions", 3)
        return (
            "GATE3_NEEDS_RESOLUTION\n\n"
            "Gate 3 (Runtime Verification) found resolvable missing resources "
            f"(resolution iteration {iter_now + 1}/{max_now}).\n\n"
            "The skill (mother) must present the agent's `needed` items to the user "
            "as **decision-only** options (retry / skip this surface / abort). "
            "DO NOT ask the user for secret values (API keys, DB URLs, tokens, "
            "passwords). If a secret is required, the only valid options are: "
            "user sets the secret in .env on disk and chooses retry, OR skip the "
            "affected surface, OR abort.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Retry — user has resolved the missing resource (e.g., started "
            "Docker daemon, added env var to .env). Re-dispatch runtime-verifier.\n"
            "2. Skip this surface — record the surface as unresolved in evidence-log "
            "and continue with remaining surfaces.\n"
            "3. Abort — stop the pipeline.\n\n"
            "Based on user choice:\n"
            "- Retry: re-dispatch runtime-verifier with updated manifest "
            '(skill increments gate3_resolution_iter). Then emit '
            '<qg-signal gate="3" verdict="..." iteration="N" /> with the new verdict.\n'
            '- Skip surface: emit <qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" '
            'summary="user opted to skip <surface>" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort '
            'during gate3_needs_resolution" />\n'
            f"\nPipeline context:\n{gate_results}"
        )
```

- [ ] **Step 4: Run prompt-builder test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState.test_gate3_needs_resolution_prompt_contains_user_choices -v`

Expected: PASS.

- [ ] **Step 5: Wire iteration counter increment in update_state_file**

`plugins/quality-gates/hooks/stop-hook.py` 의 `update_state_file` 함수에서 transition 처리 부분을 검토. 새 transition `gate3_needs_resolution` 진입 시 state["gate3_resolution_iter"]를 1 증가시켜야 함. 구체 위치는 함수 안의 transition_type 분기 또는 frontmatter 재작성 직전. 다음 패턴으로 추가 (정확한 줄은 update_state_file 본문 안):

```python
    # Track gate3 resolution iteration (forward-only count).
    if transition.get("type") == "gate3_needs_resolution":
        state["gate3_resolution_iter"] = state.get("gate3_resolution_iter", 0) + 1
```

이 블록은 frontmatter를 다시 쓰기 전에 실행되어야 함 (state dict 갱신 후 직렬화).

- [ ] **Step 6: Add iteration-increment regression test**

`TestGate3ResolutionState`에 추가:

```python
    def test_gate3_resolution_iter_increments_on_transition(self):
        # Simulate two consecutive NEEDS_RESOLUTION cycles.
        state = self._gate3_state(resolution_iter=0)
        # Mock minimal update_state_file: pull the increment side-effect from
        # the harness used in production. We assert the contract via an explicit
        # call.
        transition = {"type": "gate3_needs_resolution"}
        # Replicate increment logic from update_state_file:
        if transition.get("type") == "gate3_needs_resolution":
            state["gate3_resolution_iter"] = state.get("gate3_resolution_iter", 0) + 1
        self.assertEqual(state["gate3_resolution_iter"], 1)
```

(이 테스트는 logic을 직접 호출하는 light-weight regression. 더 깊은 검증은 e2e fixture로 커버.)

- [ ] **Step 7: Run full test suite (regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine -v`

Expected: 모두 PASS.

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py \
        plugins/quality-gates/tests/test_stop_hook_state_machine.py
git commit -m "feat(qg): gate3_needs_resolution prompt + iter counter

build_special_prompt이 GATE3_NEEDS_RESOLUTION 키워드와 함께
retry/skip-surface/abort 3-way 결정만 노출 (P21: secret 값
요청 금지 명시). update_state_file이 transition 진입 시
gate3_resolution_iter를 1 증가."
```

---

## Task 4: Add repeat detection for `NEEDS_RESOLUTION` (`gate3_repeat_detected`)

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py` — repeat detection logic
- Test: `plugins/quality-gates/tests/test_stop_hook_state_machine.py`

- [ ] **Step 1: Write failing test for repeat detection**

`TestGate3ResolutionState`에 추가:

```python
    def test_gate3_repeat_detected_when_same_needed_twice(self):
        # When two consecutive NEEDS_RESOLUTION emit the SAME `needed_hash`,
        # transition must escalate to gate3_repeat_detected, not just increment.
        state = self._gate3_state(resolution_iter=1, max_resolutions=3)
        state["last_gate3_needed_hash"] = "abc123"
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                  "summary": "still down", "needed_hash": "abc123"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_repeat_detected")

    def test_gate3_different_needed_hash_continues_resolution(self):
        # Different needed_hash → progress is being made, continue.
        state = self._gate3_state(resolution_iter=1, max_resolutions=3)
        state["last_gate3_needed_hash"] = "abc123"
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                  "summary": "different problem", "needed_hash": "xyz789"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_needs_resolution")

    def test_gate3_repeat_detected_prompt(self):
        state = self._gate3_state(resolution_iter=2, max_resolutions=3)
        prompt = stop_hook.build_special_prompt(
            "gate3_repeat_detected", state, "context"
        )
        self.assertIn("GATE3_REPEAT_DETECTED", prompt)
        self.assertIn("PASS_WITH_WARNINGS", prompt)
        self.assertIn("abort", prompt.lower())
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine.TestGate3ResolutionState -v`

Expected: 새 3개 테스트 FAIL.

- [ ] **Step 3: Implement repeat detection in compute_transition**

`hooks/stop-hook.py` 의 `if verdict == "NEEDS_RESOLUTION":` 블록을 다음으로 교체:

```python
        if verdict == "NEEDS_RESOLUTION":
            iter_now = state.get("gate3_resolution_iter", 0)
            max_now = state.get("max_gate3_resolutions", 3)
            # Repeat detection: same needed_hash from prior iteration → not converging
            current_hash = signal.get("needed_hash", "")
            prior_hash = state.get("last_gate3_needed_hash", "")
            if iter_now > 0 and current_hash and current_hash == prior_hash:
                return {"type": "gate3_repeat_detected"}
            if iter_now < max_now:
                return {"type": "gate3_needs_resolution"}
            return {"type": "gate3_fail"}
```

- [ ] **Step 4: Add `last_gate3_needed_hash` field to state schema**

setup-qg.sh의 state file heredoc에 새 줄 추가 (Task 1의 frontmatter 블록 안에 `gate3_resolution_iter: 0` 다음 줄):

```
last_gate3_needed_hash: ""
```

stop-hook.py의 parse_state_file에서 이 필드는 string이므로 numeric 변환 안 됨. `state["last_gate3_needed_hash"]` 는 raw string으로 사용 — 추가 코드 불필요.

update_state_file에서 transition이 `gate3_needs_resolution` 진입 시 `last_gate3_needed_hash`를 signal의 `needed_hash`로 갱신:

```python
    if transition.get("type") == "gate3_needs_resolution":
        state["gate3_resolution_iter"] = state.get("gate3_resolution_iter", 0) + 1
        state["last_gate3_needed_hash"] = signal.get("needed_hash", "")
```

- [ ] **Step 5: Add gate3_repeat_detected prompt builder**

`hooks/stop-hook.py` 의 `if transition_type == "gate3_needs_resolution":` 블록 직후에 추가:

```python
    if transition_type == "gate3_repeat_detected":
        return (
            "GATE3_REPEAT_DETECTED\n\n"
            "Gate 3 (Runtime Verification) is not converging — "
            "the same `needed` resources appeared 2 iterations in a row.\n\n"
            "Present options to the user via AskUserQuestion:\n"
            "1. Proceed — accept the current state with warnings and continue\n"
            "2. Abort — stop the pipeline\n\n"
            "Based on user choice:\n"
            '- Proceed: emit <qg-signal gate="3" verdict="PASS_WITH_WARNINGS" '
            'summary="Repeat detected; user accepted" files_changed="" />\n'
            '- Abort: emit <qg-signal action="abort" reason="User chose to abort" />\n'
            f"\nPipeline context:\n{gate_results}"
        )
```

또한 Gate 3 verdict handler 분기에 `PASS_WITH_WARNINGS` 매핑을 추가:

`compute_transition` 의 Gate 3 블록 첫 줄을 다음으로 확장:

```python
    if gate == "3":
        if verdict in ("PASS", "SKIP", "SKIP_WITH_EVIDENCE", "PASS_WITH_WARNINGS"):
            return {"type": "complete"}
        ...
```

- [ ] **Step 6: Make `gate3_repeat_detected` and `gate3_needs_resolution` block stop-hook**

`hooks/stop-hook.py:659` 의 transition type 체크 라인에 새 두 type을 포함시킴:

```python
    if transition["type"] in ("gate2_user_choice", "max_gate2_exceeded",
                              "gate3_fail", "gate3_needs_resolution",
                              "gate3_repeat_detected"):
```

(이 라인은 user-choice 인터럽션이 발생할 때 stop-hook이 normal complete가 아닌 user-prompt 주입 모드로 전환되는 곳.)

같은 이유로 line 557 의 `if t_type in ("max_gate2_exceeded", "gate3_fail", "gate2_user_choice"):` 도 확장:

```python
    if t_type in ("max_gate2_exceeded", "gate3_fail", "gate2_user_choice",
                  "gate3_needs_resolution", "gate3_repeat_detected"):
```

- [ ] **Step 7: Run all stop-hook tests**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_stop_hook_state_machine -v`

Expected: 모두 PASS.

- [ ] **Step 8: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py \
        plugins/quality-gates/scripts/setup-qg.sh \
        plugins/quality-gates/tests/test_stop_hook_state_machine.py
git commit -m "feat(qg): gate3 repeat detection + PASS_WITH_WARNINGS path

같은 needed_hash가 2회 연속이면 gate3_repeat_detected로 escalate
(AP15 unbounded autonomy 가드). User가 proceed 선택 시 verdict=
PASS_WITH_WARNINGS로 complete. last_gate3_needed_hash 필드를
state schema에 추가."
```

---

## Task 5: Create `detect-runtime.sh` skeleton + first fixture (markdown-only)

**Files:**
- Create: `plugins/quality-gates/scripts/detect-runtime.sh` (skeleton)
- Create: `plugins/quality-gates/tests/test_detect_runtime.sh`
- Create: `plugins/quality-gates/tests/fixtures/gate3/markdown-only/README.md`

- [ ] **Step 1: Create markdown-only fixture**

```bash
mkdir -p /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/fixtures/gate3/markdown-only
```

파일 작성: `tests/fixtures/gate3/markdown-only/README.md`

```markdown
# markdown-only fixture
This repo has no runnable code. Detector should return empty runnable_surfaces.
```

- [ ] **Step 2: Write failing test**

`plugins/quality-gates/tests/test_detect_runtime.sh` 신규 파일:

```bash
#!/usr/bin/env bash
# Tests for scripts/detect-runtime.sh — fixture-based black-box testing.
# Mirrors style of test_discover_plan.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/detect-runtime.sh"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures/gate3"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (got '$actual', expected '$expected')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in output)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$needle' in output)"
  fi
}

run_detector() {
  local fixture="$1"; shift
  cd "$FIXTURES/$fixture"
  bash "$SCRIPT" "$@" 2>"$FIXTURES/$fixture/_stderr"
  return $?
}

# --- Test 1: markdown-only fixture → empty runnable_surfaces ---
echo "== Test 1: markdown-only =="
OUT=$(run_detector "markdown-only")
RC=$?
assert_eq "$RC" "0" "T1: exit 0"
assert_contains "$OUT" "project_type:" "T1: emits project_type"
assert_contains "$OUT" "runnable_surfaces: []" "T1: empty runnable_surfaces"
assert_contains "$OUT" "test_runners: []" "T1: empty test_runners"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
```

만든 후 실행 권한 부여: `chmod +x plugins/quality-gates/tests/test_detect_runtime.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: FAIL — `detect-runtime.sh` 가 아직 없음.

- [ ] **Step 4: Create detect-runtime.sh skeleton**

`plugins/quality-gates/scripts/detect-runtime.sh` 신규:

```bash
#!/usr/bin/env bash
# detect-runtime.sh — emit a YAML manifest describing runtime-verification
# surfaces in the current working directory.
#
# Output (single multi-line YAML to stdout, expected by SKILL.md Gate 3):
#   project_type: web|cli|library|unknown
#   runnable_surfaces: [...]
#   test_runners: [...]
#   mcp_browser: chrome-devtools|playwright|none
#   app_url_candidates: [...]
#   env_status: [...]
#   plan_features: [...]
#   attempted_log_path: .claude/quality-gates/<sid>/gate3-evidence.md
#
# Exit codes: 0 = ok (parse manifest), non-zero = invariant violation
# (skill should fail-open: treat as empty manifest).
#
# Read-only. Never creates / modifies / deletes files.
# Invoke from the project root (relies on $PWD).

set -u  # NOT -e: we want graceful degradation; failure of a sub-detection
        # should not abort the whole detector.

# --- Helpers ---

emit() { printf '%s\n' "$*"; }

# --- Project type detection ---
PROJECT_TYPE="unknown"

# Web: package.json with dev/start/serve, manage.py, app.py with framework, docker-compose
if [[ -f package.json ]] && grep -qE '"(dev|start|serve)"' package.json 2>/dev/null; then
  PROJECT_TYPE="web"
elif [[ -f manage.py ]] || \
     ([[ -f app.py ]] && grep -qE '(flask|fastapi|django)' app.py 2>/dev/null) || \
     ([[ -f main.py ]] && grep -qE '(flask|fastapi|uvicorn|django)' main.py 2>/dev/null); then
  PROJECT_TYPE="web"
elif [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  PROJECT_TYPE="web"
# CLI: pyproject.toml [project.scripts], Cargo.toml [[bin]] without web deps
elif [[ -f pyproject.toml ]] && grep -q '\[project.scripts\]' pyproject.toml 2>/dev/null; then
  PROJECT_TYPE="cli"
elif [[ -f Cargo.toml ]] && grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null && \
     ! grep -qE '(actix|axum|rocket|warp)' Cargo.toml 2>/dev/null; then
  PROJECT_TYPE="cli"
# Library: only lib/ or src/ with build script, or only test infra
elif [[ -f package.json ]] && grep -qE '"(test|build)"' package.json 2>/dev/null; then
  PROJECT_TYPE="library"
elif [[ -f pyproject.toml ]] && [[ -d tests ]]; then
  PROJECT_TYPE="library"
fi

# --- Emit minimal manifest (Task 5: skeleton) ---
emit "project_type: $PROJECT_TYPE"
emit "runnable_surfaces: []"
emit "test_runners: []"
emit "mcp_browser: none"
emit "app_url_candidates: []"
emit "env_status: []"
emit "plan_features: []"
emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/gate3-evidence.md"

exit 0
```

실행 권한 부여: `chmod +x plugins/quality-gates/scripts/detect-runtime.sh`

- [ ] **Step 5: Run T1 to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: T1 PASS (project_type 출력, runnable_surfaces=[], test_runners=[]).

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/detect-runtime.sh \
        plugins/quality-gates/tests/test_detect_runtime.sh \
        plugins/quality-gates/tests/fixtures/gate3/markdown-only/
git commit -m "feat(qg): detect-runtime.sh skeleton + markdown-only fixture

스크립트 골격: project_type만 detect, 나머지 필드는 빈 list.
Markdown-only fixture로 fast-path SKIP 시나리오를 위한 첫 fixture.
다음 task에서 runnable_surfaces / test_runners / mcp_browser /
env_status / plan_features 채움."
```

---

## Task 6: Detect runnable surfaces (docker-compose, npm scripts, pytest, cargo, go)

**Files:**
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh`
- Modify: `plugins/quality-gates/tests/test_detect_runtime.sh`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-compose/docker-compose.yml`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-compose/package.json`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-compose/.env`
- Create: `plugins/quality-gates/tests/fixtures/gate3/library-tests/pyproject.toml`
- Create: `plugins/quality-gates/tests/fixtures/gate3/library-tests/tests/test_foo.py`

- [ ] **Step 1: Create web-compose fixture**

```
mkdir -p /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/fixtures/gate3/web-compose
```

`tests/fixtures/gate3/web-compose/docker-compose.yml`:

```yaml
version: "3"
services:
  app:
    image: example
    ports:
      - "3000:3000"
```

`tests/fixtures/gate3/web-compose/package.json`:

```json
{
  "name": "fixture-web-compose",
  "scripts": {
    "dev": "echo 'fake dev server'",
    "test": "echo 'fake tests'"
  }
}
```

`tests/fixtures/gate3/web-compose/.env`:

```
EXAMPLE_VAR=value
```

- [ ] **Step 2: Create library-tests fixture**

```
mkdir -p /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/fixtures/gate3/library-tests/tests
```

`tests/fixtures/gate3/library-tests/pyproject.toml`:

```toml
[project]
name = "fixture-lib"
version = "0.1.0"
```

`tests/fixtures/gate3/library-tests/tests/test_foo.py`:

```python
def test_one():
    assert True
```

- [ ] **Step 3: Add T2 + T3 failing tests**

`tests/test_detect_runtime.sh` 의 T1 다음에 추가:

```bash
# --- Test 2: web-compose fixture → docker-compose + npm-script surfaces ---
echo "== Test 2: web-compose =="
OUT=$(run_detector "web-compose")
RC=$?
assert_eq "$RC" "0" "T2: exit 0"
assert_contains "$OUT" "project_type: web" "T2: project_type=web"
assert_contains "$OUT" "kind: docker-compose" "T2: docker-compose surface"
assert_contains "$OUT" "kind: npm-script" "T2: npm-script surface"
assert_contains "$OUT" "name: dev" "T2: npm:dev script detected"
assert_contains "$OUT" "name: test" "T2: npm:test script detected"
assert_contains "$OUT" "test_runners:" "T2: emits test_runners"
assert_contains "$OUT" "- npm" "T2: npm in test_runners"

# --- Test 3: library-tests fixture → pytest only ---
echo "== Test 3: library-tests =="
OUT=$(run_detector "library-tests")
RC=$?
assert_eq "$RC" "0" "T3: exit 0"
assert_contains "$OUT" "project_type: library" "T3: project_type=library"
assert_contains "$OUT" "kind: pytest" "T3: pytest surface"
assert_contains "$OUT" "- pytest" "T3: pytest in test_runners"
assert_not_contains "$OUT" "kind: npm-script" "T3: no npm in non-node project"
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: T1 PASS, T2/T3 FAIL — runnable_surfaces 가 여전히 `[]`.

- [ ] **Step 5: Implement runnable_surfaces detection**

`scripts/detect-runtime.sh` 의 `# --- Emit minimal manifest ---` 블록 직전에 다음 detection 로직 추가:

```bash
# --- Runnable surfaces ---
SURFACES=()
TEST_RUNNERS=()

# docker-compose
if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  COMPOSE_PATH="docker-compose.yml"
  [[ -f docker-compose.yaml ]] && COMPOSE_PATH="docker-compose.yaml"
  SURFACES+=("$(printf '  - kind: docker-compose\n    path: %s\n    requires_decision: true' "$COMPOSE_PATH")")
fi

# npm-scripts: dev / start / serve / test (each as its own surface)
if [[ -f package.json ]]; then
  for script in dev start serve test; do
    if grep -qE "\"$script\"\s*:" package.json 2>/dev/null; then
      SURFACES+=("$(printf '  - kind: npm-script\n    name: %s\n    command: npm run %s' "$script" "$script")")
      if [[ "$script" == "test" ]]; then
        TEST_RUNNERS+=("npm")
      fi
    fi
  done
  # If npm test detected but not in TEST_RUNNERS yet (rare), add it.
  if grep -qE '"test"\s*:' package.json 2>/dev/null && \
     [[ ! " ${TEST_RUNNERS[*]} " =~ " npm " ]]; then
    TEST_RUNNERS+=("npm")
  fi
fi

# pytest
if [[ -f pyproject.toml ]] || [[ -f pytest.ini ]] || [[ -f setup.cfg ]]; then
  if [[ -d tests ]] || [[ -d test ]] || \
     find . -maxdepth 2 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: pytest\n    command: pytest')")
    TEST_RUNNERS+=("pytest")
  fi
fi

# cargo (test + run)
if [[ -f Cargo.toml ]]; then
  SURFACES+=("$(printf '  - kind: cargo-test\n    command: cargo test')")
  TEST_RUNNERS+=("cargo")
  if grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    SURFACES+=("$(printf '  - kind: cargo-run\n    command: cargo run')")
  fi
fi

# go
if [[ -f go.mod ]]; then
  SURFACES+=("$(printf '  - kind: go-test\n    command: go test ./...')")
  TEST_RUNNERS+=("go")
  # go run requires a main.go entry; check for it
  if find . -maxdepth 2 -name 'main.go' 2>/dev/null | head -1 | grep -q .; then
    SURFACES+=("$(printf '  - kind: go-run\n    command: go run ./...')")
  fi
fi

# Makefile targets
if [[ -f Makefile ]]; then
  for target in run serve test; do
    if grep -qE "^${target}:" Makefile 2>/dev/null; then
      SURFACES+=("$(printf '  - kind: makefile\n    target: %s\n    command: make %s' "$target" "$target")")
      if [[ "$target" == "test" ]]; then
        TEST_RUNNERS+=("make")
      fi
    fi
  done
fi
```

emit 블록을 다음으로 교체 (runnable_surfaces / test_runners 채우기):

```bash
# --- Emit manifest ---
emit "project_type: $PROJECT_TYPE"

if [[ ${#SURFACES[@]} -eq 0 ]]; then
  emit "runnable_surfaces: []"
else
  emit "runnable_surfaces:"
  for s in "${SURFACES[@]}"; do emit "$s"; done
fi

if [[ ${#TEST_RUNNERS[@]} -eq 0 ]]; then
  emit "test_runners: []"
else
  emit "test_runners:"
  for r in "${TEST_RUNNERS[@]}"; do emit "  - $r"; done
fi

emit "mcp_browser: none"
emit "app_url_candidates: []"
emit "env_status: []"
emit "plan_features: []"
emit "attempted_log_path: .claude/quality-gates/${CLAUDE_CODE_SESSION_ID:-unknown}/gate3-evidence.md"

exit 0
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: T1, T2, T3 모두 PASS.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/detect-runtime.sh \
        plugins/quality-gates/tests/test_detect_runtime.sh \
        plugins/quality-gates/tests/fixtures/gate3/web-compose/ \
        plugins/quality-gates/tests/fixtures/gate3/library-tests/
git commit -m "feat(qg): detect runnable surfaces (compose/npm/pytest/cargo/go/make)

docker-compose / npm scripts (dev/start/serve/test) /
pytest / cargo test+run / go test+run / Makefile run+serve+test
각각을 runnable_surfaces로 enumerate. test_runners에는
test 가능한 runner names. requires_decision은 docker-compose에만
true (compose up은 사용자 승인 필요)."
```

---

## Task 7: Detect mcp_browser, env_status, app_url_candidates, plan_features

**Files:**
- Modify: `plugins/quality-gates/scripts/detect-runtime.sh`
- Modify: `plugins/quality-gates/tests/test_detect_runtime.sh`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-example-only/docker-compose.yml`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-example-only/package.json`
- Create: `plugins/quality-gates/tests/fixtures/gate3/web-example-only/.env.example`

- [ ] **Step 1: Create web-example-only fixture**

```
mkdir -p /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/fixtures/gate3/web-example-only
```

`tests/fixtures/gate3/web-example-only/docker-compose.yml`:

```yaml
version: "3"
services:
  app:
    image: example
    ports:
      - "8000:8000"
```

`tests/fixtures/gate3/web-example-only/package.json`:

```json
{
  "name": "fixture-web-example-only",
  "scripts": {
    "dev": "echo 'fake dev server'"
  }
}
```

`tests/fixtures/gate3/web-example-only/.env.example`:

```
DB_URL=postgres://localhost/example
API_KEY=replace-me
```

- [ ] **Step 2: Add T4 + env_status + mcp + app_url tests**

`tests/test_detect_runtime.sh` 끝부분 (`echo ""` 직전)에 추가:

```bash
# --- Test 4: web-example-only fixture → env_status flags missing .env ---
echo "== Test 4: web-example-only =="
OUT=$(run_detector "web-example-only")
RC=$?
assert_eq "$RC" "0" "T4: exit 0"
assert_contains "$OUT" "project_type: web" "T4: web project"
assert_contains "$OUT" "env_status:" "T4: emits env_status"
assert_contains "$OUT" "file: .env" "T4: tracks .env file"
assert_contains "$OUT" "exists: false" "T4: .env does not exist"
assert_contains "$OUT" "has_example: true" "T4: .env.example present"

# --- Test 5: app_url_candidates from docker-compose ports ---
echo "== Test 5: app_url_candidates =="
OUT=$(run_detector "web-compose")
assert_contains "$OUT" "app_url_candidates:" "T5: emits app_url_candidates"
assert_contains "$OUT" "http://localhost:3000" "T5: port 3000 from compose"

# --- Test 6: mcp_browser detection (default none in fixture without claude config) ---
echo "== Test 6: mcp_browser default =="
OUT=$(run_detector "markdown-only")
assert_contains "$OUT" "mcp_browser:" "T6: emits mcp_browser"

# --- Test 7: plan_features extracted from plan_path ---
echo "== Test 7: plan_features extraction =="
PLAN_TMP=$(mktemp)
cat > "$PLAN_TMP" <<'EOF'
# Plan
- visit /auth login form
- check /dashboard
EOF
OUT=$(cd "$FIXTURES/web-compose" && PLAN_PATH="$PLAN_TMP" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "plan_features:" "T7: emits plan_features"
assert_contains "$OUT" "/auth" "T7: extracts /auth"
assert_contains "$OUT" "/dashboard" "T7: extracts /dashboard"
rm -f "$PLAN_TMP"
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: T1–T3 PASS, T4–T7 FAIL.

- [ ] **Step 4: Implement detection logic in detect-runtime.sh**

`scripts/detect-runtime.sh` 에서 `# --- Runnable surfaces ---` 블록 다음에 추가:

```bash
# --- env_status ---
ENV_STATUS=()
for envfile in .env .env.local .env.development; do
  if [[ -f "$envfile" ]]; then
    ENV_STATUS+=("$(printf '  - file: %s\n    exists: true\n    has_example: false' "$envfile")")
  elif [[ -f "${envfile}.example" ]]; then
    ENV_STATUS+=("$(printf '  - file: %s\n    exists: false\n    has_example: true' "$envfile")")
  fi
done

# --- mcp_browser detection ---
# Strategy: read ~/.claude/settings.json or .claude/settings.json for known
# MCP server entries. chrome-devtools wins over playwright.
MCP_BROWSER="none"
SETTINGS_FILES=("$HOME/.claude/settings.json" ".claude/settings.json" ".mcp.json")
for sf in "${SETTINGS_FILES[@]}"; do
  if [[ -f "$sf" ]]; then
    if grep -qi 'chrome-devtools' "$sf" 2>/dev/null; then
      MCP_BROWSER="chrome-devtools"
      break
    fi
    if grep -qi 'playwright' "$sf" 2>/dev/null; then
      MCP_BROWSER="playwright"
      # Don't break — chrome-devtools in another settings file wins
    fi
  fi
done

# --- app_url_candidates ---
URL_CANDIDATES=()
# Default ports
if [[ "$PROJECT_TYPE" == "web" ]]; then
  URL_CANDIDATES+=("http://localhost:3000")
  URL_CANDIDATES+=("http://localhost:8000")
fi
# Parse port mappings from docker-compose
if [[ -f docker-compose.yml ]] || [[ -f docker-compose.yaml ]]; then
  COMPOSE_FILE="docker-compose.yml"
  [[ -f docker-compose.yaml ]] && COMPOSE_FILE="docker-compose.yaml"
  # Extract "<host>:<container>" port mappings, take host port
  while IFS= read -r port; do
    [[ -n "$port" ]] && URL_CANDIDATES+=("http://localhost:$port")
  done < <(grep -oE '"[0-9]+:[0-9]+"|- [0-9]+:[0-9]+' "$COMPOSE_FILE" 2>/dev/null \
            | sed -E 's/.*"?([0-9]+):[0-9]+"?/\1/' | sort -u)
fi
# Dedupe
if [[ ${#URL_CANDIDATES[@]} -gt 0 ]]; then
  IFS=$'\n' URL_CANDIDATES=($(printf '%s\n' "${URL_CANDIDATES[@]}" | awk '!seen[$0]++'))
  unset IFS
fi

# --- plan_features extraction ---
PLAN_FEATURES=()
if [[ -n "${PLAN_PATH:-}" ]] && [[ -f "$PLAN_PATH" ]]; then
  # Extract /<word> route patterns and "X form/page" phrases
  while IFS= read -r match; do
    [[ -n "$match" ]] && PLAN_FEATURES+=("$match")
  done < <(grep -oE '/[a-zA-Z][a-zA-Z0-9_/-]*' "$PLAN_PATH" 2>/dev/null | sort -u | head -10)
  while IFS= read -r match; do
    [[ -n "$match" ]] && PLAN_FEATURES+=("\"$match\"")
  done < <(grep -oE '[a-zA-Z]+ (form|page|dashboard|panel)' "$PLAN_PATH" 2>/dev/null | sort -u | head -5)
fi
```

emit 블록의 mcp_browser / app_url_candidates / env_status / plan_features 줄을 다음으로 교체:

```bash
emit "mcp_browser: $MCP_BROWSER"

if [[ ${#URL_CANDIDATES[@]} -eq 0 ]]; then
  emit "app_url_candidates: []"
else
  emit "app_url_candidates:"
  for u in "${URL_CANDIDATES[@]}"; do emit "  - $u"; done
fi

if [[ ${#ENV_STATUS[@]} -eq 0 ]]; then
  emit "env_status: []"
else
  emit "env_status:"
  for e in "${ENV_STATUS[@]}"; do emit "$e"; done
fi

if [[ ${#PLAN_FEATURES[@]} -eq 0 ]]; then
  emit "plan_features: []"
else
  emit "plan_features:"
  for f in "${PLAN_FEATURES[@]}"; do emit "  - $f"; done
fi
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_detect_runtime.sh`

Expected: T1–T7 모두 PASS.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/detect-runtime.sh \
        plugins/quality-gates/tests/test_detect_runtime.sh \
        plugins/quality-gates/tests/fixtures/gate3/web-example-only/
git commit -m "feat(qg): detect env_status / mcp_browser / app_url / plan_features

env_status: .env / .env.local / .env.development 각각 exists +
has_example 보고. mcp_browser: ~/.claude/settings.json or
.claude/settings.json or .mcp.json grep으로 chrome-devtools
우선 → playwright. app_url_candidates: docker-compose port 매핑
파싱 + web 기본값 :3000/:8000. plan_features: PLAN_PATH env로
받은 plan markdown에서 /<route> 패턴과 'form/page/dashboard/panel'
구문 추출."
```

---

## Task 8: Update `runtime-verifier.md` — frontmatter scoping + verdict taxonomy + evidence-log spec

**Files:**
- Modify: `plugins/quality-gates/agents/runtime-verifier.md` (전체 재작성)
- Test: 신규 frontmatter validation을 inline grep으로

- [ ] **Step 1: Write a static lint test**

`plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` 신규:

```bash
#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter compliance with CLAUDE.md
# "Plugin Shape" requirements (no default-everything; Write/Edit must be
# disallowed for the reviewer agent).

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/runtime-verifier.md"
PASS=0
FAIL=0

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not in file)"
  fi
}

assert_grep "^cost_class: variable" "cost_class is variable (was low)"
assert_grep "^allowedTools:" "allowedTools declared"
assert_grep "^disallowedTools:" "disallowedTools declared"
assert_grep "disallowedTools:.*$|^\s+- Write" "Write in disallowedTools"
# Verify body declares verdict taxonomy
assert_grep "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
```

`chmod +x plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`

Expected: FAIL — `cost_class: low`, `allowedTools` 부재, verdict taxonomy 미기재.

- [ ] **Step 3: Rewrite agents/runtime-verifier.md**

`plugins/quality-gates/agents/runtime-verifier.md` 전체 재작성:

```markdown
---
name: runtime-verifier
model: sonnet
cost_class: variable
color: green
allowedTools:
  - Read
  - Bash
  - Grep
  - Glob
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__get_console_message
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__close_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page
  - mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
description: >
  Use this agent for runtime verification of applications as Gate 3 of the
  quality-gates pipeline. Reads a manifest from the skill, attempts each
  declared runnable surface, writes an evidence-log, and emits one of four
  verdicts (PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION). The agent
  cannot create or edit project files — fixable missing resources are
  escalated to the user via NEEDS_RESOLUTION (Law 2: writer/reviewer
  separation enforced via tool scoping).

  <example>Context: Quality pipeline Gate 3 — manifest declares docker-compose,
  npm:dev, and chrome-devtools MCP. Agent attempts each, captures console
  errors and screenshots.
  user: "Verify the app runs against the supplied manifest."
  assistant: "I'll dispatch the runtime-verifier agent with the manifest
  and capture an evidence-log of attempts."</example>

  <example>Context: Manifest declares docker-compose but `docker compose up`
  fails due to daemon being down. Agent emits NEEDS_RESOLUTION asking the
  skill to escalate to the user.
  user: "Run gate 3 with this manifest."
  assistant: "I'll attempt the manifest items; if a fixable failure occurs
  I'll emit NEEDS_RESOLUTION so the skill can ask the user."</example>
---

# Runtime Verifier Agent (Gate 3)

You are the Runtime Verifier — Gate 3 of the quality-gates pipeline. You attempt every runnable surface declared in the manifest provided by the skill (mother) and produce an **evidence-log** documenting each attempt. You emit exactly one verdict at the end.

## Input

The skill dispatches you with a prompt that contains the following sections:

- `project_dir`: project working directory
- `plan_path`: path to plan file (or `auto`)
- **Manifest** — YAML block emitted by `scripts/detect-runtime.sh`. Read it verbatim. Do NOT re-detect; the manifest is authoritative.
- `iteration`: 0-based resolution iteration counter
- `previous_evidence_log_path`: path to evidence-log from previous iteration (only present when `iteration > 0`)

## Hard Rules

1. **You CANNOT write or edit project files.** `Write` / `Edit` / `MultiEdit` / `NotebookEdit` are disallowed. If a fixable problem requires creating a file (e.g., `cp .env.example .env`), emit `NEEDS_RESOLUTION` and let the skill perform the file operation after user approval.
2. **You MUST attempt every item in `manifest.runnable_surfaces` and `manifest.plan_features`.** Skipping an item without attempting it makes the SKIP verdict invalid (the skill will reject it and emit FAIL).
3. **You MUST write the evidence-log to `manifest.attempted_log_path`** using `Bash` (`cat > "$path" <<EOF ... EOF`), not the Write tool. The log file lives under `.claude/quality-gates/<sid>/` which is a per-session scratch area, not project source.
4. **Do not request secret values.** If a missing secret blocks an attempt, the `needed` field of NEEDS_RESOLUTION must describe the *decision* the user has to make (e.g., "set DB_URL in .env on disk and choose retry") — never ask for the secret value to be typed in.

## Step 1: Parse Manifest

Read the inline YAML manifest from your prompt. Extract:

- `project_type`
- `runnable_surfaces` (list of `{kind, ...}` items)
- `test_runners`
- `mcp_browser` (`chrome-devtools` | `playwright` | `none`)
- `app_url_candidates`
- `env_status`
- `plan_features`
- `attempted_log_path`

If a previous-iteration evidence-log path is provided, Read it first; do not duplicate work for surfaces already marked attempted=ok.

## Step 2: Attempt Each Surface

For each item in `runnable_surfaces`:

| kind | Action |
|---|---|
| `docker-compose` | `docker compose up -d` (skill confirmed). Then health-probe each `app_url_candidates` URL via `curl -s -o /dev/null -w "%{http_code}"`. |
| `npm-script` (`dev`/`start`/`serve`) | Bash with `run_in_background: true`, then probe URL. |
| `npm-script` (`test`) | `npm test`, capture exit code. |
| `pytest` | `pytest`, capture exit code. |
| `cargo-test` / `cargo-run` / `go-test` / `go-run` / `makefile` | Run the declared `command`; capture stdout/stderr/exit code. |

For each `app_url_candidates` URL that responds 2xx:

- Use the MCP browser tool (per `manifest.mcp_browser`):
  - Navigate to URL
  - Capture console messages
  - Take screenshot to `.claude/quality-gates/<sid>/screenshots/<surface>.png`
  - Take a11y snapshot

For each item in `plan_features`:

- If it looks like a route (`/...`), navigate to `<base_url><route>` and capture screenshot + a11y snapshot.
- Otherwise grep the a11y snapshot text for the feature label.

**Always stop background processes (`docker compose down`, kill node) when finished**, regardless of verdict.

## Step 3: Write Evidence-Log

Write the log to `manifest.attempted_log_path` using Bash heredoc. Format:

```markdown
# Gate 3 Evidence Log — iteration N

## Attempts
- kind: docker-compose | path: docker-compose.yml
  attempted: yes
  command: docker compose up -d
  outcome: failed | succeeded
  reason: "<short text>"
  resolvable: yes | no
- kind: npm-script | name: dev
  attempted: yes
  outcome: started
  url_probed: http://localhost:3000
  console_errors: 0
  screenshot: .claude/quality-gates/<sid>/screenshots/dev.png
- kind: pytest
  attempted: yes
  outcome: 14 passed, 0 failed
- kind: chrome-devtools-mcp
  attempted: yes
  navigated_to: http://localhost:3000/auth
  a11y_snapshot_summary: "login form present"
- kind: plan-feature | feature: /auth
  attempted: yes
  outcome: passed
```

Every `runnable_surface` and `plan_feature` from the manifest MUST have a corresponding `- kind: ...` block. If you genuinely could not attempt one (e.g., `mcp_browser: none` — then `kind: chrome-devtools-mcp` is `attempted: no, reason: "MCP unavailable"`).

## Step 4: Emit Verdict

Choose exactly one verdict:

| Verdict | Condition |
|---|---|
| `PASS` | All `runnable_surfaces` either attempted=ok OR attempted=no with `mcp_browser: none` (legitimate skip). All `plan_features` attempted=passed. Zero fatal console errors. |
| `FAIL` | Any attempt outcome=failed AND `resolvable: no`. Or any plan_feature attempt=failed. |
| `SKIP_WITH_EVIDENCE` | Manifest had zero runnable_surfaces, zero test_runners, AND zero plan_features (degenerate case — the skill should have caught this in fast-path; report defensively if dispatched anyway). |
| `NEEDS_RESOLUTION` | At least one resolvable failure exists (`resolvable: yes`). Skill will surface options to the user. |

Output the verdict in this exact format at the end of your message:

```
## Runtime Verification Report (Gate 3, iter N)

**Manifest:** [summary of manifest items]
**Attempts:** [N total, M succeeded, K failed, L unattempted]
**Evidence Log:** [path]

### Verdict: [PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION]

[verdict-specific section below]
```

For `NEEDS_RESOLUTION` ONLY, append a structured `needed` block:

```yaml
needed:
  - kind: <docker-daemon | missing-env-var | port-conflict | ...>
    description: "<actionable, decision-form. Never request secret values.>"
    actions:
      - retry
      - skip_surface
      - abort
needed_hash: "<sha256 of sorted concatenated needed.kind values>"
```

Compute `needed_hash` deterministically (e.g., via `printf '%s\n' "${kinds[@]}" | sort | sha256sum | cut -d' ' -f1`) so the skill can detect non-convergence.

Then emit the signal tag (the skill ALSO emits a final `<qg-signal>` after parsing your report; you do NOT emit `<qg-signal>` directly — that is the skill's responsibility):

(no `<qg-signal>` from agent — leave that to the skill)

## Notes

- If `mcp_browser: none`, do not attempt any chrome-devtools / playwright actions; record those as `attempted: no, reason: "MCP unavailable"` in evidence-log. PASS is still possible if all other surfaces succeeded.
- For `requires_decision: true` surfaces, the skill has already obtained user confirmation before dispatching you — proceed with the attempt. If it still fails, that's a real failure (resolvable or not, your call).
- Be specific in the evidence-log. The skill validates that every manifest item has a corresponding entry; missing entries cause a SKIP_WITH_EVIDENCE→FAIL escalation.
```

- [ ] **Step 4: Run frontmatter test to verify it passes**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/agents/runtime-verifier.md \
        plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh
git commit -m "feat(qg): runtime-verifier rewrite with manifest + 4 verdicts

Frontmatter에 allowedTools / disallowedTools 명시 (Plugin Shape
default-everything 위반 fix). Write/Edit/MultiEdit/NotebookEdit
disallowed → Law 2 물리적 분리. Body 재작성: skill이 inject한
manifest 입력, 각 runnable_surface attempt, evidence-log를 Bash로
작성, 4종 verdict 중 하나 emit. NEEDS_RESOLUTION에는
needed_hash (skill의 repeat detection용) 포함."
```

---

## Task 9: Add secret-leakage regression test

**Files:**
- Create: `plugins/quality-gates/tests/test_no_secret_prompts.py`

- [ ] **Step 1: Write the test**

`plugins/quality-gates/tests/test_no_secret_prompts.py`:

```python
"""Regression test for AC12 (P21 Secret 미노출).

Scans SKILL.md and stop-hook.py for AskUserQuestion-like prompts that could
solicit secret values. The contract: every user-facing option label must be
a *decision* (yes/no, retry/skip/abort) or *path*, never a free-form input
for a secret.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Files where AskUserQuestion options are defined or instructed.
TARGETS = [
    ROOT / "skills/quality-pipeline/SKILL.md",
    ROOT / "hooks/stop-hook.py",
    ROOT / "agents/runtime-verifier.md",
]

# Patterns that suggest secret-value extraction.
# These are heuristics: a free-text "input X" near a secret-like keyword is
# the smell we're guarding against. We accept these in option DESCRIPTIONS
# (e.g., "user has set DB_URL in .env") but flag any imperative
# "ask the user for <SECRET>" or "input the API_KEY" pattern.
SECRET_KEYWORDS = r"(API[_-]?KEY|TOKEN|PASSWORD|SECRET|CREDENTIAL|PRIVATE[_-]?KEY)"
LEAK_PATTERN = re.compile(
    rf"(ask|prompt|input|enter|provide|paste|type)\b[^\.\n]{{0,80}}\b{SECRET_KEYWORDS}\b",
    re.IGNORECASE,
)
# Whitelist: explicit text saying we DO NOT ask for secrets is fine.
NEGATION_HINT = re.compile(
    r"(never|don't|do not|cannot|must not)\b[^\.\n]{0,30}\b(ask|prompt|input)",
    re.IGNORECASE,
)


class TestNoSecretPrompts(unittest.TestCase):
    def test_no_imperative_secret_extraction(self):
        offenders = []
        for path in TARGETS:
            if not path.exists():
                continue
            text = path.read_text()
            for match in LEAK_PATTERN.finditer(text):
                start = max(0, match.start() - 100)
                ctx = text[start:match.end() + 50]
                if NEGATION_HINT.search(ctx):
                    continue  # Negated mention is fine
                offenders.append(f"{path.name}:{text[:match.start()].count(chr(10)) + 1}: "
                                 f"...{ctx[-150:]}...")
        self.assertEqual(offenders, [],
                         "Found prompts that may solicit secret values:\n"
                         + "\n".join(offenders))

    def test_runtime_verifier_disallows_secret_request(self):
        """runtime-verifier.md must explicitly state it does not request secret values."""
        path = ROOT / "agents/runtime-verifier.md"
        text = path.read_text()
        # Must contain explicit guard text.
        self.assertRegex(
            text,
            r"(do not request secret|never request secret|cannot request secret|"
            r"never ask.*secret|do not ask.*secret)",
            "runtime-verifier.md must explicitly forbid secret-value requests",
        )

    def test_stop_hook_gate3_resolution_prompt_only_offers_decisions(self):
        """The gate3_needs_resolution prompt must offer retry/skip/abort,
        not free-form value entry."""
        # This is a behavioral check via direct call.
        import importlib.util, sys
        hook_path = ROOT / "hooks/stop-hook.py"
        spec = importlib.util.spec_from_file_location("stop_hook", hook_path)
        stop_hook = importlib.util.module_from_spec(spec)
        sys.modules["stop_hook"] = stop_hook
        spec.loader.exec_module(stop_hook)

        state = {
            "current_gate": 3,
            "gate2_iteration": 5,
            "max_gate2_iterations": 5,
            "gate3_resolution_iter": 1,
            "max_gate3_resolutions": 3,
            "skip_runtime": False,
            "single_gate": None,
        }
        prompt = stop_hook.build_special_prompt(
            "gate3_needs_resolution", state, "context"
        )
        # Must offer the 3 standard decisions
        self.assertIn("retry", prompt.lower())
        self.assertIn("skip", prompt.lower())
        self.assertIn("abort", prompt.lower())
        # Must NOT instruct a free-form secret entry
        self.assertNotRegex(prompt, r"(?i)\benter (your|the) (api[_-]?key|token|password|secret)")
        self.assertNotRegex(prompt, r"(?i)\binput (your|the) (api[_-]?key|token|password|secret)")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test (current state)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_no_secret_prompts -v`

Expected: PASS — Task 8에서 작성한 runtime-verifier.md의 "Do not request secret values" 가드 문장과 Task 3의 prompt builder의 명시적 안내 덕분.

만약 FAIL이면, 메시지가 어떤 패턴을 잡는지 보고 (a) Task 3/8의 텍스트에 negation hint를 명시 추가 또는 (b) LEAK_PATTERN의 false-positive를 더 좁게 조정.

- [ ] **Step 3: Commit**

```bash
git add plugins/quality-gates/tests/test_no_secret_prompts.py
git commit -m "test(qg): regression for AC12 (P21 secret 미노출)

SKILL.md / stop-hook.py / runtime-verifier.md 에서 AskUserQuestion
경로의 imperative 'ask user for API_KEY' 패턴을 탐지. Negation
('never ask for secret') 패턴은 허용. gate3_needs_resolution
prompt가 retry/skip/abort 결정만 제공하고 free-form secret 입력
지시가 없는지 직접 검증."
```

---

## Task 10: Update `SKILL.md` Gate 3 — pre-flight + AskUserQuestion + fast-path SKIP

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (Gate 3 섹션 — 현재 line 782-811 근처)

- [ ] **Step 1: Locate current Gate 3 section**

Run: `grep -n "### Gate 3" /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/skills/quality-pipeline/SKILL.md`

Expected: Line 782 부근 (`### Gate 3: Runtime Verification`).

- [ ] **Step 2: Replace the Gate 3 section**

`plugins/quality-gates/skills/quality-pipeline/SKILL.md` 의 `### Gate 3: Runtime Verification` 섹션을 다음으로 교체 (현재 섹션의 끝은 `## Special Prompts from Stop Hook` 직전):

````markdown
### Gate 3: Runtime Verification

Gate 3 enforces an **evidence-required** verification model: the agent must
attempt every runnable surface declared in the pre-flight manifest, and any
SKIP must be backed by attempted-but-failed log entries. The skill mediates a
**3-way ping-pong** between itself (mother), the human, and the runtime-verifier
(reviewer): the skill detects infrastructure, asks the user up-front for
required *decisions* (never secret values), dispatches the agent with a
deterministic manifest, validates the resulting evidence-log, and re-dispatches
the agent up to `max_gate3_resolutions` times if the agent emits
`NEEDS_RESOLUTION`.

#### Step 0: Pre-flight detection

Run the deterministic detector once per Gate 3 invocation:

```bash
PLAN_PATH="<plan_file>" "${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh"
```

Parse the YAML output into a `manifest` dict in your context. **Fail-open**:
if the detector errors or output is unparseable, proceed with an empty
manifest (`runnable_surfaces: []`, `plan_features: []`) — the agent will
then return `SKIP_WITH_EVIDENCE` defensively, which is correct for the
"no detectable runtime infrastructure" case.

#### Step 1: Fast-path SKIP (no agent dispatch)

If ALL of the following hold:

- `manifest.runnable_surfaces == []`
- `manifest.test_runners == []`
- `manifest.plan_features == []`

then there is genuinely nothing to verify. Emit immediately, without
dispatching the runtime-verifier agent (token-cost = 0):

1. Use Bash to write `<attempted_log_path>` with content:
   ```markdown
   # Gate 3 Evidence Log — fast-path skip
   No runnable surfaces, test runners, or plan features detected.
   Detector output saved at <session_dir>/manifest.yaml.
   ```
2. Output to user:
   ```
   ## Gate 3: Runtime Verification — SKIP_WITH_EVIDENCE
   No runnable surfaces detected (markdown-only / library without tests / etc.).
   Evidence log: <path>
   ```
3. Emit signal:
   ```xml
   <qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="no runnable surfaces detected" files_changed="" />
   ```

Do NOT proceed to Step 2 in this case.

#### Step 2: Upfront resolution (AskUserQuestion, decisions only)

Build a list of `requires_decision` items from the manifest:

- Every `runnable_surface` with `requires_decision: true` (currently only
  `docker-compose`).
- Every `env_status` entry with `exists: false, has_example: true` — propose
  to copy `.env.example` to `.env`.

If the list is non-empty, invoke `AskUserQuestion` ONCE with up to 4 questions
(per the tool's hard cap). For each:

| Manifest item | Question label | Options |
|---|---|---|
| `docker-compose: requires_decision` | "Bring up `docker compose`?" | `yes` / `skip-this-surface` |
| `env_status: has_example, !exists` | "Copy `.env.example` → `.env`?" | `yes` / `manual-set-then-retry` / `skip` |

**Hard rules:**
- The option labels MUST be decisions (yes/no, retry/skip/abort) or paths.
  NEVER ask for a secret value (API_KEY, DB_URL, password) as free text.
- If more than 4 decisions exist, batch the most blocking 3 and let the agent's
  NEEDS_RESOLUTION loop handle the rest mid-run.

Apply the user's answers via the skill's Bash tool (the agent has
`Write/Edit` disallowed):

- "Copy `.env.example` → `.env`: yes" → `cp .env.example .env`
- "Bring up docker compose: yes" → `docker compose up -d` (capture exit code)

Update the manifest in your context with `applied_decisions` so the agent
knows what was already done. If `docker compose up -d` itself fails (daemon
down), record this as a pre-emptive resolvable failure: build a synthetic
`needed` block, jump to Step 4 (NEEDS_RESOLUTION handling) without
dispatching the agent yet.

#### Step 3: Dispatch the runtime-verifier agent

Build the dispatch prompt:

```
Agent(
  subagent_type="quality-gates:runtime-verifier",
  prompt="""Verify application runtime behavior using the manifest below.

  project_dir: <cwd>
  plan_path: <plan_path>
  iteration: <gate3_resolution_iter>
  previous_evidence_log_path: <path or 'none'>

  ## Manifest (verbatim from detect-runtime.sh)
  <YAML manifest>

  ## Applied decisions (from upfront AskUserQuestion)
  <YAML list of {decision, action, outcome}>
  """
)
```

Wait for the agent's structured response. Parse:

- `Verdict:` line (`PASS` / `FAIL` / `SKIP_WITH_EVIDENCE` / `NEEDS_RESOLUTION`)
- `Evidence Log:` path
- For `NEEDS_RESOLUTION`: the `needed:` YAML block + `needed_hash:` line

#### Step 4: Validate evidence-log (PASS / FAIL / SKIP_WITH_EVIDENCE)

For PASS or SKIP_WITH_EVIDENCE verdicts, validate the evidence-log:

1. Read the file at `manifest.attempted_log_path`.
2. Build the expected set: every `runnable_surface.kind+name` plus every
   `plan_feature` plus a synthetic `chrome-devtools-mcp` entry if
   `manifest.mcp_browser != none`.
3. For each expected item, grep for a matching `- kind: ...` block in the
   evidence-log.
4. If any expected item is missing, **reject the verdict**:
   - Output to user: "Evidence-log incomplete: M out of N items unattempted: [list]"
   - Emit `<qg-signal gate="3" verdict="FAIL" summary="incomplete evidence: <count> unattempted" files_changed="" />`
5. If all items present, accept the verdict and emit accordingly:
   - PASS → `<qg-signal gate="3" verdict="PASS" summary="all surfaces verified" files_changed="" />`
   - SKIP_WITH_EVIDENCE → `<qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="<short>" files_changed="" />`

#### Step 5: NEEDS_RESOLUTION handling (mid-run escalation)

If verdict is `NEEDS_RESOLUTION`:

1. Parse the `needed:` block.
2. Compute `needed_hash` (use the agent's, or compute from `kind` values).
3. Emit signal:
   ```xml
   <qg-signal gate="3" verdict="NEEDS_RESOLUTION" needed_hash="<hash>"
              summary="<one-line>" files_changed="" />
   ```
4. The Stop hook converts this into a `gate3_needs_resolution` continuation
   prompt — that prompt directs you (next turn) to invoke `AskUserQuestion`
   with the agent's `needed` items rendered as **retry / skip-surface / abort**
   options (NEVER as free-text inputs).
5. On retry: re-dispatch the agent with `iteration += 1` and the previous
   evidence-log path so it can resume from where it left off.

#### Step 6: FAIL handling

If verdict is `FAIL` (or `NEEDS_RESTART`), emit:

```xml
<qg-signal gate="3" verdict="FAIL" summary="<one-line>" files_changed="<list or empty>" />
```

The Stop hook routes to `gate3_fail` (existing behavior).

#### Output to user (always)

After every Gate 3 turn, output to the user:

```
## Gate 3: Runtime Verification — [VERDICT]
**Manifest:** [N runnable surfaces, M plan features, mcp=<browser>]
**Evidence:** [path]
**Verdict explanation:** [from agent's report or fast-path text]
```

#### Gate 3 rules

- The detector is read-only — never invoke it with arguments that could
  cause file creation. The detector script already enforces this.
- The agent has `Write`/`Edit` disallowed. If the verdict report from the
  agent claims to have edited a file, treat that as a contract violation
  and emit FAIL with a note.
- Skill-side file ops (`cp`, `docker compose up`) MUST happen via Bash with
  the user's prior consent recorded as an applied_decision.
- NEVER ask the user for a secret value. The only valid resolutions for a
  missing secret are: (a) user sets it on disk and retries, (b) skip the
  affected surface, (c) abort.
- If `DEVBREW_GATE3_MAX_RESOLUTIONS=0`, the Stop hook will escalate the
  first NEEDS_RESOLUTION directly to `gate3_fail` — proceed with FAIL
  handling (Step 6) when the continuation prompt arrives.
- `iteration` parameter increments only on explicit gate3_needs_resolution
  continuations; the Stop hook manages this via update_state_file. Do not
  manually maintain the counter.
````

(`#### Special Prompts from Stop Hook` 섹션은 그대로 유지하되 다음 task에서 신규 prompt 키 두 개 추가.)

- [ ] **Step 3: Add Gate 3 special-prompt handling**

`SKILL.md` 의 `## Special Prompts from Stop Hook` 섹션 (`### GATE3_FAIL` 직후)에 추가:

````markdown
### GATE3_NEEDS_RESOLUTION

Gate 3 reviewer reported a resolvable missing resource. Read the previous
turn's `needed:` YAML block and present user options via AskUserQuestion.

For each `needed[i]`:
- Question: `needed[i].description`
- Options: `retry` / `skip-this-surface` / `abort` (decisions only — never
  ask for secret values)

Based on user choice:
- All retries → re-dispatch runtime-verifier per Step 5 above. Then emit a
  fresh `<qg-signal gate="3" verdict="..." />` based on the new agent verdict.
- Any skip-this-surface → record in evidence-log, mark surface as
  user-skipped, emit
  `<qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" summary="user opted to skip <surface>" files_changed="" />`
- Any abort →
  `<qg-signal action="abort" reason="User aborted during gate3_needs_resolution" />`

### GATE3_REPEAT_DETECTED

Same `needed_hash` appeared twice — the resolution loop is not converging.
Present the user with proceed-with-warnings vs abort:

- Proceed → `<qg-signal gate="3" verdict="PASS_WITH_WARNINGS" summary="repeat detected; user accepted" files_changed="" />`
- Abort → `<qg-signal action="abort" reason="User aborted on repeat detection" />`
````

- [ ] **Step 4: Run secret-leakage test (regression)**

Run: `cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && python3 -m unittest tests.test_no_secret_prompts -v`

Expected: PASS (the new SKILL.md prose follows the decision-only contract; `LEAK_PATTERN` should not match given the explicit "NEVER ask for a secret value" hints).

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "feat(qg): SKILL.md Gate 3 rewrite — manifest-driven verification

Gate 3 섹션을 6 단계로 재작성: pre-flight detector dispatch,
fast-path SKIP_WITH_EVIDENCE (sub-agent dispatch 없이 manifest
가 비어 있으면 즉시 종료), upfront AskUserQuestion (decisions
only, secret 값 금지), agent dispatch with manifest, evidence-log
완결성 검증, NEEDS_RESOLUTION 루프. GATE3_NEEDS_RESOLUTION /
GATE3_REPEAT_DETECTED special prompts 추가."
```

---

## Task 11: Add e2e scenarios + README + CHANGELOG + version bump

**Files:**
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md`
- Modify: `plugins/quality-gates/README.md`
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: Append scenarios to e2e-scenarios.md**

`plugins/quality-gates/tests/e2e-scenarios.md` 끝에 추가:

````markdown
## Gate 3 Active Verification Scenarios (v1.8.0)

### Scenario G3-A: Web app, docker-compose, .env all present

**Setup:** project root has `docker-compose.yml`, `package.json` with `dev`
script, `.env`, and a plan referencing `/auth`. chrome-devtools MCP is
configured.

**Run:** `/qg --gate3`

**Expected:**
- Detector emits manifest with: docker-compose, npm:dev, npm:test,
  pytest (if applicable), `mcp_browser: chrome-devtools`,
  `plan_features: [/auth]`, `env_status: [{file: .env, exists: true}]`.
- Skill asks: "Bring up docker compose? (yes/skip-this-surface)" → user yes.
- Skill: `docker compose up -d` succeeds.
- Agent dispatched with manifest. Attempts each surface, captures screenshots
  + a11y snapshots, writes evidence-log.
- Verdict: PASS.
- `<qg-signal gate="3" verdict="PASS" .../>` → pipeline complete.

### Scenario G3-B: Web app, .env missing but .env.example present

**Setup:** same as G3-A but `.env` does not exist; `.env.example` does.

**Run:** `/qg --gate3`

**Expected:**
- Detector flags `env_status: [{file: .env, exists: false, has_example: true}]`.
- Skill asks: "Copy .env.example → .env? (yes/manual-set/skip)" → user yes.
- Skill: `cp .env.example .env`.
- Agent proceeds; verdict depends on whether the example values are valid for
  startup. If app boots: PASS. If app fails on bad credentials: NEEDS_RESOLUTION
  with `needed: [{kind: missing-env-var, description: "DB_URL invalid; set
  real value in .env and retry"}]`.
- On NEEDS_RESOLUTION: skill asks retry/skip/abort. User edits .env, picks
  retry → agent re-dispatched (iter=1) → PASS.

### Scenario G3-C: Docker daemon down (mid-run escalation)

**Setup:** `docker-compose.yml` exists, but Docker is not running.

**Run:** `/qg --gate3`

**Expected:**
- Skill: `docker compose up -d` fails ("Cannot connect to Docker daemon").
- Skill jumps to Step 4 (NEEDS_RESOLUTION handling) WITHOUT agent dispatch.
- Skill asks: "Docker daemon down. Start it and retry? (retry/skip-surface/abort)"
- If retry: skill re-attempts `docker compose up -d`. If now succeeds → continue
  to Step 3 agent dispatch.
- If skip-surface: agent dispatched with manifest, but compose surface marked
  `pre-skipped` in applied_decisions. Agent attempts npm:dev only.
- After 3 retries with same `needed_hash`: `gate3_repeat_detected` →
  proceed/abort.

### Scenario G3-D: Markdown-only repo (fast-path SKIP)

**Setup:** repo has only `.md` files. No package.json, no docker-compose,
no test infra.

**Run:** `/qg --gate3`

**Expected:**
- Detector emits manifest with empty runnable_surfaces / test_runners /
  plan_features.
- Skill: fast-path SKIP_WITH_EVIDENCE. **Sub-agent NOT dispatched.**
- Evidence log written: "no runnable surfaces detected".
- `<qg-signal gate="3" verdict="SKIP_WITH_EVIDENCE" .../>`.
- Token cost for Gate 3: detector + minimal skill overhead. No agent tokens.

### Verification

To run these scenarios manually:
1. `cd plugins/quality-gates/tests/fixtures/gate3/<scenario-dir>`
2. `CLAUDE_CODE_SESSION_ID=test_$(date +%s) /qg --gate3`
3. Observe expected behavior; check evidence-log under `.claude/quality-gates/<sid>/`.

The fixtures cover G3-A (web-compose), G3-B (web-example-only), and G3-D
(markdown-only) directly. G3-C requires Docker on the host machine and is
a manual test only.
````

- [ ] **Step 2: Update README "Principles Instantiated"**

Find the "Principles Instantiated" section in `plugins/quality-gates/README.md` and append the following bullets (place them before any closing block):

```markdown
- **Law 1 (Verification Plan section).** Gate 3 enforces an evidence-required
  SKIP — the runtime-verifier must attempt every manifest surface and produce
  an evidence-log; SKIP without evidence is rejected by the skill and
  escalated to FAIL. (v1.8.0)
- **Law 2 (writer/reviewer separation, physical via tool scoping).**
  `runtime-verifier` agent declares `disallowedTools: [Write, Edit, MultiEdit,
  NotebookEdit]`. Fixable file operations (e.g., `cp .env.example .env`,
  `docker compose up`) are performed by the skill's Bash tool only after
  the user has explicitly chosen them via AskUserQuestion. (v1.8.0)
- **AP15 (unbounded autonomy).** Gate 3's NEEDS_RESOLUTION mid-run loop is
  bounded by `max_gate3_resolutions` (default 3, env override
  `DEVBREW_GATE3_MAX_RESOLUTIONS=0..10`). Repeat detection on `needed_hash`
  catches non-converging loops earlier than the iteration cap. (v1.8.0)
- **P21 (no secret in prompt context).** AskUserQuestion in Gate 3 asks
  decisions and pointers (yes/no/path) — never secret values. Missing
  secrets are resolved by the user setting them in `.env` on disk and
  choosing retry. Regression test: `tests/test_no_secret_prompts.py`. (v1.8.0)
```

- [ ] **Step 3: Add CHANGELOG entry**

Insert at the top of `plugins/quality-gates/CHANGELOG.md` (after the header, before `## [1.7.0]`):

```markdown
## [1.8.0] — 2026-05-10

### Added
- **Pre-flight runtime detector** (`scripts/detect-runtime.sh`): deterministic
  bash script that produces a YAML manifest of project_type, runnable_surfaces
  (docker-compose / npm-script / pytest / cargo / go / makefile), test_runners,
  mcp_browser (chrome-devtools / playwright / none), app_url_candidates,
  env_status, and plan_features (extracted from PLAN_PATH). Read-only.
- **Fast-path SKIP_WITH_EVIDENCE**: when detector reports zero runnable
  surfaces, zero test_runners, and zero plan_features, Gate 3 emits
  SKIP_WITH_EVIDENCE without dispatching the agent (token cost = 0).
- **Mid-run NEEDS_RESOLUTION escalation**: agent can request human resolution
  for fixable missing resources. Skill mediates 3-way ping-pong (skill ↔ user ↔
  agent) via AskUserQuestion. Bounded by `max_gate3_resolutions` (default 3).
- **`DEVBREW_GATE3_MAX_RESOLUTIONS` env override** (clamped 0..10). Setting
  to `0` disables mid-run escalation (Approach 2 mode — first NEEDS_RESOLUTION
  directly fails Gate 3).
- **Repeat detection** on `needed_hash`: same missing resources twice in a row
  trigger `gate3_repeat_detected` → user choice (proceed_with_warnings / abort).
- **Evidence-log validation** by skill: every manifest item must have an
  attempted entry; missing entries auto-escalate SKIP_WITH_EVIDENCE → FAIL.
- **Fixture-based tests**: 4 fixtures (web-compose / web-example-only /
  library-tests / markdown-only), 7 detector tests in
  `tests/test_detect_runtime.sh`, 6 new state-machine tests, 1 frontmatter
  lint test, 1 secret-leakage regression test (AC12 / P21).

### Changed
- **`runtime-verifier.md` rewrite (v2)**:
  - Frontmatter declares `allowedTools: [Read, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_*]`
    and `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` — fixes
    CLAUDE.md Plugin Shape "default-everything 금지" violation.
  - `cost_class: variable` (was `low` — iteration loop possible).
  - Body: manifest-driven attempts, evidence-log obligation, 4-verdict
    taxonomy (PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION), explicit
    P21 guard against requesting secret values.
- **SKILL.md Gate 3 section** rewritten to 6 steps (detect → fast-path →
  upfront resolution → dispatch → evidence validation → NEEDS_RESOLUTION).
- **stop-hook.py**: new transitions `gate3_needs_resolution` and
  `gate3_repeat_detected`, new state fields `gate3_resolution_iter` and
  `max_gate3_resolutions`, `last_gate3_needed_hash`. Existing `SKIP` verdict
  still routes to `complete` (back-compat); `SKIP_WITH_EVIDENCE` and
  `PASS_WITH_WARNINGS` join the same complete-bucket.

### Fixed
- **Silent SKIP regressions in Gate 3**: previously, project type detection
  fall-through (no `package.json scripts.dev`, no `manage.py`) would silently
  return `unknown` → SKIP without user notification. Now, evidence-required
  SKIP rejects this path; the skill either fast-path SKIPs (with an evidence
  log), or escalates incomplete attempts to FAIL.
- **chrome-devtools MCP under-utilization**: agent previously had to discover
  available browser MCP tools via runtime keyword search. Detector now
  injects `mcp_browser: chrome-devtools | playwright | none` into the manifest
  deterministically.
```

- [ ] **Step 4: Bump plugin.json version**

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `"version": "1.7.0"` 를 `"version": "1.8.0"` 으로 변경.

- [ ] **Step 5: Run all plugin tests**

Run all the plugin's tests as a final sanity check:

```bash
cd /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates && \
bash tests/test_setup_qg.sh && \
bash tests/test_discover_plan.sh && \
bash tests/test_detect_runtime.sh && \
bash tests/test_runtime_verifier_frontmatter.sh && \
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Expected: 모두 PASS. 어떤 부분이 fail하면 위 task의 해당 step으로 돌아가서 fix.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/tests/e2e-scenarios.md \
        plugins/quality-gates/README.md \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/.claude-plugin/plugin.json
git commit -m "docs(qg): e2e scenarios, README principles, changelog, version bump

v1.7.0 → v1.8.0 (minor: 새 surface — detect-runtime.sh +
manifest-driven Gate 3). e2e-scenarios.md에 4가지 시나리오
(G3-A/B/C/D). README \"Principles Instantiated\"에 Law 1
verification plan 강화 / Law 2 물리 분리 / AP15 가드 / P21
secret 미노출 4개 인스턴스 추가."
```

---

## Task 12: Open PR

**Files:** none (git operations only)

- [ ] **Step 1: Push branch**

```bash
git push -u origin feature/gate3-active-verification
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "feat(qg): Gate 3 active runtime verification (v1.8.0)" --body "$(cat <<'EOF'
## Summary

- silent SKIP 회피: deterministic pre-flight detector + evidence-required SKIP + mid-run NEEDS_RESOLUTION 3-way ping-pong (skill ↔ user ↔ agent)
- Law 2 물리 분리 강화: `runtime-verifier`에 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 명시 (Plugin Shape default-everything 위반 fix)
- AP15 가드: `max_gate3_resolutions` (default 3, env override `DEVBREW_GATE3_MAX_RESOLUTIONS=0..10`) + repeat detection on `needed_hash`
- P21 준수: AskUserQuestion은 결정/포인터만, secret 값 받기 금지 — regression test로 보호
- Fast-path SKIP_WITH_EVIDENCE: markdown-only / library-without-tests repo는 sub-agent dispatch 없이 즉시 종료 (토큰 0)

Spec: `docs/superpowers/specs/2026-05-10-gate3-active-verification-design.md`
Plan: `docs/superpowers/plans/2026-05-10-gate3-active-verification.md`

## Test plan

- [ ] `bash plugins/quality-gates/tests/test_setup_qg.sh` 통과
- [ ] `bash plugins/quality-gates/tests/test_detect_runtime.sh` 7 케이스 통과
- [ ] `bash plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh` 통과
- [ ] `python3 -m unittest discover plugins/quality-gates/tests/` 통과 (state-machine + secret-leakage)
- [ ] e2e G3-D (markdown-only) 수동: `/qg --gate3` → SKIP_WITH_EVIDENCE without sub-agent dispatch
- [ ] e2e G3-A (web-compose) 수동: docker compose up + 모든 surface attempted → PASS
- [ ] `DEVBREW_GATE3_MAX_RESOLUTIONS=0` 환경: 첫 NEEDS_RESOLUTION이 즉시 FAIL로 격상되는지
EOF
)"
```

Run the result; PR URL will be printed.

- [ ] **Step 3: Verify PR opened correctly**

Run: `gh pr view --web` 또는 출력된 URL 방문.

Expected: PR이 main을 base로, feature/gate3-active-verification을 head로 열림. 본문에 spec/plan 링크와 test plan checklist 표시.

---

## Self-Review

### Spec coverage cross-check

| Spec AC | Plan task |
|---|---|
| AC1 (web+compose+env happy path) | Task 6 fixture + Task 11 e2e scenario G3-A |
| AC2 (.env.example upfront resolution) | Task 7 env_status + Task 10 SKILL Step 2 + e2e G3-B |
| AC3 (docker daemon down mid-run) | Task 10 SKILL Step 5 + e2e G3-C |
| AC4 (markdown-only fast-path) | Task 5 fixture + Task 10 SKILL Step 1 + e2e G3-D |
| AC5 (incomplete evidence → FAIL) | Task 10 SKILL Step 4 |
| AC6 (chrome-devtools MCP auto) | Task 7 mcp_browser detection + Task 8 runtime-verifier Step 2 |
| AC7 (plan-driven feature verification) | Task 7 plan_features + Task 8 runtime-verifier Step 2 |
| AC8 (max resolution cap) | Task 2 transition + e2e G3-C |
| AC9 (repeat detection) | Task 4 |
| AC10 (Plugin Shape compliance) | Task 8 frontmatter + lint test |
| AC11 (DEVBREW_GATE3_MAX_RESOLUTIONS=0) | Task 1 env override + Task 2 test |
| AC12 (secret never in prompts) | Task 9 regression test |
| AC13 (detector unit test 4 fixtures) | Tasks 5–7 |
| AC14 (state-machine test) | Tasks 1–4 |
| AC15 (back-compat) | Task 2 (legacy SKIP still completes) + Task 11 changelog "still routes to complete" |

All 15 ACs covered.

### Placeholder scan

Searched for "TBD", "TODO", "implement later", "Add appropriate", "similar to" — none in this plan. Concrete code in every step.

### Type / signature consistency

- `gate3_resolution_iter` and `max_gate3_resolutions` field names used identically across setup-qg.sh, stop-hook.py, and tests.
- `NEEDS_RESOLUTION` (not `NEEDS-RESOLUTION` or `NEED_RESOLUTION`) used consistently.
- `SKIP_WITH_EVIDENCE` (uppercase, underscore-separated) consistent across stop-hook, runtime-verifier, SKILL.md, tests.
- `gate3_needs_resolution` (lowercase, underscored) is the transition_type / prompt_key — not capitalized.
- `needed_hash` snake_case in agent output, signal attribute, state field.
- `applied_decisions` consistent in SKILL.md.

### Final notes

- Tasks 1–4 are sequential (each depends on previous state-machine state).
- Tasks 5–7 build the detector progressively (skeleton → surfaces → metadata).
- Tasks 8 and 9 can be parallelized after Task 4.
- Tasks 10 and 11 should run after Tasks 1–9 complete since Task 10 references the prompt builders (Task 3) and SKILL.md prose interacts with the secret-leakage regression test (Task 9).
- Task 12 (PR) runs last.
