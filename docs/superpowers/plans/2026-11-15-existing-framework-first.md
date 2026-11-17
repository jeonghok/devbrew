# 있는 것 위에서 만들기를 기본으로 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 「있는 것을 검토했다」고 적는 규칙을 「맞는 있는 것이 있으면 그 위에서 만든다」로 바꾼다 — 규칙 문장 둘, 기준 글 하나(와 그 고지 파일), 인터뷰 문단, 넘김 글 넷, 설계문서 리뷰 항목 하나를 고친다.

**Architecture:** 적는 법은 새 참고 파일 `plugins/spec-distill/references/existing-first.md` 한 곳에 둔다(앞은 우리 절, 뒤는 공개 skill search-first 를 가져와 덜어 낸 영어 절). 다른 자리에는 핵심 한 문장과 그 파일을 가리키는 말만 둔다. 새 스크립트 · 훅 · agent 는 없고, 바뀐 문장마다 있는 셸 테스트에 단언을 더해 잠근다.

**Tech Stack:** 마크다운, bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), Python 3.9 표준 라이브러리(한 번 쓰고 버리는 조립 스크립트), git, gh.

**Spec:** `docs/superpowers/specs/2026-11-15-existing-framework-first-design.md`

## Global Constraints

- 설계의 확정 항목은 근거가 있으면 보고한 뒤 다시 정할 수 있고, 임의로 바꾸지 않는다. 이 계획이 다시 정한 것은 설계문서 「결정 기록」의 「계획 단계」 줄 넷에 있다(조사 agent 예시 블록을 뺀다 · 승인은 대화에서 받고 문서에 적는다 · 웹 끄기 스위치를 따른다 · 계획의 판단).
- 기준 글 경로(글자 그대로): `plugins/spec-distill/references/existing-first.md`. 고지 파일: `plugins/spec-distill/references/existing-first.NOTICE.txt`(`.md` 가 아니다 — 참고 글 고아 검사는 `.md` 만 읽는다).
- 모델이 읽는 글이 기준 글을 가리킬 때의 표기(글자 그대로): `${CLAUDE_PLUGIN_ROOT}/references/existing-first.md`.
- 마지막 전체 리뷰가 묻는 구절(글 넷에서 같은 글자): `설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.`
- 가져오는 원문: 저장소 `affaan-m/everything-claude-code` 의 `skills/search-first/SKILL.md`, 커밋 `0765f7a2ca2bd5df214d3aa7ba7e7ac19db8b189`, 183줄, SHA-256 `76835db48dd910061d2e4271b1151793d2fddbabeb2d2866eed068b3580c55d5`. MIT, 저작권 줄 `Copyright (c) 2026 Affaan Mustafa`. 영어 그대로 두고, 빼는 절 여섯과 제자리 수정 네 곳(다섯 줄) 말고는 글자를 바꾸지 않는다.
- 모델이 읽는 글(기준 글 · skill · 참고 글 · 리뷰 프로필)에는 출처 · 배경 · 존재 이유를 쓰지 않는다. 출처와 라이선스는 고지 파일 · CHANGELOG · README 에만 둔다. 모델이 읽는 글은 고지 파일을 가리키지 않는다.
- 기준 글과 넘김 글에 레포 전용 값(경로 · 테스트 명령 · 브랜치 · 모델)을 박지 않는다. 이 계획도 하위 agent 의 모델 이름을 정하지 않는다 — 실행하는 쪽이 일의 무게를 보고 그 자리에서 고른다.
- 리뷰 프로필(`references/docreview-profiles/design-doc.md`) 편집은 리뷰어 페르소나 편집이다 — 더하기만 한다(있는 항목 · 처분 · 임계 · 머리말은 그대로). 보안 리뷰 대상이다(Task 4 · Task 7).
- 기존 브랜치는 `git merge origin/main` 으로 맞춘다. rebase 하지 않는다(`docs/git-workflow/branch-strategy.md`).
- 커밋: Conventional Commits, 설명은 한국어. 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md`. push 와 PR 은 사용자가 요청할 때만 한다.
- 추적되지 않는 작업 폴더: `.claude/existing-first-work/`(레포 `.gitignore` 가 `.claude/` 를 무시한다). 기준선 · 보고 파일 · 받은 원문 · 도우미 스크립트를 여기 둔다.
- 셸: 격리된 세션은 복합 명령을 막으므로 스크립트 파일로 돌린다. 한글 바로 앞의 변수는 `${v}` 로 쓴다(bash 3.2). 테스트는 `PYTHONDONTWRITEBYTECODE=1` 로 돈다. 새 파일을 읽는 검사 일부는 git 이 추적하는 파일만 보므로 테스트 전에 `git add` 한다.
- 테스트의 끝줄 `Total: <n> | Pass: <n> | Fail: <n>` 로 실패 수를 읽는다. 실패한 단언의 이름은 `bash <테스트> 2>&1 | LC_ALL=C grep -a '✗'` 로 본다 — 단언 출력이 한글을 글자 중간에서 자른 줄을 섞어 내므로 `LC_ALL=C` 없이는 `sed` · `grep` 이 그 뒤 줄을 잃는다.
- `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh` 의 「양성 짝: … <intent> 가 비지 않는다」는 이 레포의 지금 커밋에서 의도를 읽는다 — 끝 커밋에 `Spec:` 트레일러가 없으면 빨갛다(모의 실행에서 실측). 과제의 커밋 전에 이 줄이 보이면 커밋한 뒤 그 테스트를 다시 돌려 통과를 확인한다.
- 전체 스위트: 레포 루트에서 `bash tools/suite/run-all.sh`(`FAILED …` 줄이 실패). 스위트 둘을 같은 시각에 돌리지 않는다 — 돌리기 전에 `pgrep -fl tools/suite/run-all.sh` 가 비었는지 본다(다른 세션의 지휘자가 돌리고 있을 수 있다). 과제 구현자는 고친 파일을 읽는 테스트만 돌리고, 전체 스위트는 Task 1 과 Task 7 에서 한 번씩만 돈다.
- 판: spec-distill 을 minor 로 올린다. 값은 Task 6 에서 그때의 기본 브랜치 판을 읽어 정한다(계획을 쓴 날 기본 브랜치는 `8.15.0` 이고 열린 PR #288 이 같은 파일을 고친다).

## Review Focus

- 옛 넘김 줄로 이미 쓰인 다른 에픽의 설계문서가 넓힌 리뷰 항목을 만나는 경우 — 지적은 `fix` 로 나오고 승인을 막지 않아야 한다. `approaches_comparison` 이 꼭 잡을 항목 목록에 들어가면 그 문서들의 승인이 막힌다(Task 4 의 `must_catch` 단언).
- 넘김 글 넷 가운데 하나만 구절의 글자가 달라지는 경우 — 넷이 같은 글자여야 한다(Task 3 의 단언 넷 · 변이 「글자 하나 바꾸기」).
- 인터뷰 문단의 문장이 문단 밖으로 옮겨지는 경우 — 파일 어딘가에 글자가 남아도 문단 창 안에 없으면 RED 여야 한다(Task 2 의 문단 창 · 변이 「Read 줄을 문단 밖으로」).
- 가져온 영어 절이나 새 우리 절의 낱말이 참고 폴더 전체를 훑는 부재 검사에 걸리는 경우 — 새 `.md` 는 선언 없이 그 검사들의 대상이 된다. 모의 실행에서 걸린 것은 조사 agent 예시 블록의 `general-purpose` 였고 그 블록을 뺐다. 실행에서는 추적되는 파일만 읽는 인라인 python 격리 검사가 영어 절의 pip 판 확인 명령을 잡아 `-I` 를 넣었다(Task 2 의 넓게 돌리기 · Task 7 의 전체 스위트).
- 뒤에 머지하는 다른 로드맵의 에픽이 같은 줄을 고쳐 괄호를 글자로 박은 테스트가 깨지는 경우 — 테스트로 막을 수 없어 PR 본문과 두 지휘 세션에 전할 글로 알린다(Task 7).

## 파일 구조

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `plugins/spec-distill/references/existing-first.md` (새 파일) | 「있는 것 검토」 절을 적는 법 — 우리 절 열둘 + 가져온 영어 절 | 2 |
| `plugins/spec-distill/references/existing-first.NOTICE.txt` (새 파일) | 가져온 절의 저작권 줄 · MIT 전문 · 출처 · 뺀 절 · 제자리 수정 | 2 |
| `plugins/spec-distill/skills/pm-interview/SKILL.md` | 「있는 것 먼저」 문단 | 2 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | 문단 단언 · 줄 수 상한 | 2 |
| `plugins/spec-distill/skills/pm-interview/references/finishing.md` | brief 넘김 줄의 괄호와 묻는 구절 | 3 |
| `plugins/spec-distill/references/epic-handoff.md` | 에픽 넘김 줄의 괄호와 묻는 구절 | 3 |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | 다음 세션 줄의 묻는 구절 | 3 |
| `plugins/spec-distill/references/conductor-dispatch.md` | 구현 담당자 틀의 묻는 구절 | 3 |
| `plugins/spec-distill/tests/test_end_gates.sh` · `test_review_handoff_order.sh` · `test_conductor_dispatch_reference.sh` | 괄호 · 구절 단언 | 3 |
| `plugins/spec-distill/references/docreview-profiles/design-doc.md` | 층 2 `approaches_comparison` 항목 | 4 |
| `plugins/spec-distill/tests/test_handoff_design_mode.sh` | 항목 단언 | 4 |
| `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` | 규칙 문장 둘 | 5 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` | 판과 문서 | 6 |
| `docs/superpowers/specs/2026-11-15-existing-framework-first-design.md` | 「미룸」 표(마지막 리뷰의 미룸 · 빠짐) | 7 |

