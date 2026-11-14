# 덩어리 승인 화면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** request-framing 의 저자 편집 승인 화면이 바뀐 문장과 고친 이유만 보이고, 덩어리 처분을 한 묶음 질문으로 받으며, 사용자가 고치기로 처분한 지적에 대응하는 덩어리에만 「그대로 둔다 (권장)」 을 단다.

**Architecture:** `seed_edit_diff.py`(덩어리 계산 · 공시 기록 · 되돌리기 · 기준 사본 교체)는 그대로 두고, 새 모듈 `seed_edit_screen.py` 가 덩어리 JSON · 저자의 이유 파일 · 리뷰 원장(읽기만)을 받아 화면 글과 질문 묶음을 낸다. skill 의 공시는 미리 보기 펜스 → 이유 파일 → 공시 펜스 두 걸음이 되고, 처분 펜스는 되돌리기 앞에서 쓴 지적 목록에 더한다. 권장의 재료는 원장의 처분과 쓴 지적 목록뿐이다 — 지적과 편집의 연결은 저자의 말이다(설계 「남는 한계」).

**Tech Stack:** Python 3.9 표준 라이브러리(`difflib`), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md`

## Global Constraints

- 브랜치는 `feature/chunk-approval-screen`. 커밋은 pathspec 으로, Conventional Commits(`<type>(<scope>): <설명>` — 설명은 한국어), 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md`.
- 고치지 않는 파일: `plugins/spec-distill/scripts/seed_edit_diff.py` · `seed_provenance.py` · `seed_review_log.py` · `shared/docreview/scripts/docreview_state.py`. 설계문서 본문도 고치지 않는다 — 어긋나는 자리를 찾으면 멈추고 보고한다.
- 바꾸지 않는 것(설계 Non-goals): 리뷰 엔진의 판정 규칙 · 처분 흐름, 되돌리는 단위(덩어리째), 기준 사본의 수명과 `init` · `revert` · `accept` 계약, 기준 사본이 없을 때의 길(seed 전문 · 「이대로 둔다 / 멈춘다」 · 추천 없음), brief · 설계문서 리뷰의 화면.
- 일어나면 안 되는 것(설계 Anti-goals): 바뀐 문장이 화면에서 하나라도 빠진다 · 권장이 붙은 덩어리가 보이지 않거나 자동으로 통과한다 · 저자가 스스로 고친 곳에 권장이 붙는다 · 사용자가 아무것도 고르지 않았을 때 저자 편집이 통과한다.
- 화면에 내는 고정 글자(글자 그대로): 「저자 편집 N곳 — 달라진 문장만 보입니다」 · 「(권장) 은 저자가 댄 지적을 사용자가 적용하기로 했다는 뜻입니다 — 편집이 그 지적에 맞는지는 아래 문장으로 직접 보세요」 · 「문장으로 가르지 못함 — 줄 전체를 보인다」 · 「바뀐 문장 없음 — 줄 전체를 보인다」 · 「문단 나눔 · 공백도 바뀜」 · 「자리 옮김」 · 「대응하는 지적 없음 — 저자가 스스로 고침」 · 「저자가 댄 지적 <id> 은 원장에서 확인되지 않는다」 · 「앞 화면에서 이미 댄 지적」 · 「이유 파일이 이 공시의 것이 아니다」 · 「이유 파일에서 읽지 못한 줄 N개」 · 「화면 조립 실패 — 줄 전체를 보인다」 · 「저자 편집 없음」.
- 질문 글(글자 그대로): 여러 개 고르기 「그대로 둘 곳을 고르세요. 고르지 않은 곳은 되돌립니다. 전부 되돌리려면 기타 칸에 적어 주세요.」 · 선택지 「<k>번 그대로 둔다」(권장이면 끝에 「 (권장)」) · 하나 고르기의 선택지 「그대로 둔다」 · 「되돌린다」. 「모두 되돌린다」 선택지는 두지 않는다.
- 질문 도구의 한계: 질문 하나에 선택지 2–4개, 호출 하나에 질문 4개. 한 질문에 덩어리는 넷까지.
- 원장 자리의 새 파일 둘: 이유 파일 `hunk-reasons.txt`(저자가 Write 도구로), 쓴 지적 목록 `hunk-used-findings.txt`(모듈이 `nofollow_write` 로). 사용자 문구 · 저자 문구는 셸 인자에 직접 쓰지 않는다 — 파일로 넘긴다.
- 레포 전용 값을 박지 않는다 — 원장 자리 · 설계문서 폴더 · 테스트 명령은 skill 의 `## 상태` 블록과 해결자(`repo_defaults.py`)가 낸 값을 받는다.
- skill 의 새 문장은 무엇을 하는지만 짧게 적는다 — 이력 · 출처 · 존재 이유를 적지 않는다(F5 가 이 절을 다시 줄인다). skill 본문에 위치 인자 토큰(`$1`…`$9` · `$@` · `$*` · `$#`)과 도구 이름 `AskUserQuestion` 을 새로 쓰지 않는다(뒤쪽은 추천 전수 검사의 「덮는 수」 칸이 달라진다).
- 펜스가 지킬 자리(다른 테스트가 «그 글자를 담은 첫 펜스» 로 뽑는다): `### 저자 편집 공시` 안에서 `hunks.json` 글자를 담은 첫 bash 펜스는 공시 펜스다 — 미리 보기 펜스에 그 글자를 쓰지 않는다. 파일 전체에서 `hunks-final.json` 글자를 담은 첫 bash 펜스는 확정 직전 공시 펜스다 — 처분 펜스와 두 미리 보기 펜스에 그 글자를 쓰지 않는다(처분 펜스는 자리표 `<덩어리 JSON 파일 이름>` 을 쓴다).
- 새 파이썬: 3.9 문법, `open(` · `.read_text(` 마다 `encoding="utf-8"`(주석의 글자도 검사에 걸린다), `"python3"` 리터럴 금지, `re.compile` 리터럴을 두지 않는다(문장 정규식은 `seed_provenance.SENT_SPLIT_RE` 를 가져다 쓰고 이유 파일은 문자열 메서드로 읽는다). 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 가 `100755`, `# guards:` 머리를 달면 `--emit-scanned` 에 같은 경로로 답한다. 셸에서 한글 바로 앞의 변수는 `${v}`, heredoc 은 `$( )` 안에 넣지 않는다, 테스트는 `PYTHONDONTWRITEBYTECODE=1`. 다른 테스트의 20줄 블록을 그대로 베끼지 않는다(`shared/tests/test_no_new_duplication.sh`).
- 판: spec-distill `8.14.0` → `8.15.0`(minor). PR 을 만들기 전에 기본 브랜치의 판을 다시 보고, 그사이 `8.15.0` 이 쓰였으면 다음 번호로 옮긴다(먼저 머지되는 쪽이 낮은 번호).
- 전체 스위트의 러너는 `bash tools/suite/run-all.sh`(`FAILED …` 줄이 실패). 지휘자가 준 공유 잠금 명령(`suite_lock.py run … -- bash -c '<스위트 명령>'`)이 있으면 그것으로만 돌린다 — 스위트 둘을 같은 시각에 돌리지 않는다. 과제 안의 좁은 테스트는 잠금 없이 돌린다.

## Review Focus

- 문장 끝 부호가 없는 줄(목록 · 제목 · 마침표 없는 문장)이 바뀐 seed — 줄 하나가 한 단위로 화면에 나오고 죽지 않는다(Task 2 `nopunct`).
- 같은 문장이 한 화면에 여러 번 나오는 seed — 「자리 옮김」 은 하나씩만 짝짓고 불변식이 유지된다(Task 2 `dup`).
- 저자가 쓴 이유 파일의 줄 끝이 CRLF 이거나 탭 대신 공백을 쓴 줄 — CRLF 는 읽고, 탭 없는 줄은 「읽지 못한 줄」 로 세며 어느 쪽도 권장을 더 붙이지 않는다(Task 3 `crlf`).
- 원장의 지적 요약이 여러 줄인 경우 — 이유 줄은 한 줄로 이어져 화면의 덩어리 구조를 깨지 않는다(Task 3 `longsum`).
- 덩어리가 아주 많은 화면(질문이 한 호출의 넷을 넘는 17개 이상 포함) — 2–40 어느 수에서도 질문마다 덩어리 둘에서 넷이고 합이 맞는다(Task 4 `split_sizes`).

## 파일 구조

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `plugins/spec-distill/scripts/seed_edit_screen.py`(새) | 화면 조립 — 문장 가르기 · 고친 이유 확인 · 질문 묶음 · 미리 보기 · 쓴 지적 목록에 더하기 | 2 · 3 · 4 |
| `plugins/spec-distill/tests/test_seed_edit_screen.sh`(새, 100755) | 그 모듈을 실행으로 잰다(AC1–AC8 · AC10 의 스크립트 몫) | 2 · 3 · 4 |
| `plugins/spec-distill/tests/test_state_dir_writes.sh` | 스크립트 칸에 쓴 지적 목록 쓰기(링크) · README 한계 문장의 글자 | 4 · 6 |
| `plugins/spec-distill/skills/request-framing/SKILL.md` | `### 저자 편집 공시`(펜스 셋 · 규칙) · 확정 게이트 직전 검사 2 · 사용자 문구 파일 설명 · `## 상태` 표의 파일 이름 | 5 |
| `plugins/spec-distill/tests/test_framing_review_contract.sh` | skill 글자와 펜스 배선의 락(AC9 · AC10 배선 · AC11 변이) | 5 |
| `plugins/spec-distill/tests/test_plain_gate_templates.sh` | 예외 문장 단언을 새 규칙으로 | 5 |
| `shared/tests/fixtures/ask-sites.tsv` | 이 자리 행의 종류와 글자 | 5 |
| `plugins/spec-distill/README.md` · `shared/tests/test_writer_trust_notice.sh` | Law 2(seed 자리) 줄에 새 스크립트 · 한계 문장에 이유 파일 이름(락 둘이 그 글자를 잰다) | 6 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` | 판 올림 · 변경 기록 | 6 |

## AC 대응

| AC | 과제 |
|---|---|
| AC1 · AC2 · AC3 | 2 |
| AC4 · AC5 · AC6 | 3 |
| AC7 | 4 |
| AC8 | 2(미리 보기 · 화면 조립) · 3(원장 자리) |
| AC9 | 5 |
| AC10 | 4(목록에 더하기 · 번호 대조) · 5(처분 펜스 배선) |
| AC11 | 5 |
| AC12 | 6 |

## 설계 그대로 둔 가장자리(이 계획은 고치지 않는다)

설계 1 의 뼈대 비교를 글자 그대로 구현하면 아래 둘은 「바뀐 문장만」 꼴이 되어 줄 전체가 붙지 않는다. 설계를 고치는 일이라 계획은 규칙을 바꾸지 않는다 — 구현도 설계의 규칙 그대로 두고, 설계가 바뀌면 Task 2 의 뼈대 규칙과 테스트에 한 줄씩 더한다.

- 문단 하나를 통째로 바꾸면서(양쪽 모두 그 줄이 비게 된다) 한쪽에서만 맞닿은 빈 줄을 지운 덩어리 — 빈 줄이 사라진 것이 화면에 따로 보이지 않는다.
- 그대로인 문장 «사이» 의 공백만 바뀌고(문장 글자는 같다) 같은 덩어리에서 다른 문장이 바뀐 경우 — 공백 변화는 보이지 않는다.

---

### Task 1: 다시 확인 · 원장 칸 못박기

**Files:** 없음(읽기만 — 커밋하지 않는다).

**Interfaces:**
- Produces: 아래 「못박은 것」 표 — Task 3 의 `finding_status` 가 그대로 쓴다.

- [ ] **Step 1: 설계문서가 근거로 든 자리를 센다** — 아래 글을 git 이 무시하는 자리(`.claude/tmp/f2/recheck.sh`)에 쓰고 `bash .claude/tmp/f2/recheck.sh` 로 돌린다.

````bash
#!/usr/bin/env bash
# 과제 1 의 다시 확인 — 설계문서가 근거로 든 자리가 지금 코드에서도 그런지 센다. 한 줄에 「이름 값」.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
SK=plugins/spec-distill/skills/request-framing/SKILL.md
S=plugins/spec-distill/scripts
T=plugins/spec-distill/tests
c() { printf '%s %s\n' "$1" "$(grep -cF -- "$2" "$3")"; }
c skill_disc_heading '### 저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞' "$SK"
c skill_old_question '덩어리마다 질문 하나' "$SK"
c skill_old_norec '추천을 달지 않는다 — 어느 덩어리가' "$SK"
c skill_old_nocut '줄이면 공시가 아니다' "$SK"
c skill_old_exception '규칙 블록의 「따로 정한 자리」' "$SK"
c skill_norec_nobase '추천을 달지 않는다 — 기준 사본이 없어' "$SK"
c skill_hunks_only_shown '`hunks` 는 그 출력을 사용자에게 보이는 자리에서만' "$SK"
c skill_round_hunks_fence 'run --out "$STATE_DIR/hunks.json" -- python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "$SK"
c skill_final_check2 '**검사 2 — 저자 편집 공시**' "$SK"
c skill_final_hunks_fence 'run --out "$STATE_DIR/hunks-final.json" -- python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "$SK"
c skill_final_json_mentions 'hunks-final.json' "$SK"
c skill_said_hunk_desc '저자 편집 덩어리의 문구는 `$STATE_DIR/said-hunk-<k>.txt`' "$SK"
c diff_compute_hunks 'def compute_hunks(base: list[str], seed: list[str]) -> list[dict]:' "$S/seed_edit_diff.py"
c diff_hunk_keys '"removed": removed, "added": added, "render": render' "$S/seed_edit_diff.py"
c diff_seed_sha '"seed_sha256": seed_sha' "$S/seed_edit_diff.py"
c diff_span 'def _span(a: int, b: int) -> str:' "$S/seed_edit_diff.py"
c diff_read 'def _read(p: pathlib.Path) -> list[str]:' "$S/seed_edit_diff.py"
c diff_sha 'def _sha256(p: pathlib.Path) -> str:' "$S/seed_edit_diff.py"
c prov_split 'SENT_SPLIT_RE = re.compile(r"(?<=[.!?。])\s+|(?<=" + re.escape(MARK) + r")\s+")' "$S/seed_provenance.py"
c prov_norm 'def norm(s: str) -> str:' "$S/seed_provenance.py"
c prov_mark_import 'from seed_body import (MARK,' "$S/seed_provenance.py"
c body_mark 'MARK = "(사용자 확인)"' "$S/seed_body.py"
c state_load 'def load_state(state_dir) -> dict:' shared/docreview/scripts/docreview_state.py
c state_fix_pending 'st["fixes"][fid] = {"state": "pending", "round": n, "scope": None}' shared/docreview/scripts/docreview_state.py
c state_fix_applied_from_intent 'if fx.get("state") != "intent_passed":' shared/docreview/scripts/docreview_state.py
c state_decide_entry '"finding_ids": [a.id], "lineage": f["lineage"], "choice": a.choice, "quote": a.quote}' shared/docreview/scripts/docreview_state.py
c state_post_reject_adopted 'if d.get("kind") == "post":' shared/docreview/scripts/docreview_state.py
c anchor_intent_passed 'fx["state"] = "intent_passed"' shared/docreview/scripts/docreview_anchor.py
c log_user_quotes 'def user_quotes(audit_text: str) -> list[str]:' "$S/seed_review_log.py"
c ct_blocking_question "grep -qF '덩어리마다 질문 하나' || echo \"hunk_question\"" "$T/test_framing_review_contract.sh"
c ct_norec 'assert_contains "$DISC" "추천을 달지 않는다 — " "D15: 덩어리 처분에 저자 권장이 없다"' "$T/test_framing_review_contract.sh"
c ct_whole_line 'assert_contains "$outH" "+ EDITED_BY_AUTHOR 줄 둘" "$fence: 편집된 줄을 줄임 없이 낸다"' "$T/test_framing_review_contract.sh"
c ct_fix2 'assert_contains "$outR" "rev_rc=2" "fix2: 없는 덩어리 번호(--ids 99) 는 revert rc 2 로 막힌다"' "$T/test_framing_review_contract.sh"
c pg_exception "assert_file_grep \"\$FR\" '규칙 블록의 「따로 정한 자리」'" "$T/test_plain_gate_templates.sh"
c sw_script_column '# ── seed_edit_diff ───' "$T/test_state_dir_writes.sh"
c sw_rf_hunks 'fence_with "$RF_MD" '"'"'"$STATE_DIR/hunks.json"'"'" "$T/test_state_dir_writes.sh"
c lw_final_fence "bash_with \"\$RF\" 'hunks-final.json'" "$T/test_ledger_wiring.sh"
c tsv_hunk_row '	비움	- 덩어리가 있으면 **덩어리마다 질문 하나**	덩어리 본문(`render`)은 질문 텍스트에' shared/tests/fixtures/ask-sites.tsv
c tsv_nobase_row '	비움	- 기준 사본이 없으면(rc 3 — 원장이 정리됐다)	처분을 받은 뒤 순서가 계약입니다' shared/tests/fixtures/ask-sites.tsv
c readme_limit '`critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고' plugins/spec-distill/README.md
c trust_limit '`critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고' shared/tests/test_writer_trust_notice.sh
printf 'version %s\n' "$(grep -F '"version"' plugins/spec-distill/.claude-plugin/plugin.json | tr -d ' ,')"
printf 'screen_module %s\n' "$(ls "$S/seed_edit_screen.py" 2>/dev/null | grep -c .)"
````

Expected: `skill_final_json_mentions 2` · `state_post_reject_adopted 2` · `version "version":"8.14.0"` · `screen_module 0`, 그 밖의 줄은 전부 `1`. 하나라도 다르면 그 줄을 들고 멈춰 보고한다 — 이 계획의 편집 자리가 옮겨졌다는 뜻이다.

- [ ] **Step 2: 못박은 것을 지금 코드와 맞춰 본다** — `shared/docreview/scripts/docreview_state.py` 의 `cmd_decide` · `cmd_fix` · `observe_ledger` 와 `docreview_anchor.py` 의 `check-intent` 갈래를 읽어 아래 표의 근거 칸이 지금도 맞는지 본다. 다르면 멈춰 보고한다.

**못박은 것 — 원장(`load_state` 가 낸 dict `st`)의 어느 칸이 「사용자가 적용 · 채택」 인가**

