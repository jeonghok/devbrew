# QG Codex Reviewer — Design Spec

> **Status:** Draft — pending implementation plan
> **Author:** Jeongho-K (with Claude Opus 4.7)
> **Date:** 2026-05-13
> **Plugin:** `plugins/quality-gates`
> **Plugin bump:** `1.10.0 → 1.11.0` (minor — 새 reviewer surface 추가)
> **Branch:** `feature/qg-codex-reviewer`

## 1. Context / Why

QG (quality-gates)의 3개 게이트는 모두 reviewer agent를 dispatch한다 — Gate 1의 plan-verifier, Gate 2의 scout / code-reviewer / silent-failure-hunter / feature-dev:code-reviewer / adversarial / synthesizer, Gate 3의 runtime-verifier / test-scope-validator. 모두 같은 Anthropic 모델 family에서 도는 subagent다.

Law 2 — "writer와 reviewer는 같은 pass를 공유 못 한다" — 는 `disallowedTools` frontmatter로 물리적으로 강제된다. 그러나 **모델 family 단일성**은 남아 있는 약점이다. 동일 family의 reviewer들은 pattern-matching 누락(blind spot)이 상관(correlated)될 수 있다 — 한 reviewer가 놓치면 다른 reviewer도 놓칠 확률이 높아지는 구조.

Codex CLI(OpenAI 계열 모델 백엔드)가 시스템에 설치되어 있으면 진짜 독립적인 두 번째 의견 — 다른 프로세스, 다른 모델 family — 을 얻을 수 있다. devbrew Law 2의 정신을 "프롬프트가 아니라 물리적 분리"에서 한 단계 더 밀어 "OS 프로세스 분리 + 모델 family 분리"로 확장한다.

Reference 패턴 (Codex 통합 선례):
- `reference/compound-engineering-plugin/plugins/compound-engineering/skills/ce-work-beta/references/codex-delegation-workflow.md` — `codex exec`을 writer로 위임. 환경 probe (`command -v codex`, `CODEX_SANDBOX`/`CODEX_SESSION_ID` recursion guard), output schema 강제, sandbox mode 선택 (`yolo` / `full-auto`), circuit breaker (3연속 실패 후 비활성화).
- `reference/gstack/codex/SKILL.md` — `codex review` / `codex challenge` / `codex consult` 3-mode "200 IQ second opinion" reviewer 패턴.

QG는 reviewer pipeline이므로 두 reference의 합성: CE의 환경 probe + 격리 패턴 + gstack의 reviewer 의도, 단 `codex exec -s read-only` (read-only sandbox)로 격리.

## 2. Goals

1. Codex CLI가 시스템에 설치되어 있고 `DEVBREW_DISABLE_QG_CODEX=1`이 아니면, QG가 자동 감지한다.
2. 감지 시 Gate 2 Phase 1에 `codex-reviewer` agent를 추가 dispatch한다.
3. Codex의 findings는 기존 reviewer와 동일한 finding YAML schema로 정규화되어 Phase 1.5 (adversarial) / Phase 1.6 (synthesizer)에서 출처 구분 없이 dedupe/rank된다.
4. Codex 호출은 OS-level read-only sandbox(`-s read-only`)로 격리되어 working tree mutation이 물리적으로 불가능하다.
5. 실패 모드(timeout, exit ≠ 0, malformed JSON, 누락된 result) 모두 graceful skip — 다른 reviewer 실행에 영향 없음.

## 3. Non-goals

- **Codex로 코드를 *작성*하지 않는다.** QG는 review pipeline이며 ce-work-beta의 writer delegation 영역과 명확히 분리된다.
- **Codex가 git/PR/working tree를 mutate하지 않는다.** `-s read-only` sandbox로 강제.
- **기존 Claude reviewer를 대체하지 않는다.** 추가 reviewer로만 동작 — 비용 최적화 목적 아님.
- **Gate 1 / Gate 3은 변경하지 않는다.** Gate 1은 단순 plan ↔ diff 매칭이라 codex의 추가 가치가 미미하고, Gate 3는 MCP 도구 (chrome-devtools) 기반이라 codex CLI와 결합 의미가 약하다. 범위를 Gate 2 Phase 1로 한정해 영향 범위를 좁힌다.
- **`codex review` subcommand는 쓰지 않는다.** 출력 형식이 고정되어 finding YAML 정규화가 어렵다. `codex exec --output-schema`가 더 유연하다.

## 4. Constraints

### 4.1 devbrew 철학 제약

