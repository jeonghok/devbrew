# qg 토픽 구성원 규칙 재결정 구현 계획 (PR4d)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 로 이 계획을 Task 단위로 실행한다. 단계는 체크박스(`- [ ]`) 표기다.

**Goal:** 같은 `Spec:` 토픽 키에서 이미 `base_ref` 에 든 선언 커밋은 판정 대상이 아니라 기준선으로 두고(AC4 재정의), 그 수를 `in_base` 로 스코프 튜플 · `scope:` 블록 · SKILL 공지에 싣는다.

**Architecture:** `resolve-topic.sh` 가 선언 커밋 `C` 를 `C_live`(아직 base 에 안 든 것)와 `in_base`(든 것의 수)로 가르고, 구성원 1단계를 `C_live` 로만 세며, 머지된 구성원 2단계(`merged:` · `MERGED_MAINLINE`)를 통째로 지운다. 경계는 모든 구성원에 `merge-base(base_ref, b)` 를 쓴다. `in_base` 는 `resolve`(11키) → `topic-head.sh`(13키) → 스코프 파일 → `scope_tuple.py`(13키 · 검증 · 렌더) → `scope:` 블록으로 흐르고, SKILL ① 이 `in_base` > 0 이면 공지 한 줄을 낸다.

**Tech Stack:** bash 3.2 호환(스크립트 · 락) · Python 3.9+ 시스템 `python3`(3.10+ 문법 금지, 표준 라이브러리) · `shared/tests/assert.sh` · git 2.54

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.2.2(정의 블록 `C_live` · `in_base` · 도출 1·2·3단계) · §6.2.3(머지된 구성원 보정 삭제) · §6.2.6(`in_base`) · §11 AC4(재정의) · §15-12(squash 한계) · §16(4d 행 · 재결정 블록 P23 2026-09-27). 설계 편집은 이 브랜치의 첫 커밋으로 이미 들어가 있다 — 이 계획은 설계 문서를 고치지 않는다.

---

## Global Constraints

