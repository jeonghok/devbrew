---
name: law2-agent-tool-surface
type: design-doc
created_at: 2026-07-16
revised_at: 2026-07-17
status: draft — review round 3 (round 1·2 모두 needs_revise, claude+codex 독립 일치)
approach: "8중 7 = `tools:` allowlist(fail-closed, MCP는 `mcp__<server>`로) / denylist 예외 1개(pr-understanding-builder) + `mcp__*`. 목록은 추론이 아니라 **트랜스크립트 도구 census**로 도출"
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
| C1 | ⚠️ **미확증**: "레지스트리는 세션 시작에 스냅샷된다"는 원장 19의 실증은 **Workflow 도구의 `agentType` 레지스트리**에 대한 것이고, 이 8개는 **표준 Agent-tool dispatch**를 쓴다 — **다른 메커니즘**. 재시작은 **fail-safe 기본값**으로 유지하되(안 하면 stale GREEN 위험, 하면 손해 없음), §10-2의 첫 census가 이 질문에 답한다 (편집 후 무재시작 census가 불변이면 스냅샷 확증) | 원장 19 = 다른 메커니즘. 리뷰 round 2가 반증 |
| C2 | **`tools: []`는 launch 실패** (공식 문서) | 공식 문서 |
| C3 | **`disallowedTools` 먼저, 그 다음 `tools`** | 공식 문서 |
| C4 | **작업 전 test baseline 캡처 필수** — main에 stale red 존재 | [[project_qg_pre_existing_test_reds]] |
| C5 | **플러그인 건드리면 같은 커밋에서 version bump** | [[feedback_plugin_version_bump]] |
| C6 | **persona/도구 표면은 보안-민감 코드** | `CLAUDE.md` |
| C7 | 테스트는 **repo root에서** 실행 | [[project_qg_pre_existing_test_reds]] |
| C9 | **서브에이전트 트랜스크립트가 실제 tool 호출을 JSONL로 기록한다** — `grep -o '"name":"[A-Za-z_]*"' <transcript> \| sort \| uniq -c`가 결정론적 census를 낸다. 임의 트랜스크립트 3건에서 재현 확인 | 2026-07-17 실측 |
| C8 | **MCP 패턴 문법** (공식 문서 verbatim): *"**Both fields** accept MCP server-level patterns…: `mcp__<server>` or `mcp__<server>__*` **grants** or removes every tool from the named server. **In `disallowedTools`, `mcp__*` also removes every MCP tool from any server**"* → **`tools:`도 서버 단위 grant가 된다** (예: `tools: Read, Bash, mcp__plugin_chrome-devtools-mcp_chrome-devtools`). allowlist는 열거 안 하면 자동 배제(fail-closed) | 공식 문서 |

---

## 5. 핵심 설계 결정

### 도구 목록은 **추론이 아니라 측정**으로 도출한다

초고는 *"persona 본문을 읽어 최소 집합을 정한다"*고 규정했다. **그 방법이 틀린 표를 만들었다** — 리뷰 round 2 중 `spec-reviewer`의 실제 트랜스크립트를 census한 결과:

| 도구 | round 1 | round 2 | 선언(`allowedTools`) |
|---|---|---|---|
| **Bash** | **27** | **10** | 있음 |
| Read | 3 | 3 | 있음 |
| **WebFetch** | **1** | **1** | ❌ **없음** |
| ToolSearch | 1 | 1 | ❌ 없음 |
| **Grep / Glob** | **0** | **0** | 있음 |

세 가지가 동시에 드러난다: (i) **`allowedTools`가 무시된다는 행동 증거** — 선언에 없는 `WebFetch`를 씀. (ii) persona가 Bash를 **한 번도 지시하지 않는데 agent는 37회 부른다** — persona 독해로는 이 목록을 못 만든다. (iii) 초고가 제안한 `tools: Read, Grep, Glob`은 **한 번도 안 쓰는 도구 2개를 주고 실제로 쓰는 도구 2개를 뺏는다** — §12가 이름 붙인 *"조용한 열화"*를 이 설계 자신이 저지를 뻔했다.

