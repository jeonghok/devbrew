# 테스트 진단 — 재독 결과

처음 읽은 사람과 다른 리뷰어 다섯이 92단위를 다시 읽은 결과다.

## 표본 a1 — 지움 · 합침 후보 1

### plugins/plugin-audit/tests/test_axis3_reachability_question.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — 축 3 창의 `무엇을 막는가` · `kill switch` · `systemMessage` · `도착했는지 확인하는 자리` 와 `n: N,` 여섯 개를 잰다(test_axis3_reachability_question.sh:25-45). 다만 이 글은 감사 agent 가 읽는 질문 자체다(audit-workflow.js:381-394). 그래서 「동작을 정하지 않는다」는 틀렸다.
- 겹침: 일부만 — audit-workflow.test.mjs:701-715 는 같은 창에서 `kill switch` · `DEVBREW_<PLUGIN>_DISABLE_<기능>` 만 잰다. 축 여섯은 :463-466(`axes default runs all six`)이 동작으로 잰다(행은 이것을 적지 않았다). `systemMessage` · 도착 확인 · `무엇을 막는가` 는 이 테스트만 잰다.
- 판정: 서지 않는다 — 감사 질문에서 「지시가 받는 채널에 닿는가 · 값이 도착했는지 확인하는가」 두 물음이 빠지는 것을 막는 테스트는 이것뿐이다. 그 질문을 빼면 감사가 그 축을 보지 않는다.
- 보안 갈래: 맞음 — 감사 프롬프트 문구일 뿐 보안 경계 확인이 아니다
- 권하는 판정: 합침 — grep 세 줄을 audit-workflow.test.mjs:701 의 축 3 창 테스트에 `win.includes` 로 옮긴다. 같은 창을 이미 읽고 있다.

### plugins/project-init/tests/test_branch_strategy_rebase_clause.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — 템플릿 두 개(github-flow · git-flow)에 무조건 금지 문구가 없고 완화 문구가 있는지, 리포 루트 문서에 원문이 남았는지를 잰다(:21-46). 템플릿은 project-init 이 사용자 리포의 `docs/git-workflow/branch-strategy.md` 로 깔아 주는 agent 규칙이다(skills/project-init/SKILL.md:224 · :264). 그래서 「동작을 정하지 않는다」는 틀렸다.
- 겹침: 맞음(못 찾음) — test_branch_prefix_templates.py · test_plain_init_text.py 에 rebase 확인은 없다(grep 0건).
- 판정: 서지 않는다 — 사용자 리포에 까는 규칙이 무조건 rebase 금지로 되돌아가는 것(능력 억제 스윕이 걷은 조항), 그리고 리포 루트에 적힌 사용자 선호(C3)를 덮는 것을 막는 테스트는 이것뿐이다. 0.1초짜리다.
- 보안 갈래: 맞음 — 보안 경계가 아니다
- 권하는 판정: 둠 — 이 테스트만 지키는 것이 있고 비용이 거의 없다

### plugins/quality-gates/tests/test_artifact_metadata.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — 판 바닥 2.11, CHANGELOG `[2.11.0]` 헤딩, 옛 skill 이름, README 의 `critique` · `artifact-critic|artifact-critique` 를 잰다(:10-16).
- 겹침: 일부만 — 행은 「확인 못 함」이다. 실제로 CHANGELOG 헤딩이 빠지는 일은 shared/tests/test_changelog_integrity.sh(C5 건너뛴 판)가 잡는다. README 낱말은 따로 재는 곳을 찾지 못했다(문서 글자다).
- 판정: 선다 — 남는 것은 지난 판의 기록과 README 낱말뿐이다. 동작을 정하지 않는다.
- 보안 갈래: 맞음 — 해당 없음
- 권하는 판정: 지움

### plugins/quality-gates/tests/test_cost_consent.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — tests/harness/run_consent_gate.sh(테스트 쪽 흉내)만 부른다(:23 · :34). 플러그인 코드는 하나도 실행하지 않는다.
- 겹침: 맞음 — `codex-cost-consent` 를 쓰는 곳은 이 테스트와 하네스뿐이다. CHANGELOG.md:490 · :2348 은 그 장치가 없어졌다고 적고, test_gate_era_prose_absent.sh:50-54 는 README 가 그 장치를 주장하지 않는다고 잰다.
- 판정: 선다 — 없는 장치의 흉내라 지키는 것이 없다. 실행하면 사용자 홈의 `~/.claude/quality-gates/codex-cost-consent.md` 를 옮기는 위험만 있다(:16).
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움 — 함께 쓰는 곳이 없어지는 tests/harness/run_consent_gate.sh 도 같이 지운다(행에 없음)

### plugins/quality-gates/tests/test_impact_runtime_docs.sh
- 원래 판정: 지움
- 지키는 것: 어긋남 — 행이 다섯 케이스 가운데 `case_readme_principles`(README `## Principles Instantiated` 의 LD3 · LD5 · LD7 줄, :60-67)를 빠뜨렸다. 나머지 넷은 행대로다.
- 겹침: 일부만 — 행은 「확인 못 함」이다. 실행 비트는 shared/tests/test_test_selection_bundle.sh:20-25 가 이미 잰다(qg 세 이름은 shared/test-selection 공유본으로 가는 링크이고, 공유본이 100755 인지를 잰다). CHANGELOG 헤딩이 빠지는 일은 test_changelog_integrity.sh 가 잡는다. README `## 구조` 트리와 LD 줄을 재는 곳은 따로 없다(문서 글자다).
- 판정: 선다 — 실행 비트는 이미 다른 곳이 잰다. 남는 README · CHANGELOG 글자는 동작을 정하지 않는다. 행의 「실행 비트만 남기고 싶으면 옮긴다」는 할 필요가 없다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움

### plugins/quality-gates/tests/test_qg_false_clean_floor.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — floor_verdict(:29-38)는 테스트 안의 사본이다. 실제로 재는 것은 check-review-scope.sh 출력의 changes_exist · branch_ahead_count · degraded 뿐이다(:70-136).
- 겹침: 맞음 — test_check_review_scope.sh 가 네 상태를 모두 잰다: 앞선 브랜치(:32-39), base 위 변경 없음(:47-55), base 없음(weirdname, :136-146), 그 밖의 경우까지. SKILL 문면은 harness/test_skill_orchestration_behavior.sh:412-420 이 잰다.
- 판정: 선다 — 남는 확인은 모두 더 싼 쪽에 이미 있다. floor 판정은 모델 문면이라 이 사본은 자기 자신을 잰다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움

### plugins/quality-gates/tests/test_readme_scope_reconcile.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — README 에 옛 fan-out 동의 게이트 주장이 없는지(:15-19), 리뷰어 구성 표 행 · Prerequisites 의 `pr-review-toolkit` · `feature-dev` 부재(:27-33), codex 비용 문장(:44-46)을 잰다.
- 겹침: 일부만 — test_review_scope_composition.sh 는 README 에 대해 `최대 8|≤ 8|max fan-out` 부재와 `위 표는 시작 구성이다` 만 잰다(:48-49). 구성 표 행 확인은 README 가 아니라 SKILL Step 3 창에 대해서다(:18-23). codex 비용 문장은 test_gate_era_prose_absent.sh:55 와 겹친다. README Prerequisites 가 `pr-review-toolkit` 을 대는 것, 그리고 `len(phase1)` · `≥4 … AskUserQuestion` 같은 없는 게이트 주장의 부재는 이 테스트만 잰다.
- 판정: 서지 않는다 — CLAUDE.md 규칙 두 가지를 이 테스트만 지킨다. 하나는 「다른 플러그인 agent 를 dispatch 하면 README prerequisites 에 그 플러그인을 적는다」, 다른 하나는 「막지 않는 것을 막는다고 믿게 하는 선언 금지」다. 행이 근거로 든 composition 은 SKILL 쪽을 잰다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침 — Prerequisites 두 줄과 옛 게이트 주장 부재 다섯 줄을 test_review_scope_composition.sh 의 README 단언(:48 근처)으로 옮긴다. 나머지 README 표 글자는 버려도 된다.

### plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — README 의 `single assistant turn` 도식이 하나인지, 표지 열 개가 있는지, 옛 두 게이트 표지 여덟 개가 없는지 잰다(:23-63). 상대 경로라 cwd 에 따라 결과가 갈린다(:11). 행 말대로다.
- 겹침: 어긋남 — test_plain_qg_templates.sh 가 README 에서 재는 것은 선택지 라벨 줄(:126-136, `고치고 다시 돌기` 등)이다. 도식 표지(`qg iter loop` · `② differential test` · `single assistant turn`)를 재는 테스트는 따로 없다(grep 0건).
- 판정: 선다 — 근거는 행과 다르다. 「다른 테스트가 이미 잰다」가 아니라 「README 도식은 사람이 읽는 문서라 동작을 정하지 않는다」여야 한다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움

### plugins/quality-gates/tests/test_skill_codex_skip_prose.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — SKILL 「Codex skip 안내」 표의 보이는 사유 문구 여섯(:14-29), 조용한 사유 둘이 배너 꼴로 나오지 않는지(:34-42), 머리말(:45)을 잰다. 이 표는 모델이 사용자에게 내는 문구다(SKILL.md:491-511). 덧붙여 `[^\n]` 는 ERE 괄호 안이라 `\` 와 `n` 두 글자를 뺀다. 그래서 음의 확인이 약하다는 행의 의심은 맞다.
- 겹침: 어긋남 — test_codex_result_banner.sh 는 같은 절 창(:72)에서 배너 · `산문 게이트|범위 밖` 만 잰다(:88-136). 사유별 문구(설치 · 로그인 안내)는 재지 않는다. test_codex_gate_observation.sh 는 실행 관측이고 표 문구는 보지 않는다. 사유 문구를 재는 테스트는 이것뿐이다.
- 판정: 서지 않는다 — codex 가 안 돌 때 사용자에게 무엇을 고치라고 보일지(loud degrade)를 정하는 모델 지시이고, 지키는 곳이 여기뿐이다.
- 보안 갈래: 맞음 — 아니오(조용한 사유에 kill_switch 이름이 있을 뿐 경계 확인은 아니다)
- 권하는 판정: 둠 — 고친다면 구조를 고침: detect_codex.sh 의 skip_reason 목록에서 표 행을 도출한다

### plugins/spec-distill/tests/test_compression_adopters.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — 도출한 채택자가 둘 이상인지(:87-93), 정본이 코퍼스에 없는지(:101-105), 낱말 두 묶음 grep(:120-128)을 잰다. 낱말이 일상어라 낱말 grep 은 거의 늘 참이라는 행의 말은 맞다.
- 겹침: 어긋남 — test_distortion_devices.sh 는 compression.md 와 request-framing 만 읽는다(:15-50). test_request_framing_entry.sh 도 request-framing 쪽이다. pm-interview 의 references/finishing.md:3 이 정본을 가리키는지, 곧 하한 2 를 재는 곳은 없다. 공용 adopter_derivation.sh 는 함수 정본일 뿐이다. 이 함수를 쓰는 다른 락(test_proceed_gate_adopters.sh)은 proceed-gate.md 를 잰다.
- 판정: 서지 않는다 — 헤더가 실측으로 밝힌 대로(:22-31), brief 단계(finishing.md)가 압축 규약 포인터를 잃는 일(2→1)을 잡는 곳은 이 하한뿐이다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 줄임 — 하한 2 도출과 정본 제외 확인은 남기고, 낱말 grep 두 개(:120-128)는 걷는다

### plugins/spec-distill/tests/test_hook_output_schema.py
- 원래 판정: 지움
- 지키는 것: 맞음 — state_path.state_root() 를 테스트 안에서 계산한 `${CLAUDE_PROJECT_DIR:-cwd}/.claude/spec-distill` 와 견준다(:45-61). 그런데 state_root() 는 설계상 worktree 에서도 본 레포 쪽을 낸다(state_path.py:73-110). 그래서 이 단언은 지금 설계와 반대이고, worktree 에서만 돌다가 실패만 낸다. spec-distill skills · scripts 에는 견줄 bash 해석기도 없다(grep 0건).
- 겹침: 맞음 — 실제 해석은 test_ledger_root.sh:35-37(연결된 worktree 안 문서 → 본 레포 상태 루트) · test_state_root.sh 가 실행으로 잰다.
- 판정: 선다 — 지키는 것이 없고, 오히려 설계와 반대되는 기대를 담고 있다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움

### plugins/spec-distill/tests/test_probe_sweep_residue.sh
- 원래 판정: 지움
- 지키는 것: 맞음 — 지운 probe 상한의 식별자 · 근접 개념이 plugins/spec-distill 안(픽스처 · CHANGELOG · 자기 제외)에 0건인지와, 정규식 양성 대조를 잰다(:17-50).
- 겹침: 맞음(못 찾음) — 다른 잔존 락은 찾지 못했다. 지금 식별자가 걸리는 곳은 CHANGELOG 뿐이다.
- 판정: 선다 — 한 번 끝난 스윕의 부재 락이다. 산문으로 되살아나는 것은 못 잡는다고 헤더가 스스로 밝힌다. 식별자 이름이 동작을 정하지는 않는다. 다만 걷은 것이 사용자가 정한 능력 억제 제거였다는 점은 승인하는 사람이 알아야 한다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 지움

