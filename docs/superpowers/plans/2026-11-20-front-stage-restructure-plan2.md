# 앞단 다시 짜기 — 계획 2 (나머지 다섯 층과 옛 기록 읽기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 키 · 폴더 · 설계문서 머리 키 · 종류 글자 · 파일 이름 끝의 다섯 층을 새 글자로 바꾸고(새로 쓰는 기록은 새 글자만), 옛 글자로 쓰인 기록은 고치지 않은 채 그대로 읽히게 하며, 스크립트가 내는 안내 · 판결 글자와 quality-gates 의 글 속 낱말을 새 이름으로 맞춘다 — spec-distill 과 quality-gates 의 판을 올린다.

**Architecture:** 옛 글자와 새 글자의 대응을 새 모듈 `plugins/spec-distill/scripts/legacy_names.py` 하나에 두고, 종류 글자를 견주는 곳 · 파일 이름 끝으로 찾는 곳 · 머리 키로 잇는 곳이 모두 그 모듈로 옛 글자를 안다(다른 스크립트에는 옛 글자 리터럴이 없다 — 락이 문다). 설정은 `intent_dir` 가 새 폴더를, 옛 키 `interview_dir`(없으면 옛 기본값)가 옛 폴더를 정하고, 경로 검사는 옛 폴더에서 옛 꼴 이름만 더 받는다. quality-gates 는 다른 플러그인이라 모듈 없이 자기 표지 목록에 두 머리 키를 둔다.

**Tech Stack:** Python 3(표준 라이브러리 · unittest · tokenize) · bash 3.2 호환 셸 펜스와 셸 테스트 · git.

**Spec:** `docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다(설계 2 「이름 여섯 층」 · 설계 3 「옛 기록을 읽는 길」 · 설계 6 「객체와 주인」 · `## Acceptance Criteria` 의 계획 2 절). 설계문서 끝 `### Deferred to plan` 표는 본문에 이미 반영돼 있다 — 그 표의 「고치면」 을 과제로 삼지 않는다. 앞 계획은 `docs/superpowers/plans/2026-11-20-front-stage-restructure-plan1.md` 다(끝의 `## 계획 2 에 넘길 메모` 는 모두 이 계획의 과제가 받는다 — 과제 지도의 「메모」 칸).

## Global Constraints

- **판.** spec-distill 과 quality-gates 를 각각 「머지 직전 기본 브랜치 위의 다음 minor 번호」 로 한 번씩 올린다(새 설정 키 · 새 기본 폴더 · 새 종류 글자 · quality-gates 의 새 기본 표지 — 옛 기록은 그대로 읽히므로 major 가 아니다). 숫자는 박지 않는다 — 같은 판으로 올린 `plugin.json` 은 조용히 합쳐지므로 머지 직전에 `git diff origin/<기본 브랜치> -- plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json` 으로 견준다. 변경 기록 머리 날짜도 그때 정한다.
- **새 글자(설계 2 표 · 설계 6 표 그대로).**
  - 설정 키 `interview_dir` → `intent_dir`. 기본 폴더 `docs/superpowers/interview/` → `docs/superpowers/intent/`(글에서 「의도 폴더」).
  - 머리 키 `source_interview` → `source_intent`.
  - 종류 글자: `interview-seed` → `intent-seed` · `interview-seed-audit` → `intent-seed-audit` · `interview-state` → `context-state` · `interview-brief` → `context-brief` · `interview-audit` → `context-audit`.
  - 파일 이름 끝: seed `…-interview.md` → `…-intent.md`(framing 기록 `…-intent.audit.md`) · 결과물 `…-interview.md` → `…-context.md` · 상태 파일 `…-interview.state.md` → `…-context.state.md` · 결과물 audit `…-context.audit.md`(`.audit.md` 붙이기는 그대로).
  - 스크립트가 내는 판결 글자와 펜스 표지: `interview-state:` → `context-state:` · `<!-- interview-state-entry:… -->` → `<!-- context-state-entry:… -->`. 옛 판결 글자를 읽는 호환은 두지 않는다.
- **옛 기록 읽기(설계 3).** 쓰는 쪽은 새 글자만, 읽는 쪽은 옛 글자도. 옛 기록 파일과 옛 폴더는 옮기지도 고치지도 않는다 — 이 PR 의 diff 에 `docs/superpowers/interview/` 아래 변경이 없다(AC27). 진행 중이던 일(옛 꼴 상태 파일)은 그 폴더 · 그 줄기로 끝까지 가고, 새로 시작하는 일은 옛 seed 로 시작해도 새 폴더 · 새 꼴이다. 새로 쓰는 `type:` 은 어느 경우에나 새 글자다.
- **그대로 두는 것.** 스크립트 파일 이름(`interview_state.py` 등) · 템플릿 파일 이름(`templates/interview-*-template.md`) · agent 이름 · `reviewing-brief`, 스크립트의 변수 · 함수 · 인자 이름(`--interview` · `interview_dir()` 같은 함수 이름 포함 — 단, 아래 「하위 명령」), `seed` · `brief` 낱말, 「옛 인터뷰 기록」 · 「옛 인터뷰 폴더」, 옛 설정 키를 알리는 안내 속 `interview_dir`, 변경 기록과 기록 폴더(`docs/superpowers/` 아래), 쉬운 말 규칙 블록, `CLAUDE.md`, 기존 테스트 픽스처 파일(`tests/fixtures/` — 옛 꼴 그대로 두어 옛 읽기의 증인으로 쓴다).
- **하위 명령 이름.** `state_path.py interview-state` 하위 명령은 `context-state` 로 바꾼다 — 하위 명령 글자가 옛 종류 글자와 같아 AC23 의 예외(템플릿 · 스크립트 파일 이름)에 들지 않는다. 부르는 skill 글과 테스트를 같은 커밋에서 바꾸고 옛 이름은 받지 않는다.
- **낱말(AC40 의 계획 2 몫).** 계획 1 의 「낱말 대응」 그대로 — 단계를 가리키는 「인터뷰」 는 그 단계 이름(조사 · 결과물 쪽 「컨텍스트 쌓기」, 분해 · 로드맵 쪽 「로드맵 잡기」), 「인터뷰 폴더」 는 「의도 폴더」, 홀로 쓰인 영어 `interview` 가 단계를 가리키면 `context-build` · `roadmap-draft`. 범위는 spec-distill 의 `scripts/`(문자열 · 주석 — 식별자 제외)와 quality-gates 의 추적 파일(`tests/` · `CHANGELOG.md` 제외)이다. 테스트와 픽스처는 락의 범위 밖이다 — 바뀐 출력 글자를 무는 테스트만 그 글자를 따라 고친다.
- **보안 리뷰 묶음.** 리뷰어 프로필(`references/docreview-profiles/*.md`)과 agent 정의(`plugins/*/agents/*.md` · `shared/docreview/agents/*.md`)의 편집은 이 계획 안에서 한 커밋(과제 7)에만 있다 — 두 플러그인의 것을 함께 묶는다. 규칙을 지우거나 느슨하게 하지 않는다. PR 본문이 보안 리뷰 대상임을 밝힌다(AC36).
- **경로 게이트.** 경로 검사(`repo_defaults.py check-path` · 커밋 펜스 · PR 파일 세기 · 상태 자리 계산)는 설계 3 이 정한 하나만 넓힌다 — 옛 폴더 바로 아래의 옛 꼴 이름(대응표의 옛 파일 이름 끝). 사용자 결정 2026-11-22(설계문서 결정 기록 끝 줄 — 「이름 꼴로 가른다」, 설계 3 「경로 검사」 의 ① 과 AC25 끝 문장을 다시 정했다): 진행 중인지는 가리지 않는다 — 끝난 옛 기록의 옛 꼴 파일도 통과한다. 링크 · 작업 트리 밖 거절은 두 폴더에 같다. PR 본문에 「경로 게이트를 넓히는 편집」 으로 밝힌다. 그 밖에는 넓히지 않는다.
- **편집 자리 찾기.** 기본 브랜치와 에픽 브랜치는 이 계획을 쓴 뒤에도 움직인다(계획 1 의 통합 리뷰 · 옆 로드맵 E1 의 머지). 과제의 편집 자리는 줄 번호가 아니라 그때 grep 해서 찾는 글자로 적었다. 과제마다 고치기 직전에 대상 목록을 다시 낸다.
- **셸.** 새 셸 테스트와 펜스는 macOS `/bin/bash` 3.2 에서 돈다 — `$var` 바로 뒤에 한글이 오면 `${var}` 로 쓴다. heredoc 을 `$( )` 안에 두지 않는다. 새 셸 테스트는 `chmod +x` 하고 `git ls-files -s` 로 100755 를 본다. Python 은 `encoding="utf-8"` 를 명시하고 `python3` 리터럴로 부른다. 변이 시험 전에는 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 빈지 본다. Python 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. Bash 도구의 셸은 zsh 다 — 파이프의 rc 가 필요하면 `bash -c` 안에서 잡는다.
- **전체 스위트**는 이 줄로만 돌린다(공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다):
  `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <실행자 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`
  SDD 구현자에게는 전체 스위트를 맡기지 않는다 — 과제마다 그 과제의 테스트만 돌리고, 전체 스위트는 과제 12 에서 한 번 돈다.
- **무시되는 자리.** 과제가 남기는 메모 · 대조 출력은 작업 트리 안에서 `git check-ignore -q <경로>` 가 0 인 자리(예: `.claude/tmp/f5-plan2/`)에 둔다.

## 옆 로드맵이 예약한 파일 — 이 계획이 고치는 것

옆 로드맵(`docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`)의 남은 에픽(2026-11-22 기본 브랜치 df016db6 기준 — R1 · R2 · R3 은 머지됐고 E1 은 구현이 끝나 PR 을 기다린다)의 경로 예약과 겹친다. 과제 1 이 그때의 예약을 다시 읽어 이 표를 고친다. 고치는 과제가 시작하기 전에 지휘자에게 파일과 고칠 줄(grep 글자)을 보고하고, 먼저 머지된 쪽 위에서 쓴다.

