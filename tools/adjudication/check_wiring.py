# -*- coding: utf-8 -*-
"""L1 판정기 — 버리는 분기가 처분 호출을 갖는지.

대상은 파일의 «모든» `for` 문이다. 「처분 메서드가 불리는 함수」로 좁히면 전혀
배선되지 않은 버리기가 영원히 안 보이고, 모집단이 피검자 손에 들어간다.

컴프리헨션은 대상이 아니다 — 표현식 안에 문장을 넣을 수 없어 「처분을 부르라」는
요구가 문법상 성립하지 않는다. 대신 개수를 세어 호출자가 회귀로 잡게 한다.
"""
import ast
import io

DISPOSITION = frozenset((
    "accept", "reject", "hold", "absorbed", "coerced",
    "source_failed", "uncountable", "suppressed",
))

DISCARD_NODES = (ast.Continue, ast.Break, ast.Return)

# 면제는 «이 파일»에 산다 — 피검자 파일이 아니라. 각 값은 설계 §8 의 C6 조건
# 하나를 인용해야 한다: C6(1) 대응물이 원리적으로 없음 · C6(2) 측정된 이유.
# 인용 없는 항목(빈 문자열)은 호출자가 RED 로 만든다.
#
# Task 1 Step 6 이 이 목록의 초기 내용을 정한다. 착수 시점에는 비어 있다 —
# 비어 있는 것이 이 락이 오늘 RED 인 이유의 일부다.

# Task 11 (T5) — 훅에 `from adjudication import Ledger` 를 더하면서
# review-dispatch.py 가 처음으로 ㉮(회계 소비자)에 들어왔다. 이 파일의 다른
# for 문 열 자리가 그 순간 새로 이 락의 대상이 된다 — 이번 Task 가 배선한 두
# `decision:"block"` 자리(T5-1·T5-2)는 루프 «안»이 아니라서 이 열에 포함되지
# 않는다. 남은 열 자리는 전부 `select_dispatch_target()`(다음 턴에 dispatch할
# 문서 하나를 고르는 선택 루프)와 `main()` 의 검증 대상 선별 루프에 있다 —
# 신고된 발견물을 판정하는 자리가 아니라 "이번 턴에 무엇을 처리할지" 고르는
# 스케줄링 루프다.
#
# 근거(코드를 직접 읽고 확인 — 선재 판정을 그대로 받아 적지 않았다): 이 파일의
# 모듈 docstring 과 `discover_candidates.py` 의 모듈 docstring 이 함께 명시하듯
# "발견은 무상태"다 — 매 Stop 마다 `git status` 로 후보 전체를 다시 낸다.
# 그러므로 이번 턴에 선택되지 않은 후보는 «사라지는» 것이 아니라 다음 Stop 의
# 후보 목록에 그대로 다시 나타난다. 소실이라는 개념 자체가 성립하지 않는다
# (C6(1)) — "판정자가 처리하지 못해 항목이 사라졌다"는 전제가 스케줄링 루프에는
# 적용되지 않는다.
_T5_SELECT_LOOP = (
    "C6(1) — select_dispatch_target() 의 선택 루프(cands 를 훑어 dispatch 대상 "
    "하나를 고른다). discover()가 매 Stop마다 git status 로 후보 전체를 무상태 "
    "재스캔하므로, 이번 턴에 고르지 못한 후보는 사라지지 않고 다음 Stop 의 "
    "후보 목록에 그대로 다시 나타난다. 이 루프는 신고된 발견물을 판정하는 "
    "자리가 아니라 '이번 턴에 dispatch할 문서 하나'를 고르는 스케줄링이다 — "
    "회계가 대응할 처분 대상(accountable finding) 자체가 없다."
)
# Task 11b Step 4c — 오케스트레이터 지적: 위 `_T5_SELECT_LOOP` 의 "다음 Stop 의
# 후보 목록에 그대로 다시 나타난다"는 두 영속-상태 상한 검사(DISPATCH_ATTEMPT_CAP·
# VALIDATION_ATTEMPT_CAP)에는 **거짓**이다 — 상한 카운터는 arm_ledger.py 의
# record_attempt()/validation 기록이 세션에 걸쳐 영속시키므로, 한 번 상한에
# 닿으면 그 후보는 이 특정 검사를 다음 Stop 에도 계속 다시 통과 못 한다(코드
# 확인: record_attempt() 는 attempts 가 DISPATCH_ATTEMPT_CAP 에 닿는 바로 그
# write 에서 armed_paths 에도 같이 추가한다 — arm_ledger.py:347). 결론(배선
# 불필요)은 그대로다: 소실이 없다는 근거가 "다시 보인다"가 아니라 "이미
# 한 번 공시됐다"로 바뀔 뿐이다.
_T5_SELECT_LOOP_DISPATCH_CAP = (
    "C6(1) — select_dispatch_target() 의 DISPATCH_ATTEMPT_CAP 스킵. 위 "
    "_T5_SELECT_LOOP 의 '다음 Stop 에 다시 나타난다'는 이 필터에는 거짓이다 "
    "— record_attempt()(arm_ledger.py:347)가 attempts 를 상한에 올리는 그 "
    "write 에서 armed_paths 에도 같이 추가하므로, 이후 Stop 에서 그 후보는 "
    "(이 검사가 아니라) 위 armed 검사에서 먼저 걸린다. 진짜 근거: 상한 도달 "
    "사실은 상한에 닿던 바로 그 dispatch 시도에서 이미 한 번 공시됐다 — "
    "review-dispatch.py:765-770 의 mandate 메시지(「…자동 dispatch를 "
    "중단한다」). 이후의 조용한 스킵은 새 소실이 아니라 이미 공시된 상태를 "
    "다시 지나가는 것이다."
)
_T5_SELECT_LOOP_VALIDATION_CAP = (
    "C6(1) — select_dispatch_target() 의 VALIDATION_ATTEMPT_CAP 스킵. 같은 "
    "이유로 _T5_SELECT_LOOP 의 '다시 나타난다' 근거는 이 필터에도 거짓이다. "
    "진짜 근거: 같은 상한·같은 카운터를 main() 의 검증 대상 선별 루프 "
    "(:544-546)가 이 함수 호출보다 **앞서** 같은 Stop 안에서 이미 검사해 "
    "capped_advisory(:583-587)를 만들어 두고, 그 값은 select_dispatch_target() "
    "이 무엇을 고르든 상관없이 with_advisory 로 이 턴의 출력에 실린다(flush "
    "지점: :634·:650·:694·:703·:713·:797·:809). 이 자리의 스킵은 같은 Stop "
    "안에서 이미 공시된 사실을 다시 지나가는 것이지 새 소실이 아니다."
)
_T5_MAIN_VALIDATION_LOOP_INFLIGHT = (
    "C6(1) — main() 의 검증 대상 선별 루프(cands 를 훑어 validation_pool 을 "
    "만든다). is_inflight 는 arm_ledger.is_inflight(body, c.path, now) 로 매 "
    "Stop 마다 새로 계산되는 상태다 — 지금 다른 리뷰가 도는 문서를 이번 턴의 "
    "구조 검증에서만 뺀다. 리뷰가 끝나면 다음 Stop 에서 다시 후보가 되므로 "
    "영구 소실이 아니다."
)
_T5_MAIN_VALIDATION_LOOP_SUCCESS = (
    "C6(1) — main() 의 구조 검증 루프(`for key in picked`). `reasons` 가 "
    "빈 목록이면 그 문서는 구조 검증을 통과했다는 뜻이라 애초에 판정할 "
    "실패가 없다 — hold/reject 할 대상이 없는 성공 케이스에는 대응하는 "
    "처분 개념이 없다."
)