| 뜻 | 읽는 칸 | 근거 |
|---|---|---|
| 지적 요약 | `st["findings"][id]["summary"]` | `record_findings` 가 `PUBLIC_FIELDS` 를 그대로 싣는다 |
| `fix` 를 사용자가 「적용」 | `st["fixes"][id]["state"]` 가 `intent_passed` 또는 `applied` | `intent_passed` 는 `check-intent` 통과만 적고(사용자가 「적용」 을 골랐을 때만 부른다), `applied` 는 `observe_ledger` 가 `intent_passed` 에서만 옮긴다. `pending` · `held` · `dropped` · `escalated` 는 아니다 |
| `decide` 를 사용자가 채택 | `id` 가 `st["decides"]` 에 있고, `st["decision_log"]` 에서 `finding_ids` 에 그 id 가 든 **마지막** 항목의 `choice` 가 `adopt` 이며, `st["decides"][id]["kind"]` 가 `post` 가 아니다. **상태 칸은 보지 않는다** | 상태 칸만으로는 채택과 원복이 갈리지 않는다 — `kind: post` 항목을 거부(`reject`)하면 상태가 `adopted` 가 되고 원복이 관측되면 `applied` 가 된다. 채택 뒤 편집이 관측되지 않으면 `expired` 가 되지만 고른 쪽은 여전히 채택이다. `post` 항목의 채택은 「현재 변경 유지」 라 고치라는 처분이 아니다(seed 프로필에서는 생기지 않는다) |
| `ask` 에 사용자가 답함 | `st["asks"][id]["answered"]` 가 참 | 이유로만 보이고 확인됨으로 치지 않는다(설계 2) |
| 그 밖 | 위 어느 것도 아니면 「원장에서 확인되지 않는다」 | 원장에 없는 id · 처분 전 · 적용하지 않음 · 거부 · 보류 |

- [ ] **Step 3: 기준 스위트를 뜬다** — 편집 전 브랜치 끝에서 전체 스위트를 한 번 돌려 실패 줄을 `.claude/tmp/f2/suite-base.txt` 에 남긴다(Global Constraints 의 러너 · 잠금). Task 6 이 이것과 견준다. 이 worktree 에서만 실패하는 기존 실패가 있어 기준이 필요하다.

---

### Task 2: 화면 조립 — 문장 가르기 · 화면 꼴 넷 · 미리 보기 (AC1 · AC2 · AC3 · AC8)

**Files:**
- Create: `plugins/spec-distill/scripts/seed_edit_screen.py`
- Create: `plugins/spec-distill/tests/test_seed_edit_screen.sh` (100755)

**Interfaces:**
- Consumes: `seed_edit_diff.compute_hunks(base: list[str], seed: list[str]) -> list[dict]`(덩어리마다 `id` · `base: [i1, i2]` · `seed: [j1, j2]` · `removed: list[str]` · `added: list[str]` · `render`) · `seed_edit_diff._read(p)` · `seed_edit_diff._sha256(p)` · `seed_edit_diff._span(a, b)` · `seed_provenance.SENT_SPLIT_RE` · `seed_provenance.MARK` · `seed_provenance.norm`. `hunks` 가 쓴 덩어리 JSON 은 `{"base_present", "empty", "hunks", "seed_sha256"}`.
- Produces(CLI): `seed_edit_screen.py preview <기준 사본> <seed>` · `seed_edit_screen.py screen --hunks <덩어리 JSON> --reasons <이유 파일> --state-dir <원장 폴더> [--final]`. rc 0 정상 · 2 입력 오류와 그 밖의 예외 · 3 기준 사본 부재(`preview`).
- Produces(모듈 함수 — 테스트와 뒤 과제가 이 이름으로 부른다): `line_units(line: str) -> list[str]` · `sentence_diff(base_keys: list[str], seed_keys: list[str]) -> tuple[list[int], list[int]]` · `hunk_view(h: dict) -> dict` · `mark_moves(views: list[dict]) -> None` · `build_screen(hunks_doc: dict, reasons_path: str, state_dir: str, final: bool = False) -> dict`.
- Produces(`screen` 의 JSON): `{"text": str, "hunks": [...], "questions": [...], "notices": [str]}`. `hunks[]` 는 덩어리마다 `id` · `shape`(1–4) · `reason`(str) · `recommend`(bool) · `removed_sentences` · `added_sentences`(list[str]) · `removed_moved` · `added_moved`(list[bool], 문장 목록과 같은 길이) · `removed_idx` · `added_idx`(그 덩어리의 문장 열에서의 자리) · `kept`(int) · `summary`(str). 이 과제에서는 `reason` 이 늘 「대응하는 지적 없음 — 저자가 스스로 고침」, `recommend` 가 늘 거짓, `questions` · `notices` 가 빈 목록이다(Task 3 · 4 가 채운다). `--reasons` · `--state-dir` · `--final` 은 받되 아직 쓰지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_seed_edit_screen.sh` 를 아래 글 그대로 만든다.

````bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_edit_screen.py
#
# seed_edit_screen.py 를 실행으로 잰다 — 저자 편집 승인 화면의 기계 쪽.
#   · 화면은 바뀐 문장만 보인다 — 꼴 넷(문장으로 가르지 못함 · 바뀐 문장 없음 · 문단 나눔도 바뀜 · 바뀐 문장만)
#   · 권장은 저자가 댄 지적 전부에 사용자의 고치는 쪽 처분이 원장에 있고 앞 화면에서 대지 않았을 때만 붙는다
#   · 질문 묶음은 한 질문에 덩어리 넷까지 · 권장이 앞 · 덩어리 하나짜리 질문은 전체가 하나일 때만
#   · 미리 보기 · 화면 조립은 읽기만 한다. 쓴 지적 목록에 더하기는 번호 전수 대조 뒤에만 쓴다
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/seed_edit_screen.py"; exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
X="$S/seed_edit_screen.py"
TMP="$(mktemp -d -t sd-seed-screen-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
test -f "$X" || { no "부재: $X"; finish; exit; }

mk() {   # mk <이름> <기준 글> <지금 글> — 글은 printf %b 로 푼다. $TMP/<이름>/{base.md,seed.md,hunks.json,state/}
  mkdir -p "$TMP/$1/state"
  printf '%b' "$2" > "$TMP/$1/base.md"; printf '%b' "$3" > "$TMP/$1/seed.md"
  python3 "$S/seed_edit_diff.py" hunks "$TMP/$1/base.md" "$TMP/$1/seed.md" > "$TMP/$1/hunks.json"
}
scr() {  # scr <이름> [--final] → 화면 JSON 을 $TMP/<이름>/screen.json 에, rc 는 화면 조립의 rc
  local n="$1"; shift
  python3 "$X" screen --hunks "$TMP/$n/hunks.json" --reasons "$TMP/$n/state/hunk-reasons.txt" --state-dir "$TMP/$n/state" "$@" > "$TMP/$n/screen.json"
}
# j <이름> <식> — 화면 JSON(d)에 식을 매겨 낸다. 식은 이 파일에 적힌 고정 글자뿐이다(test_seed_edit_diff.sh 의 j 와 같은 꼴).
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$TMP/$1/screen.json" "$2"; }
sums() {   # sums <폴더> → 화면 · 미리 보기 출력 파일을 뺀 모든 파일의 경로와 sha256
  python3 -c 'import hashlib, os, sys
for r, _, fs in sorted(os.walk(sys.argv[1])):
    for f in sorted(fs):
        if f not in ("screen.json", "preview.json"):
            p = os.path.join(r, f)
            print(p, hashlib.sha256(open(p, "rb").read()).hexdigest())' "$1"
}

# ── AC1 — 바뀐 문장만 ─────────────────────────────────────────────────────────
mk one '가. 나. 다.\n' '가. 나 고침. 다.\n'
before="$(sums "$TMP/one")"
scr one; rc=$?
assert_eq "$rc" "0" "AC1: 화면 조립 rc 0"
assert_eq "$(sums "$TMP/one")" "$before" "AC8: 화면 조립은 seed · 기준 사본 · 공시 기록(.shown) · 덩어리 JSON 을 바꾸지 않는다"
assert_eq "$(j one '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"], d["hunks"][0]["kept"])')" \
  "(4, ['나.'], ['나 고침.'], 2)" "AC1: 한 문장만 바뀌면 뺀 문장 하나 · 더한 문장 하나 · 그대로 둘"
T1="$(j one 'd["text"]')"
assert_eq "$(j one 'd["text"].split("\n")[0]')" "저자 편집 1곳 — 달라진 문장만 보입니다" "AC1: 화면 글 첫 줄"
assert_contains "$T1" "1) 기준 1행 → 현재 1행 · 뺀 문장 1개 · 더한 문장 1개 · 그대로 2문장" "AC1: 그대로인 문장은 수로만 나온다"
assert_contains "$T1" "   뺀 문장: 나." "AC1: 뺀 문장 줄"
assert_contains "$T1" "   더한 문장: 나 고침." "AC1: 더한 문장 줄"
assert_not_contains "$T1" "가." "AC1: 그대로인 문장의 글자는 화면에 없다"
assert_not_contains "$T1" "   - " "AC1: 줄 전체 꼴이 붙지 않는다"
mk add1 '가. 나.\n' '가. 나. 다.\n'; scr add1
assert_eq "$(j add1 '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(4, [], ['다.'])" "AC1: 문장 하나만 더하면 그 문장 하나만"
assert_not_contains "$(j add1 'd["text"]')" "   + " "AC1: 문장만 더한 덩어리에 줄 전체 꼴이 붙지 않는다"
mk del1 '가. 나. 다.\n' '가. 다.\n'; scr del1
assert_eq "$(j del1 '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(4, ['나.'], [])" "AC1: 문장 하나만 빼면 그 문장 하나만"
mk padd '가.\n\n나.\n' '가.\n\n새 문단. 둘째.\n\n나.\n'; scr padd
assert_eq "$(j padd '(d["hunks"][0]["shape"], d["hunks"][0]["added_sentences"], d["text"].count("새 문단."), "   + " in d["text"])')" \
  "(4, ['새 문단.', '둘째.'], 1, False)" "AC1: 빈 줄과 함께 통째로 더한 문단은 문장이 한 번만 나오고 줄 전체 꼴이 없다"
mk pdel '가.\n\n지울 문단.\n\n나.\n' '가.\n\n나.\n'; scr pdel
assert_eq "$(j pdel '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["text"].count("지울 문단."), "   - " in d["text"])')" \
  "(4, ['지울 문단.'], 1, False)" "AC1: 빈 줄과 함께 통째로 지운 문단도 같다"

# ── AC2 — 불변식 · 자리 옮김 · 문단 나눔도 바뀐 꼴 ──────────────────────────────
inv() {   # inv <이름> → 덩어리마다 기준 쪽에서 뺀 문장을, 지금 쪽에서 더한 문장을 지운 열이 순서까지 같으면 ok
  python3 - "$S" "$TMP/$1/hunks.json" "$TMP/$1/screen.json" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
from seed_provenance import norm
hs = json.load(open(sys.argv[2], encoding="utf-8"))["hunks"]
vs = json.load(open(sys.argv[3], encoding="utf-8"))["hunks"]
bad = []
for h, v in zip(hs, vs):
    b = [norm(u) for l in h["removed"] for u in m.line_units(l)]
    s = [norm(u) for l in h["added"] for u in m.line_units(l)]
    kb = [k for i, k in enumerate(b) if i not in set(v["removed_idx"])]
    ks = [k for i, k in enumerate(s) if i not in set(v["added_idx"])]
    if kb != ks or len(kb) != v["kept"]:
        bad.append(h["id"])
print("ok" if hs and len(hs) == len(vs) and not bad else "bad %s" % bad)
PY
}
while IFS='|' read -r name base seed shapes; do
  mk "$name" "$base" "$seed"; scr "$name"
  assert_eq "$(inv "$name")" "ok" "AC2 불변식: $name"
  assert_eq "$(j "$name" '[h["shape"] for h in d["hunks"]]')" "$shapes" "AC2 꼴: $name"
done <<'EOF'
ins|가. 나.\n|가. 새. 나.\n|[4]
del|가. 새. 나.\n|가. 나.\n|[4]
rep|가. 나.\n|가. 나 고침.\n|[4]
multi|가.\n나.\n다.\n|가 고침.\n나 고침.\n다.\n|[4]
marked|가. (사용자 확인) 나.\n|가. (사용자 확인) 나 고침.\n|[4]
merge|가. 나.\n다. 라.\n|가. 나 고침. 다. 라.\n|[3]
reorder|가. 나.\n|나. 가.\n|[4]
swap|가. 나.\n\n다. 라.\n|가. 라.\n\n다. 나.\n|[4, 4]
blank|가. 나.\n다.\n|가. 나 고침.\n\n다.\n|[3]
space|가  나. 다.\n|가 나. 다 고침.\n|[3]
dup|가. 가. 나.\n|가. 나. 가.\n|[4]
nopunct|제목 줄\n- 목록 하나\n|제목 줄\n- 목록 둘\n|[4]
EOF
assert_eq "$(j marked '(d["hunks"][0]["kept"], d["hunks"][0]["removed_sentences"])')" "(1, ['나.'])" "AC2: «(사용자 확인)» 이 붙은 문장은 표시째 한 단위로 그대로다"
TM="$(j merge 'd["text"]')"
assert_contains "$TM" "   뺀 문장: 나." "AC2: 문단을 합친 덩어리도 바뀐 문장을 보인다"
assert_contains "$TM" "   문단 나눔 · 공백도 바뀜" "AC2: 문장 변경과 문단 합치기가 섞이면 그 사실 한 줄"
assert_contains "$TM" "   - 가. 나." "AC2: 그 덩어리는 줄 전체 꼴(기준 쪽)이 함께 보인다"
assert_contains "$TM" "   + 가. 나 고침. 다. 라." "AC2: 그 덩어리는 줄 전체 꼴(지금 쪽)이 함께 보인다"
assert_contains "$(j blank 'd["text"]')" "   문단 나눔 · 공백도 바뀜" "AC2: 빈 줄을 따로 넣은 덩어리"
assert_contains "$(j space 'd["text"]')" "   문단 나눔 · 공백도 바뀜" "AC2: 그대로인 문장의 공백이 바뀐 덩어리"
TR="$(j reorder 'd["text"]')"
assert_contains "$TR" "   뺀 문장(자리 옮김): 나." "AC2: 순서만 바뀐 문장은 뺀 쪽에 「자리 옮김」"
assert_contains "$TR" "   더한 문장(자리 옮김): 나." "AC2: 순서만 바뀐 문장은 더한 쪽에도 「자리 옮김」"
assert_eq "$(j swap '[(h["removed_sentences"], h["removed_moved"], h["added_sentences"], h["added_moved"]) for h in d["hunks"]]')" \
  "[(['나.'], [True], ['라.'], [True]), (['라.'], [True], ['나.'], [True])]" "AC2: 두 문단 사이에서 맞바꾼 문장은 두 덩어리에 걸쳐 「자리 옮김」 이 붙는다"
assert_not_contains "$(j rep 'd["text"]')" "자리 옮김" "AC2: 고친 문장에는 「자리 옮김」 이 붙지 않는다"
assert_eq "$(j dup '(sum(d["hunks"][0]["removed_moved"]), sum(d["hunks"][0]["added_moved"]))')" "(1, 1)" "Review Focus: 같은 문장이 여럿이어도 「자리 옮김」 은 하나씩만 짝짓는다"
assert_eq "$(j nopunct '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['- 목록 하나'], ['- 목록 둘'])" "Review Focus: 문장 끝 부호가 없는 줄은 줄 하나가 한 단위다"

# ── AC3 — 바뀐 문장 없는 덩어리 · 불변식이 어긋난 덩어리 · 표시만 바뀐 편집 ─────────
while IFS='|' read -r name base seed; do
  mk "$name" "$base" "$seed"; scr "$name"
  assert_eq "$(j "$name" '[(h["shape"], h["removed_sentences"], h["added_sentences"]) for h in d["hunks"]]')" "[(2, [], [])]" "AC3 바뀐 문장 없음: $name"
  assert_contains "$(j "$name" 'd["text"]')" "   바뀐 문장 없음 — 줄 전체를 보인다" "AC3 안내 줄: $name"
  assert_not_contains "$(j "$name" 'd["text"]')" "문단 나눔 · 공백도 바뀜" "AC3 다른 안내는 붙지 않는다: $name"
done <<'EOF'
ws|가.  나.\n|가. 나.\n
blankonly|가.\n나.\n|가.\n\n나.\n
mergeonly|가.\n나.\n|가. 나.\n
splitonly|가. 나.\n|가.\n나.\n
EOF
assert_contains "$(j ws 'd["text"]')" "   - 가.  나." "AC3: 공백만 바뀐 덩어리는 줄 전체(기준 쪽)를 보인다"
assert_contains "$(j ws 'd["text"]')" "   + 가. 나." "AC3: 공백만 바뀐 덩어리는 줄 전체(지금 쪽)를 보인다"
python3 - "$S" "$TMP/one/hunks.json" "$TMP/one/state/hunk-reasons.txt" "$TMP/one/state" > "$TMP/sh1.txt" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
m.sentence_diff = lambda base_keys, seed_keys: ([], [])   # 바뀐 문장을 놓친 차이 — 불변식이 어긋난다
out = m.build_screen(json.load(open(sys.argv[2], encoding="utf-8")), sys.argv[3], sys.argv[4])
print(out["hunks"][0]["shape"])
print(out["text"])
PY
SH1="$(cat "$TMP/sh1.txt")"
assert_eq "$(head -n 1 "$TMP/sh1.txt")" "1" "AC3: 불변식이 어긋나면 꼴 1"
assert_contains "$SH1" "   문장으로 가르지 못함 — 줄 전체를 보인다" "AC3: 불변식이 어긋난 덩어리의 안내 줄"
assert_contains "$SH1" "   - 가. 나. 다." "AC3: 불변식이 어긋난 덩어리는 줄 전체(기준 쪽)"
assert_contains "$SH1" "   + 가. 나 고침. 다." "AC3: 불변식이 어긋난 덩어리는 줄 전체(지금 쪽)"
assert_not_contains "$SH1" "뺀 문장" "AC3: 불변식이 어긋난 덩어리는 문장 줄을 내지 않는다"
mk markon '가. 나.\n' '가. (사용자 확인) 나.\n'; scr markon
assert_eq "$(j markon '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['가.'], ['가. (사용자 확인)'])" "AC3: 표시만 붙인 편집은 표시 없는 문장을 빼고 표시 붙은 문장을 더한 것으로 보인다"
mk markoff '가. (사용자 확인) 나.\n' '가. 나.\n'; scr markoff
assert_eq "$(j markoff '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['가. (사용자 확인)'], ['가.'])" "AC3: 표시만 뗀 편집은 그 반대로 보인다"

# ── AC8 — 미리 보기 ──────────────────────────────────────────────────────────
mkdir -p "$TMP/pv"; printf '가. 나.\n\n다.\n' > "$TMP/pv/base.md"; printf '가. 나 고침.\n\n다 고침.\n' > "$TMP/pv/seed.md"
before="$(sums "$TMP/pv")"
python3 "$X" preview "$TMP/pv/base.md" "$TMP/pv/seed.md" > "$TMP/pv/preview.json"; rc=$?
assert_eq "$rc" "0" "AC8: 미리 보기 rc 0"
assert_eq "$(sums "$TMP/pv")" "$before" "AC8: 미리 보기는 seed · 기준 사본을 바꾸지 않고 공시 기록(.shown)도 남기지 않는다"
python3 "$S/seed_edit_diff.py" hunks "$TMP/pv/base.md" "$TMP/pv/seed.md" > "$TMP/pv/hunks.json"
assert_eq "$(python3 -c 'import json,sys
a = json.load(open(sys.argv[1], encoding="utf-8")); b = json.load(open(sys.argv[2], encoding="utf-8"))
print(a == b, [h["id"] for h in a["hunks"]], len(a["seed_sha256"]))' "$TMP/pv/preview.json" "$TMP/pv/hunks.json")" "True [1, 2] 64" "AC8: 미리 보기의 덩어리 번호 · 판본이 같은 seed 의 hunks 와 같다"
python3 "$X" preview "$TMP/pv/none.md" "$TMP/pv/seed.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "3" "AC8: 기준 사본이 없으면 미리 보기 rc 3"
mk same '가. 나.\n' '가. 나.\n'; scr same
assert_eq "$(j same '(d["text"], d["hunks"], d["questions"])')" "('저자 편집 없음', [], [])" "덩어리가 0 이면 화면 글은 「저자 편집 없음」 한 줄이다"

finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_seed_edit_screen.sh && bash plugins/spec-distill/tests/test_seed_edit_screen.sh`
Expected: `✗ 부재: …/plugins/spec-distill/scripts/seed_edit_screen.py` 한 줄로 실패.