과제 순서는 고정이다. Task 5 의 철학 문서는 Task 2 가 커밋한 기준 글을 가리키고(가리키는 경로가 추적되지 않으면 헌장 인용 검사가 빨갛다), Task 6 의 문서는 앞 과제들이 바꾼 것을 적는다.

---

### Task 1: 최신 기본 브랜치에 올라서고 겹침을 다시 확인한다

AC13 의 기준선을 만들고, 설계 §9 의 표(다른 로드맵이 예약한 파일)를 지금의 기본 브랜치로 다시 확인한다.

**Files:**
- Create: `.claude/existing-first-work/touching.sh`(추적 안 함) · `.claude/existing-first-work/old_strings.py`(추적 안 함) · `.claude/existing-first-work/suite-base.txt`(추적 안 함) · `.claude/existing-first-work/overlap.md`(추적 안 함)

**Interfaces:**
- Produces: `.claude/existing-first-work/touching.sh <낱말>…` — 그 낱말을 품은 셸 테스트를 전부 돌려 `FAILED <파일>: <이름>` 줄과 끝줄 `실패한 파일 <n>개` 를 낸다. `.claude/existing-first-work/suite-base.txt` — 편집 전 전체 스위트의 `FAILED` 줄(뒤 과제가 「새 실패」를 가를 때 견준다).

- [ ] **Step 1: 기본 브랜치를 받아 합친다**

```bash
git fetch origin
git merge origin/main
```

Expected: 충돌 없이 merge 커밋이 생긴다(이 브랜치가 더한 것은 `docs/superpowers/` 의 문서뿐이다). 충돌이 나면 멈추고 보고한다.

- [ ] **Step 2: 고칠 옛 문장이 그대로 있는지 본다**

`.claude/existing-first-work/old_strings.py` 를 아래로 만들고 `python3 .claude/existing-first-work/old_strings.py` 로 돌린다.

```python
#!/usr/bin/env python3
"""고칠 옛 문장이 파일마다 정확히 한 번 있는지 본다."""
P = "plugins/spec-distill/"
PAREN = "(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
TAIL = "보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다."
CHECKS = [
    ("CLAUDE.md", "- **있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."),
    ("docs/philosophy/devbrew-harness-philosophy.md", "- (재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17)."),
    (P + "skills/pm-interview/SKILL.md", "먼저 찾고, 바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다. 레포 안 후보는 레포 주장(RC)으로,"),
    (P + "skills/pm-interview/references/finishing.md", PAREN),
    (P + "skills/pm-interview/references/finishing.md", TAIL),
    (P + "references/epic-handoff.md", PAREN),
    (P + "references/epic-handoff.md", TAIL),
    (P + "skills/spec-review/SKILL.md", TAIL),
    (P + "references/conductor-dispatch.md", "와 계획이 쓴 테스트 코드도 묻게 한다."),
    (P + "references/docreview-profiles/design-doc.md", "- `approaches_comparison` — 대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적.\n"),
    (P + "tests/test_end_gates.sh", PAREN),
    (P + "tests/test_conducting_interview_stage.sh", "SKILL_LINE_CAP=594\n"),
]
bad = 0
for path, lit in CHECKS:
    n = open(path, encoding="utf-8").read().count(lit)
    if n != 1:
        bad += 1
        print("어긋남 %d회 — %s — %s" % (n, path, lit[:40]))
print("옛 문장 %d/%d 실재" % (len(CHECKS) - bad, len(CHECKS)))
raise SystemExit(1 if bad else 0)
```

Expected: `옛 문장 12/12 실재`. 어긋난 줄이 있으면 예약 에픽이 그 문장을 먼저 고친 것이다 — 멈추고 그 줄을 사용자에게 보고한다(설계 §9).

- [ ] **Step 3: 예약 표를 다시 확인한다**

두 로드맵 파일을 읽는다 — `docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` 와 `docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md`. 「파일 구조」 표의 추적 파일마다 어느 에픽의 예약 경로인지를 설계 §9 의 표와 견주고, 열린 PR 이 그 파일을 고치는지 본다.

```bash
gh pr list --state open --limit 50 --json number,title,headRefName,files
```

결과를 `.claude/existing-first-work/overlap.md` 에 표(파일 · 주인 에픽 · 그 에픽의 상태 · 열린 PR)로 적는다 — Task 7 이 PR 본문에 옮긴다. 열린 PR 이 Step 2 의 옛 문장 줄을 고치면 멈추고 보고한다. 판 파일 · CHANGELOG · README 만 겹치면 진행한다(Task 6 이 판을 그때 정한다).

- [ ] **Step 4: 넓게 돌리는 도우미를 만든다**

`.claude/existing-first-work/touching.sh` 를 아래로 만든다.

```bash
#!/usr/bin/env bash
# usage: touching.sh <낱말>…  — 그 낱말을 품은 셸 테스트를 전부 돌려 실패 줄을 낸다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
export PYTHONDONTWRITEBYTECODE=1
pat="$(printf '%s\n' "$@" | paste -sd'|' -)"
total=0
while IFS= read -r f; do
  out="$(bash "$f" 2>&1 < /dev/null)"; rc=$?
  fails="$(printf '%s\n' "$out" | LC_ALL=C sed -nE 's/^ *(✗|FAIL:) //p')"
  if [ -n "$fails" ]; then
    printf '%s\n' "$fails" | sed "s|^|FAILED $f: |"; total=$((total + 1))
  elif [ "$rc" -ne 0 ]; then
    echo "FAILED $f: rc $rc(실패 표시 줄 없음)"; total=$((total + 1))
  fi
done < <(git grep -l -E "$pat" -- 'plugins/*/tests/test_*.sh' 'shared/tests/test_*.sh' | grep -v -e '/spike/' -e '/fixtures/' | LC_ALL=C sort)
echo "실패한 파일 ${total}개"
```

- [ ] **Step 5: 편집 전 전체 스위트로 기준선을 뜬다**

`pgrep -fl tools/suite/run-all.sh` 가 비었는지 본 뒤 돌린다(다른 스위트가 돌고 있으면 끝나기를 기다린다).

```bash
bash tools/suite/run-all.sh > .claude/existing-first-work/suite-base.txt
```

Expected: 파일에 `FAILED` 줄 몇 개가 남는다(편집 전부터 있던 실패 — 분리 worktree 에서는 `TestCrossResolverAdvisory` 가 그 가운데 하나다). 이 파일이 뒤 과제의 기준이다 — 뒤에서 본 실패 줄이 이 파일에 글자 그대로 있으면 새 실패가 아니다.

---

### Task 2: 기준 글 · 고지 파일 · 인터뷰 문단

AC3 · AC4 · AC5 · AC6 · AC7 · AC11 · AC12(문단 단언).

**Files:**
- Create: `plugins/spec-distill/references/existing-first.md` · `plugins/spec-distill/references/existing-first.NOTICE.txt`
- Create(추적 안 함): `.claude/existing-first-work/upstream/search-first.SKILL.md` · `.claude/existing-first-work/upstream/LICENSE` · `.claude/existing-first-work/ours.md` · `.claude/existing-first-work/build_ref.py`
- Modify: `plugins/spec-distill/skills/pm-interview/SKILL.md`(「**있는 것 먼저.**」 문단, 네 줄)
- Test: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: Task 1 의 `touching.sh` · `suite-base.txt`.
- Produces: 추적되는 파일 `plugins/spec-distill/references/existing-first.md`(Task 3 의 괄호 · Task 5 의 철학 문서 · Task 6 의 README 가 이 경로를 가리킨다).

