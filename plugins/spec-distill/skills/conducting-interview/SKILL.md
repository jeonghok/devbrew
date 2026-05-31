---
name: conducting-interview
description: >
  Use this skill to run the spec-distill interview — a strong problem-space stage
  (Double Diamond 1st diamond) that reframes the request (meta-prompting), grounds
  it with bounded web research, breaks weak directions with adversarial steelman,
  and pre-resolves trial-and-error. Produces a terminal interview-brief meta-prompt
  at docs/superpowers/interview/. Called by /interview after trivia escape. Runs the
  5 통과 의례 (R1-R5) as a Law 1 structural gate (check_brief.py). Optionally hands the
  brief to superpowers:brainstorming. Persists state to main-repo
  .claude/spec-distill/<session-id>/state.local.md (written via Bash — PN1).
cost_class: variable
user-invocable: false
---

# Conducting Interview — 문제공간 Stage (Phase 1)

당신은 spec-distill의 인터뷰 stage를 진행 중입니다. 이 stage는 *받아적는* 인터뷰가
아니라 **강한 문제공간 stage**입니다(Double Diamond 1st diamond — brainstorming 해답공간
앞단, 상보적·비중복). 4-block Korean Socratic format으로 round를 진행하되, 종료 전 **5
통과 의례**를 모두 통과해야 brief 작성이 허용됩니다(Law 1 구조 게이트).

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
interview_round: <int>
non_user_streak: <int>
web_sweep_count: 0                   # 현재 sweep 내 web 검색 호출 수 (AP9, ≤4). sweep 종료 시 0으로 reset.
web_search_count: 0                  # 세션 누적 web 검색 호출 수 (AP16, ≤8 soft cap).
rereview_count: 0
wall_clock_started_at: <ISO8601>
trivia_escape_armed: false
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
pending_locked_decisions: []         # 매 round 끝 append (b/d path 명시 응답만). brief frontmatter locked_directions로 변환.
---
```

State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) breadth-keeper 출력 transcript.

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

## Locked 판정 트리거 (G1, AC1)

매 round 끝에 사용자 응답을 `pending_locked_decisions`에 append할지 다음 decision table로 판정:

| 사용자 응답 유형 | path | locked? |
|---|---|---|
| 명시적 수락 (예/동의/선택지 1개 선택/자유 텍스트로 결정 명시) | b, d | ✅ true |
| 명시적 거절 (아니오/거절/대안 제시) | b, d | ✅ true (반대 명제로 locked) |
| 보류 ("잘 모르겠음", "둘 다 괜찮음", "나중에 결정") | b, d | ❌ false — Open Questions로 박제 |
| "추가 정보 필요" / "더 설명해주세요" | b, d | ❌ false — re-ask 또는 OQ |
| factual auto-confirm | a | ❌ false (사용자 미답변) |
| sub-agent ambiguity 답안 | c | ✅ true ONLY IF 사용자 confirm 받음 |

`locked? == true` 항목은 매 round 끝에 다음 형식으로 `pending_locked_decisions`에 append:

```yaml
- id: LD<N>                          # N = pending_locked_decisions.length + 1
  section: "#<spec-section-anchor>"  # 답변이 spec의 어느 섹션에 박힐지 (예: "#goals", "#acceptance-criteria")
  summary: "<160자 이내 한 줄 요약>"   # P21 secret placeholder 치환 적용
  source: interview-round-<N>        # 운영 경로 표시
  source_path: b | c | d             # 어느 routing path에서 왔는지
```

## C44 Dialectic Rhythm Guard

`non_user_streak` 카운터 — 직전 N round 동안 *사용자 답변이 없었던* 횟수.

- (a) factual auto-confirm: streak +1
- (c) sub-agent adversarial: streak +1
- (b) 사용자 답변 받음: streak = 0
- (d) ontological 사용자 답변 받음: streak = 0
- (a) web auto-research: streak +1 (과도하면 강제 (b)로 사용자를 loop에 유지 — AP16).

`non_user_streak >= DEVBREW_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 round의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

## breadth-keeper dispatch (C45, AC13)

매 round 끝에 다음 조건 모두 만족하면 `breadth-keeper` agent를 1회 dispatch:

1. `interview_round >= 2` (첫 round는 탐색기 — skip)
2. 직전 3 round가 같은 dimension(같은 spec 섹션)에 집중함
3. 이번 round에서 dispatch 안 한 경우 (round당 max 1, AC13)

dispatch 결과 (`narrow_tunneling: true`) 면 다음 round 시작 시 `suggested_lateral_questions` 중 하나를 추천 답안으로 제시.

## 5 통과 의례 (Law 1 구조 게이트, R1–R5)

brief 작성(+ optional brainstorming invoke)은 다음 5 의례를 **모두 통과**해야 허용됩니다.
하나라도 미충족이면 종료 차단. 종료 직전 `check_brief.py gate`로 **기계적 검증**(AC3):

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Reframe (메타 프롬프트)** | 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal. | (d) ontological 5-type (ESSENCE/ROOT_CAUSE/...) → brief §1 |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 → brief §3 |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *방어 또는 전환*. un-challenged 의심 방향 lock 불가. | steelman-builder dispatch → brief §4 |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* 기록. 0건이면 `N/A — 전부 first-time defend+lock` 명시(빈 섹션 금지). | brief §5 |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | brief §6 |

