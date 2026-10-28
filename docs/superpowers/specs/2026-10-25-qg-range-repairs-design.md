---
type: design
date: 2026-10-25
source_interview: 없음 — 로드맵 전체 qg(범위 7afca58f..92eb2ece)의 막는 지적 40건 수리
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
---

# 로드맵 전체 qg 막는 지적 수리 — 덩어리 다섯

## Context / Why

로드맵(2026-10-11-persistent-explore-pm-decompose)의 에픽 20개가 모두 머지된 뒤, 지휘 걸음 7(끝)이 품질 게이트를 로드맵 시작 커밋부터 끝까지(7afca58f..92eb2ece, 커밋 1129 · 파일 774) 한 번 돌렸다. 판정 줄:

`qg: defect · 막는 지적 40 · 선택 197 · 차등 새 실패 2 · e2e 안 함 · 제외 패치 0 · iter 1 · 92eb2ece`

막는 지적 40건은 이미 머지된 설계의 의도를 코드 · 테스트 · 문서가 지키지 못한 자리다 — 새 요구가 아니라 기존 결정의 수리다. 범위 모드는 고치고 다시 돌지 않으므로 고침은 새 브랜치에서 한다. 사용자 결정(2026-10-25): 「덩어리별 브랜치 (권장)」 · 「나눠서 — 작은 수리만 ③에 (권장)」 · 「다섯 모두 병렬 (권장)」.

지적 원문(심각도 · 위치 · 쉬운 말 · 원문 요약 · 낸 곳)은 qg 결과 기록의 `## 지적` 표다. 이 문서의 덩어리 표는 그 행의 위치만 옮긴다 — 각 구현 담당자는 자기 덩어리의 원문 행을 받는다.

## Goals

1. 막는 지적 40건 각각을 고치거나, 이미 고쳐졌으면(origin/main 에서) 그 커밋을 대며 「이미 고쳐짐」 으로 닫는다.
2. 동작 결함마다 고치기 전에 빨간 테스트를 먼저 두고(실패를 확인), 고친 뒤 초록을 확인한다. 「엉뚱한 이유로 통과하는 테스트」 지적은 변이(고친 코드를 되돌리거나 지키려는 검사를 지움)로 그 테스트가 빨개지는지 보인다.
3. 덩어리마다 PR 하나, 브랜치에서 qg 보통 모드 한 번.
4. 차등 새 실패 2(`test_epic_conductor_skill.sh` · `test_seed_grammar_crosscheck.py`)의 원인을 가려 고치거나 사유를 적는다.

## Non-goals

- 선택 지적 197건(SUGGESTION). 고친 줄 바로 옆이라 같은 커밋에서 한 줄로 고칠 수 있는 것만 예외로 하고 PR 본문에 적는다.
- qg 범위 모드의 새 동작(묶음 나누기 · 대기열 · 리뷰어 원문 저장 · 재비판 나누기 · 요약 층 · 기록 문서 축 · 범위 판정→고침 연결 · 펜스 러너 · 규모 공시 · 범위 질문 · 차등 후보 거르기) — 수리 다섯이 끝난 뒤 따로 설계 대화로.
- 설계의 대안 갈래를 새로 여는 것. 고치는 길이 설계 의도를 바꿔야 하면 그 덩어리만 멈추고 지휘자에게 돌려보낸다.

## Constraints

- 각 덩어리는 자기 「Files to Modify」 경로만 고친다(+ 그 플러그인의 `plugin.json` · `CHANGELOG.md`, 새 테스트 파일). 다른 덩어리 경로를 고쳐야 하면 멈추고 보고한다.
- 판 번호는 임시로 patch 하나 올린다 — 최종 번호는 지휘자가 머지 순서대로 정한다(①과 ④가 spec-distill 을 함께 올린다).
- macOS bash 3.2 · python 3.9 에서 돈다. 셸 테스트는 실행 비트(100755).
- 리뷰어 persona · 프로필 · 락을 약화하지 않는다. 락을 고치면 고친 락이 이빨이 있는지 변이로 보인다.
- 커밋은 Conventional Commits, 설명은 한국어. 지적 하나에 커밋 하나를 기본으로 한다.

## 덩어리

### ① 지휘자 머지 전 대조 — `fix/merge-check-trust`

| 심각도 | 위치 |
|---|---|
| CRITICAL | plugins/spec-distill/scripts/repo_defaults.py:40 |
| IMPORTANT | plugins/spec-distill/scripts/merge_check.py:352 |
| IMPORTANT | plugins/spec-distill/scripts/merge_check.py:186 |
| IMPORTANT | plugins/spec-distill/scripts/merge_check.py:421 |
| IMPORTANT | plugins/spec-distill/scripts/suite_lock.py:123 |
| IMPORTANT | plugins/spec-distill/scripts/conductor_ledger.py:1436 |
| IMPORTANT | plugins/spec-distill/tests/test_conductor_e2e.sh:50 |
| IMPORTANT | plugins/spec-distill/tests/test_workspace_invariance.sh:181 |

