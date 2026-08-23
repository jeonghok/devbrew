---
type: interview-audit
payload: 2026-08-22-request-framing-phase0-interview.md
created_at: 2026-08-22
session_id: 6fc6c085-03f0-4a6c-8596-b1040747f06d
source: spec-distill conducting-interview v0.23.0
---

# request-framing Phase 0 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 확정: 대상은 '단계 하나 추가'가 아니라 '거친 요청을 다음 에이전트가 실행 가능한 계약으로 바꾸되, 그 변환 과정에서 에이전트 추론이 사용자 결정으로 위장하는 것을 구조적으로 막는 것'. 원문 내부 긴장 3건 전부 사용자 판정으로 해소 — P1(소비자 범위)→S1, P2(닫힘 정의)→S2, P3(codex 역할)→S3. 진입 표면→S4, 핸드오프→S5.
- floor:landscape — closed — web 2회(REprompt arXiv 2601.16507 / 에이전트 사전-실행 diff·provenance 추적) + 리포 내 prior art 3종: `shared/codex/` 4러너 공통 골격, `references/proceed-gate.md` 의 `/compact` 세션 핸드오프 게이트, `check_brief.py` 15항 구조 게이트. steelman 이 추가로 8건(MAST·DORA·Fowler·Metz·Cooper·Poppendieck·Ferrari·Anthropic 2종), blind-spot 이 18건 공급.
- floor:skepticism — closed — ST1 steelman dispatch 1회. 의심 방향 = '새 단계 추가', 대안 = '새 단계 없이 conducting-interview R1+Round1 심화로 흡수'. 사용자 판정 = defended(S6). 오케스트레이터 검증으로 steelman 의 핵심 사실 주장 1건 반증 — '최초 요청'은 템플릿·fixture 에만 존재하고 게이트 15항 어디에도 없음.
- floor:blind_spot — closed — blind-spot-prober 1회(C8, 인터뷰당 1회). 숨은 가정 8건 + 실패 양식 9건. 사용자에게 8건 표면화, 전량 payload §5 `위험` 항목으로 기록.
- floor:open_questions — closed — 9건 박제(유추 금지). payload §3 참조.
- derived: N/A

## 2. Budget

- probe_count: 8 / cap 12
- coverage-mapper dispatch: 0회 (no_progress_streak 이 3에 도달한 적 없음 — 매 probe 가 focused 차원을 전진시킴)
- blind-spot-prober dispatch: 1회
- steelman-builder dispatch: 1회
- 매핑 subagent(Explore): 2회 (codex 사슬 / brief 계약)
- non_user_streak: 0 (8 probe 전부 사용자 답변 수신)

## 3. Steelman 원문

#### ST1 — 새 단계를 만들지 말고 기존 conducting-interview 앞부분을 심화하라

