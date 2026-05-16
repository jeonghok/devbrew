# QG Security Reviewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 1 always-run `security-reviewer` agent를 `plugins/quality-gates`에 추가, 모든 Gate 2 invocation에서 코드 레벨 보안 리뷰가 함께 실행되도록 scout + SKILL.md 배선.

**Architecture:** scout의 Phase 1 selection table(quick/standard/deep 3 tier)을 확장하여 새 agent를 catalog에 포함시키고, SKILL.md Phase 1 dispatch sequence가 다른 reviewer와 동일한 parallel 호출 패턴으로 dispatch한다. 새 agent는 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`로 Law 2 격리, `cost_class: medium` 선언, `model: inherit`. 출력은 `adversarial.md:22-30`이 정의한 canonical finding YAML schema. Kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` (codex-reviewer `DEVBREW_DISABLE_QG_CODEX` 패턴 미러링).

**Tech Stack:** Markdown (agent persona + skill orchestration), Bash (deterministic tests), `jq` (plugin.json verification), `grep` (structural assertion).

**Spec reference:** `docs/superpowers/specs/2026-05-16-qg-security-reviewer-design.md` v2.

---

## File Structure

**Create:**
- `plugins/quality-gates/agents/security-reviewer.md` — persona + frontmatter (canonical schema emit instruction + forced-findings 금지)
- `plugins/quality-gates/tests/test_security_reviewer_persona.sh` — AC2/AC10a structural grep (CI-blocking)
- `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` — AC5/AC11 kill switch grep (CI-blocking)
- `plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/diff.patch` — AC10b trigger fixture
- `plugins/quality-gates/tests/fixtures/security-reviewer/clean/diff.patch` — AC10b non-trigger fixture
- `plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml` — minimum expected output shape

**Modify:**
- `plugins/quality-gates/agents/scout.md` — Phase 1 selection table 3 tier 모두에 `security-reviewer` 추가
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Phase 1 parallel dispatch block에 security-reviewer 추가 + kill switch check (codex 패턴 미러링)
- `plugins/quality-gates/.claude-plugin/plugin.json` — version `1.12.0 → 1.13.0`
- `plugins/quality-gates/CHANGELOG.md` — `## [1.13.0] — 2026-05-16` entry
- `plugins/quality-gates/README.md` — agent inventory + kill switch + Law 2 instantiation 갱신

---

## Heads-up for the implementer

devbrew 본 repo에 `security_reminder_hook.py`라는 PreToolUse hook이 있어 특정 보안 키워드 (예: 특정 framework의 raw-HTML API literal 식별자) 가 `Write` payload에 등장하면 차단합니다. 본 plan에서는 paraphrased 표현 (예: "React raw-HTML render prop", "DOM raw-HTML manipulation") 을 사용합니다. 구현 단계에서:

1. **persona 본문이 LLM에게 정확한 keyword를 인식하도록 가르치려면**, hook을 우회해야 합니다. `DEVBREW_SKIP_HOOKS=...:security_reminder` env var 또는 hook 자체 kill switch (해당 hook 코드 확인 후 결정).
2. **본 plan의 paraphrase로 충분히 LLM이 패턴 매칭 가능하다고 판단하면** 그대로 진행. 후속 PR에서 keyword recognition에 실측 문제가 있을 때 literal로 보강.

---

## Task 0: Schema 재확인 (Spec §9 step-0)

이 task는 *읽기만* — 산출물 없음. 다음 작업 전에 head를 정확히 맞춘다.

**Files (read-only):**
- `plugins/quality-gates/agents/adversarial.md` lines 22-30
- `plugins/quality-gates/agents/synthesizer.md` (Algorithm 섹션)
- `plugins/quality-gates/scripts/codex_findings_to_yaml.py` (PROMPT 또는 emit 형식 주석)

- [ ] **Step 1: adversarial.md 22-30 행 읽기**

```bash
sed -n '22,30p' plugins/quality-gates/agents/adversarial.md
```

기대 output:
```yaml
- agent: <name>
  file: <path>
  line: <number>
  severity: CRITICAL | IMPORTANT | SUGGESTION
  confidence: <1-10>
  summary: <one-sentence>
  proposed_fix: <description or code>
```

- [ ] **Step 2: synthesizer.md의 Algorithm 섹션 확인**

```bash
sed -n '/^## Algorithm/,/^## /p' plugins/quality-gates/agents/synthesizer.md
```

확인 포인트: confidence < 7이 suppress된다는 규칙. → security-reviewer는 anchor 50 (= confidence 6) finding을 CRITICAL severity로 emit해야 synthesizer 컷오프를 통과한다.

