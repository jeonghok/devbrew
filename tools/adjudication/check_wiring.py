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

# T6b — `docreview_route.py`의 아홉 자리. **인과관계 정정(재리뷰 F-3)**: 이
# 파일이 이 락의 모집단에 처음 들어온 것은 이 태스크의 symlink 수정이 아니라
# Task 6이다 — `reviewing-spec/SKILL.md`에 `consumer=plugins/spec-distill/
# scripts/docreview_route.py` 앵커를 더한 그 커밋이 이 파일을 `by_anchor`
# 경유로 `union`에 처음 넣었다(52591c9b 시점에 이미 `unwired=9`였다 — 이
# 태스크가 착수하기 전). check_wiring.py의 symlink skip 제거(Ruling 8)가
# 한 일은 같은 파일을 IMPORT 쪽에서도 보이게 한 것과, 그 결과 quality-gates
# 배포 사본까지 union에 끌어들인 것뿐이다. `_dedup_by_realpath()`(F-2)가
# 두 배포 지점을 하나로 접으므로 아홉 자리에 아홉 키만 쓴다 — 대표 경로는
# `plugins/quality-gates/scripts/docreview_route.py`("q" < "s"로 union 정렬
# 순서상 먼저 온다).
_DR_PERMIT_SEARCH = (
    "C6(1) — `_permit_covers()` 는 `st[\"permits\"]` 를 도는 존재검사 헬퍼다 "
    "(리뷰 대상 finding 이 아니라 permit 레코드를 순회한다). 일치하는 permit 을 "
    "찾으면 `return True` 로 끊고, 못 찾으면 루프가 끝까지 돌아 `return False` "
    "로 떨어진다 — 어느 쪽도 판정 대상 항목을 버리지 않는다. 처분을 낼 "
    "대상 자체가 없는 탐색 루프다."
)
_DR_ABSORB_GROUP_DEAD = (
    "C6(1) — `_absorb_same_as()` 의 그룹 순회. `live`(그룹 안에서 아직 "
    "`_rejected` 가 아닌 멤버)가 비면 대표를 고를 대상이 없어 `continue` 하지만, "
    "그 그룹의 멤버는 전부 이미 `_rejected` 이고 그 표시는 `_apply_recritic()` "
    "에서 `it[\"_rejected\"] = ...` 와 **같은 자리에서** `L.reject(f, ...)` 가 "
    "함께 불려 이미 회계됐다(:229-230) — 이 continue 는 이미 처분된 항목을 "
    "대표-선정에서만 제외할 뿐 새로 버리는 항목이 없다."
)
_DR_ABSORBED_ALREADY = (
    "C6(1) — `_classify_items()` 의 `if it.get('_absorbed_into'): continue`. "
    "`_absorbed_into` 는 `_absorb_same_as()` 가 대표를 정할 때 **같은 자리에서** "
    "`L.absorbed(m, into=keep)` 와 함께 대입된다(:316-317) — 이 continue 시점엔 "
    "이미 회계가 끝난 항목이다."
)
_DR_REJECTED_ALREADY = (
    "C6(1) — `_classify_items()` 의 `if it.get('_rejected'): continue`. "
    "`_rejected` 는 `_apply_recritic()` 에서 `L.reject(f, ...)` 와 같은 자리에서 "
    "대입된다(:229-230) — 이미 회계된 항목이고, 이 continue **직전** 세 줄이 "
    "그 항목을 `rejected_items` 에 담아 반환값에 실어(:332-334) 파이프라인에서도 "
    "사라지지 않는다(continue 이전에 보존이 먼저 실행된다)."
)
_DR_ESCALATED_NOT_DUE = (
    "C6(1) — `_auto_decides()` 의 escalated 예약 순회. 아직 자기 라운드가 아닌 "
    "예약(Task 2 갱신 — `int(e['round']) >= n`, 이번 라운드 이후에 생긴 예약)은 "
    "`continue` **직전** `keep_esc.append(e)` 로 이미 보존돼 "
    "`st['escalated'] = keep_esc` 로 다음 라운드까지 살아남는다 — "
    "이번 라운드에 못 골랐다고 사라지는 게 아니라 다음 라운드의 "
    "같은 순회에 다시 나타난다. Task 2 이전엔 조건이 `!= n - 1`(정확히 직전 "
    "라운드의 예약만 소비)이라 `finalize` 가 이 루프 전에 조기 반환한 라운드가 "
    "하나라도 끼면 그 예약의 라운드 번호가 영원히 어긋나 소비도 계수도 안 되는 "
    "결함이 있었다(형제 reraise, AC21 이 같은 결함을 먼저 닫았다) — 조건을 "
    "`>= n` 으로 바꿔 「이번 라운드보다 앞선 예약 전부」를 소비 대상으로 삼는다. "
    "이 continue 자체의 회계 성질(보존됨, 소실 아님)은 조건이 바뀌어도 그대로다."
)
_DR_ESCALATED_TARGET_GONE = (
    "C6(1) — `if not f0: esc_unconsumed += 1; continue`(Task 2 갱신). 이 자리는 "
    "`esc_unconsumed` 를 **직접 증가**시켜 셈을 남기지만(주석 원문: \"대상 "
    "finding 부재 — 버리지 않고 센다\"), 그 카운터는 `Ledger` 의 처분 어휘"
    "(accept/reject/hold/absorbed/coerced/source_failed/uncountable/suppressed) "
    "가 아니라 route 자체의 별도 advisory 채널이다 — `stats['escalated_unconsumed']` "
    "가 `_build_report()` 를 거쳐 출력 JSON 의 `escalated_unconsumed` 필드로 "
    "그대로 공시된다 — 형제 `_DR_RERAISE_TARGET_GONE` 과 문자 그대로 같은 "
    "이유·같은 모양이다. **Task 2 이전엔 이 자리가 도달 불가능한 방어였다** — "
    "`st['findings']` 는 `record_findings()` 에서만 채워지고(docreview_state.py) "
    "지우는 코드 경로가 없어(설계 §6.4, 상태는 여섯으로 닫혀 전이만 한다), "
    "escalated 로 예약될 수 있는 finding_id 는 전부 이미 `st['findings']` 에 "
    "있었다 — 그 결론(production 경로에서 `f0` 부재는 지금도 도달 불가) 자체는 "
    "바뀌지 않았다. 그런데도 CLAUDE.md 의 요구(\"판정기가 항목을 버리면 센다\")를 "
    "형제(reraise)와 같은 강도로 만족시키기 위해 defense-in-depth 카운터를 "
    "더했다 — `_permit_covers()` 와 같은 이유(위 `_DR_PERMIT_SEARCH`)로 여기 "
    "순회 대상(`escalated` 예약)도 리뷰 대상 finding 이 아니라 스케줄링 레코드다."
)
_DR_ESCALATED_FIX_NOT_LIVE = (
    "C6(1) — `if not fx0 or fx0.get('state') != 'escalated': continue`(F-2/F-3 "
    "재리뷰 Ruling 20, 형제 `_DR_RERAISE_ALREADY_DECIDED`(아래, `if not d0 or "
    "d0.get('state') != 'expired'`)와 같은 모양·같은 이유). `f0` 존재만으로는 이 "
    "fix 가 «지금도» escalated 상태인지 모른다 — Task 2 의 누적(`>= n`)이 소비 "
    "창을 1 라운드에서 무한대로 넓혀, 예약이 만들어진 뒤 사용자가 `cmd_fix` 의 "
    "`event=drop`(상태 검사 없이 무조건 대입, docreview_state.py 의 `cmd_fix` 안 "
    "\"drop\" 갈래)이나 `event=intent-pass`(같은 무조건 대입, \"intent-pass\" "
    "갈래)로 그 fix 를 escalated 밖으로 옮겼을 수 있다(F-3 실측: drop 뒤에도 옛 "
    "예약이 소비돼 후속을 부활시켰다). [Task 4 fix round 1 — 리뷰 M2] 이 두 갈래를 "
    "줄번호가 아니라 함수·갈래 이름으로 가리킨다 — 이 파일 위쪽이 늘 때마다 "
    "리터럴 번호가 다시 stale 해지는 것을 리뷰가 두 번 잡았다(cases.sh 의 같은 "
    "인용도 이미 이 모양으로 고쳐져 있다). "
    "형제 주석이 이미 결론을 적어 뒀다 — 사용자가 이미 다른 처분을 내렸으면 그 "
    "처분이 의무를 진다: 버려지는 새 항목이 없다."
)
_DR_RERAISE_TARGET_GONE = (
    "C6(1) — `if not f0: reraise_unconsumed += 1; continue`. 이 자리는 "
    "`reraise_unconsumed` 를 **직접 증가**시켜 셈을 남기지만(주석 원문: \"대상 "
    "finding 부재 — 버리지 않고 센다\"), 그 카운터는 `Ledger` 의 처분 어휘"
    "(accept/reject/hold/absorbed/coerced/source_failed/uncountable/suppressed) "
    "가 아니라 route 자체의 별도 advisory 채널이다 — `stats['reraise_unconsumed']` "
    "가 `_build_report()` 를 거쳐 출력 JSON 의 `reraise_unconsumed` 필드로 "
    "그대로 공시된다(:566 `out = _build_report(...)`, `_build_report()` "
    "본문의 같은 이름 필드). CLAUDE.md 의 요구(\"판정기가 항목을 버리면 "
    "센다\")를 만족하는 자리이지 Ledger 소비 대상이 아니다 — `_permit_covers()` "
    "와 같은 이유(위 `_DR_PERMIT_SEARCH`)로 여기 순회 대상(`reraise` 예약)도 "
    "리뷰 대상 finding 이 아니라 스케줄링 레코드다."
)
_DR_RERAISE_ALREADY_DECIDED = (
    "C6(1) — `if not d0 or d0.get('state') != 'expired': continue`. 코드 "
    "자신의 주석이 이미 결론을 적어 뒀다: \"사용자가 이미 재결정했다 — "
    "의무는 그 결정이 진다.\" `state != 'expired'` 는 그 finding 의 `decides` "
    "레코드가 이미 다른 상태(adopted·rejected·held·applied)로 전이됐다는 "
    "뜻이고, 그 전이 자체가 그 finding 의 최종 처분이다 — 재상승 후속을 또"
    "내면 이미 끝난 결정 위에 유령 항목을 만드는 쪽이 오류다. 버려지는 새 "
    "항목이 없다."
)
_DR_LINEAGE_NOT_RERAISE = (
    "C6(1) — `_resolve_ids_and_lineage()` 의 전방 포인터 루프"
    "(`if it.get('_source') != 'reraise'): continue`). 이 시점의 `it` 는 이미 "
    "직전 루프(:446-451)에서 id·bucket 을 배정받아 처분이 끝난 항목이다 — 이 "
    "두 번째 루프는 `_source == 'reraise'` 인 항목에만 적용되는 **추가** "
    "부기(만료된 `decides` 레코드에 `superseded_by` 전방 포인터를 단다)이고, "
    "그 조건에 안 맞는 항목은 이 부기가 필요 없을 뿐 그 항목 자체가 버려지는 "
    "것이 아니다."
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
    # `advisory.extend(L.reasons())` 로, "held_by_class" 는 loop 직후
    # 세 줄로 각각 실린다 — 버려지는 항목이 없다.
    ("plugins/spec-distill/scripts/merge_brief_review.py", 363,
     "continue in main @ if _k in ('reasons', 'held_by_class')"):
        "C6(1) — disposition_report().items() 를 도는 이 continue 는 "
        "\"reasons\"·\"held_by_class\" 두 키를 이 loop 에서만 제외한다. "
        "\"reasons\" 는 이 loop 이전에 이미 `advisory.extend(L.reasons())` "
        "로, \"held_by_class\" 는 loop 직후 세 줄(held_unadjudicated/"
        "held_malformed/held_other)로 각각 실린다 — 버려지는 항목이 없다.",

    # Task 11b Step 1~3 — 계획이 배정하지 않았던 네 자리(merge_review.py).
    # PR1 배선 baseline=14, T1-A/T1-B 가 (삭제된) 설계문서 리뷰 훅 열을 닫아 남긴 게
    # 이 넷이었다(원 계획 전제). 넷 다 판단 결과는 «배선 불필요» — 근거는
    # 자리마다 다르다(보고서 `.superpowers/sdd/2026-09-03-adjudication-topology/
    # task-11b-report.md` 에 각 자리의 세 질문 답변).
    #
    # 헤더 두 자리 — parse_codex_yaml() 의 `for raw in lines:` 는 codex YAML
    # 파일의 «텍스트 줄» 을 도는 라인 파서 루프다. 원소는 판정 항목(finding)
    # 이 아니라 원문 줄이고, 두 continue 는 YAML 섹션 헤더(`findings:`·
    # `meta:`) 를 만났을 때 상태 전이만 하고 다음 줄로 넘어간다 — 그 줄
    # 자체가 finding 이 아니므로 버릴 항목이 없다. `meta:` 쪽은 오히려 반대
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
    # fold 조기 종료 — derive_codex_verdict() 는 `codex_findings` 전체에 대한 단일
    # 집계값(verdict 문자열)을 접는(fold) 함수다. 첫 escalating finding 에서
    # `return "needs_revise"` 로 끊지만, 순회를 멈춘다고 나머지 finding 이
    # 파이프라인에서 사라지지 않는다 — 호출자가 들고 있는 같은 `codex_findings`
    # 리스트가 이 함수와 무관하게 build_ledger() 의 `for f in codex_findings:`
    # (이미 배선됨 — codex_ledger.hold() 뒤 continue) 로 전수
    # 다시 돌며, category·target_section 둘 다 없는 원소는 거기서 hold() 된다.
    # 표시 채널(build_codex_findings_display)도 이 함수와 별개로 같은 전체
    # 리스트를 돈다. 즉 이 fold 가 일찍 멈춰도 "판정에 영향을 주는 값"은
    # 동일하고(max 류 단조 집계라 나머지를 봐도 결론이 안 바뀐다), 개별
    # finding 의 회계는 이미 build_ledger() 의 그 루프가 맡는다.
    ("plugins/spec-distill/scripts/merge_review.py", 229,
     'return in derive_codex_verdict @ if sev in CODEX_SEVERITY_REVISE or sev not in CODEX_SEVERITY_KNOWN'):
        "C6(1) — derive_codex_verdict() 의 fold 조기 종료. `codex_findings` "
        "전체는 이 함수와 무관하게 build_ledger() 의 `for f in codex_findings:` "
        "(이미 배선 — codex_ledger.hold() 뒤 continue) 가 "
        "전수 다시 돌아 개별 회계하고, build_codex_findings_display() 도 같은 "
        "전체 리스트를 별도로 순회해 표시한다 — 이 fold 가 멈춰도 미방문 "
        "finding 이 파이프라인에서 사라지지 않는다. 결론(needs_revise)도 "
        "단조 집계라 나머지를 마저 봐도 바뀌지 않는다.",
    # 도달 불가능한 방어 — build_codex_findings_display() 의
    # `if not isinstance(f, dict): continue`. 이 함수의 유일한 호출자 main() 은
    # 항상 parse_codex_yaml() 의 반환값을 그대로 넘기고(그 둘 사이에
    # 변형 없음), parse_codex_yaml() 의 `findings` 리스트는 `cur = {}` 로만
    # 생성되고 dict 항목 대입(`cur[k] = v`)만 받는다 — 코드 어디에도 `cur` 를
    # dict 아닌 값으로 덮어쓰는 경로가 없다(코드 확인 완료). 배선하면 Task 10
    # 의 `phase_key` 와 같은 죽은 코드가 된다.
    ("plugins/spec-distill/scripts/merge_review.py", 270,
     'continue in build_codex_findings_display @ if not isinstance(f, dict)'):
        "C6(1) — 도달 불가능한 방어. 유일한 호출자 main() 은 parse_codex_"
        "yaml() 의 반환값을 변형 없이 그대로 넘기고, 그 함수의 `findings` "
        "는 `cur = {}` 로만 생성돼 dict 항목 대입만 받는다 — 비-dict 원소를 "
        "만드는 경로가 코드에 없다(확인 완료). 배선하면 죽은 코드다(Task 10 "
        "의 `phase_key` 와 같은 함정).",

    # T6b — docreview_route.py 아홉 자리. spec-distill·quality-gates 두 호스트에
    # 같은 물리 파일이 심볼릭 링크로 배포되지만(설계 §12) `scan()`/`comprehension_
    # count()`는 F-2(재리뷰)의 `_dedup_by_realpath()`로 실제 내용을 한 번만
    # 읽는다 — 대표로 남는 경로는 `union`의 정렬 순서상 먼저 오는
    # `plugins/quality-gates/scripts/docreview_route.py`("q" < "s")다. 그래서
    # 키도 아홉 개면 된다(호스트마다 다시 등록하지 않는다) — 두 배포 지점이
    # 갈리지 않는다는 보장은 `shared/tests/test_copy_of_contract.sh`의
    # ∀-dominance 축이 이미 진다. 사유는 위 `_DR_*` 상수 참조.
    # [Task 4 fix round 1 — 리뷰 M2] 줄번호는 매 재앵커마다 실측으로 갱신한다(아래
    # 열 자리 전부). 과거 델타를 프로즈에 «다시» 못박지 않는다 — 그 델타 자체가
    # 다음 삽입에서 또 stale 해지는, 리뷰가 잡은 바로 그 함정이다. 재앵커가 필요한
    # 이유(무엇이 위에서 늘었는가)만 남긴다: I1 정정(`_decision_view` 에 `st` 인자
    # 추가 + 헤더 주석)과 그 앞의 import 목록 확장이 이 파일 앞부분 줄 수를 늘렸다.
    ("plugins/quality-gates/scripts/docreview_route.py", 97,
     "return in _permit_covers @ if int(p['round']) == n and anchor in p['apply_anchors']"):
        _DR_PERMIT_SEARCH,
    # T6b — docreview_route.py 아홉 자리 나머지. 사유는 위 `_DR_*` 상수 참조.
    ("plugins/quality-gates/scripts/docreview_route.py", 328,
     "continue in _absorb_same_as @ if not live"): _DR_ABSORB_GROUP_DEAD,
    ("plugins/quality-gates/scripts/docreview_route.py", 347,
     "continue in _classify_items @ if it.get('_absorbed_into')"): _DR_ABSORBED_ALREADY,
    ("plugins/quality-gates/scripts/docreview_route.py", 352,
     "continue in _classify_items @ if it.get('_rejected')"): _DR_REJECTED_ALREADY,
    # Task 2 — escalated 예약을 재상승(AC21)과 대칭으로 맞추면서 줄번호가 밀렸다.
    # F-2/F-3 재리뷰(Ruling 20·21) 가 한 번 더 바꿨다: dedup continue(옛 404)는
    # `L.absorbed(...)` 를 같은 분기에서 직접 불러 **더 이상 면제가 필요 없다**
    # (`scan()` 이 그 호출을 disposition 으로 자동 인식해 guarded=True) — 그래서
    # 아래 목록에서 통째로 빠졌다(EXEMPT_BASELINE 주석 참조). 대신 F-3 이 새
    # discard 자리(fix 가 지금도 escalated 상태인지 검사)를 하나 늘렸다.
    ("plugins/quality-gates/scripts/docreview_route.py", 417,
     "continue in _auto_decides @ if int(e['round']) >= n"): _DR_ESCALATED_NOT_DUE,
    ("plugins/quality-gates/scripts/docreview_route.py", 422,
     "continue in _auto_decides @ if not f0"): _DR_ESCALATED_TARGET_GONE,
    ("plugins/quality-gates/scripts/docreview_route.py", 433,
     "continue in _auto_decides @ if not fx0 or fx0.get('state') != 'escalated'"):
        _DR_ESCALATED_FIX_NOT_LIVE,
    ("plugins/quality-gates/scripts/docreview_route.py", 458,
     "continue in _auto_decides @ if not f0"): _DR_RERAISE_TARGET_GONE,
    ("plugins/quality-gates/scripts/docreview_route.py", 469,
     "continue in _auto_decides @ if not d0 or d0.get('state') != 'expired'"):
        _DR_RERAISE_ALREADY_DECIDED,
    # Task 5 — 재상승 후속의 kind·prev_hash 승계 주석이 `_auto_decides` 재상승 갈래
    # 위에 끼어들며 아래로 밀렸다(옛 509 → fix round 1 M3 의 확장 주석까지 더해
    # 521). 가드 텍스트 자체는 그대로다.
    ("plugins/quality-gates/scripts/docreview_route.py", 521,
     "continue in _resolve_ids_and_lineage @ if it.get('_source') != 'reraise'"):
        _DR_LINEAGE_NOT_RERAISE,
}

