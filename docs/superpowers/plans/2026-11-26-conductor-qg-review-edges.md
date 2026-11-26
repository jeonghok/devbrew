# R9 — 지휘 절차의 qg 리뷰 뒤처리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 머지 앞 qg 리뷰 한 번의 상태를 지휘자가 쥐는 상태 파일 하나에 모으고, 새 스크립트 `qg_review_state.py` 가 그 파일을 열고 · 옮기고 · 읽어 재리뷰 범위 · 머지 관문 · 다시 들어왔을 때 할 일을 답하게 한다. 지휘 절차 문서는 그 스크립트를 부르는 문장으로 바뀌고, 리뷰 기록은 기록 브랜치에만 쓰며, 답 넘기기 스크립트의 가장자리를 고친다.

**Architecture:** 스크립트는 셋으로 나눈다 — `qg_review_file.py`(상태 파일의 마크다운 꼴을 읽고 쓴다 · 링크를 따르지 않는 원자 쓰기), `qg_review_archive.py`(보관 폴더의 qg 결과를 읽어 「돌아옴」 의 갈래를 낸다), `qg_review_state.py`(명령 일곱과 규칙 — 기준 커밋 · 닫는 조건 · 관문의 까닭 여덟 · 「다음」 표). 「다음」 표는 설계 §4 의 줄을 위에서부터 보는 하나의 목록으로 짓고, 원칙 훑기 테스트(AC31)를 스크립트보다 먼저 써서 그 목록의 틈을 구현 중에 드러낸다. 문서는 스크립트가 선 뒤에 다시 쓴다.

**Tech Stack:** Python 3.9 문법 · 표준 라이브러리(`json` 입력 · `subprocess` git) · PyYAML(`qg_answered.py` 와 qg 의 `findings-pre-merge.yaml` 읽기) · unittest · bash(macOS 3.2 호환) 셸 락(`shared/tests/assert.sh`) · 마크다운 절차 문서.

**Spec:** `docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다. 설계 본문은 고치지 않는다(끝 과제의 `## 미룸` 행만 더한다). 결정 기록의 뒤집힌 줄(D9 · D13 · D16 · D18 · D26 · D41 · D42 · D63)은 옛 글이고 본문과 D71 이 지금 것이다.

## Global Constraints

- 자리 표시 — `<지휘 자원>` 은 지휘자가 보내는 글에 준 이 로드맵의 지휘 자원 폴더(`…/files`), `<spec-distill 설치본>` 은 이 세션이 쓰는 spec-distill 설치본 폴더다. 지휘자가 준 글의 실제 경로로 바꿔 쓴다.
- 한 PR · 한 브랜치(`feature/conductor-qg-review-edges`). 과제 차례대로 커밋한다 — 문서 과제(Task 10–12)는 스크립트 과제(Task 2–9)가 낸 명령 이름과 출력 꼴을 글자로 인용한다.
- 판 번호는 지휘자가 준다. 계획 · 테스트에 판 글자를 박지 않는다(락이 판을 재면 `plugin.json` 에서 읽는다). spec-distill 은 minor(새 스크립트 · 새 동작), quality-gates 는 patch(문서 하나), plugin-audit · project-init 은 공유 `shared/deps/check_deps.py` 의 측정이 바뀌어 함께 올린다(D76) — 올림 단위와 번호는 지휘자가 구현을 보낼 때 주고, 머지 직전에 기본 브랜치의 판이 올라가 있으면 다시 맞춘다.
- 상태 파일은 머지 앞 자리(첫 리뷰 · 좁은 재리뷰 · 구현이 끝난 뒤 이름으로 청한 리뷰)만 쓴다. spec 승인 앞 · 로드맵 끝은 지금 문장을 두고 spec 쪽 다시 보내기 표지에 설계문서 커밋만 더한다(설계 Non-goals · D6).
- 스크립트는 상태 파일 · 그 파일에 적힌 경로의 파일 · 보관 폴더 · git · 지휘자가 넘긴 인자(살아 있는 담당자 이름 · `--no-qg` · 뺄 파일)만 본다. 대화 · PR 본문 · 기록 파일 · 기계 상태의 쌓인 기록 줄은 읽지 않는다.
- 상태를 옮기는 명령은 `send` · `back` · `record` 셋뿐이다. `open` 은 새 상태 파일만 만들고 앞 리뷰를 건드리지 않는다. 닫기만 하는 명령은 없다(AC1 · AC26).
- 쓰기 명령은 그 대상(PR 또는 과제 · 계획)의 **마지막 리뷰**에만 쓴다 — 상태 파일 경로를 인자로 받지 않는다.
- 입력의 글은 데이터다 — 지적 원문 · 질문 글 · 답 원문은 인자가 아니라 JSON 입력 파일(`record --input`)로 받고, 셸 따옴표 안에 넣지 않는다. git 은 `subprocess.run([...])` 목록 인자로만 부른다.
- 비신뢰 꼴 검사는 `fullmatch`. 상태 파일을 읽다 꼴이 하나라도 어긋나면 그 파일을 「읽지 못함」 으로 다룬다(지우거나 고치지 않는다) — `next` 는 끝 줄(상태 보이기), `gate` 는 닫힘.
- Python 3.9 문법. `plugins/*/scripts/*.py` 의 `open(` · `.read_text(` · `.write_text(` 에 `encoding="utf-8"`(`test_utf8_explicit.py`). `.py` 에 `"python3"` 리터럴 금지(`test_python_floor.sh`). `re.compile` 에 `#` · `^##` 로 시작하는 패턴을 쓰지 않는다 — 머리 줄은 문자열 메서드로 본다. 긴 한글 문자열 리터럴은 인접 문자열로 나눈다(CPython 토크나이저).
- 새 Python 테스트의 `class Test…` 줄은 모두 `(unittest.TestCase)` 를 직접 적는다 — 도우미는 바탕 클래스로 물려받지 않고 `setUp` 에서 `self.rig = Rig(self)` 로 만든다(qg 의 unittest 어댑터가 `class Test` 줄에 `TestCase` 글자가 없는 파일을 맡지 않는다). 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755` 인지 본다. bash 3.2 — `$var` 바로 뒤에 한글 · 낫표가 오면 `${var}` 로 쓴다.
- 락은 본문에만 있는 글로 묶는다(제목이 문구를 만족시키지 않게). 부재 단언마다 양의 짝. 글자 락만 남는 자리는 변이 둘(그 줄 지우기 · 뜻 뒤집기)로 이빨을 본다 — 변이 전에 커밋하고 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 가 빈지 본다. `PYTHONDONTWRITEBYTECODE=1`.
- 고친 문서는 `plugins/spec-distill/tests/test_repo_literals.sh` 규칙(기본 브랜치 이름 · 접두 · 구조 경로 · 모델 이름을 박지 않음)과 `shared/style/plain-language.md` 를 따른다. 문구 락을 새로 둘 때는 `docs/testing.md` 「글자 대조 말고 쓰는 확인」 을 따른다(실행 블록은 뽑아 돌리고, 예시 · 틀은 읽는 코드에 먹여 꼴을 잰다). `plugins/spec-distill/tests/evals/` 에는 이 일이 닿는 글을 지키는 케이스가 없다(계획 때 확인) — 새로 생겼으면 그 PR 에서 돌린다.
- 커밋: Conventional Commits(`type`·`scope` 영어 · 설명 한국어), pathspec 커밋, 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md` 와 지휘자가 보내는 글에 준 끝 줄. 레포에 커밋하는 파일에 사용자 이름이 든 절대경로를 넣지 않는다.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기(reset · rebase · force) · push(지휘자가 한다).
- 임시 파일은 지휘자가 준 `TMPDIR`(`<지휘 자원>/tmp/<담당자 이름>`)에 쓴다.
- **전체 스위트는 공유 잠금 아래서만:** `python3 "<spec-distill 설치본>"/scripts/suite_lock.py run --lock <지휘 자원>/suite-lock --owner <담당자 이름> --wait 1800 -- bash -c 'bash tools/suite/run-all.sh'`. 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 못 잡으면 주인 · 잡은 시각을 보고한다. 과제 안에서는 그 과제의 좁은 테스트만 잠금 없이 돌린다 — `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest <모듈> -v` 또는 `bash plugins/spec-distill/tests/<파일>.sh`.

## Review Focus

1. **상태 파일을 손으로 고쳐 꼴이 깨짐**(칸 하나가 지워짐 · 단계 값이 틀 밖 · 들여쓰기가 풀린 원문) — 사람은 스크립트가 짐작해 고치지 않고, 관문이 닫힌 채 지금 값을 보이기를 기대한다. 테스트: Task 2 `test_malformed_state_is_unreadable` · Task 7 `test_next_unreadable_state_shows_values`.
2. **지적 원문에 `## ` 줄 · 백틱 펜스 · ` · ` · 맨 앞 `- ` 가 든다** — 상태 파일에 옮기고 다시 읽어도 원문 글자가 같고, team 형식 펜스 글이 한 번 열리고 한 번 닫힌다. 테스트: Task 2 `test_roundtrip_hostile_text` · Task 8 `test_team_fence_outer_longer`.
3. **두 PR(또는 같은 과제의 두 계획)의 리뷰가 같은 보고 폴더 나무에 섞인다** — 한 대상의 「마지막 리뷰」 가 다른 대상의 파일이 되지 않는다. 테스트: Task 2 `test_targets_do_not_mix`(AC20).
4. **보내는 중에 끊겼는데 보관 폴더에 「이미 답한 것」 파일 · 알림 파일만 있다** — 지휘자가 보내기 전에 만든 파일뿐이면 아직 나가지 않은 것으로 보고 보낸다. 담당자가 옮긴 파일이 하나라도 있으면(결과 파일이 없어도) 돌아온 것으로 보고, 결과 파일이 없으면 사용자에게 묻는다 — 스스로 다시 보내지 않는다(설계 D1 · D75). 테스트: Task 7 `test_sending_only_pre_files_sends` · `test_sending_with_moved_file_is_returned`.
5. **같은 날 같은 자리를 두 번 연다**(다시 보냄 뒤) — 앞 보관 폴더를 덮지 않고 `-2` 로 새 폴더를 만든다. 테스트: Task 4 `test_open_same_day_gets_suffix`.

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 구현을 시작할 때도 그런지 본다. AC 를 직접 맡지 않는다 — 뒤 과제 전부의 전제다. (계획을 짤 때 2026-11-26 브랜치 끝 `72663091` 에서 한 번 봤다 — 어긋남 하나(거른 질문 목록 이름)는 D71 로 정했고 나머지는 그대로였다.)

**Files:** 읽기만. 결과는 `TMPDIR/recheck.md` 에 적고 마지막 보고에 싣는다.

- [ ] **Step 1: 바탕.** `git fetch origin` 뒤 `git log --oneline HEAD..origin/HEAD -- plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/references/conducting.md plugins/spec-distill/scripts/qg_answered.py plugins/spec-distill/scripts/conductor_ledger.py plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/scripts/intent_critic.py` 로 기본 브랜치가 그 파일을 고쳤는지 본다(R7 · R8 머지 여부). 고쳤으면 멈추고 보고한다 — 합칠 때를 지휘자가 정한다.
- [ ] **Step 2: qg 쪽 꼴.** `intent_critic.py` 의 결과 절 목록 머리 셋(`상한 넘어 남김:` · `이미 답한 질문이라 거른 질문:` · `이미 「잘못 골랐다」 답이 있어 거른 질문:`)과 `wrong` 이 `filtered` 의 부분집합인 조건, `state-file-format.md` 의 `## 판정` · `## 범위` · `## 고칠 목록`(`### 막는 지적` · `### 제안` · `### 차등 회귀`) 절과 돌려주는 꼴의 `state` 값(`묻지 않음` · `상한 넘어 남김`) · `reviewed_head` · `reviewed_base`, `synthesize_findings.py` 의 `findings-pre-merge.yaml`(`findings:` 목록), 리뷰할 것 없음의 판정 `not-certified (trivia)` · `not-certified (scope-empty)` 가 그대로인지 본다.
- [ ] **Step 3: 지휘 쪽 자리.** `team-files.md` §1 파일 표 · 「검수 결과 파일」 · §15, `conductor_ledger.py` 의 `write-sections` · `flush` 의 team 갈래 · `resource-dir` · `record --line` 의 줄 나눔 거절(`_one_line`), `qg-review.md` 의 「이미 보낸 것」(이름으로 청한 리뷰 줄 · spec 줄) · 의도 점검 질문의 「다시 띄우지 않는다」 · 증인 문장(「승인 기록 다시 보이기가 머지 앞 기록 파일의 `- 답:` 줄을 자리 글자로 찾아 읽는다」), `conducting.md` 걸음 1 의 원천 두 불릿 · 「잠금 대기는 멈춤이 아니라 줄이다」 · 걸음 5 · 「검수 걸음의 qg」 가 있는지 본다.
- [ ] **Step 4: 판.** 두 `plugin.json` 의 판을 적는다(지휘자가 줄 번호의 바탕).
- [ ] **Step 5:** 모두 같으면 「다시 확인 — 달라진 것 없음」 한 줄을 `recheck.md` 에 적고 다음 과제로 간다. 하나라도 다르면 무엇이 어떻게 달라졌는지 적고 멈춘다.

---

### Task 2: 상태 파일의 꼴 — 읽고 쓰기

**AC:** AC1(칸 열하나 · 사유 여덟) · AC20(대상이 섞이지 않음) · AC29(링크를 따르지 않는 원자 쓰기).

**Files:**
- Create: `plugins/spec-distill/scripts/qg_review_file.py`
- Create: `plugins/spec-distill/tests/qg_review_state_fixture.py`(테스트 도우미 — 임시 리포 · 기계 상태 · 보관 폴더 · qg 결과 파일 짓기. `test_*` 이 아니라 스위트가 따로 돌리지 않는다)
- Test: `plugins/spec-distill/tests/test_qg_review_file.py`

**Interfaces:**
- Produces:
  - `STATE_NAME = "qg-review-state.md"` — 보관 폴더 안 상태 파일 이름.
  - `STAGES = ("열림", "보내는 중", "보냄", "돌아옴", "닫힘")`
  - `CLOSE_REASONS = ("막는 지적 없음", "재리뷰로 이어짐", "사용자가 남김", "리뷰 없이 감", "다시 보냄", "「잘못 골랐다」 — 설계 대화로", "「잘못 골랐다」 — 재분해 신호", "에픽을 멈춤")`
  - `HANDLINGS` — 처리 값: `처리 없음` · `고친 커밋 <해시>` · `반박` · `손대지 않음` · `손대지 않음 — 처리 파일 없이 끝남` · `손대지 않음 — 적어 낸 커밋이 범위에 없음` · `다시 돌려보냄` · `사용자가 남김` · `리뷰 없이 가기로 함`(`고친 커밋` 과 `반박` · `손대지 않음` 은 ` — <글>` 꼬리를 받는다).
  - `RETURN_MOVED = ("옮김", "아직", "처리 파일 없이 끝남", "옮겼으나 범위 밖 커밋")`
  - `@dataclass Review` — 칸 열하나: `site`(자리 · `premerge`|`recheck`|`asked`) · `site_tag`(자리 글자) · `target`(대상) · `order`(그 대상 안의 차례, 1부터) · `range_start` · `range_end` · `stage` · `close_reason` · `close_mark`(`다시 구현됨 <때>` | `재분해 뒤 이어 감 <때>` | `""`) · `worker`(이름 · 때) · `result`(`Result`) · `blocking`(`list[Finding]`) · `returns`(`list[ReturnLine]`) · `filtered_wrong`(`list[Filtered]` — 행선 칸 포함) · `filtered_other`(`list[Filtered]`) · `asks`(`list[Ask]` — `kind` ∈ `의도 점검` · `지적 목록을 얻지 못함` · `고치지 않은 막는 지적` · `두 번까지` · `담당자가 옮긴 질문`) · `answers`(`list[Answer]` — 질문 정체 · 종류 · 답 · 답 원문 · 기록 경로(`""` | 경로 | `기록 브랜치 없음 — <사유>`) · 적은 때) · `stop_rule`(멈출 조건 글).
  - `read_review(path: Path) -> Review` — 꼴이 하나라도 어긋나면 `Unreadable(사유)`.
  - `write_review(path: Path, review: Review) -> None` — `nofollow_write.replace_bytes` 로 쓴다.
  - `reviews_for(report_root: Path, target: str) -> list[Review]` — `report_root/*/qg-review-state.md` 가운데 `target` 이 같은 것을 `order` 차례로. 같은 대상 안에 `order` 가 겹치거나 비면 `Unreadable`.