- **선언이 없으면 판정은 바뀌지 않는다**(§6.2.5 · AC16). `branch` · `--paths` override 는 토픽을 보지 않는다.
- **토픽 키는 트레일러 값 «전체»다 — 조각까지 포함한다**(§6.2.2).
- **`C_live` = `C` 중 `base_ref` 의 조상이 아닌 것. `in_base` = `|C| − |C_live|`.** 선언 0 이면 `in_base: 0`. `resolve` 가 `C` 를 세기 전에 끝나는 경로(`base-unresolved` 등)는 `in_base: -`.
- **`C_live` 가 비면 `resolve` 는 `status: no-declaration` · `reason: all declared commits are already in base_ref`** 다. `topic-head.sh` 는 `resolve` 의 `no-declaration` 을 `declaration-invalid` 로 받고 `resolve` 의 reason 을 그대로 싣는다.
- **판정 어휘는 `scripts/verdict.py` 밖에 두지 않는다.** 이 PR 은 사유 · status 열거를 늘리지 않는다(`STATUSES` 8 · `STATUS_TO_REASON` 4 그대로).
- **fail4 계약은 원자적이다** — `scope_tuple.parse` 의 실패 경로는 stdout 에 아무것도 쓰지 않는다. exit `0` 정상 · `2` 잘못된 호출 · `4` 실패한 판정. 셸 스크립트의 `die` 는 exit 2.
- **비신뢰 입력에 거는 정규식은 `fullmatch`.**
- **락은 same-line · 부정형 거부 · 목적지 양의 단언으로 쓴다. 부재 락에는 양의 짝을 둔다.**
- **범위 불변식** — 아래 경로는 한 바이트도 바뀌지 않는다: `shared/**` · `plugins/spec-distill/**` · `plugins/plugin-audit/**` · `.claude-plugin/marketplace.json` · 루트 `CLAUDE.md` · `docs/superpowers/specs/**` · `plugins/quality-gates/agents/**` · `plugins/quality-gates/scripts/{seal-worktree.sh,combine-tips.sh,qg-worktree.sh,synthesize_findings.py,verdict.py,angles.py,recritic_bridge.py,run-test-selection.sh,qg-gc.py,gc_common.py}` · `plugins/quality-gates/skills/quality-pipeline/references/**`(단 `differential-test.md` 의 「형제 · 머지된 구성원의 변경을 모른다」 한 곳 — Task 3 (d)) · `tools/**` · `plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 밖 바이트. Task 5 가 대조한다.
- **커밋 본문에서 `Spec: ` 로 시작하는 줄은 트레일러 단락의 한 줄뿐이다**(`detect` 가 원시 메시지의 `^Spec: ` 줄을 전부 키로 센다 — 어기면 이 PR 의 토픽이 영구 `declaration-invalid`).
- **커밋 트레일러** — 마지막 `-m` 단락 **하나**에 `Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4d` 와 `Co-Authored-By: <그 커밋을 쓴 실제 모델>` 두 줄.
- **버전은 브랜치에서 정하지 않는다** — 머지 직전 `origin/main` 을 다시 보고 qg minor 를 올린다(오늘 관측 9.1.0 → 9.2.0).
- **최신화는 merge, rebase 금지.** 세션이 치는 명령에서 메인 체크아웃으로 `cd` 금지, `git -C` 금지(제품 · 테스트 스크립트 안은 대상 아님), bare `git stash` 금지.
- **명령은 워크트리 루트에서 돈다.** 격리 가드가 계산된 경로 · git 을 감싼 `for` · 명령 문자열 속 「github」를 거부하면 `$CLAUDE_JOB_DIR/tmp/` 아래 스크립트 파일로 돌린다. 계획 문면의 `$CLAUDE_JOB_DIR` 는 호출 전에 절대 경로 리터럴로 푼다.
- **`PYTHONDONTWRITEBYTECODE=1`.** 파이썬 편집마다 `python3 -m py_compile`, 셸 편집마다 `bash -n`.
- **`plugins/quality-gates/tests/*.sh` 는 git 모드 100755.**
- **git-ignored 산출물(기준선 TSV · 변이 표 · SDD 원장)은 매 갱신마다 `~/.claude/sdd-mirror/qg-topic-membership-pr4d/` 로 복사한다.**
- **계획 문면의 펜스 블록은 글자 그대로 옮긴다** — 옮기기 전에 목적지 파서로 검증한다. 인용한 옛 문구가 한 줄 grep 에 안 걸리면 앞 서너 단어로 찾아 문장 전체를 고친다. 뜻까지 다르면 멈추고 보고한다.
- **변이는 사본에서 우선** — 워킹트리에서 하면 변이 전 커밋, 복원은 `git checkout HEAD -- <파일>` + `git diff HEAD --stat` 빈 출력.

## Review Focus

스펙이 함의하지만 기본 테스트가 태우지 않는 입력 중 쓰는 사람을 가장 먼저 물 다섯. 각 줄의 테스트는 소유 Task 에 들어가 있다.

1. **같은 키 스택의 뒤 조각이 main 을 merge 로 최신화**(이 리포의 표준 흐름) → 경계가 방금 최신화한 main 이고 리뷰 변경은 뒤 조각의 파일뿐이다(main 이력 · 머지된 앞 조각 없음). — Task 1 `case_n1_main_history_not_absorbed`
2. **같은 키 후속 작업을 머지 뒤 main 에서 새로 땀**, 그 사이 무관한 로컬 · 원격 브랜치가 있음 → 구성원은 후속 브랜치 하나다. — Task 1 `case_unrelated_after_merge_not_member`
3. **git-flow 중첩 머지**(A → develop → main, develop 에 머지 뒤 작업) → 구성원이 develop 으로 넓어지지 않는다. — Task 1 `case_n2_nested_merge_not_expanded`
4. **전부 머지된 키를 `--topic` 으로 직접 줌**(`create-head --topic` 재도출 · 수동) → 크래시 없이 `declaration-invalid` 와 「already in base_ref」 사유 · `in_base` 공시. — Task 2 `case_explicit_topic_fully_merged`
5. **squash 로 든 앞 조각의 ref 가 살아 있음** → 여전히 구성원이다(§15-12 알려진 한계 — 동작을 기록으로 고정). — Task 1 `case_squash_front_still_member`

---

## 이 PR 이 지는 것

| 항목 | 내용 | 집행 자리 |
|---|---|---|
| **AC4 재정의** | 이미 `base_ref` 에 든 선언은 기준선 · `in_base` 공시 | Task 1 · 2 · 3 |
| **§6.2.2 1단계** | 구성원 근거 = `C_live` | Task 1 |
| **§6.2.2 2단계 삭제 · §6.2.3 보정 삭제** | `merged:` · `MERGED_MAINLINE` · `--ancestry-path` 제거 | Task 1(+ 부재 락) |
| **§6.2.2 3단계** | `C_live` 고아 → `declaration-invalid` · `C_live` 빔 → `no-declaration` | Task 1 |
| **§6.2.6** | 튜플에 `in_base` | Task 2 |
| **I1 반례 N1 · N2 · N3** | 회귀 락 | Task 1 |
| **README · CHANGELOG** | 9.1.0 알려진 한계 한 줄 → 해소 · §15-12 한계 공시 | Task 3 · Task 5 |

## 끝에서 끝 흐름

| # | 자리 | 입력 | 산출 | 소비자 | 소유 Task |
|---|---|---|---|---|---|
| 1 | `resolve-topic.sh resolve` | `C` · `base_ref` | `C_live` · `in_base:`(11번째 키) · 구성원 · 경계 | `topic-head.sh` | 1 |
| 2 | `topic-head.sh` | `resolve` 출력 | `in_base:`(13번째 키) | SKILL ① 1a 스코프 파일 | 2 |
| 3 | SKILL ① 1a | 스코프 파일 | `in_base` > 0 이면 공지 한 줄 | 사용자 | 3 |
| 4 | `scope_tuple.parse` | 스코프 파일 | `in_base` 검증(`-` 또는 수 · ok 면 수) | 합성기 `--scope` | 2 |
| 5 | `scope_tuple.render` | 튜플 | `scope:` 블록 `  in_base: N` | Step 4.5 · Final Summary | 2 |
| 6 | 레퍼런스 R-init | `boundary:` | 기준선 — 머지된 앞 조각이 이제 경계 안쪽 | R4 | (변경 없음 — 경계 값의 의미만 바뀐다) |

---

## 파일 구조

**수정**

| 경로 | 무엇이 |
|---|---|
| `plugins/quality-gates/scripts/resolve-topic.sh` | 머리 주석 · `IN_BASE` · `emit` 11키 · `C_live` 계산 · 1단계 루프 · 2단계 → 고아 계산 · 경계 루프 |
| `plugins/quality-gates/scripts/topic-head.sh` | 머리 주석 13줄 · `IN_BASE` · `emit` · `resolve` 에서 받기 · `no-declaration` 사유 전달 |
| `plugins/quality-gates/scripts/scope_tuple.py` | docstring · `KEYS` · 검증 · `_RENDER_ORDER` |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | ① 1a 공지 문단 한 줄 |
| `plugins/quality-gates/README.md` | 「토픽 스코프」 절 · 알려진 한계 |
| `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` | 「형제 · 머지된 구성원의」 → 「형제 구성원의」 한 곳(범위 불변식의 유일한 예외) |
| `plugins/quality-gates/tests/test_topic_boundary.sh` | F2 · F3 재작성 · 케이스 교체 · 새 케이스 일곱 |
| `plugins/quality-gates/tests/test_topic_head.sh` | 13키 · 머지된 구성원 케이스 재작성 · 새 케이스 둘 |
| `plugins/quality-gates/tests/test_scope_tuple.sh` | 헬퍼 · PY_LS 에 `in_base` · 새 케이스 하나 |
| `plugins/quality-gates/tests/test_topic_scope_wiring.sh` | 새 케이스 하나 |
| `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json`(`version` 만) · SKILL 제목 버전 · `skills/publishing-pr-understanding/SKILL.md` 제목 버전 | bump(Task 5) |

---

## 착수 — 컨트롤러가 Task 1 전에 한다

- [ ] **Step A: 브랜치 · base 확인**

```bash
git branch --show-current
git fetch origin --quiet
git merge-base --is-ancestor origin/main HEAD && echo "OK origin/main ⊆ HEAD"
git rev-list --count HEAD..origin/main
git log --oneline origin/main..HEAD
```

```bash
bash plugins/quality-gates/scripts/resolve-baseline.sh | grep '^base_ref:'
```

  **기대** — `feature/qg-topic-membership-pr4d` · `OK …` · `0` · 설계 재결정 커밋(`docs(spec): qg 토픽 구성원 규칙 재결정 …`)과 계획 커밋. 계획 파일이 untracked 면 먼저 커밋한다(본문에 `Spec: ` 로 시작하는 줄 없이, 트레일러 `#pr4d`). 마지막 명령은 `base_ref: origin/main` — 다르면(`origin/HEAD` 가 딴 곳을 가리킴) Task 1 Step 4 의 실제 리포 검사가 틀린 답을 낸다. 멈추고 보고한다.

- [ ] **Step B: 미러 · 러너 · 기준선**

```bash
mkdir -p ~/.claude/sdd-mirror/qg-topic-membership-pr4d
cp ~/.claude/sdd-mirror/qg-topic-scope-pr4c/run-suite.sh "$CLAUDE_JOB_DIR/tmp/run-suite.sh"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4d-baseline.tsv"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u > "$CLAUDE_JOB_DIR/tmp/pr4d-baseline-harness-fails.txt"
cp "$CLAUDE_JOB_DIR"/tmp/pr4d-baseline* "$CLAUDE_JOB_DIR/tmp/run-suite.sh" ~/.claude/sdd-mirror/qg-topic-membership-pr4d/
```

  **기대** — 217 파일, 비0 넷: qg `test_codex_backward_compat.sh`(1) · qg `test_runner_adapters.sh`(1) · qg `harness/test_skill_orchestration_behavior.sh`(2) · spec-distill `test_no_write_matcher_hooks_repo.sh`(1). unittest `Ran 197` OK. 하네스 실패 이름 2(`R1b→R8 unclaimed 집행 사슬` · `iter cap near Review gate AskUserQuestion`). 다르면 기준선 표를 원장에 적고 그 차이를 모든 Task 의 RED diff 기준으로 쓴다(멈추지 않는다). 기대 넷 밖의 비0 파일은 단독으로 다시 돌려 GREEN 이면 플래키로 원장에 적는다(기록: PR4c `shared/tests/test_docreview_round_gate_split.sh` · PR4d 모의 실행 `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh`).

- [ ] **Step C: 전제 확증** — 아래가 전부 한 건 이상 나와야 한다. 하나라도 0 이면 BLOCKED.

```bash
grep -c 'B_t 2단계: 머지된 구성원' plugins/quality-gates/scripts/resolve-topic.sh
grep -c 'MERGED_MAINLINE' plugins/quality-gates/scripts/resolve-topic.sh
grep -c 'echo "seal_on_topic: \$SEAL_ON_TOPIC"' plugins/quality-gates/scripts/topic-head.sh
grep -c '"seal_on_topic", "tree", "head_commit", "conflicts", "commits")' plugins/quality-gates/scripts/scope_tuple.py
grep -c 'C_live' docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md
grep -c 'case_f2_boundary_merged_not_hidden' plugins/quality-gates/tests/test_topic_boundary.sh
```

---

### Task 1: `resolve-topic.sh` — `C_live` · 2단계 삭제 · `in_base`(11키)

**Files:**
- Modify: `plugins/quality-gates/scripts/resolve-topic.sh`
- Test: `plugins/quality-gates/tests/test_topic_boundary.sh`

**Interfaces:**
- Produces: `resolve-topic.sh resolve <key> [--seal <sha>]` → 정확히 11줄, 순서 `topic_key · status · reason · declared · in_base · branches · boundary · tips · commits · base_ref · seal_on_topic`. `in_base` 는 `-`(C 를 세기 전 종료) 또는 음 아닌 정수. `branches:` 에 `merged:` 원소가 더는 나오지 않는다. `C_live` 가 비면 `status: no-declaration` · `reason: all declared commits are already in base_ref`. `detect` · `commits` 계약은 불변(`commits` 는 status≠ok 이면 exit 3).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/quality-gates/tests/test_topic_boundary.sh` 여섯 자리.

  (a) `case_f2_merged_ref_alive` 정의 전체(바로 위 주석 네 줄 `# ── F2: 구성원 하나가 머지됨 + ref 살아 있음 → 여전히 포함 (AC4) ──…` 부터 그 함수의 닫는 `}` 까지)를 아래로 바꾼다:

```bash
# ── F2: 구성원 하나가 머지됨 + ref 살아 있음 → 기준선 · in_base 공시 (AC4 재정의) ──
#    머지된 topicA 의 선언은 판정 대상이 아니라 기준선이다 — 구성원은 아직 base 에 안 든
#    topicB 뿐이고, 머지된 선언의 수가 in_base 로 나온다(재결정 P23 2026-09-27).
case_f2_merged_ref_alive() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA     # ref 는 그대로 둔다
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F2 status: ok"
  assert_eq "$(field declared "$out")" "2" "F2 선언 커밋 2(C 전체)"
  assert_eq "$(field in_base "$out")" "1" "F2 base 에 든 선언 1 이 in_base 로 공시된다"
  assert_eq "$(field branches "$out")" "topicB" "F2 구성원은 topicB 뿐 — 머지된 topicA 는 기준선"
  assert_eq "$(field boundary "$out")" "$R" "F2 경계 = topicB 의 분기점"
  assert_eq "$(field commits "$out")" "1" "F2 T = topicB 의 커밋 하나"
  cleanup
}
```

  (b) `case_f3_merged_ref_deleted` 정의 전체(바로 위 주석 한 줄 `# ── F3: …` 포함)를 아래로 바꾼다:

```bash
# ── F3: 구성원 하나가 머지되고 ref 도 삭제됨 → 같은 답 (AC4 재정의) ────────────
case_f3_merged_ref_deleted() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA
  git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F3 status: ok"
  assert_eq "$(field in_base "$out")" "1" "F3 in_base 1"
  assert_eq "$(field branches "$out")" "topicB" "F3 구성원은 topicB 뿐 — merged: 구성원이 없다"
  assert_eq "$(field boundary "$out")" "$R" "F3 경계 = topicB 의 분기점"
  cleanup
}
```

  (c) `case_f2_boundary_merged_not_hidden` 정의 전체(바로 위 주석이 있으면 그것까지)를 아래 두 케이스로 바꾼다:

```bash
# ── 키의 선언이 전부 base 에 있다 → no-declaration (§6.2.2 3단계) ──────────────
case_all_declared_in_base() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  echo r2 >> f.txt; git commit -qam r2
  git merge -q --no-ff -m "merge topicA" topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "no-declaration" "선언 전부 base: status: no-declaration"
  assert_grep "$(field reason "$out")" 'already in base_ref' "reason 이 base 에 들었음을 적는다"
  assert_eq "$(field declared "$out")" "1" "declared 는 C 전체(1)"
  assert_eq "$(field in_base "$out")" "1" "in_base 1"
  local rc; bash "$RT" commits "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "3" "commits 는 status≠ok 이면 exit 3(그대로)"
  cleanup
}

# ── C_live 원소가 어느 살아 있는 ref 에도 없다 → 고아 (§6.2.2 3단계) ────────────
case_orphan_tag_only() {
  new_repo
  git checkout -q --detach HEAD; decl_commit t.txt t1 "t1 (태그에만)"
  git tag only-tag
  git checkout -q main
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "declaration-invalid" "태그에만 있는 선언: declaration-invalid"
  assert_grep "$(field reason "$out")" '^orphan declaration commit' "reason 이 고아를 이름 붙인다"
  assert_eq "$(field in_base "$out")" "0" "고아는 base 에 없다(in_base 0)"
  cleanup
}
```

  (d) `case_ten_keys_always` 정의 전체(바로 위 주석 한 줄 `# ── 출력 계약: 10키가 …` 포함)를 아래로 바꾼다:

```bash
# ── 출력 계약: 11키가 «항상» 나온다 (in_base 가 다섯째 키) ─────────────────────
case_eleven_keys_always() {
  new_repo
  local out; out=$(bash "$RT" resolve "$KEY")
  local n; n=$(printf '%s\n' "$out" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "11" "선언 0 인 리포에서도 11키 전부 emit"
  assert_eq "$(printf '%s\n' "$out" | sed -n '5p')" "in_base: 0" "다섯째 줄이 in_base — 선언 0 이면 0"
  assert_eq "$(field seal_on_topic "$out")" "-" "--seal 없으면 seal_on_topic: -"
  local rc; bash "$RT" resolve "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "정상 경로 exit 0"
  cleanup
}
```

  (e) `case_base_remote_ref_never_member` 의 마지막 단언 줄(`… '(^|,)merged:[0-9a-f]{40}(,|$)' "머지된 topicA 는 merged: 로 있다(양의 짝)"`)을 아래 줄로 바꾼다:

```bash
  assert_eq "$(field in_base "$out")" "1" "머지된 topicA 의 선언은 in_base 로 공시된다(양의 짝)"
```

  (f) `for c in …` 루프 **앞**(마지막 케이스 정의 뒤)에 새 케이스 다섯을 넣는다:

```bash
# ── 머지 뒤 base 에서 딴 무관 브랜치는 구성원이 아니다 (재결정 P23 2026-09-27) ────
case_unrelated_after_merge_not_member() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff -m "merge topicA" topicA
  git branch -q -D topicA
  git checkout -q -b unrelated; echo u > u.txt; git add u.txt; git commit -qm "u (선언 없음)"
  git update-ref refs/remotes/origin/other "$(git rev-parse HEAD)"
  git checkout -q main; git checkout -q -b topicB2; decl_commit b2.txt b2 "b2 — 같은 키 후속"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "같은 키 후속: status: ok"
  assert_eq "$(field branches "$out")" "topicB2" "구성원은 topicB2 뿐 — unrelated · origin/other 는 아니다"
  assert_eq "$(field in_base "$out")" "1" "머지된 앞 조각은 in_base 1"
  assert_eq "$(field commits "$out")" "1" "T = topicB2 의 커밋 하나"
  cleanup
}

# ── N1 회귀 락: 머지 뒤 쌓인 main 이력이 리뷰 대상에 흡수되지 않는다 ────────────
case_n1_main_history_not_absorbed() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB; decl_commit b.txt b1 "b1 — A 위에 쌓은 스택"
  git checkout -q main; git merge -q --no-ff -m "merge topicA" topicA
  local i; for i in 1 2 3 4 5; do echo "m$i" > "m$i.txt"; git add "m$i.txt"; git commit -qm "main m$i"; done
  git checkout -q topicB; git merge -q --no-edit main      # 스택 뒤 조각이 main 을 merge 로 최신화
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "N1: status: ok"
  assert_eq "$(field branches "$out")" "topicB" "N1: 구성원 topicB 뿐"
  assert_eq "$(field boundary "$out")" "$(git rev-parse main)" "N1: 경계 = 방금 최신화한 main"
  assert_eq "$(git diff --name-only "$(field boundary "$out")" topicB)" "b.txt" \
    "N1: 경계..topicB 의 변경은 b.txt 뿐 — main 이력 · 머지된 A 없음"
  cleanup
}

# ── N2 회귀 락: 중첩 머지(git-flow)에서 구성원이 넓어지지 않는다 ─────────────────
case_n2_nested_merge_not_expanded() {
  new_repo
  git checkout -q -b develop
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q develop; git merge -q --no-ff -m "merge topicA into develop" topicA
  echo x > x.txt; git add x.txt; git commit -qm "develop x (무관)"
  git checkout -q main; git merge -q --no-ff -m "merge develop" develop
  git branch -q -D topicA
  git checkout -q develop; echo y > y.txt; git add y.txt; git commit -qm "develop y (무관, 머지 뒤)"
  git checkout -q main; git checkout -q -b topicB2; decl_commit b2.txt b2 "b2 — 같은 키 후속"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "N2: status: ok"
  assert_eq "$(field branches "$out")" "topicB2" "N2: 구성원 topicB2 뿐 — develop 은 아니다"
  assert_eq "$(field commits "$out")" "1" "N2: T = topicB2 의 커밋 하나(develop 의 x · y 없음)"
  cleanup
}

# ── 알려진 한계 기록(§15-12): squash 로 든 앞 조각은 ref 가 살아 있으면 여전히 구성원 ──
case_squash_front_still_member() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --squash topicA; git commit -qm "squash topicA"
  git checkout -q -b topicB2; decl_commit b2.txt b2 "b2 — 같은 키 후속"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "squash: status: ok"
  assert_grep "$(field branches "$out")" '(^|,)topicA(,|$)' \
    "squash: 원래 커밋이 base 의 조상이 아니라 topicA 가 여전히 구성원이다(§15-12)"
  assert_eq "$(field in_base "$out")" "0" "squash: 원래 선언 커밋은 base 에 없다(in_base 0)"
  cleanup
}

# ── 옛 2단계(머지된 구성원) 기계가 되살아나지 않는다 — N2 · N3 의 원인 ──────────
case_no_merged_member_machinery() {
  local code; code=$(grep -vE '^[[:space:]]*#' "$RT")
  assert_eq "$(printf '%s\n' "$code" | grep -c -- '--ancestry-path')" "0" "코드에 --ancestry-path 가 없다"
  assert_eq "$(printf '%s\n' "$code" | grep -c 'merged:')" "0" "코드가 merged: 구성원을 만들지 않는다"
  assert_eq "$(printf '%s\n' "$code" | grep -c 'MERGED_MAINLINE')" "0" "머지된 구성원의 fork 보정이 없다"
  # 양의 짝 — 구성원 · 고아 루프가 C_LIVE 를 순회한다
  assert_eq "$(printf '%s\n' "$code" | grep -cE '^[[:space:]]*for c in \$C_LIVE; do$')" "2" \
    "C_LIVE 를 순회하는 루프가 둘(구성원 1단계 · 고아)"
}
```

  그리고 루프 목록에서: `case_f2_boundary_merged_not_hidden` → `case_all_declared_in_base case_orphan_tag_only`, `case_ten_keys_always` → `case_eleven_keys_always` 로 바꾸고, 마지막 줄 `         case_detect_empty_spec_value_excluded; do` 를 아래로 바꾼다:

```bash
         case_detect_empty_spec_value_excluded \
         case_unrelated_after_merge_not_member case_n1_main_history_not_absorbed \
         case_n2_nested_merge_not_expanded case_squash_front_still_member \
         case_no_merged_member_machinery; do
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_boundary.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — F2 · F3 · `case_all_declared_in_base` · 11키 · `in_base` 단언 · 무관 브랜치 · N2 · 부재 락이 `✗`(모의 실행 실측 ✗ 23). `case_n1_main_history_not_absorbed` 는 오늘도 GREEN 이다 — N1 은 기각된 고침의 반례라 회귀 락이고, 이빨은 Task 4 Row 5 가 증명한다. `case_squash_front_still_member` 의 `topicA 가 여전히 구성원` · `status: ok` 은 오늘도 GREEN 이다(옛 규칙도 구성원으로 센다) — `in_base 0` 은 오늘 키가 없어 `✗`. `case_orphan_tag_only` 의 status · reason 은 오늘도 GREEN(옛 3단계) — `in_base` 는 `✗`. 기존 케이스(F1 · F4 · F5 · … · detect)의 `✗` 는 0. RED 수를 실측해 보고에 적는다.

- [ ] **Step 3: 구현한다** — `resolve-topic.sh` 일곱 자리.

  (a) 머리 주석 — `#   resolve <topic-key>   -> key: value 요약 10줄` 를 `#   resolve <topic-key>   -> key: value 요약 11줄` 로. 그리고 `#   status: base-unresolved     base_ref 미해결 — 기준선 축을 세울 수 없다` 줄 **아래**에 두 줄:

```bash
#
#   in_base: 선언 커밋 중 이미 base_ref 의 조상인 수 — 판정 대상이 아니라 기준선이다(AC4 · §6.2.2)
```

  (b) 초기화 — `SEAL_ON_TOPIC="-"` 줄을 `SEAL_ON_TOPIC="-"; IN_BASE="-"` 로.

  (c) `emit()` — 주석의 `10줄이 이미 나간 뒤라` 를 `11줄이 이미 나간 뒤라` 로, `echo "declared: $DECLARED"` 줄 **아래**에 한 줄:

```bash
  echo "in_base: $IN_BASE"
```

  (d) 선언 0 분기 — `[ "$DECLARED" -gt 0 ] || { DECLARED=0; emit no-declaration "no commit carries this topic key"; }` 를 아래로 바꾸고, 그 바로 아래에 `C_live` 블록을 넣는다:

```bash
[ "$DECLARED" -gt 0 ] || { DECLARED=0; IN_BASE=0; emit no-declaration "no commit carries this topic key"; }

# ── C_live = 아직 base_ref 에 안 든 선언 커밋 (§6.2.2 · 재결정 P23 2026-09-27) ──
# base_ref 에 이미 든 선언은 판정 대상이 아니라 기준선이다(AC4). 그것을 구성원 근거로
# 쓰면 그 뒤 base 에서 딴 모든 브랜치가 구성원이 된다. 그 수는 in_base 로 공시한다.
# 조상 검사가 실패(rc 128)하면 «살아 있음» 쪽으로 센다 — 구성원을 넓히는 방향이다.
C_LIVE=""; IN_BASE=0
for c in $C; do
  if git merge-base --is-ancestor "$c" "$BASE_REF" 2>/dev/null; then
    IN_BASE=$((IN_BASE + 1))
  else
    C_LIVE="$C_LIVE $c"
  fi
done
```

  (e) 경로 검사 줄 `[ -e "$repo_root/$path" ] || emit declaration-invalid "declared path does not exist: $path"` **아래**에:

```bash
[ -n "$C_LIVE" ] || emit no-declaration "all declared commits are already in base_ref"
```

  (f) 1단계 — ref 루프 안(두 칸 들여쓰기)의 `  for c in $C; do` — 바로 다음 줄이 `    if git merge-base --is-ancestor "$c" "$tip" …` 인 것 — 를 `  for c in $C_LIVE; do` 로(이 시점 `for c in $C; do` 는 세 곳이다: (d) 의 C_live 블록 · 1단계 · 옛 2단계). 그 블록 위 주석의 `머지 안 된 원격-전용 구성원이 1단계를 통과하지 못하고 2단계(머지된 구성원)도 못 받아` 를 `머지 안 된 원격-전용 구성원이 1단계를 통과하지 못해` 로(뒤 `고아(declaration-invalid)로 떨어진다` 는 그대로 이어진다 — 문장이 자연스러운지 읽어 확인).

  (g) 2단계 — `# ── B_t 2단계: 머지된 구성원 ─…` 줄부터 그 블록의 `done`(바로 다음이 빈 줄과 `# 1·2 가 둘 다 답을 못 낸 선언 커밋은 고아다 (설계 §6.2.2 3단계).`)까지를 아래로 바꾸고, 그 고아 주석 줄(`# 1·2 가 둘 다 …`)은 지운다(새 블록 헤더가 대신한다):

```bash
# ── 고아 — C_live 원소가 1단계의 어느 ref 에도 없다 (§6.2.2 3단계) ──────────────
# 머지된 구성원(옛 2단계)은 없다 — base 에 든 선언은 기준선이다(재결정 P23 2026-09-27).
ORPHANS=""
for c in $C_LIVE; do
  in_bt=no
  for tip in $BR_TIPS; do
    git merge-base --is-ancestor "$c" "$tip" 2>/dev/null && { in_bt=yes; break; }
  done
  [ "$in_bt" = yes ] || ORPHANS="$ORPHANS $c"
done
```

  (h) 경계 — `# ── 경계 = fork 들의 merge-base (§6.2.3 · AC5) ─…` 줄부터 `FORKS="$FORKS $f"` 다음의 `done` 까지를 아래로 바꾼다(그 아래 `FORKS=$(printf …sort -u …)` 부터는 그대로):

```bash
# ── 경계 = fork 들의 merge-base (§6.2.3 · AC5) ─────────────────────────────
# 구성원은 전부 base_ref 의 조상이 아닌 살아 있는 ref 다 — fork(b) = merge-base(base_ref, b).
# 머지된 구성원의 fork 보정은 없다(재결정 P23 2026-09-27 — 옛 분기점이 경계가 되면 그 뒤
# base 이력이 리뷰 대상에 흡수된다).
FORKS=""
for tip in $BR_TIPS; do
  f=$(git merge-base "$BASE_REF" "$tip" 2>/dev/null)
  [ -n "$f" ] || emit base-unresolved "cannot compute fork for ${tip}"
  FORKS="$FORKS $f"
done
```

  (i) 옛 규칙을 적은 문면 둘 — 고아 사유 `orphan declaration commit (no containing branch, no merge): …` 의 괄호를 `(no containing branch)` 로(머지 탐색은 더 없다). 머리 주석 `#   status: no-declaration      선언 0 — 기존 세 모드로 fallback (판정 아님)` 을 `#   status: no-declaration      선언 0 · 또는 선언이 전부 base_ref 에 있다 — 기존 세 모드로 fallback (판정 아님)` 으로.

  구현 뒤 `resolve-topic.sh` 에 `MERGED_MAINLINE` · `--ancestry-path` · `merged:` 가 주석 밖에 남지 않아야 한다(`grep -vE '^[[:space:]]*#' … | grep -c …` 셋 다 0).

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/resolve-topic.sh
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | grep -E '✗|Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_seal_no_side_effects.sh 2>&1 | tail -1
bash plugins/quality-gates/scripts/resolve-topic.sh resolve 'docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4b' | sed -n '2,6p'
```

  **기대** — `Fail: 0` 둘. 마지막 명령(실제 리포, 전부 머지된 키)은 `status: no-declaration` · `reason: all declared commits are already in base_ref` · `declared: <N>` · `in_base: <N>`(두 수가 같다) · `branches: -`. `test_topic_head.sh` 는 이 Task 에서 `fixed_keys` 12 단언이 그대로라 여전히 GREEN 이어야 한다(`topic-head.sh` 는 아직 12키를 낸다) — 돌려 확인한다: `PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'`. 단 `case_merged_member_combined` 는 새 규칙에서 RED 가 된다(`merged:` · A 의 파일 · A 의 커밋) — Task 2 가 그 케이스를 고쳐 쓴다. 그 케이스의 `✗` 만 있는지 확인하고 보고한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/resolve-topic.sh plugins/quality-gates/tests/test_topic_boundary.sh
git commit -m "feat(qg): 토픽 구성원 근거를 아직 base 에 안 든 선언으로 — 머지된 구성원 단계 삭제 · in_base" \
  -m "resolve-topic.sh 가 선언 커밋 중 base_ref 에 이미 든 것을 구성원 근거에서 빼고 그 수를 in_base 로 낸다(11키). 머지된 구성원(merged:) 도출과 그 분기점 보정을 지운다 — 머지 뒤 main 이력 흡수 · 중첩 머지 확대 · 이차 비용의 원인이다. 선언이 전부 base 에 있으면 no-declaration." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4d
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 2: `in_base` 튜플 — `topic-head.sh` 13키 · `scope_tuple.py` 13키

**Files:**
- Modify: `plugins/quality-gates/scripts/topic-head.sh` · `plugins/quality-gates/scripts/scope_tuple.py`
- Test: `plugins/quality-gates/tests/test_topic_head.sh` · `plugins/quality-gates/tests/test_scope_tuple.sh`

**Interfaces:**
- Consumes: `resolve-topic.sh resolve` 의 `in_base:`(Task 1).
- Produces: `topic-head.sh` → 고정 13키(순서 `topic_key · status · reason · branches · in_base · boundary · tips · seal · seal_on_topic · tree · head_commit · conflicts · commits`) + `commit:` 줄. `in_base` 는 `resolve` 를 부르기 전에 끝나면 `-`, 그 뒤면 `resolve` 의 값(빈 값이면 `-`). `resolve` 의 `no-declaration` 은 `declaration-invalid` 로, reason 은 `resolve` 의 것을 그대로. `scope_tuple.KEYS`(13, 같은 순서) · `in_base` 검증: `-` 또는 `[0-9]+`(fullmatch), `status: ok` 면 수여야 한다(아니면 fail4) · `scope:` 블록에서 `branches` 다음 줄 `  in_base: <값>`.
  이 둘은 **한 커밋**이다 — 한쪽만 바뀌면 실제 파이프라인에서 합성기 `--scope` 가 fail4(모르는 키 · 빠진 키)로 멈춘다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

  (a) `test_topic_head.sh` — `fixed_keys` 단언의 `"12"` 셋을 `"13"` 으로, 그 메시지의 `고정 키 12줄` 을 `고정 키 13줄` 로(`grep -n 'fixed_keys "\$out")" "12"'` 로 셋을 찾는다). `case_no_declaration` 의 `commit: 줄 없음` 단언 **아래**에 `assert_eq "$(field in_base "$out")" "-" "선언 없음: in_base: -(resolve 전에 끝남)"` 를, `case_single_branch_topic` 의 `본 커밋 SHA 가 commit: 줄로 실린다(AC15)` 단언 **아래**에 두 줄을 더한다:

```bash
  assert_eq "$(field in_base "$out")" "0" "단일 구성원: in_base 0"
  assert_eq "$(printf '%s\n' "$out" | sed -n '5p')" "in_base: 0" "다섯째 줄이 in_base(13키 순서 — branches 다음)"
```

  (b) `test_topic_head.sh` — `case_merged_member_combined` 정의 전체를 아래 둘로 바꾸고, 루프 목록의 `case_merged_member_combined` 를 `case_merged_member_is_baseline case_stack_after_front_merged` 로 바꾼다:

```bash
case_merged_member_is_baseline() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local CA; CA=$(git rev-parse HEAD)
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git branch -q -D topicA
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$TH" "$SID")
  assert_eq "$(field status "$out")" "ok" "머지된 앞 조각: status: ok"
  assert_eq "$(field in_base "$out")" "1" "머지된 앞 조각의 선언이 in_base 로 공시된다(AC4 재정의)"
  assert_eq "$(field branches "$out")" "topicB" "구성원은 topicB 뿐 — 머지된 topicA 는 기준선"
  assert_not_grep "$(commit_lines "$out")" "^$CA\$" "머지된 앞 조각의 커밋은 본 커밋이 아니다"
  assert_grep "$(commit_lines "$out")" '^[0-9a-f]{40}$' "본 커밋은 있다(양의 짝 — topicB 의 커밋)"
  assert_eq "$(field boundary "$out")" "$R" "경계 = topicB 의 분기점"
  assert_eq "$(fixed_keys "$out")" "13" "고정 키 13줄"
  cleanup
}

case_stack_after_front_merged() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q -b topicB; decl_commit b.txt b1 "b1 — A 위에 쌓음"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q topicB
  local out T B0; out=$(bash "$TH" "$SID"); T=$(field tree "$out"); B0=$(field boundary "$out")
  assert_eq "$(field status "$out")" "ok" "스택 앞 조각 머지 뒤: status: ok"
  assert_eq "$B0" "$TIPA" "경계 = topicA 의 끝(= topicB 와 main 의 merge-base)"
  assert_eq "$(git diff --name-only "$B0" "$T")" "b.txt" "리뷰 diff 는 b.txt 뿐 — 머지된 A 는 기준선"
  assert_grep "$(git ls-tree -r --name-only "$T")" '^a\.txt$' "합친 트리에는 A 의 파일이 있다(topicB 가 담고 있다)"
  assert_eq "$(field in_base "$out")" "1" "in_base 1"
  cleanup
}
```

  (c) `test_topic_head.sh` — `for c in …` **앞**에 케이스 하나, 루프 목록 마지막 줄 `         case_create_head_topic_rejects_conflicted_topic case_create_head_usage; do` 를 `         case_create_head_topic_rejects_conflicted_topic case_create_head_usage \` 와 다음 줄 `         case_explicit_topic_fully_merged; do` 로:

```bash
case_explicit_topic_fully_merged() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q -b later; echo l > l.txt; git add l.txt; git commit -qm "later (선언 없음)"
  local out rc; out=$(bash "$TH" "$SID" --topic "$KEY"); rc=$?
  assert_eq "$rc" "0" "전부 머지된 키를 --topic 으로: exit 0(사용 오류가 아니다)"
  assert_eq "$(field status "$out")" "declaration-invalid" "전부 머지된 키를 --topic 으로: declaration-invalid"
  assert_grep "$(field reason "$out")" 'already in base_ref' "reason 이 resolve 의 사유를 그대로 싣는다"
  assert_eq "$(field in_base "$out")" "1" "in_base 1"
  assert_eq "$(fixed_keys "$out")" "13" "고정 키 13줄"
  cleanup
}
```

  (d) `test_scope_tuple.sh` 세 자리 — `write_scope` 의 두 번째 `printf` 를 `printf 'branches: topicA,topicB\nin_base: 1\nboundary: %s\ntips: %s,%s\nseal: %s\nseal_on_topic: yes\n' "$B" "$C1" "$S" "$S"` 로, `write_undeclared` 의 `branches: -\n` 을 `branches: -\nin_base: -\n` 로, `PY_LS` 의 `base` 첫 줄 끝 `branches: -\n"` 을 `branches: -\nin_base: -\n"` 로.

  (e) `test_scope_tuple.sh` — `for c in …` **앞**에 케이스 하나, 루프 목록 마지막 줄 `         case_scope_flag_usage_errors case_line_separator_in_value_is_kept; do` 를 `         case_scope_flag_usage_errors case_line_separator_in_value_is_kept \` 와 다음 줄 `         case_in_base_disclosed_and_validated; do` 로:

```bash
case_in_base_disclosed_and_validated() {
  # AC4 재정의 — 판정에서 빠진 머지된 앞 조각의 수가 scope: 블록에 실린다.
  setup_clean_run
  write_scope "$T/scope.txt" ok - "$TR" "$HC" - 2 "$C1" "$C2"
  local out rc; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/scope.txt")
  assert_grep "$out" '^  in_base: 1$' "scope: 블록에 in_base 가 실린다"
  local lb li; lb=$(line_of "$out" '^  branches: '); li=$(line_of "$out" '^  in_base: ')
  assert_eq "$([ -n "$lb" ] && [ -n "$li" ] && [ "$li" -eq $((lb + 1)) ] && echo next)" "next" "in_base 는 branches 바로 다음 줄"
  sed 's/^in_base: 1$/in_base: 1x/' "$T/scope.txt" > "$T/bad.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "in_base 가 수 · - 가 아니면 exit 4(1x — fullmatch)"
  assert_eq "$out" "" "그때 stdout 비어 있음"
  # status 가 ok 가 아니어도 형식 검사가 선다 — ok 블록 검사가 대신 잡지 못하는 자리
  write_undeclared "$T/u2.txt" no-declaration
  sed 's/^in_base: -$/in_base: 1x/' "$T/u2.txt" > "$T/bad3.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad3.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "status 가 ok 가 아니어도 in_base 가 수 · - 가 아니면 exit 4"
  sed 's/^in_base: 1$/in_base: -/' "$T/scope.txt" > "$T/bad2.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/bad2.txt" 2>/dev/null); rc=$?
  assert_eq "$rc" "4" "status: ok 인데 in_base 가 - 면 exit 4"
  write_undeclared "$T/u.txt" no-declaration
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --scope "$T/u.txt"); rc=$?
  assert_eq "$rc" "0" "선언 없음의 in_base: - 는 받는다(양의 짝)"
  assert_grep "$out" '^  in_base: -$' "선언 없음: in_base: - 가 공시된다"
  rm -rf "$T"
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_head.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
bash -n plugins/quality-gates/tests/test_scope_tuple.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_scope_tuple.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — `test_topic_head.sh`: 13키 · `in_base` 단언과 새 케이스의 `in_base` · 13키 단언이 `✗`(Task 1 뒤라 구성원 · 경계 · diff 단언은 이미 GREEN 일 수 있다 — 실측 수를 적는다). `case_explicit_topic_fully_merged` 의 reason 단언은 오늘 `topic-head.sh` 가 고정 문구를 내서 `✗`. `test_scope_tuple.sh`: 헬퍼가 `in_base` 를 쓰므로 `KEYS` 밖 키로 거의 전 케이스가 fail4 → `✗` 다수(모의 실행 실측 topic_head ✗11 · scope_tuple ✗36). 음의 exit-4 단언(잘못된 `in_base` · ok 인데 `-`)은 구현 전에도 GREEN 이다(모르는 키 fail4 가 공허하게 만족시킨다) — 이빨은 Task 4 Row 9 · 10 이 증명한다.

- [ ] **Step 3: 구현한다**

  (a) `topic-head.sh` 다섯 자리.
  - 머리 주석 `-> key: value 12줄 + commit: N줄` 을 `-> key: value 13줄 + commit: N줄` 로. 같은 머리 주석의 `#   declaration-invalid  선언이 깨졌다 (경로 부재 · 한 브랜치에 여러 키 · 고아)` 의 괄호 끝에 ` · 키의 선언이 전부 base 에 있음(--topic)` 을 더한다.
  - 초기화 `BRANCHES="-"; BOUNDARY="-"; TIPS="-"; SEAL="-"; SEAL_ON_TOPIC="-"` 를 `BRANCHES="-"; IN_BASE="-"; BOUNDARY="-"; TIPS="-"; SEAL="-"; SEAL_ON_TOPIC="-"` 로.
  - `emit()` 의 `echo "branches: $BRANCHES"` **아래**에 `echo "in_base: $IN_BASE"`.
  - `SEAL_ON_TOPIC=$(val seal_on_topic "$r")` **아래**에:

```bash
IN_BASE=$(val in_base "$r"); [ -n "$IN_BASE" ] || IN_BASE="-"
```

  - `no-declaration) emit declaration-invalid "no commit carries this topic key" ;;` 를 `no-declaration) emit declaration-invalid "$(val reason "$r")" ;;` 로(선언 0 이면 `resolve` 가 같은 문구 「no commit carries this topic key」를 낸다).

  (b) `scope_tuple.py` 네 자리.
  - docstring 의 `(AC15). 끝점 합치기가 충돌하면 충돌 파일을 싣는다(AC7).` 뒤(같은 문단 끝)에 한 문장: ` 그 키의 선언 중 이미 base 에 든 수(`in_base`)를 싣는다 — 판정 대상에서 빠진 머지된 앞 조각이다(AC4).` — 줄 폭 약 80 에서 줄을 나눈다.
  - `KEYS` 를:

```python
KEYS = ("topic_key", "status", "reason", "branches", "in_base", "boundary", "tips",
        "seal", "seal_on_topic", "tree", "head_commit", "conflicts", "commits")
```

  - `_RENDER_ORDER` 를:

```python
_RENDER_ORDER = ("topic_key", "reason", "branches", "in_base", "boundary", "tips", "tree",
                 "seal_on_topic", "conflicts")
```

  - `parse()` — `elif not _COUNT.fullmatch(seen["commits"]) or …` 두 줄(`fail4(f"commits: …` 까지) **아래**, `if seen["status"] == "ok":` **위**에:

```python
    if seen["in_base"] != "-" and not _COUNT.fullmatch(seen["in_base"]):
        fail4(f"in_base 가 수 또는 - 가 아니다: {seen['in_base']!r}")
```

    그리고 `if seen["status"] == "ok":` 블록의 `if seen["commits"] == "-":` 두 줄 **아래**에(같은 들여쓰기):

```python
        if not _COUNT.fullmatch(seen["in_base"]):
            fail4(f"status: ok 인데 in_base 가 수가 아니다: {seen['in_base']!r}")
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/topic-head.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile plugins/quality-gates/scripts/scope_tuple.py
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_scope_tuple.sh 2>&1 | grep -E '✗|Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_qg_objects_unreachable.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | tail -1
```

  **기대** — 전부 `Fail: 0`. `test_topic_scope_wiring.sh` 의 상태 표 락은 `scope_tuple.STATUSES` 에서 도출하므로 영향이 없어야 한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/topic-head.sh plugins/quality-gates/scripts/scope_tuple.py \
        plugins/quality-gates/tests/test_topic_head.sh plugins/quality-gates/tests/test_scope_tuple.sh
git commit -m "feat(qg): 스코프 튜플에 in_base — topic-head · scope_tuple 13키 · scope: 블록 공시" \
  -m "머지된 앞 조각의 선언 수(in_base)가 topic-head.sh 튜플과 합성기 scope: 블록에 실린다. status: ok 면 수여야 하고, 그 밖은 수 또는 - 다. 전부 머지된 키를 --topic 으로 주면 resolve 의 사유를 그대로 싣는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4d
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 3: SKILL 공지 · README

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/README.md` · `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`(한 곳)
- Test: `plugins/quality-gates/tests/test_topic_scope_wiring.sh`

**Interfaces:**
- Consumes: 스코프 파일의 `in_base:`(Task 2).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_topic_scope_wiring.sh` 의 `for c in …` **앞**에 케이스 하나, 루프 목록 마지막 줄 `         case_override_clears_stale_scope_file; do` 를 `         case_override_clears_stale_scope_file case_in_base_notice; do` 로:

```bash
case_in_base_notice() {
  # AC4 재정의 — 머지된 앞 조각이 이번 판정에서 빠졌다는 사실을 ① 1a 가 공지한다(같은 줄).
  # 1a 창(「**1a — 토픽 선언」 ~ 「**session 스코프**」) 안에서만 찾는다 — 다른 절로 옮기면 RED.
  local win got
  win=$(awk '/\*\*1a — 토픽 선언/{f=1} /\*\*session 스코프\*\*/{f=0} f' "$SKILL")
  got=$(printf '%s\n' "$win" | grep -F '`in_base:`' | grep -F '기준선에 포함됐다' | grep -F '판정 대상이 아니다')
  assert_eq "$(printf '%s\n' "$got" | grep -c .)" "1" "① 1a 창에 in_base 공지가 한 줄 있다"
  assert_grep "$got" '^[[:space:]]*`status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `> \[quality-gates\] 토픽 ' \
    "조건(status ok · in_base > 0)과 목적지(공지 한 줄: …)가 같은 줄의 긍정형이다"
  assert_not_grep "$got" '않|말 것|생략|아니고' "그 줄에 부정 · 반전 토큰이 없다(「판정 대상이 아니다」는 위에서 따로 잰다)"
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_scope_wiring.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — 새 케이스의 두 단언이 `✗`(1a 창 개수 · 긍정형 조건+목적지), 부정 토큰 단언은 빈 입력이라 GREEN(이빨은 Task 4 Row 11 · 13 · 14 가 증명한다 — 계획 작성 시 복사본에서 현재 문면 67/67 GREEN · 변이 13 · 14 · 15 RED 확인).

