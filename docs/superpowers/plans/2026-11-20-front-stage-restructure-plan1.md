# 앞단 다시 짜기 — 계획 1 (가르기와 호출 이름) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 skill 을 `context-build`(컨텍스트 쌓기)와 새 `roadmap-draft`(로드맵 잡기)로 가르고, `request-framing` 을 `intent-sync` 로, `pm-interview` 를 `context-build` 로 바꾸며, spec-distill 과 `shared/` 의 skill 글 · 펜스 · 템플릿 · README · reference · agent 정의 · 리뷰 기준의 낱말을 새 이름으로 맞춘다 — spec-distill 9.0.0.

**Architecture:** 이름만 바꾸는 커밋(폴더 옮김 · 글자 치환)을 먼저 하고, 동작을 바꾸는 커밋(검증만 하는 생성기 길 · 로드맵 잡기 진입 검사 스크립트 · 끝맺음 절차 가르기 · 커밋 펜스 고침)을 그 뒤에, 글 속 낱말 바꾸기를 마지막에 둔다. 끝맺음 절차에서 로드맵 쪽 글은 글자를 바꾸지 않고 옮기고(옮김 커밋), 바꾸는 것은 따로 커밋한다. 로드맵 잡기의 진입 판정과 번호 세기는 스크립트가 하고, 「나누기 전 확인」 은 지침 한 문단이다.

**Tech Stack:** Python 3(표준 라이브러리 · unittest) · bash 3.2 호환 셸 펜스와 셸 테스트 · git · `gh`(PR 펜스만).

**Spec:** `docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다. 설계문서 끝 `### Deferred to plan` 표의 열넷은 본문에 이미 반영돼 있다 — 그 표의 「고치면」 을 과제로 삼지 않고 본문을 따른다.

## Global Constraints

- **판.** spec-distill 을 「그때 기본 브랜치의 판」 에서 9.0.0 으로 한 번 올린다(설계 2 「판」). 판 숫자는 머지 직전 기본 브랜치 위에서 정한다 — 같은 판으로 올린 `plugin.json` 은 조용히 합쳐지므로 `git diff origin/<기본 브랜치> -- plugins/spec-distill/.claude-plugin/plugin.json` 으로 견준다.
- **호출 이름.** `request-framing` → `intent-sync`, `pm-interview` → `context-build`, 새 진입 skill `roadmap-draft`. 별칭 없음. 옛 이름의 글자는 `plugins/spec-distill/CHANGELOG.md` 의 `Removed` 와 옛 이름 금지 검사 자기 파일 둘(`shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh`)과 테스트 픽스처 폴더에만 남는다. 옛 이름이 없음을 무는 새 테스트는 그 이름을 글자로 품지 않게 쓴다(`"request-" + "framing"` 처럼 이어 붙인다). 검사의 제외 목록은 넓히지 않는다.
- **이 계획이 바꾸지 않는 것(계획 2 몫).** 설정 키 `interview_dir` · 폴더 `docs/superpowers/interview/` · 머리 키 `source_interview` · 종류 글자(`interview-seed` · `interview-seed-audit` · `interview-state` · `interview-brief` · `interview-audit`) · 파일 이름 끝(`-interview.md` · `-interview.state.md` · `.audit.md`) · 스크립트가 내는 판결 글자(`interview-state:` · `raw-source:`) · 스크립트가 내는 안내와 상태줄 칸 이름의 낱말 · quality-gates 의 글. 스크립트 · 템플릿 파일 · agent · `reviewing-brief` 의 이름, `seed` · `brief` 낱말도 그대로다(설계 Non-goals).
- **낱말 대응(설계 2 「글 속의 낱말」 — 이 계획의 범위: spec-distill 과 `shared/` 의 skill 글 · 펜스 안 · 템플릿 · README · reference · agent 정의 · 리뷰 기준).**
  - 한글 「인터뷰」 가 단계를 가리키면 그 단계 이름 — 조사 · 결과물 쪽이면 「컨텍스트 쌓기」, 분해 · 로드맵 쪽이면 「로드맵 잡기」. 「인터뷰 폴더」 → 「의도 폴더」(`intent_dir` 의 폴더만 가리킨다 — 로드맵 폴더 아래 `intent/` 는 「로드맵의 원자료 폴더」).
  - 영어 `interview brief` → `context brief`.
  - 커밋 제목 `docs(interview): …` → 컨텍스트 쌓기는 `docs(context): …`, 로드맵 잡기는 `docs(roadmap): …`.
  - 펜스 표지와 펜스가 내는 판결 글자: `interview-commit` → `context-commit` · `interview-pr` → `roadmap-pr` · `interview-pr-files` → `roadmap-pr-files` · `interview-pr-head` → `roadmap-pr-head` · `interview-merge` → `roadmap-merge` · `interview-merge-recheck` → `roadmap-merge-recheck` · `interview-merge-requested` → `roadmap-merge-requested`. 새 펜스 표지는 `roadmap-commit`. 옛 판결 글자를 읽는 호환은 두지 않는다.
  - 그대로: `seed` · `brief`, 「옛 인터뷰 기록」 · 「옛 인터뷰 폴더」, 옛 설정 키를 알리는 안내 속 `interview_dir`, 변경 기록과 기록 폴더(`docs/superpowers/` 아래), 쉬운 말 규칙 블록(`<!-- plain-language:begin -->` ~ `end`), `CLAUDE.md`.
- **쉬운 말 규칙 블록**은 고치지 않는다 — 새 skill 은 `shared/style/plain-language.md` 의 블록을 그대로 싣는다.
- **진입 skill 꼴.** kebab 두 단어 이상 · 폴더 이름 = `name` · frontmatter `metadata:` 아래 `cost_class:` · `allowed-tools:` 는 사전 검사 한 항목만(`python3 shared/entry/check_invocation_surface.py --print-head spec-distill roadmap-draft` 가 내는 머리 그대로) · `## 진입 단계` 첫 문단에 F7 의 문장 「감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다.」 와 「이 절이 다른 모든 절보다 먼저 돈다.」. 새 command 파일은 만들지 않는다.
- **비용 등급.** `context-build` · `intent-sync` 는 지금 값(`variable`) 그대로, `roadmap-draft` 는 `medium`.
- **줄 수.** `context-build` 본문(`skills/context-build/SKILL.md`)은 자기 줄 수 상한 604(`test_conducting_interview_stage.sh`)를 그대로 지킨다. AC37: 가른 뒤 각 단계의 「본문 + 끝맺음 절차에서 온 글이 든 파일」 줄 수가 가르기 전 「인터뷰 본문 + 끝맺음 절차」 줄 수를 넘지 않고, `intent-sync` 본문이 가르기 전 `request-framing` 본문을 넘지 않는다.
- **보안 리뷰 묶음.** `agents/*.md`(spec-distill · `shared/docreview/agents/`)와 `references/docreview-profiles/*.md` 의 편집은 이 계획 안에서 한 커밋(과제 3)에만 있다. 규칙을 지우거나 느슨하게 하지 않는다. PR 본문이 보안 리뷰 대상임을 밝힌다(AC36).
- **경로 게이트.** 커밋 · PR 펜스의 경로 검사(`repo_defaults.py check-path` · `state_path.py path-inside`)는 넓히지 않는다 — 옮겨 쓸 뿐이다.
- **편집 자리 찾기.** 기본 브랜치가 이 계획을 쓴 뒤에도 움직인다(옆 로드맵의 PR 이 열려 있다). 과제의 편집 자리는 줄 번호가 아니라 그때 grep 해서 찾는 글자로 적었다. 이름 · 낱말을 바꾸는 과제는 바꾸기 직전에 대상 목록을 다시 낸다.
- **셸.** 새 셸 테스트와 펜스는 macOS `/bin/bash` 3.2 에서 돈다 — `$var` 바로 뒤에 한글 글자가 오면 `${var}` 로 쓴다. 새 셸 테스트는 `chmod +x` 하고 `git ls-files -s` 로 100755 를 확인한다. Python 은 `encoding="utf-8"` 를 명시하고 `python3` 리터럴로 부른다. 변이 시험 전에는 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 빈지 본다. Python 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.
- **전체 스위트**는 이 줄로만 돌린다(공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다):
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <실행자 이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`
  SDD 구현자에게는 전체 스위트를 맡기지 않는다 — 과제마다 그 과제의 테스트만 돌리고, 전체 스위트는 과제 14 에서 한 번 돈다.

## 옆 로드맵이 예약한 파일 — 이 계획이 고치는 것

옆 로드맵(`docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`)의 경로 예약과 겹친다. 과제 1 이 그때의 예약을 다시 읽어 이 목록을 고친다. 고치는 과제가 시작하기 전에 지휘자에게 파일과 고칠 줄(grep 글자)을 보고하고, 먼저 머지된 쪽 위에서 쓴다.

| 파일 | 예약한 에픽(2026-11-20 기본 브랜치 7177a5bb 기준) | 이 계획이 고치는 것 | 과제 |
|---|---|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | R2 | 코드 앵커 한 줄의 skill 경로(`skills/pm-interview/SKILL.md`) | 2 |
| `plugins/spec-distill/references/proceed-gate.md` | R2 | 옛 호출 이름 · 「인터뷰」 낱말 | 2 · 12 |
| `plugins/spec-distill/references/conducting.md` | R2 · R3 · E2 | 「인터뷰」 낱말 | 12 |
| `plugins/spec-distill/references/team-files.md` | R1 · R2 · R3 · E1 | 「인터뷰」 낱말 | 12 |
| `plugins/spec-distill/references/roadmap-ontology.md` | R1 | 「인터뷰」 낱말 | 12 |
| `plugins/spec-distill/references/epic-handoff.md` | R1 | 「인터뷰」 낱말 | 12 |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | (옆 PR 이 고친다 — 지휘자 알림) | 옛 호출 이름 · 「인터뷰」 낱말 | 2 · 12 |
| `plugins/spec-distill/scripts/roadmap_write.py` | R1 | 새 하위 명령 `check` | 5 |
| `plugins/spec-distill/dependencies.md` | R2 · E3 · R4 | 진입 skill 행 · 「인터뷰」 낱말 | 7 · 12 |
| `plugins/spec-distill/README.md` | R4 · E3 | 호출 이름 · 진입 skill 수 · 낱말 · 9.0.0 줄 | 2 · 7 · 12 · 13 |
| `plugins/spec-distill/CHANGELOG.md` | R5 | 9.0.0 절 | 13 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | (모든 PR) | 판 | 13 |
| `plugins/spec-distill/skills/roadmap-draft/` (새 폴더) | — (E1 이 새 형식을 켜는 자리로 받는다 — 그쪽 예약에 더할 것을 알린다) | 새 skill | 7 · 8 |

## Review Focus

1. **옛 흐름 도중에 끊긴 인터뷰** — 상태 파일에 승인된 `## 분해안` 이 이미 있는 채로 새 판의 `context-build` 를 끝내고 `roadmap-draft` 를 부르면, 진입이 그 표가 있다는 것을 보이고 「그 표에서 이어 간다 · 표를 버리고 처음부터」 를 묻는다(설계 남는 한계). 시험: 과제 6 `test_resume_on_approved_table`.
2. **상태 파일의 다른 절이 커밋 뒤에 바뀐 채 `roadmap-draft` 를 부름** — 진입이 멈추고 바뀐 절 이름을 댄다. `## 분해안` · `## 생성 기록` 만 바뀌었으면 멈추지 않는다. 시험: 과제 6 `test_state_changed_outside_two_sections_stops` · `test_state_changed_inside_two_sections_ok`.
3. **결과물 경로를 상대 경로 · 다른 작업 폴더에서 줌** — 진입 스크립트가 git 뿌리를 결과물 경로에서 구해 같은 판정을 낸다. 시험: 과제 6 `test_relative_brief_path_from_subdir`.
4. **기본 브랜치 위에서 「나눈다」 로 끝남** — 커밋 펜스가 커밋하지 않고, 손으로 커밋할 목록(결과물 · audit · 상태 파일 · 알 때는 framing 기록 · seed)과 함께 로드맵 잡기 줄을 내고 「커밋한 뒤 입력하라」 고 알린다. 시험: 과제 10 `default_branch_lists_raw_and_seed`.
5. **커밋 전 검사를 거치지 않은 옛 결과물** — 위험 줄 번호가 섞였거나 겹친 결과물로 `roadmap-draft` 를 부르면 표를 짜기 전에 멈추고 결과물을 고치지 않으며 사용자가 고를 길 둘(「spec 하나로」 · 그 결과물로 새 `context-build`)을 보인다. 시험: 과제 6 `test_brief_risk_defect_stops`.

## 과제 지도