- [ ] **Step 1: 실패하는 테스트를 쓴다.**
  - `test_roundtrip_all_fields` — 칸 열하나를 모두 채운 `Review` 를 쓰고 읽으면 같다. 쓴 파일의 `## ` 머리가 칸 열하나(자리 · 대상 · 범위 · 단계 · 담당자는 머리 목록, 나머지 여섯은 절)와 정확히 맞는다.
  - `test_roundtrip_hostile_text` — 지적 원문에 `## 판정` 줄 · ```` ``` ```` · ` · ` · 맨 앞 `- 처리:` · 빈 줄 · 끝 공백이 있어도 읽은 원문이 글자 그대로다.
  - `test_malformed_state_is_unreadable` — 단계 값 `반쯤` · 닫힘인데 사유 없음 · 사유가 여덟 밖 · 들여쓰기 풀린 원문 줄 · `## 막는 지적` 절 머리 지움 · 끝 개행 뒤 `열림\n` 꼴 값 — 모두 `Unreadable`.
  - `test_symlink_target_untouched` — 상태 파일 자리에 다른 파일로 가는 심볼릭 링크를 두고 `write_review` 를 부르면 링크 너머 파일의 바이트가 그대로고 상태 파일 자리는 보통 파일이 된다(AC29).
  - `test_interrupted_write_leaves_old_or_new` — `os.replace` 를 막아(목 객체로 `OSError`) 부르면 예외가 나고 앞 내용 그대로 · 임시 파일이 남지 않는다(AC29).
  - `test_targets_do_not_mix` — 대상 `pr12` 둘 · `pr13` 하나 · `T3-plan1` 하나 · `T3-plan2` 하나를 한 `report_root` 에 두면 `reviews_for(root, "pr12")` 는 둘, `"T3-plan2"` 는 하나만 낸다(AC20).
- [ ] **Step 2:** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_file -v` — 모듈이 없어 FAIL.
- [ ] **Step 3: `qg_review_file.py` 를 짓는다.** 꼴은 이렇다 — 첫 줄 `# qg 리뷰 상태`, 판 줄 `- 판: 1`, 머리 목록 `- 이름: 값`(자리 · 자리 글자 · 대상 · 차례 · 범위 `<시작>..<끝>` · 단계 · 닫힘 사유 · 닫힘 표시 · 담당자), 그 뒤 절 `## 돌아온 결과` · `## 막는 지적` · `## 돌려보냄` · `## 거른 질문` · `## 물을 것` · `## 사용자 답` · `## 멈출 조건`. 목록 절의 항목은 `### <번호>` 아래 `- 이름: 값` 줄이고, 여러 줄 값(원문 · 질문 글 · 답 원문)은 `- 원문:` 다음 줄부터 두 칸 들여 쓴다(빈 줄은 두 칸만). 머리 줄은 `startswith` 로 가르고 값은 `fullmatch` 로 본다. 쓰기는 `nofollow_write.replace_bytes`.
- [ ] **Step 4:** 같은 명령으로 PASS.
- [ ] **Step 5: 도우미.** `qg_review_state_fixture.py` 에 `class Rig` — 바탕 클래스 없는 도우미로 `Rig(testcase)` 가 `testcase.addCleanup` 으로 치우며, 만들 때 임시 리포(`git init -b trunk-x`, 이름 · 메일 · 서명 끔 — `test_merged_pr_range.py` 의 `Repo` 꼴), 기계 상태(`test_conductor_ledger.py` 가 기계 상태를 짓는 길을 따른다), 도우미 `commit(paths: dict, msg) -> sha` · `merge_commit()` · `rewrite_branch()` · `write_result(folder, verdict, start, end, blocking=[], regress=[], filtered=[], wrong=[], over=[], trivia=False)`(qg 결과 파일 `result.md` 를 `state-file-format.md` 꼴로) · `write_pre_merge(folder, findings)`(`findings-pre-merge.yaml`) · `write_intent_return(folder, questions)`(돌려주는 꼴 3판 — 질문마다 `state`) · `write_handling(path, items, header=True)`(처리 파일 — `header` 가 참이면 `## 지적마다의 처리` 머리를 둔다) · `run(*args) -> CompletedProcess`(스크립트를 `sys.executable` 로). Task 3 이후가 이 이름을 쓴다.
- [ ] **Step 6: 커밋.** `git add plugins/spec-distill/scripts/qg_review_file.py plugins/spec-distill/tests/qg_review_state_fixture.py plugins/spec-distill/tests/test_qg_review_file.py && git commit -m "feat(conductor): 머지 앞 리뷰 상태 파일의 꼴" -- <같은 경로>`

---

### Task 3: 원칙 훑기 테스트 먼저 (AC31)

설계의 뼈대(관문이 닫히는 까닭마다 그것을 푸는 할 일 하나 · 「다음」 이 「열기」 를 내는 상태 = 「열기」 가 받는 상태)를 재는 테스트를 스크립트보다 먼저 쓴다. 이 과제가 끝날 때 테스트는 RED 이고(명령이 아직 없다), Task 7 이 끝날 때 GREEN 이 된다. 그 사이 과제마다 이 테스트의 몇 줄이 풀린다.

**AC:** AC31 · AC32(세 경우와 예외) · AC9(재분해 표시 앞뒤) · AC33(받는 상태 여섯).

**Files:**
- Create: `plugins/spec-distill/tests/test_qg_review_state_sweep.py`

**Interfaces:**
- Consumes: Task 2 `Rig` · `Review` · `write_review`.
- Produces:
  - **표의 정본은 하나다** — 구현의 `qg_review_state.NEXT_ROWS`(Task 7)가 설계 §4 표의 줄마다 `Row(id, reason, kind, conductor_choices)` 를 갖고, 테스트는 그 표를 읽는다. 테스트 쪽에는 줄 id 마다 상태를 짓는 픽스처 `BUILD[id](rig)` 와 그 할 일을 하는 `DO[id](rig, out)` 만 두고 줄의 꼴 · 까닭을 다시 적지 않는다. 테스트는 `{row.id for row in NEXT_ROWS}` 가 `EXPECTED_IDS`(아래 Step 1 의 id 집합 — 설계 §4 표의 줄 수와 같은 수로 핀)와 같은지, `BUILD` · `DO` 의 키가 그 집합을 덮는지 먼저 잰다.
  - **한계** — 정본을 공유하므로 구현의 한 줄의 `kind` · `reason` 이 설계와 다르게 적혀도 이 테스트는 그 줄 안에서 그것을 잡지 못한다(줄을 빼거나 더한 것은 id 집합 핀이 잡는다). 그래서 `EXPECTED` 표 — 줄 id 마다 설계 §4 의 「까닭」 칸 번호와 「할 일」 의 꼴 낱말 — 를 테스트에 한 번 더 손으로 적어 `NEXT_ROWS` 와 견준다. 이 대조표는 줄의 꼴과 까닭 두 칸만 싣는다(맞는 조건은 싣지 않는다 — 조건은 픽스처가 상태로 재고, 할 일 뒤의 움직임은 아래 테스트가 잰다).
  - `next` 출력의 둘째 줄 `줄 · <id>` — 테스트가 어느 줄이 맞았는지 이 줄로 단언한다(Task 7 이 낸다). 꼴 낱말은 열: `열기` · `보냄` · `돌아옴` · `답 적기` · `사용자 차례` · `기다린다` · `돌려보낸다` · `기록 파일 쓰기` · `머지 준비` · `상태 보이기`.

- [ ] **Step 1: 줄 id 집합을 적는다.** 설계 §4 표의 줄을 위에서부터 하나도 빼지 않고 — `R0`(qg 없음 · 상태 파일 없음) · `R8a`(상태 파일 없음) · `R1a`(열림) · `R1b`(보내는 중 · 담당자 이름 없음) · `R1c`(보냄 · 담당자가 옮긴 질문) · `R1d`(보냄 · 살아 있음) · `R1e`(보냄 · 없음) · `R2`(에픽을 멈춤) · `R3a`(얻지 못함 · 답 없음) · `R3b`(다시 보냄 · 새 리뷰 없음) · `R4`(물을 것) · `R5`(기록 경로 빔) · `R6a`(「잘못 골랐다」 · 행선 없음) · `R6b`(설계 대화로 · 표시 없음) · `R6c`(설계 대화로 · 「다시 구현됨」) · `R6d`(재분해 · 표시 없음) · `R6e`(재분해 · 「재분해 뒤 이어 감」) · `R7a`(아직 · 살아 있음) · `R7b`(아직 · 없음 · 처리 파일 있음) · `R7c`(아직 · 없음 · 처리 파일 없음) · `R7d`(돌아옴 · 처리 없음 · 상한 안) · `R7e`(재리뷰로 이어짐 · 기준 커밋 있음) · `R7f`(재리뷰로 이어짐 · 기준 커밋 없음) · `R8b`(이름으로 청한 리뷰만 닫힘) · `R9`(까닭 없음) · `RX`(끝 줄) — 26 줄. 한 줄 안의 변형(R1b 의 옮긴 파일 있음/없음 · R4 의 질문 종류 셋 · R6a 의 돌아옴/닫힘 · R7c 의 첫째/둘째 · R7e 의 상한 안/「두 번까지」 답 · R9 의 닫힘 사유 셋)은 `BUILD[id]` 가 목록으로 낸다.
- [ ] **Step 2: 훑기 테스트를 쓴다.**
  - `test_table_ids_match_design` — 위 집합 · `EXPECTED` 대조(줄마다 까닭 번호 · 꼴 낱말)와 `NEXT_ROWS` 가 같다.
  - `test_each_row_yields_its_action` — `RX` 를 뺀 줄의 변형마다 상태를 지어 `next` 를 부르면 `줄 · <그 id>` 와 `까닭 · <그 줄의 번호>` 가 나오고 꼴 낱말이 그 줄의 것이다. `RX` 만 `상태 보이기`.
  - `test_action_resolves_reason` — `RX` · `R0` · `R9` 를 뺀 줄의 변형마다 `DO` 를 한 뒤(스크립트 명령 · 사용자 차례면 그 답을 `record` 로 적은 뒤 · `기다린다` 면 그 이름을 `--alive` 에서 뺀 뒤 · 설계 대화면 `record` 로 「다시 구현됨」 · 재분해면 「재분해 뒤 이어 감」) 다시 부르면 같은 줄 id 가 나오지 않는다 — 그 줄이 푸는 까닭이 풀렸거나 다른 줄(다음 걸음)이 맞는다. 나온 줄이 같은 까닭의 다른 줄이면 그 줄이 표의 「그 할 일 뒤 상태」 칸에 적힌 줄이어야 한다(`AFTER[id]` — 설계 §4 의 그 칸을 줄 id 집합으로 옮긴 것).
  - `test_conductor_choices_accepted` — 「지휘자가 가린다」 줄(`R1b` · `R1c` · `R7c`)마다 그 줄의 `conductor_choices`(예: `R1b` 는 `send --phase done --worker <이름>`, `R1c` 는 `back`, `R7c` 는 처리를 담은 `record`)를 부르면 rc 0 이고, 그 뒤 `next` 의 줄 id 가 `AFTER[id]` 가운데 하나다.
  - `test_next_open_is_accepted` — `next` 가 `열기` 를 낸 줄의 변형마다 같은 인자로 `open` 을 부르면 rc 0 이고 새 상태 파일이 생긴다.
  - `test_open_refused_where_next_does_not_open` — `열기` 를 내지 않는 줄의 변형마다 `open --site premerge` · `open --site recheck` 가 rc 4 이고 상태 파일 수가 그대로다. 마지막 리뷰가 닫히지 않은(열림 · 보내는 중 · 보냄 · 돌아옴) 모든 변형에서 `open --site asked` 도 rc 4 이고 그 상태의 `next` 줄들을 함께 낸다(AC33). 마지막 리뷰가 닫혔어도 「에픽을 멈춤」(`R2`) · 표시 없는 「잘못 골랐다」(`R6b` · `R6d` · 거른 「잘못 골랐다」 목록이 설계 대화를 기다리는 변형)이면 `--site asked` 도 rc 4 · 까닭 · 그 상태의 `next` 줄들이다(AC9 · D77 · D78). 표시를 붙인 뒤(`R6c` · `R6e`)와 그 밖의 닫힌 변형에서 `--site asked` 는 받는다 — 거절과 표시 뒤 받음을 함께 잰다.
  - `test_closed_reasons_sweep` — 닫힘 사유 여덟으로 닫힌 마지막 리뷰마다 `next` 가 `RX` 를 내지 않는다.
  - `test_gate_open_states_go_to_merge` — `R0` · `R9` 의 변형에서 `next` 가 `머지 준비` 를 내고 `gate` 가 rc 0.
  - `test_cap_cases` — AC32 의 (가)(나)와 「잘못 골랐다」 가 함께 있는 경우 · 예외(「두 번까지」 답 뒤 기준 커밋으로 재리뷰로 이어짐) 넷 — (가)(나)는 「두 번까지」 답이 없는 동안 `next` 가 `R4` 이고 `돌려보낸다` 도 `열기` 도 내지 않으며 `open --site recheck` 는 rc 4, 「잘못 골랐다」 경우는 물을 것에 「두 번까지」 가 없고 `next` 가 `R6a`, 예외는 `next` 가 `R7e` 이고 `open` 이 받는다.
  - `test_resplit_mark` — 재분해 신호로 닫힌 PR 에서 표시 전에는 `R6d` 이고 `open --site premerge` 가 rc 4, 표시 뒤에는 `R6e` · 첫 리뷰(PR 전체 범위)가 열리고 `gate` 와 세는 재리뷰 수가 그 리뷰부터 센다(AC9).
- [ ] **Step 3:** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state_sweep -v` — `qg_review_state.py` 가 없어 모두 FAIL(ERROR). 이 출력을 `TMPDIR/sweep-red.txt` 에 남긴다.
- [ ] **Step 4: 커밋.** `git commit -m "test(conductor): 리뷰 상태 원칙 훑기 테스트를 먼저 둔다" -- plugins/spec-distill/tests/test_qg_review_state_sweep.py`

이 테스트를 짓다가 §4 표로 상태를 지을 수 없는 줄이나, 할 일을 한 뒤에도 같은 할 일 · 같은 상태가 되는 줄이 나오면 그 줄을 적고 멈춰 보고한다 — 설계의 글자 · 수용 기준 · 보이는 동작을 바꿔야 풀리는 틈이면 스스로 정하지 않는다.

---

### Task 4: 기준 커밋 · 범위 · 「열기」

**AC:** AC4(기준 커밋 · 시작 · merge 커밋 · 세는 수와 상한) · AC5(이름으로 청한 리뷰) · AC19(옛 흔적) · AC33(받는 상태) · AC9(설계 대화 · 재분해 표시 뒤 첫 리뷰).

**Files:**
- Create: `plugins/spec-distill/scripts/qg_review_state.py`
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(`c_resource_dir` 의 몸통을 `resource_dir(root, roadmap, kind, name) -> Path` 로 떼어 `c_resource_dir` 가 부른다 · `## 자원` 줄을 더하는 몸통을 `add_resource(root, roadmap, session, cells) -> None` 로 뗀다 — 동작 그대로)
- Test: `plugins/spec-distill/tests/test_qg_review_state.py`

