---
type: roadmap
source_brief: docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md
---

# 지휘 맥락 경제 — my-team 구조로 지휘 재설계 — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

### P1 — 토큰 기준선
- 의도: 재설계 전 지휘 세션 · 하위 agent 토큰을 갈라 재어 비교 기준을 남긴다
- 범위: 한다: 백업한 세션 기록으로 캐시 읽기 · 쓰기 · 새 입력 · 출력을 갈라 측정(message.id 중복 제거) / 안 한다: 측정 도구 제품화
- 의존: 없음
- 브랜치: feature/token-baseline
- 묶음: P1.md
- 경로 예약: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md
- 크기: 작음
- 병렬: R1 과 병렬
- 순서 이유: 재설계 전에 재야 비교가 된다
- 근거: S31 · 조사 14
- 흐름: 조사 — 백업 기록에서 로드맵 세션을 골라 지휘 · 하위로 갈라 집계
- 산출물: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md

### R1 — 팀 파일 규약
- 의도: 과제 폴더 · INTENT.md · 역할 문서 · 규칙 목차 · 시작 묶음을 세워 읽기 설계의 바닥을 깐다
- 범위: 한다: 에픽 묶음 + 지휘 기록 → INTENT.md, results/, 역할 폴더(레포 공통) · 팀 전용 목록, 규칙 목차(새 이름) · HANDBOOK 운영과 경계 장치, 시작 묶음 고르기 스크립트, devbrew 파일 기준 단계 계산 / 안 한다: 지휘 절차서 개편
- 의존: 없음
- 브랜치: feature/team-file-contract, feature/team-file-read, feature/team-file-rules
- 묶음: R1.md
- 경로 예약: plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/scripts/spec_review_bundle.py, plugins/spec-distill/references/epic-handoff.md, plugins/spec-distill/scripts/team_layout.py, plugins/spec-distill/scripts/team_files.py, plugins/spec-distill/scripts/team_check.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/team_rules.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/workflow_superpowers.py, plugins/spec-distill/references/team-files.md, plugins/spec-distill/templates/team/, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/references/roadmap-ontology.md, REVIEW.md, docs/superpowers/roadmaps/HANDBOOK.md, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/designer/, docs/superpowers/roadmaps/writer/, docs/superpowers/roadmaps/worker/
- 크기: 큼
- 병렬: P1 과 병렬
- 순서 이유: 나머지가 이 파일 형식을 읽는다
- 근거: S8 · S21 · S41

### R2 — 지휘 절차 개편
- 의도: 절차서를 단계표 + 지시서로 쪼개고 순서 강제 · 실행기 칸 · 작업 방식 결합 풀기 · P8 개정을 한다
- 범위: 한다: 단계표 · 걸음별 지시서 · 손 절차 분리, 순서 강제 + 사람 승인 탈출구, 동시 수 레포 설정, 실행기 칸 · 사람 단계, SDD 고침 루프 위임, superpowers 결합을 단계 맞춤으로, P8 · CLAUDE.md 개정 / 안 한다: 상태 브랜치
- 의존: R1
- 브랜치: feature/conductor-stage-table
- 묶음: R2.md
- 경로 예약: plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/repo_defaults.py, docs/philosophy/devbrew-harness-philosophy.md, CLAUDE.md, plugins/spec-distill/references/docreview-profiles/design-doc.md
- 크기: 큼
- 병렬: R3 와 병렬 가능
- 순서 이유: R1 형식 위에서 단계가 돈다
- 근거: S14 · S18 · S37

### R3 — 지휘자 상태 브랜치 · 편지함
- 의도: 기계를 넘는 지휘자 소통 자리를 세운다
- 범위: 한다: 지휘자 상태 브랜치(코드 없음 · main 에 머지 안 함), 편지함 한 글 한 파일, STATUS.md 계산 · 커밋, 대화 계약, 브랜치 규칙 문서 예외 / 안 한다: 감시 · 표시
- 의존: R1
- 브랜치: feature/conductor-state-branch
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/scripts/conductor_state.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/state_path.py, docs/git-workflow/branch-strategy.md, plugins/project-init/hooks/post-tool-use.py
- 크기: 중간
- 병렬: R2 와 병렬 가능
- 순서 이유: 감시 mod 가 이 편지함을 본다
- 근거: S35 · 조사 13

### R4 — 현황 · 감시 mod
- 의도: mod 하나로 현황 · 토큰을 보이고 편지함을 감시한다
- 범위: 한다: 표시 전용 mod(권한 이벤트 미구독 · validate 락), 타이머 git fetch → 새 글이면 자기 세션 새 턴, kill switch, 최소 판 / 안 한다: 도구 승인
- 의존: R3, P1
- 브랜치: feature/conductor-status-mod
- 묶음: R4.md
- 경로 예약: plugins/spec-distill/README.md, plugins/spec-distill/dependencies.md
- 크기: 중간
- 순서 이유: 편지함과 측정 방식이 먼저 있어야 한다
- 근거: S38 · 조사 17

