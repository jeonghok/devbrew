---
name: conducting-interview
description: >
  Runs the spec-distill problem-space interview stage and produces a terminal
  interview-brief at docs/superpowers/interview/. 종료는 커버리지 원장의 floor
  5차원(root-problem/landscape/skepticism/blind-spot/open-questions)이 모두
  closed일 때이며, check_brief.py의 구조적 게이트로 기계적 검증합니다(Law 1).
  Optionally hands the brief to superpowers:brainstorming.
cost_class: variable
user-invocable: false
---

# Conducting Interview — 문제공간 Stage (Phase 1)

당신은 spec-distill의 인터뷰 stage를 진행 중입니다. 이 stage는 *받아적는* 인터뷰가
아니라 **강한 문제공간 stage**입니다(Double Diamond 1st diamond — brainstorming 해답공간
앞단, 상보적·비중복). 4-block Korean Socratic format으로 round를 진행하되, 종료는
**커버리지 원장의 floor 5차원**(root-problem/landscape/skepticism/blind-spot/open-questions)이
**모두 `closed`**일 때만 허용됩니다 — landscape·skepticism 등 통과 의례 메커니즘이 각 차원을
채우는 수단이며, `check_brief.py`가 이를 기계적으로 검증합니다(Law 1 구조 게이트).

산출물은 `spec.md`가 아니라 **interview brief**(brainstorming용 meta-prompt)이며, 이
brief는 **단독 완결 terminal 산출물**입니다 — superpowers가 있으면 brainstorming으로
넘기고(optional), 없으면 brief 자체로 완료합니다.

## State location (AC2)

`.claude/spec-distill/<session-id>/state.local.md` (per-session 격리, devbrew §4.8 준수)

State frontmatter schema:

```yaml
---
session_id: <uuid>
phase: 1
coverage:                            # G1 커버리지 원장 (floor 5 + derived[]). 종료 driver.
  floor:
    root_problem:   {status: open, evidence: ""}
    landscape:      {status: open, evidence: ""}
    skepticism:     {status: open, evidence: ""}
    blind_spot:     {status: open, evidence: ""}
    open_questions: {status: open, evidence: ""}
  derived: []                        # 주제-도출 차원 (coverage-mapper 제안 → orchestrator admit; {name, rationale, status, evidence})
orchestration:                       # C11/C8 across-resumption 상태 (orchestrator 소유, agent read-only)
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  no_progress_streak: 0              # C11 연속 무진전 probe 수; focused 변경·진전 시 0 reset
  blind_spot_dispatched: false       # C8 인터뷰당 1회 보장; 첫 dispatch 시 true
  coverage_mapper_last_probe: null   # 마지막 coverage-mapper dispatch 시 probe_count (C11 rate-limit)
probe_count: 0                       # C10 probe 백스톱 카운터 (probe 제기 *후* +1)
probe_cap_override: 0                # C1 '계속'이 base cap(12)만큼 raise
non_user_streak: <int>
web_sweep_count: 0                   # 현재 sweep 내 web 검색 호출 수 (AP9, ≤4). sweep 종료 시 0으로 reset.
web_search_count: 0                  # 세션 누적 web 검색 호출 수 (AP16, ≤8 soft cap).
rereview_count: 0
trivia_escape_armed: false
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
user_statements: []                  # 매 round 끝 append. 판정 없음 — 확정은 종료 게이트가 결정.
confirm_repost_count: 0              # 종료 확정 확인 재제시 횟수 (상한 2, Unbounded-autonomy 가드)
---
```

State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) coverage-mapper 출력 transcript.

**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후 기록.

### State write contract (PN1 — worktree-safe)

`state.local.md`는 `state_path.py`가 **main repo** `.claude/spec-distill/<sid>/`로 라우팅합니다
(`git rev-parse --git-common-dir`). 워크트리 세션에서 이 경로는 워크트리 *밖*이라 `Write`/`Edit`
tool이 차단됩니다 — state 갱신은 **반드시 Bash**로 하십시오:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# read-modify-write via python3 -c / heredoc (Edit tool 사용 금지 — main-repo 경로)
```

**brief는 예외**: `docs/superpowers/interview/`는 워크트리 *안*이라 `Write` tool로 정상 작성.

## 4-block Korean format (devbrother2024 deep-interview 흡수, AC1)

매 round마다 다음 4 block을 출력하십시오:

```markdown
**현재 이해:**
(지금까지 인터뷰로 파악한 사용자 요청의 *현재 이해*를 한두 문장으로 요약. 1라운드는 사용자 prompt에서 추출.)

