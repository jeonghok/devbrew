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

## Handoff Context

이 문서가 받은 것: `docs/superpowers/interview/2026-09-27-review-stopping-criterion-interview.md`
(§2 확정 9건 · 잠정 3건 · §3 Open Questions 9건 · §4 landscape 17건 · §5 기각 3 + 위험 14).
텔레메트리 · steelman 원문 · 리뷰 결정은 그 파일의 `audit_file` 에 있다.

**재결정 규약(P23)** — brief §2 의 confirmed 항목은 재논의 대상은 아니지만 **반증 대상**이다.
근거가 있으면 보고 후 사용자 동의로 재결정하고, 뒤집은 항목은 *원래 / 재결정 / 근거* 세 칸으로
남긴다. 임의 변경은 금지다. **이 문서는 confirmed 를 뒤집지 않았다.** 잠정 ⟨D7⟩ 의 두 조각을
사용자 동의로 재결정했고 세 칸 기록은 `## 결정 기록` 의 `### 재결정` 절에 있다.

## Goal

공유 문서 리뷰 엔진이 재리뷰 상한 · 사용자 피로가 아니라 **문서 상태(must-catch 0건)** 로 멈춘다.
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

- **G1** 프로필이 must-catch 축을 지목하고, 그 밖의 rubric 축 finding 은 승인을 막지 않는다 ⟨D11⟩.
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
- 프로필 본문(리뷰어가 읽는 검토 항목)의 수정 — 라우팅은 리뷰어가 알 필요가 없다.

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

- **advisory 축 = (`layer_rubric.layer1` ∪ `layer2`) − `must_catch`.** 그 밖은 전부 must-catch:
  rubric 밖 category · `other` · 엔진이 만든 category(`frozen_change` · 재상승 · 상향 후속).
- 필드 부재 → advisory 축 공집합 → 현행과 같다.
- 스키마 거부: rubric 에 없는 축 → `must_catch_unknown_axis:<축>`, 빈 목록 → `must_catch_empty`
  (막는 축 0 은 「무엇으로도 멈춘다」다).

| 프로필 | `must_catch` | advisory 축 |
|---|---|---|
| brief | 층 2 여섯 — `distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported` | `direction, overdesign` |
| design-doc | `goal_fit, problem_definition, scope, architecture` (brief §2 대조 네 축) | 층 1 나머지 다섯 + 층 2 일곱 |
| seed | 층 1 네 축 전부 | 없음 — 동작 불변, 지목은 명시용 |

### §B 라우팅

`_classify_items` 에서 처분 강제 뒤 · 앵커 분류 앞에 한 분기: category 가 advisory 축이고 처분이
`drop` 이 아니면 `advice` 로 보낸다(처분 `decide` · `ask` · `fix` · `defer` 무관). decides · fixes · asks
원장에 들어가지 않으므로 승인 술어는 그대로 must-catch 만 본다. 재비판 `reject` 는 지금처럼 기각
회계로, `drop` 은 지금처럼 drop 회계로 간다. 보호 헤딩 승격 · immutable 승격은 must-catch 에만 걸린다.

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
| design doc | `reviewing-spec` 승인 게이트 1단계 앞 | 같은 렌더 한 번 | `advice --sink <doc>` → `### Deferred to plan` (얼림 면제 절) |
| seed | — | 항상 0건 | 없음 |

design doc 의 박제처가 `Deferred to plan` 인 것은 writing-plans 가 그 절을 읽기 때문이다 — ⟨C4⟩ 의
「writing plan 에서 한 번 더 본다」가 이 자리에서 물리적으로 성립한다.

### §E 관측 — 멈춤 보장의 정직한 경계

- **멈춤의 최종 보증은 재리뷰 상한 2 다.** must-catch 축은 전문 대조라(G4) 재샘플링을 막는 장치가 없다.
- **`mc_preexisting_new`** — 라운드 n ≥ 2 에서 must-catch 로 분류된 리뷰어 finding 중 새 계보(계보 연결
  · 재상승 후속이 아님)이고 앵커 절 해시가 스냅숏 n−1 과 n 에서 같은 것의 수. 게이트 렌더의 참고 줄에
  싣는다. 동작을 바꾸지 않는다 — RC31(「전문 재대조에서 재샘플링이 잦아든다」)이 성립하는지를 다음
  사이클들이 셀 수 있게 한다(OQ17).
