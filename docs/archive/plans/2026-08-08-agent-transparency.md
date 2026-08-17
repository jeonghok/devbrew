# agent-transparency 구현 계획

> ## ⚠️ 이 계획은 실행 완료됐고, 그 산출물 중 **부품 2(`SubagentStop` 훅)는 2026-08-13에 제거됐다**
>
> 이 문서는 **무엇을 했는지의 기록**이지 지금 따라야 할 지시가 아니다. 훅 관련 task 를 그대로
> 실행하면 **제거된 부품을 다시 만든다.** 라이브 probe 가 그 훅의 `additionalContext` 는 메인
> 대화가 아니라 **방금 끝난 subagent** 로 배달되고 그 subagent 를 계속 돌게 만든다는 것을 보였다.
>
> 아래 본문에서 무효인 것: 「세 부품」 구조 · `hooks/` 관련 task 전부 · AC6 · AC7 · AC8 · AC9 ·
> AC36 · AC37 · AC44 · AC50 · AC48③④ · `tests/test_subagent_hook.py` · `tests/probe/agent_type.txt`.
> 근거 전량과 되살리려는 경우의 절차는 **spec §11** 에 있다.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew의 다섯 번째 플러그인 `agent-transparency` 를 만든다 — output style · `SubagentStop` 훅 · `/standup` 세 부품으로 이해부채(사람이 이해한 것과 실제로 일어난 것의 격차)를 줄인다.

**Architecture:** 앞의 둘이 **기록을 만들고**(설명이 메인 트랜스크립트에 쌓인다) 셋째가 그것을 **다시 꺼낸다.** 상태 파일을 만들지 않는다. 훅은 `agent_type` 라벨로 세 갈래(무출력 / 상수 B / 상수 A) 중 하나를 골라 상수를 주입할 뿐 내용을 검사하지 않는다. `/standup` 은 준비 스크립트가 찍은 인벤토리를 fork 안의 전용 read-only agent 가 받아 트랜스크립트를 직접 읽는 **탐색** 구조다.

**Tech Stack:** Python 3.9 표준 라이브러리만 · bash 3.2 · `unittest` · Claude Code 플러그인 표면(output style · hook · command · skill · agent)

**Spec:** [`docs/superpowers/specs/2026-08-05-agent-transparency-design.md`](../../superpowers/specs/2026-08-05-agent-transparency-design.md) — 아래에서 **spec** 이라고만 쓴다. 인수 조건 38건의 정본은 그 문서 §9.

## 목차

