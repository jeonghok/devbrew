# R5 지휘자 — 계획 1: 로드맵 형식 · 상태 계산 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로드맵을 항목별로 구조화하고, 상태 계산이 레포 설정 · 기본 브랜치 · 여러 브랜치 · 구현 이후 단계 · 산출물을 읽게 하며, 지휘자 기계 상태의 형식 · 넘김 계산 모듈과 에픽 하나로 내려가는 보기를 만든다.

**Architecture:** 해석기(`roadmap_model.py`)가 칸 아래 하위 항목 · 새 선택 칸 · 새 재분해 이력을 읽고, 생성기(`roadmap_render.py` · `roadmap_write.py`)가 같은 형식을 쓰며 옛 로드맵을 옮기는 `migrate` 를 갖는다. 상태 계산(`roadmap_status.py`)은 git 만 읽는 성질을 지키며 기본 브랜치를 `origin/HEAD` 에서, 설계문서 · 계획 폴더를 로드맵 frontmatter 에서(없으면 `repo_defaults.py` 의 기본값) 읽고 브랜치마다 · 계획마다 단계를 센다. 이 기계에서만 뜻이 있는 것은 `conductor_state.py` 한 모듈이 형식을 정하고, 화면(`control_plane.py`)이 그것과 실행 원장 · `gh` 를 캐시 밖에서 얹는다.

