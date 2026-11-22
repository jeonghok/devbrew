# 테스트 진단 종합 — 묶음 사이 겹침과 되풀이되는 꼴

422개 진단 행(`.claude/tmp/e5/rows/*.md`)을 묶음을 넘어 모은 것이다. 모든 항목은 행이 적은 것에서 왔고, 테스트 경로와 그 행의 초를 붙였다. 행이 적지 않은 것을 보탠 자리는 그렇다고 밝혔다(「글자에 묶인 테스트」 절의 문서 귀속 일부만). 테스트는 실행하지 않았다.

읽는 법:
- 「서로 적음」 은 두 행이 서로를 「겹침」 칸에 적은 짝이다. 「다른 묶음」 은 서로 다른 사람이 적은 행이고, 「같은 묶음」 은 한 사람이 둘 다 적은 행이다. 「한쪽만」 은 한 행만 상대를 적은 짝이다.
- 짝 뒤의 `[A쪽/B쪽]` 은 각 행이 그 상대를 적은 수준이다. 「확인 못 함」 은 그 행의 해당 구절에 「확인 못 함 · 열지 않음 · 읽지 않음 · 이름만」 같은 말이 있는 경우이고, 「내용」 은 그런 말 없이 겹치는 내용을 적은 경우다. 이 구분은 낱말로 가른 것이라 「내용」 이 곧 「대조까지 했다」 는 뜻은 아니다(「확인하지 못한 것」 절).

## 같은 것을 지키는 묶음

「겹침」 칸에서 테스트 경로를 뽑아 보면 짝이 201개(다른 묶음 71 · 같은 묶음 130)이고, 한쪽만 적은 연결이 439개다. 서로 적은 짝 가운데 두 행 모두 내용을 적은 것이 149개, 한쪽만 「확인 못 함」 인 것이 41개, 양쪽 다 「확인 못 함」 인 것이 11개다. 아래 59개 묶음은 이 짝들을 대상 · 규칙으로 다시 가른 것이다. 짝이 있어도 두 행이 「다른 것을 지킨다」 고 밝힌 것은 묶음에서 뺐고 이 절 끝에 모았다.

### G1. docreview 엔진 규칙(라우팅 · 원장 상태 · 고치기 전 확인 · 참고 라우팅 · 질문 재료)의 케이스 — 행동 락과 변이 행렬이 같은 케이스를 돈다
- 테스트: `shared/tests/test_docreview_mutations.sh` 233.0초(구조를 고침) · `shared/tests/test_docreview_route.sh` 76.1초(구조를 고침) · `shared/tests/test_docreview_state.sh` 134.4초(구조를 고침) · `shared/tests/test_docreview_intent.sh` 7.5초(둠) · `shared/tests/test_docreview_advice.sh` 72.7초(구조를 고침) · `shared/tests/test_docreview_ask.sh` 14.9초(구조를 고침) — 합 538.6초
- 짝: test_docreview_mutations.sh↔test_docreview_route.sh 서로 적음(같은 묶음) [내용/내용]; test_docreview_mutations.sh↔test_docreview_state.sh 서로 적음(같은 묶음) [내용/내용]; test_docreview_mutations.sh↔test_docreview_intent.sh 서로 적음(같은 묶음) [내용/내용]; test_docreview_mutations.sh↔test_docreview_advice.sh 서로 적음(다른 묶음) [내용/내용]; test_docreview_mutations.sh↔test_docreview_ask.sh 한쪽만(test_docreview_mutations.sh→) [내용/—]; test_docreview_advice.sh↔test_docreview_ask.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — mutations 행: 셀이 겨누는 서로 다른 케이스 89개 중 87개가 행동 락들에 이미 등록돼 있고, 깨끗한 사본 양성 대조가 같은 케이스를 한 바퀴에 한 번 더 GREEN 으로 돈다. route · state · intent · advice 행도 「이 파일 케이스를 깨끗한 사본에서 한 번 더 돈다」 고 적었다. 변이 실행 자체는 겹침이 아니다(이빨 확인)
- 남길 쪽 후보: 케이스의 주인은 행동 락(route · state · intent · advice · ask). mutations 는 변이 실행만 남기고 깨끗한 사본 실행을 행동 락 결과로 갈음(mutations 행의 고치는 길). 행렬 전용 케이스 둘은 행동 락에 등록(같은 행)

### G2. docreview 게이트 렌더 — 행마다 「그 상태 하나만 산 원장」을 지어 gate --render 를 본다
- 테스트: `shared/tests/test_docreview_gate_plain.sh` 11.9초(합침) · `shared/tests/test_docreview_gate_visibility.sh` 5.6초(구조를 고침) · `shared/tests/test_docreview_route.sh` 76.1초(구조를 고침) — 합 93.6초
- 짝: test_docreview_gate_plain.sh↔test_docreview_gate_visibility.sh 서로 적음(다른 묶음) [내용/내용]; test_docreview_gate_plain.sh↔test_docreview_route.sh 서로 적음(같은 묶음) [내용/내용]; test_docreview_gate_visibility.sh↔test_docreview_route.sh 한쪽만(test_docreview_route.sh→) [—/내용]
- 겹치는 정도: gate_plain 행은 내용까지(같은 픽스처 F_DEC · F_FIX · decide adopt/hold · next_round · st_set_stale_pointer, 같은 준비를 두 파일이 따로 함). gate_visibility 행은 「내용 대조는 못 함」. route 의 case_gate_render_six_lines · case_plain_render_* 도 같은 렌더 첫 줄을 잰다(gate_plain 행)
- 남길 쪽 후보: gate_visibility 쪽 준비 하나에 가시성 · 기호 누출 단언을 함께(gate_plain 행: 준비가 절반으로 준다)

### G3. docreview 참고 · 질문 — 같은 cases_advice.sh 준비
- 테스트: `shared/tests/test_docreview_advice.sh` 72.7초(구조를 고침) · `shared/tests/test_docreview_ask.sh` 14.9초(구조를 고침) — 합 87.6초
- 짝: test_docreview_advice.sh↔test_docreview_ask.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 양쪽 행이 case_gate_file_advice_included 가 case_AC1_brief_overdesign_only 와 같은 준비라고 적음
- 남길 쪽 후보: 행 판정은 둘 다 「구조를 고침」(준비 함께 쓰기). 어느 쪽을 지울지는 적지 않았다

### G4. 지휘 상태 브랜치(StateRepo 준비) — 프로세스 안 단위 넷과 명령줄 끝에서 끝 하나
- 테스트: `plugins/spec-distill/tests/test_conductor_branch.py` 150.0초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_cross.py` 141.5초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_mail.py` 111.7초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_status.py` 126.3초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh` 23.6초(둠) — 합 553.1초
- 짝: test_conductor_branch.py↔test_conductor_cross.py 한쪽만(test_conductor_branch.py→) [내용/—]; test_conductor_branch.py↔test_conductor_mail.py 서로 적음(다른 묶음) [내용/내용]; test_conductor_branch.py↔test_conductor_status.py 한쪽만(test_conductor_branch.py→) [내용/—]; test_conductor_branch.py↔test_conductor_state_branch_e2e.sh 한쪽만(test_conductor_state_branch_e2e.sh→) [—/확인 못 함]; test_conductor_cross.py↔test_conductor_mail.py 서로 적음(같은 묶음) [내용/내용]; test_conductor_cross.py↔test_conductor_status.py 서로 적음(같은 묶음) [내용/내용]; test_conductor_cross.py↔test_conductor_state_branch_e2e.sh 서로 적음(같은 묶음) [내용/내용]; test_conductor_mail.py↔test_conductor_state_branch_e2e.sh 서로 적음(같은 묶음) [내용/내용]; test_conductor_status.py↔test_conductor_state_branch_e2e.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 준비가 겹치고 확인은 대부분 갈림 — branch 행: 「같은 StateRepo 준비를 쓰나 SETTINGS_UNREADABLE · push_outcome · next_letter_name · looks_absolute 를 재는 다른 테스트는 못 찾음」. e2e 행: 걸음 1·4·7 이 cross 의 show 줄을, 걸음 3–6 이 mail 의 send · read · ack 를 명령줄로 다시 본다. 같은 규칙의 중복보다 같은 준비의 반복이 크다(되풀이되는 꼴 P1 · StateRepo)
- 남길 쪽 후보: 단위 넷이 세부, e2e 는 한 줄기로 둠(e2e 행 판정 「둠」). 합치기보다 준비 공유가 행들의 고치는 길

### G5. 지휘 원장 명령(claim · record · write-sections · cleanup · orphans · worktree-path)과 스위트 대조
- 테스트: `plugins/spec-distill/tests/test_conductor_e2e.sh` 9.4초(둠) · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6초(구조를 고침) · `plugins/spec-distill/tests/test_merge_check.sh` 28.5초(둠) — 합 125.5초
- 짝: test_conductor_e2e.sh↔test_conductor_ledger.py 서로 적음(같은 묶음) [내용/내용]; test_conductor_e2e.sh↔test_merge_check.sh 서로 적음(다른 묶음) [내용/내용]
- 겹치는 정도: 내용까지이나 깊이가 다름 — e2e 는 정상 길 한 번, ledger 는 명령마다 자세히, merge_check 는 merge_check 를 따로(양쪽 행이 그렇게 적음)
- 남길 쪽 후보: 셋 다 둠(e2e 9.4초 · merge_check 「둠」). 겹침은 정상 길 한 번뿐

### G6. 상태줄 · 지도(control_plane) — 시간 예산 · 기본 브랜치 조각 · 대역 scripts 사본 · 설정 폴더 후보 목록
- 테스트: `plugins/spec-distill/tests/test_control_plane.sh` 67.3초(구조를 고침) · `plugins/spec-distill/tests/test_default_branch.sh` 13.5초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6초(구조를 고침) · `plugins/spec-distill/tests/test_control_plane.py` 0.3초(둠) — 합 168.7초
- 짝: test_control_plane.sh↔test_default_branch.sh 서로 적음(같은 묶음) [내용/내용]; test_control_plane.sh↔test_conductor_ledger.py 서로 적음(같은 묶음) [내용/내용]; test_control_plane.sh↔test_control_plane.py 서로 적음(다른 묶음) [내용/확인 못 함]
- 겹치는 정도: control_plane.sh ↔ default_branch: 내용까지(상태줄 시간 예산 · 대역 scripts 사본 · 「기본 브랜치 main」 조각을 같은 꼴로 다시 만든다). control_plane.sh ↔ ledger: 「설정 폴더가 다른 레포」 절과 Roadmaps 클래스가 같은 후보 목록. control_plane.py 쪽은 「확인 못 함」
- 남길 쪽 후보: 행들은 대역 scripts 사본 만들기를 공용 헬퍼로(두 행 모두). 단언을 지울 쪽은 정하지 않음

### G7. 로드맵 상태 계산(roadmap_status)의 소비자 — 같은 계산기를 다른 갈래로
- 테스트: `plugins/spec-distill/tests/test_roadmap_status.sh` 92.2초(구조를 고침) · `plugins/spec-distill/tests/test_team_status.sh` 134.3초(구조를 고침) · `plugins/spec-distill/tests/test_team_tasks.sh` 64.8초(구조를 고침) · `plugins/spec-distill/tests/test_roadmap_model.py` 0.0초(둠) · `plugins/spec-distill/tests/test_roadmap_render.py` 0.3초(둠) · `plugins/spec-distill/tests/test_roadmap_render_r2.py` 0.0초(둠) — 합 291.6초
- 짝: test_roadmap_status.sh↔test_team_status.sh 서로 적음(다른 묶음) [내용/내용]; test_roadmap_status.sh↔test_roadmap_model.py 서로 적음(다른 묶음) [내용/확인 못 함]; test_roadmap_status.sh↔test_roadmap_render.py 서로 적음(다른 묶음) [내용/확인 못 함]; test_team_status.sh↔test_team_tasks.sh 서로 적음(다른 묶음) [내용/내용]; test_roadmap_model.py↔test_roadmap_render.py 한쪽만(test_roadmap_model.py→) [확인 못 함/—]; test_roadmap_render.py↔test_roadmap_render_r2.py 서로 적음(같은 묶음) [확인 못 함/내용]
- 겹치는 정도: 대부분 「같은 계산기의 다른 갈래」. team_status 행: test_team_results.py 가 결과 · 막힘 · 결정 기록 줄 읽기를 프로세스 안에서 재고 이 파일은 같은 갈래를 레포 왕복으로 다시 잰다. roadmap_model · render 쪽은 「확인 못 함」. render ↔ render_r2: §4 항목 색인 일부를 다시 잰다
- 남길 쪽 후보: 레포 왕복이 필요 없는 줄 읽기 갈래는 test_team_results.py(0.0초) 쪽(team_status 행). 나머지는 나누기 · 준비 공유

### G8. 사람 승인 줄 관문 — 지어낸 승인 줄 갈래 · 낡음 · 미룸 절 · 흐름 승인
- 테스트: `plugins/spec-distill/tests/test_human_gate.sh` 148.2초(구조를 고침) · `plugins/spec-distill/tests/test_human_gate_e2e.sh` 139.0초(줄임) · `plugins/spec-distill/tests/test_human_judge.py` 11.7초(둠) · `plugins/spec-distill/tests/test_start_bundle.sh` 64.7초(구조를 고침) — 합 363.6초
- 짝: test_human_gate.sh↔test_human_gate_e2e.sh 서로 적음(같은 묶음) [내용/내용]; test_human_gate.sh↔test_human_judge.py 서로 적음(같은 묶음) [내용/내용]; test_human_gate.sh↔test_start_bundle.sh 서로 적음(다른 묶음) [내용/내용]; test_human_gate_e2e.sh↔test_human_judge.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — human_gate_e2e 행: 13(낡음) · 14(미룸 절만) · 15–16(흐름 승인)이 human_gate 의 9 · 11 · 15–16 과 같다. human_judge 행: Match.test_forged_lines_do_not_pass 가 같은 지어낸 줄 갈래를 단위에서 표로 재고, e2e 는 그 갈래를 세 표면에서 다시 잰다. human_gate ↔ start_bundle 은 머지된 과제 멈춤 사유 정도
- 남길 쪽 후보: 판정 표는 human_judge(11.7초, 가장 싼 층 — 그 행: 「겹침은 위층(e2e · gate)을 덜어 풀 일」). human_gate_e2e 는 「줄임」

### G9. 팀 규칙 사본(leader seat) — 남의 고침 거절 · confirm · rules-branch 갈라짐 · 꺼진 설정
- 테스트: `plugins/spec-distill/tests/test_leader_seat.py` 92.2초(구조를 고침) · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9초(줄임) — 합 168.1초
- 짝: test_leader_seat.py↔test_leader_seat_e2e.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 양쪽 행이 같은 네 갈래를 함수 단위 / CLI 로 다시 잰다고 적음
- 남길 쪽 후보: 함수 단위(leader_seat.py)가 세부, e2e 는 「줄임」(e2e 행: 22 · 23 을 앞 걸음 확인에 흡수)

### G10. job sync · 시작 묶음 규칙 머리(rules_at)
- 테스트: `plugins/spec-distill/tests/test_start_bundle.sh` 64.7초(구조를 고침) · `plugins/spec-distill/tests/test_team_sync.sh` 7.8초(둠) · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9초(줄임) — 합 148.4초
- 짝: test_start_bundle.sh↔test_team_sync.sh 서로 적음(같은 묶음) [내용/내용]; test_start_bundle.sh↔test_leader_seat_e2e.sh 한쪽만(test_start_bundle.sh→) [내용/—]; test_team_sync.sh↔test_leader_seat_e2e.sh 한쪽만(test_team_sync.sh→) [내용/—]
- 겹치는 정도: 일부 — 맞추는 명령을 그대로 돌린 job sync 한 번 · rules_at 끝에서 끝이 겹친다(양쪽 행)
- 남길 쪽 후보: team_sync 「둠」 · 겹침은 한 걸음

### G11. intent-critic 단계 — 꺼짐 갈래 · 옛 이름 부재 · 돌려주는 꼴 · 다른 팀 요약
- 테스트: `plugins/quality-gates/tests/test_intent_critic.py` 31.7초(구조를 고침) · `plugins/quality-gates/tests/test_intent_critic_wiring.sh` 10.8초(구조를 고침) · `plugins/quality-gates/tests/test_intent_return.py` 7.6초(합침) · `plugins/quality-gates/tests/test_intent_wide.py` 20.0초(구조를 고침) · `plugins/quality-gates/tests/test_other_teams.py` 41.0초(구조를 고침) — 합 111.1초
- 짝: test_intent_critic.py↔test_intent_critic_wiring.sh 서로 적음(같은 묶음) [내용/내용]; test_intent_critic.py↔test_intent_return.py 서로 적음(같은 묶음) [확인 못 함/내용]; test_intent_critic.py↔test_intent_wide.py 서로 적음(다른 묶음) [내용/내용]; test_intent_critic_wiring.sh↔test_intent_return.py 서로 적음(같은 묶음) [내용/내용]; test_intent_critic_wiring.sh↔test_intent_wide.py 한쪽만(test_intent_critic_wiring.sh→) [내용/—]; test_intent_return.py↔test_intent_wide.py 서로 적음(다른 묶음) [내용/내용]; test_intent_wide.py↔test_other_teams.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — TestOldNameGone 이 wiring 의 「옛 이름 부재」 9파일을 포괄(양쪽 행). intent_critic 의 TestGate.test_paths · test_tree_failed_writes_return_block · test_kill_switch_first 가 intent_return 의 test_skip_and_fail_codes · test_stage_and_global_switch 의 부분집합(양쪽 행). kill · kill-global 꺼짐 줄이 세 파일에(wiring 행: 끝에서 끝 · gh 미호출 · 양의 짝은 wiring 만). wide ↔ other_teams 는 상한 줄 · 겹침 요약
- 남길 쪽 후보: CLI 갈래는 intent_return(어휘 · 칸까지 봄 — 그 행 판정 「합침」 의 방향), 옛 이름 부재는 intent_critic.TestOldNameGone, 꺼짐 끝에서 끝은 wiring

