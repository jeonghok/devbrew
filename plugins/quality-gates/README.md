# Quality Gates 플러그인

Claude Code용 품질 검증 파이프라인 — 한 파이프라인, 한 판정(`clean` · `defect` · `not-certified (<사유>)`). 기준선 대비 차등 테스트는 매 실행 돈다.

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding) — 처분 회계(adjudication `Ledger`)** (v7.1.0) — 리뷰 findings 가 버려지는 자리가 `shared/adjudication/adjudication.py` 의 처분(`accept`/`reject`/`hold`/`absorbed`/`coerced`/`source_failed`/`uncountable`/`suppressed`)을 부르고, 그 배선을 `tools/adjudication/` 의 판정기와 `shared/tests/test_adjudication_{wiring,consumed}.sh` 가 강제한다. 소비자는 `synthesize_findings.py`·`synthesize_artifact_findings.py`. **범위**: 강제되는 것은 `.py` 소비자와 `Ledger` import 가 있는 자리이고, `consumer=orchestrator`/`human` 인 dispatch 자리는 `disclosure=` 리터럴 실재까지만 검사된다(CLAUDE.md 축 C 한계).
- **Law 2 (입력 오염 차단) — `input_slots`** (v7.1.0) — 이 플러그인의 agent 여섯(`security-reviewer`·`doc-recritic`·`artifact-critic`·`artifact-adversarial`·`test-scope-validator`·`pr-understanding-builder`)이 frontmatter 에 받는 입력의 `tag`/`var`/`kind` 를 선언하고, 금지 종류(`prior_verdict`·`score`·`orchestrator_framing`)는 C6 인용과 함께 면제 등재를 요구한다. 집행은 `shared/tests/test_agent_input_slots.sh`. 앞 리뷰어의 판정이 다음 리뷰어의 전제가 되는 것이 Law 2 가 도구로 못 막는 구멍이다.
- **Law 3 (Compounding)** — Phase 1 single dispatch builder (T2-2/T3-5). Future persona edits land in one place, never drift across two dispatch sections.
- **Law 2 (Writer ≠ Reviewer)** — 순수 read-only reviewer agent(`security-reviewer`/`doc-recritic`/`test-scope-validator`)가 `tools: Read, Grep, Glob` fail-closed allowlist 선언 (frontmatter scoping으로 물리적 격리 — write/exec/delegation 도구는 목록에 없어 물리적으로 부재; 이름 기반 denylist는 시간에 대해 fail-open이라 대체됨). qg 자체 agent 는 모두 쓰기 권한이 없다. 외부 추가 리뷰어(`pr-review-toolkit` 등)는 쓰기 가능할 수 있으나 advisory 이고 fix 는 오케스트레이터가 소유한다 — 테스트는 오케스트레이터가 자기가 만든 트리에서 직접 돌린다.
- **Law 3 (Compounding)** — scout `rationale` 필드가 매 iteration마다 state 파일에 로깅; reviewer-persona 편집이 학습된 교훈을 인코딩하는 substrate.
- **Law 3 (Compounding) — cross-plugin reader contract** — 차등 테스트의 test-scope-validator(`scripts/discover-plan.sh`)가 sister-plugin (`superpowers:writing-plans`)의 출력 경로 `docs/superpowers/plans/`를 1순위 source로 명시 consume; convention drift가 silent breakage가 되지 않도록 README "Plan Discovery Sources" 섹션이 reader/writer 약속을 문서화.
- **P12 anti-corollary (former AP5, trivia ceremony) 회피** — `check-trivia.sh`가 단일 파일·≤3줄 whitespace/rename을 파이프라인 전체 skip. *현재 coverage는 whitespace + rename에 국한. P12 canonical 자격(typo/comment-only/formatting — 파일 수 무관)을 완전히 충족하기 위한 확장은 deferred 항목 — Tier 2 spec은 아카이브됨: `git show pre-slim-archive-2026-07-09:docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md`.*
- **P22 anti-corollary (former AP9, over-dispatching / subagent spray) 회피** — 파이프라인은 fan-out consent 게이트를 fire하지 않고(documented-not-implemented였음), transparency 라인 + 선언된 max fan-out(Phase 1 병렬 ≤ 8, 총/iteration ≤ 10) + authoring-time hard-review로 subagent spray를 억제.
- **P18 anti-corollary (former AP16, unbounded autonomy) 회피** — 파이프라인 내부 fix-loop이 `max_review_iterations=5` + repeat-detection (no-progress check) + kill switch로 묶임.
- **P5 (Filesystem as Memory) + P14 (State Survives Compaction)** — `.claude/quality-gates/<session-id>/` 하위 per-session markdown state (`*.local.md` gitignore 패턴으로 자동 제외; TTL sweep + SessionEnd hook으로 폴더 GC).
- **P8 determinism-economy (harness lightness — trust the model)** (v2.5.0) — 암묵 session scope로 파이프라인이 돌 때 그 사실을 사용자-가시 한 줄로 밝히는 **scope 투명성**. 버려진 결정론적 under-coverage 경고를 결정론 가드가 아니라 *모델 행동*으로 대체(git 비교·차단 없음). 자연어 scope 의도는 별도 parser 없이 모델이 branch scope로 해석 — `/qg branch`는 결정론적 escape hatch로 유지. devbrew P8 determinism-economy refinement("Zero hooks" 일반화) instantiation.
- **P8 determinism-economy — self-honest verdict floor** (v2.6.0; routing 제거·단순화 v2.7.0) — 파이프라인이 *검토받았다고 믿는 scope*와 *resolve한 scope*가 발산할 때(빈 세션 → resolved scope 0 → "clean"의 false-clean)를 봉쇄. read-only `scripts/check-review-scope.sh`가 `changes_exist`를 결정론으로 emit하고, SKILL이 iter-1에서 1회 호출·캐시해 **정직-verdict floor**(load-bearing, kill 불가)가 `resolved scope 0 AND changes_exist == yes`이면 판정이 `not-certified (scope-empty)` 가 된다. **무엇을 리뷰할지(routing)는 모델이 소유** — v2.7.0에서 v2.6.0의 redirect 게이트·`$effective_diff_scope` 배선·redirect kill switch를 제거하고 `/qg branch` escape hatch + honesty norm 한 줄로 대체(dogfood 5버그가 전부 routing 재구성에서 나왔고 floor의 load-bearing 입력 `changes_exist`는 틀린 적 없음). 결정론은 무결성 floor 한 점에만; routing/자연어는 모델 신뢰. genuine no-op·session 기본값·`/qg branch`는 무변경. regression: `tests/test_check_review_scope.sh`, `tests/test_qg_false_clean_floor.sh`.
- **P21 (Secret이 prompt context에 들어가지 않음)** — 결정 도구는 결정과 포인터만 묻고 secret 값은 받지 않는다(SKILL Rules R4). regression test: `tests/test_no_secret_prompts.py`.
- **Law 2 (Writer ≠ Reviewer, 분리)** — writer(originating turn) ≠ `test-scope-validator`(차등 테스트 R1b 의 사전 분류 리뷰어) ≠ 테스트 실행(오케스트레이터 · 결정론 스크립트). `test-scope-validator` 는 `tools: Read, Grep, Glob` fail-closed allowlist.
- **P2 (Categorical signal, no numeric scoring)** (v1.9.0) — `test-scope-validator`는 정확히 4-way enum 분류 (`aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`)만 emit. percentage, confidence, X/Y rating 모두 금지. summary의 counter 정수 (`1 aligned, 0 outdated…`) 는 허용. devbrew P2 "수치 스코어링 ban" instantiation.
- **Law 2 strengthening — model-family separation.** Optional `codex-reviewer` agent (when Codex CLI is detected) runs review in a separate process with a different model family (OpenAI vs Anthropic) and an OS-level read-only sandbox, giving 3-layer reviewer-writer isolation: `disallowedTools` + narrow `Bash` allowlist + `codex -s read-only`.
- **Law 2 (codex 격리, v1.11.0/v1.12.0 → v2.11.0 정정)** — codex 리뷰의 격리는 **`codex exec -s read-only` OS-level 샌드박스 + 별도 프로세스/모델 패밀리**가 전부다. v1.11.0~v2.10.x의 이 항목은 그 위에 *"frontmatter 키 whitelist"* layer를 얹었다고 기록했으나 **그 layer는 존재한 적이 없다**: (1) 당시 명명된 키는 공식 subagent 규격에 없는 필드라 런타임이 조용히 무시했고, (2) T3-3에서 `codex-reviewer`가 agent → 스크립트(`scripts/run_codex_reviewer.sh`)로 이관돼 frontmatter 자체가 사라졌다 (`tests/test_codex_reviewer_frontmatter.sh`가 agent 파일 **부재**를 assert). 지금 격리를 지탱하는 것은 OS 샌드박스다.
- **Law 2 (Writer ≠ Reviewer, frontmatter scoping)** (v1.13.0) — `security-reviewer` agent가 `tools: Read, Grep, Glob` fail-closed allowlist 선언. 보안 각도 구성원이며, kill switch `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`로 사용자가 disable 가능 (Plugin Shape — 모든 reviewer는 opt-out 가능). 디스패치는 `quality-pipeline` SKILL의 보안 각도 지점에 있다.
- **Law 3 (Compounding — drift 재발 차단, v1.12.0)** — `hooks/session-start-advisor.py` frontmatter scanner (AC14): SessionStart마다 모든 agent 파일의 frontmatter key를 kebab-case drift 검사. `tests/test_agent_frontmatter_keys.sh` (AC15): repo-wide deny-list bash test — CI에서 C1 종류 (kebab-case 잘못된 키) drift를 자동 차단. 이 두 mechanism이 함께 "리뷰를 탈출한 버그 → reviewer persona 편집 + compounding linter 신설" Law 3 instantiation.
- **Law 1 — Clarity Before Code (좌표 계약 측면)**: pipeline 의 단일 좌표 `project_dir` 가 SKILL preflight 에서 frozen 되어 모든 subagent / hook / 외부 codex 프로세스에 명시적으로 propagate. cwd 재계산은 frontmatter Forbidden + grep-anchored drift guard 로 mechanically 차단. (v1.14.0)
- **Law 1 (Clarity Before Code) — `/qg branch <name>` surface** (v1.15.0) — 7개 거절 시나리오(존재하지 않는 브랜치, path traversal, kill switch, idempotent reuse 등)가 `tests/test_branch_worktree.sh` AC1–AC11에 acceptance criteria로 명시. 실패 경로마다 명확한 진단 메시지를 stderr로 출력.
- **Law 3 (Compounding) — worktree path 컨벤션** (v1.15.0) — `.claude/<plugin>/worktrees/<name>-<sid-short>/` 경로 패턴을 플러그인 공통 컨벤션으로 확립해, 차후 다른 플러그인이 임시 worktree를 만들 때 같은 컨벤션을 재사용할 수 있게 함.
- **Law 1 (Clarity Before Code) — single-turn dispatch contract** (v1.32.0) — pipeline progression이 `quality-pipeline` SKILL의 단일 assistant turn 내 serial dispatch로 일원화. cross-turn state machine (transition compute helpers, no-signal counter, 시간 기반 guard) 전부 삭제 — 진행 결정은 SKILL의 명시적 boundary + AskUserQuestion으로만 발생. State file은 GC mtime anchor + worktree tracking + 파이프라인 iter counter reporting만 보존.
- **P22 generalization (consent gate → progression gate):** AskUserQuestion
  is reused as a **progression primitive** at every fix-loop iteration
  boundary. It gates fix-loop consent (it does NOT gate subagent fan-out —
  that consent gate was never implemented; fan-out is bounded by the
  transparency line + declared max fan-out) — no new principle ID needed.