- [ ] **Step 1: 문단 단언과 줄 수 상한을 테스트에 넣는다**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh` 를 두 곳 고친다.

첫째 — 이 두 줄을

```bash
# 2026-10-22 R8 계획 2: 진입 단계 `### 1.5 의존 확인`(펜스 · 결과 표)을 더한다. 삭제 0 의 순증이라 래칫을 올린다 — 실측 586 + 8.
SKILL_LINE_CAP=594
```

이 세 줄로 바꾼다.

```bash
# 2026-10-22 R8 계획 2: 진입 단계 `### 1.5 의존 확인`(펜스 · 결과 표)을 더한다. 삭제 0 의 순증이라 래칫을 올린다 — 실측 586 + 8.
# 2026-11-15 있는 것 먼저: 「있는 것 먼저」 문단에 대상 · 기본 · 정보 여섯 칸 · 조사 규약 · 기준 글 Read 줄을 더한다. 순증이라 래칫을 올린다 — 실측 596 + 8.
SKILL_LINE_CAP=604
```

둘째 — 이 줄

```bash
# 제거 (G7·AC1·AC14) — 존재 검사가 아니라 부재 검사이므로 CI_ALL 전체
```

바로 위에 아래 블록과 빈 줄 하나를 넣는다.

```bash
# 있는 것 먼저 — 문단이 대상 · 기본 · 정보 여섯 칸 · 조사 규약 · 기준 글 Read 줄을 담는다(문단 창 안에서만 잰다)
EF_PARA="$(awk '/^\*\*있는 것 먼저\.\*\*/{f=1} /^`open-researcher` 를 띄우는 메시지마다/{f=0} f' "$SKILL")"
for lit in '바깥의 있는 것(플랫폼 기본 기능 · 남이 만들어 유지하는 플러그인과 skill · 널리 쓰이는 패키지와 도구)을 웹으로 찾는다.' \
           '기본은 맞는 것이 있으면 그 위에서 만드는 쪽이다.' \
           '후보마다 정보 여섯 칸(공식인가 · 널리 쓰임과 재는 단위 · 유지 · 안정 단계 · 실행하고 닿는 것과 알려진 보안 문제 · 라이선스와 의무)을 함께 싣는다.' \
           '바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다.' \
           '만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.' \
           '조사를 띄우는 일은 이 skill 의 조사 규약(조사 agent · 띄우기 전 펜스 · 주장 계약 · 본체 확인 · 호출 상한)을 그대로 따른다.' \
           'Read ${CLAUDE_PLUGIN_ROOT}/references/existing-first.md'; do
  assert_contains "$EF_PARA" "$lit" "있는 것 먼저: 문단에 «${lit}»"
done
assert_not_contains "$EF_PARA" '바깥의 성숙한 것' "있는 것 먼저: 옛 「성숙한 것」 없음(양성 짝: 위 대상 단언)"
```

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | tail -n 1`
Expected: 끝줄이 `Fail: 6` 으로 끝난다 — 실패한 단언은 「있는 것 먼저:」로 시작하는 여섯(새 문장 다섯 + 옛 「성숙한 것」)이고, 줄 수 상한 두 줄은 통과한다.

- [ ] **Step 3: 원문과 라이선스를 받는다**

```bash
mkdir -p .claude/existing-first-work/upstream
gh api 'repos/affaan-m/everything-claude-code/contents/skills/search-first/SKILL.md?ref=0765f7a2ca2bd5df214d3aa7ba7e7ac19db8b189' -H 'Accept: application/vnd.github.raw' > .claude/existing-first-work/upstream/search-first.SKILL.md
gh api 'repos/affaan-m/everything-claude-code/contents/LICENSE?ref=0765f7a2ca2bd5df214d3aa7ba7e7ac19db8b189' -H 'Accept: application/vnd.github.raw' > .claude/existing-first-work/upstream/LICENSE
shasum -a 256 .claude/existing-first-work/upstream/search-first.SKILL.md
```

Expected: `76835db48dd910061d2e4271b1151793d2fddbabeb2d2866eed068b3580c55d5`. 다르면 멈추고 보고한다. 받은 파일은 읽기만 하고 실행하지 않는다.

- [ ] **Step 4: 우리 절을 적는다**

`.claude/existing-first-work/ours.md` 를 아래 글자 그대로 만든다(마지막 줄은 `---` 뒤의 빈 줄 하나다).

````markdown
# 있는 것 먼저 — 검토하고 적는 법

설계문서의 `## 있는 것 검토` 절을 쓸 때 따른다. 길을 정해 주지 않는다 — 아래 재료로 견줘서 고르고 이유를 적으며, 고른 것은 사용자가 승인한다.

1. **기본.** 맞는 있는 것이 있으면 그 위에서 만든다. 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.
2. **대상.** 레포 안의 것, 플랫폼 기본 기능, 남이 만들어 유지하는 플러그인과 skill, 널리 쓰이는 패키지와 도구. 실험 딱지가 붙은 것과 에이전트 조율용 프레임워크도 같은 길을 탄다.
3. **탐색 증거가 먼저다.** 결론보다 앞에 어디를 찾았는지와 찾은 후보를 이름으로 적는다.
   - 찾지 못한 곳(도구가 없거나 꺼져 있던 곳)은 못 찾았다고 적는다.
   - 찾지 않기로 한 곳은 그 일에 대한 구체 이유와 함께 적는다. 「해당 없음」 같은 일반 문구로는 서지 않는다.
   - 「없음」은 찾은 곳과 함께일 때만 선다.
   - 바깥을 찾기 전에 환경 변수 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 을 본다. 값이 정확히 `1` 이면 웹과 네트워크로는 찾지 않고, 그 곳은 「웹이 꺼져 찾지 못함」으로 적는다.
   - 아래 영어 절이 드는 찾을 곳은 예시다. 그 레포의 언어와 도구에 맞는 곳을 찾는다.
   - 찾는 일을 누가 어떻게 띄우는지는 부른 자리의 조사 규약을 따른다. 규약이 없는 자리에서는 모델이 정하고 무엇을 띄웠는지 적는다.
4. **바깥 후보마다 보이는 정보 여섯.** 그 레포가 의존으로 적어 둔 남의 것도 바깥 후보다. 레포 안 것은 해당하는 칸만 적는다. 칸마다 그 자리에서 확인한 출처와 날짜를 붙이고, 확인하지 못한 칸은 「확인 못 함」으로 적는다. 여섯 다 문턱이 아니라 보이는 정보다. 점수는 매기지 않는다.
   - 만든 쪽이 공식으로 내는가
   - 널리 쓰이는가 — 재는 단위와 함께
   - 지금도 유지되는가
   - 안정 단계 — 실험 딱지와 알려진 한계
   - 무엇을 실행하고 무엇에 닿는가, 알려진 보안 문제
   - 라이선스와 그것이 지우는 의무
5. **맞는지.** 후보마다 그 설계의 요구 문장(목표 · 수용 기준)에 비춰 맞는 곳과 안 맞는 곳을 적는다.
6. **렌즈 둘.** 접점은 작고 맡기는 일은 큰 것을 먼저 본다 — 재는 것은 크기가 아니라 접점 대비 맡기는 일의 양이다. 일반적인 부분은 있는 것을 쓰고, 이 일만의 설계가 담긴 부분은 만든다.
7. **쓰는 꼴.** 그대로 들이기 · 감싸기 · 가져와 덜어 내고 얹기 · 가져와 안을 고치기 · 방식만 빌리기 · 직접 만들기. 부분 채택도 쓰는 것으로 세고 어느 꼴인지 적는다. 라이선스가 없거나 복사를 허락하지 않으면 가져오는 꼴은 고를 수 없다.
8. **견줄 축.** 상류 추적 · 검증과 테스트 부담(안 고칠수록 준다) · 라이선스가 지우는 일 · 사용자 환경에 생기는 의존 · 요구에 맞추기.
9. **직접 만들기의 이유.** 그 후보에 대해 구체로 적을 때만 선다. 예시는 어느 요구 문장에 안 맞는가, 누구 환경에 어떤 의존이 생기고 없으면 무엇이 깨지는가, 라이선스, 안전이다. 상시 규칙이나 앞 결정을 인용하는 것만으로는 서지 않는다. 직접 만들면 탐색이 찾은 빈 곳을 적는다.
10. **승인.** 맞는 후보가 있으면 그 위에서 짓는 안을 추천 안으로 첫 자리에 둔다.
    - 이미 쓰는 것(플랫폼 기본 기능 · 그 레포가 의존으로 적어 둔 것)은 이름으로 모아 한 번에 승인받는다.
    - 새로 들이는 것은 하나씩 승인받는다.
    - 직접 만들기도 승인받는다.
    - 승인은 설계 대화에서 받고, 받은 승인은 이 절의 결론에 고른 것마다 날짜와 사용자가 한 말로 적는다. 대화에서 승인받지 못한 것은 「승인 전」으로 적는다 — 문서를 승인하는 자리는 이 승인을 대신하지 않는다. 「승인 전」이 남으면 계획으로 넘기기 전에 사용자에게 묻는다.
    - 아래 영어 절의 판정표가 권하는 행동은 승인 전에는 제안이다.
11. **수용 기준.** 고른 것마다 수용 기준을 적는다 — 실제로 쓴다, 들였으면 그 레포가 의존을 적는 자리에 적는다, 가져왔으면 라이선스가 지우는 고지를 싣는다.
12. **고침.** 이미 만든 장치를 고치는 설계면 있는 것으로 옮길 수 있는지도 함께 본다.

아래 영어 절은 찾고 견주는 흐름이다. 이 절과 다르면 이 절이 앞선다.

