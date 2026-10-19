# R2a 계획 4 — project-init · plugin-audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** project-init 이 기계 대신 정하던 중단(헌장 재질문 3회 · AGENTS.md 이전 거절)을 사용자가 고르는 선택지로 바꾸고, 질문 수 · 관례 수 · 브랜치 접두 · 브랜치 확인 · worktree 길을 기본값 + 공시 + 사용자가 여는 길로 고치며, plugin-audit 의 숨김(약한 지적 버림 · 「불확실하면 기각」 · 코퍼스 제외 수)을 공시로 바꾸고 비용 상한(6축 고정 · 심층검증 8건)을 없앤다.

**Architecture:** project-init 은 모델이 따르는 산문(`SKILL.md`)과 템플릿이라, 동작은 산문 계약 락(`tests/test_command_contract.py`)과 템플릿을 실제 훅 함수로 돌려 보는 테스트(`tests/test_branch_prefix_templates.py`)로 잰다. 브랜치 접두의 정본은 템플릿 `regex` 펜스 하나이고, 훅의 `derive_prefixes` 가 그것을 읽는 같은 규칙이다. plugin-audit 은 Workflow 스크립트(`audit-workflow.js`)가 `args.axes` 로 고른 축만 돌리고 심층검증을 상한 없이 돌리며, 반박자의 새 판정 `uncertain` 을 기각과 나눠 싣는다. 리포트 렌더러가 「목록에서 뺀 지적」 부록 · 수집에서 뺀 수 · 고른 축을 공시한다.

**Tech Stack:** Python 3.9.6(표준 라이브러리) · Node 25(`node --test`, Workflow 하네스 `tests/_wf_harness.mjs`) · bash 3.2 호환 셸 · 레포 셸 테스트 하네스(`shared/tests/assert.sh`).

**Spec:** `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` (§1 의 계획 4 행 · §5 · AC31~AC35 · 공통 AC36 · AC37). 최신 문면은 계획 2 브랜치(`feature/shared-review-engine-core`)에 있다 — 실행자는 `git show feature/shared-review-engine-core:docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` 로 읽는다.

## Global Constraints

- 브랜치는 `feature/shared-review-engine-plugins`(origin 기본 브랜치에서 분기). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec 으로(`git commit -m … -- <경로…>`). push · stash 금지 — 지휘자가 한다. 로드맵 R2a 블록 `브랜치:` 칸 등록은 지휘자가 로드맵 PR 로 한다(설계 §10).
- 커밋 메시지: Conventional Commits, `type(scope)` 영어 · 설명과 본문 한국어. 끝에 `Co-Authored-By` · `Claude-Session` 두 줄(세션이 주는 값 그대로).
- 고칠 수 있는 경로는 로드맵 R2a 경로 예약 안의 `plugins/project-init/` · `plugins/plugin-audit/` 와 이 계획 파일뿐이다. `.claude-plugin/marketplace.json` · 설계문서 · `shared/` 는 고치지 않는다(설계문서는 계획 2 브랜치가 고치는 중이다 — 새로 찾은 장치 행은 인계로 지휘자에게 넘긴다).
- 플러그인 버전: 둘 다 minor(새 선택지 · 새 인자 · 새 판정 값 — 새 표면). 지금 버전에서 도출한 임시 번호 **project-init 5.0.3 → 5.1.0 · plugin-audit 1.1.3 → 1.2.0** 을 쓰고 인계에 「번호는 머지 직전에 다시 확인」을 적는다. 겹침: 지휘자 수리 브랜치 `fix/conductor-superpowers7` 가 두 플러그인을 5.0.4 · 1.1.4 로 patch bump 하고 두 `SKILL.md` 의 쉬운 말 블록 한 줄을 고친다. R11(`feature/principles-docs-cleanup`)은 README · CHANGELOG 의 낡은 개념 줄을 고치고 patch bump 한다. 먼저 머지되는 쪽이 번호를 갖는다.
- README 는 이 계획이 바꾸는 동작을 설명하는 줄만 고친다(설계 Non-goals · `## 미룸` R11 행). 낡은 개념 줄은 R11 몫이라 건드리지 않는다.
- 두 `SKILL.md` 의 `<!-- plain-language:begin -->` ~ `end` 블록은 고치지 않는다(정본 사본 락 + 지휘자 수리 브랜치와의 겹침). plugin-audit `SKILL.md` 의 `<!-- codex-gate:begin … -->` ~ `end` 블록도 고치지 않는다(qg 의 `test_codex_gate_observation.sh` 가 잘라 실행한다).
- **persona 편집은 따로 보안 리뷰를 거친다** — `plugins/plugin-audit/agents/plugin-auditor.md` · `agents/audit-refuter.md` 와 리뷰어 지시 문면(`scripts/audit-workflow.js` 의 `refutePrompt` · 심층검증 렌즈 프롬프트). 편집 diff 를 qg 보안 리뷰어(`quality-gates:security-reviewer`, 웹 도구 없음)에 한 번 따로 돌리고 결과와 판단 근거를 PR 본문 「보안 리뷰」 절에 적는다(Task 7, AC34 · D2.7). agent `tools:` allowlist 는 바꾸지 않는다.
- 레포 전용 값을 박지 않는다 — 템플릿의 접두는 고른 전략에서 도출하고, 테스트는 `tempfile` / `mktemp -d` 안에서만 쓴다. 테스트의 레포 루트는 파일 위치에서 도출한다.
- 새 셸 테스트는 실행 비트 100755. 스크립트의 파일 읽기는 `encoding="utf-8"` 명시. 플러그인 `.py` 에 `"python3"` 리터럴을 박지 않는다. 인라인 python 은 `python3 -I`(스크립트 파일 호출에는 `-I` 금지). 긴 한글 줄은 인접 문자열로 나눈다. 3.10 이상 문법을 쓰지 않는다.
- skill 본문(`SKILL.md`)에 `$1` · `$2` 같은 위치 토큰을 쓰지 않는다(Skill 인자로 치환된다).
- 사용자에게 보이는 새 문면(선택지 · 공시 줄 · 리포트 · README · CHANGELOG)은 `shared/style/plain-language.md`: 첫 줄 상태, 번호 · 필드 이름은 괄호 안, 질문 하나에 결정 하나, 추천은 「(권장)」. `AskUserQuestion` 은 질문마다 선택지 2~4개, 한 번에 질문 1~4개다.
- 템플릿 셋에 같은 새 문단을 넣을 때 20줄 이상 똑같은 구간을 만들지 않는다(`shared/tests/test_no_new_duplication.sh`) — 전략마다 기준 브랜치가 달라 문단이 갈린다.
- `scripts/audit-workflow.js` 에 `n: <숫자>,` 꼴 줄을 새로 만들지 않는다(`tests/test_axis3_reachability_question.sh` 가 그 줄 수로 축 목록 크기 6 을 잰다).
- `TMPDIR` 은 `$HOME/.claude/sdd-mirror/r2a-plan4/tmp` 를 쓴다. 공유 임시 폴더를 glob 으로 지우지 않는다.

## 설계에 없던 결정

설계가 정하지 않았거나 레포 사실과 부딪혀 이 계획이 정한 것이다. 실행 전에 사용자 확인을 받는다. 각 항목의 「계획의 선택」대로 Task 가 쓰여 있다.

