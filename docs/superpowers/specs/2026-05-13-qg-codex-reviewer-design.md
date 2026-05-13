# QG Codex Reviewer — Design Spec

> **Status:** Draft v3 — revised after spec-reviewer rounds 1 + 2 (26 total issues addressed)
> **Author:** Jeongho-K (with Claude Opus 4.7)
> **Date:** 2026-05-13
> **Plugin:** `plugins/quality-gates`
> **Plugin bump:** `1.10.0 → 1.11.0` (minor — 새 reviewer surface 추가)
> **Branch:** `feature/qg-codex-reviewer`
> **Revision log:**
> - v1 → v2: switched core invocation from `codex exec --output-schema` to `codex exec --json` (JSONL streaming) per gstack reviewer precedent; added auth + version probes; tightened security model; replaced grep-based AC4 with multi-line aware verification; added cost ceiling, fan-out audit, concrete next action. (Round 1: 16 issues addressed.)
> - v2 → v3: added prompt-engineering spike as Step 0 (NEW-1); added stderr capture `2>"$TMPERR"` + auth-error AC5 mock (NEW-2); added Non-goal "no web_search_cached" (NEW-3); added `-C "$_REPO_ROOT"` to all invocations (NEW-4); added AC5 mock `valid-json-no-fence` + parser fallback chain (NEW-5); canonicalized `-s read-only` (NEW-6); timeout 330s → 600s with correct `codex exec --json` precedent (NEW-7); added §10 Open Questions section (NEW-8); added `tests/test-cost-consent.sh` + concrete AC10 verification (NEW-9); removed `Bash(cat *)` from allowlist — parser reads stdin from pipe (NEW-10).

## 1. Context / Why

QG의 3개 게이트는 모두 reviewer agent를 dispatch한다 — Gate 1의 plan-verifier, Gate 2의 scout / code-reviewer / silent-failure-hunter / feature-dev:code-reviewer / adversarial / synthesizer, Gate 3의 runtime-verifier / test-scope-validator. 전부 같은 Anthropic 모델 family에서 도는 subagent다.

Law 2 — "writer와 reviewer는 같은 pass를 공유 못 한다" — 는 `disallowedTools` frontmatter로 물리적으로 강제된다. 그러나 **모델 family 단일성**은 남아 있는 약점이다. 동일 family의 reviewer들은 pattern-matching 누락이 상관(correlated)될 수 있다.

Codex CLI(OpenAI 계열 모델)가 시스템에 설치되어 있으면 OS 프로세스 분리 + 모델 family 분리라는 진짜 독립 의견을 얻을 수 있다. devbrew Law 2 정신을 한 단계 더 밀어 "프롬프트가 아니라 물리"에서 "프롬프트 ≠ 도구 ≠ OS 프로세스 ≠ 모델 family"로 확장한다.

**Reference 패턴 — 검증된 invocation:**

- `reference/gstack/codex/SKILL.md:1153, 1302, 1350` — gstack의 codex challenge / consult / resume reviewer 모드. 패턴:
  ```bash
  _gstack_codex_timeout_wrapper 600 codex exec "<prompt>" -C "$_REPO_ROOT" \
    -s read-only -c 'model_reasoning_effort="high"' \
    --enable web_search_cached --json < /dev/null \
    | PYTHONUNBUFFERED=1 python3 -u -c "..."
  ```
  핵심: `codex exec` + `-s read-only` sandbox + `--json` JSONL streaming + Python으로 reasoning trace와 final agent message 추출.

- `reference/gstack/bin/gstack-codex-*`:
  - `_gstack_codex_version_check` — known-bad version 가드. 정규식: `(^|[^0-9.])0\.120\.(0|1|2)([^0-9.]|$)` (stdin deadlock bug).
  - `_gstack_codex_timeout_wrapper` — gtimeout / timeout fallback 체인.
  - `_gstack_codex_auth_probe` — `$CODEX_API_KEY`, `$OPENAI_API_KEY`, `~/.codex/auth.json` 중 하나 필요.

- `reference/compound-engineering-plugin/.../codex-delegation-workflow.md` — CE는 `codex exec --output-schema` 패턴을 *writer 위임*에 사용 (status/files_modified 같은 *완료 contract*). **이 패턴은 reviewer per-finding 출력에는 검증된 적 없음.** 따라서 본 spec은 CE 위임 패턴이 아니라 gstack reviewer 패턴을 따른다.

## 2. Goals

1. Codex CLI 가용성 + 인증 + 버전 안전성을 한 probe로 확인한다.
2. Probe 통과 시 Gate 2 Phase 1에 `codex-reviewer` agent를 추가 dispatch한다.
3. Codex 출력 (JSONL stream의 final agent message)에서 finding을 추출, 기존 reviewer와 동일 YAML schema로 정규화한다.
4. Codex 호출은 `-s read-only` sandbox + outer agent의 `Bash` allowlist로 격리된다 (2중 격리).
5. 실패 모드는 모두 graceful — 다른 reviewer 영향 없음, synthesizer 입력 형식 보존.
6. Codex 비용은 사용자가 명시적으로 인지/제한할 수 있다 (cost ceiling 또는 first-use 경고).

## 3. Non-goals

