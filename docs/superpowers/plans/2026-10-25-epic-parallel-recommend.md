# 에픽 병렬 권장 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 준비된 에픽이 진행 중인 에픽과 겹치지 않으면 지휘자가 작업 목록에서 그것을 보고 spec 승인 질문과 같은 호출에서 「병렬 (권장)」 · 「차례로」 를 묻고, 병렬로 가도 의도 손상 · 회귀를 잡는 안전망(이웃 결정 · 의도 대조 · 머지 하나씩)을 넓힌다.

**Architecture:** 계산은 있는 상태 계산(`roadmap_status.py`)의 보고만 읽는다 — 작업 목록 끝 줄(`control_plane.py`), 공유 파일 설정 키(`repo_defaults.py`), 이웃 결정(`spec_review_bundle.py`)은 그 보고를 거른다. 의도 대조 묶음은 새 모듈 `review_intents.py` 가 짓고 `conductor_ledger.py review-pack` 은 부르는 한 줄만 갖는다. 나머지는 지휘 절차 문서(`conducting.md` 등)의 문장과 그 문장을 재는 락이다.

**Tech Stack:** Python 3(표준 라이브러리 · unittest), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md`

## Global Constraints

- 레포 전용 값을 박지 않는다 — 공유 파일 목록은 레포 설정 파일(`.devbrew.md`)의 `shared_files`, 기본 브랜치 · 테스트 명령 · 모델은 `repo_defaults.py` 에서 읽는다. 테스트 픽스처는 기본 브랜치 `trunk` · 폴더 `plan/` 처럼 이 레포와 다른 값을 쓴다.
- 작업 목록 출력의 작업 줄(`<제목><탭><작업 상태>`) 모양은 그대로다. 새 줄은 탭이 없다.
- 새 줄은 작업 목록이 이미 읽는 것(로드맵 · git · 기계 상태의 PR 캐시) 밖을 읽지 않는다.
- 통합 리뷰어 프로필은 규칙을 더하는 쪽으로만 고친다 — 페르소나 편집이라 보안 리뷰 대상이다. 이음매 1~6 의 문구는 줄지 않는다.
- spec-distill 판 `8.10.0` → `8.11.0`(minor), CHANGELOG `## [8.11.0] — 2026-10-25`.
- 커밋은 Conventional Commits, 설명은 한국어(예: `feat(spec-distill): 작업 목록 끝에 병렬 판단 줄`). 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md`.
- 테스트는 `PYTHONDONTWRITEBYTECODE=1` 로 돈다. 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 가 `100755` 인지 본다. 셸에서 한글 바로 앞의 변수는 `${v}` 로 감싼다(bash 3.2). 새 파이썬 파일은 파일을 열 때 `encoding="utf-8"` 를 적는다.
- 사람에게 보이는 새 문면(출력 줄 · 경고)은 `clean()` 을 거치거나 한 줄이다. 설계문서가 정한 문면은 글자 그대로 쓴다.
- 전체 스위트: 레포 루트에서 `bash tools/suite/run-all.sh` — 실패 줄(`FAILED …`)이 없어야 한다.

## Review Focus

- `shared_files` 값의 빈 원소가 공백뿐이거나 끝 쉼표에서 생기는 경우(`a, , b` · `a,`) — 빈 원소로 보고 기본 셋과 경고를 낸다(Task 1 테스트).
- 로드맵 머리말과 레포 설정 파일에 `shared_files` 가 함께 있는 경우 — 레포 설정 값을 쓰고 로드맵 층 경고 한 줄, 상태 계산은 「검사 불가」 가 아니다(Task 1 테스트).
- 의도 대조에서 다른 에픽이 이 에픽 브랜치 위에 쌓인 브랜치(끝이 기준 커밋의 조상이지만 기본 브랜치에 안 들어감) — 빼지 않고 「열림」 으로 싣는다(Task 5 테스트).
- 의도 대조에서 다른 에픽 브랜치의 끝을 찾지 못하는 경우 — 확인하지 못했으니 함께 진행된 것으로 싣는다(Task 5 테스트).
- 결정 줄 정규식이 들여쓴 줄(`  - D1.1 · …`)이나 점 없는 `- D2 · …` 를 결정 줄로 읽는 경우 — 읽지 않는다(Task 4 테스트).

## 파일 구조

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `plugins/spec-distill/scripts/repo_defaults.py` | `shared_files` 키 · 파싱 · 층 경고 · `get` 출력 | 1 |
| `plugins/spec-distill/scripts/roadmap_status.py` | 해결된 공유 목록을 겹침 · 위반 알림에 넘김 · 겹침 대칭 | 2 |
| `plugins/spec-distill/scripts/control_plane.py` | `tasks_output` 끝 줄 | 3 |
| `plugins/spec-distill/scripts/spec_review_bundle.py` | 이웃에 동시 가능 에픽 · 결정 줄 셋 | 4 |
| `plugins/spec-distill/scripts/review_intents.py`(새) | `intents.md` 글 짓기 | 5 |
| `plugins/spec-distill/scripts/conductor_ledger.py` | `review-pack` 이 `intents.md` · README 줄을 씀 | 5 |
| `plugins/spec-distill/agents/integration-reviewer.md` · `skills/epic-conductor/SKILL.md` | 입력 칸 · 일곱째 이음매 · dispatch 칸 | 6 |
| `plugins/spec-distill/references/conducting.md` | 걸음 1 · 2 · 3 · 4 · 5, 손 절차 1 · 2 · 3 · 4 · 5 · 8 | 6 · 7 · 8 · 9 |
| `plugins/spec-distill/references/proceed-gate.md` · `skills/spec-review/SKILL.md` | 둘째 질문 한 문장 | 7 |
| `plugins/spec-distill/references/epic-handoff.md` · `references/conductor-dispatch.md` | 조사 문장 | 9 |
| `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `references/roadmap-ontology.md` | 설정 표 · 판 · 키 수 | 10 |
| `plugins/spec-distill/tests/test_parallel_recommend.py`(새) | 코드 동작 테스트(실제 git 픽스처) | 1~5 |
| `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`(새) | 절차 문장 본문 고유 문구 락 | 6~9 |

## AC 대응

| AC | 과제 |
|---|---|
| AC1 · AC2 | 3 |
| AC3 | 7 |
| AC4 | 1 · 2 · 10 |
| AC5 | 2 |
| AC6 · AC7 · AC8 | 7 |
| AC9 | 4 |
| AC10 | 5 |
| AC11 | 6 |
| AC12 · AC13 | 8 |
| AC14 | 9 |
| AC15 | 각 과제의 테스트 · 락 + 11 의 변이 |
| AC16 | 10 |

## 설계문서 「계획으로 미룬 것」 처리

| 항목 | 처리 |
|---|---|
| 44751ea8#r1.1 · 00f4602b#r2.1(삭제 전후 동일성 범위) | 설계문서가 이미 좁혔다 — Task 3 의 e2e 2b 가 PR 캐시가 단계를 바꾸지 않는 상태에서 잰다 |
| 73f9f01d#r1.1(「차례로」 를 보내는 모든 자리) | Task 7 — 정의 한 곳 · 가리킴 다섯 · 락 |
| 1cc82fb4#r2.1 · 5b1a839c#r3.1(따옴표) | Task 1 테스트 `test_quoted_whole_value_with_hash` · Task 10 README 문장 — 값 전체를 감싼다 |
| b0fc77d1#r2.1(빼는 근거) | 설계문서가 이미 고쳤다 — 계획 몫 없음 |
| 85296326#r2.1(시각 · 답 없음) | Task 7 — 줄에 시각, 닿는 답이 없으면 기본(병렬) |
| b2fe9225#r2.1(닫힌 PR · 다른 순서) | Task 8 — 「그 명령 줄을 거두고」 문장 |
| fccf272b#r2.1(AC6 와 본문) | 설계문서가 이미 맞췄다 — Task 7 락이 선택지 설명이 게이트 정본 · SKILL 에 없음을 잰다 |
| df16d9e9#r3.1(과설계 — 설계를 시작한 에픽 모두 싣기) | 받지 않는다 — 지난 로드맵(에픽 20)의 설계문서를 합치면 1.27MB(2026-10-25 실측)라 천장(리뷰어 한 번이 읽을 양)을 이미 넘는다. 결정 D2.2 그대로 |
| 73eeddd3#r3.1(일부 머지 · 다음 브랜치 없음) | Task 5 규칙 4 — `tip` 이 없으면 기본 브랜치에서 읽는다 |
| 0b618227#r3.1(산출물 · 갈라진 점 길의 수용 기준) | Task 5 — 상태 계산 `specs` 가 산출물을 담아 같은 길을 타고, 갈라진 점 길은 첫 줄 · 경고로 낸다 |
| 빈 집합 대 D2.6 | Task 7 — 지금 집합이 비었으면 다시 쓰기를 하지 않고 진행 중 에픽 갈래만 본다 |
| AC11 락 | Task 6 · Task 11 변이 |

