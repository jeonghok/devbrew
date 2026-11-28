# 있는 테스트 정리 PR 5 — quality-gates 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자가 승인한 PR 5 판정 표(114행)대로 `plugins/quality-gates/tests/` 를 정리한다 — 준비물을 한 번 지어 복사하고(대상 6 · 범위 배선) · 겹치는 확인을 지우거나 받는 쪽으로 옮기고 · 글자에 묶인 확인을 뜻 낱말로 줄이고 · 작업 트리를 건드리는 테스트를 사본 안으로 옮기며, 사라진 확인마다 `docs/removed-tests.md` 에 한 줄을 남긴다.

**Architecture:** 두 묶음이다. 묶음 A(과제 1–22)는 표시 없는 98행이고 지금 바로 한다. 묶음 B(과제 23–30)는 「#347 머지 뒤 다시 읽음」 16행(과 같은 파일이라 함께 미룬 표시 없는 셋)이고, 끄기 변수 은퇴 PR(#347)이 머지된 뒤 기본 브랜치를 합치고 다시 읽어 판정이 표와 같을 때만 고친다. 보안 확인을 옮기거나 고치는 과제는 고치기 전 사본(옛)과 고친 뒤 사본(새)에 같은 변이 넷(삭제 · 추가 · 반전 · 형태 바꾸기)을 걸어 옛이 잡는 것을 새도 잡는지 견주고, 변이 없는 사본으로 양성 대조를 본다.

**Tech Stack:** bash(`shared/tests/assert.sh` — `/usr/bin/env bash` 가 3.2 일 수 있다) · python3(스위트의 `python3` 는 3.9 — 3.9 문법만) · unittest · git · `perl -e 'alarm …'`(macOS 에 `timeout` 이 없을 때 시간 상한).

**Spec:** `docs/superpowers/specs/2026-11-26-test-prune-design.md` — §1 의 PR 5 몫 · §4 대상 1–6 · §5 · §6 · §7. 범위는 승인된 판정 표가 정한다: `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/relay/E4/table-pr5-final.md`(원문 `table-pr5-a.md` · `table-pr5-b.md` — 같은 폴더). 승인 줄은 설계문서 끝 「판정 표 승인 · 2026-11-28 · PR 5」. 사용자 답 셋: 갈림 19개 「권하는 쪽 그대로 (권장)」 · 「한 PR 로 (권장)」 · #347 이 고치는 16행 「#347 머지 뒤 다시 읽고 이 PR 에 (권장)」. 표의 행은 아래에서 `표 1절 <파일> <케이스>` 처럼 절과 첫 칸으로 부른다.

## AC 가르기

| AC | 과제 |
|---|---|
| AC1 · AC2 | 과제 30(PR 본문 재료 — 승인 표 · 승인 줄 · 읽은 담당자 A · 다시 읽은 담당자 B · 갈린 행) |
| AC6 | 과제 1 Step 4(고칠 행이 표의 행뿐) · 과제 22 · 29 의 바뀐 파일 대조 |
| AC7 | 과제 4 · 14 · 16 · 17 · 18 · 19 · 24 의 변이 표 |
| AC8 | 지우는 과제마다 기록 줄 · 과제 22 · 29 의 줄 수 대조 · 과제 30 Step 6(PR 번호) |
| AC9 | 과제 2 · 6 · 7 · 8 의 지우기 전 찾기 · 과제 22 Step 2 |
| AC10 | 과제 22 · 29 의 §5 점검 · 테스트 다섯 |
| AC11 | 과제 21 · 29 Step 1 |
| AC12 · AC14 | 과제 22 · 29 의 금지 파일 대조 |
| AC13 | 미룸 — 지휘자 대조(전체 스위트는 이 계획에 없다) |
| AC15 | 과제 30 Step 4(「없음」 — 표) |
| AC16 | 과제 4 · 19 · 20 · 2(사용자 홈에 쓰던 `test_cost_consent.sh` 지움) |
| AC3 · AC4 · AC5 · AC17 | 이 PR 몫이 아니다 — 과제 30 의 리뷰가 「미룸 — 다른 PR(PR 1 · 2 · 3 · 로드맵 끝)」 으로 적는다 |

대조 스크립트에 주는 목록: `AC1,AC2,AC6,AC7,AC8,AC9,AC10,AC11,AC12,AC13,AC14,AC15,AC16`.

## Global Constraints