고치는 방향:
- 테스트 명령 · 실패 꼴(`test_command` · `test_failure_pattern`)은 검사받는 쪽이 쓸 수 있는 기계 상태 파일에서 읽지 않는다. 기계 상태 층을 이 두 키에서 뺀다. 종료 코드 6(테스트 명령을 모른다)이면 지휘자가 사용자에게 묻고, 그 답을 merge_check 의 명시 인자(예: `--test-command`)로 그 호출에만 넘긴다. 출처는 「이 호출의 인자(사용자 답)」 로 알리고, 레포 설정 파일에 올리자고 권한다. conducting.md 걸음 5 의 종료 코드 6 문장을 같은 PR 에서 맞춘다.
- 실패 꼴이 섞여도 새 실패를 놓치지 않는다. 알려진 꼴은 첫 꼴만이 아니라 전부 센다.
- `--keep-merged` 실행 폴더(`run-<ts>/`)의 임시 폴더 · 결과는 대조가 끝나면 지우거나 `ledger cleanup` 이 함께 지운다.
- `suite_lock.take()` 은 주인 없는 잠금을 옮기지 못하면 기다림 상한을 지키고, 쉬며, 이유를 알리고 멈춘다.
- `conductor_ledger.py` 의 예상 밖 예외는 「없음」(rc 1)이 아니라 검사 불가(rc 3)로 낸다.
- 테스트 둘: 빈 worktree 경로를 막는다(실제 레포에서 `git add -A` 금지). 로드맵 머리말에 층 키를 두어 해결자가 어디서 읽는지 가린다.
- 받는 곳 없는 미룸(R14 설계, 「과제 리뷰 · 마지막 리뷰의 작은 보강」)은 이 덩어리가 고친 파일에 닿는 것만 함께 고치고, 나머지는 PR 본문에 남긴다.

### ② project-init 브랜치 훅 — `fix/branch-hook-reflog`

| 심각도 | 위치 |
|---|---|
| IMPORTANT | plugins/project-init/hooks/post-tool-use.py:157 |
| IMPORTANT | plugins/project-init/hooks/post-tool-use.py:201 |
| IMPORTANT | plugins/project-init/hooks/post-tool-use.py:302 |
| IMPORTANT | plugins/project-init/skills/project-init/SKILL.md:320 |
| IMPORTANT | plugins/project-init/tests/test_post_tool_use.py:344 |

고치는 방향:
- 새 브랜치 찾기가 reflog 의 마지막 줄만 보지 않는다. 한 명령 안의 「브랜치 만들기 + 커밋」 도 잡는다.
- 이 세션의 명령이 만든 브랜치만 다룬다. 다른 세션의 브랜치에는 이름 바꾸기 명령을 내지 않는다.
- 셋업 직후 규칙 파일이 기본 브랜치에 아직 없을 때의 안내를 실제 동작과 맞춘다. 고치는 길은 둘 중 하나다 — 안내 문장을 고치거나, 규칙 파일을 찾는 곳에 작업 트리를 더한다. 설계(2026-10-20 dependency-portability) 의 「기본 브랜치에서 읽음」 결정을 지키는 쪽을 고르고 그 이유를 적는다.
- 테스트가 실제로 커밋까지 하게 해, 위 결함을 고치기 전에 빨갛게 만든다.

### ③ qg — `fix/qg-review-gaps`

| 심각도 | 위치 |
|---|---|
| IMPORTANT | plugins/quality-gates/scripts/gh-repo.sh:45 |
| IMPORTANT | plugins/quality-gates/scripts/publish-comment.sh:63 |
| IMPORTANT | plugins/quality-gates/scripts/review-diff.sh:131 |
| IMPORTANT | plugins/quality-gates/skills/artifact-critique/SKILL.md:157 |
| IMPORTANT | plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh:216 |
| IMPORTANT | plugins/quality-gates/tests/test_plain_synth_output.sh:96 |

작은 수리 셋(실행 경험):
- codex 러너가 0 아닌 종료로 끝나면 codex 의 종료 코드와 stderr 첫 줄을 meta 에 남긴다(지금은 `exit_nonzero` 만 남는다). 세 러너가 함께 쓰는 자리(`runner_common.sh`)에서 한 번만 고친다.
- quality-pipeline SKILL 흐름도의 ② 차등 테스트 설명에 「영향받는 테스트만」 을 적는다.
- 고를 지적이 넷 이상인 낮춘 지적 게이트(SKILL :716 `multiSelect: true`)는 「그대로 둔다」 와 「전부 되올린다」 를 함께 고를 수 없게 단일 선택으로 바꾼다.

