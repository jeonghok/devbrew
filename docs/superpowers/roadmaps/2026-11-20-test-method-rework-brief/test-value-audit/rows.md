# 테스트 진단 — 단위마다의 행

처음 읽은 사람이 적은 그대로다. 재독으로 바로잡은 판정은 `verdicts.tsv`, 재독 결과는 `rereads.md` 에 있다. 묶음 이름의 deep 은 깊게 읽은 묶음(시간의 90%), shallow 는 얕게 읽은 묶음이다.

## 묶음 deep-01

### plugins/plugin-audit/tests/test_audit_sandbox_create.sh
- 초: 8.2
- 줄 수: 366
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포 · 실제 audit-sandbox.sh create-sandbox(worktree add · 파일별 cp) 실행, 약 27개 레포
- 종류: 동작
- 지키는 것: 샌드박스가 작업 트리 상태(수정 · 미추적 · 삭제 · 스테이징 · 바이너리 · 실행 비트 · 링크)를 그대로 옮기되 git-ignored 비밀(.env)은 옮기지 않고, kill switch(새 · 옛 이름, 값 정확히 1)면 아무것도 만들지 않으며, 만들기 · remove 가 자기 이름(audit-rt-*/rt-*) 밖 · 리포 밖 · 링크 너머 · 사용자 worktree 를 지우거나 쓰지 않는다.
- 거짓 실패 위험: 낮음 — 출력 첫 줄(경로) · rc 값 · 파일 존재로만 판정해 동작이 바뀔 때만 깨진다. 대소문자 케이스는 파일시스템에 따라 「해당 없음」 으로 갈린다
- 겹침: plugins/plugin-audit/tests/test_run_own_tests.py — kill switch(새 · 옛 이름) 시 샌드박스를 만들지 않음이 겹친다(그쪽은 run-own-tests.sh 를 거쳐 잰다). 파일 안: kill_case 의 「`.claude/plugin-audit` 를 만들지 않는다」 는 옛 자리 검사라 새 자리에는 이빨이 없고 같은 줄의 worktree 수 검사가 실제로 막는다. plugins/project-init/tests/test_post_tool_use_branch.sh 는 이름만 언급(동작 겹침 아님)
- 보안 갈래: 예
- 판정 후보: 둠 — 경로 탈출 · 비밀 누출 · kill switch · 남의 worktree 보존을 동작으로 재는 115개 가량 확인에 8초는 맞는 값이다
- 확신: 중간
- 확인 수: 약 115개 (동작 115 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 케이스마다 mk_repo(git init · add · commit 4~5 프로세스) 후 create-sandbox(worktree add + 파일별 cp -a + 봉인 커밋)를 새로 돈다. 레포 약 27개 · create-sandbox 약 30회 · remove 약 25회(이름 범위 루프 15회)
- 구조 고치기 여지: 준비 함께 쓰기 — kill switch 양의 짝 루프(5개 레포)와 「사본 자리」 절의 레포들을 한 레포에서 create → remove 로 돌리기, mk_repo 를 한 번 만든 틀 레포의 cp -R 로 바꾸기(이득은 1~3초 정도로 작다)

### plugins/plugin-audit/tests/test_audit_sandbox_mutation_guard.sh
- 초: 19.8
- 줄 수: 588
- 고친 횟수: 4
- 크기: 큼 — 케이스마다 임시 레포 + 실제 샌드박스(약 38개), 변이 사본 3개를 만들어 돌린다
- 종류: 섞임(동작 35 · 구조 2 · 글자 0 · 변이 3)
- 지키는 것: 검증자가 샌드박스 안에서 제품 코드를 고치거나(추적 수정 · 삭제 · 새 파일 · 링크) 그것을 숨기려 해도(assume-unchanged · skip-worktree · .gitignore/info/exclude/excludesFile 위조 · stash · commit+reset · reflog 끄기 · 스냅숏 위조 · .qgbak 심기) mutation-guard 가 forced_downgrade: yes 또는 exit 4 로 막고, 무시된 런타임 산출물에는 거짓 강등을 내지 않으며, 본 레포의 info/exclude 를 망가뜨리지 않는다.
- 거짓 실패 위험: 낮음 — forced_downgrade 줄 · rc · 플래그 이름으로 판정. 변이 3개는 sed 대상 문자열이 audit-sandbox.sh 의 특정 줄과 글자로 맞아야 해, 그 줄을 다듬으면 「변이가 안 걸려 GREEN 이 원본과 같다」 가 되어 깨진다(중간 쪽)
- 겹침: 다른 파일 못 찾음(audit-sandbox.sh 를 실행하는 것은 이 파일 · create 테스트 · test_run_own_tests.py 의 실제 도우미 케이스뿐이고 mutation-guard 깊이는 여기만). 파일 안: 「clean sandbox -> no downgrade」(75행) 와 R2-AC1(d)(385행)가 같은 준비 · 같은 단언, 「tracked change」(82행) 와 R2-AC1(e)(392행)도 같은 준비 · 같은 단언이다. C-D-b 와 C-D-c 는 config 한 줄만 다르다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — Law 2 를 지키는 우회 봉쇄 확인이라 지울 것은 거의 없지만, 같은 케이스 둘을 덜고 읽기만 하는 케이스(스냅숏 키 · digest · 깨끗함 · 잘못된 기준선 · 빈 digest · 2-인자)를 샌드박스 하나에 모으면 준비 비용이 크게 준다
- 확신: 중간
- 확인 수: 약 80개 (동작 74 · 구조 3 · 글자 0 · 변이 3)
- 시간을 쓰는 곳: 추정 — 케이스마다 mk_sandbox 가 git init · commit · create-sandbox(worktree add · 스냅숏 · 봉인 커밋)를 새로 하고 mutation-guard(git add -A · 트리 해시 · diff 여러 번)를 1~2회 돈다. 38회 × (준비 약 0.3초 + 판정 약 0.2초) 가 대부분이고, 변이 3개는 sed 사본을 만들 뿐 추가 비용은 작다
- 구조 고치기 여지: 준비 함께 쓰기 — 읽기 전용 6~7개 케이스를 한 샌드박스로, mk_sandbox 의 레포 만들기를 한 번 만든 틀 레포 위에서 sid 만 바꿔 create-sandbox 하기. 줄이기 — 같은 케이스 2개(75행/385행, 82행/392행) 하나씩 덜기

### plugins/plugin-audit/tests/test_run_own_tests.py
- 초: 12.7
- 줄 수: 184
- 고친 횟수: 4
- 크기: 중간 — run-own-tests.sh 를 하위 프로세스로 10회, 그중 3회는 임시 git 레포 + 실제 audit-sandbox.sh
- 종류: 동작
- 지키는 것: run-own-tests.sh 가 샌드박스 안의 대상 테스트를 돌려 ran · forced_downgrade 를 정확히 보고하고(guard yes · exit 4 → 강등, 타임아웃 exit 124 → ran false, 도우미 부재 → 부재 사유, 대상 경로를 샌드박스 루트로 새지 않게 매핑), kill switch(새 · 옛 이름)가 켜지면 대상 테스트를 실행하지 않는다.
- 거짓 실패 위험: 낮음 — JSON 필드와 marker 파일 존재로 판정. why 문구의 부분 일치(「부재」 · 「sandbox 생성 실패」 · 「타임아웃」 · 「kill-switch」)는 사유 문구를 다듬으면 깨진다(중간 쪽)
- 겹침: plugins/plugin-audit/tests/test_audit_sandbox_create.sh — kill switch 시 샌드박스 미생성(이쪽 `ns` 단언은 옛 자리 `.claude/plugin-audit` 를 봐 새 자리 `.claude/worktrees/audit-rt-*` 에는 이빨이 없다 — 실제 차단 신호는 marker). plugins/plugin-audit/tests/test_run_own_tests_accumulate.sh — 같은 스크립트의 누산 동작(이름 대조만, 내용 확인 못 함). 파일 안: test_clean_run_reports_ran 과 test_target_path_resolves_in_sandbox 가 같은 준비 · 같은 ran 단언(뒤쪽이 전제 한 줄을 더할 뿐). 옛 이름 케이스의 「why 에 옛 이름」 단언은 why 가 두 이름을 늘 함께 싣는 고정 문구(run-own-tests.sh 34행)라 어느 이름이 켜졌는지 가리지 못한다
- 보안 갈래: 예
- 판정 후보: 줄임 — test_clean_run_reports_ran 을 target_path 케이스에 합치고, 옛 자리를 보는 `ns` 단언은 새 자리로 고치거나 덜어도 지키는 것이 그대로다
- 확신: 중간
- 확인 수: 약 28개 (동작 28 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 실제 도우미 케이스 3개가 git init · commit · create-sandbox · 대상 테스트 · mutation-guard · remove 를 다 돌아 가장 크다. 나머지 7개는 스텁 도우미지만 매번 bash + `timeout 120 python3 -m unittest discover` 를 새로 띄운다
- 구조 고치기 여지: 줄이기 — 같은 케이스 하나 덜기. 실제 도우미 3케이스는 kill switch 를 실제 스크립트가 읽어야 해 스텁으로 못 내린다(없음에 가깝다)

### plugins/project-init/tests/test_post_tool_use_branch.sh
- 초: 19.1
- 줄 수: 308
- 고친 횟수: 16
- 크기: 큼 — 시간 문턱 케이스가 훅의 git 예산(8초)을 다 기다린다 · git clone 약 50회 · 훅 python 약 60회
- 종류: 동작
- 지키는 것: Bash · EnterWorktree 뒤 이 명령이 만든 규칙 밖 브랜치는 사람 채널에 알리고 지금 브랜치일 때만 모델 채널에 `git branch -m` 을 내며, 다른 작업 트리 · 다른 세션 · 근거 없는 브랜치 · 일회용 detached 사본에는 이름 바꾸기 명령을 내지 않고(남의 브랜치를 바꾸게 하지 않음), 규칙 파일은 기본 브랜치 판에서 읽고, git 이 멈추거나 기본 ref · origin · 규칙이 없으면 알리고 건너뛰며, kill switch 면 git 을 부르지 않는다.
- 거짓 실패 위험: 중간 — 알림 문구를 긴 부분 문자열로 맞춰 문구를 다듬으면 여러 케이스가 함께 깨진다. 「훅이 10초 안에 끝난다」 는 예산 8초 + python 기동 + 종료 대기라 부하가 크면 넘을 수 있다
- 겹침: plugins/project-init/tests/test_post_tool_use.py — fail-open(기본 ref 없음 · origin 없음 · 규칙 파일 없음 · 작업 트리 규칙 안 읽음), kill switch(DEVBREW_PROJECT_INIT_DISABLE), 무관한 새 브랜치 · 만들었지만 지금 브랜치 아님 · 이웃 worktree 이름이 in-process 로 이미 잰다. 커밋 검사 양성 짝도 그쪽에 있다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 8초 대기 케이스를 test_post_tool_use.py 에서 예산을 작게 바꿔 in-process 로 재는 확인으로 내리고(10초 상한 끝-끝 확인 하나만 남기는 판단은 뒤에서), 겹치는 fail-open 셋은 한쪽으로 모을 수 있다
- 확신: 중간
- 확인 수: 약 55개 (동작 55 · 구조 1 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 「git 이 멈추면」 케이스가 sleep 30 가짜 git 앞에서 GIT_BUDGET 8초를 다 써 약 8~9초. 나머지는 fresh() 의 git clone 약 50회와 hook() 마다 python 두 번(입력 JSON · 훅) + 판정 헬퍼마다 field() python 두 번(systemMessage · ac)
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 시간 초과 경로를 test_post_tool_use.py 에서 GIT_BUDGET 을 줄여 in-process 로. 준비 함께 쓰기 — field() 를 훅 출력 한 번 파싱으로 두 칸을 함께 꺼내게 하기(케이스당 python 1~2회 절약). clone 대신 한 clone 의 브랜치 · reflog 를 케이스마다 새로 쓰는 것은 reflog 시각이 판정 입력이라 이득보다 위험이 크다

### plugins/quality-gates/tests/test_agent_model_mutation.sh
- 초: 6.5
- 줄 수: 92
- 고친 횟수: 13
- 크기: 큼 — 다른 테스트(스윕 9회 · agent 별 락 29회)를 다시 돌리고 레포의 실제 agent 파일을 고쳤다 되돌린다
- 종류: 섞임(동작 10 · 구조 1 · 글자 0 · 변이 28)
- 지키는 것: agent frontmatter 에 model 키가 생기면(다섯 표기 · qg 리뷰 agent 의 `model: opus` 되살림) 스윕과 agent 별 락이 실제로 빨개지고, agent 가 0개면 스윕이 공허하게 통과하지 않는다 — 즉 모델 고정 금지 락에 이빨이 있음을 지킨다.
- 거짓 실패 위험: 중간 — `plugins/*/agents/` 에 커밋 안 된 변경이 있으면 첫 단언이 RED(작업 중인 개발자 트리에서 깨진다). 실제 파일을 고치는 동안 병렬로 도는 다른 테스트가 그 agent 파일을 읽으면 그쪽이 흔들린다. agent 별 락의 다른 단언이 바뀌어도 「양성 대조」 가 깨진다
- 겹침: plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh — 모든 agent 의 model 키 부재를 이미 한 번에 잰다. 그래서 9개 agent 별 락의 model 키 단언은 스윕과 같은 것을 지키고, 이 파일은 그 중복 락 9개의 이빨을 따로 27회 다시 잰다. 양성 대조로 돌리는 락 9개(test_brief_agents.sh 는 두 번)는 스위트에서도 따로 돈다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 스윕 변이(다섯 표기 · opus 되살림 · 빈 glob 하한)만 남기고, 스윕이 이미 덮는 agent 별 락 9개 × 3회 재실행은 덜어도 「model 키가 생기면 RED」 는 그대로 지켜진다
- 확신: 중간
- 확인 수: 약 39개 (동작 10 · 구조 1 · 글자 0 · 변이 28)
- 시간을 쓰는 곳: 추정 — agent 별 락 29회 실행이 대부분(test_brief_agents.sh 285줄 · test_steelman_builder_scope.sh 163줄 같은 큰 락이 매번 통째로 돈다). 스윕 재실행 9회는 작고, awk 주입 · git checkout 이 케이스마다 한 번씩
- 구조 고치기 여지: 나누기 · 더 싼 확인으로 내리기 — 실제 파일을 고치는 대신 임시 폴더에 agent 사본을 두고 스윕을 그 폴더로 돌리게 하면(빈 glob 하한 케이스가 이미 그 꼴) clean-tree 요구와 병렬 간섭이 사라진다. agent 별 락 변이는 덜기

### plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh
- 초: 12.7
- 줄 수: 428
- 고친 횟수: 20
- 크기: 큼 — 중단 트리거가 매번 2초를 기다린다(5회) · 러너를 약 20회 하위 프로세스로 · scripts/references 를 3번 복사
- 종류: 섞임(동작 57 · 구조 1 · 글자 2 · 변이 0)
- 지키는 것: codex 러너가 추출 실패 · exit 0 빈 출력 · 완료 전 SIGTERM · 잘못된 인자 · discover-spec 실패 어느 경로로 끝나도 0바이트가 아니고 `codex_failed: true`(중단이면 `reason: aborted_before_completion`)가 적힌 산출물을 남겨 지난 라운드의 「성공」 이 이번 결과로 읽히지 않게 하고(리뷰어 하나가 조용히 사라지지 않음), --range 를 discover-spec 에 그대로 넘기며, CLAUDE_PLUGIN_ROOT 가 없어도 codex 에 닿고, 없어진 DISABLE_SPEC_CONFORMANCE 스위치를 한 줄로 알린다.
- 거짓 실패 위험: 중간 — 중단 트리거가 고정 2초라 부하가 크면 러너가 codex 에 닿기 전에 TERM 을 맞아 aborted_before_completion 단언이 흔들린다. stderr 사유 문구(「추출 실패」 · 「discover-spec.sh rc=2 … 커밋을 풀 수 없다」 · 없어진 스위치 문장 전체)와 대입 줄 모양 grep(407 · 410행)은 문구 · 코드 모양을 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/test_codex_exit_meta.sh — artifact 추출기 비0 종료 → 실패 표식이 겹친다. plugins/quality-gates/tests/test_range_wiring.sh — --range 연결(펜스 글자 쪽). 파일 안: FALLBACK 의 대입 줄 grep 두 개는 바로 위 동작 확인(env 없이 codex 에 닿아 finding 을 낸다)이 이미 지키는 것의 글자판이다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 12.7초 중 약 10초가 `timeout -s TERM 2` 고정 대기라, 잠자는 codex 스텁이 표지 파일을 만들면 그때 바로 TERM 을 보내게 바꾸면 지키는 것은 그대로 두고 시간과 부하 흔들림이 함께 준다
- 확신: 높음
- 확인 수: 약 60개 (동작 57 · 구조 1 · 글자 2 · 변이 0)
- 시간을 쓰는 곳: 추정 — run_until_aborted 5회(A · B 빈/stale · C 빈/stale) × 2초 = 약 10초. 나머지는 러너 실행 약 15회(각각 python 빌더 · 추출기 기동)와 `cp -RL scripts references` 3회
- 구조 고치기 여지: 더 싼 확인으로 내리기 — shared/tests/abort_trigger.sh 의 잠자는 스텁이 기동 표지를 쓰고 run_until_aborted 가 그 표지를 0.05초 간격으로 기다렸다 TERM(이 파일만 그 모듈을 쓴다). 준비 함께 쓰기 — rangeroot2 · stoproot 사본을 하나로. 덜기 — FALLBACK 대입 줄 grep 2개

### plugins/quality-gates/tests/test_discover_spec.sh
- 초: 12.1
- 줄 수: 389
- 고친 횟수: 14
- 크기: 중간 — 임시 git 레포 여러 개 · discover-spec.sh 를 약 50회 하위 프로세스로 · 판정마다 python
- 종류: 섞임(동작 88 · 구조 0 · 글자 4 · 변이 0)
- 지키는 것: 의도 출처를 Spec: 트레일러(범위 안 전부 · 커밋 순 · 중복 한 번 · #key 떼기 · 범위 모드는 끝 커밋 트리) → 커밋 메시지 + 이 브랜치 · 같은 레포의 열린 PR 본문 순으로 정하고, 절대 경로 · `..` · 리포 밖/미추적 대상 링크 · git-ignored · 미추적 · .git/config 트레일러는 읽지 않고 거부 수를 공시해 비밀(.env · 토큰)이 codex 의도로 새지 않게 하며, gh 는 `pr view` 만 부르고 gh 부재 · 미인증 · GitHub 아님이면 rc 3 으로 멈춘다.
- 거짓 실패 위험: 중간 — 대부분 JSON 키 · rc 로 판정해 낮지만, stop: 사유 문장 전체 일치(236 · 242 · 249 · 255행)와 review-criteria.md 한 문장 전체 정규식(226행)은 문구를 다듬기만 해도 깨진다
- 겹침: plugins/quality-gates/tests/test_discover_spec_keys.sh — 출력 키 집합. plugins/quality-gates/tests/test_range_wiring.sh — 범위 모드 discover-spec 실행(322행). plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh — 러너가 discover-spec rc 2 · rc 3 사유를 옮기는 것. 파일 안: 48행과 57행이 같은 run 을 두 번 돈다. review-criteria.md 두 단언(223 · 226행)은 discover-spec 동작이 아니라 문서 글자다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 경로 탈출 · 비밀 차단은 꼭 남길 동작 확인이지만, 실행마다 키 하나에 python 하나를 띄우는 판정과 같은 run 두 번을 줄이고, review-criteria.md 문장 고정은 문서 테스트로 옮기면 덜 깨진다
- 확신: 중간
- 확인 수: 약 92개 (동작 88 · 구조 0 · 글자 4 · 변이 0)
- 시간을 쓰는 곳: 추정 — discover-spec.sh 약 50회(각각 bash + 안의 python 3회), `key`/`spec_list` 판정마다 python 하나 약 45회, refused 루프 10값 × 2접미사 = 20회가 매번 새 커밋을 만들고 스크립트를 돈다
- 구조 고치기 여지: 준비 함께 쓰기 — 실행 출력 JSON 을 한 번만 파싱해 필요한 키를 함께 꺼내기, 48/57행 run 하나로. 나누기 — review-criteria.md 글자 단언을 문서 쪽 테스트로. refused 20회를 한 커밋 여러 줄로 묶는 것은 「어느 값이 샜는지」 가 흐려져 권하지 않는다

### plugins/quality-gates/tests/test_e2e_state.sh
- 초: 14.3
- 줄 수: 431
- 고친 횟수: 9
- 크기: 큼 — 실제 프로세스를 띄우고 sleep · 폴링으로 기다린다 · 임시 git 레포 약 25개
- 종류: 동작
- 지키는 것: e2e 지문이 HEAD · 추적 파일 · 무시되지 않는 untracked 의 변경(이상한 경로 이름 포함)을 잡고 무시 파일 · qg 자기 상태 폴더 · 자기 세션 사본만 빼며, before 지문을 고쳐 써도 해시로 드러나고, 판독 불가 · 예외는 same 이 아니라 exit 4 이며, 판정안은 증거 없는 충족을 미확인으로 강제하고, boot/stop 은 어떤 종료 경로(실패 · 시간 초과 · TERM · 리더 조기 종료)에서도 띄운 프로세스를 남기지 않되 pgid 1 · 재사용 pid · 시작 시각 없는 기록으로는 남의 프로세스를 죽이지 않으며, kill switch(값 정확히 1)면 측정 · 실행 전에 멈춘다.
- 거짓 실패 위험: 중간 — 프로세스 기동 · 정지를 sleep 0.5~1초와 pgrep 이름 계수로 재 부하가 크면 「남은 프로세스 0」 · 「자식이 떠 있다(≥3)」 가 흔들릴 수 있다. 출력 마지막 줄 문구(same · changed: N · boot-failed: …)는 계약 문자열이라 동작이 바뀔 때 깨지는 쪽이다
- 겹침: plugins/quality-gates/tests/test_e2e_fixture_app.sh — 실제 앱으로 boot · stop 한 번(양성 경로). plugins/quality-gates/tests/test_e2e_docs.sh — SKILL 의 e2e-state.sh 호출 펜스 글자(동작 겹침 아님)
- 보안 갈래: 예
- 판정 후보: 둠 — 남의 프로세스를 죽이지 않음 · 띄운 것을 남기지 않음 · 판정안 강제를 실제 프로세스로 재는 확인이라 대기 시간은 그 계약에서 온다
- 확신: 중간
- 확인 수: 약 88개 (동작 88 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — boot/stop 케이스의 대기(TERM 받은 boot 케이스 폴링 최대 5초 + 0.5 + 1초, 시간 초과 케이스 1초 + stop 폴링, RF1 · RF2 sleep 0.5, stop 의 0.5초 폴링)로 약 5초. 나머지는 fingerprint 약 40회(각각 bash + python + git ls-files)와 new_repo 약 25회(git init · add · commit)
- 구조 고치기 여지: 준비 함께 쓰기 — 레포 상태를 바꾸지 않는 케이스(kill switch 둘 · near-miss · stop 거부 셋 · I1 · 두 번째 boot 거부 · compare 판독 실패)가 각자 new_repo 를 만드는데 한 레포를 같이 쓸 수 있다(이득 1초 안팎). 대기 시간 자체는 줄일 여지가 작다

#### 읽지 못한 것 — deep-01

없음 — 여덟 파일 모두 끝까지 읽었다. 시간을 쓰는 곳은 모두 실행 없이 읽어서 한 추정이다. test_run_own_tests_accumulate.sh · test_post_tool_use.py 와의 겹침은 테스트 이름과 대상 이름만 대조했고 단언 내용까지 맞춰 보지는 않았다.

## 묶음 deep-02

### plugins/quality-gates/tests/test_intent_critic.py
- 초: 31.7
- 줄 수: 3244
- 고친 횟수: 41
- 크기: 중간 — 케이스마다 intent_critic.py 를 하위 프로세스로 띄우고 임시 git 레포를 만든다(양이 많다: 하위 프로세스 약 400번 추정 · 임시 레포 수십 개 · PATH 앞 가짜 git)
- 종류: 섞임(동작 193 · 구조 1 · 글자 23 · 변이 0)
- 지키는 것: intent-critic 의 답 파일 쓰기 · 커밋이 사용자 스테이지 · 작업 변경 · 추적 안 된 파일을 건드리지 않고(pathspec 매직 · glob 글자 · 심볼릭 링크 · 리포 밖 · git 무시 거부) 원문 · 로드맵 · 의심 가르기와 거르기 · 상한 · 기록 · 렌더의 출력 줄 · 돌려주는 꼴이 맞으며, 리뷰 트리 값이 계획 파일에 줄을 덧쓰지 못하고 페르소나가 읽기 전용 · 모델 핀 없음 · 자기 상한 없음으로 남는다.
- 거짓 실패 위험: 중간 — 동작 케이스는 한국어 공시 줄을 글자 그대로 대조해 문구만 다듬어도 여럿이 깨지고, 페르소나 · 절차 문서 · README 글자 확인 23개는 문장이 정확히 한 번(count==1) 나오는지 보므로 다듬기 · 줄 나눔만으로 깨진다
- 겹침: test_intent_return.py — TestGate.test_paths · test_tree_failed_writes_return_block · test_kill_switch_first 는 test_skip_and_fail_codes · test_stage_and_global_switch 가 더 넓게(어휘 · reason_text) 보는 같은 갈래, TestRecordUnreadAnswers · TestRecordSilentDrops 는 TestAnswerInput 과 같은 갈래(머리 앞 글 · 맞지 않는 머리 · 읽지 못한 입력/설정 · 빈 입력), TestRender.test_render_separates_unanswered_questions · test_render_wrong_choice_counted 는 TestQuestionRows 와 겹침 / test_intent_wide.py test_kill_switch_stops_prepare 와 꺼진 gate · prepare 갈래 겹침 / TestOldNameGone 은 test_intent_critic_wiring.sh 「옛 이름 부재」 9파일을 포괄 / 파일 안: TestRecordSilentDrops.test_text_before_first_header_is_disclosed 와 TestRecordUnreadAnswers.test_text_before_the_first_header_leaves_the_other_unanswered 가 같은 입력 · 같은 공시 줄, TestReadTracked · TestOriginLink · TestRoadmap · TestPrepare 가 같은 _origin_repo 를 클래스마다 새로 만든다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 CLI 케이스 대부분이 python 프로세스를 새로 띄우는데 스크립트에 main(argv) 가 있어 프로세스 안에서 부를 수 있고, 변형 열거 루프(모드 파일 15변형 × 2실행 × filter+render · 설정 값 22개 × config)는 판독 함수(_review_mode · _valid_answers_dir) 단위 확인으로 내릴 수 있다
- 확신: 중간
- 확인 수: 약 217개 (동작 193 · 구조 1 · 글자 23 · 변이 0) — 단언 줄 약 866
- 시간을 쓰는 곳: 추정 — _cli 호출 자리 73곳이 루프 · subTest 로 약 400번의 python 하위 프로세스(매번 yaml · 1916줄 스크립트 · 형제 모듈 import)가 되고, 그 가운데 TestFilteredListed.test_mode_file_with_other_text_falls_back_to_the_argument(15변형 × 2실행 × filter·render = 60번) · test_names_missing_the_answer_file…(8모드 × 2) · test_mode_file_alone/of_another_iteration · TestConfig.test_invalid_values(config 22번, 각각 git 호출) · test_return_block_values_stay_strings(render 8번)가 크다. TestCommitAnswers · TestRecord · TestRecordSilentDrops · TestRecordUnreadAnswers(_fresh 로 한 케이스 안에서 재준비) · TestUnwritableText · TestPlanInjection 은 케이스마다 임시 git 레포(git 프로세스 약 7개)를 새로 만들고 subTest 안에서도 또 만든다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — CLI 를 ic.main(argv) 프로세스 안 호출(stdout 리다이렉트 · env 패치, test_intent_return.py 가 이미 cmd_prepare 로 하는 꼴)로 바꾸고 프로세스 경계가 뜻 있는 kill switch · 환경 케이스만 하위 프로세스로 남김, 모드 파일 15변형 · 설정 값 22개는 _review_mode · _valid_answers_dir 단위 확인으로 내리고 끝에서 끝은 1–2개만 / 준비 함께 쓰기 — 첫 커밋 git 레포를 한 번 만들어 케이스마다 복사, _origin_repo 를 setUpModule 로 한 번 / 나누기 — 글자 잠금(TestPersona · TestOldNameGone · TestProcedureDoc)을 동작 파일과 갈라 둠

### plugins/quality-gates/tests/test_intent_critic_wiring.sh
- 초: 10.8
- 줄 수: 553
- 고친 횟수: 12
- 크기: 큼 — 실제 스크립트로 단계를 끝까지 16번 돈다(임시 git 레포 16개 · 스크립트 폴더 사본 8개 · 변이 7개 · 가짜 gh)
- 종류: 섞임(동작 122 · 구조 0 · 글자 59 · 변이 18)
- 지키는 것: intent-critic 단계가 끝까지 돌아도 판정 파일(verdict.out · comment-head.md · comment.md · findings.yaml · result.md 앞부분)이 그대로이고 qg-verdict-args 줄을 내지 않으며 답 커밋은 답 파일 하나뿐(사용자 스테이지 · 추적 안 된 파일 보존)이고, 두 kill switch 가 gate 를 건너뛴 prepare 에서도 넓게 보기 · 다른 팀 읽기 · gh 호출을 끄며, 테스트가 네트워크에 닿지 않고, SKILL · 절차 · 상태 문서가 이 단계를 게시 뒤 마지막 · 판정 밖으로 배선한다.
- 거짓 실패 위험: 중간 — 끝에서 끝 부분은 동작이 바뀔 때만 깨지지만 글자 확인 59개는 SKILL 의 영어 문장 · 절차 문서 표 행을 글자 그대로(grep -x · count==1) 대조해 문구 다듬기 · 절 이름 바꾸기만으로 깨지고, expect_checks 의 검사 수(20 · 16 · 14)는 검사를 더할 때 손으로 함께 고쳐야 한다
- 겹침: test_intent_critic.py TestOldNameGone.test_plugin_tree_carries_no_old_name 이 플러그인 트리 전체를 훑어 이 파일의 「옛 이름 부재」 9파일(모두 플러그인 안)을 포괄 / test_plain_qg_templates.sh 114–117줄이 Final verdict 의 할 일 문장 · 결과 줄이 마지막이라는 문장 · 옛 문장 부재를 같은 글자로 확인 / shared/tests/test_switch_tables.sh 가 README 끄기 표를 switches.md 와 대조(README kill switch 표 확인과 겹침 추정) / 「다시 돌기」 의 두 번째 render 거부는 test_intent_critic.py test_render_appends_after_publish_once 와 같음 / kill · kill-global 꺼짐 줄은 test_intent_return.py test_stage_and_global_switch · test_prepare_global_switch_reads_nothing · test_intent_wide.py test_kill_switch_stops_prepare 와 겹침(여기만 끝에서 끝 · gh 미호출 · 양의 짝까지 본다) / 파일 안: 바꾸지 않은 사본 3실행(pr · wide · kill-global)이 실제 실행 real-pr · real-wide · real-kill-global 과 같은 코드를 다시 돈다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 판정 불변 · 커밋 범위 · 스위치 · 네트워크 차단은 이 파일만 끝에서 끝으로 지키므로 남기되, 16번의 레포 · 세션 폴더 준비를 템플릿 복사로 함께 쓰고 다른 파일이 이미 지키는 글자 확인(옛 이름 9파일 · plain_qg_templates 와 같은 문장)을 덜 수 있다
- 확신: 중간
- 확인 수: 약 199개 (동작 122 · 구조 0 · 글자 59 · 변이 18)
- 시간을 쓰는 곳: 추정 — run_stage 16번(실제 6모드 + 바꾸지 않은 사본 3 + 변이 7, 그리고 kill 양의 짝 prepare 1번)마다 mkrepo(git 프로세스 약 7개) · 세션 폴더 쓰기와 python3 intent_critic.py 5–7번(각각 yaml · 형제 모듈 import), check_stage 마다 python3 -I 한 번과 git 4–5번, 사본 8개는 cp -L *.py · gh-repo.sh. 글자 확인(awk · grep 수십 번)은 작다
- 구조 고치기 여지: 준비 함께 쓰기 — mkrepo 결과를 한 번 만들어 cp -R 로 실행마다 복사(git init · commit 16번 제거), 변이 사본은 한 번 복사한 기준 사본에서 변이할 파일만 덮어쓰기 / 바꾸지 않은 사본 3실행은 변이 실행에서 과녁 밖 검사들이 PASS 인지로 양성 대조를 대신할 수 있는지 검토(사본 자체의 고장을 잡는 몫이 있으므로 지우기 전에 확인 필요) / 나누기 — 글자 확인 59개를 끝에서 끝 부분과 갈라 겹치는 다른 글자 테스트와 모음

### plugins/quality-gates/tests/test_intent_return.py
- 초: 7.6
- 줄 수: 1009
- 고친 횟수: 5
- 크기: 중간 — CLI 를 하위 프로세스로 약 110번(추정) 띄우고 TestAnswerInput 은 케이스마다 임시 git 레포를 만든다
- 종류: 섞임(동작 42 · 구조 1 · 글자 3 · 변이 1)
- 지키는 것: 부르는 쪽이 읽는 돌려주는 꼴(contract 2)의 머리 칸 차례 · 닫힌 어휘 · 결과 줄 · 질문 상태 다섯이 갈래마다 맞고 사람이 친 글(줄바꿈 · 제어 · 양방향 글자)이 한 줄로 접혀 꼴을 깨지 못하며, 답 입력의 번호 · 정체 머리 처리가 맞고 두 kill switch 가 켜진 record 가 답 파일 · 커밋을 만들지 않으며, 상태 문서의 칸 목록이 코드 상수와 같다.
- 거짓 실패 위험: 중간 — 결과 줄 · 사유 글을 글자 그대로 대조해 문구 다듬기로 깨지지만, 상태 문서 칸 목록 확인은 코드 상수에서 도출해 견주므로 동작이 바뀔 때만 깨지고, 수명 문장 · I5/I2/I7 문장 확인 셋은 다듬기만으로 깨진다
- 겹침: test_intent_critic.py — TestGate.test_paths · test_tree_failed_writes_return_block · test_kill_switch_first 가 test_skip_and_fail_codes · test_stage_and_global_switch 의 부분집합, TestRecordUnreadAnswers · TestRecordSilentDrops 가 test_unknown_number_only_disclosed · test_stray_text_does_not_fail_others · test_unreadable_config_fails_only_answered · test_unreadable_input_file_keeps_failure · test_empty_input_marks_unanswered 와 같은 갈래, TestRender.test_render_separates_unanswered_questions · test_render_wrong_choice_counted 가 test_six_paths_give_five_states · test_result_line_counts_match_states · test_wrong_choice_is_bool_text 와 겹침 / test_intent_wide.py test_kill_switch_stops_prepare 가 test_prepare_global_switch_reads_nothing 과 같은 꺼진 prepare 갈래(단계 스위치 쪽) / test_intent_critic_wiring.sh 의 kill · kill-global 실행과 꺼짐 줄 겹침 / 파일 안: test_record_stage/global_switch_writes_nothing 과 test_*_switch_with_unreadable_input 이 같은 _two 준비를 반복
- 보안 갈래: 예
- 판정 후보: 합침 — test_intent_critic.py 의 헬퍼를 빌려 같은 CLI 갈래(gate 건너뜀 · record 머리 · render 상태)를 같은 준비로 다시 돌므로, 어휘 · 칸까지 보는 이 파일 쪽으로 모으고 test_intent_critic.py 의 겹친 케이스를 덜면 지키는 것이 그대로다
- 확신: 중간
- 확인 수: 약 47개 (동작 42 · 구조 1 · 글자 3 · 변이 1) — 단언 줄 약 232
- 시간을 쓰는 곳: 추정 — CLI 하위 프로세스 약 110번이 대부분이다: TestAnswerInput 20케이스 × filter · record · render 3번과 케이스마다 임시 git 레포, test_outcomes 한 케이스 안의 filter · render 12번, test_six_paths_give_five_states 의 render 6번. TestReturnDoc 은 파일 읽기와 프로세스 안 변이 비교라 작다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — render · filter · record 를 ic.main(argv) 프로세스 안 호출로(test_prepare_global_switch_reads_nothing 이 이미 cmd_prepare 를 프로세스 안에서 부른다), 스위치 케이스만 하위 프로세스로 남김 / 준비 함께 쓰기 — TestAnswerInput 의 git 레포를 템플릿 복사로 (TestQuestionRows 는 이미 intent-questions.yaml 을 직접 심어 filter 를 건너뛰므로 그대로)

#### 읽지 못한 것 — deep-02

없음

## 묶음 deep-03

### plugins/quality-gates/tests/test_intent_wide.py
- 초: 20.0
- 줄 수: 1453
- 고친 횟수: 14
- 크기: 중간 — 테스트마다 임시 git 리포를 새로 만들고 intent_critic.py CLI 를 하위 프로세스로 약 80번 띄운다(바깥 호출 없음, gh 는 원격이 없어 불리지 않음)
- 종류: 섞임(동작 약 90 · 구조 약 10 · 글자 0 · 변이 0)
- 지키는 것: 넓게 보는 intent-critic 리뷰가 넓이(좁게 · 범위 · 의도 문서)를 맞게 정하고, 리뷰 트리 밖(링크 · `..` · 절대 경로 · .git · 추적 안 된 파일)을 읽지 않으며, 읽은 인용을 실제 파일 줄과 대조해 거르고, 파일 이름 · 커밋 제목 · 다른 팀 본문이 머리 줄을 흉내 내지 못하고, 끄는 스위치가 prepare 를 멈추는 것이 깨지면 사용자는 엉뚱한 근거로 질문을 받거나 트리 밖 글이 리뷰어에게 실린다.
- 거짓 실패 위험: 중간 — stdout 의 한국어 공시 줄(「넓게 본다 — 범위 모드」 · 「인용이 그 파일에 없어 거름 1」 등)과 돌려주는 꼴의 키 순서를 글자 그대로 비교해 문구만 다듬어도 깨진다. 판정 자체는 동작 비교다.
- 겹침: plugins/quality-gates/tests/test_intent_critic.py — has_evidence 의 차등 결과 꼴(541–590행)과 build_origin(642행 이하)을 R1 쪽에서 이미 잰다. TestDifferentialShape 의 일부와 겹친다. plugins/quality-gates/tests/test_intent_return.py — 돌려주는 꼴의 breadth · other_teams 칸을 일부 본다. plugins/quality-gates/tests/test_other_teams.py — _teams 가 넘기는 collect 결과의 상한 줄 · 겹침 요약을 양쪽에서 본다. 한 파일 안에서는 test_range_roadmap_only_record_with_origin 과 test_range_origin_same_file_loaded_once 가 「brief-quote-token 한 번」 을 함께 확인한다.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하지만 TestWidePrepare(30개)·TestOriginTimeout 은 테스트마다 같은 _wide_repo 를 git 으로 다시 짓는다. test_other_teams.py 의 _copy_teams_repo 처럼 한 번 짓고 복사하면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 93개 테스트 · 약 360개 단언 (동작 약 83 · 구조 약 10 · 글자 0 · 변이 0) — 구조는 키 순서 · COUNT_NOTICES 차례 · KINDS 꼬리 · MARK_TEAMS 같은 상수 비교
- 시간을 쓰는 곳: 추정 — ① `tic._cli` 가 intent_critic.py(약 1900줄 · yaml import)를 새 python 으로 약 80번 띄운다. prepare 는 그 안에서 other_teams.collect 를 돌려 git 하위 프로세스를 여럿 띄운다. ② TestWidePrepare setUp 이 테스트마다 git init + 두 커밋(약 8번 git)을 하고, topic_scope 두 테스트는 subTest 마다 tearDown/setUp 을 다시 부른다. ③ _WideRun 계열(TestWideFilter · TestWideRender)도 테스트 · subTest 마다 리뷰 트리용 git 리포를 새로 만든다.
- 구조 고치기 여지: 준비 함께 쓰기 — TestWidePrepare · TestOriginTimeout 의 _wide_repo 를 모듈 한 번 짓고 copytree 로 나누기(TestReadSides 는 이미 setUpClass 다). _WideRun._prepare 의 리뷰 트리도 템플릿 복사로. 더 싼 확인으로 내리기 — 같은 프로세스로 부를 수 있는 넓이 · 거르기 판정(이미 ic._prepare · ic._breadth 를 직접 부르는 테스트가 있다)은 CLI 대신 함수 호출로 돌려 python 기동을 줄인다. 다만 kill switch · stdout 이 R1 과 같은지를 보는 테스트는 CLI 그대로 둔다.

### plugins/quality-gates/tests/test_other_teams.py
- 초: 41.0
- 줄 수: 1444
- 고친 횟수: 9
- 크기: 큼 — 픽스처 리포를 한 번 짓고 39번 copytree 로 사본을 만든다. 각 collect 가 git 하위 프로세스를 수십 번 띄운다. 가짜 gh · 가짜 gpg 셸 스크립트를 쓴다(바깥 호출 없음)
- 종류: 섞임(동작 약 92 · 구조 약 3 · 글자 0 · 변이 0)
- 지키는 것: 다른 팀 읽기(other_teams.py)가 머지 · 스쿼시 · 리베이스된 브랜치를 빼고 남은 작업과 파일 겹침 · 의도 문서 · 열린 PR 을 맞게 찾고, 리포를 바꾸지 않으며(읽기 전용 git 명령만), 링크 폴더 · 옵션 모양 rev · 포크 PR · 줄바꿈 · 제어 문자가 든 이름이나 본문이 요약 절을 위조하지 못하고, 상한 · 시간 한도 · gh 실패를 「확인 못 함」 으로 공시하는 것이 깨지면 intent-critic 이 다른 팀 근거를 잘못 싣거나 남의 리포 밖 글을 읽는다.
- 거짓 실패 위험: 중간 — 「확인 못 함」 줄 · 상한 줄 · 머리 줄을 한국어 글자 그대로 비교한다(공시 문구를 다듬으면 여러 곳이 깨진다). 시간 문턱은 대역으로 흉내 내 부하에 흔들리지 않는다. 커밋 시각을 고정해 날짜 비교도 안정적이다.
- 겹침: plugins/quality-gates/tests/test_intent_wide.py — prepare 경로에서 다른 팀 기록의 상한 줄 · 겹침 요약(ot.summary)을 다시 본다. plugins/quality-gates/tests/test_publish_gh_two_files.sh — other_teams.py 의 `gh pr list` 가 읽기 전용 한 줄이라는 것을 글자로 본다(이 파일의 TestOpenPrs 는 동작으로 본다 · 다른 축). 한 파일 안에서는 TestReadOnlyGit.test_git_forms_run_clean 과 TestCollectGitForms.test_git_forms_run_clean_collect 가 git 명령 집합 · rc 를 겹쳐 보고(후자가 범위가 넓다), test_repo_untouched 가 두 클래스에 있다. TestOtherWork.test_rev_named_files_in_checkout_change_nothing 과 TestCollectGitForms.test_rev_named_files_change_nothing 도 같은 축(rev 이름 파일)을 두 층에서 본다.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 읽기만 하는 공유 픽스처에 똑같은 인자로 collect 를 거듭 돌린다(`_collect(self.repo, names={"a.txt"})` 10곳, `_collect(self.repo)` 5곳). 결과를 모듈에서 한 번 계산해 나눠 쓰면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 95개 테스트 · 약 260개 단언 (동작 약 92 · 구조 약 3 · 글자 0 · 변이 0) — 구조는 NO_OVERLAP · OVERLAP_UNKNOWN · PR_LIMIT · PR_TIMEOUT 같은 상수 비교
- 시간을 쓰는 곳: 추정 — ① collect 한 번이 브랜치마다 log · diff · merge-base · show · ls-tree 를 따로 띄워 git 하위 프로세스가 수십 번이다. 호출 자리가 약 76곳이고 subTest(rev 이름 파일 5 · always_lines 3 · PR 상한 3)를 더하면 90번 안팎이다. ② `_fresh()` 39곳이 픽스처 리포를 copytree 한다. ③ `_on_branch` · `_commit_off` 가 테스트마다 checkout 왕복과 커밋을 더한다. 템플릿 리포는 이미 한 번만 짓는다.
- 구조 고치기 여지: 준비 함께 쓰기 — 읽기 전용 공유 리포(_Fixture.repo)에 같은 인자로 부르는 collect 결과를 모듈 캐시로(TestOtherWorkRecord · TestCap · TestTopicSiblings · TestGitTimeout.test_no_timeout_no_line · TestNoEpicRoadmap.test_roadmap_with_epics_has_no_line). 합치기 — 두 클래스에 갈린 git 명령 형태 · repo_untouched 확인을 TestCollectGitForms 쪽 하나로.

### plugins/quality-gates/tests/test_publish_comment_sink.sh
- 초: 12.6
- 줄 수: 585
- 고친 횟수: 15
- 크기: 중간 — publish-comment.sh 를 bash 하위 프로세스로 약 85번 돌린다(한 번마다 git · secret-scan.py · 글자 수 python). gh · ssh 는 스텁이라 바깥 호출 0. 임시 git 리포 다섯
- 종류: 동작
- 지키는 것: 게시 sink 가 PR 코멘트를 정확히 하나만 새로 달고, 끄는 스위치 · 미인증 · origin 없음 · fork PR · head 불일치 · 닫힌 PR 에서는 달지 않거나 실패를 밝히며, 비밀 값이 든 본문(커밋 메시지 · 지운 줄 · 되돌린 값 · untracked · textconv · -diff 파일까지 corpus 에 넣어)과 이미지 · HTML 태그 본문을 막고, 본문 · 커밋 메시지 · 파일 이름의 명령을 실행하지 않는 것이 깨지면 사용자의 비밀이 GitHub 에 올라가거나 엉뚱한 PR 에 글이 달린다.
- 거짓 실패 위험: 낮음 — 결과 줄(`posted:` · `skipped:` · `failed:`)과 gh 호출 인자 · rc 를 본다. stderr 문구 grep 이 10곳쯤 있어 그 안내 문구를 바꾸면 깨진다. 케이스들이 한 리포(REPO)를 고쳤다 되돌리며 이어 써서, 한 케이스의 복원이 빠지면 뒤 케이스가 엉뚱하게 깨질 수 있다.
- 겹침: plugins/quality-gates/tests/test_publish_gh_two_files.sh — gh 쓰기가 publish-comment.sh 에만 있다는 것을 글자로 본다(이 파일은 동작 · 다른 축). plugins/quality-gates/tests/test_publish_pipeline_wiring.sh · test_range_wiring.sh — sink 경로 이름을 SKILL 글에서 본다(내용 확인 못 함 — 대상 이름으로만 찾음). 한 파일 안에서는 정상 게시(`posted:`) 양성 짝이 여러 케이스에 되풀이되지만 각 케이스의 대조군이라 필요하다.
- 보안 갈래: 예
- 판정 후보: 둠 — 비밀 유출 · 주입 · 끄는 스위치 · 인증 경계를 각 생산자(log · diff · untracked · textconv)마다 실제 sink 로 잰다. 한 번에 0.15초 안팎으로 비용이 지키는 것에 맞다.
- 확신: 높음
- 확인 수: 약 23개 케이스 · 약 100개 단언 (동작 약 100 · 구조 0 · 글자 0 · 변이 0) — P1 은 secret-scan 을 갈아 끼운 사본으로 판정 리터럴을 보는 대역 확인이다(변이 시험은 아니다)
- 시간을 쓰는 곳: 추정 — sink 를 한 번 돌릴 때마다 bash 기동 + gh-repo.sh + git log/diff/ls-files 로 corpus 만들기 + python3 secret-scan.py + python3 글자 세기가 이어진다. 약 85번이라 이것이 거의 전부다. I2 이미지 꼴 11가지 · N1 파일 이름 4가지 · P1 변형 4가지가 루프로 sink 를 각각 돈다. 65,536자 본문 두 개를 python 으로 만드는 비용은 작다.
- 구조 고치기 여지: 없음 — 각 케이스가 sink 가 앞에서 멈추는 서로 다른 관문을 보므로 sink 를 따로 돌려야 한다. 이미지 꼴 11가지를 sink 없이 검사 함수 하나로 내리려면 sink 안 인라인 grep 을 떼어 내야 하는데, 그것은 테스트가 아니라 대상 쪽 변경이다.

### plugins/quality-gates/tests/test_review_diff.sh
- 초: 53.5
- 줄 수: 1410
- 고친 횟수: 30
- 크기: 큼 — 케이스(와 모드 루프)마다 git init + 커밋 + git clone 으로 픽스처를 약 66번 새로 짓고, review-diff.sh 를 약 100번 돌린다. 파일 4000개 · 510개 · 긴 경로 160개 픽스처와 120초 시간 문턱 하나가 있다
- 종류: 섞임(동작 약 47 · 구조 약 2 · 글자 약 1 · 변이 0)
- 지키는 것: 리뷰 diff 생산자가 다섯 범위 모드에서 바뀐 경로를 빠짐 · 겹침 없이 싣고(인자 길이 묶음 · 접두 폴더 · 이름 대조), 문서 경로만 빼며, 바이너리 · 중첩 레포 · 선언 안 된 gitlink · 다른 세션 worktree 를 「리뷰하지 않았다」 로 공시하고 degraded 로 인증을 막고, 중첩 레포 · 사용자 설정의 fsmonitor · diff.external · textconv · 훅을 실행하지 않고, qg 자기 산출물만 문법대로 건너뛰는 것이 깨지면 리뷰어가 못 본 코드가 clean 판정을 받거나 리뷰 중 남의 코드가 실행된다.
- 거짓 실패 위험: 중간 — stderr 공시 줄을 `assert_line` 으로 한 줄 전체 글자 비교하는 곳이 많아(바이너리 · 중첩 레포 · gitlink · 이전 worktree 줄) 안내 문구를 다듬으면 여러 케이스가 함께 깨진다. stdout 11줄 · 키 순서 비교도 있다. 큰 제외 목록 120초 문턱은 넉넉해 부하로 흔들릴 일이 적다. case_degraded_blocks_certification 은 SKILL.md 판정 입력 표의 행 글자를 grep 해 표 문구가 바뀌면 깨진다.
- 겹침: plugins/quality-gates/tests/test_review_scope_composition.sh — 같은 중첩 레포 · gitlink 이유 줄을 스크립트에서 뽑아 README 와 대조하고 SKILL 이 `self_state:` 를 읽는지 글자로 본다(이 파일은 그 줄이 실제로 나오는지를 본다 · 축이 다르다). plugins/quality-gates/tests/test_range_wiring.sh · test_topic_scope_wiring.sh — review-diff 연결을 SKILL 글에서 본다(내용 확인 못 함 — 이름으로만 찾음). 한 파일 안에서는 case_topic_uses_boundary_tree 와 case_mode_file_records_the_mode 가 「boundary 가 '-' 면 rc 2」 를 되풀이하고, case_registered_worktree_only_not_degraded 는 case_other_session_worktree_degraded 의 양성 짝과 거의 같은 상태를 다시 잰다.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 넓고 분명하지만 시간의 큰 몫이 케이스마다 같은 A/R 픽스처를 git init · commit · clone 으로 다시 짓는 데 들 것으로 보인다. 한 번 지은 템플릿을 복사하면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 51개 케이스 · 약 420개 단언 (동작 약 410 · 구조 약 5 · 글자 약 3 · 변이 0) — 구조는 state-file-format.md 의 산출물 목록 · review-diff.sh 의 임시 이름을 읽어 문법이 받는지 보는 두 락(읽은 목록으로 실제 실행해 동작도 본다), 글자는 SKILL.md 판정 입력 표 행 grep
- 시간을 쓰는 곳: 추정 — ① mkfix 약 66번(모드 루프 포함): 한 번에 git init · add · commit · clone · checkout 으로 git 기동이 6번 이상이다. ② review-diff.sh(665줄) 약 100번: 한 번마다 git diff · ls-files · 이름 대조와 doc_paths.py python 기동. ③ case_excluded_prefix_not_swallowed 의 notes 4000개 생성 · add · 실행, case_keep_batches 의 510개와 긴 경로 160개 + 인자 상한 대역. ④ qg-worktree.sh create-baseline 으로 worktree 를 만드는 케이스가 약 6개.
- 구조 고치기 여지: 준비 함께 쓰기 — mkfix 를 「한 번 지은 A/R 템플릿을 cp -R 로 복사」 로 바꾼다(R 의 origin URL 이 A 의 절대 경로라 복사 뒤 `git remote set-url origin <새 A>` 가 필요하다). 나누기 — 4000개 · 510개 묶음 케이스(크기 · 인자 상한)를 따로 떼어 내면 나머지는 빨리 돈다. 줄임 — 한 파일 안에서 되풀이되는 rc 2 확인 하나와 등록 worktree 양성 짝 하나는 덜어도 된다.

### plugins/quality-gates/tests/test_run_test_selection.sh
- 초: 7.0
- 줄 수: 284
- 고친 횟수: 25
- 크기: 중간 — 케이스마다 임시 git 리포 + worktree 를 짓고 run-test-selection.sh 를 하위 프로세스로 돌린다(바깥 호출 없음)
- 종류: 동작
- 지키는 것: 차등 테스트의 배정 · 실행 행 파일 계약(꼬리 줄 · 행 수 · 커밋 대조 · 다시 돌린 행 교체 · flaky 재실행 한 번)과, 트리 밖 후보 · 범위 밖 shell 은 claim 하거나 실행하지 않고, 주 작업 트리 · 브랜치에 붙은 트리에서는 저장소 코드를 돌리지 않는 것이 깨지면 차등 결과가 옛 행 · 잘린 행으로 판정되거나 리뷰 대상 저장소의 코드가 사용자의 작업 트리에서 실행된다.
- 거짓 실패 위험: 낮음 — 행 파일의 칸 값 · rc · 표지 파일 유무를 본다. 꼬리 줄 글자(`#qg-assign	adapters=shell	rows=1`)는 계약 자체라 동작이 바뀔 때만 깨진다. 「디렉토리」 · 「미실행 러너: make」 stderr grep 둘만 문구에 기댄다.
- 겹침: plugins/quality-gates/tests/test_diff_test_results.py — 소비자 쪽에서 같은 꼬리 값 검증(340행 「생산자가 거부하는 꼬리 값은 소비자도 거부」)을 본다 · 생산자(이 파일 case_trailer_values_are_validated)와 짝이라 축이 다르다. plugins/quality-gates/tests/test_runner_adapters.sh — 같은 스크립트의 detect · 실행 관문을 맡아 나뉘어 있다(겹침 적음). shared/tests/test_test_selection_bundle.sh — granularity 한 줄로 사본 경로만 본다.
- 보안 갈래: 예
- 판정 후보: 둠 — 경로 탈출 · 주 작업 트리 실행 거부(R11 · R20)와 행 파일 무결성을 케이스 하나에 0.3초 안팎으로 본다.
- 확신: 높음
- 확인 수: 약 21개 케이스 · 약 60개 단언 (동작 약 60 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 케이스마다 mkrepo(git init · config 3번) + mktree(add · commit · worktree add)로 git 기동이 7번 안팎이고, run-test-selection.sh(673줄 · 안에서 python3 를 부르는 자리 8곳)를 케이스당 1–6번 돌린다. sleep · 시간 문턱은 없다.
- 구조 고치기 여지: 없음 — 리포 준비가 작고 케이스마다 행 파일 상태를 따로 가져야 해서 나눠 쓰면 케이스 사이 간섭이 생긴다. 여지가 있다면 assign 만 보는 다섯 케이스가 리포 하나를 함께 쓸 수 있으나 아낄 몫이 1초 안팎이다.

### plugins/quality-gates/tests/test_runner_adapters.sh
- 초: 7.8
- 줄 수: 190
- 고친 횟수: 24
- 크기: 중간 — 임시 폴더 · 임시 git 리포 + worktree, run-test-selection.sh 를 하위 프로세스로 약 35번 돌린다. 한 케이스(case_R3_setup_failure_is_unrun)는 진짜 `python3 -m venv` 를 만든다. 가짜 go · cargo 스텁
- 종류: 섞임(동작 25 · 구조 0 · 글자 1 · 변이 0)
- 지키는 것: 러너 어댑터 표(감지 9종 · 입도)가 맞고, 러너 없음 · setup 실패 · exit 127 은 unrun 으로 · 그 밖의 종료 코드는 error 로 갈리며(PRE_EXISTING 위장 방지), 끄는 스위치가 켜지면 실행 단계와 setup 단계 모두에서 저장소 코드를 하나도 실행하지 않고, 감지가 저장소의 json.py 를 import 하지 않는 것이 깨지면 차등 테스트가 못 돌린 것을 통과로 세거나 꺼 둔 사용자의 리포 코드가 실행된다.
- 거짓 실패 위험: 낮음 — 감지 결과 · rc · 행 칸 · 표지 파일을 본다. case_adapter_count_claims_match 는 문서의 「러너 어댑터 N종」 글자를 grep 해 그 표현을 바꾸면(예: 「9가지」) 0건으로 깨진다. 「jest 와 vitest」 · 「파싱에 실패」 stderr grep 둘도 문구에 기댄다.
- 겹침: plugins/quality-gates/tests/test_run_test_selection.sh — 같은 스크립트의 assign · run 행 파일 계약을 맡는다(R21 go 는 양쪽에 있으나 하나는 assign 의 패키지 접기, 하나는 run 의 absent 라 축이 다르다). shared/tests/test_test_selection_bundle.sh — `granularity shell` 한 줄을 사본 경로 확인에 쓴다(입도 표 전체는 이 파일만).
- 보안 갈래: 예
- 판정 후보: 둠 — 끄는 스위치 · 저장소 코드 실행 · 모듈 주입을 양성 대조와 함께 본다. 비용의 큰 몫은 venv 하나다.
- 확신: 중간
- 확인 수: 약 26개 케이스 · 약 37개 단언 (동작 약 36 · 구조 0 · 글자 1 · 변이 0)
- 시간을 쓰는 곳: 추정 — ① case_R3_setup_failure_is_unrun 이 진짜 `python3 -m venv .venv`(ensurepip 포함)를 만들어 수 초를 쓸 것으로 보인다 — 파일 전체 시간의 큰 몫으로 추정한다. ② detect 케이스 15개와 granularity 10번이 run-test-selection.sh 를 하위 프로세스로 띄운다(package.json 은 python 으로 읽는다). ③ 실행 관문 케이스 9개가 git 리포 + worktree 를 짓는다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — case_R3_setup_failure_is_unrun 은 「러너는 있는데 setup 만 실패」 를 재려고 진짜 venv 를 만든다. setup 명령이 실패하는 더 싼 픽스처(예: PATH 앞 python3 스텁이 venv 생성에서 실패)로 바꾸면 같은 관문을 볼 수 있다. 다만 스텁이 실제 setup 경로를 덜 닮게 되는 값은 따져야 한다.

#### 읽지 못한 것 — deep-03

- 없음 — 여섯 파일 모두 끝까지 읽었다. 다만 겹침 칸에서 이름으로만 찾은 파일(test_publish_pipeline_wiring.sh · test_range_wiring.sh · test_topic_scope_wiring.sh)은 그 안에서 무엇을 확인하는지까지 읽지 않았다. 시간 칸은 모두 실행 없이 코드만 읽은 추정이다.

## 묶음 deep-04

### plugins/quality-gates/tests/test_synthesize_recritic.sh
- 초: 8.1
- 줄 수: 1096
- 고친 횟수: 8
- 크기: 중간 — 케이스마다 임시 폴더를 만들고 synthesize_findings.py(1013줄)를 prepare · 합성으로 하위 python 프로세스로 띄운다
- 종류: 섞임(동작 99 · 구조 1 · 글자 0 · 변이 0)
- 지키는 것: 재비판자(code-recritic) 응답을 합성기가 판정으로 옮길 때, 근거 없는 기각 · 하향, 모르는 f, 겹치는 id 의 갈린 판정, 깨진 응답 · 매핑이 CRITICAL 지적을 조용히 지우거나 clean 판정을 내지 못하게 막는다(막히면 보류 · angle-absent · 게이트 변경 공시로 드러난다).
- 거짓 실패 위험: 중간 — 판정 값 · 수는 동작으로 재지만, 공시 문구(「강제(게이트 변경): lower.to '…'→'confirm'」 · 「탐지 0 · 재비판 0 — 재비판자가 돌았고 더한 finding 이 없다.」)와 표 행 모양(`| CRITICAL | app.py:10 |`)을 글자 그대로 찾아서 문구만 다듬어도 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_findings_adjudication.py — 소문자 raise · 낡은 매핑의 raise 저지 · 같은 등급 raise 를 단위로 잰다(이 파일의 case_raise_to_case_folds · case_raise_cannot_lower_when_map_is_stale · case_raise_to_same_severity_is_noop_not_degrade 와 같다) / 파일 안: case_unknown_verdict_value_is_coerced_to_confirm 와 case_downgrade_is_not_a_verb 가 같은 `downgrade` 입력, case_reject_needs_evidence 뒤 절반과 case_gate_coercion_is_disclosure_not_block 이 같은 근거 없는 reject 입력, case_dead_recritic_is_not_clean 와 case_primary_death_keeps_not_clean_marker 가 같은 응답 없음 입력이다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 분명하지만, 약 25개 케이스가 똑같은 one_finding 픽스처로 prepare 를 다시 돌리고, 문자열을 문자열로 옮기는 확인 대부분을 CLI 대신 한 프로세스 안의 단위 테스트로 잴 수 있다
- 확신: 중간
- 확인 수: 약 250개 (동작 249 · 구조 1 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 케이스 52개마다 python 을 2–4번 새로 띄운다(prepare 1번 + 합성 1–3번, 매번 synthesize_findings.py 와 yaml 을 새로 import 한다). 반복 케이스(case_evidence_must_be_text 12회 · case_ac6_lower_with_unknown_to_is_coerced_to_confirm 5회 · case_malformed_top_level_container… 3회 · lower 둘 2회씩)가 prepare 와 합성을 회차마다 되풀이해 python 을 약 170번 띄운다
- 구조 고치기 여지: 준비 함께 쓰기 — one_finding 기본 픽스처의 rf.yaml · map.json 은 한 번 만들어 케이스마다 복사한다 / 더 싼 확인으로 내리기 — 겹치는 id 서명 · raise · lower · evidence 표(case_colliding_* · case_ac6_* · case_evidence_must_be_text)는 test_synthesize_findings_adjudication.py 에서 to_adjudication_doc · apply_verdicts 를 한 프로세스 안에서 부르게 옮기고, CLI 로는 연결 대표 몇 개만 남긴다 / 같은 입력을 되풀이하는 케이스 셋(위 겹침)은 하나씩으로 합친다

### plugins/quality-gates/tests/test_topic_boundary.sh
- 초: 20.4
- 줄 수: 812
- 고친 횟수: 19
- 크기: 중간 — 케이스 41개마다 일회용 git 레포를 새로 만들고(init + 커밋 둘 이상) resolve-topic.sh · combine-tips.sh 를 bash 하위 프로세스로 돌린다
- 종류: 섞임(동작 96 · 구조 0 · 글자 4 · 변이 0)
- 지키는 것: 토픽 선언 트레일러(`Spec: <키>`)에서 리뷰 대상 구성원 브랜치 · 경계 · 커밋 집합 · 끝점을 고르는 일이 형제 · 머지된 조각 · 원격 전용 · 스택 · 중첩 머지 · 봉인에서 틀리지 않게(넓어지거나 · 빠지거나 · 고아로 떨어지지 않게) 지키고, 끝점을 합친 트리 · 충돌 귀속도 지킨다.
- 거짓 실패 위험: 중간 — 거의 모든 확인은 동작이 바뀔 때만 깨진다. 다만 case_no_merged_member_machinery(정확한 루프 줄 `for c in $C_LIVE; do` 가 2개)와 case_for_each_ref_sort_pinned(for-each-ref 호출이 한 곳이고 같은 줄에 `--sort=refname `)는 resolve-topic.sh 의 줄 모양을 리팩터하기만 해도 깨진다
- 겹침: plugins/quality-gates/tests/test_topic_head.sh — topic-head.sh 를 거쳐 같은 resolve · combine 경로를 끝에서 끝까지 잰다(머지된 조각은 기준선 · 경로 부재 · 한 브랜치의 조각 둘 · 원격 전용 형제 · 충돌 · 하위 디렉토리 호출 · 전부 머지된 키) / 파일 안: case_nkeys_grep_family_catches_genuine_trailer 는 case_f7_mixed_keys_in_T 와 준비 · 단언이 같다(F7 이 더 많이 잰다), case_f1_boundary 는 case_f1_two_siblings 와 같은 준비를 다시 세운다, case_eleven_keys_always 는 같은 resolve 를 rc 를 보려고 두 번 부른다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 동작 확인의 값은 높지만(고친 횟수 19, 회귀 락이 많다) 레포 준비가 케이스마다 처음부터라 비싸다. 같은 꼴의 레포를 함께 쓰고 중복 케이스 하나(nkeys 진짜 트레일러)를 지우면 지키는 것은 그대로다
- 확신: 중간
- 확인 수: 약 170개 (동작 163 · 구조 0 · 글자 7 · 변이 0)
- 시간을 쓰는 곳: 추정 — 케이스마다 mktemp + git init + 커밋 2개(git 약 8번)를 새로 하고, rt 를 부를 때마다 sync_base(git rev-parse 2–4번) + resolve-topic.sh(안에서 resolve-baseline.sh bash 를 또 띄우고 for-each-ref · log --all · 선언 커밋마다 merge-base · 조상 검사)를 돈다. rt 호출은 약 60번이고 case_detect_statuses(5번) · case_local_branch_named_origin_main(레포 2개 × 2번) · case_n1(main 커밋 5개 + merge)이 무겁다
- 구조 고치기 여지: 준비 함께 쓰기 — 「main 두 커밋」 기본 레포를 한 번 만들어 케이스마다 `cp -R` 하거나, resolve 가 ref 를 쓰지 않는 읽기 전용 케이스(F1 · F1 경계 · tips 결정론 · eleven_keys)는 레포 하나에서 차례로 잰다 / 나누기 — combine-tips 케이스 여섯(case_combine_*)은 resolve 와 무관해 따로 떼어 낼 수 있다 / 지움 — case_nkeys_grep_family_catches_genuine_trailer(F7 과 같다) / 더 싼 확인으로 내리기의 반대 — 글자 락 둘(machinery · sort_pinned)은 이미 동작 케이스(case_n2 · case_unrelated_after_merge · case_local_and_remote_same_commit_dedup)가 잰다면 지울 후보다

### plugins/quality-gates/tests/test_topic_head.sh
- 초: 24.0
- 줄 수: 415
- 고친 횟수: 12
- 크기: 큼 — 케이스마다 일회용 git 레포를 만들고, topic-head.sh 한 번이 resolve-topic(detect · resolve · commits — 매번 resolve-baseline)+ seal-worktree + combine-tips 를 줄지어 돌리며, create-head --topic 은 그 전체를 다시 돌리고 git worktree 를 만들고 지운다
- 종류: 섞임(동작 100 · 구조 0 · 글자 0 · 변이 0)
- 지키는 것: 선언된 토픽의 형제 · 현재 브랜치 · 미커밋 변경을 합친 커밋(head_commit)을 사용자 레포의 인덱스 · 워킹트리 · ref · 워크트리를 건드리지 않고, 레포의 훅을 돌리지 않고 만들며, create-head --topic 이 그 합친 커밋만 받고 봉인 단독 · 경계 · 낡은 값은 거부하게 지킨다.
- 거짓 실패 위험: 중간 — 대부분 동작이 바뀔 때만 깨지지만, 출력 고정 키 수 13 을 다섯 케이스가 되풀이해 핀하고 stderr 문구(「head-commit mismatch」 · 「all declared commits are already in base_ref) — no combined tree」)를 글자로 찾는다
- 겹침: plugins/quality-gates/tests/test_topic_boundary.sh — 머지된 조각 · 경로 부재 · 조각 둘 · 원격 전용 · 충돌 · 하위 디렉토리 · 전부 머지된 키의 status · 구성원 판단이 resolve 층에서 이미 잰 것과 같다 / plugins/quality-gates/tests/test_entry_safety_e1_e6.sh E6 — case_repo_hooks_not_run 과 거의 같은 픽스처(추적 hooks 넷 + core.hooksPath)로 「topic-head 가 훅을 돌리지 않는다 + git add 양의 짝」을 똑같이 잰다 / plugins/quality-gates/tests/test_qg_objects_unreachable.sh — th + create-head --topic + remove 를 같은 꼴로 돌린다(case_create_head_topic_accepts_derived_commit 와 준비가 같다)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 봉인 · 합친 트리 · 부작용 없음 · 훅 미실행 · create-head 대조는 이 파일만 지키지만, resolve 층 판단을 다시 재는 케이스와 E6 중복이 무거운 topic-head 실행을 늘린다
- 확신: 중간
- 확인 수: 약 90개 (동작 90 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — th 한 번이 bash 하위 스크립트 5–6개(detect · seal · resolve · commits · combine, 그 안의 resolve-baseline 셋)와 git 수십 번이다. th 는 약 30번 불리고, create-head --topic 은 안에서 seal + topic-head 를 다시 돌린다. case_create_head_topic_rejects_wrong_commits(th 1 + create-head 4) · case_scope_file_under_subdir_cwd(th 2 + create-head 2 + worktree add/remove) · case_create_head_topic_accepts_derived_commit(worktree add/remove)가 가장 무겁다. 케이스당 평균 약 1.1초
- 구조 고치기 여지: 준비 함께 쓰기 — 「형제 둘 + wip.txt」 레포(case_two_siblings_combined · case_no_side_effects · case_create_head_topic_accepts/rejects)는 한 번 세우고 th 출력을 함께 쓴다(th 는 부작용이 없다는 것을 이 파일이 스스로 잰다) / 줄임 — resolve 층에서 이미 잰 판단(merged · path absent · two fragments · remote-only · fully merged)은 topic-head 고유 칸(seal · tree · head_commit · commit 줄 · 13키)만 남긴다 / 합침 — case_repo_hooks_not_run 과 test_entry_safety_e1_e6.sh E6 는 한쪽으로 모은다(보안 갈래라 지우지 않고 한 곳에 둔다)

### plugins/quality-gates/tests/test_verdict_no_reread.sh
- 초: 7.5
- 줄 수: 435
- 고친 횟수: 4
- 크기: 중간 — SKILL.md 에서 판정 펜스를 뽑아(verdict_fence.py) 임시 git 레포에서 bash 와 zsh 로 실제로 돌린다. 매번 python 둘(채우기 + 안의 verdict.py)을 띄운다
- 종류: 섞임(동작 90 · 구조 1 · 글자 9 · 변이 0)
- 지키는 것: 최종 · trivia · scope-empty 판정 펜스가 세션 폴더(차등 · excluded.md · 범위 파일)를 다시 읽지 않고 받은 `qg-verdict-args:` 줄로만 판정하고, 비었거나 모양 밖이거나 셸 확장(`$( )` · 역따옴표 · 글롭)을 심은 줄 · 느슨해진 되올림 줄에는 판정 줄 없이 멈추며, excluded.md 가 링크면 그 너머에 쓰지 않게 지킨다.
- 거짓 실패 위험: 중간 — 펜스 실행 부분은 판정 줄 전체 문자열과 멈춤 사유 문구를 글자로 비교해 문구를 다듬으면 깨지고, 글자 확인 약 27개(Step 3.9 · Step 4 제목 줄, 「② 에서 온 세 행」, R24 문장 전체, README 한계 문장 전체, e2e 문장 수 = 2)는 SKILL.md · README 를 다듬기만 해도 깨진다(높음)
- 겹침: plugins/quality-gates/tests/test_skill_run_contract.sh — 같은 final-verdict 펜스를 뽑아 빈 줄 · 모양 밖 줄이면 판정 줄을 만들지 않는지를 실제로 돌려 잰다 / plugins/quality-gates/tests/test_differential_procedure.sh — 옛 D7 문장(「사본을 직접 읽어 정한다」)의 부재와 D5 펜스 끝의 emit-args 줄을 같은 문서에서 글자로 잰다 / plugins/quality-gates/tests/test_v1_verdict_line.sh — verdict.py --emit-args 와 판정 줄 렌더링을 잰다 / 파일 안: 모양 표 19줄 · 되올림 표가 셸 둘에서 그대로 두 번 돈다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 주입 · 링크 너머 쓰기 · 변조 무시는 분명히 지키지만, 셸에 따라 달라질 수 있는 것은 따옴표 · 확장 · 여러 줄 처리뿐인데 문법 표 전체를 zsh 로 다시 돌린다
- 확신: 중간
- 확인 수: 약 320개 (동작 290 · 구조 3 · 글자 27 · 변이 0)
- 시간을 쓰는 곳: 추정 — run_verdict 가 약 115번(셸 둘 × 모양 표 19 + 되올림 7 + 느슨함 8 + 위조 5 + trivia 3 …) 불리고 매번 verdict_fence.py 가 SKILL.md 를 처음부터 다시 읽어 펜스를 뽑고 채운 뒤(python 1), 펜스가 verdict.py 를 돈다(python 1). 합쳐 python 을 약 230번 띄운다. x_run(제외 결과 줄)도 셸마다 약 11번 같은 길을 간다
- 구조 고치기 여지: 줄임 — case_bad_lines_fail_closed 의 문법 표와 case_restore_line_cannot_loosen 표는 bash 한 셸에서만 돌리고, zsh 는 위조 줄 · 여러 줄 · 따옴표 케이스만 남긴다 / 준비 함께 쓰기 — 표지마다 펜스를 한 번만 뽑아 두고 자리만 바꿔 채운다 / 합침 — test_skill_run_contract.sh 의 final_case 행동 블록과 겹치는 모양 오류 케이스는 한쪽으로 모은다

### plugins/spec-distill/tests/test_brief_form_r2.sh
- 초: 12.0
- 줄 수: 264
- 고친 횟수: 7
- 크기: 중간 — 케이스마다 픽스처 쌍을 임시 폴더에 복사해 python 으로 고치고 check_brief.py(2101줄) gate 를 하위 python 프로세스로 돌린다
- 종류: 동작
- 지키는 것: 인터뷰 brief 게이트(check_brief.py gate)가 §1 출처 표시 누락 · 매달린 ⟨S<n>⟩, §0 · §3 결정 집합 불일치 · 해결 결정 누락 · 해결 내용 없음, §4 여러 줄 항목의 본문 줄 연결 · RC, 유니코드 공백 들여쓰기, 상태 자리 허용 목록 밖 표시(서식 글자 · 전각 괄호 등) · 같은 OQ 두 번을 red 로 막고 정상 꼴은 통과시키게 지킨다(Law 1 의 구조 게이트).
- 거짓 실패 위험: 중간 — rc 와 함께 오류 문구를 grep 해서(「해결로 닫은 OQ9」 · 「§0 결정 줄의 상태 표시가」 · 「결정 줄(선두 OQ<n>)에 있지 않다」 · 「unkeyed landscape entries」) 메시지만 다듬어도 깨지고, 기반 픽스처 interview-brief-v2-valid.md 의 §4 첫 항목 꼴이 바뀌어도 깨진다
- 겹침: plugins/spec-distill/tests/test_check_brief.sh — V2 변이로 해결 결정 · OQ 역참조를 gate 로 재고, TARGET_FUNCS 에 section1_provenance_failures · resolved_decision_failures · section4_body_failures 를 넣어 구조로 잠근다 / plugins/spec-distill/tests/test_brief_body.py — 유니코드 공백 이어짐(test_unicode_space_continuation) · 해결 토큰이 든 결정 줄 꼴(decision_line_problem) · 출처 표시 꼬리를 단위로 잰다(일부 겹침)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 케이스마다 같은 base 준비(복사 + python 으로 frontmatter 고치기)를 되풀이하고 gate 를 새 python 으로 띄운다. 한 프로세스 안에서 check_brief.gate 를 문자열 변형마다 부르면 지키는 것은 그대로 싸진다
- 확신: 중간
- 확인 수: 약 65개 (동작 65 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — gate 를 약 55번 돌리고 그때마다 base 가 cp 둘 + python 1번, put · app · rep4 가 python 1–3번, gate 가 python 1번(2101줄 import)이다. 상태 자리 표(11행 × 배치 2 = 22번)가 가장 크고, 합쳐 python 을 약 180번 띄운다
- 구조 고치기 여지: 준비 함께 쓰기 — base 의 결과(audit_file · payload 를 고친 쌍)를 한 번 만들어 케이스마다 cp 만 한다 / 더 싼 확인으로 내리기 — 픽스처 변형 · gate 호출을 python unittest 하나로 옮겨 check_brief 를 한 번만 import 하고 gate(path) 를 반복해 부른다(상태 자리 표가 가장 크게 준다)

#### 읽지 못한 것 — deep-04
없음 — 다섯 파일을 끝까지 읽었다. 다만 겹침의 「같은 것을 지킨다」 판단은 다른 테스트 파일을 끝까지 읽지 않고 해당 구절만 grep 으로 확인했다(test_synthesize_findings_adjudication.py · test_entry_safety_e1_e6.sh E6 · test_skill_run_contract.sh F 행동 · test_check_brief.sh V2 · test_brief_body.py). 글자 락 둘(case_no_merged_member_machinery · case_for_each_ref_sort_pinned)을 동작 케이스가 모두 대신하는지는 변이로 확인하지 못했다.

## 묶음 deep-05

### plugins/spec-distill/tests/test_check_brief.sh
- 초: 50.7
- 줄 수: 3230
- 고친 횟수: 88
- 크기: 중간 — 임시 폴더에 정상 쌍을 케이스마다 복사·변형하고 check_brief.py(+ section6 · brief_body · skepticism, 합 ~3,300줄)를 하위 python 으로 약 900번 띄운다
- 종류: 섞임(동작 82 · 구조 15 · 글자 2 · 변이 1)
- 지키는 것: 인터뷰 brief 의 기계 게이트(check_brief.py gate)가 필수 절 누락 · audit 짝 바꿔치기 · §6 원문 누락 · 출처 없는 조사 주장 · 건너뜀 줄 오용 등을 실제로 막고, 정상 쌍과 채운 출하 템플릿은 통과시키며, web 끄기 변수의 완화가 한 자리뿐이고 알려지는 것 — 이것이 깨지면 Law 1 의 유일한 구조 게이트가 조용히 뚫리거나 정상 brief 를 막는다
- 거짓 실패 위험: 중간 — 대부분 실패 메시지의 한국어 문구를 grep 으로 물고 정상 fixture 의 특정 줄을 replace 앵커로 써서, 메시지를 다듬거나 interview-brief-valid(.audit).md · v2-valid 를 고치면 수십 건이 함께 깨진다
- 겹침: plugins/spec-distill/tests/test_brief_body.py — AC18 문법 밖 앵커 · 결정 줄 사유 코드(anchor_confusable · decision_shape 등)를 판독기 단에서 이미 잰다 / plugins/spec-distill/tests/test_check_verbatim_coverage.sh — 같은 AC18 변형표를 다른 소비자로 되풀이 / plugins/spec-distill/tests/test_audit_template_gate_shape.py — T-TPL 의 coverage-mapper <k> 치환 · 출하 템플릿 게이트 통과 / 파일 안: AC8 과 U3-T8(web OFF + sentinel-only)이 같은 명령 · 같은 판정(주석이 스스로 「한 번 더 고정」이라 밝힘), T15 · read_tree · R10 이 정상 쌍 gate 를 세 번 띄움
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하고 크나, 같은 모듈을 케이스마다 새 인터프리터로 띄우는 짜임이 시간 대부분이라 한 프로세스 안 호출로 내리면 단언은 그대로 두고 크게 싸진다
- 확신: 중간
- 확인 수: 약 520개 (동작 430 · 구조 80 · 글자 8 · 변이 1)
- 시간을 쓰는 곳: 추정 — 케이스마다 `python3 check_brief.py gate` 로 2,100줄 모듈과 형제 셋을 새로 import 한다(약 900회 · 회당 ~50ms). F4 건너뜀 절(약 95케이스)은 케이스마다 cp ×2 · sed ×2 · 변형 python · gate python · JSON 파싱 python ×2 로 4~5개 인터프리터를 띄워 가장 무겁고, V2 절(v2mut 약 75회)은 변형 python + gate python + cksum 두 번, AC18 절(약 60회)은 bb_variant python + gate python 이다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — check_brief 를 한 번 import 해 gate() 를 프로세스 안에서 부르는 python 구동기 하나(변형 · 기대값을 표로)로 F4 · V2 · AC18 · N1c 절을 옮긴다(web 끄기 변수만 env 패치) / 준비 함께 쓰기 — skip_json 의 JSON 파싱 두 번을 skip_run 한 번의 python 으로 합치고 ac3_pair 의 cp+sed 를 python 안으로 / 나누기 — 기본 게이트 · V2 계약 · AC18 판독기 · F4 건너뜀 넷으로 파일을 갈라 병렬로 / 겹침 줄이기 — AC8 · U3-T8 중 하나, 정상 쌍 gate 세 번을 한 번으로

### plugins/spec-distill/tests/test_check_verbatim_coverage.sh
- 초: 16.7
- 줄 수: 806
- 고친 횟수: 24
- 크기: 중간 — check_verbatim_coverage.py 를 하위 python 으로 약 130번 띄우고 mktemp 파일 · 폴더를 19곳에서 만들며, 변이본을 위해 형제 스크립트 10개를 임시 폴더로 복사하고 RB SKILL 의 진입 게이트 펜스를 꺼내 bash 로 돌린다
- 종류: 섞임(동작 72 · 구조 5 · 글자 22 · 변이 1)
- 지키는 것: §6 원문 완전성 검사가 앵커 누락 · 요약 치환 · 부분 절단을 exit 1 로, 검사 불가(state 부재 · 빈 원장 · P21 자리표 관여)를 exit 3 으로, 예외를 exit 4 로 갈라 내고, 인터뷰를 닫은 답이 고른 선택지(source: chosen)인지 대조해 건너뛰기 변수로도 지나가지 못하게 하는 것 — 깨지면 원문이 빠지거나 비밀 자리표로 덮인 brief 가 조용히 리뷰로 넘어간다
- 거짓 실패 위험: 중간 — 대부분 rc · JSON 키로 판정하지만 꼬리의 약 22건은 README · CHANGELOG · finishing.md · reviewing-brief SKILL.md 의 문장을 grep -F 로 물어 문장을 다듬기만 해도 깨진다
- 겹침: plugins/spec-distill/tests/test_check_brief.sh — AC18 문법 밖 앵커 변형표(nbsp · 전각 S · 줄 구분자 등)를 gate 소비자로 같은 꼴로 되풀이 / plugins/spec-distill/tests/test_brief_body.py — 같은 사유 코드를 판독기 단에서 잰다 / 파일 안: 정상 경로 `brief-verbatim-ok` 3인자 호출이 21 · 349 · 368행에서 똑같이 세 번, T1 · T2 · T2 변이 · C1 · C3 · AC18 이 같은 입력을 rc_of 와 json_of 로 두 번씩 띄운다
- 보안 갈래: 예
- 판정 후보: 줄임 — 같은 입력을 rc 와 JSON 으로 두 번 띄우는 자리 약 22곳과 똑같은 정상 경로 3회를 한 번 호출(출력 · rc 함께 받기)로 덜어도 지키는 것이 그대로다
- 확신: 높음
- 확인 수: 약 115개 (동작 85 · 구조 6 · 글자 22 · 변이 1)
- 시간을 쓰는 곳: 추정 — AC18 15케이스가 케이스마다 변형 python + json_of + rc_of 로 인터프리터 3개를 띄우고(45회), 닫은 답 절은 tool.py(check_brief · check_verbatim_coverage 를 import)를 약 40번 새로 띄운다. 변이 블록은 형제 스크립트 10개 복사 + 두 python, rb 펜스는 bash 하위 프로세스 2개다
- 구조 고치기 여지: 준비 함께 쓰기 — rc_of/json_of 를 `out=$(…); rc=$?` 한 번으로 합친다(약 22회 절감) / 더 싼 확인으로 내리기 — 닫은 답 절의 tool.py 반복 호출을 한 python 안에서 여러 명령을 차례로 도는 구동기로 / 겹침 줄이기 — 같은 정상 경로 3회를 1회로. 꼬리의 문서 문장 grep 은 문서 락 파일로 옮길 수 있다

### plugins/spec-distill/tests/test_conducting_loop.sh
- 초: 13.2
- 줄 수: 224
- 고친 횟수: 28
- 크기: 작음 — 파일 읽기와 grep · awk 뿐이고 python 은 문장 판독 도우미로 약 35번 띄운다(시간은 셸 포크가 쓴다)
- 종류: 섞임(동작 0 · 구조 10 · 글자 80 · 변이 10)
- 지키는 것: 지휘자가 읽는 references/conducting.md 의 지휘 순환이 걸음 1~7 · 칸 다섯 · 핵심 지시 문장(승인 뒤 같은 턴 계획 agent · 맞추기 순서 · 동시 수를 상한으로 묶지 않음 · 옛 「턴을 끝낸다」 부재)을 유지하고, 문서가 부르는 ledger 명령 이름과 「끝」 낱말이 conductor_ledger.COMMANDS · conductor_state.WORK_DONE 과 같은지 — 깨지면 지휘 세션이 빠지거나 낡은 절차, 없는 명령을 따른다
- 거짓 실패 위험: 높음 — 약 110개 문장 리터럴을 「정확히 한 번」으로 물어, conducting.md 의 문장을 다듬거나 다른 걸음으로 옮기기만 해도 깨진다
- 겹침: plugins/spec-distill/tests/test_conducting_reference.sh — 같은 병렬 권장 문장(PAR, 76행)과 같은 문서의 절 · 걸음을 문장 락으로 잰다 / 파일 안: PAR 을 걸음 1 · 4 에 두 번, live-agent 확인 문장을 걸음 1 · 3 · 손 절차에 세 번
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 단언은 그대로 두고 걸음 본문을 단언마다 다시 잘라 내는 짜임만 바꾸면 초 대부분이 사라진다
- 확신: 중간
- 확인 수: 약 215개 (동작 0 · 구조 20 · 글자 172 · 변이 23)
- 시간을 쓰는 곳: 추정 — `once`/`assert_*` 가 단언마다 `step n` 으로 printf|awk 를 다시 돌리고 grep -oF | wc | tr 를 이어 단언 하나에 포크 5~6개, 합 약 1,000개 포크(macOS 에서 포크당 수 ms). cap_hits(22회) · recon_order · approve_order 등 python -I 약 35회가 나머지다
- 구조 고치기 여지: 준비 함께 쓰기 — 걸음 1~7 본문을 시작할 때 한 번씩 변수에 잘라 두고 단언은 그 변수를 쓴다 / 더 싼 확인으로 내리기 — 리터럴 목록(걸음, 문장, 기대 횟수)을 python 한 번에 넘겨 한꺼번에 세고, cap_hits 의 양성 대조 16줄도 한 호출로 / 겹침 줄이기 — PAR 문장 락은 test_conducting_reference.sh 와 한쪽으로

### plugins/spec-distill/tests/test_conductor_branch.py
- 초: 150.0
- 줄 수: 1512
- 고친 횟수: 24
- 크기: 큼 — 약 101개 케이스가 각자 임시 bare 원격 + file:// 클론 + 커밋 · push 를 새로 만들고, 15곳에서 클론을 더 만들며(얕은 클론 포함), CLI 를 하위 python 으로 45번 띄운다
- 종류: 섞임(동작 91 · 구조 1 · 글자 8 · 변이 0)
- 지키는 것: 지휘 상태 브랜치(conductor/<로드맵>) 쓰기가 체크아웃 · index · 다른 브랜치를 건드리지 않고, 표지 주인만 쓰고 지우며, force push · lease 없는 지우기를 git 문에서 막고, 거절되면 원격 끝 위에 다시 얹되 남의 글을 덮거나 중복하지 않고, 로드맵 폴더 밖 경로 · .. 이름을 거절하고, 오류 글에서 원격 주소 · 절대경로를 가리는 것 — 깨지면 여러 기계의 지휘 기록이 사라지거나 사용자 작업 트리 · 원격 브랜치가 망가진다
- 거짓 실패 위험: 중간 — 대부분 실제 git 결과로 판정해 동작이 바뀔 때만 깨지나, 소스 본문을 regex 로 읽는 경계 락(WriteBoundary · PublishBoundary · DeleteBoundary · CommandLineIdentity 약 9개)과 한국어 알림 문구 assertIn 은 코드 꼴 · 문구만 바꿔도 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_mail.py · test_conductor_status.py · test_conductor_cross.py — 같은 StateRepo 준비를 쓰나 SETTINGS_UNREADABLE · push_outcome · next_letter_name · looks_absolute 를 재는 다른 테스트는 못 찾음 / 파일 안: 얕은 클론이 정말 얕은지를 Fixture · Write · Publish 세 곳에서, GIT_ALLOWED 에 checkout~merge 가 없음을 Reading.test_git_runner_is_closed 와 WriteBoundary 에서 두 번, pre-receive 거절 준비를 Publish 의 두 케이스가 각자 되풀이
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하고 대부분 실제 git 동작이라 지울 것은 적지만, 케이스마다 원격 · 클론 · 첫 커밋을 처음부터 다시 짓는 준비가 초 대부분이라 준비를 함께 쓰면 크게 싸진다
- 확신: 중간
- 확인 수: 약 116개 (동작 106 · 구조 1 · 글자 9 · 변이 0) — 케이스 기준, 단언문은 약 400개
- 시간을 쓰는 곳: 추정 — StateRepo.setUp 이 케이스마다 git init --bare · clone(upload-pack) · config 3 · checkout · add · commit · push(receive-pack) · set-head 로 git 프로세스 약 12개를 띄운다(약 101회). Write · WriteFloorGuards · Publish(+클론 · 표지) · Delete(+ensure 둘 · send 둘 · write 하나 = push 5번) 의 setUp 이 그 위에 더 얹고, CB.write 한 번이 hash-object · update-index · write-tree · commit-tree · update-ref · push(+거절 시 fetch) 를 돈다. Delete.test_the_counted_tip… 은 CLI 를 14번 새 python 으로 띄운다
- 구조 고치기 여지: 준비 함께 쓰기 — setUpClass 에서 원격 · 클론 · 첫 커밋(과 Delete · Publish 의 확장 준비)을 한 번 지어 두고 케이스마다 shutil.copytree 로 사본을 쓴다(원격 URL 은 사본 경로로 고쳐 둠) / 나누기 — 저장소가 필요 없는 케이스(Names.test_stamp… · Publish.test_push_outcome_table · Publish.test_push_outcome_needs_the_bang_flag · MainCatchesEverything)를 StateRepo 밖 TestCase 로 옮겨 무거운 Publish setUp 을 피한다 / 더 싼 확인으로 내리기 — 같은 저장소에서 CLI 를 여러 번 부르는 루프(Delete 의 tip 꼴 14회 · SettingsErrorIsZero 의 6명령 ×2)는 main() 을 프로세스 안에서 부르고 CLI 경로는 한 번만 잰다 / 겹침 줄이기 — 얕은 클론 확인 · GIT_ALLOWED 루프를 한 곳으로

#### 읽지 못한 것 — deep-05

없음 — 네 파일을 끝까지 읽었다. 다만 test_check_brief.sh 와 test_check_verbatim_coverage.sh 가 쓰는 fixture 파일들의 본문은 열지 않았고(테스트가 무엇을 확인하는지는 테스트 본문의 변형 코드로 판단), 크기 칸의 「python 약 900번」 · 「약 130번」 같은 횟수는 반복문을 읽어 센 어림이다.

## 묶음 deep-06

### plugins/spec-distill/tests/test_conductor_cross.py
- 초: 141.5
- 줄 수: 483
- 고친 횟수: 8
- 크기: 큼 — 케이스마다 원격(bare)+클론+커밋·push 여러 번, Show 는 상태 브랜치 둘을 세우고 일부 케이스는 둘째 클론까지 만든다
- 종류: 동작
- 지키는 것: 지휘자가 `show` 로 보는 「다른 로드맵과 닿는 것」(예약·바꾼 파일 겹침, 같은 판 번호, 기본 브랜치 움직임, 도는 스위트, 남의 고침 수)과 다른 로드맵의 기다리는 질문·온 글이 맞게 계산되고, 남이 심은 STATUS·편지의 제어 글자·꼴 틀린 줄이 화면에 실리거나 화면을 세우지 못하며, show 가 fetch·push·gh 를 부르지 않는다.
- 거짓 실패 위험: 중간 — Computed 는 계산 결과 dict 를 봐서 낮지만, Show 는 렌더 줄 전체(「- 예약 겹침: … (PR 상태 미확인)」 등)를 assertIn 해서 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh — 걸음 1·4·7 이 같은 show 줄(예약 겹침·온 글 1·다른 기계의 기다리는 질문)을 명령줄로 다시 본다 / plugins/spec-distill/tests/test_conductor_mail.py — about 의 제어 글자 거르기를 읽는 쪽에서 본다(이 파일은 렌더 쪽 두 번째 층) / plugins/spec-distill/tests/test_conductor_status.py — waiting_add·sync 를 준비로 같이 쓴다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 케이스당 약 3.4초가 거의 다 git 픽스처를 새로 세우는 데 든다. 미리 만든 레포를 복사해 쓰면 싸진다
- 확신: 중간
- 확인 수: 약 113개 (동작 113 · 구조 0 · 글자 0 · 변이 0) — 케이스 42
- 시간을 쓰는 곳: 추정 — 케이스마다 StateRepo 가 git init --bare·clone·config 셋·commit·push·set-head(약 10번)를 띄우고, CrossRepo 가 put 과 에픽 브랜치 둘(각 checkout·add·commit·push·rev-parse·checkout)로 약 15번 더, Show 는 claim 두 번에 CB.ensure 두 번(상태 브랜치 커밋+push). 그 위에 self.text()/view() 를 케이스마다 2–4번 불러 cross_view 의 git 읽기를 되풀이하고, foreign_write 는 클론 하나를 더 만들며, cli() 는 python 을 새로 띄운다
- 구조 고치기 여지: 준비 함께 쓰기 — CrossRepo/Show 의 기본 상태(로드맵 둘·에픽 브랜치 둘·상태 브랜치 둘)를 setUpClass 에서 한 번 만들고 케이스마다 shutil.copytree 로 복사(또는 bare 를 한 번 만들고 clone 만). 레포를 바꾸지 않는 케이스(test_reserve_overlap…, test_changed_overlap…, test_fetch_config… 의 fetch_covers 표)는 같은 사본을 함께 써도 된다

### plugins/spec-distill/tests/test_conductor_e2e.sh
- 초: 9.4
- 줄 수: 138
- 고친 횟수: 8
- 크기: 큼 — 스위트 대조(merge_check run)가 합친 사본에서 pytest 를 실제로 돌리고, 걸음마다 roadmap_status·conductor_ledger 를 python 으로 새로 띄운다
- 종류: 동작
- 지키는 것: devbrew 밖 레포(기본 브랜치 trunk·접두 work/·폴더는 frontmatter)에서 지휘 순환의 기계 부분 — 단계가 준비→설계 중→승인→계획→구현 중→구현 끝→머지됨으로 넘어가고, 스위트 대조가 pytest 를 찾아 돌고, 정리가 브랜치를 남기고 worktree 만 지우며, 기계 상태를 지워도 작업 목록이 같고, main·docs/ 같은 레포 전용 값이 박혀 있지 않다.
- 거짓 실패 위험: 중간 — 단계·근거 글자를 통째 비교한다(「spec 승인됨(2026-10-18) · 계획 없음」, 「동시에 갈 수 있는 준비 에픽: E1(함께: E2) · E2(함께: E1)」) — 근거 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_ledger.py — claim·record·write-sections·cleanup·orphans·worktree-path 를 하나씩 더 자세히 본다 / plugins/spec-distill/tests/test_merge_check.sh — merge_check 를 따로 본다 / plugins/spec-distill/tests/test_roadmap_status.sh — 단계 계산(겹치는 정도는 확인 못 함). 이 파일만 이 걸음들을 이어서 한 레포에서 걷는다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 레포 전용 값이 없다는 것과 걸음 사이 이음매는 이 끝에서 끝만 보고, 9초는 그에 맞다
- 확신: 중간
- 확인 수: 약 37개 (동작 37 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 6 의 merge_check run(합친 사본 worktree + pytest 실행)이 가장 크다. 다음은 stage_of·reason_of 를 부를 때마다 roadmap_status.py --json 을 통째로 다시 돌리는 것(약 14번, 73–74·108–109 줄처럼 같은 상태에서 연달아 두 번 부르기도 한다)과 tasks_of(control_plane show --tasks) 네 번
- 구조 고치기 여지: 더 싼 확인으로 내리기(작음) — 같은 걸음 안의 stage_of·reason_of 를 status_json 한 번에서 두 칸을 함께 뽑게 하면 roadmap_status 실행이 서너 번 준다. 그 밖에는 없음

### plugins/spec-distill/tests/test_conductor_ledger.py
- 초: 87.6
- 줄 수: 2702
- 고친 횟수: 51
- 크기: 큼 — Repo 를 쓰는 케이스마다 원격(bare)+클론+커밋·push 를 새로 만들고, 상태 계산이 드는 명령은 roadmap_status.py 를 하위 프로세스로 띄우며, PendingSeat 는 상태 브랜치를 세우고 케이스마다 둘째 클론을 만든다
- 종류: 섞임(동작 약 730 · 구조 약 10 · 글자 0 · 변이 0)
- 지키는 것: 지휘 원장의 명령마다 — 표지를 쥔 세션만 기계 상태에 쓰고(rc 5), 깨진 기계 상태를 덮어쓰지 않으며, 정리(cleanup)가 링크·자기 자리·잠긴 스위트 사본·worktree 아닌 폴더를 지우지 않고, 자원 폴더 이름의 `..`·`/` 를 거절하며, PR 캐시 갱신·번호 기록이 다른 head·fork·다른 base 의 PR 을 받지 않고, 판정·지휘 기록 줄이 설계문서·INTENT.md 의 맞는 자리에 한 번씩만 들어가며, 사람 줄(승인)은 관문이 켜지면 record --human 으로만 쓰이고, 읽지 못한 것을 「없음」 이 아니라 「셀 수 없음」·rc 3 으로 낸다.
- 거짓 실패 위험: 중간 — 종료 코드와 기계 상태 행은 동작이 바뀔 때만 깨지지만, 안내 문장을 통째 비교하는 단언이 많다(test_reset_with_epic_is_refused 의 전체 출력 동등, test_mismatch_head_drops_only_that_row 의 expected 문장, test_upgrade_path… 의 정규식) — 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_e2e.sh — claim·record·write-sections·cleanup·orphans·worktree-path 의 정상 길 / plugins/spec-distill/tests/test_control_plane.sh — 「설정 폴더가 다른 레포」 절이 Roadmaps.test_two_entries_same_list·test_finds_in_configured_folder_only 와 같은 후보 목록(plan/roadmaps 바로 아래·검사 불가 사유)을 다시 본다 / plugins/spec-distill/tests/test_leader_seat_e2e.sh — 대기 줄(pending.md)·flush·남의 줄을 명령줄로 다시 본다(PendingSeat 와 겹침, 정도는 확인 못 함) / 파일 안 — 가짜 gh 를 PATH 에 심는 준비가 PrHandoffs·NoPrBranch·PrHandoffEdges·RecordedPrs·ReviewPack·UncountedBlock 에서 거의 같은 꼴로 되풀이된다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하지만 186 케이스 대부분이 레포 준비(git 약 8번)를 새로 하고, 그 가운데 git 이 필요 없는 케이스도 있다. 2702줄·51번 고침이라 명령별로 나누면 다음 고침도 싸진다
- 확신: 중간
- 확인 수: 약 741개 (동작 약 730 · 구조 약 10 · 글자 0 · 변이 0) — 케이스 186
- 시간을 쓰는 곳: 추정 — ① Repo.setUp 이 케이스마다 git init --bare·clone·checkout·add·commit·push·set-head 를 띄운다(186 × 약 8). ② audit·pr-refresh·pr-record·review-pack·roadmaps·pr-handoffs 가 L._status 로 roadmap_status.py 를 python 하위 프로세스로 띄운다(케이스 안에서 여러 번 부르는 것도 많다: test_upgrade_path…, test_mismatch_head…). ③ PendingSeat(TeamRepo)는 StateRepo 준비 + claim + CB.ensure(상태 브랜치 커밋+push) 위에 plant/foreign_edit 마다 둘째 클론을 만든다. ④ Resources·ReviewPack 은 worktree add·브랜치 커밋을 케이스마다 한다. cli() 는 프로세스 안 L.main 이라 그 자체는 싸다
- 구조 고치기 여지: 준비 함께 쓰기 — Repo 의 기본 레포를 setUpClass 에서 한 번 만들고 케이스마다 copytree. 더 싼 확인으로 내리기 — git 을 쓰지 않는 케이스(Pending.test_write_sections_refuses_empty_or_stray_rulings·test_record_rejects_bad_date…, TeamRecords.test_plan_and_retry_names_round_trip, UncountedBlock.test_predicate_corners·test_copies_do_not_add_branches… 처럼 Repo 를 물려받기만 하는 것)를 레포 없는 TestCase 로 옮긴다. 가짜 gh 심기를 헬퍼 하나로. 나누기 — Marker/Resources/Records/Pr*/ReviewPack/Team*/PendingSeat 를 파일 여럿으로

### plugins/spec-distill/tests/test_conductor_mail.py
- 초: 111.7
- 줄 수: 545
- 고친 횟수: 8
- 크기: 큼 — MailRepo 케이스마다 원격+클론+로드맵 커밋에 표지 둘·상태 브랜치 둘(커밋+push)을 세우고, 편지 보내기마다 상태 브랜치에 커밋+push 하며, cli() 는 python 을 새로 띄운다
- 종류: 섞임(동작 약 115 · 구조 약 5 · 글자 약 3 · 변이 0)
- 지키는 것: 다른 지휘자의 편지가 지시처럼 읽히지 않도록 틀 안에 갇혀 나오고(가짜 끝 줄·줄바꿈 글자·ESC·방향 제어 글자 포함), about 에 기계 이름·절대경로·홈 경로가 실려 원격에 올라가지 않으며, from 이 놓인 브랜치와 다르거나 꼴이 틀린 글은 세고 내지 않고, 받음 줄·답·세는 수가 맞으며, 표지를 쥔 세션만 보내고 받는다(rc 5)·끄면 쓰지 않는다.
- 거짓 실패 위험: 낮음 — 대부분 종료 코드·세는 수·읽은 본문을 보고, 문장 비교는 알림 줄 몇 개(「%s 지휘자의 글 — conductor/…」, 「온 글 없음」, 「꼴이 맞지 않아 내지 않은 글 5」)뿐이다
- 겹침: plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh — 걸음 3–6 이 send·read(틀 머리 한 줄·본문이 틀 안)·ack·답을 명령줄로 다시 걷는다 / plugins/spec-distill/tests/test_conductor_cross.py — about 의 제어 글자·온 글 줄을 렌더 쪽에서 본다 / plugins/spec-distill/tests/test_conductor_branch.py — CM.send 를 상태 브랜치 쓰기 준비로 쓴다 / 파일 안 — Send.test_refused_values_write_nothing·test_about_at_the_limit_is_taken 과 Closures.test_reader_closes_about_too 가 about 의 길이·제어 글자를 쓰는 쪽·읽는 쪽에서 나눠 본다(겹침이 아니라 두 층), test_long_body_is_written_and_told 와 test_long_body_note_counts_the_stored_body 는 같은 2000/2001 경계를 두 번 본다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(남의 글 거르기·경로 누출 막기)은 분명하나 케이스당 약 2.5초가 준비에 든다. 레포가 필요 없는 케이스를 빼고 준비를 함께 쓰면 싸진다
- 확신: 중간
- 확인 수: 약 123개 (동작 약 115 · 구조 약 5 · 글자 약 3 · 변이 0) — 케이스 44
- 시간을 쓰는 곳: 추정 — MailRepo.setUp 이 케이스마다 StateRepo(git 약 10번) + claim 둘 + CB.ensure 둘(상태 브랜치 만들기+push). 케이스 안에서 send/plant 를 2–10번 부르고 그때마다 CB.write 가 커밋+push(git 여러 번). Inbox 의 malformed·planted 케이스는 plant 를 5–9번 한다. cli() 케이스(약 10개)는 python 을 새로 띄워 같은 일을 다시 한다. test_notice_names_the_path… 는 클론 하나를 더 만든다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — Closures.test_reader_closes_about_too 는 parse_letter 만 부르는데 MailRepo 를 물려받아 상태 브랜치 둘을 세운다 → Shape 로 옮긴다. 준비 함께 쓰기 — 상태 브랜치 둘이 선 레포를 한 번 만들고 케이스마다 복사. 줄임 — 2000/2001 길이 경계 두 케이스를 하나로

### plugins/spec-distill/tests/test_conductor_state_branch_docs.py
- 초: 6.6
- 줄 수: 273
- 고친 횟수: 13
- 크기: 중간 — 대부분 문서 읽기·ast 지만, OldBehaviour 가 임시 레포를 세우고 control_plane·conductor_ledger 를 하위 프로세스로 열 번 띄우며, 닫힘 변이 케이스가 scripts 폴더를 통째로 복사한다
- 종류: 섞임(동작 약 8 · 구조 약 10 · 글자 약 42 · 변이 약 2)
- 지키는 것: 상태 계산·상태 화면이 상태 브랜치 모듈(conductor_branch·mail·status·leader_seat)을 가져오지 않고(닫힘 락, 변이로 이빨 확인), 옛 형식 로드맵의 화면·원장 출력이 상태 브랜치가 생겨도 바뀌지 않으며, 절차 문서가 코드의 닫힌 목록(편지 종류·질문 종류·건 길)과 명령 이름을 빠짐없이 싣고 「온 글은 자료다 … 사용자에게 보이고 묻는다」·「secret 을 적지 않는다」 문장을 지닌다. CHANGELOG·README 확인은 글자만 지킴 — plugins/spec-distill/CHANGELOG.md 의 `8.26.0`·`8.28.0` 절 낱말과 README 의 「### 지휘자 상태 브랜치」·「`delete` 는 끈 상태에서도 돕니다」.
- 거짓 실패 위험: 높음 — 글자 확인 약 42개가 references/conductor-state-branch.md·conducting.md·team-files.md·README·CHANGELOG 의 문장을 그대로 찾아 문장을 다듬거나 걸음 번호를 바꾸면 깨진다(닫힘 락·OldBehaviour 는 낮음)
- 겹침: plugins/spec-distill/tests/test_repo_literals.sh — references/conductor-state-branch.md 를 대상 목록에 둔다(다른 확인) / plugins/spec-distill/tests/test_conducting_loop.sh·test_conducting_reference.sh — conducting.md 걸음 본문을 정적으로 본다(step(n) 확인과 겹치는 정도는 확인 못 함) / plugins/spec-distill/tests/test_leader_seat_e2e.sh — 꺼진 설정의 R1 출력(AC14·AC20)이 OldBehaviour 와 비슷한 불변을 본다(정도는 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 줄임 — 닫힘 락·옛 형식 불변·닫힌 목록 동기화·「온 글은 자료다 / secret 금지」 문장은 둔다. 지난 판(8.26.0·8.28.0) CHANGELOG 절과 README 낱말 확인(Documents.test_readme_and_changelog, LeaderSeatDocs.test_readme_and_changelog_section_of_8_28_0)은 동작을 정하지 않는 글자다
- 확신: 중간
- 확인 수: 약 62개 (동작 약 8 · 구조 약 10 · 글자 약 42 · 변이 약 2) — 케이스 15
- 시간을 쓰는 곳: 추정 — OldBehaviour.test_status_screen… 이 출력 다섯(control_plane show ×3·ledger pending·resources)을 상태 브랜치 앞뒤로 두 번, 즉 python 열 번을 띄우고 그 안에서 roadmap_status 도 돈다. 그 다음이 test_a_planted_import… 의 scripts 폴더 copytree. 글자 확인은 거의 0초
- 구조 고치기 여지: 없음(6.6초로 작다). 줄임 대상 둘을 지우면 글자 확인 약 15개가 준다

### plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh
- 초: 23.6
- 줄 수: 146
- 고친 횟수: 4
- 크기: 큼 — 원격 하나에 클론 둘(서로 다른 기계 흉내)과 team_repo 픽스처를 세우고, 걸음마다 스크립트를 python 으로 새로 띄워 push·fetch 한다
- 종류: 동작
- 지키는 것: 두 기계의 지휘자가 명령줄만으로 claim→ensure→sync→show→send→fetch→read→ack→답→waiting→delete 를 끝까지 걸을 수 있고, 표지 없는 세션의 sync·ensure·send 는 5 로 막히며, 상태 브랜치에는 로드맵 폴더 밖 파일이 없고 origin trunk·작업 폴더는 그대로이며, 확인 없이는 delete 가 브랜치를 지우지 않고, team 형식 로드맵에서도 sync·show 가 돈다.
- 거짓 실패 위험: 중간 — show·delete 출력 줄을 글자로 찾는다(「- 예약 겹침: src/shared.py — $BE」, 「온 글 1 ·」, 「상대가 아직 받지 않은 보낸 글 0 · 내가 답하지 않은 온 질문 0」) — 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_cross.py·test_conductor_status.py·test_conductor_mail.py — 걸음마다의 계산·꼴은 프로세스 안에서 더 자세히 본다 / plugins/spec-distill/tests/test_conductor_branch.py — delete 의 확인 끝 대조(정도는 확인 못 함) / plugins/spec-distill/tests/test_leader_seat_e2e.sh — team 형식 상태 브랜치 끝에서 끝(걸음 11 과의 겹침 정도는 확인 못 함). 명령줄 배선과 두 기계 사이 push·fetch 는 이 파일만 본다
- 보안 갈래: 예
- 판정 후보: 둠 — 단위 테스트가 못 보는 CLI 배선·두 기계 흐름·「코드 브랜치를 건드리지 않음」 을 한 번 걷고, 23초는 그에 맞다
- 확신: 중간
- 확인 수: 약 27개 (동작 27 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — run() 이 약 30번 python 을 새로 띄우고, ensure·sync·send·ack·delete 는 그때마다 origin 에 push 한다. 걸음 11 의 team_repo 가 레포를 하나 더 세운다. 기다림(sleep)은 없다
- 구조 고치기 여지: 없음 — 걸음 11(team 형식)이 test_leader_seat_e2e.sh 와 겹치면 그쪽으로 옮길 수 있으나 확인 못 함

### plugins/spec-distill/tests/test_conductor_status.py
- 초: 126.3
- 줄 수: 441
- 고친 횟수: 8
- 크기: 큼 — StatusRepo 케이스마다 원격+클론+로드맵 커밋에 표지·상태 브랜치(커밋+push)를 세우고, sync 마다 커밋+push 하며, 일부 케이스는 둘째 클론을 만든다
- 종류: 섞임(동작 약 100 · 구조 약 12 · 글자 0 · 변이 0)
- 지키는 것: 원격에 올라가는 STATUS 가 정해진 꼴(절 차례·계산 줄)로 쓰이고 그 꼴만 읽히며, 질문 본문·로컬 경로·홈 경로·기계 이름·세션 id 가 실리지 않고, 낡지 않았으면 다시 커밋하지 않으며(한 시간 문턱), 다른 세션·다른 기계가 내 표지 뒤에 쓴 현황을 알리고, 기다리는 질문의 「질문 창」 줄은 다음 sync 에서 내려가고 「턴 끝」 줄은 남으며, 표지를 쥔 세션만 쓴다(rc 5).
- 거짓 실패 위험: 중간 — Shape.test_sections_order_and_empty_lines 가 STATUS 전체 글을 통째 비교해 절 제목·빈 줄 하나만 바꿔도 깨진다(다만 그 꼴은 기계 사이 계약이다). 알림 문장(「달라진 것이 없다 — 쓰지 않았다」 등) assertIn 도 몇 개
- 겹침: plugins/spec-distill/tests/test_conductor_cross.py — waiting_add·sync 와 STATUS 나이 줄을 화면 쪽에서 본다 / plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh — sync·waiting add·STATUS 편지 줄을 명령줄로 다시 본다 / 파일 안 — Scrub 의 경로 가리기 사례가 Shape.test_what_must_not_ride_does_not 의 scrub 단언과 일부 겹친다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(원격에 사적 정보가 실리지 않음·꼴 계약)은 분명하나 케이스당 약 3.4초가 준비에 들고, 순수 함수 케이스까지 같은 준비를 한다
- 확신: 중간
- 확인 수: 약 112개 (동작 약 100 · 구조 약 12 · 글자 0 · 변이 0) — 케이스 37
- 시간을 쓰는 곳: 추정 — StatusRepo.setUp 이 케이스마다 StateRepo(git 약 10번) + claim + CB.ensure(상태 브랜치 커밋+push). 케이스 안 sync 가 그때마다 build_status(상태 계산) + 커밋+push 하고 test_no_commit…·test_another_session… 는 sync 를 4–5번 부른다. other_machine_syncs 는 클론 하나를 더 만들고 거기서 ensure+sync 한다. cli() 케이스는 python 을 새로 띄운다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — Scrub 세 케이스는 CS.scrub(텍스트, 경로)만 부르는데 StatusRepo 를 물려받아 상태 브랜치를 세운다 → 레포 없는 TestCase 로(self.w 대신 임시 폴더 경로). Shape.test_other_shapes_are_refused·test_read_back… 는 push 없이 build_status→render_status 로 글을 만들 수 있다. 준비 함께 쓰기 — 상태 브랜치가 선 레포를 한 번 만들고 케이스마다 복사

### plugins/spec-distill/tests/test_control_plane.sh
- 초: 67.3
- 줄 수: 750
- 고친 횟수: 28
- 크기: 큼 — 멈춘 git·멈춘 상태 계산·닫히지 않는 입력에 시간 상한까지 기다리고, 변이 사본 18개를 cp -R 로 만들며, 30MB 파일을 두 번 쓰고 상태 파일 201개를 두 번 만든다
- 종류: 섞임(동작 약 160 · 구조 약 3 · 글자 약 7 · 변이 약 20)
- 지키는 것: 상태줄·지도가 결과를 캐시해 상태 계산을 다시 부르지 않되 브랜치·origin/main·로드맵·PR 캐시가 바뀌면 다시 계산하고, 끄기 스위치(DEVBREW_SPEC_DISTILL_DISABLE·DEVBREW_SKIP_HOOKS)로 조용히 꺼지며, 작업 트리를 쓰지 않고(읽기 전용), 멈춘 git·상태 계산·입력·파이프·큰 파일에도 시간 예산 안에 끝나며 하위 프로세스를 남기지 않고, 링크된 인터뷰 폴더·FIFO 를 따라가지 않으며, gh 없이 PR 캐시만 읽고, fork·다른 base PR 을 고르지 않는다.
- 거짓 실패 위험: 높음 — 시간 문턱(within 2.5·3·6·8초, statusline 예산 3초)이 기계 부하에 흔들리고, 상태줄 전체 글(LINE·LINE2)을 통째 비교해 조각 문구를 바꾸면 수십 단언이 함께 깨진다
- 겹침: plugins/spec-distill/tests/test_control_plane.py — 상태줄·지도 줄의 모양을 순수 함수(statusline_text 등)로 본다 / plugins/spec-distill/tests/test_default_branch.sh — 상태줄 시간 예산(statusline_stays_in_budget)과 대역 scripts 사본·기본 브랜치 이름 줄을 같은 꼴로 다시 만든다 / plugins/spec-distill/tests/test_conductor_ledger.py — 「설정 폴더가 다른 레포」 절의 후보 목록을 Roadmaps 클래스가 다시 본다 / 파일 안 — 변이 블록 둘(374–413, 493–529, 그 뒤 fp·cancel·short·rec_*)이 앞 단언을 다시 돌린다(의도된 이빨 확인)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(끄기 스위치·읽기 전용·멈추지 않음)은 분명하나 초의 절반 이상이 기다림이고, 변이 블록은 상한보다 길게 기다린다. 기다림 상한을 줄이고 변이 블록을 떼면 지키는 것은 그대로 싸진다
- 확신: 중간
- 확인 수: 약 190개 (동작 약 160 · 구조 약 3 · 글자 약 7 · 변이 약 20)
- 시간을 쓰는 곳: 추정 — 기다림이 가장 크다: m-budget 변이(timed 10, 멈춘 git 은 30초 sleep → 10초 꽉 채움), m-nonblock 변이(timed 10 → TIMEOUT 10초), 멈춘 git·멈춘 상태 계산 원본(예산 3초씩), 닫히지 않는 입력(sleep 4 두 번, 원본·m-stdin), cancel_run 두 번(최대 5초 폴링+0.3초). 합쳐 30–40초로 본다. 다음은 변이 사본 18개 cp -R, 30MB 상태 파일 두 번 쓰기, 상태 파일 402개 만들기, sl/show 호출마다 python+대역 실행(수십 번), push_file 마다 다른 사본 commit+push+fetch
- 구조 고치기 여지: 더 싼 확인으로 내리기 — m-budget 은 6초 문턱만 넘기면 되니 timed 7 로, m-nonblock 은 원본이 6초 안이니 timed 7 이하로(각 3초 이상 절약). 나누기 — 변이 블록(AC11·멈춤 변이·rec_*)을 따로 떼어 덜 자주 돌리거나 한 파일로, 캐시·끄기·읽기 전용·PR 캐시·README 절을 파일 여럿으로(750줄·28번 고침). 준비 함께 쓰기 — test_default_branch.sh 의 대역 scripts 사본 만들기를 공용 헬퍼로

### plugins/spec-distill/tests/test_default_branch.sh
- 초: 13.5
- 줄 수: 172
- 고친 횟수: 8
- 크기: 큼 — 느린 원격 대역이 7초를 실제로 sleep 하고, 느린 config 대역(sleep 8)을 상태줄 예산(약 3초)까지 기다리며, 레포를 여섯 벌 세운다
- 종류: 섞임(동작 약 41 · 구조 약 2 · 글자 0 · 변이 0)
- 지키는 것: 기본 브랜치를 전체 참조 이름에서 통째로 뽑고(trunk·feature/x·로컬 origin/main 브랜치가 있어도 main), origin·origin/HEAD 가 없으면 고치는 명령을 알려 주며, 원격 기본 브랜치가 바뀌었으면 rc 5 로 멈추고(merge_check 도 멈춘다), 오프라인이면 로컬 값으로 알리고 가고, git config 실패를 「원격 없음」 으로 읽지 않으며, 원격 대조 상한이 10초이고 상태줄은 느린 git 에도 예산 안에서 끊긴다.
- 거짓 실패 위험: 중간 — slow_remote 는 7초 sleep 이 10초 상한 안에 드는지를 3초 여유로 보고, statusline_stays_in_budget 은 4.5초 문턱이라 부하에 흔들린다. 나머지는 rc·안내 명령 글자(git remote set-head origin --auto)로 낮음
- 겹침: plugins/spec-distill/tests/test_repo_defaults_git.sh — 레포 밖 default-branch rc 3 한 케이스 / plugins/spec-distill/tests/test_control_plane.sh — origin/HEAD 없음의 「기본 브랜치를 알 수 없다」·상태줄 멈춘 git 예산·상태줄의 「기본 브랜치 main」 조각, 대역 scripts 사본 만들기를 같은 꼴로 / plugins/spec-distill/tests/test_merge_check.sh — merge_check 의 기본 브랜치 대조(정도는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 13.5초 가운데 약 10초가 대역의 sleep 기다림이다. 상한 상수는 이미 inspect 로 핀했으니 실측 기다림을 짧게 할 길이 있다
- 확신: 낮음
- 확인 수: 약 43개 (동작 약 41 · 구조 약 2 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — slow_remote 의 sleep 7(통째로 기다림), statusline_stays_in_budget 의 sleep 8 대역을 예산 약 3초까지 기다림 — 합쳐 약 10초. 나머지는 mkrepo 여섯 번(init·commit·push·set-head)과 python 실행 약 20번
- 구조 고치기 여지: 더 싼 확인으로 내리기 — slow_remote 는 「상한이 7초보다 길다」 를 보이려고 7초를 실제로 기다린다. 상한 상수와 기본값은 remote_timeout_is_10 이 이미 핀하므로, 호출 자리가 그 상한을 넘기는지만 보면(예: 대역이 받은 timeout 인자 기록 또는 짧은 sleep + 상한 낮춘 사본) 기다림을 1–2초로 줄일 수 있다. 다만 상수를 실제로 쓰는지는 지금 이 실측만 본다 — 바꾸려면 대체 확인이 먼저다. 준비 함께 쓰기 — statusline_names_default 의 scripts 사본을 test_control_plane.sh 와 공용 헬퍼로

#### 읽지 못한 것 — deep-06

없음 — 묶음의 아홉 단위를 모두 끝까지 읽었다. 다만 겹침 칸의 test_leader_seat_e2e.sh·test_conducting_loop.sh·test_conducting_reference.sh·test_conductor_branch.py·test_merge_check.sh·test_roadmap_status.sh 는 머리말과 대상 이름만 찾아봤고 본문은 읽지 않아 겹치는 정도를 「확인 못 함」 으로 적었다.

## 묶음 deep-07

### plugins/spec-distill/tests/test_dispatch_profile_inline.sh
- 초: 22.0
- 줄 수: 477
- 고친 횟수: 15
- 크기: 큼 — SKILL 펜스 셋을 차가운 셸에서 셀 약 40번 돌리고(셀마다 python 6–9개), 비움 스크립트를 셸 둘 × 모양 11로 돌리며, 셀마다 상태 폴더를 python 둘로 도출한다
- 종류: 섞임(동작 85 · 구조 5 · 글자 10 · 변이 0)
- 지키는 것: 리뷰어 dispatch 에 프로필 경로가 아니라 내용이(must_catch 줄은 뺀 채) 실린다 · 프로필을 못 읽으면 dispatch 하지 않고 rc 1 · 지난 라운드 critic 출력을 비우되 링크 너머의 폴더 밖 파일은 건드리지 않는다 · 비우지 못한 것을 「비웠다」고 말하지 않는다 · brief 는 그 실패를 degrade 원장에 남긴다
- 거짓 실패 위험: 중간 — 대부분 rc · 파일 내용 단언이라 동작이 바뀔 때만 깨지지만, stderr 문구(「critic-<번호>.txt)을 비웠다.」 · 「STATE_DIR 도출 실패」)와 dispatch 절 산문 문구는 글자로 묶여 있어 다듬기만 해도 깨진다
- 겹침: plugins/spec-distill/tests/test_ledger_wiring.sh — profile-content 펜스의 spec_path 슬롯 배선 한 줄만 겹침. clear_critic_outputs.sh 를 지키는 다른 테스트는 못 찾음. 파일 안에서는 같은 모양(only · both · none · linked · hardlinked)의 비움을 Z(펜스 거쳐) · W(스크립트 직접) · request-framing Z 가 세 번 재고, X 의 errexit 모드가 plain 모드의 단언 전부를 되풀이한다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 비움 스크립트 모양 행렬(W)은 스크립트 자체 테스트로 떼고, 펜스 쪽 Z 는 셸마다 모양 하나(배선 확인)로 줄이면 지키는 것은 그대로다
- 확신: 중간
- 확인 수: 약 330개 (동작 290 · 구조 15 · 글자 25 · 변이 0)
- 시간을 쓰는 곳: 추정 — brief 펜스는 한 번에 python 을 7–9개 띄우는데 X(2 skill × 2 모드 × 3 셀 = 12) · Z(2 × 2 셸 × 3 모양 = 12) · wn(2)로 약 26번 돈다. seed_critic 이 셀마다 python 둘(state_path · docreview_state)을 띄워 약 28번(56개). W 는 셸 둘 × 모양 11 = 22번 스크립트 실행, request-framing 은 15번
- 구조 고치기 여지: 나누기 — W(비움 스크립트 모양 11 × 셸 2)를 clear_critic_outputs.sh 전용 테스트로 / 더 싼 확인으로 내리기 — Z 를 셸마다 모양 하나로(모양 처리는 W 가 이미 잰다), errexit 모드는 ok 셀 하나만 / 준비 함께 쓰기 — 상태 폴더 도출 결과를 셀 이름만 바꿔 재사용

### plugins/spec-distill/tests/test_epic_conductor_skill.sh
- 초: 28.3
- 줄 수: 241
- 고친 횟수: 18
- 크기: 큼 — 104–107행에서 다른 공유 락 테스트 8개(test_invocation_surface.sh · test_dispatch_disposition.sh 등)를 통째로 다시 돌린다. 나머지는 grep · 짧은 python
- 종류: 섞임(동작 10 · 구조 10 · 글자 75 · 변이 5)
- 지키는 것: epic-conductor SKILL 의 절차 문장(로드맵 고르기 · worktree 기준 · claim/release 펜스가 같은 펜스에서 sid 를 정하고 빈 값이면 멈춤 · 옛 PR 캐시면 reset→release→claim · 규모 공시가 지출 승인을 묻지 않음)과 integration-reviewer · relay-checker 가 쓰기 도구 없이 Read · Grep · Glob 만 갖는 것
- 거짓 실패 위험: 높음 — SKILL · relay-checker · conducting.md 의 긴 문장 수십 개를 글자 그대로 요구해 문장을 다듬기만 해도 깨지고, 다시 돌리는 공유 락 8개 중 하나가 빨개지면 이 파일도 같이 빨개진다
- 겹침: shared/tests/test_cost_disclosure.sh — 「### 4. 규모 공시」 절의 「지출 승인을 묻지 않는다」 · 「엔진의 재리뷰 상한까지」 문구를 같이 잰다. 다시 돌리는 shared/tests 의 8개 락은 스위트에서 따로도 돈다(완전 중복 실행). test_repo_literals.sh · test_research_claims_contract.sh · test_seed_agents.sh 도 같은 공유 락 이름을 부른다(같은 다시 돌리기 꼴일 수 있으나 열어 보지 않음)
- 보안 갈래: 예
- 판정 후보: 줄임 — 공유 락 8개 다시 돌리기(104–107행)를 빼면 시간 대부분이 사라지고, 그 락들은 스위트에서 스스로 돌아 지키는 것이 그대로다
- 확신: 높음
- 확인 수: 약 115개 (동작 10 · 구조 12 · 글자 88 · 변이 5)
- 시간을 쓰는 곳: 추정 — 시간 거의 전부가 공유 락 8개를 하위 bash 로 다시 돌리는 데 든다(각자 레포 전체를 훑는 락). 나머지 python -I 열 번 남짓과 grep 은 1–2초
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 공유 락 다시 돌리기를 지운다(스위트가 이미 돌린다). 글자 단언 가운데 펜스 구조(sid 가드 · release 수)는 이미 python 으로 잰다 — 나머지 산문 문구 단언은 동작이 아니라 줄이기 후보

### plugins/spec-distill/tests/test_finish_commit_roadmap.sh
- 초: 11.7
- 줄 수: 309
- 고친 횟수: 14
- 크기: 중간 — 케이스마다 bare origin + clone + 커밋 + push 로 임시 git 레포를 새로 만들어(28개) finishing.md 의 커밋 펜스를 돌린다. 재분해 펜스는 가짜 roadmap_write.py 로
- 종류: 섞임(동작 75 · 구조 0 · 글자 25 · 변이 0)
- 지키는 것: 분해된 인터뷰를 끝낼 때 brief · audit · 상태 파일과 로드맵 폴더가 한 커밋에 들어가고, 정해진 폴더 밖 · 대소문자만 다른 경로 · 밖으로 가는 링크 · 기본 브랜치 위면 커밋하지 않으며, 재분해 펜스가 사용자 말 · 경로 안의 명령을 셸로 실행하지 않고 글자 그대로 넘긴다
- 거짓 실패 위험: 중간 — 커밋 파일 목록 · 커밋 수 단언은 동작이 바뀔 때만 깨지지만, 출력 문구(「로드맵 폴더에 커밋할 파일이 없어 빼고 진행한다」 등)와 redecompose.md 의 문장 14개를 글자로 묶어 문구만 다듬어도 깨진다
- 겹침: plugins/spec-distill/tests/test_workspace_invariance.sh — 같은 interview-commit 펜스를 trunk 레포에서 한 번 실행한다(나누지 않은 일의 세 파일 커밋). plugins/spec-distill/tests/test_decompose_surface.sh — 같은 펜스의 §7 도출 · roadmap-check 호출을 글자로 잰다. 기본 브랜치 판정(6b–6e)은 test_default_branch.sh · test_repo_defaults_git.sh 가 해결자 쪽을 볼 것으로 보이나 열어 보지 않음
- 보안 갈래: 예
- 판정 후보: 둠 — 케이스마다 다른 경로 판정 · 링크 거부 · 주입 차단을 실제 git 위에서 재고, 28개 케이스에 약 12초라 비용이 맞다
- 확신: 중간
- 확인 수: 약 80개 (동작 58 · 구조 0 · 글자 22 · 변이 0)
- 시간을 쓰는 곳: 추정 — mk 가 케이스마다 git init --bare · clone · commit · push · set-head · switch 를 새로 띄운다(28번, git 하위 프로세스 약 9개씩). 펜스 한 번이 repo_defaults.py 를 몇 번 부르고 원격 대조(ls-remote)를 한다
- 구조 고치기 여지: 준비 함께 쓰기 — origin + 기능 브랜치까지 만든 레포를 한 번 만들고 케이스마다 cp -R 로 베끼면 git 초기화 · push 를 아낀다(설정 머리말이 다른 cfg-* · renamed · nohead · offline 만 따로)

### plugins/spec-distill/tests/test_finish_pr_merge.sh
- 초: 71.3
- 줄 수: 602
- 고친 횟수: 6
- 크기: 큼 — bash · zsh 두 번 전부를 돌리고, 한 번에 임시 레포(bare + 가짜 ssh 로 잇는 clone + 커밋 2개 + push) 23개와 펜스 실행 약 70번, 가짜 gh · sleep · mktemp 를 쓴다
- 종류: 섞임(동작 95 · 구조 2 · 글자 3 · 변이 0)
- 지키는 것: 분해된 인터뷰의 PR · 머지 펜스가 origin 레포의 PR 만 다루고, 물을 때의 끝 커밋에 묶어 머지하며, 검사 실패 · 30분 초과 · 머지 대기열이면 MERGED 라고 하지 않고, 요청 뒤 끊기면 다시 확인 펜스가 정해진 횟수만 읽어 판결하며, 인터뷰 · 로드맵 폴더 밖 파일이 섞이면 ONLY 를 내지 않는다 — 두 셸 모두에서
- 거짓 실패 위험: 중간 — 판결 줄 · gh 호출 기록 단언은 동작이 바뀔 때만 깨지지만, 사람 줄을 긴 문장 그대로 비교하는 단언이 많고 finishing.md 본문 문장 다섯 개를 글자로 묶었다. 가짜 sleep(0.05초)과 hang 의 kill 확인은 부하에 약간 흔들릴 수 있다
- 겹침: plugins/spec-distill/tests/test_gh_repo.py · test_gh_repo.sh — 펜스가 부르는 gh_repo.py 하위 명령의 단위 동작(열어 보지 않음). 14b 의 끝내기 커밋 펜스 실행은 test_finish_commit_roadmap.sh 와 겹친다. 파일 안에서는 23개 픽스처와 모든 케이스를 bash · zsh 로 두 번 되풀이한다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 셸에 따라 갈리는 자리(글롭 · 단어 쪼개기 · 한글 경로 · 끊김 신호)만 zsh 로 다시 돌리고, 레포 픽스처를 한 번 만들어 베끼면 지키는 것은 그대로 두고 시간이 크게 준다
- 확신: 중간
- 확인 수: 약 500개 (동작 470 · 구조 10 · 글자 20 · 변이 0)
- 시간을 쓰는 곳: 추정 — 셸 둘 × 픽스처 23 = mk 46번(가짜 ssh 를 거친 clone · push 포함), 펜스 실행 셸마다 약 70번(한 번에 gh_repo.py · repo_defaults.py 를 여러 번 띄우고 fetch 를 가짜 ssh 로). 머지 펜스의 「검사 없음」 다시 보기 · hang 의 120회 폴링이 가짜 sleep 을 수십~백여 번 띄운다
- 구조 고치기 여지: 나누기 — zsh 바퀴는 셸 감수 케이스(new · mixed · merge · cut · late 정도)로 줄인다 / 준비 함께 쓰기 — mk 결과(origin + seed · 인터뷰 커밋)를 템플릿으로 한 번 만들고 케이스마다 cp -R / 더 싼 확인으로 내리기 — 판결 갈래(신원 대조 · 이미 머지됨 대조 셋)는 gh_repo.py 단위 쪽에서 재고 펜스 쪽은 배선만

### plugins/spec-distill/tests/test_framing_raw_source.sh
- 초: 25.6
- 줄 수: 242
- 고친 횟수: 6
- 크기: 큼 — 검사 함수 framing_fails 를 실제 파일 1번 + 변이 사본 30번 = 31번 다시 돌리고, 한 번에 python 을 약 12개 · grep 서브셸을 약 80개 띄운다
- 종류: 섞임(동작 0 · 구조 5 · 글자 65 · 변이 30)
- 지키는 것: 모델이 읽고 따르는 원문 보존 · 비밀값 가리기 규약(쓰기 전에 가린다 · 가린 값은 보이지 않는다 · seed 에도 가린 글만 간다 · 구분 줄 꼴)이 request-framing SKILL · audit/seed 템플릿 · seed 프로필에서 빠지거나 뒤집히면 잡고, 템플릿 구분 줄 머리가 호스트 정규식(build_seed_inline_blob)과 맞으며 토큰 모양이 P21 정규식에 맞는지 본다
- 거짓 실패 위험: 높음 — 문장을 글자 그대로 요구하고 OVERLAP_PIN 은 SKILL 의 한 문단 전체를 바이트로 고정해, 문구를 다듬거나 줄을 다시 감기만 해도 깨진다
- 겹침: 같은 SKILL · 템플릿을 test_seed_trust_boundary.sh · test_framing_review_contract.sh · test_seed_review_profile.sh 등 9개 파일이 읽지만, 비밀값 가리기 절과 같은 문구를 확인하는 다른 테스트는 못 찾음
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 31번 다시 도는 검사를 python 한 프로세스로 옮기거나, 바뀌지 않은 파일의 절 추출 · 줄 이음을 한 번만 계산해 변이마다 재사용하면 변이 이빨은 그대로 두고 싸진다
- 확신: 중간
- 확인 수: 약 96개 (동작 0 · 구조 3 · 글자 63 · 변이 30)
- 시간을 쓰는 곳: 추정 — framing_fails 한 번에 join(python) 약 10번 + 모듈 import python 2번 + has 서브셸 약 80번. 이것이 31번(약 370 python). mutate 도 변이마다 python 하나(30번)
- 구조 고치기 여지: 더 싼 확인으로 내리기 — framing_fails 전체를 python 하나로(파일 다섯을 한 번 읽고 항목별 판정을 한 번에) / 준비 함께 쓰기 — 변이는 파일 하나만 바꾸므로 나머지 파일의 추출 결과를 캐시

### plugins/spec-distill/tests/test_framing_review_contract.sh
- 초: 15.1
- 줄 수: 718
- 고친 횟수: 20
- 크기: 중간 — SKILL 펜스를 뽑아 차가운 셸에서 약 40번 돌리고, 엔진 상태(docreview_state · docreview_route)를 python 으로 세운다. 사본은 sdbad 하나(scripts 통째 cp -RL)
- 종류: 섞임(동작 50 · 구조 3 · 글자 42 · 변이 5)
- 지키는 것: request-framing 리뷰 게이트 펜스가 실제로 — 사용자 문구 · 요약 안의 백틱 · $( ) 를 실행하지 않고, 문구 없는 drop 을 막고, 기록이 성공했을 때만 ask 를 닫고, 되돌리기 → 기록 → 기준 사본 교체 순서이며 어느 걸음이든 실패하면 seed · 기준 사본을 그대로 두고, 화면 조립이 실패해도 권장 없이 편집 줄 전부를 보인다
- 거짓 실패 위험: 중간 — 펜스 실행 단언은 동작이 바뀔 때만 깨지지만, 글자 단언 약 110개가 SKILL 문장 · 펜스 실행 줄을 글자 그대로 요구해 문구나 인자 꼴을 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_seed_edit_screen.sh · test_seed_edit_diff.sh · test_seed_review_log.sh · test_seed_provenance.sh — 펜스가 부르는 스크립트의 단위 동작(열어 보지 않음). test_framing_raw_source.sh 와 같은 SKILL 의 다른 절. 파일 안에서는 round_disc · final_disc 가 같은 단언 묶음을 두 번(의도된 두 자리)
- 보안 갈래: 예
- 판정 후보: 둠 — 주입 차단 · 기준 사본 보존 같은 동작을 펜스 그대로 재고, 270개 남짓 확인에 15초라 비용이 맞다
- 확신: 중간
- 확인 수: 약 270개 (동작 135 · 구조 8 · 글자 115 · 변이 12)
- 시간을 쓰는 곳: 추정 — 펜스 실행 약 40번(펜스마다 seed_edit_diff · seed_edit_screen · seed_review_log 를 2–4개 띄운다), id 를 꺼내는 python -c 한 줄이 열 번 남짓, 엔진 상태 준비(init · begin-round · prepare-recritic · finalize)가 두 벌. 차단 문장 변이 10개는 python 하나 + awk 셋씩
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 펜스 실행 줄의 인자 꼴 글자 단언(bash_lines 에 대한 assert_contains 약 25개)은 같은 펜스를 실제로 돌리는 아래 칸이 이미 동작으로 재는 것과 겹치는 부분이 있다(펜스별로 대조해야 확정). 그 밖에는 없음

### plugins/spec-distill/tests/test_human_gate.sh
- 초: 148.2
- 줄 수: 477
- 고친 횟수: 11
- 크기: 큼 — 팀 레포(bare origin + 로드맵 생성 python 3개 + claim)를 15번 새로 세우고, start_bundle.py 약 60번 · job_results.py 20번 · 사람 줄 적기 약 21번(번마다 python 3개) · push+fetch 약 68번을 한다
- 종류: 섞임(동작 95 · 구조 0 · 글자 5 · 변이 0)
- 지키는 것: 사람 승인 줄(spec 승인 · 계획 검토 · 흐름 승인 · 건너뜀 · 다시 시도)이 질문 창 기록과 대조를 지나지 못하면 시작 묶음 · 결과 대조가 멈추고(손으로 적은 줄 · 커밋 안 한 줄 · 세션 기록 없음 · 승인 뒤 본문 변경), 연속 실패 둘이면 멈추며, 머지된 계획은 어느 단계든 멈추고, 환경 변수로는 관문이 꺼지지 않는다
- 거짓 실패 위험: 중간 — rc 단언은 동작이 바뀔 때만 깨지지만, 멈춤 사유를 긴 문장 그대로 비교하는 단언(「계획 2 의 브랜치 feature/tm-e1b 가 아직 없다: …」 등)이 있어 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_human_judge.py — 관문 표 · missing · 건너뜀 · 다시 시도 · 꺼짐 판정 로직을 단위로 잰다. plugins/spec-distill/tests/test_human_gate_e2e.sh — 승인 없음 · 낡음 · 미룸 절만 변경 · 흐름 승인 · human-check 를 같은 도우미로 다시 잰다. plugins/spec-distill/tests/test_start_bundle.sh — 머지된 과제 멈춤 사유
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 15번 새로 세우는 팀 레포를 한 번 세워 베끼고, 관문 표 갈래(어느 줄이 없는지 · 계획 번호 · 건너뜀이 다른 관문을 열지 않음)는 human_judge 단위로 내리고 세 표면(시작 묶음 · 결과 대조 · human-check)마다 배선 확인만 남기면 싸진다
- 확신: 중간
- 확인 수: 약 175개 (동작 165 · 구조 0 · 글자 10 · 변이 0)
- 시간을 쓰는 곳: 추정 — start_bundle.py 한 번이 여러 브랜치 끝 · 세션 기록 · 결과 파일을 읽어 약 60번이 가장 크다. new_repo 15번(git init 둘 · python 4개 · commit · push), approved/human 약 21번(ask-head · session_fixture · record python 셋 + commit + push + fetch), push_br/push_main 약 68번(push + fetch 쌍), finish_attempt 6번(묶음 + 맞추기 + sync)
- 구조 고치기 여지: 준비 함께 쓰기 — new_repo 결과(origin.git + repo + claude 폴더)를 한 번 만들어 묶음마다 cp -R / 더 싼 확인으로 내리기 — 13 · 14 · 22–27 의 관문 표 · 시도 세기 갈래를 human_lines 단위 테스트로 / 나누기 — 결과 대조 묶음(H–P)과 시작 묶음 묶음(A–G)을 따로 돌려 병렬화 여지

### plugins/spec-distill/tests/test_human_gate_e2e.sh
- 초: 139.0
- 줄 수: 364
- 고친 횟수: 4
- 크기: 큼 — 팀 레포 한 벌 위에서 지어낸 줄 갈래 17개를 세 표면(start_bundle · job_results · human-check)으로 재고, 갈래마다 줄 심기 · 되돌리기 커밋과 push+fetch 를 한다. 옛 형식 레포를 하나 더 세운다
- 종류: 섞임(동작 95 · 구조 0 · 글자 5 · 변이 0)
- 지키는 것: ask-head → 질문 창 답 → record --human → 시작 묶음 → 결과 대조 → 상태 계산 → human-check 가 한 흐름으로 이어지고, 지어낸 승인 줄(손 줄 · 없는 항목 · 다른 과제 · 라벨 바꿈 · 같은 근거 두 번 · 판만 새것 · sdk-cli · 훅 · 빈 답 · 모르는 출처)을 세 표면 모두가 막으며, 깨진 human_gate 값은 관문을 열지 않고, 옛 형식 로드맵의 명령 · 출력은 그대로다
- 거짓 실패 위험: 중간 — rc · 판정 단언은 동작이 바뀔 때만 깨지지만, 세 표면의 사유 글 조각을 글자로 비교해 사유 문구를 다듬으면 갈래 17개가 함께 깨진다
- 겹침: plugins/spec-distill/tests/test_human_judge.py — Match.test_forged_lines_do_not_pass 가 같은 지어낸 줄 갈래(손 줄 · 없는 항목 · 다른 과제 · 라벨 · 훅 · sdk-cli · 모르는 출처 · 빈 답)의 판정을 단위에서 표로 잰다. plugins/spec-distill/tests/test_human_gate.sh — 13(낡음) · 14(미룸 절만) · 15–16(흐름 승인) 이 그쪽 9 · 11 · 15–16 과 같다
- 보안 갈래: 예
- 판정 후보: 줄임 — 지어낸 줄 판정은 단위 테스트가 이미 갈래별로 재므로, 세 표면 배선은 판정 종류마다 한 갈래(근거 없음 · 어긋남 · 확인 못 함)만 남기고 human_gate.sh 와 겹치는 13–16 을 덜어도 지키는 것이 그대로다
- 확신: 중간
- 확인 수: 약 300개 (동작 285 · 구조 0 · 글자 15 · 변이 0)
- 시간을 쓰는 곳: 추정 — trio 17번이 가장 크다(번마다 start_bundle · job_results · conductor_ledger human-check python 셋 + 줄 짓기 python(rend · hd · answer) + plant/unplant 커밋 · push+fetch 두 쌍). passes 2번(python 4개씩), 1절 흐름의 approved · finish_attempt · status, 3절 옛 형식 레포 세우기와 human_gate 설정 세 번 바꾸기(커밋 · push)
- 구조 고치기 여지: 더 싼 확인으로 내리기 — trio 갈래 대부분을 human_lines 단위(이미 있음)에 맡기고 세 표면에는 판정 종류별 한 갈래만 / 준비 함께 쓰기 — plant/unplant 의 push+fetch 대신 같은 커밋 위에서 세 표면을 부른 뒤 reset(원격이 필요한 표면만 push)

### plugins/spec-distill/tests/test_human_judge.py
- 초: 11.7
- 줄 수: 585
- 고친 횟수: 9
- 크기: 중간 — 한 프로세스 안의 unittest 지만 테스트마다 임시 git 레포를 새로 init 하고(SeededRepo 는 커밋 4개 = git 하위 프로세스 약 12개), 가짜 세션 기록 파일을 쓴다
- 종류: 섞임(동작 95 · 구조 5 · 글자 0 · 변이 0)
- 지키는 것: human_lines 의 판 찾기 · 꼴 판정 · 대조 판정 · 관문 표가 맞다 — 지어낸 승인 줄 갈래 20여 개가 지나지 못하고, 본문 아닌 절(미룸 · 결정 기록 · 구현 대조) 변경은 낡음이 아니며, 관문 표가 설정 · 환경을 읽지 않는다(구문 나무로 확인)
- 거짓 실패 위험: 낮음 — 판정 상수와 반환값을 비교해 동작이 바뀔 때만 깨진다. why 문구 일부를 assertIn 으로 본다
- 겹침: plugins/spec-distill/tests/test_human_gate_e2e.sh — 지어낸 줄 갈래를 세 표면에서 다시 잰다. plugins/spec-distill/tests/test_human_gate.sh — 관문 표 갈래를 start_bundle 을 거쳐 다시 잰다. 이 파일이 가장 싼 층이다
- 보안 갈래: 예
- 판정 후보: 둠 — 지어낸 줄 판정의 가장 싼 층이고 테스트마다 레포를 새로 두는 것은 커밋을 쌓는 테스트라 필요하다. 겹침은 위층(e2e · gate)을 덜어 풀 일이다
- 확신: 높음
- 확인 수: 약 230개 (동작 220 · 구조 10 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 39개 테스트마다 git init 과 SeededRepo 의 커밋 4개(add · commit · rev-parse = 하위 프로세스 12개)를 새로 띄운다. 판정 함수 자체가 git show · log 를 부른다
- 구조 고치기 여지: 나누기 — 레포가 필요 없는 테스트(RecordHeads.test_suffixed_titles_are_body · Gates.test_gate_table_is_fixed · test_gate_table_reads_no_settings_or_environment · test_expected_lines_from_traces · test_received_lines_follow_the_gate_table_by_stage)를 Repo 를 상속하지 않는 TestCase 로 옮기면 init · 커밋 4개를 아낀다(몇 초 이내)

#### 읽지 못한 것 — deep-07

없음 — 아홉 단위를 모두 끝까지 읽었다. 다만 겹침 칸에서 「열어 보지 않음」 이라고 적은 파일(test_gh_repo.py · test_gh_repo.sh · test_default_branch.sh · test_repo_defaults_git.sh · test_seed_edit_*.sh · test_seed_review_log.sh · test_seed_provenance.sh · test_repo_literals.sh 등)은 이름 검색으로만 찾았고 내용은 대조하지 않았다.

## 묶음 deep-08

### plugins/spec-distill/tests/test_human_record.sh
- 초: 61.6
- 줄 수: 394
- 고친 횟수: 7
- 크기: 큼 — 팀 레포 셋(team_repo · new_repo h · d)과 bare 원격 push, conductor_ledger.py · session_fixture.py 를 하위 프로세스로 약 150번
- 종류: 섞임(동작 90 · 구조 10 · 글자 0 · 변이 0)
- 지키는 것: 사람 승인 줄(spec 승인 · 계획 검토 · 걸음 건너뜀 · 흐름 승인)이 지휘 세션 기록의 실제 사람 질문 창 답에서만 적히고, 하위 agent · 곁가지 · 훅 · 알림 · 친 말 · 다른 과제/판/계획의 답이나 옛 인자(--approval · --line · flush)로는 적히지 않으며, 가를 수 없으면 3 과 끄는 길(human_gate: 끔)을 낸다 — 깨지면 지어낸 승인이 관문을 지난다.
- 거짓 실패 위험: 중간 — 출력 문구(「확인 못 함」 · 「이미 있어 쓰지 않았다」 · K22 의 처음과 끝 꼴 · 줄 전문)를 정확히 대조해 문구를 다듬으면 깨지고, 케이스가 차례에 기대(뒤 답이 앞 답을 가린다) 중간 하나를 바꾸면 뒤가 연쇄로 깨진다.
- 겹침: plugins/spec-distill/tests/test_human_judge.py — 사람 아닌 답 축(denied · sdk-cli · 모르는 entrypoint · 칸 없음 · 곁가지 · 하위 agent)을 같은 가짜 세션 기록으로 판정 쪽에서 잰다 / test_human_gate_e2e.sh — ask-head → record --human → human-check 한 바퀴 / test_conductor_ledger.py — --approval 거절과 ask-head · record 사용법 일부 / 파일 안: 27 사용법 루프와 28 · 29 · 34 가 「record --human 으로 보낸다」 를 되풀이.
- 보안 갈래: 예
- 판정 후보: 둠 — 승인 위조를 막는 쓰기 쪽 집행이고 케이스마다 축이 다르다. 8 · 9 루프는 test_human_judge.py 와 같은 분류 축이라 줄임 후보로 남긴다.
- 확신: 낮음
- 확인 수: 약 170개 (동작 155 · 구조 15 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 레포 셋을 새로 세우며 매번 roadmap_write.py original · create 를 돌린다. 케이스마다 session_fixture.py(answer)와 conductor_ledger.py(rec)를 python 으로 새로 띄우고(약 150회, 호출마다 git 을 여러 번 부름), 8 · 9 루프만 11 변형 × 2 회다.
- 구조 고치기 여지: 줄이기 — 8 · 9 루프의 11 변형을 결과 갈래(1 · 3)마다 대표 하나로 줄이고 나머지 축은 test_human_judge.py 에 맡긴다(같은 분류기를 쓰는지 먼저 확인). 준비 함께 쓰기 — h · d 절의 new_repo 둘을 team_repo 템플릿 한 벌의 복사로 바꾼다.

### plugins/spec-distill/tests/test_interview_raw_source_entry.sh
- 초: 13.6
- 줄 수: 248
- 고친 횟수: 3
- 크기: 중간 — 임시 폴더에 픽스처 레포 둘, state-file.md 펜스를 bash · zsh 로 5 갈래씩 실행, 변이 사본 10 묶음마다 판정 전체를 다시 돈다
- 종류: 섞임(동작 25 · 구조 0 · 글자 45 · 변이 30)
- 지키는 것: 인터뷰 진입 펜스가 raw_source.py 판결 줄을 갈래(seed+상태 · 잃은 기록 · 상태 없음 · seed 만 · 판결 없음)마다 맞게 내고 막지 않으며, pm-interview 문서 · 두 agent · steelman 이 seed 를 S1 · 사용자 원문으로 부르지 않는다 — 깨지면 인터뷰가 원자료 대신 모델이 줄인 seed 를 brief §6 의 사용자 원문으로 싣는다(펜스 부분은 동작, 나머지는 SKILL · state-file · seed-input · request-framing 의 문장).
- 거짓 실패 위험: 높음 — words 판정이 네 문서의 긴 문장 십여 개를 글자 그대로 찾아 문장을 다듬기만 해도 깨진다. 펜스 실행 판정은 동작이 바뀔 때만 깨진다.
- 겹침: test_raw_source.py · test_raw_source_text.py — raw_source.py locate 판결 자체 / test_raw_source_downstream.sh — 같은 픽스처로 하류 / test_conducting_interview_stage.sh — SKILL_LINE_CAP 정의처 / 이 파일은 그 판결을 부르는 skill 펜스와 문구만 맡아 겹침은 부분.
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 펜스 실행은 두되, 변이 10 묶음이 글자 변이에도 펜스 10회 실행을 다시 치르므로 변이 종류에 맞는 판정만 먹이면 같은 이빨이 싸진다.
- 확신: 중간
- 확인 수: 약 30개 (동작 10 · 구조 0 · 글자 10 · 변이 10)
- 시간을 쓰는 곳: 추정 — entry_fails 를 11번(실제 1 + 변이 10) 부르고 매번 펜스를 5 갈래 × 셸 2 = 10번 env -i 셸로 돌려 raw_source.py 를 띄운다(약 110회 python). 변이 7개는 글자 변이인데도 펜스 실행 10회를 함께 치른다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — bites 가 글자 변이에는 words 판정만, 펜스 변이(3개)에는 fence 판정만 돌게 나누면 펜스 실행이 약 110회 → 약 40회로 준다.

### plugins/spec-distill/tests/test_interview_state_flow.sh
- 초: 13.0
- 줄 수: 422
- 고친 횟수: 15
- 크기: 중간 — 임시 git 레포와 bare 원격 클론 약 20개, SKILL · finishing · reviewing-brief 펜스를 bash -c 로 실행
- 종류: 섞임(동작 60 · 구조 5 · 글자 35 · 변이 0)
- 지키는 것: 진입 판결(RESUME · REJECT · NEW-SEED · LEGACY)이 맞게 나고, 끝내기 커밋 펜스가 기능 브랜치에서만 brief · audit · 상태 파일(+ 바뀐 framing 기록 · seed)을 한 커밋으로 넣고 기본 브랜치 · detached · origin/HEAD 없음 · 링크 · 다른 저장소 링크 · 폴더 밖이면 커밋하지 않으며, reviewing-brief 머리가 degrade 원장을 상태 파일로 두고 링크(끊긴 것 포함)를 따라 쓰지 않는다 — 깨지면 인터뷰 산출물이 잘못 커밋되거나 링크 너머 파일이 덮인다.
- 거짓 실패 위험: 중간 — AC2 · AC3 · AC4 · B-1 · fix1/2 의 문구 grep(「이어 감 (권장)」 · 끝 질문 라벨 전문 등)과 AC5 의 문면 순서 검사는 문장을 다듬거나 절을 옮기면 깨진다. 펜스 실행 단언은 동작이 바뀔 때만 깨진다.
- 겹침: test_state_storage_e2e.sh — interview-state-entry · interview-commit · advice-ba · ledger-open 펜스를 같은 방식으로 실행 / test_finish_commit_roadmap.sh — interview-commit 펜스 / test_resume_candidate_names.sh — 진입 펜스 / test_ledger_wiring.sh — 링크된 .docreview 와 원장 열기.
- 보안 갈래: 예
- 판정 후보: 둠 — 펜스 실행 갈래마다 다른 자리(링크 · 저장소 밖 · 브랜치 판정)를 지키고 클론 수가 갈래 수에 맞다. 문구 grep 일부는 test_state_storage_e2e.sh 와 합칠 후보다.
- 확신: 중간
- 확인 수: 약 95개 (동작 55 · 구조 5 · 글자 35 · 변이 0)
- 시간을 쓰는 곳: 추정 — mk() 가 케이스마다 bare 원격 + clone + 빈 커밋 + push 를 새로 한다(c1–c8 · r1–r7 약 15회). 커밋 펜스 실행마다 state_path.py 등 python 이 여러 번 뜨고, reviewing-brief 머리 펜스 실행이 열 번 남짓이다.
- 구조 고치기 여지: 준비 함께 쓰기 — mk() 의 bare+clone 을 한 번 만들어 cp -R 로 복제(원격 경로는 set-url). 나누기 — AC2–AC4 · B-1 · fix1/2 문구 grep 을 싼 정적 파일로 떼어 낸다.

### plugins/spec-distill/tests/test_job_results.sh
- 초: 33.1
- 줄 수: 349
- 고친 횟수: 9
- 크기: 큼 — 팀 레포 + bare 원격 + 둘째 클론, 변이 브랜치 약 30개, job_results.py check 와 pyq · rcpt 를 python 으로 약 100번
- 종류: 섞임(동작 90 · 구조 10 · 글자 0 · 변이 0)
- 지키는 것: 결과 대조(check)가 끝 줄 · 머리 · head/bundle_at/job_at 커밋 · AC 범위 · 이름과 머리 어긋남 · 펜스 안 끝 줄 · BOM · 폴더 자리 · 더 새 시도를 거절이나 검사 불가로 가르고 통과할 때만 받음 줄을 내며, receipt 가 받은 뒤 변경(코드 · 설계 · 계획 · 다른 에픽 merge)으로 낡음을 잰다 — 깨지면 리더가 미완이거나 꾸민 결과를 받거나 낡은 받음을 센다.
- 거짓 실패 위험: 중간 — 거절 사유는 부분 문구로 보지만 첫 줄(FIRST · 「결과 대조: 거절 1건 — …」)과 receipt 출력(「상태|알림|이름」)을 전문으로 맞춰 문구를 다듬으면 깨진다.
- 겹침: test_team_results.py — job_results.check_result · failed_streak 를 mock 으로 / test_start_bundle.sh — 같은 check 를 끝에서 끝으로 한 번 / test_human_gate.sh · test_human_gate_e2e.sh — 결과 대조의 사람 줄 관문 / 파일 안: reject() 가 갈래마다 넷(rc · 사유 · 첫 줄 · 받음 줄 없음)을 되풀이.
- 보안 갈래: 아니오
- 판정 후보: 둠 — 갈래마다 다른 거절 사유를 지키고 변이 브랜치를 한 레포에서 싸게 만든다.
- 확신: 중간
- 확인 수: 약 170개 (동작 155 · 구조 15 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 팀 레포 준비(roadmap_write.py 둘 + human 두 번). 변이마다 python mutate + git commit(약 30회). jr · rcpt · pyq 마다 python 을 새로 띄워 roadmap_status · job_results 를 import 한다(약 100회).
- 구조 고치기 여지: 더 싼 확인으로 내리기 — pyq · rcpt 의 함수 단위 단언(약 45개)을 한 python 프로세스 안에서 돌린다. 줄이기(작음) — reject() 의 「첫 줄이 거절」 · 「받음 줄 없음」 은 몇 갈래에서만 잰다.

### plugins/spec-distill/tests/test_leader_seat.py
- 초: 92.2
- 줄 수: 789
- 고친 횟수: 11
- 크기: 큼 — 67 테스트가 각자 bare 원격 + 클론 + push + 표지 + 상태 브랜치 ensure(push)를 새로 만들고, foreign_edit 마다 둘째 클론을 더하며, CLI 칸은 conductor_branch.py 를 하위 프로세스로
- 종류: 섞임(동작 97 · 구조 3 · 글자 0 · 변이 0)
- 지키는 것: 상태 브랜치의 팀 규칙 사본을 다른 세션 · 클론의 고침이 확인되지 않은 동안 읽지도 쓰지도 않고(rules-add/drop/branch 거절 · 재지 못함으로 닫음 · 머지로 숨긴 고침 · 원격 재작성으로 세탁하지 않음), confirm 은 보인 끝으로만 확인하며, rules-branch 는 기본 브랜치 위 커밋 하나에 git 이 받지 않는 이름을 거절한다 — 깨지면 다른 세션이 심은 규칙이 담당자 묶음에 실린다.
- 거짓 실패 위험: 낮음 — 문구를 모듈 상수(LS.FOREIGN 등)로 대조해 문구 변경에 덜 깨진다. 다만 CB._push 를 mock 으로 갈아 끼우는 테스트(second_remake)는 내부 함수 이름이 바뀌면 깨진다.
- 겹침: test_leader_seat_e2e.sh — 남의 고침 알림 · confirm(8자 거절 포함) · rules-branch 갈라짐 · 꺼진 설정을 CLI 로 다시 잰다 / test_conductor_branch.py — rules-add 의 표지 거절 일부 / 파일 안: 남의 머지 커밋 만들기(old · mine · clone · commit-tree · push)가 네 테스트에 같은 코드로 되풀이된다.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 67번의 레포 세우기가 시간 대부분이다. 준비를 한 번 만들고 복제하면 같은 확인이 싸진다.
- 확신: 중간
- 확인 수: 약 250개 (동작 242 · 구조 8 · 글자 0 · 변이 0) — 67 케이스
- 시간을 쓰는 곳: 추정 — setUp 마다 git init --bare + clone + 커밋 + push + set-head + 로드맵 재작성 커밋 + 표지 + CB.ensure(상태 브랜치 push)로 git 프로세스 약 15–20번 × 67. foreign_edit(약 35회)마다 clone + fetch + claim + write(push)가 더해지고, ls() CLI 호출(약 30회)마다 python 을 새로 띄운다.
- 구조 고치기 여지: 준비 함께 쓰기 — setUpClass 에서 TeamRepo 완성 상태(원격 + 클론 + 상태 브랜치)를 한 번 만들고 테스트마다 copytree + remote set-url 한다. 남의 머지 커밋 만드는 네 벌을 도우미 하나로 모은다.

### plugins/spec-distill/tests/test_leader_seat_e2e.sh
- 초: 75.9
- 줄 수: 446
- 고친 횟수: 10
- 크기: 큼 — 팀 레포 다섯(new_repo a–e), 둘째 클론 넷, start_bundle · roadmap_status · conductor_branch · conductor_status · conductor_ledger 를 하위 프로세스로 약 100번
- 종류: 섞임(동작 95 · 구조 5 · 글자 0 · 변이 0)
- 지키는 것: 규칙 사본 → 시작 묶음의 규칙 머리 · --rules-at → job sync 의 rules_at → 상태 계산 「묶음 낡음」 의 이음매, 남의 고침이면 묶음이 알림을 싣고 기본 브랜치 규칙을 읽음, sync 가 같아진 사본을 지우고 갈라짐을 알림, flush 가 확인된 보통 줄만 옮김, 꺼진 설정은 R1 출력 그대로 — 깨지면 담당자가 확인 안 된 규칙으로 일하거나 리더가 낡은 결과를 받는다.
- 거짓 실패 위험: 중간 — 출력 줄 전문(「규칙 (<B> · 팀 규칙은 <TIP>):」 · pending 출력 네 줄 · R1 글 그대로)을 맞춰 문구를 다듬으면 깨지고, 걸음이 앞 걸음의 상태에 기대 연쇄로 빨개진다.
- 겹침: test_leader_seat.py — 남의 고침 거절 · confirm · rules-branch 갈라짐 · 꺼진 설정을 함수 단위로 / test_human_gate_e2e.sh — 같은 team_repo 준비 / test_conductor_branch.py — rules-add · pending / 파일 안: 걸음 22(①)가 걸음 3–6 의 rules-add → 묶음 → sync → 낡음을, 걸음 23(②)이 걸음 10 · 17 · 18 · 20 의 남의 고침 → 알림 → confirm → flush 를 새 레포에서 되풀이한다.
- 보안 갈래: 예
- 판정 후보: 줄임 — 걸음 22 · 23 은 같은 파일 앞 걸음과 같은 이음매를 새 레포에서 다시 돌고, 레포 다섯 가운데 c · d 는 앞 레포에 이어 붙여도 지키는 것이 같다.
- 확신: 중간
- 확인 수: 약 180개 (동작 170 · 구조 10 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — new_repo 다섯 번(각각 roadmap_write.py 둘 + 공통 문서 push + claim). approved 가 레포마다 두 번(ask-head · session_fixture · record 를 각각 python 으로). 걸음마다 bundle · status · cb · csync 를 python 으로 새로 띄우고(약 100회, roadmap_status 는 git 을 많이 부름) 둘째 클론을 넷 만든다.
- 구조 고치기 여지: 준비 함께 쓰기 — team_repo 결과를 한 번 만들어 cp -R(원격 경로 맞춤)로 레포를 복제한다. 줄이기 — 22 · 23 을 앞 걸음 확인에 흡수하고 c · d 레포를 앞 레포에 잇는다.

### plugins/spec-distill/tests/test_ledger_wiring.sh
- 초: 36.2
- 줄 수: 1099
- 고친 횟수: 39
- 크기: 큼 — 임시 git 레포 약 12개와 worktree 하나, skill 펜스를 bash -c 로 수십 번 실행, 정적 스캐너를 문서 · 프로브마다 python 으로 새로 띄움(약 80번)
- 종류: 섞임(동작 50 · 구조 10 · 글자 40 · 변이 0)
- 지키는 것: 리뷰 원장 표지(reviewing-by)를 원장 열기 펜스가 HELD · OTHER · NO_SESSION · NO_DIR 로 가르고, 남의 표지 · 표지 없음이면 쓰기 전 확인이 rc 3 으로 멈춰 원장을 그대로 두며, 엔진 쓰기 하위 명령 앞마다 표지 확인이 있고(문서 전수 정적 검사), 링크된 .docreview · 상태 루트 · audit 를 따라 쓰지 않고, 결정 줄 · 경로 · 추가 승인 말의 따옴표 · 명령 치환이 셸로 새지 않는다 — 깨지면 두 세션이 한 원장을 덮어쓰거나 사용자 말이 명령으로 실행된다.
- 거짓 실패 위험: 중간 — 펜스 실행 단언은 낮다. 정적 검사 일부(문단의 「표지 확인 줄 다음에만」 · 「원장 쓰기 전 확인.」 문단 머리 · path-inside 관문 줄 n ≥ 19 · 경로 대입 줄 SITES 목록)는 문구 · 펜스 개수가 바뀌면 깨진다.
- 겹침: test_state_storage_e2e.sh — reviewing-brief 원장 열기 HELD · OTHER · NO_DIR · 넘겨받기 · 쓰기 전 확인 / test_ledger_root.sh — 다른 레포 cwd(AC15) 원장 열기 / test_ledger_marker.py — 표지 스크립트 단위 / test_interview_state_flow.sh — 링크된 .docreview 의 두 번째 채널 / test_ask_material_wiring.sh — 원장 열기 / 파일 안: spec-review · reviewing-brief · request-framing 세 skill 에 HELD · OTHER · NO_DIR · 두 줄 표지 · A1 정리 칸을 같은 꼴로 세 번 되풀이.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 보안 경계라 두되, 프로브마다 python 을 새로 띄우는 정적 스캐너를 한 프로세스 일괄로 바꾸고 정적 검사와 펜스 실행을 나누면 싸고 덜 깨진다.
- 확신: 중간
- 확인 수: 약 260개 (동작 130 · 구조 25 · 글자 105 · 변이 0) — 글자 쪽은 스캐너 판정과 그 스캐너의 음성 · 양성 프로브 약 70개
- 시간을 쓰는 곳: 추정 — ac8_scan · ac12_prose_scan 이 도출 문서마다, 그리고 음성 · 양성 프로브마다 python -I 를 새로 띄운다(약 80회). 펜스 실행마다 docreview_state.py · ledger_marker.py · ledger_sweep.py · state_path.py 가 여러 번 뜨고, 임시 레포 git init 약 12회와 worktree add 한 번이 있다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 프로브를 목록으로 한 번에 넘겨 python 한 프로세스에서 판정한다. 나누기 — 정적 검사(AC8 스캔 · AC12 산문 · AC14 문면)와 펜스 실행(표지 · 결정 줄 · B-A · 링크 관문)을 두 파일로. 준비 함께 쓰기 — 세 skill 에 같은 칸을 도는 부분을 skill 목록 루프 하나로 묶는다.

### plugins/spec-distill/tests/test_merge_check.sh
- 초: 28.5
- 줄 수: 375
- 고친 횟수: 22
- 크기: 큼 — 장면마다 bare 원격 + 클론(약 22개), merge_check 가 일회용 worktree 둘(기본 · 합친)에서 pytest · unittest · node · 셸 테스트를 실제로 돌림, 잠금 장면의 --wait 1 이 1초 기다림
- 종류: 섞임(동작 90 · 구조 10 · 글자 0 · 변이 0)
- 지키는 것: 스위트 대조가 기본 브랜치와 합친 사본의 러너별 실패 이름을 갈라 새 실패만 rc 1 로 내고, 이름을 못 뽑으면 단위 수준(rc 4) · 테스트 없음 7 · 러너 없음 6 으로 가르며, 기계 상태에 적힌 test_command(하위 agent 가 쓸 수 있는 파일)를 읽지 않고, 공유 스위트 잠금 · 충돌 · 갈라진 브랜치 끝을 바르게 다룬다 — 깨지면 머지 전 확인이 새 실패를 놓치거나 하위 agent 가 심은 명령으로 통과한다.
- 거짓 실패 위험: 중간 — 출력 문구(「양쪽 다 있는 실패 1개: …」 · 출처 표기 전문)를 부분 대조해 문구 변경에 깨진다. 이 기계에 pytest 가 없으면 장면 1 · 1b 가 실패로 찍힌다(node 없음은 따로 다루지 않음).
- 겹침: test_conductor_e2e.sh — merge_check run 한 번(끝에서 끝) / test_suite_lock.py — 잠금 단위 / test_default_branch.sh — merge_check 의 기본 브랜치 판정 / 파일 안 되풀이는 못 찾음.
- 보안 갈래: 예
- 판정 후보: 둠 — 장면마다 다른 러너 · 갈래이고 두 사본을 실제로 돌리는 것이 이 도구의 동작 자체다.
- 확신: 중간
- 확인 수: 약 125개 (동작 115 · 구조 10 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 장면마다 mkrepo(bare + clone + push)와, mc 가 worktree 둘을 만들어 테스트 명령을 두 번 실행한다(pytest 기동이 장면당 수백 ms). 잠금 장면 --wait 1 이 1초. 함수 단위 확인(names_in · neutral · branch_tip)도 python 을 따로 띄운다.
- 구조 고치기 여지: 더 싼 확인으로 내리기(작음) — 10 · 10b · 10c · _is_ancestor · _git 의 함수 단위 확인 약 7개를 python 한 프로세스로 모은다. 그 밖에는 없음.

### plugins/spec-distill/tests/test_parallel_recommend.py
- 초: 29.9
- 줄 수: 773
- 고친 횟수: 13
- 크기: 큼 — git 을 쓰는 테스트 약 35개가 각자 bare 원격 + 클론 + 로드맵 push 를 새로 만들고, worktree · push · merge 와 roadmap_status.py · control_plane.py 하위 프로세스를 돌림
- 종류: 동작
- 지키는 것: 공유 파일 설정(shared_files)이 로드맵 층을 무시하고 레포 설정으로만 겹침 판정 · 경로 예약 위반 알림을 바꾸며, 「동시에 갈 수 있는 준비 에픽」 줄이 의존 · 실제 겹침이면 빠지고, 이웃 에픽 결정 줄과 review-pack intents.md 가 머지 시점(설계 전/후 · 스쿼시 · 빨리 감기 · 지운 브랜치 · 쌓인 브랜치)에 따라 함께 진행된 에픽 설계문서를 싣거나 빼고 확인 못 하면 표시한다 — 깨지면 지휘자가 겹치는 에픽을 병렬로 권하거나 이음매 리뷰어가 엉뚱한 의도를 받는다.
- 거짓 실패 위험: 낮음 — 출력 줄을 테스트 상수(LINE · COUNT_LINE 등)로 대조해 동작이 바뀔 때 주로 깨진다. 다만 상수가 스크립트와 따로 적혀 있어 문구를 바꾸면 함께 고쳐야 한다.
- 겹침: test_parallel_recommend_docs.sh — 같은 기능의 문서 쪽 / test_conductor_cross.py · test_workspace_invariance.sh — shared_files 설정 일부 / test_roadmap_status.sh — 상태 계산 일반(이름 검색까지만 확인).
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 테스트마다 같은 원격 + 로드맵 준비를 새로 만들고 다섯 갈래 기능이 한 파일에 섞여 있다. 준비 복제와 나누기로 싸진다.
- 확신: 중간
- 확인 수: 약 130개 (동작 130 · 구조 0 · 글자 0 · 변이 0) — 55 케이스
- 시간을 쓰는 곳: 추정 — RoadmapRepo.setUp 마다 git init(bare + 작업)과 로드맵 커밋 · push(테스트당 git 약 8회). start_design 마다 worktree add + 커밋 + push. status() · tasks() · pack 마다 roadmap_status.py 등 python 을 새로 띄운다. IntentsPack 은 setUp 에서 로드맵까지 만든다(18 테스트).
- 구조 고치기 여지: 준비 함께 쓰기 — 로드맵(TWO · THREE) push 까지 끝난 원격 + 클론을 setUpClass 에서 한 번 만들고 테스트마다 copytree. 나누기 — git 이 필요 없는 클래스(SharedFilesSetting 대부분 · Overlaps · ParallelLineUnit · DecisionLines · IntentsBuildUnit)를 git 클래스와 떼어 낸다.

#### 읽지 못한 것 — deep-08

없음 — 다만 test_ledger_wiring.sh 의 도출 대상 문서 수는 git ls-files 를 직접 돌리지 않아 어림(약 십여 개)이고, test_human_record.sh 의 「같은 분류기」 겹침은 conductor_ledger.py 가 human_lines(HL.match)를 import 하는 것까지만 확인했다.

## 묶음 deep-09

### plugins/spec-distill/tests/test_repo_literals.sh
- 초: 11.8
- 줄 수: 253
- 고친 횟수: 17
- 크기: 중간 — 임시 폴더에 대상 사본을 만들어 python 스캐너를 100번 넘게 새로 띄운다(git 이나 러너는 안 씀)
- 종류: 섞임(동작 0 · 구조 25 · 글자 3 · 변이 137)
- 지키는 것: 지휘자 skill · reference · 스크립트 24개에 이 레포에서만 맞는 값(main · feature/ · docs/superpowers · 모델 이름)이 새어 들어가지 않게 막고, `git add --` 로 경로를 정하는 펜스가 add 앞에서 check-path · roadmap-check 판정을 거치게 한다 — 깨지면 다른 레포에서 지휘자가 엉뚱한 브랜치 · 경로를 쓰거나, 판정 안 받은 경로를 커밋한다.
- 거짓 실패 위험: 중간 — 대상 문서에 따옴표 친 상수 값이나 `fix/` 꼴 예시 문장을 넣기만 해도 깨진다. shape_mut 의 sed 식이 request-framing SKILL · finishing.md 의 정확한 줄(`    RDIR=""` 등)에 묶여 있어서, 그 줄을 다듬으면 「사본이 그대로다」 로 RED 가 난다.
- 겹침: shared/tests/test_dispatch_disposition.sh — 처분 앵커 줄 꼴(면제 범위의 전제)은 저쪽이 맡는다 / plugins/spec-distill/tests/test_request_framing_entry.sh · test_finish_pr_merge.sh · test_decompose_surface.sh — check-path 를 실행해 보지만 펜스 꼴 검사는 이 파일에만 있다 / 파일 안: 「대상마다 변이」 루프(24개)와 「한 번에 전부 스캔」 루프(24개)가 같은 것(대상이 실제로 읽히는지)을 두 번 잰다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 변이·음성 대조 100여 개가 줄마다 python 을 따로 띄운다. 스캐너를 함수로 두고 한 프로세스 안에서 문자열 변이를 돌리면 지키는 것은 그대로다. 「대상마다 변이」 와 「전체 한 번 스캔」 은 하나로 줄일 수 있다.
- 확신: 중간
- 확인 수: 약 165개 (동작 0 · 구조 25 · 글자 3 · 변이 137)
- 시간을 쓰는 곳: 추정 — `scan`/`shape` 를 부를 때마다 `python3 -I -` 를 새로 띄우고 heredoc 스크립트 · repo_defaults · test_finishing_block_scope 를 다시 import 한다. 대상별 변이 24회, 문구 변이 · 음성 대조 약 40회, 상수 변이, shape_mut 약 30회로 python 이 100번 넘게 뜬다. mut 할 때마다 대상 파일을 cp 한다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — scan · shape 의 python 을 모듈 하나로 빼고, 변이 목록을 한 번의 python 실행에 넘겨 메모리 안 사본으로 판정한다. 나누기 — 리터럴 스캔과 펜스 꼴(R8 AC4)은 서로 다른 축이라 파일을 나눌 수 있다.

### plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh
- 초: 14.1
- 줄 수: 217
- 고친 횟수: 5
- 크기: 중간 — SKILL 펜스를 잘라 `env -i` 차가운 셸에서 9번 실행한다. 칸마다 가짜 플러그인 루트 · 임시 HOME 을 두고, 원장 init · profile-check 를 python 으로 부른다.
- 종류: 섞임(동작 24 · 구조 6 · 글자 2)
- 지키는 것: reviewing-brief 의 탐지 dispatch 가 프로필 web 값과 끄기 스위치 DEVBREW_SPEC_DISTILL_DISABLE_WEB 에 따라 웹 사본(doc-critic-web)과 웹 없는 사본 중 맞는 것을 고르는지 지킨다. 스위치가 켜졌는데 웹 사본을 고르거나, 프로필을 읽지 못했을 때 웹 쪽으로 새거나, 내려간 사실이 degrade 원장에 남지 않으면 깨진다.
- 거짓 실패 위험: 낮음 — 펜스를 실행한 결과로 판정한다. 마커(`critic-select:begin`) · `## 입력` 절 이름 · advisory 문구(「웹 비활성(…)」)를 바꿀 때만 깨진다.
- 겹침: plugins/spec-distill/tests/test_web_kill_switch.sh — 스위치 확인 블록이 있는지 · 프로필이 web: true 인지를 글자로 보고, 실행은 이 파일에 맡긴다고 적어 두었다 / plugins/spec-distill/tests/test_reviewing_brief_skill.sh — 웹 공시 문면과 doc-critic-web 의 tools 를 본다(겹침은 작다)
- 보안 갈래: 예
- 판정 후보: 둠 — 끄기 스위치의 「정확히 "1" 만 참」 · fail-closed 방향을 실행으로 재는 유일한 자리다. 칸 9개는 축(S1–S5 · errexit)마다 하나씩이라 되풀이가 적다.
- 확신: 중간
- 확인 수: 약 32개 (동작 24 · 구조 6 · 글자 2 · 변이 0)
- 시간을 쓰는 곳: 추정 — 칸 9개가 칸마다 `## 입력` 블록(원장 init python)과 선택 펜스(profile-check python · degrade-append)를 처음부터 다시 돈다. 전제 확인에서 profile-check 를 python 으로 3번 더 띄운다.
- 구조 고치기 여지: 준비 함께 쓰기 — 칸마다 같은 `## 입력`(원장 init)을 다시 도는데, 원장을 한 번 만들고 칸마다 복사하면 줄일 여지가 있다. 이득은 작다.

### plugins/spec-distill/tests/test_reviewing_brief_residue.sh
- 초: 47.9
- 줄 수: 889
- 고친 횟수: 18
- 크기: 큼 — 세션 id 56개마다 임시 HOME · 가짜 플러그인 루트 · 스텁 러너를 두고, codex-gate 펜스를 `env -i` 셸에서 60번 넘게 실행한다. 권한 잠금(chmod 444/555) 칸과 bash · xpg_echo bash · zsh 의 셸 3종을 쓴다.
- 종류: 섞임(동작 118 · 구조 10 · 글자 5 · 변이 2)
- 지키는 것: reviewing-brief 의 codex 게이트가 건너뛰는 모든 길(끄기 스위치 · 미설치 · 번들 부재 · 감지기 부재 · 모델 판단 건너뜀)에서 직전 라운드 codex 산출물을 지우거나 0바이트로 만드는지 지킨다. 이번 라운드 산출물은 지우지 않아야 하고, 지우지 못하면 residue_unclearable 로 공시해야 하며, 모델이 적은 이유 글이 셸 명령으로 실행되면 안 된다. 깨지면 지난 라운드 finding 이 이번 판정으로 섭취되거나, 사용자가 끈 codex 축이 켜진 것으로 보고된다.
- 거짓 실패 위험: 중간 — 대부분 디스크 사후상태로 판정한다. 다만 공시 문구 grep(「codex 리뷰를 건너뛰었다 (reason: …)」 · K2 의 한 줄 전문 assert_eq)과 RS 문면 칸(vc_rc 표의 source_mismatch 행 두 문장 전문)은 SKILL 문장을 다듬기만 해도 깨진다.
- 겹침: plugins/spec-distill/tests/test_reviewing_spec_residue.sh — 축 A · A+ · A! · D · A2 · A3 · E · P · S 가 같고 하니스 코드(스텁 러너 · bin 자리표 · fire/where · e_case · unknown_payload_case)를 거의 그대로 복사했다. D · A2 · A3 의 하류 판정(prepare-recritic 의 codex_absent · codex_predates_round)은 펜스가 아니라 엔진 동작이라 두 파일이 같은 것을 잰다. 이 파일의 P×자리 칸은 spec-review 의 `## 입력` · 펜스까지 실행한다.
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하다. 다만 spec 쪽 residue 와 하니스 · 엔진 하류 칸이 겹치고, 세션 id 검사와 `where` 도출이 같은 sid 에 python 을 여러 번 띄운다. 공용 하니스로 모으고 엔진 하류 칸을 한 번만 두면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 135개 (동작 118 · 구조 10 · 글자 5 · 변이 2)
- 시간을 쓰는 곳: 추정 — ① 전제 루프가 sid 56개마다 state_path.py session-id 와 docreview_state.py state-dir-for 를 python 으로 따로 띄운다(약 112회). ② fire 가 부를 때마다 `where`(python)를 다시 부르고 펜스를 `env -i` 셸에서 실행한다. 펜스 안에서도 detect_codex.sh · state_path · docreview_state 가 python 을 여러 번 띄운다(60여 회 × 여러 python). ③ open_round · ingest 가 칸마다 init · begin-round · prepare-recritic · json 파싱 python 을 따로 띄운다. ④ K 칸이 bash · xpg_echo bash · zsh 로 같은 펜스를 되풀이한다.
- 구조 고치기 여지: 준비 함께 쓰기 — test_reviewing_spec_residue.sh 와 함께 쓰는 하니스 lib(스텁 러너 · fire · e_case · unknown_*_case)로 빼고 SKILL 경로만 매개로 받는다. 더 싼 확인으로 내리기 — sid 전제 검사와 `where` 를 python 한 번으로 모아 캐시한다. 나누기 — 엔진 하류 칸(D · A2 · A3 · Q)은 docreview_route 단위 테스트 한 곳에만 두고, H(따로 도는 블록) · K(모델 건너뜀)는 별도 파일로 나누면 병렬로 돌릴 수 있다.

### plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh
- 초: 8.5
- 줄 수: 615
- 고친 횟수: 19
- 크기: 중간 — 펜스 5종을 잘라 `env -i` 셸에서 실행한다. 스텁 review_entry.py 를 칸마다 새로 쓰고, 임시 git 레포 7개를 만들어 커밋을 십여 개 쌓는다. 바깥 호출은 없다.
- 종류: 섞임(동작 95 · 구조 12 · 글자 3)
- 지키는 것: spec-review 진입 펜스가 review_entry.py 의 잘못된 출력(rc≠0 · 비-JSON · 스키마 위반 · 개행 주입 · 검사기 자체 실패)을 전부 「끔」(fail-closed)으로 읽는지 지킨다. 그 밖에 끄기 스위치를 이름으로 대는지, 플러그인 루트를 풀지 못했을 때 사용자 저장소 cwd 의 미끼 스크립트를 실행하지 않는지, 상태 디렉토리를 문서마다 따로 도출하는지, 미커밋 · untracked 문서를 깨끗하다고 읽지 않는지, 후보 목록이 실재하는 절대 경로만 내는지도 본다.
- 거짓 실패 위험: 낮음 — 실행한 펜스의 출력으로 판정한다. 복귀 지시 문장(RETURN_MSG 전문)과 「진입 검사 실패(끔으로 친다)」 같은 문구는 전문으로 대조하므로, 그 문장을 다듬을 때 깨진다.
- 겹침: plugins/spec-distill/tests/test_review_entry.py — review_entry.py 의 스위치 판정(DISABLE · DESIGN_MODE_DISABLE · SKIP_HOOKS)을 단위로 잰다. 이 파일의 「정본 end-to-end」 칸 5개와 겹친다 / plugins/spec-distill/tests/test_reviewing_spec_residue.sh · test_reviewing_brief_residue.sh — `## 입력` 의 STATE_DIR 문서별 도출(P1–P5)과 겹친다
- 보안 갈래: 예
- 판정 후보: 둠 — 입력 검증의 fail-closed · 주입(개행으로 PROCEED 줄 위조) · cwd 미끼 미실행을 실행으로 재는 자리다. 8.5초에 확인 110개로 비용에 맞다.
- 확신: 중간
- 확인 수: 약 110개 (동작 95 · 구조 12 · 글자 3 · 변이 0)
- 시간을 쓰는 곳: 추정 — 스텁 행렬 약 20칸이 칸마다 python 으로 스텁을 쓰고 펜스를 실행한다(펜스 안 python 검사기 포함). 후보 펜스 칸이 임시 git 레포 6개를 새로 init 하고 커밋을 칸마다 6–7번 쌓는다. 설치본 흉내가 python 으로 치환 사본을 4번 만든다.
- 구조 고치기 여지: 준비 함께 쓰기 — 후보 펜스 칸의 git 레포(cand5 · cand-rm · cand-space)를 레포 하나에 차례로 쌓아 쓸 여지가 있다. 이득은 작다.

### plugins/spec-distill/tests/test_reviewing_spec_residue.sh
- 초: 14.1
- 줄 수: 565
- 고친 횟수: 14
- 크기: 큼 — 세션 id 21개마다 임시 HOME · 가짜 플러그인 루트 · 스텁 러너를 두고, codex-gate 펜스를 `env -i` 셸에서 20번 넘게 실행한다. 권한 잠금 칸이 있다.
- 종류: 섞임(동작 42 · 구조 4)
- 지키는 것: spec-review 의 codex 게이트가 건너뛰는 길마다 직전 라운드 codex 산출물을 지우거나 0바이트로 만들고, 이번 라운드 산출물은 살리는지 지킨다. 지우지 못하면 residue_unclearable 로 공시하는지, 문서를 모르면 다른 문서의 산출물을 건드리지 않는지도 본다. 깨지면 설계문서 리뷰가 지난 라운드 codex finding 을 이번 판정으로 섭취한다.
- 거짓 실패 위험: 낮음 — 디스크 사후상태와 하류 prepare-recritic 출력으로 판정한다. 공시 문구 「codex 리뷰를 건너뛰었다 (reason: …)」 를 바꿀 때 깨진다.
- 겹침: plugins/spec-distill/tests/test_reviewing_brief_residue.sh — 같은 축(A · A+ · A! · D · A2 · A3 · E · P · S)과 거의 같은 하니스 코드다. 저쪽 P×자리 칸이 이미 spec-review 의 `## 입력` + 펜스를 실행해 자리를 관측하고, D · A2 · A3 의 엔진 하류 판정은 두 파일이 같은 것을 잰다.
- 보안 갈래: 예
- 판정 후보: 합침 — 펜스는 달라도 축 · 하니스 · 엔진 하류 칸이 brief 쪽과 같다. 한 하니스에 SKILL 을 매개로 넘겨 두 펜스를 돌리면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 46개 (동작 42 · 구조 4 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 전제 루프가 sid 21개마다 python 을 2번 띄운다(약 42회). run_fence 가 부를 때마다 dir_of(python)를 부르고 펜스를 실행한다(펜스 안 python 여러 번). mk_state · downstream 이 칸마다 init · begin-round · prepare-recritic · json 파싱 python 을 따로 띄운다.
- 구조 고치기 여지: 준비 함께 쓰기 — brief residue 와 공용 하니스 lib 로 모은다. 더 싼 확인으로 내리기 — sid 전제 검사를 python 한 번으로, 엔진 하류 칸(D · A2 · A3)은 엔진 단위 테스트 한 곳으로 옮긴다.

### plugins/spec-distill/tests/test_roadmap_status.sh
- 초: 92.2
- 줄 수: 1992
- 고친 횟수: 75
- 크기: 큼 — 임시 bare origin · 작업 레포 둘에 git 을 400번 넘게 부르고(push · fetch 포함), roadmap_status.py 를 75번 실행한다. 모든 git 호출 앞에 bash 래퍼(fakebin-origin)가 끼고, 변이를 위해 스크립트 폴더(71개 .py)를 25번 넘게 통째로 복사한다.
- 종류: 섞임(동작 355 · 구조 10 · 글자 25 · 변이 45)
- 지키는 것: 로드맵 상태 계산이 에픽 단계(머지됨 · 일부 머지 · 구현 중 · 계획 · 설계 중 · 대기 · 준비)를 git 이력 · PR 캐시 · 적은 PR 번호 · 결정 기록으로 맞게 매기는지 지킨다. 경고 · 정보 · 검사 불가(rc 3)를 빈 결과로 뭉개지 않는지, 이 스크립트가 쓰기 · 네트워크 · gh · 허용 밖 git 을 하지 않는지(읽기 전용)도 본다. 깨지면 지휘자가 머지 안 된 에픽을 머지됨으로 보고 다음 에픽을 열거나, 상태줄이 저장소를 바꾼다.
- 거짓 실패 위험: 중간 — 단계 판정은 동작으로 재서 안정적이다. 그러나 ① §7 실데이터 칸은 실제 로드맵(docs/superpowers/roadmaps/2026-10-11-…)의 겹침 목록 전체를 긴 리터럴로 고정해, 그 문서나 locks.md 를 고치면 깨진다. ② README · 템플릿 · NOTICE · `## 한계` 의 문장 전문 대조(U8A · U8B 등)는 문구를 다듬기만 해도 깨진다. ③ ctl_reader 변이는 conductor_state.py · gh_repo.py 의 정확한 줄(`def own_version() -> str:` 등)에 묶여 있어 그 줄이 바뀌면 「변이 적용 안 됨」 으로 깨진다.
- 겹침: plugins/spec-distill/tests/test_roadmap_status_merge_base.py — merge-base 실패의 셀 수 없음 / test_roadmap_render.py · test_roadmap_model.py · test_roadmap_migrate.py · test_entry_guidance.sh — 같은 실제 로드맵(2026-10-11-persistent-explore-pm-decompose)을 읽는다 / test_merge_check.sh · test_conductor_branch.py — GIT_ALLOWED 꼴 검사 / test_control_plane.py · test_team_status.sh 등 — roadmap_status 를 소비자로 부른다 / 파일 안: 정적 읽기 전용 검사(§5)와 행동 읽기 전용 검사(ro_probe)가 「쓰기 · 허용 밖 git 없음」 을 두 길로 잰다(의도된 이중이지만 둘 다 비싸다)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 핵심이고 크다. 다만 한 파일에 갈래가 열 가지 넘게 섞여 직렬로 92초를 쓴다. JSON 필드 하나마다 python 을 새로 띄우는 js 호출이 287번이고, 변이마다 스크립트 폴더를 통째로 복사한다. 갈래별로 파일을 나누고 판정을 한 python 에서 모으면 지키는 것은 그대로다.
- 확신: 중간
- 확인 수: 약 435개 (동작 355 · 구조 10 · 글자 25 · 변이 45)
- 시간을 쓰는 곳: 추정 — ① roadmap_status.py 75회 실행. 실행마다 git 하위 프로세스를 수십 번 띄우는데, 그때마다 fakebin-origin bash 래퍼를 거쳐 fork 가 두 배가 된다. ② stage/warns/notes/reason/js 헬퍼가 assert 하나마다 python 을 띄워 같은 JSON 을 다시 읽는다(287회, 수십 ms 씩). ③ 픽스처 git 이력 쌓기 — `g` 호출 428회와 push/fetch. ④ ctl_reader · ro_variant 가 변이마다 scripts/*.py 71개를 새 폴더에 복사하고, static_check 가 AST 로 모듈 16개 이상을 다시 파싱한다(약 28회). ⑤ ro_probe 가 `chmod -R` 와 `find | shasum` 으로 작업 트리 전체를 앞뒤로 해시한다(4회).
- 구조 고치기 여지: 나누기 — 이력 단계 판정(§1–§4 · R5) / 읽기 전용 정적 검사와 그 변이(§5 · ctl_reader · net_check) / PR 캐시 · 번호 판정(R8 AC14– · R14) / 실데이터(§7) / 공시 문면을 파일로 나누면 병렬로 돈다. 더 싼 확인으로 내리기 — 보고서 하나를 python 한 번에 읽어 여러 식을 판정한다(js 287회 → 보고서 수만큼). static_check 변이는 메모리 안 소스 문자열로 판정해 폴더 복사를 없앤다. 준비 함께 쓰기 — fakebin-origin 래퍼는 `remote get-url origin` 에만 필요하므로, 그 칸에만 PATH 를 두르면 나머지 git 호출의 래퍼 비용이 빠진다.

### plugins/spec-distill/tests/test_roadmap_write.sh
- 초: 17.5
- 줄 수: 535
- 고친 횟수: 16
- 크기: 중간 — 임시 git 레포 하나와 bare origin 을 두고, roadmap_write.py 를 45번쯤 실행한다. 검사기(roadmap_status.py)도 10번쯤 실행한다.
- 종류: 섞임(동작 135 · 구조 2 · 글자 3)
- 지키는 것: 분해안 표로 로드맵 · 묶음을 만들고(create) 다시 나눌(update) 때 지키는 것들이다 — 검증이 실패하면 덮어쓴 파일을 원래 바이트로, 지운 파일을 되살린다. 생성 기록 밖의 파일 · 남의 파일을 덮어쓰지 않는다. 머지되거나 끝난 에픽은 바꾸지 않는다. 번호는 빈틈없이 잇는다. 위험 · RC 번호를 brief 줄에 맞게 배정한다. 깨지면 재분해가 사용자의 손 파일이나 머지된 에픽의 묶음을 덮어쓰거나, 실패한 생성이 반쯤 쓴 폴더를 남긴다.
- 거짓 실패 위험: 중간 — 대부분 rc · 바이트 비교 · 나무 비교로 판정한다. 그러나 132줄의 digest 단언은 create 출력 나무 전체의 sha256 을 고정해, 묶음 · 로드맵 템플릿의 글자 하나만 바꿔도 깨진다. 알림 줄 문구 전문 대조도 있다.
- 겹침: plugins/spec-distill/tests/test_roadmap_write.py — 되돌리기 바이트 복원(test_rollback_restores_bytes) · 생성 기록 왕복(test_round_trip) · 검사기 목록 판정이 이 파일의 「되돌리기」 · 「다시 생성」 칸과 겹친다 / test_roadmap_write_atomic.py — 원자 쓰기 / test_team_write.sh · test_finish_commit_roadmap.sh · test_decompose_surface.sh — roadmap_write 를 소비자 쪽에서 부른다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 실패 시 되돌리기 · 남의 파일 보호 · 머지된 에픽 거부를 CLI 끝에서 끝으로 재는 자리다. 17초에 확인 140개로 비용에 맞다. digest 고정은 따로 손볼 거리다.
- 확신: 중간
- 확인 수: 약 140개 (동작 135 · 구조 2 · 글자 3 · 변이 0)
- 시간을 쓰는 곳: 추정 — roadmap_write.py 를 칸마다 python 으로 새로 띄운다(약 45회 · extract 포함). four_empty 가 roadmap_status.py(git 하위 프로세스 여러 번)와 판정용 python 을 함께 띄운다(9회). snap 이 폴더를 통째로 cp -R 하고 diff -r 로 대조한다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 132줄 digest(나무 전체 해시 고정)는 R1 AC3 의 일회성 바이트 동일 확인이었으니, 골든 파일 대조로 바꾸거나 지울지 검토한다. 나머지는 없음.

### plugins/spec-distill/tests/test_seed_edit_screen.sh
- 초: 18.5
- 줄 수: 598
- 고친 횟수: 11
- 크기: 중간 — 임시 폴더만 쓴다. 칸마다 seed_edit_diff.py · seed_edit_screen.py · docreview_state.py 를 python 으로 새로 띄우고, 확인 하나마다 판정용 python 을 또 띄운다.
- 종류: 섞임(동작 158 · 구조 2)
- 지키는 것: 저자 편집 승인 화면이 바뀐 문장만 보이는지(꼴 1–4 · 자리 옮김 · 문단 나눔), 원장에서 사용자가 고치기로 처분한 지적을 댄 덩어리에만 (권장)을 붙이는지 지킨다. 원장 · 이유 파일 · 쓴 지적 목록이 없거나 깨지거나 판본이 다르면 권장 없이 그 사실을 보여야 하고, 질문은 넷까지 묶여야 하며, mark-used 는 번호를 전수 대조한 뒤에만 써야 한다. 깨지면 사용자가 틀린 편집에 (권장)을 보고 승인하거나 바뀐 문장을 놓친다.
- 거짓 실패 위험: 중간 — 화면 글의 문구를 전문으로 대조하는 칸이 많다(「저자 편집 1곳 — 달라진 문장만 보입니다」 · 권장 뜻 줄 · 설명 문장 · 110자 길이). 문구나 설명 길이 기준을 다듬으면 여러 칸이 함께 깨진다.
- 겹침: plugins/spec-distill/tests/test_seed_edit_diff.sh — 덩어리(hunks) 생성 쪽, 같은 j 헬퍼 꼴 / plugins/spec-distill/tests/test_framing_review_contract.sh · test_state_dir_writes.sh — seed_edit_screen 을 부르는 계약 · 상태 폴더 쓰기 쪽(겹침은 작다) / 파일 안: AC2 표 루프의 inv · shown 이 덩어리마다 python 을 두 번 더 띄워 같은 JSON 을 다시 읽는다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 분명하다. 다만 확인 160개 대부분이 `j` 로 같은 screen.json 을 python 을 새로 띄워 읽는다. python unittest 로 옮기거나 한 번에 여러 식을 판정하면 지키는 것은 그대로이고 훨씬 싸다.
- 확신: 중간
- 확인 수: 약 160개 (동작 158 · 구조 2 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — ① `j`/`rec`/`qs`/`form_bad` 가 assert 하나마다 python 을 새로 띄워 screen.json 을 다시 연다(약 200회). ② `mk` 가 칸마다 seed_edit_diff.py 를, `scr` 가 seed_edit_screen.py 를 python 으로 띄운다(각 70회쯤). ③ AC2 표 25줄마다 inv · shown 이 python 을 2번 더 띄운다. ④ 원장 fixture 를 엔진 CLI(init · begin-round · prepare-recritic · finalize · decide · ask)로 python 을 15번 넘게 띄워 만든다. mk2 가 원장 사본을 칸마다 cp -R 한다.
- 구조 고치기 여지: 더 싼 확인으로 내리기 — seed_edit_screen · seed_edit_diff 를 import 하는 python unittest 로 옮겨 build_screen 을 한 프로세스에서 부른다. 셸로 남기려면 screen.json 하나에 식 목록을 넘겨 python 한 번에 판정한다. 준비 함께 쓰기 — 원장 fixture(L · LS)는 이미 한 번 만들어 복사하므로 그대로 둔다.

#### 읽지 못한 것 — deep-09
없음

## 묶음 deep-10

### plugins/spec-distill/tests/test_seed_gate_wiring.sh
- 초: 29.8
- 줄 수: 341
- 고친 횟수: 26
- 크기: 중간 — request-framing 의 상태 · 번들 · 산출물 기록 · codex 게이트 펜스를 잘라 `env -i` 차가운 셸로 약 38번 돌리고, 케이스마다 임시 홈 폴더와 가짜 플러그인 루트 · 러너 스텁을 쓴다
- 종류: 섞임(동작 90 · 구조 10 · 글자 0 · 변이 0)
- 지키는 것: request-framing 의 셸 블록을 실제로 돌렸을 때 seed 마다 엔진 자리가 갈리고, 재비판 번들에 판정 이력이 새지 않고, 직전 라운드 산출물(critic · recritic · codex yaml)이 이번 라운드 것으로 넘어가지 않고, kill switch · 번들 부재 · rc 3 에서 러너를 부르지 않거나 껍데기를 치우며, bash · zsh · bash 3.2 와 `set -euo pipefail` 아래에서도 같은 결과를 내는지 지킨다 — 깨지면 seed 리뷰가 낡은 산출물을 이번 판정으로 쓰거나 꺼 둔 codex 가 돈다
- 거짓 실패 위험: 중간 — SKILL 의 헤딩(`## 상태` · `### 번들` · `### 산출물 기록`) · codex-gate 표지 · `TOPIC="<kebab-topic>"` 줄 모양을 바꾸면 추출이 깨진다(chk_blk 가 이름 붙여 먼저 빨개진다), stderr 공시 문구를 grep 한다
- 겹침: plugins/quality-gates/tests/test_codex_gate_observation.sh — 같은 codex 펜스를 가용 · kill switch · 미설치로 돌려 호출 수를 센다(이 파일은 호출 수가 못 보는 사후 상태만 잰다고 머리에 밝힘) · plugins/spec-distill/tests/test_seed_codex_axes.sh — 같은 SKILL 의 codex 게이트 표지 · 러너 호출을 글자로 본다 · 파일 안에서 산출물 기록 세 사례(old · det · none)를 bash · zsh · bash 3.2 로 세 번 되풀이(셸별 결함을 잡으려는 의도)
- 보안 갈래: 예
- 판정 후보: 둠 — kill switch 공시 · 직전 산출물 중화처럼 읽어서는 못 잡는 결함을 실행으로 잡고, 셸 행렬도 실제로 셸마다 다른 결함(zsh 빈 글롭 · bash 3.2 문법)을 겨눈다
- 확신: 중간
- 확인 수: 약 54개 (동작 49 · 구조 5 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 차가운 셸 실행 약 38번이 저마다 상태 블록(python docreview_state state-dir-for · interview_state 등)과 번들 조립 python 을 다시 띄우고, 케이스마다 `place()` 가 python 을 한 번 더 띄운다; zsh · bash 3.2 행렬이 그 가운데 12번
- 구조 고치기 여지: 준비 함께 쓰기 — 케이스마다 `home()` 새 폴더와 `place()` python 을 부르는데 B(모양 × 셸) · K(셸) 사례는 같은 sid 의 자리를 한 번 계산해 다시 쓸 수 있다(작은 이득 · 차가운 셸 실행 자체는 측정 대상이라 그대로)

### plugins/spec-distill/tests/test_seed_trust_boundary.sh
- 초: 14.8
- 줄 수: 756
- 고친 횟수: 6
- 크기: 중간 — 임시 폴더 하나에서 check_seed · seed_provenance · seed_review_log · build_seed_inline_blob 을 케이스마다 하위 프로세스로 띄운다(python 실행 약 350번)
- 종류: 동작
- 지키는 것: 사용자 · 리포 · 모델이 심을 수 있는 seed 본문 · audit 본문(전각 · 제로폭 · setext · HTML · 줄 나눔 글자 · 위장 꼬리 · 펜스 안 제목 · ## 6 위조 줄 · --title 줄바꿈 · --quote 줄임 인자)이 게이트를 통과하거나 «(사용자 확인)» 출처를 얻거나 audit ## 6 의 사용자 문구로 둔갑하지 못하고, 정직한 산문 · 표 · 펜스는 통과하는지 지킨다 — 깨지면 지어낸 문장이 사용자 확인으로 하류에 넘어간다
- 거짓 실패 위험: 중간 — 막힘을 거부 메시지 접두 문구(`[check_seed] seed 에 산문이 아닌 구조가 있다 —` · `[seed_provenance] …` · `[seed_review_log] …`)로 재서, 그 문구를 다듬으면 수십 케이스가 함께 깨진다; 판정 자체는 동작에만 반응한다
- 겹침: plugins/spec-distill/tests/test_seed_grammar_crosscheck.py — 난수 씨앗으로 만든 수백 개 표기 조합으로 seed 본문(check_seed.gate · marks · classify)과 audit ## 6(parse_lines · user-quotes · check-drops)의 거부 일치를 프로세스 안에서 재고 CLI 배선도 몇 개 본다 — 이 파일의 S2 gate 61 케이스 · 표시 변형 12 · ## 6 허용 목록 5 와 같은 축 · plugins/spec-distill/tests/test_check_seed.sh(61줄) · test_seed_provenance.sh · test_seed_review_log.sh 는 같은 스크립트의 기본 동작을 재며 이 파일의 우회 케이스는 grep 으로 못 찾음
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 손으로 적은 우회 회귀 목록은 보안 경계라 남기되, 케이스마다 python 둘 이상을 새로 띄우는 대신 한 프로세스 안에서 import 해 부르면 같은 것을 지키며 싸진다
- 확신: 중간
- 확인 수: 약 190개 (동작 190 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — gate 케이스마다 픽스처 쓰기 python(`w`) + check_seed python 두 번 띄움(61 + audit 12), 표시 변형 루프는 케이스마다 python 다섯(×12), 줄 나눔 글자 루프는 일곱(×5), ## 6 허용 목록 루프는 여섯(×5); 프로세스 시작 비용이 거의 전부다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — gate 61 · audit 12 · 표시 변형 12 · 줄 나눔 5 · ## 6 허용 목록 5 케이스를 python 한 프로세스에서 check_seed · seed_provenance · seed_review_log 함수를 불러 재고(test_seed_grammar_crosscheck.py 방식), CLI rc · 첫 줄 문구 배선은 대표 몇 개만 하위 프로세스로 남긴다

### plugins/spec-distill/tests/test_spec_review_bundle.sh
- 초: 6.8
- 줄 수: 214
- 고친 횟수: 12
- 크기: 중간 — bare + clone 임시 git 레포 하나에 브랜치 여섯과 머지를 세우고 spec_review_bundle.py 와 SKILL 펜스를 하위 프로세스로 약 35번 돌린다
- 종류: 섞임(동작 80 · 구조 7 · 글자 13 · 변이 0)
- 지키는 것: spec-review 의 --bundle 이 설계문서 source_interview 와 같은 파일일 때만 통과하고(표기 넷 · 거부 넷), 진입 번호 대조 경고 수 · 로드맵 위치 · 의존 이웃의 사용자 결정 줄 · 깨진 이웃의 「셀 수 없음」 · 기각 번호 목록을 내며, 스크립트가 없을 때 펜스가 실패를 말하고 통과하는지 지킨다 — 깨지면 엉뚱한 묶음을 정답 출처로 리뷰하거나 이웃 결정을 못 본다
- 거짓 실패 위험: 중간 — SKILL `## 입력` · `## 게이트` · `## degrade 채널` 의 문장(예: 「진입 펜스가 낸 `질문 줄:` 뒤의 글을 …」)을 글자로 찾아 문장만 다듬어도 8개가 깨진다; 스크립트 출력은 문장 전체 일치(assert_eq)
- 겹침: plugins/spec-distill/tests/test_team_review_entry.sh — 같은 entry 의 PROCEED · REFUSE 를 team 형식(INTENT.md)으로 잰다(입력 꼴이 달라 대신하지 못함) · plugins/spec-distill/tests/test_bundle_short_line.sh — entry 의 `질문 줄:` 짧은 줄
- 보안 갈래: 아니오
- 판정 후보: 둠 — 비용이 작고 대부분 스크립트 · 펜스를 실제로 돌린다; 글자 확인 8개는 모델이 읽는 지시문이라 실행으로 바꿀 길이 없다
- 확신: 중간
- 확인 수: 약 70개 (동작 57 · 구조 5 · 글자 8 · 변이 0)
- 시간을 쓰는 곳: 추정 — 픽스처 레포 세우기(브랜치 여섯 · 커밋 · 머지 · push 약 25번의 git 실행)와 spec_review_bundle.py python 약 35번(neighbors 는 안에서 git show 를 여러 번 부른다)
- 구조 고치기 여지: 없음

### plugins/spec-distill/tests/test_start_bundle.sh
- 초: 64.7
- 줄 수: 464
- 고친 횟수: 18
- 크기: 큼 — 팀 레포를 두 번 세우고(bare origin + 작업 트리) 브랜치 십여 개 · commit/revert/push 왕복 약 30번 · start_bundle 약 60번 · 승인 줄(세션 기록 · 원장 python) 다섯 번을 돈다
- 종류: 동작
- 지키는 것: 리더 묶음과 과제 묶음(design · plan · implement · review)이 작업 폴더가 아니라 origin/main · 과제 브랜치의 커밋 글만 싣고, 예산 초과 · 규칙 파일 없음은 알리고 역할 문서 없음 · 기본 브랜치 모름 · 갈라짐 · 머지된 단순 작업 · 깨진 INTENT 머리 · 같은 이름 과제 둘은 멈추며(1 · 3 구분), 시도 번호 · 읽을 것 · 맞추는 명령(셸에 붙여도 한 낱말)과 끝에서 끝 흐름이 맞는지 지킨다 — 깨지면 일꾼이 낡거나 남의 글로 일을 시작한다
- 거짓 실패 위험: 중간 — 묶음 줄을 줄 번호(`line 5`)와 문장 전체 일치로 재서 줄 순서나 문구를 바꾸면 여러 단언이 함께 깨진다; 레포 상태를 걸음마다 이어받아 앞 걸음의 되돌림이 어긋나면 뒤가 연쇄로 빨개진다
- 겹침: plugins/spec-distill/tests/test_human_gate.sh — 같은 start_bundle 의 관문 멈춤 · human_gate 끔 알림(check 88곳) · plugins/spec-distill/tests/test_leader_seat_e2e.sh — 상태 브랜치 규칙 사본 → 시작 묶음 규칙 → 맞추는 명령 --rules-at → job sync 끝에서 끝(이 파일의 AC31 · 끝에서 끝과 일부 겹침) · plugins/spec-distill/tests/test_team_sync.sh — job sync 자체
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 한 파일이 레포 상태를 차례로 이어받으며 64초를 쓴다; 이미 떨어진 갈래(리더 · 과제 · 멈춤 · 끝에서 끝)로 나누면 병렬로 돌고 연쇄 실패도 준다
- 확신: 중간
- 확인 수: 약 220개 (동작 220 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 팀 레포 세우기 두 번(roadmap_write original · create python + git 십여 번), start_bundle python 약 60번(각자 브랜치 · team_status 를 읽으며 git 을 여러 번 부른다), main 을 바꾼 걸음마다 commit · push · fetch 와 revert · push 왕복, approved 마다 ask-head · session_fixture · led record python 셋, job new python 여섯
- 구조 고치기 여지: 나누기 — 리더 묶음(①–⑧ · AC31 · I2) / 과제 묶음(implement · plan · design · review · 시도 번호) / 멈춤 다섯과 머지된 단순 작업 / 끝에서 끝(이미 새 레포)으로 갈라 병렬로; 사용법 오류 11개(rc 2)는 레포를 바꾸지 않으니 한 준비 위에 모으고, ①②③⑤ 처럼 main 을 바꿨다 되돌리는 걸음은 브랜치에서 갈라 재면 revert · publish 왕복이 준다

### plugins/spec-distill/tests/test_state_dir_writes.sh
- 초: 11.7
- 줄 수: 783
- 고친 횟수: 12
- 크기: 중간 — 임시 폴더 · 임시 git 레포 하나에서 상태 스크립트를 하위 프로세스로 돌리고, SKILL 셋의 bash 펜스 69개를 테스트 안 python 렉서와 /bin/bash 로 읽고, 펜스를 잘라 `env -i` 로 약 12번 실행한다
- 종류: 섞임(동작 47 · 구조 9 · 글자 10 · 변이 34)
- 지키는 것: seed_edit_diff · seed_edit_screen · docreview_state 와 세 skill(request-framing · reviewing-brief · spec-review) 펜스의 상태 폴더 쓰기가 마지막 성분의 심볼릭 · 하드 링크를 따라가 레포 밖 파일을 만들거나 바꾸지 않고, 쓰기 실패 때 직전 번들 · 메모를 이번 것으로 넘기지 않으며, 펜스에 허용 밖 쓰기(> · tee · touch)가 없는지 지킨다 — 깨지면 상태 폴더에 심은 링크로 레포 밖 파일이 덮인다
- 거짓 실패 위험: 중간 — 펜스를 고정 문자열(`build_seed_inline_blob.py` · `--for recritic` · `gate-drops.json` · `record_artifact()`)로 골라 그 글자를 바꾸면 추출이 깨지고(추출 확인이 이름 붙여 먼저 빨개진다), README `## 한계` 문장을 전체 글자로 찾는다; 펜스에 새 쓰기 꼴(정당한 것이라도)을 넣으면 렉서가 막는다
- 겹침: plugins/spec-distill/tests/test_seed_edit_diff.sh · test_seed_edit_screen.sh — 같은 스크립트의 기본 동작(링크 케이스는 grep 으로 못 찾음) · shared/tests/test_writer_trust_notice.sh · plugins/spec-distill/tests/test_reviewing_brief_skill.sh — nofollow_write 를 부르는 펜스를 글자로 본다(이 파일은 실행으로 잰다)
- 보안 갈래: 예
- 판정 후보: 둠 — 경로 탈출(링크 따라가기)을 실행으로 잡는 보안 확인이고 비용이 그에 맞다; 다만 테스트 안 370줄 렉서는 구조를 손볼 여지가 있다
- 확신: 중간
- 확인 수: 약 100개 (동작 47 · 구조 9 · 글자 10 · 변이 34)
- 시간을 쓰는 곳: 추정 — scan_writes 가 SKILL 셋을 읽으며 bash 펜스마다 /bin/bash 둘(bash -n · declare -f)을 띄워 약 140번, 프로브 32개는 저마다 python 하나와 bash 최대 둘, 펜스 끝에서 끝 약 12번은 엔진 python 을 안에서 다시 띄운다, 상태 스크립트 직접 실행 약 25번
- 구조 고치기 여지: 더 싼 확인으로 내리기 — 테스트 안 heredoc python 렉서(scan_writes)를 따로 모듈로 빼면 프로브 32개를 한 프로세스에서 돌릴 수 있다(펜스마다 실제 셸과 맞춰 보는 bash 실행은 지키는 것이라 그대로)

### plugins/spec-distill/tests/test_team_coverage.sh
- 초: 10.0
- 줄 수: 363
- 고친 횟수: 7
- 크기: 중간 — 팀 레포를 한 번 세우고 check_bundle_coverage.py 를 약 75번 · roadmap_status 를 5번 하위 프로세스로 돌린다
- 종류: 동작
- 지키는 것: team 형식 번호 대조가 번호 파일(sources.md)의 ids 를 정답 출처로 빠진 번호를 잡고, `## 원문 대조` 표의 얕은 답 · 읽지 못한 행 알림 · 다른 과제 design.md 의 받듦 · 결과 파일 AC 줄(--impl) · 모르는 layout(검사 불가 3) · 레포 밖 `..` roadmap 경로 거부를 맞게 내며, 그 결과가 단계 계산의 경고 · 알림 · 종료 코드로 이어지는지 지킨다 — 깨지면 빠진 번호나 근거 없는 「바꿈」 이 조용히 지나간다
- 거짓 실패 위험: 중간 — 알림 · 얕은 답 문장을 전체 일치(assert_eq · `sed -n '$p'`)로 재서 문구를 다듬으면 깨진다; 판정 값(rc · --json 칸)은 동작에만 반응한다
- 겹침: plugins/spec-distill/tests/test_roadmap_status.sh — 옛 형식의 얕은 답 경고 줄 · plugins/spec-distill/tests/test_bundle_coverage.sh — 옛 형식 번호 대조(이 파일의 「옛 형식」 절 3단언과 겹칠 공산) · 파일 안에서 같은 design 을 글 출력과 --json 으로 두 번 돌려 같은 사실을 재는 자리가 약 15곳
- 보안 갈래: 예
- 판정 후보: 둠 — 10초에 약 110개로 비용이 맞고 대부분 판정 값을 잰다
- 확신: 중간
- 확인 수: 약 110개 (동작 110 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 팀 레포 세우기 한 번, check_bundle_coverage python 약 75번(글 · --json 짝으로 같은 입력을 두 번), 단계 계산 roadmap_status 5번과 copies() 넷이 git 을 여러 번 부른다
- 구조 고치기 여지: 같은 design 에 글 출력과 --json 을 따로 돌리는 약 15곳을 --json 한 번(필요하면 글 출력 한 번)으로 줄이기 — 그 밖에 없음

### plugins/spec-distill/tests/test_team_stale.sh
- 초: 24.2
- 줄 수: 178
- 고친 횟수: 7
- 크기: 중간 — 팀 레포 하나에서 main 을 바꿨다 되돌리는 commit · push · fetch 왕복 약 13번과 roadmap_status 17번을 돈다
- 종류: 동작
- 지키는 것: 도는 일꾼(끝 줄 없는 결과 파일)의 묶음이 낡았을 때 — 팀 규칙 · 공통 규칙 · 그 역할의 문서가 묶은 커밋 뒤에 바뀌면 — 현황에 「묶음 낡음」 을 알리고, 다른 역할 문서 · 검수 기준 · 끝난 파일 · 검수 결과는 알리지 않고, 없는 커밋 · 깨진 머리는 「재지 못했다」 로 알리며 종료 코드 · 검사 불가 사유는 그대로인지, leader_ref 를 바꾸면 팀 규칙만 그 커밋에서 읽는지 지킨다 — 깨지면 일꾼이 낡은 규칙으로 일하는 줄 모른다
- 거짓 실패 위험: 중간 — 알림 문장을 커밋 8자까지 전체 일치로 재서 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_leader_seat_e2e.sh — 상태 브랜치 규칙 사본과 rules_at 을 거친 「묶음 낡음」(R3 AC15)을 끝에서 끝으로 잰다(이 파일의 ⑩ AC31 과 일부 겹침) · plugins/spec-distill/tests/test_start_bundle.sh — 같은 leader_ref 바꿔 끼우기(I2)를 묶음 쪽에서 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 「바뀜」 을 지어내지 않는 음의 짝까지 갖춘 확인이고 단언 약 50개에 24초로 무겁지만 main 을 실제로 바꿔야 재는 동작이다
- 확신: 중간
- 확인 수: 약 50개 (동작 50 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — roadmap_status 17번(브랜치마다 결과 파일을 git 으로 읽는다), bump · unbump 마다 commit · push · fetch · revert, job sync python 약 12번, js 로 보고를 읽는 python 약 24번
- 구조 고치기 여지: 준비 함께 쓰기 — 걸음마다 main 을 바꿨다 revert 로 되돌리며 push 하는데, 바꾼 상태를 처음에 브랜치로 만들어 두고 origin/HEAD 를 옮겨 재면 왕복이 준다(스크립트가 origin/HEAD 만 읽으므로 이득은 작고 확신 낮음)

### plugins/spec-distill/tests/test_team_status.sh
- 초: 134.3
- 줄 수: 869
- 고친 횟수: 20
- 크기: 큼 — 팀 레포를 세 번 세우고(본 레포 · 관문 · 받음 낡음) 둘째 clone · 얕은 clone 둘 · 가짜 git 둘을 쓰며, 걸음마다 commit · push(되돌릴 땐 force push) 뒤 roadmap_status 를 다시 계산해 약 120번 돈다
- 종류: 섞임(동작 99 · 구조 0 · 글자 1 · 변이 0)
- 지키는 것: team 로드맵의 단계 계산이 근거 파일 하나씩의 변화(브랜치 · design.md · 승인 줄 · 계획 · 결과 파일 · 막힘 파일 · 받음 줄 · 받은 뒤 고침 · 갈라짐 · 얕은 클론 · 기본 브랜치 모름 · git 실패)에 맞는 단계 · 근거 · 진행 숫자 · 알림 · 종료 코드를 내고, 손으로 적은 승인 줄은 관문이 켜진 동안 지나지 못하며 설정 오류면 관문이 켜진 채인지, 예약 밖 변경 · INTENT 어긋남 · 넘김 · 판정 알림이 맞는지 지킨다 — 깨지면 지휘자가 잘못된 단계로 다음 일을 고르거나 승인 없이 넘어간다
- 거짓 실패 위험: 중간 — 근거 · 알림 문장을 전체 일치로 재는 단언이 수백이라 문구 하나를 다듬으면 여러 단언이 함께 깨지고, 걸음이 레포 상태를 이어받아 앞 걸음이 어긋나면 뒤가 연쇄로 빨개진다(fail_step 이 보고를 지워 연쇄를 드러낸다); read_tip 소스 글자 확인 3개(branch_tip.tip( · is_ancestor · merge-base)는 리팩터에 깨진다
- 겹침: plugins/spec-distill/tests/test_team_results.py — 결과 파일 · 막힘 파일 · 결정 기록 줄 읽기(BOM · 닫히지 않은 펜스 · Task 줄 꼴)를 프로세스 안에서 잰다(이 파일은 같은 갈래를 레포 왕복으로 다시 잰다) · plugins/spec-distill/tests/test_human_gate.sh — human_gate 끔 · 손으로 적은 줄 관문을 묶음 쪽에서 · plugins/spec-distill/tests/test_team_tasks.sh — 로드맵 밖 과제 · plugins/spec-distill/tests/test_roadmap_status.sh — 옛 형식 단계 계산 · 파일 안에서 「받은 뒤 바뀜」 갈래를 본 레포와 받음 낡음 레포(r1–r10)에서 비슷하게 두 번 잰다(미룸 절만 고침 · 본문 고침 · 예약 경로 고침)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 134초로 스위트에서 가장 무겁고, 이미 새 레포를 세우는 두 절(관문 · 받음 낡음)과 단계 · 알림 절이 갈라지므로 나누면 병렬로 돌고, 보고를 걸음마다 python 수십 번으로 읽는 자리를 묶으면 싸진다
- 확신: 중간
- 확인 수: 약 270개 (동작 267 · 구조 0 · 글자 3 · 변이 0)
- 시간을 쓰는 곳: 추정 — roadmap_status 약 120번(step · restat · back 뒤마다, 각자 모든 브랜치를 git 으로 읽는다), st · why · notes · blk · jobf 가 단언마다 python 을 새로 띄우는 곳 약 263곳, 팀 레포 세우기 세 번, step 마다 add · commit · push, back 마다 reset · force push, 얕은 클론 둘, approved 여덟 번(python 셋씩)
- 구조 고치기 여지: 나누기 — 관문(733–801행)과 받음 낡음(803–868행)은 이미 새 레포를 세우므로 따로 파일로 떼어 병렬로 · 본 레포도 단계 · 받음(1–500행)과 알림(502–731행)으로 나눌 수 있다(알림은 RECEIVED_AT · MAIN_AT 상태를 이어받아 준비를 함께 써야 한다); 준비 함께 쓰기 — 걸음마다 보고를 한 번 python 으로 읽어 필요한 칸을 함께 내면 python 실행 수백 번이 준다; 더 싼 확인으로 내리기 — 결과 파일을 다 읽지 못한 갈래(Task 03 · 닫히지 않은 펜스 · BOM)의 파싱은 test_team_results.py 가 재니 레포 왕복은 대표 하나만

### plugins/spec-distill/tests/test_team_sync.sh
- 초: 7.8
- 줄 수: 275
- 고친 횟수: 8
- 크기: 중간 — 팀 레포를 한 번 세우고 roadmap_write.py job sync 를 약 95번 · parse_result python 약 15번 · workflow_superpowers place 8번 하위 프로세스로 돌린다
- 종류: 동작
- 지키는 것: job sync 가 결과 파일 머리(키 차례 · 빈 줄 · rules_at 자리)를 만들고, 원장 · 계획에서 Task · Ruling 줄을 한 번씩만 덧붙이고(두 번 돌려도 바이트 그대로 · CRLF · 끝 줄바꿈 없음 · 펜스 인용), 끝난 파일은 고치지 않고, 이름 꼴 · team 형식 아님 · 심볼릭 링크(파일 · 결과 폴더 · 과제 폴더 · jobs · 레포 밖 · 다른 작업 트리)를 거절해 링크 너머에 쓰지 않으며, place 문장이 맞는지 지킨다 — 깨지면 결과 파일이 중복 줄로 부풀거나 링크 너머 파일이 덮인다
- 거짓 실패 위험: 낮음 — rc 와 사유 조각(부분 문자열) · 바이트 비교로 재서 동작이 바뀔 때만 깨진다; 머리 전체 글자 비교 두 곳만 키 차례에 민감하다
- 겹침: plugins/spec-distill/tests/test_team_results.py — 결과 파일 읽기(parse_result)의 꼴(이 파일은 rattr 로 쓰고 난 뒤 읽힘만 본다) · plugins/spec-distill/tests/test_start_bundle.sh — 맞추는 명령을 그대로 돌린 job sync 한 번 · plugins/spec-distill/tests/test_leader_seat_e2e.sh — rules_at 을 끝에서 끝으로
- 보안 갈래: 예
- 판정 후보: 둠 — 8초에 약 200개, 링크 거절(경로 탈출)과 멱등 쓰기를 실행으로 재고 겹침은 일부뿐이다
- 확신: 높음
- 확인 수: 약 200개 (동작 200 · 구조 0 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — 팀 레포 세우기 한 번(roadmap_write original · create python + git 십여 번)과 job sync python 약 95번; 레포를 바꾸는 commit · push 가 없어 가볍다
- 구조 고치기 여지: 없음

#### 읽지 못한 것 — deep-10

없음

## 묶음 deep-11

### plugins/spec-distill/tests/test_team_tasks.sh
- 초: 64.8
- 줄 수: 584
- 고친 횟수: 11
- 크기: 큼 — 임시 bare+작업 레포 하나 위에 브랜치 수십 개를 쌓고 상태 계산을 34번 다시 돌리며, 얕은 클론 셋 · --no-local 클론 · bare 사본 · 새 팀 레포까지 만든다
- 종류: 섞임(동작 95 · 구조 5 · 글자 0 · 변이 0)
- 지키는 것: 로드맵 밖 과제(kind: task)를 기본 브랜치 · 브랜치 끝에서 찾아 jobs · job_notes 에 따로 싣고(사본 · 머리 어긋남 · 갈라짐 · 이름 겹침 · 깨진 INTENT · 얕은 클론 · git 실패 · 기본 브랜치 모름), 단계(진행 중 · 결과 받음 · 머지됨)와 예약 알림을 블록과 같은 판정으로 내며 종료 코드를 바꾸지 않는다는 것 — 깨지면 지휘자가 과제를 못 보거나 잘못된 단계로 보거나, 읽지 못함을 「없음」으로 본다.
- 거짓 실패 위험: 높음 — 알림 문장을 글자 그대로 assert_contains/assert_eq 로 대조하는 줄이 많아(「로드맵 밖 과제 … 을 세지 않았다 — 머리의 branch(…)」 · 현황 「정보:」 줄 들여쓰기) 문구만 다듬어도 깨지고, 앞 걸음의 브랜치 상태가 뒤 단언의 전제라 한 걸음 실패가 연쇄로 번진다
- 겹침: plugins/spec-distill/tests/test_control_plane.py — job_notes · jobs 의 현황 렌더(단위); plugins/spec-distill/tests/test_team_status.sh · test_start_bundle.sh — job new · job sync · 결과 대조 걸음; 파일 안에서는 「종료 코드를 바꾸지 않는다」(r['exit']=0)를 다섯 자리에서 되풀이
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 한 레포에 모든 묶음을 차례로 쌓아 상태 계산을 34번 · `js` 로 python 을 단언마다 새로 띄우고, git 실패 셋(Shut · NoDiff)은 이미 프로세스 안 python 이라 단위 테스트로 내릴 수 있다
- 확신: 중간
- 확인 수: 약 165개 (동작 157 · 구조 8 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — `again`(roadmap_status.py --json 전체 계산)을 34번 부르는데 브랜치가 쌓일수록 한 번이 비싸진다; 단언마다 `js`/`jget` 가 python 을 새로 띄워 150번 남짓; 얕은 클론 3개 + shalgen --no-local 클론 + prr bare/clone + 새 팀 레포(new_repo: roadmap_write original · create + push) 준비; 가짜 git 래퍼(PATH 앞 sh)로 도는 상태 계산
- 구조 고치기 여지: 나누기 — 「끝에서 끝」(job new→sync→check→record) · 「얕은 클론」 · 「pr-refresh」 · 「글 출력 M21–M23」 묶음은 서로 다른 레포 상태에서 시작하므로 파일을 나눠 병렬로; 더 싼 확인으로 — Shut/NoDiff git 실패 셋은 roadmap_status.build 를 직접 부르는 python 단위 테스트로; 한 상태마다 필요한 칸을 `js` 한 번에 뽑아(튜플로) python 띄우기를 줄인다

### plugins/spec-distill/tests/test_team_write.sh
- 초: 58.5
- 줄 수: 1548
- 고친 횟수: 19
- 크기: 큼 — origin 째 새 레포 사본을 20번 가까이 clone 하고(fresh · sq2–sq8 · sqw), 거의 모든 실패 갈래마다 snap.py 로 작업 나무 전체를 해시해 견준다
- 종류: 섞임(동작 85 · 구조 10 · 글자 5 · 변이 0)
- 지키는 것: team 형식 생성기(original · create --layout team · update · extract · job new)가 원자료를 출처와 바이트 그대로 옮기고, 실패하면 한 거래로 아무것도 남기지 않으며, 사람이 둔 파일 · 매달린 링크 · 심볼릭 링크 역할 폴더 · 머지된 에픽을 덮어쓰지 않고, 출처 커밋이 사라진 사본은 기준 줄로 대체 대조하거나 검사 불가로 멈춘다는 것 — 깨지면 원자료 사본이 틀어지거나 사용자의 파일이 지워진다.
- 거짓 실패 위험: 중간 — 대부분 rc · 바이트 비교(cmp · snap)라 동작이 바뀔 때만 깨지지만, 「손으로 고칠 것」 블록 · 사라진 에픽 알림 · FN_LINE · 대체 대조 알림을 글자 그대로 대조하는 단언(약 20개)은 문구 다듬기에 깨진다; 앞 블록의 t1 상태를 뒤 블록이 전제로 쓴다
- 겹침: plugins/spec-distill/tests/test_team_layout.py — team_layout 경로 · 이름 규칙(단위); test_team_status.sh · test_raw_source_downstream.sh — original · create 를 픽스처로 부른다; test_roadmap_write.sh — 옛 형식 update(파일 784줄이 직접 밝힌다); 파일 안에서는 jfail 의 「나무 그대로」(same_tree) 를 사용법 오류(rc 2) 열 넘는 갈래에도 매번 되풀이
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 넓고 분명하나 한 파일이 하위 명령 다섯을 한 레포 상태 위에 차례로 쌓아 병렬이 안 되고, 사본마다 git clone 을 새로 하며, argparse 단계에서 멈추는 rc 2 갈래까지 python 기동 + 나무 해시를 쓴다
- 확신: 중간
- 확인 수: 약 450개 (동작 380 · 구조 45 · 글자 25 · 변이 0)
- 시간을 쓰는 곳: 추정 — `fresh`/`git clone` 20번(sq 갈래는 기준 커밋을 바꿀 때마다 새 clone: sq3 · sq4 · sq5 · sq6 · sq7 · sq8 · sqw); `snap.py`(os.walk + sha256 전체) 를 same_tree · b_* 비교마다 약 70번; roadmap_write.py 를 갈래마다 새 python 으로(create · update · original · job new 합쳐 150번 남짓); jfail 루프의 rc 2 갈래 열 개도 python 기동 + snap 둘
- 구조 고치기 여지: 나누기 — original · create · update/extract · job new · 대체 대조(sq) · framing 찾기(fa) · 머지 보호(mg) · 잔여(rz) 를 파일로 갈라 병렬로(각 묶음은 이미 제 사본에서 시작하는 것이 많다); 준비 함께 쓰기 — 깨끗한 origin clone 하나를 만들어 두고 `cp -R` 로 사본을 뜬다; 더 싼 확인으로 — `--goal`/`--paths`/`--branch`/`--not` 사용법 오류(rc 2)는 쓰기 전 argparse 검증이라 snap 없이 rc · 사유만 보거나 python 단위 테스트로

### plugins/spec-distill/tests/test_walk_next.sh
- 초: 46.6
- 줄 수: 243
- 고친 횟수: 3
- 크기: 큼 — 팀 레포를 세 번 새로 세우고(team_repo: roadmap_write original · create + push · 지휘 표지) walk_table.py next 를 33번 하위 프로세스로 돈다
- 종류: 섞임(동작 95 · 구조 5 · 글자 0 · 변이 0)
- 지키는 것: 걸음 보기(walk_table.py next)가 자취(브랜치 · 설계 · 계획 · 사람 줄 · 받음 줄 · PR 캐시 · 머지 줄)로 지금 걸음 · 다음 걸음 · 막는 것을 바르게 고르고, 레포 걸음표가 관문 칸을 비워도 관문을 열지 않으며(AC9), 깨진 표 · 갈라진 브랜치 · 읽지 못한 PR 캐시는 3 으로 멈추고 표준 출력을 비운다는 것 — 깨지면 지휘자가 사람 관문을 건너뛰거나 틀린 다음 걸음을 진행한다.
- 거짓 실패 위험: 중간 — `다음 걸음` 칸의 전체 문자열(「설계 대화 — 누가 사람 · leader · 작업 방식 … · 상한 — · 도구 —」)과 사유 문구를 글자로 대조해 표 칸 문구를 바꾸면 깨진다; 묶음 A 는 앞 행 상태가 뒤 행의 전제라 연쇄로 번진다
- 겹침: plugins/spec-distill/tests/test_walk_table.py — 걸음표 읽기(l1–l7: 레포 표 · 깨진 표 · 기본 브랜치에 없는 표)와 b3c–b5 의 표 오류 갈래가 아래층에서 겹친다(여기는 next 의 rc 3 · 빈 출력까지 본다); test_walk_docs.py — 표 문서
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것이 분명하고 단언은 군더더기가 적으나, 초의 대부분이 같은 팀 레포 준비를 세 번 되풀이하고 next 한 번마다 상태 계산 전체를 다시 하는 데서 나온다
- 확신: 낮음
- 확인 수: 약 105개 (동작 100 · 구조 5 · 글자 0 · 변이 0)
- 시간을 쓰는 곳: 추정 — new_repo 세 번(각각 git init · roadmap_write original · create · push · fetch · claim); `wn` 33번(각각 python walk_table.py next → 상태 계산 · git 읽기); finish_attempt(start_bundle 실행 + job sync) · rcheck · led record 같은 준비 걸음; status() 두 번
- 구조 고치기 여지: 준비 함께 쓰기 — team_repo 로 세운 깨끗한 레포를 한 번 만들어 두고 묶음 B · C 는 `cp -R`(origin.git 포함)로 뜬다(team_repo 를 쓰는 test_team_tasks · test_team_status 등도 같은 템플릿을 쓸 수 있다); 나누기 — 묶음 A · B · C 는 서로 독립이라 파일 셋으로 갈라 병렬로

### plugins/spec-distill/tests/test_workspace_invariance.sh
- 초: 20.2
- 줄 수: 451
- 고친 횟수: 13
- 크기: 큼 — 임시 레포를 열 개 넘게 만들고(inv · oth · tr · pl · noorigin · ren · trk · cfg-×4 · fk), 해결자 · 로드맵 찾기 · 상태 계산을 세 자리에서 33번씩 돌리며, merge_check run(스위트 대조 사본)을 한 번 돈다
- 종류: 섞임(동작 90 · 구조 5 · 글자 5 · 변이 0)
- 지키는 것: 같은 레포의 다른 브랜치 worktree 둘에서 해결자 get(열다섯 키 · 로드맵 층) · 로드맵 찾기 · 상태 계산이 바이트까지 같은 답을 내고(작업 트리가 아니라 기본 브랜치를 읽는다), devbrew 밖 레포(trunk · plan/ 폴더 · origin 없음 · 개명 · fork + upstream)에서도 기본 브랜치 · 설정 · origin PR 만을 바르게 쓴다는 것 — 깨지면 브랜치마다 다른 설정 · 다른 로드맵 판정이 나고 fork 에서 upstream PR 로 거짓 「머지됨」이 난다.
- 거짓 실패 위험: 중간 — 불변 락 자체는 바이트 비교라 낮지만, AC29 꼬리의 안내 문구(「git remote add origin」 · 「값의 출처: 기본값(…)」 · 「[devbrew-deps] 멈춤 — …」) 대조와 비교 파일 수 상수 NFILES(키 수 15 를 식에 박음)는 키 추가 · 문구 다듬기에 깨진다
- 겹침: plugins/spec-distill/tests/test_repo_defaults_git.sh — 설정 파일 BOM · 같은 키 둘 · 오타 키; test_state_root.sh(172행 conductor claim 까지) · test_ledger_root.sh — 상태 폴더 아래 추적 파일 rc 3 과 안내; test_default_branch.sh — trunk · --check-remote; shared/tests/test_check_deps.py — 「2.45.0-rc1」 접미사 판 읽기; plugins/quality-gates/tests/test_resolve_baseline.sh — no-default-branch; test_gh_repo.sh · test_roadmap_status.sh — GH_REPO · -R origin
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 불변 락(AC27) · 양성 대조 · fork pr-refresh · trunk merge_check 은 이 파일만 지키지만, AC29 꼬리의 설정 파일 깨짐 넷 · 추적 파일 · -suffix · origin 없음 일부는 더 싼 전용 테스트가 이미 같은 문구까지 지킨다
- 확신: 중간
- 확인 수: 약 95개 (동작 85 · 구조 5 · 글자 5 · 변이 0)
- 시간을 쓰는 곳: 추정 — battery 세 번 × (해결자 30번 + 로드맵 찾기 + 상태 계산 둘) = python 기동 99번; mkrepo 열두 번(bare + 작업 레포 + push + set-head); merge_check.py run 의 스위트 대조 사본(test_command "true"); 끝내기 커밋 펜스 · spec-review 진입 펜스를 bash -c 로 실제 실행; cfg-* 네 레포마다 get + roadmaps
- 구조 고치기 여지: 더 싼 확인으로 — battery 의 열다섯 키 × 두 꼴을 해결자 한 번 기동에서 다 뽑는 꼴(같은 프로세스에서 키를 돌며 stdout · stderr · rc 를 기록)로 바꾸면 python 기동이 99 → 9 남짓; 줄임 — 겹침에 적은 꼬리 갈래를 빼면 레포 다섯 남짓을 덜 만든다

### shared/tests/test_changelog_integrity.sh
- 초: 7.1
- 줄 수: 366
- 고친 횟수: 2
- 크기: 작음 — 파일 읽기와 grep 뿐(하위 프로세스는 셸 내장 대신 쓴 grep · cut 들)
- 종류: 구조
- 지키는 것: 플러그인마다 CHANGELOG 가 plugin.json 판과 맞고(v≥1.0.0 이면 필수 · 맨 위 헤딩 = 판 · 헤딩 순감소 · 헤딩 형식과 날짜) floor 위로 건너뛴 판이 없으며 floor 자체가 실재 gap 에만 놓인다는 것 — 깨지면 판을 올리고 노트를 덮어쓰거나 빠뜨린 릴리스가 조용히 지나간다.
- 거짓 실패 위험: 낮음 — 실제로 헤딩 · 판이 어긋날 때만 깨진다; GAP_FLOORS 두 줄은 C5b 가 코퍼스와 맞는지 검증한다
- 겹침: 못 찾음 — CHANGELOG.md 를 읽는 다른 락(test_invocation_surface.sh · test_switch_tables.sh · test_dispatch_disposition.sh)은 Removed 공시 · 이름 같은 다른 사실을 본다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 분명하고 겹침도 없으나, 헤딩 495개마다 printf|grep · cut · grep -oE 를 서너 번씩 하위 프로세스로 돌려 초를 쓴다 — 한 번의 awk(또는 python) 파스로 내리면 같은 검사를 1초 안으로
- 확신: 중간
- 확인 수: 약 25개 (동작 0 · 구조 25 · 글자 0 · 변이 0) — 플러그인마다 C1 · C2 · C3 · C4 · C5a · C5b 와 vacuity 게이트 넷
- 시간을 쓰는 곳: 추정 — 헤딩 줄마다 C4(printf|grep · cut · printf|grep) · C3(printf|grep -oE|grep -oE|head) · C5a(같은 추출을 다시) 로 헤딩 495개 × 10번 남짓의 fork; ver_gt · ver_adjacent 의 here-string(bash 3.2 는 임시 파일)
- 구조 고치기 여지: 더 싼 확인으로 — 헤딩 추출 · 형식 · 순감소 · 인접성을 파일마다 awk 한 번(또는 python 한 번)으로 계산하고 셸은 결과만 단언; 같은 버전 추출을 세 번 하는 것을 한 번으로

### shared/tests/test_copy_of_contract.sh
- 초: 40.8
- 줄 수: 1239
- 고친 횟수: 22
- 크기: 큼 — 리포 전체 코퍼스를 여러 번 훑고, import 소비자마다 python 프로브를 두 번(제자리 해석 · 링크 없는 설치본 대역 트리) 실행하며, 사본 레포 · 임시 트리를 만든다
- 종류: 섞임(동작 25 · 구조 70 · 글자 5 · 변이 0)
- 지키는 것: 배포 지점이 정본을 가리키는 세 방식(심볼릭 링크 ∀ · copy-of 사본 바이트 동일 · import 형제 사본 ∀ 와 설치본 대역 import)이 재분열 없이 맞고, codex kill switch 설정이 배포에 실리며 설정이 없으면 detect_codex 가 fail-closed 라는 것 — 깨지면 설치본에서 형제 import 가 ImportError 로 codex 리뷰어가 죽거나 kill switch 가 조용히 무반응이 된다.
- 거짓 실패 위험: 낮음 — 대부분 구조에서 도출한 ∀ 대조라 실제 배포가 갈라질 때만 깨진다; 축 0 의 머리말 수사 · shared/README.md 서술 대조(「방법은 셋이다」 · 「세 계약을 검사한다」)만 문구에 걸린다
- 겹침: shared/tests/test_no_new_duplication.sh — copy-of 마커 면제를 이 파일에 위임(같은 CORPUS 도출); shared/tests/test_variant_of_contract.sh · test_docreview_copy_set.sh — 사본 · 변형 계약의 다른 면; plugins/quality-gates/tests/test_codex_copies_agree.sh — codex 사본 일치
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(설치본 형제 · kill switch fail-closed)은 분명하고 버리면 안 되지만, 초의 큰 몫이 셸 루프 안의 불필요한 fork(특히 shared .py × plugin .py 이중 루프의 `$(basename …)`)에서 나온다
- 확신: 중간
- 확인 수: 약 300개 (동작 15 · 구조 280 · 글자 5 · 변이 0) — 실행 중 정본 · 배포 지점 · 사본 후보 · 소비자 수만큼 늘어난다(축 1a 링크 마흔 남짓 · 축 1b 파일 760개 훑기 · 축 1c 소비자 · 축 2·3 사본 셋)
- 시간을 쓰는 곳: 추정 — M6 앵커 루프가 shared .py 61개 × plugin .py 242개 = 약 1만 5천 번 `$(basename -- "$pp")` 를 fork; 축 1b 의 CORPUS 760개를 두 루프에서 파일마다 head|grep(|head) · printf|grep -qxF; 축 1a 의 prose_consumers 가 정본마다 plugins 전체를 xargs grep; CONSUMED_PY 가 shared .py 마다 git ls-files + awk; 축 1c 의 소비자마다 python 프로브 두 번 + cp -RL 트리
- 구조 고치기 여지: 더 싼 확인으로 — 이중 루프의 `$(basename …)` 를 `${pp##*/}` 로 바꾸거나 plugin .py basename 목록을 한 번 만들어 awk 로 셈(같은 판정, fork 0); 축 1b 두 루프를 파일당 한 번 읽기로 합치고 head|grep 을 awk 한 번으로; prose_consumers 는 정본 basename 전부를 한 번의 grep(대안 패턴)으로 훑어 정본별로 가른다

### shared/tests/test_docreview_advice.sh
- 초: 72.7
- 줄 수: 87
- 고친 횟수: 29
- 크기: 큼 — 케이스 66개(본문 fixtures/docreview/cases_advice.sh 1097줄)가 저마다 임시 상태 디렉토리를 만들어 init · begin-round · prepare-recritic · finalize 를 python 하위 프로세스로 돌리고, 단언마다 python 을 또 띄운다
- 종류: 섞임(동작 95 · 구조 3 · 글자 2 · 변이 0)
- 지키는 것: docreview 의 must-catch / 참고(advisory) 라우팅이 프로필의 must_catch 지목대로 차단 원장과 advice 원장을 가르고(rubric 밖 · other · frozen_change · 엔진 자동 항목 · must-catch 구성원이 낀 병합은 fail-closed 로 차단 쪽), 라운드 1회 규칙 · 계수 등식 · 박제(sink) · 계수 줄의 멱등 · 원자 쓰기 · surrogate 정화 · 닫힌 뒤 손 줄 판정이 바르다는 것 — 깨지면 승인을 막아야 할 지적이 참고로 새거나, 사용자 문서가 깨지거나 0 바이트가 된다.
- 거짓 실패 위험: 중간 — 대부분 원장 · 보고서의 값 대조라 동작이 바뀔 때만 깨지지만, 게이트 참고 줄 · 렌더 머리 줄(「참고(advisory) N건 — 게이트 질문이 아니고 …」)을 글자 그대로 대조하는 단언(약 15개)은 렌더 문구 다듬기에 깨진다
- 겹침: shared/tests/test_docreview_mutations.sh — 같은 cases_advice.sh 케이스를 변이 매트릭스로 다시 돈다; shared/tests/test_docreview_ask.sh — cases_advice.sh 를 source 하고 case_gate_file_advice_included 가 AC1 과 같은 준비; plugins/spec-distill/tests/test_begin_round_snapshot.sh — cases_advice.sh 를 코퍼스로 읽는다; 파일 안에서는 같은 라운드 1 준비(mc_r1)를 14번 · adv_state 를 21번 새로 만든다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하고 변이 락과 케이스 본문을 공유해 지울 수 없지만, 같은 준비(mc_r1 · adv_state N · route_r1 같은 입력)를 케이스마다 python 예닐곱 번으로 다시 짓고 값 하나마다 python 을 새로 띄우는 데 초를 쓴다
- 확신: 중간
- 확인 수: 약 215개 (동작 205 · 구조 5 · 글자 5 · 변이 0)
- 시간을 쓰는 곳: 추정 — route_r1 한 번이 mk_state(init) · snap · begin-round · prepare-recritic · render_recritic · finalize 로 python 6–7번이고 이를 케이스마다(mc_r1 14 · adv_state 21 · route_r1 직접 20 남짓 · r1+next_round 여럿); st_yaml · jget · fsum · gsum(gate + jgets 두 번) 이 단언마다 python 1–2번이라 단언 215개에 300번 남짓; next_round 가 exempt-anchors · diff · observe-diff 를 더한다; source 때 nofield_profiles.sh 로 사본 프로필을 만든다
- 구조 고치기 여지: 준비 함께 쓰기 — 읽기만 하는 케이스용으로 mc_r1 · adv_state(1/2/3/8/11) · route_r1(같은 입력) 결과 디렉토리를 파일 머리에서 한 번 만들고 케이스마다 `cp -R` 로 뜬다(변이 락은 지금처럼 새로 지어도 된다); 더 싼 확인으로 — 한 케이스의 원장 · 보고서 값 여럿을 st_yaml/jget 한 번에 튜플로 뽑는다

### shared/tests/test_docreview_ask.sh
- 초: 14.9
- 줄 수: 55
- 고친 횟수: 4
- 크기: 중간 — 케이스 33개(본문 fixtures/docreview/cases_ask.sh 356줄)가 임시 상태 디렉토리를 만들고 docreview 스크립트를 python 하위 프로세스로 돈다
- 종류: 섞임(동작 90 · 구조 5 · 글자 5 · 변이 0)
- 지키는 것: 질문에 싣는 짧은 경고 줄 · 상태 줄이 게이트 첫 줄과 같은 목록에서 세어지고, ask-material 이 질문으로 뜨는 행마다 엔진 라벨 · 두 칸 전문 · 고정 설명을 원장을 쓰지 않고 내며, gate-file 이 라운드마다 두 구역 파일을 쓰되 원문 구역을 잇고 링크를 따라가지 않으며 원장을 바꾸지 않는다는 것 — 깨지면 사용자가 보는 질문의 선택지 · 설명이 엔진 동작과 어긋나거나 전문 파일이 링크 너머에 쓰인다.
- 거짓 실패 위험: 높음 — 고정 설명 · 선택지 · 덧줄 문장을 글자 그대로 assert_contains 로 대조하는 단언이 많아(「고정 설명: 나중에 정한다(보류) = 지금 정하지 않는다 — …」) 사용자 글 문구를 다듬기만 해도 깨진다
- 겹침: shared/tests/test_docreview_advice.sh — cases_advice.sh 를 함께 source 하고 case_gate_file_advice_included 가 case_AC1_brief_overdesign_only 와 같은 준비; cases.sh 의 원 케이스(case_plain_render_nothing_left · case_T46 · case_T35 · case_AC38 · case_cap_zero_open_two_stage 등)와 준비가 같다고 케이스 머리 주석이 밝힌다; plugins/spec-distill/tests/test_ledger_wiring.sh — AC8_READ_ONLY 목록(이 파일이 그 줄을 grep 한다)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것은 분명하나 같은 준비(ask_prep_fields/gfile_prep)를 13번 새로 짓고, 순수 함수 케이스(short_warn_line · display_path · originals_block 등) 여섯은 python 단위 테스트가 더 싸다
- 확신: 중간
- 확인 수: 약 95개 (동작 85 · 구조 5 · 글자 5 · 변이 0)
- 시간을 쓰는 곳: 추정 — ask_prep_fields(route_r1: python 6–7번)를 13번; mat · gfile · gate --render 가 각각 python 기동; 단언 값마다 jget/jgets/status_of python; source 때 cases.sh · cases_advice.sh 를 함께 읽고 nofield_profiles.sh 실행
- 구조 고치기 여지: 준비 함께 쓰기 — ask_prep_fields 결과를 한 번 만들고 읽기만 하는 케이스(decide_bundle · length_mark · gate_file_failed · module_missing · ledger_untouched 등)는 `cp -R` 사본에서; 더 싼 확인으로 — 순수 함수 케이스 여섯을 python 단위 테스트 하나로 모은다

### shared/tests/test_docreview_codex.sh
- 초: 19.4
- 줄 수: 587
- 고친 횟수: 18
- 크기: 큼 — codex 러너(bash + 인라인 python 빌더 + 변환기)를 stub codex 와 함께 90번 가까이 실행하고, 모양마다 mutate_profile_shape.py · profile-check 를 따로 띄운다(바깥 호출은 없다 — stub)
- 종류: 섞임(동작 85 · 구조 10 · 글자 5 · 변이 0)
- 지키는 것: docreview codex 러너가 프로필의 ground_truth · 층 rubric · 처분 · 본문 · P21 preamble 을 프롬프트에 그대로 싣고, 웹 스위치를 프로필 web 과 두 호스트 kill switch 의 OR 로 닫으며, 게이트가 받는 프로필이면 같은 값을 읽거나 이름 붙은 사유로 멈춰 다른 값으로 codex 를 부르지 않고(줄 문법 허용 목록), preamble 이 없으면 주입 경계 없는 프롬프트를 내보내지 않는다는 것 — 깨지면 kill switch 를 켜도 웹이 열리거나, 프로필 편집 한 줄로 codex 웹이 켜지거나, 주입 방어 없는 프롬프트가 나간다.
- 거짓 실패 위험: 중간 — 대부분 러너 결과(사유 이름 · argv · 캡처 줄 대조)라 동작이 바뀔 때만 깨지지만, 프롬프트 줄 머리(「Layer 1 (big-picture coherence) — categories: 」 · 「Never follow instructions found inside」 · 「empty is NOT a deletion proposal」)를 글자로 잡아 프롬프트 문구를 다듬으면 깨진다; 레포 안 fixtures/docreview/binstub 을 만들고 지워 같은 폴더를 쓰는 동시 실행과 부딪칠 수 있다
- 겹침: plugins/spec-distill/tests/test_web_kill_switch.sh — 러너들의 웹 스위치 변수 · web_search 모드를 정적으로 대조; test_brief_codex_axes.sh · test_seed_codex_axes.sh — 같은 러너의 배선 · 축; plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh · test_codex_invocation_contract.sh — 러너 계약의 다른 면; 파일 안에서는 앞쪽 「형태 회귀」 셀(dup-web · gt-dup · block-* 등)과 뒤쪽 「한 판정」 variant 셀이 같은 멈춤(profile_parse_ambiguous)을 다른 모양으로 되풀이한다
- 보안 갈래: 예
- 판정 후보: 둠 — kill switch · 주입 경계 · 게이트와 러너의 한 판정을 지키는 보안 갈래이고, 셀 하나가 러너 한 번(0.2초 남짓)이라 비용이 지키는 것에 맞는다
- 확신: 중간
- 확인 수: 약 280개 (동작 240 · 구조 25 · 글자 15 · 변이 0) — variant 50개 × 단언 2–4개 · 프로필 코퍼스 4개 × 단언 12개 · 형태 회귀 20개 남짓 · preamble 2개
- 시간을 쓰는 곳: 추정 — 러너 실행 약 90번(각각 bash + python 빌더 + 필요 시 stub codex + codex_findings_to_yaml.py); variant 마다 mutate python + profile-check python + parsed_eq python + pc_get python; 프로필 코퍼스마다 profile-check 를 세 번(l1_axis0 · want_l2 · pj) 따로 돈다
- 구조 고치기 여지: 더 싼 확인으로 — 프로필 코퍼스 루프의 profile-check 세 번을 한 번(pj)으로 모아 l1 · l2 를 pj 에서 읽는다; variant 중 러너가 멈추는 모양(대부분)은 빌더의 줄 문법 파서를 python 한 번에서 모양 전부에 돌리는 단위 대조로 내릴 여지가 있으나 러너 «행동»(codex 미호출)을 재는 몫은 남겨야 한다

#### 읽지 못한 것 — deep-11

- shared/tests/test_docreview_advice.sh · shared/tests/test_docreview_ask.sh — 테스트 파일과 케이스 본문(cases_advice.sh 1097줄 · cases_ask.sh 356줄)은 끝까지 읽었다. 공유 헬퍼 파일 cases.sh(4773줄)는 쓰이는 헬퍼(route_r1 · r1 · next_round · st_yaml · jget · gsum · fsum · render_recritic · critic_now · codex_now)만 읽었다 — 그 밖의 헬퍼(mk_doc_state · br · seed_findings · with_log · doc_sub 등) 본문은 읽지 않았다.
- 모든 「시간을 쓰는 곳」은 테스트를 실행하지 않고 코드에서 센 추정이다(fork 수 · python 기동 수 · clone 수).

## 묶음 deep-12

### shared/tests/test_docreview_gate_plain.sh
- 초: 11.9
- 줄 수: 159
- 고친 횟수: 8
- 크기: 중간 — 행마다 임시 원장을 새로 짓고(init · snapshot · begin-round · seed · 때로 next_round 두 번) docreview_state.py gate --render 를 python 하위 프로세스로 돌린다
- 종류: 섞임(동작 53 · 구조 0 · 글자 10 · 변이 0)
- 지키는 것: 게이트 렌더의 모든 줄에서 지적 id · AC 번호 · § 가 괄호 밖에 새지 않아, 사람이 읽는 승인 화면에 내부 기호가 섞이지 않는다(각 행 상태가 실제로 렌더됐다는 양성 짝 포함).
- 거짓 실패 위험: 높음 — 양성 짝이 렌더 문구 전체(예: 「이 결정 때문에 함께 바뀐 곳 1개 (D1.1)」 · 「「미검증」 리뷰어(doc-critic)가 결과를 내지 못해」)와 reviewing-document.md 의 규칙 문장 전체를 글자 그대로 찾아, 렌더 · 절차서 문구를 다듬기만 해도 깨진다
- 겹침: shared/tests/test_docreview_gate_visibility.sh — GATE_ROWS 행마다 「그 상태 하나만 산 원장」을 같은 픽스처(F_DEC · F_FIX · decide adopt/hold · next_round · st_set_stale_pointer)로 짓고 gate --render 를 본다(같은 준비를 두 파일이 따로 한다); test_docreview_route.sh 의 case_gate_render_six_lines · case_plain_render_* · case_T46_* 도 같은 렌더 첫 줄을 잰다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 행별 원장 준비가 gate_visibility 와 같아, 한 번 지은 원장의 렌더에 가시성(id 가 있다)과 기호 누출(괄호 밖엔 없다)을 함께 재면 준비가 절반으로 준다
- 확신: 중간
- 확인 수: 약 63개 (동작 53 · 구조 0 · 글자 10 · 변이 0) — 계측기 양성 대조 2 · 행별 누출 21 · 행별 양성 짝 30 · 골든 gate.txt 5 + 바닥 1 · 절차서 문장 4
- 시간을 쓰는 곳: 추정 — 21행마다 r1(init · snapshot · begin-round 로 python 3회)+seed+decide/fix 를 새로 띄우고, cap_* · stagnation 행은 next_round(행마다 python 5회)를 두 번 더 돈다; 렌더마다 outside_parens 용 python 을 한 번 더 띄운다
- 구조 고치기 여지: 준비 함께 쓰기 — gate_visibility 의 gv_reach_<행> 픽스처를 그대로 쓰거나 한 파일로 합쳐 행마다 원장 한 번 · 렌더 한 번으로; outside_parens 를 렌더 결과 묶음에 한 번만 돌리기

### shared/tests/test_docreview_intent.sh
- 초: 7.5
- 줄 수: 20
- 고친 횟수: 4
- 크기: 중간 — 케이스마다 임시 원장(r1)을 짓고 docreview_anchor.py check-intent · docreview_state.py 를 python 하위 프로세스로 돌린다
- 종류: 동작
- 지키는 것: 고치기 전 확인(check-intent)이 finding 의 고칠 범위 밖 · 보호 절 · 불변 절(사용자 원문) · 삽입 대상이 보호/불변인 경우 · 없는 앵커 · 낡거나 소모된 permit 을 정해진 사유로 거부하고 그 fix 를 escalated 로 올려, 허가 없는 문서 수정이 통과하지 않는다.
- 거짓 실패 위험: 낮음 — rc 와 사유 코드(scope_outside_edit_scope · anchor_immutable 등) · 원장 상태 값만 보므로 거부 동작이 바뀔 때만 깨진다
- 겹침: shared/tests/test_docreview_mutations.sh — case_AC6_fix_contract · case_AC23_general_fix_anchor_unresolved 를 깨끗한 사본에서 한 번 더 돌린다(양성 대조); plugins/spec-distill/tests/test_ledger_wiring.sh 등은 절차서 쪽 배선만 본다(확인 못 함 — 이름 검색만)
- 보안 갈래: 예
- 판정 후보: 둠 — 편집 허가 경계(보호 · 불변 절)를 사유 코드까지 실행으로 재고 6케이스 7.5초로 비용이 맞다
- 확신: 높음
- 확인 수: 약 27개 (동작 27 · 구조 0 · 글자 0 · 변이 0) — 6케이스
- 시간을 쓰는 곳: 추정 — 케이스 안에서 하위 상황마다 r1 을 새로 지어(케이스당 2~6회, 회당 python 3회) seed · check-intent · jgets · st_yaml 을 각각 python 으로 띄운다; case_AC6_permit_contract · reject_reasons_extra 는 next_round(python 5회)도 돈다
- 구조 고치기 여지: 준비 함께 쓰기 — 같은 프로필 · 문서의 r1 원장을 한 번 지어 cp -R 로 복제(init · snapshot · begin-round 3회 → cp 1회); 이 파일 단독 이득은 작다

### shared/tests/test_docreview_mutations.sh
- 초: 233.0
- 줄 수: 930
- 고친 횟수: 64
- 크기: 큼 — 변이 셀 119개마다 엔진 스크립트 사본을 만들고 sed 로 망가뜨린 뒤 cases.sh 케이스를 서브셸에서 다시 돌리며, 케이스마다 깨끗한 사본에서도 한 번 돌린다(양성 대조)
- 종류: 변이
- 지키는 것: docreview 엔진의 규칙(얼림 diff 의 사후 decide · 보호/불변 절 승격 · permit 라운드 경계 · 재상승/escalated 누적 · dedup · 계수 · 원장 정체 · 원자 쓰기 · 시대 표지 · 쉬운 말 렌더 등)을 하향으로 뒤집으면 행동 락의 해당 케이스가 실제로 빨개진다는 것, 곧 행동 락에 이빨이 있다는 것을 지킨다.
- 거짓 실패 위험: 높음 — 셀마다 sed 가 엔진 소스의 정확한 줄 모양(들여쓰기 · 꼬리 주석 · 변수 이름)과 선언 churn(삭제/추가 줄 수)에 묶여 있어, 동작이 같은 리팩터 · 줄 정리 · 변수 개명만으로도 「치환 앵커 소실(계측기 고장)」로 깨진다(파일 주석에 재앵커 기록이 여럿)
- 겹침: shared/tests/test_docreview_route.sh · test_docreview_state.sh · test_docreview_intent.sh · test_docreview_anchor.sh · test_docreview_advice.sh · test_docreview_ask.sh — 셀이 겨누는 서로 다른 케이스 89개 중 87개가 이 행동 락들에 이미 등록돼 있어, 깨끗한 사본 양성 대조가 같은 케이스를 한 바퀴에 한 번 더 GREEN 으로 돈다; 반대로 case_AC21_unconsumed_counted · case_reraise_successor_immune_to_recritic 두 케이스는 행동 락 어디에도 없고 이 행렬에서만 불린다(test_docreview_state.sh 주석이 「매트릭스에서만 불리면 규칙이 깨져도 계측기 고장으로만 보고된다」고 적은 바로 그 꼴)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(행동 락의 이빨)은 그대로 두고, 깨끗한 사본 실행을 행동 락과 나누거나 묶고, 서브셸마다 반복되는 준비를 덜고, 독립 셀을 병렬로 돌리면 크게 싸진다
- 확신: 중간
- 확인 수: 약 129개 (동작 0 · 구조 0 · 글자 0 · 변이 129) — 초기 양성 대조 7 · 계측기 탐침 1 · 변이 셀 119(카나리아 1 포함, 기대 unmeasurable) · 앵커 소실 가드는 셀마다 판정 앞에 붙는다
- 시간을 쓰는 곳: 추정 — 케이스 실행 약 208회(변이 119 + 깨끗한 사본 89, 캐시로 케이스당 1회); 실행마다 서브셸이 assert.sh · cases.sh(4773줄) · cases_advice.sh(1097줄)를 새로 source 하고 nofield_profiles.sh(bash + python 해시)를 다시 돌린 뒤 케이스 본문의 python 하위 프로세스 수십 개를 띄운다(r1 · next_round · jgets · st_yaml); 셀마다 _churn 이 diff 를 파일 7개 × 2회 띄우고 mkclone 이 .py 7개를 복사한다
- 구조 고치기 여지: 준비 함께 쓰기 — 부모에서 DOCREVIEW_PROF_SD 를 한 번 구해 export(서브셸마다 nofield_profiles.sh 생략), 깨끗한 사본 89회는 행동 락의 같은 케이스 결과로 갈음하거나 서브셸 하나에서 묶어 돌리기; 나누기 — 셀은 서로 독립(사본 디렉토리가 따로)이라 병렬 실행 · 엔진 파일별(route · state · advice) 파일 분할 가능; 빈칸 메우기 — 행렬 전용 두 케이스를 행동 락에 등록

### shared/tests/test_docreview_route.sh
- 초: 76.1
- 줄 수: 139
- 고친 횟수: 52
- 크기: 중간 — 케이스마다 임시 원장을 짓고 docreview_route.py(prepare-recritic · finalize) · docreview_state.py(gate) 를 python 하위 프로세스로 돌린다
- 종류: 동작
- 지키는 것: 라우터가 리뷰어 finding 을 익명화 · same_as 병합(높은 처분 유지) · 재비판 판정(raise/reject 근거 요구) · 보호/불변 절 승격 · permit 범위 · id/계보 배정 · 재상승/escalated 이월 · codex/critic 사망과 시점 판별 · 「미검증」 라운드 · 탐지 리뷰어 여럿의 병합과 일부 사망 공시 · 게이트 쉬운 말 렌더를 바르게 해, 리뷰 지적이 조용히 사라지거나 잘못된 처분으로 승인을 열지 않게 한다.
- 거짓 실패 위험: 중간 — 대부분 처분 · 사유 코드 · 계수를 보지만, 렌더 계열 케이스(case_plain_*, case_gate_*, case_first_line_*)는 첫 줄 · 항목 문구를 글자로 맞춰 렌더 문구를 다듬으면 깨진다
- 겹침: shared/tests/test_docreview_mutations.sh — 이 파일 케이스 다수를 깨끗한 사본에서 한 번 더 돈다; shared/tests/test_docreview_golden.sh — finalize 출력 골든(fin.json · state.md)이 같은 라우팅 결과를 통째로 잰다(확인 못 함 — 이름만 확인); shared/tests/test_docreview_gate_plain.sh · test_docreview_gate_visibility.sh — 게이트 렌더 첫 줄 · 행 렌더가 겹친다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 121케이스가 각자 원장을 처음부터 짓고 단언마다 python 을 새로 띄워 76초를 쓴다; 지키는 것은 그대로 두고 준비 공유 · 단언 묶기로 줄일 수 있다
- 확신: 중간
- 확인 수: 약 424개 (동작 424 · 구조 0 · 글자 0 · 변이 0) — 121케이스(본문의 assert/ok/no 수를 센 어림, 렌더 문구 단언도 실행 결과를 보므로 동작으로 셈)
- 시간을 쓰는 곳: 추정 — 케이스마다 r1 · route_r1(init · snapshot · begin-round · critic 사본 · prepare-recritic · 재비판 렌더 · finalize 로 python 5~7회)을 새로 돌리고, 케이스 본문에서 보이는 python 호출만 약 680회(jget · jgets · fsum · gsum · gfirst 가 단언마다 python 을 따로 띄운다); docreview_state.py(약 3000줄)+yaml import 가 매 호출 반복된다
- 구조 고치기 여지: 준비 함께 쓰기 — 같은 프로필 · 문서 · critic 의 route_r1 결과를 한 번 지어 cp -R 로 복제; 더 싼 확인으로 내리기 — 한 케이스의 여러 jget/jgets 단언을 python 한 번으로 묶어 값 묶음을 받기; 나누기 — 렌더 계열(약 30케이스)과 라우팅 계열을 파일로 갈라 병렬 실행

### shared/tests/test_docreview_state.sh
- 초: 134.4
- 줄 수: 174
- 고친 횟수: 45
- 크기: 중간 — 케이스마다 임시 원장을 짓고 라운드를 여러 번 넘기며 docreview_state.py · docreview_anchor.py 를 python 하위 프로세스로 돌린다
- 종류: 동작
- 지키는 것: 원장 상태 전이(채택 → permit · 기각 · 보류 · 적용/원복 관측 · 만료 · 재상승 · escalated)와 상한 · 정체 · 승인 게이트 도출, 불변 절(사용자 원문 · 결정 기록) 덧붙이기만 허용 · 위조 줄 · 확인값(digest) 불일치 · 시대 표지 · 원장 정체(다른 문서/프로필 거부) · 설정 우선순위를 지켜, 사람이 내린 결정과 보호 절이 조용히 바뀌거나 우회되지 않게 한다.
- 거짓 실패 위험: 중간 — 대부분 상태 값 · 사유 리터럴 · 계수를 보지만, 일부(case_AC22_post_expiry_render_tail · case_AC13_* · 렌더 꼬리)는 렌더 문구를 글자로 맞춘다
- 겹침: shared/tests/test_docreview_mutations.sh — 행렬이 겨누는 케이스(case_T37 · case_AC21 · case_AC22 · case_GR · case_init · case_AC17 등)를 깨끗한 사본에서 한 번 더 돈다; shared/tests/test_docreview_gate_visibility.sh — case_GR_* 와 같은 GATE_ROWS 행 차단 · 가시성을 다른 각도로 잰다; plugins/spec-distill/tests/test_state_dir_writes.sh — 원장 쓰기의 링크 거절(부분 겹침)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 138케이스 중 next_round 호출이 약 160회(회당 python 5회)라 134초를 쓴다; 지키는 것(위조 · 불변 절 · 결정 기록 울타리 포함)은 그대로 두고 라운드 준비를 공유하면 줄어든다
- 확신: 중간
- 확인 수: 약 564개 (동작 564 · 구조 0 · 글자 0 · 변이 0) — 138케이스(본문 assert/ok/no 수를 센 어림)
- 시간을 쓰는 곳: 추정 — next_round 가 snapshot · begin-round · exempt-anchors · diff · observe-diff 로 python 5회를 띄우고 이것이 약 160번 불린다; 케이스마다 r1/mk_state(python 3회)를 새로 짓고, 케이스 본문에서 보이는 python 호출만 약 1200회(st_yaml · jgets · 인라인 python -c 로 원장을 직접 고치는 픽스처); 엔진 import(약 3000줄 + yaml)가 호출마다 반복된다
- 구조 고치기 여지: 준비 함께 쓰기 — 「r1 + F_DEC 심기 + 채택」 · 「라운드 2 변경 없음」 같은 자주 쓰는 중간 원장을 한 번 지어 복제; 더 싼 확인으로 내리기 — st_yaml 단언 여럿을 python 한 번으로 묶기, 또는 순수 상태 전이 케이스는 엔진 함수를 한 프로세스 안에서 부르는 python 단위 테스트로 옮기기; 나누기 — AC38 감사 행 · AC17 확인값 · config 묶음을 파일로 갈라 병렬 실행

### shared/tests/test_invocation_surface.sh
- 초: 20.8
- 줄 수: 449
- 고친 횟수: 21
- 크기: 큼 — 합성 리포 변이 약 70개마다 cp -R 사본을 만들고, 레포 전체를 git clone --no-local 한 뒤 그 사본을 9번 통째로 cp -R 하며, 바깥 CLI(claude plugin validate --strict)를 3번 부른다
- 종류: 섞임(동작 45 · 구조 0 · 글자 0 · 변이 85)
- 지키는 것: 호출 표면 검사기(check_invocation_surface.py)가 축 A~I(진입 skill 이름 규칙 · 내부 skill 동명사 · 사전 검사 `!` 줄 하나와 그 꼴 · `!` 줄에 사용자 인자($ARGUMENTS · $1) 금지 · 미지 frontmatter 키 · 사용자 전용 skill · 풀리지 않는 완전명/bare 이름 · commands/ 층 · 옛 이름)를 실제로 잡고 오탐하지 않으며, 이 레포가 그 규칙을 지키고, 세 플러그인 manifest 가 validate --strict 를 통과한다는 것을 지킨다.
- 거짓 실패 위험: 중간 — 합성 변이는 검사기 사유 문구의 일부(「이 디렉토리」 · 「정확히 하나」 등)를 grep 해 사유 문구를 다듬으면 깨지고, 4부 판정기는 validate JSON 의 최상위 · directory 하위 키를 닫힌 집합으로 봐 CLI 가 키를 더하기만 해도 깨진다
- 겹침: shared/tests/test_skill_cost_class_place.sh — 같은 검사기로 metadata 아래 cost_class(축 E 의 일부)를 잰다; 한 파일 안에서 2부(이 리포 검사기 GREEN)와 3부 첫 단언(clone HEAD GREEN)이 커밋 상태가 같으면 같은 확인을 되풀이한다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 지키는 것(축 D 인자 주입 금지 포함)은 그대로 두고, 3부의 「사본 9번 통째 복사」를 한 사본에서 변이 · 되돌리기(git checkout -- . · git clean)로 바꾸고 2부 · 3부 HEAD 검사 중복을 덜면 싸진다
- 확신: 중간
- 확인 수: 약 130개 (동작 45 · 구조 0 · 글자 0 · 변이 85) — 1부 합성 변이 · 음성 대조 약 74 · 2부 1 · 3부 실제 변이 10 · 4부 판정기 합성 JSON 약 42 · validate 실측 3
- 시간을 쓰는 곳: 추정 — 3부가 레포 전체(약 40MB pack + 1647파일)를 clone 하고 그 사본을 변이마다 9번 cp -R 해 레포 전체에 검사기를 10번(2부 포함 11번) 돌린다; 4부 claude CLI 3회 기동; 1부는 합성 리포가 작아 cp -R · 검사기 python 약 75회가 수 초를 쓴다
- 구조 고치기 여지: 준비 함께 쓰기 — 3부는 clone 하나에서 변이 하나 → 검사 → git checkout -- . && git clean -fdq 로 되돌리기(또는 clone 위 git worktree 로 객체 공유); 2부를 지우고 3부 HEAD GREEN 으로 갈음(또는 반대); 나누기 — 4부(바깥 CLI)를 따로 떼어 CLI 없는 환경 · 빠른 바퀴에서 건너뛰게

### shared/tests/test_nofollow_write.sh
- 초: 6.6
- 줄 수: 682
- 고친 횟수: 4
- 크기: 중간 — 임시 폴더에 심볼릭 · 하드 링크를 심고 nofollow_write.py · 공유 codex 러너(가짜 codex 스텁)를 하위 프로세스로 돌린다
- 종류: 섞임(동작 160 · 구조 6 · 글자 2 · 변이 44)
- 지키는 것: 공용 writer 가 출력 자리의 심볼릭 · 하드 링크를 따라가지 않아 레포 밖 파일을 덮지 않고(run · empty · append 각 모드, 실패 시 rc 73 · 임시 파일 안 남김 · 권한 = 셸 > 와 같음), 공유 codex 러너가 $OUTPUT_PATH 를 writer 로만 쓰며 상대 경로로 불려도 리뷰 대상 폴더에 심은 nofollow_write.py 를 실행하지 않는다는 것을 지킨다.
- 거짓 실패 위험: 중간 — writer 부분은 rc · 파일 내용만 봐 낮지만, 러너 잠금의 변이는 러너 문면(OVERRIDE_REASON="" 줄 · _RUNNER_DIR 대입 줄의 정확한 글자)에 기대 러너를 다듬으면 「변이가 적용되지 않았다」로 깨진다
- 겹침: plugins/spec-distill/tests/test_state_dir_writes.sh — skill 스크립트 · 펜스의 상태 폴더 쓰기 링크 거절(부분 겹침, writer 자체 동작은 아님); shared/tests/test_codex_runner_scratch_trap_order.sh — 같은 러너의 trap 순서(다른 축); plugins/quality-gates/tests/test_codex_copies_agree.sh — 러너 사본 일치(다른 축)
- 보안 갈래: 예
- 판정 후보: 둠 — 링크 따라가기로 레포 밖 파일을 덮는 경로 탈출 경계와 리뷰 대상 폴더의 코드 심기를 실행으로 재고, 약 210개 확인에 6.6초로 비용이 맞다
- 확신: 높음
- 확인 수: 약 212개 (동작 160 · 구조 6 · 글자 2 · 변이 44) — writer 모드별 약 85 · 링크 도출 약 7 · 러너 잠금 5 + 변이 22행(행마다 rc · 사유) · 러너 끝에서 끝 약 62 · 상대 경로 심기 5
- 시간을 쓰는 곳: 추정 — nw 호출마다 python 을 새로 띄운다(약 50회); 러너 끝에서 끝 12회가 bash 러너 + 스텁 + 변환 python 을 돈다; 러너 잠금 파서(heredoc 의 약 330줄 python)를 변이 22행 × (mutate + check) 약 45회 띄운다 — 모두 가벼워 합이 작다
- 구조 고치기 여지: 없음

### tools/suite/test_suite_timing.py
- 초: 11.7
- 줄 수: 672
- 고친 횟수: 7
- 크기: 큼 — 임시 git 레포를 약 19개 만들어 run-all.sh 를 약 20번 돌리고(안에서 다시 테스트 러너를 돈다), 실제 ps 와 가짜 러너 프로세스 · sleep 을 쓴다
- 종류: 섞임(동작 95 · 구조 15 · 글자 0 · 변이 0)
- 지키는 것: 스위트 러너(run-all.sh · run_unittest_dir.py · suite_peers.py)가 SUITE_TIMING_FILE 을 켜도 출력 · rc 가 같고, 대상마다 시간 줄과 start/end 줄 · 동시 러너 수를 바르게 적으며(안쪽 러너 · 자기 조상 · 하위 셸은 세지 않음), 기록 실패 · 상대 경로 · 측정 불가를 한 번 알리고 「?」 로 적는다는 것을 지켜, 스위트 시간 측정이 틀린 숫자를 내거나 테스트 결과를 바꾸지 않게 한다.
- 거짓 실패 위험: 중간 — 실제 ps 를 읽는 두 케이스 · 중간에 죽이는 케이스는 머신 부하와 프로세스 타이밍에 기대고, stderr 안내 문장을 글자 그대로 맞춰 문구를 다듬으면 깨진다
- 겹침: 못 찾음 — suite_peers · run_unittest_dir · SUITE_TIMING_FILE 을 다루는 다른 테스트 없음(shared/tests/test_shell_tests_executable.sh 는 run-all.sh 이름만 언급)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 시간 측정 도구가 스위트 결과를 바꾸지 않는다는 것과 동시 러너 계수를 실행으로 재고 11.7초로 비용이 맞다(아래 여지만큼 줄일 수 있다)
- 확신: 중간
- 확인 수: 약 110개 (동작 95 · 구조 15 · 글자 0 · 변이 0) — PeerCount 11케이스 · UnittestDir 8케이스 · RunAll 16케이스(시간 줄 모양 정규식은 구조로 셈)
- 시간을 쓰는 곳: 추정 — test_real_ps_self_ancestor_child_excluded 가 가짜 러너 b 의 `( sleep 3 ) & wait` 를 끝까지 기다려 약 3초; test_wait_returns_at_zero_and_times_out 의 --wait 1 약 1초; RunAll 케이스마다 make_repo(git init · git add)와 run-all.sh(작은 스위트 + python unittest + 있으면 node)를 1~3번 돈다(약 20회); test_killed_round 는 sh 줄 둘이 찰 때까지 폴링한 뒤 죽인다
- 구조 고치기 여지: 더 싼 확인으로 내리기 — self_ancestor 케이스의 sleep 3 을 짧게(살아 있는 자식만 필요); 준비 함께 쓰기 — BASE · BASE_WITHOUT_FAIL 레포를 setUpClass 에서 한 번 지어 읽기만 하는 케이스(ac1 · ac3_start_count · toplevel · ac4 · ac27_relative · unknown_peer)가 함께 쓰기

#### 읽지 못한 것 — deep-12

- 없음 — 여덟 단위 모두 끝까지 읽었다. 다만 route · state · intent 의 케이스 본문은 공유 파일 shared/tests/fixtures/docreview/cases.sh(4773줄 · 고친 횟수 125) · cases_advice.sh(1097줄)에 있어 도우미(r1 · next_round · route_r1 · seed_findings)와 표본 케이스만 읽었고, 확인 수 · python 호출 수는 케이스 본문을 스크립트로 센 어림이다.
- test_docreview_golden.sh 와의 겹침은 이름(파일 주석 언급)으로만 확인했고 그 파일은 열지 않았다.

## 묶음 shallow-01

### plugins/plugin-audit/tests/audit-workflow.test.mjs
- 초: 0.2
- 줄 수: 803
- 고친 횟수: 15
- 크기: 작음 — node 한 프로세스 안에서 스텁 agent 로 워크플로를 케이스마다 돌린다(하위 프로세스 · git 없음). 두 테스트는 소스 텍스트를 읽는다
- 종류: 섞임(동작 80 · 구조 10 · 글자 10)
- 지키는 것: 감사 워크플로가 축별 스키마 · 판정 누락 공시 · 심층검증 표시 · 축 선택 검증을 어기면 미검증 지적이 검증된 것처럼 리포트에 실린다.
- 거짓 실패 위험: 중간 — 동작 검사는 낮으나 프롬프트 문구 일부(`축: 1` · 한국어 안내문)와 소스 텍스트 창 검사(`DEEP_CAP` · `n: 3,`)는 문구를 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_axis3_reachability_question.sh — 축 3 창의 `kill switch` 문구를 같은 소스 창으로 읽는다. 같은 파일 안에서 「양성 짝」 케이스가 많아 확인이 되풀이된다(deep_verified 짝 5회)
- 보안 갈래: 예(축 3 질문이 hook kill switch 가 아닌 기능 끄기 변수를 묻는지 확인)
- 판정 후보: 둠 — 0.2초로 싸고 판정 누락 · 축 분리는 동작 확인이라 지키는 것이 분명하다
- 확신: 높음

### plugins/plugin-audit/tests/smoke-workflow.test.mjs
- 초: 0.2
- 줄 수: 52
- 고친 횟수: 1
- 크기: 작음 — node 한 프로세스, 스텁 agent
- 종류: 섞임(동작 2 · 글자 1)
- 지키는 것: 스모크 워크플로가 agentType 을 `plugin-audit:smoke-probe` 로 고정하고 JSON 문자열 args 를 풀어 읽지 않으면 Law 2 자가 점검이 거짓 통과한다.
- 거짓 실패 위험: 중간 — spread 순서 정규식 락은 같은 뜻의 다른 표기로 고쳐 쓰면 깨진다
- 겹침: plugins/plugin-audit/tests/test_check_law2.py — 같은 smoke-workflow.js 의 agentType 고정을 check-law2 가 정적으로도 본다(TestSmokeMode)
- 보안 갈래: 예(agentType 고정 · Law 2 자가 점검)
- 판정 후보: 둠 — 작고 WB2 는 동작 확인이다. spread 순서 락만 check-law2 와 겹치는 정도
- 확신: 중간

### plugins/plugin-audit/tests/test_ac6_regression.py
- 초: 0.0
- 줄 수: 56
- 고친 횟수: 2
- 크기: 중간 — assemble-audit-data.py 를 하위 프로세스로 한 번 실행
- 종류: 섞임(동작 1 · 구조 1)
- 지키는 것: 일반화한 조립 스크립트가 옛 기준 산출(finding id · 상태 · cross_model_confirmed · d_verdicts 출처 분포)을 그대로 재현하지 않으면 감사 결과가 옛 감사와 어긋난다.
- 거짓 실패 위험: 중간 — 기준 JSON 과 픽스처가 조립 규칙을 바꿀 때마다 같이 고쳐져야 한다
- 겹침: plugins/plugin-audit/tests/test_run_dir_pipeline.py — 같은 ac6 픽스처로 assemble 을 돌린다. test_assemble_audit_data.py 가 같은 분기를 합성 입력으로 더 자세히 본다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 두 번째 테스트(CX-2 · A6-1 이 기준 파일에 있다)는 고정 JSON 을 읽을 뿐이라 조립 동작을 지키지 않는다
- 확신: 중간

### plugins/plugin-audit/tests/test_agents_generic.py
- 초: 0.0
- 줄 수: 60
- 고친 횟수: 3
- 크기: 작음 — agent 마크다운 파일 읽기 · 문구 검사
- 종류: 섞임(구조 2 · 글자 4)
- 지키는 것: 감사 agent 셋의 frontmatter `tools:` 가 안전 도구 부분집합이고 denylist 를 쓰지 않아 감사자가 쓰기 권한을 갖지 못한다(Law 2).
- 거짓 실패 위험: 중간 — tools 검사는 낮으나 `or drop it` · `verdict: uncertain` 류 글자 확인은 문구를 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_check_law2.py — 같은 agent 의 tools allowlist 를 check-law2.py 가 실제 게이트로 본다(실제 agents 디렉터리 GREEN 락)
- 보안 갈래: 예(agent 도구 allowlist · 리뷰어 프로필)
- 판정 후보: 줄임 — tools 부분집합 검사는 지키되 `or drop it` · `uncertain` 류 문구 글자 검사 셋은 동작을 정하지 않는다. 도구 검사는 check-law2 와 합칠 수 있다
- 확신: 중간

### plugins/plugin-audit/tests/test_assemble_audit_data.py
- 초: 0.6
- 줄 수: 385
- 고친 횟수: 8
- 크기: 중간 — assemble-audit-data.py 를 케이스마다 하위 프로세스로 실행(약 20회) + 임시 폴더. 일부는 render · validate 도 실행
- 종류: 섞임(동작 95 · 구조 5)
- 지키는 것: 조립 단계가 깨진 codex 출력에 죽지 않고, 죽은 축을 빈칸 채움으로 드러내며, cross-model 확인 · gate-E 회수 · 접지 폐기를 정확히 처리하지 않으면 감사 리포트가 조용히 틀리거나 통째로 죽는다.
- 거짓 실패 위험: 낮음 — 출력 JSON 의 값만 보며 동작이 바뀔 때만 깨진다(일부 한국어 사유 문구 일치 제외)
- 겹침: plugins/plugin-audit/tests/test_validate_audit_data.py — gate-E NOQ 와 backfill 을 같은 방식으로 조립 후 검증한다. test_plain_audit_text.py 의 AssembleTextTest 가 같은 backfill 사유를 본다
- 보안 갈래: 예(비정상 codex 입력으로 조립을 죽이는 DoS 방어)
- 판정 후보: 둠 — 실제 동작 검증이고 0.6초로 싸다. 케이스마다 python 을 새로 띄우지만 총량이 작다
- 확신: 높음

### plugins/plugin-audit/tests/test_axis3_reachability_question.sh
- 초: 0.1
- 줄 수: 46
- 고친 횟수: 1
- 크기: 작음 — awk · grep 으로 audit-workflow.js 한 파일을 읽는다
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/plugin-audit/scripts/audit-workflow.js 축 3 창의 `무엇을 막는가` · `systemMessage` · `도착했는지 확인하는 자리` 문구와 `n: N,` 여섯 줄
- 거짓 실패 위험: 높음 — 질문 문구를 다듬거나 줄 모양(`n: 3,`)을 바꾸기만 해도 깨진다
- 겹침: plugins/plugin-audit/tests/audit-workflow.test.mjs — 같은 축 3 창을 읽어 `kill switch` 문구를 확인한다
- 보안 갈래: 아니오
- 판정 후보: 지움 — 감사자에게 가는 질문 문장 존재만 확인하고 동작을 정하지 않는다. 질문 문구 변경은 리뷰가 맡는 편이 낫다
- 확신: 중간

### plugins/plugin-audit/tests/test_check_grounding.py
- 초: 0.0
- 줄 수: 147
- 고친 횟수: 2
- 크기: 작음 — check-grounding.py 를 모듈로 불러 함수 호출. 임시 폴더만
- 종류: 동작
- 지키는 것: 인용 접지 검사가 위조 · 부재 · 빈 · 비문자열 인용과 repo 밖 경로를 통과시키지 않고 죽지도 않아야 존재하지 않는 근거로 쓴 지적이 리포트에 남지 않는다.
- 거짓 실패 위험: 낮음 — 동작이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_assemble_audit_data.py — 조립 경로로 접지를 live 로 한 번 더 태운다(진입점 차이)
- 보안 갈래: 예(repo 밖 파일 읽기 오라클 차단 · 비신뢰 입력 크래시 방어)
- 판정 후보: 둠 — 싸고 보안 경계를 동작으로 확인한다. 비문자열 케이스 셋은 한 테스트에 이미 묶여 있다
- 확신: 높음

### plugins/plugin-audit/tests/test_check_integrity.py
- 초: 1.0
- 줄 수: 128
- 고친 횟수: 1
- 크기: 중간 — 케이스마다 임시 git 레포를 init · commit 하고 check-integrity.sh 를 한두 번 실행(8케이스)
- 종류: 동작
- 지키는 것: 무결성 해시 목록이 형제 marketplace 편집 · `.DS_Store` 에는 변하지 않고 내용 있는 오염에는 변하지 않으면 정상 실행이 무효 처리되거나 오염이 통과한다.
- 거짓 실패 위험: 낮음 — 스크립트 동작이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_plain_audit_text.py — IntegrityTextTest 가 같은 스크립트의 오류 줄을 확인한다(다른 측면)
- 보안 갈래: 예(감사 대상이 감사 중 변조되지 않았는지 확인하는 무결성 백스톱)
- 판정 후보: 구조를 고침 — 케이스마다 git init · add · commit 을 새로 하므로 읽기 전용 케이스는 한 레포를 함께 쓸 수 있다
- 확신: 중간

### plugins/plugin-audit/tests/test_check_law2.py
- 초: 0.2
- 줄 수: 90
- 고친 횟수: 3
- 크기: 중간 — check-law2.py 를 하위 프로세스로 6회 실행
- 종류: 동작
- 지키는 것: Law 2 게이트가 본문에만 있는 `tools:` 를 frontmatter 로 오인하지 않고 실제 워크플로 · agents 가 통과하며 기본 agents 경로가 cwd 사본이 아닌 설치본을 읽어야 쓰기 권한 있는 리뷰어가 통과하지 못한다.
- 거짓 실패 위험: 낮음 — 게이트 동작이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_agents_generic.py — 같은 agent 파일의 tools 를 글자로 본다
- 보안 갈래: 예(Law 2 · agent 도구 allowlist 게이트)
- 판정 후보: 둠 — Law 2 집행 게이트를 동작으로 확인하고 비용이 작다
- 확신: 높음

### plugins/plugin-audit/tests/test_check_no_verdict_injection.py
- 초: 0.2
- 줄 수: 91
- 고친 횟수: 1
- 크기: 중간 — check-no-verdict-injection.py 를 하위 프로세스로 10회 실행
- 종류: 동작
- 지키는 것: 판정 주입 게이트가 감사자에게 가는 표면(seed 포함)의 `철회됨` · `사실 오류` · 대문자 CONFIRMED 같은 결론 문구를 막지 않으면 감사자가 미리 정해진 결론을 받아 독립성이 깨진다.
- 거짓 실패 위험: 낮음 — 금지 토큰 목록이 바뀔 때만 깨진다. 단 `test_real_surfaces_are_green` 은 실제 표면 문구를 고치면 같이 깨진다
- 겹침: 못 찾음
- 보안 갈래: 예(비신뢰 seed 의 판정 주입 방어)
- 판정 후보: 둠 — 게이트 동작 확인이고 싸다
- 확신: 높음

### plugins/plugin-audit/tests/test_check_plugin_structure.py
- 초: 2.8
- 줄 수: 191
- 고친 횟수: 5
- 크기: 중간 — 가짜 plugin-dev 폴더와 대상 폴더를 만들고 bash 스크립트(내부에서 하위 스크립트 호출)를 9회 실행. 초 대부분은 bash 하위 스크립트
- 종류: 동작
- 지키는 것: plugin-dev 검증기가 없거나 죽거나 호환되지 않을 때 구조 검사가 가짜 사실을 내지 않고 degrade 로 알려야 감사자가 틀린 증거를 받지 않는다.
- 거짓 실패 위험: 낮음 — degrade · 집계 동작이 바뀔 때만 깨진다. `2개` 같은 한국어 표기 일치는 문구를 바꾸면 깨진다
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 케이스마다 같은 가짜 plugin-dev 와 target 을 새로 만든다. 같은 입력을 함께 쓰거나 한 번의 실행에서 여러 확인을 하면 줄어든다
- 확신: 중간

### plugins/plugin-audit/tests/test_check_shape_completeness.py
- 초: 0.8
- 줄 수: 268
- 고친 횟수: 8
- 크기: 중간 — check-shape-completeness.py 를 케이스마다 하위 프로세스로 실행(약 30회) + 임시 폴더
- 종류: 섞임(동작 85 · 구조 10 · 글자 5)
- 지키는 것: 형태 완결성 검사가 cost_class · plugin.json 필드 · 교차 플러그인 의존 선언 부재를 정확히 가려내고 깨진 plugin.json 에도 죽지 않아야 감사자가 받는 shape 사실이 맞다.
- 거짓 실패 위험: 중간 — 동작 검사는 낮으나 `test_checklist_synced_with_claude_md` 는 CLAUDE.md 문구 앵커를 읽어 문서를 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_check_staleness.py — cost_class 부재 판정을 같은 규칙으로 따로 확인한다. `test_two_copies_are_identical` 이 두 스크립트의 같은 함수를 맞춘다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — cost_class 파싱 케이스(약 12개)가 staleness 쪽 케이스(약 6개)와 같은 확인을 되풀이한다. 한쪽 파서를 공유하면 케이스를 한 곳으로 모을 수 있다
- 확신: 중간

### plugins/plugin-audit/tests/test_check_staleness.py
- 초: 2.6
- 줄 수: 713
- 고친 횟수: 7
- 크기: 중간 — check-staleness.py 를 케이스마다 하위 프로세스로 실행(약 60회) + 임시 폴더
- 종류: 동작
- 지키는 것: 낡음 스윕이 존재하지 않는 경로 · 명령 주장, 버전 불일치, 초안 잔재 등을 사실로 내되 코드 펜스 · 자리표시자 · 브랜치 이름 같은 오탐을 내지 않아야 감사자가 거짓 증거를 받지 않는다.
- 거짓 실패 위험: 낮음 — 분류 규칙이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_check_shape_completeness.py — cost_class · Principles 부재 판정이 겹친다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 케이스마다 python 을 새로 띄우고 임시 플러그인을 만든다(약 60회, 2.6초). 파일이 713줄이라 클래스 단위로 나누거나 진입을 함수 호출로 내리면 싸진다
- 확신: 중간

### plugins/plugin-audit/tests/test_codex_audit_to_json.py
- 초: 0.4
- 줄 수: 164
- 고친 횟수: 3
- 크기: 중간 — codex_audit_to_json.py 를 하위 프로세스로 약 17회 실행
- 종류: 동작
- 지키는 것: codex 응답 변환기가 마지막 펜스 · 마지막 메시지를 채택하고 키 부재 · 타입 위반 · 빈 출력을 clean 이 아니라 실패로 표시해야 읽지 못한 감사가 「문제 없음」으로 기록되지 않는다.
- 거짓 실패 위험: 낮음 — 변환 동작이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_preamble_schema_parity.py — 같은 변환기를 preamble 예시로 다시 돌린다. test_plain_audit_text.py 의 PlainFieldTest 가 `plain` 통과를 끝에서 끝으로 본다
- 보안 갈래: 예(앞선 펜스 주입 방어 · 인증 오류 표시)
- 판정 후보: 둠 — 싸고 indeterminate ≠ clean 불변식을 동작으로 확인한다
- 확신: 높음

### plugins/plugin-audit/tests/test_detect_codex.py
- 초: 0.1
- 줄 수: 129
- 고친 횟수: 4
- 크기: 중간 — detect_codex.sh 를 하위 프로세스로 약 14회 실행. 두 테스트는 추적 중인 conf 파일을 덮었다가 되돌린다
- 종류: 섞임(동작 11 · 글자 3)
- 지키는 것: codex 탐지 스크립트가 미설치 · 인증 없음 · 낮은 버전 · kill switch · codex 샌드박스 안을 각각 건너뜀 사유로 내고 이웃 플러그인 끄기 변수는 무시해야 끈 사용자에게 codex 가 조용히 돌지 않는다.
- 거짓 실패 위험: 중간 — `CODEX_VERSION_FLOOR='0.118.0'` 리터럴과 정규식 락은 바닥 버전을 올리면 깨진다. conf 를 덮는 테스트는 중단되면 작업 트리를 더럽히고 병렬 실행과 겹칠 수 있다
- 겹침: plugins/quality-gates/tests/test_detect_codex.sh 및 plugins/spec-distill/tests/test_detect_codex.sh — 같은 스크립트의 형제 사본을 같은 14케이스로 본다
- 보안 갈래: 예(kill switch · 이웃 끄기 변수 무시 · fail-closed 설정)
- 판정 후보: 합침 — 세 플러그인이 같은 탐지기를 14케이스로 각각 확인한다. 한 곳의 공유 케이스로 모으고 이 파일에는 변수 이름 케이스만 둘 수 있다
- 확신: 중간

### plugins/plugin-audit/tests/test_parse_seed.py
- 초: 0.1
- 줄 수: 89
- 고친 횟수: 2
- 크기: 중간 — parse-seed.py 를 하위 프로세스로 5회 실행
- 종류: 동작
- 지키는 것: seed 파서가 단서 · 열린 질문 · 추가 scope 를 읽고 형식이 틀린 항목이나 빈 seed 를 조용히 버리지 않고 경고해야 사용자가 준 단서가 흔적 없이 사라지지 않는다.
- 거짓 실패 위험: 중간 — 경고 문구(`파싱 실패` · `인식된 항목이 0개`)를 stderr 에서 확인해 문구를 바꾸면 깨진다
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 작고 조용한 증발 방지를 동작으로 확인한다
- 확신: 높음

### plugins/plugin-audit/tests/test_plain_audit_text.py
- 초: 0.5
- 줄 수: 249
- 고친 횟수: 6
- 크기: 중간 — check-integrity.sh · assemble · render 를 약 10회 하위 프로세스로 실행하고 SKILL · README 를 읽는다
- 종류: 섞임(동작 40 · 글자 60)
- 지키는 것: 사람에게 나오는 고정 문구(codex 건너뜀 줄 · 종료 보고 틀 · 오류 줄 · 빈칸 채움 사유)가 쉬운 말인지 확인한다. `plain` 칸이 codex 변환기 → 조립 → 렌더까지 이어지는지는 동작으로 확인한다.
- 거짓 실패 위험: 높음 — SKILL · README · 오류 문구를 다듬기만 해도 깨진다(전체 문장 일치)
- 겹침: plugins/plugin-audit/tests/test_skill_orchestration.py — 같은 SKILL.md 의 종료 보고 · 문구를 따로 확인한다. test_render_audit_report.py 의 PlainLanguageReport 가 같은 렌더 문구를 확인한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — `plain` 끝에서 끝 흐름 한 테스트는 동작이라 지키고, SKILL · README 문장을 통째로 박은 글자 락은 쉬운 말 규칙을 한 번 확인하면 되는데 문장마다 핀을 박았다
- 확신: 중간

### plugins/plugin-audit/tests/test_preamble_schema_parity.py
- 초: 0.0
- 줄 수: 122
- 고친 횟수: 1
- 크기: 중간 — 변환기를 모듈로 불러오고 하위 프로세스로 1회 실행
- 종류: 섞임(구조 2 · 동작 1)
- 지키는 것: codex 에게 주는 preamble 의 응답 예시가 변환기 요구 스키마를 실제로 만족해야 codex 가 예시를 따라 답해도 감사가 schema_mismatch 로 실패하지 않는다.
- 거짓 실패 위험: 낮음 — 키 목록은 변환기에서 도출하고 예시도 변환기의 정규식으로 뽑아 스키마가 갈라질 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_codex_audit_to_json.py — 같은 변환기를 다른 입력으로 본다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 도출 방식이라 락이 스스로 낡지 않고 실제 파싱으로 확인한다
- 확신: 높음

### plugins/plugin-audit/tests/test_prepare_run_dir.py
- 초: 0.4
- 줄 수: 117
- 고친 횟수: 2
- 크기: 중간 — prepare-run-dir.py 를 하위 프로세스로 약 15회 실행 + 임시 폴더
- 종류: 동작
- 지키는 것: 실행 폴더 생성기가 키 있는 폴더를 만들고 `-2` 로 이어가며 잘못된 target · 날짜는 거부해 앞선 실행 산출을 덮지 않고 경로 탈출(`../x`)을 막아야 한다.
- 거짓 실패 위험: 낮음 — 동작이 바뀔 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_run_dir_pipeline.py — 같은 생성기를 파이프라인 안에서 한 번 더 돌린다
- 보안 갈래: 예(target 경로 탈출 거부)
- 판정 후보: 둠 — 경로 탈출 거부와 비덮어쓰기를 동작으로 확인하고 비용이 작다
- 확신: 높음

### plugins/plugin-audit/tests/test_render_audit_report.py
- 초: 1.0
- 줄 수: 532
- 고친 횟수: 10
- 크기: 중간 — render-audit-report.py 를 약 45회 하위 프로세스로 실행(케이스마다 임시 폴더) + 모듈 로드 몇 회
- 종류: 섞임(동작 90 · 구조 10)
- 지키는 것: 리포트 렌더러가 정렬 순서 · 축 분모 · degraded 배너 · codex 3상태 · 빈칸 표기를 맞게 그리고 6축 전멸 등에는 리포트를 만들지 않아야 읽는 사람이 정직하지 않은 리포트를 받지 않는다.
- 거짓 실패 위험: 중간 — 렌더 문구(`감사를 마쳤다 — …` · 배너 전체 문장)를 줄 단위로 일치시켜 문구를 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_plain_audit_text.py — 같은 렌더 배너 문구를 SKILL 인용과 함께 확인한다. plugins/plugin-audit/tests/test_severity_mapping.py — SEV_RANK 정렬 순서
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 한 케이스에 파이썬 프로세스 하나(45회). 렌더 함수를 모듈로 불러 호출하면 같은 확인이 훨씬 싸진다
- 확신: 중간

### plugins/plugin-audit/tests/test_run_audit_codex_reviewer.py
- 초: 0.6
- 줄 수: 146
- 고친 횟수: 5
- 크기: 중간 — 가짜 codex 를 임시 폴더에 두고 러너를 하위 프로세스로 약 6회 실행
- 종류: 섞임(동작 6 · 글자 2)
- 지키는 것: codex 러너가 프롬프트를 argv 가 아닌 stdin 으로 넘기고 `-s read-only` 로 호출하며 untrusted 절을 앞세우고 항상 산출물을 남겨야 codex 감사가 쓰기 권한을 얻거나 조용히 실패하지 않는다.
- 거짓 실패 위험: 낮음 — 계약이 바뀔 때만 깨진다. PATH 를 교체해 실제 codex 로 새지 않게 막아 두었다
- 겹침: plugins/plugin-audit/tests/test_untrusted_data_clause.py — 같은 untrusted 절. plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh — 형제 러너의 같은 절
- 보안 갈래: 예(read-only 샌드박스 · 프롬프트 argv 유출 방지 · untrusted 절 · kill switch 를 러너가 읽지 않음)
- 판정 후보: 둠 — 실행 관측으로 샌드박스 인자를 확인하는 보안 락이고 PATH 교체로 과금 호출도 막는다
- 확신: 높음

### plugins/plugin-audit/tests/test_run_dir_pipeline.py
- 초: 0.2
- 줄 수: 69
- 고친 횟수: 1
- 크기: 중간 — 임시 git 레포 하나를 만들고 prepare · assemble · validate · render · validate 를 차례로 실행
- 종류: 동작
- 지키는 것: 실행 폴더에서 post-1 을 끝까지 돌려도 사용자 레포의 `git status` 가 깨끗해야 감사 산출물이 사용자 작업 트리를 더럽히지 않는다.
- 거짓 실패 위험: 낮음 — 자기 ignore 가 사라지거나 파이프라인이 바뀔 때만 깨진다. 양성 대조가 있다
- 겹침: plugins/plugin-audit/tests/test_ac6_regression.py — 같은 ac6 픽스처. plugins/plugin-audit/tests/test_prepare_run_dir.py — 같은 생성기
- 보안 갈래: 아니오
- 판정 후보: 둠 — 끝에서 끝 한 번이고 싸다. 사용자 레포 청결이라는 지키는 것이 분명하다
- 확신: 높음

### plugins/plugin-audit/tests/test_run_own_tests_accumulate.sh
- 초: 0.6
- 줄 수: 111
- 고친 횟수: 3
- 크기: 중간 — 샌드박스 스텁과 임시 대상을 만들고 run-own-tests.sh 를 3회 실행. 그 안에서 unittest · 셸 테스트가 돈다
- 종류: 동작
- 지키는 것: 자체 테스트 러너가 여러 테스트 폴더를 전부 돌고 앞 폴더의 실패를 뒤 성공이 덮지 않으며 통과 · 전체 수를 실제로 세야 실패한 대상 플러그인이 통과로 읽히지 않는다.
- 거짓 실패 위험: 낮음 — 러너 동작이 바뀔 때만 깨진다. JSON 출력 문자열 일치라 공백 변형은 두 모양을 모두 받는다
- 겹침: plugins/plugin-audit/tests/test_run_own_tests.py — 같은 스크립트의 다른 테스트(이 묶음 밖이라 내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 스텁으로 샌드박스를 대신해 가볍고 fail-open 회귀를 동작으로 확인한다
- 확신: 중간

### plugins/plugin-audit/tests/test_severity_mapping.py
- 초: 0.0
- 줄 수: 75
- 고친 횟수: 3
- 크기: 작음 — render-audit-report.py 와 프리앰블을 읽고 SEV_RANK 한 줄을 exec
- 종류: 섞임(구조 3 · 글자 1)
- 지키는 것: 정렬 테이블이 정본 어휘 셋이고 순위가 엄격히 단조라야 리포트가 거꾸로 정렬되거나 옛 어휘로 갈라지지 않는다.
- 거짓 실패 위험: 중간 — `SEV_RANK` 가 줄 시작 한 줄 리터럴이어야 한다. 줄 모양을 바꾸면 깨진다
- 겹침: plugins/plugin-audit/tests/test_render_audit_report.py — 정렬 결과를 동작으로 확인한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 어휘 · 순서는 렌더 정렬 동작 테스트가 이미 본다. 프리앰블 옛 어휘 부재(d)만 따로 남기면 된다
- 확신: 중간

### plugins/plugin-audit/tests/test_skill_codex_gate.py
- 초: 0.0
- 줄 수: 97
- 고친 횟수: 3
- 크기: 작음 — SKILL.md 한 파일 읽기 · 정규식
- 종류: 글자
- 지키는 것: SKILL 의 codex 게이트가 산문이 아니라 bash 리터럴 `if` 이고 detect 가 러너보다 먼저 와야 kill switch 를 모델이 건너뛰지 못한다.
- 거짓 실패 위험: 높음 — 마커 모양 · bash fence 개수 · `codex exec` 부재 같은 글자에 걸려 SKILL 을 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_skill_orchestration.py — 같은 SKILL 의 codex 게이트 마커와 kill switch 이름을 확인한다. plugins/plugin-audit/tests/test_plain_audit_text.py 도 같은 gate 블록을 읽는다
- 보안 갈래: 예(codex kill switch 게이트 · 샌드박스 없는 codex 호출 부재)
- 판정 후보: 둠 — 글자 검사지만 SKILL 이 모델이 따르는 문서라 이 순서와 게이트 모양이 집행의 전부다. 보안 갈래라 지우지 않는다
- 확신: 중간

### plugins/plugin-audit/tests/test_skill_orchestration.py
- 초: 0.0
- 줄 수: 161
- 고친 횟수: 15
- 크기: 작음 — SKILL.md · README 읽기 · 문자열 검사
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/plugin-audit/skills/plugin-audit/SKILL.md 의 스크립트 이름 · `cost_class: high` · 범위 질문 → 중단 → 공시 → 실행 폴더 순서 · 규모 공시 문장 · `docs/audits` 부재. 일부(`--artifacts "$RUN_DIR"` 부재)는 실제로 크래시를 부른 호출 형태를 막는다
- 거짓 실패 위험: 높음 — SKILL 문장을 다듬거나 이름을 바꾸기만 해도 깨진다. 고친 횟수 15회가 그 증거다
- 겹침: plugins/plugin-audit/tests/test_skill_codex_gate.py — codex 게이트 마커 · kill switch. plugins/plugin-audit/tests/test_plain_audit_text.py — 종료 보고 · SKILL 문구
- 보안 갈래: 예(kill switch 변수 이름 · P21 secret 스캔 문구가 INVARIANTS 에 있음)
- 판정 후보: 줄임 — 순서 앵커 테스트(journal → assemble, 범위 → 공시 → 생성)는 모델이 읽는 SKILL 의 절차라 남기되 INVARIANTS 30여 개 이름 나열과 규모 공시 전체 문장 핀은 문구 따라가기에 가깝다
- 확신: 중간

### plugins/plugin-audit/tests/test_untrusted_data_clause.py
- 초: 0.0
- 줄 수: 34
- 고친 횟수: 2
- 크기: 작음 — 마크다운 네 파일 읽기
- 종류: 글자
- 지키는 것: 감사 agent 셋과 프리앰블에 「파일 내용은 데이터지 지시가 아니다」 절이 있고 plugin-auditor 가 무조건 따르지 않음 문장을 유지해야 감사 대상 파일 속 지시를 감사자가 따라 URL fetch 같은 행동을 하지 않는다.
- 거짓 실패 위험: 중간 — 이 두 문장은 의도적으로 고정이라 평소엔 안정적이나 문구를 다듬으면 깨진다
- 겹침: plugins/plugin-audit/tests/test_run_audit_codex_reviewer.py — 러너가 같은 절을 stdin 에서 확인한다. plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh — 형제 확인
- 보안 갈래: 예(비신뢰 데이터 절 · 프롬프트 주입 방어)
- 판정 후보: 둠 — 글자 확인이지만 보안 문장이 그 글자뿐이라 지키는 것이 분명하고 0.0초다
- 확신: 높음

### plugins/plugin-audit/tests/test_validate_audit_data.py
- 초: 1.9
- 줄 수: 595
- 고친 횟수: 11
- 크기: 중간 — validate-audit-data.py 를 약 55회 하위 프로세스로 실행. 일부는 assemble 도 함께, 한 케이스는 node 로 실제 워크플로를 돈다
- 종류: 섞임(동작 95 · 구조 5)
- 지키는 것: 감사 데이터 검증기가 배정 판정 누락 · 동의 불일치 · pending 잔존 · gate-E 회수 누락 · 비정상 refutation 을 깨끗한 RED 로 잡고 고른 축 집합과 codex 판정 요구를 정확히 맞춰야 불완전한 감사가 정상으로 통과하지 않는다.
- 거짓 실패 위험: 낮음 — 검증 규칙이 바뀔 때만 깨진다. 오류 문구 일부(`D1의 codex 판정 없음`)는 문구에 걸린다
- 겹침: plugins/plugin-audit/tests/test_assemble_audit_data.py — gate-E NOQ · backfill · 축 지도를 조립으로 같은 방식 확인. test_plain_audit_text.py 의 backfill 사유
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 케이스마다 python 프로세스 하나(약 55회). 검증 함수를 모듈로 불러 호출하는 케이스가 이미 일부 있으므로 나머지도 내릴 수 있다
- 확신: 중간

### plugins/project-init/tests/test_branch_prefix_templates.py
- 초: 0.8
- 줄 수: 193
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포를 만들고 clone(HookEnv). 여러 전략 × 케이스로 약 8회 init + clone
- 종류: 섞임(동작 40 · 글자 60)
- 지키는 것: 브랜치 접두 템플릿이 전략별 기본 접두와 맞고 훅이 문서에서 접두를 올바르게 뽑아 추가 접두를 허용하거나 거절해야 사용자 브랜치 이름 검사가 설정과 어긋나지 않는다.
- 거짓 실패 위험: 높음 — 템플릿 · SKILL 의 문장 일부(`reflog` · 「확인한다 — 그 이름이 …」 전체 문장)를 박아 두어 문구를 다듬으면 깨진다
- 겹침: plugins/project-init/tests/test_post_tool_use_branch.sh 와 plugins/project-init/tests/test_post_tool_use.py — 같은 훅의 브랜치 검사
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 훅 동작(derive · check)과 템플릿 문장 글자 락이 섞여 있다. 문장 락은 줄이고 HookEnv 의 git init · clone 은 전략마다 한 번만 만들 수 있다
- 확신: 중간

### plugins/project-init/tests/test_branch_strategy_rebase_clause.sh
- 초: 0.1
- 줄 수: 48
- 고친 횟수: 2
- 크기: 작음 — grep 으로 템플릿 세 파일을 읽는다
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/project-init/templates/{github-flow,git-flow}/branch-strategy.md 의 `공유된 브랜치는 rebase하지 않는다` 와 리포 루트 docs/git-workflow/branch-strategy.md 의 「`git rebase`는 절대 안 됨」 보존
- 거짓 실패 위험: 높음 — 문구를 다듬거나 파일을 옮기기만 해도 깨진다
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 지움 — 사용자 선호 문장이 어디 있다는 것만 확인하고 동작을 정하지 않는다. 양방향 락이라는 의도는 있으나 문장 하나에 걸린 글자 락이다
- 확신: 중간

### plugins/project-init/tests/test_command_contract.py
- 초: 0.0
- 줄 수: 541
- 고친 횟수: 20
- 크기: 작음 — SKILL.md · README · hooks.json 읽기와 훅 소스 ast 파싱
- 종류: 섞임(글자 90 · 구조 10)
- 지키는 것: 글자만 지킴 — plugins/project-init/skills/project-init/SKILL.md · README 의 선택지 라벨(「중단」 · 「(권장)」) · 단계별 규칙 문장. 예외로 완료 보고가 배포된 훅이 하지 않는 사후 검증을 약속하지 않는지는 훅 소스에서 도출해 비교한다(TestCompletionReportPromisesOnlyWhatShips)
- 거짓 실패 위험: 높음 — SKILL 문장을 다듬으면 깨지는 전체 문장 핀이 대부분이다. 고친 횟수 20회가 그 증거다
- 겹침: plugins/project-init/tests/test_no_write_matcher_hooks.sh — 같은 hooks.json 을 읽는다. plugins/project-init/tests/test_branch_prefix_templates.py — 같은 SKILL 의 Step 3 · 4d 를 읽는다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 훅이 약속보다 적게 검증한다는 도출형 락(축 A~D)은 지킬 만하나 나머지는 SKILL 문장 하나하나를 박은 글자 락이라 모델이 읽는 지시를 문구 단위로 고정한다
- 확신: 중간

### plugins/project-init/tests/test_no_write_matcher_hooks.sh
- 초: 0.1
- 줄 수: 39
- 고친 횟수: 2
- 크기: 중간 — git rev-parse 와 python3 하위 프로세스 하나로 hooks.json 파싱
- 종류: 섞임(구조 1 · 글자 1)
- 지키는 것: PostToolUse 훅 항목이 쓰기 도구(Write · Edit 등)나 빈 matcher 에 발화하지 않아야 모든 도구 호출에 훅이 도는 일을 막는다.
- 거짓 실패 위험: 낮음 — hooks.json 의 matcher 가 바뀔 때만 깨진다. 양성 대조(Bash 항목 생존)가 있다
- 겹침: plugins/project-init/tests/test_command_contract.py — 같은 hooks.json 을 읽는다(다른 확인)
- 보안 갈래: 예(훅 발화 범위 · 권한 경계)
- 판정 후보: 둠 — 작고 hooks.json 구조를 직접 읽어 의미 있는 matcher 불변식을 지킨다. A3 의 `docs-lint.py` 부재만 글자만 지킴에 가깝다
- 확신: 중간

#### 읽지 못한 것 — shallow-01
없음. 다만 test_run_own_tests_accumulate.sh 의 「겹침」에 적은 test_run_own_tests.py 는 이 묶음 밖이라 열어 보지 못했다(이름만 확인). 위의 「초」는 묶음 파일 값이고 「시간」 추정은 읽은 코드에서 어림했다(실행하지 않았다).

## 묶음 shallow-02

### plugins/project-init/tests/test_plain_init_text.py
- 초: 0.0
- 줄 수: 91
- 고친 횟수: 6
- 크기: 작음 — SKILL.md · README.md 를 읽어 문자열을 비교할 뿐
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/project-init/skills/project-init/SKILL.md 의 보고 블록 첫 줄 · 끝 「다음 할 일」 문장 전체, README 첫 문단 · `## Principles Instantiated` 표제
- 거짓 실패 위험: 높음 — 보고 문장의 한 글자만 다듬어도 깨진다(끝 문장은 통째 등호 비교인데 같은 문장을 부분 문자열로 다시 확인하기도 한다)
- 겹침: 같은 파일 안 — test_last_line_is_one_next_action 의 통째 등호와 test_next_action_names_each_rule_state 의 부분 문자열이 같은 문장을 되풀이. 다른 파일은 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 끝 문장을 등호 한 번 + 「바로 확인한다고 약속하지 않는다」 부정 한 줄로 줄여도 지키는 것(셋업 직후 훅이 확인한다는 거짓 약속 방지)이 그대로다
- 확신: 중간

### plugins/project-init/tests/test_post_tool_use.py
- 초: 5.3
- 줄 수: 780
- 고친 횟수: 21
- 크기: 중간 — 케이스마다 임시 git 레포(src init + clone)를 만들고 훅을 하위 프로세스로 실행
- 종류: 섞임(동작 80 · 구조 5 · 글자 15)
- 지키는 것: project-init 훅이 브랜치 이름 · 커밋 메시지를 실제 git 상태(origin/HEAD 판 규칙 · reflog)에서 읽어 규칙 밖 이름을 알리되 규칙을 읽지 못하면 소리 내어 fail-open 하고 항상 exit 0 인 것
- 거짓 실패 위험: 중간 — 동작이 바뀔 때 깨지나 경고 문구(한국어 메시지) 부분 문자열 단언이 많아 문구 다듬기에도 깨진다
- 겹침: plugins/project-init/tests/test_post_tool_use_branch.sh · test_branch_prefix_templates.py 가 같은 훅 · branch-strategy.md 를 다룬다(내용은 안 읽음, 겹침 정도 확인 못 함)
- 보안 갈래: 예 — kill switch(DEVBREW_PROJECT_INIT_DISABLE) 단언, 경로의 제어 문자 · 개행 주입이 출력 줄을 쪼개지 못하는 단언(`_inert`)이 들어 있다
- 판정 후보: 구조를 고침 — 지키는 것은 그대로 두고 `_RepoTestCase.setUp`/`make_repo` 가 테스트(약 60개)마다 새로 만드는 src+clone 레포를 클래스 단위로 한 번 만들어 복제하면 싸진다
- 확신: 중간

### plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
- 초: 0.2
- 줄 수: 571
- 고친 횟수: 69
- 크기: 작음 — 재구성한 SKILL.md 와 몇몇 문서를 awk · grep 으로 읽을 뿐(상단 약 100줄은 주석)
- 종류: 글자
- 지키는 것: 재비판 dispatch 의 diff 슬롯 · fail-closed 처분 줄 · 줄 순서 · 제거된 표면(scope_signal 등)의 부재를 SKILL.md 가 글자로 유지하는 것. 단 security-reviewer · recritic 프로필의 `verifier-writable` 문구와 code-recritic 의 `tools: Read, Grep, Glob` 줄은 리뷰어 프로필 락이다
- 거짓 실패 위험: 높음 — SKILL.md 문장 · 줄 간격 · 헤딩을 다듬거나 옮기기만 해도 깨지고(고친 횟수 69 가 이 묶음 최대), 줄번호 근접 단언은 파일이 자라면 깨진다
- 겹침: plugins/quality-gates/tests/test_code_recritic_frontmatter.sh(tools 줄) · test_recritic_code_profile.sh(verifier-writable) · test_range_wiring.sh(SKILL 앵커)와 겹침
- 보안 갈래: 예 — code-recritic tools 포스처 · verifier-writable 페르소나 문구 확인(리뷰어 프로필)
- 판정 후보: 줄임 — 리뷰어 프로필 두 확인은 남기고 SKILL 문구 · 줄 순서 · `scope-empty` 3회 같은 글자 핀과 「대상 소멸」 설명 주석을 덜어도 사람에게 닿는 동작은 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py
- 초: 1.9
- 줄 수: 339
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포를 셸로 만들고 review-diff.sh · check-review-scope.sh 를 하위 프로세스로 실행
- 종류: 섞임(동작 85 · 구조 5 · 글자 10)
- 지키는 것: Bash(heredoc · 리다이렉트 · sed -i)로 쓴 파일도 기본 리뷰 범위와 리뷰어가 받는 diff 에 들어가고 gitignore 파일은 안 들어가며, 은퇴한 세션 산출물 이름이 모델이 읽는 표면에 돌아오지 않는 것
- 거짓 실패 위험: 낮음 — 기대값을 git 에서 런타임 도출해서 동작이 바뀔 때만 깨진다(축 3 의 마커 부재만 새 문서에 걸릴 수 있다)
- 겹침: plugins/quality-gates/tests/test_git_derived_scope.sh · test_check_review_scope.sh · test_qg_false_clean_floor.sh 가 같은 스크립트를 다룸(내용 겹침 정도는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 「셸로 쓴 변경이 리뷰 범위에서 빠진다」는 실제 사고를 동작으로 재고, 비용(임시 레포 몇 개)이 그에 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_agent_color.sh
- 초: 0.1
- 줄 수: 24
- 고친 횟수: 1
- 크기: 작음 — agents/*.md 를 grep 할 뿐
- 종류: 구조
- 지키는 것: 모든 qg agent 의 frontmatter color 가 8색 목록 안에 있는 것(보기 좋게 표시되는지의 문제 — 틀려도 동작이 바뀌는지는 이 파일이 못 보임)
- 거짓 실패 위험: 낮음 — color 값을 바꿀 때만 깨진다(단 cwd 가 레포 루트여야 하는 상대 경로)
- 겹침: plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh · test_artifact_adversarial_frontmatter.sh 가 같은 color 정규식을 두 agent 에 되풀이, test_agent_tools_lock_mutation.sh 는 color 를 픽스처에 쓸 뿐
- 보안 갈래: 아니오
- 판정 후보: 합침 — agent frontmatter 전수 스캔(test_agent_frontmatter_keys.sh)이나 plugin-audit 구조 검사 쪽으로 모으면 위 두 frontmatter 테스트의 color 줄도 함께 걷힌다
- 확신: 중간

### plugins/quality-gates/tests/test_agent_frontmatter_keys.sh
- 초: 0.9
- 줄 수: 600
- 고친 횟수: 15
- 크기: 중간 — 스캔 루트로 cd 해 python3(PyYAML)을 한 번 띄우고 agent 마다 awk · sed · grep 을 돈다(상단 주석이 대부분)
- 종류: 구조
- 지키는 것: 모든 plugins/*/agents/*.md 가 `tools:` allowlist 를 선언하고 금지 도구(Write · Edit · Bash · Agent · Monitor · MCP 서버 grant)는 마커 없이 못 갖는 것, frontmatter 가 YAML 로 읽히는 것 — 쓰기 권한 있는 리뷰어(Law 2)와 fail-open 로드를 막는다
- 거짓 실패 위험: 낮음 — agent 의 도구 선언 형태가 바뀔 때만 깨진다
- 겹침: test_agent_tools_lock_mutation.sh · test_agent_tools_lock_differential.sh 가 이 락을 대상으로 이빨을 재는 별개 시험(역할 분담이 의도됨). plugins/plugin-audit/tests/test_check_law2.py 도 비슷한 것을 다룸(내용 확인 못 함)
- 보안 갈래: 예 — 리뷰어 agent 도구 allowlist(Law 2) 집행 지점
- 판정 후보: 둠 — 지키는 것이 분명하고 0.9초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh
- 초: 0.1
- 줄 수: 49
- 고친 횟수: 5
- 크기: 작음 — agents/*.md frontmatter 와 README 를 grep
- 종류: 섞임(구조 80 · 글자 20)
- 지키는 것: 어느 devbrew agent 도 frontmatter 에 model 키를 달지 않아 사용자의 서브에이전트 모델 설정 → 세션 모델 순으로 따르는 것(README 우선순위 문장 1건은 글자만 지킴 — plugins/quality-gates/README.md 의 「모델을 고정하지 않는다…」)
- 거짓 실패 위험: 중간 — 새 agent 에 model 키를 달면 깨지는 건 의도지만 README 문장 다듬기에도 깨진다
- 겹침: test_artifact_critic_frontmatter.sh · test_artifact_adversarial_frontmatter.sh · test_code_recritic_frontmatter.sh 가 각 agent 의 model 키 부재를 되풀이, test_agent_model_mutation.sh 가 이 스윕의 이빨을 잰다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 전수 스윕이 이미 있으므로 개별 frontmatter 테스트의 model 부재 단언을 걷고 이 스윕으로 모으면 된다
- 확신: 중간

### plugins/quality-gates/tests/test_agent_stub_harness.py
- 초: 0.0
- 줄 수: 86
- 고친 횟수: 3
- 크기: 작음 — 한 프로세스 안에서 harness 함수 호출
- 종류: 동작
- 지키는 것: 테스트 도구 `harness/agent_stub.py` 의 YAML 파싱 · 스키마 단언이 빈 값 · 잘못된 값에서 올바르게 실패하는 것(제품이 아니라 테스트 하니스를 지킴)
- 거짓 실패 위험: 낮음 — harness 동작이 바뀔 때만 깨진다
- 겹침: harness 를 쓰는 것은 test_security_reviewer_behavior.py 하나(grep 결과). 한 파일 안에서 test_assert_yaml_schema_empty_enum_dict_is_not_skipped 는 주석이 스스로 「가드를 되돌려도 통과한다」고 적어 구별력이 없다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 구별력 없는 마지막 케이스를 덜고 나머지는 둬도 지키는 것이 같다(비용은 0초)
- 확신: 중간

### plugins/quality-gates/tests/test_agent_tools_lock_differential.sh
- 초: 3.9
- 줄 수: 294
- 고친 횟수: 4
- 크기: 중간 — 케이스(약 45)마다 락(bash + python3 한 번)과 별도 python 파서를 하위 프로세스로 실행
- 종류: 섞임(변이 50 · 동작 50)
- 지키는 것: 락이 믿은 `tools` 값이 YAML 파서가 실제로 해석하는 값과 같은 것(락이 승인한 agent 를 런타임이 다른 도구로 읽는 우회를 막는다)
- 거짓 실패 위험: 낮음 — 락 동작이 바뀔 때만 깨진다(PyYAML 없으면 L2 는 소리 내어 건너뜀)
- 겹침: test_agent_tools_lock_mutation.sh 와 같은 픽스처 형태 · 같은 RED/GREEN 기대(`tools: [Write]` · bare `tools:` · 인용 · 중복 키 등)를 L1 로 되풀이, 락도 케이스마다 양쪽에서 각각 실행
- 보안 갈래: 예 — 리뷰어 agent 도구 allowlist 락(Law 2)의 이빨
- 판정 후보: 구조를 고침 — 사례표 하나로 두 파일의 케이스를 모아 락을 케이스당 한 번만 돌리고 L1 verdict 와 파서 합치(L2)를 같은 실행에서 재면 지키는 것은 그대로 싸진다
- 확신: 중간

### plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh
- 초: 6.2
- 줄 수: 423
- 고친 횟수: 13
- 크기: 중간 — 락(python3 포함)을 약 90회 하위 프로세스로 실행, 주입용 sitecustomize 디렉토리 여럿 생성(추정)
- 종류: 변이
- 지키는 것: Law 2 락이 금지 도구 · YAML 우회 · 파싱 불가 frontmatter · 완주 신호 위조를 실제로 RED 로 막고(정상 형태는 GREEN) 진단 스위치가 verdict 를 못 뒤집는 것
- 거짓 실패 위험: 낮음 — 락 술어가 바뀔 때만 깨진다(대소문자 구별 FS 에서 일부 셀은 건너뜀)
- 겹침: test_agent_tools_lock_differential.sh 와 케이스 겹침(위 항목 참조), test_agent_frontmatter_keys.sh 가 대상
- 보안 갈래: 예 — 리뷰어 agent 도구 allowlist 락의 이빨(Law 2)
- 판정 후보: 구조를 고침 — differential 과 한 사례표로 모으고 A-1 의 EMIT × stdout 16칸 행렬을 대표 몇 칸으로 줄이면 락 실행 수가 줄어도 이빨은 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_angle_coverage.sh
- 초: 5.1
- 줄 수: 934
- 고친 횟수: 18
- 크기: 중간 — 케이스(약 100개 단언 · 46개 함수)마다 python3(angles.py · synthesize_findings.py)를 새로 띄우고 임시 폴더를 만든다(추정)
- 종류: 동작
- 지키는 것: 리뷰 각도(보안 · 판정 · 다른 전제)가 상태 없이 인증되지 않고, 판정 각도를 그 실행에서 finding 을 낸 리뷰어에게 접으면 거부되며, 막는 각도의 부재가 `clean` 을 막고 다른 전제 부재는 막지 않는 것
- 거짓 실패 위험: 낮음 — 합성기 판정 동작이 바뀔 때만 깨진다(메시지 문구 부분 문자열 단언 일부는 문구 다듬기에 깨짐)
- 겹침: plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh 가 오케스트레이터 쪽 배선(이 파일이 재지 않는다고 밝힘), test_synthesize_findings*.sh 류와 겹칠 수 있음(확인 못 함). 한 파일 안에서 「rc 4 + 빈 stdout + AC10a + 자기 finding 자기 판정」 4중 단언이 6개 변형에 되풀이
- 보안 갈래: 예 — 자기 finding 자기 판정 금지(Law 2) · 신원 계약 우회 방지
- 판정 후보: 구조를 고침 — 되풀이되는 4중 단언을 도우미 함수로 묶고 angles.py 모듈 단위 케이스(약 20개)를 python 한 번에서 함수 호출로 돌리면 지키는 것은 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh
- 초: 0.1
- 줄 수: 24
- 고친 횟수: 3
- 크기: 작음 — agent 파일 한 개를 grep
- 종류: 섞임(구조 70 · 글자 30)
- 지키는 것: artifact-adversarial 이 읽기 전용 allowlist(Read, Grep, Glob)이고 model 키가 없는 것. `finding_key` · `new_severity` · `new_findings` · `load-bearing` 은 글자만 지킴 — agents/artifact-adversarial.md 본문 낱말
- 거짓 실패 위험: 중간 — 페르소나 낱말을 다듬으면 깨진다
- 겹침: test_artifact_critic_frontmatter.sh 와 거의 복제, tools/model/color 는 test_agent_frontmatter_keys.sh · test_agent_model_unpinned_sweep.sh · test_agent_color.sh 가 전수로 이미 잰다
- 보안 갈래: 예 — 리뷰어 프로필(읽기 전용 allowlist, 페르소나 문구)
- 판정 후보: 합침 — critic 짝과 한 표로 합치고 전수 스캔이 하는 tools/model/color 확인은 걷는다(페르소나 낱말 핀은 보안 갈래라 유지)
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_bounds.sh
- 초: 0.2
- 줄 수: 38
- 고친 횟수: 4
- 크기: 중간 — 스크립트(artifact_max_rounds.sh · artifact_stagnation.py)를 약 18회 하위 프로세스로 실행
- 종류: 동작
- 지키는 것: 문서 비평 루프가 상한(기본 5, 최대 10, 오버플로 · 8진수 · 음수 값도 안전하게 정규화)과 정체 판정(정체 · 진전 · 1라운드 오탐 방지 · 잘못된 신호는 멈춤)으로 끝없이 돌지 않는 것
- 거짓 실패 위험: 낮음 — 상한 · 정체 판정이 바뀔 때만 깨진다
- 겹침: 못 찾음(같은 스크립트를 부르는 것은 test_critiquing_artifacts_skill.sh · shared/tests/test_cost_disclosure.sh 이고 동작 확인은 아님)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 무한 루프 방지 경계값을 동작으로 재고 0.2초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_artifact_branch_guard.sh
- 초: 0.6
- 줄 수: 71
- 고친 횟수: 4
- 크기: 중간 — 케이스마다 임시 git 레포를 만들고 스크립트 실행(7개)
- 종류: 동작
- 지키는 것: 자율 비평이 main · master · develop · detached HEAD 에는 진행하지 않고(origin/HEAD 없으면 이름 목록으로 fail-closed) feature 브랜치는 경고와 함께 진행하는 것
- 거짓 실패 위험: 낮음 — 가드 규칙이 바뀔 때만 깨진다
- 겹침: 못 찾음
- 보안 갈래: 예 — 보호 브랜치에 자동 커밋하지 않는 권한 경계
- 판정 후보: 둠 — 지키는 것이 분명하고 0.6초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_artifact_codex_reviewer.sh
- 초: 0.7
- 줄 수: 178
- 고친 횟수: 7
- 크기: 중간 — 빌더 · 추출기 · 러너를 하위 프로세스로 실행, 스텁 플러그인 사본 두 개와 가짜 codex 를 임시 폴더에 만든다
- 종류: 섞임(동작 90 · 글자 10)
- 지키는 것: artifact codex 하위 파이프라인이 본문을 프롬프트에 싣고 마지막 펜스를 골라 주입 decoy 를 이기며, 실패(종료 코드 · 빈 추출 · 인자 누락)마다 빈 산출물이 아니라 사유 있는 `codex_failed: true` 를 내고 CLAUDE_PLUGIN_ROOT 없이도 codex 에 닿는 것
- 거짓 실패 위험: 중간 — 러너 소스의 `PLUGIN_ROOT=` 줄 grep(글자)이 리팩터링에 깨진다
- 겹침: test_codex_exit_meta.sh(추출기 · 러너 e2e), test_codex_runner_degrade_contract.sh(degrade 계약) 와 일부 겹칠 수 있음(후자 내용은 확인 못 함)
- 보안 갈래: 예 — 비신뢰 artifact 에 숨은 가짜 findings 펜스 주입 방어(마지막 펜스 채택)
- 판정 후보: 둠 — 주입 · degrade 경로를 동작으로 재고 0.7초로 싸다
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_commit.sh
- 초: 0.5
- 줄 수: 67
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포(5개)를 만들고 스크립트 실행
- 종류: 동작
- 지키는 것: 비평 커밋이 대상 한 파일만 담고(스테이지된 다른 변경을 쓸어 담지 않음) 변경 없으면 no-op, 추적 안 되는 대상을 구별하며, kill switch(모드 · 전역)가 커밋 싱크에서 커밋을 막는 것
- 거짓 실패 위험: 낮음 — 커밋 스크립트 동작이 바뀔 때만 깨진다(끝의 `git add -A` grep 만 글자)
- 겹침: 못 찾음(`git add -A` 부재 grep 은 위 원자성 동작 시험과 일부 겹침)
- 보안 갈래: 예 — kill switch 가 커밋 싱크에서 집행되는지(F-H)
- 판정 후보: 둠 — 원자성과 kill switch 를 동작으로 재고 0.5초
- 확신: 높음

### plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh
- 초: 0.1
- 줄 수: 18
- 고친 횟수: 4
- 크기: 작음 — agent 파일 한 개를 grep
- 종류: 섞임(구조 70 · 글자 30)
- 지키는 것: artifact-critic 이 읽기 전용 allowlist 이고 model 키가 없는 것. `You are **Artifact Critic**` · `NOT responsible` · `findings:` 는 글자만 지킴 — agents/artifact-critic.md 본문
- 거짓 실패 위험: 중간 — 페르소나 문장을 다듬으면 깨진다
- 겹침: test_artifact_adversarial_frontmatter.sh 와 거의 복제, tools/model/color 는 전수 스캔들이 이미 잰다
- 보안 갈래: 예 — 리뷰어 프로필(읽기 전용 allowlist, 역할 한정 문구)
- 판정 후보: 합침 — adversarial 짝과 한 표로 합친다
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_critique_truths.sh
- 초: 0.1
- 줄 수: 40
- 고친 횟수: 5
- 크기: 작음 — SKILL · README · agent 파일을 grep 하고 python -I 한 번
- 종류: 섞임(구조 30 · 글자 70)
- 지키는 것: 비평 skill 이 인용한 adversarial 의 `tools:` 줄이 실제 agent 의 tools 줄과 같은 것(도출 비교 — 거짓 서술 방지). 나머지(`그 파일로 고정` 부재 · 문단 줄 160자 이하 · README 에 `hard-review` 부재 · 특정 문장 존재)는 글자만 지킴 — skills/*/SKILL.md · README.md
- 거짓 실패 위험: 높음 — 문단을 다듬거나 줄 길이가 넘으면 동작과 무관하게 깨진다
- 겹침: test_codex_gate_observation 등과는 무관, test_law2_prose.sh 가 비슷한 도구 서술을 다룰 수 있음(확인 못 함)
- 보안 갈래: 예 — 리뷰어(adversarial)의 egress 도구 서술이 실제 tools 와 맞는지
- 판정 후보: 줄임 — 인용 tools 줄 == 실제 tools 줄의 도출 비교만 남기고 줄 길이 · 문구 핀을 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_metadata.sh
- 초: 0.1
- 줄 수: 17
- 고친 횟수: 5
- 크기: 작음 — plugin.json · CHANGELOG · README grep
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugin.json 판이 2.11 이상, CHANGELOG 에 `## [2.11.0]` 과 옛 skill 이름, README 에 `critique` 낱말
- 거짓 실패 위험: 높음 — 문서 개편 · 판 정책 변경에 깨지고, 한 번 지나간 버전 기록이라 동작을 지키지 않는다
- 겹침: 확인 못 함(CHANGELOG 연속 · README 원칙 락은 레포 쪽에 따로 있을 수 있으나 파일은 안 찾아봄)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 과거 판 기록 낱말이 동작을 정하지 않는다
- 확신: 중간

### plugins/quality-gates/tests/test_artifact_path_auth.sh
- 초: 0.1
- 줄 수: 37
- 고친 횟수: 2
- 크기: 중간 — 임시 폴더를 만들고 python 스크립트를 4번 실행
- 종류: 동작
- 지키는 것: 비평 대상 경로가 `..` 탈출 · 심볼릭 링크 탈출 · 트리 안 심볼릭 별칭이면 거부되고 정상 내부 파일만 승인되는 것
- 거짓 실패 위험: 낮음 — 경로 인가 규칙이 바뀔 때만 깨진다
- 겹침: 못 찾음
- 보안 갈래: 예 — 경로 탈출 · 심볼릭 링크 방어
- 판정 후보: 둠 — 보안 경계를 동작으로 재고 0.1초
- 확신: 높음

### plugins/quality-gates/tests/test_build_codex_prompt.sh
- 초: 0.2
- 줄 수: 50
- 고친 횟수: 7
- 크기: 중간 — 빌더를 python 으로 5번 실행, 임시 폴더
- 종류: 동작
- 지키는 것: codex 프롬프트가 diff · 의도 · 기준 블록을 다른 리뷰어와 같은 글자로 싣고, 의도 없음은 빈 `<intent>` 로 가며 오류가 아니고, diff 안 자리표시자가 한 번만 치환되고, 기준 블록 부재는 exit 2 인 것
- 거짓 실패 위험: 낮음 — 빌더 동작이 바뀔 때만 깨진다
- 겹침: test_codex_prompt_untrusted_clause.sh 가 같은 빌더를 태워 절 방출을 잼(서로 다른 확인), test_plain_field_path.sh 도 빌더를 참조(확인 못 함)
- 보안 갈래: 예 — diff 안 `{{INTENT}}` 같은 자리표시자 주입 방지(치환 한 번)
- 판정 후보: 둠 — 프롬프트 조립 계약을 동작으로 재고 0.2초
- 확신: 높음

### plugins/quality-gates/tests/test_check_review_scope.sh
- 초: 2.4
- 줄 수: 241
- 고친 횟수: 7
- 크기: 중간 — 케이스(11개)마다 임시 git 레포를 만들고 일부는 bare 원격 · 얕은 clone · git shim 까지 만든다
- 종류: 동작
- 지키는 것: 리뷰 범위 신호가 변경 유무(분기 앞섬 · 미커밋 · 무시 파일 제외)를 정확히 내고, 판단할 수 없으면(detached · 기본 브랜치 없음 · 얕은 clone · git 질의 실패 · resolver 부재) 가짜 「변경 없음」이 아니라 사유와 함께 degraded 로 fail-open 하며 읽기 전용인 것
- 거짓 실패 위험: 낮음 — 신호 로직이 바뀔 때만 깨진다(git 버전에 따라 얕은 clone 전제는 흔들릴 수 있음)
- 겹침: test_a20_tool_agnostic_scope.py 축 2 · test_git_derived_scope.sh · test_qg_false_clean_floor.sh · test_resolve_baseline.sh 와 같은 스크립트를 다룸(겹침 정도 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 가짜 clean 을 막는 fail-open 갈래를 동작으로 재고 비용이 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_classify_artifact_target.sh
- 초: 0.3
- 줄 수: 30
- 고친 횟수: 3
- 크기: 중간 — 분류 스크립트를 python 으로 12번 실행
- 종류: 동작
- 지키는 것: 비평 대상이 코드면 코드 파이프라인으로 보내고(종료), 비코드는 진행하고, 확장자 없음 · 목록 밖 · 복합 확장자 · 디렉토리는 ambiguous 로 안전하게 처리하는 것
- 거짓 실패 위험: 낮음 — 분류 규칙이 바뀔 때만 깨진다
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 3분기 계약을 동작으로 재고 0.3초
- 확신: 높음

### plugins/quality-gates/tests/test_code_recritic_frontmatter.sh
- 초: 0.2
- 줄 수: 85
- 고친 횟수: 5
- 크기: 작음 — agent 파일을 grep · awk 하고 python 으로 YAML 두 번 파싱
- 종류: 섞임(구조 35 · 글자 55 · 동작 10)
- 지키는 것: code-recritic 이 읽기 전용(tools 줄과 YAML 파싱 양쪽)이고 model 키 없고, 출력 블록 이름이 합성기 BLOCK 상수와 같아 응답이 「판정자 사망」으로 읽히지 않으며, 페르소나 본문의 framing-blind · 주입 저항 · reject 근거 필수 문장이 유지되는 것
- 거짓 실패 위험: 높음 — 페르소나 문장 한 글자(주입 저항 단락은 처음부터 끝까지 등호)를 다듬어도 깨진다
- 겹침: tools/model 은 test_agent_frontmatter_keys.sh · test_agent_model_unpinned_sweep.sh · harness/test_skill_orchestration_behavior.sh 가 되풀이
- 보안 갈래: 예 — 리뷰어 페르소나 약화 방지(주입 저항 · 읽기 전용) — 글자 확인도 지우지 않기로 한 갈래
- 판정 후보: 둠 — 페르소나 락이 목적이고 0.2초로 싸다(tools/model 되풀이만 전수 스캔에 맡길 수 있음)
- 확신: 중간

### plugins/quality-gates/tests/test_codex_backward_compat.sh
- 초: 0.1
- 줄 수: 168
- 고친 횟수: 13
- 크기: 중간 — detect_codex.sh 를 한 번 실행, 나머지는 grep(Check 3 은 원장의 등재 줄마다 테스트를 다시 돌리나 지금 등재 0건)
- 종류: 섞임(동작 15 · 글자 60 · 구조 25)
- 지키는 것: kill switch 가 codex 를 건너뛰게 하는 것(Check 1). SKILL.md 의 `다른 전제 각도 — codex (사용 가능하면 부른다` · `regardless of scope` · `If codex is unavailable, continue without it` 는 글자만 지킴. Check 3(원장 재실행)은 plugins/quality-gates/tests/codex-blessed-red.txt 에 등재 줄이 0건이라 지금은 아무것도 재지 않는다
- 거짓 실패 위험: 높음 — SKILL 문구를 다듬으면 동작과 무관하게 깨진다
- 겹침: test_codex_dispatch_invariant.sh 가 같은 SKILL 앵커 두 개를 되풀이, test_detect_codex.sh · test_codex_copies_agree.sh 가 kill switch 동작을 이미 잼, test_range_wiring.sh 도 같은 앵커
- 보안 갈래: 예 — codex kill switch 확인(다만 같은 확인이 다른 테스트에도 있음)
- 판정 후보: 합침 — Check 1 은 detect_codex 테스트에, Check 2 는 dispatch_invariant 에 모으고 등재 0건인 원장 재실행(Check 3)은 비어 있는 동안 걷는 것을 고려
- 확신: 높음

### plugins/quality-gates/tests/test_codex_copies_agree.sh
- 초: 2.6
- 줄 수: 342
- 고친 횟수: 13
- 크기: 중간 — 추출기를 표본 7 × override 2 × 사본 2 = 28회, detect_codex 를 env -i 로 약 21회, mock 쌍을 수십 회 하위 프로세스로 실행
- 종류: 동작
- 지키는 것: 세 detect_codex 사본의 kill switch 가 각자 자기 변수에만 반응하고 공통 판정(버전 바닥 등)이 같은 것, codex_jsonl 정본과 사본이 빈 · 비문자열 agent_message 에 앞선 진짜 답을 덮어쓰지 않는 것, mock 자산 사본이 같은 행동을 하는 것
- 거짓 실패 위험: 중간 — 사본 · mock 이 늘거나 하한(mock 8그룹 · 표본 7건)이 바뀌면 깨진다
- 겹침: 층④(codex_findings_to_yaml 두 호출 경로 등가)는 헤더 스스로 두 경로가 같은 심볼릭 링크 정본이라 등가가 약하다고 적음. test_detect_codex.sh · test_codex_exit_meta.sh · plugins/spec-distill/tests/test_codex_findings_to_yaml.py 와 일부 겹침
- 보안 갈래: 예 — 플러그인마다 다른 kill switch 변수의 교차 배선 확인
- 판정 후보: 줄임 — 층⑤(codex_jsonl 가드)와 층①(kill switch 교차)은 두고 심볼릭 링크 정본에 대한 층④ 28회 등가 비교를 대표 표본으로 줄여도 지키는 것이 같다
- 확신: 중간

### plugins/quality-gates/tests/test_codex_dispatch_invariant.sh
- 초: 0.1
- 줄 수: 76
- 고친 횟수: 12
- 크기: 작음 — 재구성한 SKILL.md 를 grep · awk
- 종류: 글자
- 지키는 것: 글자만 지킴 — quality-pipeline/SKILL.md 의 `다른 전제 각도 — codex (사용 가능하면 부른다` · `regardless of scope`(그 절 창 안) · `run_codex_reviewer.sh` · security-reviewer dispatch 12줄 안 `project_dir:` · 옛 `codex_manifest.codex_available` 문구 부재
- 거짓 실패 위험: 높음 — 산문 문구 · 줄 간격을 다듬기만 해도 깨진다(12줄 창 근접 포함)
- 겹침: test_codex_backward_compat.sh Check 2 와 같은 앵커 · test_range_wiring.sh 와 겹침. 실제 gate 동작은 test_codex_gate_observation.sh 가 잼
- 보안 갈래: 아니오
- 판정 후보: 합침 — backward_compat 의 SKILL 앵커 확인과 한 파일로 모으고, 동작은 gate_observation 이 재므로 글자 핀은 필요한 만큼만 남긴다
- 확신: 중간

### plugins/quality-gates/tests/test_codex_exit_meta.sh
- 초: 1.4
- 줄 수: 190
- 고친 횟수: 9
- 크기: 중간 — 추출기를 python 으로 약 35회 실행하고 러너 e2e 를 위해 scripts · references 를 임시 폴더로 `cp -RL` 한다
- 종류: 동작
- 지키는 것: codex 가 비정상 종료하면 산출물 meta 에 종료 코드와 사유 분류(과부하 · 인증 · 한도 · 시간 초과 · 네트워크 등)가 남고, stderr 원문과 비밀(토큰 · 키 · 비밀번호)은 기록 · 화면에 새지 않으며 stderr 를 못 읽으면 `unreadable` 로 구별하는 것
- 거짓 실패 위험: 낮음 — 추출기 동작이 바뀔 때만 깨진다(분류 키워드 목록 단언은 키워드 추가에 깨짐)
- 겹침: 공유 추출기와 artifact 추출기 단언을 쌍으로 두는 것은 의도(화면 줄 동등 비교). test_artifact_codex_reviewer.sh · test_codex_runner_degrade_contract.sh 와 러너 경로가 일부 겹침
- 보안 갈래: 예 — stderr 비밀 가림 · 원문 미기록
- 판정 후보: 둠 — 비밀 유출 방지와 실패 사유 기록을 동작으로 재고 1.4초는 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_codex_extractor_positive_marker.sh
- 초: 0.2
- 줄 수: 229
- 고친 횟수: 3
- 크기: 중간 — python 한 번에서 러너 도출 후 추출기 몇 개를 하위 프로세스로 실행
- 종류: 동작
- 지키는 것: 러너가 실제로 부르는 모든 codex 추출기(코드에서 도출)가 정상 성공 입력에서 `codex_failed: false` 양성 표식을 내 「깨끗이 0건」과 「조용히 깨져 빈 결과」를 소비자가 구별하는 것
- 거짓 실패 위험: 낮음 — 추출기가 표식을 못 낼 때 · 러너가 새 형태로 호출될 때 깨진다(러너 도출 정규식이 바뀐 호출 형태에는 도출 실패로 깨질 수 있음)
- 겹침: test_codex_copies_agree.sh 층④ 의 `01-clean` 값 고정이 한 추출기에 대해 같은 값을 확인
- 보안 갈래: 아니오
- 판정 후보: 둠 — 도출 방식이라 새 추출기를 자동으로 덮고 0.2초
- 확신: 높음

### plugins/quality-gates/tests/test_codex_gate_observation.sh
- 초: 2.9
- 줄 수: 332
- 고친 횟수: 20
- 크기: 중간 — 마킹된 게이트 블록 수곳 × 시나리오 5개를 하위 bash 로 실행하고 실제 체크아웃의 detect_codex.sh 심볼릭 링크를 잠깐 지웠다 되살린다
- 종류: 동작
- 지키는 것: SKILL 의 codex 게이트가 가용일 때만 codex 를 1번 부르고 kill switch · 미설치 · 버전 바닥 미달 · 감지기 부재에서는 0번 부르며(감지기 부재는 stderr 에 사유를 낸다), 게이트 없는 러너는 사유와 함께 등재되는 것
- 거짓 실패 위험: 중간 — 새 게이트 · SKILL 마커 형태가 바뀌면 분류 목록에서 깨진다. 실행 중 실제 레포의 링크를 지우므로 같은 시각 다른 테스트가 그 파일을 읽으면 흔들릴 수 있다(병렬 실행 시)
- 겹침: test_codex_invocation_contract.sh 는 같은 lib 로 러너 안 argv · stdin 을 재서 서로 다른 확인. kill switch 동작은 test_detect_codex.sh · test_codex_copies_agree.sh 와 일부 겹침
- 보안 갈래: 예 — codex kill switch(P21)가 호출 앞에서 실제로 집행되는지
- 판정 후보: 구조를 고침 — 심볼릭 링크 삭제 · 복원을 실제 체크아웃이 아닌 플러그인 사본에서 하게 바꾸면 지키는 것은 그대로 두고 병렬 안전해진다
- 확신: 중간

### plugins/quality-gates/tests/test_codex_invocation_contract.sh
- 초: 1.7
- 줄 수: 155
- 고친 횟수: 5
- 크기: 중간 — 후보 러너(여럿)를 mock codex 와 함께 실제로 실행해 argv · stdin 을 캡처
- 종류: 동작
- 지키는 것: codex 를 부르는 모든 러너가 프롬프트를 argv 가 아니라 stdin 으로 넘기고(`-`) `--json` · `-s read-only` · `-C` 로 부르며, 새 러너가 호출 방법 없이 들어오면 RED 인 것
- 거짓 실패 위험: 낮음 — 러너의 codex 호출 모양이 바뀔 때만 깨진다(obs_invoke 표에 없는 새 러너는 의도적으로 RED)
- 겹침: test_codex_runner_no_effort_pin.sh · test_codex_runner_degrade_contract.sh · test_sandbox_enforced.sh 가 같은 codex_observation lib 를 씀(내용 겹침은 확인 못 함)
- 보안 갈래: 예 — read-only 샌드박스 · 프롬프트의 argv 노출 방지
- 판정 후보: 둠 — 실행 관측으로 호출 계약을 재고 비용이 그에 맞다
- 확신: 높음

### plugins/quality-gates/tests/test_codex_prompt_untrusted_clause.sh
- 초: 2.8
- 줄 수: 310
- 고친 횟수: 11
- 크기: 중간 — 빌더 2개 × (일반 · ascii · dominance)와 러너 × 프로필 4개 × (일반 · ascii)를 하위 프로세스로 실행하고 git ls-files 로 도출한 러너마다 grep 2번(추정)
- 종류: 섞임(동작 80 · 구조 10 · 글자 10)
- 지키는 것: codex 프롬프트가 입력 태그보다 앞에 untrusted-data 절 · 보고 무결성 문장 · 행동 금지 문장을 항상 방출하고(ascii 출력에서도), 그 문장의 출처가 프로필이 아니라 preamble 인 것
- 거짓 실패 위험: 낮음 — 프롬프트 조립이 바뀔 때만 깨진다(빌더 · 프로필 하한 수 변동에는 깨짐)
- 겹침: test_build_codex_prompt.sh 가 같은 빌더의 다른 계약을 잼. 한 파일 안에서 러너 × 프로필 4개 교차는 프로필이 절 방출에 영향을 주지 않는데 같은 판정을 프로필마다 되풀이
- 보안 갈래: 예 — 프롬프트 주입 방어 절(P21)의 방출과 지배 순서
- 판정 후보: 줄임 — 프로필별 부정 grep 은 그대로 두고 러너 실행(방출 · ascii · dominance)은 프로필 하나로 줄여도 지키는 것이 같다
- 확신: 중간

#### 읽지 못한 것 — shallow-02
없음 (32개 테스트 파일 모두 끝까지 읽음. 단 겹침 칸에서 「확인 못 함」으로 적은 다른 테스트들의 내용은 열어보지 않았다.)

## 묶음 shallow-03

### plugins/quality-gates/tests/test_codex_result_banner.sh
- 초: 0.1
- 줄 수: 137
- 고친 횟수: 4
- 크기: 작음 — SKILL.md 한 파일에 awk · sed · grep 만 돈다
- 종류: 글자
- 지키는 것: 코드리뷰 경로에서 codex 결과 판정 절차(산출물 부재 · 0바이트, `codex_failed: false` 양성 표식, 「findings 0건 ≠ clean」, 「모델 다양성」 배너)가 SKILL 에 적혀 있어야 오케스트레이터가 codex 실패를 깨끗함으로 읽지 않는다 — 문서 확인이라 모델이 따르는지는 못 잰다.
- 거짓 실패 위험: 높음 — 섹션 윈도우(헤딩 · 3칸 들여쓰기 볼드 · +50줄)와 한국어 문구에 기대서 SKILL 을 다듬거나 소절 순서를 바꾸면 깨진다
- 겹침: 못 찾음 (이 SKILL 소절을 겨냥한 다른 테스트는 못 찾았다. test_critiquing_artifacts_skill.sh 는 다른 SKILL 이다)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 지키는 것이 분명하고 0.1초라 비용이 맞다. 다만 `section_window` 가 70줄이라 같은 꼴 윈도우를 쓰는 다른 테스트와 함께 쓰는 헬퍼로 뽑을 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh
- 초: 0.1
- 줄 수: 19
- 고친 횟수: 5
- 크기: 작음 — 파일 존재 · 실행 비트와 grep 한 번
- 종류: 구조
- 지키는 것: codex-reviewer 가 에이전트가 아니라 스크립트로 있고 실행 가능하며, quality-pipeline SKILL 이 kill switch(`DEVBREW_QUALITY_GATES_DISABLE_CODEX`)나 `codex_available` 를 언급한다.
- 거짓 실패 위험: 중간 — 파일 이름 · 경로 변경이나 SKILL 에서 두 낱말이 사라질 때 깨지고 상대 경로를 써서 리포 루트가 아닌 곳에서는 못 돈다
- 겹침: plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh — 러너 스크립트 실재와 invocation 플래그를 더 세게 잰다. 파일 이름이 「frontmatter」인데 frontmatter 는 재지 않는다(헤더 주석이 샌드박스 확인을 test_sandbox_enforced.sh 로 넘겼다고 적는다)
- 보안 갈래: 예
- 판정 후보: 합침 — 에이전트 파일 부재 · 스크립트 실재는 no_effort_pin 이 이미 보고, 남는 kill switch 문구 한 줄만 kill switch 락으로 옮기면 된다(보안 글자 확인이라 줄 자체는 남긴다)
- 확신: 중간

### plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh
- 초: 0.7
- 줄 수: 159
- 고친 횟수: 8
- 크기: 중간 — plugins/* 전체를 `grep -rS` 로 여러 번 훑고 파일마다 하위 grep · awk 를 띄운다
- 종류: 글자
- 지키는 것: codex 를 부르는 모든 러너가 `-s read-only` 샌드박스를 invocation 줄에 유지하고(주석 제외), 세 이름 붙은 러너가 `-C` · `--json` 을 유지하며, 추론 강도 핀(`model_reasoning_effort`)이 어디에도 없다 — 사용자 워킹트리에 샌드박스 없이 codex 가 붙는 것을 막는다.
- 거짓 실패 위험: 중간 — 호출부 정규식(`codex exec`)에 기대서 호출 형태를 바꾸면 깨지고 positive 하한(디렉토리 4 · 호출부 3)이 플러그인 수에 매인다
- 겹침: plugins/quality-gates/tests/test_sandbox_enforced.sh · test_codex_invocation_contract.sh — 헤더가 같은 `-s read-only` 를 mock codex 의 실제 argv 로 잰다고 밝힌다(내용은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 샌드박스 플래그 존속은 보안 경계이고 0.7초다. 주석 설명이 길 뿐 확인은 촘촘하다
- 확신: 중간

### plugins/quality-gates/tests/test_compute_test_scope_candidates.sh
- 초: 2.9
- 줄 수: 128
- 고친 횟수: 10
- 크기: 중간 — 케이스마다 임시 git 레포를 새로 만들고 스크립트를 하위 프로세스로 여러 번 부른다
- 종류: 동작
- 지키는 것: 바뀐 소스 · 바뀐 테스트 · `# guards:` 선언에서 영향 테스트 후보와 분모를 맞게 고르고, 기준선을 못 풀거나 git 이 실패하면 「후보 없음」이 아니라 exit 4 로 멈춘다.
- 거짓 실패 위험: 낮음 — 동작이 바뀔 때만 깨진다. 단 stderr 안내 문장 전체를 핀하는 한 줄은 문구에 민감하다
- 겹침: plugins/quality-gates/tests/test_guards_declaration_mapping.sh — 같은 스크립트의 guards 축(이 파일의 「guards 글롭이 바뀐 파일에 걸린 락」 · `--emit-guards` 와 일부 겹침). test_resolve_baseline.sh 와 기준선 해석이 겹칠 수 있다(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 영향 테스트 선택이 어긋나면 diff 에 걸린 테스트가 조용히 빠지므로 지키는 것이 크다. 변경 없는 케이스 · 인자 오류 케이스는 레포 하나를 공유할 수 있으나 이득이 작다
- 확신: 중간

### plugins/quality-gates/tests/test_cost_consent.sh
- 초: 0.1
- 줄 수: 44
- 고친 횟수: 1
- 크기: 작음 — 가짜 하네스 스크립트를 두 번 부른다
- 종류: 동작
- 지키는 것: 글자만 지킴 — tests/harness/run_consent_gate.sh(테스트가 직접 가진 흉내 스크립트)가 마커 파일이 없으면 질문 파일을 쓰고 있으면 쓰지 않는다는 것뿐이다. 플러그인 코드는 하나도 부르지 않는다.
- 거짓 실패 위험: 중간 — 사용자의 실제 `~/.claude/quality-gates/codex-cost-consent.md` 를 옮겼다 되돌리므로 SIGKILL 이나 병렬 실행에서 사용자 파일이 사라질 수 있다
- 겹침: 못 찾음 (`codex-cost-consent` 를 쓰는 곳은 이 테스트와 하네스뿐이다). test_gate_era_prose_absent.sh 는 이 비용 동의 게이트가 구현된 적이 없다고 못 박는다
- 보안 갈래: 아니오
- 판정 후보: 지움 — 대상이 플러그인에 없는 장치의 흉내라 깨져도 사용자에게 잘못되는 것이 없고, 실제 홈 폴더를 건드리는 위험만 있다
- 확신: 높음

### plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh
- 초: 0.4
- 줄 수: 307
- 고친 횟수: 17
- 크기: 작음 — SKILL 한 파일 grep · awk 와 python 한 번(토큰 경계)
- 종류: 섞임(동작 0 · 구조 3 · 글자 약 85 · 변이 0)
- 지키는 것: artifact-critique SKILL 이 kill switch 두 개를 집행 줄로 가지며, 경로 인가(E2c)가 리뷰어 읽기보다 앞서고(심볼릭 링크로 바깥 파일이 codex 로 새는 것을 막는다), 지적만 받기가 E2c 로만 가고, 변경 신호가 커밋보다 앞이며, kill switch 절이 앞 5,000토큰 안에 있다.
- 거짓 실패 위험: 높음 — E3 선택지 · 질문 문장 수십 개를 글자 그대로 핀해서 문구를 다듬기만 해도 깨진다(고친 횟수 17)
- 겹침: plugins/quality-gates/tests/test_artifact_critique_truths.sh · test_qg_critique_routing.sh — 같은 SKILL 을 겨냥한다(내용 겹침은 확인 못 함). 한 파일 안에서 E3 문장 핀과 지적만 받기 문장 핀이 같은 방식으로 되풀이된다
- 보안 갈래: 예
- 판정 후보: 줄임 — kill switch 집행 줄 · 순서(경로 인가 → 리뷰어) · E2c 로만 가는 불변식은 남기고, E3 선택지 라벨 · 얻음/내줌 · 안내 문장의 전문 핀은 동작을 정하지 않는 말투 확인이라 덜어낸다
- 확신: 중간

### plugins/quality-gates/tests/test_detect_codex.sh
- 초: 0.2
- 줄 수: 121
- 고친 횟수: 7
- 크기: 중간 — 탐지 스크립트를 하위 프로세스로 열 몇 번 부르고 임시 폴더 · 추적 중인 conf 를 덮어 썼다 복원한다
- 종류: 섞임(동작 약 12 · 구조 0 · 글자 5 · 변이 0)
- 지키는 것: codex 탐지가 미설치 · kill switch · codex 안 샌드박스 · 인증 없음 · 나쁜 판 · 판 하한 미달 · 판독 불가 각각에서 맞는 skip_reason 을 내고 이웃 플러그인의 스위치는 듣지 않으며, 망가진 conf 는 fail-closed 로 막는다.
- 거짓 실패 위험: 낮음 — 동작이 바뀔 때만 깨진다. 추적 파일 conf 를 덮어쓰므로 SIGKILL 시 워킹트리가 더럽혀진다
- 겹침: plugins/plugin-audit/tests/test_detect_codex.py · plugins/quality-gates/tests/test_codex_copies_agree.sh · test_codex_backward_compat.sh — 같은 정본 탐지 스크립트의 사본 · 호환을 다른 각도로 잰다(케이스 단위 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 외부 프로그램에 내용이 넘어가는 경로의 스위치 · 하한 판정을 동작으로 잰다. 0.2초
- 확신: 높음

### plugins/quality-gates/tests/test_diff_test_results.py
- 초: 3.6
- 줄 수: 428
- 고친 횟수: 20
- 크기: 중간 — 케이스마다 python 으로 짝짓기 스크립트를 새로 띄우고 임시 git 레포 · 마지막 클래스는 worktree 둘을 케이스마다 만든다
- 종류: 동작
- 지키는 것: 기준선 · HEAD 결과 쌍에서 새 회귀 · 새 테스트 빨강 · 조용한 소실 · 기준선 실행 불가를 맞게 가르고, 계약 위반(꼬리 값 · 행 수 · 다른 커밋 · 누락 러너)은 exit 4 로 거부해 잘린 출력이 clean 으로 새지 못하게 한다.
- 거짓 실패 위험: 낮음 — 출력 계약이 바뀔 때만 깨진다. 단 `degrade_causes` · 한국어 공시 문구 일부를 핀한다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh · test_verdict_no_reread.sh (verdict.py 를 같이 부른다, 내용은 확인 못 함). 한 파일 안에서 error 축 세 변형 · mixed-mode smeared 두 변형처럼 같은 확인을 방향만 바꿔 되풀이한다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 판정의 입력을 만드는 핵심 계약이라 지키는 것이 크다. 중복 변형은 소수라 줄여도 이득이 작다
- 확신: 중간

### plugins/quality-gates/tests/test_differential_procedure.sh
- 초: 0.9
- 줄 수: 202
- 고친 횟수: 8
- 크기: 중간 — 대부분 grep 이고 D1 펜스 추출 · 실행에서 임시 레포와 가짜 스크립트를 쓰며 python 을 두 번 부른다
- 종류: 섞임(동작 약 10 · 구조 0 · 글자 약 70 · 변이 0)
- 지키는 것: 차등 테스트 절차 문서와 SKILL 이 판정 인자를 기계가 낸 `qg-verdict-args:` 줄 그대로 쓰게 이어져 있고(모델이 숫자를 옮겨 적지 않는다), 반복마다 앞 사본을 지우며, 토픽 축을 매 반복 새로 읽고, kill switch 가 켜지면 저장소 코드를 호스트에서 도는 조사용 실행까지 막는다.
- 거짓 실패 위험: 높음 — 줄 전체 일치(`grep -cxF`)와 긴 한국어 문장 · 코드 펜스 전문을 핀한다
- 겹침: plugins/quality-gates/tests/test_e2e_docs.sh — `<<'QG_ARGS_*'` 판정 펜스 · R24 · 「세션 폴더를 다시 읽지 않는다」 확인이 두 파일에 겹친다. test_one_pipeline_surface.sh 가 같은 레퍼런스의 토큰 부재를 잰다
- 보안 갈래: 예
- 판정 후보: 줄임 — D1 펜스를 실제로 돌리는 케이스와 kill switch(조사용 실행 금지) 핀은 남기고, e2e_docs 와 겹치는 최종 판정 펜스 문면 확인과 문장 전문 핀을 덜어낸다
- 확신: 중간

### plugins/quality-gates/tests/test_differential_trees.sh
- 초: 1.9
- 줄 수: 158
- 고친 횟수: 3
- 크기: 중간 — 케이스마다 임시 git 레포를 만들고 worktree 를 만들고 지운다
- 종류: 동작
- 지키는 것: 일회용 트리 · 실행 메모를 지우는 길이 자기 이름공간과 표지가 맞는 것만 지우고(`.claude` 링크 · 가짜 표지 · 링크 디렉토리 · 이름공간 밖 · 나쁜 세션 id 는 거부), HEAD 축을 기준선 sha 로 만들 수 없다.
- 거짓 실패 위험: 낮음 — 지우기 규칙이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_qg_worktree_helper.sh · test_qg_objects_unreachable.sh — 같은 qg-worktree.sh 를 다룬다(케이스 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 리뷰 대상 리포가 심은 링크 · 표지로 리포 밖이 지워지는 길을 동작으로 막는 보안 락이다
- 확신: 높음

### plugins/quality-gates/tests/test_discover_spec_keys.sh
- 초: 0.4
- 줄 수: 30
- 고친 횟수: 2
- 크기: 중간 — 임시 git 레포 하나, 스크립트 한 번, python 세 번
- 종류: 동작
- 지키는 것: discover-spec.sh 의 JSON 출력 키가 intent_source · intent_note · intent_file · specs 넷뿐이고 옛 `spec_path` 키가 없으며 `Spec:` 트레일러가 첫 의도 출처다.
- 거짓 실패 위험: 중간 — 출력에 키를 하나 더하면 깨진다(의도된 계약)
- 겹침: plugins/quality-gates/tests/test_discover_spec.sh — 같은 discover-spec.sh 를 14번 고친 큰 테스트가 따로 있다(키 집합 확인 중복 여부는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 합침 — 같은 스크립트의 출력 계약이라 test_discover_spec.sh 의 한 케이스로 옮기면 임시 레포 준비를 한 번 덜 한다
- 확신: 중간

### plugins/quality-gates/tests/test_doc_paths.py
- 초: 0.2
- 줄 수: 225
- 고친 횟수: 3
- 크기: 작음 — 모듈을 한 프로세스에서 불러 단위로 재고, CLI 만 하위 프로세스 몇 번
- 종류: 동작
- 지키는 것: 리뷰 diff 에서 뺄 문서 경로 규칙이 문서 파일만 빼고(모델이 읽는 파일 · 코드 · MDX 는 패턴에 걸려도 남기고), 환경 변수 패턴이 나쁘면 알리며, 설정이 이번 변경에서 바뀌면 기본값으로 되돌아가 변경이 자기 리뷰를 빼내지 못하게 한다.
- 거짓 실패 위험: 낮음 — 규칙이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_review_diff.sh · test_review_scope_composition.sh — 같은 doc_paths.py 를 쓴다(겹침은 확인 못 함). 한 파일 안에서 test_select_agrees_with_matches 와 test_glob_semantics 가 일부 겹친다
- 보안 갈래: 예
- 판정 후보: 둠 — 리뷰어가 읽을 범위가 조용히 줄지 않게 하는 락이고 0.2초다
- 확신: 높음

### plugins/quality-gates/tests/test_e2e_docs.sh
- 초: 0.5
- 줄 수: 406
- 고친 횟수: 18
- 크기: 작음 — SKILL · 레퍼런스 · README · 철학 문서 grep 과 awk, 재구성 헬퍼 한 번
- 종류: 섞임(동작 약 3 · 구조 약 8 · 글자 약 150 · 변이 0)
- 지키는 것: e2e 절이 SKILL 에서 맞는 자리에 있고, 지문 rc 가 걷기의 게이트이며(kill switch 에서는 CLI 명령을 하나도 실행하지 않고, 승인된 명령 줄만 실행한다), D 를 정하는 모든 줄이 git 최상위 가드 아래에 있고, 판정 펜스가 세션 폴더를 다시 읽지 않는다.
- 거짓 실패 위험: 높음 — README 한계 줄 · 철학 P4 문장 · 질문 문장을 줄 전체(`grep -cxF`) · 정규식으로 핀한다. 문구를 다듬기만 해도 깨진다(고친 횟수 18)
- 겹침: plugins/quality-gates/tests/test_differential_procedure.sh — 최종 판정 펜스 · R24 확인이 겹친다. test_one_pipeline_surface.sh 의 `##` 절 순서 핀과 K-8(절 순서)이 겹친다
- 보안 갈래: 예
- 판정 후보: 줄임 — 지문 rc 게이트 · 승인된 줄만 실행 · TOP 가드 · 판정 펜스 재독 금지는 남기고, README 한계 문장 · 철학 P4 문장 · 질문 선택지 문장의 전문 핀은 동작을 정하지 않아 덜어낸다
- 확신: 중간

### plugins/quality-gates/tests/test_e2e_fixture_app.sh
- 초: 1.8
- 줄 수: 72
- 고친 횟수: 1
- 크기: 중간 — fixture 리포를 만들고 파이썬 서버를 포트에 띄우고 curl 로 부른다(바깥 프로세스 · 네트워크 루프백)
- 종류: 동작
- 지키는 것: e2e 걷기가 기대어 서는 fixture 리포(main · e2e-ok · e2e-bug)가 만들어지고, e2e-ok 에서는 API 계약이 지켜지고 e2e-bug 에서는 HTTP 층에서만 깨지며 두 브랜치 모두 단위 테스트는 통과한다 — 걷기용 바닥이 살아 있는지 잰다.
- 거짓 실패 위험: 중간 — 빈 포트 경합 · curl 부재 · 부팅 20초 상한에 걸린다
- 겹침: plugins/quality-gates/tests/test_e2e_state.sh — 같은 e2e-state.sh boot · stop 을 쓴다(케이스 겹침은 확인 못 함). 이 fixture 를 쓰는 다른 테스트는 못 찾음 — 소비자가 사람의 수동 걷기뿐이면 fixture 자체를 지키는 락이다
- 보안 갈래: 아니오
- 판정 후보: 둠 — fixture 가 깨지면 e2e 걷기를 시험할 바닥이 없어지나, 소비자가 자동 테스트에 없어 가치가 불확실하다
- 확신: 낮음

### plugins/quality-gates/tests/test_e2e_verdict.sh
- 초: 1.1
- 줄 수: 119
- 고친 횟수: 3
- 크기: 중간 — verdict.py 를 케이스마다 python 으로 새로 띄운다(약 40회)
- 종류: 동작
- 지키는 것: 최종 판정이 e2e fail → defect, e2e 미확인 → not-certified(e2e-unconfirmed), e2e 가 안 함 · 꺼짐 · pass 일 때는 앞 판정을 바꾸지 않게 합치고, 잘못된 호출 · 판독 불가 앞 판정은 exit 2 · 4 로 거부한다.
- 거짓 실패 위험: 낮음 — 판정 우선순위나 출력 줄 꼴이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh · test_verdict_no_reread.sh · test_v_requirements.sh — 같은 verdict.py 를 다룬다(케이스 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 판정을 우선순위 규칙으로 합치는 코드가 정확해야 한다. 세 판정 × 다섯 상태 반복은 같은 python 을 열다섯 번 띄우나 이득이 작다
- 확신: 높음

### plugins/quality-gates/tests/test_entry_safety_e1_e6.sh
- 초: 6.5
- 줄 수: 363
- 고친 횟수: 15
- 크기: 큼 — setup-qg.sh 를 수십 번 부르고, 플러그인 scripts 를 `cp -RL` 로 복사하고, 다른 테스트(test_qg_gc 유닛 · shared 위치 인자 검사)를 다시 돌린다
- 종류: 섞임(동작 약 80 · 구조 0 · 글자 0 · 변이 약 2)
- 지키는 것: setup · GC 가 빈 · 패턴 밖 세션 id, 링크로 풀린 state root · 세션 폴더 · `.claude`, 예약 이름, 마커 없는 폴더, 다른 세션의 폴더를 지우거나 쓰지 않고(한 줄 사유로 거부), 플러그인 루트를 cwd 로 바꿔치지 않으며, GC 끄기 토큰을 전체 일치로만 받고, 리뷰 대상 리포의 git 훅을 돌리지 않는다.
- 거짓 실패 위험: 낮음 — 지우기 · 거부 동작이 바뀔 때만 깨진다. 단 E3 · E4 는 다른 테스트의 통과 여부에 묶여 그쪽이 깨지면 같이 깨진다
- 겹침: plugins/quality-gates/tests/test_qg_gc.py (QgGcRootSafetyTest 를 이 파일이 다시 돌린다) · shared/tests/test_skill_body_no_positional_tokens.sh (E3 가 다시 돌린다) · plugins/quality-gates/tests/test_setup_qg.sh · test_isolation.sh (같은 SID 재실행)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — E1 · E2 · E5 · E6 은 보안 동작이라 그대로 두고, E3 · E4 의 「다른 테스트를 다시 돌려 결과 받기」는 러너가 이미 각각 돌리므로 빼면 같은 확인을 두 번 하는 비용이 사라진다
- 확신: 높음

### plugins/quality-gates/tests/test_extract_codex_invocations.sh
- 초: 0.2
- 줄 수: 62
- 고친 횟수: 1
- 크기: 작음 — 임시 폴더에 작은 픽스처를 만들고 수집기를 python 으로 세 번
- 종류: 동작
- 지키는 것: codex 호출 수집기가 조상 경로에 `.claude` 가 있는 worktree 배치에서도 스캔하고, 스캔 루트 안쪽의 플러그인별 `.claude` · `__pycache__` 는 계속 거른다 — 틀리면 `-s read-only` 샌드박스 전수 스캔이 worktree 에서 호출부 0건을 보고 조용히 통과한다.
- 거짓 실패 위험: 낮음 — prune 규칙이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_sandbox_enforced.sh · tests/lib/codex_observation.sh — 이 수집기의 소비자다(헤더가 전용 테스트가 없었다고 밝힌다)
- 보안 갈래: 예
- 판정 후보: 둠 — 샌드박스 스캔의 눈을 지키는 작은 동작 락이다
- 확신: 중간

### plugins/quality-gates/tests/test_failure_injection.sh
- 초: 0.2
- 줄 수: 63
- 고친 횟수: 1
- 크기: 작음 — mock codex 스크립트 다섯 개를 돌려 파서에 먹인다
- 종류: 동작
- 지키는 것: codex 가 실패한 다섯 모양(exit 1 · 깨진 JSON · agent_message 없음 · 펜스 없는 JSON · stderr 인증 오류)이 파서의 meta 사유(missing_result · malformed_json · auth_error_in_stderr)로 나온다.
- 거짓 실패 위험: 낮음 — 파서 사유 이름이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_findings_parser.sh — 같은 파서의 같은 사유(malformed · missing agent_message · auth stderr)를 인라인 픽스처로 다시 잰다. test_codex_exit_meta.sh · test_codex_runner_degrade_contract.sh 도 같은 파서를 부른다. 공용 assert.sh 를 쓰지 않고 자체 카운터를 가진다
- 보안 갈래: 아니오
- 판정 후보: 합침 — findings_parser 의 픽스처와 같은 확인이라 mock 다섯 개 중 `exit-1` · `valid-json-no-fence` 두 모양만 findings_parser 로 옮기면 파일 하나가 줄어든다
- 확신: 중간

### plugins/quality-gates/tests/test_findings_parser.sh
- 초: 0.7
- 줄 수: 175
- 고친 횟수: 8
- 크기: 중간 — 파서를 케이스마다 python 으로 새로 띄운다(약 20회)
- 종류: 동작
- 지키는 것: codex 출력 파서가 펜스 · 원본 JSON · 옛 모양을 읽고, 깨짐 · 누락 · 인증 오류 · 시간 초과를 meta 사유로 내며, 마지막 펜스 블록만 고르고(프롬프트 주입 차단), 삼중 따옴표 주입을 실행하지 않고, 비목록 findings 를 사유와 함께 강제하고, stderr 를 못 읽으면 알린다.
- 거짓 실패 위험: 낮음 — 파서 출력 계약이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_failure_injection.sh — 같은 사유 확인이 겹친다. test_codex_copies_agree.sh (사본 일치) · test_codex_exit_meta.sh
- 보안 갈래: 예
- 판정 후보: 둠 — 모델 밖 프로그램이 낸 글을 읽는 입구의 주입 안전을 동작으로 잰다
- 확신: 높음

### plugins/quality-gates/tests/test_gate_era_prose_absent.sh
- 초: 0.1
- 줄 수: 62
- 고친 횟수: 5
- 크기: 작음 — `git ls-files` 로 qg 산문 목록을 얻어 파일마다 grep 한다
- 종류: 글자
- 지키는 것: 글자만 지킴 — qg 의 `*.md` · plugin.json 에 「Review gate」 · 「Runtime gate」 · 「2-gate」 낱말이 없고, security-reviewer 설명 · artifact-critique SKILL 한 줄 · README 비용 단락 끝 문장이 그대로다. 이 낱말이 남아도 플러그인 동작은 바뀌지 않는다.
- 거짓 실패 위험: 높음 — 영어 낱말 하나만 들어와도 깨지고 새 문구 핀은 에이전트 설명 문장 전체를 재서 문구를 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/test_one_pipeline_surface.sh — 같은 옛 게이트 낱말(`runtime gate` · `review gate`)의 부재를 SKILL · 레퍼런스에서 잰다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 옛 게이트 낱말 부재는 one_pipeline_surface 의 토큰 목록에 한 줄을 더하고 코퍼스만 넓히면 된다. 남는 「새 문구」 · 「동의 게이트 주장 없음」 문장 핀은 동작을 정하지 않는다
- 확신: 중간

### plugins/quality-gates/tests/test_gh_repo.sh
- 초: 1.9
- 줄 수: 201
- 고친 횟수: 6
- 크기: 중간 — 케이스마다 임시 git 레포를 새로 만들고 스크립트를 부른다(약 80회), 가짜 gh · ssh 를 PATH 앞에 둔다
- 종류: 동작
- 지키는 것: `gh -R` 에 넣을 origin(호스트/owner/repo)을 URL 일곱 꼴 · SSH 별칭 · insteadOf · gh 가 아는 호스트에서 맞게 정하고, 호스트 자리에 `-` 로 시작하는 값이나 이상한 글자가 오면 ssh 에 넘기지 않아 옵션 주입(`-oProxyCommand`)을 막으며, 못 뽑거나 gh · ssh 가 없으면 rc 3 · 4 와 사유로 멈춘다.
- 거짓 실패 위험: 낮음 — URL 해석 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill 의 gh_repo.py 테스트 — 헤더가 URL 꼴이 같다고 밝힌다(겹침 정도는 확인 못 함). plugins/spec-distill/tests/test_gh_single_door.sh
- 보안 갈래: 예
- 판정 후보: 둠 — 주입 방어와 대상 레포 결정이 틀리면 엉뚱한 레포에 글이 올라간다. git init 반복은 줄일 수 있으나 이득이 작다
- 확신: 높음

### plugins/quality-gates/tests/test_git_derived_scope.sh
- 초: 0.1
- 줄 수: 75
- 고친 횟수: 6
- 크기: 작음 — SKILL 한 문단을 awk 로 잘라 grep 몇 번
- 종류: 글자
- 지키는 것: SKILL 의 `resolved_scope_file_count` 정의가 「오케스트레이터가 실제로 resolve 한 집합의 크기」이고 `$branch_ahead_count` 와 등식이 아니며 판정 불가를 조용히 0 으로 취급하지 않아야 정직 판정 바닥(범위가 비었는데 변경이 있으면 scope-empty)이 도달 불가능해지지 않는다 — 모델이 읽는 정의 문장이라 영어 문구에 묶인다.
- 거짓 실패 위험: 높음 — 영어 문구(`the size of the file set you actually resolved` · `do NOT silently treat it as 0`)와 awk 시작 · 끝 앵커에 기대서 문장을 다듬으면 깨진다. 공용 assert.sh 를 쓰지 않고 `git rev-parse` 로 cwd 를 정한다
- 겹침: 못 찾음 (이 정의 문단을 겨냥한 다른 테스트는 못 찾았다)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 바닥이 무력화된 이력이 실제로 있었던 불변식이라 근거가 있고 0.1초다. 다만 `files.md` 부재 한 줄은 글자만 지킨다
- 확신: 중간

### plugins/quality-gates/tests/test_governance_no_capability_caps.sh
- 초: 0.3
- 줄 수: 362
- 고친 횟수: 21
- 크기: 작음 — CLAUDE.md · 철학 · 가이드 · 플러그인 산문 grep 과 awk
- 종류: 글자
- 지키는 것: 규약 문서와 플러그인 산문에 fan-out 수량 임계 · wall-clock · single-agent 기본값 편향이 없고(인용부까지 개념 별칭으로 훑는다), 규약 문장 몇 개(cost_class · Law 1 · 판 올림 · 상태 글머리 · 끄는 길)가 확정 문안과 바이트 같다 — 앞 절은 능력 억제가 규약으로 되돌아오는 것을 막고 뒤 절은 문서 문안이 바뀌지 않게 잠근다.
- 거짓 실패 위험: 높음 — `STATE_LINE` · `SWITCH_LINE` · `FIXED_CLAUDE` 처럼 한 줄 전체를 바이트 단위로 핀하고 README 수치 · 링크 수 문장까지 재서 CLAUDE.md 를 고칠 때마다 깨진다(고친 횟수 21)
- 겹침: plugins/quality-gates/tests/test_law2_prose.sh — CLAUDE.md 의 agent 격리 문장을 둘 다 잰다. shared/tests 쪽 규약 락과의 겹침은 확인 못 함
- 보안 갈래: 아니오 (kill switch · 보안 컨트롤 문장을 담은 줄을 핀하지만 문서 글자이고 집행이 아니다)
- 판정 후보: 줄임 — 능력 상한 부재 스캔(AC8a · AC8e, 양성 짝 포함)은 남기고, 바이트 같음 핀(`FIXED_*` · `STATE_LINE` · `SWITCH_LINE`)과 F6 · F7 이 모은 잡다한 문서 문장 핀은 문서를 고치는 사람의 일을 막는 변경 감지기라 덜어낸다
- 확신: 중간

### plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh
- 초: 3.9
- 줄 수: 106
- 고친 횟수: 1
- 크기: 중간 — `git ls-files` 로 모든 tests 아래 `.sh` 를 모아 파일마다 `head | grep` 을 띄우고 선언을 가진 락마다 `--emit-scanned` 로 락을 다시 실행한다
- 종류: 동작
- 지키는 것: `# guards:` 선언 글롭과 락이 실제로 읽는 경로 집합이 서로를 덮어서(선언이 좁으면 조용한 미선택, 넓으면 헛돎) 영향 테스트 선택이 락을 빠뜨리거나 헛돌지 않는다.
- 거짓 실패 위험: 중간 — 락 하나가 `--emit-scanned` 를 잘못 구현하면(자기 재귀 · 전체 실행) 느려지거나 멈춘다. 새 락의 경로가 바뀌면 선언도 같이 고쳐야 한다
- 겹침: plugins/quality-gates/tests/test_guards_declaration_mapping.sh — 선택 쪽 축이고 이 파일은 선언 정확성 축이라 겹침 없음. test_compute_test_scope_candidates.sh 와 같은 `# guards:` 선언을 읽는다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 시간의 대부분이 모든 테스트 파일마다 셸 파이프 두 개를 띄우는 선언 탐지 루프로 추정되므로 `git grep -l` 한 번으로 바꾸면 지키는 것은 그대로고 싸진다
- 확신: 중간

### plugins/quality-gates/tests/test_guards_declaration_mapping.sh
- 초: 2.3
- 줄 수: 129
- 고친 횟수: 6
- 크기: 중간 — 케이스마다 임시 git 레포를 새로 만들고(여덟 번 가량) 후보 스크립트를 부른다
- 종류: 동작
- 지키는 것: 변경 파일의 확장자와 무관하게 `# guards:` 선언(탭 구분 포함)에 걸리면 그 락이 후보에 들고, 선언 밖 변경 · 선언 없는 테스트는 끌려 들어오지 않는다 — `.py` 사본이 편집돼도 copy-of 락이 선택된다.
- 거짓 실패 위험: 낮음 — 후보 선택 동작이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_compute_test_scope_candidates.sh — 같은 compute-test-scope-candidates.sh 의 `# guards:` 축(`--emit-guards` 확인이 양쪽에 있다)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 대상 네 개를 도는 반복이 `mk_repo` 를 대상마다 다시 만드는데 레포를 한 번 만들고 변경만 되돌리면 싸지고, 원하면 compute_test_scope_candidates 의 한 케이스로 합칠 수도 있다
- 확신: 중간

### plugins/quality-gates/tests/test_impact_runtime_docs.sh
- 초: 0.1
- 줄 수: 84
- 고친 횟수: 6
- 크기: 작음 — python 으로 JSON 한 번 읽고 grep · awk
- 종류: 구조
- 지키는 것: 글자만 지킴 — plugin.json 의 major 가 3 이상이고, CHANGELOG 에 `## [3.0.0] — 날짜` 항목과 Added · Changed · Removed 소절이 있고, README `## 구조` 트리에 스크립트 세 이름이 있고 실행 비트가 있다. 버전 · 문서 항목은 레포 규칙이 따로 정하고 케이스 이름(「exactly three」)과 달리 정확히 셋인지는 재지 않는다.
- 거짓 실패 위험: 높음 — README 소절 제목(`## 구조`)이나 CHANGELOG 형식을 고치면 깨진다
- 겹침: 확인 못 함 (CHANGELOG 연속 · 판 올림을 재는 레포 락이 있다고 알고 있으나 대조하지 않았다)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 판 · CHANGELOG · README 일치는 레포 전체 규칙으로 따로 지키고, 이 락이 재는 3.0.0 항목은 동작을 정하지 않는다. 실행 비트만 남기고 싶으면 스크립트 실재를 재는 다른 락에 한 줄로 합친다
- 확신: 중간

### plugins/quality-gates/tests/test_isolation.sh
- 초: 1.9
- 줄 수: 162
- 고친 횟수: 4
- 크기: 중간 — 임시 레포 · git worktree 를 만들고 setup-qg.sh 를 열 번 가량 부른다
- 종류: 동작
- 지키는 것: 같은 세션 id 를 쓰는 worktree 와 원 레포, 같은 디렉토리의 두 세션이 서로의 상태 폴더(result.md · session_id)를 보지도 지우지도 않고, 같은 세션 id 의 재실행은 거부 없이 자기 폴더를 새로 만든다.
- 거짓 실패 위험: 낮음 — 상태 폴더 위치 규칙이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_setup_qg.sh · test_worktree.sh · test_entry_safety_e1_e6.sh — T6(같은 SID 재실행 시 새로 시작)이 entry_safety 의 E1 「다시 실행이 자기 세션 폴더를 지운다」와 같다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 상태가 cwd 의 git 최상위 아래에 서는 성질이라 setup-qg.sh 를 다루는 test_setup_qg.sh 의 케이스로 옮기면 준비가 줄고 T6 중복도 사라진다
- 확신: 중간

### plugins/quality-gates/tests/test_law2_prose.sh
- 초: 0.2
- 줄 수: 100
- 고친 횟수: 11
- 크기: 작음 — 규약 문서 · 모든 README · SKILL · 레퍼런스 grep
- 종류: 글자
- 지키는 것: 활성 문서가 존재하지 않는 `allowedTools` 필드를 격리의 불가결한 층으로 주장하지 않고(`실제 키` · `tool 0개` 같은 거짓 주장 리터럴 포함), CLAUDE.md 가 「denylist 는 시간에 대해 fail-open」과 `tools:` allowlist 규범을 쓴다 — 리뷰어 격리에 대한 거짓 믿음이 되살아나 다음 저자가 재도입하는 것을 막는다.
- 거짓 실패 위험: 중간 — 낱말 한 개(`allowedTools`)가 어디든 쓰이면 깨진다. 코퍼스가 파일 수만큼 단언을 만든다
- 겹침: plugins/quality-gates/tests/test_governance_no_capability_caps.sh — CLAUDE.md 의 agent 격리 문장을 같이 잰다. 실제 리뷰어 `tools:` 집행은 agent frontmatter 를 재는 test_code_recritic_frontmatter.sh 등이 맡는다
- 보안 갈래: 예 (리뷰어 격리 규범의 문서 글자 — 집행 자체는 아니다)
- 판정 후보: 둠 — 거짓 격리 주장이 실제로 한 판 배포된 이력이 있는 자리이고 0.2초다
- 확신: 중간

### plugins/quality-gates/tests/test_lowered_gate_wiring.sh
- 초: 0.8
- 줄 수: 217
- 고친 횟수: 5
- 크기: 중간 — 합성기를 임시 폴더에서 여러 번 돌리고, 추출한 SKILL 기록 블록 · 확인 펜스를 bash 로 실행한다
- 종류: 섞임(동작 약 15 · 구조 약 3 · 글자 약 45 · 변이 0)
- 지키는 것: 재비판이 낮춘 지적이 사용자에게 보이고 되올릴 수 있다 — 합성기가 내는 `lowered:` 줄을 SKILL 게이트가 읽고, 기록 펜스가 「## 낮춘 지적」 절을 합성기 표 그대로 옮기며, 기타 칸 번호 확인 펜스가 표에 없는 번호(L11 · 1)를 되올리지 않는다.
- 거짓 실패 위험: 높음 — SKILL 4.5 의 질문 · 선택지 문장 수십 개를 글자 그대로 핀해서 문구를 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_recritic.sh · test_synthesize_findings_adjudication.py — 같은 합성기의 낮춘 출력을 잰다(겹침은 확인 못 함). test_code_recritic_frontmatter.sh 가 persona 를 잰다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 합성기 출력을 SKILL 블록에 넣어 돌리는 이음매 확인(case_record_fence · case_pick_fence)은 남기고, 질문 · 선택지 문장 전문 핀(case_step45_gate 대부분)은 동작을 정하지 않아 덜어낸다
- 확신: 중간

### plugins/quality-gates/tests/test_no_secret_prompts.py
- 초: 0.0
- 줄 수: 81
- 고친 횟수: 6
- 크기: 작음 — 한 프로세스에서 SKILL · 레퍼런스 파일을 읽고 정규식으로 훑는다
- 종류: 글자
- 지키는 것: SKILL · 레퍼런스(스킬 레벨 · 플러그인 레벨)에 「API 키 · 토큰 · 비밀번호 · DB URL 을 사용자에게 입력하라」는 지시가 없다(부정문은 허용) — 절차 본문에 비밀 값 요청 지시가 새로 들어가는 것을 막는다.
- 거짓 실패 위험: 중간 — 정규식 휴리스틱이라 무해한 문장도 걸릴 수 있다. 코퍼스가 줄면 vacuity 가드가 깨진다
- 겹침: 확인 못 함 (다른 플러그인의 비밀 프롬프트 스캔이 있는지 대조하지 않았다)
- 보안 갈래: 예
- 판정 후보: 둠 — 비밀 값 기록 금지(P21) 경계를 지키는 보안 글자 확인이고 비용이 0 이다
- 확신: 높음

### plugins/quality-gates/tests/test_no_write_matcher_hooks.sh
- 초: 0.1
- 줄 수: 27
- 고친 횟수: 4
- 크기: 작음 — 경로 존재 확인과 python 으로 JSON 한 번
- 종류: 구조
- 지키는 것: qg 에 `hooks/` 폴더도 plugin.json 의 `"hooks"` 키도 없다 — v10 이후 훅 0개라는 설계를 잠가 쓰기 도구에 발화하는 PostToolUse 항목이 되살아나지 않게 한다. 이름(「no_write_matcher」)보다 넓게 훅 전체를 막는다.
- 거짓 실패 위험: 중간 — 설계가 훅을 다시 허용하면 이 락이 stale-red 가 된다
- 겹침: 못 찾음 (훅 부재를 잰 다른 qg 테스트는 못 찾았다. README 의 「설치된 Hook」 절 규칙은 별개다)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 훅은 설치 즉시 모든 세션에 영향을 주는 표면이라 부재 락과 양의 짝이 그만한 값을 한다. 확신은 낮다
- 확신: 낮음

### plugins/quality-gates/tests/test_one_pipeline_surface.sh
- 초: 0.3
- 줄 수: 109
- 고친 횟수: 12
- 크기: 작음 — SKILL 과 레퍼런스 두 파일에 grep 을 서른 번 가량(대소문자 무관 포함)
- 종류: 글자
- 지키는 것: 오케스트레이터가 읽는 SKILL · 차등 레퍼런스에 옛 게이트 · verifier 시대 토큰(runtime-verifier · NEEDS_RESOLUTION · 대문자 PASS/FAIL 등)이 없고, 새 골격(`##` 절 열세 개가 정해진 순서, 흐름 ①②③ 순서, 봉인 · 워크트리 · 짝짓기 호출)이 있으며 게이트 범위 질문이 없다.
- 거짓 실패 위험: 높음 — `##` 절 목록 전체를 한 문자열로 핀해서 절을 하나 더하거나 이름을 바꿀 때마다 이 락을 고친다고 스스로 적는다(고친 횟수 12)
- 겹침: plugins/quality-gates/tests/test_gate_era_prose_absent.sh (옛 게이트 낱말 부재) · test_e2e_docs.sh (K-8 절 순서 · e2e 절 위치)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 흐름 순서(리뷰 → 차등 → 합성)와 옛 토큰 부재는 남기되, 절 목록 전체 핀은 e2e_docs 의 K-8 순서 확인이 이미 일부를 지키고 절 하나 더할 때마다 고쳐야 하는 변경 감지기라 덜어낸다
- 확신: 중간

#### 읽지 못한 것 — shallow-03

없음 — 32개 테스트 파일을 모두 끝까지 읽었다. 대상 스크립트 · 겹침 테스트는 이름과 일부 줄만 확인했고(test_discover_spec.sh · test_e2e_state.sh · test_qg_worktree_helper.sh · test_review_diff.sh · test_verdict_*.sh · spec-distill 쪽 gh 테스트 · 판 올림 레포 락은 열지 않았다), 그래서 「겹침」 칸의 해당 항목은 내용 겹침을 「확인 못 함」으로 적었다. 시간 쓰는 곳 추정은 얕게 읽는 묶음이라 적지 않았다.

## 묶음 shallow-04

### plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh
- 초: 1.1
- 줄 수: 474
- 고친 횟수: 20
- 크기: 중간 — python3 heredoc 십여 번 + 합성기(rf_synth)를 하위 프로세스로 여러 번 실행
- 종류: 섞임(동작 4 · 구조 1 · 글자 약 12 · 변이 0)
- 지키는 것: 오케스트레이터 SKILL 이 합성기를 항상 --emit-verdict · --angles 와 함께 부르고, 보안 각도 부재(kill switch 포함)가 탐지 0건이어도 clean 이 아니라 not-certified 로 가며, 반복 상한(CAP) 이후의 길이 사용자 승인 하나뿐임을 지킨다.
- 거짓 실패 위험: 높음 — SKILL.md 의 문장 · 표 · 펜스 문구를 정규식으로 구간 잘라 재므로 문구를 다듬거나 절을 옮기면 동작이 그대로여도 깨진다
- 겹침: plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh — 같은 보안 kill switch env 를 SKILL 에서 재는 다른 앵커; plugins/quality-gates/tests/test_plain_qg_templates.sh — Max-iter · CAP · 선택지 라벨 문구가 일부 겹침; 합성기 쪽 verdict 어휘는 test_verdict_vocabulary.sh · test_angle_coverage.sh (본문은 읽지 못함)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 합성기 동작 케이스(angle-absent 판정)는 유지하고, 줄 단위 문구 정규식 락은 동작 확인이나 파일 밖 핀으로 내릴 여지가 크다
- 확신: 중간

### plugins/quality-gates/tests/test_plain_field_path.sh
- 초: 2.6
- 줄 수: 249
- 고친 횟수: 7
- 크기: 중간 — 케이스마다 python3 · rf_prep · rf_synth 를 새로 띄우는 호출이 수십 번
- 종류: 섞임(동작 약 75 · 구조 0 · 글자 약 12 · 변이 0)
- 지키는 것: 리뷰어가 쓴 쉬운 문장(plain)이 변환기 · 합성기를 지나 화면에 먼저 나오고, 쓸 수 없는 plain(숫자 · 목록 · 공백)은 지적을 버리지 않은 채 빠지며, 재비판자에게는 plain 이 넘어가지 않는다.
- 거짓 실패 위험: 중간 — 합성 표의 정확한 줄 꼴(`| 요약 | 낸 곳 |`)과 한국어 문구를 grep 하므로 표 모양이 바뀌면 깨지지만 규칙 자체가 바뀔 때도 깨진다
- 겹침: 같은 파일 안에서 「쓸 수 없는 plain 은 빠지고 지적은 남는다」를 코드 경로 · codex 경로 · 비코드 경로 · 렌더(⑧)에서 되풀이; plugins/quality-gates/tests/test_plain_synth_output.sh — 합성기 첫 줄 · 표 한국어화; plugins/quality-gates/tests/test_recritic_code_profile.sh 와는 프로필 plain 문구 한 줄만 겹침
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 같은 plain 규칙을 세 경로에서 거의 같은 입력으로 되풀이하므로 입력을 표로 묶어 python 호출 수를 줄이고 파일 문면 grep(① 형식)은 한곳으로 모을 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_plain_qg_templates.sh
- 초: 0.5
- 줄 수: 219
- 고친 횟수: 18
- 크기: 작음 — SKILL · README · e2e 레퍼런스를 grep/awk 로 읽기만 함
- 종류: 섞임(동작 0 · 구조 3 · 글자 약 105 · 변이 0)
- 지키는 것: 사용자에게 보이는 선택지 라벨이 같은 절의 분기 불릿 글자와 같아 모델이 없는 선택지를 찾지 않게 하는 상호참조(Max-iter 절의 라벨↔분기 루프)는 지킨다; 그 밖의 대부분은 SKILL 문장이 그 한국어 글자로 있다는 확인이다.
- 거짓 실패 위험: 높음 — 문구를 다듬거나 줄을 넘기기만 해도 깨지고, 라벨을 고르면 같은 문구를 이 파일과 test_pipeline_verdict_wiring.sh 양쪽에서 고쳐야 한다
- 겹침: plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh — Max-iter · CAP · 차등 기원 문구; plugins/quality-gates/tests/test_plain_readme.sh — README 문구; plugins/quality-gates/tests/test_readme_state_diagram_complete.sh — README 상태도 라벨; test_publish_surface_removed.sh · test_render_terminal.sh — 완료 표 render-terminal table
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 라벨↔분기 일치 · 기록 펜스 형태 같은 상호참조만 남기고 한국어 문구를 한 줄씩 고정한 단언은 덜어도 동작을 지키는 것이 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_plain_readme.sh
- 초: 0.1
- 줄 수: 45
- 고친 횟수: 5
- 크기: 작음 — README 를 awk/grep 으로 읽기만 함
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/quality-gates/README.md 첫 문단 문구와 `## 쓰는 법` 표 · 흐름 첫 문단 문구(단, `## Principles Instantiated` 제목 존재와 표의 「친다」 칸이 진입 명령 다섯뿐이라는 확인은 레포 규칙 · 표면 정합을 지킨다)
- 거짓 실패 위험: 높음 — README 문장을 다듬기만 해도 깨진다
- 겹침: plugins/quality-gates/tests/test_readme_scope_reconcile.sh · test_readme_state_diagram_complete.sh · test_plain_qg_templates.sh — 모두 README.md 문구를 grep 한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — Principles Instantiated 제목과 진입 명령 표 행 집합만 남기고 문단 문구 단언은 지워도 동작이 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_plain_synth_output.sh
- 초: 1.7
- 줄 수: 166
- 고친 횟수: 7
- 크기: 중간 — 합성기를 여러 입력으로 실행하고 setup-qg.sh 를 오류 모양마다 하위 프로세스로 실행
- 종류: 섞임(동작 약 55 · 구조 0 · 글자 약 8 · 변이 0)
- 지키는 것: 합성기 첫 줄이 상태 문장이고, 읽지 못한 입력(주 입력 · 재비판자)이 있으면 「지적 없음」이라 말하지 않으며(false-clean 방지), setup 오류 줄이 쉬운 말로 시작하되 소비자가 읽는 영어 토큰을 남긴다.
- 거짓 실패 위험: 중간 — 한국어 문장을 통째로 등호 비교하므로 문구 변경에 깨지지만 입력 사망 처리는 동작 확인이다
- 겹침: plugins/quality-gates/tests/test_removed_plan_arg.sh — setup 배너에 「계획 파일」이 없다는 단언이 일부 겹침; test_plain_field_path.sh — 합성기 표 한국어화; 합성기 본 테스트 test_synthesize_findings.sh 와의 겹침은 읽지 못함
- 보안 갈래: 예
- 판정 후보: 둠 — 「아무도 확인하지 않은 것을 지적 없음이라 말하지 않는다」는 실제 동작을 실행해 확인하고 비용(1.7초)이 그에 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_precheck_retired.sh
- 초: 0.1
- 줄 수: 39
- 고친 횟수: 1
- 크기: 작음 — 파일 존재 확인과 grep (재귀 grep 한 번 포함)
- 종류: 섞임(동작 0 · 구조 1 · 글자 4 · 변이 0)
- 지키는 것: 은퇴한 pre-pipeline-check 스크립트와 그 결과 코드 이름(cleared_stale 등)이 SKILL 에 유령으로 남지 않고, setup-qg.sh 의 세션 ID 패턴 가드는 살아 있다.
- 거짓 실패 위험: 낮음 — 은퇴한 이름이 되살아날 때만 깨진다. 단 `git rev-parse --show-toplevel` 에 의존하므로 레포 밖 cwd 에서 부르면 깨진다
- 겹침: plugins/quality-gates/tests/test_publish_surface_removed.sh — 같은 종류(삭제된 표면의 개념 별칭 스윕)이나 대상이 다르다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 삭제된 표면이 남지 않았는지 보는 스윕이므로 test_publish_surface_removed.sh 류의 은퇴 표면 스윕 한 파일로 모을 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_publish_gh_two_files.sh
- 초: 0.2
- 줄 수: 95
- 고친 횟수: 6
- 크기: 작음 — python 한 번으로 추적 파일 전체를 정규식 스캔
- 종류: 섞임(동작 0 · 구조 0 · 글자 9 · 변이 0) — 코퍼스를 읽는 정적 스캔이고 매처 대조 8건을 함께 돌린다
- 지키는 것: gh 를 부르는 파일이 sink · discover-spec · gh-repo · other_teams 뿐이고 gh 쓰기(pr comment · api 등)는 publish-comment.sh 에만 있어, 다른 곳이 몰래 바깥에 글을 올리지 못한다.
- 거짓 실패 위험: 중간 — 새 문서나 스크립트에 `gh pr view` 같은 표기가 한 줄만 들어가도 깨진다(의도한 경계)
- 겹침: plugins/quality-gates/tests/test_publish_pipeline_wiring.sh — 게시 펜스가 gh 를 직접 부르지 않는다는 한 줄이 일부 겹침; 그 밖은 못 찾음
- 보안 갈래: 예
- 판정 후보: 둠 — 바깥에 글을 올리는 경로를 한 파일로 가두는 보안 경계이고 0.2초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_publish_pipeline_wiring.sh
- 초: 4.7
- 줄 수: 251
- 고친 횟수: 9
- 크기: 중간 — 게시 펜스를 bash 와 zsh 로 각각 돌리고 케이스마다 임시 git 레포(fresh_proj)를 새로 만든다(약 30 케이스 × 2 셸)
- 종류: 섞임(동작 약 85 · 구조 4 · 글자 3 · 변이 0)
- 지키는 것: 게시 펜스가 aborted · 범위 모드 · 작업 트리 더러움 · 이해글의 판정 줄 위조 · 두 번째 실행에서는 sink 를 부르지 않고, 안전하지 않은 세션 id(`../../../x` 등)는 거부하며, 코멘트 마지막 줄을 result.md 판정 절의 원문 판정 줄로만 채운다.
- 거짓 실패 위험: 중간 — 거절 줄 한국어 리터럴을 등호 비교하므로 문구 변경에 깨지고, zsh 가 없으면 한 셸분만 돈다
- 겹침: plugins/quality-gates/tests/test_range_wiring.sh — 범위 모드 게시 거절 줄과 두 번째 실행 거절이 겹침; plugins/quality-gates/tests/test_publish_comment_sink.sh — sink 쪽 동작(본문은 읽지 못함)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 케이스마다 git init · add · commit 을 되풀이하므로 템플릿 레포를 한 번 만들어 복사하면 지키는 것은 그대로 두고 초를 줄일 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_publish_surface_removed.sh
- 초: 1.4
- 줄 수: 61
- 고친 횟수: 4
- 크기: 중간 — 추적 파일 500여 개를 xargs grep 하고 render-terminal.py 를 세 번 실행
- 종류: 섞임(동작 약 5 · 구조 약 26 · 글자 약 7 · 변이 0)
- 지키는 것: 은퇴한 게시 표면(/qg-publish 명령 · 스킬 · 에이전트 · 스크립트 · 옛 테스트 이름)이 추적 트리와 코퍼스 어디에도 남지 않고, 새 sink 가 실행 비트로 추적되며 render-terminal 에는 table 만 남는다.
- 거짓 실패 위험: 중간 — 토큰 목록(qg-publish · pr-understanding 등)이 새 문서에 우연히 나오면 깨진다. 코퍼스 하한 500 이 레포가 줄면 깨진다
- 겹침: plugins/quality-gates/tests/test_precheck_retired.sh — 은퇴 표면 스윕; plugins/quality-gates/tests/test_render_terminal.sh — render-terminal table 동작; 삭제 파일 24개 목록은 git 이 이미 알려 주는 사실과 겹친다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 삭제된 파일 24개 존재 부재 루프는 개념 별칭 스윕이 대부분 포함하므로 덜고, 스윕 · 양의 짝(sink 실행 비트 · invalid choice)만 남긴다
- 확신: 중간

### plugins/quality-gates/tests/test_qg_critique_routing.sh
- 초: 0.2
- 줄 수: 45
- 고친 횟수: 8
- 크기: 중간 — 임시 git 레포 둘과 setup-qg.sh 를 열 번 남짓 하위 프로세스로 실행
- 종류: 섞임(동작 약 22 · 구조 1 · 글자 약 5 · 변이 0)
- 지키는 것: 파이프라인에 문서 비평 인자(critique)가 어느 위치에 와도 setup 은 exit 2 로 새 이름(/quality-gates:artifact-critique)을 안내하고 아무 파일도 쓰지 않으며, 끄는 스위치(DISABLE=1)가 그 안내보다 먼저 이긴다.
- 거짓 실패 위험: 낮음 — 인자 처리 순서가 바뀔 때만 깨진다(P1b 문구 확인만 문구에 민감)
- 겹침: plugins/quality-gates/tests/test_setup_qg.sh — setup-qg.sh 인자 처리 일반(본문은 읽지 못함)
- 보안 갈래: 예
- 판정 후보: 둠 — 잘못된 대상을 코드 파이프라인으로 돌리지 않고 kill switch 우선순위를 지키는 동작 확인이며 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_qg_false_clean_floor.sh
- 초: 0.8
- 줄 수: 148
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포를 만들고 check-review-scope.sh 를 실행(4 케이스)
- 종류: 섞임(동작 4 · 구조 0 · 글자 0 · 변이 0) — 단 floor_verdict 는 이 테스트 안에 정의된 사본이다
- 지키는 것: check-review-scope.sh 가 네 레포 상태(앞선 브랜치 · 변경 없음 · 기준선 없음)에서 changes_exist · branch_ahead_count · degraded 를 올바르게 내는 것만 실제로 지킨다. 「floor 가 not_clean 을 낸다」는 단언은 테스트 안 함수를 재는 것이라 production 판정을 지키지 않는다.
- 거짓 실패 위험: 낮음 — 스크립트 출력 키가 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_check_review_scope.sh — check-review-scope.sh 출력 계약; plugins/quality-gates/tests/test_resolve_baseline.sh — case_review_scope_contract · same_as_head 계열; plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh — 헤더가 정적 앵커를 그쪽이 잰다고 밝힌다
- 보안 갈래: 아니오
- 판정 후보: 지움 — floor_verdict 사본은 자기 자신을 재는 순환이고, 남는 스크립트 출력 확인은 test_check_review_scope.sh 가 이미 지킨다
- 확신: 중간

### plugins/quality-gates/tests/test_qg_gc.py
- 초: 1.9
- 줄 수: 654
- 고친 횟수: 16
- 크기: 중간 — 케이스마다 임시 폴더를 만들고 qg-gc.py 를 python 하위 프로세스로 새로 실행(약 30회) · 프로세스 안 패치 4건
- 종류: 섞임(동작 약 40 · 구조 1 · 글자 1 · 변이 0)
- 지키는 것: 세션 폴더 GC 가 TTL 이 지난 진짜 세션 폴더만 지우고 신선한 · 자기 세션 · 마커 없는 형제 · worktrees/baseline-cache 는 건드리지 않으며, 링크 · 링크된 루트로 저장소 밖을 만들거나 지우지 않고 kill switch 와 락 경합에서 물러선다.
- 거짓 실패 위험: 낮음 — 폴더 나이 · 링크 처리 동작이 바뀔 때만 깨지고 mtime 을 조작해 시간 문턱에 흔들리지 않는다
- 겹침: shared/gc/gc_common.py 를 spec-distill 도 쓰지만 그쪽 테스트는 확인 못 함; plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py 등은 qg-gc.py 를 언급만 한다
- 보안 갈래: 예
- 판정 후보: 둠 — 링크 탈출 · 삭제 범위 · kill switch 를 실제 실행으로 확인하고 1.9초로 규모가 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_qg_objects_unreachable.sh
- 초: 2.7
- 줄 수: 81
- 고친 횟수: 2
- 크기: 중간 — 임시 git 레포 둘에서 topic-head · qg-worktree · seal 을 실행하고 git fsck · cat-file 을 커밋마다 돌린다
- 종류: 동작
- 지키는 것: qg 가 만드는 봉인 · 합치기 커밋이 ref · reflog 로 도달 가능해지지 않아 git prune 이 회수하므로, 사용자 레포에 qg 커밋이 영영 쌓이지 않는다.
- 거짓 실패 위험: 낮음 — qg 가 커밋을 ref 에 붙일 때만 깨진다(저자 이름 qg seal 에 묶여 있어 그 문자열이 바뀌면 공허해진다)
- 겹침: plugins/quality-gates/tests/test_seal_no_side_effects.sh — 봉인 부작용(HEAD · 인덱스 불변)이나 도달 불가는 재지 않는다; 도달 불가를 재는 다른 테스트는 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 레포 오염이라는 실제 결함을 fsck 로 확인하고 양의 짝이 있다
- 확신: 중간

### plugins/quality-gates/tests/test_qg_worktree_helper.sh
- 초: 4.3
- 줄 수: 268
- 고친 횟수: 15
- 크기: 중간 — 섹션마다 임시 git 레포를 새로 만들고(약 25개) worktree add · 링크 생성 · qg-worktree.sh 실행을 되풀이
- 종류: 동작
- 지키는 것: qg-worktree.sh 가 qg-base/qg-head 이름의 자기 사본만 만들고 지우며, 브랜치를 쥔 사용자 worktree · 링크 · 밖을 가리키는 .claude/worktrees · 대소문자만 다른 이름은 건드리지 않고 rc 2 로 거부한다.
- 거짓 실패 위험: 낮음 — 이름 공간 · 링크 처리 동작이 바뀔 때만 깨진다(대소문자 구분 파일시스템은 SKIP)
- 겹침: plugins/quality-gates/tests/test_runtime_contract_invariance.sh — create-baseline · remove 이름 공간 밖 거부가 겹침; plugins/quality-gates/tests/test_range_wiring.sh · test_resolve_range.sh — create-head --range
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 경로 탈출 · 사용자 worktree 보호라는 지키는 것은 그대로 두고 레포 세우기(git init · config · commit)를 템플릿 복사로 줄일 여지가 있다
- 확신: 중간

### plugins/quality-gates/tests/test_range_wiring.sh
- 초: 5.5
- 줄 수: 415
- 고친 횟수: 7
- 크기: 큼 — 케이스마다 레포 + 클론(mkfix)을 새로 세우고 펜스를 뽑으려 python3 -I 를 약 40번 띄우며 SKILL 펜스를 실제 실행
- 종류: 섞임(동작 약 55 · 구조 0 · 글자 약 50 · 변이 0)
- 지키는 것: 범위 모드(range 시작..끝)에서 diff 기준 · 차등 기준선 · 리뷰어가 읽는 트리 · 판정 커밋이 모두 얼린 같은 두 커밋을 쓰고, 리뷰어가 커밋 안 된 변경 · 추적 안 된 파일이 있는 체크아웃이 아니라 끝 커밋 임시 트리를 읽으며, 범위에서는 PR 코멘트를 달지 않는다.
- 거짓 실패 위험: 높음 — SKILL 절 창과 펜스 본문 문자열을 그대로 비교하므로 펜스를 다듬거나 절을 옮기면 동작이 그대로여도 깨진다
- 겹침: plugins/quality-gates/tests/test_resolve_range.sh — resolve-range 의 rc · start · end 단언이 case_chain_agrees 와 겹침; plugins/quality-gates/tests/test_review_diff.sh — review-diff 범위 모드; plugins/quality-gates/tests/test_publish_pipeline_wiring.sh — 범위 모드 게시 거절
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — python 으로 펜스를 뽑는 호출을 한 번에 모아 재사용하고 mkfix 를 케이스마다 새로 세우지 않으면 지키는 것은 그대로 두고 싸진다
- 확신: 중간

### plugins/quality-gates/tests/test_readme_scope_reconcile.sh
- 초: 0.1
- 줄 수: 49
- 고친 횟수: 8
- 크기: 작음 — README 를 grep 하기만 함
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/quality-gates/README.md 에 옛 fan-out 게이트 문구(`len(phase1)` · `= 12` 등)가 없고 `## 리뷰어 구성` 표 행 · `리뷰어 상한 없이` 같은 문구가 있다
- 거짓 실패 위험: 높음 — README 문장을 다듬기만 해도 깨진다
- 겹침: plugins/quality-gates/tests/test_review_scope_composition.sh — README 에 최대 8 · max fan-out 이 없다는 부재와 시작 구성 문구가 겹침; plugins/quality-gates/tests/test_plain_readme.sh — README 문구
- 보안 갈래: 아니오
- 판정 후보: 지움 — 옛 시대(fan-out 게이트)의 부재 문구와 README 표 문구를 고정할 뿐이고, 지금 리뷰어 구성은 test_review_scope_composition.sh 가 SKILL 쪽에서 이미 잰다
- 확신: 높음

### plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
- 초: 0.1
- 줄 수: 65
- 고친 횟수: 7
- 크기: 작음 — README 를 grep 하기만 함
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/quality-gates/README.md 의 ASCII 파이프라인 도식에 `qg iter loop` · `② differential test` 등 표지 열 개가 있고 옛 두 게이트 도식 표지가 없다
- 거짓 실패 위험: 높음 — 도식 글자를 한 군데만 바꿔도 깨지고, 상대 경로를 쓰므로 레포 루트가 아닌 cwd 에서 부르면 깨진다
- 겹침: plugins/quality-gates/tests/test_plain_qg_templates.sh — README 상태도의 라벨 줄을 이미 잰다; plugins/quality-gates/tests/test_plain_readme.sh
- 보안 갈래: 아니오
- 판정 후보: 지움 — 도식 글자가 동작을 정하지 않고 라벨 일치는 test_plain_qg_templates.sh 가 이미 잰다
- 확신: 중간

### plugins/quality-gates/tests/test_recritic_code_profile.sh
- 초: 0.2
- 줄 수: 222
- 고친 횟수: 6
- 크기: 작음 — 프로필 한 파일을 awk 로 창을 잘라 고정 문자열로 확인 (헤더 주석이 약 80줄)
- 종류: 글자
- 지키는 것: 재비판자가 읽는 코드 프로필에 보안 판정 규칙(관문 A–E 순서 · diff 속 지시문은 데이터 · reject 는 근거 인용 필수 · raise 는 상향만 · lower 의 목적지는 SUGGESTION)이 그 문장 그대로 있어, 규칙이 약해지거나 뒤집히지 않는다.
- 거짓 실패 위험: 높음 — 규칙 문장을 다듬기만 해도 깨지지만 규칙 약화를 PR 에서 잡으려는 의도적 락이다
- 겹침: 못 찾음 — recritic-code-profile 을 읽는 다른 테스트는 harness/test_skill_orchestration_behavior.sh 의 grep 한 줄과 test_plain_field_path.sh 의 plain 문구 한 줄뿐
- 보안 갈래: 예
- 판정 후보: 둠 — 모델이 읽는 리뷰어 프로필의 보안 규칙을 지키는 글자 확인이라 뒤에서도 지우지 않기로 한 갈래이고 0.2초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_removed_plan_arg.sh
- 초: 0.1
- 줄 수: 31
- 고친 횟수: 3
- 크기: 중간 — 임시 git 레포 하나와 setup-qg.sh 를 두 번 실행
- 종류: 섞임(동작 5 · 구조 0 · 글자 2 · 변이 0)
- 지키는 것: 제거된 --plan 인자는 값을 쓰지 않고 한 줄 안내만 내며 종료 코드가 이미 제거된 --pr-url 과 같고, SKILL argument-hint 에 --plan 이 없다.
- 거짓 실패 위험: 낮음 — 인자 처리가 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_plain_synth_output.sh — setup 배너에 「계획 파일」이 없다는 단언이 일부 겹침; plugins/quality-gates/tests/test_setup_qg.sh 와의 겹침은 읽지 못함
- 보안 갈래: 아니오
- 판정 후보: 둠 — 제거된 호출 이름을 조용히 받지 않는 동작을 싸게 확인한다
- 확신: 중간

### plugins/quality-gates/tests/test_render_terminal.sh
- 초: 0.1
- 줄 수: 34
- 고친 횟수: 6
- 크기: 작음 — render-terminal.py 한 번 실행과 SKILL grep
- 종류: 섞임(동작 1 · 구조 0 · 글자 2 · 변이 0)
- 지키는 것: render-terminal.py table 이 값 열을 같은 위치로 정렬해 완료 표가 어긋나지 않고, SKILL 의 Final verdict 절이 그 table 하위 명령을 부른다.
- 거짓 실패 위험: 낮음 — 정렬 동작이 바뀌거나 호출이 사라질 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_publish_surface_removed.sh — render-terminal table 이 남아 있는지 `k   v` 출력으로 확인; plugins/quality-gates/tests/test_plain_qg_templates.sh — 완료 표 제목 호출 문구
- 보안 갈래: 아니오
- 판정 후보: 합침 — table 동작 확인은 test_publish_surface_removed.sh 의 같은 확인과 겹치므로 한 파일로 모을 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_resolve_baseline.sh
- 초: 4.1
- 줄 수: 355
- 고친 횟수: 7
- 크기: 중간 — 케이스마다 임시 git 레포(진짜 원격 · 얕은 클론 포함)를 약 25개 새로 만들고 스크립트를 실행
- 종류: 섞임(동작 약 30 · 구조 0 · 글자 2 · 변이 0)
- 지키는 것: 기준선을 origin/HEAD 하나로만 정하고 origin/main · 로컬 main 으로 대신하지 않으며, 같은 이름의 로컬 브랜치 · 태그가 원격 추적 커밋을 가로채거나 base ref 변조(same_as_head)가 floor 를 끄지 못하게 하고 degrade 사유를 키로 낸다.
- 거짓 실패 위험: 낮음 — 기준선 해석 동작이 바뀔 때만 깨진다(안내 줄 문구는 한 줄 등호 비교)
- 겹침: plugins/quality-gates/tests/test_check_review_scope.sh — check-review-scope 출력 계약(case_review_scope_contract · same_as_head 가 겹침); plugins/quality-gates/tests/test_compute_test_scope_candidates.sh — --total; 같은 파일 안에서 detached 상태를 case_detached · case_reasons · case_degraded_emits_all_keys 가 되풀이
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 변조 · 가로채기 방어는 그대로 두고 레포 세우기를 템플릿 복사로, 같은 detached 케이스는 하나로 줄일 여지가 있다
- 확신: 중간

### plugins/quality-gates/tests/test_resolve_range.sh
- 초: 4.0
- 줄 수: 236
- 고친 횟수: 2
- 크기: 중간 — 케이스마다 레포 + 곁가지 + 클론 + fetch(mkfix)를 새로 세우고(약 13회) resolve-range.sh 를 매번 실행
- 종류: 동작
- 지키는 것: range 인자를 시작 · 끝 커밋 둘로 얼리고(끝 생략은 origin/HEAD, 짧은 id · ref 이름 해석) 나쁜 입력은 rc 3 과 사유로 거부하며, 얼린 끝이 fetch 뒤에도 유지되고 create-head --range 가 불일치를 거부한다.
- 거짓 실패 위험: 낮음 — 범위 해석 동작이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_range_wiring.sh — case_chain_agrees 가 같은 start · end · end_from 단언을 되풀이; plugins/quality-gates/tests/test_review_diff.sh — 범위 모드 diff
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 읽기 전용 케이스(대부분)는 mkfix 한 벌을 함께 쓰고 레포를 바꾸는 케이스(no_origin_head · head_is_end · frozen_end)만 따로 세우면 싸진다
- 확신: 중간

### plugins/quality-gates/tests/test_review_scope_composition.sh
- 초: 1.1
- 줄 수: 237
- 고친 횟수: 15
- 크기: 중간 — SKILL 절 창 grep 이 대부분이고 scope-empty · 기록 펜스를 실제로 실행(임시 git 레포 하나와 verdict.py 실행 여러 번)
- 종류: 섞임(동작 약 20 · 구조 약 10 · 글자 약 60 · 변이 0)
- 지키는 것: 리뷰어 구성 표 · 시작/끝 공시 줄이 SKILL 에 있고, 걸러진 diff 가 빈 실행이 실제로 not-certified (scope-empty) 판정 줄을 내며, 파일 이름에 개행을 심어 문서 경로 요약 줄을 위조해도 result.md 에 진짜 값만 남는다.
- 거짓 실패 위험: 높음 — 구성 표 행 · 공시 줄 · 규칙 문장을 줄 전체로 등호 비교하므로 문구 변경에 깨진다(README 이유 줄은 스크립트에서 도출해 좋은 예)
- 겹침: plugins/quality-gates/tests/test_readme_scope_reconcile.sh — README 상한 8 부재 · 시작 구성; plugins/quality-gates/tests/test_review_diff.sh — review-diff 이유 줄; plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh — --reason scope-empty 리터럴
- 보안 갈래: 예
- 판정 후보: 줄임 — 위조 방어와 scope-empty 펜스 실행은 유지하고 구성 표 행 · 공시 줄 문구를 하나씩 고정한 글자 단언은 덜어도 지키는 것이 그대로다
- 확신: 낮음

### plugins/quality-gates/tests/test_runtime_contract_invariance.sh
- 초: 1.7
- 줄 수: 262
- 고친 횟수: 29
- 크기: 중간 — 케이스마다 임시 git 레포를 세우고 create-baseline · seal · create-head · remove 를 실행(6 케이스) + SKILL 재구성
- 종류: 섞임(동작 약 20 · 구조 3 · 글자 8 · 변이 0)
- 지키는 것: create-head 가 지금 뜬 봉인 커밋이 아닌 값(merge_base · 오래된 봉인 · 커밋 아님)을 거부해 HEAD 축 트리가 기준선 복사본이 되어 차등 테스트가 거짓 통과하지 않게 하고, 두 축 트리가 서로 다른 경로로 공존하며 기준선 재실행이 막히지 않는다.
- 거짓 실패 위험: 중간 — 훅 없음 · 에이전트 파일 수 5 · verdict 토큰 0종 같은 숫자 · 부재 락은 의도적 변경 때마다 같은 커밋에서 고쳐야 깨진다
- 겹침: plugins/quality-gates/tests/test_qg_worktree_helper.sh — create-baseline · remove 이름 공간 밖 거부(case_remove_namespace_guard 와 `[remove]` 섹션이 같음); plugins/quality-gates/tests/test_seal_no_side_effects.sh — 봉인; agents 5 개수 락은 test_agent_tools_lock_* 계열과 겹칠 공산(확인 못 함)
- 보안 갈래: 예
- 판정 후보: 줄임 — 이름 공간 거부와 숫자 · verdict 토큰 부재 락은 다른 테스트가 지키거나 글자성이라 덜고 create-head 봉인 대조 · 공존 확인은 남긴다
- 확신: 중간

### plugins/quality-gates/tests/test_sandbox_enforced.sh
- 초: 1.9
- 줄 수: 162
- 고친 횟수: 5
- 크기: 중간 — codex 호출부마다 러너 스크립트를 가짜 codex 로 실행해 argv 를 관측(6곳 안팎) + python 수집기 한 번
- 종류: 섞임(동작 약 8 · 구조 3 · 글자 7 · 변이 0)
- 지키는 것: codex 를 부르는 모든 러너가 실제 실행된 argv 에 `-s read-only` 를 싣고 값이 변수가 아니라 리터럴이어서 사용자 작업 트리가 샌드박스 없이 codex 에 노출되지 않는다.
- 거짓 실패 위험: 낮음 — 새 codex 호출부가 표에 없거나 샌드박스 값을 인자화할 때만 깨진다(옳은 경계)
- 겹침: plugins/quality-gates/tests/test_codex_invocation_contract.sh · test_codex_gate_observation.sh — 같은 lib/codex_observation.sh 를 쓸 공산이나 내용은 확인 못 함
- 보안 갈래: 예
- 판정 후보: 둠 — Law 2 codex 격리의 유일한 기둥을 실행된 argv 로 확인하고 1.9초로 비용이 맞다
- 확신: 높음

### plugins/quality-gates/tests/test_scope_tuple.sh
- 초: 1.9
- 줄 수: 199
- 고친 횟수: 4
- 크기: 중간 — 케이스마다 임시 폴더에 합성기 fixture(rf_prep · rf_reply · rf_synth)를 새로 세우고 합성기를 약 35번 실행
- 종류: 동작
- 지키는 것: 합성기 --scope 가 합치기 충돌 · 선언 오류를 not-certified 사유로 내고 확증 결함이 스코프 미판정보다 우선하며, 모양이 깨진 스코프 파일(U+2028 · 개수 불일치 · in_base 형식)은 exit 4 로 stdout 없이 원자적으로 실패한다.
- 거짓 실패 위험: 낮음 — 스코프 판정 · 형식 검증 동작이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh · test_angle_coverage.sh — 같은 합성기 판정 계열(본문은 읽지 못함); plugins/quality-gates/tests/test_topic_head.sh — 스코프 파일 생산자 쪽
- 보안 갈래: 아니오
- 판정 후보: 둠 — 판정 입력의 형식 검증이 조용히 clean 으로 새지 않는지 동작으로 확인한다
- 확신: 중간

### plugins/quality-gates/tests/test_seal_no_side_effects.sh
- 초: 2.1
- 줄 수: 260
- 고친 횟수: 7
- 크기: 중간 — 케이스마다 임시 git 레포(12개)를 새로 세우고 worktree add · bash -x 로 seal-worktree.sh 를 실행
- 종류: 동작
- 지키는 것: 봉인이 미커밋 수정 · 삭제 · 추적 안 된 파일을 담고 qg 네임스페이스 · 이 세션의 일회용 사본 · 임시 인덱스는 담지 않으며 HEAD · 인덱스 · 워킹트리 · worktree 목록은 그대로 두고, 인덱스가 워킹트리에서 닿으면 exit 2 로 죽는다.
- 거짓 실패 위험: 낮음 — 봉인 내용 · 제외 동작이 바뀔 때만 깨진다(읽기 불가 파일 케이스는 root 실행 시 약해질 수 있다)
- 겹침: plugins/quality-gates/tests/test_qg_objects_unreachable.sh — 봉인 커밋의 도달 불가; 같은 파일 안에서 case_no_index_in_tree(헤더가 지금은 늘 참이라 밝힘)와 case_index_file_cleaned_up · case_authoritative_guard 가 임시 인덱스 부재를 되풀이
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 「.gitignore 없는 평범한 레포」를 여러 케이스가 각자 세우므로 한 벌을 함께 쓰고, 늘 참인 case_no_index_in_tree 는 줄일 수 있다
- 확신: 중간

### plugins/quality-gates/tests/test_secret_scan.py
- 초: 0.2
- 줄 수: 94
- 고친 횟수: 4
- 크기: 중간 — 테스트마다 임시 폴더와 secret-scan.py 를 python 하위 프로세스로 실행(7개)
- 종류: 동작
- 지키는 것: secret-scan.py 가 진짜 비밀(GitHub 토큰 · AWS 키 · 고엔트로피 값 · 비 http 연결 문자열의 자격 증명)을 막고 식별자 · 경로는 통과시키며, 읽을 수 없거나 코퍼스가 degraded 이면 fail-closed 로 막는다.
- 거짓 실패 위험: 낮음 — 스캐너 탐지 동작이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_secret_scan_fp.py — 같은 스크립트의 반대 방향(오탐) 짝; plugins/quality-gates/tests/test_publish_comment_sink.sh — sink 가 스캐너를 부르는 쪽(본문은 읽지 못함)
- 보안 갈래: 예
- 판정 후보: 둠 — 비밀 값 유출을 막는 이빨을 진짜 비밀 픽스처로 확인하고 0.2초로 싸다
- 확신: 높음

### plugins/quality-gates/tests/test_secret_scan_fp.py
- 초: 0.1
- 줄 수: 71
- 고친 횟수: 2
- 크기: 중간 — 테스트마다 임시 폴더와 secret-scan.py 를 하위 프로세스로 실행(5개 중 4)
- 종류: 동작
- 지키는 것: secret-scan.py 가 `token: RequestHandler` 같은 낮은 엔트로피 타입 이름 · 함수 · 경로를 비밀로 오인해 막지 않아 정상 코멘트의 게시가 막히지 않는다(value_shaped 게이트가 일을 한다).
- 거짓 실패 위험: 낮음 — 값 모양 판정이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_secret_scan.py — run · scan_ok · blocked 헬퍼가 같고 test_real_value_still_blocks 가 test_github_token_blocks 를 되풀이한다
- 보안 갈래: 예
- 판정 후보: 합침 — 같은 스크립트 · 같은 헬퍼를 쓰는 오탐 케이스를 test_secret_scan.py 한 파일로 모을 수 있다
- 확신: 높음

### plugins/quality-gates/tests/test_security_reviewer_behavior.py
- 초: 0.0
- 줄 수: 84
- 고친 횟수: 4
- 크기: 작음 — 프로세스 안에서 파일 읽기와 스텁 호출만 함
- 종류: 섞임(동작 0 · 구조 3 · 글자 0 · 변이 0) — 나머지 2개는 스텁 자체를 재는 항등 확인
- 지키는 것: security-reviewer 페르소나의 `## Output format` yaml 블록과 기대 스키마 픽스처의 키 집합이 정해진 finding 키(confidence 없음)와 같아 산출 형식이 갈라지지 않는다. 고정 문자열을 agent_stub 에 넣고 스키마를 검사하는 나머지 세 확인은 리뷰어가 아니라 스텁을 잰다.
- 거짓 실패 위험: 낮음 — 페르소나 출력 형식 키가 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_agent_stub_harness.py — 스텁 자체; plugins/quality-gates/tests/test_security_reviewer_persona.sh — confidence 부재 · 스키마 키 존재(같은 persona 파일)
- 보안 갈래: 예
- 판정 후보: 줄임 — 스텁에 고정 문자열을 넣어 재는 AC45 · AC46 · AC47 은 리뷰어가 아니라 스텁을 재므로 덜고 페르소나 · 픽스처 키 집합 확인 둘만 남긴다
- 확신: 높음

### plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
- 초: 0.1
- 줄 수: 135
- 고친 횟수: 9
- 크기: 작음 — SKILL.md 를 awk/grep 으로 읽고 dispatch 마다 창을 도출
- 종류: 섞임(동작 0 · 구조 약 8 · 글자 약 8 · 변이 0)
- 지키는 것: SKILL 의 모든 security-reviewer dispatch 바로 위에 kill switch 게이트(env 이름 · IF 조건 · 배너 원문 · 발행하지 않는다 지시)가 서 있어, 끄는 스위치가 dispatch 지점을 지배한다(모델이 따르는지는 재지 못한다고 헤더가 밝힌다).
- 거짓 실패 위험: 중간 — 창을 구조에서 도출하므로 줄번호 이동에는 강하지만 배너 · 조건 문구를 바꾸면 깨진다. `git rev-parse --show-toplevel` 에 의존해 레포 밖 cwd 에서 깨진다
- 겹침: plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh — case_security_kill_switch_routes_to_absent 가 같은 env 를 각도 표 · IF item4 에서 잰다(다른 앵커); shared/tests/test_switch_tables.sh — 스위치 표
- 보안 갈래: 예
- 판정 후보: 둠 — 끄는 스위치가 dispatch 앞에 서 있는지를 구조에서 도출한 창으로 확인하는 보안 락이고 0.1초로 싸다
- 확신: 중간

### plugins/quality-gates/tests/test_security_reviewer_persona.sh
- 초: 0.2
- 줄 수: 148
- 고친 횟수: 18
- 크기: 작음 — security-reviewer.md 한 파일과 SKILL 한 줄을 awk/grep 으로 읽기만 함
- 종류: 섞임(동작 0 · 구조 약 20 · 글자 약 45 · 변이 0)
- 지키는 것: security-reviewer 페르소나가 도구를 Read · Grep · Glob 로만 한정(쓰기 · 실행 · 웹 도구 없음)하고 diff · intent 의 지시문을 데이터로만 읽으며 Severity · 사냥 규칙(변경이 낳은 결함만 막는 지적 · 커밋된 비밀은 CRITICAL · 자원 고갈)이 그 문장 그대로 있어 약화되지 않는다.
- 거짓 실패 위험: 높음 — 단락을 줄 전체 등호(assert_line)로 비교하므로 한 단어만 다듬어도 깨지지만 페르소나 약화를 잡으려는 의도적 락이다
- 겹침: plugins/quality-gates/tests/test_agent_tools_lock_mutation.sh · test_agent_tools_lock_differential.sh — 에이전트 tools 락(본문은 읽지 못함); 같은 파일 안에서 tools 줄을 세 번 재고 Severity 단락마다 부분 문자열 단언(assert_fixed)과 줄 전체 단언(assert_line)이 같은 문장을 되풀이한다
- 보안 갈래: 예
- 판정 후보: 줄임 — assert_line 으로 줄 전체를 잠근 Severity · 비밀 · 자원 고갈 단락 앞의 부분 문자열 단언은 줄 전체 락이 포함하므로 덜어도 지키는 것이 그대로다(리뷰어 프로필 락 자체는 유지)
- 확신: 중간

#### 읽지 못한 것 — shallow-04

없음 — 32개 단위의 테스트 파일은 모두 끝까지 읽었다. 단 「겹침」 칸에서 test_check_review_scope.sh · test_setup_qg.sh · test_verdict_vocabulary.sh · test_agent_tools_lock_*.sh · test_codex_invocation_contract.sh · test_publish_comment_sink.sh · shared/gc 의 spec-distill 쪽 테스트 같은 짝 후보는 이름과 grep 결과로만 언급했고 본문은 열지 않았다(「확인 못 함」 또는 「본문은 읽지 못함」으로 표시). 「시간을 쓰는 곳」 성격의 초 추정(레포 세우기 반복 등)은 읽어서 한 추정이며 실행하지 않았다.

## 묶음 shallow-05

### plugins/quality-gates/tests/test_setup_qg.sh
- 초: 4.9
- 줄 수: 231
- 고친 횟수: 21
- 크기: 중간 — setup-qg.sh 를 케이스마다 임시 폴더에서 약 60번 실행하고, sleep 1 · 0.5 · 폴링 0.1 × 최대 20, 백그라운드 python 프로세스 하나를 띄운다
- 종류: 섞임(동작 약 90 · 구조 0 · 글자 10 · 변이 0)
- 지키는 것: setup-qg.sh 가 세션 폴더와 result.md 를 한 번만 만들고, 없어진 인자와 제거된 인자를 안내하며 실행하지 않고, 같은 세션의 남은 e2e 앱을 내리지 못하면 사유를 알리지 못하는 일이 없게 한다.
- 거짓 실패 위험: 중간 — 안내 문구(「인자는 제거됐다」 · 「모르는 인자」)를 다듬으면 깨지고, 부하가 크면 sleep 0.5 뒤 프로세스 종료 확인이 흔들린다
- 겹침: plugins/quality-gates/tests/test_worktree.sh — 세션 폴더 생성 확인이 겹친다 / test_removed_plan_arg.sh · test_entry_safety_e1_e6.sh · test_precheck_retired.sh — 같은 스크립트의 인자 처리를 따로 잰다(내용 겹침 정도는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 멱등 확인의 sleep 1 은 mtime 을 과거로 돌려 놓고 비교하면 없어지고, 같은 모양의 인자 케이스가 많아 한 번에 돌려도 지키는 것이 그대로다
- 확신: 중간

### plugins/quality-gates/tests/test_skill_bash_allowlist_narrow.sh
- 초: 0.1
- 줄 수: 19
- 고친 횟수: 1
- 크기: 작음 — SKILL.md 를 grep 두 번(경로가 cwd 기준 상대경로라 레포 루트에서만 돈다)
- 종류: 글자
- 지키는 것: quality-pipeline SKILL 의 frontmatter 에 모든 Bash 를 미리 허용하는 `Bash(*)` 가 들어와 권한이 넓어지는 일을 막는다(둘째 확인인 run_codex_reviewer.sh 언급은 글자만 지킴 — SKILL.md 의 그 파일 이름).
- 거짓 실패 위험: 낮음 — `Bash(*)` 가 새로 생길 때만 깨진다. 단 run_codex_reviewer.sh 이름을 바꾸면 깨진다
- 겹침: 못 찾음(run_codex_reviewer.sh 이름은 test_worktree.sh · test_v_requirements.sh 등이 다른 용도로 쓴다)
- 보안 갈래: 예
- 판정 후보: 둠 — 권한 미리 허용 범위를 지키는 싼 확인이다(CLAUDE.md 가 allowed-tools 는 제한이 아니라고 하므로 첫 확인의 실효는 작다)
- 확신: 중간

### plugins/quality-gates/tests/test_skill_codex_skip_prose.sh
- 초: 0.1
- 줄 수: 54
- 고친 횟수: 2
- 크기: 작음 — SKILL.md grep 만
- 종류: 글자
- 지키는 것: 글자만 지킴 — quality-pipeline SKILL.md 의 「Codex CLI not installed」 · 「auth missing」 · 「version_below_floor」 같은 사유 문구와 「Codex skip 안내」 헤더
- 거짓 실패 위험: 높음 — 문구를 다듬거나 사유 이름을 바꾸면 깨진다. 침묵 사유 확인의 `[^\n]` 는 ERE 에서 개행이 아니라 글자 `n` 을 뺀다는 뜻이라 음의 확인이 의도대로 걸리는지 의심스럽다
- 겹침: plugins/quality-gates/tests/test_codex_result_banner.sh · test_codex_gate_observation.sh · test_detect_codex.sh — codex 건너뜀 사유와 공시를 따로 잰다(겹치는 정도는 읽지 않음)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 문구 존재만 확인하고 동작을 정하는 것은 아래 배너 · 관찰 테스트가 잰다
- 확신: 낮음

### plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh
- 초: 0.3
- 줄 수: 170
- 고친 횟수: 11
- 크기: 중간 — 합성기를 python 으로 네 번 돌리고 임시 폴더를 쓴다
- 종류: 섞임(동작 약 40 · 구조 0 · 글자 60 · 변이 0)
- 지키는 것: 합성기가 내는 「dropped as malformed」 · 「이 실행은 clean이 아니다」 공지를 SKILL step 4.5 가 실제로 그대로 보이라고 지시해, 버려진 CRITICAL 위에 clean 이 찍히지 않게 한다(생산자와 소비자가 같은 문구인지).
- 거짓 실패 위험: 중간 — step 4.5 의 awk 앵커 문구와 마커 바이트가 바뀌면 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_promoted_findings.sh — 10 · 10b 가 같은 drop 공지를 생산자 쪽에서 잰다 / test_v_requirements.sh — V3 이 같은 공지 줄을 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 생산자와 소비자의 이음매를 한 락에서 재는 것은 다른 둘이 못 한다
- 확신: 중간

### plugins/quality-gates/tests/test_skill_orchestration.sh
- 초: 0.1
- 줄 수: 61
- 고친 횟수: 11
- 크기: 작음 — SKILL.md grep · awk 만
- 종류: 글자
- 지키는 것: 글자만 지킴 — quality-pipeline SKILL.md 의 「qg 반복 N: <ask-line>」 질문 줄이 모드마다 정확히 하나라는 것과 「고치고 다시 돌기」 · 「지금 판정으로 끝내기」 선택지 이름
- 거짓 실패 위험: 높음 — 질문 문구나 선택지 이름을 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh — 같은 SKILL 의 오케스트레이션 모양을 잰다(헤더가 직접 그쪽으로 넘겼다)
- 보안 갈래: 아니오
- 판정 후보: 합침 — 헤더가 이미 뼈대 확인을 harness 쪽으로 넘겼으므로 질문 줄 유일성은 그쪽으로 모은다
- 확신: 낮음

### plugins/quality-gates/tests/test_skill_run_contract.sh
- 초: 1.6
- 줄 수: 221
- 고친 횟수: 16
- 크기: 중간 — SKILL 의 bash 펜스를 뽑아 임시 git 레포에서 약 15번 실제로 돌리고 python 으로 펜스를 채운다
- 종류: 섞임(동작 약 65 · 구조 0 · 글자 35 · 변이 0)
- 지키는 것: 파이프라인 SKILL 의 P2 · P3 · Final verdict 펜스가 끝난 앞 실행 파일을 지우고, git 밖에서는 멈추며, 결과 줄이 비었거나 모양이 틀리면 판정 줄을 만들지 않는 것을 실제 실행으로 지킨다.
- 거짓 실패 위험: 중간 — 펜스 추출 앵커(`**P2 — setup.**` 등)와 문장 전체 핀이 많아 문구를 다듬어도 깨진다
- 겹침: plugins/quality-gates/tests/test_v_requirements.sh — case_ac25 가 같은 방식으로 SKILL 펜스를 뽑아 돌린다(다른 펜스) / test_pipeline_verdict_wiring.sh — 판정 줄 배선(겹침 정도는 읽지 않음)
- 보안 갈래: 아니오
- 판정 후보: 둠 — SKILL 에 박힌 셸을 실제로 도는 몇 안 되는 자리이고 1.6초는 그에 맞다
- 확신: 중간

### plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py
- 초: 0.0
- 줄 수: 87
- 고친 횟수: 2
- 크기: 작음 — 한 프로세스 안에서 함수를 직접 부른다
- 종류: 동작
- 지키는 것: 산출물 합성기가 판정을 못 받은 지적을 보여주지 않되 수렴을 막고(converged False · unadjudicated 1), 원장이 그것을 held 로 센다.
- 거짓 실패 위험: 낮음 — 합성기의 원장 배선이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_artifact_findings.sh — 79-94행 「un-adjudicated fail-closed」 와 103-115행이 CLI 로 같은 확인을 한다 / test_synthesize_findings_adjudication.py — 원장 hold 계수
- 보안 갈래: 아니오
- 판정 후보: 합침 — 같은 unadjudicated 계약을 CLI 락이 이미 재므로 한쪽으로 모을 수 있다(0.0초라 비용 이득은 작다)
- 확신: 중간

### plugins/quality-gates/tests/test_synthesize_artifact_findings.sh
- 초: 1.9
- 줄 수: 448
- 고친 횟수: 17
- 크기: 중간 — 합성기를 python 으로 약 35번, yaml 을 다시 읽는 `python3 -c` 확인을 약 15번 띄운다
- 종류: 섞임(동작 약 95 · 구조 0 · 글자 5 · 변이 0)
- 지키는 것: 산출물 critique 합성기가 입력 소스 실패 · 빈 병합 파일 · 형식이 깨진 판정 · 알 수 없는 severity 에서 가짜 수렴(converged true)을 내지 않고, 중복에서 가장 엄한 severity 를 남기고, 처분 회계를 사람이 읽는 줄로 낸다.
- 거짓 실패 위험: 낮음 — 합성기 동작이 바뀔 때만 깨진다(처분 줄 확인 몇 곳은 한국어 라벨에 기댄다)
- 겹침: plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py — unadjudicated 계약이 겹친다 / test_critiquing_artifacts_skill.sh · test_plain_field_path.sh — 같은 스크립트를 다른 면에서 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 실패를 clean 으로 읽지 않는 핵심 게이트를 직접 돌려 재고 비용은 1.9초다
- 확신: 중간

### plugins/quality-gates/tests/test_synthesize_ask_line.sh
- 초: 1.9
- 줄 수: 172
- 고친 횟수: 2
- 크기: 중간 — rf_prep · rf_synth 로 합성기를 약 30번 python 으로 띄운다
- 종류: 동작
- 지키는 것: 수정 루프 질문에 뜨는 한 줄(막는 지적 수 · 제안 수 · 가장 무거운 지적 · 80자 자르기 · degrade 경고 수 · 「확정하지 못했다」)이 사람이 읽을 때 틀리지 않게 한다.
- 거짓 실패 위험: 중간 — 줄 문구 전체를 글자 그대로 비교해 표현을 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_findings.sh — 표 · blocking 줄 확인이 일부 겹친다 / test_plain_synth_output.sh(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 사용자가 결정에 쓰는 줄의 모든 갈래를 fixture 로 재며 200자 케이스가 81자 갈래와 겹치는 정도의 되풀이뿐이다
- 확신: 중간

### plugins/quality-gates/tests/test_synthesize_disposition.sh
- 초: 0.9
- 줄 수: 290
- 고친 횟수: 16
- 크기: 중간 — 합성기를 약 8번 python 으로 돌리고 임시 폴더를 쓴다
- 종류: 동작
- 지키는 것: 합성기 출력의 처분 줄(수용 · 기각 · 흡수 · 미판정 · 배관 손실)이 clean 인 갈래에서도 값으로 실리고, 「실행 차단」 표기가 실제 차단 여부(막는 사건 vs 공시만 하는 degrade)를 따른다.
- 거짓 실패 위험: 중간 — 라벨 문구(「미판정은 차단」 · 「실행 차단: 예」)와 풀이 줄을 그대로 비교한다
- 겹침: plugins/quality-gates/tests/test_synthesize_artifact_findings.sh — 같은 회계를 key 단계에서 재지만 다른 스크립트다 / test_synthesize_recritic.sh — 재비판 경로(겹침 정도는 읽지 않음)
- 보안 갈래: 아니오
- 판정 후보: 둠 — clean 위에서 입력 실패가 사라지는 가장 위험한 자리를 지키고 케이스마다 다른 분기를 탄다
- 확신: 높음

### plugins/quality-gates/tests/test_synthesize_findings.sh
- 초: 2.0
- 줄 수: 210
- 고친 횟수: 10
- 크기: 중간 — 합성기와 verdict.py 를 약 25번 python 으로 띄우고 케이스마다 임시 폴더를 만든다
- 종류: 동작
- 지키는 것: 합성기의 표(심각도 · 위치 · 내용 · 낸 곳), 같은 좌표 중복 병합, 기각 · 낮은 confidence 처리, blocking · optional 개수, 판정(clean · defect · not-certified), 판정 인자 줄이 정해진 대로 나온다.
- 거짓 실패 위험: 낮음 — 합성기 출력이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh — case_synth_ac4 · ac5 · lost_findings 가 같은 AC4 · AC5 · V3 확인이다 / test_v_requirements.sh — V2 · V3 · V8 이 같다 / test_synthesize_findings_adjudication.py — V8
- 보안 갈래: 아니오
- 판정 후보: 줄임 — AC4 · AC5 · V2 · V3 · V8 이 세 파일에서 되풀이되고 케이스마다 fixture 를 새로 만든다
- 확신: 중간

### plugins/quality-gates/tests/test_synthesize_findings_adjudication.py
- 초: 0.0
- 줄 수: 302
- 고친 횟수: 13
- 크기: 작음 — 한 프로세스 안에서 main() 과 함수를 직접 부른다
- 종류: 동작
- 지키는 것: 입력 파일이 없는 것과 경로가 없는 것을 구별하고, 판정 없는 지적을 세며, severity 결측 · 대소문자 차이 · raise 가드에서 낙관값(가짜 clean)을 내지 않고, 주 입력이 죽으면 출력이 clean 과 같지 않게 한다.
- 거짓 실패 위험: 낮음 — 합성기 내부 함수 이름과 동작이 바뀔 때 깨진다
- 겹침: plugins/quality-gates/tests/test_synthesize_findings.sh · test_v_requirements.sh — V8 severity 결측이 CLI 로 한 번 더 있다 / test_synthesize_promoted_findings.sh — malformed 컨테이너
- 보안 갈래: 아니오
- 판정 후보: 둠 — 프로세스 안에서 도는 가장 싼 락이고 CLI 에서 닿지 않는 방어를 직접 핀한다
- 확신: 높음

### plugins/quality-gates/tests/test_synthesize_lowered.py
- 초: 0.0
- 줄 수: 254
- 고친 횟수: 1
- 크기: 작음 — main() 을 한 프로세스 안에서 반복 호출한다
- 종류: 동작
- 지키는 것: 재비판이 낮춘 지적이 이유와 함께 「낮춘 지적」 표로 보이고, `--restore-lowered` 로 되올리면 막는 지적 수와 판정이 바뀌고, 잘못된 번호는 exit 2 로 멈춘다.
- 거짓 실패 위험: 중간 — 표 머리와 절 위치를 글자 그대로 비교한다
- 겹침: plugins/quality-gates/tests/test_lowered_gate_wiring.sh — SKILL 쪽 배선을 따로 잰다(합성기 출력 확인은 겹치지 않음)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 사용자가 판정을 되돌리는 게이트의 출력 계약을 싸게 지킨다
- 확신: 높음

### plugins/quality-gates/tests/test_synthesize_promoted_findings.sh
- 초: 0.8
- 줄 수: 375
- 고친 횟수: 15
- 크기: 중간 — 합성기를 약 14번 python 으로 돌리고 케이스마다 fixture 를 쓴다
- 종류: 섞임(동작 약 90 · 구조 0 · 글자 10 · 변이 0)
- 지키는 것: 재비판이 더한 지적이 표에 낸 곳 code-recritic 으로 나오고, 같은 줄의 다른 결함이 합쳐져 사라지거나 다른 리뷰어 보증을 위조하지 못하고, 깨진 항목 · 이상한 값(비수치 confidence · 리스트 severity · 해시 불가 file)이 합성을 죽이거나 clean 으로 읽히지 않게 한다.
- 거짓 실패 위험: 중간 — 표 행 정규식과 「N개 지적을 버렸다」 문구를 그대로 비교한다
- 겹침: plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh — a1 · a2 가 케이스 10 · 10b 와 같은 공지를 잰다 / test_synthesize_findings_adjudication.py — promote 규칙과 컨테이너 검사 / 10c · 13 · 15 는 주석만 남은 옛 케이스다
- 보안 갈래: 예
- 판정 후보: 줄임 — 10 · 10b 가 drop_notice 락과 되풀이되고 주석만 남은 세 케이스(10c · 13 · 15)는 확인이 없으며 낸 곳 위조(10e)는 유지한다
- 확신: 중간

### plugins/quality-gates/tests/test_topic_scope_wiring.sh
- 초: 0.3
- 줄 수: 304
- 고친 횟수: 23
- 크기: 작음 — SKILL.md · 레퍼런스를 읽고 python 6번 · awk 로 문장을 뽑는다
- 종류: 섞임(동작 0 · 구조 약 20 · 글자 80 · 변이 0)
- 지키는 것: SKILL 이 스코프 파일을 리포 루트 경로에 쓰고 review-diff 에 넘기며, 상태 표가 scope_tuple.STATUSES 전부를 받고, 선언이 깨진 토픽에서 trivia 우회를 쓰지 않는다는 지시가 SKILL 에 있다(스크립트 산출물을 산문이 실제로 흘리는지).
- 거짓 실패 위험: 높음 — 문장 전체를 글자 그대로 핀하고(공지 문장 전체 · 한 줄 정확 일치) 앵커 마커가 바뀌면 깨진다
- 겹침: plugins/quality-gates/tests/test_topic_head.sh · test_review_diff.sh — 스크립트 쪽 동작은 그쪽이 잰다(이름만 확인, 내용은 읽지 않음)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 경로와 의무(--scope-file 을 넘긴다)는 지키되 공지 문장 전체 · 부정 토큰 열거 같은 문장 핀은 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/quality-gates/tests/test_utf8_explicit.py
- 초: 0.2
- 줄 수: 219
- 고친 횟수: 8
- 크기: 중간 — 모든 플러그인의 hooks · scripts 파이썬을 정규식으로 훑고 python 서브프로세스를 4번 띄운다
- 종류: 섞임(동작 약 40 · 구조 0 · 글자 60 · 변이 0)
- 지키는 것: 모든 플러그인의 production 코드가 encoding 없는 read_text · write_text · open 을 쓰지 않아, UTF-8 이 아닌 로케일에서 한국어 파일을 읽다 죽지 않고 verdict.py 가 한국어 차등 산출물을 읽는다.
- 거짓 실패 위험: 낮음 — 새 스크립트가 encoding 을 빼먹을 때만 깨진다(예외 목록이 줄 번호 하나에 고정돼 그 줄이 움직이면 깨진다)
- 겹침: plugins/project-init/tests/test_post_tool_use.py — non-UTF-8 로케일 패턴을 같은 방식으로 쓴다(내용은 다른 대상)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 새 코드가 들어올 때마다 걸리는 값싼 스윕이고 로케일 변이를 실제로 재는 양성 확인을 함께 가진다
- 확신: 높음

### plugins/quality-gates/tests/test_v1_verdict_line.sh
- 초: 1.5
- 줄 수: 143
- 고친 횟수: 4
- 크기: 중간 — verdict.py 를 약 60번 python 으로 띄운다(차등 산출물 이상 케이스 하나당 두세 번)
- 종류: 동작
- 지키는 것: verdict.py 가 판정 줄을 정해진 형식으로 만들고, 값이 비었거나 음수 · 개행으로 둘째 판정 줄을 심는 입력은 줄을 만들지 않고 exit 4 · 2 로 끝나며, 인자 줄이 따옴표 없이 쓸 수 있는 낱말만 낸다.
- 거짓 실패 위험: 낮음 — verdict.py 동작이 바뀔 때만 깨진다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh · test_v_requirements.sh — 비정수 exit 4 · 판정 줄 형식이 일부 겹친다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 이상 입력 11개 파일마다 같은 스크립트를 rc · stdout · stderr 로 세 번 띄우므로 한 번 실행에 셋을 함께 잡으면 지키는 것이 같다
- 확신: 중간

### plugins/quality-gates/tests/test_v_requirements.sh
- 초: 1.0
- 줄 수: 262
- 고친 횟수: 8
- 크기: 중간 — 합성기 · verdict.py · run_codex_reviewer.sh 를 돌리고 임시 git 레포와 python 펜스 채우기를 쓴다
- 종류: 섞임(동작 약 60 · 구조 0 · 글자 40 · 변이 0)
- 지키는 것: 요구 V1–V12 와 AC7 · AC9 · AC25 를 번호로 모아 재서, 판정 어휘 · 합성 실패 · 파손 지적이 clean 이 되지 않고, 재시도 경로가 project_dir 안에 갇히며, 상한에서 연 반복 기록 펜스가 원문을 실행하지 않고 한 줄로 남긴다.
- 거짓 실패 위험: 중간 — SKILL 절 제목 · 문장 정규식 핀이 많아 문구를 다듬으면 깨진다
- 겹침: plugins/quality-gates/tests/test_verdict_vocabulary.sh · test_synthesize_findings.sh · test_synthesize_promoted_findings.sh — V1 · V2 · V3 · V8 이 같은 확인을 되풀이한다 / test_skill_run_contract.sh — SKILL 펜스를 뽑아 돌리는 방식이 같다
- 보안 갈래: 예
- 판정 후보: 줄임 — 헤더가 스스로 「색인이자 그물」 이라 하는 V1–V8 중복 케이스는 덜고, 경로 가두기(V9) · 신원 문법(V11) · AC25 펜스 실행은 유지한다
- 확신: 중간

### plugins/quality-gates/tests/test_verdict_vocabulary.sh
- 초: 2.0
- 줄 수: 582
- 고친 횟수: 18
- 크기: 중간 — verdict.py 를 약 75번, 합성기를 약 12번 python 으로 띄운다(열거를 얻으려 `python3 -c` import 도 여러 번)
- 종류: 섞임(동작 약 88 · 구조 0 · 글자 12 · 변이 0)
- 지키는 것: 판정값은 clean · defect · not-certified 셋뿐이고 not-certified 는 사유 없이 존재할 수 없으며, 사유 열거 열두 값이 모두 산출자에 귀속되고, 읽을 수 없는 차등 산출물은 clean 으로 새지 않고 exit 4 로 원자적으로 끝난다.
- 거짓 실패 위험: 중간 — 사유 열거 크기(N:12)와 decide() 파라미터 집합을 정확히 핀해 사유를 더할 때마다 이 파일도 고쳐야 한다
- 겹침: plugins/quality-gates/tests/test_v1_verdict_line.sh · test_v_requirements.sh — exit 4 · 사유 계약이 겹친다 / test_synthesize_findings.sh — case_synth_ac4 · ac5 가 같다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 같은 verdict.py 를 케이스마다 새로 띄우는 확인을 한 호출로 묶고, 파일의 큰 부분을 차지하는 변이 경위 주석은 PR 로 옮기면 지키는 것이 같다
- 확신: 중간

### plugins/quality-gates/tests/test_worktree.sh
- 초: 0.5
- 줄 수: 154
- 고친 횟수: 20
- 크기: 중간 — 케이스마다 임시 git 레포와 git worktree 를 만들고 setup-qg.sh 를 한 번 돌린다
- 종류: 섞임(동작 약 55 · 구조 약 10 · 글자 35 · 변이 0)
- 지키는 것: worktree 에서 돌린 setup-qg.sh 가 상태를 원본 레포가 아닌 worktree 안에 쓰고, 에이전트 파일과 SKILL 의 dispatch 가 project_dir 를 싣는다.
- 거짓 실패 위험: 중간 — agent 파일이나 SKILL dispatch 문구를 바꾸면 깨진다
- 겹침: plugins/quality-gates/tests/test_setup_qg.sh — 상태 폴더 생성 확인 / test_v_requirements.sh — V12 가 같은 SKILL dispatch project_dir 를 잰다 / shared/tests/test_agent_input_slots.sh(헤더가 지목)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — T3 · T4 는 git 자체(rev-parse · .git 이 파일)를 재 플러그인이 지키는 것이 없고 T5 는 V12 와 겹치며 T1(worktree 에 쓴다)만 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_ask_material_wiring.sh
- 초: 4.2
- 줄 수: 170
- 고친 횟수: 3
- 크기: 중간 — docreview_state.py · ledger_marker.py 를 약 20번 python 으로 띄우고 임시 git 레포 둘 · bash -c 펜스 실행을 쓴다
- 종류: 섞임(동작 약 45 · 구조 약 5 · 글자 50 · 변이 0)
- 지키는 것: 리뷰 결정 질문이 엔진의 질문 재료를 싣고, 표지 주인만 전문 파일을 쓰며(남의 표지는 rc 3 으로 멈춤), 전문 파일 자리가 링크면 링크 너머에 쓰지 않고 사유를 낸다.
- 거짓 실패 위험: 높음 — 절차서 · SKILL 문장을 `grep -cF` 로 그대로 세는 핀이 약 35개라 문구를 다듬으면 깨진다
- 겹침: shared/tests/test_docreview_ask.sh · test_plain_gate_templates.sh · test_ledger_wiring.sh — 같은 질문 재료 · 전문 파일 면을 잰다(겹치는 정도는 읽지 않음)
- 보안 갈래: 예
- 판정 후보: 줄임 — 표지 주인 · 링크 비추종 동작 확인은 유지하고 SKILL · 절차서 문장 핀 30여 개는 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_audit_template_gate_shape.py
- 초: 0.0
- 줄 수: 141
- 고친 횟수: 3
- 크기: 작음 — check_brief 함수를 한 프로세스에서 직접 부른다
- 종류: 섞임(동작 약 80 · 구조 20 · 글자 0 · 변이 0)
- 지키는 것: 출하 audit 템플릿이 coverage-mapper 계수와 포화 판정 자리를 `<k>` 자리표로 두어, 채우지 않은 턴이 게이트를 조용히 통과하지 못하고 설명 산문이 판정을 대신하지 못한다.
- 거짓 실패 위험: 낮음 — 템플릿 §2 줄 모양이나 게이트 판독이 바뀔 때만 깨진다
- 겹침: 확인 못 함(check_brief.py 이름 검색 결과가 12건에서 잘려 budget_mapper_failures 를 따로 찾지 않았다)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 실물 판정 함수로 침묵 통과를 막는 싼 동작 확인이다
- 확신: 높음

### plugins/spec-distill/tests/test_begin_round_snapshot.sh
- 초: 3.6
- 줄 수: 254
- 고친 횟수: 2
- 크기: 중간 — docreview_state.py init · begin-round 를 약 20번, 앵커 스냅숏을 약 25번 python 으로 띄우고 마지막에 git ls-files 로 레포 전체 파일을 훑는다
- 종류: 섞임(동작 약 85 · 구조 0 · 글자 15 · 변이 0)
- 지키는 것: begin-round 가 원장에 적힌 문서에서 라운드 스냅숏(울타리 절 line_hashes · 불변 절 item_marks)을 직접 만들고, 문서를 못 읽으면 원장을 바꾸지 않으며, 불변 절은 새 항목만 더한 편집을 허용한다.
- 거짓 실패 위험: 중간 — 끝의 「호출자 문면」 스윕이 13개 파일 이름과 cases.sh 의 begin-round 줄 수 하한 74 를 핀한다
- 겹침: shared/tests/fixtures/docreview/cases.sh · test_ledger_wiring.sh · test_state_dir_writes.sh 등 — begin-round 를 부르는 파일들이 같은 스냅숏 경로를 지난다(양의 짝 목록으로 직접 참조)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 엔진 동작 확인은 두고, 레포 전체를 훑는 음의 문면 스윕과 하드코딩된 파일 목록 · 74 하한은 더 싼 grep 한 줄로 내리면 시간과 거짓 실패가 줄어든다
- 확신: 중간

### plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh
- 초: 0.1
- 줄 수: 99
- 고친 횟수: 11
- 크기: 작음 — agent 파일 한 개를 awk · grep 으로 읽는다
- 종류: 섞임(동작 0 · 구조 약 55 · 글자 45 · 변이 0)
- 지키는 것: blind-spot-prober 에이전트가 쓰기 · 실행 · 위임 도구 없이 읽기와 웹 도구만 갖고 model 핀이 없으며(Law 2), 출력 스키마 키와 계약 슬롯을 갖는다.
- 거짓 실패 위험: 중간 — 도구 목록 한 줄 · 「once per」 같은 옛 문구 부재 · 「blind_spot 첫 전이 때 1회는 필수다」 문장을 그대로 핀한다
- 겹침: plugins/spec-distill/tests/test_research_agents_frontmatter.sh · test_steelman_builder_scope.sh · test_coverage_mapper_frontmatter.sh — 형제 에이전트의 도구 표면 / test_brief_agents.sh — 같은 도구 부재 확인
- 보안 갈래: 예
- 판정 후보: 합침 — 도구 allowlist 확인은 형제 에이전트 frontmatter 락과 같은 형태이므로 한 파일로 모으고, 옛 상한 문구 부재 확인은 글자만 지킨다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_agents.sh
- 초: 0.5
- 줄 수: 285
- 고친 횟수: 29
- 크기: 중간 — agent 파일 여섯 개를 awk · sed · grep 으로 반복해서 읽는 작은 프로세스를 수백 번 띄운다
- 종류: 섞임(동작 0 · 구조 약 55 · 글자 45 · 변이 0)
- 지키는 것: brief 리뷰 agent 들이 쓰기 · 실행 · 위임 도구와 model 핀 없이 읽기 도구만 갖고(Law 2), 격리 agent 집합이 정해진 둘이며, 엔진 사본과 readback 본문에 「비신뢰 입력」 주입 경계 규칙이 있다.
- 거짓 실패 위험: 중간 — readback 에 스키마 어휘 · 「audit」 · 「G1」 같은 단어가 없다는 확인과 「**NOT** 불릿 정확히 3개」 핀은 문구를 다듬으면 깨진다
- 겹침: shared/tests/test_docreview_agents.sh · test_copy_of_contract.sh(헤더가 직접 지목) — 같은 frontmatter · 사본 표면 / plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh — model 키 · 도구 부재
- 보안 갈래: 예
- 판정 후보: 줄임 — 도구 부재 · 격리 집합 · 주입 경계 확인은 유지하고 readback 어휘 부재(AC3 · AC25) · NOT 불릿 3개 핀은 글자만 지켜 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_body.py
- 초: 0.6
- 줄 수: 824
- 고친 횟수: 25
- 크기: 작음 — 순수 함수를 한 프로세스에서 부르고 선형 시간 확인에 python 서브프로세스 5번만 쓴다
- 종류: 섞임(동작 약 92 · 구조 0 · 글자 8 · 변이 0)
- 지키는 것: brief 판독의 허용 문법 하나가 사용자 발화 · 앵커 · 결정 줄을 판독기 셋이 같은 객체로 읽게 하고, 닮은 글자 · 보이지 않는 글자 · 숨긴 절 머리 · 인라인 HTML 로 위조한 앵커와 결정을 거부하며 정규식이 입력 길이에 선형이다.
- 거짓 실패 위험: 중간 — 거부 사유 이름(anchor_confusable 등)과 거부 말 문구를 그대로 비교하고 fixture 가 사용자 발화 원문 앵커에 걸려 있다
- 겹침: plugins/spec-distill/tests/test_check_brief.sh · test_check_verbatim_coverage.sh · test_roadmap_status.sh — 같은 판독기를 쓰는 다른 소비자(겹침 정도는 읽지 않음) / 같은 파일 안에서 confusable 군이 Round1 · 2 · 3 · 4 에 변형되어 되풀이된다
- 보안 갈래: 예
- 판정 후보: 둠 — 위조 앵커와 지수 시간 정규식을 지키는 가장 두꺼운 순수 함수 락이고 0.6초로 싸다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_bundle.sh
- 초: 4.8
- 줄 수: 540
- 고친 횟수: 16
- 크기: 큼 — build_brief_bundle.py 를 약 60번, 케이스마다 임시 git 레포를 만드는 fixture 도우미(rs_make · raw_source_fixture)를 약 20번 python 으로 띄운다
- 종류: 섞임(동작 약 95 · 구조 0 · 글자 5 · 변이 0)
- 지키는 것: brief 리뷰 번들이 payload · audit §6 원문 · 원자료 블록을 정해진 표지로 조립하고, audit 신원 불일치 · §6 종결 모호 · 번들 표지와 같은 줄 · 줄 나눔 글자를 만나면 조립하지 않고 이유를 대며 이름 · 시각 키를 redact 한다.
- 거짓 실패 위험: 중간 — 사유 문구(`신원 불일치` · `같은 절 제목이 두 번 이상 있다`)를 그대로 grep 한다
- 겹침: plugins/spec-distill/tests/test_brief_inline_blob.sh — redact 키 확인이 같은 부류(다른 스크립트) / test_check_brief.sh · test_reviewing_brief_skill.sh — 번들 호출 배선
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 위조 표지 · 신원 결속 확인은 유지하되 RS 케이스마다 새 레포를 만드는 fixture 를 함께 쓰면 시간이 줄어든다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_codex_axes.sh
- 초: 0.1
- 줄 수: 86
- 고친 횟수: 11
- 크기: 작음 — 파일 존재 · 심볼릭 링크 · SKILL grep 과 find 한 번
- 종류: 섞임(동작 0 · 구조 약 70 · 글자 30 · 변이 0)
- 지키는 것: spec-distill 이 엔진의 codex 러너 · 라우터를 가리키는 배포 링크가 실재하고 정본을 가리키며 reviewing-brief SKILL 이 그 러너와 처분 소비자를 대고, 옛 전용 스크립트 다섯이 이름을 바꿔 되살아나지 않는다.
- 거짓 실패 위험: 중간 — SKILL 의 codex 게이트 마커 · consumer 경로 문구를 grep 한다
- 겹침: plugins/spec-distill/tests/test_reviewing_brief_skill.sh · shared/tests/test_copy_of_contract.sh — 배포 링크 · SKILL 배선(이름만 확인)
- 보안 갈래: 아니오
- 판정 후보: 합침 — 링크가 정본을 가리키는 확인은 사본 계약 락과 같은 부류이고, 삭제한 이름이 안 돌아온다는 부재 확인은 글자만 지킨다
- 확신: 낮음

### plugins/spec-distill/tests/test_brief_inline_blob.sh
- 초: 0.4
- 줄 수: 174
- 고친 횟수: 8
- 크기: 중간 — build_brief_inline_blob.py 를 python 으로 약 12번 돌리고 가드를 지운 스크립트 사본을 한 번 만든다
- 종류: 섞임(동작 약 85 · 구조 0 · 글자 5 · 변이 10)
- 지키는 것: 비평가 · readback 프롬프트에 실리는 blob 에서 audit_file · name · created_at 이 redact 되고 §6 원문은 보존되며, 비-UTF-8 · 읽기 불가 payload 가 빈 blob 디스패치(fail-open)로 새지 않고 exit 2 로 끝난다.
- 거짓 실패 위험: 낮음 — 스크립트 동작이 바뀔 때만 깨진다(변이 사본은 가드 문구가 바뀌면 「치환 안 됨」 으로 RED)
- 겹침: plugins/spec-distill/tests/test_brief_bundle.sh — T12 redact 키 · 위생 스캔이 같은 부류 / test_brief_review_meta.sh · test_reviewing_brief_skill.sh — blob 호출 배선
- 보안 갈래: 예
- 판정 후보: 둠 — 빈 입력이 리뷰어에게 가는 fail-open 과 redaction 을 실행으로 재는 싼 락이다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_no_length_cap.sh
- 초: 0.2
- 줄 수: 97
- 고친 횟수: 3
- 크기: 작음 — grep · awk 와 check_brief.py gate · metrics 호출 두 번
- 종류: 섞임(동작 약 20 · 구조 약 15 · 글자 65 · 변이 0)
- 지키는 것: brief 템플릿에 절별 줄 예산이 돌아오지 않고, gate 가 정상 brief 에 JSON(advisories 채널 포함)을 내며 metrics 서브커맨드는 rc 64 로 거부된다. 그 외 부재 · 보존 확인은 글자만 지킴 — 템플릿 · check_brief.py 의 LINE_TRIPWIRE · 「이 절은 요약이다」 문구.
- 거짓 실패 위험: 높음 — 템플릿 문구(「이 절은 요약이다」 · 「1항목 = 첫 줄 하나」)를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_brief_no_statement_cap.sh — 같은 「걷어낸 상한이 돌아오지 않는다」 패턴(다른 상수)
- 보안 갈래: 아니오
- 판정 후보: 합침 — statement 상한 락과 함께 하나의 「상한 제거」 락으로 모으고 gate 실행 한 번을 공유한다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_no_statement_cap.sh
- 초: 0.2
- 줄 수: 142
- 고친 횟수: 6
- 크기: 중간 — grep 몇 번과 python 으로 임시 fixture 를 파생하고 gate 를 한 번 돌린다
- 종류: 섞임(동작 약 10 · 구조 0 · 글자 90 · 변이 0)
- 지키는 것: 200자 statement 가 게이트에 걸리지 않는다(rc 0). 나머지는 글자만 지킴 — check_brief.py · finishing.md · 템플릿의 STATEMENT_MAX · 「160자」 부재와 템플릿 C1 주석 「# 모델이 쓴 요약. P21 secret placeholder 치환」 정확 일치.
- 거짓 실패 위험: 높음 — 템플릿 주석 한 줄을 정확 일치로 핀해 주석을 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_brief_no_length_cap.sh — 같은 상한 제거 패턴
- 보안 갈래: 아니오
- 판정 후보: 합침 — 길이 상한 제거 락과 하나로 모으고 유일한 동작 확인(200자 통과)만 남기며 주석 정확 일치 핀은 덜어도 된다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_review_entry.sh
- 초: 0.2
- 줄 수: 286
- 고친 횟수: 23
- 크기: 작음 — pm-interview SKILL · references 를 awk 로 펜스 · 윈도우 단위로 잘라 grep 한다
- 종류: 섞임(동작 0 · 구조 약 10 · 글자 90 · 변이 0)
- 지키는 것: pm-interview 의 Step A.5 가 reviewing-brief 를 `$PAYLOAD` · `$AUDIT` 인자와 함께 부르고 옛 인자 둘을 나르지 않으며, B-2 가 4옵션 AskUserQuestion 과 「경고 줄」 질문을 갖고, audit 템플릿 칸이 reviewing-brief 의 웹 줄 모양과 같다.
- 거짓 실패 위험: 높음 — 펜스 · 윈도우 추출과 문구 grep 이 많아 문장을 다듬거나 SKILL 을 분할하면 깨진다
- 겹침: plugins/spec-distill/tests/test_reviewing_brief_skill.sh — 헤더가 직접 인용한 scoped_window · fence 관용구를 따로 복제한다 / test_reviewing_brief_residue.sh
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 펜스 · 윈도우 추출 도우미를 shared/tests 쪽에 한 벌로 두고 쓰면 사본 관용구가 사라져 거짓 실패가 줄고 지키는 배선은 그대로다
- 확신: 중간

#### 읽지 못한 것 — shallow-05
없음 — 32개 파일을 모두 끝까지 읽었다. 단 test_synthesize_artifact_findings.sh 와 test_verdict_vocabulary.sh 의 겹침 대상은 이름 검색만 했고 대상 테스트 본문을 읽지 않았다. 「겹침」 칸에 「이름만 확인」 · 「읽지 않음」 이라 적은 곳이 그렇다. 시간 근거(스폰 횟수)는 읽어서 센 추정이다.

## 묶음 shallow-06

### plugins/spec-distill/tests/test_brief_review_meta.sh
- 초: 0.2
- 줄 수: 213
- 고친 횟수: 25
- 크기: 작음 — grep · awk 로 plugin.json · CHANGELOG · README · 설계문서 · SKILL 을 읽을 뿐
- 종류: 섞임(동작 0 · 구조 20 · 글자 80 · 변이 0)
- 지키는 것: brief 리뷰 파이프라인의 문서 표면(훅 0 추가 · codex 끄기 스위치 문서화 · NFC 구현 존재 · SKILL 의 codex 게이트 펜스 하나)이 서로 어긋나지 않는다 — 단 CHANGELOG 옛 항목 · 설계문서 문구 핀은 글자만 지킴(CHANGELOG [0.24.0] 등 · spec §6.3 표 문구)
- 거짓 실패 위험: 높음 — README 문구 · CHANGELOG 항목 · 설계문서 표를 다듬거나 옮기면 깨진다(수정 25회가 그 증거)
- 겹침: plugins/spec-distill/tests/test_kill_switches_v060.sh · test_readme_sync.sh 가 같은 README · 버전을 잼(내용은 읽지 못함 — 확인 못 함)
- 보안 갈래: 예 — README 에 끄기 스위치(DISABLE_CODEX · DISABLE_BRIEF_REVIEW)가 적혀 있는지와 훅이 없는지를 확인하는 부분
- 판정 후보: 줄임 — 훅 부재 · 스위치 문서화 · SKILL 펜스 하나 · NFC 구현 존재만 남기고 CHANGELOG 과거 항목 핀 · 설계문서 §6.3/§5.5 문구 핀을 덜어도 지키는 것이 그대로다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_review_ng3.sh
- 초: 0.8
- 줄 수: 185
- 고친 횟수: 9
- 크기: 작음 — production 파일마다 별칭 네 개를 grep 하는 루프 + 프로필 두 개 읽기(하위 프로세스 수백 개 추정)
- 종류: 섞임(동작 0 · 구조 40 · 글자 60 · 변이 0)
- 지키는 것: 설계문서 자리와 brief 자리의 리뷰어 프로필이 서로 다른 정답 출처 · 검토 항목을 갖고(허용 목록 밖 공유 없음), 「brief 에는 분리 리뷰어가 없다」는 낡은 주장이 production 에 남지 않는다
- 거짓 실패 위험: 중간 — 프로필 frontmatter 문법이나 축 이름이 바뀌면 깨지고, 낡은 문구 별칭은 다듬기에 안 걸린다
- 겹침: plugins/spec-distill/tests/test_brief_agents.sh · test_reviewing_spec_residue.sh 가 프로필 · 낡은 주장 잔존을 잼(내용은 읽지 못함 — 확인 못 함)
- 보안 갈래: 예 — 리뷰어 프로필(Law 2 경계 소유자)의 자리 분리
- 판정 후보: 구조를 고침 — 별칭 × 파일 이중 루프의 grep 을 `grep -rlF -f` 한 번으로 내리면 지키는 것은 그대로고 시간이 준다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh
- 초: 0.8
- 줄 수: 52
- 고친 횟수: 4
- 크기: 큼 — 플러그인 전체와 shared/tests 를 임시 폴더로 복사하고 다른 테스트(test_brief_agents.sh)를 다시 돌린다
- 종류: 섞임(동작 40 · 구조 0 · 글자 60 · 변이 0)
- 지키는 것: 설치본이 배포 단위 밖 파일(docs/audits)이 없어도 brief 리뷰 격리 락이 통과하고, reviewing-brief SKILL 이 그 경로를 실행 시점에 읽지 않으며 감사 폴더가 되살아나지 않는다
- 거짓 실패 위험: 중간 — 격리 락이 다른 이유로 깨지면 이 테스트도 같이 빨개진다(연쇄 실패)
- 겹침: plugins/spec-distill/tests/test_brief_agents.sh — 통째로 한 번 더 실행됨
- 보안 갈래: 예 — 리뷰어 격리 락(tools allowlist)이 배포 단위 밖 파일에 기대지 않는지
- 판정 후보: 구조를 고침 — 복사 + 재실행 대신 SKILL · 테스트 파일에 `docs/audits` 참조가 없다는 grep 한 줄 + 폴더 부재 확인으로 내릴 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_brief_review_short.sh
- 초: 0.4
- 줄 수: 35
- 고친 횟수: 1
- 크기: 중간 — 임시 폴더에서 brief_review_state.py 를 python 으로 열두 번 가까이 띄운다
- 종류: 동작
- 지키는 것: 질문의 경고 줄에 이어 붙는 brief 리뷰 경고 짧은 줄(개수 · ×k · 두 번째 채널)이 원장 상태별로 맞게 나오고, 원장을 못 읽으면 rc 1 로 알린다
- 거짓 실패 위험: 중간 — 한국어 문구 한 글자를 바꾸면 깨지지만 출력 형식이 계약이다
- 겹침: plugins/spec-distill/tests/test_brief_review_state.py — 같은 스크립트의 다른 서브커맨드(겹치는 확인 없음)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 작고 출력 계약을 실행으로 잰다
- 확신: 높음

### plugins/spec-distill/tests/test_brief_review_state.py
- 초: 1.4
- 줄 수: 374
- 고친 횟수: 11
- 크기: 중간 — 케이스마다 임시 state 파일을 만들고 스크립트를 하위 프로세스로 약 60번 띄운다(추정)
- 종류: 동작
- 지키는 것: degrade 원장이 닫힌 열거 · append-only · 손상(null · 스칼라) 거부로 동작해서 「기록 없음」과 「degrade 없음」이 구분되고, 옛 세션 state 의 은퇴한 줄을 건드리지 않는다
- 거짓 실패 위험: 낮음 — 원장 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_state_storage_e2e.sh · test_interview_state_flow.sh 가 같은 스크립트를 부름(원장 부분 겹침은 읽지 못함 — 확인 못 함). 한 파일 안에서 --ledger-key 의 오타 거부가 TestLedgerKeyOverride · TestInitLedgerKey 에서 되풀이됨
- 보안 갈래: 아니오
- 판정 후보: 둠 — fail-closed 원장의 실제 동작을 잰다(프로세스 수는 많으나 값이 있다)
- 확신: 중간

### plugins/spec-distill/tests/test_brief_verbatim_full.sh
- 초: 1.3
- 줄 수: 153
- 고친 횟수: 3
- 크기: 중간 — 임시 폴더에 픽스처를 복사하고 python 을 하위 프로세스로 열 번 넘게 띄운다
- 종류: 섞임(동작 90 · 구조 0 · 글자 10 · 변이 0)
- 지키는 것: brief payload §6 이 사용자 발화 S1~Sn 을 전량 담고 추가만 허용되며, 남의 항목 본문 안에 심은 가짜 앵커 · state 에 안 더한 추가는 게이트가 막는다
- 거짓 실패 위험: 낮음 — 게이트 판정이 바뀔 때만 깨진다(마지막 SKILL rc 표 grep 한 줄만 글자)
- 겹침: plugins/spec-distill/tests/test_check_verbatim_coverage.sh · test_check_brief.sh 가 같은 두 스크립트를 부름(겹치는 케이스는 읽지 못함 — 확인 못 함)
- 보안 갈래: 예 — 사용자 발화 원장에 심은 앵커(주입) 거부
- 판정 후보: 둠 — 원문 보존 게이트의 음성 · 양성 대조를 실제 실행으로 잰다
- 확신: 중간

### plugins/spec-distill/tests/test_bundle_coverage.sh
- 초: 5.4
- 줄 수: 443
- 고친 횟수: 20
- 크기: 큼 — 임시 git 레포를 만들고 cp -R 로 사본을 일곱 번 뜨며 python 을 약 100번 띄운다(추정), chmod 000 시나리오 포함
- 종류: 섞임(동작 90 · 구조 0 · 글자 0 · 변이 10)
- 지키는 것: check_bundle_coverage.py 가 번호 대조(빠진 번호 · 얕은 답 · 받드는 에픽 없음 · 셀 수 없음)와 --plan · --impl 대조를 맞게 판정하고, 못 읽은 문서를 「받든다」로 치지 않으며 rc 를 계약대로 낸다
- 거짓 실패 위험: 중간 — 출력 한 줄 문구가 어휘 한 글자만 바뀌어도 깨진다. 권한(chmod 000) 케이스는 root 실행이나 파일시스템에서 흔들릴 수 있다
- 겹침: plugins/spec-distill/tests/test_coverage_scope.py — 같은 스크립트의 --impl · --plan · specs_dir · 받는 곳 규칙을 프로세스 안에서 잼. 한 파일 안에서 python 호출마다 같은 모듈을 새로 읽는다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 판정 케이스를 한 python 프로세스(함수 호출)로 모으고 레포 사본을 픽스처 한 벌에서 파생하면 지키는 것은 그대로고 시간이 크게 준다
- 확신: 중간

### plugins/spec-distill/tests/test_bundle_short_line.sh
- 초: 0.5
- 줄 수: 42
- 고친 횟수: 1
- 크기: 중간 — python 을 여섯 번쯤 띄우고 임시 폴더 하나 만든다
- 종류: 동작
- 지키는 것: 번호 대조 경고가 질문의 짧은 한 줄(개수 · 종류 순서 · 검사 불가 1개)로 나오고, 경고가 없으면 줄 자체가 없으며 개수 줄 위치가 고정이다
- 거짓 실패 위험: 중간 — 출력 문구 계약이 바뀌면 깨진다
- 겹침: 못 찾음(short_line · spec_review_bundle entry 를 이름으로 잰 다른 테스트를 찾지 못함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 작고 출력 계약을 실행으로 잰다
- 확신: 높음

### plugins/spec-distill/tests/test_check_brief_frontmatter.py
- 초: 0.0
- 줄 수: 79
- 고친 횟수: 1
- 크기: 작음 — 순수 함수 호출 일곱 번
- 종류: 동작
- 지키는 것: brief 게이트가 next_phase 값을 판정하지 않으면서도 type · user_sourced_items · audit_file · frontmatter 부재는 여전히 막는다
- 거짓 실패 위험: 낮음 — 게이트가 next_phase 를 다시 판정하거나 다른 축이 죽을 때만 깨진다
- 겹침: 확인 못 함 — 파일 이름으로는 못 찾음, plugins/spec-distill/tests/test_check_brief.sh 가 같은 게이트를 잴 공산이 크나 읽지 못함
- 보안 갈래: 아니오
- 판정 후보: 둠 — 값싸고 게이트 축마다 양성 증인을 가진다
- 확신: 높음

### plugins/spec-distill/tests/test_check_seed.sh
- 초: 0.3
- 줄 수: 61
- 고친 횟수: 2
- 크기: 중간 — check_seed.py 를 python 으로 여섯 번 띄운다
- 종류: 동작
- 지키는 것: seed 게이트의 검사 넷(답-슬롯 헤딩 · 태그 · URL · 빈 원문 절)이 각자 자기 픽스처에서 막히고 audit 경로가 없으면 통과가 아니라 막힘이며 깨끗한 seed 는 통과한다
- 거짓 실패 위험: 낮음 — 게이트 판정이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_seed_one_sentence.sh · test_seed_trust_boundary.sh · test_request_framing_entry.sh 가 check_seed 를 부름(겹치는 케이스는 읽지 못함 — 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 검사마다 픽스처를 나눠 「한 검사만 살아도 통과」를 막은 모범 구조다
- 확신: 높음

### plugins/spec-distill/tests/test_codex_findings_to_yaml.py
- 초: 1.2
- 줄 수: 372
- 고친 횟수: 13
- 크기: 중간 — 변환기를 하위 프로세스로 약 40번 띄운다(subTest 포함 추정)
- 종류: 동작
- 지키는 것: 신뢰할 수 없는 codex 출력이 스키마가 깨지면 성공으로 마킹되지 않고(codex_failed), 앞 펜스의 주입이 무시되고, summary 의 YAML 지시자 글자가 파싱 왕복에서 깨지지 않으며, default · design 키셋 출력 바이트가 고정이다
- 거짓 실패 위험: 낮음 — 변환 출력이 바뀔 때만 깨진다. 고정 경로 /tmp/sd_auth_stderr.txt 에 쓰는 케이스 하나는 동시 실행에 약하다
- 겹침: plugins/quality-gates/tests/test_findings_parser.sh · test_codex_copies_agree.sh 가 같은 변환기(정본 공유)를 잼(내용은 읽지 못함 — 확인 못 함)
- 보안 갈래: 예 — 외부 LLM 출력의 주입(마지막 펜스 우선) · fail-open 방지
- 판정 후보: 둠 — 외부 입력 경계의 실제 동작을 재고 값이 분명하다
- 확신: 중간

### plugins/spec-distill/tests/test_compression_adopters.sh
- 초: 0.1
- 줄 수: 131
- 고친 횟수: 6
- 크기: 작음 — 공용 도출 함수와 grep 뿐(줄의 대부분이 주석)
- 종류: 섞임(동작 0 · 구조 30 · 글자 70 · 변이 0)
- 지키는 것: compression.md 를 채택한 skill 이 둘 이상이라는 도출 하한만 의미가 있다 — 그 밖의 확인은 글자만 지킴 — 채택 skill 표면에 「의도|steering|방향|goal」 · 「확산.*압축|깎」 낱말이 한 줄이라도 있는지(일상어라 거의 항상 참)
- 거짓 실패 위험: 중간 — 채택 skill 표면에서 그 낱말이 모두 사라질 때만 깨지나 낱말이 너무 흔해 거의 안 깨지고, 하한 2 는 채택 포인터를 잃으면 깬다
- 겹침: plugins/spec-distill/tests/test_request_framing_entry.sh · test_distortion_devices.sh 가 compression.md 를 직접 읽음(문구 단언은 test_distortion_devices.sh 쪽이 더 구체적)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 낱말 grep 은 동작을 정하지 못하고 하한 2 도출은 test_distortion_devices.sh · 공용 adopter 락이 이미 읽는다(채택자 수 락만 따로 남길지는 뒤에 판단)
- 확신: 중간

### plugins/spec-distill/tests/test_conducting_interview_stage.sh
- 초: 2.1
- 줄 수: 1699
- 고친 횟수: 141
- 크기: 중간 — 대부분 grep · awk, 일부 mktemp 사본에서 SKILL 의 대조 펜스를 bash 로 실행(V2)
- 종류: 섞임(동작 3 · 구조 7 · 글자 90 · 변이 0)
- 지키는 것: pm-interview 의 SKILL · references 본문이 인터뷰 절차의 핵심 규칙(조사 상한 질문의 세 선택 · state 스키마 키 · 마이그레이션 이월 · 다음 세션 줄의 정지 요건 · web 끄기 스위치 문서화)을 싣는다 — 대다수는 글자만 지킴(pm-interview SKILL · references/finishing.md · state-migration.md 의 문장 리터럴)
- 거짓 실패 위험: 높음 — 문장 하나를 다듬거나 절을 다른 파일로 옮기기만 해도 깨진다(수정 141회 · 파일 분할이 락을 반복해 약화시켰다고 주석이 직접 말함)
- 겹침: plugins/spec-distill/tests/test_end_gates.sh · test_decompose_surface.sh · test_distortion_devices.sh 가 같은 finishing.md · SKILL.md 를 글자로 잼. 한 파일 안에서도 B-0~B-4 블록을 awk 로 여러 번 다시 뜬다
- 보안 갈래: 예 — 일부(web 끄기 스위치 문서화 · 재제시 상한의 자동 강등 금지)
- 판정 후보: 줄임 — 동작을 정하는 몇몇(state 스키마 필드 · V2 대조 펜스 실행 · 끄기 스위치)만 남기고 문장 리터럴 수십 개를 덜어도 지키는 것이 같다. 이 판단은 앞 460줄을 끝까지 읽고 나머지는 훑은 것이다
- 확신: 중간

### plugins/spec-distill/tests/test_conducting_reference.sh
- 초: 6.3
- 줄 수: 424
- 고친 횟수: 40
- 크기: 중간 — python3 -I 를 단언마다 새로 띄운다(100번 넘게 추정) + 변이 사본 몇 개
- 종류: 섞임(동작 10 · 구조 5 · 글자 70 · 변이 15)
- 지키는 것: 손으로 따르는 지휘 절차 문서가 걸음 1~9 · 승인 뒤 차례(기록 커밋 → 메인 → 같은 턴 계획 agent) · pr-record/pr-refresh 순서를 지키고 레포 전용 값(main · opus · plugins/…)을 박지 않는다 — 문장 리터럴 대부분은 글자만 지킴(conducting.md 걸음별 문구)
- 거짓 실패 위험: 높음 — 문장을 한 번만 나오게 못박은 단언이 많아 문구 정리에 깨진다(수정 40회)
- 겹침: plugins/spec-distill/tests/test_conducting_loop.sh · test_epic_conductor_skill.sh · test_conductor_dispatch_reference.sh 가 conducting.md 를 글자로 잼. 한 파일 안에서 「양성 대조」 합성 입력 단언이 같은 함수 판정을 되풀이한다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 순서 판정(chain · before · approval_order)을 python 한 프로세스로 모으고 once 단언의 grep 을 한 번에 돌리면 6초가 크게 준다. 이어 once 문장 핀은 줄임 후보
- 확신: 중간

### plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
- 초: 0.3
- 줄 수: 97
- 고친 횟수: 15
- 크기: 작음 — grep · awk 와 python 한 번
- 종류: 섞임(동작 0 · 구조 10 · 글자 90 · 변이 0)
- 지키는 것: 하위 agent 에게 보내는 글이 스위트 잠금 · TMPDIR · git stash 금지 · 두 부분 반환 · 처분 줄을 싣는다 — 대부분 글자만 지킴(references/conductor-dispatch.md 의 문장 리터럴 수십 개)
- 거짓 실패 위험: 높음 — 한 문장을 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conducting_reference.sh(옮김 꼬리 · 「원문은 늘 붙인다」 · 「지휘자 의견」 같은 문구 중복) · test_end_gates.sh(USED 문장 같은 글자)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 안전 규칙(스위트 잠금 · 다른 worktree git 조작 금지)과 절 머리만 남기고 문장 통째 핀을 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_conductor_state.py
- 초: 0.0
- 줄 수: 546
- 고친 횟수: 14
- 크기: 작음 — 순수 함수와 임시 폴더 파일 쓰기(프로세스 안)
- 종류: 동작
- 지키는 것: 지휘 기계 상태 파일의 형식 왕복 · 깨진 입력 거부 · 표지 있어야 저장하는 원자 쓰기 · 더 새 판이 쓴 파일은 읽지 않고 멈춤 · 옛 판 줄을 읽고 버리는 호환
- 거짓 실패 위험: 낮음 — 형식 · 규칙이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_conductor_cross.py · test_control_plane.py 가 같은 모듈을 부름(겹치는 확인은 읽지 못함 — 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 값싸고 상태 파일 손상 · 판 불일치를 실제로 잰다
- 확신: 높음

### plugins/spec-distill/tests/test_control_plane.py
- 초: 0.3
- 줄 수: 1330
- 고친 횟수: 30
- 크기: 작음 — 대부분 순수 함수 · 가짜 객체, git init 세 군데와 sleep 0.01 한 번
- 종류: 섞임(동작 97 · 구조 0 · 글자 3 · 변이 0)
- 지키는 것: 상태줄 · 지도 · 작업 목록 · 에픽 보기가 로드맵 보고에서 맞는 줄을 내고(셀 수 없음 · 경고 · PR 겹침 · team 보고), 제어 문자를 지우며, 못 읽은 기계 상태를 비어 있다고 말하지 않는다
- 거짓 실패 위험: 중간 — 표시 문구를 바꾸면 깨지나 동작 단언이다
- 겹침: plugins/spec-distill/tests/test_roadmap_status.sh · test_control_plane.sh(같은 모듈 · 이웃 파일) 가 같은 표시를 잼(내용은 읽지 못함 — 확인 못 함)
- 보안 갈래: 예 — 제어 문자(터미널 이스케이프) 제거 케이스 둘
- 판정 후보: 둠 — 0.3초에 130개 안팎의 실제 동작 확인을 돈다. 앞 230줄을 끝까지 읽고 나머지는 케이스 목록으로 판단했다
- 확신: 중간

### plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh
- 초: 0.1
- 줄 수: 91
- 고친 횟수: 13
- 크기: 작음 — frontmatter 추출 후 grep 약 40번
- 종류: 섞임(동작 0 · 구조 50 · 글자 50 · 변이 0)
- 지키는 것: coverage-mapper agent 의 도구 표면이 읽기 전용(쓰기 · 실행 · 위임 부재, model 키 없음)이고 출력 의무 키와 슬롯 선언이 있다 — 옛 상한 문구 부재 열두 개는 글자만 지킴(agents/coverage-mapper.md 의 옛 문구 목록)
- 거짓 실패 위험: 중간 — tools 줄 한 칸을 바꾸면 깨지고, 부재 목록은 문구 정리와 무관하게 안 깨진다
- 겹침: plugins/spec-distill/tests/test_research_agents_frontmatter.sh(두 agent 를 한 루프로 같은 규칙을 잼) · test_blind_spot_prober_frontmatter.sh · test_brief_agents.sh
- 보안 갈래: 예 — agent tools allowlist(Law 2)
- 판정 후보: 합침 — agent 도구 표면 · 모델 핀 · 출력 키 확인을 test_research_agents_frontmatter.sh 의 공용 루프로 모을 수 있다(옛 상한 문구 부재는 거기서 줄임)
- 확신: 중간

### plugins/spec-distill/tests/test_coverage_scope.py
- 초: 0.4
- 줄 수: 361
- 고친 횟수: 9
- 크기: 중간 — 순수 함수 위주, git init 세 번과 하위 프로세스 몇 번
- 종류: 동작
- 지키는 것: 번호 대조의 자리 표기 · 에픽 이름 · AC 범위(~) 파싱 · --acs 로 고른 대조 · 받는 곳 규칙 · 설계문서 폴더 해결이 맞고, 트리에서 못 읽은 설계문서나 git grep 실패를 「받든다」로 치지 않는다
- 거짓 실패 위험: 낮음 — 판정 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_bundle_coverage.sh — 같은 스크립트의 --impl · --plan · 받는 곳 · 셀 수 없음을 프로세스를 띄워 한 번 더 잼
- 보안 갈래: 아니오
- 판정 후보: 둠 — 프로세스 안에서 싸게 도는 쪽이라 test_bundle_coverage.sh 를 이쪽으로 모으는 방향의 기준이 된다
- 확신: 중간

### plugins/spec-distill/tests/test_decompose_surface.sh
- 초: 2.4
- 줄 수: 325
- 고친 횟수: 25
- 크기: 중간 — 임시 git 레포 + 바레 원격 + push 한 번, 그 위에서 펜스를 bash 로 여섯 번 실행
- 종류: 섞임(동작 20 · 구조 0 · 글자 80 · 변이 0)
- 지키는 것: 분해된 일의 Step A 8 펜스가 셸 메타문자 · 앞 '-' · 여러 줄 승인 원문이 든 제목 · 승인을 명령으로 실행하지 않고 글자 그대로 로드맵에 싣고 거절 시 폴더를 만들지 않는다 — 나머지 약 70개는 글자만 지킴(finishing.md · redecompose.md · roadmap-template.md 문구)
- 거짓 실패 위험: 높음 — 문장 리터럴 대부분이 문구 다듬기에 깨진다(수정 25회)
- 겹침: plugins/spec-distill/tests/test_end_gates.sh · test_entry_guidance.sh · test_conducting_interview_stage.sh 가 finishing.md 의 같은 절을 글자로 잼
- 보안 갈래: 예 — 승인 원문 속 명령 주입(pwned 파일) 실행 거부
- 판정 후보: 줄임 — 주입 e2e 와 heredoc 펜스 실행 확인은 남기고 문장 리터럴 수십 개를 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_design_profile_source.sh
- 초: 0.1
- 줄 수: 29
- 고친 횟수: 1
- 크기: 작음 — 프로필 한 파일 grep
- 종류: 글자
- 지키는 것: 설계문서 리뷰어 프로필이 정답 출처를 세 자리(ground_truth · 층 1 첫 문장 · 판정 관계 줄)에서 같은 모드 문장으로 말하고 옛 문장이 없다 — 이 프로필이 리뷰어의 판정 기준이라 글자가 곧 행동이다
- 거짓 실패 위험: 중간 — 프로필 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_brief_review_ng3.sh 가 같은 프로필의 ground_truth 를 다른 축(자리 분리)으로 읽음
- 보안 갈래: 예 — 리뷰어 프로필(persona 파일은 보안-민감)
- 판정 후보: 둠 — 작고 리뷰어 프로필 보호 갈래다
- 확신: 중간

### plugins/spec-distill/tests/test_detect_codex.sh
- 초: 1.1
- 줄 수: 70
- 고친 횟수: 7
- 크기: 중간 — 탐지 스크립트를 가짜 PATH 로 열네 번 실행하고 추적되는 codex-killswitch.conf 를 덮었다 복원한다
- 종류: 섞임(동작 85 · 구조 0 · 글자 15 · 변이 0)
- 지키는 것: codex 사용 가능 판정이 설치 · 인증 · 샌드박스 재귀 · 나쁜 판 · 판 바닥 · 끄기 스위치별로 맞게 skip 사유를 내고, 망가진 스위치 설정은 fail-closed 이며 다른 플러그인의 스위치 변수는 이 스크립트에 영향이 없다
- 거짓 실패 위험: 중간 — SIGKILL 이면 추적 파일이 덮인 채 남고(주석이 인정) 다른 실행과 겹치면 서로의 설정을 흔든다
- 겹침: plugins/quality-gates/tests/test_detect_codex.sh · plugins/plugin-audit/tests/test_detect_codex.py — 형제 정본 복사본의 같은 확인(합집합 주석)
- 보안 갈래: 예 — 끄기 스위치 · 설정 손상 fail-closed
- 판정 후보: 구조를 고침 — 추적 설정을 건드리지 말고 임시 사본 경로를 쓰게 하면 덜 깨진다(지키는 것은 그대로)
- 확신: 중간

### plugins/spec-distill/tests/test_distortion_devices.sh
- 초: 1.0
- 줄 수: 196
- 고친 횟수: 26
- 크기: 중간 — 단언마다 파일을 tr 로 접는 하위 프로세스, 스텁 스크립트로 advice-all 펜스를 세 번 실행
- 종류: 섞임(동작 8 · 구조 7 · 글자 85 · 변이 0)
- 지키는 것: 왜곡 방지 장치 문면(압축 규약의 「빼면 표에 남긴다」 · seed 덜어 낸 것 표 · trivia 질문 · 프로필 축 · payload §6 추가만 · 재리뷰 상한 문장)이 문서에 있다 + 「참고 전부 보기」 펜스가 원장 폴더에 쓰지 않고 path-inside 관문을 지킨다 — 앞쪽은 대부분 글자만 지킴(여러 skill · 프로필 · 템플릿의 문구)
- 거짓 실패 위험: 높음 — 열 개 넘는 파일의 문장 리터럴이라 문구 다듬기에 깨진다(수정 26회)
- 겹침: plugins/spec-distill/tests/test_end_gates.sh · test_compression_adopters.sh · test_design_profile_source.sh · test_conducting_interview_stage.sh 가 같은 파일을 글자로 잼
- 보안 갈래: 예 — 리뷰어 프로필의 자르지 않는 것(Law · kill switch 줄) · path-inside 관문
- 판정 후보: 줄임 — 펜스 실행 확인 · 프로필 보안 줄 · frontmatter 값은 남기고 문장 리터럴 대다수를 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_end_gates.sh
- 초: 0.4
- 줄 수: 268
- 고친 횟수: 26
- 크기: 작음 — grep · awk(단언마다 파일을 tr 로 접음), 파이썬 호출 없음
- 종류: 글자
- 지키는 것: 글자만 지킴 — proceed-gate.md · finishing.md B-2/B-3/B-A/B-R/B-S · brief 템플릿 · trivia-escape.md · CHANGELOG · README 의 문장 리터럴(CHANGELOG · README 문장 핀 포함). 예외로 B-R 이 대는 FormatError · TableError 문구가 roadmap_model.py · roadmap_render.py 의 실제 메시지와 같은지는 문서-코드 어긋남을 잰다
- 거짓 실패 위험: 높음 — 문장 · CHANGELOG 항목 · README 줄 하나를 다듬어도 깨진다(수정 26회)
- 겹침: plugins/spec-distill/tests/test_decompose_surface.sh · test_distortion_devices.sh · test_conducting_interview_stage.sh 가 finishing.md 의 같은 절을 글자로 잼. test_conductor_dispatch_reference.sh 와 USED 문장이 같은 글자
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 문서-코드 메시지 일치 두 건과 정본 둘째 질문의 뼈대만 남기고 CHANGELOG · README · 옛 문구 부재 핀을 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_entry_guidance.sh
- 초: 0.2
- 줄 수: 66
- 고친 횟수: 7
- 크기: 작음 — grep · awk 와 python 몇 번
- 종류: 섞임(동작 5 · 구조 10 · 글자 85 · 변이 0)
- 지키는 것: 로드맵 템플릿과 이 레포의 실제 로드맵 문서가 같은 지휘자 안내 줄을 싣고, 지휘 세션의 spec 승인 갈래가 미커밋 확인 → 승인 줄 · 커밋 → 저장 → 같은 턴 계획 agent 순서를 지킨다 — 나머지는 글자만 지킴(epic-handoff.md · spec-review SKILL 문구)
- 거짓 실패 위험: 높음 — 이 레포의 실제 로드맵 경로를 고정으로 읽어 로드맵을 옮기거나 지우면 깨진다
- 겹침: plugins/spec-distill/tests/test_epic_handoff.sh · test_decompose_surface.sh · test_conducting_reference.sh 가 같은 문서(epic-handoff.md · conducting.md)를 잼
- 보안 갈래: 예 — 일부(끄기 스위치가 플러그인 전체를 끈다는 서술 확인)
- 판정 후보: 줄임 — 순서 판정과 템플릿-로드맵 줄 일치만 남기고 문구 핀을 덜어도 지키는 것이 같다
- 확신: 중간

### plugins/spec-distill/tests/test_epic_handoff.sh
- 초: 0.5
- 줄 수: 140
- 고친 횟수: 9
- 크기: 작음 — grep · awk 와 python3 -I 를 여덟 번쯤 띄움
- 종류: 섞임(동작 0 · 구조 20 · 글자 80 · 변이 0)
- 지키는 것: 에픽 넘김 줄이 묶음 첨부 · 번호째 읽기 · --bundle · --plan/--impl 지시와 허용된 자리표만 싣고, team 줄이 brief 줄에 치환 표를 기계 적용한 글과 바이트가 같다 — 문장 리터럴 대부분은 글자만 지킴(references/epic-handoff.md 의 문장)
- 거짓 실패 위험: 높음 — 넘김 줄은 한 문장 길이라 단어 하나만 바꿔도 깨진다. 바이트 일치 단언이 특히 취약하다
- 겹침: plugins/spec-distill/tests/test_end_gates.sh(SHARED · USED 문장을 같은 글자로 잼) · test_entry_guidance.sh · test_review_handoff_order.sh · test_conducting_reference.sh
- 보안 갈래: 아니오
- 판정 후보: 합침 — 에픽 넘김 줄 문구 핀을 test_end_gates.sh · test_review_handoff_order.sh 의 같은 줄 락과 한 파일로 모으고 자리표 집합 · 순서 판정만 남긴다
- 확신: 중간

### plugins/spec-distill/tests/test_finishing_block_scope.py
- 초: 0.0
- 줄 수: 145
- 고친 횟수: 9
- 크기: 작음 — 파일 두 개를 읽어 정규식으로 펜스를 추출
- 종류: 섞임(동작 40 · 구조 60 · 글자 0 · 변이 0)
- 지키는 것: finishing.md · redecompose.md 의 bash 펜스가 앞 펜스의 변수를 물려받지 않는다(호출마다 새 셸이라 빈 경로로 조용히 실패하는 것을 막음)
- 거짓 실패 위험: 낮음 — 펜스가 앞 펜스 변수에 기댈 때만 깨진다. 열거가 아니라 도출이다
- 겹침: 못 찾음(펜스 변수 범위를 잰 다른 테스트를 찾지 못함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 값싸고 도출형이라 새 펜스에도 자동으로 걸리며 실제 결함 부류를 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_first_cell_check.py
- 초: 5.3
- 줄 수: 372
- 고친 횟수: 3
- 크기: 중간 — 케이스마다 임시 레포 픽스처를 만들고 python 을 하위 프로세스로 한두 번 띄운다(약 40케이스 → 80번 안팎 추정)
- 종류: 동작
- 지키는 것: brief 의 첫 칸(S1 원자료)이 framing 기록과 글자까지 같지 않으면(한 글자 · 인용 표지 · 공백 · CRLF) 막고 라벨 · 표시 어긋남을 사유 이름과 함께 내며, 가린 비밀값 텍스트도 판정하고 구조가 모호하면 「검사 불가」를 낸다
- 거짓 실패 위험: 중간 — 안내 문구 문자열을 그대로 단언하는 곳이 많다
- 겹침: plugins/spec-distill/tests/test_check_verbatim_coverage.sh · test_brief_verbatim_full.sh 가 같은 스크립트를 잼(첫 칸 · 표시 부분은 이 파일만). 한 파일 안에서 place + check 호출 쌍이 케이스마다 되풀이됨
- 보안 갈래: 예 — 비밀값 가림(REDACTED)이 결과물에 새지 않는지 확인하는 케이스
- 판정 후보: 구조를 고침 — place · check 를 하위 프로세스 둘 대신 모듈 함수 호출로 내리고 픽스처 레포를 파생하면 지키는 것은 그대로고 5초가 크게 준다. 픽스처 모듈(raw_source_fixture)은 읽지 못했다
- 확신: 중간

### plugins/spec-distill/tests/test_first_cell_finishing.sh
- 초: 2.9
- 줄 수: 220
- 고친 횟수: 4
- 크기: 중간 — 변이 하나마다 사본 복사 + python 두 번(치환 · 전체 검사)을 열여섯 번 가까이, 거기에 locate 펜스를 bash · zsh 로 여섯 번 실행
- 종류: 섞임(동작 15 · 구조 0 · 글자 40 · 변이 45)
- 지키는 것: 끝맺음이 seed 의 S1 을 원자료로 싣고 비밀값에서 싣기 전에 멈춰 묻고(가린 기록을 결과물과 같은 커밋에 넣음) 판결 종료 코드 2 · 3 · 0 별 안내가 실제 펜스에서 맞게 나온다 — 문장 검사 열네 개는 글자만 지킴(finishing.md Step A · A.5 문구), 변이가 그 검사들이 정말 빨개지는지 잰다
- 거짓 실패 위험: 중간 — 펜스 실행 쪽은 낮고 Step A 문구 쪽은 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_conducting_interview_stage.sh · test_decompose_surface.sh 가 finishing.md Step A 를 글자로 잼. 한 파일 안에서 같은 검사 함수를 변이마다 전부 다시 돈다
- 보안 갈래: 예 — 비밀값 확인 · 멈춤 · 가린 기록 커밋
- 판정 후보: 구조를 고침 — 변이 열여섯 건을 한 python 프로세스에서 사본 문자열로 돌리면 지키는 것(변이 이빨 포함)은 그대로고 시간이 준다
- 확신: 중간

### plugins/spec-distill/tests/test_fresh_evidence.sh
- 초: 0.1
- 줄 수: 91
- 고친 횟수: 4
- 크기: 중간 — python 없이 grep · awk, mktemp 한 번(쓰지 않는 scratch)
- 종류: 섞임(동작 0 · 구조 25 · 글자 75 · 변이 0)
- 지키는 것: 사용자가 준 신선한 근거 원칙 여덟이 fresh-evidence.md 에 원문 그대로 실리고, 바로잡기 「대체됨」 줄이 인터뷰 중 state 에서 종료 때 audit 으로 옮겨지는 길이 있으며, brief 게이트가 이 칸을 읽지 않는다 — 원칙 원문 보존이 핵심이라 글자가 곧 요구다
- 거짓 실패 위험: 중간 — 원칙 원문은 안 깨지고 행동 한 줄 · audit 템플릿 줄 문구가 바뀌면 깨진다
- 겹침: 못 찾음(fresh-evidence.md 를 이름으로 잰 다른 테스트를 찾지 못함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 작고 사용자 원문 보존이라는 분명한 값이 있다
- 확신: 중간

### plugins/spec-distill/tests/test_gh_repo.py
- 초: 0.0
- 줄 수: 134
- 고친 횟수: 5
- 크기: 작음 — 순수 함수와 mock 호출
- 종류: 동작
- 지키는 것: origin URL 일곱 꼴이 같은 호스트 · owner · repo 로 읽히고 못 뽑는 URL 은 멈추며, gh 의 인증 · 저장소 해석 실패 stderr 를 가려 멈춤 사유를 내고 GH_REPO 같은 환경변수는 알린다(devbrew 는 origin 을 -R 로 명시한다)
- 거짓 실패 위험: 낮음 — 파싱 · 분류가 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_gh_repo.sh(gh 호출 몫) · test_gh_single_door.sh — 같은 모듈의 이웃 확인이고 겹치는 케이스는 읽지 못함
- 보안 갈래: 예 — 엉뚱한 레포(GH_REPO · fork)로 쓰기 호출이 나가는 것을 막는 origin 고정
- 판정 후보: 둠 — 값싸고 외부 쓰기 호출의 대상 고정을 지킨다
- 확신: 높음

#### 읽지 못한 것 — shallow-06
- plugins/spec-distill/tests/test_conducting_interview_stage.sh — 1~460줄은 끝까지 읽었고 461~1699줄은 주석을 뺀 줄의 3분의 1을 훑은 것이다(도구 읽기 한도 때문). 뒷부분의 마이그레이션 · V2 대조 펜스 · R3 추천 표시 단언은 앞부분과 같은 글자 락 꼴로 보였다
- plugins/spec-distill/tests/test_control_plane.py — 1~230줄은 끝까지 읽었고 나머지는 클래스 · 테스트 메서드 목록과 하위 프로세스 · git 사용 줄만 봤다
- plugins/spec-distill/tests/test_first_cell_check.py — 같은 폴더의 픽스처 모듈(raw_source_fixture · test_raw_source_text)은 읽지 못해 git init 여부와 호출당 시간을 추정으로 적었다
- 겹침 칸의 「읽지 못함 — 확인 못 함」 표시는 이름 grep 으로 후보 테스트 경로만 확인하고 그 내용은 열지 않았다는 뜻이다

## 묶음 shallow-07

### plugins/spec-distill/tests/test_gh_repo.sh
- 초: 4.5
- 줄 수: 311
- 고친 횟수: 6
- 크기: 중간 — 임시 git 레포 여럿 + 가짜 gh 를 python -I 로 60여 번 새로 띄운다(sleep 모드는 0.5초 한도)
- 종류: 동작
- 지키는 것: gh 를 부르는 모든 길이 origin 에서 뽑은 -R 호스트/owner/repo 를 쓰고, gh 없음 · 인증 실패 · 비 GitHub · origin 없음 · 모양이 다른 응답에서 멈추며, 머지 명령은 전체 SHA 에 묶인다 — 깨지면 fork 의 upstream 에 머지/PR 명령이 나가거나 검사 없이 머지된다.
- 거짓 실패 위험: 중간 — gh 에러 문구(실측 stderr)나 STOP 문장을 다듬으면 깨진다. 동작이 바뀔 때도 깨진다
- 겹침: plugins/spec-distill/tests/test_gh_repo.py — 같은 gh_repo.py 를 겨눈다(내용은 확인 못 함). plugins/quality-gates/tests/test_gh_repo.sh 는 qg 쪽 사본이라 겹치지 않음
- 보안 갈래: 예 — 머지 명령이 head 커밋에 묶이는지 · -R 을 origin 으로 고정(남의 레포로 나가지 않음)
- 판정 후보: 구조를 고침 — 케이스마다 python 을 새로 띄우는 호출을 한 프로세스 안에서 여러 케이스로 묶으면 싸진다. 지키는 것은 그대로
- 확신: 중간

### plugins/spec-distill/tests/test_gh_single_door.sh
- 초: 1.3
- 줄 수: 246
- 고친 횟수: 5
- 크기: 작음 — git ls-files 로 목록을 뽑아 python ast/정규식으로 읽기만 한다(임시 폴더에 양성 대조 파일 몇 개)
- 종류: 섞임(동작 40 · 구조 20 · 글자 40) — ast 로 gh 호출 자리를 세는 판독기와 그 판독기의 양성 대조
- 지키는 것: spec-distill 의 gh 찾기 · 실행이 gh_repo.py 한 곳에만 있고 문서의 bash 펜스도 gh 를 직접 부르지 않으므로, 어느 스크립트나 문서가 -R origin 규칙을 우회해 gh 를 직접 부르면 잡힌다.
- 거짓 실패 위험: 중간 — 새 스크립트가 gh 를 정당하게 쓰거나 finishing.md 의 펜스 모양이 바뀌면 깨진다(펜스 수 하한 20 · VIA 6줄 같은 숫자 핀)
- 겹침: plugins/spec-distill/tests/test_gh_repo.sh — 그쪽은 gh_repo.py 의 동작, 이쪽은 우회 금지로 갈린다. 겹침 없음
- 보안 갈래: 예 — 외부 호출 문이 한 곳이라는 경계(origin 고정을 우회 못 함)
- 판정 후보: 둠 — 열거가 아니라 ast 로 도출해 비용 대비 이빨이 있다
- 확신: 중간

### plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh
- 초: 1.3
- 줄 수: 19
- 고친 횟수: 3
- 크기: 중간 — uv run 으로 별도 확인 모듈(grammar_vs_markdown_it_check)을 unittest 로 돌린다(uv 없으면 rc 3)
- 종류: 동작
- 지키는 것: brief/seed 본문의 허용 문법이 markdown-it-py 토큰과 어긋나지 않는지 교차 확인한다 — 깨지면 우리 판독기와 실제 마크다운 렌더가 다르게 읽는 글이 게이트를 통과한다. 이 파일은 래퍼이고 실제 확인은 확인 모듈에 있다(그 모듈은 읽지 않았다).
- 거짓 실패 위험: 중간 — uv 부재 · 의존 잠금(uv.lock) 변경 · 네트워크가 필요한 환경에서 깨지거나 rc 3
- 겹침: plugins/spec-distill/tests/test_grammar_vs_markdown_it.py(9회 수정) — 이름이 같아 같은 확인을 둘로 나눈 흔적일 수 있다(내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 래퍼 한 줄이고 비용은 uv 기동뿐. 단 같은 이름의 .py 와 정리 여부는 깊게 읽는 쪽이 봐야 한다
- 확신: 낮음

### plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh
- 초: 0.1
- 줄 수: 42
- 고친 횟수: 4
- 크기: 작음 — sed/awk/grep 으로 프로필 한 파일을 읽는다
- 종류: 글자
- 지키는 것: design-doc 프로필의 defer_target 이 「Deferred to plan」 을 가리키고 층 2 rubric 줄이 Handoff Context 를 댄다 — 깨지면 리뷰어가 defer 처분을 문서에 없는 절로 보내거나 handoff 누락을 못 잡는다.
- 거짓 실패 위험: 높음 — 프로필 문구를 다듬거나 절 이름을 바꾸면 깨진다. 파일 이름은 empty_subsections 인데 내용은 그것이 아니다(옛 템플릿 시절의 이름)
- 겹침: test_handoff_context_section_required.sh · test_handoff_conversation_reference.sh · test_handoff_design_mode.sh — 모두 같은 design-doc.md 의 층 2 rubric 줄 `handoff_incomplete` 을 읽는다
- 보안 갈래: 아니오
- 판정 후보: 합침 — handoff 계열 넷(design_mode · section_required · conversation_reference · 이것)을 design-doc 프로필 락 하나로 모을 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_handoff_context_section_required.sh
- 초: 0.1
- 줄 수: 62
- 고친 횟수: 3
- 크기: 작음 — sed/awk/grep 으로 프로필 한 파일
- 종류: 글자
- 지키는 것: 프로필이 handoff_incomplete 를 층 2 전용으로 두고(층 1 에는 없다) 층 2 본문이 그 발화 조건으로 Handoff Context 부재를 댄다 — 깨지면 리뷰어가 같은 결함을 두 층에 중복으로 내거나 handoff 누락을 못 잡는다.
- 거짓 실패 위험: 높음 — 프로필의 목록 줄 모양(layer1:/layer2: 한 줄)과 `## 층 2` 제목에 기대 문구를 다듬거나 줄바꿈하면 깨진다
- 겹침: test_handoff_context_empty_subsections.sh · test_handoff_conversation_reference.sh · test_handoff_design_mode.sh — 층 2 창을 같은 awk 로 자르고 같은 줄을 본다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 같은 awk 창 추출을 넷이 되풀이한다. 한 파일로 모으면 추출 한 번에 단언 여럿
- 확신: 중간

### plugins/spec-distill/tests/test_handoff_conversation_reference.sh
- 초: 0.1
- 줄 수: 35
- 고친 횟수: 4
- 크기: 작음 — awk/grep 으로 프로필 한 파일
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/spec-distill/references/docreview-profiles/design-doc.md 층 2 handoff_incomplete 줄의 「/compact」 · 「암묵 컨텍스트」 문구(리뷰어가 읽는 문장이 대화 컨텍스트 의존을 잡도록 하는 문구라 동작을 약하게 정함)
- 거짓 실패 위험: 높음 — 문구를 다듬으면 깨진다
- 겹침: test_handoff_context_section_required.sh · test_handoff_context_empty_subsections.sh · test_handoff_design_mode.sh — 같은 rubric 줄
- 보안 갈래: 아니오
- 판정 후보: 합침 — 앞 두 handoff 락과 같은 줄을 읽는다. 문구 확인은 한 곳에서 한 번이면 된다
- 확신: 중간

### plugins/spec-distill/tests/test_handoff_design_mode.sh
- 초: 0.1
- 줄 수: 67
- 고친 횟수: 7
- 크기: 작음 — sed/awk/grep 으로 프로필 · existing-first.md
- 종류: 글자
- 지키는 것: design-doc 프로필 층 2 목록에 일곱 카테고리가 함께 있고 approaches_comparison 항목이 「있는 것 검토」 절을 읽는 여섯 조건을 문장 그대로 싣는다 — 깨지면 설계 리뷰어가 있는 것 먼저 규칙을 못 잡는다. 다만 문장 전체를 byte 로 핀해 문구 다듬기에 약하다.
- 거짓 실패 위험: 높음 — approaches_comparison 문장 아홉 줄 · existing-first.md 두 문장을 글자 그대로 핀한다. 뜻이 같은 다듬기에도 깨진다
- 겹침: test_handoff_context_* 계열(층 2 목록 추출) · plugins/spec-distill/tests/test_design_profile_source.sh(같은 프로필, 내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 일곱 카테고리 존재(구조)는 두고, 문장 아홉 줄 byte 핀은 핵심 어구 몇 개로 줄이거나 프로필 쪽 계약으로 내린다
- 확신: 중간

### plugins/spec-distill/tests/test_handoff_kill_switch.sh
- 초: 0.1
- 줄 수: 74
- 고친 횟수: 6
- 크기: 작음 — find/grep 으로 몇 파일
- 종류: 글자
- 지키는 것: 집행 지점이 없어진 스위치 DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK 이름이 design 자리 표면(skill · 프로필 · 공유 엔진 · README)에 다시 나타나지 않는다 — 깨지면 사용자가 껐다고 믿지만 아무것도 끄지 못하는 스위치가 되살아난다.
- 거짓 실패 위험: 낮음 — 이름이 되돌아올 때만 깨진다. 양의 짝(코퍼스 ≥4 · 살아 있는 스위치 둘 읽힘 · README 실재)이 있다
- 겹침: plugins/quality-gates/tests/test_governance_no_capability_caps.sh 같은 kill switch 락과 다른 대상. 이 이름을 겨눈 다른 테스트는 못 찾음
- 보안 갈래: 예 — 끄는 스위치(kill switch)가 거짓 선언이 되는 것을 막음
- 판정 후보: 둠 — 값싸고 이유가 CLAUDE.md 「막지 않는 것을 막는다고 믿게 만드는 선언」 에 닿는다
- 확신: 높음

### plugins/spec-distill/tests/test_hook_output_schema.py
- 초: 0.0
- 줄 수: 65
- 고친 횟수: 34
- 크기: 작음 — git rev-parse 한 번(worktree 에서만 돈다, 밖에서는 skip)
- 종류: 구조
- 지키는 것: 글자만 지킴 — 파이썬 state_path.state_root() 가 파이썬 안에서 계산한 `${CLAUDE_PROJECT_DIR:-cwd}/.claude/spec-distill` 와 같다는 것. bash 를 실제로 실행하지 않고 같은 식을 파이썬으로 다시 쓴 것이라 자기 비교에 가깝다. 이름(hook_output_schema)과 내용이 다르다.
- 거짓 실패 위험: 높음 — worktree 안에서만 돌고, worktree 에서는 CLAUDE_PROJECT_DIR 이 메인 레포로 풀려 기존 실패가 난다(레포 메모의 TestCrossResolverAdvisory). 동작과 무관하게 환경에 따라 빨개진다
- 겹침: plugins/spec-distill/tests/test_state_root.sh · test_ledger_root.sh — 상태 루트 해석을 실제 실행으로 잰다(내용은 앞쪽만 확인)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 훅이 없어진 뒤(6.0.0) 이름이 낡았고 스스로 계산한 값을 견주며, 상태 루트는 test_ledger_root.sh 가 실제로 잰다. 34번 고쳐졌다는 점도 신호
- 확신: 중간

### plugins/spec-distill/tests/test_hooks.sh
- 초: 0.1
- 줄 수: 42
- 고친 횟수: 7
- 크기: 작음 — 파일 존재 확인 + grep + python json 한 번
- 종류: 구조
- 지키는 것: 지운 SessionStart 훅(session-anchor.sh)과 hooks/ 와 GC 훅이 되살아나지 않는다 — 깨지면 설치본에 훅이 다시 생겨 README 의 「훅 없음」 공시와 어긋난다.
- 거짓 실패 위험: 낮음 — 지운 것이 돌아올 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_review_hook_removed.py(hook_common 에서 빠진 이름을 리포 전체에서 금지, 내용은 확인 못 함) · test_no_write_matcher_hooks_repo.sh(hooks.json 전수)
- 보안 갈래: 아니오
- 판정 후보: 합침 — 「지운 것이 돌아오지 않는다」 부재 락이라 test_review_hook_removed.py 와 한 파일로 모을 수 있다
- 확신: 낮음

### plugins/spec-distill/tests/test_human_lines.py
- 초: 0.0
- 줄 수: 173
- 고친 횟수: 5
- 크기: 작음 — 한 프로세스 안에서 human_lines 함수 호출과 문서 몇 개 읽기
- 종류: 섞임(동작 80 · 글자 20)
- 지키는 것: 사람 결정 줄(spec 승인 · 계획 검토 · 흐름 승인 · 걸음 건너뜀)의 꼴 파서와 통과 라벨 표 · 본문 비교(기록 절을 뺀 본문이 같으면 같은 문서)가 맞다 — 깨지면 승인 줄이 위조되거나 문서가 바뀌었는데 승인이 낡음으로 안 잡힌다.
- 거짓 실패 위험: 낮음 — 파서 동작이 바뀔 때만. 한 단위(통과 라벨이 conducting.md 등에 실재)는 문구에 약하다
- 겹침: plugins/spec-distill/tests/test_human_judge.py · test_human_gate_e2e.sh — 같은 human_lines 를 쓰는 다른 층(내용은 확인 못 함)
- 보안 갈래: 예 — 사용자 승인 줄 위조 방지(어긋남 · 근거 없음 판정의 바탕)
- 판정 후보: 둠 — 빠르고 파서 경계(잘못된 줄 20여 개)가 분명하다
- 확신: 높음

### plugins/spec-distill/tests/test_interview_state.py
- 초: 4.4
- 줄 수: 525
- 고친 횟수: 10
- 크기: 중간 — 케이스마다 임시 git 레포를 init 하고 interview_state.py/state_path.py 를 하위 프로세스로 약 50회 실행(원격 bare 레포 케이스 포함)
- 종류: 동작
- 지키는 것: 인터뷰 진입 판정(RESUME/ASK/NEW/NEW-SEED/REJECT)이 링크된 상태 파일 · 링크된 audit/brief · 작업 트리 밖 파일을 거부하고 쓰기가 링크를 따라 밖을 건드리지 않으며, interview_dir 설정을 따른다 — 깨지면 심볼릭 링크로 남의 파일이 덮어써지거나 끝난 인터뷰가 되살아난다.
- 거짓 실패 위험: 낮음 — 출력 문구(REJECT 줄 · 안내 문장)를 글자로 비교해 문구 다듬기에는 중간. 동작이 바뀔 때 주로 깨짐
- 겹침: plugins/spec-distill/tests/test_interview_state_flow.sh · test_resume_candidate_names.sh · test_state_root.sh — 같은 스크립트를 다른 각도로(내용은 확인 못 함)
- 보안 갈래: 예 — 링크 · 경로 탈출 거부
- 판정 후보: 구조를 고침 — 케이스마다 새 git init 과 python 기동이 시간을 쓴다. setUp 의 git init 은 링크 케이스에 필요 없는 것이 많아 준비를 함께 쓰면 싸진다
- 확신: 중간

### plugins/spec-distill/tests/test_kill_switches_v060.sh
- 초: 0.9
- 줄 수: 70
- 고친 횟수: 7
- 크기: 중간 — 임시 git 레포 하나에서 ledger_sweep.py 를 하위 프로세스로 약 10회
- 종류: 동작
- 지키는 것: 원장 정리(파일을 지우는 장치)가 전역 스위치 · 옛 토큰 셋이 켜져 있으면 아무것도 지우지 않고, 다른 플러그인의 토큰은 무시하며, 스위치 없으면 지운다(양성 대조) — 깨지면 껐는데도 파일이 지워진다.
- 거짓 실패 위험: 낮음 — 스위치 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_ledger_sweep.py test_kill_switches_spare_everything — 같은 네 스위치를 파이썬으로도 잰다(거의 동일). 또 TTL 재정의는 이 파일에만
- 보안 갈래: 예 — 끄는 스위치가 파일 삭제를 실제로 멈춘다
- 판정 후보: 합침 — 스위치 넷 행렬은 test_ledger_sweep.py SafetyTest 에 이미 있다. TTL 두 케이스만 옮기고 한쪽으로 모을 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_ledger_marker.py
- 초: 1.7
- 줄 수: 199
- 고친 횟수: 2
- 크기: 중간 — ledger_marker.py 를 하위 프로세스로 약 60회 실행, 동시 취득 케이스는 프로세스 6개 × 10판
- 종류: 동작
- 지키는 것: 리뷰 원장 표지(reviewing-by)의 취득 · 확인 · 해제 · 인수가 한 세션만 이기고, 남의 표지는 지우지 않으며, 링크 표지 · 링크 폴더로 밖을 쓰지 않는다 — 깨지면 두 세션이 같은 리뷰 원장을 동시에 쓰거나 링크로 밖 파일을 덮는다.
- 거짓 실패 위험: 낮음 — 동작이 바뀔 때만
- 겹침: plugins/spec-distill/tests/test_ledger_wiring.sh · test_control_plane.py 가 이 스크립트를 언급(내용은 확인 못 함)
- 보안 갈래: 예 — 링크 · 경로 탈출 거부, 동시 쓰기 배타
- 판정 후보: 구조를 고침 — 동시 취득 10판 × 6프로세스가 시간 대부분이다. 판 수를 줄여도 지키는 것은 그대로(추정)
- 확신: 중간

### plugins/spec-distill/tests/test_ledger_root.sh
- 초: 5.3
- 줄 수: 283
- 고친 횟수: 9
- 크기: 중간 — 임시 레포 셋과 worktree, python/bash 하위 프로세스 수십 번, 옛 state_path.py 를 git show 로 꺼내 11개 호출을 새·옛 비교
- 종류: 섞임(동작 70 · 글자 30)
- 지키는 것: 문서가 속한 레포의 상태 루트를 쓰고(다른 레포 · 연결된 worktree · git 밖), spec-review · reviewing-brief · finishing 의 펜스가 문서 변수를 넘기는 state-root-for 만 쓰며 추적 파일이 있으면 멈춘다 — 깨지면 리뷰 원장이 엉뚱한 레포에 쌓이거나 git 이 추적하는 폴더에 쓴다.
- 거짓 실패 위험: 중간 — 펜스의 줄 모양 · 한계 문장(README) 문구에 기댄다. 옛 커밋 d433cd3b 를 git show 로 꺼내므로 얕은 클론이면 깨진다
- 겹침: plugins/spec-distill/tests/test_state_root.sh · test_reviewing_spec_state_keying.sh · test_ledger_wiring.sh — state-root-for 를 언급(내용은 확인 못 함)
- 보안 갈래: 예 — 경로 탈출(링크 폴더 거부), 추적 파일 위에 쓰기 거부
- 판정 후보: 구조를 고침 — 시간은 e2e 펜스 실행(레포 셋 + 상태 폴더)과 옛 코드 비교 11회가 쓴다. 옛 코드 대조는 고정 기대값으로 내리면 git show 와 python 11회를 아낀다
- 확신: 중간

### plugins/spec-distill/tests/test_ledger_sweep.py
- 초: 4.1
- 줄 수: 404
- 고친 횟수: 4
- 크기: 중간 — 케이스마다 임시 git 레포 + ledger_sweep.py/docreview_state.py 하위 프로세스(key_for 가 케이스마다 한 번 더), 옛 GC 를 git show 로 꺼내 실행
- 종류: 동작
- 지키는 것: 리뷰 진입 때의 원장 정리가 TTL 지난 문서 없는 원장과 옛 세션 폴더만 지우고, 읽지 못한 것은 남기고 알리며, 충돌에서는 새 쪽을 고르고, 링크 · 루트 탈출 · 잠금 · PyYAML 부재에서 아무것도 지우지 않는다 — 깨지면 살아 있는 리뷰 원장이 지워지거나 링크 너머 파일이 지워진다.
- 거짓 실패 위험: 낮음 — 출력 문구(「읽지 못한 원장 1개 남김」)를 글자로 비교하므로 문구 다듬기에는 중간. 옛 GC 커밋 9b7a5e07 에 기댄다
- 겹침: plugins/spec-distill/tests/test_kill_switches_v060.sh(스위치 행렬 중복)
- 보안 갈래: 예 — 삭제 장치의 경로 탈출 · 링크 · kill switch
- 판정 후보: 구조를 고침 — 케이스마다 새 git init 이 필요 없는 케이스가 많다(레포 안 이어야 하는 이유는 root 만). 준비 함께 쓰기로 아낄 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_merged_by_pr.py
- 초: 0.0
- 줄 수: 379
- 고친 횟수: 10
- 크기: 작음 — 한 프로세스 안에서 roadmap_status 의 순수 함수만 호출(가짜 git 객체)
- 종류: 동작
- 지키는 것: 에픽이 머지됐는지의 판정(PR 캐시 줄의 상태 · base · 교차 레포 · head 커밋 · 머지 커밋이 기본 브랜치에 닿는가, 지운 브랜치 · 이름 재사용 · fork)이 맞다 — 깨지면 머지 안 된 에픽이 머지됨으로 세어져 지휘자가 다음 에픽을 잘못 푼다.
- 거짓 실패 위험: 낮음 — 판정 결과가 바뀔 때만. 안내 문장 전체를 등호로 비교하는 몇 케이스는 문구에 약하다
- 겹침: plugins/spec-distill/tests/test_roadmap_status.sh(71회 수정)가 roadmap_status 를 통째로 돌린다 — 판정 순수 함수는 이 파일이 맡음(내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0초이고 분기가 촘촘한 판정 로직을 표로 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_merged_pr_range.py
- 초: 2.7
- 줄 수: 210
- 고친 횟수: 2
- 크기: 중간 — 케이스마다 임시 git 레포를 만들어 git 을 십수 번 실행(merge · squash · cherry-pick)
- 종류: 동작
- 지키는 것: PR 이 머지 커밋 · squash · rebase 어느 방식으로 머지됐든 리뷰할 커밋 범위(시작 · 끝 · 방식)를 맞게 확인하고, 못 확인하면 사유와 함께 rc 3/4 로 멈춘다 — 깨지면 qg 리뷰가 엉뚱한 범위를 본다.
- 거짓 실패 위험: 낮음 — 범위 계산이 바뀔 때만. 시스템 git 버전 차이(cherry-pick 커미터 · merge 기본값)에는 약간 약함
- 겹침: plugins/spec-distill/tests/test_qg_review_reference.sh 가 이 스크립트를 문서 쪽에서 언급(글자). 동작 겹침은 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 진짜 git 이 필요한 동작 시험이고 2.7초는 케이스 수(11)에 맞다
- 확신: 중간

### plugins/spec-distill/tests/test_next_session_command.sh
- 초: 0.1
- 줄 수: 213
- 고친 횟수: 6
- 크기: 작음 — 채택자 skill 표면을 도출해 python 한 번으로 정규식 검사
- 종류: 글자
- 지키는 것: 다음 세션 명령 줄이 채택 skill 마다 정확히 하나이고 slash 줄의 @ 토큰 수가 받는 쪽 한도 이하이며 평문 줄에 절대경로 · 거부 문구가 있다 — 깨지면 사용자가 붙여 넣는 명령이 받는 쪽 한도를 넘거나 경로가 안 풀려 다음 세션이 원문을 못 읽는다.
- 거짓 실패 위험: 중간 — 정본 절의 문장 열 개를 글자로 핀하므로 문구를 다듬으면 깨진다. 채택자는 도출이라 skill 추가에는 강하다
- 겹침: plugins/spec-distill/tests/test_proceed_gate_adopters.sh · test_compression_adopters.sh — 같은 adopter_derivation.sh 로 같은 채택자 집합을 각자 잰다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 채택자 도출과 표면 목록 준비가 세 테스트에서 되풀이된다. 도출은 공유하고 확인만 각자 두면 싸진다. 사용자에게 실제 영향(명령 줄 한도)이 있어 지키는 것은 있다
- 확신: 중간

### plugins/spec-distill/tests/test_no_wall_clock.sh
- 초: 0.2
- 줄 수: 81
- 고친 횟수: 7
- 크기: 작음 — 표면 파일 몇십 개를 grep
- 종류: 글자
- 지키는 것: 글자만 지킴 — skill · references · README 어디에도 wall_clock_started_at · DEVBREW_SPEC_DISTILL_TIMEOUT_MIN · wall-clock 토큰이 없다(제거한 인터뷰 월클락 기능이 되살아나지 않는다는 부재 락).
- 거짓 실패 위험: 중간 — 정당한 문장이 wall-clock 이라는 낱말을 쓰면 깨진다(CHANGELOG 는 제외)
- 겹침: 못 찾음(wall-clock 토큰을 겨눈 다른 테스트는 plugins/quality-gates/tests/test_governance_no_capability_caps.sh 뿐이고 대상이 다르다)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 제거 기능의 부재 락. 토큰 셋 · 파일 수십 개 × grep 이라 싸지만, 지키는 것이 「되살아남 방지」뿐이라 더 큰 부재 락 모음에 흡수해도 된다
- 확신: 낮음

### plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh
- 초: 0.1
- 줄 수: 149
- 고친 횟수: 8
- 크기: 작음 — git rev-parse + python 한 번으로 hooks.json 전수 읽기(2개)
- 종류: 구조
- 지키는 것: 리포의 어떤 플러그인도 쓰기 도구(Write/Edit 등)에 발화하는 PostToolUse 훅을 갖지 않는다 — 판정은 「쓰기 도구를 배제한다고 증명할 수 있는 matcher 만 통과」라는 allowlist 라서 새 쓰기 도구나 와일드카드 matcher 가 조용히 통과하지 않는다.
- 거짓 실패 위험: 낮음 — hooks.json 의 matcher 가 바뀔 때만 깨진다
- 겹침: plugins/project-init/tests/test_no_write_matcher_hooks.sh — 같은 이름의 짝(project-init 쪽, 내용은 확인 못 함). 중복일 수 있다
- 보안 갈래: 예 — 훅이 쓰기 도구에 발화하는 권한 경계를 fail-closed 로 막음
- 판정 후보: 합침 — project-init 쪽 test_no_write_matcher_hooks.sh 와 같은 이름 · 같은 질문이면 한쪽으로 모을 수 있다. 확인 전이라 둠이 안전
- 확신: 낮음

### plugins/spec-distill/tests/test_open_research.sh
- 초: 0.2
- 줄 수: 102
- 고친 횟수: 7
- 크기: 중간 — 펜스 두 개를 뜬 셸에서 env -i bash/zsh 로 약 12회 실행
- 종류: 섞임(동작 35 · 글자 65)
- 지키는 것: 인터뷰 skill 의 「조사 열기」 절의 웹 끄기 펜스가 스위치 값에 따라 open_researcher=go/skip 을 내고(1 만 skip, 01 · yes · 빈 값은 go), 요약 펜스가 reference 파일 없으면 rc 1 로 본체 직접 조사로 강등한다 — 깨지면 웹을 껐는데 웹 조사 agent 가 뜨거나 reference 없는 설치에서 조용히 실패한다.
- 거짓 실패 위험: 중간 — 열네 개 가까운 문장을 글자로 핀한다(AC1 · AC2 · AC12 · AC13 · AC14). 동작 부분(펜스 실행)은 낮음
- 겹침: plugins/spec-distill/tests/test_web_kill_switch.sh(25회 수정) — 같은 웹 끄기 스위치를 겨눈다(내용은 확인 못 함)
- 보안 갈래: 예 — 웹 조사(바깥 호출)를 끄는 스위치가 실제로 듣는다
- 판정 후보: 구조를 고침 — 펜스 실행(동작)은 둔 채 skill 문장 핀 열네 개를 핵심 어구로 줄인다. 웹 스위치 행렬은 test_web_kill_switch.sh 와의 합침 후보
- 확신: 중간

### plugins/spec-distill/tests/test_overdesign_rubric.sh
- 초: 0.3
- 줄 수: 356
- 고친 횟수: 11
- 크기: 작음 — awk/sed/grep 위주, PyYAML 한 번씩 두 프로필
- 종류: 섞임(구조 35 · 글자 65)
- 지키는 것: brief · design 두 프로필에 overdesign 축이 layer1 한 줄로 서 있고 축마다 본문 불릿이 있으며, 판정 한 줄 형식(슬롯 다섯)과 「자르지 않는 것」(보안 · 접근성 · 데이터 손실 · kill switch 등) 가드가 있다 — 깨지면 리뷰어가 보안 검사를 자르자고 제안하거나 layer1 이 줄바꿈돼 codex 러너가 죽는다.
- 거짓 실패 위험: 높음 — 프로필 본문 문구를 다듬거나 축 개수(2 · 9) · 표 행 수(5 · 4) 를 바꾸면 깨진다. 반면 PyYAML 대 줄 기반 일치 확인은 실제 파서 갈림을 잰다
- 겹침: plugins/spec-distill/tests/test_docreview_profiles.sh 가 층 2 범주 불릿에 같은 원칙을 건다고 주석에 있으나 파일은 이 묶음 밖(확인 못 함)
- 보안 갈래: 예 — 리뷰어 프로필의 「자르지 않는 것」 보안 가드를 지킨다(프로필 약화는 보안 리뷰 대상)
- 판정 후보: 구조를 고침 — 파서 일치(PyYAML 대 줄 기반)와 보안 가드 문구는 두고, 본문 문구 핀 수십 개는 줄이거나 프로필 쪽 구조 검사로 내린다
- 확신: 중간

### plugins/spec-distill/tests/test_parallel_recommend_docs.sh
- 초: 0.6
- 줄 수: 178
- 고친 횟수: 21
- 크기: 작음 — conducting.md 등 문서를 awk 로 잘라 grep, python 한 번
- 종류: 글자
- 지키는 것: 글자만 지킴 — references/conducting.md · proceed-gate.md · spec-review SKILL · integration-reviewer.md · README · CHANGELOG 8.11.0 · 설계 문서의 병렬 질문 · 이음매 일곱째 · 「차례로」 확인 문장 약 100개를 «정확히 한 번» 있다고 핀한다. 그 문장 일부가 지휘 절차의 동작을 정하긴 하나 테스트는 문구만 본다.
- 거짓 실패 위험: 높음 — 문구를 한 글자 다듬거나 절을 옮기면 깨진다. 21번 고쳐졌고 CHANGELOG · README · 설계문서 줄까지 핀한다
- 겹침: plugins/spec-distill/tests/test_conducting_reference.sh · test_conducting_loop.sh · test_roadmap_status.sh 가 같은 conducting.md 를 겨눈다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 문장 핀 약 100개 중 동작을 정하는 몇 개(병렬 질문 선택지 · 답 기록 규칙)만 남기고 CHANGELOG · README · 설계문서 문구 핀은 내린다. 지움 후보도 있으나 조건 일부는 병렬 판단 동작이다
- 확신: 중간

### plugins/spec-distill/tests/test_plain_gate_templates.sh
- 초: 0.6
- 줄 수: 177
- 고친 횟수: 19
- 크기: 작음 — 문서 다섯 개를 줄바꿈 접어 grep 여러 번(python 한 번)
- 종류: 글자
- 지키는 것: 글자만 지킴 — finishing.md · spec-review · reviewing-brief · request-framing · proceed-gate.md 에 게이트 질문이 결정 하나 · 경고 줄 하나 · 「전문」 줄만 싣고 경고는 「게이트 앞 글」에 쓴다는 문장과 「이상 없음 / 경고 없음」 구분 문장이 그 자리에 «정확히 한 번» 있다. 사람에게 보이는 글의 규칙이라 의도는 있으나 테스트는 문장 일치만 본다.
- 거짓 실패 위험: 높음 — 문장 앞뒤 글자까지 핀하고(「… 한 번 있다」) 줄바꿈 접은 본문에서 비교한다. 19번 고쳐졌다
- 겹침: plugins/spec-distill/tests/test_proceed_gate_adopters.sh · test_next_session_command.sh — 같은 채택자 문서를 읽는다. test_window_phrases.sh(shared)와 겹칠 수 있음(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 문장 핀을 정본(proceed-gate.md) 한 곳에서 재고 채택 skill 에서는 정본 포인터만 확인한다(채택자 대칭 락이 이미 있음)
- 확신: 낮음

### plugins/spec-distill/tests/test_pm_interview_entry.sh
- 초: 0.1
- 줄 수: 71
- 고친 횟수: 4
- 크기: 작음 — grep/awk, python 한 번(CHANGELOG 표 행)
- 종류: 섞임(구조 60 · 글자 40)
- 지키는 것: pm-interview 가 사용자가 부르는 진입 skill 로 보이고(frontmatter 에 user-invocable 없음 · name · description · cost_class: variable) 옛 진입 이름(command · skill 디렉터리)이 사라졌으며 CHANGELOG 의 major 절에 옛 → 새 이름 표 행이 있다 — 깨지면 메뉴에서 skill 이 숨거나 옛 이름이 별칭으로 남는다.
- 거짓 실패 위험: 낮음 — frontmatter · 파일 존재 같은 구조가 바뀔 때만. CHANGELOG 표 행은 문구에 약간 약함
- 겹침: shared/tests/test_invocation_surface.sh 가 진입 skill 이름 규칙을 집행한다고 CLAUDE.md 에 있음(내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — frontmatter 구조와 cost_class 는 공용 락(test_invocation_surface.sh)이 덮을 공산이 크다. 이 skill 고유 부분(옛 이름 부재 · CHANGELOG 행)만 남긴다
- 확신: 낮음

### plugins/spec-distill/tests/test_probe_sweep_residue.sh
- 초: 0.2
- 줄 수: 147
- 고친 횟수: 6
- 크기: 작음 — git grep 몇 번(레포 전체 추적 파일 대상)
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/spec-distill 안(픽스처 · CHANGELOG · 이 파일 제외)에 지운 probe 상한 기능의 식별자(probe_budget · probe_cap 등)와 「probe … 백스톱」 같은 근접 개념이 다시 나타나지 않는다. 헤더가 한계(산문 부활은 못 잡음)를 스스로 적었다.
- 거짓 실패 위험: 중간 — 정당한 후속 이력 문장이 두 정규식에 걸리면 영구 RED(헤더가 인정). 새 문서에 우연히 같은 낱말 근접이 생겨도 깨진다
- 겹침: 못 찾음(probe 잔존을 겨눈 다른 테스트는 찾지 못했다)
- 보안 갈래: 아니오
- 판정 후보: 지움 — 스윕 완료 확인용 일회성 부재 락이고, 헤더 스스로 산문 부활은 못 잡는다고 적었다. 지키는 것이 「옛 식별자가 코드에 안 남음」뿐이라 동작을 정하지 않는다
- 확신: 중간

### plugins/spec-distill/tests/test_proceed_gate_adopters.sh
- 초: 0.2
- 줄 수: 214
- 고친 횟수: 11
- 크기: 작음 — adopter_derivation.sh 로 채택자를 도출해 grep -c 위주
- 종류: 글자
- 지키는 것: proceed-gate 정본을 채택한 모든 skill 이 자기 표면에 정지 어휘(턴 종료/다음 턴) · polite stop 금지 · degrade 채널 · 재결정 규약 · 정본을 읽는 Read 줄을 갖는다 — 깨지면 새 채택 skill 이 게이트 계약(polite stop 금지 · 재결정 경로)을 조용히 빠뜨린다.
- 거짓 실패 위험: 중간 — 도출이라 skill 추가에는 강하나 어휘 하나(「degrade 채널」 등)를 바꾸면 깨진다
- 겹침: plugins/spec-distill/tests/test_conducting_interview_stage.sh · test_next_session_command.sh — 같은 채택자 도출. 헤더가 interview 쪽과 의도적 이중(defense-in-depth)이라고 밝힘
- 보안 갈래: 아니오
- 판정 후보: 둠 — 도출 기반 대칭 락이라 구조적 이빨이 있다(CLAUDE.md 의 Polite stop/Polite handoff 금지 · P23 재결정). 단 같은 도출 준비는 세 테스트가 공유할 여지
- 확신: 중간

### plugins/spec-distill/tests/test_qg_review_reference.sh
- 초: 0.8
- 줄 수: 520
- 고친 횟수: 11
- 크기: 작음 — qg-review.md · conducting.md · qg SKILL 등 문서를 awk 로 잘라 grep 수백 번, python(YAML 파서) 한 번
- 종류: 섞임(구조 15 · 글자 85)
- 지키는 것: 글자만 지킴이 대부분 — skill/epic-conductor/references/qg-review.md 의 문장 약 100개(호출 줄 · 자리 표 · 보내는 차례 · 이미 보낸 것 다섯 근거 · 보관 · 기록 틀 · 행선)를 «정확히 한 번» 있다고 핀한다. 일부는 qg 계약 판 · 머리 칸 이름 · 라벨 순서를 qg 쪽 파일과 견주는 결합 락이고 기록 틀 머리를 YAML 로 읽어 보는 부분은 실제 파서 확인이다.
- 거짓 실패 위험: 높음 — 문장 한 글자 변경에도 깨진다. 11번 고쳐졌다. qg 쪽 계약 판이 오르면 연쇄로 깨짐(의도된 결합이지만)
- 겹침: plugins/spec-distill/tests/test_conducting_reference.sh 와 conducting.md 들어가는 문장 · shared/tests/fixtures/ask-sites.tsv 행이 겹침. 계약 결합은 quality-gates 쪽 state-file-format 테스트와 겹칠 수 있음(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 문장 핀 약 100개를 qg 계약 결합(판 · 칸 이름 · 라벨 순서)과 YAML 읽기(동작 확인)만 남기고 절차 문장 핀은 줄이거나 지운다. 지키는 것을 쓸 수 있는 부분이 소수
- 확신: 중간

### plugins/spec-distill/tests/test_r2_bypass_residue.py
- 초: 1.8
- 줄 수: 579
- 고친 횟수: 7
- 크기: 중간 — 하위 프로세스로 seed_provenance.py · seed_review_log.py · check_brief.py 를 십수 번, bash 펜스 실행, 선형 시간 확인(5만 글자 줄 · 2초 문턱)
- 종류: 섞임(동작 90 · 글자 10)
- 지키는 것: seed/audit/brief 입력의 알려진 우회(frontmatter 에 URL · 제목 · 앵커 모양 줄 심기, 홀로 선 CR 로 줄 위조, 맨 도메인 · 문자 참조, 「(사용자 확인 완료)」 변형, 펜스 안 가짜 제목, audit 앞부분의 열린 HTML)를 게이트가 거부하고 정상 글은 통과시킨다 — 깨지면 모델이나 외부 글이 사용자 확인 표시를 위조해 게이트를 통과한다.
- 거짓 실패 위험: 중간 — 시간 문턱 2초(선형 확인)가 부하에 흔들린다. 설계문서 `## 미룸` 행 문구를 읽는 단위는 문서 편집에 약하다
- 겹침: plugins/spec-distill/tests/test_check_brief.sh(85회 수정) · test_seed_provenance.sh · test_seed_gate_wiring.sh 가 같은 게이트를 다른 각도로(내용은 확인 못 함)
- 보안 갈래: 예 — 입력 위조 · 주입(사용자 확인 표시 위조) 방어
- 판정 후보: 둠 — 우회마다 재현 + 양성 대조라 이빨이 있다. 시간 문턱 두 개는 상한을 느슨히 하는 정도로 손볼 만하다
- 확신: 중간

### plugins/spec-distill/tests/test_raw_source.py
- 초: 1.9
- 줄 수: 306
- 고친 횟수: 3
- 크기: 중간 — 케이스마다 임시 git 레포를 init 하고 raw_source.py locate 를 하위 프로세스로 약 30회
- 종류: 동작
- 지키는 것: 원자료(framing 기록 파일)를 seed 또는 인터뷰 상태 파일에서 찾는 길(FOUND/LOST/NO-FRAMING 과 사유 · 작업 트리 밖 · 링크 · 펜스 모양)이 맞고 옆 로드맵 생성기(team_write)와 같은 판결을 낸다 — 깨지면 원자료를 잃었는데 NO-FRAMING 으로 조용히 넘어가거나 두 생성기가 다른 사실을 낸다.
- 거짓 실패 위험: 낮음 — 판결 줄이 바뀔 때만. 사유 문구는 상수(RS.R_*)로 비교해 문구 다듬기에 강함
- 겹침: plugins/spec-distill/tests/test_raw_source_text.py · test_raw_source_profiles.sh · test_framing_raw_source.sh · test_interview_raw_source_entry.sh — 같은 스크립트의 다른 면(내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 케이스마다 git init + python 기동이 시간을 쓴다. locate 는 git 이 필요 없는 케이스(seed · state 읽기)가 많아 레포 준비를 함께 쓰거나 함수 직접 호출로 내릴 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_raw_source_downstream.sh
- 초: 3.3
- 줄 수: 248
- 고친 횟수: 6
- 크기: 중간 — 임시 레포 셋(good · bad · seeded) 각각 git init/add/commit/push + bare origin + python -I 호출 여러 번(place · original · create)
- 종류: 변이(변이 60 · 동작 40) — place 를 건너뛰거나 seed 전문을 심은 레포에서 같은 판정이 실패하는지 본다
- 지키는 것: 원자료 사본(S1)이 로드맵 생성기(original · create)와 에픽 묶음까지 따라가 사용자 원문 구간에 framing 두 절이 있고 seed 전문이 어디에도 없다 — 깨지면 모델이 줄인 seed 가 사용자 원문으로 둔갑해 하류 문서에 실린다.
- 거짓 실패 위험: 낮음 — 파이프라인 동작이 바뀔 때만. 양성 짝과 변이 둘이 있어 이빨은 확인됨
- 겹침: plugins/spec-distill/tests/test_raw_source_profiles.sh · test_framing_raw_source.sh — 같은 원자료 흐름의 다른 구간(내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 레포 셋 중 good/seeded 는 같은 준비를 되풀이한다(place 후 seed 표지만 다름). 준비 한 번 만들어 복사하면 git 연쇄 두 번을 아낀다
- 확신: 중간

#### 읽지 못한 것 — shallow-07
없음 — 묶음의 32개를 끝까지 읽었다(test_qg_review_reference.sh 는 두 번에 나눠 읽음). 겹침 칸은 대상 이름으로 grep 한 파일 목록까지만 봤고, 이 묶음 밖 파일의 내용은 열지 않아 「확인 못 함」 으로 적은 곳이 많다. test_grammar_vs_markdown_it.sh 가 부르는 확인 모듈(grammar_vs_markdown_it_check.py)은 열지 않았다.

## 묶음 shallow-08

### plugins/spec-distill/tests/test_raw_source_profiles.sh
- 초: 1.6
- 줄 수: 179
- 고친 횟수: 3
- 크기: 중간 — python 한 프로세스가 프로필 사본을 약 40번 만들고 그때마다 docreview_state.py profile-check 를 하위 프로세스로 부른다(추정)
- 종류: 변이
- 지키는 것: brief · 설계문서 리뷰 프로필이 첫 칸의 사용자 줄과 모델이 줄인 줄을 갈라 읽으라고 말하지 않게 되면(문구가 빠지거나 반대로 바뀌면) 리뷰어가 모델 글을 사용자 말로 착각한다 — 라벨 상수 셋이 raw_source.py 와 어긋나도 잡는다.
- 거짓 실패 위험: 높음 — 프로필 문장을 다듬기만 해도 깨진다(문장 통째를 핀한다)
- 겹침: 확인 못 함 — 같은 프로필 파일을 이름으로 대는 test_reviewing_brief_skill.sh · test_dispatch_profile_inline.sh 가 있으나 내용 겹침은 열어 보지 않음
- 보안 갈래: 예 — 리뷰어 프로필의 원문 판독 규칙
- 판정 후보: 둠 — 변이로 이빨을 재고 지키는 것이 분명하다. 비용도 1.6초로 작다
- 확신: 중간

### plugins/spec-distill/tests/test_raw_source_text.py
- 초: 4.2
- 줄 수: 479
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 임시 git 레포를 새로 만들고 raw_source.py 를 하위 프로세스로 부른다(약 40회, 추정)
- 종류: 동작
- 지키는 것: raw_source.py 가 원문을 brief 첫 칸에 그대로 싣지 못하는 글(가짜 S 앵커 · 심은 결정 제목 · 줄 나눔 글자)을 거절하고, place 가 brief 를 망가뜨리거나 두 번 싣지 않고, 종료 코드가 맞다.
- 거짓 실패 위험: 중간 — 종료 코드와 stderr 한 줄 문구를 글자 그대로 핀해, 메시지만 바꿔도 깨진다
- 겹침: 확인 못 함 — raw_source.py 를 이름으로 대는 test_raw_source_downstream.sh · test_first_cell_finishing.sh · test_interview_raw_source_entry.sh 가 있으나 내용은 열어 보지 않음
- 보안 갈래: 예 — 원문 절에 심은 앵커 · 결정 줄의 거절, 심볼릭 링크 거부
- 판정 후보: 구조를 고침 — 읽기만 하는 명령(first-cell · locate · review-block)은 레포 하나를 함께 쓸 수 있는데 케이스마다 새 레포를 만든다
- 확신: 중간

### plugins/spec-distill/tests/test_readme_sync.sh
- 초: 0.3
- 줄 수: 248
- 고친 횟수: 41
- 크기: 작음 — README · CHANGELOG grep 과 python 두 번(파일 이름 도출 · agents 목록 대조)
- 종류: 섞임(동작 0 · 구조 12 · 글자 28 · 변이 0)
- 지키는 것: README 가 지워진 .py · .sh 파일이나 은퇴한 agent 를 현재형으로 대지 않고, AP9 의 agent 수 · 목록이 agents/ 폴더와 같다 — 나머지(키워드 존재 · CHANGELOG 옛 엔트리 보존)는 글자만 지킨다.
- 거짓 실패 위험: 높음 — README 문장을 고칠 때마다 깨진다(41번 고쳐진 것이 그 증거). 키워드 열세 개 · Principles 문구를 핀한다
- 겹침: plugins/spec-distill/tests/test_rereview_cap_consistency.sh · test_reviewing_brief_skill.sh — README 의 재리뷰 상한 · gap 범위 표기를 각자 다시 잰다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 도출한 실재 대조(파일 이름 · agents 목록)는 남기고, 키워드 존재 열세 개와 CHANGELOG 엔트리 핀(git 이 지키는 것)은 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_repo_defaults.py
- 초: 0.1
- 줄 수: 411
- 고친 횟수: 19
- 크기: 작음 — 한 프로세스 안의 단위 확인(임시 git init 하나만 있다)
- 종류: 섞임(동작 약 55 · 구조 4 · 글자 2 · 변이 0)
- 지키는 것: 레포 설정 해결자가 머리말을 엄격히 읽고(BOM · 중복 키 · 따옴표 밖 #), 위험한 폴더 값(.git · 절대 경로 · .. · glob 글자)을 거절하고, human_gate · state_branch 가 정확한 낱말과 레포 설정으로만 꺼지며 환경 변수로는 꺼지지 않는다.
- 거짓 실패 위험: 중간 — 키 개수(15) · README 표 행 · 마지막 키 이름을 핀해 키를 더할 때 같이 고쳐야 한다
- 겹침: plugins/spec-distill/tests/test_repo_defaults_git.sh — 같은 스크립트의 git 쪽 읽기(해결 · check-path), 폴더 값 거절 몇 줄이 겹친다
- 보안 갈래: 예 — 경로 탈출 거절 · 게이트를 끄는 길(환경 변수 불가)
- 판정 후보: 둠 — 싸고 동작을 직접 재며 보안 경계를 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_repo_defaults_git.sh
- 초: 6.2
- 줄 수: 304
- 고친 횟수: 10
- 크기: 중간 — 임시 레포를 열네 개 안팎(원격 bare 포함) 만들고 repo_defaults.py 를 약 100번 부른다(추정)
- 종류: 동작
- 지키는 것: 설정 파일을 작업 트리가 아니라 기본 브랜치 판에서 읽고, 깨진 설정 · 링크 · LFS 포인터 · 레포 밖은 조용히 기본값으로 가지 않고 rc 3 을 내며, check-path · roadmap-check 가 폴더 밖 경로를 거절한다.
- 거짓 실패 위험: 중간 — 한국어 사유 문구를 부분 문자열로 핀하고, 대소문자 가리는 파일시스템 분기가 있다
- 겹침: plugins/spec-distill/tests/test_repo_defaults.py — 폴더 값 거절 · 층 합치기 일부
- 보안 갈래: 예 — 링크 설정 파일 거부 · 레포 밖 경로 거절 · 작업 트리 값 불채택
- 판정 후보: 구조를 고침 — 케이스마다 mkrepo(init + bare + push)를 새로 하는데, 읽기 전용 케이스는 레포 하나를 함께 쓸 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_request_framing_entry.sh
- 초: 0.9
- 줄 수: 241
- 고친 횟수: 16
- 크기: 중간 — 임시 git 레포 셋(base 펜스 · 커밋 펜스 둘)을 만들어 SKILL 의 펜스를 실제로 돌린다
- 종류: 섞임(동작 10 · 구조 3 · 글자 35 · 변이 1)
- 지키는 것: request-framing 의 커밋 펜스가 seed · audit 두 경로만 커밋하고(이미 stage 된 다른 파일을 쓸어 담지 않고) 인터뷰 폴더가 다르면 멈추며, base 펜스가 origin/HEAD 가 없을 때 「확인 못함」을 낸다 — 진입 단계의 kill switch · 포인터 문장은 글자만 지킨다.
- 거짓 실패 위험: 높음 — SKILL 문장 정규식을 많이 핀한다(파일 머리가 스스로 부분 문자열 검사의 한계를 밝힌다)
- 겹침: plugins/spec-distill/tests/test_seed_gate_wiring.sh · test_framing_review_contract.sh · test_end_gates.sh — 같은 SKILL.md 를 대는 것으로 보이나 내용은 열어 보지 않음
- 보안 갈래: 예 — kill switch 이름 공시, 경로 지정 커밋
- 판정 후보: 줄임 — 펜스를 실제로 돌리는 부분은 남기고 AC11 · AC12 의 산문 정규식 서른 개 남짓은 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_request_framing_open.sh
- 초: 0.8
- 줄 수: 170
- 고친 횟수: 10
- 크기: 중간 — 웹 펜스를 값마다 새 셸(bash · zsh)로 열댓 번 돌리고 원자료 펜스 · check_seed 를 돈다
- 종류: 섞임(동작 25 · 구조 3 · 글자 45 · 변이 3)
- 지키는 것: 이름 조회 웹 스위치가 정확히 "1" 일 때만 꺼지고(yes · 0 · 빈 값 · 01 은 안 꺼진다) 원자료 판결 펜스가 기록 파일이 없어도 멈추지 않으며, 이름 조회 URL 줄이 있는 audit 으로 check_seed 가 막히지 않는다.
- 거짓 실패 위험: 중간 — 펜스 실행은 동작이 바뀔 때만 깨지나, 정본 문단 리터럴 수십 개는 문장 다듬기에 깨진다
- 겹침: plugins/spec-distill/tests/test_web_kill_switch.sh — 같은 웹 스위치를 지키는 것으로 보이나 확인 못 함
- 보안 갈래: 예 — 웹 kill switch 의 집행(값마다 실행)
- 판정 후보: 둠 — 스위치를 실제로 실행해 재는 비싸지 않은 락이다. 산문 리터럴이 많지만 0.8초라 이득이 작다
- 확신: 중간

### plugins/spec-distill/tests/test_rereview_cap_consistency.sh
- 초: 0.2
- 줄 수: 191
- 고친 횟수: 17
- 크기: 작음 — 정본 · 엔진 상수 · SKILL · README · 철학 문서 grep 뿐
- 종류: 섞임(동작 0 · 구조 12 · 글자 3 · 변이 0)
- 지키는 것: 재리뷰 상한 숫자가 정본 문서 · 엔진 기본값 · SKILL · README 에서 갈라지지 않아(사용자가 읽는 상한과 실제로 도는 상한이 다르지 않아) 어느 한 곳만 고쳐도 소리가 난다.
- 거짓 실패 위험: 중간 — 상한 어휘 정규식 밖의 표기는 못 잡고, README 에 같은 문구가 둘 이상 있어야 통과한다
- 겹침: 못 찾음 — rereview_cap 을 대상 이름으로 찾은 테스트는 이 파일뿐(나머지는 픽스처)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 값을 도출해 ∀ 로 재는 구조 락이고 싸다
- 확신: 높음

### plugins/spec-distill/tests/test_research_agents_frontmatter.sh
- 초: 0.5
- 줄 수: 175
- 고친 횟수: 12
- 크기: 작음 — agent 파일 읽기 · grep · 파일마다 PyYAML 파서 한 번(python 네 번)
- 종류: 섞임(동작 0 · 구조 40 · 글자 55 · 변이 0)
- 지키는 것: 조사 · 판정 agent 넷이 읽기 전용 도구 allowlist(Law 2)와 정해진 입력 슬롯 · 출력 키를 갖고, open-researcher 가 비신뢰 입력을 따르지 않고 웹 쿼리에 레포 내용 · 비밀값을 싣지 않으며, 포화 판정자가 묶음 단위 규칙을 지킨다.
- 거짓 실패 위험: 높음 — saturation-judge 의 규칙 문장을 통째로 핀한다(문장을 다듬으면 깨진다)
- 겹침: plugins/spec-distill/tests/test_saturation_reference.sh — 포화 판정의 두 묶음 기준을 양쪽이 각자 문장으로 잰다
- 보안 갈래: 예 — agent tools allowlist · 웹 쿼리 비밀 유출 금지 · 비신뢰 입력
- 판정 후보: 둠 — persona 파일을 지키는 보안 락이다. saturation 문장 핀만 test_saturation_reference.sh 와 나중에 합칠 만하다
- 확신: 중간

### plugins/spec-distill/tests/test_research_claims_contract.sh
- 초: 0.2
- 줄 수: 233
- 고친 횟수: 13
- 크기: 중간 — 계약 펜스를 차가운 셸에서 네 번(plain · errexit × 실재 · 부재 루트) 돌린다
- 종류: 섞임(동작 16 · 구조 6 · 글자 12 · 변이 0)
- 지키는 것: 조사 주장 계약이 경로가 아니라 내용으로 dispatch 에 실리고(설치본에서 Read 가 막혀도), 계약이 없으면 dispatch 하지 않고 rc 1 로 멈추며, 정본과 steelman-builder 사본의 필드 집합이 같고 처분 줄이 모두 fail-closed 다.
- 거짓 실패 위험: 중간 — 슬롯 개수(4 · 1)와 처분 줄 수(3 이상)를 핀해 dispatch 자리를 더하면 같이 고쳐야 한다
- 겹침: shared/tests/test_dispatch_disposition.sh — 처분 줄의 어휘를 그쪽이 재고 이쪽은 값(fail-closed)을 잰다(파일 머리가 그렇게 말함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 펜스를 실제로 돌려 내용 배달 실패를 잡고 지키는 것이 분명하다
- 확신: 중간

### plugins/spec-distill/tests/test_resume_candidate_names.sh
- 초: 0.3
- 줄 수: 71
- 고친 횟수: 4
- 크기: 중간 — 임시 git 레포 하나에서 진입 펜스를 여러 번 새 셸로 돌린다
- 종류: 섞임(동작 4 · 구조 0 · 글자 6 · 변이 0)
- 지키는 것: 이어 갈 후보 파일 이름에 작은따옴표 · 세미콜론으로 심은 명령이 있어도 후보로 나오지 않고 셸 리터럴에 붙어 실행되지 않는다(PWNED 가 생기지 않는다).
- 거짓 실패 위험: 낮음 — 이름 걸러내기 동작이 바뀔 때만 깨진다(문서 문장 핀 몇 개만 문구에 민감)
- 겹침: 못 찾음 — 후보 이름 심기를 재는 다른 테스트를 찾지 못했다(test_interview_state_flow.sh 는 같은 펜스를 쓰나 이 주제는 아님)
- 보안 갈래: 예 — 주입(셸 리터럴에 심은 이름)
- 판정 후보: 둠 — 주입을 직접 재현하는 짧고 분명한 보안 락이다
- 확신: 높음

### plugins/spec-distill/tests/test_review_entry.py
- 초: 0.7
- 줄 수: 173
- 고친 횟수: 3
- 크기: 중간 — review_entry.py 를 케이스마다 하위 프로세스로 약 30번 띄운다(환경을 새로 짠다)
- 종류: 동작
- 지키는 것: 리뷰 진입의 끄기 판정(전역 스위치 · 토큰 · 설계 모드 스위치 · =0 은 안 끔)이 맞고, 은퇴한 스위치를 쓰는 사용자에게 「더 이상 끄지 않는다」를 정확히 알리며 살아 있는 스위치만 권한다.
- 거짓 실패 위험: 낮음 — 판정이나 공시 메시지가 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh — 같은 review_entry.py 를 진입 펜스에서 실행한다(은퇴 토큰 advisory 일부가 겹칠 수 있음, 확인 못 함)
- 보안 갈래: 예 — kill switch 판정과 은퇴 스위치 공시
- 판정 후보: 둠 — kill switch 집행을 실행으로 재는 락이고 0.7초로 싸다
- 확신: 높음

### plugins/spec-distill/tests/test_review_handoff_order.sh
- 초: 0.6
- 줄 수: 266
- 고친 횟수: 30
- 크기: 작음 — 문서 grep · awk 와 순서 확인용 python 몇 번
- 종류: 섞임(동작 4 · 구조 8 · 글자 80 · 변이 1)
- 지키는 것: interview 의 다음 세션 줄과 brief §7 · spec-review description 이 brainstorming → spec-review → writing-plans 순서와 게이트 없는 종료의 복귀 지시를 싣고, 정지 요건이 있다 — 옛 지시 문장 열다섯 · 네 개를 글자 그대로 핀하는 부분은 글자만 지킨다.
- 거짓 실패 위험: 높음 — 지시 문장 열다섯을 순서까지 등호로 핀한다(30번 고쳐진 것이 그 증거)
- 겹침: plugins/spec-distill/tests/test_end_gates.sh — 파일이 스스로 같은 글자라고 밝힌 문장(있는 것 검토 괄호 · 마지막 전체 리뷰 구절)과 gate 표; test_plain_gate_templates.sh · test_conducting_interview_stage.sh 도 brief-handoff.md 를 댄다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 지시 문장 일부를 test_end_gates.sh 와 같은 글자로 이중으로 핀한다. 한쪽으로 모으면 문장 하나를 고칠 때 한 곳만 고치면 된다
- 확신: 중간

### plugins/spec-distill/tests/test_review_hook_removed.py
- 초: 4.2
- 줄 수: 480
- 고친 횟수: 11
- 크기: 중간 — 삭제된 파일의 옛 판을 git show 로 읽고 도출한 이름(백 개 안팎, 추정)마다 git grep 을 하위 프로세스로 돌린 뒤 리포 전체를 정규식으로 훑는다
- 종류: 섞임(동작 0 · 구조 8 · 글자 8 · 변이 0)
- 지키는 것: 삭제한 리뷰 훅 · 스크립트의 이름이 현재형 문서 · 코드에 남아 거짓 인용이 되지 않고, 삭제 파일이 다시 생기지 않으며 spec-review 가 옛 입력 계약을 되살리지 않는다.
- 거짓 실패 위험: 중간 — 새 문서가 도출된 이름과 같은 낱말을 쓰면 깨지고, 기준 커밋 c7b4f580 이 없는 얕은 클론에서는 RED 다
- 겹침: plugins/spec-distill/tests/test_reviewing_spec_design_only.sh — 옛 모드 슬롯($mode · mode: design|spec) 부재를 양쪽이 재는 자리가 있다(test_old_input_contract_absent)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 실행 때마다 옛 판에서 이름 집합을 도출하고 이름마다 git grep 을 부른다. 한 번 도출한 목록을 파일로 두거나 git grep -f 한 번으로 모으면 4초가 줄 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_reviewing_brief_skill.sh
- 초: 1.1
- 줄 수: 509
- 고친 횟수: 50
- 크기: 중간 — 게이트 펜스를 스텁 검사기로 열두 번 가까이 돌리고 python 으로 엔진 GATE_ROWS 를 읽는다
- 종류: 섞임(동작 14 · 구조 30 · 글자 150 · 변이 0)
- 지키는 것: reviewing-brief 의 진입 게이트 펜스가 검사 실패에서 멈추고 건너뛰기를 변수 + 오늘 날짜 · 같은 rc 의 증거 줄이 있을 때만 허용하며, 순서(의존 → 구조 게이트 → 완전성 → 번들 → codex)와 agent tools(웹 없는 사본 · 웹 사본)가 공시와 같다.
- 거짓 실패 위험: 높음 — SKILL 문장 리터럴 백오십 개를 핀한다(50번 고쳐짐)
- 겹침: plugins/spec-distill/tests/test_reviewing_brief_residue.sh · test_brief_agents.sh · test_web_kill_switch.sh — 같은 SKILL · 프로필을 대는 것으로 보이나 내용은 열어 보지 않음. README 의 G1–G6 범위는 test_readme_sync.sh 와 겹친다
- 보안 갈래: 예 — 건너뛰기 증거 위조 방지 · kill switch 공시 · agent tools allowlist
- 판정 후보: 줄임 — 펜스 실행(건너뛰기 증거 · rc 표)과 사실 대조는 남기고 산문 리터럴 목록(게이트 문면 · 건너뜀 절 열다섯 줄)은 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_reviewing_spec_design_only.sh
- 초: 0.1
- 줄 수: 94
- 고친 횟수: 15
- 크기: 작음 — SKILL grep 과 디렉터리 순회
- 종류: 섞임(동작 0 · 구조 4 · 글자 8 · 변이 0)
- 지키는 것: spec-review 가 design-doc 프로필 하나만 고르고 옛 모드 슬롯 · re-consensus · drafting-spec 이 되살아나지 않는다 — 대부분 되살아나면 안 되는 낱말의 부재다.
- 거짓 실패 위험: 중간 — 낱말 부재와 `고정` 문장 정규식이라 SKILL 문장을 고칠 때 깨질 수 있다
- 겹침: plugins/spec-distill/tests/test_review_hook_removed.py — 옛 모드 슬롯 부재를 같이 재고, plugins/spec-distill/tests/test_reviewing_brief_skill.sh 의 5절이 같은 「다른 프로필을 안 부른다」 도출을 brief 쪽에서 한다
- 보안 갈래: 아니오
- 판정 후보: 합침 — 옛 모드 슬롯 부재는 test_review_hook_removed.py 가 이미 재므로 프로필 도출 확인만 남기고 한쪽으로 모을 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh
- 초: 0.1
- 줄 수: 75
- 고친 횟수: 4
- 크기: 작음 — SKILL grep 뿐
- 종류: 글자
- 지키는 것: spec-review 표면이 codex kill switch · 전역 kill switch 이름과 「dispatch 직전에 확인하고 캐시하지 않는다」를 사용자에게 공시하고 degrade 채널 이름을 댄다 — 사용자가 끌 수 있다는 사실을 알 길이다.
- 거짓 실패 위험: 중간 — 공시 문장과 채널 이름이 바뀌면 깨진다
- 겹침: 확인 못 함 — test_reviewing_spec_residue.sh 가 같은 SKILL 의 fence 쪽을 잰다고 파일 머리가 밝히나 열어 보지 않음
- 보안 갈래: 예 — kill switch 공시
- 판정 후보: 둠 — 끄는 스위치의 공시를 지키고 0.1초다(파일 머리가 집행 락과의 역할 구분을 밝힌다)
- 확신: 중간

### plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh
- 초: 0.1
- 줄 수: 96
- 고친 횟수: 18
- 크기: 작음 — SKILL 정규식 grep 뿐
- 종류: 글자
- 지키는 것: spec-review 가 엔진 상태 디렉터리를 문서마다 따로(루트 · 문서 경로에서 도출) 만들고 STATE_DIR · CODEX_YAML 대입이 전부 그 도출을 거치게 적혀 있다 — 두 문서가 원장을 섞어 쓰지 않는 것을 SKILL 줄 모양으로 확인한다.
- 거짓 실패 위험: 높음 — 대입 줄을 끝까지 고정한 정규식이라 줄 하나를 고치기만 해도 깨진다(18번 고쳐짐)
- 겹침: 확인 못 함 — 도출이 문서마다 다른 자리를 내는지는 test_reviewing_spec_residue.sh 의 P 셀이 실행으로 잰다고 이 파일이 밝히나 열어 보지 않음
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 줄 모양 정규식 대신 SKILL 의 STATE_DIR 줄을 임시 루트에서 실행해 문서별 자리가 다른지 보는 동작 확인으로 내릴 수 있다(residue 락과 합칠 후보)
- 확신: 중간

### plugins/spec-distill/tests/test_roadmap_approval.py
- 초: 0.0
- 줄 수: 208
- 고친 횟수: 7
- 크기: 작음 — 한 프로세스, 가짜 git 객체
- 종류: 동작
- 지키는 것: 지휘 기록의 spec 승인 줄을 날짜로 읽되 승인 대기 · 거절 · 철회 같은 부정 줄은 승인으로 읽지 않고, 승인 · 계획 유무로 에픽 단계를 맞게 계산하며, 끝난 에픽의 PR 이 캐시 없이 「알 수 없음」으로 드러난다.
- 거짓 실패 위험: 낮음 — 읽기 규칙이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_model.py — approval_in · approval_date 줄 읽기를 일부 다시 잰다(TeamRoadmap)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 단계 오판(승인 안 된 것을 승인으로 읽음)을 직접 잡고 비용이 0이다
- 확신: 높음

### plugins/spec-distill/tests/test_roadmap_migrate.py
- 초: 0.1
- 줄 수: 269
- 고친 횟수: 6
- 크기: 중간 — 이전 커밋(PRE)의 로드맵을 git show 로 읽어 옮기기를 돌린다(하위 프로세스 약 10회)
- 종류: 섞임(동작 14 · 구조 10 · 글자 0 · 변이 0)
- 지키는 것: roadmap_write migrate 가 옛 범위 한 줄만 새 형식으로 바꾸고 나머지 바이트를 그대로 두며(CRLF 포함) 옮길 수 없으면 거절하고, 이 레포 로드맵이 옮기기 전의 사용자 인용을 하나도 잃지 않았다.
- 거짓 실패 위험: 중간 — 이 레포의 로드맵 이력을 손으로 핀한 표(APPROVALS · NOT_USER_WORDS)가 있어 그 로드맵을 고치거나 PRE 커밋이 없는 얕은 클론에서 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_model.py — 같은 로드맵의 PRE 판을 읽어 옛 해석과 견준다(다른 확인)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — migrate 명령의 단위 확인은 남기되, 한 번 끝난 옮김을 영구히 지키는 LiveRoadmap 의 손으로 핀한 표는 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_roadmap_model.py
- 초: 0.0
- 줄 수: 432
- 고친 횟수: 14
- 크기: 중간 — 한 프로세스지만 옛 판 roadmap_model 을 git show 로 읽어 임시 폴더에서 불러오고 브리프 픽스처를 읽는다
- 종류: 동작
- 지키는 것: roadmap_model 이 하위 항목이 없는 옛 로드맵을 바뀌기 전과 같게 해석하고, 하위 항목 · 선택 칸 · 여러 브랜치 · 재분해 이력 · brief 번호 · 로드맵 판정 · team 형식의 규칙을 맞게 읽고 틀린 입력은 오류로 낸다.
- 거짓 실패 위험: 중간 — 기준 커밋(93be1042)이 없는 얕은 클론에서 깨지고, 파서 오류 문구를 일부 핀한다
- 겹침: plugins/spec-distill/tests/test_roadmap_render.py — 파싱 · 렌더 왕복 일부, plugins/spec-distill/tests/test_roadmap_status.sh(확인 못 함)
- 보안 갈래: 예 — 로드맵 판정이 폴더 밖 · 링크 · LFS · UTF-8 아닌 파일을 읽지 않고 사유를 낸다
- 판정 후보: 둠 — 파서의 동작을 싸게 직접 재는 핵심 락이다
- 확신: 높음

### plugins/spec-distill/tests/test_roadmap_ontology.py
- 초: 0.1
- 줄 수: 179
- 고친 횟수: 8
- 크기: 작음 — 문서 표와 스크립트 소스를 한 프로세스에서 읽는다
- 종류: 섞임(동작 0 · 구조 9 · 글자 1 · 변이 0)
- 지키는 것: 로드맵 객체 문서의 객체 표가 가리키는 주인 스크립트 · 기호 · 링크 이름(칸 · 키)이 실제 코드에 정의돼 있고, 에픽 행이 모든 칸 이름을 댄다 — 문서를 따라가면 코드에 닿는다.
- 거짓 실패 위험: 중간 — 객체 이름 스물여섯을 순서까지 핀해 객체를 더하거나 이름을 바꿀 때 같이 고쳐야 한다
- 겹침: 못 찾음 — roadmap-ontology 를 대상 이름으로 찾은 테스트는 이 파일과 문서 존재를 보는 test_parallel_recommend_docs.sh · test_end_gates.sh 뿐
- 보안 갈래: 아니오
- 판정 후보: 둠 — 코드에서 도출한 집합과 맞추는 구조 락(AST 정의 확인 · 양성 대조)이고 싸다
- 확신: 중간

### plugins/spec-distill/tests/test_roadmap_render.py
- 초: 0.3
- 줄 수: 504
- 고친 횟수: 15
- 크기: 중간 — 한 프로세스지만 이 레포 로드맵 폴더의 파일 십여 개를 읽어 묶음 · 블록을 다시 만들어 바이트를 견준다
- 종류: 동작
- 지키는 것: 분해안 표 · 블록 · 묶음 · 로드맵 글의 렌더링이 왕복해도 같고, 이 레포 로드맵에서 만든 묶음 · 블록이 손으로 쓴 파일과 바이트가 같으며 team 형식의 표 · 번호 파일을 맞게 읽는다.
- 거짓 실패 위험: 중간 — 살아 있는 로드맵(이 레포)을 손으로 고치면 골든 대조가 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_render_r2.py — §4 · §6 렌더 일부, plugins/spec-distill/tests/test_roadmap_status.sh(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 렌더링 동작을 직접 재고 비용이 0.3초다
- 확신: 중간

### plugins/spec-distill/tests/test_roadmap_render_r2.py
- 초: 0.0
- 줄 수: 156
- 고친 횟수: 1
- 크기: 작음 — 한 프로세스, 문자열 픽스처
- 종류: 동작
- 지키는 것: R2 형식 brief 의 사용자 원문 §6 이 S1~Sn 을 한 번씩만 싣고(중복 없이) §4 여러 줄 항목이 머리 줄과 본문 줄을 한 덩어리로 싣고 게이트가 보는 항목과 같다.
- 거짓 실패 위험: 낮음 — 렌더링 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_render.py — Section4RcIndex 가 §4 항목 색인을 일부 다시 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 짧고 직접적이며 한 번 고쳐졌을 뿐이다
- 확신: 높음

### plugins/spec-distill/tests/test_roadmap_status_merge_base.py
- 초: 0.0
- 줄 수: 92
- 고친 횟수: 1
- 크기: 작음 — 한 프로세스, 가짜 Git 서브클래스
- 종류: 동작
- 지키는 것: merge-base 를 못 읽은 것(오류 · 얕은 클론)을 「설계 중」으로 읽지 않고 「알 수 없음」과 종료 코드 3 으로 드러낸다 — 공통 조상이 없는 정상 경우는 실패로 세지 않는다.
- 거짓 실패 위험: 낮음 — 판정 규칙이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_approval.py — Progress.test_unread_merge_base_is_unknown_not_designing 이 git 오류 한 갈래를 같이 잰다(얕은 클론 · rc 1 · exit code 는 이쪽만)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 비용이 0이라 합쳐도 시간이 줄지 않고, 얕은 클론 · 종료 코드 갈래는 이쪽만 갖는다
- 확신: 중간

### plugins/spec-distill/tests/test_roadmap_write.py
- 초: 0.0
- 줄 수: 108
- 고친 횟수: 5
- 크기: 작음 — 임시 폴더 하나(Txn 케이스) 외엔 문자열
- 종류: 동작
- 지키는 것: roadmap_write 가 점검 결과 JSON 에서 형식 오류 · 미배정 · 고아 · 모르는 번호가 하나라도 있거나 셀 수 없으면 되돌릴 사유로 판정하고(블록 경고는 되돌리지 않고), 되돌리기가 바이트와 권한을 복원하며 생성 기록을 왕복한다.
- 거짓 실패 위험: 낮음 — 판정 · 복원 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_write_atomic.py — Txn 되돌리기를 다른 면(짧은 쓰기)에서 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 로드맵을 쓰다 실패했을 때 사용자 파일이 망가지지 않게 하는 직접 확인이다
- 확신: 높음

### plugins/spec-distill/tests/test_roadmap_write_atomic.py
- 초: 0.0
- 줄 수: 79
- 고친 횟수: 1
- 크기: 작음 — 임시 폴더 하나, os.write 를 바꿔 끼운 가짜 디스크
- 종류: 동작
- 지키는 것: 디스크가 거의 찬 짧은 쓰기를 다 쓴 것으로 바꿔 놓지 않아 원래 로드맵이 잘리지 않고 임시 파일이 남지 않으며, 되돌리기도 짧은 쓰기에서 파일을 자르지 않는다.
- 거짓 실패 위험: 낮음 — 쓰기 길이 처리가 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_write.py — Txn 되돌리기를 정상 경로에서 잰다(이쪽은 짧은 쓰기)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 사용자 문서가 잘리는 데이터 손실을 직접 재현하는 싸고 분명한 락이다
- 확신: 높음

### plugins/spec-distill/tests/test_saturation_reference.sh
- 초: 0.4
- 줄 수: 200
- 고친 횟수: 14
- 크기: 작음 — 문서 grep · awk 위주에 상한 값 펜스를 새 셸에서 일곱 번 돈다
- 종류: 섞임(동작 9 · 구조 3 · 글자 85 · 변이 0)
- 지키는 것: 조사 상한 값 펜스가 이상한 값(0 · 00 · 음수 · 문자)을 기본값으로, 앞자리 0 을 10진으로 바꿔 쓴다 — 나머지(조사 상한 · 포화 판정 절의 문장 · audit §2 줄 모양 · 건너뜀 규칙)는 글자만 지킨다.
- 거짓 실패 위험: 높음 — 포화 판정 절의 문장 리터럴 구십 개 안팎을 핀한다(문구 다듬기에 깨진다)
- 겹침: plugins/spec-distill/tests/test_research_agents_frontmatter.sh — saturation-judge 의 두 묶음 · 실패 조사 규칙을 양쪽이 각자 문장으로 잰다. shared/tests/test_window_phrases.sh 는 확인 못 함
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 펜스 실행(상한 값)은 남기고 산문 리터럴의 대부분은 줄일 수 있다. audit §2 줄 모양은 게이트(check_brief.py)가 읽는 글자라 그것만 남긴다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_agents.sh
- 초: 0.1
- 줄 수: 197
- 고친 횟수: 10
- 크기: 작음 — agent 파일 · SKILL 의 grep · awk(펜스마다 짝 비교)
- 종류: 구조
- 지키는 것: seed-readback agent 가 도구 표면 0(`tools: []`, Read 도 없음)이라 seed 만 보는 냉독이 성립하고, SKILL 의 모든 dispatch 펜스가 description 이 약속한 <태그>${변수} 쌍만 실어 초안이 새지 않는다.
- 거짓 실패 위험: 낮음 — agent 도구나 dispatch 펜스의 쌍이 바뀔 때만 깨진다(주석이 길지만 단언은 구조다)
- 겹침: shared/tests/test_dispatch_disposition.sh — dispatch 로 세는 정의를 물려받는다고 밝힌다. plugins/spec-distill/tests/test_dispatch_profile_inline.sh 와의 겹침은 확인 못 함
- 보안 갈래: 예 — 리뷰어 tools allowlist · 격리 채널
- 판정 후보: 둠 — Law 2 의 집행 지점과 격리 채널을 구조로 재는 보안 락이다
- 확신: 높음

### plugins/spec-distill/tests/test_seed_at_path_handoff.sh
- 초: 0.3
- 줄 수: 223
- 고친 횟수: 21
- 크기: 작음 — 문서 grep · awk 위주에 case 패턴을 bash -c 로 몇 번 돈다
- 종류: 섞임(동작 8 · 구조 8 · 글자 100 · 변이 0)
- 지키는 것: pm-interview 문서 어디에도 원 인자 토큰($ARGUMENTS)이 남지 않아 플랫폼이 @경로 문자열을 대신 끼워 넣지 않고, 이름 가드가 공백 · 탭 · 자리표 이름을 거절한다 — 정본 proceed-gate 와 skill 표의 문장은 글자만 지킨다.
- 거짓 실패 위험: 높음 — proceed-gate 정본 · 지휘자 아래 승인 질문 문장을 수십 개 핀하고 21번 고쳐졌다
- 겹침: plugins/spec-distill/tests/test_proceed_gate_adopters.sh · test_plain_gate_templates.sh · test_request_framing_open.sh — proceed-gate.md 의 같은 단락을 각자 문장으로 잰다(내용 겹침은 열어 보지 않음)
- 보안 갈래: 예 — 이름 가드(공백 · 탭 거부)와 원 인자 토큰 부재
- 판정 후보: 줄임 — 부재 코퍼스 · 이름 가드 실행은 남기고 정본 단락 문장 핀(Step B · 가드 · 지휘자 아래)은 다른 proceed-gate 락과 겹치는 만큼 덜 수 있다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_body_placeholder.py
- 초: 0.0
- 줄 수: 54
- 고친 횟수: 2
- 크기: 작음 — 한 프로세스(임시 폴더 하나로 gate 를 한 번 돈다)
- 종류: 동작
- 지키는 것: seed 문법이 줄 안의 가림 표시(<REDACTED:…> 등)는 산문으로 받고, 줄 머리 · URL · 도메인 · 대괄호 · 다른 꺾쇠(<b> 등)는 그대로 거절하며 gate 가 구조 문제를 내지 않고 marks 가 rc 0 이다.
- 거짓 실패 위험: 낮음 — seed 문법이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_seed_grammar_crosscheck.py — 같은 AUDIT · STRUCT_GATE 를 가져다 쓰는 형제. seed_body.py 는 test_grammar_vs_markdown_it.sh · test_seed_provenance.sh 도 댄다(내용은 확인 못 함)
- 보안 갈래: 예 — seed 에 마크업 · URL 이 들어오는 길의 거절
- 판정 후보: 둠 — 허용 목록 문법을 입력 꼴로 직접 재고 0초다
- 확신: 높음

### plugins/spec-distill/tests/test_seed_codex_axes.sh
- 초: 0.1
- 줄 수: 61
- 고친 횟수: 9
- 크기: 작음 — 파일 존재 확인 · 링크 해석 python 두 번 · SKILL grep 다섯 번
- 종류: 섞임(동작 0 · 구조 9 · 글자 5 · 변이 0)
- 지키는 것: seed 전용 리뷰 파일 넷이 되살아나지 않고(이름을 바꿔 되살린 것도 글롭으로), 엔진 러너 · 라우터 배포 링크가 정본을 가리키며 request-framing SKILL 이 엔진 러너 · 탐지기 · 재비판기 · 처분 소비자를 실제로 댄다.
- 거짓 실패 위험: 중간 — SKILL 의 러너 호출 줄 · 마커 모양을 글자로 핀한다
- 겹침: 확인 못 함 — 같은 SKILL 의 배선을 test_seed_gate_wiring.sh · test_framing_review_contract.sh 가 잴 것으로 보이나 열어 보지 않음. 삭제 파일 부재는 test_review_hook_removed.py 와 같은 부류
- 보안 갈래: 아니오
- 판정 후보: 둠 — 싸고 구조 확인이지만 겹침을 못 열어 봐 줄임이나 합침이 맞는지 판단하지 못했다
- 확신: 낮음

#### 읽지 못한 것 — shallow-08

- 없음 — 서른두 파일을 모두 끝까지 읽었다. 다만 「겹침」 칸에서 「확인 못 함」으로 적은 것은 대상 이름을 grep 해 이름만 확인했고 그 형제 테스트(test_end_gates.sh · test_reviewing_spec_residue.sh · test_seed_gate_wiring.sh · test_framing_review_contract.sh · test_web_kill_switch.sh 등)의 내용은 열지 않았다. 「초」 칸 값은 묶음 파일을 그대로 옮겼고, 「시간을 쓰는 곳」을 가리킨 크기 칸의 판단은 읽어서 한 추정이다(실행하지 않았다).

## 묶음 shallow-09

### plugins/spec-distill/tests/test_seed_cut_table.sh
- 초: 0.7
- 줄 수: 100
- 고친 횟수: 2
- 크기: 중간 — check_seed · seed_provenance · build_seed_inline_blob 를 하위 프로세스로 약 20번 띄운다(임시 폴더)
- 종류: 섞임(동작 90 · 구조 0 · 글자 10 · 변이 0)
- 지키는 것: seed 감사 파일의 「덜어 낸 것」 표가 없거나 머리 행뿐이면 게이트가 막고, 확인 표시가 「다시 검증할 것 —」 문단 안에서도 확인 풀이에 맞게 따라가며, 리뷰 번들이 그 표를 싣는다.
- 거짓 실패 위험: 낮음 — 게이트 동작이 바뀔 때만 깨진다(오류 문구는 절 이름 · 「표 행도」 한 구절만 본다)
- 겹침: plugins/spec-distill/tests/test_check_seed.sh — check_seed 게이트 일반 · test_seed_provenance.sh — classify · marks · test_seed_inline_blob.sh — 번들이 싣는 재료 (이 파일은 덜어 낸 것 절 한 건만 보태서 부분 겹침)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0.7초에 새 절(덜어 낸 것 표)의 게이트 · 번들 · 분류를 한 흐름으로 지키고 중복이 적다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_edit_diff.sh
- 초: 2.2
- 줄 수: 210
- 고친 횟수: 4
- 크기: 중간 — seed_edit_diff.py 를 python 하위 프로세스로 약 70번 띄우고 변이 사본 하나를 만든다
- 종류: 섞임(동작 95 · 구조 0 · 글자 0 · 변이 5)
- 지키는 것: 저자가 seed 를 고친 것을 공시할 때 기준 사본이 공시될 때까지 덮이지 않고, 되돌리기 · 수락이 공시된 판본에만 묶이며(그 뒤 seed 가 바뀌면 rc 4), 같은 공시에서 같은 되돌리기를 되풀이해도 번호가 밀려 엉뚱한 덩어리를 되돌리지 않는다.
- 거짓 실패 위험: 낮음 — rc · 파일 바이트 · 렌더 전체 문자열을 보지만 모두 스크립트 동작을 고정한다(렌더 문자열을 바꾸면 깨짐)
- 겹침: plugins/spec-distill/tests/test_seed_edit_screen.sh · test_state_dir_writes.sh · test_framing_review_contract.sh — 같은 스크립트 이름을 다루나 이 파일이 동작 정본(내용 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 사용자 편집을 잃거나 엉뚱한 덩어리를 되돌리는 사고를 막는 동작 확인이고 변이 짝도 있다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_grammar_crosscheck.py
- 초: 4.1
- 줄 수: 411
- 고친 횟수: 6
- 크기: 중간 — 같은 프로세스에서 수백 입력 × 읽는 쪽 셋을 돌리고 CLI 는 표본 25 + audit 줄나눔 32건에서 build 스크립트를 하위 프로세스로 부른다(임시 폴더)
- 종류: 동작
- 지키는 것: seed 본문 · audit `## 6` 을 읽는 모든 쪽(문법 · 게이트 · marks · classify · user-quotes · check-drops · 번들)이 같은 입력에 같은 판정(정직한 산문은 받고 구조 · 보이지 않는 글자 · 링크 · HTML 은 거부)을 내서, 한 쪽만 우회되는 틈이 안 생긴다.
- 거짓 실패 위험: 중간 — 허용 문법을 일부러 바꾸면 깨지고 유니코드 범주표(미할당 글자 등)가 유니코드 판에 흔들릴 수 있다
- 겹침: plugins/spec-distill/tests/test_seed_trust_boundary.sh · test_check_seed.sh · test_r2_bypass_residue.py — 같은 읽는 쪽들의 개별 우회 케이스(손으로 적은 목록)
- 보안 갈래: 예
- 판정 후보: 둠 — 손으로 적은 우회 목록보다 생성 코퍼스 교차 대조가 우회를 넓게 잡고 4초면 값에 맞다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_inline_blob.sh
- 초: 1.7
- 줄 수: 392
- 고친 횟수: 16
- 크기: 중간 — build_seed_inline_blob.py 를 약 40번 띄우고 변이 사본 둘 · scripts 폴더 사본 하나 · 임시 git 레포 하나를 만든다
- 종류: 섞임(동작 80 · 구조 0 · 글자 5 · 변이 15)
- 지키는 것: seed 리뷰 번들이 재료 여섯을 순서대로 싣고, 재비판 번들에는 판정 이력이 한 줄도 새지 않으며, 비신뢰 `## 1` 안의 가짜 제목이 절을 자르거나 진짜 절을 가로채지 못하고, 「CLAUDE.md 없음」 경고가 한 라운드에 한 번만 난다.
- 거짓 실패 위험: 중간 — 번들 펜스의 호출 줄 두 개를 SKILL.md 에서 grep 으로 떠 오므로 skill 문면 · 플래그 이름을 고치면 깨진다
- 겹침: plugins/spec-distill/tests/test_seed_gate_wiring.sh · test_framing_review_contract.sh · test_seed_trust_boundary.sh — 번들 조립기를 부른다(내용 겹침은 확인 못 함); test_seed_cut_table.sh — 덜어 낸 것 절 한 건
- 보안 갈래: 예
- 판정 후보: 둠 — 재비판자의 프레이밍 차단(AC11)과 비신뢰 원문 가로채기 방어를 실행으로 지키고, 변이로 이빨도 확인한다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_input_provenance.sh
- 초: 0.2
- 줄 수: 53
- 고친 횟수: 7
- 크기: 중간 — grep · awk 위주에 classify 를 python 으로 두 번 부른다
- 종류: 섞임(동작 15 · 구조 0 · 글자 85 · 변이 0)
- 지키는 것: 규약대로 classify 가 사용자 원문 문장은 사용자 출처로, 저자 문장은 저자 출처로 가르고 audit 이 없으면 그 사실을 낸다(마지막 세 단언뿐); 앞의 열네 단언은 seed-input.md · pm-interview SKILL 의 표 · 문구 존재를 확인한다.
- 거짓 실패 위험: 높음 — 표 행 · 문구 한 줄을 다듬거나 SKILL 의 Read 줄 모양을 바꾸기만 해도 깨진다
- 겹침: plugins/spec-distill/tests/test_seed_provenance.sh — classify 의 사용자 · 저자 가름과 audit 부재 처리를 같은 내용으로 이미 잰다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 동작 세 단언은 test_seed_provenance.sh 가 이미 잰다; 문서 표 · 문구 grep 은 글자만 지킴이라 줄이거나 지울 후보
- 확신: 중간

### plugins/spec-distill/tests/test_seed_one_sentence.sh
- 초: 0.2
- 줄 수: 58
- 고친 횟수: 2
- 크기: 중간 — check_seed.py 게이트를 python 하위 프로세스로 세 번 부른다
- 종류: 동작
- 지키는 것: 한 문장뿐인 seed · 6자 최소 seed 도 게이트를 통과해서(본문 슬롯 존재 검사가 들어오면 깨짐) seed 게이트가 양식으로 변질되지 않는다; URL seed 는 막혀 게이트가 살아 있음을 같은 자리에서 증명한다.
- 거짓 실패 위험: 낮음 — 게이트에 슬롯 검사가 생길 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_check_seed.sh — 같은 게이트의 일반 케이스(이 파일은 「금지」를 재는 유일한 락으로 보임; 겹침 내용은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0.2초에 게이트가 양식이 되는 변질 경로를 지키는 양성 대조 있는 락
- 확신: 높음

### plugins/spec-distill/tests/test_seed_provenance.sh
- 초: 2.0
- 줄 수: 529
- 고친 횟수: 13
- 크기: 중간 — seed_provenance.py 를 python 으로 약 45번 띄우고 변이 사본 셋(형제 모듈 사본 포함)을 만든다
- 종류: 섞임(동작 90 · 구조 0 · 글자 0 · 변이 10)
- 지키는 것: 압축이 고친 문장에서는 «(사용자 확인)» 이 떨어지고 글자 그대로 남은 문장에서는 유지되며, audit 이 못 믿을 꼴(제목 중복 · 절 누락 · 풀이 줄 0 · 모양 어긋난 풀이 줄)이면 판단을 거부하고(rc 2) 비신뢰 요청문의 `$( )` 같은 글자를 stderr 로 옮기지 않는다.
- 거짓 실패 위험: 중간 — stderr 전문 동등 단언(안내 문구를 고치면 깨짐 — 의도된 핀)과 템플릿 풀이 줄 모양 도출에 의존한다
- 겹침: plugins/spec-distill/tests/test_seed_input_provenance.sh — classify · test_seed_cut_table.sh — marks 꼬리 · test_seed_grammar_crosscheck.py — 같은 marks · classify 의 거부 대조
- 보안 갈래: 예
- 판정 후보: 둠 — 사용자 확인 표시가 근거 없이 남는 것(AC13)과 비신뢰 글자의 셸 주입 경로를 실행으로 지킨다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_review_log.sh
- 초: 2.8
- 줄 수: 350
- 고친 횟수: 13
- 크기: 중간 — seed_review_log.py 를 python 으로 약 70번 띄우고 엔진 왕복(docreview_state init · begin-round · route · finalize · gate)과 변이 사본 넷을 만든다
- 종류: 섞임(동작 85 · 구조 0 · 글자 3 · 변이 12)
- 지키는 것: 엔진이 audit `## 6` 에 쓴 결정 기록 줄을 이 파서가 읽어서(엔진 왕복), 문구 없는 drop 이 막히고 사용자 문구만 재비판자에게 가며, 문구 안에 심은 엔진 줄 모양 · 줄 나눔 글자가 가짜 기록이 되거나 진짜 기록을 삼키지 못한다.
- 거짓 실패 위험: 중간 — 엔진 결정 기록 줄 모양에 결합돼 있어 엔진이 줄 모양을 바꾸면 깨진다(의도된 결합 소리)
- 겹침: plugins/spec-distill/tests/test_seed_grammar_crosscheck.py — `## 6` 줄 문법 교차 대조 · test_seed_trust_boundary.sh · test_check_verbatim_coverage.sh — 같은 파서
- 보안 갈래: 예
- 판정 후보: 둠 — AC12(문구 없는 drop 차단) · 심은 줄 방어 · 엔진 결합을 동작으로 지키고 변이 짝도 있다
- 확신: 중간

### plugins/spec-distill/tests/test_seed_review_profile.sh
- 초: 0.6
- 줄 수: 88
- 고친 횟수: 4
- 크기: 중간 — docreview 엔진을 임시 상태 폴더에서 두 번(프로필 두 판본) 한 라운드씩 돌린다
- 종류: 섞임(동작 70 · 구조 30 · 글자 0 · 변이 0)
- 지키는 것: seed 프로필이 앵커 부류를 비운 채로 drop · ask · fix 판정을 그대로 배달하고(보호를 켠 판본에서는 셋 다 decide 가 되는 양성 대조), 프로필의 결정 기록 헤딩이 audit 템플릿에 정확히 한 번 있다.
- 거짓 실패 위험: 낮음 — 프로필 한 줄 모양이 바뀌면 변이 준비 단언이 소리 내고 그 밖엔 라우팅 동작이 바뀔 때만 깨진다
- 겹침: shared/tests/test_docreview_profiles.sh — 프로필 구조(내용 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0.6초에 사용자에게 갈 처분이 보존되는지를 양성 대조로 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_session_fixture.py
- 초: 0.0
- 줄 수: 207
- 고친 횟수: 3
- 크기: 중간 — 한 프로세스 안, 케이스마다 임시 폴더에 세션 기록 파일을 쓴다
- 종류: 섞임(동작 40 · 구조 60 · 글자 0 · 변이 0)
- 지키는 것: 세션 기록 자료 파일의 모든 글자가 자리표시이거나 고정 낱말이라 경로 · 이메일 · 실제 문장 같은 개인 정보가 커밋되지 않고(양성 대조로 걸리는 것 확인), 도우미가 잰 자료와 같은 꼴의 항목을 짓는다.
- 거짓 실패 위험: 낮음 — 새 자료에 자리표시가 아닌 글을 넣을 때만 깨지고 그것이 의도다
- 겹침: plugins/spec-distill/tests/test_session_record.py — 같은 도우미 · 자료를 입력으로 쓴다(확인하는 것은 다름)
- 보안 갈래: 예
- 판정 후보: 둠 — 실제 세션 기록에서 가져온 자료에 개인 정보가 섞여 커밋되는 사고를 막고 비용이 0 이다
- 확신: 중간

### plugins/spec-distill/tests/test_session_id_resolution.sh
- 초: 1.4
- 줄 수: 130
- 고친 횟수: 5
- 크기: 중간 — 케이스마다 env -i 로 python 을 새로 띄운다(약 15번)
- 종류: 동작
- 지키는 것: 세션 ID 해석이 환경변수 · payload 우선순위를 지키고 공백 · `../` · `/` · `.` 가 든 값과 8자 미만을 거부해서 상태 폴더 경로가 세션 ID 로 탈출당하지 않는다.
- 거짓 실패 위험: 낮음 — 해석 규칙이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_state_path.sh · test_ledger_root.sh — 같은 state_path.py 의 다른 하위 명령(세션 ID 해석은 못 찾음)
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 경로 탈출 거부를 지키는 확인은 그대로 두고 케이스마다 python 을 띄우는 것을 한 프로세스 안 표 순회로 바꾸면 1초대가 줄어든다(추정)
- 확신: 중간

### plugins/spec-distill/tests/test_session_record.py
- 초: 0.1
- 줄 수: 362
- 고친 횟수: 3
- 크기: 중간 — 한 프로세스 안, 케이스마다 임시 폴더 · 세션 기록 파일 쓰기(큰 기록 5만 줄 하나 포함)
- 종류: 동작
- 지키는 것: 세션 기록에서 질문 창의 답을 읽을 때 사람 · 사람 아님(hook · sdk-cli) · 알 수 없음을 가려서(사람 아님이 먼저), 칸이 바뀐 모양이 조용히 사라지지 않고 「알 수 없음」 으로 남으며, 이름이 경로 탈출 꼴이면 기록을 찾지 않는다.
- 거짓 실패 위험: 중간 — Claude Code 기록 꼴(2.1.327에서 잰 값)에 결합돼 있고 큰 기록 단언이 10초 문턱을 쓴다(실제는 0.1초대)
- 겹침: plugins/spec-distill/tests/test_control_plane.py · test_roadmap_status.sh — session_record 를 소비하나 읽는 규칙 정본은 이 파일(내용 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 사람이 한 답인지(승인 관문의 근거)를 가르는 규칙을 0.1초에 폭넓게 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_skepticism_module.sh
- 초: 0.1
- 줄 수: 83
- 고친 횟수: 2
- 크기: 중간 — grep 몇 번과 python 하나(함수 22건 판정)
- 종류: 섞임(동작 85 · 구조 0 · 글자 15 · 변이 0)
- 지키는 것: skepticism 모듈의 판정 함수(verdict · 검토 기록 형식 · 닫힘 · bijection A)가 정상 · 형식 미달을 가르고, check_brief → skepticism 한 방향 import 가 지켜져 순환이 안 생긴다.
- 거짓 실패 위험: 낮음 — 판정 규칙이 바뀔 때만 깨지고 기대 줄 수 22 는 같은 커밋에서 고치게 못 박았다
- 겹침: plugins/spec-distill/tests/test_check_brief.sh — 같은 판정을 check_brief 쪽에서 부름(내용 겹침은 확인 못 함); test_check_verbatim_coverage.sh
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0.1초에 brief 게이트의 skepticism 판정을 함수 단위로 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_stale_terms.sh
- 초: 1.5
- 줄 수: 365
- 고친 횟수: 33
- 크기: 작음 — production 파일 전체에 대한 grep 약 35번과 파일 부재 검사 39개(하위 프로세스 없음, 쓰기 없음)
- 종류: 글자
- 지키는 것: 글자만 지킴 — plugins/spec-distill production 파일(tests · CHANGELOG 제외)에 옛 어휘(breadth-keeper · review_lock · depth_pairs · 권위 문법 6개 등)가 남지 않고 지운 파일 39개가 되살아나지 않는다; 라운드 규약 절의 문구 둘만 양성 짝.
- 거짓 실패 위험: 높음 — 정직한 서술(README · SKILL)이 옛 낱말을 인용하거나 개념 별칭이 우연히 겹치면 RED 이고 목록 개수 39 · 주석 핀을 편집마다 고쳐야 한다
- 겹침: 못 찾음(같은 옛 어휘를 지키는 다른 테스트를 찾지 못했다 — 다만 plugins/spec-distill/tests 의 다른 *_residue 테스트가 같은 부류일 수 있어 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 삭제 당시 스윕을 락으로 굳힌 33번 수정의 누적이다; 지킬 것은 되살아난 파일 · 훅(V10) 정도이고 옛 어휘 grep 대부분은 글자만 지킴
- 확신: 낮음

### plugins/spec-distill/tests/test_state_path.sh
- 초: 1.9
- 줄 수: 174
- 고친 횟수: 12
- 크기: 중간 — 임시 git 레포 · worktree 와 state_path.py 를 약 45번 띄운다
- 종류: 동작
- 지키는 것: 상태 루트가 worktree 에서도 본 레포를 가리키고, 인터뷰 상태 경로가 seed · audit 와 겹치면 멈추며, path-inside · payload-root 가 링크 성분 · `..` 탈출 · 저장소 밖 링크 경로를 거부해 상태 쓰기가 레포 밖으로 새지 않는다.
- 거짓 실패 위험: 낮음 — 경로 결정 규칙이 바뀔 때만 깨진다(사유 문구 일부 grep)
- 겹침: plugins/spec-distill/tests/test_state_root.sh — worktree 의 상태 루트(연결된 worktree 케이스 겹침); plugins/spec-distill/tests/test_workspace_invariance.sh · test_ledger_root.sh 도 state_path.py 를 부른다(내용 겹침 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 링크 · `..` 로 상태 쓰기가 밖으로 새는 경로를 실행으로 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_state_root.sh
- 초: 3.4
- 줄 수: 199
- 고친 횟수: 3
- 크기: 중간 — 임시 git 레포 약 17개(bare 클론 · worktree 포함)를 새로 만들고 state_path · conductor_ledger 를 부른다
- 종류: 동작
- 지키는 것: `state-root --ensure` 가 상태 루트에 자기 무시 `.gitignore` 를 두고 git status 를 깨끗하게 유지하며, 상태 폴더 아래 추적 파일이 있으면 고치는 법을 담아 rc 3 으로 멈추고, bare 레포끼리 상태 루트가 섞이지 않고 링크 너머로 쓰지 않는다.
- 거짓 실패 위험: 중간 — 안내 문장 전문 비교(TRACKED)와 SKILL 상태 블록을 awk 로 잘라 실행하므로 문구 · 펜스 모양에 결합된다
- 겹침: plugins/spec-distill/tests/test_state_path.sh — worktree 상태 루트 · state_path.py 를 같이 다룬다
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 읽기만 하는 구역(A · B · C0 · D · R2)이 각자 git init + 커밋하는데 템플릿 레포 하나를 복사해 쓰면 3.4초가 줄 것이다(추정; 지키는 것은 그대로)
- 확신: 낮음

### plugins/spec-distill/tests/test_state_storage_e2e.sh
- 초: 4.7
- 줄 수: 185
- 고친 횟수: 7
- 크기: 중간 — bare origin 둘 + 클론 세 개를 만들고 실제 SKILL 펜스 · CLI 를 세션 A · B 로 한 흐름 돌린다(git commit · push 다수, ledger_sweep 실행)
- 종류: 동작
- 지키는 것: seed 진입 → 상태 파일 → 두 세션 이어 감 → 끝내기 커밋이 세 경로만 담음 → 두 세션 리뷰의 표지 넘겨받기와 쓰기 전 확인 → 문서 없는 원장 정리까지의 끝에서 끝 흐름이 이어지고, 링크로 심은 상태 파일 · 원장이 있으면 따라 쓰거나 지우지 않는다.
- 거짓 실패 위험: 중간 — SKILL · finishing 의 펜스를 마커로 뽑아 실행하므로 펜스 마커 · 출력 줄(`ledger-open: HELD` 등) 문구가 바뀌면 깨진다
- 겹침: plugins/spec-distill/tests/test_interview_state_flow.sh · test_state_dir_writes.sh · test_ledger_sweep.py — 같은 흐름의 일부를 개별로 잰다(내용 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 이음매(진입 · 커밋 · 리뷰 표지 · 정리)를 끝에서 끝으로 잰 유일한 락이고 링크 축 방어를 포함한다
- 확신: 중간

### plugins/spec-distill/tests/test_steelman_builder_scope.sh
- 초: 0.2
- 줄 수: 163
- 고친 횟수: 13
- 크기: 작음 — 한 파일에 대한 grep · awk 뿐
- 종류: 섞임(동작 0 · 구조 35 · 글자 65 · 변이 0)
- 지키는 것: steelman-builder agent 가 쓰기 · 실행 도구 없이 `tools:` allowlist 로만 읽기 · 웹 도구를 갖고 model 키로 티어를 고정하지 않는다(Law 2); 나머지 약 40줄은 출력 스키마 키 · 옛 토큰 부재 · 문구 존재를 확인하는 글자 확인이다.
- 거짓 실패 위험: 높음 — 스키마 줄 · 문구를 다듬거나 설계를 개편하면(13번 수정) 깨진다
- 겹침: plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh · plugins/quality-gates/tests/test_agent_model_mutation.sh · tools/adjudication/check_slots.py — 같은 부류(agent frontmatter · 슬롯)를 다른 agent 로 / 일반화해 잰다(steelman 스키마 키는 못 찾음)
- 보안 갈래: 예
- 판정 후보: 줄임 — tools allowlist · model 키 부재(Law 2)는 남기고 스키마 키 · 옛 토큰 · 문구 grep 은 글자만 지킴이라 줄인다
- 확신: 중간

### plugins/spec-distill/tests/test_suite_lock.py
- 초: 2.5
- 줄 수: 329
- 고친 횟수: 7
- 크기: 큼 — 실제 sleep(0.6초 해제 대기 · 1초 기다림)과 SIGTERM 시험의 자식 프로세스 · 손자 대기, 매 케이스 python 하위 프로세스(dead_pid)
- 종류: 동작
- 지키는 것: 지휘자와 하위 agent 가 같이 쓰는 스위트 잠금이 산 주인의 잠금을 훔치지 않고, 죽은 주인 잠금은 소리 내며 풀고, 옮길 수 없는 잠금 · 경합 되돌리기가 무한히 돌지 않으며, SIGTERM 이 스위트(손자)까지 멈추고 잠금을 푼다.
- 거짓 실패 위험: 중간 — 시간 문턱(기다림 ≥0.9초 · 쉬는 횟수 ≤20 · 표지 파일 10초 대기)이 부하에 흔들리고 chmod 기반 케이스는 root 에서 어긋난다
- 겹침: plugins/spec-distill/tests/test_control_plane.sh · test_conductor_dispatch_reference.sh · tools/suite/test_suite_timing.py — suite_lock 을 부르거나 문서화하나 잠금 동작 정본은 이 파일(내용 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 동시 스위트 실행이 서로 시간을 흐리거나 산 잠금을 훔치는 사고를 동작으로 지키고 2.5초는 값에 맞다
- 확신: 중간

### plugins/spec-distill/tests/test_superpowers_presence.sh
- 초: 0.7
- 줄 수: 133
- 고친 횟수: 11
- 크기: 작음 — grep · awk · sed 위주이고 python 은 세 번(plugin.json · dependencies.md 읽기), 쓰기 없음
- 종류: 섞임(동작 0 · 구조 10 · 글자 90 · 변이 0)
- 지키는 것: spec-distill plugin.json 에 `dependencies` 키가 없고(있으면 superpowers 없을 때 플러그인 전체가 꺼진다) dependencies.md 에 superpowers 행이 있으며 문서가 부르는 check_deps 하위 명령이 entry · measure 둘뿐이다; 나머지는 superpowers 없음 안내 문장 · 선택지 리터럴이 문서에 그대로 있다는 확인이다.
- 거짓 실패 위험: 높음 — finishing.md B-1 의 선택지 · 안내 리터럴 열두 개를 글자 그대로 핀해 문구를 다듬기만 해도 깨진다
- 겹침: plugins/spec-distill/tests 의 의존 · 선언 락(test_deps 류)은 이름으로 찾지 못함 — 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 줄임 — plugin.json 의존 키 부재 · dependencies.md 행 · check_deps 하위 명령 확인(5 · 6)은 남기고 문서 문구 리터럴 핀(1~4)은 글자만 지킴이라 줄인다
- 확신: 중간

### plugins/spec-distill/tests/test_team_docs.py
- 초: 0.1
- 줄 수: 548
- 고친 횟수: 19
- 크기: 작음 — 문서 · CHANGELOG · 코드 상수를 읽는 문자열 확인뿐(한 프로세스, 쓰기 없음)
- 종류: 섞임(동작 5 · 구조 10 · 글자 85 · 변이 0)
- 지키는 것: team-files.md 가 코드의 상수(단계 · 알림 글 · 결정 종류)와 같은 글을 싣고(코드에서 도출) 알림 · 종료 코드 문장이 코드와 어긋나지 않으며, 버전 올림 판정 로직에 이빨이 있다; 그러나 대부분은 문서의 긴 문장을 글자 그대로 핀한다.
- 거짓 실패 위험: 높음 — 문서 문장 · 용어를 다듬거나 CHANGELOG 항목을 더하는 것만으로 깨지고 「판 글자를 못 박지 않는다」 식의 보정 로직이 커졌다
- 겹침: plugins/spec-distill/tests/test_walk_docs.py — 같은 team-files.md · CHANGELOG(changelog_entries 를 import)를 다른 문장으로 핀한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 코드 상수에서 도출한 이름 대조는 남기고 긴 문장 · CHANGELOG 낱말 핀은 글자만 지킴이라 줄인다
- 확신: 중간

### plugins/spec-distill/tests/test_team_files.py
- 초: 0.0
- 줄 수: 409
- 고친 횟수: 12
- 크기: 작음 — 한 프로세스 안, 템플릿 읽기와 문자열 처리(쓰기 없음)
- 종류: 섞임(동작 75 · 구조 10 · 글자 15 · 변이 0)
- 지키는 것: INTENT · sources · original 파일이 렌더 → 읽기 왕복에서 손실 없이(받은 말의 `##` 줄 · CRLF 도 바이트 그대로) 돌고, 본문이 출처 표지를 위조하지 못하며, 머리 roadmap 이 `..` · 절대 경로면 형식 오류가 된다.
- 거짓 실패 위험: 중간 — 역할 틀 문장 줄(할 일 줄 모양)을 줄 단위로 핀하고 이 레포의 사본이 틀과 바이트로 같아야 해서 틀 문구를 다듬으면 깨진다
- 겹침: plugins/spec-distill/tests/test_team_docs.py — 역할 문서 두 절 · 문장 확인 일부가 겹친다(RepoFiles)
- 보안 갈래: 예
- 판정 후보: 둠 — 사용자 지시 원문이 바이트 그대로 보존되고 출처 위조 · 경로 탈출이 막히는 동작 확인이고 비용 0
- 확신: 중간

### plugins/spec-distill/tests/test_team_layout.py
- 초: 0.0
- 줄 수: 140
- 고친 횟수: 6
- 크기: 작음 — 한 프로세스 안, scripts 폴더 읽기와 문자열 확인
- 종류: 섞임(동작 85 · 구조 0 · 글자 15 · 변이 0)
- 지키는 것: team 형식의 경로 · 이름 규칙(과제 이름이 `..` · 슬래시 · 역할 이름이면 거절, 결과 파일 이름 왕복)과, 폴더 이름 리터럴이 다른 스크립트에 흩어 적히지 않고 team_layout.py 한 곳에만 있다.
- 거짓 실패 위험: 낮음 — 새 스크립트가 `jobs/` 같은 리터럴을 직접 적을 때만 깨지고 그것이 의도다
- 겹침: plugins/spec-distill/tests/test_team_docs.py · test_team_files.py — team_layout 상수를 가져다 쓴다(확인하는 것은 다름)
- 보안 갈래: 예
- 판정 후보: 둠 — 경로 이름 검증과 「한 곳」 락을 비용 0 으로 지키고 양성 · 음성 대조가 있다
- 확신: 높음

### plugins/spec-distill/tests/test_team_results.py
- 초: 0.0
- 줄 수: 411
- 고친 횟수: 11
- 크기: 작음 — 한 프로세스 안, 가짜 git(FakeGit) · 문자열 입력
- 종류: 동작
- 지키는 것: 결과 파일 · 막힘 파일 · 결정 기록 줄 읽기가 코드 펜스 안의 흉내 줄을 본문으로 보고(기계 줄 위조 방지), 줄 나눔 글자를 모두 거부하며, 같은 줄을 두 번 적지 않고, 연속 실패 수(failed_streak)를 받음 줄 · 도는 중인 시도에 맞게 센다.
- 거짓 실패 위험: 낮음 — 사유 문구 일부(`startswith`)를 보지만 대부분 구조화된 값이라 읽는 규칙이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_job_results.sh — job_results 를 임시 레포로 확인하는 쪽(내용 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 결과 파일 위조 · 파서 경계를 비용 0 으로 폭넓게 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_team_review_entry.sh
- 초: 5.8
- 줄 수: 152
- 고친 횟수: 6
- 크기: 중간 — team_repo 픽스처(bare origin · 클론 · roadmap_write 로 팀 폴더 생성)를 세우고 spec_review_bundle 을 약 30번 부르며 브랜치 push · fetch · 객체 삭제를 한다
- 종류: 동작
- 지키는 것: spec-review 진입이 과제 파일(INTENT.md)을 --bundle 로 받고 다른 과제 · 번호 파일은 REFUSE 하며, 이웃 에픽의 결정을 INTENT.md 에서 읽되 못 읽은 것은 「없음」 이 아니라 「셀 수 없음」 으로 낸다.
- 거짓 실패 위험: 중간 — 출력 줄 전문 · 위치(tail -n 3 등)를 동등 비교하므로 안내 문장 · 줄 순서가 바뀌면 깨진다
- 겹침: plugins/spec-distill/tests/test_team_status.sh · test_bundle_coverage.sh · test_job_results.sh — 같은 team_repo 픽스처(15개 파일)를 쓰나 확인하는 것은 다름
- 보안 갈래: 예
- 판정 후보: 구조를 고침 — 이 배치에서 가장 느린 파일이고 시간은 대부분 team_repo 세우기(15개 테스트 파일이 각자 반복)로 보인다; 한 번 만든 레포를 복사해 쓰면 지키는 것은 그대로 싸진다(추정, 픽스처 내부는 읽지 않았다)
- 확신: 낮음

### plugins/spec-distill/tests/test_team_rules.py
- 초: 0.0
- 줄 수: 180
- 고친 횟수: 3
- 크기: 작음 — 한 프로세스 안, 문자열 파싱 · ast 훑기
- 종류: 섞임(동작 85 · 구조 15 · 글자 0 · 변이 0)
- 지키는 것: 규칙 줄(`- [태그] 글 · 조건 · 출처 · 확인`)의 읽는 법 · 형식 오류 사유 · 바이트 예산 경계 · 같은 규칙 글 중복을 가려내고, 승격 후보를 출처 둘 이상으로 고르며, 새 스크립트 둘이 파일을 쓰거나 프로세스를 띄우지 않는다(ast).
- 거짓 실패 위험: 낮음 — 읽는 규칙이 바뀔 때만 깨지고 사유 상수는 코드에서 가져온다
- 겹침: plugins/spec-distill/tests/test_team_rules.sh — 같은 스크립트의 CLI 쪽(예산 · 누락 파일이 일부 겹침)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 비용 0 으로 규칙 파서 경계를 폭넓게 지킨다
- 확신: 높음

### plugins/spec-distill/tests/test_team_rules.sh
- 초: 3.4
- 줄 수: 83
- 고친 횟수: 2
- 크기: 중간 — team_repo 픽스처를 세우고 team_rules.py 를 약 28번 띄우며 커밋 · push 를 여섯 번 한다
- 종류: 동작
- 지키는 것: team_rules.py check · candidates 가 작업 폴더의 파일과 `--ref` 커밋의 파일을 따로 읽고(없는 ref · 없는 팀은 검사 불가 3), 예산을 글자 수가 아니라 바이트로 재고, 공통 규칙 파일이 없으면 한 줄만 알린다.
- 거짓 실패 위험: 낮음 — 출력 첫 줄 · 사유 문구를 코드의 상수와 맞춰 보며 동작이 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_team_rules.py — 예산 경계 · 파일 누락을 프로세스 안에서 이미 잰다(CLI 배선 · `--ref` · 바이트 대 글자는 이 파일만)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 3.4초는 거의 team_repo 세우기이고 확인은 CLI 배선뿐이다; 픽스처를 공유하거나 작은 레포로 줄이면 지키는 것은 그대로다(추정)
- 확신: 낮음

### plugins/spec-distill/tests/test_team_status_stub.sh
- 초: 1.7
- 줄 수: 175
- 고친 횟수: 3
- 크기: 중간 — 임시 git 레포 · bare origin 을 만들고 roadmap_status.py 를 약 12번 띄운다
- 종류: 동작
- 지키는 것: roadmap_status 가 team 로드맵은 번호 대조를 하고 단계를 과제 폴더로 계산하며, 모르는 layout 값은 번호도 세지 않고 검사 불가(3)로 멈추고(옛 규칙으로 읽지 않음), layout 이 없는 옛 형식은 그대로 계산한다.
- 거짓 실패 위험: 낮음 — 상태 계산 동작이 바뀔 때만 깨진다(보고 JSON 의 필드 값을 eval 로 비교)
- 겹침: plugins/spec-distill/tests/test_team_status.sh · test_roadmap_status.sh — 같은 roadmap_status.py(머리 주석이 단계 표는 test_team_status.sh 가 잰다고 한다; 번호 대조 · layout 분기의 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 모르는 형식을 옛 규칙으로 읽는 조용한 오판을 막는 분기 확인이고 1.7초
- 확신: 중간

### plugins/spec-distill/tests/test_walk_docs.py
- 초: 0.0
- 줄 수: 181
- 고친 횟수: 8
- 크기: 중간 — 문서 읽기 위주이고 `git show` 하위 프로세스가 한 번 있다
- 종류: 섞임(동작 10 · 구조 15 · 글자 75 · 변이 0)
- 지키는 것: 보내는 글 틀(team 형식)의 칸이 허용 목록 안이고 옛 틀 세 개가 기준 커밋과 바이트로 같으며(얕은 클론이면 건너뜀) 걸음 보기가 결정 문구를 싣는다; 나머지는 철학 문서 · CLAUDE.md 의 P8 문장과 CHANGELOG 8.27.0 낱말을 글자 그대로 핀한다.
- 거짓 실패 위험: 높음 — CLAUDE.md · 철학 문서의 문장을 고치거나 기준 커밋 해시(3b4e582a)가 얕은 클론에서 사라지면 동작 변화 없이 깨지거나 건너뛴다
- 겹침: plugins/spec-distill/tests/test_team_docs.py — 같은 team-files.md · changelog_entries 를 쓰는 문서 핀; test_conducting_loop.sh 와 같은 사실을 헤더가 인정한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 틀의 칸 허용 목록 · 옛 틀 바이트 견줌은 남기고 CLAUDE.md · 철학 · CHANGELOG 문장 핀은 글자만 지킴이라 줄인다
- 확신: 중간

### plugins/spec-distill/tests/test_walk_table.py
- 초: 1.2
- 줄 수: 224
- 고친 횟수: 1
- 크기: 중간 — 케이스마다 임시 git 레포(9개)를 새로 만들고 CLI 를 네 번 부른다
- 종류: 섞임(동작 85 · 구조 15 · 글자 0 · 변이 0)
- 지키는 것: 걸음표가 기본 표 · 깨진 표 · 허용 잡음을 맞게 읽고, 설정이 가리키는 표를 작업 폴더가 아니라 기본 브랜치 커밋에서만 읽으며 링크 · 절대 경로 설정은 멈추고, 스크립트는 읽기만 한다(ast).
- 거짓 실패 위험: 낮음 — 표 문법 · 읽는 위치가 바뀔 때만 깨진다
- 겹침: plugins/spec-distill/tests/test_walk_next.sh — 같은 walk_table.py 를 CLI 로 부른다(내용 겹침은 확인 못 함)
- 보안 갈래: 예
- 판정 후보: 둠 — 작업 폴더의 미커밋 표 · 링크가 하네스 동작을 바꾸지 못하게 하는 경계를 실행으로 지킨다
- 확신: 중간

### plugins/spec-distill/tests/test_web_kill_switch.sh
- 초: 4.0
- 줄 수: 433
- 고친 횟수: 25
- 크기: 중간 — mock codex 를 PATH 앞에 두고 codex 호출부(약 6곳)를 평시 · 끔 · `=yes` 세 번씩 실제 실행하며 skill · reference 표면을 grep 한다
- 종류: 섞임(동작 70 · 구조 0 · 글자 30 · 변이 0)
- 지키는 것: 웹 검색 끄는 스위치(DEVBREW_*_DISABLE_WEB)가 codex 호출부마다 실제 argv 의 web_search 두 값을 뒤집고 정확히 문자열 `1` 만 참으로 읽으며(`yes` 는 웹을 켠 채 둠), 웹 도구 agent 를 dispatch 하는 skill 이 그 위 40줄 안에 실행 가능한 스위치 확인을 갖는다.
- 거짓 실패 위험: 중간 — 새 codex 호출부가 AC21 표에 없으면 RED(의도)이고 호출 줄 모양이 codex_candidates() 정규식에서 빠지면 소리가 난다; skill 표면 grep 은 문구 모양에 결합
- 겹침: shared/tests/test_docreview_codex.sh(프로필 web × 스위치) · plugins/quality-gates/tests/test_codex_invocation_contract.sh(같은 관측 라이브러리) · plugins/spec-distill/tests/test_brief_codex_axes.sh · test_reviewing_brief_critic_select.sh — 같은 스위치의 일부 소비자
- 보안 갈래: 예
- 판정 후보: 둠 — 끄는 스위치(P21)가 사용자가 끈 것과 실제로 꺼진 것을 일치시키는지를 실행 관측으로 지키는 보안 락이다
- 확신: 중간

### plugins/spec-distill/tests/test_workflow_superpowers.py
- 초: 0.0
- 줄 수: 110
- 고친 횟수: 2
- 크기: 작음 — 한 프로세스 안, 문자열 변환과 scripts 폴더 읽기
- 종류: 섞임(동작 85 · 구조 0 · 글자 15 · 변이 0)
- 지키는 것: superpowers 계획의 Task 절 읽기와 원장 → 결과 줄 변환이 정해진 꼴(펜스 안 제목은 세지 않음 · 판정 줄 규칙 하나)로 돌고, 그 꼴을 읽는 코드가 변환기 한 곳에만 있다.
- 거짓 실패 위험: 낮음 — 새 스크립트가 `Task ` 제목 · `"Ruling:"` 리터럴을 직접 적을 때만 깨지고 그것이 의도다
- 겹침: plugins/spec-distill/tests/test_bundle_coverage.sh · test_control_plane.py — 변환기를 소비한다(확인하는 것은 다름)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 비용 0 으로 superpowers 꼴 의존을 한 곳에 묶어 둔 락을 지킨다
- 확신: 중간

#### 읽지 못한 것 — shallow-09

없음 — 32개 단위 모두 끝까지 읽었다. 다만 판정에 영향을 줄 수 있는 확인 못 함 두 가지: (1) team_repo.sh 픽스처는 길이(237줄)와 git 명령 줄만 봤고 내부 시간 배분은 추정이다 · (2) 「겹침」 칸의 다른 테스트들은 이름 grep 으로 찾은 것이고 내용 겹침의 정도는 대부분 읽지 않았다.

## 묶음 shallow-10

### plugins/spec-distill/tests/test_yaml_scalar_single_definition.py
- 초: 0.0
- 줄 수: 245
- 고친 횟수: 6
- 크기: 작음 — 한 프로세스 안 unittest, 파일 읽기와 함수 호출뿐
- 종류: 섞임(동작 70 · 구조 30 · 글자 0 · 변이 0)
- 지키는 것: `_yaml_scalar` 정의가 한 곳뿐이고 그 하나가 인용 규칙(빈 값 · 첫 글자 지시자 · `[]{}` · None)을 지켜서, 리뷰 상태 문서의 YAML 이 깨지지 않으며 shared/codex 정본과 출력이 바이트로 같다.
- 거짓 실패 위험: 낮음 — 인용 규칙이나 정의 위치가 바뀔 때만 깨진다(소비자 하한 1 은 소비자가 더 줄면 깨짐)
- 겹침: plugins/spec-distill/tests/test_codex_findings_to_yaml.py — `_yaml_scalar` 를 쓰는 곳으로 겹칠 수 있으나 내용 대조는 못 함(확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0초에 YAML 파손과 사본 갈라짐을 동작으로 지킨다
- 확신: 높음

### shared/tests/test_adjudication_behavior.sh
- 초: 0.5
- 줄 수: 206
- 고친 횟수: 7
- 크기: 중간 — 케이스마다 python3 를 새로 띄운다(약 25회) + fixture 프로브 둘
- 종류: 동작
- 지키는 것: 처분 회계 원장의 각 메서드가 올바른 칸만 올리고 흡수는 degrade 가 아니며 blocks 판정이 진리표대로라서, 항목 소실이 조용히 묻히거나 보조 판정자 실패가 심사를 막는 일이 없다.
- 거짓 실패 위험: 낮음 — 원장 동작이 바뀔 때만 깨진다(reasons 접두 문구 핀은 다소 문구 의존)
- 겹침: 못 찾음 — 대상 이름(adjudication.py)으로 직접 행동을 재는 다른 테스트는 못 찾음. 소비자 쪽은 cases.sh 가 별도로 잰다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 게이트 판정 정확성을 동작으로 못 박고 0.5초다
- 확신: 높음

### shared/tests/test_adjudication_consumed.sh
- 초: 0.3
- 줄 수: 100
- 고친 횟수: 9
- 크기: 중간 — run_consumed.py 를 python 으로 한 번 실행
- 종류: 섞임(동작 60 · 구조 40 · 글자 0 · 변이 0)
- 지키는 것: 처분 원장이 내는 카운트 키를 소비자 코드가 실제로 읽어서, 새 카운트가 생겼는데 소비자가 화면에 안 싣는 일(조용한 소실)을 잡는다.
- 거짓 실패 위험: 중간 — 소비자 파일이나 공유 렌더 모듈의 import 구조를 옮기면 폐포 계산이 바뀌어 깨질 수 있다
- 겹침: shared/tests/test_adjudication_wiring.sh — 같은 판정기군(tools/adjudication)과 러너를 공유하나 지키는 축은 다름(소비 vs 배선)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 파일 단위 폐포 한계를 스스로 밝혔고 0.3초다
- 확신: 중간

### shared/tests/test_adjudication_wiring.sh
- 초: 2.6
- 줄 수: 430
- 고친 횟수: 30
- 크기: 큼 — `git clone --no-local` 사본을 만들고 그 위에서 스캔을 네 번 되풀이 + 러너 여럿
- 종류: 섞임(동작 40 · 구조 10 · 글자 0 · 변이 50)
- 지키는 것: 항목을 버리는 분기(continue · return)가 같은 분기에서 처분을 부르는지 전수로 재서, 판정 항목이 원장 밖으로 조용히 사라지는 배선 누락을 잡고 면제 목록이 부풀지 않게 한다.
- 거짓 실패 위험: 높음 — 라우터 파일에 줄이나 컴프리헨션이 늘면 baseline 숫자(COMP_BASELINE)와 면제 키가 깨지고 실제로 30번 고쳐졌다
- 겹침: shared/tests/test_adjudication_consumed.sh, test_adjudication_behavior.sh — 같은 판정기군의 다른 축이며 중복은 아님
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 사본 클론을 케이스마다 쓰지 않고 한 번 만들어 쓰고, COMP_BASELINE 의 손 유지 숫자를 도출로 바꾸면 고친 횟수가 준다
- 확신: 중간

### shared/tests/test_agent_input_slots.sh
- 초: 0.2
- 줄 수: 127
- 고친 횟수: 9
- 크기: 중간 — run_slots.py 를 python 으로 한 번 실행
- 종류: 섞임(동작 50 · 구조 50 · 글자 0 · 변이 0)
- 지키는 것: agent 가 선언한 입력 슬롯과 dispatch 가 실제로 넘기는 것이 일치하고 금지 종류가 없어서, 리뷰어가 받아서는 안 될 판정·이력 입력을 조용히 받는 일을 잡는다.
- 거짓 실패 위험: 중간 — 면제 baseline 과 agent 정의 개수 도출에 의존, agent 를 더하면 조정이 필요하다
- 겹침: shared/tests/test_dispatch_disposition.sh, test_dispatch_name_defined.sh — 같은 dispatch 집합을 다른 축으로 읽음(내용 겹침은 작음)
- 보안 갈래: 예 — 리뷰어 입력 경계(Law 2 에 닿는 슬롯 금지 종류)
- 판정 후보: 둠 — 리뷰어 격리 경계를 도출로 지키고 0.2초다
- 확신: 중간

### shared/tests/test_ask_recommendation.sh
- 초: 0.3
- 줄 수: 69
- 고친 횟수: 5
- 크기: 중간 — git ls-files + find + python 판정 모듈 두 번 실행
- 종류: 섞임(동작 50 · 구조 20 · 글자 30 · 변이 0)
- 지키는 것: 모델이 읽는 문서의 질문 자리마다 「(권장)」 꼬리 등 추천 표시 규칙이 지켜져서, 사용자가 추천 없이 또는 어긋난 표시로 선택을 요구받는 일을 막는다.
- 거짓 실패 위험: 높음 — 질문 문구를 다듬거나 AskUserQuestion 줄을 옮기면 ask-sites.tsv 행과 어긋나 깨진다
- 겹침: shared/tests/test_plain_language_block.sh — 같은 추천 문장(REC)을 정본에서 글자로 핀한다. 겹침은 그 한 문장
- 보안 갈래: 아니오
- 판정 후보: 둠 — 문서 계약을 도출로 전수 검사하고 0.3초다. 목록(tsv) 손 유지 비용은 있다
- 확신: 중간

### shared/tests/test_assert_behavior.sh
- 초: 0.8
- 줄 수: 208
- 고친 횟수: 5
- 크기: 중간 — probe 마다 bash 를 새로 띄운다(약 40회) + 2MB 임시 파일
- 종류: 동작
- 지키는 것: 모든 shell 테스트가 의존하는 assert.sh 헬퍼가 실패를 세고 finish 가 비영 종료하는 등 행동 계약을 지켜서, 스위트 전체가 조용히 거짓 GREEN 이 되는 일을 막는다.
- 거짓 실패 위험: 낮음 — 헬퍼 계약(접두 `  ✗ `, pipefail 처리)이 바뀔 때만 깨진다
- 겹침: 못 찾음 — assert.sh 의 행동을 직접 재는 다른 테스트는 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 모든 락의 이빨을 지키는 바닥이고 0.8초다
- 확신: 높음

### shared/tests/test_charter_citations.sh
- 초: 0.2
- 줄 수: 285
- 고친 횟수: 11
- 크기: 중간 — python 한 번 + git ls-files · git log 하위 프로세스
- 종류: 섞임(동작 30 · 구조 40 · 글자 30 · 변이 0)
- 지키는 것: CLAUDE.md 와 철학 문서가 이름으로 박은 경로 · 플러그인 이름이 실재하고 이력에서 사라진 이름이 남지 않으며 qg 공개 설명 문자열이 정본과 같아서, 헌장이 존재하지 않는 대상을 가리키는 일을 막는다.
- 거짓 실패 위험: 높음 — 헌장에 새 경로를 적거나 파일을 옮기거나 qg 설명을 바꾸면 UNTRACKED_CITED 목록과 QG_DESC 를 같이 고쳐야 깨진다
- 겹침: 못 찾음 — 헌장 인용 실재를 재는 다른 테스트는 못 찾음. test_plugin_description_parity.sh 가 qg 설명을 따로 잴 가능성은 있으나 확인 못 함
- 보안 갈래: 아니오
- 판정 후보: 둠 — 헌장이 대상 없는 조항을 갖지 않게 하고 0.2초다
- 확신: 중간

### shared/tests/test_check_deps.py
- 초: 0.0
- 줄 수: 172
- 고친 횟수: 3
- 크기: 작음 — 한 프로세스 unittest, 임시 폴더 파일 몇 개
- 종류: 동작
- 지키는 것: 의존 표 판독과 판 문자열 판독이 깨진 표 · 이상한 출력을 멈춤 사유와 함께 거절하고 원자 쓰기가 임시 파일을 남기지 않아서, 사용자가 잘못된 의존 판정이나 반쯤 쓴 파일을 만나지 않는다.
- 거짓 실패 위험: 낮음 — 판독 규칙이나 오류 문구(`4칸`, `머리말` 등 일부 한국어 단편)가 바뀔 때만 깨진다
- 겹침: shared/tests/test_check_deps.sh — 같은 check_deps.py 의 read_table 을 간접으로 다시 돌리나 동작 범위는 다름
- 보안 갈래: 아니오
- 판정 후보: 둠 — 0초에 파서 가장자리를 단위로 지킨다
- 확신: 높음

### shared/tests/test_check_deps.sh
- 초: 3.3
- 줄 수: 295
- 고친 횟수: 7
- 크기: 큼 — 케이스마다 python 을 새로 띄워 수십 번 실행(measure · entry), 가짜 바이너리 PATH 와 임시 플러그인 루트
- 종류: 섞임(동작 80 · 구조 15 · 글자 5 · 변이 0)
- 지키는 것: check_deps.py 의 measure 가 표의 판 칸만 고치고 entry 가 낮은 판 · 없는 도구에서 rc 3 으로 멈춰서, 사용자가 의존이 부족한 채 스킬을 진행하거나 의존 표가 망가지는 일을 막는다.
- 거짓 실패 위험: 중간 — 안내 문구(`멈춤 — …`)를 다듬거나 플러그인 의존 행 목록을 바꾸면 expected_names 와 문구 단언이 깨진다
- 겹침: shared/tests/test_check_deps.py(read_table 부분), shared/tests/test_entry_dep_needs.sh(entry 호출 부분) — 일부 겹침
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 같은 스크립트를 케이스마다 python 으로 새로 띄우는 비용이 3초의 대부분이라, 순수 판독 가장자리는 .py 단위 테스트로 내리면 싸진다
- 확신: 중간

### shared/tests/test_codex_project_doc_off.sh
- 초: 2.0
- 줄 수: 231
- 고친 횟수: 3
- 크기: 중간 — 도출된 호출 파일마다 임시 git 레포를 새로 만들고 compute-test-scope-candidates.sh 를 실행(약 6회)
- 종류: 섞임(동작 60 · 구조 30 · 글자 0 · 변이 10)
- 지키는 것: codex 를 부르는 모든 호출이 검토 트리의 AGENTS.md 를 지시로 읽지 않게 하는 설정을 정확히 한 번 싣고 있어서, 검토 대상 리포 안의 글이 리뷰어에게 지시로 주입되는 일을 막는다.
- 거짓 실패 위험: 중간 — codex 호출 모양이 새로 늘면 도출기가 판정 불가를 내 깨진다(의도된 fail-closed)
- 겹침: 못 찾음 — project_doc_max_bytes 를 다루는 다른 테스트는 못 찾음
- 보안 갈래: 예 — 주입(리뷰 대상 트리의 AGENTS.md 지시 차단)
- 판정 후보: 둠 — 주입 방어를 도출로 전수 확인하고 차등 선택까지 지킨다. 차등 선택의 임시 레포 반복만 줄일 여지는 있다
- 확신: 중간

### shared/tests/test_codex_runner_scratch_trap_order.sh
- 초: 0.2
- 줄 수: 142
- 고친 횟수: 1
- 크기: 작음 — git ls-files 와 grep, 러너마다 python realpath 한 번
- 종류: 구조
- 지키는 것: codex 러너가 mktemp 실패 시 `rm -rf ""` 가 도는 일이 없도록 가드된 대입이 트랩보다 앞서고, 상대 경로가 cd 전에 절대화되며, CLAUDE_PLUGIN_ROOT 에 fallback 이 있어서, 러너가 엉뚱한 곳을 지우거나 훅 밖에서 죽는 일을 막는다.
- 거짓 실패 위험: 중간 — 러너의 줄 순서와 변수 이름(SCRATCH, PROJECT_DIR)을 grep 하므로 변수명 바꿈에 깨진다
- 겹침: 못 찾음 — 러너의 트랩 순서를 재는 다른 테스트는 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 파괴적 명령(rm -rf) 오발을 순서로 지키고 0.2초다. 글자 기반이지만 순서 불변식이다
- 확신: 중간

### shared/tests/test_cost_disclosure.sh
- 초: 0.7
- 줄 수: 127
- 고친 횟수: 3
- 크기: 중간 — SKILL.md 사본을 임시 폴더에 복사하고 grep 반복(스킬 수 × 금지 문구 6)
- 종류: 섞임(동작 20 · 구조 10 · 글자 70 · 변이 0)
- 지키는 것: SKILL.md · 규칙 문서에 지출 승인 문구가 없고 세 skill 이 「지출 승인을 묻지 않는다」와 kill switch · 라운드 상한을 문서에 남겨서, 사용자가 비용 승인 질문에 막히거나 상한 없는 루프를 만나지 않는다.
- 거짓 실패 위험: 높음 — 문구를 다듬거나 절 제목(`### 4. 규모 공시`)을 바꾸면 깨진다
- 겹침: 못 찾음 — 지출 승인 금지를 재는 다른 테스트는 못 찾음
- 보안 갈래: 예 — kill switch 이름 존재(DEVBREW_*_DISABLE)를 한 번 핀한다
- 판정 후보: 둠 — 규칙 문장이 동작을 정하는 글자 확인이라 지울 수는 없으나, 사본 복사 양성 대조는 줄일 수 있다
- 확신: 중간

### shared/tests/test_dispatch_disposition.sh
- 초: 0.2
- 줄 수: 348
- 고친 횟수: 14
- 크기: 중간 — python 도출 한 번 + git ls-files, 자기 자신을 `--emit-scanned` 로 다시 한 번 실행
- 종류: 섞임(동작 20 · 구조 70 · 글자 10 · 변이 0)
- 지키는 것: 모든 agent dispatch 자리가 「처분」 한 줄(소비자 · fail 방향 · 공시)을 1:1 로 갖고 소비자 경로가 실재하며 같은 플러그인이어서, 판정 항목이 소실돼도 알려지지 않는 일을 막는다.
- 거짓 실패 위험: 중간 — dispatch 표기나 앵커 문구를 바꾸거나 agent 를 추가하면 처분 줄을 같이 고쳐야 한다(의도된 마찰)
- 겹침: shared/tests/test_docreview_copy_set.sh · test_dispatch_name_defined.sh — dispatch 집합을 다른 키로 읽음. 헌장(CLAUDE.md)이 이 테스트를 집행처로 지명
- 보안 갈래: 아니오
- 판정 후보: 둠 — 헌장이 집행처로 지명했고 0.2초다
- 확신: 높음

### shared/tests/test_dispatch_name_defined.sh
- 초: 0.8
- 줄 수: 92
- 고친 횟수: 6
- 크기: 중간 — run_names.py 를 python 으로 한 번 실행
- 종류: 섞임(동작 60 · 구조 40 · 글자 0 · 변이 0)
- 지키는 것: 백틱으로 부른 `<플러그인>:<이름>` 이 실재 agent · skill · command 정의를 가리켜서, 지운 정의를 가리키는 호출 이름이 문서에 남아 사용자가 없는 skill 을 부르게 되는 일을 막는다.
- 거짓 실패 위험: 중간 — 문서의 예시 이름을 백틱으로 적으면 매달림으로 잡혀 깨진다
- 겹침: shared/tests/test_dispatch_disposition.sh — 방향이 반대(정의에서 호출 vs 호출에서 정의). test_charter_citations.sh 도 헌장 안 `플러그인:이름` 을 따로 본다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 방향이 반대인 짝이라 한쪽으로 합칠 수 없고 0.8초다
- 확신: 중간

### shared/tests/test_docreview_advice_procedure.sh
- 초: 0.3
- 줄 수: 83
- 고친 횟수: 6
- 크기: 중간 — `docreview_state.py advice --help` 를 python 으로 한 번 실행 + awk · grep
- 종류: 섞임(동작 5 · 구조 25 · 글자 70 · 변이 0)
- 지키는 것: 절차서와 진입 skill 이 참고(advisory) 목록의 한 번 표시 · 박제 절차에서 부르는 `advice` 플래그가 실재해서, 모델이 존재하지 않는 플래그로 호출하거나 목록을 건너뛰는 일을 막는다.
- 거짓 실패 위험: 높음 — 문장(`1단계가 있었으면 그것이 진행 쪽으로 닫힌 뒤`)을 다듬거나 절 순서를 바꾸면 깨진다
- 겹침: shared/tests/test_docreview_procedure_paths.sh — 같은 절차서와 skill 의 다른 문구를 지킨다(문구가 겹치진 않음)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 플래그 실재(동작)만 남기고 긴 문장 핀 여러 개는 줄이면 문구 다듬기에 덜 깨진다
- 확신: 중간

### shared/tests/test_docreview_agent_fields.sh
- 초: 0.7
- 줄 수: 121
- 고친 횟수: 8
- 크기: 중간 — frontmatter 읽기마다 python 을 새로 띄운다(약 15회) + variant_of.py 실행
- 종류: 섞임(동작 10 · 구조 70 · 글자 20 · 변이 0)
- 지키는 것: 문서 리뷰어 agent 의 `tools:` 가 Read · Grep · Glob 뿐이고 denylist 와 model 키가 없고 입력 슬롯이 정해진 대로이며 웹 사본이 정본과 한 덩어리만 다르고 주입 경계 규칙이 있어서, 리뷰어가 쓰기 권한을 얻거나 문서 속 지시를 따르는 일을 막는다.
- 거짓 실패 위험: 낮음 — 도구 표면과 슬롯 계약이 바뀔 때만 깨진다
- 겹침: shared/tests/test_docreview_agents.sh(같은 agent 사본의 본문 규칙), shared/tests/test_variant_of_contract.sh(variant-of 관계) — 부분 겹침
- 보안 갈래: 예 — 리뷰어 프로필(tools allowlist · Law 2) · 주입 경계
- 판정 후보: 구조를 고침 — frontmatter 를 케이스마다 python 으로 새로 파싱하는 대신 한 번 파싱해 쓰면 싸진다. 지키는 것은 보안 경계라 그대로 둔다
- 확신: 중간

### shared/tests/test_docreview_agents.sh
- 초: 0.5
- 줄 수: 119
- 고친 횟수: 6
- 크기: 중간 — 사본마다 python 으로 절 추출(약 30회)과 yaml 파싱
- 종류: 섞임(동작 10 · 구조 30 · 글자 60 · 변이 0)
- 지키는 것: 탐지 리뷰어와 재비판자 본문이 `replacement` · `if_unfixed` 요구와 「빈 칸은 삭제 제안이 아니다」, 쉬운 말 한 줄, contradicts 키, related_changes 슬롯을 싣고 있어서, 게이트 블록이 「(대체안 미작성)」으로 떨어지거나 내부 기호가 사용자에게 보이는 일을 막는다.
- 거짓 실패 위험: 높음 — persona 문장을 다듬으면 부분 문자열 핀이 깨진다(이 파일은 persona 약화 감시 성격도 있다)
- 겹침: shared/tests/test_docreview_agent_fields.sh — 같은 agent 사본의 frontmatter 쪽을 지킴. test_docreview_layer1_wiring.sh 도 같은 사본의 층 1 불릿을 본다
- 보안 갈래: 예 — 리뷰어 persona(약화 시 보안 리뷰 대상)
- 판정 후보: 구조를 고침 — 절 추출을 사본×단언마다 python 새로 띄우지 않고 한 번에 뽑으면 싸진다. 문구 핀은 persona 가 동작을 정하므로 둔다
- 확신: 중간

### shared/tests/test_docreview_anchor.sh
- 초: 1.4
- 줄 수: 25
- 고친 횟수: 4
- 크기: 중간 — cases.sh 케이스 8개를 실행(각각 python 으로 docreview_anchor.py · docreview_state.py 실행, 임시 상태 폴더)
- 종류: 동작
- 지키는 것: 헤딩 단위 앵커 도구가 스냅숏 모양 · slug · diff 와 얼림 예외 · 보호 부류 캐스케이드 · 인용 수를 올바르게 내서, 문서 리뷰의 얼림 검사가 잘못된 변경 판정을 하는 일을 막는다.
- 거짓 실패 위험: 낮음 — 앵커 동작이 바뀔 때만 깨진다(케이스 본문은 cases.sh 에 있어 이 25줄만으로는 내용을 못 봄)
- 겹침: 못 찾음 — docreview_anchor.py 를 직접 실행해 재는 다른 테스트는 못 찾음(test_docreview_state.sh 가 state 쪽을 볼 가능성은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 25줄 래퍼이고 케이스는 공유 fixture 이며 1.4초다
- 확신: 중간

### shared/tests/test_docreview_copy_set.sh
- 초: 0.6
- 줄 수: 206
- 고친 횟수: 6
- 크기: 중간 — 검출기 python 을 실제 리포 1회 + 픽스처 git 리포 9개에서 실행
- 종류: 섞임(동작 70 · 구조 30 · 글자 0 · 변이 0)
- 지키는 것: docreview agent 의 사본 집합과 dispatch 집합이 (플러그인, 이름) 쌍으로 정확히 같고 파일 밖 기대값과도 같아서, 사본 없이 dispatch 하거나 쓰이지 않는 사본이 남는 일을 막는다.
- 거짓 실패 위험: 중간 — agent 사본을 더하면 EXPECTED 핀을 같이 고쳐야 한다(의도된 마찰)
- 겹침: shared/tests/test_dispatch_disposition.sh — 접두 없는 이름 키라는 사각을 메우는 짝이며 그 파일이 정확히 이 락의 존재 이유를 설명
- 보안 갈래: 아니오
- 판정 후보: 둠 — 검출기를 픽스처로 자기검사하고 0.6초다
- 확신: 높음

### shared/tests/test_docreview_gate_visibility.sh
- 초: 5.6
- 줄 수: 336
- 고친 횟수: 5
- 크기: 중간 — 가시성 행 10개마다 임시 상태 폴더를 만들고 docreview_state.py 를 여러 번(init · begin-round · decide · gate · gate --render · python 프로브) 실행
- 종류: 동작
- 지키는 것: 승인을 막는 상태는 게이트 본문에 반드시 보이고 막지 않는다고 표에 적힌 상태는 정말 막지 않으며 열림 계보 값이 맞아서, 사용자가 보이지 않는 이유로 승인에 막히거나 막혀야 할 때 통과하는 일을 막는다.
- 거짓 실패 위험: 낮음 — gate-rows 표 · 게이트 동작이 바뀔 때만 깨진다(EXPECTED_ROWS 리터럴은 행 추가 때 손으로 고쳐야 하는 의도된 마찰)
- 겹침: shared/tests/test_docreview_gate_plain.sh · test_docreview_mutations.sh — gate/approval_ready 를 읽는 다른 테스트(내용 대조는 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 행마다 만드는 state 에서 공통 준비(init + begin-round + seed)를 한 번 만들어 복사해 쓰면 5.6초가 줄 수 있다. 지키는 것은 그대로
- 확신: 중간

### shared/tests/test_docreview_golden.sh
- 초: 5.0
- 줄 수: 95
- 고친 횟수: 3
- 크기: 중간 — capture_finalize_golden.sh 를 실행해 케이스 다섯의 finalize 를 다시 돌리고 파일 20개를 diff
- 종류: 동작
- 지키는 것: cmd_finalize 의 실제 산출물(fin.json · state.md · gate.json · gate.txt)이 고정 골든과 바이트로 같아서, 케이스 단언이 읽지 않는 출력 필드(by_disposition · defers 등)의 회귀가 조용히 지나가는 일을 막는다.
- 거짓 실패 위험: 중간 — 출력에 필드나 문구를 의도로 더하면 골든 20개를 다시 떠야 깨짐이 풀린다
- 겹침: shared/tests/test_docreview_mutations.sh — 같은 finalize 경로를 다른 시나리오로 돌릴 수 있으나 골든 대조는 이 파일만(내용 겹침은 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 둠 — 골든 바이트 대조라는 다른 락이 못 보는 면을 지키고 5초는 finalize 다섯 번에 맞다
- 확신: 중간

### shared/tests/test_docreview_layer1_wiring.sh
- 초: 0.1
- 줄 수: 129
- 고친 횟수: 2
- 크기: 작음 — git ls-files 와 grep 만
- 종류: 글자
- 지키는 것: 탐지 리뷰어 본문이 층 1 판정 관계를 리터럴로 쥐지 않고 각 프로필이 자기 자리의 판정 관계를 한 줄씩 소유해서, 한 자리(brief · seed)의 관계 문장이 다른 자리에 잘못 적용되는 일을 막는다.
- 거짓 실패 위험: 높음 — 불릿 문구나 축 이름 문장을 다듬으면 마커와 부분 문자열 핀이 깨진다
- 겹침: shared/tests/test_docreview_agents.sh — 같은 doc-critic 사본의 다른 절을 지킴(내용 겹침은 작음)
- 보안 갈래: 예 — 리뷰어 persona(층 1 본문 약화 감시)
- 판정 후보: 둠 — 글자 확인이나 persona 보안 갈래이고 0.1초라 비용이 지키는 것에 맞다
- 확신: 중간

### shared/tests/test_docreview_procedure_paths.sh
- 초: 0.4
- 줄 수: 267
- 고친 횟수: 15
- 크기: 중간 — python 으로 AST 도출과 문자열 치환 반복(약 10회), 나머지 grep
- 종류: 섞임(동작 10 · 구조 20 · 글자 70 · 변이 0)
- 지키는 것: 절차서와 두 진입 skill 이 init · begin-round · finalize 의 rc 규칙, 배포 경로 호출, 「미검증」 라벨의 출처가 엔진 요약이라는 규칙을 싣고 엔진 gate_summary 키와 사유를 모두 싣고 있어서, 모델이 실패한 단계를 넘어 진행하거나 「미검증」 라벨을 기억으로 붙이는 일을 막는다.
- 거짓 실패 위험: 높음 — 15번 고쳐졌고 긴 한국어 문장을 body-unique 로 핀하므로 문구를 다듬을 때마다 깨진다
- 겹침: shared/tests/test_docreview_round_gate_split.sh · test_docreview_advice_procedure.sh — 같은 절차서와 skill 을 읽어 다른 문구를 핀한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 지키는 규칙은 분명하나 긴 문장 핀이 많고 같은 문서를 읽는 두 형제와 문구 다듬기에 함께 깨진다. 핵심 규칙과 엔진 도출 대조만 남기면 된다
- 확신: 중간

### shared/tests/test_docreview_profile_schema.sh
- 초: 1.7
- 줄 수: 262
- 고친 횟수: 7
- 크기: 중간 — profile-check · init 을 약 35번 새 프로세스로 실행하고 변이 프로필을 python 으로 만든다
- 종류: 섞임(동작 70 · 구조 5 · 글자 0 · 변이 25)
- 지키는 것: 프로필 로더가 layer_rubric 의 셋째 키 미끼 · 중복 키 · 빈 본문 · 문자열 아닌 층 항목 · 알 수 없는 must_catch 축을 진입 단계에서 거절해서, 악의적으로 심은 프로필 값이 codex 러너의 느슨한 파서에 조용히 이기는 일을 막는다.
- 거짓 실패 위험: 낮음 — 프로필 검증 규칙이 바뀔 때만 깨진다
- 겹침: shared/tests/test_docreview_profiles.sh — 둘 다 profile-check 를 배포 프로필에 돌린다(배포 프로필 넷 통과 · 정확히 넷 단언이 둘 다에 있음)
- 보안 갈래: 예 — 주입 · 리뷰어 프로필 로더(fail-closed 게이트)
- 판정 후보: 합침 — 배포 프로필 넷 통과와 「정확히 넷」 단언은 test_docreview_profiles.sh 와 같으니 한쪽으로 모으면 profile-check 실행이 4회 줄고, 변이 거절은 그대로 둔다
- 확신: 중간

### shared/tests/test_docreview_profiles.sh
- 초: 2.5
- 줄 수: 233
- 고친 횟수: 13
- 크기: 중간 — profile-check 를 약 35번 새 프로세스로 실행(`chk` 마다 python 두 번)
- 종류: 섞임(동작 45 · 구조 10 · 글자 35 · 변이 10)
- 지키는 것: 프로필 넷의 frontmatter 가 열 필드 스키마를 지키고 자리별 값(defer 허용 · web · 층 2 범주 · seed 의 비어 있는 부류)과 seed 처분 안내의 비신뢰 원문 자리 문구가 정해진 대로여서, 한 자리의 리뷰 규칙이 다른 자리로 번지거나 원문 주입 경계가 약해지는 일을 막는다.
- 거짓 실패 위험: 높음 — 13번 고쳐졌고 프로필 본문의 긴 문장(정답 출처 · 층 2 규칙)과 범주 목록을 글자로 핀하므로 규칙을 다듬을 때마다 깨진다
- 겹침: shared/tests/test_docreview_profile_schema.sh — 배포 프로필 넷 통과 · 정확히 넷, 변이로 스키마 깨기(필드 누락 · 열한 번째 필드)가 겹친다
- 보안 갈래: 예 — 리뷰어 프로필 · 원문의 주입 경계(비신뢰 verbatim 문구)
- 판정 후보: 구조를 고침 — `chk` 가 호출마다 profile-check 와 python 을 새로 띄우므로 프로필당 한 번 JSON 으로 받아 재사용하면 싸진다. 변이로 이빨을 확인한 seed 계약은 보안이라 둔다
- 확신: 중간

### shared/tests/test_docreview_round_gate_split.sh
- 초: 0.2
- 줄 수: 129
- 고친 횟수: 8
- 크기: 작음 — grep 과 파일 읽기만
- 종류: 글자
- 지키는 것: 절차서와 spec-review 게이트 절이 질문을 최대 4개씩 나누고 「추가 라운드 1회 열기」를 별개 항목으로 같은 분할에 세며 내부 기호를 질문에 쓰지 않는 규칙을 싣고 있어서, 게이트 질문이 한 호출에 몰려 도구 한도를 넘거나 내부 번호가 사용자에게 노출되는 일을 막는다.
- 거짓 실패 위험: 높음 — 문장(`같은 4개씩 분할에 함께 세어지며`, `부재 건수를 함께 공시`)을 다듬으면 두 파일 모두에서 깨진다
- 겹침: shared/tests/test_docreview_procedure_paths.sh — 같은 절차서와 spec-review 를 읽는 다른 문구. test_ask_recommendation.sh 도 추천 문구 일부를 본다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 같은 문장을 절차서와 SKILL 두 곳에서 되풀이 핀하고 규칙은 한 줄씩이면 충분하다. 동작이 문장에 달린 규칙이라 지울 수는 없다
- 확신: 중간

### shared/tests/test_entry_dep_needs.sh
- 초: 1.5
- 줄 수: 153
- 고친 횟수: 3
- 크기: 중간 — SKILL.md 열 개마다 python 으로 펜스를 파싱하고 펜스를 잘라 bash 를 세 번 실행(약 30회)
- 종류: 섞임(동작 50 · 구조 40 · 글자 10 · 변이 0)
- 지키는 것: 모든 skill 진입에 의존 확인 펜스가 하나씩 있고 `--need` 목록이 정해진 대로이며 rc 3 이면 멈추고 루트가 비면 rc 1 로 멈춰서, 사용자가 의존이 없는 상태로 진입해 중간에 죽는 일을 막는다.
- 거짓 실패 위험: 중간 — skill 을 추가하면 expected_need 표를 같이 고쳐야 하고 `n_skill` 이 10 으로 박혀 있다
- 겹침: shared/tests/test_check_deps.sh — entry 서브커맨드 동작 일부를 겹쳐서 잰다. test_entry_preflight.sh 와는 다른 펜스
- 보안 갈래: 아니오
- 판정 후보: 둠 — 펜스를 실제로 잘라 돌려 진입 동작을 지키고 1.5초다
- 확신: 중간

### shared/tests/test_entry_preflight.sh
- 초: 2.7
- 줄 수: 260
- 고친 횟수: 7
- 크기: 중간 — 새 프로세스로 약 80번 실행, 임시 git 레포 · 한글 경로 레포 · 설치본 사본 구성
- 종류: 동작
- 지키는 것: 진입 사전 검사가 리포 안 · 비-git · .git 안 · 삭제된 cwd 에서 감시줄을 rc 0 으로 내고 kill switch 가 값이 정확히 "1" 일 때만 켜지며 끄기 변수 표가 망가져도 읽지 못함 한 줄로 내려가서, 사용자가 이상한 환경에서도 스킬 진입이 죽거나 끈 스위치가 무시되는 일이 없다.
- 거짓 실패 위험: 낮음 — 사전 검사 동작이 바뀔 때만 깨진다(환경변수는 깨끗한 환경으로 격리)
- 겹침: shared/tests/test_switch_tables.sh — 끄기 변수 표 읽기에서 일부 겹칠 수 있음(확인 못 함)
- 보안 갈래: 예 — kill switch 판정(값 "1" 만)과 끄는 스위치 은퇴 표시
- 판정 후보: 둠 — kill switch 보안 갈래를 동작으로 지키고 2.7초는 환경 가짓수에 맞다
- 확신: 높음

### shared/tests/test_inline_python_isolated.sh
- 초: 4.6
- 줄 수: 437
- 고친 횟수: 17
- 크기: 중간 — 코퍼스 전체를 스캔하고 임시 git 레포를 만들어 qg · plugin-audit 스크립트를 실제 실행(12개 모듈 이름을 심은 리포)
- 종류: 섞임(동작 45 · 구조 5 · 글자 50 · 변이 0)
- 지키는 것: 플러그인과 shared 의 인라인 python 호출이 `-I` 로 격리되고 검토 대상 리포에 심은 json.py 같은 표준 모듈 이름 파일이 실행되지 않아서, 리뷰 · 감사 대상 리포의 코드가 플러그인 안에서 임의로 실행되는 일을 막는다.
- 거짓 실패 위험: 높음 — 17번 고쳐졌고 새 python 호출 줄이나 의존 표 행이 바뀌면 EXEMPT_PATHS · EXEMPT_NEEDLES 목록을 손으로 맞춰야 깨짐이 풀린다
- 겹침: 못 찾음 — 인라인 python 격리를 재는 다른 테스트는 못 찾음
- 보안 갈래: 예 — 주입 · 임의 코드 실행(sys.path 하이재킹)
- 판정 후보: 구조를 고침 — 보안 방어는 둔다. 예외 목록을 줄 번호 없는 정체 키로 도출하고 행동 절의 임시 레포 준비는 한 번 만들어 쓰면 싸지고 덜 깨진다
- 확신: 중간

### shared/tests/test_no_new_duplication.sh
- 초: 1.0
- 줄 수: 341
- 고친 횟수: 8
- 크기: 중간 — 코퍼스 전 파일(약 445)을 python 으로 20줄 창 해시 스캔하고 단위별 git ls-files 를 여러 번 실행
- 종류: 동작
- 지키는 것: 20줄 이상 같은 블록이 copy-of · variant-of 로 설명되지 않은 채 두 파일에 생기지 않아서, 복제본이 한쪽만 고쳐져 갈라지는 일(드리프트)의 유입을 막는다.
- 거짓 실패 위험: 중간 — 새 파일에 기존 블록을 붙여 넣거나 플러그인을 추가하면 등식 가드가 반응한다(의도된 동작)
- 겹침: shared/tests/test_copy_of_contract.sh — 마커의 실재만 보고 실제 동일성은 그쪽에 위임하는 짝
- 보안 갈래: 아니오
- 판정 후보: 둠 — 복제 유입을 도출로 막고 vacuity 가드가 이빨 있게 짜였으며 1초다
- 확신: 높음

### shared/tests/test_plain_language_block.sh
- 초: 0.2
- 줄 수: 66
- 고친 횟수: 10
- 크기: 중간 — git ls-files + find + python 판정 모듈 한 번
- 종류: 섞임(동작 40 · 구조 10 · 글자 50 · 변이 0)
- 지키는 것: 모든 SKILL.md · 명령 파일이 「사람에게 쓰는 글」 블록을 정본과 같게 싣고 정본의 추천 · 순서 문장이 정해진 대로여서, 사용자에게 보이는 출력의 쉬운 말 규칙이 파일마다 갈라지는 일을 막는다.
- 거짓 실패 위험: 높음 — 10번 고쳐졌고 정본 문장(REC · NEW · EXA)을 글자 그대로 핀하므로 문구를 다듬을 때마다 깨진다
- 겹침: shared/tests/test_ask_recommendation.sh — 추천 문장(「(권장)」 꼬리)을 같이 핀한다
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 정본 문장 리터럴 핀 열 개 안팎이 같은 정본의 문구를 되풀이한다. 블록 동일성(판정 모듈)만 두고 정본 문장 핀은 줄일 수 있다
- 확신: 낮음

#### 읽지 못한 것 — shallow-10

없음. 32개 단위 전부를 끝까지 읽었다. 다만 다음은 대상 파일 전체가 아니라 호출 이름만 확인했다 — `shared/tests/fixtures/docreview/cases.sh` 의 case 본문(test_docreview_anchor.sh 가 부르는 케이스 · 겹침 판정 근거로 함수 이름만 봄), `shared/tests/ask_recommendation.py` · `plain_language_block.py` · `fixtures/adjudication/run_*.py` 의 내부, `docreview_state.py` 의 구현. 겹침 칸의 「못 찾음」 은 대상 이름을 grep 한 결과이고 내용 대조는 하지 않았다.

## 묶음 shallow-11

### shared/tests/test_plugin_description_parity.sh
- 초: 0.2
- 줄 수: 101
- 고친 횟수: 2
- 크기: 중간 — python 한 번 + 합성 트리 4개 (임시 폴더)
- 종류: 동작
- 지키는 것: plugin.json 과 마켓플레이스 항목의 소개 문구가 달라지면(또는 한쪽이 없거나 JSON 이 깨지면) 마켓플레이스에 뜨는 설명이 설치본과 어긋난다.
- 거짓 실패 위험: 낮음 — 두 소개 문구가 실제로 다를 때만 깨진다
- 겹침: plugins/plugin-audit/tests/test_check_staleness.py — 같은 술어(scan_description_drift)의 단위 시험이고 실제 트리를 재는 것은 이 파일뿐
- 보안 갈래: 아니오
- 판정 후보: 둠 — 싸고 동작을 직접 재며 자체 점검(양성 대조)이 있다
- 확신: 높음

### shared/tests/test_plugin_root_no_cwd_fallback.sh
- 초: 0.8
- 줄 수: 554
- 고친 횟수: 14
- 크기: 중간 — python 파서 한 번이 코퍼스 전체를 읽고, 대표 펜스 둘을 하위 셸로 실행
- 종류: 섞임(동작 약 10% · 구조 약 20% · 글자 약 70%)
- 지키는 것: skill · reference 의 bash 펜스가 플러그인 루트를 cwd 에서 만들거나 가드 없이 쓰면 설치본에서 사용자 저장소의 스크립트가 실행될 수 있다 — 행동 단언(미끼 스크립트가 돌지 않는다)이 그 핵심이다.
- 거짓 실패 위험: 높음 — 펜스 표기 · 주석 속 대입 문구 · 예약된 변수 이름(`PR` 등) · 가드 하한 숫자(44, 19)를 건드리기만 해도 깨진다. 머리말이 스스로 거짓 RED 셋을 인정한다
- 겹침: plugins/spec-distill/tests/test_epic_conductor_skill.sh · plugins/spec-distill/tests/test_finishing_block_scope.py 가 이름을 언급(겹치는 내용은 확인 못 함). 같은 문제의 다른 축은 못 찾음
- 보안 갈래: 예 — 경로 탈출 · cwd 코드 실행을 막는 가드
- 판정 후보: 구조를 고침 — 행동 단언(펜스 둘)은 두고, 셸을 흉내 낸 정규식 축(2b · C3~C6 · 회계 하한)을 실제 셸 파서나 더 적은 축으로 바꾸면 거짓 RED 와 수정 횟수가 준다
- 확신: 중간

### shared/tests/test_presence_corpus_behavior.sh
- 초: 2.6
- 줄 수: 150
- 고친 횟수: 2
- 크기: 큼 — 다른 테스트 셋(spec-distill 소비자 락)을 통째로 실행하고 그중 하나(채택자 락)를 두 번 돌린다
- 종류: 섞임(동작 약 80% · 구조 약 20%)
- 지키는 것: presence_corpus.sh 헬퍼의 판정(플러그인 레벨 공유 계약 거절 · 빈 코퍼스 실패)이 약해지면 그것을 쓰는 세 락이 한꺼번에 이빨을 잃는다.
- 거짓 실패 위험: 중간 — 소비자 출력 문구(「presence 대상 N개가 전부 skill 소유 표면」 · 「자기 표면 N파일」)에 의존하고, 소비자가 다른 이유로 느려지면 같이 느려진다
- 겹침: plugins/spec-distill/tests/test_conducting_interview_stage.sh · test_brief_review_entry.sh · test_proceed_gate_adopters.sh — 이 파일이 그 셋을 다시 실행한다(같은 소비자가 스위트에서 이미 한 번 돈다)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 헬퍼 판정 probe(1절)는 두고, 소비자를 다시 실행하는 2 · 3절은 소비자 락이 낸 출력을 재사용하거나 소비자 락 쪽 단언으로 내리면 2초대가 사라진다
- 확신: 중간

### shared/tests/test_python_floor.sh
- 초: 3.8
- 줄 수: 879
- 고친 횟수: 26
- 크기: 큼 — 케이스마다 해석기 셸을 새 프로세스로 띄운다(약 100회 이상, 임시 가짜 인터프리터 · PATH 조합)
- 종류: 섞임(동작 약 75% · 구조 약 15% · 글자 약 10%)
- 지키는 것: 훅 해석기가 바닥 미만 Python 을 건너뛰고, cwd 의 python3 · sh 를 집지 않고, kill switch 를 정확히 따르고, payload 를 그대로 넘기지 않으면 훅이 엉뚱한 인터프리터로 돌거나 사용자 저장소의 파일을 실행하거나 꺼 둔 훅이 돈다.
- 거짓 실패 위험: 중간 — 해석기 동작이 바뀔 때 깨지지만, README · dependencies.md 문구(축 F · G)와 hooks.json 형태 단언은 문구 다듬기에도 깨진다
- 겹침: shared/tests/test_copy_of_contract.sh(사본 일치) 와 일부 겹침(이름으로 확인 못 함 — 헤더가 언급). 해석기 행동 자체는 못 찾음
- 보안 갈래: 예 — kill switch · cwd 코드 실행 방지(축 I) · PATH 불신
- 판정 후보: 구조를 고침 — 해석기 동작(축 A · I · C2)은 둠, README · dependencies 글자 축(F · G · J)을 떼어 싼 파일로 옮기고, 케이스 공통 준비를 함께 쓰면 줄일 수 있다
- 확신: 중간

### shared/tests/test_runner_disposition.sh
- 초: 0.4
- 줄 수: 218
- 고친 횟수: 7
- 크기: 중간 — 도출기 python 한 번, 이후 파일 grep 과 git ls-files 스냅샷
- 종류: 섞임(구조 약 70% · 글자 약 20% · 동작 약 10%)
- 지키는 것: codex 러너 스크립트가 처분 앵커(consumer · fail-open/closed · disclosure)를 밝히고 consumer 경로가 같은 플러그인의 추적되는 파일이 아니면 설치본에서 판정 소비자가 도달 불가인 채 남는다.
- 거짓 실패 위험: 중간 — 러너 파일 이동 · 앵커 문구 변경 · 명시 제외 목록(한 줄)에 민감하다
- 겹침: shared/tests/test_dispatch_disposition.sh — 머리말이 같은 규칙(추적 + 동일 플러그인)을 다른 언어로 독립 구현했다고 밝힘(직접 대조는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 합침 — 같은 규칙을 두 언어로 구현한 형제와 한쪽으로 모을 수 있다(합침 시 도출기 공유 필요)
- 확신: 낮음

### shared/tests/test_shell_tests_executable.sh
- 초: 2.0
- 줄 수: 40
- 고친 횟수: 2
- 크기: 중간 — 고른 셸 테스트(수백 개)마다 awk 를 새로 띄워 git ls-files -s 목록을 훑는다
- 종류: 구조
- 지키는 것: 스위트가 고르는 셸 테스트 중 100755 가 아닌 것이 있으면 러너가 그 테스트를 건너뛰어 조용히 검사를 잃는다.
- 거짓 실패 위험: 낮음 — 새 테스트에 실행 비트를 안 줬을 때만 깨진다(run-all.sh 의 find 줄 모양이 바뀌면 추출 실패로 깨짐)
- 겹침: 못 찾음(같은 현상을 지키는 테스트는 이름으로 찾지 못했다 — 메모리의 qg 어댑터 not-certified 사례와 같은 현상일 수 있으나 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 그대로이고 파일당 awk 호출 대신 awk 한 번으로 목록을 대조하면 2.0초가 줄어든다
- 확신: 높음

### shared/tests/test_skill_body_no_positional_tokens.sh
- 초: 0.2
- 줄 수: 180
- 고친 횟수: 5
- 크기: 중간 — python 세 번(스캐너 · 표본 생성 · 양성 대조)과 find · git check-ignore
- 종류: 섞임(동작 약 60% · 글자 약 40%)
- 지키는 것: SKILL.md · command 본문에 `$0`~`$9` 같은 위치 인자 토큰이 있으면 호출 인자로 치환돼 셸 펜스(예: rm -f 대상)가 의도와 다른 값으로 바뀐다.
- 거짓 실패 위험: 낮음 — 금지 토큰을 쓸 때만 깨진다(셸 함수 인자 · awk 필드도 걸리는 것이 의도)
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 실측된 사고(인자로 치환돼 audit 이 지워짐)를 막고 양성 · 음성 대조가 있으며 싸다
- 확신: 높음

### shared/tests/test_skill_cost_class_place.sh
- 초: 1.4
- 줄 수: 119
- 고친 횟수: 2
- 크기: 중간 — SKILL.md 마다 python 을 새로 띄우고(수십 회) 임시 git 레포 둘을 만든다
- 종류: 섞임(동작 약 55% · 구조 약 25% · 글자 약 20%)
- 지키는 것: skill 의 cost_class 가 frontmatter 의 맨 위에 남거나 metadata 밖에 있으면 비용 선언을 읽는 쪽이 값을 못 읽고, disallowed-tools 를 쓰는 skill 이 생기면 알린다.
- 거짓 실패 위험: 중간 — 열 개 skill 의 cost_class 값을 이름으로 핀해, 값을 바꾸는 정당한 변경에도 깨진다
- 겹침: shared/tests/test_invocation_surface.sh 와 shared/entry/check_invocation_surface.py 를 공유(축 E 의 모르는 키 검사 부분이 겹치는지는 확인 못 함)
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — SKILL.md 마다 python 을 띄우는 것을 한 번의 python 스캔으로 바꾸고, 이름별 값 핀(10줄)은 줄이면 싸지고 덜 깨진다
- 확신: 중간

### shared/tests/test_skill_reference_pointers.sh
- 초: 1.1
- 줄 수: 351
- 고친 횟수: 12
- 크기: 중간 — 포인터마다 서브셸 · awk(norm_path)를 띄우는 bash 루프, git ls-files
- 종류: 섞임(구조 약 85% · 동작 약 15%)
- 지키는 것: SKILL.md · references 가 가리키는 references/*.md 가 없거나(소실) 아무도 가리키지 않으면(고아) 모델이 읽을 절차 전문이 조용히 사라지거나 죽은 사본이 설치본에 남는다.
- 거짓 실패 위험: 중간 — 파일 옮기기 · 포인터 표기 변경(접두사 형태 열거 밖)에 깨진다. 단 그것이 의도된 경고다
- 겹침: shared/tests/test_dispatch_name_defined.sh · shared/tests/test_agent_input_slots.sh · plugins/spec-distill/tests/test_epic_conductor_skill.sh 가 이름을 언급(겹치는 내용은 확인 못 함). test_plugin_root_no_cwd_fallback.sh 의 축 3 이 Read 포인터 일부를 따로 본다
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 지키는 것은 그대로이고 bash 루프(포인터마다 프로세스)를 python 한 번의 해석기로 바꾸면 빨라지고 norm_path · resolve_target 흉내가 단순해진다
- 확신: 중간

### shared/tests/test_switch_tables.sh
- 초: 0.6
- 줄 수: 240
- 고친 횟수: 4
- 크기: 중간 — 절마다 python 을 새로 띄우고 플러그인별 git ls-files 를 호출
- 종류: 섞임(구조 약 40% · 글자 약 60%)
- 지키는 것: 끄기 변수 표(switches.md) · README 끄는 길 표 · 실제로 변수를 읽는 코드가 어긋나면 사용자가 끈다고 믿는 변수가 아무것도 끄지 못한다.
- 거짓 실패 위험: 높음 — 표 27행의 이름 · 상태 · 별칭과 개수(27 · 7 · 20 · 0)를 리터럴로 핀했고 README 구절 8개를 글자로 본다. 은퇴 판마다 같이 고쳐야 한다(스스로 그렇게 적어 둠)
- 겹침: shared/tests/test_entry_preflight.sh — 같은 사전 검사 모듈을 시험(표 읽기는 겹칠 수 있으나 확인 못 함)
- 보안 갈래: 예 — 끄는 스위치(kill switch)
- 판정 후보: 줄임 — 절 C(README 표 = switches.md 바이트 일치)와 D(읽는 곳 존재)는 두고, 절 B · B2 의 리터럴 핀(개수 · 행 전수)은 표를 두 번 쓰는 셈이라 덜어도 지키는 것이 같다
- 확신: 중간

### shared/tests/test_test_selection_bundle.sh
- 초: 0.9
- 줄 수: 75
- 고친 횟수: 6
- 크기: 중간 — 임시 폴더에 링크 · 사본을 만들고 스크립트를 열두 번 가까이 실행, git log 로 이력을 조회
- 종류: 섞임(동작 약 55% · 구조 약 45%)
- 지키는 것: 테스트 선택 스크립트 넷이 링크로 배포될 때 링크 · 다른 플러그인 링크 · 링크를 푼 설치본 사본이 같은 결과를 내지 않으면 설치본에서 형제 스크립트를 못 찾아 동작이 달라진다.
- 거짓 실패 위험: 중간 — 얕은 클론이면 처음 더한 커밋을 못 찾아 실패한다. 이동 전후 blob 일치 단언은 한 번 일어난 이동의 역사 단언이라 정상 편집과 무관하게 이력에 묶인다
- 겹침: plugins/quality-gates/tests/test_run_test_selection.sh 가 같은 스크립트의 동작을 별도로 시험(링크 배포 관점은 이 파일뿐으로 보임)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 링크 · 설치본 사본 동작 대조(후반부)는 두고, 이동 전후 blob 이 같다는 역사 단언(전반부)은 일회성이라 덜어도 지키는 것이 같다
- 확신: 중간

### shared/tests/test_variant_of_contract.sh
- 초: 2.2
- 줄 수: 423
- 고친 횟수: 10
- 크기: 큼 — python 을 케이스마다 새로 띄우고(약 100회) 중복 락 스크립트를 스크래치 git 레포에서 다시 실행
- 종류: 섞임(동작 약 85% · 구조 약 10% · 글자 약 5%)
- 지키는 것: variant-of 마커의 판정기가 숨은 frontmatter 키(tools · permissionMode 를 YAML 이 다르게 읽는 모양)를 통과시키면 agent 변형이 도구 전체를 상속하거나 권한 모드를 숨겨 얻고도 중복 락 면제를 받는다.
- 거짓 실패 위험: 낮음 — 판정기 동작이 바뀔 때만 깨진다(마커 파일 집합 리터럴 목록과 agent 파일 수 하한 18 은 정당한 추가에도 같이 고쳐야 한다)
- 겹침: shared/tests/test_no_new_duplication.sh(V3 에서 실행 대상으로 다시 돎) · shared/tests/test_docreview_agents.sh · plugins/quality-gates/tests/test_agent_frontmatter_keys.sh 가 variant-of 를 언급(겹치는 내용은 확인 못 함)
- 보안 갈래: 예 — 리뷰어 agent 프로필(tools 허용 목록 · 권한 모드) 무력화 방지
- 판정 후보: 구조를 고침 — 판정기 음성 셀은 둠, 셀마다 python 을 새로 띄우는 것을 한 번의 python 일괄 호출로 바꾸고 V3(중복 락 재실행)은 중복 락 쪽으로 옮기면 줄어든다
- 확신: 중간

### shared/tests/test_window_phrases.sh
- 초: 0.7
- 줄 수: 73
- 고친 횟수: 2
- 크기: 작음 — 파일 읽기와 grep 뿐(목록 파일마다 grep 을 띄움)
- 종류: 글자
- 지키는 것: 글자만 지킴 — 질문 창 밖의 글을 가리키는 옛 문구 5개가 skill · reference · agent 에 돌아오지 않았는지, 새 문장 18곳이 그 파일에 그대로 있는지(plain-language.md 외 여러 skill 파일의 문구)
- 거짓 실패 위험: 높음 — 문구를 다듬기만 해도 양의 짝 18곳이 깨진다. 문구 수 5 · 양의 짝 글자도 리터럴 핀이다
- 겹침: tools/plain-language/test_measure_questions.py 가 같은 문구 목록 파일을 읽는다(글자 대조는 아님)
- 보안 갈래: 아니오
- 판정 후보: 줄임 — 부재 검사(옛 문구가 돌아오지 않음)는 두고 양의 짝 18곳의 글자 핀은 줄이는 편이 낫다(문구가 동작을 정하는지는 이 파일만으로 판단되지 않음)
- 확신: 낮음

### shared/tests/test_writer_trust_notice.sh
- 초: 1.5
- 줄 수: 133
- 고친 횟수: 8
- 크기: 중간 — 엔진 스크립트를 여러 번 python 으로 띄워 임시 상태 폴더에서 게이트를 렌더하고 bash -c 하위 셸 실행
- 종류: 섞임(동작 약 30% · 글자 약 70%)
- 지키는 것: 리뷰 결과 머리의 「쓰는 세션을 믿는 한계」 공시 문장이 엔진 출력 · gate JSON · README 한계 절에서 어긋나거나 빠지면 사용자가 기록 위조 한계를 모르고 리뷰를 믿는다.
- 거짓 실패 위험: 높음 — README 한계 절의 불릿 문장(P21 · P14 · 샌드박스 줄)을 글자 그대로 핀했고 절 순서도 본다. 문구 다듬기만으로 깨진다
- 겹침: plugins/spec-distill/tests/test_roadmap_status.sh 가 WRITER_TRUST_NOTICE 를 언급(겹치는 내용은 확인 못 함). shared/tests/fixtures/docreview/cases.sh 를 다른 docreview 테스트와 공유
- 보안 갈래: 아니오
- 판정 후보: 구조를 고침 — 엔진 렌더 동작 단언(둠)과 README 불릿 글자 핀을 분리하고, 글자 핀은 한 불릿당 핵심 구절 하나로 줄이면 덜 깨진다
- 확신: 중간

### tools/plain-language/test_measure_output.py
- 초: 0.0
- 줄 수: 233
- 고친 횟수: 5
- 크기: 작음 — 한 프로세스 안, 임시 폴더에 jsonl 을 쓴다
- 종류: 동작
- 지키는 것: 대화 기록 측정 도구가 턴 경계 · 중복 uuid · 고정된 manifest · 질문 상태 줄 · 영어 최종 보고를 틀리게 세면 쉬운 말 출력의 전후 비교가 거짓 개선으로 읽힌다.
- 거짓 실패 위험: 중간 — qg SKILL.md 의 질문 틀(`question: "qg …"`)을 실제 파일에서 읽어 쓰는 단언이 있어 문구 바뀜에 깨진다(의도된 연동)
- 겹침: 못 찾음
- 보안 갈래: 아니오
- 판정 후보: 둠 — 레포 측정 도구의 동작 시험이고 비용이 거의 0 이다
- 확신: 높음

### tools/plain-language/test_measure_questions.py
- 초: 0.0
- 줄 수: 167
- 고친 횟수: 1
- 크기: 작음 — 한 프로세스 안, 임시 폴더에 jsonl 을 쓴다
- 종류: 동작
- 지키는 것: 질문 측정 도구가 직전 skill 귀속 · 창 밖 문구 · 권장 질문 · 지적 id 짝짓기 · 중복 제거 · 쓰기 없음을 틀리게 하면 질문 개선 측정값이 틀린다.
- 거짓 실패 위험: 낮음 — 도구 동작이 바뀔 때만 깨진다(출하된 window_phrases.txt 에 「위에 적었다」 가 있다는 단언 하나만 문구 의존)
- 겹침: shared/tests/test_window_phrases.sh — 같은 문구 목록 파일을 읽지만 지키는 것은 다르다
- 보안 갈래: 아니오
- 판정 후보: 둠 — 싸고 동작을 직접 재며 겹치는 것이 없다
- 확신: 높음

#### 읽지 못한 것 — shallow-11
없음 (열여섯 파일 모두 끝까지 읽었다. 단 고친 횟수는 `git log --name-only` 로 센 값이라 이름 변경 이력은 반영되지 않았을 수 있다. 「겹침」 중 이름 언급만 확인한 항목은 내용 대조를 하지 않았다고 표기했다)
