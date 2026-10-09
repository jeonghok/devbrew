# 쉬운 말 출력 PR 3 — quality-gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** /qg 의 사람용 고정 문구와 질문 셋, 완료 표가 한국어 쉬운 말이 되고, 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이 된다. 모든 리뷰어 지적에 사람에게 보일 한 문장(`plain:`)이 생겨 화면에 먼저 보인다. 판정 줄과 기계가 읽는 줄은 형태가 그대로다. 착수 전 기준선과 비교해 새 실패는 0 이어야 한다.

**Architecture:** 판정은 여전히 `verdict.py` 의 `verdict:` 줄 하나가 정하고, 합성기의 `**Findings:**` 줄과 `판정 degrade` 표지도 그대로 둔다(기계가 읽는다). 바꾸는 것은 그 옆의 사람용 줄뿐이다. `plain:` 칸은 형식을 정하는 곳(agent 정의 · codex 프롬프트 빌더 · 재비판 프로필 · SKILL 의 dispatch 지시)에서 생기고, 넘기는 곳(허용 목록 셋)을 지나, 그리는 곳(합성기 표)에서 요약 앞에 선다. 칸이 없는 지적은 지금처럼 나간다 — 칸이 없다고 버리면 처분 회계에서 소실이 된다.

**Tech Stack:** Python 3.9+, bash(macOS 3.2 호환), git.

**Spec:** `docs/superpowers/specs/2026-10-08-plain-language-output-design.md` (brief: `docs/superpowers/interview/2026-10-03-plain-language-output-interview.md`). 선행: PR 1 · PR 2 머지.

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거가 있으면 보고한 뒤 재결정할 수 있고, 임의 변경은 금지다. 설계 B1~B10 · D1.1~D2.10, PR 1 의 P1~P13, PR 2 의 Q1~Q8 이 제약이다. 이 계획이 정한 것은 아래 표에 있다.
- **작업 위치** — `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice`, 브랜치 `feature/plain-language-voice`. subagent 에게 이 절대경로를 매번 못 박는다.
- **git** — merge(rebase 금지), 경로 지정 커밋, Conventional Commits 에 **한국어 설명**, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. 스태시 금지.
- **Python** — `encoding="utf-8"` 명시, `"python3"` 문자열 리터럴 금지(`shared/tests/test_python_floor.sh` 축 E), Python 3.9.
- **테스트** — 셸은 리포 루트에서 `bash <경로>`, 하나씩. Python 은 그 `tests/` 에서 `python3 -m unittest -v <모듈>`. `plugins/quality-gates/tests/spike/` 는 돌리지 않는다. 선재 RED: `tests/harness/test_skill_orchestration_behavior.sh` 의 둘(「iter cap near Review gate」 · 「R1b→R8 unclaimed」), 부하 아래의 `test_codex_backward_compat.sh`(단독 재실행 GREEN).
- **변이** — 커밋 뒤 변이, `git checkout HEAD -- <파일>` 로 복원, `git diff HEAD --stat` 빈 출력 확인, `PYTHONDONTWRITEBYTECODE=1`.
- **Bash 도구** — 호출마다 새 셸. 계산된 값이 든 복합 명령은 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/` 스크립트로.
- **리뷰어 지시 파일은 보안 민감** — 찾는 지시는 한 글자도 바꾸지 않고, 「짧게 써라」를 넣지 않으며, `tools:` 를 바꾸지 않는다. 칸만 더한다(설계 §5).
- **버전** — quality-gates minor. spec-distill patch(심볼릭 링크된 `shared/codex/codex_findings_to_yaml.py` 의 내용이 바뀐다 — 설치본 캐시 키). 번호는 머지 직전에.
- **산출 보존** — `~/.claude/sdd-mirror/plain-language-output/pr3/`.
- **줄 번호** — 이 계획의 줄 번호는 2026-10-08(PR 1 이전) 기준이다. PR 1 이 모든 `plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md` 의 H1 뒤에 14줄(빈 줄 + 블록 13줄)을 넣었으므로 그 파일들의 줄 번호는 +14 다. 다른 파일(references · scripts · tests)은 그대로다. 편집은 줄 번호가 아니라 「옛」 문구로 찾는다.

## 계획이 정한 것

| # | 정한 것 | 근거 |
|---|---|---|
| R1 | 합성기의 **판단에 필요한 0** 으로 남기는 줄: 처분 줄(`**처분:** 수용 N · 기각 N · 억제 N · 흡수 N · 미판정 N (미판정은 차단)`) · 배관 손실 줄 · 「탐지 0 · 재비판 0」 줄. 이 0 들은 「아무것도 버리지 않았다」·「재비판자가 돌았다」는 공시다. | 설계 §3 원칙 3. 기존 락(`test_synthesize_disposition.sh:191` · `:130`, `test_synthesize_artifact_findings.sh:396-400`, `test_recritic_bridge.sh:420`)이 그 줄들이 늘 보인다고 잰다. 공유 모듈 `render_disposition.py` 는 손대지 않는다. |
| R2 | 합성기 첫 줄은 `render()` 가 계산한 상태 문장이다(판정과 무관 — 판정에 기대는 줄은 `render()` 에 넣지 않는다). 범위·각도 블록 앞의 쉬운 한 줄은 `--emit-verdict` 꼬리에서 `scope:` 블록 앞에 낸다. | `test_verdict_vocabulary.sh:460-486` — 판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다. |
| R3 | 외부 추가 리뷰어(`pr-review-toolkit:code-reviewer` 등)에게는 SKILL 에 dispatch 프롬프트 리터럴이 없다 — 모델이 쓴다. 그래서 「추가 리뷰어 — 스코프 도출」 절에 **프롬프트 끝에 붙일 한 줄**을 리터럴로 적는다. 그 절은 AC6 창(보안 각도 ~ 다른 전제 각도 앵커 사이) 밖이다. | 설계 D2.8 · 조사(2026-10-08) · `test_review_scope_composition.sh` 의 창 규칙. |
| R4 | 오케스트레이터가 `$RV/findings.yaml` 을 손으로 쓸 때 `plain:` 도 옮긴다는 문장을 `confidence:` 옮기기 문장 옆에 더한다. 이 문장이 없으면 칸이 합성기에 닿기 전에 사라진다. | 조사: security-reviewer · 추가 리뷰어 결과는 오케스트레이터가 옮겨 적는다. |
| R5 | 「Codex skip 안내」 표의 영어 사유 문구와 `specialist <X> unavailable … degraded coverage` 줄은 고치지 않는다. 사유 토큰이 사람에게 그대로 보여야 하고(설치 명령 · 버전 문자열), 락(`test_skill_codex_skip_prose.sh` · `test_review_scope_composition.sh:58-59`)이 그 글자를 잰다. | AC6 의 범위는 질문 셋 · 완료 표 · 합성기 · 시작 배너 · cancel 이다. |
| R6 | `cancel-qg-core.sh` 의 `cancel-qg-core: …` 줄은 모델이 읽는 진단이라 그대로 둔다. 사람에게 보이는 보고는 `commands/cancel-qg.md` 가 정하고, 그것을 한국어로 바꾼다. | 설계 §6. |
| R7 | 비코드 산출물 경로(`critiquing-artifacts`)에는 화면 렌더러가 없다 — `kept:` YAML 을 모델이 읽어 보고한다. 그래서 그 경로의 `plain:` 은 `kept` 에 남는 것까지 재고, 보고 틀에 「`plain:` 이 있으면 그것을 먼저 쓴다」 한 줄을 더한다. | 조사: `synthesize_artifact_findings.py` 는 YAML 을 낸다. |
| R8 | Goal 2 의 확인(설계 표 `0b618227#r2.1`): golden 파일 대신 합성기(발견 0건 · 1건 이상)와 시작 배너의 첫 줄과 0 줄 부재를 단언으로 고정한다. | 이 플러그인의 기존 테스트 관례가 단언이다. 변이 「0 인 집계 줄 되살리기 → RED」를 함께 잰다. |

## Review Focus