### plugins/plugin-audit/tests/test_detect_codex.py
- 원래 판정: 합침
- 지키는 것: 맞음 — 건너뜀 사유 열 갈래, 이웃 변수 무시, conf 변수 이름, 잘못된 conf 의 fail-closed, 타임아웃 래핑 · 바닥 리터럴을 잰다(:33-125). conf 를 덮었다 되돌리는 것도 행대로다(:93-106).
- 겹침: 맞음 — 세 플러그인의 detect_codex.sh 는 모두 ../../../shared/codex/detect_codex.sh 로 가는 심볼릭 링크다(행에 없음 — 세 테스트가 같은 본문 하나를 잰다). 플러그인마다 다른 축(자기 변수에만 반응 · 이웃 변수 무효)은 quality-gates/tests/test_codex_copies_agree.sh:249-283 이 세 사본 모두에 대해 잰다. spec-distill/tests/test_detect_codex.sh:24-68 도 같은 케이스다.
- 판정: 선다 — 같은 스크립트를 세 번 잰다. 공유 테스트 하나와 플러그인별 conf 줄로 모을 수 있다.
- 보안 갈래: 맞음 — kill switch · 이웃 변수 무시 · conf fail-closed
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_agent_color.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — qg agents/*.md 의 color 가 8색 안에 있는지 잰다(:10-21). 상대 경로다.
- 겹침: 맞음 — test_artifact_critic_frontmatter.sh:10 · test_artifact_adversarial_frontmatter.sh:10 이 같은 정규식을 되풀이한다. test_agent_frontmatter_keys.sh 는 지금 color 를 재지 않으므로, 모으려면 그쪽에 더해야 한다.
- 판정: 선다
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — plugins/*/agents/*.md(10개 이상) frontmatter 에 model 키가 없는지와 README 우선순위 문장을 잰다(:24-48).
- 겹침: 맞음 — test_artifact_critic_frontmatter.sh:9 · test_artifact_adversarial_frontmatter.sh:9 · test_code_recritic_frontmatter.sh:19 · :34 가 개별로 되풀이한다. test_agent_model_mutation.sh:21 · :89 가 이 스윕의 이빨을 잰다.
- 판정: 선다 — 실제로는 이 파일은 그대로 두고, 개별 파일의 model 단언을 덜어 내는 방향이다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — name · model 부재 · color · `tools: Read, Grep, Glob` 정확 일치 · disallowedTools 부재 · 금지 도구 부재 · 페르소나 낱말 넷을 잰다(:7-22).
- 겹침: 일부만 — 전수 스캔 test_agent_frontmatter_keys.sh 는 금지 8종만 막는다(:39 · :55). 「Read, Grep, Glob 만」 정확 일치(예: WebFetch 를 더하는 것)는 막지 못한다. adversarial 의 정확 일치는 test_artifact_critique_truths.sh:15-16 도 재므로 이 파일에서는 다른 곳에도 있는 확인이다.
- 판정: 선다 — critic 짝과 한 표로 모으는 것은 된다. 행이 말한 「tools 확인은 걷는다」는 adversarial 한정으로만 안전하다(truths 가 받친다).
- 보안 갈래: 맞음 — 읽기 전용 allowlist(Law 2 리뷰어 경계)
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — :7-16 의 항목은 행대로다.
- 겹침: 일부만 — 행은 「tools/model/color 는 전수 스캔들이 이미 잰다」고 적었다. 그러나 artifact-critic 의 `tools: Read, Grep, Glob` 정확 일치(:11)를 재는 곳은 이 파일뿐이다. frontmatter_keys 는 금지 8종만 보고, truths 는 adversarial 만 본다. 웹 도구 같은 금지 밖 도구를 더하면 이것만 잡는다.
- 판정: 선다 — adversarial 과 한 표로 모으는 것은 된다. 다만 모은 표에서 정확 일치 줄을 걷으면 안 된다.
- 보안 갈래: 맞음 — 리뷰어 allowlist
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_codex_backward_compat.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — Check 1 kill switch 실행(:21), Check 2 SKILL 앵커 셋(:41 · :50 · :58), Check 3 원장 재실행(:108-164)을 잰다. 원장 등재 0건도 확인했다(grep 결과 0).
- 겹침: 일부만 — test_codex_dispatch_invariant.sh:27 · :37-39 는 2a · 2b 만 겹친다(2b 는 창으로 더 엄격하다). 2c `If codex is unavailable, continue without it` 는 이 파일뿐이다. test_range_wiring.sh:125 · :156 은 같은 앵커를 창 시작으로 쓸 뿐 같은 확인이 아니다. Check 1 은 test_detect_codex.sh · test_codex_copies_agree.sh 가 잰다.
- 판정: 선다 — 행 계획대로 모으면 된다. 다만 2c 를 dispatch_invariant 로 함께 옮겨야 한다.
- 보안 갈래: 맞음 — kill switch(다른 곳에도 있음)
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_codex_dispatch_invariant.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 다섯 케이스(:26-74)는 행대로다.
- 겹침: 맞음 — 1 · 2 는 backward_compat Check 2 와 겹친다. 3(run_codex_reviewer.sh) · 4(security-reviewer dispatch 12줄 안 project_dir) · 5(옛 codex_manifest 부재)는 이 파일뿐이다. 모으는 쪽이 이 파일이므로 잃는 것은 없다.
- 판정: 선다
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_codex_reviewer_frontmatter.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — agent 파일 부재(:9), 러너 실재 + 실행 비트(:10), SKILL 의 `DEVBREW_QUALITY_GATES_DISABLE_CODEX\|codex_available` (:17)를 잰다. OR 라서 kill switch 이름 없이도 통과한다(약하다).
- 겹침: 일부만 — test_codex_runner_no_effort_pin.sh 는 러너 파일 존재(`-f`)와 invocation 의 `-C` · `--json` · `-s read-only` 를 잰다(:127-160). agent 파일 부재와 실행 비트(`-x`)는 재지 않는다. SKILL 은 러너를 직접 실행하는 꼴로 부른다(SKILL.md:479). 행이 말한 「에이전트 파일 부재 · 스크립트 실재는 no_effort_pin 이 이미 본다」는 절반만 맞다.
- 판정: 선다 — 모으는 것은 되지만, kill switch 줄만 옮기면 실행 비트 · agent 부재 확인을 잃는다. 이 둘도 함께 옮겨야 한다.
- 보안 갈래: 맞음 — kill switch 발견성
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_discover_spec_keys.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 키 넷 정확 일치 · spec_path 부재 · spec-trailer · specs 목록을 잰다(:21-29).
- 겹침: 일부만 — test_discover_spec.sh 는 intent_source=spec-trailer 와 specs 목록을 여러 케이스로 잰다(:47-50 · :96-104). 출력 키 집합 정확 일치와 spec_path 부재는 재지 않는다.
- 판정: 선다 — test_discover_spec.sh 의 기존 케이스 출력에 키 집합 단언 두 줄을 더하면 임시 레포 준비가 하나 준다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_failure_injection.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — mock 다섯을 파서에 넣고 사유를 잰다(:43-56). 덧붙여 추적되는 mock 파일에 `chmod +x` 를 한다(:41). 부작용인데 행에 없다.
- 겹침: 맞음 — test_findings_parser.sh 가 깨진 JSON(:54) · agent_message 없음(:61) · stderr 인증(:68) · 펜스 없는 JSON 성공(Fixture 2, :46-50)을 인라인으로 잰다. 빈 stdout · stderr 없음 → missing_result(exit-1 mock)는 파서 테스트에 없다.
- 판정: 선다 — 옮길 것은 exit-1 한 모양뿐이다. 펜스 없는 JSON 은 Fixture 2 가 이미 잰다. 행은 둘을 옮기자고 적었다.
- 보안 갈래: 맞음 — 아니오
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_gate_era_prose_absent.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — qg *.md · plugin.json(하한 15, tests · CHANGELOG 제외)에서 옛 게이트 낱말을, 새 문구 셋을, README 동의 게이트 주장 부재 + kill switch 문장을 잰다(:22-56).
- 겹침: 일부만 — test_one_pipeline_surface.sh 의 코퍼스는 SKILL 과 differential-test.md 두 파일뿐이다(:9-16 · :47-57). agents · README · 다른 skill 은 이 파일만 본다. 행도 코퍼스를 넓혀야 한다고 적었다. README 동의 게이트 주장 부재(:53)는 「막지 않는 것을 막는다고 믿게 하는 선언 금지」를 지키는 줄이다. 이것을 재는 곳은 여기뿐이다(readme_scope_reconcile 은 fan-out 게이트 주장을 잰다).
- 판정: 선다 — 모으는 것은 된다. 다만 행이 덧붙인 「남는 동의 게이트 주장 없음 핀은 동작을 정하지 않는다」를 따라 그 줄을 버리면 이 테스트만 지키는 확인을 잃는다.
- 보안 갈래: 맞음 — 아니오(README kill switch 문장은 shared/tests/test_switch_tables.sh 의 README 표 대조도 덮는다)
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_intent_return.py
- 원래 판정: 합침
- 지키는 것: 맞음 — 행의 문장대로다. 추가로, record 에 스위치가 켜져 있으면 답 파일 · 커밋 · docs 폴더를 만들지 않는 확인(:757-818)은 다른 곳에 없다. test_intent_critic.py 에서는 :3090 의 문서 행 하나뿐이다.
- 겹침: 맞음 — test_intent_critic.py:1107-1129 test_paths · test_tree_failed_writes_return_block 은 :77-90 의 부분집합이다. :1096-1105 test_kill_switch_first 는 거의 부분집합이지만 result.md 부재 · questions 빈 목록을 더 본다. :2011-2050 render 두 케이스, :2214-2380 record 두 클래스도 행이 짝지은 대로 같은 갈래다. CLI 호출을 세어 보면 약 109번(ReturnHead 약 33 · QuestionRows 17 · AnswerInput 20케이스 × 약 3 · ReturnDoc 1)이다. AnswerInput 은 케이스마다 _git_repo 를 새로 만든다(:512-518). 행의 추정은 자릿수가 맞다.
- 판정: 선다 — 남기는 쪽이 이 파일이고 덜어 내는 쪽이 test_intent_critic.py 라서 스위치 · 접기 확인을 잃지 않는다. 다만 test_kill_switch_first 의 result.md 부재 단언은 이쪽으로 옮겨야 한다.
- 보안 갈래: 맞음 — kill switch 두 개가 쓰지 않음 · 제어 · 양방향 글자 주입 접기
- 권하는 판정: 합침

#### 되풀이되는 어긋남 — a1

- **겹침 상대를 이름만 대고 그 확인 내용은 견주지 않았다.** 상대가 같은 파일의 다른 면을 잰다. 예: state_diagram → plain_qg_templates(선택지 라벨이지 도식 아님), skill_codex_skip_prose → codex_result_banner(배너이지 사유 표 아님), compression_adopters → distortion_devices(request-framing 만), readme_scope_reconcile → review_scope_composition(SKILL 쪽), codex_reviewer_frontmatter → no_effort_pin(실행 비트 · agent 부재 없음), artifact_critic → 전수 스캔(정확 allowlist 없음).
- **모델이 읽는 글을 「글자만 지킴 — 동작을 정하지 않는다」로 묶었다.** 이 레포에서 SKILL · reference · 감사 질문 · 깔아 주는 템플릿 문면은 곧 동작이다. 예: axis3 감사 질문, skill_codex_skip_prose 의 사유 표, branch_strategy 템플릿, compression_adopters 의 finishing.md 포인터. 「지움」 다섯이 서지 않은 것은 모두 이 두 꼴 가운데 하나에서 나왔다.
- **합침 계획이 남는 확인 일부를 빠뜨렸다.** 예: backward_compat 2c, codex_reviewer_frontmatter 의 실행 비트 · agent 부재, gate_era 의 동의 게이트 주장 부재, failure_injection 은 반대로 이미 덮인 것까지 옮기자고 했다.

#### 확인하지 못한 것 — a1

- 없음. test_intent_critic.py(3244줄)는 행이 짝지은 클래스와 메서드만 읽었다. 그 밖의 부분이 test_intent_return.py 의 다른 케이스와 겹치는지는 보지 않았다.

## 표본 a2 — 합침 후보 2

### plugins/quality-gates/tests/test_isolation.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — T1·T2·T4c·T6 이 setup-qg.sh 를 실제로 돌려 확인한다(test_isolation.sh:48-67, 123-157). 단 T3·T5 는 테스트가 직접 `rm -rf` 한 뒤 남은 폴더를 보는 것이라 setup-qg 동작을 재지 않는다(:95, :142) — 행이 적은 「지우지도 않고」는 T4c(setup B 가 A 를 안 지움) 하나가 진다
- 겹침: 일부만 — T6 은 test_entry_safety_e1_e6.sh:56-64(E1 양의 짝)와 글자째 같고, T4 의 「형제 세션 폴더가 그대로」는 같은 파일 :53-54·:65-66 이 잰다. worktree↔원 레포 쪽은 test_worktree.sh:42-72(T1b: 원 레포에 상태 없음)가 일부만 덮는다 — 같은 SID 로 원 레포에서도 setup 이 성공하는지(T1b·T2b)와 inode 다름(T1c)은 이 파일에만 있다
- 판정: 선다 — 다만 받는 곳은 test_setup_qg.sh 보다 같은 make_repo_with_worktree 헬퍼를 가진 test_worktree.sh(:19-40)가 맞다. T6 은 지워도 되고 T3·T5 는 재는 것이 없다
- 보안 갈래: 맞음 — 상태 폴더 위치 성질이라 경로 탈출·권한 확인이 없다
- 권하는 판정: 합침 — (받는 곳은 test_worktree.sh · test_entry_safety E1)

### plugins/quality-gates/tests/test_precheck_retired.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 스크립트 부재 · SKILL 호출 부재 · 유령 결과 코드 다섯 · branch.md 참조 0 · setup-qg.sh 의 「fails pattern guard」 문구 존재(test_precheck_retired.sh:11-37)
- 겹침: 어긋남 — test_publish_surface_removed.sh:20-46 은 다른 은퇴 표면(qg-publish 계열)만 스윕한다. pre-pipeline-check · cleared_stale 등 · quality-gates 안 branch.md 를 재는 테스트는 레포에 이 파일뿐이다(`git grep` 결과 spec-distill 쪽 branch.md 는 다른 뜻). 행 스스로도 「대상이 다르다」고 적었다
- 판정: 서지 않는다 — 합침은 「같은 것을 지킨다」인데 같은 모양의 스윕일 뿐 지키는 대상이 겹치지 않는다. 한 파일로 옮기는 것은 짜임 정리이고 0.1초라 이득도 없다
- 보안 갈래: 어긋남(경계 사례) — :28-30 이 setup-qg.sh 의 SID 패턴 가드(경로 탈출 막음, test_entry_safety_e1_e6.sh:46 의 `../keep`) 문구를 grep 한다. 다만 같은 가드는 E1 과 test_plain_synth_output.sh:163 이 동작으로 재므로 이 줄을 잃어도 경계는 남는다
- 권하는 판정: 둠 — 은퇴 이름의 유일한 락이고 0.1초다

### plugins/quality-gates/tests/test_render_terminal.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 길이가 다른 두 키(target·identity)의 값 열 오프셋이 같고(:9-18), Final verdict 절 창 안에서 table 을 부른다(:23-33)
- 겹침: 일부만 — test_publish_surface_removed.sh:51-52 는 한 행(`k\tv` → `k   v`)만 보므로 열 정렬을 재지 못한다. test_plain_qg_templates.sh:107 은 SKILL 어딘가의 `render-terminal.py" table --title "Quality Gates — 끝"` 만 보고 Final verdict 절 창은 보지 않는다
- 판정: 서지 않는다 — 행의 근거 「table 동작 확인은 같은 확인과 겹친다」가 틀렸다. 정렬 확인은 이 파일에만 있다
- 보안 갈래: 맞음 — 렌더 정렬이라 보안 확인 없음
- 권하는 판정: 둠 — 정렬 확인이 이 파일에만 있고 0.1초다

### plugins/quality-gates/tests/test_secret_scan_fp.py
- 원래 판정: 합침
- 지키는 것: 맞음 — `token: string` · `token: RequestHandler` · 함수/경로 통과, ghp_ 토큰 차단, value_shaped() 가 낮은 엔트로피 RHS 에 거짓(test_secret_scan_fp.py:46-67)
- 겹침: 맞음 — run·scan_ok·blocked 헬퍼가 test_secret_scan.py:15-32 와 같고, test_real_value_still_blocks 는 test_github_token_blocks(:35-39), test_function_and_path_pass 는 test_identifier_and_path_pass(:56-63)와 같은 성질을 잰다. 「키워드+콜론+낮은 엔트로피」 두 케이스와 value_shaped 단위 확인은 이 파일에만 있다
- 판정: 선다 — 같은 스크립트·같은 헬퍼라 한 파일로 모으면 되고, 옮길 때 이 파일에만 있는 세 확인을 가져가면 된다
- 보안 갈래: 맞음 — 비밀 값 검출기의 판정 경계(차단 케이스 포함)
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_skill_orchestration.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — `qg 반복 N: <ask-line>` 이 범위 모드 아닌 question 줄에 정확히 하나, 범위 모드 줄에 정확히 하나(:42-52), 선택지 이름 둘(:53-54)
- 겹침: 일부만 — harness/test_skill_orchestration_behavior.sh:383-386 은 그 question 줄의 «첫 번째» 위치만 잡아 순서를 보고 모드별 유일성은 재지 않는다. 선택지 이름 둘은 행이 적지 않은 test_plain_qg_templates.sh:78 · :93 이 이미 잰다
- 판정: 선다 — 유일성 두 단언을 harness 쪽 같은 줄 확인 옆으로 옮기고, 선택지 이름 grep 은 plain_qg_templates 가 덮으므로 덜어도 된다
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py
- 원래 판정: 합침
- 지키는 것: 맞음 — Ledger(items=closed) 가 미판정을 내지 않되 막고(:25-40), phase_synth 가 unadjudicated 1 · converged False 를 낸다(:42-83)
- 겹침: 맞음 — phase_synth 쪽은 test_synthesize_artifact_findings.sh:79-84(unadjudicated 1) · :96-108(converged false + unadjudicated 1)이 CLI 로 같은 것을 잰다. Ledger closed 방향은 shared/tests/test_adjudication_behavior.sh:121-124 가 같은 공용 모듈을 잰다(행은 이쪽을 적지 않았다)
- 판정: 선다 — 셋 모두 다른 테스트가 덮는다(지움 후보로도 선다)
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — model 키 부재 · 정확한 tools 줄 · 쓰기/실행/위임 부재 · 출력 키 · E10 상한 부재 · 슬롯 · AC22 옛 상한 부재 + 양의 짝 · 웹 근거 계약 객체(블록마다 url+decides)(:13-98)
- 겹침: 어긋남 — 행이 든 test_research_agents_frontmatter.sh 는 repo-researcher · saturation-judge · open-researcher 만 재고(:102-161) blind-spot-prober 를 보지 않으며, check_agent 는 `kind: orchestrator_framing` 슬롯을 금지해(:93) 이 agent(frontmatter 의 framing 슬롯)를 그대로 넣으면 RED 다. test_brief_agents.sh 도 doc-critic 계열 넷만 본다(:27). 실제로 겹치는 것은 행이 적지 않은 레포 전수 스윕 — test_agent_frontmatter_keys.sh(plugins/*/agents/*.md 금지 8종 · denylist, :12-40·:111)와 test_agent_model_unpinned_sweep.sh(:21-40, model 키)다
- 판정: 서지 않는다 — 같은 것을 지키는 상대로 적힌 파일이 이 agent 를 재지 않는다. 겹치는 것은 Law 2 도구 부재·model·denylist 줄뿐이고, 정확한 tools 줄(웹 도구 보유)·출력 스키마·AC22·계약 객체는 이 파일에만 있다
- 보안 갈래: 맞음 — agent tools allowlist(권한)
- 권하는 판정: 줄임 — 레포 전수 스윕이 덮는 도구 부재·model·denylist 줄만 덜고 나머지는 둔다

### plugins/spec-distill/tests/test_brief_codex_axes.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 옛 다섯 이름 부재 + 모양 find(:42-56), 배포 링크 둘이 정본을 가리킴(:60-69), SKILL 의 게이트 마커 · 러너 호출 · consumer 앵커(:73-81)
- 겹침: 일부만 — 러너 호출과 게이트 마커는 test_reviewing_brief_skill.sh:105 · :251 이, 링크→정본은 shared/tests/test_copy_of_contract.sh 의 symlink-∀(:396-471, 참조하는 플러그인마다 배포 링크 요구)가 잰다. consumer 가 docreview_route 라는 값과 옛 다섯 이름 부재는 이 파일에만 있다
- 판정: 선다 — 양의 짝 대부분은 다른 락이 덮고, 부재 확인은 옮길 몫으로 남기면 된다(행은 부재를 「글자만」이라 했지만 지우라고는 하지 않았다)
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_brief_no_length_cap.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 템플릿 §0-7 헤더 · 보존 문구 넷 · 줄 예산/LINE_TRIPWIRE/지표 부재 · gate JSON 에 지표 키 없음과 advisories 채널 유지 · metrics rc 64(:47-95)
- 겹침: 어긋남 — test_brief_no_statement_cap.sh 는 다른 상수(STATEMENT_MAX)·다른 파일(finishing.md)을 재고 같은 단언이 하나도 없다. 행의 「gate 실행 한 번을 공유」도 입력이 다르다(이쪽은 원본 valid 픽스처 :82, 저쪽은 200자로 파생한 픽스처 statement_cap :127-128)
- 판정: 서지 않는다 — 「걷어낸 상한」이라는 주제만 같고 지키는 것이 겹치지 않는다
- 보안 갈래: 맞음 — :87-91 의 advisories 채널은 web 킬 스위치 통보용이라 적혀 있으나 채널 키 존재만 볼 뿐 스위치 동작은 재지 않는다
- 권하는 판정: 둠 — 0.2초이고 겹침이 없다

### plugins/spec-distill/tests/test_brief_no_statement_cap.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 코퍼스 셋 양성 대조 · 상한 어휘 부재 · 템플릿 C1 주석 등호 · 200자 statement 가 rc 0(:22-140)
- 겹침: 어긋남 — 위 length_cap 과 같은 단언이 없다(같은 패턴, 다른 대상)
- 판정: 서지 않는다 — 겹침이 없고, 행이 「덜어도 된다」고 한 C1 주석 등호(:63-72)는 파일 주석(:49-58)이 밝힌 대로 다른 말로 재도입된 상한을 잡는 유일한 장치다. 덜면 그 축을 잃는다
- 보안 갈래: 맞음
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — model 부재 · tools 줄 · 쓰기/실행/위임/MCP 부재 · 웹 도구 유지 · 출력 키 · 슬롯 · AC22/R1 부재 + 양의 짝 · C10 confidence 규칙(:15-89)
- 겹침: 어긋남 — test_research_agents_frontmatter.sh 의 check_agent 루프는 coverage-mapper 를 재지 않는다(:102-161). 실제 겹침은 레포 전수 스윕 test_agent_frontmatter_keys.sh(금지 8종 · MCP · denylist)와 test_agent_model_unpinned_sweep.sh(model)다
- 판정: 서지 않는다 — 공용 루프에 넣는 것은 짜임 바꾸기(구조를 고침)이고 지금은 상대가 같은 것을 지키지 않는다
- 보안 갈래: 맞음 — tools allowlist
- 권하는 판정: 줄임 — 전수 스윕이 덮는 도구 부재 · MCP · model · denylist 줄만 덜어낸다

### plugins/spec-distill/tests/test_epic_handoff.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 넘김 줄 머리 · 지시 리터럴 · 순서 · 자리표 집합(양성 대조 포함) · team 줄이 치환 표를 적용한 글과 바이트 같음(:17-138)
- 겹침: 일부만 — test_end_gates.sh:79-87 은 에픽 줄에서 SHARED · USED 두 문장만 잰다(이 파일의 '## 있는 것 검토 절' · '사용자가 승인한 뒤에만' · '## 상류 · 하류 연계 절' · '레포 전용 값은 박지 말고' 넷이 그 부분 문자열). test_review_handoff_order.sh 는 epic-handoff.md 를 읽지 않는다(:265 는 conducting.md 의 포인터 한 줄). test_entry_guidance.sh:39-42 는 머리말 다섯 줄만 본다
- 판정: 서지 않는다 — 행은 「문구 핀을 모으고 자리표 집합·순서만 남긴다」고 했지만 나머지 리터럴 대부분과 team 줄 바이트 등호는 다른 어디에도 없다
- 보안 갈래: 맞음
- 권하는 판정: 둠 — 겹치는 리터럴 넷만 덜 수 있고, 시간을 줄이려면 python3 -I 약 11회(pos 6 · names_ok 2 · team_names 2 · team_expected 1)를 한 번으로 묶는 구조 고치기가 맞다

### plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — defer_target 이 Deferred to plan 을 가리킴(:22-29), 층 2 handoff_incomplete 줄이 Handoff Context 를 댐(:31-41)
- 겹침: 일부만 — 둘째 확인은 test_handoff_context_section_required.sh:53-61 이 같은 층 2 창에서 잰다. defer_target 확인은 레포 다른 테스트에 없다(`git grep defer_target` — shared 쪽은 brief 프로필 none 뿐)
- 판정: 선다 — 같은 프로필 한 줄을 넷이 같은 awk 로 자르므로 한 파일로 모으면 되고, defer_target 확인은 함께 옮긴다
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_handoff_context_section_required.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — handoff_incomplete 가 layer2 에 있고 layer1 에 없으며 층 2 본문이 Handoff Context 와 함께 정의(:29-61)
- 겹침: 일부만 — layer2 등재는 test_handoff_design_mode.sh:30-42 가, 본문 Handoff Context 는 empty_subsections:31-41 이 잰다. layer1 부재(:46-48)는 이 파일에만 있다
- 판정: 선다
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_handoff_conversation_reference.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 층 2 handoff_incomplete 줄에 「/compact」 와 「암묵 컨텍스트」(:21-33)
- 겹침: 일부만 — 같은 줄을 읽지만 「/compact」·「암묵 컨텍스트」 확인은 다른 세 파일에 없다(`git grep` 0건)
- 판정: 선다 — 행의 「문구 확인은 한 곳에서 한 번이면 된다」는 같은 문구를 두 번 잰다는 뜻으로 읽히지만 실은 이 파일만 잰다. 모을 때 이 단언을 옮겨야 한다
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_hooks.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — hooks.json 의 SessionStart 부재 · session-anchor.sh 부재 · hooks/ 부재 · spec-distill-gc.py 부재 · hook_common 의 옛 정리 함수 이름 부재 · _yaml_scalar 존재(:19-41)
- 겹침: 일부만 — test_review_hook_removed.py 는 base c7b4f580 의 hook_common 에서 빠진 이름(그 옛 정리 함수 이름 포함, base :58)을 레포 전체에서 금지하므로(:379-398) :38-39 를 덮는다. hooks/ · spec-distill-gc.py 부재와 _yaml_scalar 존재는 그쪽이 재지 않으며, 그쪽 docstring(:305-308)이 hooks/ 부재를 이 파일에 맡긴다고 적었다
- 판정: 선다 — 한 「부재」 파일로 모을 수 있고 이 파일 고유의 셋을 옮기면 된다
- 보안 갈래: 맞음
- 권하는 판정: 합침

### plugins/spec-distill/tests/test_kill_switches_v060.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 스위치 다섯 케이스 · 다른 플러그인 토큰 · TTL 두 케이스 · 양성 대조(:29-68)
- 겹침: 일부만 — test_ledger_sweep.py:243-255 SafetyTest 는 단일 스위치 넷만 잰다. 쉼표 목록 `spec-distill:SessionEnd,quality-gates:Stop`(case 5, :35)과 다른 플러그인 토큰이 끄지 않음(case 6, :45-49)은 ledger_sweep 에 대해 다른 곳에 없다(shared/tests/test_entry_preflight.sh:104·:197 의 쉼표 파싱은 진입 사전 검사 쪽이다)
- 판정: 서지 않는다 — 적힌 근거대로 「TTL 두 케이스만 옮기면」 끄는 스위치의 쉼표 목록·다른 플러그인 토큰 두 케이스를 잃는다
- 보안 갈래: 맞음 — 끄는 스위치가 파일 삭제를 실제로 멈추는지 동작으로 잰다
- 권하는 판정: 합침 — TTL 둘만이 아니라 case 5·6·7·8 넷을 SafetyTest 로 옮길 때만

### plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — plugins/* · shared/** 의 hooks.json PostToolUse matcher 를 allowlist(SAFE_TOOLS={Bash, EnterWorktree}, 맨 식별자만)로 판정, 정의역 하한 둘, 양성 대조 셋(:28-147)
- 겹침: 맞음 — plugins/project-init/tests/test_no_write_matcher_hooks.sh:9-32 는 project-init 하나만 denylist(WRITE_TOOLS 넷)로 보고 Bash 항목 생존을 본다 — 이 파일의 전수 allowlist 판정과 N_BASH 양성 대조(:125-127)에 모두 포함된다. 저쪽의 docs-lint.py 부재(:36-37)만 저쪽에 고유하다
- 판정: 선다 — 행은 「확인 전」이라 했으나 열어 보니 project-init 쪽이 이쪽에 포함된다. 저쪽을 이쪽으로 모으고 docs-lint.py 부재 한 줄만 옮기면 된다
- 보안 갈래: 어긋남(경계 사례) — 막는 것은 「쓰기 도구에 발화하는 훅이 없다」는 설계 규칙이다. fail-closed allowlist 모양일 뿐 경로 탈출 · 주입 · 비밀 · 권한 · 끄는 스위치 · 리뷰어 프로필 경계는 아니다
- 권하는 판정: 합침 — (받는 쪽은 이 파일, 지울 쪽은 project-init 파일에서 docs-lint 줄을 뺀 나머지)

### plugins/spec-distill/tests/test_review_handoff_order.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 다음 세션 줄 모양 · brief-handoff.md 두 절의 등호(열다섯 · 넷) · 순서 · 변이 대조 · 템플릿 §7 · spec-review description · 게이트 없는 종료의 복귀 문장 · 게이트 표 ①-④ · ③ 로드맵 분기 · 다음 세션 줄 · 정지 요건(:96-265)
- 겹침: 일부만 — test_end_gates.sh:66-87 은 공통 지시 네 문장(포함만, 이 파일은 등호 :147-148)과 SHARED · USED 두 문장을 잰다. 이 파일 약 120개 단언 중 6개 남짓이다. 게이트 표 · ③ 분기 · 정지 요건 · description · 복귀 문장은 다른 데 없다
- 판정: 서지 않는다 — 266줄 파일을 통째로 「합침」으로 적을 만큼 겹치지 않는다. 이중 핀은 문장 여섯뿐이다
- 보안 갈래: 맞음
- 권하는 판정: 줄임 — 두 파일이 함께 핀하는 문장 여섯을 한쪽에서만 재게 덜어낸다

### plugins/spec-distill/tests/test_reviewing_spec_design_only.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — design-doc 프로필 고정(주장 + 디렉터리 도출 사실) · 모드 슬롯 부재 · re-consensus · mode_b_violation · spec 표 행 · drafting-spec 스윕(루트 실재 확인 포함)(:21-93)
- 겹침: 일부만 — test_review_hook_removed.py:428-434 가 같은 SKILL 의 `\$mode\b` · `mode: (design|spec)` 를 잰다 — (2a)(:37-39)와 같다. re-consensus · mode_b_violation · spec 행 · drafting-spec 은 레포 다른 테스트에 없다(`git grep` 0건). test_reviewing_brief_skill.sh 5절은 다른 skill(reviewing-brief)이다
- 판정: 서지 않는다 — 행은 「프로필 도출 확인만 남기고」라 했는데, 그대로 하면 이 파일에만 있는 부재 락 넷을 잃는다
- 보안 갈래: 맞음
- 권하는 판정: 줄임 — (2a) 한 단언만 덜어낸다

### plugins/spec-distill/tests/test_reviewing_spec_residue.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — spec-review codex-gate 펜스를 env -i 로 실행해 A(skip 다섯) · A+ · A! · D · A2 · A3 · E · P1-5 · S 를 디스크 사후상태와 prepare-recritic 출력으로 판정(:192-563)
- 겹침: 일부만 — test_reviewing_brief_residue.sh 는 축이 같지만(:8-15) 돌리는 것은 reviewing-brief 펜스다. spec-review 펜스는 P×자리 한 번(:405, kill switch 로 끈 채 자리만 관측)만 돈다. 겹치는 것은 엔진 하류 판정(D 대조군 · A3 의 codex_predates_round)이고, spec 펜스의 중화 · 보존 · 공시 · errexit · S 는 이 파일에만 있다
- 판정: 서지 않는다 — 행의 처방(한 하니스에 SKILL 을 매개로 넘겨 두 펜스를 돈다)은 지키는 것을 보존하지만, 그것은 준비를 함께 쓰는 「구조를 고침」이다. 「합침」으로 적으면 brief 쪽이 이미 덮는다고 읽힐 수 있다
- 보안 갈래: 맞음 — 지난 라운드 codex finding 섭취 차단 · DISABLE_CODEX 스위치 · 권한 잠금 칸
- 권하는 판정: 구조를 고침 — 공용 하니스 lib 로 두 SKILL 을 매개 실행. 행의 시간 추정(sid 21개 × python 2회, 펜스 실행 24회)은 코드와 맞다

### shared/tests/test_docreview_gate_plain.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — 21개 상태 렌더의 괄호 밖 기호 부재 + 양성 짝, 골든 gate.txt, 절차서 문장 넷(:35-158)
- 겹침: 일부만 — test_docreview_gate_visibility.sh 의 gv_reach_* 는 GATE_ROWS 10행(:63-166, :220-229)만 짓는다. 이 파일의 나머지 11개(related_changed_unchanged · adopt_unavailable · log_check_skipped · revert_target_flagged · approval_ready · cap_open · cap_zero_open · stagnation · detector_partial_death · unverified · route_warnings, :90-140)는 저쪽에 없다
- 판정: 선다 — 10행은 한 번 지은 원장으로 두 성질을 함께 잴 수 있다. 다만 「준비가 절반으로 준다」는 과장이다 — 가장 비싼 cap_* · stagnation(next_round 두 번)과 detector · unverified 는 이 파일에만 있어 그대로 남는다
- 보안 갈래: 맞음
- 권하는 판정: 합침 — (10행에 한해)

### shared/tests/test_docreview_profile_schema.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — layer_rubric 셋째 키 · 중복 키 넷 · 빈 본문 · 비문자열 층 · 정규식 메타 처리 · must_catch 검증과 init 경로 거부(:46-260). 행이 빠뜨린 것 하나: 프로필 넷에서 도출한 category 전부에 사람말 사상이 있는지 ∀ 검사(:199-229)는 이 파일에만 있다(cases.sh:3766 은 사상 밖 공시만 잰다)
- 겹침: 맞음 — ③(:62-71)이 test_docreview_profiles.sh:20-28 과 글자째 같다(배포 프로필 통과 + 정확히 넷). 파일 안에서도 design-doc profile-check 가 ②(:54) · ③ 루프 · ⑤ 양성 짝(:127)으로 세 번 돈다 — 행이 적지 않은 되풀이
- 판정: 선다 — ③ 만 한쪽으로 모으고 변이 거절과 사상 검사는 둔다
- 보안 갈래: 맞음 — 리뷰어 프로필 로더가 심은 미끼 키를 진입에서 거절한다
- 권하는 판정: 합침

### shared/tests/test_runner_disposition.sh
- 원래 판정: 합침
- 지키는 것: 맞음 — extract_codex_invocations.py 로 도출한 codex 러너 .sh 마다 처분 앵커의 세 칸 · consumer 경로 실재 · 같은 플러그인, 제외 목록 생존, 조용한 버림 0(:56-216)
- 겹침: 어긋남 — test_dispatch_disposition.sh 의 코퍼스는 skills · commands · hooks 의 .md/.js, scripts/*.js, agents/*.md 다(:33-40, :80-88). codex 러너 .sh 는 그 코퍼스 밖이라 같은 규칙을 다른 파일 집합에 건다
- 판정: 서지 않는다 — 규칙은 같아도 지키는 파일이 겹치지 않는다. 합치면 도출기를 공유하는 구조 고치기가 되고 「같은 것을 지킨다」는 성립하지 않는다
- 보안 갈래: 맞음
- 권하는 판정: 둠 — 0.4초이고 .sh 러너를 재는 유일한 락이다

#### 되풀이되는 어긋남 — a2

- **「같은 모양」을 「같은 것을 지킴」으로 적은 합침.** 지키는 대상은 다르고 확인의 꼴만 같은 짝을 합침으로 적었다. 이건 짜임 정리(구조를 고침)거나 둠이다. 예: test_precheck_retired(다른 은퇴 표면) · test_brief_no_length_cap ↔ test_brief_no_statement_cap(다른 상수) · test_blind_spot_prober / test_coverage_mapper → test_research_agents_frontmatter(그 루프는 이 두 agent 를 재지 않는다) · test_runner_disposition(다른 코퍼스) · test_reviewing_spec_residue(다른 펜스).
- **처방이 고유 확인을 조용히 버린다.** 합침 근거에 「X 만 옮기고」·「Y 만 남기고」라고 적었는데, 적지 않은 나머지가 그 파일에만 있다. 예: test_kill_switches_v060(TTL 만 → 쉼표 목록 · 다른 플러그인 토큰 두 스위치 케이스를 잃음, 보안 갈래) · test_reviewing_spec_design_only(프로필 도출만 → 부재 락 넷을 잃음) · test_epic_handoff(자리표·순서만 → 유일한 리터럴과 team 줄 등호를 잃음) · test_brief_no_statement_cap(주석 등호를 덜어도 된다 → 재표현 상한을 잡는 유일한 장치). 가장 위험한 꼴이다.
- **실제 겹침은 레포 전수 스윕에 있는데 이름 비슷한 형제를 적었다.** agent frontmatter 의 Law 2 · model 확인은 plugins/quality-gates/tests/test_agent_frontmatter_keys.sh · test_agent_model_unpinned_sweep.sh 가 전수로 덮는다. 행들은 이 둘 대신 test_research_agents_frontmatter · test_brief_agents 를 적었다. 비슷한 예: 선택지 이름은 test_plain_qg_templates.sh 가 덮고(test_skill_orchestration 행이 빠뜨림), Ledger closed 방향은 shared test_adjudication_behavior.sh 가 덮는다.

#### 확인하지 못한 것 — a2

- test_reviewing_brief_residue.sh(889줄)는 머리말 · 블록 추출 · P/S 절만 읽고 H · K · Q 절 본문은 끝까지 읽지 않았다. spec_residue 의 겹침 판정은 머리말의 축 목록과 spec 펜스를 쓰는 자리(:85-86, :405)로만 냈다.
- test_review_hook_removed.py 는 도출 함수 본문(:81-300)을 읽지 않았다. S2 에 hook_common 의 옛 정리 함수 이름(test_hooks.sh 가 부재를 재는 것)이 드는지는 base 커밋의 hook_common 에 그 이름이 있다는 사실(git show)과 docstring 의 S2 정의로 추론했다.
- test_docreview_gate_visibility.sh 와 test_end_gates.sh 는 겹침에 닿는 부분만 읽었다.

## 표본 b1 — 가장 비싼 여덟

### shared/tests/test_docreview_mutations.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 셀 119개(`^mut`/`^mut_expect` 줄을 셈)가 엔진 규칙을 하향으로 뒤집고 classify_result(:127–136)로 caught를 기대한다. 양성 대조 7개(:92–101) · carry_fold 탐침(:104–106) · 카나리아(:310) · churn 가드(:191–195)로 계측기 자체도 잰다(행의 확인 수 칸에 있음)
- 겹침: 맞음 — 셀이 겨누는 서로 다른 케이스 89개를 test_docreview_*.sh(mutations 제외)에서 bash grep으로 찾았다. 87개는 행동 락에 있고 `case_AC21_unconsumed_counted` · `case_reraise_successor_immune_to_recritic` 두 개는 이 파일에서만 불린다(행과 같다)
- 시간 쓰는 곳: 맞음 — run_case 호출은 변이 119 + 깨끗한 사본 89(캐시 :85–91, 처음 7개는 89 안에 든다) + 탐침 1 = 209회다. 서브셸마다 cases.sh(4773줄) · cases_advice.sh(1097줄)를 source하고, cases.sh:7이 `DOCREVIEW_PROF_SD`가 없으면 nofield_profiles.sh(bash + python 해시)를 다시 띄운다. 이 테스트는 그 변수를 export하지 않는다(shared/tests 안에서 grep, 다른 파일 한 곳만 넘긴다). 셀마다 _churn이 diff를 2×7번 부르고 mkclone이 .py 7개를 복사한다
- 고치면 잃는 것: 있음 — ① 깨끗한 사본 89회를 행동 락 결과로 갈음하면 두 가지를 잃는다. 하나는 `$CLEAN`(복사본 + adjudication 링크)이 계측기로서 GREEN인지 보는 양성 대조다. 행동 락은 plugins/spec-distill/scripts 링크 경로로 돈다. 다른 하나는 행렬에서만 불리는 두 케이스의 양성 대조다. ② 셀을 병렬로 돌리면 clean_result 캐시(`tee` → `.clean-results/<case>`)에 경합이 생긴다. 같은 케이스를 여러 셀이 겨누기 때문이다(예: case_choices_offered_equal_accepted 3셀, case_AC22_expired_escape_hatch 2셀). 반쯤 쓴 캐시를 읽으면 거짓 instrument_broken이 나므로 캐시를 먼저 채운 뒤에 병렬로 돌려야 한다. ③ 깨끗한 실행을 한 서브셸에 묶으려면 케이스마다 `_ASSERT_FAIL/_PASS` 계수와 traceback 판정 출력을 나눠야 한다. `DOCREVIEW_PROF_SD` 한 번 export는 잃는 것이 없다
- 판정: 선다 — 되풀이 209회와 서브셸 준비는 실제로 있다. 다만 행이 맨 앞에 둔 고치기(행동 락 결과로 갈음)는 양성 대조를 잃는다
- 보안 갈래: 맞음 — 보호 · 불변 절 승격(②, ㉔ :433), 원장 문서 · 프로필 정체 거부((54)–(56) :778–790), 원자 쓰기((80) :865)를 흔드는 셀이 실제로 있다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_conductor_branch.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — force · lease 없는 지우기를 문에서 막음(:554–566, :1264–1292), 로드맵 폴더 밖과 `..` 거절(:284–289, :455–461), 원격 주소 · 경로 가리기(:252–257, :901–907). 행이 빠뜨린 것은 셋이다. 설정 오류 때 쓰는 명령이 알리고 0을 내되 표지 검사가 먼저인 것(:1396–1452), 지우기 전에 센 끝과 `--confirmed` 끝을 대조하는 것(:1223–1242, :1186–1208), 제어 · 방향 글자를 글자로 보이는 것(:230–238)
- 겹침: 일부만 — 파일 안 GIT_ALLOWED 루프 중복(:225–226 ↔ :574–575)과 pre-receive 준비 중복(:757 ↔ :902, 단언은 서로 다르다)은 맞다. 「얕은 클론이 정말 얕은지 세 곳」 은 어긋난다. is-shallow 단언은 :42와 :492 두 곳이고, Publish(:798)는 fetch refspec을 잰다
- 시간 쓰는 곳: 맞음 — `def test_` 116개 가운데 unittest.TestCase 직속(Showing 3 · WriteBoundary 3 · LetterNames 1 · PublishBoundary 3 · DeleteBoundary 2 · PathShape 2 · DoneStages 1)을 빼면 StateRepo 케이스는 101개다. StateRepo.setUp(fixture :49–60)은 git을 약 11번 띄운다(init · clone · config 3 · rev-parse · checkout · add · commit · push · set-head). `cli(` 45곳, `self.clone(` 15곳이다. Delete의 tip 꼴 케이스(:1225–1233)는 10 + 3 + 1 = 14번 CLI를 띄운다
- 고치면 잃는 것: 없음 — setUpClass + copytree는 케이스가 매번 자기 사본을 받으므로 서로의 상태에 기대지 않는다(조건: clone의 `file://` 원격 주소를 사본 경로로 고친다. 상태 루트는 git-common-dir에서 도출되어 사본을 따라간다, state_path.py:73–110). 저장소가 필요 없는 4개를 떼어 내도 잃는 것이 없다. Delete 루프를 main() 호출로 바꿔도 CommandLineIdentity(:1506–1512)와 남긴 CLI 한 번이 프로세스 경계를 잰다
- 판정: 선다 — 지키는 것은 실제 git 동작이고, 초는 케이스마다 다시 짓는 준비에서 나온다
- 보안 갈래: 맞음 — 경로 탈출 거절 · force push 문 · 원격 주소(토큰 든 URL) 가리기가 실제 단언으로 있다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_human_gate.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 시작 묶음 멈춤(:27–106), 환경 변수로 꺼지지 않음(:129), 연속 실패 멈춤(:163–223), 머지된 계획 멈춤(:225–240). 행이 빠뜨린 것은 human-check 명령의 rc 0/1/2 · 쓰지 않음(AC23) · 판정별 줄(묶음 I · L · M · O · P, :367–474)이다
- 겹침: 맞음 — test_human_judge.py가 관문 표 · missing · 건너뜀 · retry_open을 단위로 잰다(:431–459, :556–567). test_human_gate_e2e.sh의 13 · 14 · 15–16은 이 파일의 9 · 11 · 15–16과 같은 시작 묶음 단언이다. 다만 행에 없는 겹침이 하나 있다. 시도 세기(22–27)는 test_team_results.py:322–395 FailedStreak이 잰다
- 시간 쓰는 곳: 맞음 — new_repo 15번(a · b · c · d · f · g · h · j · k · i · l · m · n · o · p). check 줄 52개 + 4단계 루프 둘(+6) + finish_attempt 6번 = start_bundle 약 64번. rcheck 20번, approved 19 + human 2 = 21번(번마다 ask-head · session_fixture · record python 셋), push_br 55 + push_main 13 = 68번이다. new_repo 하나는 python 5개다(repo_defaults · original · create · 인라인 · claim)
- 고치면 잃는 것: 있음 — 「13 · 14 · 22–27을 human_lines 단위로」 는 대상이 틀렸다. 시도 세기는 job_results.failed_streak이고 그 단위 테스트(test_team_results.py:359)는 check_result를 mock한다. 그래서 26(손으로 적은 받음 줄이 실제 결과 대조에서 거절됨)과 27(record로 적은 받음 줄이 이어짐을 끊음)의 실제 대조 경로를 잃는다. 묶음 안 케이스는 앞 단계 상태에 기댄다(A: 1→16, D: 20→30). 그래서 나눌 수 있는 단위는 묶음이다. 반면 new_repo 결과를 한 번 지어 묶음마다 cp -R하는 것은 잃는 것이 없다(조건: `$T/origin.git` 원격 주소를 고친다)
- 판정: 선다 — 준비 복사는 맞다. 「단위로 내리기」 는 대상(human_lines)이 틀렸고 22–27 가운데 26 · 27은 내리면 잃는다
- 보안 갈래: 맞음 — 지어낸 승인 줄 거절(23b :178–184)과 환경 변수 우회 불가(:129)가 실제 확인이다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_conductor_cross.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — show가 fetch · push · gh를 부르지 않음(:271–297), 남이 심은 STATUS 줄 · 제어 글자가 화면에 실리지 않음(:222–254, :333–341), 겹침 계산(:50–146)
- 겹침: 맞음 — test_conductor_state_branch_e2e.sh:59(예약 겹침) · :79 · :101(온 글 1) · :102(다른 기계의 기다리는 질문)가 같은 show 줄을 명령줄로 다시 본다
- 시간 쓰는 곳: 맞음 — 케이스 42개(Computed 13 · Quiet 1 · Show 28), 141.5초 ÷ 42 ≈ 3.4초다. CrossRepo.setUp(:39–43)은 StateRepo 약 11 + put 3 + epic_branch 2×6 ≈ 26번 git을 띄우고, Show.setUp(:171–175)은 그 위에 ensure 두 번(커밋 + push)을 얹는다. text()/view()는 케이스마다 2–4번이다(예: :442–451 네 번)
- 고치면 잃는 것: 없음 — 케이스는 사본마다 독립이다(T0 고정, mock은 케이스 안). 조건은 clone 원격 주소를 다시 맞추는 것이다(행에 없음). 읽기만 하는 Computed 둘은 같은 사본을 함께 써도 상태를 바꾸지 않는다
- 판정: 선다
- 보안 갈래: 맞음 — 남의 글에서 온 제어 글자 주입을 거르는 단언이 렌더 층에 있다(:237–238, :340–341)
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_human_gate_e2e.sh
- 원래 판정: 줄임
- 지키는 것: 맞음 — 끝에서 끝 흐름(:20–107), 지어낸 줄 × 세 표면(trio :140–156), 깨진 human_gate는 3이고 관문을 열지 않음(:286–294), 옛 형식(:301–361)
- 겹침: 일부만 — test_human_judge.py가 S1–S10 · P1–P3의 판정을 모두 단위로 잰다. 대부분은 Match.test_forged_lines_do_not_pass(:183–210)이고, 같은 호출의 다른 질문 · 같은 근거 두 번 · 판만 새것은 :213 · :229 · :221이다. 그러나 human_gate.sh 9 · 11과 겹친다는 13 · 14는 이 파일에서 더 잰다. 상태 계산이 설계 중으로 돌아감, 되돌린 뒤 「받은 뒤 바뀜」 없음(K13 :85–90), human-check 낡음 · 0(:83–84, :95–96)이 그것이고, human_gate.sh:66–74는 시작 묶음만 본다
- 시간 쓰는 곳: 맞음(갈래 수만 어긋남) — trio는 17번이 아니라 16번이다(S1–S8 8 + S9 루프 2 + S10 루프 3 + P1–P3 3). 번마다 start_bundle · job_results · human-check python 셋, hd · rend · answer python 셋, plant · unplant의 커밋과 push + fetch 두 쌍이 든다
- 고치면 잃는 것: 있음 — trio를 판정 종류(근거 없음 · 어긋남 · 확인 못 함)마다 한 갈래로 줄이는 것은 잃는 것이 거의 없다. 세 표면이 같은 H.match를 거치고, 어긋남 한 갈래가 남으면 표면이 꼴만 보는 얕은 대조로 바뀐 것도 잡힌다. 그러나 「13–16을 덜기」 는 13 · 14의 상태 계산과 human-check 단언을 잃는다. 「push 대신 reset」 은 올리지 않은 끝에서 read_tip이 「아직 안 올라옴」 갈래를 타므로 실제 흐름과 다른 길을 잰다
- 판정: 선다 — trio 줄이기는 선다. 13–16 덜기는 겹침이 일부뿐이라 서지 않는다
- 보안 갈래: 맞음 — 지어낸 승인 줄을 세 표면이 모두 막고 깨진 설정이 관문을 열지 않는 확인이 실제로 있다
- 권하는 판정: 줄임 — trio만 줄이고 13–16은 둔다

### shared/tests/test_docreview_state.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — :15–173에서 케이스 138개를 부른다(`^case_` 138줄). 전이 · 상한 · 불변 절 · 위조 줄 · 확인값 · 시대 표지 · 원장 정체 · 설정이 행과 맞는다
- 겹침: 맞음 — mutations 행렬이 같은 케이스를 깨끗한 사본에서 다시 돈다(위 블록에서 확인). test_docreview_gate_visibility.sh는 GATE_ROWS를 보고, test_state_dir_writes.sh:25는 같은 원장 init을 링크 거절 쪽에서 본다
- 시간 쓰는 곳: 맞음(세부 수는 어긋남) — next_round 한 번은 python 5회가 아니라 7회다(cases.sh:219–227: st_yaml · snap · put_doc→ledger_doc · begin-round · exempt-anchors · diff · observe-diff). 138케이스에서 도우미를 거쳐 정적으로 센 next_round는 약 118회로, 행의 약 160회와 자릿수가 같다(루프는 한 번으로 셌다). 케이스 본문에 글자로 보이는 python 호출(`py ` 682 · jget 149 · st_yaml 65 · python3 69)은 약 960곳이다. 엔진 docreview_state.py는 2998줄이다
- 고치면 잃는 것: 있음 — 「중간 원장을 한 번 지어 복제」 하면 케이스끼리 오염된다. 원장은 문서 절대경로를 담는다(st["doc"] = `<state-dir>/src/<이름>`, cases.sh:26–31, init은 상대경로를 거절한다). 디렉토리를 복사해도 put_doc(cases.sh:48–53)이 원본 템플릿의 문서를 덮어쓴다. 원장 정체 검사도 걸린다. 순수 전이를 프로세스 안 python 단위로 옮기면 CLI 경계(rc · JSON · 줄인 플래그 거부 case_AC14_no_abbrev_flags)를 잃는다. st_yaml 단언을 python 한 번으로 묶거나 파일을 나누는 것은 잃는 것이 없다
- 판정: 선다 — 비용이 큰 곳은 맞다. 다만 첫 고치기(복제)는 문서 경로를 다시 매어야만 안전하다
- 보안 갈래: 맞음 — 위조 줄(case_AC15_forged_lines_gain_no_provenance :146), 불변 절 덧붙이기만(:138–143), 확인값 불일치 멈춤(:151–157)이 실제 확인이다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_team_status.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — read_tip(:35–68), 단계 표(:125–258), 관문(:733–800, 설정 오류면 켜진 채 :799–800), 받음 낡음 r1–r10(:825–867)
- 겹침: 맞음 — test_team_results.py가 BOM · 펜스 · Task 줄 꼴을 프로세스 안에서 잰다(:24, :51–72). 파일 안에서 받은 뒤 바뀜 갈래가 본 레포(:205–258)와 받음 낡음 레포(:825–867)에서 비슷하게 되풀이된다
- 시간 쓰는 곳: 맞음 — 레포 세우기는 3번이다(team_repo :11 · 관문 :736 · new_repo :804). step 약 98번(`step "` 196 = step · fail_step 짝) + restat 약 26 + status 직접 4 ≈ 125번 roadmap_status를 돌린다. st · why · notes · blk · jobf · js 류 python 호출 256곳, back 57번(reset + force push), approved 6 + human 1 = 7번(행은 8)
- 고치면 잃는 것: 없음 — 관문 절과 받음 낡음 절은 새 레포를 세우므로 떼어 내도 상태를 잃지 않는다(조건: $DESIGN · 도우미를 함께 옮긴다). 본 레포의 단계 절과 알림 절은 RECEIVED_AT · MAIN_AT을 이어받으므로 나누려면 준비를 다시 지어야 한다(행이 이미 적었다). 걸음마다 보고를 python 한 번으로 읽는 것도 잃는 것이 없다
- 판정: 선다
- 보안 갈래: 맞음 — 관문이 켜진 동안 손으로 적은 승인 줄이 지나지 못하고(:131–133) 설정 오류면 관문이 켜진 채(:799–800)인 fail-closed 확인이다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_conductor_status.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 실리면 안 되는 것(:106–123), 한 시간 문턱은 now 인자로 잰다(:142–153, 실제로 기다리지 않는다), 다른 세션 · 기계 알림(:176–217), 표지 주인만 씀(:162–163, :309–311)
- 겹침: 맞음 — test_conductor_state_branch_e2e.sh:56 · :93 · :99가 sync와 waiting add를 명령줄로 다시 부른다. test_conductor_cross.py Show가 waiting_add · sync를 준비로 쓴다
- 시간 쓰는 곳: 맞음 — 케이스 37개, 126.3초 ÷ 37 ≈ 3.4초다. StatusRepo.setUp(:40–44)은 StateRepo 약 11 git + claim + ensure(커밋 + push)다. sync를 여러 번 부르는 케이스는 :142–153(5번)과 :176–190(4번)이다. Scrub 3케이스(:246–265)는 CS.scrub만 부르는데 그 준비를 다 탄다
- 고치면 잃는 것: 있음(작음) — Scrub을 레포 없는 TestCase로 옮겨도 잃는 것은 없다. 다만 :248이 `self.w.resolve()` 갈래를 보므로 resolve가 달라지는 임시 경로를 써야 한다(macOS mkdtemp는 그렇다). 그러나 Shape.test_read_back을 push 없이 build→render로 바꾸면 브랜치에 실제로 쓴 글을 CB.read로 되읽어 바이트로 견주는 왕복을 잃는다
- 판정: 선다
- 보안 갈래: 맞음 — 원격으로 가는 STATUS에 경로 · 홈 · 기계 이름 · 세션 id · 질문 본문이 실리지 않는 단언(:118–123)은 사적 정보 유출 경계다
- 권하는 판정: 구조를 고침

#### 되풀이되는 어긋남 — b1

- 「준비를 한 번 지어 복사」 를 적으면서 복사가 깨지는 조건을 적지 않았다. 상태가 자기 절대경로를 담으면 단순 복사가 깨진다. 예: test_docreview_state.sh(원장의 st["doc"]가 사본이 아니라 템플릿 문서를 가리켜 put_doc이 덮어씀), test_conductor_cross.py · test_conductor_status.py · test_human_gate.sh(clone 원격 주소). test_conductor_branch.py 행만 이 조건을 적었다.
- 「더 싼 단위로 내리기」 의 대상을 확인하지 않았다. 예: test_human_gate.sh 22–27은 human_lines가 아니라 job_results.failed_streak이 맡고, 그 단위는 check_result를 mock한다. test_docreview_mutations.sh는 깨끗한 실행을 행동 락으로 갈음하면 사본 계측기의 양성 대조를 잃는다. test_human_gate_e2e.sh 13–16은 human_gate.sh에 없는 상태 · human-check 단언을 가진다.
- 작은 수가 어긋났다(자릿수는 맞음). e2e trio 17 → 16, next_round python 5 → 7, team_status approved 8 → 7.

#### 확인하지 못한 것 — b1

- shared/tests/fixtures/docreview/cases.sh(4773줄) · cases_advice.sh(1097줄)는 끝까지 읽지 않았다. 도우미 정의(cases.sh:1–60, :205–240)와 정적 계수 스크립트로만 셌다. 두 docreview 블록의 python 호출 수는 루프를 한 번으로 센 하한이다.
- 행의 「고친 횟수」 는 test_docreview_mutations.sh(64)와 test_docreview_state.sh(45)만 git log로 다시 셌다. 나머지 여섯 개는 다시 세지 않았다.
- test_docreview_gate_visibility.sh는 GATE_ROWS를 다루는 줄 하나만 확인했다.

## 표본 b2 — 비싼 여덟(둘째)

### plugins/spec-distill/tests/test_conductor_mail.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 틀 가두기(:312–342), about 의 절대경로·기계 이름·제어 글자 거절(:83–101, :199–208), from·to·파일 이름 꼴 대조(:273–295), 표지 rc 5·끄기(:149–161, :218–225), 받음 줄·세는 수(:257–268, :371–389)를 실제로 본다. 행에 없는 것은 SourceLocks 셋(:512–538, 소스의 보이지 않는 글자·`\d` 금지·framed 가 splitlines+visible 을 부르는지)뿐인데 종류 칸의 구조·글자 몫으로 들어가 있다
- 겹침: 맞음 — test_conductor_state_branch_e2e.sh:69–110 이 send·read·ack·답·표지 없는 send(rc 5)를 명령줄로 다시 걷고, test_conductor_cross.py:248–258 이 about 제어 글자를 렌더 쪽에서 본다. 2000/2001 경계 두 케이스(:142–147, :235–239)는 입력이 하나는 `\n` 붙음이라 완전히 같지는 않다
- 시간 쓰는 곳: 맞음 — 케이스 44 가운데 39 가 MailRepo(StateRepo 준비 git 약 11번: conductor_branch_fixture.py setUp·clone·put + claim 둘 + CB.ensure 둘), cli() 하위 프로세스는 11 케이스에서 22번, Inbox 의 plant 는 케이스당 최대 9번(:283–295). 111.7초/44 ≈ 2.5초도 행과 같다
- 고치면 잃는 것: 없음 — 케이스는 setUp 마다 새로 서고 서로의 상태를 읽지 않는다. 표지·기계 상태는 w/.claude/spec-distill 안이고(state_path.py:73–78), 표지 파일에는 세션 id 만 있어(conductor_state.py:361–375) copytree 에 remote set-url 을 더하면 같은 상태가 된다. cli() 의 프로세스 경계(rc·출력)는 고치기 대상에 들어 있지 않다
- 판정: 선다 — 지키는 것은 그대로 두고 상태 브랜치 둘이 선 레포를 한 번 지어 복사할 수 있다. Closures.test_reader_closes_about_too(:193–197)는 parse_letter 만 부르는데 MailRepo 를 물려받는다
- 보안 갈래: 맞음 — 남의 글의 지시 흉내·터미널 제어 글자 차단, 기계 경로가 원격에 올라가는 것을 막는다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_leader_seat.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 남의 고침이 확인될 때까지 rules-add·drop·branch 를 거절(:277–287, :496–502)한다. 재지 못하면 닫고(:116–120, :301–310, :504–518), 머지로 숨긴 고침을 잡고(:145–161), 원격을 다시 써도 세탁되지 않고(:620–642), confirm 은 보인 끝 40자로만 받고(:568–579, :733–744), rules-branch 이름 꼴을 거절(:466–473)한다
- 겹침: 맞음 — test_leader_seat_e2e.sh 의 걸음 10(묶음 알림), 걸음 16(rules-branch 갈라짐 rc 1·차이), 걸음 18(8자 confirm 거절 rc 2, :241), 걸음 25(꺼진 설정)가 같은 판정을 명령줄로 다시 잰다. 파일 안에서는 「남의 머지 커밋」 만들기가 :149–156, :361–367, :505–513, :698–704 네 벌이다
- 시간 쓰는 곳: 맞음 — test_ 67개가 모두 TeamRepo 준비(StateRepo git 약 11번 + put 3번 + claim + CB.ensure push)를 새로 한다. foreign_edit 호출 자리가 34(행은 약 35)이고 부를 때마다 clone+fetch+claim+write(push)가 붙는다. ls() 하위 프로세스는 34자리에 반복문(:739) 4번을 더해 약 38번이다(행은 약 30)
- 고치면 잃는 것: 없음 — 케이스끼리 상태를 공유하지 않는다. copytree 한 사본에서는 foreign_edit 이 self.o 로 clone 하므로 self.o·remote URL 만 사본 쪽으로 맞추면 된다. CB._push 를 mock 하는 케이스(:644–662)는 복사와 무관하다
- 판정: 선다 — 67번의 레포 세우기가 시간 대부분이고, 준비를 한 번 지어 복사하면 같은 확인이 싸진다
- 보안 갈래: 맞음 — 다른 세션·클론이 심은 규칙을 신뢰 경계 밖으로 막는 판정이다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_roadmap_status.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 단계 판정(:232–281, :1191–1356, :1506–1600), 검사 불가를 빈 결과로 뭉개지 않음(:378–417), 정적·행동 읽기 전용(:419–892, :1787–1851), 번호 판정(:1858–1969), 공시 문면(:283–299, :1971–1990)
- 겹침: 맞음 — test_merge_check.sh·test_conductor_branch.py 에 GIT_ALLOWED 가 있고, test_roadmap_render.py·test_roadmap_model.py·test_entry_guidance.sh 가 같은 실제 로드맵(persistent-explore-pm-decompose)을 읽는다. test_roadmap_status_merge_base.py 는 merge-base 를 10번 부른다
- 시간 쓰는 곳: 맞음 — roadmap_status.py 실행 73자리에 ro_probe 4번을 더해 약 77번이다. js·stage·warns·notes·reason 은 287번 python 을 띄운다. `g` 는 422자리이고 commit_file 68번이 각각 g 두 번이라 git 은 550번 넘는다(행의 428 은 하한이다). 사본 복사는 ctl_reader 25번과 ro_variant 4번이고 scripts 의 .py 는 71개다. 모든 git 이 fakebin-origin bash 래퍼를 지난다(:25 의 export PATH). static_check 는 직접 17번에 ctl_reader 안에서 25번을 더해 약 42번이다(행은 약 28)
- 고치면 잃는 것: 있음 — ① 래퍼를 「그 칸에만」 두르면 owner 판정이 빠진다. 머지 문면 길(B1·Q1·H30 머지됨, G30 거절, :238–246, :1590–1592)이 RS 실행마다 FAKE_ORIGIN_URL 에 기대므로 RS 실행 전부에 래퍼가 필요하고, 덜 수 있는 것은 픽스처 쪽 `g` 호출의 래퍼뿐이다. ② 나누기는 확인을 잃지 않지만 공짜가 아니다. 절이 앞 절의 누적 상태에 기댄다. §1 의 $OUT 을 :412 와 :1165 가 다시 읽는다. rm30 의 S30_TIP·B30_TIP 를 rm31·rm32 가 쓴다(:1613, :1662). ro_probe 는 rm30 픽스처를 쓰고(:1790–1833), rm40 변이는 §6 의 $M 폴더를 쓴다(:1943). docs/rm2·rm3·rm4·rm5 이름도 뒤 절이 덮어쓴다(:1135, :1193). ③ ro_probe 는 PATH 기록기·chmod 로 프로세스 경계를 재는 것이 확인 대상이라 한 프로세스로 내리면 안 된다(행은 그렇게 제안하지 않았다)
- 판정: 선다 — js 287번을 보고서마다 한 번으로 묶는 것과 static_check 변이를 메모리 안에서 하는 것은 잃는 것이 없다. 나누기는 공통 이력(:132–230)을 픽스처 함수로 빼야 한다
- 보안 갈래: 맞음 — 상태 계산이 쓰기·네트워크·gh·허용 밖 git 을 하지 않는다는 권한 경계를 정적·행동 두 길로 잰다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_conductor_ledger.py
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 표지 rc 5(:115–119, :170–175), 깨진 기계 상태를 덮어쓰지 않음(:140–147), cleanup 이 링크·자기 자리·잠긴 스위트 사본·worktree 아닌 폴더를 지우지 않음(:328–345, :383–398, :491–510), 자원 이름의 `..`·`/` 거절(:434–446), pr-refresh·pr-record 가 다른 head·fork·base 를 받지 않음(:1211–1218, :1478–1500), 사람 줄은 record --human 으로만(:2152–2158, :2540–2547), 셀 수 없음·rc 3(:857–861, :872–957)을 본다
- 겹침: 맞음 — test_conductor_e2e.sh 가 claim·worktree-path·write-sections·cleanup 을 정상 길로 걷는다(:53, :67, :90, :114). PendingSeat 와 test_leader_seat_e2e.sh 걸음 19–21·25 는 대기 줄 판정이 겹친다
- 시간 쓰는 곳: 맞음 — 케이스 186 가운데 159 가 Repo/TeamRepo 준비를 새로 한다(Repo.setUp git 7번 :66–78). 상태 계산 하위 프로세스는 c_pr_refresh·c_pr_record·c_audit·c_review_pack·c_roadmaps 가 roadmap_status.py 를 띄운다(conductor_ledger.py:455–456, :610–612, :773). refresh() 30, record() 16, review-pack 15, pr-handoffs 9, reason() 6 자리 등 약 80–100번으로 보인다. cli() 는 프로세스 안 L.main 이다
- 고치면 잃는 것: 없음 — 케이스는 서로 독립이다. 레포 없는 케이스로 옮기라는 예(write-sections·record 의 s.md)는 team_intent 가 git 없이 None 을 낸다(conductor_ledger.py:657–673). 일부러 하위 프로세스를 쓰는 RetiredApproval.test_retired_subcommands_are_unknown(:151–158)과 LiveAgent.test_unexpected_error_is_rc3_not_none(:755–766)은 프로세스 경계(argparse 종료·잡히지 않은 예외의 rc 3)가 확인 대상인데, 제안은 이들을 건드리지 않는다
- 판정: 선다 — 다만 판정 근거가 setUp 만 든다. roadmap_status.py 하위 프로세스 약 80–100번(행의 ②)도 비슷한 몫으로 보이는데 구조 고치기 여지에 그 몫이 없다(같은 케이스 안 반복 호출: test_mismatch_head_drops_only_that_row 의 refresh 두 번, RecordThenStatus 의 reason() 반복)
- 보안 갈래: 맞음 — 경로 탈출(`..`·링크)·표지 권한·지우기 경계·사람 줄 위조 막기를 실제로 실행해 본다
- 권하는 판정: 구조를 고침

### shared/tests/test_docreview_route.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 익명화(cases.sh:1797–1805), same_as 높은 처분(:1806–1813), 시점 판별 codex·critic 부재·사망(:1676–1780) 등 121 케이스(test_docreview_route.sh:18–138)가 처분·사유 코드·계수를 실행 결과로 본다
- 겹침: 일부만 — test_docreview_golden.sh:4–15 는 대표 케이스 셋의 finalize 산출물을 바이트로 대조할 뿐 121 케이스를 덮지 않는다. test_docreview_mutations.sh:63–66 은 같은 케이스를 변이 사본으로 다시 도는 별개의 축이다(겹침이 아니라 이 케이스를 이빨 재기에 쓴다)
- 시간 쓰는 곳: 맞음 — 케이스 본문에 route_r1 80번(r1 3번 + prepare·render·finalize, python 약 6번), r1 80번(3번), next_round 23번(6번)이 있다. 단언 헬퍼는 jget 144 · fsum 60 · gsum 24(각 2번) · st_yaml 34 · jgets 11 · gfirst 9 번이고 직접 py 는 180번이다. 본문만 python 약 500번, 준비까지 약 1,300–1,400번(반복문은 한 번으로 셌다)이다. 행의 「본문 약 680회」 와 자릿수가 같다
- 고치면 잃는 것: 있음 — ① 원장이 문서 사본의 절대 경로를 담는다(init 이 절대 경로를 요구 docreview_state.py:962–963, own_doc 이 상태 폴더 안 src/ 로 복사). 그래서 cp -R 사본은 원본 폴더의 문서를 가리키고, put_doc·sink 가 템플릿 쪽 문서를 덮어 케이스 격리가 깨진다. ② 라운드 시작 표식이 상태 파일 mtime 이라(:1115) cp -R 로 mtime 이 바뀌면 codex_now·critic_now·backdate·st_mark 를 쓰는 시점 판별 케이스의 전제가 달라진다. ③ route_r1 은 cases.sh 의 공유 헬퍼다. 여기에 캐시를 두면 run_case 가 변이 SCRIPTS 로 같은 케이스를 돌 때(test_docreview_mutations.sh:63–66) 깨끗한 스크립트로 지은 상태를 재게 되어 init·prepare-recritic·finalize 변이의 이빨을 잃는다. 공유는 진입 파일에서, 읽기만 하는 케이스에, 경로를 고쳐서만 해야 한다. jget 묶기는 잃는 것이 없다
- 판정: 선다 — 준비 공유는 위 셋을 지키는 꼴로만 서고, 단언 묶기는 그대로 선다
- 보안 갈래: 맞음 — 보호·불변 절 승격, 주 판정자 사망 시 차단, 처분 강등 막기 같은 리뷰 게이트 경계를 지킨다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_leader_seat_e2e.sh
- 원래 판정: 줄임
- 지키는 것: 맞음 — 규칙 사본 → 묶음 머리·--rules-at → job sync rules_at → 「묶음 낡음」(:50–130), 남의 고침 알림(:132–150), sync 의 지우기·갈라짐·남의 고침(:167–245), 대기 줄 flush(:247–316), 꺼진 설정의 R1 글(:318–325, :419–443)
- 겹침: 일부만 — 걸음 23 은 앞 걸음에 없는 확인을 갖는다. 확인 뒤 묶음이 남의 줄을 싣고 --rules-at 이 확인 끝이 되는 것(:398–402)은 걸음 18 이 확인 뒤 묶음을 다시 부르지 않아서 이 걸음에만 있다. sync 는 두 쪽 남의 고침 2, 묶음은 규칙 쪽 1 로 따로 세는 것(:379, :382)도 이 걸음에만 있다. 걸음 22 는 둘째 고침을 rules-add 로 낸다(:347). 걸음 6 은 copy() 로 CB.write 를 직접 불러 rules-add 를 지나지 않는다(:85)
- 시간 쓰는 곳: 어긋남 — new_repo 5번(:15, :168, :248, :276, :328), 둘째 클론 4번(:134, :220, :285, :359), 하위 프로세스 약 140번(bundle 11 · cb 21 · status 9 · csync 10 · pend 7 · flush 7 · seen_pend 7 · run_sync 6 · js 10 · new_repo 안 python 약 25 · approved 4번×3 등)은 맞다. 다만 「approved 가 레포마다 두 번」 은 틀렸다. approved 는 레포 a·e 에서만 두 번씩(:47, :335) 모두 4번이다
- 고치면 잃는 것: 있음 — 걸음 23 을 앞 걸음에 흡수하면서 :379·:382·:398–402 를 옮기지 않으면 그 확인이 빠진다. 레포 d(걸음 20)는 상태 브랜치가 없는 동안의 add(:279–281, 「상태 브랜치가 없어 기계 상태에 쌓았다」)가 확인 대상이라, ensure 가 끝난 앞 레포에 이으면 그 전제가 없어진다. 레포 c(걸음 19)는 b 에 이을 수 있어 보인다
- 판정: 서지 않는다 — 「22·23 은 같은 이음매를 다시 돈다 · c·d 는 앞 레포에 이어도 같다」 는 근거가 23 의 고유 확인과 d 의 「상태 브랜치 전」 전제를 놓쳤다
- 보안 갈래: 맞음 — 확인 안 된 다른 클론의 규칙·대기 줄을 담당자 묶음과 결정 기록에서 막는 신뢰 경계다
- 권하는 판정: 구조를 고침 — team_repo 결과를 한 번 지어 cp -R(origin 이 "$T/origin.git" 절대 경로라 set-url 하고, CLAUDE_CONFIG_DIR 은 레포마다 둔다)로 레포 다섯의 준비 비용을 덜고 걸음은 그대로 둔다

### shared/tests/test_docreview_advice.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — must_catch 지목대로 advice·차단 원장을 가름(cases_advice.sh:14–31 의 advisory_axes·is_advisory, AC1 :51–67), fail-closed 갈래, 박제·계수 줄·원자 쓰기·surrogate 를 실행 결과로 본다(test_docreview_advice.sh:19–86)
- 겹침: 맞음 — test_docreview_mutations.sh:66 이 cases_advice.sh 를 source 해 같은 케이스를 변이로 다시 돈다
- 시간 쓰는 곳: 맞음 — 케이스 본문에 mc_r1 14(행 14), adv_state 22(행 21), route_r1 직접 22(행 20 남짓)가 있고 각각 python 약 6–7번(adv_state 는 mk_advice_critic.py 1번 더, :334–338)이다. 단언 헬퍼는 jget 30 · jgets 7 · gsum 22(각 2번) · fsum 23 · st_yaml 38 · adv_has 16 · id_of 10 · adv_py 8 번이고 직접 py 는 88번이다. 본문 python 은 약 300번이고 행의 「300번 남짓」 과 같다
- 고치면 잃는 것: 있음 — 변이 락은 새로 지으라는 단서는 행에 있다. 그러나 원장이 문서 사본의 절대 경로를 담는다는 점은 빠졌다(mk_state→own_doc, docreview_state.py:962). 그래서 cp -R 사본에서 sink·계수 줄을 쓰는 케이스(AC7·AC17·closed_log 계열)가 템플릿 폴더의 문서를 고친다. 읽기만 하는 케이스로 한정하더라도 상태 파일 mtime(라운드 시작 표식)을 보존해야 다음 라운드를 여는 케이스(adv_round2·mc_round)의 시점 판별이 같다
- 판정: 선다 — 읽기만 하는 케이스에 한해, 경로·mtime 을 맞춘 복사로 서고 단언 묶기는 그대로 선다
- 보안 갈래: 맞음 — 승인을 막아야 할 지적이 참고로 새지 않게 하는 리뷰 게이트의 fail-closed 경계다
- 권하는 판정: 구조를 고침

### plugins/spec-distill/tests/test_finish_pr_merge.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — origin 레포의 PR 만(:308–319, :534–538), 물을 때의 끝 커밋에 묶은 머지(:380–403), 검사 실패·30분·대기열이면 MERGED 아님(:321–334, :350–359), 다시 확인 펜스의 정해진 횟수(:492–509), 폴더 밖 파일이면 ONLY 아님(:213–272)을 bash·zsh 둘에서 본다
- 겹침: 확인 못 함 — test_gh_repo.py·test_gh_repo.sh·test_finish_commit_roadmap.sh 는 열지 않았다
- 시간 쓰는 곳: 맞음 — 셸마다 mk 23번(:185–594)이고, mk 한 번이 bare init·가짜 ssh 를 거친 clone·커밋 3·push 다(:135–152). run 은 62자리에 반복문(:410, :374, :496, :555)을 더하고 직접 실행 3번을 합쳐 셸마다 약 72번이다. hang 은 펜스의 `[ "$n" -lt 120 ]` 루프(finishing.md 머지 펜스)로 가짜 sleep 을 최대 120번 띄운다
- 고치면 잃는 것: 있음 — ① zsh 바퀴를 new·mixed·merge·cut·late 로 줄이면 hang(백그라운드 `&`·`$!`·`kill -0`·`wait`, :355–359)이 zsh 에서 돌지 않는다. 대기열 다시 읽기 루프(:321–334), mktemp 실패 갈래(:256–264, :588–592), stderr 가르기(:250–255), failmerged(:439–462)도 마찬가지다. 펜스는 Bash 도구의 셸에서 돌고 케이스마다 다른 갈래의 줄을 지난다. 특히 백그라운드·kill·wait 는 셸 차이가 나기 쉬운 자리다. ② 판결 갈래를 gh_repo.py 단위로 내리면 잃는다. 신원 대조 `[ "$pr" = "OPEN $def $cur false $HEAD_SHA" ]` 와 이미 머지됨 `case "$pr" in "MERGED $def $cur false "*` 는 finishing.md 머지 펜스의 셸 코드다. gh_repo.py pr-identity 는 칸을 찍을 뿐이다. mk 템플릿 cp -R 은 owner 이름이 URL·-R 단언에 들어가 사본마다 remotes/<owner> 자리와 remote 를 맞춰야 하지만 잃는 것은 없다
- 판정: 선다 — 「구조를 고침」 자체는 mk 템플릿 복사로 선다. 행이 든 셋 가운데 zsh 축소와 단위로 내리기는 지키는 것을 잃는다
- 보안 갈래: 맞음 — 다른 레포 PR·끝 커밋이 바뀐 PR 을 머지하지 않는 바깥 쓰기 경계다
- 권하는 판정: 구조를 고침 — mk 결과를 템플릿으로 복사하는 것만 하고, zsh 축소는 갈래별로 셸 의존을 따져 정하고, 판결 갈래는 펜스 쪽에 남긴다

#### 되풀이되는 어긋남 — b2

- 「준비를 한 번 지어 복사」 제안이 복사하면 깨지는 전제를 따지지 않는다. 상태에 박힌 절대 경로(docreview 원장의 문서 사본 경로), 파일 mtime 을 쓰는 시점 판별, 변이 매트릭스가 함께 쓰는 헬퍼가 그 전제다. 예: test_docreview_route.sh(셋 모두 빠짐), test_docreview_advice.sh(변이 락 단서만 있고 경로·mtime 은 빠짐)
- 「덜어도 같다」 는 판단이 확인 대상(갈래·셸·펜스 코드·전제 상태)을 덜 본다. 예: test_leader_seat_e2e.sh(걸음 23 의 고유 확인, 레포 d 의 「상태 브랜치 전」 전제), test_finish_pr_merge.sh(zsh 축소가 hang·대기열 갈래를 빼고, 판결 갈래는 gh_repo.py 가 아니라 펜스 셸 코드다)
- 시간을 쓰는 곳이 둘인데 판정 근거·고치기 여지가 하나만 다룬다. 예: test_conductor_ledger.py(roadmap_status.py 하위 프로세스 약 80–100번), test_roadmap_status.sh(래퍼를 한 칸에만 두르면 RS 실행마다 필요한 owner 판정이 빠진다)

#### 확인하지 못한 것 — b2

- shared/tests/fixtures/docreview/cases.sh(4773줄)·cases_advice.sh(1097줄)는 헬퍼 정의와 일부 케이스만 읽었다. 케이스 본문 전체는 함수 경계를 잘라 헬퍼 호출을 세는 스크립트로 정적으로 셌다. 반복문은 한 번으로, 갈래는 모두 셌으므로 python 횟수는 어림이다
- 겹침의 상대 파일은 해당 줄만 열었다(test_conductor_state_branch_e2e.sh, test_conductor_cross.py, test_docreview_golden.sh 머리, test_conductor_e2e.sh, test_docreview_mutations.sh 의 run_case). 열지 않은 상대는 test_control_plane.sh, test_human_gate_e2e.sh, test_gh_repo.py·.sh, test_finish_commit_roadmap.sh, test_docreview_gate_plain.sh·gate_visibility.sh, test_docreview_ask.sh, test_begin_round_snapshot.sh 다
- 테스트를 돌리지 않았으므로 시간 몫(준비 대 하위 프로세스)의 비율은 호출 수로 어림한 것이다

## 표본 c1 — 「둠」 · 보안 표시 무작위 28

### plugins/spec-distill/tests/test_seed_review_profile.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 앵커 부류를 비운 프로필로 drop·ask·fix 가 그대로 가고(:72), 보호 판본은 셋 다 decide 로 가며(:78), 결정 기록 헤딩이 템플릿에 한 번 있다(:86-87)
- 겹침: 해당 없음 — 행이 적은 test_docreview_profiles.sh 는 프로필 구조만 보고, 이 라우팅 양성 대조와는 다른 것이다
- 판정: 선다 — 0.6초에 동작 확인 둘과 양성 대조를 함께 한다
- 보안 갈래: 맞음 — 「아니오」 가 맞다. 라우팅이 맞는지 보는 확인이지 보안 경계가 아니다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_roadmap_ontology.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 객체 표의 링크 이름과 주인 기호를 AST 정의(:88-97)와 코드에서 뽑은 집합(:65)에 맞추고, 양성 대조도 있다(:168-175)
- 겹침: 맞음 — 「못 찾음」 이 맞다. 다른 두 테스트는 문서가 있는지만 본다
- 판정: 선다 — 0.1초다. 26개 이름을 차례까지 핀하는 것(:29-32)은 거짓 실패를 부르지만, 문서와 코드를 잇는 유일한 락이다
- 보안 갈래: 맞음 — 「아니오」 가 맞다
- 권하는 판정: 둠

### plugins/quality-gates/tests/test_detect_codex.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 7가지 skip 사유, 이웃 스위치를 듣지 않음, 망가진 conf 의 fail-closed 를 확인한다(:22-119). AC7 두 개와 Case 11·12 는 글자 grep 이다
- 겹침: 어긋남 — qg·sd·pa 의 scripts/detect_codex.sh 셋이 모두 shared/codex/detect_codex.sh 를 가리키는 링크다. plugins/plugin-audit/tests/test_detect_codex.py:1 은 「형제 두 사본과 같은 커버리지」 라고 스스로 밝히고 같은 케이스 14개(:33-123)를 돈다. plugins/spec-distill/tests/test_detect_codex.sh 도 같은 꼴이다. 행이 쓴 「다른 각도」 가 아니라 같은 스크립트에 같은 케이스를 세 번 돌린다
- 판정: 서지 않는다 — 플러그인마다 달라지는 것은 conf(스위치 변수 이름) 하나뿐이다. 그와 무관한 케이스(미설치·샌드박스·인증·판·하한·판독 불가·timeout grep)는 세 파일이 겹친다
- 보안 갈래: 맞음 — kill switch 와 망가진 conf 의 fail-closed 를 실제로 잰다(:31, :110-119)
- 권하는 판정: 합침 — 스크립트 로직 케이스는 shared 쪽 한 곳으로 모으고, 플러그인마다 conf 케이스(자기 스위치·이웃 스위치·망가진 conf)만 둔다

### plugins/spec-distill/tests/test_yaml_scalar_single_definition.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 정의가 하나이고 같은 함수 객체를 쓰는지(:70-92), 인용 규칙과 음의 짝(:98-153), shared 정본과 바이트가 같은지·상수가 같은지(:177-241)를 본다
- 겹침: 일부만 — test_codex_findings_to_yaml.py 의 TestSummaryScalarRoundTrip 은 정본 쪽 summary 인용을 끝에서 끝으로 본다. 이 파일은 두 정의의 일치와 상수를 본다
- 판정: 선다
- 보안 갈래: 맞음 — 「아니오」 가 맞다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_brief_verbatim_full.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — payload §6 이 S1~Sn 을 전부 담아야 통과하고(:40-45), 같은 앵커의 글자가 다르거나 빠지면 막으며(:52-80), 세 자리에 함께 더하면 통과한다(:102). 남의 본문 안에 심은 앵커(:115-131)와 state 에 없는 추가(:133-146)는 막는다
- 겹침: 일부만 — test_check_verbatim_coverage.sh:440(anchor_indented)·:603(unknown_ids) 와 test_check_brief.sh(N1b) 가 같은 사유를 잰다. 이 파일만의 것은 심은 S3 로 OQ 를 「해결」 하는 케이스와 세 자리 append 다
- 판정: 선다 — 1.3초다. 겹치는 케이스는 두셋이다
- 보안 갈래: 어긋남 — 막는 것은 모델이 사용자 발화를 지어 넣는 일(원장의 무결성)이다. 바깥 입력의 주입이나 권한·비밀 경계가 아니다. 「주입」 이라는 낱말만 닿았다
- 권하는 판정: 둠

### shared/tests/test_dispatch_disposition.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 축 A①~⑤·B·C(:144-270)와 vacuity 하한(:290-299, :335-339)을 본다
- 겹침: 맞음 — 헌장이 집행처로 지명했고, 형제 테스트들은 다른 키를 잰다
- 판정: 선다
- 보안 갈래: 맞음 — 「아니오」 가 맞다. 판정 항목이 소실되지 않았는지 세는 회계다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_walk_table.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 기본 표와 깨진 표(:31-90), 읽기 전용 AST(:93-109)를 보고, 설정의 표는 커밋에서만 읽으며 링크와 절대 경로는 멈춘다(:152-198)
- 겹침: 확인 못 함 — test_walk_next.sh:157-168 은 레포 표를 읽는 것을 보지만, 링크와 절대 경로 케이스는 거기 없었다(grep)
- 판정: 선다
- 보안 갈래: 맞음 — 링크 멈춤(:186-192)과 절대 경로 설정 멈춤(:194-198)은 경로 탈출 확인이다. 다만 파일 안 확인 약 20개 가운데 둘뿐이다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_human_judge.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 판 찾기(:78-100), 지어낸 줄 갈래 20여 개(:183-211), 관문 표와 구문 나무 탐침(:381-429)을 본다
- 겹침: 맞음 — test_human_gate_e2e.sh:109- 가 지어낸 줄을 세 자리에서 다시 잰다. 이 파일이 가장 싼 층이라는 행의 말이 맞다
- 판정: 서지 않는다 — 행은 「테스트마다 레포를 새로 두는 것은 커밋을 쌓는 테스트라 필요하다」 를 비용의 근거로 댔다. 그런데 SeededRepo 를 쓰는 약 37개 테스트 가운데 setUp 뒤에 커밋하는 것은 다섯쯤뿐이다(:170 뒤 commit 호출 7줄 — :223·:243·:463-466·:519·:526). 나머지는 SF.add_answer 로 테스트마다 있는 conf 폴더에 쓴다. 표본에서 가장 비싼 11.7초인데, 대부분이 되풀이 git init 과 커밋 4개다
- 보안 갈래: 맞음 — 사람 승인 줄의 위조를 막는다. 사람이 정하는 관문(권한)이다(경계 사례)
- 권하는 판정: 구조를 고침 — 커밋하지 않는 테스트는 클래스마다 한 번 세운 레포를 함께 쓰고(setUpClass), conf 폴더만 테스트마다 새로 둔다. 커밋하는 다섯은 지금처럼 둔다

### plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 스텁 행렬과 개행 주입이 전부 끔(:140-174)이고, 검사기 자체 실패도 끔(:178-186)이며, cwd 미끼를 실행하지 않는다(:234-245, :414-423). 상태 폴더와 미커밋·후보 펜스(:251-613)도 본다
- 겹침: 일부만 — 행이 적은 대로 test_review_entry.py 가 스위치 판정을 단위로 잰다
- 판정: 선다
- 보안 갈래: 맞음 — fail-closed, PROCEED 줄 위조(개행 주입), 사용자 저장소 미끼 미실행, kill switch 이름 대기를 잰다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_bundle_short_line.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — short_line 네 갈래(:14-19)와 entry 의 질문 줄 위치(:34-41)를 본다
- 겹침: 일부만 — test_team_review_entry.sh:42·:65 가 같은 「질문 줄:」 꼴을 다른 경로(team INTENT.md)로 잰다. 행은 「못 찾음」 이라 적었다
- 판정: 선다 — 0.5초다
- 보안 갈래: 맞음 — 「아니오」 가 맞다
- 권하는 판정: 둠

### plugins/quality-gates/tests/test_runner_adapters.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 감지 15가지(:33-71), 입도 표(:61-66), unrun·error 갈래(:87-142), kill switch 가 실행 단계와 setup 단계를 막는지와 양성 대조(:144-169)를 본다
- 겹침: 맞음 — 행이 적은 대로 축이 다르다
- 판정: 선다 — 비용의 큰 몫이 진짜 venv(:106-115)라는 행의 말도 코드와 맞다
- 보안 갈래: 맞음 — kill switch 아래에서 저장소 코드를 실행하지 않고, 저장소의 json.py 를 import 하지 않는다(:67-71)
- 권하는 판정: 둠

### plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 셸로 쓴 변경이 session 범위·diff 에 git 오라클과 같은 집합으로 들어오는지(:225-254), check-review-scope 의 수와 양성 대조(:272-292), 은퇴 마커 부재와 탐지기 확인(:307-335)을 본다
- 겹침: 확인 못 함 — 행과 같다. 열지 않았다
- 판정: 선다
- 보안 갈래: 맞음 — 「아니오」 가 맞다. 리뷰 범위가 새지 않는지 보는 것이다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 래퍼(:14-19)다. 실제 확인은 grammar_vs_markdown_it_check.py(563줄)에 있다: 앵커·머리·결정 줄의 어긋남(:244-333), 실제 brief·seed 코퍼스(:355-475), 펜스·setext·코드 칸(:536-563). 행은 그 모듈을 읽지 않았지만 요지는 맞다
- 겹침: 어긋남 — 행이 겹친다고 한 test_grammar_vs_markdown_it.py 는 지금 없다. 그 파일이 이름을 바꾼 것이 이 래퍼가 돌리는 grammar_vs_markdown_it_check.py 다(git log --all, 3f9088e2 「교차 확인 모듈 이름」). 둘로 나뉜 것이 아니다. test_seed_grammar_crosscheck.py 는 우리 판독기끼리 대조하는 것이라 다르다
- 판정: 선다
- 보안 갈래: 맞음 — 「아니오」. HTML 로 감춘 「위조」 앵커 케이스(:190-206)가 있지만, brief_verbatim_full 과 같은 무결성 갈래다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_roadmap_approval.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 승인 줄과 부정 줄 26가지(:23-65), 단계 계산과 merge-base 실패의 「알 수 없음」(:106-143), PR 캐시(:161-204)를 본다. OneDefaultRef(:146-158)는 글자 부재도 섞여 있다
- 겹침: 확인 못 함 — 행과 같다
- 판정: 선다
- 보안 갈래: 맞음 — 「아니오」
- 권하는 판정: 둠

### shared/tests/test_docreview_agent_fields.sh
- 원래 판정: 구조를 고침
- 지키는 것: 어긋남 — 행은 「`tools:` 가 Read·Grep·Glob 뿐, denylist·model 키 없음, 웹 사본이 정본과 한 덩어리만 다름(variant_of.py)」 이라 적었는데, 이 파일에는 tools·model·variant_of 가 한 글자도 없다(grep 0건). 그 내용은 test_docreview_agents.sh·test_variant_of_contract.sh 의 것이다. 실제로는 리뷰어 출력 형식의 문구를 본다: replacement·if_unfixed 칸(:46-67), added 규약(:72-84), 쉬운 말 한 줄(:87-95), contradicts·첫 줄 규칙·related_changes 슬롯(:100-119)
- 겹침: 일부만 — test_docreview_agents.sh 는 같은 사본의 다른 규칙을 본다
- 판정: 서지 않는다 — 근거로 든 「frontmatter 를 케이스마다 python 으로 새로 파싱」 도 사실과 다르다. python 약 24번 가운데 frontmatter 파싱은 6번(:112)이고, 나머지는 절 추출(:27-42)이다. 0.7초라 합쳐서 얻는 것은 0.5초 미만이다. 종류도 「구조 70」 이 아니라 거의 글자다
- 보안 갈래: 맞음 — 리뷰어 프로필 본문이다. 다만 보안 경계를 재는 확인은 「`<related_changes>` 의 절 제목도 문서에서 온 글이다」(:110, 문서 글을 지시로 읽지 않는 규칙) 하나뿐이다. 행이 댄 근거(tools allowlist)는 이 파일에 없다
- 권하는 판정: 둠 — 싸고, 리뷰어 출력 칸 계약의 유일한 락이다

### plugins/spec-distill/tests/test_codex_findings_to_yaml.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 스키마 위반은 codex_failed 로(:71-115), 마지막 펜스를 고르고(:117-129), summary 를 왕복하며(:158-249), keyset 바이트는 고정이다(:264-368)
- 겹침: 일부만 — plugins/quality-gates/tests/test_findings_parser.sh 의 PARSER 와 이 파일의 SCRIPT 가 같은 shared/codex/codex_findings_to_yaml.py 를 가리킨다(둘 다 링크). malformed_json·missing_result·auth_error·마지막 펜스·dict findings 의 schema_mismatch, 이 다섯 케이스가 두 파일에 겹친다(:43-57·:71-77·:117 대 findings_parser :53-68·:109-130)
- 판정: 선다 — 겹치지 않는 케이스가 더 많다
- 보안 갈래: 맞음 — 신뢰할 수 없는 LLM 출력에 심은 앞 펜스를 무시한다(:117-129)
- 권하는 판정: 둠

### plugins/plugin-audit/tests/test_codex_audit_to_json.py
- 원래 판정: 둠
- 지키는 것: 맞음 — 키 부재·타입 위반·빈 출력이 clean 이 아니고(:51-129), 마지막 펜스와 마지막 메시지를 채택하며(:85-96), 늘 exit 0 이다(:149-152)
- 겹침: 확인 못 함 — 행과 같다. 다른 스크립트라 qg·sd 변환기와 겹치지 않는다
- 판정: 선다
- 보안 갈래: 맞음 — 감사 대상 파일에 심은 앞 펜스를 이긴다(:85-90)
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_seed_at_path_handoff.sh
- 원래 판정: 줄임
- 지키는 것: 맞음 — 행이 쓴 「대부분 글자」 가 맞다. 이름 가드 case 를 실행하는 것(:121-133)만 동작이다
- 겹침: 어긋남 — 행은 「proceed-gate 정본 단락 문장 핀이 다른 proceed-gate 락과 겹친다」 고 했다. 그런데 이 파일이 핀하는 정본 문장 가운데 「지휘자 아래 — 승인 질문 하나」·「cross-compact 조기 진행 금지」·「명령을 노출하면 그 턴은 거기서 종료」·「바로 진행」 부재는 tests/ 안의 다른 어느 파일에도 없다(grep). 「기타 칸 — 「여기서 계속」」 만 test_request_framing_open.sh 와 겹친다
- 판정: 서지 않는다 — 덜어 내자고 한 정본 단락 핀은 대부분 그 게이트 문장을 지키는 유일한 락이다. 덜면 지키는 것이 함께 사라진다
- 보안 갈래: 어긋남 — `$ARGUMENTS` 부재는 플랫폼의 인자 치환이 맞는지 보는 것이고, 이름 가드는 공백·탭·자리표만 거부한다(경로 문자 `..`·`/` 는 보지 않는다). 보안 경계가 아니다
- 권하는 판정: 둠 — 0.3초다. 거짓 실패(21번 고침)는 비용이지만, 덜 근거인 겹침이 없다

### plugins/quality-gates/tests/test_findings_parser.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 옛 모양과 진짜 표본(:29-50), meta override(:70-94), 삼중 따옴표(:96-105), AUTH_ERROR_RE 확장(:132-157), stderr 를 못 읽음(:159-173)을 본다
- 겹침: 일부만 — 행은 test_failure_injection.sh 등을 댔다. 그러나 같은 정본 파일을 재는 plugins/spec-distill/tests/test_codex_findings_to_yaml.py 를 놓쳤다. 그 파일과 다섯 케이스가 겹친다(위 블록)
- 판정: 선다 — 이 파일만의 케이스가 다수다
- 보안 갈래: 맞음 — 마지막 펜스 선택(:124-130)과 삼중 따옴표 주입(:96-105)을 본다
- 권하는 판정: 둠

### plugins/quality-gates/tests/test_build_codex_prompt.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 의도가 없으면 빈 intent(:20-25), 치환은 한 번(:34-37), diff·기준 블록이 없으면 exit 2(:40-48)
- 겹침: 확인 못 함 — 행과 같다
- 판정: 선다
- 보안 갈래: 맞음 — 신뢰할 수 없는 diff 안의 자리표시자가 다시 치환되지 않는다(:34-37). 다만 12개 가운데 2개다(경계 사례)
- 권하는 판정: 둠

### plugins/quality-gates/tests/test_qg_gc.py
- 원래 판정: 둠
- 지키는 것: 맞음 — TTL·마커·형제 보호(:46-285), 스냅숏 불안정(:297-374), 루트 안전 14가지(:394-607), setup 의 stderr 를 버리지 않음(:610-622)
- 겹침: 맞음 — spec-distill 쪽 test_ledger_sweep.py 는 다른 대상(원장 GC)이다. 행의 「확인 못 함」 은 정직했다
- 판정: 선다
- 보안 갈래: 맞음 — 링크 탈출(:432-587), kill switch(:83-87), 거부 줄이 링크 대상 이름을 옮겨 적지 않음(:596-607, 주입)
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_first_cell_finishing.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — Step A 와 A.5 의 문장 14개(:76-108), 변이(:141-154, :204-219), locate 펜스를 bash·zsh 로 실행(:196-202)
- 겹침: 확인 못 함 — 행이 댄 두 파일을 열지 않았다
- 판정: 선다 — 변이 15건이 건마다 cp 와 python 두 번이다(:125-139). 한 프로세스에서 문자열 사본으로 돌리면 python 기동 약 28번을 아낀다
- 보안 갈래: 맞음 — 비밀값에서 멈추고, 묻고, 가린 기록을 같은 커밋에 넣는 문장(:84-94, :97)이다. 비밀 값 갈래의 글자 확인이다
- 권하는 판정: 구조를 고침

### plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh
- 원래 판정: 줄임
- 지키는 것: 맞음 — 처음 약 100줄과 「대상 소멸」 묘비 주석 여러 덩어리가 본문의 절반쯤이다
- 겹침: 일부만 — test_code_recritic_frontmatter.sh 가 code-recritic 의 tools 를 본다(grep 확인)
- 판정: 서지 않는다 — 덜 대상으로 든 「SKILL 문구·줄 순서」 안에 이 파일만 재는 것이 들어 있다. code-recritic dispatch 의 `<diff>${DIFF}</diff>` 슬롯(:332-341 — 주석에 「test_agent_input_slots.sh cannot see this」), 처분 줄의 fail-closed(:343-351 — 「the only place that measures R-R」), 0건이어도 dispatch(:355-357)다. 「리뷰어 프로필 두 확인만 남기고」 로 읽으면 이것들이 함께 빠진다
- 보안 갈래: 맞음 — verifier-writable 페르소나 문구(:290-303), code-recritic 의 tools 포스처(:306-311), 은퇴한 kill switch 부재(:450)
- 권하는 판정: 줄임 — 범위를 좁힌다. 묘비 주석과 은퇴 표면의 부재 핀 일부만 덜고, diff 슬롯·fail-closed·AC17·NG6 는 남긴다

### plugins/spec-distill/tests/test_team_review_entry.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — INTENT.md 진입과 REFUSE(:26-73), neighbors 와 「셀 수 없음」 갈래(:76-137), 단순 작업(:140-151)
- 겹침: 맞음 — 같은 픽스처를 쓰는 다른 파일은 다른 것을 잰다
- 판정: 서지 않는다 — 행은 「시간은 대부분 team_repo 세우기」 라 추정했다(픽스처는 읽지 않았다고 밝혔다). 그런데 이 파일은 team_repo 를 한 번만 부르고(:13), 픽스처의 세우기는 python 약 6번과 git 약 10번이다(fixtures/team_repo.sh:204-235). 반면 본문은 spec_review_bundle 을 약 16번 띄우고, 브랜치 checkout·commit·push·fetch 를 십수 번 한다(:94-137). 「한 번 만든 레포를 복사」 는 이 파일 안에서 아낄 것이 없다
- 보안 갈래: 맞음 — INTENT.md 의 roadmap 이 `..` 로 레포 밖을 가리키면 열지 않는다(:84-91). 경로 탈출 케이스는 이 하나다
- 권하는 판정: 둠 — 시간이 어디서 나는지 재기 전에는 구조 고치기의 자리를 정할 수 없다

### shared/tests/test_agent_input_slots.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 판정기 fixture 여섯(:58-63), 모집단·선언 부재(:66-75), 축 (a) 의 잰 수와 못 잰 수(:89-104), 면제 상한(:110-118)
- 겹침: 맞음 — 다른 축이다
- 판정: 선다 — 0.2초다
- 보안 갈래: 어긋남(경계 사례) — 금지 종류는 prior_verdict·score·orchestrator_framing 이다(tools/adjudication/check_slots.py:19). 리뷰어가 앞선 판정에 끌리지 않게 하는 독립성 장치이지, 권한·주입·비밀 경계가 아니다. 「리뷰어」 라는 주제로 「예」 가 된 쪽에 가깝다
- 권하는 판정: 둠

### plugins/spec-distill/tests/test_distortion_devices.sh
- 원래 판정: 줄임
- 지키는 것: 맞음 — 대부분 문서의 문장 리터럴이고(:14-147, :183-194), 「참고 전부 보기」 펜스 실행(:152-180)이 있다
- 겹침: 어긋남 — 행은 test_end_gates.sh 등이 「같은 파일을 글자로 잰다」 고 했다. 같은 파일이지만 같은 문장은 아니다. 「빼면 표에 남긴다」·「재리뷰 상한은 안전 정지이고」·「확정으로 올리지 않은 발화」·「사실로 보고 직접 답한 질문」·「전체 과정으로」·fix_anchors 프론트매터·「참고 전부 보기」 는 tests/ 의 다른 어느 파일에도 없다(grep). 겹치는 것은 「자르지 않는 쪽」(test_overdesign_rubric.sh)과 Law·kill switch 줄(test_raw_source_profiles.sh) 정도다
- 판정: 서지 않는다 — 「문장 리터럴 대다수를 덜어도 지키는 것이 같다」 는 근거가 없다. 덜면 그 모델 지시 문장들을 지키는 락이 하나도 남지 않는다. 문장 핀의 비용(26번 고침)이 그 가치보다 큰지는 다른 질문이고, 사람이 정할 일이다
- 보안 갈래: 맞음 — 리뷰 프로필의 「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다」(:85)와 path-inside 관문이 거부하면 STATE_DIR 을 비우는 것(:177-179)이다. 다만 확인 약 100개 가운데 몇 개뿐이다
- 권하는 판정: 둠 — 줄이려면 「겹친다」 가 아니라 「이 문장은 지키지 않아도 된다」 는 사람의 결정이 근거여야 한다

### plugins/spec-distill/tests/test_brief_bundle.sh
- 원래 판정: 구조를 고침
- 지키는 것: 맞음 — 라벨과 헤딩 충돌(:9-22, :85-180), 신원 결속(:188-200), §6 종결 위장(:206-227), redact 3키(:106-145), 원자료 블록과 표지 위조(:229-537)
- 겹침: 확인 못 함 — 열지 않았다
- 판정: 선다 — rs_make 와 make_repo 는 약 23번이다(python 1번 + git 3번씩, raw_source_fixture.py:112-137). 다만 케이스마다 심는 내용이 달라 레포를 「함께 쓰기」 는 어렵다. 한 python 프로세스에서 여러 레포를 한꺼번에 짓는 쪽이 현실적이다. build_brief_bundle 호출은 행이 쓴 「약 60번」 이 아니라 약 37번이다
- 보안 갈래: 맞음 — 모델이 쓴 payload·원자료 블록에 번들 표지와 같은 줄을 심으면 조립하지 않는다(:333-419, 리뷰어 입력의 주입). 다른 이름의 audit 를 싣지 않는다(:188-200)
- 권하는 판정: 구조를 고침

### plugins/quality-gates/tests/test_artifact_codex_reviewer.sh
- 원래 판정: 둠
- 지키는 것: 맞음 — 프롬프트에 본문을 싣고(:11-17), 진짜 이벤트 모양을 추출하며(:26-50), 앞의 decoy 펜스를 이긴다(:56-62). degrade 사유(:69-141)와 CLAUDE_PLUGIN_ROOT fallback(:155-175)을 본다
- 겹침: 확인 못 함 — 행과 같다
- 판정: 선다
- 보안 갈래: 맞음 — 신뢰할 수 없는 artifact 에서 echo 된 앞 펜스 주입을 막는다(:56-62)
- 권하는 판정: 둠

#### 되풀이되는 어긋남 — c1

- **보안 갈래 「예」 가 얼마나 넓은가(표본 28단위).** 「예」 20, 「아니오」 8 이다(표본은 「둠」 과 보안 갈래에서 뽑은 것이라 전체 비율 53% 보다 높게 나오는 것이 자연스럽다). 「아니오」 8개는 모두 맞다.
  - 보안 경계 확인이 아예 없는데 「예」 인 것: 2/20 (10%). test_brief_verbatim_full.sh(원장 무결성), test_seed_at_path_handoff.sh(인자 치환·이름 공백 가드).
  - 경계 사례: 2/20. test_agent_input_slots.sh(리뷰어 독립성 — 어긋남으로 셌다), test_human_judge.py(사람 승인 위조 — 맞음으로 셌다). 이 둘을 엄하게 보면 좁게 잡아도 「예」 의 15~20% 가 주제만 닿은 것이다.
  - 더 큰 넓힘은 **파일 단위 표시**다. 「예」 가 맞는 18개 가운데 7개(walk_table · docreview_agent_fields · build_codex_prompt · team_review_entry · distortion_devices · skill_orchestration_behavior · first_cell_finishing 일부)는 보안 확인이 파일 확인의 약 10% 이하다. 「보안 갈래의 글자 확인은 지우지 않는다」 를 파일 단위로 걸면, 보안과 무관한 문장 핀까지 보호받는다. 표시는 파일이 아니라 확인(줄 범위) 단위로 다는 편이 맞다.
  - 「예」 의 근거로 쓴 내용이 파일에 없는 경우: 1. test_docreview_agent_fields.sh — tools allowlist·variant_of 는 다른 파일(test_docreview_agents.sh)의 내용이다.
- **「겹침」 을 이름이나 정본으로 짐작하고 열지 않은 경우가 판정을 뒤집었다.** 예는 다섯이다.
  - 같은 링크 정본을 세 파일이 같은 케이스로 잰다: detect_codex 의 qg·sd·pa. 행은 「다른 각도」 라 했다.
  - 같은 정본을 두 파일이 재는데 서로를 못 봤다: codex_findings_to_yaml.py 와 findings_parser.sh.
  - 없는 파일을 겹침으로 댔다: grammar_vs_markdown_it 의 .py, 이름이 바뀐 바로 그 모듈이다.
  - 반대로 「다른 락과 겹친다」 를 근거로 줄임을 권했는데, 열어 보면 그 문장들이 유일한 락이었다: seed_at_path_handoff, distortion_devices. 이 꼴이 지침이 말하는 가장 위험한 잘못(「지켜야 할 것을 지워도 된다」)에 가장 가깝다.
- **「둠」 쪽 기울기.** 「둠」 19개 가운데 판정이 서지 않는 것은 2개다. detect_codex 는 합침 감이고, human_judge 는 비용의 근거가 틀렸다. 나머지 17개는 지키는 것이 분명하고 대부분 1초 미만이라 「둠」 이 맞다. 무난해서 「둠」 을 고른 기울기보다는, 위의 「겹침을 열지 않음」 이 「둠」 과 「줄임」 양쪽에서 같은 원인으로 작용했다.
- **「구조를 고침」 의 시간 근거를 추정만으로 댄 경우.** 둘이다. team_review_entry 는 픽스처를 읽지 않고 「대부분 픽스처」 라 했다. docreview_agent_fields 는 「frontmatter 반복 파싱」 이라 했지만 실제로는 절 추출이 대부분이다. 실측 없이 시간 쓰는 곳을 정한 행은 확신을 「낮음」 으로 두었더라도 판정 칸에는 「확인 못 함」 이 더 맞았다.

#### 확인하지 못한 것 — c1

- 표본 28개 파일은 모두 끝까지 읽었다.
- 겹침 상대 가운데 열지 않은 것이 있다. 이 상대들이 관련된 블록의 「겹침」 은 「확인 못 함」 으로 두었다.
  - test_git_derived_scope.sh · test_check_review_scope.sh(a20 상대)
  - test_conducting_interview_stage.sh · test_decompose_surface.sh(first_cell 상대)
  - test_brief_inline_blob.sh · test_reviewing_brief_skill.sh(brief_bundle 상대)
  - test_codex_exit_meta.sh · test_codex_runner_degrade_contract.sh(artifact_codex_reviewer 상대)
  - test_codex_prompt_untrusted_clause.sh(build_codex_prompt 상대)
- spec-distill 의 test_detect_codex.sh 는 머리말과 케이스 수(grep)만 보았다. 그 파일의 케이스 구성을 끝까지 대조하지는 않았다.
- test_team_review_entry.sh 와 test_human_judge.py 의 시간이 어디서 나는지는 코드를 읽어서 한 추정이다. 실행해서 재지 않았다.