- [ ] **Step 3: `seed_edit_screen.py` 를 쓴다** — 위 Interfaces 의 이름 그대로. 머리 주석은 하위 명령 · rc 만 적는다. 규칙:

  - `line_units(line)` — `SENT_SPLIT_RE.split(line)` 의 조각 가운데 공백뿐인 것은 버린다. `조각.strip() == MARK` 이고 앞 단위가 있으면 앞 단위 끝에 `" " + MARK` 로 붙여 한 단위로 삼는다(줄의 첫 조각이 표시면 그 조각만으로 한 단위). 그 밖의 조각은 원래 글자 그대로 단위다. 문장을 견주는 열쇠는 `norm(단위)`, 화면에 내는 글은 `단위.strip()` 이다.
  - `sentence_diff(base_keys, seed_keys)` — `difflib.SequenceMatcher(a=base_keys, b=seed_keys, autojunk=False).get_opcodes()` 에서 `equal` 이 아닌 구간의 기준 쪽 자리들과 지금 쪽 자리들을 낸다(뺀 문장 · 더한 문장).
  - `hunk_view(h)` — 덩어리의 `removed` 줄들과 `added` 줄들을 각각 줄마다 `line_units` 로 나눠 이어 붙인 문장 열 둘을 만들고(열쇠로) `sentence_diff` 를 **모듈 전역 이름으로** 불러 견준다(테스트가 그 이름을 바꿔 끼운다). 꼴은 위에서부터 먼저 맞는 것:
    1. 기준 쪽 열에서 뺀 자리를 지운 것과 지금 쪽 열에서 더한 자리를 지운 것이 순서까지 같지 않다 → `shape` 1. `removed_sentences` · `added_sentences` 는 빈 목록, `kept` 0.
    2. 뺀 문장도 더한 문장도 없다 → `shape` 2.
    3. 뼈대가 다르다 → `shape` 3.
    4. 뼈대가 같다 → `shape` 4.
  - 뼈대 — 양쪽을 줄마다의 단위 목록(원래 글자)으로 놓고, 기준 쪽에서는 뺀 문장을, 지금 쪽에서는 더한 문장을 지운다. 그 지움 때문에 비게 된 줄은 버리고, 그 줄에 맞닿은 빈 줄(단위가 없는 줄) 하나도 함께 버린다 — 앞줄을 먼저 보고 없으면 뒷줄, 이미 버린 줄은 다시 세지 않는다. 그 밖의 빈 줄은 빈 목록으로 남는다. 남은 두 목록(줄마다 단위의 튜플)이 같으면 뼈대가 같은 것이다.
  - `summary` — 꼴 1 「문장으로 가르지 못함」, 꼴 2 「바뀐 문장 없음」, 꼴 3 · 4 는 `뺀 문장 N개`(N>0 일 때) · `더한 문장 M개`(M>0 일 때) · `그대로 K문장` 을 ` · ` 로 잇는다.
  - `mark_moves(views)` — 화면의 모든 덩어리에 걸쳐, 뺀 문장과 더한 문장을 열쇠가 같은 것끼리 하나씩(앞에서부터) 짝지어 양쪽의 `removed_moved` · `added_moved` 를 참으로 한다. 한 문장은 한 번만 짝이 된다.
  - `build_screen(...)["text"]` — 덩어리가 0 이면 「저자 편집 없음」 한 줄. 아니면 첫 줄 `저자 편집 <덩어리 수>곳 — 달라진 문장만 보입니다`, 그 뒤 덩어리마다 빈 줄 하나와 아래 꼴(들여쓰기는 공백 셋):

    ```
    <k>) 기준 <_span(base)> → 현재 <_span(seed)> · <summary>
       고친 이유(저자가 댐): <이유 조각>            ← 조각마다 한 줄
       뺀 문장: <문장>                              ← 자리만 옮긴 문장이면 「뺀 문장(자리 옮김): <문장>」
       더한 문장: <문장>                            ← 자리만 옮긴 문장이면 「더한 문장(자리 옮김): <문장>」
       문단 나눔 · 공백도 바뀜                      ← 꼴 3 만
       - <기준 쪽 줄>                               ← 꼴 1 · 2 · 3 — removed 줄 전부, 그 뒤 added 줄 전부
       + <지금 쪽 줄>
    ```

    꼴 1 은 문장 줄 대신 `   문장으로 가르지 못함 — 줄 전체를 보인다`, 꼴 2 는 `   바뀐 문장 없음 — 줄 전체를 보인다` 한 줄을 이유 줄 뒤에 두고 줄 전체를 싣는다.
  - `preview` — 기준 사본이 없으면 `{"base_present": false, "empty": null, "hunks": []}` 를 내고 rc 3. 있으면 `seed_edit_diff._read` 로 둘을 읽어 `compute_hunks` 를 부르고 `hunks` 와 같은 JSON(`base_present` · `empty` · `hunks` · `seed_sha256` = `seed_edit_diff._sha256(seed)`)을 낸다. 파일을 쓰지 않는다.
  - `screen` — 덩어리 JSON 을 읽어(못 읽거나 `hunks` 목록이 없으면 stderr 한 줄 · rc 2) `build_screen` 의 결과를 `json.dumps(..., ensure_ascii=False)` 로 낸다. 파일을 쓰지 않는다.
  - `main` — `seed_edit_diff.py` 의 꼴대로 stdout · stderr 를 UTF-8 로 맞추고, 문서화한 rc 밖의 예외는 stderr 한 줄과 rc 2 로 낸다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_seed_edit_screen.sh`
Expected: `✗` 0, 마지막 줄 `Total: … | Fail: 0`.

- [ ] **Step 5: 새 파일이 걸리는 레포 락을 돌린다**

Run: `git add plugins/spec-distill/scripts/seed_edit_screen.py plugins/spec-distill/tests/test_seed_edit_screen.sh && git ls-files -s plugins/spec-distill/tests/test_seed_edit_screen.sh`
Expected: `100755` 로 시작하는 한 줄.

Run: `python3 tools/suite/run_unittest_dir.py plugins/quality-gates/tests test_utf8_explicit.py; bash shared/tests/test_python_floor.sh | tail -1; bash shared/tests/test_shell_tests_executable.sh | tail -1; bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -1; bash shared/tests/test_no_new_duplication.sh | tail -1; bash plugins/spec-distill/tests/test_check_brief.sh | grep -c '✗'`
Expected: unittest `OK`, 셸 락마다 실패 0, 마지막 수 `0`.

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 저자 편집 화면 조립 — 바뀐 문장만 · 미리 보기" -m "Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md" -- plugins/spec-distill/scripts/seed_edit_screen.py plugins/spec-distill/tests/test_seed_edit_screen.sh
```

---

### Task 3: 고친 이유 · 권장 (AC4 · AC5 · AC6 · AC8 의 원장 자리)

**Files:**
- Modify: `plugins/spec-distill/scripts/seed_edit_screen.py`
- Modify: `plugins/spec-distill/tests/test_seed_edit_screen.sh`

**Interfaces:**
- Consumes: Task 1 의 「못박은 것」 표 · `docreview_state.load_state(state_dir) -> dict`(읽기만 — 원장에 쓰지 않는다) · Task 2 의 `build_screen` · `hunk_view`.
- Produces: `parse_reasons(path: str, version: str, hunk_ids: set[int]) -> dict`(`by_hunk: {번호: {"ids": list[str], "self": bool}}` · `dropped: int` · `stale: bool` · `unreadable: bool` · `present: bool`) · `load_ledger(state_dir: str) -> dict | None` · `read_used(state_dir: str) -> set[str] | None`(읽지 못하면 `None`) · `finding_status(st: dict | None, fid: str, used: set[str] | None) -> tuple[str, str]`(갈래 `confirmed` · `used` · `answered` · `unverified` 와 이유 조각) · 모듈 상수 `USED_FILE = "hunk-used-findings.txt"`. Task 4 의 `mark-used` 가 `parse_reasons` · `read_used` · `USED_FILE` 을 쓴다.
- 이유 파일의 꼴(저자가 쓴다): 첫 줄 `seed_sha256 <판본>`, 그 아래 줄마다 `<덩어리 번호><탭><지적 id 들(쉼표) | 없음>`.

- [ ] **Step 1: 실패하는 테스트를 더한다** — `test_seed_edit_screen.sh` 의 마지막 줄 `finish` 바로 앞에 아래 글을 넣는다.

````bash
# ── 원장 fixture — fix 셋(적용 · 처분 전 · 적용하지 않음) · decide 둘(채택 · 거부) · ask 하나(답함) ──
L="$TMP/L"; mkdir -p "$L/state"
printf -- '---\ntype: interview-seed\n---\n\n로그인이 가끔 실패한다.\n' > "$L/s.md"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$L/s.audit.md"
python3 "$S/docreview_state.py" init --state-dir "$L/state" --doc "$L/s.md" --profile "$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md" >/dev/null
python3 "$S/docreview_state.py" begin-round --state-dir "$L/state" >/dev/null
{ printf '```docreview-layer1\n'
  while read -r cat disp summ; do
    printf -- '- ref: c_%s\n  category: %s\n  anchor: "#__doc__"\n  disposition: %s\n  summary: "%s"\n' "$summ" "$cat" "$disp" "$summ"
  done <<'EOF'
premature_closure fix SCR_FIX_APPLY
premature_closure fix SCR_FIX_PENDING
omission fix SCR_FIX_DROP
inference_as_decision decide SCR_DEC_ADOPT
inference_as_decision decide SCR_DEC_REJECT
unfounded_addition ask SCR_ASK
EOF
  printf '```\n```docreview-layer2\n[]\n```\n'; } > "$L/critic.txt"
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$L/state" --critic "$L/critic.txt" > "$L/prep.json"
python3 "$S/docreview_route.py" finalize --state-dir "$L/state" --recritic-skipped --doc "$L/s.md" > "$L/fin.json"
idof() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")==sys.argv[2]][0])' "$L/fin.json" "$1"; }
FA="$(idof SCR_FIX_APPLY)"; FP="$(idof SCR_FIX_PENDING)"; FD="$(idof SCR_FIX_DROP)"; DA="$(idof SCR_DEC_ADOPT)"; DR="$(idof SCR_DEC_REJECT)"; AK="$(idof SCR_ASK)"
python3 "$S/docreview_anchor.py" check-intent "$FA" --intent '#__doc__' --state-dir "$L/state" >/dev/null
python3 "$S/docreview_state.py" fix --state-dir "$L/state" --id "$FD" --event drop --reason="적용하지 않음" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" decide --state-dir "$L/state" --id "$DA" --choice adopt --quote="채택" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" decide --state-dir "$L/state" --id "$DR" --choice reject --quote="기각" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" ask --state-dir "$L/state" --id "$AK" --answered >/dev/null
python3 - "$S" "$L/state" "$FA" "$FP" "$FD" "$DA" "$DR" "$AK" > "$L/pre.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
fa, fp, fd, da, dr, ak = sys.argv[3:9]
last = {i: e["choice"] for e in st["decision_log"] for i in e["finding_ids"]}
print(st["fixes"][fa]["state"], st["fixes"][fp]["state"], st["fixes"][fd]["state"], last[da], last[dr], st["asks"][ak]["answered"])
PY
assert_eq "$(cat "$L/pre.txt")" "intent_passed pending dropped adopt reject True" "전제: 원장 fixture — 적용한 fix · 처분 전 fix · 적용하지 않은 fix · 채택한 decide · 거부한 decide · 답한 ask"
mk2() {   # mk2 <이름> → 덩어리 둘인 화면 + 원장 사본
  mk "$1" '가.\n\n나.\n\n다.\n' '가 고침.\n\n나.\n\n다 고침.\n'
  cp -R "$L/state/." "$TMP/$1/state/"
}
ver() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["seed_sha256"])' "$TMP/$1/hunks.json"; }
why() {   # why <이름> <줄…> → 판본이 맞는 이유 파일. 줄은 printf %b 로 푼다(\t 가 탭)
  local n="$1" l; shift
  { printf 'seed_sha256 %s\n' "$(ver "$n")"; for l in "$@"; do printf '%b\n' "$l"; done; } > "$TMP/$n/state/hunk-reasons.txt"
}
rec() { j "$1" '[h["recommend"] for h in d["hunks"]]'; }
force() {   # force <상태 폴더> <지적 id> <칸> <값> — 엔진의 읽기 · 쓰기로 원장의 한 칸을 바꾼다(decides 의 state · kind, findings 의 summary)
  python3 - "$S" "$1" "$2" "$3" "$4" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
st["decides" if sys.argv[4] in ("state", "kind") else "findings"][sys.argv[3]][sys.argv[4]] = sys.argv[5].replace("\\n", "\n")
ds.save_state(sys.argv[2], st)
PY
}

# ── AC4 — 확인된 덩어리에만 권장 ────────────────────────────────────────────────
mk2 fixok; why fixok "1\t$FA"
before="$(sums "$TMP/fixok/state")"
scr fixok
assert_eq "$(sums "$TMP/fixok/state")" "$before" "AC8: 화면 조립은 원장 자리(원장 · 이유 파일)를 바꾸지 않는다"
assert_eq "$(rec fixok)" "[True, False]" "AC4: 사용자가 적용을 고른 fix 를 댄 덩어리만 권장이다(쓴 지적 목록 파일 없음 — 첫 화면)"
TF="$(j fixok 'd["text"]')"
assert_contains "$TF" "   고친 이유(저자가 댐): 지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분" "AC4: 지적의 한 줄 요약 · id · 처분이 보인다"
assert_contains "$TF" "   고친 이유(저자가 댐): 대응하는 지적 없음 — 저자가 스스로 고침" "AC4: 이유 파일에 없는 덩어리는 대응하는 지적 없음"
assert_eq "$(j fixok 'd["text"].split("\n")[1]')" "(권장) 은 저자가 댄 지적을 사용자가 적용하기로 했다는 뜻입니다 — 편집이 그 지적에 맞는지는 아래 문장으로 직접 보세요" "AC4: 권장이 붙은 화면은 첫머리에 권장의 뜻 한 줄"
mk2 decok; why decok "2\t$DA"; scr decok
assert_eq "$(rec decok)" "[False, True]" "AC4: 사용자가 채택한 decide 를 댄 덩어리도 권장이다"
assert_contains "$(j decok 'd["text"]')" "   고친 이유(저자가 댐): 지적 「SCR_DEC_ADOPT」(${DA}) — 사용자가 채택" "AC4: 채택한 decide 의 이유 줄"
force "$TMP/decok/state" "$DA" state expired; scr decok
assert_eq "$(rec decok)" "[False, True]" "AC4: 결정 항목은 상태 칸이 아니라 고른 쪽으로 가른다(채택 뒤 상태가 expired 여도 권장)"
scr fixok --final
assert_eq "$(rec fixok)" "[False, False]" "AC4: 확정 직전 화면으로 조립하면 같은 입력에서도 권장이 없다"
assert_contains "$(j fixok 'd["text"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분" "AC4: 확정 직전 화면에도 고친 이유 줄은 그대로 보인다"
assert_not_contains "$(j fixok 'd["text"]')" "(권장)" "AC4: 확정 직전 화면 글에는 권장의 뜻 줄도 없다"

# ── AC5 — 권장이 붙지 않는 경우 ─────────────────────────────────────────────────
norec() {   # norec <이름> <라벨> <이유 줄…> — 그 이유로 조립하면 어느 덩어리에도 권장이 없다
  local n="$1" label="$2"; shift 2
  mk2 "$n"; why "$n" "$@"; scr "$n"
  assert_eq "$(rec "$n")" "[False, False]" "AC5: ${label}"
}
norec mixed "「없음」 이 섞인 덩어리" "1\t$FA,없음"
norec unknown "원장에 없는 id" "1\tdeadbeef#r9.9"
assert_contains "$(j unknown 'd["text"]')" "   고친 이유(저자가 댐): 저자가 댄 지적 deadbeef#r9.9 은 원장에서 확인되지 않는다" "AC5: 원장에서 확인되지 않은 id 가 화면에 보인다"
norec dropped "사용자가 적용하지 않기로 한 fix" "1\t$FD"
norec pending "처분 전인 fix" "1\t$FP"
norec partial "댄 지적 가운데 하나가 확인되지 않음" "1\t$FA,$FP"
norec ask "ask 의 답에 따른 편집" "1\t$AK"
assert_contains "$(j ask 'd["text"]')" "지적 「SCR_ASK」(${AK}) — 사용자가 답한 열린 질문" "AC5: ask 의 답에 따른 편집은 이유로만 보인다"
norec rejected "사용자가 거부한 decide" "1\t$DR"
for stt in adopted applied; do
  force "$TMP/rejected/state" "$DR" state "$stt"; scr rejected
  assert_eq "$(rec rejected)" "[False, False]" "AC5: 거부한 decide 는 원장 상태 칸이 ${stt} 여도 권장이 없다"
done
mk2 postkind; why postkind "1\t$DA"; scr postkind
assert_eq "$(rec postkind)" "[True, False]" "AC5 양의 짝: 채택한 decide 는 권장이다"
force "$TMP/postkind/state" "$DA" kind post; scr postkind
assert_eq "$(rec postkind)" "[False, False]" "AC5: 「현재 변경 유지」 로 채택한 항목(kind post)은 고치라는 처분이 아니라 권장이 없다"
mk2 used; why used "1\t$FA"; printf '%s\n' "$FA" > "$TMP/used/state/hunk-used-findings.txt"; scr used
assert_eq "$(rec used)" "[False, False]" "AC5: 쓴 지적 목록에 든 지적"
assert_contains "$(j used 'd["text"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 앞 화면에서 이미 댄 지적" "AC5: 이미 쓴 지적이라는 사실이 화면에 보인다"
mk2 usedbad; why usedbad "1\t$FA"; printf '\377\376' > "$TMP/usedbad/state/hunk-used-findings.txt"; scr usedbad
assert_eq "$(rec usedbad)" "[False, False]" "AC5: 쓴 지적 목록 파일을 읽지 못한 경우(깨짐)"
assert_contains "$(j usedbad 'd["text"]')" "쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다" "AC5: 목록을 읽지 못한 사실이 화면에 보인다"

