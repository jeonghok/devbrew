---
type: interview-seed-audit
payload: 2026-09-28-resolve-audits-interview.md
created_at: 2026-09-28
session_id: c4c858a4-126e-4ec2-b6d1-d5a167e5416d
source: spec-distill framing-requests
---

# resolve-audits — Interview Seed Audit

> 순수 텔레메트리 — 다음 세션의 첫 턴 `/interview @<seed 경로>` 가 가리키는 것은 payload(seed)
> 파일이고, 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.

## 1. 원문

- 요청(`/spec-distill:framing-requests` 인자): 「audit 폴더에 있는거 해결하고 최대한 지우려고 해」
- 워크트리 질문에 대한 답: 「만들고 시작 (권장)」
- 워크트리 질문 도중 사용자가 보낸 메시지: 「audits 폴더는 이제 안쓰거든」

## 2. 질문 전체

### 라운드 0 (워크트리)

- 물은 것: `feature/resolve-audits` 워크트리를 만들고 거기서 시작할까요? 이 브랜치 하나에서 인터뷰·설계·계획·구현까지 갑니다. (origin/main 에 없는 커밋 13개 — 워크트리 기본 base 엔 안 들어온다. 현재 브랜치 feature/review-stopping-criterion 의 docreview 작업분입니다) 거절하면 현재 디렉토리에서 진행합니다.
  - 선택지: 만들고 시작 (권장) / 현재 디렉토리에서
  - 당신이 답한 것: 만들고 시작 (권장)

### 라운드 1

- 물은 것: audit 문서들에 남은 열린 항목(합쳐 약 20건: §7-4 secret 스캔 구멍 · project-init A6-1/CX-2 · 선재 RED 2건 · seam/adjudication 잔여 조각 등)을 이번에 어떻게 다룰까요?
  - 선택지: 전부 실제로 고친다 / 실제 구멍만 고친다 / 고치지 않고 넘긴다 / 버린다
  - 당신이 답한 것: 실제 구멍만 고친다
- 물은 것: 문서를 지울 때 남겨야 할 것(열린 항목·재사용 지식 — 예: 분할 시 부재 락이 약해지는 실패 클래스, rc 124 함정)이 있다면, 앞으로 그런 것을 어디에 두시나요?
  - 선택지: GitHub issue / auto-memory / 관련 코드 옆 / 남기지 않는다
  - 당신이 답한 것: 남기지 않는다
- 물은 것: `/plugin-audit` 은 지금 산출물(리포트·data.json·journal)을 `docs/audits/` 에 커밋하고, 검증기가 CLAUDE.md 에 `docs/audits/` 포인터를 요구합니다. 폴더를 안 쓰게 되면 이 플러그인은 어떻게 할까요?
  - 선택지: 산출 경로를 옮긴다 / plugin-audit 제거 / plugin-audit 전용으로 둔다
  - 당신이 답한 것: 산출 경로를 옮긴다
- 물은 것: `docs/archive/audits/`(완료로 옮겨 둔 감사 5건 + codex 측정 디렉토리 4개)도 이번 정리 대상인가요?
  - 선택지: 포함한다 / 제외한다
  - 당신이 답한 것: 포함한다

### 라운드 2

- 물은 것: plugin-audit 산출물(리포트 .md · data.json · journal.jsonl)을 어디로 보낼까요?
  - 선택지: 커밋 안 하는 state / 호출자가 경로 지정 / 다른 커밋 경로
  - 당신이 답한 것: 커밋 안 하는 state
- 물은 것: `2026-07-15-project-init-audit-data.json` 은 plugin-audit AC6 회귀 테스트의 기준선입니다(테스트가 실행 시 읽음). 어떻게 할까요?
  - 선택지: fixtures 로 옮긴다 / 테스트째 지운다
  - 당신이 답한 것: fixtures 로 옮긴다
- 물은 것: CHANGELOG · docs/superpowers/{specs,plans,interview} 약 40개 파일이 지워질 감사 문서 경로를 인용합니다. 이 역사 기록 속 참조는 어떻게 할까요?
  - 선택지: 그대로 둔다 / 전부 고친다
  - 당신이 답한 것: 그대로 둔다
