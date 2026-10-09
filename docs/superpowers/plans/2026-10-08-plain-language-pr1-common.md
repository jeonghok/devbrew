# 쉬운 말 출력 PR 1 — 공통 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 네 플러그인의 SKILL.md·명령 파일 15곳 모두가 같은 「사람에게 쓰는 글」 규칙 블록으로 시작하고 락이 그것을 지키게 하고, 문서 리뷰 엔진의 게이트 렌더를 쉬운 말로 바꾸고, 양 측정 도구로 정식 기준선을 낸다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 정본 `shared/style/plain-language.md` 를 15곳의 H1 바로 다음에 바이트 그대로 복사하고, `shared/tests/test_plain_language_block.sh` 가 구조에서 대상을 도출해 동일성·자리·한 쌍을 잰다. 엔진 렌더(`render_gate` · `_rg_*`)는 GATE_ROWS 와 기계 출력(JSON)을 건드리지 않고 사람용 글만 바꾼다. 상태 이름의 쉬운 말 짝은 렌더 코드 옆 표 `STATE_GLOSS` 에 둔다. 양 측정은 리포 전용 `tools/plain-language/` 에 두고 배포하지 않는다.

**Tech Stack:** Python 3.9+(표준 라이브러리만, `unittest`), bash(macOS 3.2 호환), git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 실행자는 둘 다 읽는다. 이 계획은 PR 넷 중 첫째다. 나머지는 `2026-10-08-plain-language-pr2-spec-distill.md` · `-pr3-quality-gates.md` · `-pr4-audit-init.md` 다.

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. brief 의 C1~C11 · D12~D22 와 설계의 B1~B10 · D1.1~D2.10 이 제약이다. 이 계획이 설계와 다르게 정한 것은 아래 「계획이 정한 것」에 모두 있다. 그 밖에 충돌이 보이면 멈추고 보고한다.
- **작업 위치** — 워크트리 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게는 이 절대경로를 매번 못 박아 준다. 모든 명령은 이 디렉토리를 cwd 로 돈다.
- **git** — 브랜치 최신화는 merge(rebase 금지). 커밋은 경로를 지정해서 한다(`git add <경로들>` 후 `git commit`) — `git add -A` · `git add .` 금지. 커밋 메시지는 Conventional Commits 이고 **설명은 한국어**(type·scope 는 영어, 이 PR 의 Task 6 이 이 규칙을 `CLAUDE.md` 에 적는다). 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 한 줄. 스태시 스택을 건드리지 않는다.
- **Python** — 파일 읽기·쓰기에 `encoding="utf-8"` 를 명시한다. 스크립트 안에 `"python3"` 문자열 리터럴을 두지 않는다. 비신뢰 입력 정규식은 `fullmatch`. Python 3.9 에서 돌아야 한다.
- **테스트 실행** — 셸 테스트는 리포 루트에서 `bash <경로>`. Python 은 그 `tests/` 디렉토리에서 `python3 -m unittest -v <모듈>`. `plugins/quality-gates/tests/spike/` 는 돌리지 않는다(codex 를 실제로 태운다). 같은 테스트를 둘 이상 동시에 돌리지 않는다 — 고정 경로 `/tmp/sd_auth_stderr.txt` 가 경쟁해 거짓 RED 가 난다(2026-10-08 조사 실측).
- **변이(mutation)** — 먼저 커밋하고 변이한다. 변이 중에는 `PYTHONDONTWRITEBYTECODE=1`. 복원은 `git checkout HEAD -- <파일>` 이고 복원 뒤 `git diff HEAD --stat` 이 빈 출력인지 확인한다. 판정은 rc 만이 아니라 지정된 줄로 한다.
- **Bash 도구** — 호출마다 새 셸이다. 셸은 zsh 라 `PIPESTATUS` 가 없다. 이 워크트리의 bash 가드는 계산된 값이 들어간 복합 명령을 거부한다 — 그런 명령은 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/` 아래에 스크립트 파일로 쓰고 `bash <파일>` 로 돌린다. heredoc 으로 만들고 바로 실행하는 한 명령은 거부된다(Write 도구로 쓴 뒤 따로 실행).
- **버전** — 이 PR 은 네 플러그인을 모두 올린다(블록이 넷 모두에 들어간다): spec-distill minor(게이트 렌더가 바뀐다), quality-gates · plugin-audit · project-init patch. 번호는 머지 직전 origin/main 기준으로 다시 정한다.
- **사람에게 쓰는 글** — 커밋·PR 본문·보고는 `shared/style/plain-language.md` 를 따른다: 첫 줄에 상태, 번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일 하나.
- **모델** — devbrew 에서 fable 모델을 쓰지 않는다. codex 실호출은 사전 승인돼 있다(호출 횟수는 보고한다).
- **산출 보존** — 기준선 · 최종 스위트 · 측정값은 `~/.claude/sdd-mirror/plain-language-output/pr1/` 에 둔다(job tmp 와 git-ignored 경로는 세션 재개에 사라질 수 있다). 조사 원자료는 `~/.claude/sdd-mirror/plain-language-output/research/` 에 있다.

## 계획이 정한 것 (설계와 다른 점 · 설계가 계획에 넘긴 것)

사용자가 계획을 검토할 때 이 표를 본다. 각 줄은 근거와 함께 정했다.

| # | 정한 것 | 근거 |
|---|---|---|
| P1 | 블록 크기 상한은 줄 수로 재지 않는다. 판정자는 중복 락 하나다(설계 §2 의 「19줄을 넘기지 않는다」와 AC2 의 「19줄 이하 · 크기 락」을 쓰지 않는다). | 설계 표 `20bd0c10#r3.1`. 그리고 실측: H1 바로 다음에 19줄 블록을 넣으면 이미 RED 다 — reviewing-brief 와 reviewing-spec 의 H1 다음 줄이 글자까지 같아 창이 20줄이 된다. 13줄은 GREEN, 18줄까지 GREEN(2026-10-08). |
| P2 | 블록 동기 스크립트(`sync_plain_language.py`)를 만들지 않는다. 정본을 고치면 같은 커밋에서 15곳을 함께 고치고, 동일성 락이 어긋난 파일을 이름으로 댄다. | 설계 표 `3733b467#r2.1`(yagni). 15곳 삽입은 이 PR 의 일회성 스크립트(job tmp)로 한다. |
| P3 | 「밀려난 핵심 절」은 **블록 때문에 새로 경계 밖으로 나간 절**로 잰다. 블록을 넣기 전부터 경계 밖이던 kill switch · 게이트 절은 이 PR 이 만든 문제가 아니다. | 실측: 여러 파일의 `## kill switch` · `## 게이트` 는 블록 없이도 이미 앞 5,000토큰 밖이다. AC2 를 「넣은 뒤 경계 밖」으로 읽으면 블록과 무관하게 거짓이다. 예외 하나: 중앙 근사에서는 critiquing-artifacts 가 블록을 넣기 전 파일 전체가 5,000토큰 미만이라 `## kill switch` 가 블록 때문에 새로 밀린다(2026-10-08 모의 실행). |
| P4 | 토큰은 근사식으로 잰다(한글 음절 1.0 · 그 밖 비ASCII 1.0 · ASCII 3자당 1 — 보수). 오프라인 tokenizer 도 API 키도 없다. | 실측(2026-10-08). 보수 근사에서 publishing-pr-understanding 의 `## Consent` 일부가 경계를 넘는다(frontmatter 포함 기준). frontmatter 를 빼거나 중앙 근사로 재면 넘지 않는다. **이 PR 은 절 순서를 바꾸지 않고 PR 본문에 기록한다** — 동의 절은 게시 직전 단계라 압축이 그 사이에 끼기 어렵고, 절 순서를 바꾸면 그 skill 의 순서 단언을 다시 짜야 한다. 중앙 근사에서는 critiquing-artifacts 의 `## kill switch` 가 새로 밀리고 publishing-pr-understanding 의 경계가 `## kill switch` 안에 걸친다. 이것도 기록만 한다 — 두 skill 의 kill switch 판정은 앞쪽 진입 게이트(critiquing E0 · publishing 시작 펜스)가 실제로 집행하고, 뒤쪽 `## kill switch` 절은 스위치 목록 설명이다. 사용자가 다르게 정하면 Task 3 Step 6 에서 바꾼다. |
| P5 | conducting-interview SKILL 의 줄 수 래칫(`< 451`)은 **규칙 블록과 그 뒤 빈 줄을 뺀 줄 수**로 잰다. 상한 값은 그대로다. | 래칫은 「그 skill 자신의 분량」을 잰다. 블록은 15곳 공통이라 그 분량이 아니다. 값을 올리면 래칫의 뜻이 약해진다. |
| P6 | 렌더 첫 줄은 경고(advisory)를 **전부** 싣는다. 지금은 codex 가 없으면 codex 줄 하나만 싣고 나머지를 버린다. | `reviewing-document.md:88` 과 reviewing-spec SKILL 은 「codex 부재·critic 층 2 부재·recritic 부재는 게이트 첫 줄로 공시」라고 적는다. 지금 코드는 그 약속을 어긴다. |
| P7 | 항목 머리의 요약(`summary`)은 렌더할 때 한 줄로 접는다(원장 값은 그대로). | 새 항목 머리가 열 0 의 `- ` 로 시작한다. 지금 `summary` 는 정규화에서 개행을 접지 않는다(`docreview_route.py` normalize). 여러 줄 요약이 가짜 항목 줄을 만들 수 있다(Review Focus 1). |
| P8 | 판단에 필요한 0 으로 남기는 것: 참고 목록 줄(`참고 0건(이번 라운드 새 0 · 반복 0)`). 이 줄은 참고 축이 실제로 셌다는 공시다. | 설계 §3 원칙 3. 기존 락(`cases_advice.sh:573`·`:581`)이 프로필이 깨진 경우에도 이 줄이 나와야 한다고 잰다. |
| P9 | 사람용 렌더 문구를 고친 뒤에도 기계가 읽는 것은 그대로다: `gate` JSON 키·값, `gate-rows` 의 다섯 열, GATE_ROWS 순서, 선택지 라벨(`_CHOICE_LABEL`). | 설계 §3 표 · AC4 · AC8. |
| P10 | 「대표 사례 둘」의 전·후 출처(설계 표 `aabdbfc0#r3.1`): 사례 ① 「[미적용 fix] 3720b2b7#r1.1」은 옛 렌더 `_rg_unapplied_fix` 의 출력이다. 사례 ② 「(codex 정상 · 재비판 정상 · …)」은 **모델이 쓴 게이트 글**이고, 그 렌더 쪽 짝은 옛 렌더의 「degrade 없음」 + 0 만 늘어선 집계 줄이다. 둘 다 새 golden 두 케이스로 고정한다. | 2026-10-08 조사가 옛 렌더 표본으로 확인했다. |
| P11 | 리뷰어 칸에 더하는 한 줄은 `summary` · `if_unfixed` · `replacement` 에만 건다. `evidence`(근거)는 문서 인용이라 원문 그대로 둔다. | 규칙 블록의 「스크립트·subagent 가 낸 원문은 고치지 않는다」와 doc-critic 의 「evidence 는 문서에서 인용한다」. 설계 Deferred 5 는 `summary` 까지 넓혔다. |
| P12 | PR 1 은 엔진 렌더가 바뀌므로, spec-distill 문서 중 **렌더 첫 줄의 내용을 설명하는 문장**(「둘 다 비면 `degrade 없음` 이 온다」 등)만 이 PR 에서 함께 고친다. 게이트 질문 틀의 재배치(§4)는 PR 2 다. | PR 1 만 머지된 동안 문서가 존재하지 않는 출력을 설명하지 않게 한다. |
| P13 | 리뷰 라운드 게이트는 지금처럼 `AskUserQuestion` 한 번에 최대 4개씩 띄운다(설계 Deferred 6 — 2026-10-08 사용자 답 「지금처럼 4개씩」). 「서로 무관한 결정을 묶지 않는다」는 「질문 하나에 결정 하나」 와 「다른 결정의 답에 따라 달라지는 결정은 다음 묶음으로」 라는 뜻이다. 이 문장은 PR 2 가 쓴다. | 사용자 결정. |

## Review Focus

