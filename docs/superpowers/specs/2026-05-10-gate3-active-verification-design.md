# Gate 3 Active Verification — Design

**작성일:** 2026-05-10
**대상 플러그인:** `quality-gates` (v1.7.0 → v1.8.0)
**관련 sister:** `chrome-devtools-mcp` (선택 의존), `playwright` MCP (선택 fallback)

## 1. Context / Why

`/qg`의 Gate 3 (`runtime-verifier` agent)이 실제 런타임 검증을 적극적으로 수행하지 않고 SKIP으로 빠지는 빈도가 높다. 사용자 보고:

> "직접 서비스를 실행하려는 적극성이 떨어짐. docker-compose같이 서비스라면 서비스를 띄워서 동작시키거나, 테스트를 돌려봐야 하는 거면 (있으면) 검증 후 돌리거나 하는 노력을 안 하고 pass시켜버림. chrome-devtools MCP 같은 것도."

**근본 원인 — 세 가지 silent-skip 경로:**

1. **Project type detection이 시그널 부재 = unknown으로 fall-through.** `runtime-verifier.md` Step 1의 sequence가 매칭 실패 시 `unknown`을 반환하고 Step 3 "For Unknown" 분기가 README 부재 시 즉시 SKIP을 emit (`runtime-verifier.md:115-118`).
2. **stop-hook이 SKIP을 PASS와 동급으로 취급.** `stop-hook.py:280` — `if verdict in ("PASS", "SKIP")` → 둘 다 `complete`로 종료. SKIP의 정당성을 사용자에게 묻는 path가 없다 (FAIL은 `gate3_fail` user choice가 있는데 SKIP은 없음). 즉 reviewer가 자기 자신을 silent하게 비활성화 가능 (Law 2 정신 위반).
3. **Tool discovery가 fragile.** `runtime-verifier.md:82-85`는 agent가 런타임에 사용 가능한 MCP 도구 (chrome-devtools / playwright)를 자기 system prompt에서 keyword 검색으로 찾도록 지시 — 모델 판단에 의존하는 비결정적 path.

**왜 이게 Law 1 / Law 2 이슈인가:**

- **Law 1 (Clarity Before Code → Verification Plan section):** Verification Plan이 silently 무력화되면 spec의 acceptance criteria가 실제로 검증되지 않는다. SKIP은 "검증할 surface가 없음"의 증거를 동반해야 하는데, 현재는 evidence 없이 통과.
- **Law 2 (Writer/Reviewer separation):** `runtime-verifier`는 reviewer 역할인데 frontmatter에 `allowedTools`/`disallowedTools`가 없어 default-everything (CLAUDE.md "Plugin Shape" — *"Scoped agents — default-everything 금지"* 위반). 이번 기회에 정리.

**왜 Anti-Pattern 회피 이슈인가:**

- **AP15 (unbounded autonomy 회피):** mid-run resolution 루프를 추가하면 새로운 무한 루프 위험이 생긴다. 새 변수 `max_gate3_resolutions: 3` + repeat-detection으로 가드.
- **AP — silent skip:** Gate 2의 "no silent skip" 정책 (`SKILL.md:711` *"All skipped agents must be listed with a reason"*)이 Gate 3에는 없었음. 일관성 회복.

## 2. Goals

- Gate 3가 SKIP을 emit하려면 **runnable surface 별로 attempt-and-fail 증거**를 요구. Evidence 없는 SKIP은 자동으로 FAIL로 격상.
- Pre-flight detection을 deterministic bash script로 분리 — agent 자유서술 의존 제거.
- Mid-run에서 해결 가능한 missing resource 발견 시 sub-agent가 mother(skill) ↔ human ↔ reviewer 3자 ping-pong을 통해 escalation 가능 (max 3회).
- Secret 값은 prompt context로 전달하지 않음 (P21). user에게 묻는 건 **결정과 포인터**(파일 복사 OK / yes-no / path)뿐.
- Markdown-only / 진짜 runnable surface 없는 repo는 `bash detector` 단계에서 정당화된 SKIP_WITH_EVIDENCE 처리 — sub-agent 깨우지도 않고 토큰 0으로 종료.
- Plugin Shape 위반 정비 — `runtime-verifier.md` frontmatter scoping, cost_class 갱신.
- README "Principles Instantiated" 갱신 (Law 1 verification plan 강화 / Law 2 writer-reviewer 물리 분리 강화 / AP15 가드 / P21 secret 미노출).

