# 판정 지형 — 회계 배선과 도출 락 · Design

> 판정을 버릴 때 이름을 부르게 하고, 그 이름을 부르는지 구조에서 도출해 검사한다.

## Handoff Context

- **입력** — `docs/superpowers/interview/2026-09-02-adjudication-topology-interview.md`
  (확정 17 · 잠정 2 · 열린 질문 26). 텔레메트리는 같은 이름의 `.audit.md`.
- **이 문서가 정하는 것** — brief 가 미확정으로 남긴 OQ1(통일 계약의 구체적 형태).
- **다음** — `superpowers:writing-plans`. 이 문서가 형태를 정하지 않은 것은 §14.
- **이 판본이 서 있는 측정** — §A. **측정하지 않은 것을 주장하지 않는다**; 주장의 범위가
  측정의 범위보다 넓으면 그 사실을 그 자리에 적는다.

### 이름 규약

**T1–T5** 작업 · **L1–L4** 락 · **㉮㉯㉰** 도출된 집합 · **D1–D6** 사용자 결정 ·
**F1–F4** 이 사이클이 실행한 측정 · **U1–U4** `writing-plans` 가 정할 미결.

## 목차

- [A. 측정 넷](#a-측정-넷)
- [0. 한눈에](#0-한눈에)
- [1. 문제](#1-문제)
- [2. 도출 규칙](#2-도출-규칙)
- [3. 작업 T1 — 배선](#3-작업-t1--배선)
- [4. 작업 T2 — 락 넷](#4-작업-t2--락-넷)
- [5. 작업 T3 — 출력 모양](#5-작업-t3--출력-모양)
- [6. 작업 T4 — stale 이름과 역방향 스캔](#6-작업-t4--stale-이름과-역방향-스캔)
- [7. 작업 T5 — 훅 층 회계](#7-작업-t5--훅-층-회계)
- [8. 제외 범위 — 각 행이 C6 조건을 인용한다](#8-제외-범위--각-행이-c6-조건을-인용한다)
- [9. 착수 전 선결 조건](#9-착수-전-선결-조건)
- [10. 위험](#10-위험)
- [11. 기각한 대안](#11-기각한-대안)
- [12. 완료 측정](#12-완료-측정)
- [13. 재결정 기록](#13-재결정-기록)
- [14. writing-plans 가 정할 미결](#14-writing-plans-가-정할-미결)

## A. 측정 넷

### F1 — ㉯ 도출기의 실제 출력 (실행함)

`python3 plugins/quality-gates/tests/lib/extract_codex_invocations.py <repo>/plugins` → **7개**:
러너 6개 + `quality-gates/tests/spike/test_codex_json_extraction.sh`.
`/scripts/` 후처리 필터를 걸면 **6**.

그 도구는 심볼릭 링크를 건너뛰고 주석-전용 파일을 거른다. **CLI 는 `<root_dir>` 하나뿐이고
스코프 인자가 없다** — `collect()` 가 확장자 필터를 의도적으로 제거했다고 17줄로 적으며 출력이
`test_sandbox_enforced.sh:51-62` 의 standing assertion 에 묶여 있다. **그 파일을 고치지 않는다.**

### F2 — L1 후보 규칙 둘의 비교 (실행함 · 프로브 커밋됨)

프로브: `docs/superpowers/specs/probe-l1-rule-comparison.py`.

| 파일 | 규칙 A(*ledger 를 인자로 받는 함수*) | 규칙 B(*처분 메서드가 불리는 함수*) |
|---|---|---|
| `synthesize_findings.py` | `:295` · `:310` | 동일 |
| `synthesize_artifact_findings.py` | **함수 0개 — 아무것도 못 봄** | `:203` · `:216` · `:221` |
| `merge_review.py` / `merge_brief_review.py` | 0 | 0 |

**측정 범위 — 주장보다 좁다.** 프로브는 `ast.Continue` **하나만** 본다. §4.1 이 정의한 네 버리기
형태 중 `break` · 이른 `return` · 「본문 끝까지 append 없음」 **셋은 측정되지 않았다.** 그리고
분기를 못 찾으면 `scope` 가 루프 본문 전체로 넓어져 루프 최상위의 맨 `continue` 를 guarded 로
읽는다 — **fail-open 방향이다.** 즉 위 다섯 자리는 **하한**이지 전수가 아니다.

**규칙 A 를 버리는 근거는 이 좁은 측정으로도 충분하다** — 4파일 전부 `Ledger` 를 로컬로 만들어
규칙 A 는 파일 하나에서 함수를 0개 고른다. **그러나 규칙 B 도 채택하지 않는다**(§4.1).

**F2 가 새로 찾은 두 자리** — `synthesize_artifact_findings.py:216`(형태 불량 신규 finding 을
안 세고 버림) · `:221`(dedup 흡수를 안 셈).

### F3 — 훅이 실제로 내는 키 (읽음)

`review-dispatch.py:598-602` 와 `:751-755` 는 **세 키**를 낸다 — `decision` · `reason` ·
`systemMessage`. 영속 채널은 `write_state_file()`(`:198-204`).

**그리고 세 채널의 모델 도달은 이 설계의 입력 문서가 이미 실측했다** —
`2026-09-02-adjudication-topology-interview.md:515-520`:

> 훅의 `systemMessage` 필드는 모델 컨텍스트에 도달하지 않는다(카나리 14개 중 0개 도달).
> 같은 실행에서 `additionalContext` 는 8/8, 차단 결정에 딸린 `reason` 은 7/7 도달했다.

**그러므로 T5 의 공시 채널은 `reason` 이다** — `systemMessage` 가 아니고 `additionalContext` 도
아니다(후자는 brief OQ26 의 폭주 실측 대상). 같은 인터뷰 문장이 *"회계 요건을 충족하는지는 별개로
미결"* 이라고 적으므로 그 미결은 §14 U3 이다.

### F4 — 세 인용의 진위 (읽음)

앞 판본이 세 파일을 인용해 메커니즘을 세웠다. **셋 다 그 파일이 말하지 않는 것이었다.**

| 앞 판본의 주장 | 실제 |
|---|---|
| `docs/git-workflow/pr-process.md` 가 비-main base 를 지원한다 | 그 파일 79줄에 stacked PR 도 `--base` 도 없다. `base 브랜치` 는 동기화 체크리스트의 변수(`:16`·`:55`) |
| `check-no-verdict-injection.py` 는 판정 어휘 스캐너다 | 특정 사건에서 귀납한 **한국어 문구 블랙리스트**(`BANNED`:47-63 + `SEED_EXTRA`:75-81). 헤더 `:16-20` 이 *"Narrowing the scope is how the false positives go away"* 로 **좁은 스코프가 하중**임을 명시 |
| 훅이 두 채널을 쓴다 | 세 키다 (F3) |

이 판본은 세 자리에서 **그 인용을 걷어냈다** — §4.2 · §4.5 · §7.

## 0. 한눈에

**무엇** — 판정 항목이 버려질 때 `Ledger` 메서드를 반드시 부르게 하고, 그것을 부르는지 검사하는
락 넷을 둔다. 검사 대상은 목록이 아니라 구조에서 도출하고, 이미 있는 도출기를 재사용한다(F1).

**왜** — 계산기는 있고 `report()` 는 카운트 여섯을 이미 낸다. 프로덕션이 읽는 것은 `held` 하나,
「리뷰어가 보고 판단해서 배제」를 세는 호출은 **0건**이다.

| # | 사용자 결정 |
|---|---|
| D1 | 세 축이 충돌하면 **회계가 이긴다** |
| D2 | 공시는 **두 지표로 쪼갠다** |
| D3 | **도출 우선** |
| D4 | 규칙 억제는 **새 칸 「억제」로 분리** |
| D5 | stale 이름은 **제거**하고 그 방향을 보는 검사를 둔다 |
| D6 | **자동 실행자 신설은 범위 밖** |

**확정 제약이 어디에 사나**

| 제약 | 어디 | 완전한가 |
|---|---|---|
| **C4** 전 자리 통일 + 특화만 분기 | L1·L3·L4·T1 이 통일을 지고, 분기는 **§8 의 표에서만** 일어나며 각 행이 C6 조건을 인용한다 | 예 |
| **C5** 입력·역할·회계 셋 다 | 입력 = L3 · 회계 = T1·L1·L2·T3 · **역할 = 부분** | **아니오 — §8 이 그 미달을 C6⑵ 로 적는다** |
| **C13** 술어 도출 + 훅 2곳 | 앞절 = §2·D3 · 뒷절 = T5 | 예 |

## 1. 문제

### 1.1 어휘는 완성돼 있다

`shared/adjudication/adjudication.py` 의 `Ledger` — `accept`(:43) · `reject`(:47) · `hold`(:51) ·
`absorbed`(:55) · `coerced`(:59) · `source_failed`(:67) · `uncountable`(:75) · `blocks`(:89) ·
`reasons`(:106) · `report`(:121) · `surfaced`(:136). 배포는 심볼릭 링크(mode 120000)로
quality-gates · spec-distill 두 곳.

### 1.2 배선이 절반이다

**생산자** — 「리뷰어가 보고 판단해서 배제」를 세는 호출이 0건이다.
`plugins/quality-gates/scripts/synthesize_findings.py:298-310` verbatim:

```python
        f = _normalize_identity(dict(f))
        v = by_id.get(finding_id(f))
        if v is None:
            # (주석 3줄 — 원문 :301-303)
            if ledger is not None:
                ledger.hold(finding_id(f), "adversarial 판정 부재")   # 부른다
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            continue                                                  # 안 부른다
```

**소비자** — `report()` 의 카운트 여섯 중 프로덕션이 읽는 것은 `held` 하나
(`synthesize_findings.py:562` · `synthesize_artifact_findings.py:211` · `merge_review.py:559`).

### 1.3 계산기 밖에 평행 어휘가 셋 산다

| # | 어디 | 처분 |
|---|---|---|
| ⓐ | `synthesize_findings.py:551-552` 의 `dropped_*` **5종** + `:494` 의 `suppressed_count` | **흡수**(T1) — 다섯 전부, 아래 T1 표가 각각을 지목 |
| ⓑ | `synthesize_artifact_findings.py:235-243` 의 자체 `degraded`·`degraded_reason` | **흡수**(T1) |
| ⓒ | `audit-workflow.js:492…596` 의 `degradedEvents` — JS | **제외**(§8) — **판정자가 둘로 남는다** |

## 2. 도출 규칙

| 집합 | 신호 | 판정기 | 오늘 |
|---|---|---|---|
| **㉮ 회계 소비자** | ⑴ `plugins/*/scripts/*.py` · `plugins/*/hooks/*.py` 가 `adjudication` 을 import **∪** ⑵ 처분 앵커가 `consumer=<path>.py` 로 지목한 파일 | grep + 앵커 스캔 | **4** (T5 후 5) |
| **㉯ 외부 모델 판정자** | F1 의 도구 출력에 `/scripts/` 후처리 | **기존 `extract_codex_invocations.py`** (무수정) | **6** |
| **㉰ 서브에이전트 판정자** | `plugins/*/agents/*.md` 의 `name:` (`test_dispatch_disposition.sh:63-68` 의 ∀) | 기존 락 | **20** |

㉮ 의 4는 두 경로 모두에서 확인했다 — `adjudication` 을 import 하는 `plugins/*/scripts/*.py` 가 4개,
처분 앵커가 `consumer=…py` 로 지목한 경로도 **같은 4개**. ㉰ 의 20도 확인했다.

**합집합인 이유** — import 하나로만 도출하면 **그 import 를 지우는 것이 락에서 빠져나가는 길**이
된다(codex round 4 지적). ⑵ 의 앵커는 **다른 파일**(skill)에 살고 기존 락의 축 A④·B 가 이미 그
앵커를 ∀ 로 검사하므로, 피검자가 자기 파일을 고쳐서 ⑵ 를 벗어날 수 없다. 두 경로가 오늘 같은
4개를 내는 것이 그 합집합이 공허하지 않다는 증거는 아니다 — **분기하는 순간이 곧 회귀 신호**이고
M7 이 두 값을 따로 기록한다.

**신설하지 않는다** — ㉯ 의 도출은 리포에 이미 두 벌 있고 서로를 대조한다.

## 3. 작업 T1 — 배선

| # | 자리 | 부를 것 |
|---|---|---|
| T1-1 | `synthesize_findings.py:310` | `reject` |
| T1-2 | `synthesize_findings.py:295` | **`hold("항목 파손: …")`** — ⓐ 의 `dropped_raw` 흡수 |
| T1-3 | `synthesize_findings.py` 의 `dropped_verdicts`·`dropped_newlist` (컨테이너 수준) | `source_failed` — **L1 이 구조적으로 못 보는 자리**(루프 원소 경로가 아님). 락이 아니라 T1 이 책임진다 |
| T1-4 | `synthesize_findings.py` 의 `dropped_primary`·`dropped_promoted` | `hold("항목 파손: …")` |
| T1-5 | `synthesize_artifact_findings.py:203` | `reject` |
| T1-6 | `synthesize_artifact_findings.py:216` | `hold("항목 파손: …")` |
| T1-7 | `synthesize_artifact_findings.py:221` | `absorbed` |
| T1-8 | `synthesize_findings.py:336-342` (dedup) | `absorbed` — `dedup()` 에 계산기 인자 추가(`:554` 호출부). **L1 이 못 봄** — 매 회 append 하고 손실이 그룹 «안»에서 일어난다 |
| T1-9 | `synthesize_findings.py:361-362` (suppress) | **새 메서드 `suppressed(item, why)`** (D4). **L1 이 볼지 미정** — `suppressed` 리스트를 「출력」으로 보느냐에 따라 갈린다(U1) |
| T1-10 | `_normalize_identity` **확장**(`:149`) | `coerced`. **L1 이 못 봄** — 값 강제이지 원소 처분이 아니다 |
| T1-11 | `synthesize_artifact_findings.py:100-155` | `source_failed` — ⓑ 흡수 |
| T1-12 | **모든 `hold()` 호출부의 `why` 접두 통일** + `Ledger.held_by_class()` 신설 | §5 의 데이터 경로 |

**L1 이 구조적으로 못 보는 자리 넷** — T1-3 · T1-8 · T1-9(미정) · T1-10. **「L1 GREEN」을 「배선
완료」로 읽으면 안 된다.** 그 넷은 락이 아니라 T1 이 책임지고, M2 의 통과가 그것을 증명하지 않는다.

**「항목 파손」은 `hold` 로 통일한다.** 앞 판본이 같은 두 자리에 `source_failed` 와 `hold` 를 동시에
지시해 §5 의 칸이 영구히 0이 될 뻔했다(리뷰어 둘이 독립 지적). `held_by_class()` 가 `hold` 만
분류하므로 파손도 `hold` 여야 한다. `source_failed` 는 **소스 전체가 죽은** 자리에만 쓴다.

**T1-10 은 신설이 아니라 확장이다** — `synthesize_findings.py` 의 `_norm_sev()` 가 네 곳에서 불려 그
안에 넣으면 네 번 세어진다. 입력 직후 정규화 패스는 같은 파일의 `_normalize_identity()` 로 **이미
존재한다.**

**T1-12 — `held_by_class()`.** `reasons()` 는 평면 문자열이고 `held` 는 int 하나라 클래스별 개수를
산문 재파싱 없이 못 얻는다. 접두 둘(`"판정자 부재: "` / `"항목 파손: "`)을 확정하고 접두별 카운트를
반환하는 메서드를 `shared/` 에 더한다. **알 수 없는 접두의 처리는 U4.**

### 3.1 철회한 것 둘

- **`surfaced()` 배선** — `adjudication.py` 의 `surfaced()` 가 `items == "closed"` 에서 빈 리스트를
  반환하고, 배선 대상(`synthesize_artifact_findings.py` 의 `Ledger(items="closed")`)이 정확히 그 모드다.
- **`hold` → `source_failed(primary=False)` 재배치** — `adjudication.py` 의 `blocks()` 첫 항이
  `bool(self._held)` 라 옮기면 `blocks()` 가 꺼진다. CLAUDE.md 의 차단 술어와 충돌한다.

## 4. 작업 T2 — 락 넷

| 락 | 대상 | 요구 | 오늘 |
|---|---|---|---|
| **L1 배선** | ㉮ **파일의 모든 `for` 루프** | 루프 원소가 출력에 도달 못 하고 끝나는 경로마다 같은 분기에 처분 호출이 있어야 한다 | **RED** — 최소 5자리(F2, 하한) |
| **L2 소비** | 계산기 출력 | `report()` 의 카운트가 **전부**(`accepted` 포함) + `unknown_counts` 가 프로덕션 출력에 실려야 한다 | **RED** — 6 중 5 미소비 |
| **L3 입력 선언** | ㉰ 20 | (a) 선언 ↔ 전달 일치 · (b) 선언된 슬롯에 금지 종류 없음 | **RED** — 2/20 |
| **L4 역할 선언** | ㉯ 6 | 처분 선언(`consumer=`·`fail-*`·`disclosure=`)을 갖는다 | **RED** — 6/6 없음 |

### 4.1 L1 의 모집단은 피검자 손에 없다

**대상 = ㉮ 파일의 «모든» `for` 루프.** 앞 판본은 *"처분 메서드가 불리는 함수"* 를 대상으로 삼았고
두 리뷰어가 독립으로 그 순환을 지적했다 — **전혀 배선 안 된 버리기는 영원히 안 보인다.** 그것은
§11 이 다른 락에 대해 기각한 「안 적으면 대상 아님」과 같은 형태다.

**면제는 락의 상수에 산다** — 저자 파일이 아니라. 각 면제 항목은 **C6 의 두 조건 중 하나를
인용**해야 하고 인용이 없으면 RED. §4.2 의 L3(b) 면제 목록과 같은 모양이고 M8 이 그 크기를 잰다.

**오늘 예상되는 면제 후보** — 제자리 변형 루프(`synthesize_artifact_findings.py:146` 의
`for f in findings: f.setdefault(...)` 처럼 출력 컬렉션이 없는 것). **면제 목록의 초기 내용은 U1** —
`writing-plans` 가 정밀 구현을 돌려 실제로 걸리는 자리를 보고 정한다.

**「버리는 분기」** = 루프 원소가 출력 컬렉션에 도달하지 못하고 끝나는 경로 — `continue` · `break` ·
이른 `return` · 본문 끝까지 append 없음. **이 넷 중 하나만 F2 가 측정했다**(§A). 나머지 셋의
실제 적중 범위는 U1 이 연다.

### 4.2 L3 는 프레이밍 축을 절반만 흡수한다

L3(a)는 **선언과 전달의 일치**일 뿐 *무엇을 선언해도 되는가*의 어휘가 없다. `<history>${...}</history>`
를 선언하면 누출이 그대로인 채 GREEN 이 된다.

**L3(b) — 내용 술어.** 각 슬롯은 `kind:` 를 갖고 금지 종류는 brief C8 의 세 범주다:
`prior_verdict` · `score` · `orchestrator_framing`.

**판정기는 새로 만들어야 한다** — 앞 판본은 `plugins/plugin-audit/scripts/check-no-verdict-injection.py`
(**다른 플러그인**이다 — 설치본에서 런타임 도달 불가)를 승격해 치환한다고
적었으나 **그 파일은 특정 사건에서 귀납한 한국어 문구 블랙리스트이고 `score`·`orchestrator_framing`
에 대응하는 패턴이 없으며, 헤더가 좁은 스코프를 오탐 억제의 하중으로 명시한다**(F4). 그것을 7배로
넓히면 그 파일이 방어한 성질을 깨뜨린다. **그 판정기의 형태는 U2.**

다만 **그 파일에서 가져오는 것이 하나 있다 — 구조**: 「주입 표면을 열거하고 그 표면만 스캔한다」.
어휘가 아니라 배치를 재사용한다.

**면제** — adversarial·refuter 계열은 앞 판정을 반박하는 것이 과업이다. `kind: prior_verdict` 를
선언하고 **락의 상수에 C6 인용과 함께** 등재한다.

### 4.3 L3 의 공수 (가장 큰 단일 작업)

프로토타입은 `plugins/spec-distill/tests/test_seed_agents.sh` 이나 일반화 지점이 넷이다 —
`:123`(`for a in seed-critic seed-readback`) · `:154`(`subagent_type` 리터럴) ·
`:101`(`"spec-distill:$1"` 접두사와 `javascript` 펜스) · `:2`(`# guards:` 가 SKILL 하나).
20 에이전트 중 **18은 슬롯 선언 자체가 없다**. 5개 플러그인의 dispatch 표기가 따라온다.
**문법은 U2.**

### 4.4 동시에 편집해야 하는 기존 락

| 락 | 무엇이 깨지나 |
|---|---|
| `test_skill_drop_notice_consumed.sh` | 생산자–소비자 문자열 동일성. **리포에서 그 seam 을 재는 유일한 락 — 약화 금지**(M9) |
| `test_synthesize_artifact_findings.sh:86-241` | `degraded_reason` 닫힌 어휘 4값 |
| `test_synthesize_promoted_findings.sh` | `dropped` 2수준 계수 |
| `reviewing-spec/SKILL.md:116` | merge_review 출력 키 열거 — L2 가 카운트를 실으면 깨진다 |

### 4.5 PR 분할

| PR | 내용 |
|---|---|
| **PR1** | L1·L2·L3·L4 + T4-2 신설 — **전부 RED 인 채**. T4-2 는 stale 이름이 **살아 있을 때** 들어가야 이빨이 증명된다 |
| **PR2** | T4-1(stale 제거) + T1 + T3 + T5 + §4.4 기존 락 갱신 → L1·L2·L4·T4-2 GREEN |
| **PR3** | L3 의 18 에이전트 슬롯 규약 + 5 플러그인 dispatch 표기 → L3 GREEN |

**RED 커밋에 대한 정직한 서술.** 앞 판본은 *"`pr-process.md` 가 비-main base 를 지원한다"* 를
근거로 stacked PR 완화책을 세웠다. **그 문서에 그런 서술이 없다**(F4). 실제 상태는 이렇다 —
리포에 CI 가 없고 D6 이 실행자를 제외했으므로 **RED 가 `main` 에 가는 것을 막는 메커니즘이
없다.** merge commit 규약상 PR1 의 RED 커밋은 `main` 의 조상이 된다. GREEN 인 것은 **트리 상태**
이지 히스토리가 아니다. 이 사실을 완화하지 않고 적는다 — 대안은 PR 을 쪼개지 않는 것뿐이고,
그러면 M1(락이 오늘 RED 임을 증거로 남김)을 잃는다. **그 교환을 사용자가 판정한다**(§13).

## 5. 작업 T3 — 출력 모양

```
**Findings:** 0 CRITICAL / 3 IMPORTANT / 5 SUGGESTION
**처분:** 수용 8 · 기각 7 · 억제 2 · 흡수 4 · 미판정 1     ← 상태별, 차단 아님
**배관 손실:** 3 · 셀 수 없음 1 (차단)                      ← 차단은 blocks() 가 정한다
```

| 칸 | 들어가는 것 | 차단 |
|---|---|---|
| **처분** | `accepted` · `rejected` · `suppressed` · `absorbed` · `held_by_class()["판정자 부재"]` | 아니오 |
| **배관 손실** | `sources_failed` · `held_by_class()["항목 파손"]` · `coerced` · **`unknown_counts`(셀 수 없음)** | `blocks()` 가 정한다 |

**`unknown_counts` 를 뺐다가 되돌렸다.** 그것은 `report()["counts"]` 에 없지만 `blocks()` 의 세 항
중 하나다(`adjudication.py` 의 `blocks()`). 빼면 **uncountable 로 차단된 실행이 어느 칸에도 숫자를 안
남긴다.** 그래서 별도 항목으로 싣는다.

**`coerced` 는 `blocks()` 가 읽지 않는다**(확인함) — 칸에는 싣되 차단에 기여하지 않는다.
칸의 합계와 차단은 같은 집합이 아니므로 `(차단)`/`(차단 아님)` 을 **명시**한다.

## 6. 작업 T4 — stale 이름과 역방향 스캔

`quality-pipeline/SKILL.md:511` 은 이렇게 적는다 — *"Dispatch `quality-gates:synthesizer`
**(or local synthesize_findings.py)** to consolidate findings."* 그 에이전트는 없다
(`37ea0d7` 이 정의를 지우고 스크립트로 옮겼다). **괄호 안이 이미 탈출구다** — 그래서 T4-1 은
긴급하지 않고, 값은 T4-2 가 다음 stale 을 잡는 데 있다.

| # | 내용 | PR |
|---|---|---|
| **T4-1** | `:511` 정리 | PR2 |
| **T4-2** | *"dispatch 되는 이름은 전부 정의가 있어야 한다"* | PR1 |

**기존 도출로는 안 된다** — 현행 `NOTATION`(`subagent_type:|agentType:|Agent\(|^\s*agent:\s`)이
`:511` 의 **산문**을 매치하지 않는다(확인함). T4-2 는 **참조 스캐너**를 요구한다. §11 이 금지한
것은 **모집단 도출기**의 신설(㉯)이고 이것은 참조 스캔이다.

**넘겨야 할 실측 제약** — `shared/tests/test_dispatch_disposition.sh:80-84` 가 *"표기 필터를 이름
매칭보다 먼저 걸지 않으면 산문 속 영어 단어가 dispatch 로 잡힌다"* 를 실측으로 기록했고
(*"맨 `adversarial` 이 5줄에 등장하고 전부 산문"*), T4-2 는 그 필터를 빼는 방향이다.
**토큰 규칙은 U4** — 그 실측이 U4 의 입력이다.

## 7. 작업 T5 — 훅 층 회계

C13 은 confirmed 이고 *"Phase 0 이 이 세션에 배정한 훅 차단 결정 2곳을 더한다"* 로 포함을 명시한다.

| # | 자리 | 내용 |
|---|---|---|
| T5-1 | `review-dispatch.py:599` (`decision:"block"` — 구조 검증 실패) | 차단 사실과 사유를 원장 어휘로 기록 |
| T5-2 | `review-dispatch.py:752` (`decision:"block"` — 다음 턴 dispatch 강제) | 같음 |

**공시 채널은 `reason` 이다** (F3). 그 두 자리는 이미 `decision`·`reason`·`systemMessage` 세 키를
내고, 인터뷰 실측이 `systemMessage` 0/14 · `reason` 7/7 이다. `additionalContext` 는 쓰지 않는다
(brief OQ26 의 폭주 실측 대상). **영속 기록은 `write_state_file()`**(`:198-204`).

**「회계 요건을 충족하는가」는 미결이다** — 같은 인터뷰 문장이 그렇게 적는다. §14 U3.

**측정** — 훅이 `adjudication` 을 import 하면 ㉮ 에 들어오고, L1 의 대상이 **그 파일의 모든 `for`
루프**이므로(§4.1) 공허한 GREEN 이 되지 않는다. 앞 판본은 L1 대상이 「처분 호출이 있는 함수」라
import 만 하고 아무것도 안 불러도 GREEN 이었다(리뷰어 둘이 독립 지적).

**도달 가능성** — 심볼릭 링크가 있고 `review-dispatch.py:52-53` 이 `SCRIPTS_DIR` 을 `sys.path` 에
넣는다. P5 가 실행으로 확인한다.

**형제 세션 — 위험은 소멸이 아니라 동시 편집이다.** 앞 판본은 인터뷰 `:529-534`(Phase 0 시점의
조사)를 인용해 *"기능을 걷어내는 방향이 유력"* 을 근거로 P6 게이트를 세웠다. **같은 입력 문서
`:190-193` 이 그 질문을 이미 닫는다** — *"OQ3 — 닫힘(형제 세션 조율). 그쪽이 그 훅을 이번 범위에
넣되 **걷어내지 않는다.** 손대는 것은 목적지 리터럴뿐이고 차단 결정 두 자리는 그대로다."*

**그러므로 T5 의 대상은 유지된다.** 실제 제약은 **같은 파일(`review-dispatch.py`)을 두 사이클이
동시에 고친다**는 것이다 — 형제는 목적지 리터럴을, 이쪽은 두 `decision:"block"` 분기를. §6 T4-2 의
이름 스캔과도 겹친다(`:752` 의 강제 대상이 리터럴에서 데이터로 바뀌면 스캔 코퍼스가 달라진다).
**P6 은 존치 확인이 아니라 동시 편집 조율이다.**

## 8. 제외 범위 — 각 행이 C6 조건을 인용한다

C6 ⑴ 대응물이 원리적으로 없음 · ⑵ 측정된 이유(기존에 기록된 설계 이유 포함).

| 제외 | C6 | 근거 |
|---|---|---|
| codex 스키마 둘의 통일 | ⑵ | hard crash / false-clean. `shared/codex/runner_common.sh:11-35` |
| `degradedEvents`(ⓒ) | ⑵ | JS 는 개념의 대응물을 갖췄고 없는 것은 심볼릭 링크다 |
| 자동 실행자 신설 (D6) | ⑵ | 사용자 결정 |
| cross-family 를 계약이 요구하기 | ⑵ | C14 가 별도 축으로 확정 |
| `surfaced()` 배선 | ⑴ | `items="closed"` 에서 빈 리스트 — 살리려면 fail-closed 방향을 뒤집어야 함 |
| `quality-pipeline/SKILL.md:488`(Tier C) | ⑵ | 프롬프트 리터럴이 파일에 없어 **무엇이 실리는지 셀 수 없다.** (앞 판본은 ⑴ 로 적었으나 「셀 수 없음」의 대응물은 `uncountable()` 로 실재한다 — 분류가 틀렸다) |
| **C3 의 역할 재배치** | ⑵ | 축(「프레이밍을 보느냐」)에 대한 방향성 리뷰의 미반영 지적이 brief §3 의 **OQ11~OQ19 아홉 건**으로 살아 있다(audit `:79` — 방향성 Claude 11 / codex 5 중 미반영분). 미해소 근거 위에 배치를 바꾸지 않는다 |
| **C5 의 역할 축 — 실질 미달** | ⑵ | L4·T4·T5 는 **선언·이름·회계**이지 「비판자의 역할 구조 통일」이 아니다. 리뷰어가 재라벨이라고 지적했고 **맞다.** 역할 구조의 실질은 C3 의 축이 정하는데 그 축이 **OQ11~OQ19** 로 미해소이므로 같은 근거로 미룬다. **C5 는 이 사이클에서 2/3만 달성된다** |

## 9. 착수 전 선결 조건

| # | 확인 | 통과 조건 |
|---|---|---|
| P1 | `check_seed.py` + `test_seed_one_sentence.sh` 가 L3 와 충돌하는가 | **충돌해도 L3 를 빼지 않는다** — 그 자리만 §8 표에 C6⑵ 로 추가 |
| P2 | F1 재실행 + `/scripts/` 후처리 | 7 → 6 |
| P3 | L1 의 **정밀 구현**을 ㉮ 전체에 돌린다 | **F2 의 5자리를 오라클로 쓰지 않는다**(F2 는 하한). 나온 자리 전수를 목록으로 만들고 면제 후보를 골라 U1 을 닫는다 |
| P4 | **기존 락 전량 baseline** — 선재 RED 에 이름과 이유 | M10 의 기준점 |
| P5 | 훅에서 `adjudication` import 실행 확인 | T5 의 전제 |
| P6 | **형제 세션에 훅 존치 여부를 확인** | 걷어내면 T5·M3·C13 뒷절을 재설계한다 |

## 10. 위험

- **대리지표 치환** — §5 의 쪼개기가 구조적 답이다.
- **락을 만들어도 아무도 안 돌린다**(D6) · **RED 커밋이 `main` 의 조상이 된다**(§4.5).
- **L3(b) 판정기를 새로 만든다** — 앞 판본이 재사용한다고 적었으나 그 파일은 다른 것이다(F4).
  새 판정기는 오탐 위험을 처음부터 진다.
- **면제 목록 둘이 자란다**(L1·L3b) — C6 인용을 요구하고 M8 이 크기를 잰다.
- **`_normalize_identity` 확장의 폭발 반경** — 형제 `_norm_sev` 주석이 과거 사고를 기록한다.
- **§4.4 seam 락의 회귀** — M9 가 이빨 생존을 따로 잰다.
- **정적 검사의 절대 경계** — 이름을 문자열 연결로 쪼개면 이 리포의 락도 새 락도 침묵한다.
- **형제 세션이 T5 의 대상을 없앤다**(§7) — P6.

## 11. 기각한 대안

- **배선만 하고 락을 안 만든다** — §1.3 의 평행 어휘가 계산기 밖에서 자란 것이 증거.
- **새 표식(`# **판정** —` 등)을 요구한다** — 「안 적으면 대상 아님」. `spec-distill/CHANGELOG.md:2347`.
- **㉯ 용 도출기를 새로 만든다** — 이미 두 벌 있고 서로를 대조한다(F1).
- **㉯ 도출기를 고쳐 스코프 인자를 넣는다** — standing assertion 에 묶여 있다(F1).
- **L1 의 대상을 「ledger 를 인자로 받는 함수」로 한다** — 파일 하나를 통째로 놓친다(F2).
- **L1 의 대상을 「처분 메서드가 불리는 함수」로 한다** — 배선 안 된 버리기가 영원히 안 보인다.
  모집단이 피검자 손에 있다(§4.1).
- **L3(a) 만으로 프레이밍 축을 덮는다** — 「적으면 통과」가 된다.
- **`hold` 를 `source_failed` 로 옮긴다** — `blocks()` 가 꺼진다.
- **`surfaced()` 를 아티팩트 합성기에 배선한다** — `items="closed"` 에서 빈 리스트.
- **presence 락의 코퍼스를 공유 계약 파일까지 넓힌다** — 그 파일이 대신 만족시킨다.
  `presence_corpus.sh:10-20` 정본, `:32-40` 헬퍼.
- **규칙 억제를 `reject` 에 합친다** — D2 가 없애려던 실명이 재발한다.

## 12. 완료 측정

| # | 재는 법 | 통과 조건 |
|---|---|---|
| M1 | PR1 직후 L1–L4 | **전부 RED.** GREEN 인 락은 재설계한다 |
| M2 | T1 후 L1·L2 | GREEN |
| M3 | T5 후 L1 | GREEN **그리고** 훅의 두 `decision:"block"` 분기가 처분 호출을 갖는다 — ㉮ 개수(4→5)만으로 판정하지 않는다 |
| M4 | T4-1 후 T4-2 | GREEN (PR1 에서 RED 였던 것이 여기서 GREEN) |
| M5 | PR3 후 L3 | GREEN |
| M6 | **락별 귀속 변이** — 변이마다 **어느 락이 RED 여야 하는지 미리 적고** 실행. **변이 목록은 각 락의 단언에서 도출한다**(임의로 고르지 않는다 — 내 변이가 락의 전제를 공유하는 것을 막는 유일한 방법) | 지정한 락이 RED. 다른 락도 함께 RED 인 것은 정상. **지정한 락이 GREEN 이면 실패** |
| M7 | ㉮㉯㉰ 도출 | 5 / 6 / 20. **㉮ 는 두 경로(import · 앵커)의 값을 따로 기록** — 갈리면 회귀 신호다. ㉯ 에 `tests/spike/`·`detect_codex.sh`·`runner_common.sh` 없음 |
| M8 | 면제 목록 둘(L1·L3b) | 각 항목이 C6 조건을 인용한다(인용 없는 항목 0) **그리고 각 목록의 크기를 기록한다** — ㉮ 네 파일의 `for` 루프가 대략 40여 개라 면제 팽창이 L1 의 유일한 이빨 리스크다. 크기가 늘면 그 커밋에 이유가 있어야 한다 |
| M9 | **seam 락의 이빨 생존** — `test_skill_drop_notice_consumed.sh` 에 변이(소비자 분기 삭제) | RED |
| M10 | 기존 락 전량 | **P4 의 baseline 대비** 신규 RED 0 |
| M11 | 결정론 fixture 로 처분 행렬 — 기각·억제·흡수·미판정·배관 손실·셀 수 없음 각 1건 이상 | §5 의 세 줄이 기대값과 일치. 라이브 `/qg` 에 의존하지 않는다 |
| M12 | 라이브 `/qg` 1회 | 세 줄이 렌더된다. 숫자는 0이어도 통과 |

**M6 의 전제** — 변이 전에 커밋한다(`git checkout --` 는 HEAD 로 되돌린다).

## 13. 재결정 기록

리뷰가 반증해 이 문서가 방향을 바꾼 것들. **원래 / 이 판본 / 근거.**

| 항목 | 원래 | 이 판본 | 근거 |
|---|---|---|---|
| 훅 층 회계 | 제외 | **포함**(T5) | 인용한 락은 다른 플러그인 것. C13 은 confirmed |
| `surfaced()` | 배선 | 제외(C6⑴) | `items="closed"` 에서 빈 리스트 |
| `hold` 재배치 | `source_failed` | 철회 | `blocks()` 가 꺼진다 |
| L1 대상 | ledger 인자 → 처분 호출 함수 | **㉮ 파일의 모든 `for` 루프** | 앞 둘 다 모집단이 좁거나 피검자 손에 있다 |
| ㉯ 도출 | 도구 수정/승격 | 무수정 + 후처리 | F1 |
| T4-2 의 PR | 제거 이후 | **제거 이전(PR1)** | 이후면 도착 즉시 GREEN |
| §5 데이터 경로 | `reasons()` 문자열 | `held_by_class()` + 접두 통일 | 평면 문자열, `held` 는 int 하나 |
| 「항목 파손」의 메서드 | `source_failed` 와 `hold` 를 동시 지시 | **`hold` 로 통일** | `held_by_class()` 가 `hold` 만 분류 |
| T5 공시 채널 | `systemMessage` | **`reason`** | 인터뷰 실측 0/14 vs 7/7 |
| L3(b) 판정기 | 기존 파일 승격(치환) | **신설**(U2) | 그 파일은 한국어 문구 블랙리스트다(F4) |
| RED 커밋 완화책 | stacked PR | **완화책 없음 — 사실을 적는다** | 인용한 문서에 그 서술이 없다(F4) |
| C5 역할 축 | 「L4·T4·T5 로 커버」 | **2/3 달성 · §8 에 C6⑵ 로 미달을 적는다** | 재라벨이라는 지적이 맞다 |
| `unknown_counts` | §5 에서 뺌 | **되돌림** | `blocks()` 의 세 항 중 하나 |
| 형제 세션 의존 | 미결(P6 이 존치를 확인) | **OQ3 닫힘 — 위험이 「소멸」에서 「동시 편집」으로 바뀜** | 입력 문서 `:190-193` 이 이미 닫았다. 앞 판본이 같은 문서의 더 오래된 줄을 인용했다 |
| 방향성 미반영분의 수 | 「13건」 | **OQ11~OQ19 아홉 건** | 13은 축이 다른 계측(brief `:118`) |
| ㉮ 도출 | import 단독 | **import ∪ 앵커 `consumer=`** | import 를 지우는 것이 탈출 경로가 된다 |

**사용자 판정이 필요한 것 둘**

1. **RED 커밋이 `main` 의 조상이 된다**(§4.5). 대안은 PR 을 쪼개지 않는 것이고, 그러면 「락이 오늘
   RED 였다」는 증거(M1)를 잃는다.
2. **C5 가 2/3만 달성된다**(§8). 역할 축의 실질은 C3 의 축이 정하는데 그 축이 미해소다. 이 사이클에서
   억지로 채우려면 미해소 근거 위에 배치를 바꿔야 한다.

### Known gaps

- 판정자가 둘로 남는다(ⓒ, JS) — OQ22 의 drift 쌍 조건 성립.
- 자동 실행자 부재(D6) · `disclosure=` 채널이 실제로 읽히는지(정적 검사 밖).
- 축 A⑤ — 코드는 7축, 문서는 6축, mutation 검증 0건.
- `# guards:` 선언의 하한 — 방향 B 가 글롭당 `n > 0`.
- OQ16 · OQ5 · OQ10 · OQ21 — 답하지 않았다.
- **방향성 리뷰의 미반영 지적 — brief §3 의 OQ11~OQ19 아홉 건**(audit `:79`: 방향성 Claude 11 /
  codex 5, 사용자 재결정 2 + 유지 재확인 1, 나머지 이월). 축 교체가 단독 저자 preprint 하나에
  기대고 [취함] 논문 둘은 모든 비판자에게 같은 전체 맥락을 준다. §8 의 C3·C5 행이 이것을 근거로
  배치 변경을 보류한다. (앞 판본들이 이 수를 「13건」으로 적었다 — 그 13은 brief `:118` 의
  「불일치 20건 중 13건이 **입력 계약**에 몰려 있다」로 축이 다른 계측이다.)

## 14. writing-plans 가 정할 미결

| # | 무엇 | 왜 여기 있나 |
|---|---|---|
| U1 | **L1 의 정밀 구현과 면제 목록의 초기 내용** | F2 는 네 버리기 형태 중 하나만, 그것도 하한으로 측정했다. P3 가 전수를 내고 그 결과로 면제를 정한다 |
| U2 | **L3 의 슬롯 문법 + `kind:` 판정기** — 선택적 슬롯 · 반복 dispatch · 템플릿 · 별칭의 매칭 규칙, 그리고 세 금지 종류를 무엇으로 판정할 것인가 | §4.2·§4.3. 기존 파일은 재사용 불가(F4) |
| U3 | **L4 의 런타임 인터페이스** — 러너의 사전-항목 실패가 원장에 도달하는 경로. **그리고 T5 의 `reason` 기록이 「회계 요건을 충족하는가」** | 인터뷰가 그 미결을 명시했다(F3) |
| U4 | **T4-2 참조 스캐너의 토큰 규칙**(§6 의 실측 제약이 입력) **+ `held_by_class()` 의 미지 접두 처리** | §6 · T1-12 |

**이 넷을 산문으로 미리 정하지 않는다.** 앞 판본들이 정했고 리뷰어가 파일을 열어 반증했다.
