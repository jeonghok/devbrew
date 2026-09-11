# spec-distill

> 강한 문제공간 인터뷰(메타프롬프팅 + 웹 리서치 + adversarial steelman)로 방향을 끌어내 superpowers brainstorming용 interview brief를 생성하고, design doc은 물리 분리된 Law 2 reviewer가 검증하는 devbrew-native 플러그인.

## What it does

`/interview <rough request>` 호출 시 «직전 답에서» 블록 + 질문 둘 형식의 Korean Socratic
인터뷰가 **강한 문제공간 stage**로 동작합니다: 요청을 재구성(메타프롬프팅)하고, 외부 사례를 웹으로 조사하고(bounded), 약한 방향을
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

`conducting-interview` skill이 «직전 답에서» 블록 + 질문 둘 형식으로 첫 round를 시작합니다.

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
                                       · «직전 답에서» 블록 + 질문 둘 + 3-path (web=path(a))
                                       · R1 Problem Reframe / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ
                                       ▼ 5 의례 통과 (check_brief.py gate, Law 1)
                                   interview brief (payload + audit) → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ [Step A.5]  ※ 구조 게이트를 통과했을 뿐 아직 분리 리뷰 전
                                   [2] reviewing-brief (Law 2 분리 리뷰, cost_class: high 승인 게이트)
                                       │  진입 첫 액션: check_verbatim_coverage.py (payload §6 ∪ audit §6 ↔ state 원장)
                                       ├─ 1단계 방향성  brief-direction-reviewer + codex #1  (보고만, 병합 없음)
                                       ├─ 2단계 충실도  brief-critic(격리) + codex #2  fail-closed 합집합
                                       │                needs_revise → 수정 → fresh 재리뷰 (재dispatch 상한 2)
                                       └─ 3단계 냉독    brief-readback  (advisory, G1–G6 gap)
                                       ▼ 산출물 4종 (확정 후보 / 방향성 C4 / readback+gap / 모든 degrade record)
                                       ▼ [Step B proceed 게이트] ①/compact 후 brainstorming · ②바로 brainstorming · ③확정 목록 수정 · ④brief만 종료  (superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
                                       ▼ brainstorming 이 설계문서를 쓰고 커밋 — 사용자 리뷰 게이트 자리
                                       ▼ 오케스트레이터가 그 경로로 reviewing-spec 호출 (핸드오프 지시 · description — 훅 강제 없음)
                                   [3] reviewing-spec → 문서 리뷰 엔진 doc-critic → doc-recritic (Law 2, design-mode only)
                                       ├─ approval_gate_open → [5] proceed 게이트 → 재리뷰 상한 2 → writing-plans
                                       └─ round_gate_needed(decide 묶음 + 차단 ask) → brainstorming author 수정 → fresh 재리뷰
```

**v0.12.0**: drafting-spec 제거 + reviewing-spec design-mode 전용. interview는 brief까지 단독 완결.

**v0.13.0**: interview→brainstorming Step B를 `/compact` proceed 게이트(reviewing-spec Phase 5 대칭)로 재작성. — **v0.31.0에서 그 "대칭"(독립 저술 두 벌)이 하나의 공유 계약 `references/proceed-gate.md`로 합쳐졌다.**

**v0.14.0–v0.18.0**: 리뷰 재발동을 막는 방어층 3종이 순차로 쌓였다 — 문서별 억제 집합, approve 시 기록 순서 교정, 문서-키 진행중 락. 셋 다 훅이 자기가 만든 재발동을 자기가 막는 내부 하니스였고 **v0.25.0 에서 원인과 함께 삭제**됐다(상세는 CHANGELOG).

**v0.23.0**: interview brief를 핸드오프 아티팩트로 재설계. 라운드마다 결정을 잠그던 producer를 제거하고(`user_statements`에 판정 없이 기록), 확정 권한을 **종료 시 사용자 일괄 확인**으로 되돌렸다. brief는 payload(8섹션 역피라미드) + audit(텔레메트리) **두 파일**로 갈라지고 `audit_file`로 묶이며, frontmatter `user_sourced_items` 계약과 세 bijection이 body↔frontmatter·payload↔audit drift를 잡는다.

**v0.22.0**: [1] Interview 종료 driver를 고정 라운드 카운터에서 커버리지 원장(고정 floor 5 + 주제-도출 차원, status ∈ {open, in-progress, closed})으로 재구성 — 집요함·깊이·차원이 주제에 적응한다. tunneling 검출 에이전트는 `coverage-mapper`(주제-도출 차원 advisory 제안자)로 재명명·재목적화되었고, `blind-spot-prober`(적대적 premortem, fan-out 1)가 blind-spot floor 차원 구현으로 신설되었다.

**v0.24.0**: 구조 게이트를 통과한 interview brief에 **Law 2 분리 리뷰**(`reviewing-brief`)를 얹었다. 방향성(`brief-direction-reviewer` + codex #1, 보고만) → 충실도(`brief-critic` 격리 + codex #2, fail-closed 합집합) → 냉독(`brief-readback`, advisory) 3단계이고, `check_verbatim_coverage.py`가 진입 첫 액션으로 §6 원문 완전성을 state 원장과 대조한다. 리뷰어 셋은 전부 fail-closed `tools:` allowlist이며 `brief-critic`·`brief-readback`은 payload를 경로가 아니라 전문 inline으로 받는다. 모든 degradation은 `brief_review_degradations` 원장 + Step B 게이트 질문 텍스트로 표면화된다 — 돌지 못한 검사가 통과한 검사로 집계되지 않는다.

**v0.25.0**: design 문서를 편집할 때마다 리뷰가 재발동하던 원인 자체를 없앴다 — 문서 생애 단 한 번만 리뷰를 거는 세션 원장을 도입했고, v0.14.0–v0.18.0에 쌓였던 방어층 3종(억제 집합·순서 교정·진행중 락)이 근거를 잃어 함께 삭제됐다. 그 원장은 2.0.0 에서 리뷰 훅과 함께 삭제됐다.

**v0.41.0**: 파이프라인 맨 앞에 **Phase 0** `/request-framing`(skill: `framing-requests`)을 신설. 사용자의 의도·steering·방향·goal을 확산(원문 보존 → 레포 읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴에 `/interview` 의 인자로 그대로 붙여넣는 메시지 `interview-seed`로 만든다 — 산출물은 문서가 아니라 메시지다. 호출 모양의 정본은 `framing-requests` 의 「호출 모양」 절이다. 검증은 억제 축(`seed-critic` 격리 critic + codex, 셋째 담당)과 냉독 축(`seed-readback`)으로 나뉘고 판정은 사용자가 한다. `references/compression.md`(압축 규약)·`references/trivia-escape.md`(5패턴 정본, `/request-framing`이 가리킨다)를 채택하고, 확정 단계는 공유 계약 `references/proceed-gate.md`의 재결정 규약(P23)을 따른다.

**v0.41.0**: interview의 R1을 `Reframe (메타 프롬프트)`에서 **`Problem Reframe`**으로 재정의 — 「받은 요청 재구성」은 `request-framing`이 맡고, R1은 **seed가 가리키는 작업 뒤의 진짜 문제**를 재구성한다(R&R 이동, 명칭 변경이 아니다). `conducting-interview`가 `type: interview-seed` 입력을 받는 규약을 얻었다 — seed 본문은 §6 `S1`이 되고, 인터뷰 중 새 발화가 seed의 확정을 뒤집으면 새 발화가 이기며 그 재결정이 §5에 *원래/재결정/근거*로 남는다(P23). `commands/interview.md`의 trivia 5패턴 인라인 사본이 `references/trivia-escape.md` 포인터로 바뀌었고(v0.41.0 시점엔 아직 인라인이었다), seed가 아닌 입력에는 조언 한 줄만 내고 차단하지 않는다(호환 유지).

**2.0.0**: 설계문서 리뷰 진입의 훅 강제를 없앴다. brainstorming 뒤·writing-plans 앞의 `reviewing-spec` 호출은 오케스트레이터가 인터뷰 핸드오프 문구(`finishing.md` ①·②, brief 템플릿 §7)와 이 skill 의 description 을 읽고 스스로 한다. 끄기 판정은 진입 검사(`scripts/review_entry.py` + 리터럴 펜스, fail-closed)가, TTL-GC 기동은 SessionEnd 훅이 맡는다.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws

- **Law 1 (Clarity Before Code)** — Plugin의 raison d'être. 인터뷰 → brief → design doc → reviewer → human gate. **설계문서에는 필수 섹션 구조 게이트가 없다(2.0.0)** — 그것을 검사하던 코드(spec 모드 검사)는 생산자가 없어 발동하지 않았고 리뷰 훅과 함께 삭제됐다. 설계문서의 명확성은 `doc-critic` 층 2(`placeholder`·`ambiguity`)와 승인 게이트가 판정한다 — 이 리포의 Law 1 필수 섹션 게이트 구현은 0 이다(CHANGELOG `[2.0.0]`).
- **Law 1 (Clarity) — 문제공간 게이트 (v0.12.0)** — interview의 5 통과 의례(R1–R5)가 `check_brief.py`로 기계 검증되는 구조 게이트. 약한 방향(무인용 landscape·un-challenged 의심·빈 시행착오)은 brief 종료를 차단.
- **Law 2 (Writer/Reviewer 분리)** — `tools:` allowlist frontmatter로 doc-critic(`Read, Grep, Glob`) + doc-recritic(`Read, Grep, Glob`) + coverage-mapper(`Read, Grep, Glob, WebSearch, WebFetch`) + blind-spot-prober(`Read, Grep, Glob, WebSearch, WebFetch`) agent의 *물리적* 분리. 프롬프트가 아닌 frontmatter scoping이며, **allowlist라 열거되지 않은 쓰기·실행·위임 도구가 자동 차단**된다(denylist는 시간에 대해 fail-open이라 v0.21.0에서 폐기).
- **Law 2 — 리뷰 진입은 집행이 아니다 (2.0.0)** — 설계문서 리뷰 진입에 훅 강제가 없다. brainstorming 뒤·writing-plans 앞에 `reviewing-spec` 을 부르는 것은 오케스트레이터이고, 근거는 인터뷰 핸드오프 문구와 이 skill 의 description 이다 — 철학 P13(hook = 집행 / skill = capability 표면) 기준으로 이 자리의 집행이 사라졌다. `/brainstorming` 직접 경로는 description 하나에 기대므로 건너뛰는 일이 흔할 것이다 — 그때는 `/spec-distill:reviewing-spec <경로>` 로 부른다. 리뷰어의 물리 분리(`tools:` allowlist)는 그대로다.
- **Law 3 (Compounding) — 처분 회계(adjudication `Ledger`)** (v0.52.0) — 리뷰 findings 가 버려지는 자리가 `shared/adjudication/adjudication.py` 의 처분을 부른다. 소비자는 `scripts/merge_review.py`·`scripts/merge_brief_review.py`. 집행은 `shared/tests/test_adjudication_{wiring,consumed}.sh`. **범위**: `consumer=orchestrator`/`human` 인 dispatch 자리는 `disclosure=` 리터럴 실재까지만 검사된다(CLAUDE.md 축 C 한계) — 이 플러그인의 앵커 다수가 그쪽이다.
- **Law 2 (입력 오염 차단) — `input_slots`** (v0.52.0) — 이 플러그인의 agent 열이 frontmatter 에 받는 입력의 `tag`/`var`/`kind` 를 선언한다. 금지 종류(`prior_verdict`·`score`·`orchestrator_framing`)는 C6 인용과 함께 `tools/adjudication/check_slots.py` 의 `EXEMPT_SLOTS` 등재를 요구한다 — `blind-spot-prober.framing` 이 그 하나다(과업의 대상이 오케스트레이터의 재구성 그 자체라서). 집행은 `shared/tests/test_agent_input_slots.sh`.
- **Law 3 (Compounding)** — spec.md 파일 자체가 named, versioned, diff-able artifact (P5). state.local.md 보존 (실패 시) → 디버깅 + future session 추적.
- **Law 3 (Compounding) — model diversity (v0.20.0)** — codex 병렬 co-reviewer를 design-doc 리뷰에 추가. codex가 Claude persona가 반복해 놓치는 결함류(fail-open)를 잡으면 → 그 자리의 persona 파일(오늘은 `shared/docreview/agents/doc-critic.md`, v0.20.0 당시엔 `spec-reviewer.md`) 편집이 compounding 이벤트. quality-gates codex 패턴의 실증 이력을 상속.
- **AP2 approval-gate 구분 (v0.11.0)** — handoff 다음-단계 추천을 hook(텍스트 주입만 가능)이 아니라 reviewing-spec 의 `## 게이트` 절이 띄우는 `AskUserQuestion` proceed 게이트로 전달. 게이트는 사용자가 redirect 가능한 approval gate(P17)이자 AP2 polite-stop 봉쇄 장치 (철학 AP2 앵커). 진행(①/②) 직전의 미커밋 확인은 `reviewing-spec` `## 게이트` 의 리터럴 펜스가 한다 — 미커밋이거나 git 이 확인에 실패하면 advisory 만 내고 아무것도 기록하지 않는다. 세션 dir 삭제는 SessionEnd 훅(세션 폴더 + TTL-GC)이 한다.
- **Law 1 (Clarity) — 핸드오프 게이트 (v0.23.0)** — brief 구조 게이트가 **2파일 fail-closed**로 확장. payload frontmatter `audit_file`(basename만, traversal 거부)로 audit을 해석하고, 못 열면 payload-only로 degrade하지 않고 red를 낸다. `user_sourced_items` 스키마 + 세 bijection(A: payload §5 ↔ audit §3 / B: body §2 ↔ frontmatter — statement 내용까지 / C: `evidence: S<N>` → payload §6 ∪ audit §6)이 라벨과 내용이 어긋나는 drift를 기계로 잡는다.
- **P17 (User sovereignty) — 확정 권한 반환 (v0.23.0)** — 라운드마다 결정을 잠그던 producer를 제거하고 `status: confirmed`를 **종료 시 사용자 일괄 확인**으로만 발생시킨다. 확인은 새 의례가 아니라 기존 proceed 게이트에 흡수돼 상호작용이 1회로 유지된다(trivia ceremony 회피). 재제시에는 상한 2회가 있고 초과 시 전 항목이 `provisional`로 강등된다 — **덜 잠그는 쪽이 안전한 방향**(Unbounded-autonomy 가드).
- **Law 2 (brief, v0.24.0)** — 3중 분리: (a) 신규 에이전트 3개 전부 fail-closed `tools:`
  allowlist(쓰기·실행·위임 0개), (b) **입력 격리** — `brief-critic`·`brief-readback`은 payload
  전문을 inline으로만 받고 경로를 갖지 않으며, `tools: []`로 도달 경로가 물리적으로 없다,
  (c) **수정 후 fresh critic 재리뷰 1회 필수** — writer가 자기 수정을 승인하는 경로를
  차단한다(상한 2).
- **Law 3 (brief, v0.24.0)** — `brief-critic`의 `category` 6종과 readback gap 클래스 G1–G6가
  compounding substrate다. 리뷰가 놓친 결함류가 나오면 그 열거와 체크리스트를 편집하는 것이
  compounding 이벤트다(persona = 보안-민감 코드).
- **Law 3 (Compounding) — 문서 리뷰 엔진 기반 (v0.56.0)** — 네 문서 리뷰 자리를 통일하는 `shared/docreview/` 를 호출자 0 으로 심었다. 처분(decide·ask·fix·defer·drop)이 finding 의 수신자를 정하고, 회귀는 편집 범위·얼림·보호 부류로 막는다. 자리별 전환은 후속 PR(design doc·brief·seed). 집행은 `shared/tests/test_docreview_*.sh` + 변이 매트릭스.
- **「판정기가 항목을 버리면 센다」 + fail-closed — 엔진 결함 일곱 (v0.58.0)** — 호출자가 붙기 «전에» 이 일곱을 닫았다. 당시엔 **전부는 아니었다** — 재상승 후속 사슬 한 hop 뒤에서 다시 열리는 셋의 알려진 한계가 남아 있었다(설계 §6.4 「알려진 한계 셋」, PR 2 대상). 승인 차단은 역방향 스캔이 아니라 **전방 포인터**(`superseded_by`)로 판정하고(AC20), 소비되지 못한 재상승 예약·어휘 밖 재비판 verdict·`same_as` 허상 타겟은 버리지 않고 `reraise_unconsumed`/`coerced` 로 **센다**(AC21·AC27). 영구 차단에는 사용자 탈출구를 주되 「보류」는 거부한다(AC22 — 덜 잠그는 쪽이 아니라 «막힌 채로 두지 않는» 쪽이 안전한 방향). **v1.0.0 에서 셋 다 닫혔다** — (a) 재상승 후속의 「보류」 거부를 제안하는 선택지와 받아주는 선택지가 한 함수에서 나오게(전방 포인터가 원본의 차단을 후속에 넘겨도 같은 가드가 걸린다), (b) 재상승 후속이 원본의 `kind`·`prev_hash` 를 물려받아 원복 의무가 강등되지 않게, (c) `escalated` 예약도 재상승 예약과 같은 누적·dedup·계수 규칙을 따르고 상태 축의 정본 표(`is_open`·`gate_summary`·`render_gate` 를 한 표에서 도출)로 «막는 집합 ⊆ 그리는 집합»을 구조로 보장. **Law 2 계열의 자기검증**: 「동작 무변경」주장을 케이스 스위트 하나로 재지 않는다 — 실제 `fin.json`+state 골든 동치 · 단언 수까지 대조하는 전수 스위트 · 변이 매트릭스 판정의 셀별 대조, 셋을 함께 요구한다(AC26). 각각이 못 보는 것이 다르다: 스위트는 어떤 단언도 안 읽는 출력 필드를 못 보고, 골든은 세 케이스 밖을 못 보며, 매트릭스는 `sed` 가 매치 0 건이어도 성공을 내 조용히 무장해제된다. **그리고 검증 장치 자신이 락이어야 한다** — 골든은 `test_docreview_golden.sh` 로 스위트에 배선했고(사람이 기억해서 돌리는 스크립트는 락이 아니다), 매트릭스는 셀마다 diff 규모를 선언시켜 앵커 소실을 계측기 고장으로 잡는다.
- **Law 2 (Writer/Reviewer 분리) — design doc 자리 첫 호출자 배선 (v1.0.0)** — `reviewing-spec` 이 옛 verdict 파이프라인(`spec-reviewer` agent, `tools:` 에 `WebSearch`/`WebFetch` 포함)을 버리고 `shared/docreview/` 엔진의 껍데기가 됐다. 리뷰어는 `doc-critic`→`doc-recritic`(둘 다 `agents/*.md` 에 `# copy-of:` 마커로 바이트 동일 배포, `tools: Read, Grep, Glob` 뿐 — 심볼릭 링크 agent 는 dispatch 되지 않는다는 실측 때문에 사본이다) 이고, verdict(`approved`/`needs_revise`)는 사라져 승인은 게이트 판정(`approval_gate_open`)의 집계로 도출된다. **능력이 줄었다는 사실을 공시한다** — design-doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다(`design-doc.md` 프로필 `web: false`). 이것은 설계가 의도한 결정(§5.3·OQ-C)이고 이 전환이 뒤집지 않는다. **집행 없는 kill switch 는 이름조차 남기지 않는다(P21)** — 옛 handoff 우회 스위치(이름은 `CHANGELOG.md` `[1.0.0]` Removed 참고)의 유일한 집행 지점이 삭제된 `spec-reviewer.md` 뿐이었다는 것을 리포 전체(`shared/`·엔진·모든 프로필·모든 skill) 대상 `git grep` 으로 확인한 뒤 이 README 의 문서화를 지웠고, **같은 커밋에서** `test_handoff_kill_switch.sh` 의 부재-판정 코퍼스를 이 README 까지 넓혀 그 이름이 design 자리 표면에 재등장하면 RED 가 나게 했다(그 락 자신은 `SWITCH=` 변수에 그 이름을 여전히 리터럴로 쥔다 — 부재를 재려면 무엇의 부재인지 알아야 하기 때문이다. 반대로 **이 README 는**, 자신이 그 락의 코퍼스에 들어간 이상 이 문단에서도 그 이름을 리터럴로 쓰지 않는다) — 집행이 없다는 관찰과 그것을 지키는 회귀 락이 갈라지면 다음 사람이 손으로 다시 넓혀야 하고, 그 창에서는 「이름은 있는데 아무도 안 지킨다」가 다시 조용해진다.
- **Law 3 (Compounding) — 깊이 측정 원장 (v0.57.0)** — 인터뷰마다 «답→다음 행동» 짝을 세 층(스크립트·`depth-auditor`·사람 ≤4 라벨)으로 재어 `docs/superpowers/interview/depth/<basename>.json` 에 남긴다. `depth_record.py` 가 `depth/*.json` 을 읽어 판정자 투입 조건(적격 5건·not_dug 30%·일치 70%)을 audit 에 한 줄로 낸다 — 게이트 아님(spec C5).

### Principles 흡수

- **P2 (Ambiguity Gate)** — numerical 거부 (philosophy P2). 설계문서의 모호성은 `doc-critic` 층 2 가 판정한다 — 필수 섹션 구조 게이트는 2.0.0 에서 삭제됐다(위 Law 1).
- **P5 (Spec as artifact)** — `docs/superpowers/specs/...spec.md` named, versioned (frontmatter `version: 1.0.0`).
- **P12 (Trivia escape)** — `/interview` first-step rule (typo / 주석-only / formatting / rename / <10 토큰 + 단일 action). 파일 수는 자격 기준이 아니다.
- **P14 (State preservation)** — `.claude/spec-distill/<session-id>/state.local.md` (실패/abort 시 보존).
- **P17 (User sovereignty)** — `needs_interview` user confirm gate, 문서 리뷰 엔진의 **승인 게이트**(정본 `references/proceed-gate.md` — 진행·수정·멈춤을 사용자가 고른다), all kill switches.
- **P17 (User sovereignty) — 사용자가 시계 (v0.57.0)** — 차원은 사용자 발화 `S<N>` 을 인용해야 닫히고(`check_brief.py` 앵커 게이트), 재개방에 상한이 없다 — 라운드는 사용자 답으로만 돈다.
- **P18 (Stagnation detection)** — 라운드 n 의 **열린 계보**(`open_lineages`) 집합이 n−1 과 같고 그 사이 진행이 0 건이면 stagnation 이고, 승인 게이트가 즉시 열린다(`shared/docreview/scripts/docreview_state.py` 의 `gate_summary`). 「진행」은 `check-intent` 를 통과한 fix 적용과 채택 결정의 permit 적용 둘을 센다 — 채택대로 고친 라운드는 계보가 같아도 stagnation 이 아니다.
- **P21 (Secret 기록 금지 / untrusted input)** — state.local.md token/key/credential placeholder 치환. **v0.23.0**: `audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(`../`·절대경로·서브경로 전부 거부).
- **P22 (Cost class)** — 모든 skill cost_class 선언 (conducting-interview: variable / reviewing-spec: medium).
- **P23 (Decisions Stay Refutable)** — `framing-requests`의 「재결정 규약」 절(정본은 `references/proceed-gate.md`)이 확산에서 확정된 것을 압축 단계가 뒤집을 때 임의 변경이 아니라 근거 제시 + 사용자 동의 + audit *원래/재결정/근거* 세 칸 기록을 강제한다. `conducting-interview`도 하류에서 같은 원칙을 잇는다(v0.41.0) — 인터뷰 중 새 발화가 seed의 확정을 뒤집으면 조용히 덮어쓰지 않고 새 발화가 이기며, §5 기각에 같은 *원래/재결정/근거* 형태로 남는다.
- **worktree-safe state path (P5·P14)**: state 파일 위치를 `state_path.state_root()`로 단일화하여 worktree 호출 시에도 main repo `.claude/spec-distill/`에만 기록 — `ExitWorktree action: remove` 시 원장 state silent loss 차단.

### Roadmap absorption (C-numbers)

- **C43** 3-path Socratic routing (factual auto-confirm / judgment→user / ontological, 라벨 강제 없음 — v0.57.0에서 ambiguity→sub-agent 경로·5-type 라벨 요구 제거).
- **C44** Dialectic Rhythm Guard (env: `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD`, default 3).
- **C1** 사용자-발화 floor 탈출구 — Unbounded-autonomy 가드(사용자가 언제든 종료를 요청하면 미충족 floor를 사용자-승인 박제로 닫고 payload §3 Open Questions로 이월).
- **C4** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자, dispatch 상한 2) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem, fan-out 1).

### Anti-pattern 회피

- **AP3 (Self-approval)** — writer/reviewer 물리적 분리 (frontmatter scoping).
- **AP2 (Polite stop)** — **정본은 `references/proceed-gate.md`** (v0.31.0). 두 proceed 게이트(reviewing-spec 의 `## 게이트` 절 · conducting-interview 종료 Step B)가 그 파일의 골격·두 가드·예외 경로를 공유하며, 각 skill 은 자기 어휘(옵션 라벨 · verbatim `/compact` 템플릿 · 고유 스텝)만 인라인으로 갖는다. 아래는 그 계약의 **요약**이지 별개 저술이 아니다 — 계약이 바뀌면 정본을 고치고 여기를 따라 고친다. approve tail = proceed 게이트(AskUserQuestion) → 미커밋 확인(리터럴 펜스, 기록 없음). 게이트를 skip한 narrate-only 종료 금지. cross-compact 조기 진행(옵션 ① 노출 후 같은 턴 writing-plans 직진)도 게이트 P17 우회의 대칭 실패로 금지 (v0.11.0 AC19). interview→brainstorming Step B의 **4옵션**: ①/compact 후 brainstorming / ②바로 brainstorming / ③확정 목록 수정 / ④brief만 종료 (③ 추가는 v0.23.0) — 전용 handoff 스크립트를 호출하지 않음(brief는 막 검증됨, 하류/SessionEnd가 cleanup) (v0.13.0).
- **AP5 (Trivia ceremony)** — `/interview` first-step trivia escape (5 패턴).
- **AP9 (Subagent spray)** — `plugins/spec-distill/agents/` 11종(doc-critic·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·brief-critic·brief-direction-reviewer·brief-readback·seed-critic·seed-readback·depth-auditor). 상한이 선언된 것: coverage-mapper dispatch 상한 2 + blind-spot-prober fan-out 1(interview) · brief-critic 재dispatch 상한 2(reviewing-brief).
- **P11 (Cross-Model Adversarial)** — sub-agent reviewer adversarial review + **`steelman-builder` 의심 게이트(v0.12.0, v0.54.0 재설계)**: 의심 방향에 대해 builder 가 원안·대안 **양쪽**의 최강 케이스를 사용자 goal 기준으로 쓰고 근거가 핵심 전제에 닿는지 판정한다. 재검토를 여는 열쇠는 전제 충돌 하나 — 그 외 근거는 원안 강화·경계 다듬기에 쓴다. 판정 어휘 유지/보완/전환/보류(kept/refined/switched/deferred), 선택은 사용자.
- **AP16 (Unbounded autonomy)** — 재리뷰 상한 2 (정본은 `shared/docreview/references/reviewing-document.md` 한 줄이고, 라운드 4 이상은 승인 게이트에서 사용자가 연다), rhythm guard 3, kill switch.
- **P14 (State Survives Compaction)** — state.local.md frontmatter 보존.
- **P3 — graceful degradation with loud logging**: `resolve_session_id` 검증 실패 시 None 반환 + stderr advisory. cleanup 실패 시 silent skip (SessionEnd), 미커밋 확인·진입 검사 실패는 advisory — 사용자 attention 가용성에 따라 loud 정도 조정. 진입 검사 자신의 실패는 끔으로 친다(fail-closed).
- **P14 — failure-time state preservation**: `write_state`가 stale-session 검출 시 *명시적* truncate (정상 케이스), 그러나 unreadable file은 보존 (failure preservation). TTL-GC도 self-session 보호 + grace window로 in-flight data 보호.

## External source absorption

- **devbrother2024 deep-interview** — 초기 영향은 4-block Korean format (현재 이해 / 막힌 결정 / 추천 답안 / 질문). v0.57.0에서 **라운드 규약의** 4-block 이 «직전 답에서» 블록 + 질문 둘로 대체됐다. 형식 자체가 리포에서 사라진 것은 아니다 — **R3 steelman 게이트**는 제시 형식으로 4-block 을 그대로 쓴다(`skills/conducting-interview/references/steelman.md` Step 3). 같은 어휘를 쓰는 다른 물건이라 한쪽의 제거가 다른 쪽의 제거가 아니고, `tests/test_conducting_interview_stage.sh` 의 G7 부재 락이 그 파일 하나만 예외로 두되 그 예외가 vacuous 하지 않은지를 양성 대조로 함께 잰다.
- **gstack** — concrete-next-action refusal pattern + ETHOS ("AI recommends, users decide"). Structural baseline(11 필수 섹션) 흡수분은 2.0.0 에서 그 검사 코드와 함께 삭제됐다.
- **OMC** — env-var configurable threshold (steelman antithesis는 plan-reviewer PR로 defer, v0.2.0+ 회귀 도입).
- **superpowers** — 산출물 위치(`docs/superpowers/specs/`) + plan-document-reviewer 출력 형식 (Status / Issues / Recommendations) + brainstorming drop-in 대체.
- **Ouroboros** — inner/outer loop spirit (graph back-edges), spec lifecycle as named/versioned. (단 numerical ambiguity gate 거부, philosophy P2 비추천.)

## Hooks Installed

| Event | Script | 책임 | 왜 skill이 아닌가 |
|---|---|---|---|
| SessionEnd | `hooks/session-end-cleanup.py` | ① kill switch → ② 끝나는 세션의 `.claude/spec-distill/<sid>/` 삭제(v0.6.0) → ③ `finally` 에서 TTL-GC(`scripts/spec-distill-gc.py`) 기동(2.0.0) — payload 가 깨져도 GC 는 돈다. polite-stop이나 approve 누락 시에도 cleanup 보장. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` / `:session-end-cleanup` — **세션 정리와 TTL-GC 를 함께 끈다**. GC 만 끄려면 `spec-distill:spec-distill-gc`. | Claude lifecycle 이벤트는 hook이 catch해야 함 — skill은 사용자/LLM이 invoke해야 동작. |

**Output:** SessionEnd 훅은 stdout 을 내지 않는다 — 실패(stdin 판독 · GC 비정상 종료)는 `[spec-distill]` 접두의 stderr 로만 알린다.

## Kill switches

### 먼저 — 설계문서 리뷰를 끄는 법

설계문서 리뷰 진입은 `reviewing-spec` 이 엔진 라운드 전에 도는 진입 검사(`scripts/review_entry.py` + 리터럴 펜스)가 판정한다. 끄는 스위치는 셋이고 셋 다 수동 호출(`/spec-distill:reviewing-spec`)까지 끈다: `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · 플러그인 전체 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 진입 검사 자신이 실패하면(모듈 부재 · rc≠0 · 출력 계약 위반) 끔으로 친다 — 그 사실이 advisory 로 나오고 brainstorming 의 사용자 리뷰 게이트로 돌아간다. 전부 세션 스코프 env var 라 재시작이 필요하다.

### 스위치 목록

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — plugin 전체 abort, state 보존.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` (v0.20.0, v0.24.0 확대) — codex 병렬 co-review만 skip. Claude 리뷰는 정상 동작, combined = Claude verdict + loud degrade advisory. 전역 `DEVBREW_SPEC_DISTILL_DISABLE`과 독립. **적용 범위는 두 경로 전부**: (a) design-doc 리뷰(`reviewing-spec`), (b) brief 리뷰(`reviewing-brief`)의 **호출 지점 3곳** — 1-c 방향성 축 · 2-b 충실도 축 · 2-c 충실도 재실행. 게이트는 **호출자 책임**이다 — `detect_codex.sh`가 이 스위치를 `codex_available: false`로 옮기고 세 지점이 같은 `$codex_avail`로 묶이며, 러너(`run_brief_codex_reviewer.sh`)는 이 변수를 보지 않는다. 한 지점이라도 게이트 밖이면 opt-out이 무시된 채 지출이 나가고 `affected_axis: all` degradation record가 거짓이 된다.
- `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` — 문서 리뷰 엔진의 **재비판 단계만** skip (`doc-recritic` dispatch 없음). 탐지·codex 는 정상 동작한다. 기각 경로가 0 이 된 사실은 `fin.json` 의 `advisory[]` 로 공시된다 — 오탐이 걸러지지 않은 라운드라는 뜻이므로 조용히 넘어가지 않는다.
- `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0, 2.0.0 재정의) — `reviewing-spec` 진입 검사가 설계문서 리뷰를 끈다 — **수동 호출 포함** skill 전체다(1.x 까지는 자동 리뷰와 구조 검사만 끄고 수동 호출은 살아 있었다). 파일 분류(content-aware 판별)는 없다 — 이 skill 은 받은 경로를 `design-doc.md` 프로필로 리뷰한다.
- `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` (2.0.0) — 같은 효과의 이름 붙은 스위치. 수신처는 `scripts/review_entry.py` 의 진입 검사다(`spec-distill:review-entry`) — 훅이 아니지만 지목할 이름을 갖는다(`spec-distill-gc` 와 같은 관례).
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` (alias: `spec-distill:session-end-cleanup`) — SessionEnd 훅 전체를 끈다: 끝나는 세션의 폴더 정리 **와** TTL-GC 기동 둘 다. GC 만 끄려면 아래 `spec-distill:spec-distill-gc`.
- `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` — TTL-GC 스크립트(`scripts/spec-distill-gc.py` — SessionEnd 훅이 기동한다)만 skip. 훅이 아니지만 지목할 이름을 갖는다 — 그전에는 이 스크립트가 `DEVBREW_SKIP_HOOKS`를 **아예 읽지 않아서**, 그 변수로 껐다고 믿어도 GC는 계속 돌았다.
- `DEVBREW_SPEC_DISTILL_TTL_HOURS=<int>` (v0.6.0) — TTL-GC orphan 정리 임계값 (default 24h). 짧게 설정 시 자주 정리, in-flight 작업 risk 증가.
- `DEVBREW_SPEC_DISTILL_GC_VERBOSE=1` (v0.6.0) — TTL-GC가 cleanup 발생 시 stdout summary 출력. CI/디버깅용.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` (v0.12.0, AC21로 범위 확대) — 이 kill switch 가
  **두 소비자**의 웹 접근을 끈다: interview 웹 리서치(landscape, v0.12.0), codex brief
  co-reviewer(`run_brief_codex_reviewer.sh`, AC21). 어느 쪽이든 loud log와 함께 생략, crash
  없음 (graceful degradation, AC8). **design-doc 리뷰는 이 스위치의 대상이 아니다** — `doc-critic`·
  `doc-recritic` 은 `tools:` 에 웹 도구가 아예 없고 `design-doc.md` 프로필이 `web: false` 를
  고정해서(설계 §5.3·OQ-C 결정, v1.0.0) 켜고 끌 것이 없다.
