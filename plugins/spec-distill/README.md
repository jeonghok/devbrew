# spec-distill

> 강한 문제공간 인터뷰(메타프롬프팅 + 웹 리서치 + adversarial steelman)로 방향을 끌어내 superpowers brainstorming용 interview brief를 생성하고, design doc은 물리 분리된 Law 2 reviewer가 검증하는 devbrew-native 플러그인.

## What it does

`/interview <rough request>` 호출 시 4-block Korean Socratic 인터뷰가 **강한 문제공간 stage**로
동작합니다: 요청을 재구성(메타프롬프팅)하고, 외부 사례를 웹으로 조사하고(bounded), 약한 방향을
steelman으로 깨뜨려, **interview brief**(brainstorming용 meta-prompt)를 **2파일 쌍**으로
산출합니다 — payload `docs/superpowers/interview/YYYY-MM-DD-<topic>-interview.md`(8섹션 역피라미드,
`templates/interview-brief-template.md`) + audit `…-interview.audit.md`(5섹션 텔레메트리,
`templates/interview-audit-template.md`). audit 이름은 payload 파일명에서 유도됩니다. 5 통과 의례(R1–R5)가
Law 1 구조 게이트입니다. brief는 단독 완결 산출물이며, superpowers가 있으면 brainstorming
해답공간으로(optional), design doc은 물리 분리된 reviewer가 Law 2로 검증합니다.

## Quick start

```
/interview todo 앱 만들어줘
```

`conducting-interview` skill이 4-block format ("현재 이해 / 막힌 결정 / 추천 답안 / 질문")으로 첫 round를 시작합니다.

## Flow (v0.24.0)

```
/interview ─→ [0] Trivia escape ─→ [1] Interview (문제공간 stage)
                                       · 4-block Socratic + 4-path (web=path(a))
                                       · R1 Reframe / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ
                                       ▼ 5 의례 통과 (check_brief.py gate, Law 1)
                                   interview brief (payload + audit) → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ [Step A.5]  ※ 구조 게이트를 통과했을 뿐 아직 분리 리뷰 전
                                   [2] reviewing-brief (Law 2 분리 리뷰, cost_class: high 승인 게이트)
                                       │  진입 첫 액션: check_verbatim_coverage.py (§6 원문 ↔ state 원장)
                                       ├─ 1단계 방향성  brief-direction-reviewer + codex #1  (보고만, 병합 없음)
                                       ├─ 2단계 충실도  brief-critic(격리) + codex #2  fail-closed 합집합
                                       │                needs_revise → 수정 → fresh 재리뷰 (재dispatch 상한 2)
                                       └─ 3단계 냉독    brief-readback  (advisory, G1–G5 gap)
                                       ▼ 산출물 4종 (확정 후보 / 방향성 C4 / readback+gap / 모든 degrade record)
                                       ▼ [Step B proceed 게이트] ①/compact 후 brainstorming · ②바로 brainstorming · ③확정 목록 수정 · ④brief만 종료  (superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
                                       ▼ [PostToolUse: design mode → pending_review]  (기존 hook)
                                       ▼ brainstorming user-review 정지 → 턴 경계
                                       ▼ [Stop: review-dispatch]  (기존 hook)
                                   [3] reviewing-spec → spec-reviewer (Law 2, design-mode only)
                                       ├─ approved → [5] proceed 게이트 → auto re-review, max 5 → writing-plans
                                       └─ needs_revise → brainstorming author 회귀 → 재검증
```

**v0.12.0**: drafting-spec 제거 + reviewing-spec design-mode 전용. interview는 brief까지 단독 완결.

**v0.13.0**: interview→brainstorming Step B를 `/compact` proceed 게이트(reviewing-spec Phase 5 대칭)로 재작성.

**v0.14.0–v0.18.0**: 리뷰 재발동을 막는 방어층 3종이 순차로 쌓였다 — 문서별 억제 집합, approve 시 기록 순서 교정, 문서-키 진행중 락. 셋 다 훅이 자기가 만든 재발동을 자기가 막는 내부 하니스였고 **v0.25.0 에서 원인과 함께 삭제**됐다(상세는 CHANGELOG).