| # | 과제 | 커밋 성격 | AC |
|---|---|---|---|
| 1 | 다시 확인 — 기본 브랜치 합치기 · 근거 대조 · 전수 목록 · 기준 줄 수 | 합치기 커밋만 | 선행 · AC37 기준 |
| 2 | 호출 이름 바꾸기 — 폴더 옮김과 글자 치환 | 이름만 | AC1(앞 절반) |
| 3 | agent 정의와 리뷰 기준 — 이름과 낱말(보안 리뷰 묶음) | 이름 · 낱말 | AC36 · AC40(일부) |
| 4 | 옛 호출 이름 금지 | 동작(검사) | AC2 |
| 5 | 생성기의 「검증만」 길 — `roadmap_write.py check` | 동작 | AC8 · AC39 기반 |
| 6 | 로드맵 잡기 진입 검사 — `roadmap_draft_entry.py` | 동작 | AC6 · AC7 · AC11(멈춤) |
| 7 | `roadmap-draft` skill — 진입 · 읽기 · 확인 · 표 · 승인 · 생성 · 커밋 · 되돌아가기 | 옮김 + 동작 | AC1 · AC6–AC14 · AC19(수) |
| 8 | PR 과 머지 · 지휘자 줄을 `roadmap-draft` 로 | 옮김 + 동작 | AC10 |
| 9 | `context-build` 다듬기 — 질문 하나 · 위험 번호 커밋 전 검사 · 커밋 범위 · 끝 줄 · 소개 문구 · 상태 파일 자리 | 동작 | AC3 · AC4 · AC5 · AC12 · AC15 · AC39 |
| 10 | 커밋 펜스의 거절 갈래와 원자료 싣기 펜스 | 동작 | AC16 · AC17 |
| 11 | 상태 보기가 로드맵 없는 「나눈다」 결과물에서 돈다 | 시험 | AC18 |
| 12 | 글 속 낱말 바꾸기(이 계획 몫) | 낱말 | AC40 |
| 13 | 판 · 변경 기록 · README · 표 | 판 | AC19 |
| 14 | 마무리 — 줄 수 대조 · validate · 전체 스위트 · AC 보고 | 확인 | AC37 · 전부 |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 다르면 멈춰 지휘자에게 보고한다. 산출물은 git 이 무시하는 자리의 메모 파일 하나다 — 작업 트리 안에서 `git check-ignore -q <경로>` 가 0 인 자리(예: `.claude/tmp/f5-plan1/recheck.md`)를 쓴다.

**Files:**
- Create(추적 안 함): `<무시되는 자리>/recheck.md`
- Modify: (합치기 커밋만)

**Interfaces:**
- Produces: `recheck.md` 의 절 — `## 옛 호출 이름 전수` · `## 낱말 전수` · `## finishing.md 를 읽는 테스트` · `## 옆 로드맵 예약` · `## shared 를 싣는 플러그인` · `## 제3자 설치` · `## 기준 줄 수` · `## 근거 대조`. 과제 2 · 3 · 7 · 12 · 14 가 읽는다.

- [ ] **Step 1: 기본 브랜치를 합친다**

`git fetch origin` 뒤 `git merge --no-ff origin/<기본 브랜치>`(기본 브랜치 이름은 `python3 plugins/spec-distill/scripts/repo_defaults.py default-branch --root .` 이 낸다). 충돌이 나면 `git merge --abort` 하고 멈춰 보고한다. 커밋 메시지: `chore(merge): 기본 브랜치를 F5 브랜치에 합친다` + 끝 줄들.

- [ ] **Step 2: 설계문서의 근거를 다시 연다**

아래를 지금 글에서 확인하고 「같다 / 다르다 — 무엇이」 를 `## 근거 대조` 에 한 줄씩 적는다. 하나라도 계획의 과제를 바꿀 만큼 다르면 멈춘다.
- `shared/entry/check_invocation_surface.py` 의 `ENTRY_SKILLS` 가 아홉이고 `OLD_NAME_RE` 에 두 옛 이름이 없다.
- `shared/tests/test_switch_tables.sh` 가 사전 검사 줄이 있는 진입 skill 을 아홉으로 묻는다(`len(entries) == 9`).
- `skills/pm-interview/SKILL.md` 가 604 줄 이하이고 `test_conducting_interview_stage.sh` 의 상한이 604 다.
- `skills/pm-interview/references/finishing.md` 에 `### 분해 판단 — Step A 직전` · `### Step A` 의 「8.」 생성 걸음(`roadmap_write.py" create`) · `#### B-R — 로드맵 다시 생성` · `**PR 과 머지 — 분해된 일 ①/② 만.**` · 표지 `interview-commit` · `interview-pr` · `interview-merge` · `interview-merge-recheck` 가 있다.
- `roadmap_write.py` 에 검증만 하는 하위 명령이 없다(하위 명령: create · extract · migrate · update · original · job).
- `raw_source.py locate --interview` 가 `raw-source: FOUND|LOST|NO-FRAMING` 을 낸다.
- `check_brief.py` 의 `payload_is_split` · `skip_split_failures`(「나눈 일은 건너뛸 수 없다」)가 있다.
- `quality-gates/scripts/intent_origin.py` 가 `source_interview` 를 읽는다(계획 2 몫 — 있는지만).
- `decompose_edits` 가 상태 파일 스키마(`skills/pm-interview/SKILL.md` 의 `## State location` yaml)에 없다.
- `roadmap_status.py` · `control_plane.py` 가 결과물 §7 을 읽지 않는다(`grep -n '분해됨' plugins/spec-distill/scripts/*.py` 가 `check_brief.py` 밖에서 0건).

- [ ] **Step 3: 전수 목록을 낸다**

- `## 옛 호출 이름 전수`: `git grep -l -e 'pm-interview' -e 'request-framing' -- plugins shared docs/philosophy docs/git-workflow tools .claude-plugin README.md` 에서 `CHANGELOG.md` 를 뺀 목록과 경로 이름에 옛 이름이 든 파일(`git ls-files | grep -e pm-interview -e request-framing`). 2026-11-20 의 기본 브랜치에서 119개(변경 기록 포함)였다.
- `## 낱말 전수`: 이 계획 범위의 파일(`plugins/spec-distill/{skills,references,templates,agents}/` · `plugins/spec-distill/{README.md,switches.md,dependencies.md}` · `shared/` 의 `tests/` 밖)에서 과제 12 의 금지 토큰(과제 12 Step 1 의 목록)이 든 파일과 줄 수.
- `## finishing.md 를 읽는 테스트`: `git grep -l -e 'finishing' -e 'pm-interview/references' -e '"-interview/references' -- plugins/*/tests shared/tests tools` 와 `# guards:` 머리에 finishing.md 가 든 테스트.

- [ ] **Step 4: 옆 로드맵 예약을 다시 읽는다**

그때의 `docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`(기본 브랜치 쪽)를 읽어 남은 에픽의 `경로 예약:` 과 이 계획이 고치는 파일의 교집합을 낸다. 위 「옆 로드맵이 예약한 파일」 표와 다르면 표를 고치는 커밋(`docs(plan): …`)을 하고 지휘자에게 보고한다. 빠지는 에픽(R4 등)은 그때의 파일대로 따른다.

- [ ] **Step 5: `shared/` 를 싣는 플러그인과 제3자 설치를 확인한다**

