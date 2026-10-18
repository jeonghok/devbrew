# 에픽 넘김 줄

승인된 로드맵의 에픽 하나를 설계하는 세션을 열 때 지휘 세션이 붙여 넣는 줄이다. brief 흐름의 다음 세션 줄(`${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/finishing.md` 의 B-3)과 같은 모양이고, 첨부와 정답 출처가 brief 가 아니라 그 에픽의 묶음이다.

**에픽 넘김 줄**

> `@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라. 이 묶음은 승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다 — 로드맵의 이 에픽 블록에 흐름: 칸이 있으면 brainstorming 대신 그 칸의 흐름(승인받은 그대로)을 따르고 설계문서 대신 산출물: 칸의 파일을 낸다(아래 설계문서 지시는 그 파일에 적용하고, 그 흐름에 없는 단계는 그 흐름이 정한 대로 한다). 이 에픽의 몫만 설계한다 — 묶음을 다시 나눌 근거가 보이면 스스로 나누지 말고 그 근거를 재분해 신호로 사용자에게 보고한다(${CLAUDE_PLUGIN_ROOT}/references/redecompose.md). confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 묶음의 모든 번호(확정 · 열린 질문 · 조사 · 위험 · 발화)를 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 묶음을 다시 읽는다. 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 묶음 ids 의 모든 번호를 싣고, 다른 에픽으로 넘기는 번호는 기각 칸에 그 에픽 번호를 적는다. 설계문서 frontmatter source_interview 에 <bundle-rel> 을, roadmap 에 <roadmap-rel> 을 적는다. 설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다. 설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로 뒤에 --bundle <bundle-rel> 를 붙여 Skill spec-distill:spec-review 를 부른다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다. 고른 실행 방식의 마지막 전체 리뷰(조사 에픽은 산출물의 AC 대조)에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

## 자리표

- `<bundle-abs>` — 묶음의 절대경로(첨부). 상대경로는 하니스가 세션 작업 디렉토리 기준으로 풀어 다른 파일을 붙일 수 있다.
- `<bundle-rel>` — 같은 묶음의 레포 루트 기준 상대경로(로드맵 블록의 `묶음:` 값을 로드맵 디렉토리에 붙인 것). `roadmap_status.py` 가 설계문서를 이 글자로 찾는다.
- `<roadmap-rel>` — 로드맵의 레포 루트 기준 상대경로. 설계문서 frontmatter `roadmap:` 값이 되고, spec-review 게이트 ③ 은 이 줄이 있는 설계문서를 로드맵 에픽으로 보고 재분해 절차로 보낸다. `<epic-id>` — 블록 번호(예 `R3`).
- `${CLAUDE_PLUGIN_ROOT}` — spec-distill 플러그인의 절대경로.

모든 자리표를 치환한 뒤 쓴다. 치환되지 않은 자리표가 남거나 경로에 공백이 있으면 쓰지 않는다 — 지휘 세션은 그 사유를 사용자에게 보인다(`proceed-gate.md` `## 다음 세션 명령` 규칙 5 와 같다). 새 세션(`/new`)의 첫 줄로 붙여 넣는다.