- **C66 (Linked Artifact Flow) — spec을 truth로 instantiate** (v2.1.0) — qg가 처음으로 사용자 프로젝트 spec을 읽어(`scripts/discover-spec.sh`) test-scope-validator의 기준 축을 plan items → **spec Acceptance Criteria**로 전환하고, codex 경로(`run_codex_reviewer.sh`)가 spec AC를 `<spec_context>`에 주입한다. cycle 위계(spec=truth ⊃ plan=구현 방식)를 instantiate — spec→test 커버리지를 역방향 walk. plan은 구현-방식 보조 hint로 강등(제거 아님; `discover-plan.sh` byte-identical). **advisory only — 판정을 block하지 않음.** spec 부재 시 loud log + plan-기반 분류로 fallback. kill switch `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1`.
- **P21 (Untrusted input — diff is data, not instructions)** (v2.8.0) — 파이프라인의 두 diff-reading reviewer(`security-reviewer`/재비판 `doc-recritic`)가 attacker-influenced `filtered_diff`(및 finding 텍스트)를 데이터로만 다루고 그 안의 prompt-injection·안전성 주장을 verdict 근거로 삼지 않도록 명시. 더해 언어/프레임워크 FP precedent 5건을 기능별 단일 배치(DRY)로 흡수 — suppress-at-source 3(security-reviewer anti-flag) + reject-at-verify 2(재비판 코드 프로필 관문 C, PR4a 부터 `references/recritic-code-profile.md`가 싣는다). 섹션-스코프 grep 회귀 락(`test_security_reviewer_persona.sh`)으로 persona 약화 검출(재비판은 공유 정본의 copy-of 사본이라 이 플러그인이 그 persona 를 직접 lock 하지 않는다 — `shared/tests/test_copy_of_contract.sh` 가 대신 잰다). 신규 P# 0, 결정론 가드 0 (Anthropic *"Using LLMs to Secure Source Code"* 평가 Tier-1; design-lightness).
- **P21 (Secret이 prompt context에 들어가지 않음) — 출력값 유출 차단으로 확장 (publish sink)** (v2.9.0) — `/qg-publish`가 게시 직전 `secret-scan.py`로 전체 payload(artifact + PR title + 브랜치명 + 커밋메시지; PR-create 시 히스토리까지)에서 시크릿 **값**(quoted string / vendor 패턴 / corpus-substring, keyword는 보조 신호)을 스캔해 hit 시 게시를 FAIL CLOSED로 거부한다 — 스캔 에러·타임아웃도 hit 취급. 기존 인스턴스(v1.8.0, secret 값이 prompt로 들어가지 않음)와 자매지만 방향이 반대다: 여기는 모델이 저술한 텍스트가 GitHub로 **나가기 전** 값 유출을 막는다. regression: `tests/test_secret_scan.py`, `tests/test_secret_scan_fp.py`.
- **P21 (Untrusted input — diff is data, not instructions) 확장** (v2.9.0) — v2.8.0에서 파이프라인 두 reviewer에 넣은 norm을 `pr-understanding-builder` 페르소나와 publish orchestrator에도 확장한다. PR 코멘트는 id+마커 매칭용 opaque bytes로만 다루고(스크립트가 선택 계산; 모델이 내용을 읽고 지시로 따르지 않음), artifact 내 이미지는 auto-fetch 유출 벡터라 중립화한다.
- **P17 (Consent) — 게시는 파이프라인의 일부가 아니라 opt-in consent-gated 표면** (v2.9.0) — `/qg-publish`는 매 실행마다 사람이 읽는 preview 뒤 AskUserQuestion으로 명시 동의를 받아야만 GitHub에 쓴다(비가역·영구 노출 고지 포함; cross-repo "always" 없음). **`/qg`의 파이프라인 자체는 이 기능으로 변경되지 않는다 — publish는 그 위에 얹힌 별도 opt-in 표면이지 파이프라인에 자동으로 연결되지 않는다.**
- **P18 (Bounded idempotency)** (v2.9.0) — `comment-upsert.py`가 인증 `user.id` 스코프 내에서 버전-패밀리 마커(`<!-- pr-understanding:v1 -->`, 첫 줄 anchored 매칭이 optional `tier=N` 접미사를 허용 — 빌더는 `tier=N`을 emit하지만 tier는 변경 파일 수에 따라 드리프트하므로 매칭은 tier를 무시해 멱등이 깨지지 않게 함)로 기존 코멘트를 조회해 0개→POST, 1개→PATCH, ≥2개(비정상)→REFUSE — 모호성 앞에서 임의로 고르지 않고 결정론적으로 멈추고 사용자 확인을 요구한다.
- **pwn-request Law-2형 물리 분리 — 생성 ≠ 게시** (v2.9.0 → v2.12.0에서 **처음으로 사실이 됨**) — `pr-understanding-builder` 에이전트는 `tools:`에 무해한 항목 **하나만** 선언한다 (fail-closed allowlist — 쓰기·실행·네트워크·위임 도구 0개, 유일 항목 = inert `Read`(생성기가 미호출), 유일 입력 = inlined `build-pr-context.sh` blob). `gh`/네트워크는 오직 `publishing-pr-understanding` skill(오케스트레이터)만 보유한다. ⚠️ **v2.9.0~v2.10.x에서 이 주장은 거짓이었다**: 당시 격리는 존재하지 않는 필드 + 11개 이름 denylist였고, denylist에 `mcp__*`가 없어 tavily 웹검색·chrome-devtools 브라우저 제어가 **열려 있었다**. 이름 기반 denylist는 원리적으로 닫을 수 없다 — `Monitor`가 이름 없는 셸(`command`)과 이름 없는 egress(`ws`)를 준다. allowlist만이 열거되지 않은 것과 **미래에 추가될 것**을 자동 차단한다.
- **Law 1/2/3 + P8/P18 (산출물 비평 루프, v2.11.0)** — `/qg critique`가 비-코드 산출물에 대해 tier-unpinned `artifact-critic`+`artifact-adversarial`(+조건부 codex)의 read-only 비평 → 오케스트레이터 수정 → 라운드별 커밋 루프를 돈다. Law 1=E3 upfront 동의 게이트; Law 2=read-only 리뷰어(`tools:` allowlist)+매 라운드 독립 critic 게이트; Law 3=라운드별 커밋 감사추적; P18=max-rounds+stagnation predicate+kill switch(`DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE`); P8=NL 라우팅 모델-소유, 결정론은 `critique <path>`+§10 스키마. 별도 skill `critiquing-artifacts`로 위임(코드 파이프라인 무변경).
- **LD3 (floor 는 실행이다) — 영향분 테스트의 실제 실행** (v3.0.0) — ② 차등 테스트의 floor
  가 "전체 앱 부팅"이 아니라 *"레포에 이미 있는 테스트 중 영향분을 실제로 돌리는 것"*이다.
  `run-test-selection.sh` 가 러너 어댑터 9종을 **집합으로** 감지해 전부 실행한다 — 폴리글랏
  레포에서 우선순위 밖 러너를 버리면 floor 가 의미를 잃는다(이 리포 실측: `.sh` 130개 /
  `.py` 50개). 부팅되는 앱의 런타임 행위 검증은 대체되지 않고 주장만 거뒀다(위 C4).
