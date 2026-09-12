# 문서 리뷰 엔진 — design doc 자리 전환 (PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `spec-distill` 의 design doc 리뷰 자리를 옛 verdict 파이프라인에서 `shared/docreview/` 엔진으로 치환하고, 첫 호출자가 붙는 이 시점에 설계 §6.4 「알려진 한계 셋」을 그 공통 뿌리에서 닫는다.

**Architecture:** 엔진은 이미 `shared/docreview/` 에 있고 스크립트 넷이 심볼릭 링크로 배포돼 있다. 이 PR 이 더하는 배포는 둘 — agent 사본 둘(`copy-of` 마커, 링크는 dispatch 안 된다)과 절차 reference 링크 하나. `reviewing-spec/SKILL.md` 는 「프로필을 정하고 절차서를 읽어 따른다」 + dispatch 블록 둘 + arm-once 진입 게이트만 남는 껍데기가 되고, 옛 탐지·병합·codex 경로는 삭제된다. 세 fail-open 은 개별 patch 가 아니라 **상태 축의 정본 표** 하나를 세우고 `is_open`·`gate_summary`·`render_gate`·선택지 제안을 전부 거기서 도출해 닫는다.

**Tech Stack:** python 3.9.6 (`match` 없음) · bash 3.2 (macOS — `<<<` 없음 · `declare -A` 없음 · `${var^^}` 없음 · `$( )` 안 heredoc 파싱 깨짐) · git 2.50.1 · 테스트는 `shared/tests/assert.sh` 위의 셸 락 + `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-09-06-document-review-redesign-design.md` — 특히 §5.1(물리 배치) · §5.4(진입 자리 배선) · §5.5(치환되는 것) · §6.4(승인의 도출 + 알려진 한계 셋) · §8.1~§8.4(게이트·상한·stagnation) · §10(이관, PR 2 행) · §12(Files to Modify) · AC1·AC2·AC7·AC9·AC13·AC14·AC16·AC17·AC27.

## 목차