EXEMPT = {
    # ("plugins/.../foo.py", 146): "C6(1) 제자리 변형 루프 — 버려지는 항목이 없다",
    # Task 10 이 파일 상단에 `from render_disposition import disposition_lines`
    # 를 더해 이 줄이 358→359 로 밀렸다 — 인용 자체는 무변경(내용은 그대로다).
    ("plugins/quality-gates/scripts/synthesize_findings.py", 359,
     "continue in dedup @ if f.get('promoted')"):
        "C6(1) — dedup() 의 이 continue 는 `promoted` 항목을 그룹핑에서만 "
        "제외한다. 항목 자체는 이 loop 이전에 계산된 `passthrough` 리스트에 "
        "이미 담겨 있고 함수 반환값(`deduped + passthrough`)에 그대로 "
        "살아남는다 — 버려지는 항목이 없다.",
    # Task 10 — merge_review.py 의 `disposition_report()` 결과를 이름별로 펴는
    # 루프. `continue` 는 "reasons"·"held_by_class" 두 키를 이 loop 에서만
    # 제외한다 — 둘 다 다른 자리에서 이미/따로 실린다: "reasons" 는 이 loop
    # «이전»에 이미 `advisory.extend(merged["reasons"])`로 advisory 채널에
    # 실렸고, "held_by_class" 는 loop 직후 세 줄(`adjudication_held_unadjudicated`/
    # `_malformed`/`_other`)로 분해돼 실린다.
    # 버려지는 항목이 없다(C6(1)).
    ("plugins/spec-distill/scripts/merge_review.py", 618,
     "continue in main @ if _k in ('reasons', 'held_by_class')"):
        "C6(1) — disposition_report().items() 를 도는 이 continue 는 "
        "\"reasons\"·\"held_by_class\" 두 키를 이 loop 에서만 제외한다. "
        "\"reasons\" 는 이 loop 이전에 이미 advisory 채널로, \"held_by_class\" "
        "는 loop 직후 세 줄(held_unadjudicated/held_malformed/held_other)로 "
        "각각 실린다 — 버려지는 항목이 없다.",
    # Task 10 수정 라운드 1 — merge_brief_review.py 가 형제 merge_review.py 와
    # 같은 편평화 루프를 쓴다. 원장이 하나뿐이라 합산이 없다는 점만 다르고
    # 제외 사유는 동일하다: "reasons" 는 이 loop 이전에 이미
    # `advisory.extend(L.reasons())`(:334)로, "held_by_class" 는 loop 직후
    # 세 줄로 각각 실린다 — 버려지는 항목이 없다.
    ("plugins/spec-distill/scripts/merge_brief_review.py", 363,
     "continue in main @ if _k in ('reasons', 'held_by_class')"):
        "C6(1) — disposition_report().items() 를 도는 이 continue 는 "
        "\"reasons\"·\"held_by_class\" 두 키를 이 loop 에서만 제외한다. "
        "\"reasons\" 는 이 loop 이전에 이미 `advisory.extend(L.reasons())`(:334) "
        "로, \"held_by_class\" 는 loop 직후 세 줄(held_unadjudicated/"
        "held_malformed/held_other)로 각각 실린다 — 버려지는 항목이 없다.",

    # Task 11 (T5) — select_dispatch_target() 의 선택 루프 7 자리.
    # Task 11b Step 4c/수정 — 07c9991·6d87b2c 가 이 함수보다 «앞선» 코드
    # (`_block_with_ledger` 재작성 + import 한 줄)를 늘려 select_dispatch_target
    # 전체가 +13 줄 밀렸다. 원래 327~338 이던 키가 조용히 stale 해져 배선 락이
    # 이미 인용한 자리를 "미배선"으로 잘못 재보고했다 — 배선 락은 (파일, 줄번호)
    # 로만 面제를 찾으므로 줄 이동은 그 자체로 락을 무력화한다(발견: Task 11b
    # 스캔 실측, unwired=14 인데 브리프 전제는 4). 아래 7 줄을 현재 위치로
    # 갱신한다 — 코드·판정은 무변경, 줄번호만 교정.
    #
    # 최종 수정 라운드 2 — 같은 drift 가 «한 번 더» 일어났다(+17): R-A 가
    # `_block_with_ledger()` 의 docstring 을 늘려 그 아래 전부가 밀렸다. 이번엔
    # 다른 점이 하나 있다 — 키가 «정체»(kind·func·guard)를 함께 쥐게 된 뒤라
    # 락이 열 자리를 **이름과 함께** 냈고, 갱신을 «정체가 같은 행 찾기»로
    # 기계적으로 할 수 있었다(줄번호를 손으로 세지 않았다). 판정·사유는 무변경.
    # :340~342·:348~351 다섯 자리는 `_T5_SELECT_LOOP` 를 그대로 공유한다(born·
    # armed·is_inflight·resolve_mode 넷은 실제로 매 Stop 재계산되는 상태다).
    # :344·:346 (DISPATCH_ATTEMPT_CAP·VALIDATION_ATTEMPT_CAP) 은 그 공유 근거가
    # 거짓이라 위 두 전용 상수로 분리했다(Step 4c). :351 은 그 루프의
    # `return c` — 첫 적격 후보를 찾고 순회를 멈추는 것도 `_T5_SELECT_LOOP` 와
    # 같은 이유로 소실이 아니다(discover()가 다음 Stop 에 나머지 후보를 다시
    # 낸다).
    ("plugins/spec-distill/hooks/review-dispatch.py", 357,
     'continue in select_dispatch_target @ if c.born'): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 359,
     'continue in select_dispatch_target @ if c.key in armed'): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 361,
     'continue in select_dispatch_target @ if att.get(c.key, 0) >= arm_ledger.DISPATCH_ATTEMPT_CAP'):
        _T5_SELECT_LOOP_DISPATCH_CAP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 363,
     'continue in select_dispatch_target @ if val.get(c.key, 0) >= arm_ledger.VALIDATION_ATTEMPT_CAP'):
        _T5_SELECT_LOOP_VALIDATION_CAP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 365,
     'continue in select_dispatch_target @ if arm_ledger.is_inflight(body, c.path, now)'): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 367,
     'continue in select_dispatch_target @ if resolve_mode(c.path) is None'): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 368,
     'return in select_dispatch_target @ <bare>'): _T5_SELECT_LOOP,

    # Task 11 (T5) — main() 의 검증 대상 선별 루프. :543(구 :530) 은 in-flight
    # 스킵(다른 리뷰가 도는 중 — 끝나면 다음 Stop 에 다시 후보가 된다). 줄번호는
    # Task 11b 가 위와 같은 +13 drift 로 교정(사유·판정 무변경).
    ("plugins/spec-distill/hooks/review-dispatch.py", 560,
     'continue in main @ if arm_ledger.is_inflight(body, c.path, now)'):
        _T5_MAIN_VALIDATION_LOOP_INFLIGHT,

    # Task 11 수정 라운드 1 — 최초 사유가 범주 착오였다(오케스트레이터 지적).
    # Task 11b — 줄번호를 :533→:546 으로 교정(위와 같은 +13 drift, 판정·본문
    # 논거는 무변경 — 내부 인용 줄번호만 현재 파일에 맞게 다시 잡는다).
    # :546 은 검증 상한(VALIDATION_ATTEMPT_CAP) 도달 스킵이다. `capped.append(
    # c.key)` 가 바로 위 같은 분기에서 continue 이전에 실행되므로 항목 자체는
    # 사라지지 않고 `capped` → `capped_advisory` 를 타고 이번 턴의 JSON 출력
    # `systemMessage` 필드에 실제로 실린다(추적: :567 정의·:583-587 조립·flush
    # 지점 :634,650,694,703,713,797,809).
    #
    # 최초 판정은 여기서 "systemMessage 가 모델 도달 카나리 0/14 라 채널
    # 효과가 의심된다"고 적었으나 **그건 범주 착오다.** CLAUDE.md 의 계약:
    # "미판정 항목의 방향은 다음 소비자가 정한다: 기계면 제외, 사람이면
    # 라벨을 붙여 보여준다." `systemMessage` 는 **사람의 터미널**에 뜨는
    # 채널이지 모델 컨텍스트에 주입되는 채널이 아니다 — T5-1·T5-2 가 채널을
    # `reason` 으로 정한 이유는 그 두 자리의 소비자가 **모델**(다음 턴
    # dispatch 판단)이기 때문이었다. 이 자리(:546)의 소비자는 사람이다 —
    # "자동 검증·dispatch 를 하지 않는 문서가 있다"는 사실은 세션을 보는
    # 사람에게 알리는 것이지 모델에게 강제할 대상이 아니다. 그러므로 모델
    # 미도달은 결함이 아니라 이 채널의 **설계대로**다 — 소실도 아니고 채널
    # 결함도 아니다(C6(1)).
    #
    # 그래도 면제 표시는 "최종 리뷰 재검토" 를 남긴다 — 규칙 억제
    # (`suppressed()`)로 재분류할지는 여전히 열린 질문이다: 이 스킵은 규칙
    # (상한값)이 정한 배제이지 판정자의 판단이 아니라는 점에서 `suppressed()`
    # 의 정의("규칙 억제 — 판정자의 판단이 아니라 규칙(임계값)이 정한 배제")
    # 와 정확히 들어맞아 보이기 때문이다.
    ("plugins/spec-distill/hooks/review-dispatch.py", 563,
     'continue in main @ if val_att.get(c.key, 0) >= val_cap'):
        "C6(1) — 검증 상한 도달 스킵. `capped.append(c.key)` 가 같은 분기에서 "
        "continue 이전에 실행돼 항목이 `capped`→`capped_advisory`로 이 턴의 "
        "systemMessage 에 실린다(코드 추적 완료). systemMessage 는 사람의 "
        "터미널에 뜨는 채널이다(CLAUDE.md: 미판정 항목은 사람이면 라벨을 "
        "붙여 보여준다) — 이 자리의 소비자는 사람이고, 모델 컨텍스트 카나리 "
        "0/14 는 이 채널의 설계이지 소실이 아니다. 최종 리뷰가 재검토할 것 "
        "(규칙 억제 `suppressed()` 재분류 후보 — 판단이 아니라 상한값이 "
        "정한 배제라는 점에서).",

    # Task 11 (T5) — main() 의 구조 검증 루프. :603(구 :589) 는 `reasons` 가 빈
    # 성공 케이스 — 판정할 실패 자체가 없다. 줄번호는 Task 11b 가 +14 drift 로
    # 교정(사유·판정 무변경 — 이 지점은 :546 보다 아래라 6d87b2c 의
    # `failed_keys` 삽입 한 줄이 더 얹혀 +14).
    ("plugins/spec-distill/hooks/review-dispatch.py", 620,
     'continue in main @ if not reasons'):
        _T5_MAIN_VALIDATION_LOOP_SUCCESS,

    # Task 11b Step 1~3 — 계획이 배정하지 않았던 네 자리(merge_review.py).
    # PR1 배선 baseline=14, T1-A/T1-B 가 review-dispatch.py 열을 닫아 남긴 게
    # 이 넷이었다(원 계획 전제). 넷 다 판단 결과는 «배선 불필요» — 근거는
    # 자리마다 다르다(보고서 `.superpowers/sdd/2026-09-03-adjudication-topology/
    # task-11b-report.md` 에 각 자리의 세 질문 답변).
    #
    # :155·:160 — parse_codex_yaml() 의 `for raw in lines:` 는 codex YAML
    # 파일의 «텍스트 줄» 을 도는 라인 파서 루프다. 원소는 판정 항목(finding)
    # 이 아니라 원문 줄이고, 두 continue 는 YAML 섹션 헤더(`findings:`·
    # `meta:`) 를 만났을 때 상태 전이만 하고 다음 줄로 넘어간다 — 그 줄
    # 자체가 finding 이 아니므로 버릴 항목이 없다. :160 은 오히려 반대
    # 증거를 담고 있다: `meta:` 전환 **이전에** `if cur: findings.append(cur)`
    # 로 그때까지 누적된 finding 을 먼저 보존한 뒤에 continue 한다 — 소실
    # 방지가 코드에 명시적으로 있다.
    ("plugins/spec-distill/scripts/merge_review.py", 155,
     "continue in parse_codex_yaml @ if line.startswith('findings:')"):
        "C6(1) — parse_codex_yaml() 의 `for raw in lines:` 는 codex YAML 의 "
        "«텍스트 줄»을 도는 라인 파서다(findings 리스트가 아니다). 이 "
        "continue 는 `findings:` 섹션 헤더 줄을 만났을 때 상태 전이만 하고 "
        "다음 줄로 넘어간다 — 헤더 줄 자체는 finding 이 아니라 버릴 항목이 "
        "없다.",
    ("plugins/spec-distill/scripts/merge_review.py", 160,
     "continue in parse_codex_yaml @ if line.startswith('meta:')"):
        "C6(1) — 같은 라인 파서, `meta:` 섹션 헤더. `if cur: findings.append("
        "cur)` 가 continue **이전**에 실행돼 그때까지 누적된 finding 을 먼저 "
        "보존한다 — 헤더 줄 자체는 finding 이 아니고, 진행 중이던 finding 도 "
        "소실되지 않는다.",
    # :229 — derive_codex_verdict() 는 `codex_findings` 전체에 대한 단일
    # 집계값(verdict 문자열)을 접는(fold) 함수다. 첫 escalating finding 에서
    # `return "needs_revise"` 로 끊지만, 순회를 멈춘다고 나머지 finding 이
    # 파이프라인에서 사라지지 않는다 — 호출자가 들고 있는 같은 `codex_findings`
    # 리스트가 이 함수와 무관하게 build_ledger() 의 `for f in codex_findings:`
    # (:363, 이미 배선됨 — :373 에서 codex_ledger.hold() 뒤 continue) 로 전수
    # 다시 돌며, category·target_section 둘 다 없는 원소는 거기서 hold() 된다.
    # 표시 채널(build_codex_findings_display)도 이 함수와 별개로 같은 전체
    # 리스트를 돈다. 즉 이 fold 가 일찍 멈춰도 "판정에 영향을 주는 값"은
    # 동일하고(max 류 단조 집계라 나머지를 봐도 결론이 안 바뀐다), 개별
    # finding 의 회계는 이미 다른 자리(:363)가 맡는다.
    ("plugins/spec-distill/scripts/merge_review.py", 229,
     'return in derive_codex_verdict @ if sev in CODEX_SEVERITY_REVISE or sev not in CODEX_SEVERITY_KNOWN'):
        "C6(1) — derive_codex_verdict() 의 fold 조기 종료. `codex_findings` "
        "전체는 이 함수와 무관하게 build_ledger() 의 `for f in codex_findings:` "
        "(:363, 이미 배선 — :371-373 에서 codex_ledger.hold() 뒤 continue) 가 "
        "전수 다시 돌아 개별 회계하고, build_codex_findings_display() 도 같은 "
        "전체 리스트를 별도로 순회해 표시한다 — 이 fold 가 멈춰도 미방문 "
        "finding 이 파이프라인에서 사라지지 않는다. 결론(needs_revise)도 "
        "단조 집계라 나머지를 마저 봐도 바뀌지 않는다.",
    # :270 — build_codex_findings_display() 의 `if not isinstance(f, dict):
    # continue` 는 도달 불가능한 방어다. 이 함수의 유일한 호출자(main():555)는
    # 항상 parse_codex_yaml() 의 반환값을 그대로 넘기고(:489→:555, 사이에
    # 변형 없음), parse_codex_yaml() 의 `findings` 리스트는 `cur = {}` 로만
    # 생성되고 dict 항목 대입(`cur[k] = v`)만 받는다 — 코드 어디에도 `cur` 를
    # dict 아닌 값으로 덮어쓰는 경로가 없다(코드 확인 완료). 배선하면 Task 10
    # 의 `phase_key` 와 같은 죽은 코드가 된다.
    ("plugins/spec-distill/scripts/merge_review.py", 270,
     'continue in build_codex_findings_display @ if not isinstance(f, dict)'):
        "C6(1) — 도달 불가능한 방어. 유일한 호출자 main():555 는 parse_codex_"
        "yaml():489 의 반환값을 변형 없이 그대로 넘기고, 그 함수의 `findings` "
        "는 `cur = {}` 로만 생성돼 dict 항목 대입만 받는다 — 비-dict 원소를 "
        "만드는 경로가 코드에 없다(확인 완료). 배선하면 죽은 코드다(Task 10 "
        "의 `phase_key` 와 같은 함정).",
}

