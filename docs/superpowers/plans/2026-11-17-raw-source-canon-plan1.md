# 원자료 정본 사슬 — 계획 1(framing 쪽) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** framing 이 사용자의 말을 기록 파일에 쓸 때 비밀값을 가리고 고른 말과 쓴 말을 갈라 적게 하며, 원자료를 찾는 길을 새 모듈 하나(`raw_source.py`)에 모으고, seed 를 「모델이 줄인 글」 로 다시 이름 짓는다.

**Architecture:** 새 모듈 `plugins/spec-distill/scripts/raw_source.py` 가 seed 경로나 인터뷰(brief · 상태 파일) 경로를 받아 판결 하나(찾음 · framing 없는 인터뷰 · 찾지 못함)를 마지막 줄로 낸다. framing skill 글 · 기록 파일 템플릿 · seed 템플릿 · seed 프로필의 문장을 고치고, seed 문법과 seed 리뷰 번들 조립을 한 자리씩 연다. 옆 로드맵의 생성기(`team_write.py`)는 고치지 않고, 같은 픽스처로 판정이 같은지만 잰다.

**Tech Stack:** Python 3.9(표준 라이브러리) · bash 3.2 셸 테스트(`shared/tests/assert.sh`) · unittest.

**Spec:** `docs/superpowers/specs/2026-11-16-raw-source-canon-design.md` — 이 계획은 그 설계의 계획 1 이다(설계문서 `## Metadata`).

**이 계획의 몫.** 설계 2 · 6 · 7(CLAUDE.md 없는 레포 · framing 의 「다른 다음 단계」 운반 문장 · README · 변경 기록 · 판)과 설계 1 의 찾는 길과 판결. AC: AC1 AC3 AC4 AC5 AC6 AC13 AC14 AC15 AC16 AC18 AC20 AC21 AC22. 나눠 갖는 셋:

- AC4 — 이 계획: framing `## 2` 답 줄의 「라벨」 · 「적음」 표시 · 기록 파일 템플릿 · seed 프로필 문장. 계획 2: brief 프로필 문장.
- AC20 — 이 계획: framing 원문 보존 걸음 · 기록 파일 템플릿 · seed 프로필 문장. 계획 2: brief 프로필 문장.
- AC22 — 이 계획: framing 「다른 다음 단계」 운반 문장. 계획 2: 조사 agent 입력 낱말 넷(`agents/coverage-mapper.md` · `agents/blind-spot-prober.md` · `skills/pm-interview/references/steelman.md` · 인터뷰 본문).

계획 2 의 몫(여기서 하지 않는다): 설계 3 · 4 · 5, 모듈의 글을 내는 명령 둘, `docreview-profiles/design-doc.md` · `brief.md`, 인터뷰 본문(`skills/pm-interview/SKILL.md`)의 모든 편집(진입 단계가 기록 파일 경로를 이 모듈로 받게 하는 문장 포함), AC2 AC7 AC8 AC9 AC10 AC11 AC12 AC17 AC19 AC23 AC24.

## Global Constraints

- 옆 로드맵의 `team_write.py` · `team_files.py` · `team_check.py` 는 고치지 않는다.
- `seed_review_log.AUDIT_HEADINGS` 의 앞 셋은 글자와 순서를 바꾸지 않는다. `seed_review_log.py` · `check_seed.py` 는 이 계획에서 고치지 않는다(게이트가 멈추는 조건 — 제목 일곱 · 앞뒤 공백을 뗀 줄 — 은 diff 가 없다).
- 리뷰어 프로필 편집은 보안 리뷰 대상이다 — `docreview-profiles/seed.md` 는 문장을 더하기만 하고 `ground_truth` 문자열 · 판정 규칙 · 처분 안내는 바꾸지 않는다.
- 비밀값 가림 표시는 `brief_body.P21_PLACEHOLDER_RE` 가 아는 집합(`<REDACTED>` · `<REDACTED:라벨>` · `<SECRET:...>` · `<TOKEN:...>` · `<KEY:...>` · `<CREDENTIAL:...>` · `<PLACEHOLDER:...>`)이다.
- `seed_edit_screen.py` · `seed_edit_diff.py` · `seed_provenance.py`(분류 규칙 · `parse_reading_line`) · `interview_state.py` 는 고치지 않는다.
- 인터뷰 본문(`skills/pm-interview/SKILL.md`)은 이 계획에서 건드리지 않는다(줄 수 상한 락 — 기본 브랜치에서 상한이 604 로 올라 있다).
- 새 `scripts/*.py`: `re.compile` 리터럴이 `"## 6. 사용자 원문"` 맨 앞에서 3글자 이상 맞으면 안 된다(§6단일화 락 — 제목은 문자열 비교로 본다) · `open(` · `.read_text(` 에 `encoding` · `"python3"` 리터럴 금지 · Python 3.9 문법(`from __future__ import annotations`).
- 다른 파일과 20줄(200자 이상) 같은 블록을 만들지 않는다(`shared/tests/test_no_new_duplication.sh`).
- skill 글에 새로 쓰는 문장에 `AskUserQuestion` 리터럴을 넣지 않는다(`shared/tests/fixtures/ask-sites.tsv` 의 자리 수 락). 앵커 글자(「단독 `AskUserQuestion` 으로」 · 「**audit 템플릿 절 제목이 중복되면**」 · 「**다른 다음 단계(둘째 질문).**」)는 파일에서 한 번씩만 나와야 한다.
- 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 로 `100755` 를 확인한다.
- 판: spec-distill minor — 머지 직전 기본 브랜치 판 위의 다음 minor. `CHANGELOG.md` 머리는 그 판 하나만(건너뛰면 `shared/tests/test_changelog_integrity.sh` RED).
- 커밋은 pathspec 으로, 메시지는 한국어 Conventional Commits(type · scope 영어).
- 전체 스위트는 아래 공유 잠금으로만 돌린다(하위 agent 에게 보내는 글에도 이 줄을 그대로 싣는다):
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`
  못 잡으면 주인 · 잡은 시각을 보고한다. 좁은 테스트는 잠금 없이 돈다.
- 모든 셸 테스트 · 픽스처는 `PYTHONDONTWRITEBYTECODE=1` 로 돈다(같은 길이 변이가 stale `.pyc` 를 못 넘는다).

## Review Focus

- 상태 파일을 다른 cwd 에서 넘겨도 `seed:` 는 그 상태 파일이 속한 작업 트리 루트 기준으로 풀린다 — cwd 기준으로 풀면 같은 인터뷰가 부르는 자리마다 다른 판결이 된다(Task 2 `test_cwd_elsewhere`).
- `seed:` 값이 따옴표로 감싸져 있어도 같은 판결이다(Task 2 `test_quoted_seed`).
- 가림 표시가 줄 머리에 오거나 소문자(`<redacted>`) · 공백이 든 라벨(`<REDACTED: 공백>`)이면 seed 문법은 지금처럼 거부한다 — 표시 하나를 열면서 줄 머리 꺾쇠와 HTML 을 함께 열지 않는다(Task 3).
- `CLAUDE.md` 가 끊긴 링크이거나 폴더면 「없음」 이 아니라 지금처럼 종료 코드 2 로 멈춘다 — 없는 것과 깨진 것을 한 값으로 접지 않는다(Task 4).
- `--interview` 에 brief 의 기록 파일(`.audit.md`)을 잘못 주면 조용히 「framing 없는 인터뷰」 가 아니라 인자 오류(2)다(Task 2 `test_usage_errors`).

---

### Task 1: 다시 확인 — 설계가 기댄 자리와 이 계획의 첫 과제

**Files:** 없음(읽기만). 결과는 이 Task 의 커밋 없이 지휘자에게 보고한다.

이 Task 는 AC 를 구현하지 않는다. 아래가 하나라도 기대와 다르면 멈춰 보고한다(계획을 쓸 때 브랜치 끝 42b1f66c 에서 다시 확인한 결과를 「기대」 로 적었다).

- [ ] **Step 1: 기본 브랜치를 합친 뒤에 시작하는지 본다**

Run: `git merge-base --is-ancestor origin/HEAD HEAD && echo merged`
Expected: `merged`. 아니면 멈춘다 — 기본 브랜치(948c37d2 이후)가 이 계획이 고치는 `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` 을 바꿨다. 합치는 것은 지휘자 몫이다.

- [ ] **Step 2: 설계가 근거로 든 자리를 다시 찾는다**

| 확인 | 명령 | 기대 |
|---|---|---|
| 원문 보존 걸음 · 질문 기록 걸음 | `grep -n '1\. \*\*원문 보존\*\*\|^\*\*기록\*\* —' plugins/spec-distill/skills/request-framing/SKILL.md` | 두 줄 |
| 제목 줄 겹침 물음 | `grep -c '단독 `AskUserQuestion` 으로 「그 줄만 인용 표시로 감싼다 (권장) / 멈춘다」를' …/request-framing/SKILL.md` | 1 |
| 추가 라운드 승인 낱말 | `grep -c 'typed`, 선택지를 골랐으면 `label`' …/request-framing/SKILL.md` | 1 |
| 「다른 다음 단계」 운반 문장 | `grep -c 'seed 전문을 그 skill 의 사용자 원문(첫 요청 — 인터뷰의 S1 과 같은 자리)으로 삼아 원문 그대로 입력으로 삼는다' …/request-framing/SKILL.md` | 1 |
| seed 본문 줄의 꺾쇠 거부 | `grep -n 'ANGLE_RE = ' plugins/spec-distill/scripts/seed_body.py` | `re.compile(r"<\S")` |
| 가림 표시 정규식 | `grep -n 'P21_PLACEHOLDER_RE = ' plugins/spec-distill/scripts/brief_body.py` | 있음 |
| 옆 생성기의 찾는 함수 | `grep -n 'def _framing_from_state' plugins/spec-distill/scripts/team_write.py` | 있음, 상태 파일 없음 · `seed:` 비었거나 `없음` → `(None, None)` |
| 진입 판정이 seed 경로를 `없음` 으로 적는 길 | `grep -n 'def seed_value' plugins/spec-distill/scripts/interview_state.py` | 링크 · 작업 트리 밖이면 `없음` |
| 모듈의 seed 경로 입력은 자리 도출과 `type` 확인만(설계 Handoff Context — 리뷰어가 다시 읽지 않은 글) | 설계 1 의 「받는 것」 · 「인터뷰의 원자료 판결은 상태 파일 판결 뒤」 를 `interview_state.py` 의 `cmd_entry` 와 맞춰 읽는다 | 모듈이 기록 조건(링크 · 트리 밖 · 이름 꼴)을 다시 잴 필요가 없다 — 그 조건은 `seed:` 값(`없음`)과 `## 풀린 입력` 블록으로만 드러난다 |

