# 추천의 대가와 리뷰 뒤 질문 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew skill 이 사람에게 선택을 물을 때, 질문 창에 보이는 글만으로 무엇을 고르는지와 그 대가를 알게 한다.

**Architecture:** 공통 규칙 블록(정본 하나 · SKILL.md 10개 복제)의 문장 셋을 고치고, 문서 리뷰 엔진에 읽기 전용 「질문 재료」 출력과 라운드별 「전문 파일」 쓰기를 더한다(지금 게이트 글 `gate --render` 는 한 글자도 바꾸지 않는다). 질문 자리마다 선택지 설명을 「얻음: … · 내줌: …」 한 줄로 고쳐 쓰고, 레포 테스트(질문 자리 전수 검사 · 옛 문구 부재 락과 그 양의 짝 · 엔진 사례)로 잠근다. 실행 중 검사 · 훅은 더하지 않는다.

**Tech Stack:** Python 3 표준 라이브러리(엔진 · 검사 · 측정), bash 테스트(`shared/tests/assert.sh`), 마크다운 skill · reference.

**Spec:** `docs/superpowers/specs/2026-11-15-present-tradeoffs-design.md` (실행자는 계획과 함께 읽는다. 자리별 새 설명의 표는 짝 파일 `docs/superpowers/plans/2026-11-15-present-tradeoffs-sites.md` 에 있다.)

## Global Constraints

- 공통 규칙 블록은 `shared/style/plain-language.md` 가 정본이고 진입 SKILL.md 10개에 **같은 바이트**로 있다. 한 글자를 고치면 열 곳이 같은 커밋에서 바뀐다(`shared/tests/test_plain_language_block.sh`).
- `docreview_state.py gate --render` 의 출력은 이 변경 전과 **바이트가 같다**. 정답 파일은 `shared/tests/fixtures/docreview/golden/*.gate.txt` 이고 `shared/tests/test_docreview_golden.sh` 가 잰다. 정답 파일을 다시 뜨지 않는다.
- 엔진 정본은 `shared/docreview/` 다. 플러그인 쪽 `plugins/{spec-distill,quality-gates}/scripts/docreview_*.py` · `plugins/spec-distill/references/reviewing-document.md` 는 정본을 가리키는 **심볼릭 링크**(git mode 120000)다 — 정본만 고친다. 새 형제 모듈은 두 플러그인 `scripts/` 에 같은 꼴의 링크를 더한다.
- 질문 도구는 한 호출에 질문 넷, 질문 하나에 선택지 둘에서 넷. `preview` 칸은 쓰지 않는다.
- 선택지 설명은 한 줄, 길어도 세 줄. 엔진의 기준 길이는 110자(코드 포인트)다.
- 상태 폴더(`.claude/spec-distill/.docreview/…`)에 쓰는 것은 마지막 경로 성분의 링크를 따라가지 않는 writer(`nofollow_write.py`)를 거친다.
- 엔진의 쓰기 하위 명령은 같은 Bash 호출 안에서 표지 확인 줄(`ledger_marker.py" check --dir "$STATE_DIR"`) **다음에만** 부른다. 엔진 호출 줄에 `>` 넘기기를 쓰지 않고 결과는 `$(…)` 로 받는다(`plugins/spec-distill/tests/test_ledger_wiring.sh` AC8).
- 훅을 더하지 않는다. 어느 `hooks.json` 도, 리뷰어 정의 파일(`agents/*.md`)도 바꾸지 않는다. `plugins/spec-distill/agents/relay-checker.md` 는 바이트가 그대로다.
- 옛 문구(목록은 `tools/plain-language/window_phrases.txt`)를 skill · reference · 절차서의 새 문면에 다시 쓰지 않는다 — 「…를 쓰지 않는다」 꼴의 부정문으로도 쓰지 않는다(부재 락의 코퍼스에 들어간다).
- 새 python 파일은 UTF-8 을 명시해 읽고 쓰고(`encoding="utf-8"`), 긴 한글 문자열은 한 줄 100자 안에서 인접 문자열로 나눈다. 새 셸 테스트는 실행 비트(100755)를 준다.
- 커밋: Conventional Commits, 설명은 한국어(`feat(spec-distill): …`). 끝에 `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>` 와 `Claude-Session: https://claude.ai/code/session_01T86yLpoMchPD6QV4MDdUou`. push 는 사용자가 말할 때만 한다.
- 기준 브랜치는 박아 쓰지 않고 읽는다: `BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD)"`. 이 계획의 명령에 나오는 `$BASE` 가 그 값이다(명령마다 앞에 이 대입을 붙인다).
- 전체 스위트는 `bash tools/suite/run-all.sh` 다. 스위트 둘을 같은 시각에 돌리지 않는다. worktree 에서는 `TestCrossResolverAdvisory` 가 원래 실패한다 — 기준 브랜치 실행과 견줘 **새 실패**만 본다.
- 사람에게 쓰는 글(커밋 본문 · PR 본문 · 보고)은 쉬운 말 규칙을 따른다: 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에.

## 이 계획이 정한 것

설계가 계획에 넘긴 것(`### Deferred to plan` · 리뷰 참고 항목)을 이렇게 정했다. 사용자가 고른 것이 아니다 — 틀린 것으로 드러나면 고치고 알린다.

| # | 넘겨받은 것 | 정한 것 |
|---|---|---|
| 1 | 엔진 새 출력과 새 하위 명령의 이름 | 읽기 전용 `ask-material`, 쓰기 `gate-file`. 로직은 새 형제 모듈 `shared/docreview/scripts/docreview_ask.py`(leaf)에 두고 `docreview_state.py` 에는 진입 줄만 더한다. |
| 2 | 「플러그인 안 물리 사본」(설계 Constraints · Files to Modify · AC7) | 사실이 아니다 — 링크다(`git ls-files -s` 로 확인, mode 120000). 정본만 고치고, AC7 의 「정본과 사본이 같다」는 「플러그인 쪽이 링크 그대로다」로 확인한다. |
| 3 | 기준 길이 110자를 어디서 읽나 | 환경 변수 하나(`DEVBREW_DOCREVIEW_ASK_WIDTH`, 20~500, 기본 110). 라운드 설정(원장의 `config`)에 넣지 않는다 — 넣으면 정답 파일의 원장 · JSON 이 전부 바뀐다. |
| 4 | 「다음 결정」 줄을 읽는 스크립트 | 없다. `plugins/spec-distill/tests/test_conducting_interview_stage.sh` 가 그 줄이 `OQ<n>:` 으로 시작하는지만 본다 — 그 시작은 그대로 둔다. |
| 5 | 측정 스크립트 | 새 파일 `tools/plain-language/measure_questions.py`. 있는 도구(`measure_output.py`)는 질문 본문만 모아 선택지 · 직전 skill · 게이트 글 짝을 얹을 수 없다. 기록 판별 도우미(`devbrew_plugin` · `DEVBREW_PLUGINS`)는 그 모듈에서 가져다 쓴다. |
| 6 | 옛 문구 목록 | 파일 하나(`tools/plain-language/window_phrases.txt`)를 측정 스크립트와 부재 락이 함께 읽는다. |
| 7 | 고친 뒤 재측정의 통과 기준 · 맡는 이 | 기준을 `tools/plain-language/README.md` 에 적는다(Task 1). 재측정은 구현 PR 이 머지되고 새 판으로 리뷰를 몇 번 돈 뒤 사용자 세션이 그 README 의 명령으로 돈다 — PR 본문 「후속」 칸과 설계 `## 미룸` 표가 그 자리를 가리킨다. |
| 8 | 전문 파일을 쓰지 못한 라운드 | 「전문」 줄에 사유를 내고, 기타 칸의 「전문」에는 `gate --render` 출력을 그대로 보인다(절차서에 적는다 — Task 7). |
| 9 | 질문 자리 검사가 `지시` 자리의 고정 설명도 보는가 | 본다. 목록의 새 칸(「설명 수」)을 채운 행은 종류와 무관하게 검사한다. `꼬리` · `출처꼬리` 행은 그 칸이 필수다(Task 14 에서 켠다). |
| 10 | 코드 리뷰 질문의 경고 줄 자리 | Task 12 의 Step 1 에서 합성 출력에 경고 줄이 있는지 읽고 정한다 — 있으면 질문용 줄 끝에 「 · 경고 N개: <종류>」를 붙이고, 없으면 채널 표(Task 8)에 「경고 줄 없음」으로 적는다. |
| 11 | 엔진 밖 스크립트의 새 줄과 「전부」 펜스의 시험 | 스크립트마다 단위 시험을 둔다 — `test_synthesize_ask_line.sh`(Task 12) · `test_bundle_short_line.sh` · `test_brief_review_short.sh`(Task 8) · `test_lowered_gate_wiring.sh` 의 「전부」 케이스(Task 12). |
| 12 | 라벨만 적힌 `지시` 자리(설명이 skill 글에 없다) | 손대지 않는다. 설계의 예외는 「skill 글에 설명이 적힌 고정 선택지」에 한한다(D2.10). 그 자리의 설명은 모델이 공통 규칙대로 쓴다. 대상: `finishing.md` 의 「계속 고칠까요」 · 닫은 답 되묻기, `saturation.md` 의 반복 빈 곳 · 판정 불가 · 판정 상한. |

## Review Focus

설계가 함의하지만 어느 Task 의 시험도 그냥은 밟지 않는 입력 다섯. 각 줄의 시험은 그 코드를 가진 Task 에 넣었다.

1. **리뷰어가 두 칸을 비운 지적**(사후 결정 포함) — 질문 재료가 빈 줄 대신 지금의 부재 표기를 내고, 그 글자가 게이트 글의 부재 표기와 같아야 한다 → Task 5 `case_ask_material_absent_fields`.
2. **경고 원문이 엔진 표에 없는 글자** — 짧은 줄이 버리지 않고 「그 밖 N개」로 세어, 개수가 게이트 첫 줄과 같아야 한다 → Task 4 `case_ask_unknown_warn_counted`.
3. **전문 파일 자리가 링크이거나 쓸 수 없는 폴더** — 링크를 따라 쓰지 않고, 질문은 사유와 함께 그대로 떠야 한다 → Task 6 `case_gate_file_symlink_refused` · Task 5 `case_ask_material_gate_file_failed`.
4. **결정을 반영한 뒤 전문 파일을 다시 쓸 때** — 답한 지적의 원문 구역이 사라지거나 바뀌면 안 된다 → Task 6 `case_gate_file_originals_preserved`.
5. **낮춘 지적의 기타 칸에 「전부」와 낱개 번호가 함께 온 답** — 어느 쪽도 적용하지 않고 다시 물어야 한다 → Task 12 `test_lowered_gate_wiring.sh` 의 부딪힘 케이스.

---

### Task 1: 측정 스크립트와 고치기 전 기준 수

**AC:** AC17

**Files:**
- Create: `tools/plain-language/measure_questions.py`
- Create: `tools/plain-language/window_phrases.txt`
- Create: `tools/plain-language/test_measure_questions.py`
- Modify: `tools/plain-language/README.md`

**Interfaces:**
- Consumes: `tools/plain-language/measure_output.py` 의 `devbrew_plugin(name) -> bool`.
- Produces:
  - `window_phrases.txt` — 한 줄에 문구 하나, `#` 줄과 빈 줄은 건너뛴다. Task 14 의 부재 락이 같은 파일을 읽는다.
  - `load_phrases(path) -> list[str]`
  - `scan(folders: list[str]) -> list[Question]` — `Question` 은 `skill: str`(그 파일에서 질문 **직전에** 부른 `Skill` 도구의 `input.skill`, 없으면 `"(없음)"`) · `text: str` · `options: list[tuple[str, str]]`(라벨, 설명) · `file: str` · `gate_blocks: dict[str, str]`(그 파일의 앞선 도구 결과에서 찾은 지적 id → 게이트 글 묶음).
  - `summarize(questions, phrases) -> dict` — 아래 여섯 값.
  - CLI: `measure_questions.py <폴더…> [--phrases <파일>] [--pairs N]`. 결과는 화면에만 낸다. 파일을 쓰지 않는다.

- [ ] **Step 1: 실패하는 시험을 쓴다**

`tools/plain-language/test_measure_questions.py`(unittest). 임시 폴더에 jsonl 을 지어 넣고 잰다. 기록 한 줄의 꼴은 `{"type":"assistant","uuid":"…","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"spec-distill:spec-review"}}]}}` · `{"type":"assistant",…,"content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"question":"…","options":[{"label":"…","description":"…"}]}]}}]}` · `{"type":"user",…,"content":[{"type":"tool_result","content":"…"}]}` 다.

```python
class MeasureQuestions(unittest.TestCase):
    def test_skill_is_the_one_called_just_before(self):
        # 한 파일: Skill(spec-distill:pm-interview) → 질문 A → Skill(spec-distill:spec-review) → 질문 B
        qs = mq.scan([self.dir])
        self.assertEqual([q.skill for q in qs], ["spec-distill:pm-interview", "spec-distill:spec-review"])

    def test_counts(self):
        # 질문 넷: ① 본문에 「위에 적었다」 ② (권장) 있고 모든 설명에 얻음: · 내줌:
        #          ③ (권장) 있고 한 설명에 내줌: 없음 ④ 라벨이 「고친다(채택) — …」 이고 본문에 「전문: …」 줄
        s = mq.summarize(mq.scan([self.dir]), ["위에 적었다"])
        self.assertEqual(s["questions"], 4)
        self.assertEqual(s["out_of_window"], 1)
        self.assertEqual(s["recommended"], 2)
        self.assertEqual(s["recommended_all_tradeoff"], 1)
        self.assertEqual(s["review_decision"], 1)
        self.assertEqual(s["review_decision_with_fulltext"], 1)

    def test_duplicate_uuid_counted_once(self):     # 같은 uuid 가 두 파일에 있으면 경로 정렬 순서로 처음 것만
        self.assertEqual(mq.summarize(mq.scan([self.dir]), [])["questions"], 1)

    def test_pair_by_finding_id_not_nearest_gate(self):
        # 도구 결과 둘: 앞 것에 「- 요약 가 (aaaaaaaa#r1.1)\n  그대로 두면: …\n  고치면: …」, 뒤 것에 다른 id.
        # 질문 설명에 (aaaaaaaa#r1.1) → 짝은 앞 묶음이다(가까운 뒤 묶음이 아니다).
        q = mq.scan([self.dir])[0]
        self.assertIn("요약 가", q.gate_blocks["aaaaaaaa#r1.1"])

    def test_non_devbrew_skill_excluded_from_summary(self):   # skill 이 superpowers:brainstorming 인 질문은 세지 않는다
        self.assertEqual(mq.summarize(mq.scan([self.dir]), [])["questions"], 0)

    def test_writes_nothing(self):                  # 돌린 뒤 폴더의 파일 목록이 그대로다
        before = sorted(os.listdir(self.dir)); mq.main([self.dir]); self.assertEqual(sorted(os.listdir(self.dir)), before)
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `cd tools/plain-language && python3 -m unittest -v test_measure_questions`
Expected: `ModuleNotFoundError: No module named 'measure_questions'`

- [ ] **Step 3: `measure_questions.py` 와 `window_phrases.txt` 를 쓴다**

정의(스크립트 머리 docstring 에 그대로 적는다):
- 폴더 아래 `*.jsonl` 을 재귀로 읽는다(하위 agent 기록 포함). 경로 정렬 순서, 같은 `uuid` 는 처음 것만.
- 세는 질문은 직전 skill 이 devbrew 플러그인의 것(`devbrew_plugin(skill)`)인 질문이다.
- `out_of_window` — 질문 본문이나 어느 선택지 설명에 문구 목록의 문구가 하나라도 있다.
- `recommended` — 어느 라벨이 `(권장)` 또는 `(Recommended)` 를 가진다. `recommended_all_tradeoff` — 그 가운데 모든 설명에 「얻음:」과 「내줌:」이 있다.
- `review_decision` — 어느 라벨이 엔진의 상태어(고친다 · 그대로 둔다 · 나중에 정한다 · 채택 · 기각 · 보류 · 현재 변경 유지 · 이전 상태로 원복)로 시작한다. `review_decision_with_fulltext` — 그 가운데 본문에 「전문:」으로 시작하는 줄이 있다.
- 지적 id 는 `[0-9a-f]{8}#r\d+\.\d+` 다. 게이트 글 묶음은 도구 결과 글에서 `(<id>` 가 든 줄과 그 뒤 들여쓴 줄들(다음 `- ` 줄 앞까지)이다.
- 출력: 한 줄 요약 문장, 그다음 `json.dumps`(전체와 skill 별), `--pairs N` 이면 리뷰 결정 질문 N개까지 「질문 · 선택지 · 짝지은 게이트 묶음(없으면 `짝 없음`)」.

`window_phrases.txt` 의 처음 내용:

```
# 질문 창 밖의 글을 가리키는 문구 — measure_questions.py 와 shared/tests/test_window_phrases.sh 가 함께 읽는다.
위에 적었다
이유는 질문 위 글에
제안 이유는 게이트 앞 글
(위 「낮춘 지적」 절)
옵션 description 에 싣지 않습니다
```

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `cd tools/plain-language && python3 -m unittest -v test_measure_questions test_measure_output`
Expected: 모두 `ok`

- [ ] **Step 5: README 에 쓰는 법과 재측정 기준을 적는다**

`tools/plain-language/README.md` 의 목록에 한 항목을 더한다(문면 그대로):

```
- `measure_questions.py <세션 기록 폴더…> [--pairs N]` — 질문 도구 호출을 직전에 부른 skill 로 나눠, 창 밖을 가리키는 문구가 든 질문 수 · 추천이 있는 질문 가운데 모든 설명에 얻음 · 내줌이 있는 비율 · 리뷰 결정 질문 가운데 「전문」 줄이 있는 비율을 낸다. 읽기만 하고 결과는 화면에만 낸다 — 기록은 사용자의 것이라 결과 파일을 커밋하지 않는다. 문구 목록은 `window_phrases.txt`.
  - 고친 뒤(2026-11-15 추천의 대가 설계) 다시 잴 때의 기준: 창 밖을 가리키는 문구가 든 질문 0 · 리뷰 결정 질문의 「전문」 줄 비율 100% · 추천이 있는 질문의 얻음 · 내줌 비율이 PR 본문에 적힌 기준 수보다 높고, 모자란 질문은 `--pairs` 표본으로 읽는다 · 표본에서 리뷰어가 낸 길이 사라진 질문 0. 새 판을 깔고 리뷰를 몇 번 돈 뒤에 잰다.
```