| 파일 | 예약한 에픽 | 이 계획이 고치는 것(grep 글자) | 과제 |
|---|---|---|---|
| `plugins/spec-distill/scripts/team_write.py` | E1 | `FRAMING_TYPE = "interview-seed-audit"` 와 그것을 견주는 줄 · `import legacy_names` 한 줄 · 안내 글 「framing 을 거친 인터뷰라면」 · 「인터뷰 상태 파일이 가리키는」 | 5 · 10 |
| `plugins/spec-distill/scripts/control_plane.py` | E2 | `STATE_SUFFIX = "-interview.state.md"` · `type: interview-state` · `def interview_dir(repo)` 의 본문 · `def interview_files(` · `"interview-state" in (SCRIPTS / "state_path.py")` · 칸 이름 「인터뷰 조사」 · 「인터뷰: 」 · 「인터뷰 폴더」 | 4 |
| `plugins/spec-distill/references/conducting.md` | E1 · E2 | `source_interview` 한 곳 | 6 |
| `plugins/spec-distill/references/epic-handoff.md` | E4 | `source_interview:` | 6 |
| `plugins/spec-distill/skills/roadmap-draft/SKILL.md` · `references/pr-merge.md` | E4 | `get interview_dir` · `BRIEF_REL="${IDIR}<file>"` · `check-path interview_dir` · 「끝의 `-int」 로 시작하는 로드맵 폴더 이름 규칙 | 6 |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | E4 | frontmatter `description` 의 `source_interview` · 게이트 ③ 갈래 문단의 「컨텍스트 쌓기 다시 열기」 | 6 · 9 |
| `plugins/spec-distill/CHANGELOG.md` | R5 | 새 판 절 | 11 |

`references/team-files.md`(E1 · E4) · `dependencies.md`(E3 · R5) 는 2026-11-22 에 이 계획의 옛 글자가 없다 — 과제 1 이 다시 보고, 생기면 이 표에 더한다.

## Review Focus

1. **설정에 옛 키만 있는 레포(새 폴더 = 옛 폴더)** — 새로 시작한 컨텍스트 쌓기는 그 폴더에 새 꼴 이름으로 쓰고, 경로 검사가 그 폴더의 두 꼴을 다 받고, 「값을 그대로 읽는다」 알림 한 줄이 한 번 나온다. 시험: 과제 3 `test_old_key_only_same_folder_accepts_both`.
2. **업그레이드 전에 시작한 컨텍스트 쌓기를 새 판으로 이어 감(옛 폴더 · 옛 꼴 상태 파일, 두 폴더가 다르다)** — 이어 갈 후보가 옛 폴더에서 나오고, 결과물 경로가 그 상태 파일 줄기(`…-interview.md`)로 지어지며 새로 쓰는 `type:` 은 `context-brief` 이고, 커밋 펜스가 받는다. 시험: 과제 4 `test_resume_candidate_in_old_folder` · 과제 6 `old_stem_payload_and_commit`.
3. **옛 폴더의 옛 seed 로 새로 시작** — 상태 파일은 새 폴더 · 새 꼴이고 `seed:` 는 옛 폴더의 seed 를 가리키며, 원자료 찾기가 seed 옆 framing 기록을 찾고, 커밋 펜스와 PR 파일 세기가 옛 폴더의 그 둘을 함께 받는다. 시험: 과제 6 `old_seed_new_interview_commit` · `old_seed_pr_files_only`.
4. **두 폴더가 다를 때 옛 폴더에 새 꼴 파일이나 상관없는 파일** — 경로 검사가 지금처럼 거절하고 사유가 두 폴더를 함께 댄다. 시험: 과제 3 `test_old_folder_rejects_new_form_and_other`.
5. **상태줄 · 지도에서 두 폴더** — 새 폴더와 옛 폴더에 진행 중 상태 파일이 하나씩이면 둘 다 세고, 두 키가 같은 폴더를 가리키면 한 번만 센다. 시험: 과제 4 `test_statusline_counts_both_folders_once`.

## 과제 지도

| # | 과제 | 커밋 성격 | AC | 메모 |
|---|---|---|---|---|
| 1 | 다시 확인 — 합치기 · 근거 대조 · 전수 목록 · 예약 · AC22 기준점 | 합치기 커밋만 | 선행 | — |
| 2 | 대응표 모듈 `legacy_names.py` | 새 모듈 | AC23 기반 | 대응표 모듈 |
| 3 | 설정 키 · 두 폴더 · 경로 검사 | 동작 | AC24 · AC25(경로) | 설정 키 수 글자 |
| 4 | 상태 자리 · 진입 · 이어 가기 · 상태줄 | 동작 + 판결 글자 | AC20 · AC21(상태) · AC25 | — |
| 5 | 종류 글자 · 머리 키를 읽는 스크립트와 옛 꼴 · 새 꼴 짝 시험 | 동작 | AC21 · AC23 | 진입 경로 도출 · 원자료 사슬 |
| 6 | 새로 쓰는 글자 — 템플릿 · 넘김 글 · skill 펜스 | 글 + 펜스 동작 | AC20 · AC25(펜스) | 기준 해시 · 이른 진입 확인 |
| 7 | agent 정의와 리뷰 기준(보안 리뷰 묶음) | 글 | AC20 · AC36 · AC40 | 문법 실수 미룸 행 |
| 8 | quality-gates 가 두 머리 키를 읽는다 | 동작 + 글 | AC26 · AC40(qg) | — |
| 9 | 로드맵 에픽의 「로드맵 다시 잡기」 라벨 | 글 | (사용자 결정) | 라벨 |
| 10 | 스크립트 안내 낱말과 락 둘(옛 글자 리터럴 · 낱말) | 글 + 락 | AC23 · AC40 | 낱말 락 줄이기 · 면제 한 줄 |
| 11 | 판 · 변경 기록 · README | 판 | AC26(판) | — |
| 12 | 마무리 — AC22 대조 · AC27 · validate · 전체 스위트 · AC 보고 | 확인 | AC22 · AC27 · 전부 | — |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 계획 1 뒤의 코드에서도 그런지 보고, 다르면 멈춰 지휘자에게 보고한다. 산출물은 무시되는 자리의 메모 파일 하나(`.claude/tmp/f5-plan2/recheck.md`)다.

**Files:**
- Create(추적 안 함): `.claude/tmp/f5-plan2/recheck.md`
- Modify: (합치기 커밋 · 예약 표가 달라졌을 때의 이 계획 표만)

**Interfaces:**
- Produces: `recheck.md` 의 절 — `## 근거 대조` · `## 옛 글자를 쥔 스크립트` · `## 옛 글자를 쥔 글` · `## 옛 폴더를 읽는 자리` · `## 결과물 경로를 짓는 펜스` · `## 판결 글자를 읽는 곳` · `## 옛 글자를 무는 테스트` · `## 옆 로드맵 예약` · `## AC22 기준점` · `## 닿는 선택 지적`. 과제 2–12 가 읽는다.

- [ ] **Step 1: 기본 브랜치를 합친다** — `git fetch origin` 뒤 `git merge --no-ff origin/<기본 브랜치>`(이름은 `python3 plugins/spec-distill/scripts/repo_defaults.py default-branch --root .`). 이 계획을 에픽 브랜치(`feature/front-stage-restructure`)가 아닌 브랜치에서 시작했으면 `origin/feature/front-stage-restructure` 도 합친다(계획 1 의 통합 리뷰 고침이 거기 있다). 충돌이 나면 `git merge --abort` 하고 멈춰 보고한다. 합친 뒤 계획 1 의 산출물이 있는지 본다 — `plugins/spec-distill/skills/context-build/SKILL.md` · `skills/roadmap-draft/SKILL.md` · `scripts/roadmap_draft_entry.py` · `tests/test_stage_words.sh` 가 없으면 멈춘다. 커밋 메시지: `chore(merge): 기본 브랜치를 F5 브랜치에 합친다` + 끝 줄들.

- [ ] **Step 2: 설계문서의 근거를 다시 연다** — 아래를 지금 글에서 확인하고 「같다 / 다르다 — 무엇이」 를 `## 근거 대조` 에 한 줄씩 적는다. 하나라도 과제를 바꿀 만큼 다르면 멈춘다.
  - 옛 글자 리터럴을 쥔 spec-distill 스크립트(2026-11-22: `interview_state.py` · `state_path.py` · `check_brief.py` · `control_plane.py` · `spec_review_bundle.py` · `repo_defaults.py` · `raw_source.py` · `check_bundle_coverage.py` · `seed_review_log.py` · `roadmap_status.py` · `build_seed_inline_blob.py` · `team_write.py` · `seed_body.py` · `roadmap_render.py` · `check_verbatim_coverage.py` · `check_seed.py` · `build_brief_inline_blob.py`). 명령: `git grep -c -E 'interview-(seed|state|brief|audit)|-interview\.(md|state\.md|audit\.md)|source_interview|interview_dir|docs/superpowers/interview' -- plugins/spec-distill/scripts`. 이 계획에 없는 스크립트가 나오면 과제 5 의 Files 에 더한다(멈추지 않는다).
  - `state_path.py` 의 `_SLOTS` 가 세 자리(`.state.md` · `.md` · `.audit.md`)와 종류 글자를 잇는다.
  - 옛 폴더(설정 `interview_dir`)를 읽는 자리: `state_path.interview_dir` · `control_plane.interview_dir` · `interview_state.cmd_seed_audit` · `repo_defaults.py` 의 `check-path` 선택지 · skill 펜스의 `get interview_dir`(intent-sync · context-build finishing · roadmap-draft) · `check-path interview_dir`(intent-sync · context-build finishing 커밋 펜스 · roadmap-draft 커밋 펜스 · pr-merge.md).
  - quality-gates `scripts/intent_origin.py` 의 `DEFAULT_MARKERS` 가 `source_interview` 를 갖고, `_follow_changed` 와 `build_origin` 이 `source_interview` 를 읽는다. `other_teams.py` 의 `LINE_INTERVIEW` 가 「인터뷰 단계의 팀」 이다.
  - 레포 설정(`.devbrew.md`, 기본 브랜치 판)에 `interview_dir` 가 없다 — 있으면 이 레포의 새 기록 자리가 옛 폴더가 되니 보고한다.
  - 설정 키 수: `repo_defaults.KEYS` 의 길이(2026-11-22: 열다섯 — `intent_dir` 가 `interview_dir` 자리를 이으므로 수는 그대로다)와 키 수 · 키 목록을 세는 글자(`plugins/spec-distill/README.md` · `references/roadmap-ontology.md` · `tests/test_parallel_recommend_docs.sh` · `tests/test_repo_defaults.py` · `tests/test_workspace_invariance.sh`).
  - 로드맵 폴더의 로드맵 수(2026-11-22: 다섯 — 설계는 「넷」 이라 적었다. AC22 는 「전부」 로 읽는다).

- [ ] **Step 3: 전수 목록을 낸다**
  - `## 옛 글자를 쥔 스크립트`: Step 2 첫 명령의 줄 단위 출력(`git grep -n`).
  - `## 옛 글자를 쥔 글`: 같은 정규식으로 `plugins/spec-distill/{skills,references,templates,agents}` · `plugins/spec-distill/README.md` · `plugins/quality-gates` 의 `tests/` · `CHANGELOG.md` 밖.
  - `## 결과물 경로를 짓는 펜스`: `git grep -n -E '\$\{?IDIR\}?<file>' -- plugins/spec-distill/skills`(2026-11-22: finishing.md 의 `PAYLOAD="$(pwd)/${IDIR}<file>"` · roadmap-draft 의 `BRIEF_REL="${IDIR}<file>"`)와 `git grep -n -e '%-interview' -e '-interview.state.md' -- plugins/spec-distill/skills`(reviewing-brief 의 `STATE=` 줄 일곱).
  - `## 판결 글자를 읽는 곳`: `git grep -n -e 'interview-state:' -e 'interview-state-entry' -e 'state_path.py" interview-state' -- plugins shared tools`.
  - `## 옛 글자를 무는 테스트`: `git grep -l -E 'interview-(seed|state|brief|audit)|-interview\.(md|state\.md|audit\.md)|source_interview|interview_dir|docs/superpowers/interview|interview-state:' -- plugins/*/tests shared/tests tools ':!*/fixtures/*'`(2026-11-22: 100개 안팎). 테스트마다 「쓴 결과를 무는가(새 글자로 바꿈) · 손으로 만든 옛 기록을 먹이는가(그대로 — 옛 읽기의 증인)」 를 가른다.

- [ ] **Step 4: 옆 로드맵 예약을 다시 읽는다** — 그때의 기본 브랜치의 옆 로드맵을 읽어 남은 에픽의 `경로 예약:` 과 이 계획이 고치는 파일의 교집합을 낸다(`python3 plugins/spec-distill/scripts/roadmap_status.py docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` 로 머지된 에픽을 가른다). 위 「옆 로드맵이 예약한 파일」 표와 다르면 표를 고치는 커밋(`docs(plan): …`)을 하고 지휘자에게 보고한다. E1 이 그 사이 머지됐으면 `team_write.py` · `control_plane.py` 의 grep 글자가 그대로인지 본다.

- [ ] **Step 5: AC22 기준점을 적는다** — `git rev-parse HEAD`(합친 뒤, 과제 2 전)를 `## AC22 기준점` 에 적는다. 과제 12 가 이 커밋의 스크립트와 그때의 스크립트로 같은 입력을 돌려 견준다.

- [ ] **Step 6: 닿는 선택 지적을 뽑는다** — 지휘 세션의 대조표 `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/tmp/qg-fix-triage/triage.md`(품질 리뷰가 낸 선택 지적을 기준 나무에 대조한 표)에서, 이 계획이 고치는 파일(과제 2–11 의 Files)에 걸리고 판정이 `남아 있음` 인 **선택 지적** 행을 `## 닿는 선택 지적` 에 번호 · 파일 · 자리 · 한 줄 요지로 옮긴다. 막는 지적 · 낮춘 지적 행은 옮기지 않는다 — 따로 도는 브랜치 `fix/qg-review-findings` 가 고친다. 파일이 없으면 이 걸음을 건너뛰고 그 사실을 그 절에 적는다. 뒤 과제는 이 절에서 **자기가 고치는 줄이나 바로 그 함수 · 문단에 걸린 것만** 함께 고친다 — 일부러 찾아가 고치지 않는다(사용자 결정 「막는 지적 · 낮춘 지적만 고치고 선택 지적은 닿는 것만」). 고친 번호는 그 과제의 커밋 본문에 적는다.

---

### Task 2: 대응표 모듈 `legacy_names.py` (AC23 기반)

옛 글자 리터럴이 사는 유일한 자리다. 다른 스크립트는 이 모듈의 상수와 함수만 쓴다.

**Files:**
- Create: `plugins/spec-distill/scripts/legacy_names.py` · `plugins/spec-distill/tests/test_legacy_names.py`

**Interfaces:**
- Produces(모두 모듈 최상위 — 과제 3–6 · 8 · 10 이 쓴다):
  - 새 글자: `INTENT_SEED = "intent-seed"` · `INTENT_SEED_AUDIT = "intent-seed-audit"` · `CONTEXT_STATE = "context-state"` · `CONTEXT_BRIEF = "context-brief"` · `CONTEXT_AUDIT = "context-audit"` · `HEAD_KEY = "source_intent"` · `SETTING_KEY = "intent_dir"` · `DEFAULT_DIR = "docs/superpowers/intent/"` · `SEED_TAIL = "-intent"` · `CONTEXT_TAIL = "-context"`(파일 이름 줄기 끝 — `.md` · `.audit.md` · `.state.md` 를 붙인다).
  - 옛 글자: `OLD_KIND: dict[str, str]`(새 종류 글자 → 옛 글자, 다섯) · `OLD_HEAD_KEY = "source_interview"` · `OLD_SETTING_KEY = "interview_dir"` · `OLD_DEFAULT_DIR = "docs/superpowers/interview/"` · `OLD_TAIL = "-interview"`.
  - `kind_matches(have: str | None, new_kind: str) -> bool` — `have` 가 `new_kind` 이거나 그 옛 글자면 True.
  - `kinds(new_kind: str) -> tuple[str, str]` — (새, 옛). 오류 글자에 둘 다 보일 때 쓴다.
  - `source_of(fm: dict) -> str` — `fm` 의 `source_intent` 값, 없거나 비면 `source_interview` 값, 둘 다 없으면 `""`. 둘 다 있으면 새 키가 이긴다.
  - `head_keys() -> tuple[str, str]` — (`HEAD_KEY`, `OLD_HEAD_KEY`).
  - `state_suffixes() -> tuple[str, str]` — (`"-context.state.md"`, `"-interview.state.md"`).
  - `is_old_name(name: str) -> bool` — 파일 이름(basename)이 `-interview.md` · `-interview.state.md` · `-interview.audit.md` 로 끝나는가.
  - `seed_topic(name: str) -> str | None` — `YYYY-MM-DD-<kebab>-intent.md` 또는 옛 `…-interview.md` 의 `<kebab>`, 아니면 None.
  - `seed_audit_topic(name: str) -> str | None` — `YYYY-MM-DD-<주제>-intent.audit.md` 또는 옛 `…-interview.audit.md` 의 `<주제>`(`.+` — 지금 `_AUDIT_TOPIC` 과 같은 너그러움).
  - `roadmap_folder_name(brief_name: str) -> str | None` — 결과물 파일 이름에서 `-context.md` 또는 옛 `-interview.md` 를 뗀 이름(로드맵 폴더 이름 규칙), 둘 다 아니면 None.
  - `siblings(brief: str) -> tuple[str, str]` — (audit, 상태 파일) 경로 — `brief[:-3] + ".audit.md"`, `brief[:-3] + ".state.md"`. `.md` 로 끝나지 않으면 ValueError.
  - `setting_notice(old_value: str, new_value: str | None) -> str` — 설정에 옛 키가 있을 때의 한 줄. `new_value` 가 None 이면 `레포 설정의 interview_dir 는 이름이 intent_dir 로 바뀌었다 — 값(<old_value>)을 그대로 읽는다. 키 이름을 intent_dir 로 바꾼다`, 아니면 `레포 설정에 intent_dir 와 옛 키 interview_dir 가 함께 있다 — intent_dir(<new_value>)에 새 기록을 쓰고 interview_dir(<old_value>)는 옛 기록을 읽는 폴더로만 쓴다`.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — 기대 글자는 모듈이 아니라 시험에 박는다)**

