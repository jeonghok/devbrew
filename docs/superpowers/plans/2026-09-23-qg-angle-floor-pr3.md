# qg 각도 바닥 구현 계획 (PR3/5)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 로 이 계획을 Task 단위로 실행한다. 단계는 체크박스(`- [ ]`) 표기다.

**Goal:** 세 각도(보안 · 판정 · 다른 전제)의 상태를 **총 함수**로 만들고, 그 총 함수가 `clean` 을 막는 자리와 공시만 하는 자리를 결정론으로 가른다. 명단-리터럴 락을 각도 coverage 락으로 **교체**하고, 공유 재비판자에 `diff` **선택** 슬롯을 연다. 소비자(오케스트레이터) 배선은 PR4 다.

**Architecture:** 새 책임은 새 모듈로 간다 — `scripts/angles.py` 하나가 각도 이름 셋 · 상태 문법 · 총 함수 검증 · 자기-판정 금지(AC10a) · 차단/공시의 분기(AC11·AC12)를 전부 갖는다. **판정 값은 내지 않는다** — 그것은 `verdict.py` 하나가 한다(PR2 가 세운 규칙). `verdict.py` 에는 축이 **하나** 는다(`angle_absent`), `synthesize_findings.py` 에는 **진입 한 줄**(`--angles`, 기본 off)이 는다. off 일 때 stdout 은 PR3 이전과 **바이트 동일**하다 — PR2 가 `--emit-verdict` 로 세운 모양 그대로다. `shared/adjudication/adjudication.py` 의 `Ledger` 는 `blocks()` 가 접고 있던 세 조건 중 둘을 공개 accessor 로 **가른다**(값 동치 리팩터 + 신규 accessor 하나).

**Tech Stack:** Python 3.12+ (표준 라이브러리) · bash 3.2 호환 회귀 락 · `shared/tests/assert.sh`

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.3.1(각도 셋) · §6.3.2(교체 락의 앵커) · §6.3.4(diff 슬롯) · §6.3.5(처분 회계의 기대값 앵커) · §11(AC) · §13(검증) · §15-4(알려진 한계) · §16(분할)

---

## Global Constraints

설계에서 그대로 옮긴다. 모든 Task 의 요구사항에 암묵적으로 포함된다.

- **판정 어휘는 `scripts/verdict.py` 밖에 두지 않는다.** 이 PR 이 새 사유를 «발화»시키지만 그 사유의 이름·우선순위·렌더는 여전히 `verdict.py` 한 파일이 소유한다. `angles.py` 는 `verdict` 를 import 하지 않고, 반대도 아니다 — 둘을 잇는 것은 `synthesize_findings.py` 한 자리다.
- **각도 ≠ 에이전트**(§6.3.1). `angles.py` 는 **수행자 명단을 갖지 않는다.** 각도 이름 셋과 상태 문법만 갖는다. 명단을 넣으면 이 PR 이 지우는 바로 그 락(`test_review_floor_lock.sh`)을 파이썬으로 다시 쓰는 것이다.
- **세 각도의 비대칭은 헌장 그대로다.** 보안·판정의 부재는 **막고**, 「다른 전제」의 부재는 **공시만 한다**(AC11 · AC12). 이 비대칭을 코드에서 지우면 모델 다양성 손실이 게이트가 된다 — 헌장 위반이다.
- **AC10a 는 판정 각도에 한정한다.** 보안 각도는 그 리뷰어가 finding 을 내는 것이 정상이다. 보안에도 걸면 C13 이 허용한 접어 넣기가 사실상 죽는다.
- **`--angles` 없이 부른 `synthesize_findings.py` 의 stdout 은 이 PR 이전과 바이트 동일**하다. 소비자 배선은 PR4 다.
- **fail4 계약은 원자적이다** — 실패 경로에서 stdout 에 아무것도 쓰지 않는다. 판정 «계산» 은 본 보고서를 쓰기 **전**에 끝낸다(PR2 Ruling T5-b).
- **exit 코드 셋** — `0` 정상 · `2` 잘못된 **호출**(usage) · `4` 실패한 **판정**(fail-closed). 둘을 섞지 않는다.
- **선재 RED 기준선은 rc 가 아니라 «실패 파일 이름 + 실패 줄 수»로 잡는다**(§13). 이미 RED 인 파일 «안»의 새 실패는 rc 로 원리적으로 안 보인다.
- **버전 번호는 브랜치에서 정하지 않는다** — 머지 직전에 `origin/main` 을 다시 보고 정한다. 같은 버전 문자열은 충돌 없이 병합되므로 먼저 머지되는 쪽이 이긴다.
- **동반 bump 가 있다** — 이 PR 은 `shared/docreview/` 의 agent 표면을 바꾸므로 `spec-distill` 도 **minor 이상** bump 한다(설계 Metadata).
- **최신화는 merge, rebase 금지.** 세션은 워크트리 격리 — 메인 체크아웃으로 `cd` 금지, bare `git stash` 금지.
- **커밋 트레일러** `Spec:` + `Co-Authored-By:` 는 마지막 `-m` 단락 **하나**에 담는다. 이 PR 의 선언은 `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3` 다 — **PR1·PR2 와 같은 값을 쓰지 않는다**(§16: 같은 값을 쓰면 PR3 가 앞 PR 전부를 합집합으로 재리뷰한다).
- **`PYTHONDONTWRITEBYTECODE=1`** 로 돌린다(같은 길이 변이가 stale `.pyc` 를 못 넘는다). 파이썬 편집마다 `python3 -m py_compile` 로 확인한다.

---

## 이 PR 이 지는 AC

| AC | 내용 | 이 PR 에서 |
|---|---|---|
| **AC10** | 세 각도의 상태가 `filled`/`folded_into:<수행자>`/`absent` 중 하나로 **항상** 산출물에 있다. 하나라도 없으면 스키마 검증 실패 | `angles.parse()` 의 총 함수 + `test_angle_coverage.sh` |
| **AC10a** | **판정 각도**의 `folded_into:<수행자>` 가 그 실행에서 finding 을 낸 리뷰어면 실패. **보안 각도 제외** | `angles.check_self_adjudication()` |
| **AC11** | 보안 또는 판정 각도가 `absent` 인데 판정이 `clean` 이면 실패 | `verdict.decide(angle_absent=…)` 가 구조적으로 `clean` 을 불가능하게 만든다 |
| **AC12** | 「다른 전제」 각도가 `absent` 여도 판정은 막히지 않고 공시만 된다 | `angles.BLOCKING_ANGLES` 가 그 각도를 빼고, `angles.render()` 가 그래도 한 줄을 싣는다 |
| **AC18** | 재비판자의 `diff` 슬롯이 optional 이고, 부재 시 「이 변경이 도입했는가」 축을 쓰지 않는다. 브리프 경로는 diff 를 싣지 않는다 | `shared/docreview/agents/doc-recritic.md` + 바이트 사본 + 슬롯 락 이동 + 두 dispatch 자리 산문 |

**이 PR 이 지지 않는 것** — AC17(탐지 0 재비판 디스패치) · AC22(사본 집합 = 디스패치 집합) · §6.3.4 의 **변환 계층**(`f`↔`finding_id` · `added`→`new_findings` · `raise`/`to` 강제)은 **PR4** 다. 근거는 아래 「계획이 내린 판정」 R-D.

---

## 전제 — PR2 가 main 에 남긴 것 (#166)

**이 계획은 PR2 가 `main` 에 있다는 전제 위에 서 있다.** Task 1 이 그것을 코드로 확증하고, 없으면 **BLOCKED** 로 보고한다.

- `plugins/quality-gates/scripts/verdict.py` — 세 값(`VALUES`) · 11값 닫힌 사유 열거(`REASONS`, 튜플 순서 = 우선순위) · `CAUSE_TO_REASON` 7키 · `LEGACY_VERDICTS`(AC23 블록) · `fail4()` · `read_or_none()` · `decide(*, defect, review_blocked, differential_text, extra_reasons, legacy_verdict)` · `render()` · CLI 0/2/4
- `REASONS` 안에 **`angle-absent` 가 이미 있다** — PR2 가 이름만 넣고 산출자를 안 뒀다. **이 PR 이 그 산출자를 배선한다.**
- `plugins/quality-gates/scripts/synthesize_findings.py` — `import verdict as _verdict` · `--emit-verdict`(기본 off, stdout 바이트 동일) · 판정 입력 플래그 셋(`--differential`·`--reason`·`--legacy-verdict`)이 `--emit-verdict` 없이 오면 **exit 2**
- `plugins/quality-gates/tests/test_verdict_vocabulary.sh` — 34케이스 / 94단언. **이 PR 이 두 자리를 움직인다**(`debt` 문자열 · `AXES:` 단언)
- `plugins/quality-gates/tests/test_resolution_disclosure.sh` — 12단언 (이 PR 은 안 건드린다)

---

## 이월 — 앞 PR 에서 넘어온 것. 이 계획이 이름을 붙인다

| # | 이월 | 이 PR 에서 |
|---|---|---|
| **C1** | PR2 계획문서(`…-pr2.md`)의 부채 목록이 **`kill-switch` 를 빠뜨렸다** — 락의 `debt` 는 다섯인데 계획 산문은 넷을 적고 그중 `kill-switch` 가 빠졌다(AC9) | **닫는다.** 락의 `debt` 리터럴이 기계 검사되는 유일한 정본이고, 이 PR 이 거기서 `angle-absent` 를 지우면 남는 넷은 `trivia · kill-switch · declaration-invalid · merge-conflict` 다. PR2 계획문서는 **고치지 않는다**(R-F) |
| **C2** | `references/runtime-gate.md` 의 절단-안전성 정정이 **완화책 언급을 떨어뜨렸다** — `verdict.causes_of()` 의 「정확히 한 번」이 곧 그 절단 가드다 | **닫는다.** Task 5 가 그 문단에 한 문장을 더한다 |
| **C3** | `blocks()` 의 셋째 조건(주 판정자 사망)이 `findings-lost` 에 접혀 있다 — 가르려면 `Ledger` 에 공개 accessor 가 필요하다(PR2 I2 가 기록한 알려진 편차) | **닫는다.** Task 3 |
| **C4** | `tools/adjudication/check_wiring.py` 의 **줄번호-키 면제**가 `synthesize_findings.py` 360행을 가리킨다 — 이 PR 이 import 를 더하면 밀린다 | **닫는다.** Task 4 가 같은 커밋에서 재앵커한다 |
| **C5** | PR1 이월 셋 — `--sort=refname` 미고정 · `origin/HEAD`/base-remote-ref 전용 락 없음 · §13 수동 e2e | **이 PR 밖이다.** 앞 둘은 PR1 의 `resolve-topic.sh` 소유라 PR4 의 배선이 그것을 실제로 부를 때 값이 생긴다. 수동 e2e 는 §13 이 사이클 전체에 건 것으로 PR5 에서 한 번 돈다 |

---

## PR2 에서 상속한 판정 셋 — 이 PR 이 그대로 따른다

앞 계획이 정했고 사용자가 아직 뒤집지 않은 것. 여기 다시 세워 받는 이유는 이 PR 의 코드가 그것을 **인용**하기 때문이다 — 인용만 있고 원문이 없으면 다음 읽는 쪽이 그 근거를 못 찾는다.

- **R-A** — `expected-empty`(영향분 0개)와 `no-adapters`(어댑터 0개)는 둘 다 `scope-empty` 로 보낸다. 설계가 이름을 주지 않은 자리다.
- **R-B** — `defect` 는 **severity 를 묻지 않는다**. 합성기의 `defect=bool(kept)` 가 그것이다 — 살아남은 finding 이 하나라도 있으면 결함이다.
- **R-C** — `reason:`(단수, 열거 순서상 첫째)과 `reasons:`(전체) **둘 다** 낸다.

---

## 계획이 내린 판정 — 설계 문면을 넘어선 자리 일곱

사용자가 뒤집을 수 있는 자리다. 각 항목은 **무엇을 정했는가 · 왜 · 틀리면 무엇을 치르는가**를 적는다.

### R-D — 사본 · AC17 · AC22 · 변환 계층은 PR4 로 간다 (§16 의 PR3 행을 좁힌다)

**정함.** §16 의 PR3 행은 「… · `doc-critic`/`doc-recritic` 사본 · `shared` diff 슬롯」을 적었다. 이 계획은 **`shared` diff 슬롯만** 받고 **qg 쪽 사본 · 그 dispatch 자리 · AC22 락 · §6.3.4 의 변환 계층 · AC17 을 PR4 로 넘긴다.**

**왜 — 셋이 겹친다.**

1. **§12 가 같은 커밋을 요구한다.** 「`adversarial.md` … SKILL.md 의 dispatch 블록과 **같은 커밋**에서 지운다」. qg 사본의 dispatch 자리는 곧 `adversarial` 이 앉아 있는 그 자리이고, §16 은 SKILL.md 를 PR4 에 두었다. 사본만 PR3 에 두면 §12 를 어기거나 PR3 가 SKILL.md 를 앞당겨 열어야 한다.
2. **§16 의 PR3 행이 자기 근거와 어긋난다.** 사본을 배선하려면 §6.3.4 의 변환 계층(`f`↔`finding_id` 역매핑 · `added`→`new_findings` · `raise`/`to` 강제 계수)과 `adversarial` 락 셋(`test_adversarial_behavior.py` · `test_adversarial_model_consistency.sh` · `test_adversarial_persona.sh`)의 처분이 함께 와야 한다. 여기에 각도 바닥까지 얹으면 §16 이 분할한 이유(「한 PR 에 담으면 리뷰가 실질을 못 본다」)가 이 PR 에서 그대로 재발한다.
3. **AC22 락은 반쪽만으로 이빨이 없다.** 사본만 있고 dispatch 가 없는 상태에서 AC22 락을 세우면 그 락은 자기 대상이 도착하기 한 릴리스 «앞»에 증명서를 붙인 채 선다 — 이 사이클이 이미 두 번 값을 치른 실패 모양이다.

**설계 전제 하나가 측정으로 반증됐다 — 기록한다(P23).** §12 는 「정의만 남으면 `shared/tests/test_dispatch_disposition.sh` 가 「어디서도 dispatch 되지 않는 agent」로 잡는다」고 적었다. `adversarial`(유일한 이름)에는 참이지만 **qg 의 `doc-recritic` 사본에는 거짓**이다. 실측:

- 그 락의 agent 집합은 **경로가 아니라 frontmatter `name:` 값으로 키가 잡힌 dict** 다(`test_dispatch_disposition.sh:76`). `plugins/spec-distill/agents/doc-recritic.md` 가 이미 `name: doc-recritic` 이므로 같은 이름의 qg 파일은 **같은 키로 접힌다** — agent 수가 18 에서 늘지 않는다.
- dispatch 이름 정규식이 플러그인 접두를 **검사하지 않는다**(`name_re()`, `:100`·`:103-104` — `(?:[A-Za-z0-9_-]+:)?`). 그래서 spec-distill 의 dispatch 셋이 qg 사본의 `dispatch ≥ 1` 을 대신 만족시킨다.
- 반대 방향도 조용하다 — 정의 없는 이름을 dispatch 해도 그 줄은 `agents` dict 를 도는 루프에 안 걸려 아예 안 보인다(`:126-129`). 「dispatch 대상이 실재하는 agent 인가」 검사는 그 파일 어디에도 없다.
- 면제 목록 · `# copy-of:` 마커 예외 · 파일명 패턴 예외는 **없다**. 이것은 예외가 아니라 **사각지대**다.

→ **결론은 바뀌지 않고 근거가 바뀐다.** AC22 의 범위(qg 는 재비판자 사본 «하나»만 갖는다)는 그 자체로 옳다. 다만 **AC22 락은 기존 락에 조금도 기댈 수 없다** — 양방향 전부를 자기가 져야 하고, 그 사실을 PR4 계획이 이름으로 받아야 한다.

**틀리면 치르는 것** — PR4 가 커진다. 사용자가 반대로 정하면 이 계획에 Task 둘(사본+dispatch, 변환 계층)이 붙고 PR3 가 리뷰 한 번에 담기 어려워진다. 어느 쪽이든 되돌리는 비용은 **계획 층**에서 끝나고 코드에 남지 않는다.

### R-E — 각도 상태는 «입력 파일»로 받는다 (PR2 의 `--emit-verdict` 모양을 그대로)

**정함.** `synthesize_findings.py` 가 `--angles <경로>` 를 받는다. 기본은 `None`(그 축을 안 쓴다), 빈 문자열은 **exit 2**, `--emit-verdict` 없이 주면 **exit 2**. 플래그를 안 주면 stdout 은 이 PR 이전과 **바이트 동일**하다.

