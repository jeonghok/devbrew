# spec-distill brief 포맷·producer 재설계 (Spec A)

> *brief는 방향을 잡는 문서다. 컨텍스트를 제약하는 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다.*
> — 사용자, 2026-07-25 (제약 C5)

interview brief를 핸드오프 아티팩트로 재설계한다. 라운드마다 결정을 잠그는 producer를 제거하고, 확정 권한을 사용자에게 되돌리며, payload를 역피라미드로 재배치·압축한다.

## 목차

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
  - [5.6 legacy 비계와 락의 순서 의존](#56-legacy-비계와-락의-순서-의존)
- [6. Acceptance Criteria](#6-acceptance-criteria)
- [7. Files to Modify](#7-files-to-modify)
- [8. Verification Plan](#8-verification-plan)
  - [8.1 구조 테스트](#81-구조-테스트)
  - [8.2 회귀 락 + mutation](#82-회귀-락--mutation)
  - [8.3 탐색 폭 회귀 검증 (AC13)](#83-탐색-폭-회귀-검증-ac13)
  - [8.4 수동 검증](#84-수동-검증)
- [9. Rejected Alternatives](#9-rejected-alternatives)
- [10. Open Questions 처리](#10-open-questions-처리)
- [11. Metadata](#11-metadata)

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

**보조 근거**: `superpowers` 6.1.1·6.2.0 brainstorming skill 전문에 `interview`/`brief`/`locked_directions` 언급 0건 — frontmatter `locked_directions[]`는 소비자가 없고 전달은 순수 프로즈 경로다. 6.2.0에서 `Key Principles`의 *"Explore alternatives — Always propose 2-3 approaches before settling"* 줄이 삭제되어 탐색 지시가 체크리스트 1곳으로 줄었다 — 하류가 약해진 만큼 brief의 과잉결정이 더 해롭다.

**이 spec의 범위**: 인터뷰 결과물은 「포맷·producer 교체」와 「리뷰 파이프라인 신설」 두 덩어리다. 사용자 결정으로 **두 spec으로 분리**하고, 이 문서는 전자(Spec A)만 다룬다. Spec B(brief-critic / 방향성 리뷰 / readback / codex)는 Spec A가 실제 brief를 산출한 뒤 그 실물을 입력으로 설계한다.

---

## 2. Goals

1. **라운드별 잠금 producer 제거.** 인터뷰가 진행 중 결정을 확정하지 않는다.
2. **확정 권한을 사용자에게.** `status: confirmed`는 사용자의 명시적 확인 행위로만 발생한다.
3. **payload 재배치·압축.** 행동 항목(제약·Open Questions)을 앞으로, 근거·원문을 뒤로. 모델 산문을 압축하되 사용자 원문은 전문 보존.
4. **Spec B가 소비할 frontmatter 계약 확정.** `source × status × evidence`를 지금 못 박아 B가 포맷을 재작업하지 않게 한다.
5. **2파일 분리로 생기는 게이트 fail-open 봉쇄.**
6. **재발 방지 락.** 권위 문법 재도입을 기계적으로 막는다.

---

## 3. Non-goals

- **리뷰 파이프라인** — brief-critic(D2) / 방향성 리뷰(D5) / readback(D3) / codex 프롬프트 빌더(D4)는 전부 Spec B.
- **`agents/spec-reviewer.md` NG3 문구 수정** — Spec A는 리뷰어를 만들지 않으므로 *"brief는 분리 review 대상이 아니다"* 가 여전히 사실이다. `check_brief.py` docstring의 NG3 서술도 동일하게 유지.
- **기존 brief 3건 마이그레이션** — §5.5 참조. 불필요.
- **`superpowers` 플러그인 자체 수정** — 외부 플러그인. 하류의 약화(6.2.0 원칙 줄 삭제)는 관측 사실로 기록만 하고 손대지 않는다.
- **분량 감축을 위한 사용자 원문 발췌** — 원문은 압축 대상이 아니다(§5.3).

---

## 4. Constraints

인터뷰에서 확정된 것. `source`(누가) × `status`(얼마나 굳었나) 두 축. 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론.

| id | source | 내용 |
|---|---|---|
| **C5 (최상위)** | 🗣 | brief는 방향을 잡는 문서다. 행동 규약을 담으면 다음 세션의 잠재공간이 좁아진다. 규약·프로토콜은 brief가 아니라 그것을 집행하는 곳(템플릿·SKILL·에이전트 프롬프트)에 산다. **다른 제약과 충돌 시 이것이 이긴다.** |
| C1 | 🗣 | 다음 세션에서 보고 바로 이해되는 내용이 최상단에 온다 |
| C2 | 🗣 | 사람이 한 말은 표기로 구분한다 |
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
| B5 | 🗣 | legacy 지원은 임시 비계 — 마지막 시점에 제거 |

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
| `check_brief.py` | `locked_directions` 필수 | `user_sourced_items` 필수 + source/status/evidence 검증 + 2파일 스코프 |

**C5 ↔ OQ1 충돌 해소.** `superpowers:brainstorming`은 spec-distill을 모르고 `locked_directions`를 0건 참조한다. 그러니 `status`도 참조하지 않을 것이다. C4 프로토콜을 brief에 넣으면 C5 위반이고, 넣지 않으면 하류 도달 경로가 없다.

→ 규약은 C5가 지정한 자리 그대로 **orchestrator의 호출 프롬프트**에 산다. brief 파일은 순수 데이터(`source`/`status`/`evidence`)만 나르고, *"confirmed 항목은 근거 있으면 보고 후 재결정, 임의 변경 금지"* 는 `SKILL.md`가 brainstorming을 호출할 때 함께 보내는 문장이다. orchestrator는 두 stage 사이에 계속 존재하므로 채널이 있다. `/compact` 경로(옵션 ①)와 직행 경로(옵션 ②) 양쪽 모두에 동일 문장을 싣는다.

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
  → AskUserQuestion  ① 이대로 확정하고 진행 / ② 확정 목록 수정 / ③ 중단
       ① → status 반영 → 재저장 → 게이트 재실행 → /compact 노출 → STOP
       ② → 수정 반영 후 재제시 (최대 2회, 초과 시 전부 provisional 강등 + loud advisory)
       ③ → 정지
```

**후보 선별은 모델이 한다.** `user_statements` 전체를 훑어 각 항목에 후보 `status`를 붙이고, `confirmed` 후보만 목록으로 제시한다 — 제외한 것도 한 줄로 함께 보여야 사용자가 누락을 잡을 수 있다. 확정 목록이 길 수 있으므로 목록은 **프로즈로 출력**하고 `AskUserQuestion`은 3지선다만 담당한다. 모델의 후보 판정은 제안일 뿐이고 `confirmed`로의 전이는 옵션 ① 선택으로만 일어난다.

**frontmatter 계약** (Spec B의 critic이 소비):

```yaml
user_sourced_items:
  - id: C1
    source: verbatim | chosen | inferred
    status: confirmed | provisional | open
    statement: "<160자 이내, P21 placeholder 치환>"
    evidence: S3            # §6 원문의 어느 발화에서 나왔는가
```

`evidence`가 이 설계의 이빨이다. **`source ∈ {verbatim, chosen}`인데 `evidence`가 없으면 게이트 fail** — codex 리뷰가 인터뷰 brief에서 적발한 "☑ laundering"(사용자가 고르지 않은 것을 ☑로 표기)이 기계적으로 봉쇄된다. `inferred`는 `evidence` 없음이 정상이다.

### 5.3 payload 레이아웃

역피라미드 + 압축. 목표 ~165줄(현행 272 → -40%). **압축 대상은 모델이 쓴 산문에 한정**하고 사용자 원문은 손대지 않는다 — 원문을 발췌본으로 만들면 Spec B critic의 ground truth가 무너져 「Blind Spots」가 경고한 *"재구성 대 재구성의 순환 검증"* 이 실제로 성립한다.

| § | 섹션 | 분량 | 역할 |
|---|---|---|---|
| 0 | 한눈에 | ~12줄 | 무엇/왜/확정/열림/다음 stage |
| 1 | Goal · Non-goal | ~10줄 | |
| 2 | 제약 | ~25줄 | source × status 표 + 항목 |
| 3 | Open Questions | ~20줄 | **탐색 대상을 앞으로** |
| 4 | External Landscape | ~18줄 | 1항목 = 1줄, URL 필수 |
| 5 | 기각 · Blind Spots | ~20줄 | 통합. verdict 토큰 보유 항목 = steelman 대응 |
| 6 | 사용자 원문 | ~50줄 | **전문 보존.** `S<N>` 앵커 제공 |
| 7 | Next Action | ~8줄 | |

§6 상단에 C3의 2줄 고정 블록:

```markdown
> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론
```

항목 형식:

```markdown
- **S1** 🗣 최초 요청:
  > "..."
```

U자 배치: 앞 = 스냅샷 + 행동 항목(제약·OQ), 뒤 = 원문(대조용 참조) + Next Action.

**audit 레이아웃**: `1. Coverage Ledger` / `2. Budget` / `3. Steelman 원문` / `4. 게이트 실행 기록` / `5. 프로세스 로그`.

### 5.4 게이트 계약

```python
SECTIONS = [("0","한눈에"), ("1","Goal · Non-goal"), ("2","제약"),
            ("3","Open Questions"), ("4","External Landscape"),
            ("5","기각 · Blind Spots"), ("6","사용자 원문"), ("7","Next Action")]

AUDIT_SECTIONS = [("1","Coverage Ledger"), ("2","Budget"), ("3","Steelman 원문"),
                  ("4","게이트 실행 기록"), ("5","프로세스 로그")]
```

audit 섹션도 계약이다. `coverage_ledger_failures()`와 steelman 계수는 섹션 번호+제목 정규식으로 본문을 잘라내므로, audit 쪽 번호가 바뀌면 검증이 조용히 빈 문자열을 읽고 통과한다 — 두 목록을 함께 못 박는다.

**2파일 fail-open 봉쇄.** Coverage Ledger와 Steelman이 audit으로 이동하는데 게이트가 payload만 읽으면 두 검증이 통째로 증발한다 — interview brief가 OQ7로 경고한 지점이다.

```python
audit_file = fm["audit_file"]                    # 필수 키, 없으면 FAIL
if Path(audit_file).name != audit_file: FAIL     # basename만 — traversal 거부
audit = payload.parent / audit_file
if not audit.exists(): FAIL                      # fail-closed
coverage_ledger_failures(audit.read_text(encoding="utf-8"))
```

`audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(P21 계보). 파일 읽기는 `encoding="utf-8"` 명시 — non-UTF-8 locale에서 fail-open 방지.

**cross-file 정합.** payload §5에서 `verdict:` 토큰을 가진 항목 수 == audit 「Steelman 원문」 항목 수. 불일치는 양방향 모두 결함이다 — payload가 많으면 *원문 없는 판정*(근거 증발), audit이 많으면 *판정 없는 steelman*(R3 미충족). `0 == 0`(양쪽 N/A sentinel)은 허용. 현행 `steelman_unlogged()`가 세던 frontmatter `steelman:` 필드가 사라지므로 이 검사가 그 자리를 대체한다.

**의도적으로 엄격하게 등호를 쓴다.** `>=`로 완화하면 audit에 steelman 10개를 두고 payload에 verdict 1개만 써도 통과하여, 봉쇄하려던 fail-open이 그대로 돌아온다.

**빈 확정 금지.** `status: confirmed` 항목이 0건이면 명시 sentinel(`# confirmed 0건 — 사용자가 전부 잠정으로 판단`) 없이는 fail. sentinel 없는 0건은 확인 게이트를 건너뛴 신호다.

### 5.5 에러 처리 · graceful degradation

| 상황 | 동작 |
|---|---|
| audit 파일 부재·읽기 실패 | **fail-closed** — 게이트 red |
| `audit_file`이 basename 아님 | fail |
| web 비활성 (`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`) | 기존 `_web_disabled()` 완화 유지 — §4 인용 요구 완화 |
| 확정 확인 루프 3회 도달 | 전부 `provisional` 강등 + loud advisory. **fail-closed 방향(덜 잠금)이 안전한 쪽** |
| 구 포맷 brief를 게이트에 투입 | §5.6의 legacy 비계가 존재하는 동안은 명시 메시지 + red, 제거 후에는 `user_sourced_items` 부재로 red |

**기존 brief 3건 마이그레이션은 불필요하다.** `check_brief.py gate`는 종료 직전 방금 쓴 brief에만 실행된다 — 과거 파일은 아무도 게이트에 넣지 않는다. 다만 **보존은 필수**다(§8 회귀 검증의 대조군, Law 3 기록).

### 5.6 legacy 비계와 락의 순서 의존

legacy 감지 분기(`locked_directions`가 있고 `user_sourced_items`가 없으면 `[spec-distill] legacy v≤0.22 brief — 이 게이트는 v0.23+ 전용` 후 red)는 **임시 비계**다. 존재 이유는 구현·회귀 검증 중 구 brief를 게이트에 넣을 때 혼란을 막는 것뿐이다.

그리고 이 분기는 회귀 락과 **같은 파일에서 공존할 수 없다** — 분기가 있는 동안 `check_brief.py`에 `locked_directions` 문자열이 살아 있기 때문이다. 따라서 순서가 강제된다:

1. 구현 + legacy 분기 (락 스코프에서 `check_brief.py` **제외**)
2. 탐색 폭 회귀 검증 — 구 brief를 게이트에 넣는 마지막 시점
3. **legacy 분기 제거 → 락 스코프를 `check_brief.py`까지 확장 → mutation 재검증**

제거 후 별도 legacy 테스트는 불필요하다. 회귀 락이 `locked_directions` 문자열 자체를 금지하므로 **legacy 분기의 재도입을 자동으로 봉쇄**한다.

---

## 6. Acceptance Criteria

| # | 기준 |
|---|---|
| AC1 | `SKILL.md`에 라운드별 `locked?` decision table과 `pending_locked_decisions`가 존재하지 않는다. state는 `user_statements`(id/source/round/text)만 기록하며 `status`·`section` 앵커를 갖지 않는다 |
| AC2 | `status: confirmed`는 종료 proceed 게이트에서 사용자가 옵션 ①을 고를 때만 발생한다. 옵션 ②(목록 수정) 재제시는 **최대 2회**까지 허용하고, 3회째 요구 시 전부 `provisional` 강등 + loud advisory 후 진행 |
| AC3 | payload 템플릿이 §0–§7 8섹션 역피라미드이며, 사용자 원문이 §6에 전문 보존된다 |
| AC4 | 템플릿 §6 상단에 2줄 출처 표기 블록이 고정되어 모든 brief가 상속한다 |
| AC5 | `user_sourced_items[]`의 각 항목이 id/source/status/statement를 갖고, `source ∈ {verbatim, chosen}`이면 `evidence: S<N>`가 필수다 |
| AC6 | payload 템플릿·`SKILL.md`·게이트 어디에도 독자에게 행동을 지시하는 규약 문장이 없다(C5). C4 프로토콜은 `SKILL.md`가 brainstorming을 호출할 때 프롬프트로 전달하며, `/compact` 경로와 직행 경로 양쪽에 실린다 |
| AC7 | `check_brief.py`가 `audit_file`을 필수 키로 요구하고, basename이 아니면 fail, 파일이 없으면 fail한다 |
| AC8 | Coverage Ledger·Steelman 원문 검증이 audit 파일에 대해 실행된다 |
| AC9 | payload §5 verdict 항목 수 ≠ audit Steelman 항목 수이면 fail (`0 == 0` 허용) |
| AC10 | `confirmed` 0건이면 명시 sentinel 없이는 fail |
| AC11 | 회귀 락이 `locked_directions`·`pending_locked_decisions`·`재논쟁 금지`·`Locked Directions` 4개를 잡고, mutation test로 이빨이 증명된다. 스코프는 production only (`tests/`·`CHANGELOG.md`·`docs/` 제외), 검사 문구는 body-unique. **1단계 스코프는 `check_brief.py`를 제외**한다(§5.6 — legacy 비계가 그 문자열을 합법적으로 보유) |
| AC12 | 회귀 검증 완료 후 legacy 분기가 제거되고, **같은 커밋에서** 락 스코프가 `check_brief.py`까지 확장되며 mutation이 재검증된다. 이 시점에 AC11의 예외가 사라진다 |
| AC13 | 탐색 폭 회귀 검증이 구/신 포맷 쌍으로 조건당 3회 실행되고 결과가 audit에 기록된다. 두 brief는 **내용이 동일**해야 하며, 변환이 내용을 바꾸지 않았음을 대조로 확인한다 |
| AC14 | `plugin.json` `0.23.0` + `CHANGELOG.md` `## [0.23.0]` 항목 + `README.md`의 "Principles Instantiated"·"Hooks Installed" 갱신 |

---

## 7. Files to Modify

| 파일 | 성격 |
|---|---|
| `plugins/spec-distill/templates/interview-brief-template.md` | 재작성 — payload 8섹션 |
| `plugins/spec-distill/templates/interview-audit-template.md` | 신규 — 텔레메트리 5섹션 |
| `plugins/spec-distill/scripts/check_brief.py` | 수정 — SECTIONS 교체, `user_sourced_items` 검증, 2파일 fail-closed, cross-file 정합, legacy 비계(→ 마지막에 제거) |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 수정 — producer 교체, 종료 확인 흡수, compact 문구, 호출 프롬프트 계약 |
| `plugins/spec-distill/plugin.json` | `0.23.0` |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.23.0] — 2026-07-25` |
| `plugins/spec-distill/tests/` | 신규 케이스 (§8) |
| `plugins/spec-distill/README.md` | "Principles Instantiated" 갱신 |

**신규 에이전트 0개.** Law 2 tool posture는 변경 없음.

---

## 8. Verification Plan

### 8.1 구조 테스트

| # | 케이스 | 기대 |
|---|---|---|
| T1 | 새 섹션 8개 각각 제거 | red ×8 |
| T2 | `user_sourced_items` 부재 | red |
| T3 | `source: verbatim` + `evidence` 없음 | **red** — ☑ laundering 봉쇄 |
| T4 | `source: chosen` + `evidence` 없음 | red |
| T5 | `source: inferred` + `evidence` 없음 | green |
| T6 | 잘못된 `status` / `source` 값 | red ×2 |
| T7 | `audit_file` 부재 / `../foo.md` / 파일 없음 | red ×3 |
| T8 | Coverage Ledger가 audit에 없음 | red |
| T9 | verdict 수 ≠ steelman 수 (양방향) | red ×2 |
| T10 | 양쪽 N/A sentinel (`0 == 0`) | green |
| T11 | `confirmed` 0건 + sentinel 없음 / 있음 | red / green |
| T12 | 정상 payload + audit 쌍 | green |

실행: `python3 -m unittest`(`-m unittest`로만 — pytest 미사용), repo root에서.

### 8.2 회귀 락 + mutation

4개 금지 문자열을 production 파일에서 검사. **mutation test로 이빨 증명** — 문자열을 각각 맨앞·중간·맨끝 한 곳에 되살려 실제로 red가 되는지 확인한다. 락의 PASS는 이빨의 증거가 아니다. 셸 파싱(IFS·nullglob·후행 개행)이 집행을 조용히 0으로 만드는 사례가 이 리포에 있으므로, 락이 bash라면 세 케이스를 모두 흔든다.

### 8.3 탐색 폭 회귀 검증 (AC13)

구 brief(`2026-07-20-spec-distill-interview-coverage-driven-*`)를 **내용은 그대로 두고 새 포맷으로만 변환**해 쌍을 만든다. 각각을 fresh 서브에이전트에 동일 프롬프트로 투입하고, `superpowers:brainstorming` 체크리스트 4번("Propose 2-3 approaches")의 발화 여부를 관측한다. 조건당 3회, 같은 superpowers 버전(6.2.0)·같은 모델로 통제. 결과는 audit에 기록.

**변환 편향 통제**: 변환자는 포맷을 설계한 당사자이므로 무의식적으로 내용을 개선할 수 있다 — 그러면 측정 대상이 "포맷"이 아니라 "다시 쓴 내용"이 된다. 변환은 재배치·섹션 재라벨·권위 문구 제거로만 한정하고, 변환 전후 문장 집합이 동치인지 대조한 결과를 audit에 남긴다. 새로 추가된 정보가 있으면 그 실행은 무효 처리한다.

**한계를 미리 명시한다**: n=3은 통계적 검정력이 없고, 관측치는 이진이며, 하류가 6.2.0에서 "Explore alternatives" 원칙 줄을 잃었으므로 음성이 나와도 원인이 brief가 아닐 수 있다. **방향 전환의 근거가 아니라 Spec B 조준용 신호**로 쓴다.

### 8.4 수동 검증

| # | 항목 |
|---|---|
| V1 | 새 포맷으로 인터뷰 1회 e2e — 확정 확인 게이트가 실제로 뜨고 `status`가 반영되는지 |
| V2 | 확인 루프 2회 초과 시 전부 `provisional` 강등 + advisory 출력 |
| V3 | `/compact` 경로와 직행 경로 양쪽에서 C4 프로토콜 문장이 실리는지 |

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
| **legacy 분기 영구 유지** | `check_brief.py`에 `locked_directions` 문자열이 남아 회귀 락을 그 파일에 걸 수 없다. 락과 공존 불가 |
| **cross-file 정합을 `>=`로 완화** | audit에 steelman 10개 + payload에 verdict 1개가 통과한다. 봉쇄하려던 fail-open이 복귀 |
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
| **OQ6** (부분) 규약 0개를 실증하고 재발은 락이 감시 | OQ8 리뷰 역할 배치 (D2 ↔ D5 도구 계약 충돌) |
| **OQ11** (부분) 설계 후 회귀 검증으로 배치 | OQ10 readback을 hard verdict로 쓸 수 있는가 |

**OQ4는 A에서 부분적으로 선제 처리된다** — payload에 red-flag 기준을 넣지 않음으로써(C5의 귀결) readback 오염원이 미리 제거된다. 기준의 *내용*과 배치처는 B의 몫.

---

## 11. Metadata

- **작성일**: 2026-07-25
- **입력 brief**: `docs/superpowers/interview/2026-07-25-spec-distill-brief-handoff-redesign-interview.md` (+ `.audit.md`)
- **대상 플러그인**: `plugins/spec-distill` — `v0.22.0` → `v0.23.0`
- **후속 spec**: Spec B (brief-critic / 방향성 리뷰 / readback / codex) — Spec A 산출 brief 실물을 입력으로 설계
- **철학 근거**: Law 1(구조 게이트 — `check_brief.py`), Law 3(회귀 락 = compounding), P17(사용자 주권 — 확정 확인 게이트), P21(untrusted input — `audit_file` basename 제한), 금지 패턴 *trivia ceremony*(확인 게이트 흡수)·*unbounded autonomy*(확인 루프 max 2회)
- **Law 2**: 신규 에이전트 0개. tool posture 변경 없음