1. **`plain:` 이 없는 지적** — 외부 리뷰어는 칸을 안 채울 수 있다. 사람은 그 지적이 사라지지 않고 지금처럼 요약으로 보이길 기대한다. → Task 3 의 `case_plain_absent_kept`(변이: 렌더가 칸 없는 지적을 건너뛰기 → RED).
2. **`plain:` 값에 표 칸을 깨는 글자(`|` · 개행)** — 사람은 표가 깨지지 않길 기대한다. → Task 3 의 `case_plain_cell_escaped`(기존 `_cell` 을 지난다).
3. **판정과 무관한 상태 줄이 `verdict:` 를 품는다** — 쉬운 첫 줄에 `verdict: clean` 같은 글자가 들어가면 판정 줄이 둘이 된다. → Task 2 Step 5 의 변이(AC5).
4. **재비판자가 새로 더한 지적에 `plain:` 이 있다** — 다리(`recritic_bridge.py`)가 칸을 넘기는지. → Task 3 의 `case_plain_recritic_added`.
5. **두 리뷰어가 같은 지적을 내고 하나만 `plain:` 을 썼다** — 합칠 때 칸이 사라지지 않길 기대한다. → Task 3 의 `case_plain_survives_dedup`(코드 경로: 신뢰도 높은 쪽이 남는다 — 그쪽에 칸이 없으면 다른 쪽의 칸을 물려받는다).

---

## Task 0: 착수 준비

- [ ] **Step 1: PR 2 머지를 받는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/plain-language-voice
mkdir -p ~/.claude/sdd-mirror/plain-language-output/pr3
git status --porcelain
git fetch origin main
git merge-base --is-ancestor "$(git log --format=%H -1 --grep='게이트 질문에 결정 하나와 경고 개수만')" origin/main && echo PR2-MERGED || echo PR2-NOT-MERGED
git merge-tree --write-tree HEAD origin/main >/dev/null && echo clean || echo CONFLICT
git merge --no-edit origin/main
```

- [ ] **Step 2: 옛 문구 실재 확인**

이 계획이 바꾸는 옛 문구가 각 파일에 정확히 한 번 있는지 센다(Task 마다 「옛」 블록의 첫 줄). 스크립트는 PR 2 Task 0 Step 2 와 같은 모양으로 `/Users/jeonghokim/.claude/jobs/d60d9f96/tmp/pr3_anchor_check.sh` 에 쓴다. 대상:

```text
plugins/quality-gates/skills/quality-pipeline/SKILL.md	      question: "qg iter N: findings remain (<summary>). What next?",
plugins/quality-gates/skills/quality-pipeline/SKILL.md	      question: "qg reached max 5 iterations. Last findings: <summary>. Finish with the current verdict or stop?",
plugins/quality-gates/skills/quality-pipeline/SKILL.md	      question: "Retry failed at <file>: <reason>. Abort the retry iteration, or skip this file and continue with the remaining patches?",
plugins/quality-gates/skills/quality-pipeline/SKILL.md	  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"
plugins/quality-gates/scripts/synthesize_findings.py	            "## Review Findings (Synthesized)",
plugins/quality-gates/scripts/setup-qg.sh	echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
shared/codex/codex_findings_to_yaml.py	DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")
plugins/quality-gates/references/recritic-code-profile.md	- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다.
```

- [ ] **Step 3: 기준선**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/baseline
```

---

## Task 1: 질문 셋 · 완료 표 · 모델이 그대로 내는 문구 (AC6)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(196 · 264 · 610 · 691-730 · 767-780 · 869-882 · 899-913, 그리고 라벨을 부르는 분기 문장들)
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:269-274`(최종 보고 틀)
- Modify: `plugins/quality-gates/commands/cancel-qg.md:35-36, :44, :58-59, :66-67` · `plugins/quality-gates/commands/qg.md`(「Quality-gates state cleared.」)
- Modify(고정 단언): `tests/test_skill_orchestration.sh:35, :39-41, :45-46` · `tests/harness/test_skill_orchestration_behavior.sh:383` · `tests/test_one_pipeline_surface.sh:101-103` · `tests/test_readme_state_diagram_complete.sh:38-39`(README 표지 — Task 5 의 README 가 새 낱말을 싣는다)

- [ ] **Step 1: 고정 단언을 먼저 새 낱말로 바꾼다(RED 확인용)**

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_skill_orchestration.sh:35, :39-41` | `findings remain` | `남은 지적이 있다` | 반복 경계 앵커가 정확히 한 질문에만 있다(라우팅 유일성) |
| `test_skill_orchestration.sh:45-46` | `Retry` · `Accept and finish` | `고치고 다시 돌기` · `지금 판정으로 끝내기` | Fix-loop 선택지가 있다 |
| `harness/test_skill_orchestration_behavior.sh:383` | `question:.*findings remain` | `question:.*남은 지적이 있다` | 보이기(Step 4.5) 다음에 묻는다 |
| `test_one_pipeline_surface.sh:101-103` | 머리글 집합에 `qg iter N` | `qg 반복 N` | 반복마다 머리글로 구별된다 |
| `test_readme_state_diagram_complete.sh:38-39` | `findings remain` · `Final summary` | `남은 지적이 있다` · `최종 요약` | README 상태도가 질문과 끝을 그린다 |

Run: `bash plugins/quality-gates/tests/test_skill_orchestration.sh | tail -1` → Expected: Fail > 0.

- [ ] **Step 2: Fix-loop · Retry failed · Max-iter 질문**

SKILL 691-693 · 697-699 의 앵커 설명 두 곳에서 `` `findings remain` `` 을 `` `남은 지적이 있다` `` 로 바꾼다(문장은 그대로 — 「이 앵커는 이 질문에만 있다」).

705-718(옛 Fix-loop 펜스 안)을 이것으로:

```
AskUserQuestion({
  questions: [
    {
      question: "qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?",
      header: "qg 반복 N",
      options: [
        {label: "고치고 다시 돌기",      description: "제안된 수정을 이 턴에서 파일에 적용하고 다음 반복을 돈다(차등 테스트 포함)."},
        {label: "지금 판정으로 끝내기", description: "남은 지적을 그대로 두고 지금 판정으로 최종 요약에 간다."},
        {label: "멈추기",               description: "이 반복에서 멈춘다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],
      multiSelect: false
    }
  ]
})
```

721-727 의 「Retry 옵션 문구」 단락에서 대체 description 을 한국어로: `"<summary> 에 적힌 회귀 단위(예: NEW_REGRESSION)를 고치고 다음 반복을 돈다(차등 테스트 포함)."` 단락 안의 `` `Retry` 옵션 `` 은 `` 「고치고 다시 돌기」 옵션 `` 으로, `"Apply the suggested fixes"` 는 `「제안된 수정을 … 적용하고」` 로 바꾼다.

729 이하 「Branch on answer」 불릿의 굵은 라벨: `**Retry**` → `**고치고 다시 돌기**`, `**Accept and finish**` → `**지금 판정으로 끝내기**`, `**Stop**` → `**멈추기**`. SKILL 의 다른 자리에서 **선택지 라벨로서** `Retry` · `Accept and finish` · `Stop` 을 부르는 곳(`grep -n '"Retry"\|Accept and finish\|"Stop"\|\*\*Retry\*\*\|\*\*Stop\*\*' plugins/quality-gates/skills/quality-pipeline/SKILL.md`)을 같은 낱말로 바꾼다. 개념어로서의 「Retry 반복」(예: 「Retry patches」 · 「Retry iteration」)은 지시문이라 그대로 둔다.

767-779(옛 Retry failed 펜스)를:

```
AskUserQuestion({
  questions: [
    {
      question: "<file> 수정에 실패했다: <reason>. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까?",
      header: "수정 실패",
      options: [
        {label: "이번 반복 멈추기",  description: "이번 수정 반복 전체를 멈추고 qg 판정에 실패로 올린다."},
        {label: "이 파일만 건너뛰기", description: "이 파일의 수정만 건너뛰고 나머지 수정은 이번 반복에서 계속 적용한다."}
      ],
      multiSelect: false
    }
  ]
})
```

