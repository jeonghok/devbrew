# R12 계획 2 — qg 판정 상태 · 리뷰 diff · codex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** qg 의 최종 판정이 레포 코드(차등 테스트 · e2e)가 돈 뒤 세션 폴더를 다시 읽지 않고 숫자를 만든 직후 기계가 낸 판정 인자 줄로만 정해지고, 판정 id 가 같은 줄의 다른 지적을 가르며, 리뷰 diff 가 경로를 조용히 빠뜨리지 않고, 중첩 레포 · codex 프로젝트 문서의 위험을 닫거나 공시한다.

**Architecture:** 판정 인자는 「숫자를 만든 직후의 펜스가 내는 `qg-verdict-args:` 한 줄」로 턴에 든다 — 리뷰 축은 차등 테스트 **앞**에 도는 합성기(`synthesize_findings.py --verdict-args`), 차등 축은 D5 직후 `verdict.py --emit-args`, 제외 수 · 범위 끝 커밋 · e2e 칸은 그것을 쓴 펜스가 낸다. 최종 판정 펜스는 그 줄들을 bash 배열 자리에 글자 그대로 붙여 `verdict.py` 의 이미 있는 플래그로만 넘긴다. 반복 중간 단계(Step 4 · 4.5 · Fix-loop)는 그대로다(U4). 리뷰 diff 는 남길 경로를 `:(literal)` 로 명시하고 이름 목록을 대조한다.

**Tech Stack:** Python 3.9 표준 라이브러리, bash 3.2 호환 셸(`review-diff.sh` 는 bash), git, codex-cli 0.160.0(실측만), Markdown skill · reference.

**Spec:** `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` (§7 · §10 · AC17~AC24 · AC34)

**구현 브랜치:** `feature/qg-verdict-state` — 시작할 때 기본 브랜치(`origin/<기본>`)에서 새로 만든다(Task 0). 이 계획 파일과 설계문서는 `feature/review-engine-leftovers` 에 있다 — Task 0 이 두 파일을 그 브랜치에서 가져와 첫 커밋으로 싣는다(qg 의 의도 출처가 `Spec:` 트레일러의 경로를 이 브랜치에서 찾는다). 계획 1 · 3 과 병렬로 간다.

## Global Constraints

- 기본 브랜치 이름은 `git symbolic-ref --short refs/remotes/origin/HEAD` 로 도출한다(없으면 `git remote set-head origin --auto`). 기본 브랜치를 merge 한다(rebase 금지). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec, `git stash` 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` 트레일러, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 이 계획은 **quality-gates · spec-distill · plugin-audit** 를 올린다 — spec-distill 은 공유 문서 리뷰 codex 러너(`shared/docreview/scripts/run_docreview_codex_reviewer.sh`)가 링크로 실려서, plugin-audit 은 `run_audit_codex_reviewer.sh` 때문에. 판 번호는 머지 직전 지휘자가 정한다 — 구현 중에는 기본 브랜치 판의 다음 minor(quality-gates 14.2.0 · spec-distill 8.1.0 · plugin-audit 1.3.0 꼴). CHANGELOG 머리는 plugin.json 과 같게.
- **경로 겹침.** `tools/adjudication/check_wiring.py` 의 `EXEMPT` 에 `synthesize_findings.py` 자리 하나가 줄 번호로 박혀 있다 — 계획 3 이 먼저 머지됐으면 줄 번호가 없어 손대지 않고, 아니면 합성기 줄이 밀린 만큼 실측으로 다시 박는다. 설계문서 `## 미룸` 표는 계획 1 · 3 도 고칠 수 있다 — 뒤에 머지하는 쪽이 두 쪽 행을 모두 남긴다. R8 이 `review-diff.sh` · `check-review-scope.sh` 를 예약했다 — 이 계획이 먼저 고친다.
- **보안 재현은 격리해서.** 중첩 레포 · 링크 · codex 실측은 `mktemp -d` 아래 버릴 레포에서만 한다. 실제 레포에서 재현하지 않고 `git add -A` 를 쓰지 않는다. git 조작 뒤마다 이 worktree 의 `git status --short` 가 깨끗한지 본다.
- **실제 codex 호출은 사전 승인됐다** — `AskUserQuestion` 게이트를 두지 않는다. 태운 호출 수를 마지막 보고에 적는다.
- **셸.** macOS bash 3.2. `$var` 바로 뒤 한글이면 `${var}`. `$( )` 안 heredoc 금지. 새 · 바뀐 셸 테스트는 `chmod +x` 후 `100755` 확인(실행 비트 없는 `tests/*.sh` 는 qg 가 줍지 않는다). `mktemp` 결과가 비었으면 `cd` 하지 않는다(빈 `cd ""` 는 레포에서 돈다).
- **파이썬.** `encoding="utf-8"` · `"python3"` 리터럴 금지(플러그인 `.py`) · 인라인은 `python3 -I` · 비신뢰 입력 신원은 `fullmatch`.
- **변이.** 변이 전에 커밋 · `git clone --no-local` 사본 · `PYTHONDONTWRITEBYTECODE=1` · 매 변이 뒤 `git checkout HEAD -- <파일>` + `git diff HEAD --quiet`. 양성 대조 먼저. 음의 락엔 양의 짝.
- 레포 전용 값을 박지 않는다. 사람에게 보이는 새 문면은 `shared/style/plain-language.md`. 모델이 읽는 새 문면에 출처 · 정당화를 쓰지 않는다.
- **전체 스위트**는 지휘자가 준 공유 스위트 잠금 아래서만: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c '<스위트 명령>'`. 못 잡으면 보고한다. 과제 경계마다 바꾼 파일을 코퍼스로 읽는 락까지 넓게 돈다.
- 리뷰어 요청에 계획이 쓴 테스트 코드는 「plan-mandated」 라벨을 매번 단다.

## 설계와 다른 점 · 설계에 없던 결정

1. **판정 인자 줄의 생산자 · 모양(§7 의 `### Deferred to plan` 표).**

   | 축 | 숫자를 만든 펜스 | 기계가 낸 줄 | `verdict.py` 플래그 |
   |---|---|---|---|
   | 리뷰 | 새 Step 3.9 「리뷰 축 합성」(차등 테스트 전) · Step 4 · 되올려 다시 합성하기 | `qg-verdict-args: --blocking N --optional M [--defect] [--review-blocked] [--angle-absent] [--reason r]…` (합성기 stdout 마지막 줄) | 이미 있음 |
   | 차등 | D5 펜스 끝 · D0 kill switch · D7 의 실패 갈래 | `qg-verdict-args: --new-failures K [--defect] [--reason r]…` (`verdict.py --emit-args`) | 이미 있음 |
   | 제외 | Fix-loop 「제외」 기록 뒤 새 한 줄 펜스 | `qg-verdict-args: --excluded X` | 이미 있음 |
   | 범위 | Preflight 의 범위 얼림 펜스(범위 모드만) | `qg-verdict-args: --sha <끝 커밋 짧은 꼴>` | 이미 있음 |
   | e2e | E5 기록 펜스 | `qg-verdict-args: --e2e <칸>[ --e2e-overridden]`(`printf %q`) | 이미 있음 |

   리뷰 축 줄은 차등 입력에서 온 사유 · 결함을 싣지 않는다(합성기가 `--differential` 을 받아도 그 줄은 리뷰 축만) — 차등 축은 차등 줄이 맡고, 같은 사유가 두 줄에 있으면 `verdict.decide` 가 하나로 센다. 새 플래그는 둘뿐이다: 합성기 `--verdict-args`(`--emit-verdict` 와 함께만) · `verdict.py --emit-args`(판정 줄 대신 차등 축 인자 줄만 낸다). 둘 다 축 플래그가 아니라 줄을 내는 출력 방식이다.