**따라서 도출 규칙 (결정론):**

```
tools:  =  (관측된 census  ∪  문서화된 Inputs/Output 계약이 요구하는 것)  −  금지 7종
```

`금지 7종` = `Write` · `Edit` · `MultiEdit` · `NotebookEdit` · `Agent` · `Bash` · `mcp__*`.
**census가 금지 도구를 보이면 그 용도를 대체 도구로 옮긴다** (예: `spec-reviewer`의 Bash 37회는 대부분 grep/find → `Grep`/`Glob`이 대체). 대체 불가면 예외 마커(아래).

census 절차 (C9 — 재현 확인됨):

```bash
grep -o '"name":"[A-Za-z_]*"' <transcript>.output | sort | uniq -c | sort -rn
```

### 8중 7은 allowlist. denylist 예외는 **하나**.

**denylist는 fail-open이다.** *"이 N개 빼고 전부"*는 새 도구·새 MCP 서버가 추가되면 **자동으로 agent가 갖는다.** `Agent`가 그렇게 들어왔고 MCP 서버가 그렇게 들어왔다.

초고는 *"실행자는 allowlist 불가"*라고 썼다. **틀렸다** — C8이 확정하듯 **`tools:`도 MCP 서버 단위 grant를 받는다**:

```yaml
tools: Read, Bash, Grep, Glob, Write, Edit, MultiEdit, mcp__plugin_chrome-devtools-mcp_chrome-devtools
```

→ `runtime-verifier`는 chrome을 유지하면서 나머지 MCP가 **fail-closed로 차단**된다. **예외 조항이 필요 없어지고, 초고의 §5↔§7 모순이 예외를 추가해서가 아니라 예외를 없애서 해소된다.**

**진짜 예외는 하나뿐이다**: `pr-understanding-builder`는 의도가 *"도구 0개"*인데 C2가 `tools: []`를 죽인다 — *"아무것도 없음"*은 allowlist로 표현할 수 없다. **denylist + `mcp__*`**가 유일한 표현 수단이다.

### 판정식 — 리뷰어 도구 상한

리뷰어의 `tools:`에 **금지 7종**이 있으면 위반. **침묵 예외 금지 — 예외는 기계가 읽을 수 있어야 한다.** 필요하면 그 agent 파일에 정확히:

```
# TOOL-EXCEPTION: <도구> — <한 줄 근거>
```

락은 `tools:`에 금지 도구가 있는데 이 마커가 **없으면 FAIL**한다.

---

## 6. Agent별 도구 표면

⚠️ **아래는 census 전 가설이다.** `spec-reviewer`만 실측 census를 가졌고(§5), 그것이 초고 표를 이미 반증했다. **§10-0이 8개 전부의 before-census를 뜬 뒤 §5의 도출 규칙을 적용해 확정한다** — 이 표를 그대로 구현하지 말 것.