고치는 방향: SSH 별칭 호스트를 실제 호스트로 풀거나, 풀 수 없으면 알리고 멈춘다. 로그인 실패를 「gh 없음」 과 다른 이름의 실패로 낸다. 리뷰 diff 에서 「Binary files differ」 로 든 파일은 리뷰한 것으로 세지 않고 이름과 함께 리뷰 안 됨으로 공시한다(`degraded: yes`) — 원본 바이트는 넣지 않는다(사용자 결정 2026-10-26: 「--text 빼고 리뷰 안 됨으로 공시」. `--text` 는 진짜 바이너리의 바이트를 모든 리뷰어 입력에 넣었다). 링크 대상을 합치는 문장을 실제 경로 검사와 맞춘다(문장 또는 검사). 테스트 둘은 경우마다 결과 파일을 지우고, 합성기가 죽으면 빨개지는 양성 단언을 더한다.

### ④ spec-distill 인터뷰 · 리뷰 — `fix/interview-review-gaps`

| 심각도 | 위치 |
|---|---|
| IMPORTANT | plugins/spec-distill/skills/pm-interview/references/state-file.md:53 |
| IMPORTANT | plugins/spec-distill/skills/request-framing/SKILL.md:1253 |
| IMPORTANT | plugins/spec-distill/skills/request-framing/SKILL.md:383 |
| IMPORTANT | plugins/spec-distill/scripts/brief_body.py:533 |
| IMPORTANT | plugins/spec-distill/agents/saturation-judge.md:60 |
| IMPORTANT | plugins/spec-distill/scripts/check_bundle_coverage.py:2308 |
| IMPORTANT | plugins/spec-distill/scripts/spec_review_bundle.py:128 |
| IMPORTANT | plugins/spec-distill/scripts/roadmap_status.py:351 |
| IMPORTANT | plugins/spec-distill/scripts/roadmap_write.py:90 |
| IMPORTANT | shared/docreview/scripts/docreview_state.py:2639 |
| IMPORTANT | plugins/spec-distill/tests/test_reviewing_brief_skill.sh:166 |
| IMPORTANT | plugins/spec-distill/tests/test_roadmap_write.sh:188 |

고치는 방향: 재개 후보 이름은 셸에 넣기 전에 허용 글자로 검사하고, 어긋나면 거절한다. `LEDGER_REFUSED`(상태 폴더 아래 링크)는 확정 직전 검사를 열지 않고 막는다(옛 rc 2 동작). 같은 세션에서 다른 주제로 다시 열면 옛 audit · seed 를 다시 쓰지 않는다. §6 원문 줄(사용자 발화 인용)은 하위 집합 검사에서 빼거나 원문 그대로 통과시킨다. 포화 판정은 실패한 조사를 「새로움 없음」 과 다르게 센다. 읽지 못한 이웃 문서 · 깨진 표 · merge-base 오류 · 짧은 쓰기는 「없음」 · 「설계 중」 · 성공으로 떨어지지 않고 「셀 수 없음」 · 실패로 낸다. 계수 줄의 멱등 키는 원장이 새로 만들어진 경우를 가린다(조용히 건너뛰지 않는다). 테스트 둘은 지난 날짜 칸과 종류 칸만 어긋난 픽스처를 더한다. 차등 새 실패 `test_seed_grammar_crosscheck.py` 의 원인(개발 의존 `markdown-it-py` 없이 돈 것인지)을 가린다.

### ⑤ 엉뚱한 이유로 통과하는 테스트 · R5 설계문서 낡은 기록 — `fix/vacuous-test-locks`

| 심각도 | 위치 |
|---|---|
| IMPORTANT | docs/superpowers/specs/2026-10-17-epic-conductor-design.md:161 |
| IMPORTANT | docs/superpowers/specs/2026-10-17-epic-conductor-design.md:295 |
| IMPORTANT | docs/superpowers/specs/2026-10-17-epic-conductor-design.md:535 |
| IMPORTANT | shared/tests/fixtures/docreview/cases.sh:3830 |
| IMPORTANT | shared/tests/fixtures/docreview/cases.sh:3958 |
| IMPORTANT | shared/tests/test_codex_project_doc_off.sh:1 |
| IMPORTANT | tools/adjudication/check_wiring.py:245 |
| IMPORTANT | tools/plain-language/measure_output.py:72 |
| IMPORTANT | tools/plain-language/test_measure_output.py:161 |