- [ ] **Step 6: 고치기 전 기준 수를 잰다**

이 레포와 그 worktree 의 세션 기록 폴더 전부(`~/.claude/projects/` 아래, 레포 절대 경로의 `/` 와 `.` 를 `-` 로 바꾼 이름으로 시작하는 폴더들)를 인자로 준다.

Run: `python3 tools/plain-language/measure_questions.py "$HOME"/.claude/projects/"$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||; s|[/.]|-|g')"*`
Expected: rc 0, 요약 한 줄과 JSON. 그 JSON(수만 — 질문 글은 빼고)을 git 이 추적하지 않는 `~/.claude/sdd-mirror/present-tradeoffs/baseline.json` 에 손으로 옮겨 둔다(PR 본문 재료 — Task 15). 폴더가 없으면 만든다.

- [ ] **Step 7: 커밋**

```bash
git add tools/plain-language/measure_questions.py tools/plain-language/window_phrases.txt tools/plain-language/test_measure_questions.py tools/plain-language/README.md
git commit -m "feat(tools): 질문을 직전 skill 로 나눠 재는 측정 스크립트"
```

---

### Task 2: 공통 규칙 블록

**AC:** AC1 · AC2

**Files:**
- Modify: `shared/style/plain-language.md:3,6` 과 예시 줄(12행 뒤)
- Modify: 블록이 든 SKILL.md 10개 — `plugins/spec-distill/skills/{pm-interview,request-framing,reviewing-brief,spec-review,epic-conductor,roadmap-status}/SKILL.md` · `plugins/quality-gates/skills/{quality-pipeline,artifact-critique}/SKILL.md` · `plugins/project-init/skills/project-init/SKILL.md` · `plugins/plugin-audit/skills/plugin-audit/SKILL.md`
- Test: `shared/tests/test_plain_language_block.sh:30-34`

**Interfaces:**
- Produces: 새 6행의 문장들. Task 9 · 10 · 12 · 13 의 자리별 문면이 이 문장에 기댄다(「얻음: … · 내줌: …」 꼴).

- [ ] **Step 1: 락을 새 문면으로 바꾼다(실패하는 시험)**

`shared/tests/test_plain_language_block.sh` 의 `REC=` · `EXC=` 두 줄과 그 단언을 아래로 바꾼다.

```bash
REC='추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두. 추천이 있는 질문은 질문 창만 보고 고를 수 있게 쓴다 — 질문 위 글은 안 보일 수 있다. 모든 선택지의 설명을 「얻음: … · 내줌: …」 한 줄(길어도 세 줄)로 쓰고, 내줌은 그 선택이 틀렸다고 드러날 때 원인이 될 것 하나다. 추천이 없으면 아무 표시도 쓰지 않는다. 질문 없이 한쪽을 권하는 글에는 그 대가를 한 구절 붙인다.'
EXC='추천 표시와 대가 표기는 그 자리에서도 이 블록을 따른다 — 옮긴 질문의 선택지 순서와 설명, steelman 질문의 선택지 순서와 출처 표지만 예외다.'
EXA='예) 전: 설명 「더 낫다」 → 후: 「얻음: 겹치는 규칙을 한 번에 고친다 · 내줌: 일이 커져 설계가 길어진다」.'
assert_eq "$(grep -cF -- "$REC" "$ROOT/shared/style/plain-language.md")" "1" "AC1: 정본 6행에 추천과 대가 문장(양)"
assert_eq "$(grep -cF -- "$EXC" "$ROOT/shared/style/plain-language.md")" "1" "AC1: 정본 3행에 추천 · 대가 예외 문장(양)"
assert_eq "$(grep -cxF -- "$EXA" "$ROOT/shared/style/plain-language.md")" "1" "AC1: 정본에 얻음 · 내줌 예시 줄(양)"
assert_not_contains "$CANON" '여럿이면 모두, 이유는' "AC1: 정본에 옛 추천 꼬리가 없다(음)"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_plain_language_block.sh`
Expected: `AC1: 정본 6행에 추천과 대가 문장(양)` 등 넷이 ✗

- [ ] **Step 3: 정본을 고친다**

`shared/style/plain-language.md`:
- 3행에서 `추천 표시는 그 자리에서도 이 블록을 따른다 — 옮긴 질문과 steelman 질문의 선택지 순서, steelman 질문의 출처 표지만 예외다.` 를 위 `EXC` 문장으로 바꾼다. 그 앞뒤 문장은 그대로다.
- 6행 전체를 아래로 바꾼다.

```
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두. 추천이 있는 질문은 질문 창만 보고 고를 수 있게 쓴다 — 질문 위 글은 안 보일 수 있다. 모든 선택지의 설명을 「얻음: … · 내줌: …」 한 줄(길어도 세 줄)로 쓰고, 내줌은 그 선택이 틀렸다고 드러날 때 원인이 될 것 하나다. 추천이 없으면 아무 표시도 쓰지 않는다. 질문 없이 한쪽을 권하는 글에는 그 대가를 한 구절 붙인다.
```

- 12행(둘째 `예)` 줄) 바로 뒤, `<!-- plain-language:end -->` 앞에 위 `EXA` 줄을 더한다.

- [ ] **Step 4: SKILL.md 10개의 블록을 정본 바이트로 맞춘다**

파일마다 `<!-- plain-language:begin -->` 줄부터 `<!-- plain-language:end -->` 줄까지를 정본 파일의 전체 바이트로 바꾼다(한 번 쓰는 python 스크립트를 scratch 에 두고 돌린다 — 레포에 남기지 않는다). 바꾼 파일 수가 10 인지 스크립트가 센다.

- [ ] **Step 5: 돌려서 통과를 본다**

Run: `bash shared/tests/test_plain_language_block.sh`
Expected: `✗` 없음, 마지막 줄이 통과 집계

- [ ] **Step 6: 길이를 잰다**

Run: `python3 tools/plain-language/token_boundary.py --base "$(git merge-base HEAD "$BASE")"` 그리고 같은 명령에 `--body`
Expected: 새로 밀려난 **실제 `## ` 절**이 어느 SKILL.md 에도 없다(두 근사식 `cons` · `cent` 모두). 인터뷰 skill 의 라운드 양식 펜스 안 `## R<n>` 줄이 밀린 것은 실패가 아니다 — 그 줄과 값(경계까지 남은 토큰)을 `~/.claude/sdd-mirror/present-tradeoffs/token-boundary.txt` 에 옮겨 둔다(PR 본문 공시 재료). 실제 절이 밀렸으면 멈추고 보고한다(설계의 측정과 다르다).

- [ ] **Step 7: 커밋**

```bash
git add shared/style/plain-language.md shared/tests/test_plain_language_block.sh plugins/*/skills/*/SKILL.md
git commit -m "feat(shared): 추천에 얻음 · 내줌을 적게 하는 공통 규칙"
```

---

### Task 3: 질문 자리 검사가 설명의 얻음 · 내줌을 본다

**AC:** AC15

**Files:**
- Modify: `shared/tests/ask_recommendation.py`
- Modify: `shared/tests/fixtures/ask_recommendation/{doc.md,sites.tsv,expected.txt}`
- Modify: `shared/tests/fixtures/ask-sites.tsv:1-4`(머리 주석)
- Modify: `shared/tests/test_ask_recommendation.sh`

**Interfaces:**
- Produces: 목록 tsv 의 여섯째 칸 「설명 수」와 판정 ⑤. 뒤 Task(8 · 9 · 10 · 12 · 13)가 자기 행의 그 칸을 채운다. Task 14 가 `REQUIRE_DESCS` 를 켠다.
  - `Site` 에 필드 `descs: str` 추가(여섯째 칸, 없으면 `""`). 줄의 칸 수는 3~6 을 받는다.
  - `REQUIRE_DESCS: tuple[str, ...] = ()` — 이 종류의 행은 「설명 수」가 비면 ⑤ 다. 이 Task 에서는 빈 튜플이다.
  - 판정: 「설명 수」가 채워진 행(수 N)에서, 범위에 `label:` 키가 있으면 범위의 `description:` 값이 정확히 N 개이고 값마다 `얻음:` 과 `내줌:` 이 있어야 한다. `label:` 키가 없으면(표 · 문장 꼴) 범위의 `얻음:` 수와 `내줌:` 수가 각각 N 이어야 한다. N 이 0 이면 보지 않는다. 어긋나면 `no ⑤ <경로>:<줄> <종류> 「<앵커>」 (목록 L<n>): <사유>`.
  - 「설명 수」는 `꼬리` · `지시` · `출처꼬리` 행에만 쓴다. 그 밖의 종류에 쓰였거나 수가 아니면 ② 다.

- [ ] **Step 1: fixture 에 경우를 더한다(실패하는 시험)**

`fixtures/ask_recommendation/doc.md` 끝에 일곱 블록을 더하고 `sites.tsv` 에 행을 더한다(앵커는 블록 첫 줄의 `카-질문:` … `하-질문:` 꼴 — 지금 fixture 의 이름 규칙을 잇는다).

| 블록 | 꼴 | 설명 수 | 기대 |
|---|---|---|---|
| 카 | `label:` 둘, 설명 둘 모두 `얻음: … · 내줌: …` | 2 | `ok` |
| 타 | `label:` 둘, 둘째 설명에 `내줌:` 없음 | 2 | `no ⑤ … 설명 2개 가운데 1개에 「내줌:」이 없다` |
| 파 | `label:` 둘, `description:` 하나뿐 | 2 | `no ⑤ … 범위의 설명이 1개인데 목록의 설명 수는 2다` |
| 하 | 표 꼴, `얻음:` 셋 `내줌:` 셋 | 3 | `ok` |
| 거 | 표 꼴, `얻음:` 셋 `내줌:` 둘 | 3 | `no ⑤ … 범위의 「내줌:」이 2개인데 목록의 설명 수는 3이다` |
| 너 | `비움` 행에 설명 수 `2` | — | `no ② … 설명 수 칸 「2」는 꼬리 · 지시 · 출처꼬리 행에만 쓴다` |
| 더 | `꼬리` 행에 설명 수 `둘` | — | `no ② … 설명 수 칸 「둘」이 수가 아니다` |

`expected.txt` 에 위 `no` 줄 다섯을 판정 순서대로 더한다. `test_ask_recommendation.sh` 에 `assert_contains "$FX_OUT" 'ok doc.md:<카 줄> 꼬리 「카-질문:」'` 과 `「하-질문:」` 둘을 더한다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_ask_recommendation.sh`
Expected: `fixture: no 줄이 expected.txt 와 같다` 가 ✗ (칸 수 6 인 행이 「칸 수가 맞지 않다」로 나온다)

- [ ] **Step 3: `ask_recommendation.py` 를 고친다**

`load_sites` 가 3~6 칸을 받게 하고, `scope()` 의 칸 검증에 「설명 수」 둘을 더하고, `check()` 에서 `required()` 가 통과한 행에 ⑤ 판정을 건다. 설명 값은 `LABEL_RE` 와 같은 꼴의 정규식을 키 `description` 으로 읽는다. 모듈 docstring 의 입력 · 출력 줄에 여섯째 칸과 ⑤ 를 적는다. `ask-sites.tsv` 머리 주석 넷째 줄을 `# 경로	종류	앵커	끝	덮는 수	설명 수` 로 바꾸고 한 줄을 더한다: `# 설명 수: 그 질문에서 skill 글이 적어 둔 선택지 설명의 수 — 채우면 설명마다 「얻음:」 · 「내줌:」이 있는지 본다(0 이면 보지 않는다).`

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_ask_recommendation.sh`
Expected: `✗` 없음. 실제 목록(`ask-sites.tsv`)의 행은 아직 「설명 수」가 비어 판정이 달라지지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add shared/tests/ask_recommendation.py shared/tests/test_ask_recommendation.sh shared/tests/fixtures/ask-sites.tsv shared/tests/fixtures/ask_recommendation
git commit -m "test(shared): 질문 자리 검사가 설명의 얻음 · 내줌을 본다"
```

---

### Task 4: 엔진 — 짧은 경고 줄과 상태 줄

**AC:** AC6

**Files:**
- Create: `shared/docreview/scripts/docreview_ask.py`
- Create(링크): `plugins/spec-distill/scripts/docreview_ask.py` · `plugins/quality-gates/scripts/docreview_ask.py` → `../../../shared/docreview/scripts/docreview_ask.py`(옆의 `docreview_advice.py` 링크와 같은 꼴 — `readlink` 로 그 대상을 보고 맞춘다)
- Modify: `shared/docreview/scripts/docreview_state.py:36-41`(형제 import) · `2199-2292`(`WARN_GLOSS` · `_plain_warns` · `_first_line`)
- Create: `shared/tests/fixtures/docreview/cases_ask.sh`
- Create: `shared/tests/test_docreview_ask.sh`(100755)

**Interfaces:**
- Produces (`docreview_ask.py` — leaf, 표준 라이브러리만, `docreview_state` 를 import 하지 않는다):
  - `short_warn_line(entries: list[tuple[str | None, str]]) -> str` — `entries` 가 비면 `""`. 아니면 `"리뷰 경고 %d개: %s"`. 뒤쪽은 짧은 이름을 처음 나온 순서로 `" · "` 로 잇고, 같은 이름이 k(≥2)번이면 `"<이름> ×k"`, 짧은 이름이 `None` 인 것은 맨 끝에 `"그 밖 N개"` 하나로 센다.
- Produces (`docreview_state.py`):
  - `WARN_GLOSS` 의 행마다 넷째 값(짧은 이름)을 더한다 — 아래 표.
  - `_warn_entries(warns) -> list[tuple[str | None, str]]` — (짧은 이름, 쉬운 줄). 줄의 순서 · 합치기 규칙은 지금 `_plain_warns` 그대로다. 표에 없는 원문은 `(None, 원문)`.
  - `_plain_warns(warns)` 는 `[line for _, line in _warn_entries(warns)]` 를 낸다(출력 바이트 그대로).
  - `_gate_warns(g) -> list[str]` — `_first_line` 안의 원문 모으기(advisory + codex 부재 줄 끼우기)를 그대로 옮긴 것. `_first_line` 이 이것을 부른다.
  - `status_line(g) -> str` — 질문의 상태 줄. 공시(`lead`)가 있으면 `lead + "."` 뒤에 짧은 경고 줄이 있으면 `" " + 짧은 줄`. 공시가 없고 경고가 있으면 짧은 경고 줄. 둘 다 없으면 남은 행이 없을 때 `"이상 없음"`, 있을 때 `"경고 없음"`.
  - 형제 import: `try: import docreview_ask as _ask / except ImportError: _ask = None`(`_adv` 와 같은 자리 · 같은 모양).

`WARN_GLOSS` 짧은 이름(행 순서대로):

| 행의 괄호 이름 또는 쉬운 문장 | 짧은 이름 |
|---|---|
| codex (두 행) | `codex 리뷰 없음` |
| doc-recritic (두 행) | `재비판 없음` |
| layer2 (두 행) | `세부 검토 없음` |
| 앵커 불가 | `제목 없는 문서` |
| critic 시점 | `리뷰어 결과 시점 모름` |
| 탐지 | `탐지 리뷰어 일부 없음` |
| 꼭 있어야 할 리뷰어 결과를 읽지 못했다 | `주 리뷰어 결과 없음` |
| 보조 리뷰어 결과를 읽지 못했다 | `보조 리뷰어 결과 없음` |
| 셀 수 없는 것이 있다 | `셀 수 없는 것` |
| 판정하지 못하고 보류한 지적이 있다 | `보류한 지적` |
| 결정 id — 기록에서 찾지 못해 | `결정 id 못 찾음` |
| 결정 id — 이 자리를 다룬 채택이 아니라서 | `결정 id 자리 다름` |
| 결정 id — 모양이 틀려 | `결정 id 모양 틀림` |
| 판정 값을 강제로 바꿨고 | `판정 강제 변경` |

- [ ] **Step 1: 실패하는 시험을 쓴다**

`shared/tests/fixtures/docreview/cases_ask.sh`(계약은 `cases.sh` 머리와 같다 — `cases.sh` 다음에 source 한다):

```bash
status_of() { PYTHONPATH="$SCRIPTS" python3 -c 'import sys, docreview_state as S
st = S.load_state(sys.argv[1]); print(S.status_line(S.gate_summary(st)))' "$1"; }

case_ask_short_warn_line_unit() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_ask import short_warn_line
print(short_warn_line([("codex 리뷰 없음", "a"), (None, "b"), ("보류한 지적", "c"), ("보류한 지적", "d"), (None, "e")]))
print(repr(short_warn_line([])))')"
  assert_eq "$got" "리뷰 경고 5개: codex 리뷰 없음 · 보류한 지적 ×2 · 그 밖 2개
''" "짧은 경고 줄: 처음 나온 순서 · 같은 이름은 ×k · 표에 없는 것은 그 밖 N개 · 없으면 빈 글"
}
case_ask_status_count_equals_first_line() {   # AC6 — 같은 목록에서 센다
  local d f s; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "상태 줄: route_r1 실패"; return; }
  f="$(gfirst "$d")"; s="$(status_of "$d")"
  assert_contains "$f" "경고 3개: " "상태 줄 전제: 게이트 첫 줄의 경고는 셋이다"
  assert_eq "${s%%:*}" "리뷰 경고 3개" "상태 줄: 개수가 게이트 첫 줄과 같고 머리에 채널 이름이 있다"
  for n in 'codex 리뷰 없음' '재비판 없음' '세부 검토 없음'; do assert_contains "$s" "$n" "상태 줄: 짧은 이름 「${n}」"; done
  assert_not_contains "$s" "다른 모델의 시각" "상태 줄: 긴 쉬운 문장은 싣지 않는다"
  rm -rf "$d"
}
case_ask_status_no_warns() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "상태 줄: route_r1 실패"; return; }
  assert_eq "$(status_of "$d")" "경고 없음" "상태 줄: 경고는 없고 남은 것이 있으면 「경고 없음」"
  rm -rf "$d"
}
case_ask_status_nothing_left() {   # case_plain_render_nothing_left 와 같은 준비(그 케이스 본문의 route_r1 줄을 그대로 쓴다)
  assert_eq "$(status_of "$d")" "이상 없음" "상태 줄: 남은 것도 경고도 없으면 「이상 없음」"
}
case_ask_status_unverified() {     # case_T46_critic_dead_twice_unverified 와 같은 준비
  local s; s="$(status_of "$d")"
  assert_eq "$s" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다." "상태 줄: 미검증이면 그 공시의 첫 문장이고 두 문구는 쓰지 않는다"
}
case_ask_unknown_warn_counted() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S, docreview_ask as A
e = S._warn_entries(["표에 없는 경고 하나", "codex 없음 — 모델 다양성 0 (exit_nonzero)"])
print(e[0]); print(A.short_warn_line(e))')"
  assert_eq "$got" "(None, '표에 없는 경고 하나')
리뷰 경고 2개: codex 리뷰 없음 · 그 밖 1개" "짧은 경고 줄: 표에 없는 원문도 센다(버리지 않는다)"
}
case_ask_warn_gloss_short_names_total() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S
print(all(len(r) == 4 and isinstance(r[3], str) and 0 < len(r[3]) <= 14 for r in S.WARN_GLOSS))')"
  assert_eq "$got" "True" "경고 표: 모든 행에 열네 글자 안의 짧은 이름이 있다(∀)"
}
case_ask_plain_warns_unchanged() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import docreview_state as S
w = ["codex 없음 — 모델 다양성 0 (exit_nonzero)", "셀 수 없음: layer2 — block missing", "표에 없는 경고", "보류: a", "보류: a"]
print(S._plain_warns(w) == [l for _, l in S._warn_entries(w)], len(S._plain_warns(w)))')"
  assert_eq "$got" "True 5" "경고 표: 쉬운 줄 목록은 그대로이고 같은 글자의 사건은 따로 센다"
}
```

