# 지운 테스트 기록

지운 테스트마다 한 줄을 남기는 파일이다. 언제 적는지는 [`docs/testing.md`](testing.md) 의 「지우기 · 합치기 · 줄이기의 승인과 기록」 을 따른다. 테스트를 빠져나간 실수를 고칠 때는 새 테스트를 쓰기 전에 그것을 지키던 테스트가 있었는지 여기서 먼저 찾는다.

줄의 꼴:

```
- <지운 날> · <테스트 파일[ · 케이스]> · 지키던 것: <한 문장 | 못 댐> · 판정: <`docs/testing.md` 「값 대비 비용」 의 어느 줄> · 지금 지키는 것: <테스트 경로 | 없음 — 받아들임> · PR #<번호>
```

## 항목

- 2026-11-28 · plugins/quality-gates/tests/test_artifact_metadata.sh · 지키던 것: plugin.json 판 바닥 2.11 · CHANGELOG [2.11.0] · 옛 skill 이름 · README 낱말 둘 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_cost_consent.sh (+ plugins/quality-gates/tests/harness/run_consent_gate.sh) · 지키던 것: 테스트 쪽 흉내 하네스가 마커 없을 때만 질문을 쓴다(플러그인 코드 0) · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_impact_runtime_docs.sh · 지키던 것: major ≥3 · CHANGELOG [3.0.0] 섹션 · README 구조 트리 · 원칙 LD 줄 · 새 스크립트 셋 실행 비트 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: shared/tests/test_test_selection_bundle.sh (실행 비트) · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_readme_state_diagram_complete.sh · 지키던 것: README 도식 하나 · 표지 열 · 옛 표지 여덟 부재 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py · 지키던 것: Ledger(items=closed) 가 미판정을 빼되 막음 · phase_synth 가 unadjudicated 1 · converged False · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_synthesize_artifact_findings.sh · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh · 케이스 2 · 지키던 것: README 모델 절 문장 전체 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh · :10 · 지키던 것: color 8색 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_agent_color.sh · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh · :10 · 지키던 것: color 8색 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_agent_color.sh · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_codex_backward_compat.sh · Check 1 · 지키던 것: 스위치를 켜면 detect_codex 가 skip_reason: kill_switch · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_detect_codex.sh Case 3 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_codex_backward_compat.sh · Check 2a · 2b · 지키던 것: SKILL 의 codex 각도 앵커 · scope 무관 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_codex_dispatch_invariant.sh 1 · 2 · PR #<번호>
