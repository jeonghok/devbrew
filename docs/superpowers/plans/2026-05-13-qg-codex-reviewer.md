# QG Codex Reviewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Codex CLI가 감지되면 QG Gate 2 Phase 1에 독립 reviewer로 자동 dispatch하도록 `plugins/quality-gates`를 확장한다 (Law 2 강화: model-family + OS-process 분리).

**Architecture:** (1) `scripts/detect_codex.sh` probe가 6 case YAML manifest emit → (2) `agents/scout.md`가 manifest를 받아 `codex-reviewer`를 phase1_agents에 추가 → (3) `agents/codex-reviewer.md`가 `codex exec --json -s read-only` 호출 → (4) `scripts/codex_findings_to_yaml.py`가 JSONL stream을 표준 finding YAML로 정규화. 3 layer 격리: agent disallowedTools + narrow Bash allowlist + codex OS sandbox.

**Tech Stack:** Bash 3.2+ (probe + agent body), Python 3.8+ (JSONL parser), Codex CLI (optional runtime dependency), gtimeout/timeout (wall-clock guard).

**Spec reference:** `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` v3.1 (3 rounds adversarial review, 29 issues addressed). 모든 design decision은 spec §X.Y로 cross-reference 가능 — plan은 implementation step만 다룸.

**Naming convention note:** Spec에서 hyphen-style (`detect-codex.sh`)로 표기했으나 기존 `plugins/quality-gates/tests/`는 underscore (`test_<name>.sh`) 규칙. **Plan에서는 underscore로 정규화** — `detect-codex.sh` → `detect_codex.sh`, `test-detect-codex.sh` → `test_detect_codex.sh`. Spec과 plan 사이 차이는 의도적 (local convention 우선).

---

## File Structure

### New files (plugins/quality-gates/)

- `scripts/detect_codex.sh` — 6-case probe (AC1)
- `scripts/codex_findings_to_yaml.py` — JSONL parser, 3-stage fallback (AC3)
- `agents/codex-reviewer.md` — Reviewer agent (AC4, AC9, AC11)
- `tests/test_detect_codex.sh` — AC1
- `tests/test_findings_parser.sh` — AC3
- `tests/test_sandbox_enforced.sh` — AC4
- `tests/test_failure_injection.sh` — AC5
- `tests/test_scout_codex_integration.sh` — AC2
- `tests/test_cost_consent.sh` — AC10
- `tests/test_codex_backward_compat.sh` — AC7
- `tests/lib/extract_codex_invocations.py` — AC4 multi-line aware helper
- `tests/mocks/mock-codex-exit1.sh` — AC5 case 1
- `tests/mocks/mock-codex-hang.sh` — AC5 case 2 (sleep 700)
- `tests/mocks/mock-codex-bad-json.sh` — AC5 case 3
- `tests/mocks/mock-codex-no-agent-message.sh` — AC5 case 4
- `tests/mocks/mock-codex-valid-json-no-fence.sh` — AC5 case 5
- `tests/mocks/mock-codex-auth-stderr.sh` — AC5 case 6
- `tests/mocks/safe-v1/codex` — AC1 case 2 (safe version)
- `tests/mocks/bad-version/codex` — AC1 case 6 (0.120.1)
- `tests/spike/test_codex_json_extraction.sh` — Task 0 BLOCKING gate
- `tests/spike/spike_prompt.md` — spike payload
- `tests/spike/fixtures/codex_jsonl_sample.json` — frozen schema (OQ-3)
- `tests/fixtures/baseline_synthesizer_{small,medium,large}.yaml` — AC7 baselines

### Modified files

- `plugins/quality-gates/.claude-plugin/plugin.json` — version `1.10.0 → 1.11.0`
- `plugins/quality-gates/CHANGELOG.md` — `## [1.11.0] — 2026-05-13` section
- `plugins/quality-gates/README.md` — 3 spots
- `plugins/quality-gates/agents/scout.md` — 3 hunks
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Phase 0 probe call + Scout input synthesis

### Responsibility boundaries

- `detect_codex.sh`: 환경 probe만. Codex 호출 안 함. Output: YAML to stdout.
- `codex_findings_to_yaml.py`: stdin → stdout. 파일 I/O 안 함.
- `codex-reviewer.md` body: §4.3 canonical invocation 한 번. Parser pipe + meta emit.
- `scout.md`: Manifest 받아서 dispatch list 결정.
- `quality-pipeline/SKILL.md`: Probe call + Scout input synthesis.

---

## Task 0: Prompt-engineering spike (BLOCKING gate)

**Why first:** §9 Step 0 of spec — Codex가 fenced JSON code block을 안정적으로 emit하는지 empirically 검증. 실패 시 Task 4 진행 금지.

**Prerequisites:**
- Codex CLI 설치됨
- 인증됨 (`$CODEX_API_KEY` / `$OPENAI_API_KEY` / `~/.codex/auth.json` 중 하나)
- 버전이 known-bad (`0.120.0`, `0.120.1`, `0.120.2`) 아님

If any prereq fails, ASK user before proceeding (do not assume).

**Files:**
- Create: `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh`
- Create: `plugins/quality-gates/tests/spike/spike_prompt.md`
- Create: `plugins/quality-gates/tests/spike/fixtures/codex_jsonl_sample.json` (captured)

### Steps

- [ ] **0.1: Verify prerequisites manually**

Run:
```bash
command -v codex && codex --version
echo "CODEX_API_KEY set: ${CODEX_API_KEY:+yes}"
echo "OPENAI_API_KEY set: ${OPENAI_API_KEY:+yes}"
test -f ~/.codex/auth.json && echo "auth.json present"
```

Expected: codex path printed, version printed (not `0.120.0/1/2`), at least one auth source confirmed.

If any check fails, STOP. Document the failure and request user intervention.

- [ ] **0.2: Create spike prompt**

Create `plugins/quality-gates/tests/spike/spike_prompt.md` with a benign diff. Use a missing-bounds-check pattern (not security-sensitive content):

```markdown
You are a code reviewer. Review the following synthetic diff for any issues.

<diff>
--- a/example.py
+++ b/example.py
@@ -1,5 +1,8 @@
 def divide(a, b):
-    return a / b
+    if b == 0:
+        return None
+    return a / b

+def lookup(items, idx):
+    return items[idx]
</diff>

Output your findings in this exact format (fenced JSON code block):
[BACKTICKS_JSON]
{
  "findings": [
    {
      "file": "example.py",
      "line": 8,
      "severity": "IMPORTANT",
      "confidence": 8,
      "summary": "lookup() does not validate idx is within range.",
      "proposed_fix": "Add bounds check or catch IndexError."
    }
  ]
}
[BACKTICKS_END]

The JSON code block is REQUIRED. Wrap your findings array in [BACKTICKS_JSON] ... [BACKTICKS_END] exactly as shown.
```

(Replace `[BACKTICKS_JSON]` with three real backticks + `json`, and `[BACKTICKS_END]` with three real backticks, when writing the file.)

- [ ] **0.3: Create spike test script**

Create `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh`:

```bash
#!/usr/bin/env bash
# Spike: verify codex emits fenced JSON >=2/3 times.
# Run from plugins/quality-gates directory.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
PROMPT_FILE="$SCRIPT_DIR/spike_prompt.md"
OUT_DIR="$(mktemp -d -t qg-codex-spike-XXXXXX)"
trap 'rm -rf "$OUT_DIR"' EXIT

[[ -f "$PROMPT_FILE" ]] || { echo "Missing $PROMPT_FILE" >&2; exit 1; }

PROMPT="$(cat "$PROMPT_FILE")"
TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"
[[ -n "$TIMEOUT_CMD" ]] || { echo "Need gtimeout or timeout" >&2; exit 1; }

pass=0
total=3
for i in 1 2 3; do
  echo "--- Run $i/$total ---"
  STDOUT_FILE="$OUT_DIR/run-$i.jsonl"
  STDERR_FILE="$OUT_DIR/run-$i.stderr"

  "$TIMEOUT_CMD" 600 codex exec "$PROMPT" \
    -C "$REPO_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE"

  echo "  exit: $?"
  echo "  stdout lines: $(wc -l < "$STDOUT_FILE")"
  echo "  stderr preview: $(head -1 "$STDERR_FILE")"

  # Extract last agent_message text from JSONL stream via Python (json.loads only)
  last_msg="$(grep '"type":"agent_message"' "$STDOUT_FILE" | tail -1 \
              | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); print(d.get("text",d.get("message","")))' 2>/dev/null || echo "")"

  # Check for fenced JSON (three backticks + json)
  if echo "$last_msg" | grep -q '```json' && echo "$last_msg" | grep -q '```\s*$'; then
    echo "  fenced JSON detected"
    pass=$((pass + 1))
  else
    echo "  no fenced JSON"
    echo "  preview: $(echo "$last_msg" | head -c 200)"
  fi
done

echo ""
echo "Spike result: $pass/$total passed"
if [[ $pass -ge 2 ]]; then
  mkdir -p "$SCRIPT_DIR/fixtures"
  cp "$OUT_DIR/run-1.jsonl" "$SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  echo "Frozen sample to $SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  exit 0
else
  echo "FAIL: spike threshold not met. Halt before Task 4." >&2
  exit 1
fi
```

Make executable: `chmod +x plugins/quality-gates/tests/spike/test_codex_json_extraction.sh`

- [ ] **0.4: Run spike**

Run from `plugins/quality-gates/`:
```bash
mkdir -p tests/spike/fixtures
bash tests/spike/test_codex_json_extraction.sh
```

Outcomes:
- **Pass (>=2/3):** spike exits 0, sample fixture saved. Proceed to Task 1.
- **Fail (<2/3):** spike exits 1. STOP. Adjust prompt template. If still failing after 2 iterations, escalate to user — spec amendment needed (OQ-2 resolution).

- [ ] **0.5: Commit spike artifacts**

```bash
git add plugins/quality-gates/tests/spike/
git commit -m "feat(qg-codex): add prompt-engineering spike for fenced JSON extraction"
```

---

## Task 1: AC7 backward-compatibility baseline capture (precursor)

**Why first (before any codex changes):** §AC7 requires regression diff against baseline captured pre-feature. Must run /qg on representative diffs in pristine state.

**Files:**
- Create: `plugins/quality-gates/tests/fixtures/baseline_synthesizer_{small,medium,large}.yaml`
- Create: `plugins/quality-gates/tests/fixtures/baseline_capture_README.md`
- Create: `plugins/quality-gates/tests/capture_baseline.sh`

### Steps

- [ ] **1.1: Identify 3 synthetic diffs**

Check existing `tests/e2e-scenarios.md` for suitable cases (small/medium/large). If unsuitable, construct 3 minimal patches under `tests/fixtures/baseline_inputs/`:
- small: single-file rename (~5 lines)
- medium: new function + test (~50 lines)
- large: new module with cross-file imports (~200 lines)

- [ ] **1.2: Capture baseline (with DEVBREW_DISABLE_QG_CODEX=1)**

Create `tests/capture_baseline.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
export DEVBREW_DISABLE_QG_CODEX=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
mkdir -p "$FIXTURES"

for size in small medium large; do
  echo "Capturing baseline_synthesizer_$size.yaml..."
  bash "$SCRIPT_DIR/run_qg_on_fixture.sh" "$size" \
    | python3 "$SCRIPT_DIR/lib/normalize_qg_output.py" \
    > "$FIXTURES/baseline_synthesizer_$size.yaml"
done

echo "Baselines captured. Review and commit."
```

`run_qg_on_fixture.sh` and `normalize_qg_output.py` are helpers — inspect existing qg test patterns (`test_isolation.sh`, `test_session_tracker.py`). If absent, write minimal versions that invoke `/qg` non-interactively. If unattended invocation is not feasible, capture manually by running `/qg` interactively against each fixture diff and saving synthesizer output.

- [ ] **1.3: Verify baselines are stable**

```bash
bash tests/capture_baseline.sh
mv tests/fixtures/baseline_synthesizer_small.yaml /tmp/first.yaml
bash tests/capture_baseline.sh
diff /tmp/first.yaml tests/fixtures/baseline_synthesizer_small.yaml
```

Expected: empty diff. If non-empty, identify non-deterministic fields and update normalizer. Re-capture until stable.

- [ ] **1.4: Document provenance**

Create `tests/fixtures/baseline_capture_README.md`:

```markdown
# Baseline Synthesizer Fixtures

Captured: 2026-05-13
Captured with: DEVBREW_DISABLE_QG_CODEX=1 (codex disabled)
Git commit at capture: <hash from git rev-parse HEAD>

These fixtures freeze synthesizer output for 3 representative diffs.
AC7 asserts QG output in codex-disabled environments is byte-identical
to these baselines after the codex-reviewer feature lands.

Regenerate: bash tests/capture_baseline.sh
```

- [ ] **1.5: Commit baselines**

```bash
git add plugins/quality-gates/tests/fixtures/baseline_*.yaml \
        plugins/quality-gates/tests/fixtures/baseline_capture_README.md \
        plugins/quality-gates/tests/capture_baseline.sh
git commit -m "test(qg-codex): capture AC7 baseline synthesizer fixtures"
```

---

## Task 2: detect_codex.sh probe (AC1, 6 cases)

**Files:**
- Test: `plugins/quality-gates/tests/test_detect_codex.sh`
- Create: `plugins/quality-gates/scripts/detect_codex.sh`
- Mocks: `plugins/quality-gates/tests/mocks/safe-v1/codex`, `plugins/quality-gates/tests/mocks/bad-version/codex`

### Steps

- [ ] **2.1: Create per-version mock binaries**

Create `tests/mocks/safe-v1/codex`:
```bash
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "1.0.0" ;;
  *) echo "mock-codex-safe-v1: unexpected arg $*" >&2; exit 2 ;;
esac
```

Create `tests/mocks/bad-version/codex`:
```bash
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "0.120.1" ;;
  *) echo "mock-codex-bad-version: unexpected arg $*" >&2; exit 2 ;;
esac
```

Make executable:
```bash
mkdir -p plugins/quality-gates/tests/mocks/safe-v1
mkdir -p plugins/quality-gates/tests/mocks/bad-version
chmod +x plugins/quality-gates/tests/mocks/safe-v1/codex
chmod +x plugins/quality-gates/tests/mocks/bad-version/codex
```