「같은 준비」라고 적은 케이스는 이름을 댄 `cases.sh` 케이스의 준비 줄(상태 폴더 `d` 를 만드는 줄들)을 그대로 옮기고 끝에 `rm -rf "$d"` 를 둔다. 준비가 실패하면 `no "<케이스>: 준비 실패"; return` 한다.

`shared/tests/test_docreview_ask.sh` 는 `shared/tests/test_docreview_advice.sh` 의 머리(guards 줄 · `--emit-scanned` · `assert.sh` · `SCRIPTS` · `cases.sh` 와 `cases_advice.sh` source)를 그대로 따르되 guards 와 `--emit-scanned` 에 `shared/docreview/scripts/docreview_ask.py` 를 더하고, `cases_ask.sh` 를 source 한 뒤 위 케이스를 부르고 `finish` 한다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_docreview_ask.sh`
Expected: `ModuleNotFoundError: No module named 'docreview_ask'` 로 케이스들이 ✗

- [ ] **Step 3: 구현한다**

`docreview_ask.py` 에 `short_warn_line` 을 쓰고 링크 둘을 만든다(`ln -s`, 그다음 `git ls-files -s` 로 mode 120000 확인). `docreview_state.py` 에서 `WARN_GLOSS` 에 넷째 값을 더하고 `_warn_entries` · `_gate_warns` · `status_line` 을 더하고 `_plain_warns` · `_first_line` 이 새 함수를 쓰게 한다. `_plain_warns` 안의 `row = (row[0], row[1], row[2].format(...))` 줄은 넷째 값을 잇게 고친다.

- [ ] **Step 4: 돌려서 통과를 본다 — 게이트 글이 그대로인지도**

Run: `bash shared/tests/test_docreview_ask.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_gate_plain.sh && bash shared/tests/test_docreview_state.sh`
Expected: 넷 모두 `✗` 없음. `git status --short shared/tests/fixtures/docreview/golden` 은 빈 출력이다.

- [ ] **Step 5: 커밋**

```bash
git add shared/docreview/scripts/docreview_ask.py shared/docreview/scripts/docreview_state.py plugins/spec-distill/scripts/docreview_ask.py plugins/quality-gates/scripts/docreview_ask.py shared/tests/fixtures/docreview/cases_ask.sh shared/tests/test_docreview_ask.sh
git commit -m "feat(docreview): 질문에 싣는 짧은 경고 줄과 상태 줄"
```

---

### Task 5: 엔진 — 질문 재료(`ask-material`)

**AC:** AC4

**Files:**
- Modify: `shared/docreview/scripts/docreview_ask.py`
- Modify: `shared/docreview/scripts/docreview_config.py`
- Modify: `shared/docreview/scripts/docreview_state.py`(`cmd_ask_material` · `_ask_bundles` · `build_parser`)
- Modify: `plugins/spec-distill/tests/test_ledger_wiring.sh:132`(`AC8_READ_ONLY`)
- Modify: `plugins/spec-distill/README.md:220` 뒤(엔진 값 표)
- Test: `shared/tests/fixtures/docreview/cases_ask.sh` · `shared/tests/test_docreview_ask.sh`

**Interfaces:**
- Consumes: Task 4 의 `status_line(g)`.
- Produces:
  - `docreview_config.ASK_WIDTH_DEFAULT = 110` · `ASK_WIDTH_ENV = "DEVBREW_DOCREVIEW_ASK_WIDTH"` · `ask_width(env) -> int` — 값이 ASCII 숫자가 아니거나 20~500 밖이면 `ConfigInvalid("ask_width", raw, "환경 " + ASK_WIDTH_ENV)`.
  - `docreview_ask.FIXED_DESC: dict[str, tuple[str, str]]`(평문, 얻음 · 내줌) — 아래 표. `docreview_ask.KEEP_GAIN = "지금 글이 그대로 남는다"`.
  - `docreview_ask.ABSENT = {"replacement": "(대체안 미작성)", "if_unfixed": "(리뷰어가 안 적음)"}`.
  - `docreview_ask.length_mark(text: str | None, width: int) -> str` — `None` 이면 `"부재"`, 아니면 `"%d자 · 그대로"`(길이 ≤ width) 또는 `"%d자 · 줄인다"`. 길이는 공백을 접은 글의 코드 포인트 수.
  - `docreview_ask.full_text_line(result: str | None) -> str` — `gate-file` 이 낸 JSON 글. `{"ok": true, "shown": "<경로>"}` 면 `"전문: <경로>"`. `ok` 가 거짓이면 `"전문: 전문 파일을 쓰지 못했다 — <reason>"`(`detail` 이 있으면 `" · <detail>"`). `None` 이면 `"전문: 전문 파일을 쓰지 못했다 — 쓰는 명령을 부르지 않았다"`. JSON 이 아니면 `"… — 결과를 읽지 못했다"`.
  - `docreview_ask.render_material(bundles: list[dict], status: str, full_text: str, width: int, tail: list[str]) -> str`
  - CLI: `docreview_state.py ask-material --state-dir D [--gate-file-result <JSON>] [--fix-rows] [--ask-rows]` — **읽기 전용**(원장 · 파일을 쓰지 않는다). 모듈이 없으면 `fail("ask_module_missing")`.

고정 설명(문구는 엔진 동작과 맞췄다 — `cmd_decide` 의 hold · post 갈래와 `_rg_held_decide`):

| 키 | 라벨 | 평문 | 얻음 · 내줌 |
|---|---|---|---|
| `hold` | 나중에 정한다(보류) | 지금 정하지 않는다 — 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다 | 얻음: 지금 정하지 않고 넘어간다 · 내줌: 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다 |
| `post_adopt` | 현재 변경 유지(채택) | 바뀐 글을 받아들인다 — 되돌릴 의무가 끝나고 리뷰가 다시 확인하지 않는다 | 얻음: 바뀐 글이 그대로 남는다 · 내줌: 허가 없이 바뀐 글을 받아들여 되돌릴 의무가 끝난다 |
| `post_reject` | 이전 상태로 원복(기각) | 바뀐 글을 이전 글로 되돌려야 한다 — 다음 라운드가 확인할 때까지 승인이 막힌다 | 얻음: 허가 없이 바뀐 글이 이전 글로 돌아간다 · 내줌: 손으로 되돌려야 하고 다음 라운드가 확인할 때까지 승인이 막힌다 |
| `extra_open` | 추가 라운드 1회 열기 · 열기 | 상한 밖 리뷰를 한 번 더 돈다 | 얻음: 고친 글을 리뷰가 한 번 더 본다 · 내줌: 상한 밖 라운드를 한 번 더 돌아 다음 단계가 그만큼 늦어진다 |
| `extra_skip` | 열지 않음 | 추가 라운드를 열지 않는다 — 남은 항목은 이 게이트에서 정한다 | 얻음: 리뷰를 이 라운드에서 닫는다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다 |
| `to_options` | 진행 옵션으로 | 추가 라운드 없이 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계 질문으로 간다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다 |
| `approve_with_open` | 열린 지적 %d개를 두고 진행 | 열린 지적 %d개를 둔 채 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계로 간다 · 내줌: 열린 지적 %d개가 풀리지 않은 채 넘어간다 |

묶음(GATE_ROWS 렌더 순서, 묶음 사이 빈 줄 하나):

- `open_decide` · `blocked_expired` 행 → **전체 묶음**.
- `unapplied_fix` 행 → `--fix-rows` 일 때만 전체 묶음. 선택지는 `적용 / 적용하지 않음`, 「고정 얻음」의 라벨은 `적용하지 않음`.
- `blocking_ask_open` 행 → 짧은 묶음. `ask_open` 행 → `--ask-rows` 일 때만 짧은 묶음.
- 그 밖의 행 → 내지 않는다.
- `g["two_stage"] and g["next_round_mode"] == "extra_approval"` 이면 맨 끝에 **추가 라운드 묶음**. 선택지는 `g["approval_ready"]` 이면 `추가 라운드 1회 열기 / 진행 옵션으로`, 아니면 `열기 / 열지 않음`.
- `g["two_stage"] and not g["approval_ready"]` 이면 묶음들 뒤에 꼬리 한 줄: `승인 선택지 고정 설명: 열린 지적 N개를 두고 진행 = <평문> | <얻음 · 내줌>`(N = `g["open_total"]`).

전체 묶음의 줄(사전 결정 · 선택지 셋일 때):

```
질문 1/3 (dec7d5b2#r1.1)
본문: <요약 칸 — 공백만 접고 글자 그대로>
상태: <status_line>
전문: <full_text_line 의 「전문: 」 뒤>
선택지: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)
고치면 (191자 · 줄인다): <대체안 칸 전문 — 없으면 (대체안 미작성), 표시는 (부재)>
그대로 두면 (84자 · 그대로): <그대로 두면 칸 전문 — 없으면 (리뷰어가 안 적음)>
덧줄: <있을 때만, 한 줄에 하나>
고정 얻음: 그대로 둔다(기각) = 지금 글이 그대로 남는다
고정 설명: 나중에 정한다(보류) = <평문> | <얻음 · 내줌>
```

- 선택지는 `decide_choices(st, fid)` 를 `choice_label` 로 바꾼 것이다(「고친다」를 고를 수 없으면 빠진다 — 지금 규칙).
- 두 칸은 `decision_view` 의 `replacement` · `if_unfixed`, 없으면 finding 의 같은 이름 칸.
- 덧줄의 원천 넷, 이 순서: `_post_kind_notice(d)`(앞의 `" — "` 를 뗀다) · 반대라고 한 결정(`"반대라고 한 결정: " + contradicts`) · `_adopt_unavailable_line` · `_revert_target_flagged_line`(뒤 둘은 앞의 `"  ↳ "` 를 뗀다).
- 사후(`post`) 결정은 「고정 얻음」 줄이 없고 선택지마다 「고정 설명」 줄이 있다(`post_adopt` · `post_reject` · `hold`).
- 짧은 묶음은 머리 줄 · 본문 · 상태 · 전문 다음에 `렌더: <그 행의 게이트 글 한 줄에서 앞의 "- " 를 뗀 것>` 한 줄이다.
- 추가 라운드 묶음: 머리 `질문 n/n (추가 라운드)`, `본문: 재리뷰 상한에 닿았다 — 리뷰를 한 번 더 열지 정한다`, 상태 · 전문 · 선택지, 선택지마다 「고정 설명」.

- [ ] **Step 1: 실패하는 시험을 쓴다**

`cases_ask.sh` 에 더한다.

```bash
mat() { py docreview_state.py ask-material --state-dir "$1" "${@:2}"; }   # mat <state-dir> [플래그…]