**막힌 결정:**
(가장 큰 단일 불확실성 — goal/scope/constraints/AC 중 가장 모호한 한 가지를 명시.)

**추천 답안:**
(막힌 결정에 대한 *내 추천 답*. 사용자가 No만 골라도 진행 가능하게.)

**질문:**
(한 번에 하나의 질문. 다지선다 형태 권장. open-ended는 신중히.)
```

## C43 4-path routing

질문을 만들 때 다음 4 경로 중 하나로 분류해서 routing 하십시오:

| Path | When | Action |
|---|---|---|
| (a) **factual / landscape** | 답이 codebase/git history *또는 외부 prior-art*에 있는 경우 | codebase는 grep/Read *auto-confirm*; 외부는 web sweep(아래 R2). 마커 `[from-code][auto-confirmed]` 또는 `[from-web]`. streak +1. |
| (b) **judgment** | 사용자 선호/우선순위/제약 | 사용자에게 묻기 (default path). 4-block 출력. |
| (c) **ambiguity** | 여러 해석 가능한 핵심 가정 | sub-agent에 adversarial draft 요청 (`general-purpose` agent에 "이 가정이 잘못됐다면 어떤 시나리오가 가능한가?" 형태로 dispatch). 답을 그대로 사용자에게 보여주고 confirm. |
| (d) **ontological** | "이게 무엇인가" 종류 (essence/root cause 등) | C51 5-type framework 사용 — ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT 중 하나로 라벨링 후 사용자에게 묻기. |

매 round의 4-block에서 어떤 path로 routing했는지 transcript에 명시하십시오.

## teach-beat (AC8/C3/C12 — 미지를 드러내 가르치기)

매 probe에 **teach-lite**를 붙인다: prior-art/trade-off를 **≤1문장**, **web 호출 없이**, 그리고
**단정이 아닌 질문 형태**로 제시해 사용자가 모르는 지형을 살짝 연다(C3 — 공유된 전제가 사용자 답을
오염시키지 않게).

다음 **열거 신호** 중 하나가 발화하면 그 probe의 teach-lite를 **teach-heavy**로 *대체*한다
(추가 아님 — probe당 teach-beat 최대 1회). teach-heavy = **≥1 prior-art/URL 또는 landscape 인용**:

1. 사용자 답이 `## External Landscape` 한 항목과 모순.
2. hold·satisficing 답("모르겠음/둘 다/아무거나" — 발화 기록 표의 "보류" 행 재사용).
3. floor 차원의 첫 open→in-progress 전이(그 차원에 첫 probe 착수).
4. coverage-mapper/blind-spot-prober 출력이 비어있지 않음.

복수 신호 동시 발화 시 heavy beat 1회로 합친다. **발화 시점은 모델 판단 적응 행동**이다(C12 —
결정론 게이트로 기계화하지 않는다; 위 신호는 결정 규칙이 아니라 휴리스틱 가이드). 검증 가능한 것은
이 신호 목록 + 크기 한도(teach-lite ≤1문장 / teach-heavy ≥1 URL)뿐이며, 각 발화의 per-firing
결정성은 non-goal(모델 판단을 결정론으로 대체하지 않음 — 이 재구성의 핵심 논지).

## 사용자 발화 기록 (G1, AC1)

매 round 끝에 사용자가 실제로 답한 것을 `user_statements`에 append합니다. **여기서 무엇도
판정하지 않습니다** — 이 stage는 문제공간이고, 무엇이 확정인지는 종료 직전 사용자 일괄
확인(Step B-0)이 결정합니다.

| 사용자 응답 유형 | path | 기록? | `source` |
|---|---|---|---|
| 자유 텍스트 응답 (수락·거절·요구 무관) | b, d | ✅ | `verbatim` |
| 선택지 선택 | b, d | ✅ | `chosen` |
| 보류 ("잘 모르겠음", "둘 다 괜찮음") | b, d | ✅ — §3 Open Questions로도 이월 | `verbatim` |
| factual auto-confirm | a | ❌ (사용자 발화 아님) | — |
| sub-agent ambiguity 답안 | c | ✅ ONLY IF 사용자 confirm — **confirm 발화**를 기록 | `verbatim` |

```yaml
- id: S<N>                 # N = user_statements.length + 1
  source: verbatim         # verbatim(발화 그대로) | chosen(고른 선택지 라벨 + 요지)
  round: <int>
  text: "<사용자가 실제로 한 말>"    # P21 secret placeholder 치환 적용
```

