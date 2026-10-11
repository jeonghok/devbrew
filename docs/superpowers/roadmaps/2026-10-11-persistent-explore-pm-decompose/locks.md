# 락 지도 · 충돌표 — R0

에픽이 바꿀 동작을 잠근 테스트와, 진행 중 브랜치와 에픽 경로 예약의 겹침이다. 찾은 수는 하한이다 — 에픽마다 착수할 때 brief §5 의 RC 근거 줄과 장치 이름(예: 상한 숫자 · 공식 · 고정 문구)으로 `git grep` 한다. 검색어 예: R1 `coverage_mapper_dispatches|blind_spot_dispatches` · `RHYTHM_GUARD|non_user_streak` · `되묻기` · `confirm_repost_count` · `문제 재구성`, R2 `1–5 낱말` · `compression.md`, R2a `재리뷰 상한|rereview` · `--cap|접기` · `최대 5번`, R3 `우선한다` · 보존 목록 문구, R7 `TTL|24 ?시간`. 처리의 기본은 「그 에픽이 같은 PR 에서 고친다」.

## 락 지도

| 테스트 파일:줄 | 잠근 동작 | 바꿀 에픽 | 처리 |
|---|---|---|---|
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:577 | 조사 장치 예산 식 `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)` 문구 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:290 | 상태 스키마의 `orchestration` 필드 목록(`blind_spot_dispatches` · `coverage_mapper_dispatches` 초기값 0) | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_check_brief.sh:1479 | 구조 게이트: 조사 장치 호출 수 0 이고 불가 사유가 없으면 거절 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_check_brief.sh:1485 | 구조 게이트: 호출 수 0 이라도 불가 사유가 있으면 조언으로 통과 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:716 | 리듬 강제: 열린 결정을 담은 답이면 `non_user_streak` +0, 아니면 +1 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:451 | 되묻기 상한 문장 「같은 주제의 연속 되묻기는 최대 2회」 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_stale_terms.sh:362 | 위와 같은 상한 문장을 라운드 규약에서 양성으로 다시 확인 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| shared/tests/test_dispatch_disposition.sh:181 | 호출 자리마다 처분 줄 형식 `**처분** — consumer=… · fail-(open\|closed)` 을 요구 | R1 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_conducting_interview_stage.sh:149 | 확정 목록 다시 보이기 횟수를 상태의 `confirm_repost_count` 로 센다 | R1 | 그 에픽이 같은 PR 에서 고친다 — 이 테스트 파일과 spec-interview SKILL.md 는 R1 이 예약했다. finishing.md(R3)도 같은 규칙을 말하므로 R1 · R3 중 먼저 바꾸는 쪽이 이 락을 함께 고친다 |
| shared/tests/test_docreview_round_gate_split.sh:95 | 선택지 라벨을 「replacement 를 1–5 낱말로 압축」해 조립한다는 문장 | R2 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_compression_adopters.sh:89 | 압축 규약 정본 `references/compression.md` 를 채택한 표면의 대칭 | R2 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_rereview_cap_consistency.sh:96 | 일치 락(값 락 아님): 정본 `rereview_cap: N` 과 엔진 상수 `REREVIEW_CAP` 이 N 이 무엇이든 같아야 한다 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_reviewing_brief_skill.sh:79 | 재리뷰 상한 값: 절차가 「재리뷰 상한 2」 와 「라운드 4」 를 문구로 댄다 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/cases_advice.sh:394 | 재리뷰 상한 값: 게이트 렌더가 「재리뷰 0/2회 썼다」 줄을 낸다 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/golden/case_T05_T06_reject.gate.txt:2 | 재리뷰 상한 값: 골든 게이트 문구 「재리뷰 0/2회 썼다」 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/golden/case_T11_permit_keeps_disposition.gate.txt:2 | 재리뷰 상한 값: 골든 게이트 문구 「재리뷰 1/2회 썼다」 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| shared/tests/fixtures/docreview/cases_advice.sh:341 | 조언 출력 상한: `--cap` 없이 렌더해도 11건이면 8줄 + 「외 3건」 한 줄(기본 상한 8) | R2a | 그 에픽이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_v_requirements.sh:157 | 반복 상한 질문이 「최대 5번」을 말한다 | R2a | 그 에픽이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_artifact_bounds.sh:11 | 산출물 비평 라운드 기본값 5(범위 0~10, 잘못된 값은 5) | R2a | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_review_handoff_order.sh:78 | 다음 세션 줄이 「보다 이 순서가 우선한다」로 기존 다음 단계 지시를 덮어쓴다 | R3 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_gc.py:61 | spec-distill 세션 폴더 수명: 25시간 묵은 폴더가 기본 24시간 기준으로 지워진다(`test_2_ttl_reached`) | R7 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_gc.py:87 | 수명 재정의: `DEVBREW_SPEC_DISTILL_TTL_HOURS` 1 이면 2시간 묵은 폴더가 지워진다(`test_6_ttl_override`) | R7 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/spec-distill/tests/test_session_end_cleanup.py:123 | 세션 종료 훅이 수명 지난 다른 세션 폴더를 지우고 살아 있는 폴더는 남긴다 | R7 | 그 에픽이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_qg_gc.py:116 | qg 쪽 세션 폴더 수명 기본값: 잘못된 값이면 묵은 폴더가 기본 기준으로 지워진다(`plugins/quality-gates/` 는 R2a 예약) | R2a | 그 에픽이 같은 PR 에서 고친다 |
| plugins/quality-gates/tests/test_qg_gc.py:172 | qg 쪽 수명이 지난 세션 폴더를 지우는 동작(`plugins/quality-gates/` 는 R2a 예약) | R2a | 그 에픽이 같은 PR 에서 고친다 |
| 찾지 못함 | 보존 목록 문구를 잠근 줄이 없다(두 테스트 파일에서 0건) | R3 | 착수 때 다시 찾는다 |
| 찾지 못함 | 「문제 재구성」 낱말은 픽스처 감사 줄의 이름 일치뿐이고 동작을 잠근 줄이 없다 | R1 | 착수 때 다시 찾는다 |