- [ ] **Step 3: 구현한다**

  (a) SKILL.md — ① 1a 의 공지 한 줄 문단(`   공지 한 줄: \`> [quality-gates] 토픽 선언을 이번 iteration 에 쓰지 못했다 (<status>: <reason 값>) — session 스코프로 진행한다.\``) **아래**에 빈 줄 하나와 한 줄(들여쓰기 세 칸, 한 줄로):

```markdown
   `status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `> [quality-gates] 토픽 <topic_key> 의 선언 커밋 <in_base>개는 이미 base 에 있어 기준선에 포함됐다 — 이번 판정 대상이 아니다.`
```

  (b) README.md 「토픽 스코프 — `Spec:` 트레일러」 절 세 자리.
  - `한 작업이 브랜치 여럿(스택 · 형제 · 이미 머지된 앞 브랜치)에 걸치면, 커밋에` 를 `한 작업이 브랜치 여럿(스택 · 형제)에 걸치면, 커밋에` 로.
  - `커밋에서 그 키를 찾고, 같은 키를 단 브랜치 전부(원격-추적 · 머지된 구성원 포함)를 한 판정` ⏎ `단위로 본다:` 두 줄을 아래 세 줄로:

```markdown
커밋에서 그 키를 찾고, 같은 키를 단 브랜치 중 아직 base 에 머지되지 않은 것 전부(원격-추적
포함)를 한 판정 단위로 본다. 같은 키로 이미 base 에 머지된 앞 조각은 기준선에 든다 — 그 조각은
자기 PR 에서 판정됐다 — 그 선언 커밋 수가 `scope:` 블록의 `in_base:` 에 보인다:
```

  - `- **판정 꼬리의 \`scope:\` 블록** — 본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID. \`clean\` 은 이` 의 `합친 트리 OID.` 를 `합친 트리 OID · \`in_base\`.` 로.

  (c) README.md 「알려진 한계」 — `- 같은 키를 여러 브랜치에 걸쳐 쓰는 토픽에서 앞 브랜치가 먼저 머지되면 그 변경이 기준선에 숨고,` 로 시작하는 항목(세 줄, `…(\`…#pr1\` · \`…#pr2\`)를 쓰면 생기지 않는다.` 까지)을 아래로:

```markdown
- 같은 키의 앞 조각을 squash · rebase-merge · cherry-pick 으로 base 에 넣고 그 브랜치 ref 를 남겨
  두면 원래 커밋이 base 의 조상이 아니라서 여전히 구성원이다 — 이미 들어간 변경을 다시 본다.
  머지한 브랜치는 지운다.
```

  그 바로 아래에 한 항목을 더한다(로컬-전용 머지는 옛 규칙과 같은 동작 — 공시):

```markdown
- base 는 `base_ref`(보통 `origin/main`)다 — 같은 키의 앞 조각을 로컬 `main` 에만 머지하고 fetch
  전이면 그 조각은 아직 기준선이 아니어서, 로컬 `main` 과 그 뒤 딴 브랜치가 구성원으로 잡힌다.
  머지는 원격에서 하고 fetch 한 뒤 돌린다.
```

  그리고 같은 목록의 `- \`resolve\` 비용이 ref 수 × 선언 커밋 수에 비례한다` 의 `선언 커밋 수` 를 `아직 base 에 안 든 선언 커밋 수` 로.

  (d) `references/differential-test.md` 한 곳(범위 불변식의 유일한 예외) — `로 잡으므로 형제 · 머지된 구성원의 변경을 모른다.` 를 `로 잡으므로 형제 구성원의 변경을 모른다.` 로(머지된 구성원은 더 없다 — 머지된 앞 조각은 기준선이다).