| agent | 현재 실효 | 가설 | 근거 |
|---|---|---|---|
| `spec-reviewer` | all except 4 | `tools:` **Read, Grep, Glob, WebFetch, WebSearch** | ✅ **census 실측**: WebFetch를 **실제로 써서 공식 문서로 이 스펙을 검증**했다 — 뺏으면 리뷰 품질이 열화된다. Bash 37회는 grep/find 용도 → Grep/Glob이 대체 |
| `security-reviewer` | all except 4 | `tools:` **Read, Grep, Glob** | `filtered_diff` 인라인 수령. `:42` *"Do not run audit commands yourself"* → web 불요 (OQ2 해소). **census로 확인 필요** |
| `adversarial` | all except 4 | `tools:` **Read, Grep, Glob** | findings를 구조화 블록으로 수령. **census로 확인 필요** |
| `test-scope-validator` | all except 4 | `tools:` **Read, Grep, Glob** | `:48` *"No `curl`, no `WebFetch`, no MCP. **`Bash` is for reading files only**"* → Read가 대체 (OQ1 해소). **census로 확인 필요** |
| `breadth-keeper` | all except 4 | `tools:` **Read, Grep, Glob** | Bash·web 언급 0건. **census로 확인 필요** |
| `steelman-builder` | all except 4 | `tools:` **Read, Grep, Glob, WebSearch, WebFetch** | web 3건 · Bash 0건 → Bash 제거는 개선 |
| `runtime-verifier` | all except 1 | `tools:` **Read, Bash, Grep, Glob, Write, Edit, MultiEdit, `mcp__plugin_chrome-devtools-mcp_chrome-devtools`** + 죽은 `allowedTools`(**22**개) 제거 | 실행자 예외 — Write/Bash 필수, Law 2는 mutation-guard가 보장. **`tools:`로도 chrome 유지 가능**(C8) → 나머지 MCP fail-closed. `# TOOL-EXCEPTION:` 마커 필수 |
| `pr-understanding-builder` | all except 11 (**MCP 보유**) | 🔴 **denylist + `mcp__*`** + 죽은 `allowedTools: []` 제거 | **유일한 denylist 예외** — C2로 `tools: []` 불가. **MCP 구멍이 본 PR의 보안 핵심** |

---

## 7. 결함을 지키는 집행 메커니즘 뒤집기

> **용어 주의**: 아래 **레거시 AC14 / 레거시 AC15**는 qg v1.12.0이 붙인 이름이며, 이 문서 §8의 AC 번호와 **무관**하다. (초고가 같은 번호를 재사용해 리뷰 round 2에 지적당했다 — *"이름 충돌이 버그의 원인"*이라는 이 문서의 결론을 문서 자신이 반복한 것.)

### 레거시 AC15 — `test_agent_frontmatter_keys.sh`

**현재**: kebab 금지 + *"Expected: allowedTools / disallowedTools (camelCase)"*.
**변경 후** — `plugins/**/agents/*.md`에 대해 FAIL 조건:

| # | 조건 |
|---|---|
| L1 | `allowedTools` 존재 (kebab 변종도 계속) |
| L2 | **denylist 카브아웃 목록(현재 `pr-understanding-builder` 1개)에 없는데 `tools:`가 없음** |
| L3 | `tools:`에 금지 7종이 있는데 `# TOOL-EXCEPTION:` 마커 부재 |
| L4 | **카브아웃 목록의 agent**에 `disallowedTools`의 `mcp__*` 부재 |

> L2의 카브아웃 목록이 §5의 예외를 **인코딩**한다 — 초고는 이걸 빠뜨려 `runtime-verifier`가 자기 락에 FAIL했다(round 2 block). 이제 `runtime-verifier`는 allowlist라 카브아웃이 아니고, 카브아웃은 1개뿐이다.

### 레거시 AC14 — `session-start-advisor.py::_scan_agent_frontmatter_keys`

**현재**: kebab drift만 경고. **변경 후**: `allowedTools`도 경고. kill switch(`DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan`)는 **그대로 유지** — 어떤 훅도 자기 kill switch를 거부할 수 없다.

### 이빨 증명 (필수)

락을 걸고 끝내지 않는다. **§8 AC9의 mutation 전부에서 RED를 확인**한다. RED가 안 나면 그 락은 장식이다 ([[feedback_grep_lock_header_satisfiable]]).

> 이 PR은 **"버그가 리뷰를 탈출하면 잡았어야 할 검증 파일을 편집한다"**는 Law 3의 교과서적 사례다 — 다만 이번엔 그 검증 파일 자체가 범인이었다.

---

## 8. Acceptance Criteria