- [ ] **Step 3: 사용자 문구를 적는 걸음을 전부 센다**

Run: `grep -n 'said-\|## 1. 원문\|## 5. degrade' plugins/spec-distill/skills/request-framing/SKILL.md`
Expected: 사용자의 말이 audit 에 들어가는 길이 여덟이다 — ① `## 1. 원문`(받은 글 · 주제 질문의 답) ② `## 2` 의 «당신이 답한 것» · «사용자가 적은 말»(`said-r<n>.txt`) ③ 결정 답과 거부 줄(`said-<id>.txt`) ④ 막지 않는 질문의 답(`said-<id>.txt`) ⑤ 덩어리 처분 답(`said-hunk-<k>.txt`) ⑥ 추가 라운드 승인(`said-extra-r<n>.txt`) ⑦ 제목 줄 겹침 물음의 선택과 문구(`## 5. degrade` 한 줄 — 설계의 목록에 없던 길) ⑧ 질문 라운드에서 직접 적은 답(Task 6 이 `## 1` 에 새로 더하는 길). 이 여덟을 덮는 skill 글의 자리는 다섯이다 — 확산 1 · `**기록**` 문단 · 「사용자 문구 · 리뷰어 요약은 셸 인자에 직접 쓰지 않는다」 문단 · `### 절차` 의 추가 라운드 줄 · 새 `### 비밀값 가리기` 절(⑦ 은 이 절의 목록이 덮는다 — 물음 문단은 AC6 이 diff 를 금한다). 더 있으면 Task 6 의 목록에 더한다.

- [ ] **Step 4: CLAUDE.md 없는 임시 레포에서 번들 조립을 돌린다**

`$TMPDIR` 아래 빈 git 레포에 seed(`type: interview-seed` · 한 문장)와 일곱 제목을 가진 기록 파일을 두고, 레포 루트에서
`python3 <SD>/scripts/build_seed_inline_blob.py docs/s.md docs/s.audit.md CLAUDE.md --for detect` 를 돌린다.
Expected: rc 2, stderr `claude_md_file not found: CLAUDE.md`(계획을 쓸 때 실측한 값). 다르면 멈춘다.

---

### Task 2: 원자료를 찾는 모듈 — 찾는 길과 판결(AC1 · AC21)

**Files:**
- Create: `plugins/spec-distill/scripts/raw_source.py`
- Create: `plugins/spec-distill/tests/test_raw_source.py`

**Interfaces:**
- Consumes: `state_path.worktree_root(cwd) -> (Path, bool)` · `state_path.frontmatter_scalars(path) -> dict | None`. 테스트는 `team_write._framing_from_state(top, state_rel, W)` · `team_write.frontmatter` · `team_write.unquote` · `team_write.FRAMING_TYPE` 를 불러 쓰기만 한다.
- Produces(계획 2 와 Task 7 이 기댄다):
  - CLI `raw_source.py locate --seed <seed 경로>` · `raw_source.py locate --interview <brief 또는 상태 파일 경로>`(둘 중 하나만). 하위 명령 구조라 계획 2 가 글을 내는 명령 둘을 하위 명령으로 더한다 — `locate` 의 인자 · 판결 줄 · 종료 코드는 이 Task 에서 굳힌다.
  - stdout 마지막 줄(다른 줄은 stdout 에 내지 않는다): `raw-source: FOUND <framing 기록 파일 경로>` · `raw-source: NO-FRAMING` · `raw-source: LOST <사유>`. 종료 코드: FOUND · NO-FRAMING 0, LOST 3, 인자 오류 · 상태 파일을 읽지 못함 2(stderr `[raw_source] …`).
  - FOUND 의 경로: `--seed` 면 받은 글자 그대로의 seed 경로에서 끝의 `.md` 를 `.audit.md` 로 바꾼 것, `--interview` 면 상태 파일 `seed:` 값(작업 트리 루트 기준 상대 경로)에서 같게 바꾼 것.
  - Python: `Verdict(kind: str, audit: str | None, reason: str | None)`(frozen dataclass, kind ∈ `"FOUND" | "NO-FRAMING" | "LOST"`) · `locate_from_seed(seed: str) -> Verdict` · `locate_from_interview(path: str) -> Verdict`(인자 오류면 `ValueError`) · `verdict_line(v: Verdict) -> str`.
  - 사유 상수(글자 그대로 — 사유 안의 줄 나눔은 공백으로 바꾼다):
    - `R_SEED_MISSING = "seed 파일이 없다 — {seed}"`
    - `R_SEED_NOT_MD = "seed 파일 이름이 .md 로 끝나지 않아 framing 기록 파일의 자리를 정하지 못한다 — {seed}"`
    - `R_AUDIT_MISSING = "seed 옆에 framing 기록 파일이 없다 — {audit}"`
    - `R_AUDIT_TYPE = "framing 기록 파일 머리의 type 이 interview-seed-audit 이 아니다 — {audit} (type: {kind})"` — `{kind}` 는 값 · `없음` · `읽지 못함`
    - `R_SEED_UNRECORDED = "seed 로 시작했는데 상태 파일에 seed 경로가 기록되지 않았다 — 붙여 넣은 seed 이거나 링크 · 작업 트리 밖 · 이름 꼴이 다른 seed 다"`

판정 순서(옆 생성기와 같은 차례):