case_ask_material_decide_bundle() {
  local d m fid; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "질문 재료: route_r1 실패"; return; }
  fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "다른 것을 겨눈다" in x["summary"]][0]')"
  local before rb; before="$(cksum < "$d/docreview-state.md")"; rb="$(py docreview_state.py gate --state-dir "$d" --render | cksum)"
  m="$(mat "$d" --gate-file-result '{"ok": true, "shown": "~/x/gate-r1.md"}')"
  assert_grep "$m" "^질문 [0-9]+/[0-9]+ \(${fid}\)$" "질문 재료: 머리 줄에 차례와 지적 id"
  assert_contains "$m" "본문: Goals 가 브리프의 goal 과 다른 것을 겨눈다" "질문 재료: 본문은 리뷰어의 요약 칸 그대로"
  assert_grep "$m" '^상태: 리뷰 경고 [0-9]+개: ' "질문 재료: 상태 줄은 짧은 경고 줄"
  assert_contains "$m" "전문: ~/x/gate-r1.md" "질문 재료: 전문 줄은 받은 경로 그대로"
  assert_contains "$m" "선택지: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)" "질문 재료: 선택지는 엔진 라벨"
  assert_contains "$m" "고치면 (24자 · 그대로): §2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "질문 재료: 고치면 칸 전문과 길이 표시"
  assert_contains "$m" "그대로 두면 (22자 · 그대로): 설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "질문 재료: 그대로 두면 칸 전문과 길이 표시"
  assert_contains "$m" "고정 얻음: 그대로 둔다(기각) = 지금 글이 그대로 남는다" "질문 재료: 그대로 둔다의 얻음은 엔진 문구"
  assert_contains "$m" "고정 설명: 나중에 정한다(보류) = 지금 정하지 않는다 — 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다 | 얻음: 지금 정하지 않고 넘어간다 · 내줌: 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다" \
    "질문 재료: 보류의 고정 설명이 두 꼴이고 엔진이 실제로 하는 일을 적는다"
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "질문 재료: 원장을 쓰지 않는다(읽기 전용)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | cksum)" "$rb" "질문 재료: 부른 뒤에도 게이트 글이 같다"
  rm -rf "$d"
}
case_ask_material_length_mark_uses_width() {   # 같은 준비, 환경 값 20
  local m; m="$(DEVBREW_DOCREVIEW_ASK_WIDTH=20 mat "$d")"
  assert_contains "$m" "고치면 (24자 · 줄인다): " "질문 재료: 기준 길이를 넘으면 「줄인다」"
  local rc; DEVBREW_DOCREVIEW_ASK_WIDTH=5 mat "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "질문 재료: 기준 길이가 허용 범위 밖이면 rc 2"
}
case_ask_material_absent_fields() {            # case_decision_view_absence_is_literal 과 같은 준비(두 칸이 없는 지적)
  local m r; m="$(mat "$d")"; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$m" "고치면 (부재): (대체안 미작성)" "질문 재료: 대체안이 없으면 부재 표기"
  assert_contains "$m" "그대로 두면 (부재): (리뷰어가 안 적음)" "질문 재료: 그대로 두면이 없으면 부재 표기"
  assert_contains "$r" "고치면: (대체안 미작성)" "질문 재료 짝: 게이트 글의 부재 표기와 글자가 같다"
  assert_contains "$r" "그대로 두면: (리뷰어가 안 적음)" "질문 재료 짝: 게이트 글의 부재 표기와 글자가 같다"
}
case_ask_material_post_decision() {            # case_T35_frozen_change_auto_decide 와 같은 준비(허가 없이 바뀐 절)
  local m; m="$(mat "$d")"
  assert_contains "$m" "선택지: 현재 변경 유지(채택) / 이전 상태로 원복(기각) / 나중에 정한다(보류)" "질문 재료: 사후 결정의 선택지"
  assert_contains "$m" "덧줄: 「채택」은 원복 의무를 관측 없이 종결한다" "질문 재료: 사후 채택이 뜻하는 것이 덧줄에 있다"
  assert_contains "$m" "고정 설명: 현재 변경 유지(채택) = 바뀐 글을 받아들인다 — 되돌릴 의무가 끝나고 리뷰가 다시 확인하지 않는다 | 얻음: 바뀐 글이 그대로 남는다 · 내줌: 허가 없이 바뀐 글을 받아들여 되돌릴 의무가 끝난다" "질문 재료: 현재 변경 유지의 고정 설명"
  assert_contains "$m" "고정 설명: 이전 상태로 원복(기각) = 바뀐 글을 이전 글로 되돌려야 한다 — 다음 라운드가 확인할 때까지 승인이 막힌다 | " "질문 재료: 원복의 고정 설명"
  assert_not_contains "$m" "고정 얻음: " "질문 재료: 사후 결정에는 「고정 얻음」 줄이 없다"
}
case_ask_material_adopt_unavailable() {        # case_AC38_r3_f5_gate_adopt_unavailable 와 같은 준비
  local m; m="$(mat "$d")"
  assert_contains "$m" "선택지: 그대로 둔다(기각) / 나중에 정한다(보류)" "질문 재료: 고를 수 없는 「고친다」는 선택지에 없다"
  assert_contains "$m" "덧줄: 고친다(채택)는 고를 수 없다 — " "질문 재료: 그 이유가 덧줄에 있다"
}
case_ask_material_fix_rows_flag() {            # case_plain_render_fix_and_decide 와 같은 준비(고칠 곳 하나 + 정할 것 하나)
  local a b; a="$(mat "$d")"; b="$(mat "$d" --fix-rows)"
  assert_not_contains "$a" "선택지: 적용 / 적용하지 않음" "질문 재료: 플래그가 없으면 수정 행은 묶음이 없다"
  assert_contains "$b" "선택지: 적용 / 적용하지 않음" "질문 재료: --fix-rows 면 수정 행도 전체 묶음"
  assert_contains "$b" "고정 얻음: 적용하지 않음 = 지금 글이 그대로 남는다" "질문 재료: 적용하지 않음의 얻음은 엔진 문구"
  assert_contains "$b" "고치면 (" "질문 재료: 수정 행에도 두 칸이 있다"
}
case_ask_material_blocking_ask_short() {       # case_T31_T34_blocked_fix_held_gate_opens 와 같은 준비
  local m; m="$(mat "$d")"
  assert_contains "$m" "렌더: " "질문 재료: 수정의 전제가 되는 질문은 짧은 묶음"
  assert_contains "$m" "이 답을 기다리는 수정 " "질문 재료: 짧은 묶음의 렌더 줄은 게이트 글의 그 줄"
}
case_ask_material_extra_round() {              # case_cap_zero_open_two_stage 와 같은 준비(상한 도달 · 열린 것 0)
  local m; m="$(mat "$d")"
  assert_contains "$m" "(추가 라운드)" "질문 재료: 상한에 닿으면 추가 라운드 묶음"
  assert_contains "$m" "선택지: 추가 라운드 1회 열기 / 진행 옵션으로" "질문 재료: 열린 것이 0 이면 두 선택지"
  assert_contains "$m" "고정 설명: 진행 옵션으로 = 추가 라운드 없이 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계 질문으로 간다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다" "질문 재료: 진행 옵션으로의 고정 설명"
}
case_ask_material_approve_with_open_tail() {   # case_AC13_open_count_and_label 과 같은 준비(상한 · 열린 지적 있음)
  local m n; m="$(mat "$d")"; n="$(py docreview_state.py gate --state-dir "$d" | jgets 'd["open_total"]')"
  assert_contains "$m" "선택지: 열기 / 열지 않음" "질문 재료: 열린 것이 있으면 추가 라운드는 열기 · 열지 않음"
  assert_contains "$m" "승인 선택지 고정 설명: 열린 지적 ${n}개를 두고 진행 = 열린 지적 ${n}개를 둔 채 다음 단계 질문으로 간다 | 얻음: 리뷰를 닫고 다음 단계로 간다 · 내줌: 열린 지적 ${n}개가 풀리지 않은 채 넘어간다" "질문 재료: 승인 선택지의 고정 설명이 꼬리에 있다"
}
case_ask_material_gate_file_failed() {
  local m; m="$(mat "$d" --gate-file-result '{"ok": false, "reason": "gate_file_write_failed", "detail": "Permission denied"}')"
  assert_contains "$m" "전문: 전문 파일을 쓰지 못했다 — gate_file_write_failed · Permission denied" "질문 재료: 전문을 못 썼으면 그 사유가 전문 줄에 나온다"
  assert_contains "$(mat "$d")" "전문: 전문 파일을 쓰지 못했다 — 쓰는 명령을 부르지 않았다" "질문 재료: 결과를 받지 못했으면 그렇게 알린다"
  assert_contains "$(mat "$d" --gate-file-result '깨진 글')" "전문: 전문 파일을 쓰지 못했다 — 결과를 읽지 못했다" "질문 재료: 결과가 JSON 이 아니면 그렇게 알린다"
}
```

「같은 준비」라고 적은 케이스는 이름을 댄 `cases.sh` 케이스의 준비 줄(상태 폴더 `d` 를 만드는 줄들)을 그대로 옮기고 끝에 `rm -rf "$d"` 를 둔다. 준비가 실패하면 `no "<케이스>: 준비 실패"; return` 한다. `test_docreview_ask.sh` 의 부름 목록에 위 케이스를 더한다. 길이 표시의 숫자(24 · 22)는 fixture 글의 실제 코드 포인트 수다 — 다르면 fixture 를 세어 시험의 숫자를 고친다(구현을 숫자에 맞추지 않는다).

`plugins/spec-distill/tests/test_ledger_wiring.sh:132` 의 목록에 이름을 더한다:

```bash
AC8_READ_ONLY="advice-list ask-material gate related-changes state-dir-for profile-check gate-rows exempt-anchors"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_docreview_ask.sh`
Expected: `invalid choice: 'ask-material'` 로 새 케이스들이 ✗

- [ ] **Step 3: 구현한다**

`docreview_config.py` 에 `ask_width`, `docreview_ask.py` 에 위 Produces 의 상수와 함수, `docreview_state.py` 에 `_ask_bundles(st, g, fix_rows, ask_rows) -> list[dict]`(행을 묶음 dict 로 — 키 `kind`(`full` · `short` · `extra`) · `id` · `summary` · `choices` · `replacement` · `if_unfixed` · `notes` · `fixed` · `keep_label` · `render`) 와 `cmd_ask_material`, `build_parser` 에 `x = sd(P("ask-material")); x.add_argument("--gate-file-result", default=None); x.add_argument("--fix-rows", action="store_true"); x.add_argument("--ask-rows", action="store_true"); x.set_defaults(fn=cmd_ask_material)`. `cmd_ask_material` 은 `save_state` 를 부르지 않는다. `ConfigInvalid` 는 `fail("config_invalid", …)` 와 rc 2(다른 명령의 꼴 그대로). `docreview_state.py` 머리 docstring 의 서브커맨드 줄에 `ask-material` 을 더한다. `plugins/spec-distill/README.md` 의 엔진 값 표 끝에 행을 더한다: `| \`DEVBREW_DOCREVIEW_ASK_WIDTH\` | — | 질문 설명의 기준 길이(20~500) — 넘는 원문 칸에 「줄인다」를 표시한다 | 110 |`(칸 수와 순서는 그 표의 머리를 따른다).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_docreview_ask.sh && bash shared/tests/test_docreview_golden.sh && bash plugins/spec-distill/tests/test_ledger_wiring.sh`
Expected: 셋 모두 `✗` 없음. (`test_ledger_wiring.sh` 의 「원장 쓰기 명령 문단 = 엔진 쓰기 하위 명령」 단언은 `ask-material` 이 읽기 전용 목록에 있어 그대로 통과한다.)

- [ ] **Step 5: 커밋**

```bash
git add shared/docreview/scripts plugins/spec-distill/tests/test_ledger_wiring.sh plugins/spec-distill/README.md shared/tests/fixtures/docreview/cases_ask.sh shared/tests/test_docreview_ask.sh
git commit -m "feat(docreview): 질문으로 뜨는 행마다 질문 재료를 내는 읽기 전용 명령"
```

---

### Task 6: 엔진 — 전문 파일(`gate-file`)

**AC:** AC5

**Files:**
- Modify: `shared/docreview/scripts/docreview_ask.py`
- Modify: `shared/docreview/scripts/docreview_state.py`(`cmd_gate_file` · `build_parser` · 형제 import `nofollow_write`)
- Modify: `plugins/spec-distill/skills/{spec-review,reviewing-brief,request-framing}/SKILL.md`(「**원장 쓰기 전 확인.**」 문단의 명령 열거)
- Test: `shared/tests/fixtures/docreview/cases_ask.sh` · `shared/tests/test_docreview_ask.sh`

**Interfaces:**
- Consumes: `render_gate(st, g)`, `shared/docreview/scripts/nofollow_write.py` 의 `replace_bytes(path, data)`(마지막 성분이 링크여도 링크를 따라가지 않고 그 이름을 새 파일로 바꾼다 — 그래서 쓰기 전에 `os.path.islink(path)` 를 직접 보고 거부한다).
- Produces:
  - CLI: `docreview_state.py gate-file --state-dir D` — **쓰기 명령**(읽기 전용 목록에 넣지 않는다). 원장은 바꾸지 않는다. 파일 `<D>/gate-r<라운드>.md` 를 쓴다.
    - 성공: stdout JSON `{"ok": true, "path": "<절대 경로>", "shown": "<보이는 경로>", "round": n}`, rc 0.
    - 실패: `fail("gate_file_write_failed", path=…, detail=…)`(rc 1). 마지막 성분이 링크면 `detail` 은 `"링크다 — 따라가지 않는다"`.
  - `docreview_ask.ZONE_GATE = "## 지금 게이트 글"` · `ZONE_ORIGINALS = "## 이 라운드의 지적 원문"` · `ZONE_CHANNELS = "## 다른 채널의 경고"`.
  - `docreview_ask.originals_block(items: list[dict]) -> str` — 항목마다 `- <요약> (<id>)` 와 들여쓴 넷(`그대로 두면:` · `고치면:` · `근거:` · `자리:`). 칸이 없으면 `ABSENT` 표기(근거 · 자리는 `—`). 항목이 없으면 `없음 — 이 라운드에 판정을 지난 지적이 없다`.
  - `docreview_ask.keep_originals(old_text: str | None) -> str | None` — 옛 파일 글에서 `ZONE_ORIGINALS` 줄 다음부터 `ZONE_CHANNELS` 줄 앞(없으면 끝)까지. 구역이 없으면 `None`.
  - `docreview_ask.gate_file_text(round_n: int, gate_text: str, originals: str) -> str` — `# 리뷰 <n>라운드 — 게이트 전문` · 빈 줄 · `ZONE_GATE` · 게이트 글 · 빈 줄 · `ZONE_ORIGINALS` · 원문 구역. 끝은 개행 하나.
  - `docreview_ask.display_path(path: str, cwd: str, home: str) -> str` — `cwd` 아래면 상대 경로, 아니고 `home` 아래면 `~/…`, 둘 다 아니면 그대로.
- 원문 구역에 드는 항목: `st["findings"]` 가운데 id 가 이번 라운드 것(`#r<n>.`)이고 `state` 가 `rejected` 가 아닌 것 전부(참고로 간 항목 포함), id 순.
- 다시 부르면: 「지금 게이트 글」 구역은 그때의 게이트 글로 새로 쓰고, 「이 라운드의 지적 원문」 구역은 **옛 파일의 글을 그대로 잇는다**(`keep_originals` 가 값을 내면 그것, `None` 이면 새로 짓는다). 「다른 채널의 경고」 구역은 엔진이 쓰지 않는다 — 부른 펜스가 매번 덧붙인다(Task 7).

- [ ] **Step 1: 실패하는 시험을 쓴다**

```bash
gfile() { py docreview_state.py gate-file --state-dir "$1"; }

case_gate_file_two_zones_match_render() {      # case_ask_material_decide_bundle 과 같은 준비
  local out p; out="$(gfile "$d")"; p="$(printf '%s' "$out" | jgets 'd["path"]')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["ok"], d["round"]')" "(True, 1)" "전문 파일: 성공 JSON"
  assert_eq "${p##*/}" "gate-r1.md" "전문 파일: 라운드마다 파일 하나(gate-r<라운드>.md)"
  local zone1; zone1="$(awk '/^## 지금 게이트 글$/{f=1;next} /^## 이 라운드의 지적 원문$/{f=0} f' "$p" | sed -e '$ d')"
  assert_eq "$zone1" "$(py docreview_state.py gate --state-dir "$d" --render)" "전문 파일: 「지금 게이트 글」 구역이 그때의 게이트 글과 같다"
  assert_file_grep "$p" '^  고치면: §2 를 브리프 §1 의 goal 한 문장으로 되돌린다$' "전문 파일: 원문 구역에 대체안 전문"
  assert_file_grep "$p" '^  그대로 두면: plan 이 그 자리를 스스로 지어낸다$' "전문 파일: 결정이 아닌 지적(고칠 곳)의 원문도 있다"
}
case_gate_file_originals_preserved() {         # 같은 준비 → gate-file → 한 결정을 adopt → gate-file
  local p a b; p="$(gfile "$d" | jgets 'd["path"]')"
  a="$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p")"
  py docreview_state.py decide --state-dir "$d" --id "$fid" --choice adopt --quote="고친다" >/dev/null
  gfile "$d" >/dev/null; b="$(sed -n '/^## 이 라운드의 지적 원문$/,$p' "$p")"
  assert_eq "$b" "$a" "전문 파일: 결정을 반영한 뒤 다시 써도 원문 구역의 글이 같다"
  assert_file_grep "$p" '다음 라운드에서 반영이 확인돼야 닫힌다' "전문 파일 짝: 「지금 게이트 글」 구역은 새 게이트 글로 바뀌었다"
}
case_gate_file_channel_zone_not_duplicated() { # gate-file → 펜스가 하듯 채널 구역을 덧붙임 → gate-file → 다시 덧붙임
  printf '\n## 다른 채널의 경고\n번호 대조 경고 2개\n' | py nofollow_write.py append --out "$p"
  gfile "$d" >/dev/null
  assert_eq "$(grep -c '^## 다른 채널의 경고$' "$p")" "0" "전문 파일: 다시 쓰면 옛 채널 구역이 사라진다(펜스가 다시 덧붙인다)"
  assert_eq "$(grep -c '^## 이 라운드의 지적 원문$' "$p")" "1" "전문 파일: 원문 구역은 하나다"
}
case_gate_file_advice_included() {             # cases_advice.sh 의 case_AC1_brief_overdesign_only 와 같은 준비(참고 항목이 생기는 프로필) — adv_id 는 그 원장의 advice 항목 id
  assert_file_grep "$p" "$adv_id" "전문 파일: 참고로 간 항목도 원문 구역에 있다"
}
case_gate_file_symlink_refused() {
  ln -s "$d/elsewhere.md" "$d/gate-r1.md"
  local out rc; out="$(gfile "$d" 2>&1)"; rc=$?
  assert_eq "$rc" "1" "전문 파일: 마지막 성분이 링크면 쓰지 않는다(rc 1)"
  assert_contains "$out" "gate_file_write_failed" "전문 파일: 사유를 낸다"
  [ ! -e "$d/elsewhere.md" ] && ok "전문 파일: 링크가 가리키는 곳에 쓰지 않았다" || no "전문 파일: 링크를 따라가 썼다"
}
case_gate_file_ledger_untouched() {
  local before; before="$(cksum < "$d/docreview-state.md")"; gfile "$d" >/dev/null
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "전문 파일: 원장은 바뀌지 않는다"
}
case_gate_file_is_write_command() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
import argparse, docreview_state as S
sub = next(a for a in S.build_parser()._actions if isinstance(a, argparse._SubParsersAction))
print("gate-file" in sub.choices, "ask-material" in sub.choices)')"
  assert_eq "$got" "True True" "하위 명령: gate-file 과 ask-material 이 있다"
  assert_not_contains "$(grep -n '^AC8_READ_ONLY=' "$REPO_ROOT/plugins/spec-distill/tests/test_ledger_wiring.sh")" "gate-file" "하위 명령: gate-file 은 읽기 전용 목록에 없다"
}
case_ask_display_path() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_ask import display_path as p
print(p("/w/repo/.claude/x.md", "/w/repo", "/h")); print(p("/h/a/x.md", "/w/repo", "/h")); print(p("/o/x.md", "/w/repo", "/h"))')"
  assert_eq "$got" ".claude/x.md
~/a/x.md
/o/x.md" "보이는 경로: 작업 폴더 아래면 상대, 홈 아래면 ~, 아니면 그대로"
}
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_docreview_ask.sh`
Expected: `invalid choice: 'gate-file'` 로 새 케이스들이 ✗

- [ ] **Step 3: 구현한다**

`docreview_ask.py` 에 구역 상수와 `originals_block` · `keep_originals` · `gate_file_text` · `display_path`. `docreview_state.py` 에 `cmd_gate_file` 과 `x = sd(P("gate-file")); x.set_defaults(fn=cmd_gate_file)`. `nofollow_write` 는 `_adv` 와 같은 모양으로 import 하고 없으면 `fail("writer_module_missing")`. 쓰기 실패(`OSError` · `UnicodeError`)는 `gate_file_write_failed` 로 잡는다. 머리 docstring 의 서브커맨드 줄에 `gate-file` 을 더한다.

세 skill 의 「**원장 쓰기 전 확인.**」 문단에서 `docreview_state.py` 의 쓰기 명령 열거에 `` `gate-file` `` 을 더한다(예: `… · `declare-related` · `log-decision` · `gate-file`, `docreview_route.py` 의 …`). `plugins/spec-distill/tests/test_ledger_wiring.sh` 가 그 열거를 엔진의 쓰기 하위 명령과 견준다 — 더하지 않으면 그 단언이 RED 다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_docreview_ask.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_nofollow_write.sh && bash plugins/spec-distill/tests/test_ledger_wiring.sh`
Expected: 넷 모두 `✗` 없음

- [ ] **Step 5: 커밋**

```bash
git add shared/docreview/scripts shared/tests/fixtures/docreview/cases_ask.sh shared/tests/test_docreview_ask.sh plugins/spec-distill/skills/{spec-review,reviewing-brief,request-framing}/SKILL.md
git commit -m "feat(docreview): 라운드마다 게이트 전문 파일을 쓰는 명령"
```

---

### Task 7: 절차서 8단계와 진입 skill 셋의 질문 재료 펜스

**AC:** AC7 · AC3

**Files:**
- Modify: `shared/docreview/references/reviewing-document.md:27-42` · `:86`
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(8단계 재진술 문단 · 새 펜스)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(같은 둘)
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(같은 둘 + 「3. **`fix` 는 사용자가 고른 대로만 닫는다.**」 문단)
- Modify: `plugins/spec-distill/tests/test_plain_gate_templates.sh:100-101` 과 그 두 값을 쓰는 단언
- Create: `plugins/spec-distill/tests/test_ask_material_wiring.sh`(100755)

**Interfaces:**
- Consumes: `docreview_state.py gate-file --state-dir D`(Task 6) · `ask-material --state-dir D --gate-file-result <JSON> [--fix-rows] [--ask-rows]`(Task 5).
- Produces:
  - 세 skill 의 펜스 `<!-- ask-material:begin -->` … `<!-- ask-material:end -->`.
  - 펜스가 읽는 셸 변수 `channel_lines`(그 skill 의 다른 채널 경고 줄들 — 여러 줄, 없으면 빈 값). 무엇을 넣는지는 Task 8 이 skill 마다 적는다.
  - 절차서의 새 문장들(아래). Task 14 의 양의 락이 이 글자를 잠근다.

절차서 8단계의 새 문면 — 옛 두 문장(「질문 본문에는 그 질문의 결정 하나와, 경고가 있으면 … 한 줄만 둔다.」 · 「「미검증」이거나 리뷰를 마치지 못한 라운드면 … 붙인다.」)을 지우고 그 자리에 넣는다. 앞의 「렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다.」는 그대로다.

```
질문은 질문 창만 보고 고를 수 있게 싣는다 — 질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다. 질문 본문은 그 묶음의 「본문」 · 「상태」 · 「덧줄」(있을 때) · 「전문」 줄을 이 순서로, 엔진이 낸 글자 그대로다 — 다시 쓰지 않는다. 진입 skill 에 다른 경고 채널이 있고 거기 경고가 있으면 그 채널의 짧은 줄을 「상태」 줄 뒤에 「 · 」로 잇는다 — 글자와 개수를 바꾸지 않고 개수를 더하지 않는다.
```

「**`AskUserQuestion` 라벨의 항목별 내용**」 문단 바로 뒤에 세 문단을 더한다(문면 그대로).

```
**선택지 설명** — 「고친다」의 설명은 고치면 무엇이 바뀌는지(묶음의 「고치면」 칸), 「그대로 둔다」의 설명은 그대로 두면 어떻게 되는지(「그대로 두면」 칸)다. 그 밖의 선택지는 묶음의 「고정 설명」을 그대로 쓴다 — 권하는 쪽이 없으면 `|` 앞의 평문, 있으면 `|` 뒤의 얻음 · 내줌 꼴. 권하는 쪽이 있으면 모든 설명이 얻음 · 내줌 꼴이다: 「고친다」는 얻음이 「고치면」 칸이고, 내줌에는 그 수정이 문서에서 바꾸는 범위와 그 때문에 늘어나는 일만 쓴다 — 지적이 옳은지 그른지를 다시 따지지 않는다. 「그대로 둔다」는 얻음이 묶음의 「고정 얻음」이고 내줌이 「그대로 두면」 칸이다. 길이는 완성된 설명으로 잰다 — 표지와 두 구절을 합쳐 묶음의 길이 표시가 쓰는 기준(기본 110자) 안이어야 한다. 칸의 표시가 「그대로」이고 완성된 설명도 기준 안이면 리뷰어 글을 그대로 싣고, 넘으면 줄인다. 줄이기 전 글은 「전문」 파일에 있다. 적용 여부를 묻는 수정 행(「적용 / 적용하지 않음」)도 같다 — 「적용」이 「고친다」 자리, 「적용하지 않음」이 「그대로 둔다」 자리다.

