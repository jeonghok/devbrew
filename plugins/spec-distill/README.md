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

## Flow (v0.41.0)

```
/request-framing ─→ [Phase 0] framing-requests — 확산 후 압축
                                       · 확산 — 원문 보존 → 레포 읽기 → 질문 라운드 (상한 없음)
                                       · 압축 — check_seed.py 게이트 다섯 (Law 1)
                                       · 검증 — 억제 축(seed-critic 격리 + codex, model diversity)
                                                · 냉독 축(seed-readback)
                                       ▼ [확정 — proceed 게이트] ①/compact 후 /interview · ②바로 /interview · ③수정 필요 · ④멈춤
                                   interview-seed → docs/superpowers/interview/   ← 문서가 아니라 다음 세션 첫 턴에 붙여넣는 메시지
                                       ▼ 새 세션 첫 턴 = `/interview <seed 파일 전문>` (frontmatter 포함, 한 턴)
/interview ─→ [0] Trivia escape ─→ [1] Interview (문제공간 stage)
                                       · 4-block Socratic + 4-path (web=path(a))
                                       · R1 Problem Reframe / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ
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
                                       ▼ brainstorming user-review 정지 → 턴 경계
                                       ▼ [Stop: 발견 → 구조 검증 → review-dispatch]  (기존 hook)
                                   [3] reviewing-spec → spec-reviewer (Law 2, design-mode only)
                                       ├─ approved → [5] proceed 게이트 → auto re-review, max 5 → writing-plans
                                       └─ needs_revise → brainstorming author 회귀 → 재검증
```

**v0.12.0**: drafting-spec 제거 + reviewing-spec design-mode 전용. interview는 brief까지 단독 완결.

**v0.13.0**: interview→brainstorming Step B를 `/compact` proceed 게이트(reviewing-spec Phase 5 대칭)로 재작성. — **v0.31.0에서 그 "대칭"(독립 저술 두 벌)이 하나의 공유 계약 `references/proceed-gate.md`로 합쳐졌다.**

**v0.14.0–v0.18.0**: 리뷰 재발동을 막는 방어층 3종이 순차로 쌓였다 — 문서별 억제 집합, approve 시 기록 순서 교정, 문서-키 진행중 락. 셋 다 훅이 자기가 만든 재발동을 자기가 막는 내부 하니스였고 **v0.25.0 에서 원인과 함께 삭제**됐다(상세는 CHANGELOG).

**v0.23.0**: interview brief를 핸드오프 아티팩트로 재설계. 라운드마다 결정을 잠그던 producer를 제거하고(`user_statements`에 판정 없이 기록), 확정 권한을 **종료 시 사용자 일괄 확인**으로 되돌렸다. brief는 payload(8섹션 역피라미드) + audit(텔레메트리) **두 파일**로 갈라지고 `audit_file`로 묶이며, frontmatter `user_sourced_items` 계약과 세 bijection이 body↔frontmatter·payload↔audit drift를 잡는다.

**v0.22.0**: [1] Interview 종료 driver를 고정 라운드 카운터에서 커버리지 원장(고정 floor 5 + 주제-도출 차원, status ∈ {open, in-progress, closed})으로 재구성 — 집요함·깊이·차원이 주제에 적응한다. tunneling 검출 에이전트는 `coverage-mapper`(주제-도출 차원 advisory 제안자)로 재명명·재목적화되었고, `blind-spot-prober`(적대적 premortem, fan-out 1)가 blind-spot floor 차원 구현으로 신설되었다.