```python
class LegacyNames(unittest.TestCase):
    def test_kind_pairs(self):
        pairs = {"intent-seed": "interview-seed", "intent-seed-audit": "interview-seed-audit",
                 "context-state": "interview-state", "context-brief": "interview-brief",
                 "context-audit": "interview-audit"}
        self.assertEqual(L.OLD_KIND, pairs)
        for new, old in pairs.items():
            self.assertTrue(L.kind_matches(new, new))
            self.assertTrue(L.kind_matches(old, new))
            self.assertEqual(L.kinds(new), (new, old))
    def test_kind_does_not_cross(self):          # 옛 seed 글자가 결과물 종류로 통하지 않는다
        self.assertFalse(L.kind_matches("interview-seed", "context-brief"))
        self.assertFalse(L.kind_matches("interview-seed", "intent-seed-audit"))
        self.assertFalse(L.kind_matches(None, "context-brief"))
        self.assertFalse(L.kind_matches("", "context-brief"))
    def test_source_of(self):
        self.assertEqual(L.source_of({"source_intent": "a.md"}), "a.md")
        self.assertEqual(L.source_of({"source_interview": "b.md"}), "b.md")
        self.assertEqual(L.source_of({"source_intent": "a.md", "source_interview": "b.md"}), "a.md")
        self.assertEqual(L.source_of({"source_intent": "", "source_interview": "b.md"}), "b.md")
        self.assertEqual(L.source_of({}), "")
    def test_names(self):
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.md"))
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.state.md"))
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.audit.md"))
        self.assertFalse(L.is_old_name("2026-01-01-x-context.md"))
        self.assertFalse(L.is_old_name("notes.md"))
        self.assertEqual(L.seed_topic("2026-01-01-ab-cd-intent.md"), "ab-cd")
        self.assertEqual(L.seed_topic("2026-01-01-ab-cd-interview.md"), "ab-cd")
        self.assertIsNone(L.seed_topic("2026-01-01-ab-cd-context.md"))
        self.assertEqual(L.seed_audit_topic("2026-01-01-ab-intent.audit.md"), "ab")
        self.assertEqual(L.seed_audit_topic("2026-01-01-ab-interview.audit.md"), "ab")
        self.assertEqual(L.roadmap_folder_name("2026-01-01-ab-brief-context.md"), "2026-01-01-ab-brief")
        self.assertEqual(L.roadmap_folder_name("2026-01-01-ab-interview.md"), "2026-01-01-ab")
        self.assertIsNone(L.roadmap_folder_name("2026-01-01-ab.md"))
        self.assertEqual(L.state_suffixes(), ("-context.state.md", "-interview.state.md"))
    def test_siblings(self):
        self.assertEqual(L.siblings("/r/d/x-context.md"), ("/r/d/x-context.audit.md", "/r/d/x-context.state.md"))
        self.assertEqual(L.siblings("/r/d/x-interview.md"), ("/r/d/x-interview.audit.md", "/r/d/x-interview.state.md"))
        with self.assertRaises(ValueError):
            L.siblings("/r/d/x.txt")
    def test_constants(self):
        self.assertEqual((L.SETTING_KEY, L.OLD_SETTING_KEY), ("intent_dir", "interview_dir"))
        self.assertEqual((L.DEFAULT_DIR, L.OLD_DEFAULT_DIR), ("docs/superpowers/intent/", "docs/superpowers/interview/"))
        self.assertEqual(L.head_keys(), ("source_intent", "source_interview"))
    def test_setting_notice(self):
        self.assertIn("값(docs/x/)을 그대로 읽는다", L.setting_notice("docs/x/", None))
        both = L.setting_notice("docs/x/", "docs/y/")
        self.assertIn("intent_dir(docs/y/)에 새 기록을 쓰고", both)
        self.assertIn("interview_dir(docs/x/)는 옛 기록을 읽는 폴더로만", both)
```

Run: `python3 plugins/spec-distill/tests/test_legacy_names.py` → Expected: FAIL(모듈 없음).

- [ ] **Step 2: 모듈을 쓴다** — 표준 라이브러리만. 다른 spec-distill 모듈을 import 하지 않는다(누구나 import 할 수 있게). 이름 정규식은 `re.fullmatch` 로 쓴다.

- [ ] **Step 3: 통과를 본다** — 같은 명령 → PASS.

- [ ] **Step 4: 변이로 이빨을 본다** — 커밋 뒤: (지우기) `OLD_KIND` 에서 한 쌍 · (뒤집기) `source_of` 가 옛 키를 먼저 본다 · (꼴 바꾸기) `is_old_name` 이 `-interview` 로 시작만 보면 True · (더하기) `kind_matches` 가 옛 글자끼리도 통하게(`interview-seed` ↔ `context-brief`). 각각 시험 실패.

- [ ] **Step 5: 커밋** — `git commit -m "feat(spec-distill): 옛 글자와 새 글자의 대응표 모듈을 더한다"`.

---

### Task 3: 설정 키 · 두 폴더 · 경로 검사 (AC24 · AC25 의 경로 몫)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py` · `plugins/spec-distill/tests/test_repo_defaults.py` · `tests/test_repo_defaults_git.sh`(옛 키를 무는 자리) · 설정 키 목록을 세는 글자(Task 1 Step 2 의 다섯 파일)
- Modify(글): `plugins/spec-distill/README.md` 의 설정 예시(`interview_dir: docs/superpowers/interview/`)와 설정 표 행(`| \`interview_dir\` | 의도 폴더 |`) · `references/roadmap-ontology.md` 의 설정 키 칸

**Interfaces:**
- Consumes: 과제 2 의 `SETTING_KEY` · `OLD_SETTING_KEY` · `DEFAULT_DIR` · `OLD_DEFAULT_DIR` · `is_old_name` · `setting_notice`.
- Produces:
  - `KEYS` 에서 `"interview_dir"` 자리를 `"intent_dir"` 가 잇는다(수는 그대로). `_FOLDER_KEYS` · `_DEFAULTS` 도 같다(`_DEFAULTS["intent_dir"] = legacy_names.DEFAULT_DIR`). `INTERVIEW_DIR` 상수는 지운다 — 쓰던 곳(`state_path.py` · `control_plane.py`)은 과제 4 가 바꾼다.
  - 옛 키는 레포 층에서만 받는다: `check_layer("repo")` 가 `OLD_SETTING_KEY` 를 모르는 키로 막지 않는다. 로드맵 층에서는 지금처럼 `layer_key` 오류다.
  - `merge_layers` 결과에 `values["intent_dir"]`(레포 층의 `intent_dir`, 없으면 레포 층의 `interview_dir`, 없으면 `DEFAULT_DIR`) · 새 최상위 키 `"old_intent_dir"`(레포 층의 `interview_dir`, 없으면 `OLD_DEFAULT_DIR` — 폴더 규칙 `_folder` 로 검사, 깨지면 None 과 `errors` 한 줄) · 옛 키가 있으면 `notices` 에 `setting_notice(...)` 한 줄. `sources["intent_dir"]` 은 옛 키에서 읽었으면 「레포 설정(옛 키 interview_dir)」.
  - 함수 `intent_dirs(result: dict) -> tuple[str | None, str | None]` — (새 폴더, 옛 폴더). 두 값이 같을 수 있다.
  - `check-path` 의 키 선택지는 `("roadmaps_dir", "intent_dir")` — `interview_dir` 인자는 받지 않는다(argparse 오류 rc 2). `intent_dir` 판정: 부모 폴더가 새 폴더면 지금처럼 받는다. 아니고 부모 폴더가 옛 폴더이고 `is_old_name(basename)` 이면 알림 없이 받는다(본 사람이 할 일이 없는 줄이라 내지 않는다 — 이 넓힘은 PR 본문에 밝힌다). 그 밖에는 지금의 거절 사유 줄에 ` — 옛 의도 폴더(<옛 폴더>)는 옛 꼴 이름(…-interview.md · .state.md · .audit.md)만 받는다` 를 붙여 rc 3. 대소문자 · 레포 밖 · 링크 규칙은 두 폴더에 같다(`judge_path` 를 두 번 부른다).
  - `get intent_dir` 은 새 폴더를 낸다. `get` 선택지에 `interview_dir` 는 없다.
  - 사용자 결정 2026-11-22(설계문서 결정 기록 끝 줄): 진행 중인지는 가리지 않는다 — 끝난 옛 기록의 옛 꼴 파일도 통과한다(설계 3 「경로 검사」 의 ① 과 AC25 끝 문장을 다시 정한 결정 — 판정은 위의 「옛 폴더 바로 아래 + 옛 꼴 이름」 그대로).

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_repo_defaults.py` 의 임시 레포 도우미를 쓴다)**

```python
def test_no_setting_new_and_old_defaults(self): ...          # (docs/superpowers/intent/, docs/superpowers/interview/) · 알림 없음
def test_old_key_only(self): ...                             # interview_dir: docs/a/ → 새 = 옛 = docs/a/ · notices 에 "값(docs/a/)을 그대로 읽는다" 한 줄
def test_both_keys(self): ...                                # intent_dir: docs/b/ · interview_dir: docs/a/ → (docs/b/, docs/a/) · "함께 있다" 한 줄
def test_new_key_only(self): ...                             # intent_dir: docs/b/ → (docs/b/, docs/superpowers/interview/) · 알림 없음
def test_old_key_in_roadmap_layer_is_layer_key(self): ...    # 로드맵 머리에 interview_dir → errors 에 layer_key 사유(지금과 같다)
def test_broken_old_key_is_error(self): ...                  # interview_dir: /abs → errors 한 줄 · old_intent_dir None
def test_keys_count_unchanged(self): ...                     # len(KEYS) == 15 · "intent_dir" in KEYS · "interview_dir" not in KEYS
def test_check_path_new_folder_any_name(self): ...           # docs/superpowers/intent/notes.md → rc 0
def test_check_path_old_folder_old_name(self): ...           # docs/superpowers/interview/2026-01-01-x-interview.state.md → rc 0 · stderr 에 받았다는 알림 줄이 없다("값의 출처" 줄 밖은 빔)
def test_old_folder_rejects_new_form_and_other(self): ...    # 두 폴더가 다를 때 옛 폴더의 x-context.md · notes.md → rc 3 · 사유에 두 폴더 이름
def test_old_key_only_same_folder_accepts_both(self): ...    # interview_dir: docs/a/ → docs/a/x-context.md · docs/a/x-interview.md 둘 다 rc 0
def test_check_path_rejects_old_key_argument(self): ...      # check-path interview_dir … → rc 2
def test_old_folder_link_rejected(self): ...                 # 옛 폴더가 링크를 거치면 지금처럼 거절(rc 3)
```

Run: `python3 plugins/spec-distill/tests/test_repo_defaults.py` → Expected: 새 시험 FAIL.

- [ ] **Step 2: 고친다** — 위 Interfaces 대로. 옛 키 글자와 옛 기본 폴더 글자는 `legacy_names` 의 상수로만 쓴다(과제 10 의 락은 옛 기본 폴더 글자를 문다 — 옛 키 글자 `interview_dir` 는 그대로 두는 함수 이름과 글자가 같아 락이 물지 않으니 리뷰가 본다).

- [ ] **Step 3: 글을 맞춘다** — README 설정 예시와 표 행을 `intent_dir` · `docs/superpowers/intent/` 로, 표 아래에 한 줄 「옛 키 `interview_dir` 가 있으면 그 값을 읽고 한 줄로 알린다 — 그 폴더는 옛 기록을 읽는 옛 의도 폴더로도 쓴다」. `roadmap-ontology.md` 의 키 칸과 Task 1 Step 2 의 키 목록 글자들(테스트 셋 포함)을 새 키 이름으로. 키 수 글자(「열다섯」 등)는 수가 같으니 그대로 둔다 — 다르면 멈춰 보고한다.

- [ ] **Step 4: 통과를 본다** — `python3 plugins/spec-distill/tests/test_repo_defaults.py` · `bash plugins/spec-distill/tests/test_repo_defaults_git.sh` · `bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh` · `bash plugins/spec-distill/tests/test_workspace_invariance.sh`. Expected: 통과(이 과제 뒤 `get interview_dir` 를 부르는 skill 펜스는 과제 6 까지 깨진 채다 — 펜스를 뽑아 돌리는 테스트 가운데 그 줄을 지나는 것이 과제 6 전에 실패하면 「과제 6 이 뒤집는다」 고 기록하고 넘어간다).

- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤: (뒤집기) 둘 다 있을 때 옛 키가 이기게 · (지우기) 옛 폴더 받기 갈래 · (더하기) 옛 폴더에서 `is_old_name` 없이 모두 받기 · (꼴 바꾸기) 설정 키 알림(`setting_notice`)을 `warnings` 로 옮기기 · (더하기) 옛 폴더의 옛 꼴 파일을 받을 때 stderr 에 한 줄을 내기. 각각 시험 실패.

- [ ] **Step 6: 커밋** — `git commit -m "feat(spec-distill): 설정 키를 intent_dir 로 바꾸고 옛 키를 읽으며 경로 검사가 옛 폴더의 옛 꼴 파일을 받는다"`. 커밋 본문에 「경로 게이트를 넓히는 편집 — 옛 의도 폴더의 옛 꼴 이름만」 을 적는다.

---

### Task 4: 상태 자리 · 진입 · 이어 가기 · 상태줄 (AC20 · AC21 의 상태 몫 · AC25)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` · `scripts/interview_state.py` · `scripts/control_plane.py`(E2 예약 — 시작 전에 알린다) · `skills/context-build/SKILL.md`(펜스 표지 · 판결 글자 · `type:` 안내) · `skills/context-build/references/state-file.md`(판결 표 · 하위 명령 · 상태 파일 자리 글) · 그 글자를 무는 테스트(`tests/test_state_path.sh` · `test_interview_state.py` · `test_interview_state_flow.sh` · `test_control_plane.py` · `test_control_plane.sh` 와 Task 1 `## 판결 글자를 읽는 곳` 의 테스트)