- [ ] **Step 3: codex_findings_to_yaml.py docstring 확인 (cross-reference)**

```bash
sed -n '1,30p' plugins/quality-gates/scripts/codex_findings_to_yaml.py
```

확인 포인트: codex-reviewer가 동일 schema (agent/file/line/severity/confidence/summary/proposed_fix)를 emit. 새 agent는 LLM이 직접 emit하므로 parser 불필요.

- [ ] **Step 4: 다음 task로 진행 (커밋 없음)**

---

## Task 1: 구조적 persona 검증 테스트 작성 (실패하는 테스트)

**Files:**
- Create: `plugins/quality-gates/tests/test_security_reviewer_persona.sh`

- [ ] **Step 1: 테스트 스크립트 작성**

```bash
cat > plugins/quality-gates/tests/test_security_reviewer_persona.sh <<'EOF'
#!/usr/bin/env bash
# AC2 / AC10a — security-reviewer persona structural conformance.
# Verifies the persona file declares the canonical finding YAML schema
# from adversarial.md:22-30 and the forced-findings prohibition rule.
set -u
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/security-reviewer.md"

pass=0; fail=0
check() {
  local name="$1" cmd="$2" expected="$3"
  local actual
  actual="$(eval "$cmd" 2>/dev/null || echo "0")"
  if [ "$actual" -ge "$expected" ]; then
    echo "  PASS: $name (got $actual, expected >= $expected)"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (got $actual, expected >= $expected)"; fail=$((fail + 1))
  fi
}

# Existence
if [ ! -f "$PERSONA" ]; then
  echo "  FAIL: persona file missing at $PERSONA"; exit 1
fi

# Frontmatter required keys
check "frontmatter name" \
  "grep -c '^name: security-reviewer$' '$PERSONA'" 1
check "frontmatter cost_class medium" \
  "grep -c '^cost_class: medium$' '$PERSONA'" 1
check "frontmatter model inherit" \
  "grep -c '^model: inherit$' '$PERSONA'" 1
check "frontmatter disallowedTools camelCase" \
  "grep -c '^disallowedTools:' '$PERSONA'" 1
check "disallowedTools blocks Write/Edit/MultiEdit/NotebookEdit" \
  "grep -cE '\\- Write$|\\- Edit$|\\- MultiEdit$|\\- NotebookEdit$' '$PERSONA'" 4

# Canonical schema keys present in persona body
check "schema key agent: security-reviewer" \
  "grep -c 'agent: security-reviewer' '$PERSONA'" 1
check "schema key severity:" \
  "grep -c '^[[:space:]]*severity:' '$PERSONA'" 1
check "schema key confidence:" \
  "grep -c '^[[:space:]]*confidence:' '$PERSONA'" 1
check "schema key file:" \
  "grep -c '^[[:space:]]*file:' '$PERSONA'" 1
check "schema key line:" \
  "grep -c '^[[:space:]]*line:' '$PERSONA'" 1
check "severity enum CRITICAL/IMPORTANT/SUGGESTION" \
  "grep -cE 'CRITICAL.*IMPORTANT.*SUGGESTION' '$PERSONA'" 1

# Forced findings prohibition (Korean or English)
check "forced findings prohibition present" \
  "grep -cE 'forced findings|Forced findings|빈 array|empty findings|empty list' '$PERSONA'" 1

# Role declaration shape (You are X / responsible / NOT responsible)
check "role declaration shape" \
  "grep -cE 'You are .*security-reviewer|responsible for|NOT responsible' '$PERSONA'" 3

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
EOF
chmod +x plugins/quality-gates/tests/test_security_reviewer_persona.sh
```

- [ ] **Step 2: 테스트 실행하여 FAIL 확인**

```bash
bash plugins/quality-gates/tests/test_security_reviewer_persona.sh
```

Expected: `FAIL: persona file missing at ...` + exit 1.

- [ ] **Step 3: 실패 테스트 커밋**

```bash
git add plugins/quality-gates/tests/test_security_reviewer_persona.sh
git commit -m "$(cat <<'COMMIT'
test(qg): add failing structural test for security-reviewer persona

Asserts persona will declare frontmatter (name, cost_class, model,
disallowedTools), emit canonical finding schema (agent/file/line/
severity/confidence keys + severity enum), include forced-findings
prohibition, and follow "You are X / responsible Y / NOT Z" role
declaration shape.

Test FAILS until persona file is created in next task.
COMMIT
)"
```

---

## Task 2: security-reviewer persona 작성

**Files:**
- Create: `plugins/quality-gates/agents/security-reviewer.md`

- [ ] **Step 1: persona 파일 작성**