`status` 필드는 없습니다. `section:` 해답공간 앵커도 없습니다 — 문제공간의 답변을 답이
들어갈 슬롯에 미리 바인딩하면 다음 stage의 탐색이 그 슬롯 모양대로 갇힙니다.

거절도 수락과 똑같이 **발화 그대로** 기록합니다. 반대 명제로 뒤집어 "잠긴 방향"으로
승격시키지 않습니다 — 그 승격이 라운드마다 결정을 박제하던 경로였습니다.

## C44 Dialectic Rhythm Guard

`non_user_streak` 카운터 — 직전 N probe 동안 *사용자 답변이 없었던* 횟수.

- (a) factual auto-confirm: streak +1
- (c) sub-agent adversarial: streak +1
- (b) 사용자 답변 받음: streak = 0
- (d) ontological 사용자 답변 받음: streak = 0
- (a) web auto-research: streak +1 (과도하면 강제 (b)로 사용자를 loop에 유지 — AP16).

`non_user_streak >= DEVBREW_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 probe의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

## probe 백스톱 (C1/C10 — Unbounded-autonomy 가드)

floor 미충족이면 종료가 막히므로 probe가 무한히 돌 수 있다. `probe_budget.py`가 이를 기계적으로
bound한다(프로즈 self-tracking 금지). **원자성**: probe(= (b)/(d)-path 질문 1회)를 조립하기
*전에* `check`(gate)를 호출하고, 질문을 실제로 제기한 *후에만* `increment`한다.

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# 1) probe 조립 전 gate (check가 유일한 gate — C10)
if python3 "${CLAUDE_PLUGIN_ROOT}/scripts/probe_budget.py" check "$STATE"; then
  # gate 통과 → (b)/(d) 질문을 실제로 제기하고 답을 받는다
  # <질문 제기 + 답 수신>
  # 2) 질문을 제기한 *후에만* increment (phantom 증가 없음 — C10 원자성)
  #    increment는 fail-closed(exit 1: 카운터 부재/malformed/state unwritable)다. web_budget(아래 270)과
  #    대칭으로 그 exit를 반드시 확인한다 — 무시하면 카운터가 전진하지 않아 check가 영원히 통과하고
  #    백스톱이 조용히 무력화된다(fail-open, Unbounded-autonomy Forbidden Pattern).
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/probe_budget.py" increment "$STATE" || {
    echo "[spec-distill] probe_count increment 실패 — 백스톱 무력화 위험(카운터 부재/malformed/state unwritable). 자동 진행 중단, 상태 재영속화(마이그레이션 persist) 또는 세션 확인 후 재시도." >&2
    # blocked check와 동일하게 fail-closed 취급 — 다음 probe를 제기하지 말고 아래 C1 escalation으로.
  }
else
  # probe_count >= effective_cap & floor 미충족 → 질문 미제기(increment 안 함),
  # 아래 C1 escalation(AskUserQuestion 3옵션)으로.
  :
fi
```

`check`가 non-zero(`probe_count ≥ effective_cap`) & floor 미충족이면 **C1 escalation**을 발화한다
(`AskUserQuestion`, 3옵션):

- **① 계속**: `probe_budget.py raise-cap "$STATE"` — `probe_cap_override`를 base cap(12)만큼 올려
  `effective_cap = base + override`로 상향(persist) 후 진행.
- **② 박제 후 종료**: 미충족 floor 행을 `status: closed` + evidence `사용자-승인 박제(@probe N) —
  §Open Questions 참조`로 기록하고 그 내용을 payload §3 Open Questions로 이동 → AC2 게이트 통과(floor
  closed)하되 박제 표식이 원장에 가시적(silent bypass 아님).
- **③ abort**: brief 미작성, state 보존.

`increment`는 질문 제기 후에만 호출돼 phantom 증가가 없다(gate에서 막힌 probe는 카운트 안 됨).
`increment`는 gate하지 않는다 — gating은 오직 `check`(C10 원자성). 단 `increment`의 exit는
반드시 확인한다: fail-closed(exit 1) 시 카운터가 디스크에 전진하지 못한 것이므로 자동으로 다음
probe를 제기하지 말고 fail-closed로 처리한다(위 `|| {…}` 가드, web_budget과 대칭). 이 exit를
버리면 백스톱이 조용히 무력화된다.

