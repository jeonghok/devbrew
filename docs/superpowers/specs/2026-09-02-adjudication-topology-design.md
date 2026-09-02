# 판정 지형 — 회계 배선과 도출 락 · Design

> 판정을 버릴 때 이름을 부르게 하고, 그 이름을 부르는지 구조에서 도출해 검사한다.

## Handoff Context

- **입력** — `docs/superpowers/interview/2026-09-02-adjudication-topology-interview.md`
  (확정 17 · 잠정 2 · 열린 질문 26). 텔레메트리는 같은 이름의 `.audit.md`.
- **이 문서가 정하는 것** — brief 가 의도적으로 미확정으로 남긴 OQ1(통일 계약의 구체적 형태).
- **사용자가 이 단계에서 정한 것 여섯** — §0 의 표(D1–D6).
- **다음** — `superpowers:writing-plans`.

### 이름 규약 (round 1 리뷰가 네임스페이스 충돌을 지적해 통일)

| 접두 | 무엇 |
|---|---|
| **T1–T5** | 작업(task) |
| **L1–L4** | 락(lock) |
| **㉮㉯㉰** | 도출된 대상 집합 |
| **D1–D6** | 사용자 결정 |

### 근거의 지위

`file:line` 은 세 출처다. **⒜ 저자가 직접 읽어 확인** — `shared/adjudication/adjudication.py` 전체
(`blocks()` `:89-98` · `surfaced()` `:136-144` 포함), `synthesize_findings.py` 인용 구간,
도출 규칙이 뽑는 세 집합, `quality-pipeline/SKILL.md:511`, `git log` 의 `37ea0d7`,
`test_seed_agents.sh:123`·`:197`, 두 codex 추출기의 실재. **⒝ 읽기전용 조사 4건.**
**⒞ round 1 리뷰(Claude `spec-reviewer` + codex)가 반증해 이 판본이 고친 것** — §13 에 열거.

조사도 리뷰어도 **어떤 락도 실행하지 못했다**(읽기전용 제약 × `mktemp -d`). 「오늘 전부
GREEN 인가」는 이 문서의 어느 문장도 주장하지 않는다 — §8 P4 가 착수 baseline 으로 남긴다.

## 목차

