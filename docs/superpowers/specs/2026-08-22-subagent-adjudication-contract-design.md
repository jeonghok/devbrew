---
name: subagent-adjudication-contract
type: design
date: 2026-08-22
interview_brief: docs/superpowers/interview/2026-08-22-subagent-adjudication-contract-interview.md
interview_audit: docs/superpowers/interview/2026-08-22-subagent-adjudication-contract-interview.audit.md
next_phase: superpowers:writing-plans
---

# subagent 판정 계약 — Design

> subagent 의 발견이 소비되는 자리마다 「누가 어떻게 처분하는가」가 갈라져 있다. 처분 어휘를
> 공통 모듈로 모으고, 모든 dispatch 자리가 자기 처분을 기계 판독 한 줄로 밝히게 하고, 그 둘을
> 락 하나로 묶는다. **재는 것은 「판정자가 있는가」가 아니라 「판정자가 버린 것을 세는가」다.**

## Handoff Context

> 이 설계를 처음 보는 사람(또는 `/compact` 후 자기 자신)이 30초에 핵심을 잡게 하는 블록.
> 대화 컨텍스트를 가정하지 않는다.

**TL;DR** — `shared/adjudication/adjudication.py` 라는 회계 모듈 하나(`수용·기각·보류` +
흡수·강제·입력실패·원리적 미상), dispatch 자리 18곳에 붙는 기계 판독 앵커 한 줄, 그 둘을
∀ 로 묶는 락 하나(`shared/tests/test_dispatch_disposition.sh`, 축 A/B/C), 그리고 확인된
회계 결함 9건 수리. PR 넷. **새 `.md` 정본은 만들지 않는다** — 규정 문면은 `CLAUDE.md` 와
`docs/plugin-authoring.md` 에 흡수한다.

**이 설계가 서 있는 실측** (HEAD `ead6835`) — agent 정의 18개는 `plugins/*/agents/*.md`
frontmatter `name:` 에서 도출되고, 4표기 통합 정규식이 정확히 18개 dispatch 줄을 낸다
(누락 0 · 거짓양성 0, 프로토타입 실행 확인). 그중 **`.py` 소비자를 갖는 것은 소수**이고
나머지는 orchestrator·human·JS 다 — 이 비대칭이 §5 락의 축을 셋으로 나누는 이유다.
`shared/` 는 실행 모듈의 자리이며 배포는 `plugins/*/scripts/` 형제 사본 + `# copy-of:`
마커다. `plugin-dev` 는 이 리포 소유가 아니라 편집할 수 없다.

**암묵 전제 — 이 문서가 참이라고 가정하고 검증하지 않은 것**
- 산문 소비 자리들이 *실제로* 발견을 버리는지는 skill 을 실행해야 알 수 있어 **미측정**이다.
  정적 읽기로는 「처분을 안 적었다」까지만 안다.
- codex co-review 가 이번 사이클에 실행되지 않았다(계정 한도). **모델 다양성 0** 이며,
  이 리포에서 same-family 공유 맹점의 유일한 backstop 이 빠진 채로 작성·리뷰됐다.

**plan 으로 넘기는 것 (여기서 정하지 않는다)**
- 앵커 18개가 실제로 지목할 `.py` 소비자의 **전수 목록**. 아래 §11 이 하한 5개를 이름으로
  적지만 그것은 하한이며, 목록 확정은 **PR0** — PR1 보다 앞선다(§11).
- 각 dispatch 자리의 `fail-open|closed` 값. §9 의 규칙에서 자리마다 도출한다.
- 락의 창 크기(현재 40) 를 표기별로 다르게 할지 여부 — §5.2 표기 ④ 항 참조.

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

**무엇** — subagent 발견의 처분(`수용·기각·보류`)과 **버린 것의 회계**를 `shared/` 의 공통
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

네 번째가 있다. **원리적 미상** — `merge_review.py:76-83` 의 세 `return None, True` 경로
(sentinel 부재 · `JSONDecodeError` · payload 형태 불일치)가 그것이다. 그 지점에는 `issues`
리스트가 아직 만들어지지도 않았으므로 **몇 개였는지 알 방법이 없다.** 이때 정직한 출력은
`0` 이 아니라 「셀 수 없음」이다. `0` 은 거짓 clean 이다.