2. **`--line` 과 `--iter <N>` 은 판정 펜스의 글자로 둔다.** 설계는 「`--line` · `--iter` · `--e2e-overridden` 도 기계가 낸 줄에 포함된다」고 했다. `--e2e-overridden` 은 e2e 줄에 든다. `--line` 은 값 없는 출력 방식이고 `--iter` 는 오케스트레이터가 세는 반복 번호라 세션 폴더의 값이 아니다 — 레포 코드가 바꿀 수 없어 기계 줄로 옮길 까닭이 없다. 범위 모드가 아니면 `--sha` 는 판정 펜스가 `git rev-parse --short HEAD` 로 직접 구한다(세션 폴더를 읽지 않는다).
3. **판정 펜스는 줄을 bash 배열 자리에 붙인다** — `R_ARGS=( <리뷰 줄의 `qg-verdict-args:` 뒤 글자 그대로> )` 꼴 다섯. 값에 공백이 든 e2e 칸(`안 함` 등)은 e2e 줄이 `printf %q` 로 낸다. `eval` 을 쓰지 않는다.
4. **Step 3.9 의 출력 파일은 `$RV/synth-review.out`** — Step 4 의 `synth.out` 과 따로 둔다(Step 4 · 4.5 는 그대로 `synth.out` 을 쓴다).
5. **`verdict.py --prior` 는 남긴다** — SKILL 은 더 부르지 않지만 지우는 것은 이 에픽 범위 밖이다(옛 호출자 · 테스트가 있다). 판정 펜스 문면 락이 `--prior` 를 금한다.
6. **중첩 레포 목록의 후보 길(§7 실측 대상):** 빈 임시 git 폴더를 `GIT_DIR` 로, 중첩 레포 폴더를 `GIT_WORK_TREE` 로 두고 `git -c core.fsmonitor= -c core.hooksPath=/dev/null ls-files --others --exclude-standard -z` — 중첩 레포의 `.git/config` · 훅을 읽지 않고 그 안의 `.gitignore` 를 지킨다. 링크는 따라가지 않고(`[ -L ]` 면 내용 대신 링크 줄만), 그 안의 중첩 레포는 지금처럼 리뷰하지 않고 알린다. 실측이 실패하면 지금 동작 + 이유.
7. **codex 설정 키(§7 실측 대상):** codex-cli 0.160.0 바이너리에 `project_doc_max_bytes` 설정 키가 있다(계획을 쓰며 `strings` 로 확인). 후보 `-c 'project_doc_max_bytes=0'`. 실측(표지 문장을 심은 AGENTS.md)이 통과하면 러너 넷에 넣고, 아니면 공시한다.
8. **AC23 락은 `shared/tests/test_codex_project_doc_off.sh` 새 파일** — 러너가 세 플러그인 · 공유 폴더에 흩어져 있어 한 플러그인 테스트에 두면 다른 플러그인의 변경을 못 본다.
9. **판정 id 해시:** `finding_id = f"{agent}-{file}-{line}-{sha1(claim_key)[:8]}"`, `claim_key(f) = " ".join(str(f.get("summary","")).split()).casefold()`.

## Review Focus

1. **차등 테스트가 세션 폴더의 `synth.out` · `differential.yaml` 을 지우거나 고친 뒤 최종 판정을 낸다.** 판정 줄은 턴에 든 줄과 같아야 한다. Task 3 의 `case_final_verdict_ignores_tampered_session` 이 잠근다.
2. **사용자가 「낮춘 지적」 게이트에서 되올리기를 고른다(차등 테스트 뒤).** 최종 판정은 되올린 뒤의 막는 지적 수를 써야 한다 — 되올려 다시 합성하기 펜스도 리뷰 줄을 다시 내고 그 줄이 쓰인다. Task 3 Step 3 의 문면 단언과 Task 2 의 `test_verdict_args_after_restore` 가 잠근다.
3. **바뀐 경로가 하나도 남지 않게 모두 제외된다(문서만 바뀐 diff).** 남길 경로가 0 이면 `git diff` 를 경로 없이 불러 전체 diff 를 내지 않아야 한다. Task 4 의 `case_all_excluded_no_pathspec` 이 잠근다.
4. **같은 리뷰어가 같은 줄에 요약이 공백 · 대소문자만 다른 두 지적을 낸다.** 같은 id 로 묶여야 한다(다른 지적이 아니다). Task 1 의 `case_same_claim_whitespace_same_id` 가 잠근다.
5. **중단된 이전 qg 실행이 남긴 worktree 가 `.claude/` 를 무시하지 않는 레포에 있다.** 판정은 막히되 이유 줄이 「qg-gc 로 지운 뒤 다시 돌려라」 를 말해야 한다. Task 4 의 `case_other_session_worktree_degraded` 가 잠근다.