- **접근 B 로 올라갈 트리거** — 라운드 2 이상의 `advice_new` 가 cap(8)을 넘는 일이 반복되면 재비판자
  diff 자격(`### 재결정` R1)을 연다. 재료는 finalize 보고서에 이미 있다.

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

- **AC1** brief fixture 에서 `direction` finding 만 나온 라운드 1 은 `approval_ready` 가 참이고
  `round_gate_needed` 가 거짓이다. 같은 fixture 의 `distortion` finding 은 decides(또는 fixes)에 있다.
- **AC2** rubric 밖 category · `other` · `frozen_change` 는 `must_catch` 가 있는 프로필에서도 차단 원장에
  간다. 여집합 계산을 뒤집는 변이(advisory = must_catch)는 AC1 · AC2 를 RED 로 만든다.
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
- **AC8** 라운드 입력 수 = must-catch 원장 유입 + `advice`(listed + repeat) + 재비판 기각 + drop — 자리별
  등식이 fixture 에서 성립한다(합계 하한이 아니다).
- **AC9** `mc_preexisting_new` 는 해시 불변 절의 새 계보 must-catch 만 센다 — 바뀐 절의 것 · 계보 후속은
  세지 않는다.
- **AC10** 번들 빌더 · inline 블롭 빌더는 payload 에 자기 `audit_file` basename 이 있으면 rc 3, 다른
  `*.audit.md` 경로만 있으면 rc 0.
- **AC11** 절차서 · `reviewing-brief` · `reviewing-spec` · `finishing.md` 의 문면이 §D 의 한 번 표시 ·
  박제 절차를 싣고, 그 문면이 부르는 서브커맨드 · 플래그가 실재한다.
- **AC12** 착수 전 baseline 대비 `shared/tests/test_docreview_*.sh` · `plugins/quality-gates/tests/test_recritic_bridge.sh`
  · 이 파이프라인을 참조하는 spec-distill 테스트의 rc 와 실패 줄 수가 늘지 않는다.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `shared/docreview/scripts/docreview_state.py` | `OPTIONAL_PROFILE_FIELDS` · `must_catch` 스키마 · `advice` 원장 기본값 · `gate_summary` 의 참고 계수 · 렌더 참고 줄 · `advice` 서브커맨드 |
| `shared/docreview/scripts/docreview_route.py` | `_classify_items` 분기 · 보고서 `advice_new` · `advice_repeat` · `mc_preexisting_new` |
| `plugins/spec-distill/references/docreview-profiles/{brief,design-doc,seed}.md` | frontmatter `must_catch` 한 줄씩 |
| `plugins/spec-distill/references/reviewing-document.md` | 7 · 8단계의 advice 분기 · 끝의 한 번 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` · `reviewing-spec/SKILL.md` | `## 게이트` 끝의 `advice` 호출 |
| `plugins/spec-distill/skills/conducting-interview/references/finishing.md` | Step B 의 참고 목록 표시 · §3/§5 박제 규칙 |
| `plugins/spec-distill/scripts/build_brief_bundle.py` · `build_brief_inline_blob.py` | 위생 판정(`AUDIT_NAME_RE` · `AUDIT_SUFFIX_RE`)을 자기 audit basename 으로 |
| `shared/tests/test_docreview_{route,state,profile_schema,golden}.sh` · spec-distill 번들 테스트 | AC1~AC10 |
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

### 재결정

| # | 원래 | 재결정 | 근거 |
|---|---|---|---|
| R1 | ⟨D7⟩(잠정) 라운드 2 이상은 finding 자격을 diff 도입분 + 이음매로 좁힌다(advisory 축 — ⟨D12⟩) | 연기 — §C 버킷 1회 규칙이 advisory 재샘플링을 흡수하고, diff 자격은 §E 트리거로 연다 | 라우팅 분리 뒤 advisory 는 승인도 질문도 막지 않아 diff 자격의 이득이 목록 길이뿐이고, 그 비용(본문 사본 · diff · persona 규칙 · 락)이 이득보다 크다. 사용자 선택 B3 |
| R2 | ⟨D7⟩(잠정) 재제기 금지는 전 축 | advisory 축만(§C). must-catch 는 재제기를 허용하고 `revived` 로 공시 | 탐지기는 사용자 결정을 못 봐 「새 근거」를 판정할 수 없고, 버킷으로 막으면 같은 절의 새 충실도 결함이 묻힌다(fail-closed). 사용자 선택 B5 |