## 충돌표

측정: 2026-10-11 `git fetch` 직후, `origin/main` d3f03969.

| 진행 중 브랜치 | 겹치는 예약 경로 | 에픽 | 처리 |
|---|---|---|---|
| `fix/plain-language-qg-findings` | plugins/quality-gates/scripts/synthesize_findings.py · plugins/quality-gates/skills/critiquing-artifacts/SKILL.md · plugins/quality-gates/skills/quality-pipeline/SKILL.md · plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh · plugins/quality-gates/tests/test_plain_field_path.sh · plugins/quality-gates/tests/test_plain_synth_output.sh · shared/docreview/references/reviewing-document.md · shared/docreview/scripts/docreview_state.py | R2a | R2a 착수 전에 그 브랜치의 머지 또는 폐기를 확인한다(지휘 절차 2). 로드맵 블록은 두지 않고 이 충돌표에만 둔다(AC4 승인 때 사용자 결정 — R0 설계 B11) |
| `qg-review/python-floor-uv` | plugins/project-init/hooks/hooks.json · plugins/project-init/scripts/devbrew-python.sh · plugins/quality-gates/hooks/hooks.json · plugins/quality-gates/hooks/session-start-advisor.py · plugins/quality-gates/scripts/devbrew-python.sh | R2a | 위와 같다 |

`feature/subagent-adjudication-contract` · `fix/hook-write-path-bypass` · `fix/retire-suppression-sweep-handoff` 도 머지 표시는 안 됐지만 origin/main 과 비교한 변경 파일이 0개라 겹침이 없다.

로드맵 블록끼리의 겹침은 `roadmap_status.py` 의 「경로 예약 겹침(정보)」이 잰다 — 지금 1개(R2 ↔ R3 의 `plugins/spec-distill/references/docreview-profiles/design-doc.md`). 겹침은 경고가 아니라 정보다 — 두 에픽은 병렬로 가고, 충돌은 나중에 머지하는 PR 이 main 을 merge 하고 스위트를 다시 돌려 푼다(R0 설계 B13).