**줄일 때의 규칙 넷** — 「스크립트·subagent 가 낸 원문은 고치지 않는다」의 예외는 이 자리의 두 칸(「고치면」 · 「그대로 두면」)뿐이다. ① 리뷰어가 고치는 길을 둘 이상 냈으면(「또는」 · 「아니면」 · (가)/(나)) 길마다 「고친다」 선택지를 세운다 — 선택지가 넷을 넘으면 넘는 길을 본문에 「리뷰어가 낸 다른 길: …」 한 구절로 적는다. ② 모델이 스스로 낸 길을 선택지로 세우면 설명 첫머리에 「리뷰어가 낸 길이 아니다」를 적고, 리뷰어의 길을 빼고 그 자리에 넣지 않는다. ③ 원문이 있는 칸에는 원문에 없는 수량 · 장치 · 귀결을 더하지 않는다. ④ 「그대로 둔다」 설명에는 리뷰어가 그 길에 단 조건(「그대로 두려면 …를 적는다」)을 남긴다.

**기타 칸의 「전문」** — 사용자가 기타 칸에 「전문」(같은 뜻의 말 포함)을 쓰면 「전문」 줄이 가리키는 파일의 글을 그대로 보이고 같은 질문을 다시 띄운다. 다시 띄운 질문에도 「전문」 줄이 있다. 전문 파일을 쓰지 못한 라운드에는 `gate --render` 출력을 그대로 보인다.
```

`:86` 의 끝 문장 「질문 앞 글에 그 줄을 그대로 옮긴다.」를 「그 줄은 질문 재료의 「덧줄」로 나온다 — 질문 본문에 그대로 싣는다.」로 바꾼다.

세 skill 의 8단계 재진술 문단에서 같은 옛 두 문장을 지우고 아래 한 문장을 넣는다(셋이 같은 글자).

```
질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고, 선택지 설명 · 줄일 때의 규칙 넷 · 기타 칸의 「전문」은 절차서 8단계대로 한다 — 질문을 띄우기 직전마다 아래 질문 재료 펜스를 돈다.
```

`request-framing` 의 「3. **`fix` 는 사용자가 고른 대로만 닫는다.**」 문단의 「질문은 「적용 / 적용하지 않음」 둘이다.」 뒤에 한 문장을 더한다: 「그 질문도 질문 재료의 묶음을 쓴다 — 본문과 두 선택지의 설명은 절차서 8단계의 선택지 설명 규칙대로다.」

펜스(세 skill 에 같은 꼴 — 8단계 재진술 문단 바로 뒤). 앞 다섯 줄(플러그인 루트 · 세션 id · 상태 루트 · 상태 폴더 · 폴더 검사)은 **그 skill 의 `ledger-release` 펜스의 앞 다섯 줄과 글자가 같게** 쓴다(`reviewing-brief` 는 변수 이름이 `PR` · `PAYLOAD` 다). 여섯째 줄은 **그 skill 의 `ledger-guard` 펜스의 한 줄과 글자가 같게** 쓴다. 그 뒤:

```bash
gf="$(python3 "$SD/scripts/docreview_state.py" gate-file --state-dir "$STATE_DIR")" || true
gf_path="$(printf '%s' "$gf" | python3 -I -X utf8 -c 'import json, sys
try:
    d = json.load(sys.stdin)
    print(d["path"] if d.get("ok") else "")
except Exception:
    print("")')"
if [ -n "$gf_path" ] && [ -n "${channel_lines:-}" ]; then
  printf '\n## 다른 채널의 경고\n%s\n' "$channel_lines" | python3 "$SD/scripts/nofollow_write.py" append --out "$gf_path" \
    || echo "[spec-distill] 다른 채널의 경고 줄을 전문 파일에 덧붙이지 못했다 — 질문에 싣는 경고 줄은 그대로다."
fi
python3 "$SD/scripts/docreview_state.py" ask-material --state-dir "$STATE_DIR" --gate-file-result "$gf"
```

`request-framing` 의 펜스는 마지막 줄 끝에 ` --fix-rows --ask-rows` 를 붙인다. 펜스 위 문단(세 skill 같은 글자, 경로 변수 이름만 그 skill 것):

```
질문을 띄우기 직전마다 — 첫 호출 앞과, 답을 반영한 뒤 다음 호출 앞에 — 아래 펜스를 돈다. 펜스 앞에 문서 경로의 대입 줄과 `channel_lines` 대입을 붙여 같은 Bash 호출로 돌린다. `channel_lines` 에는 이 skill 의 다른 채널이 낸 경고 줄 전체를 글자 그대로 넣고, 없으면 빈 값으로 둔다. 펜스는 그 라운드의 게이트 전문 파일을 다시 쓰고(이 라운드의 지적 원문 구역은 그대로 둔다) 질문마다 한 묶음을 낸다.
```

`channel_lines` 대입은 그 skill 의 `extra-approval` 펜스와 같은 따옴표 heredoc 꼴이다(`IFS= read -r -d '' channel_lines <<'DEVBREW_CHANNEL_EOF' || true` … `channel_lines="${channel_lines%$'\n'}"`).

- [ ] **Step 1: 실패하는 시험을 쓴다**

`plugins/spec-distill/tests/test_ask_material_wiring.sh` — guards 줄은 세 SKILL.md 와 절차서 정본. 정적 단언(파일마다):

```bash
for f in "$SR" "$RB" "$RF"; do
  body="$(awk '/<!-- ask-material:begin -->/{f=1;next} /<!-- ask-material:end -->/{f=0} f' "$f" | sed -e '1d' -e '$d')"
  [ -n "$body" ] && ok "$(basename "$(dirname "$f")"): 질문 재료 펜스가 있다" || no "$(basename "$(dirname "$f")"): 질문 재료 펜스가 없다"
  printf '%s\n' "$body" | bash -n 2>/dev/null && ok "펜스가 bash 문법에 맞다" || no "펜스가 bash 문법에 맞지 않다"
  g="$(printf '%s\n' "$body" | grep -n 'ledger_marker.py" check --dir "$STATE_DIR"' | head -1 | cut -d: -f1)"
  w="$(printf '%s\n' "$body" | grep -n 'docreview_state.py" gate-file --state-dir "$STATE_DIR"' | head -1 | cut -d: -f1)"
  [ -n "$g" ] && [ -n "$w" ] && [ "$g" -lt "$w" ] && ok "표지 확인이 전문 파일 쓰기보다 앞 줄이다" || no "표지 확인이 전문 파일 쓰기 앞에 없다"
  assert_contains "$body" 'ask-material --state-dir "$STATE_DIR" --gate-file-result "$gf"' "질문 재료가 쓰기 결과를 받는다"
  assert_contains "$body" 'nofollow_write.py" append --out "$gf_path"' "채널 줄은 링크를 따라가지 않는 writer 로 덧붙인다"
  assert_eq "$(grep -cF '질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고' "$f")" "1" "8단계 재진술이 새 문장이다"
done
assert_contains "$(awk '/<!-- ask-material:begin -->/{f=1} /<!-- ask-material:end -->/{f=0} f' "$RF")" '--fix-rows --ask-rows' "request-framing 은 수정 행과 질문 행의 묶음도 받는다"
for lit in '질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다' '**선택지 설명** — 「고친다」의 설명은 고치면 무엇이 바뀌는지' \
           '**줄일 때의 규칙 넷** — 「스크립트·subagent 가 낸 원문은 고치지 않는다」의 예외는 이 자리의 두 칸' '리뷰어가 낸 길이 아니다' \
           '**기타 칸의 「전문」** — 사용자가 기타 칸에 「전문」' '그 줄은 질문 재료의 「덧줄」로 나온다 — 질문 본문에 그대로 싣는다.'; do
  assert_eq "$(grep -cF -- "$lit" "$PROC")" "1" "절차서: ${lit:0:24}…"
done
[ -L "$REPO_ROOT/plugins/spec-distill/references/reviewing-document.md" ] && ok "절차서의 플러그인 쪽은 정본을 가리키는 링크다" || no "절차서의 플러그인 쪽이 링크가 아니다"
```

행동 단언(같은 파일): `plugins/spec-distill/tests/test_ledger_wiring.sh` 의 결정 줄 펜스 시험(`dl_run` — 임시 레포 · 세션 id · 원장 열기)을 본떠, 원장이 열린 설계문서로 `spec-review` 의 질문 재료 펜스를 돌린다.

| 준비 | 단언 |
|---|---|
| 표지 주인 세션 · 결정이 하나 있는 원장 | rc 0 · 출력에 `질문 1/` 과 `전문: ` 줄 · 상태 폴더에 `gate-r1.md` 가 있다 |
| 같은 준비 · `channel_lines` 에 `번호 대조 경고 2개` | `gate-r1.md` 에 `## 다른 채널의 경고` 가 한 번 · 펜스를 두 번 돌려도 한 번 |
| 남의 표지 | rc 3 · `gate-r1.md` 가 생기지 않는다 · 출력에 `질문 1/` 이 없다 |
| 상태 폴더의 `gate-r1.md` 자리가 링크 | rc 0 · 출력의 전문 줄이 `전문: 전문 파일을 쓰지 못했다 — gate_file_write_failed` 로 시작한다 |

`test_plain_gate_templates.sh` 의 두 값을 바꾼다:

```bash
S1='질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고, 선택지 설명 · 줄일 때의 규칙 넷 · 기타 칸의 「전문」은 절차서 8단계대로 한다 — 질문을 띄우기 직전마다 아래 질문 재료 펜스를 돈다.'
STEP8='질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다.'
```

그 두 값을 쓰는 단언은 「절차서에 `STEP8` 이 한 번」 · 「진입 skill 셋에 `S1` 이 한 번씩」으로 맞춘다(승인 게이트 자리의 단언은 Task 8 이 고친다 — 이 Task 에서는 그 단언들이 RED 여도 둔다).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_ask_material_wiring.sh`
Expected: 「질문 재료 펜스가 없다」 셋과 절차서 단언들이 ✗

- [ ] **Step 3: 절차서와 세 skill 을 고친다**

위 문면 그대로. 펜스를 넣은 뒤 `bash -n` 으로 본문을 확인한다 — 계획의 펜스 글은 그 skill 의 앞 여섯 줄과 이어 붙였을 때의 문법으로 검증한다(따옴표 안의 python 을 포함해).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_ask_material_wiring.sh && bash plugins/spec-distill/tests/test_ledger_wiring.sh && bash shared/tests/test_docreview_round_gate_split.sh && bash shared/tests/test_docreview_procedure_paths.sh && bash shared/tests/test_inline_python_isolated.sh && bash shared/tests/test_plugin_root_no_cwd_fallback.sh`
Expected: 모두 `✗` 없음. 옛 문장을 글자째 잠근 단언이 이 파일들에 있으면 새 문장으로 바꾼다 — 단언을 지우지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/{spec-review,reviewing-brief,request-framing}/SKILL.md plugins/spec-distill/tests shared/tests
git commit -m "feat(spec-distill): 리뷰 결정 질문이 엔진의 질문 재료를 싣는다"
```

---

### Task 8: 승인 게이트의 본문 규칙 · 경고 채널의 짧은 줄 · 다음 단계 선택지 넷

**AC:** AC8 · AC9 · AC3

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md`(Step B 표 · 본문 규칙 문단)
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(B-2 — 경고 문단 · `question:` 줄 · 선택지 넷)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(번호 대조 경고 문단 · 승인 게이트 2단계 표 · `## degrade 채널` 끝 문단)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(`## degrade 채널`)
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(`## degrade 채널` · `## 확정 — proceed 게이트` 의 본문 규칙과 표)
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py`(`short_line`) · `spec_review_bundle.py:79,188`
- Modify: `plugins/spec-distill/scripts/brief_review_state.py`(하위 명령 `short`)
- Create: `plugins/spec-distill/tests/test_bundle_short_line.sh` · `test_brief_review_short.sh`(100755)
- Modify: `plugins/spec-distill/tests/test_plain_gate_templates.sh:30,138-151` · `test_brief_review_entry.sh:272-274` · `shared/tests/fixtures/ask-sites.tsv`(다음 단계 질문 네 행의 「설명 수」)

**Interfaces:**
- Consumes: Task 7 의 `channel_lines` · 엔진의 상태 줄.
- Produces:
  - `check_bundle_coverage.short_line(result: dict) -> str` — 경고가 없으면 `""`. 검사 불가면 `"번호 대조 경고 1개: 검사 불가"`. 아니면 `"번호 대조 경고 N개: "` 뒤에 0 이 아닌 종류만 `빠진 번호 a` · `얕은 답 b` · `받드는 에픽 없는 발화 c` · `셀 수 없음 d` 를 `" · "` 로. N 은 `warning_count(result)` 다.
  - `spec_review_bundle.py entry` 의 출력 — `번호 대조 경고 <N>개` 줄 **앞**에, N 이 0 이 아닐 때만 `질문 줄: <short_line>` 한 줄. 기존 두 줄(`번호 대조 경고 <N>개` · `bundle-entry: PROCEED …`)은 글자 그대로다.
  - `brief_review_state.py short <state> [--ledger-key K] [--fallback-file F]` — 기록이 없고 F 도 비었으면 빈 출력 rc 0. 있으면 `brief 리뷰 경고 N개: <이름> · …` 한 줄. 이름은 `<component 쉬운 말> <status 쉬운 말>`(아래 표), 같은 이름은 `×k`. F 의 비어 있지 않은 줄 수 m 은 `기록 못 한 경고 m` 으로 끝에 붙고 N 에 든다. 원장을 읽지 못하면 rc 1 과 지금 `get` 의 실패 JSON.

`brief_review_state.py short` 의 쉬운 말: component — `critic` 탐지 리뷰어 · `direction_reviewer` 방향 리뷰어 · `readback` 냉독 · `codex` codex · `verbatim_coverage` 원문 대조 · `pipeline` 리뷰 전체. status — `skipped` 건너뜀 · `degraded` 일부만 · `unavailable` 못 돎.

경고 채널 표(설계 §4-2 — 각 skill 의 어휘 절이 밝힌 채널 전부):

| skill | 채널 | 내는 것 | 질문용 짧은 줄 |
|---|---|---|---|
| spec-review · reviewing-brief · request-framing · 인터뷰 끝 게이트 | 엔진의 경고(`fin.json` `advisory[]` · `blocks` · 게이트 글 첫 줄) | `docreview_state.py` | 엔진이 낸다 — 질문 재료의 「상태」 줄(Task 4 · 5) |
| spec-review | 번호 대조 | `spec_review_bundle.py entry`(`check_bundle_coverage.py`) | 스크립트가 낸다 — `질문 줄:` (이 Task) |
| reviewing-brief · 인터뷰 끝 게이트 | brief 경고 원장(`brief_review_degradations`) | `brief_review_state.py` | 스크립트가 낸다 — `short` (이 Task) |
| reviewing-brief · 인터뷰 끝 게이트 | 원장 기록 실패 때의 두 번째 채널 파일 | 펜스의 writer | 스크립트가 낸다 — `short --fallback-file` (이 Task) |
| reviewing-brief · 인터뷰 끝 게이트 | 웹 한 줄(`웹: Claude … · codex …`) | 선택 펜스 | 싣지 않는다 — 경고가 아니라 매번 앞 글에 싣는 줄이다 |
| 인터뷰 끝 게이트 | 구조 검사의 참고 줄(`check_brief.py gate` 의 `advisories`) | `check_brief.py` | 모델이 쓴다 — 「구조 검사 참고 N개」 |
| 인터뷰 끝 게이트(B-2 · B-1) | 건너뛴 것(`check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 으로 시작하는 줄 — 기준 브랜치 269ead33 을 합치며 들어온 채널, Task 14M-2) | `check_brief.py` | 모델이 쓴다 — 「건너뛴 것 N개」. 그 줄들은 위 「구조 검사 참고 N개」 에서 뺀다 |
| 인터뷰 끝 게이트 | superpowers 판 확인 한 줄 | `check_deps.py` | 모델이 쓴다 — 「같다」가 아닐 때만 「superpowers 판 다름」. 「알 수 없음」 줄은 경고 수에 넣지 않고 지금처럼 따로 싣는다 |
| request-framing | 이 skill 이 게이트 앞 글에 적는 줄(상태 파일이 없어 원장이 없다) | skill 글의 표 | 모델이 쓴다 — 「요청 정리 경고 N개: <component> <status> · …」 |
| quality-pipeline | 합성 출력의 판정 degrade 줄 | `synthesize_findings.py` | Task 12 의 Step 1 이 정한다(「이 계획이 정한 것」 10) |

「모델이 쓴다」 넷은 리뷰받은 쪽이 경고를 자기 말로 쓰는 자리다 — 그 위험은 남는다(CHANGELOG 한계에 적는다, Task 15).

본문 규칙의 새 문면 — `proceed-gate.md` 의 「질문 본문에는 결정 하나와 「경고 N개 — … 붙인다.」(두 문장)를 아래로 바꾼다.