kill switch: `DEVBREW_SPEC_DISTILL_PROBE_CAP=N` 으로 base cap override.

## coverage-mapper dispatch (C11, AC7)

`coverage-mapper`는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(원장 admit
판정은 orchestrator, G2). 다음 조건 중 하나에서 dispatch:

1. 한 focused 차원이 **연속 3 probe** 동안 status·evidence 무변경(진전 없음), OR
2. floor 차원의 **첫 open→in-progress 전이**.

진전 = status 전이(open→in-progress→closed) 또는 evidence append. `orchestration.no_progress_streak`는
focused 차원이 바뀌거나 진전 발생 시 0으로 reset.

**redispatch 바운드(Unbounded-autonomy 가드)**: dispatch 시 `orchestration.coverage_mapper_last_probe =
probe_count` 기록. 재dispatch는 `probe_count - coverage_mapper_last_probe >= 3`일 때만 허용(무진전이
지속돼도 최소 3 probe 간격 — 레벨-트리거 무한 재dispatch 방지). `coverage_mapper_last_probe == null`이면
첫 dispatch 허용.

```
Agent({ description: "Map coverage dimensions", subagent_type: "spec-distill:coverage-mapper",
        prompt: "열린/닫힌 차원 요약: <...>. focused_dimension: <...>, no_progress_streak: <N>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
```

출력(`derived_dimensions[] + neglect_flag`)은 **advisory** — orchestrator가 원장에 admit할지 판정한다.
`neglect_flag: true`면 다음 probe에서 neglected 차원 하나를 추천 답안으로 제시. 복수 dispatch 시
name 기준 union·dedup.

## blind-spot-prober dispatch (AC6, C8 — blind_spot floor 차원)

`blind_spot` floor 차원의 **첫 open→in-progress 전이**(그 차원에 첫 probe 착수) 시 `blind-spot-prober`를
**인터뷰당 1회** dispatch한다(fan-out 1, C8). `orchestration.blind_spot_dispatched`가 false일 때만
dispatch하고, dispatch 후 true로 세팅(재dispatch 금지).

```
Agent({ description: "Adversarial premortem", subagent_type: "spec-distill:blind-spot-prober",
        prompt: "재구성된 문제정의: <...>. 지금까지의 사용자 제약 요지: <...>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
```

출력(`hidden_assumptions[] + failure_modes[]`)을 orchestrator가 payload §5 `## 5. 기각 · Blind Spots`의
**`위험` 항목**(`- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>`)으로 기록하고, `blind_spot` floor
차원을 in-progress→closed로 전이(사용자에게 표면화된 blind-spot 확인 후).

**Web 부재 시 graceful degradation (C5)**: kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web
도구 부재로 blind-spot-prober를 돌릴 수 없으면 — R2/R3 web-absent 강등과 대칭으로 — opaque gate-fail로
떨어뜨리지 말고 **loud advisory** 후 **inline premortem**으로 전환:
`[spec-distill] web 비활성 — blind-spot-prober 자동 생략, inline premortem으로 전환`. 이 경우 §5의
`위험` 항목은 codebase 근거 또는 사용자 판단으로 기록(URL 부재 사유 명시).

## 5 통과 의례 (Law 1 구조 게이트, R1–R5)

brief 작성(+ optional brainstorming invoke)은 다음 5 의례를 **모두 통과**해야 허용됩니다.
하나라도 미충족이면 종료 차단. 종료 직전 `check_brief.py gate`로 **기계적 검증**(AC3):

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Reframe (메타 프롬프트)** | 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal. | (d) ontological 5-type (ESSENCE/ROOT_CAUSE/...) → payload §0 한눈에(스냅샷) + §1 Goal · Non-goal(진짜 goal) |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 → payload §4 External Landscape |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *방어 또는 전환*. un-challenged 의심 방향은 확정 후보가 될 수 없다. | steelman-builder dispatch → payload §5의 **`verdict:` 항목** |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* 기록. 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지). | payload §5의 **`기각` 항목** |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | payload §3 Open Questions |

### R2 — 웹 Landscape (bounded, AC7/AC8)

토픽이 잡히면(round 1–2) landscape sweep **1회**를 수행합니다. 각 web 검색 *전에* `increment`로
state의 `web_sweep_count`/`web_search_count`를 +1 하고(PN1 Bash write — `increment`가 read-modify-write를
직접 수행, 인라인 주석 보존) budget을 확인합니다. `check`가 아니라 `increment`여야 카운터가 실제로
전진합니다(미전진 시 budget이 영원히 0 — AP9/AP16 무력화). exit ≠ 0 이면 그 호출이 cap을 넘는다는 뜻:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/web_budget.py" increment "$ROOT/<session-id>/state.local.md" || {
  echo "[spec-distill] web budget 초과 — landscape 중단, 강제 (b) 사용자 질문" ; }