| # | 기준 | 검증 |
|---|---|---|
| **AC1** | `CLAUDE.md:25`가 agent 격리 메커니즘으로 `allowed-tools`/`disallowed-tools`(하이픈)를 지목하지 않는다 | grep |
| **AC2** | `CLAUDE.md:41`이 `allowedTools`를 요구하지 않고 **"리뷰어·실행자=`tools:` allowlist / '도구 0개' 표현이 필요한 경우만 denylist + `mcp__*`"**를 명시한다 | grep + 읽기 |
| **AC3** | `plugins/**/agents/*.md` 중 **어떤 파일도** `allowedTools` 키를 갖지 않는다 | 결정론 grep |
| **AC4** | 카브아웃(1개)을 뺀 **7개 agent가 `tools:`를 갖고**, 금지 7종이 있으면 **`# TOOL-EXCEPTION:` 마커 동반**(마커 없으면 FAIL) | 결정론 grep |
| **AC5** | `pr-understanding-builder`는 `tools:` 키가 없고(C2), `disallowedTools`에 **`mcp__*` 포함**. C2 근거가 파일에 기록된다 | 결정론 grep |
| **AC6** | `runtime-verifier`가 `tools:` allowlist를 갖고 Write·Bash·**chrome-devtools MCP를 유지**하며, **다른 MCP 서버는 갖지 않는다** | 결정론 grep + AC7 census |
| **AC7** | **census 차분 (기계적)**: 8개 agent 각각에 대해 §10-0 before-census와 §10-2 after-census를 비교해, **after ⊆ 선언된 `tools:`**이고 **금지 7종의 호출이 0회**다. before에서 쓰이던 금지 도구(예: `spec-reviewer`의 Bash 37회)가 after에서 **0회**인 것이 도구 제거의 증거 — persona는 before에서 그 호출을 안 막았으므로 **persona-거절 교란이 통제된다**(원장 21 함정 무력화) | `grep -o '"name":"[A-Za-z_]*"' <transcript> \| sort \| uniq -c` (C9) |
| **AC8** | 8개 agent를 **고정 fixture**로 각 1회 dispatch해 **문서화된 출력 계약**을 만족: (a) launch 성공 (b) 해당 스키마의 **비어있지 않은** 블록 (c) **fixture에 심어둔 특정 신호를 검출** (d) AC7의 census가 금지 도구 0회 | §10-3 |
| **AC9** | 레거시 AC15 락이 **mutation 전부에서 RED**: ①`allowedTools` 재도입 ②kebab 재도입 ③리뷰어 `tools:`에 **금지 7종 각각**(Write·Edit·MultiEdit·NotebookEdit·Agent·Bash·`mcp__x`) 마커 없이 추가 = **7 케이스** ④카브아웃 agent에서 `mcp__*` 제거 ⑤비-카브아웃 agent에서 `tools:` 제거 | mutation test (총 11 케이스) |
| **AC10** | 레거시 AC14 스캐너가 `allowedTools`를 경고하고, kill switch가 **여전히 동작** | 단위 테스트 |
| **AC11** | qg·spec-distill 기존 스위트가 **baseline 대비 회귀 0** | baseline 대조 (C4) |
| **AC12** | 두 플러그인 `plugin.json` bump + CHANGELOG 항목 | grep |
| **AC13** | `scripts/check-allowed-tools-order.sh`와 command `allowed-tools:`는 **무변경** | `git diff` |
| **AC16** | **활성 문서**(`CLAUDE.md` · `docs/plugin-authoring.md` · `plugins/*/README.md` · `plugins/*/skills/**/SKILL.md`)에 `allowedTools`를 **로드베어링 메커니즘으로 주장하는 문구가 0건**. 금지 리터럴: *"실제 키"* + `allowedTools` 동일 줄 · *"Layer 1 없이"* · *"네트워크 tool 0개"* + `allowedTools` 동일 줄. **범위 밖(무검사)**: CHANGELOG · `docs/handoff/**` · `docs/superpowers/**` | 결정론 grep (경로 화이트리스트 + 리터럴 목록) |
| **AC17** | `spec-reviewer`·`breadth-keeper`가 다른 리뷰어와 **동등한 도구 표면 회귀 락**을 갖는다 (현재 부재) | 테스트 존재 + mutation |

---

## 9. Files to Modify