---

````

- [ ] **Step 5: 조립 스크립트로 기준 글과 고지 파일을 만든다**

`.claude/existing-first-work/build_ref.py` 를 아래로 만든다. 줄 번호는 원문의 1-기준 줄 번호다.

```python
#!/usr/bin/env python3
"""기준 글과 고지 파일을 만든다 — 원문에서 줄 범위를 빼고 제자리 수정 넷을 적용한다.

usage: build_ref.py <upstream SKILL.md> <LICENSE> <ours.md> <out existing-first.md> <out NOTICE>
"""
import hashlib
import sys

UP, LIC, OURS, OUT, NOTICE = sys.argv[1:6]
SHA = "76835db48dd910061d2e4271b1151793d2fddbabeb2d2866eed068b3580c55d5"
raw = open(UP, "rb").read()
assert hashlib.sha256(raw).hexdigest() == SHA, "원문이 고정한 커밋의 것과 다르다"
lines = raw.decode("utf-8").split("\n")
assert lines[-1] == "" and len(lines) == 184, len(lines)
lines = lines[:-1]   # 183줄

# (첫 줄, 끝 줄, 이름) — 원문의 1-기준 줄 번호
DELETE = [
    (1, 7, "머리말(frontmatter)"),
    (47, 50, "흐름 그림의 5단계(IMPLEMENT)"),
    (88, 105, "Full Mode (agent)"),
    (106, 127, "Search Shortcuts by Category"),
    (128, 147, "Integration Points"),
    (148, 176, "Examples"),
]
# (줄 번호, 원문 줄, 바꾼 줄)
EDIT = [
    (39, "│     Score candidates (functionality, maint, │", "│     Show candidate facts (functionality,    │"),
    (40, "│     community, docs, license, deps)         │", "│     maint, community, docs, license, deps)  │"),
    (73, "| Package registry | `npm --version`, `python -m pip --version`, or project package manager | Use web/docs search and avoid claiming registry coverage |",
         "| Package registry | `npm --version`, `python -I -m pip --version`, or project package manager | Use web/docs search and avoid claiming registry coverage |"),
    (75, "| MCP/docs tools | Available tool list or local MCP config | Fall back to official docs/web search |",
         "| MCP/docs tools | Available tool list | Fall back to official docs/web search |"),
    (84, "2. Is there an MCP for this? → Check `~/.claude/settings.json` and search",
         "2. Is there an MCP for this? → Check the available tool list and search"),
]
for n, old, new in EDIT:
    assert lines[n - 1] == old, (n, lines[n - 1])
    assert len(old) == len(new) or n in (73, 75, 84), n
    lines[n - 1] = new
gone = set()
for a, b, _ in DELETE:
    gone |= set(range(a, b + 1))
kept = [l for i, l in enumerate(lines, 1) if i not in gone]
ours = open(OURS, encoding="utf-8").read()
assert ours.endswith("---\n\n")
open(OUT, "w", encoding="utf-8").write(ours + "\n".join(kept) + "\n")

lic = open(LIC, encoding="utf-8").read().strip("\n")
note = []
note.append("existing-first.md 의 「# /search-first — Research Before You Code」 부터 끝까지는 아래 글을 가져와 덜어 낸 것이다.")
note.append("")
note.append("출처")
note.append("- 저장소: https://github.com/affaan-m/everything-claude-code")
note.append("- 파일: skills/search-first/SKILL.md")
note.append("- 커밋: 0765f7a2ca2bd5df214d3aa7ba7e7ac19db8b189 (2026-09-27)")
note.append("- 원문 SHA-256: " + SHA)
note.append("- 확인한 날: 2026-11-15")
note.append("")
note.append("뺀 절 (원문 줄 번호)")
for a, b, name in DELETE:
    note.append("- %d~%d행 — %s" % (a, b, name))
note.append("")
note.append("제자리 수정 (원문 줄 번호 · 원문 → 바꾼 글)")
for n, old, new in EDIT:
    note.append("- %d행" % n)
    note.append("  - 원문: " + (old if n != 73 else "아래 바꾼 글에서 「 -I」 를 뺀 줄이다"))
    note.append("  - 바꾼 글: " + new)
note.append("")
note.append("그 밖의 글자는 원문 그대로다.")
note.append("")
note.append("라이선스")
note.append("")
note.append(lic)
open(NOTICE, "w", encoding="utf-8").write("\n".join(note) + "\n")
print("kept %d lines" % len(kept))
```

Run:

```bash
python3 -I .claude/existing-first-work/build_ref.py .claude/existing-first-work/upstream/search-first.SKILL.md .claude/existing-first-work/upstream/LICENSE .claude/existing-first-work/ours.md plugins/spec-distill/references/existing-first.md plugins/spec-distill/references/existing-first.NOTICE.txt
shasum -a 256 plugins/spec-distill/references/existing-first.md plugins/spec-distill/references/existing-first.NOTICE.txt
```

Expected: `kept 83 lines`, 그리고

```
6d1403c2713b7c3f311d0e7a8df070b04bccab8cf0c0d7ff8adb4943c5fc973a  plugins/spec-distill/references/existing-first.md
aa19770aaa7c24dfa8fcb449f21fc338c454ced0601e9da0d156547be278c15b  plugins/spec-distill/references/existing-first.NOTICE.txt
```

첫 값이 다르면 `ours.md` 가 Step 4 의 글자와 다른 것이다 — 그 블록과 견줘 고친다.

- [ ] **Step 6: 인터뷰 문단을 바꾼다**

`plugins/spec-distill/skills/pm-interview/SKILL.md` 의 이 네 줄을

```text
**있는 것 먼저.** 무엇을 만들자는 결정이 열리면, 레포 안의 있는 것(같은 일을 하는 스크립트 · skill · 모듈)을
먼저 찾고, 바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다. 레포 안 후보는 레포 주장(RC)으로,
바깥 후보는 §4 웹 항목으로 brief 에 싣는다. 바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다.
기본은 이렇게 하고, 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.
```

아래 열네 줄로 바꾼다(두 문장 「바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다.」 · 「기본은 이렇게 하고, 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.」는 그대로 남는다).

````text
**있는 것 먼저.** 무엇을 만들자는 결정이 열리면, 레포 안의 있는 것(같은 일을 하는 스크립트 · skill · 모듈)을
먼저 찾고, 바깥의 있는 것(플랫폼 기본 기능 · 남이 만들어 유지하는 플러그인과 skill · 널리 쓰이는 패키지와 도구)을 웹으로 찾는다.
기본은 맞는 것이 있으면 그 위에서 만드는 쪽이다. 레포 안 후보는 레포 주장(RC)으로, 바깥 후보는 §4 웹 항목으로 brief 에 싣되
후보마다 정보 여섯 칸(공식인가 · 널리 쓰임과 재는 단위 · 유지 · 안정 단계 · 실행하고 닿는 것과 알려진 보안 문제 · 라이선스와 의무)을 함께 싣는다.
바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다.
기본은 이렇게 하고, 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.
조사를 띄우는 일은 이 skill 의 조사 규약(조사 agent · 띄우기 전 펜스 · 주장 계약 · 본체 확인 · 호출 상한)을 그대로 따른다.
찾을 곳 · 정보 칸 · 견줄 축은 아래 파일을 Read 로 읽어 따른다.