## 3. Non-goals

- Gate 3가 unit test나 integration test를 **commit-able**하게 작성 — `disallowedTools: [Write, Edit]`로 물리적 차단. 테스트가 필요하면 NEEDS_RESOLUTION으로 사용자에게 위임.
- Test 자동 생성 — 위와 동일 이유. 테스트 작성은 별도 워크플로우 (feature-dev / TDD skill).
- Browser MCP 강제 — chrome-devtools MCP가 detect되지 않으면 detector가 manifest의 `mcp_browser: none`으로 표시하고 그 항목은 attempt-skip(정당). curl + test suite로 fall-through.
- Multi-app monorepo 자동 디스패치 — 하나의 entry point만 검증. monorepo는 별도 spec.
- E2E browser 테스트 자동화 (Playwright fixture 작성 등) — 사용자가 작성한 테스트가 있으면 돌리되, 없는 걸 만들지 않음.
- 보안 스캐너 / 의존성 audit — Gate 2 영역.

## 4. Constraints

- 변경은 단일 PR/commit으로 묶여 `git revert` 한 줄로 롤백 가능해야 한다.
- CLAUDE.md "plugin.json 모든 PR마다 SemVer bump" — minor bump (`1.7.0` → `1.8.0`, 새 surface).
- CHANGELOG.md `## [1.8.0]` entry 필수.
- README "Principles Instantiated" 섹션 갱신.
- `runtime-verifier` agent에 `allowedTools` / `disallowedTools` 명시 — `Write`/`Edit` 금지 (Law 2 강화).
- 새 env: `DEVBREW_GATE3_MAX_RESOLUTIONS` (default `3`, `0` = mid-run escalation 비활성). 기존 `DEVBREW_DISABLE_QUALITY_GATES=1` / `DEVBREW_SKIP_HOOKS=quality-gates:stop-hook` 그대로.
- Detector script는 read-only — 파일 생성·수정 금지 (mkdir 포함). 사용자 결정 필요한 file ops는 skill의 `Bash`가 수행.
- Detector output은 Gate 2 Step 0와 같은 단일 stdout YAML/JSON 한 라인 — parse 실패 시 fail-open (manifest 비어있다고 간주, agent에게 auto-detect 위임).

## 5. Acceptance Criteria

