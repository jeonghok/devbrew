---
type: roadmap
source_brief: docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md
review_model: opus
test_command: bash tools/suite/run-all.sh
test_failure_pattern: "^FAILED (.+)$"
---

# 집요한 탐색 · PM 분해 · 에픽별 지휘 · 의도 왜곡 장치 제거 — 로드맵

승인된 분해안(S47)의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다(D39). 상태 칸은 없다 — 단계는 `plugins/spec-distill/scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 이고 에픽 하나는 `브랜치:` 에 브랜치를 여럿 적어 PR 여럿을 낼 수 있고, 상태 계산은 브랜치마다 · 계획마다 센다.

## 에픽

### P1 — 다음 세션 @ 명령 브랜치 머지
- 의도: 인터뷰 종료가 다음 세션 @ 명령으로 넘기게 하는 브랜치를 먼저 머지한다
- 범위:
  - 한다: 그 브랜치의 계획 실행 · 머지
  - 안 한다: 이번 로드맵의 에픽 작업
- 의존: 없음
- 브랜치: feature/next-session-at-handoff
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md
- 발화: S37
- 항목: D38 · OQ19 · RC17 · RC71

### P2 — qg v10 ⑤ 차등 테스트 머지
- 의도: qg 를 건드리는 에픽 앞에 qg v10 ⑤ 차등 테스트를 머지한다
- 범위:
  - 한다: 그 브랜치 머지
  - 안 한다: 이번 로드맵의 qg 변경
- 의존: 없음
- 브랜치: feature/qg-v10-differential
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md
- 발화: S47 · S51
- 항목: RC73 · RC77

### P3 — qg 진입 이름 결정
- 의도: qg 를 건드리는 에픽 앞에 qg 진입 이름을 정한다
- 범위:
  - 한다: 진입 이름 결정 기록
  - 안 한다: qg 코드 변경
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47 · S51
- 항목: RC85

### P4 — 옛 훅 쓰기 경로 브랜치 고아 확인
- 의도: 옛 훅 쓰기 경로 계획이 지금 없는 파일을 전제하는지 확인하고 처분을 정한다
- 범위:
  - 한다: 고아 여부 확인 · 처분 결정 기록
  - 안 한다: 그 계획의 구현
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47
- 항목: RC81

### R0 — 로드맵 · 에픽 묶음 · 상태 계산의 걷는 뼈대
- 의도: 에픽을 한 곳에서 보고 에픽마다 받은 번호를 흘리지 않게 하는 가장 얇은 끝에서 끝까지를 만든다
- 범위:
  - 한다: 손으로 만든 로드맵 · 묶음 · 공통 형식 다섯 · 상태 계산 · 번호 대조 · 실측 M1~M3 · 락 지도 · 충돌표
  - 안 한다: 묶음 자동 생성 · 깊이 검사 · 컨트롤 플레인 · 지휘자 skill
- 의존: P1
- 브랜치: feature/interview-explore-decompose
- 묶음: 없음
- 경로 예약: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/tests/test_roadmap_status.sh, plugins/spec-distill/tests/test_bundle_coverage.sh
- spec: docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
- 발화: S9 · S11 · S12 · S13 · S14 · S16 · S17 · S18 · S25 · S26 · S27 · S31 · S37 · S39 · S40 · S41 · S47 · S48 · S51
- 항목: C8 · C19 · D22 · D24 · D28 · D29 · D33 · C27 · D20 · D21 · D38 · C25 · D26 · D39 · D40 · D41 · D42 · D45 · D47 · OQ30 · OQ33 · C30 · OQ34 · OQ37 · OQ38 · RC18 · RC35 · RC36 · RC38 · RC72 · RC74 · RC75 · RC76 · RC78 · RC80 · K5 · K8 · K9 · K10 · K14 · K15

### R1 — 인터뷰 탐색 개편
- 의도: 인터뷰가 한 번에 닫지 않고 결정에 닿는 새 사실이 없을 때까지 조사하게 한다
- 범위:
  - 한다: 조사 장치 예산 · 자격 · 리듬 강제 · subagent 자리 제한의 제거 또는 수정 · 독립 판정자의 포화 판정 · 조사 상한 20회 · 문제 재구성 단계 제거
  - 안 한다: 압축 · 리뷰 장치(R2 · R2a) · 번호 인계(R3) · 분해(R4)
- 의존: R0
- 브랜치: feature/interview-persistent-explore
- 묶음: R1.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/SKILL.md, plugins/spec-distill/skills/spec-interview/references/steelman.md, plugins/spec-distill/agents/coverage-mapper.md, plugins/spec-distill/agents/blind-spot-prober.md, plugins/spec-distill/agents/steelman-builder.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/tests/test_conducting_interview_stage.sh

### R2 — spec-distill 안쪽 압축 · 리뷰 장치
- 의도: spec-distill 안에서 비용 · 압축으로 품질을 깎거나 사용자 결정을 덮는 장치를 제거하거나 공시 · 사용자가 여는 형태로 고친다
- 범위:
  - 한다: 압축 규약 · request-framing 압축 · seed · brief · 설계문서 리뷰 프로필의 절감 장치 · brief 템플릿 형식 제약
  - 안 한다: 인터뷰 조사 장치(R1) · 공유 리뷰 엔진과 qg(R2a)
- 의존: R0, P1
- 브랜치: feature/distill-distortion-devices
- 묶음: R2.md
- 경로 예약: plugins/spec-distill/references/compression.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/references/docreview-profiles/seed.md, plugins/spec-distill/references/docreview-profiles/brief.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/templates/interview-brief-template.md

### R7 — 상태 저장 재설계 흡수
- 의도: 미구현 상태 저장 재설계 결정 D1~D4 를 이 로드맵 위에서 구현한다
- 범위:
  - 한다: 인터뷰 상태는 docs · 임시 폴더는 리뷰 상태만 · 이어 하기는 로드맵 기반 · 긴 · 병렬 실행 중 리뷰 원장 소실 방지
  - 안 한다: 리뷰 엔진 동작 변경(R2a)
- 의존: R0
- 브랜치: feature/state-storage-redesign
- 묶음: R7.md
- 경로 예약: plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/hooks/session-end-cleanup.py, plugins/spec-distill/scripts/spec-distill-gc.py

### R3 — 번호 인계 · 대조 · 깊이
- 의도: brief 의 모든 번호가 spec · 계획 · 구현까지 가고 빠지거나 얕거나 미뤄지면 경고되게 한다
- 범위:
  - 한다: 넘김 글의 덮어쓰기 문장 제거 · /compact 보존에 조사 · 위험 · spec 리뷰에 묶음을 정해진 입력으로 넘기기 · 번호마다 깊이 검사 · 설계문서 항목의 계획 · 구현 대조(미룬 항목은 받는 곳이 생길 때까지 경고)
  - 안 한다: 묶음 생성(R4) · 표시(R6)
- 의존: R0, P1
- 브랜치: feature/numbered-handoff-coverage
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/references/finishing.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/references/docreview-profiles/design-doc.md

### R4 — PM 분해 · 로드맵 · 에픽 묶음 · 재분해 경로
- 의도: 인터뷰가 일을 에픽으로 나눠 로드맵과 묶음을 내고 하류의 재분해 · 축소 신호를 같은 지도로 되돌리게 한다
- 범위:
  - 한다: 분해 판단 · 로드맵 · 묶음 자동 생성(R0 형식) · 재분해 경로
  - 안 한다: 지휘(R5) · 표시(R6)
- 의존: R0
- 브랜치: feature/interview-pm-decompose
- 묶음: R4.md
- 경로 예약: plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/references/redecompose.md, plugins/spec-distill/templates/roadmap-template.md

### R6 — 컨트롤 플레인
- 의도: 에픽 지도 · 단계 · 빠진 것 · 드리프트 알림을 Claude Code 안에서 보이게 한다
- 범위:
  - 한다: 상태줄 · 패널 · 작업 목록 표시(M2 · M3 결과에 맞춤)
  - 안 한다: 상태 계산 자체(R0 · R5)
- 의존: R0
- 브랜치: feature/roadmap-control-plane
- 묶음: R6.md
- 경로 예약: 없음

### R2a — 공유 리뷰 엔진 · qg 파급 · persona 보안 리뷰
- 의도: 공유 리뷰 엔진과 qg · 다른 플러그인의 의도 왜곡 장치를 제거하거나 고치고 persona 편집은 보안 리뷰를 거친다
- 범위:
  - 한다: 공유 리뷰 엔진 상한 · 조언 접기 · qg 리뷰어 · 루프 상한 · R2 가 넘긴 보안 잔여의 검사 방식 전환(꼴 막기 대신 허용 문법 · 실제 파서) · 흐름 고정 점검(flexibility-audit.md)의 R2a 행(결함 셋 먼저) · 다른 플러그인의 장치 · qg 진입 이름 적용(P3 결정 — `commands/qg.md` 삭제 · `artifact-critique` 개명 · 호출 표면 락의 qg 위반 해소) · qg 범위 입력(로드맵 시작 커밋부터 지금 기본 브랜치까지) · 「문서 경로」 정의(모델이 읽는 .md 포함) · 범위 안 여러 설계문서를 모두 의도로 읽기(지금 discover-spec.sh 는 가장 새 커밋의 Spec: 하나에서 멈춘다) · qg 의 테스트 실행 스크립트 셋(run-test-selection.sh · diff-test-results.py · compute-test-scope-candidates.sh)을 shared/test-selection/ 으로 바이트 그대로 옮기고 qg 쪽을 링크로
  - 안 한다: spec-distill 안쪽 장치(R2)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/shared-review-engine-devices · feature/shared-review-engine-core · feature/shared-review-engine-qg · feature/shared-review-engine-plugins
- 묶음: R2a.md
- 경로 예약: shared/docreview/, plugins/spec-distill/references/reviewing-document.md, plugins/quality-gates/, plugins/project-init/, plugins/plugin-audit/, shared/test-selection/, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/scripts/check_verbatim_coverage.py, plugins/spec-distill/scripts/seed_body.py, plugins/spec-distill/scripts/check_seed.py, plugins/spec-distill/scripts/seed_review_log.py, plugins/spec-distill/scripts/seed_provenance.py, plugins/spec-distill/scripts/brief_body.py, plugins/spec-distill/tests/test_check_brief.sh, plugins/spec-distill/tests/test_check_brief_frontmatter.py, plugins/spec-distill/tests/test_brief_verbatim_full.sh, plugins/spec-distill/tests/test_check_verbatim_coverage.sh, plugins/spec-distill/tests/test_check_seed.sh, plugins/spec-distill/tests/test_seed_review_log.sh, plugins/spec-distill/tests/test_seed_provenance.sh

### R5 — 지휘자
- 의도: 한 세션이 로드맵을 따라 에픽을 끝까지 지휘하되 사용자의 결정권과 내용 검토가 남게 한다
- 범위:
  - 한다: 사람 몫은 지금 답할 수 있는지 판단해 배경 설명과 함께 몰아 받고 나머지는 멈추지 않고 병렬로 끝까지 · 외부 정지는 사용자에게(미리 받은 답이 있으면 그 답으로) · 머지 전 에픽 사이 통합 리뷰 · 모든 에픽 머지 뒤 끝에서 끝 확인 · 하위(에픽 worktree · 브랜치)는 단일 세션과 같은 skill 호출 · 같은 동작(spec 리뷰까지는 지휘 세션이 직접 · 하위가 돌려보낸 사람 자리는 쉬운 요약 + 원문(선택지 · 답은 그대로)) · 병렬은 불가피할 때만 멈추고 다시 이음 · R2 가 R3 에 넘긴 번호 대조 둘(설계 없는 묶음의 「셀 수 없음」 경고 · 기각 번호를 승인 게이트에 보이고 「반영」으로 되돌리기) · 사용자 몫 감사(혼자 정한 사용자 몫 · 줄어든 넘김을 찾아 배경과 함께 하나씩 묻기) · 미룸 · 넘김 조율(담당 에픽을 정해 넘기고 뒤에서 처리됐는지 확인) · 살아 있는 subagent 를 보이고 놀고 있는 것은 내림 · /compact 시점은 지휘자가 판단 · 구현 뒤 다시 불러도 같은 동작(설계 입력: 로드맵 roadmap.md `## 재분해 이력` 의 R5 줄 사용자 원문 전부 — 설계문서 `## 번호 대조` 에 원문마다 반영/기각 행) · 흐름 고정 점검(flexibility-audit.md)의 R5 행 · 실행 기록 회수 · 재개 · 부분 계속 · 머지 원칙 · qg 의도 회귀 · 에픽 사이 이음매 · base 이동 · 구현 이후 단계 · 쓴 자원 정리(브랜치 제외) · 계층 · 온톨로지 · 레포 전용 값 금지
  - 안 한다: 상태줄 · 패널(R6) · 리뷰 엔진 동작 변경(R2a)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/epic-conductor · feature/epic-conductor-seams · feature/epic-conductor-loop · fix/conductor-superpowers7 · fix/conductor-parallel-truth