```

- budget 초과(sweep>4 또는 session>8) → advisory + **강제 (b) 사용자 질문**(AP16).
- 모든 외부 주장은 **출처 URL 필수**(AC4) — payload §4 External Landscape에 `[취함|피함|중립]` + 이유와 함께.
- **kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`** 또는 web 도구 부재 → landscape를 **loud하게
  생략**하고 계속(crash 금지, graceful degradation — AC8): `[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용`.
- sweep 종료 시 `reset-sweep`로 `web_sweep_count`를 0으로 reset(session 카운터는 유지):
  ```bash
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/web_budget.py" reset-sweep "$ROOT/<session-id>/state.local.md"
  ```

### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌 / coverage-mapper neglect.

1. `steelman-builder` 에이전트를 **순차** dispatch(병렬·투기적 금지 — C5):
   ```
   Agent({ description: "Steelman alternative", subagent_type: "spec-distill:steelman-builder",
           prompt: "의심 방향: <statement>. trigger: <이유>. 대안의 강한 케이스를 웹근거와 함께." })
   ```
2. builder 출력(`alternative_statement` + `evidence[].url`)을 **verbatim**으로 4-block에 반대
   케이스로 제시 — conducting-interview는 이를 **약화·편집하지 않습니다**(AC5).
3. **게이트**(P17): 사용자가 (방어 → 원안 유지 / 전환 → 대안 채택, 원안은 R4로 / 보류 → §3 OQ) 중 하나를 선택한다.
4. 판정을 payload §5의 **`verdict:` 항목**으로 기록 — 각 항목은 (대안 statement + 웹근거 URL + `verdict ∈ {defended | switched | deferred}` + audit §3의 `ST<N>` 참조). 게이트 매핑: 방어→`defended`, 전환→`switched`, 보류→`deferred`(§3 OQ에도 박제). builder 출력 verbatim은 audit §3에 `#### ST<N>` 헤딩으로 남고, payload §5와 audit §3은 이 `ST<N>` id로 맞물린다(bijection A) — frontmatter에는 별도 필드를 두지 않는다.
5. 한 방향당 steelman 1회(새 근거 없으면 재steelman 금지 — AP16 harassment 방지).

**Web 부재 시 graceful degradation (AC8 대칭)**: `steelman-builder`는 WebSearch/WebFetch를 요구합니다.
kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구 부재로 steelman을 돌릴 수 없으면 —
R2 landscape와 대칭으로 — opaque한 "malformed skepticism (no-url)" 게이트 실패로 떨어뜨리지 말고
**loud advisory**를 내고 **수동 의심 게이트**로 전환합니다:
`[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청`. 이 경우 §5의
`verdict:` 항목은 사용자 판단(방어/전환/보류)을 근거로 기록하되 URL 부재 사유를 명시합니다(`check_brief.py`의
skepticism 형식 검사는 web-disabled 시 V10 manual로 위임).

**Law 2 경계**: steelman 게이트는 Law 2 분리 메커니즘이 *아닙니다* — Law 2 분리 reviewer는
오직 design doc(brainstorming `-design.md`)에만 적용됩니다. steelman은 문제공간 품질을 끌어올리는
Law 1급 skepticism 의례입니다(verbatim pass-through로 무력화 방지).

## 종료 — brief 작성 + optional handoff

종료 driver는 **커버리지 원장의 floor 5차원이 전부 `closed`** 인 것이다(고정 라운드 수 아님, G1).
다음을 모두 만족하면 brief를 작성합니다:

- floor `root_problem` closed — 진짜 problem이 한 문장으로 재구성(R1 계열).
- floor `landscape` closed — landscape가 인용과 함께 수집(R2 계열, web sweep 메커니즘 유지).
- floor `skepticism` closed — 의심 방향이 모두 steelman 통과(R3 계열, steelman-builder 게이트 유지).
- floor `blind_spot` closed — blind-spot-prober가 unknown-unknown을 표면화하고 payload §5의 `위험` 항목에 기록.
- floor `open_questions` closed — 미해결 명시(박제, "유추 금지").