# ── AC6 — 이유 파일 · 원장이 없거나 어긋날 때 ────────────────────────────────────
mk2 noreason; scr noreason; rc=$?
assert_eq "$rc $(rec noreason)" "0 [False, False]" "AC6: 이유 파일이 없어도 화면이 나온다 — 전부 권장 없음"
mk noledger '가.\n\n나.\n\n다.\n' '가 고침.\n\n나.\n\n다 고침.\n'; why noledger "1\t$FA"; scr noledger; rc=$?
assert_eq "$rc $(rec noledger)" "0 [False, False]" "AC6: 원장이 없어도 화면이 나온다 — 전부 권장 없음"
assert_contains "$(j noledger 'd["text"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 원장을 읽지 못한 사실이 화면에 보인다"
mk2 badledger; why badledger "1\t$FA"; printf 'x' >> "$TMP/badledger/state/docreview-state.md"; scr badledger; rc=$?
assert_eq "$rc $(rec badledger)" "0 [False, False]" "AC6: 깨진 원장도 같다"
assert_contains "$(j badledger 'd["text"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 깨진 원장을 읽지 못한 사실이 보인다"
mk2 stale; printf 'seed_sha256 0000\n1\t%s\n' "$FA" > "$TMP/stale/state/hunk-reasons.txt"; scr stale
assert_eq "$(rec stale)" "[False, False]" "AC6: 이유 파일 첫 줄의 판본이 다르면 이유를 하나도 쓰지 않는다"
assert_contains "$(j stale 'd["text"]')" "이유 파일이 이 공시의 것이 아니다" "AC6: 판본이 다른 사실이 화면에 보인다"
assert_not_contains "$(j stale 'd["text"]')" "SCR_FIX_APPLY" "AC6: 판본이 다른 이유 파일의 지적은 화면에 실리지 않는다"
mk2 nohead; printf '1\t%s\n' "$FA" > "$TMP/nohead/state/hunk-reasons.txt"; scr nohead
assert_eq "$(rec nohead)" "[False, False]" "AC6: 이유 파일에 판본 줄이 없으면 이유를 하나도 쓰지 않는다"
assert_contains "$(j nohead 'd["text"]')" "이유 파일이 이 공시의 것이 아니다" "AC6: 판본 줄이 없는 사실이 화면에 보인다"
mk2 dupok; why dupok "1\t$FA" "1\t$DA"; scr dupok
assert_eq "$(rec dupok)" "[True, False]" "AC6: 같은 덩어리 번호가 여러 줄이면 지적을 합친다(둘 다 확인됨이면 권장)"
assert_contains "$(j dupok 'd["text"]')" "SCR_DEC_ADOPT" "AC6: 합친 지적이 모두 이유 줄에 보인다"
mk2 dupnone; why dupnone "1\t$FA" "1\t없음"; scr dupnone
assert_eq "$(rec dupnone)" "[False, False]" "AC6: 여러 줄 가운데 한 줄이라도 「없음」 이면 권장이 없다"
mk2 badlines; why badlines "1\t$FA" "9\t$FA" "엉뚱한 줄" "x\t$FA"; scr badlines
assert_eq "$(rec badlines)" "[True, False]" "AC6: 없는 덩어리 번호의 줄과 꼴이 아닌 줄은 버리고 나머지는 읽는다"
assert_contains "$(j badlines 'd["text"]')" "이유 파일에서 읽지 못한 줄 3개" "AC6: 버린 줄 수가 화면에 보인다"
mk2 crlf; printf 'seed_sha256 %s\r\n1\t%s\r\n2 %s\r\n' "$(ver crlf)" "$FA" "$DA" > "$TMP/crlf/state/hunk-reasons.txt"; scr crlf
assert_eq "$(rec crlf)" "[True, False]" "Review Focus: 줄 끝이 CRLF 여도 읽고, 탭 대신 공백을 쓴 줄은 버린다(권장 쪽으로 기울지 않는다)"
assert_contains "$(j crlf 'd["text"]')" "이유 파일에서 읽지 못한 줄 1개" "Review Focus: 탭이 없는 줄은 읽지 못한 줄로 센다"
mk2 longsum; why longsum "1\t$FA"; force "$TMP/longsum/state" "$FA" summary '첫 줄\n둘째 줄'; scr longsum
assert_contains "$(j longsum 'd["text"]')" "   고친 이유(저자가 댐): 지적 「첫 줄 둘째 줄」(${FA})" "Review Focus: 여러 줄 요약은 한 줄로 이어 화면 구조를 깨지 않는다"

````

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_seed_edit_screen.sh | grep -c '✗'`
Expected: 0 이 아닌 수(「전제: 원장 fixture」 는 `✓` — 그것이 `✗` 면 fixture 가 틀린 것이니 구현으로 넘어가지 않는다).

- [ ] **Step 3: 구현한다**

  - `parse_reasons` — 파일이 없으면 `present` 거짓 · 빈 결과. UTF-8 로 읽지 못하면 `unreadable` 참. 줄 끝의 `\r` 은 뗀다. 첫 줄을 공백으로 나눠 정확히 `["seed_sha256", version]` 이 아니면 `stale` 참 · 이유를 하나도 쓰지 않는다. 그 아래에서 빈 줄은 건너뛴다. 줄은 첫 탭에서 번호와 값으로 가르고 값은 쉼표로 나눠 양끝 공백을 뗀다 — 탭이 없거나, 번호가 ASCII 숫자가 아니거나, `hunk_ids` 에 없는 번호이거나, 빈 조각이 있으면 그 줄을 버리고 `dropped` 를 하나 올린다. 조각 `없음` 은 그 덩어리의 `self` 를 참으로, 그 밖의 조각은 `ids` 에(같은 id 는 한 번) 더한다. 같은 번호가 여러 줄이면 합쳐진다.
  - `load_ledger` — 함수 안에서 `docreview_state` 를 import 해 `load_state(state_dir)` 를 부르고, 어떤 예외든(원장 없음 · 깨짐 · pyyaml 없음 · import 실패) `None` 을 낸다.
  - `read_used` — `<state_dir>/hunk-used-findings.txt`. 그 경로가 링크면 `None`. 없으면 빈 집합. 있으면 줄마다 양끝 공백을 뗀 비어 있지 않은 글자의 집합. 읽지 못하면(`OSError` · `UnicodeDecodeError`) `None`.
  - `finding_status(st, fid, used)` — Task 1 의 표대로. 조각의 꼴(글자 그대로, `<요약>` 은 `norm(str(summary))`):

    | 갈래 | 조건 | 조각 |
    |---|---|---|
    | `unverified` | `st` 가 `None` 이거나 `fid` 가 `st["findings"]` 에 없다 | `저자가 댄 지적 <id> 은 원장에서 확인되지 않는다` |
    | `used` | 아래 `confirmed` 조건이고 `used` 가 `None` 이 아니며 `fid` 가 그 안에 있다 | `지적 「<요약>」(<id>) — 앞 화면에서 이미 댄 지적` |
    | `confirmed` | `fix` 를 사용자가 「적용」 | `지적 「<요약>」(<id>) — 사용자가 「적용」 으로 처분` |
    | `confirmed` | `decide` 를 사용자가 채택 | `지적 「<요약>」(<id>) — 사용자가 채택` |
    | `answered` | 위가 아니고 `ask` 에 답함 | `지적 「<요약>」(<id>) — 사용자가 답한 열린 질문` |
    | `unverified` | 그 밖 | `저자가 댄 지적 <id> 은 원장에서 확인되지 않는다` |

  - `build_screen` — 이유 파일의 판본은 덩어리 JSON 의 `seed_sha256` 과 견준다. 덩어리마다 댄 지적의 조각을 차례로, `self` 이거나 댄 지적이 없으면 끝에 「대응하는 지적 없음 — 저자가 스스로 고침」 을 더한다. `reason` 은 조각을 ` · ` 로 이은 한 줄, 화면 글은 조각마다 `   고친 이유(저자가 댐): <조각>` 한 줄이다.
  - `recommend` — 댄 지적이 하나 이상이고 **전부** `confirmed` 이며 `self` 가 아니고 `read_used` 가 `None` 이 아니고 `final` 이 거짓일 때만 참.
  - `notices`(이 순서로, 화면 글에서는 머리 줄들 바로 아래 한 줄씩): 이유 파일을 읽지 못함 → 「이유 파일을 읽지 못했다 — 고친 이유를 쓰지 않았다」 · `stale` → 「이유 파일이 이 공시의 것이 아니다 — 고친 이유를 쓰지 않았다」 · `dropped` > 0 → 「이유 파일에서 읽지 못한 줄 N개」 · 원장을 읽지 못함 → 「리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다」 · 쓴 지적 목록을 읽지 못함 → 「쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다」.
  - 권장이 하나라도 참이면 화면 글 둘째 줄에 Global Constraints 의 권장 뜻 한 줄을 싣는다(알림 줄들보다 앞).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_seed_edit_screen.sh | tail -1`
Expected: `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 저자 편집 화면의 고친 이유와 권장 — 원장의 처분만 확인" -m "Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md" -- plugins/spec-distill/scripts/seed_edit_screen.py plugins/spec-distill/tests/test_seed_edit_screen.sh
```

---

### Task 4: 질문 묶음 · 쓴 지적 목록에 더하기 (AC7 · AC10 의 스크립트 몫)

**Files:**
- Modify: `plugins/spec-distill/scripts/seed_edit_screen.py`
- Modify: `plugins/spec-distill/tests/test_seed_edit_screen.sh`
- Modify: `plugins/spec-distill/tests/test_state_dir_writes.sh` (머리 주석 · 스크립트 칸)

**Interfaces:**
- Consumes: Task 3 의 `parse_reasons` · `read_used` · `USED_FILE` · `recommend` · `summary` · `reason`, `nofollow_write.replace_bytes(path, data: bytes)`.
- Produces: `split_sizes(n: int) -> list[int]` · `build_questions(views: list[dict]) -> list[dict]` · CLI `seed_edit_screen.py mark-used --hunks <덩어리 JSON> --reasons <이유 파일> --state-dir <원장 폴더> --ids <쉼표로 이은 번호>`(rc 0 더했거나 더할 것이 없음 · 2 번호가 덩어리 전부와 다름 · 목록을 읽거나 쓰지 못함 · 입력 오류). Task 5 의 처분 펜스가 이 명령을 되돌리기 앞에서 부른다.
- `screen` JSON 의 `questions[]` — 질문마다 `header`(str) · `question`(str) · `multi`(bool) · `hunk_ids`(번호 순 list[int]) · `options`(보일 순서대로 `{"label", "description", "hunk_id"}`).

- [ ] **Step 1: 실패하는 테스트를 더한다** — `test_seed_edit_screen.sh` 의 `finish` 바로 앞에 아래 글을 넣는다.

````bash
# ── AC7 — 질문 묶음 ─────────────────────────────────────────────────────────
mkn() {   # mkn <이름> <n> → 덩어리 n 개(문단마다 하나) + 원장 사본
  mkdir -p "$TMP/$1/state"
  python3 -c 'import sys
n = int(sys.argv[3])
open(sys.argv[1], "w", encoding="utf-8").write("".join("문단 %d.\n\n" % i for i in range(1, n + 1)))
open(sys.argv[2], "w", encoding="utf-8").write("".join("문단 %d 고침.\n\n" % i for i in range(1, n + 1)))' "$TMP/$1/base.md" "$TMP/$1/seed.md" "$2"
  python3 "$S/seed_edit_diff.py" hunks "$TMP/$1/base.md" "$TMP/$1/seed.md" > "$TMP/$1/hunks.json"
  cp -R "$L/state/." "$TMP/$1/state/"
}
qs() { j "$1" '[(q["multi"], q["hunk_ids"]) for q in d["questions"]]'; }
mkn q1 1; scr q1
assert_eq "$(j q1 '[(q["multi"], q["question"], [o["label"] for o in q["options"]]) for q in d["questions"]]')" \
  "[(False, '저자 편집 1곳을 그대로 둘까요?', ['그대로 둔다', '되돌린다'])]" "AC7: 덩어리 하나면 단일 선택이다"
why q1 "1\t$FA"; scr q1
assert_eq "$(j q1 '[o["label"] for o in d["questions"][0]["options"]]')" "['그대로 둔다 (권장)', '되돌린다']" "AC7: 확인된 덩어리 하나면 「그대로 둔다 (권장)」 이 첫 자리다"
mkn q4 4; scr q4
assert_eq "$(qs q4)" "[(True, [1, 2, 3, 4])]" "AC7: 덩어리 넷이면 질문 하나"
assert_eq "$(j q4 '(d["questions"][0]["question"], [o["label"] for o in d["questions"][0]["options"]])')" \
  "('그대로 둘 곳을 고르세요. 고르지 않은 곳은 되돌립니다. 전부 되돌리려면 기타 칸에 적어 주세요.', ['1번 그대로 둔다', '2번 그대로 둔다', '3번 그대로 둔다', '4번 그대로 둔다'])" "AC7: 여러 개 고르기 질문의 글과 선택지 — 선택지는 덩어리뿐이다"
mkn q5 5; scr q5
assert_eq "$(qs q5)" "[(True, [1, 2, 3]), (True, [4, 5])]" "AC7: 다섯이면 3+2"
mkn q9 9; scr q9
assert_eq "$(qs q9)" "[(True, [1, 2, 3, 4]), (True, [5, 6, 7]), (True, [8, 9])]" "AC7: 아홉이면 4+3+2"
why q5 "3\t$FA" "5\t$DA"; scr q5
assert_eq "$(j q5 '[[o["label"] for o in q["options"]] for q in d["questions"]]')" \
  "[['3번 그대로 둔다 (권장)', '1번 그대로 둔다', '2번 그대로 둔다'], ['5번 그대로 둔다 (권장)', '4번 그대로 둔다']]" "AC7: 번호 순으로 나눈 뒤 질문 안에서만 권장을 앞에 둔다"
assert_eq "$(qs q5)" "[(True, [1, 2, 3]), (True, [4, 5])]" "AC7: 권장이 있어도 한 질문의 덩어리 번호는 이어져 있다"
python3 - "$S" > "$TMP/sizes.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
bad = [n for n in range(2, 41) if sum(m.split_sizes(n)) != n or not all(2 <= s <= 4 for s in m.split_sizes(n))]
print(m.split_sizes(1), m.split_sizes(13), bad)
PY
assert_eq "$(cat "$TMP/sizes.txt")" "[1] [4, 4, 3, 2] []" "Review Focus: 덩어리가 많아도(2–40) 나뉜 질문마다 둘에서 넷이고 합이 맞는다"

# ── AC10 — 쓴 지적 목록에 더하기 ─────────────────────────────────────────────────
mu() {   # mu <이름> <ids> [덩어리 JSON 파일 이름] → rc. stderr 는 $TMP/<이름>/mu.err
  python3 "$X" mark-used --hunks "$TMP/$1/${3:-hunks.json}" --reasons "$TMP/$1/state/hunk-reasons.txt" --state-dir "$TMP/$1/state" --ids "$2" >/dev/null 2>"$TMP/$1/mu.err"
}
U="hunk-used-findings.txt"
mk2 mu1; why mu1 "1\t$FA,$DA" "2\t$FA,없음"
mu mu1 "1,2"; rc=$?
assert_eq "$rc" "0" "AC10: 목록에 더하기 rc 0"
assert_eq "$(cat "$TMP/mu1/state/$U")" "$(printf '%s\n%s' "$FA" "$DA")" "AC10: 그 화면의 이유 파일이 댄 지적 id 를 모두 더한다(같은 id 는 한 번)"
mu mu1 "1,2"
assert_eq "$(cat "$TMP/mu1/state/$U")" "$(printf '%s\n%s' "$FA" "$DA")" "AC10: 다시 돌려도 이미 있는 id 를 두 번 적지 않는다"
scr mu1
assert_eq "$(rec mu1)" "[False, False]" "AC10: 더한 뒤 다시 공시한 화면에서는 그 지적에 권장이 붙지 않는다"
mk2 mu2; mu mu2 "1,2"; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu2/state/$U" ] && ok "AC10: 이유 파일이 없으면 아무것도 더하지 않고 성공한다" || no "AC10: 이유 파일이 없는데 rc ${rc} 이거나 목록이 생겼다"
mk2 mu3; printf 'seed_sha256 0000\n1\t%s\n' "$FA" > "$TMP/mu3/state/hunk-reasons.txt"; mu mu3 "1,2"; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu3/state/$U" ] && ok "AC10: 판본이 다른 이유 파일이면 아무것도 더하지 않고 성공한다" || no "AC10: 판본이 다른데 rc ${rc} 이거나 목록이 생겼다"
mk2 mu4; why mu4 "1\t$FA"
for ids in "1" "1,2,3" "1,1,2" ""; do
  mu mu4 "$ids"; rc=$?
  [ "$rc" = 2 ] && [ ! -e "$TMP/mu4/state/$U" ] && ok "AC10: 번호가 덩어리 전부와 같지 않으면(${ids:-빈 값}) 쓰지 않고 rc 2" || no "AC10: 번호 「${ids}」 에 rc ${rc} 이거나 목록이 생겼다"
done
assert_contains "$(cat "$TMP/mu4/mu.err")" "처분 목록의 번호가 이 화면의 덩어리와 다르다" "AC10: 번호가 다른 사유를 알린다"
mk2 mu5; why mu5 "1\t$FA"
printf '가 고침.\n\n나.\n\n다 또 고침.\n' > "$TMP/mu5/seed2.md"
python3 "$S/seed_edit_diff.py" hunks "$TMP/mu5/base.md" "$TMP/mu5/seed2.md" > "$TMP/mu5/hunks-final.json"
mu mu5 "1,2" hunks-final.json; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu5/state/$U" ] && ok "AC10: 넘겨받은 덩어리 JSON 의 판본과 견준다(다른 화면의 JSON 이면 더하지 않는다)" || no "AC10: 다른 판본의 JSON 인데 rc ${rc} 이거나 목록이 생겼다"
mu mu5 "1,2"
assert_eq "$(cat "$TMP/mu5/state/$U" 2>/dev/null)" "$FA" "AC10 양의 짝: 그 화면의 JSON 이면 더한다"
mk2 mu6; why mu6 "1\t$FA"; printf '\377\376' > "$TMP/mu6/state/$U"; cp "$TMP/mu6/state/$U" "$TMP/mu6/used.before"
mu mu6 "1,2"; rc=$?
assert_eq "$rc $(cmp -s "$TMP/mu6/state/$U" "$TMP/mu6/used.before" && echo same)" "2 same" "AC10: 목록을 읽지 못하면 더하지 않고 rc 2 — 파일은 그대로다"

````

- [ ] **Step 2: 상태 폴더 쓰기 락에 새 모듈을 올린다** — `plugins/spec-distill/tests/test_state_dir_writes.sh` 에 아래 diff 를 적용한다(머리 주석 한 줄 · `# ── docreview_state` 앞의 새 칸).