그 뒤 분기 문장이 `Abort retry` · `Skip this file` 을 부르면 새 라벨로 바꾼다.

869-881(옛 Max-iter 펜스)을:

```
AskUserQuestion({
  questions: [
    {
      question: "qg 가 최대 5번 반복했다. 마지막 지적: <summary>. 지금 판정으로 끝낼까, 멈출까?",
      header: "qg 최대 반복",
      options: [
        {label: "지금 판정으로 끝내기", description: "남은 지적을 받아들이고 최종 요약에 간다."},
        {label: "멈추기",               description: "파이프라인을 멈춘다. 지적을 고친 뒤 /qg 를 다시 돌린다."}
      ],
      multiSelect: false
    }
  ]
})
```

- [ ] **Step 3: 완료 표 · Trivia 줄 · 범위 줄 · 범위 경고**

906-907(옛):

```bash
printf 'Verdict\t<마지막 verdict: 값 — not-certified 면 (<reason>) 포함>\nIterations\t<N>\nOutcome\t<finished | accepted with findings iter N | aborted iter N>\n' \
  | $QG/scripts/render-terminal.py table --title "Quality Gates — Complete"
```

새:

```bash
printf '판정\t<마지막 verdict: 값 — not-certified 면 (<reason>) 포함>\n반복\t<N>번\n결과\t<끝났다 | 지적을 남기고 끝냈다(반복 N) | 멈췄다(반복 N)>\n' \
  | $QG/scripts/render-terminal.py table --title "Quality Gates — 끝"
```

910 의 영어 문장(`Then print the last synthesizer output's \`scope:\` block and \`angles:\` block verbatim …`)은 그대로 둔다(`test_topic_scope_wiring.sh` 가 그 글자를 잰다). 그 문장 뒤에 한 문장을 더한다:

```markdown
The completion report opens with the table's 판정 and 결과 in one Korean sentence and ends with exactly one next action for the user (e.g. 「남은 지적 2개를 고친 뒤 /qg 를 다시 돌린다」 or 「할 일 없음」).
```

196(옛) `Print \`Trivia diff — pipeline skipped (one-sentence diff per CLAUDE.md trivia escape).\`` → 새 `Print \`작은 수정이라 파이프라인을 건너뛰었다 — 한 문장으로 설명되는 diff 다(CLAUDE.md trivia escape).\``

264 의 두 범위 줄(옛) `> Review scope: session (<COUNT> changed files). 전체 PR/브랜치는 /qg branch.` · `> Review scope: topic <topic_key> (<COUNT> changed files · 구성원 <branches>).` → 새 `> 리뷰 범위: 이번 세션에서 바뀐 파일 <COUNT>개. 브랜치 전체를 보려면 /qg branch.` · `> 리뷰 범위: 주제 <topic_key> — 바뀐 파일 <COUNT>개 · 구성원 <branches>.`(고치기 전에 `grep -rn 'Review scope:' plugins/quality-gates/tests` 로 고정 단언을 찾아 같이 바꾼다.)

610 의 범위 경고(옛) `` `> [quality-gates] scope check degraded (detached HEAD / no base branch / unrelated history / shallow) — empty-scope detection skipped (fail-open; this run's scope-empty floor input is unavailable — the other reasons in Step 4's table still apply normally).` `` → 새:

```text
`> [quality-gates] 범위를 확인하지 못했다(scope check degraded — detached HEAD / no base branch / unrelated history / shallow) — 바뀐 파일이 0개인지 보는 검사를 건너뛰었다(fail-open). Step 4 표의 다른 사유는 그대로 적용된다.`
```

`scope check degraded` 토큰이 남는다(`harness/test_skill_orchestration_behavior.sh:423`).

- [ ] **Step 4: critiquing-artifacts 최종 보고 · cancel 보고**

critiquing-artifacts SKILL 269-274 의 최종 보고 틀 머리에 두 문장을 더한다(라운드 히스토리 · 종료 사유 · 잔여 kept 집합의 목록은 그대로):

```markdown
보고의 첫 줄은 끝났는지와 결과 한 문장이다(예: 「비평을 3라운드 돌고 수렴했다 — 남은 지적 없음.」 · 「상한 5라운드에 닿았다 — 남은 지적 2개.」). 잔여 `kept` 항목에 `plain:` 이 있으면 그것을 먼저 쓰고 원래 `summary` 는 뒤 괄호에 둔다. 맨 끝에 사용자가 할 일 하나를 쓴다.
```

`commands/cancel-qg.md`:

| 줄 | 옛 | 새 |
|---|---|---|
| 35 | `"Cannot determine session ID — no active pipeline."` | `"세션을 알아낼 수 없다 — 돌고 있는 파이프라인이 없다."` |
| 36 | `"No active quality gates pipeline found for this session."` | `"이 세션에서 돌고 있는 Quality Gates 파이프라인이 없다."` |
| 44 | `"Cancelled quality gates pipeline (session_id: <SID>, started_at: <ISO>, worktree: <path or 'none'>)".` | `"Quality Gates 파이프라인을 멈추고 상태를 지웠다(session_id: <SID>, 시작: <ISO>, worktree: <경로 또는 없음>)".` |
| 58 | `"Delete ALL quality-gates session folders? N appear active (mtime < 1h)."` | `"Quality Gates 세션 폴더를 전부 지울까? 그중 N개는 최근 1시간 안에 쓰여 아직 돌고 있을 수 있다."` |
| 59 | `"Yes, delete all" / "No, abort"` | `"모두 지운다" / "그만둔다"` (3·4 단계의 **Yes** · **No** 도 `**모두 지운다**` · `**그만둔다**`) |
| 66 | `"Removed all session folders."` · `"No session folders to delete."` · `"Failed to remove session folders."` | `"세션 폴더를 모두 지웠다."` · `"지울 세션 폴더가 없다."` · `"세션 폴더를 지우지 못했다."` |
| 67 | `"Aborted."` | `"그만뒀다."` |

`commands/qg.md` 의 `"Quality-gates state cleared."` → `"Quality Gates 상태를 지웠다."`

- [ ] **Step 5: 테스트를 돈다**

Run:
```bash
for t in test_skill_orchestration test_one_pipeline_surface test_topic_scope_wiring test_review_scope_composition test_cancel_qg test_critiquing_artifacts_skill test_skill_drop_notice_consumed; do printf '%s ' "$t"; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done
bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep -E '^FAIL|Total' | head
```
Expected: 앞의 일곱은 `Fail: 0`. harness 는 선재 RED 둘만(「iter cap near Review gate」의 거리 숫자는 SKILL 줄 수 변화로 바뀔 수 있다 — 같은 단언이 이미 RED 이므로 새 실패가 아니다. 다른 FAIL 줄이 생기면 고친다). `test_readme_state_diagram_complete.sh` 는 Task 5 까지 RED 다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/skills plugins/quality-gates/commands plugins/quality-gates/tests/test_skill_orchestration.sh plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh plugins/quality-gates/tests/test_one_pipeline_surface.sh plugins/quality-gates/tests/test_readme_state_diagram_complete.sh
git commit -m "feat(qg): 질문 셋과 완료 표, cancel 보고를 한국어 쉬운 말로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 2: 합성기 · 시작 배너 · 세션 시작 경고 (Goal 2 · AC5 · AC6 · R1 · R2 · R8)

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py:615-712, :921-930`
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:182-185, :250-253, :306-322`
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py:181-193`
- Create: `plugins/quality-gates/tests/test_plain_synth_output.sh`
- Modify(고정 단언 — Step 4 의 표)

**Interfaces:**
- Produces: 합성기 stdout 첫 줄 = `_status_line(findings, suppressed_count)`:
  - 발견 0: `리뷰를 합쳤다 — 확신 높은 지적 없음.` + (숨긴 것이 있으면) ` 확신이 낮아 숨긴 지적 N개.`
  - 발견 ≥1: `리뷰를 합쳤다 — 남은 지적 N개(심각 a · 중요 b · 제안 c).` (0 인 등급은 뺀다) + (숨긴 것이 있으면) ` 확신이 낮아 숨긴 지적 N개.`
  - 이 줄은 `verdict` 글자를 담지 않는다.
- 둘째 줄부터: `## 리뷰 지적 (합친 결과)` · 빈 줄 · (발견 ≥1 이면) `**Findings:**` 줄(형태 그대로) · 처분 줄 셋(그대로) · …
- `--emit-verdict` 꼬리: 범위·각도 블록이 하나라도 있으면 그 앞에 `아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다.` 한 줄.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_plain_synth_output.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh
#
# 쉬운 말 출력 설계 Goal 2 · AC5 · AC6 (계획 R8) — 합성기와 시작 배너의 첫 줄이 상태 문장이고 0 인 정상 집계가 없다.
# 판단에 필요한 0(처분 줄 · 배관 손실 줄)은 남는다(R1).
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT

