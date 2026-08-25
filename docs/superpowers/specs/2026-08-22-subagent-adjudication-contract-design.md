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
`shared/` 는 실행 모듈의 자리이며 배포는 `plugins/*/scripts/` 의 **상대 심볼릭 링크**다
(결정 기록 `2026-08-16-devbrew-weight-reduction-design.md:445-448` — 링크가 기본, 바이트
사본은 잔여). `plugin-dev` 는 이 리포 소유가 아니라 편집할 수 없다.

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
- [14. 요구 → 집행 대조](#14-요구--집행-대조)
- [15. 브리프 열린 질문 대조](#15-브리프-열린-질문-대조)

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

### 2.1 배포 형태 — **상대 심볼릭 링크**(기본을 따른다)

**이 절은 추론이 아니라 결정 기록의 전사다.** 규칙은
`docs/superpowers/specs/2026-08-16-devbrew-weight-reduction-design.md:445-448` 에 표로 이미
확정돼 있다:

| 실현 | 언제 |
|---|---|
| **상대 심볼릭 링크 (기본)** | 배포 지점이 정본 파일 자체를 가리킬 수 있을 때 |
| 바이트 동일 사본 + `copy-of` 마커 (**잔여**) | *"심볼릭 링크를 쓸 수 없을 때(예: 파일이 아니라 문자열 조각을 다른 문서 안에 삽입해야 하는 소비 방식)"* |

그리고 같은 문서 `:764-769` 가 2026-08-17 실측으로 설치 동작을 확정한다 — *"`claude plugin
install` 로 … 플러그인 서브트리를 벗어나는 링크(`shared/` 처럼 캐시에 없는 경로를 가리키는
링크 포함)가 **설치 시점에 실제 파일 내용으로 역참조되어** 캐시 안에 들어간다 … 두 로드
경로 모두에서 배포된 스크립트가 정본의 실제 내용에 도달한다."*

**기록된 「링크 불가」 사유는 하나가 아니라 여럿이고, 그중 어느 것도 이 모듈에 닿지 않는다.**
실측 census (`plugins/*/scripts/`):

| 배포 형태 | 정본 |
|---|---|
| **링크** (3종) | `detect_codex.sh` ×3 · `prompt-preamble.md` ×3 · `codex_findings_to_yaml.py` ×2 |
| **사본** (5종) | `kill_switch_active.py` ×3 · `codex_jsonl.py` ×3 · `codex_prompt_common.py` ×2 · `gc_common.py` ×2 · `runner_common.sh` ×2 |

기록된 사유는 최소 셋이다 — ① `codex_prompt_common.py:38` 의 `Path(__file__).resolve().parent`
형제 데이터 파일 해석(`quality-gates/CHANGELOG.md:261-264`) ② `gc_common.py:2` 의
*"**부분 사본**이므로 파일 전체 동일화는 안 한다"* ③ `kill_switch_active.py:16-19` 의 서술
(위 `:764-769` 실측이 뒤집은 것). `adjudication.py` 는 **형제 경로를 하나도 해석하지 않고**
(순수 회계 클래스, §3.1) 부분 사본도 아니므로 ①②가 닿지 않는다.

⚠ **그러나 이 모듈은 리포 최초의 「import-only `.py` 심볼릭 링크」가 된다.** 위 census 가
말하는 것: 기존 `.py` 링크는 `codex_findings_to_yaml.py` 하나뿐이고 그것은 **exec 되며**
(`:53` 에서 자기 `sys.path` 를 직접 세운다), **import-only `.py` 는 다섯 종이 전부 사본**이다.
문서화된 기본은 링크가 맞지만 **이 범주의 기존 사례는 전원 반대**다 — §12 R10 에 위험으로
기록한다.

따라서 배포는 **상대 심볼릭 링크**이고, 계약은 축 1a(심볼릭 링크 ∀)가 진다.

**근거 규칙**: 배포·집행에 관한 주장은 **결정 기록 또는 실행 관측**을 인용한다. 락 소스의
주석은 근거가 아니다 — 이 리포에는 실측이 이미 뒤집은 믿음을 적어 둔 주석이 실재한다
(예: `kill_switch_active.py:16-19` vs 위 `:764-769`).

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
가 더해질 수 있다(§11 PR0). **각 배포 지점은 정본을 가리키는 상대 심볼릭 링크다**(§2.1).

`# copy-of:` 마커는 **쓰지 않는다** — 그것은 사본 방식의 계약이다. `test_no_new_duplication.sh`
는 링크를 마커 없이 처리한다: 스캐너가 `is_symlink()` 로 링크를 식별해 그 대상 경로를
「마커가 가리키는 경로」와 **동등하게** 같은 면제 술어에 넣는다(그 파일의 머리 주석에
명시). 동일성 자체는 링크라서 **구조적으로 깨질 수 없다** — 별도 바이트 비교가 필요 없고,
축 1a 가 「링크인가 · 존재하는 대상을 가리키는가 · 그 대상이 기대한 정본인가」만 확인한다.

**정본과 링크는 같은 PR(PR1)에 실린다.** 축 1c 의 M6 앵커(`test_copy_of_contract.sh:801-823`)는
*형제 **사본***이 실재하는데 축 1c 집합에 없을 때 발화하는데, **`:809` 가
`[ -L "$pp" ] && continue`** 로 링크를 세지 않는다. 같은 파일 `:799-800` 이 그것을 문장으로도
못 박는다 — *"심볼릭 링크로 배포되는 정본은 형제 **사본**이 아니라서 여기 걸리지 않는다 —
그쪽 계약은 축 1a 가 진다."*

**주의**: 축 1c 에는 소비자 스캔과 무관한 세 번째 앵커(M6)가 있다. 「그 축이 이 정본을 안
본다」는 「그 축이 통과시킨다」가 아니므로, 축을 인용할 때는 그 축의 **모든** 앵커를 본다.

### 3.1 API

```python
L = Ledger(items="open")                  # "open" | "closed" — 앵커의 fail-<open|closed> 와
                                          # 같은 값. 소비자 신원이 아니라 **방향**이 인자다.

L.accept(item)                            # 수용
L.reject(item, why)                       # 기각 — 근거 있는 배제
L.hold(item, why)                         # 보류 — 판정 못 함              → degraded
L.absorbed(item, into)                    # 흡수 — 소실 아님                → degraded 아님
L.coerced(field, frm, to, gate=False)     # 강제 — gate=True 면 계수        → gate 면 degraded
L.source_failed(name, why, primary=True)  # 입력 자체가 죽음. primary=True 는 그 축의
                                          # 유일한 판정자, False 는 다양성 보조(codex 등)
L.uncountable(what, why)                  # 개수를 원리적으로 모름          → degraded

L.report()    # {"counts": {"accepted","rejected","held","absorbed","coerced","sources_failed"},
              #  "degraded": bool, "unknown_counts": [str], "reasons": [str]}
L.surfaced()  # items="open"  → 미판정 항목을 라벨과 함께 포함
              # items="closed" → 제외
L.blocks()    # held > 0 or unknown_counts or 주(主) source_failed — §9.1.
              # degraded 와 **다른 술어**다: 보조 source 실패는 degraded 이되 안 막는다
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

**모듈이 없으면 소비자는 죽는다.** 배포 링크가 빠지면 `from adjudication import Ledger` 가
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
| `<경로>.py` | 결정론 파이썬 소비자 | **그 경로가 추적되는 파일로 실재해야 한다** + **앵커와 같은 플러그인**(축 A⑤) + 축 B 가 그 파일의 import 를 교차확인 |
| `<경로>.js` | 결정론 JS 소비자 | **경로 실재** + **앵커와 같은 플러그인**(축 A⑤) + `disclosure=` 필수 |
| `orchestrator` | 모델이 자기 턴 안에서 처분 | `disclosure=` 필수 |
| `human` | 사용자에게 직접 올림 | `disclosure=` 필수 |

**경로 실재 요구는 빠뜨리면 안 되는 것이다.** 이것이 없으면
`consumer=plugins/x/scripts/없는파일.js · disclosure=아무거나` 가 세 축을 전부 통과한다 —
축 B 는 「그 파일이 import 한다」만 묻고 없는 파일은 순회 대상이 아니며, 축 C 는 리터럴만
보고 경로를 안 본다. 판정: `git ls-files --error-unmatch <경로>` 가 성공해야 한다.
**무는 자리는 축 A④ 이고 분리 mutation 은 M15 다**(§14).

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

**「면제값이 없다」는 축 A 에 대해서만 참이다.**

- **축 A**(앵커 귀속, 1:1)에는 면제값이 없다 — 앵커가 있거나 없고, 하나가 둘을 덮을 수 없다.
- **축 B**(import 교차확인)는 `consumer=` 가 `.py` 인 앵커에만 걸린다. 그러므로
  `orchestrator`/`human`/`.js` 는 **축 B 의 범위 밖**이며, 저자가 값을 그렇게 쓰면 축 B 를
  피한다. 값 자체는 저자가 쓴다.
- **축 C** 가 그 세 값에 대해 남는 요구다: 채널 이름을 대라, 그리고 그 이름이 실재하라.
- **어느 축도 재지 않는 것 하나** — §9.1 은 앵커의 `fail-<open|closed>` 와 모듈의 `items=`
  인자가 **같은 값**이라고 선언하지만, 축 B 는 「그 파일이 `adjudication` 을 import 하는가」
  까지이고 그 인자로 무엇을 넘겼는지는 안 본다. **이 동일성은 미집행 표면이다.** 여기 적지
  않으면 읽는 쪽에는 집행되는 것처럼 보인다 — 목록에서 빠진 면제가 가장 위험한 면제다.

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
   게이트의 allowlist 이며 이 락이 대체하지 않는다.**
   ⚠ **다만 그 파일은 「건드리지 않는다」로 끝나지 않는다.** `check-law2.py` 는 allowlist 만
   갖는 것이 아니라 `audit-workflow.js` 에 대해 **`agent` 토큰이 정확히 N회**(`:224-232`)이고
   **각 occurrence 가 내용-핀된 helper 줄에 있을 것**(`:237-245`)을 단언한다. PR2(§7 #9)와
   PR3(그 파일의 앵커 2줄)이 **둘 다 `audit-workflow.js` 를 편집**하므로, 그 편집은 이 게이트를
   통과해야 한다. 통과 조건이 §5.2 의 「`.js` 앵커는 `//` 주석」 규칙이다.
5. **dispatch 0건인 에이전트는 RED 다.** 죽은 정의이거나 이 락이 모르는 표기이거나 —
   둘 다 고쳐야 할 사실이고, 둘 다 조용히 넘기면 안 된다. 현재 18/18 이 dispatch 를 가지므로
   이 바닥은 실재한다. 면제값을 두지 않는다: 수동 호출 전용 에이전트가 나중에 생기면 그것은
   설계 대화이지 억제값이 아니다.

도출을 **표기 열거에서 출발시키지 않는 이유**: 이 사이클에서 저자가 두 번 물렸다. 첫 번째는
`subagent_type` grep 제안(5표기 중 1개 커버), 두 번째는 설계 중 프로토타입이 표기 ②④를
놓친 것(18 중 16). 열거는 fail-open 이고, 정의 집합에서 출발하면 `0건` 이 답이 되어
누락이 드러난다.

### 5.2 세 축

| 축 | conjunct | 단언 | 적용 대상 | 분리 mutation |
|---|---|---|---|---|
| **A** | **A①** | `앵커 수 == dispatch 수` | 전체 | M14a (앵커 하나 삭제) |
| | **A②** | **위치 규칙(결정론)** — 각 dispatch 줄에 대해, 그 **바로 아래** 40줄 안의 앵커 중 **그 사이에 다른 dispatch 줄이 없는** 것이 정확히 하나 | 전체 | **M14b (앵커를 다른 dispatch 의 창으로 «옮기기» — 총계 18 유지)** |
| | **A③** | 각 dispatch 줄은 **정확히 한 에이전트**에 귀속 | 전체 | M13 (락의 경계 규칙 제거) |
| | **A④** | **서식 + 닫힌 어휘 + 경로 실재** — 값 종류와 무관 | **모든 앵커** | M2 (`fail-sideways`) · M12 (`disclosure=` 삭제) · M15 (없는 `.js` 경로) |
| **B** | **B** | `consumer=` 가 `*.py` 인 앵커: 그 파일이 `adjudication` 을 import 한다 | `.py` 앵커 | M3 · M4 |
| **C** | **C** | `consumer=` 가 `.js`·`orchestrator`·`human` 인 앵커: `disclosure=` 리터럴이 **그 앵커가 사는 파일의 「앵커-제외 본문」**(아래 정의)에 실재한다 | 나머지 앵커 | M11 |

**앵커 «검출»과 «서식 검증»은 두 단계다 — 이것이 명시되지 않으면 A④ 는 한 번도 측정되지
않는다.** 검출 패턴은 느슨하다: `^\s*(\S+\s+)?\*\*처분\*\*\s+—` (주석 접두사 허용). A④ 는
**검출된 앵커**의 서식·닫힌 어휘·경로 실재를 검증한다. 검출을 서식 정규식으로 하면
`fail-sideways` 앵커나 `disclosure=` 없는 앵커가 **아예 검출되지 않아** A①(17 ≠ 18)로 RED 가
나고, M2·M12 는 A④ 의 존재 여부와 무관하게 RED 를 낸다 — 즉 분리하지 못한다.

**「앵커-제외 본문」은 축 C 전용 용어다** — 그 앵커가 사는 **파일 하나**에서 검출된 앵커 줄
전부를 뺀 나머지. §5.1④ 의 「코퍼스」(dispatch 도출용 파일 글롭 집합)와 **다른 것**이므로
같은 단어를 쓰지 않는다. 리포 전역이나 플러그인 전체가 아닌 이유는 §5.2 말미 참조.

**A② 는 「∃ 완전매칭」이 아니라 결정론 배정이다.** *"1:1 매칭이 존재한다"* 는 이분 완전매칭
**존재 명제**여서 배정 규칙이 없으면 구현할 수 없고,
greedy-최근접과 완전매칭은 **창이 겹치는 배치에서 정확히 갈린다** — 이 conjunct 가 존재하는
바로 그 배치다. 위 규칙은 각 dispatch 에 대해 답이 하나로 정해진다.

**코드펜스 안에 dispatch 가 둘 있는 배치의 처리.**
`quality-pipeline/SKILL.md:366`·`:377` 은 `:364-385` **단일 코드펜스 안**이라
`**처분** — …` 를 사이에 넣으면 펜스가 깨진다. 규칙: **펜스 안에서는 그 언어의 주석으로
앵커를 쓴다**(`// **처분** — …`). 락은 앵커를 줄 패턴으로 찾으므로 주석 접두사는 무관하다.
펜스를 쪼개는 것도 허용하지만 기본은 주석이다 — 예제 코드의 형태를 바꾸지 않는 쪽이 낫다.
표기 ④(frontmatter)의 거처 규칙은 아래 별도 항에 그대로 유효하다.

**인접 dispatch 의 귀결 — 앵커는 「삽입」된다.** `plugins/plugin-audit/scripts/audit-workflow.js`
의 `:18`·`:19` 는 **연속한 두 줄**이다. A② 가 「바로 아래 40줄 중 그 사이에 다른 dispatch 가
없는 것」이므로, `:18` 의 자격 구간은 **공집합**이다(`:19` 가 바로 다음 줄이다). 따라서 그
배치는 현상 유지로는 A② 를 만족시킬 수 없고, **앵커를 두 dispatch «사이에 삽입»해야 한다**:

```js
const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:plugin-auditor'})
// **처분** — consumer=plugins/plugin-audit/scripts/assemble-audit-data.py · fail-open
const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:audit-refuter'})
// **처분** — consumer=… · fail-open
```

**`.js` 앵커는 반드시 `//` 주석이어야 한다 — 이것은 취향이 아니라 게이트 요구다.**
`plugins/plugin-audit/scripts/check-law2.py` 의 `strip_js_noise`(`:88-103`)가 못 박는다:
*"the real audit-workflow.js has **ZERO `/` and ZERO `${}` in code** … a bare `/` in code
(not `//` or `/*`) → **BypassError**"*. 앵커의 `consumer=plugins/…/x.py` 값은 `/` 로 가득하다
— 주석 밖에 두면 그 게이트가 **BypassError 로 죽는다**. 주석 안이면 같은 함수가 내용을
공백으로 지우므로 `:224-232` 의 *"identifier `agent` 가 정확히 N회"* 단언과 `:237-245` 의
줄-내용 핀도 흔들리지 않는다.

**A④ 가 없으면 §4.1 의 요구가 집행 자리를 잃는다.** 서식·닫힌 어휘·경로 실재는 §4.1 이
요구하는데, 축 B 는 `.py` 한정이고 축 C 는 `disclosure=` 만 본다. A④ 가 없으면
`consumer=plugins/x/scripts/없는파일.js` + 실재하는 리터럴이 세 축을 그대로 통과한다.
**요구를 산문에 적고 집행 자리를 지정하지 않는 것**이 이 설계가 반복해서 물린 모양이므로,
§14 의 요구→집행 표가 그것을 강제한다.

**축 C 의 코퍼스는 「그 앵커가 사는 파일, 모든 앵커 줄을 제외한 나머지」다.** 리포 전역도
플러그인 전체도 아니다 — 전역이면 예시 리터럴 `degrade 채널` 이 `proceed-gate.md:34-41` 에
이미 있어 축이 다시 vacuous 해진다. 파일 하나로 좁히는 것이 **채널이 그 자리에 실재한다**는
주장과 맞고, M11 도 그 코퍼스 위에서만 구성 가능하다.

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
그 agent 가 자기 처분 규약을 읽는 것은 해롭지 않다.

**이 배치가 A② 의 방향을 결정했다.** 실측: 그 파일의 dispatch 는 **6행**(frontmatter 안),
frontmatter 닫힘은 **9행**, 본문 첫 블록은 **11행**이다 — 앵커가 dispatch 보다 **아래**다.
A② 를 *"바로 **위** 40줄"* 로 쓰면 이 파일에서 qualifying 앵커가 0개가 되어
**PR3 가 배달 즉시 RED** 다. `---` 위에는 아무것도 놓을 수 없으므로 바꿀 쪽은
앵커 거처가 아니라 방향이다. 그래서 A② 는 「바로 **아래**」다 — 다른 세 표기도 전부
dispatch 아래에 앵커를 둘 수 있으므로 이 방향이 넷 모두를 만족시키는 유일한 선택이다.

### 5.3 vacuity 하한

- 에이전트 도출이 0 이면 RED (도출이 깨진 것을 「위반 없음」으로 읽지 않는다)
- dispatch 줄 도출이 0 이면 RED
- **락은 아래 여섯을 전부 인쇄한다** — 인쇄와 단언은 다른 것이므로 나눠 적는다:
  ① 에이전트 수 ② dispatch 줄 수 ③ 앵커 수 ④ **에이전트별 dispatch 수** ⑤ **축별 대상
  수**(B / C) ⑥ `--emit-scanned` 경로. ④⑤ 가 없으면 green-expected mutation(M9·M10)이
  관측할 수치를 잃는다 — 통과가 정답인 단언은 모양만으로 이빨을 판별할 수 없다.
- **`dispatch 줄 수 == 앵커 수` 등식을 단언한다**(축 A①). 구조적 근거가 있다 — 1:1 계약.
  **이 문장은 다른 단언을 배제하지 않는다** — §5.1⑤(에이전트별 dispatch ≥ 1)와 위 두
  vacuity bullet 도 단언이고, 그것들이 M6·M7 의 RED 기제다
- **위 여섯 인쇄값을 단언한다** — 특히 ④에이전트별 dispatch 수와 ⑤축별 대상 수가 **인쇄되는지**.
  M9·M10 은 green-expected 라 인쇄가 사라져도 통과하고 관측 근거만 조용히 증발한다.
  선례 형태: `test_copy_of_contract.sh:916-919` 처럼 누산기를 **루프 밖에서** 초기화하고
  최소치를 단언해, 루프를 통째로 지워도 0 이 남아 RED 가 되게 한다
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
> `**처분** — consumer=<같은 플러그인의 .py|.js 경로|orchestrator|human> · fail-<open|closed> · disclosure=<리터럴>`
> 한 줄을 갖는다. `consumer=` 가 경로면 그 경로는 추적되는 파일로 **실재해야** 하고 **앵커가 사는
> 파일과 같은 플러그인**이어야 한다(설치본에서 다른 플러그인의 스크립트는 도달 불가다).
> `disclosure=` 는 `consumer=` 가 `.py` 경로일 때만 생략한다 — 그때는 그 파일이 회계 모듈을
> 실제로 import 하는지가 대신 검사된다. 그 밖의 소비자에서는 **필수**다. 판정기가 항목을 버리면
> 센다 — 셀 수 없으면 「셀 수 없음」을 낸다(침묵과 0 은 다른 사실이다). 회계는
> `shared/adjudication/` 이 한다.
> **흡수(dedup)와 강제(coercion)는 소실이 아니다** — 계수하되 그 자체로 degrade 는 아니다.
> 다만 **강제가 게이트 판정을 바꾸면**(`gate=True`) degrade 다.
> **공시와 차단은 다른 술어다**: 무엇이 degrade 든 언제나 드러내되, 막는 것은 **항목이
> 소실됐거나 셀 수 없거나 그 축의 주(主) 판정자가 죽었을 때**다 — 모델 다양성 손실은 공시하고 막지 않는다.
> 미판정 항목의 방향은 다음 소비자가 정한다: 기계면 제외, 사람이면 라벨을 붙여 보여준다.

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
        plugins/*/scripts/adjudication.py  (상대 심볼릭 링크 → shared/adjudication/)
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

방향을 `next_consumer` 하나로 정하면 위 잡종을 **표현할 수 없다** —
`human` 이면 `blocks()` 가 항상 `False` 인데 `merge_brief_review.py:274` 는 사람이 다음인데도
막는다. 실측 세 자리를 다시 보면 방향이 **두 개의 서로 다른 대상**에 걸린다:

| 무엇의 방향인가 | 규칙 | 세 자리 대조 |
|---|---|---|
| **항목**(미판정 finding) | 다음이 **기계**(자동 편집)면 `closed`(제외), **사람**이면 `open`(라벨 붙여 표시) | artifact=closed · audit-workflow=open · merge_brief=open |
| **공시**(degrade) | 무엇이 degrade 든 **언제나 드러낸다** | `degraded_reason` · `⚠ degraded N건` 배너 · `advisory[]` — 셋 다 |
| **verdict** | **항목이 소실됐거나 셀 수 없거나 그 축의 주(主) 판정자가 죽었을 때만 막는다.** 보조(모델 다양성) 손실은 공시하되 막지 않는다 | 아래 |

**verdict 규칙이 「degraded 면 언제나」가 아닌 이유** — 실측이 그것을 반증한다:

| 자리 | 관측 | 규칙과 일치 |
|---|---|---|
| `synthesize_artifact_findings.py:252` | `converged = (not degraded) and … and (unadjudicated == 0)` — 미판정 항목이 막는다 | ✓ 항목 소실 → 막음 |
| `merge_review.py:461-465` | codex(**보조**) 실패 → `combined = claude_verdict` = `approved` | ✓ 보조 손실 → 안 막음 |
| `merge_review.py` both-dead | claude(**주**) unrecoverable + codex 사망 → `needs_revise` fail-safe | ✓ 주 판정자 사망 → 막음 |
| `merge_brief_review.py:274` | `escalates = bool(findings) or critic_malformed` — critic(**주**) 파손은 막고 `codex_failed` 단독은 안 막음(`:302` `codex_degraded: true` 인 채 approved) | ✓ 둘 다 |
| `audit-workflow.js` | `degradedEvents` → `render-audit-report.py:76-77` 배너. **막는 게 아니라 드러낸다**(`plugin-audit/README.md:79` 가 "crash 가 아니라"로 명시) | 공시 행에 속함 — verdict 가 없다 |

**배너는 blocking 이 아니다 — 공시다.** 그리고 무조건 `blocks()` 를 구현하면
`test_merge_review.py:130-135`(AC10) · `:144-148` · `:154-158` **세 테스트가 깨진다** —
셋 다 `combined_verdict == "approved"` 와 `codex_degraded == "true"` 를 동시에 단언한다.
**화석이 아니라 계약이다.** 게다가 codex 가 불가인 동안 그 구현은 **모든 라운드를
`needs_revise`** 로 만든다.

그래서 모듈의 인자는 소비자 신원이 아니라 **항목 방향** 하나(`items="open"|"closed"`)이고,
그 값은 앵커의 `fail-<open|closed>` 와 **같은 값**이다. `blocks()` 는 인자를 안 받되
**무조건도 아니다**:

```
blocks()  ==  held > 0  or  len(unknown_counts) > 0  or  any(primary source_failed)
degraded  ==  위 셋 중 하나  or  보조 source_failed  or  coerced(gate=True)
```

**공시(`degraded`)와 차단(`blocks`)이 다른 술어라는 것이 핵심이다** — 셋 다 공시하지만
차단은 일부만 한다. `consumer=` 의 네 값을 `human|machine` 으로 매핑할 필요는 여전히 없다.

`merge_brief_review.py` 는 이제 표현된다: `items="open"` + critic 파손(주) → `blocks()` True,
codex 실패(보조) → `degraded` True 이되 `blocks()` False.

**남는 한계.** 락은 정적 검사라 「사람에게 실제로 보여줬는가」를 재지 못한다. 축 B 는
*모듈을 쓰는가*까지이고 *출력을 렌더하는가*는 아니다(§12 R1).

## 10. 검증 계획

### 10.1 모듈 단위 테스트

`shared/tests/test_adjudication_behavior.sh` — 기존 `test_assert_behavior.sh` 와 같은 자리·형태.

- 7개 메서드 각각이 `counts` 의 올바른 칸을 올린다
- `absorbed` 는 `degraded` 를 올리지 **않는다** (양성 대조: `hold` 는 올린다)
- `coerced(gate=False)` 는 `degraded` 를 올리지 않고 `gate=True` 는 올린다
- `uncountable` 은 `unknown_counts` 에 들어가고 `counts` 의 정수에는 안 들어간다
- **`blocks()` 가 §9.1 의 조건부 규칙과 일치한다** — `held > 0` · `unknown_counts` 비어있지
  않음 · **주(主)** `source_failed` 셋 중 하나면 True. **양성 대조 둘**: (a) 그 셋이 전부
  아니면 False (b) **보조** `source_failed` 만 있으면 `degraded` 는 True 인데 `blocks()` 는
  **False** 다. (b) 가 없으면 이 테스트는 철회된 보편 규칙과 구별되지 않는다
- `surfaced()` 가 `items="open"` 에서 held·uncountable 항목을 포함하고 `"closed"` 에서 제외한다
- **배포 정합성은 이 테스트가 재지 않는다 — 기존 축 1a 가 잰다.** 배포가 상대 심볼릭
  링크이므로(§2.1) `test_copy_of_contract.sh` 축 1a 의 ∀-도미넌스가 「링크인가 · 존재하는
  대상을 가리키는가 · 그 대상이 기대한 정본인가」를 이미 검사하고, 그 축은 자기 mutation 을
  이미 갖고 있다(2026-08-17 라운드 1 리뷰가 실제 링크로 재현해 ∃-구멍을 잡은 기록).
  **여기에 사본용 마커/바이트 단언을 새로 쓰지 않는다** — 링크는 내용을 독립적으로 가질 수
  없으므로 잴 것이 없고, 중복 단언은 두 곳이 갈라질 자리를 만든다

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
| **M11** | `disclosure=` 리터럴을 **그 파일의 앵커 줄 제외 본문에 없는** 문자열로 교체 | 축 C RED | 그 리터럴이 실패 메시지에 등장. ✎ 앵커 줄 제외 규칙이 **없으면 이 mutation 은 구성 자체가 불가능하다** — 교체하는 순간 그 문자열이 앵커 줄에 존재하게 되므로. M11 이 구성 가능하다는 것이 곧 축 C 가 이빨을 가졌다는 증거다 |
| **M12** | 비-`.py` 앵커에서 `disclosure=` 통째 삭제 | **축 A④ RED**(서식) | 서식 위반 메시지 — 축 C 가 아니다. 축 C 는 `disclosure=` 가 **있을 때** 그 리터럴을 본다 |
| **M15** | `consumer=` 를 실재하지 않는 `.js` 경로로 교체(`disclosure=` 는 실재 리터럴 유지) | **축 A④ RED**(경로 실재) | 그 경로가 실패 메시지에 등장. 이 mutation 이 없으면 §4.1 의 경로 실재 요구가 집행되는지 아무도 모른다 |
| **M16** | `consumer=` 를 **어휘 밖 5번째 값**으로 교체(예: `consumer=maybe`, 서식은 유효) | **축 A④ RED**(닫힌 어휘) | 그 값이 실패 메시지에 등장. 검출은 느슨하므로(§5.2) 이 앵커는 **검출되고** A④ 에서 걸린다 — 미검출로 A① RED 가 나면 A④ 를 잰 것이 아니다 |
| **M17** | **락에서 ⑤축별 대상 수 인쇄를 삭제** | **§5.3 인쇄 단언 RED** | 인쇄값 6종 중 ⑤가 없다는 메시지. **M10** 의 관측 근거가 이것이다 |
| **M18** | **락에서 ④에이전트별 dispatch 수 인쇄를 삭제** | **§5.3 인쇄 단언 RED** | 인쇄값 6종 중 ④가 없다는 메시지. **M6·M7·M9** 의 관측 근거가 이것이다. ✎ M17 하나로 여섯 인쇄값을 다 재는 척하면 ④가 사라져도 통과한다 — 인쇄값마다 계측기가 따로 있어야 한다 |
| **M13** | **락 자신의** 경계 규칙(§5.1③)을 제거 | **축 A ③ RED** — `critiquing-artifacts/SKILL.md:194` 가 `adversarial` 과 `artifact-adversarial` **두 에이전트에 동시 귀속** | 그 파일:줄 + 귀속된 에이전트 2개 이름. 「`adversarial` 의 dispatch 줄 삭제」로는 안 된다: 경계 규칙 없이도 `0건` 으로 RED 가 나 **규칙의 유무를 판별하지 못한다**. 그래서 피검자가 아니라 **락 자신**을 변이시킨다 |
| **M14a** | 앵커 하나를 **삭제** | **축 A① RED** — 앵커 17 ≠ dispatch 18 | 두 수 |
| **M14b** | 앵커 하나를 **다른 dispatch 의 창 안으로 옮긴다 — 총계는 18 유지** | **축 A② 단독 RED** — 원래 dispatch **아래** 40줄에 「사이에 다른 dispatch 가 없는」 앵커가 0개, 옮긴 쪽은 2개 | 매칭 실패한 dispatch 의 줄 번호. **A① 만 구현한 락은 이것을 GREEN 으로 통과시킨다** — 그래서 이것이 A② 의 유일한 분리 계측기다. 「앵커 둘을 합치기」로는 안 된다: 총계가 17 ≠ 18 이라 A① 단독으로 RED 가 나 A② 를 분리하지 못한다 |

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
| **PR1** | `shared/adjudication/adjudication.py` 정본 + **배포 지점 상대 심볼릭 링크** + `test_adjudication_behavior.sh` + **`shared/README.md` 디렉토리 표에 5번째 행** | 링크는 축 1c 의 M6 앵커가 세지 않으므로(`:809`) 정본+링크를 한 PR 에 실을 수 있다. 축 1a 가 링크를 즉시 검사한다 |
| **PR2** | 결함 수리 9건 + **앵커가 지목할 모든 `.py` 소비자를 모듈로 전환** + 회귀 테스트 | 소비자가 생기며 축 1c 도 발효. PR3 의 축 B 가 요구할 대상이 전부 이 PR 안에서 충족된다 |
| **PR3** | 앵커 18줄 + `test_dispatch_disposition.sh`(축 A①②③④ · B · C) + mutation M1~M18 | 축 B 의 대상이 PR2 에서 이미 전환됐으므로 단독 GREEN |
| **PR4** | `CLAUDE.md` · `docs/plugin-authoring.md` 문면 | 앞의 것이 실재한 뒤에 문서가 그것을 가리킨다 |

**PR2 의 범위 = 「앵커가 지목할 모든 `.py` 소비자」이지 고정된 숫자가 아니다.** 현재 이름으로
확인된 하한은 5개다 — `merge_review.py` · `merge_brief_review.py` ·
`synthesize_findings.py` · `synthesize_artifact_findings.py` · `check_qa_ledger.py`. 이 중
결함이 있는 것은 둘(#1~#8)이고 나머지 셋은 **이미 카운터를 가진 정상 파일의 기계적 전환**이다.
`plugin-audit` 의 `assemble-audit-data.py`·`check-grounding.py` 가 여기에 더해질 수 있다 —
**전수 목록 확정은 PR0 이며 PR1 보다 앞선다.**

**왜 PR3 가 아니라 PR0 인가.** PR1 이 배포 **링크**를 만드는데, 그 배포 집합은
「PR2 가 전환할 소비자가 사는 모든 플러그인」이다. 목록이 PR3 까지 미정이면 PR1 은 배포처를
추측하게 되고, PR2 가 `plugin-audit` 소비자를 하나라도 전환하는 순간
`plugins/plugin-audit/scripts/adjudication.py` 링크가 없어 그 소비자의 `import` 가
설치본에서 풀리지 않는다. 축 1a 는 **실재하는 링크가 대상을 제대로 가리키는가**를 재지
「있어야 할 링크가 없다」를 도출하지 않으므로, 이 갭은 락이 아니라 **PR0 의 목록**이 막는다.

각 PR 은 건드린 플러그인의 `plugin.json` SemVer bump 와 `CHANGELOG.md` 항목을 포함한다.
`shared/` 는 플러그인이 아니라 bump 대상이 아니지만, 배포 링크를 받는 플러그인은 bump 한다.

## 12. 위험

| | 위험 | 완화 |
|---|---|---|
| R1 | **락이 「모듈을 쓰는가」까지만 재고 「출력을 렌더하는가」는 못 잰다.** `report()` 를 만들고 버려도 GREEN | §10.3 의 결함 회귀가 출력을 직접 본다. 정적 락으로는 여기까지가 한계임을 문면에 적는다 |
| R2 | **`consumer=` 값이 저자 손에 있다.** `.py` 대신 `orchestrator`/`human` 을 쓰면 축 B 를 벗어난다 — 축 C 는 더 약하다 | §4.2 가 이 사실을 명시하고 M10 이 그것을 **측정**한다(§5.3⑤ 가 그 수치를 인쇄). 없앴다고 주장하지 않는다. 값 오용은 사람이 읽는 diff 리뷰가 맡는다. **앵커 줄 제외 규칙(§5.2)이 없으면 축 C 의 이빨은 0 이다** — `disclosure=` 검색이 앵커 줄 자신에 걸린다 |
| R3 | 모듈이 소비자마다 안 맞아 우회가 생긴다 | 모듈은 **회계만** 하고 출력 서식은 안 건드린다(§3.2). 우회가 생기면 그 자체가 설계 결함 신호 |
| R4 | Tier C 외부 6종은 계약 밖 | `quality-pipeline/SKILL.md:706` 이 선택을 **model-owned (lightness)** 로 못 박았다. 계약이 구속하는 것은 선택이 아니라 소비 — 그 소비자는 이 리포 소유다 |
| R5 | 18줄 앵커가 하니스 무게가 된다 | 한 줄씩이다. 다만 앵커 서식 변경은 18곳 재편집이라 서식을 먼저 확정했다 |
| R6 | `# guards:` 선언이 `*.sh` 에서만 읽힌다 | 락이 `*.sh` 이므로 해당 없음. 단 이 사실이 문서화돼 있지 않아 `docs/` 에 죽은 `# guards:` 2건이 실재한다 — 별건 |
| **R7** | **#6 의 잔여는 verdict 의미가 아니라 「findings 폐기」다 — 이 사이클에서 닫지 않는다.** `CHANGELOG.md:1634-1638` 이 실측한 것은 mixed 라운드에서 **findings 전량이 사라지는** 것이다: `merge_review.py:490` 의 `codex_findings if codex_avail else []` 가 원장에서, `build_codex_findings_display`(`:241-242`)가 표시 채널에서 각각 지운다. §7 #6 의 수리(「개수를 advisory 에 포함」)는 **개수만 복원하고 사라진 `severity: high` finding 자체는 복원하지 않는다** | 올바른 수리는 **보존 + 라벨**이다 — 형제 `merge_brief_review.py:175` 가 이미 그 형태(부분적으로 읽히는 지적을 버리지 않는다). 그것은 회계가 아니라 데이터 흐름 변경이라 이 설계 범위 밖이고 별건 원장으로 넘긴다. **남의 테스트를 화석으로 전제하지 말 것** — `test_merge_review.py:130-135`(AC10)·`:144-148`·`:154-158` 은 주석에 근거까지 적힌 **계약**이다. 이 잔여를 verdict 규칙 변경으로 닫으려는 시도는 그 셋을 깨뜨린다 |
| **R8** | **산문 소비 자리들이 실제로 버리는지 미측정.** 정적 읽기로는 「처분을 안 적었다」까지만 안다 | 앵커가 그 자리들에 처분을 *적게* 만든다. 실제 행동 측정은 skill 실행이 필요하며 이 설계에 없다 |
| **R9** | **codex 미실행 — 모델 다양성 0.** 이 설계와 **5라운드 리뷰 전부**가 same-family 다 | 완화 수단 없음. 한도 회복 후 재리뷰가 유일한 경로다. **우선순위 1순위는 §2.1** — 같은 계열 리뷰가 다섯 번 붙어 네 번을 놓친 자리다 |
| **R10** | **이 모듈은 리포 최초의 「import-only `.py` 심볼릭 링크」다.** 문서화된 기본(링크)을 따르지만 **그 범주의 기존 사례 다섯 종이 전원 사본**이다(§2.1 census) | 락 축들을 실제로 대입한 추적으로는 통과한다(축 1a 소속·배포 지점 도출·1b skip·M6 skip·1c ∀). 그러나 **선례가 0인 배포 형태**이므로 PR1 은 링크 생성 직후 `/qg` Runtime gate 를 실제로 돌려 확인하고, RED 가 나면 사본으로 되돌리는 것이 즉시 가능하도록 `# copy-of:` 마커 규약을 §2.1 표에 남겨 둔다 |

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

## 14. 요구 → 집행 대조

**요구를 산문에 적고 집행 자리를 지정하지 않으면 그 요구는 없는 것과 같다.** 그래서 이
문서의 모든 요구는 아래 표에 «무는 자리»와 «그것만 분리해 무너뜨리는 mutation» 두 칸을
갖는다. **빈 칸은 결함이 아니라 정직한 미집행 선언이다** — 빈 칸을 남기지 않으려고 없는
집행을 적는 것이 더 나쁘다. 새 요구를 추가하는 편집은 이 표에 행을 함께 추가한다.

| 요구 (어디에 적혀 있나) | 무는 자리 | 분리 mutation |
|---|---|---|
| 모든 dispatch 에 앵커가 있다 (§4) | 축 A① | M1 · M5 · M14a |
| 앵커 하나가 dispatch 둘을 덮지 못한다 (§5.2) | 축 A② | **M14b** (총계 유지 «옮기기») |
| dispatch 줄은 한 에이전트에만 귀속 (§5.1③) | 축 A③ | **M13** (락 자신을 변이) |
| 앵커 서식 (§4) | 축 A④ | M2 |
| `consumer=` 닫힌 어휘 (§4.1) | 축 A④ | **M16** |
| 앵커 검출과 서식 검증이 2단계 (§5.2) | 축 A④ 가 성립하기 위한 **전제** | M2·M12 가 A④ 를 분리하는지 자체가 이 전제의 계측이다 |
| `consumer=` 경로 실재 (§4.1) | 축 A④ | **M15** |
| 비-`.py` 는 `disclosure=` 필수 (§4.1) | 축 A④ | M12 |
| `disclosure=` 리터럴이 코퍼스에 실재 (§4.1·§5.2) | 축 C | M11 |
| `.py` 소비자가 모듈을 import (§3) | 축 B | M3 · M4 |
| 에이전트별 dispatch ≥ 1 (§5.1⑤) | §5.1⑤ | M6 · M7 |
| 도출 경계 규칙 (§5.1③) | 축 A③ | M13 |
| 배포 링크 정합성 (§3·§2.1) | **기존 축 1a**(`test_copy_of_contract.sh`) — 링크인가 · 대상이 존재하는가 · 그 대상이 기대한 정본인가 | **기존 mutation 이 이름으로 있다**: 2026-08-17 라운드 1 리뷰가 실제 심볼릭 링크로 ∃-구멍을 재현한 기록(그 파일 머리 주석). 이 설계는 새 계측기를 만들지 않는다 |
| §5.3 인쇄값 ⑤(축별 대상 수) | §5.3 인쇄 단언 | **M17** |
| §5.3 인쇄값 ④(에이전트별 dispatch 수) | §5.3 인쇄 단언 | **M18** |
| §5.3 인쇄값 ①②③⑥ | §5.3 인쇄 단언 | **없음 — 분리 계측기 미작성.** ①②③은 vacuity 하한·등식이 간접적으로 의존하고 ⑥(`--emit-scanned`)은 형제 락의 양방향 검사가 읽는다. 직접 계측기는 없다 |
| **§6 문면 두 곳이 §9.1·§4.1 과 일치 (§6)** | **없음 — 미집행** | 없음. PR4 의 사람 리뷰가 유일한 방어 |
| **`shared/README.md` 디렉토리 표가 5축을 반영 (§2)** | **없음 — 미집행** | 없음. 축 0 은 **계약 축 수**만 세고 디렉토리 표는 안 본다(`test_copy_of_contract.sh:287-291`). PR1 의 작업 항목으로 넣되 락은 없다 |
| 접두사 선택적(자기면제 봉쇄) (§5.1②) | 축 A③ 도출 | M9 (green-expected) |
| 흡수·강제를 소실로 세지 않는다 (§1) | 모듈 단위 테스트 (§10.1) | 양성 대조 — `absorbed` 는 degraded 를 안 올리고 `hold` 는 올린다 |
| `blocks()` 의 조건 (§9.1) | 모듈 단위 테스트 (§10.1) | 양성 대조 — 보조 `source_failed` 는 degraded 이되 `blocks()` False |
| **앵커의 `fail-<open\|closed>` 와 모듈 `items=` 가 같은 값 (§9.1)** | **없음 — 미집행** | 없음 (§4.2 에 면제로 명시) |
| **`report()` 를 실제로 렌더한다 (§9.1)** | **없음 — 미집행** | 없음 (§12 R1) |
| **산문 소비 자리가 실제로 버리지 않는다** | **없음 — 정적 검사 불가** | 없음 (§12 R8) |

## 15. 브리프 열린 질문 대조

| OQ | 답 |
|---|---|
| OQ1 어느 하위에 두나 | `shared/adjudication/` — 새 축. 기존 4축은 소비되는 서브시스템 이름 |
| OQ2 배포 형태 | **상대 심볼릭 링크**, `plugins/*/scripts/`. 결정 기록(`2026-08-16-…-design.md:445-448`)의 **기본**이고, 「링크를 쓸 수 없는」 유일한 기록 사례(`P21_PREAMBLE_PATH` 의 형제 데이터 파일 해석)가 이 모듈에 닿지 않는다. 계약은 축 1a 가 진다 |
| OQ3 presence/absence 코퍼스 분리 | **부분 답.** 이 락에 한해서는 해소된다 — 코퍼스가 `plugins/**` 구조 규칙이고 정본이 `shared/` 라 공유 계약 파일이 들어올 자리가 구조적으로 없다. 리포 전역의 구조적 가드 문제는 **미해결**(감사 §8) |
| OQ4 「버린 걸 세는가」를 기계가 어떻게 | **`.py` 소비자는 축 B** 가 경로 실재 + import 를 교차확인한다. 나머지는 **축 C** 가 채널 이름의 실재까지만 잰다(앵커 줄을 제외한 본문에서) — 그 채널이 실제로 *읽히는지*는 못 잰다(§4.2 · R2). 그리고 **축 A 의 1:1 귀속**이 없으면 축 B·C 자체가 앵커 공유로 우회된다(§5.2) |
| OQ5 생성 시점 독자 경로 | `docs/plugin-authoring.md` 가 `plugin-dev` 를 가리키는 직전 한 줄. `plugin-dev` 자체는 외부 vendoring 이라 편집 불가 |
| OQ6 결함을 이 사이클에 고치나 | 고친다 — 9건 전부, PR2. 단 #6 의 잔여는 R7 로 남긴다 |
| OQ7 Tier C 구속 범위 | 소비만. 선택은 model-owned 로 못 박혀 있다 |
| OQ8 잔여 8건 구분 | 도출을 정의 집합(∀18)에서 출발시켜 잔여 개념이 사라졌다 |
| OQ9 죽은 참조 제거 | **별건** — `quality-gates:synthesizer` 는 agent 정의가 없어 ∀18 에 안 들어온다 |
| OQ10 수리 범위 | **사용자가 확정한 것은 8건**이고 #8(`synthesize_findings.py:283-285`)은 설계 중 저자가 추가로 찾은 것이라 **총 9건**. 여기에 사용자가 승인한 「`.py` 소비자 전부 모듈 전환」이 더해진다(§11) |
| OQ11 런타임 seam 재측정 | **미해결** — 방향성 D1. 이 설계는 훅 갈래를 열지 않는다 |