**Interfaces:**
- Consumes: Task 2 전부 · `conductor_ledger.resource_dir` · `conductor_ledger.add_resource` · `conductor_ledger.mdir_for_write`.
- Produces:
  - 명령줄 `qg_review_state.py <명령> --roadmap <로드맵 레포 상대경로> --target <대상> [--repo <레포>] [--at <YYYY-MM-DD HH:MM>]`. 대상은 옛 형식 `pr<번호>`, team 형식 `<과제>-plan<n>`. 뺄 파일은 `--spec <설계문서 레포 상대경로>`(옛 형식) 또는 `--job-dir <과제 폴더 레포 상대경로>`(team) 가운데 정확히 하나 — `open` · `record` · `next` · `gate` 에 필수.
  - 종료 코드: 0 됨(관문 열림 포함) · 1 관문 닫힘 · 2 사용법 · 3 파일을 읽거나 쓰지 못함(상태 파일 읽지 못함 포함) · 4 받지 않음(`open` 거절 · 그 상태에서 할 수 없는 쓰기).
  - `base_commits(repo, start, end, exclude: list[str]) -> list[str]` — `git log --format=%H <start>..<end> -- . :(exclude)<각 경로>` 의 커밋(옛 형식 `[spec]`, team 형식 `[<job>/INTENT.md, <job>/results/review-*]` 를 `:(exclude,glob)` 로). merge 커밋은 따로 `has_merge(repo, start, end) -> bool`.
  - `counted_rechecks(reviews) -> int` · `cap(reviews) -> int`(처음 2, 「두 번까지」 답이 「한 번 더 돌려보낸다」 인 리뷰마다 그 리뷰까지의 세는 수 + 1) · `counting_from(reviews) -> list[Review]`(「다시 구현됨」 · 「재분해 뒤 이어 감」 표시가 붙은 마지막 리뷰 뒤부터).
  - `open_accepts(reviews, git_state, site) -> (bool, 까닭)` — 설계 §2 「「열기」 가 받는 상태」 여섯. Task 7 의 `next` 가 같은 함수를 부른다. `asked` 는 마지막 리뷰가 닫혔어도 「에픽을 멈춤」 · 표시 없는 「잘못 골랐다」(설계 대화로 · 재분해 신호 · 거른 「잘못 골랐다」 목록이 설계 대화를 기다림)면 받지 않는다 — `next` 의 까닭 2 · 까닭 6 줄과 같은 판정이라 그 거절은 Task 7 이 `NEXT_ROWS` 위에서 더한다(D77 · D78).
  - `open` 명령: `open ... --site {premerge,recheck,asked} --base <기본 브랜치 ref> --head <리뷰받는 브랜치 ref> --epic <에픽> --session <세션> [--legacy-trace {pr-body,ledger}]...`(`--legacy-trace` 는 스크립트가 볼 수 없는 옛 흔적 — PR 본문의 `## qg 리뷰` 절 · 쌓인 기록의 머지 앞 qg 줄 — 을 지휘자가 보고 넘긴다) → 받으면 rc 0 과 줄 셋 `보관 폴더 · <절대경로>` · `범위 · <시작>..<끝>` · `자리 글자 · <글자>`(옛 흔적이면 넷째 줄 `알림 · 옛 흔적이 있다 — PR 전체를 처음부터 리뷰한다`), 받지 않으면 rc 4 와 `까닭 · <글>` 한 줄, 그 뒤에 그 상태에서 `next` 가 내는 줄들을 그대로(첫 줄 `할 일 · …`).

- [ ] **Step 1: 실패하는 테스트를 쓴다.** (`Rig` 위에서)
  - `test_base_commits_old_format` — 설계문서만 바꾼 커밋은 빠지고, 다른 파일을 바꾼 커밋 · 설계문서와 다른 파일을 함께 바꾼 커밋은 든다.
  - `test_base_commits_team_format` — 검수 결과 파일(`results/review-1.md`) · INTENT.md 만 바꾼 커밋은 빠지고, 처리만 적은 구현 결과 파일(`results/impl-2.md`) · 과제의 `design.md` 를 바꾼 커밋은 든다(AC4 · §9).
  - `test_recheck_start_is_last_obtained_end` — 열기만 한 리뷰 · 얻지 못한 리뷰가 뒤에 있어도 시작은 지적 목록을 얻은 마지막 리뷰의 끝이다.
  - `test_merge_commit_widens_to_whole_pr` — 범위에 merge 커밋이 있으면 시작이 `merge-base(base, head)` 이고 세는 재리뷰 하나로 센다.
  - `test_recheck_refused_without_base_commit` — 재리뷰로 이어짐으로 닫혔는데 리더 기록 파일만 바꾼 커밋으로 끝이 움직였으면 `open --site recheck` 는 rc 4.
  - `test_cap_counts_only_obtained_rechecks` — 얻지 못해 다시 보낸 재리뷰 · 이름으로 청한 리뷰는 세지 않고, 그 뒤 좁은 재리뷰는 센다. 「한 번 더」 답 뒤 상한이 그때의 수 + 1(AC4 · AC5).
  - `test_named_review_does_not_replace_first` — 이름으로 청한 리뷰만 닫혀 있으면 `open --site premerge` 가 받고(첫 리뷰), 관문은 그 전까지 까닭 8(AC5).
  - `test_open_refused_while_last_not_closed` — 마지막 리뷰가 돌아옴이면 `--site asked` 가 rc 4 이고 상태 파일 수가 그대로(AC33). 「에픽을 멈춤」 · 표시 없는 「잘못 골랐다」 로 닫힌 뒤의 거절과 표시 뒤의 받음은 Task 3 의 `test_open_refused_where_next_does_not_open` 이 재고 Task 7 에서 GREEN 이 된다.
  - `test_legacy_traces_open_whole_pr` — 상태 파일이 없고 옛 흔적이 셋 가운데 어느 것이든 있으면(같은 대상의 상태 파일 없는 옛 보관 폴더 · `--legacy-trace pr-body` · `--legacy-trace ledger`) 받고, 범위는 PR 전체(옛 흔적의 범위 · 횟수를 쓰지 않는다), 넷째 줄 알림을 낸다. `--legacy-trace pr-body` 면 다섯째 줄 `할 일 · 사용자 차례 · 옛 PR 본문의 막는 지적과 사용자 답을 한 번 보인다` 를 낸다(AC19 · 설계 §9).
  - `test_open_same_day_gets_suffix` — 같은 이름의 보관 폴더가 있으면 `-2` 로 새로 만들고 앞 폴더의 파일은 그대로다.
  - `test_open_writes_resource_line` — 연 뒤 `ledger resources` 에 그 보관 폴더가 한 줄 있다.
  - `test_reopen_after_design_mark` — 「잘못 골랐다」 — 설계 대화로 닫힘에 표시가 없으면 고친 설계문서 커밋이 있어도 rc 4, 표시가 붙으면 첫 리뷰를 받는다(AC9).
- [ ] **Step 2:** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state -v` — FAIL.
- [ ] **Step 3: 짓는다.** `qg_review_state.py` 에 명령줄 뼈대(일곱 명령의 하위 파서 · 공통 인자 · 종료 코드)와 위 함수 · `open` 을 짓는다. 보관 폴더 이름은 지금 규칙 그대로 `qg-<대상 에픽 또는 과제>-<자리 글자>-<날짜>`(같은 이름이 있으면 `-2`, `-3` …) — `resource_dir` 로 만들고 `add_resource` 로 `## 자원` 에 적는다(`<종류>` 칸 `qg 보관`). 옛 흔적은 상태 파일 없는 같은 대상의 qg 보관 폴더가 `report/` 에 있는지와 `--legacy-trace` 로 본다 — PR 본문 · 쌓인 기록은 스크립트가 읽지 않고 지휘자가 보고 넘긴다(Task 10 의 「한 번 보인다」 문장). `conductor_ledger.py` 의 두 함수 떼기는 `test_conductor_ledger.py` 를 그대로 GREEN 으로 둔다.
- [ ] **Step 4:** 같은 명령 PASS · `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_conductor_ledger -v` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(conductor): 리뷰 상태 스크립트 — 기준 커밋과 열기" -- plugins/spec-distill/scripts/qg_review_state.py plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_qg_review_state.py`

---

### Task 5: 「보냄」 · 「돌아옴」

**AC:** AC2(네 갈래) · AC3(원문 · 거른 목록 · `묻지 않음` 만) · AC8(보내는 중 · 담당자가 옮긴 질문) · AC32(나)(「돌아옴」 이 「두 번까지」 를 적음).

**Files:**
- Create: `plugins/spec-distill/scripts/qg_review_archive.py`
- Modify: `plugins/spec-distill/scripts/qg_review_state.py`
- Test: `plugins/spec-distill/tests/test_qg_review_state.py`

**Interfaces:**
- Produces:
  - `read_archive(folder: Path, review: Review) -> Outcome` — `Outcome.kind` ∈ `얻음` · `얻지 못함` · `리뷰할 것 없음`, `reason`(얻지 못함의 사유 글 — 설계 §1 표의 두 문장 글자 그대로), `blocking`(원문 목록 — 종류 `막는 지적` · `새로 깨진 테스트`), `filtered_wrong`, `filtered_other`, `asks`(의도 점검 · `state` 가 `묻지 않음` 인 것만), `verdict_line`, `intent_line`.
  - 결과 파일은 보관 폴더의 `result.md` 다. 판정 절 `## 판정` 이 없으면 얻지 못함(「qg 가 끝까지 돌지 못했다 — 보관한 결과에 판정이 없다」), `## 범위` 의 `start` · `end` 가 상태 파일 범위와 다르면 얻지 못함(「결과가 보낸 범위의 것이 아니다」), 판정이 `not-certified (trivia)` · `not-certified (scope-empty)` 면 리뷰할 것 없음. 막는 지적은 `findings-pre-merge.yaml` 의 `findings:` 에서 막는 등급인 것, 그 파일이 없거나 읽지 못하면 `## 고칠 목록` 의 `### 막는 지적` 에서. 새로 깨진 테스트는 `### 차등 회귀` 에서. `filtered_other` 는 `이미 답한 질문이라 거른 질문:` 목록에서 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록에 든 id 를 뺀 것(D71).
  - `send` 명령: `send ... --phase start` 는 열림 → 보내는 중, `send ... --phase done --worker <이름>` 은 보내는 중 → 보냄(이름 · 때). 다른 단계에서는 rc 4.
  - `back` 명령: 보내는 중 · 보냄 → 돌아옴(또는 바로 닫힘), 출력은 `next` 와 같은 꼴의 할 일 한 줄.
  - 「담당자가 옮긴 질문」 은 `record` 가 적는다(Task 6) — `back` 은 그 질문을 지우지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다.**
  - `test_back_obtained` · `test_back_no_result_md` · `test_back_no_verdict` · `test_back_range_mismatch` · `test_back_trivia_closes_zero` — 네 갈래와 사유 글자(AC2).
  - `test_back_range_from_result_scope_when_intent_blank` — 돌려주는 꼴의 `reviewed_head` · `reviewed_base` 가 `-` 여도 `## 범위` 로 가른다(AC2).
  - `test_back_moves_originals_without_pr_body` — 막는 지적 원문 · 새로 깨진 테스트 원문이 보관 폴더에서 상태 파일로 옮겨지고, `findings-pre-merge.yaml` 을 지운 같은 폴더에서는 `### 막는 지적` 에서 같은 목록이 온다(R7 의 「실패하면 지운다」 길).
  - `test_back_filtered_lists_split` — `이미 답한 질문이라 거른 질문:` 에 셋(그 가운데 하나는 `잘못 골랐다` 목록에도 있다)이면 `filtered_wrong` 하나 · `filtered_other` 둘(D71).
  - `test_back_intent_only_unasked` — 의도 점검 질문 `묻지 않음` · `상한 넘어 남김` · `답함` 이 섞이면 물을 것에 `묻지 않음` 만(AC3).
  - `test_back_intent_unreadable_does_not_block` — 돌려주는 꼴이 없거나 판이 3 이 아니면 「의도 점검은 셀 수 없음」 줄을 남기고 지적 목록을 얻은 대로 다룬다.
  - `test_back_closes_when_nothing` — 막는 지적도 물을 것도 없으면 바로 「막는 지적 없음」 으로 닫힌다(거른 「잘못 골랐다」 목록이 있어도).
  - `test_back_at_cap_adds_two_max` — 세는 재리뷰가 상한에 닿은 PR 에서 막는 지적이 오면 물을 것에 「두 번까지」 가 들고, 같은 결과에 거른 「잘못 골랐다」 목록이 있으면 들지 않는다(AC32).
  - `test_send_phases` — 열림에서 `--phase done` 은 rc 4 · 차례대로 부르면 단계와 담당자 칸이 바뀐다.
- [ ] **Step 2:** FAIL 을 본다(같은 명령).
  - `test_back_without_pyyaml` — `yaml` import 를 막은 하위 프로세스에서 `back` 은 rc 0, 막는 지적을 `### 막는 지적` 에서 옮기고 `알림 · PyYAML 이 없다 — 합치기 전 지적 목록 대신 결과 파일의 고칠 목록에서 옮겼다` 와 「의도 점검은 셀 수 없음」 을 낸다.
- [ ] **Step 3: 짓는다.** `qg_review_archive.py` 는 `yaml` 을 함수 안에서 import 하고(없으면 위 알림과 함께 고칠 목록 · 「의도 점검은 셀 수 없음」 길로 간다), `result.md` 의 절을 `startswith` 로 자르고, `## 범위` 의 `start:` · `end:` 줄과 `## 판정` 첫 줄을 읽는다. YAML 은 `yaml.safe_load` 로, 꼴이 틀리면 그 파일이 없는 것으로 보고 고칠 목록으로 내려간다. 원문의 지적 하나는 고칠 목록의 항목 하나다(합치지 않는다).
- [ ] **Step 4:** PASS. 훑기 테스트에서 `R1a`–`R1e` 의 꼴 단언은 아직 `next` 가 없어 RED 그대로다.
- [ ] **Step 5: 커밋.** `git commit -m "feat(conductor): 리뷰 상태 — 보냄과 돌아옴" -- plugins/spec-distill/scripts/qg_review_archive.py plugins/spec-distill/scripts/qg_review_state.py plugins/spec-distill/tests/test_qg_review_state.py`

---

### Task 6: 「답 적기」 와 닫는 조건

**AC:** AC24(돌려보냄 · 쓸 처리 없이 끝난 세기) · AC26(닫는 조건) · AC27(기록 브랜치 없음) · AC32(가)(고른 제안이 닫힌 리뷰를 되돌림) · AC3(고른 제안 · 되올린 지적이 마지막 리뷰의 칸에) · AC4(고친 커밋 해시 대기) · AC7(리뷰 없이 감이 앞 리뷰의 고친 지적을 닫음).

**Files:**
- Modify: `plugins/spec-distill/scripts/qg_review_state.py`
- Test: `plugins/spec-distill/tests/test_qg_review_state.py`

**Interfaces:**
- Produces: `record ... [--input <JSON 파일>]`. 입력은 `{"items": [...]}`, 항목 `kind` 별 칸:
  - `answer` — `question`(정체) · `ask_kind`(물을 것의 종류) · `value`(답 — 선택지 글자에서 「(권장)」 꼬리를 뗀 것) · `original`(직접 쓴 답 원문, 없으면 `""`)
  - `record_path` — `question` · `path`(기록 파일의 레포 상대경로 또는 `기록 브랜치 없음 — <사유>`)
  - `handling` — `finding`(번호) · `value`(처리 값 — `HANDLINGS` 꼴)
  - `return` — `worker` · `handling_file`(절대경로) — 「돌려보냄」 줄을 `아직` 으로 더한다
  - `return_moved` — `value`(`옮김` · `처리 파일 없이 끝남` — 「옮겼으나 범위 밖 커밋」 은 스크립트가 정한다) · 같은 입력에 `handling` 항목들을 함께 싣는다
  - `pick` — `text`(제안 · 지적 원문) · `from_order`(낸 리뷰의 차례) · `kind`(`고른 제안` · `되올린 지적`)
  - `worker_ask` — `question` · `text`(담당자가 옮긴 질문 글과 요약)
  - `route` — `question` · `value`(`설계 대화로` · `재분해 신호`) — 의도 점검 답 또는 거른 「잘못 골랐다」 질문의 행선
  - `stop_rule` — `text`
  - `mark` — `value`(`다시 구현됨` · `재분해 뒤 이어 감`)
  - 입력 없이 부르면 다시 가리기(아래).
  - 출력은 `next` 와 같은 꼴의 할 일 한 줄. 적어 낸 고친 커밋이 기준 커밋에 없어 되돌렸으면 `알림 · 적어 낸 고친 커밋 <해시> 가 범위에 없다` 를 함께 낸다.