```
Read ${CLAUDE_PLUGIN_ROOT}/references/existing-first.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.
````

단언은 줄 단위 글자를 찾는다 — 위 줄바꿈 자리를 옮기지 않는다.

- [ ] **Step 7: 테스트가 통과하는지 본다**

```bash
git add plugins/spec-distill/references/existing-first.md plugins/spec-distill/references/existing-first.NOTICE.txt
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | tail -n 1
bash .claude/existing-first-work/touching.sh 'pm-interview' 'references' 'existing-first'
```

Expected: 둘째 명령의 끝줄은 `Fail: 0` 으로 끝난다. 셋째 명령의 `FAILED` 줄은 전부 `suite-base.txt` 에 글자 그대로 있는 줄이어야 한다(새 실패 0). 새 `.md` 는 참고 폴더를 훑는 검사들(웹 스위치의 느슨한 참 판정 · 금지 낱말 · 고아 · 플러그인 루트 경로)의 대상에 자동으로 든다 — 새 실패가 나오면 그 검사의 금지 낱말을 읽고 우리 절의 문장을 고친 뒤 Step 5 를 다시 돌린다(영어 절을 더 고쳐야 하면 `EDIT` 에 줄을 더해 고지 파일에 남기고 사용자에게 보고한다).

- [ ] **Step 8: 가져온 절과 없어야 할 것을 확인한다**

```bash
awk '/^# \/search-first/{f=1} f' plugins/spec-distill/references/existing-first.md > .claude/existing-first-work/vendored-part.md
sed -n '8,$p' .claude/existing-first-work/upstream/search-first.SKILL.md > .claude/existing-first-work/upstream-body.md
diff .claude/existing-first-work/upstream-body.md .claude/existing-first-work/vendored-part.md | grep -c '^>'
grep -n -i -E 'eslint|ruff|textlint|markdownlint|prettier|gofmt|jest|pytest|husky|lint-staged|pre-commit|unstructured|pdfplumber|mammoth|httpx|undici|zod|pydantic|remark|markdown-it|imagemin|ajv|settings\.json|score|general-purpose' plugins/spec-distill/references/existing-first.md
git grep -n -F 'existing-first.NOTICE' -- 'plugins/*/skills/*' 'plugins/*/references/*.md' 'plugins/*/agents/*' CLAUDE.md docs/philosophy
```

Expected: 첫 수는 `5`(더해진 줄은 제자리 수정 다섯 줄뿐 — AC5). 둘째 · 셋째 명령은 출력이 없다(AC4 · AC6). 고지 파일을 열어 저작권 줄 · MIT 전문 · 출처 · 뺀 절 여섯 · 제자리 수정 다섯 줄이 있는지 눈으로 본다(AC6).

- [ ] **Step 9: 커밋한다**

```bash
git add plugins/spec-distill/references/existing-first.md plugins/spec-distill/references/existing-first.NOTICE.txt plugins/spec-distill/skills/pm-interview/SKILL.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): 있는 것 검토를 적는 기준 글과 인터뷰 문단" -m "Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md"
```

- [ ] **Step 10: 변이로 단언의 이빨을 본다 (AC12)**

커밋한 뒤에 한다. `SKILL.md` 를 하나씩 바꾸고 `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | LC_ALL=C grep -a '✗'` 를 돌린 다음 `git checkout HEAD -- plugins/spec-distill/skills/pm-interview/SKILL.md` 로 되돌린다. 끝나면 `git diff HEAD --stat` 이 비어야 한다.

| 변이 | 빨개져야 하는 줄 |
|---|---|
| 대상 문장을 옛 「바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다.」로 | 「옛 「성숙한 것」 없음」과 대상 단언(두 줄) |
| 「기본은 맞는 것이 있으면 그 위에서 만드는 쪽이다. 」를 뺀다 | 그 문장의 단언 한 줄 |
| 정보 여섯 칸 줄을 뺀다 | 그 문장의 단언 한 줄 |
| 조사 규약 줄을 뺀다 | 그 문장의 단언 한 줄 |
| Read 펜스 세 줄을 `<!-- open-research-web:begin -->` 바로 위로 옮긴다 | Read 줄 단언 한 줄(문단 창 밖이다) |
| 「바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다.」 줄을 뺀다 | 그 문장의 단언 한 줄 |

살아남는 변이가 있으면 그 단언을 고치고 다시 돌린다.

---

### Task 3: 넘김 글 넷 — 괄호와 묻는 구절

AC8 · AC10 · AC12.

**Files:**
- Modify: `plugins/spec-distill/skills/pm-interview/references/finishing.md`(「**다음 세션 줄 — ①/② 공통**」 아래 한 줄) · `plugins/spec-distill/references/epic-handoff.md`(「**에픽 넘김 줄**」 아래 한 줄) · `plugins/spec-distill/skills/spec-review/SKILL.md`(`@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라.` 로 시작하는 한 줄) · `plugins/spec-distill/references/conductor-dispatch.md`(구현 agent 틀의 `마지막 전체 리뷰는` 줄)
- Test: `plugins/spec-distill/tests/test_end_gates.sh` · `plugins/spec-distill/tests/test_review_handoff_order.sh` · `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh`

**Interfaces:**
- Consumes: Task 2 가 커밋한 `plugins/spec-distill/references/existing-first.md`.
- Produces: 넘김 줄 둘의 새 괄호(같은 글자)와, 글 넷의 같은 구절.

- [ ] **Step 1: 테스트를 새 문장에 맞춘다**

`plugins/spec-distill/tests/test_end_gates.sh` — `SHARED=` 줄 안의 괄호

```text
(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)
```

를 아래로 바꾼다(작은따옴표 안이라 `${…}` 는 풀리지 않는다).

```text
(맞는 있는 것이 있으면 그 위에서 만드는 것이 기본이다 — 찾아본 후보를 이름으로 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 적어 사용자 승인을 받는다. 레포 밖 것은 후보와 차이를 보여 사용자가 승인한 뒤에만 쓴다. 적는 법은 ${CLAUDE_PLUGIN_ROOT}/references/existing-first.md 를 읽어 따른다)
```

같은 파일의 이 줄

```bash
assert_contains "$BL" "$SHARED" "AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다"
```

바로 아래에 넣는다.

```bash
# 있는 것 먼저 — 넘김 줄 둘의 마지막 전체 리뷰가 고른 것을 썼는지도 묻는다(같은 글자: test_review_handoff_order.sh · test_conductor_dispatch_reference.sh)
USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
assert_contains "$BL" "$USED" "있는 것 먼저: brief 넘김 줄의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다"
assert_contains "$EL" "$USED" "있는 것 먼저: 에픽 넘김 줄의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다"
```

`plugins/spec-distill/tests/test_review_handoff_order.sh` — 이 줄(들여쓰기 네 칸)

```bash
    assert_not_contains "$RSL" 'SDD 의 마지막 전체 리뷰' "AC42: 다음 세션 줄이 SDD 로 고정하지 않는다(양성 짝: 위 줄)"
```

바로 아래에 같은 들여쓰기로 넣는다.

```bash
    USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
    assert_contains "$RSL" "$USED" "있는 것 먼저: 승인 게이트 다음 세션 줄의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다(같은 글자: test_end_gates.sh)"
```

`plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` — `"구현 틀: 마지막 전체 리뷰에 이음매 · 계획이 쓴 테스트 코드"` 로 끝나는 `assert_contains "$IMPL" …` 줄 바로 아래에 넣는다.

```bash
USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
assert_contains "$IMPL" "$USED" "구현 틀: 마지막 전체 리뷰가 고른 것을 썼는지 묻는다(같은 글자: test_end_gates.sh)"
```

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run:

```bash
bash plugins/spec-distill/tests/test_end_gates.sh 2>&1 | tail -n 1
bash plugins/spec-distill/tests/test_review_handoff_order.sh 2>&1 | tail -n 1
bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -n 1
```

Expected: 끝줄이 차례로 `Fail: 4`(`AC22` 둘 + 「있는 것 먼저」 둘) · `Fail: 1` · `Fail: 1` 로 끝난다.

- [ ] **Step 3: 넘김 줄 둘의 괄호를 바꾼다**

`finishing.md` 와 `epic-handoff.md` 에서 각각 한 번 나오는 옛 괄호(Step 1 의 첫 블록)를 새 괄호(Step 1 의 둘째 블록)로 바꾼다. 두 파일에서 같은 글자다. 조각 「## 있는 것 검토 절」과 「사용자가 승인한 뒤에만」은 새 괄호에도 남는다(다른 테스트가 그 조각을 읽는다).

- [ ] **Step 4: 글 넷에 묻는 구절을 더한다**

`finishing.md` · `epic-handoff.md` · `spec-review/SKILL.md` — 세 파일에 각각 한 번 나오는

```text
보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다.
```

바로 뒤에 한 문장을 잇는다(앞에 빈칸 하나).

```text
 그 리뷰가 설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.
```

`conductor-dispatch.md` — 한 번 나오는

```text
와 계획이 쓴 테스트 코드도 묻게 한다.
```

바로 뒤에 한 문장을 잇는다(앞에 빈칸 하나).

```text
 설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.
