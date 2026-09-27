# qg 토픽 스코프 배선 구현 계획 (PR4c/7)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 로 이 계획을 Task 단위로 실행한다. 단계는 체크박스(`- [ ]`) 표기다.

**Goal:** `Spec: <경로>[#<조각>]` 커밋 트레일러로 선언한 작업을 브랜치가 여럿이어도 **한 판정 단위**로 본다 — 기준선은 그 작업의 시작점(경계), HEAD 축은 워킹트리 봉인과 구성원 끝점을 순차 `merge-tree` 로 합친 트리, 판정 꼬리는 그 튜플(본 커밋 · 끝점 · 경계 · 합친 트리)을 싣는다. 선언이 없으면 동작이 바뀌지 않는다.

**Architecture:** PR1 이 남긴 호출자 0 의 스크립트 둘(`resolve-topic.sh` · `combine-tips.sh`)을 새 진입 모듈 `topic-head.sh` 하나로 묶는다 — 선언 감지 → 봉인 → 경계 · 끝점 → 합친 트리를 한 번에 풀어 `key: value` 튜플 파일 하나를 낸다. SKILL ① 이 매 iteration 그 파일을 쓰고, 차등 테스트의 R-init 이 그 파일에서 기준선(경계)과 HEAD 축(합친 커밋 → `create-head --topic` 이 지금 다시 도출해 대조)을 세우며, 합성기가 `--scope` 로 그 파일을 읽어 `declaration-invalid` · `merge-conflict` 사유와 `scope:` 블록을 낸다. 한 iteration 의 스코프 · diff · 테스트 트리 · 판정 튜플이 **한 트리**를 가리킨다.

**Tech Stack:** bash 3.2 호환(스크립트 · 락) · Python 3.9+ 시스템 `python3`(3.10+ 문법 금지, 표준 라이브러리 + PyYAML) · `shared/tests/assert.sh` · git 2.54(`merge-tree --write-tree` 필요 — 2.38+)

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.2.1–§6.2.6(선언 · 커밋 집합 · 경계 · 합친 트리 · 세 모드 · 산출물) · §6.4.1(봉인자 · `create-head` 대조) · §6.4.3(사유 `declaration-invalid` · `merge-conflict`) · §11(AC3 · AC4 · AC5 · AC6 · AC7 · AC15 · AC16 의 선언 쪽) · §13 · §16(4c 행 · P23 재결정 2026-09-25 · 2026-09-26)

---

## Global Constraints

설계와 앞 PR 이 정한 것을 그대로 옮긴다. 모든 Task 의 요구사항에 암묵적으로 포함된다.