- [ ] **Step 1: 실패하는 테스트를 쓴다.** 닫는 조건은 사유마다 하나 이상 —
  - `test_close_no_blocking_after_answers` · `test_close_rereview_needs_base_commit`(처리가 모두 「사용자가 남김」 이어도 기준 커밋이 있으면 재리뷰로 이어짐) · `test_close_user_left_without_base_commit` · `test_close_without_review` · `test_close_resend` · `test_close_wrong_choice_routes`(의도 점검 답 · 거른 목록의 행선 둘) · `test_close_epic_stop_even_with_asks` · `test_epic_stop_reanswer_reopens`(다른 답을 적으면 돌아옴으로 되돌리고 다시 가리며 앞 답이 사용자 답 칸에 남는다).
  - `test_intent_answer_needs_record_path` — 막는 지적 없이 의도 점검 질문만 온 리뷰에서 답을 적으면 돌아옴에 머물고, `record_path` 를 적으면 닫힌다. `기록 브랜치 없음 — <사유>` 로 적어도 닫힌다(AC26 · AC27).
  - `test_unanswered_intent_leaves_asks` — 의도 점검 답 `답하지 않음` 을 적으면 물을 것에서 내린다(다시 띄우지 않는다). 다른 종류의 질문은 답을 받을 때까지 남는다.
  - `test_fixed_hash_outside_range_reverts` — 「고친 커밋 deadbeef」 를 적으면 「처리 없음」 으로 되돌리고 알림 줄을 낸다(AC4).
  - `test_open_never_moves_previous` — `open` 뒤 앞 리뷰의 바이트가 그대로다.
  - `test_pick_goes_to_last_review_and_reopens` — 앞 리뷰(차례 1)의 제안을 골라도 마지막 리뷰(차례 2)의 칸에 `낸 리뷰: 1` 과 함께 들고, 닫혀 있던 차례 2 가 돌아옴으로 되돌아간다. 차례 2 의 범위로는 그 지적이 닫히지 않는다(AC3 · Verification Plan).
  - `test_pick_at_cap_asks_two_max` · `test_wrong_choice_withdraws_two_max` — 상한에 닿은 PR 에서 고른 제안을 적으면 「두 번까지」 가 물을 것에 들고, 같은 리뷰에 의도 점검 답 「잘못 골랐다」 를 적으면 거둔다(AC32).
  - `test_return_line_and_empty_return_count` — `return` 뒤 `아직` 줄이 생기고, `처리 파일 없이 끝남` 이 첫째면 다시 돌려보낼 차례, 둘째면 그 지적들이 「손대지 않음 — 처리 파일 없이 끝남」 이 되고 물을 것에 고치지 않은 막는 지적의 질문이 든다. 「옮겼으나 범위 밖 커밋」 도 함께 센다. 그 질문에 「다시 돌려보낸다」 를 적으면 세기가 처음부터(AC24).
  - `test_no_review_closes_prior_fixed` — 좁은 재리뷰가 지적 목록을 얻지 못했고 「리뷰 없이 머지 준비로 간다」 를 적으면 앞 리뷰의 처리 「고친 커밋」 지적이 「리뷰 없이 가기로 함」 이 된다(AC7).
  - `test_mark_rejected_on_wrong_reason` — 「다시 구현됨」 은 「「잘못 골랐다」 — 설계 대화로」 로 닫힌 마지막 리뷰에만, 「재분해 뒤 이어 감」 은 「「잘못 골랐다」 — 재분해 신호」 로 닫힌 것에만 받고, 다른 사유 · 닫히지 않은 리뷰 · 이미 표시가 있는 리뷰에는 rc 4 로 거절하며 바이트가 그대로다(AC9).
  - `test_pick_with_wrong_list_no_two_max` — 상한에 닿은 PR 에서 거른 「잘못 골랐다」 목록이 있는 마지막 리뷰에 `pick` 을 적으면 물을 것에 「두 번까지」 가 들지 않고 `next` 가 `R6a` 다(AC32).
  - `test_reevaluate_after_rewrite` — 재리뷰로 이어짐으로 닫은 뒤 브랜치를 다시 써 기준 커밋이 사라지면, 입력 없는 `record` 가 고친 커밋 처리를 「처리 없음」 으로 되돌리고(그 줄 값 「옮겼으나 범위 밖 커밋」) 돌아옴으로 되돌린다(AC4).
- [ ] **Step 2:** FAIL 을 본다.
- [ ] **Step 3: 짓는다.** 쓰기 뒤에 늘 `close_if_ready(review, reviews, git_state) -> Review` 를 부른다 — 설계 §1 「닫는 조건」 을 사유 차례(에픽을 멈춤 → 「잘못 골랐다」 → 리뷰 없이 감 · 다시 보냄 → 재리뷰로 이어짐 → 사용자가 남김 → 막는 지적 없음)로 본다. 닫힌 리뷰에 `pick` · `route` · 다른 답 · 입력 없는 다시 가리기가 오면 돌아옴으로 되돌린 뒤 같은 함수로 다시 가린다. 마지막 리뷰가 아닌 리뷰에는 쓰지 않는다(rc 4).
- [ ] **Step 4:** PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(conductor): 리뷰 상태 — 답 적기와 닫는 조건" -- plugins/spec-distill/scripts/qg_review_state.py plugins/spec-distill/tests/test_qg_review_state.py`

---

### Task 7: 「관문」 · 「다음」

**AC:** AC6(까닭 여덟 · qg 없음) · AC7(지적 목록을 얻지 못한 질문 차례) · AC8(다시 들어왔을 때) · AC9(멈춰 있다) · AC25(닫혔는데 관문이 닫힌 리뷰) · AC31(훑기 GREEN) · AC32 · AC33.

**Files:**
- Modify: `plugins/spec-distill/scripts/qg_review_state.py`
- Test: `plugins/spec-distill/tests/test_qg_review_state.py` · `test_qg_review_state_sweep.py`

**Interfaces:**
- Produces:
  - `gate ... [--no-qg]` — 읽지 못한 상태 파일은 닫힘(rc 1, `까닭 · 읽지 못함 — <사유>`)이고 rc 3 은 쓰지 않는다. 지휘 절차는 rc 0 일 때만 머지 준비로 간다. 출력은 rc 0 `관문 · 열림` (상태 파일 없음 · `--no-qg` 면 `관문 · 열림 — qg 리뷰 없음(quality-gates 가 설치돼 있지 않다)`) · rc 1 `관문 · 닫힘` 과 걸린 까닭마다 `까닭 · <번호> <이름>`(이름은 설계 §3 의 여덟 글자). 상태 파일이 있는데 `--no-qg` 가 오면 `알림 · qg 없음 인자를 쓰지 않았다 — 이 PR 에 상태 파일이 있다`.
  - `next ... [--alive <이름>]... [--no-qg]` → 첫 줄 `할 일 · <꼴> · <글>`(꼴은 Task 3 의 열 낱말), 둘째 줄 `줄 · <id>`, 셋째 줄 `까닭 · <번호>`(관문 열림이면 `까닭 · 없음`), 갈림이 있으면 `지휘자가 가린다 · <글>`(설계 §4 의 그 줄 글), 알림은 `알림 · <글>`. 사용자 차례면 `물을 것 · <종류> · <정체>` 를 함께 낸다(질문 차례는 설계 §4 표대로 — 지적 목록을 얻지 못함 → 의도 점검 → 「두 번까지」 → 고치지 않은 막는 지적, 담당자가 옮긴 질문은 「지적 목록을 얻지 못함」 뒤). 「보내는 중」 줄의 「담당자가 옮긴 파일」 은 보관 폴더에서 지휘자가 보내기 전에 만드는 파일(`qg-review-state.md` · 「이미 답한 것」 파일 `qg-answered.yaml` · 알림 파일 `qg-answered-notices.txt`) 밖의 파일이다 — 하나라도 있으면 `돌아옴`(결과 파일이 없으면 `back` 이 얻지 못함으로 가려 §3 의 질문이 사용자 차례로 나온다), 없으면 `보냄`.
  - 처리 파일이 「있다」 는 그 경로의 파일에 `## 지적마다의 처리` 머리 줄이 있다는 것이다(세션 담당자의 결과 파일은 처리를 쓰기 전에도 있다).
  - 살아 있는 담당자 이름은 지휘자가 넘긴 그대로 견준다 — qg 담당자는 상태 파일 담당자 칸의 이름, 구현 담당자는 「돌려보냄」 줄의 이름.

- [ ] **Step 1: 실패하는 테스트를 쓴다.**
  - `test_gate_each_reason` — 까닭 여덟을 하나씩 지어 `gate` 가 rc 1 과 그 까닭 줄을 내고, 둘이 함께면 둘 다 낸다(AC6).
  - `test_gate_fixed_finding_closes_by_later_review` — 처리가 고친 커밋인 지적은 뒤 리뷰가 지적 목록을 얻으면 닫히고, 뒤 리뷰가 얻지 못했으면 열린 채다(AC6).
  - `test_gate_no_qg` — 상태 파일 없음 + `--no-qg` → 열림 줄 · 상태 파일이 생기지 않음. 상태 파일 있음 + `--no-qg` → 알림과 함께 상태 파일대로. 인자 없이 상태 파일 없음 → 까닭 8(AC6).
  - `test_next_failed_review_asks` — 얻지 못한 리뷰에서 `next` 가 사용자 차례 · `물을 것 · 지적 목록을 얻지 못함`. 의도 점검만 셀 수 없는 리뷰에서는 이 질문이 없다(AC7).
  - `test_sending_only_pre_files_sends` — 보내는 중 · 담당자 없음 · 보관 폴더에 `qg-answered.yaml` · `qg-answered-notices.txt` 만 → `보냄`(`지휘자가 가린다` 줄과 함께).
  - `test_sending_with_moved_file_is_returned` — 같은 상태에 `result.md` 없이 담당자가 옮긴 다른 파일(`handler-report.md`) 하나가 있으면 `돌아옴`, `back` 뒤 `next` 는 사용자 차례 · `물을 것 · 지적 목록을 얻지 못함`(다시 보내지 않는다). `result.md` 가 있으면 `돌아옴`(AC8 · D75).
  - `test_gate_unreadable_is_closed` — 상태 파일 꼴이 깨지면 `gate` 가 rc 1 과 `까닭 · 읽지 못함`.
  - `test_gate_other_filtered_only_opens` — 거른 질문이 「그 밖에」 뿐인 리뷰는 관문을 막지 않고(rc 0), 「잘못 골랐다」 목록이 하나라도 있으면 까닭 6 으로 닫힌다(D71 · AC6).
  - `test_team_handling_header` — team 형식 픽스처(`--job-dir`)에서 「아직」 줄의 처리 파일(다음 시도의 구현 결과 파일)에 `## 지적마다의 처리` 머리가 있으면 `R7b`, 머리 없는 결과 파일이면 `R7c`(처리 파일 없이 끝남으로 세어짐)(D74).
  - `test_worker_question_not_failed` — 보냄 · 담당자가 옮긴 질문 → 사용자 차례, 「지적 목록을 얻지 못함」 으로 떨어지지 않는다. 답을 적고 그 이름을 `--alive` 로 넘기면 `기다린다`, 넘기지 않고 `back` 하면(결과 파일 없음) 얻지 못함과 §3 의 질문(AC8).
  - `test_answer_then_cut_before_record` — 답은 적었는데 기록 경로가 빈 채 끊기면 `기록 파일 쓰기`, 다시 묻지 않는다(AC8 · AC26).
  - `test_halted_and_resplit_wait` — 에픽을 멈춤 · 재분해 신호(표시 없음) → 사용자 차례(멈춰 있다) · 설계 대화로(표시 없음) → 기다린다(AC9).
  - `test_closed_but_gate_closed_rows` — 거른 「잘못 골랐다」 목록이 있는 닫힌 리뷰 → `답 적기`(행선), 표시 뒤 → `열기`. 다시 보냄 뒤 새 리뷰 없음 → `열기`(AC25).
  - `test_next_unreadable_state_shows_values` — 꼴이 깨진 상태 파일 · 칸끼리 맞지 않는 상태(예: 닫힘 · 재리뷰로 이어짐인데 처리 없음 지적) → `상태 보이기`, 지금 값을 줄로 낸다(AC25).
  - `test_return_wait_then_move` — 아직 · 살아 있음 → `기다린다`(다시 돌려보내지 않는다) · 빠지면 처리 절이 있으면 `답 적기`, 없으면 `답 적기`(처리 파일 없이 끝남)와 `지휘자가 가린다` 줄(AC24).
- [ ] **Step 2:** FAIL 을 본다.
- [ ] **Step 3: 짓는다.** `reasons(reviews, git_state, no_qg) -> list[int]` 를 관문과 「다음」 이 함께 쓴다. `next` 는 설계 §4 표를 위에서부터 보는 `NEXT_ROWS` 목록(줄마다 `match(reviews, git_state, alive, no_qg) -> bool` 과 `emit(...)`)으로 짓는다 — `열기` 를 내는 줄의 `match` 는 Task 4 의 `open_accepts` 를 부른다(같은 기준). 맞는 줄이 없으면 끝 줄. `open --site asked` 의 거절(마지막 리뷰가 「에픽을 멈춤」 · 표시 없는 「잘못 골랐다」 로 닫힘 — 설계 §2 여섯째 · D77 · D78)도 여기서 짓는다 — 「열기」 안에 조건을 따로 적지 않고, 닫힌 마지막 리뷰에서 `NEXT_ROWS` 가 까닭 2 · 까닭 6 의 `기다린다` · `사용자 차례` 줄을 내면 rc 4 · 까닭 · 그 `next` 줄들이다. 표시(「다시 구현됨」 · 「재분해 뒤 이어 감」) 뒤와 그 밖의 닫힘에서는 받는다.
- [ ] **Step 4:** `test_qg_review_state` · `test_qg_review_state_sweep` 둘 다 PASS. 훑기가 끝까지 GREEN 이 되지 않는 줄이 있으면 Task 3 끝의 규칙대로 멈춰 보고한다.
- [ ] **Step 5: 커밋.** `git commit -m "feat(conductor): 리뷰 상태 — 관문과 다음" -- plugins/spec-distill/scripts/qg_review_state.py plugins/spec-distill/tests/test_qg_review_state.py plugins/spec-distill/tests/test_qg_review_state_sweep.py`

---

### Task 8: 「글 짓기」

**AC:** AC10(셋 · qg 없음 줄 · 경로 없음 · 펜스) · AC23(처리 파일 절대경로 · 보관 폴더 경로 없음 — 스크립트 몫) · AC7(「qg 리뷰 없이 감」 줄 아래의 지적).

**Files:**
- Modify: `plugins/spec-distill/scripts/qg_review_state.py`
- Test: `plugins/spec-distill/tests/test_qg_review_state.py`

**Interfaces:**
- Produces: `render ... --kind {pr-body,approval,return-list,team-fence} [--no-qg] [--handling-file <절대경로>]` → 표준 출력에 그 글. `return-list` 는 `--handling-file` 이 필수다.
  - `pr-body` — `## qg 리뷰` 절의 몸(머리 줄은 싣지 않는다): 리뷰마다 `- 호출 · <자리 글자> · <시작>..<끝>` · 판정 줄 · 막는 지적과 처리 · 멈출 조건 · 사용자 답 · 남긴 지적.
  - `approval` — 승인 기록 다시 보이기의 qg 몫: 맨 위 `qg 리뷰 없음(quality-gates 가 설치돼 있지 않다)`(상태 파일 없음 + `--no-qg`) 또는 `qg 리뷰 없이 감 — 사용자 결정(<사유>)` 과 그 아래 「리뷰 없이 가기로 함」 지적 · 처리가 「사용자가 남김」 인 지적, 그다음 질문마다 질문 글 한 줄 · 답 · 답 원문(있으면 — 사용자 답 칸 전부, 이름으로 청한 리뷰 포함), 거른 질문은 `앞 리뷰에서 답함`, 끝에 리뷰마다 닫힘 사유 한 줄.
  - `return-list` — 처리 없음 · 다시 돌려보냄 지적과 고른 제안 · 되올린 지적의 원문, 끝에 `처리 파일: <절대경로>` 와 「이 파일의 `## 지적마다의 처리` 머리 아래에 지적마다의 처리를 쓴다」. 「worktree 밖이어도 이 경로에 … 쓰고 끝낸다」 는 싣지 않는다 — 설계 §1 대로 하위 agent 길의 보내는 글에만 지휘 절차 문서가 싣는다(Task 10).
  - `team-fence` — `pr-body` 와 같은 글을 바깥 펜스까지 싸서 — 펜스 길이는 글 안의 가장 긴 백틱 줄 + 1(최소 3).