- **Law 1 (Clarity Before Code).** 본 spec 자체가 Law 1의 instantiation — 구조적 게이트 (Context, Goals, Non-goals, Constraints, AC, Files, Verification, Rejected Alternatives, Metadata) 충족.
- **Law 2 (Writer/Reviewer Separation).** `codex-reviewer.md` frontmatter에 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]` 명시. 추가로 codex 프로세스 자체에 `-s read-only` sandbox — 2중 격리.
- **Law 3 (Compounding).** Spec 자체가 `docs/superpowers/specs/` 하위에 영구 저장 (Law 3 substrate). README의 "Principles Instantiated"에 "Law 2 strengthening via process + model-family separation" 한 줄 추가.

### 4.2 Plugin shape 제약

- **Scoped tools:** `codex-reviewer.md`는 `allowedTools: [Bash, Read]`, `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]`. Scout 패치는 frontmatter 건드리지 않음 (입력만 추가).
- **cost_class:** `codex-reviewer.md`에 `cost_class: variable` (사용자의 codex 계정/구독에 따라 다름). README cost 섹션에 명시.
- **Kill switch:** `DEVBREW_DISABLE_QG_CODEX=1` 환경변수. probe script가 가장 먼저 확인.
- **Markdown state, secret 금지:** 결과는 OS-temp (`mktemp -d`)에 — 영구 보존 불필요. Secret 기록 없음 (probe는 codex 경로/버전만).
- **Graceful degradation with loud logging:** Codex 없을 때 fallback이 돌았음을 사용자가 출력에서 인지할 수 있게 SKILL.md에 명시 ("Codex CLI not detected — skipping codex-reviewer").
- **Progressive disclosure:** Agent 이름 `codex-reviewer` (짧고 명령형 아님 — agent는 명사). Probe script 이름 `detect-codex.sh` (기존 `detect-runtime.sh`와 동형).

### 4.3 보안 제약

- Codex 프로세스가 `-s read-only` sandbox 외 모드로 호출되지 않도록 agent 본문에 인라인 ("Always invoke codex with `-s read-only`. Never substitute a different sandbox mode.").
- Recursion guard: `CODEX_SANDBOX` 또는 `CODEX_SESSION_ID` env가 set이면 probe는 `codex_available: false`를 emit (이미 codex 안에서 도는 경우 재귀 회피).
- Timeout: `timeout 180 codex exec ...` — 하드 wall-clock 한도.
- Persona 파일 보호: `codex-reviewer.md`는 reviewer persona — 약화하는 PR(security 제약 제거, sandbox 모드 변경)은 보안 리뷰 대상 (CLAUDE.md "Persona 파일은 보안-민감 코드" 조항).

## 5. Acceptance Criteria

각 AC는 검증 가능한 binary 조건.

- **AC1 — Probe correctness (4 cases).**
  `bash scripts/detect-codex.sh`가 다음 4가지 case에서 정확한 YAML emit:
  1. Codex 미설치 (`command -v codex` 빈 출력) → `codex_available: false`, `skip_reason: not_installed`
  2. Codex 설치됨 → `codex_available: true`, `codex_path: <absolute>`, `codex_version: <string>`
  3. Kill switch (`DEVBREW_DISABLE_QG_CODEX=1`) → `codex_available: false`, `skip_reason: kill_switch`
  4. 이미 codex 안 (`CODEX_SANDBOX=1`) → `codex_available: false`, `skip_reason: inside_codex_sandbox`

- **AC2 — Scout 통합.** Scout이 `codex_manifest` YAML을 입력으로 받고, `codex_available: true` AND depth ∈ {standard, deep}일 때 `phase1_agents`에 `codex-reviewer` 포함. depth=`quick`일 때 또는 `codex_available: false`일 때 미포함.

- **AC3 — Codex-reviewer agent 출력 schema.** Agent가 다른 Phase 1 reviewer와 동일한 finding YAML 구조 emit:
  ```yaml
  - agent: codex-reviewer
    file: <path>
    line: <number>
    severity: CRITICAL | IMPORTANT | SUGGESTION
    confidence: <1-10>
    summary: <one sentence>
    proposed_fix: <string>
  ```

- **AC4 — Sandbox 강제.** `codex-reviewer.md` 본문 grep으로 `codex exec` 호출이 항상 `-s read-only` 플래그를 동반함을 확인. (테스트 케이스: grep으로 `codex exec`가 등장하는 모든 라인이 `read-only`도 포함)

- **AC5 — Graceful failure.** Codex 호출이 실패(exit ≠ 0, timeout, malformed JSON, 누락된 result)할 때:
  1. Agent는 다음 형태의 YAML emit:
     ```yaml
     findings: []
     meta:
       codex_failed: true
       reason: <one of: exit_nonzero | timeout | malformed_json | missing_result>
       exit_code: <int or null>
     ```
  2. Phase 1.5 (adversarial) / Phase 1.6 (synthesizer)는 영향 없이 진행 — 빈 리스트는 자연스럽게 dedupe/rank pass-through
  3. 다른 reviewer의 findings는 그대로 처리

- **AC6 — Kill switch 우회.** `DEVBREW_DISABLE_QG_CODEX=1 /qg` 실행 시 codex-reviewer가 dispatch되지 않음 (스카웃 출력에 미포함).

- **AC7 — Backward compatibility.** Codex 미설치 환경에서 기존 QG 출력과 100% 동일 (findings 개수, ordering, synthesizer 출력 모두). 회귀 테스트로 검증.

- **AC8 — Plugin shape compliance.** `plugin.json` 버전 `1.10.0 → 1.11.0` bump, `CHANGELOG.md`에 `[1.11.0] — 2026-05-13` 섹션 (Added/Changed), README "Principles Instantiated"에 1줄 추가, README cost 섹션에 codex_class: variable 명시.

- **AC9 — Persona 격리 (Law 2 이중).** `codex-reviewer.md` frontmatter에 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]` 명시 AND agent 본문에 `-s read-only` 인라인. 두 layer 중 하나라도 빠지면 AC 실패.