```diff
--- a/plugins/spec-distill/tests/test_state_dir_writes.sh
+++ b/plugins/spec-distill/tests/test_state_dir_writes.sh
@@ -1,6 +1,7 @@
 #!/usr/bin/env bash
 # skill 이 부르는 스크립트의 상태 폴더 쓰기가 마지막 성분의 링크를 따라가지 않는지 실행으로 잰다.
 #   · seed_edit_diff.py — 기준 사본 · .shown · .reverted
+#   · seed_edit_screen.py — 쓴 지적 목록(링크면 읽지 않고 멈춘다)
 #   · docreview_state.py — 원장(링크면 거절 · 제자리 덮어쓰기는 유지) · 시대 표지
 # 세 skill(request-framing · reviewing-brief · spec-review)의 bash 펜스 쓰기는 도출 락(scan_writes)과
 # 펜스를 잘라 실제로 돌리는 끝에서 끝 칸으로 잰다.
@@ -61,6 +62,30 @@ assert_eq "$rc" "0" "sed_revert_markers_link: revert 성공"
 if cmp -s "$c/out/o1.txt" "$c/out/o1.keep"; then ok "sed_revert_markers_link: .shown 바깥 파일 그대로"; else no "sed_revert_markers_link: .shown 바깥 파일이 바뀌었다"; fi
 if [ -e "$c/out/o2.txt" ] || [ -L "$c/out/o2.txt" ]; then no "sed_revert_markers_link: .reverted 바깥 경로가 생겼다"; else ok "sed_revert_markers_link: .reverted 바깥 경로가 생기지 않았다"; fi
 
+# ── seed_edit_screen — 쓴 지적 목록 ─────────────────────────────────────────
+SES="$ROOT/plugins/spec-distill/scripts/seed_edit_screen.py"
+ses_case() {   # ses_case <이름> → 덩어리 하나 · 판본이 맞는 이유 파일(지적 FID_W)
+  mk_case "$1"
+  printf 'alpha\n' > "$T/$1/work/base.md"
+  python3 "$SED" hunks "$T/$1/work/base.md" "$T/$1/work/seed.md" > "$T/$1/work/hunks.json" 2>/dev/null
+  printf 'seed_sha256 %s\n1\tFID_W\n' "$(sha_of "$T/$1/work/seed.md")" > "$T/$1/state/hunk-reasons.txt"
+}
+ses_mark() { python3 "$SES" mark-used --hunks "$1/work/hunks.json" --reasons "$1/state/hunk-reasons.txt" --state-dir "$1/state" --ids 1 >/dev/null 2>&1; }
+ses_case ses_used_plain; c="$T/ses_used_plain"
+ses_mark "$c"; rc=$?
+assert_eq "$rc" "0" "ses_used_plain: 목록에 더하기 rc 0(양의 짝)"
+if plain "$c/state/hunk-used-findings.txt"; then assert_eq "$(cat "$c/state/hunk-used-findings.txt")" "FID_W" "ses_used_plain: 쓴 지적 목록은 id 를 담은 일반 파일"; else no "ses_used_plain: 쓴 지적 목록이 일반 파일이 아니다"; fi
+ses_case ses_used_dangling_link; c="$T/ses_used_dangling_link"
+ln -s "$c/out/new-target" "$c/state/hunk-used-findings.txt"
+ses_mark "$c"; rc=$?
+assert_eq "$rc" "2" "ses_used_dangling_link: 링크인 목록에는 더하지 않고 멈춘다(rc 2)"
+if [ -e "$c/out/new-target" ] || [ -L "$c/out/new-target" ]; then no "ses_used_dangling_link: 바깥 경로가 생겼다"; else ok "ses_used_dangling_link: 바깥 경로가 생기지 않았다"; fi
+ses_case ses_used_live_link; c="$T/ses_used_live_link"
+printf 'outside\n' > "$c/out/o.txt"; ln -s "$c/out/o.txt" "$c/state/hunk-used-findings.txt"
+ses_mark "$c"; rc=$?
+assert_eq "$rc" "2" "ses_used_live_link: 살아 있는 링크인 목록에도 더하지 않고 멈춘다(rc 2)"
+assert_eq "$(cat "$c/out/o.txt")" "outside" "ses_used_live_link: 바깥 파일 그대로"
+
 # ── docreview_state ──────────────────────────────────────────────────────
 mk_case ds_save_symlink_refused; c="$T/ds_save_symlink_refused"
 printf 'outside\n' > "$c/out/o.txt"
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_seed_edit_screen.sh | grep -c '✗'; bash plugins/spec-distill/tests/test_state_dir_writes.sh | grep '✗' | grep -c 'ses_used'`
Expected: 둘 다 0 이 아닌 수.

- [ ] **Step 4: 구현한다**

  - `split_sizes(n)` — `n ≤ 4` 면 `[n]`(0 이면 빈 목록). 넘으면 넷씩 나누고 나머지를 마지막에 두되, 마지막이 1 이면 끝의 둘을 `3, 2` 로 바꾼다(5 → `[3, 2]` · 9 → `[4, 3, 2]` · 13 → `[4, 4, 3, 2]`).
  - `build_questions(views)` — 덩어리가 0 이면 빈 목록. 하나면 하나 고르기 질문 하나: `question` 「저자 편집 1곳을 그대로 둘까요?」, `header` 「저자 편집」, 선택지 「그대로 둔다」(권장이면 「그대로 둔다 (권장)」 — 설명 「이 편집이 seed 에 남는다」) · 「되돌린다」(설명 「이 편집을 지우고 기준 사본의 글로 돌아간다」). 둘 이상이면 번호 순으로 `split_sizes` 대로 나눈 뒤 질문마다: `multi` 참, `question` 은 Global Constraints 의 여러 개 고르기 글, `header` 는 질문이 하나면 「저자 편집」 · 여럿이면 「편집 <첫 번호>–<끝 번호>」, 선택지는 그 질문의 덩어리마다 하나(「<k>번 그대로 둔다」, 권장이면 끝에 「 (권장)」, 설명 `<summary> · <reason>`)이고 권장인 것을 번호 순으로 앞에, 나머지를 번호 순으로 뒤에 둔다. `hunk_ids` 는 늘 번호 순이다.
  - `build_screen` 이 `questions` 를 채운다.
  - `mark-used` — ① `--ids` 를 정수 목록으로 읽어(쉼표 · 빈 조각은 건너뜀, 정수가 아니면 rc 2) 정렬한 것이 덩어리 JSON 의 번호 전부를 정렬한 것과 같지 않으면 stderr 에 「[spec-distill] 처분 목록의 번호가 이 화면의 덩어리와 다르다 — 빠진 번호 <목록> · 없는 번호 <목록>」 을 내고 rc 2(아무것도 쓰지 않는다 — 같은 번호가 두 번 와도 다른 것이다). ② `parse_reasons` 를 그 덩어리 JSON 의 `seed_sha256` 과 덩어리 번호로 부른다 — 이유 파일이 없거나 판본이 다르거나 읽지 못하면 아무것도 더하지 않고 rc 0. ③ `read_used` 가 `None` 이면 stderr 한 줄(경로를 댄다) · rc 2. ④ 이유 파일이 댄 지적 id(`없음` 제외, 덩어리 번호 순 · 적힌 순, 같은 id 는 한 번) 가운데 목록에 없는 것만 끝에 한 줄씩 더한 전체를 `nofollow_write.replace_bytes` 로 쓴다(더할 것이 없으면 쓰지 않는다). 쓰지 못하면 stderr 한 줄 · rc 2. 성공하면 stdout 에 `{"added": [...], "skipped": null | "no_reasons" | "stale_reasons"}`.

- [ ] **Step 5: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_seed_edit_screen.sh | tail -1; bash plugins/spec-distill/tests/test_state_dir_writes.sh | grep -c '✗'`
Expected: `Fail: 0` · `0`.

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 저자 편집 질문 묶음과 쓴 지적 목록 — 번호 전수 대조" -m "Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md" -- plugins/spec-distill/scripts/seed_edit_screen.py plugins/spec-distill/tests/test_seed_edit_screen.sh plugins/spec-distill/tests/test_state_dir_writes.sh
```

---

### Task 5: skill 글 · 펜스 · 락 (AC9 · AC10 의 펜스 배선 · AC11)

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md` (`### 저자 편집 공시` 절 전체 · `## 확정 — proceed 게이트` 의 검사 2 · `### 게이트` 의 사용자 문구 파일 설명 한 구절 · `## 상태` 표의 한 칸)
- Modify: `plugins/spec-distill/tests/test_framing_review_contract.sh`
- Modify: `plugins/spec-distill/tests/test_plain_gate_templates.sh`
- Modify: `shared/tests/fixtures/ask-sites.tsv`

**Interfaces:**
- Consumes: Task 2–4 의 CLI 셋(`preview` · `screen` · `mark-used`)과 `screen` JSON 의 `text` · `questions`.
- Produces: skill 의 펜스 넷(미리 보기 · 공시 · 처분 · 확정 직전의 미리 보기와 공시)과 규칙 문장. 계약 테스트가 잠그는 문장은 **파일에서 한 줄 안에** 있어야 한다(변이가 그 글자를 한 번에 바꿔 본다): 「고르지 않은 덩어리는 「되돌린다」 로 옮긴다」 · 「처분하지 않고 그 질문을 다시 묻는다」 · 「바뀐 문장은 하나도 빼지 않는다」 · 「처분 없이는 다음 단계로 가지 않는다」.

이 과제의 skill 편집은 사용자의 승인 화면을 정하는 글이다 — 리뷰는 규칙이 약해지지 않았는지(빈 답으로 통과 · 권장 자동 통과 · 화면 글 줄이기)를 본다.

- [ ] **Step 1: 계약 테스트를 새 규칙으로 고친다(먼저 실패하게)** — `plugins/spec-distill/tests/test_framing_review_contract.sh` 에 아래 diff 를 적용한다. 요지: `# guards:` 머리와 `--emit-scanned` 목록에 경로 둘 · 차단 문장 변이를 새 문장 넷으로 · 옛 규칙 문장 넷의 부재와 새 문장의 존재 · 목록에 더하기가 되돌리기 앞 · 확정 직전 사본의 두 걸음 · 번호 대조와 revert 실패(fix2 를 둘로) · 공시 펜스의 화면 글과 화면 조립 실패 · 미리 보기 펜스 · 처분 (g)(h)(i) · 추천 전수 검사 변이. 처분 (b)–(f) 의 단언은 그대로다(준비 줄만 `hunks.json` 을 쓴다).