# 발견 0
printf '[]\n' > "$T/empty.yaml"
out="$(python3 "$SYNTH" --findings "$T/empty.yaml")"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 확신 높은 지적 없음." "Goal 2: 발견 0 의 첫 줄이 상태 문장이다"
assert_not_contains "$out" "No high-confidence" "AC6: 영어 고정 문구가 없다"
assert_grep "$out" '^\*\*처분:\*\* ' "R1: 처분 줄(판단에 필요한 0)은 남는다"
assert_not_contains "$(printf '%s\n' "$out" | head -1)" "verdict" "AC5: 쉬운 첫 줄은 verdict 글자를 담지 않는다"

# 발견 ≥1 (심각 1 · 중요 0 · 제안 0 → 0 인 등급은 첫 줄에 없다)
printf -- '- agent: security-reviewer\n  file: app.py\n  line: 3\n  severity: CRITICAL\n  confidence: 9\n  summary: "SQL 을 문자열로 만든다"\n  proposed_fix: "바인딩"\n' > "$T/one.yaml"
out="$(python3 "$SYNTH" --findings "$T/one.yaml")"
assert_eq "$(printf '%s\n' "$out" | head -1)" "리뷰를 합쳤다 — 남은 지적 1개(심각 1)." "Goal 2: 발견 ≥1 의 첫 줄이 상태 문장이고 0 인 등급을 뺀다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 0 IMPORTANT / 0 SUGGESTION$' "AC5: 기계가 읽는 Findings 줄은 형태 그대로다"
assert_grep "$out" '^\| 심각도 \| 위치 \| 확신 \| 내용 \| 낸 곳 \|$' "AC6: 표 머리가 한국어다"
assert_grep "$out" '^\*\*고칠 방법:\*\*$' "AC6: 제안 수정 머리가 한국어다"

# --emit-verdict: 판정 줄은 정확히 하나, 쉬운 줄과 섞이지 않는다
out="$(python3 "$SYNTH" --findings "$T/one.yaml" --emit-verdict)"
assert_eq "$(printf '%s\n' "$out" | grep -c '^verdict: ')" "1" "AC5: verdict 줄은 정확히 한 번"
assert_eq "$(printf '%s\n' "$out" | grep -c 'verdict:')" "1" "AC5: 그 밖의 줄에 verdict: 글자가 없다"

# 시작 배너 — 과정 나열이 없다
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
assert_file_absent "$SETUP" 'Pipeline: scope → differential test' "Goal 2: 시작 배너에 과정 나열이 없다"
assert_file_grep "$SETUP" 'Quality Gates 를 시작한다' "Goal 2: 시작 배너 첫 줄이 상태 문장이다"
finish
```

Run: `bash plugins/quality-gates/tests/test_plain_synth_output.sh | tail -1` → Expected: Fail > 0.

- [ ] **Step 2: 합성기를 고친다**

`synthesize_findings.py` 의 `render()` 바로 앞에 넣는다:

```python
_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def _status_line(counts, suppressed_count):
    """사람이 보는 첫 줄 — 스크립트가 계산한 상태 문장(쉬운 말 출력 설계 §3).
    판정(verdict)과 무관하다: 판정 없는 출력이 판정 있는 출력의 바이트 접두여야 한다."""
    total = sum(counts.values())
    if total == 0:
        s = "리뷰를 합쳤다 — 확신 높은 지적 없음."
    else:
        parts = " · ".join("%s %d" % (ko, counts[k]) for k, ko in _SEV_KO if counts[k])
        s = "리뷰를 합쳤다 — 남은 지적 %d개(%s)." % (total, parts)
    if suppressed_count > 0:
        s += " 확신이 낮아 숨긴 지적 %d개." % suppressed_count
    return s
```

빈 분기의 `out = [ … ]`(옛 628-634):

```python
        out = [
            "## Review Findings (Synthesized)",
            "",
            f"No high-confidence findings. {suppressed_count} low-confidence "
            "findings suppressed.",
            disp_line, plumb_line, gloss_line,
        ]
```

새:

```python
        out = [
            _status_line({"CRITICAL": 0, "IMPORTANT": 0, "SUGGESTION": 0}, suppressed_count),
            "## 리뷰 지적 (합친 결과)",
            "",
            disp_line, plumb_line, gloss_line,
        ]
```

빈 분기의 malformed 줄(옛 641-646):

```python
            out.append(
                f"{dropped_malformed} finding(s) dropped as "
                "malformed (not a mapping, wrong container type, or missing "
                "file/severity/summary) — see stderr. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )
```

새:

```python
            out.append(
                f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
                "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고. "
                "**이 실행은 clean이 아니다**: 버려진 주장은 심사되지 않았다."
            )
```

표 행의 요약 칸(옛 663) `summary = _cell(f.get("summary", ""))` → 새:

```python
        plain = f.get("plain")
        summary = _cell(f"{plain} ({f.get('summary', '')})" if isinstance(plain, str) and plain.strip() else f.get("summary", ""))
```

표 분기의 `out = [ … ]`(옛 684-685):

```python
    out = ["## Review Findings (Synthesized)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]
```

새:

```python
    out = [_status_line(counts, suppressed_count), "## 리뷰 지적 (합친 결과)", "", counts_line,
           disp_line, plumb_line, gloss_line, ""]
```

표 머리 둘(옛 690-691):

```python
    out.append("| Sev | Path:Line | Conf | Summary | Source |")
    out.append("|---|---|---|---|---|")
```

새:

```python
    out.append("| 심각도 | 위치 | 확신 | 내용 | 낸 곳 |")
    out.append("|---|---|---|---|---|")
```

꼬리 줄들(옛 694-708):

```python
    if any_caveat:
        out.append("`*` = confidence <= 6 (treat with caution).")
    if suppressed_count > 0:
        out.append(
            f"{suppressed_count} finding(s) suppressed (conf <= 4); "
            "re-run with `/qg --show-low-confidence` to see all."
        )
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} finding(s) dropped as malformed "
            "(not a mapping, wrong container type, or missing "
            "file/severity/summary) — see stderr."
        )
    out.append("")
    out.append("**Suggested fixes:**")
```

새:

```python
    if any_caveat:
        out.append("`*` = 확신 6 이하 — 조심해서 볼 것.")
    if suppressed_count > 0:
        out.append(
            f"확신 4 이하 지적 {suppressed_count}개를 숨겼다 — 전부 보려면 `/qg --show-low-confidence`."
        )
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed}개 지적을 버렸다 — 형식이 깨졌다(dropped as malformed: 매핑이 아니거나, "
            "담는 형이 틀리거나, file/severity/summary 가 없다) — stderr 참고."
        )
    out.append("")
    out.append("**고칠 방법:**")
```

`counts_line`(`**Findings:** …` 와 ` — N suppressed (conf <= 4)` 꼬리)은 그대로 둔다 — 기계가 읽는다(설계 §3 표).

`--emit-verdict` 꼬리(옛 926-929)의 `if scope is not None:` 앞에 넣는다:

```python
        if scope is not None or angle_states is not None:
            sys.stdout.write("아래는 이 판정이 본 범위(scope)와 리뷰 각도(angles)의 원문이다.\n")