## 6. Files to Modify

### 6.1 새 파일

| Path | Purpose |
|---|---|
| `plugins/quality-gates/scripts/detect-codex.sh` | Codex 가용성 probe. YAML manifest emit. read-only, ~50줄. |
| `plugins/quality-gates/scripts/codex-findings-to-yaml.py` | Codex JSON 출력 → 표준 finding YAML 정규화. ~30줄. |
| `plugins/quality-gates/agents/codex-reviewer.md` | 독립 reviewer agent. Bash로 `codex exec -s read-only` 호출. |
| `plugins/quality-gates/tests/test-detect-codex.bats` 또는 `.sh` | AC1의 4가지 case unit test. |
| `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` | 본 spec (이 파일). |

### 6.2 패치

| Path | 변경 |
|---|---|
| `plugins/quality-gates/agents/scout.md` | 입력 schema에 `codex_manifest` 추가, Phase 1 후보 목록에 `codex-reviewer` 추가, 선택 규칙 한 줄 추가. |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | Gate 2 Phase 0 직전에 `detect-codex.sh` 실행 → 그 stdout YAML을 Scout dispatch 프롬프트의 inputs 섹션에 `codex_manifest:` 키로 inline (`filtered_diff` / `gate1_summary`와 동일 메커니즘 — Scout agent의 단일 프롬프트 입력 일부). |
| `plugins/quality-gates/.claude-plugin/plugin.json` | `version: "1.10.0" → "1.11.0"` |
| `plugins/quality-gates/CHANGELOG.md` | `## [1.11.0] — 2026-05-13` 섹션 (Added: codex-reviewer agent, detect-codex probe; Changed: scout dispatch input shape — backwards-compatible). |
| `plugins/quality-gates/README.md` | "Principles Instantiated"에 Law 2 강화 한 줄 추가, "Hooks Installed" 또는 "Agents" 섹션에 codex-reviewer 추가, cost 섹션에 codex variable cost 명시. |

## 7. Verification Plan

### 7.1 Probe unit test (`tests/test-detect-codex.sh`)

`detect-codex.sh`를 4가지 환경에서 실행하고 stdout grep으로 검증:

```bash
# Case 1: not installed (PATH에서 codex 제거)
PATH=/usr/bin /bin bash scripts/detect-codex.sh | grep -q 'skip_reason: not_installed'

# Case 2: installed (mock codex binary)
PATH="$MOCK_DIR:$PATH" bash scripts/detect-codex.sh | grep -q 'codex_available: true'

# Case 3: kill switch
DEVBREW_DISABLE_QG_CODEX=1 bash scripts/detect-codex.sh | grep -q 'skip_reason: kill_switch'

# Case 4: inside codex sandbox
CODEX_SANDBOX=1 bash scripts/detect-codex.sh | grep -q 'skip_reason: inside_codex_sandbox'
```

### 7.2 Schema conformance

`codex-findings-to-yaml.py`에 합성 codex 출력 JSON 입력 → 표준 finding YAML emit 확인. Malformed JSON 입력 → 빈 리스트 + meta note.

### 7.3 Integration (수동)

- Codex 설치된 환경에서 `/qg` 실행 → Scout 출력 YAML에 `codex-reviewer` 포함 확인 → Phase 1에서 실제 호출 → 결과 synthesizer 출력 포함 확인.
- Codex 미설치 환경에서 `/qg` 실행 → 기존 동작과 동일.
- `DEVBREW_DISABLE_QG_CODEX=1 /qg` → codex-reviewer skip.