- **LD5 (결정론은 모델 주장과 독립인 백스톱) — 호출 주체 분리 (Law 2)** (v3.0.0) — 영향 스코프
  판정은 모델이 하되, `run-test-selection.sh` 는 기준선 측·HEAD 측 **둘 다 오케스트레이터가
  직접** 호출한다. agent 가 테스트 결과를 self-report 하면 오케스트레이터가 받는 것이 raw
  출력이 아니라 모델의 요약이 되어 백스톱이 백스톱이 아니게 된다. `diff-test-results.py` 의
  `--expected` 도 같은 이유로 **독립 입력**이다 — 두 생산자의 상호 대조로 계산하면 대칭
  누락을 아무도 못 잡는다. regression: `tests/harness/test_skill_orchestration_behavior.sh`
  (호출 위치), `tests/test_diff_test_results.py` (대칭 누락).
- **LD7 (질문형 루브릭) — floor 5차원 원장** (v3.0.0) — `changed`/`behavior`/`verification`/
  `attribution`/`gap` 다섯 **질문**과 의무 `derived`. `check_qa_ledger.py` 는 **구조만** 본다
  (의미 판정 없음) — Law 1 의 구조적 게이트가 하는 일은 silent skip 을 불가능하게 만드는
  것뿐이다. `degraded` 는 실패가 아니라 1급 상태다: "확증 못 했다"를 정직하게 쓸 자리가
  있어야 "확인했다"로 반올림되지 않는다. 점수형·테스트종류 메뉴는 두지 않는다.
  여기에 **대조 두 개**가 얹힌다(둘 다 의미 판정이 아니라 두 값의 일치·개수 검사이며
  둘 다 필수 인자다 — 선택이면 안 넘긴 호출자가 조용히 면제받는다): `--aggregate` 는 R6
  집계의 `attribution_status` 와 원장의 `floor:attribution` 을, `--assign-rows` 는 배정
  TSV 의 `unclaimed` 행 수와 `floor:verification` 을 본다. 둘 다 **개수가 아니라 경로**를
  받는다 — 모델이 옮겨 적는 숫자를 받으면 대조가 대조하려던 전사 구멍을 그 인자가 다시
  연다. **`--assign-rows` 집행의 사정거리:** bulk 흡수자(cargo·make·npm-script)가 감지되면
  **어댑터가 주장하지 않은 파일**은 `unclaimed` 대신 `BULK` 한 행으로 접히므로, *그 축*의
  공시는 `커버리지 미보장` 배너이지 이 집행이 아니다(설계 §6.7 F5 — 의도적으로 열어 둔
  항목). **담김 위반(워크트리 밖 unit)은 흡수자 유무와 무관하게 `unclaimed` 로 남는다** —
  그 거절은 흡수 분기보다 **앞서** 일어난다(`run-test-selection.sh` 의 `assign` 루프:
  `unit_within_worktree` 실패 → `unclaimed` 출력 → `continue`). 흡수자가 있는 레포에서
  이 검사가 죽은 무게라고 결론짓지 말 것 — 가장 위험한 클래스가 바로 그 축이다. regression:
  `tests/test_qa_ledger.sh`, `tests/harness/test_skill_orchestration_behavior.sh`.