### G12. qg README · SKILL 문구 락 — README 첫 문단 · 상태도 라벨 · 옛 fan-out 부재 · 리뷰어 구성
- 테스트: `plugins/quality-gates/tests/test_plain_readme.sh` 0.1초(줄임) · `plugins/quality-gates/tests/test_readme_scope_reconcile.sh` 0.1초(지움) · `plugins/quality-gates/tests/test_readme_state_diagram_complete.sh` 0.1초(지움) · `plugins/quality-gates/tests/test_plain_qg_templates.sh` 0.5초(줄임) · `plugins/quality-gates/tests/test_review_scope_composition.sh` 1.1초(줄임) — 합 1.9초
- 짝: test_plain_readme.sh↔test_readme_scope_reconcile.sh 서로 적음(같은 묶음) [내용/내용]; test_plain_readme.sh↔test_readme_state_diagram_complete.sh 서로 적음(같은 묶음) [내용/내용]; test_plain_readme.sh↔test_plain_qg_templates.sh 서로 적음(같은 묶음) [내용/내용]; test_readme_scope_reconcile.sh↔test_review_scope_composition.sh 서로 적음(같은 묶음) [내용/내용]; test_readme_state_diagram_complete.sh↔test_plain_qg_templates.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지(모두 shallow-04 한 사람) — plain_readme 행: 넷 모두 README.md 문구를 grep 한다. state_diagram 행: 라벨 줄은 plain_qg_templates 가 이미 잰다. scope_reconcile ↔ composition: README 상한 8 부재 · 시작 구성 문구가 겹침
- 남길 쪽 후보: plain_qg_templates(라벨↔분기 상호참조) · review_scope_composition(scope-empty 펜스 실행 · 위조 방어). scope_reconcile · state_diagram 은 행 판정 「지움」

### G13. 범위 모드 · 게시 배선 — resolve-range 의 start · end, 범위 모드 게시 거절, review-diff 연결
- 테스트: `plugins/quality-gates/tests/test_range_wiring.sh` 5.5초(구조를 고침) · `plugins/quality-gates/tests/test_resolve_range.sh` 4.0초(구조를 고침) · `plugins/quality-gates/tests/test_publish_pipeline_wiring.sh` 4.7초(구조를 고침) · `plugins/quality-gates/tests/test_publish_comment_sink.sh` 12.6초(둠) · `plugins/quality-gates/tests/test_review_diff.sh` 53.5초(구조를 고침) — 합 80.3초
- 짝: test_range_wiring.sh↔test_resolve_range.sh 서로 적음(같은 묶음) [내용/내용]; test_range_wiring.sh↔test_publish_pipeline_wiring.sh 서로 적음(같은 묶음) [내용/내용]; test_range_wiring.sh↔test_publish_comment_sink.sh 한쪽만(test_publish_comment_sink.sh→) [—/확인 못 함]; test_range_wiring.sh↔test_review_diff.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_resolve_range.sh↔test_review_diff.sh 한쪽만(test_resolve_range.sh→) [내용/—]; test_publish_pipeline_wiring.sh↔test_publish_comment_sink.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]
- 겹치는 정도: range ↔ resolve_range: 내용까지(case_chain_agrees 가 같은 start · end · end_from 단언을 되풀이, 양쪽 행). range ↔ publish_pipeline: 범위 모드 게시 거절 줄 · 두 번째 실행 거절(양쪽 행). publish_comment_sink ↔ publish_pipeline: 양쪽 다 「확인 못 함」. range ↔ review_diff: review_diff 쪽 「확인 못 함 — 이름으로만」
- 남길 쪽 후보: start · end 단언은 resolve_range, 게시 거절은 publish_pipeline_wiring. 행들이 지울 쪽을 정하지는 않음

### G14. render-terminal table 동작(완료 표 정렬)
- 테스트: `plugins/quality-gates/tests/test_render_terminal.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_publish_surface_removed.sh` 1.4초(줄임) · `plugins/quality-gates/tests/test_plain_qg_templates.sh` 0.5초(줄임) — 합 2.0초
- 짝: test_render_terminal.sh↔test_publish_surface_removed.sh 서로 적음(같은 묶음) [내용/내용]; test_render_terminal.sh↔test_plain_qg_templates.sh 서로 적음(같은 묶음) [내용/내용]; test_publish_surface_removed.sh↔test_plain_qg_templates.sh 한쪽만(test_plain_qg_templates.sh→) [—/내용]
- 겹치는 정도: 내용까지 — publish_surface_removed 가 table 이 남아 있는지 `k   v` 출력으로 확인, render_terminal 은 정렬 동작(양쪽 행)
- 남길 쪽 후보: render_terminal 행 판정 「합침」(publish_surface_removed 와 한 파일로)

### G15. 보안 각도 kill switch 가 dispatch 를 지배 — 같은 env 를 SKILL 의 다른 앵커에서
- 테스트: `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh` 1.1초(구조를 고침) · `plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh` 0.1초(둠) · `plugins/quality-gates/tests/test_angle_coverage.sh` 5.1초(구조를 고침) — 합 6.3초
- 짝: test_pipeline_verdict_wiring.sh↔test_security_reviewer_kill_switch.sh 서로 적음(같은 묶음) [내용/내용]; test_pipeline_verdict_wiring.sh↔test_angle_coverage.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]
- 겹치는 정도: 같은 env · 다른 앵커(양쪽 행: 각도 표 · IF item4 대 dispatch 바로 위 게이트). angle_coverage ↔ pipeline_verdict_wiring 은 양쪽 다 「확인 못 함」
- 남길 쪽 후보: 보안 갈래 글자 확인이라 행들이 지움을 권하지 않음(security_reviewer_kill_switch 「둠」)

### G16. qg agent frontmatter — tools · model · color 를 전수 스윕과 agent 별 락이 겹쳐 잰다
- 테스트: `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` 0.9초(둠) · `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_agent_color.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_code_recritic_frontmatter.sh` 0.2초(둠) · `plugins/quality-gates/tests/test_agent_model_mutation.sh` 6.5초(줄임) · `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` 0.2초(줄임) — 합 8.2초
- 짝: test_agent_frontmatter_keys.sh↔test_artifact_adversarial_frontmatter.sh 한쪽만(test_artifact_adversarial_frontmatter.sh→) [—/내용]; test_agent_frontmatter_keys.sh↔test_code_recritic_frontmatter.sh 한쪽만(test_code_recritic_frontmatter.sh→) [—/내용]; test_agent_model_unpinned_sweep.sh↔test_artifact_adversarial_frontmatter.sh 서로 적음(같은 묶음) [내용/내용]; test_agent_model_unpinned_sweep.sh↔test_artifact_critic_frontmatter.sh 한쪽만(test_agent_model_unpinned_sweep.sh→) [내용/—]; test_agent_model_unpinned_sweep.sh↔test_code_recritic_frontmatter.sh 서로 적음(같은 묶음) [내용/내용]; test_agent_model_unpinned_sweep.sh↔test_agent_model_mutation.sh 서로 적음(다른 묶음) [내용/내용]; test_agent_color.sh↔test_artifact_adversarial_frontmatter.sh 서로 적음(같은 묶음) [내용/내용]; test_agent_color.sh↔test_artifact_critic_frontmatter.sh 한쪽만(test_agent_color.sh→) [내용/—]; test_artifact_adversarial_frontmatter.sh↔test_artifact_critic_frontmatter.sh 서로 적음(같은 묶음) [내용/내용]; test_code_recritic_frontmatter.sh↔test_skill_orchestration_behavior.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — adversarial ↔ critic 은 「거의 복제」(양쪽 행). 개별 셋의 model 부재 · color 정규식은 전수 스윕(frontmatter_keys · model_unpinned_sweep · agent_color)이 이미 잰다(여러 행). model_mutation 은 스윕의 이빨을 재며 agent 별 락 29회 재실행이 시간 대부분(그 행)
- 남길 쪽 후보: 전수 스윕 둘(frontmatter_keys · model_unpinned_sweep)이 tools · model 의 주인. 개별 파일에는 페르소나 문구(보안 갈래)만 남김(adversarial 행)

### G17. Law 2 도구 락의 이빨 — 같은 픽스처 꼴 · 같은 RED/GREEN 기대
- 테스트: `plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh` 6.2초(구조를 고침) · `plugins/quality-gates/tests/test_agent_tools_lock_differential.sh` 3.9초(구조를 고침) · `plugins/quality-gates/tests/test_agent_frontmatter_keys.sh` 0.9초(둠) — 합 11.0초
- 짝: test_agent_tools_lock_mutation.sh↔test_agent_tools_lock_differential.sh 서로 적음(같은 묶음) [내용/내용]; test_agent_tools_lock_mutation.sh↔test_agent_frontmatter_keys.sh 서로 적음(같은 묶음) [내용/내용]; test_agent_tools_lock_differential.sh↔test_agent_frontmatter_keys.sh 한쪽만(test_agent_frontmatter_keys.sh→) [—/내용]
- 겹치는 정도: 내용까지 — differential 행: mutation 과 같은 픽스처 형태(`tools: [Write]` · bare `tools:` · 인용 · 중복 키)를 L1 로 되풀이하고 락도 케이스마다 양쪽에서 실행. frontmatter_keys 는 대상(역할 분담 의도)
- 남길 쪽 후보: 보안 갈래. 행 판정은 둘 다 「구조를 고침」 — 겹친 L1 케이스를 한쪽에

### G18. spec-distill 조사 agent frontmatter — 읽기 전용 allowlist · model 핀 없음 · 출력 키
- 테스트: `plugins/spec-distill/tests/test_research_agents_frontmatter.sh` 0.5초(둠) · `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_steelman_builder_scope.sh` 0.2초(줄임) · `plugins/spec-distill/tests/test_brief_agents.sh` 0.5초(줄임) — 합 1.4초
- 짝: test_research_agents_frontmatter.sh↔test_blind_spot_prober_frontmatter.sh 한쪽만(test_blind_spot_prober_frontmatter.sh→) [—/내용]; test_research_agents_frontmatter.sh↔test_coverage_mapper_frontmatter.sh 한쪽만(test_coverage_mapper_frontmatter.sh→) [—/내용]; test_blind_spot_prober_frontmatter.sh↔test_coverage_mapper_frontmatter.sh 서로 적음(다른 묶음) [내용/내용]; test_blind_spot_prober_frontmatter.sh↔test_steelman_builder_scope.sh 서로 적음(다른 묶음) [내용/내용]; test_blind_spot_prober_frontmatter.sh↔test_brief_agents.sh 서로 적음(같은 묶음) [내용/내용]; test_coverage_mapper_frontmatter.sh↔test_brief_agents.sh 한쪽만(test_coverage_mapper_frontmatter.sh→) [내용/—]
- 겹치는 정도: 내용까지 — research_agents 가 두 agent 를 한 루프로 같은 규칙을 잰다(coverage_mapper 행). prober · mapper · steelman 은 같은 형태의 형제 락
- 남길 쪽 후보: test_research_agents_frontmatter.sh 의 공용 루프(prober · mapper 행 판정 「합침」 의 방향). 보안 갈래 — 규칙 자체는 남김

### G19. qg setup · 세션 폴더 — 같은 SID 재실행 · 세션 폴더 생성 · 인자 처리
- 테스트: `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` 6.5초(구조를 고침) · `plugins/quality-gates/tests/test_isolation.sh` 1.9초(합침) · `plugins/quality-gates/tests/test_setup_qg.sh` 4.9초(구조를 고침) · `plugins/quality-gates/tests/test_worktree.sh` 0.5초(줄임) · `plugins/quality-gates/tests/test_removed_plan_arg.sh` 0.1초(둠) · `plugins/quality-gates/tests/test_plain_synth_output.sh` 1.7초(둠) — 합 15.6초
- 짝: test_entry_safety_e1_e6.sh↔test_isolation.sh 서로 적음(같은 묶음) [내용/내용]; test_entry_safety_e1_e6.sh↔test_setup_qg.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_isolation.sh↔test_setup_qg.sh 한쪽만(test_isolation.sh→) [내용/—]; test_isolation.sh↔test_worktree.sh 한쪽만(test_isolation.sh→) [내용/—]; test_setup_qg.sh↔test_worktree.sh 서로 적음(같은 묶음) [내용/내용]; test_setup_qg.sh↔test_removed_plan_arg.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]; test_removed_plan_arg.sh↔test_plain_synth_output.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: isolation T6 ↔ entry_safety E1: 내용까지(양쪽 행). setup_qg ↔ worktree: 세션 폴더 생성 확인(양쪽 행). setup_qg 쪽은 entry_safety · removed_plan_arg 와의 겹침을 「확인 못 함」. removed_plan_arg ↔ plain_synth_output: setup 배너 「계획 파일」 부재 한 줄
- 남길 쪽 후보: isolation 행 판정 「합침」 → setup_qg 의 케이스로(setup_qg 행은 isolation 을 대지 않음)

### G20. qg 합성기 · 판정 줄 — V1 · V2 · V3 · V8 · AC4 · AC5 · exit 4
- 테스트: `plugins/quality-gates/tests/test_synthesize_findings.sh` 2.0초(줄임) · `plugins/quality-gates/tests/test_v_requirements.sh` 1.0초(줄임) · `plugins/quality-gates/tests/test_verdict_vocabulary.sh` 2.0초(구조를 고침) · `plugins/quality-gates/tests/test_v1_verdict_line.sh` 1.5초(구조를 고침) · `plugins/quality-gates/tests/test_synthesize_findings_adjudication.py` 0.0초(둠) · `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` 0.8초(줄임) · `plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh` 0.3초(둠) — 합 7.6초
- 짝: test_synthesize_findings.sh↔test_v_requirements.sh 서로 적음(같은 묶음) [내용/내용]; test_synthesize_findings.sh↔test_verdict_vocabulary.sh 서로 적음(같은 묶음) [내용/내용]; test_synthesize_findings.sh↔test_synthesize_findings_adjudication.py 서로 적음(같은 묶음) [내용/내용]; test_v_requirements.sh↔test_verdict_vocabulary.sh 서로 적음(같은 묶음) [내용/내용]; test_v_requirements.sh↔test_v1_verdict_line.sh 한쪽만(test_v1_verdict_line.sh→) [—/내용]; test_v_requirements.sh↔test_synthesize_findings_adjudication.py 한쪽만(test_synthesize_findings_adjudication.py→) [—/내용]; test_v_requirements.sh↔test_synthesize_promoted_findings.sh 한쪽만(test_v_requirements.sh→) [내용/—]; test_v_requirements.sh↔test_skill_drop_notice_consumed.sh 한쪽만(test_skill_drop_notice_consumed.sh→) [—/내용]; test_verdict_vocabulary.sh↔test_v1_verdict_line.sh 서로 적음(같은 묶음) [내용/내용]; test_synthesize_findings_adjudication.py↔test_synthesize_promoted_findings.sh 서로 적음(같은 묶음) [내용/내용]; test_synthesize_promoted_findings.sh↔test_skill_drop_notice_consumed.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지(모두 shallow-05) — v_requirements 행: V1 · V2 · V3 · V8 이 verdict_vocabulary · synthesize_findings · promoted 와 같은 확인을 되풀이. synthesize_findings ↔ verdict_vocabulary: case_synth_ac4 · ac5 가 같다. drop 공지는 생산자(promoted 10 · 10b)와 소비자(drop_notice a1 · a2)가 같은 공지를 잰다
- 남길 쪽 후보: v_requirements 는 스스로 「색인이자 그물」 — 행 판정 「줄임」(중복 V 케이스를 덜고 경로 가두기는 둠)

### G21. 산출물 합성기의 unadjudicated fail-closed 계약
- 테스트: `plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py` 0.0초(합침) · `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` 1.9초(둠) — 합 1.9초
- 짝: test_synthesize_artifact_adjudication.py↔test_synthesize_artifact_findings.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — adjudication 행: findings.sh 79–94행 · 103–115행이 CLI 로 같은 확인(양쪽 행)
- 남길 쪽 후보: test_synthesize_artifact_findings.sh(CLI). adjudication 0.0초라 이득은 작다(그 행)

### G22. codex 탐지 사본 셋 — 같은 정본(shared/codex/detect_codex.sh)을 플러그인마다 같은 14케이스로
- 테스트: `plugins/plugin-audit/tests/test_detect_codex.py` 0.1초(합침) · `plugins/quality-gates/tests/test_detect_codex.sh` 0.2초(둠) · `plugins/spec-distill/tests/test_detect_codex.sh` 1.1초(구조를 고침) · `plugins/quality-gates/tests/test_codex_copies_agree.sh` 2.6초(줄임) · `plugins/quality-gates/tests/test_codex_backward_compat.sh` 0.1초(합침) · `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` 0.1초(합침) — 합 4.2초
- 짝: test_detect_codex.py↔test_detect_codex.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_detect_codex.py↔test_detect_codex.sh 서로 적음(다른 묶음) [내용/내용]; test_detect_codex.sh↔test_detect_codex.sh 한쪽만(test_detect_codex.sh→) [—/내용]; test_detect_codex.sh↔test_codex_copies_agree.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_detect_codex.sh↔test_codex_backward_compat.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_codex_copies_agree.sh↔test_codex_backward_compat.sh 한쪽만(test_codex_backward_compat.sh→) [—/내용]; test_codex_backward_compat.sh↔test_codex_dispatch_invariant.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: pa 행: 형제 사본을 같은 14케이스로(내용). sd 행: 합집합 주석이 있는 같은 확인(내용). qg 행: 「케이스 단위 겹침은 확인 못 함」. backward_compat Check 1(kill switch) 은 detect_codex · copies_agree 가 이미 잼, Check 2 는 dispatch_invariant 와 같은 SKILL 앵커(양쪽 행)
- 남길 쪽 후보: 공유 케이스 한 벌 + 플러그인마다 변수 이름 케이스만(pa 행). backward_compat 은 Check 별로 흩어 모음(그 행). 보안 갈래 — 확인 자체는 남김

### G23. codex 실패 모양 → 파서 meta 사유(malformed · missing agent_message · 인증 stderr)
- 테스트: `plugins/quality-gates/tests/test_failure_injection.sh` 0.2초(합침) · `plugins/quality-gates/tests/test_findings_parser.sh` 0.7초(둠) · `plugins/quality-gates/tests/test_codex_exit_meta.sh` 1.4초(둠) · `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` 12.7초(구조를 고침) · `plugins/quality-gates/tests/test_artifact_codex_reviewer.sh` 0.7초(둠) — 합 15.7초
- 짝: test_failure_injection.sh↔test_findings_parser.sh 서로 적음(같은 묶음) [내용/내용]; test_failure_injection.sh↔test_codex_exit_meta.sh 한쪽만(test_failure_injection.sh→) [내용/—]; test_failure_injection.sh↔test_codex_runner_degrade_contract.sh 한쪽만(test_failure_injection.sh→) [내용/—]; test_findings_parser.sh↔test_codex_exit_meta.sh 한쪽만(test_findings_parser.sh→) [내용/—]; test_codex_exit_meta.sh↔test_codex_runner_degrade_contract.sh 서로 적음(다른 묶음) [내용/내용]; test_codex_exit_meta.sh↔test_artifact_codex_reviewer.sh 서로 적음(같은 묶음) [내용/확인 못 함]; test_codex_runner_degrade_contract.sh↔test_artifact_codex_reviewer.sh 한쪽만(test_artifact_codex_reviewer.sh→) [—/확인 못 함]
- 겹치는 정도: failure_injection ↔ findings_parser: 내용까지(양쪽 행, 같은 사유를 인라인 픽스처로 다시 잰다). exit_meta ↔ degrade_contract: 추출기 비0 종료 → 실패 표식(양쪽 행). artifact_codex_reviewer 쪽은 「확인 못 함」
- 남길 쪽 후보: findings_parser(둠). failure_injection 은 두 모양만 findings_parser 로 옮기고 파일을 줄임(그 행)