### 규범 층
- `CLAUDE.md` — :25 (Law 2) · :41 (Scoped agents)
- `docs/plugin-authoring.md` — :16 · :24
- `docs/philosophy/devbrew-roadmap.md` — :63 · :93 ⚠️ *완료 항목 기록이면 무변경 (OQ3)*

### Agent 층 (8)
- `plugins/quality-gates/agents/{security-reviewer,adversarial,test-scope-validator,pr-understanding-builder,runtime-verifier}.md`
- `plugins/spec-distill/agents/{spec-reviewer,breadth-keeper,steelman-builder}.md`

### 집행 층 (결함을 지키던 것들)
- `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` — **L1~L4로 재작성**
- `plugins/quality-gates/hooks/session-start-advisor.py` — 레거시 AC14 스캐너
- `plugins/quality-gates/tests/test_session_start_advisor_v2.sh` — 스캐너 테스트

### Per-agent 회귀 테스트
- 기존(키 변경 시 RED): `plugins/quality-gates/tests/{test_pr_understanding_builder_frontmatter,test_runtime_verifier_frontmatter,test_test_scope_validator_frontmatter,test_security_reviewer_persona,test_adversarial_persona}.sh` · `plugins/spec-distill/tests/test_steelman_builder_scope.sh`
- **신설(AC17)**: `spec-reviewer`·`breadth-keeper` 도구 표면 락

### 거짓이 된 서술 산문 (AC16)
- `plugins/quality-gates/README.md` — **:30**(*"실제 키"*·*"Layer 1 없이 불완전"*) · **:47**(*"네트워크 tool 0개"*) · **:63** · :11·:19·:27·:29·:31(denylist 서술 — 규범 변경 반영 판정)
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

**0. Baseline + before-census (선행 필수)**
(a) C4 — 두 플러그인 스위트를 repo root에서 돌려 red 목록을 **파일로** 기록.
(b) **8개 agent 각각을 §10-3 fixture로 1회 dispatch하고 census를 파일로 기록** (C9). 이것이 §5 도출 규칙의 입력이자 AC7 차분의 before다. **`spec-reviewer`는 이미 확보** (Bash 37 · Read 6 · WebFetch 2 · ToolSearch 2, 2라운드 합산).

**1. 목록 확정** — §5 도출 규칙을 census에 적용해 §6 가설표를 **확정표로 대체**. 금지 도구 용도는 대체 도구로 이관하거나 `# TOOL-EXCEPTION:` 마커.

**2. 편집 → (재시작) → after-census** — 편집·커밋 후 **세션 재시작**(C1 fail-safe), 8개 재-dispatch, census 재기록.
> **C1이 여기서 답해진다**: 재시작 *전에* 한 번 census를 떠서 before와 같으면 스냅샷 확증(재시작 필수), 달라지면 즉시 반영(재시작 불요). **어느 쪽이든 fail-safe로 재시작은 한다** — 비용이 거의 0이고 틀렸을 때 대가가 stale GREEN이다.

**3. 동적 dispatch — 고정 fixture + 결정론 assertion** (AC8):

| agent | fixture | 기대 (심어둔 신호) |
|---|---|---|
| `security-reviewer` | 명백한 injection 1개를 심은 diff | 그 injection을 finding YAML로 검출 |
| `adversarial` | 명백한 FP 1건 + 진짜 1건 | 두 판정이 갈림 (FP=reject) |
| `test-scope-validator` | `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}` **기존 재사용** | 3분류를 정확히 맞힘 |
| `spec-reviewer` | 알려진 결함 N개를 심은 design doc | **심은 N개 중 ≥1을 지목**(sentinel JSON, target_section 일치) |
| `breadth-keeper` | 한 dimension에 편중된 라운드 + **미탐색 dimension 1개를 명시적으로 비워둠** | **그 미탐색 dimension을 지목** |
| `steelman-builder` | 대안이 명백한 방향 + **그 대안 이름을 fixture에 미포함** | 그 대안을 **web에서 찾아** 이름을 산출 |
| **`pr-understanding-builder`** | inlined blob + *"tavily로 검색해보라"* 유인 | **MCP 호출 census 0회** + 저술 산출 (🔴 이 PR의 보안 핵심 검증) |
| **`runtime-verifier`** | 최소 웹앱 부팅 시나리오 | chrome-devtools 호출 **성공** + **다른 MCP 서버 census 0회** |