- `--seed s`: `Path(s)` 가 파일이 아니면 `R_SEED_MISSING` → `s` 가 `.md` 로 끝나지 않으면 `R_SEED_NOT_MD` → `s[:-3] + ".audit.md"` 가 파일이 아니면 `R_AUDIT_MISSING` → 그 머리 `type`(`frontmatter_scalars`, None 이면 `읽지 못함`)이 `interview-seed-audit` 이 아니면 `R_AUDIT_TYPE` → FOUND. 링크를 풀지 않고 받은 글자에서 도출하며, seed 머리의 `audit_file:` 은 읽지 않는다.
- `--interview p`: `p` 가 `.audit.md` 로 끝나거나 `.md` 로 끝나지 않으면 인자 오류. `.state.md` 면 그것이 상태 파일, 아니면 `p[:-3] + ".state.md"`. 상태 파일이 파일이 아니면 NO-FRAMING. 머리를 읽지 못하면 2. `seed:` 가 비었거나 `없음` 이 아니면 루트 = `worktree_root(상태 파일의 폴더)` 에서 그 값으로 위 `--seed` 의 넷을 잰다(경로 표기는 `seed:` 값 그대로). 비었거나 `없음` 이면 `## 풀린 입력` 블록을 본다 — frontmatter 뒤 첫 `## 풀린 입력` 줄(줄 전체 문자열 비교) 다음의 첫 비지 않은 줄이 물결표 넷 이상의 펜스이고 그 펜스 안 첫 줄이 `---` 이며 그 머리의 `type` 이 `interview-seed` 면 `R_SEED_UNRECORDED`, 그 밖(블록 없음 포함)은 NO-FRAMING.

모듈 머리 docstring 에 CLI · 판결 줄 · 종료 코드와, 옆 생성기(`team_write._framing_from_state`)와 다른 한 갈래를 적는다: 「`seed:` 가 `없음` 인데 `## 풀린 입력` 이 seed 인 인터뷰를 옆 생성기는 framing 없는 인터뷰로 읽고 이 모듈은 찾지 못함으로 읽는다 — 그쪽은 옮겨 적을 기록 파일이 없다는 것만 알면 되고, 이쪽은 첫 입력이 모델이 줄인 글이라는 것까지 알아야 한다.」

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `tests/test_raw_source.py`(unittest). 각 테스트는 `tempfile.TemporaryDirectory()` 안에 `git init -q` 한 레포를 만들고 CLI 를 `subprocess.run([sys.executable, RAW, "locate", ...], cwd=repo)` 로 부른다. 픽스처: seed = `---\ntype: interview-seed\naudit_file: other.audit.md\n---\n\n문장 하나.\n`, 기록 파일 = `---\ntype: interview-seed-audit\n---\n\n## 1. 원문\n\n원문.\n`, 상태 파일 = `---\ntype: interview-state\nseed: <값>\n---\n\n## 풀린 입력\n\n~~~~\n<seed 전문 또는 「그냥 요청」>\n~~~~\n`.

```python
class SeedMode(unittest.TestCase):
    def test_found(self):            # docs/s.md + docs/s.audit.md
        self.assertEqual(run("--seed", "docs/s.md"), (0, "raw-source: FOUND docs/s.audit.md"))
    def test_seed_missing(self):     # rc 3, 마지막 줄 == "raw-source: LOST " + R_SEED_MISSING.format(seed="docs/none.md")
    def test_not_md(self):           # docs/s.txt 가 있다 → R_SEED_NOT_MD
    def test_audit_missing(self):    # docs/other.audit.md 만 있다(audit_file: 이 가리킴) → R_AUDIT_MISSING.format(audit="docs/s.audit.md")
    def test_audit_type(self):       # type: interview-brief → R_AUDIT_TYPE(kind="interview-brief"); 머리 없음 → kind="없음"
    def test_link_seed(self):        # docs/l.md → 레포 밖 파일 링크, docs/l.audit.md 있음 → FOUND docs/l.audit.md
    def test_odd_name(self):         # docs/notes.md + docs/notes.audit.md → FOUND
    def test_outside_tree(self):     # 다른 임시 폴더의 절대경로 seed + 옆 기록 파일 → FOUND <그 절대경로>.audit.md
class InterviewMode(unittest.TestCase):
    def test_brief_and_state_agree(self):   # seed: docs/s.md → 두 입력 모두 (0, "raw-source: FOUND docs/s.audit.md")
    def test_no_state(self):                # brief 만 → (0, "raw-source: NO-FRAMING")
    def test_seed_none_plain_input(self):   # seed: 없음, 풀린 입력 「그냥 요청」 → NO-FRAMING
    def test_seed_none_seed_input(self):    # seed: 없음, 풀린 입력이 seed 전문 → (3, "raw-source: LOST " + R_SEED_UNRECORDED)
    def test_seed_empty_seed_input(self):   # seed: (빈 값) + seed 전문 → 같은 LOST
    def test_no_block(self):                # seed: 없음, ## 풀린 입력 없음 → NO-FRAMING
    def test_recorded_seed_missing(self):   # seed: docs/gone.md → R_SEED_MISSING.format(seed="docs/gone.md")
    def test_recorded_audit_type(self):     # → R_AUDIT_TYPE
    def test_quoted_seed(self):             # seed: "docs/s.md" → FOUND docs/s.audit.md
    def test_cwd_elsewhere(self):           # cwd=다른 임시 폴더, 상태 파일 절대경로 → FOUND docs/s.audit.md
    def test_usage_errors(self):            # --interview docs/x.audit.md · docs/x.txt · 인자 둘 · 인자 없음 → rc 2, stdout 에 raw-source: 줄 없음
class ParityWithTeamWrite(unittest.TestCase):
    # 같은 픽스처를 team_write._framing_from_state(top, "docs/b.state.md", W) 에 넣는다.
    # W: read=Path.read_text(encoding="utf-8"), rel=realpath(p).relative_to(top).as_posix(), Refused/Usage 예외.
    # 옆 판정 = found 이고 type == FRAMING_TYPE → FOUND · found 인데 type 다름 · lost → LOST · (None, None) → NO-FRAMING.
    def test_same(self):        # framing 있음 · framing 없음 · 상태 파일 없음 · 기록 파일 없음 · seed 파일 없음 · type 다름 · .md 아님 — 일곱 다 같다
    def test_documented_difference(self):
        # seed: 없음 + 풀린 입력이 seed: 옆 생성기 NO-FRAMING, 이 모듈 LOST(R_SEED_UNRECORDED) — 설계 1 이 고른 차이다
```