- [0. 한눈에](#0-한눈에)
- [1. 문제 — 계산기는 있는데 부르지 않는다](#1-문제--계산기는-있는데-부르지-않는다)
- [2. 도출 규칙 — 목록을 적지 않고 계산한다](#2-도출-규칙--목록을-적지-않고-계산한다)
- [3. 작업 T1 — 배선](#3-작업-t1--배선)
- [4. 작업 T2 — 락 넷 L1–L4](#4-작업-t2--락-넷-l1l4)
- [5. 작업 T3 — 출력 모양](#5-작업-t3--출력-모양)
- [6. 작업 T4 — stale 이름과 역방향 락](#6-작업-t4--stale-이름과-역방향-락)
- [7. 작업 T5 — 훅 층 회계](#7-작업-t5--훅-층-회계)
- [8. 제외 범위와 근거](#8-제외-범위와-근거)
- [9. 착수 전 선결 조건](#9-착수-전-선결-조건)
- [10. 위험](#10-위험)
- [11. 기각한 대안](#11-기각한-대안)
- [12. 완료 측정](#12-완료-측정)
- [13. 재결정 기록 · Known gaps](#13-재결정-기록--known-gaps)

## 0. 한눈에

**무엇** — 판정 항목이 버려질 때 `shared/adjudication/adjudication.py` 의 `Ledger` 메서드를
반드시 부르게 하고, 그것을 부르는지 검사하는 락 넷을 둔다. 검사 대상은 **목록이 아니라 구조에서
도출**하되, 이미 리포에 있는 도출기를 **재사용**한다(신설하면 세 번째 판정자가 된다).

**왜** — 계산기는 이미 있고 `report()` 는 카운트 여섯을 이미 낸다. 그런데 프로덕션이 읽는 것은
`held` 하나뿐이고, 리뷰어가 보고 버린 항목(`reject`)은 계산기를 손에 쥔 채 맨 `continue` 로
사라진다. 「무엇이 버려졌나」를 세는 술어에 **호출자가 0건**이다.

**사용자가 이 단계에서 정한 것**

| # | 결정 | 결과 |
|---|---|---|
| D1 | 세 축이 충돌하면 **회계가 이긴다** — 성공 = 버려지는 것이 세어짐 | 입력·역할 축은 회계에 봉사 |
| D2 | 공시는 **두 지표로 쪼갠다** — 배관 손실 / 판정 처분 | §5 |
| D3 | **도출 우선** — 배선 + 대상을 스스로 계산하는 락 | §2·§4 |
| D4 | 규칙 억제는 **새 칸 「억제」로 분리** | §3 T1-5 |
| D5 | stale 에이전트 이름은 **제거**하고 그 방향을 보는 락을 둔다 | §6 |
| D6 | **자동 실행자 신설은 범위 밖** | §8 + §10 위험 |

**축 셋이 어디에 있나** (round 1 리뷰가 C5 의 「역할 구조」에 작업이 없다고 지적 — 실은
있었고 이름이 안 붙어 있었다):

| 확정 제약 C5 의 축 | 이 문서의 어디 |
|---|---|
| **입력 계약** | L3(선언↔전달 일치) + L3b(선언 가능한 종류) |
| **역할 구조** | L4(러너도 `consumer=`·`fail-*`·`disclosure=` 를 선언) + T4-2(어느 이름이 정당한 판정자인가) + T5(훅의 차단 자리도 처분을 선언) |
| **회계 어휘** | T1(배선) + L1(버릴 때 부른다) + L2(센 것을 낸다) + T3(출력) |

## 1. 문제 — 계산기는 있는데 부르지 않는다

### 1.1 어휘는 완성돼 있다

`shared/adjudication/adjudication.py` 의 `Ledger` 는 처분 메서드 일곱을 갖는다 — `accept`(:43) ·
`reject`(:47) · `hold`(:51) · `absorbed`(:55) · `coerced`(:59) · `source_failed`(:67) ·
`uncountable`(:75). 판정 보조로 `blocks`(:89) · `reasons`(:106) · `report`(:121) · `surfaced`(:136).

배포는 **심볼릭 링크**(mode 120000)로 quality-gates · spec-distill 두 곳에만 간다.

### 1.2 배선이 절반이다

**생산자 쪽** — 프로덕션 처분 호출 18건이 **전부 배관 사고**다. 「리뷰어가 보고 판단해서 배제」를
세는 호출은 **0건**이다. 그 사건이 안 일어나서가 아니다 — 일어나는 자리가 코드에 둘 있고 둘 다
계산기를 쥔 채 버린다. `plugins/quality-gates/scripts/synthesize_findings.py:298-310` verbatim:

```python
        f = _normalize_identity(dict(f))
        v = by_id.get(finding_id(f))
        if v is None:
            # (주석 3줄 생략 — 원문 :301-303)
            if ledger is not None:
                ledger.hold(finding_id(f), "adversarial 판정 부재")   # 부른다
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            continue                                                  # 안 부른다
```

같은 모양이 `synthesize_artifact_findings.py:201-203` 에 하나 더.

**소비자 쪽** — `report()` 는 카운트 여섯을 내는데(`:121-133`) 프로덕션이 꺼내 읽는 것은 `held`
하나뿐이다. `accepted` · `rejected` · `absorbed` · `coerced` · `sources_failed` 다섯은 **독자 0**.

### 1.3 계산기 밖에 평행 어휘가 셋 산다

| # | 어디 | 무엇을 따로 세나 | 이 사이클의 처분 |
|---|---|---|---|
| ⓐ | `synthesize_findings.py:539-553` | `dropped_*` 5종 합산 + `suppressed_count`(`:494`) | **흡수**(T1) |
| ⓑ | `synthesize_artifact_findings.py:235-243` | `degraded`·`degraded_reason` 4값을 자체 계산 | **흡수**(T1) |
| ⓒ | `plugins/plugin-audit/scripts/audit-workflow.js:492…596` | `degradedEvents` — JS | **제외**(§8) |

**ⓒ 를 제외하면 판정자가 둘로 남는다** — 계산기(파이썬)와 `degradedEvents`(JS). 즉 brief OQ22 가
경고한 drift 쌍 조건이 **이 사이클 이후에도 성립한다.** §13 에 이월한다.

### 1.4 강제가 없다

「계산기를 부르라」를 강제하는 것은 오늘 `shared/tests/test_dispatch_disposition.sh` 의 축 B
하나뿐이고, 처분 앵커가 `consumer=` 로 지목한 `.py` **4파일**에만 걸리며 *"`import` 가 있는가"*
까지만 본다. 부르는지·읽는지는 안 본다. **1.3 의 평행 어휘가 그 사이로 자랐다.**

## 2. 도출 규칙 — 목록을 적지 않고 계산한다

검사 대상은 **실행 사실**에서 뽑는다. 이름으로 뽑으면 이름을 바꿔 빠져나갈 수 있고, 새 표식
(`# 판정` 주석 등)을 요구하면 「안 적으면 대상 아님」이 되어 이미 잡힌 실패
(`plugins/spec-distill/CHANGELOG.md:2347` — 저자가 접두사를 빼서 자기 skill 을 감사에서 제외한
사건)를 재발명한다.

| 집합 | 신호 | 판정기 | 오늘 나오는 것 |
|---|---|---|---|
| **㉮ 회계 소비자** | `plugins/*/scripts/*.py` 가 `adjudication` 을 import | grep | **4** |
| **㉯ 외부 모델 판정자** | `plugins/*/scripts/*.sh` 가 **비-주석 줄에서** `codex exec` 실행 | **기존 `plugins/quality-gates/tests/lib/extract_codex_invocations.py`** | **6** |
| **㉰ 서브에이전트 판정자** | `plugins/*/agents/*.md` 의 `name:` | 기존 락의 ∀ | **20** |

### 2.1 ㉯ 는 신설하지 않고 재사용한다 (round 1 리뷰가 고친 것)

앞 판본은 ㉯ 를 *"`codex exec` 를 실행하거나 `runner_common.sh` 를 로드"* 로 정의하고 `.sh` 를
무스코프로 뒀다. 리뷰가 셋을 반증했다:

1. **도출값이 6 이 아니라 7 이다** — `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh:91`
   이 비-주석 줄에서 실제로 `codex exec -` 를 부른다. ㉮ 는 `plugins/*/scripts/*.py` 로 스코프됐는데
   ㉯ 만 무스코프였던 비대칭이 원인이다. → **㉯ 를 `plugins/*/scripts/*.sh` 로 스코프**해 대칭을
   맞춘다. 그러면 `tests/spike/` 는 자연히 빠진다.
2. **양성 대조가 이미 해결된 문제를 지목했다** — `detect_codex.sh`·`runner_common.sh` 는
   `codex exec` 를 **주석에만** 갖고 있어 비-주석 필터 하나로 배제된다. → 양성 대조를
   **「테스트·mock·spike 가 안 나온다」**로 다시 쓴다.
3. **`runner_common.sh 로드` 항은 순수한 오탐 표면이다** — 리포가 그 술어를 이미 재고 기각했고
   (`plugins/quality-gates/tests/test_codex_extractor_positive_marker.sh:91-96`), 첫 항이 이미 잡는
   셋만 다시 잡는다. → **삭제.** 집합이 안 변한다.

그리고 이 도출은 **리포에 이미 두 벌 있다** — `tests/lib/extract_codex_invocations.py`(정규식
`(^|\s)codex\s+exec\s` + 비-주석 필터)와 `tests/lib/codex_observation.sh` 의 `codex_candidates()`,
그리고 둘이 매 실행마다 서로를 대조하는 standing assertion. **세 번째를 만들면 이 문서가 경계하는
「판정자 추가」를 스스로 저지른다.** L4 는 `extract_codex_invocations.py` 를 호출하고, 필요하면 그
파일을 `shared/` 로 승격한다(치환이지 추가가 아니다).

**선례** — `shared/tests/adopter_derivation.sh:36` 의 `derive_reference_adopters` 가 같은 모양
(채택자를 열거하지 않고 포인터에서 도출)을 쓴다. ㉰ 의 확장이 이 축을 재사용한다.

## 3. 작업 T1 — 배선

| # | 자리 | 부를 것 | 비고 |
|---|---|---|---|
| T1-1 | `synthesize_findings.py:309` | `reject(finding_id(f), why)` | 계산기가 이미 인자로 들어와 있다 |
| T1-2 | `synthesize_artifact_findings.py:202` | `reject(...)` | 같은 모양 |
| T1-3 | `synthesize_findings.py:336-342` (dedup) | `absorbed(item, into)` | `dedup(findings)` 가 계산기를 안 받는다 — 인자 추가 (`:554` 호출부) |
| T1-4 | `_normalize_identity` **확장** (`:149`, 호출 `:253`·`:298`) | `coerced(field, frm, to)` | 아래 |
| T1-5 | `synthesize_findings.py:361-362` (suppress) | **새 메서드 `suppressed(item, why)`** | D4 |
| T1-6 | `synthesize_artifact_findings.py:100-155` | `source_failed(...)` | 자체 int 카운터를 계산기로 교체 |

**T1-4 — 신설이 아니라 확장이다** (round 1 리뷰가 고친 것). `_norm_sev`(`:386-412`)는 dedup(`:334`) ·
suppress(`:359`) · 정렬(`:370`) · 표시(`:471`) **네 곳**에서 불리므로 그 안에 계산기를 넣으면 같은
항목이 네 번 세어진다. 그런데 **「입력 직후 정규화 패스」는 이미 존재한다** — `_normalize_identity`
(`:149`)가 그것이다. 앞 판본은 이것을 "신규"라 적어 plan-writer 에게 확장인지 병렬 신설인지 추측을
남겼다. **`_normalize_identity` 를 확장해** severity 를 그 자리에서 정규화·기록하고 항목에 써 둔다.
`_norm_sev` 는 그 뒤 정상 값을 만나 그대로 반환하며 네 호출부는 손대지 않는다.

**T1-5 — 어휘를 여덟 개로 늘린다.** `suppress()` 는 리뷰어의 판단이 아니라 규칙
(`sev != CRITICAL and conf <= 4`)으로 버린다. 「사람이 보고 버림」과 「규칙이 걸러냄」을 한 칸에
넣으면 D2 가 없애려던 실명이 재발한다. `report()["counts"]["suppressed"]` 로 낸다.

### 3.1 철회한 것 둘 (round 1 리뷰)

**앞 판본의 A7(`surfaced()` 배선) — 철회.** `adjudication.py:136-138` 이
`if self.items == "closed": return []` 다. 배선하려던 `synthesize_artifact_findings.py` 가 정확히
`items="closed"`(`:195`)이므로 **빈 리스트가 나온다** — 아무것도 안 보인다. 제외한 것을 보이려면
`items` 를 바꿔야 하는데 그것은 그 합성기의 fail-closed 방향(미판정 항목을 kept 에서 제외)을
뒤집는 별개의 행동 변경이다. 이번 범위 밖으로 두고 **§13 에 이월**한다. 대신 제외 사실은
`report()["counts"]["held"]` 로 이미 보이며 T3 가 그것을 「미판정」 칸에 싣는다.

**앞 판본의 A8(`hold` → `source_failed(primary=False)`) — 철회.** `adjudication.py:96-98` 이
`bool(self._held) or bool(self._unknown) or self._has_primary_source_failure()` 다. 옮기면 **첫 항이
사라져 `blocks()` 가 True→False 로 꺼진다** — 앞 판본은 정반대로 적었다. 축도 틀렸다:
`hold` vs `source_failed` 의 축은 「항목 소실 vs 입력 사망」이지 「항목 단위 vs 소스 전체」가 아니다.
모듈 docstring `:8`, `merge_brief_review.py:178` 주석, 그리고 **CLAUDE.md 의 차단 술어**
(*"막는 것은 항목이 소실됐거나 …"*)가 전부 그 축을 쓴다. `blocks()` 자신의 docstring 도
*"화석이 아니라 계약이다"* 라고 적는다.

**대신 T3 가 렌더 층에서 가른다** — `hold` 는 그대로 두고, `reasons()` 가 이미 싣는 사유
문자열로 「판정자 부재」와 「항목 파손」을 **표시상** 나눈다. 원장 술어도 `blocks()` 도 안 바뀌고
D2 의 두 칸 분리는 달성된다.

## 4. 작업 T2 — 락 넷 L1–L4

전부 **오늘 RED 여야 한다.** RED 가 아니면 락이 아무것도 안 재고 있다는 뜻이므로 각 락의 첫 실행
결과를 착수 기록에 남긴다.

| 락 | 대상 | 요구 | 오늘 예상 |
|---|---|---|---|
| **L1 배선** | ㉮ 4파일 | findings 원소를 버리는 분기 앞에 계산기 호출이 있어야 한다 | **RED** — `synthesize_findings.py:309` · `synthesize_artifact_findings.py:202` |
| **L2 소비** | 계산기 출력 | `report()` 의 카운트가 **전부**(`accepted` 포함) 프로덕션 출력에 실려야 한다 | **RED** — 6 중 5 미소비 |
| **L3 입력 선언** | ㉰ 20 에이전트 | (a) 정의가 슬롯을 기계 판독 형태로 선언하고 dispatch 가 정확히 그것을 준다 · (b) 선언된 슬롯에 **금지된 종류**가 없다 | **RED** — 오늘 2/20 |
| **L4 역할 선언** | ㉯ 6 러너 | 처분 선언(`consumer=` · `fail-*` · `disclosure=`)을 갖고, **판정 결과가 원장에 도달하는 인터페이스**를 갖는다 | **RED** — 6/6 없음 |

### 4.1 L1 「버리는 분기」의 판정 규칙

`ast.parse` 로 다음을 판정한다. **컬렉션 이름을 열거하지 않는다**(§11 이 금지) — 대신 **함수
시그니처의 findings 인자에서 도출**한다:

1. 대상 함수 = 계산기(`ledger`/`L`) 를 인자로 받거나 모듈 수준에서 접근하는 함수.
2. 그 함수 안의 `for` 중, **순회 대상이 그 함수의 인자이거나 인자에서 파생된 이름**인 루프.
3. 그 루프 본문의 각 종료 경로(`continue` · `break` · `return` · 본문 끝까지 append 없음)에 대해,
   같은 분기 안에 `ledger.<메서드>(...)` 호출이 있어야 한다.
4. 리스트 컴프리헨션의 `if` 필터는 계산기를 부를 수 없으므로 **명시적 루프로 풀거나** 필터 전후
   길이 차를 세는 호출을 붙인다.

**미해결로 남는 것** — 헬퍼로 분리된 버리기(`suppress()` 처럼 계산기를 안 받는 순수 함수)는 2번
조건에 안 걸린다. 그래서 T1-3·T1-5 가 그 함수들에 계산기 인자를 **먼저** 넣는다(락이 그것을
전제한다). 그 전제 자체는 락이 못 검사한다 — §13 이월.

### 4.2 L3 는 프레이밍 축을 절반만 흡수한다 (round 1 리뷰가 고친 것)

앞 판본은 *"L3 가 프레이밍 축을 흡수한다"* 고 적었다. **틀렸다.** L3(a)의 술어는 **선언과 전달의
일치**일 뿐 *무엇을 선언해도 되는가*의 어휘가 없다. 저자가 정의에
`<history>${HISTORY}</history>` 한 줄을 넣고 dispatch 가 그것을 주면 **누출이 그대로인 채 GREEN**
이 된다 — §11 이 기각한 「안 적으면 대상 아님」이 「적으면 통과」로 뒤집혀 재발한다.

그래서 **L3(b) — 내용 술어**를 둘로 나눠 명시한다. 각 슬롯은 `kind:` 를 갖고, 금지 종류는
brief C8 의 세 범주다: `prior_verdict`(선행 판정·findings) · `score`(점수·심각도) ·
`orchestrator_framing`(오케스트레이터가 쓴 해석·요약).

**판정기는 신설하지 않는다** — `plugins/plugin-audit/scripts/check-no-verdict-injection.py` 가
이미 주입 표면 7개를 판정 어휘로 스캔한다. 그것을 `shared/` 로 승격해 ㉰ 전체에 건다(치환).
그 파일의 헤더가 자기 한계를 적는다: *"grep cannot catch a novel form of verdict injection."*
그 한계는 그대로 상속된다 — §13 에 명시한다.

**예외의 자리** — adversarial · refuter 계열 6곳은 앞 판정을 반박하는 것이 과업이다. 이들은
`kind: prior_verdict` 를 **선언하고 L3(b)의 면제 목록에 등재**한다. 면제는 저자가 아니라
**락의 상수**에 산다 — 저자 손에 두면 선언이 정당화를 대신하는 그 실패로 되돌아간다.

### 4.3 공수 재추정 (round 1 리뷰가 고친 것)

앞 판본은 *"`test_seed_agents.sh:197` 그 한 줄을 도출로 바꾸면 20으로 늘어난다"* 고 적었다.
**틀렸다.** `:197` 은 개수 단언이고 하드코딩은 **`:123` 의 `for a in seed-critic seed-readback`**
이다. 그리고 일반화하려면 셋이 더 따라온다:

| 무엇 | 오늘 |
|---|---|
| `extract_dispatch_windows`(`:101`) | `"spec-distill:$1"` 접두사와 ```` ```javascript ```` 펜스를 못 박음 |
| `# guards:`(`:2`) | SKILL 파일 하나 |
| 20 에이전트 중 18 | `<태그>${변수}` 선언이 없다(산문) — `spec-reviewer.md:7-19` 가 그 예 |

즉 **5개 플러그인의 dispatch 표기**(plugin-audit 은 Workflow `agent()`)와 **18개 description 의
슬롯 규약 신설**이 L3 의 실제 공수다. 이것이 이 문서에서 가장 큰 단일 작업 항목이다.

### 4.4 동시에 편집해야 하는 기존 락

1.3 의 ⓐⓑ 를 계산기로 흡수하는 순간 아래가 설계상 RED 가 된다. 같은 PR 에서 함께 고친다.

| 락 | 무엇이 깨지나 |
|---|---|
| `plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh` | 생산자 문구와 소비자 SKILL 분기의 **문자열 동일성** — 출력 문면이 바뀌면 RED |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh:86-241` | `degraded_reason` **닫힌 어휘 4값** |
| `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` | `dropped` 계수가 컨테이너 + 항목 두 수준 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md:116` | merge_review 출력 키를 **열거**한다 — L2 가 카운트를 실으면 이 계약이 깨진다 |

`test_skill_drop_notice_consumed.sh` 는 리포에서 **생산자–소비자 seam 을 재는 유일한 락**이다.
약화시키지 않는다 — 새 문면에 맞춰 갱신한다.

(A8 철회로 `test_merge_review_adjudication.py`·`test_merge_brief_adjudication.py` 는 이 목록에서
빠졌다 — `hold` 술어를 안 건드리므로.)

### 4.5 PR 분할

| PR | 내용 | 머지 조건 |
|---|---|---|
| **PR1** | T4-1 (stale 이름 제거) | 통상 GREEN |
| **PR2** | L1·L2·L3·L4 + T4-2 신설 — **전부 RED 인 채** | **브랜치 안에서만 머지**하고 `main` 으로 보내지 않는다. 첫 실행 로그(전부 RED)를 커밋 메시지에 싣는다 |
| **PR3** | T1(배선) + T3(출력) + T5(훅) + §4.4 의 기존 락 넷 갱신 | PR2 의 락이 전부 GREEN |
| **PR4** | L3 의 18 에이전트 슬롯 규약 + 5 플러그인 dispatch 표기 (§4.3) | L3 GREEN |

**PR2 의 RED 를 `main` 에 보내지 않는 이유** — 앞 판본은 "의도적으로 RED 인 채 머지"라고만 적어
메커니즘이 없었다. 대신 **브랜치 내 머지**로 한다: 락이 RED 인 커밋이 브랜치 히스토리에 남아
M1 의 증거가 되고, `main` 에는 PR3·PR4 이후 GREEN 상태만 간다. 면제 목록도 게이트 우회도 쓰지
않는다.

T4-2(역방향 락)를 PR1 이 아니라 PR2 로 보내는 이유도 같다 — PR1 이 stale 이름을 지운 뒤 같은 PR 에
락을 넣으면 그 락은 도착 즉시 GREEN 이라 이빨을 증명하지 못한다.

## 5. 작업 T3 — 출력 모양

계산기의 `blocks()`(`adjudication.py:89-98`)가 차단 판정을 이미 계산한다. 외부 호출자가 0이라
표면만 죽어 있다. L2 가 되살린다.

```
**Findings:** 0 CRITICAL / 3 IMPORTANT / 5 SUGGESTION
**처분:** 수용 8 · 기각 7 · 억제 2 · 흡수 4 · 미판정 1     ← 상태별, 차단 아님
**배관 손실:** 3 (차단 아님)                                ← 합계. 차단은 blocks() 가 정한다
```

| 칸 | 들어가는 것 | 차단 |
|---|---|---|
| **처분** | `accepted` · `rejected` · `suppressed` · `absorbed` · `held`(사유가 「판정자 부재」인 것) | 아니오 |
| **배관 손실** | `sources_failed` · `uncountable` · `coerced` · `held`(사유가 「항목 파손」인 것) | `blocks()` 가 정한다 |

**`held` 가 두 칸에 걸치는 이유** — §3.1 이 A8 을 철회했으므로 원장 술어는 하나(`hold`)로 남고,
가르는 것은 **`reasons()` 가 이미 싣는 사유 문자열**이다. 렌더 층의 분류라 `blocks()` 도 기존 락도
안 바뀐다. 사유 접두는 T1 이 호출부에서 통일한다(예: `"판정자 부재: …"` / `"항목 파손: …"`).

**칸의 합계와 차단은 같은 집합이 아니다.** `blocks()` 는 소실·셀 수 없음·주(主) 입력 사망에
걸리고, 보조 소스 실패와 게이트를 안 바꾸는 강제는 공시만 한다. 그 사실을 칸 옆에
`(차단 아님)`/`(차단)` 으로 **명시**한다 — 숫자만 내면 「3인데 왜 안 막았나」가 추측이 된다.

**`accepted` 도 낸다** (round 1 리뷰가 지적). L2 가 *"전부 실린다"* 를 요구하므로 예외를 두면
락이 자기 술어를 어긴다. 첫 줄의 severity 합계는 dedup·suppress **이후**의 표시 수이므로
`accepted` 와 다른 값이다 — 두 줄을 함께 낸다.

## 6. 작업 T4 — stale 이름과 역방향 락

`plugins/quality-gates/skills/quality-pipeline/SKILL.md:511` 이 `quality-gates:synthesizer` 를
dispatch 하라고 지시한다. **그 에이전트는 없다.**
`37ea0d7 refactor(quality-gates): synthesizer agent → script (T3-2, v1.28.0)` 이 정의를 지우고
`synthesize_findings.py` 로 옮겼다. 괄호 안 `(or local synthesize_findings.py)` 가 유일하게 맞는
경로다.

| # | 내용 | PR |
|---|---|---|
| **T4-1** | `SKILL.md:511` 에서 stale 이름 제거, 스크립트 호출로 정리 | PR1 |
| **T4-2** | 락 ㉰ 에 **역방향** 추가 — *"dispatch 되는 이름은 전부 `plugins/*/agents/*.md` 에 정의가 있어야 한다"* | PR2 |

`shared/tests/test_dispatch_disposition.sh:294` 는 *"정의된 에이전트는 전부 최소 한 번 dispatch
돼야 한다"*(죽은 정의 탐지)만 본다. 반대 방향이 비어 있었고 정확히 그 방향으로 stale 이 흘렀다.
양방향 대조는 리포에 이미 있는 패턴이다 — `test_guards_coverage_bidirectional.sh`.

**미확인** — 이름이 resolve 되지 않을 때의 동작. `smoke-workflow.js:20-22` 가 *"resolve 되지 않으면
쓰기 권한이 있는 기본 에이전트가 대신 돈다"* 라고 적지만 그것은 **Workflow 층의 `agent()`** 에
대한 기록이고 skill 의 `Agent(...)` 도 같은지는 확인되지 않았다. 이 설계는 **어느 쪽도 전제하지
않는다** — T4-1·T4-2 는 두 경우 모두에서 옳다.

## 7. 작업 T5 — 훅 층 회계

**앞 판본은 이 층을 제외했고 근거가 틀렸다** (round 1 리뷰). 인용한
`plugins/agent-transparency/tests/test_plugin_contract.py:920,936-937`(`TestNoHooksRemain`)이
금지하는 것은 **agent-transparency 자기 플러그인의** 훅이다(`PLUGIN_DIR / "hooks"`, 자기
`plugin.json`). 이 사이클의 대상인 **`plugins/spec-distill/hooks/review-dispatch.py` 는 실재한다.**

그리고 **C13 은 confirmed 제약**이고 *"Phase 0 이 이 세션에 배정한 훅 차단 결정 2곳을 더한다"* 로
포함을 명시하며, C16 이 소유를 이 세션에 못 박는다. 저자가 지울 수 없다. **범위에 넣는다.**

| # | 자리 | 내용 |
|---|---|---|
| T5-1 | `review-dispatch.py:599` (`decision:"block"` — 스코프 문서 구조 검증 실패) | 차단이 일어난 사실과 사유를 원장 어휘로 기록 |
| T5-2 | `review-dispatch.py:752` (`decision:"block"` — 다음 턴 dispatch 강제) | 같음 |

**아무것도 되돌려 보내지 않는다.** brief OQ26 이 실측을 인용한다 — `SubagentStop` 훅이
`additionalContext` 를 내면 그 subagent 가 종료하지 않고 계속 돌고(에이전트 하나에 3회 발화),
같은 문서의 대안 표가 그 방향을 devbrew 금지 패턴(unbounded autonomy)으로 **분류**한다.
회계는 **기록만** 한다. 그러면 그 실측이 발동하지 않는다.

**도달 가능성** — 훅은 spec-distill 의 `.py` 이고 계산기 심볼릭 링크가
`plugins/spec-distill/scripts/adjudication.py` 에 있으므로 import 경로가 있다. 착수 시
P5 로 확인한다.

**OQ23 파급** — 형제 세션이 `:752` 의 목적지 리터럴을 데이터로 빼내면 **무엇이 강제되는지가
변수**가 된다. T5-2 의 기록은 그 값을 **문자열 리터럴로 키잉하지 않고** 훅이 실제로 쓴 값을
그대로 싣는다.

## 8. 제외 범위와 근거

| 제외 | 근거 | 열린 질문 |
|---|---|---|
| **codex 스키마 둘의 통일** | 합치면 각각 hard crash 와 false-clean. `shared/codex/runner_common.sh:11-35` 가 코드 주석으로 명시 → **C6 분기 ⑵** | OQ18 (닫힘) |
| **`audit-workflow.js` 의 `degradedEvents`(1.3 ⓒ)** | **C6 분기 ⑵** — JS 는 개념의 대응물을 이미 갖췄고(미검증 표시→degrade 이벤트→결손 절→결정론 검증기), 없는 것은 개념이 아니라 심볼릭 링크다. 언어/배포 사유이지 원리적 부재가 아니다. **결과: 판정자가 둘로 남는다** — §13 이월 | OQ22 |
| **자동 실행자 신설** (D6) | 사용자가 이 단계에서 범위 밖으로 선택. **결과** — 락 넷은 `/qg` 가 그 파일을 고르거나 사람이 손으로 돌릴 때만 발화한다. `.github/`·Makefile 이 없고 훅에서 `shared/tests` 호출이 0건이다 | §13 |
| **cross-family 를 계약이 요구하기** | L4 는 러너에 처분 선언을 요구하는 데까지다. C14 가 별도 축으로 확정 | OQ16 (열린 채) |
| **`surfaced()` 배선** (§3.1) | `items="closed"` 에서 빈 리스트를 반환하므로, 배선하려면 그 합성기의 fail-closed 방향을 뒤집어야 한다 — 별개의 행동 변경 | §13 |
| **산문 지시 2자리** | `quality-pipeline/SKILL.md:488`(Tier C)은 프롬프트 리터럴이 파일에 없어 무엇이 실리는지 **셀 수 없다**. 침묵을 clean 으로 읽지 않고 이월 | OQ10 |

## 9. 착수 전 선결 조건

| # | 확인할 것 | 왜 |
|---|---|---|
| P1 | `plugins/spec-distill/scripts/check_seed.py` + `tests/test_seed_one_sentence.sh` 가 L3 와 충돌하는가 | 그 락은 *"seed 본문에 슬롯 존재 검사를 추가하지 마라"* 를 강제한다. L3 는 **에이전트 정의와 dispatch 프롬프트**를 보므로 대상이 다를 가능성이 높지만 원문 미확인. **충돌해도 L3 를 빼지 않는다** — 그 자리만 C6 분기 ⑵ 로 면제하고 나머지 19 에이전트는 그대로 간다 |
| P2 | `extract_codex_invocations.py` 를 실행해 ㉯ 를 뽑는다 | 6이 나오고 `tests/spike/`·`detect_codex.sh`·`runner_common.sh` 가 안 나와야 한다 (§2.1) |
| P3 | 락 넷의 첫 실행이 **전부 RED 인가** | GREEN 이면 그 락은 아무것도 안 재고 있다 |
| P4 | **기존 락 전량 baseline 캡처** — 선재 RED 목록 포함 | M8 의 기준점. 리포에 CI 가 없고 선재 RED 가 있다는 기록이 있으므로, 한 개만 잡으면 「신규 RED 0」이 판정 불가다 |
| P5 | 훅에서 `adjudication` import 경로가 실제로 도달하는가 | T5 의 전제 |

## 10. 위험

- **대리지표 치환** — 세어지기 시작하면 판정자가 자기 기각을 다른 범주로 재분류하는 것이 지표를
  낮추는 최단 경로가 된다. §5 의 쪼개기가 구조적 답이다(차단이 안 움직이므로 유인이 없다).
- **락을 만들어도 아무도 안 돌린다** — D6 이 자동 실행자를 제외했다. 다음 사이클 1순위.
- **L3(b)의 grep 한계** — 승격하는 판정기가 스스로 적는다: *"grep cannot catch a novel form of
  verdict injection."* 새 형태의 주입은 못 잡는다.
- **면제 목록이 자라난다** — L3(b)의 `prior_verdict` 면제가 오늘 6곳이다. 늘어나는 것을 세는
  장치가 없으면 면제가 규칙을 삼킨다. 면제 항목 수를 M6 이 고정값으로 잡는다.
- **`_normalize_identity` 확장의 폭발 반경** — 그 함수는 `:253`·`:298` 두 곳에서 불리고
  형제 `_norm_sev` 의 주석이 과거 사고(비-해시가능 값이 `TypeError` 로 파이프라인 전체를 죽임)를
  기록한다.
- **§4.4 기존 락 넷의 회귀** — 특히 `test_skill_drop_notice_consumed.sh` 는 생산자–소비자 seam 을
  재는 유일한 락이다. 문면을 맞추느라 이빨을 지우면 이번 작업이 자기가 고치려던 실패를 신설한다.
- **정적 검사의 절대 경계** — 에이전트 이름을 문자열 연결로 쪼개면 이 리포의 dispatch 락도 새 락도
  **완전히 침묵한다**(실측 기록 있음). 새 락도 정적인 한 이 경계를 넘지 못한다.

## 11. 기각한 대안

- **기각 — 배선만 하고 락을 안 만든다.** 오늘 세게 만들지만 내일 다시 안 세어지는 것을 막지
  못한다. 증거가 있다 — 계산기는 이미 있었는데 1.3 의 평행 어휘 셋이 그 밖에서 자랐다.
- **기각 — 러너·합성기에 새 표식(`# **판정** —` 등)을 요구한다.** 「안 적으면 대상 아님」이 되어
  `plugins/spec-distill/CHANGELOG.md:2347` 의 실제 사건을 재발명한다.
- **기각 — ㉯ 용 도출기를 새로 만든다.** 리포에 이미 두 벌 있고 둘이 서로를 대조한다. 세 번째는
  이 문서가 경계하는 「판정자 추가」다 (§2.1).
- **기각 — L3(a) 만으로 프레이밍 축을 덮는다.** 선언이 정당화를 대신해 「적으면 통과」가 된다
  (§4.2).
- **기각 — `hold` 를 `source_failed` 로 옮긴다(앞 판본 A8).** `blocks()` 가 꺼지고 CLAUDE.md 의
  차단 술어와 충돌한다 (§3.1).
- **기각 — `surfaced()` 를 아티팩트 합성기에 배선한다(앞 판본 A7).** `items="closed"` 에서 빈
  리스트를 반환한다 (§3.1).
- **기각 — 락 코퍼스의 글롭·확장자만 넓힌다.** dispatch 정규식이 `.py`/`.sh` 에서 아무것도 못
  찾으므로 아무 축도 안 움직인다.
- **기각 — presence 락의 코퍼스를 공유 계약 파일까지 넓힌다.** 그 파일이 대신 만족시켜 대상
  파일이 문구를 잃어도 통과한다. **absence 는 넓히고 presence 는 넓히지 않는다** —
  `shared/tests/presence_corpus.sh:10-20` 이 정본이고 `:32-40` 의
  `assert_presence_corpus_skill_owned` 가 헬퍼다.
- **기각 — 규칙 억제를 `reject` 에 합친다.** D2 가 없애려던 실명이 그 안에서 재발한다.

## 12. 완료 측정

| # | 재는 법 | 통과 조건 |
|---|---|---|
| M1 | PR2 직후 L1–L4 실행 | **전부 RED**. GREEN 인 락은 **왜 GREEN 인지**를 기록한다 — 「이미 만족된 성질을 보호하는 락」과 「아무것도 안 재는 락」은 다르며, 전자면 그 성질을 깨는 변이가 RED 를 내는지로 갈린다(M3) |
| M2a | T1 후 L1·L2 실행 | GREEN |
| M2b | T5 후 L4 실행 | GREEN |
| M2c | PR4 후 L3 실행 | GREEN |
| M3 | 각 락에 변이 — 배선 한 줄 삭제 · 슬롯 선언 삭제 · 앵커 삭제 · 정의 삭제 | 그 락이 RED. **여러 락이 함께 RED 여도 실패가 아니다**(겹치는 보호는 정상) — 실패는 **아무 락도 RED 가 아닌 것**이다. 변이 전에 커밋한다(`git checkout --` 는 HEAD 로 되돌린다) |
| M4 | 결정론 fixture 로 처분 행렬 검증 — 기각·억제·흡수·미판정·배관 손실 각 1건 이상을 담은 입력을 `synthesize_findings.py` 에 직접 먹인다 | §5 의 세 줄이 기대값과 일치. **라이브 `/qg` 라운드에 의존하지 않는다**(D6 이 실행자를 제외했으므로) |
| M5 | 라이브 `/qg` 를 실제 변경에 한 번 돌린다 | 세 줄이 실제로 렌더된다. 숫자가 0이어도 통과 — 값 확보는 M4 의 몫 |
| M6 | L3(b) 면제 목록 크기 | **6** (adversarial·refuter 계열). 늘었으면 왜 늘었는지가 커밋에 있어야 한다 |
| M7 | ㉮㉯㉰ 도출 실행 | 4 / 6 / 20. ㉯ 에 `tests/spike/`·`detect_codex.sh`·`runner_common.sh` 가 없다 |
| M8 | 기존 락 전량 실행 (§4.4 넷 포함) | **P4 의 baseline 대비** 신규 RED 0. 선재 RED 는 baseline 목록에 이름과 이유가 함께 있어야 한다 |

## 13. 재결정 기록 · Known gaps

### 재결정 기록 (P23 — 원래 / 재결정 / 근거)

| 항목 | 원래(round 0) | 이 판본 | 근거 |
|---|---|---|---|
| 훅 층 회계 | 제외 (`TestNoHooksRemain` 인용) | **포함**(T5) | 그 락은 agent-transparency 자기 훅만 금지하고 대상인 spec-distill 훅은 실재한다. C13 은 confirmed 이고 포함을 명시한다 |
| 역할 구조 축 | 작업 항목 없음 | **L4 + T4-2 + T5 로 명시** | C5 가 confirmed 로 셋 다를 요구하고, C6 은 분기에 두 조건 중 하나를 요구한다. 침묵은 둘 중 어느 것도 아니다 |
| `surfaced()` | 배선 | **이월** | `items="closed"` 에서 빈 리스트 |
| `hold` 재배치 | `source_failed(primary=False)` | **철회** | `blocks()` 가 꺼진다 |
| ⓒ 의 분기 조건 | C6 ⑴ | **C6 ⑵** | JS 는 개념의 대응물을 갖췄다 |

**사용자 판정이 필요한 것** — 위 다섯 중 첫 둘은 **범위를 늘린다**(T5 신설 + §4.3 의 18 에이전트
작업). 확정 제약을 지킨 결과이지만 공수가 커졌으므로 Phase 5 게이트에서 사용자가 판정한다.
줄이려면 C5·C13 중 무엇을 이번 범위에서 뺄지를 사용자가 정해야 한다 — 저자는 못 뺀다.

### Known gaps — 이월

- **판정자가 둘로 남는다** — ⓐⓑ 를 흡수해도 `degradedEvents`(JS)가 남아 OQ22 의 drift 쌍 조건이
  성립한다. 다음 사이클이 이 사실을 알고 시작해야 한다.
- **자동 실행자 부재** (D6) — 락이 늘어날수록 「만들었는데 안 돈다」의 비용이 커진다.
- **헬퍼로 분리된 버리기를 L1 이 못 본다** (§4.1) — T1 이 계산기 인자를 먼저 넣는 것을 전제하는데,
  그 전제 자체는 락이 검사하지 않는다.
- **`surfaced()` 와 `items` 인자가 여전히 죽어 있다** — 살리려면 아티팩트 합성기의 fail-closed
  방향을 뒤집어야 한다.
- **L3(b)의 grep 한계** — 새 형태의 주입은 못 잡는다.
- **`disclosure=` 채널이 실제로 읽히는지** — 정적 검사 밖. 그 seam 을 재는 락은 리포 전체에
  `test_skill_drop_notice_consumed.sh` 하나뿐이다.
- **축 A⑤ 의 이름과 이빨** — 코드는 7축, 문서(`CLAUDE.md:58`·CHANGELOG 4개·감사문서)는 6축.
  A⑤ 는 mutation 검증 0건.
- **`# guards:` 선언의 하한** — `test_guards_coverage_bidirectional.sh` 의 방향 B 가 글롭당
  `n > 0` 이라 `guards: plugins/**` 가 737 중 22 만 훑고도 통과한다.
- **OQ16**(다른 모델 계열의 처분) · **OQ5**(착수 자료 감사 문서의 처분) · **OQ10**(비판자 아닌 두
  자리) · **OQ21**(S1 이 이관한 유보) — 이 설계가 답하지 않았다.
- **round 1 리뷰의 미해소 지적 셋** — 전부 이 문서가 요구만 세우고 형태는 `writing-plans` 가 정한다.
  1. codex block: *"L4 는 러너 선언만 검사하고 판정 결과가 원장에 도달하는 런타임 인터페이스를
     정의하지 않는다."* §4 의 L4 요구에 그 조항을 넣었으나 **인터페이스의 구체적 형태는 미정**이다.
  2. codex block: *"L3 의 슬롯 선언 문법과 매칭 규칙(선택적 슬롯 · 같은 에이전트를 여러 번 부르는
     dispatch · 템플릿 · 별칭)이 정의되지 않아 재현 가능하게 구현할 수 없다."* 이 판본은 `kind:`
     축만 세웠고 **문법 자체는 정하지 않았다.** §4.3 의 「18개 description 슬롯 규약 신설」이 그
     작업이며, 위 네 경우의 규칙이 그 안에 포함돼야 한다.
  3. Claude/codex 공통: **L1 의 AST 술어가 헬퍼로 분리된 버리기를 못 본다**(§4.1 이 그 전제를
     명시했으나 락이 전제 자체는 검사하지 않는다).
- **brief 의 방향성 지적 13건이 열린 채다** — 축 교체가 단독 저자 preprint 하나에 기대고, brief 가
  [취함]으로 실은 논문 둘은 모든 비판자에게 같은 전체 맥락을 준다. 이 설계는 그 축을 L3 로 좁게
  흡수해 축 자체의 참·거짓에 덜 의존하게 만들었지만, 지적을 해소한 것은 아니다.