**v0.24.0**: 구조 게이트를 통과한 interview brief에 **Law 2 분리 리뷰**(`reviewing-brief`)를 얹었다. 방향성(`brief-direction-reviewer` + codex #1, 보고만) → 충실도(`brief-critic` 격리 + codex #2, fail-closed 합집합) → 냉독(`brief-readback`, advisory) 3단계이고, `check_verbatim_coverage.py`가 진입 첫 액션으로 §6 원문 완전성을 state 원장과 대조한다. 리뷰어 셋은 전부 fail-closed `tools:` allowlist이며 `brief-critic`·`brief-readback`은 payload를 경로가 아니라 전문 inline으로 받는다. 모든 degradation은 `brief_review_degradations` 원장 + Step B 게이트 질문 텍스트로 표면화된다 — 돌지 못한 검사가 통과한 검사로 집계되지 않는다.

**v0.25.0**: design 문서를 편집할 때마다 리뷰가 재발동하던 원인 자체를 없앴다 — `scripts/arm_ledger.py`가 문서 생애 단 한 번만 arm하는 `arm-once` 게이트를 구현하고(세션 원장 `armed_paths` ∧ git 추적 여부로 판정), v0.14.0–v0.18.0에 쌓였던 방어층 3종(억제 집합·순서 교정·진행중 락)이 근거를 잃어 함께 삭제됐다.

**v0.41.0**: 파이프라인 맨 앞에 **Phase 0** `/request-framing`(skill: `framing-requests`)을 신설. 사용자의 의도·steering·방향·goal을 확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴에 `/interview` 의 인자로 그대로 붙여넣는 메시지 `interview-seed`로 만든다 — 산출물은 문서가 아니라 메시지다. 호출 모양의 정본은 `framing-requests` 의 「호출 모양」 절이다. 검증은 억제 축(`seed-critic` 격리 critic + codex, 셋째 담당)과 냉독 축(`seed-readback`)으로 나뉘고 판정은 사용자가 한다. `references/compression.md`(압축 규약)·`references/trivia-escape.md`(5패턴 정본, `/request-framing`이 가리킨다)를 채택하고, 확정 단계는 공유 계약 `references/proceed-gate.md`의 재결정 규약(P23)을 따른다.

**v0.41.0**: interview의 R1을 `Reframe (메타 프롬프트)`에서 **`Problem Reframe`**으로 재정의 — 「받은 요청 재구성」은 `request-framing`이 맡고, R1은 **seed가 가리키는 작업 뒤의 진짜 문제**를 재구성한다(R&R 이동, 명칭 변경이 아니다). `conducting-interview`가 `type: interview-seed` 입력을 받는 규약을 얻었다 — seed 본문은 §6 `S1`이 되고, 인터뷰 중 새 발화가 seed의 확정을 뒤집으면 새 발화가 이기며 그 재결정이 §5에 *원래/재결정/근거*로 남는다(P23). `commands/interview.md`의 trivia 5패턴 인라인 사본이 `references/trivia-escape.md` 포인터로 바뀌었고(v0.41.0 시점엔 아직 인라인이었다), seed가 아닌 입력에는 조언 한 줄만 내고 차단하지 않는다(호환 유지).

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws

- **Law 1 (Clarity Before Code)** — Plugin의 raison d'être. 인터뷰 → brief → design doc → reviewer → human gate. "spec 이전엔 코딩 안 한다" 강제. (`locked_decisions`는 design doc의 표식이 아니라 그 반대다 — `scripts/resolve_mode.py`가 frontmatter에 이 키를 가진 파일을 **spec** 모드로 분류하고, `-design.md`를 포함한 나머지는 design 모드다.)
- **Law 1 (Clarity) — 문제공간 게이트 (v0.12.0)** — interview의 5 통과 의례(R1–R5)가 `check_brief.py`로 기계 검증되는 구조 게이트. 약한 방향(무인용 landscape·un-challenged 의심·빈 시행착오)은 brief 종료를 차단.
- **Law 2 (Writer/Reviewer 분리)** — `tools:` allowlist frontmatter로 spec-reviewer(`Read, Grep, Glob, WebSearch, WebFetch`) + coverage-mapper(`Read, Grep, Glob, WebSearch, WebFetch`) + blind-spot-prober(`Read, Grep, Glob, WebSearch, WebFetch`) agent의 *물리적* 분리. 프롬프트가 아닌 frontmatter scoping이며, **allowlist라 열거되지 않은 쓰기·실행·위임 도구가 자동 차단**된다(denylist는 시간에 대해 fail-open이라 v0.21.0에서 폐기).
- **Law 2 강화 (v0.3.0, v0.36.0 재배선)** — Writer/Reviewer 분리를 turn-boundary 결정론으로 끌어올림. Stop hook이 턴 경계에서 스코프 문서의 dirty 집합을 **git 에서 직접 발견**해 구조 게이트를 차단(`decision:"block"`)하고, 통과하면 *다음 turn 첫 액션*으로 reviewer dispatch를 강제. 연료가 git 관측이라 **어떤 도구로 썼든**(Write/Edit/Bash/외부 편집기) 게이트를 우회할 수 없다 — 도구 이름을 열거하던 이전 설계의 구멍이 이것이다.
- **Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability**: spec-reviewer agent의 writer/reviewer 물리 분리가 의미를 가지려면 reviewer dispatch가 Claude context에 *실제로* 도달해야 한다. v0.5.0의 dual-target output fix가 이 baseline을 보장. dispatch가 silent하게 lost되면 reviewer persona 분리 자체가 무의미.
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.
- **Law 3 (Every Cycle Must Leave the System Smarter)**: v0.5.0 PR이 hook 코드 fix + `tests/test_hook_output_schema.py` 회귀 방지 test + CHANGELOG 명시 + design.md (아카이브됨: `git show pre-slim-archive-2026-07-09:docs/superpowers/specs/2026-05-17-spec-distill-hook-context-injection-design.md`) — 4-layer compounding 흔적. 같은 클래스의 silent-output mistake가 미래에 들어오면 CI에서 즉시 잡힘.
- **Law 3 (Compounding) — model diversity (v0.20.0)** — codex 병렬 co-reviewer를 design-doc 리뷰에 추가. codex가 Claude persona가 반복해 놓치는 결함류(fail-open)를 잡으면 → `spec-reviewer.md` 체크리스트 편집(persona = 보안-민감 코드)이 compounding 이벤트. quality-gates codex 패턴의 실증 이력을 상속.
- **AP2 approval-gate 구분 (v0.11.0)** — handoff 다음-단계 추천을 hook(텍스트 주입만 가능)이 아니라 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 전달. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 polite-stop 봉쇄 장치 (철학 AP2 앵커). `arm_ledger.py check-born`(v0.25.0)은 approve 시점에 문서가 git에 커밋됐는지만 확인한다 — 미커밋이면 advisory만 내고 아무 것도 기록하지 않는다(arm 판정은 리뷰 자신이 이미 마쳤으므로 기록할 상태가 남지 않는다). 세션 dir 삭제는 SessionEnd/TTL-GC로 이관.
- **Law 1 fail-safe + Law 2 (v0.25.0)** — arm 판정(`scripts/arm_ledger.py`)의 어떤 실패(원장 read 불능, git 불능·리포 밖, 모듈 부재)도 **arm 쪽으로 fail-open** 한다(over-review > under-review). 예외는 `session_id` 미해석 하나 — 그것은 판정 신호가 아니라 상태를 어디에 쓸지 정하는 주소라, 미해석 상태의 arm 은 원장 없는 pending 을 만들어 fail-open 의 취지와 반대 결과가 된다. **`armed_paths`("더 이상 dispatch 안 함") 기록자는 둘뿐이다** — verdict 가 나온 리뷰(완료) 와 G6 상한(3회)에 닿은 Stop 훅(포기). 어느 쪽도 문서를 쓴 턴이 아니므로, writer 가 자기 리뷰를 **영구히** 억제할 물리적 경로가 없다.
  **v0.36.0 에서 좁아진 것**: "정상 dispatch 는 원장을 건드리지 않는다"는 더 이상 상태 파일 전체에 대해 참이 아니다. 정상 dispatch 는 `armed_paths` 는 그대로 두지만 `inflight_paths` 와 `dispatch_attempts` 를 **쓴다**(`hooks/review-dispatch.py` 의 `rewrite_state`). 그래서 Law 2 의 보증은 «영구 억제 불가»로 읽어야 하고, «턴이 상태를 안 건드린다»로 읽으면 안 된다.
  **그 대가로 생긴 창**: 문서를 쓴 그 턴의 Stop 훅이 남기는 in-flight 표시가 그 문서를 발견에서 `INFLIGHT_TTL_SEC`(900초) 동안 빼낸다. 발견 결과가 곧 **구조 검증 후보 집합**이므로 그 창 동안 멈추는 것은 재-dispatch 만이 아니다 — 그 문서는 **Layer 1 구조 검증도 받지 않는다(어떤 도구로 쓰든)**. 리뷰가 verdict 없이 끝나면 둘 다 그 시간만큼(최대 900초) 늦어진다. 창을 여는 조건은 좁다: 모델이 dispatch mandate 를 무시해야 하고, 그 문서는 이미 리뷰 큐에 들어가 있다. 구현은 설계 §4.1·A12(«발견 결과에서 제외»)를 그대로 따른 것이라 이것은 구현 결함이 아니라 **명세 쪽 미결**이다 — 좁히려면 발견 제외와 검증 제외를 서로 다른 술어로 가르는 설계 변경이 필요하고(armed 게이트를 그렇게 가른 전례가 v0.36.0 에 있다), 그 판단은 아직 하지 않았다.
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
- **P23 (Decisions Stay Refutable)** — `framing-requests`의 「재결정 규약」 절(정본은 `references/proceed-gate.md`)이 확산에서 확정된 것을 압축 단계가 뒤집을 때 임의 변경이 아니라 근거 제시 + 사용자 동의 + audit *원래/재결정/근거* 세 칸 기록을 강제한다. `conducting-interview`도 하류에서 같은 원칙을 잇는다(v0.41.0) — 인터뷰 중 새 발화가 seed의 확정을 뒤집으면 조용히 덮어쓰지 않고 새 발화가 이기며, §5 기각에 같은 *원래/재결정/근거* 형태로 남는다.
- **worktree-safe state path (P5·P14)**: state 파일 위치를 `state_path.state_root()`로 단일화하여 worktree 호출 시에도 main repo `.claude/spec-distill/`에만 기록 — `ExitWorktree action: remove` 시 원장 state silent loss 차단.

### Roadmap absorption (C-numbers)

- **C43** 4-path Socratic routing (factual auto-confirm / judgment→user / ambiguity→sub-agent / ontological→5-type).
- **C44** Dialectic Rhythm Guard (env: `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD`, default 3).
- **C1** 사용자-발화 floor 탈출구 — Unbounded-autonomy 가드(사용자가 언제든 종료를 요청하면 미충족 floor를 사용자-승인 박제로 닫고 payload §3 Open Questions로 이월).
- **C11** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem, fan-out 1).
- **C51** 5-type ontology (ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT).