- [ ] **Step 2: 실패를 본다** — Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q test_raw_source` · Expected: ERROR(`raw_source.py` 없음).
- [ ] **Step 3: `raw_source.py` 를 위 Interfaces 대로 쓴다** — argparse 하위 명령 `locate`(상호 배타 그룹 `--seed` · `--interview`, 필수). `ValueError` · 상태 파일 읽기 실패는 stderr 한 줄과 rc 2.
- [ ] **Step 4: 통과를 본다** — 같은 명령 · Expected: OK.
- [ ] **Step 5: 레포 락을 돌린다** — `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep '§6단일화'` · `(cd plugins/quality-gates/tests && python3 -m unittest -q test_utf8_explicit)` · `bash shared/tests/test_python_floor.sh` · `bash shared/tests/test_no_new_duplication.sh`. Expected: §6단일화 줄이 모두 ok, 나머지 통과.
- [ ] **Step 6: 커밋** — `git add plugins/spec-distill/scripts/raw_source.py plugins/spec-distill/tests/test_raw_source.py && git commit -m "feat(spec-distill): 원자료를 찾는 모듈 — 찾는 길과 판결 한 곳" -- <두 경로>`

---

### Task 3: seed 문법이 가림 표시를 받는다(AC13)

**Files:**
- Modify: `plugins/spec-distill/scripts/seed_body.py`(`line_problem` 의 꺾쇠 검사 · 머리 docstring 「줄 안」 항목)
- Modify: `plugins/spec-distill/tests/grammar_vs_markdown_it_check.py`(`seed_structure_lines`)
- Create: `plugins/spec-distill/tests/test_seed_body_placeholder.py`

**Interfaces:**
- Consumes: `brief_body.P21_PLACEHOLDER_RE`(모듈 위에서 import — `brief_body` 는 `seed_body` 를 import 하지 않는다).
- Produces: `seed_body.line_problem(line)` 이 줄 **안**(줄 머리 다음)의 가림 표시를 산문으로 본다. 줄 머리 판정 · URL · 문자 참조 · 도메인 · 대괄호 검사는 가리기 전 글자로 그대로 한다.

`line_problem` 에서 `"[" in f or "]" in f or ANGLE_RE.search(f)` 만 가림 표시 자리를 같은 길이의 `x` 로 바꾼 줄(접기 전에 바꾸고 같은 `fold_for_match(...).casefold()` 를 거친 것)로 잰다. docstring 의 「줄 안」 항목에 한 문장: 「가림 표시(`brief_body.P21_PLACEHOLDER_RE` — `<REDACTED>` · `<REDACTED:라벨>` 등)는 줄 안에서 받는다 — 줄 머리의 `<` 는 지금처럼 거부한다.」

마크다운 파서는 `<REDACTED>` 를 인라인 HTML 로, `<REDACTED:라벨>` 을 자동 링크로 읽는다(보이는 글자는 같다). 교차 확인이 그 둘을 구조로 세지 않게, `seed_structure_lines` 는 인라인 자식이 `html_inline` 이고 내용이 `P21_PLACEHOLDER_RE` 에 `fullmatch` 하는 것과, `link_open`(markup `autolink`) 다음 `text` 자식의 내용을 `<…>` 로 감싼 것이 `fullmatch` 하는 것을 구조에서 뺀다. 그 밖의 `html_inline` · 링크는 그대로 센다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
ACCEPT = ["값은 <REDACTED> 로 가렸다.", "키 <REDACTED:api-key> 를 썼다.", "토큰 <TOKEN:깃허브> 이 있다.",
          "비밀 <SECRET_x> 이다.", "열쇠 <KEY-a.b> 다.", "접속 <CREDENTIAL:db> 다.", "자리 <PLACEHOLDER:x> 다."]
REJECT = ["<REDACTED> 로 시작한다.", "앞 <redacted> 뒤", "앞 <REDACTED: 공백> 뒤", "앞 <REDACTEDX> 뒤",
          "앞 <b>굵게</b> 뒤", "앞 <https://x.y> 뒤", "- <REDACTED> 목록", "앞 [<REDACTED>](x) 뒤",
          "앞 <REDACTED:www.x> 뒤"]
class Placeholder(unittest.TestCase):
    def test_accept(self):   # 각 줄: seed_body.line_problem(line) is None
    def test_reject(self):   # 각 줄: line_problem(line) is not None
    def test_gate_and_marks(self):
        # seed 본문 "문장 하나.\n\n키 <REDACTED:api-key> 를 썼다.\n" 로 check_seed.gate 가 「산문이 아닌 구조」 없이 통과하고,
        # seed_provenance marks 가 rc 0 이다(audit 은 test_seed_grammar_crosscheck.AUDIT 꼴)
```

`grammar_vs_markdown_it_check.py`: `SEED_CASES` 에 `("가림 표시 둘레의 진짜 HTML", "앞 <REDACTEDX> 뒤")` 를 더하고, 새 `test_placeholder_is_not_structure` — 본문 `"문장 하나.\n\n키 <REDACTED:api-key> 와 <REDACTED> 를 썼다.\n"` 에서 `self.check(text) == ([], set())`.

- [ ] **Step 2: 실패를 본다** — Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q test_seed_body_placeholder` · Expected: `test_accept` · `test_gate_and_marks` FAIL.
- [ ] **Step 3: `seed_body.line_problem` 과 교차 확인을 위대로 고친다.**
- [ ] **Step 4: 통과를 본다** — 같은 명령 + `bash plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh` + `python3 -m unittest -q test_seed_grammar_crosscheck` + `bash test_seed_edit_screen.sh` + `bash test_seed_edit_diff.sh` + `bash test_check_seed.sh` + `bash test_seed_trust_boundary.sh` + `bash test_seed_provenance.sh`(모두 `plugins/spec-distill/tests/`). Expected: 모두 통과(`test_grammar_vs_markdown_it.sh` 가 rc 3 「확인 못 함」 이면 그 사유를 보고한다).
- [ ] **Step 5: 커밋** — `feat(spec-distill): seed 문법이 줄 안의 가림 표시를 받는다`

---

### Task 4: CLAUDE.md 없는 레포에서도 seed 리뷰 번들을 조립한다(AC15)

**Files:**
- Modify: `plugins/spec-distill/scripts/build_seed_inline_blob.py`(`main` 의 존재 검사 · `assemble` · `heading_shaped_warnings` · 머리 docstring)
- Modify: `plugins/spec-distill/tests/test_seed_inline_blob.sh`

**Interfaces:**
- Produces: `CLAUDE_MD_ABSENT = "레포 CLAUDE.md 없음"` · `assemble(seed_text: str, audit_text: str, claude_md_text: str | None, consumer: str = "detect") -> str`(None 이면 `## 레포 CLAUDE.md` 절 본문이 `CLAUDE_MD_ABSENT` 한 줄) · `RECEIVED_SEPARATOR_RE = re.compile(r"^### 받은 글 — \S")`(Task 5 · 6 이 정하는 구분 줄 머리 — 글자를 바꾸면 Task 5 의 락이 함께 RED).

- `claude_md_file` 이 `os.path.lexists` 로 없으면 멈추지 않고 None 으로 조립하며 stderr 에 `[spec-distill] 경고: 레포 CLAUDE.md 가 없다(<경로>) — 번들의 그 절을 「레포 CLAUDE.md 없음」 한 줄로 채워 조립한다` 를 낸다. 있는데 파일이 아니면(끊긴 링크 · 폴더) 지금처럼 `claude_md_file not found: <경로>` 와 rc 2. seed · 기록 파일이 없을 때 멈추는 것은 그대로다.
- `heading_shaped_warnings` 는 `## 1. 원문` 절에서 `RECEIVED_SEPARATOR_RE` 에 맞는 줄을 경고에서 뺀다(`### 라운드 <n>` 을 `## 2` 에서 빼는 것과 같은 이유 — 정상 기록 파일마다 라운드마다 경고하면 신호를 잃는다). 그 밖의 제목 모양 줄은 그대로 경고한다.
- 부르는 skill 펜스(`request-framing/SKILL.md` 의 `### 번들`)는 고치지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_seed_inline_blob.sh` 의 「재료 부재 셋」 반복에서 `claude_md_file` 쌍을 빼고 아래를 더한다.

```bash
# CLAUDE.md 없음 — 멈추지 않고 그 사실을 번들에 글자로 남긴다(AC15)
out_nc="$(python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$TMP/nope.md" 2>"$TMP/e_nc.txt")"; rc=$?
assert_eq "$rc" "0" "CLAUDE.md 없음 → 조립한다"
assert_contains "$out_nc" "$(printf '## 레포 CLAUDE.md\n\n레포 CLAUDE.md 없음')" "번들에 「레포 CLAUDE.md 없음」"
assert_contains "$(cat "$TMP/e_nc.txt")" "[spec-distill] 경고: 레포 CLAUDE.md 가 없다(" "stderr 가 알린다"
ln -s "$TMP/gone-target.md" "$TMP/dangling.md"; mkdir -p "$TMP/claude-dir.md"
for bad in "$TMP/dangling.md" "$TMP/claude-dir.md"; do   # 깨진 것은 없는 것이 아니다
  python3 "$SCRIPT" "$TMP/seed.md" "$TMP/seed.audit.md" "$bad" >/dev/null 2>&1; assert_eq "$?" "2" "$(basename "$bad") → exit 2"