# Task 11 수정 라운드 1 — `derive_consumers()` 의 import·앵커 대칭 가정이
# 깨지는 자리를 명시적으로 등재한다. 그 가정("원장을 import 하는 파일은
# 전부 어딘가 dispatch 자리에서 `consumer=` 로 불린다")은 PR1 이 넣은 것이고
# review-dispatch.py 가 그 반례다: 앵커(`consumer=`)는 skill/command/agent
# 문서가 "이 subagent 의 발견물을 이 스크립트가 판정한다"고 선언하는 자리인데,
# 훅은 subagent dispatch 결과를 받는 소비자가 아니라 **그 자신이** 직접
# `decision:"block"` 으로 차단/통과를 정하는 **종단(terminal) 결정자**다 —
# 이름 붙일 dispatch 자리 자체가 없다. 없는 자리를 만들어 붙이면 그건 허구다.
#
# `EXEMPT` 와 같은 규율: 사유 없는 항목(빈 문자열)은 그 자체로 RED —
# `test_adjudication_wiring.sh` 의 `terminal_uncited` 축이 잡는다.
#
# Task 11b Step 4b — 오케스트레이터(Task 11 리뷰) 지적: `run_wiring_scan.py`
# 의 `exempt_uncited` 는 값에 리터럴 `"C6"` 이 있는지를 보는데, `terminal_
# uncited` 는 빈 문자열만 아니면 통과했다 — 같은 CLAUDE.md 요구("면제는 …
# 인용이 없으면 RED")가 두 등록부에서 다른 엄격도로 걸렸다. `run_wiring_scan.py`
# 의 `terminal_uncited` 계산을 `EXEMPT` 와 같은 `"C6" not in str(v)` 규율로
# 맞추고, 아래 값에 그 인용을 명시한다(실질은 이미 C6(1) — 대응할 dispatch
# 자리 자체가 없음).
TERMINAL_CONSUMERS = {
    "plugins/spec-distill/hooks/review-dispatch.py":
        "C6(1) — 종단 결정자. subagent findings 를 판정해 넘기는 소비자가 "
        "아니라 이 파일 스스로 두 `decision:\"block\"` 자리(T5-1 구조 검증 "
        "실패 · T5-2 dispatch 강제)에서 차단/통과를 정한다. 이 훅을 부르는 "
        "어떤 skill/command/agent 문서에도 「이 스크립트가 판정한다」고 "
        "선언할 dispatch 자리가 없다 — Stop 이벤트가 훅을 직접 실행하지, "
        "markdown 이 subagent 로 dispatch 하는 형태가 아니다. 대응물이 "
        "원리적으로 없다.",
}