**Interfaces:**
- Consumes: 과제 2 모듈 · 과제 3 `repo_defaults.intent_dirs(result)`.
- Produces:
  - `state_path.intent_dirs(root: Path, is_git: bool) -> tuple[Path | None, Path | None, str | None]` — (새 폴더, 옛 폴더, 사유). git 밖이면 두 기본값. 지금의 `state_path.interview_dir(root, is_git)` 는 이름 그대로 두고 새 폴더만 내는 얇은 함수로 남긴다(부르는 쪽이 둘이라 바꾸지 않는다).
  - `_SLOTS` 의 종류 칸은 새 종류 글자(`CONTEXT_STATE` · `CONTEXT_BRIEF` · `CONTEXT_AUDIT`), `_slot_problem` 은 `kind_matches` 로 견준다.
  - `interview_state_path(...)` 는 새 폴더에 `"{date}-{topic}" + CONTEXT_TAIL` 줄기(시각을 붙인 갈래도 같다)로 `….state.md` 를 낸다. 이름 · 인자는 그대로.
  - 하위 명령 `state_path.py context-state --topic …`(옛 `interview-state` 는 없다 — usage 줄도).
  - `interview_state.py` 의 판결 줄 접두는 `context-state: `(REJECT · RESUME · LEGACY · ASK · NEW-SEED · NEW). `migrate-legacy` 가 쓰는 머리는 `type: context-state`. `entry` 의 `type` 검사는 `kind_matches(have, CONTEXT_STATE)` · seed 판독은 `kind_matches(..., INTENT_SEED)` · 주제 떼기는 `legacy_names.seed_topic`.
  - `resume_candidates(seed, want)` 는 seed 의 폴더 · 새 폴더 · 옛 폴더(실제 경로로 겹침을 뺀 합집합)에서 `state_suffixes()` 두 꼴을 찾는다. 나머지 거름(링크 · 이름 글자 · 짝 · 종류 · `seed:` · 끝난 일)은 그대로.
  - `seed-audit-for-session` 은 새 폴더에서 두 꼴(`-intent.audit.md` · 옛 `-interview.audit.md`)을 찾는다 — 옛 폴더는 찾지 않는다(의도 싱크는 새 폴더에만 쓴다). 종류 검사는 `kind_matches(..., INTENT_SEED_AUDIT)`, 주제는 `seed_audit_topic`.
  - `control_plane.py`: `parse_interview_state` 가 첫 키 `type:` 을 `kind_matches(…, CONTEXT_STATE)` 로 받는다(오류 글자는 `첫 키가 type: context-state 가 아니다`). `interview_dir(repo)` 는 (새 폴더, 옛 폴더, 사유)를 내는 `intent_dirs(repo)` 로 바꾸고, `interview_files` 는 두 폴더(같으면 한 번)를 읽어 `state_suffixes()` 두 꼴의 짝 결과물 없는 상태 파일을 모은다. 기능 탐지 줄은 `"context-state" in (SCRIPTS / "state_path.py")…` 로. 칸 이름: 상태줄 `컨텍스트 쌓기 조사 %d/%d` · `컨텍스트 쌓기 셀 수 없음`, 지도 `컨텍스트 쌓기: 진행 중 %d개` · `컨텍스트 쌓기: 진행 중 없음` · `컨텍스트 쌓기: 셀 수 없음 — …`, 폴더 사유의 「인터뷰 폴더」 → 「의도 폴더」, 「진행 중 인터뷰 상태 파일」 → 「진행 중 컨텍스트 쌓기 상태 파일」, 마감 이름 「인터뷰 상태 파일」 → 「컨텍스트 쌓기 상태 파일」. 이 파일의 주석 · docstring 의 단계 낱말도 같은 커밋에서 바꾼다(E2 예약 파일을 한 번만 건드린다).
  - skill 글: `skills/context-build/SKILL.md` 의 펜스 표지 `<!-- context-state-entry:begin -->` · `end`, 판결 글자 `context-state:` 를 읽는 모든 문장, 「풀린 입력」 판독 문장의 `type: interview-seed` · `type: interview-state` 는 「`type: intent-seed`(옛 기록은 `interview-seed`)」 꼴로 — 옛 글자는 같은 줄에 「옛 」 을 둔다(과제 10 의 낱말 락 규칙). `state-file.md` 의 판결 표 · `state_path.py" context-state --topic` · 자리 글(「의도 폴더(`intent_dir`)의 `<날짜>-<주제>-context.state.md` — 옛 꼴 상태 파일로 이어 온 일은 그 파일의 폴더 · 줄기 그대로」) · 상태 파일 머리 예시 `type: context-state`.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드)**

```python
# test_state_path(.sh 의 python 도우미) · test_interview_state.py
def test_new_state_path_is_context_form(self): ...           # 설정 없음 → <root>/docs/superpowers/intent/<date>-x-context.state.md
def test_finished_same_day_gets_hhmm_in_new_form(self): ...  # 같은 자리에 type: context-brief 결과물 → <date>-x-<HHMM>-context.state.md
def test_slot_accepts_old_kind_at_new_stem(self): ...        # 새 줄기 자리의 결과물이 옛 type: interview-brief 여도 끝난 일로 본다(남의 파일로 막지 않는다)
def test_subcommand_renamed(self): ...                       # state_path.py context-state rc 0 · state_path.py interview-state rc 2
def test_entry_verdict_prefix(self): ...                     # entry --arg <옛 꼴 상태 파일> → 마지막 줄 "context-state: RESUME <경로>"
def test_entry_accepts_old_and_new_state_kind(self): ...     # type: interview-state · type: context-state 둘 다 RESUME
def test_entry_new_seed_topic_both_forms(self): ...          # <date>-ab-intent.md(type: intent-seed) · 옛 <date>-ab-interview.md(type: interview-seed) → "context-state: NEW-SEED ab-brief seed=…"
def test_resume_candidate_in_old_folder(self): ...           # 두 폴더가 다르고 옛 폴더에 같은 seed 의 옛 꼴 상태 파일 → candidate 줄 · "context-state: ASK"
def test_resume_candidates_dedup_same_folder(self): ...      # 옛 키만 있어 두 폴더가 같다 → 같은 후보가 한 번만
def test_migrate_writes_new_kind(self): ...                  # migrate-legacy 가 쓴 머리 첫 키 "type: context-state" · 이름 끝 -context.state.md
def test_seed_audit_for_session_both_forms_new_folder(self): ...  # 새 폴더의 -intent.audit.md · 옛 꼴 -interview.audit.md(같은 세션) 각각 찾음 · 옛 폴더(다른 폴더)의 것은 찾지 않음
# test_control_plane.py
def test_statusline_counts_both_folders_once(self): ...      # 새 · 옛 폴더에 진행 중 상태 파일 하나씩 → "컨텍스트 쌓기 조사" 칸 · 지도 "진행 중 2개" · 두 키가 같은 폴더면 한 번
def test_parse_accepts_both_state_kinds(self): ...
def test_show_label_words(self): ...                          # 진행 중 없음 → "컨텍스트 쌓기: 진행 중 없음" · 출력에 "인터뷰" 없음
```

Run: 위 테스트 파일들 → Expected: 새 시험 FAIL.

- [ ] **Step 2: 고친다** — 위 Interfaces 대로. 쓰는 쪽(`interview_state_path` · `migrate-legacy`)은 새 글자만, 읽는 쪽(진입 · 후보 · 상태줄)은 두 꼴. 옛 글자는 모듈로만.

- [ ] **Step 3: 판결 글자를 읽는 쪽을 함께 바꾼다** — Task 1 `## 판결 글자를 읽는 곳` 의 skill 글과 테스트에서 `interview-state:` → `context-state:` · `interview-state-entry` → `context-state-entry` · `state_path.py" interview-state` → `state_path.py" context-state`. 끝나면 `git grep -n -e 'interview-state:' -e 'interview-state-entry' -e 'state_path.py" interview-state' -- plugins shared tools ':!*CHANGELOG.md'` 가 0건(손으로 만든 옛 기록의 머리 `type: interview-state` 는 이 grep 에 걸리지 않는다).

- [ ] **Step 4: 통과를 본다** — 위 테스트들 · `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`(본문 줄 수 상한 — `context-build/SKILL.md` 가 604 줄을 넘지 않는다) · 펜스를 뽑아 돌리는 테스트 가운데 `context-state-entry` 를 뽑는 것. Expected: 통과.

- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤: (지우기) 후보 찾기에서 옛 폴더 · (뒤집기) `interview_state_path` 가 옛 꼴 줄기를 쓰게 · (더하기) 상태줄이 두 폴더가 같아도 두 번 읽게 · (꼴 바꾸기) 판결 접두를 `context-state ` (콜론 없음)로. 각각 시험 실패. 양성 대조: 원본에서 통과.

- [ ] **Step 6: 커밋** — `git commit -m "feat(spec-distill): 상태 파일을 새 꼴로 쓰고 옛 꼴과 옛 폴더의 진행 중 일을 함께 읽는다"`.

---

### Task 5: 종류 글자 · 머리 키를 읽는 스크립트와 옛 꼴 · 새 꼴 짝 시험 (AC21 · AC23)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py`(`atype != "interview-audit"` · `type:\s*interview-brief`) · `check_bundle_coverage.py`(`source_interview` 둘 · `"interview-brief"` 둘) · `spec_review_bundle.py`(`KINDS` · `source_interview` 셋) · `roadmap_status.py`(`source_interview` 둘) · `raw_source.py`(`AUDIT_TYPE` · `SEED_TYPE` · `R_AUDIT_TYPE`) · `team_write.py`(E1 예약 — `FRAMING_TYPE` 과 그 비교 줄, `import legacy_names`) · `roadmap_draft_entry.py`(`stem = brief[:-3]` 줄 → `legacy_names.siblings`) · 그 오류 글자를 무는 테스트
- Create: `plugins/spec-distill/tests/test_legacy_forms.py`

**Interfaces:**
- Consumes: 과제 2 모듈.
- Produces:
  - 종류를 견주는 곳은 모두 `legacy_names.kind_matches(have, <새 글자>)`, 머리 키를 읽는 곳은 `legacy_names.source_of(fm)`(머리 키 이름을 반복으로 보는 곳은 `head_keys()`).
  - 오류 · 거절 글자의 종류 이름과 머리 키 이름은 새 글자(`type != context-brief` · `audit type 'x' != 'context-audit'` · `frontmatter type 이 epic-bundle · context-brief 가 아니다` · `설계문서 frontmatter 에 source_intent 가 없다` · `설계문서 source_intent(<값>) 와 다른 파일이다` · `framing 기록 파일 머리의 type 이 intent-seed-audit 이 아니다`). 판정(rc · 판결 낱말)은 바뀌지 않는다.
  - `check_bundle_coverage.py` 가 설계문서 폴더에서 같은 source 의 설계문서를 고르는 자리는 `source_of` 로 — 옛 키와 새 키의 설계문서가 섞여 있어도 같은 묶음의 설계문서로 센다.

- [ ] **Step 1: 짝 시험을 쓴다(계획이 적은 코드 — 옛 · 새 글자를 시험에 박는다. 대응표 모듈을 import 해 짝을 만들지 않는다 — 시험이 모듈의 전제를 물려받는다)**