- 확인 질문: 라운드 0 도중 메시지 · 라운드 1 의 풀이
  - 내가 읽은 것: 「docs/audits/ 에는 앞으로 새 기록을 쌓지 않으므로 CLAUDE.md 의 `## Audits` 절이 말하는 축적 관례도 함께 끝난다.」 — 고름
  - 내가 읽은 것: 「실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다.」 — 고름
  - 내가 읽은 것: 「감사 문서의 재사용 지식과 버리는 열린 항목은 다른 곳으로 옮기지 않고 git 이력을 유일한 보존처로 둔다.」 — 고름

### 라운드 3 (확인만)

- 확인 질문: 라운드 1 · 라운드 2 의 풀이 · 원 요청
  - 내가 읽은 것: 「docs/archive/audits/ 도 같은 기준으로 실제 구멍만 고치고 폴더째 없앤다.」 — 고름
  - 내가 읽은 것: 「plugin-audit 산출물은 git-ignored 인 `.claude/plugin-audit/<session-id>/` 에 쓰고, 검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다.」 — 고름
  - 내가 읽은 것: 「AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다.」 — 고름
  - 내가 읽은 것: 「CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다.」 — 고름
  - 내가 읽은 것: 「이번 작업의 끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것이다.」 — 고름

## 3. 긴 초안

**요청의 뼈대.** 사용자는 `docs/audits/` 에 있는 것을 «해결하고 최대한 지우려» 한다. 도중에 «audits 폴더는
이제 안쓰거든» 이라고 덧붙였다. 확인 질문에서 확정된 것: 끝 상태는 `docs/audits/` 와 `docs/archive/audits/`
두 폴더의 부재 + 그로 인해 깨지는 테스트·플러그인 0 · CLAUDE.md `## Audits` 절의 축적 관례 종료 ·
열린 항목은 «실제 구멍»(지금 발동 중인 결함)만 고치고 잠재 항목은 버림 · 지식과 버리는 항목은 어디로도
옮기지 않고 git 이력만 보존처 · archive 포함 · plugin-audit 은 산출을 git-ignored state
(`.claude/plugin-audit/<session-id>/`)로 옮기고 검사기의 README 링크·CLAUDE.md 포인터 요구 제거 ·
AC6 기준선 json 은 plugin-audit 의 tests/fixtures 로 이동 · 역사 기록(CHANGELOG · docs/superpowers)
속 경로 참조는 그대로.

**이력.** 2026-08-16 weight-reduction 인터뷰가 C9·C12·C13 으로 «docs/audits/ 만 아카이브 행이고,
결국 이것도 해결 후 제거할 것이다» 를 확정했고, 그 뒤 일부(project-init 감사 md·journal · 억제 census ·
codex 측정 4개 · codex 통일 리뷰 · agent-tools 락 갭)가 `docs/archive/audits/` 로 옮겨졌다. 같은 사이클의
C10 은 «어떤 변경도 락의 순감을 만들지 않는다» 였다 — 이번 작업의 테스트 단언 제거와 긴장이 있다.