```

- [ ] **Step 3: 시작 배너와 세션 시작 경고**

`setup-qg.sh` 306-322(옛 배너):

```bash
echo "🔄 Quality Gates Pipeline"
echo ""
echo "Pipeline: scope → differential test → reviewers → re-critique → verdict"
for a in $REMOVED_ARGS; do
  echo "> [quality-gates] \`${a}\` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다."
done

echo ""
echo "Available plugins: ${AVAILABLE_PLUGINS:-none}"
if [[ -n "$PR_URL" ]]; then
  echo "PR URL: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "Plan file: $PLAN_FILE"
fi
echo ""
echo "Pipeline runs in this turn. To cancel before run: /cancel-qg"
```

새:

```bash
echo "🔄 Quality Gates 를 시작한다 — 이 턴 안에서 끝까지 돈다. 돌기 전에 멈추려면 /cancel-qg"
for a in $REMOVED_ARGS; do
  echo "> [quality-gates] \`${a}\` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다."
done
echo "추가 리뷰어 플러그인: ${AVAILABLE_PLUGINS:-없음}"
if [[ -n "$PR_URL" ]]; then
  echo "PR: $PR_URL"
fi
if [[ "$PLAN_FILE" != "auto" ]]; then
  echo "계획 파일: $PLAN_FILE"
fi
```

`setup-qg.sh` 250-253 의 경고(옛 셋째 줄까지 `⚠️  Warning: pr-review-toolkit plugin not found` …) 를 한 줄로:

```bash
  echo "⚠️  pr-review-toolkit 플러그인이 없다 — 추가 리뷰어 code-reviewer 없이, 각도 리뷰어와 설치된 리뷰어만으로 진행한다." >&2
```

(원래 셋째 줄까지 `echo … >&2` 세 줄이었다 — 그 세 줄을 이 한 줄로 바꾼다.)

`setup-qg.sh` 182-185 의 이미-활성 오류(옛 `❌ Error: A quality gates pipeline is already active in this session …`)의 첫 줄을 `❌ 이 세션에서 이미 Quality Gates 파이프라인이 돌고 있다.` 로, 나머지 안내 줄을 같은 뜻의 한국어로 바꾼다(명령 이름 `/cancel-qg` · `/qg --reset` 은 그대로).

`session-start-advisor.py` 181-193:

```python
                sys.stderr.write(
                    "[quality-gates] 이 세션에 옛 v1.x 파이프라인 상태가 남아 있다. "
                    "/qg 를 부르기 전에 `/cancel-qg` 로 지워라 — 한 턴 파이프라인은 v1.x 상태를 이어 받을 수 없다.\n"
                )
```

```python
        sys.stderr.write(
            "[quality-gates] 옛 v1.5.0 상태 파일이 남아 있다. "
            "`/qg --reset` 이나 `/cancel-qg` 로 지울 수 있고, 다음 `/qg` 때 저절로 지워진다.\n"
        )
```

- [ ] **Step 4: 고정 단언을 새 문구로**

먼저 전수를 찾는다(Deferred 2):

```bash
for lit in 'No high-confidence findings' 'low-confidence' 'treat with caution' 'suppressed (conf <= 4); re-run' 'finding(s) dropped as malformed' 'Suggested fixes' 'Review Findings (Synthesized)' '| Sev |' 'already active' 'Legacy v1.x pipeline state detected' 'Legacy v1.5.0' 'Available plugins' 'Pipeline runs in this turn'; do
  printf '== %s\n' "$lit"; /usr/bin/grep -rnF -- "$lit" plugins shared tools 2>/dev/null | grep -v '/golden/' | cut -c1-170