```diff
--- a/plugins/spec-distill/tests/test_framing_review_contract.sh
+++ b/plugins/spec-distill/tests/test_framing_review_contract.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# guards: plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/seed_review_log.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py
+# guards: plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/seed_review_log.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py plugins/spec-distill/scripts/seed_edit_screen.py shared/tests/fixtures/ask-sites.tsv
 #
 # request-framing SKILL 의 **계약** 락 — 설계 2026-09-16-framing-intent-drift 의 AC 중 SKILL 문면과
 # 배선으로 재는 것(AC1 · AC3b · AC3d · AC4 · AC6 · AC12 · AC13 배선).
@@ -13,7 +13,8 @@ SK="$ROOT/plugins/spec-distill/skills/request-framing/SKILL.md"
 if [ "${1:-}" = "--emit-scanned" ]; then
   for f in plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md \
            plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/seed_review_log.py \
-           shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py; do
+           shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py \
+           plugins/spec-distill/scripts/seed_edit_screen.py shared/tests/fixtures/ask-sites.tsv; do
     echo "$f"
   done
   exit 0
@@ -104,16 +105,19 @@ blocking_fails() {   # blocking_fails <SKILL 경로> → 빠진 차단 문장 
   f="$(section "$1" '^## 확정 — proceed 게이트$' | tr '\n' ' ' | tr -s ' ')"
   printf '%s' "$g" | grep -qF '하나라도 0 이 아니면 라운드 게이트를 띄운다' || echo "gate_open_rule"
   printf '%s' "$g" | grep -qF '`round_gate_needed` 가 거짓이어도' || echo "gate_engine_override"
-  printf '%s' "$d" | grep -qF '덩어리마다 질문 하나' || echo "hunk_question"
+  printf '%s' "$d" | grep -qF '고르지 않은 덩어리는 「되돌린다」 로 옮긴다' || echo "hunk_question"
+  printf '%s' "$d" | grep -qF '처분하지 않고 그 질문을 다시 묻는다' || echo "hunk_reask"
+  printf '%s' "$d" | grep -qF '바뀐 문장은 하나도 빼지 않는다' || echo "hunk_sentences"
   printf '%s' "$d" | grep -qF '처분 없이는 다음 단계로 가지 않는다' || echo "hunk_blocks"
   printf '%s' "$f" | grep -qF '하나라도 막히면 게이트를 띄우지 않습니다' || echo "final_blocks"
 }
 bf="$(blocking_fails "$SK")"
-[ -z "$bf" ] && ok "차단 문장 다섯이 제자리에 있다(게이트 열기 · 엔진 무시 · 덩어리 질문 · 덩어리 차단 · 확정 차단)" \
+[ -z "$bf" ] && ok "차단 문장 일곱이 제자리에 있다(게이트 열기 · 엔진 무시 · 고르지 않은 덩어리 · 다시 묻기 · 바뀐 문장 · 덩어리 차단 · 확정 차단)" \
   || no "차단 문장 빠짐: $(printf '%s' "$bf" | tr '\n' ' ')"
 TMPB="$(mktemp -d -t sd-framing-block-XXXXXX)" || exit 1
 for pair in "gate_open_rule|하나라도 0 이 아니면 라운드 게이트를 띄운다" "gate_engine_override|가 거짓이어도" \
-            "hunk_question|덩어리마다 질문 하나" "hunk_blocks|처분 없이는 다음 단계로 가지 않는다" \
+            "hunk_question|고르지 않은 덩어리는 「되돌린다」 로 옮긴다" "hunk_reask|처분하지 않고 그 질문을 다시 묻는다" \
+            "hunk_sentences|바뀐 문장은 하나도 빼지 않는다" "hunk_blocks|처분 없이는 다음 단계로 가지 않는다" \
             "final_blocks|하나라도 막히면 게이트를 띄우지 않습니다"; do
   name="${pair%%|*}"; phrase="${pair#*|}"
   PH="$phrase" python3 -c '
@@ -138,7 +142,20 @@ DISC="$(subsection "$SK" '^### 저자 편집 공시')"
 DB="$(bash_lines "$DISC")"
 assert_contains "$DB" 'seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "AC6: 공시 펜스가 기준 사본 diff 를 낸다(실행 줄)"
 assert_contains "$DISC" "저자 편집 없음" "AC6: 빈 diff 를 침묵과 구분한다"
-assert_contains "$DISC" "추천을 달지 않는다 — " "D15: 덩어리 처분에 저자 권장이 없다"
+assert_contains "$DISC" "추천을 달지 않는다 — 기준 사본이 없어" "기준 사본이 없는 길의 질문에는 추천이 없다(이유와 함께)"
+# ── AC9 — 두 걸음 · 이유 파일 · 한 묶음 질문 · 화면 조립 실패 ─────────────────────
+for old in "덩어리마다 질문 하나" "추천을 달지 않는다 — 어느 덩어리가" "줄이면 공시가 아니다" "따로 정한 자리"; do
+  assert_not_contains "$DISC" "$old" "AC9: 옛 규칙 문장이 없다 — ${old}"
+done
+assert_contains "$DB" 'rm -f "$STATE_DIR/hunk-reasons.txt"' "AC9: 미리 보기 펜스가 지난 이유 파일을 지운다(실행 줄)"
+assert_contains "$DB" 'seed_edit_screen.py" preview "$SEED_BASE" "$SEED_ABS"' "AC9: 미리 보기 펜스가 덩어리와 판본을 낸다(실행 줄)"
+assert_contains "$DB" 'seed_edit_screen.py" screen --hunks "$STATE_DIR/hunks.json" --reasons "$STATE_DIR/hunk-reasons.txt" --state-dir "$STATE_DIR")' "AC9: 공시 펜스가 화면을 조립한다(실행 줄 — 확정 직전 표시 없이)"
+for must in '첫 줄은 미리 보기가 낸 판본 `seed_sha256 <값>`' '고르지 않은 덩어리는 「되돌린다」 로 옮긴다' \
+            '그 덩어리가 든 질문의 답 전체를 글자 그대로 적는다' '전부 되돌리려면 기타 칸에 적어 주세요' \
+            '처분하지 않고 그 질문을 다시 묻는다' '화면 조립 실패 — 줄 전체를 보인다' '그때 질문은 권장 없이 낸다' \
+            '목록에 더하지 못하면 되돌리기 · 기록 · 교체를 하지 않습니다' '미리 보기는 `hunks` 를 부르지 않습니다'; do
+  assert_contains "$DISC" "$must" "AC9: 저자 편집 공시가 적는다 — ${must}"
+done
 ln_rev="$(printf '%s\n' "$DB" | grep -n 'seed_edit_diff.py" revert' | head -1 | cut -d: -f1)"
 ln_log="$(printf '%s\n' "$DB" | grep -n 'seed_review_log.py" log' | head -1 | cut -d: -f1)"
 ln_acc="$(printf '%s\n' "$DB" | grep -n 'seed_edit_diff.py" accept' | head -1 | cut -d: -f1)"
@@ -147,6 +164,12 @@ if [ -n "$ln_rev" ] && [ -n "$ln_log" ] && [ -n "$ln_acc" ] && [ "$ln_rev" -lt "
 else
   no "AC6b: revert($ln_rev) · log($ln_log) · accept($ln_acc) 순서가 아니다 — 공시 전 교체는 그 사이 편집을 지운다"
 fi
+ln_used="$(printf '%s\n' "$DB" | grep -n 'seed_edit_screen.py" mark-used' | head -1 | cut -d: -f1)"
+if [ -n "$ln_used" ] && [ -n "$ln_rev" ] && [ "$ln_used" -lt "$ln_rev" ]; then
+  ok "AC10: 쓴 지적 목록에 더하기가 되돌리기 앞이다"
+else
+  no "AC10: mark-used($ln_used) 가 revert($ln_rev) 앞이 아니다 — 목록보다 기준 사본이 먼저 바뀔 수 있다"
+fi
 # ── T10-b — revert · accept 의 rc 4(공시 뒤 seed 재변경) 처리 규약 ────────────
 assert_contains "$DISC" "위 공시 펜스를 다시 돌려 다시 처분받습니다" "T10-b: rc 4 는 기준 사본을 바꾸지 않고 공시를 다시 돈다"
 assert_contains "$DISC" "처분 하나에 한 번만" "T10-b: revert 는 처분마다 한 번만 — --ids 를 쉼표로 모아 한 번에"
@@ -157,6 +180,8 @@ FIN="$(section "$SK" '^## 확정 — proceed 게이트$')"
 FB="$(bash_lines "$FIN")"
 assert_contains "$FB" 'seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "AC6: 확정 게이트 직전에도 공시 펜스(실행 줄)"
 assert_contains "$FB" 'seed_review_log.py" check-drops' "AC12: 확정 게이트 직전 문구 없는 drop 검사(실행 줄)"
+assert_contains "$FB" 'seed_edit_screen.py" preview "$SEED_BASE" "$SEED_ABS"' "AC9: 확정 게이트 직전 검사 2 도 미리 보기부터 한다(실행 줄)"
+assert_contains "$FB" 'screen --hunks "$STATE_DIR/hunks-final.json" --reasons "$STATE_DIR/hunk-reasons.txt" --state-dir "$STATE_DIR" --final)' "AC9: 확정 직전 화면은 권장 없이 조립한다(실행 줄)"
 
 # ── AC13 — 표시 검사 배선 ─────────────────────────────────────────────────────
 AFTER="$(subsection "$SK" '^### seed 를 쓴 직후')"
@@ -353,18 +378,31 @@ assert_eq "$(cmp -s "$T/marksB/seed.md" "$T/marksB/seed.before" && echo same)" "
 mkdir -p "$T/revert1"
 printf 'line one\n' > "$T/revert1/base.md"
 printf 'line one changed\n' > "$T/revert1/seed.md"
-python3 "$S/seed_edit_diff.py" hunks "$T/revert1/base.md" "$T/revert1/seed.md" >/dev/null
+python3 "$S/seed_edit_diff.py" hunks "$T/revert1/base.md" "$T/revert1/seed.md" > "$T/revert1/hunks.json"
 cp "$T/revert1/base.md" "$T/revert1/base.before"
 cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/revert1/a.audit.md"
 n6_before="$(grep -c '^- 편집' "$T/revert1/a.audit.md" || true)"
-nth_bash_with "$DISC" 'seed_edit_diff.py" revert' | sed \
-  -e 's/<덩어리마다 한 줄 — 번호:처분>/99:되돌린다/' \
-  -e 's/<n>/1/' > "$T/revert_fence.sh"
-printf 'QUOTE_99\n' > "$T/revert1/said-hunk-99.txt"
+rev_fence() {   # rev_fence <PAIRS 한 줄> → 자리표를 채운 처분 펜스
+  nth_bash_with "$DISC" 'seed_edit_diff.py" revert' | sed \
+    -e "s/<덩어리마다 한 줄 — 번호:처분>/$1/" \
+    -e 's/<덩어리 JSON 파일 이름>/hunks.json/' \
+    -e 's/<n>/1/'
+}
 coldr() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$T/revert1" SEED_BASE="$T/revert1/base.md" SEED_ABS="$T/revert1/seed.md" AUDIT_ABS="$T/revert1/a.audit.md" bash "$1" 2>"$1.err"; }
+# (i) 그 화면에 없는 번호 — 번호 대조가 되돌리기 앞에서 막는다
+rev_fence '99:되돌린다' > "$T/revert_fence.sh"
+printf 'QUOTE_99\n' > "$T/revert1/said-hunk-99.txt"
 outR="$(coldr "$T/revert_fence.sh")"
+assert_contains "$outR" "rev_rc=0 log_rc=0 used_rc=2" "AC10: 그 화면에 없는 덩어리 번호(99)는 번호 대조에서 막힌다 — revert 를 부르지 않는다"
+assert_contains "$(cat "$T/revert_fence.sh.err")" "처분 목록의 번호가 이 화면의 덩어리와 다르다" "AC10: 번호가 다른 사유를 알린다"
+# (ii) revert 실패 — 공시 뒤에 seed 가 또 바뀌었다(rc 4)
+printf 'line one changed again\n' > "$T/revert1/seed.md"
+rev_fence '1:되돌린다' > "$T/revert_fence2.sh"
+printf 'QUOTE_1\n' > "$T/revert1/said-hunk-1.txt"
+outR2="$(coldr "$T/revert_fence2.sh")"
 n6_after="$(grep -c '^- 편집' "$T/revert1/a.audit.md" || true)"
-assert_contains "$outR" "rev_rc=2" "fix2: 없는 덩어리 번호(--ids 99) 는 revert rc 2 로 막힌다"
+assert_contains "$outR2" "rev_rc=4" "fix2: 공시 뒤 seed 가 바뀌면 revert 가 rc 4 로 막힌다"
+assert_not_contains "$outR$outR2" "accept_rc=" "fix2: 번호 대조 · revert 가 막히면 accept 를 부르지 않는다"
 assert_eq "$(cmp -s "$T/revert1/base.md" "$T/revert1/base.before" && echo same)" "same" "fix2: revert 실패면 기준 사본(accept)이 바뀌지 않는다"
 assert_eq "$n6_after" "$n6_before" "fix2: revert 실패면 log 도 돌지 않는다 — audit ## 6 에 편집 줄이 늘지 않는다"
 
@@ -373,6 +411,9 @@ assert_eq "$n6_after" "$n6_before" "fix2: revert 실패면 log 도 돌지 않는
 # 있는 채로 돌려, 편집이 없으면 «저자 편집 없음» 을, 있으면 덩어리를 내는지 본다.
 nth_bash_with "$DISC" 'hunks.json' > "$T/round_disc.sh"
 [ -s "$T/round_disc.sh" ] && ok "추출: 라운드 게이트 앞 공시 펜스" || no "추출: 라운드 게이트 앞 공시 펜스가 비었다"
+# 화면 조립이 실패하는 플러그인 사본 — 스크립트를 링크째 풀어 베끼고 화면 조립만 실패하는 대역으로 바꾼다
+mkdir -p "$T/sdbad"; cp -RL "$ROOT/plugins/spec-distill/scripts" "$T/sdbad/scripts"
+printf 'import sys\nsys.exit(1)\n' > "$T/sdbad/scripts/seed_edit_screen.py"
 for fence in round_disc final_disc; do
   mkdir -p "$T/d-$fence"
   printf 'SAME 줄 하나\nSAME 줄 둘\n' > "$T/d-$fence/seed.md"; cp "$T/d-$fence/seed.md" "$T/d-$fence/base.md"
@@ -384,9 +425,35 @@ for fence in round_disc final_disc; do
   [ -s "$T/d-$fence/base.md.shown" ] && ok "$fence: 공시가 보인 판본을 못박았다(.shown)" || no "$fence: .shown 이 없다 — 이 공시 뒤의 revert · accept 가 rc 4 로 막힌다"
   printf 'SAME 줄 하나\nEDITED_BY_AUTHOR 줄 둘\n' > "$T/d-$fence/seed.md"
   outH="$(coldx "$T/$fence.sh" STATE_DIR="$T/d-$fence" SEED_BASE="$T/d-$fence/base.md" SEED_ABS="$T/d-$fence/seed.md")"
-  assert_contains "$outH" "덩어리 1 — 기준" "$fence: 편집이 있으면 덩어리 머리줄을 낸다"
-  assert_contains "$outH" "+ EDITED_BY_AUTHOR 줄 둘" "$fence: 편집된 줄을 줄임 없이 낸다"
+  if grep -q 'seed_edit_diff.py" hunks' "$T/$fence.sh" && grep -q 'seed_edit_screen.py" screen' "$T/$fence.sh" && grep -qF 'print(d["text"])' "$T/$fence.sh"; then
+    ok "$fence: 펜스 하나가 hunks(공시 기록)와 화면 글 내기를 함께 한다"
+  else
+    no "$fence: hunks 와 화면 글 내기가 한 펜스에 없다 — 화면 없이 공시 기록만 남는 길이 생긴다"
+  fi
+  assert_contains "$outH" "1) 기준 2행 → 현재 2행" "$fence: 편집이 있으면 덩어리 머리줄을 낸다"
+  assert_contains "$outH" "   뺀 문장: SAME 줄 둘" "$fence: 뺀 문장을 낸다"
+  assert_contains "$outH" "   더한 문장: EDITED_BY_AUTHOR 줄 둘" "$fence: 더한 문장을 하나도 빼지 않고 낸다"
+  assert_not_contains "$outH" "SAME 줄 하나" "$fence: 그대로인 줄은 화면에 없다"
+  assert_contains "$outH" '질문 묶음: [{' "$fence: 질문 묶음을 낸다"
   assert_not_contains "$outH" "저자 편집 없음" "$fence: 편집이 있는데 «저자 편집 없음» 을 내지 않는다"
+  outX="$(coldx "$T/$fence.sh" SD="$T/sdbad" STATE_DIR="$T/d-$fence" SEED_BASE="$T/d-$fence/base.md" SEED_ABS="$T/d-$fence/seed.md")"
+  assert_contains "$outX" "화면 조립 실패 — 줄 전체를 보인다" "$fence: 화면 조립이 실패하면 그 사실을 알린다(공시는 막히지 않는다)"
+  assert_contains "$outX" "+ EDITED_BY_AUTHOR 줄 둘" "$fence: 화면 조립이 실패하면 편집된 줄을 줄임 없이 낸다"
+  assert_not_contains "$outX" "(권장)" "$fence: 화면 조립이 실패한 화면에는 권장이 없다"
+  [ -s "$T/d-$fence/base.md.shown" ] && ok "$fence: 화면 조립이 실패해도 공시 기록(.shown)은 남는다" || no "$fence: 화면 조립 실패 뒤 .shown 이 없다"
+done
+nth_bash_with "$DISC" 'seed_edit_screen.py" preview' > "$T/round_pv.sh"
+nth_bash_with "$FIN" 'seed_edit_screen.py" preview' > "$T/final_pv.sh"
+for fence in round_pv final_pv; do
+  [ -s "$T/$fence.sh" ] && ok "추출: 미리 보기 펜스($fence)" || no "추출: 미리 보기 펜스($fence)가 비었다 — 아래 판정은 무의미하다"
+  mkdir -p "$T/p-$fence"
+  printf 'SAME 줄\n' > "$T/p-$fence/base.md"; printf 'EDIT 줄\n' > "$T/p-$fence/seed.md"; printf 'STALE_REASONS\n' > "$T/p-$fence/hunk-reasons.txt"
+  outP="$(coldx "$T/$fence.sh" STATE_DIR="$T/p-$fence" SEED_BASE="$T/p-$fence/base.md" SEED_ABS="$T/p-$fence/seed.md")"
+  [ ! -e "$T/p-$fence/hunk-reasons.txt" ] && ok "$fence: 미리 보기 펜스가 지난 이유 파일을 지운다" || no "$fence: 지난 이유 파일이 남았다 — 다른 공시의 이유가 이 덩어리에 붙는다"
+  assert_contains "$outP" '"seed_sha256"' "$fence: 미리 보기가 판본을 낸다"
+  assert_contains "$outP" 'EDIT 줄' "$fence: 미리 보기가 덩어리를 낸다"
+  [ ! -e "$T/p-$fence/base.md.shown" ] && ok "$fence: 미리 보기는 공시 기록(.shown)을 남기지 않는다" || no "$fence: 미리 보기가 공시 기록을 남겼다"
+  assert_not_contains "$(cat "$T/$fence.sh")" 'seed_edit_diff.py' "$fence: 미리 보기 펜스는 hunks 를 부르지 않는다"
 done
 
 # ── 처분 펜스 — 성공 경로(되돌리기 → 기록 → 교체) · 기록 실패 · 부분 실패 뒤 재실행 ──────────
@@ -395,6 +462,7 @@ disp_fence() {   # disp_fence <PAIRS(줄바꿈은 \n 으로)> → 자리표를 
 import os, sys
 t = sys.stdin.read()
 t = t.replace("<덩어리마다 한 줄 — 번호:처분>", os.environ["PAIRS_IN"].replace("\\n", "\n"), 1)
+t = t.replace("<덩어리 JSON 파일 이름>", "hunks.json", 1)
 sys.stdout.write(t.replace("<n>", "1"))
 '
 }
@@ -402,7 +470,7 @@ setup_disp() {   # setup_disp <디렉토리> → base · seed(한 줄 편집) ·
   mkdir -p "$1"
   printf 'KEEP 줄\nBASE_LINE 줄\n' > "$1/base.md"; printf 'KEEP 줄\nAUTHOR_EDIT 줄\n' > "$1/seed.md"
   cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$1/a.audit.md"
-  python3 "$S/seed_edit_diff.py" hunks "$1/base.md" "$1/seed.md" >/dev/null
+  python3 "$S/seed_edit_diff.py" hunks "$1/base.md" "$1/seed.md" > "$1/hunks.json"
 }
 coldd() { coldx "$1" STATE_DIR="$2" SEED_BASE="$2/base.md" SEED_ABS="$2/seed.md" AUDIT_ABS="$2/a.audit.md"; }
 n_edit() { grep -c '^- 편집 · ' "$1/a.audit.md" || true; }
@@ -437,8 +505,8 @@ mkdir -p "$T/dispD"
 printf 'L1\nBASE_2\nL3\nL4\nL5\nL6\nBASE_7\nL8\n' > "$T/dispD/base.md"
 printf 'L1\nEDIT_2\nL3\nL4\nL5\nL6\nEDIT_7\nL8\n' > "$T/dispD/seed.md"
 cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/dispD/a.audit.md"
-python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" > "$T/dispD/h.json"
-assert_eq "$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["hunks"]))' "$T/dispD/h.json")" "2" "처분 (d) 전제: 덩어리 둘"
+python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" > "$T/dispD/hunks.json"
+assert_eq "$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["hunks"]))' "$T/dispD/hunks.json")" "2" "처분 (d) 전제: 덩어리 둘"
 cp "$T/dispD/base.md" "$T/dispD/base.before"
 printf '   \n' > "$T/dispD/said-hunk-1.txt"; printf 'QUOTE_D2\n' > "$T/dispD/said-hunk-2.txt"
 disp_fence '1:되돌린다\n2:그대로 둔다' > "$T/dispD.sh"
@@ -456,7 +524,7 @@ assert_eq "$(n_edit "$T/dispD")" "3" "처분 (d): 다시 돈 만큼 편집 줄
 assert_eq "$(cmp -s "$T/dispD/base.md" "$T/dispD/seed.md" && echo same)" "same" "처분 (d): 교체 뒤 기준 사본 = seed"
 # (e) 재사용 없음 — 끝난 처분 뒤 새 공시에 Write 없이 돌리면 지난 문구를 쓰지 않는다
 printf 'L1\nBASE_2\nL3\nL4\nL5\nL6\nEDIT_7_AGAIN\nL8\n' > "$T/dispD/seed.md"
-python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" >/dev/null
+python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" > "$T/dispD/hunks.json"
 outE2="$(coldd "$T/dispD.sh" "$T/dispD")"
 assert_contains "$outE2" "pre_rc=2" "처분 (e): Write 없이 다시 돌리면 지난 문구를 쓰지 않고 멈춘다"
 assert_eq "$(n_edit "$T/dispD")" "3" "처분 (e): 재사용 시도가 줄을 남기지 않았다"
@@ -466,11 +534,64 @@ disp_fence '1:그대로 둔다' > "$T/dispF.sh"
 outF1="$(coldd "$T/dispF.sh" "$T/dispF")"
 assert_contains "$outF1" "accept_rc=0" "처분 (f) 전제: 첫 공시의 처분이 끝난다"
 printf 'KEEP 줄\nAUTHOR_EDIT 줄\nSECOND_EDIT 줄\n' > "$T/dispF/seed.md"
-python3 "$S/seed_edit_diff.py" hunks "$T/dispF/base.md" "$T/dispF/seed.md" >/dev/null
+python3 "$S/seed_edit_diff.py" hunks "$T/dispF/base.md" "$T/dispF/seed.md" > "$T/dispF/hunks.json"
 printf 'QUOTE_SAME\n' > "$T/dispF/said-hunk-1.txt"
 outF2="$(coldd "$T/dispF.sh" "$T/dispF")"
 assert_contains "$outF2" "accept_rc=0" "처분 (f): 둘째 공시의 처분도 끝난다"
 assert_eq "$(grep -c '^- 편집 · r1 · 덩어리 1 · 그대로 둔다 · "QUOTE_SAME" —$' "$T/dispF/a.audit.md")" "2" "처분 (f): 같은 라운드 두 공시의 처분은 글자가 같아도 두 줄로 남는다"
+# (g) 쓴 지적 목록 — 그 화면의 이유 파일이 댄 지적 id 를 되돌리기 앞에서 더한다
+why_disp() {   # why_disp <디렉토리> <지적 id 들(쉼표)> → 판본이 맞는 이유 파일(덩어리 1)
+  printf 'seed_sha256 %s\n1\t%s\n' "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["seed_sha256"])' "$1/hunks.json")" "$2" > "$1/hunk-reasons.txt"
+}
+setup_disp "$T/dispG"; printf 'QUOTE_G\n' > "$T/dispG/said-hunk-1.txt"; why_disp "$T/dispG" "FID_G1,FID_G2"
+disp_fence '1:그대로 둔다' > "$T/dispG.sh"
+outG="$(coldd "$T/dispG.sh" "$T/dispG")"
+assert_contains "$outG" "pre_rc=0 rev_rc=0 log_rc=0 used_rc=0" "처분 (g): 목록에 더하기 · 기록이 성공한다"
+assert_contains "$outG" "accept_rc=0" "처분 (g): 끝까지 간다"
+assert_eq "$(cat "$T/dispG/hunk-used-findings.txt" 2>/dev/null)" "$(printf 'FID_G1\nFID_G2')" "AC10: 처분 펜스가 그 화면의 이유 파일이 댄 지적 id 를 쓴 지적 목록에 더한다"
+# (h) 목록에 더하지 못하면 — 되돌리기 · 기록 · 교체를 하지 않는다
+setup_disp "$T/dispH"; printf 'QUOTE_H\n' > "$T/dispH/said-hunk-1.txt"; why_disp "$T/dispH" "FID_H"
+printf '\377\376' > "$T/dispH/hunk-used-findings.txt"
+cp "$T/dispH/base.md" "$T/dispH/base.before"; cp "$T/dispH/seed.md" "$T/dispH/seed.before"
+disp_fence '1:되돌린다' > "$T/dispH.sh"
+outH2="$(coldd "$T/dispH.sh" "$T/dispH")"
+assert_contains "$outH2" "rev_rc=0 log_rc=0 used_rc=2" "AC10: 쓴 지적 목록에 더하지 못하면 멈춘다"
+assert_not_contains "$outH2" "accept_rc=" "AC10: 더하지 못하면 accept 를 부르지 않는다"
+assert_eq "$(cmp -s "$T/dispH/seed.md" "$T/dispH/seed.before" && cmp -s "$T/dispH/base.md" "$T/dispH/base.before" && echo same)" "same" "AC10: 더하지 못하면 seed 도 기준 사본도 그대로다(되돌리기 전에 멈췄다)"
+assert_eq "$(n_edit "$T/dispH")" "0" "AC10: 더하지 못하면 편집 줄을 남기지 않는다"
+assert_contains "$(cat "$T/dispH.sh.err")" "쓴 지적 목록에 더하지 못했다" "AC10: 멈춘 까닭을 알린다"
+# (i) 처분 목록에서 덩어리 하나가 빠졌다 — 아무것도 바뀌지 않는다
+mkdir -p "$T/dispI"
+printf 'L1\nBASE_2\nL3\nL4\nL5\nL6\nBASE_7\nL8\n' > "$T/dispI/base.md"
+printf 'L1\nEDIT_2\nL3\nL4\nL5\nL6\nEDIT_7\nL8\n' > "$T/dispI/seed.md"
+cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/dispI/a.audit.md"
+python3 "$S/seed_edit_diff.py" hunks "$T/dispI/base.md" "$T/dispI/seed.md" > "$T/dispI/hunks.json"
+printf 'QUOTE_I\n' > "$T/dispI/said-hunk-1.txt"; why_disp "$T/dispI" "FID_I"
+cp "$T/dispI/base.md" "$T/dispI/base.before"; cp "$T/dispI/seed.md" "$T/dispI/seed.before"
+disp_fence '1:그대로 둔다' > "$T/dispI.sh"
+outI="$(coldd "$T/dispI.sh" "$T/dispI")"
+assert_contains "$outI" "used_rc=2" "AC10: 처분 목록의 번호가 그 화면의 덩어리 전부와 같지 않으면 멈춘다"
+assert_not_contains "$outI" "accept_rc=" "AC10: 번호가 빠진 처분 목록으로는 accept 를 부르지 않는다"
+assert_eq "$(cmp -s "$T/dispI/seed.md" "$T/dispI/seed.before" && cmp -s "$T/dispI/base.md" "$T/dispI/base.before" && echo same)" "same" "AC10: 번호가 빠진 처분 목록으로는 seed 도 기준 사본도 바뀌지 않는다"
+assert_eq "$(n_edit "$T/dispI")" "0" "AC10: 번호가 빠진 처분 목록으로는 편집 줄을 남기지 않는다"
+[ ! -e "$T/dispI/hunk-used-findings.txt" ] && ok "AC10: 번호가 빠진 처분 목록으로는 쓴 지적 목록도 바뀌지 않는다" || no "AC10: 번호가 빠졌는데 쓴 지적 목록이 생겼다"
+
+# ── AC11 — 추천 전수 검사가 이 자리의 새 규칙을 잰다(지우면 실패) ────────────────────
+RFREL="plugins/spec-distill/skills/request-framing/SKILL.md"
+mkdir -p "$T/ar/plugins/spec-distill/skills/request-framing"
+grep -F "$RFREL" "$ROOT/shared/tests/fixtures/ask-sites.tsv" > "$T/ar/sites.tsv"
+printf '%s\n' "$RFREL" > "$T/ar/list.txt"
+ar_no() { python3 "$ROOT/shared/tests/ask_recommendation.py" "$T/ar" "$T/ar/list.txt" "$T/ar/sites.tsv" | grep '^no ' || true; }
+cp "$SK" "$T/ar/$RFREL"
+assert_eq "$(ar_no)" "" "AC11 양성 대조: request-framing 의 질문 자리 행이 전부 통과한다"
+assert_eq "$(grep -c '처분을 한 묶음으로 묻는다' "$T/ar/sites.tsv" || true)" "1" "AC11 전제: 목록에 덩어리 질문 행이 있다"
+OLD='번 그대로 둔다 (권장)」 이 된다' NEW='번 그대로 둔다」 이 된다' python3 -c '
+import os, sys
+t = open(sys.argv[1], encoding="utf-8").read()
+open(sys.argv[1], "w", encoding="utf-8").write(t.replace(os.environ["OLD"], os.environ["NEW"], 1))
+sys.exit(0 if os.environ["OLD"] in t else 3)
+' "$T/ar/$RFREL" || no "AC11 변이: 치환 대상을 못 찾았다 — 이 변이는 아무것도 재지 않았다"
+assert_contains "$(ar_no)" "꼬리 「- 덩어리가 있으면 **처분을 한 묶음으로 묻는다**」" "AC11 변이: 권장 라벨 문장을 지우면 추천 전수 검사가 그 행에서 실패한다"
 
 # ── 확정 직전 검사 셋 — 엔진 자리가 사라졌거나(세션 정리) 라운드가 시작되지 않았을 때 ──
 nth_bash_with "$FIN" 'gate-final.json' > "$T/final_drops.sh"
```