### G24. codex 러너 호출 플래그 — `-s read-only` · `--json` · `-C` · stdin 프롬프트
- 테스트: `plugins/quality-gates/tests/test_codex_invocation_contract.sh` 1.7초(둠) · `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh` 0.7초(둠) · `plugins/quality-gates/tests/test_sandbox_enforced.sh` 1.9초(둠) · `plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh` 0.1초(합침) — 합 4.4초
- 짝: test_codex_invocation_contract.sh↔test_codex_runner_no_effort_pin.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]; test_codex_invocation_contract.sh↔test_sandbox_enforced.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]; test_codex_runner_no_effort_pin.sh↔test_sandbox_enforced.sh 한쪽만(test_codex_runner_no_effort_pin.sh→) [확인 못 함/—]; test_codex_runner_no_effort_pin.sh↔test_codex_reviewer_frontmatter.sh 한쪽만(test_codex_reviewer_frontmatter.sh→) [—/내용]; test_sandbox_enforced.sh↔test_codex_reviewer_frontmatter.sh 한쪽만(test_codex_reviewer_frontmatter.sh→) [—/내용]
- 겹치는 정도: invocation_contract ↔ no_effort_pin ↔ sandbox_enforced: 양쪽 다 「확인 못 함」(같은 lib/codex_observation.sh 를 쓸 공산). codex_reviewer_frontmatter 행만 내용까지(스크립트 실재 · 플래그는 no_effort_pin 이 더 세게 잰다)
- 남길 쪽 후보: 보안 갈래 — 셋은 모두 「둠」. codex_reviewer_frontmatter 는 「합침」(kill switch 문구 한 줄만 옮김)

### G25. brief 판독기 · 게이트 — AC18 문법 밖 앵커 변형표(nbsp · 전각 S · 줄 구분자 등)
- 테스트: `plugins/spec-distill/tests/test_brief_body.py` 0.6초(둠) · `plugins/spec-distill/tests/test_check_brief.sh` 50.7초(구조를 고침) · `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` 16.7초(줄임) — 합 68.0초
- 짝: test_brief_body.py↔test_check_brief.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_brief_body.py↔test_check_verbatim_coverage.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_check_brief.sh↔test_check_verbatim_coverage.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: check_brief ↔ verbatim_coverage: 내용까지(같은 AC18 변형표를 다른 소비자로 되풀이, 양쪽 행). brief_body ↔ 둘: 소비자 쪽은 「판독기 단에서 이미 잰다」(내용), brief_body 쪽은 「겹침 정도는 읽지 않음」
- 남길 쪽 후보: 변형표는 판독기 단(brief_body, 0.6초)에서, 소비자 둘은 배선 확인만 — verbatim_coverage 행 판정 「줄임」

### G26. codex 게이트 건너뜀 길마다 직전 라운드 산출물 지우기(residue) — brief 쪽 · spec 쪽
- 테스트: `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` 47.9초(구조를 고침) · `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` 14.1초(합침) — 합 62.0초
- 짝: test_reviewing_brief_residue.sh↔test_reviewing_spec_residue.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 축(A · A+ · A! · D · A2 · A3 · E · P · S)과 거의 같은 하니스 코드를 복사했다(양쪽 행). brief 쪽 P×자리 칸이 이미 spec-review 의 펜스를 실행해 자리를 관측
- 남길 쪽 후보: 한 하니스에 SKILL 을 매개로 넘겨 두 펜스를 돌림(spec_residue 행 판정 「합침」)

### G27. 인터뷰 진입 · 원장 열기 펜스 — 링크된 .docreview · 표지 · 상태 루트
- 테스트: `plugins/spec-distill/tests/test_ledger_wiring.sh` 36.2초(구조를 고침) · `plugins/spec-distill/tests/test_interview_state_flow.sh` 13.0초(둠) · `plugins/spec-distill/tests/test_ledger_marker.py` 1.7초(구조를 고침) · `plugins/spec-distill/tests/test_ledger_root.sh` 5.3초(구조를 고침) · `plugins/spec-distill/tests/test_ask_material_wiring.sh` 4.2초(줄임) · `plugins/spec-distill/tests/test_state_storage_e2e.sh` 4.7초(둠) — 합 65.1초
- 짝: test_ledger_wiring.sh↔test_interview_state_flow.sh 서로 적음(같은 묶음) [내용/내용]; test_ledger_wiring.sh↔test_ledger_marker.py 서로 적음(다른 묶음) [내용/확인 못 함]; test_ledger_wiring.sh↔test_ledger_root.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_ledger_wiring.sh↔test_ask_material_wiring.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_ledger_wiring.sh↔test_state_storage_e2e.sh 한쪽만(test_ledger_wiring.sh→) [내용/—]; test_interview_state_flow.sh↔test_state_storage_e2e.sh 서로 적음(다른 묶음) [내용/확인 못 함]
- 겹치는 정도: ledger_wiring ↔ interview_state_flow: 내용까지(링크된 .docreview 원장 열기 · 두 번째 채널). 나머지 짝은 한쪽이 「확인 못 함」(marker · root · ask_material · state_storage_e2e 쪽)
- 남길 쪽 후보: 행들이 지울 쪽을 정하지 않음 — 단위(marker · root)와 펜스(wiring)가 층이 다르다

### G28. 걸음표 읽기(walk_table) — 레포 표 · 깨진 표 · 기본 브랜치에 없는 표
- 테스트: `plugins/spec-distill/tests/test_walk_next.sh` 46.6초(구조를 고침) · `plugins/spec-distill/tests/test_walk_table.py` 1.2초(둠) — 합 47.8초
- 짝: test_walk_next.sh↔test_walk_table.py 서로 적음(다른 묶음) [내용/확인 못 함]
- 겹치는 정도: walk_next 행: l1–l7 과 b3c–b5 표 오류 갈래가 아래층에서 겹친다(내용). walk_table 행: 「확인 못 함」
- 남길 쪽 후보: 표 읽기는 walk_table(1.2초), walk_next 는 next 의 rc 3 · 빈 출력만

### G29. 토픽 resolve · combine — 머지된 조각 · 경로 부재 · 조각 둘 · 원격 전용 · 충돌 · 하위 디렉토리 · 전부 머지된 키
- 테스트: `plugins/quality-gates/tests/test_topic_boundary.sh` 20.4초(구조를 고침) · `plugins/quality-gates/tests/test_topic_head.sh` 24.0초(구조를 고침) — 합 44.4초
- 짝: test_topic_boundary.sh↔test_topic_head.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — head 행: 이 일곱 갈래의 status · 구성원 판단이 resolve 층(boundary)에서 이미 잰 것과 같다(양쪽 행)
- 남길 쪽 후보: status 판단은 boundary, head 는 합친 커밋 · 사용자 레포 불변만