done
# 임시 git 레포(CLAUDE.md 없음)의 루트에서 skill 펜스와 같은 인자 `CLAUDE.md` 로 → rc 0 · 「레포 CLAUDE.md 없음」
# 구분 줄은 경고하지 않고, 다른 제목 모양 줄은 경고한다(양성 짝)
#   ## 1 에 「### 받은 글 — 직접 친 글 · 사용자 · 2026-11-17 · 라운드 2 의 답」 → stderr 에 「heading-모양」 없음
#   ## 1 에 「### 다른 제목」 → stderr 에 「heading-모양」 있음
```

- [ ] **Step 2: 실패를 본다** — Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_seed_inline_blob.sh` · Expected: 새 단언들 ✗.
- [ ] **Step 3: `build_seed_inline_blob.py` 를 위대로 고치고 머리 docstring 의 「재료 여섯」 문단에 「레포 CLAUDE.md 가 없으면 그 절을 「레포 CLAUDE.md 없음」 한 줄로 채운다(있는데 파일이 아니면 rc 2)」 를 더한다.**
- [ ] **Step 4: 통과를 본다** — 같은 명령 + `bash plugins/spec-distill/tests/test_seed_gate_wiring.sh` + `bash plugins/spec-distill/tests/test_seed_cut_table.sh` + `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep '§6단일화'`. Expected: 통과.
- [ ] **Step 5: 커밋** — `fix(spec-distill): CLAUDE.md 없는 레포에서도 seed 리뷰 번들을 조립한다`

---

### Task 5: 기록 파일 템플릿 · seed 템플릿 · seed 입력 규약 · seed 프로필(AC3 · AC4 · AC14 · AC20 의 이 계획 몫)

**Files:**
- Modify: `plugins/spec-distill/templates/interview-seed-audit-template.md`(`## 1` · `## 2` 설명과 답 줄)
- Modify: `plugins/spec-distill/templates/interview-seed-template.md`(머리)
- Modify: `plugins/spec-distill/skills/pm-interview/references/seed-input.md`(첫 문단 · S1 항목의 끝 문장)
- Modify: `plugins/spec-distill/references/docreview-profiles/seed.md`(층 1 끝에 문단 하나 — 보안 리뷰 대상)
- Create: `plugins/spec-distill/tests/test_framing_raw_source.sh`(100755 · `# guards:` 머리와 `--emit-scanned`)

**Interfaces:**
- Produces(계획 2 의 brief 프로필 문장과 Task 6 이 같은 글자를 쓴다):
  - 답 줄 꼴: `  - 당신이 답한 것 (<라벨 | 적음 | 라벨 · 적음>): <…>` — 답이 없으면 표시 없이 `  - 당신이 답한 것: «(답 없음)»`.
  - 구분 줄 꼴: `### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`, 갈래 = 직접 친 글 · 붙여 넣은 글 · 다른 세션이 넘긴 글.
  - 테스트 함수 `framing_fails <SKILL> <감사 템플릿> <seed 템플릿> <seed-input> <seed 프로필>` — 실패한 항목 이름을 한 줄씩 낸다(Task 6 · 7 이 항목을 더한다).

템플릿 `## 1` 설명(괄호 문단 전체를 이것으로 바꾼다 — 줄 머리에 `#` 를 두지 않는다):

```
(사용자가 준 글 — 요청 · 생각 · 대화 로그 · 자료를 받은 글자 그대로 옮긴다. 질문 라운드에서 직접 적은 답도
 줄 나눔을 접지 않은 글자 그대로 이 절 끝에 덧붙인다(고른 라벨만 있는 답은 덧붙이지 않는다).
 **append-only**: 이후 라운드에서 나온 글도 요약하지 않고 여기에 계속 덧붙인다 — 지금 요약하면 압축이 무엇을 떨어뜨렸는지 이 절이 못 남긴다.
 허용 변환은 둘이다 — token · key · credential 로 보이는 값은 쓰기 전에 가림 표시(`<REDACTED>` · `<REDACTED:라벨>` 등)로 바꾸고,
 절 제목과 같은 줄이나 `### ` 로 시작하는 줄은 사용자가 고르면 그 줄 앞에 `> ` 만 붙인다.
 저자가 쓸 수 있는 줄은 받은 글마다 그 바로 앞에 두는 구분 줄 하나뿐이다 — `### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`
 (갈래는 직접 친 글 · 붙여 넣은 글 · 다른 세션이 넘긴 글). 설명 문장을 따로 두지 않는다. 그 밖의 줄은 전부 받은 글자 그대로다.
 `### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다.)
```

템플릿 `## 2`: 설명 괄호 문단 끝에 「«당신이 답한 것» 줄의 괄호 표시는 출처다 — `(라벨)` 은 선택지 라벨을 골랐다, `(적음)` 은 직접 적었다, `(라벨 · 적음)` 은 둘 다이고 고른 라벨을 앞에 적는다. 「라벨」 이 붙은 답은 사용자가 고른 모델 문장이다. 풀이 줄의 「고름」 · 「고르지 않음」(풀이를 확인했는가)과 다른 축이고, 추가 라운드 승인의 `label` · `typed` 와 같은 뜻이다.」 를 더하고, 답 줄을 `  - 당신이 답한 것 (<라벨 | 적음 | 라벨 · 적음>): <고른 라벨 또는 적은 말 — one-line 을 거친 그대로, 답이 없으면 표시 없이 «(답 없음)»>` 로 바꾼다. 풀이 줄(`- 내가 읽은 것: …`)은 바꾸지 않는다.

seed 템플릿: 머리 인용 두 줄 뒤에 빈 줄과 `seed 는 다음 세션의 첫 턴에 넘기는, 모델이 줄인 글이다. 사용자의 말은 기록 파일(audit)의 원자료다.` 한 줄(문단).

seed-input.md: 첫 문단의 「그것은 **Phase 0 에서 사용자가 확정한 메시지**다.」 를 「그것은 **다음 세션의 첫 턴에 넘기는, 모델이 줄인 글**이다. 사용자의 말은 seed 옆 기록 파일(audit)의 원자료다.」 로 바꾸고, S1 항목 끝의 「그것이 이 세션의 최초 사용자 발화다.」 를 지운다(S1 규약 자체는 계획 2 가 바꾼다 — 「§6 `S1` 은 「풀린 입력」 원문 그대로다」 는 남긴다). 출처 · 확인 표와 분류기 문단은 diff 가 없다.

seed 프로필: `## 층 2` 바로 앞에 문단 하나(앞뒤 빈 줄):

```
**원문 줄을 읽는 법** — 원문 절(`## 1. 원문`)에서 `### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다. `## 2. 질문 전체` 의 «당신이 답한 것» 줄에 「라벨」 표시가 붙은 답은 사용자가 고른 모델 문장이다 — 고른 사실과 그 뜻은 정답이지만, 라벨의 낱말 하나하나는 사용자가 쓴 글이 아니다. 「라벨 · 적음」 이 붙은 답에서는 고른 라벨이 모델 문장이고 그 뒤의 적은 말은 사용자의 글이다 — 적은 말은 `## 1. 원문` 끝에도 글자 그대로 있다.
```

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_framing_raw_source.sh` 에 `framing_fails` 와 그 호출(실제 파일 → 빈 출력이면 ok)과 변이 검사를 둔다. 이 Task 의 항목(이름 — 무엇을 본다):
  - `tpl_redaction` — 감사 템플릿 `## 1` 절(`awk` 로 `## 1. 원문` ~ `## 2. 질문 전체`)에 `token · key · credential 로 보이는 값은 쓰기 전에 가림 표시` 가 있다(AC3).
  - `tpl_separator` — 같은 절에 `` `### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]` `` · `설명 문장을 따로 두지 않는다` · `그 밖의 줄은 전부 받은 글자 그대로다` · `` `### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다 `` 가 있다(AC20).
  - `tpl_separator_regex` — 템플릿의 구분 줄 머리가 `build_seed_inline_blob.RECEIVED_SEPARATOR_RE` 에 맞는다(`### 받은 글 — 직접 친 글` 로 잰다).
  - `tpl_answer_mark` — `## 2` 절에 답 줄 꼴(위 글자 그대로)과 `` `(라벨)` `` · `` `(적음)` `` · `` `(라벨 · 적음)` `` 가 있고, 풀이 줄 `- 내가 읽은 것: 「<풀이 문장>」 — <고름 | 고르지 않음>` 이 그대로다(AC4).
  - `seed_role` — seed 템플릿과 seed-input.md 가 각각 위 문장을 갖고, seed-input.md 에 `사용자가 확정한 메시지` · `그것이 이 세션의 최초 사용자 발화다` 가 없다(AC14 — 양의 짝과 부정 짝).
  - `profile_sep` · `profile_label` · `profile_mixed` — seed 프로필 본문에 위 문단의 세 문장이 각각 글자 그대로 있다(AC4 · AC20).
  - 변이(각 변이가 그 이름으로 실패해야 한다 — 임시 사본에서 첫 출현만 바꾼다): 템플릿의 `쓰기 전에 가림 표시` → `쓴 뒤 가림 표시`(`tpl_redaction`) · 구분 줄 머리 `### 받은 글 — ` → `### 받은글 — `(`tpl_separator`) · `(라벨 · 적음)` 삭제(`tpl_answer_mark`) · seed-input 을 옛 문장으로 되돌림(`seed_role`) · 프로필의 「라벨」 문장 삭제(`profile_label`).
