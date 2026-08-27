# request-framing (Phase 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 파이프라인 맨 앞에 `request-framing` 회의 단계를 세워 **새 세션의 첫 턴에 그대로 붙여넣는 산문 메시지** `interview-seed` 를 산출하게 하고, 앞 단계의 확정이 하류를 봉인하지 않게 하는 원칙 **P23** 을 devbrew 전체에 신설한다.

**Architecture:** 새 command 1 · skill 1 · agent 2(`tools: []`) · 게이트 스크립트 1 · seed 전용 codex 러너 3점 세트를 더한다. 압축 규약은 플러그인 레벨 공유 계약 `references/compression.md` 로 두되 **채택자는 `framing-requests` 하나**이고 포인터에서 도출한다. 게이트는 seed 본문에 대해 **전부 부재 검사**다 — 존재 검사가 payload 를 양식으로 만드는 것이 이 단계가 막으라고 만들어진 실패이기 때문이다. 인터뷰의 질문 상한(`probe_budget.py`)은 삭제하되 agent-only 루프의 바운드는 **에피소드 필드 둘**로 이식해 무상태 재계산 성질을 지킨다.

**Tech Stack:** Python 3 (표준 라이브러리만) · bash (`shared/tests/assert.sh` 하네스) · `shared/adjudication` 처분 회계 · codex CLI (선택)

**Spec:** `docs/superpowers/specs/2026-08-23-request-framing-design.md`

## 목차