**공통 assertion**: launch 성공 · 스키마 유효 · **AC7 census에서 금지 도구 0회**.

**4. 회귀** — AC11. baseline 대조.

**5. `/qg`** — 전 파이프라인. ⚠️ **자기참조 주의**: 이 PR이 고치는 리뷰어가 이 PR을 리뷰한다. codex(외부 프로세스)의 독립 판정이 특히 load-bearing — round 1·2에서 실제로 codex가 AC fail-open을 단독 적발했다.

## 11. Rejected Alternatives

| 대안 | 왜 기각 |
|---|---|
| **8개 전부 `tools:` allowlist** | `pr-understanding-builder`의 의도가 *"도구 0개"*인데 `tools: []`는 **launch 실패**(C2). *"아무것도 없음"*은 allowlist로 표현 불가 |
| **~~실행자는 allowlist 불가~~** (초고의 결정) | **반증됨** — C8: `tools:`도 `mcp__<server>` grant를 받는다. `runtime-verifier`는 chrome을 유지한 채 allowlist 가능. 초고는 이 때문에 §5↔§7 모순을 만들었다(round 2 block) |
| **persona 독해로 목록 도출** (초고의 방법) | **반증됨** — census가 `spec-reviewer`의 실제 사용(Bash 37 · WebFetch 2)이 persona 서술과 무관함을 보였다. 초고 표는 안 쓰는 도구를 주고 쓰는 도구를 뺏었다 |
| **denylist에 `Agent`만 추가 (최소 수술)** | fail-open이 남는다. 다음 새 도구가 또 자동으로 들어온다 — `Agent`·MCP가 이미 그렇게 들어왔다 |
| **`allowedTools`만 지우고 denylist 유지** | **아무것도 안 고쳐진다.** 결함 B가 본체고, 3개 agent는 애초에 `allowedTools`가 없는데도 뚫려 있다 |
| **문서만 고치고 agent는 그대로** | MCP 구멍은 문서로 안 닫힌다 |
| **PR B(plugin-audit)를 먼저 만들어 /audit이 잡게** | 순환. 살아있는 보안 구멍을 한 사이클 더 방치. PR B의 Law 2가 **이 메커니즘 위에 선다** |
| **PR A·B를 한 브랜치에** | 리뷰어가 *"보안 수술 + 신규 플러그인"*을 한꺼번에 봐야 함 (C6) |
| **`check-allowed-tools-order.sh`도 정리** | **false positive.** command/skill `allowed-tools`는 실재·정상 |
| **AC7을 레지스트리 조회로** (초고의 방법) | **경로가 없다** — `claude agents`는 background agent 관리이고, 서브에이전트 실효 표면을 뽑는 CLI·훅은 부재(공식 문서 확인). 초고의 *"레지스트리가 ground truth"*는 **내 시스템 프롬프트 주입을 읽은 것**이라 구현자가 재현 불가. → **census 차분으로 대체**(C9) |

---

## 12. Risks