- [ ] **Step 2: 실패를 본다** — Run: `chmod +x plugins/spec-distill/tests/test_framing_raw_source.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_framing_raw_source.sh` · Expected: ✗ 들.
- [ ] **Step 3: 네 파일을 위 글자대로 고친다.**
- [ ] **Step 4: 통과를 본다** — 같은 명령 + `bash shared/tests/test_docreview_profiles.sh` + `bash shared/tests/test_docreview_profile_schema.sh` + `bash plugins/spec-distill/tests/test_seed_input_provenance.sh` + `bash plugins/spec-distill/tests/test_distortion_devices.sh` + `bash plugins/spec-distill/tests/test_framing_review_contract.sh` + `python3 -m unittest -q test_r2_bypass_residue`(tests 폴더) + `bash plugins/spec-distill/tests/test_grammar_vs_markdown_it.sh`. Expected: 통과. `git diff HEAD -- plugins/spec-distill/references/docreview-profiles/seed.md` 가 더한 줄만이다.
- [ ] **Step 5: 커밋** — `docs(spec-distill): seed 를 모델이 줄인 글로 — 기록 파일 템플릿 · seed 프로필의 읽는 법`

---

### Task 6: framing skill — 비밀값 가리기 · 답 줄 표시 · 직접 적은 답 · 구분 줄 · 겹침 물음(AC3 · AC4 · AC5 · AC6 · AC20)

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(`## 확산` 1 · 새 절 `### 비밀값 가리기 — 사용자의 말을 쓰기 전에` · `**기록**` 문단 · `### 절차` 의 추가 라운드 줄 · 「사용자 문구 · 리뷰어 요약은 셸 인자에 직접 쓰지 않는다」 문단)
- Modify: `plugins/spec-distill/tests/test_framing_raw_source.sh`

**Interfaces:**
- Consumes: Task 5 의 답 줄 꼴 · 구분 줄 꼴 · `framing_fails`.
- Produces: 가리킴 글자 `` 쓰기 전에 `### 비밀값 가리기` 대로 가린다 `` · 보고 줄 꼴 `` `비밀값으로 보여 가린 곳 <N>개 — <라벨들>` ``.

새 절(「**질문에도 라운드에도 분량에도 상한이 없습니다.**」 문단 뒤, `### 확인 질문` 앞):

```
### 비밀값 가리기 — 사용자의 말을 쓰기 전에

사용자의 말이 audit 이나 사용자 문구 파일에 들어가는 길은 여덟이다.

- `## 1. 원문` 의 받은 글(주제 질문의 답 포함)
- 질문 라운드에서 직접 적은 답 — `## 1. 원문` 끝에 덧붙이는 글
- `## 2. 질문 전체` 의 «당신이 답한 것» 줄과 «사용자가 적은 말» 칸(`said-r<n>.txt`)
- 결정 답과 거부 줄의 사용자 문구(`said-<id>.txt`)
- 막지 않는 질문의 답(`said-<id>.txt`)
- 덩어리 처분 답(`said-hunk-<k>.txt`)
- 추가 라운드 승인(`said-extra-r<n>.txt`)
- 제목 줄 겹침 물음의 선택과 문구 — `## 5. degrade` 한 줄

어느 길이든 쓰기 **전에** token · key · credential 로 보이는 값을 가림 표시로 바꾼다. 표시는 `<REDACTED>` 또는
`<REDACTED:라벨>` 이고(다른 허용 형태: `<SECRET:...>` · `<TOKEN:...>` · `<KEY:...>` · `<CREDENTIAL:...>` · `<PLACEHOLDER:...>`),
인터뷰의 「Secret 기록 금지」 문단과 같은 집합이다 — 다른 꼴로 바꾸면 뒤 단계의 원문 대조가 그 자리를 알아보지 못한다.
가린 곳이 있으면 그 쓰기 뒤 사용자에게 보이는 다음 글(라운드 보고 또는 게이트 앞 글)에
`비밀값으로 보여 가린 곳 <N>개 — <라벨들>` 한 줄을 싣는다 — 가린 값 자체는 보이지 않는다. 가린 것이 없으면 그 줄을 내지 않는다.
seed 는 가린 audit 에서 압축하므로 seed 에도 가린 글만 간다. 가리는 것은 모델의 판단이다 — 찾는 스크립트는 없다.
```

`## 확산` 1(원문 보존) — 첫 문장 「…(append-only — 이후 라운드의 원문도 요약하지 않고 계속 덧붙입니다).」 바로 뒤에 `` 쓰기 전에 `### 비밀값 가리기` 대로 가린다. `` 를 넣고, 「…`## 1. 원문` 이라는 헤딩은 장식이 아닙니다」 문장 바로 앞에 아래를 넣는다(같은 목록 항목 안 — 세 칸 들여쓰기):

```
   받은 글마다 그 바로 앞에 구분 줄 하나를 둔다 — `### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`
   (갈래는 직접 친 글 · 붙여 넣은 글 · 다른 세션이 넘긴 글 가운데 하나). 원문 절 안에서 저자가 쓸 수 있는 줄은
   이 구분 줄뿐이다 — 설명 문장을 따로 두지 않고, 그 밖의 줄은 전부 받은 글자 그대로다. `### ` 로 시작하는 줄은
   저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다.
   **질문 라운드에서 직접 적은 답도 이 절에 남긴다** — «기타» 칸이나 자유 입력에 적은 답과 풀이 확인에서 적은 말은
   줄 나눔을 접지 않은 글자 그대로 `## 1` 끝(`## 2. 질문 전체` 줄 바로 앞)에 문단으로 덧붙이고, 그 앞에 구분 줄
   하나(갈래 「직접 친 글」 · 어느 라운드의 답인지)를 둔다. 구분 줄 말고는 저자의 줄을 더하지 않는다. 고른 라벨만
   있는 답은 덧붙이지 않는다. `## 2` 의 한 줄 칸은 지금처럼 줄 나눔을 접은 값이다.
   받은 글이나 덧붙일 답에 audit 절 제목과 앞뒤 공백을 뗀 글자가 같은 줄이 있거나 앞 공백을 뗀 머리가 `### ` 인 줄이
   있으면, 쓰기 전에 `### 번들` 아래 「audit 템플릿 절 제목이 중복되면」 의 물음과 같은 물음(「그 줄만 인용 표시로
   감싼다 (권장) / 멈춘다」)으로 받는다 — 「감싼다」면 그 줄 앞에 `> ` 만 붙여 쓴다. 저자가 그 줄을 스스로 고쳐 쓰지 않는다.
```

`**기록**` 문단 — 「…`seed_review_log.py one-line` 출력을 그 칸에 적습니다.」 바로 뒤에: 「«당신이 답한 것» 줄에는 출처 표시를 붙인다 — 선택지 라벨을 골랐으면 `(라벨)`, 직접 적었으면 `(적음)`, 둘 다면 `(라벨 · 적음)` 이고 고른 라벨을 앞에 적는다(템플릿의 줄 모양). 답이 없으면 표시 없이 «(답 없음)» 이다. 이 표시는 풀이 줄의 「고름」 · 「고르지 않음」(풀이를 확인했는가)과 다른 축이고, 추가 라운드 승인의 `label` · `typed` 와 같은 뜻이다. 쓰기 전에 `### 비밀값 가리기` 대로 가린다. 직접 적은 답은 `said-r<n>.txt` 를 한 줄로 잇는 펜스를 돌리기 전에 같은 글을 `## 1` 끝에 덧붙인다(`## 확산` 1).」