- [ ] **Step 1: 실패하는 테스트를 쓴다.**
  - `test_approval_has_every_answer_left_and_reason` — 상태 파일 셋(첫 리뷰 · 좁은 재리뷰 · 이름으로 청한 리뷰)의 사용자 답 · 「사용자가 남김」 · 닫힘 사유가 하나도 빠지지 않는다(집합 견줌). 거른 질문은 `앞 리뷰에서 답함` 으로(AC10).
  - `test_approval_no_qg_top_line` · `test_approval_no_review_top_with_fixed` — 맨 위 줄과 그 아래 「리뷰 없이 가기로 함」 지적(AC10 · AC7).
  - `test_pr_body_has_no_review_line` — 「리뷰 없이 머지 준비로 간다」 를 적은 PR 의 `pr-body` 에 `qg 리뷰 없이 감 — 사용자 결정(<사유>)` 줄이 실린다(설계 §3 「표시(§5)와 승인 기록 다시 보이기에」 · AC7 · AC10).
  - `test_display_has_no_paths` — `pr-body` · `team-fence` 에 보관 폴더 · 상태 파일의 절대경로 · `report_root` 의 어느 앞부분도 · `--answered` · `--suite-lock` 글자도 없고, 호출 줄은 `- 호출 · <자리 글자> · <범위>` 꼴과 `fullmatch` 한다(AC10).
  - `test_return_list_has_handling_path_only` — 처리 파일 절대경로가 있고 보관 폴더 · 상태 파일 경로는 없다(AC10 · AC23).
  - `test_team_fence_outer_longer` — 지적 원문에 ```` ```` ```` 네 개짜리 줄이 있으면 바깥 펜스는 다섯이고, 글을 마크다운 펜스 파서(`team-files.md` 의 펜스 규칙 — 펜스 밖 줄만 읽음)로 읽으면 열림 하나 · 닫힘 하나(AC10).
- [ ] **Step 2:** FAIL 을 본다.
- [ ] **Step 3: 짓는다.** 경로가 새지 않게 글은 상태 파일의 칸에서만 짓는다(경로를 담은 칸은 없다 — 처리 파일 경로는 `return-list` 의 인자에서만 온다).
- [ ] **Step 4:** PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(conductor): 리뷰 상태 — 표시 글 짓기" -- plugins/spec-distill/scripts/qg_review_state.py plugins/spec-distill/tests/test_qg_review_state.py`

---

### Task 9: 답 넘기기 스크립트의 가장자리

**AC:** AC13 · AC14 · AC15(스크립트 몫) · AC16(스크립트 몫) · AC29(답 · 알림 원자 쓰기) · AC30. AC12 는 없앴다(D23) — 할 일 없음. 제안 23(가드) · 24 · 27 · 32 · 33 을 받는다.

**Files:**
- Modify: `plugins/spec-distill/scripts/qg_answered.py`
- Test: `plugins/spec-distill/tests/test_qg_answered.py`

**Interfaces:**
- Produces: 종료 코드 0 · 2 · 3 은 그대로, 새 **4** — 답 파일은 썼는데 알림 파일을 쓰지 못했다(표준 오류 끝 줄 `[qg_answered] 알림 파일을 쓰지 못했다 — 알림은 위 줄뿐이다`). PyYAML 이 없으면 rc **5** 와 `[qg_answered] PyYAML 이 없다 — 답 없이 보낸다`(제안 23 의 가드). 알림 줄은 파일을 쓰기 **전에** 표준 오류에 낸다.

- [ ] **Step 1: 실패하는 테스트를 쓴다.** (지금 `Env` · `commit_files` · `record` · `section` 도우미로)
  - `test_unreadable_record_drops_same_target` — 같은 에픽 번호의 기록 둘 가운데 하나가 깨졌으면 그 에픽의 답은 하나도 넘어가지 않고, 다른 에픽의 답은 넘어간다. 깨진 파일 안의 「전에 한 답」 이 뒤집던 앞 답도 넘어가지 않는다(제안 28 · AC13).
  - `test_out_of_template_name_drops_all` — 이름이 틀 밖인 기록이 하나 있으면 어느 답도 넘어가지 않는다(AC13).
  - `test_whole_ref_unreadable_drops_that_ref` — 없는 ref · `-` 로 시작하는 ref 는 그 ref 의 답이 없고 알림 한 줄, 다른 ref 의 답은 넘어간다(AC13 · 제안 33).
  - `test_quiet_answer_keeps_prior` — 뒤 기록의 새 답이 `지금은 모르겠다` · `답하지 않음` · `묻지 않음(상한 넘어 남김)` 이면 앞 답이 넘어가고, `의도다` · `잘못 골랐다` 면 빠진다(AC14).
  - `test_multiline_answer_with_heading` — 답 원문 둘째 줄부터 두 칸 들여 쓰고 그 가운데 `## 다른 것` 줄이 있어도 절이 끊기지 않고 답이 넘어간다(AC15).
  - `test_prior_time_with_separator_unreadable` — 「전에 한 답」 의 둘째 칸에 ` · ` 가 들어 꼴 밖이면 그 기록은 읽지 못한 기록, 같은 대상의 답이 넘어가지 않고 알림이 남는다. `- 답한 때:` 가 꼴 밖인 기록도 같다(AC30).
  - `test_prior_identity_with_separator_reads` — 셋째 칸(정체)에 ` · ` 가 든 「전에 한 답」 은 읽혀 앞 답을 뺀다(AC30).
  - `test_prior_cell_identity_with_separator` 를 고쳐 쓴다 — 이름에 ` · ` 가 든 기록 파일(`a · b.md`)은 이름 틀 밖으로 세어 그 열쇠가 넘어가지 않는다(정상 열쇠로 기대하는 단언을 지운다 · AC30 · 제안 31).
  - `test_notice_file_fail_keeps_stderr` — 알림 파일 자리를 쓰지 못하게 하면 rc 4, 표준 오류에 알림 줄과 끝 줄, 답 파일은 있다. 답 파일을 쓰지 못하면 rc 3(AC16).
  - `test_no_partial_files_on_fail` — 쓰다 실패한 두 경우 모두 임시 파일 · 반쯤 쓴 파일이 남지 않는다(AC29).
  - `test_route_missing_contract3_unreadable` — 3판 기록의 「잘못 골랐다」 에 행선이 없으면 읽지 못한 기록(제안 32).
  - `test_record_branch_answer_carries_epic_only_does_not` — 첫 머지 앞 리뷰의 기록을 기록 브랜치에만 두고 같은 대상의 다른 기록을 에픽 브랜치에만 둔 리포에서, 지휘 절차의 호출 꼴대로 `--ref <기본 브랜치> --ref <기록 브랜치>` 로 부르면 기록 브랜치의 답은 넘어가고 에픽 브랜치에만 있는 답은 넘어가지 않는다(AC11 — 설계 Verification Plan).
  - `test_no_yaml_guard` — `yaml` import 를 막은(`sys.modules` 에 None) 하위 프로세스에서 rc 5 와 그 줄(제안 23).
- [ ] **Step 2:** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_answered -v` — 새 것 FAIL.
- [ ] **Step 3: 고친다.** `_prior_key(value) -> str | None` 은 첫 칸이 `ANSWERS` 가운데 하나 · 둘째 칸이 `fullmatch(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}|-")` · 끝 칸(오른쪽에서 뗀 것)이 까닭이고 그 사이가 열쇠다 — 꼴이 아니면 `Unreadable("전에 한 답의 칸이 꼴 밖이다")`(제안 24 — 예외에 사유를 싣되 알림 글은 바꾸지 않는다). 「전에 한 답」 은 그 절의 `답` 이 `ANSWERS` 일 때만 superseded 에 더한다. `_name_ok` 에 ` · ` 를 막는 조건. `collect` 는 읽지 못한 파일의 대상(이름의 에픽 번호 · `roadmap`)을 모아 그 대상의 항목을 버리고, 이름조차 틀 밖이면 전부 버린다. `_esc` docstring 을 실제 범위(C0 · DEL · 줄 나눔 글자)로 고친다(제안 27). 쓰기 차례 — 알림 줄을 stderr 에 먼저 → 답 파일 → 알림 파일.
- [ ] **Step 4:** PASS(옛 테스트 포함).
- [ ] **Step 5: 커밋.** `git commit -m "fix(conductor): 답 넘기기 — 읽지 못한 기록 · 앞 답 칸 · 알림 잃지 않기" -- plugins/spec-distill/scripts/qg_answered.py plugins/spec-distill/tests/test_qg_answered.py`

---

### Task 10: `qg-review.md` 를 스크립트 위에 다시 쓴다

**AC:** AC1(PR 본문 · 펜스에서 읽는 문장 없음) · AC7(선택지 셋 글자 · 차례) · AC11(기록 자리 · `--ref`) · AC15(기록 틀의 들여쓰기 · 번호 규칙) · AC16(종료 코드 줄) · AC17(알림 접기) · AC18(여러 줄 지적) · AC23(보내는 글) · AC24(하위 agent 길의 처리 파일 문장) · AC27(기록 브랜치를 만들지 못했을 때) · AC28(쌓인 기록 두 줄) · AC33(이름으로 청한 리뷰) · AC9(spec 표지에 설계문서 커밋).

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`
- Modify: `plugins/spec-distill/tests/test_qg_review_reference.sh` · `plugins/spec-distill/tests/test_qg_review_readable.sh`
- Modify: `shared/tests/fixtures/ask-sites.tsv`(새 질문 자리 — §3 의 질문 하나)

**Interfaces:**
- Consumes: Task 4–8 의 명령 이름 · 인자 · 출력 첫 줄 꼴 · 종료 코드, Task 9 의 rc 4 · 5.

고칠 문장은 계획 때 전수로 뽑았다(하위 agent 조사, 브랜치 끝 `72663091` 의 줄 번호). 머지 앞 자리(MF)의 줄은 스크립트를 부르는 문장으로, 기록 자리의 줄은 기록 브랜치로 바꾼다. spec 승인 앞(SP) · 로드맵 끝(END)의 세는 문장은 그대로 둔다(표지 커밋만 더한다).

| 줄 | 지금 | 바꾼 뒤 |
|---|---|---|
| :27 · :28 · :30 | 「자리」 표 기록 칸 — 에픽 브랜치 | 네 줄 모두 기록 브랜치 |
| :40 | 호출 줄을 PR 본문에 적고 같은 줄이 있으면 다시 적지 않음 | MF 는 `open` 이 낸 범위 · 자리 글자로 부르고, 표시는 `render --kind pr-body` 를 올린다 — PR 본문에서 읽지 않는다 |
| :54 · :64 · :67 · :68 · :87 · :89 | 「이미 보낸 것」 이 보관 사본 · 쌓인 기록 줄 · `premerge-resend-pr` · PR 본문 recheck 줄로 셈 | MF 는 `open` 이 정한다(「이미 보낸 것」 은 SP · END · 이름으로 청한 spec 전 에픽만). 쌓인 기록 두 줄은 지금 꼴대로 적되 MF 의 보낸 횟수로 세지 않는다(AC28) |
| :54(SP · END · 이름으로 청한 spec 전 에픽) | 「보관 사본:」 기록 파일을 읽는 자리 셋(에픽 브랜치 포함) | 기본 브랜치와 기록 브랜치 둘만(AC11) |
| :62 | 재진입에서 PR 본문에 막는 지적 목록이 없으면 적음 | `next` 를 부르고 그 할 일대로 |
| :66 · :80 · :412 | `spec-resend` 표지 — 차례 · 해시로 가리지 않음 | 표지 글 칸에 그때의 설계문서 커밋 ` @ <커밋 앞 8자>` 를 더하고, 설계문서가 그 커밋 그대로인 동안 그 허용분으로 보내지 않는다(AC9). MF 의 `premerge-resend-pr` 표지는 지운다 |
| :71 | 이름으로 청한 리뷰는 이미 보낸 리뷰가 있어도 보냄 | 구현이 끝난 머지 전 에픽은 `open --site asked` — 앞 리뷰가 닫힌 뒤에만 받고, 「에픽을 멈춤」 · 표시 없는 「잘못 골랐다」 로 닫혔으면 받지 않는다(한 문장). 거절되면 그 할 일을 먼저(AC33 · AC9 · D77). spec 전 에픽 · 그 밖은 지금 그대로 |
| :119 · :120 · :336 | 기록을 에픽 worktree 에서 에픽 브랜치에 | 모든 리뷰 기록은 기록 브랜치에. 만들지 못하면 사유와 「이 답은 다음 리뷰로 넘어가지 않는다」 를 알리고 MF 는 `record` 로 `기록 브랜치 없음 — <사유>`, SP 는 설계문서 지휘 기록에 한 줄(AC27) |
| :237 · :238 · :245 · :413 | 원문 · 「돌려보내지 않음」 · 사유와 답을 PR 본문에 적고 거기서 싣는다 | 원문은 `back` 이 상태 파일에, 돌려보낼 목록은 `render --kind return-list`, 답은 `record` |
| :250 · :252 · :258 · :259 | 좁은 재리뷰 범위 · 멈출 조건 · 답 · 첫 리뷰 목록을 PR 본문에서 읽고 씀 · 에픽 브랜치 기록 읽음 | `open --site recheck` 가 범위를 정하고, 멈출 조건은 `record` 의 `stop_rule`, 앞 답은 기록 브랜치에서 |
| :261 | team 펜스에 적고 거기서 셈 | team 도 같은 스크립트(대상 `<과제>-plan<n>`, `--job-dir`), 펜스는 `render --kind team-fence` 를 싣는 표시 |
| :325 | 승인 기록 다시 보이기가 기록 파일의 `- 답:` 줄을 찾아 읽음 | `render --kind approval` 이 상태 파일에서 짓는다 — 기록 파일을 읽지 않는다 |
| :357 · :358 | `--ref <에픽 브랜치>` · 열린 에픽 브랜치마다 | `--ref` 는 기본 브랜치와 기록 브랜치 둘만(AC11) |
| :359–:361 | 종료 코드 목록 rc 0 · 2 · 3 | rc 4(알림 파일만 못 씀 — 표준 오류 줄을 리뷰 글에 그대로 싣고 보낸다) · rc 5 와 「그 밖」(스크립트가 죽음 포함 — 답 없이 보내고 알린다) 줄을 더한다(AC16) |
| :280 | 기록 이름 `-2` 는 쓰는 브랜치만 봄 | 쓰는 기록 브랜치와 기본 브랜치를 모두 본다(AC15) |
| :386 | 기록 파일에 `## 질문` 절이 있으면 자세히 | 그대로(자리는 기록 브랜치) |
| :154 | qg 담당자 설명 글 `"Run quality gates for <대상> <자리>"` | `"qg <자리 글자> <차례>"`(D72) — 「보내는 중」 의 지휘자 가림이 하니스 목록에서 이 글로 찾는다 |
| 옛 흔적(새 문장) | — | 상태 파일이 없는 PR 에 PR 본문 `## qg 리뷰` 절이나 쌓인 기록의 머지 앞 qg 줄이 있으면 `open --legacy-trace pr-body` · `ledger` 로 넘기고, 옛 PR 본문의 막는 지적과 사용자 답을 사용자에게 한 번 보인다(새 리뷰가 같은 지적을 다시 낼 수 있다) — 범위 · 횟수로 쓰지 않는다(설계 §9 · AC19) |
| 표시를 적는 때(새 문장) | — | 「잘못 골랐다」 로 설계 대화에 돌아간 PR 은 고친 설계의 구현 담당자가 돌아온 뒤에 `record` 의 `mark` 「다시 구현됨」 을, 재분해 신호로 닫힌 PR 은 재분해가 끝나 그 PR 을 이어 가기로 했을 때 「재분해 뒤 이어 감」 을 적는다 — 브랜치 끝이 움직였다는 것으로 적지 않는다(설계 §4 · AC9) |