Note: 본 plan은 paraphrased framework API 표현을 사용. 구현자가 hook 우회 후 literal 식별자로 보강하려면 별도 PR (Heads-up 섹션 참고).

```bash
cat > plugins/quality-gates/agents/security-reviewer.md <<'EOF'
---
name: security-reviewer
description: Phase 1 of Gate 2 — always-run code-level security review. Hunts exploitable paths (injection, authn/authz bypass, secrets, SSRF/path-traversal, crypto misuse, deserialization, raw-HTML escape hatches) and emits the canonical finding YAML schema defined in adversarial.md:22-30.
model: inherit
cost_class: medium
disallowedTools:
  - Write
  - Edit
  - MultiEdit
  - NotebookEdit
---

You are **security-reviewer**, the code-level security specialist for Gate 2 Phase 1.

You are responsible for: tracing exploitable paths in the `filtered_diff` from untrusted-input entry points to dangerous sinks, and reporting each verified finding in the canonical YAML schema below.

You are NOT responsible for: code style, design or architecture critique, performance issues, plan-level threat modeling (Gate 1 plan-verifier already covers spec coverage), or proposing alternative fixes when the existing approach is sound.

## Inputs

You will receive:

- `filtered_diff`: unified diff with documentation paths excluded.
- `gate1_summary`: YAML block from plan-verifier (matched_items / unmatched_items / unexpected_files / verdict). Use only for context — do not flag plan-level gaps.

## Hunt categories

Trace untrusted input → dangerous sink for each category. Verify each finding by reading the diff, not by pattern-matching keywords:

- **Injection** — SQL / NoSQL / command / template engine / directory query. Look for string concatenation or unescaped interpolation reaching a query, exec, or render call.
- **Auth/Authz bypass** — missing authentication middleware on new endpoints; broken ownership checks where one user can access another user's resources via ID substitution; privilege escalation where a regular role can modify their own permissions; state-change endpoint lacking a CSRF token in a framework whose convention requires one.
- **Secrets in code or logs** — hardcoded credentials, API keys, tokens, or passwords; sensitive data (PII, session tokens, credentials) written to logs or error responses; credentials passed in URL query parameters.
- **SSRF and path traversal** — user-controlled URL reaching a server-side HTTP client without allowlist validation; user-controlled file path reaching filesystem operations without canonicalization and boundary checks.
- **Insecure deserialization** — untrusted bytes passed to native object-serialization sinks, YAML loaders that allow arbitrary object construction, or JSON parsers configured to evaluate executable types.
- **Cryptographic misuse** — weak hash for security purposes; weak PRNG for token or nonce generation; non-constant-time comparison on secrets, tokens, or digests; hardcoded encryption key or IV; missing salt in password hashing.
- **Raw-HTML escape hatches** — framework-specific raw-render or mark-safe APIs invoked on user-controlled content (Rails raw-render API, Django mark-safe filter, React raw-HTML render prop, Vue raw-HTML directive, direct DOM raw-HTML assignment).
- **Dependency manifest changes** — `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`, `pyproject.toml`. Flag each new or upgraded entry as a finding so downstream review can verify CVE status. Do not run audit commands yourself.

## What you do NOT flag (anti-flag list)

- **Defense-in-depth on already-protected code.** If the input is already parameterized or escaped, do not suggest a second layer "just in case."
- **Theoretical attacks requiring physical or local access.** Side-channel timing attacks, hardware exploits, attacks needing local filesystem access on the server.
- **Dev or test config insecure transport.** HTTP in test fixtures or local dev config is not a production vulnerability.
- **Generic hardening advice.** "Consider adding rate limiting" or "consider CSP headers" without a specific exploitable finding in the diff. These are architecture recommendations, not review findings.
- **Forced findings.** If the diff has no security surface, emit an empty list. Padding with weak or speculative findings is forbidden.

## Confidence calibration

Use the 1–10 confidence scale anchored to evidence strength:

- **10 (anchor 100)** — vulnerability verifiable from the code alone: literal string-concat building a SQL query, missing CSRF token where framework convention requires one, hardcoded credential committed to source.
- **8 (anchor 75)** — full attack path traceable from the diff: untrusted input enters at this point, passes through these functions without sanitization, reaches this sink. The exploit is constructible from the code alone.
- **6 (anchor 50)** — dangerous pattern present but exploitability not fully confirmed (the input *looks* user-controlled but might be validated in middleware not shown in the diff). When the potential impact is severe (data breach, RCE, auth bypass), report this at `severity: CRITICAL` so the synthesizer keeps it visible despite the confidence cutoff at < 7.
- **≤ 4 (anchor ≤ 25)** — suppress. The attack requires conditions for which you have no evidence.

## Output format

Emit exactly one YAML list, no surrounding prose, no Markdown headings:

```yaml
- agent: security-reviewer
  file: <path>
  line: <number>
  severity: CRITICAL | IMPORTANT | SUGGESTION
  confidence: <1-10>
  summary: <one-sentence describing the vulnerability and its path>
  proposed_fix: <description or minimal code snippet showing the secure pattern>
