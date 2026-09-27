---
type: interview-seed
date: 2026-09-28
audit_file: 2026-09-28-resolve-audits-interview.audit.md
---

devbrew 리포의 감사 기록 폴더 두 곳, `docs/audits/` 와 `docs/archive/audits/` 를 정리해 없애는 일을
맡기고 싶다. 이 폴더는 이제 쓰지 않는다. 이번 작업의 끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것이다. (사용자 확인)
docs/audits/ 에는 앞으로 새 기록을 쌓지 않으므로 CLAUDE.md 의 `## Audits` 절이 말하는 축적 관례도 함께 끝난다. (사용자 확인)
docs/archive/audits/ 도 같은 기준으로 실제 구멍만 고치고 폴더째 없앤다. (사용자 확인)
2026-08-16 weight-reduction 사이클이 이미 이 폴더를 «해결 후 제거»하기로 정해 두었고, 이번이 그 마무리다.

문서 속 열린 항목을 다루는 기준은 하나다. 실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다. (사용자 확인)
감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력을 유일한 보존처로 둔다. (사용자 확인)
그러니 이번 일은 backlog 를 다른 곳으로 이관하는 작업이 아니다. 고칠 것은 고치고 나머지는 문서와 함께 사라진다.

폴더에 묶인 활성 코드가 있다. `/plugin-audit` 은 산출물을 이 폴더에 커밋하고, 검사기는 인덱스 링크와
CLAUDE.md 포인터를 요구한다. plugin-audit 산출물은 git-ignored 인 `.claude/plugin-audit/<session-id>/` 에 쓰고, 검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다. (사용자 확인)
플러그인 자체는 남긴다 — 제거하는 안은 고르지 않았다.
AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다. (사용자 확인)
CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다. (사용자 확인)

다시 검증할 것 — 첫째, 어느 열린 항목이 «실제 구멍»인지의 분류는 Phase 0 이 파일과 git 이력만 읽고
만든 후보일 뿐 확정이 아니다. 테스트는 한 번도 돌리지 않았다. 발동 중으로 보인 후보는 다섯이다.
quality-gates 의 `references/` 가 P21 secret 스캔 glob 밖에 있는 것, project-init 이 갈라진 CLAUDE.md 를
내용 이관 없이 한 줄 포인터로 재작성하는 것, trunk-based 템플릿이 legacy release 브랜치를 현재 main 에서
자르는 것, 그리고 선재 RED 두 개(`test_cancel_all_fence.sh` 의 실행비트, `test_no_write_matcher_hooks_repo.sh`
의 Bash matcher 개수 기대)다. 경계에 있는 후보도 있다. Law 2 agent `tools:` 락이 null 동의어·flow
mapping·locale 없는 sed 를 못 막는 것은, 지금 그렇게 쓴 agent 가 없으니 잠재로도, 검사가 비어 있으니
실제로도 읽힌다. codex 감사 러너가 웹 검색을 live 로 켜는 것, proceed 게이트 채택자 락이 라벨만 보는 것,
`test_codex_backward_compat.sh` 가 이미 고쳐졌는지도 같은 경계에 있다. 각 후보가 지금 정말 발동 중인지
실측해야 한다. 둘째, 선재 RED 두 개는 코드가 틀린 것인지 테스트가 낡은 것인지 아직 모른다. 셋째,
`test_brief_review_no_external_precondition.sh` 는 zero-tool-probe 감사 문서의 존재를 단언한다. 문서를 지우면
그 단언도 빠져야 하는데, 같은 weight-reduction 사이클이 확정한 «락 순감 금지»와 부딪혀 보일 수 있다.
넷째, 산출을 state 로 옮기면 plugin-audit README 가 Law 3 을 «커밋된 감사 기록»으로 설명하는 줄이
거짓이 된다. 또 state 의 «성공 시 자동 삭제» 규약이 사람이 읽어야 하는 감사 리포트를 읽기 전에 지울 수 있다.
