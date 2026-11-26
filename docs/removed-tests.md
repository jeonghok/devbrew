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
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py `test_nothing_set_proceeds` · 지키던 것: 무설정이면 알림이 없다 · 판정: 줄임(기대 꼴만 `{"disabled": False, "reason": None, "advisories": []}` 에서 `{"advisories": []}` 로 — 남는 동작은 그대로) · 지금 지키는 것: 같은 케이스 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py `test_each_retired_token_is_named_and_does_not_disable` · `test_autoreview_var_1_is_named` · 지키던 것: 은퇴 토큰 · `SKIP_AUTOREVIEW` 가 알림 한 줄을 내고 끄지 않는다 · 판정: 줄임(`assertFalse(out["disabled"])` 를 `assertEqual(list(out), ["advisories"])` 로 — 알림 개수 · 이름 단언은 그대로) · 지금 지키는 것: 같은 케이스 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_review_entry.py `test_review_retired_says_review_proceeds…` · 지키던 것: 옛 토큰 알림이 리뷰는 진행된다고 하고 대신할 길 이름을 댄다 · 판정: 줄임(`DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DESIGN_MODE_DISABLE=1` 단언을 `/spec-distill:spec-review` · `플러그인 끄기` 단언으로 — G5 가 바뀜. 「더 이상 리뷰를 막지 않는다」 · 「이번 리뷰는 진행된다」 단언은 그대로) · 지금 지키는 것: 같은 케이스 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 스텁 행렬 · 지키던 것: 계약을 어기면 멈추고 정상이면 PROCEED · 판정: 줄임(스텁 JSON 을 `{"disabled": false, "reason": null, "advisories": …}` 에서 `{"advisories": …}` 로 — 계약 위반 행은 그대로) · 지금 지키는 것: 같은 행렬 · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_control_plane.sh 끄기 스위치(AC6) 단락 · 변이 `switch`(`if switch_name():` 를 `if False:`) · 지키던 것: 통째 끄기 · 지도 토큰이면 상태줄은 빈 줄, show 는 `꺼져 있다 — <스위치>` 한 줄, `show --tasks` 는 rc 3, 꺼져 있으면 상태 계산을 부르지 않는다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 같은 파일 「은퇴한 끄기 변수는 듣지 않는다(AC18)」 단락(변수 · 토큰을 켜도 상태줄 · show 출력이 변수 없을 때와 같고 `show --tasks` rc 가 0 이다) · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_kill_switches_v060.sh 스위치 다섯 케이스(29-49) · plugins/spec-distill/tests/test_ledger_sweep.py `test_kill_switches_spare_everything` · 지키던 것: 통째 끄기 · 옛 토큰 셋이 원장 정리를 끈다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음 — 같은 자리를 반대 뜻으로 고쳐 씀) · 지금 지키는 것: 같은 케이스 · `test_retired_switches_do_not_spare` 가 같은 변수 · 토큰으로 정리가 그대로 도는 것을 문다 · PR #미정