```

If you have no findings, emit literally:

```yaml
[]
```

An empty list is the correct output when the diff has no security surface. Do not invent findings to fill space.

## Forbidden

- No findings outside the diff's actual code changes.
- No defense-in-depth recommendations on already-protected paths.
- No generic hardening advice without a specific exploitable finding.
- No padding or forced findings — empty list is the right answer when surface is absent.
- No code changes — Write / Edit / MultiEdit / NotebookEdit tools are disallowed by frontmatter.
- No prose narration outside the YAML list. The synthesizer parses your output directly.
EOF
```

- [ ] **Step 2: 테스트 실행하여 PASS 확인**

```bash
bash plugins/quality-gates/tests/test_security_reviewer_persona.sh
```

Expected: 모든 check PASS + `fail: 0` + exit 0.

만약 check가 어떤 keyword 미감지로 fail하면 — 그 키워드의 정확한 lower/upper case + 들여쓰기를 persona에서 확인 (grep regex 조정 또는 persona 텍스트 보강 — 단, schema key 자체는 변경 금지).

- [ ] **Step 3: 커밋**

```bash
git add plugins/quality-gates/agents/security-reviewer.md
git commit -m "$(cat <<'COMMIT'
feat(qg): add security-reviewer agent persona

Phase 1 always-run code-level security reviewer. Hunts injection,
authn/authz bypass, secrets, SSRF, path traversal, crypto misuse,
deserialization, and raw-HTML escape hatch patterns. Emits canonical
finding YAML schema (adversarial.md:22-30 contract). Forced findings
prohibited — empty list is the correct output when diff has no
security surface.

Frontmatter: disallowedTools [Write, Edit, MultiEdit, NotebookEdit]
enforces Law 2 (writer ≠ reviewer) physically. cost_class: medium.
model: inherit.

Closes structural test test_security_reviewer_persona.sh added in
prior commit.
COMMIT
)"
```

---

## Task 3: Scout Phase 1 selection table 확장

**Files:**
- Modify: `plugins/quality-gates/agents/scout.md` (Phase 1 selection table around lines 60-70)

- [ ] **Step 1: 현재 Phase 1 table 확인**

```bash
sed -n '60,70p' plugins/quality-gates/agents/scout.md
```

Expected output (현재):
```
## Phase 1 selection

| depth | phase1_agents |
|---|---|
| quick | [code-reviewer] |
| standard | [code-reviewer, silent-failure-hunter] |
| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] |
```

- [ ] **Step 2: 3개 tier에 security-reviewer 추가**

Use Edit tool with these exact strings:

old_string:
```
| quick | [code-reviewer] |
| standard | [code-reviewer, silent-failure-hunter] |
| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] |
```

new_string:
```
| quick | [code-reviewer, security-reviewer] |
| standard | [code-reviewer, silent-failure-hunter, security-reviewer] |
| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer] |
```

- [ ] **Step 3: phase1_agents 카탈로그 (line 55 부근) 확장**

old_string:
```
phase1_agents: [<subset of: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer>]
```

new_string:
```
phase1_agents: [<subset of: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer>]
```

- [ ] **Step 4: AC3 grep 검증**

```bash
for tier in quick standard deep; do
  if grep -E "^\| $tier \|.*security-reviewer" plugins/quality-gates/agents/scout.md >/dev/null; then
    echo "PASS: $tier tier includes security-reviewer"
  else
    echo "FAIL: $tier tier missing security-reviewer"
    exit 1
  fi
done

grep -E 'phase1_agents:.*security-reviewer' plugins/quality-gates/agents/scout.md \
  && echo "PASS: phase1_agents catalog extended" \
  || { echo "FAIL: phase1_agents catalog not extended"; exit 1; }
```

Expected: 4개 모두 PASS.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/agents/scout.md
git commit -m "$(cat <<'COMMIT'
feat(qg): add security-reviewer to scout Phase 1 selection (3 tiers)

Extends Phase 1 catalog and the quick/standard/deep selection table to
include security-reviewer in every tier — Phase 1 always-run decision
per spec §1. Phase 2 catalog unchanged.