- **표에 없는 테스트는 고치지 않는다**(설계 §2 걸음 3). 「둠」 행은 건드리지 않는다. 고칠 파일 목록은 과제 1 Step 4 가 표에서 뽑은 것뿐이다 — 그 밖의 파일은 표가 「같은 PR 에서 고칠 주석」 으로 든 다섯(`plugins/quality-gates/tests/test_plain_qg_templates.sh:75` · `test_codex_backward_compat.sh` 머리말 · `test_topic_boundary.sh` 「정합 2/2」 짝 주석 · `shared/tests/test_adjudication_wiring.sh:29` · `plugins/spec-distill/tests/test_brief_review_meta.sh:21` · `test_readme_sync.sh:14`)과 `docs/removed-tests.md` 다. 구현 중 새 후보를 찾으면 고치지 않고 보고에 적는다.
- **보안 확인**(표 「보안 확인이 섞였는가」 칸의 줄 범위)은 첫째 줄 · 넷째 줄로 지우거나 줄이지 않는다. 옮기거나 고친 보안 확인은 변이 넷과 양성 대조를 구현 보고에 싣는다(`docs/testing.md` 「망가뜨려 보기」). 「보안처럼」 으로 표시된 범위(range_wiring :109–127 · :209–265 · codex_copies_agree 층④ 등)도 같다.
- **변이 견주기의 꼴.** 사본은 `git archive <커밋> | tar -x -C "$TMPDIR/e4-pr5/<이름>"` 로 뜬다(작업 트리를 고치지 않는다 · 심볼릭 링크가 링크로 남는다). 옛 = 그 과제의 고치기 전 커밋, 새 = 고친 커밋. 사본마다 같은 변이를 같은 글자로 건다 — 변이 자리가 0개 · 둘 이상이면 그 변이는 무효로 보고 자리를 고친다. 돌릴 때 `PYTHONDONTWRITEBYTECODE=1`. 각 변이에 기대: 옛에서 ✗ 가 나면 새에서도 ✗. 변이 없는 사본은 둘 다 실패 0(양성 대조). **옛만 잡는 변이가 나오면** 그 변이를 잡는 단언을 받는 쪽 테스트로 옮겨 다시 견준다(옮긴 단언은 보고에 적는다). 받는 쪽이 이 PR 의 파일이 아니면 멈추고 보고한다.
- **보안이 아닌 확인을 옮기기만 했으면** 옮긴 뒤 사본에서 그 확인이 지키던 코드 · 문장을 한 번 망가뜨려 ✗ 를 본다(실패를 먼저 본다). **줄인 확인**(넷째 줄)은 남긴 뜻 낱말이 든 문장을 지운 사본에서 ✗ 를 한 번 본다.
- **지운 확인의 기록 줄**은 `docs/removed-tests.md` 머리 그대로다: `- <지운 날> · <테스트 파일[ · 케이스]> · 지키던 것: <한 문장> · 판정: <「값 대비 비용」 의 어느 줄> · 지금 지키는 것: <테스트 경로 | 없음 — 받아들임> · PR #<번호>`. 한 줄의 「지키던 것」 · 「지금 지키는 것」 은 표의 그 행 칸을 옮긴다. 옮긴 합침과 넷째 줄임은 줄을 남기지 않는다. 새 줄은 `## 항목` 아래 끝에 붙인다.
- 새 파일을 만들지 않는다(준비물 확인은 그 준비물을 쓰는 테스트 파일 안 — 설계 「테스트할 자리」). 실행 비트를 바꾸지 않는다 — 고친 셸 테스트는 `git ls-files -s` 로 100755 를 확인한다.
- 판을 올리지 않는다. `plugin.json` · `CHANGELOG.md` · `plugins/spec-distill/tests/test_stage_prose_trim.sh` · `docs/testing.md` 를 바꾸지 않는다(AC12 · AC14).
- bash 3.2: 연관 배열 · `${v,,}` · `coproc` 없음. `$v` 바로 뒤에 한글 · 「」 가 오면 `${v}`. `$( )` 안에 here-doc 을 두지 않는다. Bash 도구의 셸은 zsh 다 — 파이프 종료 코드는 `bash -c` 안에서 잡는다. 셸 안 python 은 파일 읽기 · 쓰기에 `encoding="utf-8"`.
- **전체 스위트(`tools/suite/run-all.sh`)는 이 계획에서 돌지 않는다.** 과제는 고친 파일 · 받는 쪽 · 그 파일을 읽는 레포 락만 돈다. 전체 스위트는 지휘자의 머지 전 대조가 한 번 돈다(AC13 은 「미룸 — 지휘자 대조」).
- **시간 재기는 공유 잠금 아래에서만**: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner e4-impl-qg --wait 7200 -- bash "$TMPDIR/e4-pr5/time.sh" <목록 파일> <결과 tsv>`. `time.sh` 는 목록의 파일마다 셸이면 `/usr/bin/time -p bash <파일>`, python 이면 `/usr/bin/time -p python3 <파일>` 을 한 번 돌려 `real` 초와 시작 · 끝 `uptime` 을 적는다. 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다.
- git: 커밋은 pathspec 으로만(`git add -- <경로>` · `git commit -m … -- <경로>`). Conventional Commits(`test(qg): …` — 설명은 한국어). 본문 끝: `Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md` 와 `Co-Authored-By: <그 agent 의 모델 이름> <noreply@anthropic.com>`. 금지: `git stash` · `git checkout --` · HEAD 뒤로 옮기기 · 공유 임시 폴더 glob 삭제 · 다른 worktree 의 git. 경로 꼴은 `'plugins/*/tests/*'`(`'plugins/*/tests'` 는 0건이다).
- `TMPDIR` 은 지휘자가 준 폴더이고 기준값 · 보고 · 사본은 그 아래 `e4-pr5/` 에 둔다. 격리 자리의 셸이 복합 명령을 막으면 스크립트 파일로 써서 `bash <파일>` 로 돈다.
- 하위 agent 를 띄울 때마다 superpowers subagent-driven-development 의 「Model Selection」 으로 모델을 골라 이름으로 지정하고 이유를 한 줄 적는다. 과제 리뷰어에게 「계획이 쓴 테스트 코드」 를 그렇다고 밝힌다.
- 설계 · 승인 표의 판정 · 수용 기준을 바꿔야 할 것 같으면 스스로 정하지 말고 멈춰 지휘자에게 보고한다.

## Review Focus

1. **준비물 사본이 원본을 가리킨다.** `cp -R` 한 클론 R 의 `origin` 이 원본 A 를 가리키면 케이스끼리 상태가 샌다 — 사본 R 의 `origin` 은 사본 A 다(과제 16 · 24 의 사본 확인).
2. **사본의 `.git` 에 원본 절대 경로가 박힌다**(worktree 메타 · `copytree` 의 링크). 사본의 `.git` 에서 원본 경로 `grep -rlF` 0건(과제 13 · 16 · 24 · 25).
3. **같은 계산 결과를 나눠 쓰다 한 시험이 그 결과를 고친다.** 다음 시험이 고친 값을 받지 않는다 — 깊은 복사(과제 15 의 격리 시험).
4. **출력을 함께 쓰는 케이스의 연쇄.** 앞 케이스가 만든 worktree 가 뒤 케이스의 「`head-` worktree 0」 단언을 깨지 않게 지운 뒤 다음으로 간다 — 지우지 않은 사본에서 그 단언이 ✗ 인 것을 한 번 본다(과제 14 Step 5).
5. **감지기 부재 시나리오가 실제 배포 지점을 건드린다.** 고친 뒤에는 테스트가 끝난 뒤(정상 · 실패 모두) `git status --porcelain -- plugins shared` 가 비어 있다 — 링크를 지우는 자리는 사본뿐이다(과제 19 Step 4 · 과제 20 Step 4 · 과제 4 Step 4 같은 꼴).

## 계획의 판단

설계 · 표가 계획에 맡겼거나 정하지 않아 이 계획이 정한 것이다. ✎ 는 「설계 · 표에 없던 결정」 — 지휘자에게 돌려보내는 자리다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| K1 ✎ | #347 이 고치는 파일의 표시 없는 행 | `test_intent_critic.py` TestFilteredListed(②) · `test_plain_readme.sh` 남김 행 · `test_governance_no_capability_caps.sh` 부분 핀(B-6)을 묶음 B 로 미룬다. TestConfig · CLI 357 · AC8a 는 둠이라 할 일이 없다 | 표 끝 문단이 구현 담당자에게 맡겼다. #347 이 세 파일을 크게 고쳐(intent_critic :1148–1160 · :3290–3321 · plain_readme :118–121 · governance FIXED_P22_2 와 끝 17줄) 한 번 다시 읽고 한 번 고치는 쪽이 충돌이 적다. plain_readme 남김 행의 기록 줄은 문단 행의 줄과 하나다 | 묶음 A 에서 먼저 |
| K2 ✎ | backward_compat 「거절 갈래 둘」 | 셋째 확인의 거절 갈래 넷(빈 지문 · 자기 등재 · 등재된 파일 없음 · .py 실행기) 가운데 **빈 지문 · 자기 등재** 를 넷째 확인의 가짜 원장 갈래로 더한다 | 등재된 파일 없음은 그 갈래가 빠져도 출력에 FAIL 줄이 없어 빈 지문 갈래가 받는다. 자기 등재가 빠지면 안쪽 실행이 끝없이 자기를 다시 돈다. 빈 지문은 받는 자리가 없다 | 등재된 파일 없음 · .py |
| K3 ✎ | 「안쪽 실행 표지 노출」 의 꼴 | `CODEX_COMPAT_INNER` 가 켜져 있으면 첫 출력 줄로 `  NOTE: CODEX_COMPAT_INNER=1 — 셋째 확인만 돈다(넷째 확인을 건너뛴다)` 를 낸다 | 표지가 바깥 실행에 새면 넷째 확인이 조용히 빠진다(E1 미룸) — 출력에 보이게 한다 | 표지가 새면 실패 |
| K4 ✎ | spec-distill 주석 둘 | `test_brief_review_meta.sh:21` · `test_readme_sync.sh:14` 의 「qg 쪽 test_artifact_metadata.sh 와 동형」 을 지운 파일을 가리키지 않게 이 PR 에서 고친다(주석만) | 표 「§5 요약 — 같은 PR 에서 고칠 주석」 을 따랐다. 1절이 아닌 2절 행의 「PR 4 가 손봄」 과 갈린다 | PR 4 에 맡김 |
| K5 ✎ | V1 의 「열거 밖 사유 exit 4」(:28–29) | 그대로 둔다 | 표의 V1 행이 옮길 것(:26–27 · :31–34)과 지울 것(:35–37)만 들고 이 두 줄은 말하지 않는다 | 함께 옮김 |
| K6 ✎ | codex_gate_observation 의 변이 | 표 「확인 방법」 이 든 세 범위(:56–117 · :209–221 · :252–330)마다 변이 넷 | 표 문면 그대로. 고친 자리는 감지기 부재뿐이지만 표가 세 범위를 함께 들었다 | 감지기 부재만 |
| K7 ✎ | 옛만 잡는 변이 | 받는 쪽 테스트로 그 단언을 옮겨 다시 견준다(Global Constraints) | 지휘자 지시(앞 PR 의 교훈). 표에 없던 단언이 받는 쪽에 더해질 수 있다 | 멈추고 보고 |
| K8 ✎ | 준비물 사본 확인 | 한 번 지어 복사하는 준비물마다(topic_boundary · range_wiring · other_teams · review_diff · intent_critic · intent_wide) 그 파일 안에 격리 확인 하나를 더한다 — 그 파일의 Total 이 는다 | 설계 「테스트할 자리」 의 첫 줄 | 사본 확인을 구현 보고에만 |
| K9 ✎ | 「판정 미룸」 행(TestRender · TestRecordSilentDrops · TestRecordUnreadAnswers) | 다시 읽어 판정을 내되 고치지 않고 지휘자에게 올린다 — 사용자 동의가 오면 그때 고친다 | 표가 승인한 것은 「다시 읽고 가른다」 이고, 가른 판정은 아직 승인받지 않았다 | 다시 읽은 판정대로 고침 |
| K10 ✎ | 묶음 B 의 앞 시간 | #347 을 합친 뒤 · 고치기 전에 잰다 | #347 이 그 파일들을 고쳐 합치기 전 시간은 견줄 기준이 아니다 | 과제 1 에서 함께 |
| K11 | #347 이 이미 머지된 경우 | 과제 1 Step 0 에서 과제 23 의 합침 · 다시 읽기를 먼저 하고 과제 2 부터 간다 | 다시 읽기를 두 번 하지 않는다 | — |
| K12 ✎ | topic_head ③ 의 꼴 | `case_two_siblings_combined` · `…accepts_derived_commit` · `…rejects_wrong_commits` 셋을 한 함수 `case_two_siblings_shared` 안의 차례(합친 트리 → accepts → worktree 지움 → rejects 첫 셋 → later.txt → stale · `head-` 0)로 합친다. 단언 글은 그대로 둔다. `case_no_side_effects` 는 따로 | 표 「한 레포를 세워 th 를 한 번 돌리고 그 출력을 셋이 함께 쓴다」 를 셸에서 지키는 가장 짧은 꼴 | 파일 전역 변수로 나눠 씀 |
| K13 | 시간 재기 | Global Constraints 의 `time.sh`. 묶음 A 는 과제 1 · 22, 묶음 B 는 과제 23 · 29 | 사용자 규칙(대상 파일만 · 공유 잠금) | — |
| K14 | PR | PR 을 여는 것은 지휘 흐름이다. 이 계획은 PR 본문 재료까지 만든다 | 앞 PR 들과 같다 | — |

---

## 파일 표

`plugins/quality-gates/tests/` 기준(다른 폴더는 레포 기준).

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `test_artifact_metadata.sh` · `test_cost_consent.sh` · `harness/run_consent_gate.sh` · `test_impact_runtime_docs.sh` · `test_readme_state_diagram_complete.sh` · `test_synthesize_artifact_adjudication.py` | 지움 | 2 |
| `shared/tests/test_adjudication_wiring.sh` · `plugins/spec-distill/tests/test_brief_review_meta.sh` · `plugins/spec-distill/tests/test_readme_sync.sh` | 주석 한 줄씩 | 2 |
| `test_agent_model_unpinned_sweep.sh` · `test_artifact_critic_frontmatter.sh` · `test_artifact_adversarial_frontmatter.sh` | 겹친 줄 지움 | 3 |
| `test_detect_codex.sh` | Case 13 · 14 를 사본에서 | 4 |
| `test_codex_backward_compat.sh` · `test_codex_dispatch_invariant.sh` | Check 1 · 2 지움 · 2c 옮김 · 갈림 ④ | 4 · 5 |
| `test_failure_injection.sh` · `mocks/mock-codex-no-agent-message.sh` · `mocks/mock-codex-valid-json-no-fence.sh` · `test_findings_parser.sh` | 옮기고 지움 | 6 |
| `test_isolation.sh` · `test_worktree.sh` | T1 · T2 옮김 · 나머지 지움 | 7 |
| `test_security_reviewer_behavior.py` · `test_agent_stub_harness.py` · `harness/agent_stub.py` | 가짜 응답 도우미 지움 | 8 |
| `test_readme_scope_reconcile.sh` · `test_artifact_critique_truths.sh` | README 글자 단언 지움 | 9 |
| `test_skill_orchestration.sh` · `test_plain_qg_templates.sh` · `test_lowered_gate_wiring.sh` | 낮춘 지적 질문 이음매 | 2(:75 주석) · 10 |
| `test_one_pipeline_surface.sh` · `test_topic_scope_wiring.sh` · `test_review_scope_composition.sh` | 넷째 줄임 | 11 |
| `test_differential_procedure.sh` · `test_v_requirements.sh` · `test_v1_verdict_line.sh` · `test_runtime_contract_invariance.sh` · `test_codex_result_banner.sh` · `test_git_derived_scope.sh` | 겹침 지움 · V1 옮김 | 12 |
| `test_topic_boundary.sh` | ① · 겹침 지움 | 13 |
| `test_topic_head.sh` | 훅 케이스 지움 · ③ | 14 |
| `test_other_teams.py` | ③ | 15 |
| `test_range_wiring.sh` | ① ③ · 글자 핀 · 줄임 · README | 16 · 17 |
| `test_codex_copies_agree.sh` | 층④ 한 경로 | 18 |
| `test_codex_gate_observation.sh` | 감지기 부재를 사본에서 | 19 |
| `test_agent_model_mutation.sh` | 변이를 사본에서 | 20 |
| `harness/test_skill_orchestration_behavior.sh` | 묘비 · 이력 주석 | 21 |
| `test_review_diff.sh` | ① ② | 24 |
| `test_intent_critic.py` · `test_intent_wide.py` · `test_intent_return.py` | ① · TestGate 옮김 · ② · 재판정 | 25 · 26 |
| `test_pipeline_verdict_wiring.sh` · `test_plain_readme.sh` · `test_critiquing_artifacts_skill.sh` · `test_e2e_docs.sh` | 줄임 · README 지움 | 27 |
| `test_governance_no_capability_caps.sh` | 뜻 낱말로 줄임 | 28 |
| `docs/removed-tests.md` | 사라진 확인마다 한 줄 | 지우는 과제마다 · 30 |

---

## 묶음 A — 지금 하는 98행

### Task 1: 다시 확인 · 기준값 · 고치기 전 시간

**Files:** 없음(`$TMPDIR/e4-pr5/` 아래)

- [ ] **Step 0: #347 상태** — `gh pr view 347 --json state,mergedAt`. `MERGED` 면 과제 23 을 먼저 하고(K11) 이 과제의 Step 1 부터 그 합친 HEAD 에서 한다.
- [ ] **Step 1: 근거 자리가 그대로인지 본다** — 표가 줄 번호를 든 자리를 이 HEAD 에서 연다(1절 · 2절 · 3절 · 4절의 고칠 행 전부 — 보안 범위와 지우는 줄 범위는 빠짐없이). 줄 번호가 밀렸으면 새 번호를 `anchors.tsv`(행 · 표의 번호 · 지금 번호 · 같은 글인가)에 적는다. 글이 달라진 자리가 있으면 그 행을 고치기 전에 멈추고 보고한다. `git log --since=2026-11-27 --oneline -- 'plugins/quality-gates/tests/*'` 가 비었는지 본다(있으면 그 diff 를 읽고 표의 근거가 서는지 보고).
- [ ] **Step 2: #347 과의 겹침** — `git fetch -q origin feature/switch-retirement` 뒤 `git diff --name-only origin/main...origin/feature/switch-retirement -- 'plugins/quality-gates/tests/*'` 를 표 「§8 겹침」 의 21개와 견준다. 묶음 A 가 고치는 파일과 겹치는 것은 없어야 한다(받는 쪽 `test_entry_safety_e1_e6.sh` 는 고치지 않고 돌리기만 한다). 겹치면 그 파일을 묶음 B 로 옮기고 보고한다. 양성 대조: 같은 명령이 `test_review_diff.sh` 를 찾는다.
- [ ] **Step 3: 고칠 파일 목록** — 표의 행 가운데 판정이 「다섯째(둠)」 이 아닌 것과 「같은 PR 에서 고칠 주석」 의 파일을 묶음(A · B — K1)으로 갈라 `files-A.txt` · `files-B.txt` 에 적는다. 지울 파일은 `delete-A.txt` 에. 받는 쪽으로만 기대는 파일(`test_entry_safety_e1_e6.sh` · `shared/tests/test_copy_of_contract.sh` · `test_agent_color.sh` · `shared/tests/test_test_selection_bundle.sh` · `shared/tests/test_changelog_integrity.sh` · `test_synthesize_artifact_findings.sh` · `shared/tests/test_adjudication_behavior.sh` · `test_synthesize_findings.sh` · `test_verdict_vocabulary.sh` · `test_a20_tool_agnostic_scope.py` · `test_e2e_docs.sh` · `test_intent_critic_wiring.sh` · `test_gate_era_prose_absent.sh` · `test_codex_gate_observation.sh`)은 `receivers.txt` 에.
- [ ] **Step 4: 고칠 행이 표의 행뿐임을 적는다(AC6)** — `files-A.txt` · `files-B.txt` 의 모든 파일이 표의 첫 칸 또는 「같은 PR 에서 고칠 주석」 에 나온다. 고칠 행에 대상 1–6 밖의 「둠」 이 없다(표가 이미 그렇다 — 확인만).
- [ ] **Step 5: 기준값** — `files-A.txt`(지울 파일 포함 — 단 `test_cost_consent.sh` 는 돌리지 않는다: 사용자 홈 아래 `.claude/quality-gates/` 에 마커를 실제로 만든다(표 2절). 그 파일의 기준값은 「돌리지 않음 — 사용자 홈에 쓴다」 로 적는다) · `receivers.txt` 를 하나씩 돌려 출력을 `before/<이름>.out`, 마지막 Total/Pass 줄(또는 unittest 의 `Ran N` · `OK`)을 `before-totals.tsv` 에. 실패가 있으면 이름을 적는다(이 PR 이 만든 실패와 가를 때 쓴다). `git status --porcelain` 이 돌린 뒤에도 비었는지 본다 — 비지 않으면(작업 트리를 건드리는 테스트) 그 이름과 바뀐 경로를 적고 `git restore --source=HEAD -- <그 경로>` 로 되돌린다.
- [ ] **Step 6: 고치기 전 시간** — `files-A.txt`(지울 파일 포함 · `test_cost_consent.sh` 빼고)를 Global Constraints 의 잠금 명령으로 `before-times-A.tsv` 에.

---

### Task 2: 파일째 지우기 다섯

**Files:**
- Delete: `test_artifact_metadata.sh` · `test_cost_consent.sh` · `harness/run_consent_gate.sh` · `test_impact_runtime_docs.sh` · `test_readme_state_diagram_complete.sh` · `test_synthesize_artifact_adjudication.py`
- Modify: `test_plain_qg_templates.sh:75`(주석) · `shared/tests/test_adjudication_wiring.sh:29`(주석) · `plugins/spec-distill/tests/test_brief_review_meta.sh:21` · `plugins/spec-distill/tests/test_readme_sync.sh:14`(주석 — K4) · `docs/removed-tests.md`

- [ ] **Step 1: 지우기 전 찾기(AC9)** — 파일 이름마다 `git grep -n -F <이름> -- CLAUDE.md docs/philosophy docs/plugin-authoring.md docs/testing.md docs/git-workflow '*README.md' 'plugins/*/skills/*' 'plugins/*/references/*' 'plugins/*/agents/*' 'plugins/*/templates/*'` → 0건. 양성 대조: 같은 명령이 `test_qg_false_clean_floor.sh` 를 찾는다(README.md:20). 테스트 쪽 부름은 `git grep -n -F <이름> -- 'plugins/*/tests/*' 'shared/tests/*'` 로 모아 아래 주석 넷 밖에 없음을 본다(있으면 멈추고 보고).
- [ ] **Step 2: 지운다** — `git rm -q -- <여섯>`.
- [ ] **Step 3: 주석을 고친다** — `test_plain_qg_templates.sh:75` 의 괄호 「(질문 앵커 표지는 test_readme_state_diagram_complete.sh 가 잰다)」 를 지운다. `test_adjudication_wiring.sh:29` 의 그 줄을 `quality-gates/tests/test_synthesize_artifact_findings.sh` 로. spec-distill 둘은 「(qg 쪽 … test_artifact_metadata.sh 와 동형 …)」 구절을 지운다 — 그 줄의 나머지 뜻은 그대로.
- [ ] **Step 4: 돈다** — `test_plain_qg_templates.sh` · `shared/tests/test_adjudication_wiring.sh` · `plugins/spec-distill/tests/test_brief_review_meta.sh` · `test_readme_sync.sh` · 받는 쪽 `test_synthesize_artifact_findings.sh` · `shared/tests/test_adjudication_behavior.sh` · `shared/tests/test_test_selection_bundle.sh` · `shared/tests/test_changelog_integrity.sh` · `test_gate_era_prose_absent.sh` → 기준값과 같은 Total/Pass.
- [ ] **Step 5: 기록 다섯 줄** — 표 2절의 다섯 행(artifact_metadata · cost_consent + run_consent_gate 한 줄 · impact_runtime_docs · readme_state_diagram_complete · synthesize_artifact_adjudication)의 칸으로. 판정 칸: 첫째 넷은 「첫째 줄(지키는 것을 댈 수 없다)」, adjudication 은 「둘째 줄(같은 것을 다른 테스트가 지킨다)」. 지금 지키는 것: impact 는 `shared/tests/test_test_selection_bundle.sh`(실행 비트), adjudication 은 `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh`, 나머지는 「없음 — 받아들임」.
- [ ] **Step 6: 커밋** — `test(qg): 지킬 것이 없거나 겹친 테스트 파일 다섯을 지운다`(pathspec: 지운 여섯 · 고친 넷 · `docs/removed-tests.md`).

---

### Task 3: frontmatter 겹침 셋

**Files:** Modify `test_agent_model_unpinned_sweep.sh:44-48` · `test_artifact_critic_frontmatter.sh:10` · `test_artifact_adversarial_frontmatter.sh:10` · `docs/removed-tests.md`

- [ ] **Step 1: 지운다** — 스윕의 케이스 2(:44–48 — README 모델 절 문장) · critic :10 · adversarial :10(color). 두 frontmatter 의 :9(model)는 둔다(갈림 ③).
- [ ] **Step 2: 돈다** — 세 파일 · `test_agent_color.sh` · `test_agent_model_mutation.sh`(짝 락 :27 · :28 가 그대로 RED 를 내는지 — 기준값과 같은 Total/Pass).
- [ ] **Step 3: 기록 세 줄** — 스윕 케이스 2(첫째 줄 · 없음 — 받아들임) · critic :10 · adversarial :10(둘째 줄 · `plugins/quality-gates/tests/test_agent_color.sh`).
- [ ] **Step 4: 커밋** — `test(qg): agent frontmatter 락의 겹친 color 줄과 README 문장 단언을 지운다`.

---

### Task 4: detect_codex — Case 13 · 14 를 사본에서 · backward_compat Check 1 지움(보안)

**Files:** Modify `test_detect_codex.sh:8-18,106-119` · `test_codex_backward_compat.sh:25-36` · `docs/removed-tests.md`

**Interfaces:**
- Produces: `test_detect_codex.sh` 가 추적 파일 `plugins/quality-gates/scripts/codex-killswitch.conf` 를 쓰지 않는다. 망가진 conf 케이스는 `$TMP/probe/detect_codex.sh`(`cp -L` 로 링크를 푼 감지기)와 그 옆 `$TMP/probe/codex-killswitch.conf` 를 쓴다 — 감지기가 형제 conf 를 `dirname "${BASH_SOURCE[0]}"` 로 찾는다(`shared/codex/detect_codex.sh:35`).

- [ ] **Step 1: 옛 커밋을 적는다** — `B4=$(git rev-parse HEAD)`.
- [ ] **Step 2: Case 13 · 14 를 바꾼다** — `CONF_BACKUP` · `restore_conf` · SIGKILL 주석(:11–17)을 걷고 trap 을 `rm -rf "$TMP"` 로. 두 케이스는 `mkdir -p "$TMP/probe"; cp -L "$PROBE" "$TMP/probe/detect_codex.sh"` 뒤 망가진 값을 `$TMP/probe/codex-killswitch.conf` 에 쓰고 `bash "$TMP/probe/detect_codex.sh"` 를 돈다. 단언 글 · 기대값은 그대로. 양의 짝 하나를 더한다: 같은 사본에 정상 conf(`cp "$CONF" "$TMP/probe/"`)를 두면 `skip_reason: killswitch_config_invalid` 가 없다 — 사본이 형제 conf 를 실제로 읽는다.
- [ ] **Step 3: Check 1 을 지운다** — backward_compat :25–36. 머리말은 과제 5 가 고친다.
- [ ] **Step 4: 돈다** — 두 파일. `test_detect_codex.sh` Total = 기준값 + 1(양의 짝), Fail 0. 돌린 뒤 `git status --porcelain -- plugins shared` 가 비었다(AC16). 실행 도중 `codex-killswitch.conf` 의 수정 시각이 바뀌지 않는다(`stat -f %m` 앞뒤).
- [ ] **Step 5: 커밋** — `test(qg): detect_codex 의 망가진 conf 케이스를 사본에서 돌리고 겹친 kill switch 확인을 지운다`.
- [ ] **Step 6: 변이 견주기 — 망가진 conf(:109–119 · fail-closed)** — 옛 = `$B4`(`test_detect_codex.sh`), 새 = HEAD(같은 파일). `shared/codex/detect_codex.sh` 에 건다:
  - 삭제 — 식별자 검사 블록(`if [[ ! "$CODEX_KILL_SWITCH_VAR" =~ … ]]; then` 부터 `fi`, :55–58)을 지운다.
  - 추가 — :55 앞에 `CODEX_KILL_SWITCH_VAR="${CODEX_KILL_SWITCH_VAR%$'\r'}"` 를 더한다.
  - 반전 — :55 의 `! ` 를 뺀다.
  - 형태 — 정규식 끝 `[A-Za-z0-9_]*$` 를 `[A-Za-z0-9_[:space:]]*$` 로.
  기대: 변이마다 옛 Case 13 · 14 의 ✗ 가 새 Case 13 · 14 에도 있다. 변이 없는 사본은 둘 다 Fail 0. 옛 사본은 추적 conf 를 덮으므로 사본 안에서만 돈다.
- [ ] **Step 7: 변이 견주기 — kill switch(:25–36 → Case 3)** — 옛 = `$B4` 의 backward_compat Check 1 과 `test_detect_codex.sh` Case 3, 새 = HEAD 의 `test_detect_codex.sh` Case 3. `detect_codex.sh` :61–64 에: 삭제(그 블록) · 추가(:61 앞에 `CODEX_KILL_SWITCH_VAR="${CODEX_KILL_SWITCH_VAR}_X"`) · 반전(`== "1"` → `!= "1"`) · 형태(`== "1"` → `== "true"`). 기대: 옛 Check 1 이 FAIL 이면 새 Case 3 도 ✗. 양성 대조 같은 꼴.
- [ ] **Step 8: 기록 한 줄** — backward_compat Check 1(둘째 줄 · `plugins/quality-gates/tests/test_detect_codex.sh` Case 3). 두 변이 표(변이 · 바꾼 줄 · 옛 ✗ · 새 ✗)를 구현 보고에 싣는다. 기록 줄을 커밋한다(`docs(test): …`).

---

### Task 5: backward_compat 나머지 · dispatch_invariant 케이스 6

**Files:** Modify `test_codex_backward_compat.sh`(머리말 :1–14 · Check 2 :38–79 · :124 주석 · Check 4) · `test_codex_dispatch_invariant.sh`(케이스 5 뒤) · `docs/removed-tests.md`

**Interfaces:**
- Consumes: 과제 4 뒤의 backward_compat(Check 1 없음).
- Produces: backward_compat 의 확인은 둘(셋째 · 넷째)이고 `Total: 2` 로 끝난다. 넷째 확인의 가짜 원장 갈래는 다섯(맞는 지문 둘 · 틀린 지문 · stale · 빈 지문 · 자기 등재).

- [ ] **Step 1: 케이스 6 을 쓴다** — `test_codex_dispatch_invariant.sh` 케이스 5 뒤:

```bash
# 6. codex 를 못 쓰면 빼고 계속 간다(옛 test_codex_backward_compat.sh Check 2c).
if grep -qE 'If codex is unavailable, continue without it' "$SKILL"; then
  ok "6: codex-unavailable degrade path documented"
