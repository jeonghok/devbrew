---
name: qg-llm-security-gap-assessment
type: interview-brief
created_at: 2026-06-20
session_id: ec41425d-c57a-41fc-959a-a1157db73a65
source: spec-distill conducting-interview v0.17.0
next_phase: superpowers:brainstorming
# locked_directions — (b)/(d) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
locked_directions:
  - id: LD1
    statement: "1차 산출물 = 블로그 6-step <-> qg 파이프라인 gap 평가 문서(이미-됨/흡수-권장/기각 verdict). 코드 변경은 후속. B(구체설계)·C(통째포팅) 기각."
    source_path: b
    steelman: n/a
  - id: LD2
    statement: "scale-up gap(partition 병렬 discovery·multi-vote N>2)은 보안 load-bearing carve-out으로 evidence-weighted 평가; steelman 4논거가 REJECT 증명책임 bar."
    source_path: b
    steelman: defended
    defense: "carve-out 프레이밍 자체는 steelman이 반박 못함 — per-gap 평가는 유지하고, steelman의 transfer-validity·diminishing-returns 논거를 scale-up gap을 REJECT하는 증명책임 bar로 흡수(gap-assessment의 기각사유 근거가 됨)."
  - id: LD3
    statement: "threat-model은 기존 spec-as-truth 활용 심화(triage/severity에 spec 위협맥락 주입)만 qg 범위로 평가; 새 threat-model stage 신설은 상류(spec-distill/writing-plans) 소유라 제외."
    source_path: d
    steelman: n/a
---

# qg ← LLM-보안-소스코드 블로그/레퍼런스 반영 — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**(d) ontological — EXISTING_CONTEXT로 도출.** 받은 요청("블로그+레퍼런스 레포를 qg에 반영할 수 있을지 검토")의 진짜 문제정의는 *"블로그를 qg에 적용한다"*가 아니다. 조사 결과 qg는 블로그 thesis의 핵심을 **이미 구현**하고 있다 — discovery↔verification 분리(`security-reviewer` Phase 1 + `adversarial` Phase 1.5 "assume false positive"), PoC 샌드박스(`runtime-verifier`), verifier 격리(Law 2), 모델-다양성 투표(claude+codex). 따라서 진짜 문제는:

> **qg가 이미 구현한 discovery↔verification 아키텍처 위에서, 블로그·레퍼런스가 권하는 기법 중 qg가 *아직 안 하는* gap을 식별하고, 그중 devbrew의 lightness·anti-subagent-spray·상류-소유 경계와 *양립하는 것만* 선별해 "흡수 후보"로 판정하는 평가 문서를 산출하는 것.**

진짜 goal = qg의 보안-리뷰 recall/precision을 블로그 evidence 기준으로 점검하되, devbrew 정체성(lightness, 단일 턴 CI-less 파이프라인, Law 1–3)을 훼손하지 않는 **선별 흡수 경로**를 도출.

## 2. Locked Directions