done > ~/.claude/sdd-mirror/plain-language-output/pr3/fixed-string-hits.txt
```

고칠 자리(조사 2026-10-08 · 위 결과로 보충한다):

| 자리 | 옛 | 새 | 지키는 뜻 |
|---|---|---|---|
| `test_angle_coverage.sh:201, :302` | `No high-confidence findings\. 1 low-confidence` | `확신 높은 지적 없음\. 확신이 낮아 숨긴 지적 1개` | 깨끗한/전부 억제된 분기가 알아보이고 숨긴 수를 말한다 |
| `test_recritic_bridge.sh:442` · `test_synthesize_disposition.sh:125, :226` · `test_synthesize_findings.sh:130, :154` | `No high-confidence findings…` | 같은 새 문구 | 같다 |
| `test_synthesize_findings_adjudication.py:215` | `"No high-confidence findings."` | `"확신 높은 지적 없음."` | 같다 |
| `test_synthesize_findings.sh:100` | `'\*\*Suggested fixes:\*\*.*`x\.py:1` —'` | `'\*\*고칠 방법:\*\*.*`x\.py:1` —'` | 제안 수정이 위치와 함께 나온다 |
| `test_synthesize_findings.sh:106` | `` '`\*` = confidence <= 6 \(treat with caution\)\.' `` | `` '`\*` = 확신 6 이하 — 조심해서 볼 것\.' `` | 낮은 확신 표시의 뜻 |
| `test_synthesize_findings.sh:119` | `'finding\(s\) suppressed \(conf <= 4\); re-run with `/qg --show-low-confidence` to see all\.'` | `'확신 4 이하 지적 [0-9]+개를 숨겼다 — 전부 보려면 `/qg --show-low-confidence`\.'` | 숨긴 것을 다시 보는 길 |
| `test_synthesize_findings_adjudication.py:494` | `assertNotIn("suppressed (conf <= 4)", …)` | 그대로 둔다 — 그 케이스는 `**Findings:**` 꼬리(형태 그대로)가 없어야 함을 잰다. 같은 케이스에 `assertNotIn("확신 4 이하 지적", …)` 한 줄을 더한다(부재 단언이 새 문구에서도 공허하지 않게). | 억제 0 이면 억제 문구가 없다 |
| `test_synthesize_promoted_findings.sh:222, :244, :363` · `test_recritic_bridge.sh:449, :543` · `test_synthesize_disposition.sh:268` | `^2 finding\(s\) dropped as malformed` 등 | `^2개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed` 등(숫자는 그대로) | 버린 주장이 stdout 에 보인다 |
| `test_isolation.sh:152` | `already active`(대소문자 무시) | `이미 Quality Gates 파이프라인이 돌고 있다` | 같은 세션 중복 실행을 막는다 |
| `test_kill_switches.py:197` | `"Legacy v1.x pipeline state detected"` | `"옛 v1.x 파이프라인 상태가 남아 있다"` | 하위 kill switch 가 이 경고를 끄지 않는다 |

`test_skill_drop_notice_consumed.sh` 는 SKILL 이 `dropped as malformed` 를 이름으로 대는지를 잰다 — SKILL Step 4.5 의 문장은 그대로라 GREEN 이어야 한다.

- [ ] **Step 5: 테스트와 변이**

Run:
```bash
for t in test_plain_synth_output test_synthesize_findings test_synthesize_disposition test_recritic_bridge test_angle_coverage test_synthesize_promoted_findings test_verdict_vocabulary test_topic_scope_wiring test_setup_qg test_isolation test_session_start_advisor_v2 test_skill_drop_notice_consumed; do printf '%s ' "$t"; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done
( cd plugins/quality-gates/tests && python3 -m unittest test_synthesize_findings_adjudication test_kill_switches 2>&1 | tail -2 )
```
Expected: 전부 `Fail: 0` / `OK`. `test_verdict_vocabulary.sh` 는 **수정 없이** GREEN 이어야 한다(AC5).

커밋한 뒤 변이:
1. `_status_line` 의 `for k, ko in _SEV_KO if counts[k])` 에서 ` if counts[k]` 를 지운다 → `test_plain_synth_output.sh` 의 「0 인 등급을 뺀다」 RED.
2. `_status_line` 의 첫 줄 문자열 끝에 ` verdict: clean` 을 붙인다 → AC5 단언 둘 RED.
3. 빈 분기의 첫 줄을 `"No high-confidence findings."` 로 되돌린다 → RED.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/hooks/session-start-advisor.py plugins/quality-gates/tests
git commit -m "feat(qg): 합성기 첫 줄을 상태 문장으로, 배너와 고정 문구를 한국어로

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: `plain:` 칸 — 형식 · 넘기기 · 그리기 (§5 · AC9 · D2.8 · Deferred 7)

**Files:**
- Modify(형식): `plugins/quality-gates/agents/security-reviewer.md:81-89` · `agents/artifact-critic.md:47-56` · `agents/artifact-adversarial.md:56-62` · `scripts/build_codex_prompt.py:66-78` · `scripts/build_artifact_codex_prompt.py:55-64` · `references/recritic-code-profile.md:10` · `skills/quality-pipeline/SKILL.md:466-472, :497-501`
- Modify(넘기기): `shared/codex/codex_findings_to_yaml.py:66` · `scripts/synthesize_artifact_findings.py:132-133, :291-292` · `scripts/synthesize_findings.py`(합치기 — Review Focus 5)
- Modify(그리기): Task 2 에서 끝났다(표의 요약 칸)
- Create: `plugins/quality-gates/tests/test_plain_field_path.sh`

**Interfaces:**
- 칸 이름 `plain`(문자열, 선택). 뜻: 「처음 보는 사람에게 보일 쉬운 한 문장 — 내부 번호 없이」. 없거나 공백뿐이면 없는 것으로 친다.
- `recritic_bridge.py` 는 이미 `added` 의 칸을 통째로 넘긴다(`nf = dict(a)`) — 코드는 고치지 않고 테스트만 더한다. 익명화(`anonymize`)는 재비판자에게 `plain` 을 넘기지 않는다(프레이밍 차단 — 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_plain_field_path.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/recritic_bridge.py shared/codex/codex_findings_to_yaml.py plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md
#
# 쉬운 말 출력 설계 §5 · AC9 — 생산자마다 리뷰어 출력 하나가 변환·합성을 지나 화면까지 가고, 거기서 plain 이 먼저 나온다.
# plain 이 없는 지적은 버려지지 않고 지금처럼 나온다.
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  sed -n '2s/^# guards: //p' "$0" | tr ' ' '\n'
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
ART="$PLUGIN_ROOT/scripts/synthesize_artifact_findings.py"
B="$PLUGIN_ROOT/scripts/recritic_bridge.py"
CONV="$REPO_ROOT/shared/codex/codex_findings_to_yaml.py"
T="$(mktemp -d)" || exit 1
trap 'rm -rf "$T"' EXIT

# ① 형식 — 생산자 일곱이 plain 칸을 형식에 싣는다(보안 리뷰어 · artifact-critic · artifact-adversarial · codex 빌더 둘 · 재비판 프로필 · 추가 리뷰어 dispatch 줄).
for f in agents/security-reviewer.md agents/artifact-critic.md agents/artifact-adversarial.md scripts/build_codex_prompt.py scripts/build_artifact_codex_prompt.py references/recritic-code-profile.md; do
  assert_file_grep "$PLUGIN_ROOT/$f" 'plain' "AC9 형식: $f 가 plain 칸을 싣는다"
done
assert_file_grep "$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md" '지적마다 `plain:` 칸에' "AC9 형식(D2.8): 추가 리뷰어 dispatch 에 붙일 한 줄이 있다"
assert_file_grep "$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md" '`plain:` 도 리뷰어가 낸 값을 그대로 옮긴다' "R4: 오케스트레이터가 findings.yaml 에 plain 을 옮긴다"

# ② 보안 리뷰어 · 추가 리뷰어 경로 — 오케스트레이터가 쓴 findings.yaml → 합성기 표
printf -- '- agent: security-reviewer\n  file: app.py\n  line: 3\n  severity: CRITICAL\n  confidence: 9\n  summary: "SQL 문자열 결합"\n  plain: "입력값이 그대로 데이터베이스 명령에 들어간다"\n  proposed_fix: "바인딩"\n- agent: code-reviewer\n  file: lib.py\n  line: 7\n  severity: IMPORTANT\n  confidence: 8\n  summary: "예외를 삼킨다"\n  proposed_fix: "다시 던진다"\n' > "$T/f.yaml"
out="$(python3 "$SYNTH" --findings "$T/f.yaml")"
assert_grep "$out" '\| 입력값이 그대로 데이터베이스 명령에 들어간다 \(SQL 문자열 결합\) \|' "AC9: plain 이 먼저, 원래 요약은 뒤 괄호"
assert_grep "$out" '\| 예외를 삼킨다 \|' "AC9(Review Focus 1): plain 없는 지적도 지금처럼 나온다"
assert_grep "$out" '^\*\*Findings:\*\* 1 CRITICAL / 1 IMPORTANT / 0 SUGGESTION$' "AC9: 두 지적 모두 셌다(버린 것 없음)"

# ③ codex 코드 리뷰 경로 — codex JSONL → codex_findings_to_yaml(default) → 합성기
python3 - "$T/codex.jsonl" <<'PY'
import json, sys
text = "```json\n" + json.dumps({"findings": [{"file": "x.py", "line": 2, "severity": "IMPORTANT", "confidence": 8,
        "summary": "경계 검사 누락", "plain": "길이를 확인하지 않아 범위를 넘어 읽는다", "proposed_fix": "검사 추가"}]}, ensure_ascii=False) + "\n```"
open(sys.argv[1], "w", encoding="utf-8").write(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": text}}, ensure_ascii=False) + "\n")
PY
python3 "$CONV" < "$T/codex.jsonl" > "$T/codex.yaml"
assert_file_grep "$T/codex.yaml" 'plain: ' "AC9: codex 변환이 plain 을 넘긴다"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1],encoding="utf-8")); open(sys.argv[2],"w",encoding="utf-8").write(yaml.safe_dump(d["findings"],allow_unicode=True))' "$T/codex.yaml" "$T/codex-list.yaml"
out="$(python3 "$SYNTH" --findings "$T/codex-list.yaml")"
assert_grep "$out" '\| 길이를 확인하지 않아 범위를 넘어 읽는다 \(경계 검사 누락\) \|' "AC9: codex 지적의 plain 이 화면에 먼저 나온다"

# ④ 재비판자가 더한 지적 — recritic_bridge → 합성기
printf '[]\n' > "$T/empty.yaml"
python3 "$B" prepare --findings "$T/empty.yaml" --out-findings "$T/rf.yaml" --out-map "$T/map.json"
{ printf '재비판을 마쳤습니다.\n\n```docreview-recritic\n'; printf 'verdicts: []\nadded:\n  - file: lib.py\n    line: 4\n    severity: CRITICAL\n    summary: "놓친 경로 탐색"\n    plain: "사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다"\n    proposed_fix: "정규화 후 비교"\n'; printf '```\n'; } > "$T/reply.txt"
out="$(python3 "$SYNTH" --findings "$T/empty.yaml" --recritic "$T/reply.txt" --recritic-map "$T/map.json")"
assert_grep "$out" '\| 사용자가 준 경로로 다른 폴더의 파일을 읽을 수 있다 \(놓친 경로 탐색\) \|' "AC9(D2.8): 재비판 added 의 plain 이 화면에 먼저 나온다"

# ⑤ 비코드 산출물 경로 — key → synth 의 kept 에 plain 이 남는다
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", plain: "이 절은 앞 절과 반대로 말한다", proposed_fix: "fix A"}\n' > "$T/critic.yaml"
python3 "$ART" --phase key --findings "$T/critic.yaml" > "$T/merged.yaml"
assert_file_grep "$T/merged.yaml" 'plain: ' "AC9: artifact key 단계가 plain 을 넘긴다"
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$T/merged.yaml")"
printf 'verdicts:\n  - {finding_key: "%s", verdict: confirm, evidence: real}\n' "$K" > "$T/adv.yaml"
out="$(python3 "$ART" --phase synth --findings "$T/merged.yaml" --adversarial "$T/adv.yaml")"
assert_contains "$out" "이 절은 앞 절과 반대로 말한다" "AC9: artifact synth 의 kept 에 plain 이 남는다"