else
  no "6: SKILL missing the codex-unavailable degrade path"
fi
```

- [ ] **Step 2: 실패를 본다** — `git archive HEAD` 사본에서 SKILL 의 그 문장을 지우고(`plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 줄 하나가 맞는지 센다) 사본의 dispatch_invariant 를 돈다 → `6:` ✗. 이 worktree 에서는 ✓.
- [ ] **Step 3: Check 2 를 지운다** — :38–79 통째.
- [ ] **Step 4: 갈림 ④ 의 주석 · 표지** — 머리말을 두 확인(셋째 · 넷째)으로 고쳐 쓰고, 넷째 확인이 원장이 비어도 가짜 테스트를 띄운다는 것을 적는다(:175 지적). :124 주석에 한 문장 — 다시 돌리기가 표준 입력을 `/dev/null` 로 막아 넷째 확인의 가짜(`test_fake_red.sh`)는 fd 3 분리를 따로 가르지 못한다. 안쪽 실행 표지는 K3 의 한 줄.
- [ ] **Step 5: 거절 갈래 둘을 쓴다(K2)** — 넷째 확인에 `out_d` · `out_e` 를 더한다:
  - `printf '%s\n' 'echo quiet; exit 1' > "$C4_TMP/tests/test_fake_quiet.sh"`, 원장 `test_fake_quiet.sh <아무 64자 hex>` → 기대 `*"빈지문"*"rc=1"`.
  - 원장 `$SELF <아무 64자 hex>` → 기대 `*"자기 등재"*"rc=1"`.
  실패 글은 `FAIL: 다시 돌리는 갈래 — 빈 지문이 빈지문으로 실패하지 않았다` · `… 자기 등재가 자기 등재로 실패하지 않았다`.