```

넷 다 같은 줄 안에 잇는다 — 줄을 나누지 않는다. AC 보고 파일의 꼴(`AC1: 구현됨 — 근거`)은 그대로다. 지휘 절차서(`references/conducting.md`)의 「마지막 전체 리뷰」 문장은 고치지 않는다(설계 §7).

- [ ] **Step 5: 테스트가 통과하는지 본다**

```bash
bash plugins/spec-distill/tests/test_end_gates.sh 2>&1 | tail -n 1
bash plugins/spec-distill/tests/test_review_handoff_order.sh 2>&1 | tail -n 1
bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -n 1
bash .claude/existing-first-work/touching.sh 'finishing\.md' 'epic-handoff' 'spec-review' 'conductor-dispatch'
```

Expected: 앞의 셋은 끝줄이 `Fail: 0` 으로 끝난다. 넷째의 `FAILED` 줄은 전부 `suite-base.txt` 에 있는 줄이어야 한다(새 실패 0) — 넘김 줄의 자리표 수 · 첫 토큰 · 순서를 읽는 테스트들이 여기 든다.

- [ ] **Step 6: 커밋한다**

```bash
git add plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/references/conductor-dispatch.md plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
git commit -m "feat(spec-distill): 넘김 글이 있는 것 위에서 만들기를 기본으로 싣고 마지막 리뷰가 고른 것을 썼는지 묻는다" -m "Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md"
```

- [ ] **Step 7: 변이로 단언의 이빨을 본다 (AC12)**

커밋한 뒤에 한다. 파일 하나를 바꾸고 표의 테스트를 `bash <테스트> 2>&1 | LC_ALL=C grep -a '✗'` 로 돌린 다음 `git checkout HEAD -- <그 파일>` 로 되돌린다. 끝나면 `git diff HEAD --stat` 이 비어야 한다.

| 변이 | 테스트 | 빨개져야 하는 줄(하나씩) |
|---|---|---|
| `finishing.md` 의 괄호를 옛 문장으로 | `test_end_gates.sh` | 「AC22: brief 줄의 원칙 문장…」 |
| `epic-handoff.md` 의 괄호를 옛 문장으로 | `test_end_gates.sh` | 「AC22(양성 대조)…」 |
| `finishing.md` 에서 더한 문장을 뺀다 | `test_end_gates.sh` | 「brief 넘김 줄의 마지막 전체 리뷰…」 |
| `epic-handoff.md` 에서 더한 문장을 뺀다 | `test_end_gates.sh` | 「에픽 넘김 줄의 마지막 전체 리뷰…」 |
| `epic-handoff.md` 의 구절에서 「썼는지」를 「쓰는지」로 | `test_end_gates.sh` | 「에픽 넘김 줄의 마지막 전체 리뷰…」 |
| `spec-review/SKILL.md` 에서 더한 문장을 뺀다 | `test_review_handoff_order.sh` | 「승인 게이트 다음 세션 줄의 마지막 전체 리뷰…」 |
| `conductor-dispatch.md` 에서 더한 문장을 뺀다 | `test_conductor_dispatch_reference.sh` | 「구현 틀: 마지막 전체 리뷰가 고른 것을 썼는지…」 |

---

### Task 4: 설계문서 리뷰 기준 — 있는 항목을 넓힌다

AC9 · AC12. 이 파일은 리뷰어 페르소나다 — 더하기만 한다.

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`(층 2 의 `approaches_comparison` 한 줄)
- Test: `plugins/spec-distill/tests/test_handoff_design_mode.sh`

**Interfaces:**
- Consumes: 없음.
- Produces: 넓힌 `approaches_comparison` 항목. 항목 이름 · 머리말(`layer_rubric` · `must_catch`) · 다른 항목은 그대로다.

- [ ] **Step 1: 항목 단언을 테스트에 넣는다**

`plugins/spec-distill/tests/test_handoff_design_mode.sh` 의 끝 두 줄

```bash
done
finish
```

을 아래로 바꾼다.

```bash
done

# approaches_comparison 항목이 「있는 것 검토」 절도 읽는다 — 낼 때 여섯 · 처분 · 한계(항목 창 안에서만 잰다)
AC_ITEM="$(awk '/^- `approaches_comparison`/{f=1} /^- `isolation`/{f=0} f' "$PROFILE")"
for lit in '`## 있는 것 검토` 절도 이 항목이 읽는다' \
           '1. 「있는 것 검토」 절이 없고 「해당 없음 — 이유」도 없다.' \
           '2. 찾아본 후보가 이름으로 없거나, 「없음」이 어디를 찾았는지 없이 적혔거나, 찾지 않은 곳의 이유가 그 일에 대한 구체가 아니라 일반 문구다.' \
           '3. 후보마다 이 문서의 요구 문장(목표 · 수용 기준)에 비춘 맞음 판정이 없다.' \
           '4. 바깥 후보의 정보 여섯 칸(만든 쪽이 공식으로 내는가 · 널리 쓰이는가와 재는 단위 · 지금도 유지되는가 · 안정 단계 · 무엇을 실행하고 무엇에 닿는가와 알려진 보안 문제 · 라이선스와 그것이 지우는 의무)에 출처와 확인 날짜가 없고 「확인 못 함」 표시도 없다.' \
           '5. 직접 만들기 결론의 이유가 그 후보에 대한 구체가 아니라 상시 규칙이나 앞 결정의 인용뿐이다.' \
           '6. 고른 것마다 수용 기준이 없다.' \
           '빠진 사실을 채우는 것이면 `fix`, 저자에게 그 사실이 없으면 그 `fix` 를 막는 `ask`, 쓰기와 만들기의 결론을 바꾸자는 것이면 `decide` 다.' \
           '이 리뷰는 웹을 보지 않는다 — 절을 읽을 뿐 바깥을 새로 찾지 않으며, 빠진 후보는 문서나 레포에 근거가 있을 때만 지적한다.'; do
  assert_contains "$AC_ITEM" "$lit" "있는 것 먼저: approaches_comparison 항목에 «${lit}»"
done
MC="$(sed -n 's/^must_catch:[[:space:]]*//p' "$PROFILE" | head -1)"
assert_eq "$MC" '[goal_fit, problem_definition, scope, architecture, required_sections]' "있는 것 먼저: 꼭 잡을 항목 목록은 그대로다(approaches_comparison 을 올리지 않는다)"
finish
```

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_handoff_design_mode.sh 2>&1 | tail -n 1`
Expected: 끝줄이 `Fail: 9` 로 끝난다 — 실패한 단언은 「있는 것 먼저: approaches_comparison 항목에 …」 아홉이고, `must_catch` 단언은 통과한다(지금도 그 값이다).

- [ ] **Step 3: 항목을 넓힌다**

`plugins/spec-distill/references/docreview-profiles/design-doc.md` 의 이 한 줄을

```markdown
- `approaches_comparison` — 대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적.
```

아래 아홉 줄로 바꾼다(첫 줄은 옛 줄 뒤에 문장을 이은 것이고, 아래 줄들은 들여쓰기 두 칸이다).

```markdown
- `approaches_comparison` — 대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적. `## 있는 것 검토` 절도 이 항목이 읽는다 — 있는 것이라는 대안을 견주는 자리다. 아래 여섯 가운데 하나면 낸다.
  1. 「있는 것 검토」 절이 없고 「해당 없음 — 이유」도 없다.
  2. 찾아본 후보가 이름으로 없거나, 「없음」이 어디를 찾았는지 없이 적혔거나, 찾지 않은 곳의 이유가 그 일에 대한 구체가 아니라 일반 문구다.
  3. 후보마다 이 문서의 요구 문장(목표 · 수용 기준)에 비춘 맞음 판정이 없다.
  4. 바깥 후보의 정보 여섯 칸(만든 쪽이 공식으로 내는가 · 널리 쓰이는가와 재는 단위 · 지금도 유지되는가 · 안정 단계 · 무엇을 실행하고 무엇에 닿는가와 알려진 보안 문제 · 라이선스와 그것이 지우는 의무)에 출처와 확인 날짜가 없고 「확인 못 함」 표시도 없다.
  5. 직접 만들기 결론의 이유가 그 후보에 대한 구체가 아니라 상시 규칙이나 앞 결정의 인용뿐이다.
  6. 고른 것마다 수용 기준이 없다.

  처분은 빠진 사실을 채우는 것이면 `fix`, 저자에게 그 사실이 없으면 그 `fix` 를 막는 `ask`, 쓰기와 만들기의 결론을 바꾸자는 것이면 `decide` 다. 이 리뷰는 웹을 보지 않는다 — 절을 읽을 뿐 바깥을 새로 찾지 않으며, 빠진 후보는 문서나 레포에 근거가 있을 때만 지적한다.