고치는 방향: R5 설계문서 본문 · AC 를 결정 기록과 지금 skill 에 맞추고(승인 질문 하나 · 지출 승인 없음), R5→R5 미룸 행 가운데 실제로 고치지 않은 것은 받는 곳을 바르게 적는다(받는 곳을 정할 수 없으면 지휘자에게 돌려보낸다). `$(...)` 안에서 잃는 실패 계수를 밖으로 꺼낸다. `1_0` 시험은 상한 안의 값으로 밑줄 검사만 거절하게 한다. 새 락에 `# guards:` 를 달아 차등 선택이 고르게 한다. 회계 호출 인식은 회계 함수 이름만 받고 음성 테스트를 더한다. 측정 도구 · 테스트는 지금 SKILL 의 반복 상한 문구를 세고, 픽스처를 SKILL 문구에 묶는다. 받는 곳 없는 미룸(R9 설계)의 `test_invocation_surface.sh` manifest 세 단언 · `test_epic_conductor_skill.sh` 공유 락 단언 RED(차등 새 실패 하나와 같다)를 고친다.

## Acceptance Criteria

- AC1 — 덩어리마다 그 덩어리 표의 행 전부에 「고침(커밋)」 · 「이미 고쳐짐(커밋)」 · 「돌려보냄(이유)」 가운데 하나가 PR 본문 표에 있다.
- AC2 — 동작을 고친 행마다 고치기 전 빨간 테스트(실패 출력 한 줄)와 고친 뒤 초록이 있다.
- AC3 — 「엉뚱한 이유로 통과」 · 「빈 단언」 행마다 변이 하나와 그 변이에서 빨개진 출력이 있다.
- AC4 — ①: 기계 상태 파일에 적은 `test_command` 는 merge_check 가 쓰지 않는다(테스트로 보인다). 종료 코드 6 갈래가 명시 인자로 돈다.
- AC5 — ③: 세 작은 수리가 들어가고, 각자 락 또는 테스트 하나가 있다.
- AC6 — 덩어리마다 공유 스위트에서 새 실패 0(지휘자의 merge_check 대조).
- AC7 — 덩어리마다 브랜치에서 qg 보통 모드를 한 번 돌리고, 판정 줄을 PR 본문에 싣는다.

## Files to Modify

각 덩어리 표의 파일, 그 플러그인의 `plugin.json` · `CHANGELOG.md`, 그 파일을 재는 테스트. ①은 `plugins/spec-distill/references/conducting.md` 걸음 5 의 종료 코드 6 문장도 고친다.

## Verification Plan

1. 구현 담당자: 행마다 빨강 → 고침 → 초록 → 커밋. 덩어리 끝에 그 플러그인의 테스트 전부와 고친 파일을 재는 `shared/tests` 를 돌린다.
2. 지휘자: `merge_check.py run` 스위트 대조 → 통합 리뷰(통합 리뷰어) → 브랜치 qg 보통 모드 → PR → 사용자 머지.
3. 다섯이 머지된 뒤 지휘 걸음 7 의 나머지(기록 PR · 자원 정리 · 표지 풀기).

## Rejected Alternatives

- 후속 PR 하나(걸음 7 기본값) — 40건 · 다섯 플러그인 영역이 한 PR 에 몰려 리뷰가 커지고 병렬이 안 된다. 사용자가 덩어리별을 골랐다.
- qg 실행 경험 14개를 ③에 전부 — 새 동작이라 설계 대화 없이 넣으면 Law 1 을 어긴다. 작은 수리 셋만 넣는다.

## 지휘 기록

- 2026-10-25 · 흐름: 수리 흐름 — 계획 문서 없이 덩어리 표의 행이 과제 목록이다. 이유: 행마다 결함 · 위치 · 고치는 방향이 이미 qg 지적과 재비판으로 정해졌고, 새 동작은 ①의 종료 코드 6 갈래 하나뿐이다. 구현 담당자는 행마다 `superpowers:test-driven-development` 로 고치고, 끝에 쓰기 도구 없는 리뷰어가 덩어리 전체를 본다.
- 2026-10-25 · 사용자 결정: 설계 승인 「이대로 (권장)」.

## Metadata

- qg 결과 사본: `~/.claude/sdd-mirror/epic-decisions/qg-roadmap-range-2026-10-25/`(result.md · findings.yaml · synth.out · recritic.txt)
- 덩어리별 지적 원문: `~/.claude/sdd-mirror/epic-decisions/qg-repair/chunk<n>-findings.md`
- 지휘: epic-conductor(spec-distill 8.10.0), 2026-10-25