---

### Task 0: 시작 · 설계문서 싣기 · 기준선 · 실측

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r12-plan2/{baseline.sh,cites.txt,codex-probe.md,nested-probe.md}` (레포 밖)
- Create(이 브랜치): `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` · `docs/superpowers/plans/2026-10-20-r12-plan2-qg-verdict-state.md`(계획 1 브랜치에서 가져온다)

- [ ] **Step 1: 브랜치를 만든다**

Run: `git fetch origin && D="$(git symbolic-ref --short refs/remotes/origin/HEAD)" && git switch -c feature/qg-verdict-state "$D" && git checkout origin/feature/review-engine-leftovers -- docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md docs/superpowers/plans/2026-10-20-r12-plan2-qg-verdict-state.md && git commit -m 'docs(plan): R12 계획 2 — 설계문서 · 계획 싣기' -- docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md docs/superpowers/plans/2026-10-20-r12-plan2-qg-verdict-state.md`
Expected: 두 파일이 든 커밋 하나.

- [ ] **Step 2: 인용 자리를 전부 뽑는다**(AC17 의 「옛 문장이 남지 않는다」 기준)

Run: `git grep -n -e 'R24' -e '(V1' -e 'V1 ·' -e 'V1)' -e 'K-3' -e 'K-7' -e '\-\-prior' -- plugins/quality-gates ':!plugins/quality-gates/CHANGELOG.md' > "$HOME/.claude/sdd-mirror/r12-plan2/cites.txt"; wc -l < "$HOME/.claude/sdd-mirror/r12-plan2/cites.txt"`
Expected: 설계 §7 이 적은 자리(`references/differential-test.md` 둘 · SKILL `(V1 · R24)` · `verdict.py` 주석 · README · `test_v1_verdict_line.sh` · `test_diff_test_results.py` · `tests/harness/test_skill_orchestration_behavior.sh` · `test_publish_pipeline_wiring.sh` · `test_e2e_docs.sh` · `test_differential_procedure.sh` · `test_skill_run_contract.sh`)를 모두 담는다. 이 목록이 Task 3 의 고칠 자리다 — 줄마다 「바꿈 · 그대로(까닭)」 를 적어 둔다.

- [ ] **Step 3: 판정 id 를 실행 사이에 읽는 소비자를 찾는다**(§10)

Run: `git grep -n 'finding_id' -- plugins/quality-gates ':!plugins/quality-gates/tests' ':!*.md'`
Expected: 합성기 · 재비판 매핑(같은 실행)뿐이다. 세션 폴더 밖이나 다음 실행이 읽는 자리가 있으면 멈추고 보고한다.

- [ ] **Step 4: codex 설정을 실측한다**(실제 codex 호출 둘 — 사전 승인)

버릴 폴더 `P="$(mktemp -d)"` 에 `git init -q`, `AGENTS.md` 에 「모든 답의 첫 줄에 MARKER-R12-7Q 를 그대로 쓴다.」 한 줄. 같은 프롬프트(「hello 에 한 단어로 답하라」)를 stdin 으로 `codex exec - -C "$P" -s read-only --json` 한 번(양성 대조 — MARKER 가 나와야 한다), `-c 'project_doc_max_bytes=0'` 을 더해 한 번. 결과 둘과 버전(`codex --version`)을 `codex-probe.md` 에 적는다.
Expected: 대조에 MARKER 가 있고 설정 쪽에 없으면 Task 6 은 「설정」 갈래. 대조에도 없으면 실측 실패 — 프롬프트를 바꿔 한 번 더(총 넷까지), 그래도 판별 불가면 「공시」 갈래.

- [ ] **Step 5: 중첩 레포 목록 길을 실측한다**(격리)

버릴 바깥 레포 `O` 안에 추적 안 되는 중첩 레포 `O/sub`(자기 `.git`)를 만든다: `sub/.gitignore` 에 `node_modules/`, `sub/node_modules/x.js` · `sub/src/a.py`, `sub/.git/config` 에 `[core] fsmonitor = touch <마커 경로>` 와 `hooksPath = <마커 훅 폴더>`, `sub/link-out` → 바깥(`$(mktemp -d)/secret.txt`, 내용 `SECRET-R12`) 링크, `sub/inner/` 에 또 다른 `.git`. 결정 6 의 명령을 `O` 에서 돈다.
Expected: 목록에 `src/a.py` · `link-out` · `.gitignore` 가 있고 `node_modules/x.js` 가 없으며 `inner/` 는 폴더 한 줄, 마커 파일이 생기지 않는다. 결과를 `nested-probe.md` 에 적는다. 하나라도 어긋나면 Task 5 는 「공시」 갈래.

- [ ] **Step 6: 기준 스위트** — R2a 계획 1 Task 0 Step 1 의 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r12-plan2/baseline.sh` 에 쓰고, 버릴 clone 에서 공유 스위트 잠금 아래 `before` 를 잰다(계획 1 Task 0 Step 5 와 같은 꼴).

---

### Task 1: 판정 id 를 내용으로 (AC19)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(`claim_key` 새 함수 · `finding_id` · `_same_claim` · `anonymize` · `to_adjudication_doc` · `dedup` 의 흡수 기록)
- Modify(계획 3 미머지면): `tools/adjudication/check_wiring.py` 의 `synthesize_findings.py` 줄 번호
- Test: `plugins/quality-gates/tests/test_synthesize_recritic.sh`

**Interfaces:**
- Produces: `claim_key(f: dict) -> str` · `finding_id(f: dict) -> str`(결정 9). `_same_claim(a, b)` 는 `claim_key(a) == claim_key(b)`.