- [ ] **2.2: Write the 6-case test (failing first per TDD)**

Create `plugins/quality-gates/tests/test_detect_codex.sh`:

```bash
#!/usr/bin/env bash
# AC1 — 6-case probe verification.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t qg-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
assert_grep() {
  local desc="$1"; local output="$2"; local pattern="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS: $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $pattern"
    echo "    actual:"
    echo "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

echo "=== Case 1: not installed ==="
out="$(PATH=/usr/bin:/bin bash "$PROBE")"
assert_grep "not installed" "$out" 'skip_reason: not_installed'

echo "=== Case 2: installed + auth + safe version ==="
out="$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "ok" "$out" 'codex_available: true'

echo "=== Case 3: kill switch ==="
out="$(DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")"
assert_grep "kill switch" "$out" 'skip_reason: kill_switch'

echo "=== Case 4a: inside codex (CODEX_SANDBOX) ==="
out="$(CODEX_SANDBOX=1 bash "$PROBE")"
assert_grep "inside codex via CODEX_SANDBOX" "$out" 'skip_reason: inside_codex_sandbox'

echo "=== Case 4b: inside codex (CODEX_SESSION_ID) ==="
out="$(CODEX_SESSION_ID=abc bash "$PROBE")"
assert_grep "inside codex via CODEX_SESSION_ID" "$out" 'skip_reason: inside_codex_sandbox'

echo "=== Case 5: auth missing ==="
mkdir -p "$TMP/no-codex-home"
out="$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/no-codex-home" bash "$PROBE")"
assert_grep "auth missing" "$out" 'skip_reason: auth_missing'

echo "=== Case 6: known bad version ==="
out="$(PATH="$MOCKS/bad-version:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "known bad version" "$out" 'skip_reason: known_bad_version'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable: `chmod +x tests/test_detect_codex.sh`

(Note: test uses direct command substitution `$(...)` with inline env-var prefixes — no shell `eval` builtin. Cleaner than eval-based dispatch.)

- [ ] **2.3: Run test, verify all 7 sub-cases fail (probe doesn't exist)**

```bash
cd plugins/quality-gates
bash tests/test_detect_codex.sh
```

Expected: 7 FAILs.

- [ ] **2.4: Implement `scripts/detect_codex.sh`**

Create `plugins/quality-gates/scripts/detect_codex.sh`:

```bash
#!/usr/bin/env bash
# detect_codex.sh — emit YAML manifest describing Codex CLI availability.
# Spec AC1. Read-only, exit 0 always (graceful degradation).

set -u

emit_skip() {
  printf 'codex_available: false\n'
  printf 'skip_reason: %s\n' "$1"
}

# 1. Kill switch
if [[ "${DEVBREW_DISABLE_QG_CODEX:-0}" == "1" ]]; then
  emit_skip 'kill_switch'
  exit 0
fi

# 2. Recursion guard
if [[ -n "${CODEX_SANDBOX:-}" || -n "${CODEX_SESSION_ID:-}" ]]; then
  emit_skip 'inside_codex_sandbox'
  exit 0
fi