- **Law 3 (Compounding) — 문서 리뷰 엔진 기반 (v7.4.0)** — 네 문서 리뷰 자리를 통일하는 `shared/docreview/` 를 호출자 0 으로 심었다. `generic` 프로필(`references/docreview-profiles/generic.md`)이 non-code 아티팩트 자리를 데이터로 선언. `/qg critique` 의 전환(agent·reference 링크 배선, `artifact_commit.sh` 자율 커밋 루프 소멸)은 후속 major PR. 집행은 `shared/tests/test_docreview_*.sh` + 변이 매트릭스.
- **모집단에 안 들어간 것은 검사되지 않는다 (v7.5.0)** — 심볼릭 링크로 배포되는 러너가 `extract_codex_invocations.py` 의 `is_symlink()` skip 과 `codex_observation.sh` 양쪽 모집단에서 빠져, `test_sandbox_enforced.sh` 가 «통과»하면서도 그 러너를 한 번도 안 봤다. 링크 배포본을 모집단에 넣고 관측 캡처를 basename 이 아니라 «경로»로 키잉했다(같은 basename 후보 둘이 서로를 가렸다). **락의 PASS 는 이빨의 증거가 아니다** — 무엇이 모집단에 있는지를 먼저 물어야 한다. v7.4.0 CHANGELOG 가 「PR 2 에서 다시 판단한다」로 미뤘던 항목이고, 그 판단은 이 릴리스가 했다.
- **Law 1 · G3 — 「검증하지 못했다」는 일급 판정값** — 판정은 `clean` · `defect` · `not-certified (<사유>)` 셋이고 사유는 닫힌 열거다(`scripts/verdict.py` 한 곳). kill switch · trivia · 각도 부재 · 차등 축의 해상도 문제는 `clean` 도 실패도 아닌 `not-certified` 로 드러난다. regression: `tests/test_verdict_vocabulary.sh` · `tests/test_pipeline_verdict_wiring.sh`.
- **C4 — 차등 테스트는 항상** — 기준선 축(`create-baseline`)과 봉인된 HEAD 축(`seal-worktree.sh` → `create-head`)에서 오케스트레이터가 직접 돌린다. 판정을 내는 경로 안에서 차등 테스트가 빠지는 길은 trivia escape 와 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 둘뿐이고 둘 다 `not-certified` 다(전역 `DEVBREW_QUALITY_GATES_DISABLE=1` 은 다르다 — Preflight P1 에서 판정 자체를 내지 않고 그대로 리턴한다). 부팅되는 앱의 런타임 행위 검증은 **대체하지 않고 주장을 거둔다**.

## 구조

```
quality-gates/
├── .claude-plugin/         # 플러그인 메타데이터
│   └── plugin.json
├── agents/                 # 리뷰어 agent (leaf agent; 파이프라인이 dispatch — 쓰기 권한 있는 agent 는 없다)
│   ├── test-scope-validator.md  # 차등 테스트 R1b (pre-exec test scope 분류)
│   ├── doc-recritic.md          # ④ 재비판(Phase 1.5) — 공유 재비판자의 copy-of 사본
│   ├── security-reviewer.md     # ③ 보안 각도(Phase 1) always-run — 코드 레벨 보안 리뷰 (injection / authn-authz / secrets / SSRF / crypto-misuse / deserialization / raw-HTML / dependency manifest). Disable: `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`
│   ├── artifact-critic.md       # `/qg critique` 게이트 — tier-unpinned critic; 비-코드 산출물의 논리 갭·미기술 전제·불완전·근거 없는 주장·모호성 (read-only)
│   ├── artifact-adversarial.md  # `/qg critique` 게이트 — tier-unpinned 판정자; critic/codex 발견을 confirm/downgrade/reject 하고 놓친 것을 추가 (read-only)
│   └── pr-understanding-builder.md  # publish 생성기 — model 키 없음(tier-unpinned), tools: Read 1개 (inert·미호출; fail-closed; 쓰기·실행·네트워크·위임 0; 유일 입력 = inlined blob)
├── commands/
│   ├── qg.md               # /qg slash command (--reset, --paths, branch flag 포함)
│   ├── qg-publish.md       # /qg-publish slash command ([--dry-run]; publish skill로 얇은 dispatch)
│   └── cancel-qg.md        # /cancel-qg command
├── hooks/
│   ├── hooks.json                            # Hook 설정
│   ├── session-start-advisor.py              # in-flight 파이프라인 read-only advisor
│   └── session-end-cleanup.py                # 정상 종료 시 현재 세션 폴더 제거
├── scripts/
│   ├── setup-qg.sh                           # 파이프라인 초기화
│   ├── check-trivia.sh                       # Trivia escape 감지기
│   ├── filter-docs.sh                        # 코드 reviewer용 docs path 필터
│   ├── discover-plan.sh                      # Plan 파일 우선순위 탐색 (차등 테스트 test-scope-validator)
│   ├── discover-spec.sh                      # Spec 파일 우선순위 탐색 (test-scope-validator + codex; AC-섹션 적격성)
│   ├── discover_common.sh                    # 위 두 탐색기가 source 하는 공통 조각 (get_mtime · pick_newest; 실행 지점 없음)
│   ├── compute-test-scope-candidates.sh      # 차등 테스트 R1b — 후보 test 파일 산출 (Python/JS/TS heuristic)
│   ├── resolve-baseline.sh                   # 공유 baseline resolution (base/base_ref/merge_base/degraded/same_as_head/ahead)
│   ├── seal-worktree.sh                      # `seal <session-id>` — HEAD 트리를 `.git` 안 임시 인덱스로 봉인, 봉인 커밋 SHA 출력
│   ├── qg-worktree.sh                        # `create-baseline`/`create-head` — 기준선·봉인 HEAD 두 축의 워크트리 생성(`create-head`는 봉인을 다시 떠 대조). `create-sandbox`/`mutation-guard` 는 남아 있으나 qg 파이프라인은 더 호출하지 않는다 — 소비자는 `plugins/plugin-audit` 자체 테스트 격리
│   ├── run-test-selection.sh                 # ② floor — 러너 어댑터 9종 detect/assign/probe/run (유일 소유자, 기준선·HEAD 양쪽 오케스트레이터가 직접 호출)
│   ├── baseline-cache.sh                     # (merge_base, runner, unit) 내용주소 기준선 캐시 get/put
│   ├── diff-test-results.py                  # 기준선×HEAD 귀속 8종 + 어댑터 간 --aggregate
│   ├── check_qa_ledger.py                    # LD7 floor 5차원 원장 구조 게이트 (Law 1)
│   ├── detect_codex.sh                       # symlink → ../../../shared/codex/detect_codex.sh — Codex CLI 10-case probe (killswitch-conf/version/auth/sandbox/kill-switch/timeout)
│   ├── build_codex_prompt.py                 # ③ 다른 전제 각도(codex-reviewer)용 prompt builder
│   ├── codex_findings_to_yaml.py             # symlink → ../../../shared/codex/codex_findings_to_yaml.py — Codex JSONL stream → 표준 finding YAML (auth/schema/stderr 처리, --emit-keys default|design)
│   ├── codex_jsonl.py                        # copy-of shared/codex/codex_jsonl.py — extract_last_agent_message 정본 사본 (설치본에서 sibling import가 살아있게)
│   ├── recritic_bridge.py                    # Phase 1.5 재비판 익명화 브리지 (`prepare` — findings → agent-stripped f-키 findings + 매핑 산출; raw diff 는 오케스트레이터가 별도로 쓴다)
│   ├── qg-gc.py                              # TTL 기반 stale 세션 GC (fcntl-locked)
│   ├── build-pr-context.sh                   # publish: base..HEAD 고정 context blob (diff+내용+이웃 시그니처+커밋메시지) — 빌더의 유일 입력
│   ├── diagram-facts.sh                      # publish: nodes/edges 산출 (changed files + 이웃 import; repo-root 상대 import만)
│   ├── secret-scan.py                        # publish: 게시 직전 값-차단 secret scan (FAIL CLOSED)
│   ├── pr-detect.sh                          # publish: 현재 브랜치의 PR 상태 탐지 (has_pr/number/url/state/head_pushed)
│   ├── comment-upsert.py                     # publish: marker 기반 멱등 upsert (user.id 스코프, 0/1/≥2 REFUSE) — DEVBREW_QUALITY_GATES_DISABLE_PUBLISH 최내부 sink
│   ├── render-terminal.py                    # publish + Final Summary 공용 STATUS 표 / ASCII diagram / accuracy-warnings 렌더러
│   └── gh-identity.sh                        # publish: 인증 user login+numeric id 조회 (`gh api user` 캡슐화; empty id는 fail-closed)
├── references/
│   ├── recritic-code-profile.md   # Phase 1.5 재비판 코드-경로 프로필 — 판정 어휘 + 관문 A–D(verifier-writable 포함, 이전 판정자 persona 에서 이관, PR4a R-Q)
│   └── docreview-profiles/
│       └── generic.md             # `/qg critique` 게이트 — non-code 아티팩트 리뷰 프로필(§ 위 v7.4.0 bullet)
├── skills/
│   ├── quality-pipeline/
│   │   ├── SKILL.md         # 한 파이프라인 실행기 — ①–⑤ in-turn 오케스트레이션
│   │   └── references/
│   │       ├── differential-test.md  # ② 차등 테스트 절차 전문 (매 iteration Read)
│   │       └── state-file-format.md  # 파이프라인 state 파일 포맷
│   └── publishing-pr-understanding/
│       └── SKILL.md         # /qg-publish orchestrator — gh를 가진 유일 컴포넌트 (cost_class: variable)
└── tests/                            # Bash/Python 단위 테스트 (test_discover_plan.sh, test_qg_publish_docs.sh 등)
```

