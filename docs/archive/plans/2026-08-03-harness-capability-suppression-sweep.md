# 하니스 능력 억제 제거 sweep — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew의 모든 컨텍스트 표면에서 하니스가 모델(Claude·codex)의 능력을 load-bearing 근거 없이 깎는 지점을 제거하고, 재도입을 막는 회귀 락을 mutation으로 이빨을 증명해 남긴다.

**Architecture:** 설계 `docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md`의 S1→S5를 13개 커밋으로 실행한다. 핵심 통찰 하나: **핀의 실제 이빨은 agent frontmatter가 아니라 테스트 락**이다. 따라서 각 태스크는 *"락을 먼저 반전 → RED 확인 → 대상 수정 → GREEN 확인 → mutation으로 이빨 증명"* 순서로 진행하며, 락 반전과 대상 수정은 **같은 커밋**에 들어간다 (락만 먼저 고치면 그 커밋이 baseline보다 red를 늘린다).

**Tech Stack:** Bash 테스트 하니스(`plugins/*/tests/*.sh`, 자체 pass/fail 카운터), Python 3 표준 라이브러리 + `unittest` + `PyYAML`, Markdown(agent frontmatter · SKILL 프로즈 · 템플릿). 신규 런타임 의존성 없음.

## 목차

- [Global Constraints](#global-constraints)
- [측정된 baseline (이 워크트리 실측)](#측정된-baseline-이-워크트리-실측)
- [File Structure](#file-structure)
- [태스크 지도](#태스크-지도)
- [Task 1 — quality-gates 모델 핀 3개](#task-1--quality-gates-모델-핀-3개)
- [Task 2 — spec-distill 모델 핀 4개](#task-2--spec-distill-모델-핀-4개)
- [Task 3 — codex 추론 상한 3 스크립트](#task-3--codex-추론-상한-3-스크립트)
- [Task 4 — 조사 도구 결핍 (S2)](#task-4--조사-도구-결핍-s2)
- [Task 5 — 검색 횟수 상한·병렬 금지 (S3a)](#task-5--검색-횟수-상한병렬-금지-s3a)
- [Task 6 — test-scope-validator 자기모순 (S3b)](#task-6--test-scope-validator-자기모순-s3b)
- [Task 7 — codex 범주 개방 (S3c)](#task-7--codex-범주-개방-s3c)
- [Task 8 — web_budget 상한 제거 (S3d)](#task-8--web_budget-상한-제거-s3d)
- [Task 9 — adversarial 신규 발견 승격 (S3e)](#task-9--adversarial-신규-발견-승격-s3e)
- [Task 10 — ambiguity 단어경계 (S3f)](#task-10--ambiguity-단어경계-s3f)
- [Task 11 — 규약 정렬 (S4)](#task-11--규약-정렬-s4)
- [Task 12 — 메모리 + 과거 기록 (S5)](#task-12--메모리--과거-기록-s5)
- [Task 13 — 최종 검증](#task-13--최종-검증)
- [Self-Review](#self-review)

---

## Global Constraints

설계 §4의 C1–C5 + 이 계획이 실측으로 추가한 것. **모든 태스크의 요구사항은 암묵적으로 이 절을 포함한다.**

| # | 제약 | 정확한 값 |
|---|---|---|
| **C1** | 유지선(약화 금지) | Law 2 물리 분리(리뷰어 `tools:`에 `Write\|Edit\|MultiEdit\|NotebookEdit\|Bash\|Agent\|Monitor\|mcp__` 부재) · kill switch(`DEVBREW_DISABLE_*`, `DEVBREW_SPEC_DISTILL_DISABLE_WEB`) · qg mutation guard/digest seal · 정확성 fail-closed 게이트 · 입력 격리 |
| **C2** | 기록 vs 활성 규칙 | 활성 규칙 표면은 고친다. **이력 표면**(append-only 원장 · 머지된 design/plan · `CHANGELOG.md` · `tests/fixtures/*.audit.md` · `tests/spike/`)은 통째 제거하지 않고 정정을 append한다 |
| **C3** | 사용자 확정 결정 (재질문 금지) | `web_budget.py` 상한 제거·kill switch 유지 / fan-out 숫자 임계 N≥5 제거·`cost_class: high` 승인 게이트 유지 / `security-reviewer` 웹 도구 **미추가** / `adversarial` 신규 발견 승격 허용 / project-init 템플릿 **2개 모두** rebase 조항 완화, 리포 루트 `docs/git-workflow/`는 **불변** / 판정이 갈리면 default는 **제거** |
| **C4** | SemVer | **플러그인을 건드리는 커밋마다** `.claude-plugin/plugin.json` bump + `CHANGELOG.md` 항목. 한 커밋이 두 플러그인을 건드리면 **둘 다** bump |
| **C5** | 회귀 락 이빨 | 각 락은 억제를 되돌리는 mutation에서 **RED**여야 한다. 통과 사실은 이빨의 증거가 아니다. 락 문구는 **body-unique** — 헤더·주석에만 있어도 통과하면 가짜 |
| **C6** | 커밋 유효성 | 각 커밋은 아래 baseline을 **유지하거나 개선**해야 한다. 중간 커밋이 red를 늘리는 것은 허용하지 않는다 |
| **C7** | 버전 리터럴 | patch bump만 사용한다 (아래 [버전 시퀀스](#버전-시퀀스)). minor를 올리면 `test_readme_sync.sh:34`(`"version": "0\.24\.[0-9]+"`)·`test_artifact_metadata.sh:9`·`test_qg_publish_docs.sh:17`의 minor floor 핀이 함께 바뀌어야 한다 |
| **C8** | 문서 규약 | Korean-primary. 영어는 식별자(P#·AP#·Law N·플러그인 이름)·고유명사·원문 인용·자연스러운 한국어 대응이 없는 기술 용어(`frontmatter`·`subagent`·`hook`·`skill`)에 한정 |
| **C9** | **mutation은 커밋 *뒤에*** | 아래 참조 |

### C9 — mutation 순서 (Task 1 실행 중 발견된 계획 결함)

계획 초안은 mutation을 커밋 **앞에** 두고 `git checkout -- <file>`로 복원하라고 적었다. **그 조합은 수정을 조용히 지운다** — 아직 커밋하지 않은 상태에서 `git checkout --`는 HEAD로 되돌리므로, 되돌아가는 지점이 *억제가 살아 있던 원래 상태*다. Task 1 구현자가 실제로 한 번 당했고(즉시 `git diff`로 잡아 커밋에는 잔재가 없었다), Task 2·3·10이 같은 패턴을 반복한다.

**따라서 순서를 고정한다:**

```
락 수정 → RED 확인 → 대상 수정 → GREEN 확인 → 스위트 → bump/CHANGELOG → 커밋
  → mutation (커밋 뒤) → git checkout -- <file> → git status --short 가 깨끗한지 확인
  → 락이 이빨 없으면 락을 고치고 git commit --amend
```

커밋 뒤에 하면 `git checkout --`가 **수정된 상태로** 복원하므로 안전하고, `git status --short`가 비어 있다는 사실이 잔재 없음의 진짜 증거가 된다. 커밋 앞에 mutation을 돌려야 할 이유는 없다 — 이빨이 없는 락이 나오면 `--amend`로 고치면 되고, 아직 push 전이다.

**`git checkout --`를 쓰지 않는 대안도 허용한다**: mutation 전에 `git diff > <workspace>/pre-mutation.patch`를 떠 두고 `git checkout -- <file> && git apply <workspace>/pre-mutation.patch`로 복원. 커밋 앞에서 mutation을 돌려야 하는 상황(예: 커밋 자체가 락 방향에 달려 있을 때)에만 쓴다.

### 버전 시퀀스

C4가 커밋마다 bump를 요구하므로 미리 못 박는다. **태스크를 건너뛰면 그 다음 태스크가 앞 번호를 쓴다** (구멍을 남기지 않는다).

| 태스크 | quality-gates | spec-distill | project-init |
|---|---|---|---|
| 시작점 | `2.14.3` | `0.24.4` | `1.7.2` |
| Task 1 | **2.14.4** | — | — |
| Task 2 | — | **0.24.5** | — |
| Task 3 | **2.14.5** | **0.24.6** | — |
| Task 4 | **2.14.6** | **0.24.7** | — |
| Task 5 | — | **0.24.8** | — |
| Task 6 | **2.14.7** | — | — |
| Task 7 | — | **0.24.9** | — |
| Task 8 | — | **0.24.10** | — |
| Task 9 | **2.14.8** | — | — |
| Task 10 | — | **0.24.11** | — |
| Task 11 | — | — | **1.7.3** |
| Task 12–13 | 변경 없음 (docs·메모리·검증만) | | |

`plugin-audit`은 **이 sweep의 변경 대상이 아니다** — 이미 reference 구현(`model: inherit` + 조사 도구 보유)이다.

**patch를 쓰는 근거**: devbrew 규약은 *"major = breaking, minor = 새 surface, patch = fix"*. 이 sweep은 전부 *잘못 부과된 억제의 제거*이므로 fix다. `web_budget.py` 삭제는 플러그인이 출하하는 surface(command·skill·agent)가 아니라 **내부 스크립트**이고 소비자가 spec-distill 자신뿐이므로(Task 8에서 확인) *"제거 전 one-minor deprecation window"* 규약의 대상이 아니다. 이 판단을 각 CHANGELOG의 `Removed` 항목에 한 줄로 남긴다.

---

## 측정된 baseline (이 워크트리 실측)

설계 §9는 baseline을 *"bash 128개 중 6 red, python green"* 으로 적었다. **이 워크트리에서 실측하니 다르다** — 구현자가 회귀로 오인하지 않도록 여기 못 박는다.

```
bash:  128개 중 7 red
python spec-distill:  177 tests, 1 red
python plugin-audit:  189 tests, 0 red (green)
```

### 7번째 bash red는 워크트리 경로 아티팩트다

`plugins/spec-distill/tests/test_stale_terms.sh`는 **메인 체크아웃에서 9/9 green**이고 이 워크트리에서만 red다. 원인:

```bash
# test_stale_terms.sh 의 production 파일 수집
find "$SD" -type f \
  -not -path '*/tests/*' -not -name 'CHANGELOG.md' \
  -not -path '*/.claude/*' \        # ← 이 절
  ...
```

이 워크트리의 절대경로는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/harness-suppression/...` 이라 **모든 파일 경로가 `/.claude/`를 포함**한다. 따라서 필터가 전체를 제외하고 `prod_files`가 빈 배열이 되어, 테스트 자신의 fail-closed 가드가 발화한다:

```
  ✗ V7: no production files found — find filter broken
```

**이것은 올바른 fail-closed 동작이다** (빈 집합을 "잔존 0"으로 읽지 않는다). 고치지 말 것 — 이 sweep의 대상이 아니고, 워크트리 경로에만 의존한다.

**결과: 이 락은 워크트리에서 커버리지를 주지 않는다.** Task 8·12가 production stale 참조를 남길 수 있으므로, Task 13에서 **메인 체크아웃에서 read-only로 1회 실행**해 실제 커버리지를 확보한다 (절차는 Task 13 Step 3).

### python red 1건도 워크트리 아티팩트다

```
FAIL: test_python_and_bash_resolvers_agree (test_hook_output_schema.TestCrossResolverAdvisory)
AssertionError: .../devbrew/.claude/spec-distill' != '.../harness-suppression/.claude/spec-distill'
  : Python state_path and bash CLAUDE_PROJECT_DIR resolvers disagree. Follow-up PR per spec NG9 needed.
```

기존에 알려진 NG9 cross-resolver red(환경 의존)다. 고치지 말 것.

### baseline 측정 명령 (매 태스크 Step에서 재사용)

```bash
# bash 스위트 — repo root(워크트리 루트)에서 실행
red=0; tot=0
for t in plugins/*/tests/*.sh; do
  tot=$((tot+1))
  bash "$t" >/dev/null 2>&1 || { red=$((red+1)); echo "RED: $t"; }
done
echo "bash total=$tot red=$red"     # 기대: total=128 red=7 (Task 8 이후 total=127 red=6)

# python — repo root에서, pytest 아님(-m unittest만)
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3
python3 -m unittest discover -s plugins/plugin-audit/scripts/tests -p 'test_*.py' 2>&1 | tail -3
```

> **`~/Downloads` TCC 주의**: 권한이 회수되면 `stat`은 되는데 `open`이 실패해 테스트가 **대량** 실패한다. red가 갑자기 수십 건이 되면 회귀가 아니라 권한 문제다. 세션을 재시작하고 Finder에서 폴더를 한 번 연 뒤 재측정한다.

---

## File Structure

### 신규 생성 (2)

| 파일 | 책임 |
|---|---|
| `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` | Task 9. `synthesize_findings.py`의 신규-발견 수용 경로를 **픽스처 JSON/YAML로만** 검증한다 — persona 편집이 이 테스트를 green으로 만들 수 없게 격리 |
| `plugins/spec-distill/tests/test_web_kill_switch.sh` | Task 8. `web_budget.py` 삭제 후 남는 유일한 웹 컨트롤(kill switch)을 **소비자별로 독립** 검증. AC7b·AC7c |

### 삭제 (5)

| 파일 | 근거 |
|---|---|
| `plugins/spec-distill/scripts/web_budget.py` | 카운터·게이트가 모두 사라지면 남는 책임이 없다 (설계 S3d-4) |
| `plugins/spec-distill/tests/test_web_sweep_bound.sh` | 검사 대상이 삭제됐다 |
| `plugins/spec-distill/tests/fixtures/state-web-within.md` | `test_web_sweep_bound.sh` 전용 픽스처 |
| `plugins/spec-distill/tests/fixtures/state-web-over-sweep.md` | 같음 |
| `plugins/spec-distill/tests/fixtures/state-web-over-session.md` | 같음 |
| `plugins/spec-distill/tests/fixtures/state-web-commented-overcap.md` | 같음 |

> 삭제 전 반드시 다른 소비자가 없음을 확인한다 (Task 8 Step 6). `tests/fixtures/*.audit.md` 약 50개와 `state-legacy-interview-round.md`도 카운터 이름을 담지만 **이력 데이터(C2)라 건드리지 않는다** — 과거 인터뷰의 실제 기록이고 `check_brief.py`는 `## 2. Budget` 절을 파싱하지 않는다(Task 8 Step 1에서 재확인).

### 수정 — agents (8)

| 파일 | 무엇 | 태스크 |
|---|---|---|
| `plugins/quality-gates/agents/adversarial.md` | `model:` + 신규 발견 금지 선언 4곳 + `new_findings:` 스키마 | 1, 9 |
| `plugins/quality-gates/agents/pr-understanding-builder.md` | `model:` | 1 |
| `plugins/quality-gates/agents/test-scope-validator.md` | `model:` + Hard Rule 4의 허용 컨텍스트 | 1, 6 |
| `plugins/quality-gates/agents/security-reviewer.md` | 본문 문구만 (`tools:` **불변** — C3) | 4 |
| `plugins/spec-distill/agents/spec-reviewer.md` | `model:` + `tools:`에 `WebSearch` | 2, 4 |
| `plugins/spec-distill/agents/coverage-mapper.md` | `model:` + `tools:`에 `WebSearch, WebFetch` | 2, 4 |
| `plugins/spec-distill/agents/blind-spot-prober.md` | `model:` + 검색 상한·병렬 금지 문구 | 2, 5 |
| `plugins/spec-distill/agents/steelman-builder.md` | `model:` + 검색 상한·병렬 금지 문구 | 2, 5 |

### 수정 — scripts (6)

| 파일 | 무엇 | 태스크 |
|---|---|---|
| `plugins/quality-gates/scripts/run_codex_reviewer.sh` | `-c 'model_reasoning_effort="medium"'` 삭제 | 3 |
| `plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh` | 같음 | 3 |
| `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh` | 같음 | 3 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | 신규 발견 수용 경로 (읽기 쪽 배선) | 9 |
| `plugins/spec-distill/scripts/build_spec_codex_prompt.py` | 범주 6개 폐쇄 → 개방 + `other` | 7 |
| `plugins/spec-distill/scripts/parse_spec_structure.py` | ambiguity 매칭에 단어경계 | 10 |

### 수정 — skills / templates (5)

`plugins/spec-distill/skills/conducting-interview/SKILL.md` (8) · `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (8) · `plugins/spec-distill/templates/interview-audit-template.md` (8) · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md` (1) · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (필요 시 1 — Step에서 확인)

### 수정 — tests (12)

`quality-gates/tests/`: `test_adversarial_model_consistency.sh`(1) · `test_adversarial_persona.sh`(1, 9) · `test_pr_understanding_builder_frontmatter.sh`(1) · `test_test_scope_validator_frontmatter.sh`(1, 6)
`spec-distill/tests/`: `test_spec_reviewer_frontmatter.sh`(2, 4) · `test_coverage_mapper_frontmatter.sh`(2, 4) · `test_blind_spot_prober_frontmatter.sh`(2, 5) · `test_steelman_builder_scope.sh`(2, 5) · `test_run_spec_codex_reviewer.sh`(3) · `test_conducting_interview_stage.sh`(8) · `test_reviewing_brief_skill.sh`(8) · `test_parse_spec_structure.sh`(10)

### 수정 — docs / 규약 (7)

`CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` · `docs/plugin-authoring.md` · `plugins/quality-gates/README.md` · `plugins/project-init/templates/github-flow/branch-strategy.md` · `plugins/project-init/templates/git-flow/branch-strategy.md` · `docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md`(§12 기록)

> `docs/git-workflow/branch-strategy.md`는 **변경 대상이 아니다** (C3 — 사용자 본인 선호). Task 11이 양방향으로 assert한다.
> `plugins/spec-distill/README.md`는 `sonnet`/`opus` 문자열을 담지 않으므로 S1 대상이 아니다 (실측 확인). Task 8에서 kill switch 서술만 재확인한다.

### 수정 — 메타 (6)

3× `.claude-plugin/plugin.json` + 3× `CHANGELOG.md` (quality-gates · spec-distill · project-init)

### 수정 — 메모리 (3, git 밖)

`feedback_respect_upstream_model_hardcoding.md` · `project_spec_distill_interview_coverage_driven.md` · `MEMORY.md` — `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/` 아래. **커밋되지 않으므로** 설계 §12가 유일한 감사 흔적이다 (Task 12).

---

## 태스크 지도

| # | 스테이지 | 산출 | 독립성 |
|---|---|---|---|
| 1 | S1a | quality-gates 모델 핀 3개 → `inherit`, 락 4개 반전 | ✅ |
| 2 | S1b | spec-distill 모델 핀 4개 → `inherit`, 양방향 락 **신설** | ✅ |
| 3 | S1c | codex 추론 상한 3 스크립트 제거, 락 반전 | ✅ |
| 4 | S2 | `spec-reviewer`·`coverage-mapper`에 `WebSearch`, `security-reviewer` 문구 | Task 2 이후 (같은 파일 frontmatter) |
| 5 | S3a | 검색 횟수 상한·병렬 금지 문구 제거 | Task 2 이후 |
| 6 | S3b | `test-scope-validator` 자기모순 해소 | Task 1 이후 |
| 7 | S3c | codex 범주 개방 | ✅ |
| 8 | S3d | `web_budget.py` 삭제 + kill switch 이전 | ✅ |
| 9 | S3e | `adversarial` 신규 발견 승격 (persona + synthesizer) | Task 1 이후 |
| 10 | S3f | ambiguity 단어경계 | ✅ |
| 11 | S4 | 규약 정렬 (`CLAUDE.md`·philosophy·plugin-authoring·템플릿 2개) | ✅ |
| 12 | S5 | 메모리 + 과거 기록 정정 | 1–11 이후 |
| 13 | — | AC13 잔여 질의 전수 + mutation 전량 + `/qg branch` | 전부 이후 |

**순서 의존은 파일 충돌뿐이다.** Task 4·5·6·9는 앞 태스크가 같은 파일을 건드리므로 뒤에 온다. 나머지는 순서 무관 — 하나가 막히면 나머지를 진행한다 (설계 S3의 명시적 요구).

---

## Task 1 — quality-gates 모델 핀 3개

**Files:**
- Modify: `plugins/quality-gates/agents/adversarial.md:4`
- Modify: `plugins/quality-gates/agents/pr-understanding-builder.md:4`
- Modify: `plugins/quality-gates/agents/test-scope-validator.md:3`
- Modify: `plugins/quality-gates/README.md:66,139,143,176`
- Modify: `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:112,126`
- Test: `plugins/quality-gates/tests/test_adversarial_model_consistency.sh:1-17,54-55,81-83`
- Test: `plugins/quality-gates/tests/test_adversarial_persona.sh:2-3,55-56`
- Test: `plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh:19-20`
- Test: `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh:56-58`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` → `2.14.4`
- Modify: `plugins/quality-gates/CHANGELOG.md`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: **양방향 모델 락 패턴** — 이후 Task 2가 그대로 복제한다:
  - positive: `^model: inherit$` 가 **있어야** 한다 (`model:` 줄 자체를 지우는 mutation을 잡는다)
  - negative: `^model: (opus|sonnet|haiku)$` 가 **없어야** 한다 (핀 재도입을 잡는다)
  - 두 assert가 **함께** 있어야 이빨이 있다. 하나만으로는 반대 방향 mutation이 통과한다.

**배경 (구현자가 모르면 놓치는 것):**
`model: opus` 별칭은 현재 세션 세대를 따라가므로 **이 두 핀의 오늘 손실은 0**이다. 그런데도 제거하는 근거는 (a) 잠재 상한과 (b) `cost_class` 자기모순이지, 측정된 downgrade가 **아니다**. `test-scope-validator`의 `model: sonnet`은 다르다 — 실측된 활성 downgrade다(opus-4.8 세션이 sonnet-5를 받은 관측 2회). 리뷰에서 이 둘을 뭉개면 약한 논거가 강한 논거를 끌어내린다.

- [ ] **Step 1: 락을 반전한다 (`test_adversarial_model_consistency.sh`)**

파일 헤더 주석(`:1-17`)이 지금 *opus를 옹호하는 논증*이다. assert만 뒤집고 주석을 두면 문서가 코드보다 강해진다 — 헤더 전체를 교체한다.

```bash
#!/usr/bin/env bash
# Drift guard — adversarial 리뷰어의 모델 선언이 세 곳에서 일관되게 `inherit`인지
# 확인한다. adversarial은 Gate 2의 단일 model-based 판정 병목이다(synthesizer는
# 결정론 스크립트). 그래서 **세션이 쓰는 것과 같은 티어**로 돌아야 한다 — 하니스가
# 여기서 티어를 리터럴로 박으면, 세션이 더 강한 모델을 쓰고 있을 때 판정 병목만
# 조용히 약해진다. 반대로 세션보다 강한 티어를 박으면 비용이 사용자 동의 없이 는다.
# 어느 방향이든 하니스가 사용자의 모델 선택을 덮어쓰는 것이므로 `inherit`이 정답이다.
#
# 이전 버전은 이 자리에서 `opus` 핀을 옹호했다. 그 논증은 "Phase 1 워커가 sonnet"
# 이라는 전제에 기대는데, 워커들도 이 sweep에서 `inherit`이 되어 전제가 사라졌다.
#
# 양방향 락이다 — positive(`inherit` 실재) + negative(고정 티어 부재). 하나만 두면
# 반대 방향 mutation(`model:` 줄 통째 삭제 / 핀 재도입)이 조용히 통과한다.
#
# Single source of truth: agents/adversarial.md frontmatter (`model: inherit`).
# SKILL dispatch는 model override를 pin하지 않는다 — frontmatter에 의존한다.
```

`:54-55`를 교체:

```bash
# 1. Frontmatter is the single source of truth — must be inherit (양방향).
assert_grep "$AGENT" '^model: inherit$' "adversarial.md frontmatter is model: inherit"
assert_not_grep "$AGENT" '^model: (opus|sonnet|haiku)$' "adversarial.md frontmatter pins no fixed tier"
```

`:81-83`을 교체 (README 3곳):

```bash
# 3. README must describe adversarial as inherit, consistently in both the model
#    note and the Gate 2 phase diagram.
assert_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, inherit\)' "README phase diagram tags Adversarial as inherit"
assert_grep "$README" '`adversarial` agent uses `model: inherit`' "README model note states inherit"
assert_not_grep "$README" '`adversarial` agent uses `model: (opus|sonnet|haiku)`' "README model note pins no fixed tier"
```

> `assert_grep`/`assert_not_grep` 둘 다 `grep -qE`를 쓴다(`:30`,`:46`) — ERE alternation이 동작한다. `assert_not_grep`은 파일 부재 시 FAIL로 라우팅하므로 vacuous pass가 없다.

- [ ] **Step 2: 락을 반전한다 (`test_adversarial_persona.sh`)**

`:2-3` 주석에서 `model: opus`를 `model: inherit`으로 바꾸고, `:55-56`을 교체:

```bash
check "frontmatter model inherit" \
  "grep -c '^model: inherit$' '$PERSONA'" 1
assert_absent "고정 티어 핀 없음 (하니스가 세션 모델을 덮어쓰지 않는다)" \
  '^model: (opus|sonnet|haiku)$'
```

> `check`는 `>=` 비교라 `0` 기대값이 vacuous하다(파일 주석이 `:27-29`에서 직접 경고한다). 부재 검사는 반드시 `assert_absent`를 쓴다.

- [ ] **Step 3: 락을 반전한다 (나머지 2개)**

`test_pr_understanding_builder_frontmatter.sh:19-20`:

```bash
grep -qE '^model:[[:space:]]*inherit[[:space:]]*$' <<<"$FM" \
  && pass "model: inherit (세션 티어 — 하니스 하향/상향 없음)" \
  || fail "model: inherit 아님"
grep -qE '^model:[[:space:]]*(opus|sonnet|haiku)[[:space:]]*$' <<<"$FM" \
  && fail "고정 티어 핀 잔존 — 세션 모델을 덮어쓴다" \
  || pass "고정 티어 핀 없음"
```

`test_test_scope_validator_frontmatter.sh:56-58`:

```bash
echo "$FM" | grep -qE '^model:[[:space:]]*inherit$' \
  && { PASS=$((PASS + 1)); note "PASS: model=inherit"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: model field (inherit 아님)"; }
echo "$FM" | grep -qE '^model:[[:space:]]*(opus|sonnet|haiku)$' \
  && { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: 고정 티어 핀 잔존"; } \
  || { PASS=$((PASS + 1)); note "PASS: 고정 티어 핀 없음"; }
```

- [ ] **Step 4: 락이 RED인지 확인한다 (대상은 아직 안 고쳤다)**

```bash
for t in test_adversarial_model_consistency test_adversarial_persona \
         test_pr_understanding_builder_frontmatter test_test_scope_validator_frontmatter; do
  echo "=== $t"; bash "plugins/quality-gates/tests/$t.sh" >/dev/null 2>&1 && echo "GREEN(예상밖)" || echo "RED(정상)"
done
```

Expected: 네 개 전부 `RED(정상)`. 하나라도 GREEN이면 그 락은 **대상을 보고 있지 않다** — 경로·패턴을 다시 확인한다.

- [ ] **Step 5: 대상 3개를 고친다**

```
plugins/quality-gates/agents/adversarial.md:4               model: opus   → model: inherit
plugins/quality-gates/agents/pr-understanding-builder.md:4  model: opus   → model: inherit
plugins/quality-gates/agents/test-scope-validator.md:3      model: sonnet → model: inherit
```

- [ ] **Step 6: 서술 5곳을 동기화한다**

`README.md:66` — `# publish 생성기 — model: opus, tools: Read 1개` → `model: inherit`

`README.md:139` — `매 tier `model: opus`로 고정` → 다음으로 교체:

```
저술을 맡는 `pr-understanding-builder`는 `model: inherit` — 세션이 쓰는 티어를 그대로
받는다(하니스가 티어를 덮어쓰지 않는다). Deep tier만 실행 전 upfront cost 고지
(AskUserQuestion)를 하며,
```

`README.md:143` — 문단 전체를 교체 (지금 opus 선택을 옹호하는 논증이다):

```
`adversarial` agent uses `model: inherit`. It is the **single model-based judgment
gate** in the Review gate: the Phase 1/2 reviewers emit findings and the synthesizer
after it is a deterministic script, so every finding the user sees passed through its
verdict. Its persona runs a per-finding 3-gate verification (real? / introduced-by-this-diff?
/ handled-elsewhere?) plus a severity realist check. Because it is the judgment
bottleneck it must run at **the session's own tier** — pinning a literal tier here
silently downgrades the bottleneck whenever the session runs something stronger, and
silently raises cost whenever it runs something cheaper. Both directions overwrite the
user's model choice, which the harness does not do. Locked bidirectionally by
`tests/test_adversarial_model_consistency.sh` (inherit present AND no fixed tier).
Runs ~once per Review gate fix-loop iteration (≤5×). To reduce its cost, lower the
*number* of Review gate iterations or the diff scope.
```

`README.md:176` — `(Phase 1.5, opus)` → `(Phase 1.5, inherit)`

`publishing-pr-understanding/SKILL.md:112` — `tier 3(large) 또는 큰 changed-set이면 opus 빌더 dispatch **전에 1회**` → `... 빌더 dispatch **전에 1회**` (`opus` 단어만 제거)

`publishing-pr-understanding/SKILL.md:126` — `` `model: opus`는 빌더 frontmatter에 고정(여기서 override하지 않음). `` → `` `model: inherit`이 빌더 frontmatter에 선언돼 있다(여기서 override하지 않음). ``

- [ ] **Step 7: 네 락이 GREEN인지 확인한다**

```bash
for t in test_adversarial_model_consistency test_adversarial_persona \
         test_pr_understanding_builder_frontmatter test_test_scope_validator_frontmatter; do
  printf '%-48s ' "$t"; bash "plugins/quality-gates/tests/$t.sh" >/dev/null 2>&1 && echo GREEN || echo RED
done
```

Expected: 네 개 전부 GREEN.

- [ ] **Step 8: mutation으로 이빨을 증명한다 (양방향)**

> ⚠️ **C9 정정 (Task 1 실행 중 발견).** 아래는 mutation을 커밋 *앞에* 두고 `git checkout --`로
> 복원하는데, **그 조합은 아직 커밋되지 않은 Step 5의 수정을 지운다** — `git checkout --`가
> 되돌아가는 지점이 HEAD, 즉 억제가 살아 있던 상태이기 때문이다. Task 1은 이 함정에 한 번
> 걸렸고 복원 방식을 바꿔 통과했다. **Task 2 이후는 mutation을 커밋 뒤에 돌린다 (C9).** 이
> 태스크를 다시 실행한다면 Step 8을 Step 11 뒤로 옮길 것.

```bash
A=plugins/quality-gates/agents/adversarial.md
# mutation 1 — 핀 재도입
sed -i '' 's/^model: inherit$/model: opus/' "$A"
bash plugins/quality-gates/tests/test_adversarial_model_consistency.sh >/dev/null 2>&1 \
  && echo "❌ 락에 이빨 없음 (핀 재도입이 통과)" || echo "✅ mutation 1 RED"
sed -i '' 's/^model: opus$/model: inherit/' "$A"

# mutation 2 — model: 줄 통째 삭제 (positive assert가 있어야 잡힌다)
sed -i '' '/^model: inherit$/d' "$A"
bash plugins/quality-gates/tests/test_adversarial_model_consistency.sh >/dev/null 2>&1 \
  && echo "❌ positive assert 없음 (줄 삭제가 통과)" || echo "✅ mutation 2 RED"
git checkout -- "$A"
```

Expected: `✅ mutation 1 RED` + `✅ mutation 2 RED`. 나머지 세 락도 같은 두 mutation을 각자의 agent 파일에 적용해 확인한다.

> **`git checkout --`로 되돌린 뒤 `git status`가 깨끗한지 확인**한다. mutation 잔재가 커밋에 섞이면 그 커밋이 억제를 되돌린다.

- [ ] **Step 9: 스위트 전체가 baseline을 넘지 않는지 확인한다**

```bash
red=0; for t in plugins/*/tests/*.sh; do bash "$t" >/dev/null 2>&1 || { red=$((red+1)); echo "RED: $t"; }; done; echo "red=$red"
```

Expected: `red=7` (baseline과 동일, 목록도 동일).

- [ ] **Step 10: 버전 bump + CHANGELOG**

`plugins/quality-gates/.claude-plugin/plugin.json` → `"version": "2.14.4"`

`plugins/quality-gates/CHANGELOG.md` 최상단에 추가:

```markdown
## [2.14.4] — 2026-08-03

### Changed
- `adversarial` · `pr-understanding-builder` · `test-scope-validator`의 `model:` 리터럴 핀
  (`opus`/`opus`/`sonnet`)을 `model: inherit`으로 교체. 하니스가 세션의 모델 선택을 덮어쓰지
  않는다 — 리터럴 핀은 세션이 더 강한 모델을 쓸 때 조용히 하향시키고(`test-scope-validator`는
  opus-4.8 세션에서 sonnet-5로 실행된 관측 2회), 더 약한 모델을 쓸 때 사용자 동의 없이 비용을
  올린다. `plugin-audit` 3개 에이전트가 이미 쓰던 reference 패턴을 전파한 것이다.
- 모델 락 4개를 **양방향**으로 교체 — `inherit` 실재(positive) + 고정 티어 부재(negative).
  한쪽만으로는 반대 방향 mutation(`model:` 줄 삭제 / 핀 재도입)이 통과한다.
- README·`publishing-pr-understanding` SKILL의 모델 서술 5곳 동기화.
```

- [ ] **Step 11: 커밋**

```bash
git add plugins/quality-gates/agents/adversarial.md \
        plugins/quality-gates/agents/pr-understanding-builder.md \
        plugins/quality-gates/agents/test-scope-validator.md \
        plugins/quality-gates/README.md \
        plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md \
        plugins/quality-gates/tests/test_adversarial_model_consistency.sh \
        plugins/quality-gates/tests/test_adversarial_persona.sh \
        plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh \
        plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh \
        plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md
git commit -m "fix(quality-gates): 모델 리터럴 핀 3개 제거 — 하니스가 세션 티어를 덮어쓰지 않는다

adversarial·pr-understanding-builder(opus) / test-scope-validator(sonnet)를
model: inherit으로. 핀의 실제 이빨은 frontmatter가 아니라 테스트 락이므로 락 4개를
같은 커밋에서 양방향(inherit 실재 + 고정 티어 부재)으로 반전했다. 두 방향 mutation
(핀 재도입 / model: 줄 삭제) 모두 RED 확인."
```

---

## Task 2 — spec-distill 모델 핀 4개

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md:3`
- Modify: `plugins/spec-distill/agents/coverage-mapper.md:3`
- Modify: `plugins/spec-distill/agents/blind-spot-prober.md:3`
- Modify: `plugins/spec-distill/agents/steelman-builder.md:3`
- Test: `plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh`
- Test: `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`
- Test: `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh`
- Test: `plugins/spec-distill/tests/test_steelman_builder_scope.sh`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` → `0.24.5`
- Modify: `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1의 양방향 모델 락 패턴 (positive `^model: inherit$` + negative `^model: (opus|sonnet|haiku)$`)
- Produces: 없음 (Task 4·5가 같은 4개 파일의 *다른* 부분을 건드린다)

**Task 1과 결정적으로 다른 점:** 이 네 테스트는 **`model:`에 대한 assert가 아예 없다.** 반전할 락이 없고 **신설**해야 한다. 따라서 Step 1의 RED는 "락이 틀렸다"가 아니라 "락이 없어서 아무것도 안 잡는다"를 먼저 증명하는 형태가 된다.

`spec-distill:spec-reviewer`의 `model: sonnet`은 **이 sweep 전체에서 가장 강한 증거**를 가진 항목이다 — 지난 일주일 spec-review 6회가 전부 opus-5 세션에서 sonnet-5로 돌았다. 리뷰어가 writer보다 약한 상태가 매 dispatch 재현됐다.

- [ ] **Step 1: 락 부재를 먼저 확인한다 (신설의 근거)**

```bash
grep -c '^model:' plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh \
                  plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh \
                  plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh \
                  plugins/spec-distill/tests/test_steelman_builder_scope.sh
```

Expected: 네 파일 모두 `0`. 즉 `model:`을 `haiku`로 바꿔도 스위트가 GREEN이다 — 이것이 신설 근거다.

- [ ] **Step 2: 그 사실을 실제로 증명한다 (신설 전 mutation)**

```bash
sed -i '' 's/^model: sonnet$/model: haiku/' plugins/spec-distill/agents/spec-reviewer.md
bash plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh >/dev/null 2>&1 \
  && echo "✅ 확인: 락이 없어 haiku 강등이 조용히 통과한다" || echo "❌ 예상밖 RED"
git checkout -- plugins/spec-distill/agents/spec-reviewer.md
```

Expected: `✅ 확인: ...`. 이 관측이 Step 3의 락이 무엇을 막는지에 대한 근거다.

- [ ] **Step 3: 네 테스트에 양방향 모델 락을 신설한다**

각 파일의 `FM`/`fm` 추출 직후, `name:` assert 옆에 삽입한다. **`test_spec_reviewer_frontmatter.sh`** (`FM=` 다음 줄):

```bash
# 모델 티어 양방향 락 — 하니스가 세션의 모델 선택을 덮어쓰지 않는다.
# 이 리뷰어는 devbrew에서 가장 많이 dispatch되는 리뷰어인데 `model: sonnet`으로
# 핀돼 있었다: 실측 6회 전부 opus-5 세션이 sonnet-5 리뷰어를 받았다 — 리뷰어가
# writer보다 약한 상태가 매 dispatch 재현됐다.
# positive+negative 둘 다 필요하다. negative만 두면 `model:` 줄을 통째로 지워도
# 통과하고, positive만 두면 두 줄을 넣는 mutation이 통과한다.
grep -qE '^model: inherit$' <<<"$FM" \
  && note PASS "model: inherit (세션 티어 상속)" \
  || note FAIL "model이 inherit이 아님 — 하니스가 티어를 덮어쓴다"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$FM" \
  && note FAIL "고정 티어 핀 잔존" \
  || note PASS "고정 티어 핀 없음"
```

**`test_coverage_mapper_frontmatter.sh`**·**`test_blind_spot_prober_frontmatter.sh`**: 같은 두 assert를 `note PASS/FAIL` 헬퍼로 삽입 (세 파일 모두 `note()` 시그니처가 동일하다). 주석은 각 에이전트에 맞게 한 줄로 줄인다:

```bash
# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$FM" \
  && note PASS "model: inherit (세션 티어 상속)" || note FAIL "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$FM" \
  && note FAIL "고정 티어 핀 잔존" || note PASS "고정 티어 핀 없음"
```

**`test_steelman_builder_scope.sh`**는 변수명이 소문자 `fm`이다:

```bash
# 모델 티어 양방향 락 — 하니스가 세션 모델을 덮어쓰지 않는다(리터럴 핀 = 조용한 하향).
grep -qE '^model: inherit$' <<<"$fm" \
  && note PASS "model: inherit (세션 티어 상속)" || note FAIL "model이 inherit이 아님"
grep -qE '^model: (opus|sonnet|haiku)$' <<<"$fm" \
  && note FAIL "고정 티어 핀 잔존" || note PASS "고정 티어 핀 없음"
```

- [ ] **Step 4: 네 테스트가 RED인지 확인한다**

```bash
for t in test_spec_reviewer_frontmatter test_coverage_mapper_frontmatter \
         test_blind_spot_prober_frontmatter test_steelman_builder_scope; do
  printf '%-42s ' "$t"; bash "plugins/spec-distill/tests/$t.sh" >/dev/null 2>&1 && echo "GREEN(예상밖)" || echo "RED(정상)"
done
```

Expected: 네 개 전부 `RED(정상)`.

- [ ] **Step 5: 네 agent를 고친다**

```
plugins/spec-distill/agents/spec-reviewer.md:3       model: sonnet → model: inherit
plugins/spec-distill/agents/coverage-mapper.md:3     model: sonnet → model: inherit
plugins/spec-distill/agents/blind-spot-prober.md:3   model: sonnet → model: inherit
plugins/spec-distill/agents/steelman-builder.md:3    model: sonnet → model: inherit
```

- [ ] **Step 6: GREEN 확인**

```bash
for t in test_spec_reviewer_frontmatter test_coverage_mapper_frontmatter \
         test_blind_spot_prober_frontmatter test_steelman_builder_scope; do
  printf '%-42s ' "$t"; bash "plugins/spec-distill/tests/$t.sh" >/dev/null 2>&1 && echo GREEN || echo RED
done
```

Expected: GREEN ×4. **mutation은 커밋 뒤 Step 8에서 돈다 (C9)** — 커밋 전에 `git checkout --`로 복원하면 수정이 통째로 지워진다.

- [ ] **Step 7: 스위트 확인 + bump + CHANGELOG + 커밋**

```bash
red=0; for t in plugins/*/tests/*.sh; do bash "$t" >/dev/null 2>&1 || red=$((red+1)); done; echo "red=$red"   # 기대: 7
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3   # 기대: 1 red (NG9)
```

`.claude-plugin/plugin.json` → `"version": "0.24.5"`. CHANGELOG 최상단:

```markdown
## [0.24.5] — 2026-08-03

### Changed
- `spec-reviewer` · `coverage-mapper` · `blind-spot-prober` · `steelman-builder`의
  `model: sonnet` 리터럴 핀을 `model: inherit`으로 교체. **실측된 활성 손실이다** —
  지난 일주일 spec-review 6회가 전부 opus-5 세션에서 sonnet-5로 실행됐다(리뷰어가
  writer보다 약한 상태가 매 dispatch 재현). steelman-builder 1회도 같은 패턴.

### Added
- 네 에이전트 frontmatter 테스트에 **양방향 모델 락 신설** — 이전에는 `model:`에 대한
  assert가 아예 없어서 `haiku`로 강등해도 스위트가 GREEN이었다(신설 전 mutation으로 확인).
  positive(`inherit` 실재) + negative(고정 티어 부재) 둘 다 둔다.
```

```bash
git add plugins/spec-distill/agents/spec-reviewer.md \
        plugins/spec-distill/agents/coverage-mapper.md \
        plugins/spec-distill/agents/blind-spot-prober.md \
        plugins/spec-distill/agents/steelman-builder.md \
        plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh \
        plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh \
        plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh \
        plugins/spec-distill/tests/test_steelman_builder_scope.sh \
        plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md
git commit -m "fix(spec-distill): sonnet 핀 4개 제거 — 리뷰어가 writer보다 약했다

spec-review 6회 실측 전부 opus-5 세션 → sonnet-5 리뷰어. model: inherit으로 교체하고,
네 frontmatter 테스트에 양방향 모델 락을 신설했다 — 기존에는 model: assert가 없어
haiku 강등도 조용히 통과했다(신설 전 mutation으로 확인)."
```

- [ ] **Step 8: mutation 양방향 (커밋 뒤 — C9)**

네 에이전트 각각에 대해 반복한다. 아래는 `spec-reviewer` 예시:

```bash
A=plugins/spec-distill/agents/spec-reviewer.md
T=plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh

# mutation 1 — 핀 재도입
sed -i '' 's/^model: inherit$/model: sonnet/' "$A"
bash "$T" >/dev/null 2>&1 && echo "❌ 핀 재도입이 통과 (락에 이빨 없음)" || echo "✅ mutation 1 RED"
git checkout -- "$A"

# mutation 2 — model: 줄 통째 삭제 (positive assert가 있어야 잡힌다)
sed -i '' '/^model: inherit$/d' "$A"
bash "$T" >/dev/null 2>&1 && echo "❌ 줄 삭제가 통과 (positive assert 없음)" || echo "✅ mutation 2 RED"
git checkout -- "$A"

git status --short plugins/spec-distill/agents/    # 비어 있어야 한다
```

Expected: 에이전트 4개 × mutation 2방향 = `✅` 8건, 그리고 `git status`가 **빈 출력**. 커밋 뒤라 `git checkout --`가 *수정된* 상태로 복원한다 — 커밋 전에 같은 명령을 쓰면 수정이 지워진다(C9).

이빨 없는 락이 나오면 락을 고치고 `git commit --amend` 한다 (아직 push 전이다).

---

## Task 3 — codex 추론 상한 3 스크립트

**Files:**
- Modify: `plugins/quality-gates/scripts/run_codex_reviewer.sh:99-112`
- Modify: `plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh:36-39`
- Modify: `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh:65-72`
- Test: `plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh:35-36`
- Test(신규 assert): `plugins/quality-gates/tests/` 안에 codex 러너 상한 부재 락 (아래 Step 3에서 위치 확정)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` → `2.14.5`, `plugins/spec-distill/.claude-plugin/plugin.json` → `0.24.6`
- Modify: 두 `CHANGELOG.md`

**Interfaces:**
- Consumes: 없음
- Produces: **codex 상한 부재 락 패턴** — 리포에 이미 있는 `plugins/spec-distill/tests/test_brief_codex_axes.sh:90-91`을 그대로 전파한다:

```bash
grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUNNER" \
  && note FAIL "runner가 model_reasoning_effort를 인자로 핀 — 사용자 설정을 하향 억제한다" \
  || note PASS "model_reasoning_effort 미핀 (사용자 codex 설정이 지배)"
```

**발명하지 않는다.** `plugins/spec-distill/scripts/run_brief_codex_reviewer.sh:88-91`이 **이미 올바른 참조 구현**이고, 주석까지 이 sweep의 논거를 그대로 쓰고 있다:

```bash
# 추론 강도(`model_reasoning_effort`)는 **핀하지 않는다.** 사용자 codex 설정이 지배한다.
# 하니스가 여기서 "medium"을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다 — 하니스는 능력을
# 억제하지 않는다. 바닥값이 필요하다는 판단이 서면 그때 명시적으로 문서화해서 넣는다.
```

세 스크립트에 같은 주석을 옮긴다 (문구는 각 스크립트의 역할에 맞게 첫 줄만 조정).

- [ ] **Step 1: 기존 락을 반전한다 (`test_run_spec_codex_reviewer.sh:35-36`)**

지금은 상한을 **요구**한다:

```bash
grep -qE 'model_reasoning_effort.*medium' "$RUN" \
  && note PASS "OQ2: model_reasoning_effort=medium" || note FAIL "OQ2: effort not medium"
```

교체:

```bash
# 추론 강도 상한 부재 락 — `run_brief_codex_reviewer.sh`가 이미 쓰는 계약을 전파한다.
# 하니스가 medium을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# codex co-review의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
# `-c` 인자 줄만 본다 — 주석·문서에서 이름을 *언급*하는 것은 위반이 아니다(실행 경로가 기준).
grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUN" \
  && note FAIL "추론 강도가 실행 인자로 핀됨 — 사용자 codex 설정을 하향 억제한다" \
  || note PASS "추론 강도 미핀 (사용자 codex 설정이 지배)"
# 반대 방향 — 상한 제거가 샌드박스까지 걷어내지 않았음을 증명한다(C1 유지선).
grep -qE '^[[:space:]]*-s read-only' "$RUN" \
  && note PASS "Law2: -s read-only 샌드박스 플래그 존속" || note FAIL "-s read-only 사라짐"
grep -qE '^[[:space:]]*-C ' "$RUN" \
  && note PASS "-C 작업디렉토리 핀 존속" || note FAIL "-C 사라짐"
grep -qE '^[[:space:]]*--json' "$RUN" \
  && note PASS "--json 파싱 계약 존속" || note FAIL "--json 사라짐"
```

기존 `:37-38`의 `-s read-only` assert는 위 블록이 흡수하므로 **중복 줄을 삭제**한다 (남기면 같은 사실을 두 번 세어 카운트만 부풀린다).

- [ ] **Step 2: RED 확인**

```bash
bash plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh 2>&1 | grep -E '추론 강도|read-only|-C |--json'
```

Expected: `✗ 추론 강도가 실행 인자로 핀됨 …` (아직 스크립트를 안 고쳤으므로).

- [ ] **Step 3: quality-gates 쪽 락을 신설한다**

먼저 두 러너에 대한 기존 락이 있는지 확인한다:

```bash
grep -rln 'run_codex_reviewer\|run_artifact_codex_reviewer' plugins/quality-gates/tests/*.sh
```

- 이미 러너를 검사하는 테스트가 있으면 **그 파일에** 위 4-assert 블록을 추가한다.
- 없으면 신규 파일 `plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh`를 만든다:

```bash
#!/usr/bin/env bash
# codex 러너 능력 상한 부재 락 — 두 러너(`run_codex_reviewer.sh` ·
# `run_artifact_codex_reviewer.sh`)가 `model_reasoning_effort`를 실행 인자로 핀하지
# 않으면서, load-bearing 플래그(`-s read-only` 샌드박스 · `-C` 작업디렉토리 핀 ·
# `--json` 파싱 계약)는 그대로 유지하는지 확인한다.
#
# 왜 양방향인가: 상한만 지우고 샌드박스까지 함께 지우면 이 sweep이 보안 컨트롤을
# 걷어낸 것이 된다(C1 유지선). 두 방향을 같이 재야 "상한만" 사라졌음이 증명된다.
# `-c` 인자 줄에만 앵커한다 — 주석·문서가 이름을 언급하는 것은 위반이 아니다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

for r in run_codex_reviewer run_artifact_codex_reviewer; do
  RUN="$ROOT/scripts/$r.sh"
  if [[ ! -f "$RUN" ]]; then note FAIL "$r.sh 부재"; continue; fi
  grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUN" \
    && note FAIL "$r: 추론 강도가 실행 인자로 핀됨 — 사용자 codex 설정을 하향 억제한다" \
    || note PASS "$r: 추론 강도 미핀 (사용자 codex 설정이 지배)"
  grep -qE '^[[:space:]]*-s read-only' "$RUN" \
    && note PASS "$r: -s read-only 샌드박스 존속" || note FAIL "$r: -s read-only 사라짐"
  grep -qE '^[[:space:]]*-C ' "$RUN" \
    && note PASS "$r: -C 작업디렉토리 핀 존속" || note FAIL "$r: -C 사라짐"
  grep -qE '^[[:space:]]*--json' "$RUN" \
    && note PASS "$r: --json 파싱 계약 존속" || note FAIL "$r: --json 사라짐"
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh
bash plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh
```

Expected: `Fail: 2` (두 러너의 상한 핀).

- [ ] **Step 4: 세 스크립트에서 플래그 한 줄만 지운다**

각 파일에서 `-c 'model_reasoning_effort="medium"' \` 줄을 삭제하고, 바로 위 주석 블록에 근거를 남긴다.

`run_codex_reviewer.sh` — `:99-112`가 다음이 되게 한다:

```bash
# Canonical codex invocation (spec §4.3 — load-bearing flags preserved):
#   -s read-only     : Layer 3 sandbox (file-system writes blocked)
#   -C "$PROJECT_DIR": working directory pin (single pipeline coordinate)
#   --json           : JSONL stream output
#   < /dev/null      : detach stdin (prevents stdin deadlock on some codex versions)
#
# 추론 강도(`model_reasoning_effort`)는 핀하지 않는다 — 사용자 codex 설정이 지배한다.
# 하니스가 "medium"을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다. 바닥값이
# 필요하다는 판단이 서면 그때 명시적으로 문서화해서 넣는다.
# (`run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.)
#
# Direct codex invocation — no per-call timeout (hang risk accepted; backstops:
# Bash tool timeout, DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg). Layer 3 sandbox
# (-s read-only) preserved. `|| EXIT_CODE=$?` keeps capture safe under set -e.
EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?
```

`run_artifact_codex_reviewer.sh` `:35-43` — 같은 방식으로 `-c` 줄만 삭제하고 그 위에 3줄 요약 주석:

```bash
# 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 medium을 박으면
# high/xhigh 사용자가 조용히 하향되고, 그 하향이 별-모델 적발력을 정확히 깎는다.
# 샌드박스(-s read-only)·작업디렉토리 핀(-C)·파싱 계약(--json)은 load-bearing이라 유지.
EXIT_CODE=0
codex exec "$(cat "$PROMPT")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < /dev/null \
    > "$JSONL" \
    2>"$ERR" || EXIT_CODE=$?
```

`run_spec_codex_reviewer.sh` `:65-72` — `:66-67`의 플래그 설명 주석을 유지하고 같은 3줄을 덧붙인 뒤 `-c` 줄 삭제:

```bash
# Canonical codex invocation (load-bearing flags preserved):
#   -s read-only  : Layer 3 sandbox (writes blocked)   | --json : JSONL stream
#   -C            : working-dir pin                     | </dev/null : stdin detach
# 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 medium을 박으면
# high/xhigh 사용자가 조용히 하향되고, 그 하향이 이 co-reviewer의 존재 이유(별-모델
# 적발력)를 정확히 깎는다.
EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?
```

- [ ] **Step 5: GREEN 확인 (행위 테스트 포함)**

```bash
bash plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh
bash plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh
```

Expected: 둘 다 `Fail: 0`. `test_run_spec_codex_reviewer.sh`는 mock codex를 PATH에 올려 **실제 실행 경로**까지 통과시키므로, 플래그 삭제가 `codex exec` 호출을 깨뜨리지 않았음이 함께 증명된다.

- [ ] **Step 6: 잔여 매칭을 확인하고 등재한다 (AC13)**

```bash
grep -rn 'model_reasoning_effort' plugins/ | grep -v CHANGELOG
```

Expected: 남는 것은 아래 셋뿐이고, 전부 **실행 인자가 아니다**:

| 위치 | 성격 | 처리 |
|---|---|---|
| `plugins/spec-distill/scripts/run_brief_codex_reviewer.sh:88` | 주석 — 핀하지 *않는* 이유 설명 | 유지 (이 sweep의 참조 구현) |
| `plugins/spec-distill/tests/test_brief_codex_axes.sh:86,90` | 부재 락의 assert 인자 | 유지 (부재를 assert하려면 이름을 써야 한다) |
| `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh:33` | **spike 기록** — 스위트에서 실행되지 않는다(`plugins/*/tests/*.sh` glob 밖) | 유지 (C2 이력) |

세 스크립트에 새로 넣은 주석도 매칭되지만 같은 이유로 유지한다. **실행 인자 매칭이 0인지**를 다음으로 확정한다:

```bash
grep -rnE "^[[:space:]]*-c .*model_reasoning_effort" plugins/*/scripts/
```

Expected: 출력 없음 (exit 1).

- [ ] **Step 7: 스위트 + 두 플러그인 bump + 커밋**

```bash
red=0; for t in plugins/*/tests/*.sh; do bash "$t" >/dev/null 2>&1 || red=$((red+1)); done; echo "red=$red"
```

Expected: `red=7` (신규 테스트 1개 추가로 total은 129).

`quality-gates` → `2.14.5`, `spec-distill` → `0.24.6`. 두 CHANGELOG에 같은 취지의 항목:

```markdown
### Changed
- `run_codex_reviewer.sh` · `run_artifact_codex_reviewer.sh`(qg) /
  `run_spec_codex_reviewer.sh`(spec-distill)에서 `-c 'model_reasoning_effort="medium"'`
  실행 인자 삭제. 하니스가 medium을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고,
  그 하향은 codex co-review의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
  `run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.
  **load-bearing 플래그는 그대로다** — `-s read-only`(샌드박스) · `-C`(작업디렉토리 핀) ·
  `--json`(파싱 계약) · `< /dev/null`(stdin detach).

### Added
- codex 러너 상한 부재 락(양방향) — 상한 재삽입과 샌드박스 제거 **둘 다** RED.
  한 방향만 재면 "상한만 사라졌다"를 증명하지 못한다.
```

```bash
git add plugins/quality-gates/scripts/run_codex_reviewer.sh \
        plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh \
        plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh \
        plugins/spec-distill/scripts/run_spec_codex_reviewer.sh \
        plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh \
        plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "fix(quality-gates,spec-distill): codex 추론 상한 제거 — 사용자 설정이 지배한다

세 러너에서 -c model_reasoning_effort=medium 실행 인자만 삭제. -s read-only·-C·--json은
유지하고, 그 사실을 락으로 양방향 증명했다(상한 재삽입 RED + 샌드박스 제거 RED).
run_brief_codex_reviewer.sh가 이미 쓰던 계약을 전파한 것이다."
```

- [ ] **Step 8: mutation 양방향 (커밋 뒤 — C9)**

세 러너 각각에 대해 반복한다. 아래는 `run_spec_codex_reviewer.sh` 예시:

```bash
R=plugins/spec-distill/scripts/run_spec_codex_reviewer.sh
T=plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh

# mutation 1 — 상한 재삽입 (`-s read-only` 줄 뒤에 한 줄 끼워넣는다)
awk '{print} /^    -s read-only \\$/{print "    -c '"'"'model_reasoning_effort=\"medium\"'"'"' \\"}' \
  "$R" > "$R.mut" && mv "$R.mut" "$R"
bash "$T" >/dev/null 2>&1 && echo "❌ 상한 재삽입이 통과 (락에 이빨 없음)" || echo "✅ mutation 1 RED"
git checkout -- "$R"

# mutation 2 (반대 방향) — 샌드박스 제거. 상한 제거가 보안까지 걷어내지 않았음을 증명한다.
sed -i '' '/^    -s read-only \\$/d' "$R"
bash "$T" >/dev/null 2>&1 && echo "❌ 샌드박스 제거가 통과" || echo "✅ mutation 2 RED"
git checkout -- "$R"

git status --short plugins/spec-distill/scripts/ plugins/quality-gates/scripts/   # 비어 있어야 한다
```

quality-gates 두 러너는 같은 두 mutation을 적용하고 `test_codex_runner_no_effort_pin.sh`로 확인한다.

Expected: 러너 3개 × 2방향 = `✅` 6건 + `git status` 빈 출력. **mutation 1의 `.mut` 임시파일이 남지 않았는지** `git status`로 함께 확인한다 — `mv`가 실패하면 추적되지 않은 파일이 남는다.

이빨 없는 락이 나오면 락을 고치고 `git commit --amend` 한다.

---

여기까지가 S1(모델·추론 핀) 전체다. **Task 4 이후는 이어지는 문서에서 계속한다** — 아래 [남은 태스크 요지](#남은-태스크-요지)가 4–13의 확정된 설계이고, 각 태스크의 step 분해는 앞의 셋과 동일한 형태(락 반전/신설 → RED → 대상 수정 → GREEN → 양방향 mutation → 스위트 → bump/CHANGELOG → 커밋)를 따른다.

## 남은 태스크 요지

> 이 절은 Task 4–13의 **확정 사항**(파일·정확한 문자열·인터페이스·mutation)을 담는다. 실행 전에 각 태스크를 앞 셋과 같은 step 형식으로 펼친다.

### Task 4 — 조사 도구 결핍 (S2)

`spec-reviewer`는 지금 `tools: Read, Grep, Glob, WebFetch` — **URL은 열 수 있는데 찾을 수는 없는** 비대칭이다. `coverage-mapper`는 웹 도구가 아예 없다.

| 파일 | before | after |
|---|---|---|
| `agents/spec-reviewer.md` | `tools: Read, Grep, Glob, WebFetch` | `tools: Read, Grep, Glob, WebSearch, WebFetch` |
| `agents/coverage-mapper.md` | `tools: Read, Grep, Glob` | `tools: Read, Grep, Glob, WebSearch, WebFetch` |

두 락이 **정확일치**라 함께 고치지 않으면 RED다:
- `test_spec_reviewer_frontmatter.sh:16` `'^tools: Read, Grep, Glob, WebFetch$'` → `'^tools: Read, Grep, Glob, WebSearch, WebFetch$'`
- `test_coverage_mapper_frontmatter.sh:17` `'^tools: Read, Grep, Glob$'` → `'^tools: Read, Grep, Glob, WebSearch, WebFetch$'`

두 파일 모두에 조용한-열화 방지 assert를 추가한다. 선례는 **`test_steelman_builder_scope.sh`** 다
(초안은 `blind-spot-prober`로 잘못 귀속했다 — 그 파일에는 이 패턴이 없다. Task 4 구현자 적발):

```bash
for tool in WebSearch WebFetch; do
  grep -qE "^tools:.*${tool}" <<<"$FM" \
    && note PASS "tools: 에 $tool 유지" \
    || note FAIL "tools: 에서 $tool 이 사라졌다 — 외부 근거 확인 불가"
done
```

**Law 2 무손상**: 두 락의 기존 `for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor` 루프와 `mcp__` assert는 **그대로 둔다**. 도구 추가가 그 루프를 통과하는지 GREEN으로 확인한다.

**`security-reviewer`는 `tools:`를 바꾸지 않는다** (C3). `agents/security-reviewer.md:38` 부근의 CVE 관련 문구만 고쳐, "CVE 미판정"을 약점이 아니라 **명시된 한계**로 기록하게 한다 — `check_brief.py`의 `evidence: S<N>` 앵커가 한계를 명시하고 수동 검증으로 분리한 선례와 같은 처리다. 정확한 대상 줄은 구현 시 `sed -n '30,45p' plugins/quality-gates/agents/security-reviewer.md`로 확인한다.

AC4를 지키는 양방향 assert를 `test_security_reviewer_persona.sh`에 추가:

```bash
check "frontmatter tools: Read, Grep, Glob (웹 도구 미부여 — P21 exfiltration)" \
  "grep -c '^tools: Read, Grep, Glob$' '$PERSONA'" 1
assert_absent "웹 도구 없음 (전 소스를 읽는 리뷰어의 egress는 exfiltration 채널)" \
  '^tools:.*(WebSearch|WebFetch)'
```

> 이것은 **억제 유지를 잠그는 락**이다. 이 sweep에서 유지 쪽이 load-bearing 근거를 실제로 댈 수 있는 유일한 항목이므로, 다음 sweep이 무심코 "일관성"을 이유로 웹을 추가하지 못하게 못 박는다.

**mutation**: (a) `spec-reviewer`에서 `WebSearch` 제거 → RED, (b) `security-reviewer`에 `WebSearch` 추가 → RED.

bump: qg `2.14.6`, sd `0.24.7`.

### Task 5 — 검색 횟수 상한·병렬 금지 (S3a)

| 파일 | 대상 |
|---|---|
| `agents/steelman-builder.md:40-41` | `1–2회 web 검색` · `**순차 호출**(병렬·투기적 금지, C5/AP9)` |
| `agents/blind-spot-prober.md:40-41` | 같은 두 문구 |

교체 후 (steelman-builder):

```
1. 대안 방향의 근거를 web 검색(WebSearch/WebFetch)으로 수집 — prior-art, 벤치마크,
   실패 사례. 필요한 만큼 찾는다.
```

blind-spot-prober:

```
1. 이 문제 유형의 알려진 실패 사례·안티패턴을 web 검색(WebSearch/WebFetch)으로 수집.
```

**주의**: `blind-spot-prober.md:64`의 `inline premortem으로 강등(C5)`은 **웹 도구 부재 시의 graceful degradation**이지 상한이 아니다 — 건드리지 않는다.

락은 `test_brief_agents.sh:194`의 E10 패턴을 두 에이전트로 확장한다. `test_blind_spot_prober_frontmatter.sh`·`test_steelman_builder_scope.sh` 각각에 추가:

```bash
# E10 — 단일 호출 상한 표현 + 탐색 폭 좁힘 문구 부재.
# 하니스가 프롬프트로 검색 횟수를 묶으면 조사가 본질인 역할의 능력을 직접 깎는다.
# 패턴은 test_brief_agents.sh:194의 E10 락을 확장한 것이다(숫자 범위·병렬 금지 추가).
if grep -qE '최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|[0-9]-[0-9]회|max_[a-z_]+ *= *[0-9]' "$AGENT"; then
  note FAIL "E10: 단일 호출 상한 표현 잔존"
else
  note PASS "E10: 상한 표현 없음"
fi
if grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' "$AGENT"; then
  note FAIL "E10: 병렬·투기적 호출 금지 문구 잔존 (탐색 폭 좁힘)"
else
  note PASS "E10: 병렬 금지 문구 없음"
fi
```

`test_steelman_builder_scope.sh`는 변수가 `$AGENT`로 이미 정의돼 있다. `test_blind_spot_prober_frontmatter.sh`도 동일.

**mutation**: 본문에 `최대 2회`를 재삽입 → RED. `**순차 호출**(병렬·투기적 금지)`를 재삽입 → RED. 두 방향 모두 확인한다.

bump: sd `0.24.8`.

### Task 6 — test-scope-validator 자기모순 (S3b)

`agents/test-scope-validator.md`의 Hard Rule 4가 허용 컨텍스트를 *"candidate files + plan + diff"* 로 열거하는데, 같은 파일 아래 Inputs 절은 `spec_path`를 **PRIMARY reference axis**로 선언한다. 지금 상태로는 에이전트가 자기 1차 근거를 읽지 못하도록 금지당한 채 그것을 1차 근거로 쓰라는 지시를 함께 받는다.

before:

```
4. **Do not fetch context outside the candidate files + plan + diff already in your prompt.** No `curl`, no `WebFetch`, no MCP. Read each candidate file with the `Read` tool — your frontmatter grants only `Read, Grep, Glob` (no `Bash`).
```

after:

```
4. **Do not fetch context outside the candidate files + spec + plan + diff already in your prompt.** No `curl`, no `WebFetch`, no MCP. Read each candidate file — and the `spec_path` document, which is your PRIMARY reference axis — with the `Read` tool. Your frontmatter grants only `Read, Grep, Glob` (no `Bash`).
```

락(`test_test_scope_validator_frontmatter.sh`)에 추가:

```bash
# 자기모순 방지 — Hard Rule의 허용 컨텍스트 열거가 Inputs의 PRIMARY axis를 포함해야 한다.
# 라인번호가 아니라 문자열로 앵커한다(앞선 편집에 취약하지 않게).
rule4="$(grep -F 'Do not fetch context outside' "$AGENT")"
grep -q 'spec' <<<"$rule4" \
  && { PASS=$((PASS + 1)); note "PASS: Hard Rule 허용 컨텍스트에 spec 포함"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: Hard Rule이 spec을 배제 — Inputs의 PRIMARY axis와 자기모순"; }
grep -q 'PRIMARY reference axis' "$AGENT" \
  && { PASS=$((PASS + 1)); note "PASS: spec이 PRIMARY axis로 선언됨"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: PRIMARY axis 선언 소실"; }
```

두 assert가 **함께** 있어야 한다 — 앞의 것만 두면 PRIMARY 선언을 지워 자기모순을 "해소"해도 GREEN이다.

**mutation**: (a) Rule 4에서 `spec`을 제거 → RED, (b) `PRIMARY reference axis` 문구를 제거 → RED.

bump: qg `2.14.7`.

### Task 7 — codex 범주 개방 (S3c)

`scripts/build_spec_codex_prompt.py`의 `PROMPT_TEMPLATE`에서 `Review the document below for these SIX judgment categories only:` 를 교체:

```
Review the document below. These six judgment categories are the ones the
downstream merge expects most often — they are a starting vocabulary, not a
closed list:
```

그리고 여섯 항목 뒤에 추가:

```
- other: anything real that none of the six names. Use this freely — a genuine
  problem must never be dropped because no listed category fits it. When you use
  `other`, make the `summary` self-explanatory: it is the only place a reader
  learns what kind of issue this is.
```

**하류 파서는 바꾸지 않는다.** 실측으로 확인된 사실: `merge_review.py:86`은 `str(it.get("category", ""))`로 자유 문자열을 통과시키고, `:319`는 `compute_issue_id.compute(it["category"], it["target_section"])`로 해시 입력에만 쓴다. `codex_findings_to_yaml.py`·`compute_issue_id.py` 어디에도 6개 열거를 필터하는 코드가 없다(grep 0건). 따라서 파서 변경은 불필요하고, 회귀 락이 그 사실을 잠근다.

`test_build_spec_codex_prompt.sh`에 추가:

```bash
# AC16 — 범주가 6개로 닫혀 있지 않다.
grep -qF 'SIX judgment categories only' "$SCRIPT" \
  && note FAIL "AC16: 범주가 6개로 닫혀 있다 — 리스트에 없는 진짜 결함이 버려진다" \
  || note PASS "AC16: 범주 폐쇄 문구 없음"
grep -qE '^- other:' <<<"$(python3 "$SCRIPT" "$FIXTURE")" \
  && note PASS "AC16: other 범주가 프롬프트에 실린다" \
  || note FAIL "AC16: other 범주 부재"
```

그리고 **미지 범주가 하류에서 drop되지 않음**을 python 쪽에서 행위로 잠근다 (`plugins/spec-distill/tests/test_merge_review.py`에 케이스 추가):

```python
def test_unknown_category_survives_merge(self):
    """codex가 6개 밖의 범주를 내도 merge가 버리지 않는다.

    범주를 개방했는데 하류가 닫힌 열거로 필터하면, 리뷰어는 '자유롭게 쓰라'는
    지시를 받고 쓴 finding이 조용히 사라지는 것을 보게 된다 — 켜기만 하고
    소비하는 층에 배선하지 않은 결함(이 sweep이 web_budget·adversarial에서
    두 번 잡은 것과 같은 클래스)이다.
    """
    # codex YAML에 category: other 를 담은 finding 1건을 넣고 merge를 돌린 뒤,
    # 출력 codex_findings에 그 항목이 살아 있고 issue_id가 계산됐음을 확인한다.
```

정확한 픽스처 형태는 `test_merge_review.py`의 기존 케이스를 그대로 따른다 (구현 시 파일을 읽고 같은 헬퍼를 재사용한다).

**mutation**: `SIX judgment categories only`를 되돌려 넣으면 RED. `other` 항목을 지우면 RED. python 쪽은 merge에 `category` 화이트리스트 필터를 넣으면 RED.

bump: sd `0.24.9`.

### Task 8 — web_budget 상한 제거 (S3d)

**소비자가 둘이다.** 하나만 고치면 다른 쪽이 스크립트 부재로 깨지거나 무제한이 된다.

| 소비자 | 계측 단위 | `probe_budget.py`가 대체하는가 |
|---|---|---|
| `conducting-interview/SKILL.md:289,299` | 웹 호출 단위 | **예** (probe 12 + `raise-cap`) |
| `reviewing-brief/SKILL.md:174,189` | **dispatch 단위** | **아니오** |

**kill switch 계약** (인라인 복제이므로 명시한다):

| 항목 | 규정 |
|---|---|
| 변수 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
| 참으로 취급하는 값 | **정확히 문자열 `"1"`**. `true`·`yes`·`0`·빈 문자열은 전부 거짓 |
| 미설정 시 | 웹 **활성** (사용자가 켜는 스위치이지 안전 기본값이 아니다) |
| 평가 시점 | 각 웹 작업 **직전**. 세션 시작 시 캐시하지 않는다 |
| 적용 범위 | 그 소비자의 **모든** 웹 작업 — 일부만 막으면 스위치가 거짓말이 된다 |
| 소유 | 각 소비자가 자기 경로를 책임진다. **공유 헬퍼를 새로 만들지 않는다** — 스크립트 하나를 없애려는 작업에서 다른 스크립트를 만드는 것은 순환이다 |
| 검증 | 소비자별 독립 테스트 (AC7b·AC7c) |

참조 구현은 이미 있다 — `run_brief_codex_reviewer.sh:96-99`:

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
```

**편집 목록:**

1. `conducting-interview/SKILL.md` R2 절(`:281-300`) — `increment`/`reset-sweep` bash 블록을 kill-switch 인라인 체크로 교체. `budget 초과 … 강제 (b) 사용자 질문` 불릿 삭제. kill switch 불릿은 **유지**.
2. `conducting-interview/SKILL.md:52-53` — state 스키마의 `web_sweep_count`/`web_search_count` 두 줄 삭제(게이트가 사라지면 죽은 상태다).
3. `reviewing-brief/SKILL.md:170-205` — `check --prospective`/`increment` 블록과 그에 딸린 4개 분기 서술을 삭제하고, dispatch 직전 kill-switch 체크 + degrade record만 남긴다. `dispatch 단위` 계측 서술은 더 이상 사실이 아니므로 삭제한다. *"프롬프트로 검색 횟수를 묶는 것은 E10 위반"* 문장은 **유지**한다.
4. `templates/interview-audit-template.md:29-30` — `- web_sweep_count: <n> / 4` / `- web_search_count: <n> / 8` 삭제. 분모 `/ 4`·`/ 8`은 사라진 상한을 서술로 계속 알리는 문구다. `- probe_count: <n> / cap <n>` 은 유지(그 상한은 살아 있다).
5. 삭제: `scripts/web_budget.py` · `tests/test_web_sweep_bound.sh` · 픽스처 4개(`state-web-within.md`·`state-web-over-sweep.md`·`state-web-over-session.md`·`state-web-commented-overcap.md`).
6. `tests/test_conducting_interview_stage.sh:23-28` — `web_budget.py` 3개 assert와 counter 2개 assert 삭제. `DEVBREW_SPEC_DISTILL_DISABLE_WEB` assert는 유지.
7. `tests/test_reviewing_brief_skill.sh:206-207` (T21) 교체:

```bash
# T21 — 웹 상한 게이트 부재 + kill switch 실재 (v0.24.10에서 상한 제거).
# 이전 버전은 `web_budget.py check/increment` 호출 라인 실재를 요구했다. 그 상한이
# 없어졌으므로 락의 방향을 뒤집는다 — 상한 게이트가 **다시 생기면** RED.
grep -qE 'web_budget' "$SKILL" \
  && note FAIL "T21: web_budget 상한 게이트 재도입 — 조사 폭을 다시 묶는다" \
  || note PASS "T21: 상한 게이트 부재"
grep -qE '^[[:space:]]*if \[\[ "\$\{DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0\}" == "1" \]\]' "$SKILL" \
  && note PASS "T21: kill switch 인라인 체크 실재 (줄-시작 앵커)" \
  || note FAIL "T21: kill switch 소실 — 보안 컨트롤이 상한과 함께 사라졌다"
```

8. **신규** `tests/test_web_kill_switch.sh` — AC7b·AC7c를 **소비자별로 독립** 검증한다. 한 소비자의 assert가 다른 소비자를 덮지 않아야 한다 (round-1 리뷰: 이 분리가 없으면 `check_brief.py`의 별도 경로만으로 green이 되는 green-expected AC다):

```bash
#!/usr/bin/env bash
# AC7b·AC7c — web kill switch가 두 소비자 각각에 인라인으로 살아 있다.
#
# 왜 소비자별로 나누는가: v0.24.10이 web_budget.py를 지우면서 kill switch 구현을
# 두 소비자로 이전했다. 한 파일에 대한 assert가 다른 파일을 덮으면, 한쪽에서
# 스위치가 사라져도 GREEN이 난다 — 스위치가 거짓말을 하는 상태다.
#
# 계약(설계 §6 S3d): 정확히 문자열 "1"만 참. 미설정 = 웹 활성. 평가는 각 웹 작업 직전.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

for consumer in conducting-interview reviewing-brief; do
  SKILL="$SD/skills/$consumer/SKILL.md"
  if [[ ! -f "$SKILL" ]]; then note FAIL "$consumer: SKILL.md 부재"; continue; fi
  # 줄-시작 앵커 + 정확한 비교식 — 산문 언급만으로는 통과하지 못한다.
  grep -qE '^[[:space:]]*if \[\[ "\$\{DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0\}" == "1" \]\]' "$SKILL" \
    && note PASS "$consumer: kill switch 인라인 체크 실재" \
    || note FAIL "$consumer: kill switch 인라인 체크 부재"
  # 계약: 정확히 "1" — 느슨한 참 판정(true/yes/비어있지 않음)은 계약 위반이다.
  grep -qE 'DEVBREW_SPEC_DISTILL_DISABLE_WEB.*(true|yes|-n |!= *"")' "$SKILL" \
    && note FAIL "$consumer: 느슨한 참 판정 — 계약은 정확히 \"1\"이다" \
    || note PASS "$consumer: 참 판정이 \"1\" 한정"
  # 상한 게이트가 되돌아오지 않았다.
  grep -qE 'web_budget|SWEEP_CAP|SESSION_CAP' "$SKILL" \
    && note FAIL "$consumer: 상한 게이트 재도입" \
    || note PASS "$consumer: 상한 게이트 없음"
done

# production 전역 — 스크립트와 카운터가 실제로 사라졌다(AC7a).
# tests/·CHANGELOG는 제외: 전자는 부재를 assert하는 층이고 후자는 이력이다(C2).
leftover="$(grep -rln 'web_budget\|web_sweep_count\|web_search_count' "$SD" \
  --exclude-dir=tests --exclude=CHANGELOG.md 2>/dev/null || true)"
if [[ -z "$leftover" ]]; then
  note PASS "AC7a: production에 web_budget/카운터 잔존 0"
else
  note FAIL "AC7a: production 잔존:"; printf '    %s\n' $leftover
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

**삭제 전 확인 (Step 6에 해당)**:

```bash
# web_budget.py의 다른 소비자가 없음을 확정한다.
grep -rn 'web_budget' plugins/ --exclude-dir=tests --exclude=CHANGELOG.md
# 픽스처 4개의 다른 소비자가 없음을 확정한다.
grep -rln 'state-web-within\|state-web-over-sweep\|state-web-over-session\|state-web-commented-overcap' plugins/
# check_brief.py가 Budget 절을 파싱하지 않음을 재확인한다(파싱하면 audit 픽스처 50개가 함께 깨진다).
grep -n 'web_sweep\|web_search\|## 2. Budget' plugins/spec-distill/scripts/check_brief.py
```

Expected: 첫 둘은 `test_web_sweep_bound.sh` 외에 없음, 셋째는 출력 없음.

> `tests/fixtures/*.audit.md` 약 50개와 `state-legacy-interview-round.md`는 **건드리지 않는다** — 과거 인터뷰의 실제 기록(C2 이력)이고 `check_brief.py`가 그 절을 읽지 않는다. 신규 락의 production 스윕도 `--exclude-dir=tests`로 이들을 제외한다.

**mutation (소비자별 독립)**:
- `conducting-interview/SKILL.md`에서만 kill-switch 줄 삭제 → RED
- `reviewing-brief/SKILL.md`에서만 kill-switch 줄 삭제 → RED
- 어느 한쪽에만 `python3 "$PR/scripts/web_budget.py" check "$STATE"` 재삽입 → RED

세 mutation이 **각각** RED여야 AC7c가 의미를 갖는다.

bump: sd `0.24.10`. CHANGELOG `Removed` 항목에 *"내부 스크립트라 one-minor deprecation window 대상이 아니다"* 를 한 줄 남긴다.

스위트 기대치가 바뀐다: bash total `129 → 129`(테스트 1 삭제 + 1 신설), red는 `7` 유지.

### Task 9 — adversarial 신규 발견 승격 (S3e)

**쓰기 쪽만 고치면 동작하지 않는다.** `synthesize_findings.py:44-64`의 `apply_verdicts()`는 `by_id`를 만든 뒤 **원본 `findings`만 순회**하므로, 매칭되는 `finding_id`가 없는 verdict — 정의상 *신규* 발견 — 은 `out`에 들어갈 경로가 아예 없다.

**쓰기 쪽** — `agents/adversarial.md`의 금지 선언 **네 곳 모두**:

| 위치 | 현재 | 조치 |
|---|---|---|
| `:3` description | `...to find false positives, weak fixes, or better alternatives.` | 신규 발견 보고가 역할에 포함됨을 명시 |
| `:12` | `You are the **single model-based judgment gate**` + `the Phase 1/2 reviewers run on cheaper models` | 후자는 이제 사실이 아니다(Task 1·2가 전부 `inherit`) — 삭제하고 판정 병목 서술만 유지 |
| `:22` | `You are NOT responsible for: producing new findings of your own, ...` | `producing new findings of your own,` 제거 |
| `:149` | `No new findings as verdicts. The single `meta_note:` is the only place a missed issue may be mentioned, and it is never elevated to a finding.` | verdict 블록에 신규를 넣지 말라는 부분만 유지하고, `new_findings:` 블록으로 안내 |

그리고 새 최상위 블록 스키마를 정의한다(`:130` 부근, verdict 스키마 바로 뒤):

```markdown
## Reporting an issue the reviewers missed

If you find a real issue no Phase 1/2 reviewer reported, emit it in a **top-level
`new_findings:` block** — not as a verdict (a verdict with no matching
`finding_id` has no output path in the synthesizer and is dropped).

```yaml
new_findings:
  - file: <path relative to project_dir>
    line: <integer; omit or 0 if the issue is not line-anchored>
    severity: CRITICAL | IMPORTANT | SUGGESTION
    summary: <one sentence — what is wrong>
    reason: <2-3 sentences — the concrete evidence, same bar as a verdict `reason`>
```

`file`, `severity`, `summary` are required; an entry missing any of them is
dropped with a loud stderr line and counted, never silently. `line` is optional.
Do **not** supply a `finding_id` — the synthesizer synthesizes it and forces
`agent: adversarial`, so a new finding can never impersonate another agent's.

`meta_note:` stays. Use it for unstructured observations that are not a
finding — an absent control, a pattern worth watching, a note to the author.
The two channels have different jobs: `new_findings:` is *"here is a defect,
at this line, at this severity"*; `meta_note:` is everything else.
```

**읽기 쪽** — `scripts/synthesize_findings.py`:

```python
def load_yaml_doc(path):
    """Load a YAML file and return the raw parsed document (no key flattening).

    load_yaml() flattens `{verdicts: [...]}` down to the list, which discards
    every sibling key. The adversarial document now carries a second top-level
    key (`new_findings`), so the raw document has to survive the load.
    """
    if not path:
        return None
    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return None


def extract_verdicts(doc):
    if isinstance(doc, dict):
        return doc.get("verdicts") or []
    return doc or []


def extract_new_findings(doc):
    if isinstance(doc, dict):
        return doc.get("new_findings") or []
    return []


NEW_FINDING_REQUIRED = ("file", "severity", "summary")
# 승격된 발견의 기본 confidence. suppress()의 바닥(<=4)보다는 위라 표에 실리고,
# render()의 caveat 임계(<=6) 아래라 `*`가 붙는다 — 이 발견은 어떤 리뷰어의
# 판정도 통과하지 않았다(adversarial 자신의 주장이다). 보이되 검증 안 됨으로
# 표시하는 것이 정직한 인코딩이다. 리뷰어가 명시적으로 confidence를 주면 그것을 쓴다.
NEW_FINDING_DEFAULT_CONFIDENCE = 5


def promote_new_findings(raw_new, existing):
    """adversarial의 `new_findings:` 항목을 진짜 finding으로 승격한다.

    Returns (promoted, dropped_malformed).

    출처는 `agent`에 쓴다 — `source`(단수)가 **아니다**. dedup()은 `agent`를 모아
    `sources`를 만들고 render()는 `sources`/`agent`만 읽으므로, `source`로 쓰면
    Source 컬럼이 fallback `?`로 렌더된다.

    id는 verdict가 준 값을 믿지 않고 기존 finding_id() 헬퍼로 합성한다 — 그래야
    신규 발견이 다른 agent의 finding id를 참칭할 수 없다. 기존과 충돌하면 기존이
    이기고(신규를 버리고 loud 기록), 신규끼리 충돌하면 `-2`, `-3` … 를 붙여
    결정론적으로 분리한다.

    한계(범위 밖): dedup()의 (file, line, severity) 그룹핑은 바꾸지 않으므로,
    같은 좌표·같은 severity의 신규 두 건은 렌더 단계에서 여전히 한 행으로 합쳐진다.
    그 병합 동작 자체는 별건(설계 §11 CHECKS-07)이다.
    """
    promoted, dropped = [], 0
    seen = {finding_id(f) for f in existing if isinstance(f, dict)}
    for item in raw_new:
        if not isinstance(item, dict):
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
        f = dict(item)
        f["agent"] = "adversarial"
        f["line"] = f.get("line") or 0
        f.setdefault("confidence", NEW_FINDING_DEFAULT_CONFIDENCE)
        fid = finding_id(f)
        if fid in seen:
            base = fid
            suffix = 2
            while f"{base}-{suffix}" in seen:
                suffix += 1
            fid = f"{base}-{suffix}"
            print("[synthesize_findings] adversarial finding id collision on "
                  f"{base}; disambiguated to {fid}", file=sys.stderr)
        seen.add(fid)
        f["finding_id"] = fid
        promoted.append(f)
    return promoted, dropped
```

`main()` 배선:

```python
    doc = load_yaml_doc(args.adversarial) if args.adversarial else None
    verdicts = extract_verdicts(doc)
    raw = load_yaml(args.findings) if args.findings else []

    findings = apply_verdicts(raw, verdicts)
    promoted, dropped_malformed = promote_new_findings(extract_new_findings(doc), findings)
    findings = findings + promoted          # 기존 뒤에 append — 기존 표 순서를 흔들지 않는다
    findings = dedup(findings)
    kept, suppressed = suppress(findings)
    kept = sort_findings(kept)

    sys.stdout.write(render(kept, len(suppressed), dropped_malformed))
```

`render()` 시그니처에 `dropped_malformed=0` 기본값을 추가하고, counts 줄 뒤에 조건부 한 줄:

```python
    if dropped_malformed > 0:
        out.append(
            f"{dropped_malformed} adversarial finding(s) dropped as malformed "
            "(missing file/severity/summary) — see stderr."
        )
```

**exit code는 바꾸지 않는다.** 리뷰어 출력 불량으로 파이프라인을 죽이면 그 자체가 새 fail-closed 억제다.

**테스트(신규, persona와 격리)** — `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh`. 픽스처 YAML을 직접 넣어 synthesizer만 검증하므로, persona 편집이 이 테스트를 green으로 만들 수 없다. 최소 4개 assert:

1. 기존 finding 0건 + `new_findings` 1건(IMPORTANT) → 출력 표에 **그 발견이 실재**한다
2. 그 행의 **Source 컬럼이 `adversarial`** 이다 (`?`가 아니다 — 필드명이 틀리면 여기서 잡힌다)
3. 그 행에 `*` caveat이 붙는다 (판정을 통과하지 않은 발견임이 표시된다)
4. `summary` 누락 항목은 출력에 없고, stderr에 `dropped malformed`가 찍히며, **exit code는 0**이다

**mutation**: `main()`에서 `findings + promoted`를 `findings`로 되돌리면 RED. `f["agent"] = "adversarial"`을 `f["source"] = "adversarial"`로 바꾸면 assert 2가 RED. AC14a(persona 네 곳)만 고치고 synthesizer를 안 고치면 이 테스트가 RED — **AC14a만으로는 green이 될 수 없다**는 것이 이 설계의 요점이다.

`test_adversarial_persona.sh`에 AC14a 락 추가:

```bash
# AC14a — 신규 발견 금지 선언이 네 곳 모두에서 해소됐다. 한 곳이라도 남으면 persona 자기모순.
assert_absent "신규 발견 금지 선언 부재 (승격 허용)" \
  'producing new findings of your own|No new findings as verdicts'
check "new_findings 블록 스키마 정의" "grep -c '^new_findings:' '$PERSONA'" 1
check "meta_note 채널 존치 (구조화되지 않은 관찰용)" "grep -c 'meta_note' '$PERSONA'" 1
```

bump: qg `2.14.8`.

### Task 10 — ambiguity 단어경계 (S3f)

`scripts/parse_spec_structure.py:162`의 `re.finditer(re.escape(phrase), line, flags=re.IGNORECASE)`가 단어경계 없이 부분문자열을 잡아 정상 기술 용어에서 발화한다. **이 문서를 쓰는 동안 실제로 write를 세 번 exit 2로 막았다.**

**단순 `\b` 감싸기는 틀렸다.** 하이픈은 `\w`가 아니라서 하이픈 복합어 안에서도 단어경계가 성립한다. 실측:

| phrase | text | `\b…\b` | `(?<![\w-])…(?![\w-])` |
|---|---|---|---|
| `~fast` | `~fast`-forward | **hit (오탐)** | miss ✅ |
| `~efficient` | `in`+`~efficient` | miss | miss ✅ |
| `~fast` | break+`~fast` | miss | miss ✅ |
| `~fast` | `~fast` (단독) | hit | **hit ✅** |

교체:

```python
def scan_ambiguity(text: str, patterns: list[str]) -> list[dict]:
    """Find lines containing any blacklisted phrase. `~phrase` opt-out applies
    to that specific occurrence (match must NOT be preceded by `~`).

    경계는 `\\b`가 아니라 `(?<![\\w-])…(?![\\w-])`다. 하이픈은 `\\w`가 아니므로
    `\\b`로 감싸면 하이픈 복합어(fast-forward 류) 안의 단어에 그대로 매치해
    정상 기술 용어에서 발화한다 — 이 검사가 실제로 설계 문서 작성을 세 번 막았다.
    하이픈을 경계 문자 집합에 넣으면 그 오탐이 사라지면서, blacklist의 온전한
    단어는 계속 잡힌다.
    """
    hits: list[dict] = []
    for lineno, line in enumerate(text.split("\n"), start=1):
        for phrase in patterns:
            bounded = rf"(?<![\w-]){re.escape(phrase)}(?![\w-])"
            for m in re.finditer(bounded, line, flags=re.IGNORECASE):
                start = m.start()
                if start > 0 and line[start - 1] == "~":
                    continue
                hits.append({"line": lineno, "phrase": phrase, "text": line})
                break  # one hit per phrase per line is enough
    return hits
```

> **`~` opt-out과의 상호작용을 반드시 확인한다.** `~`는 `\w`도 `-`도 아니므로 lookbehind를 통과하고, 기존 `line[start - 1] == "~"` 검사가 그대로 동작한다. 이 사실을 테스트로 잠근다(아래 assert 3).

**양방향 assert** — `tests/test_parse_spec_structure.sh` ambiguity 절에 추가:

```bash
# T6-4 (단어경계, 완화 방향): 하이픈 복합어·접두 결합 안의 부분문자열은 hit되지 않는다.
tmp_wb="$(mktemp)"
printf '# t\n\nmerge with fast-forward; the loop is inefficient by design.\n' > "$tmp_wb"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wb" "$BL" 2>&1)
echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "T6-4: 하이픈 복합어·접두 결합에서 오탐 없음" \
  || note FAIL "T6-4: 정상 기술 용어에서 발화 (out=$out)"

# T6-5 (반대 방향, 필수): 완화가 검사를 통째로 죽이지 않았다.
# 이 assert가 없으면 blacklist 매칭을 전부 제거해도 T6-4가 GREEN이다.
tmp_wp="$(mktemp)"
printf '# t\n\nthe result must be fast and the API robust.\n' > "$tmp_wp"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wp" "$BL" 2>&1)
{ echo "$out" | grep -q '"phrase": "fast"' && echo "$out" | grep -q '"phrase": "robust"'; } \
  && note PASS "T6-5: 온전한 blacklist 단어는 계속 hit (검사가 살아 있다)" \
  || note FAIL "T6-5: 완화가 검사를 죽였다 (out=$out)"
rm -f "$tmp_wb" "$tmp_wp"
```

기존 T6-3(`~` escape) 케이스는 그대로 두어 opt-out 회귀를 잡는다.

**mutation**: `bounded`를 `re.escape(phrase)`로 되돌리면 T6-4가 RED. `bounded`를 절대 매치하지 않는 패턴으로 바꾸면 T6-5가 RED. **두 방향 모두** 확인한다.

bump: sd `0.24.11`.

### Task 11 — 규약 정렬 (S4)

| 위치 | 조치 |
|---|---|
| `CLAUDE.md:43` | *"Fan-out factor N ≥ 5는 hard review 게이트."* 삭제. 같은 불릿의 `cost_class: high` 승인 게이트 문장은 **유지** (비용 동의는 P17 load-bearing) |
| `CLAUDE.md:68` | *"Subagent spray — 선언 없는 fan-out ≥ 5; single-agent를 default로."* → *"Subagent spray — 선언 없는 fan-out. 비용과 fan-out을 선언하지 않고 대규모로 퍼뜨리는 것이 anti-pattern이다 (규모 자체가 아니라 선언 없음이)."* |
| `CLAUDE.md:69` | *"wall-clock budget"* 삭제 — spec-distill v0.17.0이 *"사람 숙고시간 오측정 footgun"* 으로 이미 제거했다. 규약이 플러그인이 폐기한 것을 요구하는 상태다 |
| philosophy `:20` | *"모델 성능이 향상돼도 이 메커니즘은 불변이다."* → *"Three Laws의 집행 자체는 모델 성능과 무관하게 불변이다. 다만 개별 임계치·예산·상한은 재평가 대상이다 — 모델이 강해지면 결정론이 사던 것의 값이 달라지기 때문이다(P8)."* |
| philosophy `:43` | trivia escape의 *single-file* 제약 완화 — 두 파일 이상의 한 줄 변경(오타 3곳, symbol rename)에 full 게이트를 강제해 스스로 금지한 trivia ceremony를 요구한다 |
| philosophy `:63` | *"N≥5는 hard gate이며,"* 삭제. 나머지 문장 유지 |
| philosophy `:96` | *"single-agent가 default다 (P22)."* 삭제 |
| `docs/plugin-authoring.md` | agent `model: inherit` 규약 문장 **신설** — 신규 플러그인이 리터럴 핀을 복제하는 것을 차단 |
| `plugins/quality-gates/README.md:161` | **Task 1에서 이월** — `opus 빌더가 저술한` → `빌더가 저술한`. Task 1 브리프의 줄 목록(66/139/143/176)에 빠져 있던 리터럴 티어 산문 잔존이고, Task 1 리뷰어가 *"implementer scope creep이 아니라 brief 자체의 gap"* 으로 판정했다. 닫지 않으면 Task 13의 판별 질의에 걸린다 |
| project-init 템플릿 **2개** | rebase 조항 완화 |

`:20`이 왜 중요한가: 현재 문장은 *비용 임계치까지* 재평가 불가로 선언해 **이 sweep 자체를 규칙 위반으로 읽게 만든다**.

`docs/plugin-authoring.md`에 추가할 문장 (agents 관련 절):

```markdown
- **agent `model:`은 `inherit`.** 리터럴 티어(`opus`/`sonnet`/`haiku`)를 박으면 하니스가
  사용자의 모델 선택을 덮어쓴다 — 세션이 더 강한 모델을 쓸 때는 조용한 하향이고, 더 약한
  모델을 쓸 때는 동의 없는 비용 증가다. 어느 방향이든 P8(Determinism Economy) 위반이다.
  reference: `plugins/plugin-audit/agents/*.md`.
```

project-init 템플릿 (**두 파일 모두** — 한쪽만 고치면 억제가 다른 variant로 살아남는다):

`templates/github-flow/branch-strategy.md:63` before/after:

```
- **ALWAYS** 기존 feature 브랜치는 `git merge origin/main`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.
→
- **공유된 브랜치는 rebase하지 않는다.** 기존 feature 브랜치는 `git merge origin/main`으로 sync한다. rebase는 commit SHA를 rewrite하므로, 이미 push돼 다른 사람이 받아간 브랜치에서는 unsafe하다. 아직 공유되지 않은 로컬 브랜치를 정리하는 것은 각자의 판단이다.
```

`templates/git-flow/branch-strategy.md:99`도 동일 (기준 브랜치만 `origin/develop`).

**리포 루트 `docs/git-workflow/branch-strategy.md:63`은 변경하지 않는다** (C3 — 사용자 본인 선호).

**AC8 락** — S4 표 **7행 전부**를 기계 검증한다. 3행만 덮으면 나머지 4행이 조용히 통과한다. 신규 `plugins/project-init/tests/test_branch_strategy_rebase_clause.sh`(project-init에는 `tests/`가 없으므로 디렉토리부터 만든다) 또는 repo-root 검증 스크립트에 배치한다. 필수 assert:

```bash
# AC8a — 숫자 임계·기본값 편향·wall-clock 부재, 승인 게이트는 존속
grep -qE 'N ≥ 5|N≥5' CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md && FAIL || PASS
grep -qE 'single-agent를 default' CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md && FAIL || PASS
grep -qE 'wall-clock' CLAUDE.md && FAIL || PASS
grep -qF 'cost_class: high' CLAUDE.md && PASS || FAIL          # 승인 게이트 존속(양방향)

# AC8b — philosophy :20 완화 (임계치가 재평가 대상임이 문장으로 확인된다)
grep -qE '재평가 대상' docs/philosophy/devbrew-harness-philosophy.md && PASS || FAIL
grep -qF '모델 성능이 향상돼도 이 메커니즘은 불변이다' docs/philosophy/devbrew-harness-philosophy.md && FAIL || PASS

# AC8c — trivia escape에 single-file 제약 없음
# 섹션 윈도우로 스코프한다 — 전역 grep은 다른 절의 우연한 언급에 만족될 수 있다.
p12="$(awk '/^### P12/{f=1;next} /^### /{f=0} f' docs/philosophy/devbrew-harness-philosophy.md)"
grep -qF 'single-file' <<<"$p12" && FAIL || PASS

# AC8d — plugin-authoring에 model: inherit 규약
grep -qE 'agent .*model:.*inherit|`model: inherit`' docs/plugin-authoring.md && PASS || FAIL

# AC8e — 템플릿 2개 모두 무조건 금지 없음 + 리포 루트는 불변 (양방향)
for t in github-flow git-flow; do
  grep -qF '`git rebase`는 절대 안 됨' "plugins/project-init/templates/$t/branch-strategy.md" && FAIL || PASS
  grep -qF '공유된 브랜치는 rebase하지 않는다' "plugins/project-init/templates/$t/branch-strategy.md" && PASS || FAIL
done
grep -qF '`git rebase`는 절대 안 됨' docs/git-workflow/branch-strategy.md \
  && PASS || FAIL     # 리포 루트는 **유지**돼야 한다 — 사용자 선호 보존
```

> 마지막 assert의 방향에 주의한다. 리포 루트는 **원문이 남아 있어야** PASS다. 이것이 AC8e의 "양방향"이다 — 템플릿만 완화하고 루트는 보존했음을 증명한다.

**mutation**: (a) `git-flow` variant만 되돌리면 RED (단일-variant 누락 재발 방지), (b) 리포 루트를 함께 완화하면 RED (사용자 선호 침범 감지), (c) philosophy `:20` 원문을 되돌리면 RED.

bump: project-init `1.7.3`. `CLAUDE.md`·philosophy·plugin-authoring은 리포 루트라 플러그인 bump 대상이 아니다.

### Task 12 — 메모리 + 과거 기록 (S5)

**메모리 (git 밖 — 커밋되지 않는다)**, `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/`:

| 파일 | 조치 |
|---|---|
| `feedback_respect_upstream_model_hardcoding.md` | 무한정 일반 명제에 **범위 명시**(외부 플러그인 한정)를 넣고, *"`model: inherit`이면 sonnet으로 override 가능"* 권장을 **삭제**한다 — 이 줄은 sweep이 없애려는 행위를 how-to로 처방하고 있다 |
| `project_spec_distill_interview_coverage_driven.md:24` | writer를 sonnet으로 처방한 부분 정정 |
| `MEMORY.md` | 위 둘의 hook 문구 동기화 + `project_harness_suppression_sweep.md`를 완료 상태로 갱신 |

**historical (append only — C2)**: 아래 두 문서에 사후 반증 문단을 **덧붙인다**(기존 문장 수정 금지):

- `docs/superpowers/specs/2026-07-16-law2-agent-tool-surface-design.md`
- `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md` 및 그 design

문단 형태:

```markdown
> **사후 정정 (2026-08-03, 하니스 능력 억제 제거 sweep)**: 이 문서가 규정한
> `model: <리터럴 티어>` 핀은 이후 제거됐다. 실측 결과 그 핀이 opus-5 세션에서
> sonnet-5 리뷰어를 만들어, 리뷰어가 writer보다 약한 상태를 매 dispatch 재현했다.
> 현재 규약은 `model: inherit`이다 — `docs/plugin-authoring.md` 및
> `docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md`.
> 이 문서의 나머지 판단(Law 2 도구 표면 등)은 유효하다.
```

**설계 §12에 메모리 변경 목록을 기록한다** — 메모리는 git 밖이므로 이것이 유일한 감사 흔적이다:

```markdown
- **메모리 변경 (2026-08-03, git 밖 — 이 기록이 유일한 감사 흔적)**
  - `feedback_respect_upstream_model_hardcoding.md` — 범위를 외부 플러그인으로 한정,
    sonnet override 권장 삭제
  - `project_spec_distill_interview_coverage_driven.md` — writer sonnet 처방 정정
  - `MEMORY.md` — 위 둘의 hook 동기화 + sweep 상태 갱신
```

커밋 대상은 `docs/` 3개 파일뿐이다 (메모리는 git이 추적하지 않는다).

### Task 13 — 최종 검증

- [ ] **Step 1: AC13 — §2의 판별 질의를 전수 재실행한다**

> ⚠️ **`command grep`을 쓴다** (Task 2 실행 중 확증). 이 환경에서 `grep`의 정체가 층마다 다르다:
> 컨트롤러 세션의 `grep`은 shell-snapshot이 정의한 **셸 함수**(ugrep 래퍼)라 다중 파일 인자에서
> **출력 순서가 비결정적**이고(같은 명령 2회가 다른 순서를 냈다) `ugrep: warning:`을 낸다.
> 반면 테스트 스크립트는 `bash <script>`로 도는 자식 프로세스라 셸 함수를 상속하지 않고
> **`/usr/bin/grep`(BSD grep 2.6.0)** 을 쓴다. **락은 영향받지 않는다** — 영향받는 것은 아래처럼
> 내가 직접 치는 검증 질의다. 두 질의를 양쪽으로 대조했을 때 건수는 일치했지만(goal-1 0=0,
> goal-4 2=2), 결정론과 테스트-일치를 위해 검증에는 `command grep`을 쓴다.

```bash
echo "== goal 1 =="; command grep -rn '^model:' plugins/ | command grep -v inherit   # 기대: 0건
echo "== goal 2 =="; command grep -rnE "^[[:space:]]*-c .*model_reasoning_effort" plugins/*/scripts/   # 기대: 0건
echo "== goal 4 =="; command grep -rnE '최대 [0-9]+회|[0-9]+회까지|[0-9]–[0-9]회|max_[a-z_]+ *= *[0-9]|병렬.{0,8}금지' \
  plugins/*/agents/ plugins/*/skills/                                       # 기대: 락의 assert 인자만
echo "== goal 5 =="; command grep -rnE 'N ≥ 5|N≥5|single-agent를 default|wall-clock' CLAUDE.md docs/philosophy/  # 기대: 0건
echo "== AC7a =="; command grep -rn 'web_budget' plugins/ --exclude-dir=tests --exclude=CHANGELOG.md   # 기대: 0건
```

**잔여 매칭이 있으면 전부 설계 §12의 load-bearing allowlist에 등재한다.** 등재 필수 필드: `위치`(file:line) · `막는 실패`(이것을 제거하면 무엇이 조용히 통과하는가 — *"조심스러워서"* 는 실패 서술이 아니다) · `근거`(커밋·테스트·과거 사고 기록) · `대안 검토`(더 가벼운 수단이 왜 안 되는지) · `재검토 조건`(*"영구"* 는 허용하지 않는다).

**goal 1의 `plugins/*/tests/` 질의는 완료 판정에 쓰지 않는다** — 올바르게 반전된 락도 금지 문자열을 부정 assert의 인자로 명시하므로 반전 전후 같은 파일을 반환한다. 방향을 판정하는 것은 mutation(Step 2)뿐이다.

- [ ] **Step 2: mutation 시나리오 전량 재실행**

각 태스크에서 이미 확인했지만, 마지막에 **한 번에** 돌려 태스크 간 간섭이 락을 무력화하지 않았는지 본다. 설계 §9.1 표의 10개 행 전부. 각 mutation 후 `git checkout --`로 되돌리고 `git status --short`가 깨끗한지 확인한다.

- [ ] **Step 3: `test_stale_terms.sh`를 메인 체크아웃에서 실행한다**

이 워크트리에서는 경로에 `.claude/`가 있어 vacuous하게 red다. 실제 커버리지는 메인에서만 나온다. **read-only 실행**이므로 메인 체크아웃을 오염시키지 않는다:

```bash
(cd /Users/jeonghokim/Downloads/devbrew && git stash list >/dev/null && \
 git --no-pager status --short && bash plugins/spec-distill/tests/test_stale_terms.sh 2>&1 | tail -5)
```

> 메인 체크아웃은 이 브랜치의 변경을 갖고 있지 않으므로, 이 실행은 *"메인이 여전히 green"* 만 확인한다. **브랜치 내용에 대한 stale 검사는 PR 머지 후** 또는 워크트리를 `.claude/` 밖 경로로 다시 만들어 수행한다. 어느 쪽도 못 하면 등가 grep을 직접 돌린다:

```bash
grep -rInE 'breadth-keeper|breadth_keeper|web_budget|web_sweep_count|web_search_count' \
  plugins/spec-distill --exclude-dir=tests --exclude=CHANGELOG.md
```

Expected: 출력 없음.

- [ ] **Step 4: Law 2 무손상 기계 검증**

```bash
for a in plugins/*/agents/*.md; do
  fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$a")"
  echo "$fm" | grep -qE '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' \
    && echo "CHECK: $a"
done
```

Expected: `runtime-verifier.md`만 출력된다 (설계된 예외 — orchestrator의 git-diff mutation guard로 격리된다). 그 밖에 하나라도 나오면 이 sweep이 Law 2를 침범한 것이다.

- [ ] **Step 5: AC11 — dispatch 실측 (세션 재시작 필요)**

agent 레지스트리는 **세션 시작 시 스냅샷**되므로 편집 직후 같은 세션에서 dispatch하면 옛 정의가 돈다.

1. 세션을 재시작한다.
2. `spec-reviewer`를 1회 dispatch한다. 대상은 **외부 근거 확인이 반드시 필요한** design doc을 고르거나, 프롬프트에 *"이 문서가 인용하는 외부 사실을 검색으로 확인하라"* 를 명시한다 — *"아무 문서"* 로는 *"검색이 불필요했다"* 와 *"도구가 없다"* 를 구분할 수 없다.
3. `~/.claude/projects/<proj>/<sid>/subagents/agent-<id>.meta.json`의 `agentType`으로 신원을 확정하고, 같은 id의 `.jsonl`에서 확인한다:
   - **모델을 리터럴로 비교하지 않는다.** 메인 세션 트랜스크립트의 최빈 `"model"` 값과 subagent의 `"model"` 값이 **같은지**를 본다. `claude-opus-5` 같은 리터럴을 기대값으로 박으면 다음 세대에서 옳은 수정에도 stale-red가 난다. 두 값이 다르면 **핀이 살아 있다**.
   - `grep -o '"name":"[A-Za-z0-9_-]*"' <jsonl>` → `WebSearch` tool_use 실재.
4. 두 관측을 설계 §12에 날짜와 함께 기록한다. **에이전트의 자기보고는 증거가 아니다** — 트랜스크립트만 증거다.

- [ ] **Step 6: 전체 스위트 최종 측정**

```bash
red=0; tot=0
for t in plugins/*/tests/*.sh; do tot=$((tot+1)); bash "$t" >/dev/null 2>&1 || { red=$((red+1)); echo "RED: $t"; }; done
echo "bash total=$tot red=$red"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -3
python3 -m unittest discover -s plugins/plugin-audit/scripts/tests -p 'test_*.py' 2>&1 | tail -3
```

Expected: bash red **7 이하**이고 **목록이 baseline과 동일**(개수만 맞고 다른 파일이 red면 회귀다). python spec-distill red 1(NG9), plugin-audit green.

- [ ] **Step 7: `/qg branch`**

리포가 반복 실증한 대로 same-family 리뷰어들은 공유 맹점을 갖는다. **별-모델(codex)을 포함한 리뷰가 이 sweep에서 특히 중요한 이유**: 이 sweep의 변경 대부분이 *"가드를 제거"* 라, 같은 계열 리뷰어는 *"제거해도 괜찮다"* 는 저자의 전제를 공유하기 쉽다. codex는 그 전제를 공유하지 않는다.

`/qg branch`가 내는 findings를 처리할 때 **정지 조건을 미리 정한다** (하니스를 다듬는 동안 대상 0건이 개선되는 것을 막는다): 고치는 것은 (a) 실행이 깨지는 것, (b) 사용자를 해치는 것, (c) 거짓 결과를 내는 것 셋뿐이다. *"더 명시하라"* 는 후속 사이클로 보낸다.

- [ ] **Step 8: PR**

`main`으로 PR. 본문에 §1.1 실측 표(sonnet 핀 = 실측 손실 / opus 핀 = 오늘 손실 0)를 **분리해서** 싣는다 — 뭉개면 약한 논거가 강한 논거를 끌어내린다. 설계·census 링크를 건다.

---

## Self-Review

**1. 설계 커버리지**

| 설계 요소 | 담당 태스크 |
|---|---|
| S1 모델 핀 (agent 7) | 1, 2 |
| S1 codex 상한 (script 3) | 3 |
| S1 락 반전 5개 | 1(4개), 2(4개 신설), 3(1개) — 설계의 "5개"보다 많다. 설계는 반전 대상만 셌고, spec-distill 4개는 **부재해서 신설**이 필요했다(Task 2 Step 1에서 실측) |
| S2 조사 도구 | 4 |
| S3a–S3f | 5, 6, 7, 8, 9, 10 |
| S4 규약 7행 | 11 (AC8a–e 전부) |
| S5 메모리 + historical | 12 |
| AC1–AC16 | AC1·AC9→1·2, AC2→3, AC3·AC4→4, AC5→5, AC6→6, AC7a–d→8, AC8a–e→11, AC10→각 태스크 + 13, AC11→13 Step 5, AC12→각 태스크, AC13→13 Step 1, AC14a–c→9, AC15→10, AC16→7 |
| §9.1 mutation 10행 | 각 태스크 + 13 Step 2 |
| §10.1 rollout A | 태스크 지도 = 관심사별 커밋 1 PR |

**갭 없음.** 설계가 계획으로 미룬 두 항목(각 하위 단계 내 편집 순서 / §11 별건 8개의 후속 범위)은: 편집 순서를 각 태스크의 step으로 확정했고(락→RED→대상→GREEN→mutation), §11 별건 8개는 **이 계획의 범위 밖**임을 명시한다 — 방향이 반대(fail-open)라 섞으면 리뷰가 흐려진다. 별도 사이클에서 다룬다.

**2. 계획이 설계를 정정한 곳 (3건)**

| 항목 | 설계 | 실측 |
|---|---|---|
| baseline red | *"6 red, 전부 quality-gates"* | **워크트리 7 red** — 7번째는 `test_stale_terms.sh`가 워크트리 경로의 `/.claude/`에 걸려 vacuous fail. 메인에서는 9/9 green. python도 워크트리에서 NG9 1건 red |
| spec-distill 모델 락 | *"5개 락을 반전"* | 그중 spec-distill 4개는 **`model:` assert가 아예 없다** — 반전이 아니라 신설 |
| 커밋 수 | qg 4회 | **qg 5회** (S2의 `security-reviewer` 문구가 qg를 건드린다) |

**3. 타입·이름 일관성**

- 승격 필드는 전 구간 **`agent`** (`source` 아님) — `dedup():76`이 `agent`→`sources`를 만들고 `render():160`이 `sources`/`agent`만 읽는다
- ambiguity 패턴은 전 구간 **`(?<![\w-])…(?![\w-])`** (`\b` 아님)
- kill switch 비교는 전 구간 **`== "1"`** (느슨한 참 판정 아님)
- 모델 락은 전 구간 **positive + negative 쌍**
- 신규 함수: `load_yaml_doc` · `extract_verdicts` · `extract_new_findings` · `promote_new_findings` — Task 9에서 정의하고 같은 태스크에서만 소비한다. 기존 `finding_id(f)`·`dedup`·`suppress`·`render`는 시그니처가 그대로이고 `render`만 세 번째 인자 `dropped_malformed=0`(기본값 있음)이 추가된다

**4. placeholder 스캔**: TBD·TODO·"적절히"·"나중에" 없음. 정확한 파일:줄·정확한 문자열·실행 가능한 명령만 담았다. 두 곳만 구현 시 확인이 필요하고 그 확인 명령을 함께 적었다 — Task 3 Step 3(qg 러너 락의 배치 위치)과 Task 4(`security-reviewer.md` 대상 줄).