- [ ] **Step 1: 충돌 케이스 넷을 다시 쓴다** — `test_synthesize_recritic.sh` 에서 「같은 agent-file-line 이 겹친다」 를 전제로 한 케이스 넷(Task 0 에서 `grep -n 'finding_id' tests/test_synthesize_recritic.sh` 로 찾는다)을 아래로 바꾼다. 더해:
  - `case_same_line_different_claim_distinct_ids` — 같은 리뷰어 · 파일 · 줄, 요약이 다른 두 지적 → `recritic-map.json` 의 `finding_id` 둘이 다르다 · 재비판이 하나를 reject · 하나를 confirm 하면 합성 출력에 hold 가 없고(`held: 0`) 남은 지적이 하나다.
  - `case_same_claim_whitespace_same_id` — 요약이 공백 · 대소문자만 다른 두 지적 → 같은 id(dedup 이 하나로 합친다).

- [ ] **Step 2: 돌려 실패를 본다** — `bash plugins/quality-gates/tests/test_synthesize_recritic.sh 2>&1 | grep '✗'` 에 새 케이스가 RED(지금은 `항목 파손: 같은 finding_id 에 갈린 재비판 판정` hold).

- [ ] **Step 3: 구현한다** — `claim_key` 를 두고 `finding_id` · `_same_claim` 이 그것을 쓴다. `anonymize` · `to_adjudication_doc` · `dedup` 은 `finding_id()` 를 그대로 부르므로 바뀐 id 를 따라간다 — 다른 곳에서 `agent-file-line` 을 손으로 조립하는 자리가 없는지 `grep -n "f\"{.*agent" plugins/quality-gates/scripts/*.py` 로 본다.

- [ ] **Step 4: 돌려 통과를 보고 합성기 스위트를 돈다**

Run: `for t in plugins/quality-gates/tests/test_synthesize_*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done; for t in plugins/quality-gates/tests/test_synthesize_*.py; do python3 "$t" >/dev/null 2>&1 || echo "FAIL $t"; done; bash shared/tests/test_adjudication_wiring.sh`
Expected: 출력 없음 · 배선 PASS(줄이 밀렸으면 Global Constraints 의 경로 겹침 대로 맞춘다).

- [ ] **Step 5: 커밋** — `fix(quality-gates): 판정 id 에 요약 지문을 더한다 — 같은 줄의 다른 지적이 겹치지 않는다`

---

### Task 2: 판정 인자 줄의 생산자 (AC17 의 기계 쪽)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(`--verdict-args`) · `plugins/quality-gates/scripts/verdict.py`(`--emit-args` · `render_args` 새 함수)
- Test: `plugins/quality-gates/tests/test_v1_verdict_line.sh` · `plugins/quality-gates/tests/test_synthesize_findings.sh`

**Interfaces:**
- Produces: `verdict.render_args(*, blocking=None, optional=None, defect=False, review_blocked=False, angle_absent=False, reasons=(), new_failures=None) -> str` — `qg-verdict-args: ` 뒤에 주어진 것만 `--blocking N` · `--optional M` · `--new-failures K` · `--defect` · `--review-blocked` · `--angle-absent` · `--reason r`(REASONS 순서, 중복 없이) 차례로, 끝에 `\n`. 사유는 `REASONS` 밖이면 `fail4`.
- `synthesize_findings.py --emit-verdict --verdict-args …` — 본 출력 마지막 줄로 리뷰 축 줄: `blocking=n_block` · `optional=SUGGESTION 수` · `defect=n_block>=1` · `review_blocked` · `angle_absent`(합성기가 이미 계산한 값) · `reasons = args.reason + [scope_reason]`. `--differential` 에서 온 사유 · 결함은 넣지 않는다. `--verdict-args` 는 `--emit-verdict` 없이 주면 사용법 오류(rc 2).
- `verdict.py --emit-args [--differential F] [--reason r]…` — `--line` · `--prior` · `--e2e` 와 함께 쓰면 rc 2. `--differential` 이 있으면 `new_failures:` 를 정확히 한 번 읽어(지금 판정 펜스의 검사와 같은 규칙 — 정수 아님 · 두 번이면 exit 4) `causes_of` · `defect_flag_of` 로 `--new-failures K [--defect] [--reason …]`, 없으면 `--new-failures 0 --reason <주어진 것>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - `test_v1_verdict_line.sh`: `verdict.py --emit-args --differential <회귀 있는 픽스처>` 출력이 `qg-verdict-args: --new-failures 1 --defect` 한 줄 · degrade cause 가 있는 픽스처는 해당 `--reason` · `--emit-args --reason kill-switch` 는 `qg-verdict-args: --new-failures 0 --reason kill-switch` · `--emit-args --line …` rc 2 · `new_failures:` 가 두 번인 픽스처 exit 4. 왕복: 낸 줄의 인자를 `verdict.py --line … --iter 1 --sha abc1234 --e2e '안 함'` 에 그대로 넘긴 판정 줄이 같은 입력의 지금 경로(`--differential` 직접)와 같은 판정값.
  - `test_synthesize_findings.sh`: `--emit-verdict --verdict-args` 의 마지막 줄이 `qg-verdict-args: --blocking 1 --optional 0 --defect` 꼴(막는 지적 하나 픽스처) · `--differential <회귀 픽스처>` 를 함께 줘도 그 줄에 `--new-failures` · 차등 사유가 없다 · `--verdict-args` 없이 낸 출력은 지금과 바이트로 같다 · `--verdict-args` 만 주면 rc 2. `test_verdict_args_after_restore`: `--restore-lowered L1` 로 다시 합성하면 그 줄의 `--blocking` 이 되올린 수를 반영한다.

- [ ] **Step 2: 돌려 실패를 본다** — 새 단언 RED(플래그 없음).

- [ ] **Step 3: 구현한다** — 위 Interfaces 대로. `verdict.py` 모듈 docstring 에 출력 방식 하나를 더한 사실 한 줄.

- [ ] **Step 4: 돌려 통과를 본다** — `bash plugins/quality-gates/tests/test_v1_verdict_line.sh && bash plugins/quality-gates/tests/test_synthesize_findings.sh && python3 plugins/quality-gates/tests/test_synthesize_lowered.py && bash plugins/quality-gates/tests/test_plain_synth_output.sh`.

- [ ] **Step 5: 커밋** — `feat(quality-gates): 판정 인자 줄을 기계가 낸다 — 합성기 --verdict-args · verdict.py --emit-args`

---

### Task 3: 판정 펜스는 다시 읽지 않는다 · R24 를 새 뜻으로 (AC17 · AC18)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(Flow 그림 · 새 Step 3.9 · Step 4 펜스 · 되올려 다시 합성하기 · Fix-loop 제외 기록 · Preflight 범위 펜스 · e2e E5 펜스 · `## Final verdict` 세 판정 펜스 · Requirement index) · `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`(D5 펜스 끝 · D7 · R24 문장 둘) · `plugins/quality-gates/references/e2e.md`(7 절 기록에 e2e 줄이 언급되면) · `plugins/quality-gates/README.md`(한계 절) · `plugins/quality-gates/scripts/verdict.py`(R24 주석)
- Test: `plugins/quality-gates/tests/test_e2e_docs.sh` · `test_differential_procedure.sh` · `test_skill_run_contract.sh` · `test_diff_test_results.py` · `tests/harness/test_skill_orchestration_behavior.sh` · `test_publish_pipeline_wiring.sh` · 새 `plugins/quality-gates/tests/test_verdict_no_reread.sh`
- Consumes: Task 2 의 두 플래그.