**v0.23.0**: interview brief를 핸드오프 아티팩트로 재설계. 라운드마다 결정을 잠그던 producer를 제거하고(`user_statements`에 판정 없이 기록), 확정 권한을 **종료 시 사용자 일괄 확인**으로 되돌렸다. brief는 payload(8섹션 역피라미드) + audit(텔레메트리) **두 파일**로 갈라지고 `audit_file`로 묶이며, frontmatter `user_sourced_items` 계약과 세 bijection이 body↔frontmatter·payload↔audit drift를 잡는다.

**v0.22.0**: [1] Interview 종료 driver를 고정 라운드 카운터에서 커버리지 원장(고정 floor 5 + 주제-도출 차원, status ∈ {open, in-progress, closed})으로 재구성 — 집요함·깊이·차원이 주제에 적응한다. tunneling 검출 에이전트는 `coverage-mapper`(주제-도출 차원 advisory 제안자)로 재명명·재목적화되었고, `blind-spot-prober`(적대적 premortem, fan-out 1)가 blind-spot floor 차원 구현으로 신설되었다. `probe_budget.py`가 Unbounded-autonomy 백스톱.

**v0.24.0**: 구조 게이트를 통과한 interview brief에 **Law 2 분리 리뷰**(`reviewing-brief`)를 얹었다. 방향성(`brief-direction-reviewer` + codex #1, 보고만) → 충실도(`brief-critic` 격리 + codex #2, fail-closed 합집합) → 냉독(`brief-readback`, advisory) 3단계이고, `check_verbatim_coverage.py`가 진입 첫 액션으로 §6 원문 완전성을 state 원장과 대조한다. 리뷰어 셋은 전부 fail-closed `tools:` allowlist이며 `brief-critic`·`brief-readback`은 payload를 경로가 아니라 전문 inline으로 받는다. 모든 degradation은 `brief_review_degradations` 원장 + Step B 게이트 질문 텍스트로 표면화된다 — 돌지 못한 검사가 통과한 검사로 집계되지 않는다.

**v0.25.0**: design 문서를 편집할 때마다 리뷰가 재발동하던 원인 자체를 없앴다 — `scripts/arm_ledger.py`가 문서 생애 단 한 번만 arm하는 `arm-once` 게이트를 구현하고(세션 원장 `armed_paths` ∧ git 추적 여부로 판정), v0.14.0–v0.18.0에 쌓였던 방어층 3종(억제 집합·순서 교정·진행중 락)이 근거를 잃어 함께 삭제됐다.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws

- **Law 1 (Clarity Before Code)** — Plugin의 raison d'être. 인터뷰 → brief → design doc → reviewer → human gate. "spec 이전엔 코딩 안 한다" 강제. (`locked_decisions`는 design doc의 표식이 아니라 그 반대다 — `hooks/spec-write-validator.py`가 frontmatter에 이 키를 가진 파일을 **spec** 모드로 분류하고, `-design.md`를 포함한 나머지는 design 모드다.)
- **Law 1 (Clarity) — 문제공간 게이트 (v0.12.0)** — interview의 5 통과 의례(R1–R5)가 `check_brief.py`로 기계 검증되는 구조 게이트. 약한 방향(무인용 landscape·un-challenged 의심·빈 시행착오)은 brief 종료를 차단.
- **Law 2 (Writer/Reviewer 분리)** — `tools:` allowlist frontmatter로 spec-reviewer(`Read, Grep, Glob, WebSearch, WebFetch`) + coverage-mapper(`Read, Grep, Glob, WebSearch, WebFetch`) + blind-spot-prober(`Read, Grep, Glob, WebSearch, WebFetch`) agent의 *물리적* 분리. 프롬프트가 아닌 frontmatter scoping이며, **allowlist라 열거되지 않은 쓰기·실행·위임 도구가 자동 차단**된다(denylist는 시간에 대해 fail-open이라 v0.21.0에서 폐기).
- **Law 2 강화 (v0.3.0)** — Writer/Reviewer 분리를 turn-boundary 결정론으로 끌어올림. PostToolUse가 spec/design write를 감지해 *해당 turn 안* structural gate를 차단(exit 2)하고, Stop hook이 *다음 turn 첫 액션*으로 reviewer dispatch를 systemMessage 주입으로 강제. file-based ledger (`state.local.md` `pending_review:` block)가 trans-hook coordination을 LLM 의지에서 분리.
- **Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability**: spec-reviewer agent의 writer/reviewer 물리 분리가 의미를 가지려면 reviewer dispatch가 Claude context에 *실제로* 도달해야 한다. v0.5.0의 dual-target output fix가 이 baseline을 보장. dispatch가 silent하게 lost되면 reviewer persona 분리 자체가 무의미.
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.
- **Law 3 (Every Cycle Must Leave the System Smarter)**: v0.5.0 PR이 hook 코드 fix + `tests/test_hook_output_schema.py` 회귀 방지 test + CHANGELOG 명시 + design.md (아카이브됨: `git show pre-slim-archive-2026-07-09:docs/superpowers/specs/2026-05-17-spec-distill-hook-context-injection-design.md`) — 4-layer compounding 흔적. 같은 클래스의 silent-output mistake가 미래에 들어오면 CI에서 즉시 잡힘.
- **Law 3 (Compounding) — model diversity (v0.20.0)** — codex 병렬 co-reviewer를 design-doc 리뷰에 추가. codex가 Claude persona가 반복해 놓치는 결함류(fail-open)를 잡으면 → `spec-reviewer.md` 체크리스트 편집(persona = 보안-민감 코드)이 compounding 이벤트. quality-gates codex 패턴의 실증 이력을 상속.
- **AP2 approval-gate 구분 (v0.11.0)** — handoff 다음-단계 추천을 hook(텍스트 주입만 가능)이 아니라 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 전달. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 polite-stop 봉쇄 장치 (철학 AP2 앵커). `arm_ledger.py check-born`(v0.25.0)은 approve 시점에 문서가 git에 커밋됐는지만 확인한다 — 미커밋이면 advisory만 내고 아무 것도 기록하지 않는다(arm 판정은 리뷰 자신이 이미 마쳤으므로 기록할 상태가 남지 않는다). 세션 dir 삭제는 SessionEnd/TTL-GC로 이관.
- **Law 1 fail-safe + Law 2 (v0.25.0)** — arm 판정(`scripts/arm_ledger.py`)의 어떤 실패(원장 read 불능, git 불능·리포 밖, 모듈 부재)도 **arm 쪽으로 fail-open** 한다(over-review > under-review). 예외는 `session_id` 미해석 하나 — 그것은 판정 신호가 아니라 상태를 어디에 쓸지 정하는 주소라, 미해석 상태의 arm 은 원장 없는 pending 을 만들어 fail-open 의 취지와 반대 결과가 된다. 원장 기록자는 **둘뿐이다** — verdict 가 나온 리뷰(완료) 와 G6 상한(3회)에 닿은 Stop 훅(포기). 정상 dispatch 는 원장을 건드리지 않는다. 어느 쪽도 문서를 쓴 턴이 아니므로, writer 가 자기 리뷰를 억제할 물리적 경로가 없다.
- **Law 1 (Clarity) — 핸드오프 게이트 (v0.23.0)** — brief 구조 게이트가 **2파일 fail-closed**로 확장. payload frontmatter `audit_file`(basename만, traversal 거부)로 audit을 해석하고, 못 열면 payload-only로 degrade하지 않고 red를 낸다. `user_sourced_items` 스키마 + 세 bijection(A: payload §5 ↔ audit §3 / B: body §2 ↔ frontmatter — statement 내용까지 / C: `evidence: S<N>` → §6)이 라벨과 내용이 어긋나는 drift를 기계로 잡는다.
- **P17 (User sovereignty) — 확정 권한 반환 (v0.23.0)** — 라운드마다 결정을 잠그던 producer를 제거하고 `status: confirmed`를 **종료 시 사용자 일괄 확인**으로만 발생시킨다. 확인은 새 의례가 아니라 기존 proceed 게이트에 흡수돼 상호작용이 1회로 유지된다(trivia ceremony 회피). 재제시에는 상한 2회가 있고 초과 시 전 항목이 `provisional`로 강등된다 — **덜 잠그는 쪽이 안전한 방향**(Unbounded-autonomy 가드).
- **Law 2 (brief, v0.24.0)** — 3중 분리: (a) 신규 에이전트 3개 전부 fail-closed `tools:`
  allowlist(쓰기·실행·위임 0개), (b) **입력 격리** — `brief-critic`·`brief-readback`은 payload
  전문을 inline으로만 받고 경로를 갖지 않으며, zero-tool probe 통과 시 `tools: []`로 도달 경로가
  물리적으로 없다(실패 시 verdict를 advisory로 내리고 D2 미충족을 사용자에게 보고), (c) **수정 후
  fresh critic 재리뷰 1회 필수** — writer가 자기 수정을 승인하는 경로를 차단한다(상한 2).
- **Law 3 (brief, v0.24.0)** — `brief-critic`의 `category` 6종과 readback gap 클래스 G1–G5가
  compounding substrate다. 리뷰가 놓친 결함류가 나오면 그 열거와 체크리스트를 편집하는 것이
  compounding 이벤트다(persona = 보안-민감 코드).

### Principles 흡수

- **P2 (Ambiguity Gate)** — 구조적 (필수 11 섹션) default, numerical 거부 (philosophy P2).
- **P5 (Spec as artifact)** — `docs/superpowers/specs/...spec.md` named, versioned (frontmatter `version: 1.0.0`).
- **P12 (Trivia escape)** — `/interview` first-step rule (typo / 주석-only / formatting / rename / <10 토큰 + 단일 action). 파일 수는 자격 기준이 아니다.
- **P14 (State preservation)** — `.claude/spec-distill/<session-id>/state.local.md` (실패/abort 시 보존).
- **P17 (User sovereignty)** — `needs_interview` user confirm gate, [5] Human Review, all kill switches.
- **P18 (Stagnation detection)** — issue `raised_count ≥ 3 unresolved` 시 P18 stagnation 명시 + forced [5] escalate.
- **P21 (Secret 기록 금지 / untrusted input)** — state.local.md token/key/credential placeholder 치환. **v0.23.0**: `audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(`../`·절대경로·서브경로 전부 거부).
- **P22 (Cost class)** — 모든 skill cost_class 선언 (conducting-interview: variable / reviewing-spec: medium).
- **worktree-safe state path (P5·P14)**: state 파일 위치를 `state_path.state_root()`로 단일화하여 worktree 호출 시에도 main repo `.claude/spec-distill/`에만 기록 — `ExitWorktree action: remove` 시 pending_review state silent loss 차단.

### Roadmap absorption (C-numbers)

- **C43** 4-path Socratic routing (factual auto-confirm / judgment→user / ambiguity→sub-agent / ontological→5-type).
- **C44** Dialectic Rhythm Guard (env: `DEVBREW_RHYTHM_GUARD_THRESHOLD`, default 3).
- **C10** `probe_budget.py` 백스톱 — Unbounded-autonomy 가드(effective_cap = base 12 + override, `DEVBREW_SPEC_DISTILL_PROBE_CAP`).
- **C11** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem, fan-out 1).
- **C51** 5-type ontology (ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT).

### Anti-pattern 회피

- **AP3 (Self-approval)** — writer/reviewer 물리적 분리 (frontmatter scoping).
- **AP2 (Polite stop)** — Phase 5 approve tail = proceed 게이트(AskUserQuestion) → handoff sequence (spec_path 검증 + 세션 cleanup). 게이트를 skip한 narrate-only 종료 금지. cross-compact 조기 진행(옵션 ① 노출 후 같은 턴 writing-plans 직진)도 게이트 P17 우회의 대칭 실패로 금지 (v0.11.0 AC19). interview→brainstorming Step B도 대칭 proceed 게이트(**4옵션**: ①/compact 후 brainstorming / ②바로 brainstorming / ③확정 목록 수정 / ④brief만 종료 — ③ 추가는 v0.23.0) — 같은 두 가드(AP2 + cross-compact AC19/AC21) 적용, 전용 handoff 스크립트를 호출하지 않음(brief는 막 검증됨, 하류/SessionEnd가 cleanup) (v0.13.0).
- **AP5 (Trivia ceremony)** — `/interview` first-step trivia escape (5 패턴).
- **AP9 (Subagent spray)** — agent 4종(spec-reviewer/steelman-builder/coverage-mapper/blind-spot-prober), coverage-mapper C11 rate-limit + blind-spot-prober fan-out 1.
- **P11 (Cross-Model Adversarial)** — sub-agent reviewer adversarial review + **`steelman-builder` 의심 게이트(v0.12.0)**: 의심 방향은 웹근거 기반 대안 steelman을 통과해야 brief에 실린다.
- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, **자동 dispatch 재시도 상한 3 (v0.25.0, 세션당·문서당)**, kill switch.
- **P14 (State Survives Compaction)** — state.local.md frontmatter 보존.
- **P3 — graceful degradation with loud logging**: `resolve_session_id` 검증 실패 시 None 반환 + stderr advisory, advisory hook output은 유지. cleanup 실패 시 silent skip (SessionEnd) 또는 advisory (check-born) — 사용자 attention 가용성에 따라 loud 정도 조정.
- **P14 — failure-time state preservation**: `write_state`가 stale-session 검출 시 *명시적* truncate (정상 케이스), 그러나 unreadable file은 보존 (failure preservation). TTL-GC도 self-session 보호 + grace window로 in-flight data 보호.

## External source absorption

- **devbrother2024 deep-interview** — 4-block Korean format (현재 이해 / 막힌 결정 / 추천 답안 / 질문).
- **gstack** — Structural baseline (11 필수 섹션) + concrete-next-action refusal pattern + ETHOS ("AI recommends, users decide").
- **OMC** — env-var configurable threshold (steelman antithesis는 plan-reviewer PR로 defer, v0.2.0+ 회귀 도입).
- **superpowers** — 산출물 위치(`docs/superpowers/specs/`) + plan-document-reviewer 출력 형식 (Status / Issues / Recommendations) + brainstorming drop-in 대체.
- **Ouroboros** — inner/outer loop spirit (graph back-edges), spec lifecycle as named/versioned. (단 numerical ambiguity gate 거부, philosophy P2 비추천.)

## Hooks Installed

| Event | Script | 책임 | 왜 skill이 아닌가 |
|---|---|---|---|
| PostToolUse | `hooks/spec-write-validator.py` | `docs/superpowers/specs/` 아래 **모든 `.md`** (sub-folder hierarchy 포함) write 시 (content-aware: frontmatter `locked_decisions` 유무로 spec/design mode) mechanical Layer 1 검증 + `pending_review:` ledger 기록 (v0.3.0). **v0.25.0: arm 직전 `should_arm`(세션 원장 ∧ git 추적 여부) 게이트 — 이미 리뷰됐거나 커밋된 문서는 arm skip(Layer 1 은 불변). skip 사유를 세 가지로 구분해 표시한다.** | spec writer가 *자기 작업을 자기가 검증*하는 회색지대를 file-system level에서 가로채는 것이 Law 2의 가장 강력한 구현. skill은 LLM이 invoke해야 동작하므로 trigger 결정론이 부족함. |
| Stop | `hooks/review-dispatch.py` | `pending_review:` block 있으면 systemMessage 주입으로 reviewer dispatch 강제 (v0.3.0) **v0.25.0: `dispatch_attempts` 증가 + G6 상한(3회) 도달 시에만 원장 기록 — 정상 dispatch 는 원장을 건드리지 않는다.** | turn boundary는 LLM의 메시지 형식과 무관한 결정론적 지점 — skill로는 hit 불가. |
| UserPromptSubmit | `hooks/pending-review-reminder.py` | pending_review가 살아있고 TTL 만료 시 mandate 재emit (L4b redundancy). TTL(30s) 가드로 spam 방지. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder`. **v0.25.0: 원장을 기록하지 않는다 — 재-nag 는 리뷰의 완료가 아니다.** | Stop hook single-shot mandate가 next-turn에서 silent drop될 경우 매 user prompt에 mandate 재emit하는 redundancy layer 필요 — turn boundary 이벤트라 skill로 처리 불가. |
| SessionEnd | `hooks/session-end-cleanup.py` | deterministic per-session `.claude/spec-distill/<sid>/` cleanup (v0.6.0). polite-stop이나 approve 누락 시에도 cleanup 보장 (4-layer defense의 layer 2). Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd`. | Claude lifecycle 이벤트는 hook이 catch해야 함 — skill은 사용자/LLM이 invoke해야 동작. |

**Output schema (v0.5.0+):** 모든 hook이 *dual-target output* 패턴 — Claude-target field (`hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit, `decision:"block" + reason` for Stop) + `systemMessage` (짧은 흔적, ≤120자, `[spec-distill]` prefix). Claude는 context로 dispatch 메시지를 받고, user는 transcript에서 hook 발화 흔적을 확인 가능. 이전 (`v0.4.0` 이하) 의 `systemMessage`-only 출력은 user transcript에는 보였으나 Claude LLM context로 inject되지 않는 silent failure였음 — `v0.5.0`에서 fix. Reference 패턴: `plugins/quality-gates/hooks/stop-hook.py:845-849`.