- 이 계획이 고칠 `shared/` 파일(`shared/docreview/references/reviewing-document.md` · `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `shared/docreview/scripts/docreview_state.py` · `shared/entry/check_invocation_surface.py`)마다 심볼릭 링크로 싣는 플러그인을 `git ls-files -s plugins | awk '$1=="120000"'` 과 `readlink` 로 낸다. 2026-11-20 에는 `docreview_state.py` 를 spec-distill 과 quality-gates 가 싣고, `reviewing-document.md` 는 spec-distill 만 싣고, `check_invocation_surface.py` 와 `shared/docreview/agents/` 는 어느 플러그인도 링크로 싣지 않았다(spec-distill 의 `agents/doc-critic*.md` 는 따로 된 사본이다 — 사본 대조 락이 있으면 과제 3 이 둘을 함께 고친다).
- quality-gates 가 싣는 파일의 이 계획 변경은 주석뿐이다 — quality-gates 판을 올리지 않고 그 이유를 PR 본문에 적는다(레포 규칙의 「동작에 닿지 않는 변경」).
- 제3자 설치: `gh issue list --state all --limit 200 --json author` 에 레포 주인 밖의 작성자가 있는지 · 설치 보고 · 마켓플레이스 공개 등록이 있는지 본다. 하나라도 있으면 「호출 이름 변경을 별칭 없이 바로 하는 예외」 가 없어지므로 멈추고 보고한다.

- [ ] **Step 6: 기준 줄 수를 잰다(AC37)**

합친 뒤의 글에서 `wc -l` 로 잰다: `skills/request-framing/SKILL.md`(가르기 전 의도 싱크 기준), `skills/pm-interview/SKILL.md` + `skills/pm-interview/references/finishing.md`(가르기 전 인터뷰 기준 — 다른 reference 는 세지 않는다). `## 기준 줄 수` 에 적는다 — 과제 9 의 락 상수가 된다.

---

### Task 2: 호출 이름 바꾸기 — 폴더 옮김과 글자 치환 (이름만 · AC1)

**Files:**
- Move: `plugins/spec-distill/skills/request-framing/` → `plugins/spec-distill/skills/intent-sync/` · `plugins/spec-distill/skills/pm-interview/` → `plugins/spec-distill/skills/context-build/`(`git mv`)
- Modify: `recheck.md` 의 `## 옛 호출 이름 전수` 가운데 **agent 정의(`plugins/spec-distill/agents/` · `shared/docreview/agents/`)와 리뷰 기준(`references/docreview-profiles/`)을 뺀** 모든 파일 · `shared/entry/check_invocation_surface.py`(`ENTRY_SKILLS` 의 두 항목만) · `shared/tests/test_invocation_surface.sh`(등록 목록 `ENTRY` 의 두 항목과 이름이 박힌 변이) · `docs/philosophy/devbrew-harness-philosophy.md`(코드 앵커 한 줄) · `plugins/spec-distill/README.md`

**Interfaces:**
- Produces: skill 경로 `plugins/spec-distill/skills/intent-sync/SKILL.md` · `plugins/spec-distill/skills/context-build/SKILL.md` · `plugins/spec-distill/skills/context-build/references/finishing.md`(파일 이름 그대로) — 뒤 과제가 이 경로를 쓴다.

- [ ] **Step 1: 대상 목록을 다시 낸다** — Task 1 Step 3 의 명령을 지금 다시 돌린다.

- [ ] **Step 2: 지휘자에게 알린다** — 철학 문서 코드 앵커 한 줄(R2 예약)과 `references/proceed-gate.md` · `skills/spec-review/SKILL.md` 의 옛 이름 줄을 고친다고 보고한다.

- [ ] **Step 3: 폴더를 옮기고 글자를 바꾼다**

`git mv` 두 번. 그 뒤 목록의 파일에서 `request-framing` → `intent-sync`, `pm-interview` → `context-build` 를 글자 그대로 바꾼다(경로 조각 `skills/pm-interview/` · 완전명 `/spec-distill:pm-interview` · 맨 이름 · 사전 검사 인자 `spec-distill pm-interview` · 셸 `case` 키 `spec-distill/pm-interview` 포함). 다음은 바꾸지 않는다:
- `CHANGELOG.md`, `docs/superpowers/` 아래(기록), `tests/fixtures/` 아래.
- `shared/entry/check_invocation_surface.py` 의 `OLD_NAME_RE` 안 `commands/(?:interview|request-framing|…)\.md`(옛 명령 파일 경로다).
- `shared/tests/test_invocation_surface.sh` 의 변이 `i_sp`(옛 `spec-interview` 경로) · `i_pm` — `i_pm` 은 과제 4 가 뒤집는다. 등록 목록 `ENTRY` 와 변이 `c3` · `real g` · `real pm` 의 이름은 새 이름으로 바꾼다.
- 테스트의 이어 붙인 옛 경로(`test_review_hook_removed.py` 의 `"conducting" "-interview/…"` 처럼 이미 쪼갠 글자).

README 는 이 커밋에서 옛 이름을 새 이름으로만 바꾼다(9.0.0 줄은 과제 13).

- [ ] **Step 4: 이름 커밋이 동작을 바꾸지 않았는지 잰다**

Run:
```
python3 shared/entry/check_invocation_surface.py
bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh
bash plugins/spec-distill/tests/test_finish_pr_merge.sh
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
bash shared/tests/test_invocation_surface.sh
bash shared/tests/test_switch_tables.sh
bash shared/tests/test_entry_dep_needs.sh
bash shared/tests/test_skill_cost_class_place.sh
```
Expected: 모두 통과. 펜스를 뽑아 돌리는 테스트(앞의 둘)는 기대값의 이름 글자만 바뀐 채 통과한다. `git diff --stat HEAD` 에서 skill 글 · 펜스의 바뀐 줄이 모두 이름 글자 줄인지 `git diff HEAD -U0 | grep '^[-+]' | grep -v -e intent-sync -e context-build -e request-framing -e pm-interview | grep -v '^[-+][-+]'` 가 빈 것으로 본다.

- [ ] **Step 5: `# guards:` 머리가 실재 경로만 가리키는지 본다**

`git grep -h '^# guards:' -- '*.sh' '*.py' | tr ' ' '\n' | grep '/' | sort -u` 의 각 경로(글롭 포함)가 `git ls-files -- <경로>` 로 하나 이상 풀린다. 안 풀리는 것이 0 이어야 한다.

- [ ] **Step 6: 커밋**

```
git add -A -- plugins/spec-distill shared tools plugins/quality-gates/tests docs/philosophy/devbrew-harness-philosophy.md
git commit -m "refactor(spec-distill): 호출 이름 둘을 intent-sync · context-build 로 바꾼다 (이름만)" …
```
`git add -A` 는 pathspec 안에서만 쓴다 — 실행 전 `git status --short` 로 pathspec 밖 변경이 없는지 본다.

---

### Task 3: agent 정의와 리뷰 기준 — 이름과 낱말 (보안 리뷰 묶음 · AC36 · AC40)

이 계획에서 agent 정의와 리뷰 기준을 고치는 커밋은 이것 하나다(AC36).

**Files:**
- Modify: `plugins/spec-distill/agents/*.md` 가운데 옛 호출 이름이나 과제 12 의 금지 토큰이 든 것(2026-11-20: brief-readback · blind-spot-prober · doc-critic · coverage-mapper · seed-readback · steelman-builder · doc-critic-web · open-researcher · repo-researcher · saturation-judge) · `shared/docreview/agents/doc-critic.md` · `doc-critic-web.md` · `plugins/spec-distill/references/docreview-profiles/*.md` 가운데 같은 것(2026-11-20: `brief.md`)

- [ ] **Step 1: 대상 목록을 다시 낸다** — `git grep -l -e pm-interview -e request-framing -e '인터뷰' -e 'interview brief' -- plugins/spec-distill/agents shared/docreview/agents plugins/spec-distill/references/docreview-profiles`.

- [ ] **Step 2: 고치기 전 규칙 목록을 뜬다**

각 파일의 frontmatter `tools:` 줄 · 「하지 않는다 / must not / never / 금지」 가 든 줄 · 수치 임계 줄을 `git show HEAD:<파일>` 에서 뽑아 무시되는 자리의 `rules-before.txt` 에 적는다.

- [ ] **Step 3: 이름과 낱말을 바꾼다** — Global Constraints 의 「호출 이름」 과 「낱말 대응」 대로. 영어 문장 속 맨 낱말 `interview`(예: 「during a spec-distill interview」)는 설계 2 의 표에 없어 그대로 둔다. 문장의 뜻 · 지시 · 임계는 바꾸지 않는다. 두 사본(`plugins/spec-distill/agents/doc-critic*.md` 와 `shared/docreview/agents/doc-critic*.md`)은 같은 글로 고친다.

- [ ] **Step 4: 앞뒤 규칙을 견준다**

Step 2 와 같은 방법으로 `rules-after.txt` 를 뜨고 `diff rules-before.txt rules-after.txt` 를 본다. 바뀐 줄은 이름 · 낱말 글자뿐이어야 하고 `tools:` 줄은 같아야 한다. 결과를 PR 본문 「보안 리뷰 대상」 절에 붙일 수 있게 무시되는 자리에 남긴다.

- [ ] **Step 5: 시험** — `bash shared/tests/test_copy_of_contract.sh` · `bash shared/tests/test_docreview_agents.sh` · `bash plugins/spec-distill/tests/test_research_agents_frontmatter.sh` · `python3 shared/entry/check_invocation_surface.py`. Expected: 통과.

- [ ] **Step 6: 커밋** — `git add <바꾼 파일들>` · `git commit -m "docs(spec-distill): agent 정의와 리뷰 기준의 호출 이름 · 단계 낱말을 새 이름으로 (보안 리뷰 대상)"`.

---

### Task 4: 옛 호출 이름 금지 (AC2)

**Files:**
- Modify: `shared/entry/check_invocation_surface.py`(`OLD_NAME_RE`) · `shared/tests/test_invocation_surface.sh`

**Interfaces:**
- Consumes: 과제 2 · 3 뒤 살아 있는 표면에 옛 이름이 0건.

- [ ] **Step 1: 실패하는 시험을 더한다(계획이 적은 코드)**

`shared/tests/test_invocation_surface.sh` 에서:
- 변이 `i_pm` 을 뒤집는다 — 지금은 「옛 이름이 아니다」 를 기대한다. 새 기대: `plugins/spec-distill/scripts/q.py` 의 `# /spec-distill:pm-interview` 는 `expect_red … I "…" "옛 이름 'pm-interview'"`, 같은 꼴로 `request-framing` 하나. `docs/superpowers/interview/x.md` · `spec-distill:interview-x` 는 계속 옛 이름이 아니다(따로 된 GREEN 변이로 남긴다).
- 새 변이 넷(살아 있는 표면의 자리마다 하나 — 축은 「자리」): `plugins/spec-distill/references/x.md` 에 `skills/request-framing/SKILL.md` · `plugins/spec-distill/templates/x.md` 에 `/spec-distill:pm-interview @x` · `plugins/spec-distill/README.md` 에 `` `pm-interview` `` · `docs/philosophy/x.md` 에 `request-framing` — 모두 `expect_red … I`.
- 새 GREEN 변이 셋(제외 자리 — 「제외」 축): `plugins/spec-distill/CHANGELOG.md` 에 `pm-interview` · `plugins/spec-distill/tests/fixtures/x.md` 에 `request-framing` · `docs/superpowers/specs/x.md` 에 `pm-interview` — 모두 GREEN.
- 경계 변이 둘(「낱말 경계」 축): `pm-interviewer`(뒤에 이름 글자) · `xpm-interview` 는 잡지 않는다 — GREEN.

Run: `bash shared/tests/test_invocation_surface.sh` → Expected: 새 RED 기대 변이 다섯이 FAIL(아직 잡지 않는다).

- [ ] **Step 2: `OLD_NAME_RE` 에 두 이름을 더한다** — 앞뒤에 `[-A-Za-z0-9_]` 가 붙지 않을 때만 맞게 한다(예: `(?<![-A-Za-z0-9_])(?:request-framing|pm-interview)(?![-A-Za-z0-9_])`). 기존 `commands/(?:…request-framing…)\.md` 대안은 그대로 둔다.

- [ ] **Step 3: 통과를 본다** — `bash shared/tests/test_invocation_surface.sh` 와 `python3 shared/entry/check_invocation_surface.py`. Expected: 둘 다 GREEN.

- [ ] **Step 4: 변이로 이빨을 본다** — 커밋 뒤에(복원은 `git checkout HEAD --`) 각각 돌려 시험이 RED 로 바뀌는지 본다: (지우기) 더한 대안을 지운다 · (더하기) 앞쪽 lookbehind 를 지워 `xpm-interview` 경계 변이가 RED 가 되는지 · (뒤집기) `axis_i` 의 `CHANGELOG.md` 제외 조건을 `!=` 로 바꿔 제외 GREEN 변이가 깨지는지 · (꼴 바꾸기) 대안을 `pm_interview` 로 바꾼다. 넷 모두 시험이 실패해야 하고 원본에서 통과해야 한다(양성 대조).

- [ ] **Step 5: 커밋** — `git commit -m "test(shared): 옛 호출 이름 둘이 살아 있는 표면에 다시 들어오면 호출 표면 검사가 실패한다"`.

---

### Task 5: 생성기의 「검증만」 길 — `roadmap_write.py check` (AC8 · AC39)

로드맵 잡기가 승인 질문 전에 미배정 번호 · 고아 발화 수를 스크립트로 내고(AC8), 컨텍스트 쌓기가 커밋 전에 위험 줄 번호를 잰다(AC39). 지금 생성기에는 파일을 쓰지 않는 검증 길이 없다.

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_write.py`(새 하위 명령 `check` — 기존 하위 명령은 건드리지 않는다)
- Create: `plugins/spec-distill/tests/test_roadmap_write_check.py`

**Interfaces:**
- Consumes: `roadmap_model.brief_section(brief, "5")` · `roadmap_model.brief_risk_numbers(s5)` · `roadmap_model.brief_universe(brief, audit)` · `roadmap_render.parse_table(text)` · `Row.ids`.
- Produces: 명령 `python3 roadmap_write.py check --brief <brief> --audit <audit> [--plan-table <상태 파일>]`.
  - 늘 첫 줄: `brief-risk: OK` 또는 `brief-risk: FAIL <사유>`(사유는 `FormatError` 글자 그대로).
  - `--plan-table` 이 있으면 둘째 줄: `roadmap-table: OK 미배정 0 · 고아 0 · 모르는 번호 0` 또는 `roadmap-table: FAIL 미배정 <n> · 고아 <n> · 모르는 번호 <n>`, 그 아래 비지 않은 목록마다 `  미배정: <번호 · …>` · `  고아: …` · `  모르는 번호: …`. 표를 못 읽거나 번호를 셀 수 없으면 `roadmap-table: UNKNOWN <사유>`.
  - rc: 모두 OK 면 0 · FAIL/UNKNOWN 이 하나라도 있으면 1 · 인자 오류 2. 파일을 쓰지 않는다.
  - 함수 `check_counts(brief: str, audit: str, table_text: str) -> dict` — 키 `unassigned` · `orphans` · `unknown_ids`(정렬된 목록 — `roadmap_status` 와 같은 정렬 `id_sort_key`). 집합 셈은 `roadmap_status.py` 와 같다: `union = ⋃ row.ids`, `unassigned = non_s - union`, `orphans = s_ids - union`, `unknown_ids = union - non_s - s_ids`.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — 픽스처는 `test_roadmap_write.sh` 의 임시 저장소 만들기를 빌리거나 `tests/fixtures/` 의 brief 짝을 쓴다)**

```python
class Check(unittest.TestCase):
    def test_risk_ok_and_table_ok(self):            # 모든 번호를 배정한 표
        rc, out = run_check(brief, audit, table_all)
        self.assertEqual(rc, 0)
        self.assertEqual(out.splitlines()[0], "brief-risk: OK")
        self.assertEqual(out.splitlines()[1], "roadmap-table: OK 미배정 0 · 고아 0 · 모르는 번호 0")
    def test_unassigned_and_orphan_counted(self):    # 결정 번호 하나 · S 하나를 빼고 없는 번호 하나를 넣은 표
        rc, out = run_check(brief, audit, table_missing)
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-table: FAIL 미배정 1 · 고아 1 · 모르는 번호 1", out)
        self.assertIn("  미배정: ", out); self.assertIn("  고아: S", out)
    def test_risk_mixed_numbers_fail(self):          # K 가 박힌 줄과 안 박힌 줄이 섞인 §5
        rc, out = run_check(brief_mixed_k, audit, None)
        self.assertEqual(rc, 1)
        self.assertTrue(out.startswith("brief-risk: FAIL brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다"))
    def test_risk_duplicate_fail(self):              # K2 가 둘
        rc, out = run_check(brief_dup_k, audit, None)
        self.assertIn("brief-risk: FAIL brief §5 위험 줄의 K 번호가 겹친다: K2", out)
    def test_no_table_prints_only_risk_line(self):
        rc, out = run_check(brief, audit, None)
        self.assertEqual(out.strip().splitlines(), ["brief-risk: OK"])
    def test_writes_nothing(self):                   # 실행 전후 임시 폴더의 파일 목록과 내용 해시가 같다
        ...
    def test_counts_match_roadmap_status_after_create(self):  # 같은 입력으로 create 뒤 roadmap_status --json 의 세 목록과 check_counts 가 같다
        ...
    def test_unreadable_table_unknown(self):         # `## 분해안` 절이 없는 상태 파일
        rc, out = run_check(brief, audit, state_without_table)
        self.assertEqual(rc, 1); self.assertIn("roadmap-table: UNKNOWN `## 분해안` 절이 없다", out)
```

Run: `python3 plugins/spec-distill/tests/test_roadmap_write_check.py` → Expected: FAIL(`check` 하위 명령이 없다 — argparse rc 2).

- [ ] **Step 2: `cmd_check(a) -> int` 와 `check_counts` 를 `roadmap_write.py` 에 더한다** — 파서에 `check` 를 더하고 `COMMANDS` 에 잇는다. 파일을 쓰는 함수(`Txn` 등)를 부르지 않는다.

- [ ] **Step 3: 통과를 본다** — 같은 명령 → PASS. 기존 `test_roadmap_write.py` · `test_roadmap_write.sh` · `test_roadmap_write_atomic.py` 도 통과.

- [ ] **Step 4: 변이로 이빨을 본다** — 커밋 뒤: (지우기) `orphans` 셈을 지운다 · (더하기) `union` 에 `s_ids` 를 더한다 · (뒤집기) rc 판정을 `any` → `all` 이 아니라 FAIL 일 때 0 을 내게 바꾼다 · (꼴 바꾸기) 첫 줄 접두를 `brief-risk:OK` 로 바꾼다. 각각 시험이 실패해야 한다.

- [ ] **Step 5: 커밋** — `git commit -m "feat(spec-distill): 생성기에 파일을 쓰지 않는 검증 길(check)을 더한다"`.

---

### Task 6: 로드맵 잡기 진입 검사 — `roadmap_draft_entry.py` (AC6 · AC7 · AC11)

진입 판정은 결정론이어야 해서 스크립트로 둔다(설계 1 「로드맵 잡기」 걸음 1 · 2). 「나누기 전 확인」 은 스크립트로 만들지 않는다.

**Files:**
- Create: `plugins/spec-distill/scripts/roadmap_draft_entry.py` · `plugins/spec-distill/tests/test_roadmap_draft_entry.py`

**Interfaces:**
- Consumes: `check_brief.payload_is_split`(§7 판독 — 같은 판독기를 import 해 쓴다) · `raw_source.py locate --interview <brief> --absolute`(하위 프로세스) · `roadmap_write.py check --brief --audit`(하위 프로세스 — 위험 줄 검사) · `repo_defaults.py default-branch --root <top>`.
- Produces: `python3 roadmap_draft_entry.py --brief <brief 경로>`. 출력(차례대로, 각 한 줄):
  1. `raw-source: FOUND <경로>` · `raw-source: LOST <사유>` · `raw-source: NO-FRAMING` 가운데 하나(`raw_source.py` 의 줄 그대로).
  2. 멈출 사유마다 `roadmap-entry: STOP <사유>` — 모든 사유를 다 낸다.
  3. 멈출 사유가 없고 상태 파일에 `## 분해안` 의 표나 `## 생성 기록` 이 있으면 `roadmap-entry: RESUME <무엇이 있는가>`.
  4. 마지막 줄은 늘 판결 하나: `roadmap-entry: OK` · `roadmap-entry: RESUME` · `roadmap-entry: STOP`.
  - rc: OK · RESUME 0 · STOP 1 · 인자 오류 · 내부 오류 2.
  - STOP 사유 글자(시험이 문다):
    - `결과물이 커밋된 적이 없다: <경로>` · `결과물에 커밋하지 않은 변경이 있다: <경로>` — audit 도 같은 꼴(「audit 이 …」)
    - `상태 파일이 커밋된 적이 없다: <경로>` · `상태 파일의 커밋 뒤 변경이 두 절 밖에 있다: <바뀐 절 이름 · …>`
    - `원자료가 커밋된 적이 없다: <경로>` · `원자료에 커밋하지 않은 변경이 있다: <경로>`(원자료를 찾았을 때만)
    - `결과물 §7 에 분해됨 줄이 없다 — 나눌지는 컨텍스트 쌓기에서 정한다`
    - `이 결과물의 로드맵이 이미 기본 브랜치에 있다: <로드맵 경로> — 고치려면 재분해 절차다`
    - `결과물의 위험 줄 번호가 생성기 검사에 걸린다: <brief-risk 사유>`
  - 「두 절 밖」 판정: HEAD 의 상태 파일 글과 작업 트리 글에서 `## 분해안` · `## 생성 기록` 절(제목 줄부터 다음 `## ` 앞까지)을 떼고 나머지가 같으면 두 절 안의 변경이다. 다르면 다른 줄이 속한 `## ` 제목(첫 절 앞이면 「머리」)을 댄다.
  - 커밋 여부: `git ls-files --error-unmatch` 와 `git status --porcelain -- <경로>`. 로드맵 경로는 §7 첫 `분해됨 — ` 줄의 값(커밋 펜스의 `awk` 판독과 같은 규칙)이고, 기본 브랜치 확인은 `git cat-file -e origin/<기본 브랜치>:<레포 상대 경로>`.
  - git 뿌리는 결과물 경로의 폴더에서 `git rev-parse --show-toplevel` 로 구한다(작업 폴더와 무관).

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드)** — 임시 git 저장소에 기본 브랜치 `main` · 원격 흉내(`git clone --no-local` 또는 `refs/remotes/origin/main` 직접 쓰기)와 작업 브랜치를 만들고, 커밋된 결과물 · audit · 상태 파일(§7 첫 줄 `분해됨 — docs/superpowers/roadmaps/2026-11-20-x/roadmap.md`) 픽스처를 둔다.

