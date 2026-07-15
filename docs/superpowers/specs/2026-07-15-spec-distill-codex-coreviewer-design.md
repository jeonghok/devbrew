---
name: spec-distill-codex-coreviewer
type: design-doc
created_at: 2026-07-15
revised_at: 2026-07-15
status: draft (review round 4 반영 — verdict 회수 계층: Status 라인 독립 추출 + both-degraded fail-safe; fc2ef911 해소 확인)
approach: "A — 전용 design-doc codex 경로 + detect_codex vendor"
plugin: spec-distill
version_bump: "0.19.3 → 0.20.0 (minor — 새 review surface)"
implementation: "subagent-driven (TDD)"
---

# spec-distill codex co-reviewer — Design (Approach A)

> **model diversity를 design-doc 리뷰로 이식한다.** quality-gates가 code-review에서
> codex로 얻는 "Claude-only가 놓친 fail-open 포착"을, spec-distill의 Phase 3 design-doc
> 리뷰에 병렬 독립 co-reviewer로 추가한다. codex의 read-only 샌드박스가 Law 2를 구조적으로
> 보장하고, 두 리뷰어는 리뷰 pass 수준에서 상호 blind이며, 보수적 병합으로 codex가
> Claude의 approved를 뒤집을 수 있다.

이 설계는 새 원칙을 도입하지 않는다 — 기존 quality-gates codex 패턴(model diversity + graceful
degradation + read-only 샌드박스 Law 2)을 spec-distill의 단일-리뷰어 Phase 3에 확장한다
(devbrew design-lightness: 신규 P# 없이 기존 원칙 흡수). 핵심 비대칭은 리뷰 대상이 code diff가
아니라 **design doc 자체**라는 점이며, 이 때문에 qg의 `run_codex_reviewer.sh`(diff+AC 모델)를
그대로 재사용하면 `discover-spec.sh`가 리뷰 대상 문서 자신을 AC로 주입하는 순환이 발생한다 —
전용 design-doc 경로가 이 footgun을 구조적으로 회피한다.

## 목차

- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture & Data Flow](#5-architecture--data-flow)
- [6. Components](#6-components)
- [7. Verdict 유도 + 보수적 병합 (load-bearing)](#7-verdict-유도--보수적-병합-load-bearing)
- [8. issue_history 원장 통합](#8-issue_history-원장-통합)
- [9. Error Handling & Degradation](#9-error-handling--degradation)
- [10. Law 준수](#10-law-준수)
- [11. Acceptance Criteria](#11-acceptance-criteria)
- [12. Files to Modify](#12-files-to-modify)
- [13. Verification Plan](#13-verification-plan)
- [14. Rejected Alternatives](#14-rejected-alternatives)
- [15. Open Questions](#15-open-questions)
- [16. Metadata](#16-metadata)
- [Handoff Context](#handoff-context)

## 1. Context / Why

spec-distill의 Phase 3(`reviewing-spec` skill)는 brainstorming이 산출한 `-design.md`를
**단일 Claude reviewer**(`spec-reviewer` agent, sonnet, read-only)로 adversarial 리뷰한다.
verdict(approved/needs_revise/needs_interview)를 결정론 routing table에 투입해 다음 phase를
결정한다.

quality-gates는 code-review에서 codex를 병렬 리뷰어로 dispatch해왔고, codex의 model diversity가
Claude-only 리뷰어 다수가 놓친 **fail-open 버그를 반복적으로 단독 적발**한 실증 이력이 축적돼
있다(보안-critical 게이트에서 codex 독립 리뷰가 load-bearing). spec-distill의 design-doc 리뷰는
현재 이 diversity가 없어, Claude persona의 사각지대가 그대로 리뷰를 탈출할 수 있다.

이 설계는 codex를 spec-distill Phase 3의 **병렬 독립 co-reviewer**로 추가해 그 사각지대를
줄인다. 리뷰 대상이 diff가 아니라 design doc 자체이므로, qg의 diff+AC 기계장치를 그대로 쓰지
않고 design-doc 전용 경로를 만든다.

## 2. Goals

- **G1**: `reviewing-spec` Phase 3가 Claude spec-reviewer와 나란히 codex를 병렬 dispatch해,
  같은 design doc을 독립적으로 리뷰하고 두 결과를 하나의 verdict로 병합한다.
- **G2**: 병합은 **보수적** — precedence `needs_interview > needs_revise > approved`에서 가장
  심각한 쪽이 이긴다. codex가 Claude의 approved를 needs_revise로 뒤집을 수 있다(fail-open 포착).
- **G3**: codex findings가 stagnation `issue_history` 원장에 통합돼, codex 반복 이슈도
  per-issue stagnation(`raised_count >= 3 AND dismissed_by_user == 0`)으로 포착된다.
- **G4**: codex 부재 또는 실패 시 Claude-only로 **loud degrade**(fail-open도 spurious-block도
  아님) — 사용자가 diversity 손실을 출력에서 인지한다.
- **G5**: 플러그인 self-contained — quality-gates에 cross-plugin 의존 없이 필요한 스크립트를
  vendor하고 devbrew의 "silent coupling은 버그" 원칙을 지킨다.

## 3. Non-goals

- **NG1**: codex는 `needs_interview`를 트리거하지 **않는다**. "사용자 의도가 약함"은 대화 맥락을
  가진 Claude reviewer의 판단축 — codex는 문서 자체의 revise 축(approved↔needs_revise)만 담당.
- **NG2**: codex 전용 re-review 루프 가드를 **새로 만들지 않는다**. 기존 re-review cap(5) +
  round-level stagnation이 codex-driven 루프도 bound한다(harness-lightness).
- **NG3**: quality-gates에 대한 **cross-plugin 런타임 의존 없음** — 필요한 스크립트는 vendor.
- **NG4**: codex를 Claude subagent(`agents/*.md`)로 **감싸지 않는다**. codex는 외부 CLI이며,
  qg는 이미 agent 방식에서 스크립트 방식으로 마이그레이션했다. shell-out만 하는 agent는 무의미한
  indirection.
- **NG5**: interview stage·web research·conducting-interview·brief 검증은 **불변**. 이 변경은
  Phase 3(`reviewing-spec` design-doc 리뷰)에만 국한된다.
- **NG6**: 두 리뷰어를 리뷰 pass에서 상호 통지하지 **않는다**(shared-premise가 리뷰어를 눈멀게
  함). 통합은 오직 orchestrator-side.

## 4. Constraints

- **C1 (Law 2 구조적 분리)**: codex는 `codex exec -s read-only` OS 샌드박스에서 실행돼 working
  tree에 write 불가. Claude `spec-reviewer`는 disallowedTools로 write 차단. 두 리뷰어 모두
  write-denied.
- **C2 (Law 1 결정론)**: routing table·병합 precedence·issue_id 계산 모두 결정론 — prose 판단
  금지. 병합 규칙은 orchestrator가 기계적으로 적용.
- **C3 (순환 AC-주입 회피)**: codex 경로는 `discover-spec.sh`를 호출하지 않는다. 리뷰 대상
  design doc이 `docs/superpowers/specs/` 하위에 있어, AC 자동 주입은 리뷰 대상 자신을 컨텍스트로
  주입하는 순환을 만든다.
- **C4 (graceful degradation + loud logging)**: codex 부재/실패는 capability를 downgrade하되
  crash하지 않고, 사용자가 출력에서 fallback을 인지한다.
- **C5 (kill switch)**: 플러그인 전체(`DEVBREW_DISABLE_SPEC_DISTILL=1`) + codex 전용
  (`DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`) 두 개. 어떤 경로도 kill switch 존중을 거부 못 함.
- **C6 (버전 bump)**: plugin.json 0.19.3 → 0.20.0(minor — 새 review surface) + CHANGELOG +
  README 동기화(같은 PR).
- **C7 (mktemp footgun 가드)**: scratch dir 대입은 trap arm 전에 `|| exit 1` — `cd ""`
  repo-삭제 footgun 방지.
- **C8 (verbatim 저장 — [fc2ef911] 정신 재봉쇄)**: orchestrator는 spec-reviewer subagent의 raw
  출력을 `--claude-output` 파일에 **그대로(verbatim)** 저장해야 한다 — orchestrating 세션이 요약·바꿔쓰기
  하는 중간 단계 금지. 안 그러면 전사 단계가 한 레벨 위(orchestrator)로 재도입돼 [fc2ef911]의 정신이
  조용히 재개통된다(letter는 닫혀도 spirit 재오픈). 파싱·id 계산은 merge_review가 그 verbatim 파일에서
  수행.

## 5. Architecture & Data Flow

현행:

```
reviewing-spec SKILL
  → spec-reviewer(Claude) dispatch
  → Status/Issues/Stagnation 파싱
  → 결정론 routing table
  → 다음 phase
```

신규 (같은 라운드 안에서):

아래 `[·]` 라벨은 **실행 단계이지 순서가 아니다**(⟦detect⟧·⟦review-claude⟧·⟦review-codex⟧는 상호
독립, order-agnostic — 아래 "병렬" 정의 참조). ⟦merge⟧는 앞 세 단계가 모두 끝난 뒤 실행되는 유일한
barrier다.

```
reviewing-spec SKILL
 ├─ ⟦detect⟧        detect_codex.sh (vendored)     → codex_available: true|false + skip_reason
 ├─ ⟦review-claude⟧ spec-reviewer(Claude) dispatch → sentinel-fenced block: verdict +
 │                  (codex 존재 blind — 통보 없음)      issue별 (category, target_section, severity)
 ├─ ⟦review-codex⟧  codex_available면:
 │                  run_spec_codex_reviewer.sh <doc> <proj> <out.yaml>
 │                    → codex findings YAML: {category, severity, confidence, summary, target_section}
 ├─ ⟦merge⟧ (barrier) merge_review.py — 결정론 merge/ledger 엔진 (단일 검증 가능 경계):
 │                  입력: --claude-output <spec-reviewer 출력> --codex-yaml <path>
 │                        --history <state>   ← 양쪽을 스크립트가 결정론 파싱(LLM 전사 없음)
 │                  출력: combined_verdict + 갱신 issue_history(union raised_count)
 │                        + stagnation flags(per-issue·round-level) + codex_degraded+advisory
 │                  (내부: 양쪽 파싱 → codex_verdict 유도 → 보수적 병합 →
 │                         issue_id(compute_issue_id) → 원장 union → **통합-원장 stagnation 스캔**)
 ├─ ⟦route⟧          기존 routing table에 combined_verdict + stagnation flags 투입 (table 불변)
 └─ 출력: Claude + codex issues를 source 라벨(claude|codex|both)과 함께 surface
```

**"병렬"의 정의 (모호성 제거)**: 병렬 = **논리적 상호 독립(order-agnostic)** 을 뜻한다. codex(Bash,
동기)와 spec-reviewer(Agent, async)는 동시 진행 *가능*하나 정합성은 순서 무관 — 구현은 동시 dispatch든
순차든 택일 가능하며 결과는 불변. **둘 다 완료된 뒤** merge_review.py(⟦merge⟧ barrier)로 병합한다(같은
턴 동시 tool-dispatch를 강제하지 않음).

**핵심 설계 결정**:

1. **routing table 불변** — 병합된 단일 verdict + stagnation flags만 소비. 기존 cap(5) 재사용.
2. **리뷰 pass 상호 blind** — `spec-reviewer.md`는 codex 존재를 통보받지 않음. 병합·stagnation 판정은
   오직 merge_review.py(orchestrator-side).
3. **결정론 연산은 스크립트 경계로** — codex_verdict 유도·보수적 병합·issue_id·원장 union·stagnation
   스캔은 전부 merge_review.py가 소유(C2: prose 암산 금지 → 검증 가능 CLI 경계). SKILL.md는 스크립트를
   호출하고 그 출력을 routing table에 투입할 뿐.
4. **degrade 불변식** — codex 부재/실패면 combined = claude_verdict (fail-open으로 통과시키지도,
   infra 실패로 spurious block하지도 않음) + loud advisory.

## 6. Components

| # | 파일 | 종류 | Purpose / Interface / Deps |
|---|---|---|---|
| 1 | `scripts/detect_codex.sh` | vendor+적응 | 환경 감지 YAML emit. **kill switch var를 `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`로 교체**(qg의 `DEVBREW_DISABLE_QG_CODEX` 아님). recursion guard/설치/auth/timeout/bad-version 유지. `→ codex_available: bool + skip_reason`. deps: codex(optional), timeout/gtimeout |
| 2 | `scripts/build_spec_codex_prompt.py` | 신규 | design-doc **경로만** 받아(inline 금지 — injection 안전) **6개 판단형 category**(placeholder/ambiguity/scope_creep/approaches_comparison/isolation/testing — handoff_incomplete는 기계적 검사라 codex 범위 밖) 체크리스트 임베드 프롬프트를 stdout. 각 finding에 `category` + `target_section`(anchor) + `severity`(**spec-distill vocab `block`\|`high`\|`medium` — qg의 CRITICAL/IMPORTANT/SUGGESTION 아님, §7 병합 vocab 일치**) + confidence/summary/proposed_fix를 fenced JSON으로 요청. `build_spec_codex_prompt.py <design_doc_file>`. deps: python3 |
| 3 | `scripts/run_spec_codex_reviewer.sh` | 신규 | 독립 codex subprocess. `run_spec_codex_reviewer.sh <doc_path> <project_dir> <out_yaml>`. cd proj → mktemp scratch(C7 가드) → prompt build(#2) → `codex exec "$(cat prompt)" -C proj -s read-only -c model_reasoning_effort=medium --json < /dev/null` → exit capture → findings_to_yaml(#4). **discover-spec.sh AC 주입 없음**(C3). deps: codex, #2, #4 |
| 4 | `scripts/codex_findings_to_yaml.py` | vendor+적응 | JSONL→findings YAML. emit 키셋에 **`category`, `target_section` 추가**(design vocab). 하드닝된 3단 fallback(auth/malformed/missing) + last-fenced-block 안티인젝션 유지. iface: stdin JSONL, `--stderr-file`, `--meta-override-*` |
| 5 | `scripts/compute_issue_id.py` | 신규 | `(category, target_section) → sha256_short`. 두 리뷰어 이슈 모두에 적용(중앙화). CLI: `compute_issue_id.py <category> <target_section>` → stdout에 sha256_short 1줄(standalone-testable). merge_review.py(#6)가 issue별로 호출. deps: python3 hashlib |
| 6 | `scripts/merge_review.py` | 신규 | **결정론 merge/ledger 엔진** — §7·§8의 모든 결정론 연산을 소유하는 단일 검증 가능 경계(C2). CLI: `merge_review.py --claude-output <path> --codex-yaml <path> --history <state_path>`. **양쪽 리뷰어 출력을 스크립트가 결정론 파싱**(LLM 전사 없음, [fc2ef911] 봉쇄), **codex 파서와 진짜 대칭인 하드닝**([bc365411]): **verdict와 issue list를 분리 추출**(#8): (i-a) **verdict** ← spec-reviewer 출력의 top-level `**Status:** <verdict>` 라인 정규식(sentinel block과 독립 — block이 죽어도 회수 가능); (i-b) **issue list** ← **sentinel-fenced block**(` ```spec-review-issues `, #8)에서 issue별 `(category, target_section, severity, message)` 파싱 — **리뷰 대상 design doc이 자체 fenced block을 다수 포함**하므로(예: ```yaml frontmatter), sentinel 없는 임의 fence는 무시하고 **sentinel 블록만, 그중 마지막 것**을 선택(codex `last-fenced-block` 안티인젝션과 대칭 — 에코/인젝션된 블록 방어); (ii) codex 쪽은 `codex_findings_to_yaml.py`(#4) 출력을 파싱. collision-sensitive 값이 어느 쪽도 prose 암산을 거치지 않음. **verdict 회수 계층(결정론, §9 매트릭스 근거)**: 1) sentinel block OK → verdict=(i-a), issues=(i-b); 2) sentinel block 부재/malformed → `claude_degraded=true` + verdict는 여전히 (i-a)에서 회수 + 그 라운드 Claude issue 원장 skip + advisory; 3) (i-a) `**Status:**` 라인마저 부재/malformed → `claude_verdict_unrecoverable=true`: codex verdict 있으면 combined=codex_verdict 단독 + advisory; 4) **양쪽 다 회수 불가**(claude verdict 불능 AND codex_degraded/unavailable) → combined=`needs_revise` **fail-safe(비-approve)** + loud "review indeterminate" advisory + 원장 미갱신(§9 both-degraded 행). 출력(**stdout YAML** — 형제 스크립트 #1/#4와 일관): `combined_verdict` + 갱신 `issue_history`(union raised_count) + `stagnation`(per-issue `raised_count>=3 AND dismissed_by_user==0` + round-level) + `codex_degraded`(bool) + `claude_degraded`(bool) + `claude_verdict_unrecoverable`(bool) + advisory. 내부: (a) 양쪽 파싱(verdict/issue 분리 + sentinel 선택), (b) codex_verdict 유도(severity→verdict), (c) 보수적 병합(max precedence)/degrade 계층, (d) issue_id(compute_issue_id 호출), (e) 원장 union increment, (f) **통합-원장 stagnation 스캔**. deps: python3, #5 |
| 7 | `skills/reviewing-spec/SKILL.md` | 편집 | ⟦detect⟧/⟦review-codex⟧/⟦merge⟧ 단계 추가(**merge_review.py 호출**). routing table은 merge_review 출력(combined_verdict + stagnation flags)을 투입 — **기존 "Stagnation detection" 절도 수정**: Claude self-report 단독이 아니라 merge_review의 통합-원장 스캔 결과를 escalate 조건으로 사용(codex-only 반복 이슈 포착, [6647ebfa] fail-open 봉쇄). cap(5) 로직 불변. degrade advisory 추가 |
| 8 | `agents/spec-reviewer.md` | 편집 | **두 산출물을 emit(verdict와 issue list를 분리, [bc365411] spirit 봉쇄)**: (A) **top-level `**Status:** <verdict>` 라인**(기존 포맷 유지 — verdict의 정본 소스, sentinel block과 독립) + (B) **sentinel-fenced block**(info-string ` ```spec-review-issues `, YAML body)으로 issue list — issue별 `category`/`target_section`/`severity`/`message`. sentinel info-string은 리뷰 대상 doc의 일반 ```yaml/```json fence와 구분돼 merge_review가 안티인젝션 선택 가능. issue_id self-report 제거(merge_review가 compute_issue_id로 계산). **verdict는 (A) 라인에서, issue list는 (B) 블록에서 독립 추출** — sentinel block이 malformed여도 verdict는 (A)에서 회수 가능. 사람 가독 요약은 두 산출물 밖에 병기 가능. "Issue ID 정의" 섹션을 compute_issue_id.py 참조로. codex 존재 blind 유지 |
| 9 | `.claude-plugin/plugin.json` | 편집 | 0.19.3 → 0.20.0 |
| 10 | `CHANGELOG.md` | 편집 | `## [0.20.0] — 2026-07-15` Added/Changed |
| 11 | `README.md` | 편집 | prerequisites(codex CLI optional + graceful) + "Principles Instantiated"에 model-diversity + kill switch 표에 `DEVBREW_DISABLE_SPEC_DISTILL_CODEX` |
| 12 | `tests/*` | 신규+편집 | §13 참조 |

**vendor 결정 근거**: qg의 4개 codex 스크립트 중 `detect_codex.sh`·`codex_findings_to_yaml.py`만
리뷰 대상과 무관해 재활용 가능. `build_codex_prompt.py`·`run_codex_reviewer.sh`는 diff+AC 모델이라
design-doc 전용으로 신규 작성. vendor는 cross-plugin silent coupling(NG3/G5)을 피한다.

## 7. Verdict 유도 + 보수적 병합 (load-bearing)

> 이 절의 모든 결정론 연산((a) 유도 + (b) 병합)은 **`merge_review.py`(§6 #6)가 소유**한다 —
> SKILL.md 프로즈를 읽는 살아있는 세션의 암산이 아니라 검증 가능 CLI 경계(C2, [fc2ef911] 반영).
> 아래 의사코드는 그 스크립트의 계약을 명세한다.

**(a) codex_verdict 결정론 유도** — `merge_review.py`가 codex YAML을 읽고:

```
if codex_available == false  OR  meta.codex_failed == true:
    codex 기여 = NONE (degraded) → combined = claude_verdict + loud advisory
else:
    severities = [f.severity for f in codex.findings]   # vocab = {block, high, medium} (§6 #2)
    if any severity in {block, high}:   codex_verdict = needs_revise
    else:                               codex_verdict = approved   (medium는 advisory surface)
```

- codex_verdict ∈ {approved, needs_revise} (NG1 — needs_interview 트리거 안 함).
- **severity vocab**: codex 프롬프트(§6 #2)가 spec-reviewer.md와 동일한 `{block, high, medium}`을
  요청하므로 이 유도 규칙의 `{block, high}` 매칭이 성립. qg의 CRITICAL/IMPORTANT/SUGGESTION vocab을
  주입하지 않는다(vocab drift 방지).
- **`block` 분기 = 의도된 defensive headroom (dead branch 아님, [98dbb215] 반영)**: codex 담당 6개
  판단형 category의 persona-기본 심각도는 `{high, medium}`이라(spec-reviewer.md design checklist:
  placeholder/ambiguity/isolation/testing=high, scope_creep/approaches_comparison=medium; block은
  handoff_incomplete 전용=codex 범위 밖), 정상 흐름에서 codex가 `block`을 자연 발생시키지 않는다.
  그럼에도 `{block, high}`에 `block`을 두는 것은 **codex가 스스로 어떤 finding을 critical로 판정해
  `severity: block`을 emit할 경우 이를 존중(needs_revise)** 하기 위함이다 — codex의 독립 판단을
  persona-기본 심각도로 상한 처리하지 않는다(model-diversity 취지). 향후 codex 범위에 block-severity
  category가 추가돼도 무변경으로 동작. 이 headroom은 의도적이며 vocab 정합성 위반이 아니다.
- **`confidence`는 verdict 수식에서 의도적으로 제외 (advisory-surface 전용)**: codex 프롬프트(§6 #2)가
  `confidence`를 요청하나, verdict 유도는 `severity`만 본다. confidence는 사용자에게 finding과 함께
  표시(surface)돼 우선순위 판단을 돕는 advisory 신호일 뿐, needs_revise/approved 결정에 들어가지
  않는다 — FP 완충은 confidence 임계값이 아니라 re-review cap(5)+stagnation에 위임(§7c, NG2의
  harness-lightness). 이 제외는 의도적이며, confidence 기반 게이팅은 별도 PR 사안.

**(b) 보수적 병합** — precedence `needs_interview > needs_revise > approved`:

```
combined_verdict = 가장 심각한 값 (claude_verdict, codex_verdict)
```

| claude | codex | combined | 의미 |
|---|---|---|---|
| approved | needs_revise | **needs_revise** | codex가 approved를 뒤집음 (fail-open 포착 — 핵심 가치) |
| needs_revise | approved | needs_revise | Claude가 이미 block |
| needs_interview | approved | needs_interview | Claude의 의도축 판단이 이김 |
| approved | approved | approved | 둘 다 clean → 통과 |

**(c) FP backstop**: codex FP로 인한 과도 revise 루프는 기존 re-review cap(5) + round-level
stagnation이 bound — 5회 도달 시 [5] Human Gate로 forced escalate(NG2).

## 8. issue_history 원장 통합

**issue_id 부여**: 기존 `issue_id = sha256_short(category + ":" + target_section)`를 codex에도
적용. codex 프롬프트(#2)가 각 finding에 `category`(6-cat vocab) + `target_section`(anchor)를
emit → orchestrator가 `compute_issue_id.py`로 id 계산.

**issue_id 중앙화 (integrity 필수)**: 두 리뷰어 이슈가 같은 `(category, target_section)`일 때 id가
실제로 충돌해야 corroboration·cross-round 매칭이 성립한다. LLM in-head sha256은 신뢰 불가하므로,
각 리뷰어는 `(category, target_section)`을 **구조적으로 emit**(Claude=fenced YAML block #8, codex=fenced
JSON #4)하고, **merge_review.py가 양쪽을 결정론 파싱**해 `compute_issue_id`에 넘긴다 — id에 들어가는
collision-sensitive 값이 어느 쪽도 LLM 전사(prose 암산)를 거치지 않는다([fc2ef911] 봉쇄, codex 파서와
대칭). 이는 부수적으로 현행 Claude-only stagnation의 in-head 해싱 신뢰성도 강화한다.

**원장 병합 semantics** (라운드마다):

```
round_ids = union(claude_issue_ids, codex_issue_ids)
각 id: raised_count += 1        ← 라운드당 1회 (두 리뷰어 동시 flag = corroboration, 2배 아님)
issue.source = claude | codex | both
dismissed_by_user 는 출처 무관 (P17 — 사용자 기각은 codex 이슈에도 stagnation 제외)
```

→ per-issue stagnation(`raised_count >= 3 AND dismissed_by_user == 0`)이 codex 반복 이슈도 포착.

**통합-원장 stagnation 스캔 (기존 트리거 교체 — [6647ebfa] fail-open 봉쇄)**: 현행 SKILL.md의
"Stagnation detection" 절은 stagnation escalate를 **spec-reviewer(Claude)가 `Stagnation_signal:
true`를 self-report할 때만** 발동한다. 그런데 blind-across-rounds(아래)로 Claude는 codex가 과거에
올린 이슈를 못 보므로, **codex-only로 3회 이상 반복된 이슈에 대해 Claude는 Stagnation_signal을
self-report할 근거가 없다** — Claude 시야에 그 이슈가 애초에 없으므로 반복도 인지 못 한다. Claude
self-report 단독에 의존하면 G3의 핵심(codex 반복 이슈 escalate)이 조용히 무력화되는 fail-open이다.

→ **수정**: `merge_review.py`가 매 라운드 **통합 원장 위에서 독립적으로** per-issue
(`raised_count >= 3 AND dismissed_by_user == 0`) + round-level(새 issue_id 無 + 미해결 잔존)
stagnation을 스캔해 `stagnation` flag를 emit한다. SKILL.md "Stagnation detection" 절은 이 flag를
escalate 조건으로 사용하도록 수정된다(Claude self-report는 보조 신호로 남되 유일 트리거가 아님).
이 통합-스캔 로직은 §6 #6·#7·§12 Files에 명시된다(설계-구현 연결 끊김 방지).

**blind-across-rounds**: 통합 원장은 orchestrator-side 상태. 각 리뷰어에게는 **same-origin
history만** 전달(Claude는 codex 과거 findings를 못 봄). stagnation 판정은 merge_review.py가 통합
원장 위에서 수행. "blind"는 리뷰 pass 수준 불변식이고 원장은 orchestrator 상태 — 양립(NG6).

## 9. Error Handling & Degradation

**Degradation matrix** (fail-open도 spurious-block도 아닌 loud degrade):

| 조건 | 신호 | orchestrator 동작 |
|---|---|---|
| kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1` | available=false / kill_switch | codex skip, loud advisory, combined=claude |
| 미설치/auth 없음/bad version/timeout bin 없음/recursion | available=false + skip_reason | 동일 |
| codex 실행됐으나 exit≠0 / malformed / auth-in-stderr | meta.codex_failed=true | **degrade to claude, loud advisory** (block 아님, silent pass 아님) |
| codex OK, findings=[] | codex_failed=false | codex_verdict=approved |
| codex OK, block/high 있음 | codex_failed=false | codex_verdict=needs_revise |
| **Claude sentinel block 부재/malformed, `**Status:**` 라인은 OK** ([bc365411]) | `claude_degraded=true` | **verdict를 `**Status:**` 라인에서 회수 + 그 라운드 Claude issue 원장 skip + loud advisory** (codex 병합 정상; block도 silent pass도 아님) |
| **Claude `**Status:**` 라인마저 부재/malformed, codex는 OK** | `claude_verdict_unrecoverable=true` | combined=codex_verdict 단독 + loud advisory (원장은 codex issue만) |
| **양쪽 다 회수 불가** (claude verdict 불능 AND codex_degraded/unavailable) | `claude_verdict_unrecoverable=true` + `codex_degraded`/unavailable | combined=`needs_revise` **fail-safe(비-approve)** + loud "review indeterminate" advisory + 원장 미갱신 (fail-open으로 approve 금지, crash 금지) |

**핵심 불변식**: codex 인프라 실패는 Claude-only로 degrade + reason 명시 loud advisory —
fail-open(조용히 통과)도 fail-closed(infra 실패로 spurious block)도 금지.

**loud advisory 형식**:

- skip: `[spec-distill v0.20.0] codex co-review SKIPPED (reason: <skip_reason>) — Claude-only, model diversity 없음 (degraded).`
- fail: `[spec-distill v0.20.0] codex co-review FAILED (reason: <meta.reason>, exit: <code>) — Claude-only (degraded). combined = Claude verdict.`

**footgun 가드**(C7): mktemp scratch 대입 `|| exit 1` (trap arm 전).

## 10. Law 준수

- **Law 1 (Clarity/결정론)**: routing table + 병합 precedence + issue_id helper 전부 결정론.
  리뷰어는 구조적 체크를 silent skip 불가.
- **Law 2 (Writer ≠ Reviewer)**: codex `-s read-only` OS 샌드박스(구조적 write 불가) + Claude
  reviewer disallowedTools. 둘 다 write-denied. 리뷰 pass 상호 blind. orchestrator(author
  가능)가 invoke하나 두 리뷰어의 *판정*은 author와 독립(codex=별 프로세스/모델, Claude=별
  subagent context).
- **Law 3 (Compounding)**: README "Principles Instantiated"에 model-diversity 추가. codex가
  Claude persona가 반복해 놓치는 결함류를 잡으면 → `spec-reviewer.md` 체크리스트 편집(persona =
  보안-민감 코드). 그 commit이 compounding 이벤트.

## 11. Acceptance Criteria

- **AC1**: `detect_codex.sh`(vendored)가 `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`에서
  `codex_available: false`, `skip_reason: kill_switch`를 emit. (qg var `DEVBREW_DISABLE_QG_CODEX`는
  이 스크립트에 영향 없음 — 회귀락.)
- **AC2**: `detect_codex.sh`가 미설치/auth 없음/bad version/timeout bin 없음/recursion 각
  조건에서 해당 skip_reason으로 `codex_available: false` emit, 항상 exit 0.
- **AC3**: `build_spec_codex_prompt.py`가 6개 판단형 category(placeholder/ambiguity/scope_creep/
  approaches_comparison/isolation/testing)를 모두 프롬프트에 포함하고, 각 finding에 `category` +
  `target_section` + `severity`(**vocab `block`/`high`/`medium` — qg의
  CRITICAL/IMPORTANT/SUGGESTION 부재 회귀락**) emit을 요청한다. (handoff_incomplete는 codex 범위
  밖 — 기계적 substring/구조 검사로 기존 경로가 담당, §6 #2 참조.)
- **AC4**: `build_spec_codex_prompt.py`는 design-doc를 **파일 경로로만** 받고 inline 컨텐츠를
  argv/stdin으로 받지 않는다(injection 안전).
- **AC5**: `run_spec_codex_reviewer.sh`는 `discover-spec.sh`를 호출하지 않는다(C3 — grep으로
  스크립트 본문 검증).
- **AC6**: `run_spec_codex_reviewer.sh`의 scratch dir 대입은 trap arm 전에 `|| exit 1` 가드된다
  (C7).
- **AC7**: `codex_findings_to_yaml.py`(적응)의 emit 키셋이 `category`, `target_section`을 포함하고,
  auth/malformed/missing 3단 fallback + last-fenced-block 선택을 보존한다.
- **AC8**: `compute_issue_id.py`가 결정론 — 동일 `(category, target_section)`는 동일 id, 다른
  section은 다른 id.
- **AC9**: `merge_review.py`가 codex needs_revise + claude approved를 combined=needs_revise로
  병합한다(보수적 precedence 표 전 행 — 스크립트에 대한 behavioral 테스트로 검증).
- **AC9b (대칭 결정론 파싱 — [fc2ef911] 봉쇄)**: `merge_review.py`가 `--claude-output`(spec-reviewer의
  sentinel-fenced block)과 `--codex-yaml` **양쪽을 스크립트로 파싱**해 issue별 `(category, target_section)`을
  추출한다 — 어느 쪽 값도 SKILL.md prose의 LLM 전사를 거치지 않는다(codex 파서 #4와 대칭). fixture:
  sentinel block에서 파싱한 category/target_section이 compute_issue_id 입력과 byte-identical.
- **AC9c (Claude-side 안티인젝션 + degrade 계층 — [bc365411] letter+spirit)**: (i) `--claude-output`이
  sentinel 없는 일반 ```yaml/```json fence를 **다수 포함**해도(리뷰 대상 doc 에코 fixture)
  merge_review는 ` ```spec-review-issues ` sentinel 블록만, **마지막 것**을 선택한다(에코/인젝션 방어,
  codex last-fenced-block과 대칭). (ii) **verdict는 issue-block과 독립 추출**(top-level `**Status:**`
  라인) — sentinel block 부재/malformed(`claude_degraded=true`)여도 verdict를 `**Status:**`에서
  회수하고 그 라운드 Claude issue만 원장 skip. (iii) `**Status:**`마저 부재/malformed
  (`claude_verdict_unrecoverable=true`) + codex OK → combined=codex_verdict 단독. (iv) **양쪽 회수
  불가** → combined=`needs_revise` fail-safe(비-approve, crash·fail-open 금지) + "indeterminate"
  advisory. fixture로 (i)~(iv) 각 분기 검증(§9 매트릭스 전 행).
- **AC10**: codex 실패(meta.codex_failed=true) 또는 부재 시 `merge_review.py`가
  combined=claude_verdict + `codex_degraded=true` + advisory를 emit — pass도 block도 아님.
- **AC11**: `merge_review.py`의 원장 union이 라운드당 issue_id별 raised_count를 1회만 증가시킨다(두
  리뷰어 동시 flag가 2배로 세지 않음).
- **AC12**: 각 리뷰어는 same-origin history만 전달받는다(Claude가 codex 과거 findings를 안 봄 —
  reviewing-spec dispatch 프롬프트 검증).
- **AC13**: plugin.json=0.20.0 + CHANGELOG `## [0.20.0]` + README kill switch 표에
  `DEVBREW_DISABLE_SPEC_DISTILL_CODEX` 존재(test_readme_sync 통과).
- **AC14 (통합-원장 stagnation — [6647ebfa] 봉쇄)**: `merge_review.py`가 **codex-only로 3회 이상
  반복된 issue_id**(Claude가 한 번도 안 올림, dismissed_by_user==0)에 대해 통합 원장 스캔으로
  `stagnation` flag를 emit한다 — Claude의 Stagnation_signal self-report 없이도. (fixture: prior
  history에 codex-origin id raised_count=2 → 이번 라운드 codex 재-raise → stagnation=true 검증.)
- **AC15 (kill-switch 상호작용)**: `DEVBREW_DISABLE_SPEC_DISTILL=1`(전역)이 켜지면 codex 경로 진입
  자체가 없다(detect/dispatch 미실행). `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`은 codex만 skip하고
  Claude 리뷰는 정상 — 둘의 독립성을 검증.
- **AC16 ('block' headroom)**: `merge_review.py`가 codex finding `severity: block`을 emit받으면
  codex_verdict=needs_revise로 존중한다(정상 6-category에서 자연 발생 안 하나 codex 자기-escalation
  존중 — dead branch 아님, [98dbb215]).

## 12. Files to Modify

**신규**:
- `plugins/spec-distill/scripts/detect_codex.sh` (vendor+적응)
- `plugins/spec-distill/scripts/build_spec_codex_prompt.py`
- `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh`
- `plugins/spec-distill/scripts/codex_findings_to_yaml.py` (vendor+적응)
- `plugins/spec-distill/scripts/compute_issue_id.py`
- `plugins/spec-distill/scripts/merge_review.py` (**결정론 merge/ledger 엔진 — §6 #6·§7·§8**)
- `plugins/spec-distill/tests/test_detect_codex.sh`
- `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh`
- `plugins/spec-distill/tests/test_codex_findings_to_yaml.py`
- `plugins/spec-distill/tests/test_compute_issue_id.py`
- `plugins/spec-distill/tests/test_merge_review.py` (**behavioral — 병합 precedence + degrade + union 1회 + 통합-원장 stagnation 스캔 + block headroom, AC9–11·14·16**)
- `plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh` (**구조적 grep-invariant — SKILL.md가 merge_review 출력을 routing table + Stagnation detection 절에 배선했는지**)
- `plugins/spec-distill/tests/mocks/mock-codex-valid-json.sh`
- `plugins/spec-distill/tests/mocks/mock-codex-exit1.sh`
- `plugins/spec-distill/tests/mocks/mock-codex-auth-stderr.sh`
- `plugins/spec-distill/tests/mocks/mock-codex-bad-json.sh`

**편집**:
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (⟦detect⟧/⟦review-codex⟧/⟦merge⟧ merge_review 호출 + **기존 "Stagnation detection" 절 수정**(통합-원장 스캔 flag를 escalate 조건으로) + degrade advisory)
- `plugins/spec-distill/agents/spec-reviewer.md` (**sentinel-fenced block** emit(category/target_section/severity/message + verdict) + Issue ID 섹션 → compute_issue_id 참조)
- `plugins/spec-distill/.claude-plugin/plugin.json` (0.20.0)
- `plugins/spec-distill/CHANGELOG.md`
- `plugins/spec-distill/README.md`
- `plugins/spec-distill/tests/test_readme_sync.sh` (codex prerequisites/kill switch 반영)
- `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh` (기존, 확장 — sentinel-fenced block emit + issue_id self-report 계약 변경 락)

**계약 변경 근거 (audit 흔적, advisory)**: `agents/spec-reviewer.md`의 output 계약 변경(issue별
`issue_id` self-report 제거 → `(category, target_section)` emit)은 **현재 리포에 이 계약을 lock하는
기존 회귀 테스트가 없다**(grep 확인). 변경 자체는 안전하나, 이 사실을 여기 남겨 향후 audit에서 "왜
회귀 없이 바뀌었나" 재조사를 줄인다. 신규 `test_reviewing_spec_codex_merge.sh`가 새 계약(merge_review
배선)을 lock한다.

## 13. Verification Plan

- **자동 (테스트)**: python은 `-m unittest`, bash는 shebang 셸로 실행.
  - `test_detect_codex.sh` — 각 skip_reason + **mutation: kill switch var명 뒤집으면 red**(이빨).
  - `test_build_spec_codex_prompt.sh` — 6 category + `(category,target_section)` 요청 +
    injection 안전. **body-unique 문구를 섹션 윈도우서 grep**(header-satisfiable 함정 회피).
  - `test_compute_issue_id.py` — 결정론 + collision + 다른 section 구분.
  - `test_codex_findings_to_yaml.py` — `category`/`target_section` 키 + fallback 3단 + 안티인젝션.
  - `test_merge_review.py` (**behavioral — 실행 코드를 exercise**) — precedence 표 전 행 +
    degrade=claude(codex 실패/부재) + 원장 union 1회 증가 + **통합-원장 stagnation 스캔**(codex-only
    3회 반복 → stagnation=true, AC14) + block headroom(AC16) + **대칭 결정론 파싱**(sentinel Claude
    block + codex YAML 양쪽에서 category/target_section 추출, compute_issue_id 입력 byte-identical,
    AC9b) + **안티인젝션**(sentinel 없는 ```yaml/```json fence 다수 포함 fixture에서 sentinel 마지막
    블록만 선택, AC9c-i) + **verdict 회수 계층 4-분기**(AC9c ii~iv: sentinel OK / sentinel malformed→
    `**Status:**` 회수+`claude_degraded` / `**Status:**`도 malformed→codex 단독+`claude_verdict_unrecoverable` /
    양쪽 회수불가→`needs_revise` fail-safe+indeterminate advisory). fixture로 Claude output(sentinel
    block + 에코 fence, 그리고 sentinel/Status 제거 변형) + codex YAML(정상/degraded) + prior history
    주입, stdout YAML 파싱 검증.
  - `test_spec_reviewer_design_checklist.sh`(기존, 확장) — spec-reviewer가 issue를 **sentinel-fenced
    block**(` ```spec-review-issues `, category/target_section/severity/message + verdict)으로
    emit하는지 + issue_id self-report를 더는 강제하지 않는지(계약 변경 락).
  - `test_reviewing_spec_codex_merge.sh` (**구조적 grep-invariant — SKILL.md 텍스트**) —
    SKILL.md가 (i) merge_review.py를 호출하고, (ii) 그 `combined_verdict`를 routing table에,
    (iii) `stagnation` flag를 "Stagnation detection" 절 escalate 조건에 배선했는지. 추가로
    **AC12(blind-across-rounds)**: ⟦review-claude⟧ dispatch가 각 리뷰어에 same-origin history만
    전달(codex-origin 이슈를 Claude 프롬프트에 안 넣음); **AC15(전역 kill switch)**:
    `DEVBREW_DISABLE_SPEC_DISTILL=1` 시 codex 경로(⟦detect⟧/⟦review-codex⟧) 미진입 + **⟦review-claude⟧
    dispatch가 어떤 codex-availability 조건문에도 중첩되지 않음**(codex kill switch가 Claude 리뷰를
    막지 않음을 텍스트로 증명, AC15 나머지 절); **C8**:
    orchestrator가 spec-reviewer raw 출력을 `--claude-output`에 요약 없이 verbatim 저장 명시. 기존
    `test_reviewing_spec_design_routing.sh`·`test_rereview_cap_consistency.sh` 선례와 동일 패턴.
    **body-unique 문구를 섹션 윈도우서 grep + mutation으로 이빨 증명**(header-satisfiable 회피).
  - `test_readme_sync.sh` — kill switch/prerequisites 동기화.
  - **AC15(codex-only kill switch)** 는 `test_detect_codex.sh`가 담당(AC1과 동일 파일) — 전역/codex-only
    독립성: 전역은 SKILL 구조(위), codex-only는 detect 스크립트.
- **수동 e2e** (writing-plans 이후 구현 완료 시): codex 설치 환경에서 실제 design doc에
  `reviewing-spec` 실행 → codex 독립 리뷰 완료·병합 확인 → codex block이 Claude approved를 뒤집는지
  관찰 → 같은 codex 이슈를 3회 미해결로 반복 시 통합-원장 stagnation escalate 관찰(AC14 e2e) →
  codex kill switch로 degrade advisory 관찰.
- **degradation 확인**: `DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`로 skip advisory, codex 미설치
  환경에서 not_installed degrade.

## 14. Rejected Alternatives

- **B — quality-gates cross-plugin 의존**: spec-distill이 qg를 prerequisite로 선언하고 qg의
  `detect_codex.sh`를 경로로 직접 호출. 중복 최소이나 `CLAUDE_PLUGIN_ROOT`가 플러그인마다 달라
  취약하고, qg 버전 drift에 spec-distill이 silent하게 깨짐. devbrew가 명시적으로 경계하는 silent
  coupling. **Rejected** (G5/NG3).
- **C — codex를 spec-distill subagent로**: `agents/spec-codex-reviewer.md`로 감싸기. codex는
  Claude agent가 아니라 외부 CLI이며, qg는 이미 `agents/codex-reviewer.md`에서 스크립트 방식으로
  마이그레이션했다. shell-out만 하는 agent는 무의미한 indirection. **Rejected** (NG4).
- **codex advisory-only 병합**: codex findings를 surface만 하고 routing은 Claude verdict만 구동.
  FP 노이즈에 안전하나 codex가 조용히 무시될 수 있어 "diversity가 fail-open을 잡는다"는 핵심 가치
  약화. **Rejected** — 보수적 병합(G2) 채택.
- **codex stagnation 원장 제외**: codex를 verdict 병합에만 쓰고 issue_history 원장 밖에 두기.
  스키마 churn을 피하나 codex 반복 이슈가 stagnation으로 안 잡힘. **Rejected** — 원장 통합(G3)
  채택, issue_id 중앙화로 integrity 확보.

## 15. Open Questions

- **OQ1**: `codex_findings_to_yaml.py`의 `line` 키를 design-doc 리뷰에서 유지할지(문서엔 line이
  code보다 덜 의미 있음) vs `target_section` anchor로 대체할지. writing-plans에서 확정 — 잠정:
  둘 다 emit(anchor는 issue_id용 필수, line은 optional 참조).
- **OQ2**: codex `model_reasoning_effort`를 qg와 동일 `medium`으로 둘지, design-doc 리뷰에서
  상향할지. 잠정 `medium`(qg 패리티) — 구현 후 수동 e2e에서 재평가.

## 16. Metadata

- **plugin**: spec-distill
- **version**: 0.19.3 → 0.20.0 (minor — 새 review surface)
- **created**: 2026-07-15
- **approach**: A (전용 design-doc codex 경로 + detect_codex vendor)
- **implementation**: subagent-driven (TDD, 각 task 2단계 리뷰 + whole-branch)
- **관련 메모리**: `reference_codex_reviewer_spec_ac_injection`(순환 footgun), `project_qg_*`(codex
  패턴 이력), `feedback_shared_premise_blinds_reviewers`(리뷰 pass blind),
  `reference_mktemp_cd_empty_footgun`(C7), `grep_lock_header_satisfiable`(테스트 이빨),
  `feedback_fix_introduces_regression`(게이트 강화 시 술어 검증).

## Handoff Context

**TL;DR**: spec-distill Phase 3(design-doc 리뷰)에 codex를 병렬 독립 co-reviewer로 추가한다.
Claude spec-reviewer와 codex가 같은 design doc을 독립 리뷰 → 보수적 병합(더 심각한 verdict가
이김, codex가 approved를 뒤집을 수 있음) → 기존 routing table에 투입. codex findings는
issue_history 원장에 통합돼 stagnation으로 반복 포착. codex 부재/실패는 Claude-only로 loud
degrade. 접근법 A(전용 design-doc 경로 + detect_codex vendor)로 확정 — qg의 diff+AC 기계장치는
순환 AC-주입 footgun 때문에 재사용 불가.

**Implicit context** (코드에서 자명하지 않은 확정 사항):
- codex 역할 = 병렬 독립 co-reviewer(adversarial 2차 패스 아님) — 확정.
- verdict 병합 = 보수적(codex block 권한 있음, advisory-only 아님) — 확정.
- issue_id 계산 = orchestrator 중앙화(helper) — codex뿐 아니라 기존 Claude in-head 해싱도
  결정론 helper로 교체(cross-reviewer collision integrity 위해 필수) — 확정.
- 두 리뷰어는 리뷰 pass 수준 blind이되 원장은 orchestrator-side 통합(same-origin history만 각
  리뷰어에 전달) — 확정.
- codex는 needs_interview 트리거 안 함(approved↔needs_revise만) — 확정.
- vendor 전략: `detect_codex.sh`+`codex_findings_to_yaml.py`만 재활용(리뷰 대상 무관),
  `build_*`/`run_*`는 design-doc 전용 신규 — 확정.
- **결정론 merge/ledger 엔진 `merge_review.py`** (round-1 리뷰 반영) — verdict 유도·보수적 병합·
  원장 union·**통합-원장 stagnation 스캔**을 전부 소유하는 단일 검증 가능 CLI 경계. SKILL.md 프로즈
  암산이 아님(C2). 기존 SKILL.md "Stagnation detection" 절은 Claude self-report 단독 → merge_review
  통합-스캔 flag로 교체(codex-only 반복 이슈 escalate; self-report는 보조 신호) — 확정.
- codex severity vocab = `{block, high, medium}`(qg CRITICAL/IMPORTANT/SUGGESTION 아님); `block`
  분기는 codex 자기-escalation 존중용 의도된 headroom(dead branch 아님) — 확정.
- **대칭 결정론 파싱** (round-2 리뷰 반영) — spec-reviewer는 issue를 **구조적 fenced YAML block**으로
  emit하고 merge_review가 Claude·codex **양쪽을 스크립트로 파싱** → compute_issue_id에 넘김.
  collision-sensitive 값이 어느 쪽도 LLM 전사를 거치지 않음(codex 파서와 대칭, [fc2ef911] 완전 봉쇄).
  Claude block malformed 시 stated-verdict 존중+원장 skip. `confidence`는 verdict 수식에서 의도적 제외
  (advisory-surface 전용) — 확정.
- **Claude-side 하드닝 대칭** (round-3 리뷰 반영) — spec-reviewer는 issue를 **sentinel fence**
  (` ```spec-review-issues `)로 emit하고, merge_review는 리뷰 대상 doc의 에코 fence들 사이에서 sentinel
  블록만·마지막 것을 선택(codex last-fenced-block 안티인젝션과 대칭). Claude 파싱 실패 시 named
  `claude_degraded` flag + §9 매트릭스 행. **C8**: orchestrator는 spec-reviewer raw 출력을
  `--claude-output`에 **verbatim** 저장(요약 금지) — 전사 재도입 방지 — 확정.
- **verdict 회수 계층** (round-4 리뷰 반영, [bc365411] spirit) — verdict는 sentinel issue-block과
  **독립**으로 top-level `**Status:**` 라인에서 추출. degrade 계층: sentinel malformed→Status에서
  회수(claude_degraded) → Status도 malformed→codex 단독(claude_verdict_unrecoverable) → 양쪽 회수불가
  →`needs_revise` fail-safe(비-approve, crash·fail-open 금지)+indeterminate advisory. §9 매트릭스가
  전 분기 명세. merge_review stdout=YAML(형제 스크립트 일관) — 확정.

**Deferred to plan** (writing-plans에서 결정):
- OQ1(line 키 유지 여부), OQ2(codex reasoning effort medium vs 상향).
- codex_findings_to_yaml.py 적응의 정확한 diff 범위(qg 원본 대비 최소 변경).
- reviewing-spec SKILL의 Step 삽입 위치·정확한 문구(기존 review_lock/harness-sid 흐름과의 순서).
- spec-reviewer.md의 Output 형식에서 issue_id self-emit 제거 시 하위 호환(기존 issue_history
  스키마 migration).
- 테스트 mock codex 스크립트의 JSONL 이벤트 shape(0.130+ item.completed vs legacy).