## 설치된 Hook

| Hook | 이벤트 | 변경? | 왜 hook인가 (skill이 아닌)? |
|---|---|---|---|
| `session-start-advisor.py` | SessionStart | **아니오 — read-only advisor** | mutation 없이 in-flight 파이프라인 알림 (CLAUDE.md hook coexistence 룰). |
| `session-end-cleanup.py` | SessionEnd | 예 (자기 세션 폴더 제거) | 정상 종료 시 per-session 정리; crash 시 TTL sweep으로 fallback. |

모든 hook은 `DEVBREW_QUALITY_GATES_DISABLE=1` (전역) 와 hook 단위 override
`DEVBREW_SKIP_HOOKS=quality-gates:<hook-name>`을 따릅니다.

## Cost Class

`quality-pipeline` skill은 `cost_class: variable` — 자동 감지된 depth에 따라 비용이 달라집니다:

| Depth | 기존 default-Opus 베이스라인 대비 비용 |
|---|---|
| Trivia | ~0% (즉시 skip) |
| Quick | ~25–35% |
| Standard | ~30–45% |
| Deep | ~55–75% (추가 리뷰어 다수) |

트리거 조건과 override flag는 [`commands/qg.md`](commands/qg.md) 참고.

### Codex reviewer cost

The optional `codex-reviewer` agent has `cost_class: variable` — as an **availability-floor** it invokes the user's Codex CLI subscription/API on **every non-trivia pipeline dispatch when detected (all depths incl. `quick` — scope/depth-independent)**, separate from the depth-specific baseline in the table above (so it is not attributed to any single depth row). First-use cost consent gate prompts via `AskUserQuestion`. Disable globally with `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`.

### PR-understanding publish cost (`/qg-publish`, separate from the pipeline)

`publishing-pr-understanding` skill은 `cost_class: variable` (context 크기·tier에 따라 다름). 저술을 맡는 `pr-understanding-builder`는 frontmatter 에 `model` 키가 없다 — 사용자의 subagent 설정, 없으면 세션 티어를 받는다(하니스가 티어를 정하지 않는다). Deep tier만 실행 전 upfront cost 고지(AskUserQuestion)를 하며, 작은 diff는 비용이 자연히 bounded되고 `/qg-publish`는 명시적 실행이 곧 비용 수용이다(NG5 정합 — 명시 실행이 유일한 touchpoint). 파이프라인의 비용 표(위)와는 **완전히 별도** — publish는 파이프라인의 일부가 아니므로 depth 기반 자동 트리거가 없다.

### 재비판자(doc-recritic) model

`doc-recritic` agent declares no `model` key — 이 값은 이 플러그인이 아니라 공유 정본
(`shared/docreview/agents/doc-recritic.md`)이 정한다. 파이프라인 안에서는 여전히 **단일
model-based 판정 각도**다: Phase 1/2 리뷰어가 findings 를 내고 그 뒤의 synthesizer 는
결정론적 스크립트이므로, 사용자가 보는 모든 finding 은 재비판자의 판정을 거친다. 판정
관문은 이제 persona 가 아니라 코드 프로필 자리다 — `references/recritic-code-profile.md`
가 A–D(verifier-writable 포함)를 싣고, persona 자신은 문서 재비판과 동일한 프레이밍-차단
뼈대만 갖는다(공유 정본 — 이 플러그인은 그 persona 프로즈를 편집하지 않는다). `model` 키 부재가
그대로 유지되는지는 `shared/tests/test_copy_of_contract.sh`(byte-for-byte copy invariant)
가 잰다 — 사본이 원본과 한 바이트라도 다르면 그 락이 RED 다. 하네스가 티어를 정하지 않는
원리(no `model` key → 사용자 `CLAUDE_CODE_SUBAGENT_MODEL` 설정, 없으면 세션 티어, CLI
2.1.261 측정)는 무변경. Runs ~once per pipeline fix-loop iteration (≤5×).