```python
def test_clean_split_brief_ok(self):                 # 마지막 줄 roadmap-entry: OK · rc 0 · 첫 줄 raw-source: NO-FRAMING
def test_uncommitted_brief_stops(self):              # 결과물 끝에 한 줄 덧붙임 → "결과물에 커밋하지 않은 변경이 있다" · rc 1
def test_never_committed_audit_stops(self):          # audit 를 git rm --cached → "audit 이 커밋된 적이 없다"
def test_state_changed_outside_two_sections_stops(self):  # ## R1 절에 한 줄 → "두 절 밖에 있다: ## R1"
def test_state_changed_inside_two_sections_ok(self): # ## 분해안 표와 ## 생성 기록만 덧붙임 → RESUME (STOP 아님)
def test_resume_on_approved_table(self):             # 커밋된 상태 파일에 이미 ## 분해안 표가 있다 → "roadmap-entry: RESUME" · rc 0
def test_raw_source_uncommitted_stops(self):         # seed · framing 기록을 두고 framing 기록에 미커밋 변경 → "원자료에 커밋하지 않은 변경이 있다"
def test_raw_source_lost_does_not_stop(self):        # raw-source: LOST 면 그 줄을 내고 STOP 사유를 더하지 않는다
def test_no_split_line_stops(self):                  # §7 에 분해됨 줄이 없다 → "나눌지는 컨텍스트 쌓기에서 정한다"
def test_roadmap_on_default_branch_stops(self):      # origin/main 에 그 roadmap.md 가 있다 → "이미 기본 브랜치에 있다"
def test_brief_risk_defect_stops(self):              # §5 에 K 번호가 섞였다 → "위험 줄 번호가 생성기 검사에 걸린다"
def test_all_reasons_listed(self):                   # 두 가지가 함께 틀리면 STOP 줄이 둘 · 마지막 줄 STOP
def test_relative_brief_path_from_subdir(self):      # 하위 폴더에서 상대 경로로 불러도 같은 판정
def test_writes_nothing(self):                       # 실행 전후 git status 와 파일 해시가 같다
```

Run: `python3 plugins/spec-distill/tests/test_roadmap_draft_entry.py` → Expected: FAIL(스크립트 없음).

- [ ] **Step 2: `main(argv) -> int` 를 쓴다** — 위 Interfaces 대로. 파일을 쓰지 않는다. `open(..., encoding="utf-8")`.

- [ ] **Step 3: 통과를 본다** — 같은 명령 → PASS.

- [ ] **Step 4: 변이로 이빨을 본다** — 커밋 뒤: (지우기) 두 절 떼기를 지운다(→ `inside_two_sections_ok` 실패) · (더하기) 떼는 절에 `## R` 접두 절을 더한다(→ `outside` 실패) · (뒤집기) 원자료 검사를 `LOST` 에도 건다(→ `lost_does_not_stop` 실패) · (꼴 바꾸기) 마지막 판결 줄을 첫 줄로 옮긴다(→ 마지막 줄 단언 실패). 원본에서는 통과(양성 대조).

- [ ] **Step 5: 커밋** — `git commit -m "feat(spec-distill): 로드맵 잡기 진입 검사 스크립트를 더한다"`.

---

### Task 7: `roadmap-draft` skill — 진입부터 커밋과 되돌아가기까지 (AC1 · AC6 · AC7 · AC8 · AC9 · AC11 · AC12 · AC13 · AC14 · AC19)

끝맺음 절차의 로드맵 쪽 글을 옮겨 새 skill 을 세운다. **옮김 커밋**(글자를 바꾸지 않고 옮긴다)과 **고침 커밋**(새 동작)을 가른다.

**Files:**
- Create: `plugins/spec-distill/skills/roadmap-draft/SKILL.md`
- Modify: `plugins/spec-distill/skills/context-build/references/finishing.md`(옮긴 글을 뺀다) · `shared/entry/check_invocation_surface.py`(`ENTRY_SKILLS` 에 `("spec-distill", "roadmap-draft")`) · `shared/tests/test_invocation_surface.sh`(등록 목록) · `shared/tests/test_switch_tables.sh`(`9` → `10`, 「아홉」 → 「열」) · `shared/tests/test_entry_dep_needs.sh`(`spec-distill/roadmap-draft` 의 필요 · 번호 갈래) · `shared/tests/test_skill_cost_class_place.sh`(`plugins/spec-distill/skills/roadmap-draft/SKILL.md medium`) · `shared/tests/fixtures/ask-sites.tsv`(옮긴 질문 자리의 경로 칸 · 새 질문 자리) · `plugins/spec-distill/dependencies.md`(진입 skill 행) · `plugins/spec-distill/README.md`(진입 skill 수 「다섯」 → 「여섯」 과 목록) · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh` · `test_decompose_surface.sh` · `test_end_gates.sh` · `test_repo_literals.sh` · `test_gh_single_door.sh` · `test_finishing_block_scope.py` · `test_superpowers_presence.sh` 가운데 옮긴 글을 무는 자리
- Create: `plugins/spec-distill/tests/test_roadmap_draft_skill.sh`(실행 비트 100755)

**Interfaces:**
- Consumes: 과제 5 `roadmap_write.py check` · 과제 6 `roadmap_draft_entry.py`.
- Produces: `skills/roadmap-draft/SKILL.md` 의 절 — `## 진입 단계` · `## 1. 읽기` · `## 2. 나누기 전 확인` · `## 3. 분해안 표` · `## 4. 고치기 · 승인` · `## 5. 생성` · `## 6. 커밋` · `## 7. PR 과 머지 · 지휘자 줄`(과제 8 이 채운다) · `## 되돌아가는 길`. 새 펜스 표지 `roadmap-commit`(과제 12 전에는 이 이름 그대로 — 새 표지라 바꿀 것이 없다).

- [ ] **Step 1: 대상 목록을 다시 낸다** — `finishing.md` 에서 옮길 글을 글자로 찾는다: `### 분해 판단 — Step A 직전` 절의 하위 항목 `3. **분해안 표.**` · `4. **고치기 · 승인.**` · `5. **기록.**` · `### Step A` 의 생성 걸음(`roadmap_write.py" create` 가 든 펜스와 그 앞뒤 문단) · `#### B-R — 로드맵 다시 생성` 절의 본문(「PR 과 머지」 문단 앞까지 — PR 과 머지는 과제 8) · 커밋 펜스의 로드맵 폴더 갈래(`r7=` · `RDIR` · `roadmap-check` 줄들 — 새 커밋 펜스의 재료). 그 자리를 무는 테스트를 `recheck.md` 의 `## finishing.md 를 읽는 테스트` 에서 고른다.

- [ ] **Step 2: 옮김 커밋**

- `skills/roadmap-draft/SKILL.md` 를 frontmatter(`name: roadmap-draft` · `description` — 「사용자가 `/spec-distill:roadmap-draft @<결과물 경로>` 로 부른다.」 로 시작 · `metadata:` / `cost_class: medium` · `argument-hint: "@<결과물 경로>"` · `allowed-tools` 한 항목) · 쉬운 말 규칙 블록 · 사전 검사 줄 · `## 진입 단계`(F7 문장 둘과 감시줄 판독 행 다섯 — `check_invocation_surface.py --print-head` 와 다른 진입 skill 의 같은 절을 따른다)로 세우고, Step 1 의 글을 **글자를 바꾸지 않고** 옮겨 `## 3.` · `## 4.` · `## 5.` 아래에 둔다.
- `finishing.md` 에서 옮긴 글을 뺀다. 빈 자리에는 아무 글도 남기지 않는다(가리키는 줄은 과제 9).
- 옮긴 글을 무는 테스트는 경로만 새 파일로 바꾼다(창 제목이 옮겨 갔으면 창을 새 파일에서 자른다).
- `ENTRY_SKILLS` · 등록 목록 · 수 락(9 → 10) · `test_entry_dep_needs.sh`(`spec-distill/roadmap-draft) echo "python,git"` 와 번호 갈래) · `test_skill_cost_class_place.sh` · `ask-sites.tsv`(옮긴 「4. **고치기 · 승인.**」 · 「세 번 고칠 때마다」 행의 경로 칸) · `dependencies.md` · README 의 진입 skill 수 줄을 같은 커밋에서 맞춘다.