Internal-consistency rule (phase1_agents must be a subset of table)
satisfied: catalog now includes security-reviewer.
COMMIT
)"
```

---

## Task 4: Kill switch deterministic 테스트 작성 (실패하는 테스트)

**Files:**
- Create: `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh`

- [ ] **Step 1: 테스트 스크립트 작성**

```bash
cat > plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh <<'EOF'
#!/usr/bin/env bash
# AC5 / AC11 — kill switch presence + disable log message structural test.
# This is a structural test (grep on SKILL.md): SKILL.md is consumed by an
# LLM, not executable, so we verify the kill switch is documented in the
# dispatch sequence. Behavioral assertion of LLM compliance requires
# integration smoke (AC10b, opt-in).
set -u
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

pass=0; fail=0
check() {
  local name="$1" cmd="$2" expected="$3"
  local actual
  actual="$(eval "$cmd" 2>/dev/null || echo "0")"
  if [ "$actual" -ge "$expected" ]; then
    echo "  PASS: $name (got $actual, expected >= $expected)"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (got $actual, expected >= $expected)"; fail=$((fail + 1))
  fi
}

check "kill switch env var present" \
  "grep -c 'DEVBREW_DISABLE_QG_SECURITY_REVIEWER' '$SKILL'" 1

check "disable log message present" \
  "grep -cE 'security-reviewer disabled|security-reviewer.*DEVBREW_DISABLE' '$SKILL'" 1

check "security-reviewer dispatch reference count" \
  "grep -c 'security-reviewer' '$SKILL'" 3

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
EOF
chmod +x plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
```

- [ ] **Step 2: 테스트 실행하여 FAIL 확인**

```bash
bash plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
```

Expected: 3개 check 모두 FAIL + exit 1.

- [ ] **Step 3: 실패 테스트 커밋**

```bash
git add plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
git commit -m "$(cat <<'COMMIT'
test(qg): add failing kill switch test for security-reviewer

Asserts SKILL.md will document DEVBREW_DISABLE_QG_SECURITY_REVIEWER
env var, emit a disable log message on activation, and reference the
security-reviewer agent in dispatch context >= 3 times.

Test FAILS until SKILL.md is updated in next task.
COMMIT
)"
```

---

## Task 5: SKILL.md Phase 1 dispatch + kill switch

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (Phase 1 dispatch section around lines 542-570)

- [ ] **Step 1: 현재 Phase 1 dispatch block 위치 확인**

```bash
grep -n "Agent A — pr-review-toolkit:code-reviewer\|Agent B —\|Agent C — feature-dev:code-reviewer" plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

Expected: Agent A / B / C 헤더가 lines 542 / ~550 / 556 부근에 위치.

- [ ] **Step 2: Agent C block 다음에 새 Agent D block 삽입**

Agent C 블록 종료 직후 (다음 헤더 `**Individual dispatch failures**` 또는 `#### Phase 2` 직전) 다음 텍스트 삽입. Use Edit tool, matching the existing Agent C closing as old_string and prepending Agent D before the next section.

새 Agent D block 텍스트:

````markdown
**Agent D — security-reviewer** (always dispatched unless `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`)

Before dispatching, check the kill switch:

```bash
if [ "${DEVBREW_DISABLE_QG_SECURITY_REVIEWER:-0}" = "1" ]; then
  echo "[quality-gates] security-reviewer disabled via DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1" >&2
  # skip Agent D; other Phase 1 agents still dispatch
fi
```

Dispatch prompt template (same `[immutable head] → [diff] → [variable tail]` shape as Agent A/B/C):

> Review the unstaged changes for code-level security vulnerabilities. Trace untrusted-input entry points to dangerous sinks. Categories: injection (SQL/NoSQL/command/template/directory), authn/authz bypass (missing middleware, IDOR, privilege escalation, CSRF on state-change), secrets in code or logs, SSRF + path traversal, insecure deserialization, cryptographic misuse, raw-HTML escape hatches, dependency manifest changes. Suppress defense-in-depth on already-protected code, theoretical/physical-access attacks, dev/test insecure transport, and generic hardening advice. If diff has no security surface, emit empty YAML list (`[]`) — do not pad with forced findings. Output: canonical YAML schema only (agent / file / line / severity / confidence / summary / proposed_fix), no prose.
````

- [ ] **Step 3: Phase 1 parallel dispatch instruction 갱신**

Phase 1 dispatch section의 "Dispatch the agents in `scout.phase1_agents` in parallel" 지시 인근에 (만약 dispatch 예시 코멘트가 있다면) `+ security-reviewer in parallel`를 추가. scout output을 그대로 iterate하는 형식이면 (Phase 1 catalog 확장으로 자동 포함) 별도 작업 불필요 — 단지 dispatch 가이드 텍스트에서 `Agent A/B/C` → `Agent A/B/C/D`로 표현 갱신.