- 묶음: R5.md
- 경로 예약: plugins/spec-distill/skills/epic-conductor/, plugins/spec-distill/skills/roadmap-status/SKILL.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/skills/spec-interview/references/finishing.md, plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/references/roadmap-ontology.md, plugins/spec-distill/references/epic-handoff.md, plugins/spec-distill/references/redecompose.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/conductor_state.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/merge_check.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/scripts/spec_review_bundle.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/templates/roadmap-template.md
- 순서 이유: 계획 셋을 차례로(형식 · 상태 → 이음매 → 지휘자) — 셋째는 R2a 가 qg 테스트 스크립트를 shared/ 로 옮긴 뒤(설계 D1.3 · §11)

### R8 — 의존 선언 · 부재 시 강등 · devbrew 밖 경로
- 의도: 이 장치들이 devbrew 밖 레포와 superpowers 부재에서도 통하게 한다
- 범위:
  - 한다: 의존 최소 버전 선언 · 부재 시 강등 · 경로 규약 범용화 · squash · rebase 머지 자동 판정 · 다른 파일에 박힌 레포 전용 값(예: 인터뷰 끝의 로드맵 폴더 위치 검사) · gh · superpowers 부재 강등 · AC17 (가) 엔진 밖 원장 쓰기의 권한 경계 · 스냅숏 칸 신뢰 · `--quote-file` · `log-decision --quote` 출처 · 제목 하나 빠진 audit(R2a 설계 미룸 · 사용자 결정 B16)
  - 안 한다: 규칙 문서(R9)