- [Global Constraints](#global-constraints)
- [File Structure](#file-structure)
- [태스크 순서와 의존](#태스크-순서와-의존)
- [계획 안의 코드에 대하여](#계획-안의-코드에-대하여)
- [착수 전 baseline (2026-09-08, `main` = `3210b925` 에서 실측)](#착수-전-baseline-2026-09-08-main--3210b925-에서-실측)
  - [Task 1: 엔진 배포 — agent 사본 둘 · reference 링크 하나 · 링크 락 확장](#task-1-엔진-배포--agent-사본-둘--reference-링크-하나--링크-락-확장)
  - [Task 2: `escalated` 예약의 누적 — 라운드 n−1 하드코딩을 없앤다](#task-2-escalated-예약의-누적--라운드-n1-하드코딩을-없앤다)
  - [Task 3: 상태 축의 정본 표 — 「막는 집합 ⊆ 그리는 집합」을 도출로 만든다](#task-3-상태-축의-정본-표--막는-집합--그리는-집합을-도출로-만든다)
  - [Task 4: 알려진 한계 (a) — 재상승 후속의 「보류」 · 제안하는 선택지 = 받아주는 선택지](#task-4-알려진-한계-a--재상승-후속의-보류--제안하는-선택지--받아주는-선택지)
  - [Task 5: 알려진 한계 (b) — 재상승 후속이 원본의 `kind` 를 물려받는다](#task-5-알려진-한계-b--재상승-후속이-원본의-kind-를-물려받는다)
  - [Task 6: `reviewing-spec` 껍데기화 + 상한 락 재작성 + 인접 락 둘](#task-6-reviewing-spec-껍데기화--상한-락-재작성--인접-락-둘)
  - [Task 6b: 엔진 러너의 PyYAML 의존 제거 · 배선 락의 심볼릭 링크 맹점](#task-6b-엔진-러너의-pyyaml-의존-제거--배선-락의-심볼릭-링크-맹점)
- [Park — 이 PR 이 닫지 않고 이름 붙여 안고 가는 것](#park--이-pr-이-닫지-않고-이름-붙여-안고-가는-것)
  - [P1 — `layer_rubric` 안의 셋째 키를 통한 재귀 미끼 (확인된 익스플로잇, 조용함)](#p1--layer_rubric-안의-셋째-키를-통한-재귀-미끼-확인된-익스플로잇-조용함)
  - [P2 — spike 테스트가 추적되는 골든 픽스처를 자기 실행으로 덮어쓴다](#p2--spike-테스트가-추적되는-골든-픽스처를-자기-실행으로-덮어쓴다)
  - [P3 — T-AC7: 「추가 라운드 1회 열기」를 스펙 두 조항이 서로 부정한다](#p3--t-ac7-추가-라운드-1회-열기를-스펙-두-조항이-서로-부정한다)
  - [P4 — 라운드 게이트의 크기: 개별 응답 14건 대 「`AskUserQuestion` 하나」](#p4--라운드-게이트의-크기-개별-응답-14건-대-askuserquestion-하나)
  - [P5 — kill switch 성질의 «경계» (보안, PR 3 첫 항목)](#p5--kill-switch-성질의-경계-보안-pr-3-첫-항목)
  - [P6 — 도출 스윕이 놓친 인용 둘](#p6--도출-스윕이-놓친-인용-둘)
  - [P7 — 이 PR 이 스스로 검증하지 못한 것 (**AC8 은 2026-09-10 닫힘**)](#p7--이-pr-이-스스로-검증하지-못한-것-ac8-은-2026-09-10-닫힘)
  - [P8 — PR 3 이 물려받는 이월분 (판정 2)](#p8--pr-3-이-물려받는-이월분-판정-2)
  - [P10 — 절차서가 스크립트를 벗은 파일명으로 부른다 (마스터 경로 호출)](#p10--절차서가-스크립트를-벗은-파일명으로-부른다-마스터-경로-호출)
  - [P9 — 닫힌 항목 (기록만)](#p9--닫힌-항목-기록만)
  - [Task 7: 삭제 전수(D0) 실행 — 파일 셋 + 고아 락 다섯 + 같은 커밋 재조준 여덟](#task-7-삭제-전수d0-실행--파일-셋--고아-락-다섯--같은-커밋-재조준-여덟)
  - [Task 8: 문서 · 버전 · 철학 코드 지도](#task-8-문서--버전--철학-코드-지도)
  - [Task 9: 자리별 e2e — 이 설계 문서 자체로 라운드 3회 + AC27 나머지 절반](#task-9-자리별-e2e--이-설계-문서-자체로-라운드-3회--ac27-나머지-절반)

## Global Constraints

스펙에서 그대로 옮긴 값이다. 모든 태스크의 요구에 이 절이 암묵으로 포함된다.

- **python 은 3.9.6.** `match` 문 · `X | Y` 타입 문법 · `dict |` 병합 금지. 모든 python 실행에 `PYTHONDONTWRITEBYTECODE=1` 을 붙인다 — 같은 길이 변이가 stale `.pyc` 를 못 넘어 거짓 GREEN·거짓 RED 를 둘 다 낸다.
- **bash 는 3.2**(macOS 기본). `<<<` · `declare -A` · `${var^^}` · `$( )` 안의 heredoc 을 쓰지 않는다. 파이프 뒤에서 `$?` 를 읽지 않는다 — 파이프 마지막 명령의 코드가 잡힌다.
- **`rereview_cap` 의 정본은 `shared/docreview/references/reviewing-document.md` 5행의 `` `rereview_cap: 2` `` 한 줄이다.** 다른 어떤 파일도 이 숫자의 출처가 아니다.
- **`DISPATCH_ATTEMPT_CAP` = 3 · `INFLIGHT_TTL_SEC` = 900 은 Stop 훅의 것이고 이 PR 이 바꾸지 않는다.**
- **`plugins/spec-distill/hooks/review-dispatch.py` 는 무변경**(설계 §3 Non-goal). `references/proceed-gate.md` 도 무변경.
- **`quality-gates` 의 `skills/quality-pipeline/`(코드 리뷰) 상한 5 는 범위 밖이다.** 그 5 를 건드리지 않는다.
- **agent 는 링크가 아니라 `copy-of` 바이트 동일 사본이다** — 심볼릭 링크로 둔 agent 는 dispatch 되지 않는다(2026-09-06 실측, 설계 §5.1). `scripts/`·`references/` 는 파일 단위 **상대** 심볼릭 링크다.
- **리뷰어 agent 의 `tools:` 에 `Write`·`Edit`·`Bash` 가 없다**(Law 2, AC16).
- **모든 `Agent()` dispatch 자리에 처분 한 줄**: `**처분** — consumer=<경로|orchestrator|human> · fail-<open|closed> · disclosure=<리터럴>`. `consumer=` 가 경로면 그 경로는 **앵커가 사는 파일과 같은 플러그인**의 추적되는 파일이어야 한다(AC17, `shared/tests/test_dispatch_disposition.sh`).
- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json` 을 `1.0.0` 으로 major bump 하고 `CHANGELOG.md` 에 `## [1.0.0] — 2026-09-08` 항목을 같은 커밋에 담는다. **버전 문자열은 머지 직전에 최종 확정한다** — 같은 버전 문자열은 충돌 없이 병합되므로 git 이 경고하지 않는다.
- **선재 RED 둘**(이 PR 이 만든 것이 아니다): `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`(주 단언은 통과, 자기 양성 대조가 실패) · `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh`(단언 2건). baseline 은 rc 가 아니라 **파일별 실패 줄 수**로 비교한다.
- **테스트 스윕**: `find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/'` (spike 는 실제 codex 를 태우고 추적 픽스처를 덮어쓴다). python 은 플러그인 `tests/` **최상위만** — 하위 디렉토리는 픽스처와 숨은 오라클이라 다른 테스트의 입력이다.
- **shell `grep -r <pat> .` 를 쓰지 않는다** — 이 리포의 `grep` 은 셸 함수라 숨김 디렉토리를 건너뛴다. `git grep -n` 을 쓴다.

---

## File Structure

| 파일 | 책임 | 태스크 |
|---|---|---|
| `plugins/spec-distill/agents/doc-critic.md` · `doc-recritic.md` | 배포 사본(`copy-of` 마커 1줄). 링크는 dispatch 안 됨 | T1 |
| `plugins/spec-distill/references/reviewing-document.md` | 절차서 정본으로의 상대 심볼릭 링크 | T1 |
| `shared/tests/test_copy_of_contract.sh` | 축 1a 도출을 `{scripts,agents,references}` 로 확장 | T1 |
| `shared/docreview/scripts/docreview_state.py` | **상태 축의 정본 표** + 그 표에서 도출하는 `is_open`·`gate_summary`·`render_gate`·재결정 수용 술어 | T2·T3·T4 |
| `shared/docreview/scripts/docreview_route.py` | `escalated` 예약 누적 · 재상승 후속의 `kind` 승계 · 선택지 제안을 상태에서 도출 | T2·T4·T5 |
| `shared/tests/test_docreview_gate_visibility.sh` | 신규 ∀ 락 — 「막는 집합 ⊆ 그리는 집합」 | T3 |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 껍데기 — 프로필 지정 · 절차서 포인터 · dispatch 블록 둘 · arm-once 게이트 | T6 |
| `plugins/spec-distill/tests/test_rereview_cap_consistency.sh` | 재작성 — 정본은 절차서의 `rereview_cap` | T6 |
| (삭제) `agents/spec-reviewer.md` · `scripts/build_spec_codex_prompt.py` · `scripts/run_spec_codex_reviewer.sh` + 그것만 재는 락 다섯 | 옛 verdict 파이프라인 | T7 |
| (**이월**) `scripts/merge_review.py` · `compute_issue_id.py` + 그 락 넷 | `merge_brief_review.py:37` 이 아직 import 한다 — brief 자리를 전환하는 PR 3 이 지운다 | — |

## 태스크 순서와 의존

```
T1 배포 ─┐
         ├─ T6 껍데기화 ─ T7 삭제 ─ T8 문서 ─ T9 e2e
T2 ─ T3 ─┤            (T6 은 T1 의 agent·reference 가 있어야 배선이 성립한다)
     └ T4·T5 (T3 뒤 아무 때나)
```

- **T2 가 T3 앞이다.** T3 이 `escalated` 를 차단 행으로 만들면 좌초한 예약이 「후속으로 갈 길이 없는데 승인은 영구히 막는」 상태가 된다 — T2 가 그 좌초를 먼저 없앤다.
- **T1 이 T6 앞이다.** 껍데기가 `spec-distill:doc-critic` 을 dispatch 하고 `references/reviewing-document.md` 를 읽는다.
- **T6 이 T7 앞이다.** 껍데기가 먼저 서야 삭제가 남긴 참조를 0 으로 만들었는지 대조할 대상이 생긴다. T6 뒤 T7 앞의 중간 상태에는 RED 가 있다 — T6 의 report 가 그 목록을 적고 T7 이 0 으로 만든다.
- **T9 는 마지막이다.** 엔진은 지금까지 실제 리뷰를 한 번도 돈 적이 없다 — 이 e2e 가 첫 실측이다.

## 계획 안의 코드에 대하여

이 계획의 코드 블록은 **그대로 붙여 넣으라는 것이 아니라 무엇을 쓰라는 것**이다. 특히 픽스처 케이스 본문(`case_*`)은 실행 시점의 finding id 에 의존하므로, 이 계획이 그 값을 미리 적으면 틀린다. 그런 자리는 **리포에 실재하는 형제 케이스를 이름으로 지목**하고 「그것을 읽고 같은 모양으로 쓰라」고 적었다 — 계획이 지어낸 코드보다 실재하는 예시가 정확하기 때문이다. 형제를 지목한 자리는 그 형제가 실재하는지 먼저 확인하고, 없으면 멈추고 보고한다.

## 착수 전 baseline (2026-09-08, `main` = `3210b925` 에서 실측)

rc 가 아니라 **파일별 실패 줄 수**로 기록한다 — 이미 RED 인 파일 안의 새 실패는 rc 로 안 보인다.

| 파일 | rc | 실패 줄 | 통과 줄 |
|---|---|---|---|
| `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` | 1 | **2** | 0 |
| `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` | 1 | **1** | 3 |

그 밖의 셸 락 전부 rc=0, 실패 0. python 락(플러그인 `tests/` 최상위) 전부 rc=0(`test_hook_output_schema.py` 는 skip 1건 포함). 스윕 명령은 Global Constraints 에 있다.

**stagnation 술어의 교체(설계 §8.4)에 이 PR 이 하는 일**: 새 술어(라운드 n 의 열린 계보 집합이 n−1 과 같고 진행 0건)는 엔진의 `gate_summary` 에 **이미 있다**. 이 PR 이 하는 것은 옛 술어(`raised_count >= 3 AND dismissed_by_user == 0`)를 design doc 자리에서 **떼는 것**이고, 그 자리는 껍데기화되는 SKILL.md 본문이다(T6). 옛 술어의 구현체 `merge_review.py` 자체는 brief 자리가 아직 쓰므로 PR 3 이 지운다.

각 태스크는 `plugin.json` bump 과 CHANGELOG 를 **마지막 태스크에서 한 번** 담는다(같은 PR 안에서 버전 줄이 태스크마다 충돌하는 것을 피한다). 나머지 CLAUDE.md 요구(README 「Principles Instantiated」)는 T8 이 담는다.

---

### Task 1: 엔진 배포 — agent 사본 둘 · reference 링크 하나 · 링크 락 확장

**Files:**
- Create: `plugins/spec-distill/agents/doc-critic.md`
- Create: `plugins/spec-distill/agents/doc-recritic.md`
- Create (symlink): `plugins/spec-distill/references/reviewing-document.md`
- Modify: `shared/tests/test_copy_of_contract.sh`

**Interfaces:**
- Produces: dispatch 가능한 `spec-distill:doc-critic` · `spec-distill:doc-recritic`, 그리고 `Read` 로 읽히는 `${CLAUDE_PLUGIN_ROOT}/references/reviewing-document.md`. T6 의 껍데기 skill 이 이 셋을 전부 이름으로 부른다.
- Consumes: `shared/docreview/agents/*.md` · `shared/docreview/references/reviewing-document.md`(정본, 무변경).

**배경(이 태스크가 왜 필요한가):** PR 1 은 `scripts/` 링크 넷만 심었다(`plugins/spec-distill/CHANGELOG.md` 의 0.53.0 항목: *"이 릴리스는 `scripts/` 링크 넷만 심고"*). 그래서 오늘 `plugins/spec-distill/agents/` 에 `doc-critic` 이 없고 `references/reviewing-document.md` 도 없다 — 껍데기 skill 이 그 둘을 부르면 dispatch 실패와 파일 부재로 죽는다.

- [ ] **Step 1: 확장 전 도출 수를 먼저 잰다 (AC14 · D12 — 값이 안 변한다는 것을 재고 바꾼다)**

이 락은 이미 두 번 같은 방법으로 넓혀졌고(주석의 2026-08-18 · 08-22 실측), 그 관례는 **넓히기 전에 기존 정본의 도출 수를 기록하는 것**이다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh > /tmp/copyof-before.txt 2>&1; echo "rc=$?"
grep -cE '^\s*✓' /tmp/copyof-before.txt
grep -E 'symlink-∀' /tmp/copyof-before.txt | sort | uniq -c | sort -rn | head -20
```

이 출력을 report 파일에 그대로 붙인다. Step 5 가 확장 **후** 같은 명령을 돌려 기존 정본(`codex_findings_to_yaml.py` · `detect_codex.sh` · `prompt-preamble.md` · `adjudication.py` · `render_disposition.py` · docreview 스크립트 넷)의 도출 수가 같은지 대조한다.

- [ ] **Step 2: reference 링크를 심는다**

`scripts/` 의 기존 링크와 **같은 깊이**다(`plugins/<host>/references/` → `shared/`), 그러므로 상대 경로도 `../../../shared/…` 로 같다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
ln -s ../../../shared/docreview/references/reviewing-document.md \
      plugins/spec-distill/references/reviewing-document.md
# 검증: 링크가 실제로 풀리는가 + 인덱스 모드 비트가 120000 인가
test -f plugins/spec-distill/references/reviewing-document.md && echo "resolves OK"
git add plugins/spec-distill/references/reviewing-document.md
git ls-files -s -- plugins/spec-distill/references/reviewing-document.md
```

마지막 줄이 `120000` 으로 시작해야 한다. `100644` 면 링크가 아니라 복사본이 스테이지된 것이다.

- [ ] **Step 3: agent 사본 둘을 만든다**

마커는 **frontmatter 안의 YAML 주석 줄**이다. `---` 다음 줄에 넣는다 — 락은 마커가 몇 번째 줄에 있든 `head -20` 안이면 찾고, 비교 전에 **그 한 줄만** 지운다(`sed "${lineno}d" "$f" | diff - "$target"`). 파일 첫 줄에 넣으면 frontmatter 가 1행에서 시작하지 않게 되므로 안 된다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
for a in doc-critic doc-recritic; do
  src="shared/docreview/agents/$a.md"
  dst="plugins/spec-distill/agents/$a.md"
  { head -1 "$src"                                  # '---'
    echo "# copy-of: shared/docreview/agents/$a.md"
    tail -n +2 "$src"; } > "$dst"
done
head -3 plugins/spec-distill/agents/doc-critic.md
```

기대 출력:
```
---
# copy-of: shared/docreview/agents/doc-critic.md
name: doc-critic
```

- [ ] **Step 4: 사본이 dispatch 되는지 실측한다 (설계를 도구 동작 사실로 단정하지 않는다)**

frontmatter 안의 `#` 주석 줄을 agent 로더가 받아들이는지는 **이 리포에 실측이 없다.** YAML 은 주석을 허용하지만 로더가 YAML 파서를 쓴다는 보장은 없다. 격리 설치로 잰다 — `CLAUDE_CONFIG_DIR` 를 빈 임시 디렉토리로 두고(쓰기 전에 비어 있음을 먼저 증명한다) 세션 `init` 의 `agents` 배열에 `spec-distill:doc-critic` 이 나오는지 본다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
T="$(mktemp -d -t agentprobe-XXXXXX)"
[ -z "$(ls -A "$T")" ] && echo "격리 증명: 빈 디렉토리"
CLAUDE_CONFIG_DIR="$T" claude -p 'list your available agent types, one per line' \
  --plugin-dir plugins/spec-distill 2>&1 | grep -i 'doc-critic\|doc-recritic'
rm -rf "$T"
```

`doc-critic` 과 `doc-recritic` 이 **둘 다** 나와야 한다. 하나라도 안 나오면 **멈추고 보고한다** — 그때의 대안은 마커를 frontmatter **뒤**(본문 첫 줄, 여전히 `head -20` 안)로 옮기는 것이고, 그것도 실패하면 배포 방식 자체가 재검토 대상이라 컨트롤러의 판정이 필요하다. 위 명령이 환경 문제로 아예 안 돌면(그 자체가 관측이다) 무엇이 어떻게 실패했는지 report 에 적고 **성공했다고 적지 않는다** — 확증 실패는 부재 증명이 아니다.

- [ ] **Step 5: 링크 락 축 1a 를 세 디렉토리로 넓힌다**

`shared/tests/test_copy_of_contract.sh` 축 1a 안의 **구조 도출**과 **산문 도출** 둘 다 넓힌다. 구조만 넓히면 「참조는 하는데 배포 지점이 없는 플러그인」을 reference 에 대해 못 잡는다(그 파일 자신의 주석이 그렇게 적고 있다).

구조 도출 — 현행:

```bash
  idx_plugins="$(git ls-files -- "plugins/*/scripts/$base" 2>/dev/null \
                  | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"
  wt_plugins="$(for _p in plugins/*/scripts/"$base"; do
                  { [ -e "$_p" ] || [ -L "$_p" ]; } && printf '%s\n' "$_p"
                done 2>/dev/null | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"
```

교체 후 — 디렉토리 셋을 **한 곳에서** 열거하고 둘 다 그 목록을 돈다(열거가 두 벌이면 다음 저자가 한쪽만 고친다):

```bash
  # 배포 디렉토리는 셋이다 — scripts(실행·source) · agents(사본) · references(절차서).
  # agent 는 사본이라 축 1a 의 정본 목록에 안 들지만, 미래에 링크로 배포되는 것이
  # 생겨도 조용히 빠지지 않게 세 디렉토리를 함께 본다(설계 §5.1).
  DEPLOY_DIRS="scripts agents references"
  idx_plugins="$(for _d in $DEPLOY_DIRS; do
                   git ls-files -- "plugins/*/$_d/$base" 2>/dev/null
                 done | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"
  wt_plugins="$(for _d in $DEPLOY_DIRS; do
                  for _p in plugins/*/"$_d"/"$base"; do
                    { [ -e "$_p" ] || [ -L "$_p" ]; } && printf '%s\n' "$_p"
                  done
                done 2>/dev/null | sed -nE 's#^plugins/([^/]+)/.*#\1#p' | sort -u)"
```

산문 도출 — 현행의 `scripts/${esc_base}` 참조 패턴과 자기-제외 패턴을 같은 세 디렉토리로 넓힌다:

```bash
  refs="$( { git ls-files -- 'plugins/*' | grep -vE '/(fixtures|mocks|harness)/'; echo /dev/null; } \
            | tr '\n' '\0' \
            | xargs -0 grep -lE "(scripts|agents|references)/${esc_base}" 2>/dev/null \
            | grep -vE "^plugins/[^/]+/(scripts|agents|references)/${esc_base}\$" || true)"
```

- [ ] **Step 6: 확장 전후 도출 수 대조 + 이빨 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh > /tmp/copyof-after.txt 2>&1; echo "rc=$?"
diff <(grep -E 'symlink-∀' /tmp/copyof-before.txt | sed 's/[0-9]\+//g' | sort) \
     <(grep -E 'symlink-∀' /tmp/copyof-after.txt  | sed 's/[0-9]\+//g' | sort) | head -30
```

기존 정본의 도출은 **같아야** 하고, 새로 늘어난 것은 `reviewing-document.md` 한 건이어야 한다. 그다음 이빨을 잰다 — 새 링크를 사본으로 바꾸면 RED 여야 한다(AC14 의 마지막 문장):

```bash
cd /Users/jeonghokim/Downloads/devbrew
git stash push -- plugins/spec-distill/references/reviewing-document.md >/dev/null 2>&1 || true
rm -f plugins/spec-distill/references/reviewing-document.md
cp shared/docreview/references/reviewing-document.md plugins/spec-distill/references/reviewing-document.md
git add -f plugins/spec-distill/references/reviewing-document.md
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh > /tmp/copyof-mut.txt 2>&1; echo "mutation rc=$? (0 이 아니어야 한다)"
grep -E '✗' /tmp/copyof-mut.txt | head -5
# 복원 — 변이 전에 커밋해 두는 편이 안전하다(`git checkout --` 는 HEAD 로 되돌린다)
rm -f plugins/spec-distill/references/reviewing-document.md
ln -s ../../../shared/docreview/references/reviewing-document.md plugins/spec-distill/references/reviewing-document.md
git add plugins/spec-distill/references/reviewing-document.md
git ls-files -s -- plugins/spec-distill/references/reviewing-document.md   # 120000 으로 복원됐는지
```

변이가 rc 0 을 내면 **락에 이빨이 없는 것이고 그것이 이 스텝의 결과다** — 그대로 보고한다. 「통과했으니 됐다」로 넘어가지 않는다.

- [ ] **Step 7: 스윕 + 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in $(find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/' | sort); do
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$t" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗' || true)"
  printf '%s\trc=%s\tfail=%s\n' "$t" "$rc" "$n"
done > /tmp/sweep-t1.tsv
grep -v 'rc=0' /tmp/sweep-t1.tsv
```

선재 RED 둘(`test_no_write_matcher_hooks_repo.sh` · `harness/test_skill_orchestration_behavior.sh`) 말고 아무것도 나오면 안 되고, **그 둘의 실패 줄 수도 baseline 과 같아야** 한다.

```bash
git add plugins/spec-distill/agents/doc-critic.md plugins/spec-distill/agents/doc-recritic.md \
        plugins/spec-distill/references/reviewing-document.md shared/tests/test_copy_of_contract.sh
git commit -m "feat(docreview): design doc 자리 배포 — agent 사본 둘 · 절차서 링크 · 축 1a 를 세 디렉토리로"
```

---

### Task 2: `escalated` 예약의 누적 — 라운드 n−1 하드코딩을 없앤다

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`_auto_decides` 의 `escalated` 갈래)
- Modify: `shared/docreview/scripts/docreview_state.py` (`gate_summary` 의 `counts` 에 `escalated_unconsumed`)
- Modify: `shared/tests/fixtures/docreview/cases.sh` (`case_escalated_round_mismatch_carries_over` **재작성** + 새 케이스 둘)
- Modify: `shared/tests/test_docreview_mutations.sh` (셀 셋)

**Interfaces:**
- Produces: `gate_summary()["counts"]["escalated_unconsumed"]` — 대상 finding 이 사라져 소비하지 못한 `escalated` 예약 수. `render_gate` 의 계수 줄에 실린다.
- Consumes: 없음.

**배경 — 왜 지금인가.** `_auto_decides` 의 `escalated` 갈래는 `if int(e["round"]) != n - 1` 로 **정확히 직전 라운드의 예약만** 소비하고 나머지는 `keep_esc` 에 넣는다. `finalize` 가 `_auto_decides` 전에 조기 반환한 라운드가 하나라도 끼면 그 예약은 라운드 번호가 영원히 어긋나 **소비되지 않고 계수되지도 않는다.** 형제인 재상승 예약은 AC21 이 같은 결함을 이미 닫았다(누적 · `finding_id` dedup · 미소비 계수) — 두 예약이 같은 함수 안에서 다른 규칙을 쓰고 있다.

오늘은 이 누수가 조용하다(`escalated` 는 승인을 막지 않는다). **Task 3 이 그것을 바꾼다** — 표가 `escalated_fix` 를 차단 행으로 만들면, 좌초한 예약은 「후속 `decide` 로 올라갈 길이 없는데 승인은 영구히 막는」 상태가 된다. 그것이 정확히 AC23 이 `escalate` 경로를 고른 이유(「단순 거부면 그 `fix` 가 미적용으로 남아 영구히 승인을 막는다」)를 되살리는 모양이다. 그래서 이 태스크가 Task 3 **앞**이다.

**기존 락을 뒤집는다 — 이것은 판정이 필요한 변경이다.** `case_escalated_round_mismatch_carries_over` 의 둘째 단언은 지금 *"소비되지 않은 라운드 1 예약은 버려지지 않고 다음으로 이월된다"* 를 **의도된 동작으로 못 박고 있다.** 이 태스크는 그 단언을 뒤집는다(이월이 아니라 **소비**). 락을 지우지 말고 **뜻을 바꿔 다시 쓴다** — 케이스 이름도 `case_escalated_accumulates` 로 바꾸고, 무엇이 왜 뒤집혔는지 케이스 위 주석에 남긴다.

- [ ] **Step 1: 뒤집을 락을 먼저 실행해 현재 값을 기록한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_route.sh 2>&1 | grep -i 'escalated' 
```

두 단언이 GREEN 으로 보여야 한다. 그 문면을 report 에 그대로 붙인다 — 뒤집기 전의 사실이다.

- [ ] **Step 2: 케이스를 새 계약으로 다시 쓴다 (RED 를 먼저 만든다)**

`case_escalated_round_mismatch_carries_over` 를 `case_escalated_accumulates` 로 바꾸고 단언을 이렇게 한다. 시나리오(라운드 1 에 fid1 escalate → 라운드 2 는 finalize 없이 건너뜀 → 라운드 2 에 fid2 escalate → 라운드 3 에서 finalize)는 **그대로 둔다**:

```bash
  # n=3. 새 계약: 「직전 라운드」가 아니라 「이번 라운드보다 앞선」 예약을 전부 소비한다.
  # fid1(round=1)·fid2(round=2) 둘 다 이번 finalize 에서 decide 로 올라온다.
  assert_eq "$(jget "$d/fin.json" 'sorted(x["supersedes"] for x in d["findings"] if x.get("supersedes") in ("'"$fid1"'", "'"$fid2"'"))')" \
    "['$fid1', '$fid2']" "escalated 누적: 라운드가 어긋난 예약(라운드 1)도 버려지지 않고 이번 라운드에 소비된다"
  assert_eq "$(st_yaml "$d" 'st["escalated"]')" "[]" "escalated 누적: 소비 후 예약 목록이 빈다"
```

정렬은 id 문자열 순이므로 `fid1`·`fid2` 의 실제 값에 따라 순서가 바뀔 수 있다 — `sorted()` 를 쓴 쪽과 기대값을 같은 규칙으로 맞춘다.

- [ ] **Step 3: 새 케이스 둘을 더한다**

```bash
# dedup — 같은 finding 이 두 라운드에 걸쳐 escalate 되면 후속은 라운드당 하나다.
case_escalated_dedup() { … }
# 미소비 계수 — 대상 finding 이 없으면 버리지 않고 센다(AC21③ 과 같은 규칙).
case_escalated_unconsumed_counted() { … }
```

`case_AC21_reraise_dedup` · `case_AC21_unconsumed_counted` 를 **읽고 같은 모양으로** 쓴다. 특히 dedup 케이스는 재상승 쪽에서 한 번 `no_teeth` 로 판정됐던 자리다 — 같은 `finding_id` 가 자연스럽게 두 번 예약되는 경로가 실재하는지 먼저 확인하고, 없으면 그 사실을 report 에 적고 케이스를 만들지 않는다(도달 불가능한 케이스는 이빨이 없다).

- [ ] **Step 4: `_auto_decides` 의 `escalated` 갈래를 고친다**

```python
    prev = st["findings"]
    keep_esc = []
    esc_seen = set()
    esc_unconsumed = 0
    for e in st.get("escalated") or []:
        if int(e["round"]) >= n:
            keep_esc.append(e)      # 이번 라운드에 «생긴» 예약 — 아직 자기 차례가 아니다
            continue
        f0 = prev.get(e["finding_id"])
        if not f0:
            esc_unconsumed += 1     # 대상 finding 부재 — 버리지 않고 센다(공시는 게이트가)
            continue
        if e["finding_id"] in esc_seen:
            continue                # 한 계보에 라운드당 후속 하나
        esc_seen.add(e["finding_id"])
        extra.append({…})           # 오늘과 같은 항목
    st["escalated"] = keep_esc
```

`!= n - 1` 을 `>= n` 으로 바꾼 것이 핵심이다 — 「직전 라운드의 것만」이 「이번 라운드보다 앞선 것 전부」가 된다. 재상승 예약(`st["reraise"]`)이 라운드 필드를 아예 안 보는 것과 방향이 같고, `escalated` 는 라운드 필드를 갖고 있으므로 「아직 자기 차례가 아닌 것」만 구별해 남긴다.

- [ ] **Step 5: 미소비 계수를 게이트로 흘린다**

`_auto_decides` 의 반환을 `(extra, reraise_unconsumed, esc_unconsumed)` 로 늘리고, `cmd_finalize` → `_build_report` 가 `escalated_unconsumed` 를 리포트에 싣는다. `gate_summary` 의 `counts` 열거에 `"escalated_unconsumed"` 를 더하고, `render_gate` 의 계수 줄 끝에 `· 미소비 상향 예약 %d` 를 붙인다.

**호출자 전수를 먼저 확인한다** — `_auto_decides` 의 반환을 푸는 자리가 하나인지 `git grep -n '_auto_decides'` 로 세고, 그 수가 report 에 적힌다.

- [ ] **Step 6: 변이 셀 셋을 더한다**

`shared/tests/test_docreview_mutations.sh` 의 관례(`mut <del>/<add> <이름> <케이스> <치환기> '<sed 프로그램>'`)를 따른다. 각 셀은 **churn(삭제/추가 줄 수)을 손으로 도출해 선언**한다 — 측정값을 붙여넣지 않는다(반쯤 죽은 셀의 깨진 값을 정답으로 굳힌다).

1. `>= n` 을 `!= n - 1` 로 되돌리기 → `case_escalated_accumulates` 에서 `caught`
2. dedup(`esc_seen`) 지우기 → `case_escalated_dedup` 에서 `caught`
3. `esc_unconsumed += 1` 을 `continue` 로 바꾸기 → `case_escalated_unconsumed_counted` 에서 `caught`

셀을 더한 뒤 **매트릭스 전체**를 돌려 기존 셀의 판정이 하나도 안 바뀌었는지 본다 — 내 수정이 기존 락의 발동 조건을 없애는 것은 스위트 GREEN 유지라 diff 로 안 보인다.

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_mutations.sh > /tmp/mut-t2.txt 2>&1; echo "rc=$?"
grep -cE '^\s*✓' /tmp/mut-t2.txt; grep -E 'no_teeth|unmeasurable|instrument_broken' /tmp/mut-t2.txt || echo "(전부 caught)"
```

- [ ] **Step 7: 스윕 + 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in $(find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/' | sort); do
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$t" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗' || true)"
  printf '%s\trc=%s\tfail=%s\n' "$t" "$rc" "$n"
done | grep -v 'rc=0'
git add -A && git commit -m "fix(docreview): escalated 예약도 누적·dedup·계수 — 재상승 예약과 같은 규칙"
```

---

### Task 3: 상태 축의 정본 표 — 「막는 집합 ⊆ 그리는 집합」을 도출로 만든다

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`is_open` · `gate_summary` · `render_gate` · 새 `gate-rows` 서브커맨드)
- Create: `shared/tests/test_docreview_gate_visibility.sh`
- Modify: `shared/tests/fixtures/docreview/cases.sh` (행별 도달 픽스처)
- Modify: `shared/tests/test_docreview_mutations.sh` (새 셀)

**Interfaces:**
- Produces: `docreview_state.py gate-rows` — 표를 JSON 배열로 낸다. 항목: `{"name": str, "ledger": str, "open": bool, "blocks": bool, "render": str|null}`. 락이 이 출력으로 코퍼스를 **도출**한다.
- Produces: `gate_summary()` 의 반환에 새 키 `escalated_fix` · `held_decide` · `ask_open` · `superseded_expired` 가 는다. 기존 키(`open_decide`·`adopted`·`blocked_expired`·`unapplied_fix`·`held_fix`·`asks_open`·`blocking_ask_open`·`defers`·`dropped`·`extra_rounds`·`approval_ready`·`round_gate_needed`·`approval_gate_open`·`two_stage`·`next_round_mode`·`stagnation`·`degrade`·`advisory`·`counts`)는 **이름도 뜻도 안 바뀐다**.
- Consumes: 없음(엔진 안에서 닫힌다).

**배경 — 왜 세 결함을 각각 고치지 않는가.** 설계 §6.4 「공통 뿌리 — 상태 축의 열거」: `gate_summary` 의 차단 술어는 상태의 열거이고 `render_gate` 는 그 열거의 진부분집합만 그린다. 오늘 실제로 어긋난 자리는 **넷**이다 — `adopted`(막는데 안 그린다) · `held` decide(안 막고 안 그린다 — 설계 §8.2 는 승인 게이트에 「남은 `ask` 목록」으로 보이라고 한다) · `escalated` fix(안 막고 안 그린다 — 알려진 한계 (c)) · `blocks` 없는 일반 `ask`(안 그린다). 셋을 각각 patch 하면 넷째가 남고, 다음에 상태가 하나 늘면 다섯째가 생긴다.

- [ ] **Step 1: 실패하는 락을 먼저 쓴다 — 코퍼스를 표에서 도출한다**

`shared/tests/test_docreview_gate_visibility.sh` 를 새로 만든다. 이 락의 핵심은 검사 대상을 **열거하지 않고** `gate-rows` 출력에서 도출하는 것이다.

```bash
#!/usr/bin/env bash
# test_docreview_gate_visibility.sh — 「승인을 막는 상태는 반드시 게이트 본문에 보인다」
# guards: shared/docreview/scripts/docreview_state.py
#
# 코퍼스를 열거하지 않는다 — `gate-rows` 가 내는 표에서 차단 행을 **도출**하고, 각
# 행마다 그 상태 하나만 살아 있는 state 를 만들어 `gate --render` 본문에 그 finding id
# 가 나오는지 본다. 새 차단 상태가 표에 추가되면 이 락이 그 행의 픽스처를 요구하므로
# (아래 «행 ↔ 픽스처 집합 등식») 렌더를 빠뜨린 채 상태를 늘릴 수 없다.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
SCRIPTS="$REPO_ROOT/plugins/spec-distill/scripts"   # 형제 import(adjudication.py)가 잡히는 호스트 경로
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'shared/docreview/scripts/docreview_state.py'; exit 0
fi
. "$REPO_ROOT/shared/tests/fixtures/docreview/cases.sh"
```

그다음 도출과 등식:

```bash
ROWS_JSON="$(py docreview_state.py gate-rows)"
BLOCKING="$(printf '%s' "$ROWS_JSON" | jgets '" ".join(r["name"] for r in d if r["blocks"])')"
n_block="$(printf '%s\n' $BLOCKING | grep -c . || true)"
# vacuity 하한 — 도출이 0건이면 아래 루프가 아무것도 단언하지 않고 GREEN 이 된다.
[ "$n_block" -ge 4 ] \
  && ok "도출: 차단 행 ${n_block}건 (하한 4)" \
  || no "도출: 차단 행이 ${n_block}건이다 — 표 도출이 깨졌거나 차단 집합이 비었다. 아래 단언은 무의미하다"

# 행 ↔ 픽스처 집합 등식 — 픽스처 없는 차단 행이 조용히 빠지지 않는다.
HAVE="$(declare -F | sed -n 's/^declare -f gv_reach_//p' | sort | tr '\n' ' ')"
assert_eq "$(printf '%s\n' $BLOCKING | sort | tr '\n' ' ')" "$HAVE" \
  "등식: 표의 차단 행 집합 = 이 락이 도달 픽스처를 가진 행 집합"
```

`gv_reach_<행이름>` 은 「그 상태 하나만 살아 있는 state 디렉토리를 만들고 그 finding id 를 stdout 에 낸다」는 계약의 함수다. 행마다 하나씩 `cases.sh` 가 아니라 **이 락 안에** 둔다(다른 락의 코퍼스를 오염시키지 않는다). 루프:

```bash
for row in $BLOCKING; do
  d="$(mktemp -d -t gv-XXXXXX)"
  fid="$("gv_reach_$row" "$d")" || { no "도달: $row 픽스처가 실패했다"; rm -rf "$d"; continue; }
  out="$(py docreview_state.py gate --state-dir "$d" --render)"
  case "$out" in
    *"$fid"*) ok "가시: 차단 행 $row 의 항목 $fid 가 게이트 본문에 나온다" ;;
    *)        no "가시: 차단 행 $row 의 항목 $fid 가 게이트 본문에 없다 — 막는데 안 보인다(fail-open)" ;;
  esac
  # 짝이 되는 양의 단언 — 이 상태가 실제로 막고 있는가. 없으면 «안 막고 안 보이는»
  # 행을 픽스처가 잘못 만들어도 위 단언이 공허하게 통과한다.
  ar="$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')"
  assert_eq "$ar" "False" "차단: 행 $row 하나만 살아 있어도 approval_ready 는 False"
  rm -rf "$d"
done
finish
```

- [ ] **Step 2: 락이 RED 인지 확인한다 (`gate-rows` 가 아직 없다)**

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_gate_visibility.sh; echo "rc=$? (0 이 아니어야 한다)"
```

- [ ] **Step 3: 표를 심고 세 술어를 그것에서 도출한다**

`docreview_state.py` 의 `PUBLIC_FIELDS` 정의 **뒤**, `is_open` **앞**에 표를 둔다.

```python
GateRow = collections.namedtuple("GateRow", "name ledger pred open blocks render")

# ── 상태 축의 정본 ──────────────────────────────────────────────────────────
# 한 항목이 「열려 있는가(계보·stagnation) · 승인을 막는가 · 게이트에 보이는가」는
# 이 표 하나가 정한다. 설계 §6.4 「공통 뿌리 — 상태 축의 열거」: 같은 사실을 세 곳이
# 각자 열거하면 그 열거들이 어긋나고 어긋난 자리가 곧 fail-open 이다. 상태를 늘리는
# 사람은 이 표에 행을 더하고, 차단 행이면 렌더러 이름을 반드시 채운다 —
# test_docreview_gate_visibility.sh 가 표에서 코퍼스를 도출하므로 렌더러 없는 차단
# 행은 그 락에서 즉시 RED 다.
#
# `render` 가 None 인 행은 «보이지 않아도 되는» 행이다. 오늘 그런 행은 없다 —
# 비차단 행도 승인 게이트가 한 번은 보여준다(설계 §8.2). None 을 남겨 두는 것은
# 미래에 정말로 안 보여도 되는 상태가 생겼을 때의 자리다.
GATE_ROWS = (
    GateRow("open_decide", "decides", lambda r: r["state"] == "open", True, True, "decide"),
    GateRow("adopted", "decides", lambda r: r["state"] == "adopted", True, True, "adopted"),
    GateRow("blocked_expired", "decides",
            lambda r: r["state"] == "expired" and not r.get("superseded_by"), True, True, "expired"),
    GateRow("superseded_expired", "decides",
            lambda r: r["state"] == "expired" and bool(r.get("superseded_by")), True, False, "superseded"),
    GateRow("held_decide", "decides", lambda r: r["state"] == "held", False, False, "held_decide"),
    GateRow("unapplied_fix", "fixes",
            lambda r: r["state"] in ("pending", "intent_passed"), True, True, "unapplied_fix"),
    GateRow("escalated_fix", "fixes", lambda r: r["state"] == "escalated", True, True, "escalated_fix"),
    GateRow("held_fix", "fixes", lambda r: r["state"] == "held", True, False, "held_fix"),
    GateRow("blocking_ask_open", "asks",
            lambda r: not r.get("answered") and bool(r.get("blocks")), True, False, "blocking_ask"),
    GateRow("ask_open", "asks",
            lambda r: not r.get("answered") and not r.get("blocks") and not r.get("from_decide"),
            False, False, "ask_open"),
)


def gate_bucket(st, row) -> list:
    return sorted(i for i, r in st[row.ledger].items() if row.pred(r))
```

`import collections` 를 파일 머리 import 블록에 더한다.

`is_open` 을 표에서 도출하게 바꾼다 — **동작은 오늘과 같아야 한다**(이 스텝은 순수 리팩터다):

```python
def is_open(st, fid) -> bool:
    if fid not in st["findings"]:
        return False
    for row in GATE_ROWS:
        if not row.open:
            continue
        r = st[row.ledger].get(fid)
        if r is not None and row.pred(r):
            return True
    return False
```

`gate_summary` 의 버킷 열거를 루프로 바꾼다. **기존 키 이름을 그대로 쓴다** — 표의 `name` 이 곧 키다:

```python
    g = {"round": n, "rereview_count": rr, "cap_reached": rr >= REREVIEW_CAP}
    for row in GATE_ROWS:
        g[row.name] = gate_bucket(st, row)
    g["asks_open"] = sorted(i for i, x in asks.items() if not x.get("answered"))
    g["defers"] = sorted(i for i, f in st["findings"].items() if f.get("disposition") == "defer")
    g["dropped"] = sorted(i for i, f in fx.items() if f["state"] == "dropped")
    g["extra_rounds"] = st["extra_rounds"]
    …
    g["approval_ready"] = not any(g[row.name] for row in GATE_ROWS if row.blocks)
```

`dec` · `fx` · `asks` 지역 변수는 남는다(`asks_open` 등이 쓴다).

- [ ] **Step 4: `render_gate` 를 렌더러 등록표로 바꾼다**

행마다 그리는 모양이 다르므로 렌더러를 이름으로 등록하고 `render_gate` 는 표를 돈다. 등록되지 않은 이름을 가진 행은 **아무것도 그리지 않고** 그 사실이 Step 1 의 락에서 RED 로 나온다(예외를 던지지 않는다 — 트레이스백은 변이 판정을 `unmeasurable` 로 만들어 규칙 위반과 구별되지 않는다).

```python
def _rg_decide(st, g, fid):
    f = st["findings"][fid]
    dv = f.get("decision_view") or {}
    return ["[decide%s] %s — %s" % (" auto" if dv.get("auto") else "", fid, f.get("summary")),
            "  변경: %s" % dv.get("change", f.get("summary")),
            "  근거: %s" % dv.get("basis", f.get("evidence") or "—"),
            "  대안: %s" % " / ".join(dv.get("alternatives") or ["채택", "기각", "보류"]),
            "  영향: %s" % dv.get("impact", f.get("anchor"))]


def _rg_adopted(st, g, fid):
    return ["[채택·미관측] %s — %s (다음 라운드 diff 가 적용을 관측해야 닫힌다)"
            % (fid, st["findings"][fid].get("summary"))]


def _rg_expired(st, g, fid):
    d = st["decides"].get(fid) or {}
    tail = " — 「채택」은 원복 의무를 관측 없이 종결한다" if d.get("kind") == "post" else ""
    return ["[만료·차단] %s — %s (채택 / 기각%s)" % (fid, st["findings"][fid].get("summary"), tail)]


def _rg_superseded(st, g, fid):
    d = st["decides"].get(fid) or {}
    return ["[만료·승계됨] %s → %s" % (fid, d.get("superseded_by"))]


def _rg_held_decide(st, g, fid):
    return ["[decide 보류] %s — %s (승인 게이트에서 답하거나 기각한다)"
            % (fid, st["findings"][fid].get("summary"))]


def _rg_unapplied_fix(st, g, fid):
    return ["[미적용 fix] %s — %s (적용 예정 / drop)" % (fid, st["findings"][fid].get("summary"))]


def _rg_escalated_fix(st, g, fid):
    e = [x for x in (st.get("escalated") or []) if x["finding_id"] == fid]
    why = e[-1].get("reason") if e else "check-intent 거부"
    return ["[fix 상향 대기] %s — %s (사유: %s)" % (fid, st["findings"][fid].get("summary"), why)]


def _rg_held_fix(st, g, fid):
    return ["[fix 보류] %s — 전제 ask 미응답" % fid]


def _rg_blocking_ask(st, g, fid):
    f = st["findings"][fid]
    return ["[ask 비차단] %s — %s → 전제인 fix: %s"
            % (fid, f.get("summary"), ", ".join(f.get("blocks") or []))]


def _rg_ask_open(st, g, fid):
    return ["[ask] %s — %s" % (fid, st["findings"][fid].get("summary"))]


GATE_RENDERERS = {"decide": _rg_decide, "adopted": _rg_adopted, "expired": _rg_expired,
                  "superseded": _rg_superseded, "held_decide": _rg_held_decide,
                  "unapplied_fix": _rg_unapplied_fix, "escalated_fix": _rg_escalated_fix,
                  "held_fix": _rg_held_fix, "blocking_ask": _rg_blocking_ask, "ask_open": _rg_ask_open}
```

`render_gate` 의 몸통에서 첫 두 줄(degrade 공시 · 라운드 줄)과 마지막 계수·다음-단계 줄은 그대로 두고, 그 사이의 하드코딩된 목록 넷을 이 루프로 바꾼다:

```python
    for row in GATE_ROWS:
        fn = GATE_RENDERERS.get(row.render) if row.render else None
        if fn is None:
            continue
        for fid in g[row.name]:
            out.extend(fn(st, g, fid))
```

**주의 — 오늘 `unapplied_fix` 는 `approval_gate_open` 일 때만 그려진다.** 그 조건을 없앤다: 라운드 게이트에서도 미적용 `fix` 를 보여주는 것이 「막는 것은 보인다」와 정합하고, 설계 §8.2 는 승인 게이트에서 그 목록에 `drop` 선택지가 붙는다고 말할 뿐 라운드 게이트에서 **숨기라고** 하지 않는다. 이 변경으로 기존 케이스의 렌더 단언이 깨지면 그 케이스의 기대값을 갱신하고, 무엇이 왜 바뀌었는지 report 에 적는다.

- [ ] **Step 5: `gate-rows` 서브커맨드**

```python
def cmd_gate_rows(a) -> int:
    print(json.dumps([{"name": r.name, "ledger": r.ledger, "open": r.open,
                       "blocks": r.blocks, "render": r.render} for r in GATE_ROWS],
                     ensure_ascii=False))
    return 0
```

`build_parser()` 에 인자 없는 서브파서 `gate-rows` 를 더한다(다른 서브커맨드와 달리 `--state-dir` 를 받지 않는다 — 표는 상태와 무관하다).

- [ ] **Step 6: 락이 GREEN 인지, 그리고 이빨이 있는지**

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_gate_visibility.sh; echo "rc=$?"
```

이빨 — 표의 한 행에서 렌더러를 떼면 RED 여야 한다. **변이 전에 커밋해 둔다**(`git checkout --` 는 「내 마지막 변이」가 아니라 HEAD 로 되돌린다):

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add -A && git commit -q -m "wip: 변이 전 저장" 
python3 - <<'PY'
import pathlib
p = pathlib.Path("shared/docreview/scripts/docreview_state.py")
t = p.read_text(encoding="utf-8")
assert 'lambda r: r["state"] == "escalated", True, True, "escalated_fix"' in t
p.write_text(t.replace('lambda r: r["state"] == "escalated", True, True, "escalated_fix"',
                       'lambda r: r["state"] == "escalated", True, True, None'), encoding="utf-8")
PY
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_gate_visibility.sh > /tmp/gv-mut.txt 2>&1; echo "mutation rc=$? (0 이 아니어야 한다)"
grep -E '✗' /tmp/gv-mut.txt | head -3
git checkout -- shared/docreview/scripts/docreview_state.py
```

- [ ] **Step 7: 전체 스윕 + 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in $(find shared/tests plugins/*/tests -name 'test_*.sh' | grep -v '/spike/' | sort); do
  o="$(PYTHONDONTWRITEBYTECODE=1 bash "$t" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$o" | grep -cE '^[[:space:]]*✗' || true)"
  printf '%s\trc=%s\tfail=%s\n' "$t" "$rc" "$n"
done > /tmp/sweep-t2.tsv
grep -v 'rc=0' /tmp/sweep-t2.tsv
git add -A && git commit -m "fix(docreview): 상태 축의 정본 표 — is_open·gate_summary·render_gate 를 한 표에서 도출"
```

선재 RED 둘 밖에 아무것도 나오면 안 된다. `test_docreview_route.sh` · `test_docreview_mutations.sh` 의 렌더 단언이 새 줄 때문에 깨지면 그 기대값을 갱신하되, **무엇이 늘었는지** report 에 한 줄씩 적는다.

---
### Task 4: 알려진 한계 (a) — 재상승 후속의 「보류」 · 제안하는 선택지 = 받아주는 선택지

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`cmd_decide` 의 수용 술어 · 새 헬퍼 `decide_choices`)
- Modify: `shared/docreview/scripts/docreview_route.py` (`_decision_view` 의 `alternatives`)
- Modify: `shared/tests/fixtures/docreview/cases.sh`
- Modify: `shared/tests/test_docreview_mutations.sh`

**Interfaces:**
- Produces: `docreview_state.py` 의 모듈 함수 `decide_choices(st, fid) -> list` — 그 항목에 **실제로 받아들여지는** 선택지 목록. `cmd_decide` 의 거부 술어와 `_decision_view` 의 `alternatives` 가 **둘 다** 이 함수를 쓴다.
- Consumes: `st["decides"][*]["superseded_by"]`(Task 3 이전부터 있다).

**배경(설계 §6.4 알려진 한계 (a) · §8.2 「예외 — 재상승 후속의 「보류」」).** `cmd_decide` 의 보류 거부는 `expired` 만 겨눈다. 전방 포인터는 의무를 **후속으로 옮기므로**, 원본은 `superseded_by` 로 `blocked_expired` 를 벗어나고 후속은 평범한 `open` `decide` 다 — 그 후속에 「보류」가 통과하면 원본의 차단이 한 홉 건너에서 풀린다. 이 결함은 **이 재설계 자신이 만든 것**이다(AC20 의 전방 포인터 + AC21 의 예약 누적이 재상승을 항상 성공시키면서 노출이 넓어졌다).

Task 3 이 「보류된 decide 는 보인다」를 이미 고쳤으므로 승인 게이트에 흔적은 남는다. 이 태스크가 닫는 것은 **차단**이다 — 보이는 것과 막는 것은 다른 술어다.

- [ ] **Step 1: 실패하는 케이스를 먼저 쓴다**

`cases.sh` 에 `case_AC22b_reraise_successor_hold_refused` 를 더한다. `case_AC21_reraise_accumulates` 를 읽고 그 시나리오(라운드 1 채택 → 미적용 → `expired` → 다음 `finalize` 가 후속 생성)를 재사용해 후속 id 를 얻은 다음:

```bash
  local rc2
  py docreview_state.py decide --state-dir "$d" --id "$succ" --choice hold --quote '보류' >/dev/null 2>&1; rc2=$?
  assert_ne "$rc2" "0" "AC22b: 재상승 후속의 「보류」는 거부된다(원본의 차단을 한 홉 건너에서 풀지 못한다)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" \
    "AC22b: 보류 시도 뒤에도 승인은 열리지 않는다"
```

거부 사유 리터럴은 `decide_hold_not_allowed_for_reraise_successor` 다 — `expired` 쪽의 `decide_hold_not_allowed_for_expired` 와 **다른 문자열**이어야 한다. 「만료라서 못 한다」와 「승계 의무를 지고 있어서 못 한다」는 다른 사실이고, 사유가 같으면 사용자에게 틀린 이유가 간다.

`assert_ne` 가 `assert.sh` 에 없으면 `[ "$rc2" -ne 0 ] && ok … || no …` 형태로 쓴다 — **먼저 `shared/tests/assert.sh` 를 읽어 실재하는 헬퍼만 쓴다.**

- [ ] **Step 2: 수용 술어를 함수 하나로 모은다**

`docreview_state.py` 에:

```python
def _is_reraise_successor(st, fid) -> bool:
    """이 id 를 `superseded_by` 로 가리키는 만료 항목이 있는가 — 즉 승계된 의무를 지는가."""
    return any(d.get("superseded_by") == fid for d in st["decides"].values())


def decide_choices(st, fid) -> list:
    """이 항목에 «실제로 받아들여지는» 재결정 선택지. cmd_decide 의 거부 술어와
    _decision_view 의 alternatives 가 둘 다 이 함수를 쓴다 — 제안하는 선택지와
    받아주는 선택지가 갈라지면 사용자는 거부될 것을 고르게 된다(설계 §6.4 의
    「열거가 둘이면 어긋난다」가 상태 축이 아니라 선택지 축에서 재발한 것)."""
    d = st["decides"].get(fid) or {}
    if d.get("state") not in ("open", "expired"):
        return []
    if d.get("state") == "expired" or _is_reraise_successor(st, fid):
        return ["adopt", "reject"]          # 보류 없음 — 의무를 넘길 자리가 없다
    return ["adopt", "reject", "hold"]
```

`cmd_decide` 의 기존 거부 두 줄을 이 함수로 바꾼다:

```python
    allowed = decide_choices(st, a.id)
    if not allowed:
        return fail("decide_not_open", id=a.id, state=d["state"])
    if a.choice not in allowed:
        if d["state"] == "expired":
            return fail("decide_hold_not_allowed_for_expired", id=a.id)
        return fail("decide_hold_not_allowed_for_reraise_successor", id=a.id)
```

기존 사유 리터럴 `decide_not_open` · `decide_hold_not_allowed_for_expired` 를 **그대로 보존한다** — 기존 케이스가 그 문자열을 재고 있다. 바꾸면 그 락이 조용히 다른 것을 재게 된다.

- [ ] **Step 3: 제안하는 선택지를 같은 함수에서 낸다**

`docreview_route.py` 의 `_decision_view` 는 라우팅 시점(항목이 아직 원장에 없다)에 불리므로 `st` 를 볼 수 없는 자리가 있다. **호출부를 먼저 읽어 `st` 가 손에 있는지 확인한다.** 있으면:

```python
_CHOICE_LABEL = {"adopt": "채택(적용)", "reject": "기각(원복)", "hold": "보류"}

# _decision_view 안:
    choices = decide_choices(st, it["id"]) if st is not None and it.get("id") else ["adopt", "reject", "hold"]
    "alternatives": [_CHOICE_LABEL[c] for c in choices],
```

`st` 나 id 가 없는 호출 경로가 있으면 그 자리는 셋 전부를 내되, **재상승 후속은 그 경로로 오지 않는다**는 것을 확인하고 그 근거를 주석 한 줄로 남긴다. 확인할 수 없으면 `_decision_view` 를 고치지 말고 `render_gate` 의 `_rg_decide` 가 `decide_choices` 로 덮어쓰게 한다 — 사용자가 보는 마지막 자리가 거기다.

- [ ] **Step 4: 「제안 = 수용」 등식을 락으로 건다**

`cases.sh` 에 `case_choices_offered_equal_accepted` 를 더한다. 한 state 안에 세 부류(평범한 `open` · `expired` · 재상승 후속)를 모두 만들고, 각 항목에 대해 `gate --render` 가 보여주는 「대안:」 줄의 라벨 집합과 `decide_choices` 가 내는 집합이 같은지 본다. **라벨 문자열이 아니라 집합**을 비교한다.

- [ ] **Step 5: 변이 둘**

1. `_is_reraise_successor` 를 `return False` 로 → `case_AC22b_reraise_successor_hold_refused` 에서 `caught`
2. `_decision_view` 의 `alternatives` 를 상수 셋으로 되돌리기 → `case_choices_offered_equal_accepted` 에서 `caught`

- [ ] **Step 6: 스윕 + 커밋**

Task 2 Step 7 과 같은 스윕. 커밋 메시지: `fix(docreview): 재상승 후속의 보류 거부 — 제안하는 선택지와 받아주는 선택지를 한 함수에서`

---

### Task 5: 알려진 한계 (b) — 재상승 후속이 원본의 `kind` 를 물려받는다

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py` (`_auto_decides` 의 재상승 갈래)
- Modify: `shared/tests/fixtures/docreview/cases.sh`
- Modify: `shared/tests/test_docreview_mutations.sh`

**Interfaces:**
- Consumes: `st["decides"][*]["kind"]` · `["prev_hash"]`(둘 다 실재한다 — `cmd_decide` 의 `reject` 갈래가 `post` 원본에 `revert` permit 을 열 때 `prev_hash` 를 쓴다).
- Produces: 없음(내부 동작).

**배경(설계 §6.4 알려진 한계 (b)).** `_auto_decides` 의 재상승 갈래는 후속에 `"kind": "pre"` 를 하드코딩한다. 원본이 `post`(얼림 diff 가 만든 결정)였고 사용자가 「기각」해 `revert` permit(`expect_hash` = 기각 시점 스냅샷 해시)이 열렸는데 그 원복이 관측되지 않아 만료한 경우, 후속은 `pre` 로 태어난다 — 「채택」이 `expect_hash` 없는 `apply` permit 을 열고, `cmd_observe_diff` 는 「앵커가 하나라도 diff 에 닿았는가」만 보며 「해시가 기각 시점 스냅샷과 같은가」는 보지 않는다. **되돌리지 않은 얼림 위반이 그대로 승인된다.** `render_gate` 의 사후 고지 꼬리(`kind == "post"` 일 때만 붙는 문장)도 이 경로에서 사라진다.

- [ ] **Step 1: 실패하는 케이스를 먼저 쓴다**

`case_AC22c_reraise_inherits_post_kind`:
1. 라운드 1 에서 얼림 diff 로 사후 `decide`(`origin: auto`, `kind: post`, `prev_hash` 있음)를 만든다 — `case_*` 중 `frozen_change` 를 만드는 것을 찾아 그 절차를 재사용한다.
2. 「기각」 → `revert` permit 이 열린다.
3. 원복하지 않고 다음 라운드 → `expired` → 재상승 예약.
4. 그다음 `finalize` 가 후속을 만든다.
5. 단언 셋:
   - 후속의 `kind` 가 `"post"` 다.
   - 후속의 `prev_hash` 가 원본의 `prev_hash` 와 같다.
   - 후속에 「채택」하면 `state` 가 즉시 `applied` 다(사후 채택의 계약) — `pre` 였다면 `adopted` + `apply` permit 이었을 자리다.
   - `gate --render` 본문에 사후 고지 꼬리(`「채택」은 원복 의무를 관측 없이 종결한다`)가 나온다.

- [ ] **Step 2: 승계를 심는다**

`_auto_decides` 의 재상승 `extra.append({…})` 에서:

```python
        # 후속은 원본의 «성격»을 물려받는다. `pre`(아직 안 한 편집)와 `post`(이미
        # 일어난 변경의 원복 의무)는 permit 의 종류가 다르고, `post` 만 해시 대조를
        # 한다 — 하드코딩하면 원복 의무가 「앵커가 닿기만 하면 통과」로 강등된다
        # (설계 §6.4 알려진 한계 (b)).
        "kind": d0.get("kind") or "pre",
        "prev_hash": d0.get("prev_hash"),
```

`prev_hash` 를 항목에 실을 때, `record_findings` 의 `PUBLIC_FIELDS` 필터를 지나는지 **먼저 확인한다** — `kind` 는 목록에 있고 `prev_hash` 는 **없다.** 사후 원본은 `_auto_decides` 의 diff 갈래에서도 `prev_hash` 를 싣고 있으므로, 그 값이 오늘 `decides` 레코드까지 어떻게 도달하는지 그 경로를 읽고 같은 경로를 쓴다. 경로가 `PUBLIC_FIELDS` 를 지나지 않는다면 **`PUBLIC_FIELDS` 를 늘리지 말고** 그 경로를 그대로 쓴다(공개 필드 필터는 다른 계약이다).

- [ ] **Step 3: 변이 둘**

1. `d0.get("kind") or "pre"` 를 `"pre"` 로 되돌리기 → `case_AC22c_reraise_inherits_post_kind` 에서 `caught`
2. `prev_hash` 승계 지우기 → 같은 케이스의 해시 단언에서 `caught`

두 변이가 **같은 케이스에서** 잡히면 서로를 가릴 수 있다(하나를 되돌려도 다른 단언이 여전히 RED). 각 변이가 **어느 단언**을 RED 로 만드는지 셀 주석에 적고, 가능하면 케이스를 둘로 쪼갠다.

- [ ] **Step 4: 스윕 + 커밋**

커밋 메시지: `fix(docreview): 재상승 후속이 원본의 kind·prev_hash 를 물려받는다 — 원복 의무의 강등을 막는다`

---
### Task 6: `reviewing-spec` 껍데기화 + 상한 락 재작성 + 인접 락 둘

**Files:**
- Rewrite: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`
- Rewrite: `plugins/spec-distill/tests/test_rereview_cap_consistency.sh`
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh` (S2 재조준)
- Delete: `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh` (고아 — 피검자가 사라진다)
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` (판단 필요 — 아래 Step 6)

**Interfaces:**
- Consumes: Stop 훅 mandate 의 세 슬롯 — `spec path: <절대경로>` · `mode: design|spec` · 수명 문장. 훅은 **무변경**이므로 이 셋이 계약의 전부다.
- Produces: `arm_ledger.py` 의 원장 갱신(아래 네 호출) — 이 CLI 의 호출부는 리포 전체에서 이 파일 하나뿐이다.

**이 껍데기가 반드시 갖는 것 (락이 직접 재는 리터럴 — 하나라도 빠지면 그 락이 RED 이거나 조용히 vacuous)**

| # | 리터럴 / 요소 | 재는 락 |
|---|---|---|
| 1 | frontmatter `name: reviewing-spec` · 디렉토리명 유지 | `hooks/review-dispatch.py:80` 의 `REVIEW_SKILL` 상수(훅 불변) |
| 2 | `${CLAUDE_PLUGIN_ROOT:-…}` 최소 1건 | `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh:73` — **양성 대조**라 하한 통과와 별개로 RED |
| 3 | `턴 종료` 또는 `다음 턴` ≥1줄 | `test_proceed_gate_adopters.sh` 가드 2(AC19) |
| 4 | `polite stop` ≥1줄(대소문자 무시) | 같은 락 가드 1(AP2) |
| 5 | `degrade 채널` ≥1줄 — **문면은 새로 쓴다**(현재는 `merge_review` 플래그를 채널로 지목한다. 엔진의 채널은 `fin.json` 의 `advisory[]`·`blocks` 와 게이트 첫 줄) | 같은 락 Step B 의무 |
| 6 | `재결정` 또는 `반증` ≥1줄 | 같은 락 P23 |
| 7 | `arm_ledger.py` CLI 네 호출 — `mark-reviewed` ×1 · `clear-inflight` ×2 · `check-born` ×1 | `armed_paths`·`inflight_paths`·`dispatch_attempts` 를 지우는 **유일한 손**. 없으면 arm-once 게이트가 통째로 죽고 G6 상한 3 이 자동 dispatch 를 영구 중단시킨다 |
| 8 | `$harness_sid` 빈 값 advisory 세 자리 | 형제 자리들이 그 문구를 요구한다 — 한 자리만 침묵하면 그 비대칭이 다음 복사본으로 옮겨간다 |
| 9 | READ 와 **모든** WRITE 가 같은 `$STATE` 를 가리킴(read==write 디렉토리 불변식) | `test_reviewing_spec_state_keying.sh` |
| 10 | `codex-gate:begin runner=run_docreview_codex_reviewer.sh` … `codex-gate:end` 마커 쌍 | `plugins/quality-gates/tests/test_codex_gate_observation.sh` — 마커 수 하한 3, 오늘 4곳. 옛 마커를 지우고 새 것을 안 넣으면 정확히 하한이라 **다음 PR 에서 RED** |
| 11 | `Agent()` dispatch 블록 둘(critic · recritic)에 각각 처분 한 줄, `consumer=plugins/spec-distill/scripts/docreview_route.py` | `shared/tests/test_dispatch_disposition.sh` 축 A⑤ — `consumer=` 경로가 앵커와 같은 플러그인이어야 한다 |
| 12 | `doc-recritic` dispatch 프롬프트의 슬롯이 **정확히 셋**(문서 · 출처 라벨 없는 finding 목록 · 프로필). dispatch 사유 · 이전 대화 · 출처 라벨 슬롯 없음 | AC9 · §13 항목 3 |

**`mode` → 프로필 이름 매핑.** 훅이 내는 `mode:` 값역은 `design`·`spec` 이고 프로필 파일 이름은 `design-doc.md` 다 — **이름이 다르다.** 껍데기가 이 매핑을 한 곳에 둔다: `design`·`spec` 둘 다 `references/docreview-profiles/design-doc.md` 로 간다(이 skill 은 v0.12.0 부터 design 전용이고, `spec` 값이 와도 같은 프로필이다). 매핑을 두 곳에 쓰지 않는다.

- [ ] **Step 1: 껍데기를 쓴다**

`plugins/spec-distill/skills/reviewing-spec/SKILL.md` 를 아래 골격으로 **통째로 교체**한다. 분량은 297줄 → 대략 70~100줄이다.

절 구성:
1. `## 입력` — mandate 의 세 슬롯을 받는다. `spec_path` · `mode` · 수명. `$harness_sid`/`$ROOT`/`$STATE` 를 `state_path.py` 로 도출하는 bash 블록(현행 Step 1 의 그 블록을 **그대로** 가져온다 — 훅과 같은 리졸버를 쓰는 것이 read==write 불변식의 근거다).
2. `## 프로필` — `PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/design-doc.md"` 한 줄과 위 매핑 문장.
3. `## 절차` — `Read ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/reviewing-document.md` 를 읽고 그 여덟 단계를 한 턴 안에서 돈다는 한 문단. **절차를 여기 복사하지 않는다** — 그것이 공유되는 이유다(§5.1).
4. `## dispatch 블록 둘` — `doc-critic`(3단계) · `doc-recritic`(6단계)의 `Agent()` 호출. 각각 위 표 #11 의 처분 한 줄. recritic 은 슬롯 셋만.
5. `## 원장` — `arm_ledger.py` 네 호출과 그 시점. **`mark-reviewed` 는 승인 게이트 2단계에서 사용자가 진행(①/②)을 고른 뒤다**(설계 §5.4 표 — 현행의 「verdict 파싱 직후」에서 옮긴다). `clear-inflight` 는 두 종료 자리(문서 부재 · ④ 멈춤). `check-born` 은 진행 직전 미커밋 advisory.
6. `## 게이트` — `references/proceed-gate.md` 를 정본으로 가리키고, 위 표 #3~#6 의 네 앵커를 이 skill 어휘로 담은 문단.
7. `## degrade 채널` — 엔진의 채널을 이름으로 댄다: `fin.json` 의 `advisory[]` · `blocks` · `docreview_state.py gate --render` 첫 줄.

**쓰지 말아야 할 것**: `review lock`·`suppress_state`·`락이 훅에` 계열 표현(`test_stale_terms.sh` V9 가 production 파일에서 이 리터럴들을 금지한다 — 과거 메커니즘을 설명하는 산문을 새로 쓰다가 되살리기 쉽다).

- [ ] **Step 2: 상한 락을 재작성한다**

`test_rereview_cap_consistency.sh` 를 다시 쓴다. **정본은 `shared/docreview/references/reviewing-document.md` 의 `` `rereview_cap: N` `` 한 줄이다.**

```bash
REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
CAP="$(grep -oE '`rereview_cap: [0-9]+`' "$REF" | grep -oE '[0-9]+' | head -1)"
if [ -z "${CAP:-}" ]; then
  echo "✗ FATAL: 정본 패턴을 $REF 에서 찾지 못했다 — 기대: \`rereview_cap: N\`"; exit 1
fi
```

검사 대상(이 PR 범위 = design doc 자리 + 두 README):

1. `shared/docreview/scripts/docreview_state.py` 의 `REREVIEW_CAP = $CAP` — **엔진 상수가 산문 정본과 같은가.** 오늘 이 둘은 완전히 분리돼 있고 어떤 락도 대조하지 않는다(조사 실측). 「이 값의 정본은 이 한 줄이다」라는 절차서의 자기 주장이 실행 차원에서도 참이 되려면 이 단언이 있어야 한다.
2. `plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의 상한 언급이 `$CAP` 와 같다.
3. `plugins/spec-distill/README.md` 의 상한 언급이 `$CAP` 와 같다.
4. **음의 짝** — 위 셋 어디에도 옛 값 `5` 가 상한 문맥으로 남아 있지 않다. 부재 락만 두면 통째로 삭제해도 통과하므로 1~3 의 양의 단언과 짝이다.

이후 PR(3·4·5)이 `reviewing-brief`·`critiquing-artifacts`·`framing-requests` 를 코퍼스에 더한다 — 그 자리를 **주석으로 명시**해 다음 저자가 어디에 줄을 더할지 알게 한다.

- [ ] **Step 3: 상한 락의 이빨을 잰다**

AC13 이 지정한 변이다. **변이 전에 커밋한다.**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add -A && git commit -q -m "wip: 변이 전 저장"
sed -i '' 's/`rereview_cap: 2`/`rereview_cap: 3`/' shared/docreview/references/reviewing-document.md
PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh; echo "mutation rc=$? (0 이 아니어야 한다)"
git checkout -- shared/docreview/references/reviewing-document.md
```

이 변이가 GREEN 이면 락이 정본을 **읽지 않고** 하드코딩한 2 를 비교하고 있다는 뜻이다 — 모양만 있고 이빨이 없다.

두 번째 변이(구분력 확인) — 정본 줄의 **산문**만 바꾸고 `rereview_cap: 2` 토큰은 그대로 두면 **GREEN 이어야** 한다. RED 면 앵커가 문장 전체를 매칭하고 있다는 신호다.

- [ ] **Step 4: `test_reviewing_spec_state_keying.sh` S2 를 재조준한다**

S2 는 지금 SKILL.md 안의 리터럴 `'continuity read collapse 금지'` 를 찾는다. 그 문구가 지키던 것은 `rereview_count`/`issue_history` continuity 카운터를 harness-sid 로 collapse 하지 말라는 것이고, **엔진 전환으로 그 카운터가 엔진 state 로 이관돼 그 위험 자체가 사라진다.**

S2 를 **지우지 말고** 새 불변식으로 바꾼다: 껍데기의 READ 와 세 WRITE 가 같은 `$STATE` 를 가리키는지(read==write 디렉토리 불변식). 그것이 이 락 파일의 본래 주제(state keying)이고, 없어진 위험 대신 남아 있는 위험을 잰다. 케이스 이름과 실패 문면도 새 사실에 맞게 고친다 — **삭제된 규칙이 거짓 인용을 남기지 않게** 한다.

- [ ] **Step 5: `test_reviewing_spec_design_routing.sh` 를 지운다**

이 락은 SKILL.md 의 옛 라우팅 표 문자열(`count >?= ?5`)만 잰다. 그 표가 사라지므로 피검자가 없다. 라우팅의 새 정본은 `docreview_route.py` 픽스처(AC3)이고 이미 락이 있다.

- [ ] **Step 6: `test_reviewing_spec_design_only.sh` 는 읽고 판단한다**

이 락이 무엇을 재는지(디자인 모드 전용 · 11-section schema 미적용 등) 먼저 읽는다. 새 껍데기에서도 참인 불변식이면 앵커만 재조준하고, 옛 verdict 어휘에 매달려 있으면 고아로 판정해 지운다. **어느 쪽이든 report 에 근거를 적는다** — 「그냥 GREEN 이라 뒀다」는 근거가 아니다.

- [ ] **Step 7: 스윕 + 커밋**

이 태스크는 삭제(Task 7) 전이므로 옛 파일들이 아직 있고, 그것들을 재던 락 일부가 RED 가 된다. **그 RED 목록을 report 에 정확히 적고** Task 7 이 그것을 0 으로 만드는지 대조한다. 커밋 메시지: `feat(docreview)!: reviewing-spec 을 엔진 껍데기로 — 상한 락 재작성(정본 = reviewing-document.md)`

---
### Task 6b: 엔진 러너의 PyYAML 의존 제거 · 배선 락의 심볼릭 링크 맹점

T6 실행 중에 드러난 두 결함이다. 둘 다 **T6 이 만든 것이 아니라 첫 호출자가 붙으면서 드러난 것**이고, 둘 다 지금 락을 RED 로 두고 있다.

**Files:**
- Modify: `shared/docreview/scripts/run_docreview_codex_reviewer.sh` (인라인 프롬프트 빌더)
- Modify: `tools/adjudication/check_wiring.py` (IMPORT 도출의 링크 skip)
- Modify: 필요하면 `tools/adjudication/` 의 등록부 한 곳(Ruling 9 의 최소 조치)

- [ ] **Step 1: PyYAML 의존을 실측으로 재현한다**

구현자가 이미 격리했다 — 추출한 codex 게이트 펜스를 `HOME` 만 바꿔 두 번 돌리면 갈린다. 그 재현을 **먼저 자기 손으로** 한 뒤 고친다. 재현되지 않으면 멈추고 보고한다(고칠 대상이 다르다는 뜻이다).

- [ ] **Step 2: 빌더를 stdlib 전용으로**

빌더가 프론트매터에서 읽는 것은 셋뿐이다 — `layer_rubric`(중첩: `layer1`·`layer2` 리스트) · `allowed_dispositions`(리스트) · `web`(불리언). 형제 러너 셋의 빌더가 stdlib 로 같은 일을 어떻게 하는지 **먼저 읽고** 같은 모양으로 쓴다. 새 파서를 발명하지 않는다.

파싱이 실패했을 때의 동작은 **오늘과 같아야 한다** — `emit_fallback prompt_build_failed`. 새 실패 모드를 만들지 않는다.

- [ ] **Step 3: (철회됨) `docreview_state.py` 의 yaml 가드 — 그런 결함은 없다**

이 스텝은 원래 *"`docreview_state.py:21-24` 가 `import yaml` 을 try 로 감싸 `yaml = None` 을 두는데
`:87`·`:184`·`:198` 은 `yaml.safe_load`/`safe_dump` 를 가드 없이 부르므로 PyYAML 부재 시
AttributeError 로 죽는다"* 를 조사하라고 했다. **그 주장은 틀렸다.** 세 자리 전부 자기 함수의
머리에 가드가 있다 — `load_profile:81-82`(`raise ProfileError("pyyaml_missing")`) ·
`load_state:176-177`(`raise RuntimeError("pyyaml_missing")`) · `save_state` 도 같은 모양. PyYAML 이
없으면 AttributeError 가 아니라 `{"ok": false, "reason": "pyyaml_missing"}` 이 깨끗하게 나온다.

계획 저자가 import 문과 사용 지점만 보고 그 사이의 함수 머리를 읽지 않아 생긴 오독이다.
이 스텝에서 할 일은 없다. **기록을 남기는 이유**는 이 문단이 지워지면 같은 오독이 다음 사람에게
「알려진 결함」으로 다시 인용되기 때문이다.

- [ ] **Step 4: `check_wiring.py` 의 링크 skip 을 뺀다 — 확장 전 도출 수를 먼저 잰다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_adjudication_wiring.sh > /tmp/wiring-before.txt 2>&1; echo "rc=$?"
grep -E 'IMPORT|ANCHOR|unwired|도출' /tmp/wiring-before.txt | head -20
```

그다음 `:551` 의 `if f.is_symlink() or not f.is_file(): continue` 에서 링크 조건만 뺀다. **`not f.is_file()` 은 남긴다** — 끊어진 링크를 읽으려 들면 죽는다(파이썬의 `is_file()` 은 링크를 따라가므로 살아 있는 링크는 통과하고 끊어진 링크만 걸린다).

같은 파일 안에 링크를 건너뛰는 **다른 자리**가 있는지 `git grep -n 'is_symlink' -- tools/` 로 전수한다 — 한 자리만 고치면 같은 결함이 이름만 바꿔 남는다(PR 1b 가 `extract_codex_invocations.py` 에서 같은 것을 고쳤다).

- [ ] **Step 5: 확장 전후 대조 + Ruling 9 의 최소 조치**

도출 수가 어떻게 변했는지 적는다. `docreview_route.py` 가 이 락의 모집단에 처음 들어오면서 나온 값(`unwired=9`, 이해도 baseline 39→57)을 **triage 한다** — 각 항목이 진짜 미배선인지, 아니면 링크 배포 때문에 잘못 잡힌 것인지.

`merge_review.py` 가 IMPORT-without-ANCHOR 가 된 건에 대해: **락이 그 방향을 실제로 실패로 보는지 먼저 확인**한다. 보지 않으면 아무 조치도 하지 않는다. 본다면 두 후보(브리프 리뷰 자리의 앵커 · `TERMINAL_CONSUMERS` 항목) 중 하나를 고르고 **근거를 리포트에 적는다**.

- [ ] **Step 6: 이빨 — 고친 것이 실제로 무엇을 더 잡는가**

링크 skip 제거가 진짜인지: 엔진 스크립트 하나를 `consumer=` 로 지목한 앵커를 임시로 만들고 락이 그것을 IMPORT 에서 찾는지 본다. 제거 전이라면 못 찾아 RED 였을 자리다. **변이 전에 커밋한다.**

- [ ] **Step 7: 스윕 + 커밋**

`test_adjudication_wiring.sh` · `test_adjudication_consumed.sh` · `test_codex_gate_observation.sh` · `test_codex_backward_compat.sh` 넷이 0 이 되어야 한다. 남는 RED 는 T7 이 닫는 넷(`test_agent_input_slots` · `test_dispatch_disposition` · `test_reviewing_spec_codex_merge` · `test_arm_ledger_timing`)과 선재 둘뿐이다.

---

## Park — 이 PR 이 닫지 않고 이름 붙여 안고 가는 것

### P1 — `layer_rubric` 안의 셋째 키를 통한 재귀 미끼 (확인된 익스플로잇, 조용함)

`docreview_state.py` 의 `load_profile()` 은 **최상위 키만** 여분 키 검사를 하고 `layer_rubric` 자신의
키는 열거하지 않는다(`.get("layer1")`·`.get("layer2")` 만 본다). 그래서 아래가 게이트를 **통과**한다:

```yaml
layer_rubric:
  layer1: [goal_fit, …]
  layer2: [placeholder, …]
  foo: |
    layer1: [decoy_recursive_layer1]
    layer2: [decoy_recursive_layer2]
```

러너의 `_block_span("layer_rubric", …)` 은 블록으로 옳게 좁히지만 `_flow_list` 가 **그 블록 «안에서»
다시 무제한 last-match** 를 하므로, 더 깊이 들여쓴 `foo` 의 블록 스칼라 안 미끼가 이긴다. 결과는
`Layer 1 … categories: decoy_recursive_layer1`, rc=0, 가드 미발동 — **조용한 오독**이다.

**닫지 않는 이유(판정).** 정지 조건을 미리 선언했다는 것만이 이유가 아니다. ① 도달 경로가
**저자 실수 한 갈래뿐**이다 — 프로필은 리포 내부 데이터이고 신뢰 경계를 넘어오지 않는다.
② 폭발 반경이 **codex 자문 채널 하나**다 — codex 는 설계상 fail-open 공시 대상이고(§9·D7) Claude
critic 경로와 라우팅은 이 파서를 지나지 않는다. ③ 옳은 고침은 러너의 세 번째 패치가 아니라
**게이트에서 `layer_rubric` 의 허용 키를 `{layer1, layer2}` 로 닫는 것**이다 — 그리고 오늘 그것이
무엇을 깨뜨리는지는 **실측했다: 아무것도 깨뜨리지 않는다.** 리포의 프로필 넷(`design-doc` ·
`brief` · `seed` · `generic`)이 전부 `layer1`·`layer2` 둘만 갖는다. 그러므로 미루는 근거는
**비용이 아니다** — ①②(도달 경로 한 갈래 · 폭발 반경 하나)와 미리 선언한 정지 조건이 전부이고,
이 PR 의 범위를 지키려고 미루는 것이지 나중에 하는 편이 싸서가 아니다.

**PR 3 착수 시 첫 항목으로 올린다.** 되돌리는 말: 「지금 닫아」 — `load_profile` 한 줄 + 락 하나다
(그 되돌림이 실제로 그만큼 싸다는 것은 위 ③ 의 실측이 뒷받침한다).

### P2 — spike 테스트가 추적되는 골든 픽스처를 자기 실행으로 덮어쓴다

`plugins/quality-gates/tests/spike/test_codex_json_extraction.sh` 는 실제 codex 를 호출하고 그 출력으로
`spike/fixtures/codex_jsonl_sample.json` 을 **덮어쓴다.** 이 PR 의 리뷰어가 그것을 돌렸다가
`test_artifact_codex_reviewer.sh` · `test_findings_parser.sh` 두 개를 일시적으로 깨뜨렸고
`git checkout --` 로 복원했다. 스윕이 `/spike/` 를 제외하는 이유가 이것인데, **그 사실이 그 파일
자신에는 적혀 있지 않다.** 이 PR 범위 밖이라 고치지 않는다.

### P3 — T-AC7: 「추가 라운드 1회 열기」를 스펙 두 조항이 서로 부정한다

AC7 은 상한 도달 시 승인 게이트의 **선택지에 「추가 라운드 1회 열기」가 있어야 한다**고 요구한다.
그런데 §8.2 는 승인 게이트의 선택지를 `proceed-gate.md` 의 **네 옵션 그대로**라고 못 박고, 그 파일을
바꾸는 것은 §3 의 **Non-goal** 이며, `proceed-gate.md` Step B 는 실제로 넷을 고정한다
(①`/compact`+다음 ②바로 다음 ③수정 필요 ④멈춤). 다섯째 옵션을 넣으면 §8.2·§3 을 어기고, 안 넣으면
AC7 을 어긴다 — **둘 다 만족시키는 구현이 없다.**

Task 9 의 e2e 가 실측한 것은 여기까지다: `--extra-approval` 의 **호출자가 리포 전체에 0** 이고
(등장은 절차서 지시문 · 엔진 argparse · 락 픽스처 · plan 문서뿐), `render_gate` 의 마지막 줄 셋 중
어디에도 그 문자열이 없으며, 상한 없이 라운드 4 를 열려는 `begin-round` 는 rc 3 `cap_reached` 로
막힌다(음·양 짝으로 재현). 즉 **집행은 fail-closed 로 옳게 작동하고, 없는 것은 사용자에게 그
선택지를 «제안하는» 자리뿐**이다.

**닫지 않는 이유(판정).** 고칠 대상이 ⓐ 다섯째 옵션을 만드는 것인지 ⓑ AC7 문면을 고치는 것인지
ⓒ 옵션 ③ 의 분기 하나로 흡수하는 것인지는 **구현 판단이 아니라 설계 결정**이다. 셋은 `proceed-gate.md`
의 계약 범위·§3 Non-goal·AC7 을 각각 다르게 바꾼다. 지금 한쪽으로 고치면 사용자 동의 없이 확정을
뒤집는 것이다(P23).

**PR 3 의 사용자 결정으로 이월한다.** 되돌리는 말: 「AC7 이 맞고 §8.2 가 틀렸다 — 다섯째 옵션을
넣어라」 또는 그 반대. 어느 쪽이든 **사용자가 말해야** 움직인다.

### P4 — 라운드 게이트의 크기: 개별 응답 14건 대 「`AskUserQuestion` 하나」

Task 9 가 이 엔진의 **첫 실제 라운드**를 태웠을 때 게이트가 요구한 개별 응답은 **14건**이었다 —
`decide` 13(각각 채택/기각/보류) + 차단 `ask` 1. 계약은 그것을 하나로 띄우라고 한다 —
`shared/docreview/references/reviewing-document.md` 의 **8단계(게이트)** 「라운드 게이트(`decide` 묶음 +
차단 `ask`)를 `AskUserQuestion` 하나로」와 `plugins/spec-distill/skills/reviewing-spec/SKILL.md` 의
**`## 게이트`** 절에 있는 같은 문장 둘. (줄 번호로 인용하지 않는다 — 이 커밋이 절차서에 두 줄을
더하면서 그 자리가 이미 한 번 밀렸다.)
수치의 출처는 그 라운드의 `fin.json`(`by_disposition` = decide 13 · ask 1 · fix 10, findings 24)이고
렌더 80줄의 라벨 계수도 같은 수를 낸다.

**축을 구별한다.** 설계의 미해결 항목 `D6`(추적본 `:876` — 「라운드 게이트 질문 텍스트의 렌더 형식
(결정 묶음 하나가 **몇 줄**인가)」)은 **묶음 하나의 분량**을 묻는다. Task 9 가 잰 것은 **묶음이 몇
개인가**다. 인접하지만 같은 축이 아니다 — D6 을 닫는 사람이 개수 축까지 함께 정하지 않으면 이
긴장은 그대로 남는다.

**닫지 않는 이유(판정).** 해법을 고르지 않는다. 도구가 한 호출에 몇 개를 담을 수 있는지는 Task 9 가
**측정하지 않았고**(그 라운드는 `AskUserQuestion` 이 없는 헤드리스 세션이라 게이트가 실제로 띄워진
적이 없다 — 잰 것은 「띄워야 할 내용의 크기」다), 측정하지 않은 상한을 근거로 계약을 고치는 것은
이 리포가 반복해서 데인 형태다.

**PR 3 이 D6 을 닫을 때 개수 축과 함께 정한다.** 되돌리는 말: 「하나로 못 담는다는 것을 실측했다」
— 대화형 세션에서 한 라운드를 띄워 보면 된다.


**〔2026-09-10 — 둘째 표본 + 딱딱한 상한〕**

| 문서 | 줄 수 | decide | 미적용 fix | 게이트 항목 합 |
|---|---|---|---|---|
| `2026-09-06-document-review-redesign-design.md` (T9) | 901 | 13 + 차단 ask 1 | — | **14** |
| `2026-09-06-interview-depth-redesign-design.md` (오늘) | 776 | **7**(auto 1 포함) | 8 | **15** |

수는 문서에 따라 갈리지만(13 → 7) **게이트의 «크기»는 갈리지 않는다** — 두 번 다 열다섯 안팎이다.

**그리고 D6 은 이제 열린 취향 문제가 아니라 상한이 정해진 제약 만족 문제다.** 계약은
「`AskUserQuestion` **하나**로」인데 **그 도구는 한 호출에 질문 최대 4개, 질문당 선택지
2~4개**다(도구 스키마의 `maxItems`). 그러므로 **decide 가 5건 이상이면 「결정 하나에 질문
하나」가 원리적으로 불가능하다** — 묶거나 나누는 것 말고 길이 없고, 어느 쪽을 어떻게 하느냐가
D6 이 답해야 할 것 전부다. 오늘 실행에서 7건을 4개 이하로 묶은 것은 그 상한 때문이며
설계 결정이 아니다.

### P5 — kill switch 성질의 «경계» (보안, PR 3 첫 항목)

`reviewing-spec` 의 codex 게이트 펜스에서 「codex 를 끈 라운드에 codex 내용이 판정에
닿지 않는다」는 성질은 **평범한 skip 네 경로(kill switch·미설치·감지기 부재·입력 부재)에
대해 집행된다.** 증거는 주장이 아니라 측정이다 — 제거를 분기 안으로 되돌리는 변이를 걸고
192 파일 전수 스윕을 돌리면 **새 RED 가 정확히 하나**, `tests/test_reviewing_spec_residue.sh`
뿐이다(리포 전체의 유일한 탐지기).

집행 **밖**에 남은 것 넷:

1. **디렉토리·파일이 «둘 다» 쓰기 불가**한 권한 조합(재리뷰에서 `P3` 로 불린 것 — 위 `### P3`(T-AC7)와는 무관하다). 3단 중화의 마지막 단은 stderr 한 줄과
   곧 종료할 셸의 변수 하나를 비울 뿐이라 읽을 수 있는 잔존이 남고, 하류 판정이 수정 전과
   동일하다(`codex_absent=False`). **집행 지점이 한국어 문장**이다 — 「산문 조건은 집행이
   아니다」라고 적은 펜스 자신의 규칙 열두 줄 아래에서.
2. **절단 tier 자체가 락 밖**이다. 그 줄을 지워도 락이 14/14 GREEN 이다.
3. **`set -euo pipefail` 을 앞에 붙이면 완전 침묵**한다 — 무가드 `rm` 이 rc 1 로 펜스를 죽여
   잔존이 살아남고 `SKIPPED … degraded` 줄조차 안 난다. 도달성은 낮지만(배포된 어느 펜스에도
   `set -e` 가 없다) 펜스의 계약 자체가 「앞에 이어 붙여라」이고, 고침은 `|| true` 하나다.
4. **종료점 열거가 여전히 부정확**하다. 실행으로 rc **137**(SIGKILL)·**153**(SIGXFSZ)에서
   0바이트 husk 를 만들었고 **rc 3 에서는 못 만들었다.** 동작에는 영향이 없지만(husk 는
   하류에서 이미 fail-closed) 그 서술이 공유 정본에 있어 세 자리가 베낀다.

**되돌리는 말** — 「1~4 중 무엇이든 지금 닫아」. 1 과 3 은 각각 몇 줄이고, 2 는 락 셀 하나,
4 는 정본의 한 문단이다.

### P6 — 도출 스윕이 놓친 인용 둘

절 개명(`Phase 5` → `## 게이트`)이 남긴 살아 있는 인용 중 둘이 아직 옛 이름을 가리킨다 —
`plugins/spec-distill/README.md:266`(codex CLI 항목) · `plugins/spec-distill/scripts/merge_review.py:2`
(모듈 docstring). **원인은 대상이 남아서가 아니라 도출의 입력이 불완전해서다**: 개명 목록을
만들 때 `##`/`###` 헤딩만 diff 하고 `#` 를 안 봐서 옛 H1 `# Reviewing Spec (Phase 3)` 이
집합에 못 들어갔다. 고침은 같은 치환 둘이고, 재발 방지는 개명 도출에 `#` 를 포함하는 것이다.

**되돌리는 말** — 「지금 둘 다 고쳐」. `merge_review.py` 는 어차피 PR 3 이 손대는 파일이다.

### P7 — 이 PR 이 스스로 검증하지 못한 것 (**AC8 은 2026-09-10 닫힘**)

**AC8** — 그 요구의 문자 그대로의 대상은 게이트의 **첫 줄 질문 텍스트**인데,
`AskUserQuestion` 은 헤드리스 `claude -p` 세션에 **존재하지 않는다**(`--allowedTools` 에
넣어도 세션 init 의 도구 배열 79개에 없다). 대리 채널(게이트가 쓰는 상태·렌더 함수)을 재고
「성립」이라 적는 것은 이 브랜치가 지운 결함(T9 의 C1)과 같은 종류이므로 하지 않았다.
**사람이 대화형 라운드를 한 번 돌리는 것 말고 길이 없다.**

같은 라운드가 **P4(게이트 사이징 · 설계 D6)** 도 함께 해소한다 — 첫 실측에서 게이트가
개별 결정 **14건**(decide 13 + 차단 ask 1)을 요구했고, 계약은 「하나의 `AskUserQuestion`」이다.
D6 이 묻는 것은 「묶음 하나가 몇 줄인가」이고 그 14 는 「묶음이 몇 개인가」라 **인접하되 같은
축이 아니다** — 그 라운드를 실제로 보면 두 축이 함께 정해진다.

**〔2026-09-10 — 실행함. AC8 닫힘.〕** 대화형 세션에서 한 라운드를 끝까지 돌렸다.
대상은 T9 이 쓴 것과 **다른** 문서(`2026-09-06-interview-depth-redesign-design.md`, 776줄)를
골랐다 — 같은 문서면 T9 의 수가 재현될 뿐이고, 다른 문서라야 그 수가 문서 특성인지 구조적인지
갈리기 때문이다. 게이트가 렌더됐고 **실제 `AskUserQuestion` 하나로 사람에게 올라가 사람이
답했다.** 그것이 AC8 의 문자 그대로의 내용이다.

부수적으로 확인된 것 — 게이트 **첫 줄이 `degrade 없음`(degrade 만), 둘째 줄이
`라운드 1 · 재리뷰 0/2`** 로, 이 PR 이 M1 에서 고친 `SKILL.md` 서술과 정확히 일치한다.
그리고 **선결 단계(`mkdir` + `init`)가 실제 경로에서 작동한다**(`created: true` → `round 1`) —
F11 고침의 실사용 확인이다.

**이 라운드가 남긴 것.** 판정 7건은 문서가 이미 구현된 설계(PR #145)라 적용하지 않고 버렸다.
그러나 그중 둘은 리포에서 **실측으로 확인된 진짜 결함**이라 별도로 다룰 값이 있다:
R1 예외가 G1·AC1 과 모순인데 출하된 `conducting-interview/SKILL.md` 는 조건을 붙여 구현
쪽에서 이미 해소했다는 것, 그리고 누적 원장 `depth/<basename>.json` 을 **커밋할 주체가
설계 어디에도 없고** 출하된 `finishing.md` 에 commit 단계가 0건이라는 것.

**PR 3 착수 «전»에 하기를 권한다.** PR 3 은 이 자리의 구조를 brief 자리에 복제하는 작업인데,
게이트가 결정 14건을 그대로 내는 것이 못 쓸 물건이면 같은 모양을 하나 더 만들기 전에 아는
편이 싸다.

### P8 — PR 3 이 물려받는 이월분 (판정 2)

`shared/docreview/scripts/merge_review.py` 와 `compute_issue_id.py`, 그리고 그 락 넷.
설계 §5.5 는 이 둘을 design-doc 자리 삭제 목록에 넣었지만, `merge_brief_review.py:37` 이
세 함수를 import 하고 **그 실패 경로가 `try` 라 죽지 않고 조용히 degrade** 한다(실측).
brief 자리를 전환하는 PR 3 이 그 import 를 없애는 자리이므로 삭제도 거기서 한다.

### P10 — 절차서가 스크립트를 벗은 파일명으로 부른다 (마스터 경로 호출)

`shared/docreview/references/reviewing-document.md` 는 여덟 단계에서 스크립트를
`docreview_route.py prepare-recritic …` 처럼 **경로 없이** 부른다. 그 문서를 읽고 정본
위치(`shared/docreview/scripts/`)로 해석하면 **여덟 중 둘에서 죽는다** — 2026-09-10 실행에서
한 라운드 안에 둘 다 물었다:

| 부른 경로 | 결과 |
|---|---|
| `shared/docreview/scripts/run_docreview_codex_reviewer.sh` | 형제 `runner_common.sh` 가 거기 없다(정본은 `shared/codex/`, 배포본은 `plugins/*/scripts/`) → **fail-closed + 정직한 기록**(`codex_failed: true · reason: runner_common_unloadable`, rc 0) |
| `shared/docreview/scripts/docreview_route.py` | **`ModuleNotFoundError: No module named 'adjudication'`, 생 traceback rc 1** |

둘 다 배포 경로(`plugins/spec-distill/scripts/…`)로 부르면 정상이다. **조용한 오독은 없다** —
둘 다 fail-closed 다. 문제는 **그 문서가 PR 3·4·5 가 자기 자리를 만들 때 베끼는 문서**라는
것이고, 같은 함정을 세 번 더 밟게 된다. 판정 25 가 이 취약성을 park 했을 때의 근거는
「고치려면 배포 링크 정본 목록을 건드려야 한다」였는데, **더 싼 고침이 있다: 절차서가
스크립트를 부르는 자리에 「배포 경로에서 부른다」를 한 줄로 명시하는 것.**

**되돌리는 말** — 「배포 링크를 마스터에도 걸어서 근본부터 고쳐」.

### P9 — 닫힌 항목 (기록만)

- **F1 잔여 — 2026-09-10 머지 후 측정, 닫힘.** `--plugin-dir` 없이 기본 세션에서
  `spec-distill:doc-critic` 이 정상 dispatch 되고 `Read, Grep, Glob` 만 갖는다. 그리고
  **집행이 자기보고가 아니라 파일시스템으로 확인됐다** — Write·Bash 를 실제로 시도시켰고
  대상 파일이 생기지 않았다(Law 2 의 물리적 분리 실증).

---

### Task 7: 삭제 전수(D0) 실행 — 파일 셋 + 고아 락 다섯 + 같은 커밋 재조준 여덟

**Files:** 아래 세 표가 전수다. 설계 §5.5 는 씨앗이었고 이것이 네 축(식별자 · 개념 별칭 · 의존 폐포 · 생산자↔소비자 양방향)으로 도출한 결과다.

**표 A — 지우는 것 (파일 8)**

| 파일 | 근거(유일 소비자) |
|---|---|
| `plugins/spec-distill/agents/spec-reviewer.md` | 유일 dispatch 자리가 Task 6 에서 껍데기가 된 `reviewing-spec/SKILL.md` |
| `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh` | 유일 실행 호출부가 같은 SKILL.md:91. `run_docreview_codex_reviewer.sh` 가 프로필 인자로 흡수 |
| `plugins/spec-distill/scripts/build_spec_codex_prompt.py` | 유일 소비자가 `run_spec_codex_reviewer.sh:152` |
| `plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh` | 피검자가 `spec-reviewer.md` 하나 |
| `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh` | 같음 |
| `plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh` | 피검자가 삭제되는 러너 |
| `plugins/spec-distill/tests/test_build_spec_codex_prompt.sh` | 피검자가 삭제되는 빌더 |
| `plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh` | SKILL.md 의 codex 병합 배선만 잰다 — 그 단계가 사라진다 |

(`test_reviewing_spec_design_routing.sh` 는 Task 6 이 지운다.)

**표 B — 이 PR 에서 지우지 **않는** 것 (PR 3 으로 이월)**

| 파일 | 살아 있는 소비자 |
|---|---|
| `plugins/spec-distill/scripts/merge_review.py` | **`merge_brief_review.py:37` 이 `codex_degraded_from`·`derive_codex_verdict`·`parse_codex_yaml` 셋을 import 한다.** brief 자리는 PR 3 이 전환한다 |
| `plugins/spec-distill/scripts/compute_issue_id.py` | `merge_review.py:27` |
| `test_merge_review.py` · `test_merge_review_adjudication.py` · `test_compute_issue_id.py` · `test_degrade_alias_single_definition.py` | 위 둘이 살아 있다 |
| `tools/adjudication/check_wiring.py:117` 의 `EXEMPT` 항목 · `tools/adjudication/check_consumed.py:15` | `merge_review.py` 를 (경로, 줄) 로 인용 — 파일이 안 바뀌므로 유효 |

**설계 §5.5 는 이 여섯을 design doc 자리의 「사라지는 것」에 넣었다.** 그 표는 스스로 「씨앗」이라 밝혔고 §10 은 「자리 하나씩」을 원칙으로 세웠다 — 다른 자리에 살아 있는 소비자가 있는 파일은 그 자리를 전환하는 PR 이 지운다. AC1(「실행 표면 0건」)은 다섯 PR 이 끝난 뒤의 상태를 재므로 이 이월이 AC1 을 어기지 않는다. `merge_brief_review.py:280` 의 import 실패 경로는 `try` 로 감싸여 있어 **죽지 않고 조용히 degrade 한다** — 지금 지우면 brief 리뷰가 PR 3 까지 매 라운드 codex 축 degrade 를 내고 그것이 정상으로 읽힌다.

**표 C — 삭제와 **같은 커밋**에서 재조준해야 하는 것 (안 하면 RED 이거나 조용히 vacuous)**

| 파일:줄 | 지금 하는 일 | 삭제 후 | 처분 |
|---|---|---|---|
| `plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh:246-260` | 삭제되는 러너를 **실행**한다(「5러너 C」) | **RED** | `run_docreview_codex_reviewer.sh` 로 재조준. 인자 수가 다르다(러너는 `<profile> <doc> <project_dir> <out>` 4개) — 그 절의 라벨 「5러너」가 실제 러너 수와 맞는지도 함께 본다 |
| `plugins/quality-gates/tests/test_agent_model_mutation.sh:30` | `spec-reviewer.md\|test_spec_reviewer_frontmatter.sh` 쌍을 변이 대상으로 | 짝이 통째로 사라져 **조용히 vacuous** | 그 줄을 지우고, 목록의 **vacuity 하한**이 있는지 확인해 하한도 함께 내린다. 하한이 없으면 그 사실을 report 에 적는다 |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh:10,58-68` | `REVIEWER=$SD/agents/spec-reviewer.md` — 음의 단언 넷 + 양의 단언 둘 | 음 넷은 **GREEN 유지 vacuous**, 양 둘은 RED | 음의 단언이 지키던 것(brief 리뷰어와의 역할 경계)을 새 표면에서 다시 잰다: 경계의 새 소유자는 `references/docreview-profiles/{design-doc,brief}.md` 의 `ground_truth`·`layer_rubric` 이다 |
| `plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh:6` · `test_handoff_context_section_required.sh:7` · `test_handoff_conversation_reference.sh:6` · `test_handoff_design_mode.sh:6` · `test_handoff_kill_switch.sh:6` | 다섯 다 `AGENT=…/spec-reviewer.md` | handoff 축이 통째로 소멸(대부분 vacuous) | `plugins/spec-distill/references/docreview-profiles/design-doc.md` 로 재조준. 그 프로필의 `layer_rubric.layer2` 에 `handoff_incomplete` 가 실재한다(:16) |
| `plugins/spec-distill/tests/test_web_kill_switch.sh:88,115,304-307` | 러너 이름 arm + 감사 범위 주석 | 죽은 arm(비차단) | arm 을 `run_docreview_codex_reviewer.sh` 로 바꾼다. **304-307 의 주석은 그대로 둔다** — 과거 실패의 기록이지 현행 인용이 아니다 |
| `plugins/quality-gates/tests/lib/codex_observation.sh:120` | `obs_invoke` 인자 표의 `run_spec_codex_reviewer.sh)` arm | 죽은 arm | 지운다. `run_docreview_codex_reviewer.sh` arm 은 PR 1b 가 이미 넣었다 |
| `plugins/quality-gates/tests/test_codex_gate_observation.sh` 의 `UNGATED_run_spec_codex_reviewer_sh` 등재 줄 + 그 위 주석 블록 | T6b 가 새로 넣었다(그 러너가 아직 살아 있으므로) | **삭제 후 조용히 썩는다** — 후보는 실재 파일에서 도출되므로 파일이 사라지면 그 변수는 아무도 읽지 않고 단언도 note 도 없다. 이 파일 헤더의 「목록은 줄어들기만 한다」는 «게이트가 생김» 방향에만 참이다 | **`git rm` 과 같은 커밋에서 그 줄과 주석 블록을 함께 지운다.** 줄번호는 밀렸으니 이름으로 찾는다 |
| `plugins/quality-gates/tests/test_codex_gate_observation.sh:73,319` | `UNGATED_run_docreview_codex_reviewer_sh` ratchet 항목이 「호출자 0」이라 적혀 있다 + 라벨 | 껍데기가 그 러너를 부르므로 **거짓** | 그 ratchet 줄을 **손으로 지운다**(그 원장의 주석이 「자동 만료되지 않는다」고 명시). 같은 파일 :88 의 `codex-gate:begin` 마커 하한 `-ge 3` 과 실제 마커 수를 함께 확인한다 |
| `plugins/spec-distill/tests/test_arm_ledger_timing.sh` (T12b) | 옛 어휘 두 토큰(`claude_verdict_unrecoverable`·`codex_degraded`)으로 껍데기를 잰다 | RED 1줄 | 두 토큰을 엔진 어휘(`blocks`·`critic 사망`)로 바꾼다. **불변식 자체는 껍데기에 살아 있다** — 락을 지우지 않는다 |
| `plugins/spec-distill/references/proceed-gate.md:3,117` · `conducting-interview/references/finishing.md:227` · `reviewing-brief/SKILL.md:429` | 「`reviewing-spec` 의 옵션 ① 블록에 앵커가 산다」 · 「cap 5」 | 살아 있는 문서의 죽은 인용 | 새 사실로 고친다. cap 은 2 이고 앵커는 껍데기 안이다 |
| `shared/codex/runner_common.sh:9` + `copy-of` 사본 둘(`plugins/spec-distill/scripts/`·`plugins/quality-gates/scripts/`) | 소비자 목록에 삭제되는 러너를 열거 | 거짓 인용 | 세 파일을 **한 커밋에서** 함께 고친다(바이트 동일 계약). 그 자리에 `run_docreview_codex_reviewer.sh` 를 넣는다 — 실제로 이 정본을 source 하는 러너다 |
| `plugins/spec-distill/skills/reviewing-brief/SKILL.md:29` · `plugins/spec-distill/scripts/run_seed_codex_reviewer.sh:5` | 「`run_spec_codex_reviewer.sh` 와 같은 규약」이라는 산문 비유 — **실행 표면**이다 | 거짓 인용. T7 Step 4 의 ① grep 이 이것을 잡는다 | 살아 있는 형제(`run_brief_codex_reviewer.sh` 또는 `run_docreview_codex_reviewer.sh`)로 비유 대상을 바꾼다 |
| `plugins/spec-distill/scripts/codex_prompt_common.py` 및 그 `copy-of` 사본들의 docstring | 「spec-distill 의 `build_spec_codex_prompt.py`·`build_brief_codex_prompt.py`」 | 거짓 인용(비차단) | **`copy-of` 사본은 바이트 동일이어야 하므로 정본과 사본을 같은 커밋에서 함께 고친다.** 정본은 `shared/codex/codex_prompt_common.py` |

- [ ] **Step 1: 표 A 를 지우기 전에, 표 C 의 재조준을 먼저 한다**

순서가 중요하다. 재조준을 먼저 하면 각 편집이 「아직 있는 파일」 위에서 검증되고, 그다음 삭제가 남은 참조를 0 으로 만든다. 반대로 하면 중간 상태에서 무엇이 vacuous 인지 구별할 수 없다.

- [ ] **Step 2: vacuous 를 실증한다 — 재조준한 락이 실제로 이빨을 유지하는지**

표 C 의 「조용히 vacuous」 항목(`test_brief_review_ng3.sh` 음의 단언 넷 · `test_agent_model_mutation.sh:30` · `test_handoff_*.sh` 다섯)은 **삭제만으로 GREEN 을 유지한다.** 재조준이 진짜인지 보려면 **재조준된 새 대상**에 양성 대조를 걸어야 한다: 새 대상 파일에서 그 락이 요구하는 문구를 일부러 지우고 RED 가 나는지 본다. 각 락마다 한 번씩 한다.

부재 락(음의 단언)에는 **양의 짝**이 필요하다 — 대상 파일이 실재하고 읽혔다는 단언이 없으면 파일을 통째로 지워도 통과한다.

- [ ] **Step 3: 표 A 를 지운다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git rm plugins/spec-distill/agents/spec-reviewer.md \
       plugins/spec-distill/scripts/run_spec_codex_reviewer.sh \
       plugins/spec-distill/scripts/build_spec_codex_prompt.py \
       plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh \
       plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh \
       plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh \
       plugins/spec-distill/tests/test_build_spec_codex_prompt.sh \
       plugins/spec-distill/tests/test_reviewing_spec_codex_merge.sh
```

- [ ] **Step 4: 잔존 참조를 **개념 별칭까지** 훑는다**

식별자만 grep 하면 다른 이름의 참조가 살아남는다. 넷을 다 돈다:

```bash
cd /Users/jeonghokim/Downloads/devbrew
# ① 식별자 — 실행 표면에서 0 이어야 한다(CHANGELOG·docs 의 이력 언급은 코퍼스 밖)
git grep -n 'spec-reviewer\|spec_reviewer\|run_spec_codex_reviewer\|build_spec_codex_prompt' \
  -- 'plugins/*/agents/*' 'plugins/*/skills/*' 'plugins/*/scripts/*' 'plugins/*/hooks/*' \
     'plugins/*/commands/*' 'plugins/*/references/*' 'plugins/*/tests/*' 'shared/*' | grep -v CHANGELOG
# ② 개념 별칭 — verdict 어휘가 실행 표면에 남았는가(AC2)
git grep -n 'needs_revise\|needs_interview\|combined_verdict\|claude_verdict\|Stagnation_signal\|issue_history\|raised_count\|dismissed_by_user' \
  -- 'plugins/spec-distill/skills/reviewing-spec/*' 'plugins/spec-distill/README.md'
```

①은 **0건**이어야 한다. ②는 `reviewing-spec` 껍데기와 README 의 design-doc 문단에서 0건이어야 하고, 다른 자리(brief·seed)의 것은 **그 자리 소유**라 남는다 — 남은 줄마다 어느 자리 소유인지 report 에 적는다.

- [ ] **Step 5: 스윕 — Task 6 이 남긴 RED 가 0 이 됐는지**

Task 6 의 report 가 적은 RED 목록과 대조한다. 새로 생긴 RED 는 baseline 의 둘 말고 없어야 한다. **파일별 실패 줄 수**로 비교한다 — 이미 RED 인 파일 안의 새 실패는 rc 로는 안 보인다.

- [ ] **Step 6: 커밋**

`chore(docreview)!: 옛 design-doc 리뷰 파이프라인 삭제 — 파일 8 + 락 재조준 8`

---

### Task 8: 문서 · 버전 · 철학 코드 지도

**Files:**
- Modify: `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json` (이 PR 이 그 플러그인의 테스트를 고쳤다 — CLAUDE.md 의 bump 요구)
- Modify: `plugins/plugin-audit/CHANGELOG.md` · `.claude-plugin/plugin.json` — **T7 이 그 플러그인의 러너와 테스트를 고쳤다.** 계획이 이 플러그인을 어디에도 안 적었고 지금 0.9.0 이다(cache key silent stale)
- Modify: `shared/README.md`(디렉토리 표에 `docreview/` 행)
- Modify: `docs/philosophy/devbrew-harness-philosophy.md:28,73`(코드 지도의 리뷰 자리 목록)

- [ ] **Step 1: `plugin.json` → `1.0.0`, CHANGELOG `## [1.0.0] — 2026-09-08`**

major 인 이유를 한 줄로: **verdict 계약이 깨진다**(`approved`/`needs_revise` 산출물이 없어지고 승인이 집계로 도출된다). `description` 의 "design docs reviewed by a physically-separated Law 2 reviewer" 문구가 여전히 참인지 본다 — `doc-critic`·`doc-recritic` 도 `tools:` 에 쓰기가 없으므로 참이지만, 리뷰어 이름이 바뀌었다.

- [ ] **Step 2: README 를 고치되 세 락의 요구를 지킨다**

- `test_readme_sync.sh` 의 12개 키워드가 README 어딘가에 최소 1회씩 남아야 한다. 그중 **`armed_paths`·`arm-once` 는 `reviewing-spec` 전용**이라 다른 자리 문단이 대신 채워주지 않는다.
- 같은 락의 AC14 절 검사(`## Principles Instantiated` 블록 안의 네 문구)는 brief 관련이다 — 그 섹션을 크게 고칠 때 실수로 지우지 않는다.
- ASCII 흐름도(`:52-53`)와 AP16 줄(`:137`)이 상한 락의 코퍼스다 — 새 값 2 와 새 어휘로 다시 쓴다.
- `## Principles Instantiated` 에 이 PR 의 항목을 더한다(CLAUDE.md 요구).

- [ ] **Step 3: 능력 축소를 명시한다 (조용히 넘기지 않는다)**

`spec-reviewer` 는 `tools:` 에 `WebSearch, WebFetch` 를 갖고 `run_spec_codex_reviewer.sh` 는 codex 웹을 **기본 ON** 으로 켰다. 새 엔진의 `doc-critic`·`doc-recritic` 은 `Read, Grep, Glob` 뿐이고 `design-doc.md` 프로필은 `web: false` 다 — **design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 된다.** 설계는 이것을 의도로 정했고(§5.3 표 · OQ-C) 이 태스크는 그 결정을 뒤집지 않는다. 다만:

1. CHANGELOG 의 `### Changed` 에 이 축소를 **한 줄로 명시**한다. 없어진 능력이 릴리스 노트에 없으면 다음 사람이 회귀로 읽는다.
2. README 에서 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 이 design-doc 리뷰를 덮는다는 서술이 있으면 고친다 — **끌 대상이 없는 kill switch 를 있다고 적으면 껐다고 믿게만 만든다**(P21).

- [ ] **Step 3b: 집행 없는 kill switch 를 없앤다 (P21)**

`plugins/spec-distill/README.md:231` 이 `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK` 를 문서화하는데,
**그 유일한 집행 지점이 T7 이 지운 agent 였다.** 리뷰어가 전수 확인했다 — 이 변수의 독자가
`shared/docreview/` 에도, 엔진 스크립트에도, 어느 프로필·skill 에도 없다(살아 있는 히트는 README
그 줄과 CHANGELOG 이력, 그리고 락 자신뿐).

집행이 0인데 문서화된 스위치는 **껐다고 믿게만 만든다.** 두 갈래뿐이고 둘 중 하나를 고른다:
① README 의 그 줄을 지운다 — 그리고 **같은 커밋에서** `test_handoff_kill_switch.sh` 의 코퍼스에
README 를 넣는다(지금은 영구 RED 를 피하려고 빼 뒀고, 그 파일 헤더가 다음 사람에게 넣는 법을
적어 뒀다). ② 엔진이 그 스위치를 존중하게 만든다 — 그러면 새 surface 라 설계 §9 의 kill switch
목록도 함께 고쳐야 한다.

①을 권한다: 그 스위치가 끄던 검사(`handoff_incomplete`)는 이제 프로필 rubric 의 항목이고,
프로필을 고치는 것이 그 자리의 opt-out 이다. **어느 쪽이든 리포트에 근거를 적는다.**

- [ ] **Step 4: 철학 코드 지도**

`docs/philosophy/devbrew-harness-philosophy.md:28,73` 이 `spec-reviewer.md` 를 살아 있는 코드 예시로 지목한다. 새 예시는 `shared/docreview/agents/doc-critic.md`(Law 2 의 `tools:` allowlist)다. **인용이 가리키는 사실이 실제로 그 파일에 있는지 열어 확인하고 바꾼다.**

- [ ] **Step 5: 커밋** — `docs(spec-distill): 1.0.0 — 엔진 전환 문서 · 코드 지도 · 웹 능력 축소 공시`

---

### Task 9: 자리별 e2e — 이 설계 문서 자체로 라운드 3회 + AC27 나머지 절반

**Files:** 없음(관측). 관측 결과는 report 파일과 CHANGELOG 로만 남는다.

**배경.** 설계 §13 항목 4 는 각 PR 머지 **전에** 그 자리의 실제 문서 하나로 라운드 3회를 돌리라고 한다. design doc 자리의 대상은 **이 재설계 문서 자체**다(OQ-A 의 `decide` 비율이 그 자리에서 바로 보인다). 그리고 AC27 의 나머지 절반 — `doc-recritic` sentinel 의 `verdicts`/`added` 컨테이너 타입이 **실제 agent 출력**의 스키마와 맞는지 — 는 첫 호출자의 e2e 산출물로만 잴 수 있다. **엔진은 지금까지 한 번도 실제 리뷰를 돌린 적이 없다.**

- [ ] **Step 1: 라운드 1 — 최초 리뷰**

`docs/superpowers/specs/2026-09-06-document-review-redesign-design.md` 를 대상으로 `reviewing-spec` 을 수동 호출해 절차서의 여덟 단계를 돈다. 관측:
- 라운드 게이트에 `decide` 묶음이 C2 의 네 항목(변경 내용 · 근거 · 대안 · 영향)을 채워 보이는가
- 게이트 첫 줄이 degrade 공시인가(AC8)
- `fin.json` 의 `adjudication_*` 계수가 실재하는가

- [ ] **Step 2: AC27 나머지 절반 — recritic 산출물의 스키마 대조**

`doc-recritic` 의 **실제 출력**을 저장하고, `docreview_route.py` 의 파서가 기대하는 `verdicts`/`added` 컨테이너 타입과 맞는지 본다. 어긋나면 **파서가 아니라 무엇이 틀렸는지 먼저 판정한다** — agent 정의의 출력 예시가 틀렸을 수도 있고 파서가 틀렸을 수도 있다. 고치는 쪽을 근거와 함께 report 에 적는다.

- [ ] **Step 3: 얼림 — 일부러 건드린다**

라운드 1 에 finding 이 없던 섹션을 한 줄 고치고 라운드 2 를 돈다. 자동 `decide` 가 뜨고 `evidence` 에 헤딩 diff 가 실리는지(AC4).

- [ ] **Step 4: 라운드 3 뒤 승인 게이트**

`rereview_count` 가 2 에 도달하고 승인 게이트에 「추가 라운드 1회 열기」가 선택지로 있는지, 그 선택 없이 라운드 4 가 **돌지 않는지**(AC7).

- [ ] **Step 5: arm-once 원장**

`mark-reviewed` 가 **승인 게이트 2단계에서 진행을 고른 뒤에만** 찍히는지, 그 전에 `armed_paths`·`inflight_paths`·`dispatch_attempts` 가 어떻게 변하는지 `$STATE` 를 직접 읽어 확인한다.

- [ ] **Step 6: 관측을 기록한다**

`decide` 비율(OQ-A)을 세어 report 에 적는다 — 설계는 임계값을 정하지 않았으므로 판정하지 않고 **수치만** 남긴다. 이 e2e 가 실패하면 그것이 이 PR 의 결과다: 무엇이 어떻게 실패했는지 적고, 고칠 수 있으면 고치고, 못 고치면 멈추고 보고한다. **「돌려보지 않았다」와 「돌렸는데 괜찮았다」는 다른 사실이다.**

---