```
질문 본문에는 결정 하나, 경고 줄 하나, 「전문: <경로>」 한 줄을 둔다. 경고 줄은 경고가 있는 채널마다의 짧은 줄을 「 · 」로 이은 것이다 — 스크립트가 낸 줄은 글자와 개수를 바꾸지 않고, 채널의 개수를 더해 합계를 내지 않는다(예: 「리뷰 경고 1개: codex 리뷰 없음 · 번호 대조 경고 2개: 빠진 번호 2」). 엔진에는 경고가 없고 다른 채널에 있으면 그 채널의 줄만 싣는다. 어느 채널에도 경고가 없을 때만 「경고 없음」(남은 항목이 있다) 또는 「이상 없음」(없다)을 쓴다 — 그 문구는 채널을 실제로 읽었다는 주장이라 읽지 않은 채 쓰지 않는다. 「미검증」이거나 리뷰를 마치지 못한 라운드면 그 공시의 첫 문장이 경고 줄의 맨 앞이고 두 문구는 쓰지 않는다. 읽지 못한 채널의 「알 수 없음 — <사유>」는 따로 한 줄로 싣는다. 「전문」 줄은 질문 재료 펜스가 낸 줄 그대로다 — 리뷰를 거치지 않은 게이트에는 그 줄이 없다. 선택지 넷의 설명은 아래 표의 얻음 · 내줌 꼴이다.
```

다음 단계 질문을 적는 다섯 자리(`proceed-gate.md` · `finishing.md` B-2 · `spec-review` 승인 게이트 2단계 · `reviewing-brief` Step B 의 재진술 · `request-framing` 확정 게이트)의 같은 뜻 문장을 이 규칙에 맞춘다:

- `finishing.md` — 「모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — … 그 개수 한 줄(… )만 둡니다.」(세 문장)를 「모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다. 질문 본문에는 결정 하나와 경고 줄 · 「전문」 줄을 정본(`proceed-gate.md`)의 본문 규칙대로 싣습니다.」로. `question:` 줄의 `경고 <N>개 — … | 경고 없음 | 이상 없음.` 조각을 `<경고 줄 — 채널마다의 짧은 줄을 「 · 」로 이은 것 | 경고 없음 | 이상 없음>. 전문: <경로>.` 로. 「질문의 「경고 N개」에서 엔진 몫은 렌더 첫 줄의 N 이고, 다른 채널의 경고 줄은 그 위에 더합니다.」와 「… 전체 결론은 질문의 상태 줄이 정한다(엔진 K + 그 밖의 M).」를 「질문의 경고 줄은 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것이다 — 개수를 더하지 않는다.」로.
- `spec-review` — 번호 대조 문단의 「`번호 대조 경고 <N>개` 의 N 을 질문의 「경고 N개 …」의 N 에 더한다.」를 「진입 펜스가 낸 `질문 줄:` 뒤의 글을 질문의 경고 줄에 그대로 잇고, 번호 대조 줄 전체를 `channel_lines` 에 넣는다.」로. `## degrade 채널` 의 「… `--bundle` 로 불렀으면 … N 을 여기에 더한다(…).」도 같은 뜻으로. 끝 문단의 「승인 게이트 질문에는 「경고 N개 — …」(또는 …) 한 줄만 둔다.」와 그 뒤의 「미검증 … 붙인다.」를 「승인 게이트 질문의 본문은 정본(`proceed-gate.md`)의 본문 규칙대로 싣는다.」로.
- `reviewing-brief` · `request-framing` 의 `## degrade 채널` — 「질문의 「경고 N개」에서 엔진 몫은 … 그 위에 더한다.」 · 「… 전체 결론은 질문의 상태 줄이 정한다(엔진 K + 그 밖의 M).」 · 「(질문 본문에는 「경고 N개 — …」 한 줄)」 · 「미검증 … 붙인다.」를 위와 같은 두 문장(이은 줄 · 정본의 본문 규칙)으로. `reviewing-brief` 에는 「`brief_review_state.py short "$STATE" --fallback-file "$DEGRADE_FALLBACK_FILE"` 이 낸 줄을 질문의 경고 줄에 잇고, 그 원장의 줄 전체를 `channel_lines` 에 넣는다.」를 더한다.

선택지 넷의 설명 — 짝 파일 1부의 `proceed-gate.md:28` · `finishing.md:471`, 2부의 `spec-review/SKILL.md:688` · `request-framing/SKILL.md:1125` 표의 「새 설명」 그대로. `proceed-gate.md` 의 Step B 표에는 「설명」 칸을 더해 네 줄을 적는다. `ask-sites.tsv` 의 그 네 행에 「설명 수」 `4` 를 채운다(범위 안에 둘째 질문의 설명이 함께 있으면 그 수를 더한 값 — 검사가 세는 수에 맞춘다).

- [ ] **Step 1: 실패하는 시험을 쓴다**

`test_bundle_short_line.sh`:

```bash
sl() { PYTHONPATH="$SD/scripts" python3 -c 'import sys, json, check_bundle_coverage as c; print(c.short_line(json.loads(sys.argv[1])))' "$1"; }
assert_eq "$(sl '{"status":0,"missing":[],"shallow":[],"unserved":[],"unknown":[]}')" "" "짧은 줄: 경고가 없으면 빈 글"
assert_eq "$(sl '{"status":1,"missing":["D3","K9"],"shallow":[{"id":"S2","reason":"x"}],"unserved":[],"unknown":[]}')" \
  "번호 대조 경고 3개: 빠진 번호 2 · 얕은 답 1" "짧은 줄: 0 이 아닌 종류만, 개수는 warning_count 와 같다"
assert_eq "$(sl '{"status":3,"reason":"x"}')" "번호 대조 경고 1개: 검사 불가" "짧은 줄: 검사 불가는 1개"
# entry 출력 — 경고가 있는 묶음 fixture(같은 폴더의 기존 번호 대조 시험이 쓰는 것)로
assert_grep "$out" '^질문 줄: 번호 대조 경고 [0-9]+개: ' "entry: 경고가 있으면 질문 줄을 낸다"
assert_eq "$(printf '%s\n' "$out" | grep -c '^번호 대조 경고 [0-9]*개$')" "1" "entry: 기존 개수 줄은 그대로다"
assert_not_contains "$out_clean" "질문 줄:" "entry: 경고가 없으면 질문 줄이 없다"
```

`test_brief_review_short.sh`: 상태 파일에 `degrade-append` 로 `codex/suppression/skipped` 둘과 `readback/readback/unavailable` 하나를 적고 두 번째 채널 파일에 두 줄을 넣은 뒤

```bash
assert_eq "$(python3 "$SD/scripts/brief_review_state.py" short "$st" --fallback-file "$fb")" \
  "brief 리뷰 경고 5개: codex 건너뜀 ×2 · 냉독 못 돎 · 기록 못 한 경고 2" "short: 이름 · ×k · 두 번째 채널의 줄 수"
assert_eq "$(python3 "$SD/scripts/brief_review_state.py" short "$empty")" "" "short: 기록이 없으면 빈 출력"
python3 "$SD/scripts/brief_review_state.py" short "$missing" >/dev/null 2>&1; assert_eq "$?" "1" "short: 원장을 못 읽으면 rc 1"
```

`test_plain_gate_templates.sh:138-151` 의 다섯 단언(자리마다 옛 본문 문장이 한 번)을 새 문장으로 바꾼다: 정본은 `'질문 본문에는 결정 하나, 경고 줄 하나, 「전문: <경로>」 한 줄을 둔다.'` 가 한 번, 나머지 넷은 `'정본(`proceed-gate.md`)의 본문 규칙대로'` 가 한 번 이상. `:150-151` 의 「옵션 description 에 싣지 않는다」 단언은 그 문장이 **없다**는 단언으로 뒤집고, 짝으로 `'질문 본문에는 결정 하나와 경고 줄 · 「전문」 줄을 정본'` 이 있다는 단언을 둔다. `:30` 과 `test_brief_review_entry.sh:272-274` 는 `question:` 줄에 `경고 줄 — 채널마다의 짧은 줄` 이 있다는 단언으로 바꾼다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_bundle_short_line.sh; bash plugins/spec-distill/tests/test_brief_review_short.sh; bash plugins/spec-distill/tests/test_plain_gate_templates.sh; bash shared/tests/test_ask_recommendation.sh`
Expected: 새 두 파일은 `AttributeError: … short_line` · `invalid choice: 'short'` 로 ✗, 뒤 둘은 새 문장 · 「설명 수」 단언이 ✗

- [ ] **Step 3: 스크립트 둘과 문면을 고친다**

- [ ] **Step 4: 돌려서 통과를 본다**

Run: Step 2 의 넷과 `bash plugins/spec-distill/tests/test_brief_review_entry.sh && bash plugins/spec-distill/tests/test_end_gates.sh && bash plugins/spec-distill/tests/test_seed_gate_wiring.sh && bash plugins/spec-distill/tests/test_framing_review_contract.sh && bash plugins/spec-distill/tests/test_request_framing_open.sh`
Expected: 모두 `✗` 없음. 옛 문장을 잠근 단언이 더 나오면 새 문장으로 바꾼다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill shared/tests/fixtures/ask-sites.tsv
git commit -m "feat(spec-distill): 다음 단계 질문이 경고의 짧은 줄과 전문 자리를 싣는다"
```

---

### Task 9: 인터뷰 쪽 추천 질문 자리

**AC:** AC11 · AC3

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/{finishing.md,saturation.md,state-file.md,steelman.md}`
- Modify: `plugins/spec-distill/references/{trivia-escape.md,redecompose.md,proceed-gate.md}`
- Modify: `shared/tests/fixtures/ask-sites.tsv`(이 파일들의 `꼬리` · `출처꼬리` 행과 설명이 있는 `지시` 행의 「설명 수」)
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` · `test_end_gates.sh` 등 옛 문장을 잠근 단언

**Interfaces:**
- Consumes: 짝 파일 1부(Task 8 이 이미 고친 다음 단계 질문 넷 — `proceed-gate.md:28` · `finishing.md:471` — 은 뺀다) · Task 3 의 「설명 수」 칸.
- Produces: 없음(문면).

자리(짝 파일 1부의 절 제목 그대로): `finishing.md` 분해 판단 · 분해안 표 고치기 · 재제시 상한 · 접은 참고 목록 · 둘째 질문 · 머지 묻기 / `saturation.md` 조사 호출 상한 / `state-file.md` 이어 감 / `steelman.md` 방향 판단 / `trivia-escape.md` / `proceed-gate.md` 둘째 질문 · 지휘자 아래 승인 질문 / `redecompose.md`.

문면이 따로 바뀌는 곳(선택지 설명 말고):

- `finishing.md` 분해 판단의 `question:` → `"신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 이 일을 어떻게 진행할까?"`. 권고의 이유는 권하는 선택지의 얻음에 담는다는 한 문장을 그 펜스 아래에 더한다: 「권하는 쪽의 이유는 그 선택지의 얻음에 담는다 — 권고 줄에 대가를 따로 붙이지 않는다.」
- `redecompose.md` 의 `question:` → `"다시 나눌 표의 신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 어떻게 할까?"`. 같은 한 문장을 더한다.
- `saturation.md` 의 「연장이 첫 자리이고 라벨 끝에 「(권장)」을 단다 — 이유는 … 한 줄로 쓴다(…)」에서 「 — 이유는 … 한 줄로 쓴다」 조각을 빼고 「 — 권하는 이유는 그 선택지의 얻음에 담는다」로.
- `finishing.md` · `proceed-gate.md` 의 둘째 질문 문단에서 제안 이유를 게이트 앞 글에 쓰라는 조각을 빼고 「제안 선택지의 설명은 「얻음: <제안 이유> · 내줌: <그 제안이 틀렸을 때 원인이 될 것 하나>」로 쓴다.」를 넣는다. 기본 다음 단계 쪽 설명은 짝 파일의 고정 문구다.

- [ ] **Step 1: 목록에 「설명 수」를 채워 실패를 만든다**

이 Task 의 행마다 짝 파일의 「선택지 수」를 여섯째 칸에 적는다(손대지 않는 자리와 `비움` · `언급` · `떼기` 행은 비운다).

Run: `bash shared/tests/test_ask_recommendation.sh`
Expected: 채운 행마다 `no ⑤` (「얻음:」이 없다 · 설명 수가 다르다)

- [ ] **Step 2: 자리를 고친다**

짝 파일의 「새 설명」을 「이 표를 쓰는 법」대로 적는다. 선택지가 실제로 하는 일과 다르면 실제 동작에 맞춰 고치고 보고에 적는다. 범위가 선택지 줄을 덮지 않아 ⑤ 가 남으면 그 행의 `끝` 을 넓힌다.

- [ ] **Step 3: 옛 문장을 잠근 단언을 새 문장으로 바꾼다**

Run: `bash tools/suite/run-all.sh 2>&1 | grep -E "^FAILED plugins/spec-distill/tests/(test_review_handoff_order|test_end_gates|test_conducting_interview_stage|test_open_research)" ; true`
나온 실패가 이 Task 가 바꾼 문장을 잠근 것이면 새 글자로 바꾼다(단언을 지우지 않는다). 다른 이유의 실패는 건드리지 않고 보고에 적는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_ask_recommendation.sh && bash shared/tests/test_skill_reference_pointers.sh && bash plugins/spec-distill/tests/test_review_handoff_order.sh && bash plugins/spec-distill/tests/test_end_gates.sh`
Expected: 모두 `✗` 없음

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill shared/tests/fixtures/ask-sites.tsv
git commit -m "feat(spec-distill): 인터뷰 쪽 추천 질문의 설명을 얻음 · 내줌으로"
```

---

### Task 10: 리뷰 · 요청 정리 · 지휘자 쪽 추천 질문 자리와 지휘자 의견 줄

**AC:** AC11 · AC14 · AC3

**Files:**
- Modify: `plugins/spec-distill/skills/{spec-review,reviewing-brief,request-framing,epic-conductor}/SKILL.md`
- Modify: `plugins/spec-distill/references/{conducting.md,conductor-dispatch.md}`
- Modify: `shared/tests/fixtures/ask-sites.tsv`(이 파일들의 행)
- Modify: `plugins/spec-distill/tests/{test_conductor_dispatch_reference.sh,test_conducting_reference.sh,test_epic_conductor_skill.sh,test_review_handoff_order.sh}`

**Interfaces:**
- Consumes: 짝 파일 2부(Task 8 이 고친 `spec-review/SKILL.md:688` · `request-framing/SKILL.md:1125` 는 뺀다).
- Produces: 지휘자 의견 줄의 새 문장(아래).

자리: `spec-review` 표지 질문 · 접힌 참고 목록 · ③ 수정 필요의 후속 질문 · 지휘 세션 승인 질문 / `reviewing-brief` 표지 질문 · 원문 완전성 검사 / `request-framing` 워크트리 · 표지 질문 · audit 제목 겹침 · 다른 다음 단계 / `epic-conductor` 넘겨받기 / `conducting.md` 넘겨받기 · 흐름 승인(두 곳) · 승인 질문(두 곳) · 병렬 질문(두 곳).

문면이 따로 바뀌는 곳:

- `spec-review` 의 「두 갈래 중 이번 지적에 맞는 쪽 라벨에 「(권장)」을 달고 이유는 … 한 줄로 쓴다 — 고르는 것은 사용자다.」 → 「두 갈래 중 이번 지적에 맞는 쪽 라벨에 「(권장)」을 달고 그 이유는 그 선택지의 얻음에 담는다 — 고르는 것은 사용자다.」
- `request-framing` 의 「**다른 다음 단계(둘째 질문).**」 문단 — Task 9 의 둘째 질문과 같은 문장으로.
- 지휘자 의견 줄(AC14):
  - `conductor-dispatch.md` — 「지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다.」 바로 뒤에 「그 줄 끝에 그 의견을 따르면 내주는 것을 한 구절 붙인다.」를 더한다.
  - `conducting.md` — 「… 지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고, 꼬리를 더하는 길은 …」 를 「… 지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고 그 줄 끝에 그 의견을 따르면 내주는 것을 한 구절 붙이며, 꼬리를 더하는 길은 …」 로.
  - `plugins/spec-distill/agents/relay-checker.md` 는 고치지 않는다.

- [ ] **Step 1: 실패하는 시험을 쓴다**

`test_conductor_dispatch_reference.sh` 의 문구 목록에 `'그 줄 끝에 그 의견을 따르면 내주는 것을 한 구절 붙인다.'` 를, `test_conducting_reference.sh:117` 의 목록에 `'한 줄로만 쓰고 그 줄 끝에 그 의견을 따르면 내주는 것을 한 구절 붙이며'` 를 더한다. 옮김 대조 agent 파일이 바뀌지 않았는지는 레포 테스트에 넣지 않고(기준 브랜치 이름을 테스트에 박게 된다) Task 15 의 Step 3 이 본다. `test_epic_conductor_skill.sh` 가 그 agent 파일의 문장을 잠근 단언은 그대로 통과해야 한다.

`test_review_handoff_order.sh:191` 의 `'라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다'` 를 `'라벨에 「(권장)」을 달고 그 이유는 그 선택지의 얻음에 담는다'` 로 바꾼다. `ask-sites.tsv` 의 이 Task 행에 「설명 수」를 채운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_ask_recommendation.sh; bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh; bash plugins/spec-distill/tests/test_conducting_reference.sh; bash plugins/spec-distill/tests/test_review_handoff_order.sh`
Expected: `no ⑤` 줄들과 새 문구 단언이 ✗

- [ ] **Step 3: 자리와 문장을 고친다**

`conducting.md` 는 한 문단에 질문 행이 여럿이다 — 선택지마다 설명을 그 라벨 바로 뒤 괄호나 ` — ` 뒤에 적어, 행의 범위(앵커 ~ `끝`)마다 「얻음:」 수가 「설명 수」와 같게 한다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: Step 2 의 넷과 `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh && bash plugins/spec-distill/tests/test_ledger_wiring.sh && bash shared/tests/test_skill_body_no_positional_tokens.sh`
Expected: 모두 `✗` 없음

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill shared/tests/fixtures/ask-sites.tsv
git commit -m "feat(spec-distill): 리뷰 · 요청 정리 · 지휘자 질문의 설명과 지휘자 의견 줄의 대가"
```

---

### Task 11: 인터뷰 라운드 규약과 풀이 확인 질문

**AC:** AC12 · AC13

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md`(`## 라운드 규약` 의 양식 펜스와 그 아래 목록)
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(`### 확인 질문 — 라운드마다 하나`)
- Modify: `shared/tests/fixtures/ask-sites.tsv`(풀이 확인 질문 행의 종류 · pm-interview 라운드 행의 「설명 수」 `0`)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Produces: 없음(문면).