- [ ] **Step 4: 통과를 확인한다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
for f in test_one_pipeline_surface test_pipeline_verdict_wiring test_readme_scope_reconcile test_readme_state_diagram_complete; do PYTHONDONTWRITEBYTECODE=1 bash "plugins/quality-gates/tests/$f.sh" 2>&1 | tail -1; done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_a20_tool_agnostic_scope.py 2>&1 | tail -2
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u | comm -13 "$CLAUDE_JOB_DIR/tmp/pr4d-baseline-harness-fails.txt" -
git grep -n -E '머지된 구성원|merged:' -- plugins/quality-gates ':!plugins/quality-gates/CHANGELOG.md' ':!plugins/quality-gates/tests/test_topic_boundary.sh'
```

  **기대** — 새 락 `Fail: 0` · 넷 기준선 그대로 · A20 `OK` · 루트 락 기준선 그대로 · 하네스 비교 빈 출력. 마지막 grep(개념 별칭 스윕)에 남는 것은 `resolve-topic.sh` 의 재결정 주석(「머지된 구성원(옛 2단계)은 없다」 · 「머지된 구성원의 fork 보정은 없다」)뿐이다 — 그 밖의 줄이 나오면 그 문면을 새 규칙에 맞춘다(범위 불변식 밖이면 고치고, 안이면 멈추고 보고). `for` 줄이 가드에 막히면 넷을 한 줄씩 돌린다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/tests/test_topic_scope_wiring.sh \
        plugins/quality-gates/skills/quality-pipeline/references/differential-test.md
git commit -m "docs(qg): in_base 공지 · README 토픽 스코프 — 머지된 앞 조각은 기준선" \
  -m "① 1a 가 in_base 가 0 보다 크면 머지된 앞 조각이 이번 판정 대상이 아님을 공지한다. README 의 토픽 스코프 절과 알려진 한계를 새 구성원 규칙에 맞추고 squash 한계를 적는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4d
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 4: 변이 — 락 이빨

**Files:**
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr4d-mutations.md` → 미러