**Choosing a cheaper tier for devbrew subagents is the user's call, not the plugin's.** Put it in your own settings — for example in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus" } }
```

Remove the entry to return to the session tier. (`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` also exists. The only thing measured here (CLI 2.1.261, 2026-09-06) is that it overrides a frontmatter `inherit`; its documented effect on dispatch-time `model` arguments and on other plugins' pins was not measured. devbrew does not recommend it.) Note the trade-off you are choosing: on a session stronger than the tier you set, reviewers run one tier below the writer.

## 파이프라인

> **비-코드 산출물 비평 모드 (v2.11.0):** `/qg critique <path>` 또는 자연어 비평 의도로 문서·스펙·계획·설정·산문을 대상으로 비평-수정-재비평 루프를 돈다(라운드별 커밋; 코드 리뷰 아님 — 코드는 위 코드 파이프라인). 상세는 skill `critiquing-artifacts`.

| 단계 | 주체 | 무엇 |
|---|---|---|
| ① 스코프 | 오케스트레이터 + `check-review-scope.sh` | session(기본) · `branch` · `--paths` |
| ② 차등 테스트 | 오케스트레이터 + 결정론 스크립트 | 영향분 테스트를 기준선 축과 봉인된 HEAD 축에서 돌려 귀속(`references/differential-test.md`) |
| ③ 각도 + 리뷰어 | `security-reviewer`(보안) · codex(다른 전제) · 추가 리뷰어(스코프) | 각도 셋과 그 수행자는 고정, 스코프는 추가 리뷰어만 정한다 |
| ④ 재비판 | `doc-recritic`(판정 각도) | 출처를 못 보는 재비판 — 탐지 0 이어도 돈다 |
| ⑤ 합성 · 판정 | `synthesize_findings.py` → `verdict.py` | `clean` · `defect` · `not-certified (<사유>)` |

**아키텍처 메모 — 왜 오케스트레이션이 skill 에 있는가**: Claude Code는 skill만 `Agent()`의
`subagent_type`을 쓸 수 있다. 파이프라인은 여러 리뷰어를 디스패치해야 하므로 orchestration
로직이 `skills/quality-pipeline/SKILL.md`에 있다. 테스트 실행은 어떤 agent 에도 위임하지
않는다 — 오케스트레이터가 `run-test-selection.sh` 를 직접 부른다. 결정론 백스톱이 모델
주장과 독립이라는 전제가 거기서 선다.

**`/qg-publish` (PR-understanding generate/publish)는 파이프라인의 일부가 아니다.** (v2.9.0)
`gh`는 위 파이프라인 어디에도 없다 — publish는 별도 skill(`publishing-pr-understanding`)에
격리된 **consent-gated opt-in 표면**이지, `/qg`의 파이프라인에 자동으로 연결되지
않는다. 정직 문구: 이 표면은 **deterministic envelope + model-authored content** —
gh I/O·secret-scan·marker-scoped idempotent upsert는 결정론 스크립트가 통제하고, 사람이
읽는 실제 산출물 텍스트는 빌더가 저술한 model-authored content다. 게시는 매 실행
사람이 preview를 읽고 AskUserQuestion으로 명시 동의한 뒤에만 일어난다. `/qg` 완료 시
파이프라인은 그대로 끝난다 — 게시는 `/qg-publish`를 **명시적으로 실행**해야만
시작되고, 그 명시 실행 자체가 유일한 touchpoint다(자동 이어짐 없음).
파이프라인의 일부도 아니고, gh는 여전히 그 어디에도 없다. 자세한 내용은
[`commands/qg-publish.md`](commands/qg-publish.md).

## 리뷰어 구성 — 각도 셋 + 추가 리뷰어

각도 셋(보안 · 판정 · 다른 전제)과 그 수행자는 고정이다 — 스코프로 빠지지 않는다. **추가
리뷰어만 오케스트레이터가 diff 스코프로 선택**한다(모델 판단 + scout 힌트 + review-pr
§4 rubric + scope-signal 팔레트):

```
보안 각도 — 매 iteration (모델이 못 뺌)
  └── quality-gates:security-reviewer   tools: Read, Grep, Glob (#104 락) · 처분 fail-closed
판정 각도 — 매 iteration (탐지 0 이어도)
  └── quality-gates:doc-recritic         tools: Read, Grep, Glob (#104 락) · 처분 fail-closed
다른 전제 각도 — detect_codex 참이면
  └── codex-reviewer (별도 프로세스/모델 패밀리, OS read-only 샌드박스) · 부재는 공시만
추가 리뷰어 — 모델이 스코프로 선택, advisory 외부 에이전트; 최대 6 후보
  ├── pr-review-toolkit:code-reviewer        ← 강한 default(비-trivial diff), quick-depth만 drop
  ├── pr-review-toolkit:silent-failure-hunter → 에러핸들링 변경
  ├── pr-review-toolkit:type-design-analyzer  → 신규/변경 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → docs/주석 변경
  └── feature-dev:code-architect             → 대형 구조/아키텍처 변경
합성 — synthesize_findings.py (결정론) → verdict.py
```

선택은 **model-owned routing**(P8 lightness) — 결정론 selector 스키마 없음. 상세 rubric·
팔레트는 SKILL `## Angles and reviewers (scope-driven)` 섹션. scout(`scripts/scout.py`)는
`depth` + 추천 subset을 emit하는 **힌트 provider**(권위 아님).

**Prerequisites (추가 리뷰어 optional dependencies):** `pr-review-toolkit`(code-reviewer +
silent-failure-hunter + type-design-analyzer + pr-test-analyzer + comment-analyzer),
`feature-dev`(code-architect). 미설치 시 해당 추가 리뷰어는 unavailable로 degrade하고 각도
수행자 + 설치된 것으로 계속(loud log). 각도 수행자는 이 degrade의 영향을 받지 않는다.

**Fan-out:** 파이프라인은 fan-out consent 게이트를 fire하지 **않는다**(과거
dispatch-수 기반 consent 게이트 주장은 documented-not-implemented였음). P22
anti-corollary(subagent spray) instantiation은 **transparency 라인(매 iter 선택/제외 가시화)
+ 선언된 max fan-out** 기반으로 억제한다 (리포 전역 `fan-out ≥5` 하드 게이트는 억제 sweep에서 제거됐다 — 없는 백스톱을 근거로 들지 않는다).
재계산 max fan-out: **Phase 1 병렬 ≤ 8**(security-reviewer + codex + 추가 리뷰어 최대 6),
**총/iteration ≤ 10**(+ 재비판 + synthesizer; code-simplifier Phase 3 없음).

## 파이프라인 흐름 (single-turn)

`quality-pipeline` SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다. fix-loop iteration은 AskUserQuestion으로 사용자 동의를 받아 진행합니다 — 이 도구는 progression/consent를 담당하며, subagent fan-out은 게이트하지 않습니다(fan-out은 transparency + 선언된 max fan-out으로 bound).

```
┌─ single assistant turn ──────────────────────────────────────────────┐
│                                                                        │
│   user: /qg                                                           │
│       │                                                               │
│       ▼                                                               │
│   setup-qg.sh --ensure  (creates .claude/quality-gates/<sid>/...)     │
│       │                                                               │
│       ▼                                                               │
│   SKILL preflight  (kill switch)                                      │
│       │                                                               │
│       ▼                                                               │
│   trivia escape? ── yes ──▶ verdict: not-certified (trivia) ──────┐   │
│       │ no                                                        │   │
│       ▼                                                           │   │
│   qg iter loop (≤5)                                                │   │
│     ① scope (session | branch | --paths)                           │   │
│     ② differential test (baseline vs sealed HEAD — every iteration)│   │
│     ③ angles + reviewers (security · codex · specialists)          │   │
│     ④ framing-blind re-critique (doc-recritic)                     │   │
│     ⑤ synthesize → verdict: clean | defect | not-certified         │   │
│       │                                                             │   │
│       ├── clean ──────────────────────────────────────┐            │   │
│       ├── defect/not-certified, kept = 0 (no fix       │            │   │
│       │   to offer — stop here, verdict unchanged) ────┤            │   │
│       │                                                │            │   │
│       └── defect/not-certified, kept > 0 ──▶ AskUserQuestion        │   │
│                                    ("findings remain..." │           │   │
│                                     Retry / Accept and   │           │   │
│                                     finish / Stop)       │           │   │
│                                        │ Retry → next iteration     │   │
│       ▼                                ▼                ▼           ▼   │
│   Final summary  (Verdict · Iterations · Outcome · angles) ◀────────┘   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Trivia detector coverage

`scripts/check-trivia.sh`가 인식하는 trivia kind. 매칭 시 `/qg`는 dispatch를 건너뜀.

| kind | regex/조건 | 예 (positive) | 예 (negative) |
|---|---|---|---|
| `whitespace` | `git diff -w`가 비어 있음 | 들여쓰기 normalize | 한 토큰이라도 추가/삭제 |
| `rename` | `--diff-filter=R` ≥1 + content 변경 0 | `git mv a.py b.py` | `mv` + 한 줄 수정 |
| `comment` | 변경 line ≤3, 모두 `^[+-]\s*(#\|//\|--\|/*\|*)` 매칭 | docstring 한 줄 수정 | 코드 + 주석 혼합 |
| `typo` | 한 line 수정, 1 token만 다름, 길이 차 ≤2 | `colour → color`, `userId → userPid` | `userID → userIdentifier` (rename) |
| `untracked-newfile` | 새 파일 1개, ≤3줄, 모두 빈/주석/shebang | 빈 placeholder 추가 | 새 함수 정의 추가 |

`comment`, `typo`, `untracked-newfile`은 v1.16.0 (T2-1)에서 추가.

## 사용

```
/qg                            # 파이프라인 실행; 세션 단위 diff
/qg branch                     # 파이프라인 실행; main 대비 풀 브랜치 diff
/qg branch <name>              # 격리된 worktree 에서 <name> 브랜치 검사
/qg --paths <glob>...          # 명시 path scope
/qg --reset                    # 현재 세션 폴더 + legacy 파일 정리 후 종료
/qg --gc                       # stale sibling 세션 (TTL) sweep 후 종료
/qg both|review|runtime|--skip-runtime   # 제거됨 — 한 줄 공지 후 그대로 진행 (한 파이프라인이라 게이트 범위가 없다)
/qg --plan <path>              # 특정 plan 파일 사용
/qg --pr-url <url>             # PR URL 명시
/qg critique <path>            # 비-코드 산출물 비평-수정 루프(별도 skill; 코드 아님)
/cancel-qg                     # 현재 세션 활성 파이프라인 취소
/cancel-qg --gc                # stale 세션 TTL sweep
/cancel-qg --all               # 전 세션 wipe (확인 + 활성 sibling 리스트 먼저)
```

## Recipes

### 다른 브랜치를 격리된 worktree에서 검사

다른 브랜치를 검사하면서 본인 작업트리는 무손상 유지:

```bash
git fetch origin pull/123/head:pr-123  # PR을 로컬 브랜치로 가져오기
/qg branch pr-123                       # 임시 worktree에서 파이프라인 실행
```

내부 동작:

1. `<repo>/.claude/quality-gates/worktrees/pr-123-<sid>/` 에 detached worktree 생성
2. 그 안에서 파이프라인 실행, agent들이 worktree에서 diff를 읽음 (state는 main repo에 머묾, v1.14.0 worktree cwd contract 그대로 적용)
3. 정상 종료 (complete / cancel) 시 자동 cleanup. 비정상 종료 시 보존 + stderr 안내 경로

### 디버깅용 worktree 보존

```bash
DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1 /qg branch feat-x
# 종료 후 .claude/quality-gates/worktrees/feat-x-<sid>/ 보존
# 수동 정리: git worktree remove <path>
```

### `/qg branch <name>` 자체를 비활성화

```bash
export DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1
```

`/qg branch` (인자 없음) 은 영향 없음.

## Plan Discovery Sources (차등 테스트의 test-scope-validator)

차등 테스트의 test-scope-validator가 `--plan <path>`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 (`scripts/discover-plan.sh`; 위→아래로 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--plan <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/plans/*.md` (project-local) | checkbox `- [ ]` / `- [x]` 1개 이상 |
| 3 | `~/.claude/plans/*.md` (legacy global) | project-local 비었을 때만 consult. hit 시 deprecation 경고 출력 |

선택된 source 내부에서: unchecked checkbox 있는 파일 우선, 동률이면 mtime 가장 최근. 모두 all-checked면 mtime 가장 최근 ("방금 끝낸 plan을 정상적으로 고른 것").

**Soft dependency:** project-local source는 `superpowers:writing-plans` skill이 plan을 저장하는 경로 (`docs/superpowers/plans/`) 와 동일합니다. superpowers 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-plan.sh`(적격성 술어 + source 우선순위)와 그것이 source 하는 `scripts/discover_common.sh`(디렉토리 스캔 + mtime 선택)에 분리되어 `tests/test_discover_plan.sh` 12개 fixture로 검증됩니다.

## Spec Discovery Sources (test-scope-validator + codex)

test-scope-validator와 codex가 명시적 spec 경로를 받지 않으면 다음 우선순위로 사용자 프로젝트의 **spec**(Acceptance Criteria의 truth)을 탐색합니다 (`scripts/discover-spec.sh`; 위→아래 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--spec <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/specs/*.md` (project-local) | `^#+ .*Acceptance Criteria` 섹션 헤더 1개 이상 |

plan과 달리 **legacy-global 소스는 없습니다** — spec은 프로젝트 artifact (글로벌 위치 관행 부재). 자격 파일 중 mtime 가장 최근이 선택됩니다.

**advisory only.** spec이 발견되면 test-scope-validator가 그것을 1차 축으로 테스트 파일을
분류하고, codex 경로(`run_codex_reviewer.sh`)가 spec의 AC 섹션을 `<spec_context>`에
script-internal로 주입합니다. 어느 경우에도 판정을 **막지 않습니다.** spec이 없으면 loud
log를 출력하고 plan-기반 분류로 fallback합니다.

**kill switch:** `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` — spec이 있어도 no-spec 경로를 강제 (codex `<spec_context>` 비움; validator는 plan-기반 분류).

**Soft dependency:** project-local source는 `superpowers:brainstorming` / `spec-distill`이 spec을 저장하는 경로 (`docs/superpowers/specs/`)와 동일합니다. spec-distill / `superpowers:brainstorming` 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-spec.sh`(적격성 술어 + source 우선순위)와 그것이 source 하는 `scripts/discover_common.sh`(디렉토리 스캔 + mtime 선택)에 분리되어 `tests/test_discover_spec.sh` 9개 fixture로 검증됩니다.

## 사전 요건

- **Python 3.12+** — 이 플러그인의 훅이 요구하는 바닥입니다. 숫자는 도출된 값입니다 —
  「2026-10 이후에도 패치를 받는 버전 중 최빈」, 다음 재검토는 3.12 EOL(2028-10).
  바닥 미만이면 훅은 **막지 않고** 건너뜁니다. 그 사실을 알리는 세션 시작 안내는 이 플러그인의
  `SessionStart` 훅 자리 하나에서만 나갑니다 — devbrew 전체에서 그 자리는 여기뿐이라,
  이 플러그인 없이 다른 devbrew 플러그인만 설치하면 안내 없이 조용히 건너뜁니다.
  `$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다.

| 플러그인 | 필수 | 사용처 | 목적 |
|---------|------|-------|------|
| pr-review-toolkit | 아니오 | 리뷰어 | 추가 리뷰어(code-reviewer 강한 default 등); 미설치 시 graceful degrade |
| feature-dev | 아니오 | 리뷰어 | 컨벤션 리뷰, 아키텍처, 구현 추적 |
| superpowers | 아니오 | 리뷰어 | plan 정합성, 증거 검증 |

## 설정

### Tuning knobs

- `MAX_REVIEW_ITERATIONS`: 5 (파이프라인 fix-loop iteration 수)
- `DEVBREW_QUALITY_GATES_TTL_HOURS`: 24 (sibling 세션 폴더 TTL; 더 오래된 폴더는 `/qg` 또는 `/cancel-qg --gc`에서 GC)
- `DEVBREW_QUALITY_GATES_GC_VERBOSE`: unset (`1`로 설정 시 GC sweep 진단을 stderr로)
- `DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1`: `/qg branch` worktree cleanup 비활성화 (디버깅용 보존)

**`.claude/quality-gates/baseline-cache/`** (v3.0.0) — `(merge_base, runner, unit)` 내용주소
기준선 테스트 결과 캐시. `qg-gc.py`의 TTL sweep 대상이 **아니다**(design §11 ⑩) — merge_base
마다 파일이 하나씩 쌓이고 자동 정리 경로가 없다. 정리는 `/cancel-qg --all`에 위임한다.

### Kill switches (보안 컨트롤)

CLAUDE.md Plugin Shape: *"kill switch는 보안 컨트롤"*. 모든 component 비활성화 경로는 환경 변수 한 번으로 cover되어야 함. 아래는 source-of-truth 인벤토리.

**전역 (모든 hook + 모든 reviewer 비활성화):**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE=1` | 모든 quality-gates hook + `qg-gc.py` no-op. `/qg`는 invocable 하지만 SKILL Preflight P1 이 즉시 리턴한다 — `setup-qg.sh` 도 agent 도 부르지 않는다(판정 자체가 나지 않는다 — `not-certified` 도 아니다). |

**각도 · 리뷰어 단위 disable:**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` | optional `codex-reviewer` 완전 skip (model-family diversity layer off). `scripts/detect_codex.sh`가 우선 검사. |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1` | 보안 각도의 `security-reviewer`만 skip. 재비판 · codex · 추가 리뷰어는 여전히 fire. **판정이 `not-certified (angle-absent)` 가 된다** — 탐지 0 이어도. 형제 `DISABLE_CODEX`는 다른 전제 각도라 부재를 공시만 한다. |

**차등 테스트 · 스코프 단위 disable:**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1` | `/qg branch <name>` auto-worktree 기능 disable (`/qg branch` no-arg는 영향 없음). |
| `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE=1` | spec 발견 시에도 no-spec 경로 강제 (codex `<spec_context>` 비움; validator는 plan-기반 분류). |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | ② 차등 테스트를 통째로 건너뛴다(리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다). 판정은 `not-certified (kill-switch)` 다 — `clean` 도 실패도 아니다. |

**`DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX`** 는 qg 파이프라인에서 더 읽히지 않는다
(샌드박스 executor 가 사라졌다). `scripts/qg-worktree.sh create-sandbox` 는 남아 있고 그 소비자는
`plugins/plugin-audit` 의 자체 테스트 격리다 — 이 스위치는 그 소비자에게만 효력이 있다.

**Publish 단위 disable (`/qg-publish`, 게이트 아님):**

| Env var | 효과 |
|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` | **두 최내부 sink에서 결정론 강제**(skill 진입 자체는 막지 않음): `comment-upsert.py`(코멘트 POST/PATCH)와 `pr-create.sh`(`git push` + `gh pr create`). 로컬 artifact 생성 + `--dry-run` preview는 그대로 동작하되 GitHub에 대한 실제 네트워크 쓰기만 fail-closed로 차단된다. |

**Hook 단위 disable** (`DEVBREW_SKIP_HOOKS=quality-gates:<key>,quality-gates:<key2>...`):

| Hook 키 | 위치 | 기능 |
|---|---|---|
| `quality-gates:session-start-advisor` | `hooks/session-start-advisor.py` | SessionStart — stale state 안내 (read-only) |
| `quality-gates:session-start-advisor:frontmatter-scan` | 위 hook의 sub-feature | Plugin 전체 agent frontmatter drift 스캔만 disable |
| `quality-gates:session-end-cleanup` | `hooks/session-end-cleanup.py` | SessionEnd — 현재 세션 폴더 cleanup |
| `quality-gates:qg-gc` | `scripts/qg-gc.py` | TTL-GC 스크립트. 훅이 아니지만 지목할 이름을 갖는다 — 그전에는 전역 스위치 하나뿐이라 "이 GC만 끈다"가 불가능했다. `.claude` 를 의도적으로 링크로 쓰면 GC 는 `/qg` 마다 거부 줄을 내고 돌지 않는다 — 이 키로 끈다 |

훅 키에 더해 **이벤트명 별칭**도 받는다 — `quality-gates:SessionStart` · `quality-gates:SessionEnd`. spec-distill 훅이 쓰던 형태를
전 플러그인으로 통일한 것이다(한 플러그인에서 배운 형태가 다른 곳에서 조용히 안 먹는 것이
결함이고, kill switch 는 보안 컨트롤이라 그 결함의 방향이 fail-open 이다). 대조는 **전체 토큰**이라
`quality-gates:session-start-advisor:frontmatter-scan` 같은 더 긴 키가 `quality-gates:session-start-advisor`
를 접두 오매칭으로 함께 끄지 않는다.

(`MAX_TOTAL_ITERATIONS`와 cross-gate restart 루프는 v1.5.0에서 제거됨.)

## 파이프라인 state

state는 Claude Code 세션마다 `.claude/quality-gates/<session-id>/`에 추적됩니다:

- `pipeline.md` — 파이프라인 frontmatter (session_id · started_at · 선택적 worktree_path) + body (History).

Review scope 자체는 세션 state 로 추적되지 않는다 — `/qg` 매 턴 git 에서 직접
도출된다(branch diff against base, worktree 자체 변경분과 union).

stale sibling 폴더(mtime이 `DEVBREW_QUALITY_GATES_TTL_HOURS`(기본 24h)보다 오래된)는
`/qg` 또는 `/cancel-qg --gc` 실행 시 garbage-collect됩니다. `SessionStart` hook은
strictly read-only (CLAUDE.md 룰); `SessionEnd` hook은 정상 종료 시 현재 세션
폴더를 제거. crash는 TTL sweep으로 fallback.

모든 파일은 `*.local.md` gitignore 패턴에 매칭되며, 별도의 `.gitignore` 변경은
필요 없습니다.