> **alternative_statement**: 새 `request-framing` 단계를 만들지 않는다 — 요청 원형 보존·의도 정렬·추론/결정 분리·정제 diff 표면화는 전부 `conducting-interview` 안에 이미 존재하는 표면(R1 Reframe, §6 사용자 원문, `user_sourced_items[]` provenance, bijection B/C, `check_verbatim_coverage.py` L1·L2)의 *심화*로 달성하고, 새 command·새 skill·새 `interview-seed` 산출물·새 codex 러너·새 종료 게이트는 전부 만들지 않는다.
>
> **strongest_case**: 원안이 새로 만들겠다는 네 기능은 이 리포에 이미 구현돼 있고 기계 검증까지 붙어 있다 — 요청 원형은 `/interview $ARGUMENTS` → §6 `S1` 전문 보존(요약·재서술·발췌 금지)으로, 추론/결정 분리는 `🗣/☑` vs `✎`와 "`source: inferred`는 frontmatter에 들어갈 수 없다"는 fail-closed 규칙으로, 정제 diff는 §2의 모델 요약(160자) ↔ §6 원문 사이의 bijection B/C와 `check_verbatim_coverage.py`의 L1·L2 대조로 이미 강제된다. 따라서 새 단계가 추가하는 것은 *기능*이 아니라 **경계 하나와 핸드오프 하나**다 — 그리고 경계·핸드오프가 바로 멀티에이전트 시스템의 지배적 실패원이다(MAST의 3범주 중 두 개가 "poor decomposition·duplicate agent roles"와 "handoff 시 context 손실"이고, Poppendieck은 핸드오프 1회당 암묵지 ~50% 소실을 말한다). 게다가 두 단계의 사용자·세션·대화가 동일하므로 분리가 사는 유일한 조건(다른 액터·다른 시간·다른 신뢰경계)이 성립하지 않는다. 품질을 올리는 실증된 지렛대는 앞단 게이트가 아니라 **인터뷰 루프 내부의 모호성 탐지→후속 질문**이며(Ferrari et al., 34건 실증), DORA는 "외부의 형식적 승인 단계가 실패율을 낮춘다는 증거를 찾지 못했다"고 명시한다. 마지막으로 경계는 지금 그을 수 없다 — Fowler·Metz의 논지대로, 세그먼트를 나눌 근거(실제로 어느 지점에서 인터뷰가 깨지는가)를 얻기 전에 그은 경계는 되돌리기가 유지보다 비싸다.
>
> **weakness_of_current**: 원안이 '새 기능'이라 부르는 네 가지가 전부 기존 표면의 **재구현**이다 — 요청 원형 보존은 §6, 추론/결정 분리는 `user_sourced_items` + `✎` 규칙, 정제 diff는 bijection B/C, 의도 정렬 재구성은 R1 Reframe(요청자 본인이 '개명'을 요청했다 = 동일 기능임을 자인). 따라서 원안의 순증분은 기능이 아니라 경계·핸드오프·게이트·로드 표면이며, 그중 어느 것도 '지금 무엇이 실패하고 있는가'라는 관측 근거를 제시하지 못한다. 더 약한 지점: 같은 사용자·같은 세션·같은 대화를 두 단계가 나눠 가지므로 관심사 분리가 사는 조건이 하나도 성립하지 않고, 두 단계가 같은 것을 다른 이름으로 부르면(R1 Reframe vs Problem Reframe) MAST가 지목한 duplicate role·ambiguous role definition이 그대로 신설된다. 마지막으로 이 리포는 직전 사이클에서 로드 표면 −19.8%를 명시적 목표로 감축했고 P8이 '결정론은 보안/정확성 게이트에만'을 못박고 있는데, 새 단계는 보안도 정확성도 아닌 *조직화*를 위해 결정론 장치 4종(command·skill·러너·게이트)을 신설한다.
>
> **confidence**: 0.82
>
> **evidence (10건)**: MAST https://arxiv.org/abs/2503.13657 · Cognition https://cognition.com/blog/dont-build-multi-agents · Poppendieck https://6sigma.com/poppendieck-on-waste-the-handoff/ · DORA https://dora.dev/capabilities/streamlining-change-approval/ · Anthropic https://www.anthropic.com/engineering/building-effective-agents · Anthropic https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents · Ferrari et al. https://link.springer.com/article/10.1007/s00766-016-0249-3 · Fowler https://martinfowler.com/bliki/MonolithFirst.html · Metz https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction · Cooper https://media.transformanceadvisors.com/pdfs/After-Stage-Gate.pdf
>
> **builder 가 스스로 밝힌, 이 대안이 실패하는 조건**: (1) `/interview` 이전이 진짜 비어 있는 경우 — 심화할 R1도 §6 S1도 없다. (2) 다른 액터·다른 시간에 쓰이는 경우 — 핸드오프가 비용이 아니라 요구사항이 되며, "원안이 이길 수 있는 가장 현실적인 경로". (3) `conducting-interview` 가 이미 과적재라 심화가 불가능한 경우 — 그때의 옳은 답은 새 단계가 아니라 `references/*.md` 조건부 분할. (4) 인터뷰 종료 후에야 프레이밍 오류가 드러난다는 실측이 있는 경우 — "원안도 대안도 실패 데이터를 제시하지 않았다는 대칭적 공백"이며 그 공백에서 default 는 대안 쪽. (5) codex 러너 항목은 별개 판정 — 한도 소진으로 어느 설계든 지금은 실측 불가.

