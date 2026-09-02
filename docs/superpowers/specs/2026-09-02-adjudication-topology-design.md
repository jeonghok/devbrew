# 판정 지형 — 회계 배선과 도출 락 · Design

> 판정을 버릴 때 이름을 부르게 하고, 그 이름을 부르는지 구조에서 도출해 검사한다.

## Handoff Context

- **입력** — `docs/superpowers/interview/2026-09-02-adjudication-topology-interview.md`
  (확정 17 · 잠정 2 · 열린 질문 26). 텔레메트리는 같은 이름의 `.audit.md`.
- **이 문서가 정하는 것** — brief 가 의도적으로 미확정으로 남긴 OQ1(통일 계약의 구체적 형태).
- **다음** — `superpowers:writing-plans`.

### 이 판본의 규율 (round 1·2 리뷰가 같은 종류의 결함을 반복해 지적한 뒤 도입)

**모든 메커니즘 문장은 둘 중 하나다** — ⑴ §A 의 실측 셋 중 하나를 인용하거나, ⑵ **`writing-plans`
가 정할 미결**로 §14 에 이름이 올라 있다. **산문으로 단정하지 않는다.** 앞 두 판본이 그렇게 했고
두 리뷰어가 매 라운드 그것을 반증했다 — 리포에 이미 같은 실패가 기록돼 있다(*"설계는 도구 동작
사실을 단정하지 말 것 — 산문은 틀려도 소리를 안 낸다"*).

### 이름 규약

| 접두 | 무엇 |
|---|---|
| **T1–T5** | 작업(task) · **L1–L4** 락(lock) · **㉮㉯㉰** 도출된 집합 · **D1–D6** 사용자 결정 · **F1–F3** 이 사이클이 실행한 측정 |

## 목차

- [A. 실측 셋 — 이 설계가 서 있는 바닥](#a-실측-셋--이-설계가-서-있는-바닥)
- [0. 한눈에](#0-한눈에)
- [1. 문제 — 계산기는 있는데 부르지 않는다](#1-문제--계산기는-있는데-부르지-않는다)
- [2. 도출 규칙](#2-도출-규칙)
- [3. 작업 T1 — 배선](#3-작업-t1--배선)
- [4. 작업 T2 — 락 넷 L1–L4](#4-작업-t2--락-넷-l1l4)
- [5. 작업 T3 — 출력 모양](#5-작업-t3--출력-모양)
- [6. 작업 T4 — stale 이름과 역방향 스캔](#6-작업-t4--stale-이름과-역방향-스캔)
- [7. 작업 T5 — 훅 층 회계](#7-작업-t5--훅-층-회계)
- [8. 제외 범위와 근거](#8-제외-범위와-근거)
- [9. 착수 전 선결 조건](#9-착수-전-선결-조건)
- [10. 위험](#10-위험)
- [11. 기각한 대안](#11-기각한-대안)
- [12. 완료 측정](#12-완료-측정)
- [13. 재결정 기록](#13-재결정-기록)
- [14. writing-plans 가 정할 미결](#14-writing-plans-가-정할-미결)

## A. 실측 셋 — 이 설계가 서 있는 바닥

이 사이클이 **직접 실행한** 측정이다. 산문 추정이 아니다.

### F1 — ㉯ 도출기의 실제 출력

`python3 plugins/quality-gates/tests/lib/extract_codex_invocations.py <repo>/plugins` 를 이 워크트리에서
실행한 결과 **7개**:

```
plugin-audit/scripts/run_audit_codex_reviewer.sh
quality-gates/scripts/run_artifact_codex_reviewer.sh
quality-gates/scripts/run_codex_reviewer.sh
quality-gates/tests/spike/test_codex_json_extraction.sh      ← 러너가 아니다
spec-distill/scripts/run_brief_codex_reviewer.sh
spec-distill/scripts/run_seed_codex_reviewer.sh
spec-distill/scripts/run_spec_codex_reviewer.sh
```

- 그 도구는 **심볼릭 링크를 건너뛰고**(`p.is_symlink()`) **주석-전용 파일을 거른다**
  (`COMMENT` 필터). 그래서 `detect_codex.sh` 3사본과 `runner_common.sh` 2사본은 **이미 안 나온다.**
- **CLI 는 `<root_dir>` 하나뿐이고 스코프 인자가 없다.** `collect()` 가 17줄 주석으로 확장자 필터를
  **의도적으로 제거**했다고 적으며, 그 출력이 `test_sandbox_enforced.sh:51-62` 의 standing assertion
  에 묶여 있다. **그러므로 그 파일을 고치지 않는다.**
- **결론** — 그 도구를 그대로 부르고 출력에 `/scripts/` **후처리 필터**를 건다 → 6.

### F2 — L1 후보 규칙 둘을 같은 코퍼스에 돌린 결과

㉮ 4파일에 대해 두 규칙을 AST 로 실행했다.

| 파일 | 규칙 A(*ledger 를 인자로 받는 함수*) | 규칙 B(*처분 메서드가 한 번이라도 불리는 함수*) |
|---|---|---|
| `synthesize_findings.py` | `:295` · `:310` | `:295` · `:310` |
| `synthesize_artifact_findings.py` | **함수 0개 선택 — 아무것도 못 봄** | `:203` · `:216` · `:221` |
| `merge_review.py` | 무방비 continue 0 | 무방비 continue 0 |
| `merge_brief_review.py` | 무방비 continue 0 | 무방비 continue 0 |

**규칙 A 는 `synthesize_artifact_findings.py` 를 통째로 놓친다** — 그 파일은 `Ledger` 를 **로컬로**
만들기 때문이다(4파일 전부 그렇다). 앞 판본이 규칙 A 를 채택하면서 `:203` 을 자기 RED 증거로
들었으므로, 그 락은 **자기가 든 증거를 못 보는** 상태였다. → **규칙 B 를 채택한다.**

**규칙 B 가 새로 찾은 두 자리** (아무도 열거하지 않았던 것):

- `synthesize_artifact_findings.py:216` — `if not isinstance(nf, dict): continue`. 형태 불량 신규
  finding 을 **아무 데도 안 세고** 버린다.
- `synthesize_artifact_findings.py:221` — `if g["dedup_key"] in kept_keys: continue`. **dedup 흡수를
  안 센다**(§1.3 ⓐ 의 형제).

**측정의 한계** — 프로브의 분기 판정은 「continue 를 감싸는 가장 가까운 `If` 본문」을 walk 로
찾는 근사다. 정밀 구현은 `ast.NodeVisitor` 로 부모 사슬을 들고 내려가야 하며, 그 구현이
같은 5자리를 내는지는 **착수 시 P3 가 확인한다.**

### F3 — 훅의 sink 가 실재한다

`plugins/spec-distill/hooks/review-dispatch.py` 는 두 채널을 **이미 쓴다**:

| 채널 | 어디 | 성질 |
|---|---|---|
| `write_state_file(path, body)` | `:198-201` | **영속** — `reviewing-spec` 이 `$STATE` 로 읽는 바로 그 파일 |
| `with_advisory()` → payload 의 `systemMessage` | `:360-381`, 사용처 `:598`·`:646`·`:751` | **사용자에게 닿음** |

그 파일 자신이 `:631-632` 에 *"exit 0 의 stderr 는 사용자에게 전달되지 않는다"* 고 적는다 —
그래서 stderr 를 쓰지 않고 위 둘을 쓴다. **`systemMessage` 는 `additionalContext` 가 아니다** —
brief OQ26 이 기록한 폭주 실측(`additionalContext` 를 내면 subagent 가 종료 안 함)은 이 채널에
해당하지 않는다.

## 0. 한눈에

**무엇** — 판정 항목이 버려질 때 `Ledger` 메서드를 반드시 부르게 하고, 그것을 부르는지 검사하는
락 넷을 둔다. 검사 대상은 목록이 아니라 구조에서 도출하되, **리포에 이미 있는 도출기를
재사용한다**(F1).

**왜** — 계산기는 이미 있고 `report()` 는 카운트 여섯을 이미 낸다. 그런데 프로덕션이 읽는 것은
`held` 하나뿐이고, 「리뷰어가 보고 판단해서 배제」를 세는 호출은 **0건**이다.

| # | 사용자 결정 | 결과 |
|---|---|---|
| D1 | 세 축이 충돌하면 **회계가 이긴다** | 입력·역할 축은 회계에 봉사 |
| D2 | 공시는 **두 지표로 쪼갠다** | §5 |
| D3 | **도출 우선** — 배선 + 대상을 스스로 계산하는 락 | §2·§4 |
| D4 | 규칙 억제는 **새 칸 「억제」로 분리** | T1-5 |
| D5 | stale 이름은 **제거**하고 그 방향을 보는 검사를 둔다 | §6 |
| D6 | **자동 실행자 신설은 범위 밖** | §8 · §10 |

**확정 제약이 어디에 사나** (round 2 리뷰가 C4 의 누락을 지적해 추가):

| 제약 | 이 문서의 어디 |
|---|---|
| **C4** 전 자리 통일 + 특화만 분기 | L3·L4·T1 이 통일을 지고, **분기는 §8 의 표에서만 일어나며 각 행이 C6 의 두 조건 중 하나를 인용한다.** L3(b)의 면제 항목도 같은 인용을 요구한다(§4.2) |
| **C5** 입력·역할·회계 셋 다 | 입력 = L3 · 역할 = L4·T4·T5 · 회계 = T1·L1·L2·T3 |
| **C13** 훅 차단 2곳 | T5 |

## 1. 문제 — 계산기는 있는데 부르지 않는다

### 1.1 어휘는 완성돼 있다

`shared/adjudication/adjudication.py` 의 `Ledger` — `accept`(:43) · `reject`(:47) · `hold`(:51) ·
`absorbed`(:55) · `coerced`(:59) · `source_failed`(:67) · `uncountable`(:75) · `blocks`(:89) ·
`reasons`(:106) · `report`(:121) · `surfaced`(:136). 배포는 심볼릭 링크(mode 120000)로
quality-gates · spec-distill 두 곳.

### 1.2 배선이 절반이다

**생산자** — 「리뷰어가 보고 판단해서 배제」를 세는 호출이 **0건**이다. 그 사건이 일어나는 자리는
F2 가 실측한 **5곳**이고 전부 계산기를 쥔 채 버린다.
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

**소비자** — `report()` 의 카운트 여섯 중 프로덕션이 읽는 것은 `held` 하나뿐. 나머지 다섯은 독자 0.

### 1.3 계산기 밖에 평행 어휘가 셋 산다

| # | 어디 | 처분 |
|---|---|---|
| ⓐ | `synthesize_findings.py:539-553` 의 `dropped_*` 5종 + `:494` 의 `suppressed_count` | **흡수**(T1) |
| ⓑ | `synthesize_artifact_findings.py:235-243` 의 자체 `degraded`·`degraded_reason` | **흡수**(T1) |
| ⓒ | `audit-workflow.js:492…596` 의 `degradedEvents` — JS | **제외**(§8) |

**ⓒ 를 제외하면 판정자가 둘로 남는다.** brief OQ22 의 drift 쌍 조건이 이 사이클 이후에도 성립한다.

## 2. 도출 규칙

| 집합 | 신호 | 판정기 | 오늘 |
|---|---|---|---|
| **㉮ 회계 소비자** | `plugins/*/scripts/*.py` **또는 `plugins/*/hooks/*.py`** 가 `adjudication` 을 import | grep | **4** (T5 후 5) |
| **㉯ 외부 모델 판정자** | F1 의 도구 출력에 `/scripts/` 후처리 필터 | **기존 `extract_codex_invocations.py`** (무수정) | **6** |
| **㉰ 서브에이전트 판정자** | `plugins/*/agents/*.md` 의 `name:` | 기존 락의 ∀ | **20** |

**㉮ 에 `hooks/` 를 넣는 이유** — round 2 리뷰가 *"T5 를 측정하는 것이 아무것도 없다"* 를 block 으로
지적했다. 훅이 세 도출 전부의 밖이었다. 글롭을 넓히면 T5 가 배선되는 순간 ㉮ 에 자동으로 들어와
L1 이 그것을 검사한다 — 열거가 아니라 도출이다.

**신설하지 않는다.** ㉯ 의 도출은 리포에 이미 두 벌 있고(`extract_codex_invocations.py` +
`tests/lib/codex_observation.sh` 의 `codex_candidates()`) 둘이 매 실행 서로를 대조한다. 세 번째를
만들면 이 문서가 경계하는 「판정자 추가」를 스스로 저지른다.

## 3. 작업 T1 — 배선

| # | 자리 | 부를 것 | 근거 |
|---|---|---|---|
| T1-1 | `synthesize_findings.py:310` | `reject` | F2 |
| T1-2 | `synthesize_findings.py:295` | `source_failed`(형태 불량) — ⓐ 의 `dropped` 카운터 흡수 | F2 |
| T1-3 | `synthesize_artifact_findings.py:203` | `reject` | F2 |
| T1-4 | `synthesize_artifact_findings.py:216` | `source_failed`(형태 불량 신규 finding) | **F2 가 새로 찾음** |
| T1-5 | `synthesize_artifact_findings.py:221` | `absorbed`(dedup) | **F2 가 새로 찾음** |
| T1-6 | `synthesize_findings.py:336-342` (dedup) | `absorbed` — `dedup(findings)` 에 계산기 인자 추가(`:554` 호출부) | — |
| T1-7 | `synthesize_findings.py:361-362` (suppress) | **새 메서드 `suppressed(item, why)`** | D4 |
| T1-8 | `_normalize_identity` **확장** (`:149`, 호출 `:253`·`:298`) | `coerced` | 아래 |
| T1-9 | `synthesize_artifact_findings.py:100-155` | `source_failed` — ⓑ 의 자체 int 흡수 | — |
| T1-10 | **모든 `hold()` 호출부의 `why` 접두 통일** + `Ledger.held_by_class()` 신설 | §5 의 데이터 경로 | 아래 |

**T1-8 은 신설이 아니라 확장이다.** `_norm_sev`(`:386-412`)가 네 곳에서 불리므로 그 안에 계산기를
넣으면 같은 항목이 네 번 세어진다. **입력 직후 정규화 패스는 이미 존재한다** —
`_normalize_identity`(`:149`). 그것을 확장해 severity 를 그 자리에서 정규화·기록한다.

**T1-10 — §5 의 데이터 경로.** round 2 리뷰가 *"`reasons()` 는 평면 문자열을 내고 `held` 는 int
하나라 클래스별 개수를 산문 재파싱 없이 못 얻는다"* 를 block 으로 지적했다. 맞다. 그래서:

1. 모든 `hold()` 호출부가 `why` 를 `"판정자 부재: …"` / `"항목 파손: …"` 두 접두 중 하나로 시작한다.
2. `shared/adjudication/adjudication.py` 에 **`held_by_class()`** 를 더한다 — 접두별 카운트를
   dict 로 반환. 심볼릭 링크라 두 플러그인이 함께 받는다.
3. 오늘 두 프로덕션 `hold()` 는 둘 다 「판정자 부재」다. **「항목 파손」 접두의 생산자는 T1-2·T1-4 가
   만든다** — 그 전에는 그 칸이 항상 0이고, 그것이 정상이다.

### 3.1 철회한 것 둘 (round 1 리뷰)

- **`surfaced()` 배선 — 철회.** `adjudication.py:136-138` 이 `items == "closed"` 에서 빈 리스트를
  반환하고 배선 대상(`synthesize_artifact_findings.py:195`)이 정확히 그 모드다.
- **`hold` → `source_failed(primary=False)` 재배치 — 철회.** `adjudication.py:96-98` 의 첫 항이
  `bool(self._held)` 라 옮기면 `blocks()` 가 True→False 로 **꺼진다.** 앞 판본은 정반대로 적었다.
  CLAUDE.md 의 차단 술어와도 충돌한다. **대신 T1-10 이 렌더 층에서 가른다.**

## 4. 작업 T2 — 락 넷 L1–L4

| 락 | 대상 | 요구 | 오늘 |
|---|---|---|---|
| **L1 배선** | ㉮ | **함수 안에서 처분 메서드가 한 번이라도 불리는 함수**의 `for` 루프에서, 원소가 출력에 도달 못 하고 끝나는 경로마다 같은 분기에 처분 호출이 있어야 한다 | **RED 5곳** (F2) |
| **L2 소비** | 계산기 출력 | `report()` 의 카운트가 **전부**(`accepted` 포함) 프로덕션 출력에 실려야 한다 | **RED** — 6 중 5 미소비 |
| **L3 입력 선언** | ㉰ 20 | (a) 정의가 슬롯을 기계 판독 형태로 선언 ↔ dispatch 가 정확히 그것을 줌 · (b) 선언된 슬롯에 금지 종류가 없음 | **RED** — 2/20 |
| **L4 역할 선언** | ㉯ 6 | 처분 선언(`consumer=`·`fail-*`·`disclosure=`)을 갖는다 | **RED** — 6/6 없음 |

### 4.1 L1 의 판정 규칙 (F2 가 고른 것)

**대상 함수 = 그 함수 안에서 `Ledger` 처분 메서드가 한 번이라도 불리는 함수.** 앞 판본의
*"ledger 를 인자로 받는 함수"* 는 4파일 전부가 `Ledger` 를 **로컬로** 만들기 때문에
`synthesize_artifact_findings.py` 를 통째로 놓쳤다(F2).

**「버리는 분기」** = 그 함수의 `for` 루프 안에서 원소가 출력 컬렉션에 도달하지 못하고 끝나는 경로
— `continue` · `break` · 이른 `return` · 본문 끝까지 append 없음. 각 경로에 대해 **같은 분기 안에**
처분 호출이 있어야 한다.

**미결(§14 로)** — ⑴ 분기 판정의 정밀 구현(부모 사슬 추적) ⑵ 리스트 컴프리헨션의 `if` 필터 처리
⑶ 헬퍼로 분리된 버리기(계산기를 안 받는 순수 함수). ⑶ 은 T1-6·T1-7 이 그 함수들에 계산기 인자를
넣는 것으로 **완화**되지만, 락이 그 전제 자체를 검사하지는 않는다.

### 4.2 L3 는 프레이밍 축을 절반만 흡수한다

L3(a)는 **선언과 전달의 일치**일 뿐 *무엇을 선언해도 되는가*의 어휘가 없다. `<history>${...}</history>`
를 선언해 버리면 누출이 그대로인 채 GREEN 이 된다 — §11 이 기각한 「안 적으면 대상 아님」이
「적으면 통과」로 뒤집혀 재발한다.

**L3(b) — 내용 술어.** 각 슬롯은 `kind:` 를 갖고 금지 종류는 brief C8 의 세 범주다:
`prior_verdict` · `score` · `orchestrator_framing`.

**판정기는 신설하지 않는다** — `plugins/plugin-audit/scripts/check-no-verdict-injection.py` 가 이미
주입 표면을 판정 어휘로 스캔한다. 그것을 `shared/` 로 승격해 ㉰ 전체에 건다(치환). 그 파일 헤더가
자기 한계를 적는다: *"grep cannot catch a novel form of verdict injection."* 상속된다.

**면제** — adversarial·refuter 계열은 앞 판정을 반박하는 것이 과업이다. `kind: prior_verdict` 를
선언하고 **락의 상수**에 등재한다(저자 파일이 아니라). **각 면제 항목은 C6 의 두 조건 중 하나를
인용해야 하고, 인용이 없으면 RED** — C4 의 *"특화될 것만 분기"* 를 기계로 만드는 자리가 여기다.

### 4.3 L3 의 공수 (가장 큰 단일 작업)

`plugins/spec-distill/tests/test_seed_agents.sh` 가 프로토타입이지만 일반화 지점이 넷이다 —
`:123`(`for a in seed-critic seed-readback`) · `:154`(`subagent_type` 리터럴) ·
`:101`(`"spec-distill:$1"` 접두사와 ```javascript``` 펜스) · `:2`(`# guards:` 가 SKILL 하나).
그리고 20 에이전트 중 **18은 슬롯 선언 자체가 없다**(산문). 5개 플러그인의 dispatch 표기
(plugin-audit 은 Workflow `agent()`)가 따라온다. **문법 자체는 §14 의 미결이다.**

### 4.4 동시에 편집해야 하는 기존 락

| 락 | 무엇이 깨지나 |
|---|---|
| `test_skill_drop_notice_consumed.sh` | 생산자–소비자 문자열 동일성 — 출력 문면이 바뀌면 RED. **리포에서 그 seam 을 재는 유일한 락이므로 약화 금지**(M9 가 이빨 생존을 잰다) |
| `test_synthesize_artifact_findings.sh:86-241` | `degraded_reason` 닫힌 어휘 4값 |
| `test_synthesize_promoted_findings.sh` | `dropped` 2수준 계수 |
| `reviewing-spec/SKILL.md:116` | merge_review 출력 키 열거 — L2 가 카운트를 실으면 깨진다 |

### 4.5 PR 분할

| PR | 내용 | 근거 |
|---|---|---|
| **PR1** | L1·L2·L3·L4 + T4-2 신설 — **전부 RED 인 채** | 락을 먼저 넣어야 M1 이 증거가 된다. T4-2 도 여기 — stale 이름이 **아직 살아 있을 때** 넣어야 이빨이 증명된다 |
| **PR2** | T4-1(stale 이름 제거) + T1 + T3 + T5 + §4.4 기존 락 갱신 | PR1 의 L1·L2·L4·T4-2 가 GREEN 이 된다 |
| **PR3** | L3 의 18 에이전트 슬롯 규약 + 5 플러그인 dispatch 표기 (§4.3) | L3 GREEN |

**앞 판본의 순서가 뒤집혀 있었다** — PR1 이 stale 이름을 지운 뒤 PR2 가 락을 넣으면 그 락은 도착
즉시 GREEN 이라 이빨을 증명하지 못한다(round 2 리뷰 지적).

**RED 커밋의 처리 — 메커니즘이 아니라 규약임을 밝힌다.** 리포에 CI 가 없고 D6 이 실행자를
제외했으므로 「RED 가 main 에 못 간다」를 **강제하는 것은 없다.** PR1 을 `feature/…` 브랜치를 base
로 하는 stacked PR 로 열고(`docs/git-workflow/pr-process.md` 가 비-main base 를 지원한다), merge
commit 규약상 RED 커밋이 결국 `main` 의 조상이 되는 것은 **받아들인다** — GREEN 인 것은 트리
상태이지 히스토리가 아니다. 이 사실을 숨기지 않는다.

## 5. 작업 T3 — 출력 모양

```
**Findings:** 0 CRITICAL / 3 IMPORTANT / 5 SUGGESTION
**처분:** 수용 8 · 기각 7 · 억제 2 · 흡수 4 · 미판정 1     ← 상태별, 차단 아님
**배관 손실:** 3 (차단 아님)                                ← 합계. 차단은 blocks() 가 정한다
```

| 칸 | 들어가는 것 | 차단 |
|---|---|---|
| **처분** | `accepted` · `rejected` · `suppressed` · `absorbed` · `held_by_class()["판정자 부재"]` | 아니오 |
| **배관 손실** | `sources_failed` · `held_by_class()["항목 파손"]` · `coerced` | `blocks()` 가 정한다 |

**round 2 리뷰가 고친 것 둘** — ⑴ 앞 판본은 `uncountable` 을 배관 칸에 넣었으나 그것은
`report()["counts"]` 에 **없다**(별 키 `unknown_counts`). 칸에서 뺀다. ⑵ `coerced` 는 `blocks()` 가
읽지 않는다 — 게이트를 바꾸는 강제만 `_degraded()` 의 항이다. 칸에는 싣되 **차단에 기여하지
않는다**는 것이 위 표의 「`blocks()` 가 정한다」의 뜻이다.

**칸의 합계와 차단은 같은 집합이 아니다.** 그 사실을 `(차단 아님)`/`(차단)` 으로 **명시**한다 —
숫자만 내면 「3인데 왜 안 막았나」가 추측이 된다.

## 6. 작업 T4 — stale 이름과 역방향 스캔

`quality-pipeline/SKILL.md:511` 이 `quality-gates:synthesizer` 를 dispatch 하라고 지시한다. 그
에이전트는 없다 — `37ea0d7 refactor(quality-gates): synthesizer agent → script (T3-2, v1.28.0)` 이
정의를 지우고 스크립트로 옮겼다.

| # | 내용 | PR |
|---|---|---|
| **T4-1** | `SKILL.md:511` 정리 | PR2 |
| **T4-2** | *"dispatch 되는 이름은 전부 정의가 있어야 한다"* | PR1 |

**T4-2 는 기존 도출로는 안 된다** (round 2 리뷰). 현행 `NOTATION` 정규식
(`subagent_type:|agentType:|Agent\(|^\s*agent:\s`)은 `:511` 의 **산문** *"Dispatch
\`quality-gates:synthesizer\`"* 를 **아예 매치하지 않는다.** 그래서 T4-2 는 **새 참조 스캐너**를
요구한다 — `<plugin>:<name>` 꼴 토큰을 코퍼스에서 찾아 ㉰ 와 대조. §11 이 금지한 것은 **모집단
도출기**의 신설이고(㉯), 이것은 모집단이 아니라 **참조 스캔**이다. 그 구분을 명시해 둔다.

**미확인** — 이름이 resolve 되지 않을 때의 동작. `smoke-workflow.js:20-22` 의 기록은 **Workflow
층의 `agent()`** 에 대한 것이고 skill 의 `Agent(...)` 도 같은지는 확인되지 않았다. 이 설계는 **어느
쪽도 전제하지 않는다.**

## 7. 작업 T5 — 훅 층 회계

**C13 은 confirmed 제약**이고 *"Phase 0 이 이 세션에 배정한 훅 차단 결정 2곳을 더한다"* 로 포함을
명시한다. 저자가 지울 수 없다.

| # | 자리 | 내용 |
|---|---|---|
| T5-1 | `review-dispatch.py:599` (`decision:"block"` — 구조 검증 실패) | 차단 사실과 사유를 원장 어휘로 기록 |
| T5-2 | `review-dispatch.py:752` (`decision:"block"` — 다음 턴 dispatch 강제) | 같음 |

**sink (F3 이 실측)** — 영속 채널은 `write_state_file()`(`:198-201`, `reviewing-spec` 이 읽는 그
파일), 사용자 채널은 `with_advisory()` 의 `systemMessage`(`:360-381`). 그 파일 자신이
*"exit 0 의 stderr 는 사용자에게 전달되지 않는다"*(`:631-632`)고 적어 두 채널을 쓴다.
**`additionalContext` 는 쓰지 않는다** — brief OQ26 의 폭주 실측이 그 채널에 대한 것이다.

**측정** — 훅이 `adjudication` 을 import 하는 순간 ㉮(글롭에 `hooks/*.py` 포함, §2)에 들어와 **L1 이
자동으로 검사한다.** 앞 판본은 훅이 모든 도출 밖이라 T5 를 재는 것이 없었다(round 2 리뷰 block).

**도달 가능성** — `plugins/spec-distill/scripts/adjudication.py` 심볼릭 링크가 있고
`review-dispatch.py:52-53` 이 `SCRIPTS_DIR` 을 `sys.path` 에 넣는다(round 2 리뷰가 확인). P5 는
통과가 예상되지만 착수 시 실행으로 확인한다.

**OQ23 파급** — 형제 세션이 `:752` 의 목적지 리터럴을 데이터로 빼내면 무엇이 강제되는지가
변수가 된다. T5-2 는 그 값을 **리터럴로 키잉하지 않고** 훅이 실제로 쓴 값을 그대로 싣는다.

## 8. 제외 범위와 근거

**각 행은 C6 의 두 조건 중 하나를 인용한다** — ⑴ 대응물이 원리적으로 없음 ⑵ 측정된 이유
(기존에 기록된 설계 이유 포함). 인용 없는 제외는 C4 위반이다.

| 제외 | C6 | 근거 |
|---|---|---|
| codex 스키마 둘의 통일 | **⑵** | 합치면 hard crash / false-clean. `shared/codex/runner_common.sh:11-35` 가 코드 주석으로 명시 |
| `degradedEvents`(ⓒ) | **⑵** | JS 는 개념의 대응물을 이미 갖췄고 없는 것은 심볼릭 링크다 — 언어/배포 사유. **판정자가 둘로 남는다**(§13) |
| 자동 실행자 신설 (D6) | **⑵** | 사용자 결정. 결과 — 락은 `/qg` 가 고르거나 사람이 돌릴 때만 발화 |
| cross-family 를 계약이 요구하기 | **⑵** | C14 가 별도 축으로 확정 |
| `surfaced()` 배선 | **⑴** | `items="closed"` 에서 빈 리스트 — 살리려면 그 합성기의 fail-closed 방향을 뒤집어야 한다(별개 행동 변경) |
| `quality-pipeline/SKILL.md:488`(Tier C) | **⑴** | 프롬프트 리터럴이 파일에 없어 무엇이 실리는지 **셀 수 없다.** 침묵을 clean 으로 읽지 않고 §13 이월 |
| **C3 의 역할 재배치** | **⑵** | brief C3 이 축을 「프레이밍을 보느냐」로 **교체**했고, 이 설계는 그 축을 L3(b)로 구현한다. 「누가 1차 재비판을 하는가」의 재배치는 그 축이 참인지에 의존하는데 **brief 의 방향성 지적 13건이 그 축을 열어 둔 채다**(§13) — 미해소 근거 위에 배치를 바꾸지 않는다 |

## 9. 착수 전 선결 조건

| # | 확인 | 통과 조건 |
|---|---|---|
| P1 | `check_seed.py` + `test_seed_one_sentence.sh` 가 L3 와 충돌하는가 | **충돌해도 L3 를 빼지 않는다** — 그 자리만 §8 표에 C6⑵ 로 추가하고 나머지 19 에이전트는 그대로 |
| P2 | F1 을 재실행 + `/scripts/` 후처리 | 7 → 6. `tests/spike/` 가 필터로 빠진다 |
| P3 | L1 의 **정밀 구현**을 F2 코퍼스에 돌린다 | F2 와 같은 5자리를 낸다. 다르면 그 차이를 기록하고 규칙을 조인다 |
| P4 | **기존 락 전량 baseline 캡처** — 선재 RED 목록에 이름과 이유 | M10 의 기준점 |
| P5 | 훅에서 `adjudication` import 실행 확인 | T5 의 전제 |

## 10. 위험

- **대리지표 치환** — §5 의 쪼개기가 구조적 답이다(차단이 안 움직이므로 유인이 없다).
- **락을 만들어도 아무도 안 돌린다** (D6). 다음 사이클 1순위.
- **L3(b)의 grep 한계** — 승격하는 판정기가 스스로 적는다. 새 형태의 주입은 못 잡는다.
- **면제 목록이 자란다** — §4.2 가 C6 인용을 요구하고 M8 이 크기를 잰다.
- **`_normalize_identity` 확장의 폭발 반경** — 형제 `_norm_sev` 의 주석이 과거 사고를 기록한다.
- **§4.4 기존 락의 회귀** — 특히 seam 락. M9 가 이빨 생존을 따로 잰다.
- **정적 검사의 절대 경계** — 이름을 문자열 연결로 쪼개면 이 리포의 dispatch 락도 새 락도 **완전히
  침묵한다**(실측 기록 있음).
- **F2 의 근사** — 프로브의 분기 판정이 근사다. P3 가 정밀 구현으로 재확인한다.

## 11. 기각한 대안

- **기각 — 배선만 하고 락을 안 만든다.** 계산기는 이미 있었는데 §1.3 의 평행 어휘가 그 밖에서
  자랐다.
- **기각 — 새 표식(`# **판정** —` 등)을 요구한다.** 「안 적으면 대상 아님」이 되어
  `plugins/spec-distill/CHANGELOG.md:2347` 의 실제 사건을 재발명한다.
- **기각 — ㉯ 용 도출기를 새로 만든다.** 리포에 이미 두 벌 있고 서로를 대조한다(F1).
- **기각 — ㉯ 도출기를 고쳐 스코프 인자를 넣는다.** 그 파일의 `collect()` 가 확장자 필터를 **의도적으로
  제거**했다고 17줄로 적고 출력이 standing assertion 에 묶여 있다(F1). 후처리 필터로 푼다.
- **기각 — L1 의 대상을 「ledger 를 인자로 받는 함수」로 한다.** 4파일 전부 로컬로 만들어
  `synthesize_artifact_findings.py` 를 통째로 놓친다(F2).
- **기각 — L3(a) 만으로 프레이밍 축을 덮는다.** 선언이 정당화를 대신해 「적으면 통과」가 된다.
- **기각 — `hold` 를 `source_failed` 로 옮긴다.** `blocks()` 가 꺼지고 CLAUDE.md 와 충돌한다.
- **기각 — `surfaced()` 를 아티팩트 합성기에 배선한다.** `items="closed"` 에서 빈 리스트.
- **기각 — presence 락의 코퍼스를 공유 계약 파일까지 넓힌다.** 그 파일이 대신 만족시킨다.
  `shared/tests/presence_corpus.sh:10-20` 이 정본, `:32-40` 이 헬퍼. **absence 는 넓히고 presence 는
  넓히지 않는다.**
- **기각 — 규칙 억제를 `reject` 에 합친다.** D2 가 없애려던 실명이 그 안에서 재발한다.

## 12. 완료 측정

| # | 재는 법 | 통과 조건 |
|---|---|---|
| M1 | PR1 직후 L1–L4 실행 | **전부 RED.** GREEN 인 락이 있으면 **그 락을 재설계한다** — 문서화로 넘기지 않는다 |
| M2 | T1 후 L1·L2 | GREEN |
| M3 | T5 후 L1(㉮ 에 훅 포함) | GREEN. **그리고 M7 의 ㉮ 개수가 4→5** |
| M4 | T4-1 후 T4-2 스캔 | GREEN (직전 PR1 에서 RED 였던 것이 여기서 GREEN 이 된다) |
| M5 | PR3 후 L3 | GREEN |
| M6 | **락별 귀속 변이** — 변이마다 **어느 락이 RED 여야 하는지 미리 적고** 실행 | 지정한 락이 RED. **다른 락도 함께 RED 인 것은 정상**(겹치는 보호). **지정한 락이 GREEN 이면 실패** — 앞 판본의 「아무 락도 RED 가 아니면 실패」는 귀속을 못 한다 |
| M7 | ㉮㉯㉰ 도출 실행 | 5 / 6 / 20. ㉯ 에 `tests/spike/`·`detect_codex.sh`·`runner_common.sh` 가 없다 |
| M8 | L3(b) 면제 목록 | 각 항목이 C6 조건을 **인용**한다. 인용 없는 항목 0 |
| M9 | **seam 락의 이빨 생존** — `test_skill_drop_notice_consumed.sh` 에 변이(소비자 분기 삭제) | RED. 문면을 맞추느라 이빨이 사라지지 않았음을 증명 |
| M10 | 기존 락 전량 | **P4 의 baseline 대비** 신규 RED 0 |
| M11 | 결정론 fixture 로 처분 행렬 — 기각·억제·흡수·미판정·배관 손실 각 1건 이상을 `synthesize_findings.py` 에 직접 먹인다 | §5 의 세 줄이 기대값과 일치. **라이브 `/qg` 에 의존하지 않는다** |
| M12 | 라이브 `/qg` 1회 | 세 줄이 실제로 렌더된다. 숫자는 0이어도 통과 |

**M6 의 전제** — 변이 전에 커밋한다(`git checkout --` 는 HEAD 로 되돌린다).

## 13. 재결정 기록

| 항목 | 앞 판본 | 이 판본 | 근거 |
|---|---|---|---|
| 훅 층 회계 | 제외(`TestNoHooksRemain` 인용) | **포함**(T5) | 그 락은 agent-transparency 자기 훅만 금지. C13 은 confirmed |
| `surfaced()` | 배선 | **제외**(§8, C6⑴) | `items="closed"` 에서 빈 리스트 |
| `hold` 재배치 | `source_failed` 로 | **철회** | `blocks()` 가 꺼진다 |
| L1 대상 규칙 | ledger 를 인자로 받는 함수 | **처분 메서드가 불리는 함수** | F2 — 앞 규칙은 파일 하나를 통째로 놓쳤다 |
| ㉯ 도출 | 도구를 승격/수정해 스코프 | **무수정 + 후처리 필터** | F1 — 그 파일은 standing assertion 에 묶여 있다 |
| T4-2 의 PR | PR2(제거 이후) | **PR1(제거 이전)** | 이후면 도착 즉시 GREEN |
| §5 데이터 경로 | `reasons()` 문자열 | **`held_by_class()` 신설 + `why` 접두 통일** | `reasons()` 는 평면 문자열, `held` 는 int 하나 |

**사용자 판정이 필요한 것** — T5(훅) 신설과 §4.3 의 18 에이전트 작업이 범위를 늘린다. 확정 제약
(C13·C5·C4)을 지킨 결과이지만 공수가 크다. **줄이려면 무엇을 뺄지 사용자가 정해야 한다 — 저자는
못 뺀다.**

### Known gaps — 이월

- **판정자가 둘로 남는다** — ⓒ(JS)가 남아 OQ22 의 drift 쌍 조건이 성립한다.
- **자동 실행자 부재** (D6) · **RED 커밋이 `main` 의 조상이 되는 것**(§4.5).
- **L3(b)의 grep 한계** · **`disclosure=` 채널이 실제로 읽히는지**(정적 검사 밖).
- **축 A⑤ 의 이름과 이빨** — 코드는 7축, 문서는 6축. mutation 검증 0건.
- **`# guards:` 선언의 하한** — 방향 B 가 글롭당 `n > 0`.
- **OQ16 · OQ5 · OQ10 · OQ21** — 이 설계가 답하지 않았다.
- **brief 의 방향성 지적 13건** — 축 교체가 단독 저자 preprint 하나에 기대고, [취함] 논문 둘은 모든
  비판자에게 같은 전체 맥락을 준다. 이 설계는 그 축을 L3(b)로 좁게 흡수해 의존을 줄였지만
  해소하지 않았다. **§8 의 C3 행이 그 미해소를 근거로 역할 재배치를 보류한다.**

## 14. writing-plans 가 정할 미결

이 설계가 **요구만 세우고 형태를 정하지 않은 것**이다. 계획 단계가 각각을 하나의 작업으로 연다.

| # | 무엇 | 왜 여기 있나 |
|---|---|---|
| U1 | **L1 분기 판정의 정밀 구현** — 부모 사슬 추적 · 리스트 컴프리헨션 필터 처리 | F2 는 근사로 5자리를 냈다. 정밀 구현이 같은 값을 내는지는 P3 |
| U2 | **L3 슬롯 선언 문법** — 선택적 슬롯 · 같은 에이전트를 여러 번 부르는 dispatch · 템플릿 · 별칭의 매칭 규칙 | round 2 codex block. §4.3 의 18 에이전트 작업이 이것을 전제한다 |
| U3 | **L4 의 런타임 인터페이스** — 러너의 사전-항목 실패가 원장에 도달하는 경로 | round 2 codex block. L4 는 오늘 「선언이 있는가」까지만 요구한다 |
| U4 | **T4-2 참조 스캐너의 토큰 규칙** — `<plugin>:<name>` 을 산문에서 어떻게 잡을 것인가 | §6. 기존 `NOTATION` 이 산문을 안 잡는다 |
| U5 | **`held_by_class()` 의 시그니처와 접두 규약** | T1-10 |

**이 다섯을 산문으로 미리 정하지 않는 것이 이 판본의 요지다.** 앞 두 판본이 그것을 정했고, 두
리뷰어가 매 라운드 파일을 열어 반증했다.