각 차원의 status 전이(open→in-progress→closed)와 evidence 기록은 **orchestrator만** 수행하며
(coverage-mapper·blind-spot-prober는 read-only 제안자, Law 2), state.local.md에 쓰는 동시에
audit §1 `## Coverage Ledger`에 직렬화합니다.

### Step A — brief 작성 (terminal 산출물, 2파일)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 payload **8-section**
   구조(§0 한눈에 – §7 Next Action)를, `${CLAUDE_PLUGIN_ROOT}/templates/interview-audit-template.md`로
   audit **5-section** 구조를 확보합니다.
2. 경로 (둘 다 워크트리 안 → `Write` tool 사용):
   - payload: `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md`
   - audit:   `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.audit.md`
   - payload frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용), `audit_file`(audit의 **basename만** —
     경로 구분자가 들어가면 게이트가 거부합니다), `user_sourced_items[]`.
3. **`user_sourced_items` 직렬화**: state의 `user_statements`를 훑어 제약으로 승격할 항목을
   고르고, 각각에 id·`source`·`statement`(160자 이내)·`evidence`(그 발화의 `S<N>`)를 붙입니다.
   **이 시점의 `status`는 전부 `provisional`입니다** — `confirmed`는 Step B-0의 사용자 확인
   으로만 발생합니다. 모델 추론은 이 리스트에 넣지 말고 본문에 ✎ 프로즈로 씁니다.
   `user_statements`의 발화 전부를 payload §6에 **전문 보존**하고 `S<N>` 앵커를 답니다.
4. **Coverage Ledger 직렬화**(게이트 *전*): state의 `coverage`를 **audit §1**에 한 줄당 한
   차원으로 직렬화(floor 5행 + derived 또는 `- derived: N/A`). floor 전부 `closed`가 아니면
   이 시점에 도달하면 안 됩니다(종료 driver 위반). steelman 원문은 audit §3에
   `#### ST<N> — <한 줄 요지>` 헤딩과 함께 verbatim으로 남기고, payload §5의 `verdict:` 항목이
   그 `ST<N>`을 참조합니다 — 양방향 일치가 게이트 대상입니다.
5. **기계적 게이트 검증**(AC3) — 직렬화 직후. payload 경로만 넘기면 게이트가 `audit_file`로
   audit을 해석합니다:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 항목을 보완(누락 섹션·무인용
   landscape·형식 미달 verdict 항목·`기각` 0건·floor open·bijection 불일치). 통과(exit 0)할
   때까지 반복합니다.

### Step B — proceed 게이트 (handoff 방식 제안)

brief는 **단독 완결 terminal 산출물**입니다(NG7 — handoff는 강제가 아니라 사용자 선택).
Step B는 단일 책임 단위입니다: *brief가 완결되면 다음 stage(brainstorming 해답공간) 진입
방식을 사용자에게 제안한다.* 입력 = 완결·`check_brief.py` 검증된 brief 경로 + superpowers
가용성. 이 핸드오프는 `reviewing-spec` Phase 5의 `/compact` proceed 게이트와 **대칭**입니다 —
같은 두 가드(AP2 + cross-compact)를 interview 어휘로 독립 저술합니다(상세 모델:
`skills/reviewing-spec/SKILL.md` Phase 5).

#### B-0 — 확정 후보 제시 (게이트에 흡수, AC2)

Step A가 끝난 시점에 `user_sourced_items`는 **전부 `provisional`**입니다. `confirmed`로의
전이는 아래 B-2 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때만 일어납니다.
별도 확인 의례를 만들지 않는 이유는 종료 시 사용자 상호작용이 2회가 되기 때문입니다 —
확인을 기존 proceed 게이트에 흡수해 1회로 유지합니다.

게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로
`AskUserQuestion`은 선택지만 담당):

- 각 후보를 `<id> — <statement> (source, ⟨S<N>⟩)` 한 줄로.
- **확정 후보에서 제외한 항목도** 한 줄씩 이유와 함께 보여줍니다 — 제외 항목을 감추면
  사용자가 누락을 잡을 수 없습니다.
- 모델의 후보 판정은 **제안일 뿐**입니다. 어떤 항목도 이 출력만으로 `confirmed`가 되지 않습니다.