# Task 11 수정 라운드 1 — `derive_consumers()` 의 import·앵커 대칭 가정이
# 깨지는 자리를 명시적으로 등재한다. 그 가정("원장을 import 하는 파일은
# 전부 어딘가 dispatch 자리에서 `consumer=` 로 불린다")은 PR1 이 넣은 것이다.
# 앵커(`consumer=`)는 skill/command/agent 문서가 "이 subagent 의 발견물을 이
# 스크립트가 판정한다"고 선언하는 자리인데, 원장을 import 하면서도 그렇게 불릴
# dispatch 자리가 없는 파일이 있다(아래 항목마다 사유). 없는 자리를 만들어
# 붙이면 그건 허구다. 첫 반례였던 설계문서 리뷰 훅(스스로 차단/통과를 정하던
# 종단 결정자)은 spec-distill 3.0.0 에서 삭제됐다.
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
    # T6b — reviewing-spec 껍데기화(Task 6)가 옛 spec-reviewer 참조를 끊으면서
    # 이 파일이 ANCHOR 를 잃었다(Ruling 9). `merge_brief_review.py:37` 이 여전히
    # `codex_degraded_from`·`derive_codex_verdict`·`parse_codex_yaml` 셋을 이
    # 파일에서 재사용 import 한다(try 로 감싼 degrade 경로라 지우면 그 사용처가
    # 조용히 축소된다) — 그래서 이 파일은 PR 3(브리프 리뷰 자리로의 전환)까지
    # 산다. 최소 조치로 두 후보를 견줬다: ① `reviewing-brief/SKILL.md` 의 기존
    # `consumer=merge_brief_review.py` 처분 줄에 이 파일도 얹기 — 기각한다.
    # `_ANCHOR_RE` 는 처분 줄 하나당 `consumer=` 하나만 잡고(정규식이 `\S+` 까지만
    # 먹는다), `test_dispatch_disposition.sh` 축 A①(앵커 수==dispatch 수, 실측
    # 22==22)·축 A②(각 dispatch 아래 창에 자기 앵커가 정확히 하나)가 앵커:dispatch
    # 1:1 을 이미 강제한다 — 기존 dispatch 옆에 두 번째 앵커를 얹으면 그 dispatch
    # 가 앵커 2개를 갖게 돼 축 A② 가 깨지고, 앵커만 늘리면 축 A① 이 깨진다. 이
    # 파일을 위해 «새 Agent() dispatch 자리»를 만드는 것은 허구다(CLAUDE.md —
    # 없는 자리를 만들어 붙이면 그건 허구). ② TERMINAL_CONSUMERS 등재 — 채택.
    # C6(2, 측정된 이유): 이 파일은 이제 어떤 skill/command/agent 도 subagent
    # dispatch 결과를 이 파일에 판정시키지 않는다(옛 dispatch 자리가 사라졌다) —
    # 순수 재사용 라이브러리로 변했다. 종단 결정자처럼 «원리적으로»
    # 앵커가 불가능한 것은 아니지만(재도입되면 앵커가 다시 생길 수 있다), «지금»
    # 은 대응하는 dispatch 자리가 없고 만들 근거도 없다는 점에서 결론(앵커 없음)
    # 은 같다.
    "plugins/spec-distill/scripts/merge_review.py":
        "C6(2) — Ruling 9(T6b). reviewing-spec 껍데기화가 옛 spec-reviewer "
        "dispatch 참조를 끊어 이 파일이 ANCHOR 를 잃었다. `merge_brief_review.py:37` "
        "이 여전히 이 파일에서 세 함수를 재사용 import 하므로(try-wrapped degrade "
        "경로) 파일은 PR 3 까지 산다(계획 File Structure 표). 기존 "
        "`reviewing-brief/SKILL.md` 의 `consumer=merge_brief_review.py` 처분 "
        "줄에 이 파일을 얹는 대안을 검토했으나 기각했다 — `test_dispatch_"
        "disposition.sh` 축 A①/A② 가 앵커:dispatch 1:1 을 이미 강제해서(실측 "
        "22==22) 기존 dispatch 옆에 두 번째 앵커를 얹으면 그 비율이 깨지고, 이 "
        "파일만을 위한 새 Agent() dispatch 자리를 만드는 것은 허구다. 지금은 "
        "어떤 skill 도 이 파일에 subagent 판정을 맡기지 않는다 — 대응하는 "
        "dispatch 자리가 없다.",
    # T6b — check_wiring.py 의 IMPORT 도출에서 심볼릭 링크 skip 을 뺐다(Ruling 8).
    # 그 전에는 이 파일이 by_import·by_anchor 어느 쪽에도 없어(둘 다 링크를 걸러
    # 냈거나 애초에 앵커가 없어) union 자체에 없었다 — 이번 확장이 처음으로
    # 드러낸 자리다. `plugins/spec-distill/scripts/docreview_route.py` 는
    # reviewing-spec/SKILL.md 가 `consumer=` 로 지목하지만, 같은 엔진의
    # quality-gates 배포 지점(`plugins/quality-gates/scripts/docreview_route.py`,
    # 같은 대상을 가리키는 별도 심볼릭 링크)은 아직 어떤 quality-gates skill 도
    # dispatch 하지 않는다 — 이 PR(T6b)이 wiring 하는 host 는 spec-distill
    # 하나뿐이고(brief Files 목록), quality-gates 쪽 진입 skill 변경은 범위 밖이다.
    "plugins/quality-gates/scripts/docreview_route.py":
        "C6(2) — T6b, check_wiring.py 심볼릭 링크 skip 제거(Ruling 8)가 처음 "
        "드러낸 자리. 같은 엔진 파일이 spec-distill 쪽엔 앵커가 있다"
        "(`reviewing-spec/SKILL.md` 의 `consumer=plugins/spec-distill/scripts/"
        "docreview_route.py`) — quality-gates 쪽은 아직 어떤 skill 도 이 엔진을 "
        "dispatch 하지 않는다(호스트가 아직 안 wiring됐다). 심볼릭 링크 배포는 "
        "두 호스트 모두에 미리 나가 있지만(설계 §12), quality-gates 진입 skill "
        "변경은 이 PR 의 Files 목록 밖이다 — 그 host 가 wiring 되면 이 등재는 "
        "지우고 실제 앵커로 바꿀 것.",
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