def _disposition_calls(node):
    return [n for n in ast.walk(node)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
            and n.func.attr in DISPOSITION]


def _parent_map(tree):
    parents = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[child] = node
    return parents


def _enclosing_loop(node, parents):
    """`node` 를 감싸는 가장 안쪽 for 문. 없으면 None.

    함수 경계와 while 경계를 넘지 않는다 — 중첩 함수 안의 return 은 바깥
    루프의 버리는 분기가 아니고, for 안에 중첩된 while 의 continue/break 도
    그 while 소속이지 바깥 for 의 인구가 아니다(while 자체는 이 판정기의
    대상이 아니므로 그런 노드는 어느 for 에도 귀속되지 않는다 — 조용히
    제외된다. 함수 경계와 같은 종류의 fail-closed 다).
    """
    cur = parents.get(node)
    while cur is not None:
        if isinstance(cur, (ast.For, ast.AsyncFor)):
            return cur
        if isinstance(cur, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda,
                            ast.While)):
            return None
        cur = parents.get(cur)
    return None


def _enclosing_branch(loop, target, parents):
    """`target` 을 감싸는 가장 안쪽 분기의 «본문»과 «정체». `(body, guard)`.

    분기 컨테이너는 `If.body`/`If.orelse` 뿐 아니라 `Try.body`(try 본문)·
    `Try.orelse`(else)·`Try.finalbody`(finally)·`ExceptHandler.body`(except
    본문)도 같은 자격으로 포함한다 — try/except 도 배선 태스크들에서 실제로
    쓰는 처분 형태이고, 안쪽 except 본문에 처분 호출이 있는데 If 만 인식하면
    「배선 안 됨」이라는 거짓 신호가 난다.

    부모 사슬을 «올라가서» 첫 분기 컨테이너를 만난다 — 포함 관계 그 자체다.
    본문의 «길이»를 안쪽의 대리 지표로 쓰면 안 된다: 그 둘은 같지 않고, 바깥
    분기가 더 짧으면 거기 있는 무관한 처분 호출이 이 분기를 guarded 로
    만든다.

    **`guard` 는 그 분기를 성립시키는 조건의 원문**(`ast.unparse`)이다 —
    면제 키가 줄번호만으로는 «자리»를 가리킬 뿐 «무엇을 면제했는지»를
    가리키지 못하기 때문이다(`stale_exempt()` 참조). 본문과 정체를 한 번의
    상승으로 «함께» 낸다 — 두 함수로 나누면 두 순회의 분기 선택이 갈리는
    순간 면제가 엉뚱한 조건에 붙는다.

    분기 컨테이너가 없으면(루프 본문 최상단의 맨 `continue`/`return`)
    `(None, "<bare>")` — 자리 자체는 실재하므로 정체도 실재한다.
    """
    node = target
    while node is not loop:
        parent = parents.get(node)
        if parent is None:
            return None, "<bare>"
        if isinstance(parent, ast.If):
            test = ast.unparse(parent.test)
            if any(child is node for child in parent.body):
                return parent.body, "if " + test
            if any(child is node for child in parent.orelse):
                return parent.orelse, "else-of if " + test
        elif isinstance(parent, ast.Try):
            if any(child is node for child in parent.body):
                return parent.body, "try-body"
            if any(child is node for child in parent.orelse):
                return parent.orelse, "try-else"
            if any(child is node for child in parent.finalbody):
                return parent.finalbody, "try-finally"
        elif isinstance(parent, ast.ExceptHandler):
            if any(child is node for child in parent.body):
                return (parent.body,
                        "except " + (ast.unparse(parent.type)
                                     if parent.type else ""))
        node = parent
    return None, "<bare>"


