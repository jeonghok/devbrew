# 문서 리뷰 엔진 PR 1 — 착수 baseline (실패 줄 수)

base: 7bc5b05 (2026-09-06)

| 테스트 | rc | 실패 줄 수 |
|---|---|---|
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | 1 | 1 |
| `plugins/spec-distill/tests/test_hook_output_schema.py` | 1 | 1 |

전체 tsv 는 재생성 가능하다(이 계획 Task 0 Step 3 의 스크립트). 위 표는 rc≠0 또는 실패≠0 인 파일만이다.

## 왜 RED 인가 (면제 목록 아님 — 기록)

- `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` — 양성 대조(positive control) 실패. 리포 전수에서 "matcher 없는 Bash PostToolUse 훅"이 1개뿐이어야 양성 대조가 성립하는데 지금은 그 개수가 기대와 어긋남(`✗ 양성 대조 실패: Bash matcher 훅이 1개뿐`). 구조 단언(A1)은 통과했고, 이 브랜치가 아직 훅 코드를 건드리지 않았으므로 이 실패는 브랜치와 무관한 선재 상태다.
- `plugins/spec-distill/tests/test_hook_output_schema.py` — `test_python_and_bash_resolvers_agree`: python `state_path` 리졸버와 bash `CLAUDE_PROJECT_DIR` 리졸버가 워크트리 경로(`.claude/worktrees/document-review-redesign`)에서 서로 다른 경로를 반환. 단언 메시지 자체가 "Follow-up PR per spec NG9 needed"라고 명시하는 기존에 알려진 워크트리-한정 결함(NG9) — 이 브랜치의 변경과 무관.