**왜.** 각도 상태를 «내는» 것은 오케스트레이터(SKILL.md)이고 그 배선은 PR4 다. 여기서 각도를 **필수**로 만들면 오늘 도는 `/qg` 가 전부 exit 4 가 된다 — 「기존 동작 무변경」이 깨지고, PR3 와 PR4 사이의 릴리스가 통째로 못 쓰게 된다. PR2 가 같은 문제를 같은 모양으로 풀었고(`--emit-verdict` 기본 off + 바이트 접두 단언), 그 모양을 반복하는 것이 새 모양을 발명하는 것보다 싸다.

**틀리면 치르는 것** — PR4 가 `--angles` 를 반드시 배선해야 한다는 빚이 하나 더 생긴다. 그 빚은 `test_angle_coverage.sh` 의 주석과 이 계획의 부채 목록 두 자리에 이름으로 남는다.

### R-F — PR2 계획문서의 부채 목록은 고치지 않는다 (C1)

**정함.** `docs/superpowers/plans/2026-09-22-qg-verdict-vocabulary-pr2.md` 의 「네 사유」 문장은 그대로 둔다. 대신 이 PR 이 `test_verdict_vocabulary.sh` 의 `debt` 리터럴을 정확한 넷으로 갱신하고, 이 계획과 PR 본문이 그 넷을 명시한다.

**왜.** 계획문서는 그 시점의 **역사 기록**이고, 기계가 검사하는 정본은 락의 `debt` 리터럴이다(그 리터럴은 `OVERLAP`·`MISSING`·`STALE` 셋으로 반증 가능하다 — 산문은 아니다). 머지된 계획에 정정 노트를 덧대면 그 노트의 리터럴이 다음 스캔 코퍼스에 다시 들어가 같은 종류의 stale 을 재생산한다.

**틀리면 치르는 것** — 머지된 계획문서 한 문장이 틀린 채 남는다. 읽는 쪽이 그 문장을 부채 목록의 정본으로 오해하면 `kill-switch` 의 배선을 PR4 에서 빠뜨릴 수 있다 — 그 위험은 이 계획의 「PR4 로 넘기는 부채」 절이 같은 이름을 다시 세워 받는다.

### R-G — `Ledger` 의 공개 accessor 는 **둘**이고, `_has_primary_source_failure` 는 **공개로 개명**한다

**정함.** `shared/adjudication/adjudication.py` 의 `Ledger` 가 `items_unaccounted()` 를 **신설**하고, `_has_primary_source_failure()` 를 `primary_source_failed()` 로 **개명**(공개)한다. `blocks()` 는 그 둘의 `or` 로 다시 쓴다 — **값은 동치**다.

**왜.** 사본을 하나 더 만들지 않는다(`test_no_new_duplication.sh` 가 사는 리포다). 개명은 사적 이름의 유일한 호출자가 `blocks()` 하나라 안전하고, 그 사실은 Task 3 의 Step 1 이 grep 으로 **먼저 확인**한다.

**틀리면 치르는 것** — `_has_primary_source_failure` 를 이름으로 참조하는 자리를 놓치면 `AttributeError` 다. 그 위험은 Step 1 의 전수 grep(개념 별칭 포함)과 `shared/tests/test_adjudication_behavior.sh` 의 기존 8단언이 함께 막는다.

### R-H — 수행자 집합은 finding 에서 **도출**한다. 선언에서 뽑지 않는다

**정함.** AC10a 의 `finding_authors` 는 그 실행의 finding 목록에서 도출한다 — `sources` 가 있으면 그것, 없으면 `agent`(합성기 `:520` 의 기존 관용구 `f.get("sources") or [f.get("agent", "?")]` 를 그대로 쓴다). `"?"` 는 제외한다. **억제된(suppressed) finding 도 「낸 것」으로 센다** — 냈기 때문에 억제된 것이다.

**왜.** 선언(각도 파일)에서 수행자를 뽑아 자기 자신과 대조하면 그것은 자기-일관성 검사이지 Law 2 검사가 아니다 — 저자가 이름을 달리 적는 것만으로 검사가 조용해진다. 억제분을 빼면 「임계값 아래 finding 만 낸 리뷰어」가 자기 판정을 할 수 있게 된다.

**틀리면 치르는 것** — 억제분까지 세므로 AC10a 가 오늘보다 엄격해진다. 정상적인 접어 넣기가 막히는 실행이 생기면 그 실행은 `folded_into` 대신 `absent` 를 쓰게 되고, 그러면 판정이 `not-certified (angle-absent)` 로 떨어진다 — **거짓 clean 이 아니라 거짓 not-certified** 방향이다. 안전한 방향으로 틀린다.

### R-I — 각도 파일은 YAML 이 아니라 **엄격 정규식**으로 읽는다

**정함.** `<각도>: <상태>` 줄의 닫힌 서식을 정규식으로 검사한다. PyYAML 을 쓰지 않는다.

**왜.** 상태 값이 `folded_into:security-reviewer` 라 값 안에 콜론이 있다. YAML 에서 이 모양은 **따옴표 유무·공백 유무에 따라 해석이 갈리고**, 그 갈림이 조용하다(따옴표 없는 `a: b:c` 는 평문 스칼라지만 `a: b: c` 는 파싱 오류다). 총 함수의 입력을 애매한 파서에 맡기면 AC10 의 「하나라도 없으면 실패」가 파서의 관대함만큼 새어 나간다.

**틀리면 치르는 것** — 오케스트레이터가 각도 파일을 쓸 때 따옴표를 붙이면 exit 4 다. 오류 메시지가 기대 서식을 그대로 보여 주므로 진단은 한 번에 끝난다.

### R-J — `angles:` 블록은 Markdown 본문이 아니라 **평문 꼬리**에, `verdict:` **앞**에 붙는다

**정함.** `synthesize_findings.py` 의 산출물에서 `angles:` 블록은 `render()` 가 낸 Markdown 보고서 **뒤**, `verdict:` 줄 **앞**에 평문 `key: value` 로 붙는다. `render()` 의 두 분기(빈 상태 · 표 상태) 어느 쪽도 **안 건드린다**.

**왜.** 세 가지가 같은 답을 가리킨다.

1. **선례가 있다.** PR2 가 `verdict:`·`reason:`·`reasons:` 를 정확히 그 자리에 그 모양으로 붙였다. 본문은 Markdown(`**처분:** … · …` 꼴의 굵은-라벨 산문 + `|` 표)이지만 **기계가 읽는 꼬리는 평문**이다 — 두 층이 이미 갈려 있다.
2. **바이트 접두가 유지된다.** 본문에 끼워 넣으면 `--angles` 유무가 보고서 «중간»을 바꿔 PR2 가 세운 「off 출력은 on 출력의 바이트 접두」 성질이 깨진다. 꼬리에 붙이면 그 성질이 한 층 더 쌓인다.
3. **`render()` 의 두 분기를 다 고치지 않아도 된다.** 본문에 넣으면 빈 상태와 표 상태 **양쪽**에 같은 편집을 해야 하고, 한쪽을 빠뜨리면 「발견 0인 실행에만 각도가 없다」는 조용한 구멍이 생긴다 — 그 파일이 과거에 정확히 그 모양으로 샌 적이 있다(`render()` 의 drop 공지 주석이 그 사건을 기록하고 있다).

**각도가 판정보다 앞인 것은 읽는 순서다** — 무엇을 봤는지가 그 판정의 근거다.

**틀리면 치르는 것** — 사람이 읽는 보고서 본문에는 각도가 안 보이고 꼬리에만 보인다. 사람 가독성을 위해 본문에도 한 줄이 필요하다고 판단되면 PR4 가 `**각도:** security=filled · …` 굵은-라벨 줄을 `disposition_lines()` 옆에 더하면 된다 — 그때도 **기계가 읽는 꼬리는 그대로 둔다**(두 표현이 갈리면 어느 쪽이 정본인지가 사라진다).

---

## 파일 구조

**신설**

| 경로 | 책임 |
|---|---|
| `plugins/quality-gates/scripts/angles.py` | 각도 이름 셋 · 상태 문법 · 총 함수 검증(AC10) · 자기-판정 금지(AC10a) · 차단 술어(AC11) · 렌더. **판정 값은 안 낸다** |
| `plugins/quality-gates/tests/test_angle_coverage.sh` | §6.3.2 의 ∀ 총 함수 + **양의 짝**(`absent` + `clean` = RED). `test_review_floor_lock.sh` 의 **교체** |

**수정**

| 경로 | 무엇이 |
|---|---|
| `plugins/quality-gates/scripts/verdict.py` | `decide()` 에 축 하나(`angle_absent`) + I2 주석을 실제 분리로 교체 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | `import angles as _angles` · `--angles` 진입 한 줄 · `review_blocked`/`angle_absent` 인자 갈림 · `angles:` 블록 출력 |
| `plugins/quality-gates/tests/test_verdict_vocabulary.sh` | `debt` 리터럴에서 `angle-absent` 제거 · `AXES:` 단언을 여섯으로 · 새 축의 케이스 추가 |
| `shared/adjudication/adjudication.py` | `items_unaccounted()` 신설 · `_has_primary_source_failure` → `primary_source_failed` 개명 · `blocks()` 동치 재작성 |
| `shared/tests/test_adjudication_behavior.sh` | 두 accessor 의 단언 + 양성 대조 |
| `tools/adjudication/check_wiring.py` | `synthesize_findings.py` 면제의 줄번호 재앵커 (C4) |
| `shared/docreview/agents/doc-recritic.md` | `diff` 선택 슬롯(`kind: repo_context`, `optional: true`) + 「이 변경이 도입했는가」 축 |
| `plugins/spec-distill/agents/doc-recritic.md` | 위의 **바이트 사본**(마커 줄 제외) — 같은 커밋 |
| `shared/tests/test_docreview_agents.sh` | 슬롯 리터럴 `['document', 'findings', 'profile']` → 넷 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 「입력 슬롯은 정확히 셋이다」 산문 정정 (diff 는 브리프 경로에 안 싣는다) |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 같음 |
| `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | 절단 완화책 한 문장 (C2) |
| `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json` | bump |
| `plugins/spec-distill/CHANGELOG.md` · `.claude-plugin/plugin.json` | 동반 bump (minor 이상) |

**제거**

| 경로 | 왜 |
|---|---|
| `plugins/quality-gates/tests/test_review_floor_lock.sh` | 명단-리터럴 락. §6.3.2 의 각도 coverage 락으로 **교체**한다 — **교체 없는 삭제는 C13 위반**이라 Task 4 가 둘을 **같은 커밋**에 담는다 |

---

### Task 1: 착수 — PR2 전제 확증 · 선재 RED 기준선 · 범위 불변식

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/pr3-baseline.tsv` (추적 안 함 — 커밋하지 않는다)
- Modify: 없음

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `pr3-baseline.tsv` — Task 7 이 같은 형식으로 다시 찍어 **행 단위로** 대조한다. 형식은 `<경로>\t<rc>\t<실패줄수>` 탭 구분 세 칸

- [ ] **Step 1: PR2 가 `main` 에 있는지 확증한다**

`verdict.py` 가 없으면 이 계획의 모든 Task 가 빈 전제 위에 선다. 파일 존재만이 아니라 **이 PR 이 기대는 심볼 셋**까지 본다 — 파일은 있는데 `decide()` 의 인자가 다르면 Task 4 의 호출이 조용히 틀린다.

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin --quiet

# ① 파일이 origin/main 에 있는가
git cat-file -e origin/main:plugins/quality-gates/scripts/verdict.py 2>/dev/null \
  && echo "OK verdict.py on origin/main" \
  || echo "MISSING verdict.py on origin/main — PR2(#166) 가 아직 안 머지됐다"
```

```bash
# ② 이 PR 이 기대는 심볼이 워킹트리 판에 실재하는가 (이름만이 아니라 호출 가능성)
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import inspect, sys
sys.path.insert(0, "plugins/quality-gates/scripts")
import verdict
need = {"defect", "review_blocked", "differential_text",
        "extra_reasons", "legacy_verdict"}
got = set(inspect.signature(verdict.decide).parameters)
print("decide params:", sorted(got))
print("params OK" if need <= got else "PARAMS MISSING: %s" % sorted(need - got))
print("angle-absent in REASONS:", "angle-absent" in verdict.REASONS)
print("REASONS len:", len(verdict.REASONS))
PY
```

**기대** — `OK verdict.py on origin/main` · `params OK` · `angle-absent in REASONS: True` · `REASONS len: 11`.

**`MISSING …` 이면서 ②도 실패하면 `BLOCKED` 로 보고하고 멈춘다.** 이 계획은 PR2 의 산출물 위에서만 성립한다. 브랜치가 PR2 위에 서 있으면(즉 `feature/qg-verdict-vocabulary-pr2` 에서 분기했으면) ①이 실패해도 ②는 통과한다 — 그때는 **`DONE_WITH_CONCERNS` 로 「PR2 미머지 위에 쌓았다」를 보고**하고 진행한다. PR 본문이 그 의존을 명시해야 한다.

- [ ] **Step 2: 선재 RED 기준선을 포착한다 — rc 와 «실패 줄 수» 둘 다**

`rc` 만 적으면 **이미 RED 인 파일 안의 새 실패가 원리적으로 안 보인다**(설계 §13). 실패 줄 수를 2차 키로 함께 적는다.

```bash
cd "$(git rev-parse --show-toplevel)"
OUT="${CLAUDE_JOB_DIR:-/tmp}/tmp/pr3-baseline.tsv"
mkdir -p "$(dirname "$OUT")"
: > "$OUT"