### Anti-pattern 회피

- **AP3 (Self-approval)** — writer/reviewer 물리적 분리 (frontmatter scoping).
- **AP2 (Polite stop)** — **정본은 `references/proceed-gate.md`** (v0.31.0). 두 proceed 게이트(reviewing-spec Phase 5 · conducting-interview 종료 Step B)가 그 파일의 골격·두 가드·예외 경로를 공유하며, 각 skill 은 자기 어휘(옵션 라벨 · verbatim `/compact` 템플릿 · 고유 스텝)만 인라인으로 갖는다. 아래는 그 계약의 **요약**이지 별개 저술이 아니다 — 계약이 바뀌면 정본을 고치고 여기를 따라 고친다. Phase 5 approve tail = proceed 게이트(AskUserQuestion) → handoff sequence (spec_path 검증 + 세션 cleanup). 게이트를 skip한 narrate-only 종료 금지. cross-compact 조기 진행(옵션 ① 노출 후 같은 턴 writing-plans 직진)도 게이트 P17 우회의 대칭 실패로 금지 (v0.11.0 AC19). interview→brainstorming Step B의 **4옵션**: ①/compact 후 brainstorming / ②바로 brainstorming / ③확정 목록 수정 / ④brief만 종료 (③ 추가는 v0.23.0) — 전용 handoff 스크립트를 호출하지 않음(brief는 막 검증됨, 하류/SessionEnd가 cleanup) (v0.13.0).
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
| Stop | `hooks/review-dispatch.py` | 셋을 이 순서로 한다. **① 발견** — `git status` 하나로 `docs/superpowers/specs/` 아래 dirty·untracked 문서를 찾는다(도구 무관). **② 구조 검증(Layer 1)** — content-aware mode(frontmatter `locked_decisions` 유무)로 검사하고, 실패가 있으면 그 사유만 `decision:"block"` 으로 내고 그 턴에 dispatch 는 없다. **③ dispatch** — 같은 후보에서 하나를 골라 다음 턴 첫 액션으로 `reviewing-spec` 을 강제하고, `dispatch_attempts` 증가 + G6 상한(3회) 도달 시에만 원장에 기록한다. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` — 이 하나가 셋을 **모두** 지배한다. | turn boundary는 LLM의 메시지 형식과 무관한 결정론적 지점 — skill로는 hit 불가. 발견을 git 에 기대는 것이 핵심이다: 도구 이름(`Write|Edit|MultiEdit`)을 matcher 로 열거하던 이전 설계는 Bash 로 쓴 문서를 통째로 놓쳤다. |
| SessionEnd | `hooks/session-end-cleanup.py` | deterministic per-session `.claude/spec-distill/<sid>/` cleanup (v0.6.0). polite-stop이나 approve 누락 시에도 cleanup 보장 (4-layer defense의 layer 2). Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` / `:session-end-cleanup`. | Claude lifecycle 이벤트는 hook이 catch해야 함 — skill은 사용자/LLM이 invoke해야 동작. |

