---
name: law2-agent-tool-surface
type: design-doc
created_at: 2026-07-16
revised_at: 2026-07-16
status: draft — 리뷰 대기
approach: "리뷰어=`tools:` allowlist(fail-closed) / 실행자=denylist+구조적 가드"
plugin: "quality-gates + spec-distill (+ CLAUDE.md 규범)"
version_bump: "quality-gates 2.10.3 → 2.11.0 · spec-distill 0.20.0 → 0.21.0 (minor — 실효 도구 표면 변경)"
implementation: "subagent-driven (TDD)"
supersedes_norm: "CLAUDE.md:25 · CLAUDE.md:41 의 agent 도구 키 서술"
sibling_spec: "PR B = plugin-audit 플러그인 (별도 사이클, docs/handoff/2026-07-12-plugin-maintenance-plugin-handoff.md)"
---

# Law 2 agent 도구 표면 교정 — Design

> **Law 2는 "프롬프트가 아니라 물리적"이라고 선언돼 있다. 지금은 프롬프트다.**
> devbrew의 8개 agent 전부가 존재하지 않는 frontmatter 필드로 격리를 선언하고 있고, 그 허구를 두 개의 집행 메커니즘이 지키고 있다.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 핵심 설계 결정](#5-핵심-설계-결정)
- [6. Agent별 도구 표면](#6-agent별-도구-표면)
- [7. 결함을 지키는 집행 메커니즘 뒤집기](#7-결함을-지키는-집행-메커니즘-뒤집기)
- [8. Acceptance Criteria](#8-acceptance-criteria)
- [9. Files to Modify](#9-files-to-modify)
- [10. Verification Plan](#10-verification-plan)
- [11. Rejected Alternatives](#11-rejected-alternatives)
- [12. Risks](#12-risks)
- [13. Open Questions](#13-open-questions)
- [14. Metadata](#14-metadata)

---

## 1. Context / Why

### 발단

이 스펙은 **`plugin-audit` 플러그인(PR B) 브레인스토밍 중에 발견된 선결 결함**이다. 핸드오프 §8이 *"`allowedTools` vs `tools:` 키 불일치를 **정면으로 다뤄라** — devbrew CLAUDE.md가 요구하는 키가 런타임이 읽는 키와 다르다면, **우리 Law 2 규범 자체가 문서상으로만 존재**하는 것이다"*라고 남긴 숙제였고, 확인해보니 참이었다.

### 확정된 사실 (공식 규격 + 런타임 실측, 2026-07-16)

**공식 문서**(`code.claude.com/docs/en/sub-agents`)의 *Supported frontmatter fields* 표 전체:

> `name`, `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `color`, `memory`, `effort`, `background`, `isolation`, `initialPrompt`

**`allowedTools`는 표에 없다.** 규격에 없는 키이므로 무시되는 것이 정상 동작이다.

| 키 | 공식 규격 | 계층 |
|---|---|---|
| `tools` | ✅ allowlist. *"Inherits all tools if omitted"* | **agent** |
| `disallowedTools` | ✅ denylist. *"removed from inherited or specified list"* | **agent** |
| **`allowedTools`** | ❌ **존재하지 않음** → 조용히 무시 | — |
| `allowed-tools` (하이픈) | ✅ 실재하지만 **command/skill** frontmatter 키 | **command** |
| `--allowedTools` | ✅ 실재하지만 **CLI 플래그** (`claude -p … --allowedTools Edit,Write`) | **CLI** |

> **이름 충돌이 버그의 원인이다.** 세 계층에 비슷한 이름이 있고, agent 계층에만 `allowedTools`가 없다.

**런타임 실측** — 선언 대비 실효 도구 표면 (레지스트리 보고):

| agent | 선언 | 실효 |
|---|---|---|
| `spec-distill:spec-reviewer` | `allowedTools: [Read, Grep, Glob, Bash]` + `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` | **All tools except** 그 4개 |
| `plugin-dev:skill-reviewer` (공식) | `tools: ["Read","Grep","Glob"]` | **정확히** Read, Grep, Glob |

→ `allowedTools`는 무시되고 `tools:`는 강제된다. **플러그인 agent에도 `tools:`가 강제된다**(공식 `plugin-dev`가 실증) — 공식 문서가 *"Ignored for plugin subagents"*로 명시한 것은 `permissionMode`·`mcpServers`·`hooks`뿐이고 `tools`/`disallowedTools`는 그 목록에 없다.

### 그래서 무엇이 뚫렸나

devbrew의 8개 agent 전부 실효 표면이 **"denylist를 뺀 전부"**다. 여기엔 다음이 포함된다:

- **`Agent`** — 공식 문서가 *"서브에이전트에게 제공되지 않는 도구"*로 명시한 것은 `AskUserQuestion`·`EnterPlanMode`·`ExitPlanMode`·`ScheduleWakeup`·`WaitForMcpServers` **5개뿐**이고 `Agent`는 거기 없다. 리뷰어가 `general-purpose`(도구 `*`)를 띄우면 **그 부하가 쓴다.** Write를 뺏고 *"Write를 가진 부하를 부르는 능력"*은 안 뺏은 것 = **위임 사슬로 Law 2 우회**.
- **`Bash`** — `bash -c 'echo x > f'`. 알려진 write vector ([[reference_workflow_law2_agenttype]]).

**지금 당장 사고가 났다는 뜻은 아니다.** denylist가 `Write`/`Edit`을 실제로 막고 있고, persona가 리뷰어에게 고치지 말라고 지시한다. 그러나 그 상태의 이름이 바로 **"분리가 프롬프트에 의존한다"**이며, `CLAUDE.md:25`가 금지한 것이다.

### 가장 나쁜 부분 — 결함이 락으로 굳어 있다

누군가 이 버그의 **절반**을 이미 발견했다. kebab-case(`allowed-tools`)가 agent에 잘못 쓰인 것을 잡고(C1), Law 3 compounding을 적용해 **두 개의 집행 메커니즘**을 신설했다:

| 메커니즘 | 위치 | 무엇을 강제하나 |
|---|---|---|
| **AC15** deny-list 테스트 | `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` | kebab 발견 시 FAIL + *"Expected: allowedTools / disallowedTools (camelCase)"* |
| **AC14** SessionStart 스캐너 | `plugins/quality-gates/hooks/session-start-advisor.py::_scan_agent_frontmatter_keys` | **매 세션** `plugins/*/agents/*.md`를 스캔해 kebab drift 경고 |

**kebab이 틀렸다는 것까진 맞았다 — 그건 command 키니까. 그런데 camelCase도 똑같이 틀리다는 것을 못 봤다.** 그 결과 devbrew에는 지금 **결함을 지키는 회귀 락이 두 겹** 서 있고, 올바른 수정(`tools:`)을 하면 이들이 *"컨벤션 위반"*이라며 막는다.

> 이것이 [[feedback_gate_scope_blind_spot]]의 정확한 실례다 — **결정론 게이트는 자기 regex 밖을 못 본다.** `^(allowed-tools|disallowed-tools):`라는 regex는 *"그런데 `allowedTools`는 유효한가?"*를 물어볼 능력 자체가 없다.

---

## 2. Goals

1. `CLAUDE.md`의 Law 2 · Scoped agents 서술을 **공식 규격에 맞게** 정정한다 — 규범이 사실이 되게.
2. 8개 agent의 도구 표면을 **개별 증거에 근거해** 교정한다. 리뷰어에게서 `Agent`·`Bash`·편집 도구를 **구조적으로** 제거한다.
3. 결함을 지키는 **두 집행 메커니즘(AC14·AC15)을 뒤집어** 올바른 컨벤션을 강제하게 만든다.
4. 그 락이 **이빨을 갖는지 mutation으로 증명**한다.
5. 도구를 잃은 agent가 **실제로 죽지 않음을 동적 dispatch로 실증**한다 — 정적 검사로는 절대 못 잡는 층.

## 3. Non-goals

- **`plugin-audit` 플러그인 (PR B).** 별도 스펙·별도 사이클. 이 PR이 머지된 뒤 그 관찰을 갖고 설계한다.
- **agent persona 본문 재작성.** 이번엔 frontmatter 도구 표면만. persona 변경은 보안-민감 별건이다.
- **`runtime-verifier`의 Law 2 예외 재설계.** 그 예외는 orchestrator의 `git diff` mutation-guard로 이미 구조적으로 보장된다(qg v2.2.0). 도구 표면만 정확히 표기.
- **command/skill의 `allowed-tools` 계층.** 실재하고 올바르다. `scripts/check-allowed-tools-order.sh`와 그 테스트는 **건드리지 않는다** (초기 sweep의 false positive — 건드리면 회귀).
- **과거 기록 재작성.** CHANGELOG 과거 항목 · `docs/handoff/**` · `docs/superpowers/{interview,plans,specs}/**`의 옛 문서는 *당시 사실의 기록*이므로 그대로 둔다.

## 4. Constraints

| # | 제약 | 출처 |
|---|---|---|
| C1 | **레지스트리는 세션 시작에 스냅샷된다.** 편집 후 같은 세션에서 검증하면 옛 값을 보고 **stale GREEN**이 난다 | 원장 19, [[reference_workflow_law2_agenttype]] |
| C2 | **`tools: []`(빈 배열)는 launch 실패.** 공식 docs: *"When nothing in the `tools` list resolves to a tool… Claude Code **refuses to launch** the subagent"* | 공식 문서 |
| C3 | **`disallowedTools` 먼저, 그 다음 `tools`.** *"If both are set, `disallowedTools` is applied first, then `tools` is resolved against the remaining pool"* | 공식 문서 |
| C4 | **작업 전 test baseline 캡처 필수.** main에 stale red가 있어 baseline 없이는 회귀 귀속이 불가능 | [[project_qg_pre_existing_test_reds]] |
| C5 | **플러그인 건드리면 같은 커밋에서 version bump.** 안 하면 cache key가 silent stale | [[feedback_plugin_version_bump]] |
| C6 | **persona/도구 표면은 보안-민감 코드.** 리뷰어를 약화하는 변경은 보안 리뷰 대상 | `CLAUDE.md` |
| C7 | 테스트는 **repo root에서** 실행 | [[project_qg_pre_existing_test_reds]] |

---

## 5. 핵심 설계 결정

### 리뷰어는 allowlist, 실행자는 denylist

**denylist는 fail-open이다.** *"이 4개 빼고 전부"*는 런타임에 새 도구가 추가되면 **자동으로 리뷰어가 갖게 된다.** `Agent`가 정확히 그렇게 들어왔다. allowlist는 **열거되지 않은 모든 것을 자동으로 막는다** (fail-closed) — 미래의 새 도구까지.

**그러나 "전부 allowlist"는 오답이다.** 두 가지 반례가 있다:

- `pr-understanding-builder`는 의도가 *"zero filesystem tools"*인데, 그것을 allowlist로 표현하면 `tools: []`가 되고 **C2에 의해 죽는다.** 의도를 표현할 수 있는 유일한 키가 denylist다.
- `runtime-verifier`는 **Write를 가져야 하는** 실행자다. allowlist로 옮겨도 Law 2가 강화되지 않는다 — 분리가 도구 층이 아니라 orchestrator의 mutation-guard에서 오기 때문이다.

→ **규범은 *"모든 agent는 allowlist"*가 아니라 *"리뷰어는 allowlist, 실행자는 denylist + 구조적 가드"*다.** 이는 `CLAUDE.md`가 이미 v2.2.0 scoped exception으로 인정한 구분을 **도구 키 층위까지 일관되게 내린 것**이다.

### 리뷰어 도구 상한 (판정식)

리뷰어의 `tools:`에 다음이 있으면 **위반**:

`Write` · `Edit` · `MultiEdit` · `NotebookEdit` · **`Agent`** · **`Bash`**

`Bash` 예외를 두려면 **그 근거를 파일 주석에 기록**해야 한다 (침묵 예외 금지).

### 최소 집합의 판정 방법

각 agent의 `tools:`는 추측이 아니라 **두 증거**로 정한다:

1. **persona 본문 전수 읽기** — 본문이 실제로 지시하는 도구 + Inputs 계약이 요구하는 도구.
2. **동적 dispatch 통과** — 실제로 돌려서 자기 산출물을 내는가.

> **왜 이 방법이 필요한가**: 선언된 `allowedTools`는 **한 번도 강제된 적이 없으므로 한 번도 테스트된 적이 없다.** 그것을 그대로 `tools:`로 옮기는 것은 *검증된 적 없는 목록을 사실로 승격*하는 것이다 — 원장 10이 경고하는 바로 그 패턴.

---

## 6. Agent별 도구 표면

`filtered_diff`가 **오케스트레이터에 의해 인라인으로 주입**되고 리뷰어의 cwd 재계산이 **명시적으로 금지**돼 있다는 실측(`security-reviewer.md` Inputs)이 아래 표의 근거다 — 리뷰어는 git을 스스로 돌리지 않는다.

| agent | 현재 실효 | 제안 | 근거 |
|---|---|---|---|
| `security-reviewer` | all except 4 | `tools:` **Read, Grep, Glob** | `filtered_diff` 인라인 수령. `git rev-parse` 재계산 명시 금지 → Bash 불요 |
| `adversarial` | all except 4 | `tools:` **Read, Grep, Glob** | findings를 구조화 블록으로 수령. 동일 |
| `test-scope-validator` | all except 4 | `tools:` **Read, Grep, Glob** | ⚠️ 본문 bash/git 4건 — **구현 시 전수 읽고 확정** |
| `spec-reviewer` | all except 4 | `tools:` **Read, Grep, Glob** | 본문이 Bash를 **한 번도** 지시 안 함 (유일 히트가 자기 frontmatter 줄) |
| `breadth-keeper` | all except 4 | `tools:` **Read, Grep, Glob** | Bash·web 언급 0건 |
| `steelman-builder` | all except 4 | `tools:` **Read, Grep, Glob, WebSearch, WebFetch** | web 3건 · Bash 0건 → Bash 제거는 **개선** |
| `pr-understanding-builder` | all except 11 | 🔴 **denylist 유지** + 죽은 `allowedTools: []` 제거 | C2 — `tools: []`는 launch 실패. 이유를 파일에 기록 |
| `runtime-verifier` | all except 1 | **denylist 유지** + 죽은 `allowedTools`(23) 제거 | 문서화된 실행자 예외. Law 2는 mutation-guard가 보장 |

> **표의 마지막 두 줄이 이 설계의 핵심이다.** "전부 allowlist로"라는 단순한 답이 왜 틀리는지를 이 둘이 증명한다.

---

## 7. 결함을 지키는 집행 메커니즘 뒤집기

### AC15 — `test_agent_frontmatter_keys.sh`

**현재**: kebab 금지 + *"Expected: allowedTools / disallowedTools (camelCase)"*.
**변경 후**: `plugins/**/agents/*.md`에 **`allowedTools`가 존재하면 FAIL** + kebab도 계속 FAIL + 리뷰어 6종이 `tools:`를 갖는지 확인.

### AC14 — `session-start-advisor.py::_scan_agent_frontmatter_keys`

**현재**: kebab drift만 경고.
**변경 후**: `allowedTools`도 경고 대상. kill switch(`DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan`)는 **그대로 유지** — 어떤 훅도 자기 kill switch를 거부할 수 없다.

### 이빨 증명 (필수)

락을 걸고 끝내지 않는다. **일부러 `allowedTools`를 되살린 mutation에서 락이 RED가 되는 것을 확인**한다. RED가 안 나면 그 락은 장식이다 ([[feedback_grep_lock_header_satisfiable]]).

> 이 PR은 **"버그가 리뷰를 탈출하면 잡았어야 할 검증 파일을 편집한다"**는 Law 3의 교과서적 사례다 — 다만 이번엔 그 검증 파일 자체가 범인이었다.

---

## 8. Acceptance Criteria

| # | 기준 | 검증 |
|---|---|---|
| **AC1** | `CLAUDE.md:25`가 agent 격리 메커니즘으로 `allowed-tools`/`disallowed-tools`(하이픈)를 더 이상 지목하지 않는다 | grep |
| **AC2** | `CLAUDE.md:41`이 `allowedTools`를 요구하지 않고, **"리뷰어=`tools:` allowlist / 실행자=denylist + 구조적 가드"** 구분을 명시한다 | grep + 읽기 |
| **AC3** | `plugins/**/agents/*.md` 중 **어떤 파일도** `allowedTools` 키를 갖지 않는다 | 결정론 grep |
| **AC4** | 리뷰어 6종이 `tools:` allowlist를 갖고, 그 목록에 `Write`·`Edit`·`MultiEdit`·`NotebookEdit`·`Agent`·`Bash`가 **없다** (Bash 예외 시 파일에 근거 주석) | 결정론 grep |
| **AC5** | `pr-understanding-builder`는 denylist를 유지하고 `tools:` 키를 **갖지 않는다**. 그 이유(C2)가 파일에 기록된다 | grep + 읽기 |
| **AC6** | `runtime-verifier`는 denylist를 유지하고 Write·Bash·chrome MCP를 **잃지 않는다** | grep |
| **AC7** | **세션 재시작 후** 런타임 레지스트리가 보고하는 8개 agent의 실효 도구 표면이 **선언과 일치**한다 | 실측 기록 (C1) |
| **AC8** | 리뷰어 6종을 각 1회 **실제 dispatch**해 자기 산출물을 낸다 | dispatch 출력 |
| **AC9** | AC15 락이 `allowedTools` 재도입 mutation에서 **RED**가 난다 | mutation test |
| **AC10** | AC14 스캐너가 `allowedTools`를 경고하고, kill switch가 **여전히 동작**한다 | 단위 테스트 |
| **AC11** | qg·spec-distill 기존 스위트가 **baseline 대비 회귀 0** | baseline 대조 (C4) |
| **AC12** | 두 플러그인 `plugin.json` bump + CHANGELOG 항목 | grep |
| **AC13** | `scripts/check-allowed-tools-order.sh`와 command `allowed-tools:`는 **무변경** (계층 C 오염 방지) | `git diff` 확인 |

---

## 9. Files to Modify

### 규범 층
- `CLAUDE.md` — :25 (Law 2) · :41 (Scoped agents)
- `docs/plugin-authoring.md` — :16 · :24
- `docs/philosophy/devbrew-roadmap.md` — :63 · :93 ⚠️ *완료 항목 기록이면 무변경. 구현 시 판정*

### Agent 층 (8)
- `plugins/quality-gates/agents/{security-reviewer,adversarial,test-scope-validator,pr-understanding-builder,runtime-verifier}.md`
- `plugins/spec-distill/agents/{spec-reviewer,breadth-keeper,steelman-builder}.md`

### 집행 층 (결함을 지키던 것들)
- `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` — **뒤집기**
- `plugins/quality-gates/hooks/session-start-advisor.py` — AC14 스캐너
- `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` — 스캐너 테스트

### Per-agent frontmatter 테스트 (키 변경 시 RED)
- `plugins/quality-gates/tests/{test_pr_understanding_builder_frontmatter,test_runtime_verifier_frontmatter,test_test_scope_validator_frontmatter,test_security_reviewer_persona,test_adversarial_persona}.sh`
- `plugins/spec-distill/tests/test_steelman_builder_scope.sh`

### 메커니즘 서술 산문
- `plugins/quality-gates/README.md` — :32
- `plugins/spec-distill/README.md` — :59 · :84
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — :48

### 버전
- `plugins/quality-gates/.claude-plugin/plugin.json` **2.10.3 → 2.11.0** + `CHANGELOG.md`
- `plugins/spec-distill/.claude-plugin/plugin.json` **0.20.0 → 0.21.0** + `CHANGELOG.md`

### 명시적 무변경 (계층 C — 건드리면 회귀)
- `plugins/quality-gates/scripts/check-allowed-tools-order.sh` + `tests/test_check_allowed_tools_order.sh`
- `plugins/*/commands/*.md` · `skills/*/SKILL.md`의 `allowed-tools:`
- CHANGELOG 과거 항목 · `docs/handoff/**` · `docs/superpowers/{interview,plans,specs}/**` 옛 문서

---

## 10. Verification Plan

**0. Baseline (선행 필수)** — C4. 작업 전 두 플러그인 스위트를 repo root에서 돌려 red 목록을 기록.

**1. 정적** — AC3·AC4·AC5·AC6·AC13 결정론 grep. AC9 mutation test.

**2. 레지스트리 실측 (세션 재시작 필요)** — C1. 편집·커밋 후 **세션을 재시작**하고, 런타임이 보고하는 8개 agent의 실효 표면을 선언과 대조. **이 단계 없이는 AC7이 stale GREEN이다.**

**3. 동적 dispatch** — AC8. 리뷰어 6종을 실제로 1회씩 돌린다. 관심 대상:
- `security-reviewer` — WebSearch 없이 보안 판정이 서는가
- `test-scope-validator` — Bash 없이 테스트 파일 분류가 되는가
- `steelman-builder` — WebSearch/WebFetch로 충분한가

> **이 층이 종이가 못 잡는 것을 잡는다.** 감사 하니스가 종이 15리비전을 통과하고 실행 첫 dispatch에서 죽은 것이 이번 사이클의 실증이다 ([[feedback_harness_is_means_not_end]]).

**4. 회귀** — AC11. baseline 대조.

**5. `/qg`** — 전 파이프라인. ⚠️ **자기참조 주의**: 이 PR이 고치는 리뷰어가 이 PR을 리뷰한다. codex(모델 다양성·외부 프로세스)의 독립 판정이 특히 load-bearing.

---

## 11. Rejected Alternatives

| 대안 | 왜 기각 |
|---|---|
| **8개 전부 `tools:` allowlist** | `pr-understanding-builder`가 `tools: []`로 **launch 실패**(C2). `runtime-verifier`는 allowlist가 Law 2를 강화하지 않음 |
| **denylist에 `Agent`만 추가 (최소 수술)** | fail-open이 남는다. 다음 새 도구가 또 자동으로 리뷰어에게 들어온다. `Agent`가 이미 그렇게 들어왔다 |
| **문서만 고치고 agent는 그대로** | 규범이 사실이 되는 게 목표. 문서만 고치면 *"규범은 맞는데 코드가 안 따름"*으로 상태만 바뀜 |
| **PR B(plugin-audit)를 먼저 만들어 /audit이 잡게** | 순환. 살아있는 Law 2 구멍을 한 사이클 더 방치. 그리고 PR B의 Law 2가 **바로 이 메커니즘 위에 선다** |
| **PR A·B를 한 브랜치에** | 리뷰어가 *"보안 수술 + 신규 플러그인"*을 한꺼번에 봐야 함. devbrew가 보안-민감 변경을 섞지 말라고 규정(C6) |
| **`check-allowed-tools-order.sh`도 정리** | **false positive.** command/skill `allowed-tools`는 실재하고 올바름. 건드리면 회귀 |

---

## 12. Risks

| 리스크 | 완화 |
|---|---|
| allowlist 저술 시 필요한 도구 누락 → **리뷰어 조용한 열화** (예: `security-reviewer`가 WebSearch로 CVE를 찾고 있었다면) | §10-3 동적 dispatch. **정적 검사로는 절대 안 잡힘** |
| `pr-understanding-builder` → `tools: []` → **launch 실패** | §6에서 denylist 유지로 못 박음 + 파일에 근거 주석 + AC5 |
| 세션 재시작 없이 검증 → **stale GREEN** | C1을 §10-2의 전제조건으로 명시 |
| 자기참조 — 고치는 리뷰어가 자기 PR을 리뷰 | codex 모델 다양성 + 결정론 grep + mutation test |
| 두 플러그인 동시 수정 → 버전/CHANGELOG 누락 | C5 · AC12 |
| 계층 C(command `allowed-tools`) 오염 | AC13 — `git diff`로 무변경 확인 |
| 새 락이 또 **자기 regex 밖을 못 봄** | AC9 mutation + [[feedback_gate_scope_blind_spot]] |

---

## 13. Open Questions

| # | 질문 | 언제 답하나 |
|---|---|---|
| **OQ1** | `test-scope-validator`가 Bash를 **실제로** 쓰는가? (본문 bash/git 4건) | 구현 — persona 전수 읽기 + 동적 dispatch |
| **OQ2** | `security-reviewer`에 WebSearch가 필요한가? (CVE 조회) | 구현 — 동적 dispatch |
| **OQ3** | `devbrew-roadmap.md`:63·:93은 **완료 항목 기록**인가 활성 규범인가? | 구현 — 읽고 판정. 기록이면 무변경 |
| **OQ4** | 리뷰어에게 `Skill`·`TodoWrite`가 필요한가? | 구현 — 동적 dispatch에서 관측 |

> **OQ가 남아 있는 것은 결함이 아니다.** 이들은 전부 *"증거로만 답할 수 있고, 그 증거는 실행에서 나온다"*는 부류다. 종이 위에서 추측으로 닫으면 원장 10(확정 사실이 사각지대가 된다)을 재생산한다.

---

## 14. Metadata

| | |
|---|---|
| 발단 | PR B(`plugin-audit`) 브레인스토밍 중 발견 — 핸드오프 §8의 *"정면으로 다뤄라"* 숙제 |
| 근거 | 공식 문서 `code.claude.com/docs/en/sub-agents` (frontmatter 필드 표) + 런타임 레지스트리 실측 + 공식 `plugin-dev` 3종 대조 |
| 대상 | `quality-gates` 2.10.3 → 2.11.0 · `spec-distill` 0.20.0 → 0.21.0 · `CLAUDE.md` |
| 형제 | **PR B = `plugin-audit` 플러그인** — 이 PR 머지 후 별도 스펙. 재개점 = `docs/handoff/2026-07-12-plugin-maintenance-plugin-handoff.md` |
| Law | **Law 2** (분리를 물리적 사실로) · **Law 3** (버그를 놓친 검증 파일을 편집 — 이번엔 그 파일이 범인) |
| 구현 | subagent-driven (TDD). ⚠️ **구현 중간에 세션 재시작이 끼어든다** (C1) — 핸드오프가 재개를 감당해야 함 |
