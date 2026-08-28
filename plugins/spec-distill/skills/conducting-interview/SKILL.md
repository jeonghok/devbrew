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

## State location

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
  stall_episode: 0                   # streak 이 0 으로 reset 될 때마다 +1. 정체 «구간»의 id
  coverage_mapper_dispatched_episode: null   # 마지막 dispatch 가 일어난 에피소드 id
non_user_streak: <int>
rereview_count: 0
trivia_escape_armed: false
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
user_statements: []                  # 매 round 끝 append. 판정 없음 — 확정은 종료 게이트가 결정.
confirm_repost_count: 0              # 종료 확정 확인 재제시 횟수 (상한 2, Unbounded-autonomy 가드)
---
```

State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) coverage-mapper 출력 transcript.

**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후
기록합니다. **치환 토큰은 `<REDACTED>` 또는 `<REDACTED:라벨>` 형태**로 씁니다(다른 허용 형태:
`<SECRET:...>` · `<TOKEN:...>` · `<KEY:...>` · `<CREDENTIAL:...>` · `<PLACEHOLDER:...>`).
`check_verbatim_coverage.py`가 §6 원문 대조에서 **이 토큰 집합**을 보고 L2를 advisory로 강등하므로,
다른 형태로 치환하면 정당한 치환이 red로 잡혀 사용자가 Step B에서 판정해야 합니다(fail-closed 방향).

### State write contract (PN1 — worktree-safe)

`state.local.md`는 `state_path.py`가 **main repo** `.claude/spec-distill/<sid>/`로 라우팅합니다
(`git rev-parse --git-common-dir`). 워크트리 세션에서 이 경로는 워크트리 *밖*이라 `Write`/`Edit`
tool이 차단됩니다 — state 갱신은 **반드시 Bash**로 하십시오:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"
STATE="$ROOT/<session-id>/state.local.md"
# read-modify-write via python3 -c / heredoc (Edit tool 사용 금지 — main-repo 경로)
```

**brief는 예외**: `docs/superpowers/interview/`는 워크트리 *안*이라 `Write` tool로 정상 작성.

## 4-block Korean format (devbrother2024 deep-interview 흡수)

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

## teach-beat (C3/C12 — 미지를 드러내 가르치기)

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
- id: S<N>                 # N = user_statements.length + 1 + (최초 요청 원문 있으면 1, 없으면 0 — finishing.md S1 예약과 합의)
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

`non_user_streak >= DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 probe의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

## coverage-mapper dispatch (C11)

`coverage-mapper`는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(원장 admit
판정은 orchestrator, G2). 다음 조건 중 하나에서 dispatch:

1. 한 focused 차원이 **연속 3 probe** 동안 status·evidence 무변경(진전 없음), OR
2. floor 차원의 **첫 open→in-progress 전이**.

진전 = status 전이(open→in-progress→closed) 또는 evidence append. `orchestration.no_progress_streak`는
focused 차원이 바뀌거나 진전 발생 시 0으로 reset.

**redispatch 바운드(Unbounded-autonomy 가드)**: 재dispatch 조건은
`no_progress_streak >= 3 AND coverage_mapper_dispatched_episode != stall_episode` 다. dispatch
시 `orchestration.coverage_mapper_dispatched_episode = stall_episode` 를 기록하고,
`no_progress_streak` 가 0 으로 reset 될 때마다 `stall_episode` 를 +1 한다. 한 정체 구간당
정확히 1회다.

판정은 **디스크 두 값의 비교**이므로 어느 턴에서든 무상태로 재계산된다 — 그 성질을 잃으면
판정이 모델의 턴-간 기억에 의존하는 *프로즈 self-tracking*이 되어, 이 문단이 세운 기계적
bound 자체가 무너진다. **streak 값 자체를 저장하지 않는 이유**: streak 3 에서 dispatch(저장
3) → streak 4 → `3 != 4` → 재dispatch → streak 5 → 재dispatch … 로 레벨-트리거 무한
재dispatch 가 그대로 살아난다.

**dispatch 조건 2 는 이 바운드의 대상이 아니라 «바운드가 불필요»하다.** floor 차원의 첫
`open→in-progress` 전이는 대상이 **floor 다섯 차원으로 고정**이므로(derived 차원은 그 조건의
대상이 아니다) 상한이 5 다. 유한성이 구조에서 나오므로 추가 바운드를 두지 않는다.

**이 바운드가 묶는 것은 «밀도»이지 «총량»이 아니다.** 정체 구간 수에는 상한이 없고,
coverage-mapper 가 제안한 derived 차원이 원장에 admit 되면 새 focused 대상이 생겨 새 정체
구간을 낳는 되먹임도 있다. 총량 바운드는 이 판본에 없다(설계 §11 이월).

**Web kill switch (dispatch 직전 확인 — 이 블록에 종속)**: `coverage-mapper`는
`WebSearch`/`WebFetch`를 보유한다. kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`이면
dispatch 프롬프트에 `web_disabled: true`를 실어 **codebase 근거만으로 차원을 제안**하게 하고,
loud advisory를 남긴다: `[spec-distill] web 비활성 — coverage-mapper가 codebase 근거만 사용`.
이 확인은 R2의 landscape 확인과 **별개로** 여기 있어야 한다 — kill switch는 보안 컨트롤이고,
egress를 가진 dispatch가 하나라도 게이트 밖에 있으면 스위치는 꺼졌다고 *믿게만* 만든다.
`coverage-mapper`는 `tools:`에 `Bash`가 없어 스스로 확인할 수 없다(Law 2) — orchestrator가
유일한 집행 지점이다.

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  web_disabled=true
  echo "[spec-distill] web 비활성 — coverage-mapper가 codebase 근거만 사용" >&2