1. **새로 찾은 장치 — git 규칙 교체 거절이 실행 전체를 멈춘다.** `project-init/SKILL.md:56-59` 「기존 git workflow 룰이 감지됐습니다. 새 템플릿으로 교체할까요? … 사용자가 거절하면 중단」은 git 규칙만 거절해도 헌장 단계까지 멈춘다 — AGENTS.md 이전 거절(§1 행)과 같은 꼴(기계가 정한 전체 중단)이다. 설계 Goals 끝 줄 · D15 에 따라 같은 기준(D18 — 사용자 결정을 덮는 것은 제거)을 적용한다. 계획의 선택: 선택지 셋 「교체 (권장)」 · 「git 규칙은 그대로 두고 헌장만」 · 「중단」(Task 2 Step 3). 다른 길: 넣지 않는다 — 이 Step 을 건너뛰고 지금처럼 거절이면 멈춘다. 어느 쪽이든 지휘자가 설계 §1 에 행을 더하거나(넣음) 「장치 아님 — 사용자 통제」 유지 목록에 더한다(안 넣음).
2. **헌장 「건너뛰기」의 뜻.** 계획의 선택: 헌장 단계 전체를 건너뛴다(헌장 파일 · 절을 쓰지 않음), git 규칙 파일은 계속 만들고, 미완 항목을 그 자리와 끝 보고에 공시한다. 다른 길: 그 항목만 비운 채 헌장을 쓴다 — 그러나 헌장 완성 판정(`charter_section_complete`)은 빈칸 표시 `_명시되지 않음 — 추후 보강._` 를 채워진 값으로 읽어 다음 실행이 다시 묻지 않는다.
3. **「더 묻기」가 묻는 것.** 계획의 선택: 관례를 더 받고, 지금 기본값으로 비는 헌장 칸 셋(목표 · 성공 기준 · 사용자)을 묻는다 — 답이 그 칸의 값이 된다(`{{GOALS}}` · `{{SUCCESS_CRITERIA}}` · `{{PERSONAS}}`). 「더 묻기」 뒤에는 다시 공시하고 다시 묻는다(사용자가 「이대로 진행」을 고를 때까지). 관례는 3개를 넘게 받아도 자르지 않는다.
4. **AGENTS.md 가 이미 있는데 CLAUDE.md 가 다를 때(S4)의 거절.** 「CLAUDE.md 에 바로 쓰기」는 AGENTS.md 가 없을 때(S2)만 뜻이 있다. 계획의 선택: S4 는 「옮기기 (권장)」 · 「CLAUDE.md 는 그대로 두기」(AGENTS.md 의 관리 절만 갱신 — CLAUDE.md 는 손대지 않음) · 「중단」. S2 는 「AGENTS.md 로 옮기기 (권장)」 · 「CLAUDE.md 에 바로 쓰기」 · 「중단」.
5. **「CLAUDE.md 에 바로 쓰기」를 고른 실행의 헌장 판정 파일.** 헌장 상태 판정 (a)·(b) 는 지금 `AGENTS.md` 만 본다(`SKILL.md:71-72`). 계획의 선택: 관리 절을 담는 파일(정본 파일)을 읽는다 — AGENTS.md, 또는 「CLAUDE.md 에 바로 쓰기」를 고른 실행에서는 CLAUDE.md.
6. **worktree 로 만든 브랜치는 훅이 확인하지 않는다.** 훅의 `BRANCH_CREATE_RE`(`post-tool-use.py:38`)는 `git checkout -b` · `git switch -c` 만 본다. 계획의 선택: 템플릿의 worktree 문단이 같은 이름 규칙을 적되 「훅은 `git worktree add -b` 로 만든 이름은 확인하지 않는다」를 밝힌다 — 훅은 고치지 않는다(설계 Files to Modify 밖). 다른 길: 훅이 `git worktree add … -b <이름>` 도 확인하게 한다(정규식 한 갈래 + 테스트 — 훅 · README 「Hooks Installed」가 바뀐다).
7. **사용자가 더하는 브랜치 접두의 문법.** 계획의 선택: 훅의 `derive_prefixes` 가 읽을 수 있는 낱말만 받는다 — 소문자로 시작하고 소문자 · 숫자 · `-` 만(`[a-z][a-z0-9-]*`), 중복 없이. 밖이면 이유를 보이고 다시 묻는다. 템플릿 placeholder 는 셋 — `{{BRANCH_PREFIXES}}`(정규식 갈래, 예 `feature|fix|docs`) · `{{BRANCH_PREFIX_LIST}}`(산문, 예 `` `feature/*` · `fix/*` · `docs/*` ``) · `{{EXTRA_PREFIX_LIST}}`(더한 것만, 없으면 「없음」).
8. **반박자의 「불확실」 판정 꼴.** 계획의 선택: 반박 스키마 판정 값에 `uncertain` 을 더한다. 불확실한 지적은 기각처럼 목록에서 빠지되(`status: refuted`, `refutation.uncertain: true`) 리포트 부록에 따로 나온다. 심층검증 렌즈도 같은 장치(「확신이 없으면 refute하라」, `audit-workflow.js:665`)라 투표에 `uncertain` 을 더하고, 지적을 죽인 투표가 모두 불확실이면 그 지적을 불확실로 싣는다.
9. **리포트에 반박 부록이 지금 없다.** 반박자 persona 는 「the orchestrator writes it into the report's rejected-findings appendix」(`audit-refuter.md:36-38`)라고 하지만 렌더러(`render-audit-report.py`)는 기각된 지적을 하나도 그리지 않는다. 계획의 선택: 「목록에서 뺀 지적」 절을 새로 그리고 기각 · 불확실 · 같은 지적에 흡수 셋으로 나눈다(설계의 「부록에서 기각과 「불확실」을 나눠 표시」가 기대는 부록을 만든다).
10. **「뺀 수」를 세는 자리.** 설계는 자리를 `audit-workflow.js:239` 로 적었지만 그 줄은 제외를 알리는 문장일 뿐이고 실제 제외는 `scripts/check-staleness.py` 가 한다. 계획의 선택: `check-staleness.py` 가 뺀 수를 `excluded` 로 내고(코드 펜스 안 줄 수 · 자리표시자·URL 로 뺀 후보 수 · 생성 대상 경로로 뺀 후보 수), evidence pack · `meta.json` 을 거쳐 감사자 프롬프트와 리포트에 싣는다. 설계 Files to Modify 에 없는 `check-staleness.py` · `assemble-audit-data.py` · `validate-audit-data.py` 를 고친다(같은 플러그인 안).
11. **축 고르기 질문 꼴.** `AskUserQuestion` 은 질문마다 선택지 4개까지라 여섯 축을 한 질문에 못 싣는다. 계획의 선택: 먼저 「여섯 축 전부 (권장)」 · 「축 골라서」를 묻고, 골라서면 한 번의 호출에 다중 선택 질문 둘(축 1~3 · 축 4~6)을 싣는다. 하나도 안 고르면 「다시 고르기」 · 「중단」을 묻는다. 축 목록(여섯 축의 질문)은 그대로 두고 고르기만 연다 — 사용자가 새 축을 만드는 길은 두지 않는다.
12. **심층검증 수는 동의 때 알 수 없다.** 반박을 통과한 심각 · 중요 지적 수는 감사 뒤에야 정해지고, Workflow 는 중간에 사용자에게 묻지 못한다. 계획의 선택: 동의 게이트는 규칙(「반박을 통과한 심각 · 중요 지적마다 2회 — 상한 없음」)을 알리고, Workflow 가 심층검증을 시작하기 직전에 실제 수를 실행 기록(`log`)에 찍는다. 다른 길: Workflow 를 둘로 나눠 심층검증 전에 다시 묻는다 — 오케스트레이션이 한 단계 늘고 재개 상태가 생긴다.
13. **축 6(보안)을 빼면 축 2 가 기다리던 판정이 없다.** 축 2 의 스틸맨 조건 (c) 는 축 6 판정을 기다리는 `pending` 을 쓰고, 검증기는 남은 `pending` 을 RED 로 본다(`validate-audit-data.py:81-84`). 계획의 선택: 축 6 을 고르지 않은 실행에서는 축 2 스키마의 `steelman_condition` 선택지에서 `pending` 을 빼고, 축 2 프롬프트에 「축⑥은 이번 감사에서 돌지 않는다 — (c) 를 직접 판정하거나 `none`」을 싣는다.
14. **plugin.json 설명의 「six read-only reviewers」는 그대로 둔다.** 기본이 여섯이고, 설명을 바꾸면 `marketplace.json` 도 같이 바꿔야 하는데(`shared/tests/test_plugin_description_parity.sh`) 그 파일은 R2a 경로 예약 밖이다. README 첫 줄에서 고르기를 밝힌다.

참고(`### Deferred to plan`) 가운데 이 계획이 닿는 것: 5c83a7eb(계획 4 본문의 옛 「상한을 늘린다」 — 이 계획은 처분표와 AC35 를 따른다: 축 고정 · 8건 상한 제거) · 17563e51(질문 수는 비용 장치가 아니라 질문 피로 방지 기본값 — Task 1 은 공시 + 더 묻기로 고친다). 나머지는 계획 2 · 3 몫이다. 설계 `## 미룸` 에서 받는 곳이 「계획 4」인 행은 없다.

## Review Focus

1. **사용자가 축 6(보안)을 빼고 감사한다.** 사람은 리포트 머리에서 고르지 않은 축을 보고, 검증기가 축 2 의 남은 `pending` 때문에 RED 를 내지 않기를 기대한다. Task 6 `axes without 6 — axis 2 schema drops pending` 과 render `test_unchosen_axes_banner` 가 잠근다.
2. **축 선택 값이 잘못 왔다(`0` · `7` · `"3"` · 중복 · 빈 목록).** 사람은 감사자 하나도 부르기 전에 이유와 함께 멈추기를 기대한다(일부만 도는 감사가 아니라). Task 6 `bad axes throw before any dispatch` 가 잠근다.
3. **반박자가 범위 밖(게이트 E)이라 확신하지 못해 `uncertain` 을 낸다.** 사람은 그 지적이 부록 「불확실」에도, 열린 질문(범위 밖)에도 보이고 검증기가 GREEN 이기를 기대한다. Task 4 `test_uncertain_gate_e_goes_to_noq_and_appendix` 가 잠근다.
4. **사용자가 더한 브랜치 접두가 훅이 못 읽는 꼴이다(`Docs` · `docs/x` · `1fix`).** 사람은 다시 묻기를 기대한다 — 그대로 박히면 훅이 접두 목록을 못 읽어 고침 명령 대신 문서 안내로 떨어진다. Task 3 `test_skill_prefix_rule_matches_hook` 가 SKILL 의 낱말 규칙과 훅의 실제 판독을 같은 표본으로 대조한다.
5. **헌장에서 「건너뛰기」를 고르고 나중에 다시 실행한다.** 사람은 다음 실행이 헌장 질문을 다시 묻기를 기대한다(건너뛴 것이 채워진 것으로 읽히면 안 된다). Task 1 `test_skip_writes_no_charter` 가 건너뛰기 갈래가 헌장 절 · 파일을 쓰지 않는다는 문면과 4e 의 건너뜀 조건을 잠근다.

---

