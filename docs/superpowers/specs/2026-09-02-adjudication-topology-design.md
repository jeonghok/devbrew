# 판정 지형 — 회계 배선과 도출 락 · Design

> 판정을 버릴 때 이름을 부르게 하고, 그 이름을 부르는지 구조에서 도출해 검사한다.

## Handoff Context

- **입력** — `docs/superpowers/interview/2026-09-02-adjudication-topology-interview.md`
  (확정 17 · 잠정 2 · 열린 질문 26). 텔레메트리는 같은 이름의 `.audit.md`.
- **이 문서가 정하는 것** — brief 가 의도적으로 미확정으로 남긴 OQ1(통일 계약의 구체적 형태).
- **사용자가 이 단계에서 정한 것 다섯** — 아래 §0 의 표.
- **다음** — `superpowers:writing-plans`.

### 근거의 지위

이 문서의 `file:line` 은 두 출처다. **⒜ 저자가 직접 읽어 확인한 것** — `shared/adjudication/adjudication.py`
전체, `plugins/quality-gates/scripts/synthesize_findings.py` 의 인용 구간 전부, 도출 규칙이 뽑는
세 집합, `quality-pipeline/SKILL.md:511`, `git log` 로 확인한 `37ea0d7`. **⒝ 읽기전용 조사
4건이 보고한 것** — 그 밖의 인용. ⒝ 는 착수 시 해당 파일을 열어 재확인한다. 조사는 **어떤 락도
실행하지 못했다**(읽기전용 제약 × `mktemp -d`) — 따라서 「오늘 전부 GREEN 인가」는 이 문서의
어느 문장도 주장하지 않는다.

## 목차

