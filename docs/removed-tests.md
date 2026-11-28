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
- 2026-11-28 · plugins/quality-gates/tests/test_isolation.sh · T3 · T5 · 지키던 것: (테스트가 스스로 rm -rf 한 뒤를 봄 — setup-qg 동작 없음) · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_isolation.sh · T4 · T6 · 지키던 것: 두 SID 가 서로의 폴더를 안 건드림 · 같은 SID 다시 실행은 새로 시작 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_entry_safety_e1_e6.sh E1 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_worktree.sh · T3 · T4 · 지키던 것: git 자신(rev-parse · diff · .git 이 파일)의 동작 — 플러그인이 지키는 것이 없다 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_worktree.sh · T5 · 지키던 것: security-reviewer dispatch 가 project_dir 를 싣는다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_v_requirements.sh case_v12 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_security_reviewer_behavior.py · AC45 · AC46 · AC47 · 지키던 것: 테스트 안의 고정 YAML 을 가짜 응답 도우미에 넣고 같은 파일이 정한 스키마로 잰다 — 기대값과 대상이 같은 출처라 깨질 수 없다(도우미 머리말 :18–31 이 「agent 정의를 읽지 않는다」 고 적음) · AC46 · AC47 은 도우미 자신이 예외를 내는지만 본다 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_agent_stub_harness.py · 지키던 것: 테스트 도구 자신의 파싱 · 스키마 단언(제품 아님) · docs/testing.md 「가짜 응답은 쓰지 않는다」 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/harness/agent_stub.py · 지키던 것: 테스트 도구 자신의 파싱 · 스키마 단언(제품 아님) · docs/testing.md 「가짜 응답은 쓰지 않는다」 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_readme_scope_reconcile.sh · :27–30 · :44–46 · 지키던 것: README 구성 표 네 행 전체 · codex 비용 문장 · 옛 비용 문구 부재 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_artifact_critique_truths.sh · :26–39 · 지키던 것: 줄 길이는 지키는 동작이 없다 · README 는 사람만 읽는 글 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_skill_orchestration.sh · :48 · 지키던 것: 낮춘 지적 게이트의 「그대로 둔다」 라벨 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_lowered_gate_wiring.sh :63 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_plain_qg_templates.sh · :26–29 · :33 · :35 · 지키던 것: 낮춘 지적 질문이 한국어이고 하나다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_lowered_gate_wiring.sh case_step45_gate · plugins/quality-gates/tests/test_skill_orchestration.sh :37–41 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_plain_qg_templates.sh · README 단언(:61–63 · :69–78) · 지키던 것: 질문 · 완료 보고 · 범위 줄이 한국어 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: 없음 — 받아들임 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_v_requirements.sh · V2 · V3 · V8 의 스크립트 실행 · 지키던 것: 합성 실패 · 파손 지적 · severity 결측이 clean 이 아님 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_synthesize_findings.sh · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_runtime_contract_invariance.sh · case_no_new_surfaces 의 verdict 토큰 7종 부재 · 지키던 것: SKILL 에 옛 판정값이 없다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_one_pipeline_surface.sh case_old_surface_absent · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_codex_result_banner.sh · :124–136 · 지키던 것: SKILL :485–487 의 「이 게이트는 산문이고 리터럴 게이트 전환은 범위 밖」 고지가 남아 있다 · 판정: 첫째 줄(지키는 것을 댈 수 없다) · 지금 지키는 것: plugins/quality-gates/tests/test_codex_gate_observation.sh UNGATED 원장 · PR #<번호>
- 2026-11-28 · plugins/quality-gates/tests/test_git_derived_scope.sh · :52–55 · 지키던 것: 정의 단락이 은퇴한 files.md 를 근거로 들지 않는다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py 축 3 · PR #<번호>