### R2 — 웹 Landscape (bounded, AC7/AC8)

토픽이 잡히면(round 1–2) landscape sweep **1회**를 수행합니다. 각 web 검색 *전에* state의
`web_sweep_count`/`web_search_count`를 +1 하고(PN1 Bash write) budget을 확인:

```bash
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/hooks/state_path.py" state-root)"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/web_budget.py" check "$ROOT/<session-id>/state.local.md" || {
  echo "[spec-distill] web budget 초과 — landscape 중단, 강제 (b) 사용자 질문" ; }
```

- budget 초과(sweep>4 또는 session>8) → advisory + **강제 (b) 사용자 질문**(AP16).
- 모든 외부 주장은 **출처 URL 필수**(AC4) — brief §3에 `[취함|피함|중립]` + 이유와 함께.
- **kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`** 또는 web 도구 부재 → landscape를 **loud하게
  생략**하고 계속(crash 금지, graceful degradation — AC8): `[spec-distill] web 비활성 — landscape 생략, codebase 근거만 사용`.
- sweep 종료 시 `web_sweep_count`를 0으로 reset(session 카운터는 유지).

### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 LD 불일치 / breadth-keeper tunneling.

1. `steelman-builder` 에이전트를 **순차** dispatch(병렬·투기적 금지 — C5):
   ```
   Agent({ description: "Steelman alternative", subagent_type: "spec-distill:steelman-builder",
           prompt: "의심 방향: <statement>. trigger: <이유>. 대안의 강한 케이스를 웹근거와 함께." })
   ```
2. builder 출력(`alternative_statement` + `evidence[].url`)을 **verbatim**으로 4-block에 반대
   케이스로 제시 — conducting-interview는 이를 **약화·편집하지 않습니다**(AC5).
3. **게이트**(P17): 사용자가 (방어 → 원안 lock + `defense` 기록, steelman: defended) /
   (전환 → 대안 lock, 원안은 R4로, steelman: switched-to-this) / (보류 → §6 OQ).
4. builder 출력 그대로 brief §4 Skepticism Log에 기록 — 각 항목은 (대안 statement + 웹근거 URL + `verdict ∈ {defended | switched | deferred}`). 게이트 매핑: 방어→`defended`, 전환→`switched`, 보류→`deferred`(§6 OQ에도 박제). 프론트매터 `steelman:` 라벨(`switched-to-this`)과 §4 `verdict` 어휘(`switched`)는 별개 — §4에는 위 세 단어만 사용.
5. 한 방향당 steelman 1회(새 근거 없으면 재steelman 금지 — AP16 harassment 방지).

**Law 2 경계**: steelman 게이트는 Law 2 분리 메커니즘이 *아닙니다* — Law 2 분리 reviewer는
오직 design doc(brainstorming `-design.md`)에만 적용됩니다. steelman은 문제공간 품질을 끌어올리는
Law 1급 skepticism 의례입니다(verbatim pass-through로 무력화 방지).

## 종료 — brief 작성 + optional handoff

다음을 모두 만족하고 **5 통과 의례가 모두 통과**하면 brief를 작성합니다:

- Goal/진짜 problem이 한 문장으로 재구성됨(R1).
- Landscape가 인용과 함께 수집됨(R2).
- 의심 방향이 모두 steelman 통과(R3).
- 시행착오가 기록됨(R4).
- Open Questions 박제(R5).

### Step A — brief 작성 (terminal 산출물)

1. `${CLAUDE_PLUGIN_ROOT}/templates/interview-brief-template.md`로 7-section 구조 확보.
2. 경로: `docs/superpowers/interview/<YYYY-MM-DD>-<kebab-topic>-interview.md` (워크트리 안 → `Write` tool 사용).
   - frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`,
     `session_id`(기존 spec-distill 세션 재사용 — 새 세션 생성 안 함), `locked_directions[]`
     (state `pending_locked_decisions` + steelman verdict 반영).
3. **기계적 게이트 검증**(AC3) — 작성 직후:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"
   ```
   exit ≠ 0 이면 **brief를 finalize하지 말고** 보고된 미충족 의례를 보완(누락 섹션/무인용
   landscape/형식 미달 steelman/빈 Tried&Discarded). 통과(exit 0)할 때까지 반복.

### Step B — optional handoff (superpowers 있을 때만)

brief는 **단독 완결**입니다. 다음은 *optional 다음 단계*입니다:

- **superpowers `brainstorming` skill 사용 가능 시**: 이 brief를 rich context로 전달하며
  `superpowers:brainstorming`을 호출(해답공간 설계 → `-design.md` → 기존 hook이 design mode로
  검증 → reviewing-spec → writing-plans).
- **superpowers 부재 시(AC13)**: brief를 완료하고 **loud advisory**를 낸 뒤 정지 — crash·spec-mode
  fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.`

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).

## In-flight state migration (C10)

state.local.md 로드 시 v0.1.x schema (신규 필드 부재)를 감지하면 *non-mutating read*로 자동 promote:

- `pending_locked_decisions` 부재 → `[]`로 in-memory default.
- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지 — 명시적 write 시점에만 frontmatter 갱신).

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.
```

자동 promote 실패 시 (파일 corruption 등) → 사용자에게 "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용 (AC8).