Run: Step 2 에서 고친 테스트 전부 + `python3 shared/entry/check_invocation_surface.py` + `bash shared/tests/test_switch_tables.sh` + `bash shared/tests/test_ask_recommendation.sh`. Expected: 통과.

`git diff HEAD -M --stat` 과 `git diff HEAD --color-moved=plain` 으로 옮긴 덩어리가 「옮김」 으로 보이는지 확인한다. 커밋: `refactor(spec-distill): 끝맺음 절차의 분해안 표 · 생성 · 다시 생성 글을 roadmap-draft 로 옮긴다 (옮김만)`.

- [ ] **Step 3: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_roadmap_draft_skill.sh`)**

`SK=plugins/spec-distill/skills/roadmap-draft/SKILL.md` 에 대해 문장 · 펜스를 문다. 문장 단언은 헤더가 아니라 본문에만 있는 글자로 한다.
```bash
has "$SK" 'python3 "$SD/scripts/roadmap_draft_entry.py" --brief'        # 걸음 1 — 진입 검사
has "$SK" '「그 표에서 이어 간다」 · 「표를 버리고 처음부터」'              # 다시 불렀을 때
has "$SK" '결과물 전문 · audit · 상태 파일과, 찾았으면 원자료를 읽은 뒤에 표를 제안한다'   # AC7
has "$SK" '같은 세션에서 이어 왔어도 대화가 아니라 이 읽기부터 한다'                # AC12
has "$SK" '에픽마다 고칠 자리를 코드에서 열어 확인하고, 경로 예약에 그 근거를 함께 적는다'   # AC13
has "$SK" '다른 로드맵의 경로 예약과 겹치는지 본다 — 겹침은 막지 않고 표 아래에 보인다'
has "$SK" 'python3 "$SD/scripts/roadmap_write.py" check --brief'         # AC8 — 승인 질문 전
has "$SK" '고친 횟수: '                                                  # `## 분해안` 절 안의 한 줄
lacks_all 'decompose_edits'                                              # 스키마 밖 키를 쓰지 않는다
has "$SK" 'roadmap_write.py" create --brief'                             # AC14 — 인자는 지금과 같다
lacks "$SK" '--layout'                                                   # AC14 — 새 형식 표시 없음
has "$SK" '<!-- roadmap-commit:begin -->'
has "$SK" 'docs(roadmap): '
has "$SK" '§7 의 `분해됨` 줄을 지우는 것 하나뿐이다'                        # AC11
has "$SK" '생성 기록의 파일 지우기 · 상태 파일의 두 절 비우기 · `분해됨` 줄 지우기를 한 커밋에 넣는다'
has "$SK" '「spec 하나로」 · 그 결과물을 입력으로 새 `/spec-distill:context-build`'
# 생성기는 표가 승인된 뒤에만 돈다 — 다시 생성 걸음이 roadmap-draft 글에 없다(AC9 — 모든 skill 글은 과제 9 의 test_stage_split.sh 가 문다.
#   context-build 쪽의 「B-R 다시 생성」 꼬리는 과제 9 가 지운다)
for f in $(git ls-files 'plugins/spec-distill/skills/roadmap-draft/*'); do lacks "$f" '다시 생성'; done
has "$SK" '실패해 표를 고친 뒤 다시 도는 것과 끊긴 뒤 이어 가며 도는 것은 같은 생성 기록 위에서 그 기록의 파일만 덮어쓴다'
# 커밋 펜스 동작 — 펜스를 뽑아 임시 저장소에서 돌린다
#   로드맵 폴더 + 상태 파일이 한 커밋에 들어간다 · 결과물 · audit 은 그 커밋에 없다 · 제목이 docs(roadmap):
#   기본 브랜치 위면 커밋하지 않고 손 목록(로드맵 폴더 · 상태 파일)을 낸다
```
`has` · `lacks` · `lacks_all` · 펜스 뽑기는 `test_finish_commit_roadmap.sh` 의 도우미를 따른다. Run → Expected: FAIL.

- [ ] **Step 4: 고침 커밋 — 새 동작을 쓴다**

- **`## 진입 단계` 뒤 걸음 1(진입 검사).** `roadmap_draft_entry.py --brief "<@경로를 푼 절대경로>"` 를 돌리는 펜스. 마지막 줄이 `STOP` 이면 `roadmap-entry: STOP` 사유 줄들을 그대로 보이고 멈춘다(사유가 「분해됨 줄이 없다」 면 다시 묻지 않는다 · 「위험 줄 번호」 면 결과물을 고치지 않고 길 둘을 보인다). `RESUME` 이면 「그 표에서 이어 간다」 · 「표를 버리고 처음부터」 를 `AskUserQuestion` 하나로 묻는다 — 이어 가면 그 표를 걸음 4 의 화면으로 다시 보이고 `check` 로 수를 다시 센 뒤 승인을 다시 받는다. 판결 줄이 없으면 멈춘다.
- **`## 1. 읽기`.** 진입 검사의 `raw-source:` 줄을 「원자료: 읽음 · 찾지 못함 · 없음」 한 줄로 보이고(막지 않는다), 결과물 전문 · audit · 상태 파일 · 원자료를 읽는다. 「넘겨받는 것은 결과물 · audit · 상태 파일 · 원자료뿐이다 — 레포의 코드와 다른 로드맵 파일은 이 단계 자신의 조사다」 와 「같은 세션에서 이어 왔어도 대화가 아니라 이 읽기부터 한다」 를 적는다.
- **`## 2. 나누기 전 확인`(지침 한 문단).** 결과물의 조사 근거가 가리키는 고칠 자리를 코드에서 열어 확인하고, 에픽마다 경로 예약에 그 근거를 적고, 다른 로드맵의 예약과 겹치는지 본다(로드맵 목록은 `python3 "$SD/scripts/roadmap_status.py"` 가 낸다 — 지금 있는 명령). 겹침은 막지 않고 표 아래에 보인다.
- **`## 3. 분해안 표`.** 옮긴 글의 「미배정 · 고아는 모델이 센다」 류 문장을 「승인 질문 전에 `roadmap_write.py check --brief … --audit … --plan-table <상태 파일>` 을 돌려 `roadmap-table:` 줄과 목록을 그대로 보인다」 로 바꾼다. 상태 파일에 표를 적는 것은 `## 분해안` 절이다(그 펜스는 표를 적은 뒤에 돈다).
- **`## 4. 고치기 · 승인`.** 질문(승인 · 고치기 · spec 하나로)과 세 번마다 묻기는 그대로. 「고친 횟수는 state `decompose_edits` 에 센다」 를 「고친 횟수는 `## 분해안` 절 안의 `고친 횟수: <n>` 한 줄에 센다」 로 바꾼다. 승인된 표 아래 `승인: 「…」` 줄은 그대로.
- **`## 5. 생성`.** 옮긴 생성 펜스의 인자는 그대로(`--brief` · `--audit` · `--plan-table` · `--out` · `--title` · `--date` · `--approval`, `--layout` 없음). 「실패하면 표를 고친 뒤 다시 돌고, 끊긴 뒤 이어 가며 돌 때와 같이 생성 기록의 파일만 덮어쓴다」. 생성기가 결과물 쪽 결함으로 실패하면 고치지 않고 길 둘을 보이고 멈춘다. 옮긴 B-R 본문 가운데 「다시 생성」 걸음은 지운다(AC9) — 「다시 생성」 낱말이 어느 skill 글에도 남지 않는다.
- **`## 6. 커밋`.** 새 펜스 `<!-- roadmap-commit:begin -->` ~ `end`. 재료는 옛 커밋 펜스의 로드맵 폴더 갈래(`r7` 판독 · `check-path roadmaps_dir` · 폴더 여부 · `path-inside` · `roadmap-check` · 기본 브랜치 · detached · 기본 브랜치 위 거절)다. 넣는 것은 로드맵 폴더와 상태 파일 둘. 제목 `docs(roadmap): <로드맵 폴더 이름> 로드맵 · 분해안`. 성공 줄 `[spec-distill] 로드맵 폴더 · 상태 파일을 커밋했다 — <sha> (<브랜치>)`. 거절 갈래는 「커밋하지 않았다 — <사유>. 확인한 뒤 직접 커밋하라: <로드맵 폴더> · <상태 파일>」.
- **`## 되돌아가는 길`.** 설계 1 「되돌아가는 길」 셋을 그대로 지시로: 「spec 하나로」 → §7 `분해됨` 줄을 지우는 커밋(`docs(roadmap): … 나누지 않기로`)과 구조 게이트 다시 돌리기(`check_brief.py gate`)와 나누지 않은 일의 다음 세션 줄(`context-build` 의 그 줄과 같은 글 — 그 파일의 줄을 가리키지 않고 같은 글을 싣는다) · 생성이 이미 성공했으면 생성 기록의 파일 지우기 · 로드맵을 커밋한 뒤 머지 전 취소면 셋을 한 커밋에 · 결과물에서 모자란 것을 보면 고치지 않고 길 둘.

- [ ] **Step 5: 통과를 본다** — `bash plugins/spec-distill/tests/test_roadmap_draft_skill.sh` · Step 2 의 테스트들 · `python3 shared/entry/check_invocation_surface.py`. Expected: 통과.

- [ ] **Step 6: 변이로 이빨을 본다** — 커밋 뒤 skill 글에: (지우기) `check --brief` 줄 · (더하기) 생성 펜스에 `--layout team` · (뒤집기) 「막지 않고」 → 「막고」 · (꼴 바꾸기) 커밋 펜스에 결과물 경로를 `git add` 에 더한다. 각각 시험이 실패해야 한다. `ls -l` 이 아니라 `git ls-files -s plugins/spec-distill/tests/test_roadmap_draft_skill.sh` 로 100755 를 본다.

- [ ] **Step 7: 커밋** — `git commit -m "feat(spec-distill): roadmap-draft 가 커밋된 결과물에서 진입 검사 · 번호 세기 · 생성 · 커밋을 한다"`.

---

### Task 8: PR 과 머지 · 지휘자 줄을 `roadmap-draft` 로 (AC10 · AC16)

**Files:**
- Modify: `plugins/spec-distill/skills/context-build/references/finishing.md`(`**PR 과 머지 — 분해된 일 ①/② 만.**` 문단부터 펜스 셋(`interview-pr` · `interview-merge` · `interview-merge-recheck`)과 「다음 세션 줄 — 분해된 일」 까지를 뺀다) · `plugins/spec-distill/skills/roadmap-draft/SKILL.md`(`## 7.`) · `plugins/spec-distill/tests/test_finish_pr_merge.sh` · `test_end_gates.sh` · `test_decompose_surface.sh` · `test_plain_gate_templates.sh` · `shared/tests/fixtures/ask-sites.tsv` 가운데 옮긴 글을 무는 자리
- Create(선택): `plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md` — 본문이 길어지면 PR 과 머지 글을 여기에 두고 `## 7.` 은 `Read` 한 줄로 가리킨다. 둘 가운데 어느 쪽이든 AC37 의 「로드맵 잡기 본문 + 끝맺음 절차에서 온 글이 든 파일」 에 든다.

- [ ] **Step 1: 대상 목록을 다시 낸다** — 위 문단 · 펜스 표지 · `/spec-distill:epic-conductor` 줄을 grep 으로 찾고, 그 글을 무는 테스트를 고른다.

- [ ] **Step 2: 옮김 커밋** — 글자를 바꾸지 않고 옮긴다. 펜스 표지 이름(`interview-pr` 등)도 이 커밋에서는 그대로다(과제 12 가 바꾼다). 테스트는 경로만 바꾼다. Run: `bash plugins/spec-distill/tests/test_finish_pr_merge.sh` · `bash shared/tests/test_ask_recommendation.sh` → 통과. 커밋: `refactor(spec-distill): PR 과 머지 · 지휘자 줄을 roadmap-draft 로 옮긴다 (옮김만)`.