- 의존: R2a, R5
- 브랜치: feature/dependency-portability
- 묶음: R8.md
- 경로 예약: 없음

### R9 — 규칙 · 문서 정리
- 의도: 바뀐 장치에 맞춰 레포 규칙 · 철학의 조항 문면을 고친다
- 범위:
  - 한다: 지출 승인 조항(지휘자 시작 승인을 「규모 공시만」으로) · P22 개정 문안(사용자 승인) · 흐름 고정 점검(flexibility-audit.md)의 R9 행(「끝에 할 일 하나」 · Law 1 중간 단계 — 사용자 결정)
  - 안 한다: 장치 동작 변경 · 원칙 문서 정리 · 낡은 개념 삭제(R11)
- 의존: R8, R11
- 브랜치: feature/rules-docs-cleanup
- 묶음: R9.md
- 경로 예약: CLAUDE.md, docs/philosophy/devbrew-harness-philosophy.md

### R10 — 인터뷰 조사 열기 · 신선한 근거 · 끝 게이트
- 의도: 인터뷰가 모델 판단으로 조사를 넓게 열어 결정에 닿는 신선하고 믿을 만한 근거를 빠짐없이 채우게 한다 — 기존 방식에 더한다
- 범위:
  - 한다: 조사 subagent 를 모델 판단으로 여럿 동시에 · 시의성 있는 사실의 신선한 근거(사용자 원칙 여덟 — 흐름 고정 점검 문서 R10 절, 설계문서 `## 번호 대조` 에 원칙마다 반영/기각 행) · 흐름 고정 점검(flexibility-audit.md)의 R10 행 · 인터뷰 끝 게이트 둘(분해된 일의 ①② 이름 · 다음 세션 줄의 에픽마다 brainstorming 고정, /compact 권장은 유지) · 분해 판단이 로드맵 `흐름` · `산출물` 칸을 채움 · 인터뷰 조사에 레포 안 재사용 검토 · 나눈 일 다음 세션 줄 문면 조율(그 한 줄 자체는 R5) · 하나짜리 brief 의 다음 세션 줄(finishing.md)이 가정하는 「SDD 의 마지막 전체 리뷰」를 「고른 실행 방식의 마지막 전체 리뷰」로 · 인터뷰 진입 이름 `spec-interview` → `pm-interview`(호출 이름 변경은 레포 규칙대로 별칭 없이 즉시 · major bump)
  - 안 한다: 에픽 넘김 줄 · 지휘(R5) · 공유 리뷰 엔진(R2a)
- 의존: R1, R2, R3, R4, R7
- 브랜치: feature/interview-open-research · feature/interview-end-gates · feature/pm-interview-rename
- 묶음: R10.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md, plugins/spec-distill/agents/saturation-judge.md, plugins/spec-distill/agents/steelman-builder.md, plugins/spec-distill/templates/interview-brief-template.md, plugins/spec-distill/references/trivia-escape.md, plugins/spec-distill/skills/pm-interview/, plugins/spec-distill/agents/open-researcher.md, plugins/spec-distill/references/fresh-evidence.md, plugins/spec-distill/references/research-claims.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/scripts/brief_body.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/scripts/build_brief_bundle.py, plugins/spec-distill/scripts/build_brief_inline_blob.py, plugins/spec-distill/templates/interview-seed-template.md