```

머리말은 건드리지 않는다. 새 항목 이름을 만들지 않는다(항목 이름마다 공유 리뷰 엔진에 사람말 한 줄이 있어야 한다 — 설계 「Rejected Alternatives」).

- [ ] **Step 4: 테스트가 통과하고 더하기만 했는지 본다**

```bash
bash plugins/spec-distill/tests/test_handoff_design_mode.sh 2>&1 | tail -n 1
bash .claude/existing-first-work/touching.sh 'design-doc' 'docreview-profiles' 'approaches_comparison'
git diff --numstat -- plugins/spec-distill/references/docreview-profiles/design-doc.md
```

Expected: 첫 명령의 끝줄은 `Fail: 0` 으로 끝난다. 둘째의 `FAILED` 줄은 전부 `suite-base.txt` 에 있는 줄이어야 한다(프로필 스키마 · 프로필 문장 락 · codex 프롬프트의 층 2 줄을 읽는 공유 테스트들이 여기 든다). 셋째는 `9	1	…` — 지운 줄은 문장을 이어 다시 쓴 그 한 줄뿐이다.

- [ ] **Step 5: 커밋한다**

```bash
git add plugins/spec-distill/references/docreview-profiles/design-doc.md plugins/spec-distill/tests/test_handoff_design_mode.sh
git commit -m "feat(spec-distill): 설계문서 리뷰의 대안 비교 항목이 있는 것 검토 절도 읽는다" -m "리뷰 프로필(페르소나) 편집 — 더하기만 했다. 보안 리뷰 대상." -m "Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md"
```

- [ ] **Step 6: 변이로 단언의 이빨을 본다 (AC12)**

커밋한 뒤에 한다. 프로필을 하나씩 바꾸고 `bash plugins/spec-distill/tests/test_handoff_design_mode.sh 2>&1 | LC_ALL=C grep -a '✗'` 를 돌린 다음 `git checkout HEAD -- plugins/spec-distill/references/docreview-profiles/design-doc.md` 로 되돌린다. 끝나면 `git diff HEAD --stat` 이 비어야 한다.

| 변이 | 빨개져야 하는 줄(하나씩) |
|---|---|
| 1번 줄을 뺀다 | 「…«1. 「있는 것 검토」 절이 없고…»」 |
| 4번의 칸 이름에서 「 · 라이선스와 그것이 지우는 의무」를 뺀다 | 「…«4. 바깥 후보의 정보 여섯 칸…»」 |
| 6번 줄을 `testing` 항목 줄 바로 위(`isolation` 항목 아래)로 옮긴다 | 「…«6. 고른 것마다 수용 기준이 없다.»」 |
| 한계 문장(「이 리뷰는 웹을 보지 않는다 — …」)을 뺀다 | 그 문장의 단언 |
| 처분 문장 끝의 `decide` 를 `fix` 로 바꾼다 | 처분 문장의 단언 |
| 머리말 `must_catch` 끝에 `approaches_comparison` 을 더한다 | 「꼭 잡을 항목 목록은 그대로다…」 |

---

### Task 5: 규칙 문장 둘

AC1 · AC2.

**Files:**
- Modify: `CLAUDE.md`(「**있는 것 먼저.**」 줄) · `docs/philosophy/devbrew-harness-philosophy.md`(P8 의 「(재사용)」 줄)

**Interfaces:**
- Consumes: Task 2 가 커밋한 `plugins/spec-distill/references/existing-first.md`(철학 문서가 가리킨다 — 헌장 인용 검사는 추적되는 경로만 실재로 본다).
- Produces: 없음.

- [ ] **Step 1: CLAUDE.md 의 줄을 바꾼다**

이 줄을

```markdown
- **있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8).
```

아래로 바꾼다. 머리 낱말 「있는 것 먼저」는 그대로 둔다.

```markdown
- **있는 것 먼저.** 설계를 타는 일에서 기본은 맞는 있는 것(레포 안 · 플랫폼 기본 기능 · 남이 유지하는 것) 위에서 만든다 — 찾아본 후보를 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 대고 사용자 승인을 받는다. 외부 것은 후보와 차이를 보이고 사용자 승인 뒤 쓴다. 작은 변경은 지금처럼 그냥 고친다(철학 P8).
```

- [ ] **Step 2: 철학 문서의 줄을 바꾼다**

이 줄을

```markdown
- (재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17).
```

아래로 바꾼다. 머리 낱말 「(재사용)」은 그대로 둔다.

```markdown
- (재사용) 새로 만든 것은 유지할 표면이 되므로, 설계를 타는 일에서는 맞는 있는 것이 있으면 그 위에서 만드는 것이 기본이다 — 레포 안 · 밖에서 찾아본 후보를 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 대고 사용자 승인을 받는다. 외부 것은 사용자가 검토한 뒤에 쓴다(P17). 작은 변경은 지금처럼 그냥 고친다. 코드: `plugins/spec-distill/references/existing-first.md`
```

- [ ] **Step 3: 두 문서를 읽는 테스트를 돈다**

```bash
bash shared/tests/test_charter_citations.sh 2>&1 | tail -n 1
bash .claude/existing-first-work/touching.sh 'CLAUDE\.md' 'philosophy'
```

Expected: 첫 명령의 끝줄은 `Fail: 0` 으로 끝난다(철학 문서가 가리키는 경로가 추적되는 파일로 실재한다). 둘째의 `FAILED` 줄은 전부 `suite-base.txt` 에 있는 줄이어야 한다.

- [ ] **Step 4: 커밋한다**

```bash
git add CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md
git commit -m "docs: 있는 것 먼저 — 맞는 있는 것 위에서 만들기를 기본으로" -m "Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md"
```

---

### Task 6: 판 · CHANGELOG · README

AC14.

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`

**Interfaces:**
- Consumes: 앞 과제들이 바꾼 것.
- Produces: 새 판 `<새 판>`.

- [ ] **Step 1: 새 판을 정한다**

```bash
git fetch origin
git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json
```

`<새 판>` 은 기본 브랜치의 판에서 minor 를 하나 올리고 patch 를 0 으로 둔 값이다(계획을 쓴 날 기준 `8.15.0` → `8.16.0`). 기본 브랜치가 Task 1 뒤로 움직였으면 `git merge origin/main` 으로 다시 맞추고 CHANGELOG 충돌은 두 머리를 모두 살려 푼다. `plugin.json` 의 `"version"` 을 `<새 판>` 으로 바꾼다.

- [ ] **Step 2: CHANGELOG 머리를 더한다**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 줄과 그 아래 빈 줄 다음에 아래 블록을 넣는다(`<새 판>` 과 `<커밋 날짜 YYYY-MM-DD>` 를 채운다. 블록 뒤에 빈 줄 하나).

```markdown
## [<새 판>] — <커밋 날짜 YYYY-MM-DD>

### Added
- `references/existing-first.md` — 설계문서의 「있는 것 검토」 절을 적는 법. 맞는 있는 것이 있으면 그 위에서 만드는 것이 기본이고, 찾은 곳과 후보를 결론보다 먼저 적고, 바깥 후보마다 정보 여섯 칸(공식인가 · 널리 쓰임과 재는 단위 · 유지 · 안정 단계 · 실행하고 닿는 것과 알려진 보안 문제 · 라이선스와 의무)을 출처 · 날짜와 함께 보이며, 직접 만들기는 후보별 구체 이유와 사용자 승인을 거친다.
- `references/existing-first.NOTICE.txt` — 위 파일 뒤쪽 영어 절의 고지. 그 절은 공개 skill search-first(`affaan-m/everything-claude-code` 의 `skills/search-first/SKILL.md`, 커밋 `0765f7a2ca2bd5df214d3aa7ba7e7ac19db8b189`, MIT, Copyright (c) 2026 Affaan Mustafa)를 가져와 덜어 낸 것이다 — 저작권 줄 · MIT 전문 · 뺀 절 · 제자리 수정이 이 파일에 있다.

### Changed
- 인터뷰의 「있는 것 먼저」 문단 — 바깥 대상을 플랫폼 기본 기능 · 남이 만들어 유지하는 플러그인과 skill · 널리 쓰이는 패키지와 도구로 적고, 맞는 것이 있으면 그 위에서 만드는 쪽을 기본으로 두며, 바깥 후보를 brief 에 실을 때 정보 여섯 칸을 함께 싣는다. 찾을 곳 · 정보 칸 · 견줄 축은 `references/existing-first.md` 를 읽어 따르고, 조사를 띄우는 일은 인터뷰의 조사 규약 그대로다.
- brief 넘김 줄과 에픽 넘김 줄의 「있는 것 검토 절」 괄호 — 「맞는 있는 것이 있으면 그 위에서 만드는 것이 기본」 · 후보를 이름으로 먼저 · 직접 만들기는 후보별 구체 이유와 사용자 승인 · 적는 법은 `references/existing-first.md`. 옛 괄호로 이미 쓰인 설계문서는 그대로 읽힌다.
- 넘김 줄 둘 · 설계문서 리뷰의 다음 세션 줄 · 구현 담당자 틀의 마지막 전체 리뷰가 설계문서 「있는 것 검토」 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻는다.
- 설계문서 리뷰 프로필 층 2 `approaches_comparison` — 「있는 것 검토」 절도 읽는다(낼 때 여섯 · 처분 · 웹을 보지 않는 한계). 항목 목록 · 꼭 잡을 항목 · 다른 항목은 그대로다. 이 항목이 내는 지적은 게이트와 참고 목록에서 지금 이름 「대안 비교 없는 단정」 으로 보인다.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` — 설계 세션이 `references/existing-first.md` 를 따라 바깥을 찾는 일도 이 스위치를 보게 적었다. 그 글의 문장이 전부이고 막는 펜스나 훅은 없다.
```

- [ ] **Step 3: README 네 곳을 고친다**

`plugins/spec-distill/README.md`:

1. 「### Principles 흡수」 목록의 `- **P8 (이식성) — 의존 판** —` 줄 바로 위에 한 줄을 넣는다.

```markdown
- **P8 (재사용) — 있는 것 먼저** — 설계를 타는 일에서 맞는 있는 것이 있으면 그 위에서 만드는 것을 기본으로 둔다. 적는 법은 `references/existing-first.md` 한 곳에 있고, 인터뷰의 「있는 것 먼저」 문단과 넘김 줄 둘이 그 글을 가리킨다. 설계문서 리뷰의 층 2 `approaches_comparison` 이 「있는 것 검토」 절을 읽고, 마지막 전체 리뷰가 고른 것을 실제로 썼는지 묻는다.
```

2. `- \`references/conducting.md\` — 지휘 순환 걸음 1~7` 로 시작하는 줄 바로 위에 한 줄을 넣는다.