- [ ] **Step 1: 락을 먼저 새 규칙으로 쓴다** — Task 0 Step 2 목록의 단언마다: R24 의 「셸이 기계 출력에서 뽑는다 · `N_BLOCK=$(sed …)` · `K=` 줄 · `--prior "$SYN"`」 단언을 새 규칙 단언으로 바꾼다 — 판정 펜스 셋(최종 · trivia · 걸러진 diff 빈 실행)의 본문에 `synth.out` · `synth-review.out` · `differential.yaml` · `excluded.md` · `range-scope.txt` · `--prior` · `sed -n` 이 0건(음), `R_ARGS=( <` · `D_ARGS=( <` · `X_ARGS=( <` · `S_ARGS=( <` · `E_ARGS=( <` 자리와 `"${R_ARGS[@]}"` 꼴 넘기기가 있다(양). 숫자 자리표시(`--blocking <`)는 지금처럼 0건. 새 R24 문장(아래 Step 3)이 `differential-test.md` 에 1건, 옛 문장 「판정은 기계 출력을 직접 읽고, 모델이 옮겨 적지 않는다」 · 「`verdict.py` 가 D5 의 사본을 직접 읽어 정한다」 가 0건.

- [ ] **Step 2: 변조 픽스처를 쓴다** — 새 `test_verdict_no_reread.sh` 의 `case_final_verdict_ignores_tampered_session`: 버릴 폴더에 세션 폴더 `RD` · `RV` 를 만들고, (1) 막는 지적 하나 픽스처로 합성기 `--emit-verdict --verdict-args` 를 돌려 리뷰 줄을 받고 (2) 차등 픽스처로 `verdict.py --emit-args --differential` 를 돌려 차등 줄을 받는다. 그다음 차등 테스트 · e2e 대역처럼 `rm "$RV/synth.out"` · `differential.yaml` 의 `new_failures:` 를 99 로 고치고 · `excluded.md` 에 줄 다섯을 더한다. SKILL.md 에서 최종 판정 펜스를 마커(`<!-- final-verdict:begin/end -->` — Step 3 에서 단다)로 뽑아 다섯 배열 자리를 받은 줄로 채워 돈다. 단언: rc 0 · 판정 줄의 막는 · 새 실패 · 제외 칸이 (1)(2) 와 Preflight 기본값(제외 0)의 값이고 변조 값(99 · 5)이 아니다 · 판정값이 `defect`. 양성 대조: 차등 배열 자리에 `--new-failures 99` 를 넣어 같은 펜스를 돌리면 판정 줄의 새 실패 칸이 99 다(펜스가 배열을 실제로 쓴다 — 위 단언이 공허하지 않다).

- [ ] **Step 3: SKILL · 절차를 고친다**
  - Flow 그림 · 문단: ① 리뷰 → **①' 리뷰 축 합성(Step 3.9)** → ② 차등 테스트 → ③ 합성 · 판정(Step 4 · 4.5, 그대로).
  - 새 `### Step 3.9 — 리뷰 축 합성 (차등 테스트 전)`: Step 4 펜스와 같은 합성기 호출에서 `--differential` · 차등 사유를 빼고 `--verdict-args` 를 더해 `> "$RV/synth-review.out"`, 이어 `tail -n 1 "$RV/synth-review.out"` 으로 줄을 보인다. 「이 줄을 판정 인자 줄(리뷰)로 턴에 든다 — 옮겨 적지 않고 글자 그대로 둔다.」 Step 4 펜스 · 되올려 다시 합성하기에도 `--verdict-args` 를 더하고 「새 리뷰 줄이 앞 줄을 대신한다」.
  - D5 펜스 끝: `diff_rc=0` 이고 사본이 있으면 `python3 "$QG/scripts/verdict.py" --emit-args --differential "$RD/differential.yaml"`, 아니면 `--emit-args --reason error-axis`. D0 kill switch 갈래 · D7 표에 같은 줄. R24 문장 둘을 「R24 판정 인자는 숫자를 만든 직후의 펜스가 낸 줄(`qg-verdict-args:`)의 글자 그대로다 — 모델은 숫자를 고르거나 옮겨 적지 않고 그 줄을 판정 펜스에 붙인다.」 로.
  - Fix-loop 「제외」 기록 뒤 한 줄 펜스: `X=$(grep -c '^- ' "$RD/excluded.md"); printf 'qg-verdict-args: --excluded %s\n' "$X"` (그 iteration 의 기록 직후 — 다음 차등 테스트 전).
  - Preflight 범위 얼림 펜스 끝(범위 모드): `printf 'qg-verdict-args: --sha %s\n' "$(git rev-parse --short "$(sed -n 's/^end: //p' "$RD/range-scope.txt")")"`.
  - E5 기록 펜스 끝: `printf 'qg-verdict-args: --e2e %q%s\n' '<e2e 칸>' '<뒤집었으면 " --e2e-overridden", 아니면 빈 글>'`.
  - `## Final verdict` 의 세 펜스: 마커를 달고, `SYN` · `N_BLOCK` · `K` · `X` · `RS` 읽기를 지우고 다섯 배열(`R_ARGS` 리뷰 · `D_ARGS` 차등 · `X_ARGS` 제외 · `S_ARGS` 범위 · `E_ARGS` e2e — 마지막 iteration 의 가장 늦은 줄, 범위 · 제외 · e2e 줄이 없으면 빈 자리)로. `X_ARGS` 가 비면 `--excluded 0`, `S_ARGS` 가 비면 `--sha "$(git rev-parse --short HEAD)"`, `E_ARGS` 가 비면 `--e2e '안 함'`. trivia · 걸러진 diff 빈 실행 펜스도 같은 다섯 배열(빈 자리 기본값)로. 첫 문단의 「(V1 · R24)」 문장을 새 뜻으로.
  - 판정 뒤 기록 펜스(`result.md`)는 그대로 세션 폴더를 읽는다 — 기록이지 판정 입력이 아니다.
  - Requirement index 의 V1 · K-3 · K-7 행을 새 뜻으로.