# ⑥ 표 칸을 깨는 글자 (Review Focus 2)
printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "s"\n  plain: "왼쪽 | 오른쪽\\n둘째 줄"\n  proposed_fix: "p"\n' > "$T/esc.yaml"
out="$(python3 "$SYNTH" --findings "$T/esc.yaml")"
assert_eq "$(printf '%s\n' "$out" | grep -c '^| IMPORTANT |')" "1" "Review Focus 2: plain 의 | 와 개행이 표 행을 깨지 않는다"

# ⑦ 합칠 때 칸이 사라지지 않는다 (Review Focus 5)
printf -- '- agent: security-reviewer\n  file: d.py\n  line: 5\n  severity: IMPORTANT\n  confidence: 9\n  summary: "같은 지적"\n  proposed_fix: "p"\n- agent: code-reviewer\n  file: d.py\n  line: 5\n  severity: IMPORTANT\n  confidence: 7\n  summary: "같은 지적"\n  plain: "같은 줄을 두 리뷰어가 짚었다"\n  proposed_fix: "p"\n' > "$T/dup.yaml"
out="$(python3 "$SYNTH" --findings "$T/dup.yaml")"
assert_contains "$out" "같은 줄을 두 리뷰어가 짚었다" "Review Focus 5: 신뢰도 높은 쪽에 plain 이 없으면 합쳐진 다른 쪽의 plain 을 물려받는다"
finish
```

(③ 의 `python3 - … <<'PY'` 는 `$( )` 밖이라 heredoc 파싱 함정이 없다. `yaml` 은 이 플러그인 테스트가 이미 쓴다.)

Run: `bash plugins/quality-gates/tests/test_plain_field_path.sh | tail -1` → Expected: Fail > 0.

- [ ] **Step 2: 형식 일곱 자리**

security-reviewer.md 87행 `  summary: <one-sentence describing the vulnerability and its path>` 바로 뒤에:

```yaml
  plain: <optional — the same finding in one plain sentence a first-time reader understands, no internal IDs>
```

artifact-critic.md 54행 `    summary: "one sentence"` 바로 뒤에:

```yaml
    plain: "optional — the same finding in one plain sentence for a first-time reader, no internal IDs"
```

artifact-adversarial.md 61행(`new_findings` 안의 `    summary: "..."`) 바로 뒤에:

```yaml
    plain: "optional — one plain sentence for a first-time reader"
```

build_codex_prompt.py 74행 `      "summary": "<one sentence>",` 바로 뒤에:

```text
      "plain": "<optional: the same finding in one plain sentence a first-time reader understands, no internal IDs>",
```

build_artifact_codex_prompt.py 62행 `    summary: "one sentence"` 바로 뒤에:

```yaml
    plain: "optional — the same finding in one plain sentence for a first-time reader"
```

recritic-code-profile.md 10행(옛) `` - `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다. `` → 새:

```markdown
- `added` 항목은 `file` · `line` · `severity` · `summary` · `proposed_fix` 를 싣는다. `file` 은 리포 상대 경로다. `plain`(선택)에는 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 — 내부 번호 없이 — 쓴다.
```

quality-pipeline SKILL — 466-472(「추가 리뷰어 — 스코프 도출」) 단락 끝 `(upstream model pinning is respected).` 뒤에 넣는다(R3 — 이 자리는 AC6 창 밖이다):

```markdown
   추가 리뷰어 dispatch 프롬프트의 끝에 이 한 줄을 그대로 붙인다: 「지적마다 `plain:` 칸에 같은 지적을 처음 보는 사람이 읽을 쉬운 한 문장으로 더하라(내부 번호 없이). 다른 칸과 찾는 방식은 평소대로다.」 리뷰어가 칸을 채우지 않으면 지금처럼 진행한다.
```

497-501 의 `confidence:` 문장 바로 뒤에 넣는다(R4):

```markdown
      **각 항목의 `plain:` 도 리뷰어가 낸 값을 그대로 옮긴다** — 없으면 키를 뺀다(지어내지 않는다).
```

- [ ] **Step 3: 넘기는 곳 셋 + 합치기**