- [Global Constraints](#global-constraints)
- [Spec 대비 의도적 차이 12건](#spec-대비-의도적-차이-12건)
- [File Structure](#file-structure)
- [Task 1: 플러그인 골격 · 매니페스트 · marketplace 등록](#task-1-플러그인-골격--매니페스트--marketplace-등록)
- [Task 2: output style 본체 (AC1–AC5 · AC26 파리티 · AC31 · AC38)](#task-2-output-style-본체-ac1–ac5--ac26-파리티--ac31--ac38)
- [Task 3: SubagentStop 훅 (AC6–AC9 · AC36 · AC37 · AC44 · AC50)](#task-3-subagentstop-훅-ac6–ac9--ac36--ac37--ac44--ac50)
- [Task 4: 전용 read-only agent (AC48①②)](#task-4-전용-read-only-agent-ac48①②)
- [Task 5: `prepare_standup.py` — 리포 루트 해석 · 후보 수집 · 후보 검증 (AC10 · AC41 · AC49)](#task-5-prepare_standuppy--리포-루트-해석--후보-수집--후보-검증-ac10--ac41--ac49)
- [Task 6: `prepare_standup.py` — 범위 판정 · 인벤토리 계수 (AC11 · AC34 · AC42)](#task-6-prepare_standuppy--범위-판정--인벤토리-계수-ac11--ac34--ac42)
- [Task 7: `prepare_standup.py` — 출력 렌더 · git 블록 · 실패 경로 (AC46 · AC20)](#task-7-prepare_standuppy--출력-렌더--git-블록--실패-경로-ac46--ac20)
- [Task 8: `/standup` skill · command · 가독성 파리티 (AC16① · AC27 · AC28 · AC35①–⑤ · AC43 · AC51)](#task-8-standup-skill--command--가독성-파리티-ac16①--ac27--ac28--ac35①–⑤--ac43--ac51)
- [Task 9: `REFERENCE.md` 정본 (AC32 · AC33 · AC47)](#task-9-referencemd-정본-ac32--ac33--ac47)
- [Task 10: A/B 고정 픽스처 · 숨김 오라클 · 작업 프롬프트](#task-10-ab-고정-픽스처--숨김-오라클--작업-프롬프트)
- [Task 11: `ab_gate.sh` 실행 러너 (AC40 · AC45)](#task-11-ab_gatesh-실행-러너-ac40--ac45)
- [Task 12: `ab_judge.py` 판정 단계 (D4 — §0 의 "러너 전체 고정"을 참으로 만든다)](#task-12-ab_judgepy-판정-단계-d4--0-의-러너-전체-고정을-참으로-만든다)
- [Task 13: probe 실행 3종 · 락 (AC48④ · AC35⑥ · AC39)](#task-13-probe-실행-3종--락-ac48④--ac35⑥--ac39)
- [Task 14: README · 문서 · 마감 (AC25 · D10 · D11)](#task-14-readme--문서--마감-ac25--d10--d11)
- [머지 게이트 (AC29) — 별도 실행](#머지-게이트-ac29--별도-실행)

## Global Constraints

이 절의 모든 항목은 **모든 task 의 요구사항에 암묵적으로 포함된다.**

- **Python 3.9.6** — `match` 문·`X | Y` 타입 문법 금지. `from __future__ import annotations` 를 쓰면 `list[str]` 주석은 가능.
- **bash 3.2.57** — 이 기계에 bash 4 가 **없다**(`bash` 와 `/bin/bash` 가 같은 3.2). `mapfile`/`readarray` · `declare -A` · `${x^^}` · `&>>` 금지.
- **테스트 실행은 `-m unittest` 로만**, 리포 루트에서: `python3 -m unittest plugins/agent-transparency/tests/test_output_style.py`
- **CI 없음.** 각 task 의 마지막 단계에서 그 task 가 만든 테스트 파일을 직접 돌린다.
- **파일 읽기는 항상 `encoding="utf-8"` 명시.** 로케일이 UTF-8 이 아닌 환경에서 조용히 깨지는 것을 막는다.
- **플러그인 버전은 `0.1.0`** 으로 시작하고, 이 계획 전체가 하나의 feature 이므로 **task 마다 bump 하지 않는다.** 마지막 task 에서 CHANGELOG 를 마감한다.
- **문서는 한국어 primary.** 영어는 식별자·고유명사·원문 인용·번역이 어색한 기술 용어에 한정. **단 `output-styles/agent-transparency.md` 본문과 훅 상수 문자열은 영어다** — spec §6.1·§6.2 가 그 이유를 못박았다(내장 `Explanatory` 원문이 영어 · 한국어 지시문이 영어 세션의 응답 언어를 오염시킨다).
- **현재 브랜치는 `worktree-feature+comprehension-debt-plugin`** 이다. spec §13 Metadata 는 `feature/comprehension-debt-plugin` 이라고 적었지만 실물이 다르다 — 아래 D10.
- **커밋 메시지는 Conventional Commits**: `feat(agent-transparency): …` · `test(agent-transparency): …`.
- **작업 디렉토리는 워크트리 절대경로** `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+comprehension-debt-plugin` 이다. 메인 리포(`/Users/jeonghokim/Downloads/devbrew`)에 쓰지 않는다.

## Spec 대비 의도적 차이 12건

계획이 spec 을 그대로 옮기지 않는 지점 전부다. 각각 **왜** 가 붙어 있고, 이 목록 밖의 차이는 없다.

| # | 차이 | 근거 |
|---|---|---|
| **D1** | 러너의 `[ "${BASH_VERSINFO[0]}" -ge 4 ]` **가드를 제거**하고 bash 3.2 호환으로 쓴다 | 가드의 근거였던 `mapfile` 이 러너 최종본에 없다(`while read` + process substitution 으로 대체됨). 이 기계에 bash 4 가 없으므로 가드를 남기면 머지 게이트가 **구조적으로 실행 불가**다. 대신 AC45① 에 "bash 4 전용 구문 부재" 문자열 검사를 더해 회귀를 막는다 |
| **D2** | 러너의 `FX` 를 `mktemp -d` 직후 **물리 경로로 정규화** | macOS 의 `mktemp -d` 는 `/var/…`(심볼릭)를 준다. 픽스처 cwd 가 심볼릭이면 `claude` 가 만드는 프로젝트 슬러그와 `prepare_standup.py` 가 계산하는 슬러그가 갈려 `/standup` 이 0 파일을 보고, 게이트 5a·5b 가 **매 실행 실패**한다 |
| **D3** | `--git-common-dir` **정규화 규칙을 확정** — `os.path.realpath(os.path.join(cwd, out))` | 실측: 워크트리에서는 절대경로, **메인 리포에서는 상대 `.git`** 을 준다. 정규화 없이 문자열 비교하면 후보 검증이 전부 `other-repo` 로 떨어진다. spec 은 이 규칙을 정하지 않았다 |
| **D4** | 「판정 단계」 1–7 을 **`tests/ab_judge.py` 로 구현**하고 `ab_gate.sh` 가 호출 | spec §0 이 *"실행 러너 전체가 §10-6 에 고정됐다"* 고 주장하는데 판정 단계는 산문이었다. 구현하면 그 주장이 참이 되고, 사람이 조각을 이어 붙이지 않는다 |
| **D5** | **AC51 신설** — `commands/standup.md` 본문 검증 | 이월 지적. AC39 는 이름 충돌, AC40 은 러너, AC43 은 `SKILL.md` 를 보므로 이 glue 파일의 오타·스킬명 오기·`$ARGUMENTS` 누락이 어떤 테스트도 안 거친다 |
| **D6** | **`tests/probe/command_name.txt` 신설**(네 줄 형식) | AC39 의 검증은 *"실물 probe"* 인데 스위트 안에서 `claude` 를 부를 수 없다(AC48④ 가 같은 이유로 금지). probe 기록 파일이 유일한 in-suite 검증 수단이다 |
| **D7** | AC41 에 **`cwd-missing` 픽스처** 추가(세 번째) | spec §6.3 후보 검증 계약은 거절 사유를 셋으로 열거하는데 AC41 의 픽스처는 둘뿐이었다 |
| **D8** | AC20 에 **양의 짝** 추가 — git 이 있는 픽스처에서 `## 코드 상태` 에 실제 `git log`·`git diff --stat` 결과가 들어간다 | 음의 락(부재 확인)만 있으면 블록을 통째로 안 내는 구현이 통과한다 |
| **D9** | kill switch 와 *"모든 강등은 출력에 남는다"* 의 경계를 **REFERENCE.md 에 한 줄로** 명시 | AC6 은 kill switch 시 stdout 비우기를 요구하고 §7 은 모든 강등이 출력에 남기를 요구한다. kill switch 는 **사용자가 요청한 비활성화**이지 강등이 아니라는 것이 해소다 |
| **D10** | 브랜치 이름은 **실물**(`worktree-feature+comprehension-debt-plugin`)을 쓰고, 마지막 task 에서 spec §13 Metadata 를 실물에 맞춘다 | 표기 불일치가 남아 있으면 다음 독자가 어느 쪽을 정본으로 읽을지 모른다 |
| **D11** | README 에 **「머지 후 수동 확인」 체크리스트**(항목·소유자) 추가 | OQ-R 의 *"머지 후 수동 확인이 필요하다"* 가 수행 주체·시점 없이 문장으로만 있었다 |
| **D12** | `.claude-plugin/marketplace.json` 에 **엔트리 추가** | spec §8 에 없지만 리포 규약상 등록하지 않으면 설치가 안 된다 |

## File Structure

```
plugins/agent-transparency/
├── .claude-plugin/plugin.json      # name · description · version 0.1.0
├── README.md                       # AC25 다섯 항목 + D11 머지 후 체크리스트
├── REFERENCE.md                    # ★정본 — AC 목록(조각 단위) · 배정표 · OQ 목록 ·
│                                   #   루브릭 A–D · 게이트 표 · 판정 구간 표
├── CHANGELOG.md
├── .gitignore                      # tests/out/
├── output-styles/agent-transparency.md
├── agents/transcript-reader.md
├── hooks/hooks.json · hooks/subagent-explain.py
├── commands/standup.md
├── skills/briefing-current-state/SKILL.md
├── scripts/prepare_standup.py
└── tests/
    ├── test_output_style.py         · test_subagent_hook.py
    ├── test_prepare_standup.py      · test_readability_parity.py
    ├── test_plugin_contract.py      · test_ab_runner_contract.py
    ├── ab_gate.sh · ab_judge.py
    ├── probe/{agent_type,skill_body,command_name}.txt
    ├── oracle/test_add_contract.py
    ├── prompts/{a,b,c,d}.txt
    ├── fixtures/ab-project/…
    └── out/                         # .gitignore 대상
```

책임 분리: **`scripts/prepare_standup.py` 는 판단하지 않는다**(범위 결정 · 계수 · git 조회). **`hooks/subagent-explain.py` 는 라벨만 본다**(내용 무검사). **`tests/ab_judge.py` 는 실행하지 않는다**(러너가 만든 산출물을 판정만 한다) — 셋 다 한 파일이 한 책임이며, 서로의 입력은 파일이라 독립 테스트가 가능하다.

---

## Task 1: 플러그인 골격 · 매니페스트 · marketplace 등록

**Files:**
- Create: `plugins/agent-transparency/.claude-plugin/plugin.json`
- Create: `plugins/agent-transparency/.gitignore`
- Create: `plugins/agent-transparency/CHANGELOG.md`
- Modify: `.claude-plugin/marketplace.json`
- Test: `plugins/agent-transparency/tests/test_plugin_contract.py`

**Interfaces:**
- Consumes: 없음 (첫 task)
- Produces: `PLUGIN_DIR = <repo>/plugins/agent-transparency` 상수 규약 — 이후 모든 테스트가 `Path(__file__).resolve().parents[3] / "plugins" / "agent-transparency"` 로 같은 값을 구한다. plugin.json 의 `description` 문자열이 Task 2 의 output style `description` 과 **글자 단위로 같아야** 한다(AC26).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/agent-transparency/tests/test_plugin_contract.py`:

```python
#!/usr/bin/env python3
"""플러그인 계약 테스트 — AC16① · AC25–AC27 · AC32 · AC33 · AC35 · AC39 · AC43 · AC51.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"


def read(rel: str) -> str:
    return (PLUGIN_DIR / rel).read_text(encoding="utf-8")


class TestManifest(unittest.TestCase):
    """AC26 — plugin.json 에 name · description · version 이 있다."""

    def setUp(self) -> None:
        self.manifest = json.loads(read(".claude-plugin/plugin.json"))

    def test_required_keys_present(self) -> None:
        for key in ("name", "description", "version"):
            self.assertIn(key, self.manifest)
            self.assertTrue(str(self.manifest[key]).strip(), key)

    def test_name_matches_directory(self) -> None:
        self.assertEqual(self.manifest["name"], "agent-transparency")

    def test_version_is_semver(self) -> None:
        parts = str(self.manifest["version"]).split(".")
        self.assertEqual(len(parts), 3)
        for part in parts:
            self.assertTrue(part.isdigit(), self.manifest["version"])


class TestMarketplaceEntry(unittest.TestCase):
    """D12 — marketplace 에 등록되지 않으면 설치가 안 된다."""

    def test_entry_exists_and_points_at_plugin(self) -> None:
        market = json.loads(
            (REPO_ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8")
        )
        hits = [p for p in market["plugins"] if p.get("name") == "agent-transparency"]
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["source"], "./plugins/agent-transparency")


class TestGitignore(unittest.TestCase):
    """§8 — tests/out/ 은 커밋되지 않는다(러너 산출물에 실제 트랜스크립트 사본이 있다)."""

    def test_out_dir_ignored(self) -> None:
        self.assertIn("tests/out/", read(".gitignore"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py`
Expected: FAIL — `FileNotFoundError: .../plugins/agent-transparency/.claude-plugin/plugin.json`

- [ ] **Step 3: 매니페스트를 만든다**

`plugins/agent-transparency/.claude-plugin/plugin.json` — `description` 은 Task 2 의 output style frontmatter `description` 과 **글자 단위로 같다**(AC26 이 그 동일성을 검사한다):

```json
{
  "name": "agent-transparency",
  "description": "Reduces comprehension debt — surfaces what delegated agents did and what your judgment rests on, at decision and verdict points",
  "version": "0.1.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

`plugins/agent-transparency/.gitignore`:

```
# 러너 산출물. pre-standup-*.jsonl 이 실제 트랜스크립트 사본이라 배포·커밋 대상이 아니다.
tests/out/
```

`plugins/agent-transparency/CHANGELOG.md`:

```markdown
# Changelog

## [Unreleased]

### Added
- 초기 구현 진행 중. 릴리스 시 이 절을 `## [0.1.0] — YYYY-MM-DD` 로 승격한다.
```

- [ ] **Step 4: marketplace 에 등록한다**

`.claude-plugin/marketplace.json` 의 `plugins` 배열 **맨 끝**에 추가한다(기존 네 항목은 건드리지 않는다):

```json
    {
      "name": "agent-transparency",
      "description": "Reduces comprehension debt: an output style, a SubagentStop hook, and /standup surface what delegated agents did and what your judgment rests on.",
      "source": "./plugins/agent-transparency",
      "category": "development"
    }
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py`
Expected: PASS (5 tests)

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency .claude-plugin/marketplace.json
git commit -m "feat(agent-transparency): 플러그인 골격 + 매니페스트 + marketplace 등록"
```

---

## Task 2: output style 본체 (AC1–AC5 · AC26 파리티 · AC31 · AC38)

**Files:**
- Create: `plugins/agent-transparency/output-styles/agent-transparency.md`
- Create: `plugins/agent-transparency/tests/test_output_style.py`
- Modify: `plugins/agent-transparency/tests/test_plugin_contract.py` (AC26 description 파리티 추가)

**Interfaces:**
- Consumes: Task 1 의 `plugin.json` `description` 문자열
- Produces: output style 본문의 다섯 개 규칙 앵커 주석 — `<!-- rule:jargon -->` · `<!-- rule:standard-term -->` · `<!-- rule:no-assumed-knowledge -->` · `<!-- rule:pointer -->` · `<!-- rule:analogy -->`. Task 8 의 `SKILL.md` 와 Task 9 의 파리티 테스트가 **같은 다섯 문자열**을 쓴다.
- Produces: 검사 함수 6개(`check_frontmatter` · `check_explanatory` · `check_moments` · `check_boundaries` · `check_format` · `check_settled_row`) — 각각 `(text: str) -> list[str]` 이고 **문제 목록**을 돌려준다. mutation 테스트가 같은 함수를 변형된 문자열에 호출한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

핵심 설계: 검사를 **순수 함수**로 두고 실물 파일과 변형 문자열 양쪽에 같은 함수를 돌린다. 이렇게 하지 않으면 mutation 이 "파일을 고쳤다 되돌린다"가 되어 계측이 안 된다.

`plugins/agent-transparency/tests/test_output_style.py`:

```python
#!/usr/bin/env python3
"""output style 회귀 락 — AC1 · AC2 · AC3 · AC4 · AC5 · AC31 · AC38.

검사는 순수 함수다. 실물 파일과 **변형 문자열** 양쪽에 같은 함수를 돌려
mutation 이 실제로 red 를 내는지 확인한다(파일을 고쳤다 되돌리는 방식은
계측이 되지 않는다).

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_output_style.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
STYLE = REPO_ROOT / "plugins" / "agent-transparency" / "output-styles" / "agent-transparency.md"

MOMENT_KEYS = [
    "ask the user to decide",
    "settled something without asking",
    "another agent's result comes back",
    "verdict or conclusion lands",
    "something you needed was unavailable",
    "starting a long task",
    "the work ends",
]
BOUNDARY_KEYS = ["long task", "verdict", "The work ends", "Unavailable",
                 "settled something without asking"]
RULE_ANCHORS = ["<!-- rule:jargon -->", "<!-- rule:standard-term -->",
                "<!-- rule:no-assumed-knowledge -->", "<!-- rule:pointer -->",
                "<!-- rule:analogy -->"]


def check_frontmatter(text: str) -> list[str]:
    """AC1 — 두 값이 **참으로** 선언돼 있다."""
    bad = []
    for key in ("keep-coding-instructions", "force-for-plugin"):
        if not re.search(r"(?m)^%s:\s*true\s*$" % re.escape(key), text):
            bad.append("frontmatter 에 %s: true 없음" % key)
    return bad


def check_explanatory(text: str) -> list[str]:
    """AC2 — Explanatory 4요소."""
    bad = []
    if "★ Insight" not in text:
        bad.append("Insight 블록 형식 없음")
    if "Before and after writing code" not in text:
        bad.append("코드 전후 시점 규정 없음")
    if "Do\nnot wait until the end" not in text and "not wait until the end" not in text:
        bad.append("미루지 않는다는 규정 없음")
    if "specific\nto this codebase" not in text and "specific to this codebase" not in text:
        bad.append("코드베이스 특유 요구 없음")
    return bad


def check_moments(text: str) -> list[str]:
    """AC3 — Moments 표가 7행이고 각 행이 「일곱 순간의 출처」와 1:1."""
    rows = [ln for ln in text.splitlines()
            if ln.startswith("|") and "---" not in ln
            and not ln.startswith("| Moment")]
    bad = []
    if len(rows) != 7:
        bad.append("Moments 표 행 수가 7이 아니라 %d" % len(rows))
    body = "\n".join(rows)
    for key in MOMENT_KEYS:
        if key not in body:
            bad.append("순간 누락: %s" % key)
    return bad


def check_boundaries(text: str) -> list[str]:
    """AC4 — Trigger boundaries 문단 + 5개 용어 + settled 의 제외절."""
    bad = []
    start = text.find("**Trigger boundaries.**")
    if start < 0:
        return ["Trigger boundaries 문단 없음"]
    end = text.find("\n\nExample,", start)
    para = text[start:end if end > 0 else len(text)]
    for key in BOUNDARY_KEYS:
        if key not in para:
            bad.append("경계 정의 누락: %s" % key)
    # 제외절은 **그 문단 안에** 있어야 한다 — 위치 축 mutation(문단 끝 밖으로 이동)에서 red.
    if "Formatting, naming, and the order of independent steps are not that." not in para:
        bad.append("settled 의 제외절이 Trigger boundaries 문단 안에 없음")
    return bad


def check_format(text: str) -> list[str]:
    """AC5 — Format 이 일곱 순간으로 스코프되고, 표는 항목 둘 이상일 때만."""
    bad = []
    if "When you explain at the moments above" not in text:
        bad.append("Format 규칙이 일곱 순간으로 스코프돼 있지 않음")
    if "a table around one row costs the reader more than it saves" not in text:
        bad.append("단일 항목 표 예외 문장 없음")
    return bad


def check_settled_row(text: str) -> list[str]:
    """AC38 — 「묻지 않고 정했을 때」 행이 세 항목 + 세 사유를 요구한다.

    행 번호가 아니라 **이름**으로 찾는다(표 안 위치는 바뀔 수 있다).
    """
    row = ""
    for line in text.splitlines():
        if line.startswith("|") and "settled something without asking" in line:
            row = line
            break
    if not row:
        return ["「묻지 않고 정했을 때」 행을 이름으로 찾을 수 없음"]
    bad = []
    if "what you decided" not in row:
        bad.append("무엇을 정했나 없음")
    if "why you did not ask" not in row:
        bad.append("왜 안 물었나 없음")
    if "what the user would say to reverse it" not in row:
        bad.append("되돌리는 말 없음")
    for reason in ("the evidence left one option", "a measurement ruled the others out",
                   "an earlier instruction from the user ruled them out"):
        if reason not in row:
            bad.append("사유 열거 누락: %s" % reason)
    return bad


CHECKS = (check_frontmatter, check_explanatory, check_moments,
          check_boundaries, check_format, check_settled_row)


class TestRealFile(unittest.TestCase):
    def setUp(self) -> None:
        self.text = STYLE.read_text(encoding="utf-8")

    def test_all_checks_pass(self) -> None:
        for check in CHECKS:
            self.assertEqual(check(self.text), [], check.__name__)

    def test_rule_anchors_present(self) -> None:
        """AC28 좌변 — 다섯 규칙 앵커. 우변은 test_readability_parity.py."""
        for anchor in RULE_ANCHORS:
            self.assertIn(anchor, self.text)

    def test_opposite_verdicts_instruction(self) -> None:
        """AC31 — 리뷰어·에이전트 간 상반 판정을 밝히라는 지시(K7)."""
        self.assertIn("two reviewers or agents reached opposite verdicts", self.text)


class TestMutation(unittest.TestCase):
    """표기 · 값 · 위치 세 축으로 흔든다. 내가 지운 바이트를 되돌리는 변형은 쓰지 않는다."""

    def setUp(self) -> None:
        self.text = STYLE.read_text(encoding="utf-8")

    def test_frontmatter_value_flip(self) -> None:
        """값 축 — true → false."""
        mutated = self.text.replace("keep-coding-instructions: true",
                                    "keep-coding-instructions: false")
        self.assertNotEqual(check_frontmatter(mutated), [])

    def test_frontmatter_notation_change(self) -> None:
        """표기 축 — YAML boolean 을 문자열로."""
        mutated = self.text.replace("force-for-plugin: true", 'force-for-plugin: "true"')
        self.assertNotEqual(check_frontmatter(mutated), [])

    def test_moments_row_deleted(self) -> None:
        """AC3 — 한 행을 지우면 red."""
        lines = self.text.splitlines()
        kept = [ln for ln in lines
                if "something you needed was unavailable" not in ln]
        self.assertNotEqual(check_moments("\n".join(kept)), [])

    def test_moments_row_added(self) -> None:
        """추가 축 — 8행이 되어도 red(리뷰어가 추가·반전으로 락을 통과한 전례)."""
        mutated = self.text.replace(
            "| When the work ends |",
            "| When you feel like it | anything |\n| When the work ends |")
        self.assertNotEqual(check_moments(mutated), [])

    def test_boundary_term_removed(self) -> None:
        mutated = self.text.replace("A *verdict* is any pass/fail", "A thing is any pass/fail")
        self.assertNotEqual(check_boundaries(mutated), [])

    def test_settled_exclusion_moved_out_of_paragraph(self) -> None:
        """위치 축 — 제외절을 문단 밖(예시 뒤)으로 옮겨도 red."""
        clause = "Formatting, naming, and the order of independent steps are not that."
        mutated = self.text.replace(clause, "")
        mutated = mutated.rstrip() + "\n\n" + clause + "\n"
        self.assertNotEqual(check_boundaries(mutated), [])

    def test_format_scope_removed(self) -> None:
        mutated = self.text.replace("**When you explain at the moments above**, use",
                                    "Always use")
        self.assertNotEqual(check_format(mutated), [])

    def test_table_exception_removed(self) -> None:
        mutated = self.text.replace(
            "a table around one row costs the reader more than it saves", "")
        self.assertNotEqual(check_format(mutated), [])

    def test_settled_reverse_item_removed(self) -> None:
        """AC38 — 되돌리는 항목이 빠지면 red(그것이 없으면 통보이지 투명성이 아니다)."""
        mutated = self.text.replace(
            " / **what the user would say to reverse it**", "")
        self.assertNotEqual(check_settled_row(mutated), [])

    def test_explanatory_element_removed(self) -> None:
        mutated = self.text.replace("Before and after writing code", "Sometimes")
        self.assertNotEqual(check_explanatory(mutated), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_output_style.py`
Expected: FAIL — `FileNotFoundError: .../output-styles/agent-transparency.md`

- [ ] **Step 3: output style 을 만든다**

`plugins/agent-transparency/output-styles/agent-transparency.md` — **spec 의 `#### 전문` 코드펜스 안(spec 파일 386–484줄)을 한 글자도 바꾸지 않고 그대로** 쓴다. `---` frontmatter 구분선도 그 내용의 일부다. 확인 명령:

```bash
sed -n '386,484p' docs/superpowers/specs/2026-08-05-agent-transparency-design.md \
  > plugins/agent-transparency/output-styles/agent-transparency.md
head -8 plugins/agent-transparency/output-styles/agent-transparency.md
tail -4 plugins/agent-transparency/output-styles/agent-transparency.md
```

첫 줄이 `---`, 둘째 줄이 `name: agent-transparency`, 마지막 줄이 `Provide them as you write code.` 인지 눈으로 확인한다. spec 이 편집돼 줄 번호가 밀렸으면 `sed` 대신 `#### 전문` 아래 첫 ` ```markdown ` 과 그 짝 ` ``` ` 사이를 손으로 복사한다.

- [ ] **Step 4: AC26 description 파리티를 추가한다**

`tests/test_plugin_contract.py` 의 `TestManifest` 에 추가:

```python
    def test_description_matches_output_style(self) -> None:
        """AC26 — plugin.json 의 description 이 output style frontmatter 와 같은 문구.

        output style 의 description 은 YAML 접힘(두 줄)이라 편다 — 이어지는 줄은
        들여쓰기로만 식별한다(다음 키는 열 0에서 시작한다).
        """
        body = read("output-styles/agent-transparency.md").split("---", 2)[1]
        head, tail = body.split("description:", 1)[1].split("\n", 1)
        folded = [head.strip()]
        for line in tail.splitlines():
            if not line.startswith("  "):
                break
            folded.append(line.strip())
        self.assertEqual(self.manifest["description"], " ".join(folded))
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_output_style.py
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
```
Expected: 둘 다 PASS. output style 테스트는 13 tests(실물 3 + mutation 10) — **mutation 이 하나라도 통과(green)하면 그 검사 함수에 이빨이 없다는 뜻**이므로 검사 함수를 고친다(테스트를 지우지 않는다).

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): output style 본체 + 회귀 락(AC1-AC5·AC31·AC38)"
```

---

## Task 3: SubagentStop 훅 (AC6–AC9 · AC36 · AC37 · AC44 · AC50)

**Files:**
- Create: `plugins/agent-transparency/hooks/hooks.json`
- Create: `plugins/agent-transparency/hooks/subagent-explain.py`
- Create: `plugins/agent-transparency/tests/test_subagent_hook.py`

**Interfaces:**
- Consumes: 없음 (훅은 stdin 만 읽는다)
- Produces: 모듈 상수 — `SELF_AGENT_TYPE = "agent-transparency:transcript-reader"` · `WORKFLOW_AGENT_TYPE = "workflow-subagent"` · `FALLBACK_AGENT_TYPE = "에이전트"` · `BASE_CONTEXT` · `GROUPING_SENTENCE` · `SYSTEM_MESSAGE`. Task 4 의 probe 락(AC48④)이 `SELF_AGENT_TYPE` 을 **훅 상수**로 참조한다 — agent frontmatter 의 `name:`(bare `transcript-reader`)이 아니다.
- Produces: 함수 `build_output(agent_type: str) -> dict | None` — `None` 이면 무출력 갈래. 테스트가 이 함수를 직접 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/agent-transparency/tests/test_subagent_hook.py`:

```python
#!/usr/bin/env python3
"""SubagentStop 훅 — AC6 · AC7 · AC8 · AC9 · AC36 · AC37 · AC44 · AC48③ · AC50.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
HOOK = PLUGIN_DIR / "hooks" / "subagent-explain.py"


def load_hook():
    """하이픈이 든 파일명이라 일반 import 가 안 된다 — 경로로 로드한다."""
    spec = importlib.util.spec_from_file_location("subagent_explain", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_hook(payload, env=None, cwd=None):
    """(rc, stdout, stderr) — 실제 프로세스로 돌린다."""
    merged = dict(os.environ)
    merged.pop("DEVBREW_DISABLE_AGENT_TRANSPARENCY", None)
    merged.pop("DEVBREW_SKIP_HOOKS", None)
    merged.update(env or {})
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=payload if isinstance(payload, bytes) else json.dumps(payload).encode("utf-8"),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=merged, cwd=cwd,
    )
    return (proc.returncode,
            proc.stdout.decode("utf-8"),
            proc.stderr.decode("utf-8"))


class TestKillSwitch(unittest.TestCase):
    """AC6 — kill switch 2종. set 이면 stdout 비고 exit 0."""

    def test_global_kill_switch(self) -> None:
        rc, out, _ = run_hook({"agent_type": "Explore"},
                              env={"DEVBREW_DISABLE_AGENT_TRANSPARENCY": "1"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_per_hook_kill_switch(self) -> None:
        rc, out, _ = run_hook(
            {"agent_type": "Explore"},
            env={"DEVBREW_SKIP_HOOKS": "other:hook,agent-transparency:subagent-explain"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_kill_switch_off_produces_output(self) -> None:
        """양방향 — 끄지 않으면 나온다."""
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())


class TestConstantBranches(unittest.TestCase):
    """AC7 · AC9 · AC36 · AC37 · AC44 — 상수 A·B 갈래."""

    def test_valid_json_with_additional_context(self) -> None:
        """AC7 — 상수 A·B 갈래에서 유효한 additionalContext JSON."""
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertEqual(data["hookSpecificOutput"]["hookEventName"], "SubagentStop")
        self.assertTrue(data["hookSpecificOutput"]["additionalContext"].strip())

    def test_no_decision_key_ever(self) -> None:
        """AC9 — 어떤 경우에도 decision 키가 없다(불변식)."""
        for payload in ({"agent_type": "Explore"},
                        {"agent_type": "workflow-subagent"},
                        {}, b"not json at all"):
            rc, out, _ = run_hook(payload)
            self.assertEqual(rc, 0)
            if out.strip():
                self.assertNotIn("decision", json.loads(out))

    def test_agent_type_appears_verbatim(self) -> None:
        """AC36 — agent_type 값이 additionalContext 에 그대로."""
        rc, out, _ = run_hook({"agent_type": "code-reviewer"})
        self.assertIn("code-reviewer",
                      json.loads(out)["hookSpecificOutput"]["additionalContext"])

    def test_missing_key_falls_back(self) -> None:
        """AC36 — 키 없음 → '에이전트' 로 대체하고 **정상 출력**."""
        rc, out, _ = run_hook({})
        self.assertEqual(rc, 0)
        self.assertIn("에이전트",
                      json.loads(out)["hookSpecificOutput"]["additionalContext"])

    def test_broken_stdin_falls_back(self) -> None:
        """AC36 — 파싱 불가 → 같은 대체 + 정상 출력(예외 경로가 아니다)."""
        rc, out, _ = run_hook(b"{{{ not json")
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertIn("에이전트", data["hookSpecificOutput"]["additionalContext"])
        self.assertIn("additionalContext", data["hookSpecificOutput"])

    def test_grouping_sentence_both_directions(self) -> None:
        """AC37 — workflow-subagent 면 나오고, 그 외면 안 나온다(양방향)."""
        module = load_hook()
        on = module.build_output("workflow-subagent")
        off = module.build_output("Explore")
        self.assertIn(module.GROUPING_SENTENCE.strip(),
                      on["hookSpecificOutput"]["additionalContext"])
        self.assertNotIn(module.GROUPING_SENTENCE.strip(),
                         off["hookSpecificOutput"]["additionalContext"])

    def test_four_elements_present(self) -> None:
        """AC44 — 훅 상수가 네 요소를 모두 담는다."""
        module = load_hook()
        for element in ("who ran", "what they found",
                        "where the evidence is", "how it changed your judgment"):
            self.assertIn(element, module.BASE_CONTEXT)

    def test_four_elements_mutation(self) -> None:
        """AC44 mutation — 요소 하나가 조용히 사라지면 red."""
        module = load_hook()
        mutated = module.BASE_CONTEXT.replace(" / how it changed your judgment", "")
        self.assertNotIn("how it changed your judgment", mutated)


class TestSelfForkBranch(unittest.TestCase):
    """AC48③ — 전용 agent 의 fork 는 무출력, Explore 는 상수 A(양방향)."""

    def test_own_fork_is_silent(self) -> None:
        rc, out, _ = run_hook({"agent_type": "agent-transparency:transcript-reader"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_other_agent_is_not_silent(self) -> None:
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())


class TestNoWrites(unittest.TestCase):
    """AC8 — 임시 HOME 과 임시 cwd 두 트리에 아무것도 쓰지 않는다.

    못 잡는 것: 절대경로·두 트리 밖 디렉토리 쓰기 · 생성 후 삭제된 임시 파일.
    """

    @staticmethod
    def tree_hash(root: Path) -> str:
        digest = hashlib.sha256()
        for path in sorted(root.rglob("*")):
            digest.update(str(path.relative_to(root)).encode("utf-8"))
            if path.is_file():
                digest.update(path.read_bytes())
        return digest.hexdigest()

    def test_two_trees_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as work:
            (Path(work) / "seed.txt").write_text("seed", encoding="utf-8")
            before = (self.tree_hash(Path(home)), self.tree_hash(Path(work)))
            run_hook({"agent_type": "Explore"}, env={"HOME": home}, cwd=work)
            after = (self.tree_hash(Path(home)), self.tree_hash(Path(work)))
            self.assertEqual(before, after)


class TestExceptionPath(unittest.TestCase):
    """AC50 — 예외면 systemMessage 만 담긴 JSON + exit 0 + stderr 사유.

    자극은 **직렬화 단계**다. 손상된 stdin 은 이 경로가 아니라 AC36 의
    '에이전트 로 대체하고 정상 출력' 경로다 — 두 자극을 섞으면 같은 입력에
    두 AC 가 상반된 출력을 요구하게 된다.
    """

    def test_serialization_failure(self) -> None:
        module = load_hook()
        written = []
        with mock.patch.object(module.json, "dumps", side_effect=RuntimeError("boom")), \
             mock.patch.object(module.sys.stdout, "write", side_effect=written.append), \
             mock.patch.object(module.sys.stderr, "write", side_effect=lambda s: None), \
             mock.patch.object(module.sys.stdin, "read", return_value='{"agent_type":"Explore"}'):
            rc = module.main()
        self.assertEqual(rc, 0)
        payload = json.loads("".join(written))
        self.assertIn("systemMessage", payload)
        self.assertNotIn("hookSpecificOutput", payload)
        self.assertNotIn("additionalContext", json.dumps(payload))

    def test_stderr_carries_reason(self) -> None:
        module = load_hook()
        errs = []
        with mock.patch.object(module.json, "dumps", side_effect=RuntimeError("boom")), \
             mock.patch.object(module.sys.stdout, "write", side_effect=lambda s: None), \
             mock.patch.object(module.sys.stderr, "write", side_effect=errs.append), \
             mock.patch.object(module.sys.stdin, "read", return_value="{}"):
            rc = module.main()
        self.assertEqual(rc, 0)
        self.assertIn("boom", "".join(errs))


class TestHooksJson(unittest.TestCase):
    def test_single_subagent_stop_entry_without_matcher(self) -> None:
        """SubagentStop 은 도구 매처를 받지 않으므로 matcher 키가 없다."""
        cfg = json.loads((PLUGIN_DIR / "hooks" / "hooks.json").read_text(encoding="utf-8"))
        entries = cfg["hooks"]["SubagentStop"]
        self.assertEqual(len(entries), 1)
        self.assertNotIn("matcher", entries[0])
        self.assertIn("subagent-explain.py", entries[0]["hooks"][0]["command"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py`
Expected: FAIL — `FileNotFoundError: .../hooks/subagent-explain.py`

- [ ] **Step 3: 훅을 구현한다**

`plugins/agent-transparency/hooks/subagent-explain.py`:

```python
#!/usr/bin/env python3
"""SubagentStop — 에이전트가 끝난 직후 설명 자리를 만든다.

이 훅은 **에이전트의 출력 내용을 검사하지 않고**, 차단하지 않으며, 파일을 쓰지
않는다. `agent_type` **라벨**에 따라 세 갈래(무출력 / 상수 B / 상수 A) 중 하나를
고르는 것은 내용 검사가 아니다. `decision` 키를 어떤 경우에도 내지 않는다.
"""
from __future__ import annotations

import json
import os
import sys

KILL_ENV = "DEVBREW_DISABLE_AGENT_TRANSPARENCY"
SKIP_ENV = "DEVBREW_SKIP_HOOKS"
SKIP_TOKEN = "agent-transparency:subagent-explain"

# `/standup` 의 fork 는 이 값으로 온다(2026-08-08 실측: `<플러그인>:<agent name>`).
# 그 fork 의 산출물이 곧 사용자 답변이므로 그것을 다시 설명하라는 지시는 자기모순이다.
SELF_AGENT_TYPE = "agent-transparency:transcript-reader"
WORKFLOW_AGENT_TYPE = "workflow-subagent"
FALLBACK_AGENT_TYPE = "에이전트"

BASE_CONTEXT = (
    "Report on the `{agent_type}` agent that just finished: who ran / what they found / "
    "where the evidence is / how it changed your judgment. Summarize the finding once; "
    "do not reproduce their response verbatim. "
    "Answer in the language the user is writing in."
)
# 워크플로에서 의미 있는 보고 단위는 에이전트 하나가 아니라 워크플로 전체다.
# 설명을 *줄이라*는 것이 아니라 **보고 단위**를 알려 주는 사실 서술이다(K1 억제 금지).
GROUPING_SENTENCE = (
    " This is one piece of a workflow — if other agents from the same workflow "
    "finished alongside it, report them together as one."
)
SYSTEM_MESSAGE = "[agent-transparency] 에이전트 결과 설명 자리"
EXCEPTION_MESSAGE = (
    "[agent-transparency] 훅 예외로 이번 에이전트 결과에 설명 자리가 붙지 않았습니다 (%s)"
)


def killed() -> bool:
    if os.environ.get(KILL_ENV) == "1":
        return True
    raw = os.environ.get(SKIP_ENV, "")
    tokens = [t.strip() for t in raw.replace(";", ",").replace(" ", ",").split(",")]
    return SKIP_TOKEN in [t for t in tokens if t]


def read_agent_type() -> str:
    """stdin 을 읽고 버린다(파이프 깨짐 방지). 못 읽으면 대체값."""
    try:
        raw = sys.stdin.read()
    except Exception:
        return FALLBACK_AGENT_TYPE
    try:
        payload = json.loads(raw)
    except Exception:
        return FALLBACK_AGENT_TYPE
    if not isinstance(payload, dict):
        return FALLBACK_AGENT_TYPE
    value = payload.get("agent_type")
    if not isinstance(value, str) or not value.strip():
        return FALLBACK_AGENT_TYPE
    return value.strip()


def build_output(agent_type: str):
    """세 갈래. None 이면 무출력 갈래(자기 fork)."""
    if agent_type == SELF_AGENT_TYPE:
        return None
    context = BASE_CONTEXT.format(agent_type=agent_type)
    if agent_type == WORKFLOW_AGENT_TYPE:
        context += GROUPING_SENTENCE
    return {
        "hookSpecificOutput": {
            "hookEventName": "SubagentStop",
            "additionalContext": context,
        },
        "systemMessage": SYSTEM_MESSAGE,
    }


def _degraded(exc: Exception) -> None:
    """알리되 주입하지 않는다 — additionalContext 를 비우는 것이 요점이다.

    `json.dumps` 가 죽은 경우에도 이 경로가 살아야 하므로 직접 조립한다.
    """
    try:
        sys.stderr.write("[agent-transparency] hook exception: %r\n" % (exc,))
    except Exception:
        pass
    reason = str(exc).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")
    try:
        sys.stdout.write('{"systemMessage": "%s"}' % (EXCEPTION_MESSAGE % reason))
    except Exception:
        pass


def main() -> int:
    try:
        if killed():
            return 0
        output = build_output(read_agent_type())
        if output is None:
            return 0
        sys.stdout.write(json.dumps(output, ensure_ascii=False))
    except Exception as exc:  # 설명 장치가 작업을 막으면 불변식 위반 — 그러나 조용히 죽지도 않는다
        _degraded(exc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`plugins/agent-transparency/hooks/hooks.json`:

```json
{
  "description": "agent-transparency — SubagentStop 훅 1건. 에이전트 종료 직후 설명 자리를 만든다(검사·차단 없음).",
  "hooks": {
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/subagent-explain.py\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py -v`
Expected: PASS (15 tests). `TestExceptionPath` 가 실패하면 `_degraded` 가 `json.dumps` 에 의존하고 있다는 뜻이다 — 그 의존이 있으면 예외 경로가 자기 자신을 못 살린다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): SubagentStop 훅 세 갈래 + kill switch(AC6-AC9·AC36·AC37·AC44·AC50)"
```

---

## Task 4: 전용 read-only agent (AC48①②)

**Files:**
- Create: `plugins/agent-transparency/agents/transcript-reader.md`
- Modify: `plugins/agent-transparency/tests/test_subagent_hook.py` (AC48①② 추가)

**Interfaces:**
- Consumes: Task 3 의 `SELF_AGENT_TYPE`
- Produces: agent 이름 `transcript-reader` — Task 8 의 `SKILL.md` frontmatter 가 `agent: agent-transparency:transcript-reader` 로 가리킨다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_subagent_hook.py` 끝에 추가:

```python
class TestDedicatedAgent(unittest.TestCase):
    """AC48①② — 전용 agent 존재 + fail-closed tools allowlist.

    ②는 **곱**이다: (a) `tools:` 가 키로 존재하고 비어 있지 않으며
    (b) 그 집합이 {Read, Glob, Grep} 의 **부분집합**이다. (a) 가 load-bearing —
    부분집합만 요구하면 키가 없거나 빈 값일 때 공집합이라 공허하게 참이 되는데,
    플랫폼 의미는 정반대(미선언 = 전 도구 허용)다.

    **부재 열거가 아니라 지배관계로 판정한다.** 금지 도구를 열거하는 검사는
    내일 추가될 쓰기 도구를 오늘 담을 수 없어 시간축으로 fail-open 이고,
    그것이 devbrew 가 `disallowedTools` 단독을 기각한 바로 그 근거다.
    """

    ALLOWED = {"Read", "Glob", "Grep"}
    AGENT = PLUGIN_DIR / "agents" / "transcript-reader.md"

    @staticmethod
    def tools_of(text: str):
        """선언된 tools 집합. 키가 없으면 None(= 미선언)."""
        body = text.split("---", 2)[1]
        for line in body.splitlines():
            if line.startswith("tools:"):
                raw = line.split(":", 1)[1].strip()
                return {t.strip() for t in raw.split(",") if t.strip()}
        return None

    def setUp(self) -> None:
        self.text = self.AGENT.read_text(encoding="utf-8")

    def test_agent_file_exists_with_name(self) -> None:
        self.assertTrue(self.AGENT.is_file())
        self.assertIn("name: transcript-reader", self.text)

    def test_tools_key_exists_and_is_non_empty(self) -> None:
        tools = self.tools_of(self.text)
        self.assertIsNotNone(tools, "tools: 키 자체가 없다 — 플랫폼 의미는 전 도구 허용")
        self.assertTrue(tools, "tools: 가 비어 있다 — 공집합은 공허하게 부분집합이다")

    def test_tools_are_dominated_by_allowlist(self) -> None:
        self.assertTrue(self.tools_of(self.text) <= self.ALLOWED)

    def test_glob_is_a_required_member(self) -> None:
        """OQ-AD 의 잔여위험 논증이 Glob 보유를 전제한다."""
        self.assertIn("Glob", self.tools_of(self.text))

    def test_disallowed_tools_alone_is_red(self) -> None:
        self.assertNotIn("disallowedTools", self.text)

    def test_mutation_tools_line_removed(self) -> None:
        """`tools:` 줄 삭제 mutation 에서 red."""
        mutated = "\n".join(ln for ln in self.text.splitlines()
                            if not ln.startswith("tools:"))
        self.assertIsNone(self.tools_of(mutated))

    def test_mutation_tools_line_emptied(self) -> None:
        mutated = self.text.replace("tools: Read, Glob, Grep", "tools:")
        self.assertEqual(self.tools_of(mutated), set())

    def test_mutation_write_tool_added(self) -> None:
        """추가 축 — 쓰기 도구가 들어오면 지배관계가 깨진다."""
        mutated = self.text.replace("tools: Read, Glob, Grep",
                                    "tools: Read, Glob, Grep, Write")
        self.assertFalse(self.tools_of(mutated) <= self.ALLOWED)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py`
Expected: FAIL — `FileNotFoundError: .../agents/transcript-reader.md`

- [ ] **Step 3: agent 정의를 만든다**

`plugins/agent-transparency/agents/transcript-reader.md` — spec §6.3 「전용 agent 계약」의 코드펜스 그대로:

```markdown
---
name: transcript-reader
description: /standup 의 fork 전용 — 디스크의 대화 기록과 git 산출물만 읽어 지금 상태를 답한다
tools: Read, Glob, Grep
model: inherit
---

You are the transcript reader for `/standup`. You are responsible for reading the
transcript files and git output the inventory points at, and answering in the three
sections the skill defines. You are NOT responsible for editing any file, running any
command, or fetching anything over the network — you do not have the tools to.
```

**쓰는 방식 규칙을 여기 두지 않는다** — 규칙이 살 수 있는 자리는 셋(output style · `SKILL.md` · 이 파일)인데 AC28 파리티는 앞의 둘만 본다. 세 번째 사본을 만들면 파리티가 못 보는 drift 가 생긴다.

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py`
Expected: PASS (23 tests)

- [ ] **Step 5: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): /standup fork 전용 read-only agent(AC48①②)"
```

---

## Task 5: `prepare_standup.py` — 리포 루트 해석 · 후보 수집 · 후보 검증 (AC10 · AC41 · AC49)

**Files:**
- Create: `plugins/agent-transparency/scripts/prepare_standup.py`
- Create: `plugins/agent-transparency/tests/test_prepare_standup.py`

**Interfaces:**
- Consumes: 없음
- Produces: 함수 6개 —
  - `git_common_dir(cwd: str) -> str | None` — 정규화된 절대 경로. 실패면 `None`
  - `repo_root(cwd: str) -> str | None` — `git_common_dir` 의 **부모**
  - `slug(path: str) -> str` — `/`·`.`·`+` → `-`
  - `candidate_paths(root: str) -> list[str]` — `~/.claude/projects/<슬러그>*/` **바로 아래(비재귀)** `*.jsonl`
  - `read_records(path: str) -> tuple[list[dict], int]` — `(레코드, 파싱 실패 줄 수)`
  - `classify(records, our_common_dir, cache) -> tuple[bool, str]` — `(채택 여부, 사유)`. 사유 ∈ `{"", "other-repo", "cwd-gone", "cwd-missing"}`
- Task 6·7 이 이 여섯을 그대로 쓴다.

**왜 이 셋이 한 task 인가:** 셋 다 *"어느 파일이 대상인가"* 하나의 질문이고, 후보 검증은 후보 수집 없이는 돌릴 대상이 없다. 리뷰어가 "수집은 맞는데 검증은 틀렸다"로 반쪽만 승인할 수 있는 경계가 아니다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/agent-transparency/tests/test_prepare_standup.py`:

```python
#!/usr/bin/env python3
"""prepare_standup.py — AC10 · AC11 · AC20 · AC34 · AC41 · AC42 · AC46 · AC49.

이 파일의 픽스처는 **전부 합성**이다. 실제 세션 파일은 테스트에 쓰지 않는다
(비밀·개인정보).

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py
"""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "agent-transparency" / "scripts" / "prepare_standup.py"


def load_script():
    spec = importlib.util.spec_from_file_location("prepare_standup", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(*args, cwd):
    subprocess.run(["git"] + list(args), cwd=str(cwd), check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def make_repo(path: Path, branch: str = "work") -> None:
    """git init + 최초 커밋 + 브랜치 이름 고정."""
    path.mkdir(parents=True, exist_ok=True)
    git("init", "-q", cwd=path)
    git("config", "user.email", "t@t.t", cwd=path)
    git("config", "user.name", "t", cwd=path)
    (path / "seed.txt").write_text("seed\n", encoding="utf-8")
    git("add", "-A", cwd=path)
    git("commit", "-qm", "seed", cwd=path)
    git("branch", "-M", branch, cwd=path)


def rec(**kw):
    """레코드 하나. timestamp 는 기본값을 준다."""
    base = {"timestamp": "2026-08-02T09:11:00.000Z"}
    base.update(kw)
    return base


def assistant_text(text, **kw):
    return rec(type="assistant",
               message={"role": "assistant", "content": [{"type": "text", "text": text}]},
               **kw)


def write_jsonl(path: Path, records) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        for record in records:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")


class Sandbox:
    """임시 HOME + 메인 리포 + 워크트리 + 합성 프로젝트 디렉토리.

    **HOME 을 스스로 설정하고 close() 에서 되돌린다.** 테스트마다 os.environ 을
    손대고 복구하지 않으면 뒤 테스트가 앞 테스트의 HOME 을 물려받아, 실패가
    실행 순서에 따라 나타났다 사라진다.
    """

    def __init__(self) -> None:
        # macOS 의 mktemp 계열은 심볼릭 경로를 준다 — 슬러그가 어긋나므로 물리 경로로 푼다.
        self.root = Path(tempfile.mkdtemp(prefix="at-standup-")).resolve()
        self.home = self.root / "home"
        self.projects = self.home / ".claude" / "projects"
        self.projects.mkdir(parents=True)
        self.main = self.root / "devbrew"
        make_repo(self.main, branch="work")
        self.worktree = self.main / ".claude" / "worktrees" / "wt"
        git("worktree", "add", "-q", "-b", "wt-branch", str(self.worktree), cwd=self.main)
        self._prev_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)

    def project_dir(self, path: Path) -> Path:
        module = load_script()
        target = self.projects / module.slug(str(path))
        target.mkdir(parents=True, exist_ok=True)
        return target

    def close(self) -> None:
        if self._prev_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self._prev_home
        shutil.rmtree(self.root, ignore_errors=True)


class TestRootResolution(unittest.TestCase):
    """AC10 — 슬러그 접두사를 **메인 리포 루트**에서 만든다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_common_dir_is_absolute_even_in_main_repo(self) -> None:
        """메인 리포에서 git 은 상대 '.git' 을 준다 — 정규화가 없으면 비교가 깨진다."""
        raw = subprocess.run(["git", "rev-parse", "--git-common-dir"],
                             cwd=str(self.box.main), stdout=subprocess.PIPE,
                             check=True).stdout.decode().strip()
        self.assertFalse(os.path.isabs(raw))
        self.assertTrue(os.path.isabs(self.module.git_common_dir(str(self.box.main))))

    def test_same_common_dir_from_worktree_and_main(self) -> None:
        self.assertEqual(self.module.git_common_dir(str(self.box.main)),
                         self.module.git_common_dir(str(self.box.worktree)))

    def test_root_from_worktree_is_main_repo(self) -> None:
        self.assertEqual(self.module.repo_root(str(self.box.worktree)),
                         str(self.box.main))

    def test_prefix_catches_main_and_sibling_worktree(self) -> None:
        """워크트리 안에서 실행해도 메인 리포와 형제 워크트리 디렉토리가 **둘 다** 잡힌다.

        `--show-toplevel` 기반 구현은 워크트리 경로가 더 길어 접두사 방향이
        반대라 1개만 잡고, 파일이 0개가 아니므로 정상처럼 답한다.
        """
        main_dir = self.box.project_dir(self.box.main)
        wt_dir = self.box.project_dir(self.box.worktree)
        write_jsonl(main_dir / "aaa.jsonl", [assistant_text("m", gitBranch="work")])
        write_jsonl(wt_dir / "bbb.jsonl", [assistant_text("w", gitBranch="wt-branch")])
        os.environ["HOME"] = str(self.box.home)
        module = load_script()  # HOME 반영을 위해 재로드
        found = module.candidate_paths(str(self.box.main))
        self.assertEqual(len(found), 2, found)


class TestCandidateValidation(unittest.TestCase):
    """AC41 — 무관한 리포 배제 · 삭제된 워크트리를 **오분류하지 않음** · 집합 술어."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.ours = self.module.git_common_dir(str(self.box.main))
        self.addCleanup(self.box.close)

    def test_other_repo_rejected(self) -> None:
        """접두사만 공유하는 다른 리포는 0건 포함."""
        other = self.box.root / "devbrew-experiments"
        make_repo(other, branch="main")
        ok, reason = self.module.classify(
            [rec(cwd=str(other), gitBranch="main")], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "other-repo")

    def test_deleted_worktree_is_cwd_gone_not_other_repo(self) -> None:
        """이미 삭제된 cwd 는 other-repo 가 아니라 cwd-gone 으로 계상된다.

        남의 리포와 합산하면 정당한 과거 세션이 조용히 사라진다.
        """
        ok, reason = self.module.classify(
            [rec(cwd=str(self.box.root / "vanished"))], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "cwd-gone")

    def test_no_cwd_anywhere_is_cwd_missing(self) -> None:
        """세 번째 사유 — cwd 없는 레코드만 있는 파일(D7)."""
        ok, reason = self.module.classify([rec(gitBranch="work")], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "cwd-missing")

    def test_mixed_cwds_accepted_by_set_predicate(self) -> None:
        """한 파일에 유효·무효 cwd 가 섞이면 **채택**. 단수 술어 구현은 red."""
        ok, reason = self.module.classify(
            [rec(cwd=str(self.box.root / "vanished")), rec(cwd=str(self.box.worktree))],
            self.ours, {})
        self.assertTrue(ok)
        self.assertEqual(reason, "")

    def test_containment_predicate_is_not_used(self) -> None:
        """cwd 가 메인 리포 루트 **아래**인지로 판정하면 안 된다 — 리포 밖 워크트리가 잘린다."""
        outside = self.box.root / "outside-worktree"
        git("worktree", "add", "-q", "-b", "outside", str(outside), cwd=self.box.main)
        ok, _ = self.module.classify([rec(cwd=str(outside))], self.ours, {})
        self.assertTrue(ok)

    def test_git_calls_are_cached_per_cwd(self) -> None:
        """같은 cwd 를 반복 검사하지 않는다(스캔 비용은 git 호출 수가 지배한다)."""
        cache = {}
        records = [rec(cwd=str(self.box.main)) for _ in range(5)]
        self.module.classify(records, self.ours, cache)
        self.assertEqual(len(cache), 1)


class TestNonRecursiveGlob(unittest.TestCase):
    """AC49 — `<sid>/subagents/*.jsonl` 은 구조적으로 제외된다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_subagent_files_are_not_candidates(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        write_jsonl(pdir / "sess.jsonl", [assistant_text("main", gitBranch="work")])
        write_jsonl(pdir / "sess" / "subagents" / "agent-1.jsonl",
                    [assistant_text("sub", gitBranch="work")])
        found = self.module.candidate_paths(str(self.box.main))
        self.assertEqual([Path(p).name for p in found], ["sess.jsonl"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py`
Expected: FAIL — `FileNotFoundError: .../scripts/prepare_standup.py`

- [ ] **Step 3: 스크립트의 첫 절반을 구현한다**

`plugins/agent-transparency/scripts/prepare_standup.py`:

```python
#!/usr/bin/env python3
"""/standup 의 인벤토리 · 코드 상태 준비 스크립트.

**판단은 하지 않는다.** 범위 결정 · 계수 · git 조회만 한다. 대화 본문은 출력에
넣지 않는다 — 본문은 fork 안의 에이전트가 직접 읽는다.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import time

SLUG_RE = re.compile(r"[/.+]")
OUT_OF_SCOPE_LIST_CAP = 20
REJECT_REASONS = ("other-repo", "cwd-gone", "cwd-missing")


def _run(cmd, cwd=None):
    """(rc, stdout). 실패해도 예외를 올리지 않는다."""
    try:
        proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL)
    except OSError:
        return 127, ""
    return proc.returncode, proc.stdout.decode("utf-8", "replace").strip()


def git_common_dir(cwd):
    """정규화된 절대 git-common-dir. 실패면 None.

    `git rev-parse --git-common-dir` 는 **메인 리포에서 상대 경로('.git')** 를
    돌려주고 워크트리에서는 절대 경로를 돌려준다(실측). 두 호출의 결과를
    문자열로 비교하려면 cwd 기준으로 절대화한 뒤 realpath 로 심볼릭 링크까지
    풀어야 한다 — 이 정규화가 없으면 후보 검증이 전부 other-repo 로 떨어진다.
    """
    rc, out = _run(["git", "rev-parse", "--git-common-dir"], cwd=cwd)
    if rc != 0 or not out:
        return None
    return os.path.realpath(os.path.join(cwd, out))


def repo_root(cwd):
    """메인 리포 루트 = git-common-dir 의 부모."""
    common = git_common_dir(cwd)
    return os.path.dirname(common) if common else None


def current_branch(cwd):
    rc, out = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=cwd)
    return out if rc == 0 and out else None


def slug(path):
    """작업 경로 → 프로젝트 디렉토리 이름. 규칙은 문서화돼 있지 않아 실측이다."""
    return SLUG_RE.sub("-", path)


def candidate_paths(root):
    """접두사 글롭. 디렉토리 **바로 아래**만 본다 — `*/subagents/*.jsonl` 은
    이 패턴에 걸리지 않으므로 인벤토리 분모에 들어오지 않는다(AC49).

    접두사를 쓰는 이유: 디렉토리 이름이 작업 경로에서 만들어지고 문서화되지
    않았다. 정확한 이름을 재현하는 대신 접두사로 시작하는 디렉토리를 전부
    대상으로 삼으면 워크트리가 몇 개든 함께 잡힌다.
    """
    pattern = os.path.join(os.path.expanduser("~/.claude/projects"),
                           slug(root) + "*", "*.jsonl")
    return sorted(glob.glob(pattern))


def read_records(path):
    """(레코드 목록, 파싱 실패 줄 수). 파일을 **한 번만** 읽는다."""
    records, unparsed = [], 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except ValueError:
                    unparsed += 1
    except OSError:
        return [], 0
    return records, unparsed


def classify(records, our_common_dir, cache):
    """후보 검증 — (채택, 사유).

    파일에 등장하는 **cwd 값 전체 집합** 중 **하나라도** 우리와 같은
    git-common-dir 를 주면 채택한다. 단수 술어를 쓰면 한 세션이 두 cwd 에
    걸치는 실제 상황(메인 리포 → 워크트리 이동)을 못 다룬다.

    **경로 포함 관계로 판정하지 않는다** — 워크트리는 리포 밖 어디에나 놓인다.
    """
    seen = []
    for record in records:
        value = record.get("cwd")
        if isinstance(value, str) and value and value not in seen:
            seen.append(value)
    if not seen:
        return False, "cwd-missing"
    any_present = False
    for cwd in seen:
        if cwd not in cache:
            cache[cwd] = git_common_dir(cwd) if os.path.isdir(cwd) else None
        if cache[cwd] == our_common_dir:
            return True, ""
        if os.path.isdir(cwd):
            any_present = True
    # 하나도 남아 있지 않으면 삭제·이동된 워크트리다 — 남의 리포와 합산하면
    # 정당한 과거 세션이 조용히 사라진다.
    return False, ("other-repo" if any_present else "cwd-gone")
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py -v`
Expected: PASS (13 tests)

- [ ] **Step 5: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): prepare_standup 경로 해석 + 후보 검증(AC10·AC41·AC49)"
```

---

## Task 6: `prepare_standup.py` — 범위 판정 · 인벤토리 계수 (AC11 · AC34 · AC42)

**Files:**
- Modify: `plugins/agent-transparency/scripts/prepare_standup.py`
- Modify: `plugins/agent-transparency/tests/test_prepare_standup.py`

**Interfaces:**
- Consumes: Task 5 의 `read_records` · `classify` · `candidate_paths`
- Produces:
  - `in_scope(path, records, branch, session_id) -> list[dict]` — 합집합 술어
  - `count(records) -> dict` — 키 `blocks` · `bytes` · `decisions` · `unpaired` · `span_min` · `span_max`
  - `FileEntry` — `dict` 로 표현하며 키는 `path` · `in_scope` · `total` · `span_min` · `span_max` · `label`(`"in-scope"` | `"out-of-scope"`)
  - `collect(root, branch, session_id) -> dict` — 위를 합쳐 `files` · `candidates` · `rejected`(사유별 dict) · `entries` · `unparsed` 를 담은 인벤토리 원자료
- Task 7 의 렌더 함수가 `collect` 의 반환값만 받는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_prepare_standup.py` 에 추가:

```python
def tool_use(name, tool_id, **kw):
    return rec(type="assistant",
               message={"role": "assistant",
                        "content": [{"type": "tool_use", "id": tool_id,
                                     "name": name, "input": {}}]},
               **kw)


def tool_result(tool_id, **kw):
    return rec(type="user",
               message={"role": "user",
                        "content": [{"type": "tool_result", "tool_use_id": tool_id,
                                     "content": "ok"}]},
               **kw)


class TestScopeUnion(unittest.TestCase):
    """AC11 — gitBranch 일치 **OR** 파일명이 세션 id. 합집합이다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_branch_only_and_session_only_both_included(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        # 브랜치만 맞는 파일
        write_jsonl(pdir / "branch-file.jsonl",
                    [assistant_text("b", gitBranch="work", cwd=str(self.box.main))])
        # 세션만 맞는 파일 — gitBranch 는 다른 값
        write_jsonl(pdir / "SID-1234.jsonl",
                    [assistant_text("s", gitBranch="other", cwd=str(self.box.main))])
        data = self.module.collect(str(self.box.main), "work", "SID-1234")
        names = sorted(Path(e["path"]).name for e in data["entries"]
                       if e["label"] == "in-scope")
        self.assertEqual(names, ["SID-1234.jsonl", "branch-file.jsonl"])

    def test_out_of_scope_file_is_labelled_not_dropped(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        write_jsonl(pdir / "elsewhere.jsonl",
                    [assistant_text("x", gitBranch="other", cwd=str(self.box.main))])
        data = self.module.collect(str(self.box.main), "work", "SID-1234")
        labels = [e["label"] for e in data["entries"]]
        self.assertEqual(labels, ["out-of-scope"])


class TestInventoryPredicates(unittest.TestCase):
    """AC34 — 술어를 값으로 못박는다. scan 은 형식만 검증 대상이다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.pdir = self.box.project_dir(self.box.main)
        self.addCleanup(self.box.close)

    def test_known_fixture_yields_exact_numbers(self) -> None:
        cwd = str(self.box.main)
        records = [
            assistant_text("가나다", gitBranch="work", cwd=cwd,          # 9 bytes UTF-8
                           timestamp="2026-08-02T09:11:00.000Z"),
            assistant_text("", gitBranch="work", cwd=cwd),                # 빈 블록 — 안 센다
            assistant_text("abc", gitBranch="work", cwd=cwd,              # 3 bytes
                           timestamp="2026-08-06T22:51:00.000Z"),
            rec(type="assistant", gitBranch="work", cwd=cwd,              # thinking 전용
                message={"role": "assistant",
                         "content": [{"type": "thinking", "thinking": "…"}]}),
            tool_use("AskUserQuestion", "t1", gitBranch="work", cwd=cwd),
            tool_result("t1", gitBranch="work", cwd=cwd),
            tool_use("AskUserQuestion", "t2", gitBranch="work", cwd=cwd), # 짝 없음
            tool_use("Read", "t3", gitBranch="work", cwd=cwd),            # 다른 도구
        ]
        write_jsonl(self.pdir / "s.jsonl", records)
        with (self.pdir / "s.jsonl").open("a", encoding="utf-8") as fh:
            fh.write("{ not json\n")                                      # unparsed 1

        data = self.module.collect(cwd, "work", "s")
        self.assertEqual(data["files"], 1)
        self.assertEqual(data["candidates"], 1)
        self.assertEqual(sum(data["rejected"].values()), 0)
        self.assertEqual(data["blocks"], 2)
        self.assertEqual(data["bytes"], 12)          # '가나다'(9) + 'abc'(3)
        self.assertEqual(data["decisions"], 2)
        self.assertEqual(data["unpaired"], 1)
        self.assertEqual(data["unparsed"], 1)
        self.assertEqual(data["span_min"], "2026-08-02 09:11")
        self.assertEqual(data["span_max"], "2026-08-06 22:51")

    def test_blocks_counts_blocks_not_records(self) -> None:
        """한 레코드에 text 블록이 둘이면 2다. 레코드 수로 세면 red."""
        write_jsonl(self.pdir / "s.jsonl", [
            rec(type="assistant", gitBranch="work", cwd=str(self.box.main),
                message={"role": "assistant",
                         "content": [{"type": "text", "text": "one"},
                                     {"type": "text", "text": "two"}]}),
        ])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["blocks"], 2)

    def test_bytes_is_utf8_length_not_record_length(self) -> None:
        """레코드 직렬화 길이가 아니라 text 문자열의 UTF-8 인코딩 길이 합이다."""
        write_jsonl(self.pdir / "s.jsonl", [
            assistant_text("한글", gitBranch="work", cwd=str(self.box.main)),
        ])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["bytes"], 6)

    def test_rejected_breakdown_by_reason(self) -> None:
        other = self.box.root / "devbrew-experiments"
        make_repo(other, branch="main")
        odir = self.box.project_dir(other)
        write_jsonl(odir / "x.jsonl", [assistant_text("x", gitBranch="main", cwd=str(other))])
        write_jsonl(odir / "y.jsonl",
                    [assistant_text("y", gitBranch="main",
                                    cwd=str(self.box.root / "vanished"))])
        write_jsonl(odir / "z.jsonl", [assistant_text("z", gitBranch="main")])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["rejected"]["other-repo"], 1)
        self.assertEqual(data["rejected"]["cwd-gone"], 1)
        self.assertEqual(data["rejected"]["cwd-missing"], 1)
        self.assertEqual(data["candidates"], 0)


class TestPerFileInScopeCount(unittest.TestCase):
    """AC42 — 파일마다 **그 파일의 in-scope 레코드 수**를 낸다.

    한 세션이 여러 브랜치에 걸치면(이 리포에서 실제로 일어난다) 파일을 통째로
    세는 순간 인벤토리 숫자와 에이전트가 본 것이 어긋난다.
    """

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_mixed_branch_file_reports_in_scope_count(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        cwd = str(self.box.main)
        write_jsonl(pdir / "mixed.jsonl", [
            assistant_text("a", gitBranch="work", cwd=cwd),
            assistant_text("b", gitBranch="work", cwd=cwd),
            assistant_text("c", gitBranch="main", cwd=cwd),
            assistant_text("d", gitBranch="main", cwd=cwd),
            assistant_text("e", gitBranch="main", cwd=cwd),
        ])
        data = self.module.collect(cwd, "work", None)
        entry = data["entries"][0]
        self.assertEqual(entry["in_scope"], 2)
        self.assertEqual(entry["total"], 5)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py`
Expected: FAIL — `AttributeError: module 'prepare_standup' has no attribute 'collect'`

- [ ] **Step 3: 범위·계수를 구현한다**

`scripts/prepare_standup.py` 에 이어 붙인다:

```python
def _fmt_stamp(value):
    """ISO8601 UTC 를 그대로 자른다. 시간대 변환을 하지 않는다 — 원문의 그 지점을
    찾아가는 것이 목적이라 기록된 값과 같아야 한다."""
    if not isinstance(value, str) or len(value) < 16:
        return None
    return value[:16].replace("T", " ")


def in_scope(path, records, branch, session_id):
    """범위 = 레코드의 gitBranch 일치 **OR** 파일명이 현재 세션 id (합집합).

    둘 다 단독으로는 샌다 — 브랜치만 보면 워크트리 이동 전 기록이 빠지고,
    세션만 보면 어제 한 것이 빠진다.
    """
    stem = os.path.basename(path)
    if stem.endswith(".jsonl"):
        stem = stem[: -len(".jsonl")]
    if session_id and stem == session_id:
        return list(records)
    return [r for r in records if r.get("gitBranch") == branch]


def count(records):
    """AC34 의 술어. blocks 는 **레코드가 아니라 블록**을 센다."""
    blocks = nbytes = decisions = 0
    calls, results, stamps = set(), set(), []
    for record in records:
        stamp = _fmt_stamp(record.get("timestamp"))
        if stamp:
            stamps.append(stamp)
        message = record.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            continue
        is_assistant = record.get("type") == "assistant"
        for item in content:
            if not isinstance(item, dict):
                continue
            kind = item.get("type")
            if is_assistant and kind == "text":
                text = item.get("text") or ""
                if text.strip():
                    blocks += 1
                    nbytes += len(text.encode("utf-8"))
            elif kind == "tool_use" and item.get("name") == "AskUserQuestion":
                decisions += 1
                calls.add(item.get("id"))
            elif kind == "tool_result":
                results.add(item.get("tool_use_id"))
    return {
        "blocks": blocks,
        "bytes": nbytes,
        "decisions": decisions,
        # 짝이 없는 호출도 센다(비대화형 실행에는 답변 채널이 없어 실제로 생긴다).
        "unpaired": len([c for c in calls if c not in results]),
        "span_min": min(stamps) if stamps else None,
        "span_max": max(stamps) if stamps else None,
    }


def collect(root, branch, session_id):
    """인벤토리 원자료. 렌더는 하지 않는다."""
    started = time.time()
    ours = git_common_dir(root)
    cache = {}
    rejected = dict((reason, 0) for reason in REJECT_REASONS)
    entries, unparsed, candidates = [], 0, 0
    totals = {"blocks": 0, "bytes": 0, "decisions": 0, "unpaired": 0}
    stamps = []

    for path in candidate_paths(root):
        records, bad = read_records(path)
        accepted, reason = classify(records, ours, cache)
        if not accepted:
            rejected[reason] = rejected.get(reason, 0) + 1
            continue
        candidates += 1
        unparsed += bad
        mine = in_scope(path, records, branch, session_id)
        stats = count(mine)
        whole = count(records)
        for key in totals:
            totals[key] += stats[key]
        for value in (stats["span_min"], stats["span_max"]):
            if value:
                stamps.append(value)
        entries.append({
            "path": path,
            "in_scope": len(mine),
            "total": len(records),
            # in-scope 블록은 in-scope 기간, out-of-scope 블록은 파일 전체 기간을 보여준다.
            "span_min": stats["span_min"] if mine else whole["span_min"],
            "span_max": stats["span_max"] if mine else whole["span_max"],
            "label": "in-scope" if mine else "out-of-scope",
        })

    data = dict(totals)
    data.update({
        "files": len([e for e in entries if e["label"] == "in-scope"]),
        "candidates": candidates,
        "rejected": rejected,
        "entries": entries,
        "unparsed": unparsed,
        "span_min": min(stamps) if stamps else None,
        "span_max": max(stamps) if stamps else None,
        "scan": time.time() - started,
        "git_calls": len(cache),
    })
    return data
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py -v`
Expected: PASS (20 tests)

- [ ] **Step 5: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): 범위 합집합 + 인벤토리 술어(AC11·AC34·AC42)"
```

---

## Task 7: `prepare_standup.py` — 출력 렌더 · git 블록 · 실패 경로 (AC46 · AC20)

**Files:**
- Modify: `plugins/agent-transparency/scripts/prepare_standup.py`
- Modify: `plugins/agent-transparency/tests/test_prepare_standup.py`

**Interfaces:**
- Consumes: Task 6 의 `collect`
- Produces:
  - `render_inventory(root, branch, session_id, data) -> str` — `scope:` 줄 + 인벤토리 2줄 + 파일 목록 **세 블록**
  - `render_code_state(cwd) -> str` — `## 코드 상태` 블록
  - `main(argv) -> int` — 종료 코드 `0` 정상 · `3` 대상 파일 0개 · `4` 내부 오류
- Task 8 의 `SKILL.md` 가 `scope:` 줄을 **가용성 센티널**로 쓴다 — 그 줄이 없으면 답하지 않는다.

**계약상 확정 두 가지** (spec 예시와 다른 점을 여기서 못박는다):
1. `rejected:` 는 **항상 사유별 내역을 함께 낸다**(`rejected: 0 (other-repo: 0, cwd-gone: 0, cwd-missing: 0)`). spec §6.3 계약 행이 규범이고 §6.3 예시의 `rejected: 0` 은 예시다 — 조건부 표기는 파싱하는 쪽에서 두 형식을 다뤄야 한다.
2. **세 블록의 라벨 헤더는 비어 있어도 낸다.** AC46 이 *"각 블록이 라벨 헤더를 가진다"* 를 요구하므로, 0개일 때 라벨을 생략하면 그 요구가 데이터에 따라 참·거짓이 갈린다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_prepare_standup.py` 에 추가:

```python
class TestRender(unittest.TestCase):
    """AC46 — scope 줄 + 세 블록 + listed. 라벨·수·기간이 계약대로."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.pdir = self.box.project_dir(self.box.main)
        self.addCleanup(self.box.close)

    def render(self, session_id=None):
        data = self.module.collect(str(self.box.main), "work", session_id)
        return self.module.render_inventory(str(self.box.main), "work", session_id, data)

    def test_scope_line_has_three_fields(self) -> None:
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        first = self.render().splitlines()[0]
        self.assertTrue(first.startswith("scope:"))
        for field in ("repo=", "branch=", "+session="):
            self.assertIn(field, first)

    def test_three_block_labels_always_present(self) -> None:
        """빈 블록도 라벨을 낸다 — 데이터에 따라 계약이 갈리면 안 된다."""
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        out = self.render()
        self.assertIn("in-scope — ", out)
        self.assertIn("out-of-scope — ", out)
        self.assertIn("out-of-scope 디렉토리 집계 — ", out)

    def test_in_scope_lines_carry_count_and_span(self) -> None:
        write_jsonl(self.pdir / "mixed.jsonl", [
            assistant_text("a", gitBranch="work", cwd=str(self.box.main),
                           timestamp="2026-08-02T09:11:00.000Z"),
            assistant_text("b", gitBranch="main", cwd=str(self.box.main),
                           timestamp="2026-08-06T22:51:00.000Z"),
        ])
        line = [ln for ln in self.render().splitlines() if "mixed.jsonl" in ln][0]
        self.assertIn("1건", line)              # 전체 2가 아니라 in-scope 1
        self.assertIn("2026-08-02 09:11", line)

    def test_out_of_scope_capped_at_twenty_and_listed_reflects_it(self) -> None:
        """후보 25개 → out-of-scope 줄 20개 + listed 가 잘림을 반영."""
        for i in range(25):
            write_jsonl(self.pdir / ("f%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                        timestamp="2026-08-%02dT10:00:00.000Z" % (i + 1))])
        out = self.render()
        listed_lines = [ln for ln in out.splitlines() if ln.startswith("  ") and ".jsonl" in ln]
        self.assertEqual(len(listed_lines), 20)
        self.assertIn("listed: 20", out)

    def test_directory_rollup_line_present_when_truncated(self) -> None:
        for i in range(25):
            write_jsonl(self.pdir / ("f%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main))])
        out = self.render()
        rollup = out.split("out-of-scope 디렉토리 집계")[1]
        self.assertIn("5개", rollup)            # 25 - 20 = 5

    def test_rejected_breakdown_is_always_rendered(self) -> None:
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        out = self.render()
        for reason in ("other-repo:", "cwd-gone:", "cwd-missing:"):
            self.assertIn(reason, out)

    def test_no_conversation_body_in_output(self) -> None:
        """출력에 없는 것 — 대화 본문 일체."""
        write_jsonl(self.pdir / "s.jsonl", [
            assistant_text("비밀문장-DO-NOT-LEAK", gitBranch="work",
                           cwd=str(self.box.main)),
        ])
        self.assertNotIn("비밀문장-DO-NOT-LEAK", self.render())

    def test_scan_format_only(self) -> None:
        """scan 은 정확값이 아니라 형식만 검증 대상이다 — 음수 아닌 수 + `s`."""
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        value = self.render().split("scan:")[1].split()[0]
        self.assertTrue(value.endswith("s"), value)
        self.assertGreaterEqual(float(value[:-1]), 0.0)


class TestCodeState(unittest.TestCase):
    """AC20 — 코드 상태는 트랜스크립트가 아니라 git 에서 온다(양방향)."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_positive_git_present(self) -> None:
        """D8 양의 짝 — git 이 있으면 실제 log/diff 결과가 들어간다."""
        (self.box.main / "new.txt").write_text("x\n", encoding="utf-8")
        git("add", "-A", cwd=self.box.main)
        git("commit", "-qm", "add new.txt", cwd=self.box.main)
        block = self.module.render_code_state(str(self.box.main))
        self.assertIn("## 코드 상태", block)
        self.assertIn("add new.txt", block)
        self.assertNotIn("git 조회 실패", block)

    def test_negative_git_absent(self) -> None:
        """git 없는 픽스처 — 그 자리에 한 줄이 들어가고 인벤토리는 정상."""
        plain = self.box.root / "not-a-repo"
        plain.mkdir()
        block = self.module.render_code_state(str(plain))
        self.assertIn("## 코드 상태", block)
        self.assertIn("git 조회 실패", block)


class TestExitCodes(unittest.TestCase):
    """종료 코드 0 / 3 / 4 + 실패 시 STANDUP-UNAVAILABLE 한 줄."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.addCleanup(self.box.close)

    def run_script(self, cwd, session_id="none", env=None):
        merged = dict(os.environ)
        merged["HOME"] = str(self.box.home)
        merged.update(env or {})
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--session-id", session_id],
            cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=merged)
        return proc.returncode, proc.stdout.decode("utf-8")

    def test_no_target_files_exits_three(self) -> None:
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 3)
        self.assertTrue(out.startswith("STANDUP-UNAVAILABLE: session file not found"))
        self.assertIn("~/.claude/projects", out)

    def test_normal_run_exits_zero(self) -> None:
        module = load_script()
        pdir = self.box.projects / module.slug(str(self.box.main))
        pdir.mkdir(parents=True, exist_ok=True)
        write_jsonl(pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith("scope:"))
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py`
Expected: FAIL — `AttributeError: … has no attribute 'render_inventory'`

- [ ] **Step 3: 렌더와 진입점을 구현한다**

`scripts/prepare_standup.py` 에 이어 붙인다:

```python
def _kb(nbytes):
    return "%.1f KB" % (nbytes / 1024.0)


def _span(low, high):
    if not low or not high:
        return "(기간 없음)"
    return "%s ~ %s" % (low, high)


def render_inventory(root, branch, session_id, data):
    """scope 줄 + 인벤토리 2줄 + 파일 목록 세 블록.

    `scope:` 줄은 장식이 아니다 — SKILL.md 가 범위 대조에도(branch·+session)
    가용성 센티널에도(그 줄이 없으면 답하지 않는다) 쓴다.
    """
    in_scope_entries = [e for e in data["entries"] if e["label"] == "in-scope"]
    others = sorted([e for e in data["entries"] if e["label"] == "out-of-scope"],
                    key=lambda e: (e["span_max"] or "", e["path"]), reverse=True)
    shown, folded = others[:OUT_OF_SCOPE_LIST_CAP], others[OUT_OF_SCOPE_LIST_CAP:]
    listed = len(in_scope_entries) + len(shown)

    rejected_total = sum(data["rejected"].values())
    breakdown = ", ".join("%s: %d" % (r, data["rejected"].get(r, 0))
                          for r in REJECT_REASONS)
    lines = [
        "scope:   repo=%s  branch=%s  +session=%s" % (root, branch, session_id or "-"),
        "files:   %d (candidates: %d  rejected: %d (%s)  listed: %d)   "
        "blocks: %d (%s)   decisions: %d (unpaired: %d)"
        % (data["files"], data["candidates"], rejected_total, breakdown, listed,
           data["blocks"], _kb(data["bytes"]), data["decisions"], data["unpaired"]),
        "span:    %s   commits: %d   scan: %.1fs   unparsed: %d"
        % (_span(data["span_min"], data["span_max"]), data.get("commits", 0),
           data["scan"], data["unparsed"]),
        "",
        # 세 라벨은 **비어 있어도** 낸다 — 데이터에 따라 계약이 갈리면 안 된다.
        "in-scope — %d개 전량:" % len(in_scope_entries),
    ]
    for entry in in_scope_entries:
        lines.append("  %s   %d건  %s"
                     % (entry["path"], entry["in_scope"],
                        _span(entry["span_min"], entry["span_max"])))
    lines.append("out-of-scope — %d개 중 최근 %d개:" % (len(others), len(shown)))
    for entry in shown:
        lines.append("  %s   [%d건]  %s"
                     % (entry["path"], entry["total"],
                        _span(entry["span_min"], entry["span_max"])))

    rollup = {}
    for entry in folded:
        directory = os.path.dirname(entry["path"])
        bucket = rollup.setdefault(directory, {"n": 0, "low": None, "high": None})
        bucket["n"] += 1
        for key, value in (("low", entry["span_min"]), ("high", entry["span_max"])):
            if value and (bucket[key] is None
                          or (value < bucket[key] if key == "low" else value > bucket[key])):
                bucket[key] = value
    lines.append("out-of-scope 디렉토리 집계 — %d개 (위 %d개를 뺀 나머지 %d개):"
                 % (len(rollup), len(shown), len(folded)))
    for directory in sorted(rollup):
        bucket = rollup[directory]
        lines.append("  %s   %d개  %s"
                     % (directory, bucket["n"],
                        _span((bucket["low"] or "")[:10], (bucket["high"] or "")[:10])))
    return "\n".join(lines)


def base_ref(cwd):
    """origin/main 우선, 없으면 main. 둘 다 실패면 None."""
    for ref in ("origin/main", "main"):
        rc, out = _run(["git", "merge-base", "HEAD", ref], cwd=cwd)
        if rc == 0 and out:
            return out
    return None


def render_code_state(cwd):
    """한 재료가 죽어도 나머지는 산다. 빈 절을 조용히 두지 않는다."""
    lines = ["## 코드 상태", ""]
    base = base_ref(cwd)
    if base:
        commands = [
            ["git", "log", "--oneline", "%s..HEAD" % base],
            ["git", "diff", "--stat", "%s..HEAD" % base],
        ]
    else:
        lines.append("(base-ref 를 구하지 못해 최근 20개 커밋으로 강등)")
        commands = [["git", "log", "--oneline", "-20"]]
    commands += [["git", "status", "--short"],
                 ["git", "diff", "--stat"],
                 ["git", "diff", "--cached", "--stat"]]
    for command in commands:
        rc, out = _run(command, cwd=cwd)
        label = " ".join(command)
        if rc != 0:
            lines.append("(git 조회 실패: %s, %d)" % (label, rc))
            continue
        lines.append("$ %s" % label)
        lines.append(out if out else "(없음)")
        lines.append("")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(add_help=False)
    # 사용자 유래 인자는 받지 않는다 — 범위 조정은 「범위 라벨」로 에이전트가 수행한다.
    parser.add_argument("--session-id", default=os.environ.get("CLAUDE_CODE_SESSION_ID"))
    args = parser.parse_args(argv)
    try:
        cwd = os.getcwd()
        root = repo_root(cwd)
        if not root:
            sys.stdout.write("STANDUP-UNAVAILABLE: not a git repository (%s)\n" % cwd)
            return 3
        branch = current_branch(cwd) or "(unknown)"
        data = collect(root, branch, args.session_id)
        if not data["entries"]:
            sys.stdout.write(
                "STANDUP-UNAVAILABLE: session file not found "
                "(~/.claude/projects/%s*/*.jsonl)\n" % slug(root))
            return 3
        rc, out = _run(["git", "log", "--oneline",
                        "%s..HEAD" % (base_ref(cwd) or "HEAD")], cwd=cwd)
        data["commits"] = len([ln for ln in out.splitlines() if ln.strip()]) if rc == 0 else 0
        sys.stdout.write(render_inventory(root, branch, args.session_id, data))
        sys.stdout.write("\n\n")
        sys.stdout.write(render_code_state(cwd))
        sys.stdout.write("\n")
        return 0
    except Exception as exc:
        sys.stdout.write("STANDUP-UNAVAILABLE: internal error (%s)\n" % exc)
        return 4


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py -v`
Expected: PASS (32 tests)

- [ ] **Step 5: 실물에서 한 번 돌려 본다** — 스위트가 아니라 **바깥 세계와의 일치**를 보는 단계다. 이 계획을 만든 사이클의 교훈이 *"같은 가드가 세 판 연속 틀렸고 셋 다 실행이 잡았다"* 였다.

```bash
CLAUDE_CODE_SESSION_ID="$(basename "$(ls -t ~/.claude/projects/*/*.jsonl | head -1)" .jsonl)" \
  python3 plugins/agent-transparency/scripts/prepare_standup.py | head -20
```
Expected: `scope:` 줄이 나오고 `files:` 가 0이 아니며 `rejected:` 내역 셋이 모두 보인다. `files: 0` 이면 슬러그 규칙이나 후보 검증이 실물에서 틀린 것이다 — 픽스처가 아니라 구현을 고친다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): 인벤토리 렌더 + 코드 상태 + 종료 코드(AC46·AC20)"
```

---

## Task 8: `/standup` skill · command · 가독성 파리티 (AC16① · AC27 · AC28 · AC35①–⑤ · AC43 · AC51)

**Files:**
- Create: `plugins/agent-transparency/skills/briefing-current-state/SKILL.md`
- Create: `plugins/agent-transparency/commands/standup.md`
- Create: `plugins/agent-transparency/tests/test_readability_parity.py`
- Modify: `plugins/agent-transparency/tests/test_plugin_contract.py`

**Interfaces:**
- Consumes: Task 2 의 다섯 규칙 앵커 · Task 4 의 agent 이름 · Task 7 의 `scope:` 줄 계약
- Produces: skill 이름 `briefing-current-state` — command 본문이 `Skill agent-transparency:briefing-current-state $ARGUMENTS` 로 부른다.

**AC35 는 여섯 조각인데 이 task 는 ①–⑤ 만 덮는다.** ⑥(`tests/probe/skill_body.txt`)은 실물 측정이 있어야 하므로 Task 12 다. 조각을 나눠 배정하는 것이 AC47 이 요구하는 형태다 — 번호 단위로 두면 미측정 조각이 커버리지 계산에서 사라진다.

- [ ] **Step 1: 실패하는 테스트를 쓴다 (파리티)**

`plugins/agent-transparency/tests/test_readability_parity.py`:

```python
#!/usr/bin/env python3
"""AC28 — output style `## Vocabulary` ↔ SKILL.md `## 쓰는 방식` 다섯 규칙 파리티.

**이 검사의 한계를 여기 적는다**: 순수 unittest 가 영어 산문과 한국어 산문의
의미 대응을 판정할 수는 없다. 그래서 두 파일에 **규칙마다 주석 앵커**를 달고,
테스트는 **다섯 앵커가 양쪽에 모두 있는지**만 본다. 산문 일치는 사람 리뷰이고,
이 검사가 잡는 것은 *한쪽에서 규칙이 통째로 사라지는 것*뿐이다.

규칙이 살 수 있는 자리는 셋(output style · SKILL.md · agent 정의)인데 이 검사는
둘만 본다. 세 번째 사본을 만드는 편집이 오면 이 파일의 좌우변부터 늘려야 한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_readability_parity.py
"""
from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
STYLE = PLUGIN_DIR / "output-styles" / "agent-transparency.md"
SKILL = PLUGIN_DIR / "skills" / "briefing-current-state" / "SKILL.md"
AGENT = PLUGIN_DIR / "agents" / "transcript-reader.md"

ANCHORS = ("<!-- rule:jargon -->", "<!-- rule:pointer -->",
           "<!-- rule:standard-term -->", "<!-- rule:analogy -->",
           "<!-- rule:no-assumed-knowledge -->")


class TestFiveRuleParity(unittest.TestCase):
    def setUp(self) -> None:
        self.style = STYLE.read_text(encoding="utf-8")
        self.skill = SKILL.read_text(encoding="utf-8")

    def test_all_five_anchors_on_both_sides(self) -> None:
        for anchor in ANCHORS:
            self.assertIn(anchor, self.style, "output style 에 %s 없음" % anchor)
            self.assertIn(anchor, self.skill, "SKILL.md 에 %s 없음" % anchor)

    def test_anchor_sets_are_equal(self) -> None:
        """한쪽에만 있는 앵커가 있으면 red — 좌우변이 갈리는 것을 잡는다."""
        left = {a for a in ANCHORS if a in self.style}
        right = {a for a in ANCHORS if a in self.skill}
        self.assertEqual(left, right)

    def test_no_third_copy_in_agent_definition(self) -> None:
        """세 번째 사본 금지 — 파리티가 못 보는 자리에 규칙을 두지 않는다."""
        agent = AGENT.read_text(encoding="utf-8")
        for anchor in ANCHORS:
            self.assertNotIn(anchor, agent)

    def test_mutation_rule_removed_from_one_side(self) -> None:
        """SKILL.md 에서 한 규칙이 사라지면 red."""
        mutated = self.skill.replace("<!-- rule:pointer -->", "")
        left = {a for a in ANCHORS if a in self.style}
        right = {a for a in ANCHORS if a in mutated}
        self.assertNotEqual(left, right)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패하는 테스트를 쓴다 (계약)**

`tests/test_plugin_contract.py` 에 추가:

```python
SKILL_REL = "skills/briefing-current-state/SKILL.md"


def frontmatter(text: str) -> dict:
    """`key: value` 만 뽑는 최소 파서 — 이 파일들은 중첩 구조를 쓰지 않는다."""
    block = text.split("---", 2)[1]
    out = {}
    for line in block.splitlines():
        if ":" in line and not line.startswith(" "):
            key, value = line.split(":", 1)
            out[key.strip()] = value.strip()
    return out


class TestSkillFrontmatter(unittest.TestCase):
    """AC27 — cost_class **값이 variable** · context: fork · agent · background."""

    def setUp(self) -> None:
        self.meta = frontmatter(read(SKILL_REL))

    def test_cost_class_is_variable(self) -> None:
        """`low` 면 red — 같은 절이 '읽는 양에 상한을 걸지 않는다' 고 명시하므로
        상한 없는 탐색은 정의상 variable 이다."""
        self.assertEqual(self.meta.get("cost_class"), "variable")

    def test_context_is_fork(self) -> None:
        self.assertEqual(self.meta.get("context"), "fork")

    def test_agent_points_at_dedicated_reader(self) -> None:
        """`Explore` 면 red — 훅이 자기 fork 를 구분할 수 없게 된다."""
        self.assertEqual(self.meta.get("agent"), "agent-transparency:transcript-reader")

    def test_background_is_false(self) -> None:
        self.assertEqual(self.meta.get("background"), "false")


class TestSkillTranscriptFacts(unittest.TestCase):
    """AC35①–⑤ — 세 트랜스크립트 사실 · 「읽지 않는 것」 · 표본 하한.

    ⑥(tests/probe/skill_body.txt)은 실물 측정이 필요해 별도 배정이다.
    앞선 판에서 이것들은 추출기 **코드**에 있었다 — 코드가 사라졌으므로
    검사 대상이 지시문으로 옮겨갔다.
    """

    FRAGMENTS = {
        "①-세-레코드-타입": ['type=="user"', 'type=="queue-operation"',
                              'attachment.type=="queued_command"'],
        "②-last-prompt-제외": ['type=="last-prompt"'],
        "③-텍스트-없는-레코드-건너뛰기": ["텍스트 없는 레코드를 건너뛴다"],
        "④-읽지-않는-것": ["`Bash` 명령 문자열", "파일 내용", "`tool_result` 본문",
                            "에이전트 반환값 본문", "subagents/*.jsonl"],
        "⑤-표본-하한": ["가장 최근 블록", "모든 `AskUserQuestion` 호출과 그 짝",
                        "하한이지 상한이 아니다"],
    }

    def setUp(self) -> None:
        self.text = read(SKILL_REL)

    def test_all_fragments_present(self) -> None:
        for name, fragments in self.FRAGMENTS.items():
            for fragment in fragments:
                self.assertIn(fragment, self.text, "%s: %s" % (name, fragment))

    def test_mutation_each_fragment_removal_is_detected(self) -> None:
        """하나를 지우면 red — 항목별로 확인한다."""
        for name, fragments in self.FRAGMENTS.items():
            mutated = self.text.replace(fragments[0], "")
            self.assertNotIn(fragments[0], mutated, name)

    def test_ask_user_question_exception_is_scoped(self) -> None:
        """예외는 AskUserQuestion 하나뿐이고 다른 tool_result 는 계속 배제된다."""
        self.assertIn("다른 어떤 도구의 `tool_result` 도 계속 전부 배제한다", self.text)


class TestQuotePreservation(unittest.TestCase):
    """AC16① — 문구 보존 요구와 `(미답)` 표기가 **둘 다** 있다(mutation).

    ②(실제 산출의 정확성)는 런타임 신호가 게이트 5a 뿐이고 고른 라벨 보존은
    실물로 측정되지 않는다 — OQ-AA.
    """

    def setUp(self) -> None:
        self.text = read(SKILL_REL)

    def test_verbatim_requirement(self) -> None:
        self.assertIn("한 글자도 바꾸지 않는다", self.text)

    def test_unanswered_marker(self) -> None:
        self.assertIn("(미답)", self.text)

    def test_mutation_either_side_removed(self) -> None:
        for fragment in ("한 글자도 바꾸지 않는다", "(미답)"):
            self.assertNotIn(fragment, self.text.replace(fragment, ""))


class TestNoShellInjectionPath(unittest.TestCase):
    """AC43 — 사용자 문자열이 셸에 도달하는 경로가 없다."""

    EXPANSIONS = ("$ARGUMENTS", "${ARGUMENTS", "$1", "$@", "$*", "$USER_INPUT")

    def test_dynamic_context_line_is_a_fixed_string(self) -> None:
        line = [ln for ln in read(SKILL_REL).splitlines() if ln.strip().startswith("!`")]
        self.assertEqual(len(line), 1, "동적 컨텍스트 주입 줄이 정확히 1개여야 한다")
        for token in self.EXPANSIONS:
            self.assertNotIn(token, line[0])

    def test_script_takes_no_user_argument(self) -> None:
        script = (PLUGIN_DIR / "scripts" / "prepare_standup.py").read_text(encoding="utf-8")
        self.assertIn('add_argument("--session-id"', script)
        # 위치 인자를 받으면 사용자 유래 값이 들어올 수 있다.
        self.assertNotIn('add_argument("scope"', script)

    def test_shell_metacharacter_payload_has_no_effect(self) -> None:
        """통합 검사 — 메타문자를 인자로 넣어도 부수효과가 없다."""
        import tempfile as _tf
        with _tf.TemporaryDirectory() as tmp:
            canary = Path(tmp) / "pwn"
            proc = subprocess.run(
                [sys.executable, str(PLUGIN_DIR / "scripts" / "prepare_standup.py"),
                 "--session-id", "; touch %s" % canary],
                cwd=tmp, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertFalse(canary.exists())
            self.assertIn(proc.returncode, (0, 3, 4))


class TestCommandFile(unittest.TestCase):
    """AC51 (D7 신설) — commands/standup.md 의 본문을 직접 검증한다.

    AC39 는 이름 충돌, AC40 은 러너, AC43 은 SKILL.md 를 보므로 이 glue 파일의
    오타·스킬명 오기·$ARGUMENTS 누락은 어떤 테스트도 안 거쳤다.
    """

    def setUp(self) -> None:
        self.text = read("commands/standup.md")

    def test_frontmatter_has_description(self) -> None:
        self.assertTrue(frontmatter(self.text).get("description"))

    def test_body_invokes_the_skill_by_namespaced_name(self) -> None:
        self.assertIn("Skill agent-transparency:briefing-current-state $ARGUMENTS",
                      self.text)

    def test_skill_name_actually_exists(self) -> None:
        """스킬명 오기를 잡는다 — 이름이 실제 디렉토리와 맞는지."""
        self.assertTrue((PLUGIN_DIR / SKILL_REL).is_file())
        self.assertEqual(frontmatter(read(SKILL_REL)).get("name"),
                         "briefing-current-state")

    def test_arguments_flow_as_prompt_text_only(self) -> None:
        """$ARGUMENTS 가 셸 호출 안에 있으면 red — 프롬프트 텍스트로만 흐른다."""
        for line in self.text.splitlines():
            if "$ARGUMENTS" in line:
                self.assertFalse(line.strip().startswith("!`"), line)
                self.assertNotIn("bash", line.lower())
```

파일 상단 import 에 `subprocess` · `sys` · `from pathlib import Path` 가 이미 있어야 한다. Task 1 에서 만든 헤더에 없으면 추가한다.

- [ ] **Step 3: 실패를 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_readability_parity.py
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
```
Expected: 둘 다 FAIL — `FileNotFoundError: .../skills/briefing-current-state/SKILL.md`

- [ ] **Step 4: skill 을 만든다**

`plugins/agent-transparency/skills/briefing-current-state/SKILL.md` — **spec §6.3 「skill 전문」 코드펜스 안(spec 파일 963–1054줄)을 한 글자도 바꾸지 않고 그대로.**

```bash
mkdir -p plugins/agent-transparency/skills/briefing-current-state
sed -n '963,1054p' docs/superpowers/specs/2026-08-05-agent-transparency-design.md \
  > plugins/agent-transparency/skills/briefing-current-state/SKILL.md
head -12 plugins/agent-transparency/skills/briefing-current-state/SKILL.md
grep -c 'rule:' plugins/agent-transparency/skills/briefing-current-state/SKILL.md
```
Expected: 첫 줄 `---`, `name: briefing-current-state`, `cost_class: variable`, `context: fork`, `agent: agent-transparency:transcript-reader` 가 보이고 `rule:` 앵커가 **5개**.

- [ ] **Step 5: command 를 만든다**

`plugins/agent-transparency/commands/standup.md` — 진입점만. 절차는 skill 이 소유한다:

```markdown
---
description: "지금 이 작업이 어떤 상태인가 — 코드가 무엇이 됐고, 무엇이 열려 있고, 왜 그렇게 됐는지를 대화 기록과 git 에서 꺼낸다."
argument-hint: "[범위 조정 — 예: \"main 브랜치도 같이\" · \"최근 3일만\"]"
---

# standup

Skill agent-transparency:briefing-current-state $ARGUMENTS

`$ARGUMENTS` 는 **프롬프트 텍스트로만** 흐른다 — 셸에 도달하는 경로가 없다.
범위 조정은 에이전트가 인벤토리의 `in-scope` / `out-of-scope` 라벨을 보고 수행한다.
```

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_readability_parity.py -v
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py -v
```
Expected: 파리티 4 tests PASS · 계약 PASS. `test_all_fragments_present` 가 실패하면 spec 에서 복사한 문자열과 테스트가 기대하는 문자열이 다른 것이다 — **테스트가 아니라 복사를 확인한다**(SKILL.md 는 spec 이 정본이다).

- [ ] **Step 7: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): /standup skill + command + 가독성 파리티(AC16①·AC27·AC28·AC35①-⑤·AC43·AC51)"
```

---

## Task 9: `REFERENCE.md` 정본 (AC32 · AC33 · AC47)

**Files:**
- Create: `plugins/agent-transparency/REFERENCE.md`
- Create: `plugins/agent-transparency/tests/test_ab_runner_contract.py`
- Modify: `plugins/agent-transparency/tests/test_plugin_contract.py` (AC32 · AC33)

**Interfaces:**
- Consumes: 없음
- Produces: `REFERENCE.md` 의 여섯 절 — `## AC 번호 목록` · `## AC ↔ 검증 산출물` · `## 미해결(OQ) 식별자 목록` · `## 루브릭` (A·B·C·D) · `## 게이트 표` · `## 판정 구간 표`. **Task 12 의 `ab_judge.py` 가 루브릭을 이 파일에서 읽는다** — 사본을 코드에 박으면 정본이 둘이 된다.

**왜 정본이 플러그인 안인가:** 배포되는 것은 `plugins/agent-transparency/` 이고 설계 문서는 그 안에 없다. 설치 환경이나 CI 에서 경로가 깨지거나 문서가 옮겨지면 조용히 stale 해진다. **AC47 은 이 파일만 읽는다** — 설계 문서 §12 를 확인하게 하면 배포되지 않는 파일을 파싱하게 되어 정본을 옮긴 이유가 그대로 무너진다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/agent-transparency/tests/test_ab_runner_contract.py`:

```python
#!/usr/bin/env python3
"""AC40 · AC45 · AC47 — A/B 러너 계약과 AC 커버리지.

`ab_gate.sh` **전체는 실행하지 않는다**(워커가 claude 를 부르므로 비용·비결정).
단 순수-python 가드 스니펫은 **추출해 JSON 픽스처로 실제 실행**한다 —
문자열 검사로는 그 판정 로직의 세 판을 구분하지 못한다.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
REFERENCE = PLUGIN_DIR / "REFERENCE.md"

AC_ROW = re.compile(r"^\s*-\s+(AC\d+(?:[①②③④⑤⑥])?)\s*$")
ASSIGN_ROW = re.compile(r"^\|\s*(AC\d+(?:[①②③④⑤⑥])?)\s*\|\s*([^|]+?)\s*\|")
OQ_ROW = re.compile(r"^\s*-\s+(OQ-[A-Z]+)\s*(?:—|$)")


def section(text: str, heading: str) -> str:
    """`## <heading>` 부터 다음 `## ` 까지."""
    start = text.index("## " + heading)
    rest = text[start + 3:]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]


class TestCoverageLedger(unittest.TestCase):
    """AC47 — 모든 AC 가, 쪼개진 것은 그 조각까지, 검증 산출물에 배정돼 있다.

    **`REFERENCE.md` 한 파일만** 파싱한다. 설계 문서도 §8 트리도 읽지 않는다 —
    배포되지 않는 파일에 의존하면 정본을 옮긴 이유 그대로 stale 해진다.
    """

    def setUp(self) -> None:
        self.text = REFERENCE.read_text(encoding="utf-8")
        self.listed = {m.group(1) for m in
                       (AC_ROW.match(ln) for ln in
                        section(self.text, "AC 번호 목록").splitlines()) if m}
        self.assigned = {}
        for line in section(self.text, "AC ↔ 검증 산출물").splitlines():
            match = ASSIGN_ROW.match(line)
            if match and match.group(1) != "AC":
                self.assigned[match.group(1)] = match.group(2).strip()
        self.oqs = {m.group(1) for m in
                    (OQ_ROW.match(ln) for ln in
                     section(self.text, "미해결(OQ) 식별자 목록").splitlines()) if m}

    def test_lists_are_non_trivial(self) -> None:
        """계측기 자체가 고장 나면 빈 집합끼리 같아서 통과한다 — 먼저 막는다."""
        self.assertGreaterEqual(len(self.listed), 38)
        self.assertGreaterEqual(len(self.oqs), 20)

    def test_symmetric_difference_is_empty(self) -> None:
        self.assertEqual(self.listed - set(self.assigned), set(),
                         "목록에 있는데 배정이 없다")
        self.assertEqual(set(self.assigned) - self.listed, set(),
                         "배정에 있는데 목록에 없다")

    # NOTE: 배정된 **산출물이 실제로 존재하는지**를 보는 assertion 은 Task 11 에서
    # 더한다. 여기서 더하면 `tests/ab_gate.sh` · `tests/oracle/` 가 아직 없어
    # Task 9·10 이 red 로 끝나고, "각 task 는 독립적으로 테스트 가능한 산출물로
    # 끝난다" 는 규칙이 깨진다. 배정표의 **좌변 집합**은 여기서 이미 잠긴다.

    def test_unassigned_fragments_cite_a_real_oq(self) -> None:
        """`없음` 이 만능 탈출구가 되면 이 AC 자체가 새 fail-open 이 된다."""
        for ac, target in self.assigned.items():
            if not target.startswith("없음"):
                continue
            cited = re.findall(r"OQ-[A-Z]+", target)
            self.assertTrue(cited, "%s: 없음인데 OQ 식별자가 없다" % ac)
            for oq in cited:
                self.assertIn(oq, self.oqs, "%s 가 인용한 %s 가 목록에 없다" % (ac, oq))

    def test_split_ac_is_listed_by_fragment(self) -> None:
        """AC16 은 조각 단위로 오른다 — 번호 단위로 두면 실물 미측정 조각이
        차집합에 안 나타나 커버리지가 100%로 보고된다(이 AC 가 만들어진 계기)."""
        self.assertIn("AC16①", self.listed)
        self.assertIn("AC16②", self.listed)
        self.assertNotIn("AC16", self.listed)


class TestRubrics(unittest.TestCase):
    """AC32 좌변 — 루브릭 네 종 · 각 4문항. (게이트 표의 판정 방식은 계약 테스트.)"""

    def setUp(self) -> None:
        self.text = REFERENCE.read_text(encoding="utf-8")

    def test_four_rubrics_each_with_four_questions(self) -> None:
        for name in ("루브릭 A", "루브릭 B", "루브릭 C", "루브릭 D"):
            block = section(self.text, name)
            questions = re.findall(r"(?m)^\s*Q[1-4]\.", block)
            self.assertEqual(len(questions), 4, name)


if __name__ == "__main__":
    unittest.main()
```

`tests/test_plugin_contract.py` 에 추가:

```python
class TestReferenceIsNormative(unittest.TestCase):
    """AC32 우변 · AC33 — 게이트 표의 판정 방식과 5a·5b 의 판정 대상."""

    def setUp(self) -> None:
        self.text = read("REFERENCE.md")

    def test_gate_table_declares_rubric_for_3_4_5b_6(self) -> None:
        rows = [ln for ln in self.text.splitlines() if ln.startswith("| ")]
        for gate in ("| 3 ", "| 4 ", "| 5b ", "| 6 "):
            row = [ln for ln in rows if ln.startswith(gate)]
            self.assertTrue(row, gate)
            self.assertIn("루브릭", row[0])

    def test_no_count_based_gate_wording_remains(self) -> None:
        """개수 기반 문구가 남아 있으면 red — 굵은 문구 넷을 세는 검사는
        무관한 굵은 문구 넷으로도 통과한다."""
        for banned in ("굵은 라벨 개수", "라벨 4개 이상", "볼드 개수"):
            self.assertNotIn(banned, self.text)

    def test_gate_5a_and_5b_exist(self) -> None:
        """AC33 — 두 행이 있고 판정 구간 표에 `/standup` 행이 있다."""
        self.assertIn("| 5a ", self.text)
        self.assertIn("| 5b ", self.text)
        self.assertIn("/standup", section_of(self.text, "판정 구간 표"))

    def test_standup_verdict_is_not_script_stdout(self) -> None:
        """`/standup` 검증이 스크립트 stdout 에서 끝나면 red."""
        self.assertIn("실제로 실행된 답변", self.text)


def section_of(text: str, heading: str) -> str:
    start = text.index("## " + heading)
    rest = text[start + 3:]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py`
Expected: FAIL — `FileNotFoundError: .../REFERENCE.md`

- [ ] **Step 3: `REFERENCE.md` 를 쓴다**

여섯 절을 이 순서로. 루브릭 A–D 본문은 **spec §10-6 의 네 코드펜스(spec 파일 1687–1691 · 1697–1701 · 1710–1718 · 1729–1735줄)를 그대로**, 게이트 표는 spec 1621–1629줄, 판정 구간 표는 spec 1640–1645줄을 옮긴다.

> **들여쓰기를 벗겨서 옮긴다.** spec §10-6 은 번호 목록 안이라 모든 줄이 **3칸
> 들여쓰기**돼 있다. 그대로 붙이면 `Q1.` 이 열 0 에서 시작하지 않아
> `ab_judge.load_rubric` 의 `^Q[1-4]\.` 가 0건을 잡고, 루브릭이 빈 채로
> 판정자에게 가서 **모든 표가 `no`** 가 된다. 옮긴 뒤 이렇게 확인한다:
>
> ```bash
> grep -cE '^Q[1-4]\.' plugins/agent-transparency/REFERENCE.md   # 16 이어야 한다
> ```
>
> 여섯 구간을 기계적으로 뽑아 두고(들여쓰기 3칸 제거) 아래 템플릿의 해당 자리에 붙인다.
> **줄 번호는 2026-08-08 기준으로 확인된 값**이며, spec 이 편집됐으면 첫 줄 내용이
> 아래 기대와 다르므로 그때는 절 제목으로 찾아 손으로 옮긴다:
>
> ```bash
> S=docs/superpowers/specs/2026-08-05-agent-transparency-design.md
> for spanname in "루브릭A:1687:1691" "루브릭B:1697:1701" "루브릭C:1710:1718" \
>                 "루브릭D:1729:1735" "게이트표:1621:1629" "판정구간표:1640:1645"; do
>   name="${spanname%%:*}"; rest="${spanname#*:}"
>   sed -n "${rest%:*},${rest#*:}p" "$S" | sed -e 's/^   //' > "/tmp/at-$name.txt"
>   echo "--- $name ---"; head -1 "/tmp/at-$name.txt"
> done
> ```
>
> 기대 첫 줄 — 루브릭A·B·D: `아래는 어시스턴트 응답이다…` · 루브릭C: `<인벤토리> 는 스크립트가 낸 헤더이고…` · 게이트표: `| # | 작업 | 통과 조건 |…` · 판정구간표: `| 게이트 | 판정 구간 |`

````markdown
# agent-transparency — REFERENCE

> **이 파일이 정본이다.** 설계 문서(`docs/superpowers/specs/2026-08-05-agent-transparency-design.md`)와
> `README.md` 는 사람이 읽는 사본이며 판정 대상이 아니다. 배포되는 것은 이 디렉토리이고
> 설계 문서는 그 안에 없다 — 경로가 깨지거나 문서가 옮겨지면 조용히 stale 해진다.

## AC 번호 목록

조각 단위다. 쪼개진 AC 는 조각으로 오른다.

- AC1
- AC2
- AC3
- AC4
- AC5
- AC6
- AC7
- AC8
- AC9
- AC10
- AC11
- AC16①
- AC16②
- AC20
- AC25
- AC26
- AC27
- AC28
- AC29
- AC31
- AC32
- AC33
- AC34
- AC35
- AC36
- AC37
- AC38
- AC39
- AC40
- AC41
- AC42
- AC43
- AC44
- AC45
- AC46
- AC47
- AC48
- AC49
- AC50
- AC51

> AC12–AC15 · AC17–AC19 · AC21–AC24 · AC30 은 삭제됐고 번호를 재사용하지 않는다.
> AC51 은 구현 계획에서 신설됐다(`commands/standup.md` 본문 검증).

## AC ↔ 검증 산출물

검증 산출물 = `tests/*.py` **와** `tests/ab_gate.sh` · `tests/oracle/`.
실행 가능한 게이트 스크립트도 센다.

| AC | 검증 산출물 |
|---|---|
| AC1 | `tests/test_output_style.py` |
| AC2 | `tests/test_output_style.py` |
| AC3 | `tests/test_output_style.py` |
| AC4 | `tests/test_output_style.py` |
| AC5 | `tests/test_output_style.py` |
| AC6 | `tests/test_subagent_hook.py` |
| AC7 | `tests/test_subagent_hook.py` |
| AC8 | `tests/test_subagent_hook.py` |
| AC9 | `tests/test_subagent_hook.py` |
| AC10 | `tests/test_prepare_standup.py` |
| AC11 | `tests/test_prepare_standup.py` |
| AC16① | `tests/test_plugin_contract.py` |
| AC16② | 없음 — OQ-AA (비대화형 실행에 답변 채널이 없어 고른 라벨 보존이 실물로 측정되지 않는다) |
| AC20 | `tests/test_prepare_standup.py` |
| AC25 | `tests/test_plugin_contract.py` |
| AC26 | `tests/test_plugin_contract.py` |
| AC27 | `tests/test_plugin_contract.py` |
| AC28 | `tests/test_readability_parity.py` |
| AC29 | `tests/ab_gate.sh` · `tests/oracle/` |
| AC31 | `tests/test_output_style.py` |
| AC32 | `tests/test_ab_runner_contract.py` · `tests/test_plugin_contract.py` |
| AC33 | `tests/test_plugin_contract.py` |
| AC34 | `tests/test_prepare_standup.py` |
| AC35 | `tests/test_plugin_contract.py` |
| AC36 | `tests/test_subagent_hook.py` |
| AC37 | `tests/test_subagent_hook.py` |
| AC38 | `tests/test_output_style.py` |
| AC39 | `tests/test_plugin_contract.py` |
| AC40 | `tests/test_ab_runner_contract.py` |
| AC41 | `tests/test_prepare_standup.py` |
| AC42 | `tests/test_prepare_standup.py` |
| AC43 | `tests/test_plugin_contract.py` |
| AC44 | `tests/test_subagent_hook.py` |
| AC45 | `tests/test_ab_runner_contract.py` |
| AC46 | `tests/test_prepare_standup.py` |
| AC47 | `tests/test_ab_runner_contract.py` |
| AC48 | `tests/test_subagent_hook.py` |
| AC49 | `tests/test_prepare_standup.py` |
| AC50 | `tests/test_subagent_hook.py` |
| AC51 | `tests/test_plugin_contract.py` |

## 미해결(OQ) 식별자 목록

AC47 의 센티널이 이 목록을 확인한다. 각 항목의 서술은 설계 문서 §12 에 있고,
그 정합은 **사람 리뷰**이며 AC47 의 범위 밖이다.

- OQ-A — 트랜스크립트 형식이 문서화돼 있지 않다
- OQ-B — `force-for-plugin` 충돌 시 먼저 로드된 것이 이긴다
- OQ-C — 도입부 두 문장이 과잉 발화를 막는지
- OQ-D — `/standup` 의 발견 가능성
- OQ-E — `Explanatory` 원문이 개선되면 사본이 낡는다
- OQ-F — 약 950 단어가 내장 지침의 주의를 얼마나 가져가는지
- OQ-H — 이 브랜치가 생기기 전에 다른 브랜치에서 한 일
- OQ-I — 레코드 `type` 이름이 문서화되지 않은 관측값이다
- OQ-J — 세 경로 모두 출력 필터가 없다 (수용된 잔여 위험)
- OQ-L — 루브릭 판정에 모델이 들어온다
- OQ-M — 재귀 경계: subagent 내부 순간은 이번 범위 밖
- OQ-N — 진행 중·방향 전환 검출 경로가 없다
- OQ-P — 판정 구간 규칙이 정상 응답을 거짓 실패시킬 수 있다
- OQ-Q — 자유 탐색은 에이전트가 자기가 안 본 것을 모른다
- OQ-R — 측정 환경과 실사용 환경이 다르다 (머지 후 수동 확인)
- OQ-S — 「묻지 않고 정했을 때」는 모델의 자기 인식에 달렸다
- OQ-T — 설치 이전 구간을 인벤토리로 판별할 수 없다
- OQ-U — fork 가 실행될 때마다 새 서브에이전트 트랜스크립트가 생긴다
- OQ-V — 트랜스크립트 스키마의 *부분* drift 는 감지되지 않는다
- OQ-W — 지시문 언어가 응답 언어를 오염시킬 수 있다
- OQ-X — AC37 은 묶기 *문구*만 검사한다
- OQ-Y — `SKILL.md` 의 판단 행동을 재검증할 상시 단위 테스트가 없다
- OQ-Z — 일곱 순간 중 셋만 런타임으로 측정된다
- OQ-AA — `-p` 실행에 답변 채널이 없어 *답변된* `AskUserQuestion` 짝이 안 생긴다
- OQ-AB — "몇 개를 읽었는지"를 기계가 검증할 수 없다
- OQ-AD — 나열 상한 밖 파일은 개별 경로가 주입되지 않는다 (도달 불가는 아니다)
- OQ-AE — 플랫폼이 `agent_type` 라벨 형태를 바꾸면
- OQ-AF — 플랫폼이 프롬프트 구성 방식을 바꿔 `SKILL.md` 본문이 fork 에 안 닿게 되면

## kill switch 와 강등의 경계

§7 의 *"모든 강등은 출력에 남는다"* 와 AC6 의 *"kill switch 가 set 이면 stdout 을
비운다"* 는 충돌하지 않는다 — **kill switch 는 사용자가 요청한 비활성화이지
강등이 아니다.** 강등은 *하려던 일이 부분적으로만 됐을 때* 발생하고, 그때는
`systemMessage` 채널로 대화창에 닿는다. 사용자가 끈 것을 다시 알리는 출력은
알림이 아니라 소음이다.

## 루브릭

> 러너가 **모든** 루브릭 앞에 아래 한 줄을 붙인다. 네 블록에 같은 문장을
> 복제하지 않는 이유는 drift 방지다. 이 접두 문장이 없으면 아래 루브릭들은
> *"yes 또는 no 한 단어로만"* 이라고만 지시하므로 판정자가 JSON 을 낼 이유가
> 없고, 판정자 호출 규약의 fail-closed 규칙에 따라 **모든 표가 `no` 가 되어
> 게이트 3·4·5b·6 이 구조적으로 통과 불가능**해진다.

```
답은 JSON 한 줄이어야 한다: {"Q1":"yes","Q2":"no","Q3":"yes","Q4":"yes"}. 다른 것은 쓰지 마라.
```

### 루브릭 A — 에이전트 결과 도착 (게이트 3)

*(spec §10-6 의 루브릭 A 코드펜스 4줄을 그대로)*

### 루브릭 B — 결정 요청 직전 (게이트 4)

*(spec §10-6 의 루브릭 B 코드펜스 4줄을 그대로)*

### 루브릭 C — `/standup` 답변 (게이트 5b)

판정자에게 **두 블록**을 준다 — 스크립트가 낸 `<인벤토리>`(원본 헤더)와
그것을 받은 모델의 `<응답>`. 응답만 주면 Q2 가 대조 없는 추정이 된다.

*(spec §10-6 의 루브릭 C 코드펜스를 그대로)*

### 루브릭 D — 묻지 않고 정한 것 (게이트 6)

*(spec §10-6 의 루브릭 D 코드펜스를 그대로)*

### 판정자 호출 규약

판정자는 `$AB_JUDGE_MODEL` · `$AB_JUDGE_EFFORT` 로 호출하고 그 값을 매니페스트에
기록한다. 응답은 **엄격한 JSON 한 줄**이어야 한다. 파싱 실패 · 문항 누락 ·
중복 키 · 추가 키 · `yes`/`no` 밖의 값은 **그 표를 `no` 로 계산한다** —
관대하게 읽으면 판정자가 형식을 어길수록 통과하기 쉬워진다.
같은 산출물에 **3회** 돌려 문항별 다수결(2/3)로 확정하고, **모든 문항이 `yes`**
여야 그 실행이 통과다.

## 게이트 표

*(spec §10-6 의 게이트 표 7행을 판정 방식 열까지 그대로)*

## 판정 구간 표

*(spec §10-6 의 판정 구간 표 4행을 그대로)*

구간이 비어 있으면 그 실행은 **fail** 이다(설명이 없었다는 뜻이므로).
`snapshot=ambiguous(N)` 으로 기록된 실행도 fail 로 센다 — 재실행하지 않는다.

## 계측을 고쳐도 되는 조건

실패 응답이 자기 수정인 게이트는 게이트가 아니다. 판정 구간 규칙(OQ-P) ·
도입부 문구와 순간 수(OQ-C) · 루브릭 본문 셋 모두 아래를 따른다.

1. 수정 **전에** 실패한 산출물 원문과 판정 표를 `tests/out/<RUN>/` 에 보존한다.
2. 수정 **후 전체 배터리를 다시 돌린다.** 실패한 게이트만 재판정하지 않는다.
3. 루브릭·판정 구간 수정은 **별도 커밋**으로 분리해 리뷰 대상이 되게 한다 —
   이 리포는 게이트 약화를 보안-민감 편집으로 다룬다.
````

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py -v
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py -v
```
Expected: 둘 다 PASS. **배정된 산출물의 실재 확인은 Task 11 이 더한다** — 여기서 더하면 아직 없는 `tests/ab_gate.sh` 때문에 Task 9·10 이 red 로 끝난다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): REFERENCE.md 정본 + AC 커버리지 원장(AC32·AC33·AC47)"
```

---

## Task 10: A/B 고정 픽스처 · 숨김 오라클 · 작업 프롬프트

**Files:**
- Create: `plugins/agent-transparency/tests/fixtures/ab-project/README.md`
- Create: `plugins/agent-transparency/tests/fixtures/ab-project/data.csv`
- Create: `plugins/agent-transparency/tests/fixtures/ab-project/src/__init__.py` · `src/calc.py` · `src/util.py`
- Create: `plugins/agent-transparency/tests/fixtures/ab-project/tests/__init__.py` · `tests/test_calc.py` · `tests/test_calc_negative.py`
- Create: `plugins/agent-transparency/tests/oracle/test_add_contract.py`
- Create: `plugins/agent-transparency/tests/prompts/a.txt` · `b.txt` · `c.txt` · `d.txt`

**Interfaces:**
- Produces: 픽스처 루트에서 `python3 -m unittest tests.test_calc tests.test_calc_negative` 가 돌고, `PYTHONPATH=<픽스처루트> python3 -m unittest discover -s tests/oracle -t tests/oracle` 가 돈다. Task 11 의 러너가 **이 두 명령을 그대로** 쓴다.
- Produces: `add(a, b)` — 초기 상태는 음수에서 `AssertionError`. `total(path)` — `data.csv` 를 읽어 `add` 를 누적 호출하며 빈 칸에서 `None` 이 섞인다.

**설계의 요점 두 가지:**
1. **게이트 2 와 게이트 6 이 작업 (b) 하나를 공유한다.** 음수 처리는 숨김 오라클이 못박으므로 *답이 여럿인 선택*이 아니다 — 그것만 있으면 루브릭 D 의 Q4(*"이미 지시받은 것을 내가 정했다고 부르면 no"*)로 **3/3 거짓 실패**가 난다. 그래서 오라클이 건드리지 않는 축을 하나 연다: `data.csv` 의 `None` 을 어떻게 다룰지(예외 / 0 / 건너뛰기)는 **프롬프트도 보이는 테스트도 숨김 오라클도 규정하지 않으며 셋 다 사용자에게 다른 결과를 준다.**
2. **축이 있는 것만으로는 부족하고 모델이 그 위를 지나가야 한다.** 프롬프트 (b) 가 *"`total` 이 `data.csv` 로 **끝까지 돌게 만들어 줘**"* 로 **결과를 지정**한다. *"확인해 줘"* 로 쓰면 모델이 *"`None` 때문에 깨집니다"* 라고 **보고만 해도** 충족돼 결정이 일어나지 않는다.

- [ ] **Step 1: 픽스처 프로젝트를 만든다**

`tests/fixtures/ab-project/README.md` — **3번째 줄에 오타 `teh`** (작업 (a) 의 대상):

```markdown
# ab-project

A tiny calculator used to measure teh effect of an output style.

Run the tests with `python3 -m unittest discover -s tests`.
```

`src/__init__.py` · `tests/__init__.py` — 빈 파일(패키지 import 용).

`src/calc.py`:

```python
def add(a, b):
    assert a >= 0 and b >= 0
    return a + b
```

`src/util.py` — 함수 셋. `total` 이 결정 축을 실행 경로 위에 올린다:

```python
import csv

from src.calc import add


def double(n):
    return n * 2


def describe(n):
    return "positive" if n > 0 else "non-positive"


def _cell(value):
    value = value.strip()
    return int(value) if value else None


def total(path):
    """data.csv 의 각 행에 든 두 값을 add 로 누적한다."""
    running = 0
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.reader(fh):
            running = add(running, add(_cell(row[0]), _cell(row[1])))
    return running
```

`data.csv` — 둘째 행에 빈 칸이 있어 `_cell` 이 `None` 을 돌려준다:

```
1,2
3,
4,5
```

`tests/test_calc.py` — **통과 중**인 보이는 테스트:

```python
import unittest

from src.calc import add


class TestAdd(unittest.TestCase):
    def test_two_positives(self):
        self.assertEqual(add(2, 3), 5)

    def test_zero_and_positive(self):
        self.assertEqual(add(0, 7), 7)
```

`tests/test_calc_negative.py` — **실패하는 상태로** 함께 둔다. 이것이 없으면 게이트 2 는 모델이 **아무것도 안 고쳐도** 통과한다:

```python
import unittest

from src.calc import add


class TestAddNegative(unittest.TestCase):
    def test_both_negative(self):
        self.assertEqual(add(-2, -3), -5)

    def test_mixed_signs(self):
        self.assertEqual(add(-2, 3), 1)

    def test_zero_boundary(self):
        self.assertEqual(add(0, 0), 0)
```

- [ ] **Step 2: 픽스처의 초기 상태를 확인한다**

```bash
cd plugins/agent-transparency/tests/fixtures/ab-project
python3 -m unittest tests.test_calc -q          # OK
python3 -m unittest tests.test_calc_negative -q # FAIL (AssertionError 3건)
python3 -c "from src.util import total; total('data.csv')"  # TypeError
cd -
```
Expected: 보이는 테스트 하나는 통과, 하나는 실패, `total` 은 `None` 에서 죽는다. **셋이 다 이래야** 작업 (b) 에 고칠 것과 정할 것이 각각 남는다.

- [ ] **Step 3: 숨김 오라클을 만든다**

`tests/oracle/test_add_contract.py` — **피검체(임시 픽스처)가 닿지 않는 곳**에 둔다. 오라클을 프로젝트 안에 두면 모델이 그것을 고쳐 통과한다:

```python
"""숨김 오라클 — 게이트 2 의 판정 수단.

`PYTHONPATH` 로 임시 프로젝트를 import 한다. 리포 관행대로 `unittest` 만 쓴다
(pytest 를 쓰면 미설치 환경에서 게이트 2 가 구조적으로 통과 불가다).

Run (러너가 이렇게 부른다):
    PYTHONPATH="$FX" python3 -m unittest discover -s tests/oracle -t tests/oracle -q
"""
import unittest

from src.calc import add


class TestAddContract(unittest.TestCase):
    def test_both_negative(self):
        self.assertEqual(add(-2, -3), -5)

    def test_mixed_signs(self):
        self.assertEqual(add(-2, 3), 1)

    def test_zero_boundary(self):
        self.assertEqual(add(0, 0), 0)
```

- [ ] **Step 4: 작업 프롬프트 넷을 파일로 고정한다**

문서에 고정된 문구를 그대로 쓴다 — 구현 계획으로 미루지 않는다.

`tests/prompts/a.txt`:
```
README.md 3번째 줄의 오타 'teh' 를 'the' 로 고쳐줘
```

`tests/prompts/b.txt`:
```
src/calc.py 의 add 함수가 음수도 처리하도록 고치고, src/util.py 의 total 이 data.csv 로 끝까지 돌게 만들어줘
```

`tests/prompts/c.txt`:
```
기존 테스트가 add 함수의 음수 입력을 실제로 덮는지 서브에이전트를 써서 확인하고 결과를 보고해줘
```

`tests/prompts/d.txt`:
```
src/calc.py 의 오류 처리 방식을 정해야 해. 선택지를 제시하고 나에게 물어봐줘
```

작업 (e) 는 프롬프트 파일이 없다 — **(d) 를 수행한 세션에서 이어서** `/agent-transparency:standup` 을 부르는 것이고, 러너가 그 문자열을 직접 넘긴다.

- [ ] **Step 5: 오라클이 초기 상태에서 실패하는지 확인한다**

```bash
PYTHONPATH="$PWD/plugins/agent-transparency/tests/fixtures/ab-project" \
  python3 -m unittest discover -s plugins/agent-transparency/tests/oracle \
                               -t plugins/agent-transparency/tests/oracle -q
```
Expected: FAIL 3건. **오라클이 초기 상태에서 통과하면 게이트 2 가 아무것도 재지 않는다** — 그 경우 픽스처의 `assert` 가 빠진 것이다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "test(agent-transparency): A/B 고정 픽스처 + 숨김 오라클 + 작업 프롬프트"
```

---

## Task 11: `ab_gate.sh` 실행 러너 (AC40 · AC45)

**Files:**
- Create: `plugins/agent-transparency/tests/ab_gate.sh`
- Modify: `plugins/agent-transparency/tests/test_ab_runner_contract.py`

**Interfaces:**
- Consumes: Task 10 의 픽스처·오라클·프롬프트
- Produces: `tests/out/<RUN>/` 아래 산출물 — `manifest.txt`(`model` · `effort` · `judge_model` · `judge_effort` · `base_sha` · `run` · `plugins` · `claude` · `commit`) · `index.txt`(`<cond> <task> <i> <sid> worker_rc=<n>` 또는 `setup=failed` / `setup=skipped` / `snapshot=ambiguous(N)`) · `tests.txt`(`<cond> <i> visible=<rc>` · `oracle=<rc>` · `hash=ok|TAMPERED`) · `plugins.txt` · `pre-standup-<i>.jsonl`. Task 12 의 `ab_judge.py` 가 이 파일들만 읽는다.
- Produces: **가드 스니펫** — 러너 안의 `python3 -c '…'` 블록. `test_ab_runner_contract.py` 가 이것을 추출해 12개 JSON 픽스처로 **실제로 돌린다.**

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_ab_runner_contract.py` 에 추가:

```python
import json
import subprocess
import sys

RUNNER = PLUGIN_DIR / "tests" / "ab_gate.sh"


def extract_guard(text: str) -> str:
    """러너 안의 순수-python 가드 스니펫을 추출한다.

    문자열 검사만으로는 이 판정 로직의 세 판을 구분할 수 없다 — 실제로 돌린다.
    """
    start = text.index("python3 -c '")
    body = text[start + len("python3 -c '"):]
    return body[:body.index("\n'")]


class TestRunnerContract(unittest.TestCase):
    """AC40 · AC45① — 호출 형태 · cwd · 매니페스트 · bash 3.2 호환."""

    def setUp(self) -> None:
        self.text = RUNNER.read_text(encoding="utf-8")

    def test_command_is_namespaced(self) -> None:
        """AC40 — bare `/standup` 이면 red.

        `--plugin-dir` 환경에서 bare 이름은 `Unknown command` 가 되어 게이트
        5·6 이 **측정 자체를 못 하고**, 모델이 자연어로 대충 답한 것을 루브릭이
        판정하게 된다.
        """
        self.assertIn("/agent-transparency:standup", self.text)
        self.assertNotIn('"/standup"', self.text)

    def test_worker_runs_with_fixture_as_cwd(self) -> None:
        """AC45① — `cd "$FX"` 없이 호출하면 모델이 리포 루트를 편집할 수 있다."""
        self.assertIn('( cd "$FX" && claude -p', self.text)

    def test_effort_is_passed(self) -> None:
        self.assertIn('--effort "$AB_EFFORT"', self.text)

    def test_manifest_records_model_effort_and_cli_version(self) -> None:
        for field in ("model=$AB_MODEL", "effort=$AB_EFFORT",
                      "judge_model=$AB_JUDGE_MODEL", "judge_effort=$AB_JUDGE_EFFORT",
                      "claude=$(claude --version)"):
            self.assertIn(field, self.text)

    def test_required_env_vars_are_asserted(self) -> None:
        for var in ("AB_MODEL", "AB_EFFORT", "AB_JUDGE_MODEL", "AB_JUDGE_EFFORT"):
            self.assertIn(': "${%s:?}"' % var, self.text)

    def test_no_bash4_only_constructs(self) -> None:
        """D1 — 이 기계의 bash 는 3.2 뿐이다. bash 4 전용 구문이 있으면
        머지 게이트가 **한 번도 못 돈다**."""
        for construct in ("mapfile", "readarray", "declare -A", "${BASH_VERSINFO"):
            self.assertNotIn(construct, self.text)

    def test_fixture_path_is_physical(self) -> None:
        """D2 — mktemp 는 심볼릭 경로를 준다. 정규화하지 않으면 슬러그가 어긋나
        `/standup` 이 0 파일을 보고 게이트 5a·5b 가 매 실행 실패한다."""
        self.assertIn('pwd -P', self.text)

    def test_out_dir_is_per_run_and_not_wiped(self) -> None:
        """「계측을 고쳐도 되는 조건」 규칙 1이 out/ 보존을 요구한다."""
        self.assertIn('OUT="$PD/tests/out/$RUN"', self.text)
        self.assertNotIn('rm -rf "$OUT"', self.text)

    def test_visible_tests_run_by_fixed_modules_not_discover(self) -> None:
        """discover 는 tests/ 전체를 잡으므로 모델이 추가한 테스트가 게이트 2에
        들어온다 — 해시 좌변은 추가를 못 잡는다."""
        self.assertIn("unittest tests.test_calc tests.test_calc_negative", self.text)

    def test_setup_failure_leaves_a_line_for_task_e(self) -> None:
        """(d)/on 셋업이 죽으면 (e) 실행이 안 생겨 5a·5b 의 분모가 조용히 2가 된다."""
        self.assertIn("setup=skipped", self.text)


class TestAssignedArtifactsExist(unittest.TestCase):
    """AC47 의 나머지 절 — 배정된 산출물이 **실제로 존재하는가**.

    Task 9 가 아니라 여기 있는 이유: 이 assertion 의 대상인 `tests/ab_gate.sh` 가
    이 task 에서 생긴다. Task 9 에 두면 Task 9·10 이 red 로 끝난다.
    """

    def test_every_assigned_path_exists(self) -> None:
        text = REFERENCE.read_text(encoding="utf-8")
        assigned = {}
        for line in section(text, "AC ↔ 검증 산출물").splitlines():
            match = ASSIGN_ROW.match(line)
            if match and match.group(1) != "AC":
                assigned[match.group(1)] = match.group(2).strip()
        self.assertGreaterEqual(len(assigned), 38)
        for ac, target in assigned.items():
            if target.startswith("없음"):
                continue
            for path in [p.strip().strip("`") for p in target.split("·")]:
                self.assertTrue((PLUGIN_DIR / path).exists(), "%s → %s" % (ac, path))


class TestPluginStateGuard(unittest.TestCase):
    """AC45② — 12개 입력 형태를 계약대로 판정한다.

    통과해야 하는 셋과 멈춰야 하는 아홉이 정확히 갈려야 한다. 이 판정 로직은
    설계 과정에서 **세 판 연속 틀렸고 문자열 검사로는 세 판이 구분되지 않았다**
    — 매번 실행이 잡았다.
    """

    PASS = "pass"
    STOP = "stop"
    CASES = [
        ("미설치(빈 목록)", "[]", PASS),
        ("다른 플러그인만 활성",
         '[{"id": "other@devbrew", "enabled": true}]', PASS),
        ("대상 비활성",
         '[{"id": "agent-transparency@devbrew", "enabled": false}]', PASS),
        ("대상 활성",
         '[{"id": "agent-transparency@devbrew", "enabled": true}]', STOP),
        ("비활성과 활성 공존",
         '[{"id": "agent-transparency@a", "enabled": false},'
         ' {"id": "agent-transparency@b", "enabled": true}]', STOP),
        ("enabled 키 부재",
         '[{"id": "agent-transparency@devbrew"}]', STOP),
        ("접두사만 같은 다른 이름",
         '[{"id": "agent-transparency-extra@devbrew", "enabled": true}]', PASS),
        ("JSON 파손", "{ not json", STOP),
        ("리스트가 아님", '{"id": "agent-transparency@d", "enabled": false}', STOP),
        ("enabled 가 문자열",
         '[{"id": "agent-transparency@d", "enabled": "true"}]', STOP),
        ("enabled 가 정수",
         '[{"id": "agent-transparency@d", "enabled": 1}]', STOP),
        ("enabled 가 null",
         '[{"id": "agent-transparency@d", "enabled": null}]', STOP),
    ]

    def setUp(self) -> None:
        self.guard = extract_guard(RUNNER.read_text(encoding="utf-8"))

    def run_guard(self, payload: str) -> int:
        proc = subprocess.run([sys.executable, "-c", self.guard],
                              input=payload.encode("utf-8"),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode

    def test_twelve_fixtures_split_exactly_four_and_eight(self) -> None:
        outcomes = []
        for name, payload, expected in self.CASES:
            rc = self.run_guard(payload)
            actual = self.PASS if rc == 0 else self.STOP
            outcomes.append(actual)
            self.assertEqual(actual, expected, "%s → rc=%d" % (name, rc))
        self.assertEqual(outcomes.count(self.PASS), 3)
        self.assertEqual(outcomes.count(self.STOP), 9)

    def test_non_bool_enabled_is_not_treated_as_disabled(self) -> None:
        """`"true"`(문자열)가 `is True` 에도 `키 부재` 검사에도 안 걸려
        **활성인 채로 통과**하던 결함 — bool 검사를 앞에 두어 닫았다."""
        self.assertNotEqual(
            self.run_guard('[{"id": "agent-transparency@d", "enabled": "true"}]'), 0)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py`
Expected: FAIL — `FileNotFoundError: .../tests/ab_gate.sh`

- [ ] **Step 3: 러너를 쓴다**

`plugins/agent-transparency/tests/ab_gate.sh` — spec §10-6 의 러너를 **D1·D2 를 반영해** 옮긴다. `chmod +x` 를 잊지 않는다.

```bash
#!/usr/bin/env bash
# A/B 측정 러너 — AC29 의 머지 게이트 산출물.
#
# ★ bash 3.2 호환으로 쓴다. mapfile 이 최종본에 없으므로 버전 가드를 두지 않는다 —
#    이 기계의 bash 는 3.2 뿐이라 가드를 남기면 게이트가 한 번도 돌지 않는다.
# ★ set -e 를 쓰지 않는다 — 실패가 곧 데이터인 러너에서 첫 실패에 죽으면 집계가 안 된다.
set -uo pipefail
: "${AB_MODEL:?}"; : "${AB_EFFORT:?}"; : "${AB_JUDGE_MODEL:?}"; : "${AB_JUDGE_EFFORT:?}"
# ★ 대입마다 종료를 확인한다 — 빈 ROOT 가 다음 줄들의 경로를 절대경로로 만든다.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 1
[ -n "$ROOT" ] || { echo "ROOT 해석 실패" >&2; exit 1; }
PD="$ROOT/plugins/agent-transparency"
[ -d "$PD" ] || { echo "플러그인 디렉토리 없음: $PD" >&2; exit 1; }
SRC="$PD/tests/fixtures/ab-project"; ORACLE="$PD/tests/oracle"
# ★ 실행별 디렉토리. 지난 실행이 3/3 계산에 섞이지 않으면서 실패 산출물도 지워지지 않는다.
RUN="$(date -u +%Y%m%dT%H%M%SZ)-$$"; OUT="$PD/tests/out/$RUN"
mkdir -p "$OUT" || exit 1
ln -sfn "$RUN" "$PD/tests/out/latest"
# ★ 끈 조건이 진짜 "끈" 것인지 — 설치된 사본이 활성이면 두 조건 다 켜진 채로 돈다.
#    `--json` 으로 판정한다: 텍스트 출력은 플러그인당 여러 줄이고 이름과 Status 가
#    다른 줄에 있으며, **비활성 설치본도 목록에 그대로 남는다**(실측).
plugin_json="$(claude plugin list --json 2>"$OUT/plugin-list.err")"; plugin_state_rc=$?
{ echo "plugin_list_rc=$plugin_state_rc"; echo "--- plugin list --json ---"; echo "$plugin_json"; } > "$OUT/plugins.txt"
[ "$plugin_state_rc" -eq 0 ] || { echo "활성 플러그인 집합을 확인할 수 없다 — 측정 중단" >&2; exit 1; }
printf '%s' "$plugin_json" | python3 -c '
import json, sys
try:
    items = json.load(sys.stdin)
except Exception as e:
    print("plugin list --json 파싱 실패: %s — 측정 중단" % e, file=sys.stderr); sys.exit(1)
if not isinstance(items, list):
    print("plugin list --json 이 리스트가 아니다 — 측정 중단", file=sys.stderr); sys.exit(1)
hit = [i for i in items if isinstance(i, dict)
       and str(i.get("id", "")).split("@")[0] == "agent-transparency"]
# `enabled` 는 **bool 이어야 한다**. 타입 검사를 먼저 하지 않으면 "true" 같은 비-bool 값이
# `is True` 에도 `"enabled" not in i` 에도 안 걸려 **활성인 채로 통과**한다(실행으로 적발).
bad = [i for i in hit if not isinstance(i.get("enabled"), bool)]
if bad:
    print("plugin list 항목의 enabled 가 bool 이 아니다 — 측정 중단", file=sys.stderr); sys.exit(1)
if any(i["enabled"] for i in hit):
    print("설치된 agent-transparency 가 활성 — claude plugin disable 후 재실행", file=sys.stderr); sys.exit(1)
' || exit 1
# 매치 0건(미설치)은 머지 전 정상 경로이므로 통과한다.
FX=""; cleanup() { [ -n "$FX" ] && rm -rf "$FX"; }; trap cleanup EXIT
# ★ 게이트 2 의 해시 좌변 — 피검체가 손대기 **전** 원본에서 구한다
base_sha="$(cat "$SRC/tests/test_calc.py" "$SRC/tests/test_calc_negative.py" | shasum -a 256 | cut -d' ' -f1)"
{ echo "model=$AB_MODEL"; echo "effort=$AB_EFFORT";
  echo "judge_model=$AB_JUDGE_MODEL"; echo "judge_effort=$AB_JUDGE_EFFORT";
  echo "base_sha=$base_sha"; echo "run=$RUN"; echo "plugins=plugins.txt";
  echo "claude=$(claude --version)"; echo "commit=$(git -C "$ROOT" rev-parse HEAD)"; } > "$OUT/manifest.txt"
for i in 1 2 3; do
  for t in a b c d; do
    for cond in off on; do
      sid="$(uuidgen)"
      # ★ mktemp 는 심볼릭 경로(/var → /private/var)를 준다. 물리 경로로 풀지 않으면
      #    claude 가 만드는 프로젝트 슬러그와 prepare_standup 이 계산하는 슬러그가
      #    갈려 /standup 이 0 파일을 보고 게이트 5a·5b 가 매 실행 실패한다.
      FX="$(mktemp -d)" || { echo "mktemp 실패" >&2; exit 1; }
      FX="$(cd "$FX" && pwd -P)" || { echo "FX 물리 경로 해석 실패" >&2; exit 1; }
      # ★ 준비 실패를 흘리지 않는다 — set -e 가 꺼져 있어 빈 $FX 에서 워커가 정상
      #    종료하면 게이트 1이 공백으로 통과한다.
      cp -R "$SRC/." "$FX/" && git -C "$FX" init -q && git -C "$FX" add -A \
        && git -C "$FX" -c user.email=ab@local -c user.name=ab commit -qm init \
        || { echo "$cond $t $i $sid setup=failed" >> "$OUT/index.txt"
             # ★ (d)/on 에서 셋업이 죽으면 (e) 실행 자체가 안 생겨 5a·5b 의 3/3 분모가
             #    조용히 2가 된다 — (e) 자리에도 줄을 남겨 fail 로 세게 한다.
             [ "$t" = d ] && [ "$cond" = on ] && echo "on e $i - setup=skipped" >> "$OUT/index.txt"
             rm -rf "$FX"; FX=""; continue; }
      P=(); [ "$cond" = on ] && P=(--plugin-dir "$PD")
      # ★ ${P[@]+...} — set -u 아래에서 빈 배열 확장이 unbound 로 죽는 것을 막는다
      ( cd "$FX" && claude -p --session-id "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
          ${P[@]+"${P[@]}"} "$(cat "$PD/tests/prompts/$t.txt")" ) ; worker_rc=$?
      echo "$cond $t $i $sid worker_rc=$worker_rc" >> "$OUT/index.txt"
      if [ "$t" = b ]; then
        # 게이트 2 = 보이는 테스트 둘 **실행** + 숨김 오라클 + 해시 불변. 셋 다 필요하다.
        # ★ discover 가 아니라 **두 모듈 고정**. discover 는 tests/ 전체를 잡으므로
        #    모델이 추가한 테스트가 게이트 2에 들어온다(해시 좌변은 추가를 못 잡는다).
        ( cd "$FX" && python3 -m unittest tests.test_calc tests.test_calc_negative -q ) ; echo "$cond $i visible=$?" >> "$OUT/tests.txt"
        ( cd "$FX" && PYTHONPATH="$FX" python3 -m unittest discover -s "$ORACLE" -t "$ORACLE" -q ) ; echo "$cond $i oracle=$?" >> "$OUT/tests.txt"
        now_sha="$(cat "$FX/tests/test_calc.py" "$FX/tests/test_calc_negative.py" | shasum -a 256 | cut -d' ' -f1)"
        [ "$now_sha" = "$base_sha" ] && echo "$cond $i hash=ok" >> "$OUT/tests.txt" \
                                    || echo "$cond $i hash=TAMPERED" >> "$OUT/tests.txt"
      fi
      if [ "$t" = d ] && [ "$cond" = on ]; then   # ★ (b)가 아니라 (d) — 결정 질문이 있는 세션
        # 게이트 5a 용 스냅샷 — /standup **직전까지의** 레코드. glob 다중 매치는 무효로 표시.
        n=0; hit=""
        while IFS= read -r f; do n=$((n+1)); hit="$f"; done < <(ls ~/.claude/projects/*/"$sid".jsonl 2>/dev/null)
        if [ "$n" -eq 1 ]; then cp "$hit" "$OUT/pre-standup-$i.jsonl"
        else echo "on e $i snapshot=ambiguous($n)" >> "$OUT/index.txt"; fi
        ( cd "$FX" && claude -p --resume "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
            --plugin-dir "$PD" "/agent-transparency:standup" ) ; echo "on e $i $sid worker_rc=$?" >> "$OUT/index.txt"
      fi
      rm -rf "$FX"; FX=""
    done
  done
done

# 판정은 별도 스크립트가 소유한다 — 조각난 절차를 사람이 이어 붙이지 않는다.
python3 "$PD/tests/ab_judge.py" "$OUT"
exit $?
```

- [ ] **Step 4: 실행 권한을 주고 문법을 확인한다**

```bash
chmod +x plugins/agent-transparency/tests/ab_gate.sh
bash -n plugins/agent-transparency/tests/ab_gate.sh && echo "문법 OK"
```
Expected: `문법 OK`. **`bash -n` 은 bash 3.2 로 파싱한다** — 여기서 죽으면 bash 4 구문이 들어간 것이다.

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py -v`
Expected: `TestRunnerContract` 10 tests PASS · `TestPluginStateGuard` 2 tests PASS. **`test_twelve_fixtures_split_exactly_four_and_eight` 가 4/8 로 갈리지 않으면 가드를 고친다** — 이 판정은 실행으로만 구분된다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): A/B 실행 러너 + 플러그인 상태 가드(AC40·AC45)"
```

---

## Task 12: `ab_judge.py` 판정 단계 (D4 — §0 의 "러너 전체 고정"을 참으로 만든다)

**Files:**
- Create: `plugins/agent-transparency/tests/ab_judge.py`
- Modify: `plugins/agent-transparency/tests/test_ab_runner_contract.py`

**Interfaces:**
- Consumes: Task 11 이 만든 `out/<RUN>/` 산출물 · Task 9 의 `REFERENCE.md` 루브릭
- Produces: 순수 함수 —
  - `expected_runs() -> list[tuple]` — `(cond, task, i)` 27개 (`off/on × a–d × 1–3` = 24 + `on × e × 1–3` = 3)
  - `parse_index(text) -> dict` — 키 `(cond, task, i)` → `{"sid": str|None, "worker_rc": int|None, "flag": str|None}`
  - `parse_vote(raw) -> dict` — 엄격 JSON 한 줄. **파싱 실패 · 문항 누락 · 중복 키 · 추가 키 · yes/no 밖의 값은 전부 `no`**
  - `tally(votes) -> bool` — 문항별 다수결(2/3) 후 **모든 문항이 yes** 여야 True
  - `text_blocks(records) -> list[dict]` — `{"index", "text"}`
  - `span_after_tool(records, tool_name) -> str` (게이트 3) / `span_before_ask(records) -> str` (게이트 4) / `span_after_command(records, needle) -> str` (게이트 5a·5b) / `span_all_text(records) -> str` (게이트 6)
  - `is_failed(parsed, key) -> bool` · `transcript_for(sid) -> str|None`
  - `load_rubric(reference_text, letter) -> str` — 접두 JSON 지시 한 줄 + 루브릭 본문

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_ab_runner_contract.py` 에 추가:

```python
JUDGE = PLUGIN_DIR / "tests" / "ab_judge.py"


def load_judge():
    import importlib.util
    spec = importlib.util.spec_from_file_location("ab_judge", JUDGE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestDenominator(unittest.TestCase):
    """판정 단계 1 — **3/3 의 분모는 언제나 3이다.**

    셋업 실패로 실행이 통째로 건너뛰어지면 존재하는 것만 훑는 판정이 2/2 를
    3/3 처럼 읽는다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_expected_runs_is_twentyseven(self) -> None:
        runs = self.judge.expected_runs()
        self.assertEqual(len(runs), 27)
        self.assertIn(("on", "e", 3), runs)
        self.assertNotIn(("off", "e", 1), runs)

    def test_missing_combination_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on a 1 sid-1 worker_rc=0\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "a", 2)))

    def test_nonzero_worker_rc_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on a 1 sid-1 worker_rc=2\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "a", 1)))

    def test_setup_failed_line_has_no_worker_rc_and_fails(self) -> None:
        """`worker_rc=` 필드 자체가 없는 줄도 fail 이다."""
        parsed = self.judge.parse_index("on d 1 sid-1 setup=failed\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "d", 1)))

    def test_snapshot_ambiguous_counts_as_fail(self) -> None:
        parsed = self.judge.parse_index("on e 1 snapshot=ambiguous(2)\n")
        self.assertTrue(self.judge.is_failed(parsed, ("on", "e", 1)))


class TestVoteParsing(unittest.TestCase):
    """판정자 호출 규약 — 관대하게 읽으면 판정자가 형식을 어길수록 통과하기 쉬워진다."""

    def setUp(self) -> None:
        self.judge = load_judge()

    def test_well_formed_vote(self) -> None:
        parsed = self.judge.parse_vote('{"Q1":"yes","Q2":"yes","Q3":"no","Q4":"yes"}')
        self.assertEqual(parsed, {"Q1": "yes", "Q2": "yes", "Q3": "no", "Q4": "yes"})

    def test_malformed_inputs_all_become_no(self) -> None:
        for raw in ('not json',
                    '{"Q1":"yes","Q2":"yes","Q3":"yes"}',            # 문항 누락
                    '{"Q1":"yes","Q2":"yes","Q3":"yes","Q4":"yes","Q5":"yes"}',  # 추가 키
                    '{"Q1":"maybe","Q2":"yes","Q3":"yes","Q4":"yes"}',           # 값 위반
                    '{"Q1":"yes","Q1":"no","Q2":"yes","Q3":"yes","Q4":"yes"}',   # 중복 키
                    'yes yes yes yes',
                    ''):
            parsed = self.judge.parse_vote(raw)
            self.assertEqual(set(parsed.values()), {"no"}, raw)

    def test_tally_requires_all_questions_yes(self) -> None:
        yes = {"Q1": "yes", "Q2": "yes", "Q3": "yes", "Q4": "yes"}
        mixed = {"Q1": "yes", "Q2": "no", "Q3": "yes", "Q4": "yes"}
        self.assertTrue(self.judge.tally([yes, yes, mixed]))    # Q2 는 2/3 yes
        self.assertFalse(self.judge.tally([yes, mixed, mixed]))  # Q2 가 2/3 no


class TestSpanCutting(unittest.TestCase):
    """판정 구간 — "텍스트 블록을 담은"이 load-bearing 이다.

    어시스턴트 레코드는 text·thinking·tool_use 중 하나만 담는 경우가 많아
    순진한 정의는 3분의 2 확률로 텍스트 없는 레코드에 착지한다.
    """

    def setUp(self) -> None:
        self.judge = load_judge()

    @staticmethod
    def records():
        def assistant(items, **kw):
            base = {"type": "assistant", "message": {"content": items}}
            base.update(kw)
            return base
        return [
            assistant([{"type": "text", "text": "before"}]),
            assistant([{"type": "tool_use", "name": "Agent", "id": "a1"}]),
            {"type": "user", "message": {"content": [
                {"type": "tool_result", "tool_use_id": "a1", "content": "…"}]}},
            assistant([{"type": "thinking", "thinking": "…"}]),      # 건너뛴다
            assistant([{"type": "tool_use", "name": "Read", "id": "r1"}]),  # 건너뛴다
            assistant([{"type": "text", "text": "이 에이전트가 X를 찾았다"}]),
        ]

    def test_gate3_skips_text_less_records(self) -> None:
        span = self.judge.span_after_tool(self.records(), "Agent")
        self.assertEqual(span, "이 에이전트가 X를 찾았다")

    def test_empty_span_is_a_failure_not_a_pass(self) -> None:
        self.assertEqual(self.judge.span_after_tool([], "Agent"), "")


class TestRubricLoading(unittest.TestCase):
    """루브릭은 REFERENCE.md 에서 읽는다 — 코드에 사본을 박으면 정본이 둘이 된다."""

    def setUp(self) -> None:
        self.judge = load_judge()
        self.reference = REFERENCE.read_text(encoding="utf-8")

    def test_prefix_line_is_prepended_to_every_rubric(self) -> None:
        for letter in "ABCD":
            block = self.judge.load_rubric(self.reference, letter)
            self.assertIn('{"Q1":"yes"', block.splitlines()[0])
            self.assertEqual(len(re.findall(r"(?m)^Q[1-4]\.", block)), 4, letter)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py`
Expected: FAIL — `FileNotFoundError: .../tests/ab_judge.py`

- [ ] **Step 3: 판정기를 구현한다**

`plugins/agent-transparency/tests/ab_judge.py`:

```python
#!/usr/bin/env python3
"""A/B 판정 단계 — 러너가 만든 out/<RUN>/ 산출물을 읽어 게이트 7개를 판정한다.

**실행하지 않는다.** 워커를 부르지 않고 산출물만 읽는다. 판정자 호출만이
외부 모델을 부르는 지점이다.

Usage:
    python3 ab_judge.py <out/RUN 디렉토리>
Exit:
    0 = 일곱 게이트 모두 통과 · 1 = 하나 이상 실패(어느 게이트가 왜인지 출력)
"""
from __future__ import annotations

import glob
import json
import os
import re
import subprocess
import sys

QUESTIONS = ("Q1", "Q2", "Q3", "Q4")
JUDGE_PREFIX = ('답은 JSON 한 줄이어야 한다: '
                '{"Q1":"yes","Q2":"no","Q3":"yes","Q4":"yes"}. 다른 것은 쓰지 마라.')
PLUGIN_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def expected_runs():
    """분모를 **먼저** 고정한다. 3/3 의 분모는 언제나 3이다."""
    runs = [(cond, task, i)
            for i in (1, 2, 3) for task in ("a", "b", "c", "d") for cond in ("off", "on")]
    runs += [("on", "e", i) for i in (1, 2, 3)]
    return runs


def parse_index(text):
    """`<cond> <task> <i> <sid> worker_rc=<n>` 및 플래그 줄."""
    parsed = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        cond, task = parts[0], parts[1]
        try:
            index = int(parts[2])
        except ValueError:
            continue
        entry = {"sid": None, "worker_rc": None, "flag": None}
        for token in parts[3:]:
            if token.startswith("worker_rc="):
                try:
                    entry["worker_rc"] = int(token.split("=", 1)[1])
                except ValueError:
                    entry["worker_rc"] = None
            elif "=" in token:
                entry["flag"] = token
            elif token != "-":
                entry["sid"] = token
        prior = parsed.get((cond, task, index))
        if prior and prior.get("flag") and entry["flag"] is None:
            entry["flag"] = prior["flag"]
        parsed[(cond, task, index)] = entry
    return parsed


def is_failed(parsed, key):
    """대응 줄이 없거나 · worker_rc 가 0 이 아니거나 · 필드 자체가 없으면 fail."""
    entry = parsed.get(key)
    if entry is None:
        return True
    # `flag` 는 None 일 수 있다 — `.get("flag", "")` 는 **키가 있고 값이 None** 인
    # 경우 None 을 그대로 돌려주므로 `or ""` 가 필요하다.
    flag = entry.get("flag") or ""
    if flag in ("setup=failed", "setup=skipped"):
        return True
    if flag.startswith("snapshot=ambiguous"):
        return True
    return entry.get("worker_rc") != 0


def transcript_for(sid):
    """정확히 1개가 아니면 그 실행은 모든 게이트 fail 이다.

    한 세션이 두 슬러그 디렉토리에 걸리는 상황이 실측으로 확인됐으므로,
    규칙이 없으면 어느 파일에서 구간을 잘랐는지가 미정으로 남는다.
    """
    hits = glob.glob(os.path.expanduser("~/.claude/projects/*/%s.jsonl" % sid))
    return hits[0] if len(hits) == 1 else None


def read_records(path):
    records = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except ValueError:
                pass
    return records


def _items(record):
    message = record.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    return content if isinstance(content, list) else []


def _text_of(record):
    if record.get("type") != "assistant":
        return ""
    parts = [i.get("text") or "" for i in _items(record)
             if isinstance(i, dict) and i.get("type") == "text"]
    return "\n".join(p for p in parts if p.strip())


def text_blocks(records):
    return [{"index": n, "text": _text_of(r)}
            for n, r in enumerate(records) if _text_of(r).strip()]


def span_after_tool(records, tool_name):
    """게이트 3 — 도구 결과 레코드 직후 첫 **텍스트 블록을 담은** 어시스턴트 메시지."""
    call_ids = set()
    for record in records:
        for item in _items(record):
            if isinstance(item, dict) and item.get("type") == "tool_use" \
                    and item.get("name") == tool_name:
                call_ids.add(item.get("id"))
    for n, record in enumerate(records):
        got_result = any(isinstance(i, dict) and i.get("type") == "tool_result"
                         and i.get("tool_use_id") in call_ids for i in _items(record))
        if not got_result:
            continue
        for later in records[n + 1:]:
            if _text_of(later).strip():
                return _text_of(later)
    return ""


def span_before_ask(records):
    """게이트 4 — AskUserQuestion 호출을 담은 메시지에서 그 호출보다 **앞의**
    텍스트 블록들 + 바로 직전의 텍스트 블록을 담은 어시스턴트 메시지."""
    for n, record in enumerate(records):
        items = _items(record)
        position = None
        for pos, item in enumerate(items):
            if isinstance(item, dict) and item.get("type") == "tool_use" \
                    and item.get("name") == "AskUserQuestion":
                position = pos
                break
        if position is None:
            continue
        head = "\n".join(i.get("text") or "" for i in items[:position]
                         if isinstance(i, dict) and i.get("type") == "text")
        previous = ""
        for earlier in reversed(records[:n]):
            if _text_of(earlier).strip():
                previous = _text_of(earlier)
                break
        return "\n".join(x for x in (previous, head) if x.strip())
    return ""


def span_after_command(records, needle):
    """게이트 5a·5b — 명령 호출 직후 첫 텍스트 블록을 담은 어시스턴트 메시지."""
    for n, record in enumerate(records):
        blob = json.dumps(record, ensure_ascii=False)
        if needle not in blob:
            continue
        for later in records[n + 1:]:
            if _text_of(later).strip():
                return _text_of(later)
    return ""


def span_all_text(records):
    """게이트 6 — 모든 텍스트 블록을 시간순으로 이은 것.

    결정이 어느 시점에 일어날지 미리 알 수 없다.
    """
    return "\n\n".join(b["text"] for b in text_blocks(records))


def load_rubric(reference_text, letter):
    """`### 루브릭 <letter>` 절의 코드펜스 + 접두 지시 한 줄.

    접두 문장이 없으면 판정자가 JSON 을 낼 이유가 없고, fail-closed 규칙에 따라
    모든 표가 no 가 되어 게이트가 구조적으로 통과 불가능해진다.
    """
    marker = "### 루브릭 %s" % letter
    start = reference_text.index(marker)
    rest = reference_text[start:]
    end = rest.find("\n### ")
    block = rest if end < 0 else rest[:end]
    fences = re.findall(r"```\n(.*?)```", block, re.S)
    body = ""
    for fence in fences:
        if re.search(r"(?m)^Q1\.", fence):
            body = fence.strip()
            break
    if not body:
        raise SystemExit("루브릭 %s 의 문항 블록을 찾지 못했다" % letter)
    return JUDGE_PREFIX + "\n" + body


def parse_vote(raw):
    """엄격 JSON 한 줄. 어긋나면 **그 표 전체를 no** 로 계산한다."""
    fallback = dict((q, "no") for q in QUESTIONS)
    text = (raw or "").strip()
    if not text:
        return fallback
    seen = []

    def hook(pairs):
        seen.extend(k for k, _ in pairs)
        return dict(pairs)

    try:
        data = json.loads(text, object_pairs_hook=hook)
    except ValueError:
        return fallback
    if not isinstance(data, dict):
        return fallback
    if len(seen) != len(set(seen)):          # 중복 키
        return fallback
    if set(data) != set(QUESTIONS):          # 누락 · 추가
        return fallback
    if any(data[q] not in ("yes", "no") for q in QUESTIONS):
        return fallback
    return dict((q, data[q]) for q in QUESTIONS)


def tally(votes):
    """문항별 다수결(2/3) 후 **모든 문항이 yes** 여야 통과."""
    if not votes:
        return False
    for question in QUESTIONS:
        yes = len([v for v in votes if v.get(question) == "yes"])
        if yes * 2 <= len(votes):
            return False
    return True


def ask_judge(rubric, block, model, effort):
    prompt = "%s\n\n%s" % (rubric, block)
    try:
        proc = subprocess.run(
            ["claude", "-p", "--model", model, "--effort", effort, prompt],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return dict((q, "no") for q in QUESTIONS)
    return parse_vote(proc.stdout.decode("utf-8", "replace"))


def judge_span(rubric, block, model, effort):
    if not block.strip():
        return False                          # 구간이 비면 fail — 설명이 없었다는 뜻이다
    return tally([ask_judge(rubric, block, model, effort) for _ in range(3)])


def main(argv):
    if len(argv) != 2:
        raise SystemExit("usage: ab_judge.py <out/RUN>")
    out = argv[1]
    manifest = dict(
        line.split("=", 1) for line in
        open(os.path.join(out, "manifest.txt"), encoding="utf-8").read().splitlines()
        if "=" in line)
    model, effort = manifest["judge_model"], manifest["judge_effort"]
    reference = open(os.path.join(PLUGIN_DIR, "REFERENCE.md"), encoding="utf-8").read()
    rubrics = dict((letter, load_rubric(reference, letter)) for letter in "ABCD")

    index_path = os.path.join(out, "index.txt")
    parsed = parse_index(open(index_path, encoding="utf-8").read()
                         if os.path.exists(index_path) else "")
    tests_text = ""
    tests_path = os.path.join(out, "tests.txt")
    if os.path.exists(tests_path):
        tests_text = open(tests_path, encoding="utf-8").read()

    results, reasons = {}, []

    def note(gate, ok, why):
        results[gate] = results.get(gate, True) and ok
        if not ok:
            reasons.append("게이트 %s: %s" % (gate, why))

    for cond, task, i in expected_runs():
        key = (cond, task, i)
        failed = is_failed(parsed, key)
        sid = (parsed.get(key) or {}).get("sid")
        path = transcript_for(sid) if (sid and not failed) else None
        if sid and not failed and path is None:
            failed = True
            reasons.append("lookup=ambiguous: %s" % (key,))
        records = read_records(path) if path else []

        if task == "a" and cond == "on":
            rows = len(re.findall(r"(?m)^\|", span_all_text(records)))
            note(1, (not failed) and rows == 0,
                 "%s — 최종 응답 부재 또는 표 행 %d개" % (key, rows))
        if task == "b":
            visible = "%s %d visible=0" % (cond, i) in tests_text
            oracle = "%s %d oracle=0" % (cond, i) in tests_text
            intact = "%s %d hash=ok" % (cond, i) in tests_text
            note(2, (not failed) and visible and oracle and intact,
                 "%s — visible=%s oracle=%s hash=%s" % (key, visible, oracle, intact))
        if task == "c" and cond == "on":
            note(3, (not failed) and judge_span(
                rubrics["A"], span_after_tool(records, "Agent"), model, effort), str(key))
        if task == "d" and cond == "on":
            note(4, (not failed) and judge_span(
                rubrics["B"], span_before_ask(records), model, effort), str(key))
        if task == "b" and cond == "on":
            note(6, (not failed) and judge_span(
                rubrics["D"], span_all_text(records), model, effort), str(key))
        if task == "e":
            answer = span_after_command(records, "agent-transparency:standup")
            snapshot = os.path.join(out, "pre-standup-%d.jsonl" % i)
            questions = []
            if os.path.exists(snapshot):
                for record in read_records(snapshot):
                    for item in _items(record):
                        if isinstance(item, dict) and item.get("type") == "tool_use" \
                                and item.get("name") == "AskUserQuestion":
                            for q in (item.get("input") or {}).get("questions") or []:
                                if isinstance(q, dict) and q.get("question"):
                                    questions.append(q["question"])
            quoted = [q for q in questions if q and q in answer]
            note("5a", (not failed) and len(quoted) >= 1,
                 "%s — 인용된 결정 질문 %d건" % (key, len(quoted)))
            inventory = ""
            for record in records:
                blob = json.dumps(record, ensure_ascii=False)
                if "scope:   repo=" in blob:
                    inventory = blob
                    break
            two_blocks = "<인벤토리>\n%s\n\n<응답>\n%s" % (inventory, answer)
            note("5b", (not failed) and judge_span(rubrics["C"], two_blocks, model, effort),
                 str(key))

    for gate in (1, 2, 3, 4, "5a", "5b", 6):
        results.setdefault(gate, False)
        print("gate %s: %s" % (gate, "PASS" if results[gate] else "FAIL"))
    for reason in reasons:
        print("  - %s" % reason)
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `python3 -m unittest plugins/agent-transparency/tests/test_ab_runner_contract.py -v`
Expected: 전부 PASS — `TestCoverageLedger` 도 이제 통과한다(`tests/ab_gate.sh` · `tests/oracle/` 가 생겼다).

- [ ] **Step 5: 문법과 도움말을 확인한다**

```bash
python3 -m py_compile plugins/agent-transparency/tests/ab_judge.py && echo "컴파일 OK"
python3 plugins/agent-transparency/tests/ab_judge.py 2>&1 | head -2
```
Expected: `컴파일 OK` · `usage: ab_judge.py <out/RUN>`

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "feat(agent-transparency): A/B 판정 단계 스크립트(판정 단계 1-7 결정론화)"
```

---

## Task 13: probe 실행 3종 · 락 (AC48④ · AC35⑥ · AC39)

**Files:**
- Create: `plugins/agent-transparency/tests/probe/agent_type.txt`
- Create: `plugins/agent-transparency/tests/probe/skill_body.txt`
- Create: `plugins/agent-transparency/tests/probe/command_name.txt`
- Modify: `plugins/agent-transparency/tests/test_subagent_hook.py` (AC48④)
- Modify: `plugins/agent-transparency/tests/test_plugin_contract.py` (AC35⑥ · AC39)

**Interfaces:**
- Consumes: Task 3·4·8 의 훅·agent·skill
- Produces: 네 줄 형식 probe 파일 셋 — **1줄 관측값 · 2줄 probe 명령 · 3줄 원출력 · 4줄 `claude --version`**

**이 파일들이 무엇을 주장하고 무엇을 주장하지 않나:** 네 줄 모두 구현자가 손으로 적을 수 있으므로 **위조 불가능성을 주장하지 않는다.** 이것은 *"실행했다"* 의 증명이 아니라 **재현 메모**이고, 이 락이 막는 것은 *"아무 기록도 없이 넘어가는 것"* 까지다. 실제 측정을 요구하는 것은 OQ-AE·OQ-AF 의 머지 전 확인이다.

**왜 단위 테스트가 probe 를 직접 실행하지 않나:** 스위트 안에서 실물 CLI 실행을 요구하면 spec §10-1 이 방금 고친 실패(의존 미설치 환경에서 게이트가 구조적으로 통과 불가)를 재생산한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_subagent_hook.py` 에 추가:

```python
class TestAgentTypeProbe(unittest.TestCase):
    """AC48④ — probe 파일이 계약 형식대로 있고 첫 줄이 **훅 상수**와 일치한다.

    비교 대상은 agent frontmatter 의 `name:`(bare `transcript-reader`)이 아니다 —
    둘의 표기가 다르므로 술어를 여기서 못박는다.

    **왜 필요한가**: `agent_type` 은 문서화되지 않은 플랫폼 동작이라 드리프트할
    수 있다. ①②③만 있으면 합성 문자열 검사라 플랫폼이 라벨을 바꿔도 green 인
    채로 §6.2 의 자기모순이 되살아난다. ④가 그 드리프트를 red 로 바꾸는
    유일한 지점이다.
    """

    PROBE = PLUGIN_DIR / "tests" / "probe" / "agent_type.txt"

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      self.PROBE.read_text(encoding="utf-8").splitlines() if ln.strip()]

    def test_four_lines(self) -> None:
        """뒤 세 줄이 없으면 red — 관측값만 있으면 재현할 수 없다."""
        self.assertGreaterEqual(len(self.lines), 4)

    def test_first_line_matches_hook_constant(self) -> None:
        self.assertEqual(self.lines[0], load_hook().SELF_AGENT_TYPE)

    def test_records_probe_command_and_raw_output_and_version(self) -> None:
        self.assertIn("claude", self.lines[1])
        self.assertTrue(self.lines[2])
        self.assertRegex(self.lines[3], r"\d+\.\d+\.\d+")
```

`tests/test_plugin_contract.py` 에 추가:

```python
class TestSkillBodyProbe(unittest.TestCase):
    """AC35⑥ — SKILL.md 본문이 fork 에 도달하는지의 관측 기록.

    OQ-AE 에는 fail-closed 락이 있는데 이쪽에 없던 비대칭을 리뷰가 적발했다.
    """

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      read("tests/probe/skill_body.txt").splitlines() if ln.strip()]

    def test_four_line_format(self) -> None:
        self.assertGreaterEqual(len(self.lines), 4)
        self.assertIn("claude", self.lines[1])
        self.assertRegex(self.lines[3], r"\d+\.\d+\.\d+")

    def test_first_line_is_not_body_unreachable(self) -> None:
        """첫 줄이 '본문 미도달' 이면 red — 그러면 규칙을 한 곳에 둔 결정이
        **규칙을 아무 데도 두지 않은 것**이 되고, 인벤토리 전달 경로도 무너진다."""
        self.assertNotIn("본문 미도달", self.lines[0])

    def test_records_both_observations(self) -> None:
        """관측은 두 값이다 — ⓐ 본문 텍스트 도달 ⓑ 주입 결과 도달."""
        self.assertIn("본문", self.lines[0])
        self.assertIn("주입", self.lines[0])


class TestCommandNameProbe(unittest.TestCase):
    """AC39 — 명령 이름이 내장 command 와 겹치지 않는다.

    바이너리 문자열 추출만으로는 **번들 prompt 계열 명령을 못 본다**
    (실측: 존재하는 `/review`·`/pr-comments` 가 그 방식으로 0회로 나왔다).
    그래서 실물 probe 기록이 유일한 검증 수단이다.
    """

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      read("tests/probe/command_name.txt").splitlines() if ln.strip()]

    def test_four_line_format(self) -> None:
        self.assertGreaterEqual(len(self.lines), 4)

    def test_bare_name_is_unknown_without_the_plugin(self) -> None:
        self.assertIn("Unknown command", self.lines[0])
        self.assertIn("standup", self.lines[0])

    def test_command_file_uses_that_name(self) -> None:
        self.assertTrue((PLUGIN_DIR / "commands" / "standup.md").is_file())
```

- [ ] **Step 2: 실패를 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
```
Expected: 둘 다 FAIL — `FileNotFoundError: .../tests/probe/agent_type.txt`

- [ ] **Step 3: `agent_type` probe 를 실행한다**

**측정 장치는 플러그인의 사본이다.** 제품 트리에 로깅 훅을 넣지 않는다. 사본의 **이름이 같아야** `agent_type` 네임스페이스가 실물과 같다:

```bash
PROBE="$(mktemp -d)"; PROBE="$(cd "$PROBE" && pwd -P)"
cp -R plugins/agent-transparency "$PROBE/agent-transparency"
cat > "$PROBE/agent-transparency/hooks/log-agent-type.py" <<'PY'
import json, os, sys
try:
    payload = json.loads(sys.stdin.read())
except Exception:
    payload = {}
with open(os.environ["AT_PROBE_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"agent_type": payload.get("agent_type")}, ensure_ascii=False) + "\n")
PY
python3 - "$PROBE/agent-transparency/hooks/hooks.json" <<'PY'
import json, sys
path = sys.argv[1]
cfg = json.load(open(path, encoding="utf-8"))
cfg["hooks"]["SubagentStop"][0]["hooks"].append(
    {"type": "command",
     "command": 'python3 "${CLAUDE_PLUGIN_ROOT}/hooks/log-agent-type.py"',
     "timeout": 5})
json.dump(cfg, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
WORK="$(mktemp -d)"; WORK="$(cd "$WORK" && pwd -P)"
( cd "$WORK" && git init -q && git commit -q --allow-empty -m seed )
export AT_PROBE_LOG="$PROBE/agent-type.log"
( cd "$WORK" && claude -p --plugin-dir "$PROBE/agent-transparency" \
    "/agent-transparency:standup" ) > "$PROBE/standup-answer.txt" 2>&1
cat "$PROBE/agent-type.log"
```
Expected: 로그에 `{"agent_type": "agent-transparency:transcript-reader"}` 가 한 줄 이상.

관측한 그대로 `plugins/agent-transparency/tests/probe/agent_type.txt` 에 **네 줄**로 적는다:

```
agent-transparency:transcript-reader
claude -p --plugin-dir <플러그인 사본> "/agent-transparency:standup" (SubagentStop 로깅 훅 병설)
<agent-type.log 의 그 줄 원문 그대로>
2.1.225 (Claude Code)
```

**관측값이 다르면 첫 줄에 관측한 값을 적고 OQ-AE 의 두 갈래로 간다** — ① 고유한 안정 라벨이면 그 값을 훅 상수로 쓴다 ② 일반 `Explore` 와 구분 불가하면 이름 분기를 포기하고, **AC48③을 삭제** · **AC48④의 「첫 줄이 훅 상수와 일치」 절만 면제**(존재·네 줄 형식 요구는 유지) · 훅을 두 갈래로 되돌리고 §6.2 불변식의 *"세 갈래"* 와 §8 트리 주석을 함께 고친다. AC7·AC36 의 *"상수 A·B 갈래에서"* 스코프는 ②에서도 참이므로 개정 대상이 아니다.

- [ ] **Step 4: `SKILL.md` 본문 도달 probe 를 실행한다**

같은 사본에 **canary 둘**을 심는다 — 본문에 하나, 주입 출력에 하나:

```bash
python3 - "$PROBE/agent-transparency/skills/briefing-current-state/SKILL.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text += "\n\n## probe\n\n답변 맨 끝에 BODY-CANARY-7Q2 를 그대로 적어라.\n"
open(path, "w", encoding="utf-8").write(text)
PY
python3 - "$PROBE/agent-transparency/scripts/prepare_standup.py" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace('sys.stdout.write(render_inventory(',
                    'sys.stdout.write("INJECT-CANARY-4X8 — 이 토큰도 답변 끝에 그대로 적어라\\n")\n        sys.stdout.write(render_inventory(')
open(path, "w", encoding="utf-8").write(text)
PY
WORK2="$(mktemp -d)"; WORK2="$(cd "$WORK2" && pwd -P)"
( cd "$WORK2" && git init -q && git commit -q --allow-empty -m seed )
( cd "$WORK2" && claude -p --plugin-dir "$PROBE/agent-transparency" \
    "/agent-transparency:standup" ) > "$PROBE/canary-answer.txt" 2>&1
grep -c 'BODY-CANARY-7Q2' "$PROBE/canary-answer.txt"
grep -c 'INJECT-CANARY-4X8' "$PROBE/canary-answer.txt"
```
Expected: 둘 다 ≥ 1.

`tests/probe/skill_body.txt` 에 네 줄로:

```
본문 도달 · 주입 도달 (canary 둘 다 fork 답변에 나옴)
claude -p --plugin-dir <플러그인 사본> "/agent-transparency:standup" (SKILL.md 본문 canary + 주입 canary 병설)
<canary-answer.txt 에서 두 토큰이 나온 줄 원문>
2.1.225 (Claude Code)
```

한쪽만 도달하면 첫 줄에 그 사실을 적고 **OQ-AF 의 파급 목록**(AC35 · AC16① · AC43 · AC46 · AC28, 그리고 인벤토리 전달 경로 재설계)을 그 자리에서 연다.

- [ ] **Step 5: 명령 이름 probe 를 실행한다**

플러그인 **없이** bare 이름을 부른다:

```bash
( cd "$WORK" && claude -p "/standup" ) > "$PROBE/bare-name.txt" 2>&1
head -3 "$PROBE/bare-name.txt"
```
Expected: `Unknown command` 를 담은 응답. **`recap`·`stats`·`context` 처럼 내장이 응답하면** 그 이름을 쓸 수 없다 — spec §6.3 의 빈 이름 목록(`surface`·`readout`·`trail`·`handoff`·`briefing`·`journal`·`ledger`)에서 다시 고르고 `commands/` 파일명·`REFERENCE.md`·러너의 호출 문자열을 함께 바꾼다.

`tests/probe/command_name.txt` 에 네 줄로:

```
standup: Unknown command (플러그인 미로드 상태 bare 호출)
claude -p "/standup" (플러그인 없이)
<bare-name.txt 의 해당 줄 원문>
2.1.225 (Claude Code)
```

- [ ] **Step 6: 흔적을 지운다**

```bash
rm -rf "$PROBE" "$WORK" "$WORK2"; unset AT_PROBE_LOG
git status --short   # probe/*.txt 세 개만 새로 보여야 한다
```

- [ ] **Step 7: 테스트가 통과하는지 확인한다**

Run:
```bash
python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py -v
python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py -v
```
Expected: 둘 다 PASS

- [ ] **Step 8: 커밋**

```bash
git add plugins/agent-transparency
git commit -m "test(agent-transparency): probe 실측 3종 + 드리프트 락(AC48④·AC35⑥·AC39)"
```

---

## Task 14: README · 문서 · 마감 (AC25 · D10 · D11)

**Files:**
- Create: `plugins/agent-transparency/README.md`
- Modify: `plugins/agent-transparency/CHANGELOG.md`
- Modify: `docs/plugin-authoring.md`
- Modify: `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` (§13 브랜치 표기)
- Modify: `plugins/agent-transparency/tests/test_plugin_contract.py` (AC25)

**Interfaces:**
- Consumes: 앞의 모든 task
- Produces: 없음 (마감)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_plugin_contract.py` 에 추가:

```python
class TestReadme(unittest.TestCase):
    """AC25 — README 맨 앞의 **다섯 항목**.

    OQ-J 가 README 공개를 요구하는데 이 AC 가 그것을 검사하지 않으면 요구가
    문서에만 남는다.
    """

    ITEMS = {
        "force-for-plugin 경고": "끄려면 플러그인 전체를 비활성화",
        "설치 이전 구간": "설치 이전 작업에는 이 플러그인이 만든 설명이 없",
        "OQ-J 잔여 위험": "어떤 비밀 필터도 없",
        "Principles Instantiated": "## Principles Instantiated",
        "Hooks Installed": "## Hooks Installed",
    }

    def setUp(self) -> None:
        self.text = read("README.md")

    def test_all_five_items_present(self) -> None:
        for name, fragment in self.ITEMS.items():
            self.assertIn(fragment, self.text, name)

    def test_warning_is_near_the_top(self) -> None:
        head = "\n".join(self.text.splitlines()[:25])
        self.assertIn("끄려면 플러그인 전체를 비활성화", head)

    def test_mutation_each_item_removal_is_detected(self) -> None:
        for name, fragment in self.ITEMS.items():
            self.assertNotIn(fragment, self.text.replace(fragment, ""), name)

    def test_post_merge_checklist_is_operationalised(self) -> None:
        """D11 — OQ-R 의 '머지 후 수동 확인' 이 수행 가능한 형태여야 한다."""
        self.assertIn("## 머지 후 수동 확인", self.text)
        self.assertIn("- [ ]", self.text.split("## 머지 후 수동 확인", 1)[1])
```

- [ ] **Step 2: README 를 쓴다**

`plugins/agent-transparency/README.md`:

````markdown
# agent-transparency

> **이해부채를 줄인다.** 위임한 에이전트가 무엇을 했고 판단이 무엇에 근거하는지를,
> 결정·판정 시점에 먼저 드러낸다.

## ⚠️ 설치 전에 알아야 할 것 셋

1. **이 플러그인의 output style 을 끄려면 플러그인 전체를 비활성화해야 한다.**
   `force-for-plugin: true` 라서 설치하면 자동 적용되고 사용자의 `outputStyle`
   설정을 덮어쓴다. 플러그인을 끄면 훅과 `/standup` 도 함께 꺼진다. devbrew 의
   kill switch 규약은 훅에만 걸 수 있다 — 플랫폼이 플러그인 디렉토리에서 직접
   읽어가므로 환경변수가 개입할 지점이 없다.
2. **설치 이전 작업에는 이 플러그인이 만든 설명이 없다.** `/standup` 이 읽는
   주재료는 훅과 output style 이 쌓은 설명 블록인데, 설치 전 구간에는 그것이
   없다. 그리고 **답변은 그 사실을 알 수 없다** — 인벤토리의 `blocks` 는 모든
   어시스턴트 텍스트 블록이지 *이 플러그인이 유발한 설명* 이 아니다(OQ-T).
3. **이 플러그인이 대화창에 내는 설명에는 어떤 비밀 필터도 없다.** 훅 · output
   style · `/standup` 세 경로 모두 그렇다. 모델 출력에 필터를 거는 지점이
   플랫폼에 없고, 프롬프트로 막으면 능력 억제가 된다. **수용된 잔여 위험**이며
   그 계산은 설계 문서 §3 에 있다(OQ-J).

## 무엇을 하나

| 부품 | 하는 일 |
|---|---|
| `output-styles/agent-transparency.md` | 일곱 순간에 무엇을 담아야 하는지 규정 + 내장 `Explanatory` 흡수 |
| `hooks/subagent-explain.py` | 에이전트가 끝난 직후 설명 자리를 만든다 (검사·차단 없음) |
| `/standup` | 쌓인 설명 + git 으로 *"지금 어떤 상태인가"* 에 답한다 |

**상태 파일을 만들지 않는다.** 훅은 상수를 출력하고 준비 스크립트는 읽기만 한다.

## 사용법

```
/standup                      # 이 브랜치의 지금 상태
/standup main 브랜치도 같이    # 범위 조정은 자연어로 — 스크립트 플래그가 아니다
/standup 최근 3일만
```

## Hooks Installed

| 훅 | 왜 skill 이 아닌가 |
|---|---|
| `SubagentStop` → `hooks/subagent-explain.py` | 에이전트 종료는 **모델이 알아서 반응할 수 없는 순간**이다. 이 이벤트만이 그 시점에 컨텍스트를 주입할 수 있고(다른 후보 이벤트는 전부 주입 불가), skill 은 모델이 부를 때만 돈다 |

kill switch: `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` ·
`DEVBREW_SKIP_HOOKS=agent-transparency:subagent-explain` — **훅에만 적용된다.**

## Principles Instantiated

- **Law 1 (Clarity Before Code)** — 일곱 순간의 필수 항목이 표로 열거돼 있고,
  `tests/test_output_style.py` 가 그 표를 mutation 과 함께 잠근다.
- **Law 2 (Writer ≠ Reviewer)** — `/standup` 의 전용 agent 가 fail-closed
  `tools: Read, Glob, Grep` allowlist 를 선언한다. 쓰기·실행·네트워크 도구가
  **없다** — `disallowedTools` 단독은 시간축으로 fail-open 이라 쓰지 않는다.
- **Law 3 (Every Cycle Leaves the System Smarter)** — 이 플러그인이 하는 일
  자체가 compounding 이다. 설명이 트랜스크립트에 쌓이고 `/standup` 이 그것을
  다음 세션에 되돌려 준다.
- **P13 (state 배치)** — state 파일을 만들지 않는다. 트랜스크립트가 이미 그
  역할을 한다.
- **억제 금지** — 읽는 양·설명 길이·용어 사용에 상한을 걸지 않는다. 용어 규칙은
  금지가 아니라 **상환 의무**다.

## 알려진 한계

`REFERENCE.md` 의 「미해결(OQ) 식별자 목록」이 전부다. 특히 OQ-J(비밀 필터 없음) ·
OQ-T(설치 이전 구간) · OQ-AB(읽은 수를 기계가 검증 못 함) · OQ-AD(나열 상한 밖
파일은 후보 검증을 안 거친다)를 먼저 읽을 것.

## 머지 후 수동 확인

**설치 후 bare 호출 경로는 A/B 측정에 포함되지 않는다**(OQ-R) — 러너는
`--plugin-dir`(미설치)로 돌고 그 환경에서는 명령이 네임스페이스 형태로만 잡힌다.
머지 직후 **PR 작성자**가 한 번 확인한다:

- [ ] 플러그인을 설치한 뒤 `/standup` 을 **bare 이름으로** 불러 응답이 오는가
- [ ] 그 응답 첫 줄에 `blocks: N 중 M 개를 읽었다` 형태의 수가 나오는가
- [ ] `SubagentStop` 훅이 `/standup` 의 fork 에 대해 설명 자리를 **안 만드는가**
      (만들면 `agent_type` 이 드리프트한 것 — `tests/probe/agent_type.txt` 재측정)
````

- [ ] **Step 3: `docs/plugin-authoring.md` 에 output style 절을 더한다**

이 문서는 35줄이고 `##` 헤딩을 쓰지 않는다 — **굵은 lead-in 블록** 형식을 따른다. `**Merge 전:**` 줄 **바로 위**에 넣는다:

```markdown
**output style 컴포넌트** — devbrew 첫 사례는 [`plugins/agent-transparency/`](../plugins/agent-transparency/). `output-styles/<name>.md` 한 파일이며 frontmatter 네 필드가 전부다:

- `name` · `description` — `description` 은 `plugin.json` 과 같은 문구로 두는 것이 관행(중복 서술이 갈리는 것을 막는다).
- **`keep-coding-instructions: true` — 빠뜨리면 안 된다.** 기본값이 `false`라 생략하면 Claude Code 내장 소프트웨어 엔지니어링 지침이 **통째로 사라진다**. 그것이 devbrew 가 금지하는 능력 억제다.
- `force-for-plugin: true` — 설치하면 자동 적용되고 사용자의 `outputStyle` 설정을 **덮어쓴다**. 대가: 스타일만 따로 끄는 길이 없고(플러그인 `settings.json`은 `agent`·`subagentStatusLine` 키만 지원), 여러 플러그인이 켜면 **먼저 로드된 것이 이긴다**. README 맨 앞에 경고를 둘 것.

**output style 은 subagent 에 닿지 않는다.** 메인 대화의 시스템 프롬프트만 바꾸므로, subagent 나 `context: fork` skill 이 따라야 할 규칙은 그쪽 파일에 **따로** 두고 파리티 테스트로 묶어야 한다(사본이 셋이 되면 파리티가 못 보는 자리가 생긴다).
```

- [ ] **Step 4: CHANGELOG 를 마감하고 spec 의 브랜치 표기를 고친다**

`CHANGELOG.md` 를 `## [0.1.0] — 2026-08-08` 로 승격하고 Added 에 세 부품·머지 게이트·38+1 AC 를 한 줄씩 적는다.

spec §13 Metadata 의 `| 브랜치 | feature/comprehension-debt-plugin |` 를 실물 `worktree-feature+comprehension-debt-plugin` 로 고친다(D10). 표기가 갈려 있으면 다음 독자가 어느 쪽을 정본으로 읽을지 모른다.

- [ ] **Step 5: 전체 스위트를 돌린다**

```bash
for t in output_style subagent_hook prepare_standup readability_parity plugin_contract ab_runner_contract; do
  echo "=== $t ==="
  python3 -m unittest "plugins/agent-transparency/tests/test_$t.py" 2>&1 | tail -3
done
bash -n plugins/agent-transparency/tests/ab_gate.sh && echo "러너 문법 OK"
python3 -m py_compile plugins/agent-transparency/tests/ab_judge.py && echo "판정기 컴파일 OK"
```
Expected: 여섯 파일 모두 `OK` · 러너·판정기 통과. **하나라도 red 면 여기서 멈춘다** — 머지 게이트(AC29)는 스위트가 green 인 상태에서만 의미가 있다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/agent-transparency docs/plugin-authoring.md docs/superpowers/specs/2026-08-05-agent-transparency-design.md
git commit -m "docs(agent-transparency): README + 저술 가이드 output style 절 + v0.1.0 마감(AC25)"
```

---

## 머지 게이트 (AC29) — 별도 실행

스위트가 green 이 된 뒤, **머지 전 1회**:

```bash
export AB_MODEL=claude-sonnet-5 AB_EFFORT=medium
export AB_JUDGE_MODEL=claude-sonnet-5 AB_JUDGE_EFFORT=medium
bash plugins/agent-transparency/tests/ab_gate.sh
echo "exit=$?"
```

워커 24회 + `/standup` 3회 + 판정 36회. 일곱 게이트가 모두 통과해야 `exit=0`.
**실패하면 「계측을 고쳐도 되는 조건」 세 규칙을 따른다** — 산출물을 보존하고,
고친 뒤 **전체 배터리를 다시 돌리며**, 루브릭·판정 구간 수정은 별도 커밋으로
분리한다. 실패 응답이 자기 수정인 게이트는 게이트가 아니다.