# 세 디렉토리 전부 — 이 PR 이 shared/ 와 spec-distill 을 건드린다(§13 회귀 스위트).
# `^[[:space:]]*✗` 로 앵커한다. `\s` 를 쓰지 않는다 — BSD `grep -E` 는 `\s` 를
# 지원하지 않고 **오류 없이 0건**을 낸다(그러면 모든 파일이 실패 0줄로 기록된다).
for f in plugins/quality-gates/tests/*.sh shared/tests/*.sh plugins/spec-distill/tests/*.sh; do
  [ -f "$f" ] || continue
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$f" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗' || true)"
  printf '%s\t%s\t%s\n' "$f" "$rc" "$n" >> "$OUT"
done
wc -l < "$OUT"
awk -F'\t' '$2 != 0 {print}' "$OUT"
```

**보고서에 적는 것** — 총 행 수, RED 파일의 경로·rc·실패 줄 수 전부. 이 숫자는 **주장이 아니라 측정**이다. 앞 계획에 적힌 「선재 RED 는 N 건」을 베끼지 않는다.

- [ ] **Step 3: 범위 불변식을 적어 둔다**

이 PR 이 건드려도 되는 경로는 위 「파일 구조」 표의 것뿐이다. Task 7 이 `git diff --name-only` 로 그 집합과 대조한다. 특히 **아래는 이 PR 밖이다**:

- `plugins/quality-gates/agents/**` — 사본도 `adversarial.md` 제거도 PR4 다 (R-D)
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — PR4
- `plugins/quality-gates/commands/qg.md` — PR4
- `plugins/quality-gates/scripts/diff-test-results.py` — PR2 가 끝냈다
- `.claude-plugin/marketplace.json` · 리포 루트 `CLAUDE.md` — PR5

- [ ] **Step 4: 커밋하지 않는다**

이 Task 는 측정만 한다. 산출물은 `$CLAUDE_JOB_DIR/tmp/` 에 있고 리포에 들어가지 않는다. 보고서에 baseline 의 **절대 경로**를 적어 Task 7 이 찾을 수 있게 한다.

---

### Task 2: `angles.py` — 각도 셋 · 상태 문법 · 총 함수 (AC10 · AC10a · AC12)

**Files:**
- Create: `plugins/quality-gates/scripts/angles.py` (mode 100755)
- Test: `plugins/quality-gates/tests/test_angle_coverage.sh` (mode 100755 — 이 리포의 shell 어댑터는 **실행 비트로 claim** 한다. 비트가 없으면 unclaimed 라 사람이 `bash <경로>` 로 돌릴 때만 초록이고 스위트에서는 안 돈다)

**Interfaces:**
- Consumes: 없음 — 이 모듈은 `verdict` 를 import 하지 않는다 (Global Constraints)
- Produces — Task 4 의 합성기가 이 이름들을 그대로 부른다:
  - `ANGLES = ("security", "adjudication", "different-premise")` — 닫힌 열거, 튜플 순서 = 출력 순서
  - `BLOCKING_ANGLES = ("security", "adjudication")`
  - `SELF_ADJUDICATION_FORBIDDEN = ("adjudication",)`
  - `FILLED = "filled"` · `ABSENT = "absent"` · `FOLDED_PREFIX = "folded_into:"`
  - `fail4(msg)` → stderr `angles.py: {msg}` + `SystemExit(4)`
  - `read_or_fail4(path) -> str`
  - `parse(text) -> dict[str, str]` — 총 함수 강제
  - `performer_of(state) -> str | None`
  - `check_self_adjudication(states, finding_authors) -> None`
  - `blocks(states) -> bool`
  - `render(states) -> str` — `angles:` 블록, 항상 세 줄
  - CLI: `--angles <경로>` · `--author <이름>`(반복) → exit `0`/`2`/`4`

- [ ] **Step 1: 실패하는 락을 먼저 쓴다**

`plugins/quality-gates/tests/test_angle_coverage.sh`:

```bash
#!/usr/bin/env bash
# test_angle_coverage.sh — AC10 · AC10a · AC11 · AC12 (설계 §6.3.1 · §6.3.2).
#
# 이 락이 `test_review_floor_lock.sh` 를 **교체**한다(Task 4 가 그것을 지운다).
# 옛 락의 앵커는 SKILL.md 의 명단 리터럴이었고 그것은 **피검자가 쥔 앵커**였다 —
# 모델이 산문을 고치면 락이 따라 움직인다. 새 앵커는 합성기가 쓰는 모듈의
# ∀ 관계다: 각도 셋 전부가 상태를 갖지 않으면 exit 4 이고, 그 「셋」은 이 락이
# 열거하지 않고 `angles.py` 에서 **도출**한다.
#
# **이 락이 재지 «않는» 것(설계 §15-4)** — 「각도가 상태를 가졌는가」는 재지만
# 「그 상태가 참인가」는 못 잰다. 모델이 세 각도를 전부 `folded_into:` 로 주장하면
# 이 락은 GREEN 이다. 형식적 완전성의 락이지 진실성의 락이 아니다.
#
# **오늘 배선이 안 된 것** — `--angles` 는 기본 off 다(계획 R-E). 오케스트레이터가
# 그것을 «항상» 싣게 만드는 것은 PR4 의 빚이고, 이 락은 그 빚을 재지 못한다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
A="$PLUGIN_ROOT/scripts/angles.py"
export PYTHONDONTWRITEBYTECODE=1

TMP="$(mktemp -d -t angles-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 열거를 **모듈에게 물어** 가져온다. 여기에 리터럴을 복사하면 두 자리가 어긋날 때
# 락이 자기 사본만 보고 GREEN 을 낸다.
ANGLES="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.ANGLES))")"
BLOCKING="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.BLOCKING_ANGLES))")"

# 도출이 실패하면(모듈 부재·문법 오류) 아래 전부가 «빈 코퍼스 위의 통과»가 된다.
# 침묵하지 않고 여기서 먼저 밝힌다 — vacuous 락은 통과가 곧 증거가 아니다.
if [ -z "$ANGLES" ] || [ -z "$BLOCKING" ]; then
  no "angles.py 에서 열거를 도출하지 못했다 — 아래 단언은 아무것도 재지 않는다"
  # `finish` 는 «종료하지 않는다» — 값을 반환할 뿐이다(`shared/tests/assert.sh:111-114`).
  # 뒤에 `exit` 가 없으면 스크립트가 그대로 계속 돌아 빈 코퍼스 위에서 단언을 쌓는다.
  # 인자 없는 `exit` 는 직전 명령(`finish`)의 상태로 나간다.
  finish; exit
fi

# write_angles <파일> <"각도: 상태"...>  — 생략된 각도는 안 쓴다(총 함수 검사용)
write_angles() {
  local f="$1"; shift
  : > "$f"
  local kv
  for kv in "$@"; do printf '%s\n' "$kv" >> "$f"; done
}

case_all_three_filled_is_ok() {
  local f="$TMP/ok.txt" out rc=0
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  out="$(python3 "$A" --angles "$f")" || rc=$?
  assert_eq "$rc" "0" "세 각도가 전부 상태를 가지면 exit 0"
  assert_grep "$out" '^angles:$'                     "angles: 블록이 나온다"
  assert_grep "$out" '^  security: filled$'          "보안 각도 한 줄"
  assert_grep "$out" '^  adjudication: filled$'      "판정 각도 한 줄"
  assert_grep "$out" '^  different-premise: filled$' "다른 전제 각도 한 줄"
  assert_grep "$out" '^angle_absent: false$'         "막지 않는다"
}

case_every_angle_is_required() {
  # AC10 — **총 함수**다. 각도 하나를 «빼면» 그것이 무엇이든 exit 4 여야 한다.
  # 열거를 도출해 돌므로 `ANGLES` 에 네 번째가 생기면 이 루프가 자동으로 그것도 잰다.
  local missing a f rc out
  while IFS= read -r missing; do
    [ -n "$missing" ] || continue
    f="$TMP/missing-$missing.txt"; : > "$f"
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      [ "$a" = "$missing" ] && continue
      printf '%s: filled\n' "$a" >> "$f"
    done <<< "$ANGLES"
    rc=0; out="$(python3 "$A" --angles "$f" 2>&1)" || rc=$?
    assert_eq "$rc" "4" "'$missing' 의 상태가 없으면 exit 4 (총 함수)"
    assert_contains "$out" "$missing" "오류가 빠진 각도의 이름을 댄다"
  done <<< "$ANGLES"
}

case_state_grammar_is_closed() {
  local f="$TMP/grammar.txt" rc st
  # 문법 «안» — 셋 다 선다
  for st in "filled" "absent" "folded_into:security-reviewer"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "0" "'$st' 는 문법 안이다"
  done
  # 문법 «밖» — 넷 다 exit 4. `folded_into:` 뒤가 비거나 공백이 섞인 것도 포함한다.
  for st in "maybe" "folded_into:" "FILLED" "folded_into:two words"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "'$st' 는 문법 밖이라 exit 4"
  done
}

case_unknown_angle_is_fail_closed() {
  local f="$TMP/unknown.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: filled" \
                    "different-premise: filled" "made-up-angle: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 각도는 exit 4 — 각도 셋은 닫혀 있다"
}

case_duplicate_angle_is_fail_closed() {
  # 같은 각도가 두 줄이면 «어느 쪽이 참인지» 산출물만 보고는 복원할 수 없다.
  # 「마지막이 이긴다」로 두면 앞 줄을 조용히 덮는 경로가 열린다.
  local f="$TMP/dup.txt" rc=0
  write_angles "$f" "security: absent" "security: filled" \
                    "adjudication: filled" "different-premise: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "같은 각도가 두 번 나오면 exit 4"
}

case_blocking_angles_are_exactly_two() {
  # AC11 · AC12 의 비대칭 자체를 핀한다. 「다른 전제」가 `BLOCKING_ANGLES` 에
  # 들어가면 모델 다양성 손실이 게이트가 된다 — 헌장 위반이다. 반대로 보안·판정이
  # 빠지면 AC11 이 죽는다. 아래 두 행동 케이스는 «오늘의 값»만 재므로 집합 자체를
  # 핀하는 이 단언이 따로 필요하다.
  local got; got="$(printf '%s\n' "$BLOCKING" | sort | tr '\n' ' ')"
  assert_eq "$got" "adjudication security " \
    "막는 각도는 보안·판정 둘뿐이다 (다른 전제는 공시만 — AC12)"
}

case_absent_blocking_angle_sets_the_flag() {
  # AC11 의 «산출자» 쪽. 판정 «값» 은 Task 4 의 합성기 경로가 잰다.
  local f="$TMP/absent.txt" out a b
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out="$(python3 "$A" --angles "$f")"
    assert_grep "$out" '^angle_absent: true$' "'$a' 가 absent 면 막는다"
  done <<< "$BLOCKING"
}

case_absent_non_blocking_angle_discloses_only() {
  # AC12 — 「다른 전제」의 부재는 **공시되되 막지 않는다**.
  local f="$TMP/dp-absent.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent"
  out="$(python3 "$A" --angles "$f")"
  assert_grep "$out"     '^  different-premise: absent$' "부재가 산출물에 **드러난다**"
  assert_grep "$out"     '^angle_absent: false$'         "그래도 막지 않는다"
  assert_not_grep "$out" '^angle_absent: true$'          "막는다고 말하지 않는다"
}

case_self_adjudication_is_rejected() {
  # AC10a — 판정 각도가 **그 실행에서 finding 을 낸** 수행자에게 접히면 exit 4.
  local f="$TMP/self.txt" rc=0 out
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" \
                    "different-premise: filled"
  out="$(python3 "$A" --angles "$f" --author security-reviewer 2>&1)" || rc=$?
  assert_eq "$rc" "4" "자기 finding 자기 판정은 exit 4"
  assert_contains "$out" "security-reviewer" "오류가 그 수행자의 이름을 댄다"
}

case_folding_into_a_silent_reviewer_is_ok() {
  # 같은 모양인데 그 수행자가 finding 을 «안 냈으면» 정상이다 — C13 이 허용한
  # 접어 넣기다. 이 케이스가 없으면 위 케이스는 「folded_into 를 전부 막는다」와
  # 구별되지 않는다(양의 짝).
  local f="$TMP/fold-ok.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "finding 을 안 낸 리뷰어에게 접는 것은 정상이다"
}

case_security_angle_may_fold_into_its_own_author() {
  # AC10a 의 **범위 한정**. 보안 각도는 «무엇을 찾는가» 의 문제라 그 리뷰어가
  # finding 을 내는 것이 정상이다. 여기에 같은 금지를 걸면 C13 의 접어 넣기가
  # 사실상 죽는다 — 설계가 명시적으로 뺀 자리다.
  local f="$TMP/sec-fold.txt" rc=0
  write_angles "$f" "security: folded_into:security-reviewer" "adjudication: filled" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "보안 각도에는 AC10a 를 적용하지 않는다"
}

case_forbidden_set_is_adjudication_only() {
  # 위 두 케이스는 «오늘의 두 각도»만 잰다. 금지 집합 자체를 핀해야 세 번째
  # 각도가 조용히 편입되거나 판정 각도가 조용히 빠지는 것을 잡는다.
  local got; got="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print(' '.join(sorted(angles.SELF_ADJUDICATION_FORBIDDEN)))")"
  assert_eq "$got" "adjudication" "AC10a 의 대상은 판정 각도 하나다"
}

case_missing_file_is_fail_closed() {
  local rc=0; python3 "$A" --angles "$TMP/nope.txt" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "각도 파일이 없으면 exit 4 (조용히 clean 으로 새지 않는다)"
}

case_empty_flag_is_usage_error() {
  # exit 2 와 exit 4 를 가른다 — 빈 인자는 «잘못된 호출»이지 «실패한 판정»이 아니다.
  local rc=0; python3 "$A" --angles "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 경로는 usage 오류(exit 2)"
  rc=0; python3 "$A" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "경로를 아예 안 주면 usage 오류(exit 2)"
}

case_non_utf8_is_fail_closed() {
  # 형제 `verdict.read_or_none()` 이 네 번째 재발로 얻은 절이다 —
  # `UnicodeDecodeError` 는 `ValueError` 의 하위이지 `OSError` 가 아니라서,
  # `except OSError` 만 두면 raw traceback + exit 1 로 0/2/4 계약을 탈출한다.
  # 픽스처는 **유효한 본문 뒤에** 나쁜 바이트를 붙인다 — 파일 전체가 쓰레기면
  # 서식 오류로도 exit 4 가 나서 green-for-the-wrong-reason 이 된다.
  local f="$TMP/bad.bin" rc=0
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$f"
  printf '# \xff\xfe\n' >> "$f"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "비-UTF-8 각도 파일은 exit 4 (traceback 이 아니다)"
}

case_all_three_filled_is_ok
case_every_angle_is_required
case_state_grammar_is_closed
case_unknown_angle_is_fail_closed
case_duplicate_angle_is_fail_closed
case_blocking_angles_are_exactly_two
case_absent_blocking_angle_sets_the_flag
case_absent_non_blocking_angle_discloses_only
case_self_adjudication_is_rejected
case_folding_into_a_silent_reviewer_is_ok
case_security_angle_may_fold_into_its_own_author
case_forbidden_set_is_adjudication_only
case_missing_file_is_fail_closed
case_empty_flag_is_usage_error
case_non_utf8_is_fail_closed
finish
```

- [ ] **Step 2: 락이 실패하는지 확인한다**

```bash
chmod +x plugins/quality-gates/tests/test_angle_coverage.sh
bash plugins/quality-gates/tests/test_angle_coverage.sh; echo "rc=$?"
```

**기대** — `angles.py` 가 없어 열거 도출이 빈 문자열이 되고, 락 첫머리의 vacuous 가드가 `✗ angles.py 에서 열거를 도출하지 못했다` 한 줄을 내며 **rc=1** 로 끝난다. rc 가 0 이면 그 자체가 결함이다 — 보고하고 멈춘다.

- [ ] **Step 3: `angles.py` 를 쓴다**

```python
#!/usr/bin/env python3
"""각도 상태 — 세 각도의 총 함수 (설계 §6.3.1 · §6.3.2, AC10 · AC10a · AC11 · AC12).

**각도는 에이전트가 아니다.** 각도는 「채워졌는가」의 술어이고 수행자는 스코프가
정한다(§6.3.1). 그래서 이 모듈은 **수행자 명단을 갖지 않는다** — 명단을 넣으면
이 PR 이 지우는 `test_review_floor_lock.sh` 를 파이썬으로 다시 쓰는 것이다.

**판정 값은 내지 않는다.** 이 모듈이 내는 것은 「막는가」라는 불리언 하나이고,
그것을 `not-certified (angle-absent)` 로 번역하는 것은 `verdict.py` 다. 그래서
여기서 `verdict` 를 import 하지 않는다 — 어휘의 소유자는 하나여야 한다.
"""
import argparse
import re
import sys

# 각도 셋 — 닫힌 열거. 튜플 **순서가 출력 순서**다.
ANGLES = ("security", "adjudication", "different-premise")

# 부재가 판정을 **막는** 각도 (§6.3.1 표의 앞 두 행 · AC11). 셋째 행
# `different-premise` 는 여기 없다 — 헌장의 「모델 다양성 손실은 공시하고 막지
# 않는다」 그대로다(AC12). 이 집합에 셋째를 넣으면 codex 가 못 도는 실행이 전부
# 미판정이 된다.
BLOCKING_ANGLES = ("security", "adjudication")

# 자기 finding 자기 판정이 금지되는 각도 (AC10a). **보안 각도는 여기 없다** —
# 보안은 «무엇을 찾는가» 의 문제라 그 리뷰어가 finding 을 내는 것이 정상이고,
# 금지하면 C13 이 허용한 접어 넣기가 사실상 죽는다(설계가 명시적으로 뺀 자리).
SELF_ADJUDICATION_FORBIDDEN = ("adjudication",)

FILLED = "filled"
ABSENT = "absent"
FOLDED_PREFIX = "folded_into:"

# 엄격 서식 — YAML 을 쓰지 않는다(계획 R-I). 상태 값 안에 콜론이 있어서
# (`folded_into:security-reviewer`) YAML 은 따옴표·공백에 따라 해석이 갈리고 그
# 갈림이 조용하다. 총 함수의 입력을 관대한 파서에 맡기면 AC10 의 「하나라도 없으면
# 실패」가 그 관대함만큼 새어 나간다. 상태는 **공백 없는 한 토큰**이다.
_LINE = re.compile(r"^([a-z-]+): (\S+)$")
_PERFORMER = re.compile(r"^[A-Za-z0-9_-]+$")


def fail4(msg):
    # `angles:` 를 접두사로 쓰지 않는다 — 그것은 성공 출력의 블록 헤더다. 순진한
    # 줄-지향 파서가 이 오류 문장을 상태 줄로 읽는다. 형제 `verdict.py` 와 같은
    # 모양으로 스크립트 이름을 쓴다.
    print(f"angles.py: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_fail4(path):
    """각도 파일을 읽는다. 없거나 못 읽으면 exit 4.

    **형제와 다른 점** — `verdict.read_or_none()` 은 경로가 비면 `None`(그 축을 안
    쓴다)을 돌려준다. 여기 오는 경로는 호출자가 이미 「쓴다」고 정한 것이라 부재가
    곧 실패다. 그래서 이름도 반환 계약도 다르다.

    **형제와 같은 점** — 두 절(`OSError` · `UnicodeDecodeError`)을 **둘 다** 둔다.
    `UnicodeDecodeError` 는 `ValueError` 의 하위이지 `OSError` 가 아니라서, 앞
    절만 두면 비-UTF-8 입력이 raw traceback + exit 1 로 0/2/4 계약을 탈출한다.
    이 리포에서 네 번 재발한 모양이다.
    """
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"각도 상태 파일을 읽지 못했다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"각도 상태 파일이 UTF-8 이 아님: {path} ({exc})")


def _validated_state(name, state):
    if state in (FILLED, ABSENT):
        return state
    if state.startswith(FOLDED_PREFIX):
        performer = state[len(FOLDED_PREFIX):]
        if not performer:
            fail4(f"'{name}' 의 {FOLDED_PREFIX} 에 수행자가 없다")
        if not _PERFORMER.match(performer):
            fail4(f"'{name}' 의 수행자 이름이 아니다: {performer!r}")
        return state
    fail4(f"'{name}' 의 상태 '{state}' 가 문법 밖이다 "
          f"({FILLED} · {FOLDED_PREFIX}<수행자> · {ABSENT})")


def parse(text):
    """`<각도>: <상태>` 줄들을 각도→상태 dict 로. **총 함수를 여기서 강제한다**(AC10).

    빠진 각도 · 열거 밖 각도 · 같은 각도의 중복 · 문법 밖 상태는 전부 exit 4 다.
    중복을 「마지막이 이긴다」로 두지 않는 이유: 그러면 앞 줄을 조용히 덮는 경로가
    열리고, 무엇이 참인지 산출물만 보고는 복원할 수 없다.
    """
    states = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = _LINE.match(line)
        if not m:
            fail4(f"각도 상태 줄의 서식이 아니다: {raw!r} "
                  "(기대: '<각도>: <상태>', 상태는 공백 없는 한 토큰)")
        name, state = m.group(1), m.group(2)
        if name not in ANGLES:
            fail4(f"열거 밖 각도 '{name}' — 각도 셋은 닫혀 있다")
        if name in states:
            fail4(f"각도 '{name}' 의 상태가 두 번 나온다")
        states[name] = _validated_state(name, state)
    missing = [a for a in ANGLES if a not in states]
    if missing:
        fail4("상태가 없는 각도: " + ", ".join(missing)
              + " — 각도 상태는 총 함수다 (AC10)")
    return states


def performer_of(state):
    """`folded_into:<수행자>` 면 수행자 이름, 아니면 `None`."""
    if state.startswith(FOLDED_PREFIX):
        return state[len(FOLDED_PREFIX):]
    return None


def check_self_adjudication(states, finding_authors):
    """AC10a — 자기 finding 을 자기가 판정하면 exit 4. **판정 각도에 한정**한다.

    `finding_authors` 는 그 실행이 실제로 «낸» finding 에서 도출한 수행자 집합이다
    (계획 R-H). 각도 파일 자신에서 뽑으면 그것은 자기-일관성 검사이지 Law 2
    검사가 아니다 — 저자가 이름을 달리 적는 것만으로 조용해진다.
    """
    for name in SELF_ADJUDICATION_FORBIDDEN:
        performer = performer_of(states[name])
        if performer is not None and performer in finding_authors:
            fail4(f"'{name}' 각도가 이 실행에서 finding 을 낸 "
                  f"'{performer}' 에게 접혔다 — 자기 finding 자기 판정은 "
                  "Law 2 위반이다 (AC10a)")


def blocks(states):
    """AC11 — 보안 또는 판정 각도가 `absent` 면 참.

    `different-premise` 는 세지 않는다(AC12). 그 부재는 `render()` 가 공시한다.
    """
    return any(states[a] == ABSENT for a in BLOCKING_ANGLES)


def render(states):
    """`angles:` 블록. **항상 `len(ANGLES)` 줄**이다 — 부재도 침묵이 아니라 한 줄이다.

    침묵과 `absent` 는 다른 사실이다. 부재한 각도를 빼고 렌더하면 읽는 쪽이 그것을
    「그 각도가 필요 없었다」와 구별할 수 없다.
    """
    out = ["angles:"]
    for a in ANGLES:
        out.append(f"  {a}: {states[a]}")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--angles", default=None)
    ap.add_argument("--author", action="append", default=[])
    args = ap.parse_args()
    # exit 2 와 exit 4 를 가른다 — 빈 인자는 «잘못된 호출»이지 «실패한 판정»이
    # 아니다. 형제 `verdict.py` 의 `--differential ""` 처리와 같은 규칙이다.
    if not args.angles:
        print("angles.py: --angles 에 각도 상태 파일 경로를 줘라 "
              "(빈 문자열은 받지 않는다)", file=sys.stderr)
        return 2
    states = parse(read_or_fail4(args.angles))
    check_self_adjudication(states, set(args.author))
    sys.stdout.write(render(states))
    print(f"angle_absent: {'true' if blocks(states) else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 락이 통과하는지 확인한다**

```bash
chmod +x plugins/quality-gates/scripts/angles.py
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile plugins/quality-gates/scripts/angles.py && echo "compile OK"
bash plugins/quality-gates/tests/test_angle_coverage.sh; echo "rc=$?"
```

**기대** — `compile OK`, `rc=0`, `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/angles.py plugins/quality-gates/tests/test_angle_coverage.sh
git commit -m "feat(qg): 각도 상태 총 함수 — 세 각도 · 닫힌 문법 · 자기-판정 금지" \
  -m "AC10(총 함수) · AC10a(판정 각도 한정) · AC12(다른 전제는 공시만). 각도는
에이전트가 아니므로 이 모듈은 수행자 명단을 갖지 않는다. 판정 값도 내지 않는다 —
「막는가」 불리언 하나만 내고 번역은 verdict.py 가 한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

**모드 확인** — 커밋 뒤 `git ls-files -s plugins/quality-gates/tests/test_angle_coverage.sh` 가 `100755` 여야 한다. `100644` 면 shell 어댑터가 이 락을 claim 하지 않아 스위트에서 안 돈다.

---

### Task 3: `Ledger` 공개 accessor 둘 + `verdict.py` 의 `angle_absent` 축 (C3 · AC11 의 산출자)

**Files:**
- Modify: `shared/adjudication/adjudication.py` (`Ledger.items_unaccounted()` 신설 · `_has_primary_source_failure` → `primary_source_failed` 개명 · `blocks()` 동치 재작성)
- Modify: `plugins/quality-gates/scripts/verdict.py` (`decide()` 에 `angle_absent` 축 · CLI 플래그 · I2 주석 교체)
- Test: `shared/tests/test_adjudication_behavior.sh` (두 accessor 의 단언 + 양성 대조)
- Test: `plugins/quality-gates/tests/test_verdict_vocabulary.sh` (`debt` 리터럴 · `AXES:` 단언 · 새 케이스 둘)

**Interfaces:**
- Consumes: Task 2 의 산출물은 **안 쓴다** — 이 Task 는 `angles.py` 와 독립이다(합치는 것은 Task 4)
- Produces:
  - `Ledger.items_unaccounted() -> bool` — 항목이 소실됐거나 셀 수 없다
  - `Ledger.primary_source_failed() -> bool` — 그 축의 주 판정자가 죽었다
  - `Ledger.blocks()` 는 **값 동치** 유지 (`items_unaccounted() or primary_source_failed()`)
  - `verdict.decide(*, defect, review_blocked, angle_absent, differential_text, extra_reasons, legacy_verdict)`
  - `verdict.py --angle-absent` CLI 플래그

- [ ] **Step 1: 개명 전에 전수 스윕 — 식별자만이 아니라 개념 별칭으로**

`_has_primary_source_failure` 를 공개 이름으로 바꾸기 «전»에, 그 이름과 그 개념을 참조하는 자리를 **전부** 찾는다. 식별자만 grep 하면 다른 이름으로 같은 것을 가리키는 산문이 살아남는다.

```bash
cd "$(git rev-parse --show-toplevel)"
echo "── 식별자"
grep -rn "_has_primary_source_failure" --include="*.py" --include="*.sh" --include="*.md" . | grep -v "^./.git/"
echo "── 개념 별칭 (주 판정자 · primary source · 主)"
grep -rn "주(主)\|주 판정자\|primary source\|primary=True" --include="*.py" --include="*.sh" --include="*.md" . | grep -v "^./.git/" | head -20
```

**기대** — 식별자는 `shared/adjudication/adjudication.py` 의 정의(1)와 `blocks()` 의 호출(1), 그리고 `plugins/quality-gates/scripts/verdict.py` 의 **주석 인용**(1)이다. 이 셋 말고 다른 자리가 나오면 **전부 보고서에 적고** 그 자리도 같은 커밋에서 옮긴다. 개념 별칭 쪽은 모듈 docstring과 `source_failed()` docstring, 그리고 `reasons()` 의 렌더 문자열 — 이들은 **개명 대상이 아니다**(개념을 말하는 산문이지 식별자가 아니다). 헷갈리면 「이 문자열이 바뀌면 코드가 깨지는가」로 가른다.

- [ ] **Step 2: 실패하는 단언을 먼저 쓴다 — 두 락에**

**(a) `shared/tests/test_adjudication_behavior.sh`** — 파일 끝의 `finish` **앞**에 다음 절을 더한다. 이 락의 기존 관용구(`run <python-body>` → stdout)를 그대로 쓴다:

```bash
note "── 5. blocks() 의 세 조건을 «가르는» 공개 accessor (PR3)"

# 왜 이것이 필요한가: 소비자(qg)가 셋을 **다른 사유**로 렌더한다 — 앞 둘은
# `findings-lost`(항목을 잃었다), 셋째는 `angle-absent`(아무도 그 축을 안 봤다).
# `blocks()` 하나만 공개하면 그 구별이 소비자 쪽에서 복원 불가능하다.

out="$(run '
L = Ledger(items="open"); L.hold("x", "판정자 부재")
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "True False True" "hold 는 items_unaccounted 만 올린다"

out="$(run '
L = Ledger(items="open"); L.uncountable("issues", "셀 수 없음")
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "True False True" "uncountable 도 items_unaccounted 쪽이다"

# ★ 이 PR 이 사는 이유가 이 한 줄이다 — 주 판정자가 죽었을 때 items_unaccounted 가
#   **거짓**이어야 소비자가 그 실행을 「항목을 잃었다」가 아니라 「아무도 안 봤다」로
#   렌더할 수 있다. 여기가 True 로 돌아오면 PR2 의 접힘이 그대로 남은 것이다.
out="$(run '
L = Ledger(items="open"); L.source_failed("reviewer", "죽음", primary=True)
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "False True True" "주 source 실패는 primary_source_failed 만 올린다"

# 양성 대조 — 보조 실패는 어느 쪽도 올리지 않는다(공시만 한다).
out="$(run '
L = Ledger(items="open"); L.source_failed("codex", "미설치", primary=False)
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks(), L.report()["degraded"])')"
assert_eq "$out" "False False False True" \
  "보조 실패는 두 accessor 다 거짓이고 blocks 도 아니다 — degraded 만 참 (헌장)"

# 동치 — `blocks()` 를 다시 쓴 뒤에도 값이 같다. 네 조합 전수.
out="$(run '
def mk(h, u, p):
    L = Ledger(items="open")
    if h: L.hold("x", "판정자 부재")
    if u: L.uncountable("i", "미상")
    if p: L.source_failed("r", "죽음", primary=True)
    return L
bad = [(h,u,p) for h in (0,1) for u in (0,1) for p in (0,1)
       if mk(h,u,p).blocks() != (mk(h,u,p).items_unaccounted()
                                 or mk(h,u,p).primary_source_failed())]
print("MISMATCH:%d" % len(bad))')"
assert_eq "$out" "MISMATCH:0" "blocks() == items_unaccounted() or primary_source_failed() (8조합 전수)"
```

**(b) `plugins/quality-gates/tests/test_verdict_vocabulary.sh`** — 세 자리를 움직이고 케이스 둘을 더한다.

① `case_reason_enum_is_closed_and_accounted` 의 `debt` 리터럴에서 `angle-absent` 를 **뺀다**:

```bash
  local debt="declaration-invalid kill-switch merge-conflict trivia"
```

그 위 주석의 실측 3분할 목록도 같이 고친다 — 「호출자-전용 부채 … (5): trivia · kill-switch · declaration-invalid · merge-conflict · angle-absent」를 **(4): trivia · kill-switch · declaration-invalid · merge-conflict** 로, 「모듈 자신의 플래그로 산출 가능(1): findings-lost」를 **(2): findings-lost · angle-absent** 로. **숫자와 이름을 함께** 고친다 — 한쪽만 고치면 `OVERLAP` 이 RED 로 알리지만 주석은 조용히 틀린 채 남는다.

② `AXES:` 단언을 여섯으로:

```bash
  assert_grep "$got" '^AXES:angle_absent,defect,differential_text,extra_reasons,legacy_verdict,review_blocked$' \
    "decide() 의 키워드 전용 파라미터 집합이 여섯이다 — 새 축마다 파라미터가 하나 는다(OVERLAP 이 못 잡는 헬퍼-추출 배선의 둘째 독립 증인)"
```

③ 케이스 둘을 더하고 **호출부에도 두 줄을 더한다**(파일 끝의 케이스 호출 목록 — 함수만 쓰고 부르지 않으면 0단언이다):

```bash
case_angle_absent_is_not_certified() {      # AC11 의 «값» 쪽
  local out; out=$(python3 "$V" --angle-absent)
  assert_grep "$out"     '^verdict: not-certified$' "각도 부재는 미판정을 만든다"
  assert_grep "$out"     '^reason: angle-absent$'   "angle-absent 가 reason 이 된다"
  assert_not_grep "$out" '^verdict: clean$'          "clean 이 아니다 (AC11)"
}

case_angle_absent_and_findings_lost_are_distinct() {
  # 둘은 **다른 사유**다. 같은 실행에서 둘 다 서면 reasons 에 둘 다 남고,
  # `reason:` 은 열거 순서에서 앞선 `findings-lost` 다. 이 케이스가 없으면
  # 「둘을 하나로 다시 접는」 회귀가 GREEN 으로 지나간다 — PR2 가 갖고 있던
  # 바로 그 접힘이다(I2).
  local out; out=$(python3 "$V" --angle-absent --review-blocked)
  assert_grep "$out" '^verdict: not-certified$' "둘 다면 여전히 미판정"
  assert_grep "$out" '^reason: findings-lost$'  "reason 은 열거 순서상 앞선 쪽"
  assert_grep "$out" 'angle-absent'             "그래도 angle-absent 가 reasons 에서 소실되지 않는다"
}
```

- [ ] **Step 3: 두 락이 실패하는지 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
bash shared/tests/test_adjudication_behavior.sh; echo "rc=$?"
bash plugins/quality-gates/tests/test_verdict_vocabulary.sh; echo "rc=$?"
```

**기대** — 둘 다 rc≠0. 앞쪽은 `AttributeError: 'Ledger' object has no attribute 'items_unaccounted'`, 뒤쪽은 `AXES:` 불일치 + `OVERLAP:` 은 아직 빈 채로(부채에서 뺀 이름의 산출자가 아직 없으므로 `MISSING:angle-absent` 가 뜬다). **`MISSING:angle-absent` 가 보이는 것이 정상이다** — 이 Task 의 Step 4 가 그 산출자를 만든다.

- [ ] **Step 4: `shared/adjudication/adjudication.py` 를 고친다**

`_has_primary_source_failure` 를 지우고 공개 둘을 세운다. 사본을 만들지 않는다(R-G) — 사적 이름을 남긴 채 공개 래퍼를 덧대면 같은 술어가 두 이름으로 살고, 그것이 `test_no_new_duplication.sh` 가 사는 이유다.

```python
    # ── 파생 술어 ─────────────────────────────────────────────────────
    def items_unaccounted(self):
        """항목이 소실됐거나 셀 수 없다 — `blocks()` 의 앞 두 조건.

        `primary_source_failed()` 와 **나뉘어** 있는 이유는 소비자가 둘을 다른
        사유로 렌더하기 때문이다(qg 의 `findings-lost` 대 `angle-absent`).
        `blocks()` 하나만 공개하면 그 구별이 소비자 쪽에서 복원 불가능하다 —
        「항목을 잃었다」와 「아무도 그 축을 안 봤다」가 같은 라벨로 나간다.
        """
        return bool(self._held) or bool(self._unknown)

    def primary_source_failed(self):
        """그 축의 주(主) 판정자가 죽었다 — `blocks()` 의 셋째 조건.

        보조(모델 다양성) 손실은 여기 안 든다 — 그것은 `report()["degraded"]` 가
        공시하고 차단하지 않는다(헌장).
        """
        return any(primary for (_n, _w, primary) in self._sources_failed)

    def _has_gate_coercion(self):
        return any(gate for (_f, _a, _b, gate) in self._coerced)
```

그리고 `blocks()` 의 본문을 **동치로** 다시 쓴다(docstring 은 그대로 둔다 — 거기 적힌 계약과 양성 대조 인용이 여전히 참이다):

```python
        return self.items_unaccounted() or self.primary_source_failed()
```

`_degraded()` 는 손대지 않는다 — 이미 `self.blocks()` 를 부른다.

- [ ] **Step 5: `plugins/quality-gates/scripts/verdict.py` 를 고친다**

① 시그니처에 축을 하나 더한다. **`review_blocked` 바로 뒤**에 둔다 — 둘이 같은 원장에서 갈라져 나온 짝이라 읽는 쪽이 그 관계를 자리로 본다:

```python
def decide(*, defect=False, review_blocked=False, angle_absent=False,
           differential_text=None, extra_reasons=(), legacy_verdict=None):
```

② PR2 의 I2 주석 블록(「알려진 편차, 기록만 하고 여기서 고치지 않는다」로 시작해 `if review_blocked:` 앞까지)을 **통째로 지우고** 아래로 바꾼다. 그 주석은 이 PR 이 닫은 빚을 설명하는 글이라 남으면 거짓이 된다:

```python
    # 헌장 — 막는 것은 「항목이 소실됐거나 셀 수 없거나 주 판정자가 죽었을 때」다.
    # 모델 다양성 손실 같은 나머지 degrade 는 공시만 한다. 그래서 원장의
    # `degraded`(공시)가 아니라 차단 쪽 술어를 받는다.
    #
    # 그 셋은 **두 사유로 갈린다**(설계 §6.4.3). 앞 둘(소실·미상)은 항목을
    # «잃은» 것이라 `findings-lost` 이고, 셋째(주 판정자 사망)는 아무도 그 축을
    # «안 본» 것이라 `angle-absent` 다 — 각도가 `absent` 인 것과 같은 사실이다
    # (§6.3.5 의 표: 「도출이 잘못돼 아무도 안 불림 → 각도 absent」).
    # PR2 는 셋을 `findings-lost` 하나로 접고 있었고(I2 가 기록한 알려진 편차),
    # 그 분리에 필요한 공개 accessor 둘을 이 PR 이 `Ledger` 에 세웠다.
    # 호출자는 `review_blocked=ledger.items_unaccounted()` 와
    # `angle_absent=(각도 absent) or ledger.primary_source_failed()` 로 준다.
    if review_blocked:
        add("findings-lost")
    if angle_absent:
        add("angle-absent")
```

③ CLI 에 플래그를 더한다(`--review-blocked` 바로 뒤):

```python
    ap.add_argument("--angle-absent", action="store_true")
```

그리고 `decide(...)` 호출에 `angle_absent=args.angle_absent,` 를 **`review_blocked` 바로 뒤**에 더한다.

- [ ] **Step 6: 두 락이 통과하는지 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile shared/adjudication/adjudication.py plugins/quality-gates/scripts/verdict.py && echo "compile OK"
bash shared/tests/test_adjudication_behavior.sh; echo "rc=$?"
bash plugins/quality-gates/tests/test_verdict_vocabulary.sh; echo "rc=$?"
# 원장을 건드렸으므로 그 소비자 락 둘도 함께 — 「스위트는 닿은 소비자 전부를」
bash shared/tests/test_adjudication_wiring.sh; echo "rc=$?"
bash shared/tests/test_adjudication_consumed.sh; echo "rc=$?"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_synthesize_*adjudication*.py" -v 2>&1 | tail -5
bash shared/tests/test_docreview_route.sh; echo "rc=$?"
```

**기대** — 전부 rc=0. `test_verdict_vocabulary.sh` 는 `MISSING:` · `STALE:` · `OVERLAP:` 셋 다 빈 줄이어야 한다: `angle-absent` 가 이제 `decide()` 소스의 리터럴 `add("angle-absent")` 에서 **도출**되어 `produced` 쪽에 서고, 부채 목록에서는 빠졌다.

`docreview_route.py` 와 `synthesize_artifact_findings.py` 도 `Ledger` 소비자다 — 위 목록이 그것을 덮는다. 하나라도 RED 면 Task 1 의 baseline 과 **파일 이름 + 실패 줄 수**로 대조해 선재 RED 인지 이 Task 가 만든 것인지 가른다.

- [ ] **Step 7: 커밋**

```bash
git add shared/adjudication/adjudication.py shared/tests/test_adjudication_behavior.sh \
        plugins/quality-gates/scripts/verdict.py plugins/quality-gates/tests/test_verdict_vocabulary.sh
git commit -m "feat(shared,qg): blocks() 의 세 조건을 두 공개 술어로 가른다" \
  -m "항목 소실·미상은 findings-lost, 주 판정자 사망은 angle-absent 다 — 설계
§6.4.3 의 배정이고 PR2 의 I2 가 「공개 accessor 가 없어서」 접어 둔 자리다.
Ledger 에 items_unaccounted()·primary_source_failed() 를 세우고 blocks() 를
그 둘의 or 로 다시 썼다(값 동치, 8조합 전수 대조). verdict.decide() 에 축이
하나 늘어 부채 목록이 다섯에서 넷으로 줄었다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: 합성기 배선 — `--angles` 진입 한 줄 · AC11 양의 짝 · 명단 락 교체 완결

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`
- Modify: `tools/adjudication/check_wiring.py` (면제 줄번호 재앵커 — C4)
- Modify: `plugins/quality-gates/tests/test_angle_coverage.sh` (합성기 층 케이스 추가 — AC11 의 «값» 쪽)
- Delete: `plugins/quality-gates/tests/test_review_floor_lock.sh`

**Interfaces:**
- Consumes: Task 2 의 `angles.parse/check_self_adjudication/blocks/render`, Task 3 의 `Ledger.items_unaccounted/primary_source_failed` 와 `verdict.decide(angle_absent=…)`
- Produces: `synthesize_findings.py --angles <경로>` (기본 off) · stdout 꼬리에 `angles:` 블록

**⚠ 이 Task 는 Task 2·3 이 «둘 다» 끝난 뒤에만 돈다.** 셋 중 하나라도 빠지면 배선이 없는 이름을 부른다.

- [ ] **Step 1: 합성기 층 케이스를 `test_angle_coverage.sh` 에 더한다 (실패 상태로)**

`test_angle_coverage.sh` 의 헤더 아래에 `SYNTH` 를 세우고(PR2 락의 관용구와 같다), 케이스 함수들을 `case_…` 목록 **앞**에 넣고 호출부에도 이름을 더한다.

```bash
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"

# mk_inputs <디렉토리> — 판정 0 · finding 0 인 «깨끗한» 입력 한 벌.
# 이 벌을 기준으로 각도만 바꿔 가며 AC11·AC12 를 가른다: 각도 말고는 clean 을
# 막을 것이 아무것도 없어야 「각도가 막았다」가 입증된다.
mk_inputs() {
  printf 'verdicts: []\n' > "$1/adv.yaml"
  printf '[]\n' > "$1/f.yaml"
}

case_synth_angles_off_is_byte_prefix_of_on() {
  # `--angles` 를 안 주면 stdout 이 이 PR 이전과 같아야 한다(계획 R-E). rc 를
  # 먼저 재는 이유는 PR2 Ruling T6-a 와 같다 — 죽은 경로의 빈 출력은 어떤
  # 접두 검사도 트리비얼하게 통과시킨다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  local off on off_rc=0 on_rc=0
  off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict) || off_rc=$?
  on=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f") || on_rc=$?
  assert_eq "$off_rc" "0" "각도 없는 경로가 정상 종료한다"
  assert_eq "$on_rc"  "0" "각도 있는 경로가 정상 종료한다"
  assert_not_grep "$off" '^angles:$' "--angles 를 안 주면 angles: 블록이 없다"
  assert_grep     "$on"  '^angles:$' "--angles 가 angles: 블록을 켠다"
  assert_grep     "$on"  '^verdict: clean$' "셋 다 filled 면 clean 이다"
  rm -rf "$T"
}

case_synth_blocking_absent_is_not_certified() {
  # ★ AC11 의 **양의 짝**. 각도 coverage 락의 존재 이유가 이 케이스다 —
  # 「상태가 있는가」만 재는 락은 통째로 지워도 통과한다(음의 락). 부재가
  # 실제로 `clean` 을 «막는지» 를 여기서 관측한다.
  local T a b f out
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    T=$(mktemp -d); mk_inputs "$T"; f="$T/angles.txt"; : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
            --emit-verdict --angles "$f")
    assert_grep     "$out" '^verdict: not-certified$' "'$a' 가 absent 면 미판정 (AC11)"
    assert_grep     "$out" '^reason: angle-absent$'   "'$a' 의 사유가 angle-absent 다"
    assert_not_grep "$out" '^verdict: clean$'          "'$a' 가 absent 인데 clean 이 아니다"
    assert_grep     "$out" "^  $a: absent\$"           "그 부재가 산출물에 드러난다"
    rm -rf "$T"
  done <<< "$BLOCKING"
}

case_synth_different_premise_absent_stays_clean() {
  # AC12 — 모델 다양성 손실은 공시하고 막지 않는다. 위 케이스와 이 케이스가
  # **짝**이다: 하나만 두면 「전부 막는다」와 「전부 안 막는다」를 구별 못 한다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
                     --emit-verdict --angles "$f")
  assert_grep     "$out" '^verdict: clean$'               "다른 전제의 부재는 막지 않는다 (AC12)"
  assert_grep     "$out" '^  different-premise: absent$'  "그래도 공시된다"
  assert_not_grep "$out" '^reason: angle-absent$'         "사유가 서지 않는다"
  rm -rf "$T"
}

case_synth_self_adjudication_is_atomic_failure() {
  # AC10a 를 합성기 층에서. **그리고 fail4 의 원자성** — 실패 경로에서 stdout 이
  # 비어 있어야 한다. 비어 있지 않으면 rc 를 안 보는 줄-지향 소비자가 완전해
  # 보이는 보고서를 성공으로 읽는다(PR2 Ruling T5-b 가 산 자리).
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- {agent: security-reviewer, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>/dev/null) || rc=$?
  assert_eq "$rc" "4" "finding 을 낸 리뷰어에게 판정 각도를 접으면 exit 4 (AC10a)"
  assert_eq "$out" ""  "실패 경로의 stdout 이 비어 있다 (fail4 는 원자적이다)"
  rm -rf "$T"
}

case_synth_angles_flag_hygiene() {
  # PR2 의 I1 이 세 플래그에 건 대칭을 네 번째 플래그에도 건다. 안 걸면 값을
  # 구하고도 `--emit-verdict` 를 빼먹은 호출자가 rc=0 + 완전해 보이는 보고서를
  # 받고, 각도 축이 그 실행에서 빠졌다는 사실이 어느 채널에도 안 남는다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  local rc=0
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
    --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--angles 는 --emit-verdict 없이는 usage 오류(exit 2)"
  rc=0
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
    --emit-verdict --angles "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --angles 는 usage 오류(exit 2)"
  rm -rf "$T"
}

case_synth_primary_source_death_is_angle_absent() {
  # C3 의 **관측 가능한 결과**. 주 판정자(여기서는 `--findings` 가 가리키는 파일)가
  # 통째로 죽으면 그것은 「항목을 잃었다」가 아니라 「아무도 안 봤다」다 — PR2 는
  # 이 실행을 `findings-lost` 로 보고했다. `--angles` 없이도 서야 한다: 이 사유의
  # 산출자는 각도 파일이 아니라 원장이다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" \
                     --findings "$T/does-not-exist.yaml" --emit-verdict)
  assert_grep     "$out" '^verdict: not-certified$' "주 입력이 죽으면 미판정"
  assert_grep     "$out" '^reason: angle-absent$'   "사유가 angle-absent 다 (findings-lost 가 아니다)"
  assert_not_grep "$out" '^reason: findings-lost$'  "항목 소실로 오보고하지 않는다"
  rm -rf "$T"
}
```

호출부에 여섯 줄을 더한다(**함수만 쓰고 부르지 않으면 0단언이다** — PR2 의 pre-flight 가 잡은 결함 P5):

```bash
case_synth_angles_off_is_byte_prefix_of_on
case_synth_blocking_absent_is_not_certified
case_synth_different_premise_absent_stays_clean
case_synth_self_adjudication_is_atomic_failure
case_synth_angles_flag_hygiene
case_synth_primary_source_death_is_angle_absent
```

- [ ] **Step 2: 실패하는지 확인한다**

```bash
cd "$(git rev-parse --show-toplevel)"
bash plugins/quality-gates/tests/test_angle_coverage.sh; echo "rc=$?"
```

**기대** — rc≠0. `--angles` 를 모르는 argparse 가 exit 2 를 내므로 대부분이 실패하고, `case_synth_primary_source_death_is_angle_absent` 는 `reason: findings-lost` 를 관측해 실패한다.

- [ ] **Step 3: `synthesize_findings.py` 를 고친다 — 네 자리**

① import. `import verdict as _verdict` **바로 위**에 한 줄:

```python
import angles as _angles
```

② argparse. `--legacy-verdict` 바로 뒤:

```python
    # 각도 상태 — 기본 off. 오케스트레이터 배선은 PR4 다(계획 R-E). 안 주면
    # stdout 이 이 PR 이전과 바이트 동일하다.
    ap.add_argument("--angles", default=None)
```

③ 위생 검사 둘. `--legacy-verdict` 의 빈 문자열 검사 바로 뒤에 하나:

```python
    if args.angles is not None and args.angles == "":
        print("synthesize_findings.py: --angles 는 빈 문자열을 받지 않는다 "
              "(플래그를 생략하거나 실제 경로를 줘라)", file=sys.stderr)
        sys.exit(2)
```

그리고 `if not args.emit_verdict:` 블록 안, `--legacy-verdict` 갈래 뒤에 하나:

```python
        if args.angles is not None:
            print("synthesize_findings.py: --angles 는 --emit-verdict "
                  "없이는 의미가 없다 (함께 주거나 --angles 를 빼라)",
                  file=sys.stderr)
            sys.exit(2)
```

④ 판정 블록. 기존 `decision = None` … `)` 를 아래로 바꾼다. **`report = ledger.report()` 보다 앞**이라는 자리는 그대로 둔다(Ruling T5-b — `_angles.read_or_fail4` 의 fail4 가 여기서 터지면 stdout 이 아직 비어 있다):

```python
    decision = None
    angle_states = None
    if args.emit_verdict:
        # `report["degraded"]`(공시)가 아니라 차단 쪽 술어다 — 헌장은 모델 다양성
        # 손실 같은 degrade 를 공시만 하고 막지 않는다. 여기서 둘을 섞으면 이 PR 이
        # 조용히 게이트를 넓힌다.
        #
        # 차단 셋을 **두 사유로** 가른다(설계 §6.4.3): 항목 소실·미상은
        # `findings-lost`, 주 판정자 사망은 `angle-absent` — 아무도 그 축을 «안 본»
        # 것이라 각도가 `absent` 인 것과 같은 사실이다(§6.3.5 의 표).
        angle_absent = ledger.primary_source_failed()
        if args.angles is not None:
            angle_states = _angles.parse(_angles.read_or_fail4(args.angles))
            # AC10a — 수행자 집합은 이 실행이 실제로 «낸» finding 에서 도출한다
            # (계획 R-H). 각도 파일 자신에서 뽑으면 자기-일관성 검사이지 Law 2
            # 검사가 아니다. `sources`(dedup 이 병합하며 만든 목록) 우선, 없으면
            # `agent` — `render()` 가 Source 칼럼을 채울 때 쓰는 것과 **같은
            # 관용구**다. `kept` 가 아니라 `findings` 를 보는 이유: 억제된 것도
            # 「낸 것」이다(냈기 때문에 억제됐다).
            authors = set()
            for f in findings:
                srcs = f.get("sources") or [f.get("agent", "?")]
                if not isinstance(srcs, (list, tuple)):
                    srcs = [srcs]
                for s in srcs:
                    s = str(s)
                    if s and s != "?":
                        authors.add(s)
            _angles.check_self_adjudication(angle_states, authors)
            angle_absent = angle_absent or _angles.blocks(angle_states)
        decision = _verdict.decide(
            defect=bool(kept),                    # 계획 R-B — severity 를 묻지 않는다
            review_blocked=ledger.items_unaccounted(),
            angle_absent=angle_absent,
            differential_text=_verdict.read_or_none(args.differential),
            extra_reasons=args.reason,
            legacy_verdict=args.legacy_verdict,
        )
```

⑤ 출력. 파일 끝의 `if args.emit_verdict:` 를 아래로:

```python
    if args.emit_verdict:
        # `render()` 가 낸 Markdown 본문 **뒤**의 평문 꼬리다 — PR2 가 `verdict:`
        # 를 같은 자리에 같은 모양으로 붙였고(계획 R-J), 그래야 「off 출력은 on
        # 출력의 바이트 접두」가 유지된다. 각도가 판정보다 **앞**인 것은 읽는
        # 순서다: 무엇을 봤는지가 그 판정의 근거다.
        if angle_states is not None:
            sys.stdout.write(_angles.render(angle_states))
        sys.stdout.write(_verdict.render(decision))
```

- [ ] **Step 4: `check_wiring.py` 의 면제를 재앵커한다 (C4)**

③의 import 한 줄이 `synthesize_findings.py` 의 `dedup()` 을 한 줄 아래로 민다. `tools/adjudication/check_wiring.py` 의 `EXEMPT` 는 **줄번호를 키로** 쓴다 — 안 고치면 그 면제가 대상을 못 찾아 `test_adjudication_wiring.sh` 가 RED 다.

```bash
cd "$(git rev-parse --show-toplevel)"
grep -n "continue in dedup" tools/adjudication/check_wiring.py
grep -n "if f.get(\"promoted\")" plugins/quality-gates/scripts/synthesize_findings.py
```

두 번째 명령이 내는 **실측 줄번호**로 첫 번째의 키를 갱신한다(360 → 361 이 기대값이지만 **적힌 숫자가 아니라 잰 숫자를 쓴다**). 그 위 주석에는 **원인만** 적는다 — 과거 델타(`358→359`, `359→360`)를 되풀이하지 않는다. 그 파일이 이미 「줄번호는 매 재앵커마다 실측으로 갱신한다 … 과거 델타를 프로즈에 «다시» 못박지 않는다」고 적어 두었고, 델타를 쌓는 것이 그 경고가 가리키는 바로 그 함정이다. 한 줄이면 족하다:

```python
    # qg-angle-floor-pr3 Task 4 가 같은 import 블록에 `import angles as _angles`
    # 를 한 줄 더했다 — 인용 내용은 무변경.
```

- [ ] **Step 5: 명단 락을 지운다 — 교체가 끝난 뒤(§6.3.2)**

```bash
cd "$(git rev-parse --show-toplevel)"
git rm plugins/quality-gates/tests/test_review_floor_lock.sh
```

**교체 없는 삭제는 C13 위반이다.** 이 삭제가 합법인 근거는 Task 2 가 `test_angle_coverage.sh` 를 이미 들여놓았고 이 Task 의 Step 1 이 그 락에 «양의 짝»(부재가 `clean` 을 막는다)을 더했다는 것 — 그러므로 이 삭제는 **이 Task 의 커밋** 안에서만 성립한다. 앞 Task 로 옮기지 않는다.

**삭제 후 필수(§13 · AC21)** — 지운 락이 어떤 `# guards:` 글롭의 유일 대상이면 그 선언이 공허해진다:

```bash
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; echo "rc=$?"
```

- [ ] **Step 6: 통과 확인 — 닿은 소비자 전부**

```bash
cd "$(git rev-parse --show-toplevel)"
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile plugins/quality-gates/scripts/synthesize_findings.py && echo "compile OK"
bash plugins/quality-gates/tests/test_angle_coverage.sh;      echo "angle rc=$?"
bash plugins/quality-gates/tests/test_verdict_vocabulary.sh;  echo "verdict rc=$?"
bash plugins/quality-gates/tests/test_synthesize_findings.sh; echo "synth rc=$?"
bash plugins/quality-gates/tests/test_synthesize_disposition.sh; echo "disp rc=$?"
bash plugins/quality-gates/tests/test_synthesize_promoted_findings.sh; echo "promoted rc=$?"
bash shared/tests/test_adjudication_wiring.sh;   echo "wiring rc=$?"
bash shared/tests/test_adjudication_consumed.sh; echo "consumed rc=$?"
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; echo "guards rc=$?"
bash plugins/quality-gates/tests/test_runner_adapters.sh; echo "adapters rc=$?"
```

**기대** — `test_runner_adapters.sh` 를 뺀 전부가 rc=0.

**`test_runner_adapters.sh` 는 착수 시점에 이미 RED 다**(Task 1 의 baseline 이 그 사실과 **실패 줄 수 1**을 기록한다 — 사유는 「셸 어댑터가 claim 할 수 없는 테스트 스크립트 존재」). 이 Task 가 그 **실패 줄 수를 늘리면** 그것은 새 결함이다: 새 락의 실행 비트가 빠졌다는 뜻이다. `git ls-files -s plugins/quality-gates/tests/test_angle_coverage.sh` 가 `100755` 인지 확인한다. **rc 만 보면 이 회귀가 원리적으로 안 보인다** — 이미 RED 인 파일 안의 새 실패이기 때문이다.

같은 이유로 `test_codex_backward_compat.sh` 도 본다 — 그것은 스위트 전체를 다시 돌려 `codex-blessed-red.txt`(**현재 0항목**)와 대조하므로 **새 RED 가 하나라도 생기면 「미등재」로 보고**한다. 착수 시점의 그 RED 는 `test_runner_adapters.sh` 하나에서 온 것이고, 이 Task 뒤에도 **그 하나여야** 한다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py \
        plugins/quality-gates/tests/test_angle_coverage.sh \
        tools/adjudication/check_wiring.py
git commit -m "feat(qg): 합성기에 각도 축 진입 한 줄 — 명단 락을 각도 coverage 락으로 교체" \
  -m "AC11(부재가 clean 을 막는다) · AC12(다른 전제는 공시만). --angles 는 기본
off 라 안 주면 stdout 이 이전과 바이트 동일하다 — 오케스트레이터 배선은 PR4 다.
review_blocked 이 items_unaccounted() 로 좁아지고 주 판정자 사망이 angle-absent
로 갈라진다. 명단-리터럴 락(test_review_floor_lock.sh)은 교체가 끝난 이 커밋에서
지운다 — 앞 커밋에서 지우면 C13 위반이다. check_wiring 면제는 실측 줄번호로
재앵커했다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `diff` 선택 슬롯 (AC18) + 절단 완화책 한 문장 (C2)

**Files:**
- Modify: `shared/docreview/agents/doc-recritic.md` — 네 번째 슬롯 + 「이 변경이 도입했는가」 축
- Modify: `plugins/spec-distill/agents/doc-recritic.md` — 위의 **바이트 사본**(마커 줄 제외). **같은 커밋**
- Modify: `shared/tests/test_docreview_agents.sh` — 슬롯 리터럴
- Modify: doc-recritic 을 dispatch 하는 **모든** skill 의 「입력 슬롯은 정확히 셋이다」 산문
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` — C2

**Interfaces:**
- Consumes: 없음 — 이 Task 는 Task 2·3·4 와 **독립**이다(파일이 하나도 안 겹친다). 순서를 바꿔도 된다
- Produces: `doc-recritic` 의 네 슬롯 — `document` · `findings` · `profile` · `diff`(optional)

- [ ] **Step 1: 산문 자리를 «열거가 아니라 도출로» 찾는다**

「입력 슬롯은 정확히 셋이다」가 몇 군데 있는지 세어서 고치지 않는다 — 식별자가 아니라 개념이라 표기가 조금씩 다를 수 있다.

```bash
cd "$(git rev-parse --show-toplevel)"
echo "── doc-recritic 을 dispatch 하는 자리 (∀)"
grep -rn 'subagent_type: "[a-z-]*:doc-recritic"' plugins/ | sed 's/:.*//' | sort -u
echo "── 「셋」을 말하는 산문"
grep -rn '슬롯은 정확히 셋\|슬롯 정확히 셋\|정확히 셋' plugins/ shared/ | grep -v '^shared/tests/'
echo "── 슬롯 수를 못박는 락"
grep -rn "document', 'findings', 'profile'" shared/ plugins/
```

**세 목록을 보고서에 그대로 싣는다.** 첫 목록의 파일 전부가 산문 정정 대상 후보이고, 둘째가 실제 대상이며, 셋째가 락이다. 셋이 서로 다른 크기이면 그 차이 자체가 발견이다.

- [ ] **Step 2: 락을 먼저 움직인다 (실패 상태)**

`shared/tests/test_docreview_agents.sh` 의 슬롯 리터럴을 넷으로:

```bash
assert_eq "$SL" "['document', 'findings', 'profile', 'diff']" "doc-recritic: 입력 슬롯 정확히 넷 — diff 만 optional, dispatch 사유·이력·출처 라벨 슬롯 없음 (AC9 · AC18)"
```

같은 절에 **`diff` 만 optional 임을 못박는 단언**을 하나 더한다. 없으면 나중에 `document` 가 조용히 optional 이 돼도 이 락이 GREEN 이다 — 그러면 문서 없이 도는 재비판이 통과한다:

```bash
OPT="$(fm "$A/doc-recritic.md" '[s["tag"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"] if s.get("optional")]')"
assert_eq "$OPT" "['diff']" "doc-recritic: optional 인 슬롯은 diff 하나뿐 (나머지 셋은 필수)"
```

`KINDS` 단언(`['artifact', 'repo_context']`)은 **안 건드린다** — `diff` 의 `kind` 가 `repo_context` 이고 그 값은 `profile` 이 이미 쓰고 있어 집합이 안 바뀐다. 이 사실을 보고서에 적는다(안 바뀌는 것을 확인한 것과 안 본 것은 다르다).

```bash
bash shared/tests/test_docreview_agents.sh; echo "rc=$?"
```

**기대** — rc≠0, 슬롯 두 단언이 실패.

- [ ] **Step 3: 정본에 슬롯을 더한다**

`shared/docreview/agents/doc-recritic.md` 의 frontmatter `input_slots` **끝**에:

```yaml
  - tag: diff
    var: DIFF
    kind: repo_context
    optional: true