def _func_of(tree, node):
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any(x is node for x in ast.walk(fn)):
                return fn.name
    return "<module>"


def scan(paths):
    """버리는 분기 전수. 각 항목은 guarded 여부를 함께 낸다.

    분기 «노드»에서 출발한다 — 루프에서 출발해 하위를 훑으면 중첩 루프 안의
    한 문장이 바깥·안쪽 양쪽에 귀속돼 두 번 세어진다.
    """
    out = []
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        parents = _parent_map(tree)
        for n in ast.walk(tree):
            if not isinstance(n, DISCARD_NODES):
                continue
            loop = _enclosing_loop(n, parents)
            if loop is None:
                continue
            branch, guard = _enclosing_branch(loop, n, parents)
            # 분기를 못 찾으면 루프 본문 전체로 넓히지 «않는다» — 그것이
            # 루프 최상위의 맨 continue 를 guarded 로 읽는 fail-open 이다.
            scope = branch if branch is not None else [n]
            out.append({
                "file": path,
                "line": n.lineno,
                "kind": type(n).__name__.lower(),
                "func": _func_of(tree, n),
                "guard": guard,
                "guarded": any(_disposition_calls(s) for s in scope),
            })
    return out


def exempt_key(rel, row):
    """면제 키 — `(경로, 줄, 정체)`. 정체 = `<kind> in <func> @ <guard>`.

    **줄번호만으로는 «자리»를 가리킬 뿐 «무엇을 면제했는지»를 못 가리킨다.**
    사유는 언제나 그 분기가 «어떤 조건에서 무엇을 버리는가»에 대한 진술인데,
    키가 자리만 쥐고 있으면 그 자리의 조건이 바뀌어도(줄 수만 보존되면)
    면제가 새 조건에 그대로 상속된다 — 사유는 이미 거짓인데 락은 조용하다.

    그래서 세 성분을 함께 묶는다: `kind`(무엇으로 버리는가) · `func`(어디서) ·
    `guard`(어떤 조건에서). 셋 중 하나라도 바뀌면 키가 어긋나 `stale_exempt()`
    가 이름을 대고, 같은 행이 `unwired` 로도 다시 나온다(양의 짝).

    정체를 해시가 아니라 «원문»으로 둔다 — 면제 표를 읽는 사람이 파일을 열지
    않고도 무엇이 면제됐는지 본다. 조건이 정당하게 바뀌면 키를 갱신해야 하고,
    그 갱신이 곧 사유 재검증이다(이 락이 요구하는 churn 이지 비용이 아니다).
    """
    return (rel, row["line"],
            "%s in %s @ %s" % (row["kind"], row["func"], row["guard"]))