- **Codex로 코드 *작성* 안 함** — QG는 review pipeline, writer delegation은 ce-work-beta 영역.
- **Codex가 working tree mutate 안 함** — `-s read-only` sandbox.
- **기존 Claude reviewer 대체 안 함** — 추가 reviewer로만, 비용 최적화 아님.
- **Gate 1 / Gate 3 변경 안 함** — Gate 1은 plan↔diff 단순 매칭, Gate 3는 MCP 기반.
- **`codex review` subcommand 사용 안 함** — 출력이 freeform 텍스트라 finding YAML 정규화 어려움. `codex exec --json`이 stream에서 structured extraction 가능.
- **`codex exec --output-schema` 사용 안 함** — CE 위임 패턴, reviewer per-finding 출력에 검증된 precedent 없음. gstack의 `--json` JSONL이 검증된 reviewer 패턴.
- **`--enable web_search_cached` 사용 안 함** — QG는 working-tree-scoped review. 외부 web search는 review 품질에 추가 가치 미미하며 latency + cost 증가. 명시적 제외 (§4.3 canonical invocation에 포함 안 함).
- **Prompt-engineering 가정을 validated pattern으로 표기하지 않음** — Codex가 `agent_message`에서 fenced JSON code block을 emit하는 행동은 gstack에서 검증된 적 없는 prompt-engineering 영역. §9 Step 0 spike로 *empirically* 검증 후 구현 진행 — 검증 실패 시 spec revision 필요.

## 4. Constraints

### 4.1 devbrew 철학

- **Law 1.** 본 spec이 9개 필수 섹션 (Context, Goals, Non-goals, Constraints, AC, Files, Verification, Rejected, Metadata) + Concrete Next Action 보강.
- **Law 2 — 3중 격리:**
  1. `codex-reviewer.md` frontmatter: `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]` (Write 류 도구 차단)
  2. `codex-reviewer.md` frontmatter: `allowed-tools` 명시 — AC11이 binding 정의. outer Bash가 shell redirection으로 파일에 못 쓰도록 패턴 화이트리스트. (`Bash(cat *)`는 redirection 우회 가능해서 제외 — AC11 NEW-10 note 참조.)
  3. Codex subprocess 자체: `-s read-only` OS sandbox
  > **명시:** sandbox `-s read-only`는 Codex의 *agent loop*가 쓰는 걸 막는다. Outer Claude Code agent의 Bash는 그 sandbox 안에 있지 않다. 두 layer 모두 필요하며 어느 한 쪽도 다른 쪽을 substitute하지 않는다.
- **Law 3.** Spec → plan → 구현 사이클 후 `plugin.json` bump + CHANGELOG entry + README "Principles Instantiated" — 자동 compounding.

### 4.2 Plugin shape

- `codex-reviewer.md` frontmatter: `cost_class: variable`, `allowed-tools` 화이트리스트 명시.
- Kill switch: `DEVBREW_DISABLE_QG_CODEX=1`.
- Markdown state (스크래치는 OS temp).
- Graceful degradation with loud logging.
- 새 P# 추가 없음 — Law 2의 instantiation 강화일 뿐 직교 원칙 아님.

### 4.3 보안

- Codex 호출은 **항상** 다음 정규 형태 (canonical invocation, 한 곳에서 정의 후 spec 전체 참조):
  ```bash
  gtimeout 600 codex exec "<prompt>" \
    -C "$_REPO_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null 2>"$TMPERR" \
    | python3 scripts/codex-findings-to-yaml.py
  ```
  핵심 플래그:
  - `-s read-only` (short form, **canonical**) — sandbox 모드. spec 전체에서 `--sandbox` 대신 `-s` 사용.
  - `-C "$_REPO_ROOT"` — working directory pin. QG pipeline의 CWD가 repo root가 아닐 수 있어 필수.
  - `--json` — JSONL stream 출력 (gstack `codex exec` precedent, lines 1153/1302/1350).
  - `< /dev/null` — stdin 닫음 (gstack pattern; codex가 stdin을 읽지 않게 함, deadlock 회피).
  - `2>"$TMPERR"` — stderr 캡처. Auth 오류는 stderr로 나오므로 exit 0이어도 `$TMPERR` 파싱 필요.
  - `gtimeout 600` — 600s wall-clock 한도. **gstack `codex exec --json` precedent**: challenge/consult 모드 line 1153/1302/1350 모두 600s 사용. (v2 원안 330s는 `codex review` precedent였으나 `codex review`는 §3에서 거부된 패턴 — 잘못된 precedent 인용이었음.)
  - **명시적 비채택:** `--enable web_search_cached` — gstack codex exec 인보케이션에 있지만 QG는 read-only 코드 review이므로 외부 web search 불필요. Latency/cost 절감 위해 제외 (§3 Non-goal 7).
- Recursion guard: `CODEX_SANDBOX` 또는 `CODEX_SESSION_ID` env set → probe `false` emit.
- Persona 파일 (`codex-reviewer.md`)은 security-critical: sandbox/allowlist/timeout 약화 PR은 보안 리뷰 대상.

### 4.4 비용

- `cost_class: variable` — 사용자의 Codex 구독/API 종량제에 따라 다름.
- **First-use cost gate:** `~/.claude/quality-gates/codex-cost-consent.md`에 consent record 없으면 첫 호출 전 `AskUserQuestion`으로 사용자 동의 요구. 동의 시 marker 파일 작성, 이후 silent.
- Per-run hard ceiling: §4.3 canonical의 `gtimeout 600` 자체가 비용 ceiling proxy (단일 호출 시간 한도 = 비용 한도 근사). 명시적 토큰 cap은 §10 OQ-1 (codex CLI 지원 여부 미확정) — Step 0 spike에서 확인 후 발견 시 amendment.
- `quick` depth는 skip — 작은 diff에 codex 호출은 trivia ceremony (forbidden pattern).