### Task 0: 기준선 스위트를 잰다

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r2a-plan4/baseline.sh` · `$HOME/.claude/sdd-mirror/r2a-plan4/baseline-ext.sh` · `$HOME/.claude/sdd-mirror/r2a-plan4/baseline-node.sh` (레포 밖)

- [ ] **Step 1: 기준 스크립트를 쓴다**

`baseline.sh` · `baseline-ext.sh` 는 `$HOME/.claude/sdd-mirror/r2a-plan1/` 의 같은 이름 파일을 그대로 복사한다(전체 플러그인 · `shared/tests` · 하위 폴더 · `tools/` — qg 테스트가 plugin-audit `SKILL.md` 블록을 잘라 실행하므로 전체를 잰다). `baseline-node.sh`:

```bash
#!/usr/bin/env bash
# plugin-audit 의 node 테스트를 tap 리포터로 돌려 실패 이름을 남긴다. 리포 루트에서: bash baseline-node.sh <출력 접두>
set -u
out="$1"; : > "$out.tsv"; : > "$out.names"
for t in plugins/*/tests/*.test.mjs; do
  log="$(node --test --test-reporter=tap "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out.tsv"
  printf '%s\n' "$log" | grep -E '^not ok' | awk -v t="$t" '{print t "\t" $0}' >> "$out.names"
done
echo "node_done"
```

- [ ] **Step 2: 기준을 잰다(백그라운드 · 다른 스위트와 동시에 돌리지 않는다)**

Run (리포 루트에서): `M="$HOME/.claude/sdd-mirror/r2a-plan4"; bash "$M/baseline.sh" "$M/before"; bash "$M/baseline-ext.sh" "$M/before-ext"; bash "$M/baseline-node.sh" "$M/before-node"`
Expected: 세 `.tsv` 에 테스트마다 한 줄, `.names` 에 실패 줄. 비교는 rc 가 아니라 실패 «이름» 집합으로 한다. `git rev-parse HEAD` 를 `$M/before.head` 에 적는다.

---

### Task 1: 헌장 재질문 뒤 선택 · 질문 수 공시와 더 묻기 · Phase 0 겹침 (AC31)

**Files:**
- Modify: `plugins/project-init/skills/project-init/SKILL.md` (Step 3.5 머리 `:119` · Phase 1 `:147-156` · Law 1 게이트 `:158-164` · 4e 첫 문단 `:215` · Step 5 보고 `:250-266`)
- Test: `plugins/project-init/tests/test_command_contract.py` (새 클래스 셋)

**Interfaces:**
- Produces: 끝 보고 인용 블록의 조건 줄 `> 헌장을 건너뛰었다면: …` (Task 2 가 같은 블록에 「CLAUDE.md 에 바로 썼다면」 줄을 더한다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_command_contract.py` 에 더한다(기존 `section()` 헬퍼를 쓴다):

```python
class TestCharterGateChoice(unittest.TestCase):
    """AC31 — 재질문 3회 뒤 기계가 멈추지 않고 사용자가 고른다."""

    def setUp(self):
        self.text = COMMAND.read_text(encoding="utf-8")
        self.gate = section(self.text, "#### Law 1 구조적 게이트", "### Step 4:")

    def test_three_choices_after_three_asks(self):
        for label in ("「건너뛰기」", "「계속 묻기」", "「중단」"):
            self.assertIn(label, self.gate)
        self.assertIn("최대 3회", self.gate)

    def test_machine_abort_is_gone(self):
        self.assertTrue(self.gate.strip(), "게이트 절이 비었다 — 부재 단언이 공허하다")
        self.assertNotIn("abort한다", self.gate)
        self.assertNotIn("charter 미완료: <항목> 비어 abort", self.gate)

    def test_skip_discloses_incomplete_items(self):
        self.assertIn("[project-init] 헌장 단계를 건너뛰었다 — 미완 항목: <항목>", self.gate)

    def test_skip_writes_no_charter(self):
        self.assertIn("헌장 절과 `docs/project/` 파일을 쓰지 않는다", self.gate)
        step4e = section(self.text, "#### 4e:", "### Step 5:")
        self.assertIn("헌장 단계를 건너뛰지 않았다면", step4e)
        self.assertNotIn("abort(Law 1 게이트 실패)", step4e)


class TestQuestionDefaultsDisclosed(unittest.TestCase):
    """AC31 — 질문 4개 · 관례 1–3개는 기본값, 쓴 수를 공시하고 「더 묻기」로 연다."""

    def setUp(self):
        text = COMMAND.read_text(encoding="utf-8")
        self.phase1 = section(text, "#### Phase 1", "#### Law 1 구조적 게이트")

    def test_no_hard_cap_wording(self):
        self.assertTrue(self.phase1.strip())
        self.assertNotIn("≤4개", self.phase1)
        self.assertNotIn("4개만 묻는다", self.phase1)

    def test_disclosure_line_and_more_option(self):
        self.assertIn("헌장 질문 <n>개를 물었고(기본 4개) 관례 <m>개를 받았다(기본 1–3개)", self.phase1)
        self.assertIn("「이대로 진행 (권장)」", self.phase1)
        self.assertIn("「더 묻기」", self.phase1)
        for slot in ("{{GOALS}}", "{{SUCCESS_CRITERIA}}", "{{PERSONAS}}"):
            self.assertIn(slot, self.phase1)


class TestPhase0MayOverlap(unittest.TestCase):
    """AC31 — 질문 순서는 기본 직렬, 질문 없는 Phase 0 스캔은 겹쳐 돌 수 있다."""

    def test_serial_default_and_scan_overlap(self):
        text = COMMAND.read_text(encoding="utf-8")
        head = section(text, "### Step 3.5:", "#### Phase 0")
        self.assertIn("기본은 직렬", head)
        self.assertIn("Phase 0 스캔은 질문이 없으므로", head)
        self.assertNotIn("*모두 끝난 뒤* 시작한다", head)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_command_contract 2>&1 | tail -3`
Expected: FAIL — 새 클래스 단언들(`「건너뛰기」` 없음 등).

- [ ] **Step 3: `SKILL.md` 를 고친다**

- Step 3.5 머리(`:119`): 「**질문 순서**: 기본은 직렬이다 — Step 3(release 브랜치 질문 포함)의 질문이 모두 끝난 뒤 헌장 질문을 시작하고, git 질문과 헌장 질문을 교차하지 않는다(답이 엉키지 않게). Phase 0 스캔은 질문이 없으므로 Step 2 · 3 질문과 겹쳐 돌려도 된다 — 예: Step 2 질문을 띄우기 전에 스캔을 시작한다. 헌장 질문 수는 git 질문 수와 따로 센다.」
- Phase 1 제목을 「Phase 1 — 판단 질문 (AskUserQuestion, 기본 4개)」로, 첫 문장을 「다음 4개를 묻는다(기본값 — 아래 「더 묻기」로 더 연다)」로. ③ 관례 질문 문구는 「지켜야 할 핵심 코딩/구조 컨벤션은? (보통 1–3개, 더 적어도 된다)」 — 받은 관례는 개수와 상관없이 모두 쓴다(자르지 않는다).
- 4개 질문 뒤 새 문단 「쓴 수 공시와 더 묻기」: 공시 줄 `[project-init] 헌장 질문 <n>개를 물었고(기본 4개) 관례 <m>개를 받았다(기본 1–3개).` 을 내고 `AskUserQuestion` 한 번 — 「이대로 진행 (권장)」 · 「더 묻기」. 「더 묻기」면 `AskUserQuestion` 한 번에 질문을 최대 넷 — 관례 더 · 목표(`{{GOALS}}`) · 성공 기준(`{{SUCCESS_CRITERIA}}`) · 사용자(`{{PERSONAS}}`) — 묻고, 답한 칸은 4e 의 기본값(파생 · `_명시되지 않음 — 추후 보강._`) 대신 그 답을 쓴다. 그 뒤 공시 줄을 새 수로 다시 내고 같은 선택을 다시 묻는다.
- Law 1 게이트(`:158-164`): 재질문 「최대 3회」는 그대로. 3회 뒤에도 비면 `AskUserQuestion` — 「건너뛰기」(헌장 단계를 건너뛴다 — 헌장 절과 `docs/project/` 파일을 쓰지 않는다, git 규칙 파일은 그대로 만든다) · 「계속 묻기」(그 항목을 다시 최대 3회 묻고, 그래도 비면 이 선택을 다시 묻는다) · 「중단」(실행 전체를 멈춘다 — Step 4 전이라 아무 파일도 쓰지 않았다). 「건너뛰기」를 고르면 `[project-init] 헌장 단계를 건너뛰었다 — 미완 항목: <항목>. git 규칙 파일은 그대로 만든다. 헌장을 채우려면 /project-init:project-init 을 다시 실행하세요.` 을 낸다. 「중단」이면 `[project-init] 사용자가 중단을 골랐다 — 아무 파일도 쓰지 않았다.` 를 내고 멈춘다. 옛 abort 줄과 「abort 후에도 …」 문장을 이 셋으로 바꾼다. C-S2 면제 문장은 그대로.
- 4e 첫 문장(`:215`): 「charter step이 abort(Law 1 게이트 실패)되지 않았다면」 → 「헌장 단계를 건너뛰지 않았다면(Law 1 게이트에서 「건너뛰기」를 고르지 않았고 C-S2 갱신을 거절하지 않았다면)」.
- Step 5 보고 블록: 마지막 줄(「다음 할 일: …」) 바로 앞에 조건 줄 하나 — `> 헌장을 건너뛰었다면: 미완 항목 <항목> — 헌장 파일은 만들지 않았다.` 첫 줄 · 마지막 줄은 바꾸지 않는다(`test_plain_init_text.py`). 이 줄에 「hook」 · 「훅」 · 「검증」을 쓰지 않는다(`TestCompletionReportPromisesOnlyWhatShips` 축 D).

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_command_contract test_plain_init_text 2>&1 | tail -3`
Expected: `OK`(옛 `TestMigrationPromptStillGated` 는 아직 그대로라 GREEN — Task 2 가 바꾼다).

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "feat(project-init): 헌장 재질문 뒤 사용자가 고른다 — 건너뛰기 · 계속 묻기 · 중단, 질문 수 공시와 더 묻기" -- plugins/project-init/skills/project-init/SKILL.md plugins/project-init/tests/test_command_contract.py
```

---

### Task 2: AGENTS.md 이전 거절 · git 규칙 교체 거절이 실행 전체를 멈추지 않는다 (AC32)

**Files:**
- Modify: `plugins/project-init/skills/project-init/SKILL.md` (Step 1 `:56-65` · 헌장 상태 감지 `:69-73` · 4c S2 행 `:199` · S4 행 `:201` · Step 5 보고)
- Test: `plugins/project-init/tests/test_command_contract.py` (`TestMigrationPromptStillGated` 를 `TestMigrationRefusalChoices` 로 바꾼다)

**Interfaces:**
- Consumes: Task 1 의 Step 5 조건 줄 자리(마지막 줄 바로 앞).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`TestMigrationPromptStillGated` 를 지우고 다음으로 바꾼다:

```python
class TestMigrationRefusalChoices(unittest.TestCase):
    """AC32 — 이전 거절이 실행 전체를 멈추지 않는다(옛 AC21 「부분 진행 금지」 폐지)."""

    def setUp(self):
        self.text = COMMAND.read_text(encoding="utf-8")
        self.step1 = section(self.text, "### Step 1:", "### Step 2:")
        self.matrix = section(self.text, "#### 4c:", "#### 4d:")

    def test_s2_offers_three_choices(self):
        for label in ("「AGENTS.md 로 옮기기 (권장)」", "「CLAUDE.md 에 바로 쓰기」", "「중단」"):
            self.assertIn(label, self.step1)

    def test_git_workflow_files_continue(self):
        self.assertIn("`docs/git-workflow/` 파일은 그대로 만든다", self.step1)

    def test_old_whole_run_abort_is_gone(self):
        self.assertTrue(self.step1.strip())
        self.assertNotIn("부분 진행 금지", self.step1)
        self.assertNotRegex(self.step1, r"사용자 거절 시.*전체 `/project-init:project-init` 실행 abort")
        s2 = self.matrix[self.matrix.index("**S2 (CLAUDE-only legacy)**"):self.matrix.index("**S3 (")]
        self.assertNotIn("거절 시 전체", s2)
        self.assertIn("「CLAUDE.md 에 바로 쓰기」", s2)

    def test_s4_offers_keep_claude_md(self):
        s4 = self.matrix[self.matrix.index("**S4 ("):]
        for label in ("「옮기기 (권장)」", "「CLAUDE.md 는 그대로 두기」", "「중단」"):
            self.assertIn(label, s4)

    def test_charter_detection_reads_the_canonical_file(self):
        detect = section(self.text, "#### Charter 상태 감지", "### Step 2:")
        self.assertIn("「CLAUDE.md 에 바로 쓰기」를 고른 실행에서는 CLAUDE.md", detect)


class TestGitWorkflowReplaceRefusal(unittest.TestCase):
    """설계에 없던 결정 1 — git 규칙 교체 거절이 헌장까지 멈추지 않는다."""

    def test_three_choices(self):
        step1 = section(COMMAND.read_text(encoding="utf-8"), "### Step 1:", "### Step 2:")
        for label in ("「교체 (권장)」", "「git 규칙은 그대로 두고 헌장만」", "「중단」"):
            self.assertIn(label, step1)
        self.assertNotIn("사용자가 거절하면 중단.", step1)
```

(설계에 없던 결정 1 이 「넣지 않음」이면 `TestGitWorkflowReplaceRefusal` 과 Step 3 의 첫 항목을 뺀다.)

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_command_contract 2>&1 | tail -3`
Expected: FAIL — 새 선택지 라벨 없음.

- [ ] **Step 3: `SKILL.md` 를 고친다**

- Step 1 git 규칙 감지(`:56-59`): `AskUserQuestion` — 「교체 (권장)」(새 템플릿으로 바꾼다) · 「git 규칙은 그대로 두고 헌장만」(Step 2 · 3 · 4b · 4c 의 `## Git Workflow` 갱신 · 4d 를 건너뛰고 헌장 단계로 간다 — 기존 git 규칙 파일과 절은 그대로) · 「중단」(아무 파일도 쓰지 않고 멈춘다). 「사용자가 거절하면 중단.」 줄을 지운다.
- Step 1 이전 질문(`:61-65`): `AskUserQuestion` — 「AGENTS.md 로 옮기기 (권장)」(지금처럼 S2a · S2b) · 「CLAUDE.md 에 바로 쓰기」(AGENTS.md 를 만들지 않고 관리 절 `## Git Workflow` · `## Project Charter` 를 CLAUDE.md 안에서 제자리 갱신한다 — S3 의 절 갱신 규칙을 CLAUDE.md 에 그대로 적용, 비-관리 컨텐츠 보존) · 「중단」(아무 파일도 쓰지 않고 멈춘다). 「CLAUDE.md 에 바로 쓰기」를 고르면 `docs/git-workflow/` 파일은 그대로 만든다. 옛 「AC21에 따라 부분 진행 금지」 문장을 지운다.
- 헌장 상태 감지(`:69-73`): (a)·(b) 의 `AGENTS.md` 를 「관리 절을 담는 파일 — AGENTS.md, 또는 「CLAUDE.md 에 바로 쓰기」를 고른 실행에서는 CLAUDE.md」로. 4e 의 발행 대상 파일도 같은 규칙(4e 첫 표 `→ AGENTS.md` 줄에 같은 괄호).
- 4c S2 행: 「Step 1의 migration 프롬프트 (AC21) — 거절 시 전체 `/project-init:project-init` abort.」 → 「Step 1 의 이전 질문 — 「AGENTS.md 로 옮기기」면 아래 S2a · S2b, 「CLAUDE.md 에 바로 쓰기」면 CLAUDE.md 안에서 관리 절만 제자리 갱신(AGENTS.md 를 만들지 않음), 「중단」이면 멈춘다.」 나머지 S2a · S2b 문면은 그대로.
- 4c S4 행: 「(ii) abort. 승인 시 (i) 수행 + S3 action.」 → 선택지 셋 「옮기기 (권장)」((i) + S3 action) · 「CLAUDE.md 는 그대로 두기」(S3 action 만 — AGENTS.md 관리 절 갱신, CLAUDE.md 는 손대지 않음, git-workflow 파일은 만든다) · 「중단」.
- Step 5 보고 블록: Task 1 의 조건 줄 다음(마지막 줄 앞)에 `> CLAUDE.md 에 바로 썼다면: 관리 절이 CLAUDE.md 에 있다 — AGENTS.md 는 만들지 않았다.` 을 더한다. 「hook」 · 「훅」 · 「검증」을 쓰지 않는다.

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_command_contract test_plain_init_text 2>&1 | tail -3`
Expected: `OK`.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "feat(project-init): 이전 거절 · git 규칙 교체 거절이 실행 전체를 멈추지 않는다 — CLAUDE.md 에 바로 쓰기 선택지" -- plugins/project-init/skills/project-init/SKILL.md plugins/project-init/tests/test_command_contract.py
```

---

### Task 3: 템플릿 브랜치 접두를 전략에서 도출 · 변경 작업일 때만 확인 · worktree 길 (AC33)

**Files:**
- Modify: `plugins/project-init/templates/github-flow/branch-strategy.md` · `templates/git-flow/branch-strategy.md` · `templates/trunk-based/branch-strategy.md` · 세 전략의 `agents-md-section.md`
- Modify: `plugins/project-init/skills/project-init/SKILL.md` (Step 3 「모든 strategy 공통」에 질문 3 · 4b 치환 표)
- Create: `plugins/project-init/tests/test_branch_prefix_templates.py`

**Interfaces:**
- Consumes: 훅 `hooks/post-tool-use.py` 의 `get_branch_pattern() -> Optional[re.Pattern]` · `derive_prefixes(pattern) -> list[str]` · `validate_branch(command) -> Optional[tuple]` (`importlib` 로 로드 — `test_post_tool_use.py:20-23` 와 같은 방식).
- Produces: placeholder `{{BRANCH_PREFIXES}}` · `{{BRANCH_PREFIX_LIST}}` · `{{EXTRA_PREFIX_LIST}}` 와 SKILL 4b 표 바로 아래의 한 줄 `**전략별 기본 접두** — github-flow: \`feature, fix\` · git-flow: \`feature, fix, release, hotfix\` · trunk-based: \`feature, fix\`` (표 칸 안에 `|` 를 쓰면 표가 깨지므로 표 밖에 쉼표로 둔다). `{{BRANCH_PREFIXES}}` 의 값은 그 전략의 기본 접두 + Step 3 질문 3 에서 더한 접두를 순서대로 중복 없이 `|` 로 이은 것이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_branch_prefix_templates.py` (unittest, 레포 루트는 `Path(__file__).resolve().parents[1]` 에서 도출):

- 헬퍼 `defaults_from_skill() -> dict[str, list[str]]` — SKILL 의 `**전략별 기본 접두**` 줄(정확히 한 줄)에서 `github-flow: \`…\`` · `git-flow: \`…\`` · `trunk-based: \`…\`` 를 정규식으로 뽑아 `, ` 로 나눈다(기대값을 테스트가 손으로 적지 않는다).
- 헬퍼 `render(strategy, extras) -> str` — 그 전략 `branch-strategy.md` 의 세 placeholder 를 4b 규칙대로 채운 글.
- `test_regex_fence_is_the_placeholder` — 세 템플릿 모두 `regex` 펜스가 정확히 하나이고 그 내용이 `^({{BRANCH_PREFIXES}})/[a-z0-9][a-z0-9.-]*$` 다. 리터럴 `^(feature|fix` 가 남아 있지 않다.
- `test_hook_derives_defaults` — 전략마다 `render(s, [])` 를 tmp 의 `docs/git-workflow/branch-strategy.md` 에 쓰고 `CLAUDE_PROJECT_DIR` 를 그 tmp 로 둔 뒤 `derive_prefixes(get_branch_pattern()) == defaults_from_skill()[s]`.
- `test_hook_derives_added_prefixes` — `render(s, ["docs", "chore"])` → `derive_prefixes(...) == defaults + ["docs", "chore"]`, 그리고 `validate_branch("git checkout -b docs/readme-fix") is None`. 양성 짝: `render(s, [])` 에서는 같은 명령이 `None` 이 아니다.
- `test_skill_prefix_rule_matches_hook` — SKILL Step 3 질문 3 에서 백틱 안 낱말 규칙(`[a-z][a-z0-9-]*`)을 뽑고, 표본 `["docs", "chore-x", "a1", "Docs", "docs/x", "1fix", "do_cs", ""]` 마다 `re.fullmatch(규칙, t)` 의 참거짓이 「`derive_prefixes(re.compile("^(feature|" + t + ")/x$"))` 에 `t` 가 들어 있다」와 같다.
- `test_prose_uses_derived_list` — 세 `agents-md-section.md` 에 `{{BRANCH_PREFIX_LIST}}` 가 있고, 세 `branch-strategy.md` 에 `{{EXTRA_PREFIX_LIST}}` 가 있다. `branch-strategy.md` 의 `## Rules for Claude` 절에 리터럴 `` `feature/*` 또는 `fix/*` 브랜치 명명 사용`` 이 없다.
- `test_branch_check_only_for_change_work` — 세 `branch-strategy.md` 에 `**ALWAYS** 작업 시작 전 현재 브랜치 확인` 이 없고, `변경 작업` 과 `git branch --show-current` 를 함께 담은 줄이 하나 있다.
- `test_worktree_path_same_rule` — 세 `branch-strategy.md` 에 `### Working in a worktree` 절이 있고, 그 절에 `git worktree add` · `-b` · `Branch Naming Pattern` · `git worktree add -b` 로 만든 이름은 훅이 확인하지 않는다는 문장(`확인하지 않는다`)이 있다.

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_branch_prefix_templates 2>&1 | tail -3`
Expected: FAIL(placeholder 없음 · 4b 행 없음).

- [ ] **Step 3: 템플릿과 SKILL 을 고친다**

- 세 `branch-strategy.md`:
  - `regex` 펜스 내용 → `^({{BRANCH_PREFIXES}})/[a-z0-9][a-z0-9.-]*$`. 펜스 아래 설명 문단은 그대로.
  - `## Branch Prefixes` 표는 기본 행 그대로, 표 바로 아래 한 줄 `추가 접두: {{EXTRA_PREFIX_LIST}}`.
  - `## Rules for Claude`: `**ALWAYS** 작업 시작 전 현재 브랜치 확인: \`git branch --show-current\`` → `**변경 작업(파일 편집 · 커밋)을 시작하기 전** 현재 브랜치 확인: \`git branch --show-current\` — 읽기만 하는 작업에는 확인하지 않는다`. github-flow · trunk-based 의 `**ALWAYS** \`feature/*\` 또는 \`fix/*\` 브랜치 명명 사용` → `**ALWAYS** 브랜치 이름은 위 \`Branch Naming Pattern\` 의 접두 중 하나로 시작`. git-flow 의 분기 기준 규칙(develop · main)은 그대로. 「STOP, 브랜치 먼저 생성」 줄에 「또는 worktree 를 만든다(아래)」를 붙인다.
  - `## Branch Lifecycle` 끝에 `### Working in a worktree` — 브랜치를 전환하지 않고 별도 폴더에서 작업하는 길: 그 전략의 기준 브랜치에서 `git fetch origin` 뒤 `git worktree add -b <접두>/<이름> ../<폴더> origin/<기준 브랜치>`(github-flow · trunk-based 는 `main`, git-flow 의 feature · fix 는 `develop` · hotfix 는 `main`), 이름은 `Branch Naming Pattern` 과 같은 규칙, 끝나면 `git worktree remove ../<폴더>`. 「project-init 훅은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다 — `git worktree add -b` 로 만든 이름은 확인하지 않는다.」 전략마다 기준 브랜치가 달라 20줄 넘게 같은 구간이 생기지 않게 쓴다(문단 10줄 안팎).
- 세 `agents-md-section.md` 의 `- Branch:` 줄: 접두를 `{{BRANCH_PREFIX_LIST}}` 로 — github-flow `- Branch: \`main\`에서 분기, 접두는 {{BRANCH_PREFIX_LIST}}. kebab-case, 2–4 단어.` · trunk-based 같은 꼴에 「1–2일 내 merge.」 유지 · git-flow 는 분기 기준 문장 유지 + 「허용 접두는 {{BRANCH_PREFIX_LIST}}.」.
- SKILL Step 3 「모든 strategy 공통」에 질문 3: **브랜치 접두 추가** — 「기본 접두는 <전략 기본>. 더할 접두가 있나요? (예: `docs` · `chore`)」 선택지 「더하지 않음 (권장)」 · 「더하기」(기타 칸에 쉼표로). 받은 낱말마다 규칙 `[a-z][a-z0-9-]*`(소문자로 시작, 소문자 · 숫자 · `-` 만 — 훅이 접두 목록을 읽는 규칙과 같다)과 중복을 보고, 밖이면 그 낱말과 이유를 보이고 다시 묻는다. Git Flow 의 기존 질문 3(release 명명)은 질문 4 로 번호만 바꾼다.
- SKILL 4b 치환 표에 세 행 — `{{BRANCH_PREFIXES}}`(전략 기본 접두 + 질문 3 에서 더한 접두를 순서대로 중복 없이 이은 정규식 갈래) · `{{BRANCH_PREFIX_LIST}}`(같은 낱말을 `` `<접두>/*` `` 로 감싸 ` · ` 로 잇는다) · `{{EXTRA_PREFIX_LIST}}`(질문 3 에서 더한 것만 같은 꼴, 없으면 `없음`). 표 바로 아래에 위 Interfaces 의 `**전략별 기본 접두**` 줄. 4a 가 읽는 파일 목록은 그대로.

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_branch_prefix_templates test_post_tool_use test_command_contract 2>&1 | tail -3; cd ../../.. && bash plugins/project-init/tests/test_branch_strategy_rebase_clause.sh 2>&1 | tail -1; bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -1`
Expected: `OK` 와 두 셸 락 GREEN.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "feat(project-init): 템플릿 브랜치 접두를 전략에서 도출하고 더할 수 있게 — 변경 작업일 때만 확인 · worktree 길" -- plugins/project-init/templates plugins/project-init/skills/project-init/SKILL.md plugins/project-init/tests/test_branch_prefix_templates.py
```

---

### Task 4: 감사자는 약한 지적을 열린 질문으로 · 반박자의 「불확실」을 따로 · 리포트 부록 (AC34 의 persona · 부록) — 보안 리뷰 대상

**Files:**
- Modify (persona — 보안 리뷰): `plugins/plugin-audit/agents/plugin-auditor.md` (`:56-57` · `:76-77`) · `plugins/plugin-audit/agents/audit-refuter.md` (frontmatter `description` · `:22-24` · 끝 문단 `:91-92`)
- Modify (리뷰어 지시 — 보안 리뷰): `plugins/plugin-audit/scripts/audit-workflow.js` (`REFUTE_SCHEMA` `:137-158` · `DEEP_SCHEMA` `:160-168` · `refutePrompt` `:455-456` · 렌즈 프롬프트 `:665` · 병합 `:553-556` · `:590-593` · 심층 표결 `:681-706`)
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py` (새 절 「목록에서 뺀 지적」)
- Test: `plugins/plugin-audit/tests/audit-workflow.test.mjs` · `tests/test_render_audit_report.py` · `tests/test_agents_generic.py` · `tests/test_assemble_audit_data.py`

**Interfaces:**
- Produces: 반박 판정 `verdict ∈ {"refuted","survives","uncertain"}` (`gate` 는 `refuted` 일 때만 필수). 병합 뒤 지적 레코드 — 기각 · 불확실 모두 `status: "refuted"`, `refutation: {stage: "axis"|"codex"|"deep"|"dedup", gate?, reason, facts?, uncertain: bool}`. 심층 투표 `{id, refuted: bool, uncertain?: bool, lens, reason}`.
- Produces: 렌더러 절 제목 `## 목록에서 뺀 지적` 과 하위 `### 기각` · `### 불확실` · `### 같은 지적에 흡수`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`audit-workflow.test.mjs`:
- `REFUTE_SCHEMA verdict enum includes uncertain` — `captured['검증'].properties.verdicts.items.properties.verdict.enum` 가 `['refuted','survives','uncertain']` 를 포함하고, `if/then` 조건(refuted 일 때 gate 필수)은 그대로.
- `uncertain verdict keeps the finding off the list but marked` — `stubOneFinding('SUGGESTION')` 에서 `검증` 이 `{verdicts:[{finding_id:'A1-1', verdict:'uncertain', reason:'근거 줄을 못 찾음'}]}` 를 내면 결과 지적이 `status === 'refuted'` · `refutation.uncertain === true` · `refutation.stage === 'axis'`. 짝: `verdict:'refuted', gate:'A'` 이면 `refutation.uncertain === false`.
- `deep kill by uncertain votes is marked uncertain` — IMPORTANT 하나, 두 렌즈가 `{refuted:true, uncertain:true}` 를 내면 `refutation.stage==='deep'` · `refutation.uncertain===true`; 한 렌즈만 uncertain 이면 `false`.
- `refute prompt no longer says refute when unsure` — 첫 `검증` 호출의 프롬프트에 `확신이 없으면 \`refuted\`다` 가 없고 `uncertain` 이 있다. 심층 호출 프롬프트에 `확신이 없으면 refute하라` 가 없다.

`test_render_audit_report.py`:
- `test_appendix_groups` — 지적 넷(살아남은 하나 · 기각 `{stage:'axis', gate:'C', reason:'취향', facts:['줄 3 확인']}` · 불확실 `{stage:'axis', reason:'못 찾음', uncertain:True}` · 흡수 `{stage:'dedup', target_id:'A1-1', reason:'…'}`)로 렌더하면 `## 목록에서 뺀 지적` 아래 `### 기각` 에 기각 id 와 `게이트 C` 와 `확인한 사실: 줄 3 확인`, `### 불확실` 에 불확실 id, `### 같은 지적에 흡수` 에 흡수 id 와 `A1-1` 이 있고, 불확실 id 는 `### 기각` 구간에 없다.
- `test_appendix_empty_groups_say_none` — 뺀 지적이 없으면 세 하위 절이 각각 `(없음)`.

`test_assemble_audit_data.py`:
- `test_uncertain_gate_e_goes_to_noq_and_appendix` — `status:'refuted'`, `refutation:{stage:'axis', gate:'E', reason:'범위 판단 불가', uncertain:True}` 인 지적이 `new_open_questions` 에 같은 id · `reason_code:'gate_e_scope_out'` 으로 들어가고, 조립 결과를 `validate-audit-data.py --data` 에 넘기면 GREEN.

`test_agents_generic.py`:
- `test_auditor_never_drops` — `plugin-auditor.md` 본문에 `or drop it` · `or drop the gap` 이 없고 `new_open_questions` 와 `why_not_gap` 이 있다.
- `test_refuter_marks_uncertain_separately` — `audit-refuter.md` 에 `If you are uncertain, refute.` 가 없고 `verdict: uncertain` 이 있다. frontmatter `tools:` 줄은 `Read, Grep, Glob, WebSearch, WebFetch` 그대로.

- [ ] **Step 2: 실패를 확인한다**

Run: `node --test --test-reporter=tap plugins/plugin-audit/tests/audit-workflow.test.mjs 2>&1 | grep -c '^not ok'; python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_render_audit_report.py' 2>&1 | tail -1; python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_agents_generic.py' 2>&1 | tail -1; python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_assemble_audit_data.py' 2>&1 | tail -1`
Expected: node 실패 수 > 0, 세 unittest FAILED.

- [ ] **Step 3: persona 를 고친다**

- `plugin-auditor.md` 제약 3: 「A gap you cannot anchor to a specific line does not exist. Report it as an open question instead — in `new_open_questions`, with `why_not_gap` naming the evidence you could not find. Never drop an observation silently.」 Method 4: 「If not, either strengthen the evidence or report it as an open question (`new_open_questions`, with `why_not_gap`).」 나머지 문면 · `tools:` 그대로.
- `audit-refuter.md`: frontmatter `description` 끝 문장 「Defaults to refuted when uncertain.」 → 「Defaults to refuted; marks findings it cannot settle as uncertain, separately from refuted ones.」 `:22-24` → 「**Your default verdict is `refuted`.** A finding earns survival; it is not presumed valid. If you cannot settle it — what you read neither confirms nor kills it — return `verdict: uncertain` with the gate you could not settle (if any) and why. An uncertain finding stays off the user's gap list exactly like a refuted one, but the report lists it apart, under 「불확실」, so the user can tell a finding dropped for lack of certainty from one killed by a found flaw. A false positive that reaches the user costs them an entire wasted implementation cycle; a false negative merely costs one gap on a list that has others.」 끝 문단에 「If you could not settle it, return `uncertain` — never `survives`.」 한 줄을 더한다.

- [ ] **Step 4: Workflow 와 렌더러를 고친다**

- `REFUTE_SCHEMA.verdict.enum` 에 `'uncertain'`. `DEEP_SCHEMA.properties` 에 `uncertain: { type: 'boolean' }`(필수 아님).
- `refutePrompt` 의 「확신이 없으면 `refuted`다. 다음 게이트 중 **하나라도** 실패하면 kill하라:」 → 「다음 게이트 중 **하나라도** 실패하면 kill하라. 읽은 것으로 살리지도 죽이지도 못하면 `uncertain` 을 내고 어느 게이트에서 막혔는지와 이유를 적어라 — 목록에서는 빠지고 리포트 부록에 「불확실」로 따로 보인다:」. 렌즈 프롬프트의 「**기본 verdict는 refuted다.** 확신이 없으면 refute하라.」 → 「**기본 verdict는 refuted다.** 확신이 없으면 `refuted: true` 와 `uncertain: true` 를 함께 내라.」
- 축 · codex 병합: `v.verdict === 'refuted' || v.verdict === 'uncertain'` 이면 `status='refuted'`, `refutation = { stage, gate: v.gate, reason: v.reason, facts: v.facts || [], uncertain: v.verdict === 'uncertain' }`. 렌즈 투표 객체에 `uncertain: v.uncertain === true`. 심층 사망 시 `refutation.uncertain = votes.filter(x => x.refuted).every(x => x.uncertain)`. dedup 레코드에 `uncertain: false`.
- `render-audit-report.py`: `render()` 끝(결손 절 앞)에 함수 `appendix_lines(all_findings: list) -> list[str]` 의 결과를 붙인다. 대상은 `status == "refuted"` 인 지적 전부. 그룹: `refutation.stage == "dedup"` → 흡수 / `refutation.uncertain is True` → 불확실 / 그 밖 → 기각. 줄 꼴 — 기각 · 불확실: `- {title} ({id}) — {단계} · 게이트 {gate}: {reason}`(게이트 없으면 ` · 게이트 …` 를 뺀다), `facts` 마다 `  - 확인한 사실: {fact}`; 흡수: `- {id} → {target_id}에 흡수`. 단계 이름: `axis` 축 반박 · `codex` codex 반박 · `deep` 심층검증. 그룹이 비면 `(없음)`. 머리말 한 줄: 「반박 단계가 목록에서 뺀 지적이다 — 사용자가 반박을 다시 따져 볼 수 있게 남긴다.」

- [ ] **Step 5: 통과를 확인한다**

Run: Step 2 의 명령 + `python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests 2>&1 | tail -1; node --test --test-reporter=tap plugins/plugin-audit/tests/*.test.mjs 2>&1 | grep -c '^not ok'; bash plugins/plugin-audit/tests/test_axis3_reachability_question.sh 2>&1 | tail -1`
Expected: unittest `OK`, node 실패 0, 셸 락 GREEN.

- [ ] **Step 6: 보안 리뷰 diff 를 남기고 커밋한다**

`git diff HEAD -- plugins/plugin-audit/agents plugins/plugin-audit/scripts/audit-workflow.js > "$HOME/.claude/sdd-mirror/r2a-plan4/persona-task4.diff"` (Task 7 보안 리뷰 입력 — 커밋 전 diff).

```bash
git commit -m "feat(plugin-audit): 약한 지적은 열린 질문으로 · 반박의 불확실을 기각과 나눠 리포트 부록에" -- plugins/plugin-audit/agents/plugin-auditor.md plugins/plugin-audit/agents/audit-refuter.md plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/tests/audit-workflow.test.mjs plugins/plugin-audit/tests/test_render_audit_report.py plugins/plugin-audit/tests/test_agents_generic.py plugins/plugin-audit/tests/test_assemble_audit_data.py
```

---

### Task 5: 코퍼스에서 뺀 수를 공시한다 (AC34 의 공시)

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-staleness.py` (`scan_dangling_doc_claims` · `scan_draft_residue` · `scan_dangling_refs` · `main`)
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js` (CONTRACT `:237-242`)
- Modify: `plugins/plugin-audit/scripts/assemble-audit-data.py` (`out_meta` 허용 키 `:162`)
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py` (새 절 「수집에서 뺀 것」)
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md` (pre-1 step 2 pack 필드 목록 `:123-143` · post-1 의 `meta.json` 설명)
- Test: `tests/test_check_staleness.py` · `tests/audit-workflow.test.mjs` · `tests/test_render_audit_report.py` · `tests/test_assemble_audit_data.py` · `tests/test_skill_orchestration.py`

**Interfaces:**
- Produces: `check-staleness.py` stdout JSON `{"facts": [...], "excluded": {"fence_lines": int, "placeholder_or_url": int, "generation_target": int}}`. 세 스캐너는 키워드 인자 `excluded: Optional[dict] = None` 을 받아 그 키를 1씩 더한다(없으면 버리는 dict). `fence_lines` 는 `main` 이 `_iter_docs` 파일마다 한 번 센다(펜스 표지 줄은 빼고 펜스 안 줄만).
- Produces: evidence pack 필드 `staleness_excluded` 와 `meta.json` 키 `staleness_excluded`(같은 dict). 조립 결과 `meta.staleness_excluded`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `test_check_staleness.py` — 헬퍼 `run_sweep_full()`(전체 JSON 반환). `test_excluded_counts` — README 에 펜스 안 줄 2개(그 안 백틱 경로 하나) · 자리표시자 경로 `` `<your-plugin>/scripts/x.sh` `` 하나 · 생성 대상 `` `docs/out.md` 를 생성한다`` 하나를 두면 `excluded == {"fence_lines": 2, "placeholder_or_url": 1, "generation_target": 1}`. `test_excluded_zero_is_reported` — 아무것도 안 빼면 세 값이 0 이고 키가 있다(침묵과 0 은 다르다).
- `audit-workflow.test.mjs` — `CONTRACT discloses staleness exclusion counts` — pack 에 `staleness_excluded: {fence_lines: 7, placeholder_or_url: 2, generation_target: 1}` 이면 감사 프롬프트에 `코드 펜스 안 7줄` · `자리표시자·URL 2개` · `생성 대상 경로 1개` 가 있다. 없으면 `뺀 개수를 받지 못했다 — 셀 수 없음` 이 있다.
- `test_render_audit_report.py` — `test_exclusion_section` — `meta.staleness_excluded` 가 있으면 `## 수집에서 뺀 것` 아래 세 수가 있고, 없으면 그 절에 `셀 수 없음` 이 있다.
- `test_assemble_audit_data.py` — `test_meta_carries_staleness_excluded` — `meta.json` 의 `staleness_excluded` 가 조립 결과 `meta` 에 그대로 있다.
- `test_skill_orchestration.py` — `INVARIANTS` 에 `"staleness_excluded"` 를 더한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests 2>&1 | tail -1; node --test --test-reporter=tap plugins/plugin-audit/tests/audit-workflow.test.mjs 2>&1 | grep -c '^not ok'`
Expected: FAILED · 실패 수 > 0.

- [ ] **Step 3: 구현한다**

- `check-staleness.py`: 위 Interfaces 대로. `is_fp_claim` 으로 건너뛰는 자리 셋(`:167` 근처 · `:272` 근처 · `:363` · `:379` 근처)에서 `placeholder_or_url` 를, `_is_generation_target` 로 건너뛰는 자리에서 `generation_target` 을 더한다. 결정론 정렬은 그대로.
- `audit-workflow.js` CONTRACT 의 「(코드 펜스·플레이스홀더·생성물 경로는 이미 제외됐다 — 그래도 원문을 직접 확인하라).」 → pack 에 `staleness_excluded` 가 있으면 「(뺀 것: 코드 펜스 안 N줄 · 자리표시자·URL M개 · 생성 대상 경로 K개 — 그래도 원문을 직접 확인하라).」, 없으면 「(뺀 개수를 받지 못했다 — 셀 수 없음. 그래도 원문을 직접 확인하라).」
- `assemble-audit-data.py`: `out_meta` 허용 키 튜플에 `"staleness_excluded"`.
- `render-audit-report.py`: 「목록에서 뺀 지적」 절 다음에 `## 수집에서 뺀 것` — `- 자동 사실 수집이 코드 펜스 안 {n}줄 · 자리표시자·URL {m}개 · 생성 대상 경로 {k}개를 뺐다. 감사자는 원문을 직접 읽는다.` 키가 없으면 `- 셀 수 없음 — 이 감사 데이터에 뺀 수가 없다.`
- SKILL pre-1 step 2: pack 필드 목록에 `staleness_excluded` 를 더하고, 「`staleness_facts`는 `check-staleness.py plugins/<target>`」 문장을 「`staleness_facts` · `staleness_excluded` 는 `check-staleness.py plugins/<target>` 출력의 `facts` · `excluded`」로. post-1 step 2 앞에 「`<meta.json>` 에 `staleness_excluded` 를 같은 값으로 적는다」 한 문장.

- [ ] **Step 4: 통과를 확인한다**

Run: Step 2 의 명령.
Expected: `OK` · 실패 0.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "feat(plugin-audit): 사실 수집에서 뺀 펜스 · 자리표시자 · 생성 대상 수를 감사자와 리포트에 공시" -- plugins/plugin-audit/scripts/check-staleness.py plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/scripts/assemble-audit-data.py plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/skills/plugin-audit/SKILL.md plugins/plugin-audit/tests/test_check_staleness.py plugins/plugin-audit/tests/audit-workflow.test.mjs plugins/plugin-audit/tests/test_render_audit_report.py plugins/plugin-audit/tests/test_assemble_audit_data.py plugins/plugin-audit/tests/test_skill_orchestration.py
```

---

### Task 6: 축 고정 · 심층검증 8건 상한을 없애고 동의 게이트가 축과 규모를 알린다 (AC35)

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js` (`meta` `:1-10` · `args` 정규화 `:26-29` · 축 2 질문 `:316-343` · `AXIS_SCHEMA` 의 `steelman_condition` · `pipeline(AXES, …)` `:498` · 로그 `:537` · 심층 `:637-651` · 반환 `:713-720`)
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md` (frontmatter `description` · phase 0 step 3 `:70-72` · step 4 의 consent 아티팩트 · Workflow 호출 `:207-210`)
- Modify: `plugins/plugin-audit/scripts/assemble-audit-data.py` (`out_meta` 허용 키에 `"axes"`)
- Modify: `plugins/plugin-audit/scripts/validate-audit-data.py` (`meta.axes` 검사)
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py` (`:104` · `:112` · `deep_label` · 새 배너)
- Modify: `plugins/plugin-audit/README.md` (`:3-5` · `:17` · `:87`) · `plugins/plugin-audit/tests/README.md` (실행 순서 2 · 5)
- Test: `tests/audit-workflow.test.mjs` · `tests/test_render_audit_report.py` · `tests/test_validate_audit_data.py` · `tests/test_skill_orchestration.py`

**Interfaces:**
- Consumes: Task 4 의 `refutation.uncertain` (심층 표결이 상한 없이 돌 때도 같은 규칙).
- Produces: Workflow 인자 `args.axes: number[]` — 생략하면 `[1,2,3,4,5,6]`. 정수 1~6 · 중복 없음 · 비지 않음이 아니면 첫 dispatch 전에 `throw new Error('[plugin-audit] 축 선택이 잘못됐다 — ' + 이유)`. 반환에 `axes_run: number[]`. `meta.json` · 조립 결과 `meta.axes: number[]`(consent 아티팩트의 `axes` 와 같은 값).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`audit-workflow.test.mjs`:
- `axes default runs all six` — `args.axes` 없이 감사 호출 6번, `result.axes_run` 이 `[1,2,3,4,5,6]`.
- `axes [1,6] runs exactly those` — 감사 호출 2번이고 라벨이 `축1 …` · `축6 …`, `axes_run` `[1,6]`.
- `bad axes throw before any dispatch` — `[0]` · `[7]` · `['3']` · `[1,1]` · `[]` 마다 `runWorkflow` 가 reject 되고 그 실행의 `calls.length === 0`(하네스가 throw 전에 넣은 호출이 없다 — `calls` 를 바깥에서 볼 수 있게 `runWorkflow` 가 reject 할 때도 `calls` 를 노출하도록 하네스 `_wf_harness.mjs` 에 `opts.calls` 배열 주입을 더한다).
- `axes without 6 — axis 2 schema drops pending` — `axes:[2]` 이면 축 2 감사 호출의 `findings.items.properties.steelman_condition.enum` 과 `oq_answers.items.properties.steelman_condition.enum` 에 `'pending'` 이 없고, 프롬프트에 `축⑥은 이번 감사에서 돌지 않는다` 가 있다. 짝: `axes:[2,6]` 이면 `'pending'` 이 있고 그 문장이 없다.
- `deep verify has no cap` — 감사 단계가 IMPORTANT 지적 12개(`A1-1`…`A1-12`)를 내고 반박이 모두 `survives` 면 `심층검증` 호출이 24번이고 어떤 지적도 `deep_verified === false` 가 아니다.
- `no DEEP_CAP in source` — 스크립트 원문에 `DEEP_CAP` · `캡 8` · `6축` 이 없다.

`test_render_audit_report.py`:
- `test_deep_verified_three_states` 를 두 상태로 고친다 — True → `통과`, None → 무라벨. `상한 초과` 가 어디에도 없다.
- `test_axis_denominator_follows_chosen_axes` — `meta.axes=[1,2,6]` · `axis_failures=[{"axis":2}]` 면 `⚠ **축 2/3 완주**`. 고른 축이 모두 죽으면 rc 1(리포트 없음).
- `test_unchosen_axes_banner` — `meta.axes=[1,6]` 이면 머리 20줄 안에 `⚠ **고른 축 2/6**` 과 고르지 않은 축 이름(`2 아키텍처·shape` 등)이 있다. `meta.axes` 가 없거나 여섯이면 그 배너가 없다.

`test_validate_audit_data.py`:
- `test_axes_must_be_valid_subset` — `meta.axes` 가 `[]` · `[0]` · `[1,1]` · `["1"]` 면 RED, `[1,6]` · 키 없음은 GREEN.

`test_skill_orchestration.py`:
- `test_consent_gate_announces_axes_and_scale` — phase 0 step 3 구간(`3. **지출 동의 게이트` 부터 `4. **실행 디렉토리**` 앞까지)에 `「여섯 축 전부 (권장)」` · `「축 골라서」` · `상한 없음` · `심층검증` 이 있고, `최대 8` · `약 30` 이 없다. 기존 앵커 `AskUserQuestion\`으로 명시 승인` 은 그대로 한 번.
- `test_workflow_call_passes_axes` — `## Workflow` 펜스에 `axes` 가 있다.

- [ ] **Step 2: 실패를 확인한다**

Run: `node --test --test-reporter=tap plugins/plugin-audit/tests/audit-workflow.test.mjs 2>&1 | grep -c '^not ok'; python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests 2>&1 | tail -1`
Expected: 실패 수 > 0 · FAILED.

- [ ] **Step 3: Workflow 를 고친다**

- `args` 정규화 다음에 `AXES_RUN` 을 푼다(위 Interfaces 규칙, 오류면 throw). `AXES` 배열(여섯 축의 질문 목록)은 그대로 두고 `pipeline(AXES.filter((ax) => AXES_RUN.includes(ax.n)), …)`.
- 축 2 질문: `AXES_RUN.includes(6)` 이면 지금 문단 그대로, 아니면 「**조건 (c)는 축⑥(보안)의 판정에 의존한다.**」 문단 대신 「축⑥은 이번 감사에서 돌지 않는다 — (c) 를 네가 직접 판정하거나 `none` 으로 두어라.」. `AXIS_SCHEMA` 의 두 `steelman_condition.enum` 을 `AXES_RUN.includes(6)` 일 때만 `'pending'` 을 담게 만든다(스키마를 상수가 아니라 `AXES_RUN` 에서 만든다).
- 로그 `'/6 축 생존'` → `'/' + AXES_RUN.length + ' 축 생존'`.
- 심층: `DEEP_CAP` · 슬라이스 · `deep_verified = false` 줄 · 캡 초과 로그를 지운다. `deepTargets = deepPool`. 심층 시작 직전 `log('심층검증 ' + deepPool.length + '건 × 렌즈 ' + LENSES.length + ' = ' + deepPool.length * LENSES.length + '회 (상한 없음)')`.
- `meta.description` · 단계 설명에서 「6축」 · 「(캡 8)」을 「고른 축」 · 「(상한 없음)」으로. 반환에 `axes_run: AXES_RUN`.
- 하네스 `_wf_harness.mjs`: `opts.calls` 가 오면 그 배열에 호출을 쌓는다(기본은 지금처럼 내부 배열).

- [ ] **Step 4: 오케스트레이션 · 조립 · 검증 · 렌더를 고친다**

- SKILL phase 0 step 3 을 바꾼다(앵커 문구 `AskUserQuestion`으로 명시 승인 은 (b) 에 한 번 남긴다):
  - (a) **축 고르기** — `AskUserQuestion`: 「여섯 축 전부 (권장)」 · 「축 골라서」. 골라서면 한 번의 호출에 다중 선택 질문 둘 — 「축 1~3 중 쓸 것」(1 정합·정직성 · 2 아키텍처·shape · 3 집행 능력) · 「축 4~6 중 쓸 것」(4 외부 대비·정체성 · 5 UX·디테일 · 6 보안). 하나도 안 고르면 「다시 고르기」 · 「중단」을 묻는다. 보안 축(6)을 빼면 「보안 축을 뺐다 — 사용자 파일 파괴 경로를 아무도 보지 않는다」를 질문 (b) 의 본문 첫 줄에 싣는다.
  - (b) **규모 공시와 승인** — 고른 축 수 k 로 본문에 규모를 적는다: 「감사자 k · 반박 최대 k · codex 감사 k회(설치돼 있으면)와 그 반박 1 · 심층검증은 반박을 통과한 심각·중요 지적마다 2회 — 상한 없음, 몇 건인지는 감사 뒤에 정해지고 시작 직전 실행 기록에 찍힌다」. `AskUserQuestion`으로 명시 승인 — 「승인」 · 「중단」. 승인 없으면 종료 — 실행 디렉토리를 만들지 않는다.
  - step 4 consent 아티팩트를 `{approved, at, fanout, axes}` 로(`fanout` 은 (b) 의 규모 문장 그대로). 고르지 않은 축의 seed 단서 · 질문은 「검증 안 됨」으로 채워진다는 문장을 (b) 본문에 싣는다.
  - `## Workflow` 펜스 args 에 `axes`. post-1 step 2 앞 문장에 「`<meta.json>` 에 `axes` 를 consent 아티팩트와 같은 값으로 적는다」.
  - frontmatter `description` 의 「6축 발견」 → 「고른 축(기본 여섯) 발견」.
- `assemble-audit-data.py`: `out_meta` 허용 키에 `"axes"`.
- `validate-audit-data.py`: `meta` 에 `axes` 가 있으면 비지 않은 목록 · 원소가 `type(x) is int and 1 <= x <= 6` · 중복 없음이 아니면 `errs.append("meta.axes 가 잘못됐다 (…)")`.
- `render-audit-report.py`: `n_axes = len(meta["axes"])` (유효한 목록일 때) 아니면 6. AC-4 조건 `len(axis_failures) >= n_axes`, 배너 `⚠ **축 {n_axes - 실패}/{n_axes} 완주**`. `n_axes < 6` 이면 배너 `⚠ **고른 축 {n_axes}/6** — 고르지 않은 축은 감사하지 않았다: {이름 목록}` (축 이름 표는 `audit-workflow.js` 의 `name` 과 같은 여섯 — 렌더러 상수로 두고 테스트가 두 쪽을 대조한다: `test_axis_names_match_workflow` 가 워크플로 원문에서 `name: '…'` 여섯을 뽑아 비교). `deep_label` 의 False 갈래(「상한 초과」)를 지운다. main 의 stderr 메시지 「6축 전멸」 → 「고른 축 전멸」.
- README `:3-5` 「읽기 전용 리뷰어 여섯이 축마다」 → 「읽기 전용 리뷰어가 고른 축마다(기본 여섯)」, 지출 동의 줄(`:19`)에 「축을 고르고 규모(심층검증은 상한 없음)를 본 뒤 승인한다」, `:17` 「6축 fresh discovery」 → 「fresh discovery」, `:87` 「6축 전멸 시」 → 「고른 축이 모두 죽으면」. tests/README 실행 순서 2 의 「(`AskUserQuestion`, fanout 30)」 → 「(축 고르기 · 규모 공시 · 승인)」, 5 의 「(6축 pipeline)」 → 「(고른 축 pipeline)」.

- [ ] **Step 5: 통과를 확인한다**

Run: `node --test --test-reporter=tap plugins/plugin-audit/tests/*.test.mjs 2>&1 | grep -c '^not ok'; python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests 2>&1 | tail -1; for t in plugins/plugin-audit/tests/test_*.sh; do bash "$t" 2>&1 | tail -1; done; python3 plugins/plugin-audit/scripts/check-law2.py plugins/plugin-audit/scripts/audit-workflow.js --agents-dir plugins/plugin-audit/agents; echo rc=$?`
Expected: 실패 0 · `OK` · 셸 락 GREEN · `check-law2.py` rc 0(dispatch 두 줄 그대로).

- [ ] **Step 6: 보안 리뷰 diff 를 남기고 커밋한다**

`git diff HEAD -- plugins/plugin-audit/scripts/audit-workflow.js > "$HOME/.claude/sdd-mirror/r2a-plan4/persona-task6.diff"`

```bash
git commit -m "feat(plugin-audit): 축 고정 · 심층검증 8건 상한 제거 — 동의 게이트가 고른 축과 규모를 알린다" -- plugins/plugin-audit/scripts/audit-workflow.js plugins/plugin-audit/skills/plugin-audit/SKILL.md plugins/plugin-audit/scripts/assemble-audit-data.py plugins/plugin-audit/scripts/validate-audit-data.py plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/README.md plugins/plugin-audit/tests/README.md plugins/plugin-audit/tests/_wf_harness.mjs plugins/plugin-audit/tests/audit-workflow.test.mjs plugins/plugin-audit/tests/test_render_audit_report.py plugins/plugin-audit/tests/test_validate_audit_data.py plugins/plugin-audit/tests/test_skill_orchestration.py
```

---

### Task 7: 버전 · CHANGELOG · README · 보안 리뷰 · 끝 검증 (AC32 의 CHANGELOG · AC34 의 보안 리뷰 · AC36 · AC37)

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json` (5.0.3 → 5.1.0 임시) · `plugins/project-init/CHANGELOG.md` · `plugins/project-init/README.md` (`:22` · 사용 순서 3 의 「커스터마이징 질문」 줄 · `:57` · `:105`)
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` (1.1.3 → 1.2.0 임시) · `plugins/plugin-audit/CHANGELOG.md`

- [ ] **Step 1: CHANGELOG · README**

- project-init `## [5.1.0] — <머지 날짜>`:
  - `### Changed` — 헌장 재질문 3회 뒤 사용자가 「건너뛰기 · 계속 묻기 · 중단」을 고른다(기계가 정하던 중단 제거) · 헌장 질문 4개 · 관례 1–3개는 기본값, 쓴 수를 공시하고 「더 묻기」로 더 받는다 · Phase 0 스캔은 질문과 겹쳐 돌 수 있다 · **AGENTS.md 이전을 거절해도 실행 전체가 멈추지 않는다 — 옛 AC21 「부분 진행 금지」를 바꿨다**: 「CLAUDE.md 에 바로 쓰기」 선택지, git-workflow 파일 생성은 계속 · (설계에 없던 결정 1 이 들어가면) git 규칙 교체를 거절해도 헌장은 진행 · 템플릿 브랜치 「ALWAYS 확인」은 변경 작업일 때만 · Rules for Claude 의 접두 고정 문장이 `Branch Naming Pattern` 을 가리킨다.
  - `### Added` — 브랜치 접두 추가 질문과 템플릿 placeholder 셋(`{{BRANCH_PREFIXES}}` · `{{BRANCH_PREFIX_LIST}}` · `{{EXTRA_PREFIX_LIST}}`) — 훅이 읽는 정규식이 정본 · 템플릿의 worktree 작업 절.
- project-init README: `:22` 테스트 설명 「(4c S2a H1, AC21 abort)」 → 「(4c S2a H1 · 이전 거절 선택지 · 헌장 게이트 선택)」 및 새 테스트 줄 `test_branch_prefix_templates.py` · 사용 순서의 「커스터마이징 질문 2–3개 답변 (commit scope, merge strategy)」 → 「(commit scope, merge strategy, 브랜치 접두 추가)」 · `:57` 「≤4개 질문으로」 → 「기본 4개 질문으로(쓴 수를 공시하고 「더 묻기」로 더 받는다)」 · `:105` 「각 항목 최대 3회 재질문 후 loud abort (bounded …)」 → 「각 항목 최대 3회 재질문 뒤 사용자가 건너뛰기 · 계속 묻기 · 중단을 고른다(기계가 멈추지 않는다 — 반복은 사용자 선택이 연다)」.
- plugin-audit `## [1.2.0] — <머지 날짜>`:
  - `### Removed` — 6축 고정 · 심층검증 8건 상한(비용만 지키던 장치 — 설계 D1.3).
  - `### Added` — Workflow 인자 `axes` · 동의 게이트의 축 고르기와 규모 공시 · 반박 판정 `uncertain` · 리포트 절 「목록에서 뺀 지적」(기각 · 불확실 · 흡수) · 「수집에서 뺀 것」 · `check-staleness.py` 출력 `excluded`.
  - `### Changed` — 감사자는 근거 약한 지적을 버리지 않고 열린 질문으로 낸다 · 반박자는 불확실을 기각과 나눠 낸다(persona — 보안 리뷰) · 심층검증 수를 시작 직전 실행 기록에 찍는다.

- [ ] **Step 2: 보안 리뷰(따로 한 번)**

입력: `git diff "$(cat "$HOME/.claude/sdd-mirror/r2a-plan4/before.head")"..HEAD -- plugins/plugin-audit/agents plugins/plugin-audit/scripts/audit-workflow.js`. 판단 근거: 「약화가 아니라 표시 분리와 범위 공시 — (1) 감사자: 근거 약한 관찰을 버리지 않고 열린 질문으로 낸다, 지적의 증거 요건(`file:line` + 원문 인용)은 그대로 (2) 반박자: 확인하지 못한 지적은 여전히 목록에서 빠진다 — 리포트 부록에 「불확실」로 따로 보일 뿐, 기본 판정 refuted 와 게이트 A~F 는 그대로 (3) Workflow: 축은 사용자가 고르고 고르지 않은 축은 리포트 머리 배너로 공시, 심층검증은 상한 없이 더 많이 돈다 (4) `tools:` allowlist · 데이터/지시 경계 문장(P21) 그대로」. dispatch:

```
Agent({
  description: "Security review of R2a plan 4 plugin-audit persona diff",
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=PR 본문 「보안 리뷰」 절
  prompt: "<diff>${DIFF}</diff> <rationale>${RATIONALE}</rationale>"
})
```

결과를 `$HOME/.claude/sdd-mirror/r2a-plan4/security-review.md` 에 원문 그대로 둔다. 차단 지적이 있으면 그 Task 로 돌아가 고친 뒤 **다시 리뷰한다**(persona · 보안 수정은 매번 재리뷰). PR 본문 「보안 리뷰」 절(지휘자가 쓴다)에 옮길 요약과 판단 근거를 인계에 적는다.

- [ ] **Step 3: 락과 메타 테스트를 돌린다**

Run: `bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1; bash shared/tests/test_plugin_description_parity.sh 2>&1 | tail -1; bash shared/tests/test_invocation_surface.sh 2>&1 | tail -1; bash shared/tests/test_plain_language_block.sh 2>&1 | tail -1; bash shared/tests/test_skill_body_no_positional_tokens.sh 2>&1 | tail -1; bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -1`
Expected: 새 실패 0(기준선 대비).

- [ ] **Step 4: 끝 스위트 대조(AC36)**

Task 0 의 세 스크립트로 `after` · `after-ext` · `after-node` 를 잰다(동시에 두 스위트를 돌리지 않는다). 그다음 셋 각각 `comm -13 <(cut -f1,2 before*.names | sort -u) <(cut -f1,2 after*.names | sort -u)` 가 빈지 본다(새 실패 «이름» 0). 이름이 바뀐 테스트(`TestMigrationPromptStillGated` → `TestMigrationRefusalChoices`, `test_deep_verified_three_states` 의 단언 변경)로 생긴 차이는 내용을 열어 의도된 교체인지 확인하고 인계에 적는다. 기준선 뒤 origin 기본 브랜치가 움직였으면 버릴 clone 에서 새 base 기준선을 다시 재고 그것과 비교한다.

- [ ] **Step 5: AC37 대조와 설계문서 대조**

- §1 처분표의 계획 4 행 아홉이 각각 어느 AC · Task 로 닫혔는지 표를 `$HOME/.claude/sdd-mirror/r2a-plan4/ac37-table.md` 에 쓴다(헌장 재질문 → AC31/Task 1 · 이전 거절 → AC32/Task 2 · 질문 ≤4 · 관례 → AC31/Task 1 · 직렬 순서 → AC31/Task 1 · 템플릿 접두 · ALWAYS 확인 · worktree → AC33/Task 3 · auditor 버림 → AC34/Task 4 · 반박자 불확실 → AC34/Task 4 · 6축 · 8건 → AC35/Task 6 · 코퍼스 제외 → AC34/Task 5). 새로 찾은 장치(설계에 없던 결정 1 · 8 의 심층 렌즈 자리)와 구현 중 더 찾은 장치를 그 표 끝에 적고 인계로 지휘자에게 넘긴다(설계 §1 행 추가는 지휘자가 — 이 브랜치는 설계문서를 고치지 않는다).
- Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan <계획 2 브랜치 설계문서 사본> docs/superpowers/plans/2026-10-19-r2a-plan4-project-init-plugin-audit.md --acs "AC31~AC35"` — 사본은 `git show feature/shared-review-engine-core:docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` 를 워크트리 안 추적 안 되는 임시 파일로 꺼내 쓰고 지운다. Expected: 빠진 AC 없음.
- AC 보고 파일(`AC<n>: 구현됨|미룸|빠짐 — <근거>`, AC31~AC35 · AC36 · AC37)을 `$HOME/.claude/sdd-mirror/r2a-plan4/ac-report.md` 에 쓴다(지휘자의 `--impl` 대조 입력).

- [ ] **Step 6: 커밋한다**

```bash
git commit -m "chore(project-init,plugin-audit): R2a 계획 4 — 버전 · CHANGELOG · README" -- plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md plugins/project-init/README.md plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md
```

인계에 적는다: 버전 번호는 머지 직전에 다시 확인(지휘자 수리 · R11 과 겹침) · 보안 리뷰 결과와 판단 근거 · AC37 표와 새로 찾은 장치 · 「설계에 없던 결정」 사용자 답 · 대화형에서 `/project-init:project-init` 을 버릴 레포에서 한 번 걸어 볼 것(선택지 문면이 산문 계약이라 테스트는 문면만 잰다 — 사람 확인 항목).
