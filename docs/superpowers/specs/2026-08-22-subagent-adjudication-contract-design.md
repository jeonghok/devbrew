# subagent 판정 계약 — Design

## Handoff Context

- Interview brief: `docs/superpowers/interview/2026-08-22-subagent-adjudication-contract-interview.md`
- Interview audit (방향성 D1~D7 전문 · 커버리지 원장): 같은 디렉토리의 `*.audit.md`
- 착수 시점 HEAD: `ead6835`

## 목차

- [0. 한눈에](#0-한눈에)
- [1. 문제 — 무엇이 실제로 깨져 있나](#1-문제--무엇이-실제로-깨져-있나)
- [2. 접근 — 규정 문서가 아니라 공통 모듈](#2-접근--규정-문서가-아니라-공통-모듈)
- [3. 컴포넌트 A — `shared/adjudication/`](#3-컴포넌트-a--sharedadjudication)
- [4. 컴포넌트 B — 처분 앵커](#4-컴포넌트-b--처분-앵커)
- [5. 컴포넌트 C — dispatch 락](#5-컴포넌트-c--dispatch-락)
- [6. 컴포넌트 D — 규정 문면의 거처](#6-컴포넌트-d--규정-문면의-거처)
- [7. 결함 수리 9건](#7-결함-수리-9건)
- [8. 데이터 흐름](#8-데이터-흐름)
- [9. degrade 와 fail 방향](#9-degrade-와-fail-방향)
- [10. 검증 계획](#10-검증-계획)
- [11. PR 분할](#11-pr-분할)
- [12. 위험](#12-위험)
- [13. 기각한 대안](#13-기각한-대안)
- [14. 브리프 열린 질문 대조](#14-브리프-열린-질문-대조)

## 0. 한눈에

**무엇** — subagent 발견의 처분(`수용·기각·보류`)과 **버린 것의 회계**를 `shared/`의 공통
파이썬 모듈로 구현하고, 모든 dispatch 자리가 자기 처분을 기계 판독 가능한 한 줄로 밝히게
하며, 그 두 가지를 락 하나로 묶는다.

**왜 모듈인가** — 규정 문서는 저자가 안 읽으면 끝이다. 소비자가 실제로 `import` 하는 모듈은
빠뜨리면 출력이 안 나온다. 이 리포에서 `tools:` 규정이 지켜지는 유일한 이유가 *런타임이 그
키를 읽어서 누락이 즉시 실제 결과를 낸다*는 것이고, 이 설계는 그 성질을 판정 회계에 부여한다.

**규모** — 모듈 1 · 락 1 · 앵커 18줄 · 결함 수리 9건 · 규정 문면 2곳 흡수. 새 `.md` 정본 없음.

**실측 기준선** (HEAD `ead6835`)

| | |
|---|---|
| 로컬 agent 정의 | **18** (`plugins/*/agents/*.md` frontmatter `name:`) |
| dispatch 줄 | **18** — 4표기 통합 도출, 누락 0 · 거짓양성 0 |
| dispatch 표기 | ①`subagent_type:` ②위치인자 `Agent("ns:name"` ③`agentType:` ④frontmatter `agent:` ⑤산문 rubric(Tier C, 외부 소유 — 범위 밖) |
| 확인된 회계 결함 | **9건** — `merge_review.py` 6 · `synthesize_findings.py` 2 · `audit-workflow.js` 1 |

## 1. 문제 — 무엇이 실제로 깨져 있나

문제는 판정자의 **부재**가 아니라 판정자 **내부의 침묵**이다. 이 리포에서 발견이 소실된
최악의 사고 둘이 판정자가 *있는* 자리에서 났고, "판정자가 있는가"만 묻는 census 는 그 두 곳을
준수로 채점했다.

세 가지를 구별하지 못하는 것이 근본 원인이다:

| | 정의 | 예 |
|---|---|---|
| **소실** | 항목이 사라지고 아무도 세지 않음 | `merge_review.py:85-87` |
| **흡수** | 중복이 흡수처에 귀속 — 소실이 아님 | `audit-workflow.js:606-622` |
| **강제** | 항목이 아니라 값을 대체 | `synthesize_findings.py:124-134` |

"버린 것을 전부 세라"는 요구는 흡수·강제까지 잡아 진짜 신호를 희석한다. 반대로 아무것도
요구하지 않으면 소실이 침묵한다. 계약은 **셋을 구별하는 어휘**여야 한다.

네 번째가 있다. **원리적 미상** — `merge_review.py:180-181` 계열에서 sentinel 이 깨지면
몇 개가 있었는지 알 수 없는 경우가 실재한다. 이때 정직한 출력은 `0` 이 아니라
「셀 수 없음」이다. `0` 은 거짓 clean 이다.

### 1.1 어휘가 네 벌로 갈라져 있다

같은 개념이 소비자마다 다른 이름이다 — 공통 모듈이 없어서다.

| 소비자 | 이름 |
|---|---|
| `synthesize_findings.py` | `dropped_malformed` |
| `synthesize_artifact_findings.py` | `sources_failed` + `unadjudicated` |
| `plugin-audit/scripts/assemble-audit-data.py` | `dropped[]` |
| `plugins/spec-distill/scripts/merge_review.py` | 없음 |

### 1.2 생성 시점 독자에게 규정이 닿지 않는다

저자가 새 dispatch 자리를 만들 때 실제로 읽는 경로를 실측했다:

`docs/plugin-authoring.md`(46줄, dispatch 내용 0) → `plugin-dev:agent-development`
(외부 vendoring, `Law 2`·`adjudicat`·`devbrew` 검색 0건) → 선택적으로 `CLAUDE.md#plugin-shape`.

`CLAUDE.md` 와 `docs/plugin-authoring.md` 에 `shared` 언급 **0회**. agent·skill 파일 생성에
반응하는 훅 **0개**. `plugin-dev` 는 `plugins/` 에 존재하지 않아 **편집 불가**다.

## 2. 접근 — 규정 문서가 아니라 공통 모듈

`shared/` 의 실측 패턴은 **정본 `shared/<축>/<mod>.py` → 배포 `plugins/*/scripts/<mod>.py`
(형제 사본 또는 심볼릭 링크) → 소비 `from <mod> import <fn>`** 이다. 전부 실행 모듈이고
규정 문서는 하나도 없다. 유일한 `.md`(`shared/codex/prompt-preamble.md`)조차 규정이 아니라
스크립트가 읽는 프롬프트 조각이다.

따라서 이 설계는 `shared/` 에 **모듈**을 두고, 규정 문면은 이 리포가 선언한 정책의 소스
(`CLAUDE.md#plugin-shape` + `docs/plugin-authoring.md`, 후자 `:36` 이 명시)에 흡수시킨다.

새 `.md` 정본을 만들지 않으므로 배포·심볼릭 링크 문제가 통째로 사라진다. 이것이 없었다면
아래 셋을 전부 처리해야 했다 (전부 실행으로 확증):

| 배치 후보 | 판정 |
|---|---|
| `plugins/<p>/skills/<s>/references/` | `shared/tests/presence_corpus.sh:36` 이 경로 모양만 보고 `own` → **거짓 GREEN** |
| `plugins/<p>/references/` | 같은 가드가 `foreign` → RED · `test_skill_reference_pointers.sh` orphan RED |
| `scripts/` 밖 어디든 | `test_copy_of_contract.sh:447` *"배포 지점이 0건 도출됐다"* RED |

## 3. 컴포넌트 A — `shared/adjudication/`

**정본**: `shared/adjudication/adjudication.py`
**배포**: `plugins/spec-distill/scripts/adjudication.py` · `plugins/quality-gates/scripts/adjudication.py`
— 형제 사본. 기존 `shared/tests/test_copy_of_contract.sh` **axis 1c(import 형제 사본 ∀)**
가 이미 이 계약을 집행하므로 배포용 새 락은 만들지 않는다.

### 3.1 API

```python
L = Ledger(next_consumer="human")        # "human" | "machine"

L.accept(item)                            # 수용
L.reject(item, why)                       # 기각 — 근거 있는 배제
L.hold(item, why)                         # 보류 — 판정 못 함              → degraded
L.absorbed(item, into)                    # 흡수 — 소실 아님                → degraded 아님
L.coerced(field, frm, to, gate=False)     # 강제 — gate=True 면 계수        → gate 면 degraded
L.source_failed(name, why)                # 입력 자체가 죽음                → degraded
L.uncountable(what, why)                  # 개수를 원리적으로 모름          → degraded

L.report()   # {"counts": {"accepted","rejected","held","absorbed","coerced","sources_failed"},
             #  "degraded": bool, "unknown_counts": [str], "reasons": [str]}
L.blocks()   # next_consumer 에서 결정 — §9
```

`수용·기각·보류` 는 사용자 어휘(브리프 C16)다. 현재 리포는 quality-gates 쪽이
`confirm/downgrade/reject`, spec-distill 쪽이 무명으로 갈라져 있다. 모듈은 **회계 어휘**를
통일하고 각 소비자의 **출력 어휘**는 건드리지 않는다.

### 3.2 모듈이 하지 않는 것

**출력 서식의 권위가 아니다.** 각 소비자는 자기 필드명으로 렌더한다.
`plugins/spec-distill/references/proceed-gate.md:34-37` 이 필드 통일을 명시적으로 거절했고
(*"이 계약이 정하는 것은 «감추지 않는다» 뿐이고, 각 skill 은 자기 degrade 채널을 자기 어휘
절에 이름으로 명시해야 한다"*), 형제 `_norm_sev` 두 개가 **반대 방향**으로 기본값을 잡으면서
각자 근거를 갖고 있다(`synthesize_findings.py:379-391` → `SUGGESTION`,
`synthesize_artifact_findings.py:49-55` → `CRITICAL`). 서식을 통일하면 그 근거를 지운다.

**모듈이 없으면 소비자는 죽는다.** 배포 사본이 빠지면 `from adjudication import Ledger` 가
`ImportError` 로 즉시 실패한다 — fallback 을 두지 않는다. 회계를 조용히 건너뛰고 「깨끗함」을
내는 것이 이 설계가 고치려는 바로 그 실패이므로, degrade 가 아니라 crash 가 맞다.
`test_copy_of_contract.sh` axis 1c 가 배포 누락을 미리 RED 로 잡는다.

**JS 소비자를 덮지 않는다.** `plugin-audit/scripts/audit-workflow.js` 는 이 파이썬 모듈을
import 할 수 없다. 그 결함(§7 #9)은 개별 패치로 남는다.

## 4. 컴포넌트 B — 처분 앵커

모든 dispatch 자리는 창 40줄 안에 다음 한 줄을 갖는다:

```
**처분** — consumer=<경로|human> · fail-<open|closed>
```

예:

```
**처분** — consumer=plugins/spec-distill/scripts/merge_brief_review.py · fail-open
**처분** — consumer=human · fail-open
```

산문이 아니라 **기계 판독 필드**다. 산문 파싱은 깨지고, 깨진 파서는 조용히 통과시킨다.

`consumer=` 가 스크립트 경로면 §5 축 B 가 그 파일을 교차 확인한다. `consumer=human` 이면
다음 소비자가 사람이라는 선언이고 §9 의 fail 방향이 거기서 나온다.

**면제값이 없다.** 앵커는 있거나 없다. `none` 같은 *아무것도 바꾸지 않는 값*이 없으므로
「준수」와 「무판정」이 구별 불가능해지는 실패 양식이 성립하지 않는다.

## 5. 컴포넌트 C — dispatch 락

`shared/tests/test_dispatch_disposition.sh` · `# guards: plugins/**` · `--emit-scanned` 지원.

**실행 지점은 `/qg` Runtime gate 하나다.** 형제 락 둘(`test_copy_of_contract.sh` ·
`test_no_new_duplication.sh`)과 같은 자리이며, 새 실행 지점을 만들지 않는다(무게 감축 설계
C16). 훅을 추가하지 않으므로 새 kill switch 도 없다 — `/qg` 자신의 스위치를 상속한다.

### 5.1 도출

1. `plugins/*/agents/*.md` frontmatter `name:` → 에이전트 집합 (**∀**, 현재 18)
2. 각 에이전트에 대해 4표기 통합 정규식으로 dispatch 줄을 찾는다.
   **접두사는 선택적** (`(<plugin>:)?<name>`) — 저자가 접두사를 빼서 자기를 감사 대상에서
   제외하는 경로를 봉쇄한다. 이 함정은 실제로 물렸던 것이다
   (`plugins/spec-distill/CHANGELOG.md:1197`).
3. 코퍼스는 **구조 규칙**이다: `plugins/*/skills/**` · `plugins/*/commands/**` ·
   `plugins/*/scripts/*.js` · `plugins/*/hooks/**` 중 `.md`·`.js`. `.py` 는 Agent 도구를
   호출할 수 없으므로 코퍼스 밖 — 이름 열거가 아니라 성질이다. 이 규칙이
   `plugin-audit/scripts/check-law2.py` 의 allowlist 리터럴(거짓양성 3건)을 제거한다.
4. **dispatch 0건인 에이전트는 RED 다.** 죽은 정의이거나 이 락이 모르는 표기이거나 —
   둘 다 고쳐야 할 사실이고, 둘 다 조용히 넘기면 안 된다. 현재 18/18 이 dispatch 를 가지므로
   이 바닥은 실재한다. 면제값을 두지 않는다: 수동 호출 전용 에이전트가 나중에 생기면 그것은
   설계 대화이지 억제값이 아니다.

도출을 **표기 열거에서 출발시키지 않는 이유**: 이 인터뷰에서 저자가 두 번 물렸다. 첫 번째는
`subagent_type` grep 제안(5표기 중 1개 커버), 두 번째는 설계 중 프로토타입이 표기 ②④를
놓친 것(18 중 16). 열거는 fail-open 이고, 정의 집합에서 출발하면 `0건` 이 답이 되어
누락이 드러난다.

### 5.2 두 축

| 축 | 단언 | 이빨 |
|---|---|---|
| **A — 앵커 존재 (∀ 지배)** | 모든 dispatch 줄에 대해 창 40줄 안에 앵커가 있다 | 새 dispatch 가 처분 없이 들어오면 RED |
| **B — 소비자 교차확인 (∀)** | `consumer=` 가 `*.py` 인 모든 앵커에 대해, 그 파일이 `adjudication` 을 import 한다 | 앵커가 소비자를 지목해 놓고 그 소비자가 회계를 안 하면 RED |

축 A 는 ∃-존재검사가 아니라 **∀-지배**다. `shared/tests/` 의 선례(`test_web_kill_switch.sh:350-358`)가
∃ 판본에서 실패한 기록을 갖는다 — 가드 하나가 dispatch 열 개를 만족시켰다.

**축 B 가 이 설계의 이빨이다.** 축 A 만 있으면 앵커는 주석 한 줄로 만족된다
(`test_web_kill_switch.sh:54` 가 자기 파일에 이 한계를 적어 뒀다). 축 B 는 앵커가 거짓말을
못 하게 만든다.

### 5.3 vacuity 하한

- 에이전트 도출이 0 이면 RED (도출이 깨진 것을 「위반 없음」으로 읽지 않는다)
- dispatch 줄 도출이 0 이면 RED
- `--emit-scanned` 는 실제로 훑은 경로를 낸다. 선언에서 목록을 도출하면 자기 반복이라
  커버리지 증거가 되지 않는다

### 5.4 구현 함정

`printf "... ${tot}개"` — 변수 뒤에 한글이 바로 붙으면 중괄호 없이는 bash 가 `tot개` 를
변수명으로 읽어 **조용히 빈 값**을 낸다(이 설계 중 실측으로 물림). 중괄호 필수이며 락의
자기 테스트에 이 mutation 을 넣는다.

## 6. 컴포넌트 D — 규정 문면의 거처

새 문서를 만들지 않는다. 두 곳에 흡수한다.

**`CLAUDE.md` → Plugin Shape → 컴포넌트 격리** 아래 항목 하나:

> **subagent 발견은 처분을 밝힌다.** 모든 dispatch 자리는 `**처분** — consumer=<경로|human> ·
> fail-<open|closed>` 한 줄을 갖는다. 판정기가 항목을 버리면 센다 — 셀 수 없으면 「셀 수
> 없음」을 낸다(침묵과 0 은 다른 사실이다). 회계는 `shared/adjudication/` 이 한다.
> **흡수(dedup)와 강제(coercion)는 소실이 아니다** — 계수하되 degrade 가 아니다.
> fail 방향은 다음 소비자가 정한다: 기계면 막고, 사람이면 라벨을 붙여 보여준다.

**`docs/plugin-authoring.md`** — 스타터 트리의 `agents/` 주석 줄과 「단계별 문법 레퍼런스」
사이에 한 줄. 이 문서가 `plugin-dev` 를 가리키는 **직전**에 놓아야 한다 —
`plugin-dev:agent-development` 는 외부 vendoring 이라 편집할 수 없고, 우리가 닿는 마지막
지점이 여기다.

**Non-goal**: 새 P# 원칙 신설. P11 이 이미 adversarial 을 집행 파일로 지명한다 — 흡수가
default 다.

## 7. 결함 수리 9건

| # | 자리 | 성격 | 수리 |
|---|---|---|---|
| 1 | `merge_review.py:85-87` | **소실** — 비-dict 원소를 버리고 `return issues, False` 로 「깨끗함」을 단언 | `hold()` + reason. 형제 `merge_brief_review.py:161-176` 이 이미 가진 형태 |
| 2 | `merge_review.py:180-181` | 사실은 보고(`codex_yaml_malformed`), **개수 미보고** — 그 시점에 `findings` 가 있어 셀 수 있다 | 개수를 advisory 에 포함 |
| 3 | `merge_review.py:279-287` | **소실** — 원장 통째(`except: return []`) + `id` 없는 레코드. `main()` 이 결과를 안 본다. 짝 `_write_history` 는 실패 시 advisory 를 낸다(비대칭) | `source_failed()` + `main()` 이 읽어 advisory |
| 4 | `merge_review.py:263-267` | **강제인데 게이트를 바꿈** — `raised_count 5→0` 이 `>=3` 정체 게이트를 무력화 | `coerced(gate=True)` |
| 5 | `merge_review.py:326-328` | **소실** — `category`·`target_section` 이 둘 다 빈 codex finding 이 원장에 안 들어감 | `hold()` |
| 6 | `merge_review.py:489-490` | 입력 zero 화. 사실은 advisory, 개수 없음 — `CHANGELOG.md:1634-1638` 에 `Known gaps` 로 기록된 연기 | 개수 포함 |
| 7 | `synthesize_findings.py:38-39`·`58-60` | **파일 부재를 「경로 없음」과 구별 못 함** → `dropped=0` → `render()` 공지가 영원히 안 켜짐 | `source_failed()` |
| 8 | `synthesize_findings.py:283-285` | **미판정 finding 을 카운터 없이 keep.** 형제 `synthesize_artifact_findings.py:197` 에는 `unadjudicated += 1` 이 있다 | `hold()` 계수 |
| 9 | `audit-workflow.js:581-594` | codex 갈래가 `unverified=true` 는 세우면서 `degradedEvent` 를 push 하지 않는다. 구조가 같은 Claude 갈래 `:556-559` 는 push 한다 | 1줄 패치 (JS — 모듈 밖) |

**#2 와 #4 는 소실이 아니다.** #2 는 셀 수 있는데 안 세는 것이고 #4 는 게이트를 바꾸는
강제다. 이 구별이 계약의 핵심이므로 수리도 다르게 한다.

## 8. 데이터 흐름

```
plugins/*/agents/*.md  ──(frontmatter name:)──►  락 도출 ∀18
                                                    │
SKILL.md / *.js  ──(4표기 dispatch 줄)──────────────┤ 축 A: 앵커 ∀지배
      │                                             │
      └─ **처분** — consumer=<경로> · fail-<dir> ────┘ 축 B: 그 경로가 import 하는가
                          │
                          ▼
        plugins/*/scripts/adjudication.py  (형제 사본 ← shared/adjudication/)
                          │
        accept/reject/hold/absorbed/coerced/source_failed/uncountable
                          │
                          ▼
                    .report()  ──►  각 소비자가 자기 어휘로 렌더
                    .blocks()  ──►  §9
```

## 9. degrade 와 fail 방향

fail 방향은 저자가 고르는 것이 아니라 **다음 소비자**에서 나온다.

| 다음 소비자 | 미판정 항목 | 근거 |
|---|---|---|
| **기계** (자동 편집) | fail-closed — 제외하고 수렴을 막는다 | `synthesize_artifact_findings.py:245-252` — *"un-adjudicated … must NOT be silently read as 'resolved'"*, `converged = (not degraded) and (crit+imp==0) and (unadjudicated==0)` |
| **사람** | fail-open — 유지하고 `unverified` 라벨을 붙여 보여준다 | `audit-workflow.js:515-518` — *"Killing an honest finding without review is worse than shipping it with a '⚠ 미검증' label."* |

`merge_brief_review.py` 가 둘을 한 파일에서 쪼갠 잡종이다 — **데이터는 fail-open**(부분적으로
읽히는 지적을 버리지 않는다, `:175`), **verdict 는 fail-closed**(`malformed → escalates →
needs_revise`, `:274`). 다음 소비자가 사람이면서 그 사람이 내용과 차단을 둘 다 필요로 하기
때문이다.

`Ledger.blocks()` 는 이 표를 코드로 옮긴 것이다:

- `next_consumer="machine"` → `degraded or held > 0` 이면 `True`
- `next_consumer="human"` → 항상 `False`. 대신 호출자는 `report()` 를 렌더할 의무를 진다

**후자가 이 설계의 정직한 한계다.** 락은 정적 검사라 「사람에게 실제로 보여줬는가」를 재지
못한다. 축 B 는 *모듈을 쓰는가*까지이고 *출력을 렌더하는가*는 아니다. §12 에 위험으로 기록한다.

## 10. 검증 계획

### 10.1 모듈 단위 테스트

`shared/tests/test_adjudication_behavior.sh` — 기존 `test_assert_behavior.sh` 와 같은 자리·형태.

- 7개 메서드 각각이 `counts` 의 올바른 칸을 올린다
- `absorbed` 는 `degraded` 를 올리지 **않는다** (양성 대조: `hold` 는 올린다)
- `coerced(gate=False)` 는 `degraded` 를 올리지 않고 `gate=True` 는 올린다
- `uncountable` 은 `unknown_counts` 에 들어가고 `counts` 의 정수에는 안 들어간다
- `blocks()` 가 `next_consumer` 별로 §9 표와 일치한다

### 10.2 락 mutation (락이 실제로 무는지)

각 mutation 은 RED 를 내야 한다. **양성 대조**로 무변경 트리가 GREEN 인 것을 먼저 확인한다
— 그것 없이는 RED 도 증거가 아니다.

| # | mutation | 기대 |
|---|---|---|
| M1 | 임의 dispatch 자리의 앵커 줄 삭제 | 축 A RED |
| M2 | 앵커의 `fail-open` → `fail-sideways` | 축 A RED |
| M3 | 앵커의 `consumer=` 를 import 하지 않는 파일로 교체 | 축 B RED |
| M4 | `merge_brief_review.py` 의 `import adjudication` 삭제 | 축 B RED |
| M5 | 새 agent 정의 + 앵커 없는 dispatch 추가 | 축 A RED |
| M6 | agent 정의의 `name:` 을 dispatch 와 다르게 변경 | dispatch 0건 보고 |
| M7 | 락의 코퍼스 글롭을 `skills/` 만으로 축소 | vacuity 하한 또는 `--emit-scanned` 커버리지 RED |
| M8 | 락 메시지의 `${tot}` → `$tot` (한글 접미) | 락 자기 테스트 RED |
| M9 | dispatch 에서 접두사 제거(`"spec-reviewer"`) | 여전히 잡힘 (자기면제 봉쇄 확인) |

**mutation 은 삭제 축만 흔들지 않는다** — M2·M3·M6·M9 는 추가·반전·형태변경이다.
`PYTHONDONTWRITEBYTECODE=1` 로 돌린다(같은 길이 변이가 stale `.pyc` 를 못 넘는 함정).

### 10.3 결함 수리 회귀

9건 각각에 fixture 기반 테스트를 붙인다. 형태는 `merge_brief_review.py` 쪽 기존 테스트를
따른다 — 깨진 입력을 먹이고 **출력에 개수가 있는지**를 본다. 「깨끗함」과 바이트 동일한
출력이 나오면 RED.

## 11. PR 분할

| PR | 내용 | 이유 |
|---|---|---|
| **PR1** | `shared/adjudication/` 모듈 + 배포 사본 + `test_adjudication_behavior.sh` | 소비자가 없어도 단독으로 GREEN. 리뷰 표면이 작다 |
| **PR2** | 결함 수리 9건 + 회귀 테스트 | PR1 의 모듈을 첫 적용. 계약과 첫 적용례가 함께 리뷰된다 |
| **PR3** | 앵커 18줄 + `test_dispatch_disposition.sh` + mutation | 락은 앵커가 다 있어야 GREEN 이라 같은 PR |
| **PR4** | `CLAUDE.md` · `docs/plugin-authoring.md` 문면 | 앞의 것이 실재한 뒤에 문서가 그것을 가리킨다 |

각 PR 은 건드린 플러그인의 `plugin.json` SemVer bump 와 `CHANGELOG.md` 항목을 포함한다.
`shared/` 는 플러그인이 아니라 bump 대상이 아니지만, 배포 사본을 받는 플러그인은 bump 한다.

## 12. 위험

| | 위험 | 완화 |
|---|---|---|
| R1 | **락이 「모듈을 쓰는가」까지만 재고 「출력을 렌더하는가」는 못 잰다.** `report()` 를 만들고 버려도 GREEN | §10.3 의 결함 회귀가 출력을 직접 본다. 정적 락으로는 여기까지가 한계임을 문면에 적는다 |
| R2 | 앵커가 주석·죽은 분기로 만족될 수 있다 | 축 B 가 교차 확인. 그래도 `consumer=` 가 import 만 하고 안 쓰는 경우는 남는다 |
| R3 | 모듈이 소비자마다 안 맞아 우회가 생긴다 | 모듈은 **회계만** 하고 출력 서식은 안 건드린다(§3.2). 우회가 생기면 그 자체가 설계 결함 신호 |
| R4 | Tier C 외부 6종은 계약 밖 | `quality-pipeline/SKILL.md:706` 이 선택을 **model-owned (lightness)** 로 못 박았다. 계약이 구속하는 것은 선택이 아니라 소비 — 그 소비자는 이 리포 소유다 |
| R5 | 18줄 앵커가 하니스 무게가 된다 | 한 줄씩이고 면제값이 없다. 다만 앵커 서식 변경은 18곳 재편집이라 서식을 먼저 확정했다 |
| R6 | `# guards:` 선언이 `*.sh` 에서만 읽힌다 | 락이 `*.sh` 이므로 해당 없음. 단 이 사실이 문서화돼 있지 않아 `docs/` 에 죽은 `# guards:` 2건이 실재한다 — 별건 |

## 13. 기각한 대안

| 대안 | 기각 이유 |
|---|---|
| `shared/rules/subagent-findings.md` 정본 신설 | 사용자 정정 — `shared/` 는 공통 **모듈** 자리다. 그리고 배포하면 락 3개와 충돌(§2 표) |
| 통일 필드 스키마 | `proceed-gate.md:34-37` 이 명시적으로 거절. 형제 `_norm_sev` 둘이 반대 방향 기본값을 각자 근거와 함께 가짐 |
| 「버린 것 전부 세기」 | 흡수·강제·원리적 미상 3종을 잡아 신호를 희석 (§1) |
| 새 frontmatter 키 `adjudicated_by:` | 런타임이 안 읽는 키. `none` 다수값이 준수와 무판정을 구별 불가능하게 만든다 |
| 표기법 통일 후 도출 | 5표기 중 3개가 다른 도구 API·다른 계층이거나 model-owned selection 을 파괴해야 통일된다 |
| agent 정의에서 역방향으로 소비자 찾기 | Tier C 외부 6종은 이 리포에 정의가 0개 |
| 소비자 실행 관측 락 (fixture in / stdout out) | 진짜 이빨이지만 소비자 8 중 6만 덮고, 그 6은 이미 카운트를 낸다 — 가장 안 아픈 곳에 가장 비싼 도구. §10.3 의 회귀 테스트가 같은 일을 더 싸게 한다 |
| `test_proceed_gate_adopters.sh` 인스턴스화 | 단언층 전체가 `.md` 표면의 한국어 앵커 grep 이고 구조 가드가 `.py` 경로에 fail-closed RED. 소비자 8/15 가 `.py` |

## 14. 브리프 열린 질문 대조

| OQ | 답 |
|---|---|
| OQ1 어느 하위에 두나 | `shared/adjudication/` — 새 축. 기존 4축은 소비되는 서브시스템 이름 |
| OQ2 배포 형태 | 형제 사본, `plugins/*/scripts/`. 기존 axis 1c 가 집행 |
| OQ3 presence/absence 코퍼스 분리 | **부분 답.** 이 락에 한해서는 해소된다 — 코퍼스가 `plugins/**` 구조 규칙이고 정본이 `shared/` 라 공유 계약 파일이 들어올 자리가 구조적으로 없다. 리포 전역의 구조적 가드 문제는 **미해결**(감사 §8) |
| OQ4 「버린 걸 세는가」를 기계가 어떻게 | 축 B — `consumer=` 가 지목한 파일이 모듈을 import 하는가 |
| OQ5 생성 시점 독자 경로 | `docs/plugin-authoring.md` 가 `plugin-dev` 를 가리키는 직전 한 줄. `plugin-dev` 자체는 외부 vendoring 이라 편집 불가 |
| OQ6 결함을 이 사이클에 고치나 | 고친다 — 9건 전부, PR2 |
| OQ7 Tier C 구속 범위 | 소비만. 선택은 model-owned 로 못 박혀 있다 |
| OQ8 잔여 8건 구분 | 도출을 정의 집합(∀18)에서 출발시켜 잔여 개념이 사라졌다 |
| OQ9 죽은 참조 제거 | **별건** — `quality-gates:synthesizer` 는 agent 정의가 없어 ∀18 에 안 들어온다 |
| OQ10 수리 범위 | **사용자가 확정한 것은 8건**이고 #8(`synthesize_findings.py:283-285`)은 설계 중 저자가 추가로 찾은 것이라 **총 9건**. 「무검증 10곳」은 앵커 18줄이 덮는다 |
| OQ11 런타임 seam 재측정 | **미해결** — 방향성 D1. 이 설계는 훅 갈래를 열지 않는다 |