`### 절차` 의 추가 라운드 줄 — 「- 추가 라운드를 여는 1단계는 사용자 문구를」 뒤에 `(쓰기 전에 \`### 비밀값 가리기\` 대로 가린다)` 를 넣는다(그 줄의 `--extra-approval="$q" --extra-approval-source "$src"` 글자는 그대로).

「사용자 문구 · 리뷰어 요약은 셸 인자에 직접 쓰지 않는다」 문단 — 「…추가 라운드 승인은 `$STATE_DIR/said-extra-r<n>.txt` 다.」 바로 뒤에 `사용자 문구는 쓰기 전에 \`### 비밀값 가리기\` 대로 가린다 — 결정 답 · 거부 · 막지 않는 질문의 답 · 덩어리 처분 답 · 추가 라운드 승인이 모두 이 파일들을 거친다.`

`### 번들` 아래 「**audit 템플릿 절 제목이 중복되면**」 문단은 한 글자도 바꾸지 않는다(AC6).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `framing_fails` 에 항목을 더한다.
  - `secret_section` — 새 절 제목이 있다. `secret_path:<x>` — 그 절 본문에 `` `## 1. 원문` `` · `직접 적은 답` · `«당신이 답한 것»` · `«사용자가 적은 말»` · `` `said-r<n>.txt` `` · `` `said-<id>.txt` `` · `막지 않는 질문의 답` · `` `said-hunk-<k>.txt` `` · `` `said-extra-r<n>.txt` `` · `` `## 5. degrade` `` 가 각각 있다(AC3).
  - `secret_report_line` — 그 절에 `` `비밀값으로 보여 가린 곳 <N>개 — <라벨들>` `` 와 `가린 것이 없으면 그 줄을 내지 않는다` 가 있다.
  - `secret_tokens` — 그 절에서 뽑은 토큰 모양 집합(`<[A-Z]+(:[^>]*)?>`)이 인터뷰 본문 「Secret 기록 금지」 두 줄에서 뽑은 집합과 같고, 각 토큰(`...` 을 `x` 로 채운 것)이 `brief_body.P21_PLACEHOLDER_RE` 에 맞는다.
  - `secret_pointer:<자리>` — 네 자리(확산 1 항목 · `**기록**` 문단 · 추가 라운드 줄 · 셸 인자 문단 — 각각 그 첫 줄의 글자로 찾아 다음 빈 줄까지)에 `` 쓰기 전에 `### 비밀값 가리기` 대로 가린다 `` 가 있다.
  - `answer_mark` — `**기록**` 문단에 `` `(라벨)` `` · `` `(적음)` `` · `` `(라벨 · 적음)` `` · `추가 라운드 승인의 \`label\` · \`typed\` 와 같은 뜻이다` 가 있다(AC4).
  - `typed_append` — 확산 1 에 `**질문 라운드에서 직접 적은 답도 이 절에 남긴다**` · `줄 나눔을 접지 않은 글자 그대로` · `구분 줄 말고는 저자의 줄을 더하지 않는다` · `고른 라벨만` 다음 줄의 `있는 답은 덧붙이지 않는다`(줄을 이어 붙여 잰다)가 있다(AC5).
  - `separator_rule` — 확산 1 에 구분 줄 꼴 · `설명 문장을 따로 두지 않고` · `그 밖의 줄은 전부 받은 글자 그대로다` 가 있다(AC20).
  - `overlap_same_question` — 확산 1 에 `「audit 템플릿 절 제목이 중복되면」 의 물음과 같은 물음` · `앞 공백을 뗀 머리가 \`### \` 인 줄` 이 있다(AC6).
  - `overlap_unchanged` — 「**audit 템플릿 절 제목이 중복되면**」 문단(그 줄부터 「`### 번들` 부터 다시 돕니다.」 까지)이 계획 작성 때의 글자와 같다 — 테스트에 그 여섯 줄을 글자 그대로 둔다(AC6).
  - `self_rewrite` — SKILL 에 `스스로 고쳐 쓴다` 가 없고(부정) `저자가 그 줄을 스스로 고쳐 쓰지 않는다` 가 있다(양의 짝).
  - 변이: 셸 인자 문단의 가리킴 삭제(`secret_pointer:셸 인자`) · 절의 `` `<KEY:...>` `` → `` `<KEYS:...>` ``(`secret_tokens`) · 절 목록에서 `` `## 5. degrade` `` 줄 삭제(`secret_path`) · 「고른 라벨만 있는 답은 덧붙이지 않는다」 삭제(`typed_append`) · 겹침 문단의 `(권장)` 을 지움(`overlap_unchanged`) · 「저자가 그 줄을 스스로 고쳐 쓴다」 로 바꿈(`self_rewrite`).
- [ ] **Step 2: 실패를 본다** — `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_framing_raw_source.sh` · Expected: 이 Task 의 ✗.
- [ ] **Step 3: SKILL 을 위 글자대로 고친다.**
- [ ] **Step 4: 통과를 본다** — 같은 명령 + `bash shared/tests/test_ask_recommendation.sh` + `bash plugins/spec-distill/tests/test_framing_review_contract.sh` + `bash plugins/spec-distill/tests/test_seed_gate_wiring.sh` + `bash plugins/spec-distill/tests/test_ledger_wiring.sh` + `bash plugins/spec-distill/tests/test_request_framing_entry.sh` + `bash plugins/spec-distill/tests/test_state_dir_writes.sh` + `bash shared/tests/test_invocation_surface.sh` + `bash shared/tests/test_no_new_duplication.sh`. Expected: 통과.
- [ ] **Step 5: 커밋** — `feat(spec-distill): framing 이 사용자의 말을 쓰기 전에 비밀값을 가리고 고른 말과 쓴 말을 가른다`

---

### Task 7: framing 의 「다른 다음 단계」 운반 문장(AC22 의 이 계획 몫)

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`(`### 호출 모양` 의 「**다른 다음 단계(둘째 질문).**」 문단과 그 바로 뒤 펜스 하나)
- Modify: `plugins/spec-distill/tests/test_request_framing_open.sh`

**Interfaces:**
- Consumes: Task 2 의 `raw_source.py locate --seed` 와 판결 줄 `raw-source: FOUND <경로>`.

그 문단의 「평문 줄(외부 skill)이면 운반 문장에 「seed 전문을 … 입력으로 삼는다」를 싣고,」 를 아래로 바꾸고, 문단 바로 뒤에 펜스를 둔다. slash 줄 갈래(「slash 줄이면 운반 문장 없이 seed 경로만 넘긴다.」)와 문단의 나머지는 그대로다.