### G30. seed 게이트 · 읽는 쪽들의 거부 일치
- 테스트: `plugins/spec-distill/tests/test_check_seed.sh` 0.3초(둠) · `plugins/spec-distill/tests/test_seed_one_sentence.sh` 0.2초(둠) · `plugins/spec-distill/tests/test_seed_trust_boundary.sh` 14.8초(구조를 고침) · `plugins/spec-distill/tests/test_seed_grammar_crosscheck.py` 4.1초(둠) · `plugins/spec-distill/tests/test_seed_review_log.sh` 2.8초(둠) — 합 22.2초
- 짝: test_check_seed.sh↔test_seed_one_sentence.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_check_seed.sh↔test_seed_trust_boundary.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_check_seed.sh↔test_seed_grammar_crosscheck.py 한쪽만(test_seed_grammar_crosscheck.py→) [—/내용]; test_seed_trust_boundary.sh↔test_seed_grammar_crosscheck.py 서로 적음(다른 묶음) [내용/내용]; test_seed_trust_boundary.sh↔test_seed_review_log.sh 서로 적음(다른 묶음) [내용/내용]; test_seed_grammar_crosscheck.py↔test_seed_review_log.sh 한쪽만(test_seed_review_log.sh→) [—/내용]
- 겹치는 정도: trust_boundary 행: crosscheck 가 난수 조합으로 같은 축(S2 gate 61 케이스 · 표시 변형 12 · ## 6 허용 목록 5)을 프로세스 안에서 잰다(내용, crosscheck 행도 같은 말). check_seed 쪽은 「확인 못 함」
- 남길 쪽 후보: 손 목록 우회 케이스는 crosscheck(4.1초, 프로세스 안)로, trust_boundary(14.8초)는 「구조를 고침」

### G31. plugin-audit 샌드박스 kill switch(새 · 옛 이름) 시 샌드박스를 만들지 않음
- 테스트: `plugins/plugin-audit/tests/test_audit_sandbox_create.sh` 8.2초(둠) · `plugins/plugin-audit/tests/test_run_own_tests.py` 12.7초(줄임) · `plugins/plugin-audit/tests/test_run_own_tests_accumulate.sh` 0.6초(둠) — 합 21.5초
- 짝: test_audit_sandbox_create.sh↔test_run_own_tests.py 서로 적음(같은 묶음) [내용/내용]; test_run_own_tests.py↔test_run_own_tests_accumulate.sh 서로 적음(다른 묶음) [확인 못 함/확인 못 함]
- 겹치는 정도: create ↔ run_own_tests: 내용까지(양쪽 행). create 쪽의 `.claude/plugin-audit` 미생성 단언은 옛 자리라 새 자리에 이빨이 없다(양쪽 행). run_own_tests ↔ accumulate: 양쪽 다 「확인 못 함」
- 남길 쪽 후보: kill switch 는 보안 갈래 — 둘 다 둠. create 의 옛 자리 단언만 손볼 거리

### G32. 원자료 locate 판결(raw_source.py)
- 테스트: `plugins/spec-distill/tests/test_interview_raw_source_entry.sh` 13.6초(구조를 고침) · `plugins/spec-distill/tests/test_raw_source.py` 1.9초(구조를 고침) · `plugins/spec-distill/tests/test_raw_source_text.py` 4.2초(구조를 고침) — 합 19.7초
- 짝: test_interview_raw_source_entry.sh↔test_raw_source.py 서로 적음(다른 묶음) [내용/확인 못 함]; test_interview_raw_source_entry.sh↔test_raw_source_text.py 서로 적음(다른 묶음) [내용/확인 못 함]; test_raw_source.py↔test_raw_source_text.py 한쪽만(test_raw_source.py→) [확인 못 함/—]
- 겹치는 정도: entry 행: 「raw_source.py locate 판결 자체」(내용). 단위 쪽 두 행은 「확인 못 함」
- 남길 쪽 후보: 판결은 단위(raw_source.py), entry 는 펜스 배선 — entry 행 판정 「구조를 고침」

### G33. 리뷰 범위 신호 · 영향 테스트 후보 · 기준선 해석
- 테스트: `plugins/quality-gates/tests/test_check_review_scope.sh` 2.4초(둠) · `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` 0.8초(지움) · `plugins/quality-gates/tests/test_resolve_baseline.sh` 4.1초(구조를 고침) · `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh` 2.9초(둠) · `plugins/quality-gates/tests/test_guards_declaration_mapping.sh` 2.3초(구조를 고침) · `plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py` 1.9초(둠) — 합 14.4초
- 짝: test_check_review_scope.sh↔test_qg_false_clean_floor.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_check_review_scope.sh↔test_resolve_baseline.sh 서로 적음(다른 묶음) [확인 못 함/내용]; test_check_review_scope.sh↔test_a20_tool_agnostic_scope.py 서로 적음(같은 묶음) [확인 못 함/확인 못 함]; test_qg_false_clean_floor.sh↔test_resolve_baseline.sh 한쪽만(test_qg_false_clean_floor.sh→) [내용/—]; test_qg_false_clean_floor.sh↔test_a20_tool_agnostic_scope.py 한쪽만(test_a20_tool_agnostic_scope.py→) [—/확인 못 함]; test_resolve_baseline.sh↔test_compute_test_scope_candidates.sh 서로 적음(다른 묶음) [내용/확인 못 함]; test_compute_test_scope_candidates.sh↔test_guards_declaration_mapping.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: compute ↔ guards: 내용까지(`--emit-guards` 확인이 양쪽에, 양쪽 행). false_clean_floor 행: 남는 스크립트 출력 확인은 check_review_scope 가 이미 지킨다(내용) — check_review_scope 행은 「겹침 정도 확인 못 함」. resolve_baseline ↔ check_review_scope: case_review_scope_contract · same_as_head(resolve_baseline 쪽만 내용)
- 남길 쪽 후보: false_clean_floor 행 판정 「지움」(근거 한쪽 — 어긋남 절 참조)

### G34. discover-spec 출력 키 집합
- 테스트: `plugins/quality-gates/tests/test_discover_spec.sh` 12.1초(구조를 고침) · `plugins/quality-gates/tests/test_discover_spec_keys.sh` 0.4초(합침) — 합 12.5초
- 짝: test_discover_spec.sh↔test_discover_spec_keys.sh 서로 적음(다른 묶음) [내용/확인 못 함]
- 겹치는 정도: discover_spec 행: 출력 키 집합(내용). keys 행: 「키 집합 확인 중복 여부는 확인 못 함」
- 남길 쪽 후보: keys 를 discover_spec 의 한 케이스로(keys 행 판정 「합침」 — 임시 레포 준비 한 번 덜함)

### G35. spec-distill 지휘 · 마무리 문서 문장 락 — 같은 문서의 같은 절을 여러 파일이 글자로
- 테스트: `plugins/spec-distill/tests/test_conducting_loop.sh` 13.2초(구조를 고침) · `plugins/spec-distill/tests/test_conducting_reference.sh` 6.3초(구조를 고침) · `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` 0.3초(줄임) · `plugins/spec-distill/tests/test_end_gates.sh` 0.4초(줄임) · `plugins/spec-distill/tests/test_decompose_surface.sh` 2.4초(줄임) · `plugins/spec-distill/tests/test_distortion_devices.sh` 1.0초(줄임) · `plugins/spec-distill/tests/test_conducting_interview_stage.sh` 2.1초(줄임) · `plugins/spec-distill/tests/test_entry_guidance.sh` 0.2초(줄임) · `plugins/spec-distill/tests/test_epic_handoff.sh` 0.5초(합침) · `plugins/spec-distill/tests/test_review_handoff_order.sh` 0.6초(합침) · `plugins/spec-distill/tests/test_compression_adopters.sh` 0.1초(지움) — 합 27.1초
- 짝: test_conducting_loop.sh↔test_conducting_reference.sh 서로 적음(다른 묶음) [내용/내용]; test_conducting_reference.sh↔test_conductor_dispatch_reference.sh 서로 적음(같은 묶음) [내용/내용]; test_conducting_reference.sh↔test_entry_guidance.sh 한쪽만(test_entry_guidance.sh→) [—/내용]; test_conducting_reference.sh↔test_epic_handoff.sh 한쪽만(test_epic_handoff.sh→) [—/내용]; test_conductor_dispatch_reference.sh↔test_end_gates.sh 서로 적음(같은 묶음) [내용/내용]; test_end_gates.sh↔test_decompose_surface.sh 서로 적음(같은 묶음) [내용/내용]; test_end_gates.sh↔test_distortion_devices.sh 서로 적음(같은 묶음) [내용/내용]; test_end_gates.sh↔test_conducting_interview_stage.sh 서로 적음(같은 묶음) [내용/내용]; test_end_gates.sh↔test_epic_handoff.sh 한쪽만(test_epic_handoff.sh→) [—/내용]; test_end_gates.sh↔test_review_handoff_order.sh 한쪽만(test_review_handoff_order.sh→) [—/내용]; test_decompose_surface.sh↔test_conducting_interview_stage.sh 서로 적음(같은 묶음) [내용/내용]; test_decompose_surface.sh↔test_entry_guidance.sh 서로 적음(같은 묶음) [내용/내용]; test_distortion_devices.sh↔test_conducting_interview_stage.sh 서로 적음(같은 묶음) [내용/내용]; test_distortion_devices.sh↔test_compression_adopters.sh 서로 적음(같은 묶음) [내용/내용]; test_conducting_interview_stage.sh↔test_review_handoff_order.sh 한쪽만(test_review_handoff_order.sh→) [—/내용]; test_entry_guidance.sh↔test_epic_handoff.sh 서로 적음(같은 묶음) [내용/내용]; test_epic_handoff.sh↔test_review_handoff_order.sh 한쪽만(test_epic_handoff.sh→) [내용/—]
- 겹치는 정도: conducting_loop ↔ conducting_reference: 내용까지(같은 병렬 권장 문장 PAR, 76행, 다른 묶음 둘이 서로 적음). dispatch_reference ↔ end_gates: USED 문장이 같은 글자. end_gates · decompose_surface · distortion_devices · conducting_interview_stage 가 finishing.md 의 같은 절을 글자로(shallow-06 한 사람). review_handoff_order 는 스스로 end_gates 와 같은 글자라고 밝힘(한쪽만)
- 남길 쪽 후보: 문서별로 락 하나 — 「글자에 묶인 테스트」 절의 문서 묶음 참조

### G36. design-doc 프로필 층 2 handoff_incomplete 줄
- 테스트: `plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_handoff_context_section_required.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_handoff_conversation_reference.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_handoff_design_mode.sh` 0.1초(구조를 고침) — 합 0.4초
- 짝: test_handoff_context_empty_subsections.sh↔test_handoff_context_section_required.sh 서로 적음(같은 묶음) [내용/내용]; test_handoff_context_empty_subsections.sh↔test_handoff_conversation_reference.sh 서로 적음(같은 묶음) [내용/내용]; test_handoff_context_empty_subsections.sh↔test_handoff_design_mode.sh 한쪽만(test_handoff_context_empty_subsections.sh→) [내용/—]; test_handoff_context_section_required.sh↔test_handoff_conversation_reference.sh 서로 적음(같은 묶음) [내용/내용]; test_handoff_context_section_required.sh↔test_handoff_design_mode.sh 한쪽만(test_handoff_context_section_required.sh→) [내용/—]; test_handoff_conversation_reference.sh↔test_handoff_design_mode.sh 한쪽만(test_handoff_conversation_reference.sh→) [내용/—]
- 겹치는 정도: 내용까지(shallow-07 한 사람) — 셋이 층 2 창을 같은 awk 로 자르고 같은 줄을 본다. design_mode 쪽 행은 셋을 대지 않음
- 남길 쪽 후보: design-doc 프로필 락 하나로(세 행 판정 「합침」)

### G37. 리뷰 진입 끄기 판정(review_entry.py)
- 테스트: `plugins/spec-distill/tests/test_review_entry.py` 0.7초(둠) · `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` 8.5초(둠) — 합 9.2초
- 짝: test_review_entry.py↔test_reviewing_spec_entry_fence.sh 서로 적음(다른 묶음) [확인 못 함/내용]
- 겹치는 정도: fence 행: review_entry.py 의 스위치 판정을 단위로(내용). review_entry 행: 은퇴 토큰 advisory 일부가 겹칠 수 있음(확인 못 함)
- 남길 쪽 후보: 보안 갈래 — 둘 다 「둠」. 단위 판정 대 fail-closed 읽기로 층이 다르다

### G38. 원장 정리 kill switch 네 개 행렬
- 테스트: `plugins/spec-distill/tests/test_kill_switches_v060.sh` 0.9초(합침) · `plugins/spec-distill/tests/test_ledger_sweep.py` 4.1초(구조를 고침) — 합 5.0초
- 짝: test_kill_switches_v060.sh↔test_ledger_sweep.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 네 스위치를 파이썬으로도 잰다(거의 동일, 양쪽 행). TTL 재정의는 v060 에만
- 남길 쪽 후보: ledger_sweep.SafetyTest 쪽, TTL 두 케이스만 옮김(v060 행 판정 「합침」). 보안 갈래

### G39. 번호 대조 스크립트(check_bundle_coverage) — --impl · --plan · 받는 곳 · 셀 수 없음
- 테스트: `plugins/spec-distill/tests/test_bundle_coverage.sh` 5.4초(구조를 고침) · `plugins/spec-distill/tests/test_coverage_scope.py` 0.4초(둠) — 합 5.8초
- 짝: test_bundle_coverage.sh↔test_coverage_scope.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 갈래를 프로세스 안 / 프로세스를 띄워 한 번 더(양쪽 행)
- 남길 쪽 후보: 프로세스 안(coverage_scope 0.4초) — bundle_coverage 「구조를 고침」

### G40. 옛 모드 슬롯 · 삭제한 훅 부재
- 테스트: `plugins/spec-distill/tests/test_review_hook_removed.py` 4.2초(구조를 고침) · `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` 0.1초(합침) · `plugins/spec-distill/tests/test_hooks.sh` 0.1초(합침) — 합 4.4초
- 짝: test_review_hook_removed.py↔test_reviewing_spec_design_only.sh 서로 적음(같은 묶음) [내용/내용]; test_review_hook_removed.py↔test_hooks.sh 한쪽만(test_hooks.sh→) [—/확인 못 함]
- 겹치는 정도: removed ↔ design_only: 옛 모드 슬롯($mode · mode: design|spec) 부재를 양쪽이 잰다(양쪽 행). hooks.sh → removed 는 「확인 못 함」(한쪽만)
- 남길 쪽 후보: review_hook_removed(design_only · hooks 행 판정 「합침」 의 방향)

### G41. docreview 프로필 — 배포 프로필 넷 통과 · 정확히 넷
- 테스트: `shared/tests/test_docreview_profile_schema.sh` 1.7초(합침) · `shared/tests/test_docreview_profiles.sh` 2.5초(구조를 고침) — 합 4.2초
- 짝: test_docreview_profile_schema.sh↔test_docreview_profiles.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 단언이 둘 다에 있고 변이로 스키마 깨기(필드 누락 · 열한 번째 필드)도 겹친다(양쪽 행)
- 남길 쪽 후보: 한쪽에 모으면 profile-check 4회 준다(profile_schema 행). 보안 갈래 — 변이 거절은 그대로

### G42. 형태 완결성 · 낡음 스윕의 cost_class 부재 판정
- 테스트: `plugins/plugin-audit/tests/test_check_shape_completeness.py` 0.8초(줄임) · `plugins/plugin-audit/tests/test_check_staleness.py` 2.6초(구조를 고침) — 합 3.4초
- 짝: test_check_shape_completeness.py↔test_check_staleness.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 규칙을 따로 확인, test_two_copies_are_identical 이 두 스크립트의 같은 함수를 맞춘다(양쪽 행)
- 남길 쪽 후보: 행들이 정하지 않음

### G43. seed 출처 가름(classify) — 사용자 원문 대 저자 문장 · audit 부재
- 테스트: `plugins/spec-distill/tests/test_seed_input_provenance.sh` 0.2초(줄임) · `plugins/spec-distill/tests/test_seed_provenance.sh` 2.0초(둠) · `plugins/spec-distill/tests/test_seed_cut_table.sh` 0.7초(둠) · `plugins/spec-distill/tests/test_seed_inline_blob.sh` 1.7초(둠) — 합 4.6초
- 짝: test_seed_input_provenance.sh↔test_seed_provenance.sh 서로 적음(같은 묶음) [내용/내용]; test_seed_provenance.sh↔test_seed_cut_table.sh 서로 적음(같은 묶음) [내용/내용]; test_seed_cut_table.sh↔test_seed_inline_blob.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: input_provenance 행: seed_provenance 가 같은 내용을 이미 잰다(내용, 마지막 세 단언). cut_table ↔ inline_blob · provenance 는 덜어 낸 것 절 한 건만 보탠 부분 겹침
- 남길 쪽 후보: seed_provenance. input_provenance 는 「줄임」

### G44. 같은 규칙의 두 언어 구현 · 짝
- 테스트: `plugins/quality-gates/tests/test_secret_scan.py` 0.2초(둠) · `plugins/quality-gates/tests/test_secret_scan_fp.py` 0.1초(합침) — 합 0.3초
- 짝: test_secret_scan.py↔test_secret_scan_fp.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 헬퍼, test_real_value_still_blocks 가 test_github_token_blocks 를 되풀이(fp 행)
- 남길 쪽 후보: secret_scan.py 한 파일(fp 행 판정 「합침」). 보안 갈래

### G45. brief 상한 제거 락 둘(걷어낸 상한이 돌아오지 않음)
- 테스트: `plugins/spec-distill/tests/test_brief_no_length_cap.sh` 0.2초(합침) · `plugins/spec-distill/tests/test_brief_no_statement_cap.sh` 0.2초(합침) — 합 0.4초
- 짝: test_brief_no_length_cap.sh↔test_brief_no_statement_cap.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 꼴 · 다른 상수(양쪽 행)
- 남길 쪽 후보: 하나의 「상한 제거」 락, gate 실행 한 번 공유(두 행 판정 「합침」)

### G46. qg-worktree remove 이름 공간 밖 거부
- 테스트: `plugins/quality-gates/tests/test_qg_worktree_helper.sh` 4.3초(구조를 고침) · `plugins/quality-gates/tests/test_runtime_contract_invariance.sh` 1.7초(줄임) — 합 6.0초
- 짝: test_qg_worktree_helper.sh↔test_runtime_contract_invariance.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — case_remove_namespace_guard 와 `[remove]` 섹션이 같다(양쪽 행)
- 남길 쪽 후보: qg_worktree_helper. runtime_contract 는 「줄임」

### G47. check_deps · entry 의존 확인
- 테스트: `shared/tests/test_check_deps.py` 0.0초(둠) · `shared/tests/test_check_deps.sh` 3.3초(구조를 고침) · `shared/tests/test_entry_dep_needs.sh` 1.5초(둠) — 합 4.8초
- 짝: test_check_deps.py↔test_check_deps.sh 서로 적음(같은 묶음) [내용/내용]; test_check_deps.sh↔test_entry_dep_needs.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 일부 — read_table · entry 서브커맨드 일부를 겹쳐 잰다(양쪽 행), py 행은 「동작 범위는 다름」
- 남길 쪽 후보: 행들이 정하지 않음

### G48. 포화 판정 두 묶음 기준 문장
- 테스트: `plugins/spec-distill/tests/test_research_agents_frontmatter.sh` 0.5초(둠) · `plugins/spec-distill/tests/test_saturation_reference.sh` 0.4초(줄임) — 합 0.9초
- 짝: test_research_agents_frontmatter.sh↔test_saturation_reference.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 양쪽이 같은 문장을 각자 잰다(양쪽 행)
- 남길 쪽 후보: saturation_reference 로(research_agents 행: 「saturation 문장 핀만 나중에 합칠 만하다」)

### G49. CLAUDE.md 의 agent 격리 문장
- 테스트: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` 0.3초(줄임) · `plugins/quality-gates/tests/test_law2_prose.sh` 0.2초(둠) — 합 0.5초
- 짝: test_governance_no_capability_caps.sh↔test_law2_prose.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 문장을 둘 다 잰다(양쪽 행)
- 남길 쪽 후보: 행들이 정하지 않음

### G50. 「(권장)」 추천 문장
- 테스트: `shared/tests/test_ask_recommendation.sh` 0.3초(둠) · `shared/tests/test_plain_language_block.sh` 0.2초(줄임) — 합 0.5초
- 짝: test_ask_recommendation.sh↔test_plain_language_block.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 추천 문장(REC)을 둘 다 핀(양쪽 행)
- 남길 쪽 후보: 행들이 정하지 않음

### G51. plugin-audit 리포트 렌더 문구 · SKILL codex 게이트 마커
- 테스트: `plugins/plugin-audit/tests/test_plain_audit_text.py` 0.5초(줄임) · `plugins/plugin-audit/tests/test_render_audit_report.py` 1.0초(구조를 고침) · `plugins/plugin-audit/tests/test_skill_orchestration.py` 0.0초(줄임) · `plugins/plugin-audit/tests/test_skill_codex_gate.py` 0.0초(둠) · `plugins/plugin-audit/tests/test_severity_mapping.py` 0.0초(줄임) — 합 1.5초
- 짝: test_plain_audit_text.py↔test_render_audit_report.py 서로 적음(같은 묶음) [내용/내용]; test_plain_audit_text.py↔test_skill_orchestration.py 서로 적음(같은 묶음) [내용/내용]; test_plain_audit_text.py↔test_skill_codex_gate.py 한쪽만(test_skill_codex_gate.py→) [—/내용]; test_render_audit_report.py↔test_severity_mapping.py 서로 적음(같은 묶음) [내용/내용]; test_skill_orchestration.py↔test_skill_codex_gate.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지(shallow-01 한 사람) — 같은 렌더 배너 문구 · 같은 SKILL 종료 보고 · 같은 codex 게이트 마커와 kill switch 이름 · 정렬 순서를 둘씩 잰다
- 남길 쪽 후보: 행들이 정하지 않음(대부분 「줄임」)

### G52. 축 3 창의 kill switch 문구(audit-workflow.js)
- 테스트: `plugins/plugin-audit/tests/audit-workflow.test.mjs` 0.2초(둠) · `plugins/plugin-audit/tests/test_axis3_reachability_question.sh` 0.1초(지움) — 합 0.3초
- 짝: audit-workflow.test.mjs↔test_axis3_reachability_question.sh 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 내용까지 — 같은 소스 창을 읽어 같은 문구를 확인(양쪽 행)
- 남길 쪽 후보: audit-workflow.test.mjs(둠). axis3 은 「지움」 — 어긋남 절 참조

### G53. Law 2 — 감사 agent tools allowlist
- 테스트: `plugins/plugin-audit/tests/test_agents_generic.py` 0.0초(줄임) · `plugins/plugin-audit/tests/test_check_law2.py` 0.2초(둠) — 합 0.2초
- 짝: test_agents_generic.py↔test_check_law2.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 agent 의 tools 를 글자로 / 실제 게이트로(양쪽 행)
- 남길 쪽 후보: check_law2(게이트). agents_generic 은 「줄임」

### G54. README · CHANGELOG 문서 핀(team-files.md · changelog_entries)
- 테스트: `plugins/spec-distill/tests/test_team_docs.py` 0.1초(줄임) · `plugins/spec-distill/tests/test_walk_docs.py` 0.0초(줄임) — 합 0.1초
- 짝: test_team_docs.py↔test_walk_docs.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 문서 · 다른 문장(양쪽 행)
- 남길 쪽 후보: 행들이 정하지 않음

### G55. 상태 루트 — 연결된 worktree 케이스
- 테스트: `plugins/spec-distill/tests/test_state_path.sh` 1.9초(둠) · `plugins/spec-distill/tests/test_state_root.sh` 3.4초(구조를 고침) · `plugins/spec-distill/tests/test_hook_output_schema.py` 0.0초(지움) — 합 5.3초
- 짝: test_state_path.sh↔test_state_root.sh 서로 적음(같은 묶음) [내용/내용]; test_state_root.sh↔test_hook_output_schema.py 한쪽만(test_hook_output_schema.py→) [—/내용]
- 겹치는 정도: path ↔ root: worktree 케이스 겹침(양쪽 행). hook_output_schema → 둘: 한쪽만(「내용은 앞쪽만 확인」)
- 남길 쪽 후보: hook_output_schema 「지움」(34번 고침)

### G56. 실행 폴더 생성기 · ac6 픽스처
- 테스트: `plugins/plugin-audit/tests/test_prepare_run_dir.py` 0.4초(둠) · `plugins/plugin-audit/tests/test_run_dir_pipeline.py` 0.2초(둠) · `plugins/plugin-audit/tests/test_ac6_regression.py` 0.0초(줄임) — 합 0.6초
- 짝: test_prepare_run_dir.py↔test_run_dir_pipeline.py 서로 적음(같은 묶음) [내용/내용]; test_run_dir_pipeline.py↔test_ac6_regression.py 서로 적음(같은 묶음) [내용/내용]
- 겹치는 정도: 같은 생성기 · 같은 픽스처를 다시 돌린다(양쪽 행) — 지키는 것은 다름(경로 탈출 대 git status 깨끗함)
- 남길 쪽 후보: 셋 다 1초 미만 · 행들은 둠

### G57. codex 웹 끄기 스위치 — 정적 대조 대 실행
- 테스트: `plugins/spec-distill/tests/test_web_kill_switch.sh` 4.0초(둠) · `plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh` 14.1초(둠) · `shared/tests/test_docreview_codex.sh` 19.4초(둠) — 합 37.5초
- 짝: test_web_kill_switch.sh↔test_reviewing_brief_critic_select.sh 서로 적음(다른 묶음) [내용/내용]; test_web_kill_switch.sh↔test_docreview_codex.sh 서로 적음(다른 묶음) [내용/내용]
- 겹치는 정도: 역할 분담 — web_kill_switch 는 글자로, 실행은 critic_select 에 맡긴다고 적음(양쪽 행)
- 남길 쪽 후보: 보안 갈래 · 셋 다 「둠」. 짝으로 의도된 분담

### G58. seed 게이트 배선 — codex 게이트 표지 · 러너 호출
- 테스트: `plugins/spec-distill/tests/test_seed_codex_axes.sh` 0.1초(둠) · `plugins/spec-distill/tests/test_seed_gate_wiring.sh` 29.8초(둠) — 합 29.9초
- 짝: test_seed_codex_axes.sh↔test_seed_gate_wiring.sh 서로 적음(다른 묶음) [확인 못 함/내용]
- 겹치는 정도: gate_wiring 행: codex_axes 가 같은 SKILL 의 표지 · 러너 호출을 글자로(내용). codex_axes 행: 「확인 못 함」
- 남길 쪽 후보: 행들이 정하지 않음

### G59. 호출 표면 검사기 축 E(metadata 아래 cost_class)
- 테스트: `shared/tests/test_invocation_surface.sh` 20.8초(구조를 고침) · `shared/tests/test_skill_cost_class_place.sh` 1.4초(구조를 고침) — 합 22.2초
- 짝: test_invocation_surface.sh↔test_skill_cost_class_place.sh 서로 적음(다른 묶음) [내용/확인 못 함]
- 겹치는 정도: invocation_surface 행: 같은 검사기로 축 E 의 일부(내용). cost_class_place 행: 「확인 못 함」
- 남길 쪽 후보: 행들이 정하지 않음

### 짝이지만 같은 것을 지키지 않는다고 행이 밝힌 것(묶음에서 뺌)
- `shared/tests/test_adjudication_consumed.sh` 0.3 ↔ `shared/tests/test_adjudication_wiring.sh` 2.6 — 양쪽 행이 「지키는 축은 다름(소비 대 배선)」 · 「중복은 아님」.
- `shared/tests/test_docreview_advice_procedure.sh` 0.3 · `shared/tests/test_docreview_procedure_paths.sh` 0.4 · `shared/tests/test_docreview_round_gate_split.sh` 0.2 — 같은 절차서 · skill 을 읽지만 「다른 문구를 핀한다(문구가 겹치진 않음)」.
- `shared/tests/test_window_phrases.sh` 0.7 ↔ `tools/plain-language/test_measure_questions.py` 0.0 — 같은 문구 목록 파일을 읽지만 「지키는 것은 다르다」.
- `shared/tests/test_dispatch_disposition.sh` 0.2 ↔ `shared/tests/test_dispatch_name_defined.sh` 0.8 · `shared/tests/test_docreview_copy_set.sh` 0.6 — 「방향이 반대(정의에서 호출 대 호출에서 정의)」 · 사각을 메우는 짝.
- `plugins/quality-gates/tests/test_run_test_selection.sh` 7.0 ↔ `plugins/quality-gates/tests/test_runner_adapters.sh` 7.8 — 「같은 스크립트를 나눠 맡음(겹침 적음)」 · R21 은 「축이 다르다」. `shared/tests/test_test_selection_bundle.sh` 0.9 는 링크 배포 관점만.
- `plugins/quality-gates/tests/test_qg_objects_unreachable.sh` 2.7 ↔ `plugins/quality-gates/tests/test_seal_no_side_effects.sh` 2.1 — 봉인 부작용 대 도달 불가, 서로 「재지 않는다」.
- `plugins/quality-gates/tests/test_build_codex_prompt.sh` 0.2 ↔ `plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh` 2.8 — 같은 빌더의 「서로 다른 확인」.
- `shared/tests/test_copy_of_contract.sh` 40.8 ↔ `shared/tests/test_no_new_duplication.sh` 1.0 — 서로 일을 넘기는 짝(마커 실재 대 실제 동일성).
- `plugins/project-init/tests/test_command_contract.py` 0.0 ↔ `plugins/project-init/tests/test_no_write_matcher_hooks.sh` 0.1 — 같은 hooks.json 을 읽는 「다른 확인」.
- `plugins/spec-distill/tests/test_roadmap_write.py` 0.0 ↔ `plugins/spec-distill/tests/test_roadmap_write_atomic.py` 0.0 — Txn 되돌리기의 다른 면(정상 경로 대 짧은 쓰기).
- `plugins/spec-distill/tests/test_roadmap_write.sh` 17.5 ↔ `plugins/spec-distill/tests/test_team_write.sh` 58.5 — 소비자 관계(team_write 가 옛 형식 update 를 roadmap_write 에 맡긴다고 밝힘).
- `plugins/spec-distill/tests/test_next_session_command.sh` 0.1 ↔ `plugins/spec-distill/tests/test_proceed_gate_adopters.sh` 0.2 — 같은 adopter_derivation.sh 로 채택자 집합을 각자 도출하나 재는 규칙이 다름.
- `plugins/quality-gates/tests/test_agent_stub_harness.py` 0.0 ↔ `plugins/quality-gates/tests/test_security_reviewer_behavior.py` 0.0 — 하니스와 그 사용자.
- `plugins/plugin-audit/tests/test_codex_audit_to_json.py` 0.4 ↔ `plugins/plugin-audit/tests/test_preamble_schema_parity.py` 0.0 — 같은 변환기를 다른 입력으로(보완).
- `plugins/spec-distill/tests/test_brief_bundle.sh` 4.8 ↔ `plugins/spec-distill/tests/test_brief_inline_blob.sh` 0.4 — 「같은 부류(다른 스크립트)」.
- `plugins/spec-distill/tests/test_framing_raw_source.sh` 25.6 ↔ `plugins/spec-distill/tests/test_framing_review_contract.sh` 15.1 — 「같은 SKILL 의 다른 절」. seed_edit_diff · seed_edit_screen · state_dir_writes 와의 짝은 대부분 「같은 스크립트의 다른 면」 이고 한쪽이 「확인 못 함」.
- `plugins/spec-distill/tests/test_job_results.sh` 33.1 ↔ `plugins/spec-distill/tests/test_team_results.py` 0.0 · `plugins/quality-gates/tests/test_e2e_fixture_app.sh` 1.8 ↔ `plugins/quality-gates/tests/test_e2e_state.sh` 14.3 · `plugins/spec-distill/tests/test_gh_repo.py` 0.0 ↔ `plugins/spec-distill/tests/test_gh_repo.sh` 4.5 · `shared/tests/test_entry_preflight.sh` 2.7 ↔ `shared/tests/test_switch_tables.sh` 0.6 · `plugins/project-init/tests/test_branch_prefix_templates.py` 0.8 ↔ `plugins/project-init/tests/test_post_tool_use.py` 5.3 · `plugins/spec-distill/tests/test_repo_defaults.py` 0.1 ↔ `plugins/spec-distill/tests/test_repo_defaults_git.sh` 6.2 · `plugins/spec-distill/tests/test_team_rules.py` 0.0 ↔ `plugins/spec-distill/tests/test_team_rules.sh` 3.4 · `plugins/spec-distill/tests/test_readme_sync.sh` 0.3 ↔ `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` 1.1 · `shared/tests/test_docreview_agent_fields.sh` 0.7 ↔ `shared/tests/test_docreview_agents.sh` 0.5 · `plugins/plugin-audit/tests/test_run_audit_codex_reviewer.py` 0.6 ↔ `plugins/plugin-audit/tests/test_untrusted_data_clause.py` 0.0 · `plugins/plugin-audit/tests/test_assemble_audit_data.py` 0.6 ↔ `plugins/plugin-audit/tests/test_validate_audit_data.py` 1.9 — 같은 스크립트 · 파일의 이웃 확인. 겹치는 몇 줄이 있거나(「폴더 값 거절 몇 줄」 · 「예산 · 누락 파일 일부」 · 「README G1–G6 범위」) 한쪽 또는 양쪽이 「확인 못 함」 이라 묶음으로 세우지 않았다.

## 되풀이되는 꼴

꼴은 행의 「크기」 와 깊게 읽은 묶음의 「시간을 쓰는 곳」 칸에서 뽑았다(고치는 길 칸의 낱말로는 뽑지 않았다). 한 테스트가 여러 꼴에 들 수 있어 꼴마다의 초의 합은 겹친다. 여섯 꼴 가운데 하나라도 든 테스트는 209개 · 3606.0초(전체 3795.4초)다. 초는 테스트 하나 전체의 시간이지 그 꼴이 쓰는 몫이 아니다. 꼴의 몫을 행이 어림한 곳은 따로 적었다.

### P1. 임시 git 레포 · bare 원격 · 클론을 케이스마다 새로 세운다 — 116개 · 2417.7초
- 행이 적은 규모의 예: `test_conductor_branch.py` 약 101케이스가 각자 bare 원격 + file:// 클론 + push · `test_review_diff.sh` 픽스처 약 66번 · `test_human_gate.sh` 팀 레포 15번 · `test_roadmap_status.sh` git 400번 넘게 · `test_finish_pr_merge.sh` 셸 둘 × 레포 23 · `test_audit_sandbox_mutation_guard.sh` 레포 + 샌드박스 약 38개.
- 행이 적은 고치는 길: 기본 레포를 한 번 지어 케이스마다 `cp -R` / `shutil.copytree`(원격 경로는 `git remote set-url` 로 맞춤 — review_diff · interview_state_flow 행), setUpClass 로 한 번(conductor_* · suite_timing 행), 레포를 바꾸지 않는 읽기 전용 케이스는 레포 하나를 함께(topic_boundary · e2e_state · resolve_range 행), git 이 필요 없는 케이스는 나누기(conductor_branch · conductor_status · ledger 행). 고치지 말라는 행도 있다: `test_post_tool_use_branch.sh` 는 reflog 시각이 판정 입력이라 한 클론 재사용은 이득보다 위험이 크다, `test_human_judge.py` 는 커밋을 쌓는 테스트라 레포를 새로 두는 것이 필요하다.
- 같은 준비물을 여러 테스트가 각자 세우는 경우:
  - **팀 레포(team_repo · new_repo: bare origin + roadmap_write original · create + push + 지휘 표지)** — 15개 · 843.0초: `plugins/spec-distill/tests/test_human_gate.sh` 148.2 · `plugins/spec-distill/tests/test_human_gate_e2e.sh` 139.0 · `plugins/spec-distill/tests/test_team_status.sh` 134.3 · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9 · `plugins/spec-distill/tests/test_team_tasks.sh` 64.8 · `plugins/spec-distill/tests/test_start_bundle.sh` 64.7 · `plugins/spec-distill/tests/test_human_record.sh` 61.6 · `plugins/spec-distill/tests/test_walk_next.sh` 46.6 · `plugins/spec-distill/tests/test_job_results.sh` 33.1 · `plugins/spec-distill/tests/test_team_stale.sh` 24.2 · `plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh` 23.6 · `plugins/spec-distill/tests/test_team_coverage.sh` 10.0 · `plugins/spec-distill/tests/test_team_sync.sh` 7.8 · `plugins/spec-distill/tests/test_team_review_entry.sh` 5.8 · `plugins/spec-distill/tests/test_team_rules.sh` 3.4. `test_team_review_entry.sh` 행: 「team_repo 세우기(15개 테스트 파일이 각자 반복)」. `test_walk_next.sh` 행: 같은 템플릿을 team_tasks · team_status 도 쓸 수 있다.
  - **StateRepo 계열(케이스마다 bare 원격 + 클론 + 커밋 · push + 표지 · 상태 브랜치)** — 7개 · 739.2초: `plugins/spec-distill/tests/test_conductor_branch.py` 150.0 · `plugins/spec-distill/tests/test_conductor_cross.py` 141.5 · `plugins/spec-distill/tests/test_conductor_status.py` 126.3 · `plugins/spec-distill/tests/test_conductor_mail.py` 111.7 · `plugins/spec-distill/tests/test_leader_seat.py` 92.2 · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6 · `plugins/spec-distill/tests/test_parallel_recommend.py` 29.9. 행 어림: status 케이스당 약 3.4초, mail 케이스당 약 2.5초가 준비.
  - **mkfix(A/R 템플릿: 레포 + 곁가지 + 클론)** — 3개 · 63.0초: `plugins/quality-gates/tests/test_review_diff.sh` 53.5 · `plugins/quality-gates/tests/test_range_wiring.sh` 5.5 · `plugins/quality-gates/tests/test_resolve_range.sh` 4.0.
  - **mkrepo(bare + clone + push)** — 6개 · 86.2초: `plugins/spec-distill/tests/test_merge_check.sh` 28.5 · `plugins/spec-distill/tests/test_workspace_invariance.sh` 20.2 · `plugins/spec-distill/tests/test_default_branch.sh` 13.5 · `plugins/quality-gates/tests/test_intent_critic_wiring.sh` 10.8 · `plugins/quality-gates/tests/test_run_test_selection.sh` 7.0 · `plugins/spec-distill/tests/test_repo_defaults_git.sh` 6.2. 이름이 같을 뿐 파일마다 따로 정의된 도우미인지는 행이 적지 않았다.
  - **session_fixture.py(가짜 질문 창 세션 기록)** — 4개 · 350.4초: `plugins/spec-distill/tests/test_human_gate.sh` 148.2 · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9 · `plugins/spec-distill/tests/test_start_bundle.sh` 64.7 · `plugins/spec-distill/tests/test_human_record.sh` 61.6.
- 전체 목록: `plugins/spec-distill/tests/test_conductor_branch.py` 150.0 · `plugins/spec-distill/tests/test_human_gate.sh` 148.2 · `plugins/spec-distill/tests/test_conductor_cross.py` 141.5 · `plugins/spec-distill/tests/test_human_gate_e2e.sh` 139.0 · `plugins/spec-distill/tests/test_team_status.sh` 134.3 · `plugins/spec-distill/tests/test_conductor_status.py` 126.3 · `plugins/spec-distill/tests/test_conductor_mail.py` 111.7 · `plugins/spec-distill/tests/test_leader_seat.py` 92.2 · `plugins/spec-distill/tests/test_roadmap_status.sh` 92.2 · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6 · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9 · `plugins/spec-distill/tests/test_finish_pr_merge.sh` 71.3 · `plugins/spec-distill/tests/test_team_tasks.sh` 64.8 · `plugins/spec-distill/tests/test_start_bundle.sh` 64.7 · `plugins/spec-distill/tests/test_human_record.sh` 61.6 · `plugins/quality-gates/tests/test_review_diff.sh` 53.5 · `plugins/spec-distill/tests/test_walk_next.sh` 46.6 · `plugins/quality-gates/tests/test_other_teams.py` 41.0 · `plugins/spec-distill/tests/test_ledger_wiring.sh` 36.2 · `plugins/spec-distill/tests/test_job_results.sh` 33.1 · `plugins/quality-gates/tests/test_intent_critic.py` 31.7 · `plugins/spec-distill/tests/test_parallel_recommend.py` 29.9 · `plugins/spec-distill/tests/test_merge_check.sh` 28.5 · `plugins/spec-distill/tests/test_team_stale.sh` 24.2 · `plugins/quality-gates/tests/test_topic_head.sh` 24.0 · `plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh` 23.6 · `plugins/quality-gates/tests/test_topic_boundary.sh` 20.4 · `plugins/spec-distill/tests/test_workspace_invariance.sh` 20.2 · `plugins/quality-gates/tests/test_intent_wide.py` 20.0 · `plugins/plugin-audit/tests/test_audit_sandbox_mutation_guard.sh` 19.8 · `plugins/spec-distill/tests/test_roadmap_write.sh` 17.5 · `plugins/quality-gates/tests/test_e2e_state.sh` 14.3 · `plugins/spec-distill/tests/test_interview_raw_source_entry.sh` 13.6 · `plugins/spec-distill/tests/test_default_branch.sh` 13.5 · `plugins/spec-distill/tests/test_interview_state_flow.sh` 13.0 · `plugins/plugin-audit/tests/test_run_own_tests.py` 12.7 · `plugins/quality-gates/tests/test_publish_comment_sink.sh` 12.6 · `plugins/quality-gates/tests/test_discover_spec.sh` 12.1 · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh` 11.7 · `plugins/spec-distill/tests/test_human_judge.py` 11.7 · `plugins/spec-distill/tests/test_state_dir_writes.sh` 11.7 · `tools/suite/test_suite_timing.py` 11.7 · `plugins/quality-gates/tests/test_intent_critic_wiring.sh` 10.8 · `plugins/spec-distill/tests/test_team_coverage.sh` 10.0 · `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` 8.5 · `plugins/plugin-audit/tests/test_audit_sandbox_create.sh` 8.2 · `plugins/quality-gates/tests/test_runner_adapters.sh` 7.8 · `plugins/spec-distill/tests/test_team_sync.sh` 7.8 · `plugins/quality-gates/tests/test_intent_return.py` 7.6 · `plugins/quality-gates/tests/test_verdict_no_reread.sh` 7.5 · `plugins/quality-gates/tests/test_run_test_selection.sh` 7.0 · `plugins/spec-distill/tests/test_spec_review_bundle.sh` 6.8 · `plugins/spec-distill/tests/test_conductor_state_branch_docs.py` 6.6 · `plugins/spec-distill/tests/test_repo_defaults_git.sh` 6.2 · `plugins/spec-distill/tests/test_team_review_entry.sh` 5.8 · `plugins/quality-gates/tests/test_range_wiring.sh` 5.5 · `plugins/spec-distill/tests/test_bundle_coverage.sh` 5.4 · `plugins/project-init/tests/test_post_tool_use.py` 5.3 · `plugins/spec-distill/tests/test_first_cell_check.py` 5.3 · `plugins/spec-distill/tests/test_ledger_root.sh` 5.3 · `plugins/spec-distill/tests/test_brief_bundle.sh` 4.8 · `plugins/quality-gates/tests/test_publish_pipeline_wiring.sh` 4.7 · `plugins/spec-distill/tests/test_state_storage_e2e.sh` 4.7 · `shared/tests/test_inline_python_isolated.sh` 4.6 · `plugins/spec-distill/tests/test_gh_repo.sh` 4.5 · `plugins/spec-distill/tests/test_interview_state.py` 4.4 · `plugins/quality-gates/tests/test_qg_worktree_helper.sh` 4.3 · `plugins/spec-distill/tests/test_ask_material_wiring.sh` 4.2 · `plugins/spec-distill/tests/test_raw_source_text.py` 4.2 · `plugins/quality-gates/tests/test_resolve_baseline.sh` 4.1 · `plugins/spec-distill/tests/test_ledger_sweep.py` 4.1 · `plugins/quality-gates/tests/test_resolve_range.sh` 4.0 · `plugins/quality-gates/tests/test_diff_test_results.py` 3.6 · `plugins/spec-distill/tests/test_state_root.sh` 3.4 · `plugins/spec-distill/tests/test_team_rules.sh` 3.4 · `plugins/spec-distill/tests/test_raw_source_downstream.sh` 3.3 · `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh` 2.9 · `plugins/quality-gates/tests/test_qg_objects_unreachable.sh` 2.7 · `plugins/spec-distill/tests/test_merged_pr_range.py` 2.7 · `shared/tests/test_entry_preflight.sh` 2.7 · `plugins/quality-gates/tests/test_check_review_scope.sh` 2.4 · `plugins/spec-distill/tests/test_decompose_surface.sh` 2.4 · `plugins/quality-gates/tests/test_guards_declaration_mapping.sh` 2.3 · `plugins/quality-gates/tests/test_seal_no_side_effects.sh` 2.1 · `shared/tests/test_codex_project_doc_off.sh` 2.0 · `plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py` 1.9 · `plugins/quality-gates/tests/test_differential_trees.sh` 1.9 · `plugins/quality-gates/tests/test_gh_repo.sh` 1.9 · `plugins/quality-gates/tests/test_isolation.sh` 1.9 · `plugins/spec-distill/tests/test_raw_source.py` 1.9 · `plugins/spec-distill/tests/test_state_path.sh` 1.9 · `plugins/quality-gates/tests/test_runtime_contract_invariance.sh` 1.7 · `plugins/spec-distill/tests/test_seed_inline_blob.sh` 1.7 · `plugins/spec-distill/tests/test_team_status_stub.sh` 1.7 · `plugins/quality-gates/tests/test_skill_run_contract.sh` 1.6 · `shared/tests/test_skill_cost_class_place.sh` 1.4 · `plugins/spec-distill/tests/test_walk_table.py` 1.2 · `plugins/quality-gates/tests/test_review_scope_composition.sh` 1.1 · `plugins/plugin-audit/tests/test_check_integrity.py` 1.0 · `plugins/quality-gates/tests/test_v_requirements.sh` 1.0 · `plugins/quality-gates/tests/test_differential_procedure.sh` 0.9 · `plugins/spec-distill/tests/test_kill_switches_v060.sh` 0.9 · `plugins/spec-distill/tests/test_request_framing_entry.sh` 0.9 · `plugins/project-init/tests/test_branch_prefix_templates.py` 0.8 · `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` 0.8 · `plugins/quality-gates/tests/test_artifact_branch_guard.sh` 0.6 · `plugins/quality-gates/tests/test_artifact_commit.sh` 0.5 · `plugins/quality-gates/tests/test_worktree.sh` 0.5 · `plugins/quality-gates/tests/test_discover_spec_keys.sh` 0.4 · `plugins/spec-distill/tests/test_coverage_scope.py` 0.4 · `plugins/spec-distill/tests/test_control_plane.py` 0.3 · `plugins/spec-distill/tests/test_resume_candidate_names.sh` 0.3 · `plugins/plugin-audit/tests/test_run_dir_pipeline.py` 0.2 · `plugins/quality-gates/tests/test_qg_critique_routing.sh` 0.2 · `plugins/quality-gates/tests/test_removed_plan_arg.sh` 0.1 · `plugins/spec-distill/tests/test_repo_defaults.py` 0.1

### P2. 확인 · 단언 · 케이스마다 스크립트(대개 python)를 새 프로세스로 띄운다 — 124개 · 2528.3초
- 행이 적은 규모의 예: `test_check_brief.sh` check_brief.py(약 3,300줄 import)를 약 900번 · `test_intent_critic.py` 하위 프로세스 약 400번 · `test_seed_trust_boundary.sh` 약 350번 · `test_team_status.sh` 단언마다 python 약 263곳 · `test_roadmap_status.sh` js 287회 · `test_verdict_no_reread.sh` 약 230번 · `test_human_record.sh` · `test_team_tasks.sh` 약 150번.
- 행이 적은 고치는 길: 한 케이스의 여러 jget/jgets/js 단언을 python 한 번으로 묶어 값 묶음을 받기(docreview_route · advice · roadmap_status · team_tasks · post_tool_use_branch 행), 스크립트를 import 하는 프로세스 안 단위 테스트로 내리기(docreview_state · seed_edit_screen · intent_critic · team_tasks 행), 파일마다 띄우는 스캐너를 한 번의 스캔으로(skill_cost_class_place · variant_of_contract · conducting_reference 행).
- 같은 준비물:
  - **docreview 원장 도우미(cases.sh 의 r1 · route_r1 · next_round: init · snapshot · begin-round 를 python 으로)** — 15개 · 671.1초: `shared/tests/test_docreview_mutations.sh` 233.0 · `shared/tests/test_docreview_state.sh` 134.4 · `shared/tests/test_docreview_route.sh` 76.1 · `shared/tests/test_docreview_advice.sh` 72.7 · `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` 47.9 · `plugins/spec-distill/tests/test_seed_edit_screen.sh` 18.5 · `plugins/spec-distill/tests/test_framing_review_contract.sh` 15.1 · `shared/tests/test_docreview_ask.sh` 14.9 · `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` 14.1 · `plugins/spec-distill/tests/test_interview_state_flow.sh` 13.0 · `shared/tests/test_docreview_gate_plain.sh` 11.9 · `shared/tests/test_docreview_intent.sh` 7.5 · `shared/tests/test_docreview_gate_visibility.sh` 5.6 · `plugins/spec-distill/tests/test_begin_round_snapshot.sh` 3.6 · `plugins/spec-distill/tests/test_seed_review_log.sh` 2.8. 고치는 길: 같은 프로필 · 문서의 r1 원장을 한 번 지어 `cp -R`(intent · route · advice · gate_visibility 행).
  - **roadmap_status.py 를 상태마다 다시 실행** — 7개 · 414.8초: `plugins/spec-distill/tests/test_team_status.sh` 134.3 · `plugins/spec-distill/tests/test_roadmap_status.sh` 92.2 · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6 · `plugins/spec-distill/tests/test_team_tasks.sh` 64.8 · `plugins/spec-distill/tests/test_team_stale.sh` 24.2 · `plugins/spec-distill/tests/test_team_coverage.sh` 10.0 · `plugins/spec-distill/tests/test_team_status_stub.sh` 1.7. 고치는 길: 보고서 하나를 python 한 번에 읽어 여러 식을 판정(roadmap_status 행), roadmap_status.build 를 직접 부르는 단위 테스트(team_tasks 행).
  - **check_brief.py gate 를 케이스마다** — 3개 · 79.4초: `plugins/spec-distill/tests/test_check_brief.sh` 50.7 · `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` 16.7 · `plugins/spec-distill/tests/test_brief_form_r2.sh` 12.0.
- 전체 목록: `shared/tests/test_docreview_mutations.sh` 233.0 · `plugins/spec-distill/tests/test_conductor_branch.py` 150.0 · `plugins/spec-distill/tests/test_conductor_cross.py` 141.5 · `shared/tests/test_docreview_state.sh` 134.4 · `plugins/spec-distill/tests/test_team_status.sh` 134.3 · `plugins/spec-distill/tests/test_conductor_status.py` 126.3 · `plugins/spec-distill/tests/test_conductor_mail.py` 111.7 · `plugins/spec-distill/tests/test_leader_seat.py` 92.2 · `plugins/spec-distill/tests/test_roadmap_status.sh` 92.2 · `plugins/spec-distill/tests/test_conductor_ledger.py` 87.6 · `shared/tests/test_docreview_route.sh` 76.1 · `plugins/spec-distill/tests/test_leader_seat_e2e.sh` 75.9 · `shared/tests/test_docreview_advice.sh` 72.7 · `plugins/spec-distill/tests/test_team_tasks.sh` 64.8 · `plugins/spec-distill/tests/test_start_bundle.sh` 64.7 · `plugins/spec-distill/tests/test_human_record.sh` 61.6 · `plugins/spec-distill/tests/test_check_brief.sh` 50.7 · `plugins/spec-distill/tests/test_walk_next.sh` 46.6 · `plugins/spec-distill/tests/test_ledger_wiring.sh` 36.2 · `plugins/spec-distill/tests/test_job_results.sh` 33.1 · `plugins/quality-gates/tests/test_intent_critic.py` 31.7 · `plugins/spec-distill/tests/test_parallel_recommend.py` 29.9 · `plugins/spec-distill/tests/test_framing_raw_source.sh` 25.6 · `plugins/spec-distill/tests/test_team_stale.sh` 24.2 · `plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh` 23.6 · `shared/tests/test_invocation_surface.sh` 20.8 · `plugins/quality-gates/tests/test_intent_wide.py` 20.0 · `shared/tests/test_docreview_codex.sh` 19.4 · `plugins/project-init/tests/test_post_tool_use_branch.sh` 19.1 · `plugins/spec-distill/tests/test_seed_edit_screen.sh` 18.5 · `plugins/spec-distill/tests/test_roadmap_write.sh` 17.5 · `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` 16.7 · `shared/tests/test_docreview_ask.sh` 14.9 · `plugins/spec-distill/tests/test_seed_trust_boundary.sh` 14.8 · `plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh` 14.1 · `plugins/spec-distill/tests/test_reviewing_spec_residue.sh` 14.1 · `plugins/spec-distill/tests/test_conducting_loop.sh` 13.2 · `plugins/plugin-audit/tests/test_run_own_tests.py` 12.7 · `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` 12.7 · `plugins/quality-gates/tests/test_publish_comment_sink.sh` 12.6 · `plugins/quality-gates/tests/test_discover_spec.sh` 12.1 · `plugins/spec-distill/tests/test_brief_form_r2.sh` 12.0 · `shared/tests/test_docreview_gate_plain.sh` 11.9 · `plugins/spec-distill/tests/test_repo_literals.sh` 11.8 · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh` 11.7 · `plugins/spec-distill/tests/test_team_coverage.sh` 10.0 · `plugins/spec-distill/tests/test_conductor_e2e.sh` 9.4 · `plugins/quality-gates/tests/test_synthesize_recritic.sh` 8.1 · `plugins/quality-gates/tests/test_runner_adapters.sh` 7.8 · `plugins/spec-distill/tests/test_team_sync.sh` 7.8 · `plugins/quality-gates/tests/test_intent_return.py` 7.6 · `plugins/quality-gates/tests/test_verdict_no_reread.sh` 7.5 · `shared/tests/test_docreview_intent.sh` 7.5 · `plugins/spec-distill/tests/test_spec_review_bundle.sh` 6.8 · `shared/tests/test_nofollow_write.sh` 6.6 · `plugins/spec-distill/tests/test_conducting_reference.sh` 6.3 · `plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh` 6.2 · `shared/tests/test_docreview_gate_visibility.sh` 5.6 · `plugins/quality-gates/tests/test_range_wiring.sh` 5.5 · `plugins/spec-distill/tests/test_bundle_coverage.sh` 5.4 · `plugins/spec-distill/tests/test_first_cell_check.py` 5.3 · `plugins/quality-gates/tests/test_angle_coverage.sh` 5.1 · `plugins/spec-distill/tests/test_brief_bundle.sh` 4.8 · `plugins/spec-distill/tests/test_interview_state.py` 4.4 · `plugins/spec-distill/tests/test_ask_material_wiring.sh` 4.2 · `plugins/spec-distill/tests/test_raw_source_text.py` 4.2 · `plugins/spec-distill/tests/test_begin_round_snapshot.sh` 3.6 · `plugins/spec-distill/tests/test_team_rules.sh` 3.4 · `shared/tests/test_check_deps.sh` 3.3 · `plugins/spec-distill/tests/test_seed_review_log.sh` 2.8 · `shared/tests/test_entry_preflight.sh` 2.7 · `plugins/plugin-audit/tests/test_check_staleness.py` 2.6 · `plugins/quality-gates/tests/test_codex_copies_agree.sh` 2.6 · `plugins/spec-distill/tests/test_seed_edit_diff.sh` 2.2 · `shared/tests/test_variant_of_contract.sh` 2.2 · `plugins/quality-gates/tests/test_synthesize_findings.sh` 2.0 · `plugins/quality-gates/tests/test_verdict_vocabulary.sh` 2.0 · `plugins/spec-distill/tests/test_seed_provenance.sh` 2.0 · `plugins/plugin-audit/tests/test_validate_audit_data.py` 1.9 · `plugins/quality-gates/tests/test_qg_gc.py` 1.9 · `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` 1.9 · `plugins/quality-gates/tests/test_synthesize_ask_line.sh` 1.9 · `plugins/spec-distill/tests/test_raw_source.py` 1.9 · `plugins/spec-distill/tests/test_state_path.sh` 1.9 · `plugins/spec-distill/tests/test_ledger_marker.py` 1.7 · `plugins/spec-distill/tests/test_seed_inline_blob.sh` 1.7 · `plugins/spec-distill/tests/test_team_status_stub.sh` 1.7 · `plugins/quality-gates/tests/test_v1_verdict_line.sh` 1.5 · `plugins/quality-gates/tests/test_codex_exit_meta.sh` 1.4 · `plugins/spec-distill/tests/test_brief_review_state.py` 1.4 · `plugins/spec-distill/tests/test_session_id_resolution.sh` 1.4 · `shared/tests/test_skill_cost_class_place.sh` 1.4 · `plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 1.2 · `plugins/quality-gates/tests/test_e2e_verdict.sh` 1.1 · `plugins/plugin-audit/tests/test_render_audit_report.py` 1.0 · `shared/tests/test_no_new_duplication.sh` 1.0 · `plugins/spec-distill/tests/test_kill_switches_v060.sh` 0.9 · `shared/tests/test_test_selection_bundle.sh` 0.9 · `plugins/plugin-audit/tests/test_check_shape_completeness.py` 0.8 · `plugins/quality-gates/tests/test_findings_parser.sh` 0.7 · `plugins/spec-distill/tests/test_review_entry.py` 0.7 · `plugins/spec-distill/tests/test_seed_cut_table.sh` 0.7 · `shared/tests/test_docreview_agent_fields.sh` 0.7 · `plugins/plugin-audit/tests/test_assemble_audit_data.py` 0.6 · `plugins/plugin-audit/tests/test_run_audit_codex_reviewer.py` 0.6 · `shared/tests/test_switch_tables.sh` 0.6 · `plugins/plugin-audit/tests/test_plain_audit_text.py` 0.5 · `plugins/spec-distill/tests/test_epic_handoff.sh` 0.5 · `plugins/plugin-audit/tests/test_codex_audit_to_json.py` 0.4 · `plugins/plugin-audit/tests/test_prepare_run_dir.py` 0.4 · `plugins/spec-distill/tests/test_brief_inline_blob.sh` 0.4 · `plugins/quality-gates/tests/test_classify_artifact_target.sh` 0.3 · `plugins/quality-gates/tests/test_topic_scope_wiring.sh` 0.3 · `plugins/plugin-audit/tests/test_check_law2.py` 0.2 · `plugins/plugin-audit/tests/test_check_no_verdict_injection.py` 0.2 · `plugins/quality-gates/tests/test_artifact_bounds.sh` 0.2 · `plugins/quality-gates/tests/test_build_codex_prompt.sh` 0.2 · `plugins/quality-gates/tests/test_secret_scan.py` 0.2 · `plugins/quality-gates/tests/test_utf8_explicit.py` 0.2 · `plugins/spec-distill/tests/test_seed_one_sentence.sh` 0.2 · `plugins/plugin-audit/tests/test_detect_codex.py` 0.1 · `plugins/plugin-audit/tests/test_parse_seed.py` 0.1 · `plugins/spec-distill/tests/test_roadmap_migrate.py` 0.1 · `plugins/plugin-audit/tests/test_preamble_schema_parity.py` 0.0

### P3. 고정 대기 · 시간 상한까지 기다림 — 11개 · 179.3초
- 행이 어림한 기다림 몫: `test_control_plane.sh` 30–40초(멈춘 git · 상태 계산 · 닫히지 않는 입력에 상한까지, m-budget · m-nonblock 변이가 timed 10) · `test_codex_runner_degrade_contract.sh` 약 10초(`timeout -s TERM 2` × 5) · `test_default_branch.sh` 약 10초(sleep 7 대역 + 상태줄 예산) · `test_post_tool_use_branch.sh` 약 8–9초(GIT_BUDGET 8초) · `test_e2e_state.sh` 약 5초(boot/stop 폴링) · `tools/suite/test_suite_timing.py` 약 4초(sleep 3 + --wait 1) · `test_suite_lock.py` 약 1.6초 · `test_setup_qg.sh` sleep 1 · 0.5 · 폴링 · `test_merge_check.sh` 1초 · `plugins/spec-distill/tests/test_gh_repo.sh` 0.5초 한도 · `test_control_plane.py` 0.01초. 합치면 행 어림으로 약 70–85초다.
- 행이 적은 고치는 길: 상한을 넘기기만 하면 되는 변이는 상한을 줄인다(control_plane: timed 7), 고정 대기 대신 스텁이 표지 파일을 쓰면 그때 TERM(degrade_contract), 실제 sleep 대신 대역이 받은 timeout 인자를 기록(default_branch — 행은 「대체 확인이 먼저」 라고 단서), 시간 초과 경로는 예산을 줄인 프로세스 안 확인으로(post_tool_use_branch → test_post_tool_use.py), mtime 을 과거로 돌려 sleep 1 없애기(setup_qg). 「줄일 여지가 작다」 고 적은 행: e2e_state · merge_check · suite_lock.
- 시간 문턱이 거짓 실패 위험으로 적힌 곳: `test_review_diff.sh` 의 120초 문턱 하나.
- 전체 목록: `plugins/spec-distill/tests/test_control_plane.sh` 67.3 · `plugins/spec-distill/tests/test_merge_check.sh` 28.5 · `plugins/project-init/tests/test_post_tool_use_branch.sh` 19.1 · `plugins/quality-gates/tests/test_e2e_state.sh` 14.3 · `plugins/spec-distill/tests/test_default_branch.sh` 13.5 · `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` 12.7 · `tools/suite/test_suite_timing.py` 11.7 · `plugins/quality-gates/tests/test_setup_qg.sh` 4.9 · `plugins/spec-distill/tests/test_gh_repo.sh` 4.5 · `plugins/spec-distill/tests/test_suite_lock.py` 2.5 · `plugins/spec-distill/tests/test_control_plane.py` 0.3

### P4. 다른 테스트 · 러너를 통째로 다시 돌린다 — 9개 · 296.6초
- `test_docreview_mutations.sh` — 셀마다 깨끗한 사본에서 같은 케이스를 한 번 더(양성 대조 약 89회, 같은 케이스 87개가 행동 락에 이미 있음). 고치는 길: 행동 락의 같은 케이스 결과로 갈음하거나 서브셸 하나에서 묶기.
- `test_epic_conductor_skill.sh` — 104–107행에서 공유 락 8개(test_invocation_surface.sh · test_dispatch_disposition.sh 등)를 통째로. 행 어림: 시간 거의 전부. 고치는 길: 지운다(스위트가 이미 돌린다).
- `test_agent_model_mutation.sh` — 스윕 9회 · agent 별 락 29회 재실행(test_brief_agents.sh 285줄 · test_steelman_builder_scope.sh 163줄이 매번 통째로). 고치는 길: agent 별 락 변이는 덜고 스윕 변이만.
- `test_entry_safety_e1_e6.sh` — test_qg_gc 유닛과 shared 위치 인자 검사를 다시 돌린다(E3 · E4). 고치는 길: 러너가 이미 각각 돌리므로 뺀다.
- `tools/suite/test_suite_timing.py` — run-all.sh 를 약 20번(안에서 러너를 다시 돈다). 이 도구의 동작 자체라 행은 「둠」.
- `shared/tests/test_docreview_golden.sh` — capture_finalize_golden.sh 로 케이스 다섯의 finalize 를 다시. 행은 「둠」.
- `shared/tests/test_presence_corpus_behavior.sh` — 소비자 락 셋을 통째로, 그중 하나를 두 번. 고치는 길: 소비자 락 출력 재사용 또는 그쪽 단언으로.
- `shared/tests/test_variant_of_contract.sh` — 중복 락 스크립트를 스크래치 레포에서 다시(V3). 고치는 길: 중복 락 쪽으로 옮김.
- `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` — 플러그인 전체를 복사하고 test_brief_agents.sh 를 다시. 고치는 길: grep 한 줄 + 폴더 부재 확인.
- 전체 목록: `shared/tests/test_docreview_mutations.sh` 233.0 · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 28.3 · `tools/suite/test_suite_timing.py` 11.7 · `plugins/quality-gates/tests/test_agent_model_mutation.sh` 6.5 · `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` 6.5 · `shared/tests/test_docreview_golden.sh` 5.0 · `shared/tests/test_presence_corpus_behavior.sh` 2.6 · `shared/tests/test_variant_of_contract.sh` 2.2 · `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` 0.8

### P5. 변이 · 비교용 사본을 통째로 복사한다 — 26개 · 680.5초
- 행이 적은 규모의 예: `test_docreview_mutations.sh` 변이 셀 119개마다 엔진 사본(.py 7개 복사 · diff 7×2) · `test_roadmap_status.sh` scripts 폴더(.py 71개)를 25번 넘게 통째로 · `test_invocation_surface.sh` 레포 clone 뒤 그 사본을 9번 통째로 `cp -R` + 합성 리포 변이 약 70개 · `test_framing_raw_source.sh` 변이 사본 30번에 검사 함수 전체 재실행 · `test_team_write.sh` origin 째 레포 사본 약 20번 clone · `test_control_plane.sh` 변이 사본 18개 · `test_interview_raw_source_entry.sh` 변이 10묶음마다 판정 전체.
- 행이 적은 고치는 길: 한 사본에서 변이 하나 → 검사 → `git checkout -- . && git clean -fdq` 로 되돌리기(invocation_surface), 변이 판정을 메모리 안 소스 문자열로(roadmap_status 의 static_check), 깨끗한 사본 실행을 행동 락과 나누기 · 독립 셀 병렬(docreview_mutations), 사본 둘을 하나로(degrade_contract), 변이 블록을 떼어 덜 자주(control_plane).
- 이미 템플릿 복사를 쓰는 곳: `test_other_teams.py` 는 픽스처 리포를 한 번 짓고 39번 copytree 한다(행: 시간은 collect 의 git 호출).
- 전체 목록: `shared/tests/test_docreview_mutations.sh` 233.0 · `plugins/spec-distill/tests/test_roadmap_status.sh` 92.2 · `plugins/spec-distill/tests/test_control_plane.sh` 67.3 · `plugins/spec-distill/tests/test_team_write.sh` 58.5 · `plugins/spec-distill/tests/test_framing_raw_source.sh` 25.6 · `shared/tests/test_invocation_surface.sh` 20.8 · `plugins/plugin-audit/tests/test_audit_sandbox_mutation_guard.sh` 19.8 · `plugins/spec-distill/tests/test_seed_edit_screen.sh` 18.5 · `plugins/spec-distill/tests/test_roadmap_write.sh` 17.5 · `plugins/spec-distill/tests/test_check_verbatim_coverage.sh` 16.7 · `plugins/spec-distill/tests/test_framing_review_contract.sh` 15.1 · `plugins/spec-distill/tests/test_interview_raw_source_entry.sh` 13.6 · `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` 12.7 · `plugins/spec-distill/tests/test_repo_literals.sh` 11.8 · `plugins/quality-gates/tests/test_intent_critic_wiring.sh` 10.8 · `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` 8.5 · `plugins/spec-distill/tests/test_conductor_state_branch_docs.py` 6.6 · `shared/tests/test_nofollow_write.sh` 6.6 · `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` 6.5 · `plugins/spec-distill/tests/test_bundle_coverage.sh` 5.4 · `plugins/spec-distill/tests/test_first_cell_finishing.sh` 2.9 · `plugins/spec-distill/tests/test_seed_review_log.sh` 2.8 · `plugins/spec-distill/tests/test_seed_edit_diff.sh` 2.2 · `plugins/spec-distill/tests/test_seed_provenance.sh` 2.0 · `plugins/spec-distill/tests/test_seed_inline_blob.sh` 1.7 · `plugins/quality-gates/tests/test_codex_exit_meta.sh` 1.4

### P6. 같은 흐름을 bash · zsh(셸 둘 이상)로 통째로 두 번 — 8개 · 170.7초
- `test_finish_pr_merge.sh` 행: 셸 둘 × 픽스처 23 = 레포 46번. 고치는 길: zsh 바퀴는 셸에 따라 갈리는 케이스(new · mixed · merge · cut · late)만. `test_reviewing_brief_residue.sh` 는 bash · xpg_echo bash · zsh 셋. `test_publish_pipeline_wiring.sh` 는 약 30 케이스 × 2 셸.
- 전체 목록: `plugins/spec-distill/tests/test_finish_pr_merge.sh` 71.3 · `plugins/spec-distill/tests/test_reviewing_brief_residue.sh` 47.9 · `plugins/spec-distill/tests/test_dispatch_profile_inline.sh` 22.0 · `plugins/spec-distill/tests/test_interview_raw_source_entry.sh` 13.6 · `plugins/quality-gates/tests/test_verdict_no_reread.sh` 7.5 · `plugins/quality-gates/tests/test_publish_pipeline_wiring.sh` 4.7 · `plugins/spec-distill/tests/test_first_cell_finishing.sh` 2.9 · `plugins/spec-distill/tests/test_request_framing_open.sh` 0.8

### 덧붙임 — SKILL 펜스를 잘라 차가운 셸(`env -i`)에서 실행
꼴이라기보다 동작 확인의 방식인데, 펜스 한 번에 python 을 여럿 띄워 초가 든다. 행이 적은 예: `plugins/spec-distill/tests/test_seed_gate_wiring.sh` 29.8 약 38번 · `plugins/spec-distill/tests/test_dispatch_profile_inline.sh` 22.0 셀 약 40번(셀마다 python 6–9) · `plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh` 14.1 9번 · `plugins/spec-distill/tests/test_state_dir_writes.sh` 11.7 · `plugins/quality-gates/tests/test_verdict_no_reread.sh` 7.5. 행들은 대부분 「둠」(펜스를 실제로 도는 몇 안 되는 자리).

## 글자에 묶인 테스트

뽑은 기준: 「지키는 것」 이 「글자만 지킴」 으로 시작하거나(A), 「거짓 실패 위험」 이 「높음」 이고 「종류」 에 글자가 섞인(B) 행. A 25개 · B 79개(둘 다 20개) — 합 84개, 고친 횟수 합 1218. 이 밖에 「지키는 것」 안에 「나머지는 글자만 지킴」 처럼 일부만 적힌 행이 8개 있다(아래 묶음에 넣지 않음): `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh` · `plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh` · `plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh` · `plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh` · `plugins/spec-distill/tests/test_compression_adopters.sh` · `plugins/spec-distill/tests/test_conductor_state_branch_docs.py` · `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` · `plugins/spec-distill/tests/test_first_cell_finishing.sh`.

문서 귀속: 행의 「지키는 것」 · 「거짓 실패 위험」 칸이 댄 문서를 레포 경로로 풀었다. 행이 문서를 대지 않았거나 이름이 여럿으로 풀리는 행(예: 「SKILL」 만 적음)은 테스트 파일 안의 문서 경로를 grep 해 보탰다 — 아래에서 「문서는 grep」 표시가 그 경우이고, grep 은 그 파일이 경로를 적었다는 것까지만 말한다(그 문서의 문구를 대조하는지는 행이 말한 범위다). `shared/tests/test_inline_python_isolated.sh` 는 문서 문구가 아니라 코퍼스의 python 호출을 훑는 테스트라 문서 묶음에서 뺐다. 한 테스트가 여러 문서를 재면 여러 묶음에 든다. 둘 이상이 재는 문서 35개:

- `plugins/spec-distill/skills/pm-interview/references/finishing.md` — 14개 · 고친 횟수 합 366: `test_conducting_interview_stage.sh`(고침 141, 보안, 줄임) · `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_end_gates.sh`(고침 26, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_decompose_surface.sh`(고침 25, 보안, 줄임) · `test_brief_review_entry.sh`(고침 23, 문서는 grep, 구조를 고침) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_plain_gate_templates.sh`(고침 19, 구조를 고침) · `test_docreview_procedure_paths.sh`(고침 15, 문서는 grep, 줄임) · `test_saturation_reference.sh`(고침 14, 문서는 grep, 줄임) · `test_superpowers_presence.sh`(고침 11, 줄임) · `test_docreview_advice_procedure.sh`(고침 6, 문서는 grep, 구조를 고침) · `test_brief_no_statement_cap.sh`(고침 6, 합침) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 10개 · 고친 횟수 합 155: `harness/test_skill_orchestration_behavior.sh`(고침 69, 문서는 grep, 보안, 줄임) · `test_topic_scope_wiring.sh`(고침 23, 문서는 grep, 줄임) · `test_codex_backward_compat.sh`(고침 13, 문서는 grep, 보안, 합침) · `test_codex_dispatch_invariant.sh`(고침 12, 문서는 grep, 합침) · `test_one_pipeline_surface.sh`(고침 12, 문서는 grep, 줄임) · `test_skill_orchestration.sh`(고침 11, 문서는 grep, 합침) · `test_git_derived_scope.sh`(고침 6, 문서는 grep, 둠) · `test_codex_result_banner.sh`(고침 4, 문서는 grep, 둠) · `test_cost_disclosure.sh`(고침 3, 문서는 grep, 보안, 둠) · `test_skill_codex_skip_prose.sh`(고침 2, 문서는 grep, 지움)
- `plugins/spec-distill/CHANGELOG.md` — 10개 · 고친 횟수 합 212: `test_readme_sync.sh`(고침 41, 줄임) · `test_stale_terms.sh`(고침 33, 줄임) · `test_end_gates.sh`(고침 26, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_brief_review_meta.sh`(고침 25, 보안, 줄임) · `test_parallel_recommend_docs.sh`(고침 21, 구조를 고침) · `test_team_docs.py`(고침 19, 줄임) · `test_walk_docs.py`(고침 8, 줄임) · `test_no_wall_clock.sh`(고침 7, 줄임) · `test_probe_sweep_residue.sh`(고침 6, 지움)
- `plugins/spec-distill/README.md` — 9개 · 고친 횟수 합 250: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_readme_sync.sh`(고침 41, 줄임) · `test_stale_terms.sh`(고침 33, 줄임) · `test_end_gates.sh`(고침 26, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_brief_review_meta.sh`(고침 25, 보안, 줄임) · `test_parallel_recommend_docs.sh`(고침 21, 구조를 고침) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_no_wall_clock.sh`(고침 7, 줄임)
- `plugins/spec-distill/skills/pm-interview/SKILL.md` — 9개 · 고친 횟수 합 121: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_brief_review_entry.sh`(고침 23, 문서는 grep, 구조를 고침) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_saturation_reference.sh`(고침 14, 문서는 grep, 줄임) · `test_steelman_builder_scope.sh`(고침 13, 문서는 grep, 보안, 줄임) · `test_research_agents_frontmatter.sh`(고침 12, 문서는 grep, 보안, 둠) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침) · `test_interview_raw_source_entry.sh`(고침 3, 문서는 grep, 구조를 고침) · `test_cost_disclosure.sh`(고침 3, 문서는 grep, 보안, 둠)
- `CLAUDE.md` — 8개 · 고친 횟수 합 124: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_governance_no_capability_caps.sh`(고침 21, 줄임) · `test_docreview_profiles.sh`(고침 13, 문서는 grep, 보안, 구조를 고침) · `test_one_pipeline_surface.sh`(고침 12, 문서는 grep, 줄임) · `test_charter_citations.sh`(고침 11, 둠) · `test_walk_docs.py`(고침 8, 줄임) · `test_docreview_agents.sh`(고침 6, 문서는 grep, 보안, 구조를 고침) · `test_cost_disclosure.sh`(고침 3, 문서는 grep, 보안, 둠)
- `plugins/quality-gates/README.md` — 8개 · 고친 횟수 합 62: `test_governance_no_capability_caps.sh`(고침 21, 줄임) · `test_readme_scope_reconcile.sh`(고침 8, 지움) · `test_readme_state_diagram_complete.sh`(고침 7, 지움) · `test_impact_runtime_docs.sh`(고침 6, 지움) · `test_gate_era_prose_absent.sh`(고침 5, 합침) · `test_plain_readme.sh`(고침 5, 줄임) · `test_artifact_metadata.sh`(고침 5, 지움) · `test_artifact_critique_truths.sh`(고침 5, 보안, 줄임)
- `plugins/spec-distill/skills/request-framing/SKILL.md` — 8개 · 고친 횟수 합 89: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_request_framing_entry.sh`(고침 16, 문서는 grep, 보안, 줄임) · `test_docreview_round_gate_split.sh`(고침 8, 문서는 grep, 줄임) · `test_docreview_advice_procedure.sh`(고침 6, 문서는 grep, 구조를 고침) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침) · `test_interview_raw_source_entry.sh`(고침 3, 문서는 grep, 구조를 고침) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — 8개 · 고친 횟수 합 134: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_brief_review_entry.sh`(고침 23, 문서는 grep, 구조를 고침) · `test_docreview_procedure_paths.sh`(고침 15, 문서는 grep, 줄임) · `test_docreview_round_gate_split.sh`(고침 8, 문서는 grep, 줄임) · `test_docreview_advice_procedure.sh`(고침 6, 문서는 grep, 구조를 고침) · `test_cost_disclosure.sh`(고침 3, 문서는 grep, 보안, 둠) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/skills/spec-review/SKILL.md` — 8개 · 고친 횟수 합 116: `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_reviewing_spec_state_keying.sh`(고침 18, 문서는 grep, 구조를 고침) · `test_docreview_procedure_paths.sh`(고침 15, 문서는 grep, 줄임) · `test_plain_language_block.sh`(고침 10, 문서는 grep, 줄임) · `test_docreview_round_gate_split.sh`(고침 8, 문서는 grep, 줄임) · `test_docreview_advice_procedure.sh`(고침 6, 문서는 grep, 구조를 고침) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/references/docreview-profiles/design-doc.md` — 7개 · 고친 횟수 합 64: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_docreview_profiles.sh`(고침 13, 문서는 grep, 보안, 구조를 고침) · `test_overdesign_rubric.sh`(고침 11, 문서는 grep, 보안, 구조를 고침) · `test_handoff_conversation_reference.sh`(고침 4, 합침) · `test_handoff_context_empty_subsections.sh`(고침 4, 문서는 grep, 합침) · `test_handoff_context_section_required.sh`(고침 3, 문서는 grep, 합침) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/references/proceed-gate.md` — 6개 · 고친 횟수 합 140: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_end_gates.sh`(고침 26, 줄임) · `test_parallel_recommend_docs.sh`(고침 21, 구조를 고침) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_plain_gate_templates.sh`(고침 19, 구조를 고침) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/skills/pm-interview/references/seed-input.md` — 6개 · 고친 횟수 합 79: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_request_framing_entry.sh`(고침 16, 문서는 grep, 보안, 줄임) · `test_seed_input_provenance.sh`(고침 7, 줄임) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침) · `test_interview_raw_source_entry.sh`(고침 3, 문서는 grep, 구조를 고침)
- `plugins/spec-distill/references/conducting.md` — 5개 · 고친 횟수 합 137: `test_conducting_reference.sh`(고침 40, 구조를 고침) · `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_conducting_loop.sh`(고침 28, 구조를 고침) · `test_parallel_recommend_docs.sh`(고침 21, 구조를 고침) · `test_epic_conductor_skill.sh`(고침 18, 보안, 줄임)
- `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` — 4개 · 고친 횟수 합 116: `harness/test_skill_orchestration_behavior.sh`(고침 69, 문서는 grep, 보안, 줄임) · `test_topic_scope_wiring.sh`(고침 23, 문서는 grep, 줄임) · `test_one_pipeline_surface.sh`(고침 12, 문서는 grep, 줄임) · `test_codex_dispatch_invariant.sh`(고침 12, 문서는 grep, 합침)
- `plugins/spec-distill/references/docreview-profiles/brief.md` — 4개 · 고친 횟수 합 100: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_docreview_profiles.sh`(고침 13, 문서는 grep, 보안, 구조를 고침) · `test_overdesign_rubric.sh`(고침 11, 문서는 grep, 보안, 구조를 고침)
- `plugins/spec-distill/references/trivia-escape.md` — 4개 · 고친 횟수 합 89: `test_end_gates.sh`(고침 26, 줄임) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_request_framing_entry.sh`(고침 16, 문서는 grep, 보안, 줄임)
- `plugins/quality-gates/.claude-plugin/plugin.json` — 3개 · 고친 횟수 합 16: `test_impact_runtime_docs.sh`(고침 6, 지움) · `test_gate_era_prose_absent.sh`(고침 5, 합침) · `test_artifact_metadata.sh`(고침 5, 지움)
- `plugins/spec-distill/references/docreview-profiles/seed.md` — 3개 · 고친 횟수 합 45: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_docreview_profiles.sh`(고침 13, 문서는 grep, 보안, 구조를 고침) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침)
- `plugins/spec-distill/references/redecompose.md` — 3개 · 고친 횟수 합 65: `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_decompose_surface.sh`(고침 25, 보안, 줄임) · `test_plain_language_block.sh`(고침 10, 문서는 grep, 줄임)
- `plugins/spec-distill/templates/interview-brief-template.md` — 3개 · 고친 횟수 합 59: `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_brief_no_length_cap.sh`(고침 3, 문서는 grep, 합침)
- `plugins/spec-distill/templates/interview-seed-template.md` — 3개 · 고친 횟수 합 48: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_request_framing_entry.sh`(고침 16, 문서는 grep, 보안, 줄임) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침)
- `plugins/plugin-audit/skills/plugin-audit/SKILL.md` — 2개 · 고친 횟수 합 18: `test_skill_orchestration.py`(고침 15, 보안, 줄임) · `test_cost_disclosure.sh`(고침 3, 문서는 grep, 보안, 둠)
- `plugins/project-init/README.md` — 2개 · 고친 횟수 합 26: `test_command_contract.py`(고침 20, 줄임) · `test_plain_init_text.py`(고침 6, 줄임)
- `plugins/project-init/skills/project-init/SKILL.md` — 2개 · 고친 횟수 합 26: `test_command_contract.py`(고침 20, 줄임) · `test_plain_init_text.py`(고침 6, 줄임)
- `plugins/quality-gates/CHANGELOG.md` — 2개 · 고친 횟수 합 11: `test_impact_runtime_docs.sh`(고침 6, 지움) · `test_artifact_metadata.sh`(고침 5, 지움)
- `plugins/quality-gates/agents/code-recritic.md` — 2개 · 고친 횟수 합 74: `harness/test_skill_orchestration_behavior.sh`(고침 69, 문서는 grep, 보안, 줄임) · `test_code_recritic_frontmatter.sh`(고침 5, 문서는 grep, 보안, 둠)
- `plugins/quality-gates/references/recritic-code-profile.md` — 2개 · 고친 횟수 합 75: `harness/test_skill_orchestration_behavior.sh`(고침 69, 문서는 grep, 보안, 줄임) · `test_recritic_code_profile.sh`(고침 6, 문서는 grep, 보안, 둠)
- `plugins/spec-distill/references/compression.md` — 2개 · 고친 횟수 합 42: `test_distortion_devices.sh`(고침 26, 문서는 grep, 보안, 줄임) · `test_request_framing_entry.sh`(고침 16, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/references/epic-handoff.md` — 2개 · 고친 횟수 합 16: `test_epic_handoff.sh`(고침 9, 합침) · `test_entry_guidance.sh`(고침 7, 보안, 줄임)
- `plugins/spec-distill/references/existing-first.md` — 2개 · 고친 횟수 합 37: `test_review_handoff_order.sh`(고침 30, 문서는 grep, 합침) · `test_handoff_design_mode.sh`(고침 7, 구조를 고침)
- `plugins/spec-distill/references/reviewing-document.md` — 2개 · 고친 횟수 합 53: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_ask_material_wiring.sh`(고침 3, 문서는 grep, 보안, 줄임)
- `plugins/spec-distill/skills/pm-interview/references/state-migration.md` — 2개 · 고친 횟수 합 155: `test_conducting_interview_stage.sh`(고침 141, 보안, 줄임) · `test_saturation_reference.sh`(고침 14, 문서는 grep, 줄임)
- `plugins/spec-distill/templates/interview-audit-template.md` — 2개 · 고친 횟수 합 73: `test_reviewing_brief_skill.sh`(고침 50, 문서는 grep, 보안, 줄임) · `test_brief_review_entry.sh`(고침 23, 문서는 grep, 구조를 고침)
- `plugins/spec-distill/templates/interview-seed-audit-template.md` — 2개 · 고친 횟수 합 27: `test_seed_at_path_handoff.sh`(고침 21, 문서는 grep, 보안, 줄임) · `test_framing_raw_source.sh`(고침 6, 문서는 grep, 보안, 구조를 고침)

문서 묶음에 들지 않은(그 문서를 재는 다른 글자 테스트가 없거나 문서를 특정하지 못한) 15개: `plugins/plugin-audit/tests/test_axis3_reachability_question.sh` · `plugins/plugin-audit/tests/test_plain_audit_text.py` · `plugins/plugin-audit/tests/test_skill_codex_gate.py` · `plugins/project-init/tests/test_branch_prefix_templates.py` · `plugins/project-init/tests/test_branch_strategy_rebase_clause.sh` · `plugins/quality-gates/tests/test_cost_consent.sh` · `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` · `plugins/spec-distill/tests/test_hook_output_schema.py` · `plugins/spec-distill/tests/test_qg_review_reference.sh` · `shared/tests/test_ask_recommendation.sh` · `shared/tests/test_docreview_ask.sh` · `shared/tests/test_docreview_gate_plain.sh` · `shared/tests/test_docreview_layer1_wiring.sh` · `shared/tests/test_inline_python_isolated.sh` · `shared/tests/test_window_phrases.sh`.

이 절에서 눈에 띄는 것(행이 적은 것):
- `plugins/spec-distill/skills/pm-interview/references/finishing.md` 를 재는 글자 테스트가 가장 많고, 그중 `test_conducting_interview_stage.sh` 는 혼자 141번 고쳐졌다.
- `plugins/spec-distill/CHANGELOG.md` · `README.md` 를 문구로 재는 테스트가 각각 열 개 남짓이다(test_readme_sync 41 · test_stale_terms 33 · test_end_gates 26 · test_brief_review_meta 25 · test_parallel_recommend_docs 21 …).
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 묶음의 `harness/test_skill_orchestration_behavior.sh` 는 69번 고쳐졌다.
- 보안 갈래(「보안」 표시)는 brief 대로 뒤에서도 지우지 않는 대상이라, 같은 문서 묶음 안에서도 합칠 때 따로 다뤄야 한다.

## 작업 트리를 건드리는 테스트

행이 「추적 파일을 고쳤다 되돌린다 · 레포 안에 만들었다 지운다 · 함께 돌면 부딪칠 수 있다」 고 적은 테스트다.

- `plugins/quality-gates/tests/test_agent_model_mutation.sh` 6.5 — 레포의 실제 agent 파일(`plugins/*/agents/`)을 고쳤다 되돌린다. 행: 커밋 안 된 변경이 있으면 첫 단언이 RED, 고치는 동안 병렬로 도는 다른 테스트가 그 agent 파일을 읽으면 흔들린다. 행의 고치는 길: 임시 폴더의 agent 사본에 스윕을 돌리기(빈 glob 하한 케이스가 이미 그 꼴).
- `plugins/quality-gates/tests/test_codex_gate_observation.sh` 2.9 — 실제 체크아웃의 `detect_codex.sh` 심볼릭 링크를 잠깐 지웠다 되살린다. 행: 같은 시각 다른 테스트가 그 파일을 읽으면 흔들릴 수 있다. 고치는 길: 플러그인 사본에서.
- `shared/tests/test_docreview_codex.sh` 19.4 — 레포 안 `fixtures/docreview/binstub` 을 만들고 지운다. 행: 같은 폴더를 쓰는 동시 실행과 부딪칠 수 있다.
- `plugins/quality-gates/tests/test_detect_codex.sh` 0.2 · `plugins/spec-distill/tests/test_detect_codex.sh` 1.1 · `plugins/plugin-audit/tests/test_detect_codex.py` 0.1 — 각자 추적되는 `scripts/codex-killswitch.conf` 를 덮었다 복원한다. 행: SIGKILL 이면 덮인 채 남고 병렬 실행과 겹칠 수 있다. 세 conf 는 플러그인마다 다른 파일이라(`git ls-files` 로 확인) 셋끼리는 부딪치지 않고, 부딪침은 같은 플러그인의 conf 를 읽는 다른 테스트와의 사이다 — 어느 테스트가 그 conf 를 읽는지는 행이 적지 않았다.
- `plugins/quality-gates/tests/test_cost_consent.sh` 0.1 — 사용자의 실제 `~/.claude/quality-gates/codex-cost-consent.md` 를 옮겼다 되돌린다(작업 트리 밖). 행: SIGKILL 이나 병렬 실행에서 사용자 파일이 사라질 수 있다. 행 판정 「지움」.
- `plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 1.2 — 케이스 하나가 고정 경로 `/tmp/sd_auth_stderr.txt` 에 쓴다(작업 트리 밖). 행: 동시 실행에 약하다.
- 참고(고치지 않음): `plugins/spec-distill/tests/test_entry_guidance.sh` 0.2 는 이 레포의 실제 로드맵 경로를 고정으로 읽어 로드맵을 옮기면 깨진다(쓰지는 않는다).

## 행끼리 어긋나는 곳

### 같은 짝 · 같은 대상을 두 행이 다르게 본 곳
1. `plugins/quality-gates/tests/test_qg_false_clean_floor.sh` 0.8(지움) ↔ `plugins/quality-gates/tests/test_check_review_scope.sh` 2.4(둠) — 지움의 근거는 「남는 스크립트 출력 확인은 check_review_scope 가 이미 지킨다」 인데, check_review_scope 행은 「같은 스크립트를 다룸(겹침 정도 확인 못 함)」. 또 brief 의 「지움」 은 「더 싼 다른 테스트가 이미 모두 지킨다」 인데 상대가 더 비싸다(2.4초 대 0.8초).
2. codex 탐지 사본 셋 — `plugins/plugin-audit/tests/test_detect_codex.py`(합침: 같은 14케이스를 각각 확인) · `plugins/spec-distill/tests/test_detect_codex.sh`(구조를 고침: 합집합 주석이 있는 같은 확인) · `plugins/quality-gates/tests/test_detect_codex.sh`(둠: 「케이스 단위 겹침은 확인 못 함」). 같은 케이스 집합을 세 사람이 세 판정으로 냈다.
3. `plugins/quality-gates/tests/test_codex_backward_compat.sh`(합침: kill switch 동작은 test_detect_codex.sh · test_codex_copies_agree.sh 가 이미 잼) ↔ `plugins/quality-gates/tests/test_detect_codex.sh`(둠: backward_compat 은 「다른 각도로 잰다 — 확인 못 함」).
4. `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh`(합침: 개별 frontmatter 테스트의 model 부재 단언을 걷는다) ↔ `plugins/quality-gates/tests/test_code_recritic_frontmatter.sh`(둠, 같은 묶음 shallow-02). 스윕 행은 code_recritic 의 model 단언을 덜 것으로 보고, code_recritic 행은 그대로 둔다.
5. `plugins/plugin-audit/tests/test_axis3_reachability_question.sh`(지움 · 보안 아니오) ↔ `plugins/plugin-audit/tests/audit-workflow.test.mjs`(둠 · 보안 「예(축 3 질문이 hook kill switch 가 아닌 기능 끄기 변수를 묻는지 확인)」) — 같은 축 3 창의 kill switch 문구를 읽는데 보안 갈래 판단이 갈렸다(같은 묶음 shallow-01). brief 는 보안 갈래의 글자 확인을 지우지 않기로 했으므로, axis3 의 「지움」 은 보안 판단을 먼저 맞춰야 선다.
6. `plugins/spec-distill/tests/test_compression_adopters.sh`(지움) → `plugins/spec-distill/tests/test_distortion_devices.sh`(줄임) — 지움 근거는 「하한 2 도출은 test_distortion_devices.sh · 공용 adopter 락이 이미 읽는다」 인데, distortion_devices 행은 「같은 파일을 글자로 잼」 만 적었고 adopter_derivation.sh 를 쓰는 것으로 행에 나온 테스트(test_proceed_gate_adopters.sh · test_next_session_command.sh)는 compression 을 대지 않는다.
7. `shared/tests/test_docreview_gate_plain.sh`(합침, 「같은 준비를 두 파일이 따로 한다」 내용까지) ↔ `shared/tests/test_docreview_gate_visibility.sh`(구조를 고침, 「내용 대조는 못 함」) — 합침의 근거를 상대 행이 확인하지 않았다.
8. 「지움」 · 「합침」 의 근거가 상대 행에 나타나지 않는 한쪽 짝: `plugins/spec-distill/tests/test_hook_output_schema.py`(지움) → test_state_root.sh · test_ledger_root.sh(둘 다 이 파일을 대지 않음, 근거 행 자신도 「내용은 앞쪽만 확인」) · `plugins/quality-gates/tests/test_skill_codex_skip_prose.sh`(지움) → test_codex_result_banner.sh · test_codex_gate_observation.sh · test_detect_codex.sh(근거 행이 「겹치는 정도는 읽지 않음」) · `plugins/quality-gates/tests/test_isolation.sh`(합침) → test_setup_qg.sh(대지 않음) · `plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh`(합침) → test_codex_runner_no_effort_pin.sh · test_sandbox_enforced.sh(대지 않음) · `plugins/spec-distill/tests/test_review_handoff_order.sh`(합침) → test_end_gates.sh(대지 않음).
9. 합칠 곳 자신이 합침 · 지움 후보인 사슬: `plugins/quality-gates/tests/test_cost_consent.sh`(지움)의 근거 `test_gate_era_prose_absent.sh` 는 「합침」 · `plugins/spec-distill/tests/test_epic_handoff.sh`(합침) → `test_review_handoff_order.sh`(합침) · `plugins/spec-distill/tests/test_hooks.sh`(합침) → `test_no_write_matcher_hooks_repo.sh`(합침) → `plugins/project-init/tests/test_no_write_matcher_hooks.sh`(둠, 거꾸로 대지 않음 — 이 사슬의 근거는 모두 「확인 못 함」).
10. 「합침」 이 남는 쪽에 붙은 행: `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh`(스윕으로 모은다 — 자신이 남는 쪽) · `plugins/quality-gates/tests/test_intent_return.py`(「이 파일 쪽으로 모으고 test_intent_critic.py 의 겹친 케이스를 덜면」). 판정 칸만 읽으면 이 파일을 없앤다는 뜻으로 읽힌다.

### 판정과 근거가 맞지 않아 보이는 행
11. `plugins/quality-gates/tests/test_precheck_retired.sh` — 「합침」 인데 자기 「겹침」 칸이 상대(test_publish_surface_removed.sh)에 대해 「같은 종류이나 대상이 다르다」.
12. `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` — 「합침」 인데 근거 끝이 「확인 전이라 둠이 안전」.
13. `plugins/quality-gates/tests/test_skill_codex_skip_prose.sh` — 「지움」 · 확신 낮음. brief 는 확신이 서지 않으면 「둠」 · 낮음을 고르라 했다. 같은 꼴(합침 · 확신 낮음, 상대 내용을 확인 못 함): `plugins/spec-distill/tests/test_brief_codex_axes.sh` · `plugins/spec-distill/tests/test_hooks.sh` · `shared/tests/test_runner_disposition.sh` · `plugins/quality-gates/tests/test_skill_orchestration.sh`.
14. 「지움」 인데 「지키는 것」 이 글자만이 아닌 행: `plugins/quality-gates/tests/test_qg_false_clean_floor.sh`(「check-review-scope.sh 가 네 레포 상태에서 … 올바르게 내는 것만 실제로 지킨다」) · `plugins/spec-distill/tests/test_compression_adopters.sh`(「도출 하한만 의미가 있다」). 둘 다 지움의 다른 근거(더 싼 테스트가 모두 지킴)를 위 1 · 6 처럼 상대 행이 받쳐 주지 않는다.
15. 「둠」 인데 근거가 줄임 · 합침 쪽인 행: `plugins/spec-distill/tests/test_interview_state_flow.sh`(「문구 grep 일부는 test_state_storage_e2e.sh 와 합칠 후보」) · `plugins/spec-distill/tests/test_research_agents_frontmatter.sh`(「saturation 문장 핀만 나중에 합칠 만하다」) · `shared/tests/test_cost_disclosure.sh`(「사본 복사 양성 대조는 줄일 수 있다」) · `tools/suite/test_suite_timing.py`(「아래 여지만큼 줄일 수 있다」).
16. 보안 갈래의 기준이 같은 근거로 갈린 행(같은 묶음 shallow-03): `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` 는 「아니오 (kill switch · 보안 컨트롤 문장을 담은 줄을 핀하지만 문서 글자이고 집행이 아니다)」, `plugins/quality-gates/tests/test_law2_prose.sh` 는 「예 (리뷰어 격리 규범의 문서 글자 — 집행 자체는 아니다)」. 「보안 갈래 글자 확인은 지우지 않는다」 는 규칙이 이 칸에 걸려 있어 기준을 맞춰야 한다.
17. 보안 갈래 칸의 꼴: 정확히 「예」 126행 · 「아니오」 199행 · 그 밖(「예 — …」 · 「예(…)」 · 「아니오 (…)」) 97행. 칸을 「예」 와 글자로 견주는 소비자는 97행을 놓친다. 한 줄 요약 표(`slim-rows.tsv`)의 보안 칸은 잘려 「예(」 처럼 보이는 행이 있다.

## 숫자

- 겹침 짝: 「겹침」 칸에서 테스트 경로(줄인 이름은 같은 플러그인 쪽으로 풀었다)를 뽑아 짝을 세었다 — 서로 적은 짝 201개(다른 묶음 71 · 같은 묶음 130), 한쪽만 적은 연결 439개. 「겹치지 않음 · 대상이 다르다」 처럼 부정으로 적은 연결은 짝에서 뺐다.
- 겹침 묶음: 59개(G1–G59) — 서로 적은 짝을 이어 붙인 뒤 대상 · 규칙으로 손으로 갈랐고, 양쪽 행이 다른 것을 지킨다고 밝힌 짝은 뺐다(별도 목록 17항목).
- 꼴마다 초의 합(테스트 전체 초의 합 — 겹쳐 셈): P1 임시 git 레포 116개 · 2417.7초 / P2 스크립트 새 프로세스 124개 · 2528.3초 / P5 사본 통째 복사 26개 · 680.5초 / P4 다른 테스트 재실행 9개 · 296.6초 / P3 고정 대기 11개 · 179.3초(행이 어림한 기다림 몫만은 약 70–85초) / P6 셸 둘 8개 · 170.7초. 하나라도 든 테스트 209개 · 3606.0초 / 전체 3795.4초.
- 같은 준비물: 팀 레포 15개 · 843.0초 / StateRepo 계열 7개 · 739.2초 / docreview 원장 도우미 15개 · 671.1초 / roadmap_status 재실행 7개 · 414.8초 / session_fixture 4개 · 350.4초 / mkrepo 6개 · 86.2초 / mkfix 3개 · 63.0초 / check_brief gate 3개 · 79.4초.
- 꼴을 센 방법: 「크기」 와 「시간을 쓰는 곳」 칸을 꼴마다 낱말(예: P1 「임시 git 레포 · bare 원격 · 클론 · 팀 레포 · mkfix」, P2 「python 을 N번 · 단언마다 python · 하위 프로세스로 N회」)로 거른 뒤, P3 · P4 · P5 는 「sleep 은 없다」 같은 부정 · 같은 스크립트 안의 재실행 같은 거짓 걸림을 손으로 뺐다. P1 · P2 는 낱말 거름 그대로이고, P2 에서 「하위 프로세스 없음」 으로 적힌 test_stale_terms.sh 하나만 손으로 뺐다. P2 에는 python 이 아니라 bash 스크립트를 케이스마다 띄우는 행(예: test_runner_adapters.sh · test_publish_comment_sink.sh)도 들어 있다.
- 글자에 묶인 테스트: 84개(A 「글자만 지킴」 25 · B 위험 높음 + 글자 79, 겹침 20), 고친 횟수 합 1218. 일부만 글자 8개는 따로. 둘 이상이 재는 문서 35개.
- 작업 트리를 건드리는 테스트: 8개(작업 트리 안 6 · 밖 2 · 경로를 고정으로 읽기만 1은 참고로 따로).
- 행끼리 어긋나는 곳: 17항목(같은 짝 · 대상을 다르게 본 곳 10 · 판정과 근거가 맞지 않는 행 7).

## 확인하지 못한 것

- 「내용」 · 「확인 못 함」 표시는 낱말로 가른 것이다. 「내용」 으로 분류된 짝도 그 행이 상대 파일을 대조했다는 뜻은 아니다 — 여러 묶음의 「읽지 못한 것」 절이 「겹침 칸은 이름 grep 까지만 봤다」 고 적었다(deep-03 · 04 · 06 · 07, shallow-02 · 03 · 04 · 05 · 07 · 08 · 09 · 10 · 11).
- 겹침 짝은 「겹침」 칸에 적힌 경로만 셌다. 「판정 근거」 에만 적힌 짝(예: test_agent_color.sh → test_agent_frontmatter_keys.sh)은 「한쪽만」 목록 일부에만 들어갔다.
- 같은 이름의 테스트(test_detect_codex.sh · test_gh_repo.sh · test_no_write_matcher_hooks.sh 가 두 플러그인에)는 적은 행과 같은 플러그인 쪽으로 풀었다. 다른 플러그인 쪽을 뜻했을 수 있다.
- 꼴 P1 · P2 의 명단은 낱말 거름이라 「이 테스트는 레포가 꼭 필요하다」 는 행(test_human_judge.py · test_post_tool_use_branch.sh · test_merged_pr_range.py 등)도 들어 있다. 꼴에 든다는 것이 고칠 대상이라는 뜻은 아니다.
- 꼴마다 초의 합은 테스트 전체의 초다. 그 꼴이 실제로 쓰는 몫은 깊게 읽은 행 일부만 어림했고(P3 의 기다림 몫 등), 모두 실행하지 않은 추정이다.
- 「글자에 묶인 테스트」 의 문서 귀속 가운데 「문서는 grep」 · 행이 「SKILL」 처럼 이름만 댄 행은 테스트 파일의 경로 문자열을 grep 한 결과라, 그 문서를 실제로 문구 대조하는지는 열어 보지 않았다.
- shallow-06 의 test_conducting_interview_stage.sh(461–1699줄 일부만) · test_control_plane.py · test_first_cell_check.py 는 처음 읽은 사람이 끝까지 읽지 못했다고 적었다(그 묶음의 「읽지 못한 것」). deep-11 · deep-12 는 공유 cases.sh(4773줄)의 일부 도우미만 읽었다.
- 행 판정이 맞는지 테스트 파일로 다시 확인하지 않았다(그것은 표본 재확인 리뷰 몫). 테스트 파일은 문서 귀속 grep 과 conf 파일이 플러그인마다 따로인지(`git ls-files`)만 열었다.
