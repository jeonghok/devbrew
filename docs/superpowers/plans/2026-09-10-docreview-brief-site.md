# brief 자리를 공유 docreview 엔진으로 전환 (PR 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `spec-distill` 의 interview brief 리뷰 자리를 자체 3단계 파이프라인(방향성·충실도·냉독)에서 공유 엔진 `shared/docreview/` 의 여덟 단계로 옮기고, 그 전환이 고아로 만드는 것을 전수 삭제한다.

**Architecture:** 엔진·프로필 스키마·행동 락·절차서(`references/reviewing-document.md`)는 PR 1/1b 가 만들었고 PR 2 가 design doc 자리를 그 첫 소비자로 붙였다. 이 PR 은 **둘째 소비자**를 붙인다 — `reviewing-brief/SKILL.md` 를 「프로필을 정하고 절차서를 읽어 따른다」 한 절 + `Agent()` dispatch 블록 둘 + 자리 고유의 진입 게이트만 남긴 껍데기로 줄이고, 옛 파이프라인의 파일 다섯과 그것을 재는 락들을 없앤다. 새로 만드는 컴포넌트는 없다.

**Tech Stack:** bash 3.2 · python 3.9.6 · 셸 기반 테스트 하니스(`shared/tests`, `plugins/*/tests`) · codex CLI(자문 채널, fail-open)

**Spec:** `docs/superpowers/specs/2026-09-06-document-review-redesign-design.md`
(§5.4 진입 배선 · §5.5 치환 표의 brief 행 · §6 여덟 단계 · §8 게이트/상한 · §10 의 PR 3 행 · AC 전부)

**물려받는 것:** `docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md` 의 `## Park` 절(P1~P10). **착수 전에 그 절을 읽어라** — 이 계획의 T1·T2·T7·T8 이 거기서 나왔다.

## 목차