시험은 임시 git 저장소에 같은 내용의 기록 묶음을 두 꼴로 만든다. 꼴 표:

```python
FORMS = {
    "old": {"dir": "docs/superpowers/interview/", "seed": "-interview.md", "brief": "-interview.md",
            "state": "-interview.state.md", "k_seed": "interview-seed", "k_framing": "interview-seed-audit",
            "k_state": "interview-state", "k_brief": "interview-brief", "k_audit": "interview-audit",
            "head": "source_interview"},
    "new": {"dir": "docs/superpowers/intent/", "seed": "-intent.md", "brief": "-context.md",
            "state": "-context.state.md", "k_seed": "intent-seed", "k_framing": "intent-seed-audit",
            "k_state": "context-state", "k_brief": "context-brief", "k_audit": "context-audit",
            "head": "source_intent"},
}
```

묶음 내용의 재료: 결과물 · audit 은 `tests/fixtures/interview-brief-valid.md` 와 `.audit.md`(머리의 `type:` · `audit_file:` 을 꼴에 맞게), seed · framing 기록은 `tests/raw_source_fixture.py` 의 도우미, 상태 파일은 `seed:` 가 그 꼴의 seed 를 가리키는 최소 머리, 설계문서는 머리 키 하나가 결과물을 가리키는 것, 로드맵 · 묶음은 `test_roadmap_status.sh` 가 임시 레포를 만드는 도우미. 출력 견주기는 경로와 꼴 글자를 자리표(`<DIR>` · `<SFX>` · `<KIND>` · `<HEAD>`)로 바꾼 뒤 한다 — 남는 차이가 판정 차이다.

```python
class LegacyForms(unittest.TestCase):
    def test_check_brief_gate_same(self): ...          # check_brief.py gate <brief> → rc · 정규화한 출력 같음
    def test_check_verbatim_same(self): ...            # check_verbatim_coverage.py <brief> <audit> → 같음
    def test_raw_source_locate_same(self): ...         # raw_source.py locate --interview <brief> --absolute → 둘 다 "raw-source: FOUND"
    def test_build_brief_bundle_same(self): ...        # build_brief_bundle.py(원자료 싣기 포함) → rc 같음
    def test_bundle_coverage_same(self): ...           # check_bundle_coverage.py --plan <설계문서> <계획> → 첫 줄 같음
    def test_spec_review_bundle_same(self): ...        # spec_review_bundle.py 진입 대조 → 판결 같음
    def test_roadmap_status_same(self): ...            # 설계문서 머리 키가 옛 · 새인 에픽 → 단계 줄 같음
    def test_team_write_framing_same(self): ...        # team_write.py 가 framing 기록 종류를 견주는 길(original … --framing-audit) → rc · 판결 같음
    def test_mixed_old_and_new_in_one_repo(self): ...  # 옛 꼴 묶음과 새 꼴 묶음을 한 레포에 함께 두어도 서로를 남의 것으로 읽지 않는다
    def test_kind_cross_rejected(self): ...            # 결과물 자리에 옛 seed 종류(interview-seed)를 두면 두 꼴 모두 같은 거절
```

Run: `python3 plugins/spec-distill/tests/test_legacy_forms.py` → Expected: 새 꼴 쪽이 FAIL(지금 스크립트는 새 글자를 모른다).

- [ ] **Step 2: 고친다** — 위 Files 의 자리를 Interfaces 대로. `roadmap_draft_entry.py` 의 audit · 상태 파일 경로는 `legacy_names.siblings(brief)` 로(계획 1 메모). `raw_source._chain` 은 seed 경로에서 기록 경로를 짓는 그대로 둔다 — 새 꼴도 `X-intent.md` ↔ `X-intent.audit.md` 로 줄기가 같아 커밋 · PR 본문 펜스의 「seed 를 기록 경로에서 거꾸로 짓지 않는다」 글자 락과 갈리지 않는다(계획 1 메모 — 갈리지 않음을 Step 1 의 `test_raw_source_locate_same` 이 새 꼴로도 보인다).

- [ ] **Step 3: 오류 글자를 무는 테스트를 맞춘다** — `type != interview-brief` 등 옛 종류 이름을 오류 글자로 무는 테스트를 새 글자로(Task 1 `## 옛 글자를 무는 테스트` 에서 고른다). 손으로 만든 옛 기록을 먹이는 픽스처는 그대로 둔다.

- [ ] **Step 4: 통과를 본다** — `python3 plugins/spec-distill/tests/test_legacy_forms.py` · `bash plugins/spec-distill/tests/test_check_brief.sh` · `python3 plugins/spec-distill/tests/test_check_brief_frontmatter.py` · `bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh` · `bash plugins/spec-distill/tests/test_bundle_coverage.sh` · `bash plugins/spec-distill/tests/test_spec_review_bundle.sh` · `bash plugins/spec-distill/tests/test_roadmap_status.sh` · `python3 plugins/spec-distill/tests/test_raw_source.py` · `bash plugins/spec-distill/tests/test_team_write.sh` · `python3 plugins/spec-distill/tests/test_roadmap_draft_entry.py`. Expected: 통과.

- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤: (지우기) `check_brief` 의 새 글자 받기 · (뒤집기) `source_of` 대신 옛 키만 읽게 `roadmap_status` 를 되돌림 · (꼴 바꾸기) `spec_review_bundle.KINDS` 에서 새 글자를 뺌 · (더하기) `team_write` 가 옛 글자만 받게. 각각 짝 시험 실패. 양성 대조: 원본 통과.

- [ ] **Step 6: 커밋** — `git commit -m "feat(spec-distill): 종류 글자와 머리 키를 읽는 스크립트가 옛 글자와 새 글자를 함께 받는다"`.

---

### Task 6: 새로 쓰는 글자 — 템플릿 · 넘김 글 · skill 펜스 (AC20 · AC25 의 펜스 몫)

**Files:**
- Modify(템플릿): `plugins/spec-distill/templates/interview-seed-template.md`(`type: interview-seed`) · `interview-seed-audit-template.md`(`type:`) · `interview-brief-template.md`(`type:` · `audit_file:` 예시) · `interview-audit-template.md`(`type:` · `payload:` 예시 · 상태 파일 이름 예시). 파일 이름은 그대로.
- Modify(넘김 글 · 머리 키): `scripts/roadmap_render.py`(묶음 본문의 「frontmatter `source_interview:` 에」 문장) · `references/epic-handoff.md`(E4) · `references/brief-handoff.md` · `references/roadmap-ontology.md`(설계문서 행) · `references/conducting.md`(E1 · E2) · `skills/spec-review/SKILL.md` 의 frontmatter `description`(E4) · `plugins/spec-distill/README.md`(종류 글자 · 폴더 · 머리 키가 나오는 줄)
- Modify(skill 펜스 · 글): `skills/intent-sync/SKILL.md`(`get interview_dir` · `IV_NAME=…-interview"` · `check-path interview_dir` 둘 · `<날짜>-<topic>-interview.md` 글 둘 · 다음 세션 줄) · `skills/context-build/references/finishing.md`(`get interview_dir` · `PAYLOAD="$(pwd)/${IDIR}<file>"` · payload 이름 글 · `type: interview-brief` 지시 · 로드맵 경로 규칙의 「끝의 `-interview.md`」 · 커밋 펜스의 `check-path interview_dir` 셋과 그 안내 글) · `skills/context-build/references/seed-input.md`(`type: interview-seed`) · `skills/roadmap-draft/SKILL.md`(E4 — `get interview_dir` · `BRIEF_REL` · `check-path interview_dir` · 로드맵 폴더 이름 규칙) · `skills/roadmap-draft/references/pr-merge.md`(E4 — `check-path interview_dir`) · `skills/reviewing-brief/SKILL.md`(`STATE="${PAYLOAD:+${PAYLOAD%-interview.md}-interview.state.md}"` 일곱 줄과 그 설명 문단)
- Modify(시험): `plugins/spec-distill/tests/test_roadmap_write.sh` 의 「R1 AC3 옛 형식 create 나무」 기준 해시 · 펜스를 뽑아 돌리는 테스트(`test_finish_commit_roadmap.sh` · `test_finish_pr_merge.sh` · `test_roadmap_draft_skill.sh` · `test_framing_raw_source.sh` 등 — Task 1 `## 옛 글자를 무는 테스트`)
- Modify: `scripts/roadmap_draft_entry.py`(이른 경로 확인 — 아래)

**Interfaces:**
- Consumes: 과제 3 `check-path intent_dir` · `get intent_dir` · 과제 4 상태 파일 새 꼴 · 과제 5 `roadmap_draft_entry` 의 `siblings`.
- Produces:
  - 결과물 경로를 짓는 두 펜스(Task 1 `## 결과물 경로를 짓는 펜스`)는 의도 폴더 + 파일 이름으로 짓지 않는다 — finishing.md 의 리뷰 넘김 펜스는 `STATE_F="<상태 파일 절대경로>"` 자리표 한 줄을 두고 `PAYLOAD="${STATE_F%.state.md}.md"`(그래서 옛 꼴 줄기로 이어 온 일도 그 폴더 · 그 줄기다), roadmap-draft `## 5.` 생성 펜스는 `BRIEF_REL="$(git -C "$(dirname -- "<결과물 절대경로>")" ls-files --full-name -- "<결과물 절대경로>")"`(결과물은 진입 검사가 커밋을 확인했다)이고 비면 멈춘다. `IDIR` 줄은 다른 데 쓰지 않으면 지운다.
  - reviewing-brief 의 `STATE=` 일곱 줄은 `STATE="${PAYLOAD:+${PAYLOAD%.md}.state.md}"` — 두 꼴 모두 줄기에서 짓는다. 설명 문단도 「payload 이름의 `.md` 를 `.state.md` 로 바꾼 것」.
  - 모든 `check-path interview_dir` → `check-path intent_dir`, 모든 `get interview_dir` → `get intent_dir`. 커밋 펜스 · PR 파일 세기의 거절 · 안내 글은 「정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다」 꼴로.
  - finishing.md 의 payload 이름 글: 「`<줄기>.md` — 상태 파일 줄기 그대로(새로 시작한 일은 `<YYYY-MM-DD>-<kebab-topic>-context.md`, 옛 꼴 상태 파일로 이어 온 일은 그 파일의 줄기)」, frontmatter 지시 `type: context-brief`(어느 줄기든). 로드맵 경로 규칙과 roadmap-draft 의 폴더 이름 규칙: 「결과물 파일 이름에서 끝의 `-context.md`(옛 꼴 줄기면 옛 `-interview.md`)를 뗀 이름」.
  - intent-sync: `IV_NAME="$(date +%F)-${TOPIC_ARG}-intent"`, 안내 · 다음 세션 줄의 `<날짜>-<topic>-intent.md`.
  - 묶음 본문 · 넘김 글 · 설계문서 리뷰 기준(과제 7)이 `source_intent` 를 일러 준다(AC20).
  - `roadmap_draft_entry.py`: 다른 STOP 사유를 모으는 자리에서 `repo_defaults.py check-path intent_dir <결과물> --root <top>` 을 하위 프로세스로 돌려 rc 3 이면 `roadmap-entry: STOP 결과물이 의도 폴더 바로 아래가 아니다: <stderr 의 사유 첫 줄>` 을 더한다(설계 미룸 행 「로드맵 잡기 진입이 … 일찍 보지 않는다」 — 받는 곳 계획 2. 같은 판정이 커밋 펜스에서 늦게 걸리던 것을 진입으로 당긴다 — 새 멈춤 조건이 아니라 같은 조건을 먼저 보는 것). rc 2 · 그 밖이면 내부 오류(rc 2)로 멈춘다.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — 펜스는 `test_finish_commit_roadmap.sh` 의 뽑기 도우미로 뽑아 임시 저장소에서 돈다)**

```bash
# test_finish_commit_roadmap.sh 에 더한다 — context-commit 펜스
#  new_interview_commit           : 새 폴더의 <date>-x-context.md · .audit.md · .state.md → 커밋 성공 · 커밋 파일 셋
#  old_stem_payload_and_commit    : 두 폴더가 다르고 옛 폴더의 x-interview.state.md 로 이어 온 일 — 리뷰 넘김 펜스의 PAYLOAD 가
#                                   옛 폴더/x-interview.md 이고, 그 결과물(type: context-brief) · audit · 상태 파일을 커밋 펜스가 받는다
#  old_seed_new_interview_commit  : 옛 폴더의 옛 seed · framing 기록 + 새 폴더의 새 꼴 결과물 묶음 → 다섯 파일 한 커밋(B9)
#  old_folder_new_form_rejected   : 두 폴더가 다를 때 옛 폴더에 x-context.md → 커밋하지 않음 · 사유 「옛 의도 폴더」
# test_finish_pr_merge.sh(또는 roadmap-draft 의 PR 펜스 시험)에 더한다
#  old_seed_pr_files_only         : 위 묶음 + 로드맵 폴더만 바꾼 PR → "roadmap-pr-files: ONLY"
# test_roadmap_draft_skill.sh 에 더한다
#  brief_rel_from_git             : 생성 펜스의 BRIEF_REL 이 결과물의 레포 상대 경로(옛 폴더의 옛 꼴 결과물도)
# 글자
has "$FIN" 'PAYLOAD="${STATE_F%.state.md}.md"'
lacks "$FIN" '${IDIR}<file>'
for f in $(git ls-files 'plugins/spec-distill/skills/*'); do lacks "$f" 'check-path interview_dir'; lacks "$f" 'get interview_dir'; done
has "plugins/spec-distill/skills/intent-sync/SKILL.md" '-${TOPIC_ARG}-intent"'
```