**Tech Stack:** Python 3.9 표준 라이브러리, bash 3.2 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` — 이 계획은 §11 의 계획 1(형식 · 상태)이다. 이 계획의 AC: AC1 · AC2 · AC3 · AC4 · AC5 · AC6 · AC7 · AC8 · AC9 · AC10 · AC11 · AC12 · AC13 · AC14 · AC39 · AC40 · AC43(기계 상태 형식과 넘김 계산 모듈) · AC38. 나머지 AC 는 계획 2 · 3 몫이다.

## Global Constraints

- `python3` 는 3.9.6 이다 — `match` 문, 런타임 `X | Y` 타입 금지(`from __future__ import annotations` 로 주석에만). 표준 라이브러리만 쓴다(새 패키지 의존 금지 — 설계 §8).
- `plugins/**/*.py`(테스트 포함)에 `"python3"` 문자열을 쓰지 않는다 — 하위 프로세스는 `sys.executable` (`shared/tests/test_python_floor.sh`).
- 모든 `open(` · `.read_text(` · `.write_text(` 에 `encoding="utf-8"` 를 준다. 주석에도 `open(` 을 쓰지 않는다(글자 검사 — `plugins/quality-gates/tests/test_utf8_explicit.py`).
- `re.compile` 리터럴이 `## 6. 사용자 원문` 앞 세 글자 이상과 맞으면 안 된다(`tests/test_check_brief.sh` §6 단일화). 절 머리는 문자열 메서드로 찾는다.
- 같은 20줄(200자 이상) 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`) — 셸 테스트의 픽스처 함수는 새 파일로 복사하지 말고 그 함수가 사는 파일에 장면을 더한다.
- 레포 전용 값을 박지 않는다. 설계문서 · 계획 폴더 기본값(`docs/superpowers/specs/` · `docs/superpowers/plans/`), SDD 작업 폴더(`.superpowers/sdd/`), 지휘자 상태 폴더 이름(`conductor`)은 `plugins/spec-distill/scripts/repo_defaults.py` 에만 글자로 둔다. 기본 브랜치는 `refs/remotes/origin/HEAD` 에서 읽는다 — `origin/main` · `refs/remotes/origin/main` 을 코드에 박지 않는다(AC14 · AC39).
- `roadmap_status.py` 는 git 만 읽고 네트워크에 나가지 않는다(fetch 금지). `gh` 는 `control_plane.py` 의 `show` · `show --tasks` 에서만 시간 한도 안에서 부르고, 상태줄은 부르지 않는다.
- 새 셸 테스트 파일은 `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755` 인지 확인한다. 셸 테스트는 리포 루트에서 `bash <파일>`, python 테스트는 리포 루트에서 `python3 -m unittest <파일>` 로 돈다. 스위트 둘을 같은 시각에 돌리지 않는다.
- 사람에게 보이는 출력은 한국어다. 판정 · 개수 줄은 스크립트 문장 그대로 보인다(`shared/style/plain-language.md`).
- 커밋은 Conventional Commits, 설명은 한국어, `type`·`scope` 영어(예: `feat(spec-distill): 로드맵 칸 아래 하위 항목을 읽는다`). 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md` 트레일러를 단다.
- 외부 플러그인(superpowers) 파일과 `plugins/quality-gates/` 는 고치지 않는다(설계 Constraints · D1.3).
- 버전: 이 PR 은 `plugins/spec-distill/.claude-plugin/plugin.json` 의 minor 를 하나 올린다(새 표면 — `roadmap_write.py migrate` · 에픽 보기 · 종료 코드 4). 번호는 머지 직전에 origin 기본 브랜치의 값을 보고 정한다(Task 15).
- 실행 방식의 마지막 전체 리뷰에는 설계문서 `## Acceptance Criteria` 중 이 계획의 AC(위 **Spec:** 줄의 목록)를 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일(SDD 작업 폴더의 `ac-report.md`)에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다(Task 15).

## Review Focus

1. 기본 브랜치 이름이 `main` 이 아닌 레포, 그리고 `origin/HEAD` 가 없는 클론(빈 레포를 클론한 뒤 push 하면 git 이 `origin/HEAD` 를 만들지 않는다) — 단계는 같게 나오거나, 「기본 브랜치를 알 수 없다」 사유로 rc 3 이어야 한다. 조용히 「로드맵 없음」으로 끝나면 안 된다(Task 5 테스트).
2. 하위 항목 칸과 한 줄 칸이 섞인 로드맵을 재분해(`update`)할 때 바뀌지 않은 블록은 바이트 그대로이고, 칸 값이 목록인 블록도 extract → 표 → render 왕복이 같다(Task 4 테스트).
3. 한 에픽의 둘째 계획 브랜치가 앞 계획의 `## 구현 대조 — <앞 계획>` 절을 물려받아도 그 브랜치는 「구현 끝」이 아니다(Task 7 테스트).
4. 상태줄은 `gh` 를 부르지 않는다. `gh` 가 없거나 실패해도 지도는 나오고 PR 줄이 「알 수 없음」이다(Task 10 테스트).
5. 기계 상태 파일이 깨졌을 때 빈 상태로 읽지 않는다 — 지도는 나오고 「기계 상태를 읽지 못했다」 한 줄이 보인다(Task 3 · Task 10 테스트).

## 계획 단계 판정

설계가 정하지 않은 것을 이 계획이 정한 자리다. 실행 중 반증되면 원장에 `Ruling:` 으로 적고 바꾼다.

- 「병렬」 칸 — 사용자 재결정 「화면에서만 계산 (권장)」(설계문서 `## 결정 기록` 에 적었다). 생성기는 계산값을 칸에 적지 않고, 에픽 보기가 동시 가능 에픽을 매번 계산한다(Task 9 · Task 11).
- `범위:` 의 하위 항목은 `  - 한다: <…>` · `  - 안 한다: <…>` 두 줄이다. 분해안 표 칸 「한다 X / 안 한다 Y」 와 서로 바꿔 쓸 수 있어 표 인터페이스가 그대로다. ` · ` 로 더 쪼개지 않는다 — 괄호 밖 ` · ` 로 쪼개면 「squash · rebase 머지 자동 판정」 같은 항목이 뜻 없이 갈린다. 사람이 손으로 한다: 항목을 여럿 적은 블록은 읽히고, 그 블록이 재분해로 바뀌면 생성기가 두 줄로 다시 쓴다.
- 새 선택 칸은 분해안 표의 뒤 여섯 칸(`크기` · `병렬` · `순서 이유` · `근거` · `흐름` · `산출물`)이다. 표는 칸 열하나(옛 꼴)와 열일곱 둘 다 읽고, 쓸 때는 선택 칸 값이 하나라도 있을 때만 열일곱으로 쓴다(옛 표 · 테스트가 바이트 그대로).
- 재분해 이력의 새 꼴: `### <날짜> · <사유>` · `- 바뀜: …`(생성기는 한 줄, 사람은 하위 항목 가능) · `- 원문:` + `  - 「…」`(줄마다 하나). `--approval` 은 여러 번 줄 수 있다(사용자 말 하나에 하나). 인용은 겹친 「…」 를 바깥 하나로 센다(이 로드맵에 「… 「끝에 할 일 하나」 …」 가 있다).
- 이 로드맵 옮기기는 둘로 나눈다 — 블록은 `roadmap_write.py migrate` 가 기계적으로, 재분해 이력은 사람 판단(구현 agent)으로 쓰되 인용 집합이 같은지 명령으로 확인한다(Task 13). 이력은 사용자 말과 그 말에 붙은 설명이 얽혀 있어 기계로 나누면 문장이 깨진다.
- 「로드맵이 아직 기본 브랜치에 없음」의 종료 코드는 4 다(설계: 「다른 줄 · 다른 종료 코드」). `control_plane.py show --tasks` 도 rc 4 를 낸다.
- N17 의 「셀 수 없음」은 블록의 경고 줄(종료 코드 1)로 센다 — 검사 불가(3)로 세면 작업 목록 맞추기가 영구히 막힌다. 그래서 이 로드맵의 머지된 묶음 아닌 블록(P1 · P2 · R0)은 경고 줄을 하나씩 갖는다.
- `산출물:` 블록의 산출물에 `## 번호 대조` 절이 없으면 검사 불가가 아니라 N17 과 같은 경고 줄이다.
- PR 단계: 상태 계산이 「구현 끝」을 내고 화면이 기계 상태 캐시(없으면 `gh`)에서 PR 이 열려 있음을 보면 「PR」로 바꾼다. 둘 다 없으면 단계는 「구현 끝」 그대로 두고 PR 줄을 「알 수 없음」으로 보인다 — 단계 자체를 「알 수 없음」으로 바꾸면 화면 전체가 검사 불가가 된다.
- 판정 줄은 「구현 중」 이후 단계(일부 머지 포함)에서만 보이고, 「머지됨」은 설계문서 `## 판정` 이 있을 때만 보인다 — 판정 기록이 생기기 전에 머지된 에픽마다 「셀 수 없음」을 늘어놓지 않는다.
- 넘김 확인 줄은 `- 넘김 확인 · <준 에픽> · <항목 해시 8자> · <근거>` 다. 항목 글에 ` · ` 가 들어 있어 글 그대로는 칸을 가를 수 없다.
- 기계 상태 표지 파일 이름은 `conducting-by` 다(리뷰 원장의 `reviewing-by` 와 같은 방식, `ledger_marker.py` 의 읽기 · 원자 쓰기 함수를 쓴다).
- 템플릿(`templates/roadmap-template.md`)은 이 계획에서 바꾸지 않는다 — 새 형식은 렌더러가 내고, 템플릿의 `## 지휘 절차` 는 계획 3 몫이다(§11).
- 이 로드맵 frontmatter 에는 `review_model: opus` 만 더한다. `test_command` 는 계획 3(`merge_check.py`)이 그 값을 쓰는 명령과 함께 정한다 — 지금 devbrew 에는 전체 스위트를 한 번에 도는 명령이 없다.

---

### Task 0: 스위트 기준선

**Files:**
- Create: `.superpowers/sdd/2026-10-17-epic-conductor-1-format-state/suite-names.sh` (git 이 추적하지 않는다)
- Create: `.superpowers/sdd/2026-10-17-epic-conductor-1-format-state/baseline.txt`

**Interfaces:**
- Produces: `suite-names.sh` — 리포 루트에서 돌면 실패 «이름» 을 한 줄씩(`<파일>: <이름>`) 정렬해 낸다. Task 15 가 같은 스크립트로 대조한다.

- [ ] **Step 1: 스크립트를 쓴다**

```bash
#!/usr/bin/env bash
# 실패 이름 집합 — 셸 테스트의 「  ✗ 」 줄과 unittest 의 FAIL: · ERROR: 줄. ✗ 줄 없이 rc≠0 이면 그 사실을 한 줄로.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
{
  for f in plugins/spec-distill/tests/*.sh shared/tests/*.sh; do
    out="$(bash "$f" 2>&1)"; rc=$?
    name="${f##*/}"
    printf '%s\n' "$out" | sed -n 's/^  ✗ //p' | sed "s|^|$name: |"
    if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^  ✗ '; then
      echo "$name: rc $rc (✗ 줄 없음)"
    fi
  done
  for d in plugins/spec-distill/tests shared/tests; do
    python3 -m unittest discover -s "$d" -p 'test_*.py' 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|$d: |"
  done
} | LC_ALL=C sort
```

- [ ] **Step 2: 기준선을 잰다(이 브랜치의 지금 HEAD)**

Run: `bash .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/suite-names.sh > .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/baseline.txt; wc -l .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/baseline.txt`
Expected: 파일이 생기고 줄 수가 찍힌다(0 일 수도 있다). 이미 빨간 이름은 이 계획의 회귀가 아니다 — Task 15 가 이름 집합으로 대조한다.

커밋하지 않는다.

---

### Task 1: 레포 설정 기본값 모듈

**Files:**
- Create: `plugins/spec-distill/scripts/repo_defaults.py`
- Test: `plugins/spec-distill/tests/test_repo_defaults.py`

**Interfaces:**
- Produces: `repo_defaults.SPECS_DIR: str = "docs/superpowers/specs/"`, `PLANS_DIR: str = "docs/superpowers/plans/"`, `SDD_WORKSPACE: str = ".superpowers/sdd/"`, `CONDUCTOR_DIR: str = "conductor"`, `repo_settings(meta: dict) -> dict` — 키 `specs_dir` · `plans_dir`(끝에 `/`, 잘못된 값이면 `None`) · `test_command` · `review_model`(`str | None`) · `sources`(키 → `"frontmatter"` | `"기본값"`) · `errors`(`list[str]`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 로드맵 frontmatter 의 레포 설정과 기본값(R5 AC14).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import repo_defaults as rd  # noqa: E402


class Settings(unittest.TestCase):
    def test_defaults_when_absent(self):
        s = rd.repo_settings({})
        self.assertEqual(s["specs_dir"], rd.SPECS_DIR)
        self.assertEqual(s["plans_dir"], rd.PLANS_DIR)
        self.assertIsNone(s["test_command"])
        self.assertIsNone(s["review_model"])
        self.assertEqual(s["sources"]["specs_dir"], "기본값")
        self.assertEqual(s["errors"], [])

    def test_frontmatter_wins_and_gets_trailing_slash(self):
        s = rd.repo_settings({"specs_dir": "design", "plans_dir": "\"work/plans/\""})
        self.assertEqual(s["specs_dir"], "design/")
        self.assertEqual(s["plans_dir"], "work/plans/")
        self.assertEqual(s["sources"]["plans_dir"], "frontmatter")

    def test_bad_folder_is_an_error_not_a_silent_default(self):
        for bad in ("../x", "/abs", "~/x", "a/./b", "", "\"\""):
            s = rd.repo_settings({"specs_dir": bad})
            self.assertIsNone(s["specs_dir"], bad)
            self.assertTrue(s["errors"], bad)

    def test_text_keys(self):
        s = rd.repo_settings({"review_model": "opus", "test_command": "'make test'"})
        self.assertEqual(s["review_model"], "opus")
        self.assertEqual(s["test_command"], "make test")
        self.assertEqual(s["sources"]["review_model"], "frontmatter")

    def test_empty_text_key_is_an_error(self):
        s = rd.repo_settings({"review_model": ""})
        self.assertIsNone(s["review_model"])
        self.assertTrue(any("review_model" in e for e in s["errors"]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'repo_defaults'`

- [ ] **Step 3: 모듈을 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정의 기본값과 로드맵 frontmatter 의 레포 설정 읽기.

외부 도구가 정한 기본 경로(superpowers 의 설계문서 · 계획 폴더, SDD 의 작업 폴더)와 이 플러그인의 지휘자 상태
폴더 이름은 이 모듈에만 글자로 둔다. 로드맵 frontmatter 에 값이 있으면 그것이 이긴다. 읽기만 한다.
"""
from __future__ import annotations

SPECS_DIR = "docs/superpowers/specs/"
PLANS_DIR = "docs/superpowers/plans/"
SDD_WORKSPACE = ".superpowers/sdd/"
CONDUCTOR_DIR = "conductor"
DIR_KEYS = ("specs_dir", "plans_dir")
TEXT_KEYS = ("test_command", "review_model")


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1].strip()
    return value


def _folder(key: str, raw: str):
    """(폴더, 사유). 레포 상대 폴더만 받고 끝에 `/` 를 붙인다."""
    value = _unquote(raw)
    if not value:
        return None, "%s 값이 비었다" % key
    if value.startswith("/") or value.startswith("~"):
        return None, "%s 는 레포 상대경로다: %r" % (key, value)
    parts = value.split("/")
    if parts[-1] == "":
        parts = parts[:-1]
    if not parts or any(p in ("", ".", "..") for p in parts):
        return None, "%s 에 빈 조각 · . · .. 를 쓰지 않는다: %r" % (key, value)
    return "/".join(parts) + "/", None


def repo_settings(meta: dict) -> dict:
    """로드맵 frontmatter → 레포 설정. 잘못된 값은 errors 에 적고 그 키는 None — 기본값으로 조용히 바꾸지 않는다."""
    out = {"specs_dir": SPECS_DIR, "plans_dir": PLANS_DIR, "test_command": None, "review_model": None,
           "sources": {}, "errors": []}
    for key in DIR_KEYS:
        if key not in meta:
            out["sources"][key] = "기본값"
            continue
        folder, why = _folder(key, meta[key])
        out[key] = folder
        out["sources"][key] = "frontmatter"
        if why:
            out["errors"].append("레포 설정 " + why)
    for key in TEXT_KEYS:
        if key not in meta:
            out["sources"][key] = "기본값"
            continue
        out["sources"][key] = "frontmatter"
        value = _unquote(meta[key])
        if value:
            out[key] = value
        else:
            out["errors"].append("레포 설정 %s 값이 비었다" % key)
    return out
```

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py`
Expected: `OK` (5 tests)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/tests/test_repo_defaults.py
git commit -m "feat(spec-distill): 레포 설정 기본값과 로드맵 frontmatter 설정 읽기를 한 모듈에

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 2: 해석기 — 하위 항목 · 새 선택 칸 · 여러 브랜치 · 새 재분해 이력 (AC1 · AC2 · AC3 읽기 · AC5 읽기)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` (`FIELDS` 줄 117 근처 · `parse_roadmap` 의 블록 읽기 줄 164–181 · `_validate_block` 줄 221–256, 그리고 새 함수)
- Test: `plugins/spec-distill/tests/test_roadmap_model.py` (새로)

**Interfaces:**
- Consumes: 없음.
- Produces:
  - `EXTRA_FIELDS: tuple = ("크기", "병렬", "순서 이유", "근거", "흐름", "산출물")`, `FIELDS` 는 기존 열 + `EXTRA_FIELDS`.
  - 블록 dict 의 `fields[<칸>]` 은 한 줄이면 `str`, `- <칸>:` 아래 `  - ` 하위 항목이면 `list[str]`.
  - 블록 dict 새 키 `branches: list[str]`(결정 블록은 `[]`).
  - `field_list(value) -> list[str]`, `field_text(value) -> str`.
  - `quotes(text) -> list[str]`(겹친 「…」 는 바깥 하나), `is_quote(text) -> bool`, `strip_quotes(text) -> str`.
  - `parse_history(text) -> (list[dict], list[str])` — 항목 `{"date","reason","changes","quotes","form"}`, `form` 은 `"new"` | `"old"`.
  - `parse_roadmap` 은 재분해 이력의 새 꼴 오류도 `errors` 에 더한다. 반환 모양(다섯 값)은 그대로다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`git show 93be1042:<경로>` 는 이 계획 전의 해석기와 로드맵이다(origin 기본 브랜치의 머지 커밋 #220 — 이력에 영구히 남는다).

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_model.py — 하위 항목 · 새 선택 칸 · 여러 브랜치 · 재분해 이력(R5 AC1 · AC2 · AC3 · AC5).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import roadmap_model as M  # noqa: E402

PRE = "93be1042"   # 이 계획 전 — 옛 해석기와 옛 로드맵
RM = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"

HEAD = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
TAIL = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"


def block(extra=""):
    return ("### A1 — 가\n- 의도: 의도\n- 범위: 한다 x / 안 한다 y\n- 의존: 없음\n- 브랜치: feature/a\n"
            "- 묶음: A1.md\n- 경로 예약: 없음\n" + extra + "\n")


def git_show(rev_path: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), "show", rev_path], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise AssertionError("git show %s 실패 — 기준 커밋이 없는 클론이다: %s"
                             % (rev_path, proc.stderr.decode("utf-8", "replace")))
    return proc.stdout.decode("utf-8")


def old_model():
    """93be1042 의 roadmap_model 을 임시 폴더에 불러온다(section6 은 지금 것 — 해석에 쓰지 않는다)."""
    tmp = Path(tempfile.mkdtemp())
    (tmp / "roadmap_model.py").write_text(git_show(PRE + ":plugins/spec-distill/scripts/roadmap_model.py"),
                                          encoding="utf-8")
    shutil.copy(str(SCRIPTS / "section6.py"), str(tmp / "section6.py"))
    spec = importlib.util.spec_from_file_location("old_roadmap_model", str(tmp / "roadmap_model.py"))
    mod = importlib.util.module_from_spec(spec)
    saved = sys.modules.get("section6")
    sys.path.insert(0, str(tmp))
    try:
        sys.modules.pop("section6", None)
        spec.loader.exec_module(mod)
    finally:
        sys.path.remove(str(tmp))
        if saved is not None:
            sys.modules["section6"] = saved
    shutil.rmtree(str(tmp))
    return mod


def comparable(parsed):
    meta, blocks, records, risks, errors = parsed
    blocks = [{k: v for k, v in b.items() if k != "branches"} for b in blocks]
    return meta, blocks, records, risks, errors


class OldRoadmapsUnchanged(unittest.TestCase):
    """AC1 — 하위 항목이 없는 옛 로드맵은 바뀌기 전과 같은 블록 · 칸 값 · 오류를 낸다."""

    @classmethod
    def setUpClass(cls):
        cls.old = old_model()

    def same(self, text):
        self.assertEqual(comparable(M.parse_roadmap(text)), comparable(self.old.parse_roadmap(text)))

    def test_this_repo_roadmap_before_migration(self):
        self.same(git_show(PRE + ":" + RM))

    def test_small_roadmaps_including_errors(self):
        self.same(HEAD + block() + TAIL)
        self.same(HEAD + block("- 모름: x\n") + TAIL)
        self.same(HEAD + block("- 의도: 두 번\n") + TAIL)
        self.same(HEAD + block("  들여쓴 다른 줄\n") + TAIL)
        self.same(HEAD + "### 이상한 머리\n" + block() + TAIL)


class SubItems(unittest.TestCase):
    def parse(self, body):
        return M.parse_roadmap(HEAD + body + TAIL)

    def test_sub_items_become_the_field_list(self):
        body = block().replace("- 범위: 한다 x / 안 한다 y\n",
                               "- 범위:\n  - 한다: 가 · 나(근거 2026-10-17)\n  - 안 한다: 다\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["fields"]["범위"], ["한다: 가 · 나(근거 2026-10-17)", "안 한다: 다"])

    def test_sub_item_under_one_line_field_is_an_error(self):
        _m, _b, _r, _k, errors = self.parse(block("  - 떠도는 항목\n"))
        self.assertTrue(any("하위 항목" in e for e in errors), errors)

    def test_one_line_field_cannot_take_sub_items(self):
        body = block().replace("- 묶음: A1.md\n", "- 묶음:\n  - A1.md\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("묶음 칸은 한 줄" in e for e in errors), errors)

    def test_empty_list_field_is_an_error(self):
        body = block().replace("- 의도: 의도\n", "- 의도:\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("의도 칸에 값도 하위 항목도 없다" in e for e in errors), errors)

    def test_new_optional_fields_and_unknown_field(self):
        extra = "".join("- %s: 값\n" % k for k in M.EXTRA_FIELDS)
        _m, blocks, _r, _k, errors = self.parse(block(extra))
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["fields"]["산출물"], "값")
        _m, _b, _r, _k, errors = self.parse(block("- 모름: x\n"))
        self.assertTrue(any("모르는 머리말 줄" in e for e in errors), errors)

    def test_branches_one_line_and_sub_items(self):
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치: feature/a · `feature/b`\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["branches"], ["feature/a", "feature/b"])
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치:\n  - feature/a\n  - feature/c\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(blocks[0]["branches"], ["feature/a", "feature/c"])

    def test_duplicate_branch_is_an_error(self):
        body = block().replace("- 브랜치: feature/a\n", "- 브랜치: feature/a · feature/a\n")
        _m, _b, _r, _k, errors = self.parse(body)
        self.assertTrue(any("브랜치가 두 번" in e for e in errors), errors)

    def test_list_values_for_deps_and_reserved(self):
        body = block().replace("- 경로 예약: 없음\n", "- 경로 예약:\n  - `src/a.py`\n  - docs/x/\n")
        _m, blocks, _r, _k, errors = self.parse(body)
        self.assertEqual(errors, [])
        self.assertEqual(blocks[0]["reserved"], ["src/a.py", "docs/x/"])


class Quotes(unittest.TestCase):
    def test_nested_quote_counts_once(self):
        text = "앞 「에픽 실행 방식, 「끝에 할 일 하나」, 해둬」 · 「둘」"
        self.assertEqual(M.quotes(text), ["「에픽 실행 방식, 「끝에 할 일 하나」, 해둬」", "「둘」"])
        self.assertTrue(M.is_quote("「가 「나」 다」"))
        self.assertFalse(M.is_quote("「가」 「나」"))
        self.assertEqual(M.strip_quotes("R5 「R6 말」 끝"), "R5   끝")


class History(unittest.TestCase):
    def hist(self, body):
        return M.parse_history("## 재분해 이력\n\n" + body + "\n## 위험 번호표\n")

    def test_new_form(self):
        entries, errors = self.hist("### 2026-10-17 · 재분해\n- 바뀜: 바뀜 R5 · 새 R11\n- 원문:\n"
                                    "  - 「이대로 다시 나눈다」\n  - 「가 「나」 다」\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries, [{"date": "2026-10-17", "reason": "재분해", "changes": ["바뀜 R5 · 새 R11"],
                                    "quotes": ["「이대로 다시 나눈다」", "「가 「나」 다」"], "form": "new"}])

    def test_changes_as_sub_items(self):
        entries, errors = self.hist("### 2026-10-17 · 수정\n- 바뀜:\n  - 가\n  - 나\n- 원문:\n  - 「좋아」\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]["changes"], ["가", "나"])

    def test_old_one_line_form_still_reads(self):
        entries, errors = self.hist("- 2026-10-11 · 처음 로드맵 · 승인 원문 S47 「이대로 승인」\n- 없음\n")
        self.assertEqual(errors, [])
        self.assertEqual(entries[0]["form"], "old")
        self.assertEqual(entries[0]["quotes"], ["「이대로 승인」"])

    def test_new_form_errors(self):
        cases = {"### 날짜아님 · x\n- 원문:\n  - 「a」\n": "머리가",
                 "### 2026-10-17 · x\n- 바뀜: y\n": "원문이 없다",
                 "### 2026-10-17 · x\n- 원문:\n  - 인용 아님\n": "원문 줄은",
                 "### 2026-10-17 · x\n- 원문: 「한 줄」\n": "하위 항목으로",
                 "### 2026-10-17 · x\n- 원문:\n  - 「a」\n그냥 줄\n": "읽지 못한 줄"}
        for body, want in cases.items():
            _e, errors = self.hist(body)
            self.assertTrue(any(want in e for e in errors), (body, errors))

    def test_parse_roadmap_reports_history_errors(self):
        text = HEAD + block() + TAIL.replace("- 없음\n", "### 2026-10-17 · x\n- 바뀜: y\n")
        _m, _b, _r, _k, errors = M.parse_roadmap(text)
        self.assertTrue(any("원문이 없다" in e for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py`
Expected: FAIL/ERROR — `AttributeError: module 'roadmap_model' has no attribute 'EXTRA_FIELDS'` 등. `OldRoadmapsUnchanged` 는 지금도 통과한다(두 해석기가 같다 — 이 단언이 양성 짝이다).

- [ ] **Step 3: 해석기를 고친다**

`FIELDS` 줄을 아래로 바꾸고 바로 밑에 상수를 더한다:

```python
EXTRA_FIELDS = ("크기", "병렬", "순서 이유", "근거", "흐름", "산출물")
FIELDS = ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약", "spec", "발화", "항목", "완료") + EXTRA_FIELDS
ONE_LINE = ("묶음", "spec", "완료", "발화", "항목")   # 하위 항목을 두지 않는 칸
SUB_ITEM = "  - "
HISTORY_HEADING = "## 재분해 이력"
HISTORY_HEAD_RE = re.compile(r"### (\d{4}-\d{2}-\d{2}) · (\S.*)")
OLD_HISTORY_RE = re.compile(r"- (\d{4}-\d{2}-\d{2}) · (\S.*)")
```

`split_list` 바로 뒤에 더한다:

```python
def field_list(value) -> list:
    """칸 값을 목록으로 — 하위 항목이면 항목마다(백틱 뗌), 한 줄이면 쉼표 · ` · ` 로 나눈다. 「없음」은 빈 목록."""
    if isinstance(value, list):
        items = [v.strip().strip("`") for v in value]
        return [] if items == ["없음"] else [v for v in items if v]
    return split_list(value)


def field_text(value) -> str:
    """칸 값을 한 줄 글로 — 하위 항목은 ` · ` 로 잇는다."""
    return " · ".join(value) if isinstance(value, list) else value


def quotes(text: str) -> list:
    """「…」 인용들. 안에 「…」 가 겹쳐 있으면 바깥 인용 하나로 센다. 닫히지 않은 「 는 세지 않는다."""
    out, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch == "「":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "」" and depth:
            depth -= 1
            if depth == 0:
                out.append(text[start:i + 1])
    return out


def is_quote(text: str) -> bool:
    return quotes(text) == [text]


def strip_quotes(text: str) -> str:
    for q in quotes(text):
        text = text.replace(q, " ", 1)
    return text


def _field_line(text: str):
    """`<칸>: <값>` → (칸, 값 글). `<칸>:` → (칸, []) — 하위 항목을 받는다. 모르는 칸이면 (None, None)."""
    if text.endswith(":") and text[:-1] in FIELDS:
        return text[:-1], []
    key, sep, value = text.partition(": ")
    if not sep or key not in FIELDS:
        return None, None
    return key, value.strip()


def parse_history(text: str):
    """`## 재분해 이력` → (항목들, 오류들). 항목 {"date","reason","changes","quotes","form"}.

    새 꼴: `### <날짜> · <사유>` 아래 `- 바뀜: …`(또는 `- 바뀜:` + 하위 항목)과 `- 원문:` + 하위 항목(줄마다 「…」 하나).
    옛 꼴 `- <날짜> · …` 한 줄도 읽는다(인용은 줄 안의 「…」 전부). 새 항목 밖의 다른 줄은 전처럼 읽지 않는다.
    """
    try:
        body = section_body(text, HISTORY_HEADING)
    except FormatError as exc:
        return [], [str(exc)]
    entries, errors, cur, key = [], [], None, None
    for line in (body or "").splitlines():
        if not line.strip():
            continue
        old = OLD_HISTORY_RE.fullmatch(line.rstrip())
        if line.startswith("### "):
            m = HISTORY_HEAD_RE.fullmatch(line.rstrip())
            cur, key = None, None
            if not m:
                errors.append("재분해 이력 머리가 `### <YYYY-MM-DD> · <사유>` 가 아니다: %r" % line)
                continue
            cur = {"date": m.group(1), "reason": m.group(2), "changes": [], "quotes": [], "form": "new"}
            entries.append(cur)
        elif old:
            entries.append({"date": old.group(1), "reason": old.group(2), "changes": [],
                            "quotes": quotes(line), "form": "old"})
            cur, key = None, None
        elif cur is None:
            continue
        elif line.startswith("- 바뀜:") or line.startswith("- 원문:"):
            key, _sep, value = line[2:].partition(":")
            value = value.strip()
            if key == "원문" and value:
                errors.append("%s 재분해 이력: 원문은 하위 항목으로 줄마다 하나씩 적는다: %r" % (cur["date"], line))
            elif value:
                cur["changes"].append(value)
        elif line.startswith(SUB_ITEM) and key in ("바뀜", "원문"):
            item = line[len(SUB_ITEM):].strip()
            if key == "원문" and not is_quote(item):
                errors.append("%s 재분해 이력: 원문 줄은 「…」 하나다: %r" % (cur["date"], line))
            elif key == "원문":
                cur["quotes"].append(item)
            elif item:
                cur["changes"].append(item)
        else:
            errors.append("%s 재분해 이력에서 읽지 못한 줄: %r" % (cur["date"], line))
    for e in entries:
        if e["form"] == "new" and not e["quotes"]:
            errors.append("%s 재분해 이력(%s)에 원문이 없다" % (e["date"], e["reason"]))
    return entries, errors
```

`parse_roadmap` 의 블록 읽기 반복(`blocks, cur = [], None` 부터 `cur["fields"][key] = value.strip()` 까지)을 아래로 바꾼다:

```python
    blocks, cur, last = [], None, None
    for line in body.splitlines():
        if line.startswith("### "):
            last = None
            m = BLOCK_HEAD_RE.fullmatch(line.rstrip())
            if not m:
                errors.append("블록 머리가 `### <번호> — <이름>` 이 아니다: %r" % line)
                cur = None
                continue
            cur = {"id": m.group(1), "title": m.group(2), "fields": {}}
            blocks.append(cur)
        elif cur is not None and line.startswith(SUB_ITEM):
            item = line[len(SUB_ITEM):].strip()
            if last is None or not isinstance(cur["fields"].get(last), list):
                errors.append("%s: 하위 항목이 값 없는 칸(`- <칸>:`) 아래에 있지 않다: %r" % (cur["id"], line))
            elif not item:
                errors.append("%s: %s 칸의 하위 항목이 비었다" % (cur["id"], last))
            else:
                cur["fields"][last].append(item)
        elif cur is not None and line.startswith("- "):
            key, value = _field_line(line[2:])
            last = None
            if key is None:
                errors.append("%s: 모르는 머리말 줄 %r" % (cur["id"], line))
            elif key in cur["fields"]:
                errors.append("%s: 머리말 %s 가 두 번 있다" % (cur["id"], key))
            else:
                cur["fields"][key] = value
                last = key
    for b in blocks:
        for key, value in b["fields"].items():
            if isinstance(value, list) and not value:
                errors.append("%s: %s 칸에 값도 하위 항목도 없다" % (b["id"], key))
            elif isinstance(value, list) and key in ONE_LINE:
                errors.append("%s: %s 칸은 한 줄 값이다 — 하위 항목을 두지 않는다" % (b["id"], key))
```

`parse_roadmap` 의 `risk_rows` 반복 뒤, `return` 바로 앞에 한 줄을 더한다:

```python
    errors.extend(parse_history(text)[1])
```

`_validate_block` 을 아래로 바꾼다(한 줄 칸이 목록이면 위에서 이미 오류를 냈으므로 여기서는 건너뛴다):

```python
def _validate_block(b: dict, known: set) -> list:
    f, bid, errs = b["fields"], b["id"], []

    def one(key):
        value = f.get(key)
        return value if isinstance(value, str) else None

    kind = "decision" if "완료" in f else ("branch" if one("묶음") == "없음" else "bundle")
    b["kind"] = kind
    for key in REQUIRED[kind]:
        if key not in f:
            errs.append("%s: 머리말 %s 가 없다" % (bid, key))
    for key in FORBIDDEN[kind]:
        if key in f:
            errs.append("%s: %s 블록에는 머리말 %s 를 두지 않는다" % (bid, kind, key))
    if kind == "decision":
        if one("완료") != "결정 기록":
            errs.append("%s: 완료 값은 「결정 기록」이어야 한다" % bid)
        if one("묶음") != "없음":
            errs.append("%s: 확인 · 결정 블록의 묶음은 「없음」이어야 한다" % bid)
    if kind == "bundle" and one("묶음") is not None and not BUNDLE_NAME_RE.fullmatch(one("묶음")):
        errs.append("%s: 묶음 값은 로드맵 옆 파일 이름(R<n>.md)이어야 한다" % bid)
    deps = field_list(f.get("의존", "없음"))
    b["deps"] = deps
    for d in deps:
        if not BLOCK_ID_RE.fullmatch(d) or d not in known or d == bid:
            errs.append("%s: 의존 %r 가 로드맵의 다른 블록이 아니다" % (bid, d))
    b["reserved"] = field_list(f.get("경로 예약", "없음"))
    b["branches"] = field_list(f["브랜치"]) if kind != "decision" and "브랜치" in f else []
    if kind != "decision" and "브랜치" in f and not b["branches"]:
        errs.append("%s: 브랜치 칸에 브랜치 이름이 없다" % bid)
    if len(set(b["branches"])) != len(b["branches"]):
        errs.append("%s: 브랜치가 두 번 있다" % bid)
    b["assigned"] = []
    for key, want_s in (("발화", True), ("항목", False)):
        if one(key) is not None:
            try:
                toks = parse_ids(one(key))
            except FormatError as exc:
                errs.append("%s: %s — %s" % (bid, key, exc))
                continue
            wrong = [t for t in toks if (t.startswith("S") and t[1:].isdigit()) != want_s]
            if wrong:
                errs.append("%s: %s 줄에 맞지 않는 번호 %s" % (bid, key, " · ".join(wrong)))
            b["assigned"].extend(toks)
    return errs
```

- [ ] **Step 4: 통과를 확인하고, 해석기를 쓰는 기존 테스트를 돌린다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_render_r2.py && bash plugins/spec-distill/tests/test_roadmap_status.sh && bash plugins/spec-distill/tests/test_bundle_coverage.sh`
Expected: 모두 OK / `Fail: 0`. `roadmap_status.py` 는 아직 `b["fields"]["브랜치"]` 를 글로 읽는다 — 한 줄 칸은 그대로 `str` 이라 기존 픽스처에서 동작이 같다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/tests/test_roadmap_model.py
git commit -m "feat(spec-distill): 로드맵 칸 아래 하위 항목 · 새 선택 칸 · 여러 브랜치 · 새 재분해 이력을 읽는다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 3: 지휘자 기계 상태 형식 · 표지 · 넘김 계산 모듈 (AC43 · AC17 의 기계 상태 쓰기)

**Files:**
- Create: `plugins/spec-distill/scripts/conductor_state.py`
- Modify: `plugins/spec-distill/scripts/state_path.py:65-87` (`state_root` 를 공용 git 디렉토리에서 계산하는 함수로 나눈다)
- Test: `plugins/spec-distill/tests/test_conductor_state.py`

**Interfaces:**
- Consumes: `repo_defaults.CONDUCTOR_DIR`, `roadmap_model.section_body`, `ledger_marker._read_line` · `_atomic_write`, `state_path.SESSION_PATTERN`.
- Produces (`conductor_state`):
  - 상수 `MACHINE_FILE = "machine.md"`, `MARKER = "conducting-by"`, `SECTIONS`(절 이름 → 칸 이름 튜플의 순서 있는 튜플), `RULINGS_HEADING = "## 판정"`, `RECORD_HEADING = "## 지휘 기록"`, `IMPL_PREFIX = "## 구현 대조 — "`.
  - `class MachineError(ValueError)`.
  - `machine_dir(state_root, roadmap_rel) -> Path`, `machine_path(state_root, roadmap_rel) -> Path`.
  - `empty() -> dict`, `parse_machine(text, roadmap_rel) -> dict`, `render_machine(roadmap_rel, data) -> str`, `load(path, roadmap_rel) -> dict`(없으면 `empty()`, 깨졌으면 `MachineError`), `save(path, roadmap_rel, data, session) -> None`.
  - `holder(d) -> str | None`, `acquire(d, session) -> str`(`"acquired"` · `"held"` · 쥔 세션 id), `release(d, session) -> bool`, `takeover(d, session) -> str | None`.
  - `handoff_key(giver, item) -> str`(8자), `confirm_line(giver, item, basis) -> str`, `confirmed_keys(record_text) -> set`, `handoff_rows(givers, stages, records) -> list[dict]`(키 `item` · `giver` · `receiver` · `spec` · `state` · `basis`).
  - `section_lines(doc_text, heading) -> list[str] | None`, `rulings_archived(doc_text) -> list[str] | None`, `impl_done(doc_text, plan_rel) -> bool`, `ledger_rulings(text) -> list[str]`.
- Produces (`state_path`): `state_root_for_common(git_common_dir: Path) -> Path`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_state.py — 기계 상태 형식 · 원자 쓰기 · 표지 · 넘김 상태 계산(R5 AC43 · AC17).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py
"""
from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import conductor_state as cs  # noqa: E402
import state_path  # noqa: E402

RM = "docs/superpowers/roadmaps/rm/roadmap.md"
SID, OTHER = "session-aaaa1111", "session-bbbb2222"


def sample():
    data = cs.empty()
    data["PR"].append({"브랜치": "feature/a", "번호": "#12", "상태": "열림", "확인한 때": "2026-10-17 10:00"})
    data["실행 원장"].append({"에픽": "R5", "계획": "docs/p.md", "원장": "/w/.superpowers/sdd/p/progress.md",
                           "읽은 줄": "3"})
    data["자원"].append({"종류": "worktree", "경로": "/w", "에픽": "R5", "용도": "구현", "만든 때": "2026-10-17"})
    data["기다리는 질문"].append({"에픽": "R5", "기대는 일": "구현", "질문": "범위 · 인터페이스를 어떻게 할까"})
    return data


class Format(unittest.TestCase):
    def test_round_trip(self):
        text = cs.render_machine(RM, sample())
        self.assertEqual(cs.parse_machine(text, RM), sample())

    def test_last_column_may_hold_separator_others_may_not(self):
        data = sample()
        data["자원"][0]["용도"] = "가 · 나"
        with self.assertRaises(cs.MachineError):
            cs.render_machine(RM, data)

    def test_broken_inputs_raise(self):
        good = cs.render_machine(RM, sample())
        broken = {
            "frontmatter 없음": good.split("---\n", 2)[2],
            "다른 로드맵": good.replace("roadmap: " + RM, "roadmap: other/roadmap.md"),
            "모르는 절": good + "\n## 모르는 절\n",
            "칸 수": good.replace("- feature/a · #12 · 열림 · 2026-10-17 10:00", "- feature/a · #12"),
            "PR 상태": good.replace("· 열림 ·", "· 열렸음 ·"),
            "PR 번호": good.replace("#12", "12"),
            "읽은 줄": good.replace("progress.md · 3", "progress.md · 셋"),
        }
        for name, text in broken.items():
            with self.assertRaises(cs.MachineError, msg=name):
                cs.parse_machine(text, RM)

    def test_machine_dir_uses_roadmap_folder(self):
        self.assertEqual(cs.machine_dir("/s", RM), Path("/s/conductor/rm"))
        for bad in ("roadmap.md", "a/../roadmap.md"):
            with self.assertRaises(cs.MachineError):
                cs.machine_dir("/s", bad)


class Storage(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.path = cs.machine_path(self.tmp, RM)

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def test_missing_file_is_empty(self):
        self.assertEqual(cs.load(self.path, RM), cs.empty())

    def test_broken_file_is_not_read_as_empty(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("깨진 글\n", encoding="utf-8")
        with self.assertRaises(cs.MachineError):
            cs.load(self.path, RM)

    def test_save_needs_the_marker_and_is_atomic(self):
        d = self.path.parent
        self.assertEqual(cs.acquire(d, SID), "acquired")
        self.assertEqual(cs.acquire(d, SID), "held")
        self.assertEqual(cs.acquire(d, OTHER), SID)
        cs.save(self.path, RM, sample(), SID)
        self.assertEqual(cs.load(self.path, RM), sample())
        before = self.path.read_bytes()
        with self.assertRaises(cs.MachineError):
            cs.save(self.path, RM, cs.empty(), OTHER)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual([p.name for p in d.iterdir() if p.name.startswith(".machine.")], [])

    def test_release_and_takeover(self):
        d = self.path.parent
        cs.acquire(d, SID)
        self.assertFalse(cs.release(d, OTHER))
        self.assertEqual(cs.holder(d), SID)
        self.assertEqual(cs.takeover(d, OTHER), SID)
        self.assertEqual(cs.holder(d), OTHER)
        self.assertTrue(cs.release(d, OTHER))
        self.assertIsNone(cs.holder(d))

    def test_state_root_for_common(self):
        self.assertEqual(state_path.state_root_for_common(Path("/r/.git")), Path("/r/.claude/spec-distill"))


class Handoffs(unittest.TestCase):
    def test_five_states(self):
        rows = [("항목 가 · 나", "이유", "R2"), ("항목 둘", "이유", "R3"), ("항목 셋", "이유", "R4"),
                ("항목 넷", "이유", "#7"), ("항목 다섯", "이유", "없음")]
        records = {"R3": cs.confirm_line("R1", "항목 둘", "AC 보고 AC4")}
        stages = {"R1": "구현 끝", "R2": "설계 중", "R3": "머지됨", "R4": "머지됨"}
        got = {r["item"]: r["state"] for r in cs.handoff_rows([("R1", "s.md", rows)], stages, records)}
        self.assertEqual(got, {"항목 가 · 나": "열림", "항목 둘": "확인됨", "항목 셋": "처리됨",
                               "항목 넷": "이슈", "항목 다섯": "받는 곳 없음"})

    def test_confirm_key_ignores_other_giver(self):
        line = cs.confirm_line("R9", "항목", "근거")
        self.assertIn(("R9", cs.handoff_key("R9", "항목")), cs.confirmed_keys(line))
        self.assertNotIn(("R1", cs.handoff_key("R1", "항목")), cs.confirmed_keys(line))


class DocSections(unittest.TestCase):
    DOC = ("# d\n\n## 판정\n\n- Task 1: Ruling: 가 — 왜 — 비용\n\n```\n## 구현 대조 — p2.md\n```\n\n"
           "## 구현 대조 — docs/p1.md\n\n- 요약\n")

    def test_impl_done_is_per_plan(self):
        self.assertTrue(cs.impl_done(self.DOC, "docs/p1.md"))
        self.assertFalse(cs.impl_done(self.DOC, "docs/p2.md"))
        self.assertFalse(cs.impl_done(self.DOC, "p2.md"))   # 펜스 안 머리는 절이 아니다

    def test_rulings_archived(self):
        self.assertEqual(cs.rulings_archived(self.DOC), ["- Task 1: Ruling: 가 — 왜 — 비용"])
        self.assertIsNone(cs.rulings_archived("# 판정 절 없음\n"))

    def test_ledger_rulings(self):
        text = "# SDD ledger — plan: p\nTask 1: complete\nTask 2: Ruling: x — y — z\nFinal: Ruling: w\n"
        self.assertEqual(cs.ledger_rulings(text), ["Task 2: Ruling: x — y — z", "Final: Ruling: w"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py`
Expected: ERROR — `ModuleNotFoundError: No module named 'conductor_state'`

- [ ] **Step 3: `state_path.state_root` 를 나눈다**

`state_root` 바로 위에 더하고, `state_root` 안의 `main_repo = git_dir.parent` · `return main_repo / ".claude" / "spec-distill"` 두 줄을 `return state_root_for_common(git_dir)` 로 바꾼다:

```python
def state_root_for_common(git_common_dir: Path) -> Path:
    """공용 git 디렉토리 → <main_repo>/.claude/spec-distill. 화면이 git 을 다시 부르지 않고 쓴다."""
    return Path(git_common_dir).parent / ".claude" / "spec-distill"
```

- [ ] **Step 4: 모듈을 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_state.py — 지휘자 기계 상태(`machine.md`)의 형식 · 읽기 · 원자 쓰기 · 세션 표지와 넘김 상태 계산.

기계 상태는 이 기계에서만 뜻이 있는 것(PR 번호 캐시 · 실행 원장 위치 · 자원 · 살아 있는 agent · 기다리는 질문 ·
아직 커밋하지 못한 기록 · 임시 레포 설정)만 담는다. 이어 가기에 필요한 기록은 에픽 설계문서의 절이 주인이다.
상태 계산(`roadmap_status.py`) · 화면(`control_plane.py`) · 지휘자 스크립트가 이 모듈 하나를 쓴다.

명령줄(읽기만):
  conductor_state.py path --roadmap <로드맵 레포 상대경로>   이 기계의 기계 상태 파일 경로
  conductor_state.py show --roadmap <…>                     읽은 결과 JSON — 깨졌으면 사유와 rc 3
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
from ledger_marker import _atomic_write, _read_line  # noqa: E402 — 리뷰 원장 표지와 같은 방식
from roadmap_model import FormatError, section_body  # noqa: E402
from state_path import SESSION_PATTERN, state_root  # noqa: E402

MACHINE_FILE = "machine.md"
MARKER = "conducting-by"
TYPE = "conductor-machine"
SECTIONS = (
    ("PR", ("브랜치", "번호", "상태", "확인한 때")),
    ("실행 원장", ("에픽", "계획", "원장", "읽은 줄")),
    ("자원", ("종류", "경로", "에픽", "용도", "만든 때")),
    ("살아 있는 agent", ("이름", "에픽", "일", "worktree", "보낸 때")),
    ("기다리는 질문", ("에픽", "기대는 일", "질문")),
    ("쌓인 기록", ("에픽", "절", "글")),
    ("레포 설정", ("키", "값")),
)
COLUMNS = dict(SECTIONS)
PR_STATES = ("열림", "머지됨", "닫힘")
PR_NUMBER_RE = re.compile(r"#\d+")
SEP = " · "

# 에픽 설계문서(또는 산출물)의 절 — 지휘자가 쓰고 상태 계산 · 화면이 읽는다.
RULINGS_HEADING = "## 판정"
RECORD_HEADING = "## 지휘 기록"
IMPL_PREFIX = "## 구현 대조 — "
CONFIRM_RE = re.compile(r"- 넘김 확인 · ([A-Z][0-9]+[a-z]?) · ([0-9a-f]{8}) · (\S.*)")
ISSUE_RE = re.compile(r"#\d+")
EPIC_RE = re.compile(r"[A-Z][0-9]+[a-z]?")
RECEIVED = ("머지됨", "끝남")


class MachineError(ValueError):
    """기계 상태를 읽거나 쓸 수 없다 — 빈 상태로 읽지 않는다."""


# ── 경로 ─────────────────────────────────────────────────────────────────────

def machine_dir(root, roadmap_rel: str) -> Path:
    """<state-root>/conductor/<로드맵 폴더 이름>."""
    parts = [p for p in roadmap_rel.strip("/").split("/") if p]
    if len(parts) < 2 or parts[-2] in (".", "..") or ".." in parts:
        raise MachineError("로드맵 경로에서 폴더 이름을 얻지 못했다: %r" % roadmap_rel)
    return Path(root) / repo_defaults.CONDUCTOR_DIR / parts[-2]


def machine_path(root, roadmap_rel: str) -> Path:
    return machine_dir(root, roadmap_rel) / MACHINE_FILE


# ── 형식 ─────────────────────────────────────────────────────────────────────

def empty() -> dict:
    return dict((name, []) for name, _cols in SECTIONS)


def _check_row(section: str, row: dict, where: str):
    if section == "PR":
        if not PR_NUMBER_RE.fullmatch(row["번호"]):
            raise MachineError("%s: PR 번호는 `#<숫자>` 다: %r" % (where, row["번호"]))
        if row["상태"] not in PR_STATES:
            raise MachineError("%s: PR 상태는 %s 중 하나다: %r" % (where, " · ".join(PR_STATES), row["상태"]))
    if section == "실행 원장" and not row["읽은 줄"].isdigit():
        raise MachineError("%s: 읽은 줄은 숫자다: %r" % (where, row["읽은 줄"]))


def parse_machine(text: str, roadmap_rel: str) -> dict:
    lines = text.split("\n")
    if not lines or lines[0] != "---":
        raise MachineError("frontmatter 가 없다")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise MachineError("frontmatter 가 닫히지 않았다")
    head = dict(line.split(": ", 1) for line in lines[1:end] if ": " in line)
    if head.get("type") != TYPE:
        raise MachineError("type 이 %s 가 아니다" % TYPE)
    if head.get("roadmap") != roadmap_rel:
        raise MachineError("다른 로드맵의 기계 상태다: %s" % head.get("roadmap"))
    data, cur = empty(), None
    for n, line in enumerate(lines[end + 1:], end + 2):
        if not line.strip():
            continue
        if line.startswith("## "):
            cur = line[3:].strip()
            if cur not in COLUMNS:
                raise MachineError("%d줄: 모르는 절 %r" % (n, cur))
            continue
        if cur is None or not line.startswith("- "):
            raise MachineError("%d줄: 읽지 못한 줄 %r" % (n, line))
        cols = COLUMNS[cur]
        cells = [c.strip() for c in line[2:].split(SEP, len(cols) - 1)]
        if len(cells) != len(cols) or not all(cells):
            raise MachineError("%d줄: %s 절의 칸 %d개(%s)가 아니다" % (n, cur, len(cols), " · ".join(cols)))
        row = dict(zip(cols, cells))
        _check_row(cur, row, "%d줄" % n)
        data[cur].append(row)
    return data


def render_machine(roadmap_rel: str, data: dict) -> str:
    out = ["---", "type: " + TYPE, "roadmap: " + roadmap_rel, "---", ""]
    for name, cols in SECTIONS:
        out += ["## " + name, ""]
        for row in data.get(name, []):
            cells = [str(row[c]).replace("\n", " ").strip() for c in cols]
            if not all(cells):
                raise MachineError("%s 절에 빈 칸이 있다: %r" % (name, row))
            if any(SEP in c for c in cells[:-1]):
                raise MachineError("%s 절: 마지막 칸이 아닌 칸에 ` · ` 를 쓸 수 없다: %r" % (name, row))
            _check_row(name, dict(zip(cols, cells)), name)
            out.append("- " + SEP.join(cells))
        out.append("")
    return "\n".join(out)


def load(path: Path, roadmap_rel: str) -> dict:
    path = Path(path)
    if path.is_symlink():
        raise MachineError("기계 상태 파일이 링크다: %s" % path)
    if not path.exists():
        return empty()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise MachineError("기계 상태 파일을 읽지 못했다: %s (%s)" % (path, type(exc).__name__))
    return parse_machine(text, roadmap_rel)


# ── 표지 · 쓰기 ──────────────────────────────────────────────────────────────

def holder(d: Path):
    return _read_line(Path(d), MARKER) or None


def acquire(d: Path, session: str) -> str:
    """"acquired" · "held" 또는 표지를 쥔 다른 세션 id."""
    if not SESSION_PATTERN.fullmatch(session or ""):
        raise MachineError("세션 id 형식이 아니다: %r" % (session or "")[:32])
    d = Path(d)
    d.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(d / MARKER), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    except FileExistsError:
        owner = holder(d)
        return "held" if owner == session else (owner or "(빈 표지)")
    try:
        os.write(fd, (session + "\n").encode("utf-8"))
    finally:
        os.close(fd)
    return "acquired"


def release(d: Path, session: str) -> bool:
    d = Path(d)
    if holder(d) != session:
        return False
    os.unlink(str(d / MARKER))
    return True


def takeover(d: Path, session: str):
    """표지를 넘겨받는다 — 사용자가 정했을 때만 부른다. 이전 주인을 돌려준다."""
    d = Path(d)
    prev = holder(d)
    _atomic_write(d, MARKER, session + "\n")
    return prev


def save(path: Path, roadmap_rel: str, data: dict, session: str) -> None:
    """표지를 쥔 세션만 쓴다. 임시 파일 + os.replace 로 원자적으로."""
    path = Path(path)
    owner = holder(path.parent)
    if owner != session:
        raise MachineError("표지가 이 세션 것이 아니다(쥔 세션: %s) — 읽기 전용이다" % (owner or "없음"))
    text = render_machine(roadmap_rel, data)
    parse_machine(text, roadmap_rel)
    fd, tmp = tempfile.mkstemp(prefix=".machine.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


# ── 설계문서의 절 ────────────────────────────────────────────────────────────

def _headings(doc_text: str):
    in_fence = False
    for line in doc_text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and line.startswith("## "):
            yield line.rstrip()


def impl_done(doc_text: str, plan_rel: str) -> bool:
    """그 계획의 `## 구현 대조 — <계획 경로>` 절이 있는가 — 다른 계획의 절은 세지 않는다."""
    want = IMPL_PREFIX + plan_rel
    return any(h == want for h in _headings(doc_text))


def section_lines(doc_text: str, heading: str):
    try:
        body = section_body(doc_text, heading)
    except FormatError:
        return None
    return None if body is None else [l.rstrip() for l in body.splitlines() if l.strip()]


def rulings_archived(doc_text: str):
    """설계문서 `## 판정` 의 `- ` 줄들. 절이 없으면 None(빈 절은 [])."""
    lines = section_lines(doc_text, RULINGS_HEADING)
    return None if lines is None else [l for l in lines if l.startswith("- ")]


def ledger_rulings(text: str) -> list:
    """실행 방식 원장의 판정 줄 — `Ruling:` 이 든 줄."""
    return [l.strip() for l in text.splitlines() if "Ruling:" in l]


# ── 넘김 ─────────────────────────────────────────────────────────────────────

def handoff_key(giver: str, item: str) -> str:
    return hashlib.sha256(("%s\n%s" % (giver, item)).encode("utf-8")).hexdigest()[:8]


def confirm_line(giver: str, item: str, basis: str) -> str:
    return "- 넘김 확인 · %s · %s · %s" % (giver, handoff_key(giver, item), basis)


def confirmed_keys(record_text: str) -> set:
    out = set()
    for line in record_text.splitlines():
        m = CONFIRM_RE.fullmatch(line.rstrip())
        if m:
            out.add((m.group(1), m.group(2)))
    return out


def handoff_rows(givers, stages: dict, records: dict) -> list:
    """넘김 한 줄씩. givers 는 [(준 에픽, 설계문서 경로, [(항목, 이유, 받는 곳)])], stages 는 {에픽: 단계},
    records 는 {에픽: 그 에픽 설계문서들의 `## 지휘 기록` 글}.
    상태: 열림 · 처리됨(받는 에픽 머지됨, 확인 전) · 확인됨 · 이슈(`#<n>` — 처리 여부는 GitHub) · 받는 곳 없음."""
    out = []
    for giver, spec, rows in givers:
        for item, _why, recv in rows:
            row = {"item": item, "giver": giver, "receiver": recv, "spec": spec}
            if ISSUE_RE.fullmatch(recv):
                row.update(state="이슈", basis="GitHub 이슈 %s — 처리 여부는 GitHub 이 안다" % recv)
            elif not (EPIC_RE.fullmatch(recv) and recv in stages):
                row.update(state="받는 곳 없음", basis="받는 곳 %r 이 로드맵의 에픽도 `#<n>` 도 아니다" % recv)
            elif (giver, handoff_key(giver, item)) in confirmed_keys(records.get(recv, "")):
                row.update(state="확인됨", basis="%s 설계문서의 %s 절" % (recv, RECORD_HEADING[3:]))
            elif stages[recv] in RECEIVED:
                row.update(state="처리됨", basis="%s 머지됨 — 확인 전" % recv)
            else:
                row.update(state="열림", basis="%s %s" % (recv, stages[recv]))
            out.append(row)
    return out


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="conductor_state.py", description="지휘자 기계 상태를 읽는다.")
    ap.add_argument("cmd", choices=("path", "show"))
    ap.add_argument("--roadmap", required=True)
    a = ap.parse_args(argv)
    try:
        path = machine_path(state_root(), a.roadmap)
        if a.cmd == "path":
            print(path)
            return 0
        data = load(path, a.roadmap)
    except MachineError as exc:
        print("[spec-distill] 기계 상태를 읽지 못했다 — %s" % exc)
        return 3
    print(json.dumps({"path": str(path), "holder": holder(path.parent), "data": data}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py && bash plugins/spec-distill/tests/test_ledger_wiring.sh && python3 -m unittest plugins/spec-distill/tests/test_ledger_marker.py`
Expected: OK / `Fail: 0`. (`state_path` 를 쓰는 다른 테스트 — `grep -ln state_path plugins/spec-distill/tests/*` — 도 돌려 같은지 본다.)

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/scripts/state_path.py plugins/spec-distill/tests/test_conductor_state.py
git commit -m "feat(spec-distill): 지휘자 기계 상태 형식 · 표지 · 넘김 상태 계산 모듈

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 4: 생성기 — 범위 하위 항목 · 선택 칸 표 · 새 재분해 이력 (AC2 · AC3 쓰기 · AC4 의 렌더러)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_render.py` (`Row` 줄 37–57 · `_row` 줄 86–110 · `parse_table` 줄 113–138 · `format_table` 줄 141–147 · `extract_rows` 줄 150–186 · `render_block` 줄 277–288 · `append_history` 줄 375–380, 새 함수)
- Modify: `plugins/spec-distill/scripts/roadmap_write.py` (`cmd_create` 줄 240 · `QUOTE_RE`/`used_numbers` 줄 283–309 · `cmd_update` 줄 373–376 · `build_parser` 줄 405–418)
- Modify: `plugins/spec-distill/tests/test_roadmap_render.py` (줄 147 · 183–214 의 기대값), `plugins/spec-distill/tests/test_roadmap_write.sh` (줄 134 · 278 · 399 의 기대값)
- Test: `plugins/spec-distill/tests/test_roadmap_render.py` 에 `class FormatV2` 를 더한다

**Interfaces:**
- Consumes: `roadmap_model.EXTRA_FIELDS` · `field_text` · `quotes` · `is_quote` · `strip_quotes`(Task 2).
- Produces:
  - `Row.extras: dict`(칸 이름 → 한 줄 값, 「없음」은 넣지 않는다, 기본 `{}`).
  - `EXTRA_COLUMNS = EXTRA_FIELDS`, `SCOPE_RE`, `scope_lines(scope: str) -> list[str]`, `scope_text(value) -> str`.
  - `history_entry(date: str, reason: str, changes: list, quotes: list) -> str`(끝에 `\n`).
  - `append_history(roadmap_text: str, entry: str) -> str` — `entry` 가 `### ` 로 시작하면 빈 줄을 두고 붙인다.
  - `roadmap_write.py create|update --approval` 은 여러 번 줄 수 있다(`action="append"`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_roadmap_render.py` 의 `class GoldenSample` 앞에 더한다:

```python
class FormatV2(unittest.TestCase):
    """R5 AC2 · AC3 · AC4 — 범위 하위 항목 · 선택 칸 · 새 재분해 이력."""

    ROW = R.Row("A1", "가", R.KIND_BUNDLE, "", "의도", "한다 상태줄 · 패널(M2 · M3 결과에 맞춤) / 안 한다 계산(R0 · R5)",
                "없음", "feature/a · feature/b", "없음", ["C4"], extras={"크기": "중", "산출물": "docs/r.md"})

    def test_scope_lines_and_text_are_inverse(self):
        for scope in ("한다 a · b / 안 한다 c", "한다 x(가 · 나) / 안 한다 없음", "자유 글 범위"):
            lines = R.scope_lines(scope)
            value = [l[4:] for l in lines[1:]] if lines[0] == "- 범위:" else lines[0][len("- 범위: "):]
            self.assertEqual(R.scope_text(value), scope)
        self.assertEqual(R.scope_lines("한다 a / 안 한다 b"), ["- 범위:", "  - 한다: a", "  - 안 한다: b"])

    def test_scope_text_joins_hand_written_items_and_rejects_others(self):
        self.assertEqual(R.scope_text(["한다: a", "한다: b", "안 한다: c"]), "한다 a · b / 안 한다 c")
        for bad in (["한다: a"], ["안 한다: c"], ["한다: a", "모름: b", "안 한다: c"]):
            with self.assertRaises(R.TableError):
                R.scope_text(bad)

    def test_render_block_new_form(self):
        self.assertEqual(R.render_block(self.ROW),
                         "### A1 — 가\n- 의도: 의도\n- 범위:\n"
                         "  - 한다: 상태줄 · 패널(M2 · M3 결과에 맞춤)\n  - 안 한다: 계산(R0 · R5)\n"
                         "- 의존: 없음\n- 브랜치: feature/a · feature/b\n- 묶음: A1.md\n- 경로 예약: 없음\n"
                         "- 크기: 중\n- 산출물: docs/r.md\n")

    def test_block_round_trip_through_parser(self):
        text = ("---\ntype: roadmap\nsource_brief: b.md\n---\n\n## 에픽\n\n" + R.render_block(self.ROW)
                + "\n## 재분해 이력\n\n- 없음\n")
        rows = R.extract_rows(text, lambda name: (
            "---\ntype: epic-bundle\nepic: A1\nroadmap: r\nsource_brief: b.md\nids: [C4]\n---\n\n"
            "## 7. 인터페이스\n\n- 받는 것: 없음\n- 넘기는 것: 없음\n"))
        self.assertEqual(rows, [self.ROW])

    def test_table_narrow_unless_extras(self):
        plain = R.Row("B1", "나", R.KIND_DECISION, "", "i", "s", "없음", "없음", "없음", ["S1", "C4"])
        narrow = R.format_table([plain])
        self.assertIn("| " + " | ".join(R.COLUMNS) + " |", narrow)
        self.assertNotIn("크기", narrow)
        wide = R.format_table([plain, self.ROW])
        self.assertIn(" | ".join(R.COLUMNS + R.EXTRA_COLUMNS), wide)
        self.assertEqual(R.parse_table(wide), [plain, self.ROW])
        self.assertEqual(R.parse_table(narrow), [plain])

    def test_history_entry(self):
        self.assertEqual(R.history_entry("2026-10-17", "재분해", ["바뀜 R5", "새 R11"], ["좋아", "가 「나」 다"]),
                         "### 2026-10-17 · 재분해\n- 바뀜: 바뀜 R5 · 새 R11\n- 원문:\n  - 「좋아」\n  - 「가 「나」 다」\n")
        self.assertEqual(R.history_entry("2026-10-17", "처음 로드맵", [], ["승인"]),
                         "### 2026-10-17 · 처음 로드맵\n- 원문:\n  - 「승인」\n")
        for bad in ("열린 「 하나", "닫힌 」 하나", "", "줄\n바꿈"):
            with self.assertRaises(R.TableError):
                R.history_entry("2026-10-17", "x", [], [bad])

    def test_append_history_new_entry_after_old_lines(self):
        text = "## 재분해 이력\n\n- 2026-10-11 · 처음 · 「a」\n\n## 위험 번호표\n"
        got = R.append_history(text, R.history_entry("2026-10-17", "재분해", [], ["b"]))
        self.assertEqual(got, "## 재분해 이력\n\n- 2026-10-11 · 처음 · 「a」\n\n### 2026-10-17 · 재분해\n"
                              "- 원문:\n  - 「b」\n\n## 위험 번호표\n")
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py`
Expected: ERROR — `TypeError: __init__() got an unexpected keyword argument 'extras'`

- [ ] **Step 3: 렌더러를 고친다**

import 줄에 `EXTRA_FIELDS, field_text, is_quote` 를 더하고 상수를 더한다:

```python
from roadmap_model import (  # noqa: E402
    BLOCK_ID_RE, EXTRA_FIELDS, KEY_RE, OQ_LINE_RE, FormatError, brief_universe, bundle_ids, field_text,
    id_sort_key, is_quote, parse_ids, parse_roadmap, section_body)

EXTRA_COLUMNS = EXTRA_FIELDS
SCOPE_RE = re.compile(r"한다 (\S.*?) / 안 한다 (\S.*)")
```

`Row` 의 마지막 필드 뒤에 더한다:

```python
    extras: dict = field(default_factory=dict)   # 선택 칸 — 크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물
```

`_row` 의 첫 줄을 아래로 바꾸고 `return` 을 고친다(칸이 열하나면 `extra` 는 빈 목록):

```python
def _row(c: list, line: str) -> Row:
    rid, title, kind_cell, intent, scope, deps, branch, reserved, ids_cell, recv, give = c[:len(COLUMNS)]
    extras = dict((k, v) for k, v in zip(EXTRA_COLUMNS, c[len(COLUMNS):]) if v != "없음")
```

```python
    return Row(rid, title, kind, spec, intent, scope, deps, branch, reserved, ids, recv, give, extras)
```

`parse_table` 의 머리 · 구분 · 행 검사를 칸 수에 맞춘다:

```python
    head = _split_row(lines[0])
    if head == list(COLUMNS):
        width = len(COLUMNS)
    elif head == list(COLUMNS + EXTRA_COLUMNS):
        width = len(COLUMNS) + len(EXTRA_COLUMNS)
    else:
        raise TableError("분해안 표 머리가 칸 열하나(%s) 또는 그 뒤에 선택 칸 여섯(%s)을 더한 열일곱이 아니다"
                         % (" · ".join(COLUMNS), " · ".join(EXTRA_COLUMNS)))
    sep = _split_row(lines[1])
    if len(sep) != width or not all(c.count("-") >= 3 and set(c) <= set("-:") for c in sep):
        raise TableError("분해안 표 구분 행의 칸 수가 머리와 다르다")
    rows, seen = [], set()
    for line in lines[2:]:
        cells = _split_row(line)
        if len(cells) != width:
            raise TableError("분해안 표 행의 칸 수가 머리와 다르다: %r" % line)
```

`format_table` 을 바꾼다:

```python
def format_table(rows: list) -> str:
    wide = any(r.extras for r in rows)
    cols = COLUMNS + (EXTRA_COLUMNS if wide else ())
    out = [TABLE_HEADING, "", "| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        cells = [r.id, r.title, r.kind_cell(), r.intent, r.scope, r.deps, r.branch, r.reserved,
                 " · ".join(r.ids), r.receives, r.gives]
        if wide:
            cells += [r.extras.get(k, "없음") for k in EXTRA_COLUMNS]
        out.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    return "\n".join(out) + "\n"
```

`render_block` 위에 두 함수를 더하고 `render_block` 을 바꾼다:

```python
def scope_lines(scope: str) -> list:
    """표 칸 「한다 X / 안 한다 Y」 → `- 범위:` 와 하위 항목 둘. 그 꼴이 아니면 한 줄 그대로."""
    m = SCOPE_RE.fullmatch(scope)
    if not m:
        return ["- 범위: " + scope]
    return ["- 범위:", "  - 한다: " + m.group(1), "  - 안 한다: " + m.group(2)]


def scope_text(value) -> str:
    """로드맵 범위 칸 → 표 칸. 하위 항목은 「한다: …」 · 「안 한다: …」 만이고 둘 다 있어야 한다."""
    if isinstance(value, str):
        return value
    do = [i[len("한다: "):] for i in value if i.startswith("한다: ")]
    dont = [i[len("안 한다: "):] for i in value if i.startswith("안 한다: ")]
    if len(do) + len(dont) != len(value) or not do or not dont:
        raise TableError("범위 하위 항목은 「한다: …」 · 「안 한다: …」 뿐이고 둘 다 있어야 한다: %r" % value)
    return "한다 %s / 안 한다 %s" % (" · ".join(do), " · ".join(dont))


def render_block(r: Row) -> str:
    lines = ["### %s — %s" % (r.id, r.title), "- 의도: " + r.intent] + scope_lines(r.scope) + [
        "- 의존: " + r.deps,
        "- 완료: 결정 기록" if r.kind == KIND_DECISION else "- 브랜치: " + r.branch,
        "- 묶음: " + (r.id + ".md" if r.kind == KIND_BUNDLE else "없음"),
        "- 경로 예약: " + r.reserved]
    if r.kind == KIND_BRANCH:
        lines.append("- spec: " + r.spec)
    if r.kind != KIND_BUNDLE:
        lines.append("- 발화: " + " · ".join(t for t in r.ids if _is_s(t)))
        lines.append("- 항목: " + " · ".join(t for t in r.ids if not _is_s(t)))
    lines += ["- %s: %s" % (k, r.extras[k]) for k in EXTRA_COLUMNS if k in r.extras]
    return "\n".join(lines) + "\n"
```

`extract_rows` 에서 칸 값을 글로 바꿔 읽는다. 반복 맨 앞에 `f = b["fields"]` 뒤로 두 줄을 더하고, 두 `rows.append(Row(…))` 의 `f["의도"], f["범위"], f["의존"]` · `f["브랜치"]` · `f["경로 예약"]` · `f.get("브랜치", "없음")` 를 `t("의도"), scope_text(f["범위"]), t("의존")` · `t("브랜치")` · `t("경로 예약")` · `t("브랜치") if "브랜치" in f else "없음"` 로 바꾸고 끝에 `extras=extras` 를 넘긴다:

```python
        def t(key, f=f):
            return field_text(f[key])
        extras = dict((k, field_text(f[k])) for k in EXTRA_COLUMNS if k in f)
```

`append_history` 를 바꾸고 `history_entry` 를 더한다:

```python
def history_entry(date: str, reason: str, changes: list, quotes: list) -> str:
    """새 재분해 이력 항목 하나 — `### <날짜> · <사유>` · `- 바뀜:` · `- 원문:` + 줄마다 「…」."""
    for q in quotes:
        if not q or "\n" in q or not is_quote("「%s」" % q):
            raise TableError("원문은 한 줄이고 「 」 가 짝이 맞아야 한다: %r" % q)
    if not quotes:
        raise TableError("재분해 이력에 원문이 없다")
    if not reason.strip() or "\n" in reason:
        raise TableError("재분해 이력 사유는 한 줄이다: %r" % reason)
    out = ["### %s · %s" % (date, reason.strip())]
    if changes:
        out.append("- 바뀜: " + " · ".join(changes))
    out.append("- 원문:")
    out += ["  - 「%s」" % q for q in quotes]
    return "\n".join(out) + "\n"


def append_history(roadmap_text: str, entry: str) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 재분해 이력")
    body = "".join(lines[start + 1:end]).rstrip("\n")
    tail = "".join(lines[end:])
    sep = "\n\n" if entry.startswith("### ") else "\n"
    return ("".join(lines[:start + 1]) + body + sep + entry.rstrip("\n") + "\n"
            + ("\n" + tail if tail else ""))
```

- [ ] **Step 4: 생성 · 재분해가 새 이력을 쓰게 한다**

`roadmap_write.py`:
- import 줄을 `from roadmap_model import DATE_RE, FormatError, frontmatter, id_sort_key, section_body, strip_quotes, unquote` 로 바꾸고 `QUOTE_RE = re.compile(…)` 줄을 지운다.
- `used_numbers` 의 첫 줄을 `history = strip_quotes(section_body(roadmap_text, "## 재분해 이력") or "")` 로 바꾼다.
- `cmd_create` 의 `history = …` 줄을 `history = R.history_entry(date, "처음 로드맵", [], a.approval).rstrip("\n")` 로 바꾼다.
- `cmd_update` 의 `parts = …` 부터 `new_text = …` 까지를 아래로 바꾼다:

```python
    changes = ["%s %s" % (label, " · ".join(ids))
               for label, ids in (("바뀜", changed), ("새", added), ("사라짐", removed)) if ids]
    entry = R.history_entry(date, a.change, changes or ["순서만"], a.approval)
    new_text = R.append_history(R.replace_epics(old_text, blocks), entry)
```

- 끝의 `print(…)` 를 `" · ".join(changes) or "순서만"` 을 쓰도록 바꾼다.
- `build_parser` 에서 `create` · `update` 의 `--approval` 을 `c.add_argument("--approval", action="append", required=True)` 꼴로 따로 등록한다(나머지 플래그는 그대로 반복문에서).
- `main` 의 `except` 에 `R.TableError` 가 이미 있다 — `history_entry` 의 오류는 rc 1 이다.

- [ ] **Step 5: 바뀐 기대값을 고치고 왕복 단언을 더한다**

`test_roadmap_render.py`:
- 줄 183–188: `render_roadmap` 의 이력 인자를 `R.history_entry("2026-10-15", "처음 로드맵", [], ["승인"]).rstrip("\n")` 로, 기대값을 `"## 재분해 이력\n\n### 2026-10-15 · 처음 로드맵\n- 원문:\n  - 「승인」\n\n## 위험 번호표\n"` 로.
- 줄 147 근처 블록 기대값의 `- 범위: 한다 결정 / 안 한다 코드\n` 을 `- 범위:\n  - 한다: 결정\n  - 안 한다: 코드\n` 으로.

`test_roadmap_write.sh`:
- 줄 134 의 단언 하나를 둘로: `assert_file_has "$W/docs/rm/roadmap.md" "### 2026-10-15 · 처음 로드맵" "재분해 이력 첫 머리"` · `assert_file_has "$W/docs/rm/roadmap.md" "  - 「이대로 승인 (권장)」" "재분해 이력 첫 원문"`.
- `"· 바뀜 E2 「이대로 다시 나눈다」"` 단언(처음 표 순서에서 E2 만 고침)을 `"- 바뀜: 바뀜 E2"` 로.
- `"- 범위: 한다 다 · 마 / 안 한다 라" "update: 바뀐 E2 블록 범위 줄"` 단언을 `"  - 한다: 다 · 마"` · `"  - 안 한다: 라"` 둘로(묶음 `E2.md` 의 범위 줄 단언은 그대로 — 묶음 형식은 바뀌지 않는다).
- 줄 278 의 이력 단언을 셋으로: `"### 2026-10-16 · 경계 조정"` · `"- 바뀜: 바뀜 E2"` · `"  - 「이대로 다시 나눈다」"`.
- 줄 399 를 `grep -qxF -- "- 바뀜: 순서만" "$W/docs/rm/roadmap.md" && ok "순서만: 이력에 순서만이라 적는다" || no "순서만: 이력 줄이 다르다"` 로.
- Review Focus 2 — 「순서만」 장면(`for f in E2 E4 E6; do cp …keep`) 바로 앞에 `B_E2="$(block_of E2)"; B_E6="$(block_of E6)"` 를 두고, 그 장면의 단언들 뒤에 더한다:

```bash
assert_eq "$(block_of E2)" "$B_E2" "순서만: 바뀌지 않은 E2 블록(범위 하위 항목)은 바이트 그대로"
assert_eq "$(block_of E6)" "$B_E6" "순서만: 바뀌지 않은 E6 블록은 바이트 그대로"
assert_contains "$B_E2" "  - 한다: " "E2 블록은 새 꼴이다(이 단언이 하위 항목 블록을 잰다는 양성 짝)"
```

`test_roadmap_write.py` 끝(마지막 클래스 뒤)에 더한다:

```python
class Approval(unittest.TestCase):
    def test_approval_repeats(self):
        a = W.build_parser().parse_args(["update", "--roadmap", "r", "--brief", "b", "--audit", "a",
                                         "--plan-table", "t", "--date", "2026-10-17", "--change", "c",
                                         "--approval", "첫 말", "--approval", "둘째 말"])
        self.assertEqual(a.approval, ["첫 말", "둘째 말"])
```

- [ ] **Step 6: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_render_r2.py plugins/spec-distill/tests/test_roadmap_write.py && bash plugins/spec-distill/tests/test_roadmap_write.sh && bash plugins/spec-distill/tests/test_decompose_surface.sh`
Expected: 모두 OK / `Fail: 0`. 단, `GoldenSample.test_blocks_byte_equal` · `test_epics_section_rebuilds` 는 이 로드맵이 아직 옛 꼴이라 **실패한다** — Task 13 이 로드맵을 옮겨 다시 초록이 된다. 이 두 실패를 원장에 적고 다른 실패가 없는지 본다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_write.sh
git commit -m "feat(spec-distill): 생성기가 범위 하위 항목 · 선택 칸 · 새 재분해 이력을 쓴다

이 로드맵의 정답 견본 둘은 Task 13(옮기기)까지 빨갛다.

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 5: 기본 브랜치를 origin/HEAD 에서 · 「기본 브랜치에 없음」 종료 코드 4 (AC39 · AC11 다섯째)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (머리 docstring · `MAIN_REF` 줄 35 · `NOTICE` · `Git.first_parent_merges` 줄 99–110 · `Source` 줄 149–168 · `merged_by` 줄 224 · `compute` 줄 285–287 · `build` 줄 398–419 · `exit_code` · `render` · `main`)
- Modify: `plugins/spec-distill/scripts/spec_review_bundle.py:108`
- Modify: `plugins/spec-distill/scripts/control_plane.py` (머리 docstring · `NO_ROADMAP` · `MAIN_REF` 줄 275 · `candidates` · `cache_key` · `run_status` · `unfinished` · `gather` · `tasks_output` · `statusline_text` · `show_text`)
- Modify: 빈 원격을 클론하거나 `remote add` 하는 셸 테스트들(`grep -ln 'clone -q\|remote add origin' plugins/spec-distill/tests/*.sh`)
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh` 끝에 장면을 더한다, `plugins/spec-distill/tests/test_control_plane.sh:233`

**Interfaces:**
- Produces: `roadmap_status.DEFAULT_REF = "refs/remotes/origin/HEAD"`, `Git.default_branch() -> (sha | None, 이름 | None)`(이름 예 `"origin/trunk"`), `Git.first_parent_merges(main: str)`, `Source(git, rev=None, root=None, label=None)`, 보고서 새 키 `default_branch`(이름) · `not_on_default`(bool), 종료 코드 4. `control_plane.DEFAULT_REF`, `default_ref(repo) -> (sha | None, 전체 참조 이름 | None)`.

- [ ] **Step 1: 픽스처에 origin/HEAD 를 둔다**

빈 bare 레포를 클론한 뒤 push 하면 `origin/HEAD` 가 생기지 않는다. 위 grep 이 찾은 파일마다 첫 `push -q origin main` 바로 뒤에 `git -C <그 작업 트리> remote set-head origin main` 한 줄을 더한다(`test_roadmap_status.sh` 는 `g remote set-head origin main`). 각 파일을 지금 코드로 돌려 결과가 그대로인지 본다:

Run: `for f in $(grep -ln 'clone -q\|remote add origin' plugins/spec-distill/tests/*.sh); do bash "$f" > /dev/null 2>&1; echo "$f rc=$?"; done`
Expected: Task 0 기준선과 같은 rc.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test_roadmap_status.sh` 의 `summary` 호출 바로 앞에 더한다(같은 파일의 `write_brief` · `bundle` · `block` · `roadmap_head` · `roadmap_tail` · `pr_merge` 함수를 쓴다):

```bash
# ── R5 AC39 · AC11 — 기본 브랜치 이름이 main 이 아닌 레포 · origin/HEAD 없음 · 기본 브랜치에 없는 로드맵 ──
git init -q --bare -b trunk "$T/trunk.git"
git clone -q "$T/trunk.git" "$T/tw" 2>/dev/null
W_SAVE="$W"; W="$T/tw"
g symbolic-ref HEAD refs/heads/trunk
commit_file README.txt "시작" "init"
g push -q origin trunk
write_brief "$W/docs/br"; mkdir -p "$W/docs/rm"
bundle docs/rm A1 "C1, D2, OQ1, RC1, ST1, «k1», K1, K2, S1, S2"
{ roadmap_head; block A1 feature/a1 없음 없음; roadmap_tail ""; } > "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "docs" && g push -q origin trunk
g checkout -q -b feature/a1 trunk; commit_file src/a.txt a "a1"
g checkout -q trunk && g merge -q --no-ff feature/a1 -m "Merge pull request #9 from o/feature/a1" && g push -q origin trunk
g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$T/trunk-nohead.json"); rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → 검사 불가(rc 3)"
assert_contains "$(js "$T/trunk-nohead.json" "' | '.join(r['unknown_reasons'])")" "origin/HEAD" "origin/HEAD 없음 사유가 보인다 — 조용한 「로드맵 없음」이 아니다"
g remote set-head origin trunk
(cd "$W" && python3 "$RS" --json docs/rm/roadmap.md > "$T/trunk.json"); rc=$?
assert_eq "$(js "$T/trunk.json" "r['default_branch']")" "origin/trunk" "기본 브랜치 이름을 origin/HEAD 에서 읽는다"
assert_eq "$(js "$T/trunk.json" "r['source']")" "origin/trunk" "사본 이름도 기본 브랜치"
assert_eq "$(stage "$T/trunk.json" A1)" "머지됨" "기본 브랜치가 trunk 여도 머지됨"
out="$(cd "$W" && python3 "$RS" docs/none/roadmap.md)"; rc=$?
assert_eq "$rc" "4" "기본 브랜치에 없는 로드맵 → rc 4(검사 불가 3 과 다르다)"
assert_contains "$out" "로드맵이 아직 기본 브랜치(origin/trunk)에 없다" "기본 브랜치에 없음 줄"
assert_not_contains "$out" "검사 불가: " "기본 브랜치에 없음은 검사 불가 줄이 아니다"
for f in roadmap_status.py control_plane.py spec_review_bundle.py; do
  assert_eq "$(grep -c 'origin/main' "$S/$f")" "0" "$f 에 origin/main 을 박지 않는다(AC39)"
done
W="$W_SAVE"
```

`test_control_plane.sh:233` 의 기대값을 `"로드맵이 아직 기본 브랜치(origin/main)에 없다"` 로 바꾸고, 그 바로 뒤에 `show --tasks` 가 rc 4 와 같은 사유를 표준 오류로 내는지 단언을 더한다:

```bash
out="$(cd "$W" && python3 "$REAL/control_plane.py" show --tasks docs/superpowers/roadmaps/none/roadmap.md 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "4" "작업 목록: 기본 브랜치에 없는 로드맵 → rc 4"
assert_contains "$out" "--roadmap-file" "작업 목록: 머지 전이면 작업 트리 사본으로 계산하라는 안내"
```

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 15; bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 5`
Expected: 새 단언들이 `✗` (rc 3 대신 rc 3 이 나오지만 사유에 origin/HEAD 가 없다 · `default_branch` 키 없음 · rc 4 아님 · `origin/main` 이 0 이 아님).

- [ ] **Step 4: 상태 계산을 고친다**

`roadmap_status.py`:

```python
DEFAULT_REF = "refs/remotes/origin/HEAD"
NO_DEFAULT = ("기본 브랜치를 알 수 없다 — origin/HEAD 가 없다. `git remote set-head origin --auto` 로 만든 뒤 "
              "다시 계산한다")
```

`MAIN_REF = …` 줄을 지우고 위 두 상수를 둔다. `Git` 에 더한다:

```python
    def default_branch(self):
        """(커밋, 이름) — origin/HEAD 가 가리키는 기본 브랜치. 못 풀면 (None, None)."""
        sha = self.commit(DEFAULT_REF)
        if not sha:
            return None, None
        rc, out = self.run("rev-parse", "--symbolic-full-name", DEFAULT_REF)
        full = out.strip() if rc == 0 else ""
        return sha, (full[len("refs/remotes/"):] if full.startswith("refs/remotes/") else "origin/HEAD")
```

`first_parent_merges(self)` 를 `first_parent_merges(self, main)` 로 바꾸고 `MAIN_REF` 자리에 `main` 을 넘긴다. `compute` 의 `merges = git.first_parent_merges() if main else []` 를 `git.first_parent_merges(main)` 으로.

`Source.__init__` 을 `def __init__(self, git, rev=None, root=None, label=None):` 로 바꾸고 `self.label = label or ("기본 브랜치" if rev else "작업 트리")` 로.

`merged_by` 의 `"main 의 머지 커밋 %s"` → `"기본 브랜치의 머지 커밋 %s"`, `"브랜치 끝이 main 에 들어 있음"` → `"브랜치 끝이 기본 브랜치에 들어 있음"`. `compute` 의 `"origin/main 을 못 읽었다"` → `"기본 브랜치를 못 읽었다"`. `NOTICE` 안의 `main` 을 「기본 브랜치」로(`나중 PR 이 기본 브랜치를 merge 하고`).

`build` 의 머리를 아래로 바꾼다:

```python
def build(git: Git, args) -> dict:
    report = {"roadmap": None, "source": None, "default_branch": None, "not_on_default": False,
              "fetched_at": git.fetched_at(), "notice": NOTICE, "blocks": [], "unassigned": None,
              "orphans": None, "unknown_ids": [], "overlaps": [], "format_errors": [], "unknown_reasons": [],
              "exit": 3}
    main, main_name = git.default_branch()
    report["default_branch"] = main_name
    if args.roadmap_file:
        top = git.toplevel()
        if top is None:
            report["unknown_reasons"].append("git 레포 안이 아니다")
            return report
        rel = os.path.relpath(os.path.realpath(args.roadmap_file), os.path.realpath(top))
        src = Source(git, root=top)
        if main is None:
            report["unknown_reasons"].append(NO_DEFAULT)
    else:
        rel = args.roadmap.strip("/")
        report["roadmap"] = rel
        if main is None:
            report["unknown_reasons"].append(NO_DEFAULT)
            report["source"] = "기본 브랜치"
            return report
        src = Source(git, rev=main, label=main_name)
        if not src.exists(rel):
            report["source"], report["not_on_default"] = main_name, True
            return report
```

(그 뒤 `report["roadmap"], report["source"] = rel, src.label` 부터는 그대로.) `exit_code` 맨 앞에 더한다:

```python
    if report.get("not_on_default") and not report["format_errors"] and not report["unknown_reasons"]:
        return 4
```

`render` 의 첫 줄 `(사본: %s · origin/main 받은 시각: %s)` 를 `(사본: %s · 받은 시각: %s)` 로 바꾸고, `lines = [...]` 바로 뒤에 더한다:

```python
    if report.get("not_on_default"):
        lines.append("로드맵이 아직 기본 브랜치(%s)에 없다 — 머지 전이면 `--roadmap-file` 로 계산한다: %s"
                     % (report.get("default_branch") or "알 수 없음", report.get("roadmap")))
```

`main` 의 내부 오류 보고서에 `"default_branch": None, "not_on_default": False` 를 더한다. 머리 docstring 의 명령줄 설명을 「기본 브랜치(origin/HEAD)의 로드맵을 읽는다」로, 종료 코드 줄에 `4 로드맵이 아직 기본 브랜치에 없음(머지 전 — `--roadmap-file` 로 계산한다)` 를 더하고 순서를 `3 > 4 > 1 > 0` 으로 적는다. `argparse` 의 `help="origin/main 기준 …"` 을 `help="기본 브랜치 기준 로드맵 레포 상대경로"` 로.

`spec_review_bundle.py:108` 의 `main = git.commit(rs.MAIN_REF)` 를 `main, _name = git.default_branch()` 로. 끝나면 `grep -n 'origin/main\|MAIN_REF' plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/spec_review_bundle.py` 가 아무것도 내지 않을 때까지 남은 글(주석 · 도움말 포함)을 「기본 브랜치」로 바꾼다.

- [ ] **Step 5: 화면을 고친다**

`control_plane.py`: `MAIN_REF = …` 를 지우고 더한다:

```python
DEFAULT_REF = "refs/remotes/origin/HEAD"


def default_ref(repo):
    """(커밋, 전체 참조 이름) — origin/HEAD 가 가리키는 기본 브랜치. 없으면 (None, None)."""
    sha = repo.line("rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if not sha:
        return None, None
    return sha, repo.line("rev-parse", "--symbolic-full-name", DEFAULT_REF)
```

- `candidates(repo, main)`: `ls-tree … MAIN_REF` 의 `MAIN_REF` 를 `main` 으로, 사유 글의 `origin/main` 을 「기본 브랜치」로.
- `cache_key(repo, main, mode, targets)` 를 `cache_key(repo, main, main_full, mode, targets)` 로 바꾸고 `name != MAIN_REF` 를 `name != main_full` 로(주석의 origin/main 도 「기본 브랜치」로).
- `gather`: `main = repo.line(… MAIN_REF …)` 를 `main, main_full = default_ref(repo)` 로, 로드맵 blob 확인의 `"%s:%s" % (MAIN_REF, arg)` 를 `"%s:%s" % (main, arg)` 로, `cache_key(repo, main, mode, targets)` 를 `cache_key(repo, main, main_full, mode, targets)` 로.
- `run_status` 의 허용 종료 코드를 `(0, 1, 3, 4)` 로. `unfinished` 는 `report.get("exit") in (3, 4)` 도 참.
- `tasks_output` 의 `if report.get("exit") == 3:` 앞에 더한다:

```python
    if report.get("exit") == 4:
        return [], clean("로드맵이 아직 기본 브랜치에 없다 — 머지 전이면 roadmap_status.py --roadmap-file %s 로 계산한다"
                         % _path), 4
```

- `statusline_text`: `select_error or any(r.get("exit") == 3 …)` 앞에 `if any(r.get("exit") == 4 for _p, r in items): parts.append("기본 브랜치에 없음")` 을 더한다.
- `show_text`: `lines.append(clean("로드맵: %s" % path))` 바로 뒤에 `if report.get("not_on_default"): lines.append(clean("로드맵이 아직 기본 브랜치(%s)에 없다 — 머지 전이면 `--roadmap-file` 로 계산한다" % (report.get("default_branch") or "알 수 없음")))` 를 더한다.
- `NO_ROADMAP` 의 `origin/main` 을 「기본 브랜치」로. 머리 docstring 의 `(origin/main 사본)` 을 `(기본 브랜치 사본)` 으로, `show --tasks` 설명에 `기본 브랜치에 없는 로드맵이면 rc 4` 를 더한다.
- 끝나면 `grep -n 'origin/main\|MAIN_REF' plugins/spec-distill/scripts/control_plane.py` 가 아무것도 내지 않을 때까지 남은 글을 바꾼다.
- 기본 브랜치가 없을 때(`main is None`) 인자 없는 상태줄은 지금처럼 고를 것이 없다(로드맵 없음 — 아무 레포에서나 도는 상태줄이 늘 「검사 불가」를 내지 않게). 인자가 있으면 `run_status` 가 `NO_DEFAULT` 사유를 낸다.

- [ ] **Step 6: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_spec_review_bundle.sh 2>&1 | tail -n 3; python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: `Fail: 0` 셋과 `OK`. `"main 의 머지 커밋"` 같은 옛 근거 글을 단언하던 줄이 있으면 새 글로 고친다(`grep -n '머지 커밋' plugins/spec-distill/tests/*.sh`).

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/scripts/spec_review_bundle.py plugins/spec-distill/tests/
git commit -m "fix(spec-distill): 기본 브랜치를 origin/HEAD 에서 읽고 기본 브랜치에 없는 로드맵은 rc 4

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 6: 상태 계산 — 레포 설정 폴더 · 백틱 없는 `**Spec:**` · N17 경고 (AC14 · AC11 둘째 · AC12)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`find_specs` 줄 195–206 · `has_plan` 줄 209–216 · `_GitTreeRepo` 줄 237–259 · `compute` · `build`)
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh` (장면 더함)

**Interfaces:**
- Consumes: `repo_defaults.repo_settings`(Task 1), `roadmap_model.field_text`(Task 2).
- Produces: `spec_line_path(line: str) -> str | None`, `plan_specs(text: str) -> set`, `find_specs(git, tree, block, bundle_path, specs_dir)`, `has_plan(git, tree, spec, plans_dir)`, `_GitTreeRepo(git, tree).specs_for(source, specs_dir=None)`, `compute(git, main, blocks, records, bundles, roadmap_dir, settings)`, 보고서 새 키 `settings`(`specs_dir` · `plans_dir` · `test_command` · `review_model` · `sources`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_roadmap_status.sh` 의 Task 5 장면 뒤(같은 `summary` 앞)에 더한다. 둘째 로드맵 `docs/rm2/roadmap.md` 를 원래 작업 트리 `$W` 에 둔다:

```bash
# ── R5 AC14 · AC11 · AC12 — 레포 설정 폴더 · 백틱 없는 **Spec:** · 대조를 건너뛴 블록 ───────────
g checkout -q main
mkdir -p "$W/docs/rm2"
bundle docs/rm2 D1 "C1, S1"; bundle docs/rm2 D2 "C1, S1"
{ printf -- '---\ntype: roadmap\nsource_brief: docs/br/b.md\nspecs_dir: design\nplans_dir: work/plans/\n---\n\n# 로드맵\n\n## 에픽\n\n'
  block D1 feature/d1 없음 없음
  block D2 feature/d2 없음 없음
  printf '### N2 — 묶음 없는 블록\n- 의도: n\n- 범위: n\n- 의존: 없음\n- 브랜치: feature/n2\n- 묶음: 없음\n- 경로 예약: 없음\n- spec: design/n2-design.md\n- 발화: S1\n- 항목: C1\n\n'
  roadmap_tail ""
} > "$W/docs/rm2/roadmap.md"
g add -- docs/rm2 && g commit -qm "rm2" && g push -q origin main
# D1 — 설계문서는 design/ 에 · 계획은 work/plans/ 에 · **Spec:** 뒤에 백틱 없이 → 계획
g checkout -q -b feature/d1 main; mkdir -p "$W/design" "$W/work/plans" "$W/docs/superpowers/specs"
spec_doc docs/rm2/D1.md "C1 · S1" > "$W/design/d1-design.md"
printf '# 계획\n\n**Spec:** design/d1-design.md (§1)\n' > "$W/work/plans/d1.md"
g add -- design work && g commit -qm "d1" && g push -q origin feature/d1
# D2 — 기본 폴더(docs/superpowers/specs/)에만 설계문서 → 이 로드맵은 찾지 않는다
g checkout -q -b feature/d2 main; mkdir -p "$W/docs/superpowers/specs"
spec_doc docs/rm2/D2.md "C1 · S1" > "$W/docs/superpowers/specs/d2-design.md"
g add -- docs && g commit -qm "d2" && g push -q origin feature/d2
# N2 — 묶음 아닌 블록이 계획 단계
g checkout -q -b feature/n2 main; mkdir -p "$W/design" "$W/work/plans"
printf '# n2\n' > "$W/design/n2-design.md"; printf '**Spec:** `design/n2-design.md`\n' > "$W/work/plans/n2.md"
g add -- design work && g commit -qm "n2" && g push -q origin feature/n2
g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm2/roadmap.md > "$T/rm2.json")
assert_eq "$(js "$T/rm2.json" "r['settings']['specs_dir']")" "design/" "레포 설정: specs_dir 를 frontmatter 에서"
assert_eq "$(stage "$T/rm2.json" D1)" "계획" "D1: frontmatter 폴더 + 백틱 없는 **Spec:** → 계획"
assert_eq "$(stage "$T/rm2.json" D2)" "설계 중" "D2: 기본 폴더의 설계문서는 frontmatter 가 폴더를 정한 로드맵에서 찾지 않는다"
assert_eq "$(js "$T/rm2.json" "next(b['reason'] for b in r['blocks'] if b['id']=='D2')")" "브랜치 있음 · spec 없음" "D2 근거"
assert_contains "$(warns "$T/rm2.json" N2)" "번호 대조 건너뜀(셀 수 없음) — 묶음이 아닌 블록" "N17: 묶음 아닌 블록이 계획 단계면 경고"
assert_contains "$(warns "$OUT" A1)" "번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음" "N17: 설계문서 없이 머지된 묶음은 경고"
assert_not_contains "$(warns "$OUT" G1)" "번호 대조 건너뜀" "N17: 설계 중 단계는 아직 경고하지 않는다"
sed 's/^specs_dir: design$/specs_dir: ..\/x/' "$W/docs/rm2/roadmap.md" > "$T/rm2-bad.md"
cp "$T/rm2-bad.md" "$W/docs/rm2/roadmap.md"
(cd "$W" && python3 "$RS" --json --roadmap-file docs/rm2/roadmap.md > "$T/rm2-bad.json"); rc=$?
assert_eq "$rc" "3" "레포 설정 값이 잘못되면 검사 불가"
assert_contains "$(js "$T/rm2-bad.json" "' | '.join(r['format_errors'])")" "레포 설정 specs_dir" "잘못된 레포 설정 사유"
g checkout -q -- docs/rm2/roadmap.md
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | grep '✗'`
Expected: 새 단언들이 `✗` (`KeyError: 'settings'` 로 js 가 죽는 줄 포함).

- [ ] **Step 3: 상태 계산을 고친다**

import 에 `from repo_defaults import SPECS_DIR, repo_settings` 와 `field_text` 를 더한다(`roadmap_model` import 줄에). `find_specs` · `has_plan` 을 바꾸고 두 함수를 더한다:

```python
def spec_line_path(line: str):
    """`**Spec:**` 줄의 경로 — 바로 뒤가 백틱이면 그 안, 아니면 첫 토큰(백틱 뗌)."""
    rest = line.lstrip()[len("**Spec:**"):].strip()
    if rest.startswith("`"):
        m = BACKTICK_RE.match(rest)
        return m.group(1) if m else None
    tok = rest.split()[0] if rest.split() else ""
    return tok.strip("`") or None


def plan_specs(text: str) -> set:
    return {p for p in (spec_line_path(l) for l in text.splitlines() if l.lstrip().startswith("**Spec:**")) if p}


def find_specs(git: Git, tree: str, block: dict, bundle_path, specs_dir: str):
    if block["kind"] == "branch":
        spec = field_text(block["fields"]["spec"]).strip().strip("`")
        return [spec] if git.exists(tree, spec) else []
    if block["kind"] != "bundle" or bundle_path is None:
        return []
    found = []
    for path in git.grep_files(tree, bundle_path, specs_dir):
        text = git.blob(tree, path)
        if text and unquote(frontmatter(text).get("source_interview", "")) == bundle_path:
            found.append(path)
    return sorted(found)


def has_plan(git: Git, tree: str, spec: str, plans_dir: str) -> bool:
    return any(spec in plan_specs(git.blob(tree, path) or "") for path in git.grep_files(tree, spec, plans_dir))
```

`_GitTreeRepo.specs_for(self, source)` 를 `specs_for(self, source, specs_dir=None)` 로 바꾸고 `"docs/superpowers/specs/"` 를 `specs_dir or SPECS_DIR` 로, 메모 열쇠를 `(source, specs_dir or SPECS_DIR)` 로.

`compute` 의 서명을 `compute(git, main, blocks, records, bundles, roadmap_dir, settings)` 로 바꾸고 `find_specs(…, bundle_path)` 두 곳에 `settings["specs_dir"]` 를, `has_plan(git, tip, s)` 에 `settings["plans_dir"]` 를 넘긴다. 블록마다 단계가 정해진 뒤(번호 대조 반복 바로 앞) N17 을 더한다:

```python
        if b["stage"] in PAST_PLAN or b["stage"].startswith("일부 머지"):
            if b["kind"] == "bundle" and not b["specs"]:
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음이라 배정 번호 %d개를 "
                                     "대조하지 않았다" % len(b["assigned"]))
            elif b["kind"] == "branch":
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 묶음이 아닌 블록이라 배정 번호 %s 를 대조하지 "
                                     "않았다" % " · ".join(sorted(b["assigned"], key=id_sort_key)))
```

모듈 상수에 `PAST_PLAN = ("계획", "구현 중", "구현 끝", "PR", "머지됨")` 를 더한다.

`build` 에서 `meta, blocks, records, risk_rows, errors = parse_roadmap(text)` 바로 다음 줄(`report["format_errors"] = errors` 앞)에 레포 설정을 읽는다:

```python
    settings = repo_settings(meta)
    report["settings"] = dict((k, settings[k]) for k in ("specs_dir", "plans_dir", "test_command",
                                                            "review_model", "sources"))
    errors = errors + settings["errors"]
```

그리고 `compute(git, main, blocks, records, bundles, roadmap_dir)` 를 `compute(…, roadmap_dir, settings)` 로. 보고서 초기값과 내부 오류 보고서에 `"settings": None` 을 더한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_spec_review_bundle.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 3`
Expected: `Fail: 0` 셋. 머지된 묶음 블록(A1 · B1 · F1 · Q1)에 N17 경고가 생겨 `warns … == ""` 를 단언하던 줄이 있으면, 그 단언이 재던 것(다른 경고가 없음)을 `assert_not_contains` 로 좁혀 고친다 — 지우지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_roadmap_status.sh
git commit -m "feat(spec-distill): 상태 계산이 로드맵의 레포 설정 폴더를 읽고 대조를 건너뛴 블록을 경고한다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 7: 상태 계산 — 여러 브랜치 · 구현 중 · 구현 끝 · 산출물 (AC5 · AC6 · AC7)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`TASK_STATUS` · `Git` 에 메서드 셋 · `compute` 의 결정 아닌 블록 갈래 줄 297–321 · `build` 의 보고서 블록)
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh` (장면 더함), `plugins/spec-distill/tests/test_spec_review_bundle.sh` (산출물 이웃)

**Interfaces:**
- Consumes: `conductor_state.impl_done`(Task 3), `roadmap_model.field_list`(Task 2), `has_plan` 은 이 Task 뒤로 쓰지 않는다.
- Produces:
  - `Git.merge_base(a, b) -> sha | None`, `Git.changed(base, tip, pathspec=None)`, `Git.first_touch(base, tip, path) -> sha | None`, `Git.trailer_after(commit, tip, lines: set) -> bool`.
  - `branch_plans(git, base, tip, specs, plans_dir) -> list[(계획 경로, 계획을 처음 더한 커밋)]`, `progress(git, main, tip, block, bundle_path, settings) -> (단계, 근거, 설계문서들, 계획들)`.
  - `task_status(stage) -> str | None`.
  - 보고서 블록 새 키: `branches`(목록) · `branch_states`(`[{"branch","tip","merged"}]`) · `tip`(진행 중 브랜치 끝 또는 None) · `plans`(목록).
  - 단계 이름: `구현 중` · `구현 끝` · `일부 머지 <n>/<m>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_roadmap_status.sh` 의 Task 6 장면 뒤에 더한다:

```bash
# ── R5 AC5 · AC6 · AC7 — 여러 브랜치 · 구현 중 · 구현 끝 · 산출물 ─────────────────────────────
g checkout -q main
mkdir -p "$W/docs/rm3"
for b in K1 K2 K3 M2 O1; do bundle docs/rm3 "$b" "C1, S1"; done
{ roadmap_head | sed 's|^# 로드맵|# 로드맵 셋|'
  block K1 "feature/k1a · feature/k1b · feature/k1c" 없음 없음
  block K2 feature/k2 없음 없음
  block K3 feature/k3 없음 없음
  block M2 "feature/m2a · feature/m2b" 없음 없음
  printf '### O1 — 조사\n- 의도: o\n- 범위: o\n- 의존: 없음\n- 브랜치: feature/o1\n- 묶음: O1.md\n- 경로 예약: 없음\n- 흐름: 조사 「조사로 간다」\n- 산출물: docs/research/o1.md\n\n'
  roadmap_tail ""
} > "$W/docs/rm3/roadmap.md"
g add -- docs/rm3 && g commit -qm "rm3" && g push -q origin main
mkdir -p "$W/docs/superpowers/specs" "$W/docs/superpowers/plans"
SPEC_K1=docs/superpowers/specs/k1-design.md
# K1 — 첫 브랜치(계획 1)는 구현 대조 절까지 · 머지. 둘째 브랜치(계획 2)는 계획만 — 첫 계획의 절을 물려받는다.
g checkout -q -b feature/k1a main
spec_doc docs/rm3/K1.md "C1 · S1" > "$W/$SPEC_K1"
printf '**Spec:** `%s`\n' "$SPEC_K1" > "$W/docs/superpowers/plans/k1-p1.md"
g add -- docs && g commit -qm "k1 계획 1"
commit_file src/k1.txt k1 "$(printf 'k1 구현\n\nSpec: %s' "$SPEC_K1")"
printf '\n## 구현 대조 — docs/superpowers/plans/k1-p1.md\n\n- 요약\n' >> "$W/$SPEC_K1"
g add -- docs && g commit -qm "k1 구현 대조"
pr_merge 21 feature/k1a; g push -q origin main
g checkout -q -b feature/k1b main
printf '**Spec:** `%s`\n' "$SPEC_K1" > "$W/docs/superpowers/plans/k1-p2.md"
g add -- docs && g commit -qm "k1 계획 2"
# K2 — 계획 뒤 Spec: 트레일러 커밋 → 구현 중
g checkout -q -b feature/k2 main
spec_doc docs/rm3/K2.md "C1 · S1" > "$W/docs/superpowers/specs/k2-design.md"
printf '**Spec:** `docs/superpowers/specs/k2-design.md`\n' > "$W/docs/superpowers/plans/k2.md"
g add -- docs && g commit -qm "$(printf 'k2 계획\n\nSpec: docs/superpowers/specs/k2-design.md')"
commit_file src/k2.txt k2 "$(printf 'k2 구현\n\nSpec: docs/superpowers/specs/k2-design.md')"
# K3 — 계획 커밋 자신에만 트레일러 → 아직 계획
g checkout -q -b feature/k3 main
spec_doc docs/rm3/K3.md "C1 · S1" > "$W/docs/superpowers/specs/k3-design.md"
printf '**Spec:** `docs/superpowers/specs/k3-design.md`\n' > "$W/docs/superpowers/plans/k3.md"
g add -- docs && g commit -qm "$(printf 'k3 계획\n\nSpec: docs/superpowers/specs/k3-design.md')"
# M2 — 두 브랜치 모두 머지
for br in feature/m2a feature/m2b; do
  g checkout -q -b "$br" main; commit_file "src/${br##*/}.txt" x "$br"; pr_merge 30 "$br"
done
g push -q origin main
# O1 — 산출물이 생김(번호 대조 절 없음)
g checkout -q -b feature/o1 main; mkdir -p "$W/docs/research"
printf -- '---\nsource_interview: docs/rm3/O1.md\n---\n\n# 조사 결과\n\n## 결정 기록\n\n- B1 · 결정 · 조사 결론\n' > "$W/docs/research/o1.md"
g add -- docs && g commit -qm "o1"
g checkout -q main; g fetch -q origin
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3.json")
assert_eq "$(stage "$T/rm3.json" K1)" "일부 머지 1/3" "AC5: 세 브랜치 중 하나 머지 → 일부 머지 1/3"
assert_contains "$(js "$T/rm3.json" "next(b['reason'] for b in r['blocks'] if b['id']=='K1')")" "feature/k1b — 계획" "AC7: 둘째 브랜치는 앞 계획의 구현 대조 절을 물려받아도 계획 단계"
assert_eq "$(js "$T/rm3.json" "next(b['task_status'] for b in r['blocks'] if b['id']=='K1')")" "in_progress" "일부 머지는 진행 중"
assert_eq "$(stage "$T/rm3.json" K2)" "구현 중" "AC7: 계획 뒤 Spec: 트레일러 커밋 → 구현 중"
assert_eq "$(stage "$T/rm3.json" K3)" "계획" "AC7: 계획 커밋 자신의 트레일러는 구현 중이 아니다"
assert_eq "$(stage "$T/rm3.json" M2)" "머지됨" "AC5: 모든 브랜치 머지 → 머지됨"
assert_eq "$(stage "$T/rm3.json" O1)" "설계 중" "AC6: 산출물이 생기면 설계문서처럼 단계를 매긴다"
assert_eq "$(js "$T/rm3.json" "next(b['specs'] for b in r['blocks'] if b['id']=='O1')")" "['docs/research/o1.md']" "AC6: 산출물을 설계문서 자리로 읽는다"
assert_eq "$(js "$T/rm3.json" "' | '.join(r['unknown_reasons'])")" "" "AC6: 번호 대조 절 없는 산출물은 검사 불가가 아니다"
# K1 — 둘째 브랜치를 아직 만들지 않았으면(첫 브랜치만 머지) 예정 브랜치를 미완료로 센다
g branch -q -D feature/k1b
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3b.json")
assert_eq "$(stage "$T/rm3b.json" K1)" "일부 머지 1/3" "AC5: 첫 머지 뒤 남은 예정 브랜치 때문에 머지됨이 아니다"
assert_contains "$(js "$T/rm3b.json" "next(b['reason'] for b in r['blocks'] if b['id']=='K1')")" "다음 브랜치 없음: feature/k1b" "다음 예정 브랜치 이름을 보인다"
```

`test_spec_review_bundle.sh` 의 `finish`(또는 `summary`) 바로 앞에 더한다 — R3 에 의존하는 산출물 에픽 R7 을 로드맵에 넣는다:

```bash
# ── R5 AC6 — 이웃 읽기가 산출물을 읽는다 ─────────────────────────────────────
g checkout -q main
nb_bundle R7 "C1"
R7_BLOCK="$(printf '### R7 — 이웃 조사\n- 의도: R7\n- 범위: R7\n- 의존: R3\n- 브랜치: feature/r7\n- 묶음: R7.md\n- 경로 예약: 없음\n- 크기: 작음\n- 산출물: docs/research/r7.md\n')"
R7_BLOCK="$R7_BLOCK" awk 'index($0, "## 결정 기록") == 1 { print ENVIRON["R7_BLOCK"]; print "" } { print }' \
  "$W/docs/rm/roadmap.md" > "$T/rm.r7" && cp "$T/rm.r7" "$W/docs/rm/roadmap.md"
g add -- docs && g commit -qm "R7 이웃" && g push -q origin main
g checkout -q -b feature/r7 main
put docs/research/r7.md '---\nsource_interview: docs/rm/R7.md\n---\n\n# 조사\n\n## 결정 기록\n\n- B7 · 결정 · 2026-10-17 · 조사 결론 — 「가」\n'
g add -- docs && g commit -qm "r7 산출물"; g checkout -q main; g fetch -q origin
nbr7="$(cd "$T" && python3 "$SRB" neighbors --bundle docs/rm/R3.md --root "$W")"
assert_contains "$nbr7" "R7 — docs/research/r7.md" "AC6: 이웃 결정에 산출물 경로"
assert_contains "$nbr7" "- B7 · 결정 · 2026-10-17 · 조사 결론" "AC6: 이웃 읽기가 산출물의 결정 줄을 읽는다"
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | grep '✗'`
Expected: 새 단언들이 `✗` (K1 은 「설계 중」 또는 브랜치 이름 하나로 읽혀 「준비」, K2 는 「계획」, O1 은 「설계 중 · 브랜치 있음 · spec 없음」 등).

- [ ] **Step 3: git 메서드를 더한다**

`Git` 에 더하고 `changed` 를 바꾼다:

```python
    def merge_base(self, a: str, b: str):
        rc, out = self.run("merge-base", a, b)
        return out.strip() if rc == 0 and out.strip() else None

    def changed(self, base: str, tip: str, pathspec=None):
        args = ["diff", "--name-only", "-z", "%s...%s" % (base, tip)]
        if pathspec:
            args += ["--", pathspec]
        rc, out, err = self.run_err(*args)
        if rc != 0:
            self.fail("diff", rc, err)
            return []
        return [p for p in out.split("\0") if p]

    def first_touch(self, base: str, tip: str, path: str):
        rc, out, err = self.run_err("log", "--format=%H", "--reverse", "%s..%s" % (base, tip), "--", path)
        if rc != 0:
            self.fail("log", rc, err)
            return None
        first = out.split("\n", 1)[0].strip()
        return first or None

    def trailer_after(self, commit: str, tip: str, lines: set) -> bool:
        """commit 뒤(commit 제외) tip 까지 커밋 메시지에 lines 중 한 줄이 그대로 있는가."""
        rc, out, err = self.run_err("log", "--format=%x1e%B", "%s..%s" % (commit, tip))
        if rc != 0:
            self.fail("log", rc, err)
            return False
        return any(line.strip() in lines for body in out.split("\x1e") for line in body.splitlines())
```

- [ ] **Step 4: 진행 계산과 여러 브랜치를 넣는다**

import 에 `from conductor_state import impl_done` 와 `field_list` 를 더한다. `has_plan` 은 이제 부르는 곳이 없으니 지운다. 상수를 고친다:

```python
TASK_STATUS = {"대기": "pending", "준비": "pending", "설계 중": "in_progress", "계획": "in_progress",
               "구현 중": "in_progress", "구현 끝": "in_progress", "PR": "in_progress",
               "머지됨": "completed", "끝남": "completed"}


def task_status(stage):
    if stage and stage.startswith("일부 머지"):
        return "in_progress"
    return TASK_STATUS.get(stage)
```

`find_specs` 맨 앞에 산출물 갈래를 더한다:

```python
    if "산출물" in block["fields"]:
        return [p for p in field_list(block["fields"]["산출물"]) if git.exists(tree, p)]
```

`has_plan` 아래에 더한다:

```python
def branch_plans(git: Git, base: str, tip: str, specs: list, plans_dir: str) -> list:
    """이 브랜치가 기본 브랜치에서 갈라진 뒤 바꾼 계획 가운데 그 설계문서를 가리키는 것 — (경로, 처음 더한 커밋)."""
    out = []
    for path in git.changed(base, tip, plans_dir):
        text = git.blob(tip, path)
        if text is None or not (plan_specs(text) & set(specs)):
            continue
        out.append((path, git.first_touch(base, tip, path)))
    return sorted(out)


def progress(git: Git, main: str, tip: str, block: dict, bundle_path, settings: dict):
    """(단계, 근거, 설계문서들, 계획들) — 브랜치 하나의 진행. 앞 계획의 구현 대조 절은 뒤 계획을 끝내지 않는다."""
    specs = find_specs(git, tip, block, bundle_path, settings["specs_dir"])
    if not specs:
        return "설계 중", "브랜치 있음 · spec 없음", [], []
    base = git.merge_base(main, tip)
    if base is None:
        return "설계 중", "spec 있음 · 기본 브랜치와 갈라진 곳을 못 찾았다", specs, []
    plans = branch_plans(git, base, tip, specs, settings["plans_dir"])
    if not plans:
        return "설계 중", "spec 있음", specs, []
    texts = [git.blob(tip, s) or "" for s in specs]
    done = [p for p, _c in plans if any(impl_done(t, p) for t in texts)]
    paths = [p for p, _c in plans]
    if len(done) == len(plans):
        return "구현 끝", "구현 대조 절 있음: %s" % " · ".join(done), specs, paths
    trailers = {"Spec: " + s for s in specs}
    started = [p for p, c in plans if p not in done and c and git.trailer_after(c, tip, trailers)]
    if started or done:
        return "구현 중", "Spec: 트레일러 커밋 있음: %s" % " · ".join(started + done), specs, paths
    return "계획", "계획 있음", specs, paths
```

`compute` 의 결정 아닌 블록 갈래(`branch = b["fields"]["브랜치"]…` 부터 `if undone: b["warnings"].append("의존 미머지 …")` 까지)를 아래로 바꾼다:

```python
        bundle_path = (roadmap_dir + "/" + b["fields"]["묶음"]) if b["kind"] == "bundle" else None
        states = []
        for br in b["branches"]:
            tip = git.commit("refs/heads/" + br) or git.commit("refs/remotes/origin/" + br)
            states.append({"branch": br, "tip": tip, "merged": merged_by(git, merges, main, br, tip)})
        b["branch_states"] = states
        n_merged = sum(1 for s in states if s["merged"])
        active = next((s for s in states if not s["merged"] and s["tip"]), None)
        b["tip"] = active["tip"] if active else None
        rec_merge = rec.get((bid, "머지"))
        if n_merged == len(states) or rec_merge:
            why = (" · ".join(s["merged"] for s in states) if n_merged == len(states)
                   else "결정 기록의 머지 기록 %s %s" % (rec_merge["date"], rec_merge["quote"]))
            b["stage"], b["reason"], b["tip"] = "머지됨", why, None
            b["specs"] = find_specs(git, main, b, bundle_path, settings["specs_dir"])
        elif active is None:
            if n_merged:
                nxt = next(s["branch"] for s in states if not s["merged"])
                b["stage"], b["reason"] = "일부 머지 %d/%d" % (n_merged, len(states)), "다음 브랜치 없음: %s" % nxt
                b["specs"] = find_specs(git, main, b, bundle_path, settings["specs_dir"])
            elif undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료 · 브랜치 없음"
        else:
            stage, reason, b["specs"], b["plans"] = progress(git, main, active["tip"], b, bundle_path, settings)
            if n_merged:
                b["stage"] = "일부 머지 %d/%d" % (n_merged, len(states))
                b["reason"] = "%s — %s · %s" % (active["branch"], stage, reason)
            else:
                b["stage"], b["reason"] = stage, reason
            if undone:
                b["warnings"].append("의존 미머지 상태에서 진행 중: %s" % " · ".join(undone))
```

반복 맨 앞의 `b.update(…)` 에 `branch_states=[], plans=[]` 를 더한다. 번호 대조 반복의 `tree = main if b["stage"] == "머지됨" else tip` 을 `tree = b["tip"] or main` 으로 바꾼다. 같은 반복에서 `check(…)` 를 부르기 전에 산출물 갈래를 더한다:

```python
            if "산출물" in b["fields"] and section_body(spec_text, "## 번호 대조") is None:
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 산출물에 `## 번호 대조` 절이 없다: %s" % spec)
            elif b["kind"] == "bundle" and bundles.get(bid) is not None:
```

(기존 `if b["kind"] == "bundle" and bundles.get(bid) is not None:` 을 위 `elif` 로 바꾼다.) 경로 예약 위반 반복의 `b["stage"] in ("설계 중", "계획")` 을 `b["tip"]` 만으로 판단하도록 `if b["tip"]:` 로 바꾼다.

`build` 의 보고서 블록에 `"task_status": task_status(b["stage"])`(옛 `TASK_STATUS.get` 자리), `"branches": b["branches"]`, `"branch_states": b.get("branch_states", [])`, `"tip": b.get("tip")`, `"plans": b.get("plans", [])` 를 넣는다. 형식 깨짐 갈래의 블록에도 같은 키를 빈 값으로 넣고, 그 갈래의 `"branch": b["fields"].get("브랜치")` 는 `field_text(b["fields"].get("브랜치", ""))` 로.

`spec_review_bundle.neighbors` 의 `branch = (b.get("branch") …)` · `tree = …` 두 줄을 `tree = main if b["stage"] == "머지됨" else (b.get("tip") or main)` 한 줄로 바꾼다.

- [ ] **Step 5: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_spec_review_bundle.sh 2>&1 | tail -n 3; bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 3; python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: `Fail: 0` 셋 · `OK`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/spec_review_bundle.py plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_spec_review_bundle.sh
git commit -m "feat(spec-distill): 여러 브랜치 · 구현 중 · 구현 끝 · 산출물을 브랜치마다 계획마다 센다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 8: 번호 대조 — `## <n>.` 자리 · 에픽 이름 규칙 · `--acs` · `--impl` 받는 곳 규칙 · 레포 설정 폴더 (AC11 첫째 · 셋째 · AC13 · AC40 · AC14)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py` (`EPIC_TOKEN_RE` 줄 45 · `Repo` 줄 48–80 · `design_sections` 줄 144–161 · `_roadmap_view` · `_block_specs` · `check` 줄 318–336 · `check_plan` · `render_plan` · `check_impl` · `_impl_unchecked` · `IMPL_GROUPS` · `main`)
- Test: `plugins/spec-distill/tests/test_coverage_scope.py` (새로), `plugins/spec-distill/tests/test_repo_defaults.py` (락 더함)

**Interfaces:**
- Consumes: `repo_defaults.SPECS_DIR` · `repo_settings`(Task 1).
- Produces: `epic_refs(cell: str, known=None) -> list[str]`, `parse_acs(value: str) -> list[str]`, `check_plan(spec_text, plan_text, only=None) -> dict`(새 키 `scoped: bool`), `check_impl(spec_text, report_text, only=None, epic_ids=None, receiver_problem=None) -> dict`(새 키 `receiver_rule: str` · `receiver_unknown: list`), `receiver_ids(spec_path, spec_text) -> (set | None, 사유 | None)`, `Repo.specs_for(source, specs_dir=None)`. 명령줄 `--acs <AC 목록>`(`--plan` · `--impl` 과만).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 자리 표기 · 에픽 이름 · AC 고르기 · 받는 곳 규칙(R5 AC11 · AC13 · AC14 · AC40).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_coverage_scope.py
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import check_bundle_coverage as cbc  # noqa: E402
from roadmap_model import FormatError  # noqa: E402

SPEC = ("---\nroadmap: rm/roadmap.md\n---\n\n# 설계\n\n## 2. 이름 붙은 절\n\n1. 첫째\n\n"
        "## Acceptance Criteria\n\n- AC1 가\n- AC2 나\n- AC3 다\n- AC4 라\n\n"
        "## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC3 넘김 | 이유 | R9 |\n| 다른 일 | 이유 | #4 |\n")
PLAN = "# 계획\n\n### Task 1: 하나\n\nAC1 · AC2\n"
REPORT = "AC1: 구현됨 — a\nAC2: 구현됨 — b\nAC3: 미룸 — c\nAC4: 구현됨 — d\n"
ROADMAP = ("---\ntype: roadmap\nsource_brief: b.md\n---\n\n## 에픽\n\n### R5 — 가\n- 의도: i\n- 범위: s\n- 의존: 없음\n"
           "- 브랜치: feature/a\n- 묶음: R5.md\n- 경로 예약: 없음\n\n## 결정 기록\n\n## 재분해 이력\n\n- 없음\n")


class Locations(unittest.TestCase):
    def test_numbered_h2_resolves_section(self):
        sections = cbc.design_sections(SPEC)
        self.assertIn(2, sections)
        self.assertIsNone(cbc.location_problem("§2 · §2-1", sections, ["AC1"], cbc.heading_parts(SPEC)))
        self.assertIsNotNone(cbc.location_problem("§3", sections, ["AC1"], cbc.heading_parts(SPEC)))


class EpicNames(unittest.TestCase):
    def test_capital_digits_optional_lowercase(self):
        self.assertEqual(cbc.epic_refs("P3 결정은 R2a · X9 범위, S36 은 발화", {"P3", "R2a"}), ["P3", "R2a", "X9"])
        self.assertEqual(cbc.epic_refs("AC12 와 RC85 는 에픽이 아니다", {"R5"}), [])
        self.assertEqual(cbc.epic_refs("S36 이 에픽이면", {"S36"}), ["S36"])


class Acs(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(cbc.parse_acs("AC1~AC3 · AC7, AC39 AC7"), ["AC1", "AC2", "AC3", "AC7", "AC39"])
        for bad in ("", "AC3~AC1", "X1", "AC1~"):
            with self.assertRaises(FormatError):
                cbc.parse_acs(bad)

    def test_plan_only_checks_chosen_acs(self):
        self.assertEqual(cbc.check_plan(SPEC, PLAN)["missing"], ["AC3", "AC4"])
        r = cbc.check_plan(SPEC, PLAN, only=["AC1", "AC2"])
        self.assertEqual((r["status"], r["missing"], r["scoped"]), (0, [], True))
        self.assertEqual(cbc.check_plan(SPEC, PLAN, only=["AC9"])["status"], 3)

    def test_impl_only_and_receiver_rule(self):
        r = cbc.check_impl(SPEC, REPORT, only=["AC3"], epic_ids={"R5"})
        self.assertEqual(r["unreported"], [])
        self.assertEqual(r["no_receiver"], ["AC3 넘김"])
        r = cbc.check_impl(SPEC, REPORT, epic_ids={"R9"})
        self.assertEqual(r["no_receiver"], [])
        r = cbc.check_impl(SPEC, REPORT)
        self.assertEqual(r["no_receiver"], [])
        self.assertIn("로드맵 없음", r["receiver_rule"])
        r = cbc.check_impl(SPEC, REPORT, receiver_problem="로드맵을 못 읽었다: rm/roadmap.md")
        self.assertEqual(r["receiver_unknown"], ["로드맵을 못 읽었다: rm/roadmap.md"])


class Cli(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "rm").mkdir()
        (self.tmp / "rm" / "roadmap.md").write_text(ROADMAP, encoding="utf-8")
        (self.tmp / "spec.md").write_text(SPEC, encoding="utf-8")
        (self.tmp / "report.md").write_text(REPORT, encoding="utf-8")
        (self.tmp / "plan.md").write_text(PLAN, encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def run_cbc(self, *args):
        proc = subprocess.run([sys.executable, str(SCRIPTS / "check_bundle_coverage.py")] + list(args),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, proc.stdout.decode("utf-8"), proc.stderr.decode("utf-8")

    def test_impl_reads_roadmap_from_spec(self):
        rc, out, _err = self.run_cbc("--impl", str(self.tmp / "spec.md"), str(self.tmp / "report.md"), "--json")
        r = json.loads(out)
        self.assertEqual(r["no_receiver"], ["AC3 넘김"])
        self.assertEqual(rc, 1)

    def test_plan_with_acs(self):
        rc, out, _err = self.run_cbc("--plan", str(self.tmp / "spec.md"), str(self.tmp / "plan.md"), "--acs", "AC1~AC2")
        self.assertEqual(rc, 0, out)
        self.assertIn("--acs", out)

    def test_acs_needs_plan_or_impl_and_valid_list(self):
        self.assertEqual(self.run_cbc(str(self.tmp / "spec.md"), str(self.tmp / "spec.md"), "--acs", "AC1")[0], 2)
        self.assertEqual(self.run_cbc("--plan", str(self.tmp / "spec.md"), str(self.tmp / "plan.md"),
                                      "--acs", "X1")[0], 2)


class SpecsDir(unittest.TestCase):
    def test_repo_specs_for_reads_given_folder(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "design").mkdir()
            (tmp / "design" / "a.md").write_text("---\nsource_interview: rm/R5.md\n---\n", encoding="utf-8")
            repo = cbc.Repo(str(tmp))
            self.assertEqual([p for p, _t in repo.specs_for("rm/R5.md", "design/")], ["design/a.md"])
            self.assertEqual(repo.specs_for("rm/R5.md"), [])
        finally:
            shutil.rmtree(str(tmp))


if __name__ == "__main__":
    unittest.main()
```

`test_repo_defaults.py` 에 락을 더한다:

```python
SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"


class NoHardcodedFolders(unittest.TestCase):
    """AC14 — 설계문서 · 계획 · SDD 폴더 기본값은 repo_defaults.py 에만 글자로 있다."""
    FILES = ("roadmap_status.py", "check_bundle_coverage.py", "conductor_state.py", "control_plane.py",
             "spec_review_bundle.py")
    LITERALS = (rd.SPECS_DIR.rstrip("/"), rd.PLANS_DIR.rstrip("/"), rd.SDD_WORKSPACE.rstrip("/"))

    def test_default_folders_only_in_repo_defaults(self):
        for name in self.FILES:
            text = (SCRIPTS / name).read_text(encoding="utf-8")
            for lit in self.LITERALS:
                self.assertNotIn(lit, text, "%s 에 %s 가 박혀 있다 — repo_defaults 를 써라" % (name, lit))

    def test_lock_sees_a_planted_literal(self):   # 양성 대조 — 이 락이 글자를 실제로 본다
        planted = "x = %r\n" % rd.SPECS_DIR
        self.assertTrue(any(lit in planted for lit in self.LITERALS))
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_coverage_scope.py plugins/spec-distill/tests/test_repo_defaults.py`
Expected: ERROR/FAIL — `epic_refs` · `parse_acs` 없음, `check_bundle_coverage.py 에 docs/superpowers/specs 가 박혀 있다`.

- [ ] **Step 3: 고친다**

머리 docstring 의 명령줄 두 줄을 `--plan <설계문서> <계획> [--acs <AC 목록>] [--json]` · `--impl <설계문서> <보고 파일> [--acs <AC 목록>] [--json]` 으로, 그 아래에 「`--acs` 는 그 AC 만 대조한다(`AC1~AC14 · AC39` 꼴). `--impl` 은 설계문서 frontmatter `roadmap:` 의 로드맵에서 받는 곳 규칙(로드맵의 에픽 · `#<n>`)을 쓴다.」 를 더한다. import 에 `from repo_defaults import SPECS_DIR, repo_settings` 를 더한다.

```python
EPIC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])([A-Z]\d+[a-z]?)(?![A-Za-z0-9])")
ACS_PART_RE = re.compile(r"AC(\d+)(?:~AC(\d+))?")
ACS_SEP = (",", "·")


def epic_refs(cell: str, known=None) -> list:
    """칸이 가리키는 에픽 이름(대문자 + 숫자 + 소문자 선택). brief 번호 꼴(S36 · C7 · K2 …)은 로드맵에 그 이름의
    에픽이 있을 때만 에픽으로 읽는다."""
    out = []
    for e in EPIC_TOKEN_RE.findall(cell):
        if (known is not None and e in known) or not TOKEN_RE.fullmatch(e):
            if e not in out:
                out.append(e)
    return out


def parse_acs(value: str) -> list:
    """`AC1~AC14 · AC39, AC40` → AC 목록(나온 순서, 중복 제거)."""
    for sep in ACS_SEP:
        value = value.replace(sep, " ")
    out = []
    for piece in value.split():
        m = ACS_PART_RE.fullmatch(piece)
        if not m:
            raise FormatError("--acs 조각이 AC<n> 또는 AC<a>~AC<b> 가 아니다: %r" % piece)
        a, b = int(m.group(1)), int(m.group(2) or m.group(1))
        if b < a:
            raise FormatError("--acs 범위가 거꾸로다: %r" % piece)
        out += [ac for ac in ("AC%d" % n for n in range(a, b + 1)) if ac not in out]
    if not out:
        raise FormatError("--acs 가 비었다")
    return out
```

`Repo` 를 폴더별 메모로 바꾼다:

```python
class Repo:
    """레포 루트 기준 읽기 — 로드맵 · 다른 묶음 · 작업 트리 설계문서. 읽기만 한다."""

    def __init__(self, root: str):
        self.root = root
        self._specs = {}

    def read(self, rel: str):
        try:
            with open(os.path.join(self.root, rel), encoding="utf-8") as fh:
                return fh.read()
        except (OSError, UnicodeDecodeError):
            return None

    def exists(self, rel: str) -> bool:
        return os.path.exists(os.path.join(self.root, rel))

    def specs_for(self, source: str, specs_dir=None) -> list:
        """설계문서 폴더(로드맵 레포 설정, 없으면 기본값)의 `*.md` 중 frontmatter `source_interview` 가 source 인 (경로, 글)."""
        d = (specs_dir or SPECS_DIR).rstrip("/")
        if d not in self._specs:
            found = []
            try:
                names = sorted(os.listdir(os.path.join(self.root, *d.split("/"))))
            except OSError:
                names = []
            for name in names:
                if not name.endswith(".md"):
                    continue
                rel = d + "/" + name
                text = self.read(rel)
                if text is not None:
                    found.append((rel, unquote(frontmatter(text).get("source_interview", "")), text))
            self._specs[d] = found
        return [(rel, text) for rel, src, text in self._specs[d] if src == source]
```

`design_sections` 의 머리 줄 갈래를 `## <n>.` 도 받게 바꾼다:

```python
def _lead_digits(text: str) -> str:
    digits = ""
    for ch in text:
        if ch not in "0123456789":
            break
        digits += ch
    return digits


def design_sections(spec_text: str) -> dict:
    """펜스 밖 `### §<n>` 또는 `## <n>.` 절마다 본문 줄 — {n: [줄]}. 다음 `## ` · `### ` 제목에서 끝난다."""
    out, cur = {}, None
    for line in _outside_fences(spec_text):
        if line.startswith("## ") or line.startswith("### "):
            cur = None
            if line.startswith("### §"):
                digits = _lead_digits(line[len("### §"):])
            elif line.startswith("## "):
                head = line[3:]
                digits = _lead_digits(head)
                digits = digits if head[len(digits):len(digits) + 1] == "." else ""
            else:
                digits = ""
            if digits:
                cur = out.setdefault(int(digits), [])
            continue
        if cur is not None:
            cur.append(line)
    return out
```

`_roadmap_view` 가 레포 설정 폴더를 함께 낸다 — 반환 dict 에 `"specs_dir": repo_settings(meta)["specs_dir"] or SPECS_DIR` 를 더하고, `_block_specs` 의 `repo.specs_for(rdir + "/" + …)` 를 `repo.specs_for(rdir + "/" + block["fields"]["묶음"], view["specs_dir"])` 로.

`check` 의 기각 갈래(`epics = EPIC_TOKEN_RE.findall(cell)` 부터 `absent = …` 까지)를 바꾼다:

```python
        known = {b["id"] for b in view["blocks"]} if view is not None else None
        epics = epic_refs(cell, known)
        rejected_s = [t for t in ids if _is_s(t) and t in seen]
        if view is None:
            targets = list(ids) if epics else rejected_s
            unknown += ["%s — %s" % (t, note) for t in targets]
            continue
        absent = [e for e in epics if e not in known]
```

`check_plan` · `render_plan` · `_plan_unchecked`:

```python
def _plan_unchecked(reason: str) -> dict:
    return {"status": 3, "missing": [], "ac_count": None, "scoped": False, "reason": reason}


def _only(acs: list, only):
    """(고른 AC, 사유). 설계문서에 없는 AC 를 고르면 사유."""
    if only is None:
        return acs, None
    absent = [a for a in only if a not in acs]
    if absent:
        return None, "설계문서에 없는 AC 를 --acs 에 적었다: %s" % " · ".join(absent)
    return [a for a in acs if a in only], None


def check_plan(spec_text: str, plan_text: str, only=None) -> dict:
    try:
        acs = _acs_or_error(spec_text)
    except FormatError as exc:
        return _plan_unchecked(str(exc))
    acs, why = _only(acs, only)
    if why:
        return _plan_unchecked(why)
    have = {"AC" + m.group(1) for m in AC_TOKEN_RE.finditer(plan_task_text(plan_text))}
    missing = [a for a in acs if a not in have]
    return {"status": 1 if missing else 0, "missing": missing, "ac_count": len(acs),
            "scoped": only is not None, "reason": None}


def render_plan(r: dict) -> str:
    if r["status"] == 3:
        return "계획 대조 검사 불가 — %s" % r["reason"]
    scope = " · --acs 로 고른 것" if r.get("scoped") else ""
    if r["missing"]:
        return "계획 대조: 계획에 없는 AC %d개 — %s (AC %d개%s)" % (
            len(r["missing"]), " · ".join(r["missing"]), r["ac_count"], scope)
    return "계획 대조: 계획에 없는 AC 없음 (AC %d개%s)" % (r["ac_count"], scope)
```

`check_impl` · `_impl_unchecked` · `IMPL_GROUPS` · `receiver_ids`:

```python
def _impl_unchecked(reason: str) -> dict:
    return {"status": 3, "unreported": [], "unlisted": [], "no_receiver": [], "dropped": [],
            "receiver_unknown": [], "unknown_acs": [], "counts": None, "ac_count": None,
            "receiver_rule": None, "reason": reason}


def check_impl(spec_text: str, report_text: str, only=None, epic_ids=None, receiver_problem=None) -> dict:
    try:
        all_acs = _acs_or_error(spec_text)
        report = parse_report(report_text)
        if not report:
            raise FormatError("보고에 AC 판정 줄이 없다")
        deferred = deferred_rows(spec_text)
    except FormatError as exc:
        return _impl_unchecked(str(exc))
    acs, why = _only(all_acs, only)
    if why:
        return _impl_unchecked(why)
    listed = {"AC" + m.group(1) for item, _why, _recv in deferred for m in AC_TOKEN_RE.finditer(item)}
    judged = [a for a in acs if a in report]
    if epic_ids is not None:
        no_receiver = [item for item, _why, recv in deferred if not receiver_ok(recv, epic_ids)]
        rule = "로드맵의 에픽 · #<n>"
    else:
        no_receiver = [item for item, _why, recv in deferred if recv == "없음"]
        rule = "로드맵 없음 — 「없음」만 받는 곳 없음으로 센다"
    return {
        "status": 0, "reason": None, "ac_count": len(acs), "receiver_rule": rule,
        "unreported": [a for a in acs if a not in report],
        "unlisted": ["%s(%s)" % (a, report[a][0]) for a in judged
                     if report[a][0] != "구현됨" and a not in listed],
        "no_receiver": no_receiver,
        "receiver_unknown": [receiver_problem] if receiver_problem else [],
        "dropped": ["%s: %s" % (a, report[a][1]) for a in judged if report[a][0] == "빠짐"],
        "unknown_acs": sorted((a for a in report if a not in all_acs), key=lambda a: int(a[2:])),
        "counts": {v: sum(1 for a in judged if report[a][0] == v) for v in VERDICTS},
    }


IMPL_GROUPS = (("보고에 없는 AC", "unreported"), ("미룸 표에 없는 미룸/빠짐", "unlisted"),
               ("받는 곳 없는 미룸", "no_receiver"), ("받는 곳 검사 불가", "receiver_unknown"),
               ("빠짐", "dropped"))


def receiver_ids(spec_path: str, spec_text: str):
    """(로드맵 에픽 번호 집합, 사유). 설계문서에 `roadmap:` 이 없으면 (None, None) — 로드맵 없는 설계다."""
    rel = unquote(frontmatter(spec_text).get("roadmap", ""))
    if not rel:
        return None, None
    repo = find_repo(spec_path, rel)
    if repo is None:
        return None, "로드맵을 찾지 못했다: %s" % rel
    text = repo.read(rel)
    if text is None:
        return None, "로드맵을 못 읽었다: %s" % rel
    _meta, blocks, _records, _risk, errors = parse_roadmap(text)
    if errors:
        return None, "로드맵 형식이 깨졌다: %s" % errors[0]
    return {b["id"] for b in blocks}, None
```

`render_impl` 의 경고 없음 줄 끝에 ` · 받는 곳 규칙: %s` 로 `r["receiver_rule"]` 를 붙인다.

`main` 에 `ap.add_argument("--acs", help="--plan · --impl 에서 그 AC 만 대조한다(예: AC1~AC14 · AC39)")` 를 더하고, `args = ap.parse_args(argv)` 뒤를 아래로 바꾼다:

```python
    only = None
    if args.acs is not None:
        if not (args.plan or args.impl):
            ap.error("--acs 는 --plan · --impl 과만 쓴다")
        try:
            only = parse_acs(args.acs)
        except FormatError as exc:
            ap.error(str(exc))
    if args.plan:
        result = _two_files(args.first, args.second, lambda s, p: check_plan(s, p, only), _plan_unchecked)
        text = render_plan(result)
    elif args.impl:
        def impl(spec_text, report_text):
            ids, problem = receiver_ids(args.first, spec_text)
            return check_impl(spec_text, report_text, only, ids, problem)
        result = _impl_status(_two_files(args.first, args.second, impl, _impl_unchecked))
        text = render_impl(result)
    else:
        result = coverage(args.first, args.second)
        text = render(result)
```

- [ ] **Step 4: 통과를 확인하고 락의 이빨을 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_coverage_scope.py plugins/spec-distill/tests/test_repo_defaults.py && bash plugins/spec-distill/tests/test_bundle_coverage.sh 2>&1 | tail -n 3 && bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 3`
Expected: OK · `Fail: 0` 둘.

변이: 먼저 커밋한 뒤(Step 5), `roadmap_status.py` 맨 끝에 `_X = "docs/superpowers/specs/"` 한 줄을 더해 `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py` 가 FAIL 인지 보고 `git checkout HEAD -- plugins/spec-distill/scripts/roadmap_status.py` 로 되돌린 뒤 `git diff HEAD --stat` 이 비었는지 확인한다. 같은 방법으로 `epic_refs` 의 `not TOKEN_RE.fullmatch(e)` 를 `True` 로 바꿔 `EpicNames` 가 FAIL 인지 본다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/check_bundle_coverage.py plugins/spec-distill/tests/test_coverage_scope.py plugins/spec-distill/tests/test_repo_defaults.py
git commit -m "feat(spec-distill): 번호 대조가 AC 를 골라 대조하고 구현 대조가 로드맵의 받는 곳 규칙을 쓴다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 9: 상태 계산 보고서에 에픽 보기 재료 — 판정 보관본 · 넘김 · 동시 가능 · 선택 칸 (AC8 보관본 · AC9 재료 · AC43 넘김 계산 사용)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`compute` 의 번호 대조 반복 · `build` 의 보고서 · 새 함수 `parallel_with`)
- Test: `plugins/spec-distill/tests/test_roadmap_status.sh` (장면 더함), `plugins/spec-distill/tests/test_control_plane.py` (`parallel_with` 순수 함수)

**Interfaces:**
- Consumes: `conductor_state.handoff_rows` · `rulings_archived` · `section_lines` · `RECORD_HEADING`(Task 3), `roadmap_model.EXTRA_FIELDS` · `field_text`(Task 2).
- Produces: 보고서 블록 새 키 `bundle`(묶음 경로 | None) · `extras`(dict) · `parallel`(`[{"id", "overlap": [경로]}]`) · `rulings_archived`(list | None), 보고서 새 키 `handoffs`(`conductor_state.handoff_rows` 의 줄들). `parallel_with(blocks, overlaps) -> dict`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_roadmap_status.sh` 의 Task 7 장면 뒤에 더한다:

```bash
# ── R5 AC8 · AC9 · AC43 — 판정 보관본 · 넘김 · 동시 가능 · 선택 칸 ──────────────────────────
g checkout -q feature/k2
printf '\n## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| 넘길 일 | 이유 | K3 |\n| 이슈 일 | 이유 | #5 |\n\n## 판정\n\n- Task 1: Ruling: 가 — 왜 — 비용\n' >> "$W/docs/superpowers/specs/k2-design.md"
g add -- docs && g commit -qm "k2 미룸 · 판정"
g checkout -q main
(cd "$W" && python3 "$RS" --json docs/rm3/roadmap.md > "$T/rm3c.json")
assert_eq "$(js "$T/rm3c.json" "[(h['giver'], h['receiver'], h['state']) for h in r['handoffs']]")" "[('K2', 'K3', '열림'), ('K2', '#5', '이슈')]" "AC43: 넘김 줄을 conductor_state 로 계산한다"
assert_eq "$(js "$T/rm3c.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K2')")" "['- Task 1: Ruling: 가 — 왜 — 비용']" "AC8: 설계문서 ## 판정 보관본"
assert_eq "$(js "$T/rm3c.json" "next(b['rulings_archived'] for b in r['blocks'] if b['id']=='K3')")" "None" "판정 절 없는 설계문서는 None(빈 목록과 다르다)"
assert_eq "$(js "$T/rm3c.json" "next(b['extras'] for b in r['blocks'] if b['id']=='O1')")" "{'흐름': '조사 「조사로 간다」', '산출물': 'docs/research/o1.md'}" "선택 칸을 보고서에 싣는다"
assert_eq "$(js "$T/rm3c.json" "next(b['bundle'] for b in r['blocks'] if b['id']=='K2')")" "docs/rm3/K2.md" "묶음 경로"
assert_contains "$(js "$T/rm3c.json" "[p['id'] for p in next(b['parallel'] for b in r['blocks'] if b['id']=='K2')]")" "'K3'" "K2 와 K3 은 동시에 갈 수 있다"
assert_not_contains "$(js "$T/rm3c.json" "[p['id'] for p in next(b['parallel'] for b in r['blocks'] if b['id']=='K2')]")" "'M2'" "머지된 에픽은 동시 가능 목록에 없다"
```

`test_control_plane.py` 의 테스트 클래스들 뒤에 더한다:

```python
class Parallel(unittest.TestCase):
    def test_parallel_with_skips_dependents_and_done(self):
        blocks = [{"id": "A", "stage": "설계 중", "deps": []}, {"id": "B", "stage": "준비", "deps": ["A"]},
                  {"id": "C", "stage": "준비", "deps": []}, {"id": "D", "stage": "머지됨", "deps": []}]
        got = roadmap_status.parallel_with(blocks, [{"blocks": ["A", "C"], "paths": ["src/x"]}])
        self.assertEqual(got["A"], [{"id": "C", "overlap": ["src/x"]}])
        self.assertEqual([p["id"] for p in got["B"]], ["C"])
        self.assertEqual(got["D"], [])
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py; bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | grep '✗'`
Expected: `AttributeError: … parallel_with` 와 새 단언의 `✗`(`KeyError: 'handoffs'`).

- [ ] **Step 3: 고친다**

import 에 `from conductor_state import handoff_rows, rulings_archived, section_lines, RECORD_HEADING, impl_done` (Task 7 의 `impl_done` 과 한 줄로)와 `EXTRA_FIELDS` 를 더한다. `compute` 의 블록 초기화 `b.update(…)` 에 `docs=[], deferred=[]` 를 더한다. 번호 대조 반복에서 `spec_text` 를 읽은 직후(읽지 못한 경우의 `continue` 다음)에 `b["docs"].append(spec_text)` 를, `rows = deferred_rows(spec_text)` 가 성공한 직후에 `b["deferred"].append((spec, rows))` 를 더한다.

`overlaps` 아래에 더한다:

```python
def parallel_with(blocks: list, overlap_list: list) -> dict:
    """블록마다 함께 갈 수 있는 끝나지 않은 블록 — 의존 관계가 어느 쪽으로도 없는 것. 경로 예약 겹침은 정보로 함께."""
    reach = _reachable(blocks)
    over = {}
    for o in overlap_list:
        a, b = o["blocks"]
        over[(a, b)] = over[(b, a)] = o["paths"]
    out = {}
    for a in blocks:
        if a["stage"] in DONE:
            out[a["id"]] = []
            continue
        out[a["id"]] = [{"id": b["id"], "overlap": over.get((a["id"], b["id"]), [])} for b in blocks
                        if b["id"] != a["id"] and b["stage"] not in DONE
                        and b["id"] not in reach[a["id"]] and a["id"] not in reach[b["id"]]]
    return out


def _archived(texts: list):
    got = [rulings_archived(t) for t in texts]
    return None if all(g is None for g in got) else [line for g in got if g for line in g]
```

`build` 에서 `report["overlaps"] = overlaps(blocks)` 다음에 더한다:

```python
    stages = dict((b["id"], b["stage"]) for b in blocks)
    records = dict((b["id"], "\n".join("\n".join(section_lines(t, RECORD_HEADING) or []) for t in b.get("docs", [])))
                   for b in blocks)
    givers = [(b["id"], spec, rows) for b in blocks for spec, rows in b.get("deferred", [])]
    report["handoffs"] = handoff_rows(givers, stages, records)
    parallel = parallel_with(blocks, report["overlaps"])
```

보고서 블록 dict 에 `"bundle": (roadmap_dir + "/" + b["fields"]["묶음"]) if b["kind"] == "bundle" else None`, `"extras": dict((k, field_text(b["fields"][k])) for k in EXTRA_FIELDS if k in b["fields"])`, `"parallel": parallel.get(b["id"], [])`, `"rulings_archived": _archived(b.get("docs", []))` 를 더한다. 보고서 초기값 · 내부 오류 보고서에 `"handoffs": []`, 형식 깨짐 갈래 블록에 `"bundle": None, "extras": {}, "parallel": [], "rulings_archived": None` 를 더한다.

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py && bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -n 3 && bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 3`
Expected: OK · `Fail: 0` 둘.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_control_plane.py
git commit -m "feat(spec-distill): 상태 계산이 판정 보관본 · 넘김 · 동시 가능 에픽 · 선택 칸을 낸다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 10: 화면 — PR 단계 · 판정 줄 · 겹침 줄 · 기계 상태 오류 (AC8 · AC11 넷째)

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py` (import · 상수 · `bucket_counts` · `show_text` · `gather` · `cmd_statusline` · `CODE_STAMP_FILES`, 새 함수 `machine_for` · `gh_lookup_for` · `overlay` · `pr_text` · `active_branch`)
- Test: `plugins/spec-distill/tests/test_control_plane.py` (`class Overlay`)

**Interfaces:**
- Consumes: `conductor_state.machine_path` · `load` · `MachineError` · `ledger_rulings`(Task 3), `state_path.state_root_for_common`(Task 3), 보고서 블록의 `branch_states` · `rulings_archived`(Task 7 · 9).
- Produces: `overlay(items, machine_lookup, gh_lookup, use_gh, read=read_capped) -> None`(보고서를 고친다 — 블록 `pr` · `rulings` · `rulings_source`, 보고서 `machine` · `machine_error`), `gh_lookup_for(repo, deadline) -> callable | None`, `machine_for(repo, roadmap_rel) -> (dict | None, 사유 | None)`, `pr_text(pr: dict) -> str`, `gather(cwd, arg, deadline, ctx, use_gh=True)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_control_plane.py` 에 더한다(파일 머리 import 에 `import inspect`, `import os`, `import shutil`, `import tempfile`, `import conductor_state as cs` 를 더한다):

```python
def impl_done_block(bid="R5", branch="feature/a", **extra):
    return blk(bid, "구현 끝", "in_progress", branch_states=[{"branch": branch, "tip": "abcdef12", "merged": None}],
               **extra)


class Overlay(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.ledger = self.tmp / "progress.md"
        self.ledger.write_text("# SDD ledger — plan: p\nTask 1: Ruling: 가 — 왜 — 비용\n", encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def machine(self, pr=None, ledger_for=None):
        data = cs.empty()
        if pr:
            data["PR"].append({"브랜치": "feature/a", "번호": "#12", "상태": pr, "확인한 때": "2026-10-17 10:00"})
        if ledger_for:
            data["실행 원장"].append({"에픽": ledger_for, "계획": "p.md", "원장": str(self.ledger), "읽은 줄": "0"})
        return lambda rel: (data, None)

    def test_open_pr_in_machine_turns_impl_done_into_pr(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(pr="열림"), None, True)
        self.assertEqual(r["blocks"][0]["stage"], "PR")
        self.assertEqual(r["blocks"][0]["task_status"], "in_progress")

    def test_unknown_pr_keeps_stage_and_says_so(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(), None, True)
        self.assertEqual(r["blocks"][0]["stage"], "구현 끝")
        self.assertIn("    PR: 알 수 없음 — 기계 상태에 없고 gh 가 없다", self.show_lines(r))

    def test_statusline_mode_never_calls_gh(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], self.machine(), lambda br: self.fail("gh 를 불렀다"), False)
        self.assertEqual(r["blocks"][0]["pr"]["state"], "알 수 없음")
        self.assertIn("use_gh=False", inspect.getsource(cp.cmd_statusline))

    def test_rulings_ledger_then_archive_then_uncountable(self):
        r = report([impl_done_block("R5"), impl_done_block("R6", rulings_archived=["- 보관 판정"]),
                    impl_done_block("R7"), blk("R0", "머지됨", "completed")])
        cp.overlay([(RM, r)], self.machine(ledger_for="R5"), None, False)
        got = dict((b["id"], b.get("rulings", "없음 키")) for b in r["blocks"])
        self.assertEqual(got, {"R5": ["Task 1: Ruling: 가 — 왜 — 비용"], "R6": ["- 보관 판정"], "R7": None,
                               "R0": "없음 키"})
        self.assertIn("    R7: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다", self.show_lines(r))

    def test_broken_machine_is_shown_not_emptied(self):
        r = report([impl_done_block()])
        cp.overlay([(RM, r)], lambda rel: (None, "3줄: 모르는 절 'x'"), None, False)
        self.assertIsNone(r["machine"])
        self.assertIn("기계 상태를 읽지 못했다 — 3줄: 모르는 절 'x'", self.show_lines(r))

    def test_overlap_lines_show_content(self):
        r = report(BASE, overlaps=[{"blocks": ["R1", "R2"], "paths": ["src/x.py", "docs/y/"]}])
        lines = self.show_lines(r)
        self.assertIn("경로 예약 겹침(정보): 1개", lines)
        self.assertIn("    R1 ↔ R2: src/x.py · docs/y/", lines)

    def test_partial_merge_counts_as_implementation(self):
        counts, other = cp.bucket_counts([(RM, report([blk("R5", "일부 머지 1/3", "in_progress")]))])
        self.assertEqual((counts["구현"], other), (1, 0))

    def test_gh_lookup_with_fake_gh(self):
        bindir = self.tmp / "bin"
        bindir.mkdir()
        gh = bindir / "gh"
        old_path = os.environ.get("PATH", "")
        os.environ["PATH"] = str(bindir) + os.pathsep + old_path
        try:
            for body, want in (("echo '[{\"number\": 7, \"state\": \"OPEN\"}]'", {"number": "#7", "state": "열림"}),
                               ("echo '[]'", {"number": None, "state": "없음"}),
                               ("exit 1", {"number": None, "state": "알 수 없음"})):
                gh.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
                gh.chmod(0o755)
                lookup = cp.gh_lookup_for(cp.Repo(str(self.tmp), cp.Deadline(5)), cp.Deadline(5))
                got = lookup("feature/a")
                self.assertEqual({"number": got["number"], "state": got["state"]}, want, body)
        finally:
            os.environ["PATH"] = old_path

    def show_lines(self, r):
        return cp.show_text([(RM, r)], NO_IV, [], lambda rep: "첫 줄", None).split("\n")
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: ERROR — `AttributeError: module 'control_plane' has no attribute 'overlay'`

- [ ] **Step 3: 화면을 고친다**

import 에 더한다:

```python
import shutil  # noqa: E402 — 표준 라이브러리(위 import 묶음에 넣는다)
import conductor_state as cs  # noqa: E402
from state_path import state_root_for_common  # noqa: E402
```

상수:

```python
IMPL_STAGES = ("구현 중", "구현 끝", "PR")
GH_STATES = {"OPEN": "열림", "MERGED": "머지됨", "CLOSED": "닫힘"}
LEDGER_MAX_BYTES = 1 << 20
```

`CODE_STAMP_FILES` 에 `"conductor_state.py", "repo_defaults.py"` 를 더한다.

`bucket_counts` 의 블록 반복 맨 앞에 더한다:

```python
            if stage and stage.startswith("일부 머지"):
                counts["구현"] += 1
                continue
```

새 함수들(`gather` 앞):

```python
def _pr_unknown(why: str) -> dict:
    return {"number": None, "state": "알 수 없음", "source": why}


def pr_text(pr: dict) -> str:
    if pr["state"] == "알 수 없음":
        return "알 수 없음 — %s" % pr["source"]
    if pr["number"] is None:
        return "%s(%s)" % (pr["state"], pr["source"])
    return "%s %s(%s)" % (pr["number"], pr["state"], pr["source"])


def active_branch(b: dict):
    return next((s["branch"] for s in b.get("branch_states") or [] if not s.get("merged") and s.get("tip")), None)


def machine_for(repo, roadmap_rel: str):
    """(기계 상태, 사유). 파일이 없으면 빈 것. 깨졌으면 (None, 사유) — 빈 것으로 읽지 않는다."""
    common = repo.line("rev-parse", "--git-common-dir")
    if not common:
        return None, "git 공용 디렉토리를 찾지 못했다"
    try:
        path = cs.machine_path(state_root_for_common(Path(repo.cwd, common).resolve()), roadmap_rel)
        return cs.load(path, roadmap_rel), None
    except cs.MachineError as exc:
        return None, str(exc)


def gh_lookup_for(repo, deadline):
    """브랜치 → PR 사실을 `gh pr list` 로. gh 가 없으면 None."""
    exe = shutil.which("gh")
    if not exe:
        return None
    env = dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1", GH_NO_UPDATE_NOTIFIER="1")

    def lookup(branch: str) -> dict:
        try:
            rc, out = run_bounded([exe, "pr", "list", "--state", "all", "--head", branch,
                                   "--json", "number,state", "--limit", "1"], repo.cwd, env, deadline, "gh pr list")
        except TimedOut:
            return _pr_unknown("gh 시간 초과")
        if rc != 0:
            return _pr_unknown("gh 실패(rc %d)" % rc)
        try:
            data = json.loads(out.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            return _pr_unknown("gh 출력을 읽지 못했다")
        if not isinstance(data, list):
            return _pr_unknown("gh 출력 모양이 다르다")
        if not data:
            return {"number": None, "state": "없음", "source": "gh"}
        state, number = GH_STATES.get(data[0].get("state")), data[0].get("number")
        if state is None or not isinstance(number, int):
            return _pr_unknown("gh 출력 모양이 다르다")
        return {"number": "#%d" % number, "state": state, "source": "gh"}
    return lookup


def overlay(items, machine_lookup, gh_lookup, use_gh: bool, read=read_capped) -> None:
    """기계 상태 · 실행 원장 · gh 를 보고서에 얹는다 — 캐시 밖에서 매번 읽는다(캐시 열쇠에 넣지 않는다)."""
    for path, report in items:
        machine, why = machine_lookup(path)
        report["machine"], report["machine_error"] = machine, why
        ledgers, prs = {}, {}
        for row in (machine or {}).get("실행 원장", []):
            ledgers.setdefault(row["에픽"], []).append(row["원장"])
        for row in (machine or {}).get("PR", []):
            prs[row["브랜치"]] = row
        for b in report.get("blocks") or []:
            stage = b.get("stage") or ""
            partial = stage.startswith("일부 머지")
            br = active_branch(b)
            if br and (stage == "구현 끝" or (partial and "구현 끝" in (b.get("reason") or ""))):
                if br in prs:
                    row = prs[br]
                    b["pr"] = {"number": row["번호"], "state": row["상태"], "source": "기계 상태"}
                elif not use_gh:
                    b["pr"] = _pr_unknown("기계 상태에 없다(상태줄은 gh 를 부르지 않는다)")
                elif gh_lookup is None:
                    b["pr"] = _pr_unknown("기계 상태에 없고 gh 가 없다")
                else:
                    b["pr"] = gh_lookup(br)
                if stage == "구현 끝" and b["pr"]["state"] == "열림":
                    b["stage"], b["reason"] = "PR", "%s 열림(%s)" % (b["pr"]["number"], b["pr"]["source"])
            if stage in IMPL_STAGES or partial or stage == "머지됨":
                rulings = None
                for ledger in ledgers.get(b.get("id"), []):
                    try:
                        rulings = (rulings or []) + cs.ledger_rulings(read(ledger, LEDGER_MAX_BYTES))
                        b["rulings_source"] = "실행 원장"
                    except (OSError, ValueError):
                        continue
                if rulings is None and b.get("rulings_archived") is not None:
                    rulings, b["rulings_source"] = b["rulings_archived"], "설계문서 ## 판정"
                if rulings is not None or stage != "머지됨":
                    b["rulings"] = rulings
```

`gather` 서명을 `def gather(cwd: str, arg, deadline: Deadline, ctx: dict, use_gh: bool = True):` 로 바꾸고, `for _p, r in items: r["fetched_at"] = fetched` 반복 바로 뒤(캐시를 쓴 뒤라 기계 상태가 캐시에 들어가지 않는다)에 더한다:

```python
    overlay(items, lambda rel: machine_for(repo, rel), gh_lookup_for(repo, deadline) if use_gh else None, use_gh)
```

`cmd_statusline` 의 `gather(stdin_dir() or os.getcwd(), None, deadline, ctx)` 를 `gather(stdin_dir() or os.getcwd(), None, deadline, ctx, use_gh=False)` 로.

`show_text`:
- `lines.append(clean("로드맵: %s" % path))` 뒤에 `if report.get("machine_error"): lines.append(clean("기계 상태를 읽지 못했다 — %s" % report["machine_error"]))`.
- 블록 경고 줄 다음에 `if b.get("pr"): lines.append(clean("    PR: %s" % pr_text(b["pr"])))`.
- `TOP_WARNINGS` 반복 뒤에 더한다:

```python
        ov = report.get("overlaps") or []
        if ov:
            lines.append("경로 예약 겹침(정보): %d개" % len(ov))
            lines += [clean("    %s ↔ %s: %s" % (o["blocks"][0], o["blocks"][1], " · ".join(o["paths"]))) for o in ov]
```

- 판정 줄 갈래를 바꾼다(`rulings` 가 None 이면 「셀 수 없음」, 모두 빈 목록이면 지금처럼 「없음」):

```python
        ruled = [b for b in blocks if "rulings" in b]
        if ruled:
            lines.append("판정 줄:")
            rows = []
            for b in ruled:
                if b["rulings"] is None:
                    rows.append(clean("    %s: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다" % b.get("id")))
                else:
                    rows += [clean("    %s: %s" % (b.get("id"), r)) for r in b["rulings"]]
            lines += rows or ["    없음"]
```

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py && bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -n 3`
Expected: OK · `Fail: 0`. `test_control_plane.sh` 의 캐시 단언(키 요소 · 다시 계산 횟수)이 그대로인지 본다 — 기계 상태는 캐시 열쇠 밖이다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests/test_control_plane.py
git commit -m "feat(spec-distill): 화면이 PR 단계 · 판정 줄 · 겹침 내용 · 기계 상태 오류를 캐시 밖에서 얹는다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 11: 에픽 하나로 내려가는 보기 (AC9 · §6 의 크기 · 순서 이유 보이기)

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py` (`main` · `cmd_show`, 새 함수 `epic_view`)
- Modify: `plugins/spec-distill/skills/roadmap-status/SKILL.md` (frontmatter `description` · `argument-hint`, `### 2. 지도 내기`)
- Modify: `plugins/spec-distill/scripts/spec_review_bundle.py` (`_line`)
- Test: `plugins/spec-distill/tests/test_control_plane.py` (`class EpicView`), `plugins/spec-distill/tests/test_spec_review_bundle.sh` (크기 줄)

**Interfaces:**
- Consumes: 보고서 블록 `bundle` · `specs` · `plans` · `branch_states` · `deps` · `parallel` · `extras` · `pr` · `rulings` · `warnings` · `notes`, 보고서 `handoffs` · `machine` · `machine_error`(Task 7 · 9 · 10).
- Produces: `epic_view(path, report, epic) -> (list[str], rc)`, 명령줄 `control_plane.py show <로드맵> <에픽>`(에픽 꼴 `[A-Z][0-9]+[a-z]?`, `--tasks` 와 함께 못 씀 — rc 2), `/spec-distill:roadmap-status <로드맵> <에픽>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
class EpicView(unittest.TestCase):
    def rep(self):
        data = cs.empty()
        data["자원"].append({"종류": "worktree", "경로": "/w/r5", "에픽": "R5", "용도": "구현", "만든 때": "2026-10-17"})
        data["기다리는 질문"].append({"에픽": "R5", "기대는 일": "구현", "질문": "새 결정 하나"})
        r5 = blk("R5", "일부 머지 1/3", "in_progress", deps=["R1"], bundle="docs/rm/R5.md",
                 specs=["docs/s.md"], plans=["docs/p2.md"],
                 branch_states=[{"branch": "feature/a", "tip": "aaaaaaaa1", "merged": "기본 브랜치의 머지 커밋 1"},
                                {"branch": "feature/b", "tip": "bbbbbbbb2", "merged": None},
                                {"branch": "feature/c", "tip": None, "merged": None}],
                 parallel=[{"id": "R10", "overlap": ["src/x"]}], extras={"크기": "큼", "순서 이유": "R2a 뒤"},
                 rulings=None)
        r = report([blk("R1", "머지됨", "completed"), r5],
                   handoffs=[{"item": "넘길 일", "giver": "R2", "receiver": "R5", "spec": "s", "state": "열림",
                              "basis": "R5 설계 중"},
                             {"item": "끝난 일", "giver": "R5", "receiver": "R8", "spec": "s", "state": "확인됨",
                              "basis": "b"}])
        r["machine"], r["machine_error"] = data, None
        return r

    def test_drill_down_lines(self):
        lines, rc = cp.epic_view(RM, self.rep(), "R5")
        text = "\n".join(lines)
        self.assertEqual(rc, 0)
        for want in ("R5 에픽 R5 — 일부 머지 1/3", "  묶음: docs/rm/R5.md", "  설계문서: docs/s.md", "  계획: docs/p2.md",
                     "  브랜치: feature/a(머지됨) · feature/b(진행 — bbbbbbbb) · feature/c(아직 없음)",
                     "  의존: R1(머지됨)", "  동시에 갈 수 있는 에픽: R10(경로 예약 겹침: src/x)",
                     "  크기: 큼", "  순서 이유: R2a 뒤", "  열린 넘김: 1개", "    받음 ← R2: 넘길 일 · 열림 · R5 설계 중",
                     "  판정 줄: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다",
                     "  자원: worktree /w/r5(구현)", "  기다리는 질문: 새 결정 하나"):
            self.assertIn(want, text)
        self.assertNotIn("끝난 일", text)

    def test_unknown_epic(self):
        lines, rc = cp.epic_view(RM, self.rep(), "R9")
        self.assertEqual(rc, 2)
        self.assertIn("있는 에픽: R1 · R5", lines[0])

    def test_cli_rejects_bad_epic_and_tasks_with_epic(self):
        self.assertEqual(cp.main(["show", RM, "r5"]), 2)
        self.assertEqual(cp.main(["show", "--tasks", RM, "R5"]), 2)
```

`test_spec_review_bundle.sh`: Task 7 장면의 `nbr7` 단언들 뒤에 `assert_contains "$nbr7" "크기 작음" "§6: 이웃 줄에 크기를 보인다"` 를 더한다(R7 블록에 `- 크기: 작음` 이 있다).

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py`
Expected: ERROR — `AttributeError: … epic_view`

- [ ] **Step 3: 에픽 보기를 쓴다**

```python
EPIC_ARG_RE = re.compile(r"[A-Z][0-9]+[a-z]?")


def epic_view(path: str, report: dict, epic: str):
    """(줄들, rc) — 에픽 하나의 묶음 · 설계문서 · 계획 · 브랜치 · PR · 의존 · 동시 가능 · 선택 칸 · 넘김 · 판정 · 자원.
    줄마다 경로나 번호가 있어 한 단계 더 내려갈 수 있다."""
    blocks = report.get("blocks") or []
    b = next((x for x in blocks if x.get("id") == epic), None)
    if b is None:
        have = " · ".join(str(x.get("id")) for x in blocks) or "없음"
        return [clean("에픽 %s 가 로드맵 %s 에 없다 — 있는 에픽: %s" % (epic, path, have))], 2
    stages = dict((x.get("id"), x.get("stage")) for x in blocks)
    out = [clean("%s %s — %s · %s" % (b["id"], b.get("title"), b.get("stage"), b.get("reason"))),
           clean("  로드맵: %s" % path)]

    def row(label, values):
        out.append(clean("  %s: %s" % (label, " · ".join(values) if values else "없음")))

    def branch_cell(s):
        if s.get("merged"):
            return "%s(머지됨)" % s["branch"]
        return "%s(%s)" % (s["branch"], "진행 — %s" % s["tip"][:8] if s.get("tip") else "아직 없음")

    row("묶음", [b["bundle"]] if b.get("bundle") else [])
    row("설계문서", b.get("specs") or [])
    row("계획", b.get("plans") or [])
    row("브랜치", [branch_cell(s) for s in b.get("branch_states") or []])
    if b.get("pr"):
        out.append(clean("  PR: %s" % pr_text(b["pr"])))
    row("의존", ["%s(%s)" % (d, stages.get(d)) for d in b.get("deps") or []])
    row("동시에 갈 수 있는 에픽", [p["id"] + ("(경로 예약 겹침: %s)" % " · ".join(p["overlap"]) if p.get("overlap") else "")
                          for p in b.get("parallel") or []])
    for key, value in (b.get("extras") or {}).items():
        out.append(clean("  %s: %s" % (key, value)))
    mine = [h for h in report.get("handoffs") or []
            if epic in (h.get("giver"), h.get("receiver")) and h.get("state") != "확인됨"]
    out.append("  열린 넘김: %s" % ("없음" if not mine else "%d개" % len(mine)))
    for h in mine:
        arrow = "받음 ← %s" % h["giver"] if h["receiver"] == epic else "줌 → %s" % h["receiver"]
        out.append(clean("    %s: %s · %s · %s" % (arrow, h["item"], h["state"], h["basis"])))
    if "rulings" not in b:
        out.append("  판정 줄: 아직 없음(구현 전)")
    elif b["rulings"] is None:
        out.append("  판정 줄: 셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다")
    else:
        out.append(clean("  판정 줄: %d개(%s)" % (len(b["rulings"]), b.get("rulings_source"))))
        out += [clean("    %s" % r) for r in b["rulings"]]
    if report.get("machine_error"):
        out.append(clean("  기계 상태를 읽지 못했다 — %s" % report["machine_error"]))
    elif report.get("machine") is not None:
        m = report["machine"]
        row("자원", ["%s %s(%s)" % (r["종류"], r["경로"], r["용도"]) for r in m.get("자원", []) if r["에픽"] == epic])
        row("살아 있는 agent", ["%s(%s · %s)" % (r["이름"], r["일"], r["worktree"])
                              for r in m.get("살아 있는 agent", []) if r["에픽"] == epic])
        row("기다리는 질문", [r["질문"] for r in m.get("기다리는 질문", []) if r["에픽"] == epic])
    out += [clean("  경고: %s" % w) for w in b.get("warnings") or []]
    out += [clean("  정보: %s" % n) for n in b.get("notes") or []]
    return out, 0
```

`cmd_show(tasks, arg)` 를 `cmd_show(tasks, arg, epic=None)` 로 바꾸고, `if tasks:` 갈래 앞에 더한다:

```python
    if epic:
        _path, report = v["items"][0]
        if report.get("exit") in (3, 4):
            print(show_text(v["items"], v["interview"], v["notes"], first_line, v["select_error"]))
            return 0
        lines, rc = epic_view(_path, report, epic)
        print("\n".join(lines))
        return rc
```

`main` 의 `show` 하위 파서에 `sp.add_argument("epic", nargs="?")` 를 더하고, 인자 검사를 아래로 바꾼다:

```python
    if args.cmd == "show":
        if args.roadmap is not None and (not args.roadmap.strip() or args.roadmap.startswith("-")):
            sys.stderr.write("사용법: 로드맵 경로는 비지 않고 - 로 시작하지 않는다\n")
            return 2
        if args.epic is not None and (args.tasks or not EPIC_ARG_RE.fullmatch(args.epic)):
            sys.stderr.write("사용법: 에픽은 로드맵 경로 뒤에 하나(`<대문자><숫자>[소문자]`), --tasks 와 함께 쓰지 않는다\n")
            return 2
        return cmd_show(args.tasks, args.roadmap, args.epic)
```

머리 docstring 에 `control_plane.py show <로드맵 경로> <에픽>   에픽 하나로 내려가는 보기. 없는 에픽이면 rc 2.` 를 더한다.

`spec_review_bundle._line` 을 바꾼다:

```python
def _line(b: dict) -> str:
    extra = ["%s %s" % (k, (b.get("extras") or {})[k]) for k in ("크기", "순서 이유") if k in (b.get("extras") or {})]
    return "%s %s — %s · %s%s" % (b["id"], b["title"], b["stage"], b["reason"],
                                  (" · " + " · ".join(extra)) if extra else "")
```

`skills/roadmap-status/SKILL.md`:
- `description` 끝 문장을 「… 판정 줄을 한 화면에 보인다. 에픽을 하나 더 주면 그 에픽의 묶음 · 설계문서 · 계획 · 브랜치 · PR · 넘김 · 판정 줄 · 자원을 경로와 함께 보인다. 읽기만 한다.」 로, `argument-hint: "[<로드맵 경로> [<에픽>]]"` 로.
- `### 2. 지도 내기` 의 인자 규칙을 「공백으로 나눈 토큰이 하나 또는 둘이다. 첫 토큰은 지금 규칙의 로드맵 경로, 둘째 토큰은 `^[A-Z][0-9]+[a-z]?$` 에 맞는 에픽 이름이다. 그 밖이면 셸에 넘기지 않고 `[spec-distill] roadmap-status 인자는 로드맵 경로 하나 또는 로드맵 경로와 에픽 이름이다 — 받은 것: <인자>.` 를 내고 멈춘다.」 로 바꾸고, 펜스를 `python3 "$SD/scripts/control_plane.py" show "<경로>" "<에픽>"` 로(에픽이 없으면 `"<에픽>"` 을 지운다).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py && bash plugins/spec-distill/tests/test_spec_review_bundle.sh 2>&1 | tail -n 3 && bash shared/tests/test_invocation_surface.sh 2>&1 | tail -n 3 && bash shared/tests/test_entry_preflight.sh 2>&1 | tail -n 3`
Expected: OK · `Fail: 0` 셋.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/scripts/spec_review_bundle.py plugins/spec-distill/skills/roadmap-status/SKILL.md plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_spec_review_bundle.sh
git commit -m "feat(spec-distill): roadmap-status 가 에픽 하나로 내려가는 보기를 낸다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 12: 로드맵 온톨로지 문서와 락 (AC10)

**Files:**
- Create: `plugins/spec-distill/references/roadmap-ontology.md`
- Test: `plugins/spec-distill/tests/test_roadmap_ontology.py`

**Interfaces:**
- Consumes: `roadmap_model.FIELDS`, 스크립트 글(`roadmap_model.py` · `roadmap_status.py` · `check_bundle_coverage.py` · `repo_defaults.py` · `conductor_state.py` · `roadmap_render.py`).
- Produces: `references/roadmap-ontology.md` — `## 계층` 표(층 넷)와 `## 객체` 표(칸: 객체 · 층 · 식별자 · 속성 · 링크(칸 · 키) · 주인). 계획 3 의 지휘자 skill 이 이 파일을 읽는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""references/roadmap-ontology.md — 계층 넷 · 객체 표 · 링크 칸 이름의 실재(R5 AC10).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PLUGIN / "scripts"))
from roadmap_model import FIELDS, section_body  # noqa: E402

DOC = PLUGIN / "references" / "roadmap-ontology.md"
SOURCES = ("roadmap_model.py", "roadmap_status.py", "check_bundle_coverage.py", "repo_defaults.py",
           "conductor_state.py", "roadmap_render.py")
LAYERS = ("컨트롤 플레인", "계획", "실행", "기록")
HEAD = ["객체", "층", "식별자", "속성", "링크(칸 · 키)", "주인"]
BACKTICK = re.compile(r"`([^`]+)`")


def rows(section: str) -> list:
    body = section_body(DOC.read_text(encoding="utf-8"), section) or ""
    lines = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    return [[c.strip() for c in l[1:-1].split("|")] for l in lines]


def link_ok(token: str, corpus: str) -> bool:
    return token.rstrip(":") in FIELDS or token in corpus


class Ontology(unittest.TestCase):
    def setUp(self):
        self.corpus = "\n".join((PLUGIN / "scripts" / n).read_text(encoding="utf-8") for n in SOURCES)

    def test_four_layers(self):
        self.assertEqual([r[0] for r in rows("## 계층")[2:]], list(LAYERS))

    def test_object_table_shape(self):
        table = rows("## 객체")
        self.assertEqual(table[0], HEAD)
        self.assertGreaterEqual(len(table) - 2, 15)
        for r in table[2:]:
            self.assertEqual(len(r), len(HEAD), r)
            self.assertIn(r[1], LAYERS, r)

    def test_link_names_exist_in_parsers(self):
        missing = []
        for r in rows("## 객체")[2:]:
            for token in BACKTICK.findall(r[4]):
                if not link_ok(token, self.corpus):
                    missing.append("%s: %s" % (r[0], token))
        self.assertEqual(missing, [])

    def test_lock_catches_a_made_up_link(self):   # 양성 대조 — 없는 칸 이름은 걸린다
        self.assertFalse(link_ok("없는칸:", self.corpus))
        self.assertTrue(link_ok("묶음:", self.corpus))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py`
Expected: FAIL — 문서가 없어 표가 비었다(`[] != ['컨트롤 플레인', …]`).

- [ ] **Step 3: 문서를 쓴다**

```markdown
# 로드맵 온톨로지

지휘자와 화면은 컨트롤 플레인에서 출발해 식별자로 아래 층을 타고 내려간다. 사실마다 주인은 하나다 — 주인만 쓰고 나머지는 읽거나 계산한다. 고칠 때는 주인을 고친다. 주인과 캐시가 어긋나면 주인을 믿고 캐시를 고친 뒤 알린다.

## 계층

| 층 | 무엇 | 예 |
|---|---|---|
| 컨트롤 플레인 | 보고 조작하는 곳 — 자기 상태가 없고 아래 층에서 계산한다 | 지휘자 skill · `/spec-distill:roadmap-status` · 상태줄 · 작업 목록 |
| 계획 | 무엇을 왜 하나 — 정본 | 로드맵 → 에픽 묶음 → 설계문서 · 산출물 → 계획 |
| 실행 | 실제로 일어나는 것 | 세션 · agent · worktree · 브랜치 · 커밋 · PR |
| 기록 | 무엇이 일어났고 무엇을 정했나 | 결정 기록 · 재분해 이력 · 판정 · 구현 대조 · 지휘 기록 · 기계 상태 · 실행 원장 · 리뷰 원장 |

## 객체

| 객체 | 층 | 식별자 | 속성 | 링크(칸 · 키) | 주인 |
|---|---|---|---|---|---|
| 로드맵 | 계획 | 레포 상대 경로 | 에픽 · 결정 기록 · 재분해 이력 · 위험 번호표 | `source_brief` → brief · `specs_dir` · `plans_dir` · `test_command` · `review_model` → 레포 설정 | 로드맵 파일(git) — 인터뷰가 만들고 그 뒤는 재분해 절차로만 |
| 에픽 | 계획 | 블록 번호(예: R5) | 의도 · 범위(한다 · 안 한다) · 크기 · 병렬(직렬 이유) · 순서 이유 · 근거 · 흐름 | `묶음:` → 에픽 묶음 · `의존:` → 에픽 · `브랜치:` → 브랜치 · `산출물:` → 산출물 · `spec:` → 설계문서 · `경로 예약:` → 파일 | 로드맵 |
| 에픽 묶음 | 계획 | 로드맵 옆 `<에픽>.md` | 배정 번호 · brief 발췌 · 인터페이스 | `epic` → 에픽 · `roadmap` → 로드맵 · `source_brief` → brief · `ids` → 번호 | 생성기(`roadmap_write.py`) |
| 설계문서 | 계획 | 레포 상대 경로 | AC · 번호 대조 · 미룸 · 결정 기록 | `source_interview` → 에픽 묶음 · `roadmap` → 로드맵 | 그 에픽의 설계 세션 |
| 산출물 | 계획 | 레포 상대 경로 | 설계문서 대신 내는 결과 · 판정 · 구현 대조 · 지휘 기록 절 | `산출물:` ← 에픽 · `source_interview` → 에픽 묶음 | 그 에픽의 세션 |
| 계획 | 계획 | 레포 상대 경로 | task · 이 계획의 AC | `**Spec:**` → 설계문서 | 계획을 쓴 세션 |
| 레포 설정 | 계획 | 로드맵 frontmatter 키 | 설계문서 · 계획 폴더 · 테스트 명령 · 리뷰 모델 | `specs_dir` · `plans_dir` · `test_command` · `review_model` | 로드맵 frontmatter(없으면 플러그인 기본값) |
| 브랜치 | 실행 | 브랜치 이름 | 끝 커밋 · 머지 여부 | `브랜치:` ← 에픽 · PR 의 head → PR | git |
| 커밋 | 실행 | SHA | 메시지 · 트레일러 | `Spec:` 트레일러 → 설계문서 | git |
| PR | 실행 | `#<n>` | 상태(열림 · 머지됨 · 닫힘) · 통합 리뷰 인계 절 | head → 브랜치 · 기계 상태 `PR` 절 → 캐시 | GitHub(있으면) — 기계 상태의 것은 캐시 |
| worktree · agent | 실행 | 경로 · agent 이름 | 용도 · 만든 때 · 맡은 일 | 기계 상태 `자원` · `살아 있는 agent` 절 → 에픽 | 지휘자 기계 상태(이 기계에서만) |
| 결정 기록 줄 | 기록 | 블록 · 종류 · 날짜 | 원문 「…」 | 로드맵 `## 결정 기록` → 에픽 | 로드맵 |
| 재분해 이력 항목 | 기록 | `### <날짜> · <사유>` | 바뀜 · 원문 | 로드맵 `## 재분해 이력` → 로드맵 | 로드맵 — 재분해 절차로만 |
| 번호 대조 행 | 기록 | brief 번호(C7 · S36 · «key») | 반영/기각 · 자리 또는 이유 | 설계문서 `## 번호 대조` → 에픽 묶음 `ids` | 설계문서 |
| 미룸 · 넘김 줄 | 기록 | 준 에픽 + 항목 | 이유 · 상태(열림 · 처리됨 · 확인됨 · 이슈 · 받는 곳 없음) | 설계문서 `## 미룸` 의 `받는 곳` → 에픽 · `#<n>` | 준 쪽 설계문서 — 상태는 받는 쪽 설계문서 · 머지에서 계산 |
| 넘김 확인 줄 | 기록 | 준 에픽 + 항목 해시 8자 | 근거 | `- 넘김 확인` → 미룸 · 넘김 줄 | 받는 쪽 설계문서 `## 지휘 기록` |
| 판정 | 기록 | 원장 줄 | 무엇 — 왜 — 틀리면 비용 | 기계 상태 `실행 원장` → 진행 중 원장 · `## 판정` → 보관본 | 실행 중엔 실행 방식 원장, 끝나면 설계문서 `## 판정` |
| 구현 대조 | 기록 | `## 구현 대조 — <계획 경로>` | AC 보고 요약 | `## 구현 대조 —` → 계획 | 설계문서(지휘자가 쓴다) |
| 지휘 기록 | 기록 | 설계문서 절 | 고른 흐름 · 건너뛴 확인과 이유 · 보낸 일 · 넘김 확인 | `## 지휘 기록` → 에픽 | 설계문서(지휘자가 쓴다) |
| 기계 상태 | 기록 | `<state-root>/conductor/<로드맵 폴더>/machine.md` | PR 캐시 · 실행 원장 위치 · 자원 · agent · 기다리는 질문 · 쌓인 기록 · 임시 레포 설정 | `PR` · `실행 원장` · `자원` 절 → 실행 층 | 지휘자 — 다시 만들 수 있는 것만 둔다 |
| 리뷰 원장 | 기록 | 문서별 상태 디렉토리 | 라운드 · 재리뷰 상한 · finding | 문서 경로 → 설계문서 | 리뷰 엔진 |

## 타고 내려가기

`/spec-distill:roadmap-status <로드맵> <에픽>` 이 에픽 하나의 묶음 · 설계문서 · 계획 · 브랜치 · PR · 동시에 갈 수 있는 에픽 · 열린 넘김 · 판정 줄 · 자원을 경로와 번호로 보인다. 줄마다 경로나 번호가 있어 한 단계 더 내려간다 — 설계문서 경로로 그 문서를, 계획 경로로 그 계획을, `#<n>` 으로 그 PR 을 연다.
```

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py`
Expected: `OK` (4 tests). 실패하는 링크 이름이 있으면 문서를 고친다 — 스크립트에 없는 이름을 지어내지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/roadmap-ontology.md plugins/spec-distill/tests/test_roadmap_ontology.py
git commit -m "docs(spec-distill): 로드맵 계층 · 객체 · 링크 · 주인 표와 링크 이름 실재 락

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 13: 옮기기 — `roadmap_write.py migrate` 와 이 로드맵 옮기기 (AC4)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_write.py` (`cmd_migrate` · `build_parser` · `COMMANDS` · 머리 docstring)
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md`
- Test: `plugins/spec-distill/tests/test_roadmap_migrate.py` (새로)

**Interfaces:**
- Consumes: `R.extract_rows` · `R.render_block` · `R.replace_epics`(Task 4), `roadmap_model.quotes` · `parse_history`(Task 2), `validate` · `Txn` · `run_txn`(기존).
- Produces: `roadmap_write.py migrate --roadmap <로드맵>` — 블록을 새 형식으로 다시 쓴다(재분해 이력은 건드리지 않는다). 종료 코드 0 성공(옮길 것 없음 포함) · 1 쓰지 않음 · 2 사용법.

- [ ] **Step 1: 기본 브랜치를 받아 합친다**

지휘 세션이 같은 로드맵을 고치는 재분해 PR 을 따로 연다(새 에픽 · 넘김 범위). 그것이 이미 머지됐으면 그 위에서 옮긴다.

Run: `git fetch origin && git merge --no-edit origin/main && git log --oneline -1`
Expected: 충돌 없이 합쳐진다(충돌이 나면 멈추고 알린다 — rebase 하지 않는다).

- [ ] **Step 2: 실패하는 테스트를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py migrate — 옛 블록을 새 형식으로, 인용을 잃지 않고(R5 AC4).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py
"""
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_render as R  # noqa: E402
import roadmap_write as W  # noqa: E402
from roadmap_model import parse_history, parse_roadmap, quotes  # noqa: E402

PRE = "93be1042"
RM = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"


def git_show(rev_path: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), "show", rev_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise AssertionError("git show %s 실패: %s" % (rev_path, proc.stderr.decode("utf-8", "replace")))
    return proc.stdout.decode("utf-8")


class MigrateText(unittest.TestCase):
    def test_old_blocks_become_new_with_same_quotes(self):
        old = git_show(PRE + ":" + RM)
        new = W.migrated_text(old, lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n)))
        self.assertNotEqual(new, old)
        self.assertEqual(set(quotes(old)), set(quotes(new)))
        self.assertEqual(parse_roadmap(new)[4], [])
        self.assertIn("- 범위:\n  - 한다: ", new)

    def test_migrated_text_is_a_fixed_point(self):
        old = git_show(PRE + ":" + RM)
        read = lambda n: git_show("%s:%s/%s" % (PRE, Path(RM).parent.as_posix(), n))  # noqa: E731
        once = W.migrated_text(old, read)
        self.assertEqual(W.migrated_text(once, read), once)


class LiveRoadmap(unittest.TestCase):
    """이 로드맵은 옮겨졌다 — 옛 꼴 블록 · 옛 꼴 이력이 없고, 옮기기 전 인용을 하나도 잃지 않았다."""

    def setUp(self):
        self.text = (REPO / RM).read_text(encoding="utf-8")

    def test_no_quote_lost_since_before_migration(self):
        lost = set(quotes(git_show(PRE + ":" + RM))) - set(quotes(self.text))
        self.assertEqual(lost, set())

    def test_history_is_new_form(self):
        entries, errors = parse_history(self.text)
        self.assertEqual(errors, [])
        self.assertEqual([e["date"] for e in entries if e["form"] == "old"], [])

    def test_scopes_are_sub_items(self):
        _m, blocks, _r, _k, errors = parse_roadmap(self.text)
        self.assertEqual(errors, [])
        one_line = [b["id"] for b in blocks if isinstance(b["fields"].get("범위"), str)
                    and R.SCOPE_RE.fullmatch(b["fields"]["범위"])]
        self.assertEqual(one_line, [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py`
Expected: ERROR/FAIL — `AttributeError: module 'roadmap_write' has no attribute 'migrated_text'`, `LiveRoadmap` 의 이력 · 범위 단언 실패.

- [ ] **Step 4: `migrate` 를 쓴다**

`roadmap_write.py` 머리 docstring 의 명령줄에 `roadmap_write.py migrate --roadmap <로드맵>     로드맵 블록을 새 형식으로 다시 쓴다(재분해 이력은 그대로)` 를 더하고, import 에 `quotes` 를 더한다. `cmd_update` 아래에 더한다:

```python
def migrated_text(old_text: str, read_bundle) -> str:
    """로드맵 블록을 새 형식으로 — 표로 뽑아 다시 그린다. 인용이 사라지거나 되읽은 표가 다르면 Refused."""
    rows = R.extract_rows(old_text, read_bundle)
    new_text = R.replace_epics(old_text, [R.render_block(r) for r in rows])
    lost = set(quotes(old_text)) - set(quotes(new_text))
    if lost:
        raise Refused("옮기면 원문 인용이 사라진다 — %s" % " · ".join(sorted(lost)))
    if R.extract_rows(new_text, read_bundle) != rows:
        raise Refused("옮긴 블록을 되읽은 표가 옮기기 전과 다르다")
    return new_text


def cmd_migrate(a) -> int:
    roadmap = Path(os.path.realpath(a.roadmap))
    top = git_top(roadmap)
    rdir = roadmap.parent
    old_text = read(roadmap)
    new_text = migrated_text(old_text, lambda n: read(rdir / n) if (rdir / n).is_file() else None)
    if new_text == old_text:
        print("[spec-distill] 옮길 것이 없다 — 블록이 이미 새 형식이다")
        return 0
    txn = Txn()

    def body():
        txn.write(roadmap, new_text)
        reasons = validate(top, roadmap)
        if reasons:
            raise Refused("검증 실패 — %s" % " / ".join(reasons))

    run_txn(txn, body)
    print("[spec-distill] 로드맵 블록을 새 형식으로 옮겼다: %s — 재분해 이력은 옮기지 않았다" % rel(top, roadmap))
    return 0
```

`build_parser` 에 `m = sub.add_parser("migrate"); m.add_argument("--roadmap", required=True)` 를, `COMMANDS` 에 `"migrate": cmd_migrate` 를 더한다.

- [ ] **Step 5: 블록을 옮긴다**

Run: `python3 plugins/spec-distill/scripts/roadmap_write.py migrate --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md && git diff --stat`
Expected: `로드맵 블록을 새 형식으로 옮겼다` 와 `roadmap.md` 한 파일의 변경. `git diff` 를 눈으로 본다 — 바뀐 줄은 블록의 `- 범위:` 줄뿐이어야 한다.

- [ ] **Step 6: 재분해 이력을 손으로 옮긴다**

`## 재분해 이력` 의 옛 꼴 줄(`- <날짜> · …`)마다 새 꼴 항목 하나로 바꾼다. 규칙:
- 머리 `### <날짜> · <사유>` 의 사유는 옛 줄의 둘째 조각(첫 ` · ` 와 둘째 ` · ` 사이 — 예 「처음 로드맵」 · 「R7 착수 중 수정」 · 「재분해」).
- `- 바뀜:` 은 그 줄이 바꾼 것을 뜻 단위의 하위 항목으로 나눈다. 사용자 말이 아닌 「…」(용어 표시 — 예 「에픽」 · 「셀 수 없음」)는 그 항목 안에 그대로 둔다. 항목 끝 괄호에 근거(문서 · 설계 번호)를 둘 수 있다.
- `- 원문:` 은 그 줄의 사용자 말 「…」 을 나온 순서대로 줄마다 하나(`  - 「…」`) 둔다. 겹친 인용(「… 「끝에 할 일 하나」 …」)은 바깥 하나가 한 줄이다. 인용 앞의 승인 번호(`S47`)는 바뀜 항목에 둔다.
- 항목 사이는 빈 줄 하나다. 날짜 순서 · 항목 순서는 그대로다.

예(첫 줄):

```markdown
### 2026-10-11 · 처음 로드맵
- 바뀜:
  - 승인 원문 S47
  - 선행 3 을 P1~P4 블록으로 나눴다(R0 설계 §1)
- 원문:
  - 「이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인」
```

옮긴 뒤 인용 집합이 옮기기 전(지금 HEAD)과 같은지 잰다:

Run:
```bash
python3 -I - <<'PY'
import subprocess, sys
sys.path.insert(0, "plugins/spec-distill/scripts")
from roadmap_model import parse_history, parse_roadmap, quotes
p = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"
old = subprocess.run(["git", "show", "HEAD:" + p], stdout=subprocess.PIPE, check=True).stdout.decode("utf-8")
new = open(p, encoding="utf-8").read()
a, b = set(quotes(old)), set(quotes(new))
print("빠진 인용:", sorted(a - b))
print("새 인용:", sorted(b - a))
print("형식 오류:", parse_roadmap(new)[4])
print("옛 꼴 이력:", [e["date"] for e in parse_history(new)[0] if e["form"] == "old"])
sys.exit(0 if a == b and not parse_roadmap(new)[4] else 1)
PY
```
Expected: 네 줄이 모두 빈 목록이고 rc 0. 빠진 인용이 있으면 그 인용을 바뀜이나 원문에 되살린다.

- [ ] **Step 7: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_model.py && python3 plugins/spec-distill/scripts/roadmap_status.py --roadmap-file docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md > /dev/null; echo "rc=$?"`
Expected: OK(Task 4 의 `GoldenSample` 두 실패가 이제 초록) · 상태 계산 rc 는 0 또는 1(3 이면 사유를 보고 고친다).

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_roadmap_migrate.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
git commit -m "feat(spec-distill): 로드맵 옮기기와 이 로드맵의 범위 · 재분해 이력을 새 형식으로

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 14: 이 로드맵에 R5 의 브랜치 셋 · 경로 예약 · 순서 이유 · 리뷰 모델 등록 (AC5 등록 · §11)

**Files:**
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` (frontmatter · 머리 문단 · R5 블록 · 재분해 이력)
- Create: `.superpowers/sdd/2026-10-17-epic-conductor-1-format-state/table.md` (git 이 추적하지 않는다)

**Interfaces:**
- Consumes: `roadmap_write.py extract` · `update`(Task 4 · 13), 여러 브랜치 해석기(Task 2 · 7).
- Produces: R5 블록 `- 브랜치: feature/epic-conductor · feature/epic-conductor-seams · feature/epic-conductor-loop`, 경로 예약 목록, `- 순서 이유: …`, 로드맵 frontmatter `review_model: opus`.

- [ ] **Step 1: 리뷰 모델을 frontmatter 에 둔다**

`roadmap.md` frontmatter 의 `source_brief:` 줄 아래에 `review_model: opus` 한 줄을 더한다(이 레포의 리뷰 모델 — fable 금지). 머리 문단의 「다만 지금의 상태 계산은 에픽 하나를 브랜치 하나로 센다(에픽 하나의 PR 여러 개 추적은 R5).」 를 「에픽 하나는 `브랜치:` 에 브랜치를 여럿 적어 PR 여럿을 낼 수 있고, 상태 계산은 브랜치마다 · 계획마다 센다.」 로 바꾼다.

- [ ] **Step 2: 표를 뽑아 R5 행을 고친다**

Run: `python3 plugins/spec-distill/scripts/roadmap_write.py extract --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md > .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/table.md`

그 파일에서 R5 행의 칸을 바꾼다(표가 칸 열하나면 머리 · 구분 행과 모든 행 끝에 선택 칸 여섯(`크기 | 병렬 | 순서 이유 | 근거 | 흐름 | 산출물`)을 더하고, R5 가 아닌 행의 그 칸은 모두 `없음`):
- 브랜치: `feature/epic-conductor · feature/epic-conductor-seams · feature/epic-conductor-loop`
- 경로 예약: `plugins/spec-distill/skills/epic-conductor/, plugins/spec-distill/skills/roadmap-status/SKILL.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/skills/spec-interview/references/finishing.md, plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/references/roadmap-ontology.md, plugins/spec-distill/references/epic-handoff.md, plugins/spec-distill/references/redecompose.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/conductor_state.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/merge_check.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/scripts/spec_review_bundle.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/templates/roadmap-template.md`
- 순서 이유: `계획 셋을 차례로(형식 · 상태 → 이음매 → 지휘자) — 셋째는 R2a 가 qg 테스트 스크립트를 shared/ 로 옮긴 뒤(설계 D1.3 · §11)`

- [ ] **Step 3: 재분해 절차로 쓴다**

Run:
```bash
python3 plugins/spec-distill/scripts/roadmap_write.py update \
  --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md \
  --brief docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md \
  --audit docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md \
  --plan-table .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/table.md \
  --date 2026-10-17 \
  --change "R5 계획 셋의 브랜치 · 경로 예약 · 순서 이유 등록과 리뷰 모델 레포 설정(R5 설계 §6 · §9 · §11)" \
  --approval "① /compact 후 다음 세션 줄 (권장)"
```
Expected: `로드맵을 다시 나눴다: … — 바뀜 R5 · 묶음 0개 씀 · 0개 지움`. (승인 원문은 R5 설계의 승인 게이트 답이다 — §11 이 이 등록을 정했다.)

- [ ] **Step 4: 확인한다**

Run: `python3 plugins/spec-distill/scripts/roadmap_status.py --roadmap-file docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md --json | python3 -I -c 'import json,sys; r=json.load(sys.stdin); b=next(x for x in r["blocks"] if x["id"]=="R5"); print(b["stage"], "|", b["branches"], "|", r["settings"]["review_model"], "|", r["format_errors"])'`
Expected: `구현 중 | ['feature/epic-conductor', 'feature/epic-conductor-seams', 'feature/epic-conductor-loop'] | opus | []` — 앞 브랜치가 진행 중이고 뒤 둘은 아직 없어 「머지됨」이 아니다.

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_migrate.py`
Expected: OK(정답 견본이 열일곱 칸 표 · R5 의 선택 칸을 그대로 다시 그린다).

- [ ] **Step 5: 커밋**

```bash
git add docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
git commit -m "docs(roadmap): R5 계획 셋의 브랜치 · 경로 예약 · 순서 이유와 리뷰 모델 등록

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

---

### Task 15: 릴리스 · 문서 · 스위트 대조 · 구현 대조 (AC38)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`
- Modify: `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` (`## 미룸` · `## 판정` · `## 구현 대조 — <이 계획 경로>`)

**Interfaces:**
- Consumes: Task 0 의 `suite-names.sh` · `baseline.txt`, `check_bundle_coverage.py --plan · --impl --acs`(Task 8), `conductor_state.IMPL_PREFIX` · `RULINGS_HEADING` 의 절 이름(Task 3).

- [ ] **Step 1: 버전을 올린다**

Run: `git fetch origin && git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'`
그 값의 minor 를 하나 올린 번호(예: `7.0.1` → `7.1.0`)를 `plugin.json` 의 `version` 에 쓴다. 머지 직전에 origin 기본 브랜치의 값이 바뀌었으면 다시 정한다.

- [ ] **Step 2: CHANGELOG 를 쓴다**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 아래에 더한다(번호는 Step 1 의 것):

```markdown
## [7.1.0] — 2026-10-17

### Added
- 로드맵 칸 아래 하위 항목(`- <칸>:` + `  - …`), 선택 칸 여섯(`크기` · `병렬` · `순서 이유` · `근거` · `흐름` · `산출물`), 새 재분해 이력 꼴(`### <날짜> · <사유>` · `- 바뀜:` · `- 원문:` + 줄마다 「…」). 옛 로드맵은 바뀌기 전과 같이 읽힌다.
- `roadmap_write.py migrate` — 로드맵 블록을 새 형식으로 다시 쓴다. `--approval` 은 여러 번 줄 수 있다.
- 로드맵 frontmatter 레포 설정 `specs_dir` · `plans_dir` · `test_command` · `review_model`(없으면 기본값 — `scripts/repo_defaults.py`).
- 상태 계산: `브랜치:` 여럿(「일부 머지 n/m」), 「구현 중」(계획 뒤 `Spec:` 트레일러 커밋) · 「구현 끝」(설계문서의 `## 구현 대조 — <계획 경로>` 절, 계획마다), `산출물:` 블록, 판정 보관본 · 넘김 상태 · 동시에 갈 수 있는 에픽.
- `scripts/conductor_state.py` — 지휘자 기계 상태(`<state-root>/conductor/<로드맵 폴더>/machine.md`)의 형식 · 세션 표지 · 원자 쓰기와 넘김 상태 계산.
- 화면: PR 단계(기계 상태 캐시 또는 `gh`, 상태줄은 `gh` 를 부르지 않는다) · 판정 줄(실행 원장 → 설계문서 `## 판정` → 「셀 수 없음」) · 겹침 내용 · `/spec-distill:roadmap-status <로드맵> <에픽>` 에픽 보기.
- `check_bundle_coverage.py --plan · --impl --acs <AC 목록>`. `--impl` 은 설계문서 `roadmap:` 의 로드맵에서 받는 곳 규칙(에픽 · `#<n>`)을 쓴다.
- `references/roadmap-ontology.md` — 계층 넷 · 객체 · 링크 · 주인 표.

### Changed
- 기본 브랜치를 `origin/HEAD` 에서 읽는다(`origin/main` 을 박지 않는다). `origin/HEAD` 가 없으면 「기본 브랜치를 알 수 없다」 로 검사 불가(3)다 — `git remote set-head origin --auto` 로 만든다.
- 로드맵이 아직 기본 브랜치에 없으면 검사 불가(3)가 아니라 종료 코드 4 와 그 사실 한 줄을 낸다(`control_plane.py show --tasks` 도 4).
- 설계문서 없는 묶음 · 묶음 아닌 블록이 계획 이후 단계면 「번호 대조 건너뜀(셀 수 없음)」 경고 줄을 낸다(N17).
- 번호 대조: `§n` 이 `## <n>.` 머리에서도 풀리고, 계획 판정이 백틱 없는 `**Spec:**` 경로를 받고, 에픽 이름 규칙이 「대문자 + 숫자 + 소문자 선택」이다.
```

- [ ] **Step 3: README 를 고친다**

`plugins/spec-distill/README.md` `## 로드맵 · 에픽 묶음`:
- 첫 문단의 「단위는 … 지금의 상태 계산은 에픽 하나를 브랜치 하나로 셉니다.」 를 「단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 이고, 에픽 하나는 `브랜치:` 에 브랜치를 여럿 적어 PR 여럿을 냅니다. 객체 · 링크 · 주인은 `references/roadmap-ontology.md` 에 있습니다.」 로.
- `roadmap_status.py` 줄의 「`origin/main` 의 로드맵」 을 「기본 브랜치(`origin/HEAD`)의 로드맵」 으로, 「아직 main 에 없는 로드맵은」 을 「아직 기본 브랜치에 없는 로드맵은(이때 종료 코드 4)」 으로 바꾸고, 줄 끝에 「설계문서 · 계획 폴더는 로드맵 frontmatter `specs_dir` · `plans_dir`(없으면 superpowers 기본 폴더)에서 찾고, 단계는 브랜치마다 · 계획마다 구현 중 · 구현 끝까지 셉니다.」 를 더한다.
- `--plan` · `--impl` 줄 끝에 「`--acs <AC 목록>` 이면 그 AC 만 대조합니다. `--impl` 의 받는 곳은 설계문서 `roadmap:` 의 로드맵에 있는 에픽이나 `#<n>` 이어야 합니다.」 를 더한다.
- `roadmap_write.py` 줄의 `create · update · extract` 를 `create · update · extract · migrate` 로 바꾸고 줄 끝에 「migrate 는 옛 꼴 블록을 새 형식(범위 하위 항목)으로 다시 씁니다.」 를 더한다.
- 「종료 코드는 둘 다 …」 줄을 「종료 코드는 둘 다 0 이상 없음 · 1 경고 · 2 사용법 오류 · 3 검사 불가이고, `roadmap_status.py` 는 4 (로드맵이 아직 기본 브랜치에 없음)를 더 냅니다.」 로.
- `### 상태줄` 의 「자세히는 `/spec-distill:roadmap-status`」 를 「자세히는 `/spec-distill:roadmap-status`(에픽 하나는 `<로드맵> <에픽>`)」 로.

`## Principles Instantiated` 의 `### Three Laws` 목록 끝에 한 줄을 더한다:

```markdown
- **Law 3 (Compounding) — 로드맵 온톨로지 · 사실마다 주인 하나 (7.1.0)** — 로드맵이 가장 상류의 정본이고, 객체 · 링크 · 주인을 `references/roadmap-ontology.md` 표 하나에 둔다. 다시 불러도 같은 자리에서 이어 가도록 이어 갈 기록은 git 이 추적하는 설계문서 절에, 이 기계에서만 뜻이 있는 것만 기계 상태에 둔다(`scripts/conductor_state.py`). 링크 칸 이름의 실재는 `tests/test_roadmap_ontology.py` 가 잰다.
```

- [ ] **Step 4: 스위트를 기준선과 대조한다**

Run: `bash .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/suite-names.sh > .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/after.txt; comm -13 .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/baseline.txt .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/after.txt`
Expected: 빈 출력(이 브랜치에만 있는 실패 이름 없음). 나오면 그 실패를 고치고 다시 돈다. `comm -23` 으로 고쳐진 이름도 본다. `shared/tests/test_changelog_integrity.sh` · `test_no_new_duplication.sh` · `test_invocation_surface.sh` 가 모두 기준선과 같은지 이 대조가 함께 잰다.

- [ ] **Step 5: 계획 대조를 돌린다**

Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan docs/superpowers/specs/2026-10-17-epic-conductor-design.md docs/superpowers/plans/2026-10-17-epic-conductor-1-format-state.md --acs "AC1~AC14 · AC38 · AC39 · AC40 · AC43"`
Expected: `계획 대조: 계획에 없는 AC 없음 (AC 18개 · --acs 로 고른 것)`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "chore(spec-distill): 로드맵 형식 · 상태 계산 릴리스 기록

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```

- [ ] **Step 7: 마지막 전체 리뷰 뒤 — 구현 대조를 설계문서에 남긴다**

실행 방식의 마지막 전체 리뷰가 `ac-report.md`(SDD 작업 폴더)에 AC 마다 한 줄을 적은 뒤:

1. 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다. 받는 곳은 로드맵의 에픽 번호나 `#<n>` 이다.
2. Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-17-epic-conductor-design.md .superpowers/sdd/2026-10-17-epic-conductor-1-format-state/ac-report.md --acs "AC1~AC14 · AC38 · AC39 · AC40 · AC43"` — 출력을 고치지 않고 사용자에게 보인다.
3. 설계문서 끝에 두 절을 더한다(지휘자가 생기기 전이라 이 계획의 실행 세션이 쓴다 — 형식은 `conductor_state.RULINGS_HEADING` · `IMPL_PREFIX`):

```markdown
## 판정

- <실행 방식의 마지막 목록 「Rulings I made」 의 줄을 그대로, 줄마다 `- ` 를 붙여>

## 구현 대조 — docs/superpowers/plans/2026-10-17-epic-conductor-1-format-state.md

- 구현 대조: <위 2 의 첫 줄 그대로>
- 보고: AC 18개 중 구현됨 <n> · 미룸 <n> · 빠짐 <n>
```

4. Run: `python3 plugins/spec-distill/scripts/roadmap_status.py --roadmap-file docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md --json | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(next(b["stage"] for b in r["blocks"] if b["id"]=="R5"))'`
Expected: `구현 끝`.
5. 커밋한다:

```bash
git add docs/superpowers/specs/2026-10-17-epic-conductor-design.md
git commit -m "docs(spec-distill): R5 계획 1 의 판정과 구현 대조

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
```