**오케스트레이터 검증 (verbatim pass-through 이후 별도 기록)**: ST1 의 핵심 사실 주장 중 하나가 반증됐다. `"최초 요청"` 문자열은 `templates/interview-brief-template.md:83` 과 테스트 fixture 에만 존재하며 `check_brief.py`·`check_verbatim_coverage.py`·`finishing.md` 어디에도 없다. `finishing.md:31` 은 §6 을 `user_statements` 에서 채우고, `SKILL.md:134` 는 그것을 "매 round 끝에 사용자가 실제로 **답한** 것"으로 정의하므로 `$ARGUMENTS`(최초 요청)는 기계적으로 §6 에 요구되지 않는다. 즉 Raw Capture 는 실재 갭이며, ST1 의 "이미 달성" 주장은 템플릿 관례를 기계 강제로 오인한 것이다.

## 4. 게이트 실행 기록

- check_brief.py gate — **pass** (2026-08-22). 총 9회 실행: Step A 최초 1회(첫 실행 통과) · 방향성 수정 후 1회 · 내부 정합 수정 후 1회 · 충실도 라운드2 전후 2회 · 라운드3 전 1회 · S0 sweep 후 1회 · 확정 전이 후 1회 · §0 정정 후 1회. 전부 pass.
- check_verbatim_coverage.py — **exit 0** (2026-08-22). 6회 실행(진입 첫 액션 포함), `missing_ids: []` / `not_contained: []` / `advisories: []` 일관.
- **기록 순서 오류(자기 고발)**: 이 절의 초판은 게이트를 *실행하기 전에* `pass`/`exit 0` 을 적었다. 결과적으로 두 값 모두 실측과 일치했으나 순서가 규칙 위반이며("verdict 전 결과 기록 금지"), 지금 값은 9회·6회 실행 후의 실측이다.

## 5. 프로세스 로그

- round 1: path (b) — seed 소비자 범위(P1). 원문 내부 모순 표면화 후 사용자 판정.
- round 2: path (b) — '공간을 닫는다'의 경계(P2). 금지 대상을 예시 이름이 아니라 역할로 정의.
- round 3: path (b) — codex 역할(P3). Suppression Review 4항목이 기존 findings 분류표와 1:1임을 제시.
- round 4: path (b) — 진입 표면. 완전 opt-in 시 우회 위험 표면화.
- round 5: path (b) — 세션 핸드오프. "세션 안에서 새 세션을 띄울 수 없다"는 기계적 사실 제시.
- round 6: path (b) — R3 steelman 게이트. verdict = defended.
- round 7: path (b) — 성공 oracle. **사용자가 선택지 밖으로 나가 자유 서술로 답함** — 전제 자체를 되돌림.
- round 8: path (b) — 제시되지 않은 선택지 처리. round 7 의 이탈이 이 질문의 실례가 됨.

### 제시한 선택지 집합 전체 (S8 규약의 첫 적용)

**이 항목은 S8 이 정한 규칙을 이 인터뷰 자신에게 소급 적용한 것이다.** 고른 것만이 아니라 각 라운드에 실제로 제시된 옵션 집합 전부를 남긴다 — 닫힌 선택지가 어떤 산출물에도 흔적을 남기지 않는다는 blind-spot 지적에 대한 대응이며, 사후 검토와 리뷰어 코퍼스 확보가 목적이다. **선택지의 저자는 전부 모델(orchestrator)이다.**