```python
# test_roadmap_draft_entry.py 에 더한다
def test_brief_outside_intent_folder_stops(self): ...   # 결과물이 docs/other/ 아래 → "roadmap-entry: STOP 결과물이 의도 폴더 바로 아래가 아니다: " · rc 1
def test_old_form_brief_in_old_folder_ok(self): ...     # 옛 폴더의 옛 꼴 결과물(커밋됨) → 이 STOP 이 없다
# 템플릿이 새 글자를 쓴다 — test_legacy_names 와 같은 파일이 아니라 템플릿을 무는 기존 테스트에 더한다
#   templates/interview-brief-template.md 머리 "type: context-brief" · audit_file 예시 끝 "-context.audit.md"
#   templates/interview-seed-template.md "type: intent-seed" · interview-seed-audit-template.md "type: intent-seed-audit"
#   templates/interview-audit-template.md "type: context-audit" · payload 예시 끝 "-context.md"
#   roadmap_render 가 낸 묶음 본문에 "frontmatter `source_intent:`" 가 있고 "source_interview" 가 없다
```

Run: 위 테스트들 → Expected: 새 시험 FAIL.

- [ ] **Step 2: 지휘자에게 알린다** — E4 예약(`skills/roadmap-draft/` · `references/epic-handoff.md` · `skills/spec-review/SKILL.md`) · E1 · E2 예약(`references/conducting.md`)의 고칠 줄(grep 글자)을 보고한다.

- [ ] **Step 3: 고친다** — 위 Files · Interfaces 대로. 펜스를 바꾸면 그 펜스를 뽑아 무는 테스트의 기대 글자를 같은 커밋에서 바꾼다.

- [ ] **Step 4: 기준 해시를 다시 잰다** — `roadmap_render.py` 의 묶음 본문 글이 바뀌었으니 `test_roadmap_write.sh` 의 「R1 AC3 옛 형식 create 나무」 기준 해시를 그 시험이 적은 방법으로 다시 재어 고친다(계획 1 메모 — 옆 로드맵 R1 의 시험이다). 해시 말고 바뀐 것이 없는지 그 나무의 diff 로 본다 — 묶음 본문의 그 한 문장만 달라야 한다.

- [ ] **Step 5: 통과를 본다** — Step 1 의 테스트들 · `bash plugins/spec-distill/tests/test_roadmap_write.sh` · `bash plugins/spec-distill/tests/test_stage_split.sh` · `bash plugins/spec-distill/tests/test_stage_read_budget.sh`(AC37 — 줄 수가 늘었으면 계획 1 기준과 견줘 보고) · `python3 shared/entry/check_invocation_surface.py`. Expected: 통과.

- [ ] **Step 6: 변이로 이빨을 본다** — 커밋 뒤: (되돌리기) reviewing-brief 의 `STATE=` 하나를 옛 꼴로 · (꼴 바꾸기) finishing 의 PAYLOAD 를 `${IDIR}` 로 되돌림(→ `old_stem_payload_and_commit` 실패) · (더하기) intent-sync 의 `IV_NAME` 을 `-interview` 로 · (지우기) `roadmap_draft_entry` 의 이른 확인. 각각 시험 실패.

- [ ] **Step 7: 커밋** — `git commit -m "feat(spec-distill): 새로 쓰는 기록이 새 종류 글자 · 이름 · 머리 키를 쓰고 펜스가 옛 폴더의 일을 받는다"`.

---

### Task 7: agent 정의와 리뷰 기준 — 보안 리뷰 묶음 (AC20 · AC36 · AC40)