```markdown
- `references/existing-first.md` — 설계문서의 「있는 것 검토」 절을 적는 법(기본 · 대상 · 탐색 증거 · 정보 여섯 칸 · 맞는지 · 렌즈 · 쓰는 꼴 · 견줄 축 · 직접 만들기의 이유 · 승인 · 수용 기준 · 고침). 인터뷰와 설계 세션이 읽습니다. 뒤쪽 영어 절은 MIT 로 가져온 글이고 고지는 `references/existing-first.NOTICE.txt` 에 있습니다.
```

3. `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 항목의 끝 줄(들여쓰기 두 칸) `  자리)도 끈다 — 조회 직전마다 정확히 \`1\` 인지 보고, 켜져 있으면 조회를 건너뛴다.` 바로 아래에 같은 들여쓰기로 한 줄을 넣는다. 그 항목의 「**두 자리**」는 그대로 둔다(다른 테스트가 읽는다).

```markdown
  설계 세션이 `references/existing-first.md` 를 따라 바깥을 찾는 일도 이 스위치를 보게 적혀 있다 — 그 글의 문장이 전부이고, 막는 펜스나 훅은 없다.
```

4. 「## License」 절의 `(devbrew root 정책 따름.)` 아래에 빈 줄 하나와 한 줄을 넣는다.

```markdown
`references/existing-first.md` 의 뒤쪽 영어 절은 MIT 로 가져온 글이다 — 저작권 줄 · 전문 · 출처는 `references/existing-first.NOTICE.txt`.
```

의존 표(`dependencies.md`)에는 줄을 더하지 않는다 — 가져온 글은 실행 때 기대는 의존이 아니다(설계 §10).

- [ ] **Step 4: 판과 문서를 읽는 테스트를 돈다**

```bash
bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -n 1
bash .claude/existing-first-work/touching.sh 'README' 'CHANGELOG' 'plugin\.json'
```

Expected: 첫 명령의 끝줄은 `Fail: 0` 으로 끝난다(CHANGELOG 머리가 `plugin.json` 과 같고 바로 다음 판이다). 둘째의 `FAILED` 줄은 전부 `suite-base.txt` 에 있는 줄이어야 한다.

- [ ] **Step 5: 커밋한다**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "chore(spec-distill): <새 판> — 있는 것 위에서 만들기를 기본으로" -m "Spec: docs/superpowers/specs/2026-11-15-existing-framework-first-design.md"
```

---

### Task 7: 끝 검증 · 마지막 전체 리뷰 · 넘길 글

AC12(변이 결과 모음) · AC13 · AC15, 그리고 AC1~AC15 의 구현 대조.

**Files:**
- Create(추적 안 함): `.claude/existing-first-work/suite-after.txt` · `.claude/existing-first-work/hand-check.md` · `.claude/existing-first-work/ac-report.md` · `.claude/existing-first-work/pr-body.md` · `.claude/existing-first-work/conductor-notes.md`
- Modify: `docs/superpowers/specs/2026-11-15-existing-framework-first-design.md`(「## 미룸」 표 — 마지막 리뷰가 미룸 · 빠짐을 냈을 때만)

**Interfaces:**
- Consumes: Task 1 의 `suite-base.txt` · `overlap.md`, Task 2~6 의 커밋.
- Produces: AC 보고 파일 `.claude/existing-first-work/ac-report.md`(한 줄에 `AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거`), PR 본문 초안, 두 지휘 세션에 전할 글.

- [ ] **Step 1: 전체 스위트를 기준선과 견준다 (AC13)**

`pgrep -fl tools/suite/run-all.sh` 가 비었는지 본 뒤 돌린다.

```bash
bash tools/suite/run-all.sh > .claude/existing-first-work/suite-after.txt
LC_ALL=C comm -13 .claude/existing-first-work/suite-base.txt .claude/existing-first-work/suite-after.txt
```

Expected: 둘째 명령의 출력이 없다(기준 대비 새 실패 0). 줄이 나오면 `superpowers:systematic-debugging` 으로 원인을 찾는다 — 그 테스트 하나를 편집 전 커밋에서 다시 돌려 부하 탓의 흔들림인지부터 가른다.

- [ ] **Step 2: 손 확인 한 번**

새 하위 agent 하나를 띄운다(맥락 없이). 보내는 글에는 `plugins/spec-distill/references/existing-first.md` 의 전문과 Task 3 의 새 괄호 문장만 싣고, 작은 가상 설계(「마크다운 문서의 깨진 링크를 찾는 검사를 레포에 더한다」)의 `## 있는 것 검토` 절을 쓰게 한다. 돌아온 글에 넷이 있는지 본다 — 탐색 증거(찾은 곳과 후보 이름) · 정보 여섯 칸(출처와 날짜 또는 「확인 못 함」) · 승인 요청 · 고른 것의 수용 기준. 결과를 `.claude/existing-first-work/hand-check.md` 에 적는다. 측정 장치가 아니라 처음 돌아가는 모습을 보는 한 번이다 — 빠진 것이 있으면 그 사실을 사용자에게 보고하고, 고칠지는 사용자가 정한다.

- [ ] **Step 3: 마지막 전체 리뷰 — AC 보고**

고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC1~AC15 를 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 한다. 그 보고를 `.claude/existing-first-work/ac-report.md` 에 적는다. 리뷰에 함께 묻는다:

- 설계문서 `## 있는 것 검토` 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지) — search-first 는 가져와 덜어 내고 얹었는가, search-before-building 과 codebase-design 에서는 글자를 가져오지 않았는가.
- 과제 사이 이음매 — 기준 글의 경로와 구절이 그것을 가리키는 자리 여섯(인터뷰 문단 · 넘김 줄 둘 · 철학 문서 · README · CHANGELOG)에서 같은가, 넘김 글 넷의 구절이 같은 글자인가.
- 이 계획이 쓴 테스트 코드(Task 2 · 3 · 4 의 단언) — 창을 자르는 `awk` 가 비면 단언이 실패하는가, bash 3.2 에서 도는가.
- 리뷰 프로필 편집(보안 리뷰) — 지운 줄이 다시 쓴 한 줄뿐인가, 머리말 · 다른 항목 · 처분 · 임계가 그대로인가, 넓힌 문장이 리뷰어를 약하게 만드는 곳이 없는가.

AC15(PR 본문)는 Step 5 의 초안이 있으면 「구현됨 — 초안 경로」로, PR 을 아직 열지 않았다는 사실과 함께 적는다.

- [ ] **Step 4: 미룸을 올리고 구현 대조를 돈다**

보고에 미룸 · 빠짐이 있거나 리뷰 후속으로 미룬 것이 있으면 설계문서 `## 미룸` 표에 행(항목 · 이유 · 받는 곳 — 칸 셋 모두 채운다)으로 올리고 커밋한다. 그다음:

```bash
python3 plugins/spec-distill/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-15-existing-framework-first-design.md .claude/existing-first-work/ac-report.md
```

Expected: `구현 대조:` 로 시작하는 첫 줄. 경고가 있으면 그 줄들을 고치지 말고 그대로 사용자에게 보인다.

- [ ] **Step 5: PR 본문 초안과 지휘 세션에 전할 글을 쓴다 (AC15)**

`.claude/existing-first-work/pr-body.md` — 한국어로 쓰고 아래 절을 담는다.

- 무엇을 왜 바꿨는지(설계문서 경로와 함께).
- **「다른 로드맵이 예약한 파일을 고친다」** — Task 1 의 `overlap.md` 를 옮긴 표(파일 · 주인 에픽 · 바뀐 문장 · 뒤에 머지하는 쪽이 할 일). 「할 일」 칸에는 괄호를 글자로 박은 테스트(`tests/test_end_gates.sh` 의 `SHARED`)와 인터뷰 skill 줄 수 상한(`SKILL_LINE_CAP`)을 적는다.
- **「리뷰 프로필(페르소나) 편집 — 보안 리뷰 대상」** — 바뀐 항목, 더하기만 했다는 사실, 변이 결과.
- 가져온 글 — 출처 · 커밋 · 라이선스 · 고지 파일 경로.
- 검증 — 전체 스위트 대조 결과, 변이 표 결과(Task 2 · 3 · 4), 손 확인 결과, 구현 대조 첫 줄.
- 설계 리뷰의 공시 — 3라운드는 codex 없이 판정했다, 리뷰어가 다시 보지 않은 수정이 하나 있다(다음 세션 줄의 구절).

`.claude/existing-first-work/conductor-notes.md` — 두 로드맵(지휘자 맥락 경제 · 앞단 개선)의 지휘 세션에 사용자가 전할 짧은 글. 로드맵마다 따로 쓴다: 이 PR 이 고친 그 로드맵의 예약 파일, 바뀐 문장, 그 에픽이 뒤에 머지할 때 받아야 할 것.

두 파일의 경로를 사용자에게 보이고, push 와 PR 열기는 사용자가 요청할 때 한다. PR 을 열기 전에 Step 4 의 구현 대조를 한 번 더 돌려 경고를 보인다.