`pm-interview/SKILL.md` 의 새 문면:

- 양식 펜스의 「다음 결정」 줄 → `OQ<n>: <무엇을 정하는지 한 줄> · 추천: <첫 선택지 | 없음 — <이유>>` (「 · 트레이드오프: <선택지별 한 줄>」 조각을 뺀다).
- 양식 펜스의 `### 질문` 아래 → 두 줄로:

```
### 질문
<본문>
<선택지마다 한 줄 — 「<라벨>」 — 얻음: … · 내줌: …>
```

- 목록의 「question 본문은 무엇을 정하는지·용어·기술 사실을 풀고, 각 선택지의 `description` 은 «고르면 무엇이 달라지는가»를 담는다. 기계 검사는 없다.」 → 「question 본문은 무엇을 정하는지·용어·기술 사실을 푼다. 인터뷰 라운드의 질문은 추천이 있든 없든 모든 선택지 설명을 「얻음: … · 내줌: …」 한 줄로 쓴다 — 같은 대가를 질문 앞 글과 질문에 두 번 싣지 않는다. 상태 파일의 `### 질문` 아래에는 본문과 함께 선택지와 그 설명을 적는다(무엇을 보이고 물었는지가 기록에 남는다). 기계 검사는 없다.」

`request-framing/SKILL.md` 의 풀이 확인 질문:

- 「… 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다. 두 꼴 모두 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다.」에서 둘째 문장을 지우고 그 자리에: 「두 꼴 모두 추천을 달지 않는다 — 풀이는 저자가 쓴 것이라, 권하면 저자가 자기 읽기를 스스로 승인한다.」
- `ask-sites.tsv` 의 그 행(앵커 「질문과 **같은 `AskUserQuestion` 호출**에 확인 질문을 하나 더 싣습니다」)의 종류를 `지시` 에서 `비움` 으로 바꾼다. 범위 안의 예시 선택지에 「(권장)」 꼬리가 없어야 한다(`비움` 의 검사). 같은 범위의 `떼기` 행(「- **한 질문에 풀이가 하나뿐이면** 단일 선택」)은 그대로다.

- [ ] **Step 1: 실패하는 시험을 쓴다**

`test_conducting_interview_stage.sh` 의 라운드 규약 블록 단언 옆에 더한다(변수 `round_block` · `round_flat` 은 그 파일의 것):

```bash
nd_line="$(awk '/^### 다음 결정$/{getline; print; exit}' <<<"$round_block")"
case "$nd_line" in *트레이드오프*) no "AC12: «다음 결정» 줄에 트레이드오프 조각이 남아 있다" ;; *) ok "AC12: «다음 결정» 줄에 트레이드오프 조각이 없다" ;; esac
grep -qF '인터뷰 라운드의 질문은 추천이 있든 없든 모든 선택지 설명을 「얻음: … · 내줌: …」 한 줄로 쓴다' <<<"$round_flat" \
  && ok "AC12: 추천이 없는 라운드에도 얻음 · 내줌 꼴" || no "AC12: 설명 규칙이 없다"
grep -qF '<선택지마다 한 줄 — 「<라벨>」 — 얻음: … · 내줌: …>' <<<"$round_block" \
  && ok "AC12: 상태 파일 기록에 선택지와 설명이 남는다" || no "AC12: 양식에 선택지 줄이 없다"
```

풀이 확인 질문은 같은 파일이나 `test_request_framing_open.sh` 에:

```bash
assert_eq "$(grep -cF '두 꼴 모두 추천을 달지 않는다 — 풀이는 저자가 쓴 것이라' "$RF")" "1" "AC13: 풀이 확인 질문은 추천을 달지 않고 이유를 적는다"
assert_eq "$(grep -cF '두 꼴 모두 권하는 쪽이 있으면 첫 자리로 옮기고' "$RF")" "0" "AC13: 옛 추천 지시가 없다"
assert_eq "$(awk -F'\t' '$3 ~ /확인 질문을 하나 더 싣습니다/ {print $2}' "$REPO_ROOT/shared/tests/fixtures/ask-sites.tsv")" "비움" "AC13: 목록의 종류가 비움이다"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh; bash plugins/spec-distill/tests/test_request_framing_open.sh; bash shared/tests/test_ask_recommendation.sh`
Expected: 새 단언들이 ✗

- [ ] **Step 3: 두 skill 과 목록을 고친다**

- [ ] **Step 4: 돌려서 통과를 본다**

Run: Step 2 의 셋과 `bash plugins/spec-distill/tests/test_open_research.sh`
Expected: 모두 `✗` 없음. 「다음 결정」 줄이 `OQ<n>:` 으로 시작한다는 기존 단언은 그대로 통과한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill shared/tests/fixtures/ask-sites.tsv
git commit -m "feat(spec-distill): 인터뷰 질문은 늘 얻음 · 내줌, 풀이 확인 질문은 추천 없이"
```

---

### Task 12: 코드 리뷰 질문

**AC:** AC10 · AC3

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(`_ask_line` · `render`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(낮춘 지적 게이트 · 범위 모드 갈래 · Fix-loop decision · Max-iter decision · Retry 실패 질문 · `<summary>` 정의)
- Modify: `plugins/quality-gates/references/e2e.md`(5 절 판정 질문)
- Create: `plugins/quality-gates/tests/test_synthesize_ask_line.sh`(100755)
- Modify: `plugins/quality-gates/tests/{test_lowered_gate_wiring.sh,test_plain_qg_templates.sh}` · `tools/plain-language/test_measure_output.py`(SKILL 의 질문 틀을 읽는 시험 — 틀이 바뀌면 맞춘다)
- Modify: `shared/tests/fixtures/ask-sites.tsv`(quality-pipeline · e2e 행)

**Interfaces:**
- Consumes: 짝 파일 3부의 quality-pipeline 넷(범위 모드 · 반복 게이트 · 상한 도달 · Edit 실패).
- Produces:
  - `synthesize_findings._ask_line(findings, blocking, degrade_count) -> str` 과 stdout 의 새 줄 `질문 줄: 막는 지적 <b>개 · 제안 <s>개 — 가장 무거운 것: <file>:<line> — <요약>` — `lowered:` 줄 다음(되올림이 있으면 `restored:` 다음)에 한 줄. 지적이 없으면 `질문 줄: 지적 없음`. 「가장 무거운 것」은 심각도(CRITICAL > IMPORTANT > SUGGESTION)가 가장 높은 것 중 표의 첫 행이고, 요약은 그 행 「내용」 칸의 쉬운 말 부분을 공백을 접어 80자에서 자른 것(넘으면 79자 + `…`)이다.
  - SKILL 의 `<ask-line>` = `$RV/synth.out` 의 `질문 줄: ` 뒤 글자 그대로. 전문 자리 = `$RV/synth.out`.
  - 분류표 파일 `$RV/classification.md`(Step 5 가 표를 출력할 때 같은 글을 Write 도구로 쓴다).

Step 1 에서 정할 것(「이 계획이 정한 것」 10): `synthesize_findings.py` 의 `_degrade_block` 이 내는 「판정 degrade」 줄이 있을 때 질문 줄 끝에 ` · 경고 <n>개: 판정 degrade` 를 붙인다(n = 그 블록의 `- ` 줄 수). 블록이 없으면 붙이지 않는다. 채널 표(Task 8)의 quality-pipeline 행은 「스크립트가 낸다 — 질문 줄의 꼬리」다.

SKILL 의 새 문면:

- **`<summary>` 정의 문단** 끝에 더한다: 「질문에는 `<summary>` 대신 `<ask-line>` 을 싣는다 — `$RV/synth.out` 의 `질문 줄: ` 뒤 글자 그대로다. 차등 기원 결함이고 지적이 없으면 지금처럼 `<unit> · <verdict>` 목록이다.」
- **반복 게이트** `question:` → `"qg 반복 N: <ask-line>\n전문: <$RV/synth.out 의 경로>\n어떻게 할까?"`. 선택지 셋의 `description:` 은 짝 파일의 새 설명(차등 기원 변형 포함).
- **분류 질문** `question:` → `"분류표의 적용/제외를 바꿀까요? 바꿀 항목 번호는 「기타」에 적는다(예: 2, 5).\n<항목마다 한 줄 — #<번호> <지적 요약> · <적용|제외> · <제외 사유(제외일 때)>>\n표: <$RV/classification.md 의 경로>"`. 그 아래 문장: 「줄은 분류표에서 그대로 온다. 한 질문에 여덟 줄까지 싣고, 넘으면 같은 선택지로 질문을 나눈다(한 호출에 질문 넷까지 — 반복 게이트 질문을 포함해 센다 — 넘으면 다음 호출).」 선택지 둘은 그대로다(`비움`).
- **낮춘 지적 게이트** — 펜스를 아래로 바꾼다.

```text
AskUserQuestion({ questions: [<낮춘 지적을 표의 순서로 셋씩 묶어 묶음마다 질문 하나 — 한 호출에 넷까지, 넘으면 다음 호출> {
  question: "재비판이 심각도를 낮춘 지적 <n>개 가운데 <이 묶음의 번호들 — 예: L1 · L2 · L3>. 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.\n전문: <$RV/synth.out 의 경로><n ≥ 4 일 때만: \n전부 되올리려면 기타 칸에 「전부」>",
  header: "낮춘 지적",
  options: <이 묶음의 지적마다 {label: "<파일 이름>:<줄> (L<k>)", description: "문제: <그 지적의 내용을 쉬운 말 한 구절로> · 낮춘 이유: <쉬운 말 한 구절로>"}> + {label: "그대로 둔다", description: "이 묶음의 지적을 낮춘 대로 둔다."},
  multiSelect: true }] })
```

그 아래 문단들을 아래로 바꾼다(추천을 달지 않는다는 문장은 그대로 둔다).

```
문제 요약과 낮춘 이유는 「낮춘 지적」 표의 「내용」 · 「낮춘 이유」 칸에서 온다. 묶음마다 지적을 여러 개 고를 수 있다.

- 모든 묶음에서 지적을 하나도 고르지 않았다(「그대로 둔다」만 · 빈 답) → 다시 합성하지 않고 아래 라우팅으로 간다.
- 되올릴 것을 골랐다 → 묶음마다 고른 `L<k>` 를 모아(「그대로 둔다」를 함께 골랐어도 고른 지적이 이긴다) Step 4 의 「되올려 다시 합성하기」를 돌려 `$RV/synth.out` 을 덮는다. 그 새 출력으로 이 Step 4.5 의 표면화를 다시 한 뒤 아래 라우팅으로 간다. 새 출력에는 이 게이트를 다시 띄우지 않는다.
- 기타 칸의 「전부」(같은 뜻의 말 포함) → 어느 묶음에 써도 낮춘 지적 전체다. `all` 로 되올리고 아직 띄우지 않은 호출은 건너뛴다.
- 「전부」와 다른 답이 부딪히면 — 한 묶음에 「전부」가 있고 다른 묶음(같은 호출이든 앞 호출이든)에 「그대로 둔다」나 낱개 선택이 있다 — 어느 쪽도 적용하지 않고 질문 하나로 다시 묻는다: 선택지는 「전부 되올린다」 · 「고른 것만 되올린다」 · 「그대로 둔다」 셋이고 추천을 달지 않는다 — 되올림은 리뷰 대상 코드를 쓴 쪽이 권할 수 없는 처분이다.
- 기타 칸에 `L<k>` 도 「전부」도 없으면 받은 글을 그대로 보이고 한 번만 다시 묻는다 — 두 번째도 없으면 그대로 둔다.
- 기타 칸의 글은 다시 합성하기 전에 아래 펜스로 맞춘다. `lowered-pick: all` 이면 `all` 로 넘긴다. `lowered-pick: bad …` 면 받은 글과 표의 번호를 보이고 한 번만 다시 묻는다(두 번째도 표에 없는 번호면 지금처럼 되올리지 않고 알린다).
```

번호 확인 펜스의 `BAD=""` 줄 앞에 한 줄을 넣는다(「전부」 · `all` 을 받는다):

```bash
case "$PICK" in 전부|all) echo "lowered-pick: all"; exit 0 ;; esac
```

- **범위 모드 갈래** `question:` → `"qg 반복 N: <ask-line>\n<지적마다 한 줄 — <file>:<line> — <요약>>\n전문: <$RV/synth.out 의 경로>\n범위 모드는 이미 있는 커밋을 본다 — 고칠 것은 새 브랜치에서 고친다. 어떻게 끝낼까?"`. 그 아래: 「지적 줄이 여덟을 넘으면 분류 질문과 같은 기준으로 질문을 나눈다.」 선택지 둘의 설명은 짝 파일.
- **상한 도달** `question:` → `"qg 가 반복 상한(<CAP>번 — 기본 5번)에 닿았다. <ask-line>\n전문: <$RV/synth.out 의 경로>\n반복을 하나 더 열까, 지금 판정으로 끝낼까, 멈출까?"`. 선택지 셋의 설명은 짝 파일.
- **Edit 실패 질문** — 선택지 둘의 설명은 짝 파일.
- **`e2e.md` 5 절** — 「증거표와 판정안을 보인 뒤 `AskUserQuestion` 하나를 띄운다.」 뒤에 더한다: 「질문 본문에는 판정안 한 줄, 충족하지 못한 기대 상태를 한 줄씩(없으면 「충족하지 못한 기대 상태 없음」), 「증거표: <세션 폴더의 `e2e-evidence.tsv` 경로>」 한 줄을 싣는다 — 질문 창만 보고 고를 수 있게.」

- [ ] **Step 1: 실패하는 시험을 쓴다**

`test_synthesize_ask_line.sh` — 같은 폴더의 `test_plain_synth_output.sh` 가 쓰는 fixture 와 호출 꼴(`python3 "$SYNTH" --findings … --recritic … --recritic-map …`)을 따른다.

```bash
out="$(python3 "$SYNTH" --findings "$FX_TWO" 2>/dev/null)"          # IMPORTANT 1 · SUGGESTION 1 인 fixture
assert_grep "$out" '^질문 줄: 막는 지적 1개 · 제안 1개 — 가장 무거운 것: [^ ]+:[0-9]+ — ' "질문 줄: 수와 가장 무거운 지적 하나"
assert_eq "$(printf '%s\n' "$out" | grep -c '^질문 줄: ')" "1" "질문 줄: 한 줄뿐이다"
assert_eq "$(printf '%s\n' "$out" | sed -n 's/^blocking: //p')" "1" "질문 줄 짝: blocking 줄의 수와 같다"
out0="$(python3 "$SYNTH" --findings "$FX_NONE" 2>/dev/null)"
assert_contains "$out0" "질문 줄: 지적 없음" "질문 줄: 지적이 없으면 그렇게 낸다"
long="$(python3 "$SYNTH" --findings "$FX_LONG" 2>/dev/null | sed -n 's/^질문 줄: .* — //p')"   # 내용이 200자인 fixture
[ "${#long}" -le 80 ] && ok "질문 줄: 요약은 80자에서 자른다" || no "질문 줄: 요약이 ${#long}자다"
assert_grep "$(python3 "$SYNTH" --findings "$FX_DEGRADED" 2>/dev/null)" '^질문 줄: .* · 경고 [0-9]+개: 판정 degrade$' "질문 줄: 판정 degrade 가 있으면 꼬리에 센다"
```

`test_lowered_gate_wiring.sh` — 「전부 되올린다」를 잠근 넷(`:56-63`)을 바꾼다:

```bash
assert_not_contains "$S45" '{label: "전부 되올린다"' "게이트: 「전부 되올린다」 선택지가 없다"
assert_contains "$S45" '낮춘 지적을 표의 순서로 셋씩 묶어 묶음마다 질문 하나' "게이트: 넷 이상이면 셋씩 나눠 묻는다"
assert_contains "$S45" 'description: "문제: <그 지적의 내용을 쉬운 말 한 구절로> · 낮춘 이유: <쉬운 말 한 구절로>"' "게이트: 설명에 문제 요약과 낮춘 이유"
assert_contains "$S45" '전부 되올리려면 기타 칸에 「전부」' "게이트: 넷 이상이면 본문에 「전부」 안내"
assert_contains "$S45" '어느 쪽도 적용하지 않고 질문 하나로 다시 묻는다' "게이트: 「전부」와 다른 답이 부딪히면 다시 묻는다"
assert_contains "$S45" '「전부 되올린다」 · 「고른 것만 되올린다」 · 「그대로 둔다」 셋이고 추천을 달지 않는다' "게이트: 다시 묻는 질문의 선택지 셋"
# 번호 확인 펜스 — 실제 합성기 출력에 걸어 돈다(그 파일의 lowered-pick 도우미 그대로)
assert_eq "$(run_pick '전부')" "lowered-pick: all" "펜스: 「전부」를 받는다"
assert_eq "$(run_pick 'all')" "lowered-pick: all" "펜스: all 을 받는다"
assert_eq "$(run_pick 'L1')" "lowered-pick: ok" "펜스 짝: 표의 번호는 지금처럼 ok"
assert_contains "$(run_pick 'L1,전부')" "lowered-pick: bad" "펜스: 번호와 「전부」를 섞은 글은 받지 않는다"
```

`test_plain_qg_templates.sh:50` 의 질문 문구 단언을 새 `question:` 의 첫 문장(`재비판이 심각도를 낮춘 지적 <n>개 가운데`)으로 바꾸고, 반복 게이트 · 범위 모드 · 상한 도달의 `question:` 에 `<ask-line>` 과 `전문: ` 이 있다는 단언, 분류 질문에 `표: ` 가 있다는 단언을 더한다. `ask-sites.tsv` 의 quality-pipeline 네 `지시` 행에 「설명 수」(범위 모드 2 · 반복 게이트 3 · 상한 3 · Edit 실패 2)를 채운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_synthesize_ask_line.sh; bash plugins/quality-gates/tests/test_lowered_gate_wiring.sh; bash plugins/quality-gates/tests/test_plain_qg_templates.sh`
Expected: 새 단언들이 ✗

- [ ] **Step 3: 합성 스크립트와 SKILL · e2e 를 고친다**