**같은 파일의 `:180-181` 은 이 부류가 아니다** — 거기서는 `findings` 가 이미 누적돼 있어
버리는 개수를 셀 수 있다. 세지 않을 뿐이다(§7 #2). 두 자리를 뭉개면 `uncountable()` 이
호출처 없는 API 로 남는다.

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
→ 소비 `from <mod> import <fn>`** 이다. 네 하위축(`codex`·`gc`·`killswitch`·`tests`)은
전부 *소비되는 서브시스템* 또는 테스트 하네스의 이름이다.

### 2.1 배포 형태 — 왜 심볼릭 링크가 아니라 형제 사본인가

`shared/README.md:10` 은 **상대 심볼릭 링크를 기본**으로 규정하고 바이트 사본 + `copy-of:`
마커는 *"링크를 못 쓰는 잔여만"* 이라고 못 박는다. 이 모듈은 그 **잔여 케이스**이며, 근거는
락 자신의 주석에 이미 적혀 있다 — `test_copy_of_contract.sh:441-443`:

> *"다음 저자가 `scripts/<basename>` 로 **exec 되지 않고 import 되는** 정본을 더하면 정확히
> 그 상태가 된다 — 참조 도출은 exec 관례 문자열을 찾기 때문이다."*

축 1a(심볼릭 링크 ∀)의 배포 지점 도출은 `scripts/<basename>` 을 **실행**하는 관례 문자열을
찾는다. 이 모듈은 `import` 로만 소비되므로 그 문자열이 없고, 도출이 0건이 되어 `:447` 이
*"배포 지점이 **0건 도출**됐다 — 이 정본은 아무것도 검사되지 않았다"* 로 RED 를 낸다.
**이 문장이 설계에 없으면 README 의 「기본은 링크」를 읽은 구현자가 그 RED 로 걸어 들어간다.**

**`shared/` 에 마크다운이 없는 것은 아니다.** `shared/README.md` 가 있고 load-bearing 이다
— `test_copy_of_contract.sh:287-291` 의 축 0 이 그 파일의 계약 수 서술을 단언 대상으로 삼는다.
`shared/codex/prompt-preamble.md` 도 있다(스크립트가 읽는 프롬프트 조각). 따라서
*"`shared/` 에는 문서가 없다"* 는 이 설계의 근거가 **아니다.**

새 `.md` 정본을 두지 않는 근거는 둘이고, 순서가 중요하다:

1. **사용자 지목** — `shared/` 는 공통 **모듈**을 두는 자리라는 것이 사용자의 정정이다.
   기존 두 `.md` 는 모듈의 부속(README · 프롬프트 조각)이지 독립 규정이 아니다.
2. **이 규정의 독자가 런타임이 아니라 저자다.** 저자는 설치본이 아니라 리포를 읽는다.
   그래서 배포가 필요 없고, 배포하지 않으므로 아래 셋이 성립 자체를 안 한다.

배포했을 경우 걸렸을 것 (전부 가드 함수 실행으로 확증):

| 배치 후보 | 판정 |
|---|---|
| `plugins/<p>/skills/<s>/references/` | `shared/tests/presence_corpus.sh:36` 이 경로 모양만 보고 `own` → **거짓 GREEN** |
| `plugins/<p>/references/` | 같은 가드가 `foreign` → RED · `test_skill_reference_pointers.sh` orphan RED |
| `scripts/` 밖 어디든 | `test_copy_of_contract.sh:447` *"배포 지점이 0건 도출됐다"* RED |

## 3. 컴포넌트 A — `shared/adjudication/`

**정본**: `shared/adjudication/adjudication.py`
**배포**: **열거가 아니라 도출이다** — 「PR2 가 전환할 `.py` 소비자가 사는 모든 플러그인」의
`scripts/adjudication.py`. 현재 하한으로는 `spec-distill`·`quality-gates` 이고 `plugin-audit`
가 더해질 수 있다(§11 PR0). **형제 사본이며 1행에
`# copy-of: shared/adjudication/adjudication.py` 마커를 갖는다.**
이 마커는 장식이 아니라 `test_no_new_duplication.sh` 의 면제 술어 ②(*"양쪽이 같은 정본을
copy-of 로 가리킨다"*)가 요구하는 것이다. 마커가 없으면 정본과 사본이 20줄 이상 동일 블록으로
잡혀 그 락이 RED 를 낸다. 기존 사본 전부가 같은 형태다(`plugins/spec-distill/scripts/
kill_switch_active.py:1`).

**축 1c 는 PR1 시점에 이 정본을 보지 않는다.** `test_copy_of_contract.sh:753` 의 `CONSUMED_PY`
는 *추적되는 `.py` 가 실제로 import 하는* `shared/*.py` 만 도출한다. 소비자가 아직
없는 PR1 에서 새 정본은 그 집합 밖이고, 따라서 ∀ 계약이 걸리지 않는다. 축 1c 의 보호는
**첫 소비자가 생기는 PR2 부터** 발효한다 — PR1 의 배포 정합성은 §10.1 의 모듈 테스트가
직접 단언한다(§11 참조).

### 3.1 API

```python
L = Ledger(items="open")                  # "open" | "closed" — 앵커의 fail-<open|closed> 와
                                          # 같은 값. 소비자 신원이 아니라 **방향**이 인자다.

L.accept(item)                            # 수용
L.reject(item, why)                       # 기각 — 근거 있는 배제
L.hold(item, why)                         # 보류 — 판정 못 함              → degraded
L.absorbed(item, into)                    # 흡수 — 소실 아님                → degraded 아님
L.coerced(field, frm, to, gate=False)     # 강제 — gate=True 면 계수        → gate 면 degraded
L.source_failed(name, why)                # 입력 자체가 죽음                → degraded
L.uncountable(what, why)                  # 개수를 원리적으로 모름          → degraded

L.report()    # {"counts": {"accepted","rejected","held","absorbed","coerced","sources_failed"},
              #  "degraded": bool, "unknown_counts": [str], "reasons": [str]}
L.surfaced()  # items="open"  → 미판정 항목을 라벨과 함께 포함
              # items="closed" → 제외
L.blocks()    # **degraded 이면 항상 True.** items 값과 무관 — §9
```

`수용·기각·보류` 는 사용자 어휘(브리프 C16)다. 현재 리포는 quality-gates 쪽이
`confirm/downgrade/reject`, spec-distill 쪽이 무명으로 갈라져 있다. 모듈은 **회계 어휘**를
통일하고 각 소비자의 **출력 어휘**는 건드리지 않는다.

`uncountable()` 의 첫 호출처는 `merge_review.py:76-83` 의 세 `return None, True` 경로다
(§1 · §7 #1 주석).

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

**JS 소비자를 덮지 않는다.** `plugin-audit/scripts/audit-workflow.js` 는 이 파이썬 모듈을
import 할 수 없다. 그 결함(§7 #9)은 개별 패치로 남는다.

## 4. 컴포넌트 B — 처분 앵커

모든 dispatch 자리는 창 40줄 안에 다음 한 줄을 갖는다:

```
**처분** — consumer=<값> · fail-<open|closed>[ · disclosure=<리터럴>]
```

### 4.1 `consumer=` 는 닫힌 어휘다

네 값만 유효하고, **그 밖의 값은 RED** 다(자유 서술 금지):

| 값 | 뜻 | 추가 의무 |
|---|---|---|
| `<경로>.py` | 결정론 파이썬 소비자 | **그 경로가 추적되는 파일로 실재해야 한다** + 축 B 가 그 파일의 import 를 교차확인 |
| `<경로>.js` | 결정론 JS 소비자 | **경로 실재** + `disclosure=` 필수 |
| `orchestrator` | 모델이 자기 턴 안에서 처분 | `disclosure=` 필수 |
| `human` | 사용자에게 직접 올림 | `disclosure=` 필수 |

**경로 실재 요구는 빠뜨리면 안 되는 것이다.** 이것이 없으면
`consumer=plugins/x/scripts/없는파일.js · disclosure=아무거나` 가 세 축을 전부 통과한다 —
축 B 는 「그 파일이 import 한다」만 묻고 없는 파일은 순회 대상이 아니며, 축 C 는 리터럴만
보고 경로를 안 본다. 판정: `git ls-files --error-unmatch <경로>` 가 성공해야 한다.

`disclosure=<리터럴>` 은 **그 처분 결과가 어디에 나타나는지를 가리키는 문자열**이며, 축 C 가
그 리터럴이 **모든 앵커 줄을 제외한 본문**에 실재하는지 검사한다(§5.2 — 제외하지 않으면
검색이 앵커 자신에 걸려 축 C 의 이빨이 0 이다). 예: `disclosure=degrade 채널` ·
`disclosure=verification_status` · `disclosure=degradedEvents`.

이 요구는 발명이 아니라 `proceed-gate.md:34-41` 의 것을 그대로 가져온 것이다 —
*"각 skill 은 자기 degrade 채널을 자기 어휘 절에 이름으로 명시해야 한다 …
**채널이 없다는 사실 자체가 degrade 이고 그렇게 출력해야 한다**"*.

예:

```
**처분** — consumer=plugins/spec-distill/scripts/merge_brief_review.py · fail-open
**처분** — consumer=orchestrator · fail-open · disclosure=verification_status
**처분** — consumer=human · fail-open · disclosure=degrade 채널
```

산문이 아니라 **기계 판독 필드**다. 산문 파싱은 깨지고, 깨진 파서는 조용히 통과시킨다.

### 4.2 면제에 대한 정직한 진술

앞선 판본은 *"면제값이 없다"* 라고 썼다. **그것은 축 A 에 대해서만 참이다.**

- **축 A**(앵커 귀속, 1:1)에는 면제값이 없다 — 앵커가 있거나 없고, 하나가 둘을 덮을 수 없다.
- **축 B**(import 교차확인)는 `consumer=` 가 `.py` 인 앵커에만 걸린다. 그러므로
  `orchestrator`/`human`/`.js` 는 **축 B 의 범위 밖**이며, 저자가 값을 그렇게 쓰면 축 B 를
  피한다. 값 자체는 저자가 쓴다.
- **축 C** 가 그 세 값에 대해 남는 요구다: 채널 이름을 대라, 그리고 그 이름이 실재하라.

축 C 는 축 B 보다 약하다. `disclosure=` 리터럴이 파일에 있다는 것이 그 채널이 실제로
읽힌다는 증거는 아니다. **그 한계를 §12 R2 에 위험으로 적고 문면에도 적는다** — 값이
저자 손에 있는 한 축 B 급 이빨은 이 축에서 나오지 않는다. `CHANGELOG.md:1197` 이 기록한
verifier-steerable anchor 실패가 접두사에서 *값* 으로 자리를 옮긴 형태이며, 이 설계는
그것을 없앴다고 주장하지 않고 **어디로 옮겼는지 명시**한다.

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
   (`plugins/spec-distill/CHANGELOG.md:1197-1198`).
3. **경계 규칙은 명시한다.** 이름 집합에 포함 관계가 실재한다 —
   `adversarial` ⊂ `artifact-adversarial`. 표기 ④는 따옴표가 없으므로
   (`agent: agent-transparency:transcript-reader`) 따옴표를 경계로 쓸 수 없다. 규칙:
   이름 앞은 **줄머리 · 공백 · 따옴표 · `:` 중 하나**여야 하고, 뒤는 **따옴표 · 공백 ·
   줄끝 중 하나**여야 한다. `-` 는 경계가 아니다. 이 규칙이 없으면 `adversarial` 의 ∀
   요구가 `artifact-adversarial` 의 줄로 만족되면서 총계는 18 로 남아 「거짓양성 0」이
   검증 불가능해진다.
   ✎ **실측 (양성 + 음성 대조 둘 다)**: 이 경계 규칙을 넣은 도출은 에이전트 18개가 각각
   **정확히 1건**의 dispatch 를 갖는다(`not-exactly-1 = 0`). 그리고 맨 `adversarial` 로
   `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` 를 훑으면 **매치 0** 이다 —
   `artifact-adversarial` 줄을 먹지 않는다. **음성 대조가 없으면 이 규칙은 검증되지 않는다**:
   잘못 먹어도 총계는 18 로 남기 때문이다(§10.2 M13 이 이 대조의 회귀 락).
4. 코퍼스는 **구조 규칙**이다: `plugins/*/skills/**` · `plugins/*/commands/**` ·
   `plugins/*/scripts/*.js` · `plugins/*/hooks/**` 중 `.md`·`.js`. `.py` 는 Agent 도구를
   호출할 수 없으므로 코퍼스 밖 — 이름 열거가 아니라 성질이다.
   ✎ *부수 효과이지 목적이 아님*: 이 규칙 덕에 `plugin-audit/scripts/check-law2.py` 의
   에이전트 이름 리터럴(`CANONICAL_HELPERS`/`CANONICAL_SMOKE` :69-75, `agents=[…]`
   :220-222)이 이 락의 코퍼스에 들어오지 않는다. **그것들은 결함이 아니라 pre-0 Law 2
   게이트의 allowlist 이며 이 락이 대체하지 않는다** — 어느 PR 도 그 파일을 건드리지 않는다.
5. **dispatch 0건인 에이전트는 RED 다.** 죽은 정의이거나 이 락이 모르는 표기이거나 —
   둘 다 고쳐야 할 사실이고, 둘 다 조용히 넘기면 안 된다. 현재 18/18 이 dispatch 를 가지므로
   이 바닥은 실재한다. 면제값을 두지 않는다: 수동 호출 전용 에이전트가 나중에 생기면 그것은
   설계 대화이지 억제값이 아니다.

도출을 **표기 열거에서 출발시키지 않는 이유**: 이 사이클에서 저자가 두 번 물렸다. 첫 번째는
`subagent_type` grep 제안(5표기 중 1개 커버), 두 번째는 설계 중 프로토타입이 표기 ②④를
놓친 것(18 중 16). 열거는 fail-open 이고, 정의 집합에서 출발하면 `0건` 이 답이 되어
누락이 드러난다.

### 5.2 세 축

| 축 | 단언 | 적용 대상 | 이빨 |
|---|---|---|---|
| **A — 앵커 귀속 (1:1)** | ① `앵커 수 == dispatch 수` ② 앵커→dispatch **1:1 매칭**이 존재한다 — 각 앵커는 어떤 dispatch 의 창 40 안이고, **한 앵커는 한 dispatch 에만** 귀속된다 ③ 각 dispatch 줄은 **정확히 한 에이전트**에 귀속된다 | **18/18** | 새 dispatch 가 처분 없이 들어오거나, 앵커 하나로 둘을 덮으려 하면 RED |
| **B — 소비자 교차확인 (∀)** | `consumer=` 가 `*.py` 인 모든 앵커에 대해, 그 경로가 추적 파일로 실재하고 그 파일이 `adjudication` 을 import 한다 | `.py` 값을 쓴 앵커 | 앵커가 소비자를 지목해 놓고 그 소비자가 회계를 안 하면 RED |
| **C — 채널 실재 (∀)** | `consumer=` 가 `.js`·`orchestrator`·`human` 인 모든 앵커에 대해 `disclosure=` 가 있고, 그 리터럴이 **모든 앵커 줄을 제외한 본문**에 실재한다 | 나머지 앵커 | 채널 이름을 안 대거나 가짜 이름을 대면 RED |

**축 A 는 ∀-지배만으로는 부족하다 — 1:1 이어야 한다.** 선례
`plugins/spec-distill/tests/test_web_kill_switch.sh:350-358` 은 ∀ 루프이지만 그 술어가
*"각 dispatch 위 40줄 안에 **가장 가까운** 가드가 있는가"* 라서, **가드 하나가 `[g, g+40]`
구간의 모든 dispatch 를 만족시킨다.** 이 리포의 실제 배치가 정확히 그 형태다 —
`quality-pipeline/SKILL.md:366`·`:377`(11줄) · `conducting-interview/SKILL.md:254`·`:269`(15줄) ·
`audit-workflow.js:18`·`:19`(인접). 앵커를 공유하면 「앵커 18줄」이 집행되지 않을 뿐 아니라,
**축 B·C 가 앵커를 순회하므로 덮인 쪽 dispatch 의 소비자는 한 번도 교차확인되지 않는다** —
거짓 `consumer=` 값을 쓸 필요조차 없이 축 B 를 빠져나가는 경로다. `CHANGELOG.md:1198` 이
기록한 *"가드 하나가 dispatch 열 개를 만족"* 이 40줄 상한만 걸린 채 살아 있었다.
그래서 등식(①)과 1:1 매칭(②)이 **함께** 있어야 한다 — ①만 있으면 앵커 둘이 한 dispatch 를
가리키고 다른 하나가 비는 배치가 통과한다.

**단언 ③ 이 경계 규칙(§5.1③)의 진짜 계측기다.** 경계 규칙이 없으면
`critiquing-artifacts/SKILL.md:194` 한 줄이 `adversarial` 과 `artifact-adversarial` **둘 다**에
귀속되어 이 단언이 RED 를 낸다. 규칙이 있으면 정확히 하나다(§5.1③ 실측).

**축 B 가 가장 센 이빨이지만 전부를 덮지 않는다.** 축 A 만 있으면 앵커는 주석 한 줄로
만족된다(`test_web_kill_switch.sh:54` 가 자기 파일에 이 한계를 적어 뒀다). 축 B 는 앵커가
거짓말을 못 하게 만들지만 `.py` 소비자에만 걸린다. 축 C 는 나머지를 덮되 더 약하다 — §4.2.

**축 C 의 코퍼스에서 앵커 줄을 빼는 것은 선택이 아니라 성립 조건이다.** `disclosure=` 리터럴은
앵커 줄 자신에 적혀 있고 그 앵커는 검색 대상 파일 안에 있다. 제외하지 않으면 저자가 무엇을
쓰든 검색이 **자기 자신에 걸려** 항상 GREEN 이고, 축 C 의 이빨은 0 이다. 이 리포가 이미
이름 붙인 실패(*헤더가 문구를 만족시키면 body 를 삭제해도 GREEN*)와 동형이며, 판정은
**body-unique** 여야 한다.

**표기 ④의 앵커 거처.** `context: fork` skill 의 dispatch 줄은 YAML frontmatter 안에 있고
(`plugins/agent-transparency/skills/briefing-current-state/SKILL.md:6`), `**처분** — …` 는
유효한 YAML 이 아니다. 규칙: **표기 ④의 앵커는 frontmatter 닫힘(`---`) 직후 본문 첫
블록에 둔다.** 그 본문이 fork agent 의 프롬프트 일부가 된다는 부작용은 감수한다 — 한 줄이고,
그 agent 가 자기 처분 규약을 읽는 것은 해롭지 않다. 창 40줄은 이 배치를 수용한다.

### 5.3 vacuity 하한

- 에이전트 도출이 0 이면 RED (도출이 깨진 것을 「위반 없음」으로 읽지 않는다)
- dispatch 줄 도출이 0 이면 RED
- **락은 아래 여섯을 전부 인쇄한다** — 인쇄와 단언은 다른 것이므로 나눠 적는다:
  ① 에이전트 수 ② dispatch 줄 수 ③ 앵커 수 ④ **에이전트별 dispatch 수** ⑤ **축별 대상
  수**(B / C) ⑥ `--emit-scanned` 경로. ④⑤ 가 없으면 green-expected mutation(M9·M10)이
  관측할 수치를 잃는다 — 통과가 정답인 단언은 모양만으로 이빨을 판별할 수 없다.
- **단언은 하나다: `dispatch 줄 수 == 앵커 수`**(축 A ①). 구조적 근거가 있다 — 1:1 계약.
- **`에이전트 수 == dispatch 줄 수` 는 걸지 않는다.** 오늘 18/18 인 것은 에이전트당 dispatch 가
  우연히 하나여서이고, 한 에이전트를 두 skill 에서 부르는 것은 정당한 편집이다. 등식을 걸면
  그 편집에 거짓 RED 가 난다. 코퍼스 축소는 이 등식이 아니라 **에이전트별 0건**(§5.1⑤)이 잡는다
- `--emit-scanned` 는 실제로 훑은 경로를 낸다. 선언에서 목록을 도출하면 자기 반복이라
  커버리지 증거가 되지 않는다

### 5.4 구현 함정

`printf "... ${tot}개"` — 변수 뒤에 한글이 바로 붙으면 중괄호 없이는 bash 가 `tot개` 를
변수명으로 읽어 **조용히 빈 값**을 낸다(이 설계 중 실측으로 물림). 중괄호 필수이며 락의
자기 테스트에 이 mutation 을 넣는다.

## 6. 컴포넌트 D — 규정 문면의 거처

새 문서를 만들지 않는다. 두 곳에 흡수한다.

**`CLAUDE.md` → Plugin Shape → 컴포넌트 격리** 아래 항목 하나:

> **subagent 발견은 처분을 밝힌다.** 모든 dispatch 자리는
> `**처분** — consumer=<경로|orchestrator|human> · fail-<open|closed>[ · disclosure=<리터럴>]`
> 한 줄을 갖는다. 판정기가 항목을 버리면 센다 — 셀 수 없으면 「셀 수 없음」을 낸다(침묵과
> 0 은 다른 사실이다). 회계는 `shared/adjudication/` 이 한다.
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
| 1 | `merge_review.py:85-87` (+ `:76-83`) | **소실** — 비-dict 원소를 버리고 `return issues, False` 로 「깨끗함」을 단언. 같은 함수의 `:76-83` 은 **원리적 미상** | `:85-87` → `hold()`; `:76-83` → `uncountable()`. 형제 `merge_brief_review.py:161-176` 이 이미 가진 형태 |
| 2 | `merge_review.py:180-181` | 사실은 보고(`codex_yaml_malformed`), **개수 미보고** — 그 시점에 `findings` 가 누적돼 있어 셀 수 있다 | 개수를 advisory 에 포함 |
| 3 | `merge_review.py:279-287` | **소실** — 원장 통째(`except: return []`) + `id` 없는 레코드. `main()` 이 결과를 안 본다. 짝 `_write_history` 는 실패 시 advisory 를 낸다(비대칭) | `source_failed()` + `main()` 이 읽어 advisory |
| 4 | `merge_review.py:263-267` | **강제인데 게이트를 바꿈** — `raised_count 5→0` 이 `>=3` 정체 게이트를 무력화 | `coerced(gate=True)` |
| 5 | `merge_review.py:326-328` | **소실** — `category`·`target_section` 이 둘 다 빈 codex finding 이 원장에 안 들어감 | `hold()` |
| 6 | `merge_review.py:489-490` | 입력 zero 화. 사실은 advisory, 개수 없음 — `CHANGELOG.md:1634-1638` 에 `Known gaps` 로 기록된 연기 | 개수 포함. **잔여 있음** — §12 R7 |
| 7 | `synthesize_findings.py:38-39`·`58-60` | **파일 부재를 「경로 없음」과 구별 못 함** → `dropped=0` → `render()` 공지가 영원히 안 켜짐 | `source_failed()` |
| 8 | `synthesize_findings.py:283-285` | **미판정 finding 을 카운터 없이 keep.** 형제 `synthesize_artifact_findings.py:197` 에는 `unadjudicated += 1` 이 있다 | `hold()` 계수 |
| 9 | `audit-workflow.js:581-594` | codex 갈래가 `unverified=true` 는 세우면서 `degradedEvent` 를 push 하지 않는다. 구조가 같은 Claude 갈래 `:556-559` 는 push 한다 | 1줄 패치 (JS — 모듈 밖) |

**#2 와 #4 는 소실이 아니다.** #2 는 셀 수 있는데 안 세는 것이고 #4 는 게이트를 바꾸는
강제다. 이 구별이 계약의 핵심이므로 수리도 다르게 한다.

## 8. 데이터 흐름

```
plugins/*/agents/*.md  ──(frontmatter name:)──►  락 도출 ∀18
                                                    │
SKILL.md / *.js  ──(4표기 dispatch 줄)──────────────┤ 축 A: 앵커 1:1 귀속 (18==18)
      │                                             │
      ├─ consumer=<*.py>  ─────────────────────────►┤ 축 B: 그 파일이 import 하는가
      └─ consumer=orchestrator|human|<*.js>  ──────►┘ 축 C: disclosure 리터럴이 실재하는가
                          │
                          ▼
        plugins/*/scripts/adjudication.py  (형제 사본 + # copy-of: ← shared/adjudication/)
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

### 9.1 방향은 하나가 아니라 둘이다

앞선 판본은 `next_consumer` 하나로 방향을 정했고, 그래서 위 잡종을 **표현할 수 없었다** —
`human` 이면 `blocks()` 가 항상 `False` 인데 `merge_brief_review.py:274` 는 사람이 다음인데도
막는다. 실측 세 자리를 다시 보면 방향이 **두 개의 서로 다른 대상**에 걸린다:

| 무엇의 방향인가 | 규칙 | 세 자리 대조 |
|---|---|---|
| **항목**(미판정 finding) | 다음이 **기계**(자동 편집)면 `closed`(제외), **사람**이면 `open`(라벨 붙여 표시) | artifact=closed · audit-workflow=open · merge_brief=open |
| **verdict** | **degraded 이면 언제나 막는다.** 예외 없음 | `converged` 연언 · `⚠ degraded N건` 배너 · `escalates` — 셋 다 |

그래서 모듈의 인자는 소비자 신원이 아니라 **항목 방향** 하나(`items="open"|"closed"`)이고,
그 값은 앵커의 `fail-<open|closed>` 와 **같은 값**이다. `blocks()` 는 인자를 안 받는다 —
`degraded` 면 True 다. 이렇게 하면 `consumer=` 의 네 값을 `human|machine` 두 값으로
매핑할 필요 자체가 사라진다(그 매핑은 `orchestrator` 에서 답이 없었다).

`merge_brief_review.py` 는 이제 표현된다: `items="open"` + degraded → `blocks()` True.

**남는 한계.** 락은 정적 검사라 「사람에게 실제로 보여줬는가」를 재지 못한다. 축 B 는
*모듈을 쓰는가*까지이고 *출력을 렌더하는가*는 아니다(§12 R1).

## 10. 검증 계획

### 10.1 모듈 단위 테스트

`shared/tests/test_adjudication_behavior.sh` — 기존 `test_assert_behavior.sh` 와 같은 자리·형태.

- 7개 메서드 각각이 `counts` 의 올바른 칸을 올린다
- `absorbed` 는 `degraded` 를 올리지 **않는다** (양성 대조: `hold` 는 올린다)
- `coerced(gate=False)` 는 `degraded` 를 올리지 않고 `gate=True` 는 올린다
- `uncountable` 은 `unknown_counts` 에 들어가고 `counts` 의 정수에는 안 들어간다
- `blocks()` 가 **degraded 이면 항상 True** 다 — `items` 값과 무관(§9.1). 양성 대조:
  degraded 가 아니면 False
- `surfaced()` 가 `items="open"` 에서 held·uncountable 항목을 포함하고 `"closed"` 에서 제외한다
- **배포 정합성 (∀, 도출 집합 위에서)** — PR0 이 확정한 배포 집합의 **모든** 플러그인에
  대해 `plugins/<p>/scripts/adjudication.py` 가 존재하고, 1행 `# copy-of:` 마커가 정본을
  가리키며, 그 줄을 뺀 바이트가 정본과 같다. **실재하는 사본만 순회하면 안 된다** — 그것은
  ∃-검사라 빠진 자리에 침묵한다. 기대 집합을 먼저 도출하고 그 전부를 검사한다.
  PR1 에서 축 1c 가 아직 발효하지 않으므로(§3) 이 단언이 PR1 의 배포 보호다

### 10.2 락 mutation (락이 실제로 무는지)

각 mutation 은 RED 를 내야 한다. **양성 대조**로 무변경 트리가 GREEN 인 것을 먼저 확인한다
— 그것 없이는 RED 도 증거가 아니다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.

| # | mutation | 기대 | 무엇을 관측해 판정하나 |
|---|---|---|---|
| M1 | 임의 dispatch 자리의 앵커 줄 삭제 | 축 A RED | 그 파일:줄이 실패 메시지에 이름으로 등장 |
| M2 | 앵커의 `fail-open` → `fail-sideways` | 축 A RED | 서식 위반 메시지 |
| M3 | `consumer=` 를 import 하지 않는 `.py` 파일로 교체 | 축 B RED | 그 경로가 실패 메시지에 등장 |
| M4 | `merge_brief_review.py` 의 `import adjudication` 삭제 | 축 B RED | 동상 |
| M5 | 새 agent 정의 + 앵커 없는 dispatch 추가 | 축 A RED | 새 이름이 실패 메시지에 등장 |
| M6 | agent 정의의 `name:` 을 dispatch 와 다르게 변경 | **§5.1⑤ dispatch-0건 RED** | 그 에이전트 이름 + `0건` |
| M7 | 코퍼스 글롭을 `skills/` 만으로 축소 | **§5.1⑤ 에이전트별 dispatch 0건 RED.** `scripts/*.js` 3건이 빠져 `plugin-auditor`·`audit-refuter`·`smoke-probe` 가 0건이 된다. 총계 등식이 아니다 — 앵커도 함께 사라져 `dispatch == 앵커` 는 15/15 로 성립하고, vacuity 하한(0)도 발화하지 않는다 | 그 세 에이전트 이름 + `0건` (§5.3④ 가 인쇄) |
| M8 | 락 메시지의 `${tot}` → `$tot` (한글 접미) | 락 자기 테스트 RED | 출력에 빈 문자열 |
| M9 | dispatch 에서 접두사 제거(`"spec-reviewer"`) | **GREEN 이어야 함** (자기면제 봉쇄 확인) | `--emit-scanned` 에 그 파일이 여전히 있고 dispatch 총계가 18 유지 |
| **M10** | `.py` 앵커 하나를 `consumer=human · disclosure=<실재 리터럴>` 로 교체 | **축 B 를 벗어나 축 C 로 이동 — GREEN 이 예상된다.** 이것은 결함이 아니라 §4.2 가 명시한 면제 경로의 **측정**이다 | 축 B 대상 수가 1 줄고 축 C 대상 수가 1 는다 |
| **M11** | `disclosure=` 리터럴을 **앵커 줄을 제외한 본문에 없는** 문자열로 교체 | 축 C RED | 그 리터럴이 실패 메시지에 등장. ✎ 앵커 줄 제외 규칙이 **없으면 이 mutation 은 구성 자체가 불가능하다** — 교체하는 순간 그 문자열이 앵커 줄에 존재하게 되므로. M11 이 구성 가능하다는 것이 곧 축 C 가 이빨을 가졌다는 증거다 |
| **M12** | 비-`.py` 앵커에서 `disclosure=` 통째 삭제 | 축 C RED | 서식 위반 |
| **M13** | **락 자신의** 경계 규칙(§5.1③)을 제거 | **축 A ③ RED** — `critiquing-artifacts/SKILL.md:194` 가 `adversarial` 과 `artifact-adversarial` **두 에이전트에 동시 귀속** | 그 파일:줄 + 귀속된 에이전트 2개 이름. ✎ 이전 판본은 「`adversarial` 의 dispatch 줄 삭제」였는데 그것은 경계 규칙 없이도 `0건` 으로 RED 가 나므로 **규칙의 유무를 판별하지 못했다** |
| **M14** | 인접한 두 dispatch(`quality-pipeline/SKILL.md:366`·`:377`)의 앵커 **둘을 하나로 합침** | **축 A ①② RED** — 앵커 수 17 ≠ dispatch 수 18, 그리고 남은 앵커가 두 dispatch 에 매칭될 수 없다 | 앵커 수 vs dispatch 수 + 매칭 실패한 dispatch 의 줄 번호. ✎ 이 mutation 이 없으면 「1:1」이 ∀-지배와 다르다는 주장이 검증되지 않는다 |

**mutation 은 삭제 축만 흔들지 않는다** — M2·M3·M6·M9·M10·M11·M13·M14 는 추가·반전·형태변경이고,
**M13 은 락 자신을 흔든다**(피검자가 아니라 계측기를 변이시키는 유일한 항목).

M9 와 M10 은 **green-expected** 이므로 통과가 정답이다. 그런 assert 는 모양만으로 이빨을
판별할 수 없으므로 둘 다 관측 대상 수치를 적었고, **그 수치가 §5.3 의 인쇄 요구 ④⑤ 로
실제 산출된다** — 인쇄되지 않는 수치를 관측 근거로 적는 것은 관측하지 않는 것과 같다.

### 10.3 결함 수리 회귀

9건 각각에 fixture 기반 테스트를 붙인다. 형태는 `merge_brief_review.py` 쪽 기존 테스트를
따른다 — 깨진 입력을 먹이고 **출력에 개수가 있는지**를 본다. 「깨끗함」과 바이트 동일한
출력이 나오면 RED.

## 11. PR 분할

| PR | 내용 | 단독 GREEN 근거 |
|---|---|---|
| **PR0** (선결) | **`.py` 소비자 전수 목록 확정** — 앵커 18개를 실제로 초안 작성하며 `consumer=` 값을 도출한다. 코드 변경 없음 | PR1 의 배포 집합과 PR2 의 범위가 **둘 다 이 목록에서 나온다**. 목록 없이 PR1 을 치면 배포처를 추측하게 된다 |
| **PR1** | `shared/adjudication/` 모듈 + 배포 사본(`# copy-of:` 마커) + `test_adjudication_behavior.sh` | 축 1c 는 소비자가 없어 아직 발효하지 않으므로(§3), §10.1 의 **배포 정합성 단언**이 그 자리를 대신한다 |
| **PR2** | 결함 수리 9건 + **앵커가 지목할 모든 `.py` 소비자를 모듈로 전환** + 회귀 테스트 | 소비자가 생기므로 축 1c 발효. PR3 의 축 B 가 요구할 대상이 전부 이 PR 안에서 충족된다 |
| **PR3** | 앵커 18줄 + `test_dispatch_disposition.sh`(축 A/B/C) + mutation M1~M13 | 축 B 의 대상이 PR2 에서 이미 전환됐으므로 단독 GREEN |
| **PR4** | `CLAUDE.md` · `docs/plugin-authoring.md` 문면 | 앞의 것이 실재한 뒤에 문서가 그것을 가리킨다 |

**PR2 의 범위 = 「앵커가 지목할 모든 `.py` 소비자」이지 고정된 숫자가 아니다.** 현재 이름으로
확인된 하한은 5개다 — `merge_review.py` · `merge_brief_review.py` ·
`synthesize_findings.py` · `synthesize_artifact_findings.py` · `check_qa_ledger.py`. 이 중
결함이 있는 것은 둘(#1~#8)이고 나머지 셋은 **이미 카운터를 가진 정상 파일의 기계적 전환**이다.
`plugin-audit` 의 `assemble-audit-data.py`·`check-grounding.py` 가 여기에 더해질 수 있다 —
**전수 목록 확정은 PR0 이며 PR1 보다 앞선다.**

**왜 PR3 가 아니라 PR0 인가.** PR1 이 배포 사본을 만드는데, 그 배포 집합은
「PR2 가 전환할 소비자가 사는 모든 플러그인」이다. 목록이 PR3 까지 미정이면 PR1 은 배포처를
추측하게 되고, PR2 가 `plugin-audit` 소비자를 하나라도 전환하는 순간
`plugins/plugin-audit/scripts/adjudication.py` 형제 사본이 없어 **축 1c 가 RED** 다.
그리고 §10.1 의 배포 정합성 단언은 **실재하는 사본만 순회**하므로 없는 사본을 못 잡는다 —
빠진 자리에 대해 침묵하는 ∃-검사다.

각 PR 은 건드린 플러그인의 `plugin.json` SemVer bump 와 `CHANGELOG.md` 항목을 포함한다.
`shared/` 는 플러그인이 아니라 bump 대상이 아니지만, 배포 사본을 받는 플러그인은 bump 한다.

## 12. 위험

| | 위험 | 완화 |
|---|---|---|
| R1 | **락이 「모듈을 쓰는가」까지만 재고 「출력을 렌더하는가」는 못 잰다.** `report()` 를 만들고 버려도 GREEN | §10.3 의 결함 회귀가 출력을 직접 본다. 정적 락으로는 여기까지가 한계임을 문면에 적는다 |
| R2 | **`consumer=` 값이 저자 손에 있다.** `.py` 대신 `orchestrator`/`human` 을 쓰면 축 B 를 벗어난다 — 축 C 는 더 약하다 | §4.2 가 이 사실을 명시하고 M10 이 그것을 **측정**한다(§5.3⑤ 가 그 수치를 인쇄). 없앴다고 주장하지 않는다. 값 오용은 사람이 읽는 diff 리뷰가 맡는다. ✎ 초판에서는 축 C 의 이빨이 **0** 이었다 — `disclosure=` 검색이 앵커 줄 자신에 걸렸기 때문이며, 앵커 줄 제외 규칙(§5.2)이 그것을 고쳤다 |
| R3 | 모듈이 소비자마다 안 맞아 우회가 생긴다 | 모듈은 **회계만** 하고 출력 서식은 안 건드린다(§3.2). 우회가 생기면 그 자체가 설계 결함 신호 |
| R4 | Tier C 외부 6종은 계약 밖 | `quality-pipeline/SKILL.md:706` 이 선택을 **model-owned (lightness)** 로 못 박았다. 계약이 구속하는 것은 선택이 아니라 소비 — 그 소비자는 이 리포 소유다 |
| R5 | 18줄 앵커가 하니스 무게가 된다 | 한 줄씩이다. 다만 앵커 서식 변경은 18곳 재편집이라 서식을 먼저 확정했다 |
| R6 | `# guards:` 선언이 `*.sh` 에서만 읽힌다 | 락이 `*.sh` 이므로 해당 없음. 단 이 사실이 문서화돼 있지 않아 `docs/` 에 죽은 `# guards:` 2건이 실재한다 — 별건 |
| **R7** | **#6 의 수리가 verdict 의미를 바꾼다 — 범위가 커졌다.** `CHANGELOG.md:1634-1638` 이 실측한 거짓 `approved`(mixed 라운드에서 `severity: high` 소실 + `combined_verdict: approved`)는 §9.1 의 「**verdict 는 degraded 이면 언제나 막는다**」로 **닫힌다** — 소실이 degraded 를 세우고 `blocks()` 가 True 이므로 그 라운드는 `approved` 를 낼 수 없다. 그러나 이것은 회계 추가가 아니라 **shipped 파이프라인의 판정 의미 변경**이다 | 앞선 판본은 이 결함을 「닫지 못한다」고 적고 연기했는데, 그 논거가 §Handoff 가 plan 으로 미룬 미정 값(`next_consumer`)에 기대고 있었다 — §9.1 이 그 값을 없애면서 논거도 사라졌다. 지금 필요한 것은 연기가 아니라 **재검증**이다: `merge_review.py` 의 기존 verdict 테스트가 degraded 라운드에서 `approved` 를 기대하는 곳이 있는지 전수 확인하고, 있으면 그 기대가 이 결함의 화석인지 판정한다. PR2 의 작업 항목으로 명시한다 |
| **R8** | **산문 소비 자리들이 실제로 버리는지 미측정.** 정적 읽기로는 「처분을 안 적었다」까지만 안다 | 앵커가 그 자리들에 처분을 *적게* 만든다. 실제 행동 측정은 skill 실행이 필요하며 이 설계에 없다 |
| **R9** | **codex 미실행 — 모델 다양성 0.** 이 설계와 그 리뷰가 전부 same-family 다 | 완화 수단 없음. 한도 회복 후 재리뷰가 유일한 경로이며 그때까지 이 문서의 공유-맹점 위험은 열려 있다 |

## 13. 기각한 대안

「소비자」의 모집단을 먼저 고정한다 — **dispatch 자리 18곳** 중 결정론 `.py` 소비자를 갖는
것이 하한 5곳, 나머지가 orchestrator·human·JS 다(§11). 아래 표의 수는 전부 이 정의를 쓴다.

| 대안 | 기각 이유 |
|---|---|
| `shared/rules/subagent-findings.md` 정본 신설 | 사용자 정정 — `shared/` 는 공통 **모듈** 자리다. 그리고 이 규정의 독자가 저자라 배포가 필요 없다(§2) |
| 통일 필드 스키마 | `proceed-gate.md:34-37` 이 명시적으로 거절. 형제 `_norm_sev` 둘이 반대 방향 기본값을 각자 근거와 함께 가짐 |
| 「버린 것 전부 세기」 | 흡수·강제·원리적 미상 3종을 잡아 신호를 희석 (§1) |
| 새 frontmatter 키 `adjudicated_by:` | 런타임이 안 읽는 키. `none` 다수값이 준수와 무판정을 구별 불가능하게 만든다 |
| 표기법 통일 후 도출 | 5표기 중 3개가 다른 도구 API·다른 계층이거나 model-owned selection 을 파괴해야 통일된다 |
| agent 정의에서 역방향으로 소비자 찾기 | Tier C 외부 6종은 이 리포에 정의가 0개 |
| 소비자 실행 관측 락 (fixture in / stdout out) | 진짜 이빨이지만 **`.py` 소비자 하한 5곳**만 덮고 그중 셋은 이미 카운트를 낸다 — 가장 안 아픈 곳에 가장 비싼 도구. §10.3 의 회귀 테스트가 같은 일을 더 싸게 한다 |
| `test_proceed_gate_adopters.sh` 인스턴스화 | 단언층 전체가 `.md` 표면의 한국어 앵커 grep 이고 구조 가드가 `.py` 경로에 fail-closed RED. 이 축의 소비자 상당수가 `.py` 라 그대로는 못 쓴다 |

## 14. 브리프 열린 질문 대조

| OQ | 답 |
|---|---|
| OQ1 어느 하위에 두나 | `shared/adjudication/` — 새 축. 기존 4축은 소비되는 서브시스템 이름 |
| OQ2 배포 형태 | 형제 사본 + `# copy-of:` 마커, `plugins/*/scripts/`. 축 1c 는 첫 소비자(PR2)부터 발효 |
| OQ3 presence/absence 코퍼스 분리 | **부분 답.** 이 락에 한해서는 해소된다 — 코퍼스가 `plugins/**` 구조 규칙이고 정본이 `shared/` 라 공유 계약 파일이 들어올 자리가 구조적으로 없다. 리포 전역의 구조적 가드 문제는 **미해결**(감사 §8) |
| OQ4 「버린 걸 세는가」를 기계가 어떻게 | **`.py` 소비자는 축 B** 가 경로 실재 + import 를 교차확인한다. 나머지는 **축 C** 가 채널 이름의 실재까지만 잰다(앵커 줄을 제외한 본문에서) — 그 채널이 실제로 *읽히는지*는 못 잰다(§4.2 · R2). 그리고 **축 A 의 1:1 귀속**이 없으면 축 B·C 자체가 앵커 공유로 우회된다(§5.2) |
| OQ5 생성 시점 독자 경로 | `docs/plugin-authoring.md` 가 `plugin-dev` 를 가리키는 직전 한 줄. `plugin-dev` 자체는 외부 vendoring 이라 편집 불가 |
| OQ6 결함을 이 사이클에 고치나 | 고친다 — 9건 전부, PR2. 단 #6 의 잔여는 R7 로 남긴다 |
| OQ7 Tier C 구속 범위 | 소비만. 선택은 model-owned 로 못 박혀 있다 |
| OQ8 잔여 8건 구분 | 도출을 정의 집합(∀18)에서 출발시켜 잔여 개념이 사라졌다 |
| OQ9 죽은 참조 제거 | **별건** — `quality-gates:synthesizer` 는 agent 정의가 없어 ∀18 에 안 들어온다 |
| OQ10 수리 범위 | **사용자가 확정한 것은 8건**이고 #8(`synthesize_findings.py:283-285`)은 설계 중 저자가 추가로 찾은 것이라 **총 9건**. 여기에 사용자가 승인한 「`.py` 소비자 전부 모듈 전환」이 더해진다(§11) |
| OQ11 런타임 seam 재측정 | **미해결** — 방향성 D1. 이 설계는 훅 갈래를 열지 않는다 |