### 7.4 Failure injection

- `codex` 자리에 `exit 1`만 하는 mock binary → agent가 빈 findings + meta note emit, Phase 1.5/1.6 정상 진행.
- Timeout 시뮬레이션 (`sleep 300`) → 180초 후 timeout, graceful skip.
- Malformed JSON 출력 → 빈 리스트 + meta note.

### 7.5 Backward compatibility regression

기존 `tests/` 하위 테스트 전부 통과 확인.

### 7.6 Persona file 보안 검토

리뷰어 persona 파일 (`codex-reviewer.md`) 작성 시 다음 보안 컨트롤이 인라인으로 박혀 있는지 확인:
- `disallowedTools` frontmatter
- `-s read-only` sandbox 모드
- `timeout 180` wall-clock 한도
- Recursion guard 호출 (probe 통과 후 dispatch)

## 8. Rejected Alternatives

### 8.1 Codex로 writer 위임 (CE 패턴 그대로)

CE의 `ce-work-beta` 패턴은 `codex exec`로 implementation 위임. **거부 이유:** QG는 review pipeline이지 writer가 아님. Writer delegation은 별도 플러그인(ce-work-beta) 영역이며 QG가 침범할 책임이 아니다.

### 8.2 Settings.json toggle로 모든 reviewer를 codex로 교체

비용 절감 목적. **거부 이유:** Law 2의 가치(독립 의견)를 잃고 비용 최적화로 의미 좁아짐. 단일 모델 family로 회귀하면서 reviewer correlation 문제 재발. 또한 사용자가 toggle 상태를 추적해야 하는 mental model 비용 발생.

### 8.3 Adversarial agent를 codex로 교체

기존 `adversarial.md`가 codex 가용 시 backend 전환. **거부 이유:** 한 agent에 두 backend는 디버깅/테스트 부담 큼; codex 없을 때와 동작 차이가 크면 회귀 표면 넓어짐; "reviewer-reviewer 격리" 효과보다 "writer-reviewer 격리" 강화가 Law 2 정신에 더 가깝다. 새 agent로 분리하는 것이 깨끗.

### 8.4 `codex review` subcommand 사용

빌트인 diff review 모드. **거부 이유:** 출력 형식이 고정되어 표준 finding YAML로 정규화 어려움. `codex exec --output-schema`가 schema 강제 + 유연성 모두 제공.

### 8.5 모든 Gate에 codex 추가 (Gate 1/3 포함)

**거부 이유:** Gate 1은 plan ↔ diff 단순 매칭이라 codex의 추가 가치가 미미. Gate 3는 MCP 도구 (chrome-devtools 등) 기반의 runtime verification이라 codex CLI와 결합 의미가 약함. 범위를 Gate 2 Phase 1로 한정해 영향 범위를 좁히고 검증 부담 최소화.

### 8.6 새 P# 원칙으로 escalation

"Multi-model reviewer diversity"를 새 devbrew 원칙으로 추가. **거부 이유:** `feedback_devbrew_design_lightness` 메모리 — devbrew design은 기본이 lightness, 기존 원칙 흡수가 default. 이 디자인은 Law 2의 *물리적 분리* 원칙을 한 단계 더 인스턴스화하는 것이지 직교 원칙이 아니다. Law 2 텍스트에 "다른 모델 family로 분리하면 강화" 한 줄 코멘트 추가 정도면 충분 (별도 PR 가능).

## 9. Metadata

- **Plugin:** `plugins/quality-gates`
- **Version bump:** `1.10.0 → 1.11.0` (minor — 새 surface 추가, backward compatible)
- **Branch suggestion:** `feature/qg-codex-reviewer`
- **Commit prefix:** `feat(qg-codex):` for new files, `feat(qg):` for scout/skill patches
- **Estimated effort:** 1 implementation session — probe + agent + scout patch + skill patch + version/CHANGELOG/README + tests
- **Risk:** Low — additive change, 2중 격리, graceful degradation, kill switch
- **Dependencies:** None (codex CLI는 런타임 optional, 미설치 시 graceful skip)
- **Related memory:**
  - `feedback_respect_upstream_model_hardcoding` — 본 디자인은 model frontmatter 우회 아님 (codex는 별도 프로세스), 충돌 없음
  - `feedback_devbrew_design_lightness` — 새 P# 추가 없이 기존 패턴(probe script, scout dispatch, finding YAML) 한 번 더 인스턴스화
  - `feedback_plugin_version_bump` — 본 spec이 1.10.0 → 1.11.0 bump 명시