(확정·검증된 방향. frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1 (deliverable, path b)**: 1차 산출물은 **gap 평가 문서** — 블로그 6-step(threat-model → sandbox → discovery → verification → triage → patching) ↔ qg 현재 파이프라인을 매핑해 각 기법에 **이미-됨 / 흡수-권장 / 기각** verdict를 부여. 코드 변경은 후속. 대안 B(특정 기법 구체 설계+구현)·C(reference-harness 통째 포팅)는 기각(§5).
- **LD2 (scale-up 취급, path b, steelman defended)**: 블로그의 scale-up 권고(codebase partition + 병렬 discovery, multi-vote N>2)는 **보안 load-bearing carve-out**으로 다룬다 — anti-spray 기계적 자동기각도, 무비판 채택도 아닌 **evidence-weighted 개별 판단**. 단 steelman 4논거(2-source 충분성·단일턴 비용·transfer-validity·creep 위험)가 각 scale-up gap을 **흡수 후보로 인정받으려면 넘어야 할 REJECT 증명책임 bar**가 된다(§4).
- **LD3 (threat-model 경계, path d)**: threat-model 단계는 **기존 spec-as-truth 활용 심화만** qg 범위로 평가한다 — qg가 `discover-spec.sh`로 *이미 받는* spec을 threat-model 신호로 더 잘 쓰는가(예: triage/severity에 spec의 위협 맥락 주입; 블로그가 severity inflation 해법으로 지목). 새 threat-model *stage 신설*은 devbrew 경계상 상류(spec-distill/writing-plans) 소유라 평가 대상에서 제외.

## 3. External Landscape

(prior-art / 기존 해결책. **각 항목 출처 URL 필수** + [취함|피함|중립] + 이유.)

- **블로그 thesis — discovery(recall)↔verification(precision) 분리, 병목은 verify/triage/patch** — https://claude.com/blog/using-llms-to-secure-source-code — **[취함]** — qg가 이미 구현(security-reviewer + adversarial). 평가의 골격 프레임워크로 채택.
- **adversarial verifier가 non-exploitable findings 절반 감소** — https://claude.com/blog/using-llms-to-secure-source-code — **[취함]** — qg `adversarial.md`(Phase 1.5)가 이미 수행; 이 evidence가 그 설계의 정당성을 사후 강화.
- **PoC/test-bed/live system = "biggest efficacy lever"** — https://claude.com/blog/using-llms-to-secure-source-code — **[취함]** — qg `runtime-verifier` 샌드박스가 이미 PoC 실행 영역을 점유. "이미-됨" verdict 후보.
- **well-defined threat model → findings 90% exploitable; threat model을 triage에도 주입** — https://claude.com/blog/using-llms-to-secure-source-code — **[중립]** — LD3대로 *기존 spec 활용 심화*로만 한정 평가(새 stage 제외).
- **과거 CVE 패턴 ingest = cheat-code** — https://claude.com/blog/using-llms-to-secure-source-code — **[중립]** — qg 미보유. "흡수-권장" 후보지만 미평가(§6 OQ).
- **variant-search(fix 후 call-site + vulnerability-class 레벨)** — https://claude.com/blog/using-llms-to-secure-source-code — **[중립]** — qg 미보유, 경량 흡수 후보(scale-up 아님 → carve-out 무관).
- **anthropics/defending-code-reference-harness (threat-model/vuln-scan/triage/patch skills)** — https://github.com/anthropics/defending-code-reference-harness — **[중립]** — 통째 포팅(C)은 기각이나, *패턴 참조용 deep-read* 대상(§6 OQ로 깊이 미정).
- **anthropics/claude-code-security-review (GitHub Action)** — https://github.com/anthropics/claude-code-security-review — **[피함]** — CI-time PR-gate deployment model. qg는 단일 턴 CI-less라 deployment 불일치(§6 OQ로 경계 확인).
- **scale-up: partition + 병렬 discovery, multi-vote N>2** — https://claude.com/blog/using-llms-to-secure-source-code — **[피함]** — steelman defended(§4); REJECT bar 통과 시에만 재고.

## 4. Skepticism Log

(의심 triggered 방향: steelman-builder 대안 verbatim + 웹근거 URL + verdict. conducting-interview 약화·편집 금지(AC5).)

**의심 방향**: "보안 load-bearing 카브아웃으로 scale-up(partition 병렬 discovery + multi-vote N>2) gap을 qg 흡수 후보로 인정한다" — **trigger**: anti-subagent-spray + harness-lightness 충돌.

- **steelman 대안 (verbatim)**: "qg는 scale-up(partition 병렬 discovery, multi-vote N>2)을 흡수하지 말아야 한다 — lightness/anti-spray가 보안 영역에서도 이겨야 하며, 현재 2-source(claude+codex) 다양성은 이미 multi-vote의 핵심 이득을 감당할 수 있는 최소 충분 구조다." — https://arxiv.org/pdf/2512.21352 — **verdict: defended**

steelman 4논거 (verbatim 요지): ①2-source가 모델-다양성 핵심 이득 이미 취함, 동종 N-fan-out은 diminishing returns ②partition은 단일턴서 3–10x 지연·4–220x 토큰+state격리/경계미탐 ③블로그 evidence는 전담팀·전용인프라 맥락 → transfer-validity 실패 ④anti-spray/lightness는 load-bearing 예외 불인정, 구조적 escape hatch가 이미 보안 역할 → N-vote는 중복 투자.

웹근거 URL (5, verbatim):

> https://arxiv.org/pdf/2512.21352 — 위원회 에이전트 추가 시 +14.9pp→+13.5pp→+11.2pp diminishing returns
> https://online.stevens.edu/blog/hidden-economics-ai-agents-token-costs-latency/ — 멀티에이전트 토큰 4–220x, 지연 3–10x
> https://arxiv.org/pdf/2511.21572 — BAMAS: 에이전트 수↑ → 비용 누적이 배포 핵심 제약
> https://aclanthology.org/2025.findings-acl.606.pdf — 동종 편향 공유 시 추가 표가 독립 커버리지 미제공
> https://www.augmentcode.com/guides/single-agent-vs-multi-agent-ai — 경계 불명확 보안 스캔엔 단일 에이전트가 기본값

**verdict 상세**: 사용자가 ② carve-out 프레이밍 유지(LD2). steelman은 프레이밍을 반박하지 못했고, 그 4논거+5 URL은 평가 문서에서 scale-up gap의 **REJECT 증명책임 bar/기각사유 근거**로 흡수됨.

## 5. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.)

- **deliverable B — 특정 기법 1–3개 구체 반영 설계+구현** → 버림: qg가 이미 ~80% 정렬돼 *무엇이 진짜 gap인지* 평가 없이 구현하면 헛수고 위험. 평가(A)가 B의 입력이 되어야 함(LD1).
- **deliverable C — reference-harness skills 통째 포팅(새 플러그인/qg 흡수)** → 버림: 최대 작업량 + devbrew 철학(lightness, 단일턴) 충돌 리스크. qg와 deployment model·아키텍처 불일치.
- **threat-model (ii) devbrew 전체 책임배치 재검토** → 버림: qg+spec-distill 경계 재설계는 범위·작업량 과대, 다수 플러그인 동시 변경(LD3).
- **threat-model (iii) 완전 제외** → 버림: spec-as-truth를 threat-model 신호로 *더 잘 쓰는* 여지(triage/severity 주입)는 qg 범위 안 실익이라 완전 배제는 손실(LD3은 절충안 (i) 채택).
- **scale-up 흡수 입장** → steelman 후 **defended(전환 아님)**: 폐기가 아니라 carve-out 유지하되 REJECT bar 강화(§4). [전환된 방향 없음 — 이 항목은 defend로 기록.]

## 6. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- **OQ1 (평가 문서 깊이)**: 문서가 순수 descriptive(현황 매핑+verdict)인가, 아니면 "흡수-권장" gap에 대해 구현 스케치까지 담아 후속 B안의 직접 입력이 되는가? brainstorming에서 결정.
- **OQ2 (레퍼런스 레포 deep-read 깊이)**: `defending-code-reference-harness`를 블로그 요약 수준으로 볼지, 실제 skill 구현(threat-model/vuln-scan/triage/patch)까지 정독할지. 사용자가 "레퍼런스 레포들을"이라 명시 → 최소 구조-수준 정독은 필요, 어느 skill까지인지 미정.
- **OQ3 (흡수-권장 gap의 우선순위)**: 미평가 흡수 후보(과거-CVE ingest, variant-search, spec→triage 위협맥락 주입) 중 실익·경량성 기준 우선순위. 평가 과정에서 산출.
- **OQ4 (CI-time 도구 경계)**: `claude-code-security-review`(GitHub Action, CI-time PR-gate)는 qg(단일 턴 CI-less)와 deployment model이 달라 평가 포함 여부 모호 — 별도 surface로 둘지, 평가에서 "out-of-deployment-scope"로 명시 제외할지.
- **OQ5 (평가 문서 거처)**: 일회성 분석인지, `docs/`에 tracked artifact(예: `docs/philosophy/` 또는 qg README 참조)로 남길지.

## 7. Concrete Next Action

superpowers 있음 → 이 brief를 context로 **`superpowers:brainstorming` 호출**하여 해답공간(`-design.md`)을 설계한다. brainstorming은 LD1–LD3을 기정사실로 받고, §6 Open Questions를 해소하며, "gap 평가 문서"의 구체 구조(블로그 6-step별 verdict 표 + scale-up gap의 REJECT 근거 + 흡수-권장 gap의 경량 흡수 경로)를 산출한다. 그 후 spec-reviewer(Law 2) 검증 → writing-plans.