- round 1 — 제시: ③ 단일 소비자 + 중립 포맷(추천) / ① interview 전용 고정 / ② 범용 프롬프트 도구. **선택: ③**. 미제시로 언급만 된 것: profile 전량 구현(image-gen 포함) — 검증할 다운스트림 부재로 제외.
- round 2 — 제시: ① 작업-기술 필드만 허용(추천) / ② 순수 산문 프롬프트 / ③ 목록 허용 + non-exhaustive 강제. **선택: ①**. 미제시로 언급만 된 것: "OQ 섹션만 콕 집어 금지" — 예시 하나에 결박된 규칙이라 제외.
- round 3 — 제시: ① 비평자(추천) / ② 공동 생성자 / ③ 질문 제안자 / ④ ①+②. **선택: ①**. 미제시로 언급만 된 것: codex 를 profile 감지에만 사용 — 분류는 판정이 아니라 모델 다양성 이득 없음.
- round 4 — 제시: ③ 별도 command + 조언(추천) / ① 별도 command 만 / ② `/interview` 자동 분기 / ④ 별도 command + 훅 강제. **선택: ③**.
- round 5 — 제시: ③ 두 경로 모두(추천) / ① 새 세션만 / ② `/compact` 재사용만. **선택: ③**. 미제시로 언급만 된 것: seed 생성 즉시 자동 진행 — 원문이 직접 금지.
- round 6 — 제시: ① 방어(추천) / ③ 부분 전환 / ② 전환 / ④ 보류. **선택: ①**.
- round 7 — 제시: ① 되돌림 발생 여부(추천) / ② 계측만·판정 보류 / ③ 구조적 검증만 / ④ A/B 비교. **선택: 없음 — 사용자가 네 선택지 밖에서 자유 서술로 답함(S7)**. 이 이탈은 제시된 선택지 집합이 답을 담고 있지 않았음을 뜻한다.
- round 8 — 제시: ① 제시한 선택지 전부 audit 기록(추천) / ② 탈출구만 구조적 보장 / ③ 문제로 보지 않음. **선택: ①**. 미제시로 언급만 된 것: `chosen` 에 새 provenance 등급 추가 — 라벨을 늘려도 미제시분은 여전히 불가시.

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 8건 / codex 0건(강등) — 사용자 재결정 4건(D4·D5·D6·D8 → S9~S12), 이월 3건(D1·D2·D3 → OQ10~12), §4 미평가 승격 1건(D7).
- 충실도 기록(게이트 아님, 마지막 관측 verdict): **needs_revise** — critic 라운드1 8건 / 라운드2 3건 / 라운드3 10건, codex 0건(강등). 재라운드 **2/2 (상한 도달, forced escalate)**.
- 냉독: **미실행** — 충실도 hard gate 미통과 상태로 상한 도달, 3단계 진입 전 escalate. 가독성 축 미측정.
- degrade: codex:direction(degraded, 모델 400 이 한도 오류를 가림) · codex:fidelity(degraded, 동일 원인 — 합집합이 critic 단독으로 축소) · critic:fidelity(degraded, 재리뷰 상한 초과·findings 잔존) · readback:readback(skipped, forced escalate 경로).
- 격리: zero-tool probe **ZERO_TOOL_OK**(`docs/audits/2026-07-27-spec-distill-zero-tool-probe.md:121`) — critic·readback 이 `tools: []`, 충실도 verdict 는 hard gate 로 작동. `codex_isolated: false`.
- **상한 이후 편집(미검증)**: 라운드3 findings 10건 중 9건을 상한 도달 *후* 수정했다(S0 구속 요구 14건 승격 + C3 supersession 표시 + §5 비대칭 해소 + authority 어휘 교정). 이 수정들은 **어느 독립 리뷰어도 보지 않았다** — fresh critic 재dispatch 가 상한으로 막혀 있기 때문이다. 사용자가 proceed 게이트에서 이 사실을 알고 ① 을 선택했다.
- 미반영 1건: frontmatter sentinel(`check_brief.py` 강제 문구) — 저자 권한 밖, §5 에 하니스 결함으로 기록.

### 확정 전이 (proceed 게이트 ①)

- 재제시 1/2 후 사용자가 ① 선택 → **29건 `provisional` → `confirmed`**. sentinel 줄은 같은 write 에서 삭제.
- `provisional` 유지: **C3** 1건 — C13 이 범위를 바꿔 확정 시 충돌하는 유효 제약 두 개가 생기므로. 이력으로 남김.