---

### Task 0: 다시 확인(가벼운)

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 본다. 다르면 멈추고 보고한다(고치지 않는다).

- [ ] **Step 1: 근거 자리 확인**

| 근거 | 확인할 것 |
|---|---|
| `roadmap_status.py` | `SHARED_BASENAMES = ("plugin.json", "CHANGELOG.md", "README.md")` · `_shared(path)` · `overlaps` 가 `not _shared(ea)` 만 본다 · `parallel_with` 가 `DONE` 을 뺀다 · `build` 가 `resolve(...)` 뒤에 `overlaps` 를 부른다 |
| `control_plane.py` | `tasks_output(items, select_error=None)` 가 `(줄들, 표준 오류 글, rc)` 를 낸다 |
| `repo_defaults.py` | `KEYS` 아홉 · `check_layer` 가 층 밖 키를 `layer_key` 로 낸다 · `merge_layers` 의 `parallel_default` 경고 길 |
| `spec_review_bundle.py` | `DECISION_LINE_RE = re.compile(r"- B\d+ · 결정 · ")` · `neighbors` 의 `near` |
| `conductor_ledger.py` | `c_review_pack` 이 `pr.diff` · `open-*.diff` · `conflicts.txt` · `handoffs.md` · `README.txt` 를 쓴다 · `_status(root, roadmap)` 가 상태 계산 JSON 을 낸다 |
| `conducting.md` | 지휘 순환 걸음 1~7, 손 절차 1~9 · 걸음 2 와 손 절차 2 의 「섞지 않고」 문장 |
| `proceed-gate.md` | 「지휘자 아래 승인 질문에는 둘째 질문이 없다(에픽의 흐름은 로드맵 `흐름:` 칸이 정한다).」 |

Run: 각 파일을 읽는다. Expected: 표대로다. 다르면 무엇이 다른지 보고하고 멈춘다.

---

### Task 1: 공유 파일 설정 키 `shared_files`

**AC:** AC4

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`
- Create: `plugins/spec-distill/tests/test_parallel_recommend.py`
- Modify: `plugins/spec-distill/tests/test_workspace_invariance.sh`(키 목록에 `shared_files` · 주석의 「아홉」 → 「열」)

**Interfaces:**
- Produces: `repo_defaults.SHARED_FILES: tuple = ("plugin.json", "CHANGELOG.md", "README.md")`; `KEYS` 끝에 `"shared_files"`; `merge_layers(...)["values"]["shared_files"]` 는 `tuple[str, ...]`(늘 채워짐 — 없거나 깨지면 `SHARED_FILES`); `get shared_files` 는 `", ".join(값)` 한 줄을 낸다.
- 층: 레포 설정 파일만 읽는다. 로드맵 머리말 · 기계 상태 층에 있으면 `check_layer` 전에 그 층 사본에서 빼고 `warnings` 에 한 줄 — 오류(`errors`)가 아니다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_parallel_recommend.py` 에 `class SharedFilesSetting(unittest.TestCase)`(머리: `sys.path` 에 scripts 를 넣고 `import repo_defaults as rd`).

```python
DEFAULT = ("plugin.json", "CHANGELOG.md", "README.md")

def merged(roadmap=None, repo=None, machine=None):
    return rd.merge_layers(roadmap, repo, "레포 설정@0123abcd" if repo is not None else None, machine, [])

def test_absent_is_default(self):
    m = merged(repo={})
    self.assertEqual(m["values"]["shared_files"], DEFAULT)
    self.assertEqual(m["errors"], [])

def test_value_is_parsed(self):
    m = merged(repo={"shared_files": "plugin.json, CHANGELOG.md, NOTICE"})
    self.assertEqual(m["values"]["shared_files"], ("plugin.json", "CHANGELOG.md", "NOTICE"))
    self.assertEqual(m["warnings"], [])

def test_broken_values_fall_back_with_warning(self):
    for bad in ("", "a, , b", "a,", "docs/README.md, b"):
        m = merged(repo={"shared_files": bad})
        self.assertEqual(m["values"]["shared_files"], DEFAULT, bad)
        self.assertEqual(m["errors"], [], bad)
        self.assertTrue(any("shared_files" in w for w in m["warnings"]), bad)

def test_roadmap_and_machine_layer_are_ignored_with_warning(self):
    for layer in ("roadmap", "machine"):
        kw = {layer: {"shared_files": "X.md"}, "repo": {"shared_files": "Y.md"}}
        m = merged(**kw)
        self.assertEqual(m["errors"], [], layer)
        self.assertEqual(m["values"]["shared_files"], ("Y.md",), layer)
        self.assertTrue(any("shared_files" in w for w in m["warnings"]), layer)

def test_quoted_whole_value_with_hash(self):
    meta = rd.strict_frontmatter('---\nshared_files: "note #1.md, README.md"\n---\n', "repo")
    m = merged(repo=meta)
    self.assertEqual(m["values"]["shared_files"], ("note #1.md", "README.md"))
```

`get` CLI: 임시 git 레포(기본 브랜치 `trunk`, origin bare, `remote set-head origin --auto`)에 `.devbrew.md`(`---\nshared_files: a.md, b.md\n---\n`)를 커밋 · push 하고 `repo_defaults.py get shared_files --root <레포>` 의 표준 출력이 `a.md, b.md\n`, rc 0 인지 보는 `test_get_prints_comma_list` 를 더한다.

- [ ] **Step 2: 실패를 본다** — Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py -v` Expected: FAIL(`KeyError: 'shared_files'` 등).

- [ ] **Step 3: 구현** — `repo_defaults.py`:
  - `SHARED_FILES` 상수 · `KEYS` 에 `shared_files` · `_DEFAULTS["shared_files"] = SHARED_FILES`.
  - `_shared_files(raw: str) -> tuple[tuple | None, str | None]` — `_unquote` 뒤 쉼표로 나누고 원소마다 앞뒤 공백 · 따옴표를 벗긴다. 값이 비었거나 빈 원소가 있거나 원소에 `/` 가 있으면 `(None, 사유)`.
  - `merge_layers` 첫머리: `roadmap` · `machine` 이 `shared_files` 를 가지면 그 키를 뺀 사본으로 바꾸고 `warnings` 에 `"%s: shared_files 는 레포 설정 파일(%s)에서만 읽는다 — 이 값은 무시하고 레포 설정 값(없으면 기본 셋)을 쓴다" % (자리, SETTINGS_FILE)`.
  - 키 루프의 `shared_files` 갈래: 깨졌으면 `SHARED_FILES` · 출처 `"기본값(머리말 값이 깨졌다)"` · 경고 `"%s: 공유 파일 목록은 경로 없는 파일 이름의 한 줄 쉼표 목록이다(shared_files: %r — %s) — 기본 셋(%s)을 쓴다"`.
  - `main` 의 값 출력 두 자리: 값이 tuple 이면 `", ".join(value)` 를 낸다.
  - `test_workspace_invariance.sh` 의 `KEYS=` 에 `shared_files` 를 더하고 주석 · 메시지의 「아홉 키」 를 「열 키」 로.

- [ ] **Step 4: 통과를 본다** — Run: Step 2 명령 · `bash plugins/spec-distill/tests/test_workspace_invariance.sh` · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py` Expected: 모두 PASS(실패 0).

- [ ] **Step 5: 커밋** — `git add` 위 세 파일 → `git commit -m "feat(spec-distill): 레포 설정 키 shared_files" -m "Spec: docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md"`

---

### Task 2: 상태 계산 — 해결된 공유 목록 · 겹침 대칭

**AC:** AC4 · AC5 · AC15

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py`
- Modify: `plugins/spec-distill/tests/test_parallel_recommend.py`

**Interfaces:**
- Consumes: Task 1 의 `settings["shared_files"]`(tuple).
- Produces: `_shared(path: str, names=SHARED_BASENAMES) -> bool`; `overlaps(blocks: list, names=SHARED_BASENAMES) -> list`(기본 인자로 옛 호출은 그대로); `compute(...)` 의 예약 위반 알림과 `build` 의 `overlaps(...)` 가 `settings.get("shared_files") or SHARED_BASENAMES` 를 쓴다. `SHARED_BASENAMES` 는 `repo_defaults.SHARED_FILES` 를 가리킨다.
- 대칭: 짝 `(ea, eb)` 가운데 하나라도 공유 파일이면 그 짝은 겹침이 아니다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

(a) 단위 — `class Overlaps(unittest.TestCase)`:

```python
def blocks(a_res, b_res):
    return [{"id": "A", "deps": [], "reserved": a_res}, {"id": "B", "deps": [], "reserved": b_res}]