```

`kind: repo_context` 인 근거는 설계 §6.3.4 다 — 슬롯 `kind` 어휘가 이미 프레이밍과 자료의 선을 긋는다: `artifact` · `repo_context` 는 허용, `prior_verdict` · `orchestrator_framing` 은 **락으로 금지**. diff 는 「누가 무엇이라 했나」가 아니라 **대상**이라 `repo_context` 다.

본문의 「각 finding 에 대해」 절 안에, 처분을 정하는 기준 목록의 **끝**에 한 항목을 더한다:

```markdown
- **이 변경이 도입했는가** — `<diff>` 를 받았으면 그 변경이 실제로 이 결함을 «도입했는지» 를 본다. 선재 결함(변경 전에도 있었던 것)은 그 사실을 근거로 기각할 수 있다. **`<diff>` 를 못 받았으면 이 축을 쓰지 않는다** — 받지 않은 것을 추측해 기각하면 그것은 근거 없는 배제다.
```

**diff 는 프레이밍이 아니다.** 당신이 못 보아야 하는 것은 「왜 이 리뷰가 열렸나 · 앞 리뷰어가 무엇이라 했나」이고, diff 는 문서와 같은 층의 1차 자료다. 이 문장을 본문에 넣어 재비판자가 그 선을 스스로 알게 한다.

- [ ] **Step 4: 사본을 «손으로 고치지 않고 도출한다»**

사본은 마커 줄 하나를 뺀 **바이트 동일**이어야 한다(`test_copy_of_contract.sh` 가 `sed "<n>d" <사본> | diff - <정본>` 으로 잰다). 손으로 같은 편집을 두 번 하면 공백 하나가 갈린다 — 도출한다:

```bash
cd "$(git rev-parse --show-toplevel)"
SRC=shared/docreview/agents/doc-recritic.md
DST=plugins/spec-distill/agents/doc-recritic.md
head -n 1 "$SRC" > "$DST.new"
printf '# copy-of: %s\n' "$SRC" >> "$DST.new"
tail -n +2 "$SRC" >> "$DST.new"
mv "$DST.new" "$DST"
diff <(sed '2d' "$DST") "$SRC" && echo "사본 ≡ 정본 (마커 줄 제외)"
```

마커가 **2행**인 것은 현재 사본의 실측이다(`1a2`). 옮기기 전에 `head -3 "$DST"` 로 그 자리를 확인하고, 다르면 그 자리에 맞춘다.

- [ ] **Step 5: 산문을 정정한다 — Step 1 이 낸 목록 전부**

각 dispatch 자리의 「입력 슬롯은 정확히 셋이다」를 아래 취지로 바꾼다. **브리프·설계 경로는 diff 를 싣지 않는다**는 사실을 함께 적는다(AC18 후반):

> 입력 슬롯은 **넷**이고 그중 `diff` 는 **선택**이다 — 이 자리(문서 경로)는 `diff` 를 싣지 않는다. 싣는 것은 코드 경로뿐이고, 재비판자는 `diff` 를 못 받으면 「이 변경이 도입했는가」 축을 쓰지 않는다.

dispatch 펜스 자체는 **안 바꾼다** — 세 슬롯 그대로다. `optional` 이라 전달하지 않아도 `check_slots.py:224`(`if tag not in got and not s.get("optional")`)가 잡지 않는다.

- [ ] **Step 6: 절단 완화책 한 문장 (C2)**

`plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` 의 절단 안전성 문단 — 「이 구간을 판정 입력으로 읽는 소비자가 생기면 사정이 달라진다」로 시작하는 문장 뒤에 한 문장을 더한다. PR2 의 정정이 **완화책이 이미 있다는 사실**을 떨어뜨렸다:

> 그 소비자가 갖춰야 할 가드는 이미 한 자리에 있다 — `verdict.py` 의 `causes_of()` 는 그 키 줄이 **정확히 한 번** 나올 것을 요구하고, 0회면 `exit 4` 다. 즉 그 키를 읽는 소비자는 절단을 「원인 없음」이 아니라 실패로 본다. 새 소비자가 생길 때 이 요구를 함께 갖추지 않으면 그때 이 문단의 위험이 실현된다.

**금지 토큰 확인** — 정정 문장이 파일의 다른 락이 금지하는 문구를 되살리지 않는지 본다(PR2 가 같은 자리에서 한 번 확인한 것):

```bash
bash plugins/quality-gates/tests/test_impact_runtime_docs.sh; echo "rc=$?"
bash plugins/quality-gates/tests/test_skill_reference_pointers.sh 2>/dev/null || \
  bash shared/tests/test_skill_reference_pointers.sh; echo "rc=$?"