**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드): 최초 제시는 0회째입니다. 사용자가
옵션 ③(확정 목록 수정)을 고를 때마다 state의 `confirm_repost_count`를 +1 하고 **2회까지**
허용합니다. 3번째 ③ 요구 시 전 항목을 `provisional`로 강등하고 아래 **고정 문자열**을 출력한
뒤 게이트를 재제시하지 않고 **④와 동일한 terminal 경로로 종료합니다**(handoff 안 함 —
사용자가 ③을 골랐지 ①/②를 고른 적이 없으므로, 게이트 없이 brainstorming으로 자동 진행하는
것은 B-4의 P17/AP2 금지 대상이다). 종료 방향인 이유는 확정이 덜 되는 쪽이 안전한 방향이기
때문입니다:

```
[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등
```

카운터는 프로즈 self-tracking이 아니라 state에 씁니다(PN1 Bash write contract):

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# confirm_repost_count read-modify-write via python3 -c / heredoc
```

#### B-1 — superpowers 가용성 분기 (AC13 보존)

- **superpowers 부재 시 (AC13)**: 현행 graceful degradation 그대로 — brief를 완료하고 **loud advisory**를 낸 뒤 **정지(STOP)**. 게이트 없음(compact 후 넘길 대상 자체가 없음). crash·spec-mode fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.`

- **superpowers 가용 시**: B-2 proceed 게이트 제시.

#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC20/AC2)

게이트 *이전*에 brief 경로 존재를 확인합니다(`[[ -f <brief-path> ]]` — race 방어 경량 가드,
`AskUserQuestion` 게이트 자체는 아님). 부재 시 reviewing-spec Phase 5 Step A와 대칭으로
`/compact`를 노출하지 *않고* loud advisory 후 STOP(`approve_handoff.sh` 미호출 — 설계 §5.3):

> `[spec-distill] brief '<brief-path>' 부재 — 재작성/세션 리셋 필요`

(Step A의 작성 + `check_brief.py` 검증 직후라 정상 경로에선 발생하지 않습니다.)

brief 유효 시 **한 번의** `AskUserQuestion`으로 다음 단계를 제안합니다:

```javascript
AskUserQuestion({
  questions: [{
    question: "interview brief 완결: <brief-path> (구조 게이트 통과). 확정 후보는 위 목록대로. 다음 단계?",
    header: "Proceed",
    options: [
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 status: confirmed로 반영 → 재저장 → 게이트 재실행 → verbatim /compact 노출. 긴 인터뷰 context 정리 이점."},
      {label: "확정하고 바로 brainstorming", description: "확정 반영 후 즉시 Skill superpowers:brainstorming <brief-path> 호출 (compact 없이, 전체 context 유지)."},
      {label: "확정 목록 수정", description: "확정 후보를 고쳐 다시 제시 (상한 2회). 확정 전이 없음."},
      {label: "brief만 종료", description: "brief는 단독 완결 terminal (NG7). 전 항목 provisional 유지, handoff 안 함."}
    ],
    multiSelect: false
  }]
})
```

#### B-3 — 응답 처리

**규약의 거처 (C5).** `superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **orchestrator의 호출 프롬프트**에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. 아래 ①과 ② **양쪽 모두** 같은 문장을 싣습니다.

**확정 반영 절차 (①/② 공통).** `provisional` → `confirmed` 전이와 함께, Step A가 confirmed
0건일 때 넣었던 sentinel 한 줄(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`)이 남아 있으면
**같은 write에서 삭제**합니다. `check_brief.py`는 이 잔존을 잡지 못합니다 — confirmed가 한 건이라도
있으면 sentinel *요구*가 해제될 뿐 잔존을 거부하지는 않아, 지우지 않으면 confirmed 항목 옆에
"전부 잠정"이라 적힌 자기모순 brief가 그대로 나갑니다. 삭제까지 마친 뒤 재저장 → 게이트 재실행.

- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 →
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "compact 후 brainstorming 진입 준비됨" 안내:

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 §0 한눈에, §2 제약, §3 Open Questions, §6 사용자 원문), audit 파일 경로 참조, **그리고 아래 '재결정 규약' 문장**을 유지하고, round-by-round 인터뷰 대화·web sweep 원문·steelman 중간 추론은 drop. 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 다음 단계: Skill superpowers:brainstorming <brief-path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것**(compact 전
  brainstorming 진입 = 옵션 ① 무력화). `Skill superpowers:brainstorming <brief-path>` 진입은
  사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write design`처럼
  compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동
  진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 바로 brainstorming**: 확정 반영 → 재저장 → 게이트 재실행 → 즉시
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장을 함께
  싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`

  이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.