- [Global Constraints](#global-constraints)
- [착수 전 실측 — 이 계획서 작성 중 확정](#착수-전-실측--이-계획서-작성-중-확정)
  - [① baseline](#-baseline)
  - [② 락 × PR 행렬 (도출)](#-락--pr-행렬-도출)
  - [③ P23 재결정 7건 — 설계가 볼 수 없었던 것](#-p23-재결정-7건--설계가-볼-수-없었던-것)
- [File Structure](#file-structure)
- [PR0 — P23 신설 (`0.36.0`)](#pr0--p23-신설-0360)
  - [Task 1: philosophy P23 + CLAUDE.md anti-corollary](#task-1-philosophy-p23--claudemd-anti-corollary)
  - [Task 2: `proceed-gate.md` 재결정 절 승격 + `reviewing-spec` 어휘](#task-2-proceed-gatemd-재결정-절-승격--reviewing-spec-어휘)
  - [Task 3: 채택자 락에 P23 앵커 + mutation](#task-3-채택자-락에-p23-앵커--mutation)
- [PR1 — 상한 삭제 + 원문 보존 (`0.37.0`)](#pr1--상한-삭제--원문-보존-0370)
  - [Task 4: coverage-mapper 바운드를 에피소드 필드 둘로](#task-4-coverage-mapper-바운드를-에피소드-필드-둘로)
  - [Task 5: floor 탈출구 — 사용자 발화 → 박제](#task-5-floor-탈출구--사용자-발화--박제)
  - [Task 6: probe 스윕 삭제 + 잔존 단측 락](#task-6-probe-스윕-삭제--잔존-단측-락)
  - [Task 7: Budget 절 본문 교체 + `finishing.md` 원문 보존](#task-7-budget-절-본문-교체--finishingmd-원문-보존)
  - [Task 8: brief `[미평가]` 라벨 + 문서 동기화 + bump](#task-8-brief-미평가-라벨--문서-동기화--bump)
- [PR2 — 원장 writer 재사용 준비 (`0.38.0`)](#pr2--원장-writer-재사용-준비-0380)
  - [Task 9: `brief_review_state.py` `--ledger-key` + `AXES` 확장](#task-9-brief_review_statepy---ledger-key--axes-확장)
- [PR3 — request-framing 본체 (`0.39.0`)](#pr3--request-framing-본체-0390)
  - [Task 10: `compression.md` + `trivia-escape.md` + 채택자 락](#task-10-compressionmd--trivia-escapemd--채택자-락)
  - [Task 11: command + skill (앵커 넷 + 처분 앵커 둘)](#task-11-command--skill-앵커-넷--처분-앵커-둘)
  - [Task 12: agent 2 + template 2](#task-12-agent-2--template-2)
  - [Task 13: `check_seed.py` + 게이트 락 둘](#task-13-check_seedpy--게이트-락-둘)
  - [Task 14: seed codex 러너·빌더·체크리스트](#task-14-seed-codex-러너빌더체크리스트)
  - [Task 15: mutation 전수 + bump](#task-15-mutation-전수--bump)
- [PR4 — 연결 (`0.40.0`)](#pr4--연결-0400)
  - [Task 16: R1 재정의 · 탐색 경계 · seed 입력 · README](#task-16-r1-재정의--탐색-경계--seed-입력--readme)
- [이 계획이 닫지 않는 것](#이-계획이-닫지-않는-것)

---

## Global Constraints

- **버전 bump** — `plugins/<name>/` 을 건드리는 모든 PR 은 같은 커밋에서 `plugin.json` SemVer bump + `CHANGELOG.md` `## [x.y.z] — YYYY-MM-DD` 헤딩을 낸다. **현재 `spec-distill` = `0.35.3`** (2026-08-27 `origin/main` `983d7d7` 실측).
- **CHANGELOG 에 건너뛴 버전 금지** — `shared/tests/test_changelog_integrity.sh` C5a 가 `spec-distill` floor `0.11.2` 이상에서 인접성을 잰다. `ver_adjacent` 규칙상 `0.35.3 → 0.36.0 → 0.37.0 → 0.38.0 → 0.39.0 → 0.40.0` 는 전부 인접이다(minor +1 이면 patch 는 0 이어야 한다). **patch 를 건너뛰거나 minor 를 둘 올리면 RED.**
- **Law 2** — 새 리뷰어 agent 둘(`seed-critic`·`seed-readback`)은 `tools: []` 다. `Write`/`Edit` 는커녕 `Read` 도 없다.
- **dispatch 처분 앵커** — 새로 만드는 모든 dispatch 자리는 `**처분** — consumer=… · fail-<open|closed> · disclosure=<리터럴>` 한 줄을 **그 dispatch 줄 아래 40줄 안**에 갖는다(`shared/tests/test_dispatch_disposition.sh` 축 A①②). 그리고 **agent 정의는 dispatch 자리가 0 이면 RED** 다(축 `ZERO_AGENTS`) — 새 agent 는 그것을 dispatch 하는 skill 과 **같은 PR** 에 들어가야 한다.
- **`references/*.md` 고아 금지** — `shared/tests/test_skill_reference_pointers.sh` 는 git 추적되는 모든 `references/*.md` 가 가리켜지는지 본다. **포인터 출처 코퍼스는 `plugins/*/skills/*/SKILL.md` ∪ `plugins/*/skills/*/references/*.md` ∪ `plugins/*/references/*.md` 뿐이다 — `commands/*.md` 는 출처가 아니다.** 그리고 접두사는 `${CLAUDE_PLUGIN_ROOT…}/…` · `plugins/<p>/…` · `(../)*references/…` 셋만 인식하며 그 밖은 loud FAIL 이다.
- **20줄 동일 블록 금지** — `shared/tests/test_no_new_duplication.sh` 는 20줄 이상 완전히 같은 블록이 두 파일에 있으면 `copy-of:` 마커나 심볼릭 링크 없이 RED 를 낸다. 코퍼스는 `plugins/*` · `shared/*` 이고 **아직 커밋하지 않은 새 파일도 포함**한다.
- **새 락은 `# guards:` + `--emit-scanned`** — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` 가 선언과 실측 스캔 경로의 **양방향** 일치를 잰다. 선언만 있고 `--emit-scanned` 가 없으면 "미지원" 으로 분류되어 선언이 검증되지 않은 채 남는다.
- **Korean-primary** — 주석·문서는 한국어 primary. 영어는 식별자·고유명사·기술어에 한정.
- **파일 읽기는 명시적 UTF-8** — 생성 파일을 읽는 모든 파이썬 코드는 `encoding="utf-8"` 을 명시한다 (non-UTF-8 locale fail-open 방지).
- **mutation 실행 환경** — `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. 같은 길이 변이가 stale `.pyc` 를 못 넘어 거짓 GREEN/거짓 RED 를 낸다.
- **변이 전에 커밋한다** — `git checkout -- <path>` 는 «마지막 변이»가 아니라 HEAD 로 되돌린다. 커밋하지 않은 채 변이하면 복원이 그 앞의 편집까지 지우고, 복원 후 clean tree 가 성공처럼 보인다.
- **락 메시지의 변수 뒤 한글은 반드시 중괄호** — `printf "${tot}개"`. `"$tot개"` 는 macOS bash 3.2 가 한글 `개` 의 선두 바이트를 변수명에 포함시켜 `set -u` 아래서 죽는다.
- **파이썬 heredoc 을 `$( … )` 안에 넣지 않는다** — 본문에 `\'` + `)` 조합이 들어오면 `bash -n` 단계에서 죽는다. 정본은 파일로 받는 형태(`python3 - … > "$TMPD/out.txt" <<'PY'`). **모든 shell 편집 뒤 `bash -n` 을 돌린다.**
- **`shared/` 는 플러그인이 아니다** — bump 대상이 아니고 설치본에 들어가지 않는다.
- **branch 는 `main` 에서** — 각 PR 은 `main` 에서 분기해 merge commit 으로 돌아온다. rebase 금지.

---

## 착수 전 실측 — 이 계획서 작성 중 확정

설계 §8.2 가 *"락 × PR 은 계획이 도출한다 — 이 문서가 열거하지 않는다"* 로 넘긴 것을 여기서 확정했다. **설계는 2026-08-23 에 쓰였고 그때 base 는 `ead6835` 였다. 2026-08-27 현재 `origin/main` 은 `983d7d7` 로 48커밋 앞서 있다.** 그 사이에 들어온 것이 이 계획의 상당 부분을 바꾼다.

### ① baseline

**측정 기준선** — 워크트리 브랜치에 `origin/main`(`983d7d7`)을 merge 한 트리. 각 테스트를 개별 실행하고 rc 를 기록했다(`PYTHONDONTWRITEBYTECODE=1`).

```
plugins/spec-distill/tests/test_*.sh + shared/tests/test_*.sh
  + plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh
  + plugins/spec-distill/tests/test_*.py  (python3 -m unittest)
→ 72 pass · 1 fail
```

**유일한 RED 는 선재 실패다** — `plugins/spec-distill/tests/test_hook_output_schema.py` (cross-resolver). **이 계획의 어느 태스크도 그 파일을 건드리지 않는다.** merge 이전(base `ead6835`) 측정치는 `68 pass · 1 fail` 이었고 같은 1건이었다 — 즉 main 의 48커밋은 새 RED 를 들여오지 않았다.

> 설계 §8.3 은 `61 pass · 1 fail` 을 적었으나 **그 값은 한 번도 실행된 적이 없다**(리뷰어에 `Bash` 가 없었다). 위 수치가 실측이다.

### ② 락 × PR 행렬 (도출)

설계가 요구한 도출 규칙 그대로다 — 각 PR 의 파일 집합 **F** 를 잡고, `tests/` 를 전수해 **F 의 원소를 코퍼스로 삼는 테스트**를 찾았다. 손으로 적지 않았다.

**도출 방법** — 리포의 모든 `test_*.{sh,py}` 본문을 읽고, 대상 파일을 **식별 가능한 경로 조각**으로 찾았다. `basename` 만으로는 안 된다 — `SKILL.md`·`README.md`·`CHANGELOG.md` 는 여러 파일이 공유하는 이름이라 무관한 테스트 수십 건이 딸려 온다(첫 시도에서 실측). 키는 `conducting-interview/SKILL.md` · `spec-distill/README.md` 처럼 그 파일만 가리키는 형태로 썼다.

| 건드리는 파일 | 그것을 코퍼스로 삼는 테스트 |
|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | `quality-gates :: test_governance_no_capability_caps.sh` |
| `CLAUDE.md` | 22건 — `plugin-audit ×3` · `project-init ×2` · `quality-gates ×9` · `spec-distill ×6`(`test_arm_ledger.py` · `test_arm_once.sh` · `test_brief_agents.sh` · `test_check_brief.sh` · `test_conducting_interview_stage.sh` · `test_reviewing_spec_state_keying.sh`) · `shared ×2`(`test_changelog_integrity.sh` · `test_copy_of_contract.sh`) |
| `references/proceed-gate.md` | `quality-gates :: test_law2_prose.sh` · `spec-distill :: test_conducting_interview_stage.sh` · `test_no_wall_clock.sh` · `test_proceed_gate_adopters.sh` · `test_web_kill_switch.sh` · `shared :: test_dispatch_disposition.sh` |
| `skills/reviewing-spec/SKILL.md` | 11건 — `quality-gates :: test_skill_plugin_root_fallback.sh` · `spec-distill :: test_brief_review_ng3.sh` · `test_conducting_interview_internal.sh` · `test_no_wall_clock.sh` · `test_proceed_gate_adopters.sh` · `test_rereview_cap_consistency.sh` · `test_reviewing_spec_codex_merge.sh` · `test_reviewing_spec_design_only.sh` · `test_reviewing_spec_design_routing.sh` · `test_reviewing_spec_state_keying.sh` · `test_stale_terms.sh` |
| `scripts/probe_budget.py` | `test_conducting_interview_stage.sh` · `test_probe_budget.sh` · `test_readme_sync.sh` |
| `skills/conducting-interview/SKILL.md` | `test_brief_review_entry.sh` · `test_check_verbatim_coverage.sh` · `test_conducting_interview_internal.sh` · `test_conducting_interview_stage.sh` · `test_no_wall_clock.sh` · `test_stale_terms.sh` · **`shared :: test_dispatch_disposition.sh`** |
| `.../references/finishing.md` | `quality-gates :: test_law2_prose.sh` · `test_brief_review_entry.sh` · `test_conducting_interview_stage.sh` · `test_no_wall_clock.sh` · `test_proceed_gate_adopters.sh` · `test_web_kill_switch.sh` · **`shared :: test_skill_reference_pointers.sh`** |
| `templates/interview-audit-template.md` | `test_brief_review_ng3.sh` · `test_check_brief.sh` |
| `scripts/brief_review_state.py` | `test_brief_review_meta.sh` · `test_brief_review_state.py` · `test_reviewing_brief_skill.sh` · `test_yaml_scalar_single_definition.py` |
| `commands/interview.md` | `test_conducting_interview_internal.sh` · **`shared :: test_dispatch_disposition.sh`**(commands 도 dispatch 코퍼스다) |
| `spec-distill/README.md` | `test_handoff_kill_switch.sh` · `test_readme_sync.sh` · `test_rereview_cap_consistency.sh` |
| `plugin.json` · `CHANGELOG.md` | `test_readme_sync.sh` · `shared :: test_changelog_integrity.sh` · `shared :: test_dispatch_disposition.sh` |
| `tests/test_conducting_interview_stage.sh` · `tests/test_proceed_gate_adopters.sh` | **`shared :: test_presence_corpus_behavior.sh`**(두 락을 실제로 실행해 판정 줄과 코퍼스 크기를 읽는다) |
| **새 `references/*.md` 아무거나** | **`shared :: test_skill_reference_pointers.sh`**(고아 검사) |
| **새 `agents/*.md` 아무거나** | **`shared :: test_dispatch_disposition.sh`**(∀ 도출 · `ZERO_AGENTS`) |
| **새 `scripts/*` 아무거나** | **`shared :: test_no_new_duplication.sh`** · `shared :: test_copy_of_contract.sh` |
| **새 `test_*.sh` 아무거나** | **`quality-gates :: test_guards_coverage_bidirectional.sh`** |

**PR 별 확인 목록** — 각 PR 은 아래 전부에 green 이어야 한다(선재 RED 1건 제외).

| PR | 반드시 돌릴 것 |
|---|---|
| **PR0** | `test_proceed_gate_adopters.sh` · `test_presence_corpus_behavior.sh` · `test_no_wall_clock.sh` · `test_web_kill_switch.sh` · `test_conducting_interview_stage.sh` · `test_law2_prose.sh` · reviewing-spec 11건 · `test_governance_no_capability_caps.sh` · `test_skill_reference_pointers.sh` · `test_changelog_integrity.sh` · `test_readme_sync.sh` · `test_guards_coverage_bidirectional.sh` · CLAUDE.md 22건 |
| **PR1** | `test_conducting_interview_stage.sh` · `test_conducting_interview_internal.sh` · `test_brief_review_entry.sh` · `test_check_verbatim_coverage.sh` · `test_check_brief.sh` · `test_brief_review_ng3.sh` · `test_stale_terms.sh` · `test_no_wall_clock.sh` · `test_readme_sync.sh` · `test_proceed_gate_adopters.sh` · `test_web_kill_switch.sh` · `test_law2_prose.sh` · **`test_dispatch_disposition.sh`** · `test_presence_corpus_behavior.sh` · `test_skill_reference_pointers.sh` · `test_changelog_integrity.sh` · `test_guards_coverage_bidirectional.sh` |
| **PR2** | `test_brief_review_state.py` · `test_brief_review_meta.sh` · `test_reviewing_brief_skill.sh` · `test_yaml_scalar_single_definition.py` · `test_changelog_integrity.sh` · `test_readme_sync.sh` |
| **PR3** | 위 전부 + `test_dispatch_disposition.sh` · `test_skill_reference_pointers.sh` · `test_no_new_duplication.sh` · `test_copy_of_contract.sh` · `test_guards_coverage_bidirectional.sh` · `test_presence_corpus_behavior.sh` · `test_proceed_gate_adopters.sh` · `test_law2_prose.sh` · `test_brief_agents.sh` |
| **PR4** | `test_conducting_interview_internal.sh` · `test_conducting_interview_stage.sh` · `test_dispatch_disposition.sh` · `test_readme_sync.sh` · `test_stale_terms.sh` · `test_changelog_integrity.sh` |

**실무 지침** — 태스크마다 목록을 손으로 고르지 말고 각 PR 종료 시 **전수**를 돌린다. 아래 한 줄이면 된다(선재 RED 1건만 남아야 한다).

```bash
cd <repo-root>
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/*/tests/test_*.sh shared/tests/test_*.sh; do
  bash "$t" </dev/null >/dev/null 2>&1 || echo "FAIL $t"
done
for t in plugins/*/tests/test_*.py; do
  m="$(echo "$t" | sed 's|/|.|g; s|\.py$||')"
  python3 -m unittest "$m" </dev/null >/dev/null 2>&1 || echo "FAIL $t"
done
```

### ③ P23 재결정 7건 — 설계가 볼 수 없었던 것

**이 절 자체가 P23 의 두 번째 사례다.** 설계가 못 박은 것을 하류(계획)가 레포 실측으로 반증했다. 조용히 덮어쓰지 않고 근거와 함께 남긴다.

| # | 설계가 정한 것 | 계획이 재결정한 것 | 근거(실측) |
|---|---|---|---|
| **R1** | PR2 첫 항목 = `run_spec_codex_reviewer.sh` 의 맨 `${CLAUDE_PLUGIN_ROOT}` 를 `:-` 유도로 | **삭제 — 이미 main 에 있다** | `c732ddd`(PR #130)가 세 러너에 fallback 을 이식했다. 현재 `run_spec_codex_reviewer.sh:32` = `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`. 맨 참조 0건 |
| **R2** | PR0–PR4 = `0.34.0`–`0.38.0` | **`0.36.0`–`0.40.0`** | main 의 `spec-distill` 이 `0.35.3`. `0.34.0`·`0.35.0` 은 소진됐고, `test_changelog_integrity.sh` C5a 가 건너뛴 버전을 RED 로 낸다 |
| **R3** | `references/trivia-escape.md` 를 **두 command 가** 포인터로 가리킨다 | **`framing-requests/SKILL.md` 도 가리킨다**(command 포인터는 유지) | `test_skill_reference_pointers.sh` 의 포인터 **출처 코퍼스에 `commands/*.md` 가 없다**. command 만 가리키면 그 파일은 **고아 → RED**. 설계 시점에 이 락이 없었다 |
| **R4** | dispatch 자리에 대한 요구 없음 | **skill 의 dispatch 2곳에 `**처분**` 앵커 필수 + 새 agent 2 는 dispatch 와 같은 PR** | main 의 `CLAUDE.md:45-59` 가 신설 규칙을 담고 `shared/tests/test_dispatch_disposition.sh` 가 집행한다. `ZERO_AGENTS` 단언 때문에 agent 정의만 먼저 넣는 분해가 불가능하다 |
| **R5** | seed 러너는 `run_brief_codex_reviewer.sh` 의 **골격을 따른다** | **20줄 이상 동일 블록이 생기면 `copy-of:` 마커 또는 심볼릭 링크로 배포**한다 | `shared/tests/test_no_new_duplication.sh` — 창 20줄 · 최소 200자, 미추적 새 파일도 코퍼스. env override 없음 |
| **R6** | 새 락의 형식 요구 없음 | **새 락 전부에 `# guards:` 선언 + `--emit-scanned` 구현** | `test_guards_coverage_bidirectional.sh` 가 선언 ↔ 실측 스캔 경로의 양방향 일치를 잰다 |
| **R7** | baseline `61 pass · 1 fail` | **`72 pass · 1 fail`** | 실행되지 않았던 값. 위 ① 이 실측 |

**R3 만이 설계 판단의 변경이다.** 나머지 여섯은 사실 정정(R1·R2·R7)이거나 설계 시점 이후 생긴 리포 계약의 흡수(R4·R5·R6)다. R3 의 대안 셋과 기각 사유는 [Task 10](#task-10-compressionmd--trivia-escapemd--채택자-락) 본문에 있다.

---
## File Structure

경로는 전부 리포 루트 기준. `SD` = `plugins/spec-distill`.

**새로 만드는 것 (13)**

| 파일 | 책임 |
|---|---|
| `SD/references/compression.md` | 압축 규약 정본. 채택자는 포인터에서 도출. **오늘 집행 대상이 seed 뿐임을 자기 안에 적는다** |
| `SD/references/trivia-escape.md` | trivia 5패턴 정의 정본. 두 command + `framing-requests/SKILL.md` 가 가리킨다 |
| `SD/commands/request-framing.md` | kill switch · trivia escape 포인터 · skill dispatch. 그 셋만 |
| `SD/skills/framing-requests/SKILL.md` | 확산 후 압축 절차. `proceed-gate.md`·`compression.md`·`trivia-escape.md` 채택 |
| `SD/agents/seed-critic.md` | `tools: []`. 억제 리뷰 네 축. 초안 + 원문 + 레포 `CLAUDE.md` 를 inline 으로 받는다 |
| `SD/agents/seed-readback.md` | `tools: []`. seed 만 받는다. 판정은 사용자 |
| `SD/templates/interview-seed-template.md` | **예시와 쓰지 말 것**. 양식이 아니다 |
| `SD/templates/interview-seed-audit-template.md` | 원문 · 질문 전체 · 긴 초안 · 비평과 냉독 · degrade |
| `SD/scripts/check_seed.py` | 게이트 넷. seed 본문에 대해서는 **전부 부재 검사** |
| `SD/scripts/build_seed_inline_blob.py` | critic 입력 조립 (식별자 redact) |
| `SD/scripts/run_seed_codex_reviewer.sh` | seed 억제 축 codex 러너 |
| `SD/scripts/build_seed_codex_prompt.py` | seed payload 형상 프롬프트 빌더 |
| `SD/scripts/seed-codex-suppression-checklist.md` | 억제 축 체크리스트 — 네 축 |

**새 테스트 (7)**

| 파일 | 잠그는 것 |
|---|---|
| `SD/tests/test_probe_sweep_residue.sh` | probe 별칭 잔존이 `tests/fixtures/`·`CHANGELOG.md` 밖에 0건 (단측) |
| `SD/tests/test_check_seed.sh` | 게이트 넷이 각각 실재하고 각자 RED 픽스처를 잡는다 |
| `SD/tests/test_seed_one_sentence.sh` | **한 문장뿐인 seed 가 통과한다** — 존재 검사 추가가 RED |
| `SD/tests/test_request_framing_command.sh` | kill switch · trivia 포인터 · skill dispatch |
| `SD/tests/test_seed_agents.sh` | 두 agent 의 `tools: []` |
| `SD/tests/test_compression_adopters.sh` | 채택자 표면의 압축 어휘 · 코퍼스 자기만족 방지 · 하한 1 |
| `SD/tests/test_seed_codex_axes.sh` | 억제 축의 체크리스트 실재 + 러너 배선 |

**고치는 것 (11)**

| 파일 | 무엇 |
|---|---|
| `docs/philosophy/devbrew-harness-philosophy.md` | P23 신설 |
| `CLAUDE.md` | Forbidden Patterns 에 anti-corollary 한 줄 |
| `SD/references/proceed-gate.md` | 재결정 규약을 **계약의 절로 승격** |
| `SD/skills/reviewing-spec/SKILL.md` | P23 재결정 규약 어휘 (오늘 0건) |
| `SD/skills/conducting-interview/SKILL.md` | R1 재정의 · 탐색 경계 · seed 입력 · **probe cap 제거** · coverage-mapper 바운드 이식 · 조건 2 유한성 근거 |
| `SD/skills/conducting-interview/references/finishing.md` | 최초 요청 원문 §6 보존 · floor 사용자-승인 박제 경로 |
| `SD/commands/interview.md` | trivia escape 를 포인터로 · seed 아닌 입력에 조언 한 줄 |
| `SD/templates/interview-audit-template.md` | `## 2. Budget` **본문 교체** |
| `SD/scripts/brief_review_state.py` | `--ledger-key` 인자 + `AXES` 에 `suppression` |
| `SD/tests/test_conducting_interview_stage.sh` | probe 단언 제거 + 대체 단언 둘 |
| `SD/tests/test_proceed_gate_adopters.sh` | **P23 앵커만** 추가 |

**삭제하는 것 (4)**

`SD/scripts/probe_budget.py` · `SD/tests/test_probe_budget.sh` · `SD/tests/fixtures/state-probe-at-cap.md` · `SD/tests/fixtures/state-probe-within.md`

---

## PR0 — P23 신설 (`0.36.0`)

**단독 green 조건**: 채택자 락에 네 번째 앵커를 더하는 편집과, 그 앵커를 만족시키는 두 채택자 표면의 편집이 **같은 PR** 에 있어야 한다. 자기 락을 green 으로 만들지 않는 PR 은 단독 green 이 아니다.

### Task 1: philosophy P23 + CLAUDE.md anti-corollary

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`
- Modify: `CLAUDE.md` (Forbidden Patterns 절)

**Interfaces:**
- Consumes: 없음 (이 계획의 첫 태스크)
- Produces: 식별자 `P23` — Task 2·3 과 PR3 의 `compression.md` 가 이 이름으로 인용한다

- [ ] **Step 1: 현재 최대 P 번호와 빈 번호를 실측한다**

Run:
```bash
grep -oE '^> \*\*P[0-9]+ ' docs/philosophy/devbrew-harness-philosophy.md | sort -V | tail -3
grep -c 'P23' docs/philosophy/devbrew-harness-philosophy.md
```
Expected: 최대가 `P22`, `P23` 은 0건. **다르면 멈추고 번호를 다시 정한다** — 빈 번호(`P1`·`P6`·`P7`·`P9`·`P15`·`P16`·`P19`·`P20`)를 재사용하면 슬리밍 때 흡수·삭제된 원칙을 인용하는 기존 문장이 거짓 인용이 된다.

- [ ] **Step 2: P23 을 philosophy 에 넣는다**

`P22` 항목 바로 아래, 같은 서식으로:

```markdown
> **P23 — Decisions Stay Refutable**
> **Law 1 × P17 집행.** 확정된 결정은 재논의 대상이 아니지만 **반증 대상이다.** 앞 단계가 못
> 박은 것이 뒤 단계에서 틀린 것으로 드러나면, 그 단계는 근거를 제시하고 사용자 동의를 받아
> 피벗할 수 있어야 한다 — 임의 변경은 금지, 보고 후 재결정은 허용. Load-bearing: **오류를 가장
> 잘 볼 수 있는 자리는 그 오류를 만든 자리가 아니라 하류다** — 확정을 영구 봉인하면 볼 수 있는
> 자리와 고칠 수 있는 자리가 분리되고, 이른 단계의 오차가 하류 전 구간에 증폭된 채 아무도
> 말할 길이 없어진다. 재발견 금지는 반증 금지가 아니다.
>
> *anti-corollary (AP):* 앞 단계의 확정이 하류에서 반증돼도 피벗 경로가 없는 것.
```

- [ ] **Step 3: 목차를 동기화한다**

`docs/philosophy/devbrew-harness-philosophy.md` 가 300줄 이상이면 상단 `## 목차` 가 필수다(CLAUDE.md Doc Conventions). P23 항목을 추가한다.

Run: `wc -l docs/philosophy/devbrew-harness-philosophy.md`
Expected: 300 이상이면 `## 목차` 에 P23 줄이 있어야 한다. 300 미만이면 면제.

- [ ] **Step 4: CLAUDE.md Forbidden Patterns 에 한 줄**

`## Forbidden Patterns` 의 불릿 목록 끝에:

```markdown
- **Sealed decision** — 앞 단계의 확정이 하류에서 반증됐는데 피벗 경로가 없는 것 (철학 P23 의 anti-corollary). 재발견 금지는 반증 금지가 아니다 — 근거 있는 재결정은 사용자 동의를 받아 허용하고, 임의 변경만 금지한다.
```

- [ ] **Step 5: CLAUDE.md 를 코퍼스로 삼는 22건이 green 인지 확인**

Run:
```bash
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/plugin-audit/tests/test_check_shape_completeness.py \
         plugins/plugin-audit/tests/test_skill_orchestration.py \
         plugins/plugin-audit/tests/test_validate_audit_data.py \
         plugins/project-init/tests/test_command_contract.py \
         plugins/project-init/tests/test_docs_lint.py; do
  m="$(echo "$t" | sed 's|/|.|g; s|\.py$||')"; python3 -m unittest "$m" >/dev/null 2>&1 \
    || echo "FAIL $t"
done
for t in plugins/quality-gates/tests/test_governance_no_capability_caps.sh \
         plugins/quality-gates/tests/test_law2_prose.sh \
         shared/tests/test_changelog_integrity.sh \
         shared/tests/test_copy_of_contract.sh; do
  bash "$t" </dev/null >/dev/null 2>&1 || echo "FAIL $t"
done
```
Expected: 출력 없음.

- [ ] **Step 6: Commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md CLAUDE.md
git commit -m "docs(philosophy): P23 — Decisions Stay Refutable 신설"
```

### Task 2: `proceed-gate.md` 재결정 절 승격 + `reviewing-spec` 어휘

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

**Interfaces:**
- Consumes: `P23` (Task 1)
- Produces: 어휘 `재결정 규약` — Task 3 의 네 번째 앵커가 이 문자열을 grep 한다

- [ ] **Step 1: 오늘의 분포를 실측한다**

Run:
```bash
for f in plugins/spec-distill/references/proceed-gate.md \
         plugins/spec-distill/skills/reviewing-spec/SKILL.md \
         plugins/spec-distill/skills/conducting-interview/SKILL.md \
         plugins/spec-distill/skills/conducting-interview/references/finishing.md; do
  printf '%s %s\n' "$(grep -cE '재결정|반증' "$f")" "$f"
done
```
Expected (2026-08-27 실측):
```
0 plugins/spec-distill/references/proceed-gate.md
0 plugins/spec-distill/skills/reviewing-spec/SKILL.md
0 plugins/spec-distill/skills/conducting-interview/SKILL.md
3 plugins/spec-distill/skills/conducting-interview/references/finishing.md
```

**이 분포가 Task 3 의 앵커를 정한다.** 채택자는 둘이다 — `reviewing-spec`(SKILL.md 가 정본을 가리킨다)과 `conducting-interview`(`references/finishing.md` 가 가리킨다). 후자는 이미 3줄이라 만족하고, 전자는 0줄이라 **이 태스크가 채우지 않으면 Task 3 의 앵커가 착지 즉시 RED** 다.

- [ ] **Step 2: `proceed-gate.md` 에 계약의 절로 승격**

`## Step C — 두 가드` 다음에 새 절을 넣는다. 이 문면이 **정본**이고, 채택자는 자기 어휘로 이것을 자기 표면에 갖는다.

```markdown
## 재결정 규약 (P23)

게이트를 지나 확정된 항목은 **재논의 대상이 아니지만 반증 대상이다.** 하류 단계가 그
확정이 틀렸다는 **근거**를 얻으면, 근거를 제시하고 **사용자 동의를 받아** 피벗할 수 있다.

- **임의 변경 금지** — 근거 없이 바꾸지 않는다.
- **보고 후 재결정 허용** — 근거를 대고 사용자가 결정한다.
- **기록** — 뒤집은 항목은 *원래 / 재결정 / 근거* 세 칸으로 산출물에 남긴다. 조용히
  덮어쓰지 않는다.

이 규약은 **네 옵션 전부와 게이트를 지나지 않는 예외 경로에도** 적용된다 — 핸드오프하는
두 옵션에만 있으면 규약이 아니라 그 두 경로의 관례다.
```

- [ ] **Step 3: `reviewing-spec/SKILL.md` 에 이 skill 어휘로 한 절**

`### 두 가드 — polite stop 금지 (AP2) · cross-compact 조기 진행 금지 (AC19)` 절 다음에:

```markdown
### 재결정 규약 (P23) — 이 skill 의 적용

design doc 이 인터뷰가 확정한 항목을 뒤집어야 한다고 판단하면, **근거와 함께 사용자에게
올린다.** 리뷰어 findings 가 앞 단계의 확정을 겨냥할 때가 그 경로다 — `combined_verdict`
가 `needs_revise` 이고 그 사유가 인터뷰 확정 항목이면, 저자가 조용히 고치지 않고 Phase 5
게이트 질문 텍스트에 *원래 / 재결정 / 근거* 를 실어 사용자가 판정하게 한다.

**임의 변경은 금지, 보고 후 재결정은 허용이다.** 정본은
`${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「재결정 규약」 절.
```

**포인터 표기 주의** — `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 는 `test_skill_reference_pointers.sh` 가 인식하는 세 형태 중 ①이다. 중괄호를 빼거나(`$CLAUDE_PLUGIN_ROOT/…`) 다른 접두사를 쓰면 **loud FAIL** 이다.

- [ ] **Step 4: 실측으로 확인**

Run:
```bash
grep -c '재결정' plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -c '재결정' plugins/spec-distill/references/proceed-gate.md
bash shared/tests/test_skill_reference_pointers.sh </dev/null | tail -3
```
Expected: 앞 둘이 각각 1 이상, 세 번째가 `Total:` 줄에 `Fail: 0`.

- [ ] **Step 5: reviewing-spec 을 코퍼스로 삼는 11건 확인**

Run:
```bash
for t in plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh \
         plugins/spec-distill/tests/test_brief_review_ng3.sh \
         plugins/spec-distill/tests/test_conducting_interview_internal.sh \
         plugins/spec-distill/tests/test_no_wall_clock.sh \
         plugins/spec-distill/tests/test_rereview_cap_consistency.sh \
         plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh \
         plugins/spec-distill/tests/test_reviewing_spec_design_only.sh \
         plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh \
         plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh \
         plugins/spec-distill/tests/test_stale_terms.sh \
         plugins/spec-distill/tests/test_web_kill_switch.sh; do
  bash "$t" </dev/null >/dev/null 2>&1 || echo "FAIL $t"
done
```
Expected: 출력 없음.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/references/proceed-gate.md \
        plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): 재결정 규약을 proceed-gate 계약의 절로 승격 (P23)"
```

### Task 3: 채택자 락에 P23 앵커 + mutation

**Files:**
- Modify: `plugins/spec-distill/tests/test_proceed_gate_adopters.sh`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: 어휘 `재결정` (Task 2)
- Produces: 네 번째 앵커 — PR3 의 `framing-requests/SKILL.md` 가 셋째 채택자로 도출되면 자동으로 요구받는다

- [ ] **Step 1: 실패하는 단언을 먼저 쓴다**

`test_proceed_gate_adopters.sh` 의 채택자 루프 안, `degrade 채널` 단언 **바로 아래**:

```bash
  # P23: 각 채택자가 자기 표면에 **재결정 규약**을 갖는가.
  #
  # 정본(`proceed-gate.md`)에도 같은 어휘가 있지만 그것은 계약 서술이지 이 skill 의
  # 앵커가 아니다 — 위 코퍼스 규칙(정본은 스캔 대상 아님)이 그대로 적용된다.
  # 재는 것은 «규약을 자기 어휘로 적었는가» 이지 그 문면이 무엇인가가 아니다.
  # 앞 단계의 확정이 하류에서 반증됐을 때 피벗 경로가 그 skill 에 있는지가 요구다.
  rc="$(cat "${files[@]}" | grep -cE '재결정|반증')"
  [ "$rc" -ge 1 ] \
    && ok "$name: P23 재결정 규약 앵커 실재 — ${rc}줄" \
    || no "$name: P23 재결정 규약이 자기 표면에 없다 — 앞 단계의 확정을 뒤집을 근거가 생겨도 이 skill 에는 올릴 자리가 없다"
```

- [ ] **Step 2: Task 2 의 편집을 되돌린 상태에서 RED 를 확인한다**

Run:
```bash
git stash push -u -m "p23-anchor-red-probe" -- plugins/spec-distill/skills/reviewing-spec/SKILL.md
SHA="$(git stash list --format='%H %gs' | grep p23-anchor-red-probe | head -1 | cut -d' ' -f1)"
bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh </dev/null | grep -E 'P23|Fail'
git stash apply "$SHA"
git stash list --format='%gd %gs' | grep p23-anchor-red-probe | head -1 | cut -d' ' -f1 \
  | xargs -I{} git stash drop {}
```
Expected: `✗ reviewing-spec: P23 재결정 규약이 자기 표면에 없다` + `Fail: 1` 이상. 복원 후 다시 돌리면 `Fail: 0`.

> **왜 `git stash push -u -m` + `apply <sha>` 인가**: stash 스택은 main 체크아웃과 모든 워크트리가 공유하고 다른 세션이 동시에 push/pop 할 수 있다. 맨 `git stash` / `git stash pop` 은 남의 작업을 꺼낸다.

- [ ] **Step 3: 격리 산술이 여전히 성립하는지 확인**

`shared/tests/test_presence_corpus_behavior.sh` 의 (3) 이 채택자 락을 **실행해** `Σ(채택자별 파일 수) == 전체 코퍼스` 를 잰다. 앵커를 더하는 것은 코퍼스를 바꾸지 않으므로 산술은 불변이어야 한다.

Run: `bash shared/tests/test_presence_corpus_behavior.sh </dev/null | tail -5`
Expected: `Fail: 0`, 그리고 `격리: 채택자 2개의 자기-파일 합 N = 전체 N` 줄.

- [ ] **Step 4: `# guards:` 선언이 실측과 맞는지 확인**

Run: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh </dev/null | grep -i 'proceed_gate\|Fail'`
Expected: `Fail: 0`. 이 태스크는 `--emit-scanned` 가 내는 경로 집합을 바꾸지 않는다(코퍼스 도출은 그대로, 단언만 늘었다).

- [ ] **Step 5: bump + CHANGELOG**

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `version` 을 `0.35.3` → `0.36.0`.

`plugins/spec-distill/CHANGELOG.md` 맨 위에 **새 섹션을 끼워 넣는다**(제자리 덮어쓰기 금지 — `shared/tests/test_changelog_integrity.sh` 가 그 실패를 잡으려고 존재한다):

```markdown
## [0.36.0] — 2026-08-27

### Added
- 재결정 규약(P23)을 `references/proceed-gate.md` 계약의 절로 승격. 확정된 항목은 재논의 대상이 아니지만 **반증 대상**이며, 근거와 사용자 동의가 있으면 피벗할 수 있다.
- `skills/reviewing-spec/SKILL.md` 에 이 skill 어휘의 재결정 규약 절.
- `tests/test_proceed_gate_adopters.sh` 에 네 번째 채택자 앵커(P23).
```

- [ ] **Step 6: PR0 전수 확인**

Run: [착수 전 실측 ②](#-락--pr-행렬-도출) 의 전수 스크립트.
Expected: `FAIL plugins/spec-distill/tests/test_hook_output_schema.py` 한 줄만.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/tests/test_proceed_gate_adopters.sh \
        plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md
git commit -m "test(spec-distill): 채택자 락에 P23 앵커 + v0.36.0"
```

---
## PR1 — 상한 삭제 + 원문 보존 (`0.37.0`)

**이 PR 의 위험**: `test_conducting_interview_stage.sh` 에서 probe 단언을 지우면 **그 파일의 유일한 floor-escalation 단언과 coverage-mapper 바운드 단언이 함께 쓸려 나간다.** 지우는 것과 같은 커밋에서 대체 단언을 넣지 않으면 두 불변식이 locked 에서 unlocked 로 조용히 후퇴한다. Task 4·5 가 그 대체를 **먼저** 세우고 Task 6 이 지운다.

**dispatch 앵커 주의**: `conducting-interview/SKILL.md` 는 dispatch 3곳(`254` coverage-mapper · `270` blind-spot-prober · `322` steelman-builder)과 그 아래 2줄에 `**처분**` 앵커를 갖는다. 이 PR 의 편집은 그 **dispatch 줄과 앵커 줄 사이에 아무것도 끼워 넣지 않는다** — `shared/tests/test_dispatch_disposition.sh` 축 A② 가 「dispatch 아래 40줄 안, 그 사이에 다른 dispatch 없음」 을 잰다.

### Task 4: coverage-mapper 바운드를 에피소드 필드 둘로

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (State schema 절 `26-67` · coverage-mapper 절 `219-262`)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (`179`행 · `272-274`행)

**Interfaces:**
- Consumes: 없음
- Produces: state 필드 `orchestration.stall_episode` · `orchestration.coverage_mapper_dispatched_episode` — Task 6 이 `coverage_mapper_last_probe` 를 지울 때 이 둘이 이미 있어야 한다

- [ ] **Step 1: 대체 단언을 먼저 쓴다 (RED 를 만든다)**

`test_conducting_interview_stage.sh` 의 `179`행 `has 'coverage_mapper_last_probe' …` 를 **지우지 말고** 그 아래에 새 단언 둘을 더한다. 이 시점에는 SKILL 에 새 필드가 없으므로 RED 다.

```bash
# v0.37.0: probe 카운터를 지우면서 coverage-mapper 재dispatch 바운드가 함께 사라지지
# 않게 «에피소드» 단위로 이식한다. 재는 것은 **두 디스크 값의 비교**가 유지되는가다 —
# 값 하나(streak)를 저장하면 streak 3 에서 dispatch(저장 3) → 4 → `3 != 4` → 재dispatch
# → 5 → … 로 레벨-트리거 무한 재dispatch 가 되살아난다(현행 바운드가 명시적으로 막는 것).
has 'stall_episode' "C11(v0.37.0): orchestration.stall_episode in schema"
has 'coverage_mapper_dispatched_episode' "C11(v0.37.0): orchestration.coverage_mapper_dispatched_episode in schema"
```

- [ ] **Step 2: RED 를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh </dev/null | grep -E 'stall_episode|dispatched_episode|Fail'`
Expected: 두 줄 모두 `✗`, `Fail: 2`.

- [ ] **Step 3: State schema 에 필드 둘을 넣는다**

SKILL.md 의 `orchestration:` 블록에서 `coverage_mapper_last_probe` 줄을 대체한다.

```yaml
orchestration:                       # C11/C8 across-resumption 상태 (orchestrator 소유, agent read-only)
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  no_progress_streak: 0              # C11 연속 무진전 probe 수; focused 변경·진전 시 0 reset
  blind_spot_dispatched: false       # C8 인터뷰당 1회 보장; 첫 dispatch 시 true
  stall_episode: 0                   # streak 이 0 으로 reset 될 때마다 +1. 정체 «구간»의 id
  coverage_mapper_dispatched_episode: null   # 마지막 dispatch 가 일어난 에피소드 id
```

- [ ] **Step 4: 재dispatch 조건 산문을 교체한다**

`## coverage-mapper dispatch (C11)` 절의 `**redispatch 바운드(Unbounded-autonomy 가드)**` 단락(`230-233`행)을 통째로 대체한다.

```markdown
**redispatch 바운드(Unbounded-autonomy 가드)**: 재dispatch 조건은
`no_progress_streak >= 3 AND coverage_mapper_dispatched_episode != stall_episode` 다. dispatch
시 `orchestration.coverage_mapper_dispatched_episode = stall_episode` 를 기록하고,
`no_progress_streak` 가 0 으로 reset 될 때마다 `stall_episode` 를 +1 한다. 한 정체 구간당
정확히 1회다.

판정은 **디스크 두 값의 비교**이므로 어느 턴에서든 무상태로 재계산된다 — 그 성질을 잃으면
판정이 모델의 턴-간 기억에 의존하고, 이 SKILL 이 백스톱에 대해 금지하는 *프로즈
self-tracking* 이 된다. **streak 값 자체를 저장하지 않는 이유**: streak 3 에서 dispatch(저장
3) → streak 4 → `3 != 4` → 재dispatch → streak 5 → 재dispatch … 로 레벨-트리거 무한
재dispatch 가 그대로 살아난다.

**dispatch 조건 2 는 이 바운드의 대상이 아니라 «바운드가 불필요»하다.** floor 차원의 첫
`open→in-progress` 전이는 대상이 **floor 다섯 차원으로 고정**이므로(derived 차원은 그 조건의
대상이 아니다) 상한이 5 다. 유한성이 구조에서 나오므로 추가 바운드를 두지 않는다.

**이 바운드가 묶는 것은 «밀도»이지 «총량»이 아니다.** 정체 구간 수에는 상한이 없고,
coverage-mapper 가 제안한 derived 차원이 원장에 admit 되면 새 focused 대상이 생겨 새 정체
구간을 낳는 되먹임도 있다. 총량 바운드는 이 판본에 없다(설계 §11 이월).
```

- [ ] **Step 5: 옛 단언을 지우고 GREEN 을 확인한다**

`test_conducting_interview_stage.sh` `179`행의 `has 'coverage_mapper_last_probe' …` 와 `272-274`행의 `covmap_block` 안 `coverage_mapper_last_probe` grep 을 대체한다.

```bash
covmap_block="$(awk '/^## coverage-mapper dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
# 스코프가 필수다 — `stall_episode` 는 State schema 절에도 등장하므로 전-파일 grep 은
# 이 절이 통째로 사라져도 satisfied 된다(feedback_grep_lock_header_satisfiable).
{ grep -q 'coverage_mapper_dispatched_episode' <<<"$covmap_block" \
  && grep -q 'stall_episode' <<<"$covmap_block" \
  && grep -qE '!=' <<<"$covmap_block"; } \
  && ok "C11(v0.37.0): 재dispatch 바운드가 두 에피소드 필드의 비교 (scoped to coverage-mapper dispatch)" \
  || no "C11(v0.37.0): 재dispatch 바운드가 두 에피소드 필드의 비교 (scoped to coverage-mapper dispatch)"
# 조건 2 의 «유한성 근거» — 이것이 없으면 그 조건이 «바운드 밖»인지 «바운드 불필요»인지
# 구별되지 않는다. 지금까지 어디에도 없었다.
grep -qE 'floor 다섯 차원으로 고정|상한이 5' <<<"$covmap_block" \
  && ok "C11(v0.37.0): 조건 2 의 유한성 근거 명시" \
  || no "C11(v0.37.0): 조건 2 의 유한성 근거 명시"
```

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh </dev/null | tail -3`
Expected: `Fail: 0`.

- [ ] **Step 6: mutation — 이 락에 이빨이 있는가**

네 축으로 흔든다(삭제 · 값 · 표기 · 반전). **먼저 커밋한다** — `git checkout --` 는 HEAD 로 되돌리므로 미커밋 편집이 함께 사라진다.

```bash
git add -A && git commit -m "wip: mutation baseline"
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
T=plugins/spec-distill/tests/test_conducting_interview_stage.sh

# M1 삭제 — 절 본문에서 dispatched_episode 를 지운다 → RED 여야 한다
sed -i '' 's/coverage_mapper_dispatched_episode != stall_episode/무진전이 지속되면/' "$SK"
bash "$T" </dev/null | grep -c '✗'   # ≥1 이어야 한다
git checkout -- "$SK"

# M2 반전 — 비교를 `==` 로 뒤집는다 → RED 여야 한다 (`!=` grep 이 잡는다)
sed -i '' 's/coverage_mapper_dispatched_episode != stall_episode/coverage_mapper_dispatched_episode == stall_episode/' "$SK"
bash "$T" </dev/null | grep -c '✗'
git checkout -- "$SK"

# M3 위치 — 절을 통째로 State schema 절로 옮긴다(절 헤딩만 남기고 본문 삭제) → RED
awk '/^## coverage-mapper dispatch/{print; skip=1; next} /^## /{skip=0} !skip' "$SK" > /tmp/m3 && cp /tmp/m3 "$SK"
bash "$T" </dev/null | grep -c '✗'
git checkout -- "$SK"

# M4 양성 대조 — 아무것도 안 바꾸면 GREEN 이어야 한다 (계측기가 살아 있는가)
bash "$T" </dev/null | tail -1
```
Expected: M1·M2·M3 각각 `✗` 1건 이상, M4 는 `Fail: 0`. **M4 가 GREEN 이 아니면 앞의 RED 들은 증거가 아니다** — 계측기가 이미 고장 난 것이다.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): coverage-mapper 바운드를 에피소드 필드 둘로 이식"
```

### Task 5: floor 탈출구 — 사용자 발화 → 박제

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## 종료` 절 `344-358`)
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: 없음
- Produces: 어휘 `사용자-승인 박제` — Task 6 이 probe 백스톱 블록을 지울 때 3옵션 단언의 대체다

- [ ] **Step 1: 왜 이 대체가 필요한지 확인한다**

Run:
```bash
sed -n '/^## probe 백스톱/,/^## coverage-mapper/p' \
  plugins/spec-distill/skills/conducting-interview/SKILL.md | grep -c '박제'
grep -n 'backstop_block' plugins/spec-distill/tests/test_conducting_interview_stage.sh
```
Expected: 박제 어휘가 probe 백스톱 절 안에 있고, `backstop_block` awk 윈도우로 스코프된 3옵션 단언(`계속`/`박제`/`abort`)이 존재. **그 단언이 리포에서 floor escalation 탈출구를 잠그는 유일한 기계 단언이다.**

- [ ] **Step 2: 대체 단언을 먼저 쓴다 (RED 를 만든다)**

`test_conducting_interview_stage.sh` 에서 `backstop_block` 단언들 **아래**에:

```bash
# v0.37.0: probe cap 이 사라지면 그 escalation 의 3옵션도 함께 사라진다. 새 탈출구는
# 발동 조건만 다르고(카운터 → 사용자 발화) 존재해야 하는 것은 같다.
#
# **awk 윈도우로 스코프한다** — `박제` 어휘가 이 파일의 다른 절(Step B 게이트 안내 ·
# kill switch)에도 선재하므로 전-파일 grep 은 이 경로가 통째로 사라져도 satisfied 되어
# teeth 가 0 이다(feedback_grep_lock_header_satisfiable, 같은 파일의 backstop_block 이
# 같은 이유로 스코프됐다).
exit_block="$(awk '/^## 종료 — brief 작성/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ grep -qE '사용자.*종료를 요청|사용자가 언제든 종료' <<<"$exit_block" \
  && grep -q '박제' <<<"$exit_block" \
  && grep -qE 'floor' <<<"$exit_block"; } \
  && ok "C1(v0.37.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (scoped to 종료)" \
  || no "C1(v0.37.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (scoped to 종료)"
```

- [ ] **Step 3: RED 를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh </dev/null | grep -E 'floor 탈출구|Fail'`
Expected: `✗ C1(v0.37.0): floor 탈출구 …`, `Fail: 1`.

- [ ] **Step 4: SKILL 의 `## 종료` 절에 탈출구를 쓴다**

`## 종료 — brief 작성 + optional handoff` 절, `읽어야 하는 조건:` 문장 **앞**에:

```markdown
### 나가는 문은 floor 뒤에만 있지 않다

floor 다섯이 전부 `closed` 여야 종료가 열리지만, **사용자는 언제든 종료를 요청할 수 있다.**
그때 미충족 floor 는 **사용자-승인 박제**로 닫는다 — 그 차원의 `evidence` 에
`사용자-승인 박제(@사용자 종료 요청) — §Open Questions 참조` 를 적고, 그 내용을 payload
§3 Open Questions 로 이월한다. 박제 표식이 원장에 남으므로 silent bypass 가 아니다.

발동 조건이 카운터가 아니라 **사용자 발화**라는 점만 예전 escalation 과 다르다. 상한을
없애는 것과 탈출구를 없애는 것은 다르다 — 없애는 것은 사용자 질문의 상한이지 나가는 문이
아니다.
```

- [ ] **Step 5: `finishing.md` 에 같은 경로를 쓴다**

`finishing.md` 는 종료 절차의 정본이다. floor 박제로 닫힌 차원이 payload §3 로 가는 경로를 여기에도 적는다(SKILL 은 조건을, `finishing.md` 는 절차를 담는다).

```markdown
**사용자-승인 박제로 닫힌 floor** — `evidence` 가 `사용자-승인 박제` 로 시작하는 차원은
그 내용을 payload `## 3. Open Questions` 에 한 항목으로 옮긴다. 박제된 차원은 「닫혔다」가
아니라 「사용자가 지금은 안 하기로 했다」이므로, 다음 단계가 그것을 열린 질문으로 본다.
```

- [ ] **Step 6: GREEN 확인 + `finishing.md` 를 코퍼스로 삼는 7건**

Run:
```bash
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh </dev/null | tail -2
for t in plugins/quality-gates/tests/test_law2_prose.sh \
         plugins/spec-distill/tests/test_brief_review_entry.sh \
         plugins/spec-distill/tests/test_no_wall_clock.sh \
         plugins/spec-distill/tests/test_proceed_gate_adopters.sh \
         plugins/spec-distill/tests/test_web_kill_switch.sh \
         shared/tests/test_skill_reference_pointers.sh; do
  bash "$t" </dev/null >/dev/null 2>&1 || echo "FAIL $t"
done
```
Expected: 첫 명령 `Fail: 0`, 두 번째 출력 없음.

- [ ] **Step 7: mutation — awk 윈도우가 실제로 이빨을 주는가**

```bash
git add -A && git commit -m "wip: mutation baseline"
SK=plugins/spec-distill/skills/conducting-interview/SKILL.md
T=plugins/spec-distill/tests/test_conducting_interview_stage.sh

# M5 — `## 종료` 절에서 탈출구 소절만 지운다 → RED. (전-파일 grep 이었다면 GREEN 이다:
#      `박제` 가 다른 절에 살아 있기 때문. 이것이 스코프의 이빨을 재는 변이다.)
awk '/^### 나가는 문은 floor 뒤에만/{skip=1} /^## /{skip=0} !skip' "$SK" > /tmp/m5 && cp /tmp/m5 "$SK"
bash "$T" </dev/null | grep -c '✗'
git checkout -- "$SK"

# M6 양성 대조 — 스코프를 «전-파일» 로 되돌리고 M5 를 다시 하면 GREEN 이 되는가.
#     GREEN 이면 스코프가 이빨의 출처임이 증명된다. 확인 후 즉시 되돌린다.
sed -i '' 's/<<<"\$exit_block"/"${CI_ALL[@]}"/g' "$T"
awk '/^### 나가는 문은 floor 뒤에만/{skip=1} /^## /{skip=0} !skip' "$SK" > /tmp/m6 && cp /tmp/m6 "$SK"
bash "$T" </dev/null | grep -c 'floor 탈출구.*✗'
git checkout -- "$SK" "$T"
```
Expected: M5 는 `✗` 1건 이상, M6 는 `0`(전-파일이면 안 잡힌다). **M6 가 0 이 아니면 스코프가 이빨의 출처가 아니므로 다른 어휘를 골라야 한다.**

- [ ] **Step 8: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md \
        plugins/spec-distill/skills/conducting-interview/references/finishing.md \
        plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "feat(spec-distill): floor 탈출구를 사용자 발화 → 박제 경로로"
```

### Task 6: probe 스윕 삭제 + 잔존 단측 락

**Files:**
- Delete: `plugins/spec-distill/scripts/probe_budget.py` · `plugins/spec-distill/tests/test_probe_budget.sh` · `plugins/spec-distill/tests/fixtures/state-probe-at-cap.md` · `plugins/spec-distill/tests/fixtures/state-probe-within.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`## probe 백스톱` 절 삭제 · State schema · migration 절)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`
- Create: `plugins/spec-distill/tests/test_probe_sweep_residue.sh`

**Interfaces:**
- Consumes: Task 4 의 에피소드 필드 · Task 5 의 탈출구 (둘 다 이미 green 이어야 한다)
- Produces: 없음

- [ ] **Step 1: 완결성 oracle 을 돌려 대상을 확정한다**

Run:
```bash
git grep -lE 'probe_budget|probe_count|probe_cap|effective_cap|raise-cap|PROBE_CAP|coverage_mapper_last_probe' \
  -- plugins/spec-distill | grep -v 'tests/fixtures/'
```
Expected (2026-08-27 실측, 비-픽스처 **10건**):
```
plugins/spec-distill/CHANGELOG.md
plugins/spec-distill/README.md
plugins/spec-distill/scripts/brief_review_state.py
plugins/spec-distill/scripts/probe_budget.py
plugins/spec-distill/skills/conducting-interview/SKILL.md
plugins/spec-distill/templates/interview-audit-template.md
plugins/spec-distill/tests/test_brief_review_state.py
plugins/spec-distill/tests/test_conducting_interview_stage.sh
plugins/spec-distill/tests/test_probe_budget.sh
plugins/spec-distill/tests/test_readme_sync.sh
```
픽스처 **61건**. **목록이 다르면 이 태스크를 멈추고 다시 도출한다** — 손으로 적은 목록을 믿지 않는다.

> `brief_review_state.py` · `test_brief_review_state.py` 가 걸리는 것은 카운터를 쓰기 때문이 아니라 **삭제되는 파일을 산문으로 인용**하기 때문이다(실측: 러너 `:18`·`:82` 의 규율 인용, 테스트 `:22` 의 픽스처 문자열). 둘 다 고친다 — 남기면 **삭제된 규칙을 가리키는 거짓 인용**이 된다.

- [ ] **Step 2: 잔존 락을 먼저 쓴다**

Create `plugins/spec-distill/tests/test_probe_sweep_residue.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# probe 상한 스윕의 **완결성**을 잰다 — 단측 단언이다.
#
# 완료 조건: 아래 별칭 oracle 의 출력에 `tests/fixtures/` 와 `CHANGELOG.md` **밖** 경로가
# 0건. 집합 일치가 아니라 단측인 이유와 두 제외의 이유를 여기 함께 적는다 — **이유 없는
# 면제 목록은 그 질문을 영구히 닫는다.**
#
#  · `tests/fixtures/` 제외 — audit 템플릿의 `## 2. Budget` 절을 **삭제하지 않기로** 한
#    비용 판단의 결과다(절을 지우면 `check_brief.py` 의 `AUDIT_SECTIONS` 와 픽스처
#    61건이 함께 스윕 대상이 된다). 절은 남기고 본문만 바꾼다. 대가는 «삭제된 개념을
#    계속 인용하는 픽스처가 락으로 굳는 것»이고, 그 대가를 알고 치른다.
#  · `CHANGELOG.md` 제외 — **지울 수 없는 과거 릴리스 이력**이다. 빼지 않으면 이 락은
#    원리적으로 green 이 될 수 없고, 무엇보다 **이 스윕 자신의 `Removed: probe_budget.py`
#    엔트리가 락을 RED 로 만든다.** 락을 만족시키는 커밋이 락을 깨뜨리는 형태다.
#
# 집합 «일치»로 잠그지 않는 이유: 픽스처 61건 중 `state-probe-at-cap.md` 와
# `state-probe-within.md` 둘은 audit 픽스처가 아니라 삭제 대상 `test_probe_budget.sh`
# 전용 state 픽스처라 함께 지워지는 것이 옳다(잔존이 59 가 된다). 일치로 잠그면 그
# 올바른 정리에 거짓 RED 가 난다. 단측은 판별력이 같고 그 부작용이 없다.
#
# 이 oracle 이 못 보는 것(알려진 채로 남긴다): grep 은 산문 언급을 찾지 **구조화된
# 상수**를 못 본다. `check_brief.py` 의 `AUDIT_SECTIONS` 는 절 제목을 튜플 원소로 들고
# 있어 `## 2. Budget` 패턴에 안 걸린다. 위의 «절을 삭제하지 않는다» 결정이 이 사각지대를
# 무해하게 만든다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

ALIAS_RE='probe_budget|probe_count|probe_cap|effective_cap|raise-cap|PROBE_CAP|coverage_mapper_last_probe'
SCOPE='plugins/spec-distill'

if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- "$SCOPE"
  exit 0
fi

# vacuity 하한 — 코퍼스가 비면 「잔존 0」이 「안 봤다」가 된다.
corpus_n="$(git ls-files -- "$SCOPE" | wc -l | tr -d ' ')"
if [ "${corpus_n:-0}" -lt 1 ]; then
  no "코퍼스가 0건 — 이 검사가 vacuous 하다"
  finish; exit $?
fi
ok "코퍼스 ${corpus_n}개 파일 (vacuous 아님)"

# 양성 대조 — oracle 자체가 살아 있는가. 별칭이 «어딘가에는» 남아 있어야 한다
# (픽스처). 0건이면 정규식이 깨진 것이지 스윕이 완벽한 것이 아니다.
all_hits="$(git grep -lE "$ALIAS_RE" -- "$SCOPE" | wc -l | tr -d ' ')"
if [ "${all_hits:-0}" -lt 1 ]; then
  no "양성 대조: 별칭이 리포 어디에도 0건 — 정규식이 깨졌다 (스윕 완벽과 구별 불가)"
  finish; exit $?
fi
ok "양성 대조: 별칭 총 ${all_hits}건 (정규식 살아 있음)"

residue="$(git grep -lE "$ALIAS_RE" -- "$SCOPE" \
  | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG\.md$' || true)"
n=0
while IFS= read -r f; do [ -n "$f" ] && n=$((n + 1)); done <<< "$residue"
if [ "$n" -eq 0 ]; then
  ok "잔존 0건 (tests/fixtures/ 와 CHANGELOG.md 제외 — 위 헤더에 각각의 이유)"
else
  printf '%s\n' "$residue" | while IFS= read -r f; do
    [ -n "$f" ] && echo "     잔존: $f"
  done
  no "probe 별칭 잔존 ${n}건 — 스윕이 끝나지 않았다"
fi

finish
```

- [ ] **Step 3: RED 를 확인한다**

Run: `bash plugins/spec-distill/tests/test_probe_sweep_residue.sh </dev/null | tail -12`
Expected: `잔존: …` 여러 줄 + `✗ probe 별칭 잔존 8건` (`CHANGELOG.md` 와 픽스처를 뺀 나머지).

- [ ] **Step 4: 파일 넷을 지운다**

```bash
git rm plugins/spec-distill/scripts/probe_budget.py \
       plugins/spec-distill/tests/test_probe_budget.sh \
       plugins/spec-distill/tests/fixtures/state-probe-at-cap.md \
       plugins/spec-distill/tests/fixtures/state-probe-within.md
```

- [ ] **Step 5: 남은 6건에서 별칭을 제거한다**

| 파일 | 무엇 |
|---|---|
| `skills/conducting-interview/SKILL.md` | `## probe 백스톱 (C1/C10 …)` 절 **통째로 삭제**(`173-218`). State schema 의 `probe_count` · `probe_cap_override` 줄 삭제. migration 절의 `probe_count: **0**` · `probe_cap_override: 0` 항목 삭제 및 advisory 문면 교체. kill switch 절의 `DEVBREW_SPEC_DISTILL_PROBE_CAP` 삭제 |
| `templates/interview-audit-template.md` | `## 2. Budget` **본문 교체** — Task 7 |
| `tests/test_conducting_interview_stage.sh` | `175`·`176`·`179`행 schema 단언 · `189`·`191-193` migration 단언 · `196-214` 백스톱 단언 · `216-230` `backstop_block` 블록 삭제 |
| `tests/test_readme_sync.sh` | `probe_budget.py` 를 스크립트 목록에서 제거 |
| `README.md` | probe 상한 서술 삭제 |
| `scripts/brief_review_state.py` | **거짓 인용이 된다 — 고친다.** `:18` 과 `:82` 가 *"fail-closed 규율은 `probe_budget.py`와 동일하다"* · *"probe_budget.py의 '존재하지만 비-정수 → ValueError' 규율과"* 로 **삭제되는 파일을 규율의 출처로 인용**한다(2026-08-27 실측). 파일이 사라지면 그 인용은 존재하지 않는 것을 가리킨다 |
| `tests/test_brief_review_state.py` | `:22` 의 state 픽스처 문자열에 `probe_count: 0` 이 있다. 스키마에서 그 필드가 사라지므로 픽스처에서도 뺀다 |

migration advisory 의 새 문면:

```
[spec-distill v0.37.0] state schema migration: coverage/orchestration added (probe counters retired).
```

- [ ] **Step 6: 거짓 인용 3건을 고친다**

Run:
```bash
grep -nE 'probe_budget|probe_count' \
  plugins/spec-distill/scripts/brief_review_state.py \
  plugins/spec-distill/tests/test_brief_review_state.py
```
Expected (2026-08-27 실측 — 정확히 3건):
```
scripts/brief_review_state.py:18:fail-closed 규율은 `probe_budget.py`와 동일하다: state가 unreadable/absent이면
scripts/brief_review_state.py:82:    fail-closed다(ValueError) — probe_budget.py의 '존재하지만 비-정수 → ValueError' 규율과
tests/test_brief_review_state.py:22:probe_count: 0
```

앞 둘은 **삭제되는 파일을 규율의 출처로 인용**한다. 파일이 사라지면 인용이 존재하지 않는 것을 가리키므로, 규율 자체를 그 자리에 옮겨 적는다 — 출처를 다른 살아 있는 파일로 바꾸지 않는다(그러면 같은 문제가 그 파일이 사라질 때 재발한다).

`:18` 대체:
```
fail-closed 규율: state가 unreadable/absent이면 silent-create 하지 않고 exit 1 + JSON 으로
사유를 낸다. 「기록이 없다」와 「degrade 가 없다」는 다른 사실이므로, 쓰기 실패를 조용히
삼키면 원장이 비어 있는 것이 «깨끗함»으로 읽힌다.
```

`:82` 대체:
```
    fail-closed다(ValueError) — 존재하지만 비-정수인 값은 0 으로 강등하지 않는다. 강등하면
    손상된 원장이 정상 원장과 구별되지 않는다.
```

`test_brief_review_state.py:22` 는 픽스처 문자열에서 `probe_count: 0` 줄을 뺀다.

Run: `python3 -m unittest plugins.spec-distill.tests.test_brief_review_state`
Expected: OK.

- [ ] **Step 7: 잔존 락 GREEN + 전수 확인**

Run:
```bash
bash plugins/spec-distill/tests/test_probe_sweep_residue.sh </dev/null | tail -3
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh </dev/null | tail -2
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh </dev/null | tail -2
```
Expected: 셋 다 `Fail: 0`.

- [ ] **Step 8: mutation — 단측 락에 이빨이 있는가**

```bash
git add -A && git commit -m "wip: mutation baseline"
T=plugins/spec-distill/tests/test_probe_sweep_residue.sh

# M7 «놓친 1» 을 심는다 → RED 여야 한다
echo "# probe_count 는 v0.37.0 에서 제거됐다" >> plugins/spec-distill/README.md
bash "$T" </dev/null | grep -c '✗'
git checkout -- plugins/spec-distill/README.md

# M8 «제외를 넓힌다» → 위 M7 을 다시 심어도 GREEN 이 되면 제외가 이빨을 먹은 것이다
sed -i '' "s|grep -v 'CHANGELOG\\\\.md\$'|grep -v 'CHANGELOG\\\\.md$' \| grep -v 'README'|" "$T"
echo "# probe_count" >> plugins/spec-distill/README.md
bash "$T" </dev/null | grep -c '✗'
git checkout -- "$T" plugins/spec-distill/README.md

# M9 양성 대조 하한 — 별칭 정규식을 깨뜨린다 → «잔존 0» 이 아니라 RED 여야 한다
sed -i '' "s/ALIAS_RE='probe_budget/ALIAS_RE='zzz_no_such_token/" "$T"
bash "$T" </dev/null | grep -c '양성 대조.*✗'
git checkout -- "$T"
```
Expected: M7 은 `✗` ≥1, M8 은 `0`(제외가 이빨을 먹는다는 증명), M9 는 `1`. **M9 가 0 이면 정규식이 깨져도 「잔존 0」으로 읽히는 fail-open 이다.**

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(spec-distill): probe 상한 삭제 + 잔존 단측 락"
```

### Task 7: Budget 절 본문 교체 + `finishing.md` 원문 보존

**Files:**
- Modify: `plugins/spec-distill/templates/interview-audit-template.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md`

**Interfaces:**
- Consumes: Task 6 의 스윕
- Produces: audit `## 2. Budget` 의 새 본문 형식

- [ ] **Step 1: 현재 본문을 읽는다**

Run: `sed -n '/^## 2\. Budget/,/^## /p' plugins/spec-distill/templates/interview-audit-template.md`
Expected: `- probe_count: <n> / cap <n>` 한 줄. cap 이 사라지면 빈 의례가 남는다.

- [ ] **Step 2: 본문을 교체한다**

절 제목(`## 2. Budget`)은 **그대로 둔다** — `check_brief.py` 의 `AUDIT_SECTIONS` 가 절 제목을 튜플 원소로 들고 있고, 픽스처 61건이 그 문자열을 담고 있다.

```markdown
## 2. Budget

- 질문 라운드: <n> · agent dispatch: <n> · codex 실호출: <n> (성공 <n>)
```

상한이 아니라 **지출 기록**이다. 상한을 두지 않는다는 결정과 충돌하지 않는다 — 얼마나 태웠는지는 남기고, 얼마까지만 태우라는 말을 하지 않는다.

- [ ] **Step 3: `finishing.md` 에 최초 요청 원문 보존을 요구로 넣는다**

**지금 `finishing.md` 는 §6 를 `user_statements` 에서만 채우고 `$ARGUMENTS`(최초 요청)는 거기 들어가지 않는다.** 게이트 15항 어디에도 원문 보존 요구가 없고, 지금까지 보존된 것은 관례였다.

§6 작성 지시 부분에:

```markdown
**최초 요청 원문은 `S1` 이다.** `$ARGUMENTS`(사용자가 `/interview` 에 함께 넘긴 rough
request)를 `user_statements` 의 첫 항목과 **같은 형식**으로 §6 맨 앞에 넣는다:

```yaml
- id: S1
  source: verbatim
  round: 0
  text: "<$ARGUMENTS 원문 그대로>"    # P21 secret placeholder 치환 적용
```

비어 있으면(인자 없이 호출) `S1` 을 만들지 않고 `S2` 부터 시작하지 않는다 — 번호는
`user_statements` 의 순서를 따르고, 최초 요청이 없으면 첫 사용자 답변이 `S1` 이다.

원문 보존은 **관례가 아니라 요구**다. 지금까지 게이트 15항 어디에도 이 요구가 없어서,
보존되지 않은 인터뷰가 나와도 아무것도 RED 가 되지 않았다.
```

- [ ] **Step 4: 픽스처가 깨지지 않는지 확인**

Run:
```bash
bash plugins/spec-distill/tests/test_check_brief.sh </dev/null | tail -2
bash plugins/spec-distill/tests/test_brief_review_ng3.sh </dev/null | tail -2
bash plugins/spec-distill/tests/test_check_verbatim_coverage.sh </dev/null | tail -2
```
Expected: 셋 다 `Fail: 0`. **`AUDIT_SECTIONS` 가 절 제목만 보므로 본문 교체는 게이트를 건드리지 않는다** — 이것이 절을 남기기로 한 이유다.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/templates/interview-audit-template.md \
        plugins/spec-distill/skills/conducting-interview/references/finishing.md
git commit -m "feat(spec-distill): Budget 절을 지출 기록으로 + 최초 요청 원문 보존 요구"
```

### Task 8: brief `[미평가]` 라벨 + 문서 동기화 + bump

**Files:**
- Modify: `docs/superpowers/interview/2026-08-22-request-framing-phase0-interview.md`
- Modify: `plugins/spec-distill/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 4–7
- Produces: 없음 (PR1 의 마무리)

- [ ] **Step 1: 라벨 실측**

Run:
```bash
grep -n '\[미평가\]\|\[중립·미평가\]' \
  docs/superpowers/interview/2026-08-22-request-framing-phase0-interview.md
```
Expected: 순수 `[미평가]` **4건** + 합성 `[중립·미평가]` 1건 (2026-08-27 실측).

**이것은 게이트 위반이 아니다** — `check_brief.py` 에 라벨 검사가 없다. 템플릿이 `[취함|피함|중립]` 셋만 규정하므로 이탈일 뿐이다. 재구조화와 무관한 독립 수정이라 여기서 처리한다.

- [ ] **Step 2: 각 항목을 셋 중 하나로 판정한다**

`[미평가]` 를 기계적으로 `[중립]` 으로 바꾸지 않는다. 각 landscape 항목이 이 설계에서 **실제로 취해졌는지 · 피해졌는지 · 중립인지**를 §5·§9 에 대고 판정해서 적는다. 판정할 근거가 없으면 그 항목을 §3 Open Questions 로 옮긴다.

- [ ] **Step 3: README flow 동기화**

`plugins/spec-distill/README.md` 에서 probe 상한 서술을 지우고, 종료 조건이 「floor 5 전부 closed **또는** 사용자 종료 요청 시 미충족 floor 를 사용자-승인 박제」임을 반영한다. `request-framing` 은 **아직 언급하지 않는다** — PR3 에서 들어온다.

- [ ] **Step 4: bump + CHANGELOG**

`version` `0.36.0` → `0.37.0`.

```markdown
## [0.37.0] — 2026-08-27

### Removed
- `scripts/probe_budget.py` 와 그 전용 테스트·픽스처. 인터뷰 질문·라운드에 상한을 두지 않는다 — 질문 루프는 매 반복마다 사용자가 답해야 돌므로 묶을 자율이 없다.
- `DEVBREW_SPEC_DISTILL_PROBE_CAP` kill switch (대상이 사라졌다).

### Changed
- coverage-mapper 재dispatch 바운드를 `probe_count` 단위에서 **에피소드 필드 둘**(`stall_episode` · `coverage_mapper_dispatched_episode`)로 이식. 판정은 여전히 디스크 두 값의 비교이며 한 정체 구간당 1회다.
- floor 탈출구의 발동 조건이 카운터에서 **사용자 발화**로. 미충족 floor 는 사용자-승인 박제로 닫고 payload §3 로 이월한다.
- audit `## 2. Budget` 절의 본문이 상한에서 **지출 기록**으로.

### Added
- `finishing.md` 에 최초 요청 원문(`$ARGUMENTS`)을 §6 `S1` 로 보존하는 요구. 지금까지는 관례였다.
- `tests/test_probe_sweep_residue.sh` — 스윕 완결성의 단측 단언.
```

- [ ] **Step 5: PR1 전수 확인**

Run: [착수 전 실측 ②](#-락--pr-행렬-도출) 의 전수 스크립트.
Expected: `FAIL plugins/spec-distill/tests/test_hook_output_schema.py` 한 줄만.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs(spec-distill): brief 라벨 판정 + README 동기화 + v0.37.0"
```

---
## PR2 — 원장 writer 재사용 준비 (`0.38.0`)

**설계의 PR2 는 두 항목이었고 하나가 이미 main 에 있다**(재결정 R1). `run_spec_codex_reviewer.sh` 의 맨 `${CLAUDE_PLUGIN_ROOT}` 는 `c732ddd`(PR #130)가 세 러너에 fallback 을 이식하면서 해소됐다 — 현재 `:32` 가 `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"` 다. **이 PR 에서 그 파일을 건드리지 않는다.**

남는 것은 하나뿐이라 PR2 는 태스크 하나다. **그래도 PR3 에 합치지 않는다** — 원장 writer 의 확장은 request-framing 본체 없이도 단독으로 옳고, 섞으면 「각 PR 단독 green」을 검증할 때 무엇이 깨뜨렸는지 가려진다.

### Task 9: `brief_review_state.py` `--ledger-key` + `AXES` 확장

**Files:**
- Modify: `plugins/spec-distill/scripts/brief_review_state.py` (`42`행 `AXES` · `48`행 `KEY_DEGRADE`)
- Modify: `plugins/spec-distill/tests/test_brief_review_state.py`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: 없음
- Produces: CLI `--ledger-key <key>`(기본값 `brief_review_degradations`) · `AXES` 에 `suppression` — PR3 의 `framing-requests/SKILL.md` 가 `--ledger-key framing_degradations --axis suppression` 으로 호출한다

- [ ] **Step 1: 현재 상수를 확인한다**

Run:
```bash
sed -n '40,50p' plugins/spec-distill/scripts/brief_review_state.py
```
Expected:
```python
AXES = ("fidelity", "direction", "readback", "completeness", "all")
...
KEY_DEGRADE = "brief_review_degradations"
```

**이 `AXES` 는 degrade 원장의 `affected_axis` 닫힌 열거다.** 같은 이름이 `build_brief_codex_prompt.py:42` 에도 있는데 그것은 **codex 프롬프트 축**(축마다 체크리스트 파일이 실재해야 한다)이고, `run_brief_codex_reviewer.sh:79-81` 의 `case … exit 2` 는 **실제 fail-point** 다. 셋은 이름만 같고 뜻이 다르다 — **parity 락을 세우지 마라.** 술어 자체가 거짓이 된다.

- [ ] **Step 2: 실패하는 테스트를 먼저 쓴다**

`plugins/spec-distill/tests/test_brief_review_state.py` 에:

```python
    def test_ledger_key_override_writes_to_named_key(self):
        """--ledger-key 가 주어지면 그 키에 append 한다 (기본값은 불변)."""
        state = self._make_state(extra="framing_degradations: []\n")
        rc = self._run(["degrade-append", state, "--component", "critic",
                        "--axis", "suppression", "--status", "degraded",
                        "--reason", "codex 미가동",
                        "--ledger-key", "framing_degradations"])
        self.assertEqual(rc, 0)
        text = pathlib.Path(state).read_text(encoding="utf-8")
        self.assertIn("framing_degradations:", text)
        self.assertIn("suppression", text)
        # 기본 키는 건드리지 않는다 — 두 원장이 서로를 오염시키지 않는다.
        self.assertNotIn("suppression", text.split("brief_review_degradations:")[1]
                         .split("framing_degradations:")[0])

    def test_suppression_is_a_valid_axis(self):
        """AXES 에 suppression 이 없으면 seed 억제 축의 degrade 를 기록할 수 없다."""
        from importlib import import_module
        mod = import_module("plugins.spec-distill.scripts.brief_review_state".replace("-", "_"))
        self.assertIn("suppression", mod.AXES)

    def test_unknown_ledger_key_is_rejected(self):
        """임의 키 생성 금지 — 오타가 조용히 새 원장을 만들면 아무도 안 읽는다."""
        state = self._make_state()
        rc = self._run(["degrade-append", state, "--component", "critic",
                        "--axis", "suppression", "--status", "degraded",
                        "--reason", "x", "--ledger-key", "typo_degradations"])
        self.assertEqual(rc, 1)
```

**세 번째가 중요하다.** `--ledger-key` 를 자유 문자열로 두면 오타가 새 원장을 만들고, 그 원장은 아무 소비자도 읽지 않아 **degrade 가 기록됐는데 아무에게도 안 닿는다**. 허용 키를 닫힌 열거로 둔다.

- [ ] **Step 3: RED 확인**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins.spec-distill.tests.test_brief_review_state -v 2>&1 | tail -12`
Expected: 새 테스트 3건 FAIL/ERROR.

- [ ] **Step 4: 구현**

```python
AXES = ("fidelity", "direction", "readback", "completeness", "suppression", "all")

KEY_DEGRADE = "brief_review_degradations"
# 원장 키의 **닫힌 열거**. 자유 문자열로 두면 오타가 새 원장을 만들고, 그 원장은 어떤
# 소비자도 읽지 않아 degrade 가 기록됐는데 아무에게도 안 닿는다 — 침묵보다 나쁘다
# (기록이 있으니 됐다고 믿게 만든다).
LEDGER_KEYS = (KEY_DEGRADE, "framing_degradations")
```

`degrade-append` 의 argparse 에:
```python
    p.add_argument("--ledger-key", default=KEY_DEGRADE, choices=LEDGER_KEYS,
                   help="degrade 원장 키. 기본값은 brief 파이프라인의 것")
```

그리고 `KEY_DEGRADE` 를 리터럴로 쓰는 자리를 **읽기 1곳·쓰기 1곳**으로 모아 인자를 받게 한다. 리터럴이 흩어져 있으면 한 곳만 고쳐도 «키를 넘겼는데 다른 키를 읽는» 상태가 되고, 그때 원장은 비어 보인다.

Run: `grep -n 'KEY_DEGRADE\|brief_review_degradations' plugins/spec-distill/scripts/brief_review_state.py`
→ 각 히트가 (a) 상수 정의 (b) 기본값 (c) 파라미터화된 읽기/쓰기 중 하나여야 한다. **리터럴 하드코딩이 남으면 그 자리가 버그다.**

- [ ] **Step 5: GREEN 확인 + 회귀**

Run:
```bash
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest plugins.spec-distill.tests.test_brief_review_state 2>&1 | tail -3
python3 -m unittest plugins.spec-distill.tests.test_yaml_scalar_single_definition 2>&1 | tail -3
bash plugins/spec-distill/tests/test_brief_review_meta.sh </dev/null | tail -2
bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh </dev/null | tail -2
```
Expected: 넷 다 통과.

- [ ] **Step 6: mutation**

```bash
git add -A && git commit -m "wip: mutation baseline"
S=plugins/spec-distill/scripts/brief_review_state.py

# M10 — choices 를 없애 자유 문자열로 만든다 → 오타 테스트가 RED 여야 한다
sed -i '' 's/, choices=LEDGER_KEYS//' "$S"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins.spec-distill.tests.test_brief_review_state 2>&1 | tail -3
git checkout -- "$S"

# M11 — 쓰기만 파라미터화하고 읽기는 리터럴로 되돌린다 → 첫 테스트가 RED 여야 한다
#      («키를 넘겼는데 다른 키를 읽는» 상태를 실제로 만들어 본다)
# 이 변이는 손으로 한다 — 읽기 지점의 이름이 구현에 달렸다. 되돌린 뒤 반드시 재확인.

# M12 양성 대조 — 아무것도 안 바꾸면 GREEN
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins.spec-distill.tests.test_brief_review_state 2>&1 | tail -1
```
Expected: M10·M11 은 FAIL 을 내고, M12 는 `OK`.

- [ ] **Step 7: bump + CHANGELOG**

`version` `0.37.0` → `0.38.0`.

```markdown
## [0.38.0] — 2026-08-27

### Added
- `scripts/brief_review_state.py` 에 `--ledger-key`(닫힌 열거: `brief_review_degradations` · `framing_degradations`). 다른 파이프라인이 같은 writer 로 자기 원장에 쓴다.
- `AXES` 에 `suppression` — seed 억제 축의 degrade record 를 위한 `affected_axis` 값.
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(spec-distill): degrade 원장 writer 를 --ledger-key 로 재사용 가능하게 (v0.38.0)"
```

---

## PR3 — request-framing 본체 (`0.39.0`)

**이 PR 이 통째로 하나인 이유**: `shared/tests/test_dispatch_disposition.sh` 의 `ZERO_AGENTS` 단언이 *"dispatch 0건인 에이전트가 없다"* 를 요구한다. `seed-critic.md` · `seed-readback.md` 를 만들면 **그것을 dispatch 하는 skill 이 같은 커밋에** 있어야 한다. agent 정의만 먼저 넣는 분해가 구조적으로 불가능하다.

**이 PR 이 통과해야 하는 새 계약 넷** (설계 시점에 없던 것들):

| 계약 | 요구 |
|---|---|
| `test_skill_reference_pointers.sh` | 새 `references/*.md` 둘이 **고아가 아니어야** 한다. 포인터 출처는 `SKILL.md` ∪ `references/*.md` — `commands/*.md` 는 출처가 아니다 |
| `test_dispatch_disposition.sh` | dispatch 2곳에 `**처분**` 앵커 · agent 2 의 dispatch ≥1 |
| `test_no_new_duplication.sh` | 20줄 이상 동일 블록 금지(미추적 새 파일 포함) |
| `test_guards_coverage_bidirectional.sh` | 새 락 6종에 `# guards:` + `--emit-scanned` |

### Task 10: `compression.md` + `trivia-escape.md` + 채택자 락

**Files:**
- Create: `plugins/spec-distill/references/compression.md`
- Create: `plugins/spec-distill/references/trivia-escape.md`
- Create: `plugins/spec-distill/tests/test_compression_adopters.sh`

**Interfaces:**
- Consumes: `P23` (PR0 Task 1)
- Produces: 두 정본 경로 — Task 11 의 SKILL 이 셋 다(`proceed-gate.md`·`compression.md`·`trivia-escape.md`) 가리킨다

> **재결정 R3 — `trivia-escape.md` 의 포인터 출처**
>
> 설계는 *"두 command 가 포인터로 가리킨다"* 로 정했다. **그러면 그 파일은 고아가 되어 RED 다** — `shared/tests/test_skill_reference_pointers.sh` 의 포인터 출처 코퍼스가 `plugins/*/skills/*/SKILL.md` ∪ `plugins/*/skills/*/references/*.md` ∪ `plugins/*/references/*.md` 뿐이고 `commands/*.md` 가 없다. 이 락은 설계 작성 이후 main 에 들어왔다.
>
> **검토한 셋과 기각 사유:**
>
> | 대안 | 왜 안 하나 |
> |---|---|
> | 추출하지 않고 두 command 에 각각 쓴다 | `interview.md` 의 Step 1(kill switch) + Step 2(trivia)가 연속 **27줄**이고 `request-framing.md` 가 같은 구조를 쓰면 그 구간이 통째로 동일해진다 — `test_no_new_duplication.sh` 의 창 20줄 · 최소 200자를 넘긴다 |
> | `conducting-interview/SKILL.md` 가 가리키게 한다 | 그 skill 은 trivia escape 를 하지 않는다(command 가 한다). 락을 만족시키려고 쓰는 포인터는 **코퍼스를 락에 맞춰 고치는 것**이지 불변식을 재는 것이 아니다 |
> | `compression.md` 가 가리키게 한다 | 플러그인 레벨 파일 둘이 서로만 가리키는 **상호 보증**이 된다. 락 헤더가 *"둘째를 추가한다면 그때 도달성으로 올릴지 결정할 것"* 이라고 명시적으로 예고한 구멍이다 |
>
> **채택**: `framing-requests/SKILL.md` 가 가리킨다 + command 포인터도 유지한다. 그 skill 이 *"command 가 trivia escape 를 통과시킨 요청만 받는다"* 는 **자기 진입 선결조건**을 적는 것은 장식이 아니라 실제 계약이다. NG6(*"trivia escape 는 command 의 책임"*)도 깨지 않는다 — **검사**는 여전히 command 가 하고 skill 은 정의를 인용할 뿐이다.

- [ ] **Step 1: 채택자 락을 먼저 쓴다**

Create `plugins/spec-distill/tests/test_compression_adopters.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/*/references/*.md
#
# 압축 규약의 **채택자 대칭** — `references/compression.md` 를 채택한 skill 이 자기 표면에
# 압축 어휘를 갖는가. `test_proceed_gate_adopters.sh` 와 같은 골격이되 하한이 다르다.
#
# ── 하한이 2 가 아니라 1 인 이유 ────────────────────────────────────────────
# 형제 락의 하한 2 는 «두 skill 이 공유하니까 플러그인 레벨에 있다»는 배치 근거에서
# 나온다. 이 계약은 다르다 — **오늘 집행 대상은 seed 하나뿐**이고 brief 는 재구조화
# 이후에 채택한다(정본 자신이 그렇게 적는다). 하한 2 를 두면 정직한 상태에 RED 가 난다.
#
# **그래도 하한 1 은 둔다.** 두지 않으면 유일한 채택자가 포인터를 잃는 순간 도출 집합이
# 공집합이 되고 채택자별 루프가 0회 돌아 **vacuous GREEN** 이다. 하한 1 은 열거가
# 아니므로 둘째 채택자가 생겨도 그대로 작동한다.
#
# ── 코퍼스 스코프 ───────────────────────────────────────────────────────────
# **정본을 코퍼스에 넣지 않는다.** 정본은 계약을 서술하느라 앵커 어휘를 그대로 담고
# 있어서, 들어오면 아래 존재 단언이 정본 하나로 만족되고 채택 skill 이 자기 문구를
# 통째로 잃어도 GREEN 이 된다(형제 락의 F1 위험과 같은 모양).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
CANON="$SD/references/compression.md"
CANON_REF='references/compression\.md'

. "$REPO_ROOT/shared/tests/assert.sh"
. "$REPO_ROOT/shared/tests/presence_corpus.sh"

emit_only=0
[ "${1:-}" = "--emit-scanned" ] && emit_only=1

[ -f "$CANON" ] || { [ "$emit_only" -eq 1 ] && exit 0
  no "정본 $CANON 부재 — 채택자 대칭을 잴 대상이 없다"; finish; exit $?; }

adopters=""
scanned=""
for skill_dir in "$SD"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  surface=""
  for f in "$skill_dir"SKILL.md "$skill_dir"references/*.md; do
    [ -f "$f" ] || continue
    surface="$surface$f
"
  done
  [ -n "$surface" ] || continue
  hit=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qE -- "$CANON_REF" "$f" && { hit=1; break; }
  done < <(printf '%s' "$surface")
  if [ "$hit" -eq 1 ]; then
    adopters="$adopters${skill_dir%/}
"
    scanned="$scanned$surface"
  fi
done

if [ "$emit_only" -eq 1 ]; then
  printf '%s' "$scanned" | sed "s|^$REPO_ROOT/||"
  exit 0
fi

n_adopt=0
while IFS= read -r a; do [ -n "$a" ] && n_adopt=$((n_adopt + 1)); done < <(printf '%s' "$adopters")
if [ "$n_adopt" -lt 1 ]; then
  no "채택자 도출 ${n_adopt}개 — 유일한 채택자가 포인터를 잃으면 아래 루프가 0회 돌아 vacuous GREEN 이 된다"
  finish; exit $?
fi
ok "채택자 도출 ${n_adopt}개 (열거 아님 — 정본 포인터에서 도출, 하한 1 충족)"

SCANNED_ARR=()
while IFS= read -r f; do
  [ -n "$f" ] && SCANNED_ARR+=("$f")
done < <(printf '%s' "$scanned")
assert_presence_corpus_skill_owned "압축 채택자 표면" "${SCANNED_ARR[@]+"${SCANNED_ARR[@]}"}"

if printf '%s' "$scanned" | grep -qxF -- "$CANON"; then
  no "코퍼스: 정본($CANON)이 스캔 대상에 들어 있다 — 앵커 어휘를 담은 파일이라 단언이 그것으로 만족된다"
else
  ok "코퍼스: 정본이 스캔 대상에 없다 (자기 만족 불가)"
fi

while IFS= read -r skill_dir; do
  [ -n "$skill_dir" ] || continue
  name="$(basename -- "$skill_dir")"
  files=()
  for f in "$skill_dir/SKILL.md" "$skill_dir"/references/*.md; do
    [ -f "$f" ] && files+=("$f")
  done
  if [ "${#files[@]}" -lt 1 ]; then
    no "$name: 표면 파일 0건 — 도출이 깨졌다"
    continue
  fi
  # 불변량 넷을 이름으로 댔는가. 넷 중 하나라도 없으면 그 채택자는 «무엇을 남기는지»를
  # 자기 표면에 적지 않은 것이다 — 압축의 잣대가 정본에만 있으면 실행 시점에 안 읽힌다.
  ic="$(cat "${files[@]}" | grep -cE '의도|steering|방향|goal')"
  [ "$ic" -ge 1 ] \
    && ok "$name: 압축 불변량 어휘 실재 — ${ic}줄 (자기 표면 ${#files[@]}파일)" \
    || no "$name: 압축 불변량(의도·steering·방향·goal)이 자기 표면에 없다"
  # 확산 후 압축 — 순서가 이 계약의 전부다. 「짧게 써라」와 「크게 쓰고 깎아라」는 다른 지시다.
  dc="$(cat "${files[@]}" | grep -cE '확산.*압축|깎')"
  [ "$dc" -ge 1 ] \
    && ok "$name: 확산-후-압축 어휘 실재 — ${dc}줄" \
    || no "$name: 확산 후 압축이 자기 표면에 없다 — 「짧게 써라」는 이 계약이 아니다"
done < <(printf '%s' "$adopters")

finish
```

- [ ] **Step 2: RED 확인 (정본 부재)**

Run: `bash plugins/spec-distill/tests/test_compression_adopters.sh </dev/null | tail -3`
Expected: `✗ 정본 … 부재`.

- [ ] **Step 3: `compression.md` 정본을 쓴다**

```markdown
# 압축 규약

> **payload 는 압축의 결과이고, 압축에서 떨어진 모든 것은 audit 에 남는다.**

## 불변량

**의도 · steering · 방향 · goal**, 그리고 그 넷을 지탱하는 사실 중 **에이전트가 알 수 없는
것**. 넷을 지탱해도 에이전트가 이미 아는 사실이면 깎인다.

## 깎이는 것

자명한 것 · 하류 단계가 정할 수 있는 것 · 읽으면 아는 것 · 과정과 절차 · 상시 규칙
(`CLAUDE.md`·`AGENTS.md` 에 이미 있는 것) · **출처 링크**.

## 링크와 사실의 구분

사용자가 준 자료는 에이전트가 알 수 없는 사실이므로 불변량이다 — 그러나 **URL 로 나르지
않고 말로 옮겨 적는다.** payload 에 URL 이 0개인 것은 사실을 버리라는 뜻이 아니라 **링크를
근거로 세우지 말라**는 뜻이다. 링크가 권위로 읽혀 하류를 끌고 가는 것이 이 조항의 이유다.

## 상한을 두지 않는다

확산에도 분량에도. **짧음은 상한이 아니라 뺄셈의 결과다.** 긴 초안을 먼저 쓰고 그 다음
깎는다 — 크게 그린 다음 깎아낸 것이 처음부터 짧게 쓴 것보다 더 많은 것을 고려한다.

## 메시지형 payload 에는 존재 검사를 두지 않는다

**존재 검사가 payload 를 양식으로 만든다.** 문서형 payload 는 절 존재 검사를 가질 수 있되
확산물의 *원문·근거·전량*을 payload 에 요구해서는 안 된다. 확산에서 나온 것의 **압축된
판정 한 줄**은 payload 의 것이다.

## 문장 하나에 적용하는 세 물음

1. 이게 의도·steering·방향·goal 인가, 아니면 실행 세부인가. 세부면 뺀다.
2. 이 문장을 빼면 에이전트가 **틀리거나 빠뜨릴** 수 있는가. 어차피 맞게 할 거면 뺀다.
   대체로 하지만 가끔 빠뜨리는 것은 한 줄 값어치가 있다.
3. 레포 `CLAUDE.md`·`AGENTS.md` 에 이미 있는가. 있으면 뺀다.

## 오늘 이 계약을 게이트로 집행하는 것은 seed 뿐이다

`interview-brief` 는 이 규약을 **원칙으로 상속**하되 게이트로 강제받지 않는다. 그 이유는
규약 부재가 아니라 **게이트 배치**다 — brief 의 15검사와 bijection 3종과 원문 완전성 검사가
전부 payload 를 대상으로 삼아, 검증하고 싶은 것이 전부 payload 로 끌려왔다. **검증 대상과
인계 대상이 같은 파일이면 검증이 인계물을 부풀린다.** brief 는 그 재구조화(별도 설계)
이후에 채택한다.

## 이 규약은 앞 단계의 결정을 봉인하지 않는다

철학 **P23 — Decisions Stay Refutable**. 압축이 떨어뜨린 것도, 압축이 남긴 것도, 하류가
근거를 대고 사용자 동의를 받으면 뒤집을 수 있다. 압축은 **정보를 audit 으로 옮기는 것**이지
결정을 닫는 것이 아니다.
```

- [ ] **Step 4: `trivia-escape.md` 정본을 쓴다**

`commands/interview.md` 의 Step 2 본문을 **그대로 옮긴다**(문면 변경 없음 — 옮기면서 고치면 무엇이 바뀌었는지 diff 가 안 보인다).

```markdown
# Trivia Escape — 5 패턴

`$ARGUMENTS` 가 아래 다섯 중 하나에 해당하면 인터뷰 게이트를 우회한다.

1. **Typo 1줄 수정** — 예: "fix typo on line 3", "오타 고쳐줘"
2. **주석-only diff** — 예: "add a comment explaining X"
3. **formatting** — 예: "reformat foo.py", "indentation 맞춰줘". 파일 수는 기준이 아니다.
4. **단일 식별자 rename** — 예: "rename `bar` to `baz`". 파일 수는 기준이 아니다 — 판정 기준은 **한 문장으로 설명 가능한가**이다(philosophy P12). *의미가 바뀌는 rename(공개 API·직렬화 키 등)은 파일이 하나여도 trivia 아님.*
5. **<10 토큰 + 명백히 안전한 syntactic action 동사** — 예: "fix typo", "add semicolon", "remove blank line". *다음 경우는 trivia 아님: (a) destructive 동사 `drop`/`truncate`/`reset`/`force-push` 등이 system noun (`table`/`branch`/`production`/`deployment`) 과 결합, (b) `delete`/`remove` + system noun (e.g., "remove auth middleware", "delete user table"). 의미론적 삭제는 syntactic 삭제와 구분.*

해당하면 다음 메시지를 출력하고 진행하지 않는다:

> ⚠ 이 요청은 trivia 패턴(<해당 패턴 이름>)으로 보입니다. 게이트를 우회해서 직접 처리할 수 있습니다.
> 그래도 진행하시려면 명시적으로 "force interview" 또는 더 자세한 컨텍스트를 알려주세요.

→ END (사용자 후속 입력 대기).
```

- [ ] **Step 5: 고아 검사가 아직 RED 인지 확인한다**

Run: `bash shared/tests/test_skill_reference_pointers.sh </dev/null | grep -E 'orphan.*compression|orphan.*trivia|Fail'`
Expected: 두 파일이 **고아로 잡혀야 한다** — 아직 아무 SKILL.md 도 가리키지 않는다. 이것이 Task 11 의 요구를 만든다.

> **이 RED 는 Task 11 이 닫는다.** 이 태스크만으로 커밋하지 않는다 — PR3 는 통째로 하나이고, 중간 커밋은 로컬 진행 표시일 뿐 단독 green 을 주장하지 않는다.

- [ ] **Step 6: 로컬 커밋 (PR 단위 green 은 Task 15 에서)**

```bash
git add plugins/spec-distill/references/compression.md \
        plugins/spec-distill/references/trivia-escape.md \
        plugins/spec-distill/tests/test_compression_adopters.sh
git commit -m "feat(spec-distill): 압축 규약 + trivia escape 정본 (채택자는 Task 11)"
```

---
### Task 11: command + skill (앵커 넷 + 처분 앵커 둘)

**Files:**
- Create: `plugins/spec-distill/commands/request-framing.md`
- Create: `plugins/spec-distill/skills/framing-requests/SKILL.md`
- Create: `plugins/spec-distill/tests/test_request_framing_command.sh`

**Interfaces:**
- Consumes: `references/proceed-gate.md` · `references/compression.md` · `references/trivia-escape.md`
- Produces: dispatch 자리 2곳(`seed-critic` · `seed-readback`) — Task 12 의 agent 정의가 이 자리를 필요로 한다(`ZERO_AGENTS`)

**이 skill 이 자기 표면에 반드시 가져야 하는 것 — 여섯**

`framing-requests` 는 `proceed-gate.md` 를 가리키는 순간 `test_proceed_gate_adopters.sh` 의 **셋째 채택자로 자동 도출**되고, `compression.md` 를 가리키는 순간 `test_compression_adopters.sh` 의 채택자가 된다. 도출은 열거가 아니므로 등록 절차가 없다 — **포인터를 쓰는 것이 곧 등록이고, 등록되는 순간 아래 여섯을 요구받는다.**

| # | 앵커 | 재는 락 | grep |
|---|---|---|---|
| 1 | 정지 어휘 | `test_proceed_gate_adopters.sh` | `턴 종료` 또는 `다음 턴` |
| 2 | polite stop 금지 | `test_proceed_gate_adopters.sh` | `polite stop` (대소문자 무시) |
| 3 | degrade 채널 이름 | `test_proceed_gate_adopters.sh` | `degrade 채널` |
| 4 | P23 재결정 규약 | `test_proceed_gate_adopters.sh` (PR0 Task 3) | `재결정` 또는 `반증` |
| 5 | 압축 불변량 | `test_compression_adopters.sh` | `의도`·`steering`·`방향`·`goal` |
| 6 | 확산 후 압축 | `test_compression_adopters.sh` | `확산.*압축` 또는 `깎` |

- [ ] **Step 1: command 락을 먼저 쓴다**

Create `plugins/spec-distill/tests/test_request_framing_command.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/commands/request-framing.md
#
# `/request-framing` command 가 자기 세 책임을 실제로 담고 있는가 — kill switch ·
# trivia escape 포인터 · skill dispatch. 그 셋뿐이고, 셋 다 없으면 안 된다.
#
# **포인터로 재는 이유**: trivia 5패턴을 이 파일에 그대로 쓰면 `interview.md` 와
# 20줄 이상 동일 구간이 생겨 `shared/tests/test_no_new_duplication.sh` 가 RED 를 낸다.
# 그래서 정본은 `references/trivia-escape.md` 이고 여기는 가리키기만 한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CMD="$ROOT/plugins/spec-distill/commands/request-framing.md"
. "$ROOT/shared/tests/assert.sh"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/commands/request-framing.md"
  exit 0
fi

[ -f "$CMD" ] || { no "command 파일 부재: $CMD"; finish; exit $?; }
ok "command 파일 실재"

grep -q 'DEVBREW_SPEC_DISTILL_DISABLE' "$CMD" \
  && ok "kill switch 존중" || no "kill switch 가 없다 — 훅 밖 진입점이 스위치를 무시한다"

grep -qE 'references/trivia-escape\.md' "$CMD" \
  && ok "trivia escape 정본 포인터" || no "trivia escape 포인터가 없다"

grep -qE 'Skill .*framing-requests|framing-requests' "$CMD" \
  && ok "skill dispatch" || no "framing-requests skill 을 호출하지 않는다"

# 5패턴을 여기 «복제하지» 않았는가 — 정본이 있는데 사본이 있으면 둘이 갈라진다.
pc="$(grep -cE '^[0-9]\. \*\*(Typo|주석-only|formatting|단일 식별자|<10 토큰)' "$CMD")"
[ "$pc" -eq 0 ] \
  && ok "5패턴 본문이 복제되지 않았다 (정본만)" \
  || no "5패턴 본문이 이 파일에 복제돼 있다 (${pc}줄) — 정본과 갈라진다"

finish
```

- [ ] **Step 2: RED 확인**

Run: `bash plugins/spec-distill/tests/test_request_framing_command.sh </dev/null | tail -3`
Expected: `✗ command 파일 부재`.

- [ ] **Step 3: command 를 쓴다**

`interview.md`(56줄)와 같은 크기. **Step 1 의 kill-switch 문면을 그대로 복사하지 않는다** — 그 구간이 `interview.md` 와 이어지면 중복 락의 창에 들어간다.

```markdown
---
description: 파이프라인 맨 앞의 회의 — 사용자의 의도·steering·방향·goal 을 싱크해 새 세션의 첫 턴 메시지 `interview-seed` 로 압축한다.
argument-hint: "[raw request / 생각 / 대화 / 자료]"
---

# /request-framing

당신은 spec-distill 파이프라인의 **Phase 0** 에 있습니다. 여기서 하는 일은 요구사항
인터뷰가 아니라 **회의**입니다 — 사용자와 함께 「다음 에이전트에게 정확히 무엇을
맡기는가」를 정하고, 그것을 새 세션의 첫 턴에 그대로 붙여넣을 메시지 하나로 압축합니다.

## Step 1: kill switch

`DEVBREW_SPEC_DISTILL_DISABLE=1` 이 set 이면 즉시 종료(no-op). 상태를 만들지 않습니다.

## Step 2: trivia escape

5 패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 에 있습니다. 그 파일을
읽고 `$ARGUMENTS` 를 대조하십시오. 해당하면 그 파일의 안내 문면을 출력하고 종료합니다.

## Step 3: 회의 진입

trivia 가 아니면 `framing-requests` skill 을 invoke 합니다.

```
Skill framing-requests $ARGUMENTS
```

## Arguments

`$ARGUMENTS` — 거친 프롬프트·생각·대화 로그·자료 무엇이든. 비어 있으면 skill 이
「무엇을 맡기려 하시나요」로 시작합니다.

## 다음 단계

skill 이 확산 후 압축을 거쳐 `interview-seed` 를 `docs/superpowers/interview/` 에
만듭니다. 그 seed 는 **새 세션의 첫 턴에 붙여넣는 메시지**이고, 그 세션이
`/interview` 로 Phase 1 을 시작합니다.
```

- [ ] **Step 4: skill 을 쓴다 — 앵커 여섯 + 처분 앵커 둘**

`plugins/spec-distill/skills/framing-requests/SKILL.md`. 아래는 **락이 요구하는 부분만** 발췌한 골격이다. 절차 본문(확산·압축)은 설계 §2 를 그대로 옮긴다.

````markdown
# Framing Requests — Phase 0

`cost_class: medium`

당신은 파이프라인 맨 앞의 **회의**를 진행 중입니다. 산출물은 문서가 아니라 **새 세션의 첫
턴에 그대로 붙여넣는 메시지**입니다.

**진입 선결조건** — `/request-framing` command 가 trivia escape 를 통과시킨 요청만 이
skill 에 옵니다. 5패턴 정의는 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md`.
**검사는 command 가 합니다** — 이 skill 은 그 정의를 인용할 뿐 다시 검사하지 않습니다.

## 무엇을 남기고 무엇을 깎는가

압축 규약 정본은 `${CLAUDE_PLUGIN_ROOT}/references/compression.md` 입니다.

**불변량은 넷** — **의도 · steering · 방향 · goal**, 그리고 그 넷을 지탱하는 사실 중
에이전트가 알 수 없는 것.

**방식은 확산 후 압축** — 긴 초안을 먼저 쓰고 **그 다음 깎습니다.** 처음부터 짧게 쓰지
않습니다. 크게 그린 다음 깎아낸 것이 처음부터 짧게 쓴 것보다 더 많은 것을 고려합니다.
긴 초안은 세션 state 에만 살고, `docs/` 에 나가는 것은 깎은 것뿐입니다.

## 확산

(설계 §2.2 — 원문 보존 → 레포 읽기 → 질문을 한꺼번에 → 부분 답 → 새 질문. 매 라운드
네 블록: 지금 이해한 작업 / 원문과 다른 점 / 아직 안 잡힌 것 / 질문.)

**질문에도 라운드에도 분량에도 상한이 없습니다.** 질문 루프는 매 반복마다 사용자가
답해야 돌고 사용자가 그 루프의 시계입니다 — 자율이 없으므로 묶을 자율도 없습니다.

## 검증

### 억제 리뷰

```javascript
Agent({ description: "Seed suppression critique", subagent_type: "spec-distill:seed-critic",
        prompt: `초안 · 원문 · 레포 CLAUDE.md 를 전문 inline 으로 받는다. 네 축만 본다.
<draft>${BLOB}</draft>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

**뺄셈 검사입니다.** 「좋은 프롬프트냐」는 묻지 않습니다 — 그건 취향이고 비평자에게는
사용자의 도메인 지식이 없습니다.

### 냉독

```javascript
Agent({ description: "Seed cold readback", subagent_type: "spec-distill:seed-readback",
        prompt: `아래 seed 만 읽고 «내가 이해한 것은 이것이다» 를 산문으로 말하라.
<seed>${SEED}</seed>` })
// **처분** — consumer=human · fail-open · disclosure=framing_degradations
```

**싱크됐는지는 사용자가 읽고 판정합니다.** 에이전트가 통과·미달을 내면 어긋남의 감각이
사용자에게 오지 않습니다.

## degrade 채널

이 skill 의 **degrade 채널**은 state 의 `framing_degradations` 원장입니다. 기록은
`brief_review_state.py degrade-append … --ledger-key framing_degradations --axis suppression`
으로 하고, **원장에 못 쓰면 그 사실 자체를 게이트 질문 텍스트에 한 줄로 싣습니다** —
기록이 없는 것과 degrade 가 없는 것은 다른 사실입니다.

codex 가 죽으면 record 하나가 남고 격리 critic 이 단독으로 돕니다. **억제 축은 판정에
합류하지 않습니다** — findings 는 어떤 병합기도 거치지 않고 사용자에게 직접 갑니다.

## 확정 — proceed 게이트

공통 계약의 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 입니다. 4옵션
게이트를 띄우고, 게이트 질문 텍스트에 degrade 를 **하나도 빠뜨리지 않고** 싣습니다.
**승인 이후에만** seed 파일이 `docs/` 에 쓰입니다.

게이트를 띄우기 **직전에** 구조 검사를 돌립니다:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/check_seed.py" \
  gate "$SEED" "$AUDIT"; seed_rc=$?
if [ "$seed_rc" -ne 0 ]; then
  echo "[spec-distill] seed 게이트 위반 — 위 항목을 고치고 다시 이 블록부터 탑니다. 게이트를 띄우지 않습니다." >&2
fi
```

`check_seed.py` 가 재는 넷은 **전부 부재 검사**입니다(원문 보존 하나만 audit 쪽 존재
검사). **본문에 존재 검사를 추가하지 마십시오** — 그것이 이 payload 를 양식으로 만드는
유일한 경로이고, `tests/test_seed_one_sentence.sh` 가 그 금지를 동작으로 잡습니다.

### 두 가드

- **polite stop 금지 (AP2)** — 승인 옵션인데 narrate 만 하고 다음 단계로 가지 않는 것은
  polite stop 입니다. 게이트를 거치지 않는 예외 경로(kill switch · 경로 부재)면 명시적
  advisory 단락을 동반해야 합니다 — 게이트-less silent 종료 금지.
- **cross-compact 조기 진행 금지** — 옵션 ①(`/compact` 후 다음 단계)을 고르면 verbatim
  `/compact` 명령을 노출하고 **거기서 턴 종료(STOP)** 합니다. 같은 턴에서 다음 단계로
  가지 않습니다. **다음 턴** 진입은 사용자가 `/compact` 를 실제 실행한 뒤 사용자
  트리거로만 일어납니다.

### 재결정 규약 (P23)

확산에서 확정된 것은 재논의 대상이 아니지만 **반증 대상입니다.** 압축 중에 그 확정이
틀렸다는 근거가 나오면 근거를 제시하고 **사용자 동의를 받아** 피벗합니다 — 임의 변경은
금지, 보고 후 재결정은 허용. 뒤집은 항목은 audit 에 *원래 / 재결정 / 근거* 세 칸으로
남깁니다. 정본은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「재결정 규약」 절.

## kill switch

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — 즉시 abort, state 보존.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` — codex 억제 축만 skip, 격리 critic 은 정상.
````

- [ ] **Step 5: 앵커 여섯이 실제로 잡히는지 실측한다**

Run:
```bash
S=plugins/spec-distill/skills/framing-requests/SKILL.md
printf '1 정지어휘 %s\n' "$(grep -cE '턴 종료|다음 턴' "$S")"
printf '2 politestop %s\n' "$(grep -ciF 'polite stop' "$S")"
printf '3 degrade채널 %s\n' "$(grep -cF 'degrade 채널' "$S")"
printf '4 재결정 %s\n' "$(grep -cE '재결정|반증' "$S")"
printf '5 불변량 %s\n' "$(grep -cE '의도|steering|방향|goal' "$S")"
printf '6 확산압축 %s\n' "$(grep -cE '확산.*압축|깎' "$S")"
```
Expected: 여섯 전부 1 이상. **하나라도 0 이면 그 락이 착지 즉시 RED 다.**

- [ ] **Step 6: 포인터 표기와 고아 해소를 확인한다**

Run: `bash shared/tests/test_skill_reference_pointers.sh </dev/null | tail -4`
Expected: `Fail: 0`. 세 포인터가 전부 `${CLAUDE_PLUGIN_ROOT}/references/…` 형태(인식 형태 ①)여야 하고, `compression.md`·`trivia-escape.md` 가 더 이상 고아가 아니어야 한다.

**중괄호를 빼면(`$CLAUDE_PLUGIN_ROOT/…`) loud FAIL 이다** — 그 표기는 인식 형태 셋 중 어디에도 없고, 락이 조용히 재해석하는 대신 거부한다.

- [ ] **Step 7: 채택자 락 둘 + 격리 산술**

Run:
```bash
bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh </dev/null | tail -6
bash plugins/spec-distill/tests/test_compression_adopters.sh </dev/null | tail -4
bash shared/tests/test_presence_corpus_behavior.sh </dev/null | tail -4
```
Expected: 셋 다 `Fail: 0`. 첫 번째는 이제 **채택자 3개**를 도출해야 하고, 세 번째의 격리 산술 `Σ(채택자별 파일 수) == 전체` 가 3개로 확장돼도 성립해야 한다.

- [ ] **Step 8: 로컬 커밋**

```bash
git add plugins/spec-distill/commands/request-framing.md \
        plugins/spec-distill/skills/framing-requests/SKILL.md \
        plugins/spec-distill/tests/test_request_framing_command.sh
git commit -m "feat(spec-distill): request-framing command + framing-requests skill"
```

### Task 12: agent 2 + template 2

**Files:**
- Create: `plugins/spec-distill/agents/seed-critic.md` · `agents/seed-readback.md`
- Create: `plugins/spec-distill/templates/interview-seed-template.md` · `templates/interview-seed-audit-template.md`
- Create: `plugins/spec-distill/tests/test_seed_agents.sh`

**Interfaces:**
- Consumes: Task 11 의 dispatch 자리 2곳 (`ZERO_AGENTS` 때문에 필수)
- Produces: agent 이름 `seed-critic` · `seed-readback`

- [ ] **Step 1: 락을 먼저 쓴다**

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/agents/seed-*.md
#
# 두 seed 리뷰어의 **도구 표면**을 잰다. `tools: []` 는 Law 2 의 집행 지점이고, 여기서는
# 그보다 더 강하다 — 이 둘은 `Read` 도 없다.
#
# **왜 `Read` 조차 없나**: `seed-readback` 의 측정이 성립하려면 그것이 **seed 만** 알아야
# 한다. `Read` 가 있으면 원문 파일을 열어 「seed 만 읽고 알 수 있나」가 더 이상 재지지
# 않는다. `seed-critic` 은 원문이 필요하지만 **inline 으로** 받는다 — 도구가 아니라
# 프롬프트로 준다. 도구 표면이 격리의 유일한 물리적 근거다(프롬프트 지시는 근거가 아니다).
#
# `disallowedTools` 단독은 금지다 — 공간에 대해서도 시간에 대해서도 fail-open 이다
# (내일 추가될 도구는 오늘 열거할 수 없다).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
AGENTS="$ROOT/plugins/spec-distill/agents"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/agents/seed-critic.md"
  echo "plugins/spec-distill/agents/seed-readback.md"
  exit 0
fi

n=0
for a in seed-critic seed-readback; do
  f="$AGENTS/$a.md"
  if [ ! -f "$f" ]; then no "$a: agent 정의 부재"; continue; fi
  n=$((n + 1))
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")"
  # `tools:` 가 있고 빈 리스트인가. 값이 있으면 RED.
  tl="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -1)"
  case "$tl" in
    "[]"|"[ ]") ok "$a: tools: [] (도구 표면 0)" ;;
    "")         no "$a: frontmatter 에 tools: 선언이 없다 — default-everything 은 금지다" ;;
    *)          no "$a: tools: '$tl' — 빈 리스트가 아니다. 격리가 도구 표면에서 무너진다" ;;
  esac
  # denylist 단독 금지
  printf '%s\n' "$fm" | grep -q '^disallowedTools:' \
    && no "$a: disallowedTools 를 쓴다 — 공간·시간 양쪽에 fail-open 이다" \
    || ok "$a: denylist 미사용"
done
[ "$n" -eq 2 ] && ok "agent 2개 전부 실재" || no "agent 도출 ${n}개 — 2 여야 한다"
finish
```

- [ ] **Step 2: RED 확인 → agent 둘을 쓴다**

Run: `bash plugins/spec-distill/tests/test_seed_agents.sh </dev/null | tail -3` → `✗ … 부재`.

`agents/seed-critic.md`:
```markdown
---
name: seed-critic
description: Use this agent to review an interview-seed draft for SUPPRESSION — what the model added without grounds, mistook an example for a requirement, closed too early, or dressed its own inference as the user's decision. Receives the draft, the raw原文, and the repo CLAUDE.md inline; owns no tools at all.
tools: []
---

You are the seed critic. You are responsible for **subtraction** — finding what should not
be in this draft. You are NOT responsible for judging whether it is a *good* prompt: that is
taste, and you do not have the user's domain knowledge.

네 축만 본다.

1. **근거 없이 추가된 제약** — 원문에도 `CLAUDE.md` 에도 없는데 초안에 있는 제한.
2. **예시를 필수로 오인** — 사용자가 "예를 들면" 이라고 한 것이 요구사항이 된 자리.
3. **선택지를 조기에 닫는 표현** — 하류가 정할 수 있는 것을 지금 정해버린 문장.
4. **사용자 결정처럼 표현된 에이전트 추론** — 누가 정했는지가 뒤바뀐 문장.

각 항목은 `<축> — <초안의 그 문장> — <원문/CLAUDE.md 의 대응 부재 또는 대응> — <제안>`.
```

`agents/seed-readback.md`:
```markdown
---
name: seed-readback
description: Use this agent to read an interview-seed cold and say back, in plain prose, what it understood — what work is being handed off, what the direction is, and what the sender cares about. A synchronization measurement, not a review: it is given no criteria, no schema, and nothing but the seed itself.
tools: []
---

You are the cold reader. You are responsible for saying back **what you understood**. You are
NOT responsible for judging, scoring, or improving anything.

당신에게는 seed 본문만 주어진다. 원문도 대화도 없다.

산문으로 답하라: 무엇을 맡기려는 것으로 읽었는가 · 방향이 무엇으로 읽혔는가 · 보낸 사람이
무엇을 신경 쓰는 것으로 읽혔는가 · 읽으면서 «이건 모르겠다» 싶었던 곳은 어디인가.

**통과·미달을 내지 마라.** 싱크됐는지는 사용자가 당신의 답을 읽고 판정한다.
```

- [ ] **Step 3: 템플릿 둘**

`templates/interview-seed-template.md` — **양식이 아니다.** 슬롯이 아니라 예시 하나와 «쓰지 말 것» 목록을 담는다. 본문은 설계 §5.1 의 예시(로그인 실패 사례)와 문장별 판정 표를 그대로 옮긴다.

머리에 이 한 줄을 둔다:

```markdown
> 이것은 **양식이 아니라 예시**다. 아래 문단 구성을 따라 쓰지 말고, 무엇이 남고 무엇이
> 깎였는지의 **판정**만 가져가라. 절도 라벨도 태그도 URL 도 없다.
```

`templates/interview-seed-audit-template.md` — 절 다섯: `## 1. 원문`(append-only) · `## 2. 질문 전체`(쏟아낸 것 · 답한 것 · 안 한 것) · `## 3. 긴 초안` · `## 4. 비평과 냉독` · `## 5. degrade`.

- [ ] **Step 4: dispatch 회계가 green 인지 확인**

Run: `bash shared/tests/test_dispatch_disposition.sh </dev/null | tail -8`
Expected: `Fail: 0`. 확인할 것:
- `PRINT_1_agents` 가 **20**(기존 18 + 새 2)
- `ZERO_AGENTS` 가 빈 문자열 — 두 새 agent 가 각각 dispatch ≥1
- 축 A① `앵커 수 == dispatch 수`
- 축 A② 각 dispatch 아래 40줄 창에 자기 앵커 정확히 하나

**A① 이 어긋나면** 새 dispatch 2개에 앵커가 2개가 아닌 것이다. **A② 가 어긋나면** 두 dispatch 사이 거리가 40줄을 넘거나 앵커가 잘못된 dispatch 에 배정된 것이다 — Task 11 의 코드펜스 안 배치(`// **처분** —`)를 다시 확인한다.

- [ ] **Step 5: 로컬 커밋**

```bash
git add plugins/spec-distill/agents/seed-critic.md \
        plugins/spec-distill/agents/seed-readback.md \
        plugins/spec-distill/templates/interview-seed-template.md \
        plugins/spec-distill/templates/interview-seed-audit-template.md \
        plugins/spec-distill/tests/test_seed_agents.sh
git commit -m "feat(spec-distill): seed-critic · seed-readback (tools: []) + 템플릿 2"
```

### Task 13: `check_seed.py` + 게이트 락 둘

**Files:**
- Create: `plugins/spec-distill/scripts/check_seed.py`
- Create: `plugins/spec-distill/tests/test_check_seed.sh` · `tests/test_seed_one_sentence.sh`
- Create: `plugins/spec-distill/tests/fixtures/seed-*.md` (RED 픽스처 넷 + GREEN 픽스처 둘)

**Interfaces:**
- Consumes: 없음
- Produces: CLI `python3 check_seed.py gate <seed> [<audit>]` — Task 11 의 SKILL 이 확정 직전에 호출한다

**게이트의 모양이 이 태스크의 전부다.** seed 본문에 대해서는 **전부 부재 검사**이고, 원문 보존 하나만 audit 쪽 존재 검사다. **존재 검사가 payload 를 양식으로 만들고, 양식이 내용을 미리 판 구멍 모양으로 강제한다 — 그것이 이 단계가 막으라고 만들어진 실패다.**

- [ ] **Step 1: 금지 조항을 재는 락을 먼저 쓴다**

`tests/test_seed_one_sentence.sh` 가 이 계획에서 가장 중요한 락이다. 산문이 아니라 **동작**으로 금지를 잡는다.

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/check_seed.py
#
# **한 문장뿐인 seed 가 통과해야 한다.**
#
# 이 락이 재는 것은 기능이 아니라 **금지**다 — `check_seed.py` 에 seed 본문의 «존재
# 검사»를 추가하면 RED 가 난다. 그것이 이 게이트가 양식으로 변질되는 유일한 경로이고,
# 산문으로 적어 둔 금지는 다음 편집자가 「합리적인 추가」로 지나간다.
#
# 픽스처는 헤딩 0 · 필드 0 · 절 0 · 태그 0 · URL 0 인 **한 문장**이다. 어떤 슬롯 존재
# 검사가 들어와도 이 픽스처는 그것을 만족시킬 수 없다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CHECK="$ROOT/plugins/spec-distill/scripts/check_seed.py"
FIX="$ROOT/plugins/spec-distill/tests/fixtures"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/check_seed.py"
  exit 0
fi

[ -f "$CHECK" ] || { no "check_seed.py 부재"; finish; exit $?; }

PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate \
  "$FIX/seed-one-sentence.md" "$FIX/seed-one-sentence.audit.md" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] \
  && ok "한 문장 seed 가 통과한다 (게이트가 양식이 아니다)" \
  || no "한 문장 seed 가 rc=$rc 로 막혔다 — 본문 존재 검사가 들어왔다. 그것이 payload 를 양식으로 만든다"

# 양성 대조 — 게이트가 «무엇이든 통과시키는» 상태가 아님을 같은 자리에서 증명한다.
# 이것이 없으면 위 ok 는 「검사가 다 죽었다」와 구별되지 않는다.
PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate \
  "$FIX/seed-has-url.md" "$FIX/seed-one-sentence.audit.md" >/dev/null 2>&1
rc2=$?
[ "$rc2" -ne 0 ] \
  && ok "양성 대조: URL 있는 seed 는 막힌다 (게이트가 살아 있다)" \
  || no "양성 대조: URL 있는 seed 가 통과한다 — 검사가 전부 죽었다"

finish
```

- [ ] **Step 2: 픽스처를 만든다**

`fixtures/seed-one-sentence.md`:
```markdown
---
type: interview-seed
next_phase: spec-distill:interview
audit_file: seed-one-sentence.audit.md
---

로그인이 가끔 실패하는데 왜인지 모르겠다.
```

`fixtures/seed-one-sentence.audit.md`: `## 1. 원문` 절 하나에 한 문장.

`fixtures/seed-has-url.md` (양성 대조) — 본문에 `https://example.com/x` 한 줄.
`fixtures/seed-has-tag.md` — 본문에 `[open: 아직 안 정함]`.
`fixtures/seed-has-answer-heading.md` — `## 미해결 질문` 헤딩.
`fixtures/seed-empty-verbatim.audit.md` — `## 1. 원문` 절이 비어 있다.

- [ ] **Step 3: RED 확인 → `check_seed.py` 를 쓴다**

```python
#!/usr/bin/env python3
"""interview-seed 게이트 — 넷.

**seed 본문에 대해서는 전부 부재 검사다.** 존재 검사를 추가하지 않는다: 그것이 payload 를
양식으로 만들고, 양식이 내용을 미리 판 구멍 모양으로 강제한다 — 이 단계가 막으라고
만들어진 실패가 그것이다. `tests/test_seed_one_sentence.sh` 가 이 금지를 산문이 아니라
동작으로 잡는다.

audit 쪽 존재 검사는 **원문 보존 하나뿐**이다. 그것은 payload 가 아니라 확산물의 보관소라
같은 논리가 적용되지 않는다.
"""
import argparse
import pathlib
import re
import sys

# 답-슬롯 헤딩 — 이 넷은 «공간을 닫는» 산출물의 표지다. seed 는 질문을 닫지 않는다.
ANSWER_SLOT_RE = re.compile(
    r'^##+\s*(미해결\s*질문|Open\s*Questions|대안|Alternatives|인수\s*조건|'
    r'Acceptance\s*Criteria|기각|Rejected)', re.M | re.I)
TAG_RE = re.compile(r'\[(open|추론|외부)\s*:')
URL_RE = re.compile(r'https?://')
FRONTMATTER_RE = re.compile(r'\A---\n.*?\n---\n', re.S)


def body_of(text: str) -> str:
    """frontmatter 를 제외한 본문. frontmatter 세 줄은 하니스용이고 첫 턴에 붙여넣는
    것은 본문이다 — 검사 대상도 본문이어야 한다."""
    return FRONTMATTER_RE.sub("", text, count=1)


def gate(seed_path: pathlib.Path, audit_path: pathlib.Path | None) -> list:
    problems = []
    try:
        text = seed_path.read_text(encoding="utf-8")
    except OSError as e:
        return [f"seed 를 읽을 수 없다: {e}"]

    body = body_of(text)

    # 0. 본문이 비어 있지 않다 — 유일한 seed 본문 «존재» 검사이고, 슬롯이 아니라
    #    파일 전체에 대한 것이다. 빈 파일을 통과시키면 나머지 셋이 전부 vacuous 하다.
    if not body.strip():
        problems.append("seed 본문이 비어 있다")

    # 1. 답-슬롯 헤딩 부재
    for m in ANSWER_SLOT_RE.finditer(body):
        problems.append(f"답-슬롯 헤딩: {m.group(0).strip()!r} — seed 는 공간을 닫지 않는다")

    # 2. 태그 0개
    for m in TAG_RE.finditer(body):
        problems.append(f"태그: {m.group(0)!r} — 라벨 없이 말로 쓴다")

    # 3. URL 0개
    #    web kill switch 와 **무관**하다. 웹이 꺼져 있어도 금지는 유지된다 — 완화할
    #    대상이 애초에 없다. 링크가 권위로 읽혀 하류를 끌고 가는 것이 이 조항의 이유다.
    for m in URL_RE.finditer(body):
        problems.append(f"URL: {m.group(0)!r} — 링크로 나르지 말고 말로 옮겨 적는다")

    # 4. 원문 보존 (audit 쪽 «존재» 검사)
    if audit_path is None:
        problems.append("audit 경로가 주어지지 않았다 — 원문 보존을 확인할 수 없다")
    else:
        try:
            atext = audit_path.read_text(encoding="utf-8")
        except OSError as e:
            problems.append(f"audit 을 읽을 수 없다: {e}")
        else:
            m = re.search(r'^##\s*1\.\s*원문\s*$(.*?)(?=^##\s|\Z)', atext, re.M | re.S)
            if m is None:
                problems.append("audit 에 `## 1. 원문` 절이 없다")
            elif not m.group(1).strip():
                problems.append("audit 의 `## 1. 원문` 절이 비어 있다")
    return problems


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["gate"])
    p.add_argument("seed")
    p.add_argument("audit", nargs="?")
    a = p.parse_args()
    probs = gate(pathlib.Path(a.seed),
                 pathlib.Path(a.audit) if a.audit else None)
    for x in probs:
        print(f"[check_seed] {x}", file=sys.stderr)
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: `test_check_seed.sh` — 검사 넷이 각자 RED 픽스처를 잡는가**

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/check_seed.py
#
# 검사 넷이 **각자** 자기 픽스처를 잡는가. 픽스처를 검사당 하나로 나눈 이유: 한 픽스처에
# 위반 넷을 다 넣으면 검사 하나만 살아 있어도 rc≠0 이라 나머지 셋이 죽은 것을 못 잡는다
# («여럿이 함께 실패»는 변이 선택의 결함이다).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CHECK="$ROOT/plugins/spec-distill/scripts/check_seed.py"
FIX="$ROOT/plugins/spec-distill/tests/fixtures"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/check_seed.py"
  exit 0
fi

[ -f "$CHECK" ] || { no "check_seed.py 부재"; finish; exit $?; }

run_gate() {   # run_gate <seed> <audit> → rc
  PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate "$1" "$2" >/dev/null 2>&1
}

GOOD_AUDIT="$FIX/seed-one-sentence.audit.md"

# ── 각 위반 픽스처가 rc≠0 인가 (검사가 살아 있는가)
for pair in \
  "seed-has-answer-heading.md|답-슬롯 헤딩" \
  "seed-has-tag.md|태그" \
  "seed-has-url.md|URL"; do
  fx="${pair%%|*}"; label="${pair#*|}"
  run_gate "$FIX/$fx" "$GOOD_AUDIT"
  [ $? -ne 0 ] \
    && ok "검사 살아 있음: ${label} (${fx})" \
    || no "검사 죽음: ${label} 픽스처(${fx})가 통과한다"
done

# 원문 보존 — audit 쪽 «존재» 검사. 빈 원문 절은 막혀야 한다.
run_gate "$FIX/seed-one-sentence.md" "$FIX/seed-empty-verbatim.audit.md"
[ $? -ne 0 ] \
  && ok "검사 살아 있음: 원문 보존 (빈 §1 원문 절)" \
  || no "검사 죽음: audit 의 §1 원문이 비어도 통과한다"

# audit 경로 자체가 없으면 «확인 불가»이지 «통과»가 아니다.
PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate "$FIX/seed-one-sentence.md" >/dev/null 2>&1
[ $? -ne 0 ] \
  && ok "audit 경로 부재를 통과로 읽지 않는다 (indeterminate ≠ clean)" \
  || no "audit 경로 없이도 통과한다 — 원문 보존이 조용히 vacuous 해진다"

# ── 양성 대조: 위반 0 인 픽스처는 통과해야 한다. 없으면 위 넷은 «전부 막는 게이트»와
#    구별되지 않는다.
run_gate "$FIX/seed-one-sentence.md" "$GOOD_AUDIT"
[ $? -eq 0 ] \
  && ok "양성 대조: 깨끗한 seed 는 통과한다" \
  || no "양성 대조: 깨끗한 seed 가 막힌다 — 위 RED 들은 증거가 아니다"

finish
```

**검사 하나를 지우면 그 픽스처가 GREEN 이 되어 이 락이 발화해야 한다** — 그것이 Step 5 의 mutation 이다.

- [ ] **Step 5: mutation — 각 검사에 이빨이 있는가**

```bash
git add -A && git commit -m "wip: mutation baseline"
C=plugins/spec-distill/scripts/check_seed.py

# M13~M16: 검사 넷을 하나씩 죽인다 → 각자의 RED 픽스처가 GREEN 이 되어 락이 발화
for pat in 'ANSWER_SLOT_RE.finditer' 'TAG_RE.finditer' 'URL_RE.finditer' "1\\. 원문"; do
  cp "$C" /tmp/c.bak
  # 해당 루프/블록을 무력화 (손으로 — 자동 sed 는 구현 형태에 달렸다)
  # ... 편집 ...
  bash plugins/spec-distill/tests/test_check_seed.sh </dev/null | grep -c '✗'
  cp /tmp/c.bak "$C"
done

# M17 — **존재 검사를 추가한다** → test_seed_one_sentence.sh 가 RED 여야 한다.
#       이것이 이 계획에서 가장 중요한 변이다.
python3 - <<'PY'
import pathlib
p = pathlib.Path("plugins/spec-distill/scripts/check_seed.py")
t = p.read_text(encoding="utf-8")
t = t.replace('    # 4. 원문 보존',
 '    if "## " not in body:\n'
 '        problems.append("seed 에 절 헤딩이 없다")\n\n    # 4. 원문 보존')
p.write_text(t, encoding="utf-8")
PY
bash plugins/spec-distill/tests/test_seed_one_sentence.sh </dev/null | grep -c '✗'
git checkout -- "$C"

# M18 양성 대조
bash plugins/spec-distill/tests/test_seed_one_sentence.sh </dev/null | tail -1
```
Expected: M13~M16 각각 `✗` ≥1, **M17 이 `✗` ≥1**, M18 이 `Fail: 0`.

**M17 이 0 이면 `test_seed_one_sentence.sh` 는 이름만 그 금지를 잡는 락이다.** 그때는 픽스처를 더 벌거벗겨야 한다(헤딩·필드·절이 전부 0 인지 다시 확인).

- [ ] **Step 6: 로컬 커밋**

```bash
git add plugins/spec-distill/scripts/check_seed.py \
        plugins/spec-distill/tests/test_check_seed.sh \
        plugins/spec-distill/tests/test_seed_one_sentence.sh \
        plugins/spec-distill/tests/fixtures/seed-*.md
git commit -m "feat(spec-distill): check_seed.py — 부재 검사 넷 + 양식화 금지 락"
```

### Task 14: seed codex 러너·빌더·체크리스트

**Files:**
- Create: `plugins/spec-distill/scripts/run_seed_codex_reviewer.sh` · `build_seed_codex_prompt.py` · `build_seed_inline_blob.py` · `seed-codex-suppression-checklist.md`
- Create: `plugins/spec-distill/tests/test_seed_codex_axes.sh`

**Interfaces:**
- Consumes: `shared/codex/runner_common.sh`(배포 사본 `scripts/runner_common.sh`) · `codex_prompt_common.py`
- Produces: `run_seed_codex_reviewer.sh suppression <seed> <cwd> <out.yaml>`

**억제 축을 brief 파이프라인에 얹지 않는 이유**(설계 §7.2): `AXES` 라는 이름이 세 곳에 있는데 뜻이 다르다 — `build_brief_codex_prompt.py:42` 는 **codex 프롬프트 축**(축마다 체크리스트 파일이 실재해야 한다), `run_brief_codex_reviewer.sh:79-81` 은 `case … exit 2` 의 **실제 fail-point**, `brief_review_state.py:42` 는 **degrade 원장의 `affected_axis`**. 게다가 brief 프롬프트 빌더는 **brief payload 형상**을 만드는데 입력은 seed 다. **parity 락을 세우기 전에 두 열거가 같은 것을 뜻하는지 먼저 확인하라** — 아니면 술어 자체가 거짓이다.

- [ ] **Step 1: 중복 위험을 먼저 잰다**

`run_brief_codex_reviewer.sh` 는 156줄이고 공통부는 이미 `runner_common.sh`(106줄, 정본 `shared/codex/`)에 빠져 있다. 남는 축-고유 본문은 ~110줄이며, 그중 `runner_common.sh` 로드 보일러플레이트가 ~15줄이다.

Run:
```bash
sed -n '40,70p' plugins/spec-distill/scripts/run_brief_codex_reviewer.sh
```
→ 이 구간을 그대로 복사하면 인접 줄과 합쳐 **20줄 창**에 들어갈 수 있다.

- [ ] **Step 2: seed 러너를 쓰고 중복 락으로 즉시 잰다**

Run: `bash shared/tests/test_no_new_duplication.sh </dev/null | tail -6`

- **`Fail: 0` 이면** 그대로 간다.
- **RED 면 두 갈래다.** 어느 쪽인지 **출력의 블록 내용을 보고** 정한다:
  - 겹치는 블록이 **`runner_common.sh` 로드 보일러플레이트**면 → 그 블록을 `shared/codex/runner_common.sh` 정본에 함수로 올리고 두 러너가 부른다. 정본을 고치므로 배포 사본들이 따라와야 하고 `shared/tests/test_copy_of_contract.sh` 를 함께 돌린다.
  - 겹치는 블록이 **축-고유 로직**이면 → 그건 실제로 같은 일을 두 번 쓰는 것이다. 같은 처방(정본 추출).

**`copy-of:` 마커로 면제받는 길을 먼저 고르지 않는다.** 마커는 «링크를 못 쓰는 경우»의 잔여 수단이고, 여기는 정본 추출이 가능하다.

- [ ] **Step 3: 체크리스트 문면 — 네 축**

`scripts/seed-codex-suppression-checklist.md`:

```markdown
# seed 억제 축 — codex 체크리스트

당신은 `interview-seed` 초안에서 **빼야 할 것**을 찾는다. 좋은 프롬프트인지 판정하지 않는다.

각 항목은 초안의 **문장을 인용**하고, 원문 또는 레포 `CLAUDE.md` 의 대응(또는 대응 부재)을
함께 낸다. 근거 없는 지적은 내지 않는다.

1. **근거 없이 추가된 제약** — 원문에도 `CLAUDE.md` 에도 없는데 초안이 만든 제한.
   예: 원문에 없던 "커밋까지만 하고 푸시는 하지 않는다".
2. **예시를 필수로 오인** — 사용자가 "예를 들면" 으로 든 것이 요구사항 문장이 된 자리.
3. **선택지를 조기에 닫는 표현** — 하류 단계가 정할 수 있는 것을 지금 정해버린 문장.
   예: 구현 방법("먼저 실패하는 테스트를 쓰고")은 다음 단계의 몫이다.
4. **사용자 결정처럼 표현된 에이전트 추론** — 누가 정했는지가 뒤바뀐 문장. 초안이
   "…하기로 했다" 라고 쓴 것 중 원문에 근거가 없는 것.

**판정에 합류하지 않는다.** 당신의 findings 는 어떤 병합기도 거치지 않고 사용자에게 직접
간다 — verdict 를 내지 말고 항목만 내라.
```

- [ ] **Step 4: 축 락**

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/run_seed_codex_reviewer.sh plugins/spec-distill/scripts/build_seed_codex_prompt.py plugins/spec-distill/scripts/seed-codex-suppression-checklist.md
#
# seed 억제 축의 **세 지점이 서로를 지탱하는가** — 러너의 fail-point · 빌더가 아는 축 ·
# 그 축의 체크리스트 파일 실재.
#
# **`build_brief_codex_prompt.py` 의 `AXES` 와 parity 를 재지 않는다.** 같은 이름이지만
# 뜻이 다르다: 그쪽은 brief 의 codex 프롬프트 축이고, `brief_review_state.py` 의 `AXES` 는
# degrade 원장의 `affected_axis` 이며, 러너의 `case` 는 실제 fail-point 다. 셋을 등식으로
# 묶으면 **술어 자체가 거짓**이 된다 — parity 락을 세우기 전에 두 열거가 같은 것을 뜻하는지
# 먼저 확인해야 한다는 규칙의 실사례다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
S="$ROOT/plugins/spec-distill/scripts"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/run_seed_codex_reviewer.sh"
  echo "plugins/spec-distill/scripts/build_seed_codex_prompt.py"
  echo "plugins/spec-distill/scripts/seed-codex-suppression-checklist.md"
  exit 0
fi

for f in run_seed_codex_reviewer.sh build_seed_codex_prompt.py seed-codex-suppression-checklist.md; do
  [ -f "$S/$f" ] && ok "실재: $f" || no "부재: $f"
done

# ① 러너가 축을 실제로 받는가 — 산문이 아니라 fail-point 로.
grep -qE "^\s*suppression\)" "$S/run_seed_codex_reviewer.sh" \
  && ok "러너 case 가 suppression 을 받는다" \
  || no "러너 case 에 suppression 갈래가 없다 — 호출이 exit 2 로 죽는다"

# ② 빌더가 그 축을 안다.
grep -qE "suppression" "$S/build_seed_codex_prompt.py" \
  && ok "빌더가 suppression 축을 안다" || no "빌더가 suppression 축을 모른다"

# ③ 체크리스트가 **네 축을 전부** 담는가. 하나라도 빠지면 codex 는 그 축을 안 본다.
cl="$S/seed-codex-suppression-checklist.md"
miss=0
for axis in '근거 없이 추가된 제약' '예시를 필수로 오인' '선택지를 조기에 닫는' '에이전트 추론'; do
  grep -qF -- "$axis" "$cl" || { no "체크리스트에 축 누락: ${axis}"; miss=$((miss + 1)); }
done
[ "$miss" -eq 0 ] && ok "체크리스트가 네 축을 전부 담는다"

# ④ 억제 축은 **판정에 합류하지 않는다** — 체크리스트가 verdict 를 요구하면 안 된다.
grep -qE '판정에 합류하지 않는다|verdict 를 내지 말' "$cl" \
  && ok "체크리스트가 verdict 금지를 명시한다" \
  || no "체크리스트에 verdict 금지가 없다 — findings 가 병합기 없이 사용자에게 가는 설계와 어긋난다"

# ⑤ vacuity 하한 — 체크리스트가 비면 위 ③ 이 공허하다.
n="$(wc -l < "$cl" | tr -d ' ')"
[ "${n:-0}" -ge 10 ] && ok "체크리스트 ${n}줄 (vacuous 아님)" \
                     || no "체크리스트가 ${n}줄뿐 — 축 검사가 공허하다"

finish
```

- [ ] **Step 5: kill switch 게이트가 호출자에 있는지 확인**

러너는 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` 를 보지 않는다 — 게이트는 **호출자 책임**이다(`run_spec_codex_reviewer.sh`·`run_brief_codex_reviewer.sh` 와 같은 규약). Task 11 의 SKILL 안에 `detect_codex.sh` 게이트가 실제 `if` 로 있어야 하고, **산문으로 조건을 적고 bash fence 는 무조건 실행되게 두면 안 된다** — 그것이 kill switch 를 「껐다고 믿게만」 만드는 형태다.

Run: `bash plugins/spec-distill/tests/test_web_kill_switch.sh </dev/null | tail -2`
Expected: `Fail: 0`.

- [ ] **Step 6: 로컬 커밋**

```bash
git add plugins/spec-distill/scripts/run_seed_codex_reviewer.sh \
        plugins/spec-distill/scripts/build_seed_codex_prompt.py \
        plugins/spec-distill/scripts/build_seed_inline_blob.py \
        plugins/spec-distill/scripts/seed-codex-suppression-checklist.md \
        plugins/spec-distill/tests/test_seed_codex_axes.sh
git commit -m "feat(spec-distill): seed 억제 축 codex 러너·빌더·체크리스트"
```

### Task 15: mutation 전수 + bump

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md`

- [ ] **Step 1: PR3 의 새 락 6종 전부에 `--emit-scanned` 가 있는지 확인**

Run: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh </dev/null | grep -iE 'seed|compression|request_framing|Fail'`
Expected: `Fail: 0`, 그리고 새 락들이 "미지원" 으로 분류되지 **않아야** 한다.

- [ ] **Step 2: 중복·배포 계약**

Run:
```bash
bash shared/tests/test_no_new_duplication.sh </dev/null | tail -3
bash shared/tests/test_copy_of_contract.sh </dev/null | tail -3
```
Expected: 둘 다 `Fail: 0`.

- [ ] **Step 3: `bash -n` 전수**

Run:
```bash
for f in plugins/spec-distill/scripts/*.sh plugins/spec-distill/tests/test_*.sh; do
  bash -n "$f" || echo "SYNTAX $f"
done
```
Expected: 출력 없음. **모든 shell 편집 뒤에 돈다** — heredoc 파싱 파손은 조용하다.

- [ ] **Step 4: README + bump + CHANGELOG**

`README.md` 에 새 flow 를 넣는다: `/request-framing` → `interview-seed` → (새 세션) `/interview` → `interview-brief` → `brainstorming` → `design`. "Hooks Installed" 는 바뀌지 않는다(이 PR 은 훅을 만들지 않는다). "Principles Instantiated" 에 **P23** 한 줄.

`version` `0.38.0` → `0.39.0`.

```markdown
## [0.39.0] — 2026-08-27

### Added
- **`/request-framing` — 파이프라인 Phase 0.** 사용자의 의도·steering·방향·goal 을 싱크해 새 세션의 첫 턴 메시지 `interview-seed` 로 압축한다. 산출물은 문서가 아니라 **붙여넣는 메시지**이며 절·라벨·태그·URL 이 없다.
- `skills/framing-requests/` — 확산 후 압축 절차. `proceed-gate.md`·`compression.md`·`trivia-escape.md` 채택.
- `agents/seed-critic.md` · `agents/seed-readback.md` — 둘 다 `tools: []`. critic 은 억제 네 축, readback 은 냉독이며 **판정은 사용자가 한다**.
- `references/compression.md` — 압축 규약 공유 계약. **오늘 게이트로 집행하는 것은 seed 뿐**이고 brief 는 재구조화 이후에 채택한다.
- `references/trivia-escape.md` — 5패턴 정의 정본. 두 command 와 `framing-requests` 가 가리킨다.
- `scripts/check_seed.py` — 게이트 넷. seed 본문에 대해서는 **전부 부재 검사**다.
- seed 억제 축 codex 러너·빌더·체크리스트. 억제 findings 는 어떤 병합기도 거치지 않고 사용자에게 직접 간다.
```

- [ ] **Step 5: PR3 전수 확인**

Run: [착수 전 실측 ②](#-락--pr-행렬-도출) 의 전수 스크립트.
Expected: `FAIL plugins/spec-distill/tests/test_hook_output_schema.py` 한 줄만.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs(spec-distill): README flow + v0.39.0"
```

---

## PR4 — 연결 (`0.40.0`)

### Task 16: R1 재정의 · 탐색 경계 · seed 입력 · README

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md`
- Modify: `plugins/spec-distill/commands/interview.md`
- Modify: `plugins/spec-distill/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`

**Interfaces:**
- Consumes: PR3 의 `references/trivia-escape.md` · `interview-seed` 형상
- Produces: 없음 (마지막 PR)

- [ ] **Step 1: R1 재정의 단언을 먼저 쓴다**

```bash
# v0.40.0: R1 의 «받은 요청 재구성» 은 이제 request-framing 이 한다. interview 의 R1 은
# **seed 가 가리키는 작업 뒤의 진짜 문제**를 재구성한다. 명칭 변경이 아니라 R&R 이동이다.
rites_block="$(awk '/^## 5 통과 의례/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
grep -q 'Problem Reframe' <<<"$rites_block" \
  && ok "R1(v0.40.0): Problem Reframe 으로 재정의 (scoped to 5 통과 의례)" \
  || no "R1(v0.40.0): Problem Reframe 으로 재정의 (scoped to 5 통과 의례)"
# 경계 — framing 의 탐색은 «사용자 머릿속», interview 의 탐색은 «문제 공간». 이 문장이
# 없으면 두 단계의 질문이 어느 쪽 것인지 실행 시점에 판정 불가다.
grep -qE 'framing.*웹|웹.*framing|사용자 머릿속|문제 공간' <<<"$rites_block" \
  && ok "R2(v0.40.0): 탐색 경계 명시" || no "R2(v0.40.0): 탐색 경계 명시"
```

- [ ] **Step 2: R1 을 `Problem Reframe` 으로**

5 통과 의례 표의 R1 행:

| # | 의례 | 통과 기준 | 메커니즘 |
|---|---|---|---|
| R1 | **Problem Reframe** | seed 가 가리키는 **작업 뒤의 진짜 문제**를 재구성한 한 문장 문제정의 + 진짜 goal. seed 의 문장을 되풀이하는 것은 통과가 아니다. | (d) ontological 5-type → payload §0 · §1 |

그리고 R2 절에 경계 한 문단:

```markdown
**탐색 경계** — `request-framing` 은 **레포는 읽되 웹은 보지 않는다.** framing 의 공백은
사용자에게 물어서 메운다. 바깥에서 찾는 것은 이 단계(interview)의 R&R 이다 — landscape ·
steelman · blind-spot premortem · coverage-mapper 넷이 전부 그 장치다.

**질문 라우팅** — 답을 사용자만 알 수 있으면 framing, 사용자 밖에서 찾아야 하면 interview.
같은 주제도 이 기준으로 갈린다.
```

- [ ] **Step 3: seed 입력 규약**

`## 종료` 앞에 새 절:

```markdown
## seed 를 입력으로 받았을 때

`$ARGUMENTS` 가 `type: interview-seed` frontmatter 를 가진 문서(또는 그 본문)면, 그것은
**Phase 0 에서 사용자가 확정한 메시지**다.

- **§6 `S1` 은 seed 본문 전체**다. 그것이 이 세션의 최초 사용자 발화다.
- **seed 에는 태그가 없다.** `confirmed`/`inferred`/`open` 구분을 seed 에서 읽으려 하지
  말 것 — Phase 0 이 전문을 사용자 확정으로 만들었으므로 전부 사용자 결정이다.
- **seed 를 뒤집을 수 있다**(P23). 인터뷰 중 사용자가 seed 의 확정을 뒤집으면 **새 발화가
  이긴다** — 그리고 그 뒤집음을 §6 에 새 `S<N>` 으로 추가하고 §5 `기각` 에 *원래 /
  재결정 / 근거* 로 남긴다. 조용히 덮어쓰지 않는다.
- **seed 가 아닌 입력도 그대로 받는다.** `/interview` 는 호환을 유지한다 — 조언 한 줄을
  내되 **차단하지 않는다**.
```

> **「seed 와 인터뷰 중 새 발화의 우선순위」는 설계 §11 이 미정으로 남긴 항목이다.** 여기서 **새 발화가 이긴다**로 정한다 — 근거: P23 이 「하류가 상류를 반증할 수 있다」고 정했고, 사용자 본인의 새 발화보다 강한 근거는 없다. 이것을 다르게 정하고 싶으면 이 불릿 하나를 바꾸면 된다.

- [ ] **Step 4: `/interview` 를 포인터로 + 조언 한 줄**

`commands/interview.md` 의 Step 2 본문 5패턴을 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 포인터로 대체한다. 그리고 Step 3 앞에:

```markdown
## Step 2.5: seed 아닌 입력에 대한 조언 (차단 아님)

`$ARGUMENTS` 가 `interview-seed` 가 아니면 한 줄 안내를 낸다 — **막지 않는다.**

> 💡 `/request-framing` 을 먼저 거치면 첫 턴이 정리된 상태로 시작합니다. 지금 그대로
> 진행해도 됩니다.
```

- [ ] **Step 5: dispatch 회계 재확인**

`commands/interview.md` 는 dispatch 코퍼스에 든다. 편집이 dispatch 줄을 만들거나 앵커 거리를 바꾸지 않았는지 확인한다.

Run: `bash shared/tests/test_dispatch_disposition.sh </dev/null | tail -6`
Expected: `Fail: 0`.

- [ ] **Step 6: bump + CHANGELOG + 전수**

`version` `0.39.0` → `0.40.0`.

```markdown
## [0.40.0] — 2026-08-27

### Changed
- 인터뷰 R1 이 `Reframe (메타 프롬프트)` 에서 **`Problem Reframe`** 으로. 「받은 요청 재구성」은 `request-framing` 이 하고, 여기서는 **seed 가 가리키는 작업 뒤의 진짜 문제**를 재구성한다. 명칭 변경이 아니라 R&R 이동이다.
- `commands/interview.md` 의 trivia 5패턴이 `references/trivia-escape.md` 포인터로.

### Added
- `conducting-interview` 에 seed 입력 규약. seed 본문은 §6 `S1` 이 되고, 인터뷰 중 사용자가 seed 를 뒤집으면 **새 발화가 이기며** 그 재결정이 §5 에 기록된다(P23).
- `/interview` 가 seed 아닌 입력에 조언 한 줄을 낸다 — **차단하지 않는다**(호환 유지).
```

Run: [착수 전 실측 ②](#-락--pr-행렬-도출) 의 전수 스크립트.
Expected: `FAIL plugins/spec-distill/tests/test_hook_output_schema.py` 한 줄만.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(spec-distill): R1 재정의 + seed 입력 규약 + v0.40.0"
```

---

## 이 계획이 닫지 않는 것

설계 §11 이 이월한 것에 **계획이 실측으로 더한 것**을 합쳐 적는다.

| | |
|---|---|
| **`test_hook_output_schema.py` 선재 RED** | cross-resolver. 이 계획의 어느 태스크도 건드리지 않는다. **면제 목록에 이름을 올리는 것이 그 질문을 영구히 닫는다** — 그래서 이유를 함께 적는다: 이 계획의 파일 집합 F 어디에도 그 파일이 없고, 고치려면 세션 id 리졸버 두 벌의 통일이 선행돼야 한다(별건) |
| **채택자 치환 구멍(OQ3)이 이 계획으로 넓어진다** | `test_proceed_gate_adopters.sh` 의 하한은 개수이지 구성원이 아니다. 오늘 치환 변이가 RED 인 것은 유일한 대체 후보 `reviewing-brief/SKILL.md` 가 정지 어휘를 0줄 가진 **우연**인데, `framing-requests` 가 셋째 채택자가 되면 그 우연이 소멸한다. 설계가 세 판본을 시도해 세 번 구멍이 났고 닫지 못했다 |
| **플러그인 레벨 참조 파일의 상호 보증 구멍** | `test_skill_reference_pointers.sh` 의 자기 보증 금지는 **동일 경로만** 막는다. A→B, B→A 는 막지 않는다. 그 락의 헤더가 *"플러그인 레벨 파일이 둘 이상이어야 열린다 … 둘째를 추가한다면 그때 도달성으로 올릴지 결정할 것"* 이라고 예고했고, **이 계획이 둘째와 셋째를 추가한다**(`compression.md`·`trivia-escape.md`). 도달성으로 올릴지는 이 계획이 정하지 않는다 |
| **agent-only 루프의 총량 바운드** | 에피소드 필드 둘은 **밀도**(구간당 1회)를 묶지 **총량**을 묶지 않는다. cap 제거로 정체 구간 수의 상한이 사라졌고 derived 차원 admit 되먹임도 있다 |
| **brief 재구조화 — 이월 항목 다섯** | ① `user_sourced_items` 파서 형식 전환 ② bijection A 의 payload 축 소실 ③ bijection B 의 대상 절 소실 ④ §6 append-only 가드의 관할 이동 ⑤ 픽스처 120건. **선결 문제는 하류 핸드오프 계약**(`superpowers` 는 이 리포 밖이라 `<brief-path>` 하나만 넘기는 계약을 우리가 못 바꾼다) |
| **brief payload URL 제거(B1–B3)** | `landscape_uncited()` 뒤집기 · 양성 짝이 `landscape_present()` 의 sentinel 로 새는 것 · `_web_disabled()` 가드의 의미 반전 — 셋이 얽혀 재구조화와 분리 불가 |
| **「수정」의 정의** | proceed 게이트 3번 선택지가 재취조 · 재깎기 · 직접편집 중 무엇인가. Task 11 의 SKILL 이 셋 다 열어 두고 사용자가 고르게 한다 — **어느 것이 기본인지는 정하지 않았다** |
| **깎기의 기준선** | 「누구에게 자명한가」는 모델 릴리스마다 움직인다. 규칙이 없고, 이것이 seed 길이를 정하는 유일한 레버다 |
| **효과 측정** | 이 단계를 **제거하게 만들** 관측이 정해지지 않았다 |
| **codex 축** | 이 계정에서 한도가 소진돼(2026-09-17 까지) 실행 검증이 불가능하다. 설계 리뷰도 Claude 단독이었다 — **모델 다양성 0 으로 확정됐다.** Task 14 의 러너는 작성되지만 **실호출로 검증되지 않는다** |
| **턴 넘는 강제 경로** | seed → 새 세션 → `/interview` 핸드오프는 **사람의 붙여넣기**다. 리포의 턴-넘김 강제는 Stop 훅 하나뿐이고 목적지가 `reviewing-spec` 으로 하드코딩돼 있다 — Phase 0 핸드오프를 기계로 강제할 자리가 없다. 이 계획은 그것을 만들지 않는다 |
| **`tools: []` 의 런타임 집행을 이 계획이 재확인하지 않는다** | 리포의 `brief-critic`·`brief-readback` 이 이미 `tools: []` 이고 `docs/audits/2026-07-27-spec-distill-zero-tool-probe.md` 의 `**분기 판정:** ZERO_TOOL_OK` 가 P1(정의 resolve) · P2(명시 지시에도 도구 호출 불가) · P3(트랜스크립트 census)로 적대적 확인했다. **다만 그 probe 는 2026-07-27 측정이고 이 계획은 그것을 다시 돌리지 않는다.** Task 12 의 락은 **선언**(`tools: []`)을 재지 **런타임 집행**을 재지 못한다 — 선언이 무시되는 빌드에서는 그 락이 GREEN 인 채로 격리가 없다. PR3 착수 시 probe 를 재실행할지는 이 계획이 정하지 않는다 |
| **정체 감지의 과소계수 · `shared/codex` 의 quota 오분류** | 둘 다 범위 밖. 별도 이슈 |