else
  web_disabled=false
fi
```

```
Agent({ description: "Map coverage dimensions", subagent_type: "spec-distill:coverage-mapper",
        prompt: "열린/닫힌 차원 요약: <...>. focused_dimension: <...>, no_progress_streak: <N>. web_disabled: <true|false — true면 WebSearch/WebFetch 사용 금지, codebase 근거만>. 이 주제가 요구하는 derived 차원과 neglect를 제안." })
// **처분** — consumer=orchestrator · fail-open · disclosure=advisory
```

출력(`derived_dimensions[] + neglect_flag`)은 **advisory** — orchestrator가 원장에 admit할지 판정한다.
`neglect_flag: true`면 다음 probe에서 neglected 차원 하나를 추천 답안으로 제시. 복수 dispatch 시
name 기준 union·dedup.

## blind-spot-prober dispatch (C8 — blind_spot floor 차원)

`blind_spot` floor 차원의 **첫 open→in-progress 전이**(그 차원에 첫 probe 착수) 시 `blind-spot-prober`를
**인터뷰당 1회** dispatch한다(fan-out 1, C8). `orchestration.blind_spot_dispatched`가 false일 때만
dispatch하고, dispatch 후 true로 세팅(재dispatch 금지).

```
Agent({ description: "Adversarial premortem", subagent_type: "spec-distill:blind-spot-prober",
        prompt: "재구성된 문제정의: <...>. 지금까지의 사용자 제약 요지: <...>. 이 framing의 hidden assumption과 failure mode를 웹근거와 함께." })
// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
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
하나라도 미충족이면 종료 차단. 종료 직전 `check_brief.py gate`로 **기계적 검증**:

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Reframe (메타 프롬프트)** | 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal. | (d) ontological 5-type (ESSENCE/ROOT_CAUSE/...) → payload §0 한눈에(스냅샷) + §1 Goal · Non-goal(진짜 goal) |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 → payload §4 External Landscape |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *방어 또는 전환*. un-challenged 의심 방향은 확정 후보가 될 수 없다. | steelman-builder dispatch → payload §5의 **`verdict:` 항목** |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* 기록. 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지). | payload §5의 **`기각` 항목** |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | payload §3 Open Questions |

### R2 — 웹 Landscape

토픽이 잡히면(round 1–2) landscape sweep을 수행합니다. 각 web 검색 *직전에* kill switch를
확인합니다(세션 시작 시 캐시하지 않고 매 호출 직전 재평가):

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  echo "[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용"
else
  # <web 검색 수행>
  :
fi
```

- 모든 외부 주장은 **출처 URL 필수** — payload §4 External Landscape에 `[취함|피함|중립]` + 이유와 함께.
- **kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`** 또는 web 도구 부재 → landscape를 **loud하게
  생략**하고 계속(crash 금지, graceful degradation): `[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용`.

### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌 / coverage-mapper neglect.

1. `steelman-builder` 에이전트를 dispatch:
   ```
   Agent({ description: "Steelman alternative", subagent_type: "spec-distill:steelman-builder",
           prompt: "의심 방향: <statement>. trigger: <이유>. 대안의 강한 케이스를 웹근거와 함께." })
   // **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
   ```
2. builder 출력(`alternative_statement` + `evidence[].url`)을 **verbatim**으로 4-block에 반대
   케이스로 제시 — conducting-interview는 이를 **약화·편집하지 않습니다**.
3. **게이트**(P17): 사용자가 (방어 → 원안 유지 / 전환 → 대안 채택, 원안은 R4로 / 보류 → §3 OQ) 중 하나를 선택한다.
4. 판정을 payload §5의 **`verdict:` 항목**으로 기록 — 각 항목은 (대안 statement + 웹근거 URL + `verdict ∈ {defended | switched | deferred}` + audit §3의 `ST<N>` 참조). 게이트 매핑: 방어→`defended`, 전환→`switched`, 보류→`deferred`(§3 OQ에도 박제). builder 출력 verbatim은 audit §3에 `#### ST<N>` 헤딩으로 남고, payload §5와 audit §3은 이 `ST<N>` id로 맞물린다(bijection A) — frontmatter에는 별도 필드를 두지 않는다.
5. 한 방향당 steelman 1회(새 근거 없으면 재steelman 금지 — AP16 harassment 방지).