- [ ] **Step 2: 나머지 락 둘을 고친다** — `plugins/spec-distill/tests/test_plain_gate_templates.sh`:

```diff
--- a/plugins/spec-distill/tests/test_plain_gate_templates.sh
+++ b/plugins/spec-distill/tests/test_plain_gate_templates.sh
@@ -78,7 +78,8 @@ assert_eq "$(printf '%s' "$FR_FLAT" | grep -oE '게이트 질문 텍스트|게
 assert_file_grep "$FR" 'disclosure=proceed 게이트 앞 글' "Q3 양의 짝: 처분 앵커가 새 이름을 댄다"
 
 # ⑧ 질문에 그대로 남는 예외가 명시돼 있다(Q4).
-assert_file_grep "$FR" '규칙 블록의 「따로 정한 자리」' "Q4: 저자 편집 덩어리를 질문에 그대로 싣는 것이 예외라고 적혀 있다"
+assert_file_absent "$FR" '규칙 블록의 「따로 정한 자리」' "Q4: 저자 편집 덩어리를 질문에 그대로 싣는 예외가 없다"
+assert_file_grep "$FR" '공시 펜스가 낸 화면 글은 게이트 앞 글에 그대로 한 번 싣는다' "Q4 양의 짝: 저자 편집 화면은 게이트 앞 글에 싣고 질문 본문에는 결정 한 줄만 둔다"
 
 # ⑨ 게이트 질문의 「경고 N개」는 렌더 첫 줄의 N 이다 — 첫 줄은 같은 사실의 원문들을 한 줄로 합쳐 사실을 세므로
 #    앞 글에 `advisory[]` 원문을 다시 늘어놓으면 질문의 N 과 앞 글의 줄 수가 갈린다(계획 Q9). 줄바꿈을 접어 잰다.
```

`shared/tests/fixtures/ask-sites.tsv` — `- 덩어리가 있으면 **덩어리마다 질문 하나**` 행(종류 `비움`) 한 줄을 아래 두 줄로 바꾼다. 칸 사이는 탭 하나이고(`<TAB>` 으로 적었다) 둘째 줄은 「끝」 칸이 빈 채 탭으로 끝난다. 바로 아래의 `- 기준 사본이 없으면(rc 3 — 원장이 정리됐다)` 행은 그대로 둔다.

```
plugins/spec-distill/skills/request-framing/SKILL.md<TAB>꼬리<TAB>- 덩어리가 있으면 **처분을 한 묶음으로 묻는다**<TAB>확정 게이트 직전 화면에는 권장이 없다.
plugins/spec-distill/skills/request-framing/SKILL.md<TAB>떼기<TAB>고른 덩어리는 「그대로 둔다」 로,<TAB>
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_framing_review_contract.sh | grep -c '✗'; bash plugins/spec-distill/tests/test_plain_gate_templates.sh | grep -c '✗'; bash shared/tests/test_ask_recommendation.sh | grep -c '✗'`
Expected: 셋 다 0 이 아닌 수.

- [ ] **Step 4: `### 저자 편집 공시` 절을 바꾼다** — `plugins/spec-distill/skills/request-framing/SKILL.md` 에서 `### 저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞` 줄부터 `### 냉독` 줄 바로 앞까지를 아래 글 그대로로 바꾼다(끝에 빈 줄 하나를 두고 `### 냉독` 이 온다).

`````markdown
### 저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞

seed 는 헤딩이 없어 엔진의 얼림 검사가 모든 변경을 면제합니다. 저자 편집은 기준 사본과의 diff 로 **전부**
사용자 앞에 놓습니다 — 승인된 수정과 그 틈에 끼어든 수정을 가를 기계가 없으므로 가르지 않습니다.

공시는 두 걸음입니다 — 미리 보기 펜스, 그다음 공시 펜스. 그 사이에 저자가 이유 파일을 씁니다.

```bash
# 미리 보기 — 공시 기록을 남기지 않는다. 지난 이유 파일을 지우고 덩어리와 판본(seed_sha256)을 낸다.
[ -n "${STATE_DIR:-}" ] || { echo "[spec-distill] 리뷰 엔진 자리가 비었다 — 「## 상태」 블록을 이 펜스 앞에 이어 붙여라." >&2; exit 1; }
rm -f "$STATE_DIR/hunk-reasons.txt"
pv_rc=0
python3 "$SD/scripts/seed_edit_screen.py" preview "$SEED_BASE" "$SEED_ABS" || pv_rc=$?
echo "pv_rc=$pv_rc"
echo "이유 파일 경로(Write 도구로 쓴다): $STATE_DIR/hunk-reasons.txt"
```

미리 보기가 낸 덩어리마다 그 편집이 어느 지적 때문인지를 저자가 이유 파일(`$STATE_DIR/hunk-reasons.txt`)에 Write 도구로 적습니다.
첫 줄은 미리 보기가 낸 판본 `seed_sha256 <값>`, 그 아래는 줄마다 `<덩어리 번호><탭><지적 id 들(쉼표) | 없음>` 입니다.
지적 때문이 아닌 편집은 `없음` 이고, 한 덩어리에 둘이 섞였으면 지적 id 뒤에 `없음` 을 함께 적습니다. 이유 파일은 공시마다 새로 씁니다 —
미리 보기를 건너뛰거나 이유 파일을 쓰지 않으면 전부 권장 없음입니다. 덩어리가 0 이어도 공시 펜스는 돕니다.

```bash
# 공시할 때마다 덩어리 번호가 새로 매겨진다 — 지난 공시의 덩어리 문구 파일을 먼저 지운다.
find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
hunks_rc=0
python3 "$SD/scripts/nofollow_write.py" run --out "$STATE_DIR/hunks.json" -- python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS" || hunks_rc=$?
case "$hunks_rc" in
  0) scr_rc=0
     scr="$(python3 "$SD/scripts/seed_edit_screen.py" screen --hunks "$STATE_DIR/hunks.json" --reasons "$STATE_DIR/hunk-reasons.txt" --state-dir "$STATE_DIR")" || scr_rc=$?
     if [ "$scr_rc" -eq 0 ]; then
       printf '%s' "$scr" | python3 -I -X utf8 -c '
import json, sys
d = json.load(sys.stdin)
print(d["text"])
if d["questions"]:
    print()
    print("질문 묶음: " + json.dumps(d["questions"], ensure_ascii=False))
' || scr_rc=$?
     fi
     if [ "$scr_rc" -ne 0 ]; then
       echo "[spec-distill] 화면 조립 실패 — 줄 전체를 보인다(scr_rc=${scr_rc}). 질문은 권장 없이 낸다."
       python3 -I -X utf8 -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d["hunks"]:
    print("저자 편집 없음")
for h in d["hunks"]:
    print(h["render"])
    print()
' "$STATE_DIR/hunks.json"
     fi ;;
  3) echo "[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자가 seed 를 고쳤는지 대조할 수 없다. seed 전문을 보이고 「이대로 둔다 / 멈춘다」를 물어라." >&2 ;;
  *) echo "[spec-distill] 저자 편집 공시 실패(rc $hunks_rc) — 게이트를 띄우지 않는다." >&2 ;;
esac
```

- 덩어리가 0 이면 게이트 앞 글에 **«저자 편집 없음»** 한 줄을 싣는다 — 침묵과 구분한다.
- 공시 펜스가 낸 화면 글은 게이트 앞 글에 그대로 한 번 싣는다. 바뀐 문장은 하나도 빼지 않는다 — 화면 글을 줄이거나 고쳐 쓰지 않는다. 질문 본문에는 결정 한 줄만 둔다.
- 덩어리가 있으면 **처분을 한 묶음으로 묻는다** — 펜스가 낸 「질문 묶음」 의 질문 · 선택지 라벨 · 순서를 그대로 쓴다(한 호출에 질문 넷까지, 넘치면 다음 호출).
  덩어리가 둘 이상이면 여러 개 고르기 질문 「그대로 둘 곳을 고르세요. 고르지 않은 곳은 되돌립니다. 전부 되돌리려면 기타 칸에 적어 주세요.」 이고 선택지는 덩어리마다 「<k>번 그대로 둔다」 다. 하나면 하나 고르기 「그대로 둔다 / 되돌린다」 다. 나뉜 질문 전부에 답해야 처분이 끝난다.
- 권장은 화면 조립이 정한다 — 저자가 댄 지적 전부에 사용자의 고치는 쪽 처분이 원장에 있고 앞 화면에서 대지 않은 지적일 때만, 그 선택지가 질문의 첫 자리에 오고 라벨이 「<k>번 그대로 둔다 (권장)」 이 된다.
  저자는 꼬리를 더하거나 떼지 않고 선택지 설명에 자기 평가를 더하지 않는다 — 근거는 화면 글의 이유 줄이다. 확정 게이트 직전 화면에는 권장이 없다.
- 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다. 고른 덩어리는 「그대로 둔다」 로, 같은 질문의 고르지 않은 덩어리는 「되돌린다」 로 옮긴다 — 처분 펜스의 `PAIRS` 에 그 화면의 덩어리 번호를 하나도 빼지 않고 적는다.
  「기타」 로 전부 되돌리라고 적었으면 그 질문의 덩어리 전부가 「되돌린다」 다. 답이 비었거나 기타 칸의 말이 어느 덩어리를 어떻게 하라는 것인지 분명하지 않으면 처분하지 않고 그 질문을 다시 묻는다 — 아무것도 고르지 않은 답으로는 되돌리지도 통과시키지도 않는다.
- 덩어리 k 의 사용자 문구 파일(`said-hunk-<k>.txt`)에는 그 덩어리가 든 질문의 답 전체를 글자 그대로 적는다 — 고른 라벨들을 고른 순서대로 쉼표로 이은 것, 「기타」 면 적은 말이다. 고르지 않아 되돌리는 덩어리도 같다. 답에 없는 표지를 지어 적지 않는다.
- 화면 조립이 실패하면 공시 펜스가 「화면 조립 실패 — 줄 전체를 보인다」 와 함께 덩어리의 줄 전체 꼴을 낸다 — 그것을 그대로 싣고, 그때 질문은 권장 없이 낸다(묶는 법과 넷씩 나누기는 같다 — 넷씩 나누다 하나가 남으면 마지막 두 질문을 둘 이상씩으로 나눈다).
- 처분 없이는 다음 단계로 가지 않는다.
- 기준 사본이 없으면(rc 3 — 원장이 정리됐다) 그 사실을 게이트 앞 글에 쓰고 seed 전문을 한 질문으로
  보여 「이대로 둔다 / 멈춘다」를 묻는다. 「이대로 둔다」면 `seed_edit_diff.py init` 으로 새 기준 사본을 뜬다.
  추천을 달지 않는다 — 기준 사본이 없어 저자 편집이 섞였는지 가를 수 없고, 권하면 저자가 자기 편집을 스스로 승인한다.

처분을 받은 뒤 순서가 계약입니다 — **쓴 지적 목록에 더하기 → 되돌리기 → 기록 → 기준 사본 교체.** 교체는 맨 끝에서만 합니다. 공시
전에 교체하면 그 사이의 편집이 영영 안 보입니다. 쓴 지적 목록(`$STATE_DIR/hunk-used-findings.txt`)은 앞 화면의 이유 파일이 댄 지적 id 입니다 —
한 번 댄 지적은 뒤 화면에서 권장의 근거가 되지 않습니다. 목록에 더하지 못하면 되돌리기 · 기록 · 교체를 하지 않습니다.

```bash
# PAIRS 는 게이트의 답이다 — 그 화면의 덩어리마다 한 줄 「번호:처분」(처분은 「그대로 둔다」 또는 「되돌린다」). 번호는 그 화면의 덩어리
# 전부와 같아야 한다 — 빠진 번호나 없는 번호가 있으면 아무것도 바꾸지 않는다. HUNKS_JSON 은 그 화면을 조립한 덩어리 JSON 이다. 덩어리 k 의
# 사용자 문구는 먼저 Write 도구로 "$STATE_DIR/said-hunk-<k>.txt" 에 쓴다(공시 펜스가 공시마다 지난 파일을 지운다).
# 문구 파일이 하나라도 없으면 아무것도 바꾸지 않는다. 기록이 전부 성공했을 때만 기준 사본을 교체한다.
# 부분 실패 뒤에는 원인을 고치고 이 펜스를 통째로 다시 돈다 — 되돌리기는 표지(`<기준 사본>.reverted`)가 막아 같은 판본에서 한 번만
# 일어나고, 쓴 지적 목록은 이미 있는 id 를 다시 적지 않는다. 편집 기록 줄은 그렇지 않다: 다시 돈 만큼 겹친다(덩어리 번호가 공시마다 1 부터 다시 시작해 다른 처분이 같은 줄이 되므로,
# 같은 줄을 건너뛰면 기록이 사라진다 — 겹치는 쪽을 고른다). **겹친 줄을 지우지 마라**: 어느 것이 재실행으로 겹친 줄이고 어느 것이
# 다른 공시의 다른 처분인지 글자로는 가를 수 없고, 겹침은 아무것도 상하게 하지 않는다 — `user-quotes` 는 문구로 묶고 `check-drops` 는
# `거부` 와 엔진 drop 줄만 읽는다.
HUNKS_JSON="$STATE_DIR/<덩어리 JSON 파일 이름>"
PAIRS='<덩어리마다 한 줄 — 번호:처분>'
pre_rc=0; used_rc=0; rev_rc=0; log_rc=0; n_pairs=0; REVERT_IDS=""; ALL_IDS=""
while IFS=: read -r k choice; do
  [ -n "$k" ] || continue
  n_pairs=$((n_pairs + 1))
  ALL_IDS="${ALL_IDS:+${ALL_IDS},}${k}"
  [ -s "$STATE_DIR/said-hunk-${k}.txt" ] || { echo "[spec-distill] 덩어리 ${k} 의 사용자 문구 파일이 없다(${STATE_DIR}/said-hunk-${k}.txt) — 아무것도 바꾸지 않는다." >&2; pre_rc=2; }
  case "$choice" in
    되돌린다) REVERT_IDS="${REVERT_IDS:+${REVERT_IDS},}${k}" ;;
    "그대로 둔다") : ;;
    *) echo "[spec-distill] 덩어리 ${k} 의 처분을 모르겠다: '${choice}' — 아무것도 바꾸지 않는다." >&2; pre_rc=2 ;;
  esac
done <<< "$PAIRS"
[ "$n_pairs" -gt 0 ] || { echo "[spec-distill] 처분 목록(PAIRS)이 비었다 — 아무것도 바꾸지 않는다." >&2; pre_rc=2; }
if [ "$pre_rc" -eq 0 ]; then
  python3 "$SD/scripts/seed_edit_screen.py" mark-used --hunks "$HUNKS_JSON" --reasons "$STATE_DIR/hunk-reasons.txt" --state-dir "$STATE_DIR" --ids "$ALL_IDS" >/dev/null || used_rc=$?
  [ "$used_rc" -eq 0 ] || echo "[spec-distill] 쓴 지적 목록에 더하지 못했다(used_rc=${used_rc}) — 되돌리기 · 기록 · 기준 사본 교체를 하지 않는다. 위 사유(처분 목록의 번호가 화면의 덩어리와 다르면 PAIRS 를, 목록 파일이면 그 파일을)를 고친 뒤 이 펜스를 다시 돌려라." >&2