이 계획에서 agent 정의와 리뷰 기준을 고치는 커밋은 이것 하나다(두 플러그인을 함께).

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`(`source_interview` 셋 · `interview-brief` 둘) · `plugins/spec-distill/agents/seed-readback.md`(`interview-seed`) · `plugins/spec-distill/agents/brief-readback.md`(「an context brief」 → 「a context brief」 — 설계 미룸 행) · `plugins/quality-gates/agents/intent-critic.md`(「인터뷰 · 로드맵 · 의도 출처가 남긴 의심」 의 단계 낱말) · 과제 1 이 같은 정규식 · 낱말로 더 찾은 agent 정의 · 리뷰 기준

- [ ] **Step 1: 대상 목록을 다시 낸다** — `git grep -l -E 'source_interview|interview-(seed|state|brief|audit)|인터뷰|interview brief|an context' -- 'plugins/*/agents' shared/docreview/agents plugins/spec-distill/references/docreview-profiles` 와 같은 범위의 홀로 쓰인 영어 `interview`(계획 1 과제 12 의 정규식).
- [ ] **Step 2: 고치기 전 규칙 목록을 뜬다** — 파일마다 `git show HEAD:<파일>` 에서 frontmatter `tools:` 줄 · 「하지 않는다 / must not / never / 금지」 가 든 줄 · 수치 임계 줄을 뽑아 무시되는 자리의 `rules-before.txt` 에.
- [ ] **Step 3: 고친다** — `source_interview` → `source_intent`(리뷰 기준이 새 설계문서에 일러 주는 키 — AC20. 정답의 출처를 찾는 문장은 「`source_intent`(옛 문서는 `source_interview`)」 로 옛 키도 읽게 쓴다 — 리뷰 대상 설계문서가 옛 키일 수 있다). 종류 글자는 새 글자(옛 글자는 같은 줄에 「옛 」). 단계 낱말은 계획 1 의 「낱말 대응」. 문장의 뜻 · 지시 · 임계는 바꾸지 않는다.
- [ ] **Step 4: 앞뒤 규칙을 견준다** — 같은 방법으로 `rules-after.txt` 를 뜨고 `diff` 한다. 바뀐 줄은 이름 · 낱말 · 키 글자뿐이고 `tools:` 줄은 같아야 한다. 결과를 PR 본문 「보안 리뷰 대상」 절 재료로 남긴다.
- [ ] **Step 5: 시험** — `bash shared/tests/test_docreview_agents.sh` · `bash shared/tests/test_copy_of_contract.sh` · `bash plugins/spec-distill/tests/test_research_agents_frontmatter.sh` · 설계문서 리뷰 기준을 무는 테스트(`git grep -l 'docreview-profiles/design-doc.md' -- plugins/*/tests shared/tests`) · quality-gates 의 intent-critic agent 를 무는 테스트(`git grep -l 'agents/intent-critic.md' -- plugins/quality-gates/tests`). Expected: 통과.
- [ ] **Step 6: 커밋** — `git add <바꾼 파일들>` · `git commit -m "docs(spec-distill): 리뷰 기준 · agent 정의의 머리 키 · 종류 글자 · 단계 낱말을 새 이름으로 (보안 리뷰 대상)"` — 커밋 본문에 quality-gates agent 한 파일이 함께 들었다고 적는다.

---

### Task 8: quality-gates 가 두 머리 키를 읽는다 (AC26 · AC40 의 quality-gates 몫)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_origin.py`(`DEFAULT_MARKERS` · `_follow_changed` 의 `("source_interview", "source_brief")` · `build_origin` 의 `frontmatter_value(spec_text, "source_interview")` · docstring) · `scripts/other_teams.py`(`LINE_INTERVIEW` 글) · `README.md`(트리 주석의 `source_interview` 따라가기 · 끄는 변수 표와 「의도 문서의 표시」 문단의 기본값 글자 둘) · `skills/quality-pipeline/references/intent-critic.md`(머리 키 글자) · 그 글자를 무는 `plugins/quality-gates/tests/`
- 판 올림과 변경 기록은 과제 11.

**Interfaces:**
- Produces: `DEFAULT_MARKERS = ("source_intent", "source_interview", "roadmap", "source_brief", "type=roadmap", "type=epic-bundle")`. 설계문서에서 원문을 따라갈 때는 `source_intent` 를 먼저 읽고 없으면 `source_interview`. 바뀐 의도 문서를 따라갈 때 보는 키는 `("source_intent", "source_interview", "source_brief")`. `LINE_INTERVIEW = "컨텍스트 쌓기 단계의 팀은 확인 못 함 — 그 문서의 표시가 설정에 없다"`(상수 이름은 그대로). `_interview_unmarked` 는 함수 이름 그대로.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — 기존 `intent_origin` 시험의 임시 레포 도우미를 쓴다)**

```python
def test_default_markers_have_both_head_keys(self): ...   # "source_intent" 와 "source_interview" 가 DEFAULT_MARKERS 에
def test_origin_follows_source_intent(self): ...           # 설계문서 머리 source_intent → 원문 칸에 그 파일
def test_origin_follows_source_interview(self): ...        # 옛 머리 키 → 같은 원문(바꾸기 전과 같다)
def test_origin_prefers_new_key(self): ...                 # 두 키가 다른 파일 → source_intent 쪽
def test_changed_doc_follows_source_intent(self): ...      # 바뀐 의도 문서의 source_intent 를 따라간다
def test_line_interview_words(self): ...                   # LINE_INTERVIEW 에 "컨텍스트 쌓기" · "인터뷰" 없음
```

Run → FAIL.

- [ ] **Step 2: 고친다** — 위 Interfaces 대로. 환경 변수 `DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS` 의 이름 · 읽는 법은 그대로이고 기본값만 바뀐다.
- [ ] **Step 3: 글을 맞춘다** — README 의 기본값 글자 둘을 새 목록으로, 트리 주석을 「`source_intent` · 옛 `source_interview` 따라가기」 로. `intent-critic.md` reference 의 머리 키 글자도 같은 꼴로.
- [ ] **Step 4: 통과를 본다** — `plugins/quality-gates/tests/` 가운데 `intent_origin` · `other_teams` · `INTENT_DOC_MARKERS` 를 무는 시험(`git grep -l -e intent_origin -e other_teams -e INTENT_DOC_MARKERS -- plugins/quality-gates/tests`). Expected: 통과.
- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤: (지우기) `DEFAULT_MARKERS` 의 `source_intent` · (뒤집기) 옛 키를 먼저 읽게 · (지우기) `_follow_changed` 의 새 키. 각각 시험 실패.
- [ ] **Step 6: 커밋** — `git commit -m "feat(qg): 의도 문서 표시와 원문 따라가기가 source_intent 와 옛 source_interview 를 함께 읽는다"`.

---

### Task 9: 로드맵 에픽의 「로드맵 다시 잡기」 라벨 (사용자 결정 2026-11-22)

설계문서 `## 결정 기록` 끝 줄 — 로드맵 에픽의 설계문서에서는 spec-review 게이트 ③ 후속 질문의 「컨텍스트 쌓기 다시 열기」 를 「로드맵 다시 잡기」 로 보인다(로드맵 밖 설계문서는 그대로). 계획 1 메모가 이 계획에 넘겼다.

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(E4 — 「③ 의 갈래와 로드맵 에픽.」 문단과 그 아래 「「컨텍스트 쌓기 다시 열기」 갈래는」 불릿) · `references/redecompose.md`(「1」 의 「「컨텍스트 쌓기 다시 열기」 갈래를 골랐을 때」 · 「그만둔다」 줄의 네 갈래 목록) · `plugins/spec-distill/README.md`(「재분해(「컨텍스트 쌓기 다시 열기」)」) · `tests/test_decompose_surface.sh` · `tests/test_review_handoff_order.sh` · `shared/tests/fixtures/ask-sites.tsv`(그 질문 자리 행이 라벨을 쥐면)

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_decompose_surface.sh` 에 더한다)**

```bash
SR=plugins/spec-distill/skills/spec-review/SKILL.md
RD=plugins/spec-distill/references/redecompose.md
has "$SR" '로드맵 에픽이면 이 갈래의 라벨은 「로드맵 다시 잡기」 다'
has "$SR" '「로드맵 다시 잡기」: 얻음: '
has "$RD" '「로드맵 다시 잡기」 갈래를 골랐을 때'
has "$RD" '(「지적대로 고치기」 · 「이 에픽 다시 설계」 · 「로드맵 다시 잡기」 · 「직접 편집」 네 갈래)'
has plugins/spec-distill/README.md '재분해(「로드맵 다시 잡기」)'
has "$SR" '「컨텍스트 쌓기 다시 열기」(`context-build` 재진입)'   # 로드맵 밖 설계문서의 라벨은 그대로
```

Run → FAIL.

- [ ] **Step 2: 고친다** — 「③ 의 갈래와 로드맵 에픽.」 문단은 세 갈래 질문(로드맵 밖)을 그대로 두고, `roadmap:` 줄이 있을 때의 불릿을 「로드맵 에픽이면 이 갈래의 라벨은 「로드맵 다시 잡기」 다 — 컨텍스트 쌓기를 다시 열지 않고 같은 로드맵 위의 재분해 절차로 간다 …」 로 다시 쓰고, 그 갈래의 설명을 「「로드맵 다시 잡기」: 얻음: 에픽 경계가 틀렸다면 같은 로드맵 위에서 다시 나눈다 · 내줌: 설계와 리뷰를 처음부터 다시 거치고 다른 에픽에 닿을 수 있다」 로 둔다. 「(권장)」 규칙 · 답 읽기 규칙은 그대로. `redecompose.md` · README · 두 테스트의 옛 기대 글자(「컨텍스트 쌓기 다시 열기」 를 로드맵 에픽 맥락으로 무는 줄)를 새 라벨로.
- [ ] **Step 3: 통과를 본다** — `bash plugins/spec-distill/tests/test_decompose_surface.sh` · `bash plugins/spec-distill/tests/test_review_handoff_order.sh` · `bash shared/tests/test_ask_recommendation.sh`. Expected: 통과.
- [ ] **Step 4: 변이로 이빨을 본다** — (되돌리기) 불릿의 새 라벨을 옛 라벨로 · (지우기) redecompose 「그만둔다」 줄의 새 라벨. 각각 실패.
- [ ] **Step 5: 커밋** — `git commit -m "docs(spec-distill): 로드맵 에픽의 설계문서 리뷰에서 재분해 갈래를 「로드맵 다시 잡기」 로 보인다"`.

---

### Task 10: 스크립트 안내 낱말과 락 둘 (AC23 · AC40)

**Files:**
- Modify: spec-distill `scripts/` 가운데 단계를 가리키는 「인터뷰」 · 홀로 쓰인 영어 `interview` 가 문자열이나 주석에 남은 것(2026-11-22: `check_brief.py` · `check_verbatim_coverage.py` · `build_brief_bundle.py` · `state_path.py` · `interview_state.py` · `raw_source.py` · `team_write.py`(E1 — 안내 글 둘) · `ledger_sweep.py` 는 「옛 인터뷰 기록」 이라 그대로) · 옛 종류 글자를 docstring · 주석에 쥔 것(`check_seed.py` · `seed_body.py` · `build_seed_inline_blob.py`(그 안의 `"## 초안 (interview-seed 본문)"` 은 리뷰어에게 가는 글이라 `intent-seed`) · `build_brief_inline_blob.py` · `check_verbatim_coverage.py` · `check_brief.py`) · `skills/reviewing-brief/SKILL.md`(`check_verbatim_coverage.py` 출력 인용 「인터뷰를 닫은 답」) · `plugins/spec-distill/tests/test_stage_words.sh`
- Create: `plugins/spec-distill/tests/test_legacy_literals.sh`(100755)

**Interfaces:**
- Consumes: 과제 2–9 뒤의 스크립트 · 글.
- Produces: 락 둘 — `test_legacy_literals.sh`(AC23) · 넓힌 `test_stage_words.sh`(AC40 전체 — 계획 1 범위 + spec-distill `scripts/` + quality-gates).

- [ ] **Step 1: AC23 락을 쓴다(계획이 적은 코드 — 그대로 싣고 `bash -n` 으로 먼저 잰다)**

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/*
# AC23 — 옛 글자(종류 글자 · 파일 이름 끝 · 머리 키 · 옛 기본 폴더)의 리터럴은 대응표 모듈(scripts/legacy_names.py) 한 곳에만 있다.
# 파이썬은 tokenize 로 문자열 · 주석 토큰만 본다(변수 · 함수 이름은 보지 않는다). 셸은 본문 전체를 본다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_legacy_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/spec-distill/scripts/*'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
LIST="$(mktemp)"; OUT="$(mktemp)"
trap 'rm -f "$LIST" "$OUT"' EXIT
git -C "$ROOT" ls-files -- 'plugins/spec-distill/scripts/*' > "$LIST"
n_py="$(grep -c '\.py$' "$LIST")"
[ "$n_py" -ge 60 ] && ok "코퍼스(양성 짝): 스크립트 ${n_py}개" || no "코퍼스가 ${n_py}개 — 부재 단언이 공허하다"
python3 - "$ROOT" "$LIST" > "$OUT" <<'PY'
import io
import re
import sys
import tokenize
from pathlib import Path

root = Path(sys.argv[1])
MODULE = "plugins/spec-distill/scripts/legacy_names.py"
OLD = [
    re.compile(r"interview-(?:seed-audit|seed|state|brief|audit)(?![-A-Za-z0-9_])"),
    re.compile(r"-interview\.(?:state\.|audit\.)?md"),
    re.compile(r"source_interview"),
    re.compile(r"docs/superpowers/interview/"),
]
STEM = re.compile(r"(?<!-)-interview(?=[\"'])")   # 줄기를 짓는 문자열 조각 — 문자열 토큰에만
KINDS = ("STRING", "COMMENT", "FSTRING_MIDDLE")
hits = []
for rel in Path(sys.argv[2]).read_text(encoding="utf-8").split():
    if rel == MODULE:
        continue
    text = (root / rel).read_text(encoding="utf-8")
    if rel.endswith(".py"):
        pieces = []
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            name = tokenize.tok_name.get(tok.type, "")
            if name in KINDS:
                pieces.append((tok.start[0], name, tok.string))
    else:
        pieces = [(no, "TEXT", line) for no, line in enumerate(text.splitlines(), 1)]
    for no, name, s in pieces:
        bad = [p.pattern for p in OLD if p.search(s)]
        if name == "STRING" and STEM.search(s):
            bad.append(STEM.pattern)
        if bad:
            hits.append("%s:%d: %s" % (rel, no, s.strip().splitlines()[0][:120]))
for h in hits:
    print("HIT " + h)
PY
rc_py=$?
[ "$rc_py" -eq 0 ] && ok "스캐너가 돌았다" || no "스캐너 rc=${rc_py}"
n_hit="$(grep -c '^HIT ' "$OUT")"
if [ "$n_hit" -eq 0 ]; then ok "대응표 모듈 밖의 스크립트에 옛 글자 리터럴이 없다"
else sed 's/^HIT /  /' "$OUT"; no "옛 글자 리터럴 ${n_hit}곳"; fi
# 양의 짝 — 모듈이 옛 글자를 실제로 쥐고, 읽는 스크립트가 모듈을 쓴다
M="$ROOT/plugins/spec-distill/scripts/legacy_names.py"
for lit in 'interview-seed-audit' 'interview-brief' '-interview' 'source_interview' 'docs/superpowers/interview/'; do
  grep -qF -- "$lit" "$M" && ok "모듈: 「${lit}」" || no "모듈에 「${lit}」 가 없다"
done
for s in state_path interview_state check_brief check_bundle_coverage spec_review_bundle roadmap_status raw_source \
         control_plane repo_defaults team_write roadmap_draft_entry; do
  grep -qE '^(import legacy_names|from legacy_names import|import legacy_names as)' "$ROOT/plugins/spec-distill/scripts/$s.py" \
    && ok "${s}.py 가 대응표 모듈을 쓴다" || no "${s}.py 가 대응표 모듈을 쓰지 않는다"
done
finish
```

계획을 쓸 때 이 스캐너를 계획 1 뒤의 트리에 돌려 옛 글자 61곳을 찾는 것을 봤다(양성 대조 — 2026-11-22). 과제 2–9 뒤에는 0 이어야 한다. 남으면 그 자리를 모듈 상수로 바꾼다(주석이면 새 글자로 다시 쓴다). 모듈을 import 하는 줄의 꼴이 위 정규식과 다르면(예: 함수 안 import) 정규식이 아니라 import 를 모듈 최상위로 옮긴다.

- [ ] **Step 2: 낱말 락을 넓힌다(계획이 적은 코드 — `test_stage_words.sh` 의 `corpus()` · `--emit-scanned` · 스캐너를 바꾼다)**

코퍼스에 더한다: `'plugins/spec-distill/scripts/*'` 와 quality-gates 의 추적 파일(`git ls-files -- plugins/quality-gates ':!plugins/quality-gates/tests' ':!plugins/quality-gates/CHANGELOG.md'`). `# guards:` 머리에도 같은 글롭을 더한다. 스캐너의 파일 읽기를 아래 `pieces()` 로 바꾸고, `STAGE` · `BARE` 는 모든 파일에, 새 `LAYER` 는 `.py` 가 아닌 파일에만 건다(spec-distill 스크립트의 옛 층 글자는 Step 1 의 락이, quality-gates 스크립트의 두 머리 키는 AC26 이 정한 것이다).

```python
import io
import re
import tokenize

# 옛 층 글자 — 스크립트 밖 글에서는 같은 줄에 「옛 」 이 있을 때만 받는다(옛 기록을 가리키는 말).
LAYER = re.compile(
    r"interview_dir|source_interview|docs/superpowers/interview/"
    r"|interview-(?:seed-audit|seed|state|brief|audit)(?![-A-Za-z0-9_])"
    r"|-interview\.(?:state\.|audit\.)?md"
)
IDENT_STRING = re.compile(r"[rbuRBU]{0,2}[\"'][A-Za-z_][A-Za-z0-9_]*[\"']")   # "interview" 같은 사전 키 — 식별자로 본다


def pieces(rel, text):
    """(줄 번호, 글) — .py 는 문자열 · 주석 토큰만(식별자 같은 문자열 하나는 뺀다), 그 밖은 쉬운 말 규칙 블록을 뺀 줄."""
    if rel.endswith(".py"):
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            name = tokenize.tok_name.get(tok.type, "")
            if name not in ("STRING", "COMMENT", "FSTRING_MIDDLE"):
                continue
            if name == "STRING" and IDENT_STRING.fullmatch(tok.string):
                continue
            for i, line in enumerate(tok.string.splitlines()):
                yield tok.start[0] + i, line
        return
    inside = False
    for no, line in enumerate(text.splitlines(), 1):
        if "<!-- plain-language:begin -->" in line:
            inside = True
        if inside:
            if "<!-- plain-language:end -->" in line:
                inside = False
            continue
        yield no, line


def layer_hit(rel, line):
    return not rel.endswith(".py") and bool(LAYER.search(line)) and "옛 " not in line
```

면제 목록에서 계획 1 의 줄(`reviewing-brief/SKILL.md` 의 「인터뷰를 닫은 답 …」 — 이유 「계획 2 — 스크립트 출력 인용」)을 지운다 — 이 과제가 `check_verbatim_coverage.py` 의 그 글을 「컨텍스트 쌓기를 닫은 답」 으로 바꾸고 인용도 함께 바꾼다(안 쓰는 면제는 락이 실패로 알린다). 남는 `LAYER` 면제(같은 줄에 「옛 」 을 둘 수 없는 자리 — 예: quality-gates README 의 기본 표지 목록 `source_intent,source_interview,…`)는 「(파일, 줄 글자, 이유)」 로 올린다. 락은 「옛 」 규칙으로 받은 줄 수와 면제한 줄 수를 출력한다.

양의 짝을 더한다:

```bash
some_in "plugins/spec-distill/scripts/interview_state.py" 'context-state: '
some_in "plugins/spec-distill/scripts/control_plane.py" '컨텍스트 쌓기 조사'
some_in "plugins/spec-distill/skills/context-build/SKILL.md" '<!-- context-state-entry:begin -->'
some_in "plugins/spec-distill/skills/context-build/references/state-file.md" 'context-state: RESUME'
some_in "plugins/spec-distill/README.md" 'intent_dir'
some_in "plugins/spec-distill/references/docreview-profiles/design-doc.md" 'source_intent'
some_in "plugins/quality-gates/scripts/other_teams.py" '컨텍스트 쌓기 단계의 팀'
some_in "plugins/quality-gates/scripts/intent_origin.py" '"source_intent"'
```

Run: 두 락 → Expected: FAIL(남은 글자 · 낱말).

- [ ] **Step 3: 고친다** — 두 락의 출력이 곧 대상 목록이다. 스크립트의 문자열 · 주석에서 단계를 가리키는 「인터뷰」 는 「컨텍스트 쌓기」(조사 · 결과물 쪽) 또는 「로드맵 잡기」(분해 · 로드맵 쪽)로, 「인터뷰 폴더」 는 「의도 폴더」 로, 홀로 쓰인 영어 `interview` 는 `context-build` · `roadmap-draft` 로. 바꾼 출력 글자를 무는 테스트(예: `check_verbatim_coverage` 의 L3 사유 · `build_brief_bundle` 의 신원 불일치 사유 · `team_write` 의 안내)를 같은 커밋에서 바꾼다. skill 글 · 템플릿의 옛 층 글자가 남았으면 새 글자로 바꾸거나, 옛 기록을 가리키는 줄이면 「옛 」 을 같은 줄에 두어 그 뜻을 밝힌다.

- [ ] **Step 4: 통과를 본다** — `bash plugins/spec-distill/tests/test_legacy_literals.sh` · `bash plugins/spec-distill/tests/test_stage_words.sh` · Step 3 에서 고친 테스트 · `python3 shared/entry/check_invocation_surface.py`. 그리고 `git grep -n -e 'interview-state:' -e 'interview_dir' -- 'plugins/spec-distill/skills/*' 'plugins/spec-distill/references/*'` 가 「옛 」 이 든 줄뿐이다. Expected: 통과.

- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤:
  - AC23 락: (더하기) `roadmap_status.py` 의 문자열 하나에 `interview-brief` · (꼴 바꾸기) f-string `f"{x}-interview.md"` 를 한 스크립트에 · (자리 바꾸기) 주석 `# source_interview` · (지우기 — 양의 짝) `check_brief.py` 의 `import legacy_names` · (꼴 바꾸기 — 줄기) `"{0}-interview"` 를 `state_path.py` 에. 각각 실패. 양성 대조: `"interview-seed-audit-template.md"` 문자열과 `"--interview"` 문자열을 더하면 통과.
  - 낱말 락: (더하기) `control_plane.py` 문자열에 `인터뷰 조사` · (더하기 — 주석) `raw_source.py` 주석에 `the interview stage` · (더하기 — 옛 층) `skills/context-build/references/state-file.md` 에 「옛 」 없는 `interview_dir` 한 줄 · (뒤집기) 같은 줄에 「옛 」 을 붙이면 통과 · (지우기 — 양의 짝) `other_teams.py` 의 새 글. 양성 대조: `view["interview"]` 꼴 사전 키 문자열을 더하면 통과(식별자 문자열).

- [ ] **Step 6: 커밋** — `git commit -m "test(spec-distill): 옛 글자 리터럴은 대응표 모듈에만 있고 스크립트 · quality-gates 의 글이 단계를 새 이름으로 부른다"`.

---

### Task 11: 판 · 변경 기록 · README

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`(R5) · `plugins/spec-distill/README.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/README.md`
- Create: `plugins/spec-distill/tests/test_intent_layers_release.sh`(100755)

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_roadmap_draft_skill.sh` 의 판 시험 꼴과 도우미(`has` · `no`)를 따라 새 파일 `plugins/spec-distill/tests/test_intent_layers_release.sh`(100755)에)**

```bash
SD_VER=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' plugins/spec-distill/.claude-plugin/plugin.json)
QG_VER=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' plugins/quality-gates/.claude-plugin/plugin.json)
sd_sec=$(awk -v v="$SD_VER" 'index($0,"## ["v"]")==1{f=1;print;next} f&&/^## \[/{exit} f' plugins/spec-distill/CHANGELOG.md)
qg_sec=$(awk -v v="$QG_VER" 'index($0,"## ["v"]")==1{f=1;print;next} f&&/^## \[/{exit} f' plugins/quality-gates/CHANGELOG.md)
printf '%s' "$sd_sec" | grep -q 'intent_dir' || no "spec-distill 변경 기록에 새 설정 키가 없다"
printf '%s' "$sd_sec" | grep -q '옛 기록' || no "spec-distill 변경 기록이 옛 기록을 그대로 읽는다는 것을 적지 않았다"
printf '%s' "$sd_sec" | grep -q 'context-state:' || no "spec-distill 변경 기록이 판결 글자 변경을 적지 않았다"
printf '%s' "$qg_sec" | grep -q 'source_intent' || no "quality-gates 변경 기록에 source_intent 가 없다"
has plugins/spec-distill/README.md 'docs/superpowers/intent/'
has plugins/quality-gates/README.md 'source_intent,source_interview,roadmap,source_brief,type=roadmap,type=epic-bundle'
```

Run → FAIL.

- [ ] **Step 2: 고친다**
  - 두 `plugin.json` 의 `version` 을 그때 기본 브랜치의 판에서 다음 minor 로(이 PR 의 유일한 판 올림 — Global Constraints 「판」).
  - spec-distill `CHANGELOG.md` 맨 위 절: `Added`(`legacy_names.py` · 설정 키 `intent_dir` · 옛 의도 폴더의 옛 꼴 파일을 받는 경로 검사 · 로드맵 잡기 진입의 이른 경로 확인) · `Changed`(기본 폴더 `docs/superpowers/intent/` · 종류 글자 다섯 · 파일 이름 끝 · 머리 키 `source_intent` · 판결 글자 `context-state:` 와 펜스 표지 — 옛 판결 글자를 읽는 호환 없음 · 하위 명령 `state_path.py context-state` · 상태줄 칸 이름 · 스크립트 안내 낱말 · 로드맵 에픽의 「로드맵 다시 잡기」 라벨) · 「옛 기록(옛 폴더 · 옛 글자 · 옛 머리 키 · 옛 설정 키)은 옮기지 않고 그대로 읽는다」 한 줄 · `Fixed`(「an context brief」 문법). 변경 기록 연속 락(`shared/tests/test_changelog_integrity.sh`)을 지킨다.
  - quality-gates `CHANGELOG.md`: `Changed` — 의도 문서 표시의 기본 목록에 `source_intent` 를 더하고 원문 따라가기가 두 머리 키를 읽는다 · intent-critic 의 단계 낱말 · 다른 팀 기록의 「확인 못 함」 줄 글.
  - spec-distill README: 「Principles Instantiated」 의 P14 줄(의도 폴더 · 상태 파일 이름) · 흐름 그림의 산출물 줄(`intent-seed` · 폴더) · 진입 skill 목록의 `interview-seed`. quality-gates README 는 과제 8 이 했다 — 판 줄이 있으면 맞춘다.
- [ ] **Step 3: 통과를 본다** — 위 시험 · `bash shared/tests/test_changelog_integrity.sh` · `claude plugin validate plugins/spec-distill` · `claude plugin validate plugins/quality-gates`. Expected: 통과.
- [ ] **Step 4: 변이로 이빨을 본다** — (꼴 바꾸기) spec-distill 변경 기록 절 머리의 판을 다른 수로 · (지우기) qg 절의 `source_intent`. 각각 실패.
- [ ] **Step 5: 커밋** — `git commit -m "chore(spec-distill,qg): 다섯 층의 새 글자와 옛 기록 읽기를 변경 기록 · README 에 적고 판을 올린다"`.

---

### Task 12: 마무리 — AC22 대조 · AC27 · validate · 전체 스위트 · AC 보고

- [ ] **Step 1: AC22 를 견준다(계획이 적은 코드 — 무시되는 자리에 그대로 두고 `bash -n` 뒤 돈다)** — 아래 스크립트는 레포 사본(TMPDIR 아래 — 상태줄 캐시가 그 사본의 `.git` 에 쌓여 메인 레포의 캐시를 건드리지 않는다)에서 과제 1 Step 5 의 기준 커밋의 스크립트와 지금 스크립트로 기본 브랜치의 로드맵 전부에 `roadmap_status.py` 를, 끝에 `control_plane.py show` 를 돌려 견준다. 계획을 쓸 때 같은 커밋을 양쪽에 주어 `ac22: SAME (6 묶음)` 을 봤다(결정성의 양성 대조 — 2026-11-22).

```bash
#!/bin/bash
# AC22 — 이 레포의 로드맵 전부에 대한 상태 계산 출력을 바꾸기 전(BASE 커밋의 스크립트)과 지금 스크립트로 견준다.
# 쓰는 곳은 TMPDIR 아래 둘뿐이다: 레포 사본(상태줄 캐시가 사본의 .git 에 쌓인다) · 두 판의 스크립트를 푼 폴더.
# 쓰는 법: bash ac22_compare.sh <레포 루트> <BASE 커밋> <출력 폴더>
set -u
REPO="$1"; BASE="$2"; OUTD="$3"
W="$(mktemp -d "${TMPDIR:-/tmp}/ac22.XXXXXX")" || exit 2
trap 'rm -rf -- "$W"' EXIT
mkdir -p "$OUTD" || exit 2
DEF="$(git -C "$REPO" rev-parse refs/remotes/origin/HEAD 2>/dev/null || git -C "$REPO" rev-parse refs/remotes/origin/main)" || exit 2
git clone -q --no-local --no-checkout "$REPO" "$W/repo" || exit 2
git -C "$W/repo" update-ref refs/remotes/origin/main "$DEF" || exit 2
git -C "$W/repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main || exit 2
git -C "$W/repo" checkout -q --detach "$DEF" || exit 2
mkdir -p "$W/old" "$W/new"
git -C "$REPO" archive "$BASE" plugins/spec-distill shared | tar -x -C "$W/old" || exit 2
git -C "$REPO" archive HEAD plugins/spec-distill shared | tar -x -C "$W/new" || exit 2
norm() { sed -E 's/받은 시각: [0-9: -]+/받은 시각: <시각>/'; }
for side in old new; do
  SD="$W/$side/plugins/spec-distill/scripts"
  : > "$OUTD/$side.txt"
  for rm in $(git -C "$W/repo" ls-tree -r --name-only HEAD -- docs/superpowers/roadmaps | grep '/roadmap\.md$'); do
    echo "=== roadmap_status $rm" >> "$OUTD/$side.txt"
    (cd "$W/repo" && python3 "$SD/roadmap_status.py" "$rm" 2>&1; echo "rc=$?") | norm >> "$OUTD/$side.txt"
  done
  echo "=== control_plane show" >> "$OUTD/$side.txt"
  rm -f "$W/repo/.git/devbrew/control-plane.json"
  (cd "$W/repo" && python3 "$SD/control_plane.py" show 2>&1; echo "rc=$?") | norm >> "$OUTD/$side.txt"
done
if diff -u "$OUTD/old.txt" "$OUTD/new.txt" > "$OUTD/diff.txt"; then
  echo "ac22: SAME ($(grep -c '^=== ' "$OUTD/new.txt") 묶음)"
else
  echo "ac22: DIFF — $OUTD/diff.txt"
fi
```

Run: `TMPDIR=<무시되는 자리> bash <무시되는 자리>/ac22_compare.sh "$(pwd)" <과제 1 기준 커밋> <무시되는 자리>/ac22`. Expected: `ac22: DIFF` 이고 `diff.txt` 의 바뀐 줄이 지도 끝의 칸 이름 한 줄(「인터뷰: 진행 중 …」 → 「컨텍스트 쌓기: 진행 중 …」 — 설계가 정한 낱말 변경)뿐이다. 그 밖의 줄이 다르면 멈추고 보고한다. 결과(묶음 수 · 바뀐 줄)를 PR 본문 재료로 남긴다.

- [ ] **Step 2: AC27 을 본다** — `git diff --stat "$(git merge-base HEAD origin/<기본 브랜치>)" HEAD -- docs/superpowers/interview/` 가 빈 출력. 비지 않으면 멈춘다.

- [ ] **Step 3: 기본 브랜치를 다시 합친다** — 과제 1 뒤 기본 브랜치가 움직였으면 `git merge --no-ff origin/<기본 브랜치>`(충돌이면 멈춰 보고). 합친 뒤 두 플러그인의 판을 다시 견준다(Global Constraints 「판」). 옆 로드맵 E1 이 머지됐으면 `team_write.py` · `control_plane.py` 의 이 계획 편집이 살아 있는지 본다.

- [ ] **Step 4: 마지막 전체 리뷰에 AC 목록을 싣는다** — 고른 실행 방식의 마지막 전체 리뷰(SDD 의 최종 리뷰 또는 Native 의 한 번 리뷰)에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC20–AC27 · AC36 · AC40)을 글자 그대로 싣고, 리뷰가 AC 마다 한 줄씩 `AC20: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. AC36 · AC40 은 이 계획 몫만 판정한다(계획 1 · 3 · 4 몫은 「다른 계획」). AC25 는 사용자 결정 2026-11-22(설계문서 결정 기록 끝 줄 — 「이름 꼴로 가른다」: 진행 중인지는 가리지 않고 끝난 옛 기록의 옛 꼴 파일도 통과한다)에 대어 판정하게 한다 — 그 결정이 AC25 끝 문장을 다시 정했다. 리뷰에 끝에서 끝 흐름을 따로 물어라 — ① 옛 seed(옛 폴더)로 새 컨텍스트 쌓기 → 상태 파일 · 결과물 새 폴더 새 꼴 → 커밋 펜스가 다섯 파일 → 로드맵 잡기 진입(이른 경로 확인 포함) → PR 파일 세기 ② 옛 꼴 상태 파일로 이어 감 → 결과물이 옛 폴더 옛 줄기 · 새 `type:` → 리뷰 넘김 펜스의 PAYLOAD · reviewing-brief 의 `STATE` → 커밋. 과제 사이 이음매(과제 3 의 `check-path intent_dir` 와 과제 6 의 펜스 · 과제 4 의 판결 글자와 skill 글 · 과제 10 의 락과 과제 7 · 8 의 글)를 따로 물어라. 계획이 적은 테스트 · 락 코드(과제 2 · 5 · 10 · 12)는 「계획이 적은 코드」 라고 리뷰어에게 알린다. 보고를 git 이 추적하지 않는 파일에 적는다.

- [ ] **Step 5: 전체 스위트를 돈다** — Global Constraints 의 잠금 줄로, 마지막 리뷰와 그 고침 뒤에 한 번. 기본 브랜치와의 대조는 지휘자가 한다 — 실패 목록을 그대로 보고한다.

- [ ] **Step 6: 미룸을 올리고 대조를 돌린다** — 판정이 미룸 · 빠짐인 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리는 커밋을 한다(`docs(spec): …`). 설계 미룸 표의 「an context brief」 행과 「로드맵 잡기 진입이 … 일찍 보지 않는다」 행은 과제 7 · 6 이 처리했으니 그 행의 받는 곳 칸을 「계획 2 — 처리함(<커밋>)」 으로 고친다. PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md <보고 파일 경로>` 를 돌려 경고를 사용자에게 보인다.

- [ ] **Step 7: PR 본문 재료를 모은다** — 보안 리뷰 대상(과제 7 의 앞뒤 규칙 대조 — 두 플러그인) · 경로 게이트를 넓힌 편집(과제 3 — 옛 의도 폴더의 옛 꼴 이름만) · AC22 대조 결과 · AC27 빈 diff · 옆 로드맵에 알린 파일과 줄 · 계획이 정한 것(하위 명령 이름 · 두 폴더의 이어 가기 후보 · 상태줄 칸 이름 · 이른 진입 확인 · 「로드맵 다시 잡기」 라벨) · 닿는 선택 지적(과제 1 `## 닿는 선택 지적` 가운데 고친 번호와, 닿았지만 고치지 않은 번호와 그 이유 — 마지막 보고에도 같은 목록을 싣는다). push 와 PR 은 지휘자가 한다.