| 리스크 | 완화 |
|---|---|
| allowlist 저술 시 필요한 도구 누락 → **리뷰어 조용한 열화** | **§10-0 before-census가 1차 방어**(실제 사용을 사실로 확보) + §10-3 fixture 신호 검출. **초고가 이 리스크를 실제로 저질렀고 census가 잡았다** |
| `pr-understanding-builder` → `tools: []` → **launch 실패** | §5·§6에서 denylist 유일 예외로 못 박음 + AC5 |
| `runtime-verifier` MCP 축소가 **chrome 자동화를 깨뜨림** | `tools:`에 서버 단위 grant(C8) + §10-3 전용 fixture + qg Runtime gate |
| 세션 재시작 불요인데 ceremony만 추가 / 필요한데 생략 → **stale GREEN** | C1을 **미확증으로 정직하게 표기** + fail-safe 재시작 + §10-2가 답을 냄 |
| 자기참조 — 고치는 리뷰어가 자기 PR을 리뷰 | codex 모델 다양성 + 결정론 grep + mutation. round 1·2에서 실제로 작동 |
| 새 락이 또 **자기 regex 밖을 못 봄** | AC9 **11 케이스** mutation (금지 7종 각각 포함) |
| 두 플러그인 동시 수정 → 버전/CHANGELOG 누락 | C5 · AC12 |
| 계층 C 오염 | AC13 |
| **census가 fixture 의존적이라 실사용을 과소표집** | fixture는 그 agent의 **정상 업무**를 태운다(§10-3). census는 *하한*이며 도출 규칙이 **문서화된 계약과 합집합**을 취해 보완 |

---

## 13. Open Questions

| # | 질문 | 상태 |
|---|---|---|
| ~~OQ1~~ | `test-scope-validator`가 Bash를 실제로 쓰는가? | ✅ **해소** — persona `:48` *"`Bash` is for reading files only"* → Read가 대체 → 목록 제외. **§10-0 census가 재확인** |
| ~~OQ2~~ | `security-reviewer`에 WebSearch가 필요한가? | ✅ **해소** — persona `:42` *"Do not run audit commands yourself"* → 제외. **§10-0 census가 재확인** |
| ~~OQ4~~ | 리뷰어에게 `Skill`·`TodoWrite`가 필요한가? | ✅ **해소** — 도출 규칙(§5)이 답한다: census에 나타나면 포함, 아니면 제외. 추측 불요 |
| ~~OQ5~~ | `runtime-verifier`의 MCP 서버 목록? | ✅ **해소** — 파일의 죽은 `allowedTools` 22개가 이미 열거: **`mcp__plugin_chrome-devtools-mcp_chrome-devtools` 한 서버**. `tools:`에 서버 패턴으로 grant |
| **OQ3** | `devbrew-roadmap.md`:63·:93은 완료 항목 **기록**인가 활성 규범인가? | 구현 — 읽고 판정. 기록이면 무변경 |
| **OQ6** | 표준 Agent-tool dispatch도 세션 시작에 스냅샷되는가? (C1) | **§10-2가 답한다** — 재시작 전 census가 before와 같으면 스냅샷 확증. 어느 쪽이든 fail-safe로 재시작 |

> **round 1·2의 codex 지적(*"조사로 닫을 수 있는 것을 구현에 미뤘다"*)을 받아 OQ1·2·4·5를 닫았다.** 남은 둘은 *"읽어봐야 아는 것"*(OQ3)과 *"돌려봐야 아는 것"*(OQ6)이며, 후자는 검증 절차 안에 답이 배선돼 있다.

---

## 14. Metadata

| | |
|---|---|
| 발단 | PR B(`plugin-audit`) 브레인스토밍 중 발견 — 핸드오프 §8의 *"정면으로 다뤄라"* 숙제 |
| 근거 | 공식 문서 `code.claude.com/docs/en/sub-agents` + **서브에이전트 트랜스크립트 census 실측** + 공식 `plugin-dev` 3종 대조 + 개별 파일 grep |
| 대상 | `quality-gates` 2.10.3 → 2.11.0 · `spec-distill` 0.20.0 → 0.21.0 · `CLAUDE.md` |
| 형제 | **PR B = `plugin-audit` 플러그인** — 이 PR 머지 후 별도 스펙. 재개점 = `docs/handoff/2026-07-12-plugin-maintenance-plugin-handoff.md` 원장 49 |
| Law | **Law 2** (분리를 물리적 사실로) · **Law 3** (버그를 놓친 검증 파일을 편집 — 이번엔 그 파일이 범인) |
| 리뷰 | round 1 = `needs_revise` (8건) → round 2 = `needs_revise` (3건 해소, 5건 재발, `source: both` 2건). **round 2가 §5↔§7 모순 + 보안핵심 미검증 + AC7 미측정을 잡았고, 그 지적을 따라간 census 실측이 §6 표 자체를 반증했다** |