- `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1` (v0.57.0) — `framing-requests` 진입 직후의 워크트리
  질문을 **묻지 않고** 현재 디렉토리에서 진행한다. `EnterWorktree` 도구 부재와 같은 경로다.
  audit §5 에 «워크트리 없음 —» 강등 기록이 남고, 어느 경우도 seed 작성을 막지 않는다.
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` (v0.24.0) — brief 리뷰 파이프라인 전체 skip.
  `component: pipeline` degradation record + loud advisory를 남기고 Step B로 직행한다(조용한
  생략이 아니다). 충실도·방향성·냉독 전부 미검증 상태가 게이트 질문에 표시된다.

### 은퇴한 스위치 (v0.36.0 · 2.0.0)

`PostToolUse` validator 와 `UserPromptSubmit` reminder(v0.36.0), 설계문서 리뷰 훅(2.0.0)이 삭제되면서 다음이 아무것도 끄지 않게 됐다. `reviewing-spec` 의 진입 검사가 리뷰를 부를 때마다 advisory 로 알린다.

- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` (2.0.0) — 가리키던 훅이 삭제됐다. **리뷰를 막지 않는다** — 이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다. 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`. 이 토큰은 TTL-GC 도 더 이상 멈추지 않는다.
- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` / `:validator` (v0.36.0) — 끄던 구조 검사가 삭제돼 아무것도 끄지 않는다.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder` (v0.36.0) — 재-nag 층 자체가 없다.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.36.0) — 읽는 곳이 없다. 설계문서 리뷰를 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`.

## Prerequisites

- **`jq`** (CLI, recommended) — hook 스크립트가 stdin JSON payload 파싱과 `{"systemMessage": "..."}` JSON 출력에 사용. 없으면 regex fallback + loud warning (devbrew "loud-logging graceful degradation").
- **superpowers** (외부, optional) — 있으면 brief를 `brainstorming` 해답공간으로 넘기고 `writing-plans`로 이어집니다. 없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
- **codex CLI** (외부, optional) — 있으면 Phase 3 design-doc 리뷰에 병렬 독립 co-reviewer로 참여(model diversity). 없거나 auth 미설정이면 Claude-only로 graceful degrade + loud advisory(crash 없음). kill switch `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`.

## License

(devbrew root 정책 따름.)