- [ ] **Step 6: 실패를 본다** — `git archive HEAD` 사본 둘에서 (가) 빈 지문 갈래(`if [[ "$actual" == "$EMPTY_DIGEST_SHA256" ]]` 블록)를 지운다 → 넷째 확인 FAIL(빈지문 글). (나) 자기 등재 조건을 `[[ "$b" = "x$SELF" ]]` 로 바꾼다 → `perl -e 'alarm shift; exec @ARGV' 60 bash <사본>/plugins/quality-gates/tests/test_codex_backward_compat.sh` 가 FAIL 또는 시간 상한으로 끝난다(0 이 아니다). 변이 없는 사본은 `Total: 2, pass: 2`.
- [ ] **Step 7: 돈다** — 두 파일. backward_compat `Total: 2, pass: 2, fail: 0`. dispatch_invariant Fail 0, 기준값 + 1. `CODEX_COMPAT_INNER=1 bash test_codex_backward_compat.sh` 의 첫 줄이 K3 의 NOTE 다.
- [ ] **Step 8: 기록 한 줄** — Check 2a · 2b(둘째 줄 · `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` 1 · 2). 2c 는 옮긴 합침이라 줄 없음.
- [ ] **Step 9: 커밋** — `test(qg): codex 하위 호환 테스트를 원장 확인 둘로 줄이고 거절 갈래 둘을 더한다`.

---

### Task 6: failure_injection 을 findings_parser 로

**Files:** Delete `test_failure_injection.sh` · `mocks/mock-codex-no-agent-message.sh` · `mocks/mock-codex-valid-json-no-fence.sh`; Modify `test_findings_parser.sh`(Fixture 5 뒤)

- [ ] **Step 1: 옮길 꼴을 쓴다** — Fixture 5 뒤:

```bash
# Fixture 5b: exit ≠ 0 의 모양 — 빈 stdout · 빈 stderr(옛 test_failure_injection.sh 1번)
: > "$TMP/exit1.jsonl"; : > "$TMP/exit1.err"
check "exit-1 shape (empty stdout + empty stderr)" "$TMP/exit1.jsonl" "$TMP/exit1.err" 'reason: missing_result'
```

- [ ] **Step 2: 전에 잡던 것을 잡는지 본다** — `git archive HEAD` 사본에서 `shared/codex/codex_findings_to_yaml.py` 가 빈 입력을 정상 라운드로 읽게 망가뜨리고(빈 입력이면 `missing_result` 를 내는 갈래를 찾아 그 갈래가 `codex_failed: false` 로 가게 — 자리를 보고에 적는다) 사본의 findings_parser 를 돈다 → `exit-1 shape` ✗. 같은 변이에서 옛 `test_failure_injection.sh` 의 `exit-1` 도 FAIL 인지 함께 적는다.
- [ ] **Step 3: 지우기 전 찾기** — 세 이름을 Task 2 Step 1 의 꼴로 찾는다 → 막는 자리 0. `git grep -n -F mock-codex-no-agent-message -e mock-codex-valid-json-no-fence -- 'plugins/*/tests/*' 'shared/tests/*'` 가 `test_failure_injection.sh` 밖에 없다.
- [ ] **Step 4: 지우고 돈다** — `git rm`. `test_findings_parser.sh`(기준값 + 1) · `test_codex_copies_agree.sh`(mock 교집합 바닥 8 그대로 — 기준값과 같은 Total/Pass).
- [ ] **Step 5: 커밋** — `test(qg): 실패 주입 테스트의 빈 출력 꼴을 파서 테스트로 옮기고 지운다`(옮긴 합침 — 기록 줄 없음).

---

### Task 7: isolation 을 worktree 로

**Files:** Delete `test_isolation.sh`; Modify `test_worktree.sh`(Test 1 끝 · Test 3 · 4 · 5 지움) · `docs/removed-tests.md`

- [ ] **Step 1: T1 · T2 의 확인을 Test 1 에 더한다** — Test 1 의 `rm -rf "$(dirname "$REPO")"` 앞에(같은 레포 + worktree, 레포를 새로 짓지 않는다). `inode_of` 를 옮겨 온다.
  - `T1d` — `(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID")` 가 rc 0 이고 `$REPO/.claude/quality-gates/$SID/result.md` 가 있다(같은 SID 의 worktree 상태가 원 레포를 막지 않는다).
  - `T1e` — 두 `result.md` 의 inode 가 다르다.
  - `T1f` — 거꾸로: 새 SID `wt1session02` 로 원 레포 먼저, 그다음 worktree — worktree 쪽이 rc 0 이고 `result.md` 가 있다.
  단언 글은 옛 T1b · T1c · T2b 의 뜻을 한국어 한 줄로.
- [ ] **Step 2: 전에 잡던 것을 잡는지 본다** — `git archive HEAD` 사본에서 `plugins/quality-gates/scripts/setup-qg.sh` 가 상태 폴더를 worktree 가 아닌 공유 자리(`git rev-parse --git-common-dir` 의 부모)에 쓰게 바꾼다(자리를 보고에 적는다) → 사본의 `test_worktree.sh` 의 `T1d` · `T1e` 가운데 ✗. 같은 변이에서 옛 `test_isolation.sh` 의 T1 · T2 ✗ 도 적는다.
- [ ] **Step 3: Test 3 · 4 · 5 를 지운다** — :73–101 · :126–145.
- [ ] **Step 4: 지우기 전 찾기 · 지운다** — `test_isolation.sh` 이름을 Task 2 Step 1 꼴로 → 0. `git rm`.
- [ ] **Step 5: 돈다** — `test_worktree.sh`(Fail 0) · `test_v_requirements.sh`(case_v12 — T5 의 받는 쪽) · `test_entry_safety_e1_e6.sh`(E1 — T4 · T6 의 받는 쪽).
- [ ] **Step 6: 기록 네 줄** — isolation T3 · T5(첫째 줄 · 없음 — 받아들임) · isolation T4 · T6(둘째 줄 · `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` E1) · worktree T3 · T4(첫째 줄 · 없음) · worktree T5(둘째 줄 · `plugins/quality-gates/tests/test_v_requirements.sh` case_v12).
- [ ] **Step 7: 커밋** — `test(qg): 격리 테스트를 worktree 테스트에 합치고 git 동작만 보던 확인을 지운다`.

---

### Task 8: 가짜 응답 도우미

**Files:** Delete `test_agent_stub_harness.py` · `harness/agent_stub.py`; Modify `test_security_reviewer_behavior.py`(AC45 · AC46 · AC47 · stub import :19–20 · sys.path) · `docs/removed-tests.md`

- [ ] **Step 1: 세 케이스와 import 를 지운다** — v10 둘(:57–70)만 남는다. 파일 이름은 그대로.
- [ ] **Step 2: 지우기 전 찾기** — `agent_stub` 를 `git grep -n -F agent_stub -- . ':!CHANGELOG.md' ':!docs/superpowers' ':!docs/archive' ':!docs/removed-tests.md'` → 지울 두 파일과 behavior 밖에 없다. `# guards:` 에 걸리지 않는다(`grep -rn 'agent_stub' plugins/*/tests/*.sh shared/tests/*.sh` 의 `# guards:` 줄 0).
- [ ] **Step 3: 지우고 돈다** — `python3 test_security_reviewer_behavior.py` → 둘 OK. `test_security_reviewer_persona.sh` 기준값과 같다.
- [ ] **Step 4: 기록 세 줄** — behavior AC45–47(첫째 줄 — 기대값과 대상이 같은 출처 · 없음 — 받아들임) · `test_agent_stub_harness.py`(첫째 줄 · 없음) · `harness/agent_stub.py`(첫째 줄 · 없음).
- [ ] **Step 5: 커밋** — `test(qg): 기대값을 스스로 정하던 가짜 응답 도우미와 그 시험을 지운다`.

---

### Task 9: README 글자 단언 — readme_scope_reconcile · artifact_critique_truths

**Files:** Modify `test_readme_scope_reconcile.sh:27-30,44-46` · `test_artifact_critique_truths.sh:2,9,26-39` · `docs/removed-tests.md`

- [ ] **Step 1: 지운다** — reconcile :27–30 · :44–46. truths :26–37(160자 창 검사와 양성 짝) · :38–39(README 두 단언), `# guards:`(:2)와 `--emit-scanned`(:9)에서 README 경로를 뺀다.
- [ ] **Step 2: 돈다** — 두 파일 · `test_review_scope_composition.sh` · `test_gate_era_prose_absent.sh` · `test_plain_readme.sh`(README 를 계속 읽는다) · `bash test_guards_coverage_bidirectional.sh`(README 가 다른 선언으로 덮인다).
- [ ] **Step 3: 기록 두 줄** — reconcile :27–30 · :44–46(첫째 줄 · 없음 — 받아들임) · truths :26–39(첫째 줄 · 없음).
- [ ] **Step 4: 커밋** — `test(qg): README 를 글자로 무는 단언을 지운다(범위 조정 · 비평 사실)`.

---

### Task 10: 낮춘 지적 질문의 이음매

**Files:** Modify `test_lowered_gate_wiring.sh:49-99` · `test_skill_orchestration.sh:48` · `test_plain_qg_templates.sh:2,26-29,33,35,47-49,55-66,61-63,69-78,94-97` · `docs/removed-tests.md`

**Interfaces:**
- 받는 쪽이 남기는 단언(지우지 않는다): lowered 의 라벨 「그대로 둔다」(:65) · header 「낮춘 지적」 · 「전문:」 · 묶음 번호 낱말(:68) · header 수(:98) · 순서(:85–96). skill_orchestration :37–47 · :49. plain_qg_templates :30 · :42–46 · 부재 짝.

- [ ] **Step 1: lowered 를 줄인다(넷째)** — case_step45_gate 의 걸음 문장 줄 전체 단언을 뜻 낱말 단언으로: 「lowered: 를 읽는다」 · 「0 이면 묻지 않는다」 · 「셋씩」 · 「넷까지」 · 「전부 → all」 · 「한 번만 다시 묻는다」(각각 같은 창 안). 질문 · description 전문 단언은 지운다. 위 Interfaces 의 단언은 그대로.
- [ ] **Step 2: 줄인 확인이 무는지 본다** — `git archive HEAD` 사본에서 SKILL 의 「0 이면 묻지 않는다」 가 든 문장을 지운다 → 그 단언 ✗. 「셋씩」 도 하나 더.
- [ ] **Step 3: 합친 쪽을 지운다** — skill_orchestration :48. plain_qg_templates :26–29 · :33 · :35(:30 은 남긴다 — 갈림 B-7).
- [ ] **Step 4: plain_qg_templates 의 README · 출력 문구** — README 단언(:61–63 · :69–78)을 지우고 `# guards:`(:2)에서 README 를 뺀다. 모델이 그대로 내는 문구 줄(:47–49 · :55–66 · :94–97)은 옛 영어 부재(:57 · :60 · :66 · :97)와 가장 짧은 한국어 양성 낱말(「작은 수정이라」 · 「리뷰 범위:」 — 각 줄마다 그 줄이 무는 문구에서 하나)의 짝으로 남기고 전문을 덜어 낸다. 사본에서 한 낱말의 문장을 지워 ✗ 를 한 번 본다.
- [ ] **Step 5: 돈다** — 세 파일 · `test_intent_critic_wiring.sh`(plain_qg_templates 를 목록으로 부른다) · `harness/test_skill_orchestration_behavior.sh` · `test_guards_coverage_bidirectional.sh`.
- [ ] **Step 6: 기록 셋** — skill_orchestration :48(둘째 줄 · `plugins/quality-gates/tests/test_lowered_gate_wiring.sh` :65) · plain_qg_templates :26–29 · :33 · :35(둘째 줄 · `test_lowered_gate_wiring.sh` case_step45_gate · `test_skill_orchestration.sh` :37–41) · plain_qg_templates README 단언(첫째 줄 · 없음 — 받아들임).
- [ ] **Step 7: 커밋** — `test(qg): 낮춘 지적 질문의 겹친 단언을 받는 쪽 하나로 모으고 전문 대조를 뜻 낱말로 줄인다`.

---

### Task 11: 넷째 줄임 셋