### R11 — 원칙 문서 정리
- 의도: 사용자의 상시 원칙을 auto-memory 에서 CLAUDE.md · 철학 문서 · 주요 문서로 옮기고 낡은 개념은 과감히 지워 문서 크기를 줄인다
- 범위:
  - 한다: 원칙 옮기기(있는 것 먼저 검토 — 레포 안 · 밖, 외부는 사용자 검토 뒤 · 레포 전용 값 박지 않기 · 상류 · 하류 연계 · 계층 · 온톨로지 · 컨트롤 플레인 진입점 · 흐름 고정 금지(기본값 + 모델 판단, 정석 의도 유지) · 머지 전 확인 규약 · 하위는 단일 세션과 같은 skill 흐름) · 낡은 개념 삭제로 크기 줄이기 · 플러그인 README · CHANGELOG 의 낡은 개념 정리(R9 에서 옮김)
  - 안 한다: 지출 승인 조항 · P22 · 흐름 고정 점검 R9 행(R9) · 장치 동작 변경
- 의존: R0
- 브랜치: feature/principles-docs-cleanup
- 묶음: R11.md
- 경로 예약: CLAUDE.md, docs/philosophy/devbrew-harness-philosophy.md

### R12 — R2a 남은 리뷰 엔진 · qg 소결함
- 의도: R2a 와 R11 이 남긴 공유 리뷰 엔진 · qg · project-init · plugin-audit 의 작은 결함과 보안 제안을 고친다
- 범위:
  - 한다: 엔진 환경 변수(`DEVBREW_DOCREVIEW_*`) 최댓값 · 원문 절 마지막 앵커 밑 이어 붙인 줄 · `</related_changes>` 주입 · `declare-related` 펜스 락 · 리뷰어 둘의 같은 질문 흡수 때 기다리던 수정 목록 소실 · 확인된 결정의 보호가 자식 절에 붙지 않음 · docreview 엔진 결함 셋(finalize 두 번 · 복수 앵커 · § 앵커) · 설계문서 프로필의 대안 비교 축 · 번호 대조 · 미룸 손 편집의 허가 길 · 리뷰가 닫힌 뒤 손으로 쓴 결정 줄 · qg 판정 id 충돌(synthesize_findings.py) · plugin-audit kill switch 정규식(check-shape-completeness.py) · tools/adjudication/check_wiring.py 의 줄 번호 핀 · 철학 P3 「문서 리뷰 자리 넷」 문장 · 공유 락 빈틈(copy-of-contract 소비 도출 오탐 · 같은 이름 블록 첫 블록만 읽기 · 라우터 흡수 분기 스캔 · 같은 임시 번호 · 호출 표면 `_LEAD` · `_OLD_TRAIL` · 살아 있는 표면) · `log-decision` 표지 가드 · project-init 헌장 모서리 셋(그대로 두기 · 옮기기 중복 공시 · Step 5 문구) · qg 판정 상태 위치(판정 전에 도는 레포 코드가 세션 폴더 · 표지 · synth.out 에 닿음 — 설계 결정 · 사용자 결정 「R12 로 (권장)」) · qg e2e 시나리오 수 상한 공시
  - 안 한다: R2a 계획 2~4 의 범위 · R8 의 권한 경계(AC17 가) · R10 미룸의 인터뷰 쪽 소결함(R13)
- 의존: R2a, R11
- 브랜치: feature/review-engine-leftovers
- 묶음: R12.md
- 경로 예약: shared/docreview/, plugins/quality-gates/scripts/synthesize_findings.py, plugins/plugin-audit/scripts/check-shape-completeness.py, tools/adjudication/check_wiring.py, docs/philosophy/devbrew-harness-philosophy.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, shared/tests/test_copy_of_contract.sh, shared/tests/test_docreview_route.sh, shared/tests/fixtures/docreview/, shared/tests/test_adjudication_wiring.sh, shared/entry/check_invocation_surface.py, shared/tests/test_invocation_surface.sh, plugins/spec-distill/tests/test_ledger_wiring.sh, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/skills/request-framing/, plugins/spec-distill/skills/reviewing-brief/, plugins/spec-distill/references/redecompose.md, plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/project-init/, plugins/quality-gates/skills/quality-pipeline/, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/references/e2e.md, plugins/quality-gates/tests/test_synthesize_recritic.sh

### R13 — R10 남은 인터뷰 게이트 · 엔진 skill 소결함
- 의도: R10 이 남긴 인터뷰 게이트 · 엔진 skill 의 작은 결함과 보안 제안을 pm-interview 이름 바꾸기 뒤 고친다
- 범위:
  - 한다: `check_brief` 의 사용자 답과 state `source: chosen` 대조 · 엔진 skill 셋(request-framing · reviewing-brief · spec-review) 번들 쓰기의 링크 따라가기(함께 쓰는 writer) · V1 확인 줄을 실을 자리
  - 안 한다: R10 계획 1~3 의 범위 · R12 의 엔진 · qg 소결함
- 의존: R10, R12
- 브랜치: feature/interview-gate-leftovers
- 묶음: R13.md
- 경로 예약: plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/skills/pm-interview/, plugins/spec-distill/skills/request-framing/, plugins/spec-distill/skills/reviewing-brief/, plugins/spec-distill/skills/spec-review/SKILL.md
- 순서 이유: 인터뷰 skill 은 R10 계획 3 의 pm-interview 이름 바꾸기 뒤 새 이름 자리에서 · 엔진 skill 셋은 R12 의 펜스 락 뒤에

## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 두면 spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다 — 지휘자 없이 진행하려면 끄지 말고 지휘자를 부르지 않은 채 spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.
- 손 절차로 옮긴 옛 지휘 절차의 인용: 「검사 불가」 · 「이게 앞으로의 원칙이야」 · 「경고 N개」 · 「…subagent driven이라고 되어있는걸 권장 구현 방식으로 간다고 해둬」 · 「Rulings I made」 · 「이 PR 이 머지 전 고침」 · 「뒤에 머지되는 에픽이 고침」 · 「리뷰 뒤 반영(리뷰 라운드를 거치지 않았다)」

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 에픽은 「머지」 줄로 적는다.

