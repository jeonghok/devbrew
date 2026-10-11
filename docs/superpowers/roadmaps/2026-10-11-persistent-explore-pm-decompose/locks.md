# 락 지도 · 충돌표 — R0

조각이 바꿀 동작을 잠근 테스트와, 진행 중 브랜치와 조각 경로 예약의 겹침이다. 찾은 수는 하한이다 — 조각마다 착수할 때 `locks_grep.sh` 와 같은 검색을 다시 한다. 처리의 기본은 「그 조각이 같은 PR 에서 고친다」.

## 락 지도

| 테스트 파일:줄 | 잠근 동작 | 바꿀 조각 | 처리 |
|---|---|---|---|
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:577 | 조사 장치 예산 식 `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)` 문구 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:290 | 상태 스키마의 `orchestration` 필드 목록(`blind_spot_dispatches` · `coverage_mapper_dispatches` 초기값 0) | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_check_brief.sh:1479 | 구조 게이트: 조사 장치 호출 수 0 이고 불가 사유가 없으면 거절 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_check_brief.sh:1485 | 구조 게이트: 호출 수 0 이라도 불가 사유가 있으면 조언으로 통과 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:716 | 리듬 강제: 열린 결정을 담은 답이면 `non_user_streak` +0, 아니면 +1 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:451 | 되묻기 상한 문장 「같은 주제의 연속 되묻기는 최대 2회」 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_stale_terms.sh:362 | 위와 같은 상한 문장을 라운드 규약에서 양성으로 다시 확인 | R1 | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/test_dispatch_disposition.sh:181 | 호출 자리마다 처분 줄 형식 `**처분** — consumer=… · fail-(open\|closed)` 을 요구 | R1 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:149 | 확정 목록 다시 보이기 횟수를 상태의 `confirm_repost_count` 로 센다 | R2 | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/test_docreview_round_gate_split.sh:95 | 선택지 라벨을 「replacement 를 1–5 낱말로 압축」해 조립한다는 문장 | R2 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_compression_adopters.sh:67 | 압축 규약 정본 `references/compression.md` 를 채택한 표면의 대칭 | R2 | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_rereview_cap_consistency.sh:87 | 일치 락(값 락 아님): 정본 `rereview_cap: N` 과 엔진 상수 `REREVIEW_CAP` 이 N 이 무엇이든 같아야 한다 | R2a | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_reviewing_brief_skill.sh:79 | 재리뷰 상한 값: 절차가 「재리뷰 상한 2」 와 「라운드 4」 를 문구로 댄다 | R2a | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/cases_advice.sh:394 | 재리뷰 상한 값: 게이트 렌더가 「재리뷰 0/2회 썼다」 줄을 낸다 | R2a | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/golden/case_T05_T06_reject.gate.txt:2 | 재리뷰 상한 값: 골든 게이트 문구 「재리뷰 0/2회 썼다」 | R2a | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/golden/case_T11_permit_keeps_disposition.gate.txt:2 | 재리뷰 상한 값: 골든 게이트 문구 「재리뷰 1/2회 썼다」 | R2a | 그 조각이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/cases_advice.sh:333 | 조언 출력 상한: 11건이면 8줄 + 「외 3건」 한 줄, 기본 상한 8 | R2a | 그 조각이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_v_requirements.sh:157 | 반복 상한 질문이 「최대 5번」을 말한다 | R2a | 그 조각이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_artifact_bounds.sh:11 | 산출물 비평 라운드 기본값 5(범위 0~10, 잘못된 값은 5) | R2a | 그 조각이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_review_handoff_order.sh:78 | 다음 세션 줄이 「보다 이 순서가 우선한다」로 기존 다음 단계 지시를 덮어쓴다 | R3 | 그 조각이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_qg_gc.py:116 | 세션 폴더 수명 24시간 기본값: 잘못된 값이면 25시간 묵은 폴더가 24시간 기준으로 지워진다 | R7 | 그 조각이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_qg_gc.py:172 | 수명이 지난 세션 폴더를 지우는 동작 | R7 | 그 조각이 같은 PR 에서 고친다 |
| 찾지 못함 | 보존 목록 문구를 잠근 줄이 없다(두 테스트 파일에서 0건) | R3 | 착수 때 다시 찾는다 |
| 찾지 못함 | 「문제 재구성」 낱말은 픽스처 감사 줄의 이름 일치뿐이고 동작을 잠근 줄이 없다 | R1 | 착수 때 다시 찾는다 |

## 충돌표

측정: 2026-10-11 `git fetch` 직후, `origin/main` d3f03969.

| 진행 중 브랜치 | 겹치는 예약 경로 | 조각 | 처리 |
|---|---|---|---|
| `fix/plain-language-qg-findings` | plugins/quality-gates/scripts/synthesize_findings.py · plugins/quality-gates/skills/critiquing-artifacts/SKILL.md · plugins/quality-gates/skills/quality-pipeline/SKILL.md · plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh · plugins/quality-gates/tests/test_plain_field_path.sh · plugins/quality-gates/tests/test_plain_synth_output.sh · shared/docreview/references/reviewing-document.md · shared/docreview/scripts/docreview_state.py | R2a | R2a 착수 전에 그 브랜치의 머지 또는 폐기를 확인한다(지휘 절차 2). 로드맵 블록으로 둘지는 AC4 승인 때 사용자가 정한다 |
| `qg-review/python-floor-uv` | plugins/project-init/hooks/hooks.json · plugins/project-init/scripts/devbrew-python.sh · plugins/quality-gates/hooks/hooks.json · plugins/quality-gates/hooks/session-start-advisor.py · plugins/quality-gates/scripts/devbrew-python.sh | R2a | 위와 같다 |

`feature/subagent-adjudication-contract` · `fix/hook-write-path-bypass` · `fix/retire-suppression-sweep-handoff` 도 머지 표시는 안 됐지만 origin/main 과 비교한 변경 파일이 0개라 겹침이 없다.

로드맵 블록끼리의 겹침은 `roadmap_status.py` 의 「경로 예약 겹침」이 잰다 — 지금 0개(R3 → R2 의존으로 풀었다).