**Files:** Modify `test_one_pipeline_surface.sh:64-66,108,111,113,128` · `test_topic_scope_wiring.sh:170,250-251` · `test_review_scope_composition.sh:33,35,36`

- [ ] **Step 1: one_pipeline_surface** — `##` 절 목록 전체 핀을 「Flow 가 Differential test · e2e · Final verdict 보다 앞」 순서와 「고치기 반복 절 부재」 로. 줄 전체 넷을 「묻지 않는다」 · 「코드를 고치지 않는다」 · 「고칠 목록에 들지 않는다」 구절로 — 구절은 머리 `**고칠 목록.**` 이 만족시키지 않는 본문 낱말이다(사본에서 본문 문장을 지우고 머리만 남겨 ✗ 를 본다).
- [ ] **Step 2: topic_scope_wiring** — :170 · :250–251 을 「Trivia escape 의 미룬 판단」 · 「review-i1.diff」 같은 뜻 낱말로. :273–293(in_base 공지 — 갈림 ⑨)은 둔다.
- [ ] **Step 3: review_scope_composition** — 시작 · 끝 줄 꼴(:33 · :35 · :36)을 자리표시 낱말(`<계획한 수>명` · `다시 부른 리뷰어 <r>명`)로. :31–32 · :34 · :37–41 은 둔다.
- [ ] **Step 4: 줄인 확인이 무는지 본다** — 파일마다 사본에서 남긴 낱말이 든 문장 하나를 지워 ✗.
- [ ] **Step 5: 돈다 · 커밋** — 세 파일 · `test_e2e_docs.sh`(K-8 순서). `test(qg): 줄 전체를 무는 절 목록 · 규칙 문장을 뜻 낱말로 줄인다`(넷째 줄임 — 기록 줄 없음).

---

### Task 12: 겹침 지우기 다섯과 V1 옮김

**Files:** Modify `test_differential_procedure.sh:73-77` · `test_v_requirements.sh`(V1 :26–27 · :31–37 · V2 · V3 · V8 의 스크립트 실행) · `test_v1_verdict_line.sh`(음수 개수 단언 앞) · `test_runtime_contract_invariance.sh:126-140` · `test_codex_result_banner.sh:124-136` · `test_git_derived_scope.sh:52-55` · `docs/removed-tests.md`

- [ ] **Step 1: V1 몫을 v1_verdict_line 에 쓴다** — 음수 개수 단언 앞:

```bash
assert_eq "$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import verdict; print(" ".join(verdict.VALUES))' "$SCRIPT_DIR/../scripts")" \
  "defect not-certified clean" "판정값은 셋이고 우선순위 순서다"
out="$(python3 "$V" --line --blocking x --optional 0 --new-failures 0 --sha abc1234 2>/dev/null)"; rc=$?
assert_eq "$rc" "4" "비정수 개수는 exit 4"
assert_eq "$out" "" "비정수 개수면 stdout 이 비어 있다"
```

- [ ] **Step 2: 전에 잡던 것을 잡는지 본다** — 사본에서 (가) `scripts/verdict.py` 의 `VALUES` 순서를 바꾼다 → 첫 단언 ✗. (나) 개수 검사가 비정수를 받아들이게 한다 → 둘째 · 셋째 ✗. 같은 변이에서 옛 V1 의 ✗ 를 함께 적는다.
- [ ] **Step 3: v_requirements 를 줄인다** — V1 의 :26–27 · :31–34 · :35–37 과 V2 · V3 · V8 의 스크립트 실행 절반(:43–44 · :50–57 · :98–105)을 지운다. 같은 케이스의 SKILL 창 단언은 남는다. :28–29 는 둔다(K5).
- [ ] **Step 4: 나머지 넷을 지운다** — differential :73–77 · runtime_contract :126–140(토큰 블록과 그 주석) · banner :124–136(단언 · SKIP_WINDOW 진단 줄 · 주석) · git_derived_scope :52–55.
- [ ] **Step 5: 돈다** — 여섯 파일 · 받는 쪽 `test_e2e_docs.sh` · `test_synthesize_findings.sh` · `test_verdict_vocabulary.sh` · `test_one_pipeline_surface.sh` · `test_codex_gate_observation.sh` · `test_a20_tool_agnostic_scope.py`.
- [ ] **Step 6: 기록 다섯 줄** — differential :73–77(둘째 · `test_e2e_docs.sh` case_final_verdict_goes_through_verdict_py_with_e2e) · v_requirements V2 · V3 · V8(둘째 · `test_synthesize_findings.sh`) · runtime_contract 토큰(둘째 · `test_one_pipeline_surface.sh` case_old_surface_absent) · banner :124–136(첫째 · `test_codex_gate_observation.sh` UNGATED 원장) · git_derived_scope :52–55(둘째 · `test_a20_tool_agnostic_scope.py` 축 3). 경로는 레포 기준으로 적는다.
- [ ] **Step 7: 커밋** — `test(qg): 판정 · 차등 · 배너의 겹친 확인을 지우고 V1 의 순서 · 비정수 확인을 판정 줄 테스트로 옮긴다`.

---

### Task 13: topic_boundary — 한 번 지어 복사 · nkeys 지움

**Files:** Modify `test_topic_boundary.sh`(`new_repo` · 사본 확인 케이스 하나 · :257–271 · 「정합 2/2」 짝 주석) · `docs/removed-tests.md`

**Interfaces:**
- Produces: `new_repo` 계약 그대로(빈 `main` 두 커밋 레포에 cwd · `REPO` 를 채운다). 안에서는 파일에 한 번 지은 견본(`_TB_TEMPLATE`)을 새 `mktemp -d` 에 `cp -R` 하고 `sync_base` 를 사본에서 다시 부른다.

- [ ] **Step 1: 사본 확인을 쓴다(K8)** — `case_new_repo_copies_are_isolated`: `new_repo` 로 사본 A 를 떠 커밋 하나를 더하고 그 SHA 를 적은 뒤 `cleanup`, 다시 `new_repo` 로 B — B 에 그 커밋이 없고(`git cat-file -e` 실패) B 의 `.git` 에서 `grep -rlF "$_TB_TEMPLATE"` 0건이다. 돌려 통과를 본다(지금은 새로 지어서 통과).
- [ ] **Step 2: 견본 복사를 구현한다** — 그다음 사본에서 견본을 `cp -R` 대신 같은 폴더로 두고 쓰게 망가뜨려(`REPO="$_TB_TEMPLATE"`) Step 1 의 케이스 ✗ 를 본다.
- [ ] **Step 3: nkeys 케이스를 지운다** — :257–271. 「정합 2/2」 짝 주석이 그 케이스를 가리키면 `case_f7_mixed_keys_in_T` 로 고친다.
- [ ] **Step 4: 돈다** — Total = 기준값 − (nkeys 단언 수) + (사본 확인 단언 수), Fail 0. 둘째 실행에서도 같다(견본이 남지 않는다 — 파일 trap 이 견본을 지운다).
- [ ] **Step 5: 기록 한 줄 · 커밋** — nkeys(둘째 · `plugins/quality-gates/tests/test_topic_boundary.sh` case_f7_mixed_keys_in_T). `test(qg): 토픽 경계 테스트가 레포를 한 번 지어 복사하고 겹친 트레일러 케이스를 지운다`.

---

### Task 14: topic_head — 훅 케이스 지움 · 형제 출력 함께 쓰기(보안 둘)

**Files:** Modify `test_topic_head.sh`(:99–119 · :261–322 · 케이스 목록) · `docs/removed-tests.md`

- [ ] **Step 1: 옛 커밋** — `B14=$(git rev-parse HEAD)`.
- [ ] **Step 2: 변이 견주기 — 훅(:261–284 → `test_entry_safety_e1_e6.sh` E6)** — 지우기 전에. 옛 = `$B14` 의 `test_topic_head.sh`, 새 = 같은 사본의 `test_entry_safety_e1_e6.sh`. `plugins/quality-gates/scripts/topic-head.sh` :42–45 에: 삭제(`export "GIT_CONFIG_KEY_$n=…"` 줄) · 추가(:45 뒤 `export GIT_CONFIG_COUNT=$n`) · 반전(두 export 를 `if [ -n "${GIT_CONFIG_COUNT:-}" ]; then … fi` 로 감싼다) · 형태(`GIT_CONFIG_COUNT=$((n + 1))` → `$n`). 기대: 옛 「저장소 훅을 하나도 돌리지 않는다」 ✗ ⇒ 새 E6 ✗. 양성 대조: 변이 없는 사본은 E6 · 옛 케이스 ✓.
- [ ] **Step 3: 훅 케이스를 지운다** — :261–284 와 목록의 이름.
- [ ] **Step 4: 형제 셋을 하나로(K12)** — `case_two_siblings_shared` 하나가 레포를 세우고 `th` 를 한 번 돌려 `out` 을 셋이 함께 쓴다: 합친 트리 단언(옛 :107–117) → accepts(옛 :292–299, 끝에서 `wt remove`) → rejects 첫 셋(옛 :310–316) → `later.txt` 와 stale 거부 → `head-` worktree 0. 단언 글은 그대로.
- [ ] **Step 5: 연쇄를 본다** — 사본에서 accepts 의 `wt remove` 줄을 지우고 돈다 → 「거부된 호출은 HEAD 축 워크트리를 만들지 않는다」 ✗(이 순서가 그 단언을 지킨다는 증거 — Review Focus 4).
- [ ] **Step 6: 돈다** — `test_topic_head.sh` Fail 0, Total = 기준값 − 훅 케이스 단언 수. `test_entry_safety_e1_e6.sh` 기준값과 같다.
- [ ] **Step 7: 커밋** — `test(qg): topic-head 테스트의 겹친 훅 케이스를 지우고 형제 셋이 실행 하나를 함께 쓴다`.
- [ ] **Step 8: 변이 견주기 — create-head 거부(:300–322)** — 옛 = `$B14`, 새 = HEAD. `plugins/quality-gates/scripts/qg-worktree.sh` :207–208 에: 삭제(그 `[[ … ]] || die "head-commit mismatch…"` 두 줄) · 추가(:207 앞 `ch_tree=$(git rev-parse "$2^{tree}")`) · 반전(`==` → `!=`) · 형태(`"$2^{tree}"` → `"$2"`). 기대: 옛 ✗ ⇒ 새 ✗(반전 · 형태는 accepts 쪽 ✗ 도 기대). 양성 대조 같은 꼴.
- [ ] **Step 9: 기록 한 줄 · 보고** — 훅 케이스(둘째 · `plugins/quality-gates/tests/test_entry_safety_e1_e6.sh` E6). 두 변이 표와 Step 5 를 구현 보고에. 커밋(`docs(test): …`).

---

### Task 15: other_teams — 같은 계산 한 번

**Files:** Modify `test_other_teams.py`(클래스 공유 리포를 쓰는 `_collect` · `_work` 도우미 · 격리 시험 하나)

- [ ] **Step 1: 격리 시험을 쓴다(K8 · Review Focus 3)** — 같은 클래스에 `test_shared_result_is_not_mutated_across_tests`: `_collect` 결과의 목록 하나에 원소를 더한 뒤 같은 인자로 다시 받은 결과에 그 원소가 없다. `_work` 도 같은 꼴. 돌려 통과(지금은 매번 실제로 부른다).
- [ ] **Step 2: 클래스 메모를 넣는다** — 같은 인자 튜플이면 클래스 안에서 한 번 계산해 둔다. 먼저 깊은 복사 없이 넣어 Step 1 ✗ 를 보고, `copy.deepcopy` 로 내줘 ✓. mock 안 호출(:848 · :859 · :1352–1374 등)과 :1329–1330 은 메모를 지나지 않는다(그 자리는 지금처럼 직접 부른다).
- [ ] **Step 3: 돈다** — `python3 test_other_teams.py` → 시험 수 = 기준값 + 1, OK. `test_other_teams_review_records.py` 기준값과 같다. 보안 범위(:373–424 · :1011–1234 · :1419–1435)의 시험 이름과 결과가 기준값과 같다(`-v` 출력 대조).
- [ ] **Step 4: 커밋** — `test(qg): 다른 팀 읽기 시험이 같은 인자의 결과를 클래스에서 한 번 계산해 나눠 쓴다`.

---

### Task 16: range_wiring — 픽스처 한 번 · 펜스 사전(보안처럼)

**Files:** Modify `test_range_wiring.sh`(`mkfix` · `fence_with` 를 부르는 자리 · 사본 확인 케이스 하나)