**인벤토리(Phase 0 읽기 전용 탐색 결과 — 미실측).**
- `docs/audits/` 8개(README 포함, 약 3,400줄):
  - `2026-07-15-project-init-audit-data.json` — project-init v1.7.2 감사 원데이터. 열린 finding 2건:
    A6-1 HIGH (S4(i) 가 divergent CLAUDE.md 를 내용 이관 없이 한 줄 포인터로 재작성 —
    `plugins/project-init/commands/project-init.md:164` 문구 그대로) · CX-2 CRITICAL (trunk-based
    Pattern B 가 `git checkout main` → `git checkout -b release/v1.x` — legacy release 를 현재 main 에서
    자름). AC6 회귀 테스트(`test_ac6_regression.py:7`)와 일회용 추출기(`fixtures/ac6_build.py:16`)가 읽음.
  - `2026-07-27-spec-distill-zero-tool-probe.md` — `tools: []` 격리의 ZERO_TOOL_OK 실측. 자동 회귀 없음
    (잠재). `test_brief_review_no_external_precondition.sh:48-50` 이 이 파일의 존재를 단언 — 지우면 RED.
  - `2026-08-21-skill-split-lock-corpus-shrink.md` — 지식 문서 + §7 이월 backlog. 해소 4건(§7-1·3·8·9).
    열림: §7-2(잠재 — 마커가 아직 SKILL.md 안) · §7-4(**발동 중** — `plugins/quality-gates/references/`
    가 `test_no_secret_prompts.py` 의 `skills/*/references/*.md` glob 밖, P21 secret 스캔 누락) ·
    §7-5(채택자 3개 이상인데 `test_proceed_gate_adopters.sh:185-190` 이 라벨만 봄 — 발동 조건 성립이라
    탐색이 보고) · §7-6(`./references/` 표기 거부 없음) · §7-7(요약본-정본 정합 락 없음) · §7-10(20줄 창
    한계 미기재) · §7-11(`run-own-tests.sh:102` 접두 도출 아님). `shared/tests/test_no_new_duplication.sh:247`
    이 경로를 주석 인용.
  - `2026-08-23-dispatch-lock-mutations.md` — mutation 실행 기록. 열린 항목 없음. 바로 삭제 가능.
  - `2026-08-27-adjudication-topology-handoff.md` — 대부분 판정 지형 spec(PR #138)·docreview 엔진으로 흡수.
    잔여: M1 `consumer=human` 앵커 3건 · M4 `artifact-adversarial`·`audit-refuter` 잔존 · M2 방향이 실제로는
    공유 recritic 으로 감(UNCLEAR). 설계 방향 항목이지 결함은 아님.
  - `2026-08-27-cross-skill-seam-handoff.md` — F1·F2·A1·A3·B1·D1 해소. 잔여: A2 `surfaced()` 프로덕션
    호출 0(추정) · A6 `smoke-workflow.js:11` 의 `disclosure=sentinelPath` · B2 conducting-interview SKILL 에
    reviewing-brief 언급 0 · F3/A4 degrade 별도 계산 · probe 2건(systemMessage 반대 명제 · skill→skill 전이).
  - `2026-09-21-python-floor-baseline.md` — 본 작업 완료(558d820f). 선재 RED: `test_cancel_all_fence.sh`
    인덱스 모드 100644(**실패 중**) · `test_no_write_matcher_hooks_repo.sh` 가 Bash matcher ≥2 요구인데
    1개(**실패 중**) · `test_codex_backward_compat.sh` 는 34b03370 이 고쳤을 수 있음(UNCLEAR).
    rc 124 함정·mock hang·fixtures 배제 규칙은 이 문서에만 있음 — 사용자 결정으로 버림.
  - `README.md` — archive 파일들의 유일한 인덱스.
- `docs/archive/audits/`: project-init 감사 md·journal(열린 finding 은 위 json 과 같은 2건) ·
  agent-tools 락 값 경로 갭(①null 동의어 ②flow mapping ④L3 sed `LC_ALL=C` 열림, ③해소) · 억제 census
  (완료) · codex 통일 브랜치 리뷰(A1 `run_audit_codex_reviewer.sh:121` `web_search="live"` 열림, 나머지
  대부분 대상 파일이 교체돼 무효/UNCLEAR) · codex 측정 디렉토리 4개(기록).

**폴더에 묶인 활성 표면.**
- `plugins/plugin-audit/`: `skills/auditing-plugins/SKILL.md:160-198` 의 canonical 경로 ·
  `scripts/render-audit-report.py:186-194`(README 인덱스 갱신) · `scripts/validate-audit-data.py:143-148`
  (README 링크 · CLAUDE.md 에 `docs/audits/` 문자열 요구) · `scripts/assemble-audit-data.py:236`(mkdir 없음) ·
  `README.md:71-72`(Principles Instantiated 의 Law 3 줄이 «커밋된 감사 기록»을 근거로 댐) ·
  `tests/test_validate_audit_data.py`(포인터 요구를 잠그는 케이스들) · `tests/test_skill_orchestration.py`
  (SKILL 문자열 `--out docs/audits/…` 을 잠금).
- `CLAUDE.md:99` `## Audits` 절.
- 주석 인용: `shared/tests/test_no_new_duplication.sh:247` · `test_proceed_gate_adopters.sh:187`.
- 역사 면제 정규식: `plugins/spec-distill/tests/test_review_hook_removed.py:110-111` — 무해.

**«실제 구멍» 후보(저자 분류 — 미확인).** 발동 중: §7-4 secret 스캔 누락 · A6-1 · CX-2 · 선재 RED 2건.
경계: agent-tools 락 갭 ①②④(지금 위반하는 agent 는 없지만 검사가 비어 있음) · codex A1 · §7-5 ·
`test_codex_backward_compat.sh`. 잠재(버림): §7-2·6·7·10·11 · zero-tool 회귀 부재 · seam/adjudication 잔여
설계 항목.

**열린 설계 질문(하류 몫).** state 규약은 «성공 시 auto-delete» 인데 감사 리포트는 사람이 읽어야 하는
산출물 — 언제 지우나. plugin-audit README 의 Law 3 줄을 무엇으로 바꾸나. 존재 단언 제거가 C10 의 «락 순감
금지»와 어떻게 화해하나(단언의 목적이 «감사 기록 보존»이었으니 목적 자체가 사라진다고 볼 수 있다).
플러그인 버전 bump 대상: plugin-audit · spec-distill · (구멍 수정 시) quality-gates · project-init ·
shared 는 플러그인 아님. PR 분할 여부.

## 4. 비평과 냉독

### 라운드 1 — 탐지 (doc-critic)

> ```docreview-layer1
> []
> ```
>
> ```docreview-layer2
> []
> ```
>
> I found nothing to flag in layer 1 or layer 2. Here is what I checked.
>
> **Every «(사용자 확인)» sentence traces to a 「고름」 reading.** The seed has 8 sentences marked «(사용자 확인)». In `## 2. 질문 전체`, round 2 has 3 「고름」 readings and round 3 has 5. Each of the 8 seed sentences matches one of those readings word for word:
> - 축적 관례 종료
> - 실제 구멍 정의
> - git 이력이 유일한 보존처
> - archive 포함·폴더째 제거
> - plugin-audit 산출물을 `.claude/plugin-audit/<session-id>/` 로 옮기고 검사기 요구 제거
> - AC6 기준선을 fixtures 로 이동
> - 역사 기록 참조는 그대로 두고 활성 참조만 수정
> - 끝 상태
>
> None of them is an inference passed off as a decision.
>
> **The unmarked sentences follow from the answers.**
> - 「플러그인 자체는 남긴다 — 제거하는 안은 고르지 않았다」 follows from the answer 「산출 경로를 옮긴다」. It honestly records that the user did not choose removal, so it is not a closure.
> - 「이관하는 작업이 아니다」 restates 「남기지 않는다」.
>
> **The 2026-08-16 weight-reduction claim is not in this session's ground truth, but the repo confirms it.** `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits/docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md` has the confirmed C12 at line 221. At line 403 it quotes the user: "이거만 아카이브 행, 결국 이거도 해결 후 제거할거임". The seed uses this as background only and adds no new requirement from it, so it is not an unfounded addition.
>
> **No example was promoted to a requirement.** The list in the round-1 question (§7-4 · A6-1/CX-2 · 선재 RED 등) was written by the author, not the user. The seed treats the resulting 5 candidates plus the borderline ones only as items to measure.
>
> **The 「다시 검증할 것」 section keeps the questions open.** It says the classification of which items are real holes is a candidate, not settled. It leaves open three things: whether the pre-existing REDs are bugs or stale tests, the tension with the no-net-lock-reduction rule (락 순감 금지), and the risk that state auto-delete removes the report before anyone reads it. This matches the user's answer 「실제 구멍만 고친다」 and does not close any choice the user left open.

### 라운드 1 — codex

> findings:
>   - agent: codex-reviewer
>     ref: x1
>     layer: 1
>     category: premature_closure
>     anchor: "#__doc__"
>     disposition: fix
>     summary: «최대한 지우기»를 두 폴더의 완전 삭제라는 확정된 완료 조건으로 닫았다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 사용자 원문은 «audit 폴더에 있는거 해결하고 최대한 지우려고 해», «audits 폴더는 이제 안쓰거든»이며 archive에 대한 답은 «포함한다»이다. 초안은 «두 폴더가 리포에서 사라지고»와 «폴더째 없앤다»를 사용자 확인으로 표시한다. 이에 대응하는 라운드 3의 «내가 읽은 것 … 고름»은 지정된 ground truth가 아니다.
>     replacement: 두 감사 폴더를 정리 대상으로 삼아 실제 구멍만 고치고 최대한 삭제한다. 폴더 전체 삭제를 확정된 완료 조건으로 두지는 않는다.
>     if_unfixed: 정리 과정에서 보존 필요성이 드러나도 폴더 전체 삭제가 이미 승인된 조건으로 취급된다.
>   - agent: codex-reviewer
>     ref: x2
>     layer: 1
>     category: inference_as_decision
>     anchor: "#__doc__"
>     disposition: fix
>     summary: «실제 구멍»의 구체적인 판정 기준을 저자의 풀이에서 사용자 결정으로 승격했다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 사용자가 답한 것은 «실제 구멍만 고친다»이다. «지금 발동 중인 결함», «발동 조건이 아직 성립하지 않은 잠재 항목은 … 버린다»라는 정의는 라운드 2의 저자 작성 «내가 읽은 것»에만 있다. 초안은 이를 «기준은 하나다»와 «(사용자 확인)»으로 확정하고, 후반의 검증도 «지금 정말 발동 중인지»로 한정한다.
>     replacement: 실제 구멍만 고친다. 무엇을 실제 구멍으로 볼지의 세부 기준은 아직 확정되지 않았다. 현재 발동 여부에 따른 분류와 각 후보는 검토 가설로 둔다.
>     if_unfixed: 현재 발동하지 않는다는 이유만으로 실제 결함일 수 있는 항목이 검토 대상에서 제외될 수 있다.
>   - agent: codex-reviewer
>     ref: x3
>     layer: 1
>     category: inference_as_decision
>     anchor: "#__doc__"
>     disposition: fix
>     summary: 사용자가 선택한 방향에 구체적인 경로와 수정 범위를 덧붙여 모두 사용자 확인으로 표시했다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 실제 답변은 «산출 경로를 옮긴다», «커밋 안 하는 state», «fixtures 로 옮긴다», 역사 참조는 «그대로 둔다»이다. `.claude/plugin-audit/<session-id>/`, 검사기의 README 링크·CLAUDE.md 포인터 요구 삭제, `plugins/plugin-audit/tests/fixtures/`, «활성 코드·테스트·상시 문서 속 참조만 고친다»라는 구체화는 사용자 답변 줄에 없다. 라운드 3의 저자 풀이와 제공된 CLAUDE.md는 이 구체화를 사용자 결정으로 만드는 근거가 아니다.
>     replacement: plugin-audit은 유지하고 산출물을 커밋하지 않는 state로 옮긴다. AC6 기준선은 fixtures로 옮기며 역사 기록의 감사 경로 참조는 그대로 둔다. 구체적인 저장 경로, 검사기 요구의 변경 방식, 나머지 참조의 수정 범위는 구현 검토 사항으로 둔다.
>     if_unfixed: 구현자가 제안 경로와 검사기 요구 삭제를 이미 승인된 제약으로 받아들여 다른 적합한 변경 방식을 배제할 수 있다.
>   - agent: codex-reviewer
>     ref: x4
>     layer: 1
>     category: unfounded_addition
>     anchor: "#__doc__"
>     disposition: fix
>     summary: 과거 사이클의 결정과 «락 순감 금지»를 이번 작업에 적용되는 확정 사항으로 추가했다.
>     edit_scope: "#__doc__"
>     blocks: []
>     evidence: 초안은 «2026-08-16 weight-reduction 사이클이 이미 … 해결 후 제거하기로 정해 두었고»와 «같은 … 사이클이 확정한 락 순감 금지»를 단정한다. 지정된 사용자 원문·답변 줄에는 두 결정이 없고, 리뷰 결정도 «없음»이다.
>     replacement: 과거 사이클의 삭제 결정과 락 순감 금지를 확정 사항으로 인용하는 문구를 뺀다. 문서 존재를 단언하는 테스트의 처리 문제는 확인할 기술적 쟁점으로만 남긴다.
>     if_unfixed: 근거가 확인되지 않은 과거 결정이 삭제를 강제하거나 테스트 정리를 제한하는 추가 요구로 작동한다.
> meta:
>   codex_failed: false
>   exit_code: 0

### 라운드 1 — 재비판 (doc-recritic)

> ```docreview-recritic
> verdicts:
>   - f: f1
>     verdict: reject
>     evidence: "문서 `## 질문 전체` 라운드 2 확인 질문에 「내가 읽은 것: 「실제 구멍은 지금 발동 중인 결함(검사가 실제로 비어 있거나 배포된 동작이 틀린 것)이고, 발동 조건이 아직 성립하지 않은 잠재 항목은 고치지 않고 버린다.」 — 고름」이 있다. 프로필은 inference_as_decision 을 «(사용자 확인)» 문장이 `## 2. 질문 전체` 의 「고름」 풀이에 «없을» 때로 정의한다. 이 문장은 그 풀이에 그대로 있으므로 사용자가 확인한 결정이다. 후반의 «지금 정말 발동 중인지» 실측도 확정된 이 기준을 따른 것이지 새로 닫은 것이 아니다."
>   - f: f2
>     verdict: reject
>     evidence: "라운드 3 (확인만) 에 「plugin-audit 산출물은 git-ignored 인 `.claude/plugin-audit/<session-id>/` 에 쓰고, 검사기의 docs/audits/ README 링크·CLAUDE.md 포인터 요구는 없앤다.」 — 고름 · 「AC6 기준선 json 은 plugins/plugin-audit/tests/fixtures/ 로 옮겨 회귀 테스트를 그대로 유지한다.」 — 고름 · 「CHANGELOG 와 docs/superpowers 의 역사 기록 속 감사 경로 참조는 고치지 않고, 활성 코드·테스트·상시 문서 속 참조만 고친다.」 — 고름 이 있다. finding 이 지목한 구체화 세 가지(경로 · 검사기 요구 삭제 · 수정 범위)는 모두 사용자가 고른 풀이 문장과 글자 그대로 같다. 프로필 기준으로 inference_as_decision 에 해당하지 않는다."
>   - f: f3
>     verdict: reject
>     evidence: "라운드 3 에 「이번 작업의 끝 상태는 docs/audits/ 와 docs/archive/audits/ 가 리포에서 사라지고 그로 인해 깨지는 테스트·플러그인이 하나도 없는 것이다.」 — 고름 과 「docs/archive/audits/ 도 같은 기준으로 실제 구멍만 고치고 폴더째 없앤다.」 — 고름 이 있다. 원문 「audits 폴더는 이제 안쓰거든」도 같은 방향이다. 폴더 전체 삭제라는 완료 조건은 사용자가 확인 질문에서 직접 골랐으므로 저자가 조기에 닫은 것이 아니다."
>   - f: f4
>     verdict: reject
>     evidence: "문서에서 «락 순감 금지»는 `다시 검증할 것` 셋째 항목에만 나온다. 거기서도 「부딪혀 보일 수 있다」로, 확인해야 할 열린 긴장으로 적혀 있다. 테스트 정리를 막는 제약으로 닫혀 있지 않다. 「2026-08-16 weight-reduction 사이클이 … «해결 후 제거»하기로 정해 두었고」도 사용자 원문 「audit 폴더에 있는거 해결하고 최대한 지우려고 해」 너머의 요구를 더하지 않는 배경 서술이다. 두 주장 모두 근거가 있다. 이전 사용자 결정으로 리포에 기록돼 있다(docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md:221 C12 confirmed, :403 「이거만 아카이브 행, 결국 이거도 해결 후 제거할거임」, :394 「② 남기되 '락 순감 금지' 제약」). 이것을 빼면 앞 단계 결정과 부딪힐 수 있다는 사실을 설계 단계가 보지 못하게 된다."
> added: []
> ```
>
> <diff> 를 받지 않았으므로 «이 변경이 도입했는가» 축은 쓰지 않았다. 네 건 모두 기각했다.
>
> - **f1~f3:** 지적된 «(사용자 확인)» 문장이 전부 `## 질문 전체` 의 라운드 2·3 확인 질문에 「— 고름」으로 글자 그대로 있다. 프로필의 inference_as_decision 정의(«고름» 풀이에 없을 때만 해당)에 걸리지 않는다.
> - **f4:** 문서 안에서 «락 순감 금지»는 검증할 열린 긴장으로만 적혀 있다. 두 과거 결정은 리포의 이전 인터뷰에 사용자 원문으로 남아 있다(/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits/docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md:221, :394, :403).
>
> «(사용자 확인)» 문장 여덟 개를 모두 확인 질문의 「고름」 풀이와 대조했다. 층 1 에서 놓친 결함은 찾지 못했다.

### 냉독 (seed-readback)

> ## 무엇을 맡기려는 것으로 읽었나
>
> devbrew 리포에서 감사 기록 폴더 두 곳, `docs/audits/` 와 `docs/archive/audits/` 를 없애는 일입니다. 폴더를 지우기 전에 두 가지를 먼저 합니다.
>
> - **열린 항목 처리:** 문서에 남은 열린 항목 가운데 «지금 발동 중인 결함»만 골라 실제로 고칩니다. 나머지는 문서와 함께 버립니다.
> - **묶인 활성 코드 떼어내기:** 이 폴더에 묶인 활성 코드, 특히 `/plugin-audit` 과 그 검사기를 폴더에서 분리합니다.
>
> 끝 상태는 두 폴더가 리포에 없고, 그 때문에 깨지는 테스트나 플러그인이 하나도 없는 것입니다. CLAUDE.md 의 `## Audits` 절이 말하는 축적 관례도 함께 끝납니다. 그래서 그 절은 지우거나 고쳐야 할 대상으로 읽었습니다. 다만 절을 통째로 지우라는 말은 명시돼 있지 않습니다.
>
> 구체적으로 할 일은 이렇게 읽었습니다.
>
> - **plugin-audit 산출물:** 커밋되는 폴더 대신 git-ignored 인 `.claude/plugin-audit/<session-id>/` 에 씁니다. 플러그인 자체는 남깁니다.
> - **검사기 요구 제거:** 검사기가 요구하는 docs/audits README 링크와 CLAUDE.md 포인터 요구를 없앱니다.
> - **AC6 기준선 json:** `plugins/plugin-audit/tests/fixtures/` 로 옮겨 회귀 테스트를 살립니다.
> - **참조 수정 범위:** 활성 코드·테스트·상시 문서 속 경로 참조만 고칩니다. CHANGELOG 와 `docs/superpowers` 의 역사 기록은 건드리지 않습니다.
> - **보존:** 재사용 지식이든 버리는 항목이든 다른 곳으로 옮기지 않습니다. git 이력이 유일한 보존처입니다. backlog 이관 작업이 아니라는 점이 강조돼 있습니다.
>
> ## 방향
>
> **«해결 후 제거»의 마무리**로 읽었습니다. 2026-08-16 weight-reduction 사이클이 이미 이 폴더를 없애기로 정했고, 이번 일은 새 결정이 아니라 그 결정을 끝까지 수행하는 것입니다.
>
> 기준은 하나입니다. 실제 구멍, 곧 검사가 실제로 비어 있거나 배포된 동작이 틀린 것은 고치고, 발동 조건이 아직 성립하지 않은 잠재 항목은 버립니다. 가볍게 끝내려는 방향이지, 감사 backlog 를 청산하려는 방향은 아닙니다.
>
> ## 보낸 사람이 신경 쓰는 것
>
> **1. 후보 분류를 믿지 말고 실측할 것.** Phase 0 의 분류는 파일과 git 이력만 읽고 만든 후보이고, 테스트는 한 번도 돌리지 않았습니다.
>
> 발동 중으로 보인 후보는 다섯입니다.
> - qg `references/` 가 P21 secret 스캔 glob 밖에 있는 것
> - project-init 이 CLAUDE.md 를 내용 이관 없이 한 줄 포인터로 재작성하는 것
> - trunk-based 템플릿이 legacy release 브랜치를 현재 main 에서 자르는 것
> - 선재 RED 두 개: `test_cancel_all_fence.sh` 의 실행비트, `test_no_write_matcher_hooks_repo.sh` 의 Bash matcher 개수 기대
>
> 경계 후보는 넷입니다.
> - Law 2 `tools:` 락의 우회형: null 동의어, flow mapping, locale 없는 sed
> - codex 감사 러너가 웹 검색을 live 로 켜는 것
> - proceed 게이트 채택자 락이 라벨만 보는 것
> - `test_codex_backward_compat.sh` 가 이미 고쳐졌는지
>
> **2. 선재 RED 가 코드 쪽 결함인지 테스트가 낡은 것인지 가를 것.**
>
> **3. 폴더 삭제가 다른 규약과 부딪히는 자리를 놓치지 말 것.** 셋이 짚혀 있습니다.
> - `test_brief_review_no_external_precondition.sh` 가 zero-tool-probe 감사 문서의 존재를 단언합니다. 문서를 지우면 그 단언도 빠져야 하는데, 이것이 «락 순감 금지»와 충돌해 보입니다.
> - plugin-audit README 가 Law 3 을 «커밋된 감사 기록»으로 설명하는 줄이 거짓이 됩니다.
> - state 의 «성공 시 자동 삭제» 규약이 사람이 읽어야 할 감사 리포트를 읽기 전에 지울 수 있습니다.
>
> ## 읽으면서 «이건 모르겠다» 싶었던 곳
>
> - **경계 후보의 판정을 누가 하는지.** 기준의 정의에 «검사가 실제로 비어 있는 것»이 들어 있어서, 지금 그렇게 쓴 agent 가 없는 우회형 락 구멍도 «실제»로 읽힐 수 있습니다. seed 도 이 이중성을 스스로 인정합니다. 실측으로 이게 어떻게 갈리는지, 갈리지 않으면 누가 정하는지는 적혀 있지 않습니다.
> - **다섯 후보 밖의 열린 항목.** Phase 0 가 추리지 않은 항목은 재확인하지 않고 버리는지, 전수를 다시 봐야 하는지 모르겠습니다.
> - **선재 RED 판정 뒤의 처리.** 테스트가 낡은 것으로 나오면 테스트를 고치는지, 지우는지, 면제하는지 정해져 있지 않습니다. 지우는 쪽이면 락 순감 문제와 다시 얽힙니다.
> - **락 순감 충돌의 해소 방향.** 단언을 빼는 것이 순감으로 치는지, 다른 단언으로 대체해야 하는지 정해져 있지 않습니다. 문제 제기로만 남아 있습니다.
> - **state 로 옮긴 감사 리포트의 수명.** 자동 삭제 규약을 이 플러그인만 예외로 둘지, 사람이 읽을 경로를 따로 둘지 방향이 없습니다. Law 3 줄을 무엇으로 바꿀지, plugin-audit 이 여전히 Law 3 을 instantiate 한다고 말할 수 있는지도 모르겠습니다.
> - **«상시 문서»의 경계.** `docs/philosophy/*.md`, 플러그인 README, CLAUDE.md 는 들어가는 것 같습니다. 하지만 `docs/superpowers` 안에서 역사 기록이 아닌 것(활성 설계나 reference 역할을 하는 문서)이 있을 때 어떻게 할지는 불분명합니다.
> - **용어 몇 개.**
>   - «검사기»가 plugin-audit 내부 검사기인지 shared 테스트인지 확신이 없습니다.
>   - «AC6»가 어느 스펙의 AC 인지 적혀 있지 않습니다.
>   - project-init 의 «갈라진 CLAUDE.md» 가 무엇과 무엇이 갈라진 상태인지 모르겠습니다.
>   - codex 러너의 live 웹 검색이 왜 결함 후보인지(위협인지, 비용인지, 재현성인지) 설명이 없습니다.
> - **나머지 두 가지.** 여러 플러그인을 건드리게 될 텐데 PR 을 하나로 할지 나눌지, 버전 bump 범위는 말이 없습니다. 리포 규칙상 당연하다고 본 것일 수 있습니다. 2026-08-16 결정이 어디에 기록돼 있는지도 seed 만으로는 알 수 없습니다.

## 5. degrade

- `framing_degradations` 원장 없음 — `no-state-in-phase-0`: 이 세션에 `state.local.md` 가 없어 원장 init 을 하지 않았다(`ledger_rc=1`). 게이트 텍스트가 유일한 degrade 채널이다.
- 탐지(doc-critic) · 재비판(doc-recritic) 프롬프트의 「레포 CLAUDE.md」 칸에 번들의 CLAUDE.md 전문 대신 관련 두 절(`## Audits` · `### 런타임 상태 & 훅`)의 인용과 파일 경로를 실었다 — 리뷰어는 Read 로 전문을 읽을 수 있었다. codex 는 번들 파일 전체(전문 포함)를 읽었다.
- 격리 워크트리 세션의 Write 가 메인 체크아웃 쪽 엔진 state 경로를 거부해 `critic.txt` · `recritic.txt` 는 job tmp 에 쓴 뒤 `cp` 로 옮겼다(내용 무변경).
- 앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위 (엔진 advisory, 라운드 1).

## 6. 리뷰 결정
