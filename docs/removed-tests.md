# 지운 테스트 기록

지운 테스트마다 한 줄을 남기는 파일이다. 언제 적는지는 [`docs/testing.md`](testing.md) 의 「지우기 · 합치기 · 줄이기의 승인과 기록」 을 따른다. 테스트를 빠져나간 실수를 고칠 때는 새 테스트를 쓰기 전에 그것을 지키던 테스트가 있었는지 여기서 먼저 찾는다.

줄의 꼴:

```
- <지운 날> · <테스트 파일[ · 케이스]> · 지키던 것: <한 문장 | 못 댐> · 판정: <`docs/testing.md` 「값 대비 비용」 의 어느 줄> · 지금 지키는 것: <테스트 경로 | 없음 — 받아들임> · PR #<번호>
```

## 항목
- 2026-11-26 · plugins/spec-distill/tests/test_epic_conductor_skill.sh 꺼짐 행 세 단언(56 · 65 · 66) · 지키던 것: 판독 표 `disabled` 행이 spec-distill 전체가 꺼졌다고 알리고 손 절차는 지휘자 없이 따르게 한다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 없음 — 받아들임(통째 끄기 은퇴로 그 행이 없다. 없음은 `shared/tests/test_switch_tables.sh` 절 E2 가 문다) · PR #미정
- 2026-11-26 · plugins/spec-distill/tests/test_request_framing_entry.sh 진입 단계 kill switch 두 단언 · 지키던 것: 진입 단계가 `disabled` 감시줄에서 멈추고 `DEVBREW_SPEC_DISTILL_DISABLE=1` 이름을 밝힌다 · 판정: 지우기(동작이 사라져 지킬 문장이 없음) · 지금 지키는 것: 없음 — 받아들임(없음은 `shared/tests/test_switch_tables.sh` 절 E2 가 문다) · PR #미정