### 4.5 Fan-out audit

QG는 이미 fan-out ≥ 5 regime (Phase 2 deep 단독으로 5 agent 가능). `codex-reviewer` 추가로 Phase 1 deep은 3 → 4 (still <5). Gate 2 전체 max dispatch 11 → 12 (선언된 hard review gate 안에 있음, CLAUDE.md plugin shape 조항). 추가 escalation 없음, 단 README "Fan-out" 섹션에 12로 갱신.

## 5. Acceptance Criteria

### AC1 — Probe correctness (6 cases)

`bash scripts/detect-codex.sh`가 다음 6가지 case에서 정확한 YAML emit. 각 case는 verification script `tests/test-detect-codex.sh`로 자동 검증:

| # | 환경 | Emit |
|---|---|---|
| 1 | Codex 미설치 (`command -v codex` 빈 출력) | `codex_available: false`<br>`skip_reason: not_installed` |
| 2 | Codex 설치 + 인증 + 안전 버전 | `codex_available: true`<br>`codex_path: <absolute>`<br>`codex_version: <string>` |
| 3 | Kill switch (`DEVBREW_DISABLE_QG_CODEX=1`) | `codex_available: false`<br>`skip_reason: kill_switch` |
| 4 | 이미 codex 안 (`CODEX_SANDBOX=1` 또는 `CODEX_SESSION_ID=...`) | `codex_available: false`<br>`skip_reason: inside_codex_sandbox` |
| 5 | 인증 없음 (`$CODEX_API_KEY` / `$OPENAI_API_KEY` / `~/.codex/auth.json` 모두 부재) | `codex_available: false`<br>`skip_reason: auth_missing` |
| 6 | 알려진 bad version (regex `(^\|[^0-9.])0\.120\.(0\|1\|2)([^0-9.]\|$)` 매칭) | `codex_available: false`<br>`skip_reason: known_bad_version`<br>`detected_version: <string>` |

### AC2 — Scout 통합

Scout이 `codex_manifest` block을 dispatch prompt 입력으로 받고:
- `codex_available: true` AND depth ∈ {standard, deep} → `phase1_agents`에 `codex-reviewer` 포함
- `codex_available: false` OR depth = quick → 미포함

`tests/test-scout-integration.sh`로 합성된 codex_manifest 4 case (true/standard, true/quick, false/standard, true/deep) 검증.

### AC3 — Codex-reviewer 출력 schema

Agent 출력은 Phase 1 reviewer와 동일 YAML 구조:

```yaml
- agent: codex-reviewer
  file: <path>
  line: <number>
  severity: CRITICAL | IMPORTANT | SUGGESTION
  confidence: <1-10>
  summary: <one sentence>
  proposed_fix: <string>
```

추가로 마지막에 meta block:

```yaml
meta:
  codex_version: <string>
  codex_runtime_ms: <int>
  codex_failed: false
```

JSONL parser (`codex-findings-to-yaml.py`)는 다음 입력 형식을 받음:

- **Input (stdin):** Codex JSONL stream — 각 line이 `{"type": "...", "delta": "...", ...}` 형태 event. 종결은 `agent_message` 또는 `task_complete` event.
- **추출 (3-stage fallback chain):** 마지막 `agent_message` event의 `text` 필드에 대해 순차 시도:
  1. **Stage 1 — Fenced JSON.** ```` ```json ... ``` ```` 블록 추출 후 `findings` array 파싱.
  2. **Stage 2 — Raw JSON.** Stage 1 실패 시 text 전체를 JSON으로 파싱 시도 (모델이 fence 없이 raw object 반환한 경우).
  3. **Stage 3 — Fallback.** Stage 1/2 모두 실패 → `findings: []` + `meta.reason: malformed_json` + `meta.raw_text_preview: <first 200 chars>`.
- **stderr capture:** `$TMPERR` 파일을 같이 받아서, exit 0이어도 stderr에 `Error: ` / `auth` / `authentication` 패턴이 있으면 `meta.reason: auth_error_in_stderr` (Codex CLI는 auth 실패를 stderr + exit 0로 내는 경우 존재).
- **Output (stdout):** 위 YAML 형식.

### AC4 — Sandbox 강제 (정적 검증)

`codex-reviewer.md` 본문의 모든 `codex exec` invocation이 `-s read-only`를 동반함을 정적으로 검증.

검증 명령 (`tests/test-sandbox-enforced.sh`):

```bash
# Extract every shell block, find codex exec lines, verify each has -s read-only
# in same block. Multi-line invocations with backslash continuation are
# normalized to one logical line first.
python3 tests/lib/extract-codex-invocations.py agents/codex-reviewer.md \
  | grep -v -E '(-s|--sandbox)[[:space:]]+read-only' \
  | (! grep -q .)  # exit 0 only if no offending lines
```

Helper script가 backslash-continuation을 한 줄로 normalize 후 grep. 단순 line grep 대신.

### AC5 — Graceful failure (concrete tests)

다음 6가지 실패 case 각각에 대해 mock codex binary + verification:

| Failure | Mock | Expected |
|---|---|---|
| exit ≠ 0 | `mock-codex-exit1.sh` (즉시 exit 1) | Agent emits `findings: []`, `meta.codex_failed: true`, `meta.reason: exit_nonzero`, `meta.exit_code: 1` |
| Timeout | `mock-codex-hang.sh` (sleep 700) | gtimeout fires after 600s, agent emits `findings: []`, `meta.reason: timeout`, `meta.exit_code: 124` |
| Malformed JSON | `mock-codex-bad-json.sh` (random bytes) | Agent emits `findings: []`, `meta.reason: malformed_json`, `meta.exit_code: 0`, `meta.raw_text_preview: <preview>` |
| Missing final message | `mock-codex-no-agent-message.sh` (이벤트 없이 exit 0) | Agent emits `findings: []`, `meta.reason: missing_result`, `meta.exit_code: 0` |
| Valid JSON without fence | `mock-codex-valid-json-no-fence.sh` (raw JSON object in agent_message, no ```` ```json ``` ```` wrap) | Parser Stage 2 fallback 성공 — Agent emits parsed `findings: [...]`, `meta.reason` 없음 (정상 처리) |
| Auth error in stderr (exit 0) | `mock-codex-auth-stderr.sh` (stderr: `Error: authentication failed`, stdout: empty, exit 0) | Agent emits `findings: []`, `meta.reason: auth_error_in_stderr`, `meta.exit_code: 0`, `meta.stderr_preview: <preview>` |

**Downstream impact 검증:** 각 case에서 captured synthesizer 입력에 codex의 `findings: []`가 다른 reviewer findings를 영향 주지 않음을 assert:
```bash
# Run failure case + non-codex reviewer mock, capture synthesizer input
diff <(./run-qg-with-codex-failure.sh | extract-synthesizer-input) \
     <(./run-qg-without-codex.sh | extract-synthesizer-input)
# Expected: identical except for added codex meta block
```

### AC6 — Kill switch

`DEVBREW_DISABLE_QG_CODEX=1 /qg` 실행 시 scout 출력 YAML의 `phase1_agents`에 `codex-reviewer` 부재.

### AC7 — Backward compatibility (with precursor)

**Precursor task (AC7 활성화 전 1회 실행):** Codex 미설치 환경에서 `/qg`를 3개 합성 PR (small/medium/large diff)에 실행 → synthesizer 출력 YAML을 baseline fixture로 `tests/fixtures/baseline-synthesizer-{small,medium,large}.yaml`에 저장.

**AC7 자체:** Codex 미설치 환경에서 같은 3개 PR에 `/qg` 재실행 → 출력이 baseline과 byte-identical (단, timestamp/session_id 등 비결정적 필드는 normalize). `git diff` 기반 검증.

baseline 부재 시 AC7는 "aspirational — baseline must be captured first"로 표기.

### AC8 — Plugin shape compliance

- `plugin.json`: `version: "1.10.0" → "1.11.0"` 변경 검증 (`jq -r .version < plugin.json`)
- `CHANGELOG.md`: `## [1.11.0] — 2026-05-13` 섹션 존재 + Added/Changed 하위 항목 grep 확인
- `README.md`: "Principles Instantiated" 섹션에 Law 2 강화 한 줄 추가 + "Fan-out" 섹션 12로 갱신 + cost 섹션에 `variable` 명시 — 각각 grep 확인

### AC9 — Persona 격리 (3 layer)