```

- [ ] **Step 7: 통과 확인 — 닿은 소비자 전부**

```bash
cd "$(git rev-parse --show-toplevel)"
bash shared/tests/test_docreview_agents.sh;     echo "agents rc=$?"
bash shared/tests/test_copy_of_contract.sh;     echo "copyof rc=$?"
bash shared/tests/test_agent_input_slots.sh;    echo "slots rc=$?"
bash shared/tests/test_dispatch_disposition.sh; echo "dispatch rc=$?"
bash shared/tests/test_docreview_profiles.sh;   echo "profiles rc=$?"
bash shared/tests/test_docreview_golden.sh;     echo "golden rc=$?"
for f in plugins/spec-distill/tests/*.sh; do o=$(bash "$f" 2>&1); r=$?; [ $r -ne 0 ] && echo "RED $f rc=$r"; done; echo "spec-distill done"
```

**기대** — 전부 rc=0. `test_agent_input_slots.sh` 는 특히 `no_declaration=0` · `problems_other=0` · `exempt_total <= exempt_baseline` 셋을 봐야 한다. `problems_other` 가 늘면 `optional` 표기가 판정기에 안 닿은 것이다.

- [ ] **Step 8: 커밋**

```bash
git add shared/docreview/agents/doc-recritic.md plugins/spec-distill/agents/doc-recritic.md \
        shared/tests/test_docreview_agents.sh \
        plugins/spec-distill/skills/reviewing-brief/SKILL.md \
        plugins/spec-distill/skills/reviewing-spec/SKILL.md \
        plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md
# Step 1 이 찾은 자리가 더 있으면 함께 add 한다 — 사본과 정본은 반드시 같은 커밋이다.
git commit -m "feat(docreview): 재비판자에 diff 선택 슬롯 — 「이 변경이 도입했는가」 축" \
  -m "AC18. diff 는 kind=repo_context 이고 optional 이다 — 문서 경로(브리프·설계)는
싣지 않고 코드 경로만 싣는다. 못 받으면 그 축을 쓰지 않는다(받지 않은 것을 추측해
기각하는 것은 근거 없는 배제다). 프레이밍 맹목성과 충돌하지 않는 이유는 diff 가
출처가 아니라 대상이기 때문이다. 사본은 손으로 고치지 않고 정본에서 도출했다.
함께: runtime-gate.md 의 절단 문단이 완화책(causes_of 의 정확히-한-번)을 밝힌다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: mutation — 네 축 × 양성 대조

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/pr3-mutations.md` (보고용. **리포에 커밋하지 않는다**)
- Modify: 변이가 구멍을 드러내면 그 락 (같은 Task 안에서 닫는다)

**Interfaces:**
- Consumes: Task 2·3·4·5 의 락 전부
- Produces: 측정된 변이 표. **PR 본문에 그대로 실린다**(이 파일은 PR 뒤에 사라지므로 포인터를 남기지 않는다)

**★ 이 Task 의 계약 — 아래 표의 「기대」는 «가설»이다, 증명서가 아니다.**

앞 PR 에서 변이 표의 **여섯 행**이 「이 변이가 RED 를 낸다」고 적어 놓고 실제로는 GREEN 이었다. 표에 적힌 것이 아니라 **관측한 것**이 결과다. 관측이 기대와 다르면 **그 자리에서 락을 고치고 다시 잰다** — 표의 기대값을 관측에 맞춰 내리지 않는다. 이빨 없는 락은 없는 것보다 나쁘다(증명서가 붙어 있어 아무도 다시 안 본다).

- [ ] **Step 1: 계측기를 먼저 검증한다 — 양성 대조**

변이 도구 자체가 고장 나면 모든 RED 가 거짓이고 모든 GREEN 도 거짓이다. 먼저 **반드시 RED 를 내야 하는 변이** 하나를 태워 계측기가 살아 있음을 본다.

```bash
cd "$(git rev-parse --show-toplevel)"
export PYTHONDONTWRITEBYTECODE=1
# 양성 대조 — `ANGLES` 에서 각도 하나를 지운다. 총 함수의 모집단이 줄어드는
# 변이라 `case_every_angle_is_required` 가 «반드시» 무너져야 한다.
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("plugins/quality-gates/scripts/angles.py")
s = p.read_text(encoding="utf-8")
s2 = s.replace('ANGLES = ("security", "adjudication", "different-premise")',
               'ANGLES = ("security", "adjudication")')
assert s2 != s, "양성 대조 변이가 적용되지 않았다 — blast radius 0 (계측기 고장)"
p.write_text(s2, encoding="utf-8")
PY
bash plugins/quality-gates/tests/test_angle_coverage.sh >/dev/null 2>&1; echo "양성대조 rc=$? (0 이면 계측기 고장)"
git checkout HEAD -- plugins/quality-gates/scripts/angles.py
git diff HEAD --stat -- plugins/quality-gates/scripts/angles.py   # 비어야 복원 완료
```

**`rc=0` 이면 멈춘다.** 계측기가 고장 났거나 락이 vacuous 하다 — 아래 표를 재는 것이 무의미하다. **복원은 `git checkout HEAD -- <경로>` 다**(`git checkout -- <경로>` 는 index 로 되돌리므로 변이를 `git add` 했다면 복원되지 않는다). 매 변이 뒤 `git diff HEAD --stat` 이 비었는지 본다.

- [ ] **Step 2: 네 축 × blast radius 를 잰다**

각 변이마다 **①적용됐는지(blast radius ≠ 0)** → **②락을 돌린다** → **③복원하고 확인한다** 순서다. ①을 빼면 「안 적용된 변이가 GREEN」을 「락이 이빨이 없다」로 오독한다.

| # | 축 | 대상 | 변이 | 기대(가설) | 관측 |
|---|---|---|---|---|---|
| 1 | 삭제 | `angles.py` | `parse()` 의 `missing` 블록(총 함수 강제) 제거 | `case_every_angle_is_required` RED | |
| 2 | 삭제 | `angles.py` | `check_self_adjudication()` 의 `fail4` 줄 제거 | `case_self_adjudication_is_rejected` · `case_synth_self_adjudication_is_atomic_failure` RED | |
| 3 | 변형 | `angles.py` | `BLOCKING_ANGLES` 에 `"different-premise"` 추가 | `case_blocking_angles_are_exactly_two` · `case_synth_different_premise_absent_stays_clean` RED | |
| 4 | 변형 | `angles.py` | `BLOCKING_ANGLES` 를 `()` 로 | `case_blocking_angles_are_exactly_two` · `case_synth_blocking_absent_is_not_certified` RED | |
| 5 | 변형 | `angles.py` | `SELF_ADJUDICATION_FORBIDDEN` 에 `"security"` 추가 | `case_security_angle_may_fold_into_its_own_author` · `case_forbidden_set_is_adjudication_only` RED | |
| 6 | 변형 | `angles.py` | `_validated_state` 의 `folded_into:` 빈-수행자 검사 제거 | `case_state_grammar_is_closed` RED | |
| 7 | 변형 | `angles.py` | `read_or_fail4` 의 `except UnicodeDecodeError` 절 제거 | `case_non_utf8_is_fail_closed` RED | |
| 8 | 변형 | `angles.py` | `render()` 가 `absent` 인 각도를 건너뛰게 | `case_absent_non_blocking_angle_discloses_only` · `case_synth_blocking_absent_is_not_certified` RED | |
| 9 | 추가 | `angles.py` | `parse()` 에 「중복이면 마지막이 이긴다」 추가(중복 검사 제거) | `case_duplicate_angle_is_fail_closed` RED | |
| 10 | 삭제 | `adjudication.py` | `items_unaccounted()` 가 `primary_source_failed()` 도 포함하게(옛 `blocks()` 로 되돌림) | `test_adjudication_behavior.sh` 의 「주 source 실패는 primary_source_failed 만」 RED · `case_synth_primary_source_death_is_angle_absent` RED | |
| 11 | 변형 | `adjudication.py` | `primary_source_failed()` 의 `any(...)` → `all(...)` | 혼합 케이스 RED (기존 「any→all 계측기」 단언) | |
| 12 | 삭제 | `verdict.py` | `if angle_absent: add("angle-absent")` 제거 | `case_angle_absent_is_not_certified` · `case_reason_enum_is_closed_and_accounted`(MISSING) · AC11 합성기 케이스 RED | |
| 13 | 변형 | `verdict.py` | `angle_absent` 를 `review_blocked` 와 같은 사유로 접음(`add("findings-lost")`) | `case_angle_absent_is_not_certified` · `case_angle_absent_and_findings_lost_are_distinct` RED | |
| 14 | 불일치 | `synthesize_findings.py` | `review_blocked=ledger.blocks()` 로 되돌림 | `case_synth_primary_source_death_is_angle_absent` RED | |
| 15 | 불일치 | `synthesize_findings.py` | `angle_absent` 에서 `_angles.blocks(...)` 항 제거(원장 항만 남김) | `case_synth_blocking_absent_is_not_certified` RED | |
| 16 | 불일치 | `synthesize_findings.py` | `authors` 를 `kept` 에서 도출(억제분 제외) | 억제된 finding 의 저자로 접는 케이스가 GREEN 이 된다 — **오늘 그 케이스가 없다**(아래 ★) | |
| 17 | 추가 | `synthesize_findings.py` | `--angles` 없이도 `angles:` 를 내게 | `case_synth_angles_off_is_byte_prefix_of_on` RED | |
| 18 | 삭제 | `doc-recritic.md` | `optional: true` 제거 | `test_agent_input_slots.sh` 의 `problems_other` ↑ (세 dispatch 자리가 diff 미전달) · 새 `OPT` 단언 RED | |
| 19 | 변형 | `doc-recritic.md` | `kind: repo_context` → `prior_verdict` | `test_docreview_agents.sh` KINDS · `test_agent_input_slots.sh` forbidden_kind RED | |
| 20 | 불일치 | 사본 | `plugins/spec-distill/agents/doc-recritic.md` 에서 `diff` 슬롯만 제거 | `test_copy_of_contract.sh` RED | |

**★ 16번 행은 「구멍을 이름으로 낸다」** — 오늘 락에는 「억제된 finding 의 저자에게 판정 각도를 접으면 RED」 케이스가 없다. 16번을 재서 **GREEN 이 관측되면 그것이 확인된 구멍이고, 이 Task 가 그 케이스를 더해 닫는다**(계획 R-H 가 억제분을 세기로 정했으므로 락이 그 결정을 지켜야 한다). 관측 없이 「닫았다」고 적지 않는다.

- [ ] **Step 3: 구멍을 닫고 다시 잰다**

기대가 RED 인데 GREEN 이 관측된 행 전부에 대해:

1. **왜 안 걸렸는지 한 줄로 적는다** — 락의 앵커가 변이가 건드린 자리를 안 보는가, 픽스처 분포가 그 분기를 안 태우는가, 아니면 단언이 트리비얼하게 참인가.
2. 그 자리를 **락에서** 고친다(제품 코드가 아니라).
3. 같은 변이를 다시 태워 **RED 를 관측**한다.
4. 표의 「관측」 칸에 최종값을 적는다.

- [ ] **Step 4: GREEN-기대 변이 — 이빨이 과하지 않은지**

통과가 정답인 단언은 모양으로 이빨을 판별할 수 없다. 아래 둘은 **GREEN 이 기대값**이고, RED 가 나오면 락이 정상 경로를 막고 있는 것이다.

| # | 변이 | 기대 |
|---|---|---|
| G1 | `angles.py` 의 `ANGLES` 튜플 **순서만** 바꾼다 | 순서는 출력 순서일 뿐이므로 `test_angle_coverage.sh` 는 GREEN (각 각도의 줄을 개별 정규식으로 보므로) — RED 면 락이 순서에 과적합됐다 |
| G2 | `doc-recritic.md` 본문의 「이 변경이 도입했는가」 항목 **표현만** 바꾼다(뜻 유지) | `test_docreview_agents.sh` GREEN — RED 면 락이 산문 리터럴에 붙어 있다(피검자가 쥔 앵커) |

**G1 이 RED 면** 그것은 결함이 아니라 **설계 선택의 노출**이다: `ANGLES` 순서가 출력 순서이므로 순서를 바꾸는 것은 산출물 형식을 바꾸는 것이다. 그때는 표의 기대를 RED 로 고치고 **왜 그것이 정당한지**를 적는다 — 관측에 맞춰 조용히 내리지 않는다.

- [ ] **Step 5: 보고서를 쓴다 — 포인터가 아니라 내용**

`$CLAUDE_JOB_DIR/tmp/pr3-mutations.md` 에 **완성된 표**(20 + 2 행, 관측 칸 전부 채움)와 각 구멍의 한 줄 진단을 적는다. 이 파일은 PR 이 끝나면 사라지므로 **PR 본문이 표를 그대로 싣는다** — 「자세한 것은 <경로>」라고 적지 않는다. 사라질 경로를 가리키는 것은 기록이 아니다.

- [ ] **Step 6: 커밋 (락 수정이 있었다면)**

```bash
git status --porcelain      # 제품 코드가 dirty 면 복원이 안 끝났다 — 멈춘다
git diff HEAD --stat
git add plugins/quality-gates/tests/ shared/tests/
git commit -m "test(qg,shared): 변이가 드러낸 락의 구멍을 닫는다" \
  -m "<어느 행이 GREEN 이었고 왜였는지 · 무엇을 고쳤는지>" \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

변이로 드러난 구멍이 0 이면 **커밋할 것이 없다** — 그때는 보고서에 「20행 전부 기대대로」를 **관측 로그와 함께** 적는다. 앞 PR 에서 여섯 행이 거짓이었으므로, 0 이라는 결과는 그 자체로 한 번 더 의심할 값이다.

---

### Task 7: 회귀 · 범위 불변식 · bump · CHANGELOG · PR

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: Task 1 의 `pr3-baseline.tsv`, Task 6 의 완성된 변이 표
- Produces: PR

- [ ] **Step 1: 회귀 스위트 전량 — baseline 과 «행 단위로» 대조**

```bash
cd "$(git rev-parse --show-toplevel)"
OUT="${CLAUDE_JOB_DIR:-/tmp}/tmp/pr3-final.tsv"
: > "$OUT"
for f in plugins/quality-gates/tests/*.sh shared/tests/*.sh plugins/spec-distill/tests/*.sh; do
  [ -f "$f" ] || continue
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$f" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗' || true)"
  printf '%s\t%s\t%s\n' "$f" "$rc" "$n" >> "$OUT"
done
echo "── baseline 대비 diff (새 파일 · rc 변화 · 실패 줄 수 변화 전부)"
diff "${CLAUDE_JOB_DIR:-/tmp}/tmp/pr3-baseline.tsv" "$OUT" || true
```

**기대** — diff 는 **정확히 두 종류**만 보인다:

1. `test_angle_coverage.sh` 가 **추가**된 행 (rc=0)
2. `test_review_floor_lock.sh` 가 **삭제**된 행

그 밖의 모든 변화는 **회귀다.** 특히:

- **rc 가 그대로여도 실패 줄 수가 늘면 회귀다.** `test_runner_adapters.sh` 와 `test_codex_backward_compat.sh` 는 착수 시점에 이미 RED 이므로 rc 로는 안 보인다 — 세 번째 칸을 본다.
- `test_codex_backward_compat.sh` 는 `codex-blessed-red.txt`(0항목)와 대조해 **새 RED 를 「미등재」로 보고**한다. 그 파일의 실패 줄 수가 늘었으면 어딘가에 새 RED 가 생긴 것이다.

파이썬 테스트도 돈다:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -5
```

- [ ] **Step 2: 범위 불변식 — 건드린 파일이 계획의 집합 안인가**

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin --quiet
git diff --name-only origin/main...HEAD | sort
```

「파일 구조」 표 밖의 경로가 나오면 **왜 나왔는지 보고서에 적는다.** 특히 Task 1 Step 3 이 금지한 다섯(=`agents/**` · `SKILL.md` · `qg.md` · `diff-test-results.py` · `marketplace.json`/루트 `CLAUDE.md`)이 나오면 그것은 이 PR 의 범위 이탈이고 되돌린다.

- [ ] **Step 3: base 가 움직였으면 merge 한다 (rebase 아님)**

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-list --count HEAD..origin/main
git log --oneline HEAD..origin/main | head -20
git diff --name-only HEAD...origin/main | sort > /tmp/pr3-theirs.txt
git diff --name-only origin/main...HEAD | sort > /tmp/pr3-ours.txt
comm -12 /tmp/pr3-theirs.txt /tmp/pr3-ours.txt      # 겹치는 파일 = 위험 자리
```

겹치는 파일이 있으면 **머지 전과 후로 스위트를 두 번** 돌린다 — 한 번은 이 PR 의 기여를 격리하기 위해, 한 번은 통합이 아무것도 깨지 않았음을 보이기 위해. `git merge origin/main` 을 쓴다. **rebase 금지.**

`plugin.json` 이 겹침 목록에 **안 나오는데** 다른 쪽도 그것을 건드렸으면 그것이 위험 신호다 — 같은 버전 문자열은 충돌 없이 병합된다.

- [ ] **Step 4: 버전을 «지금» 정한다 — origin/main 을 다시 보고**

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin --quiet
git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json | grep '"version"'
git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'
```

**규칙(숫자가 아니라 도출)**:

- `quality-gates` — 관측한 값에서 **minor** 를 올린다. 새 표면이 둘 늘었다(`scripts/angles.py` · `--angles` 플래그)고 major 가 아닌 이유: `--angles` 는 기본 off 이고 그것 없이 부른 stdout 이 바이트 동일이라 **기존 호출자가 하나도 안 깨진다**. `Ledger` 의 사적 이름 개명도 공개 표면 변경이 아니다.
- `spec-distill` — 관측한 값에서 **minor** 를 올린다. `shared/docreview` 의 agent 표면이 바뀌었고 설계 Metadata 가 「minor 이상」을 요구한다. 슬롯이 optional 이라 기존 dispatch 가 안 깨지므로 major 가 아니다.
- 관측한 값이 이 브랜치가 기대한 것과 다르면(예: PR2 가 먼저 머지돼 8.3.1 이 됐다면) **관측값 기준으로** 올린다. 브랜치에 적어 둔 숫자를 쓰지 않는다 — 먼저 머지되는 쪽이 이기고, 같은 문자열은 충돌 없이 병합된다.

- [ ] **Step 5: CHANGELOG 둘**

`plugins/quality-gates/CHANGELOG.md` 최상단(`## [8.3.1]` 위)에:

```markdown
## [<정한 버전>] — <오늘 날짜>

각도 바닥 — 세 각도의 상태가 총 함수가 되고, 보안·판정의 부재가 `clean` 을 막는다 (설계 §6.3, AC10 · AC10a · AC11 · AC12). **호출자 배선은 PR4 다** — `--angles` 를 안 주면 stdout 은 이전과 바이트 동일하다.

### Added

- **`scripts/angles.py`** — 각도 이름 셋(`security` · `adjudication` · `different-premise`)과 상태 문법(`filled` · `folded_into:<수행자>` · `absent`)의 소유자. 상태는 **총 함수**라 하나라도 없으면 `exit 4` 다(AC10). 판정 각도를 그 실행에서 finding 을 «낸» 리뷰어에게 접으면 `exit 4`(AC10a) — 보안 각도에는 걸지 않는다. 각도는 에이전트가 아니므로 이 모듈은 수행자 명단을 갖지 않는다.
- **`synthesize_findings.py --angles <경로>`** — 기본 off. 주면 `angles:` 블록을 `verdict:` 앞에 싣고 부재를 판정에 반영한다. `--emit-verdict` 없이 주거나 빈 문자열이면 `exit 2`(PR2 의 I1 이 세 플래그에 건 대칭을 네 번째에도).
- **`tests/test_angle_coverage.sh`** — §6.3.2 의 ∀ 총 함수 + **양의 짝**(부재 + `clean` = RED). `test_review_floor_lock.sh` 의 교체다.
- **`Ledger.items_unaccounted()` · `Ledger.primary_source_failed()`**(`shared/adjudication/`) — `blocks()` 가 접고 있던 세 조건을 두 술어로 가른다. `blocks()` 는 그 둘의 `or` 로 **값 동치**(8조합 전수 대조).

### Changed

- **`verdict.decide()` 에 축이 하나 늘었다(`angle_absent`).** 주 판정자 사망이 이제 `findings-lost` 가 아니라 `angle-absent` 로 나간다 — 설계 §6.4.3 의 배정이고 PR2 의 I2 가 「공개 accessor 가 없어서」 접어 둔 자리다. 항목 소실·미상은 그대로 `findings-lost` 다. 호출자-전용 부채가 **다섯에서 넷**으로 줄었다(남은 넷: `trivia` · `kill-switch` · `declaration-invalid` · `merge-conflict` — 전부 PR4).
- **`references/runtime-gate.md`** — 절단 문단이 완화책을 밝힌다(`verdict.causes_of()` 의 「정확히 한 번」이 0회 절단을 `exit 4` 로 잡는다).

### Removed

- **`tests/test_review_floor_lock.sh`** — 명단-리터럴 락. 앵커가 SKILL.md 산문이라 **피검자가 쥐고 있었다**. `test_angle_coverage.sh` 가 그 자리를 대신하며, 앵커는 합성기가 쓰는 모듈의 ∀ 관계다. 교체와 삭제는 같은 커밋이다(§6.3.2 — 교체 없는 삭제는 C13 위반).
```

`plugins/spec-distill/CHANGELOG.md` 최상단에:

```markdown
## [<정한 버전>] — <오늘 날짜>

### Added

- **`agents/doc-recritic.md` 에 `diff` 선택 슬롯**(`kind: repo_context`, `optional: true`) — 재비판자가 「이 변경이 도입했는가」 축을 쓸 수 있다(설계 §6.3.4, AC18). **이 플러그인의 문서 경로(브리프·설계)는 `diff` 를 싣지 않는다** — 싣는 것은 코드 경로뿐이고, 못 받으면 재비판자는 그 축을 쓰지 않는다. 정본은 `shared/docreview/agents/doc-recritic.md` 이고 이 파일은 그 바이트 사본이다.
```

```bash
bash shared/tests/test_changelog_integrity.sh; echo "rc=$?"
```

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json
git commit -m "chore(plugins): qg <버전> · spec-distill <버전> — 각도 바닥 · diff 슬롯" \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr3
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: PR 을 연다**

```bash
git push -u origin HEAD
gh pr create --base main --title "qg 각도 바닥 — 세 각도 총 함수 · 명단 락 교체 · diff 선택 슬롯 (PR3/5)" --body-file <(cat <<'BODY'
…아래 목차대로…
BODY
)
```

**PR 본문에 반드시 들어가는 것:**

1. **한 줄 요약** — 무엇이 바뀌고 무엇이 안 바뀌는가(`--angles` 없이는 stdout 바이트 동일).
2. **이 PR 이 지는 AC** — AC10 · AC10a · AC11 · AC12 · AC18, 각각 어디서 집행되는가.
3. **의존** — PR2(#166)가 `main` 에 있어야 한다. Task 1 의 확증 결과를 그대로 싣는다.
4. **계획이 내린 판정 일곱(R-D … R-J)** + **PR2 에서 상속한 셋(R-A · R-B · R-C)** — 각각 무엇을 정했고 틀리면 무엇을 치르는가. **사용자가 뒤집을 수 있는 자리다.** 특히 **R-D**(§16 의 PR3 행을 좁혀 사본·AC17·AC22·변환 계층을 PR4 로 넘긴다)와 그 근거가 된 **측정된 반증**(`test_dispatch_disposition.sh` 의 이름-키 사각지대)을 빠뜨리지 않는다.
5. **변이 표 전문** — Task 6 의 20 + 2 행, 관측 칸 전부. **포인터가 아니라 표 자체**를 싣는다(`$CLAUDE_JOB_DIR` 은 PR 뒤에 사라진다).
6. **선재 RED** — 착수 시점 둘(`test_runner_adapters.sh` · 그 하류 `test_codex_backward_compat.sh`)과 종료 시점이 같다는 측정. rc 와 **실패 줄 수** 둘 다.
7. **부채 원장** — 아래 절을 그대로 싣는다.

마지막 줄:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

- [ ] **Step 8: 머지는 사용자가 한다**

`gh pr merge` 는 auto-mode 판정기가 막는다. 사용자에게 `! gh pr merge <n> --merge` 를 안내하고, **`gh api` 우회는 쓰지 않는다.** `MERGED` 는 직접 확인한다 — 성공 시 무출력이라 차단과 구별되지 않는다.

---

## 부채 원장 — 미룬 것은 전부 여기 이름이 있다

**미루는 것과 버리는 것은 다르다.** 이 절이 그 차이를 지킨다. 각 항목에 **소유자**와 **무엇이 그것을 떨어뜨리지 못하게 하는가**를 적는다.

| 부채 | 소유자 | 무엇이 붙잡고 있는가 |
|---|---|---|
| **`angle-absent` 를 «항상» 싣기** — 이 PR 의 `--angles` 는 기본 off 라 오케스트레이터가 안 주면 각도 축이 그 실행에서 통째로 빠진다 | **PR4** | `test_angle_coverage.sh` 의 헤더 주석이 「오늘 배선이 안 된 것」으로 이름을 댄다 + 이 표 |
| **`trivia` 의 발화 지점** (AC2 · C4 의 두 탈출구 중 하나) | **PR4** | `test_verdict_vocabulary.sh` 의 `debt` 리터럴 — 기계가 검사한다. 산출자가 생기면 `OVERLAP` 이 RED 로 「부채 목록에서 지워라」를 알린다 |
| **`kill-switch` 의 발화 지점** (AC9) ★C1 | **PR4** | 같은 `debt` 리터럴. **PR2 계획 산문이 이 이름을 빠뜨렸던 자리다** — 그래서 기계가 검사하는 자리에만 의존한다 |
| **`declaration-invalid` 의 발화 지점** (AC16 후반) | **PR4** | 같은 `debt` 리터럴 |
| **`merge-conflict` 의 발화 지점** (AC7) | **PR4** | 같은 `debt` 리터럴 |
| **AC17** — 탐지 0건이어도 재비판 디스패치 + 「탐지 0 · 재비판 0」을 산출물에 명시 | **PR4** | 이 표 + §6.3.3. 락이 아직 없다 — **PR4 계획이 그 락을 세워야 한다** |
| **AC22** — 사본 집합 = 디스패치 집합(양방향 ∀) | **PR4** | 이 표 + R-D 의 측정 기록. ★**기존 락은 이것을 조금도 지지 않는다**(`test_dispatch_disposition.sh` 의 이름-키 사각지대) — 새 락이 양방향 전부를 져야 한다 |
| **§6.3.4 의 변환 계층** — `f`↔`finding_id` 역매핑 · `added`→`new_findings` · `raise`/`to` 강제 계수 | **PR4** | 이 표 + §6.3.4. 없으면 재비판자의 기각이 원래 finding 에 반영되지 않고 `added` 가 누락된다 |
| **`adversarial.md` 제거** — SKILL.md 의 dispatch 블록과 **같은 커밋**(§12) | **PR4** | 이 PR 이 `test_review_floor_lock.sh` 를 지운 것이 **선결 조건**이다 — 그 락이 `subagent_type: "quality-gates:adversarial"` 리터럴을 SKILL.md 에 못박고 있었다 |
| **AC23** — 옛↔새 매핑표(`verdict.py` 의 `LEGACY_VERDICTS` 블록) 제거 | **PR4** | 블록 양 끝의 `── AC23` 주석 + AC23 자신(PR5 시점에 남아 있으면 실패) |
| **PR1 이월 둘** — `--sort=refname` 미고정 · `origin/HEAD`/base-remote-ref 전용 락 없음 | **PR4** | PR1 의 PR 본문 + 이 표. 배선이 그 스크립트를 실제로 부를 때 값이 생긴다 |
| **§13 수동 e2e** — `Spec:` 트레일러 단 브랜치 둘로 실제 `/qg` 실행 | **PR5** | §13 + 이 표. 자동 락이 못 재는 것(실제 디스패치가 일어나는지 · 산출물이 사람에게 읽히는지) |
| **§15-4 의 한계** — 각도 coverage 락은 형식적 완전성만 잰다. 모델이 셋 다 `folded_into:` 로 주장하면 GREEN | **해소하지 않는다** | 설계가 명시적으로 수용한 한계. `test_angle_coverage.sh` 의 헤더가 이것을 **자기 주석에 공시**한다(§15-4 가 요구한 그대로) |
| **AC10a 가 못 가르는 것** — 「수행자 X 가 돌았는데 아무것도 못 찾았다」와 「X 가 애초에 안 불렸다」는 합성기 입력만으로 구별되지 않는다(`agent:` 는 finding 에만 붙는다) | **PR4** | 이 표. 각도 파일을 쓰는 것이 오케스트레이터이므로 그 구별은 오케스트레이터가 진다 — 합성기는 그 선언을 검사할 뿐이다 |
| **`check_wiring.py` 의 줄번호-키 면제 취약성** | **해소하지 않는다(구조적)** | 매 PR 이 재앵커한다. 그 파일 자신이 「줄번호는 매 재앵커마다 실측으로 갱신한다」를 적고 있고, 이 PR 의 Task 4 Step 4 가 그것을 따른다 |

---

## Self-Review

**1. Spec coverage.** §6.3.1(각도 셋 · 비대칭) → Task 2. §6.3.2(교체 락의 앵커 · 음의 짝의 양의 짝) → Task 2 + Task 4. §6.3.4(diff 슬롯) → Task 5 — **단 그 절의 변환 계층은 PR4 로 넘긴다**(R-D). §6.3.5(처분 회계의 기대값 앵커) → 각도 셋이 새 앵커라는 것은 Task 2·4 가 구현하지만 **처분 줄 자체**(`fail-closed` 로의 전환)는 dispatch 자리에 붙으므로 PR4 다. §15-4(한계 공시) → Task 2 의 락 헤더. §13 의 mutation 네 축 + 양성 대조 → Task 6. §13 의 선재 RED 기준선 → Task 1·7. **남는 것:** AC17 · AC22 · AC23 · AC1~AC7 · AC13~AC16 · AC19~AC21 은 이 PR 밖이고 전부 부채 원장에 소유자가 있다.

**2. Placeholder scan.** 지시를 미루는 표현(「TBD」·「적절히 처리」·「Task N 과 비슷하게」)이 없다 — 반복되는 코드는 반복해서 적었다. 코드가 필요한 자리는 전부 코드가 있다. **버전 번호만 `<정한 버전>` 이고 그것은 의도다** — §16 과 리포 규약이 「머지 직전에 정한다」를 요구하고, Task 7 Step 4 가 숫자가 아니라 **도출 규칙**을 준다. 변이 표의 「관측」 칸이 빈 것도 의도다 — 그것은 측정할 자리이지 미리 적을 자리가 아니다(앞 PR 이 여섯 행을 미리 적었다가 전부 거짓이었다).

**3. Type consistency.**
- `angles.parse()` 의 반환 `dict[str, str]` 를 `check_self_adjudication`·`blocks`·`render` 셋이 받는다 — Task 4 의 합성기 호출이 같은 값을 셋에 넘긴다.
- `verdict.decide()` 의 키워드 인자가 **여섯**이 되고(Task 3), Task 4 의 합성기 호출이 여섯을 이름까지 맞춘다. 그 수는 `test_verdict_vocabulary.sh` 의 `AXES:` 단언이 기계로 검사한다 — 한쪽만 늘면 RED 다.
- `Ledger.items_unaccounted()`/`primary_source_failed()` 는 Task 3 이 만들고 Task 4 가 부른다. `blocks()` 는 값 동치라 **다른 소비자**(`docreview_route.py` · `synthesize_artifact_findings.py`)가 안 깨진다 — Task 3 Step 6 이 그 둘의 락을 직접 돌린다.
- `doc-recritic` 의 슬롯 tag 목록이 `test_docreview_agents.sh` 의 리터럴과 **순서까지** 일치해야 한다(`diff` 를 끝에 둔다).

**4. 이 계획이 스스로 아는 약점.**

- **AC11 의 집행이 `verdict.py` 에 «간접»이다.** 「보안·판정이 `absent` 인데 `clean`」은 `angle_absent=True` 가 `add("angle-absent")` 를 태워 `clean` 을 구조적으로 불가능하게 만드는 방식으로 막힌다 — 별도의 「clean 이면 실패」 검사가 있는 것이 아니다. 누군가 `verdict.render()` 를 우회해 자기 판정 줄을 찍으면 이 막음이 안 선다. 그 경로의 backstop 은 「판정 어휘는 `verdict.py` 밖에 두지 않는다」는 Global Constraint 와 리뷰뿐이다.
- **`test_angle_coverage.sh` 가 «각도 파일을 누가 쓰는가»를 못 잰다.** 오케스트레이터가 세 각도를 전부 `filled` 로 적으면 이 락은 GREEN 이다(§15-4). 이 PR 은 그 한계를 **해소하지 않고 공시**한다.
- **`--angles` 가 기본 off 라 이 PR 만으로는 AC10·AC11 이 실제 실행에 서지 않는다.** 서는 것은 PR4 다. 그 빚은 부채 원장의 첫 행이고, 그 행이 떨어지면 AC10·AC11 은 락에서만 참이고 제품에서는 거짓이 된다 — **PR4 계획의 1순위 확인 항목이다.**
- **`test_dispatch_disposition.sh` 의 이름-키 사각지대는 이 PR 이 안 고친다.** R-D 가 그것을 측정해 기록했을 뿐이다. 고치는 것(같은 이름의 사본이 플러그인별로 갈리게)은 그 락의 소유자 결정이고 이 PR 의 범위 밖이다 — **PR4 의 AC22 락이 그 위에 서면 안 된다**는 것만 이 PR 이 확정한다.
- **Task 5 가 Task 2·3·4 와 독립이라 순서를 섞을 수 있다.** 그것은 장점이지만, 섞으면 Task 7 의 baseline diff 에서 어느 Task 가 무엇을 바꿨는지가 흐려진다. 순서대로 도는 것을 권한다.

---

## Execution Handoff

계획이 `docs/superpowers/plans/2026-09-23-qg-angle-floor-pr3.md` 에 저장됐다. 실행 방식 둘:

**1. Subagent-Driven (권장)** — Task 마다 새 subagent, Task 사이에 리뷰, 빠른 반복. `superpowers:subagent-driven-development`.

**2. Inline Execution** — 이 세션에서 체크포인트를 두고 배치 실행. `superpowers:executing-plans`.