def stale_exempt(repo_root):
    """`EXEMPT` 의 키가 현재 트리에서 «자기가 면제한 바로 그 분기»를 가리키는지.

    면제 키는 자리(경로·줄)와 정체(`kind`·`func`·`guard`)를 함께 쥔다
    (`exempt_key()`). 이 함수는 그 키 전체를 현재 트리에서 도출한 키 집합과
    대조해, 어긋난 것을 이름을 대어 낸다.

    **두 방향의 위험이 있고 둘 다 이 검사가 잡는다.**

    ⑴ 자리가 어긋남 — 그 자리 «위»에 코드가 늘면 키가 밀린다. Task 11b 가
    실증했다: 앞선 두 커밋이 `select_dispatch_target()` 위에 코드를 늘려 그
    함수가 +13/+14 줄 밀렸고 열 개의 키가 통째로 낡았다. 밀린 줄이 아무것도
    안 가리키면 배선 락이 미배선으로 다시 잡아 시끄럽게 실패하지만, 다른
    버리는 분기의 줄번호와 겹치면 그 엉뚱한 자리가 조용히 면제된다.

    ⑵ **자리는 그대로인데 분기가 다른 것이 됨** — 줄 수를 바꾸지 않고 조건만
    넓히면(`if f.get("promoted"):` → `if f.get("promoted") or …:`) 그 자리는
    여전히 버리는 분기라서 «자리»만 보는 검사는 통과한다. 그런데 그 면제의
    사유(「버려지는 항목이 없다」)는 이미 거짓이다 — 새 조건이 버리는 항목은
    회계 없이 사라진다. 최종 리뷰가 이 구멍을 실측했다(락 넷 전부 GREEN).
    키에 `guard` 를 넣는 이유가 정확히 이것이다.

    `scan()` 을 재사용한다(재도출 아님) — "실제 버리는 분기"의 정의가 배선
    락 본체와 갈리면 이 검사 자체가 새 진실을 만든다.
    """
    repo = Path(repo_root)
    files = sorted({rel for (rel, _line, _id) in EXEMPT})
    abs_paths = [str(repo / rel) for rel in files if (repo / rel).is_file()]
    rows = scan(abs_paths) if abs_paths else []
    live = {exempt_key(str(Path(r["file"]).relative_to(repo)), r) for r in rows}
    return [k for k in EXEMPT if k not in live]


