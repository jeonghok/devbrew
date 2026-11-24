# 테스트 기준이 생겼다 — 받는 쪽마다 달라지는 것

이 레포에 테스트 기준 문서 `docs/testing.md` 가 생겼다. 테스트를 쓰고 · 고치고 · 지우는 일의 기준이다. 아래는 받는 쪽마다 그 기준이 무엇을 달라지게 하는지다.

| 받는 쪽 | 달라지는 것 |
|---|---|
| 앞단 로드맵(`2026-11-14-framing-interview-constraint-audit-brief`) F5 의 남은 계획 2–4 | `docs/testing.md` 의 「글을 무는 확인」 절(글자 확인 기준)과 「망가뜨려 보기」 절(새 꼴)을 따른다. `shared/tests/test_charter_citations.sh` 에 확인 하나가 늘었다(그 로드맵이 `shared/tests/` 를 폴더째 예약했다). 계획 3 이 더하는 문구 테스트(`test_stage_prose_trim.sh`)는 아래 「문구 테스트의 예외」 대로다 |
| 같은 로드맵 F7 의 둘째 계획(`feature/switch-retirement`) | `CLAUDE.md` 에 항목 하나가 늘고 `docs/plugin-authoring.md` 의 한 줄이 바뀌었다 — 같은 문서를 고칠 때 합치기에서 본다 |
| 지휘 로드맵(`2026-11-14-conductor-context-economy-brief`) R5(`feature/conductor-migration`) | F7 의 둘째 계획과 같다 — `CLAUDE.md` 에 항목 하나가 늘고 `docs/plugin-authoring.md` 의 한 줄이 바뀌었다. 같은 문서를 고칠 때 합치기에서 본다 |
| 이 로드맵 E3 | `docs/testing.md` 「글을 무는 확인」 절의 「행동을 정하는 문장」 규칙 — 문구 확인을 걷은 자리를 지킬 장치는 이 규칙이 남긴 확인의 바깥을 맡는다 |
| 이 로드맵 E4 | 글자 확인 기준 — 「글을 무는 확인」 절의 「행동을 정하는 문장」 규칙은 E2 설계(`docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md`)가 정했다(E4 묶음이 열린 채 든 물음 OQ18 가운데 규칙은 닫혔고, 테스트마다 대어 보는 일이 E4 몫이다) · 가르는 차례(「값 대비 비용」 절) · 승인과 기록(「지우기 · 합치기 · 줄이기의 승인과 기록」 절 · `docs/removed-tests.md`) · 보안 갈래는 확인 단위로 가른다(「보안 갈래」 절) · 지운 것 기록의 자리와 꼴은 이 설계가 정했다(`docs/removed-tests.md` — E4 묶음이 열린 채 든 물음 OQ20 은 닫혔다) · 앞단 F5 계획 3 의 문구 테스트는 아래 「문구 테스트의 예외」 대로다 |

## 문구 테스트의 예외

앞단 F5 의 계획 3 이 더하는 `test_stage_prose_trim.sh` 는 문장 하나씩을 무는 확인이라 `docs/testing.md` 「글을 무는 확인」 절(가장 짧은 낱말을 문다)과 다르다. 사용자가 그 로드맵에서 그 테스트를 「의도다」 로 정했다고 앞단 지휘 세션이 2026-11-24 에 알렸다 — 그 답의 기록은 이 레포에서 확인하지 못했다. 사용자가 이 설계의 리뷰에서 정한 범위(2026-11-24): 있는 테스트 정리(E4)는 이 테스트를 가르는 차례(「값 대비 비용」 절)에 올리지 않는다. 다시 가르려면 사용자에게 묻는다.