- [ ] **Step 1: 변이를 태운다** — 행마다 ① 변이를 적용하고 `git diff --stat` 이 **비어 있지 않음**을 확인 ② 지목 락을 `PYTHONDONTWRITEBYTECODE=1` 로 돌려 기대한 단언이 `✗` 인지 ③ `git checkout HEAD -- <파일>` 후 `git diff HEAD --stat` 빈 출력. 사본(`mktemp -d` + `git archive HEAD | tar -x -C …`)에서 해도 된다(그때 락은 사본 경로로 돈다). 편집은 `Edit` 도구로. 결과를 표로 `$CLAUDE_JOB_DIR/tmp/pr4d-mutations.md` 에 쓰고 미러로 복사한다.

| # | 축 | 변이 | 지목 락 · 기대 `✗` |
|---|---|---|---|
| 1 | 변형 | `resolve-topic.sh` 1단계 루프의 `for c in $C_LIVE; do` → `for c in $C; do` | `test_topic_boundary.sh` — `case_unrelated_after_merge_not_member` 구성원 · N2 구성원 · 부재 락 양의 짝(F2 · F3 은 topicA tip 이 base 의 조상이라 ref 스캔 첫 검사가 먼저 빼 이 변이로 안 갈린다) |
| 2 | 삭제 | `C_live` 블록의 `if … is-ancestor … then IN_BASE=… else C_LIVE=… fi` 를 `C_LIVE="$C_LIVE $c"` 한 줄로(분류 없이 전부 살아 있음) | 같은 락 — `in_base 1` 단언들 · F2 구성원 |
| 3 | 변형 | `IN_BASE=$((IN_BASE + 1))` → `:` | 같은 락 — `in_base 1` 단언들 |
| 4 | 삭제 | `[ -n "$C_LIVE" ] \|\| emit no-declaration …` 줄 삭제 | 같은 락 — `case_all_declared_in_base` |
| 5 | 변형 | 경계 루프의 `f=$(git merge-base "$BASE_REF" "$tip" 2>/dev/null)` → `f=$(git merge-base "$BASE_REF~5" "$tip" 2>/dev/null)`(더 옛 지점을 경계로 — 옛 분기점 경계의 흉내) | 같은 락 — N1 `경계 = 방금 최신화한 main`(다른 케이스도 RED 일 수 있다 — N1 의 지목 단언이 RED 인지를 본다) |
| 6 | 변형 | `topic-head.sh` 의 `IN_BASE=$(val in_base "$r"); …` 줄 삭제 | `test_topic_head.sh` — `in_base 1` 단언들 |
| 7 | 변형 | `topic-head.sh` 의 `no-declaration) emit declaration-invalid "$(val reason "$r")"` → 고정 문구 `"no commit carries this topic key"` | 같은 락 — `reason 이 resolve 의 사유를 그대로` |
| 8 | 삭제 | `scope_tuple.py` `_RENDER_ORDER` 의 `"in_base", ` | `test_scope_tuple.sh` — `scope: 블록에 in_base 가 실린다` |
| 9 | 삭제 | `scope_tuple.py` 의 ok 블록 `if not _COUNT.fullmatch(seen["in_base"]):` 두 줄 | 같은 락 — `status: ok 인데 in_base 가 - 면 exit 4` |
| 10 | 삭제 | `scope_tuple.py` 의 `if seen["in_base"] != "-" and not _COUNT…` 두 줄 | 같은 락 — `status 가 ok 가 아니어도 in_base 가 수 · - 가 아니면 exit 4`(ok 쪽 단언은 ok 블록 검사가 대신 잡아 GREEN 일 수 있다) |
| 11 | 부정 | SKILL 공지 줄의 `공지 한 줄:` 을 `공지하지 않는다 —` 로(나머지 그대로) | `test_topic_scope_wiring.sh` — 긍정형 조건 · 목적지 단언 · `부정 · 반전 토큰이 없다` |
| 12 | 추가 | `resolve-topic.sh` 에 옛 2단계 한 줄 `m=$(git rev-list --ancestry-path --merges "$c..$BASE_REF" 2>/dev/null \| tail -1)` 을 고아 루프 안에 되살림(주석 아님) | `test_topic_boundary.sh` — `--ancestry-path 가 없다` |
| 13 | 반전 | SKILL 공지 줄의 `` `status: ok` 이고 `` → `` `status: ok` 가 아니고 `` | `test_topic_scope_wiring.sh` — 긍정형 조건 · 목적지 단언 |
| 14 | 부정 | SKILL 공지 줄의 `공지 한 줄:` → `공지 한 줄을 내지 않는다:` | 같은 락 — 긍정형 단언 · 부정 토큰 단언 |
| 15 | 이동 | SKILL 공지 줄을 ① 1a 창 밖(예: Final Summary 절 끝)으로 옮김 | 같은 락 — `① 1a 창에 in_base 공지가 한 줄 있다` |
| 16 | 변형 | `scope_tuple.py` 의 두 `_COUNT.fullmatch(seen["in_base"])` → `_COUNT.match(seen["in_base"])` | `test_scope_tuple.sh` — `1x — fullmatch` · `status 가 ok 가 아니어도 …` |
| 17 | 이동 | `topic-head.sh` `emit()` 의 `echo "in_base: $IN_BASE"` 를 `echo "conflicts: …"` 뒤로 | `test_topic_head.sh` — `다섯째 줄이 in_base` |

  **양성 대조** — 변이 전 · 모든 복원 뒤에 `test_topic_boundary.sh` · `test_topic_head.sh` · `test_scope_tuple.sh` · `test_topic_scope_wiring.sh` · `test_qg_objects_unreachable.sh` 가 `Fail: 0`.