def test_folder_and_shared_file_either_order(self):
    for a, b in ((["plugins/x/"], ["plugins/x/README.md"]), (["plugins/x/README.md"], ["plugins/x/"])):
        self.assertEqual(rs.overlaps(blocks(a, b)), [], (a, b))

def test_two_folders_still_overlap(self):
    self.assertEqual([o["blocks"] for o in rs.overlaps(blocks(["plugins/x/"], ["plugins/x/sub/"]))], [["A", "B"]])

def test_names_argument(self):
    self.assertEqual(rs.overlaps(blocks(["p/NOTICE"], ["p/NOTICE"]), names=("NOTICE",)), [])
    self.assertEqual(len(rs.overlaps(blocks(["p/README.md"], ["p/README.md"]), names=("NOTICE",))), 1)
```

(b) 실제 git 픽스처 — 이 파일에 `class RoadmapRepo(unittest.TestCase)` 를 둔다(Task 3~5 가 같이 쓴다):
  - `setUp`: 임시 폴더에 bare origin(`-b trunk`) · 클론 `self.w` · `checkout -B trunk`. `plugins/spec-distill/tests/fixtures/conductor-e2e/` 의 `b.md` · `b.audit.md` 를 `plan/br/` 로 복사. git 은 `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1` · `-c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false`.
  - `roadmap(self, blocks: list[tuple[str, list[str], str, tuple[str, ...]]], settings: str | None = None) -> None` — 블록마다 `(id, deps, reserved, ids)`. 로드맵 `plan/rm/roadmap.md` 를 `conductor-e2e/roadmap.md` 의 머리말(`source_brief: plan/br/b.md` · `specs_dir: plan/specs/` · `plans_dir: plan/plans/`)과 블록 꼴로 쓴다 — 블록 칸: `의도` · `범위`(한다 · 안 한다) · `의존`(없으면 `없음`) · `브랜치: work/<id 소문자>` · `묶음: <id>.md` · `경로 예약`(없으면 `없음`, 여럿이면 쉼표). 묶음 `plan/rm/<id>.md` 는 `conductor-e2e/E1.md` 꼴에 `epic: <id>` · `ids: [<ids>]`. 위험 번호표는 `- K1 — 위험 — 숨은 가정: 버릴 가정 — 근거 없음`. 번호 다섯(`C1` · `S1` · `OQ1` · `«e2e-k»` · `K1`)을 모두 어딘가의 묶음에 나눠 싣는다. `settings` 가 있으면 `.devbrew.md` 로 쓴다. 커밋 · push · `remote set-head origin --auto`.
  - `start_design(self, epic: str, extra: str = "", base: str = "origin/HEAD") -> str` — `git worktree add <임시>/<id> -b work/<id> <base>` 뒤 `plan/specs/<id>-design.md`(frontmatter `source_interview: plan/rm/<id>.md` · `roadmap: plan/rm/roadmap.md`, 본문 `# <id> 설계` · `## Goals` · `- <id> 목표` · `## 결정 기록` + `extra`) 를 커밋하고 push 한다. worktree 경로를 낸다.
  - `merge(self, epic: str) -> None` — trunk 에서 `merge --no-ff work/<id> -m "Merge pull request #<n> from o/work/<id>"` · push · fetch.
  - `status(self) -> dict` — `python3 roadmap_status.py --json plan/rm/roadmap.md`(cwd `self.w`)의 JSON.

`class SharedOverlapInStatus(RoadmapRepo)`:

```python
def test_shared_only_overlap_is_not_overlap(self):
    self.roadmap([("E1", [], "plugins/p/README.md, src/a.txt", ("C1", "S1", "OQ1")),
                  ("E2", [], "plugins/p/", ("«e2e-k»", "K1"))])
    r = self.status()
    self.assertEqual(r["overlaps"], [])

def test_repo_setting_changes_shared_list(self):
    self.roadmap([("E1", [], "plugins/p/NOTICE", ("C1", "S1", "OQ1")),
                  ("E2", [], "plugins/p/NOTICE", ("«e2e-k»", "K1"))],
                 settings="---\nshared_files: NOTICE\n---\n")
    self.assertEqual(self.status()["overlaps"], [])

def test_roadmap_layer_value_does_not_make_status_unknown(self):
    self.roadmap([("E1", [], "", ("C1", "S1", "OQ1")), ("E2", [], "", ("«e2e-k»", "K1"))],
                 front_extra="shared_files: X.md")
    r = self.status()
    self.assertEqual((r["format_errors"], r["unknown_reasons"]), ([], []))
    self.assertTrue(any("shared_files" in w for w in r["settings"]["warnings"]))
```

`roadmap()` 에 `front_extra: str = ""`(머리말 끝에 붙일 줄) 인자를 둔다. 경로 예약 칸이 빈 글이면 `없음` 으로 쓴다.

- [ ] **Step 2: 실패를 본다** — Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py -v` Expected: `Overlaps` · `SharedOverlapInStatus` FAIL.

- [ ] **Step 3: 구현** — `roadmap_status.py` 의 `_shared` · `overlaps` 시그니처를 위 Interfaces 대로 바꾸고, 대칭은 겹침 집합식의 조건을 `not (_shared(ea, names) or _shared(eb, names))` 로. `compute` 의 예약 위반 루프와 `build` 의 `overlaps(blocks)` 호출이 `settings.get("shared_files") or SHARED_BASENAMES` 를 넘긴다.

- [ ] **Step 4: 통과를 본다** — Run: Step 2 명령 · `bash plugins/spec-distill/tests/test_roadmap_status.sh` Expected: 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 겹침 판정이 레포의 공유 파일 목록을 쓰고 순서와 무관하게` + Spec 트레일러.

---

### Task 3: 작업 목록 끝의 병렬 판단 줄

**AC:** AC1 · AC2 · AC15

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py`
- Modify: `plugins/spec-distill/tests/test_parallel_recommend.py`
- Modify: `plugins/spec-distill/tests/test_conductor_e2e.sh`(AC2)

**Interfaces:**
- Consumes: 상태 계산 보고의 `blocks[*]["stage"]` · `blocks[*]["parallel"]`(`[{"id", "overlap"}]`).
- Produces: `parallel_line(blocks: list) -> str | None` — 대상은 단계 `준비` 인 블록, 짝은 그 블록 `parallel` 가운데 `overlap` 이 비었고 짝의 단계가 `대기` · `알 수 없음` 이 아닌 것(끝난 것은 `parallel_with` 가 이미 뺀다). 짝이 있는 준비 블록이 없으면 `None`. 꼴은 `"동시에 갈 수 있는 준비 에픽: " + " · ".join("%s(함께: %s)" % (id, " · ".join(짝들)))` 이고 `clean()` 을 거친다. 블록 · 짝 순서는 보고 순서.
- `tasks_output` 은 지금 줄들(로드맵 밖 줄 포함) 뒤에 그 줄을 하나 더한다. rc · 표준 오류는 그대로.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

(a) 단위 — `class ParallelLineUnit(unittest.TestCase)`(`import control_plane as cp`):

```python
def b(bid, stage, parallel=()):
    return {"id": bid, "stage": stage, "parallel": [{"id": p, "overlap": o} for p, o in parallel]}

def test_two_ready(self):
    self.assertEqual(cp.parallel_line([b("R1", "준비", [("R2", [])]), b("R2", "준비", [("R1", [])])]),
                     "동시에 갈 수 있는 준비 에픽: R1(함께: R2) · R2(함께: R1)")

def test_filters(self):
    self.assertIsNone(cp.parallel_line([b("R1", "준비", [("R2", ["x/"])]), b("R2", "준비", [("R1", ["x/"])])]))
    self.assertIsNone(cp.parallel_line([b("R1", "준비", [("R2", [])]), b("R2", "대기", [("R1", [])])]))
    self.assertIsNone(cp.parallel_line([b("R1", "준비", [("R2", [])]), b("R2", "알 수 없음", [("R1", [])])]))
    self.assertIsNone(cp.parallel_line([b("R1", "준비", [])]))
    self.assertIsNone(cp.parallel_line([b("R1", "설계 중", [("R2", [])]), b("R2", "설계 중", [("R1", [])])]))

def test_in_progress_partner(self):
    self.assertEqual(cp.parallel_line([b("R1", "구현 중", [("R2", [])]), b("R2", "준비", [("R1", [])])]),
                     "동시에 갈 수 있는 준비 에픽: R2(함께: R1)")

def test_tasks_output_appends_tabless_last_line(self):
    rep = {"exit": 0, "blocks": [dict(b("R1", "준비", [("R2", [])]), title="가", task_status="pending"),
                                 dict(b("R2", "준비", [("R1", [])]), title="나", task_status="pending")]}
    out, err, rc = cp.tasks_output([("rm.md", rep)])
    self.assertEqual(rc, 0)
    self.assertEqual(out[:2], ["R1 가 — 준비\tpending", "R2 나 — 준비\tpending"])
    self.assertEqual(out[2], "동시에 갈 수 있는 준비 에픽: R1(함께: R2) · R2(함께: R1)")
    self.assertNotIn("\t", out[2])
