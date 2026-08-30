# Changelog

## [0.43.0] — 2026-08-31

### Changed

- **`AUDIT_SECTIONS`에 `("6", "사용자 원문")`을 뒤에 덧붙였다** — audit 사이드카가 이제
  6절 계약이다. 게이트가 audit §6 헤딩 부재를 `missing audit sections`로 red 처리한다.
- **`attribution_block_missing`의 검사 대상이 payload §6에서 audit §6으로 이사했다** —
  brief 재구조화(§7.1)의 첫 단계로, `S1`을 제외한 사용자 원문 전량이 audit으로 옮겨가는
  하류 작업(별도 Task)의 선행 조건이다. 시그니처는 여전히 `(str) -> bool`이지만 인자
  이름을 `audit_text`로 바꿔 의미 변화를 드러냈다. `gate()`의 검사 배선도 payload 텍스트
  블록에서 audit 텍스트 블록(`amiss` 계산 다음, `pair` 검사 뒤)으로 옮기고, audit §6이
  통째로 없는 경우(#9가 이미 그 red를 낸 경우)와 중복 보고되지 않도록
  `audit_sec6_absent` 가드를 추가했다.
- **두 템플릿을 갱신했다** — `interview-audit-template.md`에 `## 6. 사용자 원문`
  절(append-only, `S1` 제외 전량, 출처 표기 블록 포함)을 §5 뒤에 추가했고,
  `interview-brief-template.md` §6은 `S1` 최초 요청 하나만 남기고 출처 표기 블록을
  지웠다(그 검사가 audit으로 이사했으므로). payload §6이 `S1`만 남으면서 예시
  `user_sourced_items`의 `D2.evidence`가 더 이상 payload §6에서 해석되지 않는
  `S2`를 참조하고 있었다(bijection C) — 출하 템플릿 자체가 자기 게이트에 걸리는
  것을 막기 위해 예시 `D2`의 evidence를 `S1`로 바꿨다(payload §6에 실재하는 유일한
  앵커). `S2` 이상 원문을 근거로 삼는 실제 제약의 bijection C 재해석(양쪽 파일의
  합집합 대조)은 하류 Task가 맡는다.
- **N1b 신설 — `payload_verbatim_is_s1_only()`가 payload §6 앵커 집합이 정확히
  `{"S1"}`인지 등식으로 확인한다.** `⊆`가 아니라 `==`다 — `⊆`로 쓰면 빈 §6이
  통과하는데, `user_sourced_items`가 0건인 payload에서는 bijection C의 순회 자체가
  비어 그 구멍을 대신 막아주지 못한다(등식 술어가 스스로 양성인 이유). `gate()`는
  `sec6_absent` 가드 아래 이 검사를 새로 배선했다.
- **`bijection_c_errors()`가 2인자(`payload_text, audit_text`)로 바뀌었다** — 앵커
  집합이 이제 payload §6 ∪ audit §6이다(`S1`은 payload에, `S2` 이상은 audit에 살므로
  한쪽만 보면 반대쪽 인용 전량이 dangling으로 오탐된다). 단방향은 유지 — 인용된
  `evidence: S<N>`의 존재만 확인하고 역방향(모든 앵커가 인용될 것)은 요구하지 않는다.
  `gate()`의 호출 자리를 audit 해석 블록 안(`pair` 검사 뒤)으로 옮겨 audit 텍스트를
  받을 수 있게 했고, `items` 서브커맨드(`main()`)도 같은 시그니처 변경의 소비자라
  `gate()`와 같은 방식(`resolve_audit` → 실패 시 판정-불가 문구, 성공 시 두 텍스트로
  호출)으로 함께 고쳤다 — 안 그러면 옛 1인자 호출이 `TypeError`로 죽는다.
- **픽스처 4쌍 추가** — `interview-brief-payload-s2`(N1b 위쪽: payload §6에 `S2`가
  남아있으면 red), `interview-brief-payload-empty-sec6`(N1b 아래쪽: 빈 §6도 red),
  `interview-brief-zero-items`(`user_sourced_items: []` + §2 항목 불릿 제거 +
  frontmatter AC12 sentinel 보존 — bijection C가 공허해지는 유일한 상태에서 N1b가
  단독 방어선임을 확인), `interview-brief-audit-drop-s5`(payload에 `evidence: S5`
  항목을 추가하고 audit §6에는 `S2`만 실어 `S5`를 dangling으로 남김 — 합집합 해석의
  audit 쪽이 실제로 읽힘을 확인). 넷 다 hand-add한 audit §6(헤딩 + 출처 표기 블록)을
  가진다 — 그렇지 않으면 전부 `missing audit sections`로만 red가 나 자신이 시험하려는
  축을 재지 못한다.
- **부수 수정: `interview-brief-payload-attr-missing.md`에서 payload §6의 `S2` 항목을
  뺐다(`S1`만 남김).** 이 fixture는 U2-T2(payload attribution 무관 확인)가 `rc==0`을
  요구하는데, valid.md에서 파생된 payload §6이 원래 `{S1, S2}`를 그대로 갖고 있어
  N1b 신설과 충돌해 `rc==0` 단언이 회귀했다(`git diff` 전/후로 확인). audit
  사이드카가 이미 `S2`를 §6에 갖고 있어 `D2.evidence: S2`는 union으로 계속 해석된다
  — attribution 무관성이라는 이 fixture의 원래 취지는 그대로다.

### Known gap (하류 Task로 이관)

- 이 변경 시점에는 audit §6이 아직 기존 fixture 74건에 채워지지 않았다 — 이 하나의
  값이 늘면서 그 사이드카들이 이제 `missing audit sections: ['6. 사용자 원문']`로
  red를 낸다. 같은 원인 하나가 **테스트 파일 2개**를 건드린다:
  - `test_check_brief.sh` — `interview-brief-valid.audit.md` 등에 의존하는
    T15/T19/AC8/C9/T12/T14/T14-anchoring/T17/T21/R1/VS16/`audit_file 인라인 주석`
    12개 기존 단언.
  - `test_brief_no_statement_cap.sh` — Task 1이 만든 락. 그 L3 행이
    `interview-brief-valid.md`/`.audit.md`에서 임시 파생 fixture(`interview-brief-long.*`)를
    만드는데, 원본 audit이 다른 모든 legacy 사이드카와 똑같이 §6이 없어 파생본도
    §6이 없다 — "200자 statement가 상한에 안 걸린다(rc=0)" 단언 1건이 같은 이유로
    반드시 같이 regress한다.

  두 파일 다 검사 로직의 결함이 아니다 — `S1` 제외 전량을 audit §6으로 채우는
  하류의 일괄 이관(다른 Task, `move-verbatim.py`)이 아직 실행되지 않은 데서 오는
  예상된 공백이며, 그 일괄 이관이 두 파일을 함께 닫는다. 이번 유닛이 손으로 만든
  3개 fixture(`interview-brief-audit-attr-missing`·`payload-attr-missing`·
  `audit-no-sec6`)는 의도적으로 깨진 대조군이라 그 일괄 이관의 대상이 아니며 이미
  audit §6을 갖는다.

  **N1b 신설로 이 공백의 모양이 하나 더 늘었다.** `test_brief_no_statement_cap.sh`의
  L3가 파생하는 `interview-brief-long.*`는 `interview-brief-valid.md`의 payload §6을
  그대로 물려받으므로(`{S1, S2}`, 아직 미이관) N1b도 함께 걸린다 — 실패 메시지가
  `missing audit sections`만이 아니라 `payload §6 앵커가 {'S1'}이 아니다`까지
  두 항목이 된다. 위 12개(`test_check_brief.sh`)와 L3(`test_brief_no_statement_cap.sh`)
  모두 rc-only 단언이라 개수·판정 자체는 안 바뀐다 — 실패 메시지에 이유가 하나 더
  실릴 뿐이다. 일괄 이관이 두 축(audit §6 부재, payload의 `S2` 잔존)을 함께
  정리해야 이 공백이 완전히 닫힌다.

- **이관 시 보존해야 할 carry-forward — T18이 지금 틀린 이유로 green이다.**
  `test_check_brief.sh`의 T18 두 단언("표기 블록 부재 → red", "기호 누락 표기 블록 →
  red")은 각각 `interview-brief-no-attribution.md`·`interview-brief-attribution-partial.md`를
  쓰는데, 이 fixture들의 audit 사이드카도 다른 legacy 사이드카와 똑같이 §6이 아직
  없다. 그래서 지금은 attribution 검사가 실행되기도 전에 `missing audit sections`로
  먼저 걸려 red가 나고, rc-only 단언 방식은 두 원인을 구분하지 못해 우연히 계속
  green으로 보인다. **하류의 일괄 이관이 이 두 사이드카에 §6을 채울 때, 형태만
  갖춘 §6을 넣지 말고 출처 표기 블록이 빠진 상태(missing-attribution 성질)를
  그대로 보존해야 한다** — 안 그러면 T18은 영원히 통과하되 아무것도 재지 않는
  빈 락이 된다.
- **`check_verbatim_coverage.py`가 3인자(`<payload> <state.local.md> <audit>`)로
  바뀌었다** — `parse_payload_section6`을 `parse_section6(text, label)`로 개명해
  payload·audit 양쪽에서 재사용하고, `parse_section6_union()`을 신설해 `S1`(payload)
  ∪ `S2` 이상(audit)을 대조 코퍼스로 합친다. 한쪽 §6이 없으면 조용한 코퍼스 축소가
  아니라 그대로 `ParseError`(호출자가 exit 3으로 매핑)를 낸다 — 부분 코퍼스로
  "완전성 통과"를 내지 않는다. 같은 앵커가 payload·audit 양쪽에 있으면
  append-only 위반(exit 1)이다 — 오늘 payload 내부 중복이 구조 위반인 것과 같은
  이유이며, 집행이 이제 합집합 위에서 돈다. audit 경로는 **호출자가 명시**한다 —
  `check_brief.py`의 `resolve_audit()`처럼 payload 파일명에서 유도하지 않는다(그
  유도는 남의 audit 채택을 거절하는 목적이고, 여기는 반대로 무엇을 재료로 쓸지
  유추가 실패했을 때 조용한 것이 더 나쁘다).
- **`reviewing-brief` SKILL.md의 두 실행 라인**(진입 첫 액션, 2-c 충실도 재실행)이
  `"$AUDIT"`를 세 번째 인자로 넘긴다. `$AUDIT`은 `$PAYLOAD`와 같은 층의 호출자
  공급 입력이라 `## 상태`의 캐스팅 목록에 추가했다(스킬 자신이 정의하지 않는다).
  `test_reviewing_brief_skill.sh`의 AC1 호출-라인 락도 2인자 접두 일치만으로는
  3인자 호출을 구분 못 해(끝 앵커가 없어 부분 일치로 계속 통과) 3인자 전체를
  요구하도록 좁혔다.
- **`test_check_verbatim_coverage.sh`가 U2-T4(합집합) 4단언을 추가하고 기존
  invocation을 전부 3인자로 이관했다.** `brief-verbatim-*` 12종 fixture에 audit
  사이드카를 새로 만들었다(payload §6에서 `S1`을 제외한 전량을 떼어 옮김 — 위
  "Known gap"의 74+개 `interview-brief-*` legacy fixture와는 다른 파일군이라 그
  일괄 이관 대상이 아니다). S2 이상을 겨냥하던 mutation 락(T2 절단 3종)은 대상이
  audit 파일로 옮겨간 것을 따라 mutation 지점도 audit 사본으로 옮겼다 — payload는
  그대로 두고 audit만 mutate해도 union 위에서 여전히 위반이 잡히는지가 이 락의
  이빨이다. 교차 파일 중복 앵커(`brief-verbatim-dup-across.{md,audit.md}`)와 audit
  §6 부재(`brief-verbatim-audit-no-sec6.audit.md`) 전용 fixture 2종을 손으로
  추가했다. 사이드카 생성에 쓴 변환 스크립트(`mk-sidecar.py`)는 일회용이라
  리포에 남기지 않았다(git-ignored `.claude/` 하위, 설계 §7.2).

## [0.42.0] — 2026-08-31

### Removed
- `STATEMENT_MAX = 160` 상한과 그 전 표현을 지운다 — `check_brief.py` 의 게이트 검사,
  `finishing.md` 의 「160자 이내」지시, 픽스처 2쌍(`interview-brief-statement-160/161`
  및 각 audit)과 그것을 소비하던 `test_check_brief.sh` T23 단언. 상한이 잰 것은
  과잉결정이 아니라 부피였다 — 과잉결정은 대리 지표가 아니라 brief-readback 이 직접 잰다.
  삭제 전 양성 대조를 기록했다: `interview-brief-statement-161.md` 가 변경 전
  `rc=1` · `"C1: statement 161자 > 160 (hard cap)"` 이었다. 회귀 락
  `test_brief_no_statement_cap.sh` 는 3층(양성 대조 → 부재 → 행동)으로 재발을 막는다.

### Fixed

- **`test_brief_no_statement_cap.sh` L3 를 메시지 리터럴 앵커에서 rc(종료 코드) 앵커로
  바꿨다.** mutation 축 (c)(이름만 바꿔 상한을 되살림 —
  `if len(stmt) > 160: errs.append(f"{iid}: too long")`)로 처음 드러난 gap: 이
  mutation 을 적용하면 게이트는 실제로 200자 statement 를 거부하는데(`rc=1`,
  `"user_sourced_items: ['C1: too long']"`), 옛 L3 는 `grep -q 'hard cap'` 로 **그
  문구만** 찾아 "too long" 은 못 잡고 `ok`(안 걸림)를 냈다 — L3 가 사실상 L2(리터럴
  부재 검사)의 중복이었다. 지금은 파생 fixture 의 `audit_file`/`payload` 역참조를
  새 파일명에 맞춰 함께 갱신해(사이드카 짝을 완성해) 게이트가 그 fixture 에 대해
  `rc==0`·`"pass": true`·무-failures 를 내는 것을 cap 제거 후의 유일하게 옳은 결과로
  확정했고, L3 는 이제 `rc == 0`(그 어떤 이름의 상한도 재도입되지 않았다)을 1차
  단언으로, `hard cap` 리터럴 grep 을 진단용 보조 단언으로 둔다. 재검증: 같은
  mutation(`ev = it.get("evidence")` 앵커, `git diff --stat` 으로 실제 3줄 삽입
  확인)을 다시 적용하자 L3 가 이번엔 RED(`rc=1`)를 냈다 — 리네임을 실제로 잡는다.
  mutation (a)/(b) 는 각각 `git diff --stat` 으로 실제 코드 변경을 확인한 뒤 기대대로
  rc=1(L1 NO / L2 NO) 을 냈다 — 브리프가 준 (c) 의 원래 anchor 문자열
  (`errs.append(f"{iid}: id 형식`)은 현재 `check_brief.py` 에 존재하지 않아 최초
  실행은 무변경 no-op 이었다(diff 없음) — anchor 를 `ev = it.get("evidence")` 줄로
  교체해 실제 변경을 확인한 뒤 재실행했다.
- **출하 템플릿(`templates/interview-brief-template.md:20`)이 상한을 도로 가르치고
  있었다.** `finishing.md` Step A가 이 템플릿을 매 인터뷰가 읽는 살아있는 소스로
  지정하므로, 코드에서 지운 `STATEMENT_MAX` 를 이 파일의 주석(`# 160자 이내(hard) —
  ...`)이 모든 미래 brief 작성에 재교육하고 있었다 — 브리프의 "Files to Modify" 목록
  누락. `160자 이내(hard) — ` 절만 제거했고 나머지 주석(모델이 쓴 요약이라는 것,
  P21 secret placeholder 치환)은 그대로 남겼다 — 그 부분은 여전히 유효하다. 이 편집이
  템플릿 자신의 `check_brief.py gate` rc(=1, `audit_file` sidecar 불일치 — 상한과
  무관한 기존 사유)와 T-TPL 스위트 결과를 바꾸지 않음을 확인했다.
  `test_brief_no_statement_cap.sh` 의 코퍼스도 넓혔다 — 이전에는 `check_brief.py`
  와 `finishing.md` 만 읽어 이 템플릿 잔존을 못 봤다(재실행해도 GREEN 이었다). L1 에
  템플릿 전용 양성 대조 행(`next_phase: superpowers:brainstorming` 앵커 — L2 가 찾는
  상한 리터럴과 다른 줄이라 둘이 같은 원인으로 동시에 반응하지 않는다)을, L2 에 템플릿
  상한 부재 행을 추가했다. mutation 으로 검증: (1) 템플릿에 cap 절을 재삽입 →
  `git diff --stat` 으로 실변경 확인 후 새 L2 템플릿 행이 RED. (2) 템플릿 파일을
  통째로 비움 → L1 템플릿 행이 RED(부재 검사가 빈 파일에도 통과하는 공허함이 아님을
  확인). 둘 다 복원 후 `git status --porcelain plugins/spec-distill` 깨끗함.
- **템플릿 L2 부재 행은 리터럴 grep 이라 다른 어휘의 상한을 놓친다 — `# max 160 chars,
  strictly enforced` 처럼 영어로, 다른 표현으로 다시 써넣으면 옛 L2 는 GREEN 을 냈다**
  (재리뷰 실증). `id`/`P21` 같은 값이 그 줄에 정당하게 들어 있어 숫자 기반 검사는
  오탐하고, 상한 어휘를 두 언어로 열거하는 것도 조용히 낡는 추측이다 — 이 저장소는
  이미 이 한계를 판정해 뒀다(`test_probe_sweep_residue.sh`): grep 오라클은 식별자와
  인접 단어를 재지 의미를 재지 않으며, 그 너머를 지키는 것은 락이 아니라 리뷰의 일이다.
  그래서 `templates/interview-brief-template.md` 의 C1 `statement:` 주석 **한 줄만**
  부재가 아니라 **정확한 등가**로 고정했다 — `# 모델이 쓴 요약. P21 secret placeholder
  치환` 과 정확히 같아야 하고, 그 줄에 무엇을 덧붙이든(어떤 언어의 상한이든, 숫자든)
  등가가 깨져 red 가 된다. 앵커는 파일 위치(20행)나 "첫 statement: 매치"가 아니라
  `id: C1` 항목 다음에 나오는 첫 statement: 줄이다 — 파일에 statement: 가 둘(C1/D2)
  있고 주석은 C1 쪽에만 있어, 위치나 순서에 기대면 그 순서·개수가 바뀔 때 엉뚱한 줄을
  잰다. mutation 4종으로 검증(각각 `git diff --stat` 으로 실변경 확인 후 실행,
  복원 후 `git status --porcelain plugins/spec-distill` 깨끗함 확인): (1) 옛 한국어
  cap 절 재삽입 → RED. (2) 다른 숫자·영어 cap(`# max 200 chars, strictly enforced`)
  재삽입 → RED — 이것이 옛 L2 가 놓치던 바로 그 경우다. (3) 주석 전체 삭제(값만
  bare) → RED. (4) 템플릿 전체를 비움 → L1 템플릿 행 RED(round 2와 동일, 재확인).
  **이 등가 행이 못 미치는 것**: C1 statement 주석 한 줄 밖에서 상한이 재도입되거나
  (예: D2 statement 주석, 혹은 이 파일 밖 다른 모델-지시 채널), 이 락이 안 읽는 완전히
  다른 경로로 모델에게 상한이 재학습되는 경우는 여전히 이 락의 사각지대다 — 그 너머는
  리뷰가 계속 맡는다.

## [0.41.0] — 2026-08-29

### Changed
- 인터뷰 R1 이 `Reframe (메타 프롬프트)` 에서 **`Problem Reframe`** 으로. 「받은 요청 재구성」은 `request-framing` 이 하고, 여기서는 **seed 가 가리키는 작업 뒤의 진짜 문제**를 재구성한다. 명칭 변경이 아니라 R&R 이동이다.
- `commands/interview.md` 의 trivia 5패턴이 `references/trivia-escape.md` 포인터로.

### Added
- `conducting-interview` 에 seed 입력 규약. seed 본문은 §6 `S1` 이 되고, 인터뷰 중 사용자가 seed 를 뒤집으면 **새 발화가 이기며** 그 재결정이 §5 에 기록된다(P23).
- `/interview` 가 seed 아닌 입력에 조언 한 줄을 낸다 — **차단하지 않는다**(호환 유지).

### 검증 경계 — 이 판본에서 실제로 관측한 것

- **진짜 codex 바이너리를 태운 실행은 이 판본에 0회다**(한도 소진). v0.39.0 이 seed codex
  러너를 「배선되어 실제로 호출된다」고 쓴 것은 **배선의 계약**을 서술한 것이고, 관측으로
  확인된 것은 셋이다: ① 게이트 블록을 잘라내 stub/mock 위에서 돌렸을 때 **mock 이 실제로
  호출됐고**(sentinel 실재) 그 argv 가 계약대로였다는 것, ② kill switch · 감지기 부재 ·
  `exit 3` · 게이트 입력 부재 각 경로의 fail-closed 처리가 관측된 사후상태와 일치한다는
  것, ③ 산출물 판정이 성공 마커 **양성 요구**로 돈다는 것. **모델 다양성이 실제로 확보되는지는
  한도가 풀린 뒤 실호출로 확인해야 한다** — 지금까지의 GREEN 은 그 사실의 증거가 아니다.

## [0.40.0] — 2026-08-29

### Added
- **`/request-framing` — 파이프라인 Phase 0.** 사용자의 의도·steering·방향·goal을 싱크해
  새 세션의 첫 턴 메시지 `interview-seed`로 압축한다. 산출물은 문서가 아니라 **붙여넣는
  메시지**이며 절·라벨·태그·URL이 없다.
- `skills/framing-requests/` — 확산 후 압축 절차. `proceed-gate.md`·`compression.md`·
  `trivia-escape.md` 채택.
- `agents/seed-critic.md` · `agents/seed-readback.md` — 둘 다 `tools: []`. critic은 억제
  네 축, readback은 냉독이며 **판정은 사용자가 한다**.
- `references/compression.md` — 압축 규약 공유 계약. **오늘 게이트로 집행하는 것은
  seed뿐**이고 brief는 재구조화 이후에 채택한다.
- `references/trivia-escape.md` — 5패턴 정의 정본. `commands/request-framing.md`와
  `framing-requests`가 가리킨다(`commands/interview.md`는 아직 자기 인라인 사본을 쓴다).
- `scripts/check_seed.py` — 게이트 다섯: seed 본문 슬롯 부재 검사 셋(답-슬롯 헤딩·태그·
  URL) + 본문 전체가 비어 있지 않은지 보는 파일-전체 존재 검사 하나(check 0) + audit 쪽
  `## 1. 원문` 절 존재 검사 하나. seed 본문에 대한 **슬롯** 존재 검사는 없다.
- seed 억제 축 codex 러너·빌더·체크리스트(`run_seed_codex_reviewer.sh`·
  `build_seed_codex_prompt.py`·`seed-codex-suppression-checklist.md`)가
  `framing-requests` skill의 게이트 블록에 배선되어 실제로 호출된다.
  `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`이 호출자 책임으로 그 호출을 막고, 러너가
  산출물을 못 쓰고 죽으면(`exit 3`) 직전 라운드 잔존물을 지운다. 억제 findings는 어떤
  병합기도 거치지 않고 사용자에게 직접 간다.

### Fixed
- `skills/framing-requests/SKILL.md` — `interview-basename` 파일이 생기는 시점 서술을
  실제 조건(블록의 `TOPIC` 자리표가 실값으로 치환된 실행)에 맞췄다. 자리표가 그대로면
  블록이 돌아도 파일을 만들지 않고 advisory만 낸다.

## [0.39.0] — 2026-08-28

### Added
- `scripts/brief_review_state.py`에 `--ledger-key`(닫힌 열거: `brief_review_degradations`·
  `framing_degradations`, `get`·`degrade-append` 양쪽). 다른 파이프라인이 같은 writer로
  자기 원장에 쓴다 — 읽기·쓰기·기본값이 `LEDGER_KEYS` 하나를 거친다(리터럴 산개 금지).
- `AXES`에 `suppression` — seed 억제 축의 degrade record를 위한 `affected_axis` 값.

## [0.38.0] — 2026-08-28

### Removed
- `scripts/probe_budget.py` 와 그 전용 테스트·픽스처(`tests/test_probe_budget.sh`,
  `tests/fixtures/state-probe-at-cap.md`, `tests/fixtures/state-probe-within.md`). 인터뷰
  질문·라운드에 상한을 두지 않는다 — 질문 루프는 매 반복마다 사용자가 답해야 돌므로 묶을
  자율이 없다.
- `DEVBREW_SPEC_DISTILL_PROBE_CAP` kill switch (대상이 사라졌다).
- `skills/conducting-interview/SKILL.md`의 `## probe 백스톱 (C1/C10 …)` 절과
  `probe_count`/`probe_cap_override` state 필드 — 아래 coverage-mapper 재dispatch
  바운드가 이 카운터를 대체한다.

### Changed
- coverage-mapper 재dispatch 바운드를 `probe_count` 단위에서 **에피소드 필드 둘**
  (`orchestration.stall_episode` · `orchestration.coverage_mapper_dispatched_episode`)로
  이식. 재dispatch 조건은 `no_progress_streak >= 3 AND coverage_mapper_dispatched_episode
  != stall_episode` — 판정은 여전히 디스크 두 값의 비교(무상태)이고 한 정체 구간당
  정확히 1회다. 회귀락을 토큰 공존이 아니라 이 AND 관계 전체에 걸도록 강화했다
  (리뷰가 `AND`→`OR` 반전을 놓치던 결함 1건을 실측 적발).
- floor 탈출구의 발동 조건이 카운터에서 **사용자 발화**로. 사용자가 언제든 종료를
  요청하면 미충족 floor 는 사용자-승인 박제로 닫고(`evidence` 에 `사용자-승인 박제(@사용자
  종료 요청)` 기록) payload §3 Open Questions 로 이월한다. 박제 표식이 원장에 남으므로
  silent bypass 가 아니다.
- audit `## 2. Budget` 절의 본문이 상한 서술에서 **지출 기록**(`질문 라운드: <n> · agent
  dispatch: <n> · codex 실호출: <n> (성공 <n>)`)으로.
- `skills/conducting-interview/SKILL.md`의 `S<N>` id 번호 공식이 최초 요청 원문(`S1`)
  예약을 반영 — 원문이 있으면 `user_statements` 는 `S2`부터, 없으면 `S1`부터 시작한다.
  이 정합이 없으면 payload §6 에 `S1` 앵커가 중복되거나 payload·state 의 `S1`이 서로
  다른 텍스트를 가리켜 `check_verbatim_coverage.py`가 red 를 낸다(§6 원문 완전성 검사).

### Added
- `finishing.md`에 최초 요청 원문(`$ARGUMENTS`)을 §6 `S1`로 보존하는 요구. 지금까지는
  관례였고 게이트 15항 어디에도 이 요구가 없어 원문이 보존되지 않은 인터뷰도 통과했다.
  `test_conducting_interview_stage.sh`에 이 요구와 번호 공식 정합을 파일 전체·내용
  표지 위 **∀**(모든 매치가 정본과 일치)로 결속하는 단언을 추가하고,
  `test_check_verbatim_coverage.sh`에 영구 픽스처 2쌍(정상 공식 / 구-공식 회귀)을 넣었다.
- `tests/test_probe_sweep_residue.sh` — probe 어휘 스윕 완결성의 단측 단언. 식별자 열거
  (`ALIAS_RE`)뿐 아니라 개념명 근접 스캔(`CONCEPT_RE` — "probe 상한"이 다른 이름으로
  재작성되는 것에 대한 좁은 방어)까지 스캔하고, 세 예외(`tests/fixtures/` ·
  `CHANGELOG.md` · 이 파일 자신)의 자기지시를 제외한다. 양성 대조를 계열별(별칭/개념
  각각)로 분리해 — 합본 하나만 걸던 대조는 한쪽 계열만 깨져도 통과했다(실측:
  `ALIAS_RE`만 깨도 GREEN) — 두 계열이 각자 이빨을 갖게 했다.

## [0.37.0] — 2026-08-27

### Added
- 재결정 규약(P23)을 `references/proceed-gate.md` 계약의 절로 승격. 확정된 항목은 재논의 대상이 아니지만 **반증 대상**이며, 근거와 사용자 동의가 있으면 피벗할 수 있다.
- `skills/reviewing-spec/SKILL.md` 에 이 skill 어휘의 재결정 규약 절.
- `tests/test_proceed_gate_adopters.sh` 에 네 번째 채택자 앵커(P23).

## [0.36.0] — 2026-08-27

게이트의 연료를 «어떤 도구가 돌았나»에서 «git 이 무엇을 dirty 로 보나»로 바꾼다.
쓰기-도구 matcher 가 만들던 우회가 사라져, Bash heredoc·`sed -i`·외부 편집기로 쓴
스코프 문서도 턴 끝에 구조 검증과 리뷰 dispatch 를 지난다.

### Removed
- **`hooks/spec-write-validator.py` (PostToolUse, `matcher: "Write|Edit|MultiEdit"`)** — 쓰기-도구
  matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못한다. 이 리포에서 실제로 발생했다:
  세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 Law 1 게이트를 한
  번도 통과하지 않은 채 커밋됐다. kill switch 는 켜지지 않았다 — 게이트는 꺼졌다고 **말하지
  않고** 꺼졌다.
- **`hooks/pending-review-reminder.py` (UserPromptSubmit)** — `pending_review:` 만 소비했다.
  그 계약이 은퇴하면서 함께 사라진다. 그 훅이 `PENDING_RE` 검사 **이전에** 돌던 두 가지는
  인계를 확인했다: `fire_and_forget_gc()` 는 `review-dispatch.py` 가 같은 자리에서 이미
  부르고(Stop 은 매 턴 돌아 빈도가 같거나 높다), state 판독 실패 advisory 는 같은 훅이 같은
  조건에서 낸다.
- `pending_review:` 상태 블록 · `arm_ledger.strip_pending`·`strip_pending_file` ·
  CLI `strip-pending` · `hook_common.PENDING_RE`
- `tests/{test_spec_write_validator.sh,test_design_mode_validator.sh,test_reminder_hook.sh,test_stale_state_truncate.sh}`
- **`DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`** — 이 변수를 읽던 유일한 지점(위 write-time
  validator)이 사라져 더 이상 아무것도 끄지 않는다. **지정 대체재는 없다** — 이 변수가 주던
  능력 자체가 이 릴리스에서 사라졌다(아래 Changed 의 첫 BREAKING 항목).

### Added
- **`scripts/discover_candidates.py`** — 스코프 문서 발견. `git status` 에 **pathspec 을 주지
  않고** dirty 집합 전체를 상계로 받은 뒤 `arm_ledger.canonical_key` 로 좁힌다. wildmatch 를
  방정식에서 빼므로, 판본 4·5 가 연속으로 낸 pathspec 결함이 재발할 수 없다.
- 원장 블록 `inflight_paths:` (TTL `INFLIGHT_TTL_SEC` = 900초) 와 `validation_attempts:`
  (상한 3, `dispatch_attempts` 와 **별도**). CLI `clear-inflight`.
- `scripts/resolve_mode.py` — 삭제되는 훅에서 동작 무변경으로 옮겨왔다.
- `tests/test_write_path_behavior.sh` — 실제 `claude -p` 턴으로 A7·A8·A9·A18 을 잰다. 정적
  락이 볼 수 없는 «훅이 정말 발화하는가»만 여기서 잰다. API 크레딧을 쓰므로 기본은 skip 이고
  `DEVBREW_BEHAVIOR_TESTS=1` 일 때만 돈다.

### Changed
- **`Stop` 훅(`review-dispatch.py`)이 발견·Layer 1 구조 검증·리뷰 dispatch 를 모두 수행한다.**
  구조 검증은 파서를 `subprocess` 로 부르지 않고 import 한다 — 훅 timeout 이 10초인데
  `call_parser` 가 호출마다 `timeout=10` 을 걸어 중첩 timeout 을 만들던 구조가 사라진다.
  순서는 구조 검증 → TTL 가드 → dispatch 로 고정되며, 구조 실패가 있으면 그 사유만 block 으로
  나가고 dispatch 는 그 턴에 없다.
- 턴당 검증 문서 상한 5(`CANDIDATE_CAP`). 정렬이 안정적이라는 사실 자체가 기아의 원인이므로
  그 위에 **커서 회전**을 얹는다. 실측(문서 7개·3턴): 1턴 doc1–5 → 2턴 doc6·doc7·doc1–3 →
  2턴째에 7개 전부가 최소 1회 검증된다. 회전을 제거한 변이에서는 doc6·doc7 이 영구히 굶는다.
- 훅이 4개에서 2개(`Stop`·`SessionEnd`)로 줄었다. **신규 훅 0개.**
- `agents/spec-reviewer.md` — 삭제된 경로(`hooks/spec-write-validator.py:resolve_mode`)와 은퇴한
  `pending_review.mode` 계약의 **인용만** 갱신했다(각각 `scripts/resolve_mode.py` 와 prompt 의
  `mode:` 로). 리뷰 규칙·임계·판정 기준은 한 줄도 건드리지 않았다.
- **BREAKING — «구조 검증(Layer 1)은 유지한 채 자동 리뷰 dispatch 만 중단» 능력이 사라졌다.**
  등가 스위치가 없다 — `DEVBREW_SKIP_HOOKS=spec-distill:Stop` 은 발견·구조 검증·dispatch 셋을
  **함께** 끈다(셋이 한 훅의 한 진입점 뒤에 있다). 그 능력의 복원은 이 릴리스의 범위 밖이며
  신규 기능 작업이다.
- **BREAKING — dispatch 가 더 이상 «그 문서가 구조 검증을 통과했다»를 함의하지 않는다.**
  검증은 상한 5의 회전 창을 훑고, dispatch 선택은 후보 목록을 **0번부터** 훑는다. 두 술어가
  다르므로 dirty 문서가 5개를 넘으면 어긋날 수 있다 — 실측: 커서가 앞쪽을 지난 뒤 정렬상 맨
  앞에 오는 문서가 새로 dirty 가 되면, 그 문서는 검증 창 밖인 채로 dispatch 된다. 좁고
  자기교정적이지만(다음 회전이 잡는다) 변경 전의 불변식은 사라졌다.
- **BREAKING — «재편집하면 재발동» 트리거가 은퇴했다.** 이미 dirty 인 untracked 문서를 다시
  편집해도 `git status` 가 보고하는 것은 달라지지 않으므로, 재편집은 더 이상 관측 가능한
  트리거가 아니다. 리뷰되지 않은 문서는 이제 **in-flight TTL 만료**(`INFLIGHT_TTL_SEC`, 900초)로
  돌아온다. «파일을 건드려 리뷰어를 다시 부른다»는 이제 그만큼의 기다림이다.
  **그 창 동안 멈추는 것은 dispatch 뿐이 아니다** — 아래 Known limitations 의 in-flight 항목.

### Fixed
- **구조 검증 상한 advisory 가 `systemMessage` 로 나간다.** 이전 판은 stderr 에만 냈는데,
  같은 파일이 네 곳에서 근거로 드는 사실(exit 0 의 stderr 는 전달되지 않는다) 때문에 그것은
  전달되지 않는 채널이었다 — 형제 advisory 셋(git 불능 · state 판독 실패 · 은퇴 스위치)은
  이미 `systemMessage` 를 쓴다. 이 통지는 그 문서가 **이 세션의 Law 1 게이트를 영구히
  벗어난다**는 사실이라 조용하면 설계 §4.4 를 어긴다. 같은 턴에 block 이 함께 나갈 수
  있으므로 별도 emit 이 아니라 그 JSON 의 `systemMessage` 에 합쳐 낸다(stdout 의 JSON 은
  하나여야 한다 — 둘이면 파싱이 깨져 block 이 조용히 사라진다). 같은 상한의 **동턴 절반**
  (`reached_cap`)은 이전부터 block `reason` 을 타고 전달됐고 그대로다.
- **원장 블록 기록 실패가 block 루프를 만들지 않는다.** `rewrite_state` 의
  `record_attempt`(G6 상한)·`mark_inflight`(발견 제외) 실패는 이전 판에서 stderr 로 적히고
  **그대로 block 을 냈다**. 연료가 `pending_review` 이던 시절에는 그 소비가 무조건 일어나
  대가가 «dispatch 한 번 더» 였지만, 발견이 무상태가 된 뒤로는 소모될 연료가 없고 두 억제자가
  **둘 다** 그 실패 뒤에 있다 — 남는 상한이 30초 TTL 하나뿐이라 사람의 턴 간격이 그것을 매번
  넘긴다(재현: 두 함수를 raise 로 갈아끼우고 `main()` 4회 연속 → 4회 모두 `decision: block`).
  이제 `OSError` 와 **같은 처분**을 받는다: loud 하게 적고 emit 없이 접는다. 안전한 근거는
  이 릴리스 자신의 논거다 — 발견은 무상태라 다음 Stop 이 같은 문서를 다시 찾는다.
  `select_dispatch_target` 의 원장 조회 실패가 이미 같은 논거로 같은 선택을 한다.

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=spec-distill:validator` · `spec-distill:PostToolUse` ·
  `spec-distill:reminder` · `spec-distill:UserPromptSubmit` 은 가리킬 대상을 잃었다.
  **구조 검증이 `Stop` 훅으로 옮겨왔으므로 이 토큰들로 껐던 사용자는 검증이 말없이 되살아난
  것을 보게 된다** — `review-dispatch.py` 가 세션당 1회 그 사실을 알린다.
  가장 가까운 스위치는 `DEVBREW_SKIP_HOOKS=spec-distill:Stop` 이지만 **등가 대체재가 아니라
  더 넓다.** `:validator`/`:PostToolUse` 는 write-time 훅 하나만 껐고 dispatch 는 그때
  `Stop` 훅에 있어 계속 돌았다 — 즉 그 토큰들도 «검증만 끄기»였다. `:Stop` 은 발견·검증·
  dispatch 를 함께 끈다. 바로 아래 `SKIP_AUTOREVIEW` 항목과 **같은 종류의 비대칭**이며,
  차이는 이쪽엔 그나마 더 넓은 스위치라도 있다는 것뿐이다.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` 도 같은 릴리스에서 죽었으나 **대체재가 지정되지
  않는다** — 위 Removed 를 보라. `spec-distill:Stop` 을 대체재로 적지 않는 이유는 그것이 둘을
  함께 끄기 때문이다. 같은 것이라고 적으면 거짓이 된다.

### Security
- 은퇴한 kill switch 다섯(`spec-distill:PostToolUse`/`:validator`,
  `spec-distill:UserPromptSubmit`/`:reminder`, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`)을
  Stop 훅이 **세션당 1회** 공시한다. 전부 fail-open 방향으로 죽었다 — 껐다고 믿는 동작이
  말없이 되살아나므로, 침묵은 kill switch 를 보안 컨트롤로 다루는 CLAUDE.md 조항과 어긋난다.
  각 스위치는 **원래 읽히던 방식 그대로** 대조한다(토큰은 콤마 분리 + 전체 토큰, 환경변수는
  `== "1"`) — 다르게 매칭하면 공시가 사용자 자신의 설정에 대해 거짓을 말한다. 공시는 **구조
  검증 뒤·dispatch 앞**에서 나가므로 Layer 1 을 늦추지 않는다.

### Performance
기준선 `origin/main` **983d7d7** 대 이 브랜치, 같은 시나리오(도구 호출 약 30회 — Read 20 ·
Bash 5–7 · Write 3), 세 플러그인을 함께 로드, **팔당 2회**. 계측 래퍼는 스크래치 사본에만
넣었고 배포본에는 없다. 측정 환경: macOS · Claude Code 2.1.241.

- **없앤 훅의 비용 (Write 3회 + 프롬프트 1회 — 두 팔에서 동일):** 기준선 **384.6 / 398.7 ms**,
  이 브랜치 **0 ms**. 내역 — `spec-write-validator.py` ×3 = 110.4/121.3 ms,
  `pending-review-reminder.py` ×1 = 83.1/87.6 ms, quality-gates
  `post-tool-use-session-tracker.py` ×3 = 91.8/90.5 ms, project-init `docs-lint.py` ×3 =
  99.3/99.2 ms.
- **늘어난 것:** `Stop:review-dispatch.py` 가 발견·검증을 흡수해 80.5/84.6 ms → 109.1/100.2 ms
  (**+15.6 ~ +28.6 ms**). **이 증가분은 잡음과 분리되지 않는다** — 이 브랜치가 건드리지도
  않은 `spec-distill SessionEnd:session-end-cleanup.py` 가 **같은 팔 안에서** 65.6 → 43.7 ms
  (21.9 ms) 흔들렸다. 프로세스 기동 잡음이 증가분과 같은 자릿수라는 뜻이므로, 위 두 수를
  «Stop 훅이 정확히 그만큼 느려졌다»로 읽으면 안 된다. 아래 순감이 견고한 이유는 반대다 —
  없앤 385~399 ms 가 이 잡음보다 한 자릿수 크다.
- **시나리오당 순감 −356 ~ −383 ms.** 설계 §8 의 예측(≈244 ms)보다 크고, 격차(140~155 ms)의
  원인은 **둘**이다. ① 예측이 `pending-review-reminder.py` 를 실측값 부재로 제외했다
  (83.1/87.6 ms). ② **쓰기 훅 3개만 따로 봐도 예측이 낮았다** — 설계는 Write 1회당
  31.6+23.6+26.2 = **81.4 ms** 를 가정했는데 실측은 **≈100 ms/회**(3회 합 301.5/311.0 ms 대
  예측 244.2 ms)였다. 추정치를 다시 세울 사람에게는 ②가 ①보다 이월 가치가 크다 — ①은
  이 릴리스에서 사라지는 항목이고, ②는 훅 프로세스 기동 비용 자체의 보정값이다.
  비교군이 기준선보다 크지 않으므로 설계 §8 이 요구한 역행 advisory 는 해당 없음.
- **벽시계는 이 변경의 신호가 아니다.** 기준선 73.79/55.89 s, 이 브랜치 54.92/59.24 s — 두 팔의
  범위가 겹친다. 실행 간 벽시계 산포(≈18 s)가 훅 시간 차이(≈0.37 s)보다 두 자릿수 크므로,
  이 시나리오의 벽시계는 모델 지연을 재고 있다. 이 수치를 머지 게이트로 쓰지 않는다.

### Known limitations
- **in-flight 표시는 dispatch 만이 아니라 구조 검증도 멈춘다 — 최대 900초.** `A12` 와 설계
  §4.1 은 리뷰 진행 중인 문서를 «발견 결과에서 제외» 하라고 하고, 발견 결과가 곧 검증 후보
  집합이다. 그래서 dispatch 된 문서는 `INFLIGHT_TTL_SEC`(900초) 또는 verdict 중 먼저 오는
  것까지 **Layer 1 구조 검증을 받지 않는다 — 어떤 도구로 쓰든**. 창을 여는 조건은 좁다:
  모델이 dispatch mandate 를 무시해야 하고, 그 문서는 이미 리뷰 큐에 들어가 있다. 구현은
  명세대로이고 이것은 **명세 쪽 미결**이다 — 좁히려면 발견 제외와 검증 제외를 서로 다른
  술어로 가르는 설계 변경이 필요하며(armed 게이트를 그렇게 가른 전례가 이 릴리스에 있다),
  그 판단은 이 릴리스에서 하지 않았다. 다시 열 사람에게 필요한 사실은 이 세 가지다:
  창의 상한(900초) · 여는 조건(mandate 무시) · 대가(그 문서에 한해 Layer 1 정지).
- 발견은 훅의 cwd 리포만 본다. 다른 체크아웃의 문서는 `git status` 에 나오지 않는다 — 그
  워크트리에서 세션을 열면 커버된다.
- git 이 없거나 리포가 아니면 검증·dispatch 가 일어나지 않고 세션당 1회 loud advisory 가 나간다.
- **이 설계에는 cross-family 리뷰가 없었다.** 설계 리뷰 5라운드가 전부 Claude 단독이었다
  (codex 사용 한도가 2026-09-17 까지 소진). 어떤 종류의 공유-맹점이 남아 있는지 아무도 모른다.
- **선재 RED 면제 1건** (이 릴리스가 만든 것이 아니고, 이 릴리스가 고치지도 않는다):
  `tests/test_hook_output_schema.py::TestCrossResolverAdvisory.test_python_and_bash_resolvers_agree`
  는 **워크트리 안에서만** 돈다(`@unittest.skipUnless`)  — 그리고 워크트리 안에서는 구조적으로
  항상 실패한다. `scripts/state_path.py` 의 python 해석기는 `git rev-parse --git-common-dir` 로
  **메인 리포**의 `.claude/spec-distill` 을 가리키는 반면, 테스트가 비교하는 bash 식은
  `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` 로 워크트리 경로를 그대로 쓴다. 그 클래스의
  docstring 이 이미 «NG9 … the follow-up unification PR is needed» 라고 적어 둔 기지의 미해결
  항목이고, 두 훅의 output schema 와는 무관하다(나머지 21개는 통과). 면제 사유를 여기 적는
  이유: 이유 없는 면제 목록은 그 질문을 영구히 닫는다.

## [0.35.3] — 2026-08-25

### Added
- `tests/test_merge_review_adjudication.py` — degrade 사유가 **`advisory` 채널로**
  나가는지 잠그는 단언 3건. 계수(`adjudication_held`)와 사유는 다른 채널이라
  계수만 단언하면 사유 채널을 통째로 끊어도 GREEN 이었다 — 실제로 `advisory.extend`
  를 지우고 옛 키를 되살렸을 때 전 스위트가 통과했다. 주(主) 입력 실패 케이스는
  `held` 가 0이라 `advisory` 가 **유일한 신호**이고, 그 자리를 계측기로 삼는다.
  양성 짝(아무것도 안 버린 실행에는 사유가 없다)을 함께 건다.

## [0.35.2] — 2026-08-25

### Changed
- `scripts/merge_review.py` — 처분 원장의 degrade 사유를 `adjudication_reasons:` 대신
  `advisory` 리스트로 보낸다. `skills/reviewing-spec/SKILL.md`의 "그대로 표시"·"degrade
  없음" 판정은 `advisory` 에만 걸려 있어서, `load_history` 실패는 표시 규칙 없는 키로
  가고 그 짝 `_write_history` 실패는 `advisory` 로 가는 비대칭이 표시 층에 남아 있었다
  (설계 §7 #3 이 결함으로 지목한 바로 그 비대칭). 형제 `merge_brief_review.py:325-328`
  과 같은 선택. 사유는 이제 `emit()` 의 `_yaml_scalar` escape 를 탄다.
- `skills/reviewing-spec/SKILL.md` — 파싱 키 열거를 실제 stdout 과 맞추고, degrade 사유가
  `advisory:` 로 온다는 것과 `adjudication_held`/`adjudication_unknown` 이 degrade 의
  유일한 신호가 될 수 없다는 것을 명시.

### Removed
- `scripts/merge_review.py` stdout 의 `adjudication_reasons:` 키. `[0.35.0]` 에서 추가돼
  같은 브랜치 안에서만 존재했고 `main` 에 배포된 적이 없다 — deprecation window 대상 아님.
  `adjudication_held`/`adjudication_unknown` 두 계수 키는 그대로다.

## [0.35.1] — 2026-08-23

### Added
- dispatch 자리(7곳)에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.

## [0.35.0] — 2026-08-23

새 표면 3개(minor) — `merge_review.py` stdout에 subagent 발견의 처분 회계 채널을 얹는다.

### Added
- `scripts/merge_review.py` stdout에 `adjudication_held` / `adjudication_unknown` /
  `adjudication_reasons` 세 키 추가 — 판정(verdict)과 별개 채널로 처분 회계(수용/보류/
  입력실패/원리적 미상/강제)를 싣는다. `skills/reviewing-spec/SKILL.md`가 이 세 키를
  orchestrator가 파싱하는 stdout 키 목록에 나열.

### Fixed
- `scripts/merge_review.py`의 회계 결함 6건: ⑴ claude sentinel의 non-dict 원소를 조용히
  버리던 것을 `hold()`로 계수. ⑵ sentinel 부재·JSONDecodeError·payload 형태 불일치 세 경로를
  「0건」이 아니라 원리적 미상(`uncountable`)으로 구별 — issues 리스트가 아직 만들어지지
  않은 지점이라 개수를 알 방법이 없다. ⑶ YAML 마커 위반으로 폐기된 codex finding 개수를
  `reason` 문자열에 인코딩하지 않고(파일이 공급하는 `meta.reason:`과 충돌해 `int()` 크래시
  가능) out-of-band 4번째 반환값으로 보고. ⑷ `load_history()`가 원장 전체 손실
  (OSError/JSONDecodeError/비-list)과 id 없는 레코드를 침묵하지 않고 `source_failed`/`hold`로
  계수 — 짝 `_write_history`는 실패 시 advisory를 내는데 이쪽만 침묵하던 비대칭을 해소. ⑸
  `raised_count` 강제 변환(문자열→0)이 `>=3` 정체 게이트를 무력화하는데도 미보고이던 것을
  `gate=True` 강제로 기록. ⑹ category·target_section이 둘 다 빈 codex finding이 원장에도
  회계에도 안 잡히던 것을 `hold()`로 계수. 더불어 hold() 사유 문자열을 `str()`로 담으면
  summary 안의 개행이 stdout에 두 번째 `combined_verdict:` 줄을 주입할 수 있던 경로를
  `repr()` + `_yaml_scalar` escape로 닫았다(verdict-injection).

### Changed
- `scripts/merge_brief_review.py`를 shared `Ledger`(`scripts/adjudication.py` 심볼릭 링크)로
  전환 — critic 축의 비-dict 원소(findings로 승격 못 하는 **소실** → `hold()`)와 필수 필드가
  나빠도 그대로 싣는 §9.1 fail-open 데이터 경로(소실 아님 → `accept()`)를 서로 다른 Ledger
  어휘로 구별해 회계한다. codex 축의 malformed 개수도 `merge_review.py`와 같은 관례로
  `hold()`. 새 top-level 출력 키 없음 — 회계는 이미 escape되는 기존 `advisory` 채널에 얹는다.
  외부 출력 8개 키와 verdict 경로(`escalates`/`codex_degraded`가 평가하는 표현식) 무변경.

### Known gaps
- `merge_review.py`의 mixed-round 경로(`codex_failed: true`인 라운드에 findings가 이미
  파싱돼 있는 경우)는 여전히 그 codex finding **자체**를 원장에서 폐기한다 — 이번 수정으로
  폐기된 개수는 `adjudication_held`로 계수되지만, finding의 내용(category/severity/summary
  등)은 복원되지 않는다. `merge_brief_review.py`(brief 경로)는 이미 findings를 보존한 채
  degrade 마커를 함께 낸다 — 남은 격차는 공유 경로(`merge_review.py`, design-doc 리뷰) 한 곳.

## [0.34.0] — 2026-08-23

### Added
- `scripts/adjudication.py` — `shared/adjudication/adjudication.py` 정본을 가리키는 상대 심볼릭 링크. subagent 발견의 처분 회계(`수용·기각·보류` + 흡수·강제·입력실패·원리적 미상). 리포 최초의 import-only `.py` 심볼릭 링크.
## [0.33.1] — 2026-08-23

`run_spec_codex_reviewer.sh` 가 `CLAUDE_PLUGIN_ROOT` 를 기본값 없이 참조해,
스킬의 bash 블록에서 호출되면 `set -u` 아래에서 **codex 에 도달하기 전에** 죽던
결함을 고친다. `reviewing-spec` 의 codex co-review 는 그 경로에서 한 번도 실행되지
않았고, 산출물은 매번 `aborted_before_completion` 이었다 — 실패는 loud 했지만
모델 다양성은 상시 0이었다.

**Fixed**
- `scripts/run_spec_codex_reviewer.sh`: 형제 `run_brief_codex_reviewer.sh` 와 같은
  `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`
  를 추가하고 내부 참조 2곳을 `${PLUGIN_ROOT}` 로 통일(우회 경로 0).

**Added**
- `tests/test_run_spec_codex_reviewer.sh`: FALLBACK 회귀 락 — 환경변수를 지우고
  mock codex 를 태워 `codex_failed: false` + finding 산출을 요구한다. "exit 0 +
  YAML 존재"로는 고장난 러너도 통과하므로(degrade 계약이 그렇게 설계돼 있다)
  결과를 잰다. mutation 3축(fallback 삭제 · 경로 파손 · 참조 1곳 되돌림) 전부 RED 확인.
- `shared/tests/abort_trigger.sh`(신규 공용 모듈)를 사용하도록 ABORT 블록 전환.

**Changed**
- ABORT 계약 검증의 트리거를 환경변수 제거에서 **SIGTERM** 으로 교체. fallback 이
  생기면서 예전 트리거는 더 이상 중단을 일으키지 않아, 그대로 두면 assertion 이
  abort 경로를 한 번도 밟지 않은 채 GREEN 이 된다(2026-08-23 실측). 판정도
  `codex_failed: true` 에서 `reason: aborted_before_completion` 으로 좁혔다.

## [0.33.0] — 2026-08-22

interview brief 의 **분량 상한을 제거**한다. 절별 `≤N줄` 예산도, 150줄 트립와이어도,
그 지표를 계산하던 코드도 없다.

**Removed**
- `templates/interview-brief-template.md` 의 절별 분량 예산 7개 — §0 `≤15줄` · §1
  `≤12줄` · §2 `≤30줄` · §3 `≤25줄` · §4 `≤20줄` · §5 `≤25줄` · §7 `≤10줄`(합 137).
- `scripts/check_brief.py` 의 `LINE_TRIPWIRE = 150` 상수, advisory 분기,
  `payload_body_lines_excl_verbatim()` 함수, `gate` JSON 의 동명 키, 그리고
  `metrics` 서브커맨드. `metrics` 는 이제 unknown subcommand 로 rc 64.
- `tests/test_check_brief.sh` 의 "Task 5: 분량 지표" 블록과 그 블록만 쓰던 픽스처 4개
  (`interview-brief-over-budget.{md,audit.md}` · `interview-brief-long-verbatim.{md,audit.md}`).

**왜** — 상한의 원래 목적은 "짧게 써라"가 아니라 *"brief 가 해답을 미리 정해버리지
않게"* 였다(`2026-07-25-spec-distill-brief-format-producer-design.md` §5.3 + 같은
문서 Implicit context: superpowers 6.2.0 이 `Key Principles` 에서 *"Explore
alternatives"* 줄을 지워 하류 탐색 지시가 약해졌으므로 brief 의 과잉결정이 더
해롭다). 줄 수는 그 목적의 **대리 지표**인데 대상을 안 잰다 — 길이 ≠ 과잉결정이고,
오히려 §3 Open Questions(과잉결정의 정반대 절)를 성실히 채운 brief 가 예산을 태워
벌을 받는 방향으로 틀렸다. 실측으로도 오발했다: 2026-08-16 인터뷰에서 본문 153줄·
166줄로 두 번 발화했다
(`docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.audit.md:131,201`).

과잉결정은 이제 대리 지표가 아니라 **직접 측정기**가 본다 — `brief-readback` 이 묻는
두 번째 질문이 *"무엇이 확정이고 무엇이 아직 열려 있는가"* 다. 그 리뷰어 3종은
v0.24.0 에 생겼고 137/150 은 그 앞 버전 v0.23.0 의 산물이라, 대리 지표가 먼저 있었고
직접 측정기가 나중에 왔다. 게이트 코드 스스로도 *"분량은 목표이지 정확성 조건이
아니다"* 라고 적어 두고 있었다 — 결정론적 검사의 자리가 아니었다는 뜻이다.

하류에 기계적 한계는 없다: brief 는 `codex exec -`(stdin)로 들어가고 blob·프롬프트
빌더 어디에도 크기 상한이나 잘림이 없다.

**Changed**
- 숫자가 대리하던 계약은 **문장으로 남겼다.** §0 머리에 *"이 절은 요약이다 — 본문을
  여기 옮겨 적는 자리가 아니라, 다음 세션이 여기만 읽고도 방향을 잡을 수 있어야 하는
  자리다"*. §2 의 *"한 줄이 frontmatter 한 항목의 렌더다"*(bijection B)와 §4 의
  *"1항목 = 1줄"* 은 분량이 아니라 렌더 계약이라 그대로 둔다. `≤N줄` 이 이 문장들과
  **같은 괄호 안에** 있었으므로 괄호째 지웠다면 계약도 함께 사라졌을 것이다.
- `advisories` 채널 자체는 유지. `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 킬 스위치가 같은
  채널로 강등을 알리며, 그것은 분량과 무관한 graceful degradation 통보다.

**Added**
- `tests/test_brief_no_length_cap.sh` — 4층 회귀 락. **부재 검사만으로 된 락은 대상
  파일을 통째로 지워도 통과하므로** 층 1(양성 대조: 템플릿 8섹션 헤더 + `gate()` 존재)이
  "이 락이 실제로 그 코퍼스를 읽었다"를 먼저 증명한다. 층 2 는 보존 계약 3개를 **섹션
  윈도우 안에서** 본다(파일 전체 grep 이면 주석이나 다른 절이 대신 만족시킨다). 층 3 은
  개념 별칭(`최대 N줄` · `N줄 이내`)까지 덮는다 — 식별자만 잠그면 같은 것을 다른
  이름으로 부른 재삽입이 살아남는다. 층 4 는 grep 이 아니라 실제 호출로 gate JSON 키
  부재와 `metrics` rc 64 를 잰다.
- 기존 Task 5 블록을 "고치지" 않고 걷어낸 이유도 같다 — 트립와이어가 없는 지금 거기
  부정 assertion 만 남기면 무엇을 지워도 통과하는 빈 락이 된다.

## [0.32.7] — 2026-08-22

`tests/test_run_spec_codex_reviewer.sh` 의 FAKE_ROOT 를 **설치본 모양**으로 깐다.

**Fixed**
- FIX1 시나리오의 FAKE_ROOT 는 빌더 하나만 심볼릭 링크하고 형제
  `codex_prompt_common.py` 를 안 깔았다. 그런데도 통과했다 — CPython 은 링크된
  스크립트의 `sys.path[0]` 을 realpath 로 잡으므로(3.9.6 실측) 링크된 빌더가 형제를
  **정본 옆**에서 찾아냈다. 통과하지만 **설치본의 모양을 재고 있지 않았다**(감사 §7-9).
- 이제 빌더·`codex_prompt_common.py`·`prompt-preamble.md` 를 모두 **물리 사본**으로
  깐다(설치 시 링크가 역참조되는 실제 배포 모양). 실측: 형제 모듈을 빼면
  `ModuleNotFoundError`, 프리앰블을 빼면 로더가 **FAKE_ROOT 안의 경로**를 못 찾아
  실패한다 — 두 형제가 실제로 load-bearing 이 됐다는 증거다(수정 전에는 형제가
  아예 없어도 GREEN 이었다).

**Added**
- FAKE_ROOT/scripts 에 심볼릭 링크가 0개인지, 파일이 셋 다 깔렸는지 단언하는 회귀 락.
  다시 `ln -s` 로 돌아가면 realpath 우회가 되살아나고 사본이 dead weight 가 되는데,
  그 상태는 조용하다(시나리오는 계속 통과한다). 그래서 모양 자체를 잰다.

**동작 무변경** — 테스트 하니스만 바뀌었고 shipping 코드는 그대로다.

## [0.32.6] — 2026-08-22

`scripts/codex_prompt_common.py` 의 〔앵커 주의〕 주석 블록을 **제거**한다.

**Changed**
- `scripts/codex_prompt_common.py` — `scripts/prompt-preamble.md` 리터럴이
  `test_copy_of_contract.sh` 축 1a 의 도출 앵커라고 경고하던 주석 4줄을 삭제.
- **v0.32.5 의 "이 리터럴은 앵커다" 항목은 이제 유효하지 않다.** 그 축은 배포
  지점을 구조(인덱스∪워킹트리에 실재하는 `plugins/*/scripts/<파일>`)에서 도출하고
  산문은 거기에 더하기만 한다 — 빼지 못한다(감사 §7-8 해소). 실측: 같은 리터럴을
  다시 걷어내도 도출은 3건 그대로이고 락은 GREEN 이다(v0.32.5 때는 3→2 로 줄며 RED).

**동작 무변경** — 주석만 지웠고 실행 경로는 그대로다.

## [0.32.5] — 2026-08-22

Task 35 Step 0 — P21 프리앰블 로더 4벌을 `shared/codex/codex_prompt_common.py` 정본으로
통합. shipping 동작 무변경(네 빌더가 내는 프롬프트 바이트 동일 — 실측).

**Added**
- **`scripts/codex_prompt_common.py`** — `shared/codex/codex_prompt_common.py` 의 물리
  사본(`# copy-of:` 마커). 심볼릭 링크로 배포하지 않는 이유와 축 1c 의 ∀ 계약은
  quality-gates CHANGELOG `[4.1.10]` 과 같다(같은 정본의 두 배포 지점).
- **`shared/tests/test_no_new_duplication.sh`** — 새 중복의 **유입**을 막는 락(20줄 이상
  완전히 같은 블록이 `copy-of` 로 설명되지 않으면 RED). 위 통합 대상을 적발한 스캐너라
  같은 릴리스에 기록한다. `# guards: plugins/** shared/**` 로 다섯 플러그인 전체를
  지키며, `[0.32.4]` 의 귀속 관례에 따라 이 릴리스가 노트를 쓴 두 플러그인 엔트리에 함께
  적는다. 계약·면제 술어·vacuous 가드(단위별 등식)의 상세는 quality-gates CHANGELOG `[4.1.10]`
  과 같다(같은 파일, 두 기록 자리).

**Changed**
- **`scripts/build_spec_codex_prompt.py` · `scripts/build_brief_codex_prompt.py`** — stdout
  인코딩 가드와 P21(신뢰불가 입력 프리앰블) 로더를 형제 사본에서 import 한다.
  `build_brief_codex_prompt.py` 는 20줄 스캐너가 적발한 3쌍에 **들어 있지 않았다** —
  같은 블록을 갖고 있지만 중간에 무관한 주석(`AXES` + §6 근거)이 끼어 20줄 연속이 끊겼기
  때문이다. 크기 임계 아래에 숨은 같은 보안 컨트롤 사본이므로 함께 통합했다.
- **`scripts/codex_prompt_common.py` 의 `scripts/prompt-preamble.md` 리터럴은 앵커다** —
  `test_copy_of_contract.sh` 축 1a 의 참조원 도출이 이 문자열로 배포 지점 플러그인을
  고른다. 통합 초안이 빌더에서 그 리터럴을 걷어냈을 때 spec-distill 이 도출 3건→2건으로
  조용히 이탈했고(실측 RED), 정본 주석에 리터럴과 경고를 함께 넣어 복구했다.

## [0.32.4] — 2026-08-21

Task 33 fix round 5 (마지막). 한 항목 — fix round 4 가 만든 **단일 실패 지점**에 짝을 붙인다.

**귀속**: 새 파일 둘은 `shared/tests/` 에 있어 어느 플러그인 소유도 아니다. 이 리포의
선례(`shared/tests/test_skill_reference_pointers.sh` 를 Task 31 이 quality-gates 엔트리로,
Task 33 이 spec-distill 엔트리로 적은 것)를 따라 **그 이빨을 쓰는 락이 사는 플러그인**에
귀속한다 — 세 소비자가 전부 spec-distill 이므로 여기다.

**Added**
- **`shared/tests/test_presence_corpus_behavior.sh`** (14 단언) — `presence_corpus.sh` 의
  **행동**을 고정한다. fix round 4 가 24줄 중복을 지우면서 세 락의 이빨을 헬퍼 한 파일로
  모았고, 그 한 곳이 조용히 무력화되면 **세 락이 동시에** 이빨을 잃는다. 헬퍼는 라이브러리라
  `# guards:` 도 `--emit-scanned` 도 없다 — `assert.sh` 와 같은 상황이고 이 리포는 그것을
  `test_assert_behavior.sh` 로 답했다. 이 파일이 그 짝이며 같은 관례를 따른다(자체
  `t_ok`/`t_no` 카운터 · 픽스처 probe · rc 로 판정 관측 · `--emit-scanned` 응답).
  - **(1) 분류기 판정** — 소유 두 모양 통과(양의 짝) · **플러그인 레벨 공유 계약 거절**
    (대상은 열거 아닌 `git ls-files` 도출 + 도출 0건이면 loud FAIL) · 혼합 코퍼스는
    한 건만 소유 밖이어도 실패 · `plugins/` 밖 경로 거절.
  - **(2) 세 소비자를 실제로 돌려** 헬퍼 판정 줄이 나오는지와 코퍼스 크기(구조적 하한 2)를
    읽는다. 소비자의 GREEN/RED 자체는 보지 않는다 — 다른 이유로 RED 인 소비자와 묶지 않기 위해.
  - **(3) 채택자 락의 격리 불변식**을 **산술**로 잰다: Σ(채택자별 자기-파일 수) = 전체
    코퍼스 크기. 루프가 합집합을 넘기면 Σ = 채택자수 × 전체 가 되어 어긋난다.
  - (2)·(3)은 fix round 4 에서 **한 번 손으로 돌린 통제**다 — 매 실행마다 돌게 옮겼다.

**Fixed**
- **`presence_corpus.sh` 가 빈 코퍼스를 조용히 통과시켰다.** `own=0 foreign=0` 에 `ok` 를
  냈다〔실측: `rc=0`, *"presence 대상 0개가 전부 skill 소유 표면"*〕. 소비자의 도출이 깨져
  0건이 되면 그 스위트의 존재 검사가 **전부 vacuous** 해지는데 이 가드가 그 위에 초록을
  찍는다 — 세 락이 동시에 이빨을 잃는 바로 그 경로이고, 헬퍼가 그것을 감춰 준다.
  이제 시끄럽게 실패한다. 이 결함은 **행동 락을 쓰다가** 드러났다.

**Docs**
- `test_skill_reference_pointers.sh` 주석에 **자기 보증 금지가 막지 못하는 것**을 적었다:
  identity 만 막고 A→B/B→A **상호 보증**은 막지 않는다. skill 레벨은 소유 SKILL.md 를
  계속 요구하므로 이 구멍은 **플러그인 레벨 파일이 둘 이상**이어야 열린다(오늘 1개).
  둘째를 추가하는 사람이 서 있을 자리에 뒀다.

**양성 통제 4종** (전부 리포 원래 경로에서, 기대 방향으로 떨어진 것만으로는 증거가 아님)
- 분류기 반전(플러그인 레벨을 소유로) → 거절·혼합 두 단언 RED.
- 빈-코퍼스 수리 되돌리기 → vacuity 단언만 RED.
- 헬퍼의 판정 줄 제거 → (2) 섹션 4건 RED(세 소비자 전부 + 하한).
- 채택자 루프 격리 파괴 → (3) 산술 RED(**합 6 ≠ 전체 3** = 채택자 2 × 파일 3).
- 복원 → 14/14 GREEN, 두 파일 해시 일치.

## [0.32.3] — 2026-08-21

Task 33 fix round 4 (PR5 출하 전 마지막). 전-브랜치 seam 리뷰 = **merge 안전**.
이 라운드는 그 리뷰가 지목한 **브랜치가 만든 seam 결함 둘**을 닫는다.

**Fixed**
- **포인터 락이 자기 유일한 실사례를 안 보고 있었다 (seam).** Task 31 이 그 락을 쓸 때
  `references/*.md` 는 **잎**이었다 — 가리켜지기만 했다. Task 33 이 그 전제를 깼다:
  `conducting-interview` 는 공유 계약을 자기 SKILL.md 가 아니라 `references/finishing.md`
  에서 가리킨다. 정방향 코퍼스는 `SKILL.md` 뿐이라 **그 포인터를 한 번도 열지 않았다.**
  같은 브랜치의 `test_proceed_gate_adopters.sh` 는 반대로 그 자리를 **의도적으로** 포인터
  출처로 인정한다 — 두 락이 서로 모순인 채 출하됐다.
  - 정방향 fail-open: 세 번째 skill 이 자기 `references/*.md` 에서만, 오타로 가리키면
    포인터 락은 침묵(파일을 안 연다)하고 채택자 락도 침묵(오타라 채택자로 안 세어 ≥2 하한
    유지)한다. 런타임에 없는 경로를 Read 하고 공유 계약이 조용히 사라진다.
    〔차분〕 `finishing.md` 에 오타 포인터 주입 → **c8e6869 GREEN / 이번 RED**.
  - 역방향 false-RED: 플러그인 레벨 정본을 SKILL.md 포인터 **하나**가 지탱해, 그쪽 표기가
    바뀌면 `finishing.md` 가 여전히 가리키는데 "고아"가 된다.
    〔차분〕 그 상황 구성 → **c8e6869 RED(거짓 고아) / 이번 GREEN**.
  - 수리: 정방향 출처를 **SKILL.md ∪ 모든 references/*.md** 로 넓혔다. 넓힌 대가로 생기는
    유일한 새 구멍(어떤 파일이 출처이자 대상)은 **자기 보증 금지**로 막는다 — 자기 자신을
    가리키는 포인터는 소유 증거로 기록하지 않고 loud FAIL 한다(mutation 실증).
    `plugin_root` 도출도 두 모양 다 맞게 일반화했다(`${x%/skills/*}` 는 플러그인 레벨
    출처에서 경로 전체를 돌려준다).
- **중복 제거가 산출물인 태스크가 24줄 바이트-동일 중복을 만들었다.** `d7356ea` 가
  `test_brief_review_entry.sh` 와 `test_conducting_interview_stage.sh` 에 같은 가드 블록을
  복제했고, 한 라운드 뒤 "통과 시 침묵" 결함을 **양쪽에 따로** 고쳐야 했다.
  `copy-of` 마커는 **전체 파일** 사본을 다루는 메커니즘이라 조각에는 맞지 않는다 —
  그래서 마킹이 아니라 **추출**했다: `shared/tests/presence_corpus.sh` 의
  `assert_presence_corpus_skill_owned`. 세 소비자(위 둘 + `test_proceed_gate_adopters.sh`
  의 모양 가드)가 한 벌을 공유한다. 〔통제〕 헬퍼의 `ok` 를 지우면 **세 소비자 전부** 단언
  −1, 소유 패턴을 깨뜨리면 **세 소비자 전부** RED — 사본이 아니라 실제로 그것을 쓴다.

**Docs**
- 감사문서 §6 표: **「면역(도출)」이 판정이 아니라 그날의 관측**임을 경고로 못 박고
  **「측정 시점」열**을 추가했다. 두 행(`test_reviewing_spec_design_only.sh` ·
  `test_brief_review_meta.sh`)이 「면역」으로 적혀 있었지만 실제로는 **열거된 `grep -r` 루트**
  였고 Task 33 이 둘 다 손수리했다 — §3 이 "absence 만 수리 대상"이라 말하므로 낡은
  「면역」칸은 다음 사람에게 **건너뛰라고 지시한다.** 상속-대신-도출을 막으려 쓴 문서가
  정확히 그 상속을 부르는 열을 갖고 있었다. 이 브랜치가 만든 독자
  (`test_proceed_gate_adopters.sh`)와 라이브러리(`reconstruct-skill.sh`)도 표에 넣었다.
- 감사문서 §7-6: 거부 표면을 **전수 프로브로 재측정**했다. 앞 판본이 적은 "외부 URL 인용"만이
  아니라 **포인터 의도가 있는 표기 둘**(`./references/x.md` · 백틱 없는 표 셀)도 거부된다 —
  즉 "인용을 포인터로 오해한다"가 아니라 "인식 형태 열거가 좁다"가 옳은 서술이고, 앞 판본이
  유일한 처방으로 적은 "URL 스킴 배제"는 그 두 행을 못 덮는다. 표로 적고 선택지를 넷으로 넓혔다.
- 감사문서 **§7-7** 신설: 계약의 **요약본**(`spec-distill/README.md` · `CLAUDE.md`)이
  자제(自制)만으로 지켜진다. §8 이 기록한 *"자제 규칙은 지켜지지 않는다"* 가 그대로 적용되며
  근거는 이 태스크 자신의 초고다. 발동 조건 + 왜 지금 술어를 만들지 않는지 + 가장 그럴듯한
  좁은 술어를 적었다.

## [0.32.2] — 2026-08-21

Task 33 fix round 3 (마지막). 스코프 재리뷰는 **모든 지적 반영 / load-bearing 신규 없음**
이었고, 남은 다섯은 전부 문서 정합 또는 한 줄 위생이다. 하나는 계측기 결함이었다.

**Fixed**
- **정본이 자기 측정자 인벤토리를 낡은 채로 뒀다.** round 2 가 세 번째 측정 스캔
  (`test_proceed_gate_adopters.sh`)을 추가하고 「검증」 1항에서 이름까지 댔으면서,
  「앵커는 각 skill 에」 절은 여전히 **"두 측정 스캔"** 을 열거하고 "두 테스트 / 두 presence
  검사 / 두 락" 으로 이어갔다. `reviewing-spec/SKILL.md` 도 같은 문장을 안고 있었다.
  **F1 의 결함이 F1 의 수리 안에서 재발한 것** — 부정확한 자기 서술이 하필 진짜 위험이
  있는 자리에 서 있다. 규칙을 **개수 없는 한 문장**("이 계약의 앵커를 재는 스캔은 전부
  코퍼스를 그 skill 소유 표면으로 한정한다")으로 바꾸고 목록은 예시로 격하했다 — 넷째가
  생겨도 고칠 필요가 없다.
- **정본이 자기 앵커 리터럴을 하나 적게 셌다.** "위 Step B 표의 ① 행과 가드 2 본문"이라
  적었으나 실측 3줄(**25 · 60 · 78**)이고 78 은 그 문단이 설명하는 「검증」 절 안이다.
  목록을 고치되 **개수를 세지 말라**는 지시를 함께 넣었다 — 그 수는 안전과 무관하고
  (안전은 코퍼스 경계가 지탱한다) 이 목록이 정확히 유지된다는 보장이 없다(실제로 낡았다).
- **[0.32.1] 의 P5 통제 수치 정정.** *"정본에서 4줄을 세어 만족"* 이라 적었다. 재측정하면
  **3줄**(+ `polite stop` 5줄)이다. 〔경위〕 그 4 는 측정 시점(`d7356ea`)에는 **맞았다** —
  round 2 자신이 「검증」 1항을 다시 쓰면서 `다음 턴` 이 줄바꿈 경계에 걸려 4→3 이 됐다.
  즉 전사(轉寫) 오류가 아니라 **내 편집이 내 측정을 낡게 만든** 경우다. 그래도 지금은
  틀린 수이므로 정정하고, 이빨을 증명하는 통제 행이라 재측정으로 갈음했다.
- **round 1 의 F1 가드 둘이 통과 시 침묵했다.** `test_conducting_interview_stage.sh` ·
  `test_brief_review_entry.sh` 의 가드는 `*)` 분기에서만 `no` 를 불렀다. 〔실측〕 가드를
  통째로 제거해도 단언 수·출력이 **완전히 동일**(92/36 → 92/36) — 감사문서 「계측기」 절이
  기록한 *"아무것도 안 하면서 GREEN"* 클래스다. round 2 의 같은 가드는 통과 시 `ok` 를
  낸다. 둘을 거기에 맞췄고, 이제 가드를 제거하면 93→92 · 37→36 으로 **관측된다**.

**Added**
- **채택자마다 `degrade 채널` 절의 존재를 잰다.** 정본 Step B 의 의무 중 **라벨**
  (이름 붙은 절이 있는가)은 채널 *형태*를 건드리지 않고 한 줄로 잴 수 있다 —
  `grep -cF 'degrade 채널'`. 계약이 두려워한 실패(새 채택자가 "해당 없음"으로 넘김)를
  정확히 그것이 잡는다. 통제: 한쪽 절 삭제 → 그 채택자만 RED(다른 쪽 GREEN) · 양쪽 삭제 →
  RED 2 (정본이 같은 라벨을 2줄 담고 있으나 **코퍼스 밖이라 구제하지 못한다**).

**Docs**
- 감사문서 §7-5 를 **형태 검증**으로 좁혔다. 앞 판본은 "의무 전체가 기계화 불가"라 적었는데
  그 사유(형태가 skill 마다 다르다)는 형태에만 해당했다 — **연기의 사유가 연기의 범위보다
  좁으면 그 차이만큼 공짜로 미뤄진다**는 교훈을 항목에 적었다.
- 감사문서 **§7-6** 신설: 포인터 락의 접두사 거부가 **리포 전역**이고 산문이 방아쇠라,
  미래 SKILL.md 가 포인터 의도 없이 `…/references/*.md` 를 담은 외부 URL 을 인용만 해도
  공유 락이 RED 가 된다. 발동 조건 + 선택지 셋(가장 좁은 것은 URL 스킴 배제).
- `test_proceed_gate_adopters.sh` 주석: 채택자 하한은 **개수이지 구성원이 아니다**
  (오늘 치환이 RED 인 것은 대체 후보에 앵커가 없어서인 **우연**) · 도출은 리터럴 등장을
  셀 뿐이라 HTML 주석·예시 언급도 채택자로 등록된다(거짓 RED, fail-closed).
- `test_brief_review_entry.sh` 의 `CI_FILES` 정의부(:20)에 가드로 가는 포인터 한 줄 —
  가드와 그 근거가 110줄 아래에 있어, 넓히려는 사람이 서는 자리에서는 안 보였다.
- `test_conducting_interview_stage.sh` 의 §8/§9 잔존 검사 옆에 주의 한 줄: `CI_ALL` 에 든
  공유 계약은 **다른 문서의** 절 번호를 인용할 수 있고 이 검사는 그것을 payload 좌표와
  구별하지 못한다(실측: 감사문서 `§8` 인용 하나로 발화 — 이번 라운드에 실제로 밟았다).
  공유 계약에서는 절을 번호가 아니라 제목으로 인용하는 것이 회피책이다.

## [0.32.1] — 2026-08-21

Task 33 fix round 2 — 한 항목. `proceed-gate.md` 와 `reviewing-spec/SKILL.md` 가 **존재하지
않는 락을 인용**하고 있었다.

**Fixed**
- **`reviewing-spec` 표면의 기계적 앵커를 아무도 재지 않았다.** 정본 「검증」 절은
  *"**각 skill 표면에** 정지 어휘가 실재하는지를 grep 이 잰다"* 고 적고,
  `reviewing-spec/SKILL.md` 의 AC19 불릿은 *"기계적 검증 앵커가 사는 곳이 거기다"* 라고
  한 걸음 더 나간다. 〔실측〕 `턴 종료|다음 턴` 을 재는 단언은 리포 전체에 둘뿐이고
  (`test_conducting_interview_stage.sh` 의 `ci_cat` · `test_brief_review_entry.sh` 의
  `CI_FILES`) **둘 다 conducting-interview 표면만 본다.** 계약을 통일해 놓고 이행 검증은
  한쪽에만 있었다 — 삭제된 규칙이 아니라 **처음부터 없던 규칙을 인용하는** 형태다.
  주장을 약화하는 대신 **참으로 만들었다**: 두 게이트를 같은 방식으로 잰다.

**Added**
- **`tests/test_proceed_gate_adopters.sh`** — 공통 계약의 **채택자 대칭** 락.
  채택자를 열거하지 않고 **정본을 가리키는 포인터에서 도출**하고(세 번째 skill 이 채택하면
  자동으로 같은 요구를 받는다), 채택자마다 **자기 표면**에서 가드 2 기계적 앵커(정지 어휘)와
  가드 1 앵커(polite stop)를 잰다. 기존 `reviewing-spec` 테스트에 끼워 넣지 않은 이유는
  그러면 같은 검사가 두 벌 독립 저술되고 스코프 규칙이 갈라지기 때문이다 — **이 결함을 만든
  바로 그 구조**다.
  - **F1 위험이 여기에도 그대로 적용된다**: 정본은 앵커 리터럴을 계약 어휘로 담고 있어,
    코퍼스에 들어오면 채택 skill 이 문구를 다 잃어도 GREEN 이 된다. 〔실증〕 정본을 코퍼스에
    넣고 구조적 가드를 뺀 변형에서 `reviewing-spec` 의 정지 어휘·polite stop 을 통째로
    지워도 **GREEN**(정본에서 4줄을 세어 만족) / 스코프 복원 시 **RED 2건**.
    그래서 코퍼스는 채택자 소유 표면으로만 구성하고, 구조적 가드 두 개(모양 검사 + 정본
    이름 검사)로 그 편집을 막는다.
  - **채택자 하한이 1 이 아니라 2 인 이유**: 이 파일이 플러그인 레벨에 사는 근거가 "두 skill 이
    공유한다"이다. 1 로 떨어지면 정상 상태가 아니라 **한쪽이 조용히 이탈**한 것이고, 이탈한
    skill 은 그 순간 측정 밖으로 나간다 — 코퍼스 축소가 vacuity(≥1)를 통과하는 바로 그 모양.
    숫자를 박은 것이 아니라 **파일의 배치 근거**에서 도출한 하한이다.
  - 양성 통제 7종: 단언 7건이 실제로 실행·계수됨(도달성) · `reviewing-spec` 정지 어휘만 제거
    → 그 줄만 RED, interview 는 GREEN(채택자별 스코프 실증) · polite stop 만 제거 → 가드 1 만
    RED · 포인터 제거 → 채택자 1 → 하한 RED · 위 fail-open 차분 · 복원 GREEN + 해시 일치.

**Docs**
- 정본 「검증」 1항이 **재는 주체를 이름으로** 댄다(주장에서 확인 가능한 사실로).
- 감사문서 §7-5 신설 — 공유 계약의 **degrade 채널 의무**는 아직 산문일 뿐이고, 기계화는
  **세 번째 채택자**가 나와야 형태가 생긴다. 발동 조건과 "오늘 만들지 않는 이유"를 적었다.
- 포인터 락 주석에 리졸버 form ②(`plugins/<p>/…`)가 오늘 **살아 있는 인스턴스 0** 이고
  합성 케이스로만 검증됐음을 기록(코퍼스가 아니라 갈래이므로 vacuity 대상 아님).

## [0.32.0] — 2026-08-21

Task 33 fix round 1. 리뷰 판정은 **Spec PASS / Quality FAIL** 이었고, 결함은 리팩터가
만들어 낸 **산문 계약** 쪽에 몰려 있었다 — 엔지니어링(1:1 접두사 리졸버 · presence/absence
코퍼스 분리 · 여섯 코퍼스 수리 · 격리 설치 실측)은 독립 재도출로 유지됐다.

**Added**
- **정본이 각 skill 에 `degrade 채널`의 이름을 요구한다 (F2).** [0.31.0] 의 정본은
  *"모든 degrade record 를 출력하고 없으면 `degrade 없음`"* 을 계약으로 적었는데, 그 문장은
  `conducting-interview` 의 메커니즘(`brief_review_degradations` 원장)을 계약으로 승격시킨
  것이었다. `reviewing-spec` 에는 그런 원장이 없다 — `merge_review` 플래그와 파싱-시점
  `advisory:` 줄이 있을 뿐이고 게이트 템플릿에는 degrade 슬롯조차 없었다. 그래서 Phase 5 는
  `codex_degraded: true` 인 라운드에도 `degrade 없음` 을 내거나(사용자에게 리뷰 커버리지에
  대한 거짓 진술) 방금 따르라고 지시받은 계약을 무시하거나 둘 중 하나였다.
  정본은 이제 **채널-중립**으로 의무만 정하고(감추지 않는다), 각 skill 이 자기 채널을 이름으로
  대게 한다. 채널이 없다는 사실 자체가 degrade 이며, 채널을 대지 않은 채 "없음"을 내는 것은
  금지다. `reviewing-spec` 은 실제 채널(`codex_degraded`·`claude_degraded`·
  `claude_verdict_unrecoverable` + `advisory:`)을 명시하고 게이트 `question` 에 degrade
  슬롯을 얻었다. `conducting-interview` 는 `brief_review_degradations` 원장을 이름으로 댄다.
- **presence 코퍼스 구조적 가드 (F1).** `test_conducting_interview_stage.sh` ·
  `test_brief_review_entry.sh` 에 "`CI_FILES` 에 이 skill 소유가 아닌 파일이 들어오면 즉시
  FAIL" 을 넣었다. 〔실측〕 가드 없이 `CI_FILES` 를 `plugins/spec-distill/references/*.md` 까지
  넓힌 상태에서 `finishing.md` 의 옵션 ① 정지 어휘와 `polite stop` 을 통째로 지워도 두 락이
  **GREEN** 이었다. 그 편집은 그럴듯하다 — [0.31.0] 이 네 개의 *부재* 코퍼스에 정확히 같은
  편집을 했기 때문이다. 주석이 아니라 가드여야 하는 이유가 그것이다.
- **스캔 루트 실재 단언 (F4).** `test_brief_review_meta.sh` · `test_reviewing_spec_design_only.sh`
  는 `grep -r` 루트에 문자열을 덧붙이기만 했다. 오타·개명이면 *No such file* 이 `2>/dev/null`
  에 삼켜지고 부재 단언은 좁아진 코퍼스 위에서 통과한다. 〔차분 실측〕 공유 계약 디렉터리를
  치운 상태에서 **[0.31.0] 판본 GREEN / 이번 판본 RED**.

**Changed**
- **정본의 「검증」 절이 참인 이유를 다시 적었다 (F1).** [0.31.0] 은 *"이 파일은 앵커의 사본을
  두지 않는다"* 고 적었으나 **거짓**이었다 — `grep -cE '턴 종료|다음 턴'` = 4 (Step B 표 ① 행 +
  가드 2 본문). 그 리터럴은 계약의 어휘라 뺄 수 없고, 빼려고 계약을 약하게 쓰는 것이 더 나쁘다.
  진짜 보호는 자제가 아니라 **코퍼스 경계**(두 측정 스캔이 skill 소유 표면으로 한정)이며,
  틀린 이유를 적어두면 진짜 위험 경로를 가린다. 이제 그 경계와 위 구조적 가드를 명시한다.
- **`reviewing-spec` 의 "Step C" 지시대상 모호성 제거 (F3).** 이 SKILL 에는 `### Step C —
  응답 처리` 가 이미 있는데 [0.31.0] 이 정본의 `## Step C — 두 가드` 를 인접한 두 불릿에서
  같은 짧은 이름으로 인용했다. 기계적 앵커를 찾는 사람이 정본으로 가서 거기서 리터럴을 보고
  "공유 앵커"라 결론지어 이 SKILL 의 문구를 지우는 경로가 열린다. 두 인용을 완전한 이름으로
  적고, 앵커가 사는 곳이 어디인지 명시했다.
- `finishing.md` B-2 의 *"reviewing-spec Phase 5 Step A와 대칭으로"* 를 정본 `## Step A`
  인용으로 교체 (F8) — 60줄 위에서 은퇴시킨 skill-대-skill 대칭 모델을 그 문장이 되살리고 있었다.

**Fixed**
- **[0.31.0] 엔트리의 수 정정 (F7).** "부재 락 **4건**"이라 적고 **다섯**을 나열했다. 옳은 수는
  **6** 이다(여섯째 `quality-gates/tests/test_law2_prose.sh` 는 그 플러그인 CHANGELOG 에 있다).
- **[0.31.0] 엔트리의 성격 규정 정정 (F7).** "전부 `skills/*/references/` 까지만 도출하고 있었다"
  는 **둘에 대해 거짓**이다: `test_brief_review_meta.sh` 는 `grep -rnE … "$SD/scripts" "$SD/skills"`
  였고 `test_reviewing_spec_design_only.sh` 는 `references/` 글롭이 아예 없는 전-트리 재귀
  루트였다. 공통점은 글롭의 모양이 아니라 **`skills/` 밖을 못 봤다**는 것이다.
- **포인터 락: 역방향이 접미사로 소유를 판정하던 것 (F5).** 정방향만 as-written 으로 조이고
  역방향은 `sed 's|.*/\(references/\)|\1|'` 로 접미사를 잘라 비교했다. 그래서
  `${CLAUDE_PLUGIN_ROOT}/references/notes.md` 포인터가 `skills/<s>/references/notes.md` 의
  소유 증거로도 인정됐다 — 동명 파일이 양쪽에 있으면 skill 레벨 파일이 **아무도 안 가리키는데도**
  고아로 안 잡힌다. 이제 정방향이 만든 `(SKILL.md, 해석된 대상)` **쌍**을 그대로 되쓴다.
  〔차분 실측〕 그 상황을 구성해 **[0.31.0] 판본 GREEN / 이번 판본 RED**.
- **포인터 락: 인식 못 하는 접두사가 거부가 아니라 절단됐다 (F6).** 접두사를 열거해 골라 받는
  정규식은 열거 밖 형태에서 실패한 뒤 문자열 **중간**의 맨몸 `references/…` 에서 매치를 시작해,
  그 표기를 조용히 "스킬 디렉터리 상대"로 재해석했다 — 헤더와 설계 노트가 "폴백 없음"이라
  주장하는 자리에 **절단형 폴백**이 있었다. 토큰을 통째로 삼키는 클래스로 잡은 뒤 형태를
  판정하고, 세 형태 중 어느 것도 아니면 loud FAIL 한다. 〔차분 실측〕 중괄호 없는
  `$CLAUDE_PLUGIN_ROOT/references/x.md` + 동명 skill 레벨 파일 → **[0.31.0] 판본 GREEN
  (조용한 재해석) / 이번 판본 RED**. 인식하는 세 형태와 `**볼드**` 표기는 거짓 거부 없음(11/11).

**Docs**
- `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md` 에 §8 신설(공유 참조 파일 —
  처방을 거꾸로 적용하지 않기), §7-3 해소 기록, §7-4 신규 이월 항목
  (`quality-gates/tests/test_no_secret_prompts.py` 의 한 칸 위 맹점), §6 재도출 실측(21+1) 추가.

## [0.31.0] — 2026-08-21

Task 33 — `/compact` proceed 게이트 **두 벌의 공통 골격을 한 파일로**. 사용자 요청
*"저장소 전반의 `/compact` 방식을 점검하고 일관된 형태로 통일해"* 의 마지막 축이다.

**Added**
- **`references/proceed-gate.md` (플러그인 레벨, 71줄).** `reviewing-spec` Phase 5 와
  `conducting-interview` 종료 Step B 가 공유하는 **골격 · 두 가드 · 예외 경로**의 정본.
  두 skill 이 공유하므로 어느 skill 밑에도 두지 않았다 — 이 리포의 첫
  `plugins/<p>/references/` 파일이다.
  〔격리 설치 실측〕 이 모양이 실제로 배포되는지 재봤다(`CLAUDE_CONFIG_DIR=<tmp>` 로
  사용자 `~/.claude` 격리 증명 후 `plugin marketplace add` + `plugin install`).
  설치본 `…/spec-distill/0.31.0/references/proceed-gate.md` 로 **그대로 실린다** —
  `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 포인터가 설치본에서 resolve 된다.
  플러그인 루트의 새 디렉터리가 설치에서 누락될 가능성은 측정으로 배제됐다.

**Changed**
- **두 게이트가 자기 어휘만 인라인으로 남긴다.** 각 skill 에 남은 것: 정본을 가리키는
  `Read` 포인터 · 자기 어휘의 `AskUserQuestion` 옵션 라벨 · verbatim `/compact` 템플릿 ·
  skill 고유 스텝(interview 의 B-0 확정 후보·재제시 상한, reviewing-spec 의 `spec_path`
  선검증·AC8 경계). 옵션 ① 의 정지 문구(`턴 종료`·`다음 턴`)는 **각 skill 에 그대로 남는다**
  — 기계적 검증 앵커가 거기 살고, 정본이 그 리터럴을 복사하면 자기 인용이 락을 먹는다.
- `conducting-interview/references/finishing.md` 의 Step B 머리에서 *"같은 두 가드를
  interview 어휘로 **독립 저술**합니다"* 를 삭제 — 더 이상 참이 아니다.
- **`tests/test_conducting_interview_stage.sh` 의 코퍼스를 presence/absence 로 분리.**
  `CI_FILES`(이 skill 자신의 표면)는 **존재** 검사용, `CI_ALL`(+ 플러그인 레벨 정본)은
  **부재** 검사용. 공유 파일을 존재 검사에 넣으면 "이 skill 이 자기 어휘를 잃었다"를
  공유 파일이 대신 만족시킨다(§4 거울 클래스).

**Fixed**
- **부재 락 4건이 플러그인 레벨 `references/` 를 못 보고 조용히 약해지는 것을 차단.**
  전부 `skills/*/references/` 까지만 도출하고 있었다 — 한 칸 위는 밖이었다. 금지 토큰을
  정본 파일에 주입해 **수정 전 GREEN(fail-open 실증) / 수정본 RED** 차분으로 각각 실증했다:
  `tests/test_no_wall_clock.sh`(`wall_clock_started_at`) ·
  `tests/test_web_kill_switch.sh`(`SWEEP_CAP`) ·
  `tests/test_conducting_interview_stage.sh`(`breadth-keeper`) ·
  `tests/test_brief_review_meta.sh`(E10 스캔 루트) ·
  `tests/test_reviewing_spec_design_only.sh`(F9-D 스캔 루트, `drafting-spec`).
  합집합 vacuity 만으로는 부족하다 — 플러그인 레벨 글롭이 깨져도 `skills/` 쪽 도출로
  통과하기 때문에, **디렉터리가 있는데 도출이 0이면** 따로 loud FAIL 한다(기대값
  하드코딩 없이 디렉터리 실재라는 독립 신호에서 도출).

**Docs**
- `README.md` AP2 항목이 두 가드를 **세 번째로 저술**하고 있었다 — 정본 포인터를 달고
  "아래는 요약이지 별개 저술이 아니다"를 명시. v0.13.0 항목에도 통합 사실을 덧붙였다.

## [0.30.1] — 2026-08-21

Task 32 fix round 1 — 전부 **문서**다. 코드·락 동작은 무변경(리뷰가 Spec PASS /
Quality PASS 로 엔지니어링을 독립 재도출로 확인).

**Fixed**
- **[0.30.0] 엔트리의 overclaim 정정 (F2).** 두 스위트의 섹션 윈도우가 똑같이 위치
  무관해졌다고 적었으나 사실이 아니다. `test_brief_review_entry.sh` 만 그렇고
  (`scoped_window()` 가 `"${CI_FILES[@]}"` 위에서 돈다),
  `test_conducting_interview_stage.sh` 의 다섯 창은 `$FIN` 하드코딩이다. 결과는
  조용한 구멍이 아니라 시끄러운 false-RED 지만, 산문이 코드보다 강한 주장을 하고
  있었다. 해당 엔트리를 파일·처방별로 갈라 다시 적었다.
- **[0.30.0] **Fixed** 헤딩의 undercount 정정 (F3).** "부재 락 3건"으로 읽히지만
  실제는 **4파일 / 10단언**이다(네 번째가 `test_conducting_interview_stage.sh` 의 7건,
  같은 파일의 windowed 수리와 묶여 **Changed** 에 있었다).
- **독자 열거 수 정정 (F1).** 보고서가 12로 적은 것은 **15 + 비독자 1**이 옳다.
  누락된 넷은 전부 부재 클래스이지만 코퍼스를 `grep -r`·`find` 로 **도출**하므로
  새 참조 파일을 자동으로 삼킨다 — 오늘 동작상 결과는 없다:
  `quality-gates/tests/test_governance_no_capability_caps.sh` ·
  `tests/test_reviewing_spec_design_only.sh` · `tests/test_brief_review_meta.sh` ·
  `quality-gates/tests/test_codex_runner_no_effort_pin.sh`.
  반대로 `shared/tests/test_changelog_integrity.sh` 는 **독자가 아니다**(`SKILL.md` 를
  한 번도 읽지 않는다 — `plugin.json` + `CHANGELOG.md` 만 본다). 버전영향이지
  코퍼스영향이 아니다.
  그중 `test_governance_no_capability_caps.sh` 는 구조적으로 중요하다 — [0.30.0] 이
  "아무도 고려하지 않은 클래스"로 지목한 **플러그인 경계를 넘는 repo-wide 부재 스캔**의
  **두 번째** 인스턴스다. 그 면역은 분석의 결과가 아니라 **구성의 운**이었다.

**Added**
- `docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md` (+ `docs/audits/README.md`
  인덱스 줄) — 이 실패 클래스의 **영구 기록**. 앞선 보고서는 `.superpowers/` 아래
  git-ignored 라 커밋되지 않아 미래 세션이 **읽을 수 없다**; 아무도 열지 못하는 파일의
  숫자를 고치는 것은 아무것도 고치지 않는다. 문서가 담는 것: 실패 클래스 · 독자 열거
  6 도달 경로(`.py`·플러그인 경계 포함) · 면역 조건(도출 vs 열거) · 포인터가 presence
  락을 header-satisfiable 하게 만드는 **거울 클래스** · 차분 실증의 계측기 위생 2함정 ·
  이월 미해결 3건.
  `docs/` 와 `docs/audits/` 는 **어느 플러그인에도 속하지 않는다** — 이 bump 를
  촉발한 것은 그 문서가 아니라 위 **Fixed** 의 `plugins/spec-distill/CHANGELOG.md`
  산문 수정이다. 감사 문서 자체는 무-플러그인 자산으로 이 엔트리에 귀속만 시킨다.

**Notes**
- [0.30.0] 의 "순수 예방적"이라는 자기평가는 **과소 주장**이었다. `test_law2_prose.sh`
  수리가 새로 덮는 코퍼스는 이번 분할분 232줄이 아니라 Task 31 산출물
  (`runtime-gate.md` 1,189 + `state-file-format.md` 78)을 더한 **1,499줄**이고, 그
  전량이 clean 하다(28/28). 참인 주장은 더 강하다 — **새로 덮인 코퍼스 전체에서**
  어떤 수리된 락도 잡을 것이 없었다.
- 측정 정정 2건(둘 다 결론 불변): `GUARD_WINDOW` 가드 줄 목록에서 **330** 이 빠져
  있었다(여전히 < 341, 짝짓기는 `g ≤ d` 만 보므로 무영향). 줄번호 검사 지점은 "정확히
  두 곳"이 아니라 **셋**이다 — `test_brief_review_entry.sh:172` 의
  `n5="$(wc -l <<<"$WA5")"; [[ "$n5" -le 30 ]]` 가 창 크기를 재는 줄-거리 검사다.
  Step A.5 는 분할 전 395–424 로 이동 구간에 통째로 들어 있어 창이 온전히 따라갔고
  현재 28 ≤ 30 으로 GREEN. Ruling 67 의 "재조립 불필요" 결론은 그대로다.

## [0.30.0] — 2026-08-21

Task 32(무게 감축): `conducting-interview` SKILL.md의 `## 종료 — brief 작성 + optional
handoff` 절차 전문(232줄, 분할 전 파일(614줄)의 37.8%)을
`skills/conducting-interview/references/finishing.md`로 분리했다. SKILL.md에는 같은
`## 종료` 헤딩 아래 포인터 산문만 남는다 — floor 5차원이 전부 `closed`가 되어 brief
작성으로 넘어갈 때만 그 파일을 Read 하고, 인터뷰가 진행 중인 동안은 읽지 않는다(조건부
로드). 이 파일에는 목차도 내부 `](#anchor)` 링크도 없어 깨질 앵커가 없다.
on-demand 로드 표면(SKILL·agent·command 전량)은 이 분리로 5,406줄 → 5,188줄
(Δ −218)로 줄었다.

**Added**
- `skills/conducting-interview/references/finishing.md` — 종료 절차 전문(Step A ·
  Step A.5 · Step B B-0…B-4). 분할 전 SKILL.md에서 **바이트 그대로** 이동했고 내용
  변경은 없다(재조립 후 원본과 diff 0줄 — 의도적으로 SKILL.md에 남긴 구분용 빈 줄
  하나 제외).

**Fixed**
- **분할로 조용히 약해진 부재 락 — 4파일 / 10단언.** (아래 3건 + **Changed** 의
  `test_conducting_interview_stage.sh` 7단언. 그 7건은 같은 실패 클래스이지만 같은
  파일의 windowed 수리와 한 덩어리라 Changed 에 적었다.) 부재 락("이 문자열이 나타나면 안 된다")은
  코퍼스가 줄어도 RED가 되지 않고 **조용히 약해진다** — Task 31이 이 방식으로 P21
  secret 스캔의 범위를 잃었다. 세 락 모두 분리 직후 GREEN이었고, 금지 문자열을
  `finishing.md`에 주입해 **수정본 RED / 수정 전 GREEN**의 차분으로 fail-open을
  실증한 뒤 고쳤다. 세 곳 다 열거가 아니라 **도출**(`references/*.md` 글롭)로
  고쳐 새 참조 파일이 생기면 자동으로 대상이 되게 했고, 도출 0건이면 loud FAIL
  하는 vacuity 단언을 함께 넣었다.
  - `tests/test_no_wall_clock.sh` — 순수 전-파일 부재 락. 하드코딩된 3-파일 배열이라
    분리분을 못 봤다. 하필 종료 절차가 "얼마나 걸렸나"를 다시 재고 싶어지는 가장
    그럴듯한 자리다. 실측: 주입 후 수정 전 9/9 GREEN → 수정본 2건 RED.
  - `tests/test_web_kill_switch.sh` — 두 부재 검사(느슨한 참 판정 · 상한 게이트
    재도입)가 `dispatch_lines` 없으면 `continue`로 빠지는 자리에 있어, dispatch가
    없는 분리분은 영영 검사되지 않았다. 부재 검사를 `continue` **위로** 끌어올려
    표면 전량에서 돌게 했다. 실측: 주입 후 수정 전 32/32 GREEN → 수정본 2건 RED.
  - `plugins/quality-gates/tests/test_law2_prose.sh` — `find plugins/*/skills -name
    'SKILL.md'` 코퍼스라 **모든** 플러그인의 `references/*.md`를 못 봤다. Task 31이
    만든 `runtime-gate.md`(1,189줄) **와** `state-file-format.md`(78줄) 둘 다 이미 이 락
    밖에 있었으므로 그 잔여 구멍도 함께 닫힌다 — 수리 후 AC16-1 에 새 파일 줄이 3건
    (두 quality-gates 참조 + `finishing.md`) 늘어난 것으로 확인된다.
    실측: 주입 후 수정 전 24/24 GREEN → 수정본 4건 RED.

**Changed**
- 두 스위트의 **전-파일 검사**(존재·부재 양쪽)는 스킬 표면(SKILL.md + `references/*.md`)을
  하나로 보도록 코퍼스를 도출로 바꿨다. `test_conducting_interview_stage.sh`의 부재 7건은
  주입 차분으로 이빨을 확인했다(수정 전 7/7 GREEN → 수정본 7/7 RED).
- **섹션 윈도우의 처방은 두 파일이 다르다** — 앞선 판본의 이 항목은 둘 다 위치
  무관해졌다고 적었으나 사실이 아니다:
  - `tests/test_brief_review_entry.sh` — `scoped_window()`가 `"${CI_FILES[@]}"` 위에서
    돌아 **위치 무관**이다. `### Step A.5`·`#### B-2`가 어느 파일에 있든 창이 잡힌다.
  - `tests/test_conducting_interview_stage.sh` — 다섯 창(`#### B-0`…`#### B-3` · `## 종료`,
    `:57 :72 :92 :113 :208`)은 **`$FIN` 하드코딩**이다. 나중에 `#### B-2`가 제3의 파일로
    옮겨가면 `b2_block`이 비어 그 assert들이 RED가 된다. 다만 `[[ -f "$FIN" ]]`(`:24`)와
    `[[ -n "$b2_block" ]]` 빈-창 가드가 있어 **조용한 구멍이 아니라 시끄러운 false-RED**이고,
    수리는 창 소스 한 줄 교체다. 위치 무관화는 이 사이클 범위 밖으로 남긴다.

**Notes**
- **재조립 헬퍼(`reconstruct-skill.sh`)를 쓰지 않았다 — 측정 결과 필요 없었다.**
  Task 31이 그 헬퍼를 만든 이유는 두 테스트가 섹션 경계를 가로질러 **줄 번호로**
  순서·거리를 쟀기 때문이다. 이 스킬의 소비자 전량을 훑어 그런 검사를 찾았고,
  줄 번호 산술은 두 곳뿐이었다: `test_web_kill_switch.sh`의 dispatch↔kill switch
  근접 검사(`GUARD_WINDOW=40`)는 dispatch 254·269·320행을 가드 245·302·311행과
  짝지어 **전부 경계(341행) 아래**에 있고, `test_check_verbatim_coverage.sh`의
  `sed -n "${P21_LINES},+3p"`는 첫 `REDACTED`(63행) 기준이라 63–66행에 머문다.
  경계를 가로지르는 쌍이 0건이므로 재조립은 불필요하고, 근-중복 66줄 파일을
  새로 만들지 않았다.

## [0.29.0] — 2026-08-20 (BREAKING)

Task 25(무게 감축): 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일. 이
플러그인이 소유한 kill switch·설정 변수:

| 옛 이름 | 새 이름 |
|---|---|
| `DEVBREW_DISABLE_SPEC_DISTILL` | `DEVBREW_SPEC_DISTILL_DISABLE` |
| `DEVBREW_DISABLE_SPEC_DISTILL_CODEX` | `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` |
| `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW` | `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` |
| `DEVBREW_RHYTHM_GUARD_THRESHOLD` (플러그인 토큰 없던 패턴 D) | `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` |

이미 `DEVBREW_SPEC_DISTILL_*` 어순을 쓰던 변수(`DISABLE_WEB`·`DESIGN_MODE_DISABLE`·
`TTL_HOURS`·`PROBE_CAP` 등)는 무변경. `shared/killswitch/kill_switch_active.py`
정본(과 이 플러그인의 `scripts/kill_switch_active.py` 물리 사본)의 전역 스위치
**도출식** 자체도 `DEVBREW_DISABLE_<PLUGIN>` → `DEVBREW_<PLUGIN>_DISABLE`로 바뀌었다
— 리터럴 문자열 치환으로는 안 잡히는 자리였다(태스크 실행 중 burn-test로 실측:
`test_kill_switches_v060.sh` case 1–4가 이 도출식 미수정 상태에서 RED였다).

### Deprecated
- 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일. 옛 이름(`DEVBREW_DISABLE_SPEC_DISTILL_CODEX` 등)은
  **fallback 없이 즉시 제거**됐다. 근거: 현재 제3자 설치가 없다 (CLAUDE.md §메타데이터의
  one-minor deprecation window 와의 충돌을 그 조건 아래 수용). **제3자 설치가 생기면 이 근거가
  바뀐다** — 그때는 다음 rename 에 fallback 창을 둔다.

### Changed (devbrew weight-reduction Task 29)
- **`reviewing-brief` SKILL의 헤딩을 `## kill switch (먼저 확인)`에서
  `## kill switch`로 줄였다.** "먼저 확인"은 순서 계약(이 skill의 어떤
  dispatch보다도 먼저 평가한다)이었으므로 삭제하지 않고 본문 첫 줄 문장으로
  내렸다 — 헤딩만 보고 넘어가면 그 계약이 사라지므로.

### Fixed (devbrew weight-reduction Task 30)
- **`hooks/spec-write-validator.py:137`에 `encoding="utf-8"` 명시.** 나머지
  `write_text` 호출(255·276번 줄)은 조사 결과 이미 `encoding="utf-8"`을 다음
  줄에 갖고 있었다 — 같은 줄만 보는 grep이 오탐한 자리였다(quality-gates
  Task 30 CHANGELOG의 axis 2 참조).

## [0.28.0] — 2026-08-17

Task 17(무게 감축) + fix round 1: `scripts/codex_findings_to_yaml.py`가 물리 사본에서 `shared/codex/
codex_findings_to_yaml.py`를 가리키는 상대 심볼릭 링크로 바뀌었다(quality-gates와
공유하는 정본). emit keyset(`category`·`target_section` — design-doc 리뷰 어휘)은
더 이상 사본 하드코딩이 아니라 정본의 새 `--emit-keys design` 인자다. patch가 아니라
**minor**인 이유(S3): 이전에는 이 플러그인의 codex 소비 경로가 design keyset을
암묵적으로 항상 받았지만, 이제는 호출자(`run_brief_codex_reviewer.sh`·
`run_spec_codex_reviewer.sh`)가 명시적으로 요청해야 한다 — 잊으면 `category`/
`target_section`이 조용히 빠진다(같은 파일 경로로 새 configurability 노출, detect_codex.sh
선례와 같은 판단 기준).

Task 19(무게 감축): kill switch 판정 12정의를 `shared/killswitch/kill_switch_active.py`
정본으로 통합. 이 플러그인이 그중 5곳(훅 4 + `scripts/spec-distill-gc.py`)을 갖고 있었다.

Task 22(무게 감축): **같은 플러그인 안의** 중복을 `scripts/hook_common.py` 하나로 접었다.
`shared/` 정본과 달리 플러그인-로컬이라 `copy-of` 마커도 사본 동일성 검사도 붙지 않는다 —
같은 플러그인 안에서는 import 하나로 중복 자체가 소멸한다(설계 §6.1③). 두 훅
(`review-dispatch.py` ↔ `pending-review-reminder.py`)의 최장 공유 구간이 **24줄 → 11줄**
로 내려갔다(20줄 창 5개 → 0개). `_yaml_scalar` 는 **행동이 바뀐다** — 아래 Fixed 참조.

### Added
- `scripts/hook_common.py` — 두 훅이 공유하던 조각의 단일 정의:
  `configure_utf8_streams()` · `PENDING_RE` · `LAST_DISPATCHED_RE` · `GC_SCRIPT` ·
  `fire_and_forget_gc()` · `parse_iso()` · `state_file_for()` · `_yaml_scalar()`.
  `kill_switch_active`(Task 19의 `shared/` 정본)와 `resolve_session_id`/`state_root`
  (`state_path.py` 소유)는 담지 않는다 — 가져오면 정본이 둘이 된다.
- `tests/test_yaml_scalar_single_definition.py` — 정의가 하나이고(구조 스캔), 소비자
  셋이 **같은 함수 객체**를 부르며(텍스트가 아니라 identity 로 잰다), 그 하나가
  합집합 행동을 갖는지. 각 단언은 세 사본 중 적어도 하나가 갖지 못했던 성질이라,
  어느 옛 본문으로 되돌려도 하나는 RED 가 된다. `float` 분기는 단언하지 않는다 —
  없어도 `str(v)` 경로가 같은 값을 내 어떤 입력으로도 구분되지 않는다(이빨 없는 단언).
- `tests/test_yaml_scalar_single_definition.py` `TestCanonicalAgreesWithSharedCodex`
  — 이 플러그인의 `_yaml_scalar` 와 `shared/codex/` 정본이 **같은 입력을 인용하는지**.
  케이스 목록(내가 떠올린 값)과 상수 자체 비교(내가 안 떠올린 문자) 두 겹으로 잰다.
  인용 표기(`ensure_ascii`)는 다를 수 있으므로 `json.loads` 로 되돌린 뒤 비교한다.
  위치 축의 **음의 짝**(`codex-reviewer`·`fail-safe` 처럼 첫 글자가 아닌 지시자는
  bare 로 남는다)도 같이 잰다 — 없으면 "전부 인용" 으로 도망갈 수 있다.
- `tests/test_codex_findings_to_yaml.py` `TestSummaryScalarRoundTrip` — 정본
  스크립트를 실제로 태워 산출 YAML 을 **파싱해서 원문과 정확히 같은지** 잰다.
  텍스트 겹(인용됐는가)과 왕복 겹(되돌아오는가)을 갈라 둬서, PyYAML 이 없는 환경에서도
  텍스트 겹은 이빨을 유지한다.

### Changed
- `review-dispatch.py`·`pending-review-reminder.py` 가 UTF-8 프리앰블·`PENDING_RE`·
  `LAST_DISPATCHED_RE`·`GC_SCRIPT`·GC fire-and-forget 블록·`parse_iso` 자체 정의를
  버리고 `hook_common` 에서 import 한다. `pending-review-reminder.py` 는 인라인으로
  조립하던 상태 파일 경로도 `state_file_for()` 로 바꿨다(같은 표현식의 세 번째 사본).
- `scripts/arm_ledger.py` 의 `state_file_for` 정의를 지우고 `hook_common` 에서 import.
  `arm_ledger.state_file_for` 로 부르는 소비자(`spec-write-validator.py`)는 그대로다.
  그 docstring("저장소 위치 변경 시 이 한 곳만 갱신")이 두 번째 정의 때문에 거짓이었는데
  이제 다시 참이다(census #122).
- `merge_review.py`·`merge_brief_review.py`·`brief_review_state.py` 가 각자의
  `_yaml_scalar` 정의를 버리고 `hook_common` 에서 import(census #45의 spec-distill 부분).
- `tests/test_arm_ledger.py` 의 착지점 계산이 `arm_ledger.state_root()`(소유하지 않는
  이름의 re-export)가 아니라 `state_path.state_root()` 를 직접 쓴다. 피검자의 경로 조립
  함수를 쓰지 않는 것은 의도적이다 — 그 함수의 버그가 traversal 테스트를 눈멀게 한다.

### Fixed
- **`_yaml_scalar` 세 사본이 갈라져 있었다** — 빈 문자열 가드가 `merge_review` 에만
  없었고, flow indicator(`[]{}`) escape 가 `brief_review_state` 에만 있었고, None 분기가
  `brief_review_state` 에만 없었다. 합집합으로 접었다(더 인용하는 것은 파싱 결과를 바꾸지
  않고, 덜 인용하는 것만 바꾼다). 그래서 **출력이 바뀌는 자리가 있다**: `[` 로 시작하고
  `:` 를 갖지 않는 advisory 문구가 이제 따옴표로 감싸여 나간다. 이관 전에는 인용 없이 나가
  YAML flow sequence 로 읽혔다 — 두 merge 스크립트의 advisory 리터럴 **5건**이 이 모양이었다
  (예: "[spec-distill v0.20.0] review indeterminate …", "[spec-distill v0.24.0] critic
  sentinel 블록 …"). 빈 문자열과 None 쪽은 현재 소비자 경로로는 도달하지 않는다.
- **정본(`shared/codex/codex_findings_to_yaml.py`)의 `_yaml_scalar` 도 같은 술어로
  맞췄다** (2026-08-19). 사본 셋을 합집합으로 접는 동안 그 사본들이 모여야 할 정본은
  옛 술어를 그대로 갖고 있었다 — 통합이 뒤집혀 있던 셈이다. 실측(정본 종단):
  `summary` 가 `[` 로 시작하면(`"[CRITICAL] …"` — 리뷰어가 흔히 쓰는 모양) 인용 없이
  나가 **문서 전체가 ParserError** 로 죽었고, 소비자
  (`merge_review.parse_codex_yaml`)는 그 파일을 읽지 못해 그 라운드의 findings 가
  통째로 소실됐다. 빈 문자열은 `null` 로, `{` 로 시작하는 값은 매핑으로 읽혔다.
- **위치 축(`_YAML_UNSAFE_FIRST`)을 새로 넣었다 — 합집합에도 없던 잔여 구멍이다.**
  세 사본의 합집합은 **문자 멤버십** 하나뿐이라, block sequence 지시자로 시작하는 값
  (`- dash`)이나 backtick 으로 시작하는 값(``"`handler()` 가 null 을 반환한다"``)은
  여전히 인용 없이 나가 ScannerError 를 냈다. 첫 글자를 0x20–0x7E 전수로 돌려
  `k: <값>` 을 파싱하는 방식으로 위험 집합을 **측정해서** 얻었고, 그중 기존 검사가
  덮지 못하는 잔여를 상수로 뒀다. 정본과 이 파일이 같은 두 상수를 쓴다.
- **표기(`ensure_ascii`)까지 같아졌다** — 정본만 기본값(True)이라 인용된 한국어가
  `\uXXXX` 로 나갔고, 인용 술어를 넓히면서 그 노출이 늘어 정본을 `False` 로 맞췄다.
  이제 두 `_yaml_scalar` 의 출력은 **바이트로 동일**하고,
  `TestCanonicalAgreesWithSharedCodex` 가 여부·표기 둘 다 락으로 고정한다.

### Added
- `scripts/kill_switch_active.py` — `shared/killswitch/kill_switch_active.py` 의
  `# copy-of:` 물리 사본. 설치본에는 `shared/` 가 없으므로 형제 사본이어야 import 가 풀린다.
- **`DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc`** — `scripts/spec-distill-gc.py` 만
  끈다. 이관 전 이 파일은 `DEVBREW_SKIP_HOOKS` 를 **아예 읽지 않았다** — 사용자가 그 변수로
  껐다고 믿어도 GC 는 계속 돌았다(이관 전 HEAD 판본을 실제로 태워 확인). 훅이 아니지만
  지목할 이름을 갖는 쪽이 더 잘 꺼지는 방향이라 회귀가 아니다.
- `hooks/session-end-cleanup.py` 가 훅명 별칭 `spec-distill:session-end-cleanup` 도 받는다
  (이관 전에는 이벤트명 `spec-distill:SessionEnd` 하나뿐이었다).

### Changed
- 훅 4종(`review-dispatch.py`·`pending-review-reminder.py`·`spec-write-validator.py`·
  `session-end-cleanup.py`)과 `scripts/spec-distill-gc.py` 에서 자체 판정 정의
  (`kill_switch_active()` 3 + `_disabled()` 2)를 지우고 정본 호출로 교체. 기존 토큰
  (`:Stop`/`:review-dispatch` · `:UserPromptSubmit`/`:reminder` · `:PostToolUse`/`:validator` ·
  `:SessionEnd`)과 전역 `DEVBREW_DISABLE_SPEC_DISTILL=1` 의 동작은 전부 불변이다.
- `run_brief_codex_reviewer.sh`·`run_spec_codex_reviewer.sh` 두 호출 모두
  `--emit-keys design`을 명시(행동 불변 — 이전 하드코딩과 동치).
- `extract_last_agent_message`(codex JSONL 이벤트 파서)를 `shared/codex/
  codex_jsonl.py` 정본으로 흡수. `codex_findings_to_yaml.py`가 여기서 import한다
  (quality-gates·plugin-audit 세 사본이 있던 것 중 이 플러그인 몫).
- `tests/test_codex_findings_to_yaml.py`의 design-keyset 단언 2건이 이제
  `--emit-keys design`을 명시적으로 넘긴다(스크립트 기본값이 바뀌었으므로).

### Fixed (2026-08-17 fix round 1)
- **codex 리뷰어가 설치본에서 100% 죽는 결함(CRIT-1).** 정본의 `codex_jsonl` import가
  `.resolve()`를 써서, `claude plugin install`이 서브트리를 벗어나는 심볼릭 링크를
  실제 파일로 역참조하는 설치본(설계 §16.1)에서 sibling `codex_jsonl.py`를 못 찾고
  `ImportError`가 났다. `.resolve()`를 버리고(bare `.parent`) `codex_jsonl.py`의
  copy-of 물리 사본을 `plugins/spec-distill/scripts/`에도 배포했다(quality-gates·
  plugin-audit과 동일 패턴).
- `run_brief_codex_reviewer.sh`가 `--emit-keys design`을 잃어도 어떤 테스트도
  빨개지지 않던 결함(F1) — `tests/test_brief_codex_axes.sh`에 `run_spec_codex_reviewer.sh`
  쪽과 대칭인 assertion + mutation 증명을 추가했다.
- 공백 가드의 방향 정정(F2) — "공백-only를 거른다"가 아니라 "뒤따르는 빈 후보가
  앞선 유효한 메시지를 덮어쓰지 못하게 한다"이며, 이 플러그인이 이전에 배포하던
  것 대비 fail-open 방향의 판정 변경이다(뒤이어 빈 `agent_message`가 흐르면
  `codex_failed`가 `true → false`로 뒤집히고 finding이 살아난다). 새 테스트
  `test_codex_findings_to_yaml.py::test_trailing_blank_agent_message_does_not_clobber_real_one`가
  고정한다.
- "행동 불변" 프레이밍 정정(F8) — 정본화 이전에는 `agent_message.text`가
  문자열이 아니면 크래시(rc=1)했다. 지금은 `codex_jsonl.py`의 타입 가드가 크래시
  없이 rc=0 + `reason: missing_result`로 degrade한다 — 개선이지만 사유 문자열이
  바뀐다.

### Fixed (2026-08-17 fix round 2)
- **F1 mutation 이 플래그 줄에 도달조차 못 하던 결함(R2-5·R2-6).**
  `tests/test_brief_codex_axes.sh` 의 mutation 은 러너 사본을 temp dir 에서 돌리는데
  `CLAUDE_PLUGIN_ROOT` 를 넘기지 않아 `PLUGIN_ROOT` 유도가 어긋났고, 프롬프트 빌더를
  못 찾아 `reason: prompt_build_failed` 로 조기 종료했다 — 그런데도 락은 "이빨 있음"
  을 출력했다(**플래그와 무관한 실패를 플래그 증거로 보고**). 형제 락
  `test_run_spec_codex_reviewer.sh` 처럼 `CLAUDE_PLUGIN_ROOT` 를 명시로 넘기고,
  ① **identity 사본**(플래그 그대로 위치만 이동) 통제와 ② 변이본이 조기 degrade
  없이 변환까지 갔는지 확인하는 원인-확정 단언을 더했다. 양방향 증명: identity
  사본(플래그 온전)에서는 **계측기 줄이 GREEN** 이고 락이 "이빨 있음"을 거짓으로
  내지 않는다 — 그 거짓을 막는 것은 **mutation 줄이 RED 로 가는 것**이다(실측:
  40 중 1 RED, 계측기 줄과 원인-확정 줄은 둘 다 GREEN). 실제 플래그 제거에서는
  "이빨 있음"을 낸다. 계측기 줄이 RED 로 가는 경우는 계측기 자체(`F1ENV` 의
  `CLAUDE_PLUGIN_ROOT`)가 깨졌을 때다(실측: 40 중 2 RED). 〔2026-08-17 fix round 3,
  R3-5 — 앞 판본은 identity 일 때 "계측기 RED" 라 적어 `task-17-report-r2.md:158`
  과 모순이었다.〕
- `codex_jsonl.py` 사본의 docstring 정정(정본과 동기) — 없는 테스트 파일 인용 제거,
  배포 지점 도출 규칙 명시(R2-4·R2-11).

### Fixed (2026-08-17 fix round 3)
- **원인-확정 판별자 자신이 두 방향으로 fail-open 이던 결함(R3-1).**
  round 2 가 더한 `tests/test_brief_codex_axes.sh` 의 원인-확정 검사는 ① 맨 `grep` 이라
  **출력 파일 부재를 PASS 분기로 라우팅**했고(변이본이 구문 파손돼 아무것도 안 남겨도
  40/40 GREEN + "이빨 있음"), ② degrade 사유를 **하드코딩**해 러너가 내지 않는
  `extract_failed` 를 열거하면서 러너가 실제로 내는 여섯(`runner_incomplete` ·
  `payload_missing` · `missing_project_dir` · `project_dir_unreachable` ·
  `scratch_dir_uncreatable` · `codex_not_installed`)을 빠뜨렸다 — 그래서
  `reason: codex_not_installed` 로 degrade 한 변이본도 "원인 확정" 을 통과했다.
  즉 R2-6 이 닫혔다고 주장한 실패가 그대로 재현됐다. 두 판정 모두
  `shared/tests/assert.sh` 의 `assert_file_absent`(파일 부재 = `no()`)로 바꾸고,
  사유 열거는 러너의 `emit_fallback`/`write_failclosed` 호출부에서 **도출**한다
  (현재 9종). 도출이 0건이면 vacuous 로 보고 RED. 실측: 구문 파손 변이 → 2 RED,
  `codex_not_installed` degrade 변이 → 1 RED, 무변이 40/40 GREEN.

### Added (Task 20 — codex 러너 공통 조각)

- `scripts/runner_common.sh` — `shared/codex/runner_common.sh` 의 `copy-of` 물리 사본
  (`_degrade_if_empty` · `write_failclosed` 정본).

### Changed (Task 20)

- `run_spec_codex_reviewer.sh` · `run_brief_codex_reviewer.sh` 가 두 함수를 자체 정의하지
  않고 위 정본을 source 한다(census #24·#125 — 두 파일에 그대로 복제돼 있었다).
- **`write_failclosed` 의 시그니처가 `<output_path> <reason>` 두 인자로 바뀌었다.** 이전에는
  reason 한 인자만 받고 경로는 전역 `$OUTPUT_PATH` 에서 읽었다 — 공유 파일이 호출자의 전역을
  읽으면 그 전역 이름이 조용한 계약이 된다. 호출부 셋(`emit_fallback` ×2 · `seed_failclosed`)이
  모두 `"$OUTPUT_PATH"` 를 먼저 넘기도록 바뀌었고, 정본에 빈-인자 가드가 있어 옛 형태로
  부르면 rc=1 로 거절된다(빠뜨린 호출이 `runner_incomplete` 라는 **파일 이름**으로 쓰기를
  시도하던 실패원을 조용히 통과시키지 않는다).
- `emit_fallback` 은 정본화하지 **않는다** — `exit 0` 으로 호출자 프로세스를 끝내는 제어흐름
  래퍼라, 아끼는 3줄보다 공유 계약이 무겁다(census #126).

### Fixed (Task 20)

- **정본 로드 실패 시 stale/0바이트 산출물이 남던 새 경로** 봉쇄 — quality-gates 3.4.0 의
  같은 항목과 동형(`[ -r ]` + `bash -n` 선검사 → `reason: runner_common_unloadable`).
  `run_brief_codex_reviewer.sh` 쪽은 특히 `seed_failclosed` 에 **닿기 전에** 죽는 형태라
  직전 라운드 YAML 이 그대로 이번 판정으로 읽혔다.
- `tests/test_brief_codex_axes.sh` 의 mutation fixture가 러너를 다른 디렉토리로 옮기면서
  형제 정본을 두고 가, 사본이 로드 가드에 걸려 **조기 degrade** 했다 — 그 상태에서 mutation 은
  변이가 아니라 위치 때문에 실패한다(도달 불가). 이 테스트의 계측기 assertion 둘이 그것을
  RED 로 잡아냈고, fixture 가 정본을 함께 옮기도록 고쳤다.

### Added (Task 21 — GC 공통 조각)

- `scripts/gc_common.py` — `shared/gc/gc_common.py` 의 물리 사본(머리 한 줄 마커).
  quality-gates 와 공유하는 정본이다.

### Changed (Task 21)

- `scripts/spec-distill-gc.py` 가 `_ttl_ns`·`_folder_mtime_ns`·`_within_grace`·`_gc_one` 과
  상수 셋(`GRACE_NS`·`DOUBLE_STAT_DELAY_S`·`GC_PENDING_PREFIX`)을 지우고 `gc_common` 을
  부른다. `GC_PENDING_PREFIX` 를 정본에서 가져오는 것이 특히 중요하다 — 그 접두를 **쓰는**
  쪽(`gc_one`)과 **줍는** 쪽(`_sweep_gc_pending`)이 갈라지면 고아가 영원히 안 지워진다.
  남은 고유 본문은 git-aware state root 와 `.gc-pending-*` 고아 스윕이다.
- `hooks/session-end-cleanup.py` 와 위 고아 스윕의 삭제가 `gc_common.safe_rmtree` 를 거쳐
  root 밖 경로를 거부한다. 이 플러그인은 `SESSION_PATTERN` charset 검증을 이미 갖고 있어
  동작 변화가 없다 — 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제가 되지 않도록 하는
  두 번째 겹이다.
- **state root 해석은 공통 조각에 넣지 않았다.** 이 플러그인은 git-aware
  (`git rev-parse --git-common-dir`, worktree 호환)이고 quality-gates 는 payload cwd
  상대다 — 부분 사본의 "각자 고유 본문"이라 플러그인 경계를 넘는 통합은 하지 않는다.

### Changed (Task 23 — `state_path.py` 를 `hooks/` 에서 `scripts/` 로)

- `hooks/state_path.py` → `scripts/state_path.py` (본문 무변경, git 인식 rename).
  `hooks/` 에는 `hooks.json` 이 등록한 훅 4개와 `hooks.json` 만 남는다 — 이 리포의
  어느 플러그인 `hooks/` 에도 비-등록 `.py` 가 없다(이동 전 1건).
- SKILL 실행 라인 9곳이 `${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py` 를 부른다
  (`conducting-interview` 5 · `reviewing-brief` 2 · `reviewing-spec` 2).
  이 세 SKILL 에는 `allowed-tools` frontmatter 가 없어 함께 고칠 권한 선언이 없다.
- `scripts/{arm_ledger,spec-distill-gc,hook_common}.py` 가 `state_path` 를 찾으려고
  형제 디렉토리 `hooks/` 를 `sys.path` 에 얹던 것을 **자기 디렉토리**로 바꿨다.
  훅 4개는 이미 `scripts/` 를 `sys.path[0]` 에 얹고 있어 import 경로 변경이 없다.

### Fixed (Task 23)

- **설치본에서 `scripts/spec-distill-gc.py` 가 홀로 배포되면 죽던 잠복 결함**(Task 19
  발견 · Task 21 확대 확인). 이 파일은 `state_path` 를 `hooks/` 에서 풀었는데,
  `shared/` 정본 형제 락(`test_copy_of_contract.sh` 축 1c)의 설치본 대역은 소비자마다
  디렉토리를 도출해 편다 — 이 소비자만 격리하면 `hooks/` 가 트리에 없어
  `ModuleNotFoundError: No module named 'state_path'` 였다. 지금까지 GREEN 이었던 것은
  락이 SIM 트리를 코호트로 공유하고 `git ls-files` 가 `hooks/*` 를 `scripts/*` 앞에
  정렬해, 앞선 훅 소비자가 이미 `hooks/` 를 펴 두었기 때문이다 — 통과가 **코호트와
  순서에 의존**했다. 이동 후 소비자 19건 전부가 격리에서 GREEN 이다(측정: 이동 전
  트리에서 같은 계측기가 이 파일 하나만, 두 코호트 모두에서 RED).
- `plugins/plugin-audit/scripts/check-shape-completeness.py` 의 over-glob 방어 주석이
  들던 실측 사례가 이 이동으로 사라졌다 — 주석을 과거 사례로 표시하고, 사례가 없다고
  가드를 지우면 안 된다는 이유를 남겼다(정의부만 옮기고 인용부를 남기면 없는 것을
  근거로 내세우는 서술이 된다).

## [0.27.0] — 2026-08-17

Task 15(무게 감축) + fix round 1. patch가 아니라 **minor**인 이유(S3): 새
`skip_reason` 3종 + 새 필수 형제 payload 파일(`codex-killswitch.conf`)이 새 surface다.

`scripts/detect_codex.sh`가 물리 사본에서 `shared/codex/detect_codex.sh`를 가리키는
상대 심볼릭 링크로 바뀌었다(quality-gates·plugin-audit와 공유하는 정본). kill switch
변수명(`DEVBREW_DISABLE_SPEC_DISTILL_CODEX`)은 형제 설정 파일
`scripts/codex-killswitch.conf`로 분리 — 설정 부재 시 fail-closed
(`skip_reason: killswitch_config_missing`).

### Fixed
- **(fix round 1, 보안)** 정본의 kill switch 가드가 값이 비어 있지 않기만 하면
  통과시켜, CRLF·공백만·탭·셸 메타문자 값이 bash 3.2의 `${!VAR:-0}` 간접 확장에서
  에러 없이 `0`으로 평가돼 kill switch가 fail-open하는 결함을 닫았다(정본 공유 —
  `plugins/quality-gates/CHANGELOG.md` [3.3.0] 참조). `CODEX_KILL_SWITCH_VAR` 값이
  POSIX 식별자가 아니면 `skip_reason: killswitch_config_invalid`로 거절한다.
- `reviewing-brief`·`reviewing-spec` 두 SKILL의 codex 게이트가 "감지기 실행 자체
  실패"와 "codex 미설치"를 구별하지 못하던 결함을 `skip_reason: detector_not_runnable`
  로 닫았다. 가드 조건도 `-z codex_avail && -z skip_reason`에서
  `-z codex_avail` 단독으로 좁혔다 — 정본은 성공 실행 시 항상 exit 0이라 이쪽이
  더 정확하다(I6).
- `tests/test_detect_codex.sh`의 kill-switch 변수명 양/음 assertion 2개가 심볼릭
  링크 전환 뒤 정본 본문을 grep해 자기 변수도 못 찾고(양 — RED) 이웃 변수도 못
  찾는(음 — 조용히 vacuous 통과) 상태였다. 형제 `codex-killswitch.conf`로
  재조준했고, 위 fail-open 수정의 회귀 락(malformed conf fail-closed, CRLF·공백만)
  을 추가했다.
- `tests/test_reviewing_brief_skill.sh`의 `skip_reason=` 검사가 real capture line과
  new fallback line 둘 다 만족시켜 header-satisfiable했다(진짜 캡처를 지워도
  GREEN). `skip_reason="\$\(`로 캡처 형태에 앵커했다(mutation으로 확인).

## [0.26.2] — 2026-08-17

devbrew-weight-reduction Task 14 — 자체 판정 헬퍼 이관. `tests/` 46개 파일이 각자
정의하던 `note`/`pass`/`fail`/`ag` 판정 헬퍼(주로 `note PASS/FAIL <msg>` 디스패처
관용구)를 지우고 `shared/tests/assert.sh` 정본을 source. 호출부는 `note PASS`→`ok`,
`note FAIL`→`no`로 개명(`arm_test_helpers.sh`는 두 소비 파일—`test_arm_once.sh`·
`test_arm_ledger_timing.sh`, Task 14 스코프 밖—의 `note PASS/FAIL` 호출 계약을 유지한
채 정본 `ok`/`no`로 위임하는 얇은 wrapper로). `test_detect_codex.sh`의 3-인자 `ag`는
`assert_grep`으로 인자 순서를 재배열(desc가 마지막 인자로).

### Changed
- `tests/*.sh` 46개 — 자체 헬퍼 정의 삭제, 정본 source, 종료를 `finish`로 통일.
  assertion 판정 로직·개수 불변(파일별 감소 0), 전량 GREEN 유지.

## [0.26.1] — 2026-08-17

### Fixed

- **`tests/` 셸 테스트 14개의 실행비트 부재.** qg 셸 테스트 어댑터는 실행비트 있는
  `test_*.sh`만 후보로 고른다 — 비트가 없으면 어댑터가 그 파일을 조용히 건너뛴다.
  동작 계약(테스트 내용)은 무변경, 발견 가능성만 복구.

## [0.26.0] — 2026-08-10

### Fixed

- **`run_spec_codex_reviewer.sh` 의 guard 위치** (`/qg` whole-branch 리뷰 2026-08-13).
  세 조기 분기(`missing_project_dir`·`project_dir_unreachable`·`scratch_dir_uncreatable`)
  가 guarded truncate 보다 **앞**에서 `>` 로 산출물에 직접 썼다. `set -euo pipefail`
  에서 산출물 경로가 쓰기 불가면 그 리다이렉트가 실패해 스크립트가 **exit 1** 로 죽는데
  (EXIT 트랩도 아직 미무장), 계약과 호출 SKILL 은 `rc == 3` 에서만 stale 을 지운다 —
  이전 라운드의 YAML 이 양성 `codex_failed: false` 를 단 채 이번 라운드의 판정으로
  읽혔다(indeterminate ≠ clean 위반). 형제 `run_brief_codex_reviewer.sh` 의 seed 형태
  (절대화 직후 fail-closed 선-기록 + `write_failclosed`/`emit_fallback`)를 그대로
  채용했다. 실측: 쓰기 불가 산출물 → rc=3 + stale 바이트 무변경, 정상 degrade →
  rc=0 + `codex_failed: true`. 전문은
  `docs/audits/2026-08-13-codex-unification-branch-review.md`.

### Added

- `build_spec_codex_prompt.py`·`build_brief_codex_prompt.py` 에 untrusted-data(P21) 절 +
  무조건 blanket 문장 + 무조건 action 금지 문장(codex 프롬프트 빌더 4종 공통, 나머지
  둘은 quality-gates 쪽). brief 경로가 가장 첨예하다 — Claude critic 은 가려진 사본을
  받는데 codex 는 원본 payload 를 받고, `merge_brief_review.py` 가 그 §6 을
  "비신뢰 verbatim" 이라 명시한다.
- `run_spec_codex_reviewer.sh` 에 웹 검색 + `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인.
- `run_brief_codex_reviewer.sh` 에 degrade 계약(시작 시 truncate + 완료 전 중단 시
  degrade YAML) 백포트 — 형제 러너와 동형.
- `rc == 3`(fail-closed 산출물을 못 쓰면 죽는 러너) 소비자 의무를
  `reviewing-spec`·`reviewing-brief` SKILL 에 명문화.

### Fixed

- **`reviewing-spec` 의 codex 게이트가 산문이었다.** `:81` 이 "codex_avail=true일 때만"
  이라고 문장으로 적고 `:82-85` bash fence 는 무조건 실행됐다 — 그 파일에 `codex_avail`
  을 검사하는 `if` 가 없었다. kill switch 는 P21 보안 컨트롤이라 그 상태는 "껐다고
  믿게만" 만든다. `reviewing-brief` 와 동형인 리터럴 게이트로 전환.
- **`codex_findings_to_yaml.py` 헤더의 거짓 주장** — "ONLY adaptation … the emit keyset"
  은 사실이 아니었다(CR-2 검증이 이 사본에만 있었다). 동일성은 이제 주석이 아니라
  `quality-gates/tests/test_codex_copies_agree.sh` 가 보증한다(mock 자산 사본 8그룹도
  같은 락에 편입).

### Changed

- 러너 2종이 프롬프트를 **stdin** 으로 넘긴다 (`codex exec -`).
- `detect_codex.sh` 가 `0.118.0` 버전 바닥과 semver 판독 실패를 낸다.
- `tests/test_detect_codex.sh` 가 14-케이스 합집합.
- `codex_degraded` 의 정의가 **한 곳**(`merge_review.codex_degraded_from`)에만 있다.
  두 병합기가 각자 인라인 계산하고 있었다.
- `tests/test_web_kill_switch.sh` 의 소비자 도출이 **플러그인 횡단**이고 술어가
  **값을 인식**한다 — 웹을 *끄는* 호출부에 죽은 스위치를 요구하지 않는다.

## [0.25.2] — 2026-08-06

### Fixed

- **Stop 훅의 mandate 가 자기 수명을 밝히지 않아, "이번 리뷰만 멈춰달라"는 요청이
  세션 전체 kill switch 로 응답되던 것.** 실사용에서 적발됐다 — 사용자가 훅을 이번
  한 번만 멈추려 했는데 `DEVBREW_DISABLE_SPEC_DISTILL=1` + 재시작이 답으로 나왔다.
  스위치가 없어서가 아니다. 훅 4개 전부 `main()` 첫 문장에서 kill switch 를 존중하고
  스위치는 3단(전역·훅단위·`SKIP_AUTOREVIEW`)으로 이미 있었다. **없던 것은 범위
  정보다** — `reason` 이 "MANDATORY: reviewing-spec 호출"만 말하고 그 강제가 언제까지
  유효한지 적지 않으니, 읽는 쪽이 영구로 가정하고 최대 화력을 골랐다. 게다가 항상
  로드되는 리포 `CLAUDE.md` 의 kill switch 조항은 **보안 요구사항**("모든 훅은 꺼질 수
  있어야 한다")이라 scoping 질문에 재사용되면 all-or-nothing 만 가르친다.
  → `reason` 에 수명 한 문장 추가: *"이 mandate는 이번 dispatch 1회에만 유효하다.
  재발동은 이 문서를 다시 편집할 때 일어난다."* 두 절 **모두 무조건 참**인 것만 남겼다
  (아래 리뷰 라운드 참조).
  **범위는 알리되 면제는 알리지 않는다** — "건너뛰어도 된다"·"무시하면 재발동하지
  않는다" 같은 집행 공백은 적지 않는다. 그것은 모델이 스스로 리뷰를 면제할 근거가 되어
  Law 2 를 뚫는다. 수명 사실은 반대로 "지금 안 하면 사라진다"는 즉시 이행 압력이다.
- **두 수명 문장의 상호배타.** G6 상한에 닿은 dispatch 에서는 "재편집하면 재발동" 이
  **거짓**이다 — 그 문서는 이 세션에서 이미 중단됐다. 상한 문구와 수명 문구를 `if/else`
  로 갈라 어느 분기에서도 훅이 같은 숨결로 모순되는 두 수명을 주장하지 않게 했다.

### Changed

- `README.md` Kill switches 섹션 맨 앞에 **범위 사다리 표**. 기존 목록이 전부 세션
  스코프·재시작 필요라, "이번 한 번만" 에 해당하는 두 행(단발성 / 문서 커밋)이 어디에도
  없었다. 두 행은 env var 가 아니라 arm-once(v0.25.0) 설계에서 따라 나오는 성질이다.
  이 표는 mandate 문장의 **참조본**이지 유일한 전달 경로가 아니다 — 찾아보지 않는 문서는
  이 실패를 못 막는다는 것이 이번 건의 요지다.
- `systemMessage`(사용자향)는 **무변경**. 같은 사건에 사용자와 Claude 가 서로 다른
  강도의 신호를 받으면(사용자 화면 "1회" vs Claude "MANDATORY") 두 참여자가 다른
  구속력을 믿은 채 대화하게 된다 — 지금보다 나쁘다.

### Added

- `tests/test_hook_output_schema.py` `TestReviewDispatchMandateScope` 3종 — 존재
  1 + 상호배타 2(양방향). **mutation 3축 전부 RED 로 이빨 증명**: M1 문장 삭제 →
  RED, M2 `else`→`if True`(상한에서 두 문장 동시 방출) → RED, M3 문자열은 파일에
  남기되 `msg_lines` 에 안 싣기 → RED. **M3 가 요점이다** — grep 기반 락이었다면
  GREEN 이었을 mutation 에서 RED 가 나므로 이 락은 문자열의 존재가 아니라 그것이
  `reason` 채널에 실리는지를 잰다. 단방향으로 두면 두 문장을 모두 내보내는 mutation 이
  통과하므로 상호배타 두 방향은 함께 있어야 한다.

### 리뷰 라운드 (codex 독립 감사, 머지 전)

별-모델 독립 리뷰가 **작성자가 놓친 4건**을 적발했고 전부 이 릴리스에서 수정했다.

- **[C1] README 사다리가 모델에게 skip 을 지시하고 있었다.** 첫 판본의 "이번 dispatch
  한 번만" 행이 *"그냥 이번 턴에 리뷰를 건너뛰면 된다"* 였다 — `reason` 에는 면제 문구를
  넣지 않으려고 신중히 썼으면서, **같은 PR 의 README 가 그 절제를 무효화**했다. writer
  턴이 자기 리뷰를 skip 할 근거가 되므로 Law 2 위반이다. 표를 *"어떻게 건너뛰나"* 에서
  *"무엇이 범위를 정하나"* 로 재구성했다(열 제목 `방법` → `그 범위를 만드는 것`).
  이 PR 의 e2e 가 이미 신호를 줬으나(README 만 있는 arm 에서 3/3 이 "그냥 건너뛰면
  됩니다") 작성자는 그것을 *"README 도 효과 있다"* 로만 읽고 반대 해석을 놓쳤다.
- **[C2] mandate 가 fail-open 경로에서 거짓을 주장했다.** *"커밋하면 더 이상 arm 되지
  않는다"* 는 무조건 단정이었는데, `is_born()` 은 git 판정 실패(`ls-files` timeout·rc 128)를
  **전부 arm 쪽으로 fail-open** 한다 — 커밋된 문서도 arm 될 수 있다. `arm_ledger` import
  실패 시 `cap=0` 이 되어 같은 `else` 로 떨어지는 경로도 같은 거짓을 낸다. 커밋 절을
  mandate 에서 **제거**했다. 커밋 권고는 approve 시점 `check-born` advisory 가 이미
  담당하며, 거기서는 실제 git 판정 결과를 손에 쥐고 말하므로 거짓이 될 수 없다.
- **[C3] "커밋하면 영구히" 가 이미 걸린 dispatch 도 멈추는 것처럼 읽혔다.** Stop 은 pending 을
  찾은 뒤 `armed_paths` 만 조회하고 git 추적 여부를 재검사하지 않으므로, pending 생성 후
  같은 턴에 커밋해도 그 dispatch 는 실행된다. README 에 명시했다.
- **[C4] 락이 문구의 존재만 재고 진위는 재지 않았다.** C2 의 거짓 단정이 있어도 문구 락
  3종은 전부 GREEN 이었다. `TestMandateClaimsAreTrue` 3종 추가 — validator·Stop·상태
  파일을 실제로 태워 남은 두 주장 각각을 검증하고, 무조건 커밋 단정의 재도입을 금지한다.

**mutation 6축 전부 RED.** 문구 락 3(M1 삭제 / M2 `else`→`if True` / M3 문자열은 파일에
남기고 채널만 끊기) + 진위 락 3(N1 pending 소진 제거 / N2 `should_arm` 상시 False /
N3 커밋 단정 재도입). 그 과정에서 **계측기 결함 2건**을 잡았다:

- 진위 락 초판은 N1 에서 GREEN 이었다 — 두 번째 Stop 의 침묵을 만든 것이 pending
  소진이 아니라 **30초 redispatch TTL 가드**였다. 락이 엉뚱한 메커니즘을 재고 있었다.
  `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0` 으로 TTL 을 끄자 침묵을 설명할 수 있는
  것이 pending 소진뿐이 되어 RED 로 전환됐다.
- M2 mutation 앵커 `"    else:\n"` 가 파일에서 유일하지 않아 **첫 else 에 착지**해
  대상 분기를 건드리지 못한 채 GREEN 이 났다. 앵커를 본문 고유 문자열로 좁혀 해결.

## [0.25.1] — 2026-08-05

### Fixed

- **`parse_spec_structure.py` ambiguity 게이트 검출력 회귀 (Law 1).** 라운드 3 `/qg`가 적발.
  Task 10이 하이픈 복합어 오탐(`fast-forward`)을 막으려고 경계를
  `(?<![\w-])…(?![\w-])`로 잡았는데, **뒤쪽까지 단어문자를 막아** blacklist 어간의 접미
  굴절형이 전부 통과하게 됐다 — `seamlessly`·`efficiently`·`Robustness`·`faster`가 모두
  게이트를 빠져나갔다. 선언된 동기는 하이픈뿐이었고 T6-4/T6-5는 이 방향을 측정하지 않는다.
  → 경계를 **비대칭**으로 정정: `(?<![\w-])…(?!-)`. 앞은 단어·하이픈 금지(→ `breakfast`,
  `inefficient` 오탐 계속 차단), 뒤는 **하이픈만** 금지(→ 굴절형 복구). 오탐 1종을 막으려다
  미탐 다수를 만든 교환을 되돌린다.

### Added

- `tests/test_parse_spec_structure.sh` T6-6 — 접미 굴절형(`-ly`/`-ness`/`-er`)이 계속 hit되는지
  측정. T6-4(오탐 없음)와 T6-5(어간 그대로는 hit)만으로는 이 방향이 비어 있어서, 경계를 양쪽
  다 막아도 둘 다 GREEN이었다.

## [0.25.0] — 2026-08-02

design doc auto-review 를 **문서가 처음 생길 때 한 번만** 발동시키고, 그 재발동을 막으려
v0.14.0–v0.18.0 에 쌓인 방어층 4개를 원인과 함께 걷어냈다. 교훈 한 줄: **원인을 지우면
그 원인을 막던 방어층도 같이 지워진다** — 셋 다 사용자 기능이 아니라 훅이 자기가 만든
문제를 자기가 막는 내부 하니스였다.

### Changed
- **arm 조건이 `(세션 원장에 없음) AND (git 이 모르는 문서)` 로 바뀌었다.** 판정은
  `scripts/arm_ledger.py` 의 `should_arm()` 한 곳에만 존재하고 훅은 그것만 부른다.
  두 조건이 서로 다른 시간축을 덮는다 — 원장 단독이면 세션마다 한 번씩 다시 리뷰되고,
  git 단독이면 커밋 전 fix 루프에서 계속 재arm 된다.
- **원장 기록자가 둘로 확정됐다** — verdict 가 나온 리뷰(완료) 와 G6 상한(3회)에 닿은
  Stop 훅(포기). validator·skill 진입, 그리고 **상한 미달의 정상 dispatch** 는 쓰지
  않는다. 그 셋 중 어디에 써도 "리뷰를 받지 않았는데 표시된" 창이 생기고, 삭제된
  락이 TTL 로 얻던 자기치유를 잃는다. verdict 시점 기록은 TTL 을 새로 만들지 않고
  같은 자기치유를 얻는다 — **표시되지 않은 문서는 다음 arming 편집에서 다시 dispatch 되기 때문**.
  두 기록자의 결론은 같다("더 이상 dispatch 안 함"), 그리고 어느 쪽도 문서를 쓴 턴이 아니다.
- **리뷰 진행 중 오발 방지가 락에서 pending strip + 원장 게이트로 바뀌었다.** dispatch 의
  연료는 `pending_review` 이므로 `reviewing-spec` 진입 시 연료를 없애면 락이 필요 없다.
  다만 진입 strip 하나만으로는 부족하다 — skill 이 Step 1(strip-pending)과 Step 3
  (mark-reviewed)을 분리된 두 bash 블록으로 실행하므로, Step 1 이 빠지면 pending 이
  살아남고 실제 리뷰는 30초 TTL 을 넘겨 다음 Stop 이 이미 리뷰된 문서에 다시 block 을
  낸다. 그래서 **Stop·UserPromptSubmit 두 소비자가 emit 전에 `armed_paths` 를 조회**한다
  (Stop 은 남은 stale pending 도 함께 정리하고 결과를 보고한다; `armed_paths` 는 건드리지
  않으므로 상한 미달 무-기록 성질은 유지). 조회 실패는 dispatch 쪽 fail-open.
- **`is_born` 의 cwd 의존을 제거했다.** 전에는 raw_path 를 cwd 상대 git pathspec 으로
  넘겨, 하위 디렉토리에서 부르면 **커밋된 문서가 not-born** 으로 떨어졌다 (v0.14.0 에
  출하됐던 버그와 같은 모양이며 그 락은 승계 없이 삭제돼 있었다). 이제 **상대경로만**
  `:(top,literal)`+canonical_key 로 리포 루트에 고정하고, **절대경로는 접지 않는다** —
  접으면 다른 체크아웃의 문서를 이 리포 파일로 오판한다(아래 Fixed 참조).
- **제어문자가 든 경로는 원장에 들어가지 못한다 (Security).** 상태 파일은 0-indent 블록으로
  파싱되는 마크다운이라, 개행이 든 `tool_input.file_path` 가 그대로 보간되면 `armed_paths:`
  를 위조해 **다른 문서**의 리뷰를 영구 억제할 수 있었다(T16 mutation 으로 실증 — 가드를
  빼면 위조가 성공한다). 차단은 **writer**(`write_state`)에 둔다 — reader 마다 거르면 새
  reader 가 생길 때마다 두더지잡기가 된다. `canonical_key` 도 방어적으로 함께 거부한다.
- **`_read_body` 가 부재(`""`)와 판독 실패(`None`)를 구분한다.** 빈 body 로의 degrade 는
  읽기 술어(`is_armed`·`skip_reason`)에는 옳지만(미기록 → arm, 안전한 방향),
  read-modify-write 인 `mark_reviewed`·`strip_pending_file` 에서는 판독 불가 원장을
  통째로 덮어써 다른 문서의 `armed_paths` 와 살아있는 `pending_review` 를 함께 지웠다.
  이제 두 쓰기 경로는 보존하고 멈춘다(P14). 훅 두 곳의 `except OSError` 도
  `(OSError, UnicodeDecodeError)` 로 넓혔다 — `UnicodeDecodeError` 는 `ValueError`
  하위라 좁은 절이 판독 불가 원장에서 훅을 죽여 dispatch 를 통째로 없애고 있었다.
- **PostToolUse arm-skip advisory 가 사유를 세 가지로 구분**한다 — 세션 내 리뷰 완료 /
  git 이 아는 문서 / G6 상한 도달. 앞의 둘과 셋째는 사용자가 취해야 할 행동이 다르다.

### Added
- **G6 재시도 상한 (세션당·문서당 3회).** verdict 없이 끝난 dispatch 의 재시도는
  의도된 동작이지만 무한하면 Forbidden Pattern(*Unbounded autonomy*)이다.
  `dispatch_attempts` 가 3 에 닿는 dispatch 가 마지막이고, 그 emit 이 상한을 알린다.
  경계가 세션당인 이유: 그 상태는 세션 스코프이고, 문서 생애 상한으로 만들려면
  세션 밖에 살아남는 저장소가 필요한데 그것은 NG4 가 배제한다. 세션을 넘겨도 멈추게
  하는 진짜 수단은 문서를 커밋하는 것이고 approve 시점 `check-born` advisory 가 그것을 촉구한다.
- 회귀 락 T1–T19 (`tests/test_arm_once.sh` T1–T3·T13–T19, `tests/test_stale_terms.sh`
  V9·V10 = T4·T5, `tests/test_arm_ledger_timing.sh` T6–T12) + `tests/test_arm_ledger.py`
  유닛 · `tests/arm_test_helpers.sh` 공유 하니스 —
  전부 mutation 으로 이빨을 증명했다. T7·T8 은 서로 반대 방향이라 함께 있어야 이빨이
  생기고, T10 은 `arm_ledger` CLI 의미가 아니라 **상한 미달 dispatch 단독에서의 Stop 훅
  원장 무-기록**을 잰다(상한에 닿는 dispatch 는 반대로 기록한다 — 그 구분이 T10 의 요지).
- 승계 락 S5–S8 (`tests/test_reviewing_spec_state_keying.sh`) — 삭제된 AC8-c·AC11-a·
  AC11-b·AC8-a/b 가 잠그던 불변식의 승계처. 세 섹션 윈도우는 종료 앵커의 존재를 먼저
  확인한다: `sed` 의 범위 주소는 종료 주소가 매칭되지 않으면 EOF 까지 출력하므로,
  그 확인이 없으면 무관한 라벨 rename 한 번에 "공존" 락이 조용히 file-wide 존재
  확인으로 바뀐다(측정: 12줄 → 130줄, 스위트는 GREEN).
- T17 — 세 훅의 UTF-8 stdio 고정 회귀 락. **트리거는 `LC_ALL=C` 가 아니다**: macOS
  CPython 은 C 로케일에서도 stdio 를 UTF-8 로 강제해, 로케일 축으로는 핀을 통째로
  제거해도 차이가 없다(측정 8회). 실제로 갈리는 축은 `PYTHONIOENCODING` 이며 T17 은
  그쪽을 잰다.
- `tests/test_arm_ledger.py` 유닛 4종 추가 — `armed_paths` 위조(splitlines 경계),
  교차-체크아웃 `is_born`, `PATH_PREFIX`↔`PREFIX` 계약, `strip_pending_file` 의
  판독불가 보존(모듈이 "유일한 비대칭 방어" 라 부르는 쌍의 나머지 절반).

### Fixed
- `is_born()` 이 다른 체크아웃의 문서를 이 리포의 동명 파일로 판정하던 결함. pathspec 을
  `:/{canonical_key}` 로 접으면 **어느 체크아웃이었는지가 사라진다** — 접힌 키가 이 리포
  index 에 있으면 born=True 가 되고 `should_arm` 이 False 로 떨어져 그 문서의 Law 1
  게이트가 조용히 꺼진다. 현실적 트리거는 이 프로젝트 자신의 레이아웃이었다(cwd = main
  repo, 편집 대상 = `.claude/worktrees/<name>/docs/superpowers/specs/…`). 이제 절대경로는
  접지 않고 git 이 소속 리포를 판정하게 두며(리포 밖이면 128 → loud → arm), 상대경로만
  `:(top,literal)` 로 리포 루트에 고정한다. `--` 는 옵션 파싱만 멈출 뿐 wildmatch 를 끄지
  않으므로 `literal` 매직이 함께 필요하다 — 그전엔 파일명 속 `*` 하나로 존재한 적 없는
  문서가 born 이 됐다.
- pending 기록에 실패한 편집에도 "Reviewer will be dispatched at turn end" advisory 가
  나가던 결함. `write_state` 가 실패 **사유**를 반환하고 호출부가 그것을 소비해
  `emit_arm_skip_advisory` 로 진실을 보고한 뒤 성공 advisory 앞에서 종료한다. 기록이
  안 됐는데 리뷰를 약속하면 모델은 오지 않을 리뷰를 기다린다(under-review 방향).
- writer 와 `canonical_key` 가 서로 다른 문자 집합을 거부하던 결함. 차집합(탭·NBSP·ZWSP 등)
  에 속하는 파일명은 pending 은 쓰이는데 원장엔 기록될 수 없어 `dispatch_attempts` 가
  오르지 않았고, G6 상한(3)이 **구조적으로 무력화**돼 편집마다 영구 재발동했다. 이제
  writer 가 `canonical_key` 를 술어로 쓴다(판정 지점 1곳).
- Stop 훅 원장 게이트에서 `return 0` 이 `try` 안에 있어, veto 확정 **이후** sweep 이
  던진 예외가 dispatch 경로로 흘러 이미 기록된 문서를 다시 dispatch 하던 결함. 판정과
  부작용의 `try` 를 분리했고, sweep 실패 시 문구도 사실에 맞췄다(조회는 성공했다).
- validator 의 stdin `except` 가 `OSError` 까지 삼키면서 arm 지점에서 rc 0 + 무출력이
  되던 결함. 형제 두 훅은 같은 릴리스에서 advisory 를 받았고 이 파일만 빠져 있었다.
- **arm 은 됐는데 기록이 안 된 모든 분기가 성공 advisory 로 새던 결함.** pending 이
  없으면 Stop 훅이 볼 것이 없어 리뷰는 영영 발동하지 않는데, `write_state` 실패·세션 id
  미해석·`SKIP_AUTOREVIEW=1` 세 경로가 그대로 "Reviewer will be dispatched at turn end"
  로 흘렀다. 이제 각 경로가 사유 sentinel 과 함께 arm-skip advisory 를 내고 종료한다
  (T18·T19 가 stdout 을 두 축으로 잰다 — arm-skip 이 **있고** 성공 문구가 **없다**).
- **`unkeyable()` 의 예외 폭·검사 범위 정렬.** `ImportError` 만 잡아 `arm_ledger` 의
  `SyntaxError`(머지 충돌 마커 등)가 arm 게이트에서 degrade 된 뒤 writer 에서 다시 터져
  훅이 rc≠0 + 무-stdout 으로 죽었다(HEAD 에서는 정상 arm 되던 입력). 또 fallback 이
  경로 **전체**를 검사해 `canonical_key`(PREFIX 이후만 검사)와 어긋났고, 그 방향이
  fail-**closed** 였다. 둘 다 맞췄다.
- **인코딩 불가 상태 값이 훅을 죽이던 결함.** `os.getcwd()` 의 surrogateescape 문자열은
  줄 수 검사를 통과하고 `write_text` 에서 `UnicodeEncodeError` 를 던지는데, 그건
  `ValueError` 하위라 호출부의 `except (PermissionError, OSError)` 를 그대로 통과했다.
  선제 인코딩 검사 + `UnicodeError` 절.
- **`skip_reason` 이 "스코프 밖"과 "키 불가"를 뭉개던 결함.** 파일명의 보이지 않는 문자
  하나로 자동 리뷰를 잃은 문서가 "스코프 밖 경로"로 보고돼 원인도 조치도 알 수 없었다.
- **`bounded_window` 의 순서 역전 구멍.** 종료 앵커의 *존재*만 확인하면, 앵커가 시작보다
  앞에 있을 때 범위가 그대로 EOF 까지 흐른다(실측 12줄 → 129줄, GREEN). 이제 출력의
  마지막 줄이 종료 앵커인지 — 즉 범위가 **거기서 끝났는지** — 를 잰다. 같은 파일의 S1 이
  `pipefail` 아래에서 `grep -q` 로 파이프하던 것도 herestring 으로 바꿨다(SIGPIPE 141 이
  매치 성공을 FAIL 로 뒤집는다).
- **T17 의 거짓 진단.** `'제어문자'` 를 앵커로 쓰면 인코딩 주장이 어느 가드가 처리했는지에
  묶여, 다른 가드를 지웠을 때 "stdio 고정 없음" 이라고 잘못 보고했다. 두 가드에 공통인
  문구로 옮겨 두 성질을 분리했다.

### Security
- `canonical_key` 가 `str.splitlines()` 경계를 명시적으로 거부한다. 원장 reader
  (`armed_keys`·`attempts`)는 `splitlines()` 로 줄을 나누는데 그건 `\n` 뿐 아니라
  VT·FF·FS·GS·RS·NEL·U+2028·U+2029 에서도 쪼갠다. 반면 `ARMED_RE` 의 `[^\n]+` 는 그것들을
  전부 통과시키므로, U+2028 이 든 키는 **물리적으로 한 줄**로 기록되고 **두 개의 키**로
  읽혀 다른 문서의 리뷰를 영구 억제할 수 있었다(유닛으로 실증). `isprintable()` 이 부수적
  으로 같은 문자를 막고 있었으나 선언이 아니었고, 실제로 리뷰에서 "그 절을 좁히자"는
  제안이 나왔다 — 그 mutation 은 이제 RED 다.
- `write_state` 가 완성된 pending 블록의 줄 수를 reader 와 **같은 함수**로 검사한다.
  `path` 외에 `mode`·`worktree_path`(=`os.getcwd()`, POSIX 디렉토리명에 개행 허용) 도
  같은 보간 지점이라, 값마다 술어를 늘리는 대신 블록 전체를 한 번 센다.

### Removed
- `scripts/review_lock.py`(240) · `scripts/cancel_review.py`(99) ·
  `scripts/approve_handoff.sh`(98) · `scripts/suppress_state.py`(242) — 합계 679 줄이
  사라지고 `scripts/arm_ledger.py` 한 파일이 그 자리를 대신한다(순감소 ~240줄).
  <!-- 대체 파일의 절대 줄수는 적지 않는다: 같은 릴리스 안에서 이 파일을 고칠 때마다
       숫자가 낡고, 실제로 리뷰에서 369→410 불일치로 적발됐다. 삭제분 679 는 확정값. -->
- `/spec-distill:cancel-review` 커맨드. 네 용도 중 (a) approve 후 재arm 억제와
  (b) 고착 pending 정리는 **대상이 소멸**했고, (c) 미리 옵트아웃은 **인정된 손실**이며
  (남는 비용은 미커밋인 채 넘긴 세션당 dispatch 1회, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`
  로 0 이 된다), (d) `harness_sid` 미해석 시 수동 억제는 대체 안내로 지정했다
  (그 지시는 원래도 부정확했다 — sid 가 없으면 그 커맨드도 상태를 못 썼다).
- 환경변수 `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` (락 소멸).
- 전용 테스트 7종 중 **6종 삭제 + 1종은 개명·축소 승계**(`tests/test_reviewing_spec_lock.sh`
  → `tests/test_reviewing_spec_state_keying.sh`, Task 7 — 삭제가 아니다). 삭제된 6종 중
  두 handoff 테스트(`test_handoff_compact_chain.sh`·`test_handoff_spec_path_validation.sh`)가
  잠그던 dangling-경로 무-abort 불변식은 T11 이 승계.

### Fixed
- `tests/test_stale_terms.sh` 의 production 파일 필터가 앵커 없는 `*/.claude/*` 라,
  하니스 워크트리(`<repo>/.claude/worktrees/`) 안에서 production 47 개를 전부 삼켰다.
  락은 empty-guard 로 FAIL 했지만(fail-closed 설계가 제 역할을 했다) **워크트리에서는
  실행 자체가 불가능**했다. `$SD` 기준으로 앵커했다.
## [0.24.17] — 2026-08-05

### Fixed

- **`agents/blind-spot-prober.md`의 고아 인용 제거.** `fan-out 1`을 정당화하며 `devbrew N≥5 게이트 미해당`을 근거로 들었는데 그 게이트는 이 sweep이 삭제했다. persona 산문은 이 리포에서 보안-민감 코드로 취급된다.
- **`commands/interview.md` trivia 목록을 philosophy P12와 정합화.** P12가 `파일 수와 무관하게`로 완화됐는데도 이 파일 — **P12가 자기 집행 지점으로 지목한 곳** — 은 `단일 파일 formatting`·`단일 파일 내 단일 식별자 rename`을 그대로 요구했다. 판정 기준을 파일 수에서 "한 문장으로 설명 가능한가"로 되돌린다.
- `README.md`의 P12 자격 서술도 같이 정합화.

## [0.24.16] — 2026-08-05

### Security

- **web kill switch가 egress를 가진 dispatch 두 곳을 덮지 못하던 공백 봉쇄** (`/qg branch` 라운드 2, codex·silent-failure-hunter 적발). 0.24.15가 `coverage-mapper`에 `WebSearch`/`WebFetch`를, `spec-reviewer`에 `WebSearch`를 **새로 부여**했는데 `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`은 둘 다 막지 못했다:
  - `reviewing-spec/SKILL.md` — 스위치 참조 **0건**인 채로 `spec-reviewer`를 dispatch.
  - `conducting-interview/SKILL.md` — `coverage-mapper` dispatch에 게이트 없음(형제 3경로는 전부 보유).
  두 agent 모두 `tools:`에 `Bash`가 없어 스스로 스위치를 읽을 수 없다(Law 2) — orchestrator가 유일한 집행 지점이다. **안 죽이는 kill switch는 없는 것보다 나쁘다**: 사용자가 egress가 꺼졌다고 *믿고* 행동한다.

### Fixed

- **`test_web_kill_switch.sh`의 앵커를 피검자 손에서 회수** (adversarial `meta_note`가 명명한 *verifier-steerable anchor*). 판정이 `grep -q "spec-distill:$a"`였으므로, 접두사 없이 `subagent_type: "spec-reviewer"`로 쓴 저자는 **자기 skill을 감사 대상에서 스스로 제외**했다 — 검사받는 파일이 자기가 검사받을지를 결정하는 구조. reviewing-spec이 정확히 그렇게 누락돼 있었다. → 접두사를 선택적(`(spec-distill:)?`)으로.
- **파일 전역 존재 검사를 dispatch 지점별 지배 관계로 교체.** "이 파일 어딘가에 확인이 있다"는 명제는 dispatch가 열 개여도 가드가 하나면 참이다. 이제 각 dispatch 줄마다 위 40줄 안에 확인이 있어야 한다.

## [0.24.15] — 2026-08-04

### Fixed

- `README.md:74`·`:110` — Law 2 선언이 실제 `tools:` allowlist보다 **좁게** 적혀
  있었다. `spec-reviewer`와 `coverage-mapper`가 이 sweep에서 `WebSearch`/`WebFetch`를
  받았는데 README는 옛 목록을 유지해 **부여된 egress를 문서가 은폐**했다
  (`/qg branch` 라운드 1, security-reviewer + code-reviewer 독립 적발).
  `tests/test_readme_sync.sh:52`는 agent *이름*만 grep해 이 drift를 못 본다.
  - **미해결로 남긴 것**: `coverage-mapper`의 본문은 웹 조사를 요구하지 않는데도
    egress를 갖는다(설계 goal-3의 자기 기준 미충족). adversarial은 SUGGESTION으로
    강등했고 — 설계 AC3가 의도적으로 부여했으므로 exfiltration 판정은 성립하지
    않는다 — 되돌리려면 frontmatter·AC3·frontmatter 락 2개를 **한 커밋에 함께**
    고쳐야 한다. 이번 라운드 범위 밖.

### Changed

- `tests/test_web_kill_switch.sh` — 소비자 목록을 열거에서 **도출**로, 앵커를
  선언에서 **소비**로 (0.24.14 항목 참조).

## [0.24.14] — 2026-08-04

### Fixed

- **`run_spec_codex_reviewer.sh` — 완료 전 중단이 조용히 지나가던 경로**
  (`/qg branch` 라운드 1, silent-failure-hunter). `set -u` 위반(예:
  `CLAUDE_PLUGIN_ROOT` 미설정)으로 abort하면 EXIT trap을 지나며 산출물이
  만들어지지 않았고, 더 나쁘게는 **이전 run이 남긴 파일이 살아남아 이번 라운드의
  리뷰 결과로 재사용**됐다.
  - 보고된 fix(`rc=$?` 보존)는 **이 플랫폼에서 동작하지 않는다**: bash 3.2.57은
    `set -u` abort 시 트랩 핸들러에 `$?`를 **0으로** 넘긴다(최소 재현 확인).
    게다가 이 스크립트의 계약은 "항상 exit 0 + 항상 YAML"이라 비-0 강제는 계약
    위반이다. 그래서 종료 코드가 아니라 **산출물**로 판정한다 — 시작 시 truncate로
    stale을 제거하고, 트랩에서 비어 있으면 `codex_failed: true` degrade를 채운다.
  - trap arm은 한 줄로 유지했다: C7 순서 락(AC6)이 `trap.*rm -rf.*SCRATCH.*EXIT`를
    한 줄 정규식으로 앵커하므로, 여러 줄로 펼치면 그 락이 trap을 못 보고 guard
    순서 검사가 통째로 무력화된다.

### Added

- `tests/test_run_spec_codex_reviewer.sh` — ABORT 케이스 2종(중단 시 degrade YAML
  실재 / 이전 run의 stale 산출물 미재사용). 종료 코드가 아니라 산출물을 잰다.

## [0.24.13] — 2026-08-03

### Fixed
- `scripts/parse_spec_structure.py`의 `scan_ambiguity()`가 blacklist 문구를
  `re.escape(phrase)` bare substring으로 찾아 하이픈 복합어·접두 결합 안에서도
  발화했다 (`fast-forward`의 `fast`, `inefficient`의 `efficient` 등) —
  ambiguity 없는 정상 기술 문서의 write를 Law 1 게이트가 거짓으로 막는
  harness-capability-suppression-sweep S3f. **이 문서를 쓰는 동안 실제로 이
  검사가 write를 세 번 exit 2로 막았다.** 단순 `\b` 감싸기는 이 버그를
  고치지 못한다 — 하이픈은 `\w`가 아니라서 `\bfast\b`도 `fast-forward` 안의
  `fast`에 그대로 매치한다. 경계 판정을 `(?<![\w-])phrase(?![\w-])`로 교체해
  하이픈을 경계 문자 집합에 포함시켰다 — `~phrase` opt-out(문구 직전이 `~`가
  아닌지 별도 확인)은 `~`가 `\w`도 `-`도 아니므로 그대로 동작한다.

## [0.24.12] — 2026-08-03

### Removed
- `scripts/web_budget.py` + `tests/test_web_sweep_bound.sh` + 관련 픽스처 4개
  (`state-web-within.md`·`state-web-over-sweep.md`·`state-web-over-session.md`·
  `state-web-commented-overcap.md`) — web landscape 조사의 per-sweep(≤4)/
  per-session(≤8) 상한 enforcer를 제거 (harness-capability-suppression-sweep
  S3d, Task 8). **내부 스크립트라 one-minor deprecation window 대상이 아니다** —
  유일한 소비자가 이 플러그인 안의 두 곳(`conducting-interview` R2,
  `reviewing-brief` 1-a)뿐이라 외부 breaking-change 표면이 없다.
- state schema(`conducting-interview`)와 `templates/interview-audit-template.md`의
  `web_sweep_count`/`web_search_count` 카운터 — 상한 게이트가 사라져 죽은 상태였다
  (`probe_count`는 유지 — 그 상한은 살아 있다).

### Security
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB` kill switch를 `web_budget.py` 삭제와 함께
  잃지 않도록 두 소비자에 각각 인라인으로 이식 — `conducting-interview` R2와
  `reviewing-brief` 1-a가 `run_brief_codex_reviewer.sh:96-99`와 동일한 계약으로
  독립 확인한다(정확히 문자열 `"1"`만 참, 미설정 시 웹 활성, 매 웹 작업 직전 평가,
  소비자별 소유·공유 헬퍼 없음).

## [0.24.11] — 2026-08-03

### Fixed
- `build_spec_codex_prompt.py`의 `PROMPT_TEMPLATE`에서 프롬프트 서두(:29-31)와
  `other` 항목(:44)은 0.24.10에서 "여섯 개는 시작 어휘, 닫힌 목록 아니다"로
  열었지만, 같은 템플릿의 JSON 출력 계약(`"category": "placeholder | ... |
  testing"`, :59)은 여전히 6개로 닫혀 있었다 — prose는 열렸는데 contract는
  안 열린 자기모순. 구조화 출력을 쓰는 모델은 prose와 schema가 충돌하면
  schema를 따른다: 여섯 이름 어디에도 안 맞는 진짜 결함을 발견한 리뷰어는
  prose로는 "`other`를 자유롭게 쓰라"는 지시를, contract로는 "`other`는 허용
  값이 아니다"는 지시를 동시에 받는다 — 이 태스크가 없애려던 바로 그 drop이
  한 레이어 아래로 옮겨갔을 뿐이었다. `:59`의 pipe-list에 기존 6개 순서를
  그대로 두고 `| other`를 추가.
  (참고: 같은 파일 module docstring `:5`의 "same 6 judgment categories the
  Claude spec-reviewer uses"는 검증 결과 그대로 두는 것이 맞다 — Claude
  spec-reviewer(`agents/spec-reviewer.md:121,149,155`)는 여전히 정확히 6개
  닫힌 taxonomy를 쓰고, 이 문장은 codex 프롬프트가 그 6개와 "동일한 6개"를
  기준으로 시작한다는 서술이지 codex 쪽 categoy가 6개로 닫혀 있다는 주장이
  아니라서 열린 `other`와 모순되지 않는다. codex 프롬프트 밖의 순수 문서라
  codex가 실제로 읽는 계약에도 영향 없다.)

### Added
- `test_build_spec_codex_prompt.sh`에 AC16b 락 추가 — JSON 출력 계약의
  `"category":` 힌트 줄에 `other`가 없으면 RED. 기존 AC16(prose `other` 존재)
  과 독립: prose만 보는 전-출력 grep이었다면 `other`가 이미 흔한 단어라(prose
  bullet 자신, ":33"의 "or other unfinished text") schema가 닫힌 채로도
  통과했을 것 — `"category":` 줄에 앵커링해 계약 표면만 정확히 겨냥.

## [0.24.10] — 2026-08-03

### Changed
- `build_spec_codex_prompt.py`의 `PROMPT_TEMPLATE`에서 "Review the document
  below for these SIX judgment categories only:" 를 "이 여섯 개는 하류 merge가
  가장 자주 기대하는 시작 어휘일 뿐, 닫힌 목록이 아니다"로 교체하고 여섯 항목
  뒤에 `other` 탈출구를 추가 — codex co-reviewer에게 "여섯 개뿐"이라고 지시하면
  그 어느 이름에도 안 맞는 진짜 결함은 merge/dedup 로직이 보기도 전에 프롬프트
  단에서 버려진다. 하류 파서는 바꾸지 않는다: `merge_review.py:86`은
  `str(it.get("category", ""))`로 자유 문자열을 통과시키고, `:319`/`:326`은
  `compute_issue_id.compute(category, target_section)`으로 해시 입력에만 쓴다.
  `codex_findings_to_yaml.py`·`compute_issue_id.py` 어디에도 6개 화이트리스트
  필터가 없다(실측 확인) — 따라서 파서 변경 없이 프롬프트만 여는 것이 정확하다.

### Added
- `test_build_spec_codex_prompt.sh`에 AC16 락 신설 — 닫힌-6개 문구 재삽입 시
  RED, `other` 항목 삭제 시 RED (프롬프트 레이어).
- `test_merge_review.py`에 `test_unknown_category_survives_merge` 신설 —
  codex YAML에 `category: other`인 finding을 넣고 실제 merge를 돌려 그 항목이
  `codex_findings` 표시 블록에 살아 있고, 6개 카테고리와 같은 해시 경로로
  issue_id를 받고, severity가 여전히 verdict를 escalate함을 확인한다
  (파이프라인 레이어 — 프롬프트 락과 분리: 프롬프트가 `other`를 광고해도
  미래에 파서가 화이트리스트 필터를 넣으면 조용히 drop될 수 있는 경로를
  독립적으로 잠근다).

## [0.24.9] — 2026-08-03

### Changed
- `conducting-interview` SKILL.md의 R3 steelman dispatch 지시(`:306`)에서
  `**순차** dispatch(병렬·투기적 금지 — C5)` 문구를 삭제 — 0.24.8에서 `steelman-builder`
  에이전트 persona에서 지운 것과 같은 억제가 오케스트레이터 쪽 dispatch 지시문에도
  거울처럼 남아 있었다(0.24.8의 브리프 file list 누락, 이번 sweep의 repo-wide 판별
  질의가 적발). 인용된 두 근거 다 성립하지 않는다: `C5`는 web 부재 시 graceful
  degradation을 가리키지 dispatch 순서와 무관하고(design.md:107), `AP9`의 병렬 fan-out
  게이트는 N≥5부터인데(philosophy.md:95-96) R3는 의심 트리거당 steelman 1회로 fan-out=1
  이라 그 문턱에 닿지 않는다. `투기적 금지`는 R3의 numbered step이 의심 트리거가 이미
  발화한 뒤에만 도달하므로 애초에 발생 불가능한 경로를 금지하는 무의미한 문구였다.
  `:311`의 "한 방향당 steelman 1회(재steelman 금지 — AP16 harassment 방지)" load-bearing
  bound는 그대로 둔다.

### Added
- `test_conducting_interview_stage.sh`에 R3-스코프 E10 락 신설 — 기존 `r3_block`
  awk 윈도우(`### R3 — Steelman` ~ 다음 `### `/`## ` 헤딩)를 재사용해 병렬·투기적 금지
  문구 재삽입 시 RED. 전-파일 grep이 아니라 R3 윈도우로 스코프한 이유: 같은 SKILL에
  `:122`의 `teach-beat 최대 1회`, `:438`의 `2회까지`가 legitimately 남아있다.

## [0.24.8] — 2026-08-03

### Changed
- `steelman-builder` · `blind-spot-prober`의 "Required research" 절에서 `1–2회`
  검색 횟수 상한과 `**순차 호출**(병렬·투기적 금지, C5/AP9)` 문구를 삭제. 두 에이전트는
  인터뷰 턴이 놓친 근거를 찾는 게 존재 이유인데, 호출 수 상한과 직렬화 강제 둘 다
  아무것도 보호하지 않으면서 조사 폭을 하니스가 대신 정하는 것이었다. 이제
  "필요한 만큼 찾는다"(steelman-builder) / 횟수·병렬 제약 없이 수집(blind-spot-prober).
  `blind-spot-prober.md`의 "web 부재 시 SKILL이 inline premortem으로 강등(C5)" 절은
  상한이 아니라 graceful degradation이므로 그대로 둔다.

### Added
- `test_steelman_builder_scope.sh` · `test_blind_spot_prober_frontmatter.sh`에 E10
  락 신설(`test_brief_agents.sh:194`의 단일 호출 상한 부재 락을 숫자 범위·병렬 금지
  패턴으로 확장) — 단일 호출 상한 표현(`최대 N회`/`N회까지`/`N–N회`/`N-N회`/
  `max_x = N`) 또는 병렬·투기적 금지 문구가 재삽입되면 RED.

## [0.24.7] — 2026-08-03

### Changed
- `spec-reviewer`의 `tools:`에 `WebSearch` 추가 — 기존 `Read, Grep, Glob, WebFetch`는
  URL은 열 수 있는데 찾을 수는 없는 비대칭이었다(순수 억제, 아무것도 보호하지 않음).
  이제 `Read, Grep, Glob, WebSearch, WebFetch`.
- `coverage-mapper`의 `tools:`에 `WebSearch, WebFetch` 추가 — 주제가 요구하는 커버리지
  차원을 제안하는 역할인데 웹 도구가 아예 없었다. 이제 `Read, Grep, Glob, WebSearch, WebFetch`.

### Added
- `test_spec_reviewer_frontmatter.sh` · `test_coverage_mapper_frontmatter.sh`에
  조용한-열화 방지 락 신설 — `tools:`에서 `WebSearch`/`WebFetch`가 사라지면 RED.
  Law 2 `for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor` 루프와 `mcp__`
  assert는 그대로 두었다 — 두 도구 추가가 그 루프를 통과하는지 GREEN으로 확인.

## [0.24.6] — 2026-08-03

### Changed
- `run_codex_reviewer.sh` · `run_artifact_codex_reviewer.sh`(qg) /
  `run_spec_codex_reviewer.sh`(spec-distill)에서 `-c 'model_reasoning_effort="medium"'`
  실행 인자 삭제. 하니스가 medium을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고,
  그 하향은 codex co-review의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
  `run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.
  **load-bearing 플래그는 그대로다** — `-s read-only`(샌드박스) · `-C`(작업디렉토리 핀) ·
  `--json`(파싱 계약) · `< /dev/null`(stdin detach).

### Added
- codex 러너 상한 부재 락(양방향) — 상한 재삽입과 샌드박스 제거 **둘 다** RED.
  한 방향만 재면 "상한만 사라졌다"를 증명하지 못한다.

## [0.24.5] — 2026-08-03

### Changed
- `spec-reviewer` · `coverage-mapper` · `blind-spot-prober` · `steelman-builder`의
  `model: sonnet` 리터럴 핀을 `model: inherit`으로 교체. **실측된 활성 손실이다** —
  지난 일주일 spec-review 6회가 전부 opus-5 세션에서 sonnet-5로 실행됐다(리뷰어가
  writer보다 약한 상태가 매 dispatch 재현). steelman-builder 1회도 같은 패턴.

### Added
- 네 에이전트 frontmatter 테스트에 **양방향 모델 락 신설** — 이전에는 `model:`에 대한
  assert가 아예 없어서 `haiku`로 강등해도 스위트가 GREEN이었다(신설 전 mutation으로 확인).
  positive(`inherit` 실재) + negative(고정 티어 부재) 둘 다 둔다.

## [0.24.4] — 2026-07-29

v0.24.3의 **자기 수정을 독립 리뷰**한 결과(리뷰어 5 + codex). 그 라운드가 만든 신규 결함과
못 닫은 경로를 고친다. 교훈 한 줄: **검증할 수 없는 것을 통과/차단으로 가르려 하지 말고,
검증하지 못했다는 사실을 사람에게 도달시켜라.**

### Changed
- **P21 placeholder 관여 시 판정을 포기한다 (`exit 3`).** v0.24.3은 `masked_contains`라는
  부분 매칭 술어를 도입해 "토큰이 덮는 span만 면제"하려 했으나, 리뷰어 4/4가 독립적으로
  CRITICAL 판정했다: 양끝이 암묵 와일드카드라 **누락 세탁**이 그대로 통과했고(`"브리프에
  <REDACTED:rest>"` → rc 0), 방향이 반전돼 원문에 맥락을 덧붙인 **정당한 payload를 새로
  차단**했으며, 토큰 개수가 무제한이라 in-order subsequence 검사가 되어 의미 반전이
  통과했다. 세 실패는 같은 함수의 양면이라 앵커를 어디에 걸어도 동시에 없앨 수 없다 —
  redaction 뒤를 알 수 없다는 것은 원리적 한계이기 때문이다. 술어를 제거하고, 이 경로의
  결과를 clean도 violation도 아닌 **검사 불가**로 통일했다. 원래 결함의 본질은 "통과했다"가
  아니라 **"강등이 조용했다"** 였고, `exit 3`은 호출자 rc 표에서 degradation record가
  **의무**인 행이라 Step B 사용자에게 반드시 도달한다.
- **Status 충돌 시 마지막 판정을 채택**하고 충돌은 advisory로만 올린다. v0.24.3의
  무조건 `needs_revise`는 `approved`를 **도달 불가**로 만들었다 — agent 파일 출력 형식 절에
  리터럴 Status 두 줄이 있어 critic이 자기 형식을 복창하면 매 라운드 충돌이 잡히고 재리뷰
  상한 2를 전부 태운다.

### Fixed
- **빈 원장이 "전건 검증 완료"로 집계되던 것** — `user_statements: []`면 루프가 0회 돌고
  `EXIT_OK`가 났다. 원장을 비우는 것만으로 L1·L2가 조용히 우회된다. 빈 전칭명제는 clean이
  아니다 → `exit 3`.
- **state 판독 실패가 payload 구조 위반을 선점하던 것** — 파싱 순서 때문에 state에서 키
  하나만 빼면 §6 앵커 중복(차단)이 검사 불가(계속)로 되돌아갔다. payload를 먼저 판다.
- **한국어 출력이 비-UTF-8 locale에서 exit 1을 내던 것** — `LC_ALL=C`에서
  `UnicodeEncodeError` → Python 기본 exit 1이고, 호출자 표는 1을 "위반 → 차단"으로 읽어
  멀쩡한 brief를 막는다. stdout/stderr를 UTF-8로 고정.
- **merge verdict가 보이지 않게 된 것** — v0.24.3이 exit code를 잡으려고 stdout을 파일로
  리다이렉트했는데 그 파일을 아무도 열지 않았다. 2-c는 `needs_revise → approved` 전이가
  일어나는 라운드다. `cat`을 되돌렸다.
- **codex 러너 `exit 3`이 라우팅되지 않던 것** — seed가 산출물을 **쓰지 못하면** 아무것도
  안 남기고 죽어, 막으려던 stale-YAML 경로가 그대로 재현된다. 호출 지점에서 rc 3이면
  잔존물을 제거한다. 러너 헤더의 "항상 exit 0" 계약도 실제와 맞췄다.
- **두 번째 degrade 채널이 재실행마다 truncate되던 것** — 변수를 정의하는 유일한 블록이
  동시에 `: >`로 비웠고, fallback 경로는 `$$`(PID)라 Bash 호출마다 달라 재발견이 불가능했다.
  경로를 세션의 순수 함수로 고정하고 truncate 대신 `touch`.
- **sentinel 블록 다중성 무가드** — 마지막을 조용히 채택하면 §6에 심긴 블록이 권위를 갖는다.
  마지막을 쓰되 판독 불가로 표시해 escalate시킨다.
- **직접 실행 시 신규 테스트 8개가 조용히 누락되던 것** — 클래스가 `if __name__` 가드 뒤에
  정의돼 `python3 test_x.py`가 23개 중 19개만 돌고 `OK`를 찍었다.

### Added
- **이빨 없던 자체 락 4종 교정** (전부 iter-2가 mutation으로 실증): BLOB catch-all이
  전체파일 `grep -c == 2`라 한 섹션에 둘 다 넣어도 통과 → 각 dispatch 지점 윈도우로 스코프 /
  MERGE 락이 bash **주석**만으로 충족 → 실행 라인·분기 본문 앵커로 교체 / C1 mutation이
  `def` rename의 `NameError`(exit 4)를 "세탁 통과"로 오독 → 호출 지점을 흔들고 **정확한
  기대값(exit 0)** 요구 / `**NOT**` 불릿 `-ge 2`가 3개 중 하나를 지워도 통과(맨끝이 Law 2
  역할 경계였다) → `-eq 3` / 빈 `SENTINEL_LIT`이면 `grep -qF ""`가 전부 매치해 가짜 PASS →
  추출 실패 시 FAIL / direction sentinel 추출이 tautology → 소비자 표기에서 뽑아 양방향 rename에 red.

## [0.24.3] — 2026-07-29

`/qg` 브랜치 리뷰(6 독립 리뷰어 + adversarial 선별)가 적발한 CRITICAL 4 + IMPORTANT 15 수정.
지배 원칙은 0.24.2와 같다: **`indeterminate ≠ clean`**. 이번 라운드가 더한 것은
**"강등이 사람에게 닿지 않으면 그것은 강등이 아니라 통과다"**.

### Fixed
- **P21 placeholder 한 토큰이 §6 원문 대조를 통째로 무력화하던 것** (CRITICAL) —
  `check_verbatim_coverage.py`가 `P21_PLACEHOLDER_RE.search()`로 **문자열 전체**를 훑어,
  어느 한쪽에 토큰이 하나만 있어도 그 statement의 L2 containment를 waive하고 EXIT_OK를 냈다.
  SKILL이 허용하는 유일한 §6 편집(P21 치환)이 곧 검사를 끄는 편집이 되어 append-only
  세탁방지가 우회됐다. 이제 **payload 쪽** 토큰은 자기가 덮는 span만 면제하고 나머지 문면을
  그대로 대조한다(`masked_contains`). **state 쪽** 토큰은 원 진실 자체가 미지이므로 기존
  강등을 유지한다 — 좁힌 것은 공격자가 통제하는 면뿐이라 정당한 redaction 3종은 무변경.
- **§6 앵커 중복이 "검사 불가"로 흘러 전 statement 검사를 끄던 것** (CRITICAL) —
  중복 `**S<N>**`이 `ParseError` → exit 3(degrade 후 계속)이었고, 중복 항목뿐 아니라
  **모든** statement의 L1·L2가 함께 skip됐다. 위임 대상이라던 `check_brief.py`는 §6 앵커를
  `set()`으로 모아 중복을 아예 보지 않으므로 그 위임은 실재하지 않았다. 신규
  `StructuralViolation` → exit 1(차단). 판독 실패가 아니라 규칙 위반이다.
- **확정 위반이 뒤 항목의 불확정에 밀려 강등되던 것** (CRITICAL) — `EXIT_INDETERMINATE`
  반환이 statement 루프 **안**에 있어 이미 누적된 `not_contained`를 버리고 rc 3으로 나갔다.
  판정을 루프 밖으로 옮겨 **위반 > 불확정** 순으로 결정한다.
- **비-UTF-8 payload가 빈 `<brief>` 디스패치로 새던 것** (CRITICAL) —
  `build_brief_inline_blob.py`의 `read_text()`가 try 밖이라 `UnicodeDecodeError`가 Python
  기본 **exit 1**로 나갔고, 호출 SKILL의 표는 0/2/3만 라우팅해 어느 분기에도 안 걸렸다.
  `BLOB`이 빈 문자열인 채 프롬프트에 보간돼 critic이 빈 문서를 리뷰하고 "왜곡 없음"을
  보고한다. 읽기 실패를 문서화된 exit 2로 매핑 + 두 호출 지점 표에 **catch-all 행** 추가
  (코드가 아니라 계약을 닫는다 — 다음 미지의 코드가 같은 구멍으로 새지 않도록).
- **rc-0 run의 advisory가 전량 폐기되던 것** — 검사는 *"이 발화는 대조하지 못했다"* 를
  advisory로 말할 수 있는데 rc 표 row `0`의 동작이 "1단계로"뿐이었다. record로 라우팅하는
  행이 3·4뿐이라 P21 강등 문구가 기록되자마자 버려졌다. row 0에 조건부 액션 추가.
- **`vc_rc` 차단 행이 서술뿐이고 실행형이 아니던 것** — 확정 §6 위반(exit 1)이 차단 없이
  can-redispatch → bump → 재리뷰로 흘러갔다. 바로 위 `gate_rc`와 같은 실행형 `if`로 교정.
- **merge 호출만 exit code 계약이 없던 것** — 그 stdout이 2-c 분기 전체가 읽는 verdict인데
  rc도 표도 없었다. `merge_rc` + **빈 출력**(잘린 write는 exit code로 안 잡힌다) 라우팅 추가.
- **두 번째 degrade 채널이 Bash 호출 간 소멸하던 것** — `$DEGRADE_FALLBACK`은 셸 변수인데
  `Bash` 도구는 호출마다 새 셸이다(유지되는 것은 cwd뿐, 실측). 재도출 가능한 값과 달리
  **누산기**라 매 append가 빈 값에서 시작해 Step B에서 비어 있었다 — 원장이 죽었을 때만
  작동하는 백업이 침묵하면 그 침묵이 곧 `degrade 없음`이다. 파일(`$DEGRADE_FALLBACK_FILE`,
  `>>` append)로 교체.
- **`skip_reason`을 버리면서 advisory 템플릿이 그것을 요구하던 것** + **direction 축에
  fail-closed 리더가 없던 것** — `codex_failed: true`가 "없는지"만 보면 부재·0바이트·잘림·
  직전 라운드 잔존이 전부 "정상"으로 읽힌다. `meta.codex_failed: false` **양성 요구**로 전환.
- **codex 러너의 stale YAML이 이번 라운드 판정으로 읽히던 것** — `OUTPUT_PATH`를
  선-truncate하지 않아 조기 exit·SIGKILL이 직전 라운드 산출을 남겼고, 호출자가 러너의 exit
  code를 잡지 않으므로 merge가 그것을 이번 라운드 codex 판정으로 읽었다(`codex_degraded:
  false` → approved, 흔적 0). fail-closed 산출물 **선-기록**(seed) 후 성공이 덮어쓰도록 전환.
- **critic의 first-match `**Status:**` / sentinel 파싱** — 형제 규칙
  (`codex_findings_to_yaml.py`: "last block defeats injected earlier blocks")의 정확한 역이었고,
  `brief-critic.md` 출력 형식 절에 리터럴 Status 두 줄이 디코이로 있다. §6(비신뢰 원문)이
  프롬프트에 inline되므로 주입 표면이기도 하다. 값이 다른 Status 공존 → **fail-closed
  needs_revise + advisory**, sentinel은 마지막 블록 채택.
- **degradation 원장만 값 검증이 없던 것** — 형제 두 키는 빈 값·열거 밖·비-digit에
  `ValueError`를 내는데 원장은 `[]`/`[ ]`만 특수 처리해 `null`·임의 스칼라가 빈 리스트로
  읽혔다(손상 원장과 깨끗한 run의 Step B 텍스트가 바이트 동일). `degrade-append`도 스칼라
  아래 splice + `{"ok": true}`를 냈다. 양쪽 fail-closed.
- **NG3 stale claim 세 번째 인스턴스** — `reviewing-spec/SKILL.md`가 현재시제로 "design doc만
  Law 2 분리 reviewer 대상"을 단언한 채 출하됐다. 회귀 락이 알려진 2개 경로를 하드코딩해
  세 번째를 구조적으로 볼 수 없었다 — **개념 별칭 스윕**으로 전환(식별자 grep은 같은 것을
  다른 이름으로 부른 참조를 놓친다).

### Changed
- design 문서 §6.3 teeth 표의 **거짓 ✅ 두 개를 ⚠️로 정정**. (1) zero-tool probe 분기는
  "런타임 — 저자도 리뷰어도 쓰지 않음"이라 적혀 있었으나 분기 앵커가 오케스트레이터가 쓸 수
  있는 audit 파일 한 줄이고 테스트도 기대값을 같은 줄에서 도출한다(협조적 flip = 스위트
  green). (2) merge 입력이 "리뷰어 findings — 저자가 쓰지 않음"이라 적혀 있었으나 critic이
  `tools: []`이라 전사는 저자가 한다. 둘 다 봉쇄 조건을 표에 함께 명시.
- Step B 전달 항목 4 → **5**: critic 원문 전문(`$CRITIC_OUT`)을 병합 결과와 나란히 올려
  사람이 전사본과 파싱된 판정을 대조할 수 있게 했다(검증 불가능한 프로즈 의무 → 확인 가능).

### Added
- 회귀 락 전부 **mutation으로 이빨 증명**: C1 마스킹 제거 → 세탁 통과, blob 읽기 가드 제거
  → exit 1 재발, codex seed 제거 → stale 생존, critic sentinel·`**Status:**`·`**NOT**` 불릿·
  direction sentinel 각각 rename/치환 → RED. 생산자 쪽 계약은 리터럴을 테스트에 박지 않고
  **소비자 코드에서 추출**해 대조한다(어느 쪽에서 rename해도 red).
- `test_brief_agents.sh`의 `grep -q "NOT"`이 **"NOTE"로 충족되던** 것을 마커 형태 + 열거
  크기 핀으로 교체하고 대상을 세 agent 전부로 확대(`brief-direction-reviewer` 본문은
  그동안 완전 무테스트였다).

## [0.24.2] — 2026-07-29

지배 원칙 하나: **`indeterminate ≠ clean`** — 돌지 못한 검사는 통과한 검사로 기록되지 않는다.

### Fixed
- **state 기록 실패가 "degrade 0건"으로 렌더되던 것** — `brief_review_state.py`의 쓰기
  서브커맨드는 state 부재·판독 불가·쓰기 불가·frontmatter 손상에 exit 1 + `{"ok": false}`를
  내는데 `reviewing-brief`가 그 종료 코드를 한 번도 보지 않았다. `init`이 실패하면 이후
  `degrade-append`가 전부 실패하고 마지막 `get`도 실패해, *"모든 degradation을 Step B에
  올린다"* 는 요구가 조용히 *"degrade 없음"* 으로 바뀐다. `init_rc` 캡처 + `$DEGRADE_FALLBACK`
  턴-내 사본 채널(§5.6이 요구하는 즉시 표면화의 나머지 절반) + `get` 실패를 *비어 있음* 과
  구분해 명시.
- **`check_verbatim_coverage.py`가 malformed 원장을 exit 0으로 통과시키던 것** — (a) `- id:`로
  시작하지 않는 리스트 항목은 통째로 무시됐고, (b) `text` 키 부재는 advisory 한 줄 뒤 success,
  (c) `text`가 비었거나 정규화 후 비면 역시 advisory 후 계속이었다. 셋 다 그 발화가 payload §6과
  **한 번도 대조되지 않았는데** 호출자는 0을 "위반 없음"으로 매핑한다. 셋을 exit 3(검사 불가)로.
  세 가드는 서로 겹치지 않게 갈랐다 — 겹치면 어느 쪽을 지워도 회귀 테스트가 green이라
  mutation으로 이빨을 증명할 수 없다.
- **방향성 축에 unavailable 경로가 없던 것** — 냉독은 빈 출력을 명시적으로 degrade하는데
  방향성은 `brief-direction-findings` 센티널 검증도 record도 없었다. 리뷰어가 죽고 codex #1도
  없는(kill switch·미설치·스키마 파손) 라운드에서 축 전체가 미검증인 채 원장이 침묵했다.
  냉독과 대칭인 결정론 검증 + `component: direction_reviewer` / `verification_status: unavailable`.
- **`can-redispatch`의 exit 1이 두 사실을 싣던 것** — escalate(상한 도달)와 `_fail`(state
  부재·손상)이 같은 코드다. 스킬의 `else`가 둘 다 escalate로 취급해, state가 죽었을 뿐인
  라운드에 *"재리뷰 상한 2 초과, 미해결 findings 잔존"* 이라는 사실이 아닌 record를 남겼다.
  실패 페이로드에 없는 `escalate` 키로 가른다.
- **웹 예산이 상한을 1회 넘겨 dispatch할 수 있던 것** — `check`는 `> 8`만 거부하므로
  `session == 8`에서 통과하고, dispatch 후 `increment`가 9를 만든다. `web_budget.py check
  --prospective`(`count + 1`로 평가)를 추가해 사전 게이트가 *"지금 하려는 이 호출이 예산에
  들어가는가"* 를 묻게 했다. 기존 `check` 계약과 `increment`의 bump-then-check는 무변경 —
  increment-before-dispatch로 이미 올바른 `conducting-interview` 호출자에 영향이 없다.
- **`inc_rc != 0`을 "카운터가 오르지 않았다"로 서술하던 것** — `increment`는 bump-then-check라
  예산 경계에서는 카운터를 **올린 뒤** 1을 낸다(기록은 성공). 그 상태에서 *"웹 예산 increment
  실패"* record가 Step B 질문에 렌더되면 거짓 degrade다. 1-a가 이미 쓰는 방식대로 JSON `reason`
  으로 갈랐다.
- **`build_brief_inline_blob.py`의 `\s`-개행 버그** — `^(key\s*:\s*)(.*)$`에서 `\s*`가 개행을
  넘어, 값이 빈 redact 키가 **다음 줄을 삼켜** 그 줄을 `<redacted>`로 갈아치웠다(실측: 빈
  `audit_file:` 다음의 `created_at:` 줄이 삭제). `check_brief.py`의 frontmatter 검증이
  `name`·`created_at`을 보지 않으므로 빈 `name:`이 구조 게이트를 통과한 뒤 한 줄이 지워진
  사본이 격리 critic에게 가는, 도달 가능한 경로였다. `brief_review_state.py`가 같은 클래스를
  두 번 닫았고 이 파일이 남은 하나였다 — 형제들과 같이 `[ \t]*`로.
- **핸드오프 invocation이 인자를 주석 안에서만 넘기던 것** — `Skill spec-distill:reviewing-brief
  # 인자: $PAYLOAD, …`. callee는 이 세 값을 스스로 정의하지 않는다고 명시하므로 호출은 인자
  없이 나간다. 인자를 호출 라인 위로 옮겼다.

### Changed
- **codex 추론 강도 핀 제거** — `run_brief_codex_reviewer.sh`가 `model_reasoning_effort="medium"`
  을 박아 사용자 codex 설정을 조용히 하향시켰다. `high`/`xhigh`로 설정한 사용자가 medium으로
  깎이고, 그 하향은 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 겨냥한다.
  하니스는 능력을 억제하지 않는다 — 이제 사용자 설정이 지배한다.
- **진입 승인 게이트가 상한을 말한다** — 2-c 재실행이 들어오면서 실제 천장은 에이전트 5 +
  codex 4인데, 사용자가 실제로 승인하는 `AskUserQuestion` 질문 텍스트는 하한(3 + 2)만 말했다.
  `cost_class: high` 게이트가 싣는 숫자는 상한이어야 한다. 하한/상한 표를 명시하고 호출자
  (`conducting-interview`)의 같은 주장도 동기화.
- **P21 placeholder 집합을 producer ↔ checker 합치** — `conducting-interview`가 예시로 드는
  `<REDACTED:라벨>`이 checker의 라벨 문자류(`[A-Za-z0-9._-]`)에 안 잡혀 정당한 치환이 hard
  violation으로 갔다. **checker 쪽을** 넓혀 맞췄다(`[\w.-]`) — 한국어 라벨은 이 리포의
  Korean-primary 규약상 정상이고 producer를 ASCII로 좁히면 규약과 싸운다. 넓힌 것은 글자
  종류뿐이고 공백·`<`·`>` 불가와 길이 상한 64는 그대로라, 산문을 라벨로 위장해 L2 비교를
  통째로 강등시키는 경로는 열리지 않는다.
- **README가 코드를 따라잡았다** — `## Flow (v0.24.0)`으로 버전만 올라가고 다이어그램은
  brief를 Step B로 직행시키고 있었다. 리뷰 3단계를 다이어그램에 그리고, 붙을 리스트가 없던
  `5.5.` 고아 번호를 형제와 같은 버전 노트 문단으로, `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`
  항목에 brief 파이프라인 호출 지점 3곳(1-c · 2-b · 2-c)과 호출자-게이트 규약을 명시.
- **회귀 락 하드닝(teeth)** — 이번 wave가 추가·수정한 assert 32개 전부 mutation으로 이빨을
  확인했다(각 assert를 red로 만드는 단일 편집 수행 → 확인 → 바이트 동일 복원). 주요한 것:
  README 락이 컴포넌트 이름을 섹션 전체에서 찾아 **다이어그램을 통째로 지워도 산문으로
  충족**되던 것을 펜스 안 다이어그램 순서 락으로 교체. 핸드오프 인자 락이 `#` 뒤 텍스트를
  세어 **주석을 보호하며 green**이던 것을, 같은 사이클이 만든 따옴표-상태 스캐너에 마커
  인자만 추가해 재사용하는 방식으로 교체(두 번째 스트리퍼 금지). §6.3 열거표는 스스로
  *"기계가 열거 완전성을 본다"* 고 적어놓았지만 그 기계가 없어서(리터럴 4개 존재 확인뿐)
  실제 열거 대조를 구현했고, 표에 행이 없는 shipping 체크 2건을 **선언된 gap 목록**으로
  리포에 박았다(아래 Known gaps).
- **테스트 위생** — 픽스처 `.replace()`가 조용히 no-op이 되면 시나리오가 뒤바뀌어도 green이던
  것을 `sub1()` 치환-확인 헬퍼로 봉쇄. `test -f … || note FAIL` 가드가 정상 경로에서 note를
  안 불러 출력 Total이 조건부이던 것, 두 섹션 캡처를 구분자 없이 이어붙이던 것, 실패 메시지에
  이스케이프된 정규식이 그대로 찍히던 것을 수정. `scoped_window()`/`fence()`가 패턴을 `awk -v`로
  넘겨 `\[`·`\$`가 뭉개지던 것(지금 패턴이 `\.`뿐이라 **우연히** 무해했다)을 `ENVIRON`으로 통일.
  `codex_findings_to_yaml.py`의 `meta` 추론 타입을 `dict[str, object]`로 명시.

### Known gaps
- 설계 문서 §6.3 결정론 체크 열거표에 **행이 없는 shipping 체크 2건**:
  `build_brief_inline_blob.py`의 exit-3 잔존 검사, `brief_review_state.py`의 닫힌 열거 검증 ·
  rounds clamp · `can-redispatch` 게이트. 특히 후자는 통과 조건(`brief_critic_rounds`)을
  **orchestrator 자신이 쓰므로** 표가 존재하는 이유인 범주에 해당하고, 이빨 등급 판정은 기계가
  못 한다. 설계 문서 수정은 사람 몫이라 이 사이클에서는 문서를 건드리지 않고
  `test_brief_review_meta.sh`의 `DESIGN_GAP` 선언으로 gap을 greppable·강제 가능하게만 만들었다
  — 새 체크가 표 없이 들어오거나, 표에서 행이 사라지거나, 사람이 표를 채운 뒤 waiver를
  안 비우면 전부 red다.
- `merge_review.py`(design-doc 리뷰 경로, 이 브랜치 밖)가 `codex_failed: true`인 라운드에서
  파싱된 codex findings를 **전량 폐기**한다. mixed 라운드(정상 finding 1 + malformed 원소 1)에서
  `combined_verdict: approved` + degrade advisory만 남고 `severity: high` finding이 사라지는 것을
  실측했다. `merge_brief_review.py`(brief 경로)는 이미 findings를 보존한 채 degrade 마커를 함께
  낸다 — 남은 격차는 공유 경로 한 곳이다. blast radius가 이 브랜치 밖이라 미변경.

## [0.24.1] — 2026-07-29

### Fixed
- **`DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1`이 충실도 축에서 무시되던 것** — `reviewing-brief`의
  가용성 게이트가 1-c 방향성 호출만 감쌌고, 2-b 충실도 호출과 2-c 재실행 호출은 무조건
  실행됐다. 러너는 이 변수를 보지 않으므로(호출자-게이트 규약) `cost_class: high` skill에서
  사용자의 명시적 opt-out이 무시된 채 외부 모델에 지출이 나갔고, 1-c가 남기는
  `affected_axis: all` record가 거짓이 됐다. 세 지점을 모두 같은 `$codex_avail`로 게이트한다.
  skip 라운드에도 병합은 그대로 돌아 `codex_degraded: true`로 loud하게 보고하므로 kill switch가
  강제 수정 루프로 바뀌지 않는다. 2-b의 `codex_degraded` record에는 `codex_avail == true`
  전제를 달아 skip의 결과에 중복 record를 남기지 않는다.
- **구조 게이트 실패 분기가 차단하지 않던 것** — 2-c의 `gate_rc != 0` 분기가 하던 일은
  `exit_reason=` 변수 대입 하나였고 그 변수를 읽는 곳은 리포 전체에 0곳이었다. 분기는 그대로
  흘러내려 완전성 검사·`can-redispatch`·`bump-critic-round`·재dispatch를 전부 실행했다.
  서술은 차단이라고 단언했으므로 문서가 shipping보다 강했다. `exit 1`로 실제 정지를 넣었다.

### Changed
- **회귀 락 하드닝(teeth)** — 이빨 없이 green이던 assert들을 교체했다. codex 호출 락은 축별로
  세고(방향성 ≥ 1 · 충실도 ≥ 2 — 합산 하한 2는 재실행이 3번째 호출이 된 순간 방향성 호출을
  통째로 지워도 green이었다), 구조 게이트 락은 분기 **본문**의 정지 동작을 요구하며, codex
  재실행 락은 존재에 더해 **순서**(게이트 → `can-redispatch` → 재실행 → 재병합)와 `can == 0`
  분기 내 포함까지 본다. 실행 라인이 주어인 assert는 전부 줄-시작 앵커로 바꿨다 — 같은 문구를
  실은 산문 한 줄로 satisfiable했다. `run_brief_codex_reviewer.sh` 호출 3개가 전부 게이트
  본문 안에 있는지 세는 락을 새로 추가했다.
- `test_brief_review_entry.sh`의 `strip_trailing_linecomment()`가 문자열 경계를 줄의 마지막
  따옴표로 잡아, 트레일링 코멘트가 따옴표 쌍을 품으면 통째로 no-op이었다. 왼쪽에서 오른쪽으로
  훑는 따옴표-상태 스캔으로 교체(`\"` 이스케이프 존중, `"`·`'`·`` ` `` 세 종류).
- 락의 들여쓰기 강제(`^[[:space:]]+`)를 완화(`*`) — 호출이 살아 있는데 dedent만으로 RED가
  나던 false-red였다.

## [0.24.0] — 2026-07-27

### Added
- **brief 리뷰 파이프라인 (Law 2 분리 리뷰)** — `skills/reviewing-brief/`가 3단계를 돌린다:
  방향성(Claude + codex, 보고만) → 충실도(격리 critic + codex, fail-closed 합집합) → 냉독.
  Spec A(v0.23.0)가 *"신규 에이전트 0개 — 리뷰 파이프라인은 후속"* 으로 미룬 것이다.
- `agents/brief-critic.md` — 충실도 리뷰어. payload **전문 inline**(경로 미제공),
  `audit_file`·`name`·`created_at` redact. `category` 6종(`distortion`/`omission`/`insertion`/
  `provenance_mislabel`/`authority_syntax`/`evidence_unsupported`)을 각각 점검한다.
- `agents/brief-direction-reviewer.md` — 방향성 리뷰어. repo + 웹. **판정이 아니라 질문**을
  낸다(각 finding에 사용자가 결정할 질문 1개 필수 — C4가 사문이 되지 않게).
- `agents/brief-readback.md` — 냉독. 출력 스키마·판정 기준을 **주지 않는다**(형식이 오염원).
- `scripts/check_verbatim_coverage.py` — payload §6 ↔ state `user_statements` 대조(L1/L2).
  정규화 N1–N5(순서 고정, **NFC**), exit `1` 위반 / `3` 검사불가 / `4` 내부오류로 분리.
- `scripts/brief_review_state.py` — state 키 3개 소유. 재리뷰 상한 2 경계값(`== 2` escalate),
  도달 불가 값 clamp, degradation record 4필드 닫힌 enum.
- `scripts/merge_brief_review.py` — 충실도 fail-closed 합집합. codex는 **binding**이며 단독으로
  verdict를 만든다. `codex_isolated: false`는 저자용 라벨이고 verdict 입력이 아니다.
- `scripts/build_brief_codex_prompt.py` + `brief-codex-{direction,fidelity}-checklist.md` +
  `run_brief_codex_reviewer.sh` — codex 축별 2회. **코드 1곳 + 데이터 2곳.**
- `scripts/build_brief_inline_blob.py` — critic·readback 공용 redacted blob.
- kill switch `DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW=1` — 파이프라인 전체 skip + record.

### Changed
- `conducting-interview` Step A.5로 리뷰 파이프라인 진입(한 블록). Step B 게이트가 산출물 4종과
  **모든 degrade record를 question 텍스트에** 싣는다 — 사용자가 옵션을 고르기 *전에* 본다.
- **NG3 서술 교정**(`check_brief.py` docstring · `agents/spec-reviewer.md`): *"brief는 분리 리뷰를
  받지 않는다"* 가 이 버전으로 거짓이 됐다. 게이트는 여전히 Law 1이고 그 위에 Law 2가 얹혔다.
- `templates/interview-audit-template.md` §4·§5에 리뷰 라운드 텔레메트리 — **기록이며 게이트
  통과 조건이 아니다**(검사 대상이 통과 조건을 직접 쓰는 검사는 이빨이 없다).
- P21 치환 토큰을 `<REDACTED>` 계열로 못 박았다 — producer와 checker가 같은 집합을 봐야 L2
  advisory 강등이 발화한다.

### Security
- 신규 에이전트 3개 전부 fail-closed `tools:` allowlist, 쓰기·실행·위임 도구 **0개**(Law 2).
  `model:`은 전부 `inherit`(리터럴 핀 금지 — 세션이 더 강한 모델일 때 downgrade 방지).
- 격리는 **zero-tool probe 이진 분기**로 성립한다. probe 통과 시 `tools: []`로 도달 경로가
  물리적으로 없고 충실도가 hard gate. 실패 시 `tools: Read` + 충실도 **advisory 강등** +
  record 2건 + D2 미충족 사용자 보고 — 보장되지 않는 격리 위에 hard gate를 얹지 않는다.
  실측 기록: `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md`.
- **훅 0개 추가** — `hooks/` 파일 집합과 `hooks.json`이 무변경이다.

## [0.23.0] — 2026-07-26

### Added
- **brief 2파일 계약** — payload(`<topic>-interview.md`, 8섹션 역피라미드)와 audit
  (`<topic>-interview.audit.md`, 5섹션 텔레메트리)로 분할. payload frontmatter의 `audit_file`
  (basename만 — traversal 거부)이 audit을 가리키고, 게이트가 두 파일을 함께 검사한다.
  audit 부재·미해석은 fail-closed.
- `templates/interview-audit-template.md` — Coverage Ledger / Budget / Steelman 원문 /
  게이트 실행 기록 / 프로세스 로그.
- **frontmatter `user_sourced_items[]` 계약** — `id`/`source`(`verbatim`|`chosen`)/`status`
  (`confirmed`|`provisional`|`open`)/`statement`(160자 hard cap)/`evidence`(`S<N>`, 필수).
  `source: inferred`는 이 리스트에 들어갈 수 없다 — 모델 추론은 본문 ✎ 프로즈로만 산다.
- **audit 페어링 검사(`session_id` 바인딩)** — audit이 *이 payload의* sidecar인지 확인한다.
  `audit_file`만으로는 basename이 같은 디렉토리에 존재하기만 하면 통과해서, payload가 **다른
  인터뷰의 audit**을 가리켜 그 §1 Coverage Ledger(Law 1 종료 판정의 근거)를 상속할 수 있었다 —
  끝나지 않은 인터뷰가 `audit_file` 한 줄만 바꿔 exit 1에서 exit 0이 됐다. 결합은 파일명이 아닌
  `session_id` 동등성 + audit `type`으로 건다.
  1차 방어는 **이름 유도**다 — `audit_file`은 `<payload stem>.audit.md`여야 한다. 신뢰하지 않는
  값을 검증하는 대신 아예 받지 않는 쪽이다: payload가 자기 audit을 고를 수 있는 한, 세션 id
  동등성만으로는 부족했다(`SKILL`이 세션 id 재사용을 규정해 한 세션의 두 인터뷰가 같은 id를
  가지므로 *동일 세션* 차용이 그대로 통과했다 — 실측 exit 0). `session_id`/`type` 검사는 파일
  이동·개명에 대한 2차 방어로 남는다. 3차 방어는 audit이 스스로 선언하는 **`payload:` 역참조**다 —
  이름 유도는 *어느 파일을 읽을지*만 고정하므로, 남의 audit **내용**을 유도 경로에 복사해 넣으면
  그대로 통과했다(실측 exit 0). 이 필드는 두 템플릿과 모든 fixture가 이미 담고 있으면서 아무도
  읽지 않던 것이다 — 선언만 있고 읽는 코드가 없으면 계약이 아니다.
- **web 킬 스위치 완화를 advisory로 알린다** — `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`은 §4 인용
  요구와 §5 verdict URL 요구를 동시에 완화해 같은 brief를 red에서 green으로 바꾸는데 지금까지
  아무 흔적도 남기지 않았다(이전 세션의 export가 남아 있으면 이후 모든 brief가 이유 없이 통과).
  CLAUDE.md의 loud-degradation 요구. `gate`는 advisories JSON으로, `_web_disabled()`가 결과를
  바꾸는 나머지 서브커맨드(`landscape-citations`·`skepticism`)는 stderr로 알린다 — stdout은
  JSON 계약이라 섞으면 소비자 파싱이 깨진다.
  부재도, **중복 키도** 불일치와 동일하게 red — 못 읽은 값을 일치로 간주하거나 모호한 입력에서
  값을 하나 골라주면 이 검사 자체가 fail-open이 된다(첫 매치만 쓰면 남의 audit 맨 앞에 맞는
  `session_id` 한 줄을 얹어 바인딩을 우회할 수 있다). frontmatter 키-값 구분자는 `\s*`가 아니라
  `[ \t]*`다 — `\s`는 개행을 포함해 값이 빈 키가 **다음 줄 토큰을 값으로 포획**하고, payload와
  audit이 둘 다 `session_id`를 비우면 양쪽이 똑같이 아래 `source:`로 읽혀 페어링이 상수로
  붕괴했다. `audit_file`·`type`도 같은 모양이라 셋을 함께 고쳤다.
- **세 bijection** — A: payload §5 `ST<N>` ↔ audit §3 `#### ST<N>`(양방향, 공집합 허용) /
  B: body §2 ↔ frontmatter(id·기호·status·`⟨S<N>⟩`·**statement 내용**까지) /
  C: 모든 `evidence: S<N>`가 payload §6에서 해석됨.
- **종료 확정 확인** — proceed 게이트에 흡수(상호작용 1회 유지). 재제시 상한 2회, 초과 시
  전 항목 `provisional` 강등 + 고정 advisory.
- 분량 지표 `payload_body_lines_excl_verbatim`(§6 제외) — 150 초과 시 advisory, **fail 안 함**.
- `check_brief.py items` / `metrics` 서브커맨드.
- `tests/test_stale_terms.sh` V8 — 권위 문법 6개 리터럴 회귀 락 + mutation 이빨 증명.
- **AC12 sentinel 앵커링** — `confirmed` 0건 brief는 `# confirmed 0건 — 사용자가 전부 잠정으로
  판단`이 **한 줄 전체**로 frontmatter에 있어야 통과한다. 다른 문장 안에 인용된 같은 문자열
  (템플릿 안내 주석, `statement` 값 등)은 sentinel이 아니다 — substring 검사였다면 템플릿대로
  만든 brief가 확인-게이트 우회 검출을 통째로 우회했다.

### Changed
- **라운드별 잠금 producer 제거** — 매 round 끝 `locked?` decision table이 사라지고,
  판정 없는 `user_statements`(`{id: S<N>, source, round, text}`) 기록으로 대체. `status`도
  해답공간 `section:` 앵커도 붙이지 않는다. 과거 brief의 LD 9/6/5는 모델의 과잉 잠금이 아니라
  skill이 지시한 대로 동작한 결과였다.
- brief 템플릿을 8섹션 역피라미드로 재작성 — 행동 항목(제약·Open Questions)이 앞, 근거·원문이
  뒤. 사용자 원문은 §6에 전문 보존(허용 변환은 P21 placeholder 치환·공백 정리·인용 래핑뿐).
- Coverage Ledger 검증이 payload §6 → audit §1로 이동.
- `user_sourced_items[]` 항목 필드도 값 뒤 YAML 인라인 주석(`status: provisional  # …`)을
  떼어낸다 — `audit_file`과 같은 규칙(같은 frontmatter를 두 규칙이 반대로 읽던 불일치 해소).
  따옴표 스칼라 안의 `#`는 값의 일부로 보존한다. 블록 안의 주석 줄도 항목 파싱을 끊지 않는다.
- R4 통과 의례가 payload §5 `기각` 항목 문법으로 이관 — 0건이면 명시 N/A sentinel 없이 fail.
- **섹션 항목 추출이 `-`와 `*` 불릿을 모두 받는다** — body §2를 읽는 `BODY_ITEM_RE`는 `[-*]`를
  받는데 §4·§5·audit §1을 읽는 `_entry_lines`는 `- `만 받아, 같은 아티팩트를 두 규칙이 다른
  관례로 읽었다. §4에 인용된 `-` 항목과 인용 없는 `*` 항목을 함께 두면 `landscape_present`는
  만족되고 `landscape_uncited`는 `*`를 못 봐서 R2의 "출처 URL 필수"가 불릿 한 글자로 우회됐다.
- `/compact` 핸드오프 문구가 새 섹션명을 가리키고 **C4 재결정 프로토콜**을 함께 싣는다.
  직행 경로(옵션 ②)의 호출 프롬프트에도 같은 문장이 실린다 — 규약은 brief가 아니라
  호출 프롬프트에 산다(C5).
- `agents/{blind-spot-prober,steelman-builder,coverage-mapper}.md`의 Input 절이
  `locked_directions` 대신 "사용자 제약 요지"를 받는다.

### Removed
- frontmatter `locked_directions[]` 및 state `pending_locked_decisions[]`.
- brief §2 *"Locked Directions"* 섹션과 *"재논쟁 금지"* 헤더 문구.
- `check_brief.py`의 `steelman_unlogged()` — frontmatter `steelman:` 라벨이 사라져 죽은 코드가
  됐고, 그 보장은 bijection A가 이어받는다.

## [0.22.0] — 2026-07-21

### Added
- **커버리지-구동 인터뷰 재구성** — 종료 driver를 고정 `interview_round` 카운터에서 미지-차원
  커버리지 원장(고정 floor 5 + 주제-도출 차원, 각 status ∈ {open, in-progress, closed})으로 교체.
  집요함·깊이·차원이 주제에 적응한다(길이 아님).
- `scripts/probe_budget.py` — Unbounded-autonomy 백스톱(check/increment/raise-cap; base_cap 12 +
  probe_cap_override; env `DEVBREW_SPEC_DISTILL_PROBE_CAP`). `web_budget.py` sibling, mutation-testable.
- `agents/blind-spot-prober.md` — blind_spot floor 차원을 구현하는 적대적 premortem 에이전트
  (read-only, fan-out 1, hidden_assumptions/failure_modes 출력).
- brief 템플릿 §5 Blind Spots & Premortem + §6 Coverage Ledger 신규 섹션. `check_brief.py`가 원장 form
  (floor all-closed + evidence non-empty + derived)을 게이트.
- teach-beat — 모든 probe teach-lite(≤1문장) + 열거 신호 시 teach-heavy(≥1 URL/prior-art 인용). 발화
  시점은 model-judged(C12, 결정론 미기계화).

### Changed
- `agents/breadth-keeper.md` → `agents/coverage-mapper.md` 재명명·재목적화 — tunneling 검출에서
  주제-도출 차원 advisory 제안자로 승격(원장 admit 판정은 orchestrator, Law 2). `coverage-mapper`
  dispatch 트리거를 `interview_round >= 2`에서 C11 커버리지 조건(연속 3 probe 무진전 OR floor 첫
  open→in-progress) + redispatch 바운드로 교체.
- `skills/conducting-interview/SKILL.md` — 상태 스키마(interview_round 제거, coverage/probe_count/
  probe_cap_override/orchestration 추가), 종료 게이트(floor all-closed), probe 백스톱 호출, rhythm-guard
  probe 재프레임, in-flight 마이그레이션(구세션 fresh seed).
- `agents/steelman-builder.md` — description 용어 'breadth-keeper' → 'coverage-mapper'(terminology-only).

### Security
- 신규/변경 에이전트(coverage-mapper·blind-spot-prober)는 `tools:` allowlist fail-closed(Write/Edit 물리
  부재) — Law 2 read-only 불변. probe 백스톱은 기계적 집행(프로즈 self-tracking 아님).

## [0.21.0] — 2026-07-19

### Changed
- **agent 3종(`spec-reviewer`·`breadth-keeper`·`steelman-builder`)을 `tools:` allowlist 로 전환** (fail-closed). 이전에는 denylist 만으로 격리돼 `Agent`·`Bash`·모든 MCP 도구를 보유했다 — denylist 는 공간(열거 누락)뿐 아니라 **시간에 대해서도 fail-open** 이다(내일 추가될 도구는 오늘 열거할 수 없다).
- 목록은 **트랜스크립트 census 실측**으로 도출했다. `spec-reviewer` 는 persona 가 한 번도 지시하지 않는 `Bash` 를 45회 부르고 **선언에 없는 `WebFetch`** 로 공식 문서를 가져와 검증한다 — persona 독해로 만든 목록은 안 쓰는 도구를 주고 쓰는 도구를 뺏었을 것이다.
- 죽은 `allowedTools` 키 제거 (`spec-reviewer`·`steelman-builder`) — 공식 subagent 규격의 필드가 아니라 무시된다.

### Added
- `spec-reviewer`·`breadth-keeper` 도구 표면 회귀 락 신설 — 가장 많이 dispatch 되는 리뷰어인데 락이 없었다.

## [0.20.0] — 2026-07-15

### Added
- **codex 병렬 독립 co-reviewer (Phase 3 design-doc 리뷰)** — model diversity를 quality-gates code-review에서 spec-distill의 design-doc 리뷰로 이식. `reviewing-spec`가 Claude `spec-reviewer`와 나란히 codex를 독립 실행하고, `scripts/merge_review.py`(결정론 merge/ledger 엔진)가 **보수적 병합**(precedence `needs_interview > needs_revise > approved`)으로 두 verdict를 합친다 — codex가 Claude의 approved를 needs_revise로 뒤집을 수 있다(fail-open 포착). codex는 `codex exec -s read-only` OS 샌드박스(Law 2 구조적).
- `scripts/detect_codex.sh` (vendored) — codex 가용성 감지. kill switch `DEVBREW_DISABLE_SPEC_DISTILL_CODEX`.
- `scripts/build_spec_codex_prompt.py` — design-doc 전용 codex 프롬프트(6 판단형 category, path-only 입력, severity vocab `block|high|medium`).
- `scripts/run_spec_codex_reviewer.sh` — 독립 codex subprocess(**discover-spec.sh AC 주입 없음** — 순환 footgun 회피, C3; mktemp C7 가드).
- `scripts/codex_findings_to_yaml.py` (vendored) — codex JSONL→YAML, emit 키셋에 `category`/`target_section` 추가.
- `scripts/compute_issue_id.py` — 중앙화 issue_id helper(`sha256_short(category + ":" + target_section)`). 두 리뷰어 이슈 모두 여기로 — cross-reviewer collision integrity.
- `scripts/merge_review.py` — 결정론 merge/ledger 엔진: 양쪽 출력 스크립트 파싱(LLM 전사 없음), verdict 유도, 보수적 병합, 4-branch degrade 계층(sentinel/`**Status:**`/codex-alone/fail-safe), 통합-원장 stagnation 스캔.
- tests: `test_detect_codex.sh`, `test_build_spec_codex_prompt.sh`, `test_codex_findings_to_yaml.py`, `test_compute_issue_id.py`, `test_run_spec_codex_reviewer.sh`, `test_merge_review.py`, `test_reviewing_spec_codex_merge.sh` + codex mocks.

### Changed
- `skills/reviewing-spec/SKILL.md` — ⟦detect⟧/⟦review-codex⟧/⟦merge⟧ 스텝 추가, "Stagnation detection" 절을 merge_review의 **통합-원장 스캔 flag**로 재작성(codex-only 반복 이슈 escalate; Claude self-report는 보조 신호). combined_verdict를 기존 routing table에 투입(표 불변). C8 verbatim `--claude-output` 저장.
- `agents/spec-reviewer.md` — issue를 **sentinel-fenced JSON block**(` ```spec-review-issues `, category/target_section/severity/message)으로 emit + top-level `**Status:**` verdict 라인 유지. issue_id self-report 제거(compute_issue_id가 계산). codex 존재 blind 유지.

### Security
- 두 리뷰어 모두 write-denied(codex `-s read-only` 샌드박스 + Claude disallowedTools), 리뷰 pass 상호 blind. codex 부재/실패는 fail-open(조용한 통과)도 fail-closed(spurious block)도 아닌 loud degrade.

### Fixed
- **fail-closed 하드닝 (`/qg` self-dogfood iter-1 적발; codex+silent-failure 모델다양성이 whole-branch·code-reviewer가 놓친 verdict-path fail-open 수렴 적발)** — `merge_review.py` 3건: (1) `parse_codex_yaml`이 opt-in-to-failed였음 — 존재하지만 비어있는/절단된 codex YAML(외부 SIGKILL/OOM/disk-full로 `OUTPUT_PATH`가 0-byte)이 `codex_failed` 마커 부재 시 **성공한 빈 리뷰로 오인** → advisory 없이 `approved`로 silently 통과(다른 모든 degrade 경로가 올리는 human-gate advisory backstop 무력화). opt-in-to-success로 반전 — **정확히 하나의** exact `true`/`false` 마커만 신뢰(부재·empty·garbage value·**중복 마커** 모두 fail-closed degrade + partial findings 폐기; `failed`는 sticky-True로 마커 순서 무관). isfile() 통과 후 open 실패(permission/TOCTOU/vanished)도 uncaught OSError crash가 아닌 loud degrade(`codex_yaml_unreadable`, `load_history` 가드와 대칭). (2) `derive_codex_verdict`가 off-vocab/missing severity(LLM drift `"critical"`/`""`)를 **approved 방향으로** 흘려보냄 → `CODEX_SEVERITY_KNOWN` 도입, 인식 불가 severity는 escalate(`medium`만 non-escalating 유지, §8). (3) `_write_history` `except OSError: pass`가 silent였음 → bool 반환 + 실패 시 loud advisory(원장 기록 실패 = cross-round stagnation degraded 명시) + orphan `.tmp` 정리. 3건 모두 mutation-test로 이빨 검증.
- `emit()` codex_findings 표시 블록 + degrade advisory가 `ensure_ascii=True`로 한국어를 `\uXXXX` escape → `ensure_ascii=False`로(Korean-primary 충실성, sibling `check_brief.py` 선례).
- `build_ledger`의 미사용 `codex_avail` 파라미터 제거(원장이 codex-availability-aware라는 오해 신호 + Pyright dead-param).

## [0.19.0] — 2026-07-05

### Fixed
- **review-lock session-id split → Stop 재강제 루프**: `reviewing-spec` 스킬이 리뷰 락·suppress·approve 를 **interview UUID** 로 keyed 했으나 훅(Stop/UserPromptSubmit/PostToolUse)은 **harness sid**(`resolve_session_id` env-first)로 상태를 읽어, 두 파일이 갈려 `is_review_active` 가 락을 못 찾고 `False`(fail-safe = 강제)를 반환 → v0.18.0 이 막으려던 subagent-경계 Stop 재강제가 **인터뷰-선행 플로우에서 여전히 발생**했다(harness sid 는 `/compact`/resume 에서 drift, interview UUID 는 stable). `reviewing-spec/SKILL.md` Step 1 이 `state_path.py session-id` + `state-root` 로 상태 파일을 명시 해석하고 세 hook-facing 호출 지점(락 `set`·`pause`, `approve_handoff.sh`)에 `$harness_sid` 를 넘겨 락·suppress·approve 가 훅이 읽는 파일에 기록되게 한다(read==write 디렉토리 불변식). approve 후 같은 design 재편집 시 재-arm 도 함께 해소(suppress 대칭 복원). `cancel_review.py`·`approve_handoff.sh`·`review_lock.py` 는 무변경(각각 이미 harness sid 이거나 sid passthrough). continuity(`rereview_count`/`issue_history`)는 harness-sid 로 collapse 하지 않아 인터뷰-선행 re-review cap/stagnation 을 보존(N1).

### Added
- `hooks/state_path.py` — `session-id` CLI 서브커맨드: env-only `resolve_session_id(None)` 결과를 stdout 에 print(exit 0), 미해석 시 stdout 무출력 + exit 1. 스킬과 훅이 *정의상 동일한* sid 를 얻는 단일 진입점(DRY 리졸버).
- `tests/test_review_lock_session_id.sh`(T1 behavioral 훅 repro) + `tests/test_reviewing_spec_lock.sh`·`tests/test_session_id_resolution.sh`·`tests/test_cancel_review.py` 회귀 락 확장(세 지점 mutation POS/NEG + degradation exact-literal + continuity non-collapse + cancel_review env-resolver 계약).

## [0.18.0] — 2026-07-02

### Added
- `scripts/review_lock.py` — **document-keyed(multi-key) `review_in_progress` 락**의 단일 소스. `set_lock`(그 키 엔트리 upsert/refresh, 나머지 보존)·`clear_lock`(그 키만 제거)·`pause`(clear + 같은-키 pending strip, suppress 없음 — resumable)·`is_review_active(body, pending_key, now, ttl)` + `{set|clear|pause}` CLI. 원자적 write(flush+fsync), stale prune, kill switch. `canonical_key`는 `suppress_state`에서 import(단일 정규화 소스).
- state.local.md `review_in_progress:` 엔트리 리스트(`suppressed_paths`와 동형) + `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` env(default 1800).
- `tests/test_review_lock.py`(유닛+CLI), `tests/test_reviewing_spec_lock.sh`(SKILL teeth 락).

### Changed
- `hooks/review-dispatch.py`(Stop) + `hooks/pending-review-reminder.py`(UserPromptSubmit) — suppress 체크 뒤·TTL 가드 앞에 `is_review_active` 게이트. 이 문서 락이 신선하면 no-op(pending 보존), 엔트리 부재/stale/파싱·import 예외면 정상 dispatch(fail-safe = 강제, Law 1). 다른 문서의 신선 엔트리는 pending_key 조회라 이 문서를 억제하지 않음(AC16).
- `skills/reviewing-spec/SKILL.md` — Step 1(매 진입)에서 `review_lock.py set`으로 그 문서 엔트리 refresh + Phase 5 옵션↔락 매핑표(①②=`approve_handoff.sh` clear, ③=재진입 refresh, ④=`review_lock.py pause`).
- `scripts/approve_handoff.sh` — suppress와 함께 `review_lock.py clear` 호출(그 문서 엔트리만). `scripts/cancel_review.py` — 취소 문서 키 엔트리 `clear`(approve 대칭, AC11).

### Fixed
- **subagent 경계 Stop 재발동**: `reviewing-spec`가 `spec-reviewer`를 async dispatch하고 await하려 턴을 멈출 때 발생하는 메인 `Stop`이, revise로 재-arm된 pending을 집어 리뷰를 (A) 중복 강제 / (B) 흐름 절단하던 오발. 문서별 락으로 "그 문서 리뷰 진행 중"을 표현해 봉쇄하되 리뷰 강제 계약(Law 1/2)은 100% 보존. 인터리브 2-문서 리뷰에서도 각 문서 보호 유지(multi-key, 한 문서 set이 다른 문서 락을 clobber 안 함).

### Removed
- `scripts/approve_handoff.sh`의 dead `git_common_dir`/`main_repo` 블록(v0.14.0에서 `rm -rf` 제거된 뒤 미사용).

## [0.17.0] — 2026-06-17

### Removed
- 인터뷰 월클락 메커니즘 **완전 제거**: `wall_clock_started_at` state 필드(conducting-interview schema) + reviewing-spec `## Steps` item 2의 wall-clock 체크(구 AC14) + Step 1 reader + `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var(양쪽 SKILL kill-switch + README) + README AP16 라인의 `wall-clock 30min` 토큰. 시계가 인터뷰 시작 시 켜지고 re-review 루프에서 트립해 *agent 자율성이 아니라 사람의 숙고 시간*을 오측정하던 footgun이었다 — AP16의 load-bearing 가드는 같은 루프의 re-review hard cap(5) + round-level stagnation early-exit이므로 월클락은 중복(redundant) 4번째 바운드였다. 구 세션 state의 잔여 `wall_clock_started_at` 키는 reader 부재로 무해하게 무시됨(migration 코드 불필요 — forward-compatible). harness-lightness(결정론은 load-bearing 게이트에만) + qg v2.0.0 월클락 budget 제거 선례에 정합. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Added
- `tests/test_no_wall_clock.sh` — 월클락 토큰(`wall_clock_started_at` / `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` / `wall-clock`) 재도입 방지 회귀 락. 라이브 surface 3파일(conducting-interview SKILL, reviewing-spec SKILL, README) 스캔, CHANGELOG는 history 보존이라 제외. v0.16.0 `test_hooks.sh` regression-lock 선례 패턴(repurpose 아닌 신규 파일).

### Changed
- `tests/test_readme_sync.sh` — 버전 기대값 0.16.0 → 0.17.0.

## [0.16.0] — 2026-06-16

### Removed
- `hooks/session-anchor.sh` (SessionStart 훅) + `hooks/hooks.json`의 SessionStart 등록. 이 훅은 이전 인터뷰 세션 디렉토리를 감지해 `/interview resume` 재진입을 안내했으나, `/interview resume`는 구현된 적이 없다(`commands/interview.md`에 resume 분기 부재) — state-storage 재설계에서 resume 커맨드가 사라진 뒤에도 안내 훅만 남아 매 세션 시작마다 실행 불가능한 조언을 LLM context에 주입하던 stale advisory였다. 훅은 P14 read-only advisor라 출력 소비처가 없고, 리뷰 흐름 상태(`pending_review`/`suppressed_paths`)는 UserPromptSubmit/Stop 훅이 독립 소비하므로 제거가 리뷰 파이프라인에 영향 없음. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Changed
- `tests/test_hooks.sh` — session-anchor 동작 테스트(기존 케이스 9–12)를 SessionStart 재도입 방지 회귀 락(hooks.json에 SessionStart 키 부재 + `session-anchor.sh` 파일 부재 두 단언)으로 재작성.
- `tests/test_hook_output_schema.py` — `TestSessionAnchorSchema` 클래스 및 `TestKillSwitches.test_global_disable_silences_session_anchor` 메서드 제거(`import shutil`은 다른 테스트가 사용하므로 유지).
- `README.md` — Hooks Installed 표의 SessionStart 행, Output schema 문장의 SessionStart 이벤트, Kill switches의 `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 항목 제거.
- `tests/test_readme_sync.sh` — 버전 기대값 0.15.0 → 0.16.0.

## [0.15.0] — 2026-06-16

### Fixed
- `scripts/approve_handoff.sh` — **같은-턴 재dispatch 순서 버그**: `suppress_state.py add`(approved 키 기록 + same-key pending strip)를 working-tree 존재검사(`[[ -f ]]`) *앞으로* 이동. 기존엔 dangling/상대경로/서브디렉토리 cwd에서 `-f`가 먼저 `exit 1`로 빠져 suppress가 누락 → approve해도 같은 턴에 Stop hook이 재dispatch했다. canonical_key 기반 suppress는 파일 존재가 불필요하므로 이제 무조건 기록된다. (AC1)

### Changed
- `scripts/approve_handoff.sh` — `[[ -f ]]` 존재검사를 early-exit에서 **non-blocking advisory**로 강등. `exit 1`은 이제 **session_id charset/arg 검증 실패에 한정**(AC2). in-scope spec_path가 working-tree에 없어도 suppress 기록 + `exit 0` + stale advisory. 헤더 주석·최종 메시지를 v0.15.0 동작으로 갱신.
- `hooks/review-dispatch.py` (Stop) — pending의 path가 현재 세션 `suppressed_paths`에 있으면 **dispatch하지 않고** stale pending을 `suppress_state.strip_pending`으로 제거한다. **`last_dispatched_at`은 건드리지 않음**(TTL window 방지 — `cancel-review --reset` 직후 정당한 pending이 막히지 않도록, AC3b). `SCRIPTS_DIR`를 sys.path에 추가하고 `import suppress_state`를 `main()` try 블록 안에서 deferred 수행 — import 포함 모든 suppress-체크 예외는 fail-open(정상 dispatch, 과리뷰가 under-review보다 안전). Law 2 트리거/억제 대칭 복원. (AC3/AC4/AC5)
- `skills/reviewing-spec/SKILL.md` — "Approve handoff sequence" + "실패 시 state 보존" 절을 새 순서·exit 의미로 동기화.
- `tests/test_handoff_spec_path_validation.sh` — AC4a/AC4b를 새 계약(missing/dangling in-scope → `exit 0` + suppress 기록 + pending strip + advisory + dir 보존)으로 전환. `tests/test_review_dispatch.sh` — suppressed→no-dispatch+strip+TTL불변 / non-suppressed→dispatch 케이스 추가. `tests/test_hook_output_schema.py` — suppress import 실패 fail-open 단언 추가. `tests/test_readme_sync.sh` — 버전 0.14.0 → 0.15.0.
- `README.md` — Flow(v0.15.0) + Principles(Law 2 트리거/억제 대칭) 동기화.

### Notes
- W1(모델이 approve_handoff 자체를 미실행)은 구조적으로 막을 수단(PostToolUse가 AskUserQuestion approve를 감지)이 공식 문서상 보장되지 않아 제외 — `/spec-distill:cancel-review` escape hatch + (재발 증명 시) Law 3 persona/skill 편집이 stance.

## [0.14.0] — 2026-06-05

### Added
- `scripts/suppress_state.py` — per-doc·session-scoped `suppressed_paths` 집합의 **단일 소스**(정규화·pending strip·suppress). Python API(`canonical_key`/`pending_path`/`suppressed_keys`/`strip_pending`/`state_file_for`/`is_suppressed`/`add`/`remove`/`suppress_path`) + thin CLI(`{add|remove|is-suppressed} <sid> <raw_path>`). 정규화는 이 파일에만 존재 — 호출자는 raw 경로 위임(C4/AC17).
- `scripts/cancel_review.py` + `commands/cancel-review.md` — `/spec-distill:cancel-review [path] | --reset <path>`. 현재/지정 design 문서의 auto-review를 취소·억제(또는 재활성화). 리뷰 완료/중단 후 같은 문서 재편집 시 reviewing-spec가 재dispatch되던 두 gap(증상 A/B)을 끄는 사용자 주권(P17) 경로.
- Tests: `tests/test_cancel_review.py`(suppress_state 단위 + cancel_review 통합, AC1–AC8/AC11/AC14/AC17/AC19) + `test_spec_write_validator.sh`/`test_approve_handoff.sh` 확장.

### Changed
- `hooks/spec-write-validator.py` — Layer 1 통과 후 `write_state` 직전 `suppress_state.is_suppressed` 게이트: suppressed 문서는 arm skip + 전용 suppress advisory(기존 "Reviewer will be dispatched" 출력 *교체*) + return 0(AC9/AC18). Layer 1 구조 검증 불변(NG1/AC10). inline pending-strip re.sub → `suppress_state.strip_pending`(중복 제거).
- `scripts/approve_handoff.sh` — 세션 dir `rm -rf` → `suppress_state.py add`(approved 키 기록 + same-key pending strip). dir cleanup은 SessionEnd/TTL-GC로 이관 — 삭제 시 "승인됨" 기억 소실로 증상 A 재발(AC12). "idempotent by statelessness" → "idempotent by set-membership". `skills/reviewing-spec/SKILL.md`의 approve-handoff 계약 서술도 동기화.
- `tests/test_readme_sync.sh` — 버전 기대값 0.13.0 → 0.14.0 + `cancel-review` README 동기화 체크. `tests/test_handoff_compact_chain.sh` — approve가 dir 보존 + suppressed_paths 기록함을 검증하도록 계약 갱신.
- `README.md` — Flow(v0.14.0) + Hooks Installed(PostToolUse suppression 게이트) + Principles(P17 cancel/reset) + Kill switches(per-doc suppression 안내).

### Notes
- suppression은 **session-scoped**: SessionEnd cleanup이 dir를 삭제해 다음 세션은 fresh(NG4/AC15). 재리뷰는 `--reset <path>`, 다른 경로의 새 문서, 또는 reviewing-spec 직접 호출.
- `review-dispatch.py`(Stop)·`pending-review-reminder.py`(UserPromptSubmit)는 무변경 — pending_review가 안 생기므로 자연 no-op.

## [0.13.0] — 2026-06-04

### Added
- `skills/conducting-interview/SKILL.md` Step B — interview→brainstorming 핸드오프를 단일 `AskUserQuestion` **proceed 게이트**(3옵션: ① `/compact` 후 brainstorming 권장 / ② 바로 brainstorming / ③ brief만 종료)로 재작성. `reviewing-spec` Phase 5의 `/compact` 게이트와 **대칭** — 긴 인터뷰 context(round 대화·web sweep·steelman 중간산출)를 해답공간 진입 *전에* 정리할 수 있게. 두 가드 명문화: AP2 polite-stop 금지 + cross-compact 조기진행 금지(옵션 ① 노출 후 같은 턴 brainstorming 직진 금지, AC19 대칭, AC21). superpowers 부재 시 graceful degradation(brief terminal + loud advisory + STOP, 게이트 없음)은 보존(AC13). NG7(handoff 비강제)은 옵션 ③으로 가시화.
- Tests: `tests/test_conducting_interview_stage.sh`에 AC20(3옵션 게이트 + verbatim /compact) / AC21(i)(cross-compact stop wording, mechanical layer) / AC22(AP2 polite-stop ban) grep assert 추가.

### Changed
- `tests/test_readme_sync.sh` — 버전 동기화 기대값 `0.12.0 → 0.13.0`.
- `README.md` — Flow 다이어그램에 interview→brainstorming proceed 게이트 표기 + "Principles Instantiated" AP2에 interview-side `/compact` 대칭 게이트 한 줄.

### Notes
- `approve_handoff.sh`는 interview 쪽에서 **호출하지 않음** — brief는 같은 턴에 막 작성 + `check_brief.py` 검증되어 stale 위험이 없고, 세션 cleanup은 하류(brainstorming→reviewing-spec→spec→writing-plans의 approve_handoff) 또는 SessionEnd가 담당. 옵션 ① 노출 전 `[[ -f <brief-path> ]]` 경량 존재 가드만 둠(게이트 아님).
- `reviewing-spec` Phase 5는 무변경 — 본 작업은 interview 쪽 비대칭만 해소.

## [0.12.0] — 2026-06-01

### Added
- `scripts/web_budget.py` — interview web-research budget enforcer (per-sweep ≤4 / per-session ≤8, state-file counters). Subcommands `check` / `increment` (read-modify-write +1 both counters, preserving inline comments, then check) / `reset-sweep` (sweep boundary). The parser tolerates the schema's inline-comment counter format and fails closed on a present-but-non-numeric counter (never silent-0). Kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` short-circuits to ok (graceful degradation). (AC7/AC8/PN3)
- `scripts/check_brief.py` — interview-brief structural gate (7 sections / non-empty cited landscape / steelman-log well-formedness + frontmatter↔§4 cross-consistency / tried-&-discarded). Strips fenced code blocks before section detection (quoted headers can't satisfy the gate); an unreadable brief emits structured failure JSON, not a traceback. The Law 1 5-ritual termination gate, made mechanical. (AC2/AC4/AC5)
- `agents/steelman-builder.md` — scoped read-only adversarial counter-case builder (`disallowedTools: Write/Edit/MultiEdit/NotebookEdit`; `allowedTools` include WebSearch/WebFetch). Security-sensitive persona. (AC5/AC6)
- `templates/interview-brief-template.md` — canonical 7-section meta-prompt format. (AC1)
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` kill switch — disables interview web research, landscape skipped with loud log.
- Tests: `test_web_sweep_bound.sh`, `test_check_brief.sh`, `test_steelman_builder_scope.sh`, `test_conducting_interview_stage.sh`, `test_reviewing_spec_design_only.sh`, `test_readme_sync.sh` + brief/state fixtures; `test_hook_output_schema.py` design-doc + interview/-exclusion regression.

### Changed
- `skills/conducting-interview/SKILL.md` — re-positioned as a strong problem-space stage (Double Diamond 1st diamond): 5 통과 의례 (R1 Reframe / R2 Landscape / R3 Skepticism / R4 Tried-&-Discarded / R5 Open-Questions) as a Law 1 structural gate; web path(a) expansion; steelman gate; terminal interview-brief output at `docs/superpowers/interview/`; optional `superpowers:brainstorming` handoff. `cost_class: medium → variable`. State writes via Bash (worktree-safe — PN1).
- `commands/interview.md` — role reframed to problem-space stage (trivia escape unchanged, NG6).
- `skills/reviewing-spec/SKILL.md` — **design-mode only**: spec-mode routing rows + `[3.5]` re-consensus gate + `mode_b_violation` handling + `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS` removed (dead paths after drafting-spec removal). Design-doc review + Phase 5 proceed gate unchanged (Law 2 intact).
- `agents/spec-reviewer.md` — description/role refreshed for the design-only flow; clarified the interview brief is NOT its target (NG3). Mode branches + categories unchanged (C3 — not weakened).

### Removed
- `skills/drafting-spec/` (Mode A + Mode B) — the interview now produces a self-complete brief and brainstorming writes the design doc; design revisions are author-regression edits by the main agent, so the spec-writer skill is obsolete. (decision #10)
- Tests/fixtures for removed paths: `run-fixture-ac1.sh`, `interview-transcript-bbda.md`, `mode-b-guard-case.md`, `reconsensus-loop-case.md`, `routing-trace-cases.md`, `stagnation-cases.md`.

### Notes
- superpowers (`brainstorming`/`writing-plans`) remains an optional external plugin. With it absent, `/interview` completes at the brief and logs a loud advisory — no crash, no spec-mode fallback (AC13).
- Hooks are unchanged: `spec-write-validator.py` already classifies `-design.md` under `docs/superpowers/specs/` as design mode and auto-excludes `docs/superpowers/interview/` (outside `PATH_PREFIX`, C8).

## [0.11.3] — 2026-05-31

### Changed
- `tests/test_conducting_interview_internal.sh` — AC1 가드를 frontmatter 블록 한정으로 강화. 기존 `grep -q '^user-invocable: false$' "$SKILL"`는 파일 전체를 검사해, 이론적으로 키가 frontmatter 밖 본문에 있어도 통과할 수 있었음 (menu-visibility를 제어하지 않는 위치). `awk '/^---$/{c++} c==1'`로 첫 `---`…두 번째 `---` 블록만 추출 후 grep하여, 키가 실제로 frontmatter 안에 있을 때만 PASS. 파이프 대신 command-substitution+herestring으로 `set -uo pipefail` SIGPIPE 오탐 회피. 회귀: body-only 키 fixture로 AC1 FAIL 확인. (quality-gates v2.1.0 codex SUGGESTION #1, adversarial conf 3 — 비차단 polish.)

## [0.11.2] — 2026-05-31

### Changed
- `skills/conducting-interview/SKILL.md` — frontmatter에 `user-invocable: false` 추가. 내부 인터뷰 엔진 스킬을 `/` 슬래시 메뉴에서 숨겨 사용자 진입점을 `/interview` 하나로 단일화 (`/conducting-interview` 직접 호출 시 command의 kill switch·trivia escape 게이트 우회 → Law 1 진입 규율 무결성 보호). CC 공식 doc verbatim: `user-invocable`은 *"only controls menu visibility, not Skill tool access"* — command의 `Skill conducting-interview` dispatch·`reviewing-spec` re-entry·모델 자동 트리거는 전부 보존. `disable-model-invocation`은 정반대 효과(Skill tool 차단)라 미사용.

### Added
- `tests/test_conducting_interview_internal.sh` — 회귀 가드. `user-invocable: false` 존재(AC1) + 기존 frontmatter 3키 보존(AC2) + command dispatch·reviewing-spec re-entry 프로그램 호출 경로 보존(AC3). 누가 필드를 지우거나 dispatch 라인을 깨면 fail (Law 3 compounding).

## [0.11.0] — 2026-05-29

### Removed
- `hooks/compact-induction.py` — marker 기반 Stop-hook `/compact` 재주입 폐기. /compact 추천은 reviewing-spec Phase 5의 `AskUserQuestion` proceed 게이트로 이동 (hook은 AskUserQuestion을 띄울 수 없음).
- `hooks/compact-detect.py` — marker 삭제용 UserPromptSubmit hook. marker 부재로 무의미.
- `.claude/spec-distill/.markers/` marker 메커니즘 전체 + `approve_handoff.sh`의 named-status 상수(`HANDOFF_STATUS_*`)·packet emit·`dirty_blocked` exit-1.
- `scripts/spec-distill-gc.py`의 `_sweep_markers` — marker 미생성으로 sweep 대상 부재. **marker GC coverage 포기는 의도적** (markers는 v0.11.0부터 생성되지 않음).
- 테스트: `test_compact_induction_hook.sh`, `test_compact_induction_stagnation.sh`, `test_compact_detect_hook.sh`, `test_handoff_approve_packet_emit.sh`, `test_handoff_status_named.sh`, `test_gc.py`의 marker 케이스(test_13~16).

### Changed
- `skills/reviewing-spec/SKILL.md` Phase 5 — 단일 `AskUserQuestion` proceed 게이트(① /compact 후 writing-plans 권장 / ② 바로 writing-plans / ③ 수정 / ④ 멈춤)로 재구성. approve 후 2차 질문 없음. polite-stop(AP2) + cross-compact 조기 진행 금지(AC19) verifiable 기준 명문화. (구 packet의 verbatim `/compact` 명령 템플릿 — 본문 preserve / 인터뷰·기각대안·중간추론 drop / writing-plans next-step — 은 option ① prose로 이전.)
- `scripts/approve_handoff.sh` — thin finalizer로 축소: spec_path working-tree 존재 검증 + 세션 cleanup. 미커밋 검사는 advisory(non-blocking, exit 0).
- `hooks/hooks.json` — Stop=review-dispatch만, UserPromptSubmit=pending-review-reminder만. description 갱신.

### Fixed
- dangling `spec_path` 핸드오프 예외 — `[[ -f "$spec_path" ]]` working-tree 가드를 모든 git 조회 *이전*에 수행. 삭제된 worktree 경로(git HEAD tracked but working-tree absent)가 `git rev-parse HEAD` 성공으로 통과하던 결함 봉쇄.

### Added
- `tests/test_handoff_spec_path_validation.sh` — AC4a(부재) + AC4b(dangling worktree) 회귀.

### Security
- 없음. review-dispatch / pending-review-reminder / spec-reviewer persona 무변경 — review 강제(Law 1/2) 유지.

## [0.10.0] — 2026-05-27

### Added
- `hooks/compact-induction.py` — Stop event hook. `.claude/spec-distill/.markers/<sid>.emitted` marker 감지 시 `hookSpecificOutput.additionalContext`로 verbatim `/compact` 명령 + `Skill superpowers:writing-plans` 안내 emit. 5회 fire 도달 시 self-cleanup + stagnation advisory.
- `hooks/compact-detect.py` — UserPromptSubmit event hook. `user_prompt`/`user_message`/`prompt` 필드 lstrip + startswith로 `/compact` 또는 `Skill superpowers:writing-plans` 시작 감지 시 marker 삭제.
- `tests/test_handoff_status_named.sh` — Ouroboros named-status invariant (3 readonly 상수).
- `tests/test_compact_induction_hook.sh` — AC4/AC6/AC7/AC8 Stop hook contract.
- `tests/test_compact_detect_hook.sh` — AC5 lstrip+startswith 7-case.
- `tests/test_compact_induction_stagnation.sh` — AC6 5-fire self-cleanup.
- `tests/test_handoff_compact_chain.sh` — V9 end-to-end hook chain JSON contract.

### Changed
- `scripts/approve_handoff.sh` — **commit 단계 완전 제거** (LD4: spec은 사용자 책임). idempotent state machine으로 재설계: `HANDOFF_STATUS_ALREADY_DONE` / `HANDOFF_STATUS_DIRTY_BLOCKED` / `HANDOFF_STATUS_EMITTED` 3-status named-status (Ouroboros `handoff_contract.py` 패턴). marker file `.claude/spec-distill/.markers/<sid>.emitted`에 `STATUS=`/`TIMESTAMP=`/`FIRE_COUNT=`/`SPEC_PATH=` plaintext key=value 기록. 재호출 시 TIMESTAMP 보존 (dedupe invariant).
- `hooks/hooks.json` — UserPromptSubmit에 compact-detect.py, Stop에 compact-induction.py 등록 (기존 hook과 공존).
- `tests/test_approve_handoff.sh` — Case 1/5/7을 AC1/AC2/AC3 의미로 재작성. dirty_blocked stderr 4-token assertion + idempotent re-run TIMESTAMP preservation 검증. 모든 tmpfile은 per-run mktemp dir 안에서 처리 (CI parallel 안전).
- `scripts/spec-distill-gc.py` — `_sweep_markers()` 신규 헬퍼 + `gc()` 메인 루프에 한 줄 추가. `.markers/` 디렉토리의 24h+ stale marker 파일 정리 (기존 fcntl lock / TTL 패턴 재사용).

### Notes
- v0.9.0 에서 생성된 spec 파일은 grandfather migration 없음 (NG5). 기존 `.handoff-status` marker 부재 시 첫 approve_handoff.sh 호출에서 정상 생성.
- compact-detect.py는 `user_prompt`/`user_message`/`prompt` 세 키 모두 읽음 (Claude Code hook schema tolerance — 셋 중 하나 존재 시 처리. 실제 schema는 `user_prompt`이지만 spec 가정과의 forward compat 위해 fallback 유지).
- compact-induction.py와 review-dispatch.py는 같은 Stop 이벤트에 공존. 실 운영에서는 pending_review block 정리 후 marker가 생성되므로 두 hook이 동시에 emit하지는 않음.

## [0.9.0] — 2026-05-26

### Added
- `templates/spec-template.md` — `## Handoff Context` 섹션 신설 (`## Goal` 직후). TL;DR / Implicit context / Deferred to plan 3개 하위 항목. spec/design 파일 self-containedness baseline (G2, AC1).
- `agents/spec-reviewer.md` — `handoff_incomplete` block-severity 카테고리 (spec mode 11→12 카테고리, design mode 6→7 카테고리). 3개 sub-pattern (섹션 부재 / 하위 항목 미작성 / conversation reference 검출). 15개 conversation reference 패턴 enumerated (영어 8 + 한국어 7). v0.10.0+ list 확장 정책 명시.
- `scripts/approve_handoff.sh` — Step 2 출력 교체: minimal 2-line "다음 단계:"에서 3-block "Handoff packet" (divider / `/compact` 명령 with preserve+drop+next-step embed / `[2]` standalone safety net Skill writing-plans 라인 / 종료 divider). /compact preserve directive에 next-step instruction embed로 compact-survival best-effort 지원.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch — `handoff_incomplete` 카테고리만 우회, 다른 검사는 정상. loud warning stderr 출력.
- `tests/test_handoff_*.sh` 6개 신규 test — AC2/AC3/AC4/AC5/AC6/AC7 (모두 `test_handoff_*` prefix로 V1 glob 일관).

### Changed
- spec/design 파일의 review 통과 기준이 self-containedness까지 확장. /compact 경계를 spec lifecycle의 1급 시민으로 승격 — Law 1 (Clarity Before Code) 자연스러운 확장.

### Notes
- Pre-v0.9.0 spec.md grandfather 처리 안 함 (design 문서 NG8 / R6). 기존 spec 재review 시 사용자가 `## Handoff Context` 섹션을 30초 분량 수동 추가 필요. reviewer가 추가 위치/내용을 recommendation으로 안내.

## [0.8.1] — 2026-05-26

### Fixed
- `agents/spec-reviewer.md` — Input/Design Mode Branch wording이 v0.8.0의 content-aware scope 확대를 반영하지 못하던 drift 정정. Input path는 `<file>-spec.md` 한정에서 `docs/superpowers/specs/` hierarchy 안 임의 `.md`로 일반화. Design Mode Branch trigger는 (a) `*-design.md` suffix, (b) suffix 없는 `.md`가 frontmatter `locked_decisions` 부재로 content-aware 판별, (c) dispatcher `mode: design` 명시 — 세 갈래를 명시. Hook 결정론과 reviewer self-narrative 정렬 (Law 2 baseline operability).
- `hooks/spec-write-validator.py` docstring + `README.md` Hooks 표 + `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 설명에 "sub-folder hierarchy 포함" 명시. v0.8.0 시점부터 `resolve_mode()`의 `PATH_PREFIX in file_path` substring 매칭이 sub-folder를 자동 포함하던 것을 contract로 박제.
- `skills/reviewing-spec/SKILL.md` — `mode: design` 분기 설명에서 "brainstorming의 design.md" → "design 모드 파일 (suffix 또는 content-aware)"로 mechanism-agnostic 표현으로 정정.

### Added
- `tests/test_resolve_mode_scope.sh` — sub-folder 회귀 가드 5 case 추가 (depth-1 `-spec.md`, depth-1 `-design.md`, depth-2 content-aware spec, depth-1 content-aware design, hierarchy boundary 위반 false-positive 차단 `specs_archive/`).

## [0.8.0] — 2026-05-22

### Changed
- `hooks/spec-write-validator.py`:`resolve_mode()` — review 게이트 범위를 `docs/superpowers/specs/` 아래 **모든 `.md`**로 확대(기존: `-spec.md`/`-design.md` suffix만). suffix 없는 `.md`는 신규 `_frontmatter_has_locked_decisions()` inline 헬퍼로 mode 판별: 첫 `---`…`---` frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`. body 언급·unclosed frontmatter·디코드 실패는 `design`(안전 fallback) + loud stderr. reviewing-spec routing·검사 로직·state 스키마 불변. review 강제(Law 2)가 파일명 컨벤션에 의존하던 취약점 제거.

## [0.7.0] — 2026-05-22

### Removed
- `hooks/interview-trigger.sh` + `hooks.json` UserPromptSubmit 등록 — advisory build/make nudge 훅. ~80개 세션 트랜스크립트 hook-attachment 전수 스캔 결과 3주간 0회 발화 (trigger 조건 `키워드 + <20단어`가 실사용 프롬프트와 미매칭). 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview` 직접 호출로 충분 — advisory(`additionalContext`)는 모델이 무시 가능해 비결정적. `hooks.json` `description`에서 "interview" 문구 제거.
- `hooks/state_path.py`:`cleanup_stale_states()` 함수 전체 블록 + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 — v0.6.0에 deprecated된 no-op(약속대로 제거). 호출처 없음 (TTL-GC + SessionEnd hook이 정리 담당). `tests/test_state_cleanup.sh` 삭제.
- 테스트 정리: `tests/test_hook_output_schema.py`의 `TestInterviewTriggerSchema` + `test_global_disable_silences_interview_trigger`, `tests/test_hooks.sh`의 interview-trigger 섹션, `README.md` Hooks Installed 표의 interview-trigger 행.

## [0.6.0] — 2026-05-19

### Added
- `hooks/session-end-cleanup.py` — SessionEnd hook for deterministic per-session state cleanup (qg pattern adaptation, git-aware path).
- `scripts/spec-distill-gc.py` — TTL-based GC (24h) with fcntl lock + double-stat ns + rename-then-rmtree race guard. `.gc-pending-*` orphan sweep (>60s) on each invocation.
- `scripts/approve_handoff.sh` — atomic AC11 approve handoff (4-step: commit / handoff pointer / cleanup / termination). Extracted from `skills/reviewing-spec/SKILL.md` prose.
- `hooks/state_path.py`:`resolve_session_id(payload)` + `SESSION_PATTERN` — single source of truth for session_id, charset/length validation.
- 7 new tests: `test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_stale_state_truncate.sh`, `test_brainstorming_entry.sh`, `test_kill_switches_v060.sh`.

### Changed
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` — session_id source switched from `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` literal fallback to `resolve_session_id(payload)`. Production now resolves from `CLAUDE_CODE_SESSION_ID`. `DEVBREW_SPEC_DISTILL_SESSION_ID` retained as test override.
- `hooks/spec-write-validator.py`:`write_state` — defensive truncate when existing state.local.md frontmatter `session_id` ≠ current (defense-in-depth).
- `hooks/spec-write-validator.py` — AC14 legacy advisory: detect `.claude/spec-distill/default/` and emit one-shot stderr advisory (marker `.legacy-advisory-emitted-v060`).
- `hooks/hooks.json` — SessionEnd event registered.
- `skills/reviewing-spec/SKILL.md` — AC11 4-step prose replaced with 1-line `approve_handoff.sh` script call.

### Deprecated
- `hooks/state_path.py`:`cleanup_stale_states` — no-op + marker-based one-shot deprecation stderr. Removed in v0.7.0.

### Fixed
- 잔여 frontmatter bug (사용자 보고 2026-05-19): `.claude/spec-distill/default/state.local.md`에 이전 세션의 frontmatter가 누적되어 새 세션이 stale data 위에 쓰는 증상. Root cause: `DEVBREW_SPEC_DISTILL_SESSION_ID` 부재 시 모든 hook이 `"default"` literal로 fallback → singleton file 공유. Fix: `CLAUDE_CODE_SESSION_ID` 단일 source + SessionEnd hook + TTL-GC + write_state defensive truncate (4-layer defense).

### Security
- session_id charset validation `^[A-Za-z0-9_-]{8,}$` 모든 cleanup path (SessionEnd hook, TTL-GC, approve_handoff.sh, write_state)에 적용 — `../traversal` 등 path injection 차단.

## [0.5.1] — 2026-05-17

### Fixed
- `reviewing-spec/SKILL.md` Re-review cap drift — v0.3.0가 body section의 hard cap을 `>= 3` → `>= 5`로 상향했으나 동일 파일의 (a) frontmatter description (`max 3`), (b) Deterministic Routing Table 5개 행 (spec `< 3` / `>= 3` × 2 + design `< 3` / `>= 3`), (c) `README.md` ASCII flow `max 3`, (d) `tests/test_reviewing_spec_design_routing.sh`의 `count >= 3` assertion이 갱신되지 않아 cap=5가 *dead code*였음. Routing table의 `>= 3` 행이 먼저 fire하여 v0.2.0의 cap=3과 동등하게 동작. 본 PR이 5개 위치 모두 5로 통일하여 v0.3.0 의도가 비로소 enforce됨. **Behavioral change**: re-review가 이제 실제로 4–5회 반복 가능 (이전엔 3회에서 forced Human Gate).

### Added
- `tests/test_rereview_cap_consistency.sh` — cross-file invariant test. SKILL.md body의 `Hard cap**: \`rereview_count >= N\`` 라인에서 N을 source-of-truth로 추출 후 8개 derived 위치 (SKILL.md frontmatter + routing 4행 + README ASCII flow + README AP16 + design-routing test)가 모두 같은 N을 사용하는지 검증. devbrew Law 3 (Compounding) instantiation — 미래 cap 변경 시 derived 갱신을 빠뜨리면 즉시 fail.

## [0.5.0] — 2026-05-17

### Fixed
- 5개 hook (`review-dispatch.py`, `spec-write-validator.py` advisory 분기, `pending-review-reminder.py`, `interview-trigger.sh`, `session-anchor.sh`) 의 stdout JSON이 Claude LLM context로 도달하지 않던 silent failure. `systemMessage` 필드는 Claude Code 사양상 user transcript 표시 전용이며 LLM context inject 메커니즘이 아니다. 올바른 필드는 `hookSpecificOutput.additionalContext` (PostToolUse/UserPromptSubmit/SessionStart) 또는 Stop hook의 `decision:"block" + reason` 페어. dual-target 출력 (Claude-target field + `systemMessage` 짧은 흔적, ≤120자, "[spec-distill]" prefix) 으로 정정 — Claude는 context로 받고 user는 transcript에서 발화 흔적 확인 가능.
- `review-dispatch.py` `rewrite_state()` 호출 순서 정정 (write-before-emit, AC7.1). `rewrite_state()` 본문에 `f.flush()` + `os.fsync(f.fileno())` 추가하여 OS-level durability 보장. 이전 ordering (print → rewrite) 은 동일 turn 안에서 두 번째 Stop fire가 stale state를 읽고 두 번째 block 출력하는 block storm을 일으킬 수 있었음.
- `review-dispatch.py` rewrite OSError 시 `{}` exit 0 (block emit 안 함, AC7.2). 이번 dispatch 1회는 누락되나 L4b UserPromptSubmit reminder가 다음 user prompt에서 dispatch를 살림 — block storm 회피가 우선.
- `interview-trigger.sh` no-jq fallback에 `tr -d '\r'` 추가하여 session-anchor.sh와 CR 처리 대칭.

### Changed
- Stop hook (`review-dispatch.py`) 의 `decision:"block"` 이 Stop을 막고 Claude를 즉시 continue 시키므로 "다음 turn 첫 액션은 reviewing-spec" 강제가 user 입력 대기 없이 작동. 기존 30초 TTL guard (`DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`) 가 무한 block 루프 방지를 그대로 담당.

### Added
- `tests/test_hook_output_schema.py` — Python `unittest` 기반 통합 회귀 방지 test. 5개 hook 모두에 대해 happy-path schema assertion + AC1a 인코딩 round-trip + AC7.2 fault injection + AC7.3 ordering 3-prong (AST inspection + mock-based trace) + AC10/AC11 kill switch + NG9 cross-resolver advisory (skipUnless worktree). bash fallback (jq-없는 환경) 케이스는 `unittest.skipUnless`로 환경 감지.

### Security
- kill switch 5개 (`DEVBREW_DISABLE_SPEC_DISTILL=1` 전역 + `DEVBREW_SKIP_HOOKS=spec-distill:<event>` hook 단위) 모두 무변경. 신규 env var 없음.
- bash hook no-jq fallback escape scope: backslash + double-quote + LF + CR만 처리. null byte / 기타 control char / non-BMP unicode는 처리 범위 밖 — jq path에서 full JSON escape 처리.

## [0.4.0] — 2026-05-17

### Added
- `hooks/state_path.py` — main repo root 해석 helper (`git rev-parse --git-common-dir` 기반). state 파일을 항상 main repo `.claude/spec-distill/` 아래에 기록 (worktree 호출 시에도). cwd fallback + stderr loud log (philosophy §4.8 instantiation).
- `hooks/pending-review-reminder.py` — UserPromptSubmit hook. pending_review가 살아있고 last_dispatched_at > TTL(30s)이면 mandate 재emit (L4b redundancy). Kill switch `spec-distill:UserPromptSubmit` / `spec-distill:reminder`.
- State cleanup 정책: pending_review `triggered_at` > 24h → block auto-purge, last_dispatched_at만 있는 state file > 7일 → file auto-delete. 신규 env var 없이 하드코딩.
- reviewing-spec SKILL.md — Step 1 `pending_review.mode` 분기 + Routing Table에 design rows 3개 추가 (approved → writing-plans, needs_revise < 3 → brainstorming author 회귀, needs_revise ≥ 3 → forced Human Gate). drafting-spec Mode B는 design.md에 호출하지 *않음*.
- agents/spec-reviewer.md — design mode checklist 분기 섹션 6 카테고리 (placeholder / ambiguity / scope_creep / approaches_comparison / isolation / testing). spec mode 본문 무손상.
- 신규 test 6개: `test_state_path.sh`, `test_state_cleanup.sh`, `test_design_mode_validator.sh`, `test_review_dispatch_design_mandate.sh`, `test_reminder_hook.sh`, `test_reviewing_spec_design_routing.sh`, `test_spec_reviewer_design_checklist.sh`.
- 신규 fixture 2개: `tests/fixtures/2026-05-17-test-design.md` (valid), `tests/fixtures/2026-05-17-test-design-bad.md` (placeholder + ambiguity hits).

### Changed
- `hooks/spec-write-validator.py` — state path을 `state_path.state_root()`로 해석, pending_review block에 `worktree_path:` 필드 추가.
- `hooks/review-dispatch.py` — state path을 state_path helper로 해석, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path 포함, fire마다 `cleanup_stale_states` 호출.
- `hooks/hooks.json` — UserPromptSubmit에 reminder hook 등록 (기존 interview-trigger.sh 옆).

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중. 신규 env var 없음 (LD10 일관성).
- bare repo / submodule / nested worktree / `.git` symlink는 supported scope 밖 — state_path cwd fallback + loud log로 운영자 인지 (NG6).

## [0.3.0] — 2026-05-16

### Added
- PostToolUse hook `hooks/spec-write-validator.py` — spec/design 파일 write를 file-system level에서 가로채 Layer 1 mechanical 검증 (11 sections, frontmatter, locked_decisions schema, ambiguity blacklist, design-mode placeholder scan).
- Stop hook `hooks/review-dispatch.py` — `pending_review:` ledger 기반 결정론적 reviewer dispatch (systemMessage 주입).
- `scripts/parse_spec_structure.py` — frontmatter / sections / locked-decisions / ambiguity / placeholders CLI subcommand 라이브러리.
- `scripts/ambiguity-blacklist.txt` — 측정 불가 키워드 + `~` escape 지원.
- design.md (brainstorming upstream 산출물) 커버리지 — suffix-based mode 분기, frontmatter optional, ambiguity + placeholder만 검사.
- 7 fixture 파일 (`tests/fixtures/`) + `test_spec_write_validator.sh` + `test_review_dispatch.sh`.
- Kill switches: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`, `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<sec>`.

### Changed
- `reviewing-spec/SKILL.md` Step 1 — dispatch trigger가 hook-driven (file ledger `pending_review:` block) 임을 명시.
- `reviewing-spec/SKILL.md` Re-review cap — hard cap `>= 3` → `>= 5` + round-level stagnation early-exit (verdict `needs_revise` + `Stagnation_signal: true` → 즉시 [5] Human Gate). multi-round drift detection을 위한 budget 확장.
- `drafting-spec/SKILL.md` Mode A/B — handoff 단계에서 명시 reviewing-spec 호출 불필요, hook이 결정론 dispatch함을 note.

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- PostToolUse exit 2 + stderr 차단 패턴 + stdout `{"decision":"block"}` 이중 안전.

## [0.2.0] — 2026-05-13

### Added
- Re-consensus gate (Phase [3.5]) — locked-affecting reviewer issue가 자동 Mode B로 가지 않고 `AskUserQuestion` 3-옵션 (수용/유지/추가 인터뷰)으로 사용자 게이트.
- spec.md frontmatter `locked_decisions:` 리스트 — `LD1, LD2, ...` ID로 인터뷰 (b)/(d) path 합의를 self-contained contract로 기록.
- state.local.md 신규 필드: `pending_locked_decisions`, `issue_history[].dismissed_by_user`, `issue_history[].accepted_by_user`, `issue_history[].reconsensus_count`, `reconsensus_accepted_ids`.
- drafting-spec Mode B `allowed_issue_ids` 입력 contract — 위반 시 abort + `git restore` + state.local.md `mode_b_violation` marker + reviewing-spec [3.5] re-entry.
- spec-reviewer agent 출력에 issue별 `affects_locked_decisions: [LD ids]` 필드.
- Escalate priority table (P1–P4): C3 global cap (≥4 locked-affecting → spec 전체 [5]) > AC9 per-issue (`reconsensus_count >= 2`) > P18 stagnation > reviewer-persona warn.
- Kill switch `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS=1` (loud warning).
- v0.1.x in-flight state migration — missing field 자동 promote (non-mutating read).
- V0 pre-gate (fixture 존재 검증) + `set -e -o pipefail` 전역 적용.

### Changed
- P18 stagnation 판정 조건: `raised_count >= 3` → `raised_count >= 3 AND dismissed_by_user == 0` (사용자 명시 거절을 stagnation에서 제외).
- spec-reviewer agent — frontmatter `Read` tool 사용 허용 (locked_decisions 추출 목적).
- drafting-spec Mode A — interview transcript에서 `pending_locked_decisions`를 frontmatter `locked_decisions:`로 변환.
- README "Principles Instantiated"에 P17 explicit instantiation 한 줄 추가.