**Web 부재 시 graceful degradation (R2 대칭)**: `steelman-builder`는 WebSearch/WebFetch를 요구합니다.
kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구 부재로 steelman을 돌릴 수 없으면 —
R2 landscape와 대칭으로 — opaque한 "malformed skepticism (no-url)" 게이트 실패로 떨어뜨리지 말고
**loud advisory**를 내고 **수동 의심 게이트**로 전환합니다:
`[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청`. 이 경우 §5의
`verdict:` 항목은 사용자 판단(방어/전환/보류)을 근거로 기록하되 URL 부재 사유를 명시합니다(`check_brief.py`의
skepticism 형식 검사는 web-disabled 시 수동 판단으로 위임).

**Law 2 경계**: steelman 게이트는 Law 2 분리 메커니즘이 *아닙니다* — Law 2 분리 reviewer는
오직 design doc(brainstorming `-design.md`)에만 적용됩니다. steelman은 문제공간 품질을 끌어올리는
Law 1급 skepticism 의례입니다(verbatim pass-through로 무력화 방지).

## 종료 — brief 작성 + optional handoff

**종료 절차 전문은 `references/finishing.md` 에 있다.** floor 5차원이 전부 `closed` 가 되어
brief 작성으로 넘어갈 때 그 파일을 Read 로 읽어 그대로 따른다. 인터뷰가 아직 진행 중일 때는
읽지 않는다 — 이 분리의 목적이 그것이다(조건부 로드).

### 나가는 문은 floor 뒤에만 있지 않다

floor 다섯이 전부 `closed` 여야 종료가 열리지만, **사용자는 언제든 종료를 요청할 수 있다.**
그때 미충족 floor 는 **사용자-승인 박제**로 닫는다 — 그 차원의 `evidence` 에
`사용자-승인 박제(@사용자 종료 요청) — §Open Questions 참조` 를 적고, 그 내용을 payload
§3 Open Questions 로 이월한다. 박제 표식이 원장에 남으므로 silent bypass 가 아니다.

발동 조건이 카운터가 아니라 **사용자 발화**라는 점만 예전 escalation 과 다르다. 상한을
없애는 것과 탈출구를 없애는 것은 다르다 — 없애는 것은 사용자 질문의 상한이지 나가는 문이
아니다.

읽어야 하는 조건: `coverage.floor` 의 다섯 차원이 모두 `status: closed`.

```
Read references/finishing.md
```

경로는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이 SKILL.md와
같은 위치에 `references/finishing.md` 가 있으므로 그대로 resolve 된다.

## In-flight state migration

state.local.md 로드 시 **구세션 스키마**(`interview_round` 존재 / `coverage` 부재)를 감지하면
*non-mutating read*로 fresh 초기화(승격):

- `coverage.floor`의 5개 차원(root_problem/landscape/skepticism/blind_spot/open_questions) 전부
  `{status: open, evidence: ""}`로 seed.
- `coverage.derived`: `[]`.
- `orchestration`: `{focused_dimension: null, no_progress_streak: 0, blind_spot_dispatched: false, stall_episode: 0, coverage_mapper_dispatched_episode: null}`.

기존 필드(`non_user_streak`·`web_*`·`issue_history` 등)는 유지. 구세션의 라운드별 잠금
레코드 리스트(v0.22.0까지의 잠금 필드)는 승계하지 않고 `user_statements: []`로 fresh
seed합니다 — 잠금 레코드를 발화 레코드로 승격하면 판정이 없던 척하는 잠금이 그대로
넘어옵니다.

**영속화 시점**: 승격된 스키마는 재개된 세션의 첫 액션으로, 첫 probe보다 먼저 Bash
전체-frontmatter write로 즉시 디스크에 반영한다(PN1 state write contract). 이 write는
"다음 명시적 state write"를 기다리지 않는다 — 연기가 아니라 resume 직후 1회다.

근거: coverage-mapper 재dispatch 바운드(`## coverage-mapper dispatch`)는 `orchestration`의
두 에피소드 필드(`stall_episode`·`coverage_mapper_dispatched_episode`)를 디스크에서 직접
비교한다 — 이 write 없이는 그 필드들이 디스크에 없는 채로 첫 probe가 발생해 판정이 무상태
재계산 전제를 잃는다.

이 write는 신규 필드(coverage/orchestration)만 추가하는 forward promotion이며
backward-rewrite가 아니다 — `interview_round`는 이 write에서 자연 소멸하되 다른 기존
필드는 고치지 않는다. backward-rewrite 금지·P14 실패-상태 보존과 무충돌: 이것은 성공적
resume의 promotion write이지 실패-상태 mutation이 아니다.

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.37.0] state schema migration: coverage/orchestration added (probe counters retired).
```

자동 promote 실패 시(파일 corruption 등) → "구세션 in-flight state 호환 실패 — 세션 재시작 권장"
알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_SPEC_DISTILL_DISABLE=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용.