더하는 문장 — 「돌아왔을 때」 · 「되돌리기」 · 「「잘못 골랐다」 의 행선」 의 MF 갈래는 「`next` 를 부르고 그 할 일대로 한다」 하나와 명령마다 부르는 때(보내기 직전 `send --phase start` · 보낸 뒤 `--phase done` · 돌아오면 `back` · 답을 받으면 먼저 `record` 그다음 기록 파일 · 돌려보낸 즉시 `record` 의 `return`) · §3 의 질문(「다시 보낸다 (권장)」 · 「리뷰 없이 머지 준비로 간다」 · 「이 에픽을 멈춘다」 — 이 차례 · 얻음 · 내줌 글자는 설계 §3 그대로) · 「qg 없음」 일 때 `--no-qg` 를 `gate` · `next` · `render` 에 넘김(「## 호출 줄」 의 설치 없을 때 문장 옆) · 되돌리기의 보내는 글(처리 파일 절대경로만 · 그 파일의 `## 지적마다의 처리` 머리 아래에 지적마다의 처리를 쓰라는 문장(D74) · 하위 agent 길에도 「worktree 밖이어도 이 경로에 지적마다의 처리를 쓰고 끝낸다」 · 보관 폴더 · 상태 파일 경로 없음) · 처리 파일 자리(세션 담당자는 그 결과 파일, 하위 agent 는 `ledger resource-dir --kind report --name <에픽>` 안의 `handling-<자리 글자>-<n>.md` — 돌려보낼 때마다 새 `<n>`) · 기록 파일을 쓰기 전에 기록 브랜치에서 `- 보관 사본:` 이 이 보관 폴더를 가리키는 기록을 먼저 찾아, 있으면 그 경로를 `record_path` 로 적는다(같은 기록을 `-2` 로 또 쓰지 않는다) · 알림 접기(설계 §8 첫 불릿 — 「전에 알린 알림 <n>줄 — 자세히는 알림 파일」, 앞 보관 폴더는 `## 자원` 의 앞 qg 보관 폴더 가운데 마지막 것, 없거나 rc 4 면 접지 않음) · 여러 줄 지적을 지휘 기록에 올릴 때 첫 줄 + 「…(전문: <보관 폴더 이름>의 지적 목록)」(접은 글을 원문이라 부르지 않는다) · 기록 틀의 「답한 때」 꼴(`YYYY-MM-DD HH:MM` 또는 `-`)과 여러 줄 답 원문의 두 칸 들여쓰기 · qg 담당자 설명 글의 꼴 `qg <자리 글자> <차례>`(「보내는 중」 의 지휘자 가림이 하니스 목록에서 이 글로 찾는다).

- [ ] **Step 1: 지금 락을 대응표대로 고른다.** 지우는 락마다 같은 뜻을 잇는 테스트가 있다(설계 §8 「지금 있는 락」). SP · END · 이름으로 청한 spec 전 에픽의 몫은 「다시 씀」 에서도 지금 단언을 그대로 남긴다 — 조용히 빠지지 않게 다시 쓴 케이스 안에 그 단언이 남았는지 diff 로 본다. R7 이 같은 파일에 더한 케이스(`call_line_suite_lock` · `reinvoke_per_unknown_arg` · `overlap_sentence` · `ontology_names_qg`)가 기본 브랜치에 있으면 건드리지 않는다.

| 락(파일 · 케이스 · 줄) | 처분 | 같은 뜻을 잇는 것 |
|---|---|---|
| `test_qg_review_reference.sh` ROW_PREMERGE :51–52 | 다시 씀 — 머지 앞 행의 기록 칸이 기록 브랜치 | `record-branch-only` |
| 〃 AC14 L_resend :93 | 다시 씀 — SP 의 「다시 보내는 때」 단언은 남기고 MF 의 `premerge-resend` 몫만 뺀다 | 훑기 `R3b` · `R6c` · `test_next_open_is_accepted` |
| 〃 AC23 :121 | 다시 씀 — 쌓인 기록 자리 글자 · 두 줄은 지금 꼴 | `rc-lines` 옆 새 단언 `ledger-two-lines`(AC28) |
| 〃 행 31 :158–159 | 둠 — 기록 틀의 `- 보관 사본:` 줄 | — |
| 〃 AC11 L_branchspec · L_pushnow · L_openpr · L_remade :177–181 | 다시 씀 — 「에픽 worktree 에서 에픽 브랜치」 → 기록 브랜치. 답을 받은 직후 커밋 · push · PR 여는 때 단언은 남긴다 | `record-branch-only` |
| 〃 R6 AC9 refs :190 · :196–199 | 다시 씀 — ref 둘. `origin/<에픽 브랜치>` 부재 단언을 `<에픽 브랜치>` 가 든 `--ref` 전부의 부재로 넓힌다 | Task 9 `test_record_branch_answer_carries_epic_only_does_not` |
| 〃 L_order :289 · :340 | 다시 씀 — MF 보내기 차례(`open` → `send --phase start` → 담당자 → `send --phase done`). SP 차례는 그대로 | Task 13 `test_walk_doc_fences_run` |
| 〃 M8 L_sent* :293–311 · :345–347 | 다시 씀 — SP · END · 이름으로 청한 spec 전 에픽의 셈(보관 사본 · 쌓인 기록 줄 · `spec-resend` 정체)은 그대로 단언, MF 몫(`premerge-resend-pr` · PR 본문 recheck 줄 · MF 보관 사본)만 뺀다 | `test_open_refused_while_last_not_closed` · `test_cap_counts_only_obtained_rechecks` · `test_legacy_traces_open_whole_pr` |
| 〃 L_specline :313–315 | 둠 — SP 의 폴더 이름 표지 · 쌓인 기록 줄 | — |
| 〃 L_resendmark :412 · :418 | 다시 씀 — `spec-resend` 표지 명령에 ` @ <커밋 앞 8자>` | `spec-resend-commit` |
| 〃 return-record-first · return-questions-first :515–523 | 다시 씀 — 「질문부터 묻는다」 차례는 남기고(§4 표의 `R4` · `R6a` 가 `R7d` 앞), 「PR 본문에 글자 그대로 · 그 절에서 싣는다」 는 `back` · `render --kind return-list` 로 | 훑기 `test_each_row_yields_its_action` · `mf-calls-script` |
| 〃 recheck-cap-two :540–547 · :594–600 | 다시 씀 — 「PR 하나에 두 번까지」 · 멈출 조건 · 선택지 셋 글자는 남기고, 세는 문장은 스크립트를 부르는 문장으로 | `test_cap_counts_only_obtained_rechecks` · 훑기 `test_cap_cases` |
| 〃 unfixed-blocking-ask :570 | 다시 씀 — 선택지 셋 남김, 「사유와 답은 PR 본문에 적는다」 → `record` | `test_return_line_and_empty_return_count` |
| 〃 recheck-start-from-pr-body · fix I1 :574–592 | 지움 | `test_recheck_start_is_last_obtained_end` · Task 8 `test_display_has_no_paths`(호출 줄 꼴) |
| 〃 PR 본문 AC19 :613–616 | 다시 씀 — 절은 `render --kind pr-body` 의 글을 올린다 · 호출 줄 꼴 | 락 5 `no-paths-to-reviewed` · `test_display_has_no_paths` |
| 〃 premerge-wrong-choice :622–628 | 다시 씀 — 머지 앞 행선 갈래(설계 대화로 · 재분해 신호)는 남기고 `premerge-resend-pr` 표지를 뺀다 | 훑기 `R6a`–`R6e` · `test_reopen_after_design_mark` |
| 〃 spec-resend-identity · fix I2 :652–660 | 둠 + 더함 — 정체 `<질문 id> @ <보관 폴더 이름>` 단언 그대로, 커밋 구절 단언을 더한다 | `spec-resend-commit` |
| 〃 (a) :663 · :665 | 다시 씀 — 이름으로 청함 행의 기록 칸 | `record-branch-only` |
| 〃 (e) :670–672 | 다시 씀 — 쌓인 기록으로 세는 것은 SP · END 만, MF 는 상태 파일 | `ledger-two-lines` · `test_cap_counts_only_obtained_rechecks` |
| 〃 이월 (c) :682–684 | 다시 씀 — MF 차례 | `test_walk_doc_fences_run` |
| 〃 team 단락 :686–693 | 다시 씀 — 자리 글자 `premerge-<과제>-plan<n>` · `recheck-<과제>-plan<n>`(`premerge-resend-…` 은 뺀다), 펜스는 표시 | Task 12 락 2 `team-sentences` · Task 11 `team-review-qg` |
| 〃 AC9 :754–755 · team 검수 걸음 :762–772 | Task 11 에서 다시 씀 | `step5-gate` · `team-review-qg` |
| 〃 IR3 :820–822 | 둠 | — |
| `test_qg_review_readable.sh` answered-script-order :81–92 | 다시 씀 — ref 둘 · rc 4 · 5 · 「그 밖」 | `rc-lines` · `test_record_branch_answer_carries_epic_only_does_not` |
| 〃 asked-then-recheck :135 | 둠 | `test_cap_counts_only_obtained_rechecks` |
| 〃 record-template :288–293 | 다시 씀 — 「답한 때」 꼴 · 여러 줄 답 들여쓰기 · 이름 번호가 두 브랜치를 봄 | Task 9 `test_multiline_answer_with_heading` · `test_prior_time_with_separator_unreadable` |
| 〃 reenter-without-report :305–330 · :358–359 | 다시 씀 — MF 는 `next`, SP · END 는 지금 문장 단언 그대로 | `mf-calls-script` · 훑기 |
| 〃 carry-original :389 | 다시 씀 — 원문은 `back` 이 보관 폴더에서 옮긴다 | Task 5 `test_back_moves_originals_without_pr_body` |
| `test_superpowers_presence.sh` :28 · :98–106 | 둠 — 「## 호출 줄」 대로 · 없으면 건너뜀. 새 `--no-qg` 문장이 단언을 깨지 않는지 돌려 본다 | — |
| `shared/tests/fixtures/ask-sites.tsv` :170–172 | 둠 + §3 질문 행을 더함 | `failed-review-question` |
- [ ] **Step 2: 새 락을 먼저 쓴다(RED).** `test_qg_review_reference.sh` 에 — `mf-calls-script`(「돌아왔을 때」 · 「되돌리기」 · 「「잘못 골랐다」 의 행선」 의 MF 갈래에 `qg_review_state.py next` · 명령마다 부르는 때 다섯) · `mf-no-pr-body-read`(음: 문서의 `PR 본문` 이 든 줄을 모두 뽑아 그 줄에 「읽」 · 「센다」 · 「세」 · 「싣는다」 · 「찾」 이 없음 — SP · END 절(절 머리로 가른다)은 뺀다. `- 답:` 이 든 줄에도 「읽」 · 「찾」 이 없음(기록 틀 절은 뺀다) / 양: 「`render --kind pr-body` 의 글을 올린다」 줄과 `render --kind approval` 줄이 하나씩. 한계 — 동사를 다른 말로 바꾼 문장(예: 「거기서 가져온다」)은 이 음 단언을 지나간다. 그 몫은 양의 짝(읽는 자리가 스크립트로 바뀐 문장)과 스크립트 테스트(`test_back_moves_originals_without_pr_body` · `test_approval_has_every_answer_left_and_reason`)가 잰다 — `docs/testing.md` 「글자 대조 말고 쓰는 확인」 대로 기계가 받는 몫은 기계로 잰다) · `failed-review-question`(선택지 셋 글자 · 차례 · 얻음 · 내줌) · `record-branch-only`(표 네 줄의 기록 칸 · `--ref` 둘 · 에픽 브랜치 `--ref` 없음 / 양: 기록 브랜치를 만들지 못했을 때 문장) · `rc-lines`(rc 4 · 5 · 「그 밖」) · `notice-fold`(접는 글자 · 앞 보관 폴더 고르는 법 · 접지 않는 둘) · `finding-fold`(첫 줄 + 전문 자리 글자) · `return-text`(처리 파일 절대경로 문장 · 하위 agent 길 문장 / 음: 보내는 글 펜스에 `보관 폴더` · `qg-review-state.md` 없음) · `asked-after-close`(이름으로 청한 리뷰의 새 문장 · 「에픽을 멈춤」 · 표시 없는 「잘못 골랐다」 뒤에는 받지 않는다는 문장 / 음: 「이미 보낸 리뷰가 있어도 보낸다」 가 MF 자리에 없음) · `spec-resend-commit`(표지에 커밋 · 「그 커밋 그대로인 동안」) · `worker-description`(qg 담당자 설명 글 `"qg <자리 글자> <차례>"` / 음: `Run quality gates for` 없음) · `legacy-show-once`(옛 흔적 문장 · `--legacy-trace` / 음: 옛 흔적에서 범위 · 횟수를 읽는 문장 없음) · `mark-timing`(표시를 적는 때 두 문장) · `ledger-two-lines`(쌓인 기록 두 줄을 지금 꼴대로 적고 MF 의 보낸 횟수로 세지 않음 — AC28). `shared/tests/fixtures/ask-sites.tsv` 에 §3 질문 자리(선택지 셋)를 더한다. `bash plugins/spec-distill/tests/test_qg_review_reference.sh` 로 새 케이스 RED 를 본다.
- [ ] **Step 3: 문서를 고친다.** 위 표와 「더하는 문장」 대로. 문장은 쉬운 말 규칙을 따르고, 스크립트 명령 줄은 펜스(따옴표 친 heredoc 없이 인자만)로 싣는다.
- [ ] **Step 4: 실행 블록을 돌려 본다.** 문서의 `qg_review_state.py` 펜스를 뽑아 `Rig` 로 지은 임시 기계 상태에서 차례대로 돌리는 케이스 `doc-fences-run` 을 `test_qg_review_state_walk.py`(Task 13)에 맡긴다 — 이 과제에서는 펜스마다 `--help` 에 있는 명령 · 인자만 쓰는지 재는 셸 단언 `doc-fence-args` 를 둔다.
**스크립트로 잴 수 없는 자리.** 알림 접기(AC17) · 여러 줄 지적을 접어 올리기(AC18) · 기록 브랜치를 만들지 못했을 때 알리기(AC27) · 쌓인 기록 두 줄(AC28) · 보내는 글에 처리 파일 경로를 싣기(AC23)는 지휘자(모델)가 문서대로 하는 일이라 스크립트 테스트로 재지 못한다. 대신 — 문장은 위 락이 양 · 음으로 재고 변이 둘로 이빨을 보며, 기계가 받는 몫은 스크립트가 잰다(접는 글의 입력인 알림 파일은 Task 9 가 늘 다 쓰는지 · 접은 줄을 기록 명령이 받는지는 Task 13 · `기록 브랜치 없음 — <사유>` 로 닫히는지는 Task 6 · 표시 글에 경로가 없는지는 Task 8). `notice-fold` 는 음의 짝으로 `conductor_ledger.py --help` 에 알린 기록을 적고 읽는 명령이 없음을 함께 잰다(AC17).

- [ ] **Step 5:** `bash plugins/spec-distill/tests/test_qg_review_reference.sh && bash plugins/spec-distill/tests/test_qg_review_readable.sh && bash shared/tests/test_ask_material_wiring.sh` — PASS. 새 락마다 변이 둘(그 문장 지우기 · 옛 문장 되살리기)로 RED 를 보고 복원한다(Global Constraints 의 차례).
- [ ] **Step 6: 커밋.** `git commit -m "docs(conductor): 머지 앞 qg 리뷰를 상태 스크립트로 — 기록은 기록 브랜치에" -- plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/tests/test_qg_review_reference.sh plugins/spec-distill/tests/test_qg_review_readable.sh shared/tests/fixtures/ask-sites.tsv`

---

### Task 11: `conducting.md` — 다시 들어오기 · 머지 관문 · team 형식

**AC:** AC1(team 펜스에서 읽는 문장 없음) · AC20(team 형식 절이 펜스를 표시로) · AC6 · AC8(문서가 「다음」 · 「관문」 을 부르는 자리) · AC10(승인 기록 다시 보이기가 스크립트 글을 싣는다).

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md`
- Modify: `plugins/spec-distill/tests/test_conducting_loop.sh`

- [ ] **Step 1: 지금 락을 고른다.** `test_conducting_loop.sh` :248–251(걸음 5 의 qg 답 문장 — PR 본문 · team 펜스 · 기록 `- 답:`)을 새 문장으로 다시 쓴다. :46 · :51–52 · :61 · :129 는 그대로 두되 :61 은 아래 Step 2 의 양 단언과 함께 본다. `plugins/spec-distill/tests/test_qg_review_reference.sh` 의 AC9(:754–755 — 걸음 5 「머지 앞 qg 리뷰 → PR 본문 `## qg 리뷰`」) · team 검수 걸음(:762–772)도 이 과제에서 다시 쓴다. `plugins/spec-distill/tests/test_conducting_reference.sh` :235(걸음 5 「…PR 캐시를 새로 채운 뒤 머지 앞 qg 리뷰와 되돌리기 → 스위트 대조」)는 관문이 그 사이에 들어가 깨진다 — 「… 머지 앞 qg 리뷰와 되돌리기 → 관문(`gate`) → 스위트 대조」 꼴로 다시 쓴다.
- [ ] **Step 2: 새 락(RED).** `test_conducting_loop.sh` 에 — `step1-calls-next`(걸음 1 맞추기와 손으로 따르는 절차가 머지 앞 리뷰가 있는 PR 마다 `qg_review_state.py next` 를 부른다 · 살아 있는 이름은 「원천」 · 「세션 담당자의 원천」 으로 센다) · `step5-gate`(걸음 5 의 머지 전 확인이 스위트 대조 앞에서 `qg_review_state.py gate` 를 부르고 「rc 0 일 때만 머지 준비로 간다」, 그 밖이면 걸린 까닭의 할 일을 `next` 로 — 옛 형식 · team 형식 둘 다 / 음: 「rc 1 이면」 처럼 닫힘 하나만 적어 다른 rc 가 지나가는 문장 없음) · `step5-approval`(승인 기록 다시 보이기의 qg 몫은 `render --kind approval` 의 글 / 음: 기록 파일 `- 답:` · PR 본문 `## qg 리뷰` 의 사용자 답에서 읽는 문장 없음) · `lock-users-qg`(잠금 문장이 쓰는 쪽에 qg 를 더한다 — 「지휘자의 스위트 대조 · 하위 agent 의 전체 스위트 · qg」) · `team-review-qg`(「검수 걸음의 qg」 가 같은 스크립트 · 대상 `<과제>-plan<n>` · `--job-dir` · 펜스는 `render --kind team-fence` 를 싣는 표시 · 「두 번까지」 는 옛 형식과 같음 · 기본 브랜치 합치기를 하지 않음 · 자리 글자 `premerge-<과제>-plan<n>` · `recheck-<과제>-plan<n>` / 음: 「펜스 하나 안에 적고 거기서 센다」 없음 · 시작 묶음 · 과제 결정 기록에 싣는 글에 보관 폴더 · 상태 파일 경로 없음 · 반려 때도 `record` 의 `return`) · `team-handling-header`(team 형식의 시작 묶음과 과제 결정 기록에 싣는 글이 다음 시도의 구현 결과 파일의 `## 지적마다의 처리` 머리 아래에 지적마다의 처리를 쓰라고 싣는다 — D74) · `mark-timing-step3`(걸음 3 의 「잘못 골랐다」 로 설계 대화에 돌아간 에픽 문장(:37 근처)이 고친 설계의 구현이 돌아오면 `record` 의 `mark` 「다시 구현됨」 을 적는다고 싣는다 — AC9).
- [ ] **Step 3: 문서를 고친다.** :17–:20 · :37(걸음 3 의 설계 대화로 돌아간 에픽 — 표시를 적는 때) · :66–:82(걸음 5 — :73 · :80) · :123 · :130 을 위 락대로. 문장은 「스크립트를 부르고 그 답대로 한다」 로 줄이고 조건을 다시 적지 않는다.
- [ ] **Step 4:** `bash plugins/spec-distill/tests/test_conducting_loop.sh && bash plugins/spec-distill/tests/test_qg_review_reference.sh` PASS. 새 락마다 변이 둘로 RED 를 보고 복원한다.
- [ ] **Step 5: 커밋.** `git commit -m "docs(conductor): 다시 들어오기와 머지 관문이 리뷰 상태 스크립트를 부른다" -- plugins/spec-distill/references/conducting.md plugins/spec-distill/tests/test_conducting_loop.sh plugins/spec-distill/tests/test_qg_review_reference.sh`

---

### Task 12: §8 의 락 다섯과 qg 꼴 문서

**AC:** AC21(락 다섯 · 변이에서 실패) · AC2 · AC3(읽는 꼴이 문서에 있음).

**Files:**
- Create: `plugins/spec-distill/tests/test_qg_review_state_locks.sh`(100755)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`(합치기 전 지적 목록 `findings-pre-merge.yaml` 의 키 `findings` 와 막는 등급 칸 · 읽히는 절 이름 · 목록 머리 셋을 「같은 폴더의 다른 파일」 · 결과 파일 절에 적는다 — 꼴을 바꾸지 않고 있는 것을 적는다)

락 다섯 — 각 락은 한 쪽의 글자를 다른 쪽이 쓰는 이름과 견준다(한 쪽만 핀하지 않는다).

1. `gate-call` — `conducting.md` 걸음 5 의 옛 형식 · team 형식 문장 둘이 `qg_review_state.py gate` 를 스위트 대조 앞에 두고, 걸음 1 · 손으로 따르는 절차가 `next` 를 부른다. 그 명령 이름이 `qg_review_state.py --help` 의 하위 명령에 있다.
2. `team-sentences` — `conducting.md` 의 team 문장 셋(「두 번까지」 는 옛 형식과 같음 · 기본 브랜치 합치기를 하지 않음 · 자리 글자 꼴)과 스크립트가 받는 대상 꼴(`fullmatch` 하는 정규식을 스크립트에서 읽어 문서의 예에 대어 본다).
3. `reason-words` — 리뷰어가 「전에 물은 것」 에 붙이는 까닭 낱말 둘이 `plugins/quality-gates/scripts/intent_critic.py` 의 상수와 `qg-review.md` 에서 같다(파이썬으로 상수를 import 해 문서에서 찾는다).
4. `qg-file-shape` — `qg_review_archive.py` 가 읽는 이름(절 `## 판정` · `## 범위` · `## 고칠 목록` · `### 막는 지적` · `### 차등 회귀`, 목록 머리 `이미 답한 질문이라 거른 질문:` · `이미 「잘못 골랐다」 답이 있어 거른 질문:`, 파일 `findings-pre-merge.yaml` 의 `findings`, 돌려주는 꼴의 `state` 와 값 `묻지 않음` · `상한 넘어 남김`, 리뷰할 것 없음의 판정 둘)을 모듈 상수에서 뽑아 `state-file-format.md` 에 모두 있는지 잰다. 목록 머리 둘은 `intent_critic.py` 의 출력 문자열과도 견준다.
5. `no-paths-to-reviewed` — 양: `qg-review.md` 되돌리기의 보내는 글 · `conducting.md` team 다음 시도의 글에 처리 파일 절대경로 자리 문장. 음: 그 두 글(펜스 안)과 PR 본문 호출 줄 꼴 문장에 `보관 폴더` · `qg-review-state.md` · `--answered` · `--suite-lock` 이 없음. 호출 줄 꼴이 `- 호출 · <자리 글자> · <범위>` 이다(표시 글 자체는 Task 8 의 스크립트 테스트가 잰다).

- [ ] **Step 1:** 락 다섯을 쓰고 `chmod +x` · `bash plugins/spec-distill/tests/test_qg_review_state_locks.sh` 가 4 에서 RED(꼴 문서에 아직 없음)인 것을 본다.
- [ ] **Step 2:** `state-file-format.md` 에 적는다. PASS.
- [ ] **Step 3: 변이.** 커밋한 뒤 락마다 변이 둘 — 문서의 그 문장 · 낱말 · 이름 지우기와 바꾸기(예: 1 은 걸음 5 문장에서 `gate` 를 `next` 로, 3 은 문서 쪽 낱말 하나 바꾸기, 4 는 모듈 상수 하나에 글자 하나 더하기, 5 는 보내는 글 펜스에 `qg-review-state.md` 한 줄 넣기) — 모두 RED 를 보고 `git checkout HEAD -- <파일>` · `git diff HEAD` 빈 것으로 복원한다. 양성 대조로 변이 없는 실행이 GREEN 인 것을 함께 적는다. 결과를 `TMPDIR/mutations.md` 에.
- [ ] **Step 4: 커밋.** `git ls-files -s plugins/spec-distill/tests/test_qg_review_state_locks.sh` 가 `100755` 인지 보고 `git commit -m "test(conductor): 두 플러그인이 함께 쓰는 이름과 경로 없는 글을 락으로" -- plugins/spec-distill/tests/test_qg_review_state_locks.sh plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`

---

### Task 13: 걸어 보기 — 한 PR 을 명령만으로

**AC:** Verification Plan 「걸어 보기」 · AC8 · AC31 의 끝에서 끝 · AC18(여러 줄 지적 줄을 기록 명령이 받음).

**Files:**
- Create: `plugins/spec-distill/tests/test_qg_review_state_walk.py`

- [ ] **Step 1: 테스트를 쓴다.**
  - `test_walk_one_pr_with_three_cuts` — `Rig` 위에서 `open`(첫 리뷰) → `send` 둘 → 결과 파일(막는 지적 둘) → `back` → `record`(`return`) → 구현 커밋 · 처리 절 → `record`(`return_moved` + 처리) → `open --site recheck` → `send` → 결과 파일(막는 지적 없음) → `back` → `gate` rc 0. 세 곳(보내는 중 직후 · 돌려보낸 직후 · 재리뷰를 연 직후)에서 그때까지의 상태만 두고 `next` 를 불러 그 할 일로 이어도 같은 끝에 닿는다.
  - `test_walk_doc_fences_run` — `qg-review.md` 의 `qg_review_state.py` 펜스를 문서 차례로 뽑아 자리 표시(`<로드맵>` 등)를 `Rig` 값으로 바꿔 돌리면 rc 가 0 · 1 · 4 가운데 문서가 그 자리에 적은 것이다.
  - `test_folded_finding_line_accepted` — 여러 줄 지적의 첫 줄 + 「…(전문: qg-E1-premerge-pr12-2026-11-26의 지적 목록)」 줄을 `conductor_ledger.py record --spec <설계문서> --line` 이 받고(rc 0), 접지 않은 여러 줄 값은 rc 2 로 거절한다(AC18).
- [ ] **Step 2:** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state_walk -v` PASS(앞 과제가 섰으면 처음부터 GREEN 이어도 된다 — 대신 `next` 를 한 줄 틀리게 고친 변이로 첫 테스트가 RED 가 되는지 한 번 본다).
- [ ] **Step 3: 커밋.** `git commit -m "test(conductor): 한 PR 의 리뷰 흐름을 명령만으로 걸어 본다" -- plugins/spec-distill/tests/test_qg_review_state_walk.py`

---

### Task 14: 의존 · README · CHANGELOG · 판

**AC:** AC22(판 · CHANGELOG · README 한계 둘 · 의존 표 PyYAML 행 · 제안 열다섯의 가름).

**Files:**
- Modify: `plugins/spec-distill/dependencies.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json`
- Modify: `plugins/plugin-audit/CHANGELOG.md` · `.claude-plugin/plugin.json` · `plugins/project-init/CHANGELOG.md` · `.claude-plugin/plugin.json`(공유 `check_deps.py` 를 싣는 플러그인 — D76)
- Modify: `plugins/spec-distill/tests/test_qg_review_readable.sh`(머리 주석 — 제안 34 · 35)
- Modify: `shared/deps/check_deps.py`(`plugins/spec-distill/scripts/check_deps.py` 가 심볼릭 링크로 가리키는 정본 — `_measure_row` 에 PyYAML 을 재는 길) · `shared/tests/test_check_deps.py`(PyYAML 이 있을 때 판 셋 · 없을 때 사유 줄을 재는 테스트) — D73

- [ ] **Step 1: 의존 표.** `dependencies.md` 에 PyYAML 행(강도 「알림」, 없을 때 「답 넘기기는 rc 5 로 답 없이 보낸다(질문이 더 나온다) · 리뷰 상태의 「돌아옴」 은 합치기 전 지적 목록 대신 결과 파일의 고칠 목록에서 옮기고 의도 점검은 셀 수 없음으로 둔다 — 둘 다 그렇다고 알린다」)을 더한다. 판 칸 둘은 측정이 쓴다(손으로 고치지 않는다 — D73). 측정은 이렇게 고친다(D76) —
  - 실패하는 테스트 먼저: `shared/tests/test_check_deps.py` 에 `test_measure_pyyaml_present`(PyYAML 이 있는 하위 프로세스에서 `_measure_row("PyYAML", …)` 가 `yaml.__version__` 의 판 셋과 사유 `None` 을 낸다) · `test_measure_pyyaml_absent`(`yaml` import 를 막은 하위 프로세스에서 판 `None` 과 사유 「PyYAML 을 불러오지 못했다」). 판 글자는 박지 않고 그 프로세스의 `yaml.__version__` 과 견준다. `cd shared/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_check_deps -v` 로 FAIL 을 본다.
  - `shared/deps/check_deps.py` 의 `_measure_row` 에 `name == "PyYAML"` 갈래 — 함수 안에서 `import yaml` 하고 `version_triple(yaml.__version__)`, import 가 실패하면 `(None, "PyYAML 을 불러오지 못했다")`. 다른 이름의 갈래는 그대로.
  - 같은 명령 PASS 와 `bash shared/tests/test_check_deps.sh` PASS. 그 뒤 `python3 plugins/spec-distill/scripts/check_deps.py measure` 로 PyYAML 행 판 칸을 채운다(다른 행의 판 칸이 함께 바뀌면 그대로 둔다 — 측정이 쓴 값이다).
  - 다른 세 플러그인의 `dependencies.md` 에는 PyYAML 행을 더하지 않는다(그 플러그인의 의존이 바뀐 것이 아니다 — 측정할 수 있는 이름이 는 것이다).
- [ ] **Step 2: README.** `## 한계` 에 둘 — §6 의 한계(에픽 PR diff 에 섞인 가짜 기록 · qg 가 스스로 읽는 답 파일)와 Non-goals 의 한계(상태 파일은 기계 상태와 같은 폴더 나무 · 처리 파일 경로의 옆 폴더라 같은 사용자 권한의 담당자가 고치는 것을 막지 못한다 · 마지막 확인은 승인 기록 다시 보이기 · 지워진 지적은 거기에도 보이지 않는다). Principles Instantiated 에 새 스크립트 한 줄. 스크립트 목록에 `qg_review_state.py` 세 모듈.
- [ ] **Step 3: 판 · CHANGELOG.** 지휘자가 준 번호로 네 `plugin.json`(spec-distill · quality-gates · plugin-audit · project-init)을 올리고, plugin-audit · project-init 의 CHANGELOG 에는 Changed(「의존 측정(`check_deps.py measure`)이 PyYAML 판을 잰다 — 공유 파일 변경」) 한 줄을 적는다. spec-distill · quality-gates 는 CHANGELOG 에 `## [<판>] — <날짜>` 와 Added(상태 스크립트 · rc 4 · 5) · Changed(기록 자리 · 머지 앞 절차 · 이름으로 청한 리뷰는 앞 리뷰가 닫힌 뒤) · Fixed(답 넘기기 가장자리) — quality-gates 는 Changed(꼴 문서에 읽히는 이름을 적음).
- [ ] **Step 4: 머리 주석.** `test_qg_review_readable.sh` 머리 주석이 잠그는 파일(`qg-review.md` · `dependencies.md` · `README.md`)을 다 적고 은퇴한 규칙 문구를 뺀다(제안 34 · 35).
- [ ] **Step 5:** `bash shared/tests/test_plugin_versions.sh` 같은 판 락이 있으면 그것과 `bash plugins/spec-distill/tests/test_qg_review_readable.sh` PASS(판 락의 실제 이름은 `git ls-files 'shared/tests/*' | grep -i version` 으로 찾는다).
- [ ] **Step 6: 커밋.** `git commit -m "chore(conductor): 리뷰 상태 스크립트의 의존 · 한계 · 판" -- <위 파일들>`

---

### Task 15: 끝 확인 — 스위트 · 전체 리뷰 · 미룸

**AC:** 전체(AC1–AC33 의 보고).

**Files:** `docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md`(`## 미룸` 표에 행만 더한다), 보고 파일 `TMPDIR/ac-report.md`(git 이 추적하지 않는다).

- [ ] **Step 1: 전체 스위트.** Global Constraints 의 잠금 줄로 `bash tools/suite/run-all.sh` 를 돈다. 실패는 이름을 모두 보고에 적는다 — 기본 브랜치 끝과의 대조는 지휘자의 스위트 대조가 한다.
- [ ] **Step 2: 전체 리뷰.** 실행 방식의 마지막 전체 리뷰(쓰기 도구가 없는 리뷰어)에 설계문서 `## Acceptance Criteria` 의 AC1–AC33 을 글자 그대로 싣고, AC 마다 한 줄 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거(파일:줄 · 테스트 이름)>` 로 보고하게 한다. 같은 리뷰에 묻는다 — 설계문서 `## 있는 것 검토` 가 고른 것(보관 폴더와 자원 줄 · 결과 파일의 범위 · 판정 절과 합쳐지기 전 지적 목록 · `nofollow_write` · `qg_answered.py` 의 원자 쓰기 · 알림 파일 · `ledger human-check` · 에픽 보고 폴더 · 기록 브랜치 · 살아 있는 담당자의 원천)을 실제로 썼는지, 같은 것을 다시 만들지 않았는지(새 자원 폴더 규칙 · 새 원자 쓰기 · 새 알림 목록 · 새 원장 명령이 없는지). 이음매를 명시해 묻는다 — `open` 이 낸 범위 → 호출 줄 → qg `result.md` · `findings-pre-merge.yaml` · `intent-return.md` → `back` → `record` → `gate` · `next` → `render` 가 끝에서 끝으로 같은 이름 · 같은 범위 꼴 · 같은 대상 꼴을 말하는지, 각 명령의 rc 를 지휘 절차 문서가 읽는지, 「다음」 이 낸 `열기` 를 `open` 이 거절하는 상태가 없는지. 이 계획이 시킨 테스트 코드(Task 3 의 줄 목록 · Task 13 의 걸어 보기)는 「계획이 쓴 테스트」 라고 라벨을 붙여 따로 보게 한다.
- [ ] **Step 3: 보고 파일.** 리뷰의 AC 줄들을 `TMPDIR/ac-report.md` 에 쓴다.
- [ ] **Step 4: 미룸 표.** 리뷰가 미룸 · 빠짐으로 낸 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 `| 항목 | 이유 | 받는 곳 |` 행으로 더한다(받는 곳은 로드맵의 에픽 번호 또는 `#<PR 번호>`). 커밋: `git commit -m "docs(spec): R9 구현 뒤 미룸을 적는다" -- docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md`
- [ ] **Step 5: 덮음 확인.** PR 을 만들기 전에 `python3 <spec-distill 설치본>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md "$TMPDIR/ac-report.md"` 를 돌려 출력 전부를 마지막 보고에 싣는다(경고는 지휘자가 사용자에게 보인다).
- [ ] **Step 6: PR 본문 재료.** 제안 열다섯(§7)의 가름 — 「들어감」 은 그 AC, 「계획이 가림」(24 · 27 · 32 · 33 · 34 · 35 · 23 의 가드)은 「받음 — Task 9 · 14」, 「남김(받는 곳 없음)」(25 의 사유 나누기)은 그대로 — 과 Task 10 Step 1 의 지우는 락 대응표를 마지막 보고에 싣는다(AC22). PR 본문 인계 절(`## 통합 리뷰 인계`)에 「이 PR 이 공유 `check_deps.py` 때문에 plugin-audit · project-init 의 판을 올린다 — 그 둘을 고치는 다른 PR 과 판 번호가 겹칠 수 있고, 뒤에 머지되는 쪽이 맞춘다」 를 싣게 마지막 보고에 적는다.

---

## Deferred to plan 의 처리

| 설계의 항목 | 처리 | 자리 |
|---|---|---|
| 스크립트의 명령줄 · 종료 코드 · 상태 파일의 마크다운 꼴 | 계획이 정함 — 아래 「계획이 정한 것」 1–3 | Task 2 · 4–8 |
| 보고 폴더 안 처리 파일의 이름 | 계획이 정함 — 4 | Task 10 |
| 「리뷰할 것 없음」 · 거른 질문 목록 둘의 머리 | 다시 확인에서 확인 — 리뷰할 것 없음은 `not-certified (trivia)` · `(scope-empty)`, 목록은 D71(사용자 「빼서 짓는다」) | Task 5 · 12 |
| 과제 나누기 · PR 을 둘로 나눌지 | 한 PR — 문서(Task 10–12)가 스크립트의 명령 이름을 글자로 인용해, 나누면 앞 PR 의 문서가 없는 명령을 가리키거나 뒤 PR 까지 옛 문장이 남는다 | 이 계획의 과제 차례 |
| 첫 과제의 가벼운 다시 확인 · 두 점검의 질문 스물셋 | 계획 때 한 번 했다(열아홉은 설계가 답함, 넷은 「계획이 정한 것」 5–8) · 구현 시작 때 Task 1 | Task 1 |
| 2e6610eb#r2.1(표 밖 원칙 훑기) | 과제에 넣음 — 원칙 훑기를 먼저 쓰는 과제 | Task 3 |
| acd85e0f#r1.1 · b0677fb9#r1.1 · 966d608c#r1.1 · fccf272b#r1.1 · 4b91e38a#r2.1 · 25728d2f#r2.2 · b942fc8e#r2.1 · ef79c297#r2.1 · 1cdda836#r2.1 · 7dd35c85#r2.1 · c55fe6a5#r3.1 · 7d012e4a#r4.1 · bb9e8224#r4.1 | 반영 확인 — 설계 본문에 이미 들었다(D34 · D35 · D40 · D44 · D46–D58 · D59 · D61 · D68 · D69) | 해당 과제가 그 본문을 구현한다 |
| 45057633#r4.1 | 반영 확인 — §4 「지휘자가 가린다」(D70) | Task 7 `지휘자가 가린다` 줄 |
| 지휘 절차 문서의 머지 앞 기록 파일 · PR 본문 읽기 문장 전수(D70 · 지휘자 주의) | 과제에 넣음 — 계획 때 뽑은 표 | Task 10 의 표 · Task 11 |

## 겹치는 에픽

| 파일 | R7(`feature/qg-planted-text-suite-lock`, 구현 중) · R8(`feature/qg-answer-record-edges`, 계획 전) | 이 계획 |
|---|---|---|
| `qg-review.md` | R7: 호출 줄에 `--suite-lock` · 다시 부르기 「모르는 인자마다 한 번씩」 · 겹침 문장 | Task 10 — 호출 줄 꼴은 두고 MF 절차를 바꾼다. 경로 없는 표시 글의 음에 `--suite-lock` 도 넣는다 |
| `test_qg_review_reference.sh` | R7: 새 케이스 넷 | Task 10 — R7 케이스는 건드리지 않는다 |
| `test_qg_review_readable.sh` | R7: 의존 케이스 둘 | Task 10 · 14 |
| `dependencies.md` · spec-distill 판 · CHANGELOG | R7: quality-gates 행 · minor | Task 14 — 합친 뒤 `check_deps.py measure` 를 다시 |
| `state-file-format.md` | R7: 다른 파일 목록 · 게시 문단 / R8: 결과 줄 목록 · `commit` 값 · 「묻지 않음」 뜻 | Task 12 — 합치기 전 목록 · 읽히는 이름만 |
| quality-gates 판 · CHANGELOG | R7 · R8 | Task 14 |
| `findings-pre-merge.yaml` 의 쓰는 때 | R7 Task 12: 판정 뒤에만 쓰고 실패하면 지운다 | Task 5 의 고칠 목록으로 내려가는 길이 실제 길 |
| `conducting.md` 잠금 문장 | R7 D48 이 R9 로 넘김 | Task 11 `lock-users-qg` |
| `qg-review.md` 「## 호출 줄」 절 | R7: 호출 줄 · 다시 부르기 문장 | Task 10 — 같은 절의 quality-gates 가 없을 때 문장 옆에 `--no-qg` 를 넘기는 문장을 더한다 |

이 PR 은 공유 `check_deps.py` 때문에 plugin-audit · project-init 의 판도 올린다(D76) — 그 둘을 고치는 다른 PR 과 판 번호가 겹칠 수 있다. 뒤에 머지되는 쪽이 기본 브랜치를 합친다. 같은 판 번호로 올린 `plugin.json` 은 충돌 없이 합쳐질 수 있어 합친 뒤 기본 브랜치 쪽 판을 `git diff` 로 견준다.

## 계획이 정한 것 (설계에 없던 자리)

설계가 「계획이 정한다」 로 둔 자리와, 설계가 말하지 않아 이 계획이 채운 자리다. 사람에게 보이는 글자나 동작이 새로 생기는 것은 ★ 로 표시했다.

1. **명령줄** — `qg_review_state.py <open|send|back|record|next|gate|render> --roadmap --target [--repo] [--at]`, 뺄 파일 `--spec` | `--job-dir`, 대상 꼴 `pr<번호>` · `<과제>-plan<n>`. 쓰기 명령은 마지막 리뷰에만 쓴다(상태 파일 경로를 인자로 받지 않는다). 다른 길: 상태 파일 경로를 인자로 받는다(지휘자가 경로를 다뤄야 하고 다른 리뷰에 쓸 수 있다).
2. **종료 코드** — 0 됨 · 1 관문 닫힘 · 2 사용법 · 3 파일 · 4 받지 않음. 다른 길: 관문 닫힘도 0 과 출력 줄로만.
3. **상태 파일 꼴** — 보관 폴더의 `qg-review-state.md`, 머리 목록 + 절 여섯, 항목은 `### <번호>` · `- 이름: 값` · 두 칸 들여 쓴 여러 줄 값, 판 줄 `- 판: 1`. `record` 의 입력은 JSON 파일. 상한 · 세는 수는 칸으로 두지 않고 답에서 셈.
4. **처리 파일** — 하위 agent 는 그 에픽 보고 폴더의 `handling-<자리 글자>-<n>.md`(돌려보낼 때마다 새 `<n>`), 세션 담당자는 그 결과 파일, team 은 다음 시도의 구현 결과 파일. 어느 것이든 처리는 `## 지적마다의 처리` 절 — 스크립트는 그 머리가 있는지로 「처리 파일이 있다」 를 본다. 다른 길: 처리 파일을 따로 두지 않고 세션 담당자도 `handling-…md` 를 쓴다.
5. **리뷰할 것 없음** — `## 판정` 첫 줄의 `not-certified (trivia)` · `not-certified (scope-empty)`.
6. **「보내는 중」 의 담당자가 옮긴 파일** — 보관 폴더에서 지휘자가 보내기 전에 만드는 파일(상태 파일 · 「이미 답한 것」 파일 · 알림 파일) 밖의 파일. 하나라도 있으면 돌아옴 — 결과 파일이 없으면 지적 목록을 얻지 못함의 사용자 질문으로 간다(D75 — 처음 안의 「`result.md` 하나」 를 설계대로 고침).
7. ★ **qg 담당자의 설명 글** — `qg <자리 글자> <차례>`(예: `qg premerge-pr12 1`). 지휘자가 하니스 목록에서 살아 있는 담당자를 이 글로 찾는다. 하니스 목록 · 상태 화면에 보이는 글이다 — 사용자 「이대로 둔다」(D72).
8. **기록을 커밋한 뒤 경로를 적기 전에 끊김** — 기록 파일을 쓰기 전에 기록 브랜치에서 `- 보관 사본:` 이 이 보관 폴더인 기록을 찾아, 있으면 그 경로를 적는다(같은 기록을 `-2` 로 또 쓰지 않는다).
9. ★ **답 넘기기의 새 종료 코드** — rc 4(알림 파일만 못 씀 — 끝 줄 「알림 파일을 쓰지 못했다 — 알림은 위 줄뿐이다」는 설계 글자) · rc 5(PyYAML 없음 — 「PyYAML 이 없다 — 답 없이 보낸다」) — 사용자 「이대로 둔다」(D72).
10. **`conductor_ledger.py`** — 설계의 「여러 줄 지적을 받는 꼴」 은 지금 `record --line` 이 한 줄만 받고 여러 줄은 rc 2 로 거절해 이미 맞는다 — 꼴을 바꾸지 않고 Task 13 이 그 동작을 잰다. 대신 자원 폴더 · 자원 줄 몸통을 함수로 떼어(동작 그대로) 새 스크립트가 같은 규칙을 쓴다. 다른 길: 새 스크립트가 `conductor_ledger.py` 를 하위 프로세스로 부른다.
11. **보관 폴더의 자원 줄 종류 칸** — `qg 보관`. 다른 길: 지금 문서가 적는 종류 글자가 있으면 그것.
12. ★ **리뷰 상태의 PyYAML 없을 때** — `back` 은 멈추지 않는다(rc 0). 막는 지적을 결과 파일의 `### 막는 지적` 에서 옮기고 의도 점검은 셀 수 없음으로 두며 `알림 · PyYAML 이 없다 — 합치기 전 지적 목록 대신 결과 파일의 고칠 목록에서 옮겼다` 를 낸다. 지금 있는 두 길(합치기 전 목록이 없을 때 · 돌려주는 꼴을 읽지 못할 때)로 떨어지는 것이라 새 동작은 그 알림 한 줄뿐이다. 다른 길: rc 3 으로 멈추고 지휘자가 사용자에게 보인다.
13. **「처리 파일이 있다」** — 그 파일의 `## 지적마다의 처리` 머리 줄로 가리고, 두 형식의 보내는 글이 그 머리를 쓰라고 싣는다 — 사용자 「머리 줄로 가리고 team 형식에도 싣는다」(D74).
14. **세 모듈** — 설계의 「스크립트 하나」 는 명령줄 하나(`qg_review_state.py`)로 지키고, 꼴과 보관 폴더 읽기를 두 모듈로 뗐다(레포의 「새 책임은 별도 모듈」). 다른 길: 한 파일.

## 두 점검의 질문 스물셋

설계 Handoff 가 시험 문제로 둔 질문(지휘 자원 `report/R9/builder-check.md` 열셋 · `builder-check-2.md` 열)이 어디서 답해지는지다.

| 질문 | 요지 | 답하는 자리 |
|---|---|---|
| 1-1 | 막는 지적 목록을 PR 본문에서 읽는다 | 설계 §1 「막는 지적」 칸 · §5 · Task 5 · 8 · 10 |
| 1-2 | 등록부가 에픽 브랜치 기록을 다 덮지 못한다 | 설계 §6(에픽 브랜치를 읽지 않음 · D23) · Task 9 · 10 |
| 1-3 | 돌아온 리뷰를 파일로 가르는 법 | 설계 §1 「돌아온 결과를 가리는 법」 · Task 5 |
| 1-4 | team 형식이 빠진다 | 설계 §9 · Task 2 `test_targets_do_not_mix` · Task 11 |
| 1-5 | 「범위가 다르다」 의 갈래 | 설계 §1 표 셋째 줄 · D4 · Task 5 `test_back_range_mismatch` |
| 1-6 | `ran` 밖의 끝 · qg 없음 | 리뷰할 것 없음은 「계획이 정한 것」 5 · 그 밖은 판정 없음 → §3 질문 · qg 없음은 Task 7 `test_gate_no_qg` |
| 1-7 | §3 질문이 끊기면 사라진다 | 설계 §1 물을 것 · 훑기 `R3a` |
| 1-8 | 다시 보내기 표지와 「두 번까지」 | 설계 §2 · §3(다시 보낸 것은 세지 않음) · Task 4 `test_cap_counts_only_obtained_rechecks` |
| 1-9 | 보내기 전 끊김을 못 가른다 | 「보내는 중」 · 「계획이 정한 것」 6(D75) · Task 7 두 테스트 |
| 1-10 | 등록부 없는 두 규칙이 한 조건 | 등록부 없앰(D23) — 해당 없음 |
| 1-11 | 등록부 밖 · 깨진 파일과 읽지 못한 기록 | 설계 §6 · §7 · Task 9 `test_unreadable_record_drops_same_target` |
| 1-12 | qg 가 리뷰 트리의 답 파일을 스스로 읽는다 | 설계 §6 한계 · Task 14 README |
| 1-13 | `spec-resend` 에도 같은 구멍 | 설계 §4 끝 · Task 10 `spec-resend-commit` |
| 2-1 | 브랜치 끝 움직임과 고친 커밋 | 설계 §2 기준 커밋 · Task 4 `test_base_commits_*` |
| 2-2 | §4 표의 틈(a–f) | 설계 §1 닫는 조건 · §4 표 · 훑기 Task 3 |
| 2-3 | 담당자가 사람 질문에서 멈춤 | 설계 §1 「파일에 남아야 하는 것」 · 훑기 `R1c` |
| 2-4 | 리뷰 사이 지적의 정체 | 설계 §3 까닭 7(맞추지 않음) · Task 7 `test_gate_fixed_finding_closes_by_later_review` |
| 2-5 | 「두 번까지」 를 묻는 때 | 설계 §2 「묻는 때」 · 훑기 `test_cap_cases` |
| 2-6 | 보낸 뒤 「보냄」 전에 끊김 | 「보내는 중」 · 지휘자 가림 · 「계획이 정한 것」 7 · Task 10 `worker-description` |
| 2-7 | 답 기록에서 상태 파일까지 | 설계 §4(먼저 `record`, 다음 기록 파일) · 「계획이 정한 것」 8(기록 겹침 막기) |
| 2-8 | §6 사용자 확인과 반목표 | 등록부 · 확인 없앰(D23) — 해당 없음 |
| 2-9 | §7 · §8 알림 접기 자리 | 설계 §8(지휘자의 리뷰 글) · Task 10 `notice-fold` |
| 2-10 | 고칠 파일 빠짐 · team 펜스 | 설계 Files to Modify · Task 10–12 · Task 8 `test_team_fence_outer_longer` |