- [ ] **Step 2: 구멍을 닫는다** — 기대한 `✗` 가 안 난 행마다 락에 단언을 더하거나 좁혀 RED 로 만들고 같은 변이를 다시 태워 확인 · 커밋한다(제품 문면은 바꾸지 않는다). 수정 라운드는 **둘까지** — 셋째 생존이 같은 자리에서 새로 나면 층위 신호로 보고 멈추고 원장에 적는다.

---

### Task 5: 회귀 · 범위 불변식 · bump · CHANGELOG · PR

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(`version` 만) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(제목 버전) · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`(제목 버전)

- [ ] **Step 1: 도출 집합 회귀 — 기준선과 행 단위로** (프로세스 치환이 가드에 막히면 `$CLAUDE_JOB_DIR/tmp/` 스크립트로)

```bash
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4d-final.tsv"
join -t $'\t' -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 \
  <(sort "$CLAUDE_JOB_DIR/tmp/pr4d-baseline.tsv") <(sort "$CLAUDE_JOB_DIR/tmp/pr4d-final.tsv") \
  | awk -F'\t' '$2 != $4 || $3 != $5'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u > "$CLAUDE_JOB_DIR/tmp/pr4d-final-harness-fails.txt"
comm -13 "$CLAUDE_JOB_DIR/tmp/pr4d-baseline-harness-fails.txt" "$CLAUDE_JOB_DIR/tmp/pr4d-final-harness-fails.txt"
```

  **기대** — `join` 출력 **빈 출력**(새 테스트 파일이 없다 — 기존 파일의 rc · 실패 줄 수가 하나도 안 바뀐다). `join` 이 낸 행이 기준선 쪽 플래키 파일이면 단독 재실행 결과를 적고 회귀로 세지 않는다. 최종 쪽이 RED 인 행은 단독 재실행 후에도 RED 면 회귀다. unittest `Ran 197` OK. 하네스 `comm -13` 빈 출력.

- [ ] **Step 2: 범위 불변식**

```bash
git diff --stat origin/main...HEAD -- shared plugins/spec-distill plugins/plugin-audit .claude-plugin/marketplace.json CLAUDE.md \
  plugins/quality-gates/agents plugins/quality-gates/skills/quality-pipeline/references tools \
  plugins/quality-gates/scripts/seal-worktree.sh plugins/quality-gates/scripts/combine-tips.sh \
  plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/scripts/synthesize_findings.py \
  plugins/quality-gates/scripts/verdict.py plugins/quality-gates/scripts/angles.py \
  plugins/quality-gates/scripts/recritic_bridge.py plugins/quality-gates/scripts/run-test-selection.sh \
  plugins/quality-gates/scripts/qg-gc.py plugins/quality-gates/scripts/gc_common.py
