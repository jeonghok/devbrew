# spec-distill brief 포맷·producer 재설계 (Spec A)

> *brief는 방향을 잡는 문서다. 컨텍스트를 제약하는 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다.*
> — 사용자, 2026-07-25 (제약 C5)

interview brief를 핸드오프 아티팩트로 재설계한다. 라운드마다 결정을 잠그는 producer를 제거하고, 확정 권한을 사용자에게 되돌리며, payload를 역피라미드로 재배치·압축한다.

## 목차

- [Handoff Context](#handoff-context)
- [1. Context / Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. 설계](#5-설계)
  - [5.1 아키텍처 — 권위 경로 네 곳](#51-아키텍처--권위-경로-네-곳)
  - [5.2 데이터 흐름](#52-데이터-흐름)
  - [5.3 payload 레이아웃](#53-payload-레이아웃)
  - [5.4 게이트 계약](#54-게이트-계약)
  - [5.5 에러 처리 · graceful degradation](#55-에러-처리--graceful-degradation)
  - [5.6 락 스코프 — legacy 경로 없음](#56-락-스코프--legacy-경로-없음)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
  - [8.1 구조 테스트](#81-구조-테스트)
  - [8.2 회귀 락 + mutation](#82-회귀-락--mutation)
  - [8.3 탐색 폭 회귀 검증 (AC16, advisory)](#83-탐색-폭-회귀-검증-ac16-advisory)
  - [8.4 수동 검증](#84-수동-검증)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Open Questions 처리](#10-open-questions-처리)
- [11. Metadata](#11-metadata)

---

## Handoff Context

> 이 spec을 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 파악할 수 있게. 대화 컨텍스트를 가정하지 않는다.

**TL;DR** (무엇을·왜):

- spec-distill의 interview brief가 해답공간 결정을 *"확정·재논쟁 금지"* 로 박제해 다음 stage(`superpowers:brainstorming`)의 탐색을 죽인다. 이 spec은 그 권위 문법을 **네 곳에서 동시에** 제거하고 — 그중 진짜 원인은 템플릿이 아니라 라운드마다 결정을 잠그는 `SKILL.md`의 producer다 — 확정 권한을 사용자에게 되돌린다.
- 산출물은 여전히 interview brief다. payload는 역피라미드 8섹션으로 재배치·압축하고, audit(텔레메트리)을 별도 파일로 가른다. **신규 에이전트 0개** — 리뷰 파이프라인은 후속 Spec B.

**Implicit context** (Constraints에 안 박힌, 작업에 필요한 외부 사실):

- `superpowers` brainstorming skill(6.1.1·6.2.0 모두)은 `interview`/`brief`/`locked_directions`를 **한 번도 참조하지 않는다.** frontmatter 필드는 소비자가 없고 전달은 순수 프로즈 경로다 — 그래서 `status` 같은 새 필드도 하류가 자동으로 읽어주지 않는다. 계약 전달 채널은 orchestrator의 호출 프롬프트뿐이다.
- `superpowers` 6.2.0에서 `Key Principles`의 *"Explore alternatives — Always propose 2-3 approaches before settling"* 줄이 삭제됐다. 하류의 탐색 지시가 체크리스트 4번 1곳으로 줄어 brief의 과잉결정이 더 해롭다. 외부 플러그인이라 손대지 않는다.
- `check_brief.py gate`는 **인터뷰 종료 직전 방금 쓴 brief에만** 실행된다. 과거 brief 파일을 게이트에 넣는 경로는 코드에도 절차에도 없다 — 이 사실이 §5.6(legacy 경로 불필요)의 근거다.
- `check_brief.py`는 `state.local.md`를 읽지 않는다. brief 파일만 본다. state에 있는 것을 게이트로 집행하려면 brief에 직렬화돼 있어야 한다.
- `_web_disabled()`(`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`)가 §4 인용 요구를 완화하는 기존 graceful-degradation 선례다.
- devbrew 금지 패턴 *Unbounded autonomy* — 사용자 확인 루프에는 상한과 초과 시 동작이 반드시 있어야 한다.

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 것):

- 템플릿 §0–§7 각 섹션의 **문구·설명문 표현.** 섹션 이름·번호·분량 예산만 lock하고 안내문 wording은 구현 재량.
- `check_brief.py` 내부 함수 분해 방식(기존 `_section_text`/`_entry_lines` 재사용 범위, 신규 헬퍼 이름).
- 테스트 파일 배치(기존 `tests/` 구조에 맞춰 구현이 결정).
- `CHANGELOG.md` 항목 문구.
- **기록 이후 원문 정정 경로**(오타·사용자 철회를 덮어쓰기가 아니라 승인 이벤트로 남기는 메커니즘). 스키마·저장 위치가 미정이고 Spec A는 편집 경로를 만들지 않는다 — 검증 배정 없는 규칙을 문서에 남기지 않기 위해 스코프에서 뺀다.

---

## 1. Context / Why

**입력**: `docs/superpowers/interview/2026-07-25-spec-distill-brief-handoff-redesign-interview.md` (+ `.audit.md`).

**증상**: brainstorming stage가 해답공간 탐색을 하지 않는다. brief가 결정을 *"확정·재논쟁 금지"* 로 박제해 하류의 잠재공간을 좁힌다.

**근본 원인 — 권위 문법은 템플릿 한 곳이 아니라 네 곳에 있다.** interview brief는 이를 "정보 문법과 배치" 문제로 진단했으나, 코드베이스 확인 결과 더 상류에 producer가 있다:

| 위치 | 하는 일 |
|---|---|
| `skills/conducting-interview/SKILL.md:129–150` | 매 round 끝, 사용자가 명시적으로 답하면 **수락이든 거절이든 `locked? = true`** → `LD<N>` append. LD 레코드는 `section: "#<spec-section-anchor>"` 까지 부착해 답변 즉시 해답공간 슬롯에 바인딩 |
| `templates/interview-brief-template.md:31` | §2 헤더에 *"재논쟁 금지"* |
| `skills/conducting-interview/SKILL.md:405` | `/compact` 문구가 *"Locked Directions … 보존"* 을 직접 주입 |
| `scripts/check_brief.py:214` | `locked_directions` 키 부재 시 게이트 실패 — 필수 필드 |

과거 brief 3건의 LD 개수 9 / 6 / 5는 모델의 과잉 잠금이 아니라 **skill이 지시한 대로 동작한 결과**다. 그러므로 템플릿만 고치면 producer가 계속 LD를 찍어낸다.

**이 spec의 범위**: 인터뷰 결과물은 「포맷·producer 교체」와 「리뷰 파이프라인 신설」 두 덩어리다. 사용자 결정으로 **두 spec으로 분리**하고, 이 문서는 전자(Spec A)만 다룬다. Spec B(brief-critic / 방향성 리뷰 / readback / codex)는 Spec A가 실제 brief를 산출한 뒤 그 실물을 입력으로 설계한다.

---

## 2. Goals

1. **라운드별 잠금 producer 제거.** 인터뷰가 진행 중 결정을 확정하지 않는다.
2. **확정 권한을 사용자에게.** `status: confirmed`는 사용자의 명시적 확인 행위로만 발생한다.
3. **payload 재배치·압축.** 행동 항목(제약·Open Questions)을 앞으로, 근거·원문을 뒤로. 모델 산문을 압축하되 사용자 원문은 전문 보존. 정량 목표는 AC15가 지표로 집행한다(advisory).
4. **Spec B가 소비할 frontmatter 계약 확정.** `source × status × evidence`를 지금 못 박아 B가 포맷을 재작업하지 않게 한다.
5. **drift-guard 두 축.** payload↔audit(§5.4 ST bijection)과 body↔frontmatter(§5.4 항목 bijection). 후자가 ☑ laundering을 막는 안전-critical 축이다.
6. **재발 방지 락.** 권위 문법 재도입을 기계적으로 막는다.

---

## 3. Non-goals

- **리뷰 파이프라인** — brief-critic(D2) / 방향성 리뷰(D5) / readback(D3) / codex 프롬프트 빌더(D4)는 전부 Spec B.
- **`agents/spec-reviewer.md` NG3 문구 수정** — Spec A는 리뷰어를 만들지 않으므로 *"brief는 분리 review 대상이 아니다"* 가 여전히 사실이다. `check_brief.py` docstring의 NG3 서술도 동일하게 유지.
- **기존 brief 3건 마이그레이션** — §5.5·§5.6 참조. 불필요.
- **`superpowers` 플러그인 자체 수정** — 외부 플러그인. 하류의 약화(6.2.0 원칙 줄 삭제)는 관측 사실로 기록만 한다.
- **분량 감축을 위한 사용자 원문 발췌** — 원문은 압축 대상이 아니다(§5.3).
- **모델 추론 항목의 기계 검증** — ✎ 항목은 frontmatter 계약 밖 프로즈다(§5.2). 게이트 대상이 아니다.

---

## 4. Constraints

인터뷰에서 확정된 것. `source`(누가) × `status`(얼마나 굳었나) 두 축. 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론.

| id | source | 내용 |
|---|---|---|
| **C5 (최상위)** | 🗣 | brief는 방향을 잡는 문서다. 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다. 규약·프로토콜은 brief가 아니라 그것을 집행하는 곳(템플릿·SKILL·에이전트 프롬프트)에 산다. **다른 제약과 충돌 시 이것이 이긴다.** |
| C1 | 🗣 | 다음 세션에서 보고 바로 이해되는 내용이 최상단에 온다 |
| C2 | 🗣 | 사람이 한 말은 표기로 구분한다. **표기는 provenance(이 항목이 어디서 왔나)를 가리키며 문장의 저자를 가리키지 않는다** — §2 statement는 모델이 쓴 요약이고 원문은 §6에 있다. ✎ 이 구분은 브레인스토밍에서 도출돼 리뷰 round-5에서 사용자 재확인을 받았다(C4 경로) |
| C4 | 🗣 | 사용자 출처 항목도 이유가 있으면 보고 후 재결정 가능. 임의 변경만 불가 |
| C3 | ☑ | 표기 규약은 개별 brief가 아니라 템플릿 차원 — 2줄 고정 블록 |
| C6 | ☑ | `source`와 `status`를 직교 분해. 사용자 출처라는 사실만으로 확정 제약이 되지 않는다 |
| D1 | ☑ | payload + audit 2파일. 분할선 = *재논쟁 차단에 쓰이는 것은 payload / 순수 텔레메트리만 audit* |

브레인스토밍에서 추가로 확정한 것:

| id | source | 내용 |
|---|---|---|
| B1 | ☑ | 두 spec으로 분리 — A(포맷·producer) 먼저, 실물 산출 후 B(리뷰 파이프라인) |
| B2 | ☑ | `status`는 종료 직전 사용자 일괄 확인으로 결정 |
| B3 | ☑ | payload 레이아웃 = 역피라미드 + 압축, 8섹션, 원문 전문 보존 |
| B4 | ☑ | 탐색 폭 측정은 **설계 후 회귀 검증**으로 배치 |
| B5 | 🗣 | *"legacy는 마지막 시점에 제거하자"* (원문 그대로) |
| B5′ | ✎ | B5의 **모델 강화 해석** — legacy 분기를 처음부터 만들지 않는다 |

> ✎ B5′는 사용자 발화가 아니라 모델 해석이므로 ✎로 표기한다. 근거: 리뷰가 legacy 분기의 존치 시나리오를 반증했다(§5.6·§9). 사용자 의도(legacy를 잔존시키지 않음)는 보존되고 중간 상태만 사라진다. C4에 따라 사용자 재결정 대상이며, 되돌리려면 §5.6과 AC13 스코프만 고치면 된다.
>
> ✎ *이 표기 자체가 이 설계의 자기적용이다.* 초안은 B5 행에 강화 해석을 넣고 `source: 🗣`로 달아 — 이 재설계가 봉쇄하려는 바로 그 source 오표기를 스스로 저질렀다(리뷰 round-2 적발).

**보안·정책 제약**: `CLAUDE.md` P21(state에 secret 금지 — placeholder 참조), Law 2(리뷰어는 `tools:` allowlist로 쓰기 차단 — Spec A는 에이전트를 만들지 않으므로 해당 없음), 킬 스위치 `DEVBREW_DISABLE_SPEC_DISTILL=1`, 플러그인 편집 시 `plugin.json` SemVer bump 필수.

---

## 5. 설계

### 5.1 아키텍처 — 권위 경로 네 곳

| 위치 | 지금 | 이후 |
|---|---|---|
| `SKILL.md:129–150` producer | decision table → `LD<N>` (`section:` 앵커 부착) | **decision table 삭제.** `user_statements`에 발화만 append — `status` 없음, 해답공간 앵커 없음 |
| `SKILL.md` 종료 단계 | `pending_locked_decisions` → `locked_directions[]` | 기존 `/compact` proceed 게이트에 **확정 확인을 흡수** |
| `templates/interview-brief-template.md` | §2 Locked Directions, *"재논쟁 금지"* | §0–§7 역피라미드 + `user_sourced_items[]` |
| `SKILL.md:405` compact handoff | *"Locked Directions … 보존"* | 새 섹션명 + **C4 프로토콜을 호출 프롬프트로 전달** |
| `check_brief.py` | `locked_directions` 필수 | `user_sourced_items` 필수 + 스키마 검증 + 2파일 스코프 + 두 bijection |

**C5 ↔ OQ1 충돌 해소.** `superpowers:brainstorming`은 spec-distill을 모르고 `locked_directions`를 0건 참조한다. 그러니 `status`도 참조하지 않을 것이다. C4 프로토콜을 brief에 넣으면 C5 위반이고, 넣지 않으면 하류 도달 경로가 없다.

→ 규약은 C5가 지정한 자리 그대로 **orchestrator의 호출 프롬프트**에 산다. brief 파일은 순수 데이터(`source`/`status`/`evidence`)만 나르고, *"confirmed 항목은 근거 있으면 보고 후 재결정, 임의 변경 금지"* 는 `SKILL.md`가 brainstorming을 호출할 때 함께 보내는 문장이다. `/compact` 경로(옵션 ①)와 직행 경로(옵션 ②) 양쪽 모두에 동일 문장을 싣는다.

### 5.2 데이터 흐름

**라운드 중** — `state.local.md`:

```yaml
user_statements:                    # pending_locked_decisions 대체
  - {id: S1, source: verbatim, round: 1, text: "<사용자가 실제로 한 말>"}
  - {id: S2, source: chosen,   round: 3, text: "<고른 선택지 라벨 + 요지>"}
```

`status` 없음. `section:` 앵커 없음 — 문제공간 인터뷰가 라운드마다 해답공간 슬롯에 바인딩하던 경로가 사라진다. `text`에는 P21 placeholder 치환을 적용한다.

**종료** — 새 의례를 만들지 않고 기존 `/compact` proceed 게이트에 흡수:

```
brief 초안 작성 (user_sourced_items 전부 status: provisional)
  → check_brief.py gate                    (confirmed 0건 sentinel 허용)
  → 확정 후보 목록을 프로즈로 출력
  → AskUserQuestion  ① 확정하고 /compact 후 brainstorming (권장)
                      ② 확정하고 바로 brainstorming
                      ③ 확정 목록 수정
                      ④ brief만 종료
       ①/② → status 반영 → 재저장 → 게이트 재실행
              ① → /compact 노출 → STOP (다음 턴 사용자 트리거로 brainstorming 진입)
              ② → 즉시 brainstorming 호출 (compact 없이)
       ③ → 수정 반영 후 재제시 (상한 2회)
       ④ → terminal 종료, handoff 없음
```

**옵션이 넷인 이유.** 설계 초안의 확정 확인 3지선다(①/②/③ = 확정·수정·중단)와 이미 shipping된
handoff 3지선다(`/compact` 경유 / 직행 / brief만 종료)를 그대로 합치면 종료 시 사용자 상호작용이
2회가 되어 §9가 기각한 *"별도 status 확인 게이트 신설"*과 동형이 된다. 반대로 `바로 brainstorming`을
없애면 Non-goals가 제거 대상으로 적지 않은 shipped 기능이 조용히 사라진다. 단일 게이트에 옵션을
4개(`AskUserQuestion`은 2–4옵션 허용) 실어 두 요구를 동시에 만족한다 — 상호작용은 여전히 1회.

**재제시 상한**: 최초 제시는 0회째다. 옵션 ③을 고를 때마다 재제시 횟수가 1 증가하고 **2회까지** 허용한다. 3번째 ③ 요구 시 전 항목을 `provisional`로 강등하고 고정 문자열 advisory를 출력한 뒤, 게이트를 재제시하지 않고 ④와 동일한 terminal 경로로 종료한다(handoff 없음 — 사용자가 확정-후-진행 옵션(①/②)을 고른 적이 없으므로, 게이트 없이 brainstorming으로 자동 진행하는 쪽이 아니라 종료하는 쪽이 안전한 방향이다):

```
[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등
```

**후보 선별은 모델이 한다.** `user_statements` 전체를 훑어 각 항목에 후보 `status`를 붙이고, `confirmed` 후보를 목록으로 제시한다 — 제외한 것도 한 줄로 함께 보여야 사용자가 누락을 잡을 수 있다. 확정 목록이 길 수 있으므로 목록은 **프로즈로 출력**하고 `AskUserQuestion`은 4지선다만 담당한다. 모델의 후보 판정은 제안일 뿐이고 `confirmed`로의 전이는 확정-후-진행 옵션(①/②) 선택으로만 일어난다.

**frontmatter 계약** (Spec B의 critic이 소비):

```yaml
audit_file: 2026-07-25-<topic>-interview.audit.md   # basename only (AC9)
user_sourced_items:
  - id: C1
    source: verbatim | chosen        # inferred는 이 리스트에 들어가지 않는다
    status: confirmed | provisional | open
    statement: "<160자 이내, P21 placeholder 치환>"
    evidence: S3                     # §6 원문의 어느 발화에서 나왔는가 — 필수
```

**`user_sourced_items`는 이름 그대로 사용자 출처만 담는다.** `source: inferred`는 이 리스트에 들어갈 수 없고(게이트 fail), 모델 추론은 본문 프로즈에 ✎ 표기로만 산다 — 하류가 C4의 재결정 프로토콜을 적용할 대상이 아니기 때문이다. 그 결과 **`evidence`는 예외 없이 필수**가 되고, codex 리뷰가 인터뷰 brief에서 적발한 "☑ laundering"(사용자가 고르지 않은 것을 ☑로 표기)이 기계적으로 봉쇄된다.

**`statement`는 원문이 아니라 모델이 쓴 제약 진술이다.** 160자 cap은 **hard**(초과 시 게이트 fail, T23) — 사용자 발화는 길이 제한이 없으므로 `statement`가 원문이었다면 이 cap이 §5.3의 *"압축 대상은 모델 산문에 한정"* 원칙과 충돌한다. 충돌하지 않는 이유는 둘이 서로 다른 것이기 때문이다:

- **§2 `statement`** = 모델이 요약한 제약 한 줄. 압축 대상.
- **§6 원문** = 사용자 발화. 압축 대상 아님(§5.3 "전문 보존").

따라서 §2 항목의 기호(🗣/☑)는 **문장의 저자가 아니라 provenance**를 가리킨다. 이 구분이 무너지지 않게 붙드는 것이 `evidence: S<N>`이며, 그래서 예외 없이 필수다 — 요약이 어느 원문에서 나왔는지 추적할 수 없으면 🗣 라벨은 근거 없는 주장이 된다. 160자에 담기지 않는 제약은 대개 제약이 둘이라는 신호다.

⚠ **`evidence`가 강제하는 것은 추적 가능성이지 정확성이 아니다.** bijection C는 인용된 `S<N>`의 *존재*만 검사한다 — 요약이 그 원문을 실제로 뒷받침하는지(의미적 정합)는 **기계 검증하지 않는다.** 모델이 실재하는 아무 `S<N>`을 붙여도 게이트는 통과하므로, ☑ laundering은 *줄어들 뿐 봉쇄되지 않는다.* 이 갭은 V9 수동 spot-check가 맡으며, 여기서 그것을 숨기지 않는 이유는 V4·V5·V8과 같다.

**body §2 항목 문법** — frontmatter와 대조되는 쪽이므로 형식을 고정한다:

```markdown
- 🗣 confirmed **C1** — <statement> ⟨S3⟩
- ☑ provisional **D2** — <statement> ⟨S7⟩
```

기호↔`source` 매핑은 🗣→`verbatim`, ☑→`chosen`. ✎ 항목은 이 문법을 쓰지 않는다(프로즈 주석).

**`⟨S<N>⟩` 접미가 요약임을 알리는 시각 신호다.** §6 원문은 blockquote(`> "..."`)로 렌더되고 §2는 인용부호 없는 평문 + 원문 포인터로 렌더된다 — 두 자리를 눈으로 구분할 수 있어야 *"🗣이니까 이게 사용자가 한 말 그대로"* 라는 오독이 막힌다. 템플릿의 §2 머리에 한 줄을 고정한다: *"이 절의 진술은 모델이 쓴 요약이다. 원문은 §6, `⟨S<N>⟩`가 그것을 가리킨다."* statement의 경계는 `— ` 뒤부터 ` ⟨S`  앞까지다.

§6 원문 섹션이 `S<N>` 앵커를 제공한다:

```markdown
- **S1** 🗣 최초 요청:
  > "..."
```

### 5.3 payload 레이아웃

역피라미드 + 압축. **압축 대상은 모델이 쓴 산문에 한정**하고 사용자 원문은 손대지 않는다 — 원문을 발췌본으로 만들면 Spec B critic의 ground truth가 무너져 「Blind Spots」가 경고한 *"재구성 대 재구성의 순환 검증"* 이 실제로 성립한다.

| § | 섹션 | 분량 예산 | 역할 |
|---|---|---|---|
| 0 | 한눈에 | ≤15줄 | 무엇/왜/확정/열림/다음 stage |
| 1 | Goal · Non-goal | ≤12줄 | |
| 2 | 제약 | ≤30줄 | §5.2 항목 문법 + ✎ 프로즈 |
| 3 | Open Questions | ≤25줄 | **탐색 대상을 앞으로** |
| 4 | External Landscape | ≤20줄 | 1항목 = 1줄, URL 필수 |
| 5 | 기각 · Blind Spots | ≤25줄 | verdict 항목은 `ST<N>` 참조 필수 |
| 6 | 사용자 원문 | 무제한 | **전문 보존.** `S<N>` 앵커 제공 |
| 7 | Next Action | ≤10줄 | |

**세 수치의 관계** — 현행 payload 272줄은 사용자 원문 53줄 + 모델 산문 219줄이다. 위 예산 합계(§6 제외)는 **137줄**이므로 모델 산문 기준 **-37%**다. 게이트의 advisory 임계치는 **150줄**(§6 제외) — 예산 137에 slack 13줄을 얹은 트립와이어다. 절별 예산은 저술 목표이고 150은 총량 경보선이며, 둘 다 **advisory**라 brief를 막지 않는다(AC15). 원문(§6)은 분량 무제한이므로 총 줄수는 인터뷰 길이에 따라 달라진다.

#### "전문 보존"의 정의

*전문 보존*은 **글자 불변이 아니라 provenance 보존**이다(인터뷰 brief의 결론 이관). 글자 불변으로 못 박으면 `CLAUDE.md` P21의 secret placeholder 치환과 정면충돌한다.

- **대상 코퍼스** = `state.local.md`의 `user_statements`에 기록된 발화 전부. 모든 사용자 턴이 아니라 orchestrator가 라운드 중 기록한 것들이며, 각각이 §6의 한 `S<N>` 항목이 된다.
- **허용 변환**: P21 secret placeholder 치환(**필수**) · 앞뒤 공백 정리 · 마크다운 인용 블록 래핑.
- **금지**: 요약 · 재서술 · 발췌 · 문장 삭제.

게이트가 검증할 수 있는 것은 **bijection C**(모든 `evidence: S<N>`가 §6에 해석됨)까지다. **완전성**(기록된 발화가 하나도 빠지지 않고 §6에 있는가)은 `check_brief.py`가 `state.local.md`를 읽지 않으므로 기계 검증이 불가능하며 V8 수동 검토가 담당한다.

§6 상단에 C3의 2줄 고정 블록:

```markdown
> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론
```

U자 배치: 앞 = 스냅샷 + 행동 항목(제약·OQ), 뒤 = 원문(대조용 참조) + Next Action.

### 5.4 게이트 계약

```python
SECTIONS = [("0","한눈에"), ("1","Goal · Non-goal"), ("2","제약"),
            ("3","Open Questions"), ("4","External Landscape"),
            ("5","기각 · Blind Spots"), ("6","사용자 원문"), ("7","Next Action")]

AUDIT_SECTIONS = [("1","Coverage Ledger"), ("2","Budget"), ("3","Steelman 원문"),
                  ("4","게이트 실행 기록"), ("5","프로세스 로그")]
```

**두 목록 모두 존재 검사 대상이다.** audit 섹션도 계약이다 — `coverage_ledger_failures()`와 steelman 대조는 섹션 번호+제목 정규식으로 본문을 잘라내므로, audit 쪽 번호가 바뀌면 검증이 조용히 빈 문자열을 읽고 통과한다.

**2파일 fail-open 봉쇄.** Coverage Ledger와 Steelman이 audit으로 이동하는데 게이트가 payload만 읽으면 두 검증이 통째로 증발한다 — interview brief가 OQ7로 경고한 지점이다.

```python
audit_file = fm["audit_file"]                    # 필수 키, 없으면 FAIL
if Path(audit_file).name != audit_file: FAIL     # basename만 — traversal 거부
audit = payload.parent / audit_file
if not audit.exists(): FAIL                      # fail-closed
```

`audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(P21 계보). 파일 읽기는 `encoding="utf-8"` 명시 — non-UTF-8 locale에서 fail-open 방지.

#### bijection A — payload §5 ↔ audit §3 (drift-guard, 파일 축)

**개수 비교가 아니라 id 집합 비교다.** 개수 비교는 "무엇을 한 항목으로 셀 것인가"가 미정이라 집행이 불가능하다 — 실제 audit의 steelman 항목은 다단락 블록이지 단일 `- ` 불릿이 아니다. 대신 양쪽에 안정 id를 박는다:

- audit §3 항목: `#### ST<N> — <한 줄 요지>` 헤딩. 본문(verbatim 원문)은 그 아래 자유 형식.
- payload §5 verdict 항목: `- <요지> — <URL> — verdict: defended|switched|deferred — ST<N>`

게이트는 payload §5가 참조하는 `ST<N>` 집합 == audit §3의 `#### ST<N>` 집합인지 검사한다. 불일치는 양방향 모두 결함이다 — payload가 남으면 *원문 없는 판정*(근거 증발), audit이 남으면 *판정 없는 steelman*(R3 미충족). **양쪽 공집합(steelman 0건)은 그대로 허용하며 별도 sentinel을 요구하지 않는다** — 공집합 == 공집합은 그 자체로 정합이고, steelman은 조건부로 발동하므로 0건이 정상 상태다. sentinel이 필요한 것은 R4(`기각` 0건)뿐이다: 거기서는 *"검토를 안 함"* 과 *"검토했으나 폐기가 없었음"* 을 가려야 하기 때문이다. 두 공집합 조건(`기각`=0 vs steelman=0)은 서로 다르므로 같은 sentinel을 공유하지 않는다.

payload §5 verdict 항목 자체는 기존 `skepticism_malformed()` 규칙에 `ST<N>` 참조를 더해 검사한다: URL ≥1 + statement ≥10자 + 유효 verdict 토큰 + `ST<N>` 참조. (`_web_disabled()` 시 URL 요구는 기존대로 완화.)

#### §5 항목 문법 — R4 통과 의례 보존

구 §7 `Tried & Discarded`가 §5로 병합된다. 현행 `tried_discarded_ok()`는 §7이 비어 있으면(N/A sentinel 없이) fail시켜 *"포기한 방향은 이유와 함께 기록되거나 명시적 N/A"* 를 보장하는데, **§5 검증을 steelman verdict 항목에만 걸면 그 보장이 증발한다** — steelman이 트리거되지 않고 사용자가 그냥 폐기한 방향은 검증 대상에서 빠지고, §5가 헤더만 있어도 통과한다. 병합은 표현의 통합이지 의례의 폐기가 아니므로 항목 종류를 문법으로 가른다:

```markdown
- 기각 — <시도한 방향> → <버린 이유>
- 기각 — <시도한 방향> → <버린 이유> — <URL> — verdict: defended — ST1
- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>
```

- **`기각` 항목이 0건이면 fail** — 명시 sentinel `- 기각 — N/A — 전부 first-time defend+lock` 없이는 통과 불가. R4 규칙을 그대로 이관한다.
- **bijection A는 `verdict:` 토큰을 가진 `기각` 항목에만 적용된다.** steelman이 없는 기각은 `ST<N>` 참조를 요구받지 않는다.
- `위험` 항목은 구 §5 Blind Spots의 이관분이며 bijection 대상이 아니다.

#### 표기 블록 존재 검사

§6 상단의 2줄 출처 표기 블록(C3)은 템플릿이 상속시키는 것이지만, 개별 brief에서 지워질 수 있으므로 게이트가 확인한다: §6에 `🗣`·`☑`·`✎` 세 기호를 모두 포함한 인용 줄이 ≥1개 존재해야 한다.

#### bijection B — body §2 ↔ frontmatter (drift-guard, 안전 축)

파일 축에 drift-guard를 두면서 **어떤 항목이 실제로 `confirmed`인가** 라는 더 안전-critical한 축을 비워두면, 이 재설계의 존재 이유 바로 그 자리에 사각지대가 남는다. §5.2가 body 항목 문법을 고정한 것은 이 대조를 가능하게 하기 위해서다.

- frontmatter `user_sourced_items[].id` 집합 == body §2의 🗣/☑ 항목 id 집합 (양방향 — 어느 쪽이 남아도 fail)
- 각 id에 대해 body 기호와 frontmatter `source`가 일치 (🗣↔`verbatim`, ☑↔`chosen`)
- 각 id에 대해 body `status` 토큰과 frontmatter `status`가 일치
- 각 id에 대해 body의 `⟨S<N>⟩`가 frontmatter `evidence`와 일치
- 각 id에 대해 **body statement가 frontmatter `statement`와 정규화 후 동일**. frontmatter가 canonical이고 body는 그 렌더다 — id·기호·status만 맞추면 두 표현이 같은 라벨을 달고 **서로 다른 제약을 말해도 통과**한다. 정규화 = 앞뒤 공백 제거 + 연속 공백 1개로 축약 + 마크다운 강조 기호(`**`, `*`, `` ` ``) 제거

**빈 확정 금지.** `status: confirmed` 항목이 0건이면 명시 sentinel(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`) 없이는 fail. sentinel 없는 0건은 확인 게이트를 건너뛴 신호다.

#### 분량 지표 (advisory)

게이트가 `payload_body_lines_excl_verbatim` 값을 출력한다. 계수법: frontmatter 제외, `## 6.` 섹션 전체 제외, 빈 줄 제외, 나머지 줄 수. 150 초과 시 advisory 한 줄을 내되 **fail하지 않는다** — 분량은 목표이지 정확성 조건이 아니다.

### 5.5 에러 처리 · graceful degradation

| 상황 | 동작 |
|---|---|
| audit 파일 부재·읽기 실패 | **fail-closed** — 게이트 red |
| `audit_file`이 basename 아님 | fail |
| web 비활성 (`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`) | 기존 `_web_disabled()` 완화 유지 — §4·§5 인용 요구 완화 |
| 확정 확인 재제시 상한 초과 | 전부 `provisional` 강등 + 고정 advisory. **fail-closed 방향(덜 잠금)이 안전한 쪽** |
| 구 포맷 brief를 게이트에 투입 | `user_sourced_items` 부재 + 섹션 불일치로 red. 별도 안내 분기 없음(§5.6) |

**기존 brief 3건 마이그레이션은 불필요하다.** `check_brief.py gate`는 종료 직전 방금 쓴 brief에만 실행된다 — 과거 파일을 게이트에 넣는 경로가 코드에도 절차에도 없다. 다만 **보존은 필수**다(§8.3 회귀 검증의 대조군, Law 3 기록).

### 5.6 락 스코프 — legacy 경로 없음

초안은 구 포맷 brief를 위한 legacy 감지 분기를 두려 했다. **기각한다.** 존치 근거로 든 시나리오("구현·회귀 검증 중 구 brief를 게이트에 넣을 때")가 실재하지 않기 때문이다 — §8.3의 회귀 검증은 구 brief를 fresh 서브에이전트의 brainstorming에 투입할 뿐 `check_brief.py gate`에 넣지 않고, 다른 어떤 절차도 넣지 않는다. 존재하지 않는 시나리오의 오류 메시지를 다듬으려고 분기 + 2단계 락 스코프 + 제거 태스크 + 전용 T-case를 유지하는 것은 순비용이다.

**결과적으로 락이 단일 단계가 된다.** legacy 분기가 없으므로 `check_brief.py`에 `locked_directions` 문자열이 남을 이유가 없고, 회귀 락은 처음부터 production 전 파일을 스코프로 삼는다. AC 예외 조항도, 제거 태스크도 없다.

구 brief를 게이트에 넣으면 `user_sourced_items` 부재와 섹션 불일치로 red가 난다. 그것이 옳은 동작이다 — 과거 brief는 역사적 기록이지 이 게이트의 입력이 아니다.

---

## 6. Acceptance Criteria

AC1–AC14는 hard(미충족 시 미완료), AC15–AC16은 **advisory**(측정·기록이 조건이고 결과값은 통과 기준이 아니다). 모든 hard AC는 §8에 기계 T-case 또는 수동 V-item이 **명시 배정**된다 — 어느 쪽도 없는 AC는 검증되지 않는 주장이다.

> ✎ *표 무결성 규칙(저술용, shipping 검증 아님)* — 아래 검증 열과 §8.1/§8.4의 AC 열은 **양방향으로 일치**해야 한다. 한쪽만 가리키는 참조는 검증 배정 누락을 감춘다. 대조가 가능하도록 검증 열은 범위 표기(`T3–T6`) 없이 **명시 나열**한다. T15는 특정 AC가 아닌 happy-path 스모크라 AC 열이 `—`인 의도적 예외다.

| # | 기준 | 검증 |
|---|---|---|
| AC1 | `SKILL.md`에 `user_statements`(id/source/round/text) 스키마 블록이 존재하고, 라운드별 `locked?` decision table과 `pending_locked_decisions`가 존재하지 않는다. **부정 절반은 기계 검증이 불완전하다** — 리터럴 락은 이름만 바꾼 동일 구조(예: 변수명을 갈아끼운 라운드별 lock table)를 못 잡는다. AC8과 같은 개방형-부정이므로 V4 수동 검토가 그 몫을 진다 | §8.2 positive grep + V4 |
| AC2 | `status: confirmed`는 종료 proceed 게이트에서 사용자가 확정-후-진행 옵션(①/②)을 고를 때만 발생한다. 최초 제시는 0회째이고 옵션 ③ 재제시는 **2회**까지 허용하며, 3번째 요구 시 전 항목 `provisional` 강등 + 고정 문자열 `[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등` 출력 | V1, V2 |
| AC3 | `SKILL.md`가 `brainstorming`을 호출할 때 C4 재결정 프로토콜 문장(*"confirmed 항목은 근거 있으면 보고 후 재결정, 임의 변경 금지"*)을 함께 싣는다. `/compact` 경로와 직행 경로 **양쪽 모두** | V3 |
| AC4 | payload 템플릿이 §0–§7 8섹션 역피라미드이며, 사용자 원문이 §6에 전문 보존된다(정의는 §5.3) | T1, V8 |
| AC5 | §6에 `🗣`·`☑`·`✎` 세 기호를 모두 포함한 출처 표기 블록이 존재한다(템플릿이 상속, 게이트가 확인) | T18 |
| AC6 | `user_sourced_items[]`의 각 항목이 id/source/status/statement/**evidence**를 갖는다. `source`는 `verbatim`\|`chosen`만 허용하며 `inferred`는 fail. `statement`는 **160자 이내(hard)** — 모델이 작성한 제약 진술이며 원문이 아니다(§5.2). **bijection C**: 모든 `evidence: S<N>` 값이 §6에 대응 항목으로 존재한다(역방향은 요구하지 않음 — 제약으로 승격되지 않은 발화가 있을 수 있다) | T3, T4, T5, T6, T22, T23, V9 |
| AC7 | **bijection B**: frontmatter id 집합 == body §2 🗣/☑ 항목 id 집합(양방향), 각 id의 기호↔`source`·`status` 일치, body의 `⟨S<N>⟩` == frontmatter `evidence`, **그리고 body statement == frontmatter `statement`(정규화 후)** | T8, T9, T21, T24 |
| AC8 | C5 준수 — 닫힌 리터럴 6개는 AC13이 production 전 파일(`README.md` 포함)에서 전부 잠근다(폐쇄 절반). 열거되지 않은 규약 문장이라는 개방형 부정 판정은 리터럴 락으로 증명 불가능하다(개방 절반) — V5가 새 템플릿·`SKILL.md`·`README.md`를 사람이 읽고 그 갭을 맡는다(한계를 숨기지 않는다) | §8.2 + V5 |
| AC9 | `check_brief.py`가 `audit_file`을 필수 키로 요구하고, basename이 아니면 fail, 파일이 없으면 fail한다 | T7 |
| AC10 | `AUDIT_SECTIONS` 5개 전부에 존재 검사가 있고, Coverage Ledger 검증이 audit 파일에 대해 실행된다 | T2, T13 |
| AC11 | **bijection A + R4 보존**: payload §5가 참조하는 `ST<N>` 집합 == audit §3 `#### ST<N>` 집합(양방향). steelman 0건(양쪽 공집합)은 sentinel 없이 허용. `verdict:` 항목은 URL + statement ≥10자 + verdict 토큰 + `ST<N>` 참조를 갖는다. **`기각` 항목이 0건이면 명시 N/A sentinel 없이는 fail**(구 R4 의례 이관 — steelman 공집합과는 다른 조건) | T10, T11, T12, T17, T19 |
| AC12 | `confirmed` 0건이면 명시 sentinel 없이는 fail | T14 |
| AC13 | 회귀 락이 `locked_directions`·`pending_locked_decisions`·`재논쟁 금지`·`Locked Directions`·`다시 묻지 않는다`·`확정·재논쟁` **6개**를 잡고, mutation test로 이빨이 증명된다. 스코프는 production 전 파일(`tests/`·`CHANGELOG.md`·`docs/` 제외) | §8.2 |
| AC14 | `plugin.json` version이 `0.23.x` + `CHANGELOG.md`에 `## [0.23.` 항목 + `README.md`의 "Principles Instantiated"가 **네 사실을 각각 명시**: 라운드별 잠금 제거 · 종료 시 사용자 일괄 확인 · payload/audit 분리 · `user_sourced_items` 계약(V6가 이 체크리스트를 대조한다). 버전 리터럴은 **minor까지만 핀**한다(patch digit unpin — doc-only bump마다 stale-red 방지) | T20 + V6 |
| AC15 *(advisory)* | 게이트가 `payload_body_lines_excl_verbatim`을 출력하고 150 초과 시 advisory를 낸다. **fail하지 않는다** | T16, V7 |
| AC16 *(advisory)* | 탐색 폭 회귀 검증(§8.3)이 실행되고 결과가 audit에 기록된다. **통과 조건은 실행·기록이며 관측 결과값이 아니다** — 어떤 결과도 shipping을 막지 않는다 | §8.3 |

---

## 7. Files to Modify

| 파일 | 성격 |
|---|---|
| `plugins/spec-distill/templates/interview-brief-template.md` | 재작성 — payload 8섹션 + 분량 예산 + 항목 문법 |
| `plugins/spec-distill/templates/interview-audit-template.md` | 신규 — 텔레메트리 5섹션 |
| `plugins/spec-distill/scripts/check_brief.py` | 수정 — SECTIONS/AUDIT_SECTIONS 교체, `user_sourced_items` 스키마, 2파일 fail-closed, bijection A·B, 분량 지표 |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 수정 — producer 교체, 종료 확인 흡수, compact 문구, 호출 프롬프트 계약 |
| `plugins/spec-distill/plugin.json` | `0.23.0` |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.23.0] — 2026-07-25` |
| `plugins/spec-distill/tests/` | 신규 케이스 (§8.1) |
| `plugins/spec-distill/README.md` | "Principles Instantiated" 갱신 |

**신규 에이전트 0개.** Law 2 tool posture는 변경 없음.

---

## 8. Verification Plan

### 8.1 구조 테스트

| # | 케이스 | 기대 | AC |
|---|---|---|---|
| T1 | payload 섹션 8개 각각 제거 | red ×8 | AC4 |
| T2 | audit 섹션 5개 각각 제거 | red ×5 | AC10 |
| T3 | `user_sourced_items` 부재 | red | AC6 |
| T4 | 항목에 `evidence` 없음 | red | AC6 |
| T5 | `source: inferred`가 리스트에 있음 | red | AC6 |
| T6 | 잘못된 `status` / `source` 값 | red ×2 | AC6 |
| T7 | `audit_file` 부재 / `../foo.md` / 파일 없음 | red ×3 | AC9 |
| T8 | body §2에만 있는 id / frontmatter에만 있는 id | red ×2 | AC7 |
| T9 | 기호↔`source` 불일치 / `status` 불일치 | red ×2 | AC7 |
| T10 | payload에만 있는 `ST<N>` / audit에만 있는 `ST<N>` | red ×2 | AC11 |
| T11 | `verdict:` 항목 결손: URL 없음 / verdict 토큰 없음 / statement <10자 / `ST` 참조 없음 | red ×4 | AC11 |
| T12 | 양쪽 steelman 공집합 + `기각` 항목 존재 + **sentinel 없음** | green | AC11 |
| T13 | Coverage Ledger가 audit에 없음 | red | AC10 |
| T14 | `confirmed` 0건 + sentinel 없음 / 있음 | red / green | AC12 |
| T15 | 정상 payload + audit 쌍 | green | — |
| T16 | 본문 160줄(§6 제외) 입력 | green + advisory 문자열 출력 | AC15 |
| T17 | `_web_disabled()` 시 §4·§5 URL 요구 완화 | green | AC11 |
| T18 | §6에 표기 블록 없음 / 세 기호 중 하나 누락 | red ×2 | AC5 |
| T19 | §5에 `기각` 항목 0건 + N/A sentinel 없음 / 있음 | red / green | AC11 |
| T20 | `plugin.json` version이 `0.23.` 로 시작하지 않음 / `CHANGELOG.md`에 `## [0.23.` 없음 | red ×2 | AC14 |
| T21 | body statement와 frontmatter `statement`가 다름(정규화 후) / 공백·강조기호만 다름 | red / green | AC7 |
| T22 | `evidence: S9`인데 §6에 `S9` 없음 | red | AC6 |
| T23 | `statement`가 161자 / 160자 | red / green | AC6 |
| T24 | body `⟨S<N>⟩`와 frontmatter `evidence`가 다름 / body에 `⟨S<N>⟩` 접미 없음 | red ×2 | AC7 |

실행: `python3 -m unittest`(`-m unittest`로만 — pytest 미사용), repo root에서.

T15는 AC 열이 `—`다 — 어느 단일 AC도 아닌 **happy-path 스모크**로, 정상 쌍이 통과하는지만 본다. 위 편도 참조 감사에서 의도적 예외다.

T19는 구 `tried_discarded_ok()` 테스트의 이관분이다 — 섹션이 §7에서 §5로 옮겨갔을 뿐 R4 의례는 그대로이므로, 기존 테스트가 사라지지 않도록 새 섹션 좌표로 옮긴다.

### 8.2 회귀 락 + mutation

AC13의 6개 문자열을 production 파일에서 검사. **mutation test로 이빨 증명** — 문자열을 각각 맨앞·중간·맨끝 한 곳에 되살려 실제로 red가 되는지 확인한다. 락의 PASS는 이빨의 증거가 아니다. 셸 파싱(IFS·nullglob·후행 개행)이 집행을 조용히 0으로 만드는 사례가 이 리포에 있으므로, 락이 bash라면 세 위치를 모두 흔든다.

락 스코프에 `check_brief.py`가 처음부터 포함된다(§5.6 — legacy 분기가 없으므로 예외 조항이 필요 없다).

AC1의 긍정 주장(`user_statements` 스키마 존재)은 `SKILL.md` 본문에 대한 positive grep으로 잠근다 — **body-unique 문구**를 섹션 윈도우 안에서 찾고, 헤더만 남긴 mutation으로 이빨을 증명한다(헤더-satisfiable 함정 회피).

### 8.3 탐색 폭 회귀 검증 (AC16, advisory)

구 brief(`2026-07-20-spec-distill-interview-coverage-driven-*`)를 새 포맷으로 변환해 쌍을 만든다. 각각을 fresh 서브에이전트에 동일 프롬프트로 투입하고, `superpowers:brainstorming` 체크리스트 4번("Propose 2-3 approaches")의 발화 여부를 관측한다. 조건당 3회, 같은 superpowers 버전(6.2.0)·같은 모델로 통제. 결과는 audit에 기록.

**변환 규칙 — 화이트리스트.** "내용 동일"이나 "문장 집합 동치"는 성립할 수 없다(권위 문구를 지우는 것이 변환의 목적이므로). 대신 허용 연산을 열거한다:

- 허용: 섹션 재배치 · 섹션 재라벨 · **AC13의 6개 금지 문자열**과 §2 권위 헤더 문장 삭제 · 출처 기호(🗣/☑/✎) 부착 · `S<N>`/`ST<N>` id 부여
- 금지: 새 주장 추가 · 기존 주장 재서술 · 위 목록 밖의 정보 삭제

**검증**: 원 brief의 각 문장을 {유지, 이동, 허용된 삭제} 중 하나로 분류한 매핑을 남긴다. **"신규" 분류가 1건이라도 있으면 그 실행은 무효**다. 변환자가 포맷 설계 당사자이므로 무의식적 개선이 측정 대상을 "포맷"에서 "다시 쓴 내용"으로 바꿀 수 있고, 이 매핑이 그것을 잡는다.

**한계**: n=3은 통계적 검정력이 없고, 관측치는 이진이며, 하류가 6.2.0에서 "Explore alternatives" 원칙 줄을 잃었으므로 음성이 나와도 원인이 brief가 아닐 수 있다. **방향 전환의 근거가 아니라 Spec B 조준용 신호**로 쓴다 — 그래서 advisory다.

### 8.4 수동 검증

| # | 항목 | AC |
|---|---|---|
| V1 | 새 포맷으로 인터뷰 1회 e2e — 확정 확인 게이트가 실제로 뜨고 `status`가 반영되는지 | AC2 |
| V2 | 재제시 상한 초과 시 전부 `provisional` 강등 + 고정 advisory 출력 | AC2 |
| V3 | `/compact` 경로와 직행 경로 양쪽에서 C4 프로토콜 문장이 실리는지 | AC3 |
| V4 | **AC1 부정 절반** — `SKILL.md`를 사람이 읽고, 이름만 바꾼 라운드별 잠금 구조(변수명을 갈아끼운 decision table 등)가 남아 있지 않은지 확인. 리터럴 락이 못 잡는 영역 | AC1 |
| V5 | **C5 개방형 판정** — 새 템플릿·`SKILL.md`·`README.md`를 사람이 읽고 독자에게 행동을 지시하는 문장이 남아 있지 않은지 확인. 기계 검증 불가 영역 | AC8 |
| V6 | `README.md` "Principles Instantiated" 항목이 이 변경을 실제로 반영하는지(문자열 존재가 아니라 내용 적절성) | AC14 |
| V7 | 첫 실산출 brief의 분량 지표가 예산 대비 어디인지 | AC15 |
| V9 | **`evidence` 의미적 정합** — `statement` 표본을 골라 인용된 `⟨S<N>⟩` 원문이 실제로 그 요약을 뒷받침하는지 확인. bijection C가 존재성만 보므로 남는 갭 | AC6 |
| V8 | **원문 완전성** — `state.local.md`의 `user_statements`와 brief §6을 대조해 기록된 발화가 빠짐없이 옮겨졌는지 확인. 게이트는 state를 읽지 않으므로 기계 검증 불가 | AC4 |

V4·V5·V8은 기계 검증이 불가능하다 — 앞의 둘은 개방형 부정 명제라서, V8은 게이트의 입력 범위 밖(state 파일)을 대조해야 해서다. **이 한계를 숨기지 않는 것이 설계의 일부다** — 락이 커버한다고 주장하면 커버되지 않은 영역이 커버된 것으로 보인다.

---

## 9. Rejected Alternatives

| 안 | 기각 이유 |
|---|---|
| **한 spec으로 A+B 전부** | 10파일·신규 에이전트 4개·게이트 스키마 변경·producer 교체가 한 번에. 이 리포에서 비슷한 규모는 3–4라운드 수정 사이클을 거쳤다. 또한 B의 critic은 A가 산출한 실물 brief를 상대로 설계하는 편이 낫다 |
| **원문 앵커 우선 레이아웃 (현행 구조 유지)** | readback 시범이 통과한 유일한 구조라는 장점이 있으나, 탐색 대상(OQ)이 §7 — 고치려는 실패가 "탐색을 안 함"인데 탐색 지시가 저-attention 구간에 있다. 볼륨 레버도 미사용 |
| **최대 압축 — 제약에 원문 인라인** | 분량은 가장 작지만 원문 전용 섹션이 사라져 Spec B critic의 ground truth가 발췌본이 된다. 「Blind Spots」가 경고한 "재구성 대 재구성의 순환 검증"이 실제로 성립 |
| **라운드별 모델 `status` 판정** | 가장 가볍지만 판정 주체가 모델이라 관대해지는 것을 막을 구조가 없다. 지금의 LD 9/6/5가 정확히 이 방식의 산물 |
| **사용자가 명시한 것만 `confirmed`** | 기계적·fail-closed지만 실제 대화에서 사용자는 "확정"이라 말하지 않아 거의 전부 provisional이 되고, 하류 재질문 harassment(「Blind Spots」의 반대 방향 실패)로 직결 |
| **설계 전 선측정** | codex의 OQ11 원안. 사용자가 이미 "방향 유지"를 선택한 사안을 사실상 다시 묻는 것이고, 결과와 무관하게 방향을 유지한다면 의사결정 가치가 낮다. 같은 데이터는 §8.3이 얻는다 |
| **별도 `status` 확인 게이트 신설** | 종료 시 사용자 상호작용이 2회가 된다. 기존 `/compact` proceed 게이트에 흡수하면 1회 유지 — trivia ceremony 금지 + P17 동시 만족 |
| **기존 brief 3건 마이그레이션** | 게이트는 방금 쓴 brief에만 돈다. 변환 비용 0의 가치 |
| **legacy 감지 분기 (초안)** | 존치 근거로 든 "회귀 검증 중 구 brief를 게이트에 넣는다"가 §8.3 실제 절차와 불일치. 실재하지 않는 시나리오를 위해 분기 + 2단계 락 스코프 + 제거 태스크 + T-case를 유지하는 순비용 (리뷰 round-1이 적발) |
| **payload↔audit 개수 등호 비교 (초안)** | "무엇을 한 항목으로 셀 것인가"가 미정이라 집행 불가 — 실제 steelman 항목은 다단락 블록이지 단일 불릿이 아니다. `ST<N>` id 집합 비교로 대체 (리뷰 round-1이 적발) |
| **`user_sourced_items`에 `inferred` 포함 (초안)** | 리스트 이름과 내용이 어긋나고 `evidence` 필수 규칙에 예외 구멍이 생긴다. 모델 추론은 하류가 C4 재결정 프로토콜을 적용할 대상도 아니다 → 프로즈 ✎ 표기로만 |
| **AC8을 기계 검증으로 주장** | "어디에도 규약 문장 없음"은 개방형 부정 명제라 리터럴 락으로 증명할 수 없다. 닫힌 열거 + V5 수동으로 분리하고 한계를 명시. AC1의 부정 절반도 같은 처리(V4) |
| **§5 병합 시 R4 의례 폐기 (초안)** | 구 §7 `Tried & Discarded`를 §5로 합치면서 검증을 steelman verdict 항목에만 걸면 스키마는 단순해지지만, **steelman이 트리거되지 않은 사용자 폐기 방향이 무기록으로 사라진다** — 하류 재탐색 차단이라는 R4의 목적이 그대로 증발하고 §5는 헤더만 있어도 통과한다. 병합은 표현의 통합이지 의례의 폐기가 아니므로 `기각`/`위험` 항목 문법으로 가르고 "기각 0건 금지"를 이관 (리뷰 round-2가 적발) |
| **`evidence`가 laundering을 봉쇄한다고 서술 (초안)** | bijection C는 `S<N>`의 *존재*만 검사한다 — 요약이 그 원문을 뒷받침하는지는 검증하지 않으므로 실재하는 아무 id나 붙여도 통과한다. "기계적으로 봉쇄"는 사실과 다른 확정 진술이었고, V4·V5·V8에서 지킨 *"안 닫히는 갭은 명시한다"* 규율을 이 항목에서만 어겼다 → 주장을 낮추고 V9 신설 (리뷰 round-5가 적발) |
| **§2 body에 요약 신호 없이 🗣만 표기 (초안)** | 🗣를 provenance로 재정의했지만 렌더 문법에 시각 신호가 없어, 이 구분을 모르는 독자는 C2가 약속한 대로 *"🗣 = 한 말 그대로"* 로 읽는다 → `⟨S<N>⟩` 접미 + §2 머리 한 줄 + C2 표 명문화. **사용자 재확인을 받았다**(C4 경로, round-5 게이트) |
| **README를 락 스코프에서 빼고 대체 검증 미배정 (초안)** | 락에서 빼는 것 자체는 옳았지만(옛 용어 인용 필요) V5는 템플릿·SKILL만 스코프라 README가 **완전 무검증**으로 남았다 — 정작 권위 문법 재도입 위험이 가장 높은 파일이다 → V10 신설 (리뷰 round-5가 적발). **사후 반증(구현 완료 후)**: "옛 용어 인용 필요"라는 전제 자체가 틀렸다 — shipped README는 `grep -cF`로 6개 리터럴을 **0건** 인용한다. V10이 메운 갭은 애초에 비어 있었다. 아래 행 참고 |
| **편도 참조 감사를 Verification Plan에 배치 (초안)** | §8은 shipped artifact 검증 목록인데 그 감사는 *이 설계 문서 자신의* 저술 일관성 점검이다 — category error이고, "기계 대조"라 쓰면서 스크립트가 §7에 없었다 → §6 표 무결성 규칙(저술용)으로 이동, 라운드 참조는 Metadata로 (리뷰 round-5가 적발) |
| **`statement`를 사용자 원문으로 취급 (초안)** | 160자 cap이 붙은 필드를 원문으로 읽으면 임의 길이 발화를 압축 없이 담을 수 없어 §5.3의 *"사용자 원문은 압축 대상 아님"* 과 정면충돌한다. `statement`는 모델이 쓴 요약이고 §6이 원문이며, §2의 기호는 **저자가 아니라 provenance**를 가리킨다 — 이 구분을 붙드는 것이 `evidence` 필수 규칙이다 (리뷰 round-4가 적발) |
| **"정정 이벤트"를 스키마 없이 서술 (초안)** | 저장 위치·필드·검증 배정이 전부 없는 규칙을 §5.3에 남겼다 — 이 문서 자신의 원칙(*"검증 배정 없는 hard AC는 사실상 주석"*)을 스스로 위반. Spec A는 원문 편집 경로를 만들지 않으므로 Deferred to plan으로 이동 (리뷰 round-4가 적발) |
| **README를 락 스코프에 포함 (초안)** | README의 "Principles Instantiated"는 *무엇이 왜 사라졌는지* 설명하려면 옛 용어를 인용해야 한다 — `CHANGELOG.md`를 뺀 것과 같은 이유다. **우회해야 하는 락은 그 자체로 설계 결함** (리뷰 round-4가 적발). **사후 반증·결정 반전(구현 완료 후)**: 이 예측은 검증 가능했고 실패했다 — shipped README는 `grep -cF`로 6개 리터럴을 **0건** 인용하는 반면(README 제외를 시행한 구현 태스크의 예측과 반대), `CHANGELOG.md`는 실제로 4건 인용한다(`locked_directions` 2 · `pending_locked_decisions` 3 · `재논쟁 금지` 1 · `Locked Directions` 1 — 이쪽 제외는 여전히 정당). 두 파일은 종류가 다르다: CHANGELOG는 *코드가 부르던 이름*을 기록하고 README는 *플러그인이 하는 일*을 기록한다 — 후자에는 은퇴한 식별자를 인용할 이유가 없었다. **결정을 반전**한다 — README를 AC13 스코프에 편입(위 행의 V10은 그래서 폐지), AC8 검증열은 §8.2+V5로 통합해 개방 절반(사람 판단)만 남긴다 |
| **두 공집합 조건에 같은 sentinel 공유 (초안)** | bijection A(steelman=0)와 R4(`기각`=0)는 서로 다른 조건인데 하나의 sentinel 문구를 공유하려 했다. `기각`은 있고 steelman만 0건인 **가장 흔한 정상 상태**에서 그 문구(*"전부 first-time defend+lock"*)가 거짓 진술이 되어 쓸 수 없고, 규칙과 T12가 정면으로 모순됐다 → steelman 공집합은 sentinel 면제 (리뷰 round-3이 적발) |
| **bijection B를 메타데이터만 대조 (초안)** | id·기호·status만 맞추면 frontmatter와 body가 같은 라벨을 달고 **서로 다른 제약을 말해도** 통과한다. bijection B는 round-2에서 신설한 것인데 정작 지키려던 축의 *내용*을 비워뒀다 → frontmatter canonical + 정규화 후 statement 동일 (리뷰 round-3이 적발) |
| **"전문 보존"을 글자 불변으로 정의** | `CLAUDE.md` P21의 secret placeholder 치환과 정면충돌한다. 불변식은 글자가 아니라 **provenance**이며, 허용 변환을 열거하고 완전성은 V8 수동으로 분리 |
| **hard AC를 검증 배정 없이 선언 (초안)** | 구 AC4(표기 블록)·AC13(버전 bump)이 T-case도 V-item도 없이 hard로 선언돼 있었다. 검증이 배정되지 않은 AC는 *"미충족 시 미완료"* 를 집행할 수단이 없어 사실상 주석이다 → AC 표에 **검증 열**을 추가하고 전 hard AC에 명시 배정 (리뷰 round-2가 적발) |
| **`agents/spec-reviewer.md` NG3 문구를 지금 수정** | Spec A는 리뷰어를 만들지 않으므로 NG3가 여전히 사실. 사실이 아닌 문서를 미리 쓰는 것은 drift |

---

## 10. Open Questions 처리

interview brief의 OQ1–OQ12 중:

| Spec A에서 닫힘 | Spec B로 이월 |
|---|---|
| **OQ1** C4 전달 → 호출 프롬프트 (§5.1) | OQ2 critic·readback 재실행 cap |
| **OQ7** 게이트 스키마 + 기존 3건 (§5.4·§5.5) | OQ3 readback 판정자 |
| **OQ9** 섹션 레이아웃 (§5.3) | OQ4 red-flag 기준 위치 |
| **OQ12** 2파일 유지 + fail-closed 봉쇄 | OQ5 "사용자와 Claude 양쪽"의 의미 |
| **OQ6** (부분) 규약 0개를 실증하고 재발은 락 + V4가 감시 | OQ8 리뷰 역할 배치 (D2 ↔ D5 도구 계약 충돌) |
| **OQ11** (부분) 설계 후 회귀 검증으로 배치 (§8.3) | OQ10 readback을 hard verdict로 쓸 수 있는가 |

**OQ4는 A에서 부분적으로 선제 처리된다** — payload에 red-flag 기준을 넣지 않음으로써(C5의 귀결) readback 오염원이 미리 제거된다. 기준의 *내용*과 배치처는 B의 몫.

---

## 11. Metadata

- **작성일**: 2026-07-25
- **입력 brief**: `docs/superpowers/interview/2026-07-25-spec-distill-brief-handoff-redesign-interview.md` (+ `.audit.md`)
- **대상 플러그인**: `plugins/spec-distill` — `v0.22.0` → `v0.23.0`
- **후속 spec**: Spec B (brief-critic / 방향성 리뷰 / readback / codex) — Spec A 산출 brief 실물을 입력으로 설계
- **철학 근거**: Law 1(구조 게이트 — `check_brief.py`), Law 3(회귀 락 = compounding), P17(사용자 주권 — 확정 확인 게이트), P21(untrusted input — `audit_file` basename 제한), 금지 패턴 *trivia ceremony*(확인 게이트 흡수)·*unbounded autonomy*(재제시 상한)
- **Law 2**: 신규 에이전트 0개. tool posture 변경 없음
- **리뷰 이력**: round-1 Claude 7 + codex 4 → 11건 · round-2 Claude 5 + codex 0(`approved`) → 5건 · round-3 Claude 4 + codex 2 → 6건 · round-4 Claude 5 + codex 0(`approved`) → 5건 · round-5 Claude 4 + codex 1(medium, `approved`) → 5건. **누적 32건 전부 반영**, 매 라운드 직전 지적은 종결 확인됨. `rereview_count` 5 = hard cap → 사용자 게이트에서 재리뷰 없이 진행 결정. 재발 클래스(AC↔T/V 편도 참조)는 §6 표 무결성 규칙으로 봉쇄 — round-3 `T17↔AC11`, round-4 `V8↔AC4`·`T21↔AC7`에서 두 번 재발했다. C2의 provenance 해석은 round-5 게이트에서 **사용자 재확인**(C4 경로)