**Output schema (v0.5.0+):** 모든 hook이 *dual-target output* 패턴 — Claude-target field (Stop 은 `decision:"block" + reason`) + `systemMessage` (짧은 흔적, ≤120자, `[spec-distill]` prefix). Claude는 context로 dispatch 메시지를 받고, user는 transcript에서 hook 발화 흔적을 확인 가능. 이전 (`v0.4.0` 이하) 의 `systemMessage`-only 출력은 user transcript에는 보였으나 Claude LLM context로 inject되지 않는 silent failure였음 — `v0.5.0`에서 fix. Reference 패턴: `plugins/quality-gates/hooks/stop-hook.py:845-849`.

### 발견의 한계

- 발견은 **훅이 도는 cwd 의 리포**만 본다. 다른 체크아웃/워크트리의 문서는 그 `git status`
  에 나오지 않으므로 검증도 dispatch 도 되지 않는다 — 그 워크트리에서 세션을 열면 커버된다.
- git 을 쓸 수 없거나 리포가 아니면 검증·dispatch 가 일어나지 않고 **세션당 1회** loud
  advisory 가 나간다. 후보 0 과 구별된다.
- 턴당 구조 검증은 5개까지다(`CANDIDATE_CAP`). 커서 회전이 기아를 막지만, dirty 문서가
  5개를 넘으면 dispatch 대상이 **그 턴에 검증되지 않은 문서**일 수 있다 — 좁고 다음 회전이
  잡는다. `v0.36.0` CHANGELOG 의 해당 BREAKING 항목 참조.