- [ ] **Step 4: README 한계 절** — quality-gates README `한계` 절(없으면 만든다)에 설계 §7 의 문장 그대로: 「qg 는 최종 판정 수치를 레포 코드가 돌기 전 또는 만든 직후에 읽어 지킨다. 반복 중간 단계와 레포 코드가 남긴 프로세스의 영향은 막지 않는다. 판정 뒤 게시 단계(게시 여부를 `range-scope.txt` 유무와 result.md 의 `## 게시` 줄로 정한다)도 같다」.

- [ ] **Step 5: 돌려 통과를 본다**

Run: `for t in test_e2e_docs.sh test_differential_procedure.sh test_skill_run_contract.sh test_v1_verdict_line.sh test_verdict_no_reread.sh test_publish_pipeline_wiring.sh test_e2e_verdict.sh harness/test_skill_orchestration_behavior.sh; do bash "plugins/quality-gates/tests/$t" >/dev/null 2>&1 || echo "FAIL $t"; done; python3 plugins/quality-gates/tests/test_diff_test_results.py`
Expected: 출력 없음 · unittest OK. `git grep -n -e '판정은 기계 출력을 직접 읽고' -e '사본을 직접 읽어 정한다' -- plugins/quality-gates ':!*CHANGELOG.md'` 0건.

- [ ] **Step 6: 커밋** — `fix(quality-gates): 최종 판정은 기계가 낸 인자 줄로만 — 차등 테스트 뒤 세션 폴더를 다시 읽지 않는다`

---

### Task 4: 리뷰 diff 의 제외 접두 · 이름 대조 · worktree 세션 결속 (AC20 · AC21)

**Files:**
- Modify: `plugins/quality-gates/scripts/review-diff.sh`(걸러진 diff · `is_qg_state` · `QG_WT_RE`)
- Test: `plugins/quality-gates/tests/test_review_diff.sh`

**Interfaces:**
- 걸러진 diff: 남길 tracked 경로 `KEEP`(= `NAMES` − 제외)를 `:(literal)<경로>` 로 명시해 `git diff`; `KEEP` 이 비면 `git diff` 를 부르지 않고 빈 diff. 제외 목록에서 다른 바뀐 경로의 폴더 접두(`x` 와 `x/…`)인 경로는 빼고(제외하지 않는다) stderr 에 한 줄. 끝에 대조: (tracked + untracked 파일 이름) − 제외 − (걸러진 이름 + untracked 리뷰분) 이 비어야 하고, 남는 경로마다 `say_unreviewed` 와 같은 꼴의 줄 + `degraded: yes`.
- worktree: `SID8="${DIR##*/}"; SID8="${SID8:0:8}"`; `QG_WT_RE` 의 8자 자리를 `SID8`(영숫자 `_-` 만 — 아니면 건너뛰기 없음)로. 맞지 않는 `(base|head)-<8자>/` 는 중첩 레포 갈래로 가고 이유 줄: `review-diff: 이전 qg 실행이 남긴 worktree <경로> 는 리뷰하지 않았다 — qg-gc 로 지운 뒤 다시 돌려라`.

- [ ] **Step 1: 실패하는 케이스를 쓴다**(`test_review_diff.sh` 의 버릴 레포 꼴)
  - `case_excluded_prefix_not_swallowed` — 기준 커밋에 파일 `notes`(제외 대상이 되게 `--globs`/doc_paths 규칙으로 고른다), 끝 쪽에서 `notes` 를 지우고 `notes/a.py` 를 더한다. 단언: `review-i1.diff` 에 `notes/a.py` 가 있거나 `degraded: yes` 와 stderr 에 그 경로.
  - `case_name_reconcile_catches_missing` — `GITD` 를 흉내 내는 대역으로 걸러진 diff 가 한 경로를 빠뜨리게(테스트 전용 환경 변수 없이 — 제외 목록에 실재하지 않는 꼴의 경로를 doc_paths 가 내게 하는 픽스처로) 만들고 `degraded: yes` 를 단언한다. 대역 방법이 마땅치 않으면 대조 함수를 스크립트 안 셸 함수로 두고 그 함수를 직접 부르는 단위 케이스로 단언한다.
  - `case_all_excluded_no_pathspec` — 바뀐 경로가 전부 제외되면 `review-i1.diff` 가 비고 `filtered_files: 0`(전체 diff 가 아니다).
  - `case_other_session_worktree_degraded` — `--dir .claude/quality-gates/sessAAAA0000` 로 돌 때 등록된 `worktrees/base-sessBBBB/` 가 있으면 `degraded: yes` · stderr 에 「이전 qg 실행이 남긴 worktree」 · 「qg-gc」. 양성 짝: `worktrees/base-sessAAAA/` 는 지금처럼 건너뛴다(`self_state` 에 센다).

- [ ] **Step 2: 돌려 실패를 본다** — 넷 중 앞 셋 · 넷째 음성이 RED.