fi
if [ "$pre_rc" -eq 0 ] && [ "$used_rc" -eq 0 ] && [ -n "$REVERT_IDS" ]; then
  python3 "$SD/scripts/seed_edit_diff.py" revert "$SEED_BASE" "$SEED_ABS" --ids "$REVERT_IDS" || rev_rc=$?
fi
if [ "$pre_rc" -eq 0 ] && [ "$used_rc" -eq 0 ] && [ "$rev_rc" -eq 0 ]; then
  while IFS=: read -r k choice; do
    [ -n "$k" ] || continue
    python3 "$SD/scripts/seed_review_log.py" log "$AUDIT_ABS" --kind 편집 --round "<n>" --target "덩어리 ${k} · ${choice}" --quote-file "$STATE_DIR/said-hunk-${k}.txt" || log_rc=$?
  done <<< "$PAIRS"
fi
if [ "$pre_rc" -eq 0 ] && [ "$used_rc" -eq 0 ] && [ "$rev_rc" -eq 0 ] && [ "$log_rc" -eq 0 ]; then
  accept_rc=0
  python3 "$SD/scripts/seed_edit_diff.py" accept "$SEED_BASE" "$SEED_ABS" || accept_rc=$?
  echo "accept_rc=$accept_rc"
  [ "$accept_rc" -ne 0 ] || find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
elif [ "$rev_rc" -ne 0 ]; then
  echo "[spec-distill] revert 실패(rev_rc=$rev_rc) — 기준 사본을 교체하지 않는다. 미리 보기 펜스와 위 공시 펜스를 다시 돌려 이 처분을 다시 받아라." >&2
elif [ "$log_rc" -ne 0 ]; then
  echo "[spec-distill] 편집 처분 기록 실패(log_rc=$log_rc) — 기준 사본을 교체하지 않는다. 위 stderr 가 댄 문구 파일을 고친 뒤 이 펜스를 그대로 다시 돌려라(되돌리기는 표지가 막아 한 번만 일어난다 · 먼저 성공한 편집 기록 줄은 겹쳐 적히지만 그대로 둔다)." >&2
fi
echo "pre_rc=$pre_rc rev_rc=$rev_rc log_rc=$log_rc used_rc=$used_rc"
```

처분 펜스의 덩어리 JSON 자리에는 그 화면의 공시 펜스가 쓴 파일 이름을 넣습니다 — 라운드 게이트 앞이면 `hunks.json`, 확정 게이트 직전 검사 2 면 그 검사의 사본입니다.
`revert` · `accept` 가 rc 4 를 내면 공시(`hunks`) 뒤에 seed 가 또 바뀌었거나, 이 공시에서 이미 다른 번호를
되돌린 것입니다(되돌린 뒤에는 덩어리 번호가 다시 매겨진다) — 기준 사본을 그대로 두고
미리 보기 펜스와 위 공시 펜스를 다시 돌려 다시 처분받습니다. `revert` 는 처분 하나에 한 번만 부릅니다 — 펜스가 `PAIRS` 의
「되돌린다」 번호를 전부 쉼표로 모아 `--ids` 에 한 번에 넘깁니다. `hunks` 는 그 출력을 사용자에게 보이는 자리에서만
부릅니다 — 부르면 매번 «공시됨»으로 기록되기 때문입니다. 미리 보기는 `hunks` 를 부르지 않습니다.
`````

- [ ] **Step 5: 확정 게이트 직전 검사 2 를 바꾼다** — 같은 파일에서 `**검사 2 — 저자 편집 공시** — ` 로 시작하는 문단부터 `**검사 3 — 문구 없는 drop** — ` 문단 바로 앞까지를 아래 글 그대로로 바꾼다(끝에 빈 줄 하나).

`````markdown
**검사 2 — 저자 편집 공시** — `### 저자 편집 공시` 의 두 걸음(미리 보기 → 이유 파일 → 공시)과 처분 절차 그대로입니다. 이 화면에는 권장이 붙지 않고 고친 이유 줄만
보입니다 — 이 화면 뒤에는 리뷰 라운드가 없습니다. 처분 펜스의 덩어리 JSON 자리에는 이 검사의 사본 `hunks-final.json` 을 넣습니다. 마지막 라운드 뒤의 편집(채택 결정의
반영 · ③ 뒤에 다시 깎은 것)이 사용자 앞에 오는 유일한 자리입니다. 덩어리 하나라도 「되돌린다」를 받으면 검사 1 부터
다시 돕니다 — 되돌리기가 검사 1 뒤에 뗀 표시를 되살릴 수 있습니다. 원장 자리를 거부한 세션(`## 상태` 블록이 그 한
줄을 냈다)은 seed 리뷰 라운드도 기준 사본도 없으므로 이 검사는 «검사 불가»로 막습니다 — 링크를 걷어 내고 `## 상태` 블록부터 다시 돕니다.

```bash
# 확정 직전 미리 보기 — 공시 기록을 남기지 않는다. 지난 이유 파일을 지우고 덩어리와 판본(seed_sha256)을 낸다.
final_pv_rc=0
if [ -z "${STATE_DIR:-}" ] || [ -z "${SEED_BASE:-}" ]; then
  final_pv_rc=2
else
  rm -f "$STATE_DIR/hunk-reasons.txt"
  python3 "$SD/scripts/seed_edit_screen.py" preview "$SEED_BASE" "$SEED_ABS" || final_pv_rc=$?
  echo "이유 파일 경로(Write 도구로 쓴다): $STATE_DIR/hunk-reasons.txt"
fi
echo "final_pv_rc=$final_pv_rc"
```

```bash
final_hunks_rc=0
if [ -z "${STATE_DIR:-}" ] && [ -n "${LEDGER_REFUSED:-}" ]; then
  # 원장 자리를 거부했다 — seed 리뷰가 돌지 않았고 기준 사본도 없다. 열지 않고 막는다.
  echo "[spec-distill] 원장 자리를 거부했다(링크 · 레포 밖) — 리뷰 없이 확정하지 않는다. 그 링크를 걷어 내고 「## 상태」 블록부터 다시 돈다." >&2
  final_hunks_rc=2
elif [ -z "${STATE_DIR:-}" ] || [ -z "${SEED_BASE:-}" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  final_hunks_rc=2
else
  find "$STATE_DIR" -maxdepth 1 -name 'said-hunk-*.txt' -exec rm -f {} + 2>/dev/null || true
  python3 "$SD/scripts/nofollow_write.py" run --out "$STATE_DIR/hunks-final.json" -- python3 "$SD/scripts/seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS" || final_hunks_rc=$?
fi
case "$final_hunks_rc" in
  0) scr_rc=0
     scr="$(python3 "$SD/scripts/seed_edit_screen.py" screen --hunks "$STATE_DIR/hunks-final.json" --reasons "$STATE_DIR/hunk-reasons.txt" --state-dir "$STATE_DIR" --final)" || scr_rc=$?
     if [ "$scr_rc" -eq 0 ]; then
       printf '%s' "$scr" | python3 -I -X utf8 -c '
import json, sys
d = json.load(sys.stdin)
print(d["text"])
if d["questions"]:
    print()
    print("질문 묶음: " + json.dumps(d["questions"], ensure_ascii=False))
' || scr_rc=$?
     fi
     if [ "$scr_rc" -ne 0 ]; then
       echo "[spec-distill] 화면 조립 실패 — 줄 전체를 보인다(scr_rc=${scr_rc}). 질문은 권장 없이 낸다."
       python3 -I -X utf8 -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
if not d["hunks"]:
    print("저자 편집 없음")
for h in d["hunks"]:
    print(h["render"])
    print()
' "$STATE_DIR/hunks-final.json"
     fi ;;
  3) echo "[spec-distill] 기준 사본이 없다(${SEED_BASE:-}) — 저자가 seed 를 고쳤는지 대조할 수 없다. seed 전문을 보이고 「이대로 둔다 / 멈춘다」를 물어라. 게이트를 띄우지 않는다." >&2 ;;
  *) echo "[spec-distill] 확정 직전 공시 검사 불가(rc $final_hunks_rc) — 엔진 자리가 없거나(STATE_DIR='${STATE_DIR:-}') 입력을 읽지 못했다. 게이트를 띄우지 않는다." >&2 ;;
esac
echo "final_hunks_rc=$final_hunks_rc"
```
`````

- [ ] **Step 6: 두 구절을 고친다** — 같은 파일에서 각각 한 번 나오는 글자를 바꾼다(`### 게이트` 의 사용자 문구 파일 설명 · `## 상태` 표).

```text
옛: 저자 편집 덩어리의 문구는 `$STATE_DIR/said-hunk-<k>.txt`, 추가 라운드
새: 저자 편집 덩어리의 문구는 `$STATE_DIR/said-hunk-<k>.txt`(그 덩어리가 든 질문의 답 전체), 추가 라운드

옛: 저자 편집 기준 사본(`$SEED_BASE`) · 동시 리뷰 표지
새: 저자 편집 기준 사본(`$SEED_BASE`) · 저자 편집 이유 파일(`hunk-reasons.txt`) · 쓴 지적 목록(`hunk-used-findings.txt`) · 동시 리뷰 표지
```

- [ ] **Step 7: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_framing_review_contract.sh | tail -1; bash plugins/spec-distill/tests/test_plain_gate_templates.sh | tail -1; bash shared/tests/test_ask_recommendation.sh | tail -1`
Expected: 셋 다 `Fail: 0`.

- [ ] **Step 8: 이 skill 을 읽는 다른 락을 돌린다**

Run:
```bash
for f in $(git grep -l 'request-framing/SKILL.md' -- 'plugins/spec-distill/tests/*.sh' 'shared/tests/*.sh') plugins/spec-distill/tests/test_state_dir_writes.sh shared/tests/test_skill_body_no_positional_tokens.sh shared/tests/test_inline_python_isolated.sh shared/tests/test_plain_language_block.sh plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; do
  printf '%s %s\n' "$(bash "$f" 2>&1 < /dev/null | grep -c '✗')" "$f"
done | grep -v '^0 '
```
Expected: 출력이 없거나, 남은 줄이 Task 1 Step 3 의 기준 실패(`.claude/tmp/f2/suite-base.txt`)에 같은 테스트로 있는 것뿐이다. 새로 생긴 실패가 있으면 그 테스트가 뽑는 펜스 · 글자를 Global Constraints 의 「펜스가 지킬 자리」 와 맞춰 본다.

- [ ] **Step 9: 커밋**

```bash
git commit -m "feat(spec-distill): 저자 편집 공시를 두 걸음으로 — 바뀐 문장 화면 · 한 묶음 질문 · 확인된 곳에만 권장" -m "Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md" -- plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/tests/test_framing_review_contract.sh plugins/spec-distill/tests/test_plain_gate_templates.sh shared/tests/fixtures/ask-sites.tsv
```

---

### Task 6: 판 · CHANGELOG · README · 끝 확인 (AC12)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/tests/test_state_dir_writes.sh` · `shared/tests/test_writer_trust_notice.sh` (README 한계 문장을 잠근 글자)

- [ ] **Step 1: README 한계 문장과 그 락 둘** — 이유 파일은 Write 도구로 쓰는 상태 폴더 파일이라 README `## 한계` 의 「상태 폴더 쓰기의 링크 (P21)」 목록에 든다. 세 파일(`plugins/spec-distill/README.md` · `plugins/spec-distill/tests/test_state_dir_writes.sh` · `shared/tests/test_writer_trust_notice.sh`)에서 각각 한 번 나오는 아래 글자를 바꾼다. CHANGELOG 의 옛 판 기록에 있는 같은 글자는 건드리지 않는다.

```text
옛: `critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고
새: `critic*.txt` · `recritic.txt` · `hunk-reasons.txt`)은 writer 로 감싸지 못하고
```

- [ ] **Step 2: README 의 Law 2(seed 자리) 줄에 새 스크립트를 싣는다** — `plugins/spec-distill/README.md` 에서 한 번 나오는 아래 글자를 바꾼다. README 에 스크립트 목록 절은 없다 — 이 줄이 그 자리다.

```text
옛: 저자 편집은 기준 사본 diff(`scripts/seed_edit_diff.py`)로 라운드 게이트와 확정 게이트 앞에서 덩어리마다 처분받고,
새: 저자 편집은 기준 사본 diff(`scripts/seed_edit_diff.py`)로 라운드 게이트와 확정 게이트 앞에서 덩어리마다 처분받고(화면은 `scripts/seed_edit_screen.py` 가 바뀐 문장만 보이게 조립하고, 권장은 저자가 댄 지적에 사용자의 고치는 쪽 처분이 리뷰 기록에 있을 때만 붙는다),
```

- [ ] **Step 3: 판과 CHANGELOG** — `plugin.json` 의 `"version"` 을 `8.15.0` 으로(Global Constraints 의 번호 규칙). `CHANGELOG.md` 의 `# Changelog` 바로 아래에 `## [8.15.0] — <커밋 날짜 YYYY-MM-DD>` 절을 더한다:
  - `### Changed` — 저자 편집 승인 화면이 바뀐 문장만 보인다(뺀 문장 · 더한 문장 · 그대로인 문장 수, 문장을 더하거나 뺀 것만으로 설명되지 않는 변화가 있으면 줄 전체도) · 덩어리마다 고친 이유(저자가 댄 지적의 요약 · id · 사용자의 처분, 또는 대응하는 지적 없음)가 보인다 · 덩어리 처분을 한 묶음으로 묻는다(둘 이상이면 「그대로 둘 곳을 고르세요」 여러 개 고르기, 한 질문에 넷까지, 고르지 않은 곳은 되돌리고 빈 답은 다시 묻는다) · 저자가 댄 지적 전부에 사용자의 고치는 쪽 처분이 리뷰 기록에 있고 앞 화면에서 대지 않은 지적일 때만 「(권장)」 이 붙는다 — 확정 직전 화면에는 없고, 지적과 편집이 실제로 맞는지는 기계가 가리지 않는다.
  - `### Added` — `scripts/seed_edit_screen.py`(하위 명령 `preview` · `screen` · `mark-used`).

- [ ] **Step 4: 락을 돌린다**

Run: `bash shared/tests/test_changelog_integrity.sh | tail -1; bash shared/tests/test_writer_trust_notice.sh | tail -1; bash plugins/spec-distill/tests/test_state_dir_writes.sh | tail -1`
Expected: 셋 다 실패 0.

- [ ] **Step 5: 사람이 보는 확인(설계 Verification Plan)** — 문단 하나에서 두 문장을 바꾼 seed 로 미리 보기 → 이유 파일 → 공시의 차례를 돌려 화면 글을 눈으로 본다. 아래를 한 줄씩 돌리고 마지막 출력을 `.claude/tmp/f2/screen-sample.txt` 에 남겨 PR 본문에 싣는다.

```bash
D="$(mktemp -d)"; S=plugins/spec-distill/scripts
printf '첫 문장이다. 둘째 문장이다. 셋째 문장이다. 넷째 문장이다.\n' > "$D/base.md"
printf '첫 문장이다. 둘째 문장을 고쳤다. 셋째 문장이다. 넷째 문장도 고쳤다.\n' > "$D/seed.md"
python3 "$S/seed_edit_screen.py" preview "$D/base.md" "$D/seed.md"
python3 "$S/seed_edit_diff.py" hunks "$D/base.md" "$D/seed.md" > "$D/hunks.json"
python3 "$S/seed_edit_screen.py" screen --hunks "$D/hunks.json" --reasons "$D/hunk-reasons.txt" --state-dir "$D" | python3 -I -X utf8 -c 'import json, sys; d = json.load(sys.stdin); print(d["text"]); print(json.dumps(d["questions"], ensure_ascii=False, indent=1))'
```

Expected: 「뺀 문장」 둘 · 「더한 문장」 둘 · 「그대로 2문장」 이 보이고 첫 · 셋째 문장의 글자는 없다. 원장이 없는 폴더라 「리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다」 가 함께 보이고 질문은 하나 고르기(권장 없음)다.

- [ ] **Step 6: 전체 스위트를 기준과 견준다** — Global Constraints 의 러너 · 잠금으로 한 번 돌려 `.claude/tmp/f2/suite-after.txt` 에 남기고 Task 1 Step 3 의 기준과 견준다.

Run: `comm -13 <(sort .claude/tmp/f2/suite-base.txt) <(sort .claude/tmp/f2/suite-after.txt)`
Expected: 빈 출력(기준에 없는 실패 0). 임시 경로가 든 실패 줄은 경로만 다를 수 있다 — 그런 줄은 테스트 이름으로 견준다.

- [ ] **Step 7: 커밋**

```bash
git commit -m "chore(spec-distill): 판 올림 8.15.0 — 저자 편집 승인 화면" -m "Spec: docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md" -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_state_dir_writes.sh shared/tests/test_writer_trust_notice.sh
```

## 마지막 전체 리뷰 (실행 방식 공통)

- 브랜치 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC1–AC12 를 싣고, 리뷰가 AC 마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거>` 로 보고하게 한다. 그 보고를 `.claude/tmp/f2/ac-report.txt`(git 이 추적하지 않는 자리)에 적는다.
- 리뷰에 함께 묻는다: ① 끝에서 끝 흐름 — 미리 보기가 낸 판본 → 이유 파일 첫 줄 → 공시 펜스의 덩어리 JSON → 처분 펜스의 `HUNKS_JSON` · `PAIRS` → 목록에 더하기 → 되돌리기 → 기록 → 교체가 같은 파일 이름 · 같은 번호로 이어지는가(확정 직전 사본 `hunks-final.json` 포함). ② rc 를 누가 읽는가 — `scr_rc` · `used_rc` · `rev_rc` · `log_rc` 마다 0 이 아닐 때 다음 걸음이 멈추는가. ③ 권장이 붙을 수 있는 길을 전부 세어, 사용자의 처분 없이 붙는 길이 없는가(이유 파일 줄 읽기 · 원장 읽기 실패 · 목록 읽기 실패 · 확정 직전). ④ skill 글이 화면 글을 줄이거나 빈 답으로 통과시키는 길을 열지 않는가. ⑤ 이 계획이 쓴 테스트 코드(`test_seed_edit_screen.sh` 전체 · 계약 테스트의 새 단언 · `test_state_dir_writes.sh` 의 새 칸)도 구현과 같은 기준으로 본다 — 계획이 시킨 코드라는 이유로 건너뛰지 않는다.
- 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다.
- PR 을 만들기 전에 `python3 <spec-distill 플러그인 루트>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-15-chunk-approval-screen-design.md .claude/tmp/f2/ac-report.txt` 를 돌려 경고를 사용자에게 보인다.
- 사람에게 쓰는 글(보고 · PR 본문)은 번호 · 해시를 내용 문장 뒤 괄호에 두고, 첫 줄에 상태, 끝에 할 일(기본 하나 — 여럿이거나 병렬이면 밝힌다)을 둔다.