### 행동 케이스 테스트

`tests/test_write_path_behavior.sh` 는 실제 `claude -p` 턴을 돌려 «Bash 로 쓴 문서가 정말
게이트를 지나는가»를 잰다 — 정적 락이 볼 수 없는 유일한 축이다. API 크레딧을 쓰므로
**기본은 skip** 이다.

```bash
DEVBREW_BEHAVIOR_TESTS=1 bash plugins/spec-distill/tests/test_write_path_behavior.sh
```

스크래치 위치는 `DEVBREW_TEST_TMPDIR` 로 바꾼다. **경로에 `.claude` 가 들어가면 안 된다** —
Claude Code 가 그 아래 모든 파일을 sensitive file 로 보고 Bash 쓰기를 거부해서 측정이
성립하지 않는다(테스트가 그 경우 fail-closed 로 거부한다).

## Kill switches

### 먼저 — 무엇이 리뷰의 범위를 정하는가

아래 env var 들은 **전부 세션 스코프이고 전부 재시작이 필요합니다.** "이번 리뷰 한 번만"
같은 좁은 범위에 이것들을 쓰는 것은 압정에 망치입니다. 다만 상위 두 행은 **스위치가
아니라 arm-once(v0.25.0) 설계에서 따라 나오는 성질**이므로, "끄는 방법" 이 아니라
"범위가 어떻게 정해지는가" 로 읽으십시오.