def comprehension_count(paths):
    """컴프리헨션 내포 수 — 요구가 아니라 회귀 축이다."""
    total = 0
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        total += sum(
            len(n.generators) for n in ast.walk(tree)
            if isinstance(n, (ast.ListComp, ast.SetComp,
                              ast.DictComp, ast.GeneratorExp)))
    return total


import re
from pathlib import Path

# `\b` 두 개 — 없으면 `import adjudicationXX` 도, `from adjudication_shim
# import` 도 매칭한다(최종 리뷰 A/m6). 소비자 모집단은 이 정규식이 정하므로
# 오탐 하나가 ㉮ 를 한 파일 늘려 다른 락의 코퍼스까지 흔든다.
_IMPORT_RE = re.compile(
    r'^\s*(?:from\s+adjudication\b\s+import|import\s+adjudication\b)', re.M)
_ANCHOR_RE = re.compile(r'consumer=([^\s·]+\.py)')

# 면제 인용의 «실질» 판정은 `cite.py` 하나가 진다 — L3(`check_slots`)가 같은
# 요구를 지므로 술어를 베끼면 다음 조임이 한쪽에만 닿는다(최종 리뷰 A/m1).
from cite import cited as _cited, uncited  # noqa: E402


def uncited_exemptions():
    """사유가 실질을 갖추지 못한 `EXEMPT` 항목 — 호출자가 RED 로 만든다."""
    return uncited(EXEMPT)