```

(b) 실제 상태 계산 — `class ParallelLineInRepo(RoadmapRepo)`, `tasks(self) -> list[str]` 는 `python3 control_plane.py show --tasks plan/rm/roadmap.md`(cwd `self.w`)의 표준 출력 줄들:
  - 준비 둘 · 겹침 없음 → 끝 줄 `동시에 갈 수 있는 준비 에픽: E1(함께: E2) · E2(함께: E1)`.
  - 준비 하나(E2 가 E1 에 의존) → 끝 줄이 탭을 가진다(병렬 줄 없음).
  - 겹침(같은 `src/a.txt` 예약) → 병렬 줄 없음.
  - 공유 파일만 겹침(`plugins/p/README.md` 와 `plugins/p/`) → 병렬 줄 있음.
  - 진행 중인 짝(`start_design("E1")` 뒤) → `동시에 갈 수 있는 준비 에픽: E2(함께: E1)`.
  - 모든 줄 가운데 탭 없는 줄은 끝 줄 하나뿐이다.

(c) AC2 — `test_conductor_e2e.sh` 의 「# 2 — 표지 · 규모 공시」 단계 끝(claim 뒤 · approval 단언 뒤)에 넣는다:

```bash
# 2b — AC2: 병렬 판단 줄이 나오는 상태(E1 · E2 준비)에서 기계 상태를 지워도 작업 목록이 같다
before2="$(tasks_of)"
assert_contains "$before2" "동시에 갈 수 있는 준비 에픽: E1(함께: E2) · E2(함께: E1)" "AC2: 병렬 판단 줄이 나오는 상태다"
rm -f -- "$SP0"
assert_eq "$(tasks_of)" "$before2" "AC2: 기계 상태를 지워도 병렬 판단 줄까지 같다"
L claim --roadmap "$RM" --session "$SID" >/dev/null; assert_eq "$?" "0" "AC2: 지운 뒤 표지를 다시 잡는다"
```

- [ ] **Step 2: 실패를 본다** — Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py -v` · `bash plugins/spec-distill/tests/test_conductor_e2e.sh` Expected: 새 사례 FAIL(`parallel_line` 없음 · 2b 단언 ✗).

- [ ] **Step 3: 구현** — `control_plane.py` 에 `parallel_line` 을 두고 `tasks_output` 의 `return out, "", 0` 앞에서 줄을 더한다.

- [ ] **Step 4: 통과를 본다** — Run: Step 2 명령 · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_control_plane.py` · `bash plugins/spec-distill/tests/test_control_plane.sh` Expected: 실패 0. 기존 단언이 작업 목록 전체를 글자째 견주다 깨지면, 그 픽스처에 짝 있는 준비 에픽이 정말 있는지 보고 있을 때만 기대값에 끝 줄을 더한다 — 고친 단언과 이유를 커밋 본문에 적는다.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 작업 목록 끝에 병렬 판단 줄` + Spec 트레일러.

---

### Task 4: spec 리뷰의 이웃 결정 — 동시 가능 에픽 · 결정 줄 셋

**AC:** AC9 · AC15

**Files:**
- Modify: `plugins/spec-distill/scripts/spec_review_bundle.py`
- Modify: `plugins/spec-distill/tests/test_parallel_recommend.py`

**Interfaces:**
- Produces: `DECISION_LINE_RE = re.compile(r"- (?:[BU]\d+ · 결정 · |D\d+\.\d+ · )")`(`.match` — 줄 머리에서만); `neighbors` 의 `near` 에 `me["parallel"]` 의 id 를 더한다. 위치 블록에 그 가운데 설계문서가 있는 것마다 `"  함께 진행 중: " + _line(b)` 줄을 의존 줄들 뒤에 낸다. 결정 블록의 「설계문서가 있는 이웃만」 거르기는 그대로다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

(a) 단위 — `class DecisionLines(unittest.TestCase)`:

```python
def test_three_forms(self):
    for line in ("- B1 · 결정 · 2026-10-25 · 사용자 — 「가」", "- U3 · 결정 · 나", "- D2.6 · r2 · adopt · x"):
        self.assertTrue(sb.DECISION_LINE_RE.match(line), line)

def test_not_decision_lines(self):
    for line in ("  - D1.1 · r1 · adopt", "- D2 · 결정 · 가", "- docreview 계수 — x", "- B1 결정"):
        self.assertFalse(sb.DECISION_LINE_RE.match(line), line)
```

(b) 실제 git — `class NeighborDecisions(RoadmapRepo)`: E1 · E2 가 의존 · 겹침 없이 로드맵에 있고, `start_design("E2", extra="- U1 · 결정 · 유\n- D1.1 · r1 · adopt · 디\n")` · `start_design("E1")` 뒤 `sb.neighbors(<self.w>/plan/rm/E1.md, str(self.w))` 의 줄에:
  - `"  함께 진행 중: E2 "` 로 시작하는 줄이 있다.
  - `"    - U1 · 결정 · 유"` 와 `"    - D1.1 · r1 · adopt · 디"` 가 있다.
  - E2 를 E1 에 의존하게 바꾼 로드맵에서는 「이 에픽에 의존」 줄로 나오고 「함께 진행 중」 줄은 없다.

- [ ] **Step 2: 실패를 본다** — Run: 위 unittest 명령. Expected: FAIL.

- [ ] **Step 3: 구현** — 위 Interfaces 대로.

- [ ] **Step 4: 통과를 본다** — Run: 위 명령 · `bash plugins/spec-distill/tests/test_spec_review_bundle.sh` Expected: 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): spec 리뷰 이웃 결정에 동시 가능 에픽 · U · D 줄` + Spec 트레일러.

---

### Task 5: 리뷰 묶음의 `intents.md`

**AC:** AC10 · AC15

**Files:**
- Create: `plugins/spec-distill/scripts/review_intents.py`
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(`c_review_pack` 에 부르는 자리 · README 줄)
- Modify: `plugins/spec-distill/tests/test_parallel_recommend.py`

**Interfaces:**
- Produces: `review_intents.build(report: dict, epic: str, tip: str, git_fn) -> tuple[str, list[str]]` — `(intents.md 글, 경고 줄들)`. `git_fn(*args) -> (rc, stdout, stderr)` 는 `conductor_ledger.git` 을 `root` 에 묶은 것. 기본 브랜치 참조는 `conductor_ledger.DEFAULT_REF` 를 인자로 받지 않고 `roadmap_model.DEFAULT_REF` 를 쓴다.
- `c_review_pack` 은 `put("handoffs.md", …)` 뒤에서 `_status(root, a.roadmap)` 를 부르고(`Fail` 이면 글 `"함께 진행된 에픽을 셀 수 없다 — <사유>"` · 경고 한 줄 — 묶음은 rc 0 그대로) `put("intents.md", 글)` 한다. `README.txt` 줄: `"intents.md — 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문(머지됨 · 열림 표시)"`.

`build` 의 규칙(설계문서 §5 · 결정 D2.2):
1. 기준 커밋: 이 에픽 블록 `specs`(산출물 블록이면 산출물)를 `git log --diff-filter=A --format=%H --reverse <tip> -- <specs…>` 로 찾은 첫 커밋. `specs` 가 없거나 못 찾으면 `merge-base <DEFAULT_REF> <tip>` 이고, 글 첫 줄과 경고에 `"기준을 세울 수 없어 갈라진 점(merge-base)으로 쟀다 — <사유>"`. 찾았으면 첫 줄 `"기준 커밋 <8자> — <에픽> 의 설계문서를 처음 더한 커밋"`.
2. 후보: 이 에픽이 아니고 단계가 `대기` · `준비` 가 아닌 블록.
3. 뺌: 블록 `specs` 가 하나 이상이고 모두 기준 커밋 트리에 있으며(`cat-file -e <기준>:<경로>`), `branch_states` 가 하나 이상이고 모두 `merged` 가 참 · `tip` 이 있음 · `merge-base --is-ancestor <tip> <기준>` rc 0 일 때만. 하나라도 확인하지 못하면 뺄 수 없다(싣는다).
4. 실음: 표시는 단계가 `머지됨` 이면 `머지됨`, 아니면 `열림`. 읽는 트리는 `머지됨` 이면 기본 브랜치, 아니면 블록 `tip`, `tip` 이 없으면 기본 브랜치. 설계문서마다 `### <에픽> <경로>(<표시>)` 아래 `git show <트리>:<경로>` 전문. 못 읽으면 그 머리 아래 `"읽지 못함 — <사유>"` 와 경고. `specs` 가 없으면 `### <에픽>(<표시>)` 아래 `"설계문서 없음"` 한 줄. 단계가 `알 수 없음` 이면 그 머리 아래 `"단계를 알 수 없다 — <reason>"` 와 경고.
5. 실은 것이 없으면 둘째 줄 `"함께 진행된 에픽 없음"`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `class IntentsPack(RoadmapRepo)`, `pack(self, epic) -> tuple[int, str, Path]` 는 `conductor_ledger.main(["--root", w, "review-pack", "--roadmap", RM, "--epic", epic, "--branch", "work/<id>", "--out", <새 폴더>])` 를 `PATH` 에서 gh 를 빼고 부른 rc · 표준 출력 · 폴더. 사례(로드맵은 E1 · E2 · E3, 서로 의존 · 겹침 없음):