## Kill switches

### 먼저 — 무엇이 리뷰의 범위를 정하는가

아래 env var 들은 **전부 세션 스코프이고 전부 재시작이 필요합니다.** "이번 리뷰 한 번만"
같은 좁은 범위에 이것들을 쓰는 것은 압정에 망치입니다. 다만 상위 두 행은 **스위치가
아니라 arm-once(v0.25.0) 설계에서 따라 나오는 성질**이므로, "끄는 방법" 이 아니라
"범위가 어떻게 정해지는가" 로 읽으십시오.

| 범위 | 그 범위를 만드는 것 | 재시작 |
|---|---|---|
| **이번 dispatch 1회** | mandate 의 **수명 자체가 1회**다 — `rewrite_state()` 가 emit 전에 `pending_review` 를 소진하므로 이 강제는 이번 턴을 넘기지 않는다 | 불필요 |
| **그 문서의 재발동** | 재발동은 그 문서를 **다시 편집**할 때 일어난다. `should_arm()` 이 git-unknown 을 요구하므로 **커밋된 문서는 원칙적으로 다시 arm 되지 않는다** — 단 `is_born()` 은 git 판정 실패(`ls-files` timeout·rc 128 등)를 전부 arm 쪽으로 fail-open 하므로 이는 보장이 아니다 | 불필요 |
| 모든 문서, 자동 리뷰만 | `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (Layer 1 구조 검증은 유지) | 필요 |
| 훅 하나 | `DEVBREW_SKIP_HOOKS=spec-distill:Stop` | 필요 |
| 플러그인 전체 | `DEVBREW_DISABLE_SPEC_DISTILL=1` | 필요 |

**커밋은 이미 걸린 dispatch 를 취소하지 않습니다.** Stop 훅은 pending 을 찾은 뒤
`armed_paths` 만 조회하고 git 추적 여부를 재검사하지 않으므로, pending 이 생긴 뒤 같은
턴에 커밋해도 그 dispatch 는 그대로 실행됩니다. 커밋이 영향을 주는 것은 **앞으로의
arm** 뿐이고, 그마저 위 표의 fail-open 단서가 붙습니다.

원장(`armed_paths`)은 **세션 스코프**입니다. 리뷰를 마쳐도 문서를 커밋하지 않으면 다음
세션에서 한 번 더 arm 됩니다 — 세션을 넘겨 억제하는 통상적 수단은 커밋이며, approve 시점
`check-born` advisory 가 그것을 촉구합니다. 다만 `check-born` 은 `is_born()` 위에 서 있어
**판정 실패와 untracked 를 구별하지 않습니다** — git 호출이 실패하면 커밋된 문서를
"아직 git 에 없다" 로 보고합니다. 재발동은 세션당·문서당 3회(G6)가 상한입니다.

**Stop 훅의 mandate 는 수명 한 문장만 말하고 재발동 조건은 말하지 않습니다.** 재발동은
(원장 ∧ git ∧ 상한) 세 입력의 함수인데 셋 다 emit 시점에 확정되지 않아, 어떤 단정도
언젠가 거짓이 되기 때문입니다(실제로 두 판본이 그렇게 걸렸습니다 — CHANGELOG 0.25.2
리뷰 라운드 참조). 이 표가 그 조건을 설명하는 유일한 자리입니다.

### 스위치 목록

- `DEVBREW_DISABLE_SPEC_DISTILL=1` — plugin 전체 abort, state 보존.
- `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` (v0.20.0, v0.24.0 확대) — codex 병렬 co-review만 skip. Claude 리뷰는 정상 동작, combined = Claude verdict + loud degrade advisory. 전역 `DEVBREW_DISABLE_SPEC_DISTILL`과 독립. **적용 범위는 두 경로 전부**: (a) design-doc 리뷰(`reviewing-spec`), (b) brief 리뷰(`reviewing-brief`)의 **호출 지점 3곳** — 1-c 방향성 축 · 2-b 충실도 축 · 2-c 충실도 재실행. 게이트는 **호출자 책임**이다 — `detect_codex.sh`가 이 스위치를 `codex_available: false`로 옮기고 세 지점이 같은 `$codex_avail`로 묶이며, 러너(`run_brief_codex_reviewer.sh`)는 이 변수를 보지 않는다. 한 지점이라도 게이트 밖이면 opt-out이 무시된 채 지출이 나가고 `affected_axis: all` degradation record가 거짓이 된다.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` — UserPromptSubmit hook만 skip.
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.3.0) — PostToolUse Layer 1 (structural check) 정상 동작, Layer 2 (`pending_review:` ledger 기록) skip. 비상시 reviewer dispatch cost 회피용.
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0, v0.8.0 확대, v0.8.1 sub-folder 명시) — `design`으로 분류된 모든 `.md` 게이트 해제: `-design.md` suffix 파일 + content-aware 판별로 `design`이 된 임의 `.md` (sub-folder 포함). `locked_decisions`로 `spec` 분류된 파일은 영향 없음. brainstorming 산출물 review를 일시 정지하고 싶을 때.
- `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>` (v0.3.0) — Stop hook redispatch TTL guard (default 30초). spec self-reference cycle 방지용. plan phase에서 default 값 재검토.
- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` (alias: `spec-distill:validator`) — PostToolUse hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` (alias: `spec-distill:review-dispatch`) — Stop hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` (v0.6.0) — SessionEnd cleanup hook만 skip. TTL-GC가 backup으로 작동.
- `DEVBREW_SPEC_DISTILL_TTL_HOURS=<int>` (v0.6.0) — TTL-GC orphan 정리 임계값 (default 24h). 짧게 설정 시 자주 정리, in-flight 작업 risk 증가.
- `DEVBREW_SPEC_DISTILL_GC_VERBOSE=1` (v0.6.0) — TTL-GC가 cleanup 발생 시 stdout summary 출력. CI/디버깅용.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` (v0.9.0) — `handoff_incomplete` 카테고리만 우회. 다른 검사 (`missing_section` 등)는 정상 동작. loud warning stderr 출력. /compact 이후 정보 손실 risk 명시.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` (v0.12.0) — interview 웹 리서치 비활성화. landscape를 loud log와 함께 생략, crash 없음 (graceful degradation, AC8).
- `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` (v0.24.0) — brief 리뷰 파이프라인 전체 skip.
  `component: pipeline` degradation record + loud advisory를 남기고 Step B로 직행한다(조용한
  생략이 아니다). 충실도·방향성·냉독 전부 미검증 상태가 게이트 질문에 표시된다.
- 자동 dispatch 가 G6 상한(3회)에 닿으면 그 문서는 이 세션에서 더 이상 자동으로 리뷰되지
  않는다. 리뷰가 필요하면 `reviewing-spec` skill 을 직접 호출한다. 초안을 오래 다듬는 동안
  dispatch 를 0 으로 두고 싶으면 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`.

## Prerequisites

- **Claude Code built-in `general-purpose` agent** — 항상 사용 가능 (별도 설치 불필요). `conducting-interview` skill의 C43 ambiguity path가 dispatch.
- **`jq`** (CLI, recommended) — hook 스크립트가 stdin JSON payload 파싱과 `{"systemMessage": "..."}` JSON 출력에 사용. 없으면 regex fallback + loud warning (devbrew "loud-logging graceful degradation").
- **superpowers** (외부, optional) — 있으면 brief를 `brainstorming` 해답공간으로 넘기고 `writing-plans`로 이어집니다. 없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
- **codex CLI** (외부, optional) — 있으면 Phase 3 design-doc 리뷰에 병렬 독립 co-reviewer로 참여(model diversity). 없거나 auth 미설정이면 Claude-only로 graceful degrade + loud advisory(crash 없음). kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`.

## License

(devbrew root 정책 따름.)