**Interfaces:**
- Produces: `mkfix` 계약 그대로(전역 A R S E D F). 안에서는 파일에 한 번 지은 A/R 견본을 케이스마다 새 `mktemp -d` 에 `cp -R` 하고 사본 R 의 `origin` 을 사본 A 로 `git remote set-url`. 펜스 사전 — SKILL · DT 를 python 한 번으로 읽어 `needle → 본문` 을 `$ROOT/fences/<번호>` 파일로 두고 `fence_with` 는 그 사전에서 찾는다(호출 꼴 그대로).

- [ ] **Step 1: 옛 커밋** — `B16=$(git rev-parse HEAD)`.
- [ ] **Step 2: 사본 확인을 쓴다(K8 · Review Focus 1 · 2)** — `case_mkfix_copies_are_isolated`: `mkfix` 두 번 — 첫 사본의 R 에 커밋을 더해도 둘째 사본에 없고, `git -C "$R" remote get-url origin` 이 그 사본의 A 이고, R · A 의 `.git` 에서 견본 경로 `grep -rlF` 0건. 통과를 본다.
- [ ] **Step 3: 구현한다** — `mkfix` 의 견본 복사 · `set-url`. 사본에서 `set-url` 을 지우고 Step 2 ✗ 를 본다. 펜스 사전 — 같은 needle 에 지금과 같은 본문이 나오는지 파일 안 모든 `fence_with` needle 에 대해 한 번 대조(옛 꼴과 새 꼴의 출력 `cmp` — 보고에).
- [ ] **Step 4: 돈다** — Fail 0, Total = 기준값 + 사본 확인 단언 수.
- [ ] **Step 5: 커밋** — `test(qg): 범위 배선 테스트가 픽스처를 한 번 지어 복사하고 펜스를 한 번 뽑는다`.
- [ ] **Step 6: 변이 견주기 — 리뷰 트리(:109–127 · :209–265)** — 옛 = `$B16`, 새 = HEAD. SKILL P2b 의 리뷰 트리 펜스(`review_tree:` 를 내는 ```bash 펜스)에: 삭제(`create-head … --range "$RS"` 줄) · 추가(펜스 첫 줄 뒤 `echo "review_tree: checkout"; exit 0`) · 반전(`head_is_end` 가 `yes` 면 지금 체크아웃 경로를 `review_tree:` 로 내는 갈래를 넣는다) · 형태(`end:` 를 읽는 `sed` 를 `start:` 로). 기대: 옛 ✗ ⇒ 새 ✗. 양성 대조 같은 꼴. 표를 보고에.

---

### Task 17: range_wiring — 펜스 글자 핀 · 규칙 문장 · README

**Files:** Modify `test_range_wiring.sh:104,115-180,195,201-203` · `docs/removed-tests.md`

- [ ] **Step 1: 옛 커밋** — `B17=$(git rev-parse HEAD)`.
- [ ] **Step 2: 지우고 줄인다** — 펜스 본문 글자 핀 :104 · :116–117 · :128–129 · :146–147 · :174–176 · :195 · :201–203 을 지운다(실행 안 되는 펜스 핀 :134 · :156 · :177 은 남긴다). 규칙 문장 :160–161 · :166–167 · :173 · :180 은 뜻 낱말로. :115 · :118–127 은 남긴다(S4). README :136–139 쌍은 지운다.
- [ ] **Step 3: 변이 견주기 — 지운 S4 핀(:116–117 · :128–129 · :174–176)** — 옛 = `$B17`, 새 = HEAD. 핀마다 그 펜스에 변이 넷(Task 16 Step 6 의 꼴 — 리뷰 트리 펜스 · Final verdict 의 지우기 펜스(`qg-worktree.sh" remove` 줄 삭제 · `remove` 앞에 `true ||` 추가 · `if` 반전 · 경로를 `review-tree.txt` 가 아닌 다른 파일로) · 리뷰 트리 펜스 마지막 줄(삭제 · 둘째 printf 추가 · `end:`→`start:` · `--sha` → `--sha=`)). 기대: 옛 ✗ ⇒ 새 ✗(실행 케이스 case_review_tree · case_fences_agree 가 받는다). 나머지 핀은 보안이 아니다 — 핀마다 그 펜스 한 줄을 망가뜨려 새 쪽 실행 케이스 ✗ 를 한 번 본다.
- [ ] **Step 4: 돈다** — Fail 0.
- [ ] **Step 5: 기록 여덟 줄** — 지운 펜스 글자 핀 일곱 자리에 한 줄씩(둘째 줄 · `plugins/quality-gates/tests/test_range_wiring.sh` case_review_tree · case_fences_agree 등 그 펜스를 실제로 돌리는 케이스) · README :136–139(첫째 줄 · 없음 — 받아들임).
- [ ] **Step 6: 커밋** — `test(qg): 범위 배선의 펜스 글자 핀을 실행 케이스에 맡기고 규칙 문장을 뜻 낱말로 줄인다`.

---

### Task 18: codex_copies_agree 층④ — 한 경로로(보안처럼)

**Files:** Modify `test_codex_copies_agree.sh:84-145` · `docs/removed-tests.md`

- [ ] **Step 1: 옛 커밋** — `B18=$(git rev-parse HEAD)`.
- [ ] **Step 2: 줄인다** — 층④ 루프에서 sd 호출(`b=`)과 두 경로 비교 · sd 값 고정 단언을 지운다. qg 경로의 계측기 확인(`codex_failed:` 존재)과 값 고정(01-clean → false · 02-container-violation → true)과 표본 수 바닥은 남긴다. 머리 :32–41 의 「판정 등가는 다시 실질」 문단은 지금 지키는 것(`shared/tests/test_copy_of_contract.sh` (b))을 가리키는 한 문장으로.
- [ ] **Step 3: 돈다 · 커밋** — Fail 0. `shared/tests/test_copy_of_contract.sh` 기준값과 같다. `test(qg): codex 사본 일치 락의 층④ 를 한 경로의 값 고정으로 줄인다`.
- [ ] **Step 4: 변이 견주기** — 옛 = `$B18` 의 층④, 새 = HEAD 의 `shared/tests/test_copy_of_contract.sh`(b) 와 층④. `plugins/spec-distill/scripts/codex_jsonl.py` 의 `extract_last_agent_message` 에: 삭제(빈 `agent_message` 를 건너뛰는 줄) · 추가(함수 첫 줄에 `return (None, True)`) · 반전(그 함수 안 조건 하나의 `not`) · 형태(돌려주는 튜플의 순서). 기대: 옛 층④ ✗ ⇒ 새 (b) ✗. 양성 대조 같은 꼴. 표를 보고에.
- [ ] **Step 5: 기록 한 줄** — 층④ 두 경로 비교(둘째 · `shared/tests/test_copy_of_contract.sh` (b)). 커밋.

---

### Task 19: codex_gate_observation — 감지기 부재를 사본에서(보안)

**Files:** Modify `test_codex_gate_observation.sh:17-53,252-330`

**Interfaces:**
- Produces: 감지기 부재 시나리오는 `$SCRATCH/tree/` 에 `plugins/<플러그인>/` 과 `shared/` 를 같은 깊이로 `cp -R`(상대 링크 보존) 한 사본에서 돈다 — `sk` · `plugin_root_dir` 를 사본 경로로 바꾸고 사본의 `scripts/detect_codex.sh` 링크만 지운다. `[ -L ]` 가드와 루프 안 복원 확인은 사본 쪽에 남는다. 실제 체크아웃의 링크는 건드리지 않는다.

- [ ] **Step 1: 옛 커밋** — `B19=$(git rev-parse HEAD)`.
- [ ] **Step 2: 고친다** — 위 꼴. 사고 기록 주석 :18–36 은 지키는 것 한 문장(「감지기 부재는 사본의 링크를 지워 재고, 실제 배포 지점은 건드리지 않는다」)으로 줄인다(설계 §7 RC37).
- [ ] **Step 3: 돈다** — Fail 0, Total 기준값과 같다.
- [ ] **Step 4: 작업 트리를 건드리지 않음(AC16 · Review Focus 5)** — 돌리는 동안 다른 셸에서 `ls -l plugins/*/scripts/detect_codex.sh` 를 1초 간격으로 다섯 번 → 늘 링크다. 끝난 뒤 `git status --porcelain -- plugins shared` 비었다. 사본에서 `run_scenario` 앞에 `kill -9 $$` 를 넣어 돌린 뒤에도 실제 링크가 남아 있다.
- [ ] **Step 5: 커밋** — `test(qg): codex 게이트 관측의 감지기 부재 시나리오를 사본에서 돌린다`.
- [ ] **Step 6: 변이 견주기(K6)** — 옛 = `$B19`, 새 = HEAD. 범위마다 넷:
  - 원장 ratchet(:56–117): 삭제(`UNGATED_run_codex_reviewer_sh=` 줄) · 추가(게이트가 있는 러너의 `UNGATED_…` 줄) · 반전(ratchet 의 stale 판정 조건) · 형태(SKILL 하나의 `codex-gate:begin` 마커 글자를 바꾼다).
  - kill switch(:209–221): 삭제(`detect_codex.sh` :61–64) · 추가(spec-distill conf 의 변수 이름을 다른 이름으로) · 반전(`== "1"` → `!= "1"`) · 형태(`== "1"` → `== "yes"`).
  - 감지기 부재(:252–330): 게이트 펜스 하나(spec-review 의 것)에 삭제(`skip_reason="detector_not_runnable"` 줄) · 추가(감지기가 없을 때 `codex_avail=true`) · 반전(`[[ "$codex_avail" == "true" ]]` → `!=`) · 형태(감지기 경로를 `${CLAUDE_PLUGIN_ROOT}` 가 아닌 고정 레포 경로로).
  기대: 옛 ✗ ⇒ 새 ✗. 양성 대조 같은 꼴. 형태 변이의 「고정 경로」 는 사본에서 1회가 나와 RED 로 드러나야 한다(표 「고치면 잃는 확인」 칸). 표를 보고에.

---

### Task 20: agent_model_mutation — 변이를 사본에서

**Files:** Modify `test_agent_model_mutation.sh:37-82`

- [ ] **Step 1: 고친다** — 레포의 agents 를 직접 고치지 않는다: `plugins/` · `shared/` 를 링크째 임시 폴더에 복사하고 `git init` · 커밋 한 뒤 거기서 변이 · 복원한다((f) :84–91 의 꼴). clean-tree 전제(:37–41)와 trap 복원은 걷는다. 락이 cwd 상대 경로와 `git rev-parse --show-toplevel` 을 쓰므로 락은 사본을 cwd 로 돈다.
- [ ] **Step 2: 양성 대조부터** — 사본에서 변이 전 락들이 GREEN 이다(빠진 파일이 있으면 여기서 RED 로 드러난다 — 그 파일을 복사 목록에 더한다).
- [ ] **Step 3: 돈다** — Total/Pass 기준값과 같다. 끝난 뒤 `git status --porcelain` 비었다. 돌리는 동안 `plugins/*/agents/*.md` 의 수정 시각이 바뀌지 않는다(AC16).
- [ ] **Step 4: 이빨** — 사본 위의 사본에서 스윕(`test_agent_model_unpinned_sweep.sh`)이 `model:` 을 보지 않게 망가뜨려 돈다 → 변이 테스트 ✗.
- [ ] **Step 5: 커밋** — `test(qg): model 변이 테스트가 작업 트리 대신 사본에서 변이한다`.

---

### Task 21: 이력 주석 — 묶음 A 가 고친 파일

**Files:** Modify `harness/test_skill_orchestration_behavior.sh`(:3–100 대부분 · :189–208 · :269–278 · :385–390 · :457–462 · :491–506 · :533–550)와 과제 2–20 이 고친 파일(주석만)

- [ ] **Step 1: 덜기 전 커밋** — `B21=$(git rev-parse HEAD)`.
- [ ] **Step 2: 글을 읽는 락을 찾는다** — 파일 이름마다 `git grep -l -F <이름> -- 'plugins/*/tests/*' 'shared/tests/*'` 에서 그 파일을 글자로 읽는 테스트(예: `# guards:` · 줄 수 · 코퍼스)를 적는다. 덜 주석이 그 락이 세는 글이면 덜지 않는다.
- [ ] **Step 3: 덜어 낸다(AC11)** — 언제 · 어느 PR · 어느 라운드 · 누가 고쳤는지만 말하는 주석(`〔2026-08-17 fix round 2〕` · `Task 31 fix round 1` · `PR4a:` · `T3-3:` · 「대상 소멸」 묘비)을 지운다. 무엇을 지키는지 · 왜 그 꼴인지 말하는 문장은 남긴다(orchestration_behavior 머리 :5–13 의 guards 경로 도출 설명 포함). 실제 우회 기록처럼 판정 근거인 주석은 지키는 것 한 문장으로. `# guards:` 줄 · here-doc · 따옴표 안 `#` 줄은 건드리지 않는다.
- [ ] **Step 4: 주석만 바뀌었는지 본다** — 셸: `norm() { bash -c 'body="$(cat "$1")"; eval "__w() {
$body
}" && declare -f __w' _ "$1"; }` 를 `$TMPDIR/e4-pr5/norm.sh` 에 두고 `git show "$B21":<파일>` 과 지금 파일에 돌려 `cmp`. python: `python3 -c 'import ast,sys; print(ast.dump(ast.parse(open(sys.argv[1],encoding="utf-8").read())))'` 앞뒤 `cmp`(독스트링을 고쳤으면 다르게 나온다 — 그때는 독스트링 차이만 사람이 읽어 보고에 싣는다). 모두 같다. `bash -n` 통과.
- [ ] **Step 5: 돈다 · 커밋** — 고친 파일을 다시 돌려 과제 20 뒤 값과 같다. `test(qg): 정리한 테스트에서 이력 주석을 덜어 낸다`.

---

### Task 22: 묶음 A 마무리 · #347 관문

**Files:** 없음(`$TMPDIR/e4-pr5/`)

- [ ] **Step 1: 뒤 시간** — `files-A.txt`(지운 파일 빼고)를 잠금 명령으로 `after-times-A.tsv`. 파일마다 앞 · 뒤 · 차이를 표로. 표 「줄어드는 초」 가 음수인 파일에서 뒤가 앞보다 작지 않으면 까닭(부하 · 흔들림)을 적는다.
- [ ] **Step 2: §5 점검(AC9 · AC10)** — 구현 보고에 기대는 꼴마다 한 줄: 지움을 막는 문서(`git diff --name-only --diff-filter=D origin/main...HEAD` 의 이름마다 Task 2 Step 1 꼴 → 0) · 실행 · 목록 요구(`test_entry_safety_e1_e6.sh` · `test_intent_critic_wiring.sh` 통과) · import(지운 `.py` 를 import 하는 것 0) · 테스트를 시험하는 테스트(`test_agent_model_mutation.sh` 통과) · `# guards:`(`bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`) · 이빨이 기대는 쪽(`shared/tests/test_no_new_duplication.sh`) · 실패 원장(`codex-blessed-red.txt` 등재 그대로 · backward_compat 이름 그대로) · 부재 락 코퍼스(`test_publish_surface_removed.sh` · `test_gate_era_prose_absent.sh` 통과).
- [ ] **Step 3: 테스트 다섯과 레포 락** — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `shared/tests/test_charter_citations.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `plugins/spec-distill/tests/test_begin_round_snapshot.sh` · `shared/tests/test_presence_corpus_behavior.sh` · `shared/tests/test_no_new_duplication.sh` · `shared/tests/test_shell_tests_executable.sh`. 실패가 있으면 Task 1 의 HEAD 사본에서도 같은지 가른다.
- [ ] **Step 4: 받는 쪽 · 고친 파일 한 바퀴** — `files-A.txt` · `receivers.txt` 를 다시 돌려 Fail 0 이고 Total 차이가 과제마다 적은 늘고 준 수와 맞다(표로).
- [ ] **Step 5: 금지 파일 · 기록 수(AC12 · AC14 · AC8)** — `git diff --name-only origin/main...HEAD` 에 `plugin.json` · `CHANGELOG.md` · `test_stage_prose_trim.sh` · `docs/testing.md` 없음. 바뀐 파일이 과제 1 의 목록 · 주석 다섯 · `docs/removed-tests.md` · 이 계획 · 설계문서뿐. 셸 테스트 모드 100755. `docs/removed-tests.md` 의 이 PR 줄 수가 과제마다 적은 합(묶음 A — 38)과 같다.
- [ ] **Step 6: push · 관문** — `git push`. `gh pr view 347 --json state` 가 `MERGED` 가 아니면 **여기서 멈추고** 지휘자에게 보고한다: 「묶음 A 끝(커밋 · 시간 표 · 변이 표 경로) · 묶음 B 는 #347 머지 뒤 과제 23 부터」. `MERGED` 면 과제 23 으로.

---

## 묶음 B — #347 머지 뒤 16행(+ K1 의 셋)

### Task 23: #347 합침 · 다시 읽기 · 앞 시간

**Files:** `docs/removed-tests.md`(합침 충돌만)

- [ ] **Step 1: 머지 확인** — `gh pr view 347 --json state,mergeCommit` → `MERGED`. `git fetch -q origin && git merge-base --is-ancestor <mergeCommit> origin/main` → 0.
- [ ] **Step 2: 합친다** — `git merge --no-edit origin/main`. `docs/removed-tests.md` 충돌은 `## 항목` 아래에 먼저 머지된 쪽 줄이 위, 이 PR 줄이 아래, 머리 뒤 빈 줄 하나 · 항목 사이 빈 줄 없음으로 푼다. 설계문서(`docs/superpowers/specs/2026-11-26-test-prune-design.md` — #350 · #351 과 add/add)의 충돌은 `relay/E4/merge-order-notes.md` 「PR 5 가 main 을 합칠 때」 절대로 푼다(PR 1 · 3 승인 줄 → 지휘 기록 다섯 줄 → PR 5 승인 줄 · `## 판정` 은 하나) — 푼 뒤 그 절의 확인 명령을 돈다. 다른 파일 충돌은 표에 닿는지 보고 고치기 전에 보고한다. 합친 뒤 과제 22 Step 3 의 테스트를 다시 돌린다.
- [ ] **Step 3: 다시 읽는다** — 표 끝 목록의 16행과 K1 의 셋(TestFilteredListed · plain_readme 남김 · governance 부분 핀)마다 합친 HEAD 에서 그 테스트 · 겹침 상대 · 받는 쪽을 다시 열어 `reread-B.tsv`(행 · 바뀐 줄 번호 · 짝 · 받는 쪽 · 판정이 표와 같은가 · 근거)를 쓴다. 표가 #347 에 기댄 사실(예: TestGate final 갈래를 `test_retired_switches_do_not_skip` 이 잰다 · plain_readme :118–121 행 32 지움 · intent_wide :475–500 지움 · critiquing :17–30 지움 · e2e_docs DISABLE_E2E 지움 · pipeline_verdict :250–286 지움)이 합친 HEAD 에서 참인지 하나씩 본다.
- [ ] **Step 4: 판정이 다르면 BLOCKED** — 판정 · 고침 · 받는 쪽이 표와 다른 행은 고치지 않고 지휘자에게 `BLOCKED — <행> · 표: … · 다시 읽은 것: … · 근거` 로 올린다. 사용자 동의가 와서 표가 고쳐지기 전에는 그 행을 하지 않는다(같은 파일의 다른 행은 해도 된다).
- [ ] **Step 5: 앞 시간 · 기준값(K10)** — `files-B.txt` 와 그 받는 쪽(`test_intent_return.py` · `test_intent_handed.py` · `test_other_teams.py` · `test_topic_scope_wiring.sh`)을 돌려 `before-B/` · `before-totals-B.tsv`, 잠금 명령으로 `before-times-B.tsv`.

---

### Task 24: review_diff — 한 번 지어 복사 · 되풀이 줄이기(보안)

**Files:** Modify `test_review_diff.sh`(`mkfix` · rc 2 되풀이 · case_registered_worktree_only_not_degraded · 사본 확인 하나) · `docs/removed-tests.md`

- [ ] **Step 1: 옛 커밋** — `B24=$(git rev-parse HEAD)`.
- [ ] **Step 2: 사본 확인을 쓴다(K8)** — `case_mkfix_copies_are_isolated`(과제 16 Step 2 와 같은 단언 셋 — 이 파일의 A/R 이름으로). 통과를 본다.
- [ ] **Step 3: `mkfix` 를 견본 복사로** — 표 1절 첫 행 그대로(사본 R 의 origin 을 사본 A 로 · A 에 커밋을 더하는 case_keep_batches 는 사본 A 에서). 사본에서 `set-url` 을 지워 Step 2 ✗ 를 본다.
- [ ] **Step 4: 되풀이를 덜기 전 견주기(보안 :670–681)** — 등록 worktree 양성 짝이 `case_other_session_worktree_degraded` 의 짝(다시 읽은 줄 번호)과 같은 상태인지 본다 — degraded no · self_state 1 · 알림 없음. 다르면 멈추고 보고. #347 이 더한 `case_branch_holding_same_name_worktree` 의 짝도 같은 상태인지 적는다.
- [ ] **Step 5: 덜고 돈다** — rc 2 되풀이 하나와 등록 worktree 케이스를 지운다. Fail 0. `test_topic_scope_wiring.sh` 기준값과 같다.
- [ ] **Step 6: 커밋** — `test(qg): review-diff 테스트가 픽스처를 한 번 지어 복사하고 되풀이 확인을 던다`.
- [ ] **Step 7: 변이 견주기** — 옛 = `$B24`, 새 = HEAD. `plugins/quality-gates/scripts/review-diff.sh` 의 등록 worktree 판정(이 세션 사본만 있을 때 degraded 로 가지 않는 갈래 — 자리를 보고에)에: 삭제 · 추가(그 갈래 앞에서 degraded 를 켠다) · 반전 · 형태(이 세션 판정에 쓰는 경로 비교를 `realpath` 없이). 기대: 옛 ✗ ⇒ 새 ✗(남는 양성 짝이 받는다). 양성 대조 같은 꼴. 표를 보고에.
- [ ] **Step 8: 기록 한 줄** — rc 2 되풀이 · 등록 worktree(둘째 · `plugins/quality-gates/tests/test_review_diff.sh` 의 남는 rc 2 케이스 · 다른 세션 worktree 케이스의 양성 짝). 커밋.

---

### Task 25: intent_critic `_git_repo` · intent_wide — 한 번 지어 복사

**Files:** Modify `test_intent_critic.py`(`_git_repo` 옆 새 진입점 · 그것을 쓰는 자리 · 사본 확인 하나) · `test_intent_wide.py`(`_wide_repo` · `_WideRun` 의 리뷰 트리 · 사본 확인 하나)

**Interfaces:**
- Produces: `test_intent_critic.py` 에 `_git_repo_copy(root) -> str` — 모듈에서 한 번 지은 `_git_repo` 결과를 `shutil.copytree(src, root, symlinks=True, dirs_exist_ok=True)` 로 나눠 준다. `_git_repo` · `_origin_repo` 는 그대로(import 하는 넷이 쓴다). `test_intent_wide.py` 의 `_wide_repo` 도 같은 꼴(모듈 견본 + 시험마다 copytree). subTest 안 tearDown/setUp(:589–597)은 복사로 바꿀 뿐 그대로.

- [ ] **Step 1: 사본 확인을 쓴다** — 두 파일에 하나씩: 사본 둘을 떠 한쪽에 커밋 · 파일을 더해도 다른 쪽에 없고, 사본의 `.git` 아래 어느 파일에도 견본의 절대 경로가 없다(`Path.rglob` + 바이트 검색). 통과를 본다.
- [ ] **Step 2: 구현 · 실패를 본다** — 새 진입점을 넣고 원래 `_git_repo` 를 부르던 이 파일 안 자리(표: 77번)를 바꾼다. 사본에서 copytree 대신 견본 경로를 그대로 돌려주게 망가뜨려 Step 1 ✗.
- [ ] **Step 3: 돈다** — `python3 test_intent_critic.py` · `test_intent_wide.py` → 시험 수 = 기준값 + 1 씩, OK. import 하는 넷(`test_intent_wide.py` · `test_intent_return.py` · `test_other_teams.py` · `test_intent_handed.py`) OK. 보안 범위(표 1절의 두 행)의 시험 이름 · 결과가 기준값과 같다(`-v` 대조).
- [ ] **Step 4: 커밋** — `test(qg): 의도 점검 시험이 git 레포를 한 번 지어 복사해 쓴다`.

---

### Task 26: intent_critic — TestGate 옮김 · TestFilteredListed 내림 · 판정 미룸 행

**Files:** Modify `test_intent_return.py`(test_skip_and_fail_codes) · `test_intent_critic.py`(TestGate.test_paths · test_tree_failed_writes_return_block · TestFilteredListed.test_mode_file_with_other_text_falls_back_to_the_argument)

- [ ] **Step 1: 받는 쪽 글자 넷을 쓴다(B-1)** — test_skip_and_fail_codes 의 네 갈래마다 `_last(p)` 를 글자 그대로의 기대값(「intent-critic — 건너뜀(멈춘 실행)」 등 — `references/intent-critic.md:38–39` 와 `scripts/intent_critic.py` 에서 갈래마다 읽어 손으로 적는다)과 견주는 단언을 더한다.
- [ ] **Step 2: 실패를 본다** — 사본에서 `intent_critic.py` 의 그 결과 줄 하나의 「건너뜀(」 을 「건너뜀 (」 로 → 새 단언 ✗. 같은 변이에서 옛 TestGate 도 ✗ 인지 적는다.
- [ ] **Step 3: TestGate 두 케이스를 지운다** — final 갈래(:1171–1174 — 다시 읽은 번호)는 #347 의 `test_retired_switches_do_not_skip` 이 잰다는 것을 과제 23 Step 3 이 확인했을 때만.
- [ ] **Step 4: TestFilteredListed 를 내린다(②)** — 15변형은 `ic._review_mode` 를 프로세스 안에서 부르는 subTest 로, CLI 끝에서 끝은 대표 둘(garbage · BOM)만. 사본에서 `_review_mode` 가 다섯 낱말과 글자 그대로가 아닌 값을 받아들이게 망가뜨려 내린 확인 ✗.
- [ ] **Step 5: 판정 미룸 행(K9)** — TestRender 두 케이스 · TestRecordSilentDrops · TestRecordUnreadAnswers 를 `test_intent_return.py` TestQuestionRows · TestAnswerInput 과 케이스마다 대조해 판정(첫째–다섯째)과 근거를 `reread-B.tsv` 에 더하고 지휘자에게 올린다. 고치지 않는다.
- [ ] **Step 6: 돈다 · 커밋** — 두 파일 · import 하는 셋. `test(qg): 의도 점검 gate 결과 줄을 받는 쪽에서 글자로 재고 겹친 케이스를 지운다`(옮긴 합침 · 내림 — 기록 줄 없음).

---

### Task 27: 문장 · README 단언 — pipeline_verdict · plain_readme · critiquing · e2e_docs

**Files:** Modify `test_pipeline_verdict_wiring.sh`(:388–390 · :400 — 다시 읽은 번호) · `test_plain_readme.sh` · `test_critiquing_artifacts_skill.sh` · `test_e2e_docs.sh` · `docs/removed-tests.md`

- [ ] **Step 1: 줄인다(넷째)** — pipeline_verdict 끝 한 줄 조건 문장과 Step 4.5 줄을 표 4절의 뜻 낱말로. critiquing E3 문장 전체 단언(:71 · :76 · :78–79 · :243 · :250–251 · :253 · :263 — 다시 읽은 번호)을 뜻 낱말로, 라벨은 그대로, 부재는 짧은 양성 짝과 함께. e2e_docs 걸음 문장 줄 전체를 「셋을 넘으면 셋만」 · 「선택지는 넷을 넘지 않는다」 로, 게이트 표 행을 선택지 낱말로, 부재(:417–422)는 둔다. 파일마다 사본에서 남긴 낱말의 문장을 지워 ✗ 를 한 번 본다.
- [ ] **Step 2: 지운다(첫째)** — plain_readme 문단 · 문장 단언(표 3절 첫 행)과 남김 행의 :24–28 · :33–35 · :53–64(:41–42 · :113–115 는 남긴다). critiquing README 두 단언(:87–88). e2e_docs README 한계 · P4 줄 단언. plain_readme :31–32 주석이 `test_publish_surface_removed.sh` 스윕을 대는 말이 줄인 뒤에도 맞는지 본다.
- [ ] **Step 3: 보안 둠 행을 다시 본다** — critiquing 보안 · e2e_docs 보안 · pipeline_verdict 둠 행의 줄 범위가 합친 HEAD 에서 그대로이고 이 과제가 그 줄을 건드리지 않았다(`git diff` 의 hunk 가 그 범위 밖).
- [ ] **Step 4: 돈다** — 네 파일 · `test_guards_coverage_bidirectional.sh`(plain_readme 의 README 선언이 :41–42 로 남는다) · `test_publish_surface_removed.sh` · `test_angle_coverage.sh`.
- [ ] **Step 5: 기록 세 줄** — plain_readme 문장 단언과 남김 행의 지우는 몫(첫째 · 없음 — 받아들임) · critiquing README 두 단언(첫째 · 없음) · e2e_docs README · P4 단언(첫째 · 없음).
- [ ] **Step 6: 커밋** — `test(qg): README · 설명 문장을 무는 단언을 지우고 걸음 문장을 뜻 낱말로 줄인다`.

---

### Task 28: governance — 확정 문안 핀을 뜻 낱말로

**Files:** Modify `test_governance_no_capability_caps.sh`(FIXED_* · STATE_LINE · SWITCH_LINE · 한 문장 전체를 무는 `assert_contains`)

- [ ] **Step 1: 줄인다(⑧ · B-6)** — 줄 전체 등호를 그 규칙의 가장 짧은 낱말 단언으로(「지출 승인을 묻지 않는다」 · 「`.claude/<plugin>/`」 · 「통째 끄기용 환경변수를 두지 않는다」 등 — 상수마다 하나). 한 문장 전체를 무는 contains(:133–135 · :139 — 다시 읽은 번호)는 같은 꼴로. 이미 구절 단위인 것 · AC8a · AC8e 스캔은 둔다. #347 이 끝에 더한 17줄은 건드리지 않는다.
- [ ] **Step 2: 줄인 확인이 무는지 본다** — 사본에서 CLAUDE.md 의 「지출 승인을 묻지 않는다」 가 든 문장을 지운다 → ✗. P22 쪽 하나 더.
- [ ] **Step 3: 돈다 · 커밋** — Fail 0. `test(qg): 규칙 문서 확정 문안의 바이트 핀을 뜻 낱말로 줄인다`(넷째 — 기록 줄 없음).

---

### Task 29: 묶음 B 마무리

**Files:** 묶음 B 가 고친 파일(주석만)

- [ ] **Step 1: 이력 주석(AC11)** — 과제 24–28 이 고친 파일에서 과제 21 Step 2–4 그대로(덜기 전 커밋 `B29` · `declare -f` / ast 비교). 커밋 `test(qg): 의도 점검 · 범위 테스트에서 이력 주석을 덜어 낸다`.
- [ ] **Step 2: 뒤 시간** — `files-B.txt` 를 잠금 명령으로 `after-times-B.tsv`. 과제 22 Step 1 과 같은 표.
- [ ] **Step 3: 점검** — 과제 22 Step 2–5 를 합친 HEAD 에서 다시(§5 · 테스트 다섯 · 받는 쪽 · 금지 파일 · 기록 수 — 묶음 B 는 넷에 과제 26 K9 로 승인된 지움이 있으면 그만큼).
- [ ] **Step 4: push.**

---

### Task 30: 마지막 전체 리뷰 · 미룸 · 대조 · PR 재료

**Files:** `docs/superpowers/specs/2026-11-26-test-prune-design.md`(`## 미룸` 표 — 있을 때만) · `docs/removed-tests.md`(PR 번호)

- [ ] **Step 1: 구현 보고** — `$TMPDIR/e4-pr5/impl-report.md`: 과제 1 의 다시 확인 · 기준값 · 앞뒤 시간 표(A · B) · 변이 표(과제 4 · 14 · 16 · 17 · 18 · 19 · 24) · 옮긴 확인의 실패 보기(과제 5 · 6 · 7 · 12 · 26) · 줄인 확인의 실패 보기 · 사본 확인(K8) · §5 점검 · 테스트 다섯 · 과제 23 의 다시 읽기 표 · K9 판정 · 계획의 판단 ✎ 줄이 실제로 어떻게 들어갔는지 · 구현 중 찾은 새 후보(고치지 않았다).
- [ ] **Step 2: 마지막 전체 리뷰** — 아래 「마지막 전체 리뷰에 싣는 것」 대로 띄우고 AC 보고를 `$TMPDIR/e4-pr5/ac-report.md` 에 쓴다(git 이 추적하지 않는다 — `git check-ignore -q` 로 확인하거나 worktree 밖).
- [ ] **Step 3: 미룸** — 리뷰가 「미룸」 · 「빠짐」 으로 낸 AC(AC13 · AC3 · AC4 · AC5 · AC17 은 다른 자리 몫이라 올리지 않는다)와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 줄씩 더하고 커밋(`docs(spec): …`). 없으면 건너뛴다.
- [ ] **Step 4: 묶음 대조** — `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/9.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-26-test-prune-design.md "$TMPDIR/e4-pr5/ac-report.md" --acs "AC1,AC2,AC6,AC7,AC8,AC9,AC10,AC11,AC12,AC13,AC14,AC15,AC16"` 의 출력(경고 포함)을 그대로 지휘자에게 보인다.
- [ ] **Step 5: PR 본문 재료(AC1 · AC2 · AC15)** — 지휘자에게 넘긴다: 승인 표(`table-pr5-final.md` 그대로) · 승인 줄(설계문서 끝 「판정 표 승인 · 2026-11-28 · PR 5」) · 읽은 담당자 A · 다시 읽은 담당자 B(서로 다른 Opus 하위 agent)와 갈린 행(표 「기대는 곳」 칸의 「A·B 갈림」 여덟 행 원문) · 앞뒤 시간 표 · 변이 보고 · §5 점검 · 기록 줄 목록 · 평가 「쓰는 조건」 넷에 드는 줄인 글자 확인 「없음」 · K9 판정과 그 처리. PR 을 여는 일은 지휘자의 흐름이다.
- [ ] **Step 6: PR 번호(AC8)** — PR 이 열리면 이 PR 의 기록 줄마다 `PR #<번호>` 를 채워 같은 PR 의 다음 커밋으로 올린다(`docs(test): 지운 테스트 기록에 PR 번호를 채운다`).

## 마지막 전체 리뷰에 싣는 것

- 범위: `origin/main...HEAD` 전체. 리뷰어는 쓰기 도구가 없는 agent 다(Law 2).
- 설계문서 `## Acceptance Criteria` 원문 · 승인 표 원문 · 이 계획의 `## AC 가르기` · `## 계획의 판단` 표.
- 요청: 이 PR 몫 AC(`AC1,AC2,AC6,AC7,AC8,AC9,AC10,AC11,AC12,AC13,AC14,AC15,AC16`)마다 한 줄 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>`. AC13 은 「미룸 — 지휘자 대조」. AC3 · AC4 · AC5 · AC17 은 「미룸 — 다른 PR(PR 1 · 2 · 3 · 로드맵 끝)」. AC1 · AC2 · AC8 의 PR 본문 · 번호 몫은 「PR 본문 재료 · 과제 30 Step 5–6」 을 근거로.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 — 기준은 `docs/testing.md` 그대로(바꾸지 않음) · 기록은 `docs/removed-tests.md` 의 줄 꼴 · 점검에 `test_guards_coverage_bidirectional.sh` · `test_charter_citations.sh` 를 썼는가 · 시간은 공유 잠금 아래 대상 파일만 쟀는가 · 평가 케이스 장치를 쓰지 않았는가 · 준비물은 있는 도우미(`_git_repo` · `mkfix` · `new_repo`) 옆에 얹었는가(새 도우미 파일 없음).
- 끝에서 끝을 따로 물어라: 지운 확인마다 기록 줄의 「지금 지키는 것」 이 실제로 그것을 재는가 · 받는 쪽 단언이 남아 있는가(lowered :65 · :68 · :98 · skill_orchestration :37–41 · plain_qg_templates :30 · E6 · E1 · Case 3 · copy_of (b)) · 사본으로 옮긴 테스트(detect_codex · gate_observation · agent_model_mutation)가 실제 체크아웃에 쓰지 않는가 · 사본 R 의 origin 이 사본 A 인가 · 메모한 결과를 깊은 복사로 내주는가 · #347 합침 뒤 다시 읽은 행이 표와 같은가.
- 계획이 쓴 테스트 코드(과제 5 Step 1 · 5 · 과제 6 Step 1 · 과제 7 Step 1 · 과제 12 Step 1 · 사본 확인 K8 · 과제 26 Step 1)와 계획이 정한 판정(K1–K12)은 계획이 정한 것이라고 밝혀 같은 눈으로 보게 한다. 고친 기존 확인에서 표에 없는 단언이 지워지거나 느슨해지지 않았는지 `git diff <과제 1 HEAD> -- 'plugins/*/tests/*' shared/tests` 로 보게 한다 — 이력 주석 덜기(과제 21 · 29)는 주석만이어야 한다.