def _dedup_by_realpath(paths):
    """같은 물리 파일을 가리키는 여러 배포 경로(심볼릭 링크)를 하나로 접는다.

    F-2(T6b 재리뷰) — `docreview_route.py`가 spec-distill·quality-gates 두
    호스트에 심볼릭 링크로 배포되므로, 링크를 그대로 따라가며 스캔하면 같은
    아홉 개의 버리는 분기·같은 열여덟 개의 컴프리헨션을 호스트마다 다시 세게
    된다 — `EXEMPT` 등록도 아홉이 아니라 열여덟이 필요해지고, 세 번째 호스트가
    같은 파일을 배포하면 스물일곱이 된다(등록이 배포 지점 수에 비례해 자라는
    건 나열이지 도출이 아니다). `derive_consumers()`의 `union`(경로별로 성립해야
    하는 축 — ANCHOR는 `consumer=`가 앵커의 플러그인과 같아야 하므로 경로
    자체가 의미 있다, `test_dispatch_disposition.sh` 축 A⑤)은 그대로 두고,
    **내용을 실제로 읽는 이 함수와 `comprehension_count()`에서만** 같은 실제
    파일을 중복으로 열지 않게 거른다.

    대표로 남기는 것은 realpath 자체가 아니라 **먼저 나온 원래 인자**다 —
    realpath를 `"file"`로 쓰면 `run_wiring_scan.py`의 `Path(r["file"]).
    relative_to(root)`가 `root` 자신이 심볼릭 링크를 거치는 환경(worktree 등)
    에서 갈릴 수 있다. 정체(`exempt_key`의 kind·func·guard)는 어느 배포
    경로를 대표로 남기든 바이트가 같으므로 동일하다 — 두 링크가 갈리지
    않는다는 보장은 `shared/tests/test_copy_of_contract.sh`의 ∀-dominance
    축이 이미 지므로, 여기서 두 번 세는 것은 그 보장을 다시 사는 게 아니라
    같은 사실을 중복 기록하는 것뿐이다.
    """
    seen_real = set()
    out = []
    for p in paths:
        real = str(Path(p).resolve())
        if real in seen_real:
            continue
        seen_real.add(real)
        out.append(p)
    return out