- **③ 확정 목록 수정**: 확정 전이 없음. `confirm_repost_count` +1 후 B-0으로 돌아가 수정된
  목록을 재제시(상한 2회 — 초과 시 B-0의 강등 경로).

- **④ brief만 종료**: 전 항목 `provisional` 유지. brief terminal advisory(B-1 부재 advisory와
  같은 톤) 출력 후 종료. handoff 안 함. state는 SessionEnd hook이 cleanup.

#### B-4 — 두 가드 (load-bearing)

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate하고 게이트 제시/Skill 호출을
  skip하는 것은 **polite stop** — 금지. Step B를 *종료*하는 모든 경로는 (a) 위 proceed 게이트를
  거치거나(①/②/③/④), (b) 게이트를 거치지 않는 예외(superpowers 부재)는 명시적 advisory 단락을
  동반해야 한다 — 게이트-less **silent 종료 금지**. (게이트는 사용자가 redirect 가능한 approval
  gate이므로 P17 주권에 기여, polite-stop 아님 — 철학 §AP2.)

- **cross-compact 조기진행 금지 (AC21, AC19 대칭)**: 옵션 ① 선택 시 `/compact`를 노출한 *직후*
  같은 턴에서 `brainstorming`으로 직진하는 것은 금지. compact가 무거운 작업 *뒤에* 오면 context
  위생 이점이 사라져 옵션 ①이 무의미해진다(reviewing-spec AC19에서 실측된 실패 패턴의 대칭).
  **다음 턴** 진입은 *사용자 트리거*(B-3 ①의 정규 문구: compact 뒤에 붙인 진행 인자 예 `/compact
  write design`, 또는 명시적 진행 요청)로만 일어나며 모델 자동 진입이 아니다(NG4·P17). polite
  stop이 "진행해야 할 때 멈춤"이라면 이것은 "멈춰야 할 때 진행" — 두 방향 모두 게이트의
  사용자-주권(P17)을 우회한다. 옵션 ②는 이 정지 요건의 *명시적 예외*(compact 없이 즉시
  brainstorming).

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).

## In-flight state migration (AC5)

state.local.md 로드 시 **구세션 스키마**(`interview_round` 존재 / `coverage` 부재)를 감지하면
*non-mutating read*로 fresh 초기화(승격):

- `coverage.floor`의 5개 차원(root_problem/landscape/skepticism/blind_spot/open_questions) 전부
  `{status: open, evidence: ""}`로 seed.
- `coverage.derived`: `[]`.
- `probe_count`: **0** (interview_round 값 승계 금지 — 라운드 수는 probe 수가 아니다).
- `probe_cap_override`: `0`.
- `orchestration`: `{focused_dimension: null, no_progress_streak: 0, blind_spot_dispatched: false, coverage_mapper_last_probe: null}`.

기존 필드(`non_user_streak`·`web_*`·`issue_history` 등)는 유지. 구세션의 라운드별 잠금
레코드 리스트(v0.22.0까지의 잠금 필드)는 승계하지 않고 `user_statements: []`로 fresh
seed합니다 — 잠금 레코드를 발화 레코드로 승격하면 판정이 없던 척하는 잠금이 그대로
넘어옵니다.

**영속화 시점**: 승격된 스키마는 재개된 세션의 첫 액션으로, 첫 probe나 `probe_budget.py increment`/`raise-cap` 호출보다 먼저 Bash 전체-frontmatter write로 즉시 디스크에 반영한다(PN1 state write contract). 이 즉시 write가 AC5의 "다음 명시적 state write"다 — 연기가 아니라 resume 직후 1회.

근거: `increment`/`raise-cap`은 카운터 라인이 부재하면 fail-closed(exit 1, silent-create
금지)이므로, 이 write 없이는 `probe_count`가 디스크에 없는 채로 첫 probe가 발생해 백스톱이
무력화된다.

이 write는 신규 필드(coverage/probe_count/probe_cap_override/orchestration)만 추가하는
forward promotion이며 backward-rewrite가 아니다 — `interview_round`는 이 write에서 자연
소멸하되 다른 기존 필드는 고치지 않는다. AC5의 backward-rewrite 금지·P14 실패-상태 보존과
무충돌: 이것은 성공적 resume의 promotion write이지 실패-상태 mutation이 아니다.

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.22.0] state schema migration: coverage/probe_count added (interview_round retired).
```

자동 promote 실패 시(파일 corruption 등) → "구세션 in-flight state 호환 실패 — 세션 재시작 권장"
알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용 (AC8).