- [ ] **Step 3: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_finish_pr_merge.sh` 에 더한다)**

```bash
has "$PR" 'PR 을 열지 묻는 조건은 이 단계가 로드맵을 커밋했는가 하나다'
lacks "$PR" '분해된 일 ①/② 만'                    # 앞 단계의 끝 질문 답을 읽지 않는다
lacks "$PR" '여기서 계속'                          # 같은 턴에 지휘자를 부르는 갈래가 없다
has "$PR" '머지가 확인되면 언제나 지휘자를 부르는 명령 줄을 보이고 턴을 끝낸다'
has "$PR" '/spec-distill:epic-conductor <roadmap-path>'
# PR 펜스를 뽑아 돌린다 — 「로드맵 폴더 · 상태 파일을 커밋했다」 줄이 앞에 있을 때만 PR 을 묻는 흐름이고,
#   PR 본문 펜스가 올리는 파일 목록에 결과물 · audit · 상태 파일 · 로드맵 폴더(와 알 때 framing 기록 · seed)를 댄다
```
`$PR` 은 Step 2 에서 PR 글이 간 파일. Run → Expected: FAIL.

- [ ] **Step 4: 고침 커밋**

- PR 을 묻는 조건을 「`## 6. 커밋` 이 로드맵을 커밋했는가(성공 줄 `로드맵 폴더 · 상태 파일을 커밋했다`)」 하나로 바꾼다 — 「①/② 만」 과 끝 질문 답을 읽는 문장을 지운다.
- PR 에는 앞 단계의 커밋과 이 단계의 커밋이 함께 실린다는 것을 적는다. PR 본문 펜스의 「brief · audit · 상태 파일과 로드맵 폴더를 올린다」 를 원자료가 있을 때 framing 기록 · seed 도 대게 고친다(설계 5 의 「펜스 밖 넷」 가운데 하나 — AC16).
- 머지가 확인되면(`interview-merge: MERGED` · 다시 확인 펜스 포함) 「언제나」 지휘자 명령 줄 `/spec-distill:epic-conductor <roadmap-path>` 를 보이고 턴을 끝낸다. 「여기서 계속」 이면 같은 턴에 지휘자를 부르던 갈래를 지운다. 머지하지 않음 · 실패 갈래의 「이 커밋이 기본 브랜치에 머지된 뒤 지휘 세션을 열라」 줄은 그대로.

- [ ] **Step 5: 통과를 본다** — `bash plugins/spec-distill/tests/test_finish_pr_merge.sh` · `bash plugins/spec-distill/tests/test_gh_single_door.sh` · `python3 plugins/spec-distill/tests/test_finishing_block_scope.py`(새 파일의 bash 펜스도 그 검사의 대상 목록에 넣는다). Expected: 통과.

- [ ] **Step 6: 변이로 이빨을 본다** — (지우기) 「언제나」 · (더하기) 「여기서 계속을 골랐으면 같은 턴에 지휘자를 부른다」 한 문장 · (뒤집기) 조건 「커밋했는가」 → 「커밋하지 않았는가」 · (꼴 바꾸기) 지휘자 줄을 `/epic-conductor` 로. 각각 실패.

- [ ] **Step 7: 커밋** — `git commit -m "feat(spec-distill): 로드맵을 커밋했으면 PR 을 묻고 머지 뒤엔 언제나 지휘자 줄을 보이고 끝낸다"`.

---

### Task 9: `context-build` 다듬기 (AC3 · AC4 · AC5 · AC9 · AC12 · AC15 · AC37 · AC39)

**Files:**
- Modify: `plugins/spec-distill/skills/context-build/SKILL.md` · `references/finishing.md` · `references/state-file.md` · `references/steelman.md` · `plugins/spec-distill/tests/test_end_gates.sh` · `test_decompose_surface.sh` · `test_conducting_interview_stage.sh` · `test_superpowers_presence.sh` · `test_plain_gate_templates.sh` · `test_finish_commit_roadmap.sh` · `test_workspace_invariance.sh` · `test_repo_literals.sh` · `shared/tests/fixtures/ask-sites.tsv` 가운데 바뀐 글을 무는 자리
- Create: `plugins/spec-distill/tests/test_stage_split.sh`(100755) · `plugins/spec-distill/tests/test_stage_read_budget.sh`(100755)

**Interfaces:**
- Consumes: 과제 5 `roadmap_write.py check --brief --audit`(위험 줄 검사).
- Produces: 「나눈다」 로 끝난 컨텍스트 쌓기의 끝 줄 두 개 — `/compact`(또는 `/new`)와 `/spec-distill:roadmap-draft @<결과물 절대경로>`.

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드)**

`test_stage_split.sh` — 부재 락과 양의 짝(AC3):
```bash
CB=$(git ls-files 'plugins/spec-distill/skills/context-build/*')
RD=$(git ls-files 'plugins/spec-distill/skills/roadmap-draft/*')
for tok in '3. **분해안 표.**' '4. **고치기 · 승인.**' 'roadmap_write.py" create' \
           'interview-pr:begin' 'interview-merge:begin' 'roadmap-pr:begin' 'roadmap-merge:begin' \
           '/spec-distill:epic-conductor' '고친 횟수: '; do
  none_in "$CB" "$tok"; some_in "$RD" "$tok" || some_in "$RD" "${tok/interview-/roadmap-}"
done
# 「나눌 것인가」 질문은 조사를 닫은 직후, 결과물을 쓰기 전에 있다
order "$FIN" '### 분해 판단 — Step A 직전' '### Step A — brief 작성'
has "$FIN" '나눈다 — 확정 뒤 로드맵 잡기로'
# AC9 — 다시 생성 걸음이 어느 단계의 글에도 없다
for f in $(git ls-files 'plugins/spec-distill/skills/*'); do lacks "$f" '다시 생성'; done
# AC4 — 「나눈다」 결과물의 §7 첫 줄은 Step A 가 쓴다(구조 게이트의 「나눈 일은 건너뛸 수 없다」 가 이 줄을 읽는다)
has "$FIN" '§7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓰고'
```
(헤더 글자가 아니라 본문 토큰으로 문다. `interview-*` 와 `roadmap-*` 표지를 둘 다 적은 것은 과제 12 전후 모두 이빨이 있게 하려는 것이다.)

`test_finish_commit_roadmap.sh`(고친다) — 커밋 펜스(`interview-commit`)를 뽑아 돌려:
```bash
# §7 에 분해됨 줄과 로드맵 폴더가 있어도 결과물 · audit · 상태 파일만 커밋된다 — 로드맵 폴더는 커밋에 없다
# 성공 줄은 「brief · audit · 상태 파일을 커밋했다」 하나뿐이다(「로드맵 폴더를 커밋했다」 글자가 펜스에 없다)
# 펜스에 roadmap-check · roadmaps_dir 글자가 없다
```

`test_end_gates.sh` 에 더한다:
```bash
has "$FIN" '/spec-distill:roadmap-draft @<결과물 절대경로>'
has "$FIN" '끝 질문의 어느 갈래로 끝나든 커밋했으면 로드맵 잡기 줄을 낸다'
has "$FIN" '손으로 커밋할 파일 목록과 함께 로드맵 잡기 줄을 내고 「커밋한 뒤 입력하라」 고 알린다'
has "$FIN" 'python3 "$SD/scripts/roadmap_write.py" check --brief'      # AC39 — 커밋 전
has "$FIN" '숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다'
lacks "$FIN" '분해 판단 표가 이 순서로 미리 배정했다'
has "$CB_SKILL" '모델 판단으로 건너뜀'                                   # AC15 — 소개 문구와 종료 조건
```

`test_stage_read_budget.sh` — AC37 방향 기준(상수는 과제 1 의 `## 기준 줄 수`):
```bash
BASE_INTENT=<과제 1 의 request-framing 본문 줄 수>
BASE_INTERVIEW=<과제 1 의 pm-interview 본문 + finishing.md 줄 수>
le "$(lines skills/intent-sync/SKILL.md)" "$BASE_INTENT"
le "$(lines skills/context-build/SKILL.md skills/context-build/references/finishing.md)" "$BASE_INTERVIEW"
le "$(lines $(git ls-files 'plugins/spec-distill/skills/roadmap-draft/*'))" "$BASE_INTERVIEW"
```

Run → Expected: FAIL.

- [ ] **Step 2: `finishing.md` 의 「나눌 것인가」 질문을 고친다**

자리는 그대로(`### 분해 판단 — Step A 직전`). 신호 셋 · 권고 한 줄 · 선택지 둘 · 권장 표시 규칙은 그대로. 「나눈다」 쪽 선택지만 바꾼다(설계 1 이 글자를 계획에 맡겼다):
- 라벨: `나눈다 — 분해안 보기` → `나눈다 — 확정 뒤 로드맵 잡기로`
- 설명: `얻음: brief 를 확정해 커밋한 뒤 로드맵 잡기에서 에픽 표를 짜 덩어리마다 따로 승인한다 · 내줌: 작은 일이면 로드맵과 묶음 파일만 늘려 과하게 나눈 셈이 된다`
절의 하위 항목 3–5 가 빠진 자리(과제 7)에 한 줄: 「나눈다」 면 Step A 가 §7 첫 줄에 `분해됨 — <로드맵 경로>` 를 쓰고(로드맵 경로는 결과물 파일 이름에서 끝의 `-interview.md` 를 뗀 이름의 로드맵 폴더 아래 `roadmap.md` — 지금 규칙), 표는 다음 단계가 짠다.

- [ ] **Step 3: 위험 번호 규칙과 커밋 전 검사(AC39)**

`**위험 번호.**` 문단에서 「(분해 판단 표가 이 순서로 미리 배정했다)」 를 지운다. 새 K 가 받는 다음 수의 범위에서 「분해 표의 배정 번호」 를 뺀다. Step A 의 구조 게이트 뒤 · 커밋 펜스 앞에 걸음 하나: 「나눈다」 를 고른 결과물이면 `python3 "$SD/scripts/roadmap_write.py" check --brief "<payload>" --audit "<audit>"` 를 돌리고, `brief-risk: FAIL` 이면 그 자리에서 §5 위험 줄을 고친 뒤 다시 돈다. 이 걸음을 Step A.5 「되묻기 갈래」 의 다시 도는 걸음 목록에도 넣는다(「8은 로드맵이 있을 때만」 은 지운다).

- [ ] **Step 4: 커밋 범위와 끝 줄(AC5)**

- 커밋 펜스(`interview-commit`)에서 로드맵 폴더 갈래(`r7` · `RDIR` · `roadmaps_dir` · `roadmap-check` · 「로드맵 폴더가 없어 빼고 진행한다」 · 「로드맵 폴더에 커밋할 파일이 없어」)를 지우고, 성공 줄을 `brief · audit · 상태 파일을 커밋했다` 하나로 둔다. 넣는 것은 결과물 · audit · 상태 파일과 B9 의 두 파일(framing 기록 · seed — 커밋되지 않은 변경이 있을 때)뿐이다.
- B-1(superpowers 없음) · B-2(이름 표) · B-3(①②③④)의 「분해된 일이면 …」 꼬리를 고친다: 이름 표의 분해된 일 행은 `확정하고 /compact 후 로드맵 잡기로 (권장)` · `확정하고 /new 후 로드맵 잡기로`(선택지 수와 뜻은 그대로). 「나눈다」 로 끝난 일은 끝 질문의 어느 갈래로 끝나든(확정하고 넘기는 갈래 · `brief만 종료` · superpowers 가 없는 환경의 끝 질문) 커밋 펜스가 커밋했으면 두 줄(`/compact` 또는 `/new` 와 `/spec-distill:roadmap-draft @<결과물 절대경로>`)을 낸다. 커밋 펜스가 커밋하지 않았으면 손으로 커밋할 파일 목록과 함께 그 줄을 내고 「커밋한 뒤 입력하라」 고 알린다. 「여기서 계속」 이어도 로드맵 잡기는 그 skill 의 읽기부터 한다(대화에 기대지 않는다). 「spec 하나로」 면 지금의 다음 세션 줄 그대로.
- `B-4 — 두 가드` 의 「①/② 의 완료는 두 줄 노출」 이 지휘자 줄과 맞물린 문장을 로드맵 잡기 줄로 맞춘다.
- `SKILL.md` 의 `## 종료` 절에서 「나누면 승인된 분해안 표로 로드맵과 에픽 묶음을 만든다」 를 「나누면 결과물을 확정 · 커밋한 뒤 로드맵 잡기 줄을 낸다」 로, `Read …/epic-handoff.md` 줄은 로드맵 잡기로 갔으면 지운다(남은 쓰임이 없을 때만 — grep 으로 확인).