# 면제 «크기»의 회귀 축. 컴프리헨션이 `COMP_BASELINE` 을 갖는 것과 같은 이유다
# — 배선을 면제로 갈아 끼우는 우회가 조용하지 않게(최종 리뷰 A/m2). `note` 로만
# 내던 값에 기계 단언을 붙인다. 줄이는 것은 자유, 늘리려면 이 수를 올리는
# 커밋이 이유를 함께 적어야 한다.
EXEMPT_BASELINE = 17


def derive_consumers(repo_root):
    """회계 소비자(㉮) — 두 경로의 «합집합».

    import 하나로만 도출하면 «그 import 를 지우는 것»이 락에서 빠져나가는 길이
    된다. 앵커는 다른 파일(skill)에 살고 기존 락의 축 A(4)·B 가 그것을 이미
    전량 검사하므로, 피검자가 자기 파일을 고쳐서 두 번째 경로를 벗어날 수 없다.

    두 경로가 오늘 같은 집합을 내는 것이 합집합이 공허하지 않다는 증거는
    아니다 — 갈리는 순간이 회귀 신호이고 호출자가 두 값을 따로 기록한다.
    """
    repo = Path(repo_root)
    by_import, by_anchor = set(), set()

    for pat in ("plugins/*/scripts/*.py", "plugins/*/hooks/*.py"):
        for f in repo.glob(pat):
            if f.is_symlink() or not f.is_file():
                continue
            if _IMPORT_RE.search(f.read_text(encoding="utf-8")):
                by_import.add(str(f.relative_to(repo)))

    for pat in ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md",
                "plugins/*/agents/*.md"):
        for f in repo.glob(pat):
            if not f.is_file():
                continue
            for m in _ANCHOR_RE.finditer(f.read_text(encoding="utf-8")):
                cand = m.group(1)
                if (repo / cand).is_file():
                    by_anchor.add(cand)

    return sorted(by_import | by_anchor), sorted(by_import), sorted(by_anchor)