쉬운 말 PR 3(`feature/plain-language-voice`)은 이미 머지됐다(#198) — 선행 둘째의 그 부분은 블록을 두지 않는다.

- P3 · 결정 · 2026-10-13 · 「quality-pipeline 을 진입으로 (권장)」 · 「따로 진입 artifact-critique」
  - 앞 답은 코드 검사(`/qg`)의 진입이다 — `commands/qg.md` 를 지우고 `quality-pipeline` skill 을 진입으로 세운다(완전명 `/quality-gates:quality-pipeline`). 뒤 답은 문서 비평(`/qg critique`)의 진입이다 — `critiquing-artifacts` 를 따로 진입 skill `artifact-critique` 로 바꾼다(완전명 `/quality-gates:artifact-critique`). 적용은 R2a 가 한다.
- P4 · 결정 · 2026-10-13 · 「끝난 기록으로 둠 (권장)」
  - 옛 훅 쓰기 경로 계획(`docs/superpowers/plans/2026-08-23-hook-write-path-bypass.md`)은 고아가 아니다 — 구현 브랜치가 #134 로 머지됐고 main 밖 커밋은 0이다. 전제 파일이 없는 것은 계획 자신이 지웠거나(쓰기 감시 훅 셋 · qg 사전 검사 · docs-lint) 뒤 개편이 대체했기 때문이다(검사를 넘겨받은 Stop 훅은 e7c6bbb9 가 지웠다). 계획 파일과 브랜치는 기록으로 둔다.

## 재분해 이력

### 2026-10-11 · 처음 로드맵
- 바뀜:
  - 승인 원문 S47 「이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인」
  - 선행 3 을 P1~P4 블록으로 나눴다(R0 설계 §1)
- 원문:
  - 「이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인」

### 2026-10-11 · 승인 뒤 수정(R0 설계 B11~B13)
- 바뀜:
  - R6 묶음에 D24 · D40 을 더했다 「더한다 (권장)」
  - 경로 예약 겹침은 병렬을 막지 않는 정보로 낮추고 겹침 때문에만 있던 R3 → R2 의존을 뺐다 「병렬 유지, 정보로만 (권장)」
  - 단위 이름을 「에픽」으로 정했다 「에픽 (권장)」
- 원문:
  - 「더한다 (권장)」
  - 「병렬 유지, 정보로만 (권장)」
  - 「에픽 (권장)」

### 2026-10-13 · P3 결정 뒤 수정
- 바뀜:
  - qg 진입 이름 적용을 R2a 범위에 더했다 「R2a 범위에 더함 (권장)」
- 원문:
  - 「R2a 범위에 더함 (권장)」

### 2026-10-15 · R7 착수 중 수정
- 바뀜:
  - 사람 몫을 판단해 몰아 받고 나머지는 쭉 병렬로 가는 지휘를 R5 범위에 더했다 「사람이 있을때 사람이 진행해야 하는걸 몰아 하는거지」 · 「그게 되게끔 구현도 해야한단 말이야」 · 「근데 이 몰아서 물어보는거는 억지로 하는게 아니라 되는거까지 하는거야 판단하는 과정이 있어야겠지」 · 「그래 이런 느낌은 맞는데 설명과 배경 이해는 더 기켜줘야 겠어」 · 「너무 질문만 몰아치는 느낌이네」 · 「기존 brainstorming방식을 해치진 말아줘」 · 「R5 지휘자 범위에 더함 (권장)」
  - superpowers 가 묻는 세 자리(계획 검토 · 실행 방식 · 머지 메뉴)는 미리 답해 둔다(S36 재결정) 「미리 답해 둠 (권장)」
- 원문:
  - 「사람이 있을때 사람이 진행해야 하는걸 몰아 하는거지」
  - 「그게 되게끔 구현도 해야한단 말이야」
  - 「근데 이 몰아서 물어보는거는 억지로 하는게 아니라 되는거까지 하는거야 판단하는 과정이 있어야겠지」
  - 「그래 이런 느낌은 맞는데 설명과 배경 이해는 더 기켜줘야 겠어」
  - 「너무 질문만 몰아치는 느낌이네」
  - 「기존 brainstorming방식을 해치진 말아줘」
  - 「R5 지휘자 범위에 더함 (권장)」
  - 「미리 답해 둠 (권장)」

### 2026-10-15 · R3 설계 중 수정
- 바뀜:
  - 번호 인계를 설계문서에서 계획 · 구현까지 넓혔다 「구현을 다 안하는거도 문제이고」 · 「R3 를 넓힘 (권장)」
- 원문:
  - 「구현을 다 안하는거도 문제이고」
  - 「R3 를 넓힘 (권장)」

### 2026-10-15 · 병렬 구현 중 수정
- 바뀜:
  - 머지 전 에픽 사이 통합 리뷰와 모든 에픽 머지 뒤 끝에서 끝 확인을 R5 범위에 더했다 「궁금한거 하나 지휘자가 각각 구현도 다 보고 조율 하는거 맞지?」 · 「더함 + 끝에 끝에서 끝 확인 (권장)」
  - R4 경로 예약에 구현이 만든 새 파일 넷을 적었다(R0 계획: 예약 없던 에픽은 설계가 정하면 작은 로드맵 PR 로 더함)
- 원문:
  - 「궁금한거 하나 지휘자가 각각 구현도 다 보고 조율 하는거 맞지?」
  - 「더함 + 끝에 끝에서 끝 확인 (권장)」

### 2026-10-15 · R6 머지 뒤 수정
- 바뀜:
  - 지휘 절차 1 의 작업 목록 맞추기를 컨트롤 플레인의 작업 목록 줄(`control_plane.py show --tasks`)로 바꿨다 — R6 설계 판정 「새 세션 작업 목록 재충전은 지휘 절차가 맡는다」
  - origin/main 에 아직 없는 로드맵은 `roadmap_status.py --roadmap-file` 로 대신 계산한다(통합 리뷰)
- 원문: 없음 — 사용자 말 없음(R6 설계 판정)

### 2026-10-16 · 병렬 머지 중 수정
- 바뀜:
  - 이번 묶음에서 해 온 머지 전 확인(스위트 대조 · 통합 리뷰 · 리뷰 뒤 반영)과 끝에서 끝 확인을 지휘 절차 8 · 9 로 적었다 — R5 가 장치로 만들 때까지 지휘 세션이 따르는 절차다 「리뷰는 계속 책임지고 하고 이ㅛ는거지? 향후에도 그럴수 있게 구현하고」
- 원문:
  - 「리뷰는 계속 책임지고 하고 이ㅛ는거지? 향후에도 그럴수 있게 구현하고」

### 2026-10-17 · 병렬 머지 중 수정
- 바뀜:
  - R5 범위에 하위의 skill 호출 · 동작 동일과 병렬 재개를 더했다 「중요한게 단계만이 아니라 지휘자 하위 관점에선(각자 할당받은 워크트리와 브랜치 내에서는) 스킬 호출 다 해야하고 실제 동작에서 달라지지 말아야해, 지휘자 눈(관점에선) 병행이 돌아가는겠지만(불가피한게 아닌경우만 병행 멈춤 아니면 다시 병행)」
  - 리뷰 원장이 agent 를 바꾸면 이어지지 않던 실측(R7 · R2 설계 리뷰)도 같은 줄에 넣었다
  - R2a 범위에 R2 보안 잔여의 검사 방식 전환을 더했다 「공시하고 R2a 로 (권장)」
- 원문:
  - 「중요한게 단계만이 아니라 지휘자 하위 관점에선(각자 할당받은 워크트리와 브랜치 내에서는) 스킬 호출 다 해야하고 실제 동작에서 달라지지 말아야해, 지휘자 눈(관점에선) 병행이 돌아가는겠지만(불가피한게 아닌경우만 병행 멈춤 아니면 다시 병행)」
  - 「공시하고 R2a 로 (권장)」

### 2026-10-17 · 감사 뒤 수정
- 바뀜:
  - R2 가 R3 에 넘겼는데 R3 계획에서 줄어든 번호 대조 둘(N17 · N18)을 R5 범위에 더했다 「약속대로 — R5 가 맡음 (권장)」
- 원문:
  - 「약속대로 — R5 가 맡음 (권장)」

### 2026-10-17 · 감사 뒤 수정
- 바뀜:
  - R3 설계가 약속한 지휘 절차 갱신(에픽 넘김 줄 · `--bundle` · `--plan` · `--impl` · 번호 대조 경고는 막지 않고 게이트에서)을 R5 로 미루지 않고 지휘 절차 3 에 적었다 「지금 로드맵 PR 에 (권장)」
- 원문:
  - 「지금 로드맵 PR 에 (권장)」

### 2026-10-17 · 지휘 점검 중 수정
- 바뀜:
  - R5 범위에 사용자 몫 감사 · 미룸 · 넘김 조율 · 구현 뒤 다시 불러도 같은 동작을 더했다
  - 이 줄과 위 「R7 착수 중 수정 — 몰아 받기」 · 「병렬 구현 중 수정 — 통합 리뷰」(2026-10-15) · 「병렬 머지 중 수정 — 지휘 절차 8 · 9」(2026-10-16) · 「병렬 머지 중 수정 — 하위 동작 동일」 · 「감사 뒤 수정」 둘(2026-10-17) 줄의 사용자 원문이 R5 설계 입력이다: 「아님 qg를 활용해도 되고」(2026-10-15, 통합 리뷰에 qg 를 쓰자는 제안 — 답하지 못한 채 남았다) · 「정석으로 구현 할거지?」 · 「멋대로 혼자 brainstorming간거는없지? 혹은 그걸 안했거나」 · 「그리고 우리 이번 로드맵은 나한테 물어볼건 다 물어보고 설계했나?」 · 「좋아 defer되거나 업무들 조율해서 어떻게든 하고 조율하는거 매우 좋은 방향이야」 · 「구현 다 끝난 뒤 다시 호출해도 이렇게 되게해 물론 앞에서 내가 말한것들도 되게해야해」
- 원문:
  - 「아님 qg를 활용해도 되고」
  - 「정석으로 구현 할거지?」
  - 「멋대로 혼자 brainstorming간거는없지? 혹은 그걸 안했거나」
  - 「그리고 우리 이번 로드맵은 나한테 물어볼건 다 물어보고 설계했나?」
  - 「좋아 defer되거나 업무들 조율해서 어떻게든 하고 조율하는거 매우 좋은 방향이야」
  - 「구현 다 끝난 뒤 다시 호출해도 이렇게 되게해 물론 앞에서 내가 말한것들도 되게해야해」

### 2026-10-17 · 압축 감사 뒤 수정
- 바뀜:
  - 대화 압축으로 기록에서 빠졌던 사용자 말을 R5 설계 입력으로 남겼다: 「궁금한거 하나 지휘자가 각각 구현도 다 보고 조율 하는거 맞지? 내가 보기에 병렬 구현되면 지휘자 -> 에픽 담당자 -> 구현자(SDD인 경우) 로 잘 하고 있다고 보이긴 하는데 이렇게 잘 하고 있나」 · 「그리고 서브에이전트들 다 돌고 있는거 맞아? 아님 다 내리고」 · 「다 구현 된거야?」 · 「더 뭐해야해?그거하고 적절한 순간 compact 후 진행」 · 「내가 바로 사라지는건 아니니까」 · 「이해되지?」 · 「1, 좋아 지금 진행하는 방식보니 잘 이해한 느낌이내」(brainstorming 절별 확인 방식에 대한 답) · 「이전 세션에서 내가 말했던거 중에 반영 안된건 없을까? compact되며 날아간거」(원문 1~7 은 2026-10-15, 8 은 2026-10-17)
  - 지휘 절차 4 를 S36 재결정(미리 답해 둠)대로 고쳤다
  - R5 범위에 살아 있는 subagent 정리 · /compact 시점 판단을 더했다
  - 날짜는 한국 시간이다
- 원문:
  - 「궁금한거 하나 지휘자가 각각 구현도 다 보고 조율 하는거 맞지? 내가 보기에 병렬 구현되면 지휘자 -> 에픽 담당자 -> 구현자(SDD인 경우) 로 잘 하고 있다고 보이긴 하는데 이렇게 잘 하고 있나」
  - 「그리고 서브에이전트들 다 돌고 있는거 맞아? 아님 다 내리고」
  - 「다 구현 된거야?」
  - 「더 뭐해야해?그거하고 적절한 순간 compact 후 진행」
  - 「내가 바로 사라지는건 아니니까」
  - 「이해되지?」
  - 「1, 좋아 지금 진행하는 방식보니 잘 이해한 느낌이내」
  - 「이전 세션에서 내가 말했던거 중에 반영 안된건 없을까? compact되며 날아간거」

### 2026-10-17 · 재분해
- 바뀜:
  - 새 에픽 R10(인터뷰 조사 열기 · 신선한 근거 · 끝 게이트)을 더하고 R5 · R2a · R9 범위에 흐름 고정 점검 행을 가리키게 했다
  - 바뀜 R2a · R5 · R9 · 새 R10 「이대로 다시 나눈다」
- 원문:
  - 「이대로 다시 나눈다」

### 2026-10-17 · 흐름 고정 점검 뒤 수정
- 바뀜:
  - 지휘 절차 2 · 3 의 brainstorming 고정을 기본값으로(설계 흐름이 아닌 에픽은 고른 흐름을 시작 전에 승인받음) 바꿨다
  - 지휘 절차 3 의 구현 대조 보고를 고른 실행 방식으로 바꿨다
  - 지휘 절차 4 의 실행 방식을 writing-plans 권장으로 바꿨다
  - 지휘 절차 8 의 통합 리뷰어 「하나」 를 여럿 · 동시로(qg 의 지금 한계를 적고 맞추는 일은 R5) 바꿨다
  - 지휘 절차 9 를 기본 경로와 설계 흐름이 아닌 에픽 경로로 고쳤다
  - 점검 결과는 이 폴더의 flexibility-audit.md 다 「또 고정한걸 풀을곳은 없을까 devbrew에서」 · 「에픽 실행 방식 SDD 고정, 「끝에 할 일 하나」, Law 1 의 중간 단계, qg 리뷰어 모델 opus 고정, 1번의 경우 writing plan이 끝나면 권장 실행 방식이 있을거야 subagent driven이라고 되어있는걸 권장 구현 방식으로 간다고 해둬」 · 「좋아 이게 앞으로의 원칙이야」
- 원문:
  - 「또 고정한걸 풀을곳은 없을까 devbrew에서」
  - 「에픽 실행 방식 SDD 고정, 「끝에 할 일 하나」, Law 1 의 중간 단계, qg 리뷰어 모델 opus 고정, 1번의 경우 writing plan이 끝나면 권장 실행 방식이 있을거야 subagent driven이라고 되어있는걸 권장 구현 방식으로 간다고 해둬」
  - 「좋아 이게 앞으로의 원칙이야」

### 2026-10-17 · 재분해
- 바뀜:
  - 새 에픽 R11(원칙 문서 정리)을 R2a · R5 · R10 과 지금 병렬로 더하고 R9 의 문서 정리를 R11 로 옮겼다(R9 의존에 R11) 「내가 말하는 내용같은거 이번세션이나 저번 세션에서 메모리에 넣었자나 claude md나 devbrew철학 원장?  중요 docs들에 넣고 지금은 낡은 개념들은 과감히 지워서 크기를 줄이자」 · 「새 에픽으로 지금 병렬 (권장)」
  - R9 의 플러그인 README · CHANGELOG 정리도 R11 범위로 옮겼다 「R11 에 더함 (권장)」
  - R5 설계문서 `## 미룸` 행대로 R2a 범위에 qg 범위 입력 · 문서 경로 정의 · 범위 안 여러 설계문서를 모두 의도로 읽기를 더했다 「R2a 가 고침 (권장)」
  - (같은 `## 미룸` 행대로) R2a 범위에 qg 의 테스트 실행 스크립트 셋을 shared/test-selection/ 으로 옮기고 qg 쪽은 링크로, 경로 예약에 그 자리를 더했다 「채택 — 이동은 R2a 가 (권장)」
  - (같은 `## 미룸` 행대로) R10 범위에 `흐름` · `산출물` 칸 채움 · 레포 안 재사용 검토 · 다음 세션 줄 문면 조율 · 하나짜리 brief 다음 세션 줄이 가정하는 마지막 전체 리뷰를 SDD 대신 고른 실행 방식으로 바꾸는 일을 더했다
  - (같은 `## 미룸` 행대로) R8 범위에 다른 파일에 박힌 레포 전용 값 · gh · superpowers 부재 강등을 더했다
  - (같은 `## 미룸` 행대로) R9 범위에 지휘자 시작 승인을 규모 공시만으로 바꾸는 일을 더했다
  - (같은 `## 미룸` 행대로) R5 범위에 쓴 자원 정리 · 계층 · 온톨로지 · 레포 전용 값 금지를 더하고, 받는 것에 R2a 의 테스트 실행 공유본을 더했다
  - 바뀜 R2a · R5 · R8 · R9 · R10 · 새 R11 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「내가 말하는 내용같은거 이번세션이나 저번 세션에서 메모리에 넣었자나 claude md나 devbrew철학 원장?  중요 docs들에 넣고 지금은 낡은 개념들은 과감히 지워서 크기를 줄이자」
  - 「새 에픽으로 지금 병렬 (권장)」
  - 「R11 에 더함 (권장)」
  - 「R2a 가 고침 (권장)」
  - 「채택 — 이동은 R2a 가 (권장)」
  - 「이대로 다시 나눈다 (권장)」

### 2026-10-17 · R5 계획 셋의 브랜치 · 경로 예약 · 순서 이유 등록과 리뷰 모델 레포 설정(R5 설계 §6 · §9 · §11)
- 바뀜: 바뀐 에픽 R5 「① /compact 후 다음 세션 줄 (권장)」
- 원문:
  - 「① /compact 후 다음 세션 줄 (권장)」

### 2026-10-18 · R2a 보안 잔여 경로 예약 · R10 에 pm-interview 개명 · R5 범위를 재결정에 맞춤
- 바뀜: 바뀐 에픽 R2a · R5 · R10 「pm-interview (권장)」 · 「지휘자가 spec 리뷰까지 (권장)」 · 「이대로 다시 나눈다」
- 원문:
  - 「pm-interview (권장)」
  - 「지휘자가 spec 리뷰까지 (권장)」
  - 「이대로 다시 나눈다」

### 2026-10-18 · R2a 계획 2 의 브랜치 등록(R2a 설계 §10)
- 바뀜: 바뀐 에픽 R2a — 브랜치 칸에 계획 2(공유 엔진 · R2 보안 잔여)의 feature/shared-review-engine-core 를 더했다 「이대로 (권장)」
- 원문:
  - 「이대로 (권장)」

### 2026-10-19 · R2a 남은 리뷰 엔진 · qg 소결함을 새 에픽 R12 로 · R8 범위에 AC17 (가) 권한 경계
- 바뀜: 바뀐 에픽 R8 · 새 에픽 R12 「새 에픽으로 (권장)」 · 「이대로 다시 나눈다」
- 원문:
  - 「새 에픽으로 (권장)」
  - 「이대로 다시 나눈다」

### 2026-10-20 · R12 범위 · 경로 예약에 R2a 미룸의 받는 곳 R12 행을 싣고 R10 이 넘긴 인터뷰 쪽 셋을 새 에픽 R13 으로 · R8 범위에 log-decision --quote 출처
- 바뀜: 바뀐 에픽 R8 · R12 · 새 에픽 R13 「새 에픽으로 (권장)」 · 「R12 로 (권장)」 · 「나눠서 다시 나눈다 (권장)」
- 원문:
  - 「새 에픽으로 (권장)」
  - 「R12 로 (권장)」
  - 「나눠서 다시 나눈다 (권장)」

## 위험 번호표

brief §5 의 번호 없는 위험 줄에 줄 순서대로 번호를 단다 — 숨은 가정 K1~K7 · 실패 양식 K8~K14 · 리뷰 참고 K15. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 장치를 없애면 늘 의도를 지키는 쪽으로만 작동한다 — 멈춤 판정의 주인이 조사하는 모델 자신으로 옮겨 무한 조사·조기 「충분」 선언이 사용자 모르게 열린다 — 근거 포화 개념의 불안정·조기 종료 실패 양식·무한 루프 사례
- K2 — 위험 — 숨은 가정: plan·구현을 쭉 가는 것과 왜곡 장치 제거가 서로 맞는다 — 실행 중 혼자 판정(Ruling)은 쭉 가게 하는 장치이고 plan 검토 게이트는 PM 이 plan 을 볼 마지막 자리 — 근거 superpowers SDD·brainstorming 원문
- K3 — 위험 — 숨은 가정: 사용자 말 그대로가 하류에서도 그대로 읽힌다 — brainstorming 은 자기 이해 요약을 새 정본으로 삼아 조각 N개면 N번 재해석 — 근거 Cognition 병렬 에이전트·brainstorming 원문
- K4 — 위험 — 숨은 가정: 인터뷰 시점에 나눈 경계가 맞고 하류가 따른다 — 하류의 2차 분해와 충돌하고 승인된 분해가 봉인되기 쉽다 — 근거 ADaPT·brainstorming 분해 문구
- K5 — 위험 — 숨은 가정: 한 세션이 압축을 여러 번 겪어도 의도와 조각 지도를 잃지 않는다 — 근거 Anthropic 장시간 하니스
- K6 — 위험 — 숨은 가정: 조각이 늘어도 spec 승인이 실질 검토로 남는다 — 도장 찍기로 쇠퇴 — 근거 승인 피로(근거 약함)
- K7 — 위험 — 숨은 가정: 찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 자신의 통제 자리가 섞여 있고 모델은 사용자 말에 맞추는 경향 — 근거 Sycophancy 연구
- K8 — 위험 — 실패 양식: 병렬 조각의 암묵 결정 충돌과 버전·CHANGELOG 같은 공유 파일 겹침 — 근거 Cognition·Anthropic 멀티에이전트
- K9 — 위험 — 실패 양식: 압축 뒤 조각 지도·결정 내력 소실 또는 덮어쓰기로 「한 곳」이 실제와 어긋남 — 근거 Anthropic 장시간 하니스
- K10 — 위험 — 실패 양식: 두꺼운 brief 의 역설 — 가운데 묻힌 조사·위험·열린 질문을 하류가 덜 씀 — 근거 Lost in the Middle
- K11 — 위험 — 실패 양식: 외부 문구가 바뀌면 devbrew 쪽 넘김 글이 조용히 무력화됨(설치본과 최신본이 이미 다름) — 근거 superpowers 원문 비교
- K12 — 위험 — 실패 양식: 무한 조사 또는 포화를 가장한 조기 종료 — 근거 무한 루프 사례·조기 종료 실패 양식
- K13 — 위험 — 실패 양식: spec 승인 하나만 남은 통제점이 도장 찍기로 무너지고 실행 판정이 보이지 않음 — 근거 승인 피로(근거 약함)
- K14 — 위험 — 실패 양식: 승인된 분해가 봉인돼 조각 사이를 되돌릴 경로가 없음 — 근거 ADaPT·재결정 규약이 확정 항목 단위뿐
- K15 — 위험 — 리뷰 참고 | [overdesign] #2-제약 — 번호로 추적하는 장치가 다섯 결정(D24·D40·D41·D42·D45)에 나뉘고 번호 체계가 셋이다(D24·D42 의 빠짐 경고는 같은 검사) — 사용자 발화 S 번호에 매단 원장 하나와 spec 리뷰 검사 하나로 합치는 쪽을 설계에서 검토한다(판정은 모두 남기고 구조만 합침) (리뷰 41df26ba#r1.1)