- [ ] **Step 5: 소개 문구 · 종료 조건 문장(AC15)** — `SKILL.md` frontmatter `description` 의 종료 문장과 본문 첫 문단 · `## 종료` 의 종료 조건 문장에 「또는 모델 판단으로 건너뛸 때(건너뜀 줄을 남긴다)」 를 더한다 — 지금 `### 나가는 문은 floor 뒤에만 있지 않다` 절이 이미 말하는 건너뜀과 같은 것을 가리킨다. 본문 604 줄 상한을 지킨다.

- [ ] **Step 6: 상태 파일에 두 자리를 정한다(AC12)** — `references/state-file.md` 에 「상태 파일 본문의 절」 목록을 한 곳에 둔다: `## 풀린 입력` · `## R<n>` · `## audit §2 대기 줄` · `## 반대 논거 기록 대기` · `## 위험 줄 대기` · `## 분해안`(로드맵 잡기만 쓴다) · `## 생성 기록`(생성기가 쓴다). `steelman.md` 의 기록 걸음과 `SKILL.md` 의 blind-spot-prober dispatch 절에 「인터뷰 중에는 그 재료(넘긴 입력 · 확인한 것 · 사용자 선택 / 위험 줄)를 상태 파일의 그 절에 적고, Step A 가 그 절에서 audit §3 · 결과물 §5 로 옮긴다」 를 적는다. `state-file.md` 의 「끝낼 때」 문장(「분해된 일이면 로드맵 폴더도 같은 커밋에 든다」)을 지우고 framing 기록 · seed 가 B9 대로 함께 든다고 고친다(설계 5 「펜스 밖 넷」 가운데 하나 — AC16).

- [ ] **Step 7: 통과를 본다** — Step 1 의 테스트들 · `bash plugins/spec-distill/tests/test_check_brief.sh`(AC4 — §7 `분해됨` 줄과 건너뜀 줄이 함께 있으면 구조 게이트가 막는다는 기존 시험이 그대로 통과) · `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`(604 상한) · `test_superpowers_presence.sh` · `test_plain_gate_templates.sh` · `test_workspace_invariance.sh` · `test_repo_literals.sh`(옛 `roadmap-check` 변이 자리는 roadmap-draft 커밋 펜스로 옮긴다) · `bash shared/tests/test_ask_recommendation.sh`. Expected: 통과.

- [ ] **Step 8: 변이로 이빨을 본다** — 커밋 뒤: `test_stage_split.sh` — (더하기) `context-build/references/finishing.md` 에 `roadmap_write.py" create` 한 줄 · (지우기) roadmap-draft 의 `/spec-distill:epic-conductor` 줄 · (뒤집기) `### Step A` 를 `### 분해 판단` 앞으로 · (꼴 바꾸기) 질문 라벨을 `나눈다 — 분해안 보기` 로. `test_stage_read_budget.sh` — finishing.md 에 기준을 넘는 빈 줄을 더한다. 각각 실패. 두 새 테스트의 100755 를 본다.

- [ ] **Step 9: 커밋** — `git commit -m "feat(spec-distill): context-build 가 확정 · 커밋까지만 하고 나눈 일은 로드맵 잡기 줄로 끝낸다"`.

---

### Task 10: 커밋 펜스의 거절 갈래와 원자료 싣기 펜스 (AC16 · AC17)

**Files:**
- Modify: `plugins/spec-distill/skills/context-build/references/finishing.md`(커밋 펜스 `interview-commit` · Step A 3 의 원자료 싣기 펜스) · `plugins/spec-distill/README.md`(「세 경로를 보입니다」) · `plugins/spec-distill/skills/roadmap-draft/SKILL.md`(생성이 멈췄을 때의 「직접 커밋하라」 줄) · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh` · `test_first_cell_finishing.sh`

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — 커밋 펜스를 뽑아 임시 저장소에서 돌린다)**

```bash
# default_branch_lists_raw_and_seed — 기본 브랜치 위 · 커밋되지 않은 framing 기록과 seed 가 있다
#   → 「커밋하지 않았다」 줄의 손 목록에 결과물 · audit · 상태 파일 · framing 기록 · seed 다섯이 있다
# early_reject_lists_raw — git 저장소가 아닌 자리 밖의 거절 다섯(인터뷰 폴더 밖 · 작업 트리 밖 · 기본 브랜치 판정 실패 · detached · 기본 브랜치 위)
#   가운데 framing 기록을 알 수 있는 것마다 손 목록에 그 둘이 있다
# seed_from_state — 상태 파일의 seed: 가 framing 기록과 다른 이름 줄기의 seed 를 가리킬 때,
#   손 목록의 seed 경로는 상태 파일의 seed: 값이다(기록 경로에서 .audit.md 를 뗀 이름이 아니다)
lacks "$FIN" 'RAW_S="${RAW_A%.audit.md}.md"'
# raw_load_needs_state — 상태 파일이 없는 결과물에서 원자료 싣기 펜스가 싣기 전에 멈춘다(판결 줄과 사유)
has "$README" 'framing 기록 · seed'
```
Run → Expected: FAIL.

- [ ] **Step 2: 커밋 펜스를 고친다(AC16)** — `raw_source.py locate --interview` 와 seed 경로 구하기를 펜스 앞쪽(첫 거절보다 앞 · git 뿌리를 안 직후)으로 옮겨, 그 뒤 모든 거절 갈래의 손 목록 `FILES` 에 framing 기록 · seed 를 넣는다(알 수 있을 때 — 찾지 못했으면 넣지 않는다). seed 경로는 상태 파일 frontmatter 의 `seed:` 값에서 얻는다(레포 상대면 git 뿌리에 붙인다). `RAW_S="${RAW_A%.audit.md}.md"` 를 지운다. 같은 커밋에 넣는 규칙(커밋되지 않은 변경이 있는 것만)은 그대로다.

- [ ] **Step 3: 펜스 밖 안내 넷을 맞춘다** — ① roadmap-draft 의 생성이 멈췄을 때의 「직접 커밋하라」 줄 ② `state-file.md` 의 「끝낼 때」(과제 9 Step 6 에서 했으면 확인만) ③ README 의 「세 경로를 보입니다」 ④ PR 본문 펜스의 올리는 파일 목록(과제 8 Step 4 에서 했으면 확인만) — 넷 모두 원자료가 있을 때 framing 기록 · seed 를 댄다.

- [ ] **Step 4: 원자료 싣기 펜스(AC17)** — Step A 3 의 펜스(`raw_source.py" locate --interview … --absolute`) 앞에 상태 파일(`<payload 줄기>.state.md`)이 있는지 보고, 없으면 `raw-source:` 판결을 내기 전에 `[spec-distill] 원자료를 싣지 않았다 — 상태 파일이 없다: <경로>` 를 내고 멈춘다(rc 2 갈래와 같은 처리).

- [ ] **Step 5: 통과를 본다** — `bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh` · `test_first_cell_finishing.sh` · `test_workspace_invariance.sh` · `test_repo_literals.sh` · `bash plugins/spec-distill/tests/test_interview_raw_source_entry.sh`. Expected: 통과.

- [ ] **Step 6: 변이로 이빨을 본다** — (지우기) 앞으로 옮긴 `locate` 줄 · (더하기) `RAW_S="${RAW_A%.audit.md}.md"` 를 되살림 · (뒤집기) 상태 파일 확인을 `[ -e ]` → `[ ! -e ]` · (꼴 바꾸기) 손 목록에서 seed 를 뺀다. 각각 실패.

- [ ] **Step 7: 커밋** — `git commit -m "fix(spec-distill): 커밋 펜스의 거절 갈래가 framing 기록 · seed 를 대고 원자료 싣기는 상태 파일이 없으면 멈춘다"`.

---

### Task 11: 상태 보기가 로드맵 없는 「나눈다」 결과물에서 돈다 (AC18)

`roadmap_status.py` · `control_plane.py` 는 결과물 §7 을 읽지 않는다(과제 1 Step 2 확인) — 고칠 코드는 없고 시험으로 못 박는다. 고칠 것이 나오면 멈추고 보고한다(두 파일은 옆 로드맵 R1 · R2 · R3 예약).

**Files:**
- Create: `plugins/spec-distill/tests/test_status_split_brief_without_roadmap.sh`(100755)

- [ ] **Step 1: 시험을 쓴다(계획이 적은 코드)** — 임시 저장소에 「나눈다」 결과물(§7 첫 줄 `분해됨 — <없는 로드맵 경로>`) · audit · 상태 파일을 커밋하고 로드맵 폴더는 만들지 않는다. 그 저장소에서 `python3 plugins/spec-distill/scripts/roadmap_status.py`(인자 없이 — 기본 브랜치의 로드맵 목록) 와 `python3 plugins/spec-distill/scripts/control_plane.py`(상태줄을 내는 지금의 하위 명령 — 과제 실행 때 `--help` 로 확인)를 돌린다. 단언: rc 가 「오류」 값이 아니다(각 스크립트의 정상 · 안내 rc — `NO_ROADMAP` 안내 포함) · stderr 에 `Traceback` 이 없다 · 출력에 그 결과물 경로나 `분해됨` 을 이유로 한 오류 줄이 없다. 양성 대조: 같은 저장소에 `roadmap_status.py --roadmap-file <없는 경로>` 를 주면 「못 읽었다」 가 나온다(시험이 오류를 볼 수 있다는 증거).

- [ ] **Step 2: 돌린다** — Expected: 통과(지금 코드로). 실패하면 멈추고 보고한다.

- [ ] **Step 3: 변이로 이빨을 본다** — 임시 사본에서 `roadmap_status.py` 의 로드맵 목록 읽기에 `raise SystemExit(2)` 를 넣으면 시험이 실패한다(되돌린다).

- [ ] **Step 4: 커밋** — `git commit -m "test(spec-distill): 로드맵이 아직 없는 「나눈다」 결과물에서 상태 보기가 오류 없이 돈다"`.

---

### Task 12: 글 속 낱말 바꾸기 (이 계획 몫 — AC40)

**Files:**
- Modify: 이 계획 범위의 파일 가운데 아래 금지 토큰이 든 것 — `plugins/spec-distill/skills/**` · `plugins/spec-distill/references/**`(리뷰 기준 제외 — 과제 3 이 했다) · `plugins/spec-distill/templates/**` · `plugins/spec-distill/{README.md,switches.md,dependencies.md}` · `shared/docreview/references/reviewing-document.md` · `shared/docreview/scripts/docreview_state.py`(주석) · 그 글자를 무는 테스트(`plugins/spec-distill/tests/` · `shared/tests/` · `shared/tests/fixtures/ask-sites.tsv`)
- Create: `plugins/spec-distill/tests/test_stage_words.sh`(100755)

- [ ] **Step 1: 금지 토큰과 범위를 정하고 실패하는 락을 쓴다(계획이 적은 코드)**

금지 토큰(설계 2 표에서 뽑은 것 — 이 목록이 락의 경계다):
- 한글 `인터뷰` — 바로 앞이 `옛 ` 이면 허용.
- 영어 `interview brief`(대소문자 구분 없이, 사이 공백 하나).
- `docs(interview)`.
- 펜스 표지 · 판결 글자 `interview-commit` · `interview-pr` · `interview-merge`(뒤에 `-files` · `-head` · `-recheck` · `-requested` 가 붙은 꼴 포함).
허용(락이 건드리지 않는 것): `interview_dir` · `interview-state` · `interview-seed` · `interview-brief` · `interview-audit` · `-interview.md` 꼴 경로 · `interview_state.py` 등 파일 이름 · `docs/superpowers/interview/`(계획 2 몫) · 쉬운 말 규칙 블록 안 · `CHANGELOG.md`.

범위: 위 Files 의 Modify 글롭에 과제 3 의 파일(`plugins/spec-distill/agents/` · `shared/docreview/agents/` · `references/docreview-profiles/`)을 더한 것. `scripts/` 는 `shared/docreview/scripts/docreview_state.py` 하나만(spec-distill 의 스크립트는 계획 2 몫).