| 사례 | 만들기 | `intents.md` 기대 |
|---|---|---|
| 설계 전 머지 | E2 설계 · `merge("E2")` → 그 뒤 E1 설계 | E2 머리 없음 · 「함께 진행된 에픽 없음」 |
| 설계 뒤 머지 | E1 설계 → E2 설계 · `merge("E2")` | `### E2 plan/specs/E2-design.md(머지됨)` 와 E2 본문 |
| 합친 뒤에도 | 위 뒤 E1 브랜치에 trunk 를 merge · push | 여전히 E2 머리(머지됨) — 기준 커밋이 옮지 않는다 |
| 머지 뒤 브랜치 지움 | 「설계 뒤 머지」 뒤 `push origin --delete work/e2` · `branch -D work/e2` | E2 머리가 있다 · E2 본문이 있다 |
| 열림 | E1 · E2 설계(머지 없음) | `### E2 …(열림)` |
| 쌓인 브랜치 | E2 설계 뒤 `start_design("E1", base="work/e2")` — E2 설계문서가 기준 트리에 있고 E2 끝이 기준의 조상이지만 머지 전 | `### E2 …(열림)` |
| 준비 에픽 | E3 은 아무것도 하지 않음 | E3 머리 없음 |
| 없음 | E1 만 설계 | 「함께 진행된 에픽 없음」 |
| 상태 계산 실패 | 로드맵 형식을 깬 커밋 | rc 0 · 「함께 진행된 에픽을 셀 수 없다」 · 표준 출력에 `경고:` |

공통 단언: 첫 줄이 `기준 커밋 ` 으로 시작(상태 계산 실패 사례 빼고), `README.txt` 에 `intents.md — ` 줄.

- [ ] **Step 2: 실패를 본다** — Run: 위 unittest 명령. Expected: FAIL(`intents.md` 없음).

- [ ] **Step 3: 구현** — 위 Interfaces · 규칙대로. `review_intents.py` 는 머리에 `# -*- coding: utf-8 -*-` 와 이 모듈이 맡는 일 한 줄 docstring, 명령줄 입구는 두지 않는다.

- [ ] **Step 4: 통과를 본다** — Run: 위 명령 · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py` Expected: 실패 0(기존 `ReviewPack` 사례는 상태 계산이 실패하는 픽스처라 「셀 수 없다」 글로 rc 0).

- [ ] **Step 5: 커밋** — `feat(spec-distill): 통합 리뷰 묶음에 함께 진행된 에픽의 설계 의도` + Spec 트레일러.

---

### Task 6: 통합 리뷰어 일곱째 이음매 · dispatch 칸 · 통합 리뷰 문장

**AC:** AC11 · AC15

페르소나 편집 — 규칙을 더하기만 한다. 이 과제의 리뷰는 보안 리뷰 관점(규칙 제거 · 기준 완화가 없는가)을 함께 본다.

**Files:**
- Modify: `plugins/spec-distill/agents/integration-reviewer.md`
- Modify: `plugins/spec-distill/skills/epic-conductor/SKILL.md`
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 5 통합 리뷰 · 손 절차 8 통합 리뷰)
- Create: `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`(100755)

**Interfaces:**
- Consumes: Task 5 의 `intents.md`.
- 문면(글자 그대로):
  - 프로필 `input_slots` 끝에 `- tag: intents` / `var: INTENTS` / `kind: artifact`.
  - `## 입력` 끝 줄: `` - `<intents>` — 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문을 모은 파일 경로(`intents.md`). 에픽마다 `### <에픽> <설계문서 경로>(머지됨 | 열림)` 아래 전문이다. ``
  - `## 볼 이음매` 7: `7. 함께 진행된 에픽의 설계 의도 — `intents` 의 Goals · Non-goals · 결정 기록 · 판정과 이 PR 이 어긋나거나, 이 PR 이 그 의도가 기대는 동작 · 문구 · 규약을 무너뜨리는가. 경로가 겹치지 않아도 본다. 이 PR 이 앞 에픽의 의도를 망가뜨렸으면 고칠 곳은 「이 PR 이 고침」 이다.`
  - `## 내는 것` 의 `<위 1~6 의 이름>` → `<위 1~7 의 이름>`.
  - SKILL `### 6. 통합 리뷰어`: `나머지 셋은` → `나머지 넷은`, dispatch 의 `<handoffs>${HANDOFFS}</handoffs>` 다음 줄 `    <intents>${INTENTS}</intents>"`(닫는 따옴표를 이 줄로 옮긴다).
  - `conducting.md` 걸음 5 통합 리뷰: `· 앞선 인계 절을 한 폴더에 모은다.` → `· 앞선 인계 절 · 함께 진행된 에픽의 설계문서 전문(`intents.md`)을 한 폴더에 모은다.` 그리고 그 불릿 끝에 `리뷰어는 일곱째 이음매로 함께 진행된 에픽의 설계 의도(Goals · Non-goals · 결정 기록 · 판정)와 이 PR 이 어긋나는지 본다 — 경로가 겹치지 않아도 보고, 이 PR 이 앞 에픽의 의도를 망가뜨렸다는 지적은 「이 PR 이 고침」 이다.`
  - 손 절차 8 통합 리뷰: `앞선 통합 리뷰가 이 PR 에 넘긴 항목을 주고` → `앞선 통합 리뷰가 이 PR 에 넘긴 항목 · 함께 진행된 에픽의 설계문서 전문(`python3 "<SD>"/scripts/conductor_ledger.py review-pack` 의 `intents.md`)을 주고`, 이음매 목록 `리뷰어 프로필의 규칙 제거 · 기준 완화(사용자 결정이 있는지)` 뒤에 `, 함께 진행된 에픽의 설계 의도(Goals · Non-goals · 결정 기록 · 판정)와 이 PR 의 어긋남(경로가 겹치지 않아도)` 을 더한다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `test_parallel_recommend_docs.sh` 머리(`set -u` · `ROOT` · `. "$ROOT/shared/tests/assert.sh"` · `CD` · `PG` · `SRS` · `AG` · `SK` · `EH` · `DP` 경로 변수)와 도우미:

```bash
loop_of() { awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD"; }
cyc() { loop_of | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
man() { awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD" | awk -v n="$1" 'index($0, n ". ")==1{f=1;print;next} f&&/^[0-9]+\. /{exit} f'; }
count() { printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
once_in() { assert_eq "$(count "$2" "$3")" "1" "$1: 「$3」 정확히 한 번"; }
```

(`man <n>` 은 손 절차 n 번 걸음의 글 — 다음 `<숫자>. ` 줄 앞까지. 만든 뒤 `man 8` 이 「머지 전 확인」 을 담고 `man 9` 를 담지 않는지 양성 단언으로 확인한다.)

AC11 락: 프로필에 `tag: intents` · 이음매 7 문장 전체 · `<위 1~7 의 이름>` · 이음매 1~6 의 지금 문장 여섯(글자 그대로, 줄지 않음) · `<위 1~6 의 이름>` 이 없음. SKILL 에 `<intents>${INTENTS}</intents>` · `나머지 넷은`. `cyc 5` 에 `함께 진행된 에픽의 설계문서 전문(`intents.md`)` · `일곱째 이음매로`. `man 8` 에 `review-pack` 의 `intents.md` · `함께 진행된 에픽의 설계 의도(Goals · Non-goals · 결정 기록 · 판정)와 이 PR 의 어긋남`.

- [ ] **Step 2: 실패를 본다** — Run: `chmod +x plugins/spec-distill/tests/test_parallel_recommend_docs.sh && bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` Expected: ✗ 줄들.

- [ ] **Step 3: 문면을 고친다** — 위 Interfaces 의 글자 그대로.