def scan(paths):
    """버리는 분기 전수. 각 항목은 guarded 여부를 함께 낸다.

    분기 «노드»에서 출발한다 — 루프에서 출발해 하위를 훑으면 중첩 루프 안의
    한 문장이 바깥·안쪽 양쪽에 귀속돼 두 번 세어진다.

    F-2: 심볼릭 링크로 같은 물리 파일을 여러 번 배포한 경우 `_dedup_by_
    realpath()`가 한 번만 읽는다.
    """
    out = []
    for path in _dedup_by_realpath(paths):
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
    실증했다: 앞선 두 커밋이 설계문서 리뷰 훅(spec-distill 3.0.0 에서 삭제)의
    선택 함수 위에 코드를 늘려 그 함수가 +13/+14 줄 밀렸고 열 개의 키가 통째로
    낡았다. 밀린 줄이 아무것도
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


def stale_terminal(repo_root):
    """`TERMINAL_CONSUMERS`의 신선도 — `stale_exempt()`와 같은 목적(F-2 재리뷰).

    항목은 자기 파일이 지금도 IMPORT이고 아직 ANCHOR가 없을 때만 유효하다.
    두 방향의 낡음: 파일이 지워지면(PR 3의 merge_review.py 등) IMPORT에서
    빠지고, 호스트가 wiring되면(quality-gates docreview_route.py 등) ANCHOR가
    새로 생긴다 — 둘 다 원래의 등재 사유를 무효화한다. `derive_consumers()`를
    재사용한다(재도출 아님).
    """
    _, by_import, by_anchor = derive_consumers(repo_root)
    stale = [(p, "import_gone") for p in TERMINAL_CONSUMERS if p not in by_import]
    stale += [(p, "anchor_now_exists") for p in TERMINAL_CONSUMERS if p in by_anchor]
    return stale


