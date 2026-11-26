# 지운 테스트 기록

지운 테스트마다 한 줄을 남기는 파일이다. 언제 적는지는 [`docs/testing.md`](testing.md) 의 「지우기 · 합치기 · 줄이기의 승인과 기록」 을 따른다. 테스트를 빠져나간 실수를 고칠 때는 새 테스트를 쓰기 전에 그것을 지키던 테스트가 있었는지 여기서 먼저 찾는다.

줄의 꼴:

```
- <지운 날> · <테스트 파일[ · 케이스]> · 지키던 것: <한 문장 | 못 댐> · 판정: <`docs/testing.md` 「값 대비 비용」 의 어느 줄> · 지금 지키는 것: <테스트 경로 | 없음 — 받아들임> · PR #<번호>
```

## 항목
- 2026-11-26 · plugins/spec-distill/tests/test_epic_conductor_skill.sh 꺼짐 행 세 단언(56 · 65 · 66) · 지키던 것: 판독 표 `disabled` 행이 spec-distill 전체가 꺼졌다고 알리고 손 절차는 지휘자 없이 따르게 한다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 없음 — 받아들임(통째 끄기 은퇴로 그 행이 없다. 없음은 `shared/tests/test_switch_tables.sh` 절 E2 가 문다) · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_request_framing_entry.sh 진입 단계 kill switch 두 단언 · 지키던 것: 진입 단계가 `disabled` 감시줄에서 멈추고 `DEVBREW_SPEC_DISTILL_DISABLE=1` 이름을 밝힌다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 없음 — 받아들임(없음은 `shared/tests/test_switch_tables.sh` 절 E2 가 문다) · PR #미정
- 2026-11-26 · shared/tests/test_cost_disclosure.sh RC14 epic-conductor kill switch(119) · 지키던 것: epic-conductor SKILL 에 통째 끄기 변수 이름이 적혀 있다 · 판정: 줄임(은퇴 리터럴만 뺌 — 같은 파일의 나머지 RC14 단언은 그대로) · 지금 지키는 것: 없음 — 받아들임(은퇴한 이름이 skill 에 남지 않는 것은 AC18 의 몫) · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py 끄기 판정 여섯 케이스(전역 · review-entry 토큰 · 토큰 + 공백 목록 · 설계 모드 · `=0` · 부분 문자열 토큰) · 지키던 것: 진입 검사가 세 스위치로 리뷰를 끈다 · `=0` 과 부분 문자열은 끄지 않는다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: `test_review_entry.py` `test_retired_switches_do_not_disable` · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py `test_review_retired_with_live_switch_states_why_off` · `test_review_retired_with_entry_token_in_same_list` · 지키던 것: 살아 있는 끄기 스위치가 함께 켜지면 옛 토큰 알림이 「…때문에 꺼졌다」 를 말한다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 없음 — 받아들임(끄기 판정이 없어 늘 「이번 리뷰는 진행된다」 다. 은퇴 이름이 리뷰를 끄지 않는 것은 `test_retired_switches_do_not_disable` 가 문다) · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py `test_advisories_point_only_at_live_switches` · 지키던 것: 알림이 권하는 스위치는 전부 살아 있는 끄기 스위치다 · 판정: 줄임(권할 끄기 변수가 없어져 뜻이 뒤집힘 — 대신 `test_alternatives_name_no_retired_switch` 가 알림에 은퇴 이름이 없고 새 길이 있음을 문다) · 지금 지키는 것: `plugins/spec-distill/tests/test_review_entry.py` · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 정본 행 셋(전역 끔 · review-entry 토큰 · design 모드 끔)의 `DISABLED:<이름>` 판결 · 지키던 것: 정본 펜스가 세 스위치를 `DISABLED:<이름>=1` 로 내고 끈 이름을 판결 줄 밖에서도 댄다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 같은 파일의 「정본: 은퇴 …」 행이 세 이름 모두 `review-entry: PROCEED` 를 문다 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 스텁 행렬의 `disabled` · `reason` 행(disabled 문자열 · disabled 정수 · reason 키 없음 · reason 정수 · reason 개행 주입 · 정상 true · 정상 true + advisory) · 지키던 것: 스텁이 `disabled: true, reason: …` 를 내면 펜스가 `DISABLED:<사유>` 를 내고 끈 이유를 판결 줄 밖에 댄다 · 두 키의 꼴을 어기면 멈춘다 · 판정: 지우기(출력 계약에서 두 키가 빠져 지킬 문장이 없음) · 지금 지키는 것: 같은 행렬의 `{}` · advisories 꼴 · 개행 주입 행이 계약 위반을 문다 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh 전역 kill switch 이름 단언(44) · 지키던 것: spec-review 표면에 `DEVBREW_SPEC_DISTILL_DISABLE=1` 이 이름으로 공시된다 · 판정: 줄임(통째 끄기 은퇴 — codex 전용 스위치 · 캐시 계약 단언은 그대로) · 지금 지키는 것: 없음 — 받아들임(은퇴한 이름이 skill 에 남지 않는 것은 AC18 의 몫) · PR #미정