- [ ] **Step 4: 통과를 본다** — Run: Step 2 · `bash shared/tests/test_agent_input_slots.sh` · `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `bash plugins/spec-distill/tests/test_conducting_loop.sh` · `bash plugins/spec-distill/tests/test_conducting_reference.sh` Expected: 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 통합 리뷰어 일곱째 이음매 — 함께 진행된 에픽의 설계 의도` + Spec 트레일러. `git ls-files -s plugins/spec-distill/tests/test_parallel_recommend_docs.sh` 가 `100755`.

---

### Task 7: 병렬 질문 · 「차례로」 확인 · 끝 줄 소비 · 소식 예외

**AC:** AC3 · AC6 · AC7 · AC8 · AC15

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 1 · 2 · 3 · 4, 손 절차 1 · 2 · 3 · 4 · 5)
- Modify: `plugins/spec-distill/references/proceed-gate.md`
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`
- Modify: `plugins/spec-distill/tests/test_end_gates.sh`(옛 문장 단언을 새 문장으로)
- Modify: `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`

**문면(글자 그대로):**

- 끝 줄 소비(AC3) — 걸음 1 기본값 끝에 `작업 목록 출력의 탭 없는 끝 줄(`동시에 갈 수 있는 준비 에픽: …`)은 작업이 아니라 병렬 판단 신호다 — 작업 목록에 넣지 않고 걸음 3 의 승인 게이트에서 쓴다.` / 손 절차 1 의 `제목만 바꾼다.` 뒤에 `탭 없는 끝 줄(`동시에 갈 수 있는 준비 에픽: …`)은 작업이 아니라 병렬 판단 신호다 — 작업 목록에 넣지 않고 3 의 승인 게이트에서 쓴다.`
- 소식 예외(AC6 끝) — 걸음 2 의 `… 리뷰가 끝난 뒤 — 알리거나 묻는다.` 와 손 절차 2 의 `… 리뷰가 끝난 뒤 알리거나 묻는다.` 의 마침표 앞에 각각 ` — 걸음 3 의 병렬 질문은 소식이 아니다(지금 승인하는 에픽 다음의 구현 순서를 정하는 지휘자 질문이라 그 게이트 질문 호출에 붙는다)` 를 넣는다.
- 병렬 질문(AC6 · AC7) — 걸음 3 의 `- 승인 게이트:` 불릿 바로 뒤에 새 불릿:
  `  - 병렬 질문: 승인 게이트 직전 걸음 1 의 작업 목록 끝 줄에서 지금 승인하는 에픽(A)을 짝으로 가진 준비 에픽(B…)이 있으면 같은 `AskUserQuestion` 호출에 둘째 질문 「<A> 다음 — 준비 에픽 <B…> 의 구현을 <A> 구현과 겹칠까?」 를 붙인다. 질문 본문 앞에 배경 한 줄(의존 없음 · 경로 예약이 공유 파일 말고 겹치지 않음)을 쓰고, 선택지는 「병렬 (권장)」(<B…> 의 계획이 끝나는 대로 구현 담당자를 보낸다 — <A> 구현과 동시에 돌고 머지는 하나씩이다)과 「차례로」(<B…> 의 설계 · 계획은 그대로 가고 구현 담당자는 <A> 의 PR 이 머지된 뒤 보낸다)다. A 에 닿는 병렬 답이 하나도 없고 A 와 함께 구현할 진행 중 에픽(`control_plane.py show <로드맵> <A>` 의 「동시에 갈 수 있는 에픽」 가운데 경로 예약 겹침이 없고 대기 · 알 수 없음이 아닌 것)이 있으면 짝 조건이 없어도 「<A> 의 구현을 <진행 중 에픽> 구현과 겹칠까?」 를 붙인다 — 그 답은 A 자신의 구현 보내기에 쓰고 기록 줄의 준비 에픽 칸에 A 를 적는다. 이 로드맵 에픽들의 설계문서 `## 지휘 기록`(머지된 에픽은 기본 브랜치에서 읽는다) 가운데 가장 최근(줄의 시각) 병렬 답의 준비 에픽 집합에 지금 집합이 모두 들어 있으면 붙이지 않고 승인 질문 본문에 「지난 답: <선택지>(준비 에픽 <…>)」 한 줄을 싣고 그 답을 쓴다 — 지난 답에 없던 에픽이 하나라도 들어왔을 때만 다시 묻는다(지금 집합이 비었으면 이 다시 쓰기를 하지 않고 위 진행 중 에픽 갈래만 본다). 승인을 골랐을 때만 승인 줄과 함께 `ledger record --spec <설계문서> --line "병렬 답 · <YYYY-MM-DD HH:MM> · 「<고른 선택지>」 · 준비 에픽 <B…>"` 를 적어 같은 커밋에 넣고, 「수정 필요」 · 「멈춤」 이면 병렬 답은 버리고 다음 승인 때 다시 묻는다. 둘째 질문으로 흐름을 묻지 않는다.`
- 「차례로」 확인(AC8) — 위 불릿 바로 뒤에 새 불릿:
  `  - 「차례로」 확인: 구현 담당자를 보내기 전에(이 걸음 · 걸음 4 · 걸음 1 과 4 의 채우기 어디서든) 그 에픽(B)에 닿는 가장 최근 병렬 답을 본다. 「차례로」 면 B 보다 먼저 승인된 에픽이 모두 상태 계산에서 「머지됨」 이 될 때까지 `## 작업` 의 B 줄을 「구현 기다림 — <에픽> 머지」 로 두고 보내지 않는다. 닿는 답이 없으면 기본(병렬)대로 보낸다. 설계 · 계획은 어느 답이든 그대로 간다. 기다리는 동안 사용자가 생각을 바꾸면 그 말을 따르고 새 병렬 답 줄을 적는다(지난 줄은 고치지 않는다).`
- 가리킴(AC8) — 걸음 1 판단과 걸음 4 판단의 `이고 상한이 아니다(사용자가 늘린다).` 바로 뒤에 ` 구현 담당자를 보낼 때는 먼저 걸음 3 의 「차례로」 확인을 한다.` / 걸음 4 판단의 `없으면 계획 경로만 보이고 새 구현 agent 를 보낸다` → `없으면 계획 경로만 보이고 걸음 3 의 「차례로」 확인 뒤 새 구현 agent 를 보낸다` / 손 절차 1 의 `이고 상한이 아니다(사용자가 늘린다).` 뒤에 ` 구현 담당자를 보낼 때는 먼저 3 의 「차례로」 확인을 한다.` / 손 절차 4 의 `없으면 계획 경로만 보이고 구현을 보낸다` → `없으면 계획 경로만 보이고 3 의 「차례로」 확인 뒤 구현을 보낸다` / 손 절차 5 의 `띄우기 전에 규모를 알린다.` 뒤에 ` 구현 담당자를 보낼 때는 먼저 3 의 「차례로」 확인을 한다.`
- 손 절차 3(AC6 · AC7 · AC8 거울) — `설계문서 `## 지휘 기록` 에 한 줄로 커밋한다.` 바로 뒤에 두 문장: `승인 질문 호출에는 지휘 순환 걸음 3 의 병렬 질문(「병렬 (권장)」 · 「차례로」)이 둘째 질문으로 붙을 수 있다 — 붙는 조건 · 지난 답 다시 쓰기 · 답 기록(`conductor_ledger.py record --line "병렬 답 · …"`)은 그 불릿대로 하고, 승인을 골랐을 때만 적는다. 「차례로」 확인(구현 담당자를 보내기 전에 그 에픽에 닿는 가장 최근 병렬 답이 「차례로」 면 먼저 승인된 에픽이 모두 「머지됨」 이 될 때까지 보내지 않는다 — 설계 · 계획은 그대로)도 지휘 순환 걸음 3 대로 한다.`
- `proceed-gate.md` 56행 문장 `지휘자 아래 승인 질문에는 둘째 질문이 없다(에픽의 흐름은 로드맵 `흐름:` 칸이 정한다).` → `지휘자 아래 승인 질문에는 다음 단계 갈래 질문이 없다(에픽의 흐름은 로드맵 `흐름:` 칸이 정한다) — 둘째 질문으로는 지휘 순환 걸음 3 의 병렬 질문만 붙을 수 있다(`conducting.md`).` / 60행 「지휘자 아래 — 승인 질문 하나」 문단의 `「멈춤」(④).` 뒤에 ` 같은 호출에 지휘 순환 걸음 3 의 병렬 질문이 둘째 질문으로 붙을 수 있다(`conducting.md` 걸음 3).`
- `skills/spec-review/SKILL.md` 「지휘 세션이 돌린 리뷰면」 문단의 `「멈춤」 은 ④ 다.` 뒤에 ` 같은 호출에 지휘 순환 걸음 3 의 병렬 질문이 둘째 질문으로 붙을 수 있다(지휘 절차 걸음 3).`
- `test_end_gates.sh` 108행 단언의 기대 문장을 새 56행 문장으로 바꾸고, 같은 문단에 옛 문장 `지휘자 아래 승인 질문에는 둘째 질문이 없다(` 가 없다는 단언을 더한다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `test_parallel_recommend_docs.sh` 에:
  - AC3: `cyc 1` · `man 1` 각각 `은 작업이 아니라 병렬 판단 신호다 — 작업 목록에 넣지 않고` 정확히 한 번.
  - AC6: `cyc 3` 에 `「<A> 다음 — 준비 에픽 <B…> 의 구현을 <A> 구현과 겹칠까?」` · `「병렬 (권장)」(<B…> 의 계획이 끝나는 대로 구현 담당자를 보낸다` · `「차례로」(<B…> 의 설계 · 계획은 그대로 가고 구현 담당자는 <A> 의 PR 이 머지된 뒤 보낸다)` · `짝 조건이 없어도` 각각 한 번. `man 3` 에 `병렬 질문(「병렬 (권장)」 · 「차례로」)이 둘째 질문으로 붙을 수 있다`. `cyc 2` · `man 2` 각각 `— 걸음 3 의 병렬 질문은 소식이 아니다` 한 번(두 자리 모두 — 한 자리만 지우는 변이도 ✗). `$PG` 에 새 56행 문장과 `같은 호출에 지휘 순환 걸음 3 의 병렬 질문이 둘째 질문으로 붙을 수 있다(`conducting.md` 걸음 3).`, `$SRS` 에 `같은 호출에 지휘 순환 걸음 3 의 병렬 질문이 둘째 질문으로 붙을 수 있다(지휘 절차 걸음 3).`. 선택지 설명(`계획이 끝나는 대로 구현 담당자를 보낸다`)이 `$PG` · `$SRS` 에 없다(복사 금지).
  - AC7: `cyc 3` 에 `병렬 답 · <YYYY-MM-DD HH:MM> · 「<고른 선택지>」 · 준비 에픽 <B…>` · `가장 최근(줄의 시각)` · `「지난 답: <선택지>(준비 에픽 <…>)」` · `지난 답에 없던 에픽이 하나라도 들어왔을 때만 다시 묻는다` · `승인을 골랐을 때만` · `「수정 필요」 · 「멈춤」 이면 병렬 답은 버리고`. `- 병렬 질문:` 으로 시작하는 줄에 `같은 세션` 이 없다(brief 의 반증된 제한을 들이지 않는다).
  - AC8: `cyc 3` 에 `「구현 기다림 — <에픽> 머지」` · `닿는 답이 없으면 기본(병렬)대로 보낸다`. 가리킴 수 — `cyc 1` · `cyc 4` 의 `걸음 3 의 「차례로」 확인` 이 각각 1 · 2, `man 1` · `man 4` · `man 5` 의 `3 의 「차례로」 확인` 이 각각 1, `man 3` 의 `「차례로」 확인(` 1.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` Expected: 새 단언 ✗.

- [ ] **Step 3: 문면을 고친다** — 위 「문면」 글자 그대로. `test_end_gates.sh` 도.

- [ ] **Step 4: 통과를 본다** — Run: Step 2 · `bash plugins/spec-distill/tests/test_end_gates.sh` · `bash plugins/spec-distill/tests/test_conducting_loop.sh` · `bash plugins/spec-distill/tests/test_conducting_reference.sh` · `bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh` · `bash plugins/spec-distill/tests/test_repo_literals.sh` Expected: 실패 0. 기존 락이 바뀐 문장 때문에 깨지면 그 락이 재던 뜻이 새 문면에 남았는지 보고, 남았으면 기대 글을 새 문면으로 바꾸고 이유를 커밋 본문에 적는다.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 승인 게이트의 병렬 질문과 「차례로」 확인` + Spec 트레일러.

---

### Task 8: 머지 명령 줄은 하나씩 · 대조 기준 커밋 · 머지 큐

**AC:** AC12 · AC13 · AC15

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 5 판단 · 손 절차 8)
- Modify: `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`

**문면(글자 그대로, 두 자리 같은 글):** 걸음 5 판단의 `- 끝으로 superpowers:verification-before-completion …` 불릿 바로 앞에 두 불릿을, 손 절차 8 의 `끝으로 `superpowers:verification-before-completion` 을 따른다.` 줄 바로 앞에 같은 글을 들여쓴 두 불릿(`   - **머지 하나씩.** …` · `   - **머지 큐.** …`)으로 넣는다.

1. 머지 하나씩: `머지 명령 줄은 이 로드맵의 PR 가운데 한 번에 하나만 낸다 — 낸 PR 이 상태 계산에서 「머지됨」 이 되면 다음 PR 은 머지 뒤 걸음대로 기본 브랜치를 합치고 스위트 대조를 다시 돈 뒤에 낸다. 낸 PR 이 머지되지 않고 닫히거나 사용자가 다른 순서를 말하면 그 명령 줄을 거두고 다음 PR 을 지금 기본 브랜치에 대해 다시 대조한 뒤 낸다. 명령 줄을 내기 직전 스위트 대조 첫 줄의 기본 브랜치 커밋과 지금 origin 기본 브랜치 끝을 견주어 다르면 스위트 대조를 다시 돈다. 통합 리뷰는 다시 돌지 않는 것이 기본이다 — 앞 PR 이 이 PR 의 통합 리뷰 뒤에 바뀌었거나 기본 브랜치를 합칠 때 이 PR 이 고친 파일이 함께 바뀌었으면 다시 돌고, 그 판단과 이유를 PR 본문에 적는다. 공유 파일 · 코퍼스 락이 둘째 PR 에서만 깨지면 둘째 PR 에서 고치고, 앞 에픽과의 조합 때문이라는 근거를 인계 절에 한 문장으로 적는다.`
2. 머지 큐: `명령 줄을 내기 전에 그 레포 기본 브랜치의 보호 규칙 · 규칙 집합을 `gh` 로 원격에서 읽는다 — 읽지 못하면 없는 것으로 보고 그 사실을 알린다. 머지 큐가 있거나 「최신 기본 브랜치 반영 필수」 규칙이 있으면 머지 순서는 그것에 맡기고 명령 줄을 하나씩 낼 필요가 없다고 알린다. 기계 재검사는 레포 필수 검사가 스위트 대조와 같은 테스트 명령을 돈다고 CI 설정(워크플로 정의 등)에서 확인될 때만 맡기고, 확인하지 못하면 스위트 대조를 다시 돈다. 통합 리뷰(의도 대조)는 언제나 지휘자 몫이다.`

- [ ] **Step 1: 실패하는 락을 쓴다** — AC12 · AC13: `cyc 5` 와 `man 8` 각각에 다음이 정확히 한 번 — `한 번에 하나만 낸다` · `그 명령 줄을 거두고` · `스위트 대조 첫 줄의 기본 브랜치 커밋과 지금 origin 기본 브랜치 끝을 견주어` · `통합 리뷰는 다시 돌지 않는 것이 기본이다` · `이 PR 이 고친 파일이 함께 바뀌었으면 다시 돌고` · `읽지 못하면 없는 것으로 보고 그 사실을 알린다` · `머지 순서는 그것에 맡기고` · `같은 테스트 명령을 돈다고 CI 설정(워크플로 정의 등)에서 확인될 때만 맡기고` · `통합 리뷰(의도 대조)는 언제나 지휘자 몫이다`.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` Expected: ✗.

- [ ] **Step 3: 문면을 고친다.**

- [ ] **Step 4: 통과를 본다** — Run: Step 2 · `bash plugins/spec-distill/tests/test_conducting_loop.sh` · `bash plugins/spec-distill/tests/test_conducting_reference.sh` · `bash plugins/spec-distill/tests/test_repo_literals.sh` Expected: 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 머지 명령 줄은 하나씩 · 머지 큐는 원격 규칙으로` + Spec 트레일러.

---

### Task 9: 조사 자리 — 설계 전 꼼꼼히 · 계획 첫 과제 가볍게

**AC:** AC14 · AC15

**Files:**
- Modify: `plugins/spec-distill/references/epic-handoff.md`
- Modify: `plugins/spec-distill/references/conductor-dispatch.md`
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 3 기본값)
- Modify: `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`

**문면(글자 그대로):**
- 넘김 줄 — `… 재분해 신호로 사용자에게 보고한다(${CLAUDE_PLUGIN_ROOT}/references/redecompose.md).` 바로 뒤에 ` 설계 전에 이 에픽이 닿는 코드 · 문서를 직접 읽어 묶음의 근거가 지금도 맞는지, 빠진 항목 · 이미 고쳐진 항목이 있는지 꼼꼼히 조사해 ## 있는 것 검토 절에 적는다 — 조사가 다른 에픽이 예약한 파일을 고쳐야 한다고 보이면 재분해 신호로 보고한다.`
- 계획 agent 틀 — `흐름: <고른 흐름> — <이유>. 입력: …` 줄 바로 뒤 줄: `계획의 첫 과제는 가벼운 다시 확인이다 — 설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 달라졌으면 멈춰 보고한다.`
- 걸음 3 기본값 끝: `설계 전 조사는 꼼꼼히(`epic-handoff.md` 의 조사 문장 — 있는 것 검토 절에 적고, 다른 에픽이 예약한 파일이면 재분해 신호), 계획의 첫 과제는 가벼운 다시 확인이다(`conductor-dispatch.md` 계획 틀).`

- [ ] **Step 1: 실패하는 락을 쓴다** — AC14: 넘김 줄(`test_epic_handoff.sh` 와 같은 방법으로 표지 아래 인용 줄을 뽑는다)에 `꼼꼼히 조사해 ## 있는 것 검토 절에 적는다` · `다른 에픽이 예약한 파일을 고쳐야 한다고 보이면 재분해 신호로 보고한다`. `$DP` 의 `### 계획 agent` 절에 `계획의 첫 과제는 가벼운 다시 확인이다 — 설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 달라졌으면 멈춰 보고한다.` 한 번. `cyc 3` 에 `설계 전 조사는 꼼꼼히(` · `계획의 첫 과제는 가벼운 다시 확인이다(` 한 번.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` Expected: ✗.

- [ ] **Step 3: 문면을 고친다.**

- [ ] **Step 4: 통과를 본다** — Run: Step 2 · `bash plugins/spec-distill/tests/test_epic_handoff.sh` · `bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` · `bash plugins/spec-distill/tests/test_conducting_loop.sh` Expected: 실패 0.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 설계 전 조사와 계획 첫 과제의 다시 확인` + Spec 트레일러.

---

### Task 10: README · ontology · CHANGELOG · 판

**AC:** AC4 · AC16

**Files:**
- Modify: `plugins/spec-distill/README.md` · `plugins/spec-distill/references/roadmap-ontology.md` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/tests/test_parallel_recommend_docs.sh`

**문면:**
- README 설정 표 끝 행: `` | `shared_files` | 겹침 판정 · 경로 예약 위반 알림에서 빼는 파일 이름(경로 없이, 한 줄 쉼표 목록) | `plugin.json, CHANGELOG.md, README.md` | 무시하고 경고 | 무시하고 경고 | ``. 예시 머리말에 `shared_files: plugin.json, CHANGELOG.md, README.md` 줄. `**키는 위 아홉뿐이다.**` → `**키는 위 열뿐이다.**` 그리고 그 불릿 끝에 `` `shared_files` 가 비었거나 빈 원소 · `/` 가 든 원소가 있으면 기본 셋으로 세고 알리고, 로드맵 머리말 · 기계 상태에 적혔으면 그 값은 무시하고 알린다. ``. 따옴표 규칙 불릿 끝에 `` `shared_files` 는 이름 하나에 ` #` 가 들어도 쉼표 목록 값 전체를 감싼다(예: `shared_files: "note #1.md, README.md"`). ``. `conductor_ledger.py` 설명의 `통합 리뷰 묶음(` 괄호 끝에 ` · 함께 진행된 에픽의 설계 의도 `intents.md`` 를 더한다.
- ontology 「레포 설정」 행: `닫힌 집합 아홉` → `닫힌 집합 열`, 뜻 칸 끝 `· 겹침에서 빼는 공유 파일`, 키 칸 끝 `` · `shared_files` ``.
- `plugin.json` `"version": "8.11.0"`.
- CHANGELOG 맨 위 `## [8.11.0] — 2026-10-25`, `### Added`: 작업 목록 끝의 병렬 판단 줄(`동시에 갈 수 있는 준비 에픽: …`) · 레포 설정 키 `shared_files` · 통합 리뷰 묶음의 `intents.md` 와 통합 리뷰어 입력 칸 `intents` · 일곱째 이음매(함께 진행된 에픽의 설계 의도) · 승인 게이트의 병렬 질문 · 「차례로」 확인 · 머지 명령 줄 하나씩 · 머지 큐 판단 · 설계 전 조사 · 계획 첫 과제 다시 확인. `### Changed`: 겹침 판정이 폴더와 그 안의 공유 파일을 어느 순서로 적어도 겹침으로 보지 않는다 · spec 리뷰 이웃 결정이 동시 가능 에픽을 싣고 `U` · `D` 결정 줄도 읽는다 · 게이트 정본의 「지휘자 아래 승인 질문에는 둘째 질문이 없다」 문장이 병렬 질문만 허용한다. 한 항목 한 줄.

- [ ] **Step 1: 실패하는 락을 쓴다** — AC16 · AC4 README: `plugin.json` 판이 `8.11.0`, CHANGELOG 첫 판 머리가 `## [8.11.0] — 2026-10-25` 이고 그 판 절에 `shared_files` · `동시에 갈 수 있는 준비 에픽` · `intents` · `일곱째 이음매` 가 있다. README 에 `` | `shared_files` | `` 행 · `키는 위 열뿐이다` · `키는 위 아홉뿐이다` 없음.

- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` Expected: ✗.

- [ ] **Step 3: 문면을 고친다.**

- [ ] **Step 4: 통과를 본다** — Run: Step 2 · `bash plugins/spec-distill/tests/test_readme_sync.sh` · 전체 스위트 `bash tools/suite/run-all.sh`(공유 스위트 잠금이 있으면 그 아래서) Expected: 실패 0.

- [ ] **Step 5: 커밋** — `chore(spec-distill): 8.11.0 — README · CHANGELOG · 판` + Spec 트레일러.

---

### Task 11: 변이로 이빨 확인(AC15) · 끝에서 끝

**AC:** AC15

락과 테스트가 그 문장 · 조건을 지우면 RED 가 되는지 본다. 고치는 과제가 아니다 — RED 가 안 나는 변이가 있으면 그 락 · 테스트를 고치는 커밋을 더한다.

- [ ] **Step 1: 변이 전 깨끗한지** — Run: `git status --porcelain` Expected: 빈 출력(모두 커밋됨).

- [ ] **Step 2: 양성 대조** — 변이 없이 `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` 와 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py` 가 실패 0 인지 본다.

- [ ] **Step 3: 변이 하나씩** — 각 변이 뒤 해당 테스트를 돌려 실패가 1 이상인지 적고 `git checkout HEAD -- <파일>` 로 되돌린 뒤 `git diff HEAD --stat` 가 빈지 본다(`PYTHONDONTWRITEBYTECODE=1`).

| 변이 | 돌릴 테스트 | 기대 |
|---|---|---|
| `parallel_line` 의 `준비` 거름 지우기 | `test_parallel_recommend.py` | FAIL |
| `parallel_line` 의 `overlap` 거름 지우기 | 같음 | FAIL |
| `parallel_line` 의 `대기` · `알 수 없음` 거름 지우기(각각) | 같음 | FAIL |
| `overlaps` 대칭을 `not _shared(ea, names)` 로 되돌리기 | 같음 | FAIL |
| `merge_layers` 의 `shared_files` 층 무시를 지우기 | 같음 | FAIL |
| `_shared_files` 의 `/` 검사 · 빈 원소 검사 지우기(각각) | 같음 | FAIL |
| `DECISION_LINE_RE` 에서 `U` · `D` 갈래 지우기(각각) | 같음 | FAIL |
| `neighbors` 의 `parallel` 더하기 지우기 | 같음 | FAIL |
| `review_intents.build` 뺌 조건에서 `merged` · 조상 판정 · 기준 트리 판정 지우기(각각) | 같음 | FAIL |
| `conducting.md` 의 걸음 2 · 손 절차 2 소식 예외 구절(각각) · 끝 줄 소비 문장(두 자리 각각) · 병렬 질문 불릿 · 「차례로」 확인 불릿 · 가리킴 다섯(각각) · 머지 하나씩 · 머지 큐(두 자리 각각) · 걸음 3 조사 문장 지우기 | `test_parallel_recommend_docs.sh` | ✗ |
| 이음매 7 문장 · `tag: intents` · SKILL `<intents>` 지우기(각각) | `test_parallel_recommend_docs.sh` · `shared/tests/test_agent_input_slots.sh` | ✗ |

- [ ] **Step 4: 끝에서 끝** — Run: `python3 plugins/spec-distill/scripts/control_plane.py show --tasks docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md; echo rc=$?` Expected: 오류 없이 작업 줄들, 끝 줄은 탭을 가진다(모든 에픽이 끝나 병렬 판단 줄이 없다).

- [ ] **Step 5: 결과 보고** — 변이 표의 결과(FAIL 이 안 난 변이와 고친 커밋)를 마지막 보고에 싣는다. 락 · 테스트를 고쳤으면 `test(spec-distill): 변이로 드러난 빈 락 보강` + Spec 트레일러로 커밋.