- [ ] **Step 3: 구현한다** — Interfaces 대로. 경로 목록이 길면 `git diff` 인자가 길어진다 — `xargs` 로 나누지 않고(같은 diff 를 여러 번 이어 붙이면 머리가 겹친다) 한 번에 넘긴다. bash 3.2 에서 빈 배열 전개는 `${A[@]+"${A[@]}"}` 꼴.

- [ ] **Step 4: 돌려 통과를 본다** — `bash plugins/quality-gates/tests/test_review_diff.sh && bash plugins/quality-gates/tests/test_check_review_scope.sh 2>/dev/null; bash plugins/quality-gates/tests/test_skill_run_contract.sh`(있는 것만).

- [ ] **Step 5: 커밋** — `fix(quality-gates): 리뷰 diff 는 남길 경로를 명시하고 이름을 대조한다 — 다른 세션의 worktree 는 건너뛰지 않는다`

---

### Task 5: 중첩 레포 리뷰 다시 열기 (AC22)

**Files:**
- Modify: `plugins/quality-gates/scripts/review-diff.sh`(`NESTED` 갈래) · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(Step 1c 의 중첩 레포 문장 · Verdict inputs 표의 그 행)
- Test: `plugins/quality-gates/tests/test_review_diff.sh`

**Interfaces:**
- 「설정」 갈래(Task 0 Step 5 가 통과했을 때): 중첩 레포 `x/` 마다 결정 6 의 명령으로 파일 목록을 얻어 각 파일을 `add_untracked` 로 싣는다(링크는 `add_dir_link` 꼴로 링크 줄만, 그 안의 중첩 레포 폴더 줄은 지금처럼 `say_unreviewed`). 목록 명령이 실패하면 그 `x/` 는 지금처럼 `say_unreviewed` + 이유 「무시 규칙을 지켜 파일 목록을 얻지 못했다」.
- 「공시」 갈래: 동작은 지금 그대로, `say_unreviewed` 줄에 이유 「중첩 레포 안은 무시 규칙을 지켜 안전하게 읽는 길이 없다」 를 더한다.

- [ ] **Step 1: 적대 픽스처 케이스를 쓴다** — Task 0 Step 5 의 픽스처를 `test_review_diff.sh` 의 `case_nested_repo_reviewed_safely` 로: 단언(「설정」 갈래) — `review-i1.diff` 에 `sub/src/a.py` 내용이 있고 `sub/node_modules/x.js` 가 없다 · 마커 파일이 없다(설정의 명령이 돌지 않았다) · `SECRET-R12` 가 diff 어디에도 없다(링크를 따라가지 않았다) · `sub/inner/` 는 stderr 「리뷰하지 않았다」 줄과 `degraded: yes` · `inner` 가 없는 픽스처에서는 `degraded: no`. 「공시」 갈래면 대신: `degraded: yes` 와 이유 문장 · 마커 없음 · 비밀 없음.

- [ ] **Step 2: 돌려 실패를 본다** — 「설정」 갈래면 `sub/src/a.py` 단언 RED, 「공시」 갈래면 이유 문장 RED.

- [ ] **Step 3: 구현한다** — 갈래대로. 임시 `GIT_DIR` 는 이 스크립트의 `$T` 아래 `git init --bare -q` 로 만들고 trap 정리를 따른다. 환경: `GIT_DIR` · `GIT_WORK_TREE` 만 그 호출에 주고 `GIT_CONFIG_NOSYSTEM=1`. SKILL Step 1c · 표의 「중첩 레포는 리뷰하지 않는다」 문장을 갈래에 맞게.

- [ ] **Step 4: 돌려 통과를 보고 격리를 확인한다** — `bash plugins/quality-gates/tests/test_review_diff.sh` · 이 worktree `git status --short` 가 깨끗하다.

- [ ] **Step 5: 커밋** — 「설정」 갈래: `fix(quality-gates): 중첩 레포는 그 설정 · 링크 없이 무시 규칙대로 리뷰한다` / 「공시」 갈래: `docs(quality-gates): 중첩 레포를 리뷰하지 않는 이유를 출력에 싣는다`

---

### Task 6: codex 가 검토 트리의 AGENTS.md 를 지시로 읽지 않게 (AC23)