| 범위 | 그 범위를 만드는 것 | 재시작 |
|---|---|---|
| **이번 dispatch 1회** | mandate 의 **수명 자체가 1회**다 — `rewrite_state()` 가 emit **전에** 그 문서를 `inflight_paths` 로 찍으므로 다음 Stop 의 발견 결과에서 빠진다 | 불필요 |
| **그 문서의 재발동** | 발견은 **매 턴** 돈다 — dirty 한 동안 그 문서는 계속 후보다. 재발동을 막는 것은 편집 여부가 아니라 세 표시다: `inflight_paths`(리뷰 진행 중, TTL 15분 — **이 표시만 구조 검증까지 함께 멈춘다**, 위 «그 대가로 생긴 창» 참조) · `armed_paths`(verdict 완료 또는 G6 상한) · git 추적 여부(`c.born`). **커밋하면 그 문서는 다음 턴부터 dispatch 대상에서 빠진다**(구조 검증은 계속 받는다 — 두 게이트는 서로 다른 술어를 읽는다) — 단 `is_born()` 은 git 판정 실패(`ls-files` timeout·rc 128 등)를 전부 arm 쪽으로 fail-open 하므로 이는 보장이 아니다 | 불필요 |
| 훅 하나 | `DEVBREW_SKIP_HOOKS=spec-distill:Stop` | 필요 |
| 플러그인 전체 | `DEVBREW_SPEC_DISTILL_DISABLE=1` | 필요 |