1. **AC1 — Web app, docker-compose, .env 모두 OK:** docker-compose.yml + npm run dev + .env가 모두 있는 fixture에서 `/qg --gate3` 실행 시 Gate 3 verdict가 PASS, evidence-log에 모든 surface(`compose`, `npm:dev`, MCP nav, plan_features 각각)가 attempted=ok로 기록.
2. **AC2 — .env 없고 .env.example만 있음 (upfront resolution):** detector가 `env_status`에 `exists: false, has_example: true` 표시 → skill이 AskUserQuestion으로 "[1] copy / [2] manual / [3] skip" 제시 → [1] 선택 시 skill의 `Bash`가 `cp` 실행 → agent에게 manifest inject → PASS or FAIL_with_evidence.
3. **AC3 — Docker daemon down (mid-run escalation):** detector는 compose 항목 표시했으나 skill의 `docker compose up -d`가 실패 → skill이 NEEDS_RESOLUTION 처리 → AskUserQuestion 제시 → 사용자가 "재시도" 선택 → skill 재시도 → 또 실패하면 evidence에 기록하고 다른 surfaces로 fall-through (전체 SKIP/FAIL은 다른 surface 결과 종합).
4. **AC4 — Markdown-only repo (정당한 SKIP):** runnable_surfaces / test_runners / plan_features가 모두 비어있는 fixture에서 detector가 즉시 verdict=SKIP_WITH_EVIDENCE 반환, sub-agent dispatch가 발생하지 않는다 (sub-agent 호출 횟수 = 0).
5. **AC5 — Evidence 없는 SKIP 거부:** agent가 verdict=`SKIP_WITH_EVIDENCE`를 emit했지만 evidence-log에 manifest의 runnable_surfaces 일부만 attempted로 기록되어 있다면, skill이 그 SKIP을 거부하고 verdict=FAIL로 격상하면서 사용자에게 *"incomplete evidence: X out of N runnable surfaces unattempted"* 메시지 표시.
6. **AC6 — chrome-devtools MCP 가용 시 자동 사용:** detector가 MCP 도구 가용성을 감지(`mcp_browser: chrome-devtools`)하면 manifest를 통해 agent에 명시적으로 inject. agent는 web 경로에서 navigate + console message + screenshot + a11y snapshot 4개 모두 attempt하고 evidence-log에 기록.
7. **AC7 — Plan-driven feature verification:** plan_path가 해석되어 `/auth`, `dashboard`, `login form` 같은 feature가 추출되면 manifest의 `plan_features`에 들어가고 agent는 각각에 대해 navigate + screenshot + presence check를 수행한다 (manifest에 들어왔는데 attempt 안 했으면 AC5에 의해 SKIP 거부).
8. **AC8 — Max resolution cap:** mid-run NEEDS_RESOLUTION이 3회 발생하면 4번째는 자동으로 `gate3_fail` transition으로 격상되고 사용자에게 fix/skip/abort 선택 제시. 3회 미만에서 사용자가 "재시도" 선택하면 카운터 증가.
9. **AC9 — Repeat detection on resolution loop:** 같은 NEEDS_RESOLUTION needed 항목이 2회 연속 (사용자 응답 후에도 같은 needed) → repeat-detected 처리 → `gate3_repeat_detected` user prompt (proceed=PASS_WITH_WARNINGS / abort).
10. **AC10 — Plugin Shape 준수:** `runtime-verifier.md` frontmatter에 `allowedTools` 및 `disallowedTools` 선언 존재, 후자에 `Write`, `Edit` 포함. cost_class가 `low`에서 `variable`로 갱신.
11. **AC11 — Kill switch:** `DEVBREW_GATE3_MAX_RESOLUTIONS=0` 환경에서 mid-run escalation이 발생하지 않고 첫 번째 NEEDS_RESOLUTION이 즉시 FAIL 또는 SKIP_WITH_EVIDENCE로 처리됨 (Approach 2 모드 등가).
12. **AC12 — Secret 미노출 (P21):** AskUserQuestion이 어떤 단계에서도 secret 값(API_KEY, DB_URL 등 형태의 자유 입력)을 묻지 않는다. 결정 (`yes/no`) / 파일 복사 OK / path 선택만 묻는다. 테스트는 모든 prompt option label을 정규식으로 검사 — secret-like 패턴 (e.g., `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `URL` + free text) 부재.
13. **AC13 — Detector unit test:** `tests/test_detect_runtime.sh`가 4개 시나리오 fixture (web+compose / web+example_only / library+test_only / markdown-only) 모두에서 manifest YAML이 expected output과 일치.
14. **AC14 — Stop-hook state machine test:** `tests/test_stop_hook_state_machine.py`가 `gate3_needs_resolution` transition, `gate3_resolution_iter` 카운터 증가, max 초과 시 `gate3_fail` 격상을 모두 verify.
15. **AC15 — Backward compatibility:** 기존 PASS / FAIL / NEEDS_RESTART verdict 처리는 그대로 동작 (이전 e2e fixture 회귀 없음). 기존 사용자가 `DEVBREW_GATE3_MAX_RESOLUTIONS=0`으로 set하면 v1.7.0 동작과 (silent SKIP 제외하고) 사실상 동일.

## 6. Architecture

```
┌──────────────────┐     ┌──────────────┐     ┌──────────────────┐
│  Skill (Mother)  │     │    Human     │     │ Runtime-Verifier │
│ quality-pipeline │     │              │     │  (Sub-agent)     │
└────────┬─────────┘     └──────┬───────┘     └──────────┬───────┘
         │                      │                        │
         │ ① bash detect-runtime.sh                      │
         │ ◄─ manifest YAML ─                            │
         │                      │                        │
         │ ② AskUserQuestion(decisions only — no values) │
         │ ─────────────────────►                        │
         │ ◄────── booleans/paths ──                     │
         │                      │                        │
         │ skill Bash: cp .env.example .env / docker up  │
         │                      │                        │
         │ ③ Agent(prompt = manifest + decisions)        │
         │ ─────────────────────────────────────────────►│
         │                      │                        │
         │                      │   (attempts each       │
         │                      │    runnable_surface,   │
         │                      │    writes evidence-log)│
         │                      │                        │
         │ ◄────── NEEDS_RESOLUTION{needed:[...]} (option)┤
         │                      │                        │
         │ ④ AskUserQuestion(needed; decisions only)     │
         │ ─────────────────────►                        │
         │ ◄────── retry / skip / abort ──               │
         │                                               │
         │ ⑤ Re-dispatch (gate3_resolution_iter++)       │
         │ ─────────────────────────────────────────────►│
         │                                               │
         │ ◄── PASS / FAIL / SKIP_WITH_EVIDENCE ─────────┤
         │                                               │
         │ ⑥ skill validates evidence-log completeness   │
         │ ⑦ emit qg-signal                              │
```

### 6.1 Components

**A. `scripts/detect-runtime.sh`** (신규, ~150 LoC)
- 입력: 현재 working directory + plan_path (optional, env var로 받음)
- 출력: stdout에 한 줄 YAML — `manifest:` block.
- Read-only. 어떤 파일도 mkdir/write 안 함.
- detection 항목:
  - `project_type`: 기존 runtime-verifier.md Step 1 로직을 그대로 가져옴 (web/cli/library/unknown)
  - `runnable_surfaces`: docker-compose, npm-script (dev/start/serve/test 각각), pytest, cargo test/run, go test/run, manage.py, Makefile run/serve/test
  - `test_runners`: detected runners list (npm/pytest/cargo/go/bun)
  - `mcp_browser`: chrome-devtools | playwright | none — detector가 `claude mcp list` 또는 settings.json 파싱으로 확인
  - `app_url_candidates`: 기본 [http://localhost:3000, http://localhost:8000] + package.json/Procfile/docker-compose에서 파싱한 추가 포트
  - `env_status`: `[{file, exists, has_example}]` 모든 .env / .env.* / config.json 후보
  - `plan_features`: plan_path가 주어지면 `/path`, "form/page" 패턴 grep으로 추출 (best-effort)
- exit 0이 정상. 비정상 exit 시 skill은 fail-open으로 manifest 비어있다고 간주.

**B. `agents/runtime-verifier.md`** (수정, 재작성)
- frontmatter:
  - `cost_class: variable` (was `low`)
  - `allowedTools: [Read, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_chrome-devtools__*, mcp__playwright_*]`
  - `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`
- body:
  - manifest 입력을 받음 (skill이 dispatch 시 inline)
  - manifest의 각 runnable_surface 항목에 대해 attempt → outcome 기록
  - evidence-log 작성 (markdown, .claude/quality-gates/<sid>/gate3-evidence.md)
  - verdict 4종 emit 규칙 명시
  - `NEEDS_RESOLUTION`은 fixable한 missing 발견 시. needed는 decision-form ("Docker daemon 시작 후 재시도", "DB credential을 .env에 추가") — secret 값 받기 안 됨.

**C. `hooks/stop-hook.py`** (수정)
- 새 transition `gate3_needs_resolution` (build_special_prompt + transition logic)
- state file 새 필드:
  - `gate3_resolution_iter: 0` (default)
  - `max_gate3_resolutions: 3` (env override `DEVBREW_GATE3_MAX_RESOLUTIONS` 시 ensure 시 갱신)
- transition 로직 (gate==3):
  - PASS → complete
  - SKIP_WITH_EVIDENCE → complete (skill이 dispatch 전 evidence 검증)
  - NEEDS_RESOLUTION → if iter<max: gate3_needs_resolution else: gate3_fail
  - FAIL / NEEDS_RESTART → gate3_fail
- prompt builder: `gate3_needs_resolution` — agent의 needed 필드를 user-readable choice로 렌더 (proceed_with_retry / skip_this_surface / abort_pipeline)
- repeat detection: 이전 iter의 needed 해시 비교, 동일 시 `gate3_repeat_detected` (proceed=PASS_WITH_WARNINGS / abort)

**D. `skills/quality-pipeline/SKILL.md`** (수정, Gate 3 섹션 재작성)
- pre-flight: `bash scripts/detect-runtime.sh` → manifest 파싱
- AskUserQuestion: manifest의 `requires_decision: true` 항목을 batch로 묻기
- 응답에 따라 skill이 `Bash`로 cp / docker compose up 등 실행
- runtime-verifier dispatch: prompt에 manifest + 사용자 결정 inject
- agent 응답 verdict 분기:
  - SKIP_WITH_EVIDENCE → evidence-log 파일 검증 (모든 manifest의 runnable_surfaces가 attempted) → 통과 시 그대로 emit, 미달 시 FAIL 격상 + 사유 표기
- `gate3_needs_resolution` continuation 처리 (Stop hook 주입 prompt 구별)
- 토큰 절약 fast-path: detector가 runnable_surfaces / test_runners / plan_features 모두 비었다고 보고하면 sub-agent dispatch SKIP, 직접 SKIP_WITH_EVIDENCE emit (with evidence-log: "no runnable surfaces detected")

**E. `scripts/setup-qg.sh`** (수정)
- state schema에 `gate3_resolution_iter: 0`, `max_gate3_resolutions` 필드 추가
- `DEVBREW_GATE3_MAX_RESOLUTIONS` env 읽어서 max에 반영 (default 3, 정수 0–10 clamp)

### 6.2 Data Formats

**Manifest** (`detect-runtime.sh` stdout):

```yaml
project_type: web
runnable_surfaces:
  - kind: docker-compose
    path: docker-compose.yml
    requires_decision: true
  - kind: npm-script
    name: dev
    command: npm run dev
  - kind: npm-script
    name: test
    command: npm test
  - kind: pytest
    command: pytest
test_runners: [npm, pytest]
mcp_browser: chrome-devtools
app_url_candidates: [http://localhost:3000]
env_status:
  - file: .env
    exists: false
    has_example: true
plan_features: [/auth, /dashboard, "login form"]
attempted_log_path: .claude/quality-gates/<sid>/gate3-evidence.md
```

**Evidence-log** (markdown, agent가 작성):

```markdown
# Gate 3 Evidence Log — iteration N

## Attempts
- kind: docker-compose | path: docker-compose.yml
  attempted: yes
  command: docker compose up -d
  outcome: failed
  reason: "Cannot connect to Docker daemon"
  resolvable: yes
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
- kind: plan-feature | feature: /dashboard
  attempted: yes
  outcome: passed
```

**Skill의 evidence-log 검증 로직:**
- manifest의 `runnable_surfaces[].kind+name` set과 evidence-log의 attempted 항목 set 비교
- 누락이 있으면 SKIP_WITH_EVIDENCE 거부
- `plan_features` 도 attempted 항목으로 1:1 매칭 필요

### 6.3 NEEDS_RESOLUTION needed format

Agent가 emit하는 needed 필드는 **결정 form**:

```yaml
needed:
  - kind: docker-daemon
    description: "Docker daemon이 응답하지 않음"
    actions:
      - retry           # 사용자가 다른 터미널에서 docker 실행 후 retry
      - skip_surface    # 이 surface만 skip하고 나머지로 진행
      - abort
  - kind: missing-env-var
    description: "DB_URL이 .env에 없음. 사용자가 직접 .env에 추가 후 재진행"
    actions:
      - retry
      - skip_surface
      - abort
```

skill은 `actions`를 그대로 AskUserQuestion options로 변환. **needed에 secret value field는 정의되지 않음** — 정의되어 있어도 skill이 무시하고 retry/skip/abort만 노출 (P21 enforcement).

## 7. Files to Modify

**신규:**
- `plugins/quality-gates/scripts/detect-runtime.sh` — pre-flight detector (~150 LoC)
- `plugins/quality-gates/tests/test_detect_runtime.sh` — fixture-based test (4 시나리오)
- `plugins/quality-gates/tests/fixtures/gate3/` — 4개 시나리오 fixture 디렉토리

**수정:**
- `plugins/quality-gates/agents/runtime-verifier.md` — frontmatter scoping, verdict taxonomy 4종, manifest-driven attempt, evidence-log 의무
- `plugins/quality-gates/hooks/stop-hook.py` — `gate3_needs_resolution` transition, state field 2개, repeat detection
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — Gate 3 섹션 재작성 (pre-flight + AskUserQuestion + re-dispatch loop + evidence 검증 + fast-path SKIP)
- `plugins/quality-gates/scripts/setup-qg.sh` — state schema 신규 필드, env override
- `plugins/quality-gates/tests/test_stop_hook_state_machine.py` — gate3 transition 테스트
- `plugins/quality-gates/tests/e2e-scenarios.md` — 시나리오 4종 추가
- `plugins/quality-gates/CHANGELOG.md` — `## [1.8.0] — 2026-05-10` entry
- `plugins/quality-gates/.claude-plugin/plugin.json` — version bump (`1.7.0` → `1.8.0`)
- `plugins/quality-gates/README.md` — "Principles Instantiated"에 Law 1 (verification plan 강화) / Law 2 (writer-reviewer 물리 분리 강화) / AP15 / P21 항목 추가

## 8. Verification Plan

**Unit (detector):**
- `tests/test_detect_runtime.sh`로 4 시나리오 fixture에 대해 expected manifest YAML 비교 (AC13)

**Unit (state machine):**
- `tests/test_stop_hook_state_machine.py` 확장 — `gate3_needs_resolution` 진입, iter 카운터, max 초과 격상 (AC8, AC14)

**Static lint:**
- `runtime-verifier.md` frontmatter parse → `disallowedTools`에 `Write`, `Edit` 포함 여부 단언 (AC10, 단순 grep 또는 yaml.safe_load 한 줄)

**Integration (수동 e2e fixture):**
- `tests/e2e-scenarios.md`에 시나리오 A/B/C/D 추가 — 각 fixture에서 `/qg --gate3` 수동 실행 후 verdict 및 evidence-log 검사 (AC1–AC4, AC6–AC7)

**Secret-leakage regression:**
- `tests/test_no_secret_prompts.py` (선택) — SKILL.md와 stop-hook.py의 모든 AskUserQuestion option 텍스트를 grep, secret-like 키워드 (API_KEY/TOKEN/PASSWORD/SECRET/_URL과 free-text 입력) 부재 단언 (AC12)

**Backward compatibility:**
- 기존 e2e fixture (Gate 3가 PASS / FAIL / NEEDS_RESTART) 회귀 없음 (AC15) — `DEVBREW_GATE3_MAX_RESOLUTIONS=0`으로 환경 격리해서 비교

## 9. Rejected Alternatives

**Alt 1 — Approach 1 (Iterative loop only, pre-flight 없음):**
runtime-verifier가 모든 detection을 자기 turn에서 수행하고 NEEDS_RESOLUTION 루프로만 처리. **거부 사유**: agent 자유서술 detection이 fragile (현 문제의 근본), 매 iteration마다 dispatch 비용 큼, fast-path 정당 SKIP이 불가능 (markdown-only repo도 매번 agent 깨움). Hybrid의 deterministic 1차 패스가 안전망 역할을 한다.

**Alt 2 — Approach 2 (Pre-flight only, mid-run escalation 없음):**
사용자의 "끝까지 진행" 요구를 부분 충족만 함. 예측 못한 mid-run 실패 (port 충돌, runtime auth, daemon down)가 곧장 FAIL로 떨어져 "silent SKIP" 문제가 "silent FAIL" 문제로 옮겨갈 뿐. 단, `DEVBREW_GATE3_MAX_RESOLUTIONS=0` 환경변수로 이 모드를 옵트인 가능하게 두어 보수적 사용자도 수용.

**Alt 3 — Agent에게 commit-able 테스트 작성 권한 부여:**
"테스트가 없으면 만들어서라도 검증"의 가장 적극적 해석. **거부 사유**: Law 2 위반 (reviewer가 writer 역할 겸함), 테스트 작성은 별도 워크플로우 (TDD skill)이 책임지는 영역, 자동 생성 테스트는 품질 검증 대상이 더 늘어나는 역설. 대신 NEEDS_RESOLUTION으로 사용자에게 위임.

**Alt 4 — Browser MCP 강제:**
chrome-devtools / playwright MCP 부재 시 Gate 3 자체를 FAIL. **거부 사유**: 사용자 환경 의존성을 강제하면 마켓플레이스 플러그인의 graceful degradation 원칙(Plugin Shape — *"Loud logging을 동반한 graceful degradation"*) 위반. 대신 manifest로 detected 가용성을 명시하고 부재 시 curl + test suite로 fall-through, evidence-log에 명시.

**Alt 5 — Agent에게 secret 값을 prompt로 inject:**
사용자에게 DB_URL을 직접 받아 agent prompt에 넣음. **거부 사유**: P21 (Secret 기록 금지). 대신 사용자가 .env에 직접 추가 후 retry 선택 — agent의 Bash 서브프로세스가 OS-level 환경에서 읽음.

## 10. Metadata

- 작성자: kimjhq97@gmail.com (Jeongho-K)
- 작성 트리거: `/superpowers:brainstorming` 세션, 사용자 요청 "gate3를 개선하려고 해 실제 테스트를 진행함으로서 리뷰하는게 목적인데 스킵하는 경우가 많아서 문제가 있어"
- Sister 의존: `chrome-devtools-mcp` (선택), `playwright` MCP (선택 fallback)
- Predecessor: 없음 (이 부분에 대한 첫 spec)
- Follow-up: writing-plans skill로 implementation plan 작성 → execution