```
평문 줄(외부 skill)이면 운반 문장에 「seed(<seed 절대경로>)는 모델이 줄인 글이다 — 사용자의 말이 아니다. 사용자의 말은 framing 기록 파일 <기록 파일 절대경로> 의 원자료다(`## 1. 원문` 절에서 `### ` 로 시작하는 구분 줄을 뺀 전부 · `## 2. 질문 전체` 절의 «당신이 답한 것» 줄과 «사용자가 적은 말» 칸 · `## 6. 리뷰 결정` 절의 사용자 문구). 그 파일을 읽어 그 skill 의 사용자 원문(첫 요청)으로 삼는다」를 싣는다. `<기록 파일 절대경로>` 는 아래 펜스가 낸 마지막 줄 `raw-source: FOUND <경로>` 의 경로다 — 마지막 줄이 그 꼴이 아니면 그 줄을 보이고 다음 세션 줄을 노출하지 않는다.
```

```bash
# 다른 다음 단계 — framing 기록 파일의 자리. 앞에 「## 상태」 블록을 이어 붙인다.
python3 "$SD/scripts/raw_source.py" locate --seed "$SEED_ABS"
```

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_request_framing_open.sh` 의 `for lit in …` 목록에서 옛 문장을 새 운반 문장(「seed(<seed 절대경로>)는 모델이 줄인 글이다 — 사용자의 말이 아니다.」 부터 「사용자 원문(첫 요청)으로 삼는다」 까지 글자 그대로)과 `raw_source.py" locate --seed "$SEED_ABS"` · `` `raw-source: FOUND <경로>` 의 경로다 `` 로 바꾸고, `assert_not_contains "$CALL" 'seed 전문을 그 skill 의 사용자 원문(첫 요청 — 인터뷰의 S1 과 같은 자리)으로 삼아 원문 그대로 입력으로 삼는다' "AC22: 옛 운반 문장이 없다"` 를 더한다. 펜스 실행 단언: 임시 폴더에 seed · 기록 파일을 두고 `SD` · `SEED_ABS` 를 채워 그 펜스 본문을 `env -i PATH="$PATH" bash` 로 돌려 마지막 줄이 `raw-source: FOUND <그 기록 파일 절대경로>` 인지 본다.
- [ ] **Step 2: 실패를 본다** — `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_request_framing_open.sh` · Expected: ✗.
- [ ] **Step 3: SKILL 을 위 글자대로 고친다.**
- [ ] **Step 4: 통과를 본다** — 같은 명령 + `bash shared/tests/test_ask_recommendation.sh` + `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh` + `bash shared/tests/test_inline_python_isolated.sh`. Expected: 통과.
- [ ] **Step 5: 커밋** — `feat(spec-distill): 다른 다음 단계에 seed 를 줄인 글로, 원자료의 자리를 함께 넘긴다`

---

### Task 8: README · 변경 기록 · 판

**Files:**
- Modify: `plugins/spec-distill/README.md` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`

- README `Principles` 의 P21 줄(「**P21 (Secret 기록 금지 / untrusted input)**」)의 첫 문장을 「인터뷰 상태 파일(커밋되는 파일이다 — `## 풀린 입력` 블록 포함)과 framing 기록 파일(seed 의 audit — 원문 절 · 질문 답 · 사용자가 적은 말 · 리뷰 결정의 사용자 문구 등 사용자의 말을 적는 모든 길)의 token/key/credential placeholder 치환. seed 본문은 줄 안의 가림 표시를 받는다.」 로 바꾼다(뒤의 `audit_file` 문장은 그대로).
- README 스크립트 목록(`scripts/check_bundle_coverage.py` 줄 근처)에 「- `scripts/raw_source.py locate --seed <seed> | --interview <brief|상태 파일>` — 원자료(framing 기록 파일)를 찾는 길 한 곳. 마지막 줄 판결 `raw-source: FOUND <경로>` · `raw-source: NO-FRAMING`(종료 0) · `raw-source: LOST <사유>`(종료 3).」
- 판 = 머지 직전 기본 브랜치 판 위의 다음 minor. `plugin.json` 과 CHANGELOG 머리 `## [<그 판>] — <머지 날짜>`:

```
### Added
- 원자료를 찾는 길 한 곳 — `scripts/raw_source.py locate` 가 seed 나 인터뷰 경로를 받아 framing 기록 파일을 찾았는지 · framing 없는 인터뷰인지 · 찾지 못했는지(사유와 함께)를 낸다.

### Changed
- framing 이 사용자의 말을 기록 파일에 쓰기 전에 비밀값으로 보이는 값을 가리고, 가린 곳이 있으면 그 수와 라벨을 한 줄로 보인다.
- framing 기록의 답 줄이 고른 라벨과 직접 적은 말을 「라벨」 · 「적음」 표시로 가른다. 직접 적은 답은 원문 절에도 글자 그대로 남고, 원문 절의 저자 줄은 「### 받은 글 — 」 구분 줄 하나로 정해졌다.
- seed 는 「모델이 줄인 글」 로 다뤄진다 — 다른 다음 단계로 바로 갈 때 seed 와 함께 framing 기록 파일의 자리를 넘긴다. seed 본문은 줄 안의 가림 표시를 받는다.

### Fixed
- 레포에 CLAUDE.md 가 없으면 seed 리뷰가 멈추던 것 — 번들의 그 절을 「레포 CLAUDE.md 없음」 으로 채워 조립한다.
```

- [ ] **Step 1: 세 파일을 고친다.**
- [ ] **Step 2: 확인** — `bash shared/tests/test_changelog_integrity.sh` + `bash plugins/spec-distill/tests/test_roadmap_status.sh` + `python3 -m unittest -q test_team_docs`(tests 폴더) · Expected: 통과.
- [ ] **Step 3: 커밋** — `chore(spec-distill): 원자료 정본 사슬 계획 1 의 판 · 변경 기록 · README`

---

### Task 9: 이음매와 전체 스위트(AC16 · AC18)

**Files:** 없음(확인만).

- [ ] **Step 1: 옆 로드맵 파일의 diff 가 없다(AC16)** — Run: `git diff --stat "$(git merge-base HEAD origin/HEAD)" -- plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_check.py plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/scripts/seed_review_log.py plugins/spec-distill/scripts/check_seed.py plugins/spec-distill/scripts/seed_provenance.py plugins/spec-distill/scripts/interview_state.py plugins/spec-distill/scripts/seed_edit_screen.py plugins/spec-distill/scripts/seed_edit_diff.py` · Expected: 빈 출력.
- [ ] **Step 2: 옆 생성기 테스트와 경계 줄** — `bash plugins/spec-distill/tests/test_team_write.sh` + `(cd plugins/spec-distill/tests && python3 -m unittest -q test_team_files)` + `python3 -c 'import sys; sys.path.insert(0,"plugins/spec-distill/scripts"); import seed_review_log as s; assert s.AUDIT_HEADINGS[:3]==("## 1. 원문","## 2. 질문 전체","## 3. 긴 초안")'`. Expected: 통과.
- [ ] **Step 3: 전체 스위트(AC18)** — Global Constraints 의 잠금 줄(`--owner <이름>`)로 돈다. Expected: `FAILED` 줄이 기본 브랜치에도 있는 것뿐이다 — 이 브랜치에만 있는 실패가 0(머지 전 스위트 대조가 판정한다). 이 브랜치에만 있으면 고치고 다시 돈다.

---

### Task 10: 마지막 전체 리뷰 · AC 보고 · 묶음 대조

**Files:** `.claude/tmp/raw-source-canon-plan1-ac-report.md`(git 이 추적하지 않는다 — `git check-ignore -q` 로 확인).

- [ ] **Step 1: 마지막 전체 리뷰에 이 계획 몫의 AC 목록을 싣는다** — 리뷰어에게 설계문서 `## Acceptance Criteria` 의 AC1 AC3 AC4 AC5 AC6 AC13 AC14 AC15 AC16 AC18 AC20 AC21 AC22 원문과 위의 나눔(AC4 · AC20 · AC22 의 이 계획 몫)을 싣고, AC 마다 한 줄 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거>` 로 보고하게 한다. 나눠 갖는 AC 의 계획 2 몫은 「미룸 — 계획 2」 로 적게 한다. 끝에서 끝 흐름(framing 이 쓰는 기록 파일 → 번들 조립 → seed 문법 → 모듈의 판결 → 운반 문장)과 이 계획이 만든 사용자에게 보이는 글자를 함께 묻는다.
- [ ] **Step 2: 그 보고를 위 파일에 적는다.**
- [ ] **Step 3: 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다** — 계획 2 몫은 받는 곳 「F3 계획 2」 가 아니라 설계문서 `roadmap:` 의 로드맵에 있는 에픽이나 `#<n>` 이어야 한다(`check_bundle_coverage.py --impl` 규칙) — 그 이름은 지휘자에게 묻는다.
- [ ] **Step 4: PR 을 만들기 전에** `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-16-raw-source-canon-design.md .claude/tmp/raw-source-canon-plan1-ac-report.md` 를 돌려 경고를 사용자에게 보인다.