1. **리뷰어 요약에 개행과 목록 기호가 들어 있다** — 새 항목 머리는 열 0 의 `- ` 로 시작한다. 요약이 「…\n- 가짜 (zz#r1.7)」이면 가짜 항목 줄이 생기면 안 된다. 사람은 렌더에 진짜 항목만 보이길 기대한다. → Task 4 Step 1 의 `case_I4_summary_newline_collapsed`.
2. **codex 가 없고 남은 것도 없는 라운드** — 첫 줄이 「이상 없음」이면 사용자가 모델 다양성 없이 끝난 리뷰를 깨끗하다고 읽는다. → Task 4 의 `case_T40_codex_absent_first_line` 갱신과 변이 `warns_hidden_as_clean`.
3. **「미검증」 라운드에 남은 것도 경고도 없다** — 첫 줄이 「이상 없음」·「경고 없음」을 쓰면 안 된다(그 라운드는 리뷰되지 않았다). → Task 4 의 T46 단언 갱신(부재 단언을 새 문구로).
4. **새 SKILL.md 가 블록 없이 추가된다** — 락이 목록을 손으로 들고 있으면 놓친다. 사람은 「모든 skill」이 정말 모든 skill 이길 기대한다. → Task 2 의 변이 ③(블록 없는 새 SKILL.md).
5. **블록 자신의 `## 사람에게 쓰는 글` 이 「H1 다음 첫 비어 있지 않은 줄」 검사를 스스로 만족시킨다** — 블록을 H1 앞(frontmatter 바로 뒤)에 두면 H1 이 블록 뒤로 밀린다. 락은 H1 을 frontmatter 뒤 첫 `# ` 줄로 찾고, 그 다음 첫 비어 있지 않은 줄이 시작 표시 줄인지를 본다. → Task 2 의 변이 ⑤⑥.

---

## Task 0: 착수 준비 — base 따라잡기와 기준선

**Files:**
- Create: `~/.claude/sdd-mirror/plain-language-output/run-suite.sh`(리포 밖)
- Modify: 없음(merge 커밋이 생길 수 있다)

**Interfaces:**
- Produces: `~/.claude/sdd-mirror/plain-language-output/run-suite.sh <label> [경로 접두]` — `<OUT>/<label>/summary.tsv`(파일 · rc · 실패 줄 수) · `failures.txt`(정렬된 `<파일> :: <실패 줄>`) · `logs/`. Task 9 와 PR 2~4 가 같은 스크립트를 쓴다. `SUITE_OUT` 로 출력 자리를 바꾼다.
- Produces: `~/.claude/sdd-mirror/plain-language-output/pr1/base.txt` — merge 뒤 HEAD 와 origin/main 해시.

- [ ] **Step 1: base 이동량을 재고 merge 한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr1
git status --porcelain            # 빈 출력이어야 한다
git fetch origin main
git rev-list --count HEAD..origin/main
git merge-tree --write-tree HEAD origin/main >/dev/null && echo clean || echo CONFLICT
```

CONFLICT 면 merge 하지 말고 멈춰 보고한다. clean 이면:

```bash
git merge --no-edit origin/main
git rev-parse HEAD > ~/.claude/sdd-mirror/plain-language-output/pr1/base.txt
git rev-parse origin/main >> ~/.claude/sdd-mirror/plain-language-output/pr1/base.txt
git diff --stat HEAD@{1} HEAD -- plugins shared CLAUDE.md | tail -3
```

마지막 줄의 변경 파일 중 이 계획이 건드리는 파일(아래 Task 들의 **Files**)이 있으면, 그 파일의 이 계획 속 리터럴(바꿀 옛 문구)이 아직 그대로인지 `grep -F` 로 확인하고, 다르면 멈춰 보고한다.

- [ ] **Step 2: 스위트 스크립트를 쓴다**

`~/.claude/sdd-mirror/resolve-audits/run-suite.sh` 를 복사하고 두 줄만 바꾼다:

```bash
cp ~/.claude/sdd-mirror/resolve-audits/run-suite.sh ~/.claude/sdd-mirror/plain-language-output/run-suite.sh
```

그 파일에서 `REPO=` 줄과 `OUT=` 줄을 Edit 로 바꾼다:

```bash
REPO=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
OUT="${SUITE_OUT:-$HOME/.claude/sdd-mirror/plain-language-output}"
```

`list()` 의 정규식에 리포 전용 도구 테스트를 더한다(Task 8 이 만든다). 옛 줄:

```bash
    | grep -E '^(plugins/[^/]+/tests/(harness/)?test_[^/]*\.(sh|py)|shared/tests/test_[^/]*\.sh|plugins/[^/]+/tests/[^/]*\.test\.mjs)$' \
```

새 줄:

```bash
    | grep -E '^(plugins/[^/]+/tests/(harness/)?test_[^/]*\.(sh|py)|shared/tests/test_[^/]*\.sh|plugins/[^/]+/tests/[^/]*\.test\.mjs|tools/[^/]+/test_[^/]*\.py)$' \
```

- [ ] **Step 3: 기준선을 잰다**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr1/baseline
```

예상(2026-10-08 조사 기준): rc≠0 인 파일은 `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`(선재 RED 2건 — 「iter cap near Review gate」·「R1b→R8 unclaimed」)와 `plugins/spec-distill/tests/test_hook_output_schema.py`(워크트리에서 두 해석기가 다른 경로를 낸다), 그리고 가끔 `plugins/quality-gates/tests/test_codex_backward_compat.sh`(부하 아래 타이밍 — 단독으로 다시 돌리면 GREEN). 그 밖의 RED 가 나오면 그 이름과 실패 줄을 `pr1/baseline/NOTE.md` 에 적는다. 이 Task 는 커밋하지 않는다.

---

## Task 1: 규칙 블록 정본

**Files:**
- Create: `shared/style/plain-language.md`
- Modify: `shared/README.md`(디렉토리 표에 한 줄)

**Interfaces:**
- Produces: `shared/style/plain-language.md` — 파일 전체가 표시 줄 두 개를 포함한 13줄 블록이고 끝에 개행 하나다. Task 2 의 락과 삽입 스크립트가 이 바이트를 정본으로 쓴다.

- [ ] **Step 1: 정본을 쓴다**

`shared/style/plain-language.md` 를 Write 로 만든다. 내용은 설계 §1 의 펜스 안 13줄 그대로이고, 마지막 줄 뒤에 개행 하나로 끝난다:

```markdown
<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->
```

- [ ] **Step 2: 정본이 설계와 바이트가 같은지 확인한다**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_canon_check.py` 를 Write 로 만든다:

```python
import io, re, sys
design = io.open("docs/superpowers/specs/2026-10-08-plain-language-output-design.md", encoding="utf-8").read()
m = re.search(r"```markdown\n(<!-- plain-language:begin -->\n.*?<!-- plain-language:end -->\n)```", design, re.S)
canon = io.open("shared/style/plain-language.md", encoding="utf-8").read()
print("same" if m and m.group(1) == canon else "DIFF")
print(len(canon.split("\n")) - 1, "lines")
```

Run: `python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_canon_check.py`
Expected: `same` 와 `13 lines`.

- [ ] **Step 3: `shared/README.md` 디렉토리 표에 한 줄을 더한다**

`| `tests/` |` 로 시작하는 줄 바로 앞에 이 줄을 넣는다:

```markdown
| `style/` | 「사람에게 쓰는 글」 규칙 블록의 정본(`plain-language.md`) — 15곳의 SKILL.md·명령 파일에 바이트 그대로 복사된다. 같음은 `tests/test_plain_language_block.sh` 가 잰다 |
```

- [ ] **Step 4: 커밋**

```bash
git add shared/style/plain-language.md shared/README.md
git commit -m "feat(shared): 사람에게 쓰는 글 규칙 블록의 정본

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: 블록 동일성 락 (실패하는 테스트 먼저)

**Files:**
- Create: `shared/tests/plain_language_block.py`
- Create: `shared/tests/test_plain_language_block.sh`

**Interfaces:**
- Consumes: `shared/style/plain-language.md`(Task 1).
- Produces: `bash shared/tests/test_plain_language_block.sh` — 대상마다 `✓`/`✗` 줄, 끝에 `Total: N | Pass: N | Fail: N`. `--emit-scanned` 이면 읽는 경로를 한 줄에 하나씩 낸다.
- Produces: `python3 shared/tests/plain_language_block.py <repo-root> <list-file>` — `ok <msg>` / `no <msg>` 줄만 낸다(셸이 그것을 `ok`/`no` 로 옮긴다).

- [ ] **Step 1: 판정 모듈을 쓴다**

`shared/tests/plain_language_block.py`:

```python
#!/usr/bin/env python3
"""규칙 블록 동일성 판정 — `test_plain_language_block.sh` 의 본체.

입력: 리포 루트 · 대상 목록 파일(한 줄에 리포 상대 경로 하나). 출력: `ok <msg>` · `no <msg>` 줄.
대상마다 넷을 잰다 — 표시 줄이 각각 정확히 한 번 · 시작 표시 줄이 H1(frontmatter 뒤 첫 `# ` 줄)
다음의 첫 비어 있지 않은 줄 · 시작이 끝보다 앞 · 표시 줄 사이(포함) 바이트가 정본과 같다.
H1 은 블록 자신의 `## ` 제목으로 만족되지 않는다 — `# ` 다음 글자가 `#` 이 아닌 줄만 H1 이다.
"""
import io
import sys
from pathlib import Path

BEGIN = "<!-- plain-language:begin -->"
END = "<!-- plain-language:end -->"
CANON = "shared/style/plain-language.md"


def h1_index(lines):
    i = 0
    if lines and lines[0] == "---":
        try:
            i = lines.index("---", 1) + 1
        except ValueError:
            return None
    for j in range(i, len(lines)):
        if lines[j].startswith("# "):
            return j
    return None


def check(root, rel, canon):
    try:
        text = io.open(str(root / rel), encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as e:
        return ["no %s: 읽지 못했다 (%s)" % (rel, e.__class__.__name__)]
    lines = text.split("\n")
    nb, ne = lines.count(BEGIN), lines.count(END)
    if nb != 1 or ne != 1:
        return ["no %s: 표시 줄이 시작 %d개 · 끝 %d개다 — 정확히 한 쌍이어야 한다" % (rel, nb, ne)]
    b, e = lines.index(BEGIN), lines.index(END)
    if e < b:
        return ["no %s: 끝 표시 줄이 시작보다 앞이다" % rel]
    h = h1_index(lines)
    if h is None:
        return ["no %s: frontmatter 뒤 H1(`# ` 줄)이 없다" % rel]
    first = next((k for k in range(h + 1, len(lines)) if lines[k].strip()), None)
    if first != b:
        return ["no %s: 블록이 H1 바로 다음이 아니다 (H1 L%d · 첫 비어 있지 않은 줄 L%s · 시작 표시 L%d)"
                % (rel, h + 1, first + 1 if first is not None else "-", b + 1)]
    region = "\n".join(lines[b:e + 1]) + "\n"
    if region != canon:
        return ["no %s: 블록 바이트가 정본(%s)과 다르다" % (rel, CANON)]
    return ["ok %s: 블록이 H1 바로 다음에 있고 정본과 같다" % rel]


def main(argv):
    root = Path(argv[1])
    targets = [l for l in io.open(argv[2], encoding="utf-8").read().split("\n") if l]
    try:
        canon = io.open(str(root / CANON), encoding="utf-8").read()
    except OSError:
        print("no 정본 %s 이 없다" % CANON)
        return 0
    cl = canon.split("\n")
    if cl.count(BEGIN) != 1 or cl.count(END) != 1 or not canon.startswith(BEGIN + "\n") or not canon.endswith(END + "\n"):
        print("no 정본 %s 이 표시 줄 한 쌍으로 시작하고 끝나는 블록 하나가 아니다" % CANON)
        return 0
    if not targets:
        print("no 대상이 0개다 — 글롭이 아무것도 고르지 않았다(공허한 통과 방지)")
        return 0
    print("ok 대상 %d개를 구조에서 도출했다" % len(targets))
    for rel in targets:
        for line in check(root, rel, canon):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 2: 셸 락을 쓴다**

`shared/tests/test_plain_language_block.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/style/plain-language.md plugins/*/skills/*/SKILL.md plugins/*/commands/*.md shared/tests/plain_language_block.py
#
# 「사람에게 쓰는 글」 블록 동일성 — 대상은 두 글롭에서 도출한다(목록을 손으로 적지 않는다).
# 새 SKILL.md · 명령 파일이 블록 없이 들어오면 RED 다. 판정은 plain_language_block.py 가 한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
derive_git() {
  git -C "$ROOT" ls-files --cached --others --exclude-standard -- \
    'plugins/*/skills/*/SKILL.md' 'plugins/*/commands/*.md' | LC_ALL=C sort -u
}
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' shared/style/plain-language.md shared/tests/plain_language_block.py
  derive_git
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
LIST="$(mktemp -t plb-list-XXXXXX)" || exit 1
RES="$(mktemp -t plb-res-XXXXXX)" || { rm -f "$LIST"; exit 1; }
trap 'rm -f "$LIST" "$RES"' EXIT
derive_git > "$LIST"
# 양의 짝 — git 도출과 find 도출이 같은 집합이다(git 이 조용히 0 을 내는 경우를 막는다).
FIND_N="$(cd "$ROOT" && find plugins -path '*/skills/*/SKILL.md' -o -path 'plugins/*/commands/*.md' | grep -c .)"
GIT_N="$(grep -c . "$LIST" || true)"
assert_eq "$GIT_N" "$FIND_N" "대상 도출: git 과 find 가 같은 수를 낸다"
python3 "$ROOT/shared/tests/plain_language_block.py" "$ROOT" "$LIST" > "$RES" 2>&1
rc=$?
assert_eq "$rc" "0" "판정 모듈이 rc 0 으로 끝났다"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
    *) no "판정 모듈이 알 수 없는 줄을 냈다: $line" ;;
  esac
done < "$RES"
finish
```

- [ ] **Step 3: 실패하는지 확인한다**

Run: `bash shared/tests/test_plain_language_block.sh`
Expected: `✗ plugins/.../SKILL.md: 표시 줄이 시작 0개 · 끝 0개다` 가 15줄, rc 1.

- [ ] **Step 4: 커밋(RED 인 채로 — Task 3 이 GREEN 으로 만든다)**

```bash
git add shared/tests/plain_language_block.py shared/tests/test_plain_language_block.sh
git commit -m "test(shared): 규칙 블록 동일성 락

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: 블록을 15곳에 넣고 토큰 경계를 잰다

**Files:**
- Create: `tools/plain-language/token_boundary.py`
- Modify: `plugins/*/skills/*/SKILL.md` 8개, `plugins/*/commands/*.md` 7개(H1 다음에 빈 줄 + 블록 + 빈 줄)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh:475-477, :502`

**Interfaces:**
- Consumes: 정본(Task 1), 락(Task 2).
- Produces: `python3 tools/plain-language/token_boundary.py [--body] [--base <git-rev>]` — 대상마다 「넣기 전 · 넣은 뒤 경계 줄」과 「블록 때문에 새로 밀려난 `## ` 절」을 낸다. PR 본문 표의 원자료다.

- [ ] **Step 1: 일회성 삽입 스크립트를 쓴다(리포에 넣지 않는다)**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_insert.py`:

```python
import io, subprocess, sys
ROOT = "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice"
canon = io.open(ROOT + "/shared/style/plain-language.md", encoding="utf-8").read()
block = canon.rstrip("\n").split("\n")
out = subprocess.run(["git", "-C", ROOT, "ls-files", "--", "plugins/*/skills/*/SKILL.md", "plugins/*/commands/*.md"],
                     capture_output=True, text=True, check=True).stdout.split()
for rel in sorted(out):
    p = ROOT + "/" + rel
    lines = io.open(p, encoding="utf-8").read().split("\n")
    if "<!-- plain-language:begin -->" in lines:
        print("skip (already)", rel); continue
    fm = lines.index("---", 1) if lines[0] == "---" else -1
    h = next(i for i in range(fm + 1, len(lines)) if lines[i].startswith("# "))
    rest = lines[h + 1:]
    while rest and not rest[0].strip():
        rest.pop(0)
    new = lines[:h + 1] + [""] + block + [""] + rest
    io.open(p, "w", encoding="utf-8").write("\n".join(new))
    print("inserted", rel, "after L%d" % (h + 1))
```

- [ ] **Step 2: 넣는다**

Run: `python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_insert.py`
Expected: `inserted` 15줄. 그다음 `git diff --stat` 이 15파일 · 파일당 `+14`(빈 줄 1 + 블록 13; H1 뒤 원래 빈 줄 하나는 그대로) 근처인지 본다. H1 과 본문 사이 빈 줄이 원래 둘 이상이던 파일은 `-`가 섞인다 — `git diff` 로 그 파일을 열어 본문 글자가 바뀌지 않았는지 확인한다.

- [ ] **Step 3: 락과 중복 락이 GREEN 인지 본다**

Run:
```bash
bash shared/tests/test_plain_language_block.sh | tail -2
bash shared/tests/test_no_new_duplication.sh | tail -2
```
Expected: 둘 다 `Fail: 0`.

- [ ] **Step 4: 줄 수 래칫을 블록 밖 분량으로 잰다(P5)**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh` 에서 `SKILL=` 정의 바로 아래(6행 근처, `SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"` 다음 줄)에 함수를 더한다:

```bash
# 규칙 블록(표시 줄 포함)과 그 바로 뒤 빈 줄 하나를 뺀 줄 수 — 블록은 15곳 공통이라 이 래칫이 재는
# 「이 skill 자신의 분량」이 아니다(쉬운 말 출력 PR 1, 계획 P5). 블록이 없으면 wc -l 과 같다.
skill_own_lines() {
  awk '/^<!-- plain-language:begin -->$/{s=1} s==0{n++} s==2{s=0; if ($0 != "") n++; next} /^<!-- plain-language:end -->$/{s=2} END{print n+0}' "$1"
}
```

475행의 셋째 줄 묶음(옛):

```bash
[[ "$(wc -l < "$SKILL")" -lt 451 ]] \
  && ok "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") < 451 (조사 특화 순증 수용 — 실측 + 8, Task 11 이 조였다)" \
  || no "AC3/C9: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 451"
```

새:

```bash
[[ "$(skill_own_lines "$SKILL")" -lt 451 ]] \
  && ok "AC3/C9: SKILL.md 자기 줄 수 $(skill_own_lines "$SKILL") < 451 (규칙 블록 제외 — 조사 특화 순증 수용, 실측 + 8)" \
  || no "AC3/C9: SKILL.md 자기 줄 수 $(skill_own_lines "$SKILL") ≥ 451"
```

502행(옛):

```bash
[[ "$(wc -l < "$SKILL")" -lt 451 ]] && ok "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") < 451 (조사 특화 순증 수용 — 실측 + 8, Task 11 이 조였다)" || no "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 451"
```

새:

```bash
[[ "$(skill_own_lines "$SKILL")" -lt 451 ]] && ok "G7: SKILL.md 자기 줄 수 $(skill_own_lines "$SKILL") < 451 (규칙 블록 제외)" || no "G7: SKILL.md 자기 줄 수 $(skill_own_lines "$SKILL") ≥ 451"
```

그리고 래칫 아래에 함수의 양의 짝을 둔다(블록을 세지 않는다는 것이 공허하지 않음):

```bash
_total="$(wc -l < "$SKILL" | tr -d ' ')"; _own="$(skill_own_lines "$SKILL")"
[[ $(( _total - _own )) -eq 14 ]] \
  && ok "AC3/C9 양의 짝: 블록 13줄 + 뒤 빈 줄 1 이 정확히 빠졌다 (${_total} − ${_own})" \
  || no "AC3/C9 양의 짝: 뺀 줄 수가 14 가 아니다 (${_total} − ${_own}) — 블록이 없거나 함수가 깨졌다"
```

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh | tail -1`
Expected: `Fail: 0`.

- [ ] **Step 5: 토큰 경계 도구를 쓴다**

`tools/plain-language/token_boundary.py`:

```python
#!/usr/bin/env python3
"""압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계가 규칙 블록 때문에 어디로 옮겼는지 잰다(근사).

근사식(줄마다 누적): 한글 음절 × KH + 그 밖 비ASCII × KO + ASCII 글자 / CA (+ 개행).
  cons(보수): KH=1.0 · KO=1.0 · CA=3.0   ·  cent(중앙): KH=0.8 · KO=1.0 · CA=3.7
오프라인 tokenizer 와 API 키가 없어(2026-10-08 실측) 실제 tokenizer 로 보정하지 않았다 — 값은 근사다.
「새로 밀려난 절」 = 넣기 전에는 경계 안에서 시작하던 `## ` 절 중 넣은 뒤 경계 밖에서 시작하는 것.
넣기 전 파일은 `--base <rev>`(기본 HEAD~1 이 아니라 명시) 의 git 내용이다.
"""
import argparse
import io
import subprocess
import sys

PROFILES = {"cons": (1.0, 1.0, 3.0), "cent": (0.8, 1.0, 3.7)}
LIMIT = 5000
BEGIN, END = "<!-- plain-language:begin -->", "<!-- plain-language:end -->"


def toks(s, prof):
    kh, ko, ca = PROFILES[prof]
    h = sum(1 for c in s if "가" <= c <= "힣")
    a = sum(1 for c in s if ord(c) < 128)
    return h * kh + (len(s) - h - a) * ko + a / ca


def boundary(lines, prof, body):
    start = 0
    if body and lines and lines[0] == "---":
        start = lines.index("---", 1) + 1
    cum = 0.0
    for i in range(start, len(lines)):
        cum += toks(lines[i] + "\n", prof)
        if cum > LIMIT:
            return i
    return None


def git(*args):
    return subprocess.run(["git"] + list(args), capture_output=True, text=True, check=True).stdout


def heads(lines):
    return [(i, l) for i, l in enumerate(lines) if l.startswith("## ")]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="블록을 넣기 전 커밋")
    ap.add_argument("--body", action="store_true", help="frontmatter 를 빼고 잰다")
    a = ap.parse_args(argv)
    targets = git("ls-files", "--", "plugins/*/skills/*/SKILL.md", "plugins/*/commands/*.md").split()
    canon = io.open("shared/style/plain-language.md", encoding="utf-8").read()
    print("블록 근사 토큰: cons %.0f · cent %.0f" % (toks(canon, "cons"), toks(canon, "cent")))
    for rel in sorted(targets):
        old = git("show", "%s:%s" % (a.base, rel)).split("\n")
        new = io.open(rel, encoding="utf-8").read().split("\n")
        for prof in ("cons", "cent"):
            b0, b1 = boundary(old, prof, a.body), boundary(new, prof, a.body)
            if b0 is None and b1 is None:
                print("%s [%s] 파일 전체가 %d토큰 미만 — 밀린 절 없음" % (rel, prof, LIMIT))
                continue
            inside_old = {l for i, l in heads(old) if b0 is None or i < b0}
            outside_new = {l for i, l in heads(new) if b1 is not None and i >= b1}
            pushed = sorted(inside_old & outside_new)
            cut = [l for i, l in heads(new) if b1 is not None and i < b1][-1:]
            print("%s [%s] 경계 L%s → L%s · 새로 밀린 절: %s · 경계가 걸친 절: %s"
                  % (rel, prof, b0 + 1 if b0 is not None else "-", b1 + 1 if b1 is not None else "-",
                     " / ".join(pushed) or "없음", cut[0] if cut else "-"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: 경계를 재고 기록한다**

블록을 넣기 전 커밋은 Task 2 의 커밋이다(`git log --format=%H -1 -- shared/tests/test_plain_language_block.sh`).

```bash
BASE="$(git log --format=%H -1 -- shared/tests/test_plain_language_block.sh)"
python3 tools/plain-language/token_boundary.py --base "$BASE" > ~/.claude/sdd-mirror/plain-language-output/pr1/token-boundary.txt
python3 tools/plain-language/token_boundary.py --base "$BASE" --body > ~/.claude/sdd-mirror/plain-language-output/pr1/token-boundary-body.txt
grep -E '새로 밀린 절: [^없]' ~/.claude/sdd-mirror/plain-language-output/pr1/token-boundary*.txt
```

조사 예상(2026-10-08, cons · frontmatter 포함): auditing-plugins(`## Workflow` · `## post-1 — 조립·검증·렌더`), publishing-pr-understanding(`## Publish` · `## Report`, 경계가 `## Consent` 안에 걸친다), conducting-interview(`## C43 3-path routing` · `## 사용자 발화 기록 (G1, AC1)`), reviewing-brief(`## 번들 — 라운드마다 한 번`). 중앙 근사(cent)에서는 더해서: critiquing-artifacts 가 넣기 전 파일 전체 5,000토큰 미만(`경계 L- → L260` 근처)이라 `## Law 2 보증` · `## kill switch` · `## 종료 & 최종 요약 (AC11)` 이 새로 밀리고(frontmatter 포함 · `--body` 둘 다), publishing-pr-understanding 은 경계가 `## kill switch` 안에 걸친다. 새로 밀린 절 이름에 `kill switch` · `진입` · `게이트` · `Consent` · `consent` 가 들어간 것이 있거나 경계가 그런 절 안에 걸치면 PR 본문의 「경계 표」에 그 사실과 P4 의 처리(그대로 두고 기록)를 적는다. 사용자가 계획 검토에서 절 순서를 바꾸기로 했으면 그 절을 경계 안으로 옮기는 편집을 이 Step 에서 하고 그 skill 의 테스트를 다시 돈다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/*/skills/*/SKILL.md plugins/*/commands/*.md tools/plain-language/token_boundary.py plugins/spec-distill/tests/test_conducting_interview_stage.sh
git status --porcelain     # 이 Task 밖 파일이 스테이지에 없는지 본다
git commit -m "feat: 모든 skill·명령 파일 앞에 사람에게 쓰는 글 규칙 블록

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: 변이로 락의 이빨을 확인한다(AC1 · AC2)**

각 변이 뒤 `bash shared/tests/test_plain_language_block.sh | tail -1` 이 `Fail: 0` 이 아니어야 하고(②⑦ 은 지정한 줄), 끝나면 `git checkout HEAD -- <파일>` 후 `git diff HEAD --stat` 이 빈 출력이어야 한다. 대상 파일은 `plugins/quality-gates/commands/qg-publish.md`(짧다)로 한다.

1. 한 복사본의 글자 하나 바꾸기: `sed -i '' 's/한 번에 이해하게/한번에 이해하게/' plugins/quality-gates/commands/qg-publish.md` → `블록 바이트가 정본` RED.
2. 한 파일에서 블록 지우기: `sed -i '' '/^<!-- plain-language:begin -->$/,/^<!-- plain-language:end -->$/d' plugins/quality-gates/commands/qg-publish.md` → `시작 0개 · 끝 0개` RED.
3. 블록 없는 새 SKILL.md: `mkdir -p plugins/quality-gates/skills/zz-probe && printf -- '---\nname: zz-probe\n---\n\n# zz\n\n본문\n' > plugins/quality-gates/skills/zz-probe/SKILL.md` → `zz-probe/SKILL.md` RED. 복원은 `rm -r plugins/quality-gates/skills/zz-probe`.
4. 블록을 파일 끝으로: qg-publish.md 에서 블록 13줄을 지우고 같은 13줄을 파일 끝에 붙인다(job tmp 스크립트로) → `H1 바로 다음이 아니다` RED.
5. 블록을 H1 앞으로: 블록을 frontmatter 닫는 줄 바로 뒤로 옮긴다 → `H1 바로 다음이 아니다` RED(H1 은 frontmatter 뒤 첫 `# ` 줄이고 그 다음 첫 비어 있지 않은 줄이 본문이다).
6. H1 과 블록 사이에 문단: H1 다음 줄에 `끼어든 문단` 한 줄을 넣는다 → RED.
7. 정본만 바꾸기: `sed -i '' 's/한 번에 이해하게/한번에 이해하게/' shared/style/plain-language.md` → 15곳 전부 RED.
8. (AC2) 블록을 20줄로: 정본과 15곳 모두의 끝 표시 줄 앞에 서로 같은 일곱 줄(`- 채움 1` … `- 채움 7`)을 넣는다(job tmp 스크립트) → `bash shared/tests/test_no_new_duplication.sh` RED.
9. (AC2) frontmatter 바로 뒤 + 19줄: 15곳의 블록을 frontmatter 닫는 줄 바로 뒤로 옮기고 여섯 줄을 채운다 → 중복 락 RED.

각 변이의 명령과 RED 줄을 `~/.claude/sdd-mirror/plain-language-output/pr1/mutations-block.txt` 에 적는다.

---

## Task 4: 문서 리뷰 엔진 게이트 렌더를 쉬운 말로

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py`(상수 `UNVERIFIED_TEXT` · `UNROUTED_TEXT`, 새 `STATE_GLOSS` · `COUNT_GLOSS` · `NEXT_MODE_GLOSS` · `_one` · `_first_line`, `_rg_*` 열 개, `render_gate`)
- Modify: `shared/tests/fixtures/docreview/cases.sh`(헬퍼 · 단언 · 새 케이스)
- Modify: `shared/tests/fixtures/docreview/cases_advice.sh:70-73, :115-116, :149-150, :394, :569, :573, :581`
- Modify: `shared/tests/fixtures/docreview/critic-if-unfixed-newline.txt:12, :30`
- Create: `shared/tests/fixtures/docreview/critic-empty.txt` · `shared/tests/fixtures/docreview/codex-empty-ok.yaml`
- Modify: `shared/tests/test_docreview_route.sh`(새 케이스 등록) · `shared/tests/test_docreview_state.sh`(새 케이스 등록)
- Modify: `shared/tests/test_docreview_mutations.sh:573-574, :698-699`(재앵커) + 새 셀 다섯
- Modify: `shared/tests/fixtures/docreview/capture_finalize_golden.sh`(케이스 목록) · `shared/tests/test_docreview_golden.sh:42`(케이스 목록)
- Modify: `shared/tests/fixtures/docreview/golden/*.gate.txt`(재생성) + 새 golden 여덟 파일

**Interfaces:**
- Consumes: `gate_summary(st) -> dict`, `GATE_ROWS`, `decide_choices`, `choice_label`, `_post_kind_notice` (변경 없음).
- Produces: `render_gate(st, g) -> str` 의 새 모양 —
  - 1줄: `_first_line(g)` — 「리뷰 N라운드를 마쳤다 — <행 사람말> N개 · …가 남았다. 경고 없음.」 / 「… — 이상 없음.」 / 「… 경고 K개: a · b」. 「미검증」·라운드 미완이면 그 공시 + `. ` 가 맨 앞이고 「리뷰 N라운드 — …」(마쳤다 없음)이며 「이상 없음」·「경고 없음」을 쓰지 않는다.
  - 2줄: `재리뷰 X/2회 썼다[ · 상한에 닿았다][ · 진전 없음(stagnation)]`.
  - 행마다: 비어 있지 않으면 `<STATE_GLOSS[name]> N개` 제목 줄, 그 아래 항목. 항목 머리는 `- <요약>[ — <덧말>] (<fid>[ · 자동])` — 열 0 의 `- ` 는 렌더러만 만들고, 머리는 언제나 `(<fid>)` 또는 `(<fid> · 자동)` 으로 끝난다.
  - 사상 없는 행: 제목 줄 바로 다음에 `  ↳ 상태 이름에 사람말이 없다: <name> — 원래 이름 그대로 낸다`.
  - 집계: 0 이 아닌 것만 `이번 라운드 집계: a · b`. 전부 0 이면 줄이 없다.
  - 참고: `참고 N건(이번 라운드 새 N · 반복 N) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 N`(0 이어도 낸다 — P8).
  - 마지막: `다음: …` 줄.
- Produces(테스트 헬퍼, `cases.sh`): `item_block <render> <fid> <after>` → 그 항목 머리 줄과 뒤 `<after>` 줄. `item_prev_line <render> <fid>` → 그 항목 머리 바로 앞 줄.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다 — 새 케이스와 헬퍼**

`shared/tests/fixtures/docreview/critic-empty.txt`(Write — 바깥 펜스는 백틱 넷이다. 안의 아홉 줄이 파일 내용이고 끝에 개행 하나):

````text
리뷰 없음.

```docreview-layer1
[]
```

```docreview-layer2
[]
```
````

`shared/tests/fixtures/docreview/codex-empty-ok.yaml`(Write):

```yaml
findings: []
meta:
  codex_failed: false
  exit_code: 0
```

`cases.sh` 의 `choices_match()` 정의 바로 앞(「# render 의 그 id 블록에서 「대안:」 줄을 뽑아」 주석 앞)에 헬퍼 둘을 넣는다:

```bash
# 항목 머리 찾기 — 쉬운 말 렌더(쉬운 말 출력 PR 1)에서 항목 머리는 열 0 의 「- 」로 시작하고
# 「(<fid>)」 또는 「(<fid> · 자동)」으로 끝난다. 다른 항목이 이 fid 를 참조할 때(「이 답을 기다리는
# 수정: <fid>」 · 「이어받은 결정: <fid>」)는 괄호로 끝나지 않으므로 머리와 참조가 갈린다.
item_block() {   # item_block <render-text> <fid> <after> → 머리 줄 + 뒤 <after> 줄
  printf '%s\n' "$1" | python3 -c '
import sys
fid, after = sys.argv[1], int(sys.argv[2])
ls = sys.stdin.read().split("\n")
for i, l in enumerate(ls):
    if l.startswith("- ") and (l.endswith("(%s)" % fid) or l.endswith("(%s · 자동)" % fid)):
        print("\n".join(ls[i:i + 1 + after]))
        break
' "$2" "$3"
}
item_prev_line() {   # item_prev_line <render-text> <fid> → 그 항목 머리 바로 앞 줄
  printf '%s\n' "$1" | python3 -c '
import sys
fid = sys.argv[1]
ls = sys.stdin.read().split("\n")
for i, l in enumerate(ls):
    if l.startswith("- ") and (l.endswith("(%s)" % fid) or l.endswith("(%s · 자동)" % fid)):
        if i > 0:
            print(ls[i - 1])
        break
' "$2"
}
```

`case_I4_if_unfixed_newline_collapsed()` 정의 바로 뒤에 새 케이스 넷을 넣는다:

```bash
# ── 쉬운 말 렌더 (쉬운 말 출력 설계 §3 · AC3) ───────────────────────────────
# 대표 사례 둘 — ① 옛 렌더 「[미적용 fix] <id> — <요약> (적용 예정 / drop)」의 자리,
# ② 모델이 쓰던 정상 나열 「(codex 정상 · 재비판 정상 · …)」의 렌더 쪽 짝(옛 렌더: 「degrade 없음」 +
# 0 만 늘어선 집계 줄). 둘 다 golden 으로도 고정된다(capture_finalize_golden.sh).
case_plain_render_nothing_left() {
  local d gr; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-empty.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "쉬운 렌더 ②: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$gr" | head -1)" "리뷰 1라운드를 마쳤다 — 이상 없음." \
    "AC3①: 남은 것도 경고도 없는 라운드의 첫 줄은 「이상 없음」 한 문장이다"
  assert_not_grep "$gr" '^이번 라운드 집계' "AC3②: 전부 0 인 집계 줄이 나가지 않는다"
  assert_eq "$(printf '%s\n' "$gr" | grep -v '^참고 ' | grep -cE ' 0(건|개)( |$|·)' || true)" "0" \
    "AC3②: 0 인 정상 집계 항목이 어디에도 없다(참고 줄은 판단에 필요한 0 — 계획 P8)"
  assert_not_contains "$gr" "degrade 없음" "AC3: 옛 첫 줄 「degrade 없음」이 남지 않는다"
  rm -rf "$d"
}
case_plain_render_fix_and_decide() {
  local d gr heads; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "쉬운 렌더 ①: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$gr" | head -1)" "리뷰 1라운드를 마쳤다 — 정할 것 1개 · 아직 안 고친 곳 1개가 남았다. 경고 없음." \
    "AC3①⑥: 남은 것이 있고 경고가 없으면 첫 줄은 「경고 없음」이다(「이상 없음」이 아니다)"
  heads="$(printf '%s\n' "$gr" | grep '^- ' || true)"
  assert_eq "$(printf '%s\n' "$heads" | grep -c . || true)" "2" "AC3③ 전제: 항목 머리가 둘(decide 1 · 미적용 fix 1)"
  assert_eq "$(printf '%s\n' "$heads" | grep -cvE ' \([0-9a-f]{8}#r[0-9]+\.[0-9]+( · 자동)?\)$' || true)" "0" \
    "AC3③: 모든 항목 머리가 쉬운 말로 시작하고 id 는 끝 괄호 안에 있다"
  assert_grep "$gr" '^아직 안 고친 곳 1개$' "AC3③: 미적용 fix 묶음 제목이 쉬운 말이다"
  assert_grep "$gr" '^- §5 에 TBD 가 남아 있다 — 고치거나 버린다\(drop\) \(9dea7cf3#r1\.1\)$' \
    "AC3 사례 ①: 옛 「[미적용 fix] 9dea7cf3#r1.1 — …」 이 쉬운 말 + 끝 괄호 id 로 바뀌었다"
  assert_not_grep "$gr" '^순서: ' "AC3: 「순서:」 설명 줄은 묶음 제목으로 흡수됐다"
  rm -rf "$d"
}
# Review Focus 1 — 요약(summary)은 정규화에서 개행을 접지 않는다. 새 머리가 열 0 의 「- 」 로 시작하므로
# 여러 줄 요약이 가짜 항목 줄을 만들 수 있다 — 렌더가 접는다(원장 값은 그대로).
case_I4_summary_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" '[{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다\n- 가짜 항목 (zz#r1.7)","evidence":"12행","blocks":[],"kind":"pre"}]'
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜 항목' "I4 summary: 요약 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^- 파일 목록이 두 가지로 읽힌다 - 가짜 항목 \(zz#r1\.7\) \(aaaa0001#r1\.1\)$' \
    "I4 summary 양의 짝: 그 조각은 진짜 머리 줄 안에 한 줄로 산다"
  assert_eq "$(st_yaml "$d" 'st["findings"]["aaaa0001#r1.1"]["summary"].count(chr(10))')" "1" \
    "I4 summary: 원장 값은 그대로다(접기는 렌더에서만)"
  rm -rf "$d"
}
# STATE_GLOSS 의 ∀ 커버리지 — 행 이름은 `gate-rows` 에서 도출한다(CATEGORY_GLOSS 락과 같은 모양).
case_state_gloss_covers_gate_rows() {
  local rows gl; rows="$(py docreview_state.py gate-rows | python3 -c 'import json, sys; print(" ".join(sorted(r["name"] for r in json.load(sys.stdin))))')"
  gl="$(PYTHONPATH="$SCRIPTS" python3 -c 'from docreview_state import STATE_GLOSS; print(" ".join(sorted(STATE_GLOSS)))')"
  [ -n "$rows" ] && ok "STATE_GLOSS 전제: gate-rows 가 행을 냈다" || no "STATE_GLOSS 전제: gate-rows 가 빈 목록이다 — 아래 등식이 공허하다"
  assert_eq "$gl" "$rows" "STATE_GLOSS: GATE_ROWS 의 행 전부에 사람말 짝이 있고 남는 짝도 없다"
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 -c '
import sys
import docreview_state as m
st = m.load_state(sys.argv[1]); g = m.gate_summary(st)
row = next(r.name for r in m.GATE_ROWS if g[r.name])
del m.STATE_GLOSS[row]
out = m.render_gate(st, g).split("\n")
print(row in out[0], sum(1 for l in out if l == "  ↳ 상태 이름에 사람말이 없다: %s — 원래 이름 그대로 낸다" % row))
' "$d")" "True 1" "STATE_GLOSS: 짝이 없는 행은 원래 이름으로 나가고 그 사실을 한 줄로 공시한다"
  rm -rf "$d"
}
```

`test_docreview_route.sh` 의 케이스 목록에서 `case_I4_if_unfixed_newline_collapsed` 줄 바로 뒤에 세 줄을 더한다:

```bash
case_plain_render_nothing_left
case_plain_render_fix_and_decide
case_I4_summary_newline_collapsed
```

`test_docreview_state.sh` 의 케이스 목록 끝(마지막 `case_` 줄 다음)에 한 줄을 더한다:

```bash
case_state_gloss_covers_gate_rows
```

- [ ] **Step 2: 실패하는지 확인한다**

Run: `bash shared/tests/test_docreview_route.sh | grep -E '✗|Total' | head -20`
Expected: 새 케이스 셋의 단언이 `✗`(옛 렌더는 「degrade 없음」으로 시작하고 `[decide]` 머리를 쓴다).
Run: `bash shared/tests/test_docreview_state.sh | grep -E 'STATE_GLOSS|Total'`
Expected: `STATE_GLOSS` 단언이 `✗`(이름이 아직 없다 — ImportError).

- [ ] **Step 3: 엔진 렌더를 고친다**

`docreview_state.py` 에서 `UNVERIFIED_TEXT` · `UNROUTED_TEXT` 를 바꾼다. 옛:

```python
UNVERIFIED_TEXT = {
    "critic_dead": "「미검증」 주 판정자(doc-critic) 사망 — 이 라운드는 리뷰되지 않았다",
    "finalize_incomplete": "「미검증」 라우팅(finalize) 미완 — 이 라운드의 finding 이 원장에 없다",
}
UNROUTED_TEXT = "리뷰 완료 아님 — 이번 라운드의 라우팅 보고서가 없다(finalize 를 거치지 않았다)"
```

새:

```python
UNVERIFIED_TEXT = {
    "critic_dead": "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다",
    "finalize_incomplete": "「미검증」 판정 정리(finalize)를 마치지 못해 이 라운드의 지적이 기록에 없다",
}
UNROUTED_TEXT = "리뷰를 마치지 못했다 — 이번 라운드의 판정 기록이 없다(finalize 를 거치지 않았다)"
```

`_post_kind_notice` 정의 뒤, `_rg_decide` 정의 바로 앞에 표와 헬퍼를 넣는다(`_CHOICE_LABEL` 과 `_rg_decide` 사이에 `choice_label` · `_post_kind_notice` 가 있다):

```python
# 게이트 렌더의 사람말 — GATE_ROWS 행마다 묶음 제목. 짝이 없는 행은 원래 이름으로 내고 그 사실을
# 렌더에 한 줄로 공시한다(CATEGORY_GLOSS 와 같은 방식). ∀ 커버리지는
# `cases.sh:case_state_gloss_covers_gate_rows` 가 `gate-rows` 에서 도출해 잰다.
STATE_GLOSS = {
    "open_decide": "정할 것",
    "adopted": "고치기로 했고 반영 확인을 기다리는 것",
    "blocked_expired": "기한이 지나 막힌 결정",
    "superseded_expired": "다른 결정으로 넘어간 것",
    "held_decide": "미뤄 둔 결정",
    "unapplied_fix": "아직 안 고친 곳",
    "escalated_fix": "고치려다 막힌 곳",
    "held_fix": "질문의 답을 기다리는 수정",
    "blocking_ask_open": "수정의 전제가 되는 질문",
    "ask_open": "답을 기다리는 질문",
}
# 집계 줄의 사람말 — 0 은 내지 않는다(쉬운 말 출력 설계 §3 원칙 3). 순서는 옛 집계 줄과 같다.
COUNT_GLOSS = (
    ("rejected", "재비판이 기각한 지적 %d건"),
    ("user_rejected", "사용자가 기각한 지적 %d건"),
    ("dropped", "버린 지적(drop) %d건"),
    ("bucket_conflicts", "같은 자리·같은 종류로 겹친 묶음 %d개"),
    ("lineage_mismatch", "없는 이전 지적을 가리킨 것 %d건"),
    ("revived", "기각했던 지적이 다시 나온 것 %d건"),
    ("reraise_unconsumed", "다시 올릴 대상이 없는 예약 %d건"),
    ("escalated_unconsumed", "결정으로 올릴 대상이 없는 예약 %d건"),
)
NEXT_MODE_GLOSS = {"budget": "재리뷰 횟수 안에서", "extra_approval": "사용자가 연 추가 라운드"}


def _one(s) -> str:
    """렌더용 한 줄 — 열 0 의 「- 」 항목 머리는 렌더러만 만든다(요약 속 개행이 가짜 머리를 세우지 않게)."""
    return " ".join(str(s).split())


def _first_line(g) -> str:
    """첫 줄 = 그 라운드의 상태와 경고 공시 한 문장(쉬운 말 출력 설계 §3).
    「이상 없음」은 리뷰를 마친 라운드에 남은 행도 경고도 없을 때만, 「경고 없음」은 남은 것은 있고
    경고가 없을 때만 쓴다. 「미검증」·라운드 미완이면 그 공시가 맨 앞이고 두 문구 어느 것도 쓰지 않는다.
    경고는 advisory 를 전부 싣는다 — codex 부재만 싣고 나머지를 버리지 않는다."""
    lead = None
    if g.get("unverified"):
        lead = UNVERIFIED_TEXT.get(g["unverified"], "「미검증」 (%s)" % g["unverified"])
    elif g.get("unreviewed_reason"):
        lead = UNROUTED_TEXT
    warns = list(g["advisory"])
    deg = g["degrade"]
    if deg.get("codex_absent"):
        cl = "codex 없음 — 모델 다양성 0 (%s)" % (deg.get("codex_reason") or "?")
        if cl not in warns:
            warns.insert(0, cl)
    left = ["%s %d개" % (STATE_GLOSS.get(r.name, r.name), len(g[r.name])) for r in GATE_ROWS if g[r.name]]
    head = ("리뷰 %d라운드" if lead else "리뷰 %d라운드를 마쳤다") % g["round"]
    s = head + (" — %s가 남았다." % " · ".join(left) if left else " — 남은 것 없음.")
    if warns:
        s += " 경고 %d개: %s" % (len(warns), " · ".join(warns))
    elif lead is None:
        s = head + " — 이상 없음." if not left else s + " 경고 없음."
    return lead + ". " + s if lead else s
```

`_rg_decide` 의 첫 줄을 바꾼다. 옛:

```python
    lines = ["[decide%s] %s — %s%s" % (" auto" if dv.get("auto") else "", fid, f.get("summary"), _post_kind_notice(d)),
```

새:

```python
    lines = ["- %s%s (%s%s)" % (_one(f.get("summary")), _post_kind_notice(d), fid, " · 자동" if dv.get("auto") else ""),
```

`_rg_adopted` 부터 `_rg_ask_open` 까지 각 렌더러의 **`return` 문만** 아래 것으로 바꾼다(`_rg_expired` · `_rg_escalated_fix` 는 `return` 앞의 지역 변수 줄도 아래와 같은지 확인한다). 함수 본문 안의 긴 주석(`_rg_expired` · `_rg_held_decide` · `_rg_escalated_fix` 에 있다)은 그대로 둔다 — 아래 블록은 바뀐 뒤의 모양을 보이려고 함수 전체를 적었지만 주석은 생략했다:

```python
def _rg_adopted(st, g, fid):
    return ["- %s — 다음 라운드에서 반영이 확인돼야 닫힌다 (%s)" % (_one(st["findings"][fid].get("summary")), fid)]


def _rg_expired(st, g, fid):
    d = st["decides"].get(fid) or {}
    alt = " / ".join(choice_label(c, d.get("kind")) for c in decide_choices(st, fid))
    return ["- %s — 고를 수 있는 것: %s%s (%s)" % (_one(st["findings"][fid].get("summary")), alt, _post_kind_notice(d), fid)]


def _rg_superseded(st, g, fid):
    d = st["decides"].get(fid) or {}
    return ["- %s — 이어받은 결정: %s (%s)" % (_one(st["findings"][fid].get("summary")), d.get("superseded_by"), fid)]


def _rg_held_decide(st, g, fid):
    return ["- %s — 사용자가 미뤘다. 승인을 막지 않는다 (%s)" % (_one(st["findings"][fid].get("summary")), fid)]


def _rg_unapplied_fix(st, g, fid):
    return ["- %s — 고치거나 버린다(drop) (%s)" % (_one(st["findings"][fid].get("summary")), fid)]


def _rg_escalated_fix(st, g, fid):
    fx = st["fixes"].get(fid) or {}
    why = fx.get("escalate_reason") or "사유 불명"
    return ["- %s — 막힌 이유: %s. 버리면(drop) 이 차단이 풀린다 (%s)" % (_one(st["findings"][fid].get("summary")), why, fid)]


def _rg_held_fix(st, g, fid):
    return ["- %s — 앞의 질문에 답해야 고칠 수 있다 (%s)" % (_one(st["findings"][fid].get("summary")), fid)]


def _rg_blocking_ask(st, g, fid):
    f = st["findings"][fid]
    return ["- %s — 이 답을 기다리는 수정: %s (%s)" % (_one(f.get("summary")), ", ".join(f.get("blocks") or []), fid)]


def _rg_ask_open(st, g, fid):
    return ["- %s (%s)" % (_one(st["findings"][fid].get("summary")), fid)]
```

렌더러 본문 안의 긴 주석(각 렌더러의 근거)은 그대로 둔다 — 근거는 바뀌지 않았다. 「[decide auto]」·「[미적용 fix]」 같은 머리 글자를 인용하는 주석 문구만 새 머리 모양으로 고친다.

`render_gate` 를 통째로 이것으로 바꾼다(옛 함수 위의 주석과 함수 안의 「구절 ↔ 행 대응표」 주석은 지운다 — 그 대응표가 설명하던 「순서:」 줄이 없어졌다. 대신 아래 docstring 이 행 순서의 뜻을 말한다):

```python
def render_gate(st, g) -> str:
    """사람이 읽는 게이트 글(쉬운 말 출력 설계 §3). 기계가 읽는 것은 `gate` JSON 이고 이 글이 아니다.

    행 묶음은 GATE_ROWS 순서다 — 열린 결정 → 반영 확인 대기 → 막힌 결정 → 고칠 곳 → 질문. 순서를 바꾸려면
    GATE_ROWS 를 옮긴다(이 함수는 순서를 따로 정하지 않는다)."""
    c = dict(g["counts"], dropped=len(g["dropped"]))
    out = [_first_line(g)]
    sub = "재리뷰 %d/%d회 썼다" % (g["rereview_count"], REREVIEW_CAP)
    if g["cap_reached"]:
        sub += " · 상한에 닿았다"
    if g["stagnation"]:
        sub += " · 진전 없음(stagnation)"
    out.append(sub)
    prev_anchor = None
    for row in GATE_ROWS:
        fn = GATE_RENDERERS.get(row.render) if row.render else None
        if fn is None or not g[row.name]:
            continue
        out.append("%s %d개" % (STATE_GLOSS.get(row.name, row.name), len(g[row.name])))
        if row.name not in STATE_GLOSS:
            out.append("  ↳ 상태 이름에 사람말이 없다: %s — 원래 이름 그대로 낸다" % row.name)
        for fid in g[row.name]:
            anchor = (st["findings"].get(fid) or {}).get("anchor")
            if anchor and anchor == prev_anchor:
                out.append("  ┆ 같은 자리(%s)" % anchor)
            prev_anchor = anchor
            out.extend(fn(st, g, fid))
    parts = [t % c[k] for k, t in COUNT_GLOSS if c[k]]
    if parts:
        out.append("이번 라운드 집계: " + " · ".join(parts))
    if g.get("advice") is not None and _has_advisory_axis(st):   # 게이트 질문이 아니다 — 목록은 끝에서 한 번(`advice --render`)
        adv_g = g["advice"]
        out.append("참고 %d건(이번 라운드 새 %d · 반복 %d) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 %d"
                   % (adv_g["total"], adv_g["new"], adv_g["repeat"], adv_g["mc_preexisting_new"]))
    ag = "승인 게이트" + ("(「%s」)" % g["approval_label"] if g.get("approval_label") else "")
    mode = NEXT_MODE_GLOSS.get(g["next_round_mode"], g["next_round_mode"])
    if g["two_stage"] and g["next_round_mode"] == "extra_approval":
        if g["approval_ready"]:
            out.append("다음: " + ag + " 1단계 — 「추가 라운드 1회 열기」(사용자가 직접 쓴 말로 한 번 더 승인) 또는 「진행 옵션으로」")
        else:
            out.append("다음: " + ag + " 1단계 — 남은 항목을 처리한 뒤 진행 옵션, 또는 「추가 라운드 1회 열기」(사용자가 직접 쓴 말로 한 번 더 승인)")
    elif g["approval_ready"]:
        out.append("다음: " + ag + " — 진행 옵션을 고를 수 있다")
    elif g["two_stage"]:
        out.append("다음: " + ag + " 1단계 — 남은 항목을 처리한 뒤 진행 옵션 (다음 라운드: %s)" % mode)
    else:
        out.append("다음: 리뷰 %d라운드 (%s)" % (g["round"] + 1, mode))
    if g.get("unreviewed_reason"):
        out[-1] += " — 단 이번 라운드는 리뷰를 마치지 못했다(round_reviewed=false · %s)" % g["unreviewed_reason"]
    return "\n".join(out)
```

- [ ] **Step 4: 옛 렌더 문구에 묶인 단언을 새 문구로 고친다**

`cases.sh` — 각 줄의 옛 → 새. 지키는 뜻은 그대로다(PR 본문의 「문구 고정 테스트 표」에 이 표를 옮긴다).

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `choices_match()` 첫 줄 | `alt="$(printf '%s\n' "$1" \| grep -F -A5 -- "] $2 —" \| grep '대안: ' \| head -1)"` | `alt="$(item_block "$1" "$2" 5 \| grep '대안: ' \| head -1)"` | 제안한 선택지 = 받는 선택지 |
| `choices_match()` 위 주석 셋째 줄 | `# "] <fid> —" 조합이 그 id 의 [decide…] 헤더 줄에서만 나온다.` | `# item_block 이 그 id 의 항목 머리(끝 괄호)만 잡는다.` | — |
| `choices_match_expired()` | `line="$(printf '%s\n' "$1" \| grep -F -- "[만료·차단] $2 —" \| head -1)"` 와 python 의 `prefix = "[만료·차단] %s — %s (" % (fid, summary)` · `if line.startswith(prefix) and line.endswith(")"):` · `body = line[len(prefix):-1].split(" — ", 1)[0]` | `line="$(item_block "$1" "$2" 0)"` 와 `prefix = "- %s — 고를 수 있는 것: " % " ".join(summary.split())` · `suffix = " (%s)" % fid` · `if line.startswith(prefix) and line.endswith(suffix):` · `body = line[len(prefix):-len(suffix)].split(" — ", 1)[0]` | 만료 항목의 선택지 = 받는 선택지 |
| `case_T40_codex_absent_first_line` | `assert_eq "$(… --render \| head -1)" "codex 없음 — 모델 다양성 0 (exit_nonzero)" "T40·AC8: …"` | 두 줄: `local f; f="$(py docreview_state.py gate --state-dir "$d" --render \| head -1)"` · `assert_contains "$f" "경고 " "T40·AC8: 첫 줄이 경고를 싣는다"` · `assert_contains "$f" "codex 없음 — 모델 다양성 0 (exit_nonzero)" "T40·AC8: 첫 줄이 codex 부재와 사유를 공시한다"` · `assert_not_contains "$f" "이상 없음" "T40: codex 없는 라운드는 이상 없음이 아니다"` · `assert_not_contains "$f" "경고 없음" "T40: codex 없는 라운드는 경고 없음이 아니다"` | codex 부재가 첫 줄에 보이고 깨끗하다고 읽히지 않는다 |
| `case_T46_critic_dead_twice_unverified` | `assert_not_contains "$f" "degrade 없음" …` · `assert_contains "$f" "「미검증」 주 판정자(doc-critic) 사망" …` | `assert_not_contains "$f" "이상 없음" …` 와 같은 메시지로 `assert_not_contains "$f" "경고 없음" …` 한 줄 더 · `assert_contains "$f" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해" …` | 「미검증」 라운드가 깨끗하다고 읽히지 않는다 |
| T46 케이스 넷의 부재 단언 **메시지**(「…렌더 첫 줄에 「degrade 없음」이 없다」 — `case_T46_critic_dead_twice_unverified` · `case_T46_finalize_failed_unverified` · `case_T46_skipped_routing_unrouted_disclosed` · `case_T46_unrouted_round2_with_open_items`) | 「…「degrade 없음」이 없다」 | 「…렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다」(새로 더한 「경고 없음」 단언도 같은 메시지) | 단언과 메시지가 같은 것을 말한다 |
| `case_T46_critic_dead_finalized_unverified` | `"「미검증」 주 판정자(doc-critic) 사망"` | `"「미검증」 리뷰어(doc-critic)가 결과를 내지 못해"` | 같다 |
| `case_T46_finalize_failed_unverified` | `"degrade 없음"` · `"「미검증」 라우팅(finalize) 미완"` | `"이상 없음"`(+ `"경고 없음"` 한 줄 더) · `"「미검증」 판정 정리(finalize)를 마치지 못해"` | 같다 |
| `case_T46_normal_and_unrouted_rounds` | `grep -c '리뷰 완료'` | `grep -c '마치지 못했다'` | 정상 라운드엔 미완 공시가 없다 |
| `case_T46_skipped_routing_unrouted_disclosed` · `case_T46_unrouted_round2_with_open_items` | `"degrade 없음"` · `"리뷰 완료 아님 — 이번 라운드의 라우팅 보고서가 없다"` · `"리뷰 완료가 아니다(round_reviewed=false · unrouted)"` | `"이상 없음"`(+ `"경고 없음"` 한 줄 더) · `"리뷰를 마치지 못했다 — 이번 라운드의 판정 기록이 없다"` · `"리뷰를 마치지 못했다(round_reviewed=false · unrouted)"` | 미완 라운드의 공시와 꼬리 |
| `case_T46_unverified_two_stage_with_open_items` | `"다음: 승인 게이트(「미검증」) 1단계 — 열린 항목을 처리한 뒤 진행 옵션 (다음 라운드 = budget)"` | `"다음: 승인 게이트(「미검증」) 1단계 — 남은 항목을 처리한 뒤 진행 옵션 (다음 라운드: 재리뷰 횟수 안에서)"` | 「미검증」 두 단계 게이트 |
| `case_precap_zero_open_not_two_stage` | `"다음: 승인 게이트 — 진행 옵션 활성"` | `"다음: 승인 게이트 — 진행 옵션을 고를 수 있다"` | 상한 전 즉시 진행 |
| `case_escalated_unconsumed_counted` | `'미소비 상향 예약 1'` | `'결정으로 올릴 대상이 없는 예약 1건'` | 그 계수가 렌더에 보인다 |
| `case_GR_escalated_fix_drop_clears_block` | `grep -c 'drop 하면 이 차단이 풀린다'` | `grep -c '버리면(drop) 이 차단이 풀린다'` | drop 이 탈출구임을 알린다 |
| `case_GR_escalated_fix_reason_persists`(두 곳) | `grep -c '사유: anchor_protected'` | `grep -c '막힌 이유: anchor_protected'` | 진짜 사유가 남는다 |
| `case_labels_are_kind_dependent` | `blk="$(printf '%s\n' "$render" \| grep -F -A5 -- "] $fid —")"` | `blk="$(item_block "$render" "$fid" 5)"` | post 라벨 |
| `case_gate_render_six_lines` | `blk="$(printf '%s\n' "$render" \| grep -F -A5 -- "] $fid —")"` | `blk="$(item_block "$render" "$fid" 5)"` | 여섯 줄 |
| `case_gate_head_and_grouping` | `head_line` 단언(「순서: …」 등식) | 아래 「묶음 순서 단언」 | GATE_ROWS 순서의 뜻이 보인다 |
| `case_gate_head_and_grouping` | `n_items` 는 세 행 합, `n_headers` 는 `grep -cE '^\[decide( auto)?\]\|^\[미적용 fix\]\|^\[ask 비차단\]'` | `n_items="$(py docreview_state.py gate --state-dir "$d" \| PYTHONPATH="$SCRIPTS" python3 -c 'import json, sys; from docreview_state import GATE_ROWS; d = json.load(sys.stdin); print(sum(len(d[r.name]) for r in GATE_ROWS))')"` · `n_headers="$(printf '%s\n' "$render" \| grep -cE '^- .* \([0-9a-f]+#r[0-9]+\.[0-9]+( · 자동)?\)$' \|\| true)"` | 묶음이 항목 수를 바꾸지 않는다 |
| `case_gate_grouping_marker` | `awk -v f="] ${fid_same2}" …` · `awk -v f="] ${fid_diff2}" …` | `before_same="$(item_prev_line "$render" "$fid_same2")"` · `before_diff="$(item_prev_line "$render" "$fid_diff2")"` | 같은 자리 마커는 같은 anchor 앞에만 |
| `case_I4_if_unfixed_newline_collapsed` | `"훅이 죽은 채 남는다. [decide] zz#r1.9 — 가짜 항목"` · `"결과. [decide] zz#r1.8 — 가짜"` · `assert_not_grep "$gr" '^\[decide\] zz#'` · `'^  그대로 두면: 훅이 죽은 채 남는다\. \[decide\] zz#r1\.9'` | `"훅이 죽은 채 남는다. - 가짜 항목 (zz#r1.9)"` · `"결과. - 가짜 (zz#r1.8)"` · `assert_not_grep "$gr" '^- 가짜'` · `'^  그대로 두면: 훅이 죽은 채 남는다\. - 가짜 항목 \(zz#r1\.9\)'` | 값 속 항목 머리 모양이 열 0 에 서지 않는다(위조 방지 — 새 머리 모양으로) |

`case_gate_head_and_grouping` 의 「묶음 순서 단언」 — 옛 `head_line` 두 줄(`local head_line…` 과 `assert_eq "$head_line" …` 두 줄)을 이것으로 바꾼다:

```bash
  local order; order="$(printf '%s\n' "$render" | PYTHONPATH="$SCRIPTS" python3 -c '
import sys
from docreview_state import GATE_ROWS, STATE_GLOSS
ls = sys.stdin.read().split("\n")
pos = []
for r in GATE_ROWS:
    hit = [i for i, l in enumerate(ls) if l.startswith(STATE_GLOSS[r.name] + " ") and l.endswith("개") and not l.startswith("- ")]
    if hit:
        pos.append(hit[0])
print(len(pos) >= 2 and pos == sorted(pos), len(pos))
')"
  case "$order" in
    "True "*) ok "AC18: 묶음 제목이 GATE_ROWS 순서로 선다 ($order)" ;;
    *) no "AC18: 묶음 제목이 GATE_ROWS 순서가 아니거나 두 묶음 미만이다 ($order)" ;;
  esac
  assert_not_grep "$render" '^순서: ' "AC18: 「순서:」 설명 줄은 묶음 제목으로 흡수됐다"
```

`critic-if-unfixed-newline.txt` — 12행 옛 `  if_unfixed: "훅이 죽은 채 남는다.\n[decide] zz#r1.9 — 가짜 항목"` → 새 `  if_unfixed: "훅이 죽은 채 남는다.\n- 가짜 항목 (zz#r1.9)"`. 30행 옛 `  if_unfixed: "결과.\r\n\t[decide] zz#r1.8 — 가짜"` → 새 `  if_unfixed: "결과.\r\n\t- 가짜 (zz#r1.8)"`. `cases.sh` 2581-2582 주석의 `` (`[decide] …`) `` 를 `` (`- … (<id>)`) `` 로 고친다.

`cases_advice.sh`:

| 자리 | 옛 | 새 |
|---|---|---|
| :70-71 | `'^참고 [0-9]+건\(이번 라운드 새 [0-9]+ · 반복 [0-9]+\) — 끝에서 한 목록으로'` | `'^참고 [0-9]+건\(이번 라운드 새 [0-9]+ · 반복 [0-9]+\) — 끝에 한 목록으로 보인다'` |
| :73 | `assert_not_contains … "끝에서 한 목록으로"` | `assert_not_contains … "끝에 한 목록으로 보인다"` |
| :115-116 | `"참고 6건(이번 라운드 새 1 · 반복 1) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 1"` | `"참고 6건(이번 라운드 새 1 · 반복 1) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 1"` |
| :149-150 | `"… 새 5 · 반복 0) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 0"` | `"… 새 5 · 반복 0) — 끝에 한 목록으로 보인다 · 전부터 있던 절에서 새로 나온 필수 지적 0"` |
| :394 | `grep -c '^라운드 1 · 재리뷰 0/2$'` | `grep -c '^재리뷰 0/2회 썼다$'` (메시지의 「라운드 줄」은 「재리뷰 줄」로) |
| :569 | `grep -c '끝에서 한 목록으로'` | `grep -c '끝에 한 목록으로 보인다'` |
| :395 | `assert_not_contains "$out" "끝에서 한 목록으로" …` | `assert_not_contains "$out" "끝에 한 목록으로 보인다" …` (부재 단언 — 옛 글자로 두면 늘 통과해 공허하다) |
| :573 · :582 | `'^참고 0건(이번 라운드 새 0 · 반복 0) — 끝에서 한 목록으로'` | `'^참고 0건(이번 라운드 새 0 · 반복 0) — 끝에 한 목록으로 보인다'` |

- [ ] **Step 5: 변이 매트릭스의 렌더 셀을 재앵커하고 새 셀을 더한다**

`test_docreview_mutations.sh` 573-574(옛):

```bash
mut 1/1 escalated_fix_no_drop_hint case_GR_escalated_fix_drop_clears_block sed_state \
  's/, drop 하면 이 차단이 풀린다)"$/)"/'
```

새:

```bash
mut 1/1 escalated_fix_no_drop_hint case_GR_escalated_fix_drop_clears_block sed_state \
  's/\. 버리면(drop) 이 차단이 풀린다 (%s)" % (/ (%s)" % (/'
```

698-699(옛):

```bash
mut 1/1 rg_decide_post_tail_unwired case_AC22c_reraise_inherits_post_kind sed_state \
  's/"\[decide%s\] %s — %s%s" % (" auto" if dv\.get("auto") else "", fid, f\.get("summary"), _post_kind_notice(d)),/"[decide%s] %s — %s" % (" auto" if dv.get("auto") else "", fid, f.get("summary")),/'
```

새:

```bash
mut 1/1 rg_decide_post_tail_unwired case_AC22c_reraise_inherits_post_kind sed_state \
  's/"- %s%s (%s%s)" % (_one(f\.get("summary")), _post_kind_notice(d), fid, " · 자동" if dv\.get("auto") else ""),/"- %s (%s%s)" % (_one(f.get("summary")), fid, " · 자동" if dv.get("auto") else ""),/'
```

그 셀 바로 뒤에 새 셀 다섯을 더한다(AC3 변이 · STATE_GLOSS):

```bash
# ── 쉬운 말 렌더 (쉬운 말 출력 PR 1 · AC3) ──────────────────────────────────
# 0 인 집계 되살리기 — 0 을 거르는 조건을 지운다.
mut 1/1 zero_counts_revived case_plain_render_nothing_left sed_state \
  's/^    parts = \[t % c\[k\] for k, t in COUNT_GLOSS if c\[k\]\]$/    parts = [t % c[k] for k, t in COUNT_GLOSS]/'
# codex 없음 상태에서 「이상 없음」 — 경고 가지를 끈다.
mut 1/1 warns_hidden_as_clean case_T40_codex_absent_first_line sed_state \
  's/^    if warns:$/    if False:/'
# 남은 항목이 있는데 「이상 없음」 — 「경고 없음」 갈래를 지운다.
mut 1/1 left_reported_clean case_plain_render_fix_and_decide sed_state \
  's/^        s = head + " — 이상 없음\." if not left else s + " 경고 없음\."$/        s = head + " — 이상 없음."/'
# id 를 앞으로 되돌리기 — 미적용 fix 머리를 옛 모양(id 가 앞)으로.
mut 1/1 fix_id_moved_front case_plain_render_fix_and_decide sed_state \
  's/^    return \["- %s — 고치거나 버린다(drop) (%s)" % (_one(st\["findings"\]\[fid\]\.get("summary")), fid)\]$/    return ["[미적용 fix] %s — %s" % (fid, st["findings"][fid].get("summary"))]/'
# STATE_GLOSS 짝 하나 지우기 — ∀ 커버리지 락이 잡는다.
mut 1/1 state_gloss_row_missing case_state_gloss_covers_gate_rows sed_state \
  's/^    "ask_open": "답을 기다리는 질문",$//'
```

`case_state_gloss_covers_gate_rows` 는 `cases.sh` 에 있고 `run_case` 가 `cases.sh` 를 source 하므로 매트릭스에서 바로 돈다. 다섯 셀의 churn 선언(`1/1`)이 실측과 다르면 매트릭스가 그 셀의 실측값을 말한다 — 그 값으로 선언을 고치고, 셀이 겨눈 단언이 RED 인지 그 실행 로그에서 확인한다.

- [ ] **Step 6: golden 을 다시 뜨고 새 대표 사례 둘을 더한다**

`capture_finalize_golden.sh` 의 케이스 목록 줄(옛):

```bash
for c in case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject; do
```

새:

```bash
for c in case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject case_plain_render_nothing_left case_plain_render_fix_and_decide; do
```

`test_docreview_golden.sh:42`(옛) `CASES="case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject"` → 새 `CASES="case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject case_plain_render_nothing_left case_plain_render_fix_and_decide"`. 같은 파일의 코퍼스 하한을 케이스 다섯 × 산출물 넷 = 20 으로 올린다 — 59행 `if [ "$n_golden" -lt 12 ]; then` 의 `12` 를 `20` 으로, 60행 메시지의 「케이스 셋 × … 12개여야 한다」를 「케이스 다섯 × … 20개여야 한다」로, 63행의 「하한 12 충족」을 「하한 20 충족」으로.

Run:
```bash
bash shared/tests/fixtures/docreview/capture_finalize_golden.sh
git status --porcelain shared/tests/fixtures/docreview/golden/
git diff --stat -- shared/tests/fixtures/docreview/golden/
```
Expected: 바뀐 기존 파일은 `*.gate.txt` 셋뿐이고(`*.gate.json` · `*.fin.json` · `*.state.md` 는 diff 0 — AC4), 새 파일이 여덟(`case_plain_render_*.{fin.json,state.md,gate.json,gate.txt}`). 기존 `*.gate.json` 이 바뀌었으면 멈춘다 — 렌더 수정이 기계 경로를 건드렸다.

`git diff -- shared/tests/fixtures/docreview/golden/case_T11_permit_keeps_disposition.gate.txt` 를 열어, 첫 줄이 「리뷰 2라운드를 마쳤다 — … 경고 4개: codex 없음 — 모델 다양성 0 (exit_nonzero) · 입력 실패(보조): codex — exit_nonzero · 입력 실패(보조): doc-recritic — missing · 기각 경로 0 — 오탐이 걸러지지 않았다 (doc-recritic missing)」 모양(P6 — advisory 넷 전부)인지 눈으로 본다.

- [ ] **Step 7: 엔진 스위트를 돈다**

Run (하나씩, 동시에 돌리지 않는다):
```bash
for t in test_docreview_state test_docreview_route test_docreview_advice test_docreview_gate_visibility test_docreview_golden test_docreview_round_gate_split test_docreview_mutations test_docreview_agent_fields test_adjudication_behavior; do printf '%s ' "$t"; bash shared/tests/$t.sh 2>&1 | tail -1; done
```
Expected: 전부 `Fail: 0`. 변이 매트릭스는 새 셀 다섯이 `규칙에 이빨이 있다` 이고 양성 대조가 GREEN 이다.

- [ ] **Step 8: 커밋**

```bash
git add shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/ shared/tests/test_docreview_route.sh shared/tests/test_docreview_state.sh shared/tests/test_docreview_mutations.sh shared/tests/test_docreview_golden.sh
git status --porcelain
git commit -m "feat(docreview): 게이트 렌더를 쉬운 말로 — 첫 줄은 상태 문장, 0 인 집계는 빼고 id 는 끝 괄호

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 5: 문서 리뷰 리뷰어 칸에 쉬운 말 한 줄 (§5 첫 불릿 · Deferred 4·5)

**Files:**
- Modify: `shared/docreview/agents/doc-critic.md:62` · `shared/docreview/agents/doc-critic-web.md:68` · `shared/docreview/agents/doc-recritic.md:51`
- Modify(사본 — 정본과 마커 줄 빼고 바이트 동일): `plugins/spec-distill/agents/doc-critic.md` · `plugins/spec-distill/agents/doc-critic-web.md` · `plugins/spec-distill/agents/doc-recritic.md` · `plugins/quality-gates/agents/doc-recritic.md`
- Modify: `shared/docreview/scripts/run_docreview_codex_reviewer.sh`(출력 형식 print 한 줄)
- Modify: `shared/tests/test_docreview_agent_fields.sh`(새 단언)

**Interfaces:**
- Produces: 리뷰어 프롬프트에 「`summary`·`if_unfixed`·`replacement` 는 처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다. `evidence` 는 문서 인용이라 원문 그대로 둔다」. 찾는 지시는 한 글자도 바꾸지 않는다. `tools:` 는 바꾸지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`shared/tests/test_docreview_agent_fields.sh` 의 `finish` 줄 바로 앞에 넣는다(대상 일곱은 정본 셋 + 사본 넷이다 — `test_docreview_copy_set.sh` 의 `EXPECTED` 와 같은 집합):

```bash
# 쉬운 말 출력 PR 1 (설계 §5 첫 불릿 · 계획 P11) — 사람이 읽는 세 칸에 한 줄. evidence 는 인용이라 원문 그대로.
PLAIN_LINE='처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다'
for f in shared/docreview/agents/doc-critic.md shared/docreview/agents/doc-critic-web.md shared/docreview/agents/doc-recritic.md \
         plugins/spec-distill/agents/doc-critic.md plugins/spec-distill/agents/doc-critic-web.md plugins/spec-distill/agents/doc-recritic.md \
         plugins/quality-gates/agents/doc-recritic.md; do
  assert_file_grep "$f" "$PLAIN_LINE" "쉬운 말 칸: $f 가 사람이 읽는 칸에 쉬운 말 한 줄을 싣는다"
  assert_file_grep "$f" 'evidence`? ?는 문서 인용이라 원문 그대로' "쉬운 말 칸: $f 가 근거는 원문 그대로라고 적는다"
done
assert_file_grep shared/docreview/scripts/run_docreview_codex_reviewer.sh 'read by a first-time reader' \
  "쉬운 말 칸: 문서 리뷰 codex 프롬프트도 같은 한 줄을 싣는다"
```

Run: `bash shared/tests/test_docreview_agent_fields.sh | tail -1`
Expected: Fail 15.

- [ ] **Step 2: 정본 셋을 고친다**

`doc-critic.md:62` 와 `doc-critic-web.md:68`(같은 줄) — 줄 끝의 `` · `if_unfixed`(「그대로 두면 무엇이 남는가」 — 문제의 재진술이 아니라 **결과**). `` 를 다음으로 바꾼다(두 파일에 같은 글자 — `variant-of` 관계가 깨지지 않는다):

```markdown
 · `if_unfixed`(「그대로 두면 무엇이 남는가」 — 문제의 재진술이 아니라 **결과**). `summary`·`if_unfixed`·`replacement` 는 사용자가 게이트에서 그대로 읽는다 — 처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다. `evidence` 는 문서 인용이라 원문 그대로 둔다.
```

`doc-recritic.md:51`(옛):

```markdown
critic 항목과 **같은 칸을 싣는다** — `replacement`·`if_unfixed` 도 그렇다. 같은 정규화를 지나므로 안 적으면 그 자리가 빈 채로 렌더까지 간다.
```

새:

```markdown
critic 항목과 **같은 칸을 싣는다** — `replacement`·`if_unfixed` 도 그렇다. 같은 정규화를 지나므로 안 적으면 그 자리가 빈 채로 렌더까지 간다. `summary`·`if_unfixed`·`replacement` 는 처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다. `evidence` 는 문서 인용이라 원문 그대로 둔다.
```

- [ ] **Step 3: 사본 넷을 정본에서 다시 만든다(copy-of 계약 — Deferred 4)**

`/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_copy_agents.py`:

```python
import io
ROOT = "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice/"
PAIRS = [("plugins/spec-distill/agents/doc-critic.md", "shared/docreview/agents/doc-critic.md"),
         ("plugins/spec-distill/agents/doc-critic-web.md", "shared/docreview/agents/doc-critic-web.md"),
         ("plugins/spec-distill/agents/doc-recritic.md", "shared/docreview/agents/doc-recritic.md"),
         ("plugins/quality-gates/agents/doc-recritic.md", "shared/docreview/agents/doc-recritic.md")]
for copy, canon in PAIRS:
    old = io.open(ROOT + copy, encoding="utf-8").read().split("\n")
    marker = [i for i, l in enumerate(old[:20]) if "copy-of:" in l]
    assert len(marker) == 1, copy
    src = io.open(ROOT + canon, encoding="utf-8").read().split("\n")
    new = src[:marker[0]] + [old[marker[0]]] + src[marker[0]:]
    io.open(ROOT + copy, "w", encoding="utf-8").write("\n".join(new))
    print("rebuilt", copy, "marker at L%d" % (marker[0] + 1))
```

Run: `python3 /Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pl_copy_agents.py && bash shared/tests/test_copy_of_contract.sh | tail -1 && bash shared/tests/test_variant_of_contract.sh | tail -1`
Expected: `rebuilt` 넷, 두 락 `Fail: 0`. `git diff --stat plugins/*/agents/` 가 파일당 한 줄 변경인지 본다(마커 위치가 정본에서 바뀌지 않았다는 증거).

- [ ] **Step 4: 문서 리뷰 codex 프롬프트에 한 줄**

`run_docreview_codex_reviewer.sh` 의 출력 형식 print 묶음에서 `'(the consequence, not a restatement of the problem).')` 로 끝나는 print 바로 뒤에 한 줄을 넣는다:

```python
print('`summary`, `if_unfixed` and `replacement` are read by a first-time reader at the gate: write them in plain words, '
      'without internal IDs. Keep `evidence` as a verbatim quote of the document.')
```

- [ ] **Step 5: 테스트를 돈다**

Run:
```bash
bash shared/tests/test_docreview_agent_fields.sh | tail -1
bash shared/tests/test_docreview_codex.sh | tail -1
bash shared/tests/test_docreview_agents.sh | tail -1
bash shared/tests/test_docreview_copy_set.sh | tail -1
bash shared/tests/test_no_new_duplication.sh | tail -1
```
Expected: 전부 `Fail: 0`. 에이전트 frontmatter(`tools:`)는 diff 에 없어야 한다 — `git diff shared/docreview/agents plugins/*/agents | grep '^[-+]tools'` 가 빈 출력.

- [ ] **Step 6: 커밋**

```bash
git add shared/docreview/agents/ plugins/spec-distill/agents/doc-critic.md plugins/spec-distill/agents/doc-critic-web.md plugins/spec-distill/agents/doc-recritic.md plugins/quality-gates/agents/doc-recritic.md shared/docreview/scripts/run_docreview_codex_reviewer.sh shared/tests/test_docreview_agent_fields.sh
git commit -m "feat(docreview): 리뷰어가 사람이 읽는 칸을 쉬운 말로 쓰게 한 줄

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 6: `CLAUDE.md` 두 줄 (§7 · AC11)

**Files:**
- Modify: `CLAUDE.md`(`## Git Workflow` 목록 · `## Doc Conventions` 목록)

- [ ] **Step 1: 고친다**

`## Git Workflow` 목록의 `- Commit: Conventional Commits (`<type>(<scope>): <description>`)` 줄 바로 뒤에 넣는다:

```markdown
- 언어: 커밋 메시지의 설명과 PR 본문은 한국어로 쓴다. `type`·`scope` 는 영어다(예: `fix(qg): 범위 경고를 쉬운 말로`). 다른 레포는 그 레포의 규칙을 따른다.
```

`## Doc Conventions` 의 첫 불릿(`- **Korean-primary, English-terms-only.** …`) 바로 뒤에 넣는다:

```markdown
- **범위.** 위의 영어 범위와 「원문 인용에 풀이를 붙이지 않는다」는 **레포 문서**의 규칙이다. 플러그인이 실행 중 사람에게 내는 글은 `shared/style/plain-language.md` 를 따른다.
```

- [ ] **Step 2: 확인한다**

Run:
```bash
grep -c '커밋 메시지의 설명과 PR 본문은 한국어로' CLAUDE.md
grep -c 'shared/style/plain-language.md' CLAUDE.md
bash shared/tests/test_charter_citations.sh | tail -1
```
Expected: `1` · `1` · `Fail: 0`(새 인용 경로가 실재한다).

- [ ] **Step 3: 커밋**

```bash
git add CLAUDE.md
git commit -m "docs: 커밋·PR 은 한국어, 플러그인 실행 중 글은 쉬운 말 규칙을 따른다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 7: 렌더 첫 줄을 설명하는 문서를 새 출력에 맞춘다 (P12)

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의 `## degrade 채널`(Task 3 전 483-492 — 블록 14줄 뒤 497-506)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(Task 3 전 486-487 — 뒤 500-501)
- Modify: `plugins/spec-distill/README.md:99`
- Modify: `shared/docreview/references/reviewing-document.md:42`(라벨 규약 — 「고치면」 줄 이름은 그대로라 확인만)

**Interfaces:**
- 이 Task 는 문서가 렌더 출력의 **사실**을 맞게 말하게 할 뿐이다. 게이트 질문에 무엇을 싣는지(§4)는 PR 2 다.

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다**

`plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh` 의 `finish` 앞에 넣는다:

```bash
# 쉬운 말 출력 PR 1 — 렌더 첫 줄의 내용 설명이 새 출력과 맞는다(옛 「degrade 없음」 이 오는 경우는 없다).
DCH="$(awk '/^## degrade 채널/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
assert_not_contains "$DCH" '둘 다 비면 `degrade 없음` 이 온다' "렌더 첫 줄 설명: 옛 첫 줄 문구를 약속하지 않는다"
assert_contains "$DCH" '「이상 없음」' "렌더 첫 줄 설명: 남은 것도 경고도 없을 때의 첫 줄을 말한다"
assert_contains "$DCH" '「경고 없음」' "렌더 첫 줄 설명: 남은 것은 있고 경고가 없을 때의 첫 줄을 말한다"
```

(`$SKILL` 은 그 파일 25행이 이미 정의한 reviewing-spec SKILL 경로다.)

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh | tail -1` → Expected: Fail 3.

- [ ] **Step 2: 고친다**

reviewing-spec SKILL `## degrade 채널` 의 첫 불릿(Task 3 뒤 497-502, 옛):

```markdown
- `docreview_state.py gate --render` 의 **첫 줄** — 그 라운드의 degrade 한 줄이다. codex 가 없었으면
  그 사실과 사유가, 아니면 `advisory[]` 요약이, 둘 다 비면 `degrade 없음` 이 온다. 이번 라운드가 「미검증」이면
  (요약의 `unverified` — critic 사망 · `finalize` 실패, `fin.json` 이 없는 라운드 포함) 그 공시가, 「미검증」은 아니지만
  리뷰 완료가 아닌 라운드(요약의 `round_reviewed` 거짓 · `unreviewed_reason: unrouted`)면 라우팅 보고서 부재 공시가 맨 앞에 오고
  `degrade 없음` 은 나올 수 없다. 라운드 번호와
  재리뷰 카운트는 **둘째 줄**이다(상한 도달·stagnation 도 그 줄에 붙는다).
```

새:

```markdown
- `docreview_state.py gate --render` 의 **첫 줄** — 그 라운드의 상태와 경고 한 문장이다. 라운드 번호 · 남은 항목 수와
  함께, 경고가 있으면 `경고 N개:` 뒤에 `advisory[]` 를 전부(codex 부재와 사유 포함) 싣는다. 남은 것은 있고 경고가 없으면
  「경고 없음」, 남은 것도 경고도 없으면 「이상 없음」이 온다. 이번 라운드가 「미검증」이면(요약의 `unverified` — critic
  사망 · `finalize` 실패, `fin.json` 이 없는 라운드 포함) 그 공시가, 「미검증」은 아니지만 리뷰 완료가 아닌 라운드(요약의
  `round_reviewed` 거짓 · `unreviewed_reason: unrouted`)면 판정 기록 부재 공시가 맨 앞에 오고 「이상 없음」·「경고 없음」은
  나올 수 없다. 재리뷰 횟수는 **둘째 줄**이다(상한 도달·stagnation 도 그 줄에 붙는다).
```

그 아래 문단(Task 3 뒤 504-506)의 「셋 다 비었을 때만 `degrade 없음` 이다」는 모델이 쓰는 문구라 PR 2 가 고친다 — 이 Task 에서는 건드리지 않는다.

reviewing-brief SKILL 의 그 줄(Task 3 뒤 500-501)의 끝 `` 렌더 첫 줄도 `degrade 없음` 이 아니다. `` 를 `` 렌더 첫 줄도 「이상 없음」·「경고 없음」이 아니다. `` 로 바꾼다.

README:99 의 `` 게이트 첫 줄이 `degrade 없음` 일 수 없고 `` 를 `` 게이트 첫 줄이 「이상 없음」·「경고 없음」일 수 없고 `` 로 바꾼다.

- [ ] **Step 3: spec-distill 문서 스위트를 돈다**

Run:
```bash
for t in test_reviewing_spec_disclosure test_reviewing_brief_skill test_readme_sync test_brief_review_entry test_proceed_gate_adopters; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
```
Expected: 전부 `Fail: 0`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_reviewing_spec_disclosure.sh
git commit -m "docs(spec-distill): 렌더 첫 줄 설명을 새 출력에 맞춘다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 8: 양 측정 도구와 정식 기준선 (Goal 8 · AC12 · Deferred 1)

**Files:**
- Create: `tools/plain-language/measure_output.py` · `tools/plain-language/test_measure_output.py`(조사 시제품을 가져온다)
- Create: `tools/plain-language/README.md`

**Interfaces:**
- Produces: `python3 tools/plain-language/measure_output.py <manifest.tsv>` — stdout 첫 줄은 읽은 파일 수를 말하는 한국어 한 문장, 그다음 JSON(`accounting` · `all` · `devbrew`, 값 다섯 — v1 턴당 글 중앙값·p90, v2 상태 줄로 시작하는 질문, v3 여러 질문을 묶은 호출, v4 영어 위주 최종 보고, v5 ID·해시·코드 토큰이 든 질문). 걸린 시간은 stderr.
- 자리: 리포 전용 판정기 자리인 `tools/`(`tools/adjudication/` 선례). 배포되지 않는다.

- [ ] **Step 1: 시제품을 가져와 해시를 확인한다**

```bash
mkdir -p tools/plain-language
cp ~/.claude/sdd-mirror/plain-language-output/research/research-f/measure_output.py tools/plain-language/
cp ~/.claude/sdd-mirror/plain-language-output/research/research-f/test_measure_output.py tools/plain-language/
shasum -a 256 tools/plain-language/measure_output.py tools/plain-language/test_measure_output.py
```
Expected:
```
f695f22376d1c1803c8236596a59197fd5ef7003a1c3d1beed6439f43a225a5c  tools/plain-language/measure_output.py
78de32b04cfcc125b3458f845e56b68dc0ebc0870b320e961c0788219ade7f8b  tools/plain-language/test_measure_output.py
```
다르면 멈춘다(시제품이 바뀌었다).

- [ ] **Step 2: 시제품 테스트가 GREEN 인지 본다**

Run: `cd tools/plain-language && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v test_measure_output; cd ../..`
Expected: `Ran 5 tests` · `OK`.

- [ ] **Step 3: 새 렌더 첫 줄도 상태 줄로 세는 실패 테스트를 더한다**

PR 1 뒤 게이트 첫 줄은 「리뷰 N라운드를 마쳤다 — …」·「「미검증」 …」 모양이다. 그 줄이 질문 첫 줄로 복사되면 지금처럼 「상태 줄로 시작하는 질문」으로 세야 PR 4 뒤 사후 측정이 같은 것을 잰다. `test_measure_output.py` 의 `QuestionValues` 클래스 안에 테스트를 더한다:

```python
    def test_new_render_first_lines_count_as_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Corpus(tmp)
            c.file("a.jsonl", [
                human("q"),
                asst(auq("리뷰 2라운드를 마쳤다 — 정할 것 1개가 남았다. 경고 없음.\n무엇을 할까?",
                         "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드 — 남은 것 없음.",
                         "- §5 에 TBD 가 남아 있다 — 고치거나 버린다(drop) (9dea7cf3#r1.1)\n이것부터 고칠까?",
                         "이 절을 고칠까?")),
            ])
            all_, _, _ = c.measure()
        self.assertEqual(all_["v2_status_first_line"][:2], [3, 4])
```

(`Corpus(tmp)` · `c.file` · `c.measure()` · `human` · `asst` · `auq` 는 그 파일의 기존 헬퍼다 — `auq(*questions)` 가 AskUserQuestion 도구 블록을 만든다.)

Run: `cd tools/plain-language && python3 -m unittest -v test_measure_output 2>&1 | tail -3; cd ../..` → Expected: 새 테스트 FAIL(`[1, 4] != [3, 4]` — 「미검증」 줄은 이미 패턴에 있다).

- [ ] **Step 4: 패턴 셋을 더한다**

`measure_output.py` 의 `STATUS_RE` 안 `r"|리뷰 완료 아님"` 줄 바로 뒤에 두 줄을 넣는다:

```python
    r"|리뷰 \d+라운드(?:를 마쳤다)? — "
    r"|리뷰를 마치지 못했다 — "
    r"|- .+ \([0-9a-f]{7,}#r\d+\.\d+(?: · 자동)?\)$"
```

셋째 패턴은 새 렌더의 항목 머리(`- <요약> (<id>)`)다 — 옛 `[decide] …` 머리를 상태 줄로 셌으므로 같은 것을 계속 센다. `「미검증」` 은 이미 패턴에 있다. Run 다시 → Expected: `Ran 6 tests` · `OK`.

- [ ] **Step 5: README 를 쓴다**

`tools/plain-language/README.md`:

```markdown
# tools/plain-language

리포 안에서만 도는 쉬운 말 출력 도구 둘이다. 플러그인에 들어가지 않는다.

- `measure_output.py <목록.tsv>` — 고정한 세션 기록 목록(머리 `path\tsize\tmtime`)의 파일만 읽어 사람에게 보이는 글의 양을 다섯 값으로 낸다. 크기나 수정 시각이 목록과 다른 파일은 읽지 않고 따로 센다. 정의는 스크립트 머리에 있다.
- `token_boundary.py --base <커밋>` — 규칙 블록 때문에 skill 앞 5,000토큰 경계 밖으로 새로 밀려난 절을 근사로 잰다.

테스트: `cd tools/plain-language && python3 -m unittest -v test_measure_output`
```

- [ ] **Step 6: 정식 기준선을 낸다(AC12)**

```bash
M=~/.claude/sdd-mirror/plain-language-output/transcript-manifest-2026-10-08.tsv
python3 tools/plain-language/measure_output.py "$M" > ~/.claude/sdd-mirror/plain-language-output/pr1/measure-1.txt
python3 tools/plain-language/measure_output.py "$M" > ~/.claude/sdd-mirror/plain-language-output/pr1/measure-2.txt
cmp ~/.claude/sdd-mirror/plain-language-output/pr1/measure-1.txt ~/.claude/sdd-mirror/plain-language-output/pr1/measure-2.txt && echo IDENTICAL
head -1 ~/.claude/sdd-mirror/plain-language-output/pr1/measure-1.txt
```

Expected: `IDENTICAL`. 첫 줄은 「목록 594개 중 N개를 읽었다. 크기·시각이 바뀐 K개와 사라진 0개는 읽지 않았다.」 모양이다(2026-10-08 조사 때 K=3 — 이 세션을 포함해 이어 쓴 세션 셋). K 와 그 경로는 JSON 의 `accounting.files_changed` 에 있다. 목록 밖 파일이 값을 바꾸지 않는다는 것은 단위 테스트 `test_unlisted_file_does_not_change_values_and_changed_file_is_reported` 가 잰다.

참고값(설계 Verification Plan 3)과의 차이를 PR 본문에 적는다. 조사 시제품의 값(2026-10-08, 591/594 읽음): 턴 302, 턴당 글 중앙값 2,770.5 · p90 28,463, 상태 줄 질문 268/822(32.6%), 묶은 호출 167/440(38.0%, 셀 수 없음 10), 영어 위주 최종 보고 18/302(6.0%), 토큰 든 질문 487/822(59.2%). 참고값과 다른 까닭(같이 적는다): 이 정의의 「턴」은 사람 메시지 사이 전체라 subagent 실행이 한 턴에 들어간다 — 참고값은 사람이 아닌 프롬프트마다 턴을 나눈 것으로 보인다.

- [ ] **Step 7: 커밋**

```bash
git add tools/plain-language/
git commit -m "feat(tools): 사람에게 보이는 글의 양을 고정 목록에서 재는 도구

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 9: 설계 문서의 사실 둘 바로잡기 · 버전 · 최종 검증 · PR

**Files:**
- Modify: `docs/superpowers/specs/2026-10-08-plain-language-output-design.md`(Handoff 의 「13군데」·「B1~B9」, Context 표 머리와 Metadata 의 「776개」 — 설계 표 `e365974e#r2.1` · `64366fc7#r2.1`)
- Modify: 네 `plugins/*/.claude-plugin/plugin.json`(version) · 네 `plugins/*/CHANGELOG.md`

- [ ] **Step 1: 설계 문서의 사실 둘(문서만 — 활성 설계·AC 불변)**

- Handoff TL;DR 의 `프로그램이 글자로 읽는 줄 13군데는` → `프로그램이 글자로 읽는 줄 11군데(§3 표)는`.
- Implicit context (3) 의 `「결정 기록」 B1~B9.` → `「결정 기록」 B1~B10.`
- Context 의 `2026-10-08 에 지난 세션 기록 776개(질문 966개)를 읽었다.` → `2026-10-08 에 지난 세션 기록을 읽었다(조사 에이전트가 센 값으로 776개 · 질문 966개 — 참고값이다. 고정 목록 594개에서는 다시 나오지 않고, 정식 기준선은 PR 1 의 측정 도구가 냈다).`
- Metadata 의 `조사 자료: 2026-10-08 세션 기록 분석(776개 기록),` → `조사 자료: 2026-10-08 세션 기록 분석(참고값 776개 — 정식 기준선은 PR 1),`

- [ ] **Step 2: 버전과 CHANGELOG**

origin/main 의 각 plugin.json version 을 다시 보고(`git show origin/main:plugins/<p>/.claude-plugin/plugin.json | grep version`) 올린다: spec-distill minor, 나머지 셋 patch. 각 CHANGELOG 맨 위 항목 앞에 넣는다(날짜는 커밋하는 날):

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- SKILL.md·명령 파일 맨 앞(H1 바로 다음)에 「사람에게 쓰는 글」 규칙 블록을 둔다. 정본은 리포의 `shared/style/plain-language.md` 이고 `shared/tests/test_plain_language_block.sh` 가 같음을 잰다.
```

spec-distill 에는 한 줄을 더한다:

```markdown
- 문서 리뷰 게이트 렌더가 쉬운 말이다: 첫 줄은 상태와 경고를 한 문장으로 말하고, 0 인 집계는 빼며, 항목은 쉬운 말로 시작하고 id 는 끝 괄호에 둔다. 경고는 전부 첫 줄에 싣는다(전에는 codex 부재만 싣고 나머지를 버렸다). 기계가 읽는 `gate` JSON 은 그대로다.
- 문서 리뷰어(`doc-critic` · `doc-critic-web` · `doc-recritic`)가 사람이 읽는 칸을 쉬운 말로 쓴다.
```

quality-gates 에는 한 줄을 더한다(`doc-recritic` 사본과 심볼릭 링크된 엔진이 바뀌었다):

```markdown
- 문서 재비판자(`doc-recritic`)가 사람이 읽는 칸을 쉬운 말로 쓴다.
```

- [ ] **Step 3: 최종 스위트와 대조**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr1/final
comm -13 ~/.claude/sdd-mirror/plain-language-output/pr1/baseline/failures.txt ~/.claude/sdd-mirror/plain-language-output/pr1/final/failures.txt
```

Expected: 마지막 명령이 빈 출력(새 실패 0 — AC13). 단 선재 RED `harness/test_skill_orchestration_behavior.sh` 의 「iter cap near Review gate AskUserQuestion (lines N, M distance 496 > 160)」 줄은 quality-pipeline SKILL 에 블록 14줄이 들어가 N·M 이 +14 된다(701, 205 → 715, 219). 거리가 496 그대로면 새 실패가 아니다 — 그 한 줄은 PR 본문에 적고 넘어간다. 줄이 나오면 그 테스트를 단독으로 다시 돌린다(동시 실행 오탐 확인). 그래도 RED 면 고치고 이 Step 을 다시 한다.

- [ ] **Step 4: 문구 고정 테스트 전수 확인(Deferred 2)**

이 PR 이 없앤 옛 문구가 리포 어디에도 단언으로 남지 않았는지 본다(숨김 디렉토리 포함 — 셸 grep 함수 대신 `/usr/bin/grep`):

```bash
for lit in 'degrade 없음' '[미적용 fix]' '[decide auto]' '순서: 열린 결정' '진행 옵션 활성' '미소비 상향 예약' '주 판정자(doc-critic) 사망' '라우팅(finalize) 미완' '리뷰 완료 아님' '끝에서 한 목록으로' 'drop 하면 이 차단이 풀린다'; do
  printf '== %s\n' "$lit"
  /usr/bin/grep -rnF --include='*.sh' --include='*.py' --include='*.txt' -- "$lit" shared/tests plugins/*/tests tools 2>/dev/null | grep -v '/golden/' | head -5
done
```

남는 것이 **단언**이면(주석·옛 사실의 기록이 아니면) 그 단언을 새 문구로 고친다. 단언이 아니라 그대로 두는 것: 케이스 메시지 속 옛 사정 설명(예: 「리뷰 완료 아님」·「진행 옵션 활성」을 말하는 리뷰 이력), `cases.sh` 의 Ruling 24 주석(「미소비 상향 예약」), `test_docreview_mutations.sh` 의 셀 주석, 새 변이 셀 `fix_id_moved_front` 의 sed 안 `[미적용 fix]`(의도한 옛 모양), `tools/plain-language/measure_output.py` 의 `STATUS_RE`(옛 기록을 세는 패턴). `degrade 없음` 은 PR 2 가 다루는 모델 문구 락(`test_brief_review_entry.sh:275` · `test_reviewing_brief_skill.sh`)에 남는 것이 정상이다 — 그 둘은 렌더가 아니라 모델이 쓰는 문구를 잰다.

- [ ] **Step 5: 커밋**

```bash
git add docs/superpowers/specs/2026-10-08-plain-language-output-design.md plugins/*/.claude-plugin/plugin.json plugins/*/CHANGELOG.md
git commit -m "chore: 네 플러그인 버전 올림과 설계 문서의 사실 둘 바로잡기

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: /qg 로 리뷰한다(Verification Plan 5)**

`/qg branch` 를 돌린다. 리뷰어에게 명시해 묻는다: 「문구를 고정한 테스트의 뜻이 유지됐는가 — 특히 I4 위조 방지 단언이 새 항목 머리 모양으로 옮겨졌는가, 부재 단언(「degrade 없음」 이 없다)이 새 문구로 바뀌어 공허해지지 않았는가」. `plan-mandated` 라벨: Task 2 · 4 의 테스트 코드는 계획이 쓴 것이다 — 리뷰어에게 그 사실을 실어 더 엄격히 보게 한다.

- [ ] **Step 7: PR 을 낸다**

push 후 PR 본문(한국어)에 넣는다:
- 첫 줄: 이 PR 이 무엇을 바꿨는지 한 문장.
- 「계획이 정한 것」 표의 P1~P13 중 이 PR 에 해당하는 것(P1~P12).
- 블록 근사 토큰 수와 경계 표(Task 3 Step 6 의 두 파일 요약 — 새로 밀린 절, P4 처리).
- 문구 고정 테스트 표(Task 4 Step 4 의 표 — 옛 → 새 · 지키는 뜻).
- 양 측정 정식 기준선 다섯 값과 집계 정의, 참고값과의 차이(Task 8 Step 6).
- 변이 결과 요약(블록 9 · 렌더 5).
- 할 일 하나: 「이 PR 을 머지한 뒤 아무 devbrew skill 하나를 돌려 보고 진행 설명이 줄었는지 봐 주세요」.
- 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge` 로 한다. 머지 뒤 이 브랜치에서 `git fetch origin main && git merge --no-edit origin/main` 으로 받고 PR 2 계획의 Task 0 으로 간다.