# 3. Install check
CODEX_PATH="$(command -v codex 2>/dev/null || true)"
if [[ -z "$CODEX_PATH" || "$CODEX_PATH" != /* ]]; then
  emit_skip 'not_installed'
  exit 0
fi

# 4. Auth check
if [[ -z "${CODEX_API_KEY:-}" && -z "${OPENAI_API_KEY:-}" && ! -f "${HOME:-/nonexistent}/.codex/auth.json" ]]; then
  emit_skip 'auth_missing'
  exit 0
fi

# 5. Version check (known-bad regex from gstack)
CODEX_VERSION="$(codex --version 2>/dev/null | head -1 || echo unknown)"
if echo "$CODEX_VERSION" | grep -Eq '(^|[^0-9.])0\.120\.(0|1|2)([^0-9.]|$)'; then
  printf 'codex_available: false\n'
  printf 'skip_reason: known_bad_version\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  exit 0
fi

# 6. All checks pass
printf 'codex_available: true\n'
printf 'codex_path: %s\n' "$CODEX_PATH"
printf 'codex_version: %s\n' "$CODEX_VERSION"
exit 0
```

Make executable: `chmod +x scripts/detect_codex.sh`

- [ ] **2.5: Run test, verify all 7 sub-cases pass**

```bash
bash tests/test_detect_codex.sh
```

Expected:
```
Total: 7, pass: 7, fail: 0
```

- [ ] **2.6: Commit**

```bash
git add plugins/quality-gates/scripts/detect_codex.sh \
        plugins/quality-gates/tests/test_detect_codex.sh \
        plugins/quality-gates/tests/mocks/safe-v1/codex \
        plugins/quality-gates/tests/mocks/bad-version/codex
git commit -m "feat(qg-codex): add detect_codex.sh 6-case probe"
```

---

## Task 3: codex_findings_to_yaml.py parser (AC3, 3-stage fallback)

**Files:**
- Test: `plugins/quality-gates/tests/test_findings_parser.sh`
- Create: `plugins/quality-gates/scripts/codex_findings_to_yaml.py`

### Steps

- [ ] **3.1: Write parser test (failing first)**

Create `plugins/quality-gates/tests/test_findings_parser.sh`:

```bash
#!/usr/bin/env bash
# AC3 — parser fallback chain + stderr handling.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER="$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py"
TMP="$(mktemp -d -t qg-parser-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

check() {
  local name="$1" stdin_file="$2" stderr_file="$3" expected_grep="$4"
  if [[ -n "$stderr_file" ]]; then
    output="$(python3 "$PARSER" --stderr-file "$stderr_file" < "$stdin_file" 2>&1)"
  else
    output="$(python3 "$PARSER" < "$stdin_file" 2>&1)"
  fi
  if echo "$output" | grep -q "$expected_grep"; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name"; echo "    expected grep: $expected_grep"
    echo "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

# Fixture 1: fenced JSON in agent_message (Stage 1 success)
cat > "$TMP/fenced.jsonl" <<'EOF'
{"type":"agent_message","text":"Here are findings:\n```json\n{\"findings\":[{\"file\":\"a.py\",\"line\":3,\"severity\":\"IMPORTANT\",\"confidence\":9,\"summary\":\"index access without bounds check\",\"proposed_fix\":\"catch IndexError\"}]}\n```"}
EOF
check "fenced JSON Stage 1" "$TMP/fenced.jsonl" "" 'file: a.py'

# Fixture 2: raw JSON (Stage 2 success)
cat > "$TMP/raw.jsonl" <<'EOF'
{"type":"agent_message","text":"{\"findings\":[{\"file\":\"b.py\",\"line\":5,\"severity\":\"IMPORTANT\",\"confidence\":7,\"summary\":\"null check missing\",\"proposed_fix\":\"add if b is None guard\"}]}"}
EOF
check "raw JSON Stage 2" "$TMP/raw.jsonl" "" 'file: b.py'

# Fixture 3: malformed bytes (Stage 3 fallback)
printf '\x00\x01\x02notjson\xff' > "$TMP/bad.bin"
check "malformed Stage 3" "$TMP/bad.bin" "" 'reason: malformed_json'

# Fixture 4: missing agent_message
cat > "$TMP/missing.jsonl" <<'EOF'
{"type":"thought","text":"thinking"}
{"type":"tool_call","name":"read"}
EOF
check "missing agent_message" "$TMP/missing.jsonl" "" 'reason: missing_result'

# Fixture 5: auth error in stderr
: > "$TMP/empty.jsonl"
cat > "$TMP/auth-err.txt" <<'EOF'
Error: authentication failed: invalid API key
EOF
check "auth error in stderr" "$TMP/empty.jsonl" "$TMP/auth-err.txt" 'reason: auth_error_in_stderr'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable: `chmod +x tests/test_findings_parser.sh`

- [ ] **3.2: Run test, verify all 5 fail**

```bash
bash tests/test_findings_parser.sh
```

Expected: 5 FAILs.

- [ ] **3.3: Implement parser**

Create `plugins/quality-gates/scripts/codex_findings_to_yaml.py`:

```python
#!/usr/bin/env python3
"""codex_findings_to_yaml.py — Convert Codex JSONL stream to QG finding YAML.

Spec AC3. Three-stage fallback chain on the last agent_message text:
  1. Fenced JSON code block
  2. Raw JSON parse
  3. Fallback: empty findings + meta.reason: malformed_json

Auth-error detection: if stderr contains an auth-failure pattern AND no
findings extracted, emit meta.reason: auth_error_in_stderr.
"""

import argparse
import json
import re
import sys
from typing import Any


AUTH_ERROR_RE = re.compile(
    r"\b(authentication|auth\s+(failed|error)|invalid\s+(api[\s_]?key|token))\b",
    re.IGNORECASE,
)
FENCED_JSON_RE = re.compile(r"```json\s*\n(.*?)\n```", re.DOTALL)


def extract_last_agent_message(stdin_text: str) -> str | None:
    last_text: str | None = None
    for line in stdin_text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "agent_message":
            txt = ev.get("text") or ev.get("message", "")
            if txt:
                last_text = txt
    return last_text


def parse_fenced_json(text: str) -> dict | None:
    m = FENCED_JSON_RE.search(text)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


def parse_raw_json(text: str) -> dict | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def yaml_emit(findings: list[dict], meta: dict) -> str:
    out: list[str] = []
    if not findings:
        out.append("findings: []")
    else:
        out.append("findings:")
        for f in findings:
            out.append("  - agent: codex-reviewer")
            for k in ("file", "line", "severity", "confidence", "summary", "proposed_fix"):
                if k in f:
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    out.append("meta:")
    for k, v in meta.items():
        out.append(f"  {k}: {_yaml_scalar(v)}")
    return "\n".join(out) + "\n"


def _yaml_scalar(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--stderr-file", default=None)
    args = p.parse_args()

    stdin_text = sys.stdin.read()
    stderr_text = ""
    if args.stderr_file:
        try:
            with open(args.stderr_file, "r", encoding="utf-8", errors="replace") as fh:
                stderr_text = fh.read()
        except OSError:
            stderr_text = ""

    def has_auth_error() -> bool:
        return bool(stderr_text and AUTH_ERROR_RE.search(stderr_text))

    last_msg = extract_last_agent_message(stdin_text)

    if last_msg is None:
        if has_auth_error():
            meta = {
                "codex_failed": True,
                "reason": "auth_error_in_stderr",
                "exit_code": 0,
                "stderr_preview": stderr_text[:200],
            }
        else:
            meta = {"codex_failed": True, "reason": "missing_result", "exit_code": 0}
        sys.stdout.write(yaml_emit([], meta))
        return 0

    parsed = parse_fenced_json(last_msg)
    if parsed is None:
        parsed = parse_raw_json(last_msg.strip())

    if parsed is None or not isinstance(parsed, dict) or "findings" not in parsed:
        if has_auth_error():
            meta = {
                "codex_failed": True,
                "reason": "auth_error_in_stderr",
                "exit_code": 0,
                "stderr_preview": stderr_text[:200],
            }
        else:
            meta = {
                "codex_failed": True,
                "reason": "malformed_json",
                "exit_code": 0,
                "raw_text_preview": last_msg[:200],
            }
        sys.stdout.write(yaml_emit([], meta))
        return 0

    findings = parsed.get("findings", []) or []
    if not isinstance(findings, list):
        findings = []

    meta = {"codex_failed": False}
    sys.stdout.write(yaml_emit(findings, meta))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **3.4: Run test, verify all 5 pass**

```bash
bash tests/test_findings_parser.sh
```

Expected: `Total: 5, pass: 5, fail: 0`

- [ ] **3.5: Commit**

```bash
git add plugins/quality-gates/scripts/codex_findings_to_yaml.py \
        plugins/quality-gates/tests/test_findings_parser.sh
git commit -m "feat(qg-codex): add codex_findings_to_yaml.py JSONL parser"
```

---

## Task 4: codex-reviewer agent (AC4, AC9, AC11)

**BLOCKED BY:** Task 0 spike must have passed (>=2/3).

**Files:**
- Test: `plugins/quality-gates/tests/test_sandbox_enforced.sh`
- Test helper: `plugins/quality-gates/tests/lib/extract_codex_invocations.py`
- Create: `plugins/quality-gates/agents/codex-reviewer.md`

### Steps

- [ ] **4.1: Write sandbox-enforced static check (AC4)**

Create `plugins/quality-gates/tests/lib/extract_codex_invocations.py`:

```python
#!/usr/bin/env python3
"""Extract logical codex invocation lines from a markdown agent file.

Normalizes backslash-line-continuations so multi-line shell invocations
can be grep-checked for required flags.

Usage: python3 extract_codex_invocations.py path/to/agent.md
Stdout: one logical invocation per line.
"""

import re
import sys


def normalize_continuations(text: str) -> str:
    return re.sub(r"\\\n\s*", " ", text)


def extract_shell_blocks(md: str) -> list[str]:
    return re.findall(r"```(?:bash|sh|shell)?\s*\n(.*?)\n```", md, re.DOTALL)


def find_codex_lines(block: str) -> list[str]:
    block = normalize_continuations(block)
    return [line.strip() for line in block.split("\n") if "codex exec" in line]


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path>", file=sys.stderr)
        return 2
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        md = fh.read()
    for block in extract_shell_blocks(md):
        for line in find_codex_lines(block):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Create `plugins/quality-gates/tests/test_sandbox_enforced.sh`:

```bash
#!/usr/bin/env bash
# AC4 — every codex invocation in codex-reviewer.md has -s read-only,
# -C "$<var>", and --json.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_ROOT/agents/codex-reviewer.md"
EXTRACTOR="$SCRIPT_DIR/lib/extract_codex_invocations.py"

[[ -f "$AGENT" ]] || { echo "FAIL: $AGENT missing"; exit 1; }
[[ -f "$EXTRACTOR" ]] || { echo "FAIL: $EXTRACTOR missing"; exit 1; }

invocations="$(python3 "$EXTRACTOR" "$AGENT")"
if [[ -z "$invocations" ]]; then
  echo "FAIL: no codex invocations found in $AGENT"
  exit 1
fi

offenders="$(echo "$invocations" | grep -v -E '(-s|--sandbox)[[:space:]]+read-only' || true)"
if [[ -n "$offenders" ]]; then
  echo "FAIL: codex invocations missing -s read-only:"
  echo "$offenders" | sed 's/^/  /'
  exit 1
fi

no_repo_root="$(echo "$invocations" | grep -v -E -- '-C[[:space:]]+\"\$' || true)"
if [[ -n "$no_repo_root" ]]; then
  echo "FAIL: codex invocations missing -C \"\$<var>\":"
  echo "$no_repo_root" | sed 's/^/  /'
  exit 1
fi

no_json="$(echo "$invocations" | grep -v -E -- '--json' || true)"
if [[ -n "$no_json" ]]; then
  echo "FAIL: codex invocations missing --json:"
  echo "$no_json" | sed 's/^/  /'
  exit 1
fi

echo "PASS: all $(echo "$invocations" | wc -l) codex invocations are sandboxed/pinned/json."
exit 0
```

Make executable: `chmod +x tests/test_sandbox_enforced.sh tests/lib/extract_codex_invocations.py`

- [ ] **4.2: Run test, verify it fails (agent doesn't exist)**

```bash
bash tests/test_sandbox_enforced.sh
```

Expected: `FAIL: <path>/agents/codex-reviewer.md missing`

- [ ] **4.3: Create codex-reviewer.md agent**

Create `plugins/quality-gates/agents/codex-reviewer.md`:

```markdown
---
name: codex-reviewer
description: Independent code reviewer that delegates to the Codex CLI as a separate process with read-only sandbox. Runs only when codex is detected and not opted out. Emits standard Phase 1 finding YAML.
model: inherit
cost_class: variable
allowed-tools:
  - Bash(codex exec*)
  - Bash(timeout *)
  - Bash(gtimeout *)
  - Bash(mktemp -d*)
  - Bash(python3 *)
  - Read
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
  - Glob
---

You are **codex-reviewer**, a thin wrapper that delegates code review to the Codex CLI subprocess.

You are responsible for: invoking codex with the canonical read-only invocation (below), capturing its JSONL stream, piping it through `codex_findings_to_yaml.py`, and emitting the resulting YAML to stdout.

You are NOT responsible for: producing findings yourself, modifying any file, running tests, choosing different sandbox modes, or improvising on the invocation flags.

## Inputs

- `filtered_diff`: unified diff with documentation paths excluded.
- `gate1_summary`: YAML block from plan-verifier (matched_items only — used for context).

## Canonical invocation

Pre-conditions: `detect_codex.sh` has emitted `codex_available: true`.

Execute exactly this sequence:

```bash
SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)"
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"
TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Write prompt from template (see "Prompt template" below);
# substitute {{FILTERED_DIFF}} and {{PLAN_SUMMARY}} with the
# agent inputs.

"$TIMEOUT_CMD" 600 codex exec "$(cat "$PROMPT_FILE")" \
    -C "$REPO_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE"
EXIT_CODE=$?

python3 plugins/quality-gates/scripts/codex_findings_to_yaml.py \
    --stderr-file "$STDERR_FILE" \
    < "$STDOUT_FILE"

if [[ $EXIT_CODE -eq 124 ]]; then
  printf '  exit_code: 124\n  reason: timeout\n  codex_failed: true\n'
elif [[ $EXIT_CODE -ne 0 ]]; then
  printf '  exit_code: %d\n  reason: exit_nonzero\n  codex_failed: true\n' "$EXIT_CODE"
fi
```

## Prompt template

Use this template, substituting `{{FILTERED_DIFF}}` and `{{PLAN_SUMMARY}}`:

```text
You are a code reviewer. Review the diff for bugs, silent failures,
security issues, missing error handling, and design problems. Do not
modify any files; you are in a read-only sandbox.

<diff>
{{FILTERED_DIFF}}
</diff>

<plan_context>
{{PLAN_SUMMARY}}
</plan_context>

Output your findings in a fenced JSON code block:

[BACKTICKS_JSON]
{
  "findings": [
    {
      "file": "<path>",
      "line": <integer>,
      "severity": "CRITICAL | IMPORTANT | SUGGESTION",
      "confidence": <integer 1-10>,
      "summary": "<one sentence>",
      "proposed_fix": "<description>"
    }
  ]
}
[BACKTICKS_END]

If you find no issues, emit `{"findings": []}` inside the same code fence.
Do not output any text after the closing fence.
```

(Replace `[BACKTICKS_JSON]` with three backticks + `json`, and `[BACKTICKS_END]` with three backticks, when writing the prompt to disk.)

## Forbidden

- Do not modify the invocation flags. `-s read-only`, `-C "$REPO_ROOT"`, `--json`, `< /dev/null`, and `2>"$STDERR_FILE"` are load-bearing.
- Do not pipe to `cat` or any other intermediate command.
- Do not retry on failure within this agent.
- Do not produce findings of your own; you are the parser's output emitter.
```

- [ ] **4.4: Run sandbox-enforced check (AC4)**

```bash
bash tests/test_sandbox_enforced.sh
```

Expected: `PASS: all 1 codex invocations are sandboxed/pinned/json.`

- [ ] **4.5: Verify AC9 + AC11 frontmatter**

```bash
python3 -c "
import yaml, re
md = open('agents/codex-reviewer.md').read()
fm = re.match(r'^---\n(.*?)\n---', md, re.DOTALL).group(1)
data = yaml.safe_load(fm)
required_disallowed = {'Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Glob'}
missing = required_disallowed - set(data['disallowedTools'])
assert not missing, f'missing disallowed: {missing}'
allowed = data['allowed-tools']
banned = ['Bash(cat *)', 'Bash(echo *)', 'Write', 'Edit', 'MultiEdit']
for b in banned:
    assert b not in allowed, f'banned tool present: {b}'
print('AC9 + AC11 frontmatter checks passed')
"
```

Expected: `AC9 + AC11 frontmatter checks passed`

- [ ] **4.6: Commit**

```bash
git add plugins/quality-gates/agents/codex-reviewer.md \
        plugins/quality-gates/tests/test_sandbox_enforced.sh \
        plugins/quality-gates/tests/lib/extract_codex_invocations.py
git commit -m "feat(qg-codex): add codex-reviewer agent with 3-layer isolation"
```

---

## Task 5: 6 mock codex binaries (AC5)

**Files:**
- Test: `plugins/quality-gates/tests/test_failure_injection.sh`
- 6 mocks under `plugins/quality-gates/tests/mocks/`

### Steps

- [ ] **5.1: Write failure-injection test (failing first)**

Create `plugins/quality-gates/tests/test_failure_injection.sh`:

```bash
#!/usr/bin/env bash
# AC5 — verify each failure mock produces correct meta in parser output.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER="$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t qg-fail-inject-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

check_meta() {
  local name="$1"; local mock="$2"; local expected_reason="$3"
  local stdout_file="$TMP/$name.stdout"; local stderr_file="$TMP/$name.stderr"
  bash "$mock" > "$stdout_file" 2>"$stderr_file" || true
  output="$(python3 "$PARSER" --stderr-file "$stderr_file" < "$stdout_file")"

  if [[ "$expected_reason" == "(none)" ]]; then
    if echo "$output" | grep -q 'codex_failed: false' && echo "$output" | grep -q 'agent: codex-reviewer'; then
      echo "  PASS: $name (parsed findings, no failure)"
      pass=$((pass + 1))
    else
      echo "  FAIL: $name"
      echo "$output" | sed 's/^/    /'
      fail=$((fail + 1))
    fi
  else
    if echo "$output" | grep -q "reason: $expected_reason"; then
      echo "  PASS: $name -> $expected_reason"
      pass=$((pass + 1))
    else
      echo "  FAIL: $name (expected reason: $expected_reason)"
      echo "$output" | sed 's/^/    /'
      fail=$((fail + 1))
    fi
  fi
}

chmod +x "$MOCKS"/mock-codex-*.sh

check_meta "exit-1" "$MOCKS/mock-codex-exit1.sh" "missing_result"
check_meta "bad-json" "$MOCKS/mock-codex-bad-json.sh" "malformed_json"
check_meta "no-agent-message" "$MOCKS/mock-codex-no-agent-message.sh" "missing_result"
check_meta "valid-json-no-fence" "$MOCKS/mock-codex-valid-json-no-fence.sh" "(none)"
check_meta "auth-stderr" "$MOCKS/mock-codex-auth-stderr.sh" "auth_error_in_stderr"

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable.

- [ ] **5.2: Run test, verify failures (mocks don't exist)**

```bash
bash tests/test_failure_injection.sh
```

Expected: 5 FAILs.

- [ ] **5.3: Create the 6 mocks**

Create `tests/mocks/mock-codex-exit1.sh`:
```bash
#!/usr/bin/env bash
exit 1
```

Create `tests/mocks/mock-codex-hang.sh`:
```bash
#!/usr/bin/env bash
sleep 700
```

Create `tests/mocks/mock-codex-bad-json.sh`:
```bash
#!/usr/bin/env bash
printf '\x01\x02not-jsonl\x00garbage\n'
exit 0
```

Create `tests/mocks/mock-codex-no-agent-message.sh`:
```bash
#!/usr/bin/env bash
cat <<'EOF'
{"type":"thought","text":"thinking..."}
{"type":"tool_call","name":"read","path":"x.py"}
EOF
exit 0
```

Create `tests/mocks/mock-codex-valid-json-no-fence.sh`:
```bash
#!/usr/bin/env bash
cat <<'EOF'
{"type":"agent_message","text":"{\"findings\":[{\"file\":\"x.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":5,\"summary\":\"nothing wrong\",\"proposed_fix\":\"n/a\"}]}"}
EOF
exit 0
```

Create `tests/mocks/mock-codex-auth-stderr.sh`:
```bash
#!/usr/bin/env bash
echo "Error: authentication failed: invalid API key" >&2
exit 0
```

Make all executable: `chmod +x tests/mocks/mock-codex-*.sh`

- [ ] **5.4: Run test, verify all pass**

```bash
bash tests/test_failure_injection.sh
```

Expected: `Total: 5, pass: 5, fail: 0`

- [ ] **5.5: Commit**

```bash
git add plugins/quality-gates/tests/mocks/mock-codex-*.sh \
        plugins/quality-gates/tests/test_failure_injection.sh
git commit -m "test(qg-codex): add 6 failure-injection mocks for AC5"
```

---

## Task 6: scout.md patch (AC2, 3 hunks)

**Files:**
- Test: `plugins/quality-gates/tests/test_scout_codex_integration.sh`
- Modify: `plugins/quality-gates/agents/scout.md`

### Steps

- [ ] **6.1: Write scout-integration test (failing first)**

Create `plugins/quality-gates/tests/test_scout_codex_integration.sh`:

```bash
#!/usr/bin/env bash
# AC2 — static check: scout.md mentions codex_manifest in Inputs,
# codex-reviewer in Phase 1 table, and the selection rule.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOUT_MD="$PLUGIN_ROOT/agents/scout.md"

pass=0; fail=0
check() {
  local name="$1" pattern="$2"
  if grep -q "$pattern" "$SCOUT_MD"; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (pattern not found: $pattern)"
    fail=$((fail + 1))
  fi
}

check "Inputs lists codex_manifest" 'codex_manifest'
check "Phase1 table references codex-reviewer" 'codex-reviewer'
check "Selection rule for codex-reviewer depth gate" 'codex_available.*standard.*deep\|codex_available.*depth'
check "Selection rule mentions skip on quick" 'quick.*[Ss]kip\|[Ss]kip.*quick'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable.

- [ ] **6.2: Run test, verify failures**

```bash
bash tests/test_scout_codex_integration.sh
```

Expected: 4 FAILs.

- [ ] **6.3: Patch scout.md — 3 hunks**

Read current scout.md, then apply 3 changes from spec §6.2:

Hunk 1 — Inputs section. Add after `session_scope`:

```
- `codex_manifest`: YAML block from `scripts/detect_codex.sh`:
  ```yaml
  codex_available: true | false
  codex_path: <string, only if available>
  codex_version: <string, only if available>
  skip_reason: <not_installed | kill_switch | inside_codex_sandbox | auth_missing | known_bad_version>
  ```
```

Hunk 2 — Phase 1 table:

Change `| standard | [code-reviewer, silent-failure-hunter] |` to `| standard | [code-reviewer, silent-failure-hunter] + codex-reviewer if codex_available |`.

Change `| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] |` to `| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] + codex-reviewer if codex_available |`.

Hunk 3 — Phase 1 selection prose. Add a new bullet after the existing list:

```
- `codex-reviewer`: include when `codex_manifest.codex_available == true` AND depth ∈ {standard, deep}. Skip on `quick` — cost/latency overhead is unjustified for small diffs.
```

(Use `Read` then `Edit` for precise application. Match by context, not line number.)

- [ ] **6.4: Run test, verify 4 pass**

```bash
bash tests/test_scout_codex_integration.sh
```

Expected: `Total: 4, pass: 4, fail: 0`

- [ ] **6.5: Commit**

```bash
git add plugins/quality-gates/agents/scout.md \
        plugins/quality-gates/tests/test_scout_codex_integration.sh
git commit -m "feat(qg-codex): scout dispatches codex-reviewer when available"
```

---

## Task 7: quality-pipeline SKILL.md patch

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

### Steps

- [ ] **7.1: Locate Gate 2 Phase 0 section**

```bash
grep -n "Gate 2.*Phase 0\|Scout\|scout" plugins/quality-gates/skills/quality-pipeline/SKILL.md | head -10
```

Identify the section immediately before Scout dispatch.

- [ ] **7.2: Insert probe call + Scout input synthesis**

Use `Edit` to insert before Scout dispatch:

```markdown
**Codex availability probe (Gate 2, Phase 0 prerequisite):**

Run before dispatching scout:

\`\`\`bash
MANIFEST_PATH="${TMPDIR:-/tmp}/qg-codex-manifest-${CLAUDE_CODE_SESSION_ID:-unknown}.yaml"
bash plugins/quality-gates/scripts/detect_codex.sh > "$MANIFEST_PATH"
\`\`\`

The script emits a YAML manifest (6 cases). Read the manifest and include it as the `codex_manifest:` field in the Scout dispatch prompt's inputs section, alongside `filtered_diff`, `gate1_summary`, and `session_scope`.

Idempotency: rerunning is safe (read-only, no side effects). If the manifest file exists from a prior probe in this session, regenerate it — environment state may have changed.
```

- [ ] **7.3: Verify Scout receives manifest (manual)**

Run /qg in a test session, inspect dispatch prompt for `codex_manifest:` block.

- [ ] **7.4: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "feat(qg-codex): SKILL.md probes codex before Scout dispatch"
```

---

## Task 8: Cost consent gate (AC10)

**Files:**
- Test: `plugins/quality-gates/tests/test_cost_consent.sh`
- Test harness: `plugins/quality-gates/tests/harness/run_consent_gate.sh`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

### Steps

- [ ] **8.1: Write cost-consent test (failing first)**

Create `plugins/quality-gates/tests/test_cost_consent.sh`:

```bash
#!/usr/bin/env bash
# AC10 — first-use consent gate fires; subsequent silent.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKER="${HOME}/.claude/quality-gates/codex-cost-consent.md"
CAPTURE_DIR="$(mktemp -d -t qg-consent-test-XXXXXX)"

restore() {
  rm -rf "$CAPTURE_DIR"
  test -f "$MARKER.test-bak" && mv "$MARKER.test-bak" "$MARKER"
  return 0
}
trap restore EXIT
test -f "$MARKER" && mv "$MARKER" "$MARKER.test-bak"

pass=0; fail=0

# Test 1: first run with no marker -> consent question captured
rm -f "$MARKER"
export QG_MOCK_ASKUSER_PATH="$CAPTURE_DIR/q1.json"
bash "$SCRIPT_DIR/harness/run_consent_gate.sh" 2>/dev/null || true
if [[ -f "$QG_MOCK_ASKUSER_PATH" ]] && grep -qi 'codex' "$QG_MOCK_ASKUSER_PATH"; then
  echo "  PASS: first run prompted for consent"; pass=$((pass + 1))
else
  echo "  FAIL: first run did not capture consent question"
  fail=$((fail + 1))
fi

# Test 2: marker exists -> second run silent
test -f "$MARKER" || touch "$MARKER"
export QG_MOCK_ASKUSER_PATH="$CAPTURE_DIR/q2.json"
bash "$SCRIPT_DIR/harness/run_consent_gate.sh" 2>/dev/null || true
if [[ ! -f "$QG_MOCK_ASKUSER_PATH" ]]; then
  echo "  PASS: second run silent (marker present)"; pass=$((pass + 1))
else
  echo "  FAIL: second run still prompted"
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable.

- [ ] **8.2: Create test harness**

Create `plugins/quality-gates/tests/harness/run_consent_gate.sh`:

```bash
#!/usr/bin/env bash
# Minimal harness simulating the SKILL.md consent gate in isolation.

set -u
MARKER="${HOME}/.claude/quality-gates/codex-cost-consent.md"

if [[ -f "$MARKER" ]]; then
  exit 0
fi

if [[ -n "${QG_MOCK_ASKUSER_PATH:-}" ]]; then
  cat > "$QG_MOCK_ASKUSER_PATH" <<'EOF'
question: Codex CLI detected. Enable codex-reviewer for this project?
options:
  - Approve once
  - Approve always (recommended)
  - Decline
EOF
  mkdir -p "${HOME}/.claude/quality-gates"
  printf 'consented: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKER"
  exit 0
fi

echo "Real AskUserQuestion not invoked in harness" >&2
exit 0
```

Make executable. Create dir: `mkdir -p tests/harness`.

- [ ] **8.3: Add consent-gate logic in SKILL.md**

Insert into `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (after Phase 0 probe section, before scout dispatch):

```markdown
**Codex cost consent (first-use gate):**

If `codex_manifest.codex_available == true` AND marker file `${HOME}/.claude/quality-gates/codex-cost-consent.md` does not exist:

1. If `QG_MOCK_ASKUSER_PATH` env var is set: write the question text to that path and read response as `approve` (test harness hook).
2. Else: invoke `AskUserQuestion` (load via `ToolSearch select:AskUserQuestion` if schema not present):
   - Question: "Codex CLI detected (`{codex_version}`). The codex-reviewer agent will call `codex exec` for each Gate 2 review on `standard`/`deep` diffs. This uses your Codex subscription/API and may incur cost (proxy ceiling: 600s wall-clock per call). Approve enabling codex-reviewer for this project?"
   - Options:
     - `Approve once` — enables for this session only, no marker
     - `Approve always (recommended)` — writes marker; silent on future runs
     - `Decline` — sets `codex_available: false` for this session

3. On `Approve always`: write marker with `consented: <ISO timestamp>`.
4. On `Decline`: replace loaded `codex_manifest` with `codex_available: false\nskip_reason: user_declined_cost_consent` for remainder of session.
```

- [ ] **8.4: Run test, verify both cases pass**

```bash
bash tests/test_cost_consent.sh
```

Expected: `Total: 2, pass: 2, fail: 0`

- [ ] **8.5: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md \
        plugins/quality-gates/tests/test_cost_consent.sh \
        plugins/quality-gates/tests/harness/run_consent_gate.sh
git commit -m "feat(qg-codex): first-use cost consent gate for codex-reviewer"
```

---

## Task 9: Metadata bump + CHANGELOG + README (AC8)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/README.md` (3 spots)

### Steps

- [ ] **9.1: Bump plugin.json version**

```bash
cd plugins/quality-gates
python3 -c "
import json
p = '.claude-plugin/plugin.json'
d = json.load(open(p))
assert d['version'] == '1.10.0', f'expected 1.10.0, got {d[\"version\"]}'
d['version'] = '1.11.0'
json.dump(d, open(p, 'w'), indent=2)
open(p, 'a').write('\n')
print('Bumped to 1.11.0')
"
```

Verify: `jq -r .version .claude-plugin/plugin.json` → `1.11.0`

- [ ] **9.2: Add CHANGELOG entry**

Insert at top of CHANGELOG version log (before `## [1.10.0]`):

```markdown
## [1.11.0] — 2026-05-13

### Added
- `codex-reviewer` agent: independent code reviewer dispatched as a separate process via `codex exec --json -s read-only` when Codex CLI is detected. Adds OS-process + model-family separation to QG Gate 2 Phase 1, strengthening Law 2.
- `scripts/detect_codex.sh`: 6-case probe (not_installed, kill_switch, inside_codex_sandbox, auth_missing, known_bad_version, ok). Read-only, exit 0 always.
- `scripts/codex_findings_to_yaml.py`: JSONL parser with 3-stage fallback (fenced JSON → raw JSON → malformed_json), plus stderr auth-error detection.
- First-use cost consent gate with marker at `~/.claude/quality-gates/codex-cost-consent.md`.
- Kill switch: `DEVBREW_DISABLE_QG_CODEX=1`.

### Changed
- `agents/scout.md`: dispatch input now includes `codex_manifest` (backwards-compatible).
- `skills/quality-pipeline/SKILL.md`: Gate 2 Phase 0 prerequisite runs `detect_codex.sh` and synthesizes manifest into Scout's input.

### Notes
- Bumps QG Gate 2 max parallel fan-out from 11 → 12.
- Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md`
```

- [ ] **9.3: Update README.md — 3 spots**

Read existing README, then apply:

**Spot 1 — Principles Instantiated:** add bullet:
```markdown
- **Law 2 strengthening — model-family separation.** Optional `codex-reviewer` agent (when Codex CLI is detected) runs review in a separate process with a different model family (OpenAI vs Anthropic) and an OS-level read-only sandbox, giving 3-layer reviewer-writer isolation.
```

**Spot 2 — Fan-out:** update Gate 2 max from `11` → `12`.

**Spot 3 — Cost:** add subsection:
```markdown
### Codex reviewer cost

The optional `codex-reviewer` agent has `cost_class: variable` — it invokes the user's Codex CLI subscription/API on each `standard`/`deep` Gate 2 dispatch. First-use cost consent gate prompts via `AskUserQuestion`. Per-call wall-clock ceiling: 600s (proxy for cost ceiling). Disable globally with `DEVBREW_DISABLE_QG_CODEX=1`.
```

- [ ] **9.4: Verify all 3 README spots**

```bash
grep -c "Law 2 strengthening" README.md
grep -E "fan-out.*12|12.*fan-out" README.md
grep "DEVBREW_DISABLE_QG_CODEX" README.md
```

- [ ] **9.5: Commit**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/README.md
git commit -m "chore(qg-codex): bump to 1.11.0 + CHANGELOG + README"
```

---

## Task 10: AC7 regression run

**Files:** none new; consumes Task 1 baselines.

### Steps

- [ ] **10.1: Write regression test**

Create `plugins/quality-gates/tests/test_codex_backward_compat.sh`:

```bash
#!/usr/bin/env bash
# AC7 — codex-disabled run produces output identical to baseline fixtures.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"

pass=0; fail=0
for size in small medium large; do
  BASELINE="$FIXTURES/baseline_synthesizer_$size.yaml"
  CURRENT="$(mktemp -t qg-current-$size-XXXXXX.yaml)"
  trap "rm -f \"$CURRENT\"" EXIT

  if [[ ! -f "$BASELINE" ]]; then
    echo "  SKIP: $size (baseline missing — run Task 1 first)"
    continue
  fi

  DEVBREW_DISABLE_QG_CODEX=1 bash "$SCRIPT_DIR/run_qg_on_fixture.sh" "$size" \
    | python3 "$SCRIPT_DIR/lib/normalize_qg_output.py" \
    > "$CURRENT"

  if diff -u "$BASELINE" "$CURRENT" > /dev/null; then
    echo "  PASS: $size identical to baseline"
    pass=$((pass + 1))
  else
    echo "  FAIL: $size differs from baseline"
    diff -u "$BASELINE" "$CURRENT" | sed 's/^/    /'
    fail=$((fail + 1))
  fi
done

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
```

Make executable.

- [ ] **10.2: Run regression test**

```bash
bash plugins/quality-gates/tests/test_codex_backward_compat.sh
```

Expected: `Total: 3, pass: 3, fail: 0`

If FAIL: check normalizer strips all non-deterministic fields; check QG output structure hasn't drifted between baseline capture and now.

- [ ] **10.3: Commit regression test**

```bash
git add plugins/quality-gates/tests/test_codex_backward_compat.sh
git commit -m "test(qg-codex): AC7 regression — codex-disabled output matches baseline"
```

---

## Task 11: End-to-end self-review + PR

**Files:** none new.

### Steps

- [ ] **11.1: Run full test suite**

```bash
cd plugins/quality-gates
for t in tests/test_*.sh; do
  echo "=== $t ==="
  bash "$t" || { echo "FAILED: $t"; exit 1; }
done
echo "All tests passed."
```

Expected: every test reports pass with 0 failures.

- [ ] **11.2: Run pre-existing qg tests for regression**

```bash
for t in tests/test_*.sh tests/test_*.py; do
  echo "=== $t ==="
  case "$t" in
    *.py) python3 "$t" ;;
    *) bash "$t" ;;
  esac
done
```

Address any regressions.

- [ ] **11.3: Manual end-to-end smoke**

1. `DEVBREW_DISABLE_QG_CODEX=1 /qg` → scout dispatch excludes codex-reviewer
2. `/qg` (with codex installed + authed) → consent prompt → approve → codex-reviewer in Phase 1 → findings in synthesizer
3. After consent: `/qg` → silent on consent, codex-reviewer present
4. `DEVBREW_DISABLE_QG_CODEX=1 /qg` after consent → codex-reviewer absent (kill switch wins)

- [ ] **11.4: Final commit + PR**

```bash
git add -A
git commit -m "chore(qg-codex): final cleanup before PR" || true

gh pr create --base main \
  --title "feat(qg-codex): add Codex reviewer for Gate 2 Phase 1" \
  --body "$(cat <<'BODY_EOF'
## Summary

- Optional `codex-reviewer` agent in Gate 2 Phase 1 when Codex CLI is detected
- 6-case probe + JSONL parser + 3-layer isolation
- First-use cost consent gate, kill switch `DEVBREW_DISABLE_QG_CODEX=1`
- Strengthens Law 2: writer-reviewer separation now spans OS process + model family

## Test plan

- [x] AC1 probe 6-case (`test_detect_codex.sh`)
- [x] AC3 parser 3-stage (`test_findings_parser.sh`)
- [x] AC4 sandbox static (`test_sandbox_enforced.sh`)
- [x] AC5 6 failure mocks (`test_failure_injection.sh`)
- [x] AC2 scout integration (`test_scout_codex_integration.sh`)
- [x] AC10 cost consent (`test_cost_consent.sh`)
- [x] AC7 backward compat regression (`test_codex_backward_compat.sh`)
- [x] Existing qg tests pass unchanged
- [x] Manual smoke

Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY_EOF
)"
```

---

## Self-Review Notes

After writing the plan, I checked spec coverage:

- AC1 → Task 2 (6 cases)
- AC2 → Task 6
- AC3 → Task 3
- AC4 → Task 4 (static check)
- AC5 → Task 5 (6 mocks)
- AC6 → Implicit in Task 2 (kill_switch is case 3)
- AC7 → Tasks 1 (baseline) + 10 (regression)
- AC8 → Task 9
- AC9 → Task 4.5 (frontmatter)
- AC10 → Task 8
- AC11 → Task 4.5

Task 0 spike blocks Task 4.

**Stylistic adjustments from spec:**
- Spec hyphen-style script names → plan uses underscore for local convention
- Per-version mocks (`safe-v1/codex`, `bad-version/codex`) instead of flat `mock-codex-{ok,bad-version}.sh` for cleaner PATH override

**Implementer-vigilance residuals from spec round 3 review:**
- Spec §4.2 has stale `Bash(cat *)` example contradicting AC11 — plan uses AC11 as binding
- Spec §4.4 cost ceiling references `gtimeout 330` (corrected to 600 in §4.3) — plan uses 600 throughout
- Spec §7.7 had stale `gtimeout 330` — plan uses 600

§4.3 is authoritative; plan derives values from there.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-13-qg-codex-reviewer.md`. Two execution options:

1. **Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration. Best for 11-task scope.
2. **Inline Execution** — Execute tasks in this session via executing-plans, batch with checkpoints.

Which approach?