**Files:**
- Modify: `git grep -l 'codex exec -' -- 'plugins/*/scripts/*.sh' 'shared/*/scripts/*.sh'` 가 낸 러너 전부(계획을 쓴 때 넷: `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `run_artifact_codex_reviewer.sh` · `shared/docreview/scripts/run_docreview_codex_reviewer.sh` · `plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh`)
- Modify(「공시」 갈래): 각 러너의 codex 축 공시 줄 · quality-gates · spec-distill · plugin-audit README 한계 절
- Create: `shared/tests/test_codex_project_doc_off.sh`(100755)

- [ ] **Step 1: 락을 쓴다** — 새 테스트가 러너를 `git ls-files` + `grep -l 'codex exec -'`(테스트 · 픽스처 · 주석 줄 제외)로 도출하고 수가 0 이면 `no`. 「설정」 갈래: 러너마다 `codex exec -` 호출 블록(그 줄부터 다음 빈 줄 · `||` 까지)에 `-c 'project_doc_max_bytes=0'` 이 정확히 한 번. 「공시」 갈래: 러너마다 공시 문장 「codex 가 검토 대상 트리의 AGENTS.md 를 지시로 읽을 수 있다」 가 있고 세 README 한계 절에도 있다. 양성 대조: 도출 목록에 넷이 모두 든다(새 러너가 생기면 자동으로 든다).

- [ ] **Step 2: 돌려 실패를 본다.**

- [ ] **Step 3: 고친다** — 갈래대로. 러너 테스트 가운데 codex 인자 배열을 바이트로 고정한 것(`git grep -l "web_search" -- 'plugins/*/tests/*' 'shared/tests/*'`)이 있으면 함께 고친다. 공유 러너는 정본 한 곳(`shared/docreview/scripts/`)만 고친다(링크가 따라간다).

- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_codex_project_doc_off.sh && bash shared/tests/test_docreview_codex.sh && bash shared/tests/test_codex_runner_scratch_trap_order.sh && bash plugins/quality-gates/tests/test_codex_invocation_contract.sh && bash shared/tests/test_copy_of_contract.sh` 와 plugin-audit 러너 테스트(`grep -l run_audit_codex_reviewer plugins/plugin-audit/tests/*`).

- [ ] **Step 5: 커밋** — `fix(codex): 검토 트리의 AGENTS.md 를 지시로 불러오지 않게 — 러너 전부`

---

### Task 7: e2e 시나리오 수 상한 공시 (AC24)

**Files:**
- Modify: `plugins/quality-gates/references/e2e.md`(§1 · §2)
- Test: `plugins/quality-gates/tests/test_e2e_docs.sh`

- [ ] **Step 1: 단언을 쓴다** — §1 에 「만들 수 있는 시나리오가 셋을 넘으면 셋만 만들고 나머지 후보 수를 센다」, §2 에 질문 본문 문장 「시나리오 후보 N개 중 셋만 만들었다 — 「기타」 칸에 적으면 그 자리에서 더 만든다」 와 「기타」 규칙: 시나리오를 고르지 않고 「기타」 에 아직 만들지 않은 후보를 적으면 그 시나리오를 만들어 같은 질문을 한 번 더 띄운다(그 선택이 실행 승인이다 — 지금의 시나리오 수정 갈래와 같은 한 번). 선택지 넷 상한 문장은 그대로 있다(양성 짝).

- [ ] **Step 2: 돌려 실패를 보고 고친 뒤 통과를 본다** — `bash plugins/quality-gates/tests/test_e2e_docs.sh`.

- [ ] **Step 3: 커밋** — `docs(quality-gates): e2e 후보가 셋을 넘으면 질문에 수와 더 여는 길을 싣는다`

---

### Task 8: 문서 · 버전 · 스위트 대조 · 변이 · AC 보고 (AC34 마감)

**Files:**
- Modify: `plugins/quality-gates/{CHANGELOG.md,.claude-plugin/plugin.json,README.md}` · `plugins/spec-distill/{CHANGELOG.md,.claude-plugin/plugin.json}` · `plugins/plugin-audit/{CHANGELOG.md,.claude-plugin/plugin.json}` · 루트 `.claude-plugin/marketplace.json`(설명이 바뀔 때만)
- Modify: `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md`(`## 미룸` — 있을 때만)
- Create: `$HOME/.claude/sdd-mirror/r12-plan2/ac-report.md`

- [ ] **Step 1: README · CHANGELOG · 버전** — quality-gates README `Principles Instantiated` 의 판정 줄(V1 · R24 를 말하는 줄)을 새 뜻(「판정 인자는 숫자를 만든 직후 기계가 낸 줄 그대로」)으로. CHANGELOG 셋: quality-gates — Changed(판정 인자 줄 · Step 3.9 · R24 새 뜻) / Fixed(판정 id · 제외 접두 · worktree 세션 · 중첩 레포 갈래 · e2e 공시) / Security(codex AGENTS.md · 변조된 세션 폴더). spec-distill · plugin-audit — 각 러너 한 줄(Security). plugin.json minor 셋.

Run: `bash shared/tests/test_changelog_integrity.sh && bash shared/tests/test_invocation_surface.sh && bash shared/tests/test_copy_of_contract.sh && bash shared/tests/test_dispatch_disposition.sh`
Expected: PASS.

- [ ] **Step 2: 스위트 대조** — 계획 1 Task 12 Step 2 와 같은 꼴(`r12-plan2` 폴더). 새 실패 이름 0.

- [ ] **Step 3: 변이 기록** — 최소: `claim_key` 를 빈 글로(Task 1 — 다른 요약 케이스 RED) · 합성기 리뷰 줄에 차등 사유를 섞기(Task 2) · 최종 펜스에 `SYN=…synth.out` 읽기를 되살리기(Task 3 문면 락 RED) · `KEEP` 이 빌 때 `git diff` 를 부르게(Task 4 `case_all_excluded_no_pathspec` RED) · `SID8` 비교를 지우기(Task 4) · 「설정」 갈래면 `GIT_DIR` 를 빼고 중첩 레포의 `.git` 으로 부르게(Task 5 마커 RED) · 러너 하나에서 `project_doc_max_bytes` 지우기(Task 6). PR 본문 「변이 확인」 표로. 생존 변이가 있으면 그 락을 고친다.

- [ ] **Step 4: 마지막 전체 리뷰 — AC 보고** — 마지막 전체 리뷰 요청에 설계문서 `## Acceptance Criteria` 의 **AC17~AC24 · AC34** 원문을 싣고 AC 마다 한 줄 `AC<번호>: 구현됨 | 미룸 | 빠짐 — <근거>` 를 받는다. 이음매(Step 3.9 줄과 되올리기 줄의 대체 · D5 의 rc 갈래가 어느 줄을 내는지 · Preflight 가 지운 `excluded.md` 와 제외 줄 기본값 · Task 4 의 대조와 Task 5 의 중첩 갈래가 같은 `degraded` 를 쓰는 것)와 plan-mandated 테스트 코드를 묻는다. 보고를 `$HOME/.claude/sdd-mirror/r12-plan2/ac-report.md` 에 쓴다.

- [ ] **Step 5: 미룸 표와 구현 대조** — 미룸 · 빠짐 · 리뷰 후속 미룸을 설계문서 `## 미룸` 에 올리고:

Run: `python3 "<SD>"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md "$HOME/.claude/sdd-mirror/r12-plan2/ac-report.md" --acs "AC17~AC24 · AC34"`
Expected: 첫 줄과 경고를 마지막 보고에 그대로 싣는다.

- [ ] **Step 6: 커밋 · push** — `chore(quality-gates): R12 계획 2 — README · CHANGELOG · 판`(pathspec: 위 Files) 뒤 `git push -u origin feature/qg-verdict-state`. 마지막 보고: 판정 전체 · AC 보고 전체 · `--impl` 결과 · 커밋 목록 · 본 테스트 실패 · codex 호출 수 · Task 0 실측 둘의 결과와 고른 갈래.