def comprehension_count(paths):
    """컴프리헨션 내포 수 — 요구가 아니라 회귀 축이다.

    F-2: `scan()`과 같은 이유로 `_dedup_by_realpath()`를 거친다 — 아니면
    심볼릭 링크로 배포된 같은 파일의 컴프리헨션이 호스트 수만큼 중복 계상된다.
    """
    total = 0
    for path in _dedup_by_realpath(paths):
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
from cite import uncited  # noqa: E402


def uncited_exemptions():
    """사유가 실질을 갖추지 못한 `EXEMPT` 항목 — 호출자가 RED 로 만든다."""
    return uncited(EXEMPT)


# 면제 «크기»의 회귀 축. 컴프리헨션이 `COMP_BASELINE` 을 갖는 것과 같은 이유다
# — 배선을 면제로 갈아 끼우는 우회가 조용하지 않게(최종 리뷰 A/m2). `note` 로만
# 내던 값에 기계 단언을 붙인다. 줄이는 것은 자유, 늘리려면 이 수를 올리는
# 커밋이 이유를 함께 적어야 한다.
#
# T6b — 17 → 26. **인과관계 정정(재리뷰 F-3)**: `docreview_route.py`가 이
# 락의 모집단에 처음 들어온 것은 Task 6이다(`reviewing-spec/SKILL.md`의
# `consumer=` 앵커 추가) — 52591c9b 시점에 이미 `unwired=9`였고, 이 태스크가
# 손대기 전부터 그 아홉 자리는 미배선 RED였다. 이 태스크가 한 일은 그 아홉
# 자리에 근거를 달아 등재해 RED를 닫은 것이다(각 자리 근거는 위 `_DR_*`
# 상수). 배포는 spec-distill·quality-gates 두 호스트에 같은 물리 파일을
# 심볼릭 링크로 하지만, `_dedup_by_realpath()`(F-2)가 `scan()`/`comprehension_
# count()`에서 그 중복을 접으므로 키는 «호스트 수와 무관하게» 아홉이면
# 된다(17+9=26) — 세 번째 호스트가 같은 파일을 배포해도 이 수는 늘지 않는다.
# 배선을 면제로 «갈아 끼운» 것이 아니라 실제로 이미 다른 자리에서
# 회계됐거나(같은 대입 지점에서 `L.reject`/`L.absorbed` 동시 호출) 판정 대상
# 자체가 없는(permit/reraise 스케줄링 탐색) 자리들이다.
#
# Task 2 — 26 → 27 → (F-2/F-3 재리뷰) 그대로 27, 그러나 구성이 갈렸다.
#
# 최초 커밋(fc516eb2)은 dedup continue(`if e['finding_id'] in esc_seen`)를
# `_DR_ESCALATED_DEDUP` 으로 면제해 26→27 을 만들었다. 재리뷰 F-2(Ruling 21)가
# 그 선택을 뒤집었다 — CLAUDE.md 「흡수(dedup)…계수하되 그 자체로 degrade 는
# 아니다」는 면제가 아니라 **계수**를 요구한다. dedup 분기가 이제 같은 자리에서
# `L.absorbed(...)` 를 직접 부르므로(다른 dedup — `_absorb_same_as()` — 와 같은
# 처분 어휘) `scan()` 이 그 호출을 disposition 으로 자동 인식해 더는 면제가
# 필요 없다 — 그래서 −1(27→26).
#
# 같은 재리뷰의 F-3(Ruling 20)이 별도 결함을 고치며 새 discard 자리를 하나
# 늘렸다: escalated 후속을 만들기 전에 그 fix 가 «지금도» escalated 상태인지
# 검사한다(`_DR_ESCALATED_FIX_NOT_LIVE`) — 형제 `_DR_RERAISE_ALREADY_DECIDED`
# 와 같은 이유로 면제 대상이다(사용자의 다른 처분이 의무를 진다, 소실 없음).
# 그래서 +1(26→27).
#
# 순증가는 0 이지만 두 변경이 우연히 상쇄된 것이지 손대지 않은 것이 아니다 —
# `docreview_route.py` 몫은 여전히 아홉 자리지만 구성원이 하나 바뀌었다(dedup
# 나가고 fix-liveness 들어옴). 무엇이 지금 등재돼 있는지는 위 `_DR_*` 상수를
# 직접 읽어라.
#
# spec-distill 3.0.0 — 27 → 17. 설계문서 리뷰 훅이 삭제되며 그 파일의 면제 열 자리가
# 대상과 함께 사라졌다. 줄인 것이지 면제로 옮긴 것이 아니다 — 값은 손으로 빼지 않고
# 삭제 뒤 스캔의 `exempt_total` 로 재계수했다.
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
            # 심볼릭 링크로 배포된 스크립트도 IMPORT 모집단이다. `is_file()` 은
            # 링크를 따라가므로 대상이 실재 파일이면 여기 든다 — 링크만 걸러내면
            # (예전의 `f.is_symlink() or`) ANCHOR 도출(아래, `(repo / cand).is_file()`
            # 로 링크를 그대로 받는다)과 비대칭이 생겨, 심볼릭 링크로 배포된 엔진
            # 스크립트를 `consumer=` 로 지목하는 순간 구조적으로 ANCHOR ⊆ IMPORT 를
            # 어긴다. 같은 결함을 `plugins/quality-gates/tests/lib/
            # extract_codex_invocations.py` 가 이미 한 번 고쳤다(2026-09-08 이전,
            # 그 파일의 `is_symlink()` skip 제거 주석 참조) — 도구만 바꿔 재발한
            # 것이므로 같은 방식으로 고친다. `is_file()` 은 대상이 없는 깨진 링크는
            # 여전히 걸러낸다(끊어진 링크를 읽으려 들면 죽는다).
            if not f.is_file():
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