**커밋은 다음 턴부터 그 문서를 dispatch 대상에서 뺍니다.** 발견이 매 턴 git 을 다시
읽고 선택이 `born` 을 그 자리에서 검사하므로, 연료가 상태 파일의 블록이던 시절과 달리
"이미 걸린 dispatch" 라는 것이 남지 않습니다. 커밋 뒤에 **다시 편집**하면 그 문서는
여전히 dirty 라 발견되고 **구조 검증(Layer 1)은 계속 받습니다** — 빠지는 것은 리뷰
dispatch 뿐입니다. 완전히 clean 한 문서는 발견 자체가 되지 않아 둘 다 받지 않습니다.
다만 커밋 판정에는 위 표의 fail-open 단서가 그대로 붙습니다 — git 호출이 실패하면
커밋된 문서도 dispatch 대상으로 남습니다.

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

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — plugin 전체 abort, state 보존.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` (v0.20.0, v0.24.0 확대) — codex 병렬 co-review만 skip. Claude 리뷰는 정상 동작, combined = Claude verdict + loud degrade advisory. 전역 `DEVBREW_SPEC_DISTILL_DISABLE`과 독립. **적용 범위는 두 경로 전부**: (a) design-doc 리뷰(`reviewing-spec`), (b) brief 리뷰(`reviewing-brief`)의 **호출 지점 3곳** — 1-c 방향성 축 · 2-b 충실도 축 · 2-c 충실도 재실행. 게이트는 **호출자 책임**이다 — `detect_codex.sh`가 이 스위치를 `codex_available: false`로 옮기고 세 지점이 같은 `$codex_avail`로 묶이며, 러너(`run_brief_codex_reviewer.sh`)는 이 변수를 보지 않는다. 한 지점이라도 게이트 밖이면 opt-out이 무시된 채 지출이 나가고 `affected_axis: all` degradation record가 거짓이 된다.
- `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0, v0.8.0 확대, v0.8.1 sub-folder 명시) — `design`으로 분류된 모든 `.md` 게이트 해제: `-design.md` suffix 파일 + content-aware 판별로 `design`이 된 임의 `.md` (sub-folder 포함). `locked_decisions`로 `spec` 분류된 파일은 영향 없음. brainstorming 산출물 review를 일시 정지하고 싶을 때.
- `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>` (v0.3.0) — Stop hook redispatch TTL guard (default 30초). spec self-reference cycle 방지용. plan phase에서 default 값 재검토.
- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` (alias: `spec-distill:review-dispatch`) — Stop hook만 skip.
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` (alias: `spec-distill:session-end-cleanup`) — SessionEnd cleanup hook만 skip. TTL-GC가 backup으로 작동.
- `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` — TTL-GC 스크립트(`scripts/spec-distill-gc.py`)만 skip. 훅이 아니지만 지목할 이름을 갖는다 — 그전에는 이 스크립트가 `DEVBREW_SKIP_HOOKS`를 **아예 읽지 않아서**, 그 변수로 껐다고 믿어도 GC는 계속 돌았다.
- `DEVBREW_SPEC_DISTILL_TTL_HOURS=<int>` (v0.6.0) — TTL-GC orphan 정리 임계값 (default 24h). 짧게 설정 시 자주 정리, in-flight 작업 risk 증가.
- `DEVBREW_SPEC_DISTILL_GC_VERBOSE=1` (v0.6.0) — TTL-GC가 cleanup 발생 시 stdout summary 출력. CI/디버깅용.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` (v0.9.0) — `handoff_incomplete` 카테고리만 우회. 다른 검사 (`missing_section` 등)는 정상 동작. loud warning stderr 출력. /compact 이후 정보 손실 risk 명시.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` (v0.12.0, AC21로 범위 확대) — 이 kill switch 하나가
  **세 소비자**의 웹 접근을 끈다: interview 웹 리서치(landscape, v0.12.0), codex design-doc
  co-reviewer(`run_spec_codex_reviewer.sh`), codex brief co-reviewer(`run_brief_codex_reviewer.sh`,
  둘 다 AC21). 어느 쪽이든 loud log와 함께 생략, crash 없음 (graceful degradation, AC8).
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` (v0.24.0) — brief 리뷰 파이프라인 전체 skip.
  `component: pipeline` degradation record + loud advisory를 남기고 Step B로 직행한다(조용한
  생략이 아니다). 충실도·방향성·냉독 전부 미검증 상태가 게이트 질문에 표시된다.
- 자동 dispatch 가 G6 상한(3회)에 닿으면 그 문서는 이 세션에서 더 이상 자동으로 리뷰되지
  않는다. 리뷰가 필요하면 `reviewing-spec` skill 을 직접 호출한다. 초안을 오래 다듬는 동안
  dispatch 를 0 으로 두고 싶으면 `DEVBREW_SKIP_HOOKS=spec-distill:Stop` 을 쓴다 — 구조
  검증도 함께 꺼진다. 검증만 남기고 dispatch 만 끄는 스위치는 없다.

### 은퇴한 스위치 (v0.36.0)

`PostToolUse` validator 와 `UserPromptSubmit` reminder 가 삭제되면서 다음 셋이 아무것도
끄지 않게 됐다. Stop 훅이 세션당 1회 advisory 로 알린다.

- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` / `:validator` — 구조 검증은 이제 Stop
  훅 안에 있다. 끄려면 `spec-distill:Stop`.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder` — 재-nag 층 자체가 없다.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` — 이 스위치가 주던 것은 **구조 검증은 유지한
  채 자동 리뷰 dispatch 만 중단**이었다. 그 능력에는 **대체 수단이 없다** — 위
  `spec-distill:Stop` 은 둘을 함께 끄므로 같은 것이 아니다. 되살리는 것은 새 기능
  작업이다.

## Prerequisites

- **Claude Code built-in `general-purpose` agent** — 항상 사용 가능 (별도 설치 불필요). `conducting-interview` skill의 C43 ambiguity path가 dispatch.
- **`jq`** (CLI, recommended) — hook 스크립트가 stdin JSON payload 파싱과 `{"systemMessage": "..."}` JSON 출력에 사용. 없으면 regex fallback + loud warning (devbrew "loud-logging graceful degradation").
- **superpowers** (외부, optional) — 있으면 brief를 `brainstorming` 해답공간으로 넘기고 `writing-plans`로 이어집니다. 없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
- **codex CLI** (외부, optional) — 있으면 Phase 3 design-doc 리뷰에 병렬 독립 co-reviewer로 참여(model diversity). 없거나 auth 미설정이면 Claude-only로 graceful degrade + loud advisory(crash 없음). kill switch `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`.

## License

(devbrew root 정책 따름.)