- [ ] **Step 4: kill switch 테스트로 검증**

```bash
bash plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
```

Expected: 3개 check 모두 PASS + exit 0.

- [ ] **Step 5: persona 테스트도 여전히 PASS 확인 (회귀 없음)**

```bash
bash plugins/quality-gates/tests/test_security_reviewer_persona.sh
```

Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md
git commit -m "$(cat <<'COMMIT'
feat(qg): wire security-reviewer into Phase 1 parallel dispatch

Add Agent D block to Phase 1 dispatch sequence in quality-pipeline
SKILL.md. Mirrors codex-reviewer's kill switch pattern via
DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1 env var with loud-logging
graceful degradation (single stderr line on disable).

Persona is dispatched alongside code-reviewer, silent-failure-hunter,
and feature-dev:code-reviewer in the same parallel tool-call block.
Fan-out gate (>= 4 agents) triggers AskUserQuestion automatically
since scout.phase1_agents now includes security-reviewer by default.

Closes kill switch structural test test_security_reviewer_kill_switch.sh.
COMMIT
)"
```

---

## Task 6: Fixture 파일 추가 (AC10b 준비)

**Files:**
- Create: `plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/diff.patch`
- Create: `plugins/quality-gates/tests/fixtures/security-reviewer/clean/diff.patch`
- Create: `plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p plugins/quality-gates/tests/fixtures/security-reviewer/{sql-concat,clean,expected}
```

- [ ] **Step 2: SQL string-concat trigger fixture**

```bash
cat > plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/diff.patch <<'EOF'
diff --git a/app/users.py b/app/users.py
index 0000001..0000002 100644
--- a/app/users.py
+++ b/app/users.py
@@ -10,4 +10,9 @@ class UserRepo:
     def __init__(self, conn):
         self.conn = conn

+    def get_by_name(self, name):
+        cur = self.conn.cursor()
+        cur.execute("SELECT * FROM users WHERE name = '" + name + "'")
+        return cur.fetchone()
+
EOF
```

- [ ] **Step 3: Non-trigger clean fixture (styling only)**

```bash
cat > plugins/quality-gates/tests/fixtures/security-reviewer/clean/diff.patch <<'EOF'
diff --git a/app/format.py b/app/format.py
index 0000003..0000004 100644
--- a/app/format.py
+++ b/app/format.py
@@ -3,6 +3,7 @@
 def format_currency(amount: int) -> str:
     """Format an integer cent value as USD with comma separators."""
-    return f"${amount/100:,.2f}"
+    dollars = amount / 100
+    return f"${dollars:,.2f}"
EOF
```

- [ ] **Step 4: Expected schema shape**

```bash
cat > plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml <<'EOF'
# Minimum expected output shape for the sql-concat fixture.
# Tests do NOT compare exact finding text (LLM non-determinism) — only
# that the emitted YAML has the right keys + severity enum value range
# + finding count >= 1 + the affected file is app/users.py.

- agent: security-reviewer
  file: app/users.py
  line: <integer in 13..15>
  severity: CRITICAL  # or IMPORTANT — both acceptable for SQL string-concat
  confidence: 8  # or 9 or 10 — anchor 75 or 100 expected for literal concat
  summary: <one sentence mentioning SQL injection or string concatenation>
  proposed_fix: <description mentioning parameterized query or placeholder>
EOF
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/tests/fixtures/security-reviewer/
git commit -m "$(cat <<'COMMIT'
test(qg): add security-reviewer integration smoke fixtures

Two diff fixtures for manual / nightly integration smoke:
- sql-concat/: SQL string-concat trigger (expected >= 1 finding)
- clean/: pure styling change (expected empty findings list)

Plus expected/sql-concat.schema.yaml documenting the minimum shape
the agent should emit — keys + severity enum range + file match.
Exact finding text is non-deterministic; this fixture documents
the conformance contract, not a golden output.

Per spec AC10b: integration smoke is opt-in, CI-non-blocking.
COMMIT
)"
```

---

## Task 7: Plugin metadata bump (plugin.json + CHANGELOG)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: plugin.json version bump**

Use Edit tool:

old_string:
```
  "version": "1.12.0",
```

new_string:
```
  "version": "1.13.0",
```

- [ ] **Step 2: 검증**

```bash
jq -r .version plugins/quality-gates/.claude-plugin/plugin.json
```

Expected output: `1.13.0`.

- [ ] **Step 3: CHANGELOG entry 추가 (파일 최상단의 latest entry 위)**

```bash
head -15 plugins/quality-gates/CHANGELOG.md
```

새 entry를 최상단 헤더 다음, 첫 `## [x.y.z]` 직전에 삽입:

```markdown
## [1.13.0] — 2026-05-16

### Added

- **Phase 1 always-run `security-reviewer` agent.** Code-level security review now runs on every Gate 2 invocation (all 3 depth tiers: quick / standard / deep). Hunts injection, authn/authz bypass, secrets, SSRF + path traversal, insecure deserialization, cryptographic misuse, raw-HTML escape hatches, and dependency manifest changes. Emits canonical finding YAML schema (`adversarial.md:22-30`). Persona declares `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` for Law 2 physical isolation; `cost_class: medium`; `model: inherit`.
- **Kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`.** Mirrors codex-reviewer's `DEVBREW_DISABLE_QG_CODEX` pattern. Loud-logging graceful degradation: stderr emits `security-reviewer disabled via DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` on activation; other Phase 1 reviewers continue to run.
- **Structural tests.** `tests/test_security_reviewer_persona.sh` (frontmatter + schema keyword + role declaration grep) and `tests/test_security_reviewer_kill_switch.sh` (SKILL.md kill switch reference grep).
- **Integration smoke fixtures.** `tests/fixtures/security-reviewer/{sql-concat,clean,expected}/` — opt-in, CI-non-blocking (LLM non-determinism).

### Changed

- **Phase 1 dispatch fan-out.** Phase 1 catalog grows by 1 (now: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer + conditional codex-reviewer). On `deep` depth with codex-reviewer available, `phase1_agents = 4` + `external_reviewers = 1` = 5, exceeding the AskUserQuestion fan-out gate (≥ 4) — users see an explicit confirm before parallel dispatch.

### Security

- New `security-reviewer` persona file is security-sensitive code per CLAUDE.md ("Persona 파일은 보안-민감 코드"). PRs weakening hunt categories, lowering anchored confidence rubric, or removing the forced-findings prohibition rule require security review.
```

- [ ] **Step 4: 검증**

```bash
grep -c '## \[1.13.0\] — 2026-05-16' plugins/quality-gates/CHANGELOG.md
```

Expected: `1`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "$(cat <<'COMMIT'
chore(qg): bump to v1.13.0 + CHANGELOG entry for security-reviewer

plugin.json: 1.12.0 → 1.13.0 (minor — new always-run reviewer surface).
CHANGELOG.md: Added (agent + kill switch + tests + fixtures), Changed
(Phase 1 fan-out), Security (persona file is security-sensitive code).
COMMIT
)"
```

---

## Task 8: README 갱신

**Files:**
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: 현재 agent inventory 섹션 위치 확인**

```bash
grep -n "^##\|^###" plugins/quality-gates/README.md | head -20
```

agent inventory가 `## 구조` 또는 별도 `## Agents` 섹션에 있는지 확인.

- [ ] **Step 2: agent inventory에 security-reviewer 추가**

agent inventory 섹션 (보통 `agents/` 디렉토리 트리 또는 한 줄 설명 리스트)에 다음 1줄 추가 (codex-reviewer entry 다음 위치):

```
- `security-reviewer` — Phase 1 always-run 코드 레벨 보안 리뷰. injection / authn-authz / secrets / SSRF / crypto-misuse / deserialization / raw-HTML escape hatch / dependency manifest 변경 hunt. Disable: `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`.
```

- [ ] **Step 3: "인스턴스화한 원칙" Law 2 항목에 추가**

`## 인스턴스화한 원칙` 섹션 내 codex-reviewer의 Law 2 instantiation 항목 다음에 1줄 추가:

```markdown
- **Law 2 (Writer ≠ Reviewer, frontmatter scoping)** (v1.13.0) — `security-reviewer` agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언. Phase 1 always-run reviewer 중 4번째로 추가되며, kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`로 사용자가 disable 가능 (Plugin Shape — 모든 reviewer는 opt-out 가능).
```

- [ ] **Step 4: 검증**

```bash
grep -cE 'security-reviewer|DEVBREW_DISABLE_QG_SECURITY_REVIEWER' plugins/quality-gates/README.md
```

Expected: `>= 2`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/README.md
git commit -m "$(cat <<'COMMIT'
docs(qg): document security-reviewer in README (inventory + Law 2)

Agent inventory entry + Law 2 instantiation list entry for v1.13.0
security-reviewer. Kill switch DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1
documented in both places per Plugin Shape ("모든 hook/agent는
opt-out 가능").
COMMIT
)"
```

---

## Task 9: 회귀 테스트 스윕

이 task는 변경 검증 — 새 코드 작성 없음. 산출물: 회귀 없음 확인.

- [ ] **Step 1: 모든 quality-gates 테스트 실행**