- **선언이 없으면 아무것도 바뀌지 않는다**(§6.2.5 · AC16) — `no-declaration` 은 어느 `not-certified` 사유도 내지 않고 기존 세 모드(session · `branch` · `--paths`)로 내려간다. `branch` · `--paths` override 는 토픽을 보지 않는다.
- **토픽 키는 트레일러 값 «전체»다 — 조각까지 포함한다**(§6.2.2). `…#pr1` 과 `…#pr2` 는 다른 토픽이다.
- **판정 어휘는 `scripts/verdict.py` 밖에 두지 않는다**(PR2). `scope_tuple.py` 는 `status:` → 사유 **매핑**만 갖고, 값은 `verdict.REASONS` 안이며 `verdict.decide()` 가 검증한다. 사유 열거는 11 그대로다(`N:11` 락).
- **공시와 차단은 다른 술어다**(헌장). 스코프 튜플은 언제나 드러내되, 막는 것은 매핑된 사유 둘뿐이다.
- **fail4 계약은 원자적이다** — 실패 경로에서 stdout 에 아무것도 쓰지 않는다. exit 코드 셋: `0` 정상 · `2` 잘못된 **호출** · `4` 실패한 **판정**. 파이썬 traceback(exit 1)은 계약 위반이다. 셸 스크립트의 `die` 는 exit 2 다.
- **봉인 · 합치기 커밋은 ref · reflog 를 얻지 않는다** — git 의 prune 이 회수한다(R-AN). 어떤 Task 도 `git update-ref` · `git branch` · `git tag` 로 qg 커밋을 붙잡지 않는다.
- **비신뢰 입력에 거는 정규식은 `fullmatch`**(`$` 는 끝 개행 앞에서도 맞는다).
- **스윕은 `git grep -n -P`**(단어 경계가 필요하면 `-w`/`-P`; `git grep -E` 의 `\b` 는 이 git 에서 조용히 0건이다).
- **락은 same-line · 부정형 거부 · 목적지 양의 단언으로 쓴다.** 창/섹션 단위 grep 은 다른 행이 만족시켜 뒤집기를 못 잡는다(PR4b 교훈). 부재 락에는 양의 짝을 둔다. 열거가 필요한 락은 코드의 열거(`scope_tuple.STATUSES` 등)에서 **도출**한다.
- **`check_wiring.py` 의 `synthesize_findings.py` 면제 키는 줄번호다** — 합성기를 고치는 Task(4)가 같은 커밋에서 실측으로 재앵커한다(`bash shared/tests/test_adjudication_wiring.sh` 의 `exempt_stale=0` 이 답한다). 주석에 델타를 적지 않는다.
- **SKILL 의 bash 펜스 안에서 `git ` 으로 시작하는 줄은 `test_a20_tool_agnostic_scope.py` 가 session 합집합으로 끌어가 실행한다** — 토픽 경로의 git 질의는 대입으로 시작하는 한 줄로 쓴다(Task 7). 그 락은 session 경로의 오라클이다.
- **레퍼런스(`differential-test.md`)에 새 `§` 절 번호를 쓰지 않는다**(Task 6 락). 설계를 가리켜야 하면 절 번호 없이 개념으로 적는다.
- **자기서사 금지.** SKILL · 레퍼런스 · 스크립트 주석 · persona 는 모델이 읽고 행동하는 산출물이다 — 새 문장에 「이 문단은 PR4c 에서…」 같은 이력을 넣지 않는다. 이력은 CHANGELOG · PR 본문에 둔다.
- **범위 불변식** — 아래 경로는 한 바이트도 바뀌지 않는다: `shared/**` · `plugins/spec-distill/**` · `plugins/plugin-audit/**` · `.claude-plugin/marketplace.json` · 루트 `CLAUDE.md` · `plugins/quality-gates/agents/**` · `plugins/quality-gates/references/recritic-code-profile.md` · `plugins/quality-gates/scripts/{seal-worktree.sh,diff-test-results.py,check_qa_ledger.py,verdict.py,angles.py,recritic_bridge.py,qg-gc.py,gc_common.py}` · `plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 밖 바이트. Task 12 가 대조한다.
- **커밋 본문에서 `Spec: ` 로 시작하는 줄은 트레일러 단락의 한 줄뿐이다.** `detect` · `nkeys` 는 원시 메시지(`%B`)의 `^Spec: ` 줄을 전부 키로 센다 — 본문 단락이 `Spec: 트레일러 …` 로 시작하면 이 PR 의 토픽이 「키 둘」로 `declaration-invalid` 가 되어 영영 풀리지 않는다(모의 실행 실측). 본문에서 그 낱말을 쓰려면 백틱으로 감싸 줄 첫머리에 두지 않는다.
- **커밋 트레일러** — 마지막 `-m` 단락 **하나**에 `Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c` 와 `Co-Authored-By: <그 커밋을 쓴 실제 모델>` 두 줄.
- **버전은 브랜치에서 정하지 않는다** — 머지 직전에 `origin/main` 을 다시 보고 정한다(새 능력 · 비-breaking → minor).
- **최신화는 merge, rebase 금지.** 워크트리 격리 — 세션이 치는 명령에서 메인 체크아웃으로 `cd` 금지, `git -C` 금지(제품 스크립트 안의 `git -C` 는 이 규칙의 대상이 아니다), bare `git stash` 금지.
- **명령은 워크트리 루트에서 돈다 — 계산된 경로를 쓰지 않는다.** 이 세션의 격리 가드는 계산된 `cd` · git 에 넘기는 셸 배열 · git 을 감싼 `for` 루프 · 변수로 계산한 경로로 도는 `bash`/`python3`/`sed` · 명령 문자열 속 「github」를 거부한다. 계획 문면의 `$CLAUDE_JOB_DIR` 는 **호출 전에 절대 경로 리터럴로 풀어** 쓴다. 가드가 거부하는 모양은 `$CLAUDE_JOB_DIR/tmp/` 아래 스크립트 파일로 쓰고 그 파일을 돌린다 — 파일 **안**의 셸 구문은 이 규칙의 대상이 아니다.
- **`PYTHONDONTWRITEBYTECODE=1`** 로 돌린다. 파이썬 편집마다 `python3 -m py_compile` 로, 셸 편집마다 `bash -n` 으로 확인한다.
- **`plugins/quality-gates/tests/*.sh` 는 git 모드 100755** 여야 한다(qg shell 어댑터가 실행비트로 claim 한다). 새 테스트 파일은 `chmod +x` 후 `git add`.
- **워크트리와 `$CLAUDE_JOB_DIR/tmp` 는 세션 재개에 사라진다.** git-ignored 산출물(기준선 TSV · 변이 표 · SDD 원장)은 매 갱신마다 `~/.claude/sdd-mirror/qg-topic-scope-pr4c/` 로 복사한다.
- **계획 문면의 인라인 코드 안 `\``는 백틱 하나를 뜻한다.** 펜스 블록 안의 문면은 **글자 그대로** 옮긴다. 옮기기 전에 목적지 파서로 검증한다(`bash -n` · `python3 -m py_compile`).
- **계획이 인용한 옛 문구는 원문에서 줄바꿈을 가로지를 수 있고 마크업이 다를 수 있다.** 한 줄 grep 이 0 이면 앞 서너 단어로 찾아 그 문장 **전체**를 고친다. 인용이 원문과 뜻까지 다르면 멈추고 보고한다(계획 결함).

## Review Focus

스펙이 함의하지만 어느 Task 의 기본 테스트도 태우지 않는 입력 중, 쓰는 사람을 가장 먼저 물 다섯. 각 줄의 테스트는 소유 Task 에 들어가 있다.

1. **아직 머지 안 된 앞 조각 위에 쌓은 브랜치**(한 브랜치가 `#pr4b` · `#pr4c` 를 함께 담음) → 조용히 한 토픽으로 합치지 않는다. `declaration-invalid` 로 드러나고 봉인도 뜨지 않으며, 리뷰 · 차등 테스트는 session 스코프로 계속 돈다. — Task 2 `case_two_fragments_on_one_branch`
2. **현재 브랜치의 diff 만 사소한 토픽**(형제 브랜치에 실질 변경) → trivia escape 로 파이프라인이 통째로 건너뛰어지지 않는다 — 판정 대상은 토픽 전체다. — Task 7 `case_trivia_escape_is_gated_by_declaration`
3. **신선한 clone · CI**(형제 구성원이 원격-추적 ref 로만 존재) → 형제의 변경이 합친 트리에 들어가고, base 원격 ref · `origin/HEAD`(=`origin` 으로 찍힌다)는 구성원이 아니다. — Task 2 `case_remote_only_sibling_is_combined`
4. **① 과 HEAD 축 트리 생성 사이에 워킹트리가 바뀜** → `create-head --topic` 이 지금 다시 도출한 트리와 달라 거부한다(stale). HEAD 축 미관측으로 라우팅된다 — 옛 트리를 조용히 쓰지 않는다. — Task 3 `case_create_head_topic_rejects_wrong_commits`
5. **하위 디렉토리에서 `/qg`** → 토픽 해소가 리포 루트 기준으로 선다(`status: ok`). — Task 2 `case_runs_from_subdirectory`

---

## 이 PR 이 지는 것

| 항목 | 내용 | 집행 자리 |
|---|---|---|
| **AC3** | 여러 브랜치에 걸친 선언 → 한 판정 단위 | `topic-head.sh`(Task 2) · SKILL ①(Task 7) · 레퍼런스 R-init(Task 8) |
| **AC4** | 이미 머지된 구성원도 토픽에 든다 | PR1 `resolve-topic.sh` 2단계 — Task 2 `case_merged_member_combined` 가 끝에서 끝으로 잰다 |
| **AC5** | 선언 경로의 기준선 = `fork` 들의 merge-base | PR1 계산 + R-init `$baseline_commit`(Task 8) · R4 호출 셋(Task 8) |
| **AC6** | HEAD 축 = 봉인을 먼저 넣은 극대원소들의 `merge-tree` | `topic-head.sh`(Task 2) · `create-head --topic`(Task 3) · R-init(Task 8) |
| **AC7** | 충돌 → `not-certified (merge-conflict)` + 충돌 파일 | `topic-head.sh` 의 `conflicts:`(Task 2) · `scope_tuple.py` 사유 · 렌더(Task 4) |
| **AC15** | 판정 산출물이 본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID 를 싣는다 | `commit:` 줄(Task 2) · 합성기 `scope:` 블록(Task 4) · Final Summary(Task 7) |
| **AC16** | 선언 없음 → 세 모드 · 깨진 선언 → `declaration-invalid` | `resolve-topic.sh detect`(Task 1) · `topic-head.sh`(Task 2) · 매핑(Task 4) · 상태 표(Task 7) |
| **AC14 확장** | 토픽 해소도 실제 인덱스 · HEAD · 워킹트리 · ref 를 안 바꾼다 | Task 2 `case_no_side_effects` |
| **§6.2.4 GC** | 순차 합치기 중간 커밋 · `create-head` 재봉인 커밋의 회수 | R-AN(P23 재결정 — **사용자 동의 필요**) · Task 9 락 |
| **PR1 이월 둘** | `--sort=refname` 미고정 · `origin/HEAD` · base 원격 ref 전용 락 | Task 1 |
| **부채 후보** | M7 · 옛 § 포인터 · N=5 락 이빨(X6/X7/X8) | Task 5 · Task 6 · Task 11 — 아래 「후보 판정」 |

**이 PR 이 지지 않는 것** — 부채 원장(맨 끝)에 이름이 있다.

---

## 전제 — PR4b 가 main 에 남긴 것 (#177, 3c3444b1, qg 9.0.0)

컨트롤러가 착수 때 코드로 확증하고, 없으면 **BLOCKED** 로 보고한다.

- SKILL 파이프라인 = ① 스코프 → ② 차등 테스트(매 iteration) → ③ 각도 + 리뷰어 → ④ 재비판 → ⑤ 합성 · 판정. 레퍼런스 `skills/quality-pipeline/references/differential-test.md`(R-init R1a R1b R2 R3 R4 R5b R6 R8).
- `scripts/seal-worktree.sh seal <sid>` → 봉인 커밋 SHA 한 줄. 임시 인덱스는 `.git` 안(`qg-seal-<sid8>.<pid>.index`), `check-ignore` 로 add 방식을 고른다. 봉인 커밋 저자는 `qg seal <qg-seal@devbrew.local>`.
- `scripts/qg-worktree.sh create-head <sealed> <sid>` 는 봉인을 다시 떠서 트리를 대조한다(인자 정확히 셋).
- `scripts/resolve-topic.sh {resolve|commits} <key> [--seal <sha>]` — `resolve` 는 10키(`topic_key · status · reason · declared · branches · boundary · tips · commits · base_ref · seal_on_topic`), `status ∈ {ok, no-declaration, declaration-invalid, base-unresolved}`. `commits` 는 status≠ok 이면 exit 3.
- `scripts/combine-tips.sh <tip>...` — 6키(`tree · status · steps · intermediates · conflicts · failed_at`), `status ∈ {ok, merge-conflict, merge-failed, bad-input}`. 끝점 하나면 `steps: 0` · `intermediates: -`.
- 합성기는 매 호출 `--emit-verdict --angles`. SKILL 이 싣는 `--reason` 리터럴 = {trivia, kill-switch, scope-empty, silent-drop, error-axis}. `test_verdict_vocabulary.sh` 의 `debt="declaration-invalid merge-conflict"`.
- `tools/adjudication/check_wiring.py` 의 `synthesize_findings.py` 면제 키 **389**.
- 선재 RED 넷: qg `test_codex_backward_compat.sh`(1) · qg `test_runner_adapters.sh`(1) · qg `harness/test_skill_orchestration_behavior.sh`(2) · spec-distill `test_no_write_matcher_hooks_repo.sh`(1). unittest 197.

**계획 작성 중 실측(2026-09-26, git 2.54)** — 계획이 기대는 사실이다.

| id | 관측 | 값 |
|---|---|---|
| P1 | 이 리포에서 `resolve-topic.sh resolve '<설계>#pr4b'` | `status: ok` · `declared: 23` · `branches: merged:3db22654…` · `boundary: a1f9549a…`(#176 머지 = PR4b 가 갈라진 자리) · `commits: 24` — 설계 §7-E 의 재검증(경계 규칙의 «모양»이 사람이 아는 답과 일치) |
| P2 | scratch: 형제 둘 + untracked → seal → `resolve --seal` → `combine-tips` | `tips` = {형제 tip, 봉인}(현재 tip 은 봉인의 조상이라 빠진다) · 합친 트리 = 마지막 `intermediates` 의 트리 · `git diff --name-only <boundary> <tree>` = 형제 · 현재 · untracked 셋 다 |
| P3 | 같은 scratch 에서 `worktree add` → `remove` 뒤 | `for-each-ref --contains <봉인>` 0 · `reflog --all` 언급 0 · `git fsck --unreachable`(reflog 포함 기본값)이 봉인 · 중간 커밋을 `unreachable commit` 으로 낸다 · `git prune --expire=now` 뒤 두 커밋 `cat-file` 실패(회수됨) |
| P4 | `git for-each-ref --format='%(refname:short)'` 의 `refs/remotes/origin/HEAD` | **`origin`** 으로 찍힌다(`origin/HEAD` 가 아니다) |
| P5 | `resolve-baseline.sh` 의 base 후보 | `origin/HEAD` → `origin/main` → `origin/master` → `main` → `master`. detached HEAD · shallow 는 `degraded: yes` |

---

## 이월 — PR4b 부채 원장 중 4c 소유

| # | 이월 | 이 PR 에서 |
|---|---|---|
| **C1** | 토픽 스코프 배선 — `resolve-topic.sh` → 경계 · 끝점, `combine-tips.sh` → 합친 HEAD 트리, AC3–AC7 · AC15 · AC16 의 선언 쪽 | **닫는다**(Task 2 · 3 · 7 · 8) |
| **C2** | `declaration-invalid` · `merge-conflict` 발화 지점 — `test_verdict_vocabulary.sh` 의 `debt` · `test_pipeline_verdict_wiring.sh` 의 사유 핀 | **닫는다**(Task 4) — 핀은 R-AL 대로 |
| **C3** | PR1 이월 둘 — `--sort=refname` · `origin/HEAD`/base 원격 ref 전용 락 | **닫는다**(Task 1) |
| **C4** | 순차 합치기 중간 커밋 · `create-head` 재봉인 커밋의 GC | **닫는다 — 방식은 R-AN**(Task 9) |

## 후보 판정 — PR4b 부채 원장 §8

각 행은 **무엇을 정했는가 · 왜 · 틀리면 무엇을 치르는가**다.

| 후보 | 판정 | 근거 | 틀리면 |
|---|---|---|---|
| 결정론 차등 렌더러(`resolution_disclosure` + non-green 귀속 행을 스크립트가 직접 찍기) | **후속** | 4c 는 스코프 튜플을 합성기 꼬리(`scope:` 블록)에 싣는 자리를 새로 만든다 — 렌더러가 나중에 쓸 같은 목적지다. 그러나 차등 요약은 PR4b 최종 리뷰가 방금 same-line 락(I1-C/D/E)으로 굳힌 Step 4.5 표면이라, 옮기면 그 락 이주가 따로 필요하다. 스코프 배선과 한 PR 에 섞으면 두 변경이 서로의 리뷰 표면을 가린다 | 모델이 YAML 을 읽어 요약을 조립하는 자리가 한 릴리스 더 남는다 |
| M5 — 쓰기 가능 추가 리뷰어가 봉인 뒤에 돈다 | **후속** | 4c 는 봉인 시점을 ① 로 앞당길 뿐(선언 경로) ③ 과의 순서는 그대로다 — 이 PR 이 창을 넓히지도 좁히지도 않는다. 닫으려면 Step 4 에 재봉인 대조라는 새 표면이 필요하다 | 그대로(오늘과 같다) |
| M7 — `DISABLE_DIFFERENTIAL_TEST` 가 스크립트로 집행되지 않음 | **4c 에 넣는다**(Task 5) | kill switch 는 보안 컨트롤이다(헌장). 저장소 코드(`setup_cmd` · 테스트)를 돌리는 길은 `run-test-selection.sh` 의 `adapter_usable()` 한 관문뿐이라, 그 첫머리 한 자리가 `probe` · `run` 둘 다를 막는다. 새 exit 코드 없이 기존 계약(exit 3 + `usable: no` + `reason:` / 전 unit `unrun`)으로 거부한다 — R4 · R5b 라우팅이 이미 그 모양을 fail-closed 로 받는다 | 스위치를 켠 채 ② 에 들어온 실행이 `kill-switch` 가 아니라 다른 미판정 사유로 보인다(방향은 같다) |
| N=5 상한 락의 이빨(X6 · X7 · X8) | **4c 에 넣는다**(Task 11) | 같은 락 파일(`test_pipeline_verdict_wiring.sh`)을 이 PR 이 연다. 닫는 방법이 이미 알려져 있다(same-line + 부정형 거부 + 목적지 양의 단언). 문면은 바꾸지 않고 단언만 더한다 | 없다(단언 추가뿐) |
| `agents/security-reviewer.md` 의 「Review gate」 문구 | **PR5** | 같은 부류(없어진 게이트 이름)의 공개 문자열 · 헌장 정리를 PR5 가 진다(AC20 「2-gate」). persona 편집은 보안 리뷰 대상이라 한 PR 에 모아 한 번 받는다. 이 PR 은 `agents/**` 를 건드리지 않는다(범위 불변식) | 한 릴리스 더 옛 이름이 persona 첫 줄에 남는다(행동 불변) |
| 레퍼런스의 §6.7/§11 옛 포인터(14줄) | **4c 에 넣는다 — 포인터를 걷어낸다**(Task 6) | 모든 `§` 가 설치본에 없는 archive 설계 문서(`docs/archive/specs/2026-08-01-…`)를 가리킨다 — 모델이 없는 절을 찾게 만드는 자기서사다. 문장(잔여 결함의 공시)은 그대로 두고 번호만 뺀다. 4c 가 이 파일을 어차피 연다 | 없다(행동 불변) |

---

## 계획이 내린 판정 — 설계 문면을 넘어선 자리

사용자가 뒤집을 수 있는 자리다.

### R-AI — 토픽 키는 **현재 브랜치가 base 위에 얹은 커밋**의 트레일러에서 감지한다

**정함.** `resolve-topic.sh detect` 가 `git log --format=%B <base_ref>..HEAD` 의 `^Spec: ` 줄(원시 메시지 — `nkeys` 와 같은 계열)을 모은다. 0 → `no-declaration`, 1 → `ok` + 그 키, 2 이상 → `declaration-invalid`, base 를 못 풀면 → `base-unresolved`. `branch` · `--paths` override 가 있으면 감지하지 않는다.

**왜.** 설계는 트레일러가 «무엇»인지(§6.2.1)와 키로 토픽을 푸는 법(§6.2.2)을 정했지만 `/qg` 가 «어느» 키를 볼지는 정하지 않았다. base 에 이미 든 앞 토픽의 트레일러까지 세면 머지된 모든 토픽이 현재 브랜치의 선언이 된다. 두 키는 §6.4.3 의 「한 브랜치가 서로 다른 토픽 키를 단 커밋을 함께 담음」 그대로다.

**틀리면.** 아직 머지 안 된 앞 조각 위에 쌓은 브랜치가 `declaration-invalid` 가 된다(Review Focus 1) — 설계가 요구한 동작이지만 쌓기 작업 흐름에 마찰이다.

### R-AJ — 새 진입 모듈 `topic-head.sh` · ① 이 매 iteration 한 번 부른다 · 한 iteration 은 한 트리를 본다

**정함.** `topic-head.sh <sid> [--topic <key>]` 가 감지 → 봉인 → `resolve --seal` → `commits` → `combine-tips` 를 한 번에 돌려 12 고정 키 + `commit:` N 줄을 낸다. SKILL ① 이 그 출력을 `.claude/quality-gates/<sid>/topic-scope.txt` 에 쓴다(매 iteration 덮어쓴다). 그 파일이 이 iteration 의 스코프 파일 집합 · 리뷰어 diff(`<boundary>..<tree>`) · R-init 의 기준선 · HEAD 축 · 합성기 튜플의 **유일한 원천**이다.

**왜.** 설계 §6.4.1 의 HEAD 축 네 걸음(봉인 → 끝점 → 합치기 → 체크아웃)은 결정론이다 — 세 스크립트를 모델이 한 걸음씩 옮겨 부르면 봉인 SHA · 끝점 목록을 전사한다. 파이프라인 순서상 ③ 의 diff 는 ② 뒤에 만들어지고 ① 의 파일 집합은 ② 앞이므로, ① 에서 한 번 풀어 두어야 셋이 같은 트리를 본다. 봉인은 git 객체만 만들고 저장소 코드를 돌리지 않으므로 kill switch 와 무관하게 ① 에서 돈다. 새 책임은 새 모듈 — `resolve-topic.sh` · `combine-tips.sh` 는 사실만 내는 층으로 남는다.

**틀리면.** 선언 경로에서 봉인이 iteration 마다 두 번 뜬다(① · `create-head --topic` 의 재도출). 봉인은 수 ms 이고 객체는 prune 이 회수한다.

### R-AK — 토픽을 못 쓰면 session 으로 내려가고, 판정은 사유가 막는다

**정함.** `topic-head.sh` 의 `status:` 여덟:

| `status:` | 스코프 | 사유(합성기가 `--scope` 에서 낸다) | 왜 그 사유/무사유인가 |
|---|---|---|---|
| `ok` | topic | — | |
| `no-declaration` | session | — | §6.2.5 — 선언은 새 의무가 아니다 |
| `base-unresolved` | session | — | 감지 단계에서만 난다 — `resolve-baseline.sh` 가 degraded 라는 뜻이고, R-init 의 「baseline 확정 불가 → clean 불가」가 이미 막는다 |
| `declaration-invalid` | session | `declaration-invalid` | §6.4.3 그대로(경로 부재 · 한 브랜치에 두 키 · 고아) |
| `unbounded` | session | `declaration-invalid` | 선언은 있는데 경계 · 끝점을 못 셌다(예: 히스토리가 끊긴 구성원). 토픽이 한 판정 단위를 이루지 못함 — 가장 가까운 이름 |
| `seal-failed` | session | — | 봉인이 안 서면 HEAD 축이 안 선다 — R5b 의 봉인 실패 라우팅(unrun + degraded)이 막는다 |
| `merge-conflict` | session | `merge-conflict` | §6.2.4 · AC7 |
| `merge-failed` | session | `merge-conflict` | 같은 걸음(끝점 합치기)의 충돌 아닌 실패 — `combine-tips.sh` 비0 · 충돌 아닌 비0 status. 사용자에게 같은 사실이다 — 「끝점을 합치지 못했다」. 오늘 `topic-head.sh` 경로로는 거의 도달하지 않는다(unrelated histories 는 경계 단계에서 먼저 `unbounded` 가 된다) — 방어 갈래다 |

session 으로 내려가도 리뷰 · 차등 테스트는 돈다 — `defect` 가 `not-certified` 보다 우선하므로(§6.4.3) 현재 브랜치의 확증 결함은 여전히 잡힌다.

**왜.** 사유 열거를 늘리지 않는다(AC8 · `N:11`). 무사유 셋은 다른 경로가 이미 fail-closed 로 막는다.

**틀리면.** 사유 라벨이 정확한 원인보다 넓다(`unbounded`→`declaration-invalid` · `merge-failed`→`merge-conflict`). 방향(clean 아님)은 맞다.

### R-AL — 두 사유는 합성기가 `--scope` 파일에서 낸다 · SKILL 의 `--reason` 핀은 다섯 그대로

**정함.** PR4b 부채 원장은 이 빚을 「`test_pipeline_verdict_wiring.sh` 의 사유 핀」이 붙잡고 있다고 적었다. 이 PR 은 핀을 7 로 늘리지 않는다 — 오케스트레이터가 `--reason declaration-invalid` · `--reason merge-conflict` 를 옮겨 적는 대신, 합성기가 `--scope` 로 받은 스코프 파일의 `status:` 를 `scope_tuple.STATUS_TO_REASON` 으로 사유에 옮긴다. `test_verdict_vocabulary.sh` 는 `debt` 를 비우고 산출자 셋에 `STATUS_TO_REASON.values()` 를 더한다. 핀(`SET:error-axis kill-switch scope-empty silent-drop trivia`)은 그대로이고 그 메시지만 고친다.

**왜.** 사유를 모델이 전사하면 전사 누락이 곧 fail-open 이다(합치기가 깨졌는데 `clean`). 스크립트 산출물에서 도출하면 모델의 의무는 「`--scope` 를 싣는다」 하나로 줄고, 그 하나는 Step 4 표의 한 행 + 락이 잡는다. PR4b 가 차등 축의 `degrade_causes` 를 `CAUSE_TO_REASON` 으로 옮긴 것과 같은 모양이다.

**틀리면.** 부채 원장의 「핀 5→7」 문면과 다르다 — 결과(두 사유가 실제로 나온다)는 같다.

### R-AM — `create-head --topic <key>` 는 합친 트리를 지금 다시 도출해 대조한다

**정함.** `create-head <sha> <sid> --topic <key>` 는 봉인 대신 `topic-head.sh <sid> --topic <key>` 를 다시 돌려 그 `status: ok` 의 `tree:` 와 `<sha>^{tree}` 를 대조하고, 다르면(또는 `status` 가 `ok` 가 아니면) 죽는다. 인자 없는 기존 모양(`create-head <sha> <sid>`)은 그대로다.

**왜.** 설계 §6.4.1 이 `create-head` 에 요구한 것은 「봉인 커밋의 트리가 기대 OID 와 일치」이고, PR4b 는 그 기대값을 지금 다시 뜬 봉인에서 도출했다(전사 없음). 선언 경로의 HEAD 축은 봉인이 아니라 합친 트리라, 같은 규율을 합친 트리에 건다 — 경계 · 봉인 단독 · stale 값을 넘기면 죽는다.

**틀리면.** 선언 경로의 HEAD 축 생성이 봉인 + 합치기를 한 번 더 한다(수 ms).

### R-AN — GC 는 git 의 prune 에 맡긴다 · qg 는 도달 가능하게 만들지 않는다 (**P23 재결정 — 사용자 동의 필요**)

**원래(설계 §6.2.4 · §12).** 「순차 합치기는 `commit-tree` 중간 커밋을 만들고 그것은 unreachable 로 남는다 → 기존 `qg-gc.py` 경로에 편입한다」 · `qg-gc.py — unreachable 중간 커밋 정리`.

**재결정.** `qg-gc.py` 는 바뀌지 않는다. qg 가 만드는 커밋(봉인 · 재봉인 · 합치기 중간 · 합친 HEAD 커밋)은 **어떤 ref · reflog 도 얻지 않는다** — HEAD 축 워크트리가 살아 있는 동안만 그 워크트리의 HEAD 가 붙잡고, R6 의 `remove` 뒤에는 도달 불가다. 회수는 git 자신의 `gc`(→ `prune --expire`)가 한다. 새 락 `test_qg_objects_unreachable.sh` 가 한 실행 뒤 qg 저자 커밋 전부가 `git fsck --unreachable` 에 잡히고 어떤 ref 에도 담기지 않음을 잰다(양의 짝: 살아 있는 워크트리의 커밋은 도달 가능).

**근거.**
1. `qg-gc.py`(`gc_common.py`)는 세션 폴더를 TTL 로 지우는 모듈이고 git 객체를 다루지 않는다. 선택적 회수 수단이 git 에 없다 — `git prune` 은 리포 전체의 unreachable 객체(사용자의 dropped stash · 되살리려던 커밋 포함)를 지운다. qg 가 그것을 부르면 사용자 리포의 복구 가능성을 조용히 파괴한다.
2. 객체 파일을 골라 지우는 것도 이득이 없다 — 커밋 객체(수백 바이트)만 골라낼 수 있고, 부피를 차지하는 트리 · blob 은 내용 주소라 사용자 객체와 공유될 수 있어 지울 수 없다. 살아 있는 워크트리의 HEAD 를 지우면 그 워크트리가 깨진다.
3. 실측 P3 — 이 커밋들은 이미 ref · reflog 어디서도 닿지 않고 `prune` 이 회수한다. 남은 위험은 «앞으로 누가 ref 를 만들어 붙잡는 것»뿐이고, 그것을 락이 잡는다.

**틀리면(뒤집으면).** `qg-gc.py` 가 세션 정리 때 `git prune` 을 부르게 된다 — 위 1 의 파괴를 감수해야 한다.

**동의.** 설계 §16 에 P23 항목으로 기록하는 것은 Task 10 이다 — **사용자 동의가 있을 때만** 쓴다. 이 계획은 계획 리뷰(2026-09-26)에서 동의를 받는다. 동의가 없으면 실행하지 않는다.

### R-AO — 선언이 있으면 trivia escape 를 쓰지 않는다

**정함.** SKILL Trivia escape 는 override 가 없으면 먼저 `resolve-topic.sh detect` 를 부른다. `status: ok` 또는 `declaration-invalid` 면 `check-trivia.sh` 를 부르지 않고 곧장 iteration 1 로 간다.

**왜.** trivia escape 는 파이프라인 «앞»에 있어 ① 의 토픽 해소보다 먼저 돈다 — 현재 브랜치 diff 가 한 문장이면 형제 브랜치의 실질 변경이 통째로 건너뛰어진다(Review Focus 2). 선언된 작업은 spec 에 묶인 작업 단위(Law 1)라 「한 문장으로 설명 가능한 diff」의 정의역 밖이다. `declaration-invalid` 도 건너뛰지 않는 이유 — trivia 로 새면 `not-certified (trivia)` 가 선언이 깨졌다는 사실을 가린다.

**틀리면.** 선언이 달린 브랜치의 오타 수정도 전체 파이프라인을 돈다(trivia ceremony). 그 비용이 선언의 대가다.

### R-AP — 선언 경로의 차등 테스트는 합친 트리에서 어댑터를 감지 · unit 을 배정한다

**정함.** 선언 경로에서는 R-init 이 HEAD 축 트리(`create-head --topic`)를 **먼저** 만들고, R1a `detect` · R1b `assign` 이 `$project_dir` 대신 `$scan_dir`(= 그 트리)를 본다. R5b 는 봉인 · 트리 생성을 건너뛰고 R-init 의 `$sealed` · `$head_tree_dir` 를 쓴다. session 경로는 바뀌지 않는다(`$scan_dir = $project_dir`, R5b 그대로).

**왜.** 형제 구성원에만 있는 새 테스트 파일은 현재 브랜치 워킹트리에 없다 — `assign "$project_dir"` 가 그것을 unclaimed 로 떨어뜨려 R8 이 `silent-drop` 을 낸다. 선언 경로의 대표 시나리오(AC3: 형제가 기능 + 테스트를 더함)가 매번 `not-certified` 가 된다. 트리를 R4 «앞»에 만들면 stale 대조 창도 ①→R-init 으로 줄어든다(사이에 저장소 코드가 돌지 않는다).

**틀리면.** kill switch 가 꺼진 선언 경로에서 HEAD 축 트리가 R4 동안 살아 있다 — 기준선 테스트가 그 트리를 건드릴 수 있는 창이 생긴다(같은 호스트 권한 · 같은 신뢰 경계라 새 능력은 아니다). `test-scope-validator` 는 여전히 `$project_dir` 를 읽는다(부채 원장).

### R-AQ — 다른 리모트의 기본 브랜치는 구성원이 될 수 있다 — 공시만 한다

**정함.** `resolve-topic.sh` 의 구성원 규칙(§6.2.2 1단계 — 「`C` 를 담으면서 `base_ref` 의 조상이 아닌 ref」)을 바꾸지 않는다. base 원격 ref · `origin/HEAD`(=`origin`) · 뒤처진 로컬 `main` 은 조상-또는-같음이라 구조적으로 빠지고(Task 1 이 전용 락으로 못 박는다), 앞선 로컬 `main`(push 안 한 작업)은 구성원이 되는 것이 맞다. 그러나 **다른 리모트의 기본 브랜치**(예: fork 워크플로의 `upstream/main`)가 토픽을 이미 머지했으면 그 ref 가 구성원이 되어 `T` 가 그 리모트의 커밋만큼 부풀 수 있다.

**왜.** 이름으로 빼면(`*/main` · `*/master`) 시간에 fail-open 인 열거이고(`develop` · `trunk`), 첫-부모 규칙 같은 구조적 대안은 §6.2.2 자체의 재결정이다. `branches:` 가 `scope:` 블록으로 판정 옆에 실리므로 부풀림은 보인다.

**틀리면.** fork 워크플로에서 머지 뒤 `/qg` 가 남의 커밋까지 리뷰 대상에 넣는다 — 부채 원장.

### R-AR — 버전은 **minor**, qg 만

**정함.** 새 능력 · 비-breaking. 번호는 머지 직전 `origin/main` 의 qg 버전에서 minor 를 올린 값(오늘 관측 9.0.0 → 9.1.0). 다른 플러그인은 한 바이트도 안 바뀌므로 올리지 않는다.

---

## 끝에서 끝 흐름 — 선언 경로 한 iteration

Task 사이 이음매가 Task 리뷰에는 안 보인다(PR4b 교훈). 아래 표가 한 iteration 의 값이 누구 손에서 누구 손으로 가는지를 적는다. 최종 리뷰는 이 표를 한 행씩 따라간다.

| # | 자리 | 입력 | 산출 | 소비자 | 소유 Task |
|---|---|---|---|---|---|
| 0 | SKILL Trivia escape | `resolve-topic.sh detect` | `status:` | `ok`/`declaration-invalid` → trivia 건너뜀 | 1 · 7 |
| 1 | SKILL ① 1a | `topic-head.sh <sid>` | `.claude/quality-gates/<sid>/topic-scope.txt`(12키 + `commit:`) | 아래 2 · 4 · 5 · 9 | 2 · 7 |
| 2 | SKILL ① 파일 집합 · diff | 파일의 `boundary:` · `tree:` | `git diff --name-only <b> <t>` · `git diff <b> <t>` | `$resolved_scope_file_count` · scout · 리뷰어 `filtered_diff` · 재비판 diff | 7 |
| 3 | SKILL 상태 표 | 파일의 `status:` | topic / session + 공지 한 줄 | 모델 라우팅 | 7 |
| 4 | 레퍼런스 R-init | 파일의 `status:` · `boundary:` · `topic_key:` · `head_commit:` | `$baseline_commit` · `$sealed` · `$head_tree_dir` · `$scan_dir` (`create-head --topic` 이 재도출 대조) | R1a · R1b · R4 · R5b · R6 | 3 · 8 |
| 5 | 레퍼런스 R1a · R1b | `$scan_dir` | 어댑터 집합 · 배정 행 | R4 · R5b · R8 | 8 |
| 6 | 레퍼런스 R4 | `$baseline_commit` | `create-baseline` · 캐시 키 | R6 | 8 |
| 7 | 레퍼런스 R5b | `$sealed` · `$head_tree_dir`(R-init) | HEAD 행 | R6 | 8 |
| 8 | 레퍼런스 R6 | `$head_tree_dir` | 집계 · `remove` → qg 커밋 도달 불가 | R8 · Step 4 · git prune | 8 · 9 |
| 9 | SKILL Step 4 | `--scope "<파일>"` | 사유(`STATUS_TO_REASON`) + `scope:` 블록 | `verdict:` · Step 4.5 · Final Summary | 4 · 7 |
| 10 | 실패 · kill switch | ② 생략 | R-init 안 돎 → 트리 안 만듦 · ① 의 봉인만 prune 대상 | — | 5 · 7 |

**선언 경로가 실패한 iteration**(`status` ≠ `ok`): 1 의 파일은 쓰이고, 2–8 은 session 규칙(merge_base · `$project_dir` · R5b 봉인)으로 돌고, 9 는 여전히 `--scope` 를 실어 사유와 `mode: session` 블록을 낸다.

---

## 파일 구조

**신설**

| 경로 | 책임 |
|---|---|
| `plugins/quality-gates/scripts/topic-head.sh` | 선언 → 봉인 → 경계 · 끝점 → 합친 트리 → 12키 튜플 + `commit:` 줄 |
| `plugins/quality-gates/scripts/scope_tuple.py` | 튜플 파서(fail4) · `STATUSES` · `STATUS_TO_REASON` · `scope:` 블록 렌더 |
| `plugins/quality-gates/tests/test_topic_head.sh` | `topic-head.sh` · `create-head --topic` 행동 락(일회용 리포) |
| `plugins/quality-gates/tests/test_scope_tuple.sh` | 합성기 `--scope` 행동 락 |
| `plugins/quality-gates/tests/test_topic_scope_wiring.sh` | SKILL · 레퍼런스 배선 락(same-line · 부정형 거부 · 열거는 모듈에서 도출) |
| `plugins/quality-gates/tests/test_qg_objects_unreachable.sh` | R-AN — qg 커밋이 ref · reflog 를 얻지 않는다 |

**수정**

| 경로 | 무엇이 |
|---|---|
| `scripts/resolve-topic.sh` | `detect` 서브커맨드 · `--sort=refname` |
| `scripts/qg-worktree.sh` | `create-head --topic <key>` · 머리 주석 |
| `scripts/synthesize_findings.py` | `--scope` · `scope:` 블록 · 스코프 사유 |
| `scripts/run-test-selection.sh` | `adapter_usable()` 첫머리 kill switch(M7) |
| `scripts/combine-tips.sh` | 머리 주석의 GC 문단만(R-AN) |
| `scripts/check-allowed-tools-order.sh` | `EXPECTED_ORDER` 두 항목 |
| `skills/quality-pipeline/SKILL.md` | `allowed-tools` · Trivia escape · Step 1(1a · 상태 표 · topic diff) · kill switch 문단 · Step 4 표 · Step 4.5 · Final Summary · 보안 리뷰어 `diff_scope` 힌트 · 파일 집합 정의 |
| `skills/quality-pipeline/references/differential-test.md` | § 포인터 14줄(Task 6) · 창 표 · R-init · R1a · R1b · R4 · R5b(Task 8) |
| `tests/test_topic_boundary.sh` · `tests/test_verdict_vocabulary.sh` · `tests/test_pipeline_verdict_wiring.sh` · `tests/test_run_test_selection.sh` · `tests/test_one_pipeline_surface.sh` | 케이스 추가 · `debt` 비움 · 핀 메시지 · X6–X8 |
| `tools/adjudication/check_wiring.py` | 면제 키 재앵커 |
| `commands/qg.md` · `README.md` · `tests/e2e-scenarios.md` | 문서 |
| `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` | §16 P23(R-AN) · §6.2.4 · §12 의 해당 줄 표지 — **동의 후** |
| `CHANGELOG.md` · `.claude-plugin/plugin.json`(`version` 만) · SKILL 제목 버전 · publishing SKILL 제목 버전 | bump |

---

## 착수 — 컨트롤러가 Task 1 전에 한다

- [ ] **Step A: 브랜치 · base 확인**

```bash
git branch --show-current
git fetch origin --quiet
git merge-base --is-ancestor origin/main HEAD && echo "OK origin/main ⊆ HEAD"
git rev-list --count HEAD..origin/main
```

  **기대** — `feature/qg-topic-scope-pr4c` · `OK …` · 마지막 값이 0 이 아니면 `git merge --no-edit origin/main`(rebase 금지) 뒤 다시 본다.

- [ ] **Step B: 미러 · 러너 · 기준선**

```bash
mkdir -p ~/.claude/sdd-mirror/qg-topic-scope-pr4c
cp ~/.claude/sdd-mirror/qg-gate-merge-pr4b/run-suite.sh "$CLAUDE_JOB_DIR/tmp/run-suite.sh"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4c-baseline.tsv"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u > "$CLAUDE_JOB_DIR/tmp/pr4c-baseline-harness-fails.txt"
cp "$CLAUDE_JOB_DIR"/tmp/pr4c-baseline* ~/.claude/sdd-mirror/qg-topic-scope-pr4c/
```

  **기대** — `run-suite.sh` 가 끝에 비0 행 **넷**(전제의 선재 RED 넷, 실패 줄 수까지 같게)만 낸다. unittest `Ran 197` · OK. 하네스 실패 이름 2. 다르면 기준선 표를 원장에 적고 그 차이를 모든 Task 의 RED diff 기준으로 쓴다(멈추지 않는다).

- [ ] **Step C: 전제 확증** — 아래가 전부 한 건 이상 나와야 한다. 하나라도 0 이면 BLOCKED.

```bash
grep -c 'resolve|commits' plugins/quality-gates/scripts/resolve-topic.sh
grep -c 'intermediates' plugins/quality-gates/scripts/combine-tips.sh
grep -c 'usage: create-head <sealed-sha> <session-id>' plugins/quality-gates/scripts/qg-worktree.sh
grep -c 'local debt="declaration-invalid merge-conflict"' plugins/quality-gates/tests/test_verdict_vocabulary.sh
grep -c "SET:error-axis kill-switch scope-empty silent-drop trivia" plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh
grep -c '"plugins/quality-gates/scripts/synthesize_findings.py", 389' tools/adjudication/check_wiring.py
git grep -c -E 'resolve-topic\.sh|combine-tips\.sh|topic-head' -- plugins/quality-gates/skills plugins/quality-gates/commands || echo "OK 호출자 0"
```

---

### Task 1: `resolve-topic.sh` — `detect` · `--sort=refname` · base 원격 ref 전용 락

**Files:**
- Modify: `plugins/quality-gates/scripts/resolve-topic.sh`(머리 주석 · 인자 파싱 · `emit()` 뒤 `detect` 블록 · `for-each-ref` 줄)
- Test: `plugins/quality-gates/tests/test_topic_boundary.sh`

**Interfaces:**
- Consumes: `resolve-baseline.sh` 의 `base_ref:` 키
- Produces: `resolve-topic.sh detect` → 정확히 4줄 `topic_key: <키|->` · `status: ok|no-declaration|declaration-invalid|base-unresolved` · `reason: <문장|->` · `base_ref: <ref|->`, 정상 경로 exit 0, 인자가 있으면 exit 2. `resolve` · `commits` 계약은 불변.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_topic_boundary.sh` 의 마지막 케이스(`case_resolve_tips_feed_combine`) 정의 뒤, `for c in …` 루프 앞에 넣는다:

```bash
# ── PR1 이월: 로컬-이름 우선 dedupe 가 정렬 순서에 기댄다 — 순서를 기본값에 맡기지 않는다 ──
case_for_each_ref_sort_pinned() {
  local got
  got=$(grep -n 'for-each-ref' "$RT" | grep -vE '^[0-9]+:[[:space:]]*#')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "for-each-ref 호출은 한 곳이다"
  assert_grep "$got" '--sort=refname ' "그 호출이 같은 줄에 --sort=refname 을 싣는다"
  assert_not_grep "$got" '--sort=-' "역순(--sort=-…)이 아니다"
}

# ── PR1 이월: base 원격 ref · origin/HEAD 는 선언을 «담아도» 구성원이 아니다 ─────────
#    `%(refname:short)` 는 refs/remotes/origin/HEAD 를 `origin` 으로 찍는다(실측 P4) —
#    패턴에 `origin` 을 넣지 않으면 이 락은 공허하다.
case_base_remote_ref_never_member() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git update-ref refs/remotes/origin/main HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "base 원격 ref 가 선언 커밋을 담아도 status: ok"
  assert_eq "$(field base_ref "$out")" "origin/main" "base_ref 는 origin/HEAD 가 가리키는 origin/main"
  assert_not_grep "$(field branches "$out")" '(^|,)(origin|origin/HEAD|origin/main|main)(,|$)' \
    "origin/HEAD(=origin) · origin/main · main 은 구성원이 아니다"
  assert_grep "$(field branches "$out")" '(^|,)topicB(,|$)' "살아 있는 구성원 topicB 는 있다(양의 짝)"
  assert_grep "$(field branches "$out")" '(^|,)merged:[0-9a-f]{40}(,|$)' "머지된 topicA 는 merged: 로 있다(양의 짝)"
  cleanup
}

# ── detect: 현재 브랜치가 base 위에 얹은 커밋의 트레일러 → 토픽 키 (R-AI) ────────────
case_detect_statuses() {
  new_repo
  local R out; R=$(git rev-parse HEAD)
  git checkout -q -b plain; echo p > p.txt; git add p.txt; git commit -qm plain
  out=$(bash "$RT" detect)
  assert_eq "$(field status "$out")" "no-declaration" "detect: 선언 없음"
  assert_eq "$(field topic_key "$out")" "-" "detect: 선언 없으면 topic_key: -"
  assert_eq "$(printf '%s\n' "$out" | grep -cE '^[a-z_]+: ')" "4" "detect: 정확히 4키"
  git checkout -q -b late "$R"; echo u > u.txt; git add u.txt; git commit -qm "undeclared first"
  decl_commit l.txt l1 "declared later"
  out=$(bash "$RT" detect)
  assert_eq "$(field status "$out")" "ok" "detect: 뒤 커밋에만 트레일러 → ok"
  assert_eq "$(field topic_key "$out")" "$KEY" "detect: topic_key 는 트레일러 값 전체(조각 포함)"
  git checkout -q -b stacked "$R"; decl_commit s1.txt s1 "s1"
  git commit -q --allow-empty -m "s2

Spec: docs/x-design.md#pr2"
  out=$(bash "$RT" detect)
  assert_eq "$(field status "$out")" "declaration-invalid" "detect: 한 브랜치에 키 둘 → declaration-invalid"
  assert_grep "$(field reason "$out")" '2 distinct' "detect: reason 이 키 수를 적는다"
  assert_eq "$(field topic_key "$out")" "-" "detect: 키가 둘이면 topic_key: -"
  git checkout -q --detach HEAD
  out=$(bash "$RT" detect)
  assert_eq "$(field status "$out")" "base-unresolved" "detect: detached HEAD → base-unresolved"
  cleanup
}

case_detect_ignores_base_history() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q -b next; echo n > n.txt; git add n.txt; git commit -qm "next (선언 없음)"
  assert_eq "$(field status "$(bash "$RT" detect)")" "no-declaration" \
    "detect: base 에 이미 든 앞 토픽의 트레일러는 세지 않는다"
  cleanup
}

case_detect_lowercase_trailer_ignored() {
  new_repo
  git checkout -q -b low; echo l > l.txt; git add l.txt
  git commit -qm "low

spec: $KEY"
  assert_eq "$(field status "$(bash "$RT" detect)")" "no-declaration" \
    "detect: 소문자 spec: 는 선언이 아니다(nkeys 와 같은 계열)"
  cleanup
}

case_detect_usage() {
  new_repo
  local rc; bash "$RT" detect extra >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "detect 는 인자를 받지 않는다(exit 2)"
  cleanup
}
```

  그리고 루프 목록의 마지막 줄 `         case_resolve_tips_feed_combine; do` 를 아래로 바꾼다:

```bash
         case_resolve_tips_feed_combine \
         case_for_each_ref_sort_pinned case_base_remote_ref_never_member \
         case_detect_statuses case_detect_ignores_base_history \
         case_detect_lowercase_trailer_ignored case_detect_usage; do
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_boundary.sh && bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `for-each-ref … --sort=refname` · `detect:` 단언들이 `✗`. `case_base_remote_ref_never_member` 는 **이미 GREEN** 이다(구조적 배제 — 이 케이스는 그것을 못 박는 락이다). `case_detect_usage` 도 오늘 usage 오류(exit 2)로 이미 GREEN 이다 — 그 단언의 이빨은 구현 뒤에 선다. 기존 케이스의 `✗` 는 0.

- [ ] **Step 3: 구현한다** — `resolve-topic.sh` 네 자리.

  (a) 머리 주석의 `# Subcommands:` 세 줄(머리줄 포함)을 아래 넷으로 바꾼다. 그 아래 문단의 `— \`commits\` 는 다르다, status != ok 이면 fail-closed 로 exit 3 이다(:47–53).` 의 줄번호 인용 `(:47–53)` 은 `(emit() 첫머리)` 로 바꾼다(편집으로 밀린다). `status:` 목록은 `resolve` 의 것이라 그대로 둔다 — `detect` 의 status 는 (c) 의 블록 주석이 적는다.

```bash
# Subcommands:
#   detect                -> key: value 4줄 (topic_key · status · reason · base_ref) — 현재 브랜치의 토픽 키
#   resolve <topic-key>   -> key: value 요약 10줄
#   commits <topic-key>   -> T 의 커밋 SHA (topo-order), 한 줄에 하나
```

  (b) 인자 파싱 — 옛 문면:

```bash
SUB="${1:-}"; TOPIC="${2:-}"
case "$SUB" in
  resolve|commits) ;;
  *) die "usage: resolve-topic.sh {resolve|commits} <topic-key>" ;;
esac
[ -n "$TOPIC" ] || die "empty topic key"
```

  새 문면:

```bash
SUB="${1:-}"; TOPIC="${2:-}"
case "$SUB" in
  detect)
    [ $# -eq 1 ] || die "usage: resolve-topic.sh detect" ;;
  resolve|commits)
    [ -n "$TOPIC" ] || die "empty topic key" ;;
  *) die "usage: resolve-topic.sh {detect | resolve <topic-key> | commits <topic-key>}" ;;
esac
```

  (c) `emit()` 정의의 닫는 `}` 바로 뒤, `git rev-parse --is-inside-work-tree … || emit base-unresolved …` 줄 **앞**에 넣는다:

```bash
# ── detect: 현재 브랜치가 선언한 토픽 키 ─────────────────────────────────────────
# 범위는 `base_ref..HEAD` — 현재 브랜치가 base 위에 얹은 커밋만 본다. base 에 이미 든
# 앞 토픽의 트레일러까지 세면 머지된 모든 토픽이 현재 브랜치의 선언이 된다.
# 추출은 아래 nkeys 와 같은 원시-메시지 계열(`%B` + `^Spec: `)이다 — 트레일러 atom 은
# 소문자 `spec:` 까지 세고, squash-merge 본문의 `Spec:` 줄을 못 센다.
# status: ok(키 하나) · no-declaration(0) · declaration-invalid(2+) · base-unresolved(base 미해결)
if [ "$SUB" = "detect" ]; then
  d_emit() {   # <topic_key> <status> <reason>
    echo "topic_key: $1"
    echo "status: $2"
    echo "reason: ${3:--}"
    echo "base_ref: $BASE_REF"
    exit 0
  }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || d_emit - base-unresolved "not a git work tree"
  BASE_REF=$(bash "$SCRIPT_DIR/resolve-baseline.sh" | awk -F': ' '/^base_ref:/{print $2}')
  [ -n "$BASE_REF" ] && [ "$BASE_REF" != "-" ] || { BASE_REF="-"; d_emit - base-unresolved "resolve-baseline.sh degraded"; }
  keys=$(git log --format='%B' "$BASE_REF..HEAD" 2>/dev/null | grep -E '^Spec: ' | sed -E 's/^Spec: //' | sort -u)
  n=$(printf '%s\n' "$keys" | grep -c .)
  [ "$n" -eq 0 ] && d_emit - no-declaration "no Spec trailer on $BASE_REF..HEAD"
  [ "$n" -gt 1 ] && d_emit - declaration-invalid "current branch carries $n distinct Spec keys"
  d_emit "$keys" ok "-"
fi
```

  (d) `for-each-ref` 줄과 그 위 주석 문단(「`git for-each-ref` 의 기본 정렬은 …」 네 줄) — 옛 문면:

```bash
# `git for-each-ref` 의 기본 정렬은 전체 refname 사전순이라 `refs/heads/*` 가 항상
# `refs/remotes/*` 보다 먼저 나온다(`h` < `r`) — 그래서 로컬 브랜치가 먼저 처리되고,
# 아래 tip-SHA 중복 제거가 로컬·원격-추적이 같은 커밋을 가리킬 때 로컬 이름을 자연히
# 남긴다(뒤에 나온 중복은 건너뛴다).
BR_NAMES=""; BR_TIPS=""
for ref in $(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null); do
```

  새 문면:

```bash
# 정렬을 `--sort=refname`(전체 refname 사전순)으로 못 박는다 — `refs/heads/*` 가 항상
# `refs/remotes/*` 보다 먼저 나와(`h` < `r`) 로컬 브랜치가 먼저 처리되고, 아래 tip-SHA
# 중복 제거가 로컬·원격-추적이 같은 커밋을 가리킬 때 로컬 이름을 남긴다. 기본 정렬에
# 맡기면 그 보장이 git 의 기본값에 달린다.
# base 원격 ref · `origin/HEAD`(`origin` 으로 찍힌다) · 뒤처진 로컬 base 는 base_ref 의
# 조상-또는-같음이라 아래 첫 검사가 빼낸다(test_topic_boundary.sh
# case_base_remote_ref_never_member).
BR_NAMES=""; BR_TIPS=""
for ref in $(git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null); do
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/resolve-topic.sh
bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | tail -2
bash plugins/quality-gates/tests/test_seal_no_side_effects.sh 2>&1 | tail -1
bash plugins/quality-gates/scripts/resolve-topic.sh resolve 'docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b' | sed -n '2p;6p'
```

  **기대** — `Fail: 0` 둘 · 마지막 명령이 `status: ok` 와 `boundary: a1f9549a…`(실측 P1 과 같다).

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/resolve-topic.sh plugins/quality-gates/tests/test_topic_boundary.sh
git commit -m "feat(qg): resolve-topic detect · --sort=refname · base 원격 ref 전용 락" \
  -m "현재 브랜치가 base 위에 얹은 커밋의 Spec: 트레일러로 토픽 키를 감지한다(0 → no-declaration · 2+ → declaration-invalid). ref 스캔 정렬을 못 박고, base 원격 ref · origin/HEAD 가 선언을 담아도 구성원이 아님을 락으로 고정한다(PR1 이월 둘)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 2: `topic-head.sh` — 선언 → 봉인 → 끝점 → 합친 트리 → 튜플

**Files:**
- Create: `plugins/quality-gates/scripts/topic-head.sh`(실행비트)
- Create: `plugins/quality-gates/tests/test_topic_head.sh`(실행비트)

**Interfaces:**
- Consumes: `resolve-topic.sh detect` · `resolve <key> --seal <sha>` · `commits <key>` · `seal-worktree.sh seal <sid>` · `combine-tips.sh <tip>...`(Task 1 · PR1 · PR4b)
- Produces: `topic-head.sh <session-id> [--topic <topic-key>]` → 고정 12키(이 순서) `topic_key · status · reason · branches · boundary · tips · seal · seal_on_topic · tree · head_commit · conflicts · commits` + `commits:` 가 수이면 그 수만큼 `commit: <sha>` 줄. 값이 없으면 `-`. `status ∈ {ok, no-declaration, base-unresolved, declaration-invalid, unbounded, seal-failed, merge-conflict, merge-failed}`. 정상 경로 exit 0, 사용 오류 exit 2. `status: ok` 이면 `tree` · `head_commit` · `seal` · `boundary` 가 OID 이고 `head_commit^{tree} == tree`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/quality-gates/tests/test_topic_head.sh`:

```bash
#!/usr/bin/env bash
# test_topic_head.sh — scripts/topic-head.sh · qg-worktree.sh create-head --topic
#   (설계 §6.2.2–§6.2.6 · §6.4.1, AC3–AC7 · AC14 · AC15 · AC16)
#
# 각 케이스는 mktemp 아래 일회용 git 리포를 세운다 — 실제 리포에서 fixture git 실행 금지.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TH="$PLUGIN_ROOT/scripts/topic-head.sh"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SEALER="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
SID='sesstopic1234'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_repo() {   # main 두 커밋(둘째가 $KEY 의 경로를 만든다). CWD = 리포
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; git add f.txt; git commit -qm r0
  mkdir -p docs; echo '# design' > docs/x-design.md
  git add docs/x-design.md; git commit -qm "add design doc"
}

decl_commit() {   # <파일> <내용> <메시지> [키] — 토픽 선언 트레일러를 단 커밋
  echo "$2" > "$1"; git add "$1"
  git commit -qm "$3

Spec: ${4:-$KEY}"
}

fixed_keys() { printf '%s\n' "$1" | grep -E '^[a-z_]+: ' | grep -vc '^commit: '; }
commit_lines() { printf '%s\n' "$1" | sed -n 's/^commit: //p'; }

case_usage() {
  new_repo
  local rc
  bash "$TH" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "인자 없음: exit 2"
  bash "$TH" "$SID" --topic >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 값 없음: exit 2"
  bash "$TH" "$SID" --bogus x >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "모르는 플래그: exit 2"
  cleanup
}

case_no_declaration() {
  new_repo
  git checkout -q -b plain; echo p > p.txt; git add p.txt; git commit -qm "plain (선언 없음)"
  local out rc; out=$(bash "$TH" "$SID"); rc=$?
  assert_eq "$rc" "0" "선언 없음: exit 0"
  assert_eq "$(field status "$out")" "no-declaration" "선언 없음: status: no-declaration"
  assert_eq "$(field seal "$out")" "-" "선언 없음: 봉인을 뜨지 않는다"
  assert_eq "$(fixed_keys "$out")" "12" "선언 없음: 고정 키 12줄"
  assert_eq "$(commit_lines "$out" | grep -c .)" "0" "선언 없음: commit: 줄 없음"
  cleanup
}

case_single_branch_topic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local C1; C1=$(git rev-parse HEAD)
  echo dirty > wip.txt
  local out S; out=$(bash "$TH" "$SID"); S=$(field seal "$out")
  assert_eq "$(field status "$out")" "ok" "단일 구성원: status: ok"
  assert_eq "$(fixed_keys "$out")" "12" "단일 구성원: 고정 키 12줄"
  assert_eq "$(field boundary "$out")" "$R" "단일 구성원: 경계 = 분기점"
  assert_grep "$S" '^[0-9a-f]{40}$' "단일 구성원: 봉인 SHA"
  assert_eq "$(field tips "$out")" "$S" "단일 구성원: 끝점은 봉인 하나(현재 tip 은 봉인의 조상)"
  assert_eq "$(field head_commit "$out")" "$S" "단일 구성원: 합칠 것이 없으면 head_commit = 봉인"
  assert_eq "$(field tree "$out")" "$(git rev-parse "$S^{tree}")" "단일 구성원: tree = 봉인의 트리"
  assert_grep "$(git ls-tree -r --name-only "$(field tree "$out")")" '^wip\.txt$' "미커밋 파일이 합친 트리에 있다"
  assert_eq "$(field commits "$out")" "1" "본 커밋 1"
  assert_eq "$(commit_lines "$out")" "$C1" "본 커밋 SHA 가 commit: 줄로 실린다(AC15)"
  cleanup
}

case_two_siblings_combined() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local CA; CA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local CB; CB=$(git rev-parse HEAD)
  echo dirty > wip.txt
  local out T H; out=$(bash "$TH" "$SID"); T=$(field tree "$out"); H=$(field head_commit "$out")
  assert_eq "$(field status "$out")" "ok" "형제 둘: status: ok"
  local names; names=$(git ls-tree -r --name-only "$T")
  assert_grep "$names" '^a\.txt$' "합친 트리에 형제 topicA 의 변경(AC3)"
  assert_grep "$names" '^b\.txt$' "합친 트리에 현재 브랜치의 변경"
  assert_grep "$names" '^wip\.txt$' "합친 트리에 미커밋 변경(AC6 — 봉인을 먼저 넣었다)"
  assert_eq "$(git rev-parse "$H^{tree}")" "$T" "head_commit 의 트리 = tree"
  assert_not_grep "$H" "^$(field seal "$out")\$" "형제가 있으면 head_commit 은 봉인이 아니다"
  assert_eq "$(field commits "$out")" "2" "본 커밋 2"
  assert_eq "$(commit_lines "$out" | sort | paste -sd, -)" "$(printf '%s\n' "$CA" "$CB" | sort | paste -sd, -)" \
    "commit: 줄 = 두 선언 커밋(봉인은 토픽 커밋이 아니다)"
  cleanup
}

case_merged_member_combined() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local CA; CA=$(git rev-parse HEAD)
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "머지된 구성원: status: ok(AC4)"
  assert_grep "$(field branches "$out")" '(^|,)merged:[0-9a-f]{40}(,|$)' "머지된 구성원이 merged: 로 있다"
  assert_grep "$(git ls-tree -r --name-only "$(field tree "$out")")" '^a\.txt$' "머지된 구성원의 변경이 합친 트리에 있다"
  assert_grep "$(commit_lines "$out")" "^$CA\$" "머지된 구성원의 커밋이 본 커밋에 있다"
  assert_eq "$(field boundary "$out")" "$R" "경계 = 작업 시작점(AC5 — 머지된 앞 브랜치가 기준선에 숨지 않는다)"
  cleanup
}

case_conflict_lists_files() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt fromA "a1"
  git checkout -q -b topicB "$R"; decl_commit f.txt fromB "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "merge-conflict" "같은 파일을 달리 고친 형제: merge-conflict(AC7)"
  assert_grep "$(field conflicts "$out")" '(^|,)f\.txt(,|$)' "충돌 파일이 conflicts: 에 나열된다"
  assert_eq "$(field tree "$out")" "-" "충돌이면 tree: -"
  assert_eq "$(field head_commit "$out")" "-" "충돌이면 head_commit: -"
  assert_eq "$(field commits "$out")" "2" "충돌이어도 본 커밋은 싣는다"
  assert_eq "$(fixed_keys "$out")" "12" "충돌: 고정 키 12줄"
  cleanup
}

case_declared_path_absent() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1" 'docs/nope-design.md#pr1'
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "declaration-invalid" "경로 부재: declaration-invalid(AC16)"
  assert_grep "$(field reason "$out")" 'nope-design\.md' "reason 이 부재 경로를 이름 붙인다"
  assert_eq "$(field commits "$out")" "-" "깨진 선언: commits: -"
  cleanup
}

case_two_fragments_on_one_branch() {
  new_repo
  git checkout -q -b stacked; decl_commit a.txt a1 "a1" 'docs/x-design.md#pr1'
  decl_commit b.txt b1 "b1" 'docs/x-design.md#pr2'
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "declaration-invalid" "한 브랜치에 조각 둘: declaration-invalid(조용히 합치지 않는다)"
  assert_eq "$(field seal "$out")" "-" "감지 단계에서 멈춘다 — 봉인을 뜨지 않는다"
  assert_grep "$(field reason "$out")" '2 distinct' "reason 이 키 개수를 적는다"
  cleanup
}

case_explicit_topic_skips_detect() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b plain "$R"; echo p > p.txt; git add p.txt; git commit -qm "plain"
  assert_eq "$(field status "$(bash "$TH" "$SID")")" "no-declaration" "플래그 없이: 현재 브랜치에 선언 없음(양의 짝)"
  local out; out=$(bash "$TH" "$SID" --topic "$KEY")
  assert_eq "$(field status "$out")" "ok" "--topic: 감지를 건너뛰고 그 토픽을 푼다"
  assert_eq "$(field topic_key "$out")" "$KEY" "--topic: topic_key 가 그 값"
  assert_eq "$(field seal_on_topic "$out")" "no" "현재 브랜치가 토픽 밖이면 seal_on_topic: no(공시)"
  cleanup
}

case_unrelated_member_is_unbounded() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q --orphan island; git rm -rqf .; decl_commit i.txt i1 "i1"
  git checkout -q -b topicA "$R"; decl_commit a.txt a1 "a1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "unbounded" "히스토리가 끊긴 구성원: unbounded(경계를 못 센다)"
  cleanup
}

case_runs_from_subdirectory() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  mkdir -p sub/deep; cd sub/deep || return
  assert_eq "$(field status "$(bash "$TH" "$SID")")" "ok" "하위 디렉토리에서 불러도 status: ok"
  cleanup
}

case_remote_only_sibling_is_combined() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git update-ref refs/remotes/origin/main "$R"
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git update-ref refs/remotes/origin/topicA HEAD
  git checkout -q main; git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "원격-전용 형제: status: ok"
  assert_grep "$(git ls-tree -r --name-only "$(field tree "$out")")" '^a\.txt$' "원격-전용 형제의 변경이 합친 트리에 있다"
  assert_not_grep "$(field branches "$out")" '(^|,)(origin|origin/HEAD|origin/main|main)(,|$)' \
    "base 원격 ref · origin/HEAD(=origin) 는 구성원이 아니다"
  cleanup
}

case_no_side_effects() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt; echo mod >> b.txt
  local st0 h0 idx0 wl0 refs0
  st0=$(git status --porcelain); h0=$(git rev-parse HEAD); idx0=$(git ls-files -s | git hash-object --stdin)
  wl0=$(git worktree list --porcelain); refs0=$(git for-each-ref)
  bash "$TH" "$SID" >/dev/null
  assert_eq "$(git status --porcelain)" "$st0" "워킹트리 상태 불변"
  assert_eq "$(git rev-parse HEAD)" "$h0" "HEAD 불변"
  assert_eq "$(git ls-files -s | git hash-object --stdin)" "$idx0" "실제 인덱스 불변"
  assert_eq "$(git worktree list --porcelain)" "$wl0" "워크트리 추가 없음"
  assert_eq "$(git for-each-ref)" "$refs0" "ref 추가 · 이동 없음"
  cleanup
}

for c in case_usage case_no_declaration case_single_branch_topic case_two_siblings_combined \
         case_merged_member_combined case_conflict_lists_files case_declared_path_absent \
         case_two_fragments_on_one_branch case_explicit_topic_skips_detect \
         case_unrelated_member_is_unbounded case_runs_from_subdirectory \
         case_remote_only_sibling_is_combined case_no_side_effects; do
  echo "== $c"; $c
done
finish
```

```bash
chmod +x plugins/quality-gates/tests/test_topic_head.sh
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_head.sh && bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | tail -2
```

  **기대** — 스크립트가 없어 거의 전부 `✗`(`Fail:` 이 0 이 아니다).

- [ ] **Step 3: 구현한다** — `plugins/quality-gates/scripts/topic-head.sh`:

```bash
#!/usr/bin/env bash
# topic-head.sh — 선언 → 봉인 → 경계 · 끝점 → 합친 HEAD 트리를 한 번에 풀어 튜플 하나를 낸다.
#   (설계 2026-09-21 §6.2.2–§6.2.6 · §6.4.1, AC3–AC7 · AC15 · AC16)
#
#   topic-head.sh <session-id> [--topic <topic-key>]   -> key: value 12줄 + commit: N줄
#
# `--topic` 이 없으면 `resolve-topic.sh detect` 가 현재 브랜치에서 토픽 키를 찾는다.
# `--topic` 은 `qg-worktree.sh create-head --topic` 이 HEAD 축을 다시 도출할 때 쓴다.
#
# **사실만 낸다.** `status:` 를 판정 사유로 옮기는 것은 `scope_tuple.py` 다.
#
#   ok                   합친 트리가 섰다 (tree · head_commit 채워짐)
#   no-declaration       현재 브랜치에 선언이 없다 — 기존 세 모드로
#   base-unresolved      base 를 못 풀어 선언 여부를 모른다
#   declaration-invalid  선언이 깨졌다 (경로 부재 · 한 브랜치에 여러 키 · 고아)
#   unbounded            선언은 있는데 경계 · 끝점을 못 셌다
#   seal-failed          워킹트리 봉인 실패 — HEAD 축을 못 세운다
#   merge-conflict       끝점 합치기가 충돌 (conflicts: 에 파일)
#   merge-failed         끝점 합치기가 충돌 아닌 이유로 실패 (conflicts: 에 stderr 첫 줄)
#
# 봉인 · 합치기 커밋은 ref · reflog 를 얻지 않는다 — git 의 prune 이 회수한다
# (tests/test_qg_objects_unreachable.sh).
#
# bash 3.2 호환: 배열 대신 공백 · 콤마 구분 문자열을 쓴다.
set -u

die() { echo "topic-head: $*" >&2; exit 2; }
usage="usage: topic-head.sh <session-id> [--topic <topic-key>]"

SID="${1:-}"; [ -n "$SID" ] || die "$usage"
KEY=""
if [ $# -eq 3 ] && [ "$2" = "--topic" ]; then
  KEY="$3"; [ -n "$KEY" ] || die "$usage"
elif [ $# -ne 1 ]; then
  die "$usage"
fi
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"

BRANCHES="-"; BOUNDARY="-"; TIPS="-"; SEAL="-"; SEAL_ON_TOPIC="-"
TREE="-"; HEAD_COMMIT="-"; CONFLICTS="-"; NCOMMITS="-"; COMMITS=""

emit() {   # <status> <reason>
  echo "topic_key: ${KEY:--}"
  echo "status: $1"
  echo "reason: ${2:--}"
  echo "branches: $BRANCHES"
  echo "boundary: $BOUNDARY"
  echo "tips: $TIPS"
  echo "seal: $SEAL"
  echo "seal_on_topic: $SEAL_ON_TOPIC"
  echo "tree: $TREE"
  echo "head_commit: $HEAD_COMMIT"
  echo "conflicts: $CONFLICTS"
  echo "commits: $NCOMMITS"
  [ -n "$COMMITS" ] && printf '%s\n' "$COMMITS" | sed 's/^/commit: /'
  exit 0
}
val() { printf '%s\n' "$2" | sed -n "s/^$1: //p" | head -1; }

# exit 2 는 사용 오류뿐이다. 아래 단계의 실패(하위 스크립트 비0 · 기대 키 부재)는 status 로
# 낸다 — SKILL ① 이 비0 을 「멈춘다」로 읽으므로, 일시적 git 실패가 /qg 전체를 세우지 않고
# session 으로 내려가 그 사유가 공시되게 한다.

# 1. 토픽 키
if [ -z "$KEY" ]; then
  d=$(bash "$HERE/resolve-topic.sh" detect) || emit base-unresolved "resolve-topic.sh detect failed"
  st=$(val status "$d")
  case "$st" in
    ok) KEY=$(val topic_key "$d") ;;
    no-declaration|base-unresolved|declaration-invalid) emit "$st" "$(val reason "$d")" ;;
    *) emit base-unresolved "resolve-topic.sh detect gave no status" ;;
  esac
fi

# 2. 봉인 — 워킹트리(수정 · 삭제 · untracked)가 HEAD 축 후보에 «먼저» 들어간다(§6.2.4)
SEAL=$(bash "$HERE/seal-worktree.sh" seal "$SID") || SEAL=""
[ -n "$SEAL" ] || { SEAL="-"; emit seal-failed "seal-worktree.sh failed"; }

# 3. 경계 · 끝점
r=$(bash "$HERE/resolve-topic.sh" resolve "$KEY" --seal "$SEAL") || emit unbounded "resolve-topic.sh resolve failed"
BRANCHES=$(val branches "$r"); BOUNDARY=$(val boundary "$r"); TIPS=$(val tips "$r")
SEAL_ON_TOPIC=$(val seal_on_topic "$r")
case "$(val status "$r")" in
  ok) ;;
  declaration-invalid) emit declaration-invalid "$(val reason "$r")" ;;
  no-declaration) emit declaration-invalid "no commit carries this topic key" ;;
  base-unresolved) emit unbounded "$(val reason "$r")" ;;
  *) emit unbounded "resolve-topic.sh resolve gave no status" ;;
esac
[ -n "$TIPS" ] && [ "$TIPS" != "-" ] || emit unbounded "resolve-topic.sh gave no tips"

# 4. 본 커밋 T — 봉인은 끝점이지만 토픽 커밋이 아니다(§6.2.6)
COMMITS=$(bash "$HERE/resolve-topic.sh" commits "$KEY") || { COMMITS=""; emit unbounded "resolve-topic.sh commits failed"; }
NCOMMITS=$(printf '%s\n' "$COMMITS" | grep -c .)
[ "$NCOMMITS" -gt 0 ] || COMMITS=""

# 5. 합치기 — combine-tips 는 공백-구분 인자를 받는다
c=$(bash "$HERE/combine-tips.sh" $(printf '%s' "$TIPS" | tr ',' ' ')) || emit merge-failed "combine-tips.sh failed"
case "$(val status "$c")" in
  ok)
    TREE=$(val tree "$c")
    last=$(val intermediates "$c" | tr ',' '\n' | tail -1)
    if [ -z "$last" ] || [ "$last" = "-" ]; then
      # 끝점이 하나 — 그것은 봉인이다(봉인은 새 커밋이라 어느 끝점의 조상도 아니다)
      if [ "$TIPS" != "$SEAL" ]; then
        TREE="-"; emit merge-failed "single endpoint is not the seal: $TIPS"
      fi
      HEAD_COMMIT="$SEAL"
    else
      HEAD_COMMIT="$last"
    fi
    emit ok "-" ;;
  merge-conflict)
    CONFLICTS=$(val conflicts "$c")
    emit merge-conflict "merge-tree conflict at $(val failed_at "$c")" ;;
  *)
    CONFLICTS=$(val conflicts "$c")
    emit merge-failed "combine-tips status: $(val status "$c")" ;;
esac
```

```bash
chmod +x plugins/quality-gates/scripts/topic-head.sh
bash -n plugins/quality-gates/scripts/topic-head.sh
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | tail -1
```

  **기대** — `Fail: 0` 둘.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/topic-head.sh plugins/quality-gates/tests/test_topic_head.sh
git ls-files -s plugins/quality-gates/scripts/topic-head.sh plugins/quality-gates/tests/test_topic_head.sh | cut -c1-6
git commit -m "feat(qg): topic-head.sh — 선언 → 봉인 → 끝점 → 합친 트리 튜플" \
  -m "PR1 의 resolve-topic.sh · combine-tips.sh 를 한 진입 모듈로 묶는다. 봉인을 끝점 후보에 먼저 넣고, 합친 트리 · head_commit · 경계 · 본 커밋 SHA 를 12키 튜플로 낸다. 못 쓰는 선언은 status 여덟으로 가른다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

  **기대** — 두 파일 모두 `100755`.

---

### Task 3: `create-head --topic` — 합친 트리를 지금 다시 도출해 대조한다

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`(머리 주석의 `create-head` 항목 · `create-head)` 분기)
- Test: `plugins/quality-gates/tests/test_topic_head.sh`(케이스 셋 추가)

**Interfaces:**
- Consumes: `topic-head.sh <sid> --topic <key>`(Task 2) — `status:` · `tree:`
- Produces: `qg-worktree.sh create-head <sha> <session-id> [--topic <topic-key>]` → 성공 시 워크트리 절대 경로 한 줄, exit 0. `--topic` 이 있으면 `<sha>^{tree}` 가 지금 다시 도출한 합친 트리와 같아야 한다 — 다르거나 `status` 가 `ok` 가 아니면 exit 2 + stderr 에 그 `status`. 인자 모양이 다르면 exit 2. 인자 둘 모양은 불변.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_topic_head.sh` 의 `for c in …` 앞에 넣는다:

```bash
case_create_head_topic_accepts_derived_commit() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt
  local out H h; out=$(bash "$TH" "$SID"); H=$(field head_commit "$out")
  if h=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>/dev/null) \
     && [ -f "$h/a.txt" ] && [ -f "$h/b.txt" ] && [ -f "$h/wip.txt" ]; then
    ok "합친 커밋 → create-head --topic 수락 · 트리에 형제 · 현재 · 미커밋 변경(양의 짝)"
    bash "$WT" remove "$h" >/dev/null 2>&1
  else
    no "합친 커밋인데 create-head --topic 이 거부했거나 트리에 셋이 없다"
  fi
  cleanup
}

case_create_head_topic_rejects_wrong_commits() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  echo dirty > wip.txt
  # 거부의 «이유»까지 잰다 — 옛 usage 오류가 되살아나도 exit 2 라 종료 코드만으로는 못 가른다.
  local out S H err; out=$(bash "$TH" "$SID"); S=$(field seal "$out"); H=$(field head_commit "$out")
  err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "봉인 단독 → create-head --topic 거부 · 트리 대조로(형제가 빠진 트리)"
  err=$(bash "$WT" create-head "$R" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "경계 → create-head --topic 거부 · 트리 대조로"
  err=$(bash "$WT" create-head "$H" "$SID" 2>&1 >/dev/null)
  assert_grep "$err" 'sealed-sha mismatch' "--topic 없이 합친 커밋 → 봉인 대조가 거부(그대로)"
  echo later > later.txt
  err=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY" 2>&1 >/dev/null)
  assert_grep "$err" 'head-commit mismatch' "① 뒤 워킹트리가 바뀌면 거부(stale) · 트리 대조로"
  assert_eq "$(git worktree list | grep -c 'head-')" "0" "거부된 호출은 HEAD 축 워크트리를 만들지 않는다"
  cleanup
}

case_create_head_topic_rejects_conflicted_topic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt fromA "a1"
  git checkout -q -b topicB "$R"; decl_commit f.txt fromB "b1"
  local S; S=$(bash "$SEALER" seal "$SID")
  local err rc; err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null); rc=$?
  assert_eq "$rc" "2" "충돌 토픽: create-head --topic exit 2"
  assert_grep "$err" 'merge-conflict' "충돌 토픽: stderr 가 status 를 이름 붙인다"
  cleanup
}

case_create_head_usage() {
  new_repo
  local S rc; S=$(bash "$SEALER" seal "$SID")
  bash "$WT" create-head "$S" "$SID" --topic >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 값 없음: exit 2"
  bash "$WT" create-head "$S" "$SID" --topic "" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--topic 빈 값: exit 2"
  bash "$WT" create-head "$S" "$SID" --bogus "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "모르는 플래그: exit 2"
  cleanup
}
```

  루프 목록 마지막 줄 `         case_remote_only_sibling_is_combined case_no_side_effects; do` 를:

```bash
         case_remote_only_sibling_is_combined case_no_side_effects \
         case_create_head_topic_accepts_derived_commit case_create_head_topic_rejects_wrong_commits \
         case_create_head_topic_rejects_conflicted_topic case_create_head_usage; do
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `create-head --topic` 수락 · 거부 넷(`head-commit mismatch` 셋 — 오늘 stderr 는 `usage: create-head …` 라 RED · `sealed-sha mismatch` 하나는 오늘도 GREEN) · 충돌 stderr 가 `✗`. usage 케이스 셋(`--topic` 값 없음 · 빈 값 · 모르는 플래그)은 오늘도 인자 개수로 exit 2 라 GREEN — 이빨은 구현 뒤에 선다.

- [ ] **Step 3: 구현한다** — `qg-worktree.sh`.

  (a) 머리 주석의 `create-head` 항목 — 옛 문면:

```bash
#   create-head <sealed-sha> <session-id>
#                                -> echoes absolute worktree path; detached at the sealed
#                                   commit (seal-worktree.sh 가 봉인한 커밋). Re-seals the
#                                   working tree and asserts the tree matches before
#                                   building the worktree — the sha is not a declared free
#                                   variable (§6.4.1). No sandbox required.
```

  새 문면:

```bash
#   create-head <sealed-sha> <session-id> [--topic <topic-key>]
#                                -> echoes absolute worktree path; detached at the given
#                                   commit. Without --topic: re-seals the working tree
#                                   (seal-worktree.sh) and asserts the trees match. With
#                                   --topic: re-derives the combined topic tree
#                                   (topic-head.sh --topic) and asserts the trees match.
#                                   Either way the sha is not a declared free variable
#                                   (§6.4.1). No sandbox required.
```

  (b) `create-head)` 분기 — 옛 문면(주석 여섯 줄은 그대로 두고 그 아래부터):

```bash
    [[ $# -eq 3 ]] || die "usage: create-head <sealed-sha> <session-id>"
    git rev-parse --verify --quiet "$2^{commit}" >/dev/null \
      || die "not a commit: $2"
    ch_expected=$(bash "$(dirname "${BASH_SOURCE[0]}")/seal-worktree.sh" seal "$3") \
      || die "cannot re-seal the working tree to verify the HEAD axis"
    [[ "$(git rev-parse "$2^{tree}")" == "$(git rev-parse "$ch_expected^{tree}")" ]] \
      || die "sealed-sha mismatch: tree of '$2' is not the tree of the working tree sealed now — the HEAD axis must be built from the seal, not from merge_base or a stale seal"

    make_detached_worktree "$2" "$3" head
```

  새 문면:

```bash
    # 선언 경로(--topic)의 HEAD 축은 봉인이 아니라 «봉인 + 구성원 끝점»을 합친 트리다.
    # 같은 규율 — 기대 트리를 지금 다시 도출해 대조한다(topic-head.sh 가 봉인부터 다시 뜬다).
    ch_topic=""
    if [[ $# -eq 5 && "$4" == "--topic" && -n "$5" ]]; then
      ch_topic="$5"
    elif [[ $# -ne 3 ]]; then
      die "usage: create-head <sealed-sha> <session-id> [--topic <topic-key>]"
    fi
    git rev-parse --verify --quiet "$2^{commit}" >/dev/null \
      || die "not a commit: $2"
    if [[ -z "$ch_topic" ]]; then
      ch_expected=$(bash "$(dirname "${BASH_SOURCE[0]}")/seal-worktree.sh" seal "$3") \
        || die "cannot re-seal the working tree to verify the HEAD axis"
      [[ "$(git rev-parse "$2^{tree}")" == "$(git rev-parse "$ch_expected^{tree}")" ]] \
        || die "sealed-sha mismatch: tree of '$2' is not the tree of the working tree sealed now — the HEAD axis must be built from the seal, not from merge_base or a stale seal"
    else
      ch_out=$(bash "$(dirname "${BASH_SOURCE[0]}")/topic-head.sh" "$3" --topic "$ch_topic") \
        || die "cannot re-derive the topic HEAD axis"
      ch_status=$(printf '%s\n' "$ch_out" | sed -n 's/^status: //p' | head -1)
      [[ "$ch_status" == "ok" ]] \
        || die "topic HEAD axis is not derivable now (status: ${ch_status:-?}) — no combined tree to verify against"
      ch_tree=$(printf '%s\n' "$ch_out" | sed -n 's/^tree: //p' | head -1)
      [[ "$(git rev-parse "$2^{tree}")" == "$ch_tree" ]] \
        || die "head-commit mismatch: tree of '$2' is not the combined topic tree derived now — the topic HEAD axis must be built from topic-head.sh's head_commit, not from the seal alone, the boundary, or a stale value"
    fi

    make_detached_worktree "$2" "$3" head
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/qg-worktree.sh
bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh 2>&1 | tail -1
bash plugins/quality-gates/tests/test_qg_worktree_helper.sh 2>&1 | tail -1
```

  **기대** — `Fail: 0` 셋(뒤 둘은 기준선 그대로).

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_topic_head.sh
git commit -m "feat(qg): create-head --topic — 합친 트리를 다시 도출해 대조" \
  -m "선언 경로의 HEAD 축 커밋은 topic-head.sh 가 지금 다시 도출한 합친 트리와 같아야 한다. 봉인 단독 · 경계 · stale 값 · 충돌 토픽은 거부한다. 인자 둘 모양은 그대로." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 4: 판정 튜플 — `scope_tuple.py` · 합성기 `--scope` · 두 사유의 산출

**Files:**
- Create: `plugins/quality-gates/scripts/scope_tuple.py`
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(docstring 한 줄 · import 한 줄 · argparse · 사용 오류 두 자리 · 판정 계산 · 꼬리)
- Modify: `tools/adjudication/check_wiring.py`(면제 키 재앵커)
- Create: `plugins/quality-gates/tests/test_scope_tuple.sh`(실행비트)
- Modify: `plugins/quality-gates/tests/test_verdict_vocabulary.sh`(`debt` 비움 · 산출자에 `STATUS_TO_REASON` · 주석)
- Modify: `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh`(핀 메시지만)

**Interfaces:**
- Consumes: 스코프 파일 = `topic-head.sh` 출력(Task 2)
- Produces:
  - `scope_tuple.KEYS`(12) · `scope_tuple.STATUSES`(8) · `scope_tuple.STATUS_TO_REASON = {"declaration-invalid": "declaration-invalid", "unbounded": "declaration-invalid", "merge-conflict": "merge-conflict", "merge-failed": "merge-conflict"}`
  - `scope_tuple.parse(text) -> dict`(키 12 + `"commit": [sha, …]`; 형식 위반은 exit 4) · `scope_tuple.reason_of(d) -> str | None` · `scope_tuple.render(d) -> str` · `scope_tuple.read_or_fail4(path) -> str`
  - 합성기 `--scope PATH`: `--emit-verdict` 없이 주면 exit 2 · 빈 문자열이면 exit 2 · 파일 파손이면 exit 4(stdout 빈 채) · 정상이면 꼬리가 `scope:` 블록 → `angles:` 블록(있으면) → `verdict:` 순서이고, `reason_of` 가 낸 사유가 `--reason` 들과 함께 `verdict.decide(extra_reasons=…)` 로 간다.
  - `scope:` 블록 모양(들여쓰기 두 칸):
    ```
    scope:
      mode: topic|session
      status: <status>
      topic_key: <…>
      detail: <reason 값>
      branches: <…>
      boundary: <…>
      tips: <…>
      tree: <…>
      seal_on_topic: <…>
      conflicts: <…>
      commits: <N|->
      commit: <sha>          (N 줄)
    ```
    `mode` 는 `status == ok` 일 때만 `topic` 이다. `seal` · `head_commit` 은 배관 값이라 렌더하지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/quality-gates/tests/test_scope_tuple.sh`:

```bash
#!/usr/bin/env bash
# test_scope_tuple.sh — scripts/scope_tuple.py · 합성기 `--scope`
#   (설계 §6.2.6 · §6.4.3, AC7 · AC15 · AC16)
#
# 스코프 파일은 topic-head.sh 산출물의 모양이다 — 여기서는 손으로 써서 합성기의 행동
# (판정 · 사유 · `scope:` 블록)만 잰다. topic-head.sh 자신은 test_topic_head.sh 가 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1

B=1111111111111111111111111111111111111111
C1=2222222222222222222222222222222222222222
C2=3333333333333333333333333333333333333333
S=4444444444444444444444444444444444444444
TR=5555555555555555555555555555555555555555
HC=6666666666666666666666666666666666666666
T=""

setup_clean_run() {   # 탐지 0 · 재비판 0 · 각도 전부 filled — 스코프만 판정을 움직인다
  T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
}

write_scope() {   # <path> <status> <reason> <tree> <head_commit> <conflicts> <commits> [commit...]
  local p="$1" st="$2" rs="$3" tr="$4" hd="$5" cf="$6" n="$7"; shift 7
  {
    printf 'topic_key: docs/x-design.md#pr1\nstatus: %s\nreason: %s\n' "$st" "$rs"
    printf 'branches: topicA,topicB\nboundary: %s\ntips: %s,%s\nseal: %s\nseal_on_topic: yes\n' "$B" "$C1" "$S" "$S"
    printf 'tree: %s\nhead_commit: %s\nconflicts: %s\ncommits: %s\n' "$tr" "$hd" "$cf" "$n"
    local c; for c in "$@"; do printf 'commit: %s\n' "$c"; done
  } > "$p"
}

write_undeclared() {   # <path> <status>
  printf 'topic_key: -\nstatus: %s\nreason: -\nbranches: -\nboundary: -\ntips: -\nseal: -\nseal_on_topic: -\ntree: -\nhead_commit: -\nconflicts: -\ncommits: -\n' "$2" > "$1"
}

line_of() { printf '%s\n' "$1" | grep -n -E "$2" | head -1 | cut -d: -f1; }

case_ok_scope_is_clean_and_carries_tuple() {
  setup_clean_run
  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 2 "$C1" "$C2"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: clean$'              "status: ok 는 판정을 막지 않는다"
  assert_grep "$out" '^scope:$'                      "scope: 블록이 꼬리에 있다(AC15)"
  assert_grep "$out" '^  mode: topic$'               "ok 면 mode: topic"
  assert_grep "$out" "^  boundary: $B\$"             "경계가 실린다"
  assert_grep "$out" "^  tips: $C1,$S\$"             "끝점이 실린다"
  assert_grep "$out" "^  tree: $TR\$"                "합친 트리 OID 가 실린다"
  assert_grep "$out" '^  commits: 2$'                "본 커밋 수가 실린다"
  assert_grep "$out" "^  commit: $C1\$"              "본 커밋 SHA 1"
  assert_grep "$out" "^  commit: $C2\$"              "본 커밋 SHA 2"
  local ls la lv; ls=$(line_of "$out" '^scope:$'); la=$(line_of "$out" '^angles:$'); lv=$(line_of "$out" '^verdict: ')
  assert_eq "$([ -n "$ls" ] && [ -n "$la" ] && [ -n "$lv" ] && [ "$ls" -lt "$la" ] && [ "$la" -lt "$lv" ] && echo ordered)" \
    "ordered" "꼬리 순서 = scope: → angles: → verdict:"
  rm -rf "$T"
}

case_conflict_is_not_certified_with_files() {
  setup_clean_run
  write_scope "$T/scope.txt" merge-conflict "merge-tree conflict at $C1" - - "f.txt,g.txt" 2 "$C1" "$C2"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: not-certified$'      "합치기 충돌은 clean 이 아니다(AC7)"
  assert_grep "$out" '^reason: merge-conflict$'      "사유는 merge-conflict"
  assert_grep "$out" '^  conflicts: f\.txt,g\.txt$'  "충돌 파일이 나열된다"
  assert_grep "$out" '^  mode: session$'             "충돌이면 mode: session(판정 대상은 현재 브랜치)"
  rm -rf "$T"
}

case_declaration_statuses_map_to_reasons() {
  setup_clean_run
  local st want out
  for st in declaration-invalid unbounded merge-failed; do
    case "$st" in merge-failed) want=merge-conflict ;; *) want=declaration-invalid ;; esac
    write_scope "$T/scope.txt" "$st" "x" - - - - 
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
    assert_grep "$out" '^verdict: not-certified$' "$st → not-certified"
    assert_grep "$out" "^reason: $want\$"        "$st → reason: $want"
  done
  rm -rf "$T"
}

case_non_blocking_statuses_disclose_only() {
  setup_clean_run
  local st out
  for st in no-declaration base-unresolved seal-failed; do
    write_undeclared "$T/scope.txt" "$st"
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
    assert_grep "$out" '^verdict: clean$'     "$st 는 스코프 사유를 내지 않는다(다른 경로가 막는다)"
    assert_grep "$out" "^  status: $st\$"     "$st 가 scope: 블록에 공시된다"
    assert_grep "$out" '^  mode: session$'    "$st → mode: session"
  done
  rm -rf "$T"
}

case_defect_beats_scope_reason() {
  T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  write_scope "$T/scope.txt" merge-conflict x - - "f.txt" -
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^verdict: defect$' "확증 결함은 스코프 미판정보다 우선한다(§6.4.3)"
  rm -rf "$T"
}

case_malformed_scope_is_atomic_fail4() {
  setup_clean_run
  local out rc f
  for f in missing-key bad-status count-mismatch ok-without-tree; do
    case "$f" in
      missing-key)     printf 'topic_key: -\nstatus: ok\n' > "$T/scope.txt" ;;
      bad-status)      write_undeclared "$T/scope.txt" "made-up" ;;
      count-mismatch)  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 3 "$C1" ;;
      ok-without-tree) write_scope "$T/scope.txt" ok - - "$HC" - 1 "$C1" ;;
    esac
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt" 2>/dev/null); rc=$?
    assert_eq "$rc" "4" "$f → exit 4"
    assert_eq "$out" "" "$f → stdout 비어 있음(원자적 실패)"
  done
  rm -rf "$T"
}

case_scope_flag_usage_errors() {
  setup_clean_run
  write_undeclared "$T/scope.txt" no-declaration
  local rc
  rf_synth "$T" --scope "$T/scope.txt" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--scope 는 --emit-verdict 없이 exit 2"
  rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "--scope 빈 문자열 exit 2"
  rm -rf "$T"
}

for c in case_ok_scope_is_clean_and_carries_tuple case_conflict_is_not_certified_with_files \
         case_declaration_statuses_map_to_reasons case_non_blocking_statuses_disclose_only \
         case_defect_beats_scope_reason case_malformed_scope_is_atomic_fail4 \
         case_scope_flag_usage_errors; do
  echo "== $c"; $c
done
finish
```

```bash
chmod +x plugins/quality-gates/tests/test_scope_tuple.sh
```

  그리고 `test_verdict_vocabulary.sh` 의 `case_reason_enum_is_closed_and_accounted` — 주석의 산출자 셋 목록 마지막 두 줄(「부채 — 산출자 없음(PR4c): declaration-invalid · merge-conflict」)을 아래로 바꾸고, `local debt=…` 줄과 파이썬 `produced = …` 줄을 고친다. 옛 문면:

```bash
  #   부채 — 산출자 없음(PR4c): declaration-invalid · merge-conflict
  local debt="declaration-invalid merge-conflict"
```

  새 문면:

```bash
  #   스코프 축(scope_tuple.STATUS_TO_REASON.values()): declaration-invalid · merge-conflict
  #   부채 — 산출자 없음: (없다 — 새 사유를 더할 때 산출자보다 먼저 여기 적는다)
  local debt=""
```

  같은 케이스의 파이썬 안 옛 줄:

```python
produced = set(verdict.CAUSE_TO_REASON.values()) | flag_produced | caller_produced
```

  새 줄 둘:

```python
import scope_tuple
produced = set(verdict.CAUSE_TO_REASON.values()) | set(scope_tuple.STATUS_TO_REASON.values()) | flag_produced | caller_produced
```

  `test_pipeline_verdict_wiring.sh` 의 `case_reason_literals_are_closed_and_pinned` — 핀 단언의 메시지만 바꾼다. 옛 줄:

```bash
    "SKILL 이 싣는 사유 집합(핀) — declaration-invalid · merge-conflict 는 4c"
```

  새 줄:

```bash
    "SKILL 이 싣는 사유 집합(핀) — declaration-invalid · merge-conflict 는 합성기가 --scope 파일에서 낸다(SKILL 이 옮겨 적지 않는다)"
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_scope_tuple.sh && bash plugins/quality-gates/tests/test_scope_tuple.sh 2>&1 | tail -2
bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `test_scope_tuple.sh` 대부분 `✗`(합성기가 `--scope` 를 모른다). 단 여섯은 오늘 이미 GREEN 이다 — `case_malformed_scope_is_atomic_fail4` 의 「stdout 비어 있음」 넷과 `case_scope_flag_usage_errors` 둘은 argparse 가 모르는 `--scope` 를 exit 2 · 빈 stdout 으로 거부해서다. 이빨은 구현 뒤에 선다(fail4 넷은 exit 4 단언이 RED 였다가 GREEN 이 된다). `test_verdict_vocabulary.sh` 는 `import scope_tuple` 이 실패해 그 케이스의 단언들이 `✗`(모듈이 없다).

- [ ] **Step 3: 구현한다** — (a) `plugins/quality-gates/scripts/scope_tuple.py`:

```python
#!/usr/bin/env python3
"""스코프 튜플 — `topic-head.sh` 산출물을 판정 꼬리의 `scope:` 블록으로 (설계 §6.2.6).

`clean` 은 이 튜플에 대한 clean 이다 — 본 커밋 · 끝점 · 경계 · 합친 트리가 판정과 한
출력에 실려야 나중에 트레일러를 고쳐도 이미 난 판정이 다른 대상으로 재사용되지 않는다
(AC15). 끝점 합치기가 충돌하면 충돌 파일을 싣는다(AC7).

`status:` → 판정 사유는 여기서만 정한다(`STATUS_TO_REASON`). 오케스트레이터는 사유를
옮겨 적지 않고 이 파일을 합성기에 `--scope` 로 넘긴다. 값 자체는 `verdict.REASONS`
안이고 `verdict.decide()` 가 검증한다.
"""
import re
import sys

KEYS = ("topic_key", "status", "reason", "branches", "boundary", "tips", "seal",
        "seal_on_topic", "tree", "head_commit", "conflicts", "commits")
STATUSES = ("ok", "no-declaration", "base-unresolved", "declaration-invalid",
            "unbounded", "seal-failed", "merge-conflict", "merge-failed")
# 사유가 없는 status 는 스코프 축에서 막지 않는다 — `no-declaration` 은 새 의무가 아니고
# (§6.2.5), `base-unresolved` 는 차등 테스트 R-init 의 「baseline 확정 불가」가,
# `seal-failed` 는 R5b 의 HEAD 축 미관측이 이미 막는다. `unbounded` · `merge-failed` 는
# 가장 가까운 이름으로 보낸다 — 토픽이 한 판정 단위를 못 이룸 · 끝점을 합치지 못함.
STATUS_TO_REASON = {
    "declaration-invalid": "declaration-invalid",
    "unbounded": "declaration-invalid",
    "merge-conflict": "merge-conflict",
    "merge-failed": "merge-conflict",
}
_OID = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}")
_COUNT = re.compile(r"[0-9]+")
_RENDER_ORDER = ("topic_key", "reason", "branches", "boundary", "tips", "tree",
                 "seal_on_topic", "conflicts")


def fail4(msg):
    # 스크립트 이름을 접두사로 쓴다 — `scope:` 로 시작하면 줄-지향 파서가 블록으로 읽는다.
    print(f"scope_tuple.py: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_or_fail4(path):
    """호출자가 이미 「쓴다」고 정한 경로다 — 부재가 곧 실패다(`angles.read_or_fail4` 와 같다)."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as exc:
        fail4(f"스코프 파일을 읽지 못했다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"스코프 파일이 UTF-8 이 아님: {path} ({exc})")


def parse(text):
    seen = {}
    commits = []
    for line in text.splitlines():
        if not line.strip():
            continue
        key, sep, val = line.partition(": ")
        if not sep:
            fail4(f"key: value 가 아닌 줄: {line!r}")
        if key == "commit":
            if not _OID.fullmatch(val):
                fail4(f"commit 값이 커밋 id 가 아니다: {val!r}")
            commits.append(val)
            continue
        if key not in KEYS:
            fail4(f"모르는 키: {key!r}")
        if key in seen:
            fail4(f"키가 두 번: {key!r}")
        seen[key] = val
    missing = [k for k in KEYS if k not in seen]
    if missing:
        fail4("빠진 키: " + ", ".join(missing))
    if seen["status"] not in STATUSES:
        fail4(f"열거 밖 status: {seen['status']!r}")
    if seen["commits"] == "-":
        if commits:
            fail4("commits: - 인데 commit: 줄이 있다")
    elif not _COUNT.fullmatch(seen["commits"]) or int(seen["commits"]) != len(commits):
        fail4(f"commits: {seen['commits']} 와 commit: 줄 {len(commits)}개가 다르다")
    if seen["status"] == "ok":
        for k in ("boundary", "tree", "head_commit", "seal"):
            if not _OID.fullmatch(seen[k]):
                fail4(f"status: ok 인데 {k} 가 id 가 아니다: {seen[k]!r}")
        if not all(_OID.fullmatch(t) for t in seen["tips"].split(",")):
            fail4(f"status: ok 인데 tips 가 id 목록이 아니다: {seen['tips']!r}")
        if seen["commits"] == "-":
            fail4("status: ok 인데 commits 가 없다")
    d = dict(seen)
    d["commit"] = commits
    return d


def reason_of(d):
    return STATUS_TO_REASON.get(d["status"])


def render(d):
    """`scope:` 블록. `mode` 는 이 판정이 실제로 본 스코프다 — 토픽을 못 쓰면 session."""
    out = ["scope:",
           f"  mode: {'topic' if d['status'] == 'ok' else 'session'}",
           f"  status: {d['status']}"]
    for k in _RENDER_ORDER:
        label = "detail" if k == "reason" else k
        out.append(f"  {label}: {d[k]}")
    out.append(f"  commits: {d['commits']}")
    for c in d["commit"]:
        out.append(f"  commit: {c}")
    return "\n".join(out) + "\n"


def main():
    if len(sys.argv) != 2 or not sys.argv[1]:
        print("scope_tuple.py: usage: scope_tuple.py <스코프 파일>", file=sys.stderr)
        return 2
    sys.stdout.write(render(parse(read_or_fail4(sys.argv[1]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

  (b) `synthesize_findings.py` — 여섯 자리.

  - docstring 의 `  --angles PATH        각도 상태 파일(`<각도>: <상태>` 세 줄)` 줄 **아래**에 한 줄:

```text
  --scope PATH         스코프 튜플(topic-head.sh 산출물) — 꼬리에 `scope:` 블록 · 스코프 사유
```

  - `import angles as _angles` 줄 **아래**에 한 줄:

```python
import scope_tuple as _scope_tuple  # 스코프 축 — status → 사유 · `scope:` 블록
```

  - `ap.add_argument("--angles", default=None)` 줄 **아래**에:

```python
    # 스코프 튜플 — 기본 off. 주면 꼬리에 `scope:` 블록을 싣고, 그 status 가 사유로
    # 옮겨지는 것(scope_tuple.STATUS_TO_REASON)을 `--reason` 들과 함께 판정에 넘긴다.
    ap.add_argument("--scope", default=None)
```

  - `if args.angles is not None and args.angles == "":` 블록(4줄) **아래**에:

```python
    if args.scope is not None and args.scope == "":
        print("synthesize_findings.py: --scope 는 빈 문자열을 받지 않는다 "
              "(플래그를 생략하거나 실제 경로를 줘라)", file=sys.stderr)
        sys.exit(2)
```

  - `if not args.emit_verdict:` 블록 안, `if args.angles is not None:` 검사(5줄) **아래**에:

```python
        if args.scope is not None:
            print("synthesize_findings.py: --scope 는 --emit-verdict "
                  "없이는 의미가 없다 (함께 주거나 --scope 를 빼라)",
                  file=sys.stderr)
            sys.exit(2)
```

  - 판정 계산 — 옛 문면:

```python
    decision = None
    angle_states = None
    if args.emit_verdict:
```

  새 문면:

```python
    decision = None
    angle_states = None
    scope = None
    if args.emit_verdict:
        if args.scope is not None:
            scope = _scope_tuple.parse(_scope_tuple.read_or_fail4(args.scope))
        scope_reason = _scope_tuple.reason_of(scope) if scope is not None else None
```

  그리고 같은 블록의 `extra_reasons=args.reason,` 줄을:

```python
            extra_reasons=args.reason + ([scope_reason] if scope_reason else []),
```

  - 꼬리 — 옛 문면:

```python
        if angle_states is not None:
            sys.stdout.write(_angles.render(angle_states))
        sys.stdout.write(_verdict.render(decision))
```

  새 문면:

```python
        if scope is not None:
            sys.stdout.write(_scope_tuple.render(scope))
        if angle_states is not None:
            sys.stdout.write(_angles.render(angle_states))
        sys.stdout.write(_verdict.render(decision))
```

  그리고 그 바로 위 주석의 마지막 두 줄(줄바꿈을 가로지른다) — 옛 문면:

```python
        # 유지된다. 각도가 판정보다 **앞**인 것은 읽는 순서다: 무엇을 봤는지가
        # 그 판정의 근거다.
```

  새 문면:

```python
        # 유지된다. 스코프 · 각도가 판정보다 **앞**인 것은 읽는 순서다: 무엇을(스코프)
        # 누가(각도) 봤는지가 그 판정의 근거다.
```

  (c) 재앵커 — 합성기의 `dedup()` 안 `if f.get("promoted"):` 다음 줄 `continue` 의 새 줄번호를 잰다:

```bash
grep -n -A1 'if f.get("promoted"):' plugins/quality-gates/scripts/synthesize_findings.py
```

  그 `continue` 줄 번호로 `tools/adjudication/check_wiring.py` 의 `("plugins/quality-gates/scripts/synthesize_findings.py", 389,` 의 `389` 를 바꾼다(오늘 기대값 391 — **실측값을 쓴다**).

- [ ] **Step 4: 통과를 확인한다**

```bash
python3 -m py_compile plugins/quality-gates/scripts/scope_tuple.py plugins/quality-gates/scripts/synthesize_findings.py tools/adjudication/check_wiring.py
bash plugins/quality-gates/tests/test_scope_tuple.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh 2>&1 | tail -1
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -E 'exempt|Total'
for f in plugins/quality-gates/tests/test_synthesize_findings.sh plugins/quality-gates/tests/test_synthesize_disposition.sh plugins/quality-gates/tests/test_synthesize_promoted_findings.sh plugins/quality-gates/tests/test_angle_coverage.sh plugins/quality-gates/tests/test_recritic_bridge.sh; do bash "$f" 2>&1 | tail -1; done
```

  **기대** — 전부 `Fail: 0`(또는 각 파일의 기준선 그대로). `test_adjudication_wiring.sh` 가 `exempt_stale` 0 을 단언하고 통과한다. 마지막 루프가 가드에 막히면 파일 다섯을 한 줄씩 따로 돌린다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/scope_tuple.py plugins/quality-gates/scripts/synthesize_findings.py \
        tools/adjudication/check_wiring.py plugins/quality-gates/tests/test_scope_tuple.sh \
        plugins/quality-gates/tests/test_verdict_vocabulary.sh plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh
git commit -m "feat(qg): 판정 튜플 — 합성기 --scope · declaration-invalid · merge-conflict 산출" \
  -m "합성기가 스코프 파일을 읽어 꼬리에 scope: 블록(본 커밋 · 끝점 · 경계 · 합친 트리 · 충돌 파일)을 싣고, status 를 사유로 옮긴다(scope_tuple.STATUS_TO_REASON). 사유 열거는 11 그대로이고 SKILL 은 사유를 옮겨 적지 않는다. check_wiring 면제 키 재앵커." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 5: 차등 테스트 kill switch 를 스크립트가 집행한다 (M7)

**Files:**
- Modify: `plugins/quality-gates/scripts/run-test-selection.sh`(`adapter_usable()` 첫머리 · 머리 주석 `Exit:` 문단)
- Test: `plugins/quality-gates/tests/test_run_test_selection.sh`

**Interfaces:**
- Produces: `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 `probe` → `usable: no` · `reason: kill_switch` · exit 3, `run` → 전 unit `<unit>\tunrun\t-` · exit 3. 값이 `1` 이 아니면 효과 없음. `detect` · `assign` · `granularity` 는 저장소 코드를 돌리지 않으므로 영향 없음.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_run_test_selection.sh` 의 `case_run_test_failure_vs_absent_runner` 정의 **뒤**에:

```bash
# M7 — 차등 테스트 kill switch 는 보안 컨트롤이다. 저장소 코드(setup_cmd · 테스트)를 돌리는
# 유일한 관문(adapter_usable)에서도 선다 — 스위치를 켠 채 들어온 probe · run 은 아무것도
# 실행하지 않는다.
case_differential_kill_switch_refuses_repo_code() {
  mkw; mkdir -p "$W/tests"
  printf '#!/usr/bin/env bash\ntouch "%s/RAN"\n' "$W" > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  local out rc
  out=$(DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" probe "$W" shell 2>/dev/null); rc=$?
  assert_eq "$rc" "3" "스위치 on: probe exit 3"
  assert_grep "$out" '^usable: no$' "스위치 on: usable: no"
  assert_grep "$out" '^reason: kill_switch$' "스위치 on: reason: kill_switch"
  out=$(DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$W" shell per-unit tests/t.sh 2>/dev/null); rc=$?
  assert_eq "$rc" "3" "스위치 on: run exit 3"
  assert_eq "$out" "tests/t.sh${TAB}unrun${TAB}-" "스위치 on: 전 unit unrun"
  assert_eq "$([ -e "$W/RAN" ] && echo ran || echo not-ran)" "not-ran" "스위치 on: 테스트가 한 번도 돌지 않았다"
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=0 bash "$RTS" probe "$W" shell >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "값이 1 이 아니면 스위치가 아니다"
  bash "$RTS" run "$W" shell per-unit tests/t.sh >/dev/null 2>&1
  assert_eq "$([ -e "$W/RAN" ] && echo ran || echo not-ran)" "ran" "스위치 off: 같은 호출이 테스트를 돌린다(양의 짝)"
  rmw
}
```

  맨 아래 루프 목록에서 `case_run_test_failure_vs_absent_runner` 이름 바로 뒤에 ` case_differential_kill_switch_refuses_repo_code` 를 더한다(같은 줄, 공백 하나).

- [ ] **Step 2: 실패를 확인한다**

```bash
bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — 스위치 on 단언들이 `✗`(오늘 probe 는 `usable: yes`, run 은 테스트를 돌린다).

- [ ] **Step 3: 구현한다** — `adapter_usable()` 의 `USABLE_REASON=""` 줄 바로 **아래**에:

```bash

  # 차등 테스트 kill switch — 이 관문 뒤는 전부 저장소 코드(setup_cmd · 러너 · 테스트)다.
  # 오케스트레이터가 ② 를 건너뛰는 것이 1차 집행이고, 이것은 그 산문을 읽지 않은 호출을
  # 막는 2차 집행이다. 거부 모양은 기존 계약 그대로(probe: usable: no + reason · run: unrun).
  if [[ "${DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST:-}" == "1" ]]; then
    echo "run-test-selection: 차등 테스트가 DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다 — 저장소 코드를 돌리지 않는다 ($runner in $w)" >&2
    USABLE_REASON=kill_switch; return 1
  fi
```

  그리고 머리 주석의 `# Exit: 0 = 정상 · 2 = 사용 오류 · 3 = 어댑터 사용 불가` 문단 아래에 한 줄:

```bash
#       `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 probe · run 은 언제나 3 (reason: kill_switch)
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/run-test-selection.sh
bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | grep -cE '^[[:space:]]*(✗|FAIL[ :])'
```

  **기대** — 첫 락 `Fail: 0`. `test_runner_adapters.sh` 는 선재 RED — 실패 줄 수가 기준선(1)과 같다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/tests/test_run_test_selection.sh
git commit -m "fix(qg): 차등 테스트 kill switch 를 run-test-selection 도 집행" \
  -m "DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 이면 probe · run 이 저장소 코드를 돌리지 않는다(usable: no · reason: kill_switch / 전 unit unrun, exit 3). 보안 컨트롤이 산문에만 있던 자리(PR4b 부채 M7)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 6: 레퍼런스의 옛 § 포인터를 걷어낸다

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`(14줄 + 308줄의 `⑭`)
- Test: `plugins/quality-gates/tests/test_one_pipeline_surface.sh`

**Interfaces:**
- Produces: 레퍼런스에 `§` 0개. 잔여 결함 공시 문장은 남는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_one_pipeline_surface.sh` 의 마지막 케이스 정의 뒤, `for c in …` 앞에:

```bash
case_reference_has_no_design_section_pointers() {
  # 레퍼런스는 모델이 읽고 행동하는 산출물이다. 설치본에 없는 설계 문서의 절 번호(§)를
  # 싣지 않는다 — 모델이 없는 절을 찾게 된다. 설계를 가리켜야 하면 개념으로 적는다.
  assert_eq "$(grep -c '§' "$REF")" "0" "레퍼런스에 § 절 포인터가 0개"
  # 양의 짝 — 번호를 빼면서 잔여 결함의 공시까지 지우지 않았다
  assert_file_grep "$REF" '이 축은 잔여 결함이며 \*\*열려 있다\*\*' "R-init 잔여 결함 공시가 남았다"
  assert_file_grep "$REF" '^\*\*남은 것\(정직한 잔여\):\*\*' "R8 정직한 잔여 공시가 남았다"
  assert_file_grep "$REF" '잔여 결함과 같은 축이며 열려 있다' "custody 축 공시가 남았다"
  assert_file_grep "$REF" '빈 스코프 축' "행 0개 축 공시가 남았다"
}
```

  루프 목록 `case_pipeline_order case_no_gate_scope_question; do` 를 `case_pipeline_order case_no_gate_scope_question \` 과 다음 줄 `         case_reference_has_no_design_section_pointers; do` 로 바꾼다.

- [ ] **Step 2: 실패를 확인한다**

```bash
bash plugins/quality-gates/tests/test_one_pipeline_surface.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `§ 절 포인터가 0개` 와 양의 짝 넷 중 새 문구 넷이 `✗`.

- [ ] **Step 3: 구현한다** — 아래 표의 **옛 조각**을 찾아 **새 조각**으로 바꾼다(줄번호는 오늘 값 — 앞 Task 가 이 파일을 안 건드리므로 그대로다). 표의 한 행이 줄바꿈을 가로지르면 원문 줄 경계를 그대로 두고 조각만 바꾼다.

| 줄 | 옛 조각 | 새 조각 |
|---|---|---|
| 62 | `**미측정**이다(§11 ㉜).` | `**미측정**이다.` |
| 126 | `이미 있는 파일을 0바이트로 자르는 것 하나로 §11 ㉓ 집행이 발화하지 않고` | ``이미 있는 파일을 0바이트로 자르는 것 하나로 `unclaimed` 집행이 발화하지 않고`` |
| 129 | `이 축은 §6.7 S1(잔여 결함)이며 **열려 있다**` | `이 축은 잔여 결함이며 **열려 있다**` |
| 130 | `이거나 §11 ㉛ 의 생산자-발행 terminator 이고` | `이거나 생산자-발행 terminator 이고` |
| 205–207 | `로 읽는 것이 §6.7 F6` ⏎ `> 이 이름 붙인 결함이고, 스크립트 헤더가 예전에 *fail-open* 을 지시하고 있어 코드 수정만` ⏎ `> 으로는 닫히지 않았다(같은 라운드에 헤더도 함께 고쳤다).` | `로 읽지 않는다.` (세 줄이 한 줄로 끝난다 — 205줄은 `> "범위를 확정하지 못했다" 를 "이 diff 는 테스트를 건드리지 않는다" 로 읽지 않는다.` 가 되고 206 · 207 은 지운다) |
| 306 | `**아니다**(§11 ⑭, 열려 있음).` | `**아니다**(빈 스코프 축 — 열려 있다).` |
| 308 | `⑭ 를 **부수효과로 닫아**` | `그 축을 **부수효과로 닫아**` |
| 314 | `이 라운드의 범위 밖이다(§11 에 등재).` | `열려 있다.` |
| 468 | `§5.4 의 비대칭 논증은` | `① 의 방향 비대칭 논증은` |
| 720 | `**남은 것(정직한 잔여 — §11 ⑰):**` | `**남은 것(정직한 잔여):**` |
| 819 | `§11 ⑳ 의 누수이고` | `알려진 누수이고` |
| 917 | ` (§11 ⑱).**` | `.**` |
| 925 | ` (§11 ㉓).**` | `.**` |
| 940 | `않는다 — §6.7 S1 과 같은 축이며 열려 있다.` | `않는다 — R-init 의 잔여 결함과 같은 축이며 열려 있다.` |
| 943 | `쓰면 거짓이다. 그 축은 §11 ⑭ 이며 열려 있다.` | `쓰면 거짓이다. 그 축(빈 스코프)은 열려 있다.` |

- [ ] **Step 4: 통과를 확인한다**

```bash
grep -c '§' plugins/quality-gates/skills/quality-pipeline/references/differential-test.md
grep -n '⑭' plugins/quality-gates/skills/quality-pipeline/references/differential-test.md || echo "OK ⑭ 0"
bash plugins/quality-gates/tests/test_one_pipeline_surface.sh 2>&1 | grep -E '✗|Total'
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u | comm -13 "$CLAUDE_JOB_DIR/tmp/pr4c-baseline-harness-fails.txt" -
```

  **기대** — `0` · `OK ⑭ 0` · `Fail: 0` · 기준선 그대로 · 마지막 명령 빈 출력(새 하네스 실패 0).

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/tests/test_one_pipeline_surface.sh
git commit -m "docs(qg): 차등 테스트 레퍼런스의 옛 설계 § 포인터를 걷어낸다" \
  -m "레퍼런스의 § 14곳이 전부 설치본에 없는 archive 설계 문서의 절 번호였다. 잔여 결함의 공시 문장은 그대로 두고 번호만 뺀다. 새 § 가 다시 들어오면 락이 잡는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 7: SKILL 배선 — trivia 관문 · ① 1a · 상태 표 · Step 4 `--scope` · 표면

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Modify: `plugins/quality-gates/scripts/check-allowed-tools-order.sh`(`EXPECTED_ORDER`)
- Create: `plugins/quality-gates/tests/test_topic_scope_wiring.sh`(실행비트)

**Interfaces:**
- Consumes: `resolve-topic.sh detect`(Task 1) · `topic-head.sh`(Task 2) · 합성기 `--scope`(Task 4) · `scope_tuple.STATUSES`(Task 4)
- Produces: 스코프 파일 경로 **리터럴** `.claude/quality-gates/<session-id>/topic-scope.txt`(Task 8 의 R-init 이 같은 리터럴로 읽는다)

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/quality-gates/tests/test_topic_scope_wiring.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/scope_tuple.py
# test_topic_scope_wiring.sh — 토픽 스코프 배선 (설계 §6.2 · §6.4.1, AC3–AC7 · AC15 · AC16).
#
# 오케스트레이터 산문이 스크립트 산출물을 «실제로» 흘리는가를 잰다. 각 사실은 그것이 적힌
# 한 줄(또는 한 펜스)에서 잰다 — 다른 행이 대신 만족시키면 뒤집기를 못 잡는다. 열거가
# 필요한 단언은 코드의 열거(scope_tuple.STATUSES)에서 도출한다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/scripts/scope_tuple.py; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
export PYTHONDONTWRITEBYTECODE=1

# 파이썬 본문은 `$( )` 안 heredoc 으로 두지 않는다 — bash 3.2 는 그 본문의 짝 없는 괄호 ·
# 따옴표로 치환 경계를 잘못 잡는다. 최상위 heredoc 으로 변수에 담고 `python3 -c` 로 넘긴다.
IFS= read -r -d '' PY_TRIVIA <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^## Trivia escape\n(.*?)(?=^## )', text, re.S | re.M)
lines = (m.group(1) if m else "").splitlines()
det = [i for i, l in enumerate(lines) if 'resolve-topic.sh" detect' in l]
trv = [i for i, l in enumerate(lines) if 'check-trivia.sh' in l]
print("DETECT:%d" % len(det))
print("DETECT_FIRST:%d" % (1 if det and trv and det[0] < trv[0] else 0))
skip = [l for l in lines if 'status: ok' in l and 'status: declaration-invalid' in l and '**쓰지 않고**' in l]
print("SKIP_LINE:%d" % len(skip))
print("SKIP_NO_NODECL:%d" % (1 if skip and all('no-declaration' not in l for l in skip) else 0))
PY

IFS= read -r -d '' PY_STATUS <<'PY' || true
import re, sys
sys.path.insert(0, sys.argv[2])
import scope_tuple
text = open(sys.argv[1], encoding="utf-8").read()
missing, wrong = [], []
for st in scope_tuple.STATUSES:
    pat = re.compile(r'^\s*\| `' + re.escape(st) + r'` \|')
    rows = [l for l in text.splitlines() if pat.match(l)]
    if len(rows) != 1:
        missing.append(st)
        continue
    r = rows[0]
    if st == "ok":
        if "**topic**" not in r or "| session |" in r:
            wrong.append(st)
    elif "| session |" not in r or "**topic**" in r:
        wrong.append(st)
print("MISSING:" + ",".join(missing))
print("WRONG:" + ",".join(wrong))
PY

case_trivia_escape_is_gated_by_declaration() {
  # Review Focus 2 · R-AO — 선언이 있으면 trivia escape 를 쓰지 않는다.
  local got; got=$(python3 -c "$PY_TRIVIA" "$SKILL")
  assert_grep "$got" '^DETECT:1$'         "Trivia escape 절에 detect 호출 펜스가 하나"
  assert_grep "$got" '^DETECT_FIRST:1$'   "detect 가 check-trivia 보다 먼저 나온다"
  assert_grep "$got" '^SKIP_LINE:1$'      "ok · declaration-invalid 면 trivia escape 를 쓰지 않는다(한 줄)"
  assert_grep "$got" '^SKIP_NO_NODECL:1$' "그 줄에 no-declaration 이 없다(선언 없는 브랜치는 trivia 를 쓴다)"
}

case_step1_writes_scope_file() {
  # R-AJ — ① 1a 가 매 iteration topic-head.sh 출력을 고정 경로에 쓴다. 산문으로 옮기면
  # 실행되지 않으므로 bash 펜스 «안»의 줄만 센다.
  local n
  n=$(awk '/^[[:space:]]*```bash/{f=1;next} /^[[:space:]]*```/{f=0} f' "$SKILL" \
      | grep -cF '"$QG/scripts/topic-head.sh" "<session-id>" > ".claude/quality-gates/<session-id>/topic-scope.txt"')
  assert_eq "$n" "1" "① 1a 펜스가 topic-head.sh 출력을 .claude/quality-gates/<session-id>/topic-scope.txt 에 쓴다(한 줄)"
}

case_status_table_is_total_over_statuses() {
  # R-AK — 상태 표가 scope_tuple.STATUSES 전부를 받고, ok 만 topic 이다.
  local got; got=$(python3 -c "$PY_STATUS" "$SKILL" "$PLUGIN_ROOT/scripts")
  assert_grep "$got" '^MISSING:$' "상태 표가 STATUSES 여덟 전부를 정확히 한 행씩 받는다"
  assert_grep "$got" '^WRONG:$'   "ok 행만 **topic**, 나머지는 session"
}

case_topic_diff_uses_boundary_and_tree() {
  # ② · ③ 이 같은 트리를 본다 — 파일 집합 · diff 는 스코프 파일의 boundary · tree 에서.
  # `git ` 으로 시작하는 줄이면 A20 락이 session 합집합으로 끌어가 실행한다.
  local got
  got=$(grep -F "sed -n 's/^boundary: //p'" "$SKILL" | grep -F "sed -n 's/^tree: //p'" | grep -F 'git diff --name-only "$b" "$t"')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "파일 집합 질의가 boundary · tree 를 한 줄에서 읽는다"
  assert_not_grep "$got" '^[[:space:]]*git ' "그 줄은 git 으로 시작하지 않는다(A20 session 오라클 밖)"
}

case_step4_row_carries_scope() {
  # R-AL — 두 사유와 scope: 블록은 합성기가 이 파일에서 낸다. SKILL 의 의무는 싣는 것 하나.
  local rows
  rows=$(grep -F -- '--scope ".claude/quality-gates/<session-id>/topic-scope.txt"' "$SKILL")
  assert_eq "$(printf '%s\n' "$rows" | grep -c '^[[:space:]]*|')" "1" "Step 4 판정 입력 표에 --scope 행이 하나"
  assert_grep "$rows" 'topic-head\.sh' "그 행이 조건(① 이 topic-head.sh 를 불렀다)을 같은 줄에 적는다"
  assert_not_grep "$rows" '싣지 않|없음|생략' "그 행이 부정형(싣지 않는다 · 없음 · 생략)이 아니다"
}

case_scope_block_surfaces() {
  # AC15 — scope: 블록이 판정 옆(Step 4.5)과 Final Summary 에 그대로 나간다.
  local s45 fs
  s45=$(grep -F '`scope:` 블록' "$SKILL" | grep -F '**그대로**')
  assert_eq "$(printf '%s\n' "$s45" | grep -c .)" "1" "Step 4.5 가 scope: 블록을 그대로 보인다(한 줄)"
  fs=$(awk '/^## Final Summary$/{f=1;next} f&&/^## /{exit} f' "$SKILL" | grep -F '`scope:`' | grep -F '`angles:`' | grep -F 'verbatim')
  assert_eq "$(printf '%s\n' "$fs" | grep -c .)" "1" "Final Summary 가 scope: · angles: 블록을 verbatim 으로 싣는다(한 줄)"
}

for c in case_trivia_escape_is_gated_by_declaration case_step1_writes_scope_file \
         case_status_table_is_total_over_statuses case_topic_diff_uses_boundary_and_tree \
         case_step4_row_carries_scope case_scope_block_surfaces; do
  echo "== $c"; $c
done
finish
```

```bash
chmod +x plugins/quality-gates/tests/test_topic_scope_wiring.sh
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_scope_wiring.sh && bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — 여섯 케이스 전부 `✗` 를 낸다.

- [ ] **Step 3: 구현한다** — SKILL.md 아홉 자리, 그리고 `check-allowed-tools-order.sh`.

  (a) `allowed-tools` Group 1 — 옛 문면:

```yaml
  # Group 1 — Preflight scripts (실행 순서: setup → trivia → 스코프 신호)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verdict.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
```

  새 문면:

```yaml
  # Group 1 — Preflight scripts (실행 순서: setup → 선언 감지 → trivia → 스코프 신호 → 토픽 해소)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resolve-topic.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/verdict.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-review-scope.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/topic-head.sh:*)
```

  `check-allowed-tools-order.sh` 의 `EXPECTED_ORDER` Group 1 네 줄도 같은 여섯 줄(작은따옴표 · 같은 순서)로 바꾸고, 그 위 주석 `# Group 1 — Preflight scripts` 는 그대로 둔다.

  (b) `## Trivia escape` 절의 첫 줄 `Run \`scripts/check-trivia.sh\` (plugin root per Step P0b). Exit code:` **위**에 넣는다(이 블록의 가운데 한 줄은 **한 줄로** 둔다 — 락이 한 줄로 잰다):

`````markdown
**선언이 있으면 trivia escape 를 쓰지 않는다.** `branch` · `--paths` override 가 없으면 먼저 현재
브랜치의 토픽 선언을 감지한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/resolve-topic.sh" detect
```

`status: ok` 또는 `status: declaration-invalid` 면 trivia escape 를 **쓰지 않고** 곧장 iteration 1 로 간다 — 선언된 작업은 spec 에 묶인 작업 단위라, 현재 브랜치의 diff 가 한 문장이어도 판정 대상은 토픽 전체다.
그 밖(`no-declaration` · `base-unresolved`)이거나 override 가 있으면 아래대로 한다.

`````

  (c) `## Review` 의 Step 1 첫 줄 — 옛 문면(한 줄):

```markdown
1. **Resolve the review scope** — `paths` / `branch` / `session` (`session` = the default: no `branch` arg, no `--paths`). **There is no preflight scope**; nothing upstream hands you a file set, so you derive it here, from git, every turn:
```

  새 문면 — 한 줄을 아래 블록으로 바꾼다(들여쓰기 세 칸은 목록 항목 안이라는 뜻이다 — 그대로 둔다):

`````markdown
1. **Resolve the review scope** — `topic` / `session` / `branch` / `paths`. `branch` · `--paths` 는 override 다. override 가 없으면 **먼저 1a 로 토픽 선언을 푼다** — 풀리면 `topic`, 아니면 `session`(`session` = no `branch` arg, no `--paths`, no usable declaration). **There is no preflight scope**; nothing upstream hands you a file set, so you derive it here, from git, every turn.

   **1a — 토픽 선언 (override 가 없을 때 · 매 iteration · 이 스텝에서 가장 먼저).**

   ```bash
   QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
   "$QG/scripts/topic-head.sh" "<session-id>" > ".claude/quality-gates/<session-id>/topic-scope.txt" && cat ".claude/quality-gates/<session-id>/topic-scope.txt"
   ```

   exit 0 이 아니면(사용 오류) stderr 를 그대로 보이고 멈춘다. 파일의 `status:` 로 이 iteration 의 스코프가 갈린다:

   | `status:` | 스코프 | 그다음 |
   |---|---|---|
   | `ok` | **topic** — 경계와 합친 트리 사이의 변경 | 차등 테스트의 R-init 이 경계를 기준선으로, 합친 트리를 HEAD 축으로 쓴다 |
   | `no-declaration` | session | 공지하지 않는다 — 선언은 새 능력이지 새 의무가 아니다 |
   | `declaration-invalid` | session | 공지 한 줄 · Step 4 의 `--scope` 가 판정을 `not-certified (declaration-invalid)` 로 만든다 |
   | `unbounded` | session | 공지 한 줄 · `--scope` 가 `not-certified (declaration-invalid)` 로 만든다 |
   | `merge-conflict` | session | 공지 한 줄 · `--scope` 가 `not-certified (merge-conflict)` 로 만들고 충돌 파일을 싣는다 |
   | `merge-failed` | session | 공지 한 줄 · `--scope` 가 `not-certified (merge-conflict)` 로 만든다 |
   | `seal-failed` | session | 공지 한 줄 · 차등 테스트는 R5b 의 봉인 실패 라우팅을 탄다 |
   | `base-unresolved` | session | 차등 테스트의 R-init 이 baseline 확정 불가로 처리한다 |

   공지 한 줄: `> [quality-gates] 토픽 선언을 이번 iteration 에 쓰지 못했다 (<status>: <reason 값>) — session 스코프로 진행한다.`

   `topic` 스코프의 파일 집합(= `$resolved_scope_file_count` 의 집합):

   ```bash
   S=".claude/quality-gates/<session-id>/topic-scope.txt"; b=$(sed -n 's/^boundary: //p' "$S"); t=$(sed -n 's/^tree: //p' "$S"); git diff --name-only "$b" "$t"
   ```

   reviewer 에게 주는 diff(`FILTERED_DIFF`)는 같은 두 값의 `git diff "$b" "$t"` 에서 문서 경로를 뺀 것이다. 스코프 파일은 Step 4 가 `--scope` 로 다시 읽는다 — 이 iteration 동안 지우거나 고치지 않는다.

   **session 스코프**(1a 가 `topic` 을 내지 않았거나 override):
`````

  이 블록 바로 아래에 기존 session 펜스(`MERGE_BASE=$("$QG/scripts/resolve-baseline.sh" …` 를 담은 것)가 그대로 온다.

  (d) Scope transparency 문단 — 옛 문장 조각 `(\`<COUNT>\` = \`$resolved_scope_file_count\` — 정의는 Step 4.5 "Resolved-scope file count" 참조, \`check-review-scope.sh\` 산출값이 아니다).` **뒤**에 한 문장을 더한다(같은 문단, 같은 줄 끝):

```markdown
 스코프가 `topic` 으로 풀렸으면(N=1) 대신 `> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).` 를 낸다.
```

  (e) Kill switch 문단(`**Kill switch — \`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1\`.**` 로 시작) — 마지막 문장 `이 스위치는 그것을 끄는 보안 컨트롤이다.` **뒤**(같은 문단)에:

```markdown
 테스트를 돌리는 스크립트(`run-test-selection.sh` 의 `probe` · `run`)도 이 스위치가 켜져 있으면 저장소 코드를 돌리지 않는다(`usable: no` · `reason: kill_switch`). 1a 는 git 만 쓰므로 스위치와 무관하게 돈다.
```

  (f) security-reviewer Agent 리터럴의 `diff_scope` 힌트 — 옛 조각:

```text
(session (git-derived changed files) / branch (git diff vs base) / paths (--paths globs) — the review scope you resolved at step 1)
```

  새 조각:

```text
(topic (경계..합친 트리) / session (git-derived changed files) / branch (git diff vs base) / paths (--paths globs) — the review scope you resolved at step 1)
```

  (g) Step 4 판정 입력 표 — `| ② 가 kill switch 로 생략됐다(Step 1c) | \`--reason kill-switch\` |` 행 **아래**에 한 행(들여쓰기 세 칸, 한 줄):

```markdown
   | 기본 모드 — ① 1a 가 `topic-head.sh` 를 불렀다(`status:` 가 무엇이든) | `--scope ".claude/quality-gates/<session-id>/topic-scope.txt"` — `declaration-invalid` · `merge-conflict` 사유와 `scope:` 블록은 합성기가 이 파일에서 낸다 |
```

  (h) Step 4.5 — `- stdout 을 **그대로** 사용자에게 보인다(요약 · 재서술 금지). 앞에 한 줄:` 로 시작하는 항목(두 줄)의 **아래**에 항목 하나(한 줄):

```markdown
   - 꼬리의 `scope:` 블록을 **그대로** 보인다(요약 금지) — 본 커밋 · 끝점 · 경계 · 합친 트리가 이 판정의 대상이다.
```

  (i) Final Summary — 옛 문장:

```markdown
Then print the last synthesizer output's `angles:` block verbatim if any (the
```

  새 문장(한 줄로 — 락이 한 줄에서 잰다. 뒤 줄 `trivia escape has none — …` 은 그대로 이어진다):

```markdown
Then print the last synthesizer output's `scope:` block and `angles:` block verbatim if any (the
```

  그리고 「Resolved-scope file count」 정의 문단 — 원문이 줄바꿈을 가로지른다. 옛 두 줄:

```markdown
   fed into `scout.py`. It is **never** copied from `check-review-scope.sh`: for
   the default (`session`) that set is the git-derived changed-file set (branch
```

  새 세 줄:

```markdown
   fed into `scout.py`. It is **never** copied from `check-review-scope.sh`: for
   `topic` it is the `git diff --name-only <boundary> <tree>` set from step 1a; for
   the default (`session`) that set is the git-derived changed-file set (branch
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
bash plugins/quality-gates/scripts/check-allowed-tools-order.sh && echo "OK allowed-tools 순서"
for f in test_check_allowed_tools_order test_skill_bash_allowlist_narrow test_one_pipeline_surface test_pipeline_verdict_wiring test_git_derived_scope test_qg_false_clean_floor; do bash "plugins/quality-gates/tests/$f.sh" 2>&1 | tail -1; done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py 2>&1 | tail -2
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u | comm -13 "$CLAUDE_JOB_DIR/tmp/pr4c-baseline-harness-fails.txt" -
```

  **기대** — 새 락 `Fail: 0` · `OK allowed-tools 순서` · 여섯 락 기준선 그대로 · A20 `OK` · 플러그인 루트 락 기준선 그대로 · 마지막 명령 빈 출력. A20 이 실패하면 새 펜스의 어느 줄이 `git ` 으로 시작하는지 본다. `for` 줄이 가드에 막히면 여섯을 한 줄씩 돌린다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/scripts/check-allowed-tools-order.sh plugins/quality-gates/tests/test_topic_scope_wiring.sh
git commit -m "feat(qg): SKILL 토픽 스코프 배선 — trivia 관문 · 1a · --scope · scope: 블록" \
  -m "override 가 없으면 ① 이 매 iteration topic-head.sh 로 스코프 파일을 쓰고, 파일 집합 · 리뷰어 diff 를 경계..합친 트리에서 뽑는다. 선언이 있으면 trivia escape 를 쓰지 않는다. 합성기에 --scope 를 싣고 scope: 블록을 판정 옆 · Final Summary 에 그대로 보인다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 8: 레퍼런스 배선 — R-init 의 기준선 · HEAD 축 · `$scan_dir` · R4 · R5b · 창 표

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`
- Test: `plugins/quality-gates/tests/test_topic_scope_wiring.sh`(케이스 넷 추가)

**Interfaces:**
- Consumes: 스코프 파일 리터럴 경로(Task 7) · `create-head --topic`(Task 3)
- Produces: 오케스트레이터 변수 `$baseline_commit` · `$topic_key` · `$sealed` · `$head_tree_dir` · `$scan_dir`(R-init → R1a · R1b · R4 · R5b · R6)

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_topic_scope_wiring.sh` 의 `PY_STATUS` heredoc 블록 **아래**(케이스 정의들 앞)에 heredoc 둘을 더한다:

```bash
IFS= read -r -d '' PY_RINIT <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
fences = [b for b in re.findall(r'```bash\n(.*?)```', text, re.S) if 'topic-scope.txt' in b]
print("FENCES:%d" % len(fences))
lines = fences[0].splitlines() if fences else []
def idx(pred, start):
    for i in range(start, len(lines)):
        if pred(lines[i]):
            return i
    return -1
i_if = idx(lambda l: l.startswith('if [ "') and "s/^status: //p" in l and l.endswith('= ok ]; then'), 0)
i_else = idx(lambda l: l == 'else', i_if + 1) if i_if >= 0 else -1
i_fi = idx(lambda l: l == 'fi', i_else + 1) if i_else >= 0 else -1
shaped = i_fi > i_else > i_if >= 0
print("IF:%d" % (1 if shaped else 0))
ok_b = "\n".join(lines[i_if + 1:i_else]) if shaped else ""
el_b = "\n".join(lines[i_else + 1:i_fi]) if shaped else ""
checks = [
    ("OK_BASE", "baseline_commit=$(sed -n 's/^boundary: //p' \"$S\")" in ok_b),
    ("OK_SEALED", "sealed=$(sed -n 's/^head_commit: //p' \"$S\")" in ok_b),
    ("OK_TOPIC", 'create-head "$sealed" "<session-id>" --topic "$topic_key"' in ok_b),
    ("OK_SCAN", 'scan_dir="${head_tree_dir:-$project_dir}"' in ok_b),
    ("ELSE_BASE", 'baseline_commit="<위 6키의 merge_base>"' in el_b),
    ("ELSE_SCAN", 'scan_dir="$project_dir"' in el_b),
    ("ELSE_NO_TOPIC", "--topic" not in el_b),
]
for k, v in checks:
    print("%s:%d" % (k, 1 if v else 0))
PY

IFS= read -r -d '' PY_R4 <<'PY' || true
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^\*\*Step R4 — .*?(?=^\*\*Step R5b)', text, re.S | re.M)
win = m.group(0) if m else ""
fences = "\n".join(re.findall(r'```bash\n(.*?)```', win, re.S))
calls = re.findall(r'(?:baseline-cache\.sh" (?:get|put)|qg-worktree\.sh" create-baseline)[^\n\\]*(?:\\\n[^\n\\]*)*', fences)
good = [c for c in calls if '"$baseline_commit"' in c]
print("CALLS:%d" % len(calls))
print("GOOD:%d" % len(good))
print("MERGE_BASE_IN_FENCES:%d" % fences.count('$merge_base'))
PY
```

  그리고 `for c in …` 앞에 케이스 넷:

```bash
case_rinit_topic_branch_sets_axes() {
  # AC5 · AC6 · R-AP — 선언 경로의 기준선은 경계, HEAD 축은 create-head --topic 이 재도출 대조한
  # 합친 커밋. 각 값은 «그 갈래 안»에서 잰다 — 반대 갈래에 옮겨 적으면 RED.
  local got; got=$(python3 -c "$PY_RINIT" "$REF")
  assert_grep "$got" '^FENCES:1$'        "스코프 파일을 읽는 레퍼런스 펜스가 하나(R-init)"
  assert_grep "$got" '^IF:1$'            "그 펜스가 status == ok 로 if/else/fi 를 가른다"
  assert_grep "$got" '^OK_BASE:1$'       "ok 갈래: baseline_commit = boundary"
  assert_grep "$got" '^OK_SEALED:1$'     "ok 갈래: sealed = head_commit(전사 없이 파일에서)"
  assert_grep "$got" '^OK_TOPIC:1$'      "ok 갈래: create-head 가 --topic 으로 재도출 대조한다"
  assert_grep "$got" '^OK_SCAN:1$'       "ok 갈래: scan_dir = HEAD 축 트리"
  assert_grep "$got" '^ELSE_BASE:1$'     "else 갈래: baseline_commit = merge_base"
  assert_grep "$got" '^ELSE_SCAN:1$'     "else 갈래: scan_dir = project_dir"
  assert_grep "$got" '^ELSE_NO_TOPIC:1$' "else 갈래에 --topic 이 없다"
}

case_scan_dir_feeds_detect_and_assign() {
  # R-AP — 형제에만 있는 테스트 파일은 합친 트리에만 있다.
  assert_eq "$(grep -cF 'run-test-selection.sh" detect "$scan_dir"' "$REF")" "1" "R1a detect 가 \$scan_dir 를 본다"
  assert_eq "$(grep -cF 'run-test-selection.sh" assign "$scan_dir"' "$REF")" "1" "R1b assign 이 \$scan_dir 를 본다"
  assert_eq "$(grep -cE 'run-test-selection\.sh" (detect|assign) "\$project_dir"' "$REF")" "0" "R1a · R1b 에 \$project_dir 호출이 남지 않았다"
}

case_r4_calls_use_baseline_commit() {
  # AC5 — R4 의 세 호출(cache get · create-baseline · cache put)은 전부 $baseline_commit.
  local got; got=$(python3 -c "$PY_R4" "$REF")
  assert_grep "$got" '^CALLS:3$'               "R4 펜스에 호출 셋(get · create-baseline · put)"
  assert_grep "$got" '^GOOD:3$'                "셋 전부 \"\$baseline_commit\" 을 싣는다"
  assert_grep "$got" '^MERGE_BASE_IN_FENCES:0$' "R4 펜스에 \$merge_base 가 남지 않았다"
}

case_r5b_skips_on_topic() {
  # R-AP — 선언 경로의 R5b 는 봉인 · 트리 생성을 건너뛰고 R-init 의 값을 쓴다. 한 줄로 잰다.
  local got
  got=$(grep -F '**선언 경로면 이 스텝에서 봉인하지 않는다.**' "$REF")
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "R5b 에 선언 경로 규칙 문장이 하나"
  assert_grep "$got" 'R-init' "그 문장이 R-init 의 값을 쓴다고 적는다"
  assert_grep "$got" '\$head_tree_dir' "그 문장이 \$head_tree_dir 를 이름 붙인다"
}
```

  루프 목록 마지막 줄 `         case_step4_row_carries_scope case_scope_block_surfaces; do` 를:

```bash
         case_step4_row_carries_scope case_scope_block_surfaces \
         case_rinit_topic_branch_sets_axes case_scan_dir_feeds_detect_and_assign \
         case_r4_calls_use_baseline_commit case_r5b_skips_on_topic; do
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — 새 케이스 넷의 단언이 `✗`(`case_scan_dir_feeds_detect_and_assign` 의 「\$project_dir 0」 은 오늘 RED — 2). Task 7 케이스 여섯은 GREEN.

- [ ] **Step 3: 구현한다** — 레퍼런스 여섯 자리.

  (a) 창 표 — `| **창 없음** | \`$qg_run_tmp/aggregate.yaml\` |` 행 **위**에 한 행(한 줄):

```markdown
| | `.claude/quality-gates/<sid>/topic-scope.txt` | SKILL ① 1a 기록 → R-init(R4 앞) · Step 4 `--scope` 소비. `head_commit:` 변조는 R-init 의 `create-head --topic` 재도출 대조가 잡지만, Step 4 소비는 R4 · R5b · R6 뒤라 `status:` · 튜플 변조가 사유와 `scope:` 블록을 바꿀 수 있다. 봉인하지 않는다 — 아래 잔여 결함과 같은 축 |
```

  (b) R-init 끝 — 「`degraded: no` 일 때는 baseline 한 줄을 그대로 출력한다」 문단과 그 인용 줄(`> \`> [quality-gates] baseline: <base> @ <merge_base 앞 12자> (<ahead>커밋 앞섬)\``) **뒤**, `**Step R1a — 러너 어댑터 감지 (HEAD 트리).**` **앞**에:

`````markdown
**기준선 커밋 · HEAD 축 · 스캔 트리 — 선언 경로면 여기서 먼저 선다.** ① 1a 가 쓴 스코프
파일이 `status: ok` 면 기준선은 경계이고, HEAD 축은 1a 의 합친 커밋에서 **지금** 만든다 —
`create-head --topic` 이 합친 트리를 다시 도출해 대조하므로 1a 뒤 워킹트리가 바뀌었으면
죽는다. 형제 구성원에만 있는 테스트 파일은 합친 트리에만 있으므로 R1a · R1b 도 그 트리를
본다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
S=".claude/quality-gates/<session-id>/topic-scope.txt"
if [ "$(sed -n 's/^status: //p' "$S" 2>/dev/null)" = ok ]; then
  baseline_commit=$(sed -n 's/^boundary: //p' "$S")
  topic_key=$(sed -n 's/^topic_key: //p' "$S")
  sealed=$(sed -n 's/^head_commit: //p' "$S")
  head_tree_dir=$("$QG/scripts/qg-worktree.sh" create-head "$sealed" "<session-id>" --topic "$topic_key") || head_tree_dir=""
  scan_dir="${head_tree_dir:-$project_dir}"
else
  baseline_commit="<위 6키의 merge_base>"; topic_key=""; sealed=""; head_tree_dir=""
  scan_dir="$project_dir"
fi
printf 'baseline_commit=%s\ntopic_key=%s\nsealed=%s\nhead_tree_dir=%s\nscan_dir=%s\n' "$baseline_commit" "$topic_key" "$sealed" "$head_tree_dir" "$scan_dir"
```

다섯 값을 오케스트레이터 변수로 붙잡아 R6 까지 들고 간다. 선언 경로에서 `create-head` 가
죽었으면(`$head_tree_dir` 빈 값) stderr 를 그대로 보이고 R1a 로 계속 간다 — HEAD 축은 R5b 의
실패 라우팅 첫 행으로 처리된다. 선언 경로에서는 위 「차등 실행이 불가능한 조건」 표를 쓰지
않는다 — 기준선이 경계이고 경계는 HEAD 가 아니다. baseline 한 줄은 대신 이것이다:

> `> [quality-gates] baseline: topic <topic_key> @ <baseline_commit 앞 12자>`

`````

  (c) R1a 펜스 — `"$QG/scripts/run-test-selection.sh" detect "$project_dir"` → `"$QG/scripts/run-test-selection.sh" detect "$scan_dir"`. 그 펜스 아래 문단의 첫 문장 앞에 한 문장을 더한다: `\`$scan_dir\` 는 R-init 이 정한다 — 선언 경로면 HEAD 축 트리, 아니면 \`$project_dir\`.`

  (d) R1b 배정 펜스 — `  | "$QG/scripts/run-test-selection.sh" assign "$project_dir" \` → `  | "$QG/scripts/run-test-selection.sh" assign "$scan_dir" \`.

  (e) R4 — 세 펜스의 `"$merge_base"` 셋을 `"$baseline_commit"` 으로 바꾼다(① `baseline-cache.sh" get` 줄 아래 인자 줄 · ② `create-baseline \` 아래 인자 줄 · ③ `baseline-cache.sh" put \` 아래 인자 줄). 그리고 `**Step R4 — 기준선 측 (오케스트레이터 단독).**` 바로 아래 빈 줄 뒤에 문단 하나:

```markdown
이 스텝의 기준선 커밋은 R-init 의 `$baseline_commit` 이다 — 선언 경로면 경계, 아니면
merge_base. 아래 산문의 「merge_base」 는 그 값을 뜻한다. 선언 경로에서는 아래
`same_as_head` · `worktree_dirty` 스킵 표를 쓰지 않는다 — 언제나 R4 를 돈다.
```

  **`same_as_head` 를 담는 새 줄은 한정어(`worktree_dirty` · `clean` · `워킹 트리` 등)를 같은 줄에 싣는다** — `test_runtime_verdict_precedence.sh` 의 `case_same_as_head_never_unqualified` 가 한정어 없는 `same_as_head` 진술을 RED 로 잡는다(모의 실행 실측).

  (f) R5b — `먼저 워킹트리를 **봉인**하고(한 번, 어댑터 공통) 그 봉인 커밋에서 **HEAD 축 전용 트리**를` 로 시작하는 문장 **위**에 한 줄(한 줄로 — 락이 한 줄로 잰다):

```markdown
**선언 경로면 이 스텝에서 봉인하지 않는다.** R-init 이 `create-head --topic` 으로 만든 `$sealed` · `$head_tree_dir` 를 그대로 쓰고 아래 봉인 펜스를 건너뛴다 — R-init 의 그 호출이 실패했으면(`$head_tree_dir` 빈 값) 아래 실패 라우팅 첫 행 그대로다.

```

  그리고 R5b 실패 라우팅 표 첫 행의 조건 칸 — `\`seal-worktree.sh\` 가 non-zero(\`$sealed\` 빈 값) · 또는 \`create-head\` 가 non-zero(\`$head_tree_dir\` 빈 값)` → `\`seal-worktree.sh\` 가 non-zero(\`$sealed\` 빈 값) · 또는 \`create-head\`(선언 경로는 R-init 의 \`create-head --topic\`)가 non-zero(\`$head_tree_dir\` 빈 값)`.

- [ ] **Step 4: 통과를 확인한다**

```bash
bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
grep -c '§' plugins/quality-gates/skills/quality-pipeline/references/differential-test.md
for f in test_one_pipeline_surface test_pipeline_verdict_wiring test_runtime_verdict_precedence test_impact_runtime_docs; do bash "plugins/quality-gates/tests/$f.sh" 2>&1 | tail -1; done
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u | comm -13 "$CLAUDE_JOB_DIR/tmp/pr4c-baseline-harness-fails.txt" -
```

  **기대** — 새 락 `Fail: 0` · `0` · 넷과 플러그인 루트 락 기준선 그대로 · 마지막 빈 출력. 플러그인 루트 락이 **펜스 수 하한**으로 RED 면 하한이 아니라 **새 펜스가 가드 줄을 갖고 있는지**를 먼저 본다(PR4b Task 7 Step 9 가 그 락의 하한 셋을 다뤘다 — 이 PR 은 `shared/` 를 못 고친다; 하한 초과는 GREEN 이어야 한다).

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/tests/test_topic_scope_wiring.sh
git commit -m "feat(qg): 차등 테스트 토픽 배선 — 경계 기준선 · 합친 HEAD 축 · scan_dir" \
  -m "선언 경로면 R-init 이 스코프 파일에서 경계를 기준선으로, 합친 커밋을 create-head --topic 으로 HEAD 축으로 세우고, R1a · R1b 가 그 트리에서 어댑터를 감지 · unit 을 배정한다. R4 의 호출 셋은 baseline_commit, R5b 는 선언 경로에서 봉인을 건너뛴다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 9: GC — qg 커밋이 ref · reflog 를 얻지 않는다 (R-AN)

**Files:**
- Create: `plugins/quality-gates/tests/test_qg_objects_unreachable.sh`(실행비트)
- Modify: `plugins/quality-gates/scripts/combine-tips.sh`(머리 주석의 GC 문단만)

**Interfaces:**
- Consumes: `topic-head.sh` · `create-head [--topic]` · `seal-worktree.sh` · `qg-worktree.sh remove`

**선결** — R-AN 에 사용자가 동의했다(계획 리뷰). 동의가 없으면 이 Task 를 BLOCKED 로 보고한다.

- [ ] **Step 1: 테스트를 쓴다** — 이 락은 **green-expected** 다(오늘 코드가 이미 도달 불가를 지킨다 — 실측 P3). 이빨은 Task 11 의 변이(`git update-ref` 한 줄 삽입 → RED)가 증명한다. `plugins/quality-gates/tests/test_qg_objects_unreachable.sh`:

```bash
#!/usr/bin/env bash
# test_qg_objects_unreachable.sh — qg 가 만드는 커밋(봉인 · 재봉인 · 합치기 중간 · 합친 HEAD)은
# ref · reflog 를 얻지 않는다 → git 의 prune 이 회수한다 (계획 R-AN).
# 도달 가능해지는 순간 그 커밋과 그것이 담은 트리 · blob 은 영영 회수되지 않는다.
#
# 각 케이스는 mktemp 아래 일회용 git 리포를 세운다 — 실제 리포에서 fixture git 실행 금지.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TH="$PLUGIN_ROOT/scripts/topic-head.sh"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SEALER="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
SID='sessgc123456'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_topic_repo() {   # 형제 둘 + 미커밋 변경. CWD = 리포, 현재 = topicB
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; mkdir -p docs; echo d > docs/x-design.md; git add -A; git commit -qm r0
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; echo a > a.txt; git add a.txt; git commit -qm "a1

Spec: $KEY"
  git checkout -q -b topicB "$R"; echo b > b.txt; git add b.txt; git commit -qm "b1

Spec: $KEY"
  echo dirty > wip.txt
}

qg_commits() {   # 이 리포에서 qg 저자가 쓴 커밋 전부 — 도달 여부와 무관하게
  git cat-file --batch-all-objects --batch-check='%(objectname) %(objecttype)' \
    | awk '$2=="commit"{print $1}' \
    | while read -r c; do
        git cat-file -p "$c" | grep -q '^author qg seal <qg-seal@devbrew\.local> ' && echo "$c"
      done
}
unreachable_commits() { git fsck --unreachable --no-progress 2>/dev/null | awk '$1=="unreachable" && $2=="commit"{print $3}'; }

case_topic_run_leaves_no_reachable_qg_commit() {
  new_topic_repo
  local out H h; out=$(bash "$TH" "$SID"); H=$(field head_commit "$out")
  h=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY") || { no "create-head --topic 실패"; cleanup; return; }
  # 양의 짝 — 살아 있는 HEAD 축 워크트리는 그 커밋을 붙잡는다(도달성 검사가 이빨을 가진다)
  assert_not_grep "$(unreachable_commits)" "^$H\$" "살아 있는 워크트리의 HEAD 커밋은 도달 가능하다(양의 짝)"
  bash "$WT" remove "$h" >/dev/null 2>&1
  local qg un c bad=0 refd=0
  qg=$(qg_commits); un=$(unreachable_commits)
  assert_eq "$([ "$(printf '%s\n' "$qg" | grep -c .)" -ge 2 ] && echo enough)" "enough" "qg 커밋이 둘 이상 생겼다(봉인 · 합치기 — 공허하지 않다)"
  for c in $qg; do
    printf '%s\n' "$un" | grep -qx "$c" || bad=$((bad+1))
    [ -z "$(git for-each-ref --contains "$c")" ] || refd=$((refd+1))
  done
  assert_eq "$bad" "0" "remove 뒤 qg 커밋 전부가 fsck --unreachable 에 잡힌다(reflog 포함)"
  assert_eq "$refd" "0" "어떤 ref 도 qg 커밋을 담지 않는다"
  cleanup
}

case_session_run_leaves_no_reachable_qg_commit() {
  new_topic_repo
  local S h; S=$(bash "$SEALER" seal "$SID")
  h=$(bash "$WT" create-head "$S" "$SID") || { no "create-head 실패"; cleanup; return; }
  bash "$WT" remove "$h" >/dev/null 2>&1
  local qg un c bad=0
  qg=$(qg_commits); un=$(unreachable_commits)
  assert_eq "$([ "$(printf '%s\n' "$qg" | grep -c .)" -ge 1 ] && echo some)" "some" "봉인 커밋이 생겼다"
  for c in $qg; do printf '%s\n' "$un" | grep -qx "$c" || bad=$((bad+1)); done
  assert_eq "$bad" "0" "session 경로도 봉인 · 재봉인 커밋이 전부 도달 불가"
  cleanup
}

for c in case_topic_run_leaves_no_reachable_qg_commit case_session_run_leaves_no_reachable_qg_commit; do
  echo "== $c"; $c
done
finish
```

```bash
chmod +x plugins/quality-gates/tests/test_qg_objects_unreachable.sh
```

- [ ] **Step 2: 돌린다(GREEN 기대)**

```bash
bash -n plugins/quality-gates/tests/test_qg_objects_unreachable.sh && bash plugins/quality-gates/tests/test_qg_objects_unreachable.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `Fail: 0`. RED 면 어느 커밋이 어느 ref · reflog 에 붙잡혔는지 `git for-each-ref --contains` · `git reflog --all` 로 보고 **멈춰 보고한다**(R-AN 의 전제가 깨졌다 — 계획 결함).

- [ ] **Step 3: `combine-tips.sh` 머리 주석** — 옛 문면:

```bash
# 순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이다 — `intermediates:`
# 로 넘긴다. **이 출력의 소비자는 아직 없다.** GC 가 이것을 받는 것은 계획일 뿐이고
# (`qg-gc.py`/`gc_common.py` 는 git object 를 다루지 않는다 — TTL 로 세션 디렉토리만
# 지운다), 리포에 `git prune`/`fsck --unreachable`/`gc --prune` 호출도 0 개다.
```

  새 문면:

```bash
# 순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이다 — `intermediates:`
# 로 넘긴다(소비자: topic-head.sh 가 마지막 것을 HEAD 축 커밋으로 쓴다). 이 커밋들은
# ref · reflog 를 얻지 않으므로 git 의 prune 이 회수한다 — qg 는 `git prune` 을 부르지
# 않는다(리포 전체의 unreachable 객체를 지운다). 락: tests/test_qg_objects_unreachable.sh.
```

- [ ] **Step 4: 확인**

```bash
bash -n plugins/quality-gates/scripts/combine-tips.sh
bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | tail -1
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/tests/test_qg_objects_unreachable.sh plugins/quality-gates/scripts/combine-tips.sh
git commit -m "test(qg): qg 커밋이 ref · reflog 를 얻지 않음을 락으로 — GC 는 git prune" \
  -m "봉인 · 재봉인 · 합치기 중간 · 합친 HEAD 커밋은 HEAD 축 워크트리가 사라지면 도달 불가다. 회수는 git 자신의 gc 가 한다 — qg 가 git prune 을 부르면 사용자의 unreachable 객체까지 지운다(설계 §6.2.4 P23 재결정)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 10: 문서 — README · `qg.md` · e2e 시나리오 · 설계 §16 P23

**Files:**
- Modify: `plugins/quality-gates/README.md` · `plugins/quality-gates/commands/qg.md` · `plugins/quality-gates/tests/e2e-scenarios.md` · `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md`

**선결** — 설계 편집은 R-AN 동의가 있을 때만(Task 9 와 같다).

- [ ] **Step 1: README** — 넷.
  1. 「파이프라인」 표의 ① 행 셋째 칸 `session(기본) · \`branch\` · \`--paths\`` → `topic(선언이 있으면 기본) · session · \`branch\` · \`--paths\``. 둘째 칸에 `` · `topic-head.sh` `` 를 더한다.
  2. 「파이프라인 흐름」 그림의 `① scope (session | branch | --paths)` → `① scope (topic | session | branch | --paths)`(그림 폭이 맞게 공백을 줄인다).
  3. 「사용」 절 바로 **앞**에 새 절:

```markdown
## 토픽 스코프 — `Spec:` 트레일러

한 작업이 브랜치 여럿(스택 · 형제 · 이미 머지된 앞 브랜치)에 걸치면, 커밋에
`Spec: <리포-상대 경로>[#<조각>]` 트레일러를 단다. `/qg` 는 현재 브랜치가 base 위에 얹은
커밋에서 그 키를 찾고, 같은 키를 단 브랜치 전부(원격-추적 · 머지된 구성원 포함)를 한 판정
단위로 본다:

- **기준선** — 그 작업이 시작된 지점(구성원 분기점들의 merge-base).
- **HEAD 축** — 워킹트리 봉인과 구성원 끝점을 `git merge-tree` 로 순차 합친 트리. 리뷰 diff ·
  차등 테스트 · 판정이 이 한 트리를 본다.
- **판정 꼬리의 `scope:` 블록** — 본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID. `clean` 은 이
  튜플에 대한 clean 이다.

키는 조각까지 포함한 값 전체다 — `…#pr1` 과 `…#pr2` 는 다른 토픽이다. 선언이 없으면 동작이
바뀌지 않는다(session 기본). 선언이 깨졌으면(경로 부재 · 한 브랜치에 두 키) `not-certified
(declaration-invalid)`, 끝점 합치기가 충돌하면 `not-certified (merge-conflict)` 이고 충돌 파일을
싣는다 — 두 경우 모두 리뷰 · 차등 테스트는 현재 브랜치(session)로 계속 돈다. 선언이 있으면
trivia escape 를 쓰지 않는다. `branch` · `--paths` override 는 토픽을 보지 않는다.

**알려진 한계** — 다른 리모트의 기본 브랜치(예: `upstream/main`)가 토픽을 이미 머지했으면
구성원으로 잡혀 리뷰 대상이 부풀 수 있다(`scope:` 블록의 `branches:` 에 보인다).
```

  4. 「구조」 트리(알파벳 순이 아니다)의 `│   ├── resolve-baseline.sh …` 줄 **바로 아래**에 두 줄: `│   ├── scope_tuple.py                        # 스코프 튜플 파서 · status → 사유 · scope: 블록` 과 `│   ├── topic-head.sh                         # ① 토픽 해소 — 선언 → 봉인 → 경계 · 끝점 → 합친 트리 튜플`. 그리고 Kill switches 표의 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` 행 설명 끝에 ` \`run-test-selection.sh\` 도 집행한다(probe · run 이 저장소 코드를 돌리지 않는다).` 를 더한다.

- [ ] **Step 2: `qg.md`** — Quick Reference 의 `| \`/qg\` | Run the pipeline; git-derived diff (branch + worktree) |` → `| \`/qg\` | Run the pipeline; \`Spec:\` 트레일러로 선언된 토픽이면 토픽 전체(합친 트리), 아니면 git-derived diff (branch + worktree) |`. 「Scope (default: git 변경)」 절의 첫 문단 앞에 한 문단: `선언이 있으면 기본 scope 는 **토픽**이다 — README 「토픽 스코프」. 아래는 선언이 없을 때(session)다.`

- [ ] **Step 3: e2e 시나리오** — `tests/e2e-scenarios.md` 의 `## Out-of-Scope for This Verification` 헤딩 **바로 위**에 `### T-1 — 토픽 스코프: 형제 브랜치 둘 + 미커밋 변경` 절 하나(그 파일의 형식 `**Setup:**` · `**Run:**` · `**Expected:**` 을 따른다):
  - 준비: 일회용 리포에 형제 브랜치 둘(`Spec: docs/x.md#p1`), 현재 브랜치에 미커밋 파일.
  - 실행: `/qg`.
  - 기대: `Review scope: topic …` 한 줄 · 판정 꼬리의 `scope:` 블록에 `mode: topic` · 두 선언 커밋의 `commit:` 줄 · 형제 브랜치에 회귀를 심으면 `defect`. 형제가 같은 파일을 달리 고치면 `not-certified (merge-conflict)` 와 그 파일.

- [ ] **Step 4: 설계 §16 · §6.2.4 · §12** — (a) §16 의 마지막 재결정 항목(「재결정 (P23, 2026-09-26) — 「genuine no-op = clean」 …」 블록) **뒤**, `**각 PR 은 자기 \`Spec:\` 조각을 선언한다**` 문단 **앞**에:

```markdown
**재결정 (P23, 2026-09-26) — 중간 커밋 GC 를 `qg-gc.py` 가 아니라 git 의 prune 에 맡긴다.**
- **원래** — §6.2.4: 순차 합치기의 `commit-tree` 중간 커밋은 unreachable 로 남고 「기존
  `qg-gc.py` 경로에 편입한다」. §12: `qg-gc.py — unreachable 중간 커밋 정리`.
- **재결정** — `qg-gc.py` 는 바뀌지 않는다. qg 가 만드는 커밋(봉인 · 재봉인 · 합치기 중간 ·
  합친 HEAD 커밋)은 어떤 ref · reflog 도 얻지 않고, HEAD 축 워크트리가 사라지면 도달 불가다 —
  회수는 git 자신의 `gc`(→ `prune --expire`)가 한다. 락이 「한 실행 뒤 qg 저자 커밋 전부가
  도달 불가」를 잰다.
- **근거** — `qg-gc.py` 는 세션 폴더를 TTL 로 지우는 모듈이고 git 객체를 다루지 않는다.
  git 에는 선택적 회수 수단이 없다 — `git prune` 은 리포 전체의 unreachable 객체(사용자의
  dropped stash · 되살리려던 커밋)를 지운다. 커밋 객체만 골라 지우는 것은 부피 이득이 없고
  (트리 · blob 은 내용 주소라 사용자 객체와 공유될 수 있다) 살아 있는 워크트리를 깨뜨릴 수
  있다. 실측: 봉인 · 중간 커밋은 이미 ref · reflog 어디서도 닿지 않고 `prune` 이 회수한다.
  사람(사용자)이 이 재결정에 동의했다.
- **남는 것** — 회수 시점이 git 의 `gc.pruneExpire`(기본 2주)에 달린다. 그 사이 객체가 `.git`
  에 남는다.
```

  (b) §6.2.4 의 `- 순차 합치기는 \`commit-tree\` 중간 커밋을 만들고 그것은 unreachable 로 남는다(실측 §7-G) →` ⏎ `  기존 \`qg-gc.py\` 경로에 편입한다.` 두 줄의 끝에 ` *(재결정 P23 2026-09-26 — git 의 prune 에 맡긴다, §16)*` 를 붙인다. (c) §12 의 `- \`plugins/quality-gates/scripts/qg-gc.py\` — unreachable 중간 커밋 정리` 줄 끝에 ` *(재결정 — §16, 바뀌지 않는다)*` 를 붙인다. 목차는 절 이름이 안 바뀌므로 그대로다.

- [ ] **Step 5: 확인 · 커밋**

```bash
bash plugins/quality-gates/tests/test_readme_scope_reconcile.sh 2>&1 | tail -1
bash plugins/quality-gates/tests/test_readme_state_diagram_complete.sh 2>&1 | tail -1
bash plugins/quality-gates/tests/test_one_pipeline_surface.sh 2>&1 | tail -1
git add plugins/quality-gates/README.md plugins/quality-gates/commands/qg.md plugins/quality-gates/tests/e2e-scenarios.md docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md
git commit -m "docs(qg): 토픽 스코프 — README · qg.md · e2e · 설계 §16 P23(GC)" \
  -m "토픽 스코프(\`Spec:\` 트레일러)의 사용법 · 기준선 · HEAD 축 · scope: 블록 · 실패 경로를 문서에 싣고, 중간 커밋 GC 를 git prune 에 맡기는 재결정을 설계 §16 에 기록한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

  **기대** — 세 락 기준선 그대로. README 락이 RED 면 그 락이 무엇을 잰 것인지(표 행 · 그림 줄) 보고 문서 쪽을 맞춘다.

---

### Task 11: 변이 — 네 축 × 양성 대조 · N=5 락 이빨(X6 · X7 · X8)

**Files:**
- Modify: `plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh`(X6–X8 단언)
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr4c-mutations.md` → 미러

**Interfaces:**
- Consumes: 이 PR 의 모든 락

- [ ] **Step 1: X6 · X7 · X8 단언을 더한다** — `case_n5_and_retry_cover_differential_origin` 의 파이썬 heredoc 안, `print(f"N5_HAS_MAXITER:…")` 줄 **아래**에:

```python
# X6 — N=5 문단 안의 Fix-loop decision 언급은 전부 부정(「가 아니라」 · 「새지 않는다」)에 묶인다.
#      토큰(차등 · kept = 0 · Max-iter decision)을 남긴 채 목적지를 Fix-loop 로 되돌리는 변이를 잡는다.
fl_all = len(re.findall(r'Fix-loop decision', n5)) if n5 else 0
fl_neg = len(re.findall(r'Fix-loop decision[^.]{0,60}?(?:가 아니라|새지 않는다)', n5)) if n5 else 0
print(f"N5_FIXLOOP_ALL_NEGATED:{1 if (fl_all >= 1 and fl_all == fl_neg) else 0}")
# 목적지 양의 단언 — Max-iter decision 링크 뒤가 「을 부른다」. 괄호 · # 를 정규식에 쓰지 않는다
# (이 본문은 $( ) 안 heredoc 이다 — bash 3.2 가 짝 없는 괄호로 치환 경계를 잘못 잡는다).
n5_maxiter = bool(n5 and re.search(r'\[Max-iter decision\].{1,24} 을 부른다', n5))
print(f"N5_MAXITER_INVOKED:{1 if n5_maxiter else 0}")
# X7 — Step 4.5 라우팅의 머리가 N < 5 로 한정된다(같은 줄)
lead = re.search(r'^\s*그다음.N < 5 — N=5 는 [^\n]*「N=5 에서 도달하면」', text, re.M)
print(f"LEAD_N_LT_5:{1 if lead else 0}")
# X8 — Step 5 결정 도구의 머리가 N < 5 전용이고 N=5 는 Max-iter 로 간다(같은 줄)
dtool = re.search(r'^\s*5\. \*\*Decision tool .N < 5 only — N=5 always goes to Max-iter decision instead', text, re.M)
print(f"DECISION_TOOL_N_LT_5:{1 if dtool else 0}")
```

  **f-string 식 부분에 백슬래시를 두지 않는다** — Python 3.9–3.11 은 SyntaxError 다(시스템 `python3` 는 3.9+). 정규식 결과는 변수에 먼저 받는다.

  그리고 그 케이스의 `assert_grep "$got" '^N5_HAS_MAXITER:1$' …` 줄 **아래**에:

```bash
  assert_grep "$got" '^N5_FIXLOOP_ALL_NEGATED:1$' "N=5 문단의 Fix-loop decision 언급은 전부 부정에 묶인다(X6 — 토큰을 남긴 목적지 반전 → RED)"
  assert_grep "$got" '^N5_MAXITER_INVOKED:1$'     "N=5 문단이 Max-iter decision 을 «부른다»(목적지 양의 단언)"
  assert_grep "$got" '^LEAD_N_LT_5:1$'            "Step 4.5 라우팅 머리가 N < 5 로 한정된다(X7)"
  assert_grep "$got" '^DECISION_TOOL_N_LT_5:1$'   "Step 5 결정 도구가 N < 5 전용이다(X8)"
```

```bash
bash plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `Fail: 0`(오늘 문면이 넷을 만족한다). `✗` 면 SKILL 원문의 실제 문면(띄어쓰기 · 링크 모양)을 보고 **정규식을** 원문에 맞춘다 — SKILL 을 고치지 않는다.

- [ ] **Step 2: 커밋(변이 전에)** — 변이는 `git checkout HEAD -- <파일>` 로 되돌리므로 커밋이 먼저다.

```bash
git add plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh
git commit -m "test(qg): N=5 상한 락 이빨 — Fix-loop 부정 · Max-iter 목적지 · N < 5 머리" \
  -m "N=5 문단의 Fix-loop decision 언급이 전부 부정에 묶이고, Max-iter decision 을 부르며, Step 4.5 · Step 5 의 머리가 N < 5 로 한정됨을 같은 줄에서 잰다(PR4b 부채 X6 · X7 · X8)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

- [ ] **Step 3: 변이를 태운다** — 행마다: ① 변이를 적용하고 `git diff --stat` 이 **비어 있지 않음**을 확인한다(적용 확인이 먼저 — 빈 diff 의 RED/GREEN 은 증거가 아니다) ② 지목 락을 `PYTHONDONTWRITEBYTECODE=1` 로 돌려 기대한 단언이 `✗` 인지 본다 ③ `git checkout HEAD -- <파일>` 후 `git diff HEAD --stat` 이 빈 출력인지 본다. 변이 파일 편집은 `Edit` 도구로 한다. 결과를 표로 `$CLAUDE_JOB_DIR/tmp/pr4c-mutations.md` 에 쓰고 미러로 복사한다.

| # | 축 | 변이 | 지목 락 · 기대 `✗` |
|---|---|---|---|
| 1 | 삭제 | `resolve-topic.sh` 의 `--sort=refname ` 을 지운다 | `test_topic_boundary.sh` — `--sort=refname 을 싣는다` |
| 2 | 변형 | `--sort=refname` → `--sort=-refname` | 같은 락 — `역순이 아니다` · `로컬 이름이 이긴다`(`case_local_and_remote_same_commit_dedup`) |
| 3 | 변형 | `detect` 의 `"$BASE_REF..HEAD"` → `HEAD` | 같은 락 — `base 에 이미 든 앞 토픽의 트레일러는 세지 않는다` |
| 4 | 변형 | `detect` 의 `grep -E '^Spec: '` → `grep -iE '^Spec: '` | 같은 락 — `소문자 spec: 는 선언이 아니다` |
| 5 | 변형 | `topic-head.sh` 의 `HEAD_COMMIT="$last"` → `HEAD_COMMIT="$SEAL"` | `test_topic_head.sh` — `head_commit 의 트리 = tree` · `create-head --topic 수락` |
| 6 | 삭제 | `topic-head.sh` 의 `resolve "$KEY" --seal "$SEAL"` → `resolve "$KEY"` | 같은 락 — `미커밋 파일이 합친 트리에` · `단일 구성원: status: ok`(`끝점은 봉인 하나` 는 두 쪽이 다 비어 공허하게 GREEN 일 수 있다 — 지목 단언으로 쓰지 않는다) |
| 7 | 변형 | `topic-head.sh` 의 `merge-conflict)` 갈래의 `emit merge-conflict` → `emit ok` | 같은 락 — `merge-conflict(AC7)` |
| 8 | 삭제 | `qg-worktree.sh` 의 `--topic` 갈래 트리 대조 `[[ … == "$ch_tree" ]] \|\| die …` 두 줄을 지운다 | 같은 락 — `봉인 단독 → 거부` · `경계 → 거부` · `stale → 거부` |
| 9 | 불일치 | `scope_tuple.py` 의 `"unbounded": "declaration-invalid",` 줄을 지운다 | `test_scope_tuple.sh` — `unbounded → not-certified` |
| 10 | 삭제 | 합성기의 `+ ([scope_reason] if scope_reason else [])` 를 지운다 | 같은 락 — `합치기 충돌은 clean 이 아니다` |
| 11 | 추가 | 합성기 꼬리에서 `scope:` 렌더 두 줄을 `verdict` 렌더 **뒤**로 옮긴다 | 같은 락 — `꼬리 순서 = scope: → angles: → verdict:` |
| 12 | 삭제 | `run-test-selection.sh` 의 kill switch `if` 블록을 지운다 | `test_run_test_selection.sh` — `스위치 on:` 넷 |
| 13 | 추가 | SKILL Trivia 건너뛰기 줄에 `· \`no-declaration\`` 을 더한다 | `test_topic_scope_wiring.sh` — `no-declaration 이 없다` |
| 14 | 부정 | SKILL Step 4 `--scope` 행의 오른쪽 칸에서 `` `--scope ".claude/quality-gates/<session-id>/topic-scope.txt"` `` 리터럴은 **두고**, 그 뒤를 「는 싣지 않는다 — 공시만 한다」로 바꾼다(칸 전체를 바꾸면 리터럴이 사라져 개수 단언만 RED 가 되고 지목 단언은 공허하게 GREEN 이다 — 모의 실행 실측) | 같은 락 — `부정형이 아니다` |
| 15 | 불일치 | SKILL 상태 표의 `seal-failed` 행을 지운다 | 같은 락 — `STATUSES 여덟 전부` |
| 16 | 변형 | SKILL 상태 표 `ok` 행의 `**topic**` → `session` | 같은 락 — `ok 행만 **topic**` |
| 17 | 변형 | 레퍼런스 R4 ② 의 `"$baseline_commit"` 하나를 `"$merge_base"` 로 | 같은 락 — `셋 전부 "$baseline_commit"` · `$merge_base 가 남지 않았다` |
| 18 | 삭제 | 레퍼런스 R-init 의 `--topic "$topic_key"` 를 지운다 | 같은 락 — `create-head 가 --topic 으로` |
| 19 | 변형 | 레퍼런스 R1a 의 `"$scan_dir"` → `"$project_dir"` | 같은 락 — `R1a detect 가 $scan_dir` · `$project_dir 호출이 남지 않았다` |
| 20 | 추가 | 레퍼런스 아무 문단에 `(설계 §6.2.4)` 를 더한다 | `test_one_pipeline_surface.sh` — `§ 절 포인터가 0개` |
| 21 | 추가 | `seal-worktree.sh` 의 마지막 `printf '%s\n' "$B"` **앞**에 `git -C "$main_root" update-ref refs/qg/last "$B"` 한 줄 — 범위 불변식 파일이다. 반드시 복원하고 `git diff HEAD -- plugins/quality-gates/scripts/seal-worktree.sh` 빈 출력을 본다 | `test_qg_objects_unreachable.sh` — `session 경로도 … 도달 불가` · `어떤 ref 도` |
| 22 | 변형 | SKILL N=5 문단 — 원문은 `…(Step 5 [Fix-loop decision](#fix-loop-decision))가 아니라` ⏎ `[Max-iter decision](#max-iter-decision) 을 부른다.` 두 줄이다. `가 아니라` ⏎ `[Max-iter decision](#max-iter-decision) 을 부른다` → `를 그대로 부른다 —` ⏎ `kept = 0 차등 기원이 아니면 [Max-iter decision](#max-iter-decision) 을 쓴다` (줄바꿈을 옛 · 새 양쪽에 둔다) | `test_pipeline_verdict_wiring.sh` — X6 두 단언 |
| 23 | 삭제 | SKILL `그다음(N < 5 — ` → `그다음(` | 같은 락 — X7 |
| 24 | 삭제 | SKILL `(N < 5 only — ` → `(` | 같은 락 — X8 |

  **양성 대조** — 변이 전 · 모든 복원 뒤에 이 PR 의 새 락 다섯(`test_topic_head.sh` · `test_scope_tuple.sh` · `test_topic_scope_wiring.sh` · `test_qg_objects_unreachable.sh` · `test_topic_boundary.sh`)과 `test_pipeline_verdict_wiring.sh` · `test_run_test_selection.sh` · `test_one_pipeline_surface.sh` 가 `Fail: 0` 이다.

- [ ] **Step 4: 구멍을 닫는다** — 기대한 `✗` 가 안 난 행(생존 변이)마다 락에 단언을 더하거나 좁혀 RED 로 만든 뒤 **같은 변이를 다시 태워** 확인하고 커밋한다. 닫지 않기로 한 생존은 이유와 함께 표와 부채 원장에 남긴다. 수정 라운드는 이 Task 안에서 **둘까지** — 셋째 생존이 같은 자리에서 새로 나면 층위가 틀렸다는 신호로 보고 멈추고 원장에 적는다.

---

### Task 12: 회귀 · 범위 불변식 · bump · CHANGELOG · PR

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(`version` 만) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(제목 버전) · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`(제목 버전만)
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr4c-final.tsv` · `$CLAUDE_JOB_DIR/tmp/pr4c-body.md` → 미러

- [ ] **Step 1: 도출 집합 회귀 — 기준선과 행 단위로**

```bash
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4c-final.tsv"
join -t $'\t' -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 \
  <(sort "$CLAUDE_JOB_DIR/tmp/pr4c-baseline.tsv") <(sort "$CLAUDE_JOB_DIR/tmp/pr4c-final.tsv") \
  | awk -F'\t' '$2 != $4 || $3 != $5'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u > "$CLAUDE_JOB_DIR/tmp/pr4c-final-harness-fails.txt"
comm -13 "$CLAUDE_JOB_DIR/tmp/pr4c-baseline-harness-fails.txt" "$CLAUDE_JOB_DIR/tmp/pr4c-final-harness-fails.txt"
```

  **기대** — `join` 출력의 모든 행이 이 PR 이 **더한** 락 넷(`MISSING MISSING 0 0`: `test_topic_head.sh` · `test_scope_tuple.sh` · `test_topic_scope_wiring.sh` · `test_qg_objects_unreachable.sh`)뿐이다 — 기존 파일은 행이 안 바뀐다. **rc 나 실패 줄 수가 늘어난 행은 0.** 하네스 `comm -13` 빈 출력. unittest `Ran 197` 그대로.

- [ ] **Step 2: 범위 불변식**

```bash
git diff --stat origin/main...HEAD -- shared plugins/spec-distill plugins/plugin-audit .claude-plugin/marketplace.json CLAUDE.md \
  plugins/quality-gates/agents plugins/quality-gates/references/recritic-code-profile.md \
  plugins/quality-gates/scripts/seal-worktree.sh plugins/quality-gates/scripts/diff-test-results.py \
  plugins/quality-gates/scripts/check_qa_ledger.py plugins/quality-gates/scripts/verdict.py \
  plugins/quality-gates/scripts/angles.py plugins/quality-gates/scripts/recritic_bridge.py \
  plugins/quality-gates/scripts/qg-gc.py plugins/quality-gates/scripts/gc_common.py
git diff origin/main...HEAD -- plugins/quality-gates/.claude-plugin/plugin.json
git grep -n 'topic-head\.sh' -- plugins/quality-gates/skills plugins/quality-gates/scripts/qg-worktree.sh | head
```

  **기대** — 첫 명령 빈 출력. `plugin.json` 은 `version` 한 줄만(Step 3 뒤). 마지막 명령이 SKILL(1a · allowed-tools)과 `qg-worktree.sh`(`--topic` 갈래)를 보여 준다.

- [ ] **Step 3: 머지 직전 동기화 · 버전을 정한다**

```bash
git fetch origin --quiet
git rev-list --count HEAD..origin/main
git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json | grep '"version"'
```

  `origin/main` 이 움직였으면 **merge 한다**(rebase 금지): `git merge --no-edit origin/main`. 충돌이 없어도 `plugin.json` · `CHANGELOG.md` · SKILL 을 눈으로 본다(같은 버전 문자열은 충돌 없이 병합된다). 머지 뒤 Step 1 을 다시 돈다.

  버전 = `origin/main` 의 qg minor + 1 `.0`(오늘 관측값 9.0.0 → **9.1.0**). 세 자리를 같은 값으로: `plugin.json` 의 `"version"` · `skills/quality-pipeline/SKILL.md` · `skills/publishing-pr-understanding/SKILL.md` 제목의 `(vX.Y.Z)`.

- [ ] **Step 4: CHANGELOG** — `plugins/quality-gates/CHANGELOG.md` 맨 위(기존 형식을 본다)에 Korean-primary 로(`check-changelog-korean-primary.py` 가 잰다):

```markdown
## [<정한 버전>] — <오늘 날짜>

**토픽 스코프** — `Spec: <경로>[#<조각>]` 커밋 트레일러로 선언한 작업은 브랜치가 여럿이어도 한 판정 단위가 된다. 선언이 없으면 동작이 바뀌지 않는다.

### Added
- 토픽 스코프 — 현재 브랜치가 base 위에 얹은 커밋의 `Spec:` 트레일러가 토픽 키다. 같은 키를 단 브랜치 전부(원격-추적 · 이미 머지된 구성원 포함)를 모아, 기준선은 그 작업의 시작점(분기점들의 merge-base), HEAD 축은 워킹트리 봉인과 구성원 끝점을 `git merge-tree` 로 순차 합친 트리다. 리뷰 diff · 차등 테스트 · 판정이 그 한 트리를 본다.
- `scripts/topic-head.sh` — 선언 → 봉인 → 경계 · 끝점 → 합친 트리를 한 번에 풀어 튜플을 낸다. `scripts/resolve-topic.sh detect` — 현재 브랜치의 토픽 키.
- `scripts/scope_tuple.py` · 합성기 `--scope` — 판정 꼬리에 `scope:` 블록(본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 · 충돌 파일)을 싣는다.
- 판정 사유 `declaration-invalid`(선언 경로 부재 · 한 브랜치에 두 키 · 경계를 셀 수 없음) · `merge-conflict`(끝점 합치기 실패)가 실제로 나온다.
- `qg-worktree.sh create-head --topic <키>` — 인자 커밋의 트리를 지금 다시 도출한 합친 트리와 대조한다.
- 락: `tests/test_topic_head.sh` · `tests/test_scope_tuple.sh` · `tests/test_topic_scope_wiring.sh` · `tests/test_qg_objects_unreachable.sh`.

### Changed
- 선언이 있으면 trivia escape 를 쓰지 않는다 — 현재 브랜치의 diff 가 한 문장이어도 판정 대상은 토픽 전체다.
- 선언 경로의 차등 테스트는 어댑터 감지 · unit 배정을 합친 트리에서 한다(형제 구성원에만 있는 테스트 파일).
- `resolve-topic.sh` 의 ref 스캔 정렬을 `--sort=refname` 으로 못 박는다.
- 차등 테스트 레퍼런스에서 설치본에 없는 옛 설계 문서의 절 번호(§) 포인터를 걷어냈다(문장은 그대로).

### Security
- `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 을 `run-test-selection.sh` 도 집행한다 — `probe` · `run` 이 저장소 코드(`setup_cmd` · 테스트)를 돌리지 않는다(`usable: no` · `reason: kill_switch`). 보안 컨트롤이 오케스트레이터 산문에만 있던 자리다.
```

- [ ] **Step 5: 커밋 · 미러 · push · PR**

```bash
python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py 2>&1 | tail -2
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -E 'major' | head -3
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md
git status --short
git commit -m "chore(qg): quality-gates <정한 버전> — 토픽 스코프" \
  -m "커밋 트레일러(\`Spec:\`)로 선언한 작업을 한 판정 단위로 본다. 선언이 없으면 동작이 바뀌지 않는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4c
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4c-final.tsv"
cp "$CLAUDE_JOB_DIR"/tmp/pr4c-final* ~/.claude/sdd-mirror/qg-topic-scope-pr4c/
git push -u origin feature/qg-topic-scope-pr4c
```

  PR 본문(`$CLAUDE_JOB_DIR/tmp/pr4c-body.md`, 미러에도)의 절:
  1. **요약** — 한 문단 + 버전.
  2. **사용자가 뒤집을 수 있는 자리** — R-AI … R-AR 한 줄씩(무엇 · 틀리면). **R-AN(P23 GC)** 과 **R-AL(핀 5 유지)** 을 맨 위에.
  3. **이 PR 이 지는 것** — 계획의 표.
  4. **후보 판정** — 계획의 표.
  5. **끝에서 끝 흐름** — 계획의 표.
  6. **선재 RED — 착수와 종료** — `join` 결과 표.
  7. **변이 표** — Task 11.
  8. **부채 원장** — 아래 표 그대로 + 실행 중 더해진 행.
  9. **검증 과정** — SDD 모델 · 수정 라운드 수 · 리뷰가 실측으로 찾은 결함 · 실행 중 컨트롤러가 정한 것(SDD 원장의 `Ruling:` 전부).
  10. 마지막 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

  PR 생성 명령은 명령 문자열에 호스트 이름이 들어가지 않게 쓴다 — 가드가 거부하면 `$CLAUDE_JOB_DIR/tmp/pr-create.sh` 로 옮겨 돌린다:

```bash
gh pr create --base main --head feature/qg-topic-scope-pr4c \
  --title "feat(qg): 토픽 스코프 배선 — Spec: 선언 → 합친 HEAD 트리 · scope: 튜플 (PR4c)" \
  --body-file "$CLAUDE_JOB_DIR/tmp/pr4c-body.md"
```

  **머지는 사용자가 한다** — `! gh pr merge <n> --merge`. `gh api` 로 우회하지 않는다. 머지 뒤 `gh pr view <n> --json state` 가 `MERGED` 인지 직접 확인한다.

---

## 부채 원장 — 미룬 것은 전부 여기 이름이 있다

| 부채 | 소유자 | 무엇이 붙잡고 있는가 |
|---|---|---|
| 다른 리모트의 기본 브랜치(`upstream/main` 등)가 토픽을 머지했으면 구성원이 되어 `T` 가 부푼다 | 후속 | R-AQ · README 「알려진 한계」 · `scope:` 블록의 `branches:` 공시 |
| `topic-scope.txt` 의 custody — Step 4 소비가 저장소 코드 실행 뒤라 `status:` · 튜플 변조가 사유 · 블록을 바꿀 수 있다 | **해소하지 않는다**(열린 잔여와 한 축 — 여섯 전부에 걸거나 하나도 안 건다) | 레퍼런스 창 표 |
| §6.2.7 「경계 앞 커밋 수」 공시 — 배선하지 않았다. 브랜치-소속 표식 재결정(D1.6 · D1.9) 뒤로 그 수가 0 이 아닌 경로가 좁아졌다(측정 안 함) | 후속 | 이 표 |
| `test-scope-validator` 는 선언 경로에서도 `$project_dir` 를 읽는다 — 형제에만 있는 테스트 파일은 `unclear` 로 분류될 수 있다(advisory) | 후속 | R-AP |
| session 경로의 봉인은 R4(기준선 테스트) **뒤**다 — 기준선 테스트가 메인 워킹트리에 쓴 부수효과가 봉인에 들어간다(선재) | 후속 | 이 표 |
| 결정론 차등 요약 렌더러 | 후속 | 후보 판정 |
| M5 — 쓰기 가능 추가 리뷰어가 봉인 뒤에 돈다 | 후속 | 후보 판정 |
| `agents/security-reviewer.md` 의 「Review gate」 문구 | **PR5** | 후보 판정 · AC20 과 한 묶음 |
| N=5 상한 락의 나머지 잔여 — X1 · X2(I1 경로 목적지 교체) · X9(Retry 안내 헤더-satisfiable) | 후속 | PR4b 원장 · 이 표 |
| `CLAUDE.md` Law 2 scoped exception · `plugin.json`/`marketplace.json` 의 「2-gate」 · 철학 문서의 같은 산문 | **PR5** | 설계 §16 의 5 행 · AC19 · AC20 |
| §13 수동 e2e — 실제 `Spec:` 브랜치 둘로 `/qg` | **PR5** | 설계 §13 · `tests/e2e-scenarios.md`(Task 10 시나리오) |
| `create-sandbox` · `mutation-guard` 의 소유를 plugin-audit 로 옮기기 | 후속 | PR4b R-W |
| `--show-low-confidence` · 동률 raise 의 `gate=False` 공시 락 · RV 중간 파일 `mktemp -d` · raw `agent: [목록]` TypeError · `render_disposition` 의 `(차단: 예)` | 후속 | PR4b 원장(이월 그대로) |
| 원장 파일 이름 `runtime-evidence.md` · 각도 파일은 모델이 쓴다 · `check_wiring.py` 줄번호 키 | **해소하지 않는다** | PR4b 원장 |

---

## Self-Review

**1. 스펙 커버리지** — §16 의 4c 행을 하나씩 대조했다:
- `resolve-topic.sh` → 경계 · 끝점: Task 2(`topic-head.sh` 가 부른다) · Task 8(R-init 이 쓴다). `combine-tips.sh` → 합친 HEAD 트리: Task 2 · 3 · 8.
- AC3(Task 2 형제 · 원격 · Task 7/8 배선) · AC4(Task 2 머지된 구성원) · AC5(Task 2 경계 · Task 8 `$baseline_commit`) · AC6(Task 2 봉인 먼저 · Task 3 재도출) · AC7(Task 2 `conflicts:` · Task 4 사유 · 렌더) · AC15(Task 2 `commit:` · Task 4 `scope:` · Task 7 Final Summary) · AC16(Task 1 detect · Task 2 · Task 4 · Task 7 상태 표).
- `declaration-invalid` · `merge-conflict` 발화 → Task 4(R-AL). PR1 이월 둘 → Task 1. 중간 커밋 GC → Task 9(R-AN, 동의 필요).
- 설계 §7 E · I 재검증 — E 는 실측 P1, I 는 PR4b 가 했다.

**2. 플레이스홀더 스캔** — `<정한 버전>` · `<오늘 날짜>` · `<이 커밋을 쓴 실제 모델>` 은 실행 시점 값이고 정하는 규칙이 적혀 있다. `<session-id>` · `<위 6키의 merge_base>` · `<topic_key>` 는 SKILL · 레퍼런스가 이미 쓰는 오케스트레이터 치환 자리다. 재앵커 줄번호(391)는 기대값이고 실측값을 쓴다고 적었다.

**3. 이름 일관성** — `topic-head.sh <sid> [--topic <key>]` · 12키 순서 · `STATUSES` 여덟 · `STATUS_TO_REASON` 넷 · `create-head <sha> <sid> [--topic <key>]` · 스코프 파일 리터럴 `.claude/quality-gates/<session-id>/topic-scope.txt` · 변수 `$baseline_commit` `$topic_key` `$sealed` `$head_tree_dir` `$scan_dir` · 블록 `scope:` 의 `mode`/`detail` — Task 2 · 3 · 4 · 7 · 8 · 9 에서 같은 철자다.

**4. Review Focus** — 다섯 줄의 테스트가 소유 Task 에 있다: 1 → Task 2 · 2 → Task 7 · 3 → Task 2 · 4 → Task 3 · 5 → Task 2.

---

## Execution Handoff

계획은 `docs/superpowers/plans/2026-09-26-qg-topic-scope-pr4c.md` 에 있다. SDD 로 돌리면 구현 sonnet · Task 리뷰 opus · 최종 리뷰 opus 이고(이 리포에서는 사용자가 풀기 전까지 fable 을 쓰지 않는다), 원장은 매 갱신마다 `~/.claude/sdd-mirror/qg-topic-scope-pr4c/` 로 복사한다. Task 리뷰에는 **plan-mandated** 라벨을 싣는다 — 계획이 쓴 테스트 코드에서 Important 가 가장 많이 나왔다(PR4b). 최종 리뷰는 「끝에서 끝 흐름」 표를 한 행씩 따라가게 한다. Task 9 · 10 은 R-AN 동의가 선결이다.
