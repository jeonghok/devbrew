# Quality Gates 플러그인

바뀐 코드를 내보내기 전에 확인한다. `/quality-gates:quality-pipeline` 한 번이 diff 를 여러 독립 각도에서 리뷰하고, 동작이 바뀐 테스트를 기준선과 지금 트리 양쪽에서 돌려, 판정 하나(`clean` · `defect` · `not-certified (<사유>)`)를 낸다. 원하면 판정 전에 사람이 승인한 명령으로 앱을 띄워 직접 걸어 본다(e2e 걷기). 브랜치에 열린 PR 이 있으면 판정 뒤 쉬운 설명과 판정 줄을 코멘트 하나로 단다(`DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 로 끈다).

## Principles Instantiated

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding) — 처분 회계(adjudication `Ledger`)** (v7.1.0) — 리뷰 findings 가 버려지는 자리가 `shared/adjudication/adjudication.py` 의 처분(`accept`/`reject`/`hold`/`absorbed`/`coerced`/`source_failed`/`uncountable`/`suppressed`)을 부르고, 그 배선을 `tools/adjudication/` 의 판정기와 `shared/tests/test_adjudication_{wiring,consumed}.sh` 가 강제한다. 소비자는 `synthesize_findings.py`·`synthesize_artifact_findings.py`. **범위**: 강제되는 것은 `.py` 소비자와 `Ledger` import 가 있는 자리이고, `consumer=orchestrator`/`human` 인 dispatch 자리는 `disclosure=` 리터럴 실재까지만 검사된다(CLAUDE.md 축 C 한계).
- **Law 2 (입력 오염 차단) — `input_slots`** (v7.1.0) — 이 플러그인의 agent 넷(`security-reviewer`·`code-recritic`·`artifact-critic`·`artifact-adversarial`)이 frontmatter 에 받는 입력의 `tag`/`var`/`kind` 를 선언하고, 금지 종류(`prior_verdict`·`score`·`orchestrator_framing`)는 C6 인용과 함께 면제 등재를 요구한다. 집행은 `shared/tests/test_agent_input_slots.sh`. 앞 리뷰어의 판정이 다음 리뷰어의 전제가 되는 것이 Law 2 가 도구로 못 막는 구멍이다.
- **Law 2 (Writer ≠ Reviewer)** — 순수 read-only reviewer agent(`security-reviewer`/`code-recritic`)가 `tools: Read, Grep, Glob` fail-closed allowlist 선언 (frontmatter scoping으로 물리적 격리 — write/exec/delegation 도구는 목록에 없어 물리적으로 부재; 이름 기반 denylist는 시간에 대해 fail-open이라 대체됨). qg 자체 agent 는 모두 쓰기 권한이 없다. 외부 추가 리뷰어(`pr-review-toolkit` 등)는 쓰기 가능할 수 있으나 advisory 이고 fix 는 오케스트레이터가 소유한다 — 테스트는 오케스트레이터가 자기가 만든 트리에서 직접 돌린다.
- **Law 3 (Compounding)** — reviewer-persona 편집이 학습된 교훈을 인코딩하는 substrate.
- **P12 anti-corollary (former AP5, trivia ceremony) 회피** — 한 문장으로 설명되는 diff(typo · rename · 주석만 · 포매팅 — 파일 수와 무관)를 오케스트레이터가 판단해 trivia 로 닫는다(판정 `not-certified (trivia)`). 토픽 · 범위면 그 전체 diff 로 판단하고, 선언이 깨졌으면(`declaration-invalid`) trivia escape 를 쓰지 않는다.
- **P22 anti-corollary (former AP9, over-dispatching / subagent spray) 회피** — 파이프라인은 fan-out consent 게이트를 fire하지 않고(documented-not-implemented였음), 리뷰어 상한 없이 iteration 마다 찍는 두 공시 줄(dispatch 전 시작 줄: 계획한 수와 더한 수 · 모두 돌아온 뒤 끝 줄: 다시 부른 수와 실패)로 subagent spray를 드러낸다.
- **P18 — 루프 상한은 남기고 넘는 길은 사용자 승인 하나(수정 루프 · 문서 비평 라운드)** — 수정 루프의 기본 상한은 5 번이다. 상한에 닿으면 Retry 대신 「한 번 더 돌기」로 사용자가 반복을 하나씩 더 열고, 연 승인은 출처(고른 선택지 · 기타 칸에 쓴 글)와 원문 그대로 세션 폴더의 `extra-iterations.md` 에 한 줄씩 남는다(지금 상한 = 5 + 그 줄 수). 문서 비평(`/quality-gates:artifact-critique`)도 상한 라운드에서 같은 꼴로 묻는다. 항목마다 적용/제외 결정과 kill switch 는 그대로다.
- **P5 (Filesystem as Memory) + P14 (State Survives Compaction)** — `.claude/quality-gates/<session-id>/` 하위 per-session markdown state (따로 무시되지 않는다 — 「파이프라인 state」 절; `/quality-gates:quality-pipeline` 시작마다 자기 폴더를 다시 만들고 TTL sweep 으로 폴더 GC).
- **P8 determinism-economy (harness lightness — trust the model)** (v2.5.0) — 암묵 session scope로 파이프라인이 돌 때 그 사실을 사용자-가시 한 줄로 밝히는 **scope 투명성**. 버려진 결정론적 under-coverage 경고를 결정론 가드가 아니라 *모델 행동*으로 대체(git 비교·차단 없음). 자연어 scope 의도는 별도 parser 없이 모델이 branch scope로 해석 — `/quality-gates:quality-pipeline branch`는 결정론적 escape hatch로 유지. devbrew P8 determinism-economy refinement("Zero hooks" 일반화) instantiation.
- **P8 determinism-economy — self-honest verdict floor** (v2.6.0; routing 제거·단순화 v2.7.0) — 파이프라인이 *검토받았다고 믿는 scope*와 *resolve한 scope*가 발산할 때(빈 세션 → resolved scope 0 → "clean"의 false-clean)를 봉쇄. read-only `scripts/check-review-scope.sh`가 `changes_exist`를 결정론으로 emit하고, SKILL이 iter-1에서 1회 호출·캐시해 **정직-verdict floor**(load-bearing, kill 불가)가 `resolved scope 0 AND changes_exist == yes`이면 판정이 `not-certified (scope-empty)` 가 된다. **무엇을 리뷰할지(routing)는 모델이 소유** — v2.7.0에서 v2.6.0의 redirect 게이트·`$effective_diff_scope` 배선·redirect kill switch를 제거하고 `/quality-gates:quality-pipeline branch` escape hatch + honesty norm 한 줄로 대체(dogfood 5버그가 전부 routing 재구성에서 나왔고 floor의 load-bearing 입력 `changes_exist`는 틀린 적 없음). 결정론은 무결성 floor 한 점에만; routing/자연어는 모델 신뢰. session 기본값·`/quality-gates:quality-pipeline branch` 자체의 스코프 **선택**(routing)은 무변경이지만, 이 floor 가 보는 것과 **별개로** ② 차등 테스트가 상시 도는 v9.0.0 이후는 차등 테스트가 고르는 test unit 이 0개인 실행도 `expected-empty` → `not-certified (scope-empty)` 다(관측 없음은 음성 결과가 아니다 — §6.4.3 P23 재결정, 2026-09-26) — **진짜 무변경(genuine no-op)과 docs/config-only 변경을 포함한다.** regression: `tests/test_check_review_scope.sh`, `tests/test_qg_false_clean_floor.sh`.
- **P21 (Secret이 prompt context에 들어가지 않음)** — 결정 도구는 결정과 포인터만 묻고 secret 값은 받지 않는다(SKILL Rules R4). regression test: `tests/test_no_secret_prompts.py`.
- **P2 (Categorical signal, no numeric scoring)** (v1.9.0; 13.0.0 에서 차등 귀속으로) — 차등 테스트는 unit 마다 범주 여덟(`STILL_GREEN` · `NEW_REGRESSION` · `PRE_EXISTING` · `FIXED` · `NEW_TEST_GREEN` · `NEW_TEST_RED` · `SILENT_DROP` · `BASELINE_UNRUNNABLE`) 중 하나만 낸다(`scripts/diff-test-results.py`). 점수 · 확신도 · 비율은 없다. 범주별 개수는 허용. devbrew P2 "수치 스코어링 ban" instantiation.
- **Law 2 (codex 격리)** — codex 리뷰(`scripts/run_codex_reviewer.sh`)의 격리는 `codex exec -s read-only` OS-level 샌드박스 + 별도 프로세스 · 모델 패밀리다. agent 파일이 아니라 스크립트라 frontmatter 가 없다(`tests/test_codex_reviewer_frontmatter.sh` 가 agent 파일 부재를 잰다).
- **Law 2 (Writer ≠ Reviewer, frontmatter scoping)** (v1.13.0) — `security-reviewer` agent가 `tools: Read, Grep, Glob` fail-closed allowlist 선언. 보안 각도 구성원이며, kill switch `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`로 사용자가 disable 가능 (Plugin Shape — 모든 reviewer는 opt-out 가능). 디스패치는 `quality-pipeline` SKILL의 보안 각도 지점에 있다.
- **Law 3 (Compounding — drift 재발 차단, v1.12.0)** — `tests/test_agent_frontmatter_keys.sh` (AC15): repo-wide deny-list bash test — C1 종류 (kebab-case 잘못된 키) frontmatter drift를 자동 차단. "리뷰를 탈출한 버그 → reviewer persona 편집 + compounding linter 신설" Law 3 instantiation.
- **Law 1 — Clarity Before Code (좌표 계약 측면)**: pipeline 의 단일 좌표 `project_dir` 가 SKILL preflight 에서 frozen 되어 모든 subagent / 외부 codex 프로세스에 명시적으로 propagate. cwd 재계산은 frontmatter Forbidden + grep-anchored drift guard 로 mechanically 차단. (v1.14.0)
- **Law 3 (Compounding) — worktree path 컨벤션** (v1.15.0) — `.claude/<plugin>/worktrees/<name>-<sid-short>/` 경로 패턴을 플러그인 공통 컨벤션으로 확립해, 차후 다른 플러그인이 임시 worktree를 만들 때 같은 컨벤션을 재사용할 수 있게 함.
- **Law 1 (Clarity Before Code) — single-turn dispatch contract** (v1.32.0) — pipeline progression이 `quality-pipeline` SKILL의 단일 assistant turn 내 serial dispatch로 일원화. cross-turn state machine (transition compute helpers, no-signal counter, 시간 기반 guard) 전부 삭제 — 진행 결정은 SKILL의 명시적 boundary + AskUserQuestion으로만 발생. 로컬 결과(`result.md`)가 세션 폴더 마커 · GC mtime anchor 이고, setup 은 그 frontmatter(session_id · started_at)와 제목만 쓴다.
- **P22 generalization (consent gate → progression gate):** AskUserQuestion
  is reused as a **progression primitive** at every fix-loop iteration
  boundary. It gates fix-loop consent (it does NOT gate subagent fan-out —
  that consent gate was never implemented; fan-out is disclosed by the
  two per-iteration lines, start line before dispatch and end line after; there is no reviewer cap) — no new principle ID needed.
- **C66 (Linked Artifact Flow) — 의도 출처** (v2.1.0; v10 에서 D13 사슬로; 14.1.0 에서 설계문서 여럿) — `scripts/discover-spec.sh` 가 의도 출처를 정한다: 범위 안 커밋의 `Spec:` 트레일러가 가리키는 설계문서 전부, 없으면 브랜치 커밋 메시지 + 열린 PR 본문. 그 내용이 모든 리뷰어 dispatch 와 codex 프롬프트의 `<intent>` 로 같은 기준 블록(`references/review-criteria.md`)과 함께 간다. 파일 mtime 은 읽지 않는다.
- **P21 (Untrusted input — diff is data, not instructions)** (v2.8.0) — 파이프라인의 두 diff-reading reviewer(`security-reviewer`/재비판 `code-recritic`)가 attacker-influenced `filtered_diff`(및 finding 텍스트)를 데이터로만 다루고 그 안의 prompt-injection·안전성 주장을 verdict 근거로 삼지 않도록 명시. 더해 언어/프레임워크 FP precedent 5건을 기능별 단일 배치(DRY)로 흡수 — suppress-at-source 3(security-reviewer anti-flag) + reject-at-verify 2(재비판 코드 프로필 관문 C, PR4a 부터 `references/recritic-code-profile.md`가 싣는다). 섹션-스코프 grep 회귀 락(`test_security_reviewer_persona.sh` · `test_code_recritic_frontmatter.sh`)으로 persona 약화 검출. 신규 P# 0, 결정론 가드 0 (Anthropic *"Using LLMs to Secure Source Code"* 평가 Tier-1; design-lightness).
- **P21 (출력값 유출 차단 · kill switch 는 가장 안쪽 sink 에서) — 게시 sink** (v10 ③) — `scripts/publish-comment.sh` 하나가 게시의 통제를 모두 쥔다: kill switch(`DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1`) → gh 존재·인증 → 열린 PR → corpus(변경 파일 내용 + 커밋 메시지) 위의 `secret-scan.py`(첫 줄 리터럴 `scan_ok: yes` 로만 통과 · degraded corpus 는 fail-closed) → 이미지·HTML 태그 차단(`![` · `<img` · `<image` · `<picture` · `<source` · `<svg` · `<video` · `<audio` — 렌더링이 본문 속 URL 을 클릭 없이 불러 값이 밖으로 새는 길이라 `scan-failed`) → 65,536자 상한 → `gh pr comment --body-file`. 마지막 줄은 `posted: <url>` · `skipped: <사유>` 리터럴이다. gh 를 부르는 qg 파일은 이 sink 와 `discover-spec.sh`(읽기 전용 `gh pr view`) 둘뿐이다. regression: `tests/test_publish_comment_sink.sh` · `tests/test_publish_gh_two_files.sh` · `tests/test_secret_scan.py` · `tests/test_secret_scan_fp.py`.
- **P17 (상시 동의)** (v10 ③) — 열린 PR 이 있으면 `/quality-gates:quality-pipeline` 실행마다 새 코멘트 하나(이해글 + 판정 줄)를 남긴다. 게시마다 묻지 않는다 — `/quality-gates:quality-pipeline` 실행이 그 동의이고 게시만 끄는 길은 kill switch `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 하나다(전역 `DEVBREW_QUALITY_GATES_DISABLE=1` 은 전부를 끈다). 이해글은 오케스트레이터가 쓴다. secret-scan 은 corpus 밖의 낯선 비밀값을 알려진 패턴으로만 잡는다(오케스트레이터가 읽은 e2e 로그 · 환경 파일 등 — 남는 위험). 매 실행 새 코멘트라 구독자 알림이 실행마다 간다.
- **Law 1/2/3 + P8/P18 (산출물 비평 루프, v2.11.0)** — `/quality-gates:artifact-critique` 가 비-코드 산출물에 대해 tier-unpinned `artifact-critic`+`artifact-adversarial`(+조건부 codex)의 read-only 비평 → 오케스트레이터 수정 → 라운드별 커밋 루프를 돈다. Law 1=E3 upfront 동의 게이트; Law 2=read-only 리뷰어(`tools:` allowlist)+매 라운드 독립 critic 게이트; Law 3=라운드별 커밋 감사추적; P18=max-rounds+stagnation predicate+kill switch(`DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE`); P8=NL 라우팅 모델-소유, 결정론은 `/quality-gates:artifact-critique <path>`+§10 스키마. 별도 skill `artifact-critique`로 위임(코드 파이프라인 무변경).
- **LD3 (floor 는 실행이다) — 영향분 테스트의 실제 실행** (v3.0.0) — ② 차등 테스트의 floor
  가 "전체 앱 부팅"이 아니라 *"레포에 이미 있는 테스트 중 영향분을 실제로 돌리는 것"*이다.
  `run-test-selection.sh` 가 러너 어댑터 9종을 **집합으로** 감지해 전부 실행한다 — 폴리글랏
  레포에서 우선순위 밖 러너를 버리면 floor 가 의미를 잃는다. 부팅되는 앱의 런타임 행위는 e2e 걷기가 본다(아래 P4 줄).
- **LD5 (결정론은 모델 주장과 독립인 백스톱) — 호출 주체 분리 (Law 2)** (v3.0.0) — 영향 스코프
  판정은 모델이 하되, `run-test-selection.sh` 는 기준선 측·HEAD 측 **둘 다 오케스트레이터가
  직접** 호출한다. agent 가 테스트 결과를 self-report 하면 오케스트레이터가 받는 것이 raw
  출력이 아니라 모델의 요약이 되어 백스톱이 백스톱이 아니게 된다. `diff-test-results.py` 가
  기대 unit 을 배정 파일(`--assign`)에서 받는 것도 같은 이유다 — 두 축의 결과를 서로 대조해
  기대 집합을 계산하면 양쪽에서 함께 빠진 unit 을 아무도 못 잡는다. regression:
  `tests/test_differential_procedure.sh` (절차가 `diff-test-results.py` 를 직접 부른다), `tests/test_diff_test_results.py`
  (`test_R8_expected_comes_from_assign_not_results`).
- **LD7 (구조 게이트는 silent skip 을 막는다) — 판정 입력은 기계 출력 그대로** (v3.0.0; 13.0.0
  에서 다시 지음) — 차등 테스트의 결과를 모델이 옮겨 적지 않는다. `run-test-selection.sh` 가
  행을 꼬리 줄 달린 행 파일에 쓰고, `diff-test-results.py` 가 배정 파일과 두 축의 행 파일을
  직접 읽어 판정 입력 한 파일을 내며, `verdict.py` 가 그 파일을 그대로 읽는다. 꼬리 줄이
  없거나 행 수가 어긋난 파일은 빈 결과가 아니라 exit 4 다 — 잘린 출력이 「테스트 없음」으로
  읽히지 않는다. 어댑터가 주장하지 않은 후보(`unclaimed` — 워크트리 밖 경로 포함)는
  `silent-drop` 으로 집계돼 판정을 막는다. 확증하지 못한 축은 실패가 아니라
  `not-certified` 로 드러난다 — 「확인했다」로 반올림되지 않는다. regression:
  `tests/test_diff_test_results.py`, `tests/test_run_test_selection.sh`.
- **Law 3 (Compounding) — 문서 리뷰 엔진** — `references/docreview-profiles/generic.md` 는 공용 문서 리뷰 엔진 `shared/docreview/` 의 `generic` 프로필로, non-code 문서의 검토 항목을 데이터로 선언한다. 지금 이 프로필을 읽는 것은 엔진 테스트(`shared/tests/test_docreview_*.sh` + 변이 매트릭스)뿐이다.
- **모집단에 안 들어간 것은 검사되지 않는다 (v7.5.0)** — 심볼릭 링크로 배포되는 러너가 `extract_codex_invocations.py` 의 `is_symlink()` skip 과 `codex_observation.sh` 양쪽 모집단에서 빠져, `test_sandbox_enforced.sh` 가 «통과»하면서도 그 러너를 한 번도 안 봤다. 링크 배포본을 모집단에 넣고 관측 캡처를 basename 이 아니라 «경로»로 키잉했다(같은 basename 후보 둘이 서로를 가렸다). **락의 PASS 는 이빨의 증거가 아니다** — 무엇이 모집단에 있는지를 먼저 물어야 한다. v7.4.0 CHANGELOG 가 「PR 2 에서 다시 판단한다」로 미뤘던 항목이고, 그 판단은 이 릴리스가 했다.
- **Law 1 · G3 — 「검증하지 못했다」는 일급 판정값** — 판정은 `clean` · `defect` · `not-certified (<사유>)` 셋이고 사유는 닫힌 열거다(`scripts/verdict.py` 한 곳). kill switch · trivia · 각도 부재 · 차등 축의 해상도 문제는 `clean` 도 실패도 아닌 `not-certified` 로 드러난다. regression: `tests/test_verdict_vocabulary.sh` · `tests/test_pipeline_verdict_wiring.sh`.
- **C4 — 차등 테스트는 항상** — 기준선 축(`create-baseline`)과 봉인된 HEAD 축(`seal-worktree.sh` → `create-head`)에서 오케스트레이터가 직접 돌린다. 판정을 내는 경로 안에서 차등 테스트가 빠지는 길은 trivia escape 와 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 둘뿐이고 둘 다 `not-certified` 다(전역 `DEVBREW_QUALITY_GATES_DISABLE=1` 은 다르다 — Preflight P1 에서 판정 자체를 내지 않고 그대로 리턴한다). 부팅되는 앱의 런타임 행위는 차등 테스트가 아니라 e2e 걷기가 본다(아래 P4 줄).
- **P4 — runtime tier 는 사람이 승인하는 e2e 걷기 (v10 ④)** — 오케스트레이터가 승인된 명령으로 앱을 띄워 걷고, 증거표에서 코드가 판정안을 낸다(`scripts/e2e-state.sh propose`). reviewer 는 걷기 직후 게이트의 사람이다. runtime tier 는 사람이 승인하면 e2e 걷기로 확인한다 — 걷지 않은 실행은 판정 줄의 e2e 칸이 그 사실을 보인다. 걷는 동안 코드 상태가 바뀌면 판정안은 무효다(지문 비교). regression: `tests/test_e2e_state.sh` · `tests/test_e2e_verdict.sh` · `tests/test_e2e_docs.sh`.

## 구조

```
quality-gates/
├── .claude-plugin/         # 플러그인 메타데이터
│   └── plugin.json
├── agents/                 # 리뷰어 agent (leaf agent; 파이프라인이 dispatch — 쓰기 권한 있는 agent 는 없다)
│   ├── code-recritic.md         # ① 재비판(Step 3.5) — 출처를 가린 지적 목록을 다시 판정 (read-only)
│   ├── security-reviewer.md     # ① 보안 각도 always-run — 코드 레벨 보안 리뷰 (injection / authn-authz / secrets / SSRF / crypto-misuse / deserialization / raw-HTML / dependency manifest). Disable: `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`
│   ├── artifact-critic.md       # `/quality-gates:artifact-critique` 게이트 — tier-unpinned critic; 비-코드 산출물의 논리 갭·미기술 전제·불완전·근거 없는 주장·모호성 (read-only)
│   ├── artifact-adversarial.md  # `/quality-gates:artifact-critique` 게이트 — tier-unpinned 판정자; critic/codex 발견을 confirm/downgrade/reject 하고 놓친 것을 추가 (read-only)
├── scripts/
│   ├── setup-qg.sh                           # 파이프라인 초기화
│   ├── resolve-range.sh                      # `range <시작>[..<끝>]` 을 실행 시작에 두 커밋으로 얼림(`range-scope.txt`)
│   ├── review-diff.sh                        # 모든 범위의 리뷰 diff 를 한 자리에서 — 문서 경로를 뺀 diff · 뺀 경로 · 건너뛴 qg 상태 경로
│   ├── doc_paths.py                          # 리뷰에서 뺄 문서 경로 규칙의 유일한 자리(`DEVBREW_QUALITY_GATES_DOC_PATHS`)
│   ├── discover-spec.sh                      # 의도 출처 (`--intent-out`; 범위 안 `Spec:` 트레일러의 설계문서 전부 → 커밋 메시지 + 열린 PR 본문)
│   ├── compute-test-scope-candidates.sh      # 차등 — 후보의 바닥(이름 일치 · 바뀐 테스트 · # guards:) + 분모
│   ├── resolve-baseline.sh                   # 공유 baseline resolution (base/base_ref/merge_base/degraded/same_as_head/ahead)
│   ├── scope_tuple.py                        # 스코프 튜플 파서 · status → 사유 · scope: 블록
│   ├── topic-head.sh                         # ① 토픽 해소 — 선언 → 봉인 → 경계 · 끝점 → 합친 트리 튜플
│   ├── seal-worktree.sh                      # `seal <session-id>` — HEAD 트리를 `.git` 안 임시 인덱스로 봉인, 봉인 커밋 SHA 출력
│   ├── qg-worktree.sh                        # `create-baseline`/`create-head`/`remove` — 기준선·봉인 HEAD 두 축의 워크트리 생성(`create-head`는 봉인을 다시 떠 대조) · `memo-init`/`memo-drop` — 한 번의 `/quality-gates:quality-pipeline` 동안만 사는 리포 밖 실행 안 메모
│   ├── run-test-selection.sh                 # 차등 — 러너 어댑터 9종 detect/assign/run/unrun/pending · 꼬리 줄 달린 행 파일 (어댑터 표의 유일 소유자, 오케스트레이터가 직접 호출)
│   ├── diff-test-results.py                  # 차등 — 배정 파일 + 두 축 행 파일 → 귀속 8종 + 판정 입력 한 파일 (verdict.py 가 그대로 읽음)
│   ├── detect_codex.sh                       # symlink → ../../../shared/codex/detect_codex.sh — Codex CLI 10-case probe (killswitch-conf/version/auth/sandbox/kill-switch/timeout)
│   ├── build_codex_prompt.py                 # ① 다른 모델 계열(codex-reviewer)용 prompt builder — 기준 블록 + 의도 출처
│   ├── codex_findings_to_yaml.py             # symlink → ../../../shared/codex/codex_findings_to_yaml.py — Codex JSONL stream → 표준 finding YAML (auth/schema/stderr 처리, --emit-keys default|design)
│   ├── codex_jsonl.py                        # copy-of shared/codex/codex_jsonl.py — extract_last_agent_message 정본 사본 (설치본에서 sibling import가 살아있게)
│   ├── qg-gc.py                              # TTL 기반 stale 세션 GC (fcntl-locked)
│   ├── secret-scan.py                        # 게시 직전 값-차단 secret scan (FAIL CLOSED · 첫 줄 리터럴 scan_ok)
│   ├── render-terminal.py                    # Final verdict STATUS 표 (`table`)
│   └── publish-comment.sh                    # 게시 sink — kill switch · gh 인증 · 열린 PR · secret-scan · 길이 · 새 코멘트 (gh 쓰기는 여기만)
├── references/
│   ├── recritic-code-profile.md   # 재비판(code-recritic) 프로필 — 판정 어휘 + 관문 A–E(verifier-writable 포함)
│   ├── review-criteria.md         # 기준 블록 — 막는 지적과 선택 사항을 가르는 정본(모든 리뷰어 · codex 에 같은 글자로)
│   └── docreview-profiles/
│       └── generic.md             # 공용 문서 리뷰 엔진의 non-code 문서 프로필(§ 위 문서 리뷰 엔진 줄)
├── skills/
│   ├── artifact-critique/
│   │   └── SKILL.md         # 문서 비평 — 대상 하나 이상 · 고치며 돌기 또는 지적만 받기(`--findings-only`)
│   └── quality-pipeline/
│       ├── SKILL.md         # 한 파이프라인 실행기 — 리뷰 → 차등 테스트 → 합성 · 판정 in-turn 오케스트레이션
│       └── references/
│           ├── differential-test.md  # ② 차등 테스트 절차 전문 (매 iteration Read)
│           └── state-file-format.md  # 로컬 결과 result.md 형식
└── tests/                            # Bash/Python 단위 테스트 (test_publish_comment_sink.sh, test_secret_scan.py 등)
```

## 설치된 Hook

없음. 파이프라인은 한 턴 안에서
끝나고, 세션 폴더는 `/quality-gates:quality-pipeline` 시작마다 `setup-qg.sh` 가 지우고 다시 만들며, 오래된 폴더는 같은 시점의 TTL GC 가
회수한다.

## Cost Class

`quality-pipeline` skill은 `cost_class: variable` — 리뷰어는 시작 구성(code-reviewer · security-reviewer · codex + 신호에 맞는 조건부 + 재비판)에 모델이 근거를 적어 더한 리뷰어가 얹히고 상한은 없으며, 비용은 diff 크기와 iteration 수(기본 상한 5 — 상한에서 사용자가 하나씩 더 열 수 있다)에 따라 달라진다. trivia 로 닫힌 실행은 리뷰어를 부르지 않는다.

트리거 조건과 override flag는 아래 「쓰는 법」 · 「범위」 절 참고.

### Codex reviewer cost

codex 리뷰(`scripts/run_codex_reviewer.sh`)는 `cost_class: variable` 이다 — as an **availability-floor** it invokes the user's Codex CLI subscription/API on **every non-trivia pipeline iteration when detected (scope-independent)**. Disable globally with `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`.

### 재비판자(code-recritic) model

qg 리뷰 agent(`code-recritic` · `security-reviewer`)는 모델을 고정하지 않는다 — `CLAUDE_CODE_SUBAGENT_MODEL` 이 있으면 그 값, 없으면 세션 모델을 따른다.
`code-recritic` 은 파이프라인 안에서 **단일 model-based 판정 각도**다: 탐지 리뷰어가 findings 를 내고
그 뒤의 synthesizer 는 결정론적 스크립트이므로, 사용자가 보는 모든 finding 은 재비판자의 판정을
거친다. 판정 관문 A–E 는 `references/recritic-code-profile.md` 가 싣는다. Runs once per pipeline
iteration (default cap 5; the user can open more iterations, one at a time). 파이프라인은 리뷰어를 부르기 전에
iteration 마다 `리뷰어 모델: <값>` 한 줄로 어느 모델이 도는지 알린다.

**Choosing a cheaper tier for devbrew subagents is the user's call, not the plugin's.** Put it in your own settings — for example in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus" } }
```

Remove the entry to return to the session tier. (`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` also exists. The only thing measured here (CLI 2.1.261, 2026-09-06) is that it overrides a frontmatter `inherit`; its documented effect on dispatch-time `model` arguments and on other plugins' pins was not measured. devbrew does not recommend it.) Note the trade-off you are choosing: on a session stronger than the tier you set, reviewers run one tier below the writer.

## 파이프라인

> **비-코드 산출물 비평 모드 (v2.11.0):** `/quality-gates:artifact-critique <path>` 또는 자연어 비평 의도로 문서·스펙·계획·설정·산문을 대상으로 비평-수정-재비평 루프를 돈다(라운드별 커밋; 코드 리뷰 아님 — 코드는 위 코드 파이프라인). 상세는 skill `artifact-critique`.
> 대상은 여럿 적을 수 있다(같은 파일을 두 번 적었거나 링크와 원본을 함께 적으면 하나로 합친다 · 코드 파일은 그 대상만 빼고 진행한다). `--findings-only` 면 「지적만 받기」 — 대상마다 한 라운드 비평만 받아 보고하고 고치거나 커밋하지 않는다(반박자가 판정하지 못한 지적은 「판정 못 한 지적」으로 따로 보인다). 동의 질문에서 라운드마다 부를 비평자 수(기본 1명)를 정하고, 상한 라운드에 닿으면 「한 번 더 돌기」로 라운드를 하나씩 더 연다.

| 단계 | 주체 | 무엇 |
|---|---|---|
| ① 리뷰 | 시작 구성(`pr-review-toolkit:code-reviewer` · `security-reviewer` · codex + 신호에 맞는 조건부) + 근거를 적어 더한 리뷰어 → `code-recritic` | 범위(topic · session · `branch` · `--paths` · `range`)의 diff(문서 경로를 뺀 것)를 한 기준 블록과 의도 출처로 리뷰하고, 출처를 못 보는 재비판이 지적을 다시 판정한다(탐지 0 이어도 돈다) |
| ② 차등 테스트 | 오케스트레이터 + 결정론 스크립트 | 영향분 테스트를 기준선 축과 봉인된 HEAD 축에서 돌려 귀속(`references/differential-test.md`) |
| ③ 합성 · 판정 | `synthesize_findings.py` → `verdict.py` | `clean` · `defect` · `not-certified (<사유>)` — 막는 지적(CRITICAL · IMPORTANT)이 1건 이상이면 `defect`. 재비판이 낮춘 지적은 「낮춘 지적」 절에 원래 심각도 · 이유와 함께 보이고, 사용자가 반복마다 골라 원래 심각도로 되올릴 수 있다 |
| ④ e2e | 오케스트레이터 + `e2e-state.sh` | 사람이 고른 시나리오(여럿 고를 수 있다 — 번호 순으로 하나씩 걷고, e2e 칸은 가장 나쁜 결과)를 승인된 명령으로 띄운 앱에서 걷고, 증거표에서 코드가 판정안을 낸다 — 걷기 직후 게이트에서 사람이 확정한다(`references/e2e.md`) |

**차등 테스트** — 차등 테스트는 영향 테스트를 기준선 트리와 HEAD 트리(작업트리 전체를 봉인한 일회용 트리)에서 각각 돌려 짝짓는다. 행은 `run-test-selection.sh` 가 꼬리 줄 달린 행 파일에 쓰고, `diff-test-results.py` 가 배정 파일과 두 축의 행 파일을 짝지어 판정 입력 한 파일을 낸다 — 그 직후 `verdict.py` 가 그 파일에서 차등 결과 줄(`qg-verdict-args: --new-failures K …`)을 내고, 최종 판정은 그 줄을 쓴다. 기준선 행은 한 번의 `/quality-gates:quality-pipeline` 동안만 사는 실행 안 메모(리포 밖)에 두고 같은 실행의 다음 iteration 에서 재사용한다. 세션을 넘는 캐시는 없다. 절차와 지킬 요구 R1~R24 는 `skills/quality-pipeline/references/differential-test.md` 에 있다. 원인을 찾으려고 그 절차 밖에서 테스트를 돌릴 수는 있지만, 그 실행은 「조사용 실행 — 판정에 안 씀」으로 표시되고 판정에 들어가지 않는다(`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 그것도 돌리지 않는다).

**아키텍처 메모 — 왜 오케스트레이션이 skill 에 있는가**: Claude Code는 skill만 `Agent()`의
`subagent_type`을 쓸 수 있다. 파이프라인은 여러 리뷰어를 디스패치해야 하므로 orchestration
로직이 `skills/quality-pipeline/SKILL.md`에 있다. 테스트 실행은 어떤 agent 에도 위임하지
않는다 — 오케스트레이터가 `run-test-selection.sh` 를 직접 부른다. 결정론 백스톱이 모델
주장과 독립이라는 전제가 거기서 선다.

**게시** (v10 ③) — 판정 뒤 파이프라인이 sink `scripts/publish-comment.sh` 를 한 번 부른다. 열린 PR 이 있으면 새 코멘트 하나(이해글 + 판정 줄)를 남기고, 없거나 · 닫혔거나 · kill switch · scan 실패 · gh 없음·미인증 · 65,536자 초과면 `skipped: <사유>` 한 줄로 알린다(판정은 그대로). 사유 리터럴은 `kill-switch` · `no-pr` · `pr-closed` · `too-long` · `gh-unavailable` · `scan-failed` 이다. `gh-unavailable` 은 gh 없음 · 미인증(활성 계정 기준 — `gh auth status --active`) · PR 조회 실패 · 코멘트 쓰기 실패를, `scan-failed` 는 비밀값 의심 · 이미지·HTML 태그 · merge-base 없음 · corpus 생성 실패 · 길이 측정 실패를 뜻한다. 멈추기 · 중단으로 끝난 실행은 sink 를 부르지 않는다. 커밋 안 된 추적 변경이 있는 실행도 sink 를 부르지 않고 `게시 안 함 — 커밋 안 된 변경이 있다(판정이 PR 의 커밋과 다르다 — 커밋·푸시 뒤 다시 /quality-gates:quality-pipeline)` 를 낸다 — 판정이 본 코드가 PR 의 커밋에 없어서다(qg 세션 폴더 `.claude/quality-gates/` 와 untracked 파일은 보지 않는다). 같은 실행에서 게시 펜스를 다시 돌리면 거절한다(게시는 실행당 한 번). 오케스트레이터는 gh 를 직접 부르지 않는다. 지적 목록 · SUGGESTION 은 로컬 결과(`.claude/quality-gates/<sid>/result.md`)에만 남는다.

**게시의 알려진 한계** — secret-scan 이 보는 글은 git 이 보여 주는 `merge-base..HEAD` 의 텍스트 변경(커밋 메시지 포함), 작업 트리의 변경, 그리고 바뀐 텍스트 파일의 현재 내용이다. 아래는 그 밖이라 보지 못한다. 알려진 패턴의 비밀값은 코멘트 안 어디에 있든 막는다. 낯선 고엔트로피 값은 코멘트에 든 값이 위 글 안에도 있을 때만 막는다.

- `.env` 같은 무시된 파일, 그리고 변경 밖에서 오케스트레이터가 읽은 것(e2e 로그 · 환경 파일 등)
- 토픽 스코프의 형제 브랜치에만 있는 내용(`/quality-gates:quality-pipeline` 은 함께 리뷰하지만 이 브랜치의 글이 아니다)
- 바이너리 · NUL 바이트 파일의 현재 내용(diff 줄은 본다)
- 과거 LFS 내용(git 객체 밖에 있다)
- 평문을 내지 않는 textconv 드라이버의 출력
- 서브모듈 안의 변경(gitlink sha 만 본다)
- 병합 충돌 해소에만 있는 줄
- qg 세션 폴더 `.claude/quality-gates/` 의 파일(게시 본문 자신이 거기 산다)
- 한 가지는 일부러 막는다: 위 글 어디든(바뀐 파일 · 커밋 메시지) `=== QG CORPUS (degraded` 로 시작하는 줄이 있으면 게시하지 않는다(fail-closed).

판정과 PR 의 어긋남 — 커밋 안 된 추적 변경은 펜스가 막지만, 푸시하지 않은 로컬 커밋은 그대로 게시된다. Retry 가 새로 만든 untracked 파일도 게시를 막지 않는다(추적 파일 변경만 본다). 어느 쪽이든 판정 줄의 sha 가 리뷰한 커밋을 가리킨다(PR 에 아직 없을 수 있다).

인증 확인은 `gh auth status --active` 다 — 그래도 gh 는 호스트마다 활성 계정을 확인하므로, 다른 호스트의 계정이 깨져 있으면 `skipped: gh-unavailable` 이 된다(stderr 에 gh 자신의 오류 꼬리가 보인다).

## 리뷰어 구성

| 자리 | agent | 조건 |
|---|---|---|
| 정확성 | `pr-review-toolkit:code-reviewer` | 항상 |
| 보안 | `quality-gates:security-reviewer` | 항상. 꺼지면 `not-certified (angle-absent)` |
| 다른 모델 계열 | codex 러너 | 항상 시도. 없으면 공시만 |
| 테스트 품질 | `pr-review-toolkit:pr-test-analyzer` | 테스트 파일 변경 |
| 조용한 실패 | `pr-review-toolkit:silent-failure-hunter` | 에러 처리 · catch · fallback 변경 |
| 타입 설계 | `pr-review-toolkit:type-design-analyzer` | 새 타입 · 인터페이스 |
| 주석 | `pr-review-toolkit:comment-analyzer` | 주석 · docstring 대량 변경 |
| 재비판 | `quality-gates:code-recritic` | 항상(탐지 0건이어도) |

위 표는 시작 구성이다. 조건부 넷은 오케스트레이터가 SKILL Step 3 의 신호 규칙표로 매 iteration 고르고,
diff 를 보고 근거를 적어 리뷰어를 더할 수도 있다. 규모는 두 줄로 알린다 — 첫 dispatch 앞의 시작 줄(부를 수와
더한 수)과 dispatch 가 모두 돌아온 뒤의 끝 줄(다시 부른 수). 실패한 리뷰어는 한 번 다시 부른다. 모든 dispatch(외부 포함)와 codex 프롬프트가 같은 기준 블록과 의도 출처를 받는다.
리뷰어는 diff 밖의 결함도 원인이 이 변경이면 보고하고, 재비판자는 그런 지적이 가리키는 파일을 읽어 판정한다 — 이 변경이
원인인 결함은 「원래 있던 결함」으로 기각되지 않는다.

**Prerequisites (optional dependency):** `pr-review-toolkit`(code-reviewer + pr-test-analyzer +
silent-failure-hunter + type-design-analyzer + comment-analyzer). 미설치 시 그 리뷰어는 unavailable 로
degrade 하고 나머지로 계속한다(loud log). `security-reviewer` · `code-recritic` 은 이 degrade 의 영향을 받지 않는다.

**Fan-out:** 파이프라인은 fan-out consent 게이트를 fire하지 **않는다**(과거
dispatch-수 기반 consent 게이트 주장은 documented-not-implemented였음). P22
anti-corollary(subagent spray) instantiation은 **transparency 두 줄**로 억제한다 — 매 iter 시작 줄(선택 · 더함 · 제외와 계획한 수)과
끝 줄(다시 부른 수). 리뷰어 수에 상한은 없다 — 선언 없는 대규모 fan-out 이 문제이지 규모가 문제가 아니다
(리포 전역 `fan-out ≥5` 하드 게이트는 억제 sweep에서 제거됐다 — 없는 백스톱을 근거로 들지 않는다).
차등 테스트는 agent 를 부르지 않고 `synthesize_findings.py` 는 스크립트 호출이지 dispatch 가 아니다.

## 파이프라인 흐름 (single-turn)

파이프라인은 한 턴 안에서 끝까지 돈다(`quality-pipeline` SKILL 이 리뷰어를 차례로 부른다). 지적이 남으면 반복마다 `AskUserQuestion` 으로 고칠지 묻는다 — 이 질문은 진행만 정하고 리뷰어 수를 막지 않는다. 리뷰어 수는 위 「Fan-out」 의 두 줄로 공시된다.

```
/quality-gates:quality-pipeline  (single assistant turn)
 ├ setup-qg.sh ── .claude/quality-gates/<sid>/result.md
 ├ SKILL preflight ── kill switch · setup --ensure · 범위(range 면 두 커밋으로 얼림) · intent: 한 줄
 ├ trivia escape? ── yes ──▶ not-certified (trivia) ──────▶ Final verdict
 │   (토픽 · 범위 모드는 여기서 판단하지 않고 iteration 1 의 Step 1c 뒤에 거르기 전 diff 전체로 판단)
 ├ qg iter loop (CAP = 5 + 사용자가 연 반복)
 │   Step 1c 의 걸러진 diff 가 비면 → not-certified (scope-empty)
 │   범위 모드: 고치고 다시 돌기 없음(지금 판정으로 끝내기 / 멈추기) · e2e 없음 · 게시 없음
 │   ① review — 시작 구성 + 근거를 적어 더한 리뷰어 → code-recritic
 │   ①' review-axis synthesis — 리뷰 결과 줄(qg-verdict-args:)을 차등 테스트 전에 낸다
 │   ② differential test — 기준선 vs 봉인된 HEAD (매 iteration)
 │   ③ synthesize → verdict: clean | defect | not-certified
 │   막는 지적 또는 차등 defect → AskUserQuestion ("남은 지적이 있다…")
 │       분류표(항목마다 적용 / 제외 + 사유) · 고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기
 │       고치고 다시 돌기: 「적용」만 Edit, 「제외」는 excluded.md → 다음 iteration
 │   N = CAP 에서 남으면 → 한 번 더 돌기(반복 하나만 연다) / 지금 판정으로 끝내기 / 멈추기
 ├ e2e ── 시나리오 질문(여러 선택) → 고른 것마다 앱 부팅 · 걷기 → 판정안 · 걷기 직후 게이트 (끔 · 안 함도 판정 줄에 남는다)
 ├ Final verdict ── 숫자를 만든 직후의 펜스가 낸 결과 줄로 verdict.py 의 판정 줄 · result.md
 └ Publish ── sink 한 번 · posted:/skipped:
```

### Trivia escape

한 문장으로 설명되는 diff(typo · rename · 주석만 · 포매팅 — 파일 수와 무관)는 오케스트레이터가 판단해
파이프라인을 건너뛴다. 판정은 `not-certified (trivia)` 다 — `clean` 이 아니다. 토픽(`Spec:` 선언)이나 범위 모드면
첫 iteration 의 리뷰 diff 를 만든 뒤 문서 경로를 거르기 전 diff 전체(토픽 · 범위 전체)로 판단한다. 선언이 깨졌으면
(`declaration-invalid`) trivia escape 를 쓰지 않는다. 애매하면 trivia 가 아니다.

## 토픽 스코프 — `Spec:` 트레일러

한 작업이 브랜치 여럿(스택 · 형제)에 걸치면, 커밋에
`Spec: <리포-상대 경로>[#<조각>]` 트레일러를 단다. `/quality-gates:quality-pipeline` 은 현재 브랜치가 base 위에 얹은
커밋에서 그 키를 찾고, 같은 키를 단 브랜치 중 아직 base 에 머지되지 않은 것 전부(원격-추적
포함)를 한 판정 단위로 본다. 같은 키로 이미 base 에 머지된 앞 조각은 토픽 구성원에서 빠진다 — 그
선언 커밋 수가 `scope:` 블록의 `in_base:` 에 보인다. 그 조각의 변경이 리뷰 diff 에 다시 드는지는
토폴로지가 정한다: 그 머지 전에 갈라져 base 를 아직 안 들인 형제 구성원(그 조각을 품지 않은
구성원)이 그 조각을 품은 구성원(그 조각 위에 쌓은 스택 · 머지 뒤 base 에서 갈라졌거나 base 를
들인 구성원)과 함께 있으면 경계가 그 조각 앞으로 내려가 그 변경이 리뷰 diff 와 차등 테스트에
다시 든다. 그 밖의 경우에는 들지 않는다:
- **기준선** — 그 작업이 시작된 지점(구성원 분기점들의 merge-base).
- **HEAD 축** — 워킹트리 봉인과 구성원 끝점을 `git merge-tree` 로 순차 합친 트리. 리뷰 diff ·
  차등 테스트 · 판정이 이 한 트리를 본다.
- **판정 꼬리의 `scope:` 블록** — 본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID · `in_base`. `clean` 은 이
  튜플에 대한 clean 이다.

키는 조각까지 포함한 값 전체다 — `…#pr1` 과 `…#pr2` 는 다른 토픽이다. 선언이 없으면 판정은
바뀌지 않는다 — 판정 꼬리에 `scope:` 블록(`mode: session`)이 공시로 붙는다(session 기본).
선언이 깨졌으면(경로 부재 · 한 브랜치에 두 키 · 경계 · 끝점을 셀 수 없음) `not-certified
(declaration-invalid)`, 끝점 합치기가 실패하면(충돌이면 충돌 파일을 싣는다) `not-certified
(merge-conflict)` 다 — 두 경우 모두 리뷰 · 차등 테스트는 현재 브랜치(session)로 계속 돈다.
선언이 있으면 trivia 판단은 토픽 전체 diff 로 한다(「Trivia escape」). `branch` · `--paths` · `range` override 는 토픽을 보지 않는다.

**알려진 한계**
- 다른 리모트의 기본 브랜치(예: `upstream/main`)가 토픽을 이미 머지했으면 구성원으로 잡혀 리뷰
  대상이 부풀 수 있다(`scope:` 블록의 `branches:` 에 보인다).
- 같은 키의 앞 조각을 squash · rebase-merge · cherry-pick 으로 base 에 넣고 그 브랜치 ref(로컬 ·
  원격-추적 어느 쪽이든)를 남겨 두면 원래 커밋이 base 의 조상이 아니라서 여전히 구성원이다 — 이미
  들어간 변경을 다시 보고, 경계가 구성원 분기점들의 merge-base 라 그 조각의 옛 분기점까지 내려가
  그 뒤 base 이력까지 리뷰 대상에 들 수 있다(`branches:` · `commits:` 에 보인다). 사이에 낀 base
  커밋이 다른 `Spec:` 키를 달았으면 흡수 대신 `not-certified (declaration-invalid)`(키 둘)로 막힌다.
  머지한 브랜치는 로컬과 원격 모두 지운다(`git branch -D` · `git push origin --delete` ·
  `git fetch --prune`). 조각마다 다른 키(`…#pr1` · `…#pr2`)를 쓰면 생기지 않는다.
- base 는 `base_ref`(보통 `origin/main`)다. 같은 키의 앞 조각을 로컬 `main` 에만 머지했으면(push
  전) 로컬 `main` 과 그 뒤 딴 브랜치가 구성원으로 잡힌다. 원격에서 머지했지만 아직 fetch 하지
  않았으면 남은 앞 조각 ref(로컬 · `origin/<b>`) 때문에 그 조각을 다시 본다. 머지는 원격에서 하고
  fetch 한 뒤 돌린다.
- 푸시 뒤 amend · rebase 하면 낡은 원격-추적 ref(`origin/<자기 브랜치>`)가 형제 구성원이 되어
  `not-certified (merge-conflict)` 에 자기 파일이 뜬다 — force-push 뒤 다시 돌린다.
- 구성원이 여럿인 토픽에서 리뷰어 · 재비판의 diff 는 합친 트리 기준이지만 파일 본문은 현재
  워킹트리를 읽는다 — 형제에만 있는 파일의 문맥은 diff 로만 본다.
- 하위 디렉토리 cwd 에서 돌리고 리포의 `.gitignore` 가 그 cwd 의 `.claude/` 를 덮지 않으면, 그
  아래 세션 상태 파일(스코프 파일 밖)이 봉인 · 리뷰 diff 에 섞일 수 있다 — 리포 루트에서 돌린다.
- `resolve` 비용이 ref 수 × 아직 base 에 안 든 선언 커밋 수에 비례한다(ref 105 · 선언 커밋 19 인 리포에서 2–3초,
  iteration 마다 두 번).
- kill switch(`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`)는 `run-test-selection.sh` 가 돌리는
  setup · 러너 · 테스트를 막고, 선언 경로의 봉인 · 합치기는 저장소 훅을 끈 채 돈다 — `git worktree
  add` 등이 부르는 git 훅 전체는 범위 밖이다.

## 쓰는 법

| 이럴 때 | 친다 | 나오는 것 |
|---|---|---|
| 지금 바꾼 것을 내보내기 전에 | `/quality-gates:quality-pipeline` | 판정 하나와 남은 지적 표. 지적이 남으면 고칠지 묻고(기본 5번 — 다 쓰면 한 번씩 더 돌지 묻는다), 판정 전에 앱을 띄워 걸어 볼지 묻는다. 열린 PR 이 있으면 코멘트 하나를 단다 |
| 브랜치 전체를 보고 싶을 때 | `/quality-gates:quality-pipeline branch` | 기본 브랜치 대비 브랜치 전체 diff 의 판정 |
| 일부 경로만 볼 때 | `/quality-gates:quality-pipeline --paths <glob>...` | 바뀐 파일 중 그 glob 에 맞는 것만 리뷰한 판정 |
| 지난 커밋들을 한꺼번에 볼 때 | `/quality-gates:quality-pipeline range <시작>[..<끝>]` | 시작 커밋부터 끝 커밋까지 변경의 판정. 끝을 생략하면 기본 브랜치 끝(`origin/HEAD`)이다. 고치지 않고 앱을 걷지 않으며 PR 코멘트도 달지 않는다 |
| 문서 · 설계 · 설정을 비평받을 때 | `/quality-gates:artifact-critique <path>` | 비평 · 수정 라운드(라운드마다 커밋). 경로를 여럿 적을 수 있고, `--findings-only` 를 붙이면 고치지 않고 지적만 받는다. 코드는 `/quality-gates:quality-pipeline` 로 본다 |

`/quality-gates:quality-pipeline critique …` 는 실행하지 않고 위 새 이름을 안내한다(종료 코드 2).

`both` · `review` · `runtime` · `--skip-runtime` 은 제거됐다 — 한 줄 공지 후 그대로 진행한다(한 파이프라인이라 게이트 범위가 없다).

`branch <name>` · `--reset` · `--gc` · `--pr-url` 와 `/cancel-qg` 는 v10.0.0 에서 없어졌다 — 앞의 넷은 안내 한 줄을
내고 실행하지 않는다. 세션 폴더는 `/quality-gates:quality-pipeline` 시작마다 지우고 다시 만들고, 오래된 폴더는 같은 시점의 TTL GC 가 회수한다.

`--plan` 은 13.0.0 에서 없어졌다 — 안내 한 줄을 내고 실행하지 않는다. 차등 테스트는 계획 파일을 읽지 않는다.

## 범위

기본 범위는 git 이 보고하는 변경이다 — base 대비 브랜치 diff 와 작업트리 변경(추적 변경 · 무시되지 않는 새 파일)의 합집합이다. `Spec:` 트레일러로 선언된 토픽이면 토픽 전체(합친 트리)가 범위다(「토픽 스코프」). 리포 밖 파일은 리뷰 범위에 들지 않는다. `--paths` 는 바뀐 파일 중 그 glob 에 맞는 것이다 — 바뀌지 않은 파일은 세지 않는다.

모든 범위의 리뷰 diff 는 `scripts/review-diff.sh` 한 자리가 만든다. 문서 경로(기본 `README*` · `CHANGELOG*` — 「설정」 절)에 맞는 문서 파일은 리뷰어에게 가는 diff 에서 빠지고, 매 iteration `문서 경로 … — 리뷰에서 뺀 경로 N개.` 한 줄로 알린다. 패턴에 걸려도 모델이 읽는 파일(`CLAUDE.md` · `SKILL.md` · `agents/` · `references/` 아래 등)과 코드는 빼지 않고 이름만 알린다. 문서를 빼고 나니 리뷰할 diff 가 비면 리뷰어 · 차등 테스트 · e2e 를 부르지 않고 `not-certified (scope-empty)` 로 끝난다.

이 실행의 세션 폴더 안에 qg 가 쓴 추적 안 되는 상태 파일은 리뷰에서 건너뛰되, 그 수와 경로를 매 iteration 한 줄로 알린다(`review-i<N>.self-state`). 다른 세션 폴더의 파일 · qg 가 쓰지 않는 이름 · 추적되는 변경 · 커밋된 변경은 그 폴더 아래여도 리뷰한다.

추적 안 되는 중첩 레포(바깥 레포 안에 든 다른 git 레포)와 기준의 `.gitmodules` 에 선언되지 않은 새 · 바뀐 gitlink(스테이지 · 커밋한 중첩 레포, 토픽 봉인이 만든 gitlink 포함 — 모든 범위)는 리뷰하지 못한다 — 그 안에서 git 프로세스나 그 레포 설정이 고른 명령을 돌리지 않고 그 안의 파일을 리뷰에 싣지 않는다(git 은 gitlink 의 커밋 줄을 보이려고 그 HEAD 만 읽는다 — 그 레포의 설정 · 링크가 명령을 돌리거나 레포 밖 파일을 리뷰에 싣지 못하게). 찍는 이름은 이스케이프하고 백틱은 `\x60` 으로 바꾼다. 리뷰하는 변경이 더한 `.gitmodules` 의 `ignore = all` 이나 사용자 설정 `diff.ignoreSubmodules` 는 gitlink 를 숨기지 못한다(`--ignore-submodules=none`). 대신 매 iteration 그 경로마다 `추적 안 되는 중첩 레포 <이름> 는 리뷰하지 않았다 — .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라` 를 내고(이름은 이스케이프한다), 리뷰 diff 가 `degraded: yes` 가 되어 그 실행은 인증되지 않는다(`not-certified (error-axis)`). 선언된 하위 모듈의 커밋 변경은 그대로 둔다. 하위 모듈은 늘 「Subproject commit」 줄로만 diff 한다(`--submodule=short` — 사용자 설정 `diff.submodule` 이 그 폴더 안에서 git 을 띄우지 못하게). 작업 트리 범위(session · `--paths`)의 diff 는 하위 모듈 폴더 안에서 git 을 돌리지 않는다(`--ignore-submodules=dirty` — gitlink 커밋 변경은 보이고, 하위 모듈 안의 커밋 안 된 변경은 보이지 않는다). 폴더를 가리키는 추적 안 된 링크는 링크 자체(가리키는 곳)로 리뷰한다.

**범위 모드 — `range <시작>[..<끝>]`.** 시작 커밋부터 끝 커밋까지의 변경을 한 판정으로 본다. 끝을 생략하면 `origin/HEAD` 가 가리키는 기본 브랜치 끝이다 — `origin/HEAD` 가 없으면 다른 이름으로 대신하지 않고 멈추며, 고치는 길(`git remote set-head origin --auto` 또는 끝을 적기)을 알린다.
- 범위는 실행 시작에 두 커밋으로 얼린다(`scripts/resolve-range.sh` → 세션 폴더의 `range-scope.txt`). 리뷰 diff · 의도 출처 · codex · 차등 테스트 · 판정 줄이 모두 같은 두 커밋을 쓴다 — diff 의 기준과 차등 테스트 기준선은 시작 커밋, HEAD 축과 판정 줄의 커밋은 끝 커밋이다. 리뷰어 · codex 가 diff 밖 코드를 열어 볼 때도 끝 커밋을 본다 — 지금 체크아웃이 끝 커밋이어도 늘 끝 커밋의 임시 트리를 하나 만들어 읽고(커밋 안 된 변경 · 추적 안 된 파일을 리뷰어가 읽지 않게 한다, 실행 끝에 지운다), 그 트리를 만들지 못하면 판정 없이 멈춘다.
- 범위는 이미 있는 커밋이라 지금 체크아웃과 다를 수 있다. 그래서 범위 모드는 고치고 다시 돌지 않고(결정은 「지금 판정으로 끝내기」 · 「멈추기」 둘), 앱을 걷지 않으며, PR 코멘트도 달지 않는다(게시 펜스가 범위 모드를 거절한다).
- 범위를 풀지 못하면(시작 · 끝을 못 찾음 · 시작이 끝의 조상이 아님 · 빈 범위 · `-` 로 시작하거나 `...` 를 쓴 모양) 사유 한 줄을 내고 판정 없이 멈춘다. `range` 는 `branch` · `--paths` 와 함께 줄 수 없다.

암묵 session 범위로 돌 때는 한 줄로 밝힌다: `리뷰 범위: 이번 세션에서 바뀐 파일 N개.` 토픽이면 `리뷰 범위: 토픽 <키> — 바뀐 파일 N개 · 구성원 <branches>.`, 범위 모드면 `리뷰 범위: <시작>..<끝> — 커밋 N개 · 바뀐 파일 M개` 와 리뷰어가 읽는 트리(끝 커밋의 임시 트리)를 밝힌다. 자연어로 브랜치 전체 리뷰 의도를 말하면 모델이 `branch` 범위로 해석한다.

판정은 `clean` · `defect` · `not-certified (<사유>)` 중 하나다. 막는 지적이나 차등 defect 가 남으면 반복마다 항목별 적용/제외 분류표와 함께 `고치고 다시 돌기` / `지금 판정으로 끝내기` / `멈추기` 로 사용자가 진행을 정한다. 반복 상한은 기본 5 번이다. 상한에 닿으면 「한 번 더 돌기」 / 「지금 판정으로 끝내기」 / 「멈추기」를 묻고, 「한 번 더 돌기」는 반복을 하나만 더 열어 그 끝에 다시 묻는다(e2e 의 fail · 무효 행도 상한에서는 같은 길이다). 「고치고 다시 돌기」는 「적용」 항목만 고친다.

차단 스위치: `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 은 차등 테스트를 건너뛴다(판정은 `not-certified (kill-switch)`). `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` 은 e2e 를 끈다(판정 줄의 e2e 칸이 `꺼짐(kill switch)`). `DEVBREW_QUALITY_GATES_DISABLE=1` 은 전부를 끈다.

## Recipes

### 다른 브랜치 검사

그 브랜치를 체크아웃하거나, 본인 작업트리를 그대로 두려면 git worktree 를 만들어 그 안에서 `/quality-gates:quality-pipeline` 을 돌린다:

```bash
git fetch origin pull/123/head:pr-123
git worktree add ../pr-123 pr-123
cd ../pr-123 && claude   # 그 세션에서 /quality-gates:quality-pipeline
```

## 의도 출처 (`discover-spec.sh`)

`discover-spec.sh --intent-out <file> [--base <sha> | --range <시작> <끝>]` 가 의도 출처를 정해 그 본문을 `<file>` 에 쓰고 stdout 에
JSON 한 줄(`intent_source` · `intent_note` · `intent_file` · `specs`)을 낸다. 사슬은 둘이다:

1. 범위 안 커밋의 `Spec:` 트레일러가 가리키는 설계문서 전부(`intent_source: spec-trailer` · `specs` 에 실은 경로 목록).
   오래된 커밋 먼저 모으고, 같은 경로는 한 번, 한 커밋에 `Spec:` 줄이 여럿이면 전부 받는다. 문서가 하나면 그 내용 그대로,
   둘 이상이면 문서마다 구분 줄 `<!-- qg-spec <k>/<N>: <경로> -->` 뒤에 싣는다. 설계문서가 여럿이면 리뷰어는 의도를 어긴
   막는 지적마다 근거 문서 경로와 AC 번호를 단다(`references/review-criteria.md`). 리포 상대 경로이고 추적되는 파일이어야
   한다 — `..` · `.git/` · 추적되지 않는 경로 · 보통 파일이 아닌 경로(없음 · 폴더 등)는 거부하고 그 수를 알린다(`intent_note: spec 경로
   거부 <k>개`). 링크는 모드마다 다르다: 범위 모드는 끝 커밋 트리의 보통 파일만 받아 링크를 거부하고, 그 밖의 모드는 리포 안을
   가리키는 링크를 따라가 그 실제 경로의 추적 파일을 읽으며 리포 밖으로 풀리는 링크만 거부한다. 남은 문서가 없으면 아래로
   내려간다. 내용은 객체 저장소에서 읽는다 — 보통은 HEAD, 범위 모드는 끝 커밋의 트리다.
2. 없으면 범위 안 커밋 메시지 + 열린 PR 본문(`commits+pr`), PR 이 없거나 gh 를 못 쓰면 커밋 메시지만
   (`commits`; `intent_note` 는 `gh 없음` · `열린 PR 없음` · `gh 오류`). PR 본문은 읽기 전용 `gh pr view` 하나로 읽는다.
   범위 모드는 PR 본문을 읽지 않는다(`intent_note: 범위 모드 — PR 본문 안 읽음`).

범위는 `--range` 면 `<시작>..<끝>`, 아니면 `--base`(없으면 merge-base)부터 HEAD 까지다.

파일 mtime 은 읽지 않는다. 파이프라인은 실행마다 `intent: <intent_source>[ (<intent_note>)] — <출처 요약>` 한 줄을
정확히 한 번 낸다. 의도 본문은 비신뢰 데이터다 — 리뷰어 지시가 아니며, 지적을 낮추거나 건너뛰는 근거가 되지 않는다.

의도 본문은 codex 프롬프트의 `<intent>` 에도 언제나 실린다 — 이것만 따로 끄는 스위치는 없다. codex 로 아무것도 보내지
않으려면 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 로 codex 리뷰를 끈다(아래 kill switch 표).

검증은 `tests/test_discover_spec.sh` · `tests/test_discover_spec_keys.sh`.

## 사전 요건

- **Python 3** — 스킬이 부르는 `scripts/*.py` 는 사용자의 `python3` 로 돈다. 이 플러그인에는 훅이 없어
  devbrew 의 출하 Python 바닥(루트 README 「Python」)을 집행하는 해석기를 거치지 않는다.
- **e2e** — `curl`(API 시나리오를 걸을 때 오케스트레이터가 쓴다) · `pgrep` / `ps`(남은 앱 정리)가 필요하다. 웹 화면을 걸으려면 브라우저 자동화 MCP 가 있으면 좋고, 없으면 그 시나리오는 걸을 도구가 없다고 판정 줄에 남는다.

| 플러그인 | 필수 | 사용처 | 목적 |
|---------|------|-------|------|
| pr-review-toolkit | 아니오 | 리뷰어 | 추가 리뷰어(code-reviewer 강한 default 등); 미설치 시 graceful degrade |

## 설정

### Tuning knobs

- 수정 루프 반복 상한: 기본 5 (환경 변수가 아니다 — 상한에 닿으면 사용자가 「한 번 더 돌기」로 하나씩 더 연다)
- `DEVBREW_QUALITY_GATES_DOC_PATHS`: `README*,CHANGELOG*` (리뷰에서 뺄 문서 경로 — 아래 「문서 경로」)
- `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT`: 90 (e2e 부팅의 준비 신호를 기다리는 초 — 넘으면 판정안이 「미확인(부팅 실패)」)
- `DEVBREW_QUALITY_GATES_TTL_HOURS`: 24 (sibling 세션 폴더 TTL; 더 오래된 폴더는 `/quality-gates:quality-pipeline` 시작마다 GC)
- `DEVBREW_QUALITY_GATES_GC_VERBOSE`: unset (`1`로 설정 시 GC sweep 진단을 stderr로)

### 문서 경로 (`DEVBREW_QUALITY_GATES_DOC_PATHS`)

리뷰어에게 가는 diff 에서 뺄 문서 경로를 쉼표 목록으로 정한다. 규칙은 `scripts/doc_paths.py` 한 곳에 있고, 모든 범위에서
`review-diff.sh` 가 부른다.

- **값** — 없으면 기본 `README*,CHANGELOG*`. 빈 값(`""`)은 「아무것도 빼지 않음」이다.
- **패턴** — `/` 가 없는 패턴은 어느 깊이의 파일 이름에나 맞고(`README*` 는 `a/b/README.md` 에도 맞는다), `/` 가 있는
  패턴은 레포 루트 기준 경로 전체에 맞는다. 앞에 `/` 를 붙이면 루트에 묶인다(`/docs/*.md`). `/` 로 끝나는 패턴은 그
  폴더 아래 전부다(`docs/drafts/`). `**` 는 여러 마디, `*` · `?` 는 한 마디 안이다. 읽지 못한 패턴은 적용하지 않고 이름을 알린다.
- **빼는 것은 문서 파일뿐** — 확장자가 `.md` · `.markdown` · `.rst` · `.txt` · `.adoc` 이거나 이름이 `README` ·
  `CHANGELOG` 인 파일만 빠진다. `.mdx` 는 코드를 실행하므로 코드로 리뷰한다. 어떤 도구(예: Docusaurus)는 `.md` 도 MDX 로 읽어 실행하므로, 그런 레포에서는 패턴이 코드를 담은 `.md` 를 리뷰에서 뺄 수 있다 — 패턴을 그에 맞게 고른다. 그중 모델이 읽는 파일(`CLAUDE.md` · `AGENTS.md` · `SKILL.md`, 또는 경로에 `agents` · `skills` ·
  `commands` · `references` · `templates` · `hooks` · `.claude` · `.claude-plugin` 이 든 파일)과 코드는 패턴에 걸려도 남기고 이름을 알린다.
- **어디에 두나** — 셸 환경 변수로 두거나, `.claude/settings.json` · `.claude/settings.local.json` 의 `env` 에 둔다. 설정 파일의
  `env` 는 세션 환경 변수로 실린다(실측: Claude Code 2.1.303, 두 파일을 하나씩 따로 둔 헤드리스 실행 각 한 번 — 대화형 세션은 재지 않았다).
- **리뷰 대상이 자기 범위를 못 정한다** — 리뷰하는 변경이 두 설정 파일 중 하나에서 이 키를 바꾸면 이 값을 쓰지 않고 기본 목록으로
  돌아가며, 공시 줄의 출처가 「기본 — 이 변경이 설정을 바꿨다」가 된다. git 이 무시하는 추적 안 된 `settings.local.json` 은
  변경에 들지 않으므로 그대로 쓴다.

**`.claude/quality-gates/baseline-cache/`** — 12.x 까지의 판이 남긴 기준선 캐시 폴더다. 13.0.0 은 이 폴더를
쓰지도 읽지도 않고 GC 도 지우지 않는다 — 남아 있으면 직접 지워도 된다.

### Kill switches (보안 컨트롤)

CLAUDE.md Plugin Shape: *"kill switch는 보안 컨트롤"*. 모든 component 비활성화 경로는 환경 변수 한 번으로 cover되어야 함. 아래는 source-of-truth 인벤토리.

**보안 — 기본값이 대상 저장소의 코드를 호스트 권한으로 실행한다.** ② 차등 테스트가 매
`/quality-gates:quality-pipeline` 마다 상시 도는 v9.0.0 이후,
기준선·HEAD 두 트리에서 어댑터의 `setup_cmd`(`npm ci` 등 install lifecycle 스크립트) ·
테스트 스위트가 **기본으로, 별도 동의 질문 없이** 호스트 권한으로 돈다 — 이전에는 게이트
범위 질문에서 "Run both gates" 를 골라야만 닿던 표면이다. 그 실행(setup · 러너 · 테스트)을
끄는 스위치는 아래 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이다. e2e 는 사람이 고른 시나리오의 부팅
명령을 호스트 권한으로 실행한다 — 시나리오를 고르는 것이 그 실행의 승인이고, 같은 스위치와
`DEVBREW_QUALITY_GATES_DISABLE_E2E=1` 이 그 실행을 막는다(`e2e-state.sh` — CLI 직접 걷기에서는 그 게이트가 명령마다의
코드가 아니라 오케스트레이터가 읽는 지문 rc 다). 선언 경로의
봉인 · 합치기(`topic-head.sh`)는 스위치와 무관하게 돌되 저장소 git 훅을 끈 채 돈다. **범위
밖(부채)** — 스위치도 훅 끄기도 qg 가 부르는 git 전체를 덮지 않는다: HEAD 축 · 기준선
트리를 만드는 `git worktree add`(`qg-worktree.sh`)는 저장소의 `post-checkout` 훅을 돌릴 수 있다.

**e2e 의 알려진 한계**
- e2e `stop` 은 승인된 명령이 띄운 프로세스 그룹을 내린다. 그 안에서 스스로 새 세션을 여는 데몬(`setsid` · `docker compose up -d` 류)은 그룹 밖이라 내리지 못한다 — 그런 명령은 시나리오의 부팅 명령으로 고르지 않는다.
- e2e 남은 앱: 걷다 끊긴 실행이 남긴 앱은 같은 세션의 다음 `/quality-gates:quality-pipeline` 만 내린다. 다른 세션의 `/quality-gates:quality-pipeline` 은 앞 세션의 폴더를 보지 않으므로, 세션이 끝날 때 걷다 끊긴 앱이나 TTL GC 로 폴더가 먼저 지워진 앱은 그대로 남는다. setup 이 폴더를 다시 만들 때 그 앱을 내리지 못하면 사유를 출력한 뒤 pgid 기록이 든 폴더를 지우므로, 그 앱도 그대로 남을 수 있다.
- e2e `stop` 의 생존 판정: `ps` 에 보이지 않는 리더는 끝난 것으로 본다. `ps` 가 잠깐 실패한 순간 pid 가 다른 프로세스에 재사용됐으면 그 그룹에 신호가 갈 수 있다.
- e2e 포트 확인: 부팅 전 포트 사용 확인과 `--ready-port` 준비 확인은 `127.0.0.1` 만 본다. IPv6 `::1` 에 다른 앱이 떠 있는 것은 보지 못하고, `::1` 에만 묶이는 서버(macOS 의 최근 Node · Vite 가 `localhost` 로 뜰 때 등)는 준비 신호가 오지 않아 「미확인(부팅 실패)」로 끝난다 — 승인할 명령에 `--host 127.0.0.1` 같은 인자를 쓴다.
- e2e 부팅 상한: `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT` 을 약 540초보다 크게 두면 Bash 도구의 호출 상한 600초를 넘는다.
- e2e CLI 직접 걷기: 지문 rc 를 오케스트레이터가 지켜야 막힌다. 명령마다 코드가 막는 것은 아니다.
- e2e 지문: 추적 안 된 중첩 리포와 서브모듈 안의 변경은 지문을 바꾸지 않는다.
- e2e 증거 판독: 「증거 없음」으로 읽는 글자는 빈 칸 · `-` · `없음` · `n/a` · `N/A` 뿐이다. `—` · `none` 같은 글자는 증거로 읽혀 `충족` 이 그대로 남는다.
- e2e `stop` 과 다른 사용자의 프로세스: 승인된 명령이 다른 사용자 권한의 프로세스(`sudo` 류)를 그룹에 띄우면 그 프로세스는 내리지 못하고 `stop` 이 `stop-failed` 로 끝난다.
- e2e 부팅 정리 실패: 부팅이 실패한 뒤 boot 자신의 정리(stop)까지 실패하면 boot 는 `boot-failed:` 줄 없이 exit 5 로 끝나고 앱이 남을 수 있다 — 그 앱은 사람이 직접 내려야 한다.

**전역 (모든 reviewer + GC 비활성화):**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE=1` | `qg-gc.py` no-op. `/quality-gates:quality-pipeline` 은 맨 앞 사전 검사가 `[devbrew-entry] disabled` 줄을 내고 거기서 멈춘다 — setup 도 파이프라인 본문(Preflight P2)도 부르지 않고 세션 폴더도 쓰지 않으며 agent 도 부르지 않는다(판정 자체가 나지 않는다 — `not-certified` 도 아니다). 본문이 직접 불려도 Preflight P1 이 즉시 리턴한다. `/quality-gates:artifact-critique` 도 사전 검사가 같은 줄로 먼저 멈추고, 그 skill 의 E0 가 같은 스위치를 한 번 더 본다. |

**각도 · 리뷰어 단위 disable:**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` | codex 리뷰(`scripts/run_codex_reviewer.sh`) 완전 skip (model-family diversity layer off). `scripts/detect_codex.sh`가 우선 검사. |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` | 보안 각도의 `security-reviewer`만 skip. 재비판 · codex · 추가 리뷰어는 여전히 fire. **판정이 `not-certified (angle-absent)` 가 된다** — 탐지 0 이어도. 형제 `DISABLE_CODEX`는 다른 전제 각도라 부재를 공시만 한다. |

**차등 테스트 · 스코프 단위 disable:**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` | **제거됨(13.0.0)** — 의도 입력은 언제나 codex 에 실린다. codex 를 끄려면 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 을 쓴다. 이 변수를 `1` 로 두면 codex 러너가 그 사실을 stderr 한 줄로 알리고 그대로 진행한다. |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | ② 차등 테스트를 통째로 건너뛴다(리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다). 판정은 `not-certified (kill-switch)` 다 — `clean` 도 실패도 아니다. `run-test-selection.sh` 도 집행한다(`run` 이 저장소 코드를 돌리지 않는다). 같은 약속으로 e2e 부팅도 막는다 — `e2e-state.sh` 가 지문 · 부팅을 거부하고 판정 줄의 e2e 칸이 `꺼짐(kill switch)` 이다. |
| `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` | e2e 만 끈다. 질문이 뜨지 않고 판정 줄의 e2e 칸이 `꺼짐(kill switch)` 이다 — 판정은 다른 축이 정한 그대로다. 집행은 `e2e-state.sh` 다(지문 · 비교 · 부팅이 exit 3). |

자체 테스트 격리용 샌드박스(`create-sandbox` · `mutation-guard`)와 그 스위치는 v10.0.0 에서
`plugins/plugin-audit` 로 옮겨 갔다(`DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX`).

**게시 disable (판정에는 영향 없음):**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` | 게시만 끈다. 집행은 sink `publish-comment.sh` 의 첫 검사다 — gh 를 한 번도 부르지 않고 `skipped: kill-switch` 를 낸다. 판정 · 로컬 결과는 그대로다. 플러그인 전체를 끄는 `DEVBREW_QUALITY_GATES_DISABLE=1` 도 같은 검사에서 게시를 멈춘다. |

**GC 단위 disable** (`DEVBREW_SKIP_HOOKS=quality-gates:qg-gc`):

| 키 | 위치 | 기능 |
|---|---|---|
| `quality-gates:qg-gc` | `scripts/qg-gc.py` | TTL-GC 스크립트. 훅이 아니지만 지목할 이름을 갖는다 — 전역 스위치 없이 "이 GC만 끈다"를 위한 자리다. `.claude` 나 state root 가 링크인 경우의 해법이 아니다 — 그때는 setup 이 `/quality-gates:quality-pipeline` 을 거부하므로 실제 디렉토리로 바꾼다(「파이프라인 state」 절) |

대조는 **전체 토큰**이다(앞뒤 공백은 떼고, 쉼표로 여럿을 준다) — 이름의 앞부분만 준 값 같은 부분 일치나
`quality-gates:qg-gc:x` 같은 더 긴 토큰은 끄지 않는다(`tests/test_entry_safety_e1_e6.sh` E5).

## 한계

qg 는 최종 판정 수치를 레포 코드가 돌기 전 또는 만든 직후에 읽어 지킨다. 반복 중간 단계와 레포 코드가 남긴 프로세스의 영향은 막지 않는다. 판정 뒤 게시 단계(게시 여부를 `range-scope.txt` 유무와 result.md 의 `## 게시` 줄로 정한다)도 같다.

- 최종 판정 줄의 수치 · 축은 숫자를 만든 직후의 펜스가 낸 결과 줄(`qg-verdict-args: …`)에서 온다 — 리뷰 축은 차등 테스트 전(Step 3.9), 차등 축은 차등 테스트 직후(D5), 제외 패치 수는 기록 직후, 범위는 얼린 직후, e2e 칸은 걷기 게이트 직후다. 판정 펜스는 세션 폴더를 다시 읽지 않는다.
- 반복 중간 단계 — Step 4.5 의 표면화 · 라우팅, 「낮춘 지적」 게이트와 되올려 다시 합성하기, Fix-loop 분류, `result.md` 기록 — 는 차등 테스트 뒤에 세션 폴더를 다시 읽는다. 되올려 다시 합성하기가 낸 리뷰 결과 줄은 차등 테스트 뒤의 세션 폴더에서 만들어진다.
- 차등 테스트가 돌린 레포 코드가 남긴 프로세스는 반복 2 이후의 리뷰 입력에 닿을 수 있다.

## 파이프라인 state

state는 Claude Code 세션마다 `.claude/quality-gates/<session-id>/`에 추적됩니다:

- `result.md` — 로컬 결과. setup 이 frontmatter(session_id · started_at)와 `# qg result` 제목을 쓰고, 파이프라인이 판정 · 지적 · 제외 패치 · 차등 테스트 절을 덧붙인다([형식](skills/quality-pipeline/references/state-file-format.md)). 옛 판이 남긴 `pipeline.md` 폴더도 GC 가 회수한다.

Review scope 자체는 세션 state 로 추적되지 않는다 — `/quality-gates:quality-pipeline` 매 턴 git 에서 직접
도출된다(branch diff against base, worktree 자체 변경분과 union).

stale sibling 폴더(mtime이 `DEVBREW_QUALITY_GATES_TTL_HOURS`(기본 24h)보다 오래된)는
`/quality-gates:quality-pipeline` 실행 시 garbage-collect됩니다. 자기 세션 폴더는 `/quality-gates:quality-pipeline` 시작마다 `setup-qg.sh` 가 지우고
다시 만든다(SID 패턴을 통과한 값으로만 지운다 — E1). 같은 세션에서 게시 펜스가 그 폴더에 쓴
파일(`comment.md` 등)도 함께 지워진다. `CLAUDE_CODE_SESSION_ID` 가 있으면 그와 다른
`--session-id` 는 거부한다 — 다른 세션의 폴더를 지우지 않는다.

**`.claude` 나 `.claude/quality-gates` 가 심볼릭 링크면 `/quality-gates:quality-pipeline` 은 돌지 않는다** — 링크가 리포 안을
가리켜도 setup 이 거부 줄 하나를 내고 exit 1 로 멈춘다(링크 너머를 지울 수 있어서다). 해법은 그 자리를
실제 디렉토리로 바꾸는 것이다. 아래 GC 키(`quality-gates:qg-gc`)로 GC 를 꺼도 이 거부는 그대로다.

이 파일들은 `*.local.md` 가 아니라 따로 무시되지 않는다. 리포의 `.gitignore` 가 `.claude/` 를 무시하지 않으면
세션 폴더가 untracked 로 보인다 — 커밋하지 말고 무시 줄(`.claude/quality-gates/`)을 더하라. 게시 sink 는 이
폴더를 secret-scan corpus 에서 뺀다(게시 본문 자신이 여기 산다).