- [Global Constraints](#global-constraints)
- [착수 전 baseline (실행자가 첫 액션으로 캡처한다)](#착수-전-baseline-실행자가-첫-액션으로-캡처한다)
- [File Structure](#file-structure)
  - [사라지는 것 (스펙 §5.5 brief 행 — 실재 확인됨)](#사라지는-것-스펙-55-brief-행--실재-확인됨)
  - [남는 것 (엔진 밖 · 자리 고유)](#남는-것-엔진-밖--자리-고유)
  - [이미 있는 것 (다시 만들지 말 것)](#이미-있는-것-다시-만들지-말-것)
  - [껍데기화 대상](#껍데기화-대상)
- [실행자에게 미리 알리는 함정 넷 (PR 2 가 값을 치르고 배운 것)](#실행자에게-미리-알리는-함정-넷-pr-2-가-값을-치르고-배운-것)
- [Task 1: brief 프로필 스키마를 게이트에서 닫는다 (Park P1)](#task-1-brief-프로필-스키마를-게이트에서-닫는다-park-p1)
- [Task 2: 절차서에 「배포 경로에서 부른다」를 명시한다 (Park P10)](#task-2-절차서에-배포-경로에서-부른다를-명시한다-park-p10)
- [Task 3: `reviewing-brief` 를 껍데기로 줄인다](#task-3-reviewing-brief-를-껍데기로-줄인다)
  - [두 자리가 다른 곳 — 템플릿을 그대로 베끼면 안 되는 지점 넷](#두-자리가-다른-곳--템플릿을-그대로-베끼면-안-되는-지점-넷)
  - [⚠️ 결정이 필요한 것 — 스펙이 답하지 않는다](#-결정이-필요한-것--스펙이-답하지-않는다)
- [Task 4: 옛 agent 둘을 지운다](#task-4-옛-agent-둘을-지운다)
- [Task 5: 옛 스크립트 셋을 지운다](#task-5-옛-스크립트-셋을-지운다)
- [Task 6: `merge_review.py` · `compute_issue_id.py` 와 그 락 넷을 지운다 (Park P8)](#task-6-merge_reviewpy--compute_issue_idpy-와-그-락-넷을-지운다-park-p8)
- [Task 7: 락 재조준 전수 실행](#task-7-락-재조준-전수-실행)
- [Task 8: 문서 · 버전 · CHANGELOG](#task-8-문서--버전--changelog)
- [Task 9: brief 자리 e2e 관측](#task-9-brief-자리-e2e-관측)
- [Park — 이 PR 이 닫지 않고 이름 붙여 안고 가는 것](#park--이-pr-이-닫지-않고-이름-붙여-안고-가는-것)
- [Self-Review (계획 저자가 직접 돌린 것)](#self-review-계획-저자가-직접-돌린-것)

## Global Constraints

스펙과 리포 `CLAUDE.md` 에서 그대로 옮긴 것. 모든 태스크의 요구사항에 암묵적으로 포함된다.

- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json` 을 **minor** bump(§10 의 PR 3 행). 지금 `1.0.0` → `1.1.0`. **머지 직전에 다시 확인한다** — 같은 버전 문자열은 충돌 없이 병합되고 git 이 알려주지 않는다.
- **환경 바닥**: python **3.9.6**(`match` 없음 · `str.removeprefix` 없음 · `X | Y` 타입 없음), bash **3.2**(`<<<` 없음 · `declare -A` 없음 · `$( )` 안 heredoc 없음). 모든 실행에 `PYTHONDONTWRITEBYTECODE=1`. `$?` 앞에 파이프를 두지 않는다.
- **검색**: `git grep -n` 을 쓴다. 셸 `grep -r <pat> .` 는 **숨김 디렉토리를 건너뛴다** — `.claude/` 를 따로 훑어야 완전하다.
- **스윕**: `find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/'`. **`/spike/` 제외는 필수**(실제 codex 를 호출하고 추적되는 골든 픽스처를 덮어쓴다). Bash 도구 호출에 **`timeout: 600000` 필수** — 약 440초가 걸리고 기본 120초면 조용히 백그라운드로 넘어간다.
- **baseline 은 rc 가 아니라 파일별 실패 «줄 수»로 비교한다.** 이미 RED 인 파일 «안»의 새 실패는 rc 로는 원리적으로 안 보인다. 착수 시점 선재 RED: `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`(2줄 `FAIL:`) · `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`(1줄 `✗`). 아티팩트: `test_assert_behavior.sh` 가 **통과** 메시지 안에 `✗` 글자를 낸다.
- **Law 2 — 쓰기 권한이 있는 리뷰어는 리뷰어가 아니다.** agent frontmatter 의 실재 필드는 `tools`(allowlist, fail-closed)와 `disallowedTools`(denylist) 둘뿐이다. **denylist 단독 금지** — 시간에 대해 fail-open 이다. command/skill 계층의 `allowed-tools` 는 **아무것도 제한하지 않는다**(실측) — 그것에 기대지 않는다.
- **배포 형태**: agent 는 `# copy-of:` 마커를 단 **바이트 동일 사본**으로 배포된다(심볼릭 링크 agent 는 dispatch 되지 않는다 — 2026-09-06 실측). 스크립트·reference 는 **상대 파일-레벨 심볼릭 링크**.
- **문서는 한국어 primary.** 영어는 식별자·고유명사·원문 인용·자연스러운 한국어 대응이 없는 기술어에 한정. `docs/**.md` 가 ~300줄 이상이면 `## 목차` 를 **같은 커밋에서** 동기화한다.
- **`git diff -- plugins/<name>` 은 심볼릭 링크 «대상»의 변경을 보지 못한다.** 플러그인의 배포 내용이 그 경로 아래 diff 없이 바뀔 수 있다.
- **kill switch 는 보안 컨트롤이다(P21).** egress 를 가진 dispatch 가 하나라도 게이트 밖에 있으면 그 스위치는 「껐다고 믿게만」 만든다.

---

## 착수 전 baseline (실행자가 첫 액션으로 캡처한다)

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in $(find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/' | sort); do
  bash "$t" >/tmp/one.txt 2>&1; rc=$?
  fl=$(grep -c '^FAIL:\|✗' /tmp/one.txt)
  echo "$t rc=$rc faillines=$fl"
done | tee baseline.txt
```

`baseline.txt` 를 워크스페이스에 보존한다. 완료 판정은 **이 파일과의 줄-수 비교**다.

---

## File Structure

### 사라지는 것 (스펙 §5.5 brief 행 — 실재 확인됨)

| 경로 | 줄 | 왜 사라지나 |
|---|---|---|
| `plugins/spec-distill/agents/brief-critic.md` | 89 | 엔진의 `doc-critic` 이 그 역할을 한다 |
| `plugins/spec-distill/agents/brief-direction-reviewer.md` | 69 | 방향성 축은 엔진의 프로필 `layer_rubric` 로 흡수된다 |
| `plugins/spec-distill/scripts/merge_brief_review.py` | 372 | 엔진의 `docreview_route.py` 가 병합·라우팅을 한다 |
| `plugins/spec-distill/scripts/build_brief_codex_prompt.py` | 115 | 엔진의 codex 러너가 프로필에서 프롬프트를 만든다 |
| `plugins/spec-distill/scripts/run_brief_codex_reviewer.sh` | 168 | `run_docreview_codex_reviewer.sh` 가 대신한다 |
| 충실도 재리뷰 루프(fresh-critic 상한 2) | — | 엔진의 **재리뷰 상한 2**(`reviewing-document.md` `## 상한`)가 대신한다 |

### 남는 것 (엔진 밖 · 자리 고유)

| 경로 | 줄 | 역할 |
|---|---|---|
| `plugins/spec-distill/agents/brief-readback.md` | 40 | 냉독은 리뷰가 아니라 **가독성 측정**이라 엔진의 finding 계약 밖이다 |
| `plugins/spec-distill/scripts/check_brief.py` | 1188 | **진입 게이트** — 엔진은 「게이트를 통과한 문서」만 받는다(§5.4) |
| `plugins/spec-distill/scripts/check_verbatim_coverage.py` | 404 | 같은 진입 게이트 |
| `plugins/spec-distill/scripts/build_brief_bundle.py` | 150 | payload+audit 를 한 문서로 조립 — 엔진의 입력 |
| `plugins/spec-distill/scripts/brief_review_state.py` | 400 | degrade 원장. **`docreview_state.py` 가 같은 파일의 «다른 키»를 쓴다**(§5.5) |

### 이미 있는 것 (다시 만들지 말 것)

| 경로 | 상태 |
|---|---|
| `plugins/spec-distill/references/docreview-profiles/brief.md` | **36줄, 배포 완료**(PR 1). `detectors: 1` · `allowed_dispositions: [decide, ask, fix, drop]` · `immutable: ["^6\\."]` · `web: true` |
| `plugins/spec-distill/references/reviewing-document.md` | 절차서 심볼릭 링크(정본 `shared/docreview/references/`) |
| `plugins/spec-distill/agents/doc-critic.md` · `doc-recritic.md` | 엔진 agent 사본 둘(PR 2 배포) |
| `plugins/spec-distill/scripts/docreview_*.py` · `run_docreview_codex_reviewer.sh` | 엔진 스크립트 심볼릭 링크 |

### 껍데기화 대상

`plugins/spec-distill/skills/reviewing-brief/SKILL.md` — **509줄 → 목표 약 200~300줄.**
템플릿은 PR 2 가 만든 `plugins/spec-distill/skills/reviewing-spec/SKILL.md`(302줄)다. **그 파일을 읽고 절 구조를 그대로 베낀다** — `## 입력` · `## 프로필` · `## 절차`(codex 리터럴 게이트 포함) · `## dispatch 블록 둘` · 자리 고유 절. 두 자리가 다른 곳은 아래 T3 이 하나씩 짚는다.

---

## 실행자에게 미리 알리는 함정 넷 (PR 2 가 값을 치르고 배운 것)

1. **마스터 경로로 스크립트를 부르지 마라.** 절차서는 스크립트를 벗은 파일명으로 부르는데, 정본 위치(`shared/docreview/scripts/`)로 해석하면 여덟 단계 중 둘에서 죽는다 — 셸 러너는 형제 `runner_common.sh` 부재로 fail-closed 기록을 남기고, `docreview_route.py` 는 `ModuleNotFoundError: No module named 'adjudication'` 로 죽는다. **배포 경로(`plugins/spec-distill/scripts/…`)에서 부른다.** T2 가 이것을 절차서에 명시한다.
2. **부재 단언에는 양의 짝이 필요하다.** 「X 가 없다」만 재는 락은 X 의 «대상»을 통째로 지워도 통과한다. 부재 락을 넣을 때마다 그 옆에 「대상이 실재하고 규칙이 그것을 잡는다」는 양의 짝을 함께 넣고, 둘 다 변이로 RED 를 보인다.
3. **변이 전에 커밋해라.** `git checkout --` 는 「내 마지막 변이」가 아니라 **HEAD** 로 되돌린다 — 변이 도중 새 편집을 했으면 그것이 사라지고, 복원 후 트리가 clean 해서 성공처럼 보인다.
4. **세션이 시작 시점의 플러그인 스냅샷을 수명 내내 들고 간다.** 이 PR 이 agent 를 지우거나 더한 뒤 같은 세션에서 그것을 dispatch 하려 하면 옛 집합이 응답한다. agent 변경을 실제로 확인하려면 **새 세션**이 필요하다.

---

## Task 1: brief 프로필 스키마를 게이트에서 닫는다 (Park P1)

**왜 이 태스크가 첫 번째인가** — 이것은 네 자리 전부에 걸리는 **스키마 변경**이고, brief 프로필을 이 PR 이 처음 실사용에 붙인다. 나중 태스크가 프로필을 쓰기 시작한 뒤에 스키마를 바꾸면 그 태스크들의 검증이 무효가 된다.

**결함(확인된 익스플로잇, 조용함)** — `docreview_state.py` 의 `load_profile()` 은 **최상위 키만** 여분 키 검사를 하고 `layer_rubric` 자신의 키는 열거하지 않는다(`.get("layer1")`·`.get("layer2")` 만 본다). 그래서 아래가 게이트를 **통과**한다:

```yaml
layer_rubric:
  layer1: [goal_fit, …]
  layer2: [placeholder, …]
  foo: |
    layer1: [decoy_recursive_layer1]
    layer2: [decoy_recursive_layer2]
```

codex 러너의 `_block_span("layer_rubric", …)` 은 블록으로 옳게 좁히지만 `_flow_list` 가 **그 블록 «안에서» 다시 무제한 last-match** 를 하므로, 더 깊이 들여쓴 `foo` 의 블록 스칼라 안 미끼가 이긴다. 결과는 `Layer 1 … categories: decoy_recursive_layer1`, rc=0, 가드 미발동 — **조용한 오독**이다.

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` — `load_profile()` 의 여분 키 검사
- Test: `shared/tests/test_docreview_profile_schema.sh` (신규)

**Interfaces:**
- Consumes: 없음(이 PR 의 첫 태스크)
- Produces: `load_profile()` 이 `layer_rubric` 의 허용 키를 `{layer1, layer2}` 로 닫는다. 이후 모든 태스크의 프로필 로드가 이 규칙 아래 있다.

- [ ] **Step 1: 익スプ로잇을 재현하는 실패 테스트를 쓴다**

`shared/tests/test_docreview_profile_schema.sh` 를 만든다. 이 리포의 셸 테스트 관용구는 같은 디렉토리의 기존 파일(예: `shared/tests/test_docreview_state.sh`)에서 그대로 가져온다 — assert 헬퍼·픽스처 배치·카운터 이름을 새로 짓지 않는다.

테스트가 재야 하는 것 셋:

1. **음(negative)** — `layer_rubric` 밑에 `layer1`·`layer2` 외의 셋째 키가 있는 프로필을 만들고, `load_profile()` 이 **거부**하는지(비-zero rc 또는 명시적 오류) 단언한다.
2. **양(positive pair)** — `layer1`·`layer2` 만 있는 정상 프로필은 **통과**하는지 단언한다. 이 짝이 없으면 「전부 거부」로 구현해도 음의 단언이 통과한다.
3. **실사용 프로필 넷이 전부 통과** — `plugins/spec-distill/references/docreview-profiles/{brief,design-doc,seed}.md` 와 `plugins/quality-gates/references/docreview-profiles/generic.md` 를 실제로 로드해 통과를 단언한다. 이것이 이 변경이 배포된 프로필을 깨지 않는다는 회귀 방지다.

- [ ] **Step 2: 실패를 확인한다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_profile_schema.sh
```

기대: 항목 1 이 RED(현재 코드는 셋째 키를 받아들인다), 항목 2·3 은 GREEN.

- [ ] **Step 3: `load_profile()` 의 여분 키 검사를 `layer_rubric` 안으로 넣는다**

`docreview_state.py` 의 `load_profile()` 을 읽고, 최상위 여분 키를 거부하는 **기존 코드와 같은 모양**으로 `layer_rubric` 의 허용 키를 `{layer1, layer2}` 로 닫는다. 오류 문면과 rc 는 최상위 검사의 것을 그대로 따른다 — 엔진의 오류 어휘는 계약이다.

- [ ] **Step 4: 통과를 확인하고 배포 프로필 넷이 안 깨졌는지 본다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_profile_schema.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_state.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_codex.sh
```

기대: 셋 다 rc 0, 실패 줄 0.

- [ ] **Step 5: 락의 이빨을 변이로 증명한다**

커밋 **전**에 하지 말고, 아래 Step 6 으로 커밋한 **뒤** 변이한다(함정 3).

- [ ] **Step 6: 커밋**

```bash
git add shared/tests/test_docreview_profile_schema.sh shared/docreview/scripts/docreview_state.py
git commit -m "fix(docreview): layer_rubric 의 허용 키를 게이트에서 닫는다 (Park P1)"
```

- [ ] **Step 7: 변이 — 고침을 되돌리면 RED 가 나는가**

`load_profile()` 에서 방금 더한 검사 한 줄을 지우고 테스트를 돌린다. 기대: 항목 1 만 RED, 항목 2·3 은 GREEN(부수 피해 없음). 그다음 `git checkout -- shared/docreview/scripts/docreview_state.py` 로 복원하고 재실행해 전부 GREEN 을 확인한다.

**보고할 것**: 어느 단언이 발화했는지, 부수 피해가 있었는지, 배포 프로필 넷의 통과 여부.

---

## Task 2: 절차서에 「배포 경로에서 부른다」를 명시한다 (Park P10)

**왜 이 태스크가 두 번째인가** — 이 계획의 실행자가 T3 부터 그 절차서를 따라 엔진을 돌린다. 이 한 줄이 없으면 실행자가 여덟 단계 중 둘에서 죽고, 그 시간이 그대로 낭비된다. **그리고 PR 4·PR 5 도 같은 문서를 읽는다.**

**Files:**
- Modify: `shared/docreview/references/reviewing-document.md` — `## 한 라운드` 절의 선결 블록
- Test: `shared/tests/test_docreview_procedure_paths.sh` (신규)

**Interfaces:**
- Consumes: 없음
- Produces: 절차서가 스크립트 호출 경로를 명시한다. T3~T9 의 실행자가 그것을 따른다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`shared/tests/test_docreview_procedure_paths.sh`:

1. **음** — 절차서 본문에 「배포 경로」를 뜻하는 지시가 있는지 단언한다. 문구는 구현자가 정하되 **body-unique** 여야 한다(헤더나 목차가 그 문구를 만족시키면 본문을 지워도 GREEN 이 된다 — 리포에 기록된 실패 유형).
2. **양의 짝** — 절차서가 실제로 스크립트를 부르는 줄이 **하나 이상 존재**함을 단언한다(하한). 이것이 없으면 스크립트 호출을 전부 지워도 음의 단언이 통과한다.

- [ ] **Step 2: 실패를 확인한다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_procedure_paths.sh
```

기대: 항목 1 RED, 항목 2 GREEN.

- [ ] **Step 3: 절차서를 고친다**

`shared/docreview/references/reviewing-document.md` 의 `## 한 라운드` 절, 선결 블록 바로 뒤에 한 문단을 더한다. 담아야 할 사실 셋 — 이 문단은 **값이 아니라 이유를 가르쳐야** 한다(세 자리가 이 문서에서 베낀다):

- 스크립트는 **배포 경로**(`<플러그인 루트>/scripts/…`)에서 부른다. 정본(`shared/docreview/scripts/`)에서 부르면 안 된다.
- 왜인가: 스크립트는 형제 파일에 의존한다 — 셸 러너는 `runner_common.sh` 를, `docreview_route.py` 는 `adjudication` 모듈을. 그 형제는 **배포 디렉토리에만** 있다(정본 트리에서는 다른 자리에 산다).
- 어떻게 죽는가: 셸 러너는 fail-closed 로 `codex_failed: true · reason: runner_common_unloadable` 을 기록하고 rc 0 으로 끝나고, `docreview_route.py` 는 `ModuleNotFoundError` 로 rc 1 에 죽는다. **둘 다 조용한 오독은 아니지만 라운드는 진행되지 않는다.**

- [ ] **Step 4: 통과 + 절차서를 읽는 기존 락이 안 깨졌는지 확인**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_procedure_paths.sh
git grep -ln 'reviewing-document' -- shared/tests 'plugins/*/tests' | while read t; do
  PYTHONDONTWRITEBYTECODE=1 bash "$t" >/tmp/o 2>&1; echo "$t rc=$? faillines=$(grep -c '^FAIL:\|✗' /tmp/o)"
done
```

- [ ] **Step 5: 심볼릭 링크 전파를 «실행으로» 확인한다**

`plugins/spec-distill/references/reviewing-document.md` 와 `plugins/quality-gates/references/…`(있으면)가 같은 파일을 가리키는지, 한 번 고치면 양쪽에 반영되는지 직접 본다:

```bash
git ls-files -s | grep 'reviewing-document'      # mode 100644 이 정본, 120000 이 링크
md5 -q shared/docreview/references/reviewing-document.md plugins/spec-distill/references/reviewing-document.md
```

기대: md5 동일. **설명을 믿지 말고 직접 확인한다.**

- [ ] **Step 6: 커밋**

```bash
git add shared/docreview/references/reviewing-document.md shared/tests/test_docreview_procedure_paths.sh
git commit -m "docs(docreview): 절차서가 스크립트를 배포 경로에서 부르도록 명시 (Park P10)"
```

- [ ] **Step 7: 변이**

더한 문단을 지우고 테스트를 돌려 항목 1 이 RED 가 되는지, 그리고 **항목 2 는 GREEN 으로 남는지**(격리) 확인한다. 복원 후 재실행.

---

## Task 3: `reviewing-brief` 를 껍데기로 줄인다

**이 PR 의 본체다.** 509줄을 약 200~300줄로 줄이고, 3단계 파이프라인을 엔진의 여덟 단계로 바꾼다.

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (509줄)
- 참조(읽기만): `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (302줄 — 템플릿)
- 참조(읽기만): `shared/docreview/references/reviewing-document.md` (절차 정본)
- Test: `plugins/spec-distill/tests/test_reviewing_brief_skill.sh` (기존 — 재작성)

**Interfaces:**
- Consumes: T1 의 닫힌 프로필 스키마 · T2 의 경로 명시
- Produces: `reviewing-brief` 가 엔진을 부른다. T4·T5 가 지우는 파일들의 **마지막 호출자가 이 파일이므로**, 이 태스크가 끝나야 그것들이 고아가 된다.

### 두 자리가 다른 곳 — 템플릿을 그대로 베끼면 안 되는 지점 넷

**베끼기 전에 이 넷을 먼저 결정하고 리포트에 적는다.**

| # | design doc 자리 | brief 자리 | 어떻게 |
|---|---|---|---|
| ① 진입 계약 | Stop 훅 mandate 가 `spec path`·`mode` 를 싣는다 | **호출자가 값을 쥔다** — `conducting-interview` 종료 Step A 가 `$PAYLOAD`·`$AUDIT` 를 넘긴다(§5.4) | `## 입력` 절을 훅 mandate 가 아니라 **호출자 계약**으로 다시 쓴다. 훅은 이 자리에 없다 |
| ② 진입 게이트 | arm-once 원장 기록 | **`check_brief.py gate` + `check_verbatim_coverage.py`** (§5.4 — 「엔진은 게이트를 통과한 문서만 받는다」) | 두 게이트를 **엔진 진입 «앞»** 에 둔다. 현행 SKILL 의 `## 진입 첫 액션` 절이 이미 그 자리이므로 그 로직을 보존한다 |
| ③ 엔진 입력 | 문서 파일 하나 | **번들** — `build_brief_bundle.py` 가 payload+audit 를 한 문서로 조립한다(§5.5 「남는 것」) | 절차서의 「문서(또는 번들)」 슬롯에 번들 경로를 넘긴다. 번들은 **한 번만** 조립해 세션 디렉토리 파일로 남긴다(두 소비자가 같은 바이트를 봐야 한다) |
| ④ 냉독 | 없음 | **`brief-readback`** 이 남는다(§5.5) — 리뷰가 아니라 가독성 «측정» 이라 finding 계약 밖이다 | 엔진 여덟 단계 «뒤»에 별도 절로 둔다. 그 출력은 finding 으로 라우팅되지 않고 게이트 텍스트에 advisory 로 붙는다 |

### ⚠️ 결정이 필요한 것 — 스펙이 답하지 않는다

**`cost_class: high` 지출 승인 게이트를 어떻게 할 것인가.**

현행 `reviewing-brief` 는 진입에 `AskUserQuestion` 지출 승인 게이트를 갖고 있고(하한 5 / 상한 9 모델 호출을 표로 제시), 리포 `CLAUDE.md` 는 **「모든 skill 에 `cost_class` 선언, `high` 는 지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke 해야 함」** 을 요구한다.

**스펙은 `cost_class` 를 한 번도 언급하지 않는다** — §5.4 의 「남는 것」 목록에도 없다. 그러므로 다음 셋 중 하나를 **골라야** 하고, 임의로 고르면 근거 없이 닫힌 결정이 된다:

- ⓐ **게이트를 유지한다** — 비용 표를 엔진 기준으로 다시 계산해서(라운드당 critic 1 + recritic 1 + codex 1, 상한 라운드 3 + 추가 라운드) 같은 자리에 둔다. 대가: 엔진의 다른 세 자리에는 없는 게이트라 비대칭이 생긴다.
- ⓑ **게이트를 없앤다** — `cost_class` 를 `medium` 으로 내리고 승인 게이트를 뗀다. 대가: 사용자의 지출 통제 하나가 사라진다. **`CLAUDE.md` 의 요구를 만족시키려면 `cost_class` 도 함께 내려야 한다** — 선언만 `high` 로 두고 게이트를 떼면 규약 위반이다.
- ⓒ **네 자리 공통으로 올린다** — 엔진의 라운드 게이트 자체에 지출 공시를 넣는다. 대가: 스펙 범위 밖이고 PR 4·5 에도 걸린다.

**이 결정은 착수 시 사용자에게 올린다.** 실행자가 고르지 않는다.

- [ ] **Step 1: 현행 파일과 템플릿을 끝까지 읽는다**

```bash
cat plugins/spec-distill/skills/reviewing-brief/SKILL.md          # 509줄 — 무엇이 사라지는가
cat plugins/spec-distill/skills/reviewing-spec/SKILL.md           # 302줄 — 무엇이 되어야 하는가
cat shared/docreview/references/reviewing-document.md             # 절차 정본
cat plugins/spec-distill/references/docreview-profiles/brief.md   # 36줄 — 이 자리의 프로필
```

리포트에 적을 것: 현행 509줄 중 **어느 절이 엔진으로 흡수되고 어느 절이 남는가**를 절 단위 표로. 이 표가 다음 스텝의 작업 목록이다.

- [ ] **Step 2: 재작성한다**

목표 구조(템플릿의 절 이름을 그대로 쓴다):

```
# reviewing-brief — 문서 리뷰 엔진의 brief 자리
## 입력          ← 호출자 계약(위 ①). 훅 mandate 아님
## 진입 게이트    ← check_brief.py gate + check_verbatim_coverage.py (위 ②). 엔진 앞
## 프로필        ← brief.md 경로 한 줄
## 번들          ← build_brief_bundle.py, 한 번만, 세션 디렉토리 파일로 (위 ③)
## 절차          ← reviewing-document.md 를 읽어 따른다 + codex 리터럴 게이트
## dispatch 블록 둘 ← doc-critic · doc-recritic (처분 락 때문에 호스트 안에 산다)
## 냉독          ← brief-readback (위 ④). 엔진 밖, advisory
## degrade 채널   ← brief_review_state.py 원장 + 엔진의 advisory
```

**codex 리터럴 게이트는 템플릿에서 그대로 가져온다.** 조건을 산문으로 적지 않는다 — 산문 조건은 집행되지 않는다. 특히 **잔존물 중화가 가용성 판정 «앞»** 이어야 하고, `rm` 의 rc 를 보고 실패하면 0바이트로 절단하고 둘 다 실패하면 codex 축을 끈다. 그 이유는 템플릿의 주석에 전부 적혀 있으니 읽고 같은 모양으로 옮긴다.

- [ ] **Step 3: 락을 다시 쓴다**

`plugins/spec-distill/tests/test_reviewing_brief_skill.sh` 를 새 계약에 맞게 재작성한다. PR 2 의 대응물(`plugins/spec-distill/tests/test_reviewing_spec_*.sh`)이 어떤 축을 재는지 읽고 같은 축을 이 자리에 세운다 — 특히 **codex 게이트 펜스를 «실행»하는 락**(`test_reviewing_spec_residue.sh`). 그 락이 없으면 잔존물 제거를 분기 안으로 되돌려도 스위트 전체가 조용하다(PR 2 실측: 263 파일 침묵).

- [ ] **Step 4: 펜스를 차가운 셸에서 실행한다**

읽지 말고 실행한다 — PR 2 의 I1 은 **읽으면 맞아 보이는** 펜스가 미할당 변수 둘로 죽는 결함이었다.

```bash
# 펜스를 codex-gate 마커 사이에서 잘라내 env -i 로 돌린다
```

기대: 네 인자가 전부 비지 않고, 잔존물 경로가 재도출되며, skip 경로 넷 전부에서 잔존물이 남지 않는다.

- [ ] **Step 5: 관련 스위트를 돌린다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_brief_review_entry.sh
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_brief_review_meta.sh
```

이 시점에 **일부 RED 가 정상이다** — T4·T5 가 아직 안 지운 것을 재는 락이 있다. RED 를 baseline 과 대조해 **이 태스크가 만든 것인지 다음 태스크가 닫을 것인지** 를 리포트에 구분해 적는다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/tests/test_reviewing_brief_skill.sh
git commit -m "refactor(spec-distill): reviewing-brief 를 엔진 껍데기로 — 3단계 파이프라인 → 여덟 단계"
```

---

## Task 4: 옛 agent 둘을 지운다

**Files:**
- Delete: `plugins/spec-distill/agents/brief-critic.md` · `plugins/spec-distill/agents/brief-direction-reviewer.md`
- Modify: `plugins/spec-distill/tests/test_brief_agents.sh` (그 둘을 재는 락)

**Interfaces:**
- Consumes: T3 이 호출자를 없앴다
- Produces: brief 자리의 agent 는 `brief-readback` + 엔진 사본 둘만 남는다

- [ ] **Step 1: 호출자가 정말 0인지 도출로 확인한다**

식별자만이 아니라 **개념 별칭**으로도 훑는다(PR 2 의 P6: 개명 목록이 불완전해 잔존 둘이 살아남았다).

```bash
git grep -n 'brief-critic\|brief_critic\|brief-direction-reviewer' -- ':!docs/archive' ':!docs/superpowers'
grep -rn 'brief-critic\|brief-direction-reviewer' .claude/ 2>/dev/null | grep -v '/worktrees/'
```

기대: 살아 있는 호출자 0. **`docs/archive/**` 와 과거 계획·인터뷰는 역사 기록이라 손대지 않는다** — 그것들은 쓰일 «당시» 참이었던 것을 계속 말해야 한다.

- [ ] **Step 2: 지운다**

```bash
git rm plugins/spec-distill/agents/brief-critic.md plugins/spec-distill/agents/brief-direction-reviewer.md
```

- [ ] **Step 3: `test_brief_agents.sh` 를 재조준한다**

그 락은 두 agent 의 `tools:` 표면을 재고 있었다. 지금 재야 할 것은 **엔진 agent 사본 둘의 표면**이다 — `doc-critic`·`doc-recritic` 이 `tools:` allowlist 를 갖고 있고 쓰기 도구가 없는지. 집합 등식 형태를 유지한다(Law 2 의 집행 지점).

**부재 단언을 넣을 때는 양의 짝을 함께 넣는다** — 「brief-critic 이 없다」만 재면 `agents/` 를 통째로 지워도 통과한다.

- [ ] **Step 4: 돌린다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_brief_agents.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh
```

- [ ] **Step 5: 커밋**

```bash
git commit -am "refactor(spec-distill): brief-critic·brief-direction-reviewer 삭제 — 엔진 agent 가 대신한다"
```

- [ ] **Step 6: 변이**

지운 agent 중 하나를 되살려 락이 RED 가 되는지, 그리고 `agents/` 를 비웠을 때 **양의 짝**이 RED 가 되는지 각각 확인한다(둘은 다른 단언이어야 한다).

---

## Task 5: 옛 스크립트 셋을 지운다

**Files:**
- Delete: `plugins/spec-distill/scripts/merge_brief_review.py`(372) · `build_brief_codex_prompt.py`(115) · `run_brief_codex_reviewer.sh`(168)
- Modify: 그것들을 재는 테스트 — `test_merge_brief_review.py` · `test_merge_brief_adjudication.py` · `test_brief_codex_axes.sh` (전수는 Step 1 이 도출한다)

**Interfaces:**
- Consumes: T3 이 호출자를 없앴다
- Produces: **`merge_brief_review.py` 가 사라지면 `merge_review.py`·`compute_issue_id.py` 의 마지막 import 가 사라진다** — T6 이 그것을 지운다

- [ ] **Step 1: 코퍼스를 도출한다 (열거하지 말 것)**

```bash
git grep -ln 'merge_brief_review\|build_brief_codex_prompt\|run_brief_codex_reviewer' \
  -- shared tools plugins ':!docs'
```

이 목록이 Step 3 의 작업 대상이다. **찾은 수 / 고친 수 / 역사 기록이라 제외한 수** 세 숫자를 리포트에 적는다 — 「고친 N」만 적은 스윕은 완전성을 증명하지 않는다.

- [ ] **Step 2: 지운다**

```bash
git rm plugins/spec-distill/scripts/merge_brief_review.py \
       plugins/spec-distill/scripts/build_brief_codex_prompt.py \
       plugins/spec-distill/scripts/run_brief_codex_reviewer.sh
```

- [ ] **Step 3: Step 1 이 낸 각 파일을 처리한다**

각 파일마다 셋 중 하나다 — **삭제**(그 파일의 존재 이유가 지워진 스크립트뿐), **재조준**(살아 있는 불변식이 있고 대상만 바뀜), **그대로**(다른 주제). 어느 쪽인지와 **왜**를 파일마다 한 줄로 리포트에 적는다.

**재조준할 때 주의** — 락이 「지워진 이름을 금지」하는 형태가 되면 그 이름이 다른 소유자에게 넘어갔을 때 거짓 RED 를 만든다. PR 2 에서 실제로 있었던 일이다(`rereview_count` 는 삭제된 게 아니라 소유자가 바뀌었다). **삭제인지 소유자 이동인지 먼저 확인한다.**

- [ ] **Step 4: 스윕 + baseline 대조**

```bash
find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/'
```

`timeout: 600000` 필수. baseline 과 **실패 줄 수**로 대조한다.

- [ ] **Step 5: 커밋**

```bash
git commit -am "refactor(spec-distill): brief 옛 병합·codex 스크립트 셋 삭제 + 락 재조준"
```

---

## Task 6: `merge_review.py` · `compute_issue_id.py` 와 그 락 넷을 지운다 (Park P8)

**왜 여기인가** — PR 2 가 이것을 이월했다. 그때 근거: `merge_brief_review.py:37` 이 세 함수를 import 하고 **그 실패 경로가 `try` 라 죽지 않고 조용히 degrade** 한다(실측). T5 가 그 import 를 없앴으므로 지금이 자리다.

**Files:**
- Delete: `plugins/spec-distill/scripts/merge_review.py` · `compute_issue_id.py` 와 그 락 넷(Step 1 이 도출)

**Interfaces:**
- Consumes: T5 가 마지막 import 를 없앴다
- Produces: design doc 자리의 옛 verdict 파이프라인 잔존이 0 이 된다(PR 2 의 §5.5 목표 완결)

- [ ] **Step 1: import 가 정말 0인지 확인한다**

```bash
git grep -n 'merge_review\|compute_issue_id' -- shared tools plugins ':!docs' ':!*CHANGELOG*'
```

**아직 import 가 남아 있으면 이 태스크를 진행하지 않는다** — 소유자를 리포트에 적고 컨트롤러에게 올린다. 조용히 degrade 하는 import 를 남긴 채 지우면 그 자리가 런타임에 죽는다.

- [ ] **Step 2: 지우고 락 넷을 처리한다**

Step 1 이 낸 락 목록에 T5 Step 3 과 같은 규칙을 적용한다(삭제 / 재조준 / 그대로 + 이유 한 줄).

- [ ] **Step 3: P6 의 잔존 둘도 여기서 정리한다**

PR 2 의 도출 스윕이 놓친 것 둘 — `plugins/spec-distill/README.md:266`(codex CLI 항목이 현재형으로 `Phase 3` 인용) · `plugins/spec-distill/scripts/merge_review.py:2`(모듈 docstring). **후자는 이 태스크가 파일째 지우므로 자동 해소된다.** 전자는 손으로 고친다 — 지금 줄 번호는 밀렸을 수 있으니 `git grep -n 'Phase 3' -- plugins/spec-distill/README.md` 로 다시 찾는다.

- [ ] **Step 4: 스윕 + 커밋**

```bash
git commit -am "refactor(spec-distill): merge_review·compute_issue_id 삭제 (PR 2 이월분) + Phase 3 잔존 인용 정리"
```

---

## Task 7: 락 재조준 전수 실행

**왜 별도 태스크인가** — T4·T5·T6 이 각자 자기 코퍼스를 처리했지만, **개념 별칭으로 다른 이름을 쓰는 참조는 그 코퍼스 밖에 있다.** PR 2 에서 식별자 축은 깨끗한데 별칭 축이 결함을 냈다.

**Files:** Step 1 이 도출한다. 착수 시점 예상 규모 — `plugins/spec-distill/tests/` 안에만 약 15개.

- [ ] **Step 1: 세 축으로 도출한다**

```bash
# 축 1 — 식별자(파일명·심볼)
git grep -ln 'brief-critic\|brief_critic\|brief-direction-reviewer\|merge_brief_review\|build_brief_codex_prompt\|run_brief_codex_reviewer\|merge_review\|compute_issue_id' -- shared tools plugins ':!docs'
# 축 2 — 개념 별칭(그 구성물을 «다른 이름»으로 부르는 곳)
git grep -ln '충실도\|방향성 리뷰\|fidelity_verdict\|brief_critic_rounds\|brief_review_stage' -- shared tools plugins ':!docs'
# 축 3 — 숨김 디렉토리(셸 grep 이 건너뛴다)
grep -rln 'brief-critic\|merge_brief_review\|fidelity_verdict' .claude/ 2>/dev/null | grep -v '/worktrees/'
```

**축 2 를 생략하지 말 것.** 축 1 만 돌리면 이 PR 의 대상 중 하나만 나온다(실측: 축 1 은 테스트 1개, 축 2 는 15개).

- [ ] **Step 2: 각 항목을 처리하고 세 숫자를 낸다**

**찾음 / 고침 / 역사 기록이라 제외** — 이 셋이 완료 oracle 이다.

- [ ] **Step 3: 이빨 없는 락을 찾아낸다**

이 PR 이 «발동 조건»을 없앤 락은 GREEN 을 유지하므로 스위트 diff 로는 안 보인다. 재조준한 락마다 **그 락이 무엇을 잡는지** 를 변이로 확인한다 — 잡는 것이 없으면 그 락은 지운다(있는 척하는 락은 없는 것보다 나쁘다).

- [ ] **Step 4: 전수 스윕 + baseline 대조 + 커밋**

---

## Task 8: 문서 · 버전 · CHANGELOG

**Files:**
- Modify: `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `docs/philosophy/devbrew-harness-philosophy.md`(코드 지도에 brief 자리 항목이 있으면)

- [ ] **Step 1: 버전을 minor bump 한다**

`plugins/spec-distill/.claude-plugin/plugin.json` 을 `1.0.0` → `1.1.0`. **새 surface 가 아니라 자리 전환이지만 §10 이 minor 로 정했다.**

- [ ] **Step 2: CHANGELOG 를 쓴다**

`## [1.1.0] — YYYY-MM-DD` 아래 Added/Changed/Removed/Fixed. **한 블록 안에서 자기모순이 없게 한다** — PR 2 에서 정정 항목과 그 이웃이 반대 규칙을 가르치는 일이 두 번 있었고 커밋 둘이 더 들었다. **쓰고 나서 그 블록의 각 항목이 릴리스의 실제 상태와 맞는지 하나씩 대조한다.**

- [ ] **Step 3: README 의 「Principles Instantiated」를 갱신한다**

brief 자리가 이제 어느 법칙·원칙을 구현하는지. **죽은 술어를 남기지 않는다** — PR 2 의 I2 가 그것이었고, `test_readme_sync.sh` 는 키워드의 «존재»만 재고 제거된 구성물의 «부재»를 안 재므로 구조적으로 못 잡는다. 그 락에 **부재 단언 + 양의 짝**을 더한다.

- [ ] **Step 4: 문서를 읽는 스위트를 도출해서 돌린다**

추정하지 말고 **경로가 열리는 자리**를 grep 한다:

```bash
git grep -ln 'README.md\|CHANGELOG.md\|devbrew-harness-philosophy' -- shared/tests 'plugins/*/tests'
```

- [ ] **Step 5: 커밋**

---

## Task 9: brief 자리 e2e 관측

**성격** — 만들지 않고 **돌린다.** 「무엇이 관측됐는가」만 적고, 코드가 그렇게 한다고 적힌 것은 적지 않는다.

- [ ] **Step 1: 실제 brief 하나로 한 라운드를 돈다**

**대상 문서의 «사본»에서 돈다.** 엔진은 `decide`·`defer` 에서 `--log-file` 로 **리뷰 대상에 쓴다** — 추적본을 브랜치 중간에 바꾸면 아무도 리뷰하지 않은 변경이 된다.

절차서를 **문면 그대로** 따른다(선결 `mkdir`+`init` 포함). 그 자체가 T2 의 검증이다.

- [ ] **Step 2: 관측 항목**

| 항목 | 무엇을 보는가 |
|---|---|
| 진입 게이트 | `check_brief.py gate` · `check_verbatim_coverage.py` 가 엔진 «앞»에서 도는가. 실패 시 엔진에 진입하지 않는가 |
| 번들 | 한 번만 조립되는가. critic 과 codex 가 **같은 바이트**를 보는가 |
| 여덟 단계 | 전부 도는가. degrade 채널이 무엇을 말하는가 |
| 냉독 | `brief-readback` 이 finding 으로 라우팅되지 «않고» advisory 로만 붙는가 |
| 게이트 | `decide` 가 몇 건인가. **PR 2 의 두 표본은 13 과 7 이었고 게이트 항목 합은 14 와 15 였다** — 셋째 표본을 기록한다 |
| kill switch | `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 로 한 라운드. 직전 라운드 산출물이 삼켜지지 않는가(`codex_absent: true` 인가) |

- [ ] **Step 3: 실제 codex 호출 횟수를 보고한다**

- [ ] **Step 4: 관측 결과를 리포트에 쓴다. 커밋은 없다**

---

## Park — 이 PR 이 닫지 않고 이름 붙여 안고 가는 것

PR 2 의 `## Park` P5(kill switch 성질의 경계 넷) 중 **셋은 이 PR 의 범위 밖**이다 — 권한 조합 하나(디렉토리·파일 둘 다 쓰기 불가) · 절단 tier 가 락 밖 · `set -e` 침묵. 그 셋은 `reviewing-spec` 과 `reviewing-brief` 두 자리에 **같은 모양으로** 존재하게 되므로, 고칠 때 두 자리를 함께 고쳐야 한다. **PR 4 가 셋째 자리를 만들기 전에 닫는 것이 가장 싸다.**

**되돌리는 말** — 「P5 의 셋도 이 PR 에서 닫아」.

---

## Self-Review (계획 저자가 직접 돌린 것)

**1. 스펙 커버리지** — §5.4(진입 배선)→T3 · §5.5 brief 행의 「사라지는 것」 여섯→T4·T5·T6 · 「남는 것」 다섯→T3 이 보존 · §6 여덟 단계→T3 · §8 상한→절차서가 정하므로 T3 이 인용만 · §10 버전→T8 · AC→T9 이 관측.
**갭 하나**: `cost_class`·지출 승인 게이트를 스펙이 다루지 않는다 → T3 에 **결정 지점**으로 명시했고 실행자가 고르지 않는다.

**2. placeholder 스캔** — 「적절히」·「필요하면」·「TBD」 없음. 코드가 필요한 스텝 중 **내가 원문을 읽지 않은 파일의 내용은 지어내지 않았다** — 대신 「그 파일을 읽고 같은 모양으로」 + 정확한 경로를 줬다. 이것은 placeholder 가 아니라 옳은 지시다(설계가 도구·코드 동작 사실을 단정하면 산문은 틀려도 소리를 내지 않는다).

**3. 타입·이름 정합** — T5 가 「마지막 import 를 없앤다」고 하고 T6 이 그것을 전제로 삼는다(T6 Step 1 이 그 전제를 **실행으로 확인**하고 아니면 멈춘다). T1 의 `load_profile()` 이 T3 의 프로필 로드에 선행한다.