`shared/codex/codex_findings_to_yaml.py:66`(옛) `DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")` → 새 `DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix", "plain")`. 끝에 더하므로 칸이 없는 입력의 출력 바이트는 그대로다 — `yaml_emit`(107-125)은 `if k in f:` 로 있는 키만 쓴다(`plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 의 바이트 고정 GREEN).

`synthesize_artifact_findings.py:132-133`(옛):

```python
    fields = ("agent", "sources", "category", "target_anchor", "target_lines",
              "severity", "summary", "proposed_fix", "dedup_key", "stagnation_key")
```

새:

```python
    fields = ("agent", "sources", "category", "target_anchor", "target_lines",
              "severity", "summary", "plain", "proposed_fix", "dedup_key", "stagnation_key")
```

같은 파일 291-292(옛) `{k: f.get(k) for k in ("category", "target_anchor", "target_lines",` / `"severity", "summary", "proposed_fix", "dedup_key")` → 새 `… "severity", "summary", "plain", "proposed_fix", "dedup_key")`.

같은 파일의 합치기(114-130, `by_key[k]` 에 이미 있으면 첫 것을 남기는 자리)에서, 남는 쪽에 `plain` 이 없고 새로 온 쪽에 있으면 물려받는다 — `by_key[k]["severity"] = g["severity"]` 가 있는 갈래와 같은 들여쓰기에 한 줄:

```python
                if not by_key[k].get("plain") and g.get("plain"):
                    by_key[k]["plain"] = g["plain"]
```

`synthesize_findings.py` 의 `dedup`(485~) 에서 `merged = dict(group[0])`(503행 — 신뢰도 높은 것이 남는다) 바로 뒤에:

```python
        if not (isinstance(merged.get("plain"), str) and merged["plain"].strip()):
            other_plain = next((g["plain"] for g in group[1:] if isinstance(g.get("plain"), str) and g["plain"].strip()), None)
            if other_plain:
                merged["plain"] = other_plain
```

- [ ] **Step 4: 테스트와 변이(AC9)**

Run:
```bash
bash plugins/quality-gates/tests/test_plain_field_path.sh | tail -1
for t in test_synthesize_findings test_synthesize_artifact_findings test_recritic_bridge test_build_codex_prompt test_security_reviewer_kill_switch test_agent_tools_lock_mutation; do printf '%s ' "$t"; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done
( cd plugins/spec-distill/tests && python3 -m unittest test_codex_findings_to_yaml 2>&1 | tail -2 )
( cd plugins/quality-gates/tests && python3 -m unittest test_security_reviewer_behavior 2>&1 | tail -2 )
git diff plugins/quality-gates/agents | grep '^[-+]tools' || echo "tools 불변"
```
Expected: 전부 GREEN, 마지막 줄 `tools 불변`.

커밋한 뒤 변이(각각 `test_plain_field_path.sh` RED 확인 → 복원):
1. 합성기 표 행에서 `plain` 이 없으면 `continue` 하게(행 만들기 루프 첫 줄에 `if not f.get("plain"): continue`) → ② 「plain 없는 지적도 나온다」 RED.
2. `synthesize_artifact_findings.py` 의 `kept` 허용 목록에서 `"plain", ` 를 지운다 → ⑤ RED.
3. `codex_findings_to_yaml.py` 의 `DEFAULT_KEYS` 에서 `, "plain"` 을 지운다 → ③ RED.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/artifact-critic.md plugins/quality-gates/agents/artifact-adversarial.md plugins/quality-gates/scripts/build_codex_prompt.py plugins/quality-gates/scripts/build_artifact_codex_prompt.py plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/skills/quality-pipeline/SKILL.md shared/codex/codex_findings_to_yaml.py plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_plain_field_path.sh
git commit -m "feat(qg): 리뷰어 지적마다 사람이 읽을 한 문장(plain) 칸, 화면에 먼저

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 4: README · 소개 문구 · 버전 (§8 · AC10)

**Files:**
- Modify: `plugins/quality-gates/README.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`(quality-gates 항목) · `shared/tests/test_charter_citations.sh:31-33`(`QG_DESC`)
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`(patch) · `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: README 를 새 규칙대로 다시 쓴다**

구조:
1. 첫 문단 — 무엇을 해 주는지 세 문장 안에(「바뀐 코드를 여러 각도에서 리뷰하고, 행동이 바뀐 테스트를 돌리고, 판정 하나를 낸다. PR 설명은 따로, 승인 뒤에만 올린다.」).
2. `## 쓰는 법` — `/qg` · `/qg branch` · `/qg critique <파일>` · `/qg-publish` · `/cancel-qg` 를 「언제 — 무엇이 나오나」 한 줄씩.
3. 상태도(지금 README 의 그림) — 머리글과 설명만 쉬운 말로. 표지 낱말은 아래 목록대로.
4. `## 끄는 법` — kill switch 표(이름 영어 그대로).
5. `## 인스턴스화한 원칙` — 제목 글자를 그대로 둔다(`test_impact_runtime_docs.sh:63-67` 이 그 제목의 창에서 `LD3` · `LD5` · `LD7` 을 잰다). 불릿 형식 `- **<Law N / P#> (<이름>) — <주제>** (vX.Y.Z) — <설명>` 그대로, 설명만 쉬운 문장으로.
6. `## 구조` — 디렉토리 트리(새 스크립트 포함 — `test_impact_runtime_docs.sh:53-57`).

지워지면 안 되는 낱말(README 락 — 조사 2026-10-08):
- `test_readme_state_diagram_complete.sh:22-60`: `single assistant turn` 정확히 1번 · `setup-qg.sh` · `SKILL preflight` · `trivia escape` · `qg iter loop` · `② differential test` · `⑤ synthesize → verdict` · `AskUserQuestion` · `남은 지적이 있다`(Task 1 이 바꾼 표지) · `최종 요약`(Task 1 이 바꾼 표지). 없어야 하는 것: `Runtime gate dispatch` · `Review gate iter loop` · `gate scope?` · `NEEDS_RESOLUTION`.
- `test_readme_scope_reconcile.sh`: `Phase 1 병렬 ≤ 8` · `총/iteration ≤ 10` · `transparency` · `리뷰어 구성 — 각도 셋 + 추가 리뷰어` · `보안 각도 — 매 iteration (모델이 못 뺌)` · `다른 전제 각도 — detect_codex 참이면` · `Prerequisites (추가 리뷰어 optional dependencies)` · `` `pr-review-toolkit`(code-reviewer `` · `` `feature-dev`(code-architect) `` · `every non-trivia pipeline dispatch when detected`. 없어야 하는 것: `len(phase1)` · `= 12` · `subagent fan-out gate` · `gates subagent fan-out`.
- `test_qg_publish_docs.sh:26-47`: `### Kill switches` 절에 `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` · `deterministic envelope|model-authored|모델 저술` · `/qg-publish` · `파이프라인의 일부가 아니다`. 없어야 하는 것: `command-layer opt-in offer`.
- `test_artifact_metadata.sh:14-15`: `critique` · `artifact-critic|critiquing-artifacts`. `test_branch_worktree.sh:149`: `KEEP_WORKTREE`. `test_law2_prose.sh`: 금지 표현 스캔.

Step 1 의 README 표지(`남은 지적이 있다` · `최종 요약`)는 Task 1 이 `test_readme_state_diagram_complete.sh` 에서 이미 새 낱말로 바꿨다. 쓰고 나서:

```bash
for t in test_readme_state_diagram_complete test_readme_scope_reconcile test_qg_publish_docs test_impact_runtime_docs test_artifact_metadata test_branch_worktree test_law2_prose; do printf '%s ' "$t"; bash plugins/quality-gates/tests/$t.sh 2>&1 | tail -1; done
```

- [ ] **Step 2: 소개 문구 — 세 자리를 같은 글자로**

새 문장:

```text
Checks a change before you ship it: one /qg run reviews the diff from several independent angles, runs the tests whose behavior changed, and gives one verdict. /qg-publish separately posts a plain-language PR summary, only after you approve it.
```

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `description`, `.claude-plugin/marketplace.json` 의 quality-gates 항목 `description`, `shared/tests/test_charter_citations.sh:31-33` 의 `QG_DESC` 리터럴을 이 문장으로 바꾼다.

```bash
bash shared/tests/test_charter_citations.sh | tail -1
```
Expected: `Fail: 0`(세 자리가 같고, 금지 표현이 없다).

- [ ] **Step 3: 버전 · CHANGELOG**

quality-gates minor, spec-distill patch. quality-gates CHANGELOG:

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- /qg 의 질문 셋(반복 · 수정 실패 · 최대 반복)과 완료 표, cancel 보고가 한국어 쉬운 말이다. 반복 경계 앵커는 「남은 지적이 있다」다.
- 합성기 출력의 첫 줄이 스크립트가 계산한 상태 문장이다(「리뷰를 합쳤다 — 남은 지적 2개(심각 1 · 중요 1).」). 표 머리와 꼬리 문구도 한국어다. 판정 줄 `verdict:` 과 `**Findings:**` 줄은 형태 그대로다.
- 시작 배너가 과정 나열 없이 한 줄로 시작한다. 세션 시작 경고가 한국어다.

### Added
- 리뷰어 지적의 `plain:` 칸 — 처음 보는 사람이 읽을 쉬운 한 문장. 보안 리뷰어 · artifact-critic · artifact-adversarial · codex 리뷰어 둘 · 코드 재비판자의 새 지적 · 추가 리뷰어 dispatch 에 형식이 있고, 합성기 표가 그것을 요약 앞에 쓴다. 칸이 없으면 지금처럼 나온다.
```

spec-distill CHANGELOG(patch):

```markdown
## [<새 버전>] — <YYYY-MM-DD>

### Changed
- 공유 codex 출력 변환기(`codex_findings_to_yaml.py`)가 기본 칸 묶음에 `plain` 을 더했다(quality-gates 의 리뷰어 칸). spec-distill 이 쓰는 칸 묶음(design · docreview)의 출력은 그대로다.
```

- [ ] **Step 4: 최종 스위트 · /qg · PR**

```bash
bash ~/.claude/sdd-mirror/plain-language-output/run-suite.sh pr3/final
comm -13 ~/.claude/sdd-mirror/plain-language-output/pr3/baseline/failures.txt ~/.claude/sdd-mirror/plain-language-output/pr3/final/failures.txt
```
Expected: 빈 출력(harness 의 「iter cap」 거리 숫자만 바뀐 줄이 나오면 같은 단언의 선재 RED 다 — PR 본문에 적고 새 실패로 세지 않는다).

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/.claude-plugin/plugin.json .claude-plugin/marketplace.json shared/tests/test_charter_citations.sh plugins/quality-gates/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "docs(qg): README 와 소개 문구를 쉬운 말로, 버전 올림

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`/qg branch` 를 돌리고 묻는다: 「`verdict:` 줄이 여전히 하나이고 쉬운 줄과 섞이지 않는가 · `plain:` 이 없는 지적이 버려지는 길이 없는가 · 리뷰어 지시의 찾는 규칙이 한 글자도 바뀌지 않았는가(persona = 보안 민감)」.

PR 본문(한국어): 첫 줄 한 문장 · 「계획이 정한 것」 R1~R8 · 문구 고정 테스트 표(Task 1 Step 1, Task 2 Step 4 — 옛 → 새 · 지키는 뜻) · `plain:` 경로 표(형식 · 넘기기 · 그리기 자리) · 변이 결과 · 할 일 하나: 「작은 변경 하나에 `/qg` 를 돌려, 첫 줄이 상태 문장이고 질문이 한국어인지 봐 주세요」. 맨 끝 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

머지는 사용자가 `! gh pr merge <n> --merge`. 머지 뒤 main 을 받고 PR 4 계획으로 간다.