```bash
corpus() { git ls-files -- 'plugins/spec-distill/skills/*' 'plugins/spec-distill/references/*' \
  'plugins/spec-distill/templates/*' 'plugins/spec-distill/agents/*' 'plugins/spec-distill/README.md' \
  'plugins/spec-distill/switches.md' 'plugins/spec-distill/dependencies.md' \
  'shared/docreview/agents/*' 'shared/docreview/references/*' 'shared/docreview/scripts/docreview_state.py'; }
# 쉬운 말 규칙 블록을 뺀 본문에서 금지 토큰을 찾는다 — 0건이어야 한다
python3 - "$@" <<'PY'
# 각 파일을 utf-8 로 읽어 plain-language:begin~end 를 떼고
#   re.compile(r"(?<!옛 )인터뷰|interview brief|docs\(interview\)|interview-(?:commit|pr|merge)(?![A-Za-z0-9_])|interview-(?:pr|merge)-(?:files|head|recheck|requested)", re.I)
# 맞는 줄을 "파일:줄: 글" 로 내고 하나라도 있으면 rc 1
PY
# 양의 짝 — 새 글자가 실제로 있다(자리마다 하나)
some_in "plugins/spec-distill/skills/context-build/references/finishing.md" '<!-- context-commit:begin -->'
some_in "$(git ls-files 'plugins/spec-distill/skills/roadmap-draft/*')" '<!-- roadmap-pr:begin -->'
some_in "$(git ls-files 'plugins/spec-distill/skills/roadmap-draft/*')" 'roadmap-merge: MERGED'
some_in "plugins/spec-distill/skills/context-build/references/finishing.md" 'docs(context): '
some_in "plugins/spec-distill/skills/context-build/references/finishing.md" 'context brief'
some_in "plugins/spec-distill/README.md" '컨텍스트 쌓기'
some_in "plugins/spec-distill/README.md" '로드맵 잡기'
some_in "plugins/spec-distill/README.md" '의도 폴더'
# 「의도 폴더」 는 로드맵 폴더 아래 intent/ 를 가리키지 않는다
none_line_with "$(corpus)" '의도 폴더' 'roadmaps/'
```
Run: `bash plugins/spec-distill/tests/test_stage_words.sh` → Expected: FAIL(금지 토큰이 남아 있다).

- [ ] **Step 2: 대상 목록을 다시 낸다** — 락의 출력이 곧 대상 목록이다. 줄마다 「단계를 가리키는가 · 폴더를 가리키는가 · 옛 기록을 가리키는가」 를 보고 Global Constraints 「낱말 대응」 대로 고친다. 옛 기록을 가리키면 「옛 인터뷰 …」 로 고쳐 허용 꼴로 만든다. 스크립트(spec-distill `scripts/`)가 내는 글을 그대로 인용한 줄은 고치지 않는다(계획 2 몫 — 스크립트와 함께 바뀐다). 그런 줄은 락 안의 면제 목록에 「파일 · 줄 글자 · 이유(계획 2 — 스크립트 출력 인용 · 내는 곳 파일:함수)」 로 올리고, 락은 면제한 줄 수를 출력한다. 면제 목록은 계획 2 가 비운다.

- [ ] **Step 3: 고친다** — 펜스 표지와 판결 글자는 내는 쪽(skill 펜스)과 읽는 쪽(skill 글 · 테스트의 `fence "$X" interview-commit` 같은 뽑기 · 기대 글자)을 같은 커밋에서 바꾼다. 커밋 펜스 제목: `docs(interview): …` → `docs(context): …`. 다음 세션 줄의 `interview brief` → `context brief`. 펜스 안의 안내 글(「정해진 인터뷰 폴더 바로 아래가 아니다」 등)은 「의도 폴더」 로 — 이것을 무는 테스트 글자도 함께.

- [ ] **Step 4: 통과를 본다** — `bash plugins/spec-distill/tests/test_stage_words.sh` · `test_finish_commit_roadmap.sh` · `test_finish_pr_merge.sh` · `test_workspace_invariance.sh` · `test_stage_split.sh` · `test_roadmap_draft_skill.sh` · `bash shared/tests/test_ask_recommendation.sh` · `bash shared/tests/test_plain_language_block.sh` · `python3 shared/entry/check_invocation_surface.py`. 그리고 `git grep -l -e 'interview-commit' -e 'interview-pr' -e 'interview-merge' -- plugins shared ':!*CHANGELOG.md'` 가 0건(테스트 포함 — 읽는 쪽을 빠뜨리지 않았다).

- [ ] **Step 5: 변이로 이빨을 본다** — 커밋 뒤 범위 안 파일에: (더하기) README 에 `인터뷰 폴더` 한 줄 · (더하기 — 자리 바꿈) `shared/docreview/agents/doc-critic.md` 에 `interview brief` · (뒤집기) 허용 꼴 `옛 인터뷰` 를 `인터뷰` 로 · (꼴 바꾸기) 펜스 표지를 `Interview-Commit`(대소문자) · (지우기) 양의 짝 `<!-- context-commit:begin -->` 표지를 지운다. 각각 실패. 양성 대조: 쉬운 말 규칙 블록 안에 `인터뷰` 를 넣으면 통과한다(블록 제외가 동작한다) — 확인 뒤 되돌린다.

- [ ] **Step 6: 커밋** — `git commit -m "docs(spec-distill): skill 글 · 펜스 · 템플릿 · README · reference 의 단계 낱말과 표지를 새 이름으로"`.

---

### Task 13: 판 · 변경 기록 · README · 표 (AC19)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md` · `plugins/spec-distill/switches.md` · `plugins/spec-distill/dependencies.md`

- [ ] **Step 1: 실패하는 시험을 쓴다(계획이 적은 코드 — `test_roadmap_draft_skill.sh` 에 더한다)**

```bash
ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8"))["version"])' plugins/spec-distill/.claude-plugin/plugin.json)
[ "${ver%%.*}" = "9" ] && [ "$ver" = "9.0.0" ] || no "판이 9.0.0 이 아니다: $ver"
# CHANGELOG 9.0.0 절의 Removed 에 두 옛 이름(이어 붙여 만든 글자)과 「옛 명령 줄은 돌지 않는다」
OLD1="request-""framing"; OLD2="pm-""interview"
sec=$(awk '/^## \[9\.0\.0\]/{f=1;print;next} f&&/^## \[/{exit} f' plugins/spec-distill/CHANGELOG.md)
printf '%s' "$sec" | grep -q "$OLD1" && printf '%s' "$sec" | grep -q "$OLD2" || no "Removed 에 옛 이름이 없다"
printf '%s' "$sec" | grep -q '옛 명령 줄' || no "옛 명령 줄이 돌지 않음을 적지 않았다"
has plugins/spec-distill/README.md '9.0.0 에서 호출 이름이 바뀌었다'
has plugins/spec-distill/README.md 'CHANGELOG.md'
has plugins/spec-distill/README.md '/spec-distill:roadmap-draft'
```
Run → FAIL.

- [ ] **Step 2: 고친다**

- `plugin.json` 의 `version` 을 그때 기본 브랜치의 판에서 `9.0.0` 으로(이 PR 의 유일한 판 올림).
- `CHANGELOG.md` 맨 위에 `## [9.0.0] — <머지 직전 날짜>`: `Removed`(호출 이름 둘 — 옛 명령 줄 `/spec-distill:<옛 이름> …` 은 이 판부터 돌지 않는다 · 별칭 없음 · 업그레이드 전에 만든 seed 의 안내 줄도 돌지 않으니 새 이름으로 부르면 그 seed 는 그대로 읽힌다) · `Added`(`roadmap-draft` · `roadmap_write.py check` · `roadmap_draft_entry.py`) · `Changed`(인터뷰를 두 단계로 가름 · 커밋 범위 · PR 을 묻는 조건 · 머지 뒤 지휘자 줄 · 「나눈다」 선택지 글자 · 낱말 · 펜스 표지와 판결 글자 — 옛 판결 글자를 읽는 호환 없음) · `Fixed`(커밋 펜스 거절 갈래의 손 목록 · seed 경로 · 원자료 싣기 펜스의 상태 파일 확인). 변경 기록 연속 락(`shared/tests/test_changelog_integrity.sh`)을 지킨다.
- README: 진입 skill 목록 · 흐름 그림 · 「Principles Instantiated」 의 skill 이름 · 비용 등급 줄(`roadmap-draft: medium`) · 「9.0.0 에서 호출 이름이 바뀌었다 — 옛 이름과 옛 명령 줄은 CHANGELOG.md 의 9.0.0 절에 있다」 한 줄. 옛 이름을 글자로 싣지 않는다.
- `switches.md` 와 README 의 끄는 변수 표: 「끄는 것」 칸의 skill 이름을 새 이름으로(끄는 변수 이름은 그대로).
- `dependencies.md`: 진입 skill 행 · 「확정 · 커밋한 뒤 끝」 류 머리는 계획 3 몫이라 두고, 이름과 수만.

- [ ] **Step 3: 통과를 본다** — 위 시험 · `bash shared/tests/test_changelog_integrity.sh` · `bash shared/tests/test_switch_tables.sh` · `python3 shared/entry/check_invocation_surface.py` · `claude plugin validate plugins/spec-distill`(세 skill 을 받는다 — 설계 Verification Plan). Expected: 통과.

- [ ] **Step 4: 변이로 이빨을 본다** — (꼴 바꾸기) 판을 `9.0.1` · (지우기) Removed 의 옛 이름 하나 · (더하기) README 에 옛 이름 하나(→ 호출 표면 검사 RED). 각각 실패.

- [ ] **Step 5: 커밋** — `git commit -m "chore(spec-distill): 9.0.0 — 호출 이름 변경과 두 단계 가르기를 변경 기록 · README 에 적는다"`.

---

### Task 14: 마무리 — 줄 수 대조 · validate · 전체 스위트 · AC 보고 (AC37 · 전부)

- [ ] **Step 1: 줄 수를 견준다(AC37)** — `bash plugins/spec-distill/tests/test_stage_read_budget.sh` 와 함께 앞뒤 수(과제 1 기준 · 지금)를 PR 본문 표로 적을 수 있게 무시되는 자리에 남긴다.

- [ ] **Step 2: 기본 브랜치를 다시 합친다** — 과제 1 뒤 기본 브랜치가 움직였으면 `git merge --no-ff origin/<기본 브랜치>`(충돌이면 멈춰 보고). 합친 뒤 판을 다시 견준다(Global Constraints 「판」).

- [ ] **Step 3: 전체 스위트를 돈다** — Global Constraints 의 잠금 줄로. 기본 브랜치와 대조는 지휘자가 한다 — 실패 목록을 그대로 보고한다.

- [ ] **Step 4: 마지막 전체 리뷰에 AC 목록을 싣는다** — 고른 실행 방식의 마지막 전체 리뷰(SDD 의 최종 리뷰 또는 Native 의 한 번 리뷰)에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC1–AC19 · AC36 · AC37 · AC39 · AC40)을 글자 그대로 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. AC37 · AC40 · AC36 은 이 계획 몫만 판정한다(계획 2 · 3 · 4 몫은 「다른 계획」 으로 적는다). 리뷰에 끝에서 끝 흐름(context-build 의 커밋 → 로드맵 잡기 진입 → 표 → 생성 → 커밋 → PR)과 과제 사이 이음매(과제 7 의 펜스 이름과 과제 12 의 표지 바꿈 · 과제 9 의 커밋 펜스와 과제 10 의 거절 갈래)를 따로 물어라. 계획이 적은 테스트 코드는 「계획이 적은 코드」 라고 리뷰어에게 알린다. 보고를 git 이 추적하지 않는 파일에 적는다.

- [ ] **Step 5: 미룸을 올리고 대조를 돌린다** — 판정이 미룸 · 빠짐인 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리는 커밋을 한다(`docs(spec): …`). PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-20-front-stage-restructure-design.md <보고 파일 경로>` 를 돌려 경고를 사용자에게 보인다.

- [ ] **Step 6: PR 본문 재료를 모은다** — 보안 리뷰 대상(과제 3 의 앞뒤 규칙 대조) · 경로 게이트를 넓히지 않았다는 것 · quality-gates 판을 올리지 않은 이유(주석만) · 줄 수 앞뒤 · 옆 로드맵에 알린 파일 · 「나눈다」 선택지 글자를 계획이 정했다는 것. push 와 PR 은 지휘자가 한다.

## 계획 2 에 넘길 메모

- 설정 키는 지금 열넷이고(옆 PR 이 머지되면 열다섯) 키 수와 키 목록을 세는 글자가 `plugins/spec-distill/README.md` · `references/roadmap-ontology.md` · `tests/test_parallel_recommend_docs.sh` · `tests/test_repo_defaults.py` · `tests/test_workspace_invariance.sh` 에 있다 — `interview_dir` → `intent_dir` 를 바꿀 때 함께 본다.
- 이 계획의 낱말 락(`test_stage_words.sh`)은 `interview-state` · 종류 글자 · `-interview.md` 경로 · `interview_dir` 를 허용한다. 계획 2 가 그 층을 바꾼 뒤 락의 허용 목록을 줄인다.
- `roadmap_draft_entry.py` 와 커밋 펜스의 로드맵 경로 도출(결과물 이름에서 `-interview.md` 를 뗀다)은 옛 꼴만 안다 — 계획 2 의 대응표 모듈로 `-context.md` 를 함께 받게 한다.