git diff --stat origin/main...HEAD -- docs/superpowers/specs
git diff origin/main...HEAD -- plugins/quality-gates/.claude-plugin/plugin.json
```

  **기대** — 첫 명령은 `references/differential-test.md` 한 파일 · 1줄 변경뿐(Task 3 (d) — 범위 불변식의 유일한 예외, `git diff origin/main...HEAD -- plugins/quality-gates/skills/quality-pipeline/references` 로 그 한 줄인지 본다). 둘째는 설계 재결정 커밋 한 파일(이 계획 앞의 커밋)뿐. `plugin.json` 은 `version` 한 줄만(Step 3 뒤).

- [ ] **Step 3: 머지 직전 동기화 · 버전을 정한다**

```bash
git fetch origin --quiet
git rev-list --count HEAD..origin/main
git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json | grep '"version"'
```

  `origin/main` 이 움직였으면 **merge 한다**(rebase 금지): `git merge --no-edit origin/main` — 충돌이 없어도 `plugin.json` · `CHANGELOG.md` · SKILL 을 눈으로 본다. 머지 뒤 Step 1 을 다시 돈다. 버전 = `origin/main` 의 qg minor + 1 `.0`(오늘 9.1.0 → **9.2.0**). 세 자리를 같은 값으로: `plugin.json` `"version"` · `skills/quality-pipeline/SKILL.md` 제목 · `skills/publishing-pr-understanding/SKILL.md` 제목의 `(vX.Y.Z)`.

- [ ] **Step 4: CHANGELOG** — `plugins/quality-gates/CHANGELOG.md` 의 `## [9.1.0] — 2026-09-27` **위**에(Korean-primary — `check-changelog-korean-primary.py` 는 1.32.0 절 전용이라 새 절은 눈으로 판정한다):

```markdown
## [<정한 버전>] — <오늘 날짜>

**토픽 구성원 규칙 재결정** — 같은 `Spec:` 키의 앞 조각이 이미 base 에 머지됐으면 그 조각은 판정 대상이 아니라 기준선이다. 그 선언 커밋 수를 `scope:` 블록의 `in_base` 로 공시한다.

### Changed
- `resolve-topic.sh` 가 구성원 근거를 아직 `base_ref` 에 안 든 선언 커밋으로 좁힌다 — `base_ref` 에 든 앞 조각이 기준선에 숨던 결함과 그 뒤 base 에서 딴 무관한 브랜치가 구성원이 되던 결함(9.1.0 알려진 한계)이 함께 사라진다. 앞 조각이 로컬 `main` 에만 머지돼 fetch 전이면 아직 기준선이 아니다(README 알려진 한계).
- 머지된 구성원(`merged:`) 도출과 그 분기점 보정을 지운다 — 옛 분기점이 경계가 되어 그 뒤 main 이력이 리뷰 대상에 흡수되는 경로, 중첩 머지에서 구성원이 넓어지는 경로, 이력 길이에 따라 이차로 느는 비용이 없어진다.
- 키의 선언이 전부 base 에 있으면 `resolve` 는 `no-declaration`(`all declared commits are already in base_ref`)이고, `--topic` 으로 그 키를 주면 `topic-head.sh` 는 그 사유를 실은 `declaration-invalid` 다.

### Added
- 스코프 튜플의 `in_base` — `resolve-topic.sh resolve` 11키 · `topic-head.sh` 13키 · `scope_tuple.py` 13키 · `scope:` 블록 한 줄. SKILL ① 은 `in_base` 가 0 보다 크면 공지 한 줄을 낸다.
- 회귀 락 — 머지 뒤 main 이력 비흡수 · 중첩 머지 비확대 · 무관 브랜치 비구성원 · 옛 머지된-구성원 코드 부재 · squash 한계 기록.
```

- [ ] **Step 5: 커밋 · 미러 · push · PR**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md
git status --short
git commit -m "chore(qg): quality-gates <정한 버전> — 토픽 구성원 규칙 재결정" \
  -m "같은 키의 앞 조각이 base 에 머지됐으면 기준선으로 두고 그 수를 in_base 로 공시한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr4d
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
bash "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr4d-final.tsv"
cp "$CLAUDE_JOB_DIR"/tmp/pr4d-final* ~/.claude/sdd-mirror/qg-topic-membership-pr4d/
git push -u origin feature/qg-topic-membership-pr4d
```

  PR 본문(`$CLAUDE_JOB_DIR/tmp/pr4d-body.md`, 미러에도): 요약(버전 · 한 문단) · **사용자가 뒤집을 수 있는 자리**(AC4 재정의 — 사용자가 2026-09-27 선택지 셋 중 「머지된 조각은 기준선」을 골랐다 · squash 한계) · 이 PR 이 지는 것 · 끝에서 끝 흐름 · 선재 RED(착수 · 종료) · 변이 표 · 검증 과정(SDD 원장의 `Ruling:` 전부) · 마지막 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. PR 생성:

```bash
gh pr create --base main --head feature/qg-topic-membership-pr4d \
  --title "feat(qg): 토픽 구성원 규칙 재결정 — 머지된 앞 조각은 기준선 · in_base (PR4d)" \
  --body-file "$CLAUDE_JOB_DIR/tmp/pr4d-body.md"
```

  **머지는 사용자가 한다** — `! gh pr merge <n> --merge`. 머지 뒤 `gh pr view <n> --json state` 가 `MERGED` 인지 직접 확인한다.

---

## 부채 원장 — 미룬 것은 전부 여기 이름이 있다

| 부채 | 소유자 | 무엇이 붙잡고 있는가 |
|---|---|---|
| squash · rebase-merge · cherry-pick 으로 든 앞 조각은 ref 가 살아 있으면 구성원(과대 리뷰) | 후속 | 설계 §15-12 · README 알려진 한계 · `case_squash_front_still_member` |
| amend 뒤 낡은 upstream 이 형제(I4) · 리뷰어가 워킹트리 파일을 읽음(W3) · 하위 디렉토리 cwd 상태 파일 · kill switch 범위 | 후속(PR4c 그대로) | README 알려진 한계 |
| `resolve` 비용 = ref 수 × `|C_live|` | 후속 | README 알려진 한계 |
| M2 · M6 · PR4c Task 리뷰 Minor 들 | 후속 | PR #178 본문 · `~/.claude/sdd-mirror/qg-topic-scope-pr4c/progress.md` |
| 공개 계약 · 헌장 · 인용 락 | **PR5** | 설계 §16 |

---

## Self-Review

**1. 스펙 커버리지** — §6.2.2 정의 블록(`C_live` · `in_base`) → Task 1(d)(e)(f) · 2(a). §6.2.2 1단계 → Task 1(f). 2단계 삭제 → Task 1(g) + 부재 락. 3단계(고아 · `C_live` 빔) → Task 1(e)(g) + `case_orphan_tag_only` · `case_all_declared_in_base`. §6.2.3 보정 삭제 → Task 1(h). §6.2.6 `in_base` → Task 2. §11 AC4 → Task 1 · 2 · 3(공지). §15-12 → Task 1 `case_squash_front_still_member` · Task 3 README. §16 4d 행 → 이 PR 자체.

**2. 플레이스홀더** — `<정한 버전>` · `<오늘 날짜>` · `<이 커밋을 쓴 실제 모델>` 은 실행 시점 값이고 규칙이 적혀 있다. `<topic_key>` · `<in_base>` · `<session-id>` 는 SKILL 오케스트레이터 치환 자리.

**3. 이름 일관성** — `C_LIVE`(셸 변수) · `IN_BASE`(셸) · `in_base`(키) · 11키 순서(Task 1 Interfaces · `case_eleven_keys_always` 의 5번째 줄) · 13키 순서(Task 2 Interfaces · `KEYS`) · `_RENDER_ORDER` 의 `branches` 다음 — Task 1 · 2 · 3 · 4 에서 같다.

**4. 코드 분기 × fixture** — `resolve`: 선언 0(`case_eleven_keys_always` · `case_no_declaration`) · `C_live` 빔(`case_all_declared_in_base`) · 고아(`case_orphan_tag_only`) · 구성원 있음(F1 · F2 · F3 · N1 · N2 · 무관 · squash). `topic-head`: detect 단계 종료(`in_base: -`) · `resolve` no-declaration(`case_explicit_topic_fully_merged`) · ok(`case_single_branch_topic` · `case_merged_member_is_baseline` · `case_stack_after_front_merged`). `scope_tuple`: `in_base` 수 · `-` · 잘못된 값 · ok 인데 `-`.

**5. Review Focus** — 다섯 줄의 테스트가 소유 Task 에 있다: 1 → Task 1 N1 · 2 → Task 1 무관 · 3 → Task 1 N2 · 4 → Task 2 `case_explicit_topic_fully_merged` · 5 → Task 1 squash.

---

## Execution Handoff

SDD 로 돌리면 구현 sonnet · Task 리뷰 opus · 최종 리뷰 opus 이다(이 리포에서는 사용자가 풀기 전까지 fable 을 쓰지 않는다). 원장은 매 갱신마다 `~/.claude/sdd-mirror/qg-topic-membership-pr4d/` 로 복사한다. Task 리뷰에는 **plan-mandated** 라벨을 싣는다. 최종 리뷰는 「끝에서 끝 흐름」 표를 한 행씩 따라가게 한다.