- [0. 한눈에](#0-한눈에)
- [1. 문제 — 계산기는 있는데 부르지 않는다](#1-문제--계산기는-있는데-부르지-않는다)
- [2. 도출 규칙 — 목록을 적지 않고 계산한다](#2-도출-규칙--목록을-적지-않고-계산한다)
- [3. 작업 A — 배선](#3-작업-a--배선)
- [4. 작업 B — 락 넷](#4-작업-b--락-넷)
  - [4.4 PR 분할](#44-pr-분할)
- [5. 작업 C — 출력 모양](#5-작업-c--출력-모양)
- [6. 작업 D — stale 이름과 역방향 락](#6-작업-d--stale-이름과-역방향-락)
- [7. 제외 범위와 근거](#7-제외-범위와-근거)
- [8. 착수 전 선결 조건](#8-착수-전-선결-조건)
- [9. 위험](#9-위험)
- [10. 기각한 대안](#10-기각한-대안)
- [11. 완료 측정](#11-완료-측정)
- [12. Known gaps — 이월](#12-known-gaps--이월)

## 0. 한눈에

**무엇** — 판정 항목이 버려질 때 `shared/adjudication/adjudication.py` 의 `Ledger` 메서드를
반드시 부르게 하고, 그것을 부르는지 검사하는 락 넷을 둔다. 검사 대상 파일은 **목록이 아니라
구조에서 도출**한다.

**왜** — 계산기는 이미 있고 `report()` 는 카운트 여섯을 이미 낸다. 그런데 프로덕션이 읽는 것은
`held` 하나뿐이고, 리뷰어가 보고 버린 항목(`reject`)은 계산기를 손에 쥔 채 맨 `continue` 로
사라진다. 「무엇이 버려졌나」를 세는 술어에 **호출자가 0건**이다.

**사용자가 이 단계에서 정한 것**

| # | 결정 | 결과 |
|---|---|---|
| D1 | 세 축이 충돌하면 **회계가 이긴다** — 성공 = 버려지는 것이 세어짐 | 입력·역할 축은 회계에 봉사 |
| D2 | 공시는 **두 지표로 쪼갠다** — 배관 손실(합계·게이트) / 판정 처분(상태별·비게이트) | §5 |
| D3 | **도출 우선** — 배선 + 대상을 스스로 계산하는 락 | §2·§4 |
| D4 | 규칙 억제는 **새 칸 「억제」로 분리** — `reject` 와 합치지 않음 | §3 5번 |
| D5 | stale 에이전트 이름은 **제거**하고, 그 방향을 보는 락을 둔다 | §6 |

**무엇을 안 하나** — 훅 층 회계 · codex 스키마 둘의 통일 · 자동 실행자 신설 · cross-family 요구.
전부 §7 에 근거와 함께.

## 1. 문제 — 계산기는 있는데 부르지 않는다

### 1.1 어휘는 완성돼 있다

`shared/adjudication/adjudication.py` 의 `Ledger` 는 처분 메서드 일곱을 갖는다 — `accept`(:43) ·
`reject`(:47) · `hold`(:51) · `absorbed`(:55) · `coerced`(:59) · `source_failed`(:67) ·
`uncountable`(:75). 판정 보조로 `blocks`(:89) · `reasons`(:106) · `report`(:121) · `surfaced`(:136).

배포는 **심볼릭 링크**(`git ls-files -s` mode 120000)로 quality-gates · spec-distill 두 곳에만
간다. agent-transparency · plugin-audit · project-init 에는 링크도 사본도 없다.

### 1.2 배선이 절반이다

**생산자 쪽** — 프로덕션 처분 호출 18건이 **전부 배관 사고**다(파일 부재 · 파싱 실패 · 비-dict
원소 · 스키마 불일치 · 소스 미가용 · 타입 강제). 「리뷰어가 보고 판단해서 배제」를 세는 호출은
**0건**이다. 그 사건이 안 일어나서가 아니다 — 일어나는 자리가 코드에 둘 있고 둘 다 계산기를
쥔 채 버린다:

```python
# plugins/quality-gates/scripts/synthesize_findings.py:298-310
if v is None:
    if ledger is not None:
        ledger.hold(finding_id(f), "adversarial 판정 부재")   # 부른다
    out.append(f)
    continue
verdict = v.get("verdict", "confirm")
if verdict == "reject":
    continue                                                  # 안 부른다
```

같은 모양이 `plugins/quality-gates/scripts/synthesize_artifact_findings.py:201-203` 에 하나 더.

**소비자 쪽** — `report()` 는 카운트 여섯을 내는데(`:121-133`) 프로덕션이 꺼내 읽는 것은 `held`
하나뿐이다. `accepted` · `rejected` · `absorbed` · `coerced` · `sources_failed` 다섯은 **독자 0**.
즉 `accept()` 는 불리지만 그 결과가 어디로도 가지 않는다.

### 1.3 계산기 밖에 평행 어휘가 셋 산다

| # | 어디 | 무엇을 따로 세나 |
|---|---|---|
| ⓐ | `synthesize_findings.py:539-553` | `dropped_raw`/`dropped_verdicts`/`dropped_newlist`/`dropped_primary`/`dropped_promoted` 를 스칼라 하나로 합산 + `suppressed_count` 별도(`:494`) |
| ⓑ | `synthesize_artifact_findings.py:235-243` | `degraded` · `degraded_reason` 4값을 원장과 무관하게 자체 계산 |
| ⓒ | `plugins/plugin-audit/scripts/audit-workflow.js:492…596` | `degradedEvents` — JS 라 계산기 심볼릭 링크가 못 감 |

**그래서 새 어휘를 그냥 얹으면 판정자가 셋에서 넷이 된다.** 이 설계는 ⓐⓑ 를 계산기로 **흡수**한다
(치환). ⓒ 는 §7 로 뺀다.

### 1.4 강제가 없다

「계산기를 부르라」를 강제하는 것은 오늘 `shared/tests/test_dispatch_disposition.sh` 의 축 B
하나뿐이고, 그것은 처분 앵커가 `consumer=` 로 지목한 `.py` **4파일**에만 걸리며 *"`import` 가
있는가"* 까지만 본다. 부르는지 · 읽는지는 안 본다. **1.3 의 평행 어휘 셋이 그 사이로 자랐다.**

## 2. 도출 규칙 — 목록을 적지 않고 계산한다

검사 대상은 **실행 사실**에서 뽑는다. 파일 이름으로 뽑으면 이름을 바꿔 빠져나갈 수 있고,
새 표식(`# 판정` 주석 등)을 요구하면 「안 적으면 대상 아님」이 되어 이미 잡힌 실패
(`plugins/spec-distill/CHANGELOG.md:2347` — 저자가 접두사를 빼서 자기 skill 을 감사 대상에서
제외한 사건)를 재발명한다.

| 집합 | 신호 | 오늘 도출되는 것 |
|---|---|---|
| **㉮ 회계 소비자** | `plugins/*/scripts/*.py` 가 `adjudication` 을 import | **4** — `synthesize_findings.py` · `synthesize_artifact_findings.py` · `merge_review.py` · `merge_brief_review.py` |
| **㉯ 외부 모델 판정자** | `.sh` 가 `codex exec` 를 실행하거나 `runner_common.sh` 를 로드 | **6** — `run_codex_reviewer` · `run_artifact_codex_reviewer` · `run_audit_codex_reviewer` · `run_brief_codex_reviewer` · `run_seed_codex_reviewer` · `run_spec_codex_reviewer` |
| **㉰ 서브에이전트 판정자** | `plugins/*/agents/*.md` 의 `name:` — **기존 락이 이미 쓰는 ∀** | **20** |

**양성 대조 (구현 시 필수)** — ㉯ 의 신호는 `detect_codex.sh`(탐지만 함, 4사본)와
`runner_common.sh`(라이브러리, 3사본)를 **뽑아내면 안 된다**. 그 둘이 나오면 신호가 너무 헐거운
것이므로 규칙을 조인다.

**㉯가 새로 들어오는 부분이다.** 오늘 이 여섯은 처분 선언도 회계도 없다 — brief C7 이 넓히라고
한 「항목이 생기기 전에 리뷰어가 통째로 죽는 계층」이 여기다.

**도출 축의 선례** — `shared/tests/adopter_derivation.sh:36` 의 `derive_reference_adopters` 가
같은 모양(채택자를 열거하지 않고 포인터에서 도출)을 이미 쓴다. 새 라이브러리를 만들지 않고
이 축을 재사용한다.

## 3. 작업 A — 배선

| # | 자리 | 부를 것 | 비고 |
|---|---|---|---|
| A1 | `synthesize_findings.py:309` | `reject(finding_id(f), why)` | 계산기가 이미 인자로 들어와 있다 |
| A2 | `synthesize_artifact_findings.py:202` | `reject(...)` | 같은 모양 |
| A3 | `synthesize_findings.py:336-342` (dedup) | `absorbed(item, into)` | `dedup(findings)` 가 계산기를 안 받는다 — 인자 추가 (`:554` 호출부) |
| A4 | 입력 직후 정규화 패스 (신규) | `coerced(field, frm, to)` | 아래 |
| A5 | `synthesize_findings.py:361-362` (suppress) | **새 메서드 `suppressed(item, why)`** | D4 |
| A6 | `synthesize_artifact_findings.py:100-155` | `source_failed(...)` | 자체 int 카운터를 계산기로 교체 |

**A4 의 함정.** `_norm_sev`(`:386-412`)는 dedup(`:334`) · suppress(`:359`) · 정렬(`:370`) ·
표시(`:471`) **네 곳**에서 불린다. 그 함수 안에 계산기를 넣으면 **같은 항목이 네 번 세어진다.**
그래서 계산기 호출을 함수 안이 아니라 **입력 직후 정규화 패스 한 번**으로 옮기고 정규화된 값을
항목에 써 둔다. `_norm_sev` 는 그 뒤 항상 정상 값을 만나 그대로 반환하며, 네 호출부는 손대지
않는다. 그 함수의 주석이 *"폭발 반경이 파이프라인 전체"* 라고 적으므로 시그니처는 바꾸지 않는다.

**A5 — 어휘를 여덟 개로 늘린다.** `suppress()` 는 리뷰어의 판단이 아니라 규칙
(`sev != CRITICAL and conf <= 4`)으로 버린다. 「사람이 보고 버림」과 「규칙이 걸러냄」을 한 칸에
넣으면 D2 가 없애려던 실명이 그 안에서 재발한다. 새 메서드 `suppressed(item, why)` 를 추가하고
`report()["counts"]["suppressed"]` 로 낸다.

**A7 — `surfaced()` 배선.** 오늘 외부 호출자도 내부 호출자도 0이라 `items` 인자가 프로덕션에서
아무 관측 가능한 차이를 만들지 않는다. `synthesize_artifact_findings.py` 가 `items="closed"` 로
미판정 항목을 제외하므로(`:195`, `:199-200`), 거기에 `surfaced()` 를 배선해 **제외한 것을 보이게**
한다. 삭제가 아니라 배선인 이유는 D1(버려지는 것이 세어진다)과 방향이 같기 때문이다.

**A8 — `hold()` 의 과부하 해소.** 오늘 `hold()` 가 두 가지에 쓰인다:

| 오늘 `hold` 인 것 | 실제로 무엇인가 | 어느 칸 |
|---|---|---|
| `synthesize_findings.py:305` `"adversarial 판정 부재"` | 판정자가 판정을 안 냈다 | **처분** (미판정) |
| `merge_review.py:96` `"비-dict 원소"` · `:321` `"id 없는 원장 레코드"` · `merge_brief_review.py:180` · `:289` `"YAML 마커 위반"` | 항목 자체가 깨져 있다 | **배관** |

D2(두 지표로 쪼갠다)를 적용하면 이 둘이 한 칸에 있으면 안 된다. **`hold` 는 「판정자가 없었다」에
한정**하고, 항목이 깨진 경우는 `source_failed(name=<항목 위치>, why=..., primary=False)` 로 옮긴다.
`primary=False` 인 이유는 그 항목 하나가 깨진 것이지 **소스 전체가 죽은 것이 아니기 때문**이다 —
`blocks()` 는 `primary=True` 에만 걸리므로 차단 판정이 바뀌지 않는다(§5).

이 변경은 `plugins/spec-distill/tests/test_merge_review_adjudication.py`(비-dict = held 를 단언)를
RED 로 만든다 — §4.3 에 넣는다.

## 4. 작업 B — 락 넷

전부 **오늘 RED 여야 한다.** RED 가 아니면 락이 아무것도 안 재고 있다는 뜻이므로, 각 락의 첫
실행 결과를 착수 기록에 남긴다.

| 락 | 대상 | 요구 | 오늘 예상 |
|---|---|---|---|
| **A 배선** | ㉮ 4파일 | findings 원소를 버리는 분기 앞에 계산기 호출이 있어야 한다. `ast.parse` 로 판정 | **RED** — `synthesize_findings.py:309` · `synthesize_artifact_findings.py:202` |

**「버리는 분기」의 정의 (락 A 가 판정하는 것).** findings 컬렉션을 순회하는 `for` 안에서, 그
반복의 원소가 출력 컬렉션에 도달하지 못하고 끝나는 경로 — 구체적으로 `continue` · `break` ·
이른 `return` · 원소를 append 하지 않고 지나가는 분기. 각 경로에 대해 **같은 분기 안에**
`ledger.<메서드>(...)` 호출이 있어야 한다. 리스트 컴프리헨션의 `if` 필터도 같은 취급이다 —
그 자리는 계산기를 부를 수 없으므로 명시적 루프로 풀거나 필터 결과의 차집합을 세야 한다.
| **B 소비** | 계산기 출력 | `report()` 가 내는 카운트가 전부 프로덕션 출력에 실려야 한다 | **RED** — 6 중 5 미소비 |
| **C 입력 선언** | ㉰ 20 에이전트 | 정의가 입력 슬롯을 기계 판독 가능한 형태로 선언하고 dispatch 가 정확히 그것을 준다 | **RED** — 오늘 2/20 |
| **D 앵커 확대** | ㉯ 6 러너 | 처분 선언(`consumer=` · `fail-*` · `disclosure=`)을 가져야 한다 | **RED** — 6/6 없음 |

### 4.1 락 C 가 프레이밍 축을 흡수한다

별도 프레이밍 계약을 만들지 않는다. 락 C 가 *"dispatch 는 선언된 슬롯만 준다"* 를 강제하면
선언되지 않은 것(= 앞 리뷰어의 판정)은 **자동으로 못 간다.**

- **정당화 없는 누출 4건이 RED** — `plugins/spec-distill/skills/reviewing-spec/SKILL.md:54`
  (`Previous issue history` — 사용자가 무엇을 기각·수용했는지까지 새 리뷰어에게 실린다) +
  `plugins/spec-distill/skills/conducting-interview/SKILL.md:222` · `:238` · `:297`.
- **설계된 P 6건은 슬롯 선언으로 통과** — adversarial · refuter 계열은 앞 판정을 반박하는 것이
  과업이다. `<prior_findings>` 를 슬롯으로 선언하면 과업이 사라지지 않는다.
- **함께 드러나는 비대칭** — `reviewing-spec` 은 Claude 리뷰어에게만 이력을 주고 codex(`:89`)
  에는 안 준다. 「독립 두 리뷰어」가 다른 입력을 받고 있다. 슬롯 선언이 이 차이를 명시로 만든다.

**프로토타입이 이미 있다** — `plugins/spec-distill/tests/test_seed_agents.sh:160-195` 가 정확히
이 대조를 하고, `:197` 에서 대상 수를 **2로 하드코딩**했을 뿐이다. 그 한 줄을 ㉰ 도출로 바꾼다.

**락 C 가 brief 의 확인된 결함 둘(OQ7 · OQ8)을 해소한다** — 「에이전트 정의가 선언한 슬롯을
dispatch 가 보내지 않는다」가 정확히 이 락의 RED 다.

### 4.2 함정 둘

**⑴ presence 락은 코퍼스를 넓히면 안 된다.** 락 C · D 는 「X 는 Y 를 가져야 한다」 형태다.
공유 계약 파일(`plugins/*/references/*.md`)이나 CHANGELOG 를 코퍼스에 넣으면 **그 파일이 대신
만족시켜서**, 대상 파일이 문구를 통째로 잃어도 통과한다. 각 파일이 자기 힘으로 만족해야 하고,
헬퍼가 이미 있다 — `shared/tests/presence_corpus.sh:32-40` 의
`assert_presence_corpus_skill_owned`. (absence 락은 반대로 넓혀야 한다 — 방향을 섞지 않는다.)

**⑵ 범위는 선언이 아니라 실행 사실이 정한다.** 락 D 가 러너에 처분 선언을 요구하지만, 대상은
㉯(codex 를 돌린다)가 정한다. 선언을 안 적으면 빠지는 것이 아니라 RED 다. ∃-존재검사가 아니라
∀-지배관계다.

### 4.3 동시에 편집해야 하는 기존 락 넷

1.3 의 ⓐⓑ 를 계산기로 흡수하는 순간 아래가 설계상 RED 가 된다. 같은 커밋에서 함께 고친다.

| 락 | 무엇이 깨지나 |
|---|---|
| `plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh` | 생산자 문구와 소비자 SKILL 분기의 **문자열 동일성**을 잰다 — 출력 문면이 바뀌면 RED |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh:86-241` | `degraded_reason` **닫힌 어휘 4값** |
| `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` | `dropped` 계수가 컨테이너 수준 + 항목 수준 둘 다 |
| `plugins/spec-distill/tests/test_merge_review_adjudication.py` | 「비-dict 원소 = held」를 단언한다 — A8 이 그것을 `source_failed(primary=False)` 로 옮긴다 |

`test_skill_drop_notice_consumed.sh` 는 리포에서 **생산자–소비자 seam 을 재는 유일한 락**이다.
약화시키지 않는다 — 새 문면에 맞춰 갱신한다.

### 4.4 PR 분할

작업 D 는 A·B·C 와 의존이 없다. 셋으로 나눈다.

| PR | 내용 | 왜 분리 |
|---|---|---|
| **PR1** | 작업 D — stale 이름 제거 + 락 ㉰ 역방향 | 독립. 작고 즉시 검증 가능. 먼저 넣어 도출 축의 양방향을 확보 |
| **PR2** | 락 A·B·C·D 신설 (**전부 RED 상태로**) | 락을 먼저 넣어 M1(전부 RED)을 기록으로 남긴다. 이 PR 은 의도적으로 RED 를 남기므로 머지 조건이 다르다 — 브랜치 안에서 PR3 와 함께 GREEN 이 된다 |
| **PR3** | 작업 A(배선) + C(출력) + §4.3 의 기존 락 넷 동시 편집 | PR2 의 RED 를 GREEN 으로 만든다 |

**PR2 를 분리하는 이유** — 락과 수정을 한 PR 에 넣으면 「락이 원래부터 GREEN 이었는지」를
나중에 구별할 수 없다. RED 를 별도 커밋으로 남겨야 M1 이 증거가 된다.

## 5. 작업 C — 출력 모양

계산기의 `blocks()`(`adjudication.py:89-98`)가 게이트 판정을 이미 계산한다 — *"주(主) 입력이
죽었거나 게이트를 바꾸는 강제가 있었나"*. 외부 호출자가 0이라 표면만 죽어 있다. 락 B 가 되살린다.

```
**Findings:** 0 CRITICAL / 3 IMPORTANT / 5 SUGGESTION
**처분:** 기각 7 · 억제 2 · 흡수 4 · 미판정 1          ← 상태별, 차단 아님
**배관 손실:** 3 (차단 아님)                            ← 합계. 차단 여부는 blocks() 가 정한다
```

| 칸 | 들어가는 것 | 차단 |
|---|---|---|
| **처분** | `rejected` · `suppressed` · `absorbed` · `held`(판정자 부재에 한정 — A8) | 아니오 |
| **배관 손실** | `sources_failed`(주·보조 모두) · `uncountable` · `coerced` | `blocks()` 가 정한다 |

**칸의 합계와 차단은 같은 집합이 아니다.** `blocks()`(`adjudication.py:89-98`)는 **주(主) 입력
사망 또는 게이트를 바꾸는 강제**에만 걸린다. 그래서 배관 손실이 3이어도 전부 `primary=False` 인
항목 단위 파손이면 차단하지 않는다 — 그 사실을 칸 옆에 `(차단 아님)` / `(차단)` 으로 **명시**한다.
숫자만 내면 「3인데 왜 안 막았나」가 읽는 쪽의 추측이 된다.

**왜 쪼개는가.** 합계 하나로 두면 기각을 흡수로 재분류해도 총계가 안 변해 대리지표 치환이
안 먹지만 범주가 안 보인다. 상태별로만 두면 범주는 보이는데 재분류가 지표를 낮추는 최단 경로가
된다. 쪼개면 **재분류해도 게이트가 안 움직이므로 유인이 사라지고**, 범주는 그대로 보인다.
`coerced(gate=False)` 는 공시만 하고 게이트에 넣지 않는다 — 이 구분은 CLAUDE.md 의
「강제가 게이트 판정을 바꾸면 degrade」와 같은 술어다.

## 6. 작업 D — stale 이름과 역방향 락

`plugins/quality-gates/skills/quality-pipeline/SKILL.md:511` 이 `quality-gates:synthesizer` 를
dispatch 하라고 지시한다. **그 에이전트는 없다.** `git log` 가 이유를 보여준다 —
`37ea0d7 refactor(quality-gates): synthesizer agent → script (T3-2, v1.28.0)` 이 정의를 지우고
`synthesize_findings.py` 로 옮겼다. 괄호 안 `(or local synthesize_findings.py)` 가 지금은 유일하게
맞는 경로다.

| 작업 | 내용 |
|---|---|
| **D-1** | `SKILL.md:511` 에서 stale 이름 제거, 스크립트 호출로 정리 |
| **D-2** | 락 ㉰ 에 **역방향** 추가 — *"dispatch 되는 이름은 전부 `plugins/*/agents/*.md` 에 정의가 있어야 한다"* |

**D-2 가 필요한 이유** — `shared/tests/test_dispatch_disposition.sh:294` 는 *"정의된 에이전트는
전부 최소 한 번 dispatch 돼야 한다"*(죽은 정의 탐지)만 본다. 반대 방향이 비어 있었고 정확히 그
방향으로 stale 이 흘렀다. 이름만 지우면 다음 리팩터에서 반복된다. 양방향 대조는 리포에 이미 있는
패턴이다 — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`.

**미확인** — 이름이 resolve 되지 않을 때 무슨 일이 나는지. `plugins/plugin-audit/scripts/smoke-workflow.js:20-22`
가 *"resolve 되지 않으면 쓰기 권한이 있는 기본 에이전트가 대신 돈다"* 라고 적지만 그것은
**Workflow 층의 `agent()`** 에 대한 기록이고, skill 안의 `Agent(...)` 도 같은지는 확인되지 않았다.
같다면 Law 2 구멍이고, 아니면 헛호출 한 번이다. 이 설계는 **어느 쪽도 전제하지 않는다** —
D-1·D-2 는 두 경우 모두에서 옳다.

## 7. 제외 범위와 근거

| 제외 | 근거 | 어느 열린 질문 |
|---|---|---|
| **훅 층 회계** | `plugins/agent-transparency/tests/test_plugin_contract.py:920-965`(`TestNoHooksRemain`)가 훅 재설치를 fail-closed 로 금지한다. 다른 플러그인의 확정 결정 → **C6 분기 ⑵**(기록된 설계 이유) | OQ25 · OQ26 |
| **codex 스키마 둘의 통일** | 합치면 각각 hard crash 와 false-clean. `shared/codex/runner_common.sh:11-35` 가 코드 주석으로 이미 명시 → **C6 분기 ⑵** | OQ18 (닫힘) |
| **`audit-workflow.js` 의 `degradedEvents`(1.3 ⓒ)** | 계산기가 파이썬 모듈이고 JS 에 대응물이 원리적으로 없다 → **C6 분기 ⑴** | — |
| **자동 실행자 신설** | 사용자가 이 단계에서 범위 밖으로 선택. **결과** — 락 넷은 `/qg` 가 그 파일을 고르거나 사람이 손으로 돌릴 때만 발화한다. 리포에 `.github/` · Makefile 이 없고 훅에서 `shared/tests` 호출이 0건이다 | — |
| **cross-family 를 계약이 요구하기** | 락 D 는 러너에 처분 선언을 요구하는 데까지다. *"되돌리기 어려운 자리에 다른 모델 계열을 요구한다"* 는 넣지 않는다 — C14 가 별도 축으로 확정 | OQ16 (열린 채) |
| **산문 지시 2자리** | `quality-pipeline/SKILL.md:488`(Tier C 전문가)는 프롬프트 리터럴이 파일에 없어 무엇이 실리는지 **셀 수 없다**. 침묵을 clean 으로 읽지 않고 Known gaps 로 이월 | OQ10 |

## 8. 착수 전 선결 조건

| # | 확인할 것 | 왜 |
|---|---|---|
| P1 | `plugins/spec-distill/scripts/check_seed.py` + `tests/test_seed_one_sentence.sh` 가 락 C 와 실제로 충돌하는가 | 그 락은 *"seed 본문에 슬롯 존재 검사를 추가하지 마라"* 를 강제한다. 락 C 는 **에이전트 정의와 dispatch 프롬프트**를 보므로 대상이 다를 가능성이 높지만 원문 미확인. 진짜 충돌이면 **C6 분기 ⑵** 로 뺀다 |
| P2 | ㉯ 도출이 `detect_codex.sh` · `runner_common.sh` 를 뽑지 않는가 | 뽑으면 신호가 헐거운 것 (§2 양성 대조) |
| P3 | 락 넷의 첫 실행이 **전부 RED 인가** | GREEN 이면 그 락은 아무것도 안 재고 있다 |
| P4 | 오늘 `shared/tests/test_dispatch_disposition.sh` 가 GREEN 인가 (앵커 20 기준) | 조사가 실행하지 못했다. 인용된 `17/17` 은 앵커 18개 시절 기록이다 — 착수 baseline 을 직접 잡는다 |

## 9. 위험

- **대리지표 치환** — 세어지기 시작하면 판정자가 자기 기각을 다른 범주로 재분류하는 것이 지표를
  낮추는 최단 경로가 된다. §5 의 쪼개기가 구조적 답이다(게이트가 안 움직이므로 유인이 없다).
  산문 지시로는 못 막는다 — 리포에 「항상」을 산문으로 적었다가 조용히 꺼진 사례가 있다.
- **락을 만들어도 아무도 안 돌린다** — §7 의 자동 실행자 제외가 이 위험을 그대로 남긴다.
  Known gaps 로 이월하고 다음 사이클의 1순위 후보로 둔다.
- **원장이 깨끗한 것이 「판정이 온전했다」로 읽힌다** — 실제로 참인 명제는 「파서가 죽지 않았다」
  뿐이다. §5 의 두 칸 분리가 이것을 문면에서 갈라 놓지만, 읽는 쪽의 해석까지 강제하지는 못한다.
- **`_norm_sev` 의 폭발 반경** — 그 함수는 네 곳에서 불리고 주석이 과거 사고(비-해시가능 값이
  `TypeError` 로 파이프라인 전체를 죽임)를 기록한다. A4 는 시그니처를 안 바꾸는 쪽으로 설계했으나
  정규화 패스 추가 자체가 순서 의존을 만들 수 있다.
- **동시 편집 락 셋(§4.3)의 회귀** — 특히 `test_skill_drop_notice_consumed.sh` 는 생산자–소비자
  seam 을 재는 유일한 락이다. 문면을 맞추느라 그 락의 이빨을 지우면 이번 작업이 정확히 자기가
  고치려던 실패를 신설한다.
- **정적 검사의 절대 경계** — 에이전트 이름을 문자열 연결로 쪼개면
  (`P1 = "spec-distill:"; P2 = "seed-readback"`) 이 리포의 dispatch 락도 새 락도 **완전히
  침묵한다**(실측 기록 있음). 새 락도 정적인 한 이 경계를 넘지 못한다.

## 10. 기각한 대안

- **기각 — 배선만 하고 락을 안 만든다.** 오늘 세게 만들지만 내일 다시 안 세어지는 것을 막지
  못한다. 증거가 있다 — 계산기는 이미 있었는데 1.3 의 평행 어휘 셋이 그 밖에서 자랐고 막는 것이
  없었다.
- **기각 — 러너·합성기에 `# **판정** —` 같은 새 표식을 요구한다.** 「안 적으면 대상 아님」이
  되어 `plugins/spec-distill/CHANGELOG.md:2347` 의 실제 사건을 재발명한다. 현행 락은 그 봉쇄를
  이미 코드에 넣어 뒀는데(`test_dispatch_disposition.sh:90-91`) 새 표식이 표식 층에서 되돌린다.
- **기각 — 락 코퍼스의 글롭·확장자만 넓힌다.** dispatch 정규식이 `.py`/`.sh` 에서 아무것도 못
  찾으므로 dispatch 수도 앵커 수도 그대로다 — 아무 축도 안 움직인다.
- **기각 — presence 락의 코퍼스를 공유 계약 파일까지 넓힌다.** 그 파일이 대신 만족시켜 대상
  파일이 문구를 잃어도 통과한다. absence 락의 처방을 presence 에 잘못 옮기는 형태다.
- **기각 — 규칙 억제를 `reject` 에 합친다.** 「사람이 보고 버림」과 「규칙이 걸러냄」이 한 숫자가
  되어 D2 가 없애려던 실명이 그 안에서 재발한다.
- **기각 — 별도 프레이밍 계약을 만든다.** 락 C 가 흡수한다(§4.1). 두 번째 판정자를 만들면
  drift 쌍이 된다.
- **기각 — 훅 층까지 넓힌다(전면안).** 다른 플러그인의 fail-closed 결정을 뒤집어야 하고 동시
  편집할 락이 6건 이상인데, 자동 실행자가 없어 그 락들이 실제로 도는지 확인할 방법이 오늘 없다.

## 11. 완료 측정

| # | 재는 법 | 통과 조건 |
|---|---|---|
| M1 | 락 넷을 착수 시점에 실행 | **전부 RED**. GREEN 인 락은 이빨이 없으므로 재설계 |
| M2 | 작업 A 후 같은 락 실행 | 전부 GREEN |
| M3 | 각 락에 **변이**를 가한다 — 배선 한 줄 삭제 · 슬롯 선언 삭제 · 앵커 삭제 · 정의 삭제 | 각각 해당 락만 RED. 여럿이 함께 죽으면 변이 선택이 잘못된 것 |
| M4 | `/qg` 를 실제 변경에 돌려 출력을 본다 | §5 의 세 줄이 실제로 나온다. 「처분」 칸의 숫자가 0이 아닌 라운드를 최소 하나 확보 |
| M5 | ㉮㉯㉰ 도출을 실행 | 4 / 6 / 20. `detect_codex.sh`·`runner_common.sh` 가 ㉯ 에 없다 |
| M6 | 기존 락 전량 실행 (§4.3 넷 포함) | 착수 baseline(P4) 대비 신규 RED 0 |

**M3 의 전제** — 변이 전에 커밋한다. `git checkout --` 는 마지막 변이가 아니라 HEAD 로 되돌리므로,
미커밋 상태에서 변이하면 복원이 다른 것을 지운다.

## 12. Known gaps — 이월

- **자동 실행자 부재** — 락이 늘어날수록 「만들었는데 안 돈다」의 비용이 커진다. 다음 사이클
  1순위 후보.
- **`disclosure=` 채널이 실제로 읽히는지** — 원리적으로 정적 검사 밖이다. 그 seam 을 재는 락은
  리포 전체에 `test_skill_drop_notice_consumed.sh` 하나뿐이고, 나머지 자리는 미측정이다.
- **축 A⑤ 의 이름과 이빨** — 코드에는 7축인데 문서(`CLAUDE.md:58`, CHANGELOG 4개, 감사문서)는
  6축으로 적는다. A⑤ 는 mutation 검증도 0건이다.
- **`# guards:` 선언의 하한** — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`
  의 방향 B 가 글롭당 `n > 0` 이라, `guards: plugins/**` 가 737 중 22 만 훑고도 통과한다.
  이번에 대상을 넓히면서 이 선언을 안 고치면 커버리지 대조는 여전히 「글롭당 1건 이상」이다.
- **OQ16 (다른 모델 계열의 처분)** · **OQ5 (착수 자료였던 감사 문서의 처분)** · **OQ10 (비판자
  아닌 두 자리)** · **OQ21 (S1 이 이관한 유보)** — 이 설계가 답하지 않았다.
- **brief 의 방향성 지적 13건이 열린 채다** — 특히 축 교체가 단독 저자 preprint 하나에 기대고,
  brief 가 [취함]으로 실은 논문 둘은 모든 비판자에게 같은 전체 맥락을 준다. 이 설계는 그 축을
  **락 C 로 좁게 흡수**해(선언된 슬롯만 준다) 축 자체의 참·거짓에 덜 의존하게 만들었지만,
  지적을 해소한 것은 아니다.
