---
name: law2-agent-tool-surface
type: design-doc
created_at: 2026-07-16
revised_at: 2026-07-16
status: draft — review round 2 (round 1 = needs_revise, claude+codex 독립 일치; 8건 반영)
approach: "리뷰어=`tools:` allowlist(fail-closed) / 실행자=denylist + `mcp__*` + 구조적 가드"
plugin: "quality-gates + spec-distill (+ CLAUDE.md 규범)"
version_bump: "quality-gates 2.10.3 → 2.11.0 · spec-distill 0.20.0 → 0.21.0 (minor — 실효 도구 표면 변경)"
implementation: "subagent-driven (TDD)"
supersedes_norm: "CLAUDE.md:25 · CLAUDE.md:41 의 agent 도구 키 서술"
sibling_spec: "PR B = plugin-audit 플러그인 (별도 사이클, docs/handoff/2026-07-12-plugin-maintenance-plugin-handoff.md 원장 49)"
---

# Law 2 agent 도구 표면 교정 — Design

> **Law 2는 "프롬프트가 아니라 물리적"이라고 선언돼 있다. 지금은 프롬프트다.**
> devbrew의 8개 agent 전부가 **denylist만으로** 격리되고 있고(fail-open), 그중 5개는 그 위에 **존재하지 않는 필드**로 allowlist를 선언한다(불활성). 그리고 그 허구를 **두 개의 집행 메커니즘이 지키고 있다.**

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
- [Handoff Context](#handoff-context)

---

## 1. Context / Why

### 발단

이 스펙은 **`plugin-audit` 플러그인(PR B) 브레인스토밍 중에 발견된 선결 결함**이다. 핸드오프 §8이 *"`allowedTools` vs `tools:` 키 불일치를 **정면으로 다뤄라** — devbrew CLAUDE.md가 요구하는 키가 런타임이 읽는 키와 다르다면, **우리 Law 2 규범 자체가 문서상으로만 존재**하는 것이다"*라고 남긴 숙제였고, 확인해보니 참이었다.

### 확정된 사실 — 공식 규격 (2026-07-16 fetch, 리뷰 round 1에서 독립 재확인)

`code.claude.com/docs/en/sub-agents`의 *Supported frontmatter fields* 표 전체:

> `name`, `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `color`, `memory`, `effort`, `background`, `isolation`, `initialPrompt`

**`allowedTools`는 표에 없다.** 규격에 없는 키이므로 무시되는 것이 정상 동작이다.

| 키 | 공식 규격 | 계층 |
|---|---|---|
| `tools` | ✅ allowlist. *"Inherits all tools if omitted"* | **agent** |
| `disallowedTools` | ✅ denylist. *"removed from inherited or specified list"* | **agent** |
| **`allowedTools`** | ❌ **존재하지 않음** → 조용히 무시 | — |
| `allowed-tools` (하이픈) | ✅ 실재하지만 **command/skill** frontmatter 키 | **command** |
| `--allowedTools` | ✅ 실재하지만 **CLI 플래그** | **CLI** |

**이름 충돌이 버그의 원인이다.** 세 계층에 비슷한 이름이 있고 agent 계층에만 `allowedTools`가 없다.

공식 문서의 결정적 문장 셋 (구현 시 이 문구들이 판정 근거):
- *"To prevent a specific subagent from spawning others, **omit `Agent` from its `tools` list or add it to `disallowedTools`**"* — 위임 사슬이 공식적으로 인정된 벡터다.
- *"When nothing in the `tools` list resolves to a tool… Claude Code **refuses to launch** the subagent"* — `tools: []`는 죽는다.
- *"In `disallowedTools`, **`mcp__*` also removes every MCP tool from any server**"* — MCP를 막는 방법이 존재한다.

### 두 개의 서로 다른 결함 (실측 — 개별 파일 grep)

리뷰 round 1이 *"8개 전부가 허구 필드로 선언"*이라는 초고의 서술을 **반증**했다. 정확한 사실은 이렇다:

| 결함 | 해당 agent | 성격 |
|---|---|---|
| **A — 불활성 allowlist** | **5/8**: `pr-understanding-builder`, `runtime-verifier`, `test-scope-validator`, `spec-reviewer`, `steelman-builder` | 존재하지 않는 `allowedTools`를 선언 → **최소권한 의도가 한 번도 집행된 적 없음** |
| **B — fail-open denylist** | **8/8** (A에 해당 안 되는 `security-reviewer`·`adversarial`·`breadth-keeper` 3개 포함 — 이들은 `disallowedTools`만 선언하며 그건 **정상 필드**다) | 실효 표면 = *"denied 뺀 전부"* → 새 도구가 추가되면 **자동으로 리뷰어가 갖는다** |

> **결함 B가 본체다.** A는 "의도가 표현되지 못했다"이고, B는 "표현된 의도조차 fail-open이다". 3개 agent는 A가 없지만 B는 있다 — 즉 **허구 필드를 지우는 것만으로는 아무것도 고쳐지지 않는다.**

### 결함 B가 실제로 무엇을 열어놨나

- **`Agent`** — 공식 문서상 서브에이전트 미제공 도구는 `AskUserQuestion`·`EnterPlanMode`·`ExitPlanMode`·`ScheduleWakeup`·`WaitForMcpServers` **5개뿐**이고 `Agent`는 거기 없다. 리뷰어가 `general-purpose`(도구 `*`)를 띄우면 **그 부하가 쓴다.** Write를 뺏고 *"Write를 가진 부하를 부르는 능력"*은 안 뺏었다.
- **`Bash`** — `bash -c 'echo x > f'`. 알려진 write vector ([[reference_workflow_law2_agenttype]]).
- **🔴 `mcp__*`** — 아래 참조. 리뷰 round 1이 가리킨 README 줄을 따라가다 발견됐다.

### 🔴 살아있는 보안 구멍 — `pr-understanding-builder`의 MCP 경로

`README.md:47`이 이 agent를 **pwn-request 방어**로 규정한다 (verbatim):

> *"`pr-understanding-builder` 에이전트는 `allowedTools: []`(파일시스템·**네트워크 tool 0개**, 유일 입력 = inlined blob)로 저술만 하고, `gh`/네트워크는 오직 `publishing-pr-understanding` skill만 보유한다. **생성기가 스스로를 게시할 길이 구조적으로 없다.**"*

**그 서술은 거짓이다.** `allowedTools: []`는 불활성이고, 실효 표면은 `disallowedTools` 11개(`Write`·`Edit`·`MultiEdit`·`NotebookEdit`·`Read`·`Grep`·`Glob`·`Bash`·`WebFetch`·`WebSearch`·`Agent`)를 뺀 **전부**다. 그 11개에 **`mcp__*`가 없다** (파일 내 `mcp` 언급 **0회** — 실측).

→ *"네트워크 도구 0개"*라고 광고된 agent가 현재 **tavily 웹검색·chrome-devtools 브라우저 제어·computer-use를 포함한 모든 MCP 도구를 보유**한다. `WebFetch`/`WebSearch`만 막고 **같은 능력의 MCP 경로를 열어둔 것**이다. 공식 문서가 `mcp__*` 패턴을 제공하는데 쓰지 않았다.

> **이것이 초고 §6의 오류를 무너뜨린다.** 초고는 이 agent를 *"denylist 유지"*로 넘겼다. 그러나 **denylist가 정확히 실패하고 있는 지점**이 여기다.

### 가장 나쁜 부분 — 결함이 락으로 굳어 있고, 그 출생 기록이 남아 있다

누군가 이 버그의 **절반**을 이미 발견했다(C1 = kebab-case가 agent에 잘못 쓰임). 그리고 Law 3 compounding을 적용해 집행기 둘을 신설했다 — **고친 방향이 틀렸다** (kebab→camel; 정답은 kebab→`tools:`):

| 메커니즘 | 위치 | 무엇을 강제하나 |
|---|---|---|
| **AC15** deny-list 테스트 | `quality-gates/tests/test_agent_frontmatter_keys.sh` | kebab FAIL + *"Expected: allowedTools / disallowedTools (camelCase)"* |
| **AC14** SessionStart 스캐너 | `quality-gates/hooks/session-start-advisor.py::_scan_agent_frontmatter_keys` | **매 세션** `plugins/*/agents/*.md` kebab drift 경고 |

그리고 `README.md:30`이 **출생 기록**이다 (verbatim):

> *"(1) frontmatter `allowedTools`/`disallowedTools` camelCase deny/allow whitelist (**AC1 fix, v1.11.1에서 복구**), (2) narrow `Bash` allowlist (**실제 키 `allowedTools`**) … **Layer 1 없이 Layer 2/3는 불완전**"*

허구 필드가 *"실제 키"*로 명명되고, 3중 격리의 **Layer 1(불가결)**으로 규정되고, *"복구"*됐다고 기록됐다. **Layer 1은 작동한 적이 없다.**

> [[feedback_gate_scope_blind_spot]]의 교과서적 실례 — **결정론 게이트는 자기 regex 밖을 못 본다.** `^(allowed-tools|disallowed-tools):`는 *"그런데 camelCase는 유효한가?"*를 물어볼 능력이 없다.
> **일반화된 교훈: 결함을 반쯤 고치고 락을 걸면, 락이 나머지 절반을 영구화한다.**

---

## 2. Goals

1. `CLAUDE.md`의 Law 2 · Scoped agents 서술을 **공식 규격에 맞게** 정정한다 — 규범이 사실이 되게.
2. 8개 agent의 도구 표면을 **개별 증거에 근거해** 교정한다. 리뷰어에게서 `Agent`·`Bash`·`mcp__*`·편집 도구를 **구조적으로** 제거한다.
3. **`pr-understanding-builder`의 MCP 구멍을 닫는다** — README:47이 광고하는 pwn-request 방어를 사실로 만든다.
4. 결함을 지키는 **두 집행 메커니즘(AC14·AC15)을 뒤집어** 올바른 컨벤션을 강제하게 만든다.
5. 그 락이 **이빨을 갖는지 mutation으로 증명**한다.
6. 도구를 잃은 agent가 **실제로 죽지 않음을 결정론 assertion이 붙은 동적 dispatch로 실증**한다.

## 3. Non-goals

- **`plugin-audit` 플러그인 (PR B).** 별도 스펙·별도 사이클.
- **agent persona 본문 재작성.** frontmatter 도구 표면 + 거짓이 된 서술 문장만. persona 로직 변경은 별건.
- **`runtime-verifier`의 Law 2 예외 재설계.** 그 예외는 orchestrator `git diff` mutation-guard로 이미 구조적으로 보장된다(qg v2.2.0).
- **command/skill의 `allowed-tools` 계층.** 실재·정상. `scripts/check-allowed-tools-order.sh`와 그 테스트는 **건드리지 않는다** (초고 sweep의 false positive — 건드리면 회귀).
- **과거 기록 재작성.** CHANGELOG 과거 항목 · `docs/handoff/**` · `docs/superpowers/{interview,plans,specs}/**` 옛 문서는 *당시 사실의 기록*이다.

## 4. Constraints

| # | 제약 | 출처 |
|---|---|---|
| C1 | **레지스트리는 세션 시작에 스냅샷된다.** 편집 후 같은 세션 검증 = **stale GREEN** | 원장 19, [[reference_workflow_law2_agenttype]] |
| C2 | **`tools: []`는 launch 실패** (공식 문서) | 공식 문서 |
| C3 | **`disallowedTools` 먼저, 그 다음 `tools`** | 공식 문서 |
| C4 | **작업 전 test baseline 캡처 필수** — main에 stale red 존재 | [[project_qg_pre_existing_test_reds]] |
| C5 | **플러그인 건드리면 같은 커밋에서 version bump** | [[feedback_plugin_version_bump]] |
| C6 | **persona/도구 표면은 보안-민감 코드** | `CLAUDE.md` |
| C7 | 테스트는 **repo root에서** 실행 | [[project_qg_pre_existing_test_reds]] |
| C8 | **`mcp__*`는 `disallowedTools`에서만 와일드카드로 동작.** `tools:` allowlist는 열거하지 않으면 자동 배제 | 공식 문서 |

---

## 5. 핵심 설계 결정

### 리뷰어는 allowlist, 실행자는 denylist + `mcp__*`

**denylist는 fail-open이다.** *"이 N개 빼고 전부"*는 런타임에 새 도구·새 MCP 서버가 추가되면 **자동으로 agent가 갖는다.** `Agent`가 그렇게 들어왔고, MCP 서버가 그렇게 들어왔다. allowlist는 **열거되지 않은 모든 것을 자동으로 막는다** (fail-closed) — 미래 도구까지.

**그러나 "전부 allowlist"는 오답이다.** 두 반례:

- `pr-understanding-builder`의 의도는 *"zero tools"*인데 allowlist로 표현하면 `tools: []` → **C2로 죽는다.**
- `runtime-verifier`는 **Write를 가져야 하는** 실행자다. allowlist로 옮겨도 Law 2가 강화되지 않는다 — 분리가 orchestrator mutation-guard에서 오기 때문이다.

→ **규범 = "리뷰어는 `tools:` allowlist / 실행자는 denylist + `mcp__*` + 구조적 가드".** `CLAUDE.md`가 v2.2.0 scoped exception으로 이미 인정한 구분을 도구 키 층위까지 일관되게 내린 것.

### 판정식 — 리뷰어 도구 상한

리뷰어의 `tools:`에 다음이 있으면 **위반**: `Write` · `Edit` · `MultiEdit` · `NotebookEdit` · `Agent` · `Bash` · `mcp__`로 시작하는 모든 것.

**침묵 예외 금지 — 예외는 기계가 읽을 수 있어야 한다.** `Bash`가 필요하면 그 agent 파일에 정확히 이 마커를 둔다:

```
# BASH-EXCEPTION: <한 줄 근거>
```

결정론 락은 `tools:`에 `Bash`가 있는데 이 마커가 **없으면 FAIL**한다. 마커 없는 Bash = 위반.

### denylist agent의 상한

`disallowedTools`를 쓰는 agent는 **반드시 `mcp__*`를 포함**한다 (C8). 예외는 MCP가 그 agent의 일에 필수인 경우뿐이며(`runtime-verifier`의 chrome-devtools), 그때는 **서버 단위로 열거**한다 — 전면 개방 금지.

### 최소 집합의 판정 방법

각 agent의 `tools:`는 추측이 아니라 **두 증거**로 정한다:

1. **persona 본문 전수 읽기** — 본문이 실제로 지시하는 도구 + Inputs 계약이 요구하는 도구.
2. **결정론 assertion이 붙은 동적 dispatch** (§10-3) — 실제로 돌려서 **문서화된 출력 계약**을 만족하는가.

> **왜 필요한가**: 선언된 `allowedTools`는 **한 번도 강제된 적이 없으므로 한 번도 테스트된 적이 없다.** 그대로 `tools:`로 옮기는 것은 *검증된 적 없는 목록을 사실로 승격*하는 것 = 원장 10 재생산. 실제로 round 1에서 초고 자신이 이 기준을 어겼다(§1 서사 오류).

---

## 6. Agent별 도구 표면

**근거 실측**: `filtered_diff`는 **오케스트레이터가 인라인 주입**하고 리뷰어의 cwd 재계산은 **명시적으로 금지**된다 → 리뷰어는 git을 스스로 돌리지 않는다.

| agent | 현재 실효 | 제안 | 근거 (persona 본문) |
|---|---|---|---|
| `security-reviewer` | all except 4 | `tools:` **Read, Grep, Glob** | `filtered_diff` 인라인 수령. `:42` *"Flag each entry so downstream review can verify CVE status. **Do not run audit commands yourself.**"* → **web 불요** (OQ2 해소) |
| `adversarial` | all except 4 | `tools:` **Read, Grep, Glob** | findings를 구조화 블록으로 수령 |
| `test-scope-validator` | all except 4 | `tools:` **Read, Grep, Glob** | `:48` *"No `curl`, no `WebFetch`, **no MCP**. **`Bash` is for reading files (`cat`, `head`, `wc`) only**"* → Bash는 **Read의 대용**. Read 부여 = 동일 능력·더 적은 권한 → **Bash 불요** (OQ1 해소) |
| `spec-reviewer` | all except 4 | `tools:` **Read, Grep, Glob** | 본문이 Bash를 **한 번도** 지시 안 함 (유일 히트가 자기 frontmatter 줄) |
| `breadth-keeper` | all except 4 | `tools:` **Read, Grep, Glob** | Bash·web 언급 0건 |
| `steelman-builder` | all except 4 | `tools:` **Read, Grep, Glob, WebSearch, WebFetch** | web 3건 · Bash 0건 → Bash 제거는 **개선** |
| `pr-understanding-builder` | all except 11 (**MCP 보유**) | 🔴 **denylist + `mcp__*`** + 죽은 `allowedTools: []` 제거 | C2로 `tools: []` 불가. **MCP 구멍이 본 PR의 보안 핵심** |
| `runtime-verifier` | all except 1 | **denylist 유지** + 죽은 `allowedTools`(**22**개) 제거 + **MCP를 서버 단위로 축소** | 문서화된 실행자 예외. chrome-devtools는 필요하나 전 MCP 개방은 불요 |

> **`pr-understanding-builder`와 `runtime-verifier`가 이 설계의 핵심이다.** "전부 allowlist로"라는 단순한 답이 왜 틀리는지(C2·실행자 예외)를 증명하는 동시에, **denylist를 택한 두 agent야말로 `mcp__*` 누락으로 지금 뚫려 있다**는 것을 보여준다.

---

## 7. 결함을 지키는 집행 메커니즘 뒤집기

### AC15 — `test_agent_frontmatter_keys.sh`

**현재**: kebab 금지 + *"Expected: allowedTools / disallowedTools (camelCase)"*.
**변경 후**: `plugins/**/agents/*.md`에 대해
- `allowedTools` 존재 → **FAIL** (kebab도 계속 FAIL)
- 리뷰어 6종이 `tools:`를 갖고 그 목록에 금지 도구(§5 판정식)가 **없음** → 아니면 FAIL
- `Bash` 보유 시 `# BASH-EXCEPTION:` 마커 부재 → FAIL
- `disallowedTools`를 쓰는 agent에 `mcp__*` 부재 → FAIL

### AC14 — `session-start-advisor.py::_scan_agent_frontmatter_keys`

**현재**: kebab drift만 경고. **변경 후**: `allowedTools`도 경고 대상. kill switch(`DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan`)는 **그대로 유지** — 어떤 훅도 자기 kill switch를 거부할 수 없다.

### 이빨 증명 (필수)

락을 걸고 끝내지 않는다. **일부러 결함을 되살린 mutation마다 락이 RED가 되는 것을 확인**한다 (§10-1). RED가 안 나면 그 락은 장식이다 ([[feedback_grep_lock_header_satisfiable]]).

> 이 PR은 **"버그가 리뷰를 탈출하면 잡았어야 할 검증 파일을 편집한다"**는 Law 3의 교과서적 사례다 — 다만 이번엔 그 검증 파일 자체가 범인이었다.

---

## 8. Acceptance Criteria

| # | 기준 | 검증 |
|---|---|---|
| **AC1** | `CLAUDE.md:25`가 agent 격리 메커니즘으로 `allowed-tools`/`disallowed-tools`(하이픈)를 지목하지 않는다 | grep |
| **AC2** | `CLAUDE.md:41`이 `allowedTools`를 요구하지 않고 **"리뷰어=`tools:` allowlist / 실행자=denylist + `mcp__*` + 구조적 가드"**를 명시한다 | grep + 읽기 |
| **AC3** | `plugins/**/agents/*.md` 중 **어떤 파일도** `allowedTools` 키를 갖지 않는다 | 결정론 grep |
| **AC4** | 리뷰어 6종이 `tools:` allowlist를 갖고, 목록에 `Write`·`Edit`·`MultiEdit`·`NotebookEdit`·`Agent`·`Bash`·`mcp__*`가 **없다**. `Bash` 보유 시 **`# BASH-EXCEPTION:` 마커 필수** (마커 없으면 FAIL) | 결정론 grep |
| **AC5** | `pr-understanding-builder`는 `tools:` 키를 갖지 않고(C2), `disallowedTools`에 **`mcp__*`를 포함**한다. C2 근거가 파일에 기록된다 | 결정론 grep |
| **AC6** | `runtime-verifier`는 denylist를 유지하고 Write·Bash를 잃지 않으며, MCP가 **서버 단위로 한정**된다(전면 개방 아님) | grep |
| **AC7** | **세션 재시작 후**, 8개 agent의 **런타임 레지스트리가 보고하는 실효 도구 표면**이 선언과 일치한다. **agent 자기-보고는 증거로 쓰지 않는다** — 레지스트리(하니스의 resolved view)가 ground truth | 재시작 후 레지스트리 ↔ frontmatter 대조표 기록 (C1) |
| **AC8** | 리뷰어 6종을 **고정 fixture**로 각 1회 dispatch해 **문서화된 출력 계약**을 만족한다 — 각각 (a) launch 성공, (b) 해당 스키마의 **비어있지 않은** 블록 산출, (c) fixture에 심어둔 **기대 신호를 실제로 검출**, (d) 금지 도구 호출 시도 0회. **"산출물을 냈다"만으로는 불충분** | §10-3 |
| **AC9** | AC15 락이 mutation 4종 각각에서 **RED**: ①`allowedTools` 재도입 ②리뷰어에 `Agent` 추가 ③마커 없는 `Bash` 추가 ④denylist agent에서 `mcp__*` 제거 | mutation test |
| **AC10** | AC14 스캐너가 `allowedTools`를 경고하고, kill switch가 **여전히 동작**한다 | 단위 테스트 |
| **AC11** | qg·spec-distill 기존 스위트가 **baseline 대비 회귀 0** | baseline 대조 (C4) |
| **AC12** | 두 플러그인 `plugin.json` bump + CHANGELOG 항목 | grep |
| **AC13** | `scripts/check-allowed-tools-order.sh`와 command `allowed-tools:`는 **무변경** | `git diff` |
| **AC14** | `allowedTools`를 **로드베어링 메커니즘으로 서술하는 산문**이 하나도 남지 않는다 — `README.md:30`(*"실제 키"*·*"Layer 1 없이 불완전"*) · `:47`·`:63`(*"네트워크 tool 0개"*) 포함 | 결정론 grep + 읽기 |
| **AC15** | `spec-reviewer`·`breadth-keeper`가 다른 4개 리뷰어와 **동등한 회귀 락**을 갖는다 (현재 부재) | 테스트 존재 + mutation |

---

## 9. Files to Modify

### 규범 층
- `CLAUDE.md` — :25 (Law 2) · :41 (Scoped agents)
- `docs/plugin-authoring.md` — :16 · :24
- `docs/philosophy/devbrew-roadmap.md` — :63 · :93 ⚠️ *완료 항목 기록이면 무변경. 구현 시 판정 (OQ3)*

### Agent 층 (8)
- `plugins/quality-gates/agents/{security-reviewer,adversarial,test-scope-validator,pr-understanding-builder,runtime-verifier}.md`
- `plugins/spec-distill/agents/{spec-reviewer,breadth-keeper,steelman-builder}.md`

### 집행 층 (결함을 지키던 것들)
- `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` — **뒤집기 + 4종 판정 추가**
- `plugins/quality-gates/hooks/session-start-advisor.py` — AC14 스캐너
- `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` — 스캐너 테스트

### Per-agent 회귀 테스트
- 기존(키 변경 시 RED): `plugins/quality-gates/tests/{test_pr_understanding_builder_frontmatter,test_runtime_verifier_frontmatter,test_test_scope_validator_frontmatter,test_security_reviewer_persona,test_adversarial_persona}.sh` · `plugins/spec-distill/tests/test_steelman_builder_scope.sh`
- **신설(AC15)**: `spec-reviewer`·`breadth-keeper` 도구 표면 락 — 다른 4종과 동등 수준

### 거짓이 된 서술 산문
- `plugins/quality-gates/README.md` — **:30**(출생 기록: *"실제 키"*·*"Layer 1 없이 불완전"*) · **:47**(*"네트워크 tool 0개"* pwn-request 주장) · **:63**(트리 주석) · :11·:19·:27·:29·:31(denylist 서술 — §5 규범 변경 반영 여부 판정)
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

**0. Baseline (선행 필수)** — C4. 작업 전 두 플러그인 스위트를 repo root에서 돌려 red 목록을 파일로 기록. **재시작 후 세션이 이 파일을 읽는다.**

**1. 정적 + mutation** — AC3·AC4·AC5·AC6·AC13·AC14 결정론 grep. **AC9의 mutation 4종**을 각각 넣고 락이 RED인지 확인 후 되돌린다.

**2. 레지스트리 실측 (세션 재시작 필요)** — C1. 편집·커밋 후 **세션 재시작**, 런타임 레지스트리가 보고하는 8개 실효 표면을 frontmatter 선언과 대조해 표로 기록. **agent에게 "무슨 도구 있니?"라고 묻지 않는다** — 자기-보고는 증거가 아니다. 레지스트리는 하니스 자신의 resolved view다.

> **이 방법의 한계를 정직하게**: 레지스트리는 *보고*이지 *실행*이 아니다. 실행 층은 3이 덮는다. persona가 거절하는 것과 도구가 없는 것을 구별하려면 persona 없는 프로브가 필요한데(원장 21), 대상 리뷰어들은 persona를 가진다 — 그래서 AC8이 "금지 도구 호출 시도 0회"를 **행동**으로 본다.

**3. 동적 dispatch — 고정 fixture + 결정론 assertion** (AC8). 각 리뷰어에게 **기대 신호를 심어둔 fixture**를 주고 그것을 검출하는지 본다:

| agent | fixture | 기대 (assertion) |
|---|---|---|
| `security-reviewer` | 명백한 취약점 1개를 심은 diff | 비어있지 않은 finding YAML + **그 취약점을 검출** |
| `adversarial` | 명백한 FP 1건 + 진짜 1건 | 두 판정이 갈림 |
| `test-scope-validator` | `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}` **기존 fixture 재사용** | 각 분류를 맞힘 + `test_scope_verdicts` YAML |
| `spec-reviewer` | 알려진 결함 있는 design doc | `spec-review-issues` sentinel JSON 비어있지 않음 |
| `breadth-keeper` | 한 dimension에 편중된 라운드 | lateral 질문 산출 |
| `steelman-builder` | 대안이 명백한 방향 | web 근거 포함 steelman |

**공통 assertion**: launch 성공 · 스키마 유효 · **금지 도구 호출 시도 0회**.

> **이 층이 종이가 못 잡는 것을 잡는다.** 감사 하니스가 종이 15리비전을 통과하고 실행 첫 dispatch에서 죽은 것이 이번 사이클의 실증이다 ([[feedback_harness_is_means_not_end]]).

**4. 회귀** — AC11. baseline 대조.

**5. `/qg`** — 전 파이프라인. ⚠️ **자기참조 주의**: 이 PR이 고치는 리뷰어가 이 PR을 리뷰한다. codex(외부 프로세스·모델 다양성)의 독립 판정이 특히 load-bearing — round 1에서 실제로 codex가 AC8 fail-open을 단독 적발했다.

---

## 11. Rejected Alternatives

| 대안 | 왜 기각 |
|---|---|
| **8개 전부 `tools:` allowlist** | `pr-understanding-builder`가 `tools: []`로 **launch 실패**(C2). `runtime-verifier`는 allowlist가 Law 2를 강화하지 않음 |
| **denylist에 `Agent`만 추가 (최소 수술)** | fail-open이 남는다. 다음 새 도구가 또 자동으로 들어온다 — `Agent`·MCP가 이미 그렇게 들어왔다 |
| **`allowedTools`만 지우고 denylist 유지** | **아무것도 안 고쳐진다.** 결함 B(fail-open)가 본체고, 3개 agent는 애초에 `allowedTools`가 없는데도 뚫려 있다 |
| **문서만 고치고 agent는 그대로** | 규범이 사실이 되는 게 목표. MCP 구멍은 문서로 안 닫힌다 |
| **PR B(plugin-audit)를 먼저 만들어 /audit이 잡게** | 순환. 살아있는 보안 구멍을 한 사이클 더 방치. PR B의 Law 2가 **바로 이 메커니즘 위에 선다** |
| **PR A·B를 한 브랜치에** | 리뷰어가 *"보안 수술 + 신규 플러그인"*을 한꺼번에 봐야 함 (C6) |
| **`check-allowed-tools-order.sh`도 정리** | **false positive.** command/skill `allowed-tools`는 실재·정상 |

---

## 12. Risks

| 리스크 | 완화 |
|---|---|
| allowlist 저술 시 필요한 도구 누락 → **리뷰어 조용한 열화** | §10-3 동적 dispatch + **fixture 기대 신호 검출** assertion. 정적 검사로는 절대 안 잡힘 |
| `pr-understanding-builder` → `tools: []` → **launch 실패** | §6에서 denylist 유지로 못 박음 + AC5 + 파일 주석 |
| `runtime-verifier`의 MCP 축소가 **chrome 자동화를 깨뜨림** | 서버 단위 열거(전면 차단 아님) + qg Runtime gate 실행으로 확인 |
| 세션 재시작 없이 검증 → **stale GREEN** | C1을 §10-2 전제조건으로 명시 + Handoff Context에 재개 순서 |
| 자기참조 — 고치는 리뷰어가 자기 PR을 리뷰 | codex 모델 다양성 + 결정론 grep + mutation test |
| 새 락이 또 **자기 regex 밖을 못 봄** | AC9 mutation **4종** + [[feedback_gate_scope_blind_spot]] |
| 두 플러그인 동시 수정 → 버전/CHANGELOG 누락 | C5 · AC12 |
| 계층 C 오염 | AC13 |

---

## 13. Open Questions

| # | 질문 | 상태 |
|---|---|---|
| ~~OQ1~~ | `test-scope-validator`가 Bash를 실제로 쓰는가? | ✅ **해소** — persona `:48` *"`Bash` is for reading files only"* → Read 대용 → **불요** |
| ~~OQ2~~ | `security-reviewer`에 WebSearch가 필요한가? | ✅ **해소** — persona `:42` *"Do not run audit commands yourself"* → **불요** |
| **OQ3** | `devbrew-roadmap.md`:63·:93은 완료 항목 **기록**인가 활성 규범인가? | 구현 — 읽고 판정. 기록이면 무변경 |
| **OQ4** | 리뷰어에게 `Skill`·`TodoWrite`가 필요한가? | 구현 — §10-3 동적 dispatch에서 관측 (fixture 실패 시에만 추가) |
| **OQ5** | `runtime-verifier`의 MCP 서버 단위 열거에 chrome-devtools 외 필요한 것이 있는가? | 구현 — qg Runtime gate 실행으로 확인 |

> **OQ1·OQ2는 리뷰 round 1의 codex 지적("조사로 닫을 수 있는 것을 구현에 미뤘다")을 받아 조사로 닫았다.** 남은 셋은 *"증거가 실행/판독에서만 나오는"* 부류다.

---

## 14. Metadata

| | |
|---|---|
| 발단 | PR B(`plugin-audit`) 브레인스토밍 중 발견 — 핸드오프 §8의 *"정면으로 다뤄라"* 숙제 |
| 근거 | 공식 문서 `code.claude.com/docs/en/sub-agents` + 런타임 레지스트리 실측 + 공식 `plugin-dev` 3종 대조 + 개별 파일 grep |
| 대상 | `quality-gates` 2.10.3 → 2.11.0 · `spec-distill` 0.20.0 → 0.21.0 · `CLAUDE.md` |
| 형제 | **PR B = `plugin-audit` 플러그인** — 이 PR 머지 후 별도 스펙. 재개점 = `docs/handoff/2026-07-12-plugin-maintenance-plugin-handoff.md` 원장 49 |
| Law | **Law 2** (분리를 물리적 사실로) · **Law 3** (버그를 놓친 검증 파일을 편집 — 이번엔 그 파일이 범인) |
| 리뷰 | round 1 = `needs_revise` (claude+codex 독립 일치, 8건). **round 1이 초고의 사실 오류(§1 "8개 전부") + AC8 fail-open + MCP 구멍 경로를 잡았다** |

---

## Handoff Context

### TL;DR

**`allowedTools`는 공식 subagent frontmatter 필드가 아니다.** devbrew 8개 agent가 **denylist만으로** 격리되고 있어(fail-open) `Agent`·`Bash`·**모든 MCP 도구**를 갖는다. 그중 `pr-understanding-builder`는 README가 *"네트워크 tool 0개"*라 광고하는 **pwn-request 방어인데 tavily·chrome-devtools를 보유**한다 — 살아있는 보안 구멍. 그리고 이 결함을 **회귀 락 두 겹(AC14 훅 + AC15 테스트)이 지키고 있어**, 올바른 수정을 하면 락이 막는다. 이 PR은 규범(`CLAUDE.md`) + 8개 agent + 락 두 겹을 함께 고친다.

### Implicit context (이 문서 밖에 있지만 구현자가 알아야 할 것)

- **⚠️ 구현 중간에 세션 재시작이 강제된다** (C1). 레지스트리는 세션 시작에 스냅샷되므로 **편집한 같은 세션의 AC7 검증은 거짓 GREEN**이다. 순서: 편집·커밋 → **재시작** → AC7 → AC8 → 회귀 → `/qg`.
- **재시작 후 세션이 읽어야 할 4가지**: ① 이 문서(AC 표 = 진리원천) ② 핸드오프 원장 49 ③ 브랜치 `feature/law2-agent-tool-surface`의 `git log` ④ **§10-0에서 파일로 남긴 test baseline** — 없으면 main의 stale red를 자기 회귀로 오인한다.
- **작업 위치**: worktree `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plugin-audit` (base `819da27`). **main 리포 경로로 커밋 금지** ([[feedback_subagent_worktree_path_emphasis]]) — subagent에 매번 worktree 절대경로를 명시할 것.
- **동시 세션 주의**: 같은 리포에 `feature+qg-artifact-critique` worktree가 **동시 실행 중**이다. `.claude/spec-distill/` state root를 공유하므로 **다른 sid 디렉토리를 건드리지 말 것**.
- **`plugin.json` 경로는 `plugins/<name>/.claude-plugin/plugin.json`** (루트 아님).
- **버전 리터럴 핀 금지** — 테스트가 patch digit을 핀하면 다음 bump마다 stale-red ([[feedback_version_pin_vs_bump_rule]]).

### Deferred to plan

- 각 agent 파일의 정확한 편집 순서와 커밋 분할 (subagent-driven task 분해).
- §10-3 fixture 6종의 구체적 내용 — `test-scope-validator`만 기존 fixture 재사용 확정, 나머지 5종은 신규 저술.
- `runtime-verifier` MCP 서버 단위 열거의 정확한 목록 (OQ5).
- AC14의 산문 정정 문구 (README:30·47·63을 무엇으로 대체할지).
- AC15 신설 테스트 2종의 형태 — 기존 4종 중 어느 것을 템플릿으로 삼을지.