`codex-reviewer.md` frontmatter + 본문에 3 layer 격리 모두 존재:
1. `disallowedTools` 라인에 `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, `Glob` 모두 포함
2. `allowed-tools` 라인이 `Bash(...)` 패턴 화이트리스트로 narrow (단순 `Bash` 아님)
3. 본문의 모든 `codex exec` invocation에 `-s read-only` 포함 (AC4와 중복 검증)

한 layer라도 빠지면 AC9 실패.

### AC10 — Cost consent

첫 사용 시 `AskUserQuestion`이 발화되고 사용자가 "approve / decline / always-approve" 중 선택. Consent marker (`~/.claude/quality-gates/codex-cost-consent.md`) 있으면 silent. Decline 시 그 세션 동안 codex-reviewer skip + meta note.

**검증 (`tests/test-cost-consent.sh`):** Test harness가 `QG_MOCK_ASKUSER_PATH=$TMPDIR/captured-question.json` env var 설정. SKILL.md 안의 cost consent 호출이 이 env var 감지 시 실제 AskUserQuestion 대신 prompt text를 파일에 기록 후 `approve` 반환 (mocked). 테스트 절차:
1. `rm -f ~/.claude/quality-gates/codex-cost-consent.md` (marker 제거)
2. `QG_MOCK_ASKUSER_PATH=/tmp/q.json bash tests/run-qg-once.sh`
3. Assert `/tmp/q.json` 존재 + grep `codex` `/tmp/q.json` 매치
4. Assert marker 파일 생성됨
5. 두 번째 run: `QG_MOCK_ASKUSER_PATH=/tmp/q2.json bash tests/run-qg-once.sh`
6. Assert `/tmp/q2.json` 미생성 (silent, marker 존재하므로)

### AC11 — Outer Bash allowlist 정적 검증

`codex-reviewer.md` 의 `allowed-tools` 라인 파싱 → 다음 패턴만 포함:
- `Bash(codex exec*)` 또는 `Bash(codex *)` (codex 실행)
- `Bash(timeout *)` / `Bash(gtimeout *)` (timeout wrapper)
- `Bash(mktemp -d*)` (스크래치 디렉토리 생성)
- `Bash(python3 *)` (parser 실행)
- `Read`

위 외 패턴 (특히 generic `Bash`, `Bash(cat *)`, `Bash(echo *)`, `Write`, `Edit` 류) 존재 시 AC11 실패.

**`Bash(cat *)` 명시적 제외 (NEW-10):** `cat` allowlist는 redirection (`cat foo > bar`) 차단 못함 — Claude Code의 `allowed-tools` 패턴 매칭은 command prefix 기반이지 shell line full parse가 아님. 파일 읽기는 `Read` 도구로만 (Bash 우회 불가). Parser는 stdin pipe로 codex stdout 받음 — `cat` 불필요.

## 6. Files to Modify

### 6.1 새 파일

| Path | Purpose | 크기 추정 |
|---|---|---|
| `plugins/quality-gates/scripts/detect-codex.sh` | 6-case probe — version, auth, sandbox-guard, kill-switch, install-check 모두 통합. `gstack-codex-*` 헬퍼를 재구현 (외부 dep 없음). | ~80 lines |
| `plugins/quality-gates/scripts/codex-findings-to-yaml.py` | Codex JSONL stream → 표준 finding YAML. JSONL event parser + JSON extractor + YAML emitter + failure mode classifier. | ~120 lines |
| `plugins/quality-gates/agents/codex-reviewer.md` | Reviewer agent (frontmatter + 본문 invocation 패턴). | ~150 lines |
| `plugins/quality-gates/tests/test-detect-codex.sh` | AC1 6-case 자동 검증. | ~80 lines |
| `plugins/quality-gates/tests/test-sandbox-enforced.sh` | AC4 정적 검증. | ~30 lines |
| `plugins/quality-gates/tests/lib/extract-codex-invocations.py` | Multi-line shell block normalize 헬퍼 (AC4). | ~40 lines |
| `plugins/quality-gates/tests/mocks/mock-codex-{exit1,hang,bad-json,no-agent-message,valid-json-no-fence,auth-stderr}.sh` | AC5 6 mock binaries (v3: +valid-json-no-fence, +auth-stderr). | ~10 lines each |
| `plugins/quality-gates/tests/test-cost-consent.sh` | AC10 mocked AskUserQuestion via `QG_MOCK_ASKUSER_PATH` env var. | ~50 lines |
| `plugins/quality-gates/tests/test-findings-parser.sh` | AC3 — synthetic JSONL streams (fenced JSON, raw JSON, malformed, missing, auth-stderr) into parser, diff against expected YAML. | ~60 lines |
| `plugins/quality-gates/tests/spike/test-codex-json-extraction.sh` | §9 Step 0 prompt-engineering spike — runs real `codex exec --json` with sample prompt 3 times, asserts fenced JSON in `agent_message` ≥ 2/3 runs. | ~40 lines |
| `plugins/quality-gates/tests/fixtures/baseline-synthesizer-{small,medium,large}.yaml` | AC7 baseline (precursor task에서 captured). | captured |
| `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` | 본 spec (이 파일). | (existing) |

### 6.2 패치 — 정확한 줄 granularity

#### `plugins/quality-gates/agents/scout.md`

**Patch 1 (Inputs 섹션, line ~17 근방):** 입력 목록에 `codex_manifest` 추가.

```diff
 You will receive:

 - `filtered_diff`: unified diff with documentation paths excluded (*.md, docs/**, etc.).
 - `gate1_summary`: a YAML block from Gate 1 plan-verifier:
   ...
 - `session_scope`: one of `branch | session | paths` plus the applied path list.
+- `codex_manifest`: YAML block from `scripts/detect-codex.sh`:
+  ```yaml
+  codex_available: true | false
+  codex_path: <string, only if available>
+  codex_version: <string, only if available>
+  skip_reason: <not_installed | kill_switch | inside_codex_sandbox | auth_missing | known_bad_version>
+  ```
```

**Patch 2 (Phase 1 selection table, line ~55):** codex-reviewer row 추가.

```diff
 | depth | phase1_agents |
 |---|---|
 | quick | [code-reviewer] |
-| standard | [code-reviewer, silent-failure-hunter] |
-| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] |
+| standard | [code-reviewer, silent-failure-hunter] + codex-reviewer if codex_available |
+| deep | [code-reviewer, silent-failure-hunter, feature-dev:code-reviewer] + codex-reviewer if codex_available |
```

**Patch 3 (Phase 1 selection 본문, line ~62):** 추가 rule:

```
- `codex-reviewer`: include when `codex_manifest.codex_available == true` AND depth ∈ {standard, deep}. Skip on `quick` (cost/latency overhead unjustified for small diffs).
```

#### `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

**Patch 1 (Gate 2 Phase 0 직전):** Codex probe 호출 + Scout 입력 합성.

정확한 위치: 현재 SKILL.md의 "Gate 2 — Phase 0 (Scout)" 섹션 진입부, Scout dispatch 직전.

```markdown
**Codex availability probe (Gate 2, Phase 0 prerequisite):**

\`\`\`bash
bash scripts/detect-codex.sh > /tmp/qg-codex-manifest.yaml
\`\`\`

The script emits a YAML manifest (6-case probe — install, kill-switch, sandbox-recursion, auth, version, ok). Output is captured to `/tmp/qg-codex-manifest.yaml` (or `${TMPDIR}/qg-codex-manifest-${SESSION_ID}.yaml` if `$TMPDIR` set) and passed as the `codex_manifest` input field to Scout. **Idempotency:** rerunning the probe is safe (read-only, no side effects); the SKILL.md does not check for prior probe output.
```

**Inject 방법:** Scout dispatch가 markdown으로 표현된 입력 블록을 만들 때, `codex_manifest:` 키 하위에 YAML 매니페스트의 *escaped 본문*을 inline. 파일을 그대로 cat하는 게 아니라 YAML safe-load 후 재emit — injection 방어 (현재 detect-codex.sh 출력은 hardcoded set이라 injection 표면 사실상 0이지만 명시적 normalize 단계 명시).

### 6.3 메타데이터 패치

| Path | 변경 |
|---|---|
| `plugins/quality-gates/.claude-plugin/plugin.json` | `version: "1.10.0" → "1.11.0"` |
| `plugins/quality-gates/CHANGELOG.md` | `## [1.11.0] — 2026-05-13` 섹션 신규: Added (codex-reviewer agent, detect-codex probe, codex-findings-to-yaml parser), Changed (scout dispatch input now includes codex_manifest — backwards-compatible). |
| `plugins/quality-gates/README.md` | (a) "Principles Instantiated"에 "Law 2 strengthening: writer-reviewer 분리에 모델 family 분리 + OS sandbox 추가 격리"; (b) Fan-out 카운트 11 → 12 갱신; (c) cost 섹션에 "codex-reviewer: variable (depends on user's Codex subscription / API plan; first-use consent gate)" |

## 7. Verification Plan

### 7.1 Probe unit test — AC1 6 cases

`tests/test-detect-codex.sh`:

```bash
# Case 1: not installed
PATH=/usr/bin:/bin bash scripts/detect-codex.sh \
  | grep -q 'skip_reason: not_installed' || fail 1

# Case 2: installed + auth + safe version (mock codex binary that returns 1.0.0)
PATH="$MOCK_OK_DIR:$PATH" CODEX_API_KEY=test bash scripts/detect-codex.sh \
  | grep -q 'codex_available: true' || fail 2

# Case 3: kill switch
DEVBREW_DISABLE_QG_CODEX=1 bash scripts/detect-codex.sh \
  | grep -q 'skip_reason: kill_switch' || fail 3

# Case 4: inside codex sandbox
CODEX_SANDBOX=1 bash scripts/detect-codex.sh \
  | grep -q 'skip_reason: inside_codex_sandbox' || fail 4

# Case 5: no auth
PATH="$MOCK_OK_DIR:$PATH" \
  CODEX_API_KEY= OPENAI_API_KEY= HOME=/tmp/no-codex-home \
  bash scripts/detect-codex.sh \
  | grep -q 'skip_reason: auth_missing' || fail 5

# Case 6: known bad version (mock that returns 0.120.1)
PATH="$MOCK_BAD_DIR:$PATH" CODEX_API_KEY=test bash scripts/detect-codex.sh \
  | grep -q 'skip_reason: known_bad_version' || fail 6

echo "All 6 cases passed."
```

### 7.2 Scout integration test — AC2

`tests/test-scout-integration.sh`: 4 case 합성된 `codex_manifest` + filtered_diff/gate1_summary로 scout 호출 (test harness `tests/harness/dispatch-scout.sh` 사용) → 출력 YAML의 `phase1_agents` 검증.

### 7.3 JSONL parser test — AC3

`tests/test-findings-parser.sh`: 4가지 synthetic JSONL stream을 stdin으로 파서에 입력 → 기대 YAML과 diff.

### 7.4 Sandbox static check — AC4

`tests/test-sandbox-enforced.sh` (위 AC4 참조). CI에서 실행.

### 7.5 Failure injection — AC5

`tests/test-failure-injection.sh`: 6 mock codex binary 각각으로 codex-reviewer agent simulation 실행 → 출력 + synthesizer 입력 diff 검증. (v3에서 `valid-json-no-fence`, `auth-stderr` 추가)

### 7.6 Backward compatibility — AC7

**Precursor (one-time):** `tests/capture-baseline.sh` 실행. Codex 미설치 환경에서 3개 합성 PR에 `/qg` 돌려 synthesizer 출력 fixture 저장. Commit으로 baseline 고정.

**AC7 regression:** `tests/test-backward-compat.sh` — 같은 3 PR + 미설치 환경 → fixture와 diff (normalize 후).

### 7.7 Persona security review

PR 리뷰 시 `codex-reviewer.md` 변경에 대해 다음 체크리스트:
- [ ] `disallowedTools`에 `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, `Glob` 모두 존재
- [ ] `allowed-tools`가 narrow Bash 화이트리스트 (generic `Bash` 아님)
- [ ] 모든 `codex exec` 라인에 `-s read-only`
- [ ] 모든 `codex exec` 라인에 timeout wrapper (`gtimeout 600` / `timeout 600` — §4.3 canonical에 매칭)
- [ ] Recursion guard probe 통과 후 dispatch

## 8. Rejected Alternatives

### 8.1 Codex로 writer 위임 (CE 패턴 그대로)

QG는 review pipeline. Writer delegation은 ce-work-beta 영역. **Rejected — out of scope.**

### 8.2 Settings.json toggle로 모든 reviewer를 codex로

비용 절감 목적. **Rejected** — Law 2의 독립 의견 가치 손실 (단일 family 회귀); 사용자 mental model 비용.

### 8.3 Adversarial agent를 codex로 교체

`adversarial.md`가 codex 가용 시 backend 전환. **Rejected** — 한 agent 두 backend는 디버깅/테스트 부담; 새 agent로 분리가 깨끗; Law 2 효과는 "writer vs reviewer 격리"가 "reviewer vs reviewer 격리"보다 큼.

### 8.4 `codex review` subcommand 사용

빌트인 diff review 모드 (gstack의 `/codex review`). **Rejected** — 출력이 freeform 텍스트로 fixed format, 표준 finding YAML로 정규화 어려움; `codex exec --json`이 stream에서 structured JSON 추출 가능.

### 8.5 `codex exec --output-schema` 사용 (v1 원안)

CE의 writer delegation 패턴. **Rejected after v1 review** — `--output-schema`는 writer 완료 contract용으로 검증된 패턴이며, reviewer per-finding 출력에는 precedent 없음. Codex agent loop가 schema-enforced 출력을 emit하기 전에 reasoning trace를 같이 출력하는지 미확인. gstack의 `--json` JSONL streaming + Python parser가 검증된 reviewer 패턴.

### 8.6 모든 Gate에 codex 추가

Gate 1/3 포함. **Rejected** — Gate 1 plan↔diff 단순 매칭에 추가 가치 미미; Gate 3는 MCP 도구 기반. Gate 2 Phase 1로 범위 한정.

### 8.7 새 P# 원칙으로 escalation

"Multi-model reviewer diversity"를 신규 devbrew 원칙. **Rejected** — `feedback_devbrew_design_lightness` 부합. 본 디자인은 Law 2의 *물리 분리* 원칙을 한 단계 더 인스턴스화하지 직교 원칙 아님. Law 2 본문에 "다른 모델 family로 분리하면 강화" 한 줄 추가는 별도 PR 가능.

### 8.8 명시적 토큰 cap

Codex CLI 토큰 cap 플래그 가용성은 §10 Open Question (OQ-1)로 분리. v3 시점 미확인. **Rejected (current)** — `gtimeout 600`을 wall-clock 기반 비용 ceiling proxy로 사용. Step 0 spike 단계에서 `codex exec --help` 확인 후 토큰 cap 발견 시 spec amendment.

## 9. Concrete Next Action

구현 시작 순서 (writing-plans 단계에서 task로 풀어낼 baseline):

0. **Prompt-engineering spike (BLOCKING gate)** — 실제 codex가 설치된 환경에서 `tests/spike/test-codex-json-extraction.sh` 실행:
   ```bash
   # spike: prompt에 "Output your findings as JSON in a code block. Use exactly this format: ```json\n{\"findings\": [...]}\n```"
   # 3회 실행, 각 회마다 agent_message에 fenced JSON 추출 가능한지 검증.
   for i in 1 2 3; do
     gtimeout 600 codex exec "$SPIKE_PROMPT" -C "$_REPO_ROOT" -s read-only \
       -c 'model_reasoning_effort="medium"' --json < /dev/null 2>/dev/null \
       | python3 scripts/codex-findings-to-yaml.py
   done
   ```
   **Pass 기준:** 3회 중 ≥2회 fenced JSON 또는 raw JSON 파싱 성공. **Fail 시:** spec amendment — prompt template 조정, 또는 `codex exec --output-schema`로 architecture 재검토 (현 §3 거부 근거였던 "검증된 precedent 없음"이 spike로 뒤집힐 수 있음). Spike 실패면 step 3 진행 금지.
1. **Worktree 확인** — 이미 `worktree-qg-codex-spec`에 있음. Spec merge 후 `feature/qg-codex-reviewer` 새 브랜치 또는 worktree.
2. **Baseline capture (AC7 precursor)** — codex 없는 상태에서 합성 3 PR로 `/qg` 돌려 fixture 저장. 이걸 *먼저* 해야 AC7가 active.
3. **`scripts/detect-codex.sh` 작성** + **`tests/test-detect-codex.sh` 6 case mock + assert** — AC1.
4. **`scripts/codex-findings-to-yaml.py` 작성** + JSONL parser test (3-stage fallback chain + stderr capture) — AC3.
5. **`agents/codex-reviewer.md` 작성** — frontmatter (allowed-tools narrow per AC11, disallowedTools 5종) + 본문에 §4.3 canonical invocation 정확히 포함 (`gtimeout 600 codex exec ... -C "$_REPO_ROOT" -s read-only ... --json < /dev/null 2>"$TMPERR" | python3 ...`). AC4/AC9/AC11 정적 검증 통과.
6. **`tests/test-sandbox-enforced.sh` + 6 mock-codex binaries** — AC5.
7. **`agents/scout.md` 패치** (3 patch hunks) — AC2.
8. **`skills/quality-pipeline/SKILL.md` 패치** — Phase 0 probe 호출 + Scout 입력 합성.
9. **Cost consent gate** — `AskUserQuestion` 호출 + marker 파일 로직 + `QG_MOCK_ASKUSER_PATH` mock hook — AC10.
10. **Metadata** — `plugin.json` bump, `CHANGELOG.md` `[1.11.0]` 섹션, `README.md` 3 곳 갱신 — AC8.
11. **AC7 regression run** — baseline과 diff.
12. **Self-review + commit + PR**.

각 step은 `writing-plans` skill에서 task로 분해됨. **Step 0이 BLOCKING gate** — spike 실패 시 5번 진행 불가. 5번이 다음으로 무겁고 11번이 가장 위험 (baseline drift 발견 시 회귀 디버깅).

## 10. Open Questions

Spec 시점에 미확정이며 구현 중(특히 §9 Step 0 spike) 해소 필요한 항목. 해소 결과는 spec amendment로 반영.

- **OQ-1 — Codex CLI 토큰 cap 플래그 존재 여부.** `codex exec --help` 확인 필요. 존재한다면 `gtimeout 600` wall-clock proxy를 토큰 기반 ceiling으로 보강. 부재하면 v3 spec 그대로 진행. (이전 §8.8 "(확인 필요)" hedge가 여기로 이동.)
- **OQ-2 — `agent_message` text에서 모델이 fenced JSON을 emit하는 행동의 안정성.** §9 Step 0 spike에서 실증 검증. 3/3 fenced 성공이면 confidence 높음, 2/3이면 Stage 2 raw fallback이 자주 호출됨, ≤1/3이면 prompt template 재설계 또는 `--output-schema` 재검토.
- **OQ-3 — Codex JSONL stream event schema 안정성.** `agent_message` event의 정확한 필드 이름과 nesting이 codex 버전 간 변동될 수 있음. `_gstack_codex_version_check`가 known-bad만 차단 — known-good 범위 미정의. Spike에서 event schema 캡처 후 `tests/fixtures/codex-jsonl-sample.json`로 frozen. 향후 codex upgrade 시 sample과 diff로 schema drift 감지.
- **OQ-4 — `model_reasoning_effort="medium"` vs `"high"` 선택.** §4.3 canonical에서 `"medium"`으로 고정했으나 deep depth review에서 `"high"`가 더 적절할 수 있음. v3.1에서 depth별 reasoning effort 매핑 검토 가능 (현재 v3는 단일 값으로 단순화).
- **OQ-5 — `auth_error_in_stderr` 정규식.** `Error: authentication failed` 외에 codex가 어떤 phrasing을 쓰는지 미확정. Spike에서 의도적으로 invalid API key로 호출해 stderr 캡처 후 정규식 fine-tune.

## 11. Metadata

- **Plugin:** `plugins/quality-gates`
- **Version bump:** `1.10.0 → 1.11.0` (minor, backward compatible)
- **Branch:** `feature/qg-codex-reviewer` (현재 worktree: `worktree-qg-codex-spec` — spec merge 후 새 브랜치)
- **Commit prefix:** `feat(qg-codex):` 새 파일, `feat(qg):` scout/skill 패치, `chore(qg):` version/CHANGELOG, `docs(qg):` README
- **Estimated effort:** 1–2 implementation sessions
  - Session 1: probe + parser + agent skeleton (steps 3–5)
  - Session 2: tests + scout/skill patches + metadata + AC7 regression (steps 2, 6–11)
- **Risk:** Low–Medium
  - Low: additive, kill switch, 3 layer 격리, graceful degradation
  - Medium: `codex exec --json` reviewer 출력에서 finding JSON 추출이 모델 obedience에 의존 (prompt engineering risk) — first-pass JSONL stream으로 실증 검증 필요한 spike 포함
- **Dependencies:**
  - 런타임: codex CLI (optional, graceful degradation)
  - 빌드: Python 3 (parser) — 이미 다른 qg 스크립트가 사용 중
- **Related memory:**
  - `feedback_respect_upstream_model_hardcoding` — 충돌 없음 (codex는 별도 프로세스)
  - `feedback_devbrew_design_lightness` — 새 P# 추가 없이 Law 2 instantiation 확장
  - `feedback_plugin_version_bump` — 1.10.0 → 1.11.0 명시
- **Spec review log:**
  - v1 → v2: spec-distill:spec-reviewer round 1이 16 이슈 (4 BLOCK / 7 HIGH / 5 MEDIUM) 지적. 전부 v2에서 addressed. 주요 변경: 아키텍처 `--output-schema` → `--json` JSONL, version/auth probe 추가, timeout 180→330, 3 layer 격리 명시, AC5 concrete failure tests, AC7 precursor task, AC10 cost consent, AC11 Bash allowlist, Concrete Next Action 섹션 추가.
  - v2 → v3: spec-distill:spec-reviewer round 2가 10 NEW 이슈 (6 HIGH / 4 MEDIUM, 그중 4개 implementation-blocking) 지적. 전부 v3에서 addressed. 주요 변경: §4.3 canonical invocation 단일 정의 (`-C "$_REPO_ROOT"`, `-s read-only`, `--json`, `< /dev/null`, `2>"$TMPERR"`), timeout 330→600 (`codex exec --json` precedent로 정정), `--enable web_search_cached` 명시적 비채택, AC3 parser 3-stage fallback chain, AC5에 2 추가 case (valid-json-no-fence, auth-error-stderr), AC10 `QG_MOCK_ASKUSER_PATH` mocked verification, AC11에서 `Bash(cat *)` 제거 (redirection 우회 차단 위해), §9 Step 0 prompt-engineering spike (BLOCKING gate), §10 Open Questions 5 항목 분리.