### R5 — 이전 · 재측정
- 의도: 기존 기록 · 도는 로드맵을 새 구조로 옮기고 옛 장치를 걷어낸 뒤 기준선과 다시 잰다
- 범위: 한다: 설계문서 지휘 기록 · 에픽 묶음 이전, 도는 로드맵 이전, 옛 장치 정리, 재측정 비교 / 안 한다: 새 기능
- 의존: R1, R2, R3, R4
- 브랜치: feature/conductor-migration
- 묶음: R5.md
- 경로 예약: docs/superpowers/specs/, docs/superpowers/roadmaps/, plugins/spec-distill/CHANGELOG.md
- 크기: 중간
- 순서 이유: 모든 새 장치가 선 뒤에 옮긴다
- 근거: S20 · S30

## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 두면 spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다 — 지휘자 없이 진행하려면 끄지 말고 지휘자를 부르지 않은 채 spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. 「머지」 줄은 PR 없이 로컬에서 머지한 에픽에만 적는다 — PR 로 머지한 에픽은 지휘자가 채운 PR 상태로 머지됨이 된다(squash · rebase 포함).

## 재분해 이력

### 2026-11-14 · 처음 로드맵
- 원문:
  - 「승인 (권장)」

### 2026-11-14 · R1 설계 승인 뒤 브랜치 · 경로 예약 · 번호 목록을 맞춘다 — 에픽 경계 · 범위 · 의존은 그대로
- 바뀜: 바뀐 에픽 R1 · R2 · R3 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-14 · R2 경로 예약에서 인터뷰 끝맺음 절차 파일을 뺀다 — 그 파일은 앞단 개선 로드맵이 맡는다
- 바뀜: 바뀐 에픽 R2 「뺀다 (권장)」
- 원문:
  - 「뺀다 (권장)」

## 위험 번호표

번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다. 박은 번호는 그 위험의 정체다 — 지운 위험의 번호는 다시 쓰지 않는다. 번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 준다 — 다중 agent 는 단일 agent 보다 크게 더 쓴다(조사 3, 2차) · 대응: 작은 일은 가볍게(D11)
- K2 — 위험 — 숨은 가정: 역할 폴더 CLAUDE.md · 경로 조건 규칙이 일꾼에게 실린다 — on-demand · 하위 agent 미상속 · 격리 worktree 미적재(조사 3 · 20) · 대응: 시작 묶음(D14 · D33) [RC199 → OQ40]
- K3 — 위험 — 숨은 가정: 120줄 목차 상한이 읽기 비용을 묶는다 — 근거는 자동 메모리 규약이고 줄 수는 바이트 예산이 아니다(조사 18) · 대응: 바이트 예산(D30)
- K4 — 위험 — 숨은 가정: 두 번 나온 지적은 일반화할 만큼 검증됐다 — 같은 오판의 되풀이일 수 있다(조사 18) · 대응: 반례 확인 승격(D30)
- K5 — 위험 — 숨은 가정: 「스크립트가 강제」라고 쓰면 실제로 강제된다 — 강제 장소(rc 를 읽는 스크립트 · 훅)가 정해지지 않았다(조사 18) [RC2 → OQ24]
- K6 — 위험 — 실패 양식: 지휘 세션을 새 세션으로 바꾸면 돌던 하위 agent 의 완료 알림이 끊기고, agent 팀이면 팀이 증발한다(조사 3) · 대응: 사용자 /compact(D16)
- K7 — 위험 — 실패 양식: STATUS 현황이 실제와 어긋난다 — 일꾼이 갱신 없이 끝나거나 멈출 때(조사 3) · 대응: 계산해 쓰는 STATUS(D18)
- K8 — 위험 — 실패 양식: 받음 확인 · 되읽기가 형식만 남아 오해한 채 진행한다(조사 3) · 대응: 산출물 대조(D12)
- K9 — 위험 — 실패 양식: 토큰 계측이 조용히 틀린다 — usage 반복 · 2.1.293–2.1.306 하위 출력 과소(조사 3 · 14) [RC151 → OQ27]
- K10 — 위험 — 실패 양식: 캐시 재작성 폭풍 — 리프레시가 맥락 퍼센트만 낮추고 비용은 올린다(조사 3) · 대응: 품질 신호(D11)
- K11 — 위험 — 실패 양식: 다른 작업 방식의 산출이 조용히 「계획 없음」으로 세어져 압축 뒤 계획 agent 를 다시 보낸다(조사 11) [RC150 → OQ33]
- K12 — 위험 — 실패 양식: mod 가 sandbox 없이 도구 호출을 승인할 수 있고, 이 기계에는 기본 가드를 싣는 관리 설정이 없다(조사 17 · 19) · 대응: 표시 · 감시 전용, validate 락
- K13 — 위험 — 실패 양식: 순서 강제가 정당한 경로를 막아 봉인된 결정이 된다(조사 18) [RC191 → OQ37]
- K14 — 위험 — 실패 양식: P8 · CLAUDE.md 만 고치면 사본 문장과 P8 이름 인용이 옛 뜻으로 남는다(조사 18) [RC189 → OQ24]