`render` 가 새 줄을 내면 그 출력을 글자째 견주는 기존 시험(`test_synthesize_*.{sh,py}` · `test_plain_synth_output.sh` · `test_pipeline_verdict_wiring.sh` · `test_verdict_no_reread.sh`)이 깨질 수 있다 — 새 줄을 기대값에 더한다. 판정 꼬리(`verdict:` 줄들)와 `qg-verdict-args:` 줄의 자리 · 글자는 바꾸지 않는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `for t in plugins/quality-gates/tests/test_synthesize_*.sh plugins/quality-gates/tests/test_lowered_gate_wiring.sh plugins/quality-gates/tests/test_plain_*.sh plugins/quality-gates/tests/test_pipeline_verdict_wiring.sh plugins/quality-gates/tests/test_verdict_no_reread.sh; do bash "$t" | tail -1; done; python3 tools/suite/run_unittest_dir.py plugins/quality-gates/tests; python3 tools/suite/run_unittest_dir.py tools/plain-language; bash shared/tests/test_ask_recommendation.sh | tail -1`
Expected: 실패 표시 줄(`✗` · `FAIL:` · `ERROR:`) 없음

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates shared/tests/fixtures/ask-sites.tsv tools/plain-language/test_measure_output.py
git commit -m "feat(qg): 코드 리뷰 질문이 지적 수 · 가장 무거운 지적 · 전문 자리를 싣는다"
```

---

### Task 13: quality-gates 나머지 · project-init · plugin-audit 의 추천 질문 자리

**AC:** AC11 · AC3

**Files:**
- Modify: `plugins/quality-gates/skills/artifact-critique/SKILL.md`
- Modify: `plugins/project-init/skills/project-init/SKILL.md`
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md`
- Modify: `shared/tests/fixtures/ask-sites.tsv`(이 파일들의 행)
- Modify: 이 문면을 잠근 `plugins/{quality-gates,project-init,plugin-audit}/tests/*`

**Interfaces:**
- Consumes: 짝 파일 3부(quality-pipeline · e2e 는 Task 12 가 했다. 「손대지 않는 자리」는 뺀다).

자리: `artifact-critique` 고치며 돌 수 없을 때 · E3 첫째 질문 · E3 둘째 질문 · 상한 뒤 한 라운드 더 / `project-init` git 규칙 교체 · CLAUDE.md 이전 · 브랜칭 전략 · merge 전략 · 접두 · release 이름 · 「이대로 진행 / 더 묻기」 · 필수 항목이 세 번 비었을 때 · S4 세 선택지 / `plugin-audit` 축 고르기 · 축을 하나도 안 골랐을 때.

문면이 따로 바뀌는 곳:

- `artifact-critique` E3 — 「이유(사용자가 부른 대상 · 모드 그대로다)는 … 쓴다」 조각을 빼고 「권하는 이유는 「실행」의 얻음에 담는다.」로. 「멈추기」 설명의 「안내 줄대로 고친 뒤 다시 부른다」는 짝 파일의 새 설명으로 바뀐다.
- `project-init` 브랜칭 전략 표 — 「Best for」 칸을 「설명」 칸으로 바꾸고 짝 파일의 얻음 · 내줌을 적는다(「Branches」 칸은 그대로).
- `plugin-audit` 축 고르기 — 「선택지 설명에 규모를 싣는다」 규칙은 그대로다. 규모의 세부(「설치돼 있으면」 · 「그 반박 1」 · 「지적마다 2회」)는 바로 뒤 규모 공시 줄이 싣는다 — 그 줄이 세부를 다 싣고 있는지 읽어 확인하고, 빠진 것이 있으면 공시 줄에 더한다(비용 공시가 줄면 안 된다 — `shared/tests/test_cost_disclosure.sh`).

- [ ] **Step 1: 목록에 「설명 수」를 채워 실패를 만든다**

Run: `bash shared/tests/test_ask_recommendation.sh`
Expected: 채운 행마다 `no ⑤`

- [ ] **Step 2: 자리를 고친다**

- [ ] **Step 3: 이 문면을 잠근 단언을 새 문장으로 바꾼다**

Run: `bash tools/suite/run-all.sh 2>&1 | grep -E "^FAILED plugins/(quality-gates|project-init|plugin-audit)/" ; true`
이 Task 가 바꾼 문장을 잠근 실패만 새 글자로 바꾼다. 스위트를 돌리는 동안 다른 스위트를 함께 돌리지 않는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_ask_recommendation.sh && bash shared/tests/test_cost_disclosure.sh` 와 Step 3 의 명령
Expected: `✗` 없음, Step 3 의 출력에 이 Task 가 낸 새 실패 없음

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates plugins/project-init plugins/plugin-audit shared/tests/fixtures/ask-sites.tsv
git commit -m "feat(qg,project-init,plugin-audit): 추천 질문의 설명을 얻음 · 내줌으로"
```

---

### Task 14: 옛 문구가 돌아오지 않게 — 부재 락 · 양의 짝 · 필수 칸 · 변이

**AC:** AC3 · AC15 · AC16

**Files:**
- Create: `shared/tests/test_window_phrases.sh`(100755)
- Modify: `shared/tests/ask_recommendation.py`(`REQUIRE_DESCS`) · `shared/tests/fixtures/ask_recommendation/{doc.md,sites.tsv,expected.txt}`
- Modify: `tools/plain-language/window_phrases.txt`(앞 Task 들이 찾은 문구를 더한다)

**Interfaces:**
- Consumes: `tools/plain-language/window_phrases.txt`(Task 1) · 앞 Task 들이 넣은 새 문장.
- Produces: `REQUIRE_DESCS = ("꼬리", "출처꼬리")` — 그 종류의 행은 「설명 수」가 비면 `no ⑤ … 설명 수 칸이 비었다`.

`test_window_phrases.sh`:
- 코퍼스는 `test_ask_recommendation.sh` 의 `derive_git` 과 같은 글롭(`plugins/*/skills/*.md` · `plugins/*/references/*.md` · `plugins/*/agents/*.md` · `shared/*/references/*.md`, `/tests/` 와 링크는 뺀다)에 `shared/style/plain-language.md` 를 더한 것이다. 코퍼스가 0 이면 실패다. git 도출과 find 도출의 수가 같은지 본다(양의 짝).
- **부재** — 문구 목록의 문구마다, 코퍼스의 어느 파일에도 없다. 있으면 `<파일>:<줄>` 과 함께 실패.
- **양의 짝** — 옛 문구가 있던 자리마다 새 문장이 정확히 있다(자리 · 글자는 아래 표). 부재만 보면 그 절을 통째로 지워도 통과한다.

| 파일 | 있어야 하는 글자(한 번 이상) |
|---|---|
| `shared/style/plain-language.md` | `추천이 있는 질문은 질문 창만 보고 고를 수 있게 쓴다 — 질문 위 글은 안 보일 수 있다.` |
| `shared/docreview/references/reviewing-document.md` | `질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다.` |
| `plugins/spec-distill/references/proceed-gate.md` | `질문 본문에는 결정 하나, 경고 줄 하나, 「전문: <경로>」 한 줄을 둔다.` · `제안 선택지의 설명은 「얻음: <제안 이유> · 내줌:` |
| `plugins/spec-distill/skills/pm-interview/references/finishing.md` | `"신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 이 일을 어떻게 진행할까?"` · `정본(`proceed-gate.md`)의 본문 규칙대로` · `제안 선택지의 설명은 「얻음: <제안 이유> · 내줌:` |
| `plugins/spec-distill/skills/pm-interview/references/saturation.md` | `권하는 이유는 그 선택지의 얻음에 담는다` |
| `plugins/spec-distill/references/redecompose.md` | `"다시 나눌 표의 신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 어떻게 할까?"` |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | `그 이유는 그 선택지의 얻음에 담는다` · `질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고` |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 위 둘째 글자 |
| `plugins/spec-distill/skills/request-framing/SKILL.md` | 위 둘째 글자 · `제안 선택지의 설명은 「얻음: <제안 이유> · 내줌:` |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | `전부 되올리려면 기타 칸에 「전부」` · `전문: <$RV/synth.out 의 경로>` |
| `plugins/quality-gates/skills/artifact-critique/SKILL.md` | `권하는 이유는 「실행」의 얻음에 담는다.` |

- [ ] **Step 1: 실패하는 시험을 쓴다**

`test_window_phrases.sh` 를 쓴다. 그리고 fixture 에 한 경우를 더한다 — `꼬리` 행인데 「설명 수」가 빈 블록(「러-질문:」), `expected.txt` 에 `no ⑤ doc.md:<줄> 꼬리 「러-질문:」 (목록 L<n>): 설명 수 칸이 비었다 — 꼬리 · 출처꼬리 행은 채워야 한다(없으면 0)`. fixture 의 기존 `꼬리` · `출처꼬리` 행에는 「설명 수」 `0` 을 채운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_window_phrases.sh; bash shared/tests/test_ask_recommendation.sh`
Expected: 첫째는 앞 Task 들이 다 끝났으면 통과하거나, 남은 옛 문구의 `<파일>:<줄>` 을 낸다 — 나온 자리를 고친다(그 자리의 Task 가 놓친 것이다. 고친 자리를 보고에 적는다). 둘째는 `fixture: no 줄이 expected.txt 와 같다` 가 ✗

- [ ] **Step 3: `REQUIRE_DESCS` 를 켜고 실제 목록을 채운다**

`REQUIRE_DESCS = ("꼬리", "출처꼬리")`. `ask-sites.tsv` 에서 그 종류인데 「설명 수」가 빈 행에 `0` 또는 실제 수를 채운다 — `0` 은 그 질문의 선택지를 모델이 그 자리에서 짜는 행에만 쓴다(skill 글에 고정 선택지가 있는데 `0` 을 쓰면 안 된다 — 행마다 범위를 읽고 정한다).

앞 Task 들이 새로 찾은 창 밖 문구가 있으면 `window_phrases.txt` 에 더한다. 더하는 문구는 지금 코퍼스에 없어야 한다(있으면 그 자리를 먼저 고친다).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_window_phrases.sh && bash shared/tests/test_ask_recommendation.sh`
Expected: 둘 다 `✗` 없음

- [ ] **Step 5: 커밋**

```bash
git add shared/tests tools/plain-language/window_phrases.txt
git commit -m "test(shared): 창 밖을 가리키는 옛 문구의 부재 락과 양의 짝"
```

- [ ] **Step 6: 변이 넷과 양성 대조(AC15)**

커밋한 뒤에 한다. 변이마다 한 파일만 고치고, 본 뒤 `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 비었는지 확인한다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.

| # | 변이 | 돌릴 것 | 기대 |
|---|---|---|---|
| 0 | 없음(양성 대조) | `bash shared/tests/test_ask_recommendation.sh; bash shared/tests/test_window_phrases.sh` | 둘 다 GREEN |
| 1 | `plugins/spec-distill/references/trivia-escape.md` 의 한 선택지 설명에서 ` · 내줌: …` 을 지운다 | `test_ask_recommendation.sh` | RED — `no ⑤` 가 그 행을 가리킨다 |
| 2 | `plugins/spec-distill/references/redecompose.md` 의 한 선택지에서 `description: "…"` 을 통째로 지운다 | 같다 | RED — 설명 수가 다르다 |
| 3 | `plugins/spec-distill/skills/pm-interview/references/saturation.md` 에 옛 조각(문구 목록의 둘째 줄)을 되살린다 | `test_window_phrases.sh` | RED — 부재 단언이 그 파일 · 줄을 가리킨다 |
| 4 | `plugins/spec-distill/references/proceed-gate.md` 에서 `질문 본문에는 결정 하나, 경고 줄 하나, …` 문장을 지운다 | `test_window_phrases.sh` | RED — 양의 짝 단언 |

넷 가운데 GREEN 으로 남는 변이가 있으면 그 검사를 고치고(변이가 잘못 걸린 것인지 먼저 본다) 다시 돈다. 결과 표를 `~/.claude/sdd-mirror/present-tradeoffs/mutations.txt` 에 적는다.

---

### Task 15: 판 올림 · CHANGELOG · 전체 대조 · PR 재료

**AC:** AC2 · AC16 · AC18 · AC19 · AC20

**Files:**
- Modify: `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/.claude-plugin/plugin.json`
- Modify: `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`(`## 한계` 에 한 줄 — 있으면) · 설계문서 `## 미룸` 표

**Interfaces:**
- Consumes: `~/.claude/sdd-mirror/present-tradeoffs/` 의 `baseline.json`(Task 1) · `token-boundary.txt`(Task 2) · `mutations.txt`(Task 14).

- [ ] **Step 1: 판을 올린다**

규칙이 바뀐 새 표면이라 minor 다: spec-distill `8.14.0` → `8.15.0` · quality-gates `14.8.1` → `14.9.0` · project-init `5.4.1` → `5.5.0` · plugin-audit `1.7.0` → `1.8.0`. 기준 브랜치가 그 사이 판을 올렸으면 그 판에서 minor 를 올린다.

- [ ] **Step 2: CHANGELOG 를 쓴다**

플러그인마다 `## [<판>] — <오늘 날짜>` 절. `### Changed` 에 그 플러그인에서 바뀐 것, `### Added` 에 새 표면(spec-distill: 엔진 명령 `ask-material` · `gate-file`, 환경 변수 `DEVBREW_DOCREVIEW_ASK_WIDTH`, `brief_review_state.py short`, 번호 대조의 `질문 줄:` / quality-gates: 합성 출력의 `질문 줄:`). spec-distill 과 quality-gates 의 절에는 「이 검사가 못 보는 것」 셋과 남는 위험을 `### 한계` 소제목 없이 `### Changed` 끝의 항목으로 적는다(그 CHANGELOG 의 절 이름 규칙을 따른다):

```
- 못 보는 것 셋: 설명의 내용이 형식만 채운 것인지 · 모델이 그 자리에서 짜는 질문이 규칙을 따랐는지 · 줄인 글이 원문과 뜻이 같은지. 레포 테스트는 글자의 있고 없음만 본다 — 세션 기록 재측정(`tools/plain-language/measure_questions.py`)과 화면 확인이 본다.
- 질문 없이 한쪽을 권하는 글에 대가가 붙었는지는 정적 검사가 볼 수 없다.
- 낼 스크립트가 없는 경고 채널(구조 검사의 참고 줄 · superpowers 판 확인 · 요청 정리 단계의 경고)의 짧은 줄은 리뷰받은 쪽이 쓴다.
```

quality-gates 의 `### Removed` 에: 낮춘 지적 게이트의 「전부 되올린다」 선택지(기타 칸의 「전부」로 바뀌었다).

Run: `bash shared/tests/test_changelog_integrity.sh`
Expected: `✗` 없음

- [ ] **Step 3: 실행 중 개입이 없는지 확인한다(AC19)**

Run: `git diff --stat "$(git merge-base HEAD "$BASE")" -- 'plugins/*/hooks' 'plugins/*/agents' 'shared/docreview/agents'`
Expected: 빈 출력

- [ ] **Step 4: 길이를 다시 잰다(AC2)**

Run: `python3 tools/plain-language/token_boundary.py --base "$(git merge-base HEAD "$BASE")"` 와 `--body`
Expected: Task 2 의 Step 6 과 같은 판정 — 새로 밀려난 실제 `## ` 절이 없다. 펜스 줄의 값이 Task 2 때와 달라졌으면(뒤 Task 가 SKILL.md 앞부분을 고쳤다) `token-boundary.txt` 를 고쳐 적는다.

- [ ] **Step 5: 전체 스위트를 기준 브랜치와 견준다(AC16)**

기준 브랜치의 깨끗한 사본(`git worktree add --detach <임시 폴더> "$(git merge-base HEAD "$BASE")"`)과 이 브랜치에서 **차례로**(같은 시각에 돌리지 않는다) `bash tools/suite/run-all.sh > <파일>` 을 돌린다.

Run: `comm -13 <(sort base.txt) <(sort head.txt)`
Expected: 빈 출력(이 브랜치에만 있는 `FAILED` 줄이 없다). 나오면 고치고 다시 견준다. 임시 worktree 는 견준 뒤 지운다.

- [ ] **Step 6: 설계문서 `## 미룸` 표를 맞춘다**

「고친 뒤의 재측정」 행의 받는 곳을 「`tools/plain-language/README.md` 의 재측정 기준과 명령 — 구현 PR 이 머지되고 새 판으로 리뷰를 몇 번 돈 뒤 사용자 세션이 돈다. PR 본문 「후속」 칸」으로 고친다. 구현 중 미룬 것이 생겼으면 행을 더한다(항목 · 이유 · 받는 곳).

- [ ] **Step 7: PR 본문 재료를 한 파일에 모은다**

`~/.claude/sdd-mirror/present-tradeoffs/pr-body.md` 에 한국어로: 무엇을 왜 바꿨나(세 문장) · 고치기 전 기준 수(`baseline.json` 의 수 — 질문 글은 싣지 않는다) · 길이 측정의 공시(인터뷰 skill 의 펜스 줄과 값) · 변이 표 · 화면 확인 목록 · 후속. 화면 확인 목록은 사용자가 직접 보는 것이다 — 항목마다 `- [ ]` 로 두고, 하지 못한 항목은 「하지 못했다」로 적는다:

```
- [ ] 이 브랜치의 설치본으로 설계문서 리뷰 · brief 리뷰 · seed 리뷰 · 코드 리뷰를 한 번씩 돌렸다
- [ ] 질문 창만 보고 고를 수 있었다
- [ ] 「전문」 경로가 열린다 · 기타 칸의 「전문」이 돈다
- [ ] 설명이 세 줄 안이다
- [ ] 기타 칸에 답한 뒤에도 그 질문과 설명이 화면에 남아 있다
- [ ] 창을 80×24 쯤으로 줄였을 때 선택지 넷 · 세 줄 설명의 맨 아래 설명 끝까지 보인다
```

- [ ] **Step 8: 커밋**

```bash
git add plugins/*/.claude-plugin/plugin.json plugins/*/CHANGELOG.md plugins/spec-distill/README.md docs/superpowers/specs/2026-11-15-present-tradeoffs-design.md
git commit -m "chore(release): 추천의 대가와 리뷰 뒤 질문 — 네 플러그인 판 올림"
```

push 와 PR 은 사용자가 말할 때 한다. PR 을 만들기 전에 마지막 전체 리뷰가 낸 AC 보고(`~/.claude/sdd-mirror/present-tradeoffs/ac-report.md` — AC 마다 한 줄 `AC1: 구현됨 — 근거`, 판정은 구현됨 · 미룸 · 빠짐)로 `python3 <spec-distill 플러그인 루트>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-15-present-tradeoffs-design.md ~/.claude/sdd-mirror/present-tradeoffs/ac-report.md` 를 돌려 경고를 사용자에게 보인다. 미룸 · 빠짐은 설계문서 `## 미룸` 표에 올린다.
