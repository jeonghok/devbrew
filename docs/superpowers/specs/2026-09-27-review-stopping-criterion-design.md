---
name: review-stopping-criterion
type: design
created_at: 2026-09-27
source_interview: docs/superpowers/interview/2026-09-27-review-stopping-criterion-interview.md
next_phase: superpowers:writing-plans
---

# 리뷰 멈춤 기준 — 막는 축과 참고 축을 가른다 · Design

> 리뷰가 「더 찾을 게 있나」를 묻는 한 멈추지 않는다. 승인 술어는 그대로 두고, 그 술어에
> 들어가는 입력을 must-catch 축으로 좁힌다. 나머지는 끝에서 한 번 보이고 하류가 읽는 자리에 남는다.

## 목차

- [Handoff Context](#handoff-context)
- [Goal](#goal)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계 (Architecture)](#설계-architecture)
  - [§A 프로필 필드 must_catch](#a-프로필-필드-must_catch)
  - [§B 라우팅](#b-라우팅)
  - [§C advice 원장 · 1회 규칙](#c-advice-원장--1회-규칙)
  - [§D 표시와 박제 — 끝에서 한 번](#d-표시와-박제--끝에서-한-번)
  - [§E 관측 — 멈춤 보장의 정직한 경계](#e-관측--멈춤-보장의-정직한-경계)
  - [§F 곁가지 — 번들 위생 regex (OQ14)](#f-곁가지--번들-위생-regex-oq14)
  - [§G 데이터 흐름 한 장](#g-데이터-흐름-한-장)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [Open Questions](#open-questions)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)

## Handoff Context

이 문서가 받은 것: `docs/superpowers/interview/2026-09-27-review-stopping-criterion-interview.md`
(§2 확정 9건 · 잠정 3건 · §3 Open Questions 9건 · §4 landscape 17건 · §5 기각 3 + 위험 14).
텔레메트리 · steelman 원문 · 리뷰 결정은 그 파일의 `audit_file` 에 있다.

**재결정 규약(P23)** — brief §2 의 confirmed 항목은 재논의 대상은 아니지만 **반증 대상**이다.
근거가 있으면 보고 후 사용자 동의로 재결정하고, 뒤집은 항목은 *원래 / 재결정 / 근거* 세 칸으로
남긴다. 임의 변경은 금지다. **이 문서는 confirmed 를 뒤집지 않았다.** 잠정 ⟨D7⟩ 의 두 조각을
사용자 동의로 재결정했고 세 칸 기록은 `## 결정 기록` 의 `### 재결정` 절에 있다.

## Goal

공유 문서 리뷰 엔진이 재리뷰 상한 · 사용자 피로가 아니라 **문서 상태(must-catch 0건)** 로 멈춘다. advisory 축은
라운드를 늘리지 않는다 — 라운드 1 의 advisory fix 는 적용을 관측하는 한 라운드만 더 들고, 그 뒤의 새 advisory 는
참고로 간다(§B).
사용자 개입은 하류가 다시 못 보는 판정(원문 · 확정 대조)으로 줄고, 나머지 finding 은 사라지지 않고
하류가 읽는 자리로 간다 ⟨C1⟩ ⟨D3⟩.

## Context / Why

- **승인 술어가 범주를 안 본다.** `shared/docreview/scripts/docreview_state.py` `gate_summary` 의
  `approval_ready = not any(g[row.name] for row in GATE_ROWS if row.blocks)` — decides · fixes · asks
  원장의 열린 차단 행 하나가 승인을 막는다. 방향 finding 하나도 충실도 finding 하나와 같은 무게다
  (brief §5 RC24).
- **그 결과가 관측된다.** brief 리뷰 최근 4회 전부 상한 또는 사용자 수동 종료, 회당 결정 14~19건
  (RC12). 사용자가 비수렴 상태에서 실제로 고른 처분은 「충실도 적용 · 방향 이월」이었다(RC29).
- **입력이 한 자리에서 갈린다.** 리뷰어 finding 이 원장으로 들어가는 문은
  `shared/docreview/scripts/docreview_route.py` `_classify_items` 하나다. 여기서 advisory 축을 차단
  원장 밖으로 보내면 `approval_ready` · `GATE_ROWS` · 가시성 락은 한 글자도 안 바뀐다.
- **라운드 스냅숏은 절 해시뿐이다.** `begin-round` 는 `anchor · title · level · hash · parents` 만
  저장하고 본문은 없다 — 본문 diff 를 재비판자에게 주려면 새 저장이 필요하다(접근 B 의 비용).
- **되살아난 기각 계보는 이미 보인다.** `_resolve_ids_and_lineage` 가 `rejected_lineages` 와 같은 버킷의
  새 finding 을 `revived` 로 세고 게이트 렌더가 공시한다.
- **codex 러너는 새 필드를 이미 받는다.** `run_docreview_codex_reviewer.sh` `_parse_frontmatter` 의 허용
  목록 문법은 컬럼-0 `key: <스칼라 flow 목록>` 을 키 이름과 무관하게 받는다 — `must_catch: [a, b]` 로
  러너는 무변경이다(러너는 `must_catch` 를 읽지 않는다 — 라우팅은 엔진 몫).
- **quality-gates 쪽 실사용 호출자는 0 이다.** `generic` 프로필은 「호출자 0 으로 심었다」
  (`plugins/quality-gates/README.md`), 엔진에서 qg 가 import 하는 것은 `recritic_bridge.py` 의
  `extract_block` 하나다.

## Goals

- **G1** 프로필이 must-catch 축을 지목하고, 그 밖의 rubric 축의 결정 · 질문은 게이트 질문이 되지 않고 승인을
  막지 않는다. 그 축의 `fix` 는 사용자 질문 없이 저자가 적용한다(§B) ⟨D11⟩. 예외: advisory fix 의 재상승 · 상향
  후속(엔진 자동 생성)은 막는다(§A).
- **G2** 지목이 없거나 모르는 category 는 막는 쪽이다 — 정의가 fail-closed ⟨D11⟩ ✎.
- **G3** advisory 는 게이트 질문이 아니고, 끝에서 한 목록으로 한 번 보이며, 한 화면(≤10줄)을 넘지
  않고, 박제처가 전문을 갖는다 ⟨D8⟩ ⟨D9⟩.
- **G4** must-catch 축은 매 라운드 전문 대조를 유지한다 ⟨D12⟩ ⟨C6⟩.
- **G5** 적용은 spec-distill 세 자리이고, 필드 없는 프로필(qg)은 바이트 단위로 현행이다 ⟨D10⟩.
- **G6** must-catch 축의 수렴 가정(RC31)을 다음 사이클이 측정할 수 있다(Law 3).

## Non-goals

- 재리뷰 상한 2 · Law 2 분리 리뷰 · kill switch 의 제거나 완화.
- 방향 · overdesign **탐지**의 제거 — 게이트에서 내릴 뿐 계속 찾고 보인다.
- 탐지 · 재비판 입력에 diff 를 싣는 것(OQ12 → 싣지 않는다, 연기 트리거는 §E).
- quality-gates 리뷰 동작 변경 · reviewing-brief SKILL.md 의 펜스 반복 정리.
- 프로필 본문(리뷰어가 읽는 검토 항목)의 수정 — 라우팅은 리뷰어가 알 필요가 없다. 그래서 `must_catch` 줄은
  리뷰어에게도 안 보인다: 세 진입 skill(`reviewing-brief` · `reviewing-spec` · `framing-requests`)의 profile-content
  펜스가 `<profile>` 슬롯에 싣기 전에 그 줄을 벗긴다. 막는 축을 아는 리뷰어는 category 라벨로 차단 여부를 조종할 수
  있다. codex 러너는 frontmatter 중 자기가 읽는 필드(`ground_truth` · `layer_rubric` · `allowed_dispositions` ·
  `web`)만 프롬프트에 싣으므로 무변경이다.

## Constraints

- ⟨D10⟩ 엔진 장치 + 세 프로필 값. 공유 스크립트는 qg 로도 배포되므로(심볼릭 링크) qg 회귀 확인이 AC 다.
- ⟨D12⟩ 자격을 좁히는 장치는 advisory 축에만 건다 — must-catch 를 줄이는 장치는 이 설계에 없다.
- ⟨D9⟩ 목록 상한 장치는 이 설계가 정한다 → §D.
- ⟨C6⟩ 좁힌 리뷰가 다른 절 · 다른 자리에 미치는 영향을 놓치지 않는다 → 전문 탐지 불변 + §E 관측.
- 소실 금지(CLAUDE.md 처분 회계) — 라우팅은 소실도 강제도 아니다. 자리별로 등식으로 센다.

## 설계 (Architecture)

### §A 프로필 필드 `must_catch`

선택 필드. `PROFILE_FIELDS`(필수 전부)와 따로 `OPTIONAL_PROFILE_FIELDS = ("must_catch",)` 로 둔다 —
필수 목록에 넣으면 qg `generic` 이 `fields_missing` 으로 죽는다.

- **advisory 축 = (`layer_rubric.layer1` ∪ `layer2`) − `must_catch`.** 그 밖은 전부 must-catch: rubric 밖
  category · `other` · `frozen_change`.
- **엔진 자동 생성 항목(`_source` ∈ diff · reraise · escalated)은 category 와 무관하게 must-catch 다.** 재상승 ·
  상향 후속은 원본의 category 를 물려받으므로(`_auto_decides`) category 로는 못 가른다 — advice 표지 단계가
  `_source` 를 보고 건너뛴다. 호출 순서에 기대지 않는다.
- 필드 부재 → advisory 축 공집합 → 현행과 같다.
- 스키마 거부: rubric 에 없는 축 → `must_catch_unknown_axis:<축>`, 빈 목록 → `must_catch_empty`
  (막는 축 0 은 「무엇으로도 멈춘다」다).

| 프로필 | `must_catch` | advisory 축 |
|---|---|---|
| brief | 층 2 여섯 — `distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported` | `direction, overdesign` |
| design-doc | `goal_fit, problem_definition, scope, architecture` (brief §2 대조 네 축) | 층 1 나머지 다섯 + 층 2 일곱 |
| seed | 층 1 네 축 전부 | 없음 — 라우팅 불변. 지목했으므로 참고 줄 · 계수 키(§C · §E)는 선다(참고 0건) |

### §B 라우팅

advice 는 원장에서 **떼어 내지 않고 표지(`route: advice`)만 단다.** 표지를 단 항목도 다른 항목과 같이 id · bucket ·
계보(`_resolve_ids_and_lineage`) · `L.accept` · `record_findings` 를 거치고, `record_findings` 가 decides · asks ·
fixes 대신 `advice` 원장에 적는다 — id · 계보 · 회계가 한 경로라 advice 항목이 조용히 빠지지 않는다(AC8). 엔진
자동 생성 항목(`_source` ∈ diff · reraise · escalated)은 두 걸음 모두 건너뛴다(§A). 표지는 **두 걸음**으로 단다:

1. **`_classify_items`(처분 강제 · 보호 헤딩 승격 뒤)** — 축과 처분만 보면 정해지는 것. advisory 축 항목 중
   - 처분이 `decide` · `ask` 인 것,
   - 보호 헤딩 때문에 `fix` 에서 `decide` 로 승격된 것(`promoted_from: fix`) — 게이트 질문이 되지 않는다.
2. **`_resolve_ids_and_lineage` 뒤 · `_remap_blocks` 직전 한 자리** — 계보를 알아야 정해지는 것.
   - 라운드 n ≥ 2 에서 **새 계보**로 나온 advisory `fix`(계보 연결 · 재상승 후속이 아님) — 적용 관측을 위해
     라운드를 더 부르지 않게 참고로 보낸다.
   - `ask` 의 `blocks` 판정(아래 「`blocks`」) — 대상이 fixes 에 남는지가 이 걸음에서야 확정된다.

그 밖은 현행 경로 그대로다:

- **라운드 1 의 advisory `fix`(보호 헤딩 밖)는 fixes 원장에 남는다** — 사용자 질문 없이 저자가 적용하는 처분이라
  ⟨D2⟩ 의 개입을 늘리지 않고, `TBD` · 두 가지로 읽히는 AC 같은 결함이 리뷰 중에 고쳐진다(Law 1). 적용 관측에
  라운드 2 가 한 번 더 들고, 라운드 2 의 새 advisory fix 는 위 규칙으로 참고가 되므로 advisory 축이 라운드를 더
  늘리지 않는다.
- `defer` 는 현행 defer 경로(`### Deferred to plan`), `drop` · 재비판 `reject` 는 현행 회계로 간다.

경계를 넘는 관계는 막는 쪽으로 닫는다(G2) — `must_catch` 를 지목한 프로필에서만:

- **병합 생존자** — `same_as` 흡수(`_absorb_same_as`)는 처분 순위로 생존자를 고르고 생존자의 category 를 남긴다.
  흡수 대상 중 기각되지 않은 구성원 하나라도 must-catch 축이면 생존자를 must-catch 로 친다. 분류는 흡수 **뒤**에
  돌기 때문에(`cmd_finalize`), 흡수 단계가 구성원 축 소속을 생존자에 남겨야 한다.
- **`blocks`** — 판정은 축이 아니라 **대상의 적용 경로**로 한다. `blocks` 로 fixes 원장에 남는 항목(축 무관)을
  가리키는 `ask` 는 자기 축과 무관하게 asks 원장에 남고, 답 전까지 그 fix 는 `held` 다 — 질문이 막는 fix 가 답 없이
  적용되지 않는다. `ask` 의 `blocks` 가 advice 로 간 항목만 가리키면 그 ask 는 위 규칙대로 advice 이고, 차단 ask 의
  `blocks` 중 advice 로 간 ref 는 `_remap_blocks` 에서 조용히 버려지지 않고 `coerced("blocks", …)` 로 센다.

### §C `advice` 원장 · 1회 규칙

원장 키 `advice`(업그레이드 전 원장에는 없다 → 빈 값으로 읽는다). 항목은 버킷(`층|축|앵커`) 키.

- 새 버킷 → `listed`(id · 라운드 · 축 · 앵커 · summary · replacement).
- 이전 라운드에 오른 버킷 → 목록에 올리지 않고 그 라운드의 `advice_repeat` 로만 센다. 라운드 2
  이상의 재샘플링을 이것이 흡수한다(OQ11 의 advisory 몫).
- finalize 보고서에 `advice_new` · `advice_repeat` 를 싣는다.
- **새 출력은 `must_catch` 를 지목한 프로필에서만 난다** — 보고서의 새 키 셋(§C · §E), 게이트 렌더의
  참고 줄(§D). 지목이 없는 프로필(qg `generic`)의 보고서 · 렌더는 바이트 단위로 현행이다(AC3).

이름: 기존 `advisory[]` 는 degrade 공시다. 겹치지 않게 원장 · 키 · 서브커맨드는 `advice` 로, 사람말
라벨은 「참고(advisory)」로 쓴다.

### §D 표시와 박제 — 끝에서 한 번

- **라운드 게이트 렌더**에는 한 줄만: `참고 N건(이번 라운드 새 k · 반복 r) — 끝에서 한 목록으로`.
  게이트 질문은 0 이다.
- **새 서브커맨드** `docreview_state.py advice --state-dir D [--render --cap 8] [--sink <doc>]`.
  `--render` 는 머리 한 줄 + 항목 한 줄씩(`[축] 앵커 — summary`), 8줄 초과면 8줄 뒤에
  `외 K건 — <박제처>에 전부` 한 줄. 합계 ≤10줄 ⟨D9⟩.
  `--sink` 는 프로필 `defer_target` 절에 기존 `append_under_heading` 으로 미박제 항목 전부를 표 행으로
  적고 `sunk` 를 찍는다. `defer_target` 이 `none` 이면 `profile_has_no_defer_target` rc 1.

| 자리 | 언제 | 표시 | 박제 |
|---|---|---|---|
| brief | 호출자 Step B(`finishing.md`) | `advice --render --cap 8` 한 번 | 오케스트레이터가 결정이 필요한 것은 §3 OQ 줄, 위험 서술은 §5 위험 줄로 쓰고 §0 결정 목록을 맞춘 뒤 `check_brief.py gate` 재실행 |
| design doc | `reviewing-spec` 승인 게이트 1단계가 진행 쪽으로 닫힌 뒤 · 2단계 앞 | 같은 렌더 한 번 | `advice --sink <doc>` → `### Deferred to plan` (얼림 면제 절) |
| seed | — | 항상 0건 | 없음 |

「추가 라운드 1회 열기」를 고르면 표시 · 박제 · 계수 기록은 돌지 않고 다음 라운드 끝으로 미뤄진다. `advice` 는 이미 보인
항목 · 박제한 항목을 다시 내지 않는다(`shown` · `sunk` 표지 — 멱등).

design doc 의 박제처가 `Deferred to plan` 인 것은 writing-plans 가 그 절을 읽기 때문이다 — ⟨C4⟩ 의
「writing plan 에서 한 번 더 본다」가 이 자리에서 물리적으로 성립한다.

### §E 관측 — 멈춤 보장의 정직한 경계

- **멈춤의 최종 보증은 재리뷰 상한 2 다.** must-catch 축은 전문 대조라(G4) 재샘플링을 막는 장치가 없다.
- **`mc_preexisting_new`** — 라운드 n ≥ 2 에서 must-catch 로 분류된 리뷰어 finding 중 새 계보(계보 연결
  · 재상승 후속이 아님)이고 앵커 절과 그 하위 절(`parents` 로 도출) 전부의 해시가 스냅숏 n−1 과 n 에서 같은 것의 수.
  스냅숏 해시는 다음 헤딩(레벨 무관)에서 끊기므로 자기 절만 비교하면 상위 앵커 finding 이 하위 절 변경에도 선재로 세어진다. 게이트 렌더의 참고 줄에
  싣는다. 동작을 바꾸지 않는다 — RC31(「전문 재대조에서 재샘플링이 잦아든다」)이 성립하는지를 다음
  사이클들이 셀 수 있게 한다(OQ17).
- **영속 운반체** — 계수가 finalize 보고서에만 있으면 세션 상태의 24h TTL GC(`spec-distill-gc.py`)와 함께
  사라진다. 그래서 끝의 한 번 표시(§D)와 같은 시점에 `advice --log-file <decision_log 목적지>` 가 라운드별 계수
  한 줄(`docreview 계수 — <리뷰 정체> r<n>: advice_new=k · advice_repeat=r · mc_preexisting_new=m`)을 프로필 `decision_log`
  절에 기존 `append_under_heading` 으로 덧붙인다 — brief 는 audit `## 8. 리뷰 결정`, design doc 은 `## 결정 기록`,
  seed 는 audit `## 6. 리뷰 결정`. 커밋되는 문서라 다음 사이클이 grep 으로 센다. `<리뷰 정체>` 는 문서별 상태 디렉토리
  키(세션 + 문서 해시 — `state-dir-for` 의 마지막 경로 조각)이고 멱등 키는 (리뷰 정체, 라운드)다 — 같은 문서를 다른
  세션에서 다시 리뷰해도 줄이 막히지 않고 grep 으로 구별된다.
- **접근 B 로 올라갈 트리거** — 라운드 2 이상의 `advice_new` 가 cap(8)을 넘는 일이 반복되면 재비판자
  diff 자격(`### 재결정` R1)을 연다. 재료는 위 운반체가 남긴 계수 줄이다.

### §F 곁가지 — 번들 위생 regex (OQ14)

`plugins/spec-distill/scripts/build_brief_bundle.py` 의 `AUDIT_NAME_RE = \S*\.audit\.md\b` 는 payload
안의 **모든** `*.audit.md` 에 켜진다. 이 검사가 가리는 것은 이 brief 자신의 audit 이므로, 판정을 자기
`audit_file` 값의 basename 으로 좁힌다. 다른 인터뷰의 audit 을 §5 근거로 인용하는 것은 정상이다 —
최근 6회 중 3회의 rc 3 degrade 가 그 오탐이었다. `build_brief_inline_blob.py`(readback 블롭)는 자기
`AUDIT_SUFFIX_RE` 로 같은 판정을 하므로 같이 좁힌다.

### §G 데이터 흐름 한 장

```
라운드 n: 스냅숏 → kill switch → 탐지(전문) → codex → 익명화 → 재비판      (불변)
  → finalize: 분류 ─┬─ must-catch → decides/fixes/asks → approval_ready   (술어 불변)
                    └─ advisory   → advice(listed | repeat)
  → 게이트: 라운드 게이트 = must-catch 뿐 · 참고 한 줄(N · k · r · mc_preexisting_new)
끝: advice --render --cap 8 (한 번) → 박제: brief §3/§5 (Step B) | design doc Deferred to plan (--sink)
```

## Acceptance Criteria

- **AC1** brief 프로필 fixture 둘. (i) `direction` decide 만 나온 라운드 1 은 `approval_ready` 가 참이고
  `round_gate_needed` 가 거짓이며 그 항목은 `advice` 에 있다. (ii) `direction` decide + `distortion` finding 이면
  `distortion` 은 decides(또는 fixes)에 있고 `approval_ready` 가 거짓이며 `direction` 은 `advice` 에 있다.
- **AC2** rubric 밖 category · `other` · `frozen_change` 는 `must_catch` 가 있는 프로필에서도 차단 원장에
  간다. advisory 축(`ambiguity`) fix 의 check-intent 거부 상향 후속(`_source: escalated`)은 decides 에 있고
  `advice` 에 없다. 여집합 계산을 뒤집는 변이(advisory = must_catch)는 AC1 · AC2 를 RED 로 만든다.
- **AC3** `must_catch` 가 없는 프로필로 같은 fixture 를 돌리면 finalize 보고서와 `gate --render` 가 변경
  전과 바이트 동일하다(golden, 예외 없음). 같은 fixture 에 `must_catch` 를 지목하면 참고 줄이 선다(양성 짝).
- **AC4** `must_catch` 에 rubric 밖 축 → `must_catch_unknown_axis`, 빈 목록 → `must_catch_empty` 로 `init`
  rc ≠ 0. 필드 부재는 통과.
- **AC5** 라운드 1 에 오른 advisory 버킷이 라운드 2 에 다시 나오면 목록에 없고 `advice_repeat` 가 1 이다.
  새 버킷은 `listed` 다.
- **AC6** `advice --render --cap 8` 은 11건이면 항목 8줄 + `외 3건` 한 줄, 8건이면 접는 줄이 없다.
  머리 포함 ≤10줄.
- **AC7** `advice --sink` 는 design-doc 프로필에서 `### Deferred to plan` 아래에 미박제 항목 전부를 적고
  두 번째 호출은 아무것도 더 적지 않는다(멱등). brief 프로필에서는 `profile_has_no_defer_target` rc 1.
- **AC8** 단계별 등식이 fixture 에서 성립한다(합계 하한이 아니다). 정규화된 리뷰어 입력(critic + codex) + 재비판
  `added` = `same_as` 흡수 + 재비판 기각 + drop + 차단 원장 생존자(decides + fixes + asks + defers, 축 무관 — advisory
  fix · defer 포함) + `advice`(listed + repeat — §B 의 advice 표지를 단 것만). 엔진 자동 생성분(얼림 · 재상승 · 상향)은 별도 유입으로 세고, 파손 입력은 정규화 단계의 보류
  회계로 센다. 각 항은 fixture 에서 0 이 아닌 값을 하나 이상 갖는다.
- **AC9** `mc_preexisting_new` 는 해시 불변 절의 새 계보 must-catch 만 센다 — 바뀐 절의 것 · 계보 후속은
  세지 않는다.
- **AC10** 번들 빌더 · inline 블롭 빌더는 payload 에 자기 `audit_file` basename 이 있으면 rc 3, 다른
  `*.audit.md` 경로만 있으면 rc 0.
- **AC11** 절차서 · `reviewing-brief` · `reviewing-spec` · `finishing.md` 의 문면이 §D 의 한 번 표시 ·
  박제 절차를 싣고, 그 문면이 부르는 서브커맨드 · 플래그가 실재한다.
- **AC12** 착수 전 baseline 대비 `shared/tests/test_docreview_*.sh` · `plugins/quality-gates/tests/test_recritic_bridge.sh`
  · 이 파이프라인을 참조하는 spec-distill 테스트의 rc 와 실패 줄 수가 늘지 않는다.
- **AC13** design-doc 프로필 라운드 1 에서 보호 헤딩 밖 advisory 축(`ambiguity`)의 `fix` 는 fixes 원장에 있고 `advice` 에
  없다. 같은 축의 `decide` · `ask` 는 `advice` 에 있다 — 단 fixes 원장 항목을 `blocks` 로 가리키는 `ask` 는 asks 에 있다.
- **AC14** `same_as` 로 `architecture`(must-catch)와 `component_relations`(advisory)를 병합하면 처분 순위와 무관하게
  생존자가 must-catch 원장에 있다. 구성원이 전부 advisory 면 생존자의 축 소속만 advisory 로 남고 원장은 §B 규칙이
  정한다 — 라운드 1 advisory fix 끼리의 병합 생존자는 fixes 에 있다. 필드 없는 프로필의 병합 결과는 AC3 golden 과 같다.
- **AC15** advisory `ask` 의 `blocks` 가 fixes 원장에 남는 `fix` 를 가리키면 — 그 fix 가 must-catch 든(①) advisory 든(②)
  — 그 ask 는 차단 ask(`blocking_ask_open`)이고 fix 는 `held` 다. 차단 ask 의 `blocks` 가 advice 항목을 가리키면 그 ref
  가 `coerced` 로 1 세어진다.
- **AC16** 세 진입 skill 의 profile-content 펜스 출력에 `must_catch:` 줄이 없고, 그 줄을 뺀 나머지는 프로필 파일과
  바이트 동일하다. 벗기는 줄을 지우는 변이는 RED.
- **AC17** `advice --log-file` 이 decision_log 절에 라운드별 계수 줄을 적은 뒤 엔진 상태 디렉토리를 지워도 그 줄이
  목적지 파일에 남는다. 두 번째 호출은 같은 (리뷰 정체, 라운드) 줄을 다시 적지 않고, 다른 리뷰 정체의 같은 라운드 줄은
  적는다.
- **AC18** design-doc 프로필 라운드 2 에서 새 계보의 advisory `fix` 는 `advice` 에 있고 `approval_ready` 를 막지 않는다.
  라운드 1 에서 온 계보의 advisory fix(미적용)는 fixes 원장에 남아 막는다.
- **AC19** 보호 헤딩 안의 advisory `fix` 는 `decide` 로 승격된 뒤 `advice` 에 있고 `round_gate_needed` 를 켜지
  않는다. 같은 자리의 must-catch `fix` 는 현행대로 decides 로 승격된다.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `shared/docreview/scripts/docreview_state.py` | `OPTIONAL_PROFILE_FIELDS` · `must_catch` 스키마 · `advice` 원장 기본값 · `gate_summary` 의 참고 계수 · 렌더 참고 줄 · `advice` 서브커맨드(`--render` · `--cap` · `--sink` · `--log-file`) |
| `shared/docreview/scripts/docreview_route.py` | 두 걸음 `route: advice` 표지 — `_classify_items`(decide · ask · 승격분)와 계보 해소 뒤 `_remap_blocks` 직전(라운드 ≥2 새 계보 fix · 적용 경로 기준 `blocks`), 엔진 자동 생성분은 `_source` 로 건너뜀 · `_absorb_same_as` 의 구성원 축 소속 · 보고서 `advice_new` · `advice_repeat` · `mc_preexisting_new` |
| `plugins/spec-distill/references/docreview-profiles/{brief,design-doc,seed}.md` | frontmatter `must_catch` 한 줄씩 |
| `plugins/spec-distill/references/reviewing-document.md` | 7 · 8단계의 advice 분기와 `advice` 서브커맨드 계약만 적는다. 끝의 한 번 표시는 절차서가 하지 않는다 — 부르는 자리는 진입 자리 하나씩(design doc = `reviewing-spec` 승인 게이트, brief = 호출자 Step B, seed = 표시 없음 · 계수만)이다 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | `## 게이트` 승인 게이트 1단계가 진행 쪽으로 닫힌 뒤 · 2단계 앞의 `advice --render` · `--sink` · `--log-file` 호출 |
| `plugins/spec-distill/skills/{reviewing-brief,reviewing-spec,framing-requests}/SKILL.md` | profile-content 펜스가 `must_catch:` 줄을 벗긴다. `framing-requests` 의 `### 프로필 내용` 펜스에는 지금 `profile-content` 마커가 없으므로 마커를 더하고, 추출 락(`test_dispatch_profile_inline.sh`)이 세 자리를 재게 넓힌다(AC16). `reviewing-brief` 는 `advice` 를 부르지 않는다 — brief 의 한 번 표시는 호출자 Step B 한 곳이다. `framing-requests` 는 승인 게이트 1단계가 진행 쪽으로 닫힌 뒤 `advice --log-file <audit>` 로 seed 의 계수 줄(audit `## 6. 리뷰 결정`)만 적는다 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | Step B 의 참고 목록 표시(`advice --render` · `--log-file`) · §3/§5 박제 규칙. B-2 의 「층 1(방향성) 결정은 라운드 게이트에서 이미 사용자가 판정했습니다」를 고친다 — brief 의 방향 · overdesign 은 이제 라운드 게이트가 아니라 참고 목록으로 온다 |
| `plugins/spec-distill/scripts/build_brief_bundle.py` · `build_brief_inline_blob.py` | 위생 판정(`AUDIT_NAME_RE` · `AUDIT_SUFFIX_RE`)을 자기 audit basename 으로 |
| `shared/tests/test_docreview_{route,state,profile_schema,golden}.sh` · spec-distill 번들 · 진입 skill 펜스 테스트 | AC1~AC10 · AC13~AC19 |
| `plugins/{spec-distill,quality-gates}/.claude-plugin/plugin.json` · `CHANGELOG.md` | spec-distill minor · qg patch(공유 스크립트 배포분) |

## Verification Plan

1. 착수 전 baseline — AC12 의 테스트 전부를 rc 와 실패 줄 수로 기록한다(이미 RED 인 파일 안의 새 실패를
   보기 위해 줄 수가 필요하다).
2. 각 AC 락은 양성 · 음성 짝으로 쓰고 변이로 이빨을 확인한다 — 최소 변이: 여집합 반전(AC2) · 1회 규칙
   제거(AC5) · cap 상수 변경(AC6) · 해시 비교 제거(AC9) · regex 원복(AC10). `PYTHONDONTWRITEBYTECODE=1`.
3. AC3 golden 은 변경 전 커밋에서 fixture 출력을 캡처해 파일로 고정한 뒤 비교한다.
4. 끝에서 AC12 재측정 — baseline 과 줄 수 등식.

### Deferred to plan

- `advice --render` 항목 줄의 정확한 폭 · 절단 규칙(한 줄 유지).
- brief Step B 에서 §3 / §5 를 가르는 판단의 문면 한 줄과 §0 결정 목록 동기화의 모양 — `check_brief.py`
  게이트가 받는 모양으로.
- 회계 모듈(`shared/adjudication/`)에서 advice 를 「전달」로 세는 자리 — AC8 등식이 서는 한 구현 재량.

## Rejected Alternatives

| 대안 | 기각 이유 |
|---|---|
| **B. 재비판자 diff 자격(D7 문면)** — 라운드별 본문 사본 · unified diff 를 `<diff>` 로, persona 에 「must-catch 는 선재 이유로 기각 금지」 | 멈춤과 개입 감소는 §B 라우팅이 거의 전부 한다. advisory 는 게이트 질문도 차단도 아니라 라운드 2 재샘플링은 목록 길이에만 닿고, 그것은 §C 1회 규칙 · §D cap 이 막는다. B 는 그 목록을 조금 더 정확히 줄이는 대가로 새 저장 · diff 생성 · persona 규칙 · 락을 든다. 트리거(§E)를 달아 연기 |
| **C. 프롬프트만** — 프로필 산문으로 advisory 를 덜 내게 | `approval_ready` 가 범주를 안 봐 방향 finding 하나가 여전히 막는다(RC24) — 뿌리 ⟨D3⟩ 를 못 건드린다 |
| **`advisory: [...]` 필드(막지 않는 축 목록)** | 엔진이 새 category 를 만들 때마다 지목 누락이 fail-open 이 된다. 막는 축을 지목하고 여집합을 rubric 안으로 한정하는 쪽이 정의상 fail-closed |
| **must-catch 축의 재제기 금지(버킷 동일 → 자동 처분)** | 탐지기는 사용자 결정을 못 보므로(프레이밍 차단) 「새 근거」를 판정할 수 없고, 엔진이 가를 수 있는 버킷(`층|축|절`)으로 막으면 같은 절의 새 충실도 결함이 묻힌다. 되살아남은 `revived` 로 이미 보인다 |
| **design doc must-catch 에 feasibility 포함 · 층 1 전부** | 하류(writing-plans · 구현 테스트)가 다시 보는 축이다. brief §2 대조 네 축만 하류가 정답으로 집행한다 |
| **design doc advisory 는 표시만 · 결정 기록 절** | 표시만이면 ⟨D8⟩ 박제가 운반체 없이 사라지고, 결정 기록 절은 writing-plans 가 할 일로 읽는다는 보장이 약하다 |
| **라운드마다 참고 목록 표시** | ⟨D8⟩ 「1회」와 어긋나고 라운드 게이트의 읽을 양을 되살린다 |

## Open Questions

brief §3 의 아홉을 이 설계가 닫은 자리:

| OQ | 닫은 자리 |
|---|---|
| OQ9 design doc must-catch | §A 표 — 사용자 선택 |
| OQ10 목록 상한 장치 | §D `--cap 8` + 박제처 전문 |
| OQ11 재제기 금지 확장 | §C(advisory) · 기각 대안 4행(must-catch) — `### 재결정` R2 |
| OQ12 탐지 diff | Non-goals — 싣지 않는다, 트리거 §E |
| OQ13 단일 판정자 잔여 위험 | 알려진 한계 1 |
| OQ14 번들 rc 3 | §F |
| OQ15 qg 회귀 확인 | AC3 · AC12 |
| OQ16 박제처 | §D 표 — 사용자 선택 |
| OQ17 must-catch 멈춤 보장 | §E — 상한 2 + `mc_preexisting_new` 관측 |

새로 열린 것은 없다.

## 알려진 한계

1. **must-catch 0건은 판정자 표본 0 이지 결함 0 이 아니다**(brief §4 «capture-recapture»). 새 장치는
   두지 않는다 — codex 교차 · 재비판 추가 finding 이 있고, 그것이 빠진 라운드는 degrade 첫 줄이 공시한다.
2. **1회 규칙의 버킷은 절 단위라 거칠다.** 라운드 1 에 §2 의 `direction` 이 올랐으면 라운드 2 에 편집이
   §2 에 새로 들인 방향 결함도 `repeat` 로 접힌다. 손실은 advisory 층에 머문다 — 충실도 결함은 must-catch
   전문 대조가 잡는다. 이 손실이 문제가 되면 §E 트리거와 같은 길(B)로 간다.
3. **must-catch 축의 수렴은 가정이다**(RC31 한 건). 상한 2 가 보증이고, §E 관측이 가정을 잰다.

## Concrete Next Action

이 문서를 `spec-distill:reviewing-spec` 으로 리뷰 → 승인 게이트에서 진행을 고른 뒤 `superpowers:writing-plans`.

## 결정 기록

brainstorming 에서 사용자가 고른 것:

- **B1** OQ9 — design doc must-catch = brief §2 대조 네 축(`goal_fit · problem_definition · scope · architecture`).
- **B2** OQ16 — design doc advisory 박제처 = `### Deferred to plan`(기존 defer 경로).
- **B3** 접근 A — 라우팅 분리 + 1회 표시 + 표시 상한, diff 자격은 트리거 연기.
- **B4** §1 — 라운드 게이트엔 개수 한 줄, 목록은 끝에서 1회 · brief 박제는 Step B 에서 오케스트레이터 ·
  OQ14 를 이번 범위에.
- **B5** §3 — must-catch 재제기는 막지 않고 `revived` 공시 + `mc_preexisting_new` 관측.

리뷰 결정(엔진 기록):

- D1.1 · r1 · adopt · 4ae3af49#r1.1 · "채택 — (a) fix 는 fixes 유지" — 라우팅이 처분을 보지 않아서 advisory 축의 `fix` 도 advice 로 빠집니다. 그 결과 design doc 에서는 층 2 일곱 축과 feasibility 의 상세 결함이, 보호 헤딩 안에 있어도 리뷰 중에 문서에서 고쳐지지 않고 Deferred to plan 에 행으로만 쌓입니다.
- D1.2 · r1 · adopt · 7354bec2#r1.1 · "채택 — 슬롯 전 벗기기" — `must_catch` 가 프로필 frontmatter 에 들어가면 프로필 전문이 `<profile>` 슬롯에 그대로 실리므로 탐지기와 재비판자가 어느 축이 막는지 봅니다. Non-goal 의 「라우팅은 리뷰어가 알 필요가 없다」와 어긋나고, 라우팅의 유일한 키인 category 라벨을 리뷰어가 쥐게 됩니다.
- D1.3 · r1 · adopt · 76165d29#r1.1 · "채택 — decision_log 에 한 줄" — G6 과 §E 의 트리거가 기대는 계수(advice_new · advice_repeat · mc_preexisting_new)는 finalize 보고서에만 남습니다. 그런데 그 보고서는 24시간 TTL 로 지워지는 세션 상태 안에 있어서, 「다음 사이클이 측정한다」를 받쳐 줄 영속 운반체가 없습니다.
- D1.4 · r1 · adopt · a629a7da#r1.1 · "채택 — 구성원 하나라도 막음" — 병합 생존자의 category만으로 분기하면 must-catch finding이 advisory에 흡수되어 차단에서 빠진다.
- D1.5 · r1 · adopt · baf43eac#r1.1 · "채택 — 막는 ask 는 must-catch" — ask→fix 의 `blocks` 의존이 must-catch 와 advisory 경계를 넘으면 끊깁니다. advisory ask 가 must-catch fix 를 막고 있었다면 그 차단이 사라지고, must-catch ask 가 advisory fix 를 막고 있었다면 비차단 ask 로 강등됩니다.
- D1.6 · r1 · adopt · fccf272b#r1.1 · "채택 — fixture 둘로 분리" — AC1 이 자기모순입니다. 「`direction` finding 만 나온 라운드 1」과 「같은 fixture 의 `distortion` finding」이 한 fixture 안에서 동시에 성립할 수 없습니다.
- D1.7 · r1 · adopt · fccf272b#r1.2 · "채택 — 단계별 등식" — AC8의 입력 경계가 정의되지 않았고, 등식에서 기존 same_as 흡수 항목이 빠져 있다.
- D2.8 · r2 · adopt · dddcf5cb#r2.1 · "채택 — (b) r≥2 새 fix 는 advice" — D1.1로 advisory 축의 fix가 fixes 원장에 남으면서 design doc의 승인 조건이 must-catch 0건이 아니라 must-catch 0건 + advisory fix 전부 적용이 됐다. 그런데 Goal·G1·§E는 여전히 must-catch 0건으로 멈춘다고 쓴다.
- D2.9 · r2 · adopt · a629a7da#r2.1 · "채택 — (a) 승격분도 advice" — 라우팅 분기가 앵커 분류 앞에 있어서, 보호 헤딩 안의 advisory fix는 분기를 지난 뒤 decide로 승격돼 게이트 질문이 되고 승인도 막는다. G1의 「그 밖의 rubric 축의 결정 · 질문은 게이트 질문이 되지 않고 승인을 막지 않는다」와 어긋난다.
- D2.10 · r2 · adopt · d5231a31#r2.1 · "채택 — 적용 경로 기준" — advisory 축의 fix에 답이 필요한 경우, 그 fix를 막는 advisory ask가 advice로 빠져 질문 없이 수정이 진행될 수 있다.
- D2.11 · r2 · adopt · 0d052804#r2.1 · "채택 — seed 행 정정" — §A 표는 seed를 「동작 불변, 지목은 명시용」이라고 하는데, §C는 새 출력(보고서 키 셋·게이트 참고 줄)이 must_catch를 지목한 모든 프로필에서 난다고 한다. 그러면 seed의 게이트 렌더와 보고서도 바뀐다. seed 행을 「라우팅 불변, 참고 줄·계수 키는 선다」로 고친다.
- D2.12 · r2 · adopt · e09185f8#r2.1 · "채택 — 현재 변경 유지" — finding 없이 바뀜: Goals (modified)
- D3.13 · r3 · adopt · d5231a31#r3.1 · "채택 — 두 걸음 표지" — 라운드 2 이상의 「새로 나온 fix」 판정(과 그 판정에 기대는 ask 의 blocks 판정)은 계보를 알아야 하는데, 문서는 이것을 계보가 정해지기 전 단계인 `_classify_items` 에 둔다.
- D3.14 · r3 · adopt · b17f9b7e#r3.1 · "채택 — _source 로 막음" — §A 는 재상승 · 상향 후속이 엔진이 만든 별도 category 라서 must-catch 라고 하지만, 실제로 두 후속은 원본의 category 를 그대로 물려받는다. 그래서 차단 여부는 category 가 아니라 코드 위치(`_classify_items` 뒤에 붙는다는 것)에만 기대고 있고, G1 과도 어긋난다.
- D3.15 · r3 · adopt · fccf272b#r3.1 · "채택 — 축 소속만 단언" — AC14의 '구성원이 전부 advisory면 advice'는 라운드 1 advisory fix를 fixes에 남기는 규칙과 충돌한다.
- D3.16 · r3 · adopt · 6caad3ba#r3.1 · "채택 — advice_promoted 제거" — yagni: `advice_promoted` 계수는 읽는 자리가 없다. 참고 줄, 영속 계수 줄, 트리거 어디에도 쓰이지 않는다.
- D3.17 · r3 · adopt · fffab72f#r3.1 · "채택 — 1단계 닫힌 뒤로" — design doc 의 한 번 표시 · 박제 · 계수 기록을 「승인 게이트 1단계 앞」에 두면, 1단계에서 「추가 라운드 1회 열기」를 고를 때마다 다시 돈다. 그래서 「끝에서 한 번」(D8 의 1회)이 보장되지 않는다. 두 가지 중 하나로 고친다: 1단계가 진행 쪽으로 닫힌 뒤(2단계 앞)로 옮기거나, 이미 보인 항목과 박제한 항목은 다시 렌더하지 않는다고 적는다.
- D3.18 · r3 · adopt · 0d28d925#r3.1 · "채택 — 리뷰 정체 넣기" — 영속 계수 줄 `docreview 계수 — r<n>: …` 에는 어느 리뷰인지를 가리키는 정체가 없는데, 멱등 키는 「같은 라운드」다(AC17). 같은 문서를 다른 세션에서 다시 리뷰하면 두 번째 리뷰의 r1 줄이 막히거나, 두 리뷰의 줄이 grep 으로 구별되지 않는다. 줄과 멱등 키에 리뷰 정체(상태 디렉토리 키 또는 세션)를 넣는다.
- D3.19 · r3 · adopt · 0d28d925#r3.2 · "채택 — 하위 절 포함" — `mc_preexisting_new` 의 「앵커 절 해시가 같음」이 자기 절 본문만 보는지 하위 절까지 보는지 정해져 있지 않다. 스냅숏 해시는 다음 헤딩(레벨 무관) 전까지의 본문만 담는다(docreview_anchor.py `parse_sections` 의 `end = heads[k + 1][0]`). 그래서 상위 앵커(예: `#설계-architecture`)의 finding 은 하위 절이 바뀌어도 선재로 세어진다. 하위 절(`parents` 로 도출)까지 포함해 비교한다고 적는다.
- D3.20 · r3 · adopt · 93a5c0ad#r3.1 · "채택 — 현재 변경 유지" — finding 없이 바뀜: Acceptance Criteria (modified)
- D3.21 · r3 · adopt · d5231a31#r3.2 · "채택 — 반영분 확인" — check-intent 거부 후 상향: §B는 advice 항목을 `_classify_items`에서 떼어 내지만, §C의 listed가 쓰는 id·bucket은 그 뒤의 `_resolve_ids_and_lineage(st, final, rejected_items, n)`에서만 붙는다. advice 항목이 id·버킷·원장 기록(`record_findings`)·`L.accept` 중 어디를 거치는지 정해지지 않았다.
- D3.22 · r3 · adopt · fccf272b#r3.2 · "채택 — 반영분 확인" — check-intent 거부 후 상향: AC8 등식의 항 「must-catch 생존자(decides + fixes + asks + defers)」의 이름이 내용과 맞지 않는다. §B에 따르면 fixes와 defers에는 advisory 축의 fix·defer도 들어간다. 이 이름대로 구현하면 advisory fix가 빠지거나 두 번 세어질 수 있다. 항 이름을 「차단 원장 생존자(축 무관)」로 바꾸고 advice(listed + repeat)는 decide·ask만이라고 명시한다.

원장 정정 공시 — 라운드 1 탐지기가 `§` 를 넣은 앵커(`#§b-라우팅` · `#§e-관측--멈춤-보장의-정직한-경계`)를 냈고 엔진
slug 는 `§` 를 뺀다. D1.1 · D1.3 · D1.5 의 permit 이 실재하지 않는 앵커를 가리켜 적용해도 만료될 상태라, 사용자 선택
(「원장 permit 앵커 정정」)으로 엔진 원장의 그 세 finding 의 `anchor` · `edit_scope` 와 permit 앵커를 `§` 만 뺀 실재 앵커로
손으로 고쳤다(9자리, 엔진 API 밖 1회 · 백업 보존).

리뷰 종료 공시 — 라운드 3 에서 재리뷰 상한(2/2)에 닿았고 사용자가 추가 라운드를 열지 않았다(「열지 않음」). 그래서 라운드 3
채택 9건(D3.13~D3.19 · D3.21 · D3.22)과 fix 1건(`1b5475ac#r3.1`), 라운드 2 의 상향 fix 2건의 **적용을 엔진이 관측하지 않았다**
— 반영은 이 커밋의 본문이고, 관측되지 않은 채 승인 게이트 2단계로 갔다. 라운드 3 재비판 입력은 `## 결정 기록` 절만 요약으로
대체했다(설계 본문은 전문) — 프로세스 일탈. 문서가 ~300줄을 넘어 `## 목차` 를 리뷰 뒤 문서 정리 편집으로 넣었다.

### 재결정

| # | 원래 | 재결정 | 근거 |
|---|---|---|---|
| R1 | ⟨D7⟩(잠정) 라운드 2 이상은 finding 자격을 diff 도입분 + 이음매로 좁힌다(advisory 축 — ⟨D12⟩) | 연기 — §C 버킷 1회 규칙이 advisory 재샘플링을 흡수하고, diff 자격은 §E 트리거로 연다 | 라우팅 분리 뒤 advisory 는 승인도 질문도 막지 않아 diff 자격의 이득이 목록 길이뿐이고, 그 비용(본문 사본 · diff · persona 규칙 · 락)이 이득보다 크다. 사용자 선택 B3 |
| R2 | ⟨D7⟩(잠정) 재제기 금지는 전 축 | advisory 축만(§C). must-catch 는 재제기를 허용하고 `revived` 로 공시 | 탐지기는 사용자 결정을 못 봐 「새 근거」를 판정할 수 없고, 버킷으로 막으면 같은 절의 새 충실도 결함이 묻힌다(fail-closed). 사용자 선택 B5 |