---

## Handoff Context

### TL;DR

**`allowedTools`는 공식 subagent frontmatter 필드가 아니다.** devbrew 8개 agent가 **denylist만으로** 격리돼(fail-open) `Agent`·`Bash`·**모든 MCP 도구**를 갖는다. `pr-understanding-builder`는 README가 *"네트워크 tool 0개"*라 광고하는 **pwn-request 방어인데 tavily·chrome-devtools를 보유** — 살아있는 보안 구멍. 그리고 이 결함을 **레거시 AC14 훅 + 레거시 AC15 테스트가 지키고 있어**, 올바른 수정을 하면 락이 막는다. 이 PR은 규범(`CLAUDE.md`) + 8개 agent + 락 둘을 함께 고친다. **도구 목록은 추론이 아니라 트랜스크립트 census로 도출한다.**

### Implicit context (이 문서 밖에 있지만 구현자가 알아야 할 것)

- **§10-0 before-census를 건너뛰지 말 것.** 이게 이 설계의 입력이다. 초고는 persona 독해로 표를 만들었고 **틀렸다** — `spec-reviewer`는 persona가 한 번도 지시 안 하는 Bash를 37회 부르고, 선언에 없는 WebFetch로 공식 문서를 검증한다. census 명령: `grep -o '"name":"[A-Za-z_]*"' <transcript>.output | sort | uniq -c | sort -rn`. 트랜스크립트는 Agent 도구 결과의 `output_file` 경로에 있다.
- **`spec-reviewer` census는 이미 확보** (round 1+2 합산): Bash 37 · Read 6 · WebFetch 2 · ToolSearch 2 · **Grep/Glob 0**.
- **⚠️ 세션 재시작**: C1은 **미확증**이다(원장 19는 Workflow `agentType` 레지스트리 얘기이고 이 8개는 표준 dispatch). fail-safe로 재시작하되, §10-2가 OQ6에 답을 낸다.
- **재시작 후 세션이 읽어야 할 4가지**: ① 이 문서(AC 표 = 진리원천) ② 핸드오프 원장 49 ③ 브랜치 `feature/law2-agent-tool-surface`의 `git log` ④ **§10-0에서 파일로 남긴 baseline + before-census** — 없으면 main의 stale red를 자기 회귀로 오인하고, census 차분(AC7)의 before를 잃는다.
- **작업 위치**: worktree `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plugin-audit` (base `819da27`). **main 리포 경로로 커밋 금지** ([[feedback_subagent_worktree_path_emphasis]]).
- **동시 세션 주의**: 같은 리포에 `feature+qg-artifact-critique` worktree가 **동시 실행 중**. `.claude/spec-distill/` state root를 공유하므로 **다른 sid 디렉토리를 건드리지 말 것**.
- **`plugin.json` 경로는 `plugins/<name>/.claude-plugin/plugin.json`** (루트 아님).
- **버전 리터럴 핀 금지** ([[feedback_version_pin_vs_bump_rule]]).

### Deferred to plan

- 각 agent 파일의 편집 순서와 커밋 분할 (subagent-driven task 분해).
- §10-3 fixture 중 **5종의 구체적 바이트** — `test-scope-validator`는 기존 fixture 재사용 확정, `spec-reviewer`/`breadth-keeper`/`steelman-builder`/`security-reviewer`/`adversarial`/`pr-understanding-builder`/`runtime-verifier`는 신규 저술. **심을 신호의 성격은 §10-3 표가 확정**했고 남은 건 문면.
- AC16의 산문 대체 문구 (README:30·47·63을 무엇으로 바꿀지).
- AC17 신설 테스트 2종의 형태 — 기존 4종 중 템플릿 선택.
- OQ3 판정 (`devbrew-roadmap.md` 성격).