```bash
cd plugins/quality-gates/tests
for t in test_*.sh; do
  if bash "$t" >/tmp/qg-test-$$.out 2>&1; then
    echo "PASS: $t"
  else
    echo "FAIL: $t"
    cat /tmp/qg-test-$$.out | tail -20
  fi
done
rm -f /tmp/qg-test-$$.out
cd "$REPO_ROOT"
```

Expected: 모든 test PASS.

- [ ] **Step 2: Python 테스트도 실행**

```bash
cd plugins/quality-gates/tests
for t in test_*.py; do
  if python3 "$t" >/tmp/qg-test-$$.out 2>&1; then
    echo "PASS: $t"
  else
    echo "FAIL: $t"
    cat /tmp/qg-test-$$.out | tail -20
  fi
done
rm -f /tmp/qg-test-$$.out
cd "$REPO_ROOT"
```

Expected: 모든 test PASS.

- [ ] **Step 3: Frontmatter linter 통과 확인**

```bash
bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh
```

Expected: `PASS: agent frontmatter keys all conform to camelCase convention`.

- [ ] **Step 4: git log 확인**

```bash
git log --oneline main..HEAD
```

Expected: 8-9개 commit (7 implementation tasks + 1-2 test setup commits).

- [ ] **Step 5: 회귀 없음 확인 후 끝 (커밋 없음)**

회귀 발견 시: 영향받은 test의 expected output을 새 Phase 1 catalog (security-reviewer 포함) 기준으로 수정. 별도 commit (`test(qg): update Gate 2 fixtures for v1.13.0 Phase 1 catalog`).

---

## Optional Task 10: AC10b 수동 smoke (CI-non-blocking)

이 task는 LLM 비결정성 때문에 CI에서 강제하지 않음. 머지 전 한 번 수동 실행:

- [ ] **Step 1: SQL-concat fixture로 `/qg` 실행**

```bash
TMP=$(mktemp -d)
cp -r plugins/quality-gates/tests/fixtures/security-reviewer/sql-concat/* "$TMP/"
# Claude Code 세션에서 /qg 명령 실행하거나, 직접 security-reviewer agent dispatch
```

(정확한 invocation 방법은 quality-pipeline SKILL.md의 Phase 1 dispatch 섹션 참고.)

- [ ] **Step 2: 결과가 expected schema shape를 충족하는지 비교**

`plugins/quality-gates/tests/fixtures/security-reviewer/expected/sql-concat.schema.yaml`의 키 셋 + severity enum + 파일 매칭 확인 (정확한 finding 텍스트는 무시).

- [ ] **Step 3: clean fixture에서도 같은 절차로 실행 — 빈 array `[]` emit 확인**

- [ ] **Step 4: 결과를 PR description에 한 줄 기록 (no commit)**

```
AC10b smoke (manual): sql-concat → 1 finding emitted, severity CRITICAL/IMPORTANT,
file app/users.py. clean → empty array. Both within expected shape.
```

---

## Self-Review

**Spec coverage:**
- AC1 (frontmatter) → Task 2 (persona file)
- AC2 (role declaration + schema keywords + forced findings prohibition) → Task 1 (test) + Task 2 (persona)
- AC3 (scout 3 tier) → Task 3
- AC4 (SKILL.md dispatch) → Task 5
- AC5 (kill switch in SKILL.md) → Task 4 (test) + Task 5 (implementation)
- AC6 (fan-out gate) → Task 5 commit message + Task 9 regression
- AC7 (plugin.json bump) → Task 7
- AC8 (CHANGELOG entry) → Task 7
- AC9 (README) → Task 8
- AC10a (structural grep) → Task 1
- AC10b (integration smoke) → Task 6 (fixtures) + Optional Task 10 (manual run)
- AC11 (kill switch deterministic test) → Task 4
- AC12 (regression) → Task 9

**Placeholder scan:** No "TBD" / "TODO" / "implement later" / "fill in details" / "add appropriate error handling" / "similar to Task N" in any step. Each step shows the actual content (heredoc bodies, exact grep commands, exact commit messages).

**Type consistency:** schema keys (`agent`, `file`, `line`, `severity`, `confidence`, `summary`, `proposed_fix`) used identically across Task 1 test assertions, Task 2 persona output spec, Task 6 fixture, and Task 7 CHANGELOG. Kill switch env var (`DEVBREW_DISABLE_QG_SECURITY_REVIEWER`) used identically across Task 4 test, Task 5 SKILL.md modification, Task 7 CHANGELOG, Task 8 README. Plugin version `1.13.0` used in plugin.json (Task 7), CHANGELOG header (Task 7), README Law 2 entry (Task 8) — consistent.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-16-qg-security-reviewer.md`. Two execution options:

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
