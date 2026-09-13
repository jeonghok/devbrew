# spec-distill 리뷰 훅 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 의 Stop 리뷰 훅과 그 훅만을 위한 원장·발견·구조 검사를 지우고, 설계문서 리뷰 진입을 오케스트레이터가 핸드오프 문구·skill description 을 읽고 스스로 하게 만든다.

**Architecture:** 훅이 대신 하던 세 가지를 제자리로 옮긴다 — 끄기 판정·은퇴 토큰 공시는 새 모듈 `scripts/review_entry.py` + `reviewing-spec` 의 리터럴 진입 펜스(fail-closed), TTL-GC 기동은 SessionEnd 훅의 `finally`, 리뷰 순서는 인터뷰 핸드오프 세 자리와 description. 나머지는 삭제와 죽은 인용 정정이다.

**Tech Stack:** Python 3.9(시스템) · bash 3.2(macOS) · `shared/tests/assert.sh` · `python3 -m unittest`

**Spec:** `docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md` (커밋 `592d7e64`). 이 계획은 그 설계에서 논증한다 — 실행자는 둘 다 읽는다. 설계의 AC1–AC16 번호를 그대로 쓴다.

## 목차

- [Global Constraints](#global-constraints)
- [설계의 Deferred to plan 처분](#설계의-deferred-to-plan-처분)
- [파일 구조](#파일-구조)
- [Task 0: baseline 캡처](#task-0-baseline-캡처)
- [Task 1: 진입 검사 모듈 review_entry.py](#task-1-진입-검사-모듈-review_entrypy)
- [Task 2: TTL-GC 를 SessionEnd 로](#task-2-ttl-gc-를-sessionend-로)
- [Task 3: 훅과 훅 전용 코드 삭제](#task-3-훅과-훅-전용-코드-삭제)
- [Task 4: reviewing-spec 진입 계약](#task-4-reviewing-spec-진입-계약)
- [Task 5: 핸드오프 문구 네 자리](#task-5-핸드오프-문구-네-자리)
- [Task 6: 죽은 인용 정정 + quality-gates bump](#task-6-죽은-인용-정정--quality-gates-bump)
- [Task 7: README](#task-7-readme)
- [Task 8: 부재 락 (AC1·AC2·AC7)](#task-8-부재-락-ac1ac2ac7)
- [Task 9: 회귀 비교 + 변이 검증](#task-9-회귀-비교--변이-검증)
- [Task 10: /qg 구현 리뷰](#task-10-qg-구현-리뷰)
- [Task 11: 수동 e2e (AC14)](#task-11-수동-e2e-ac14)
- [Task 12: 머지 직전 — 번호 확정과 PR](#task-12-머지-직전--번호-확정과-pr)
- [Task 13: 머지 뒤 — 메모리 갱신](#task-13-머지-뒤--메모리-갱신)
- [AC 추적표](#ac-추적표)

## Global Constraints

- 루트 `CLAUDE.md` 는 바꾸지 않는다(설계 C2 · 사용자 결정 D5). 다른 리포 사용자에게 CLAUDE.md 에 줄을 넣으라고 권하는 README 문장도 쓰지 않는다.
- 리뷰 진입에 어떤 이벤트 훅도 쓰지 않는다(C1). SessionEnd 정리 훅은 유지한다.
- kill switch 는 보안 컨트롤이다(C3). 유일한 예외: 은퇴하는 `spec-distill:Stop`·`spec-distill:review-dispatch` 는 advisory 만 내고 리뷰를 막지 않는다(D9).
- 새 책임은 별도 모듈에 둔다(C4). 리뷰어 `doc-critic`·`doc-recritic` 의 `tools:` 는 건드리지 않는다(C6). `# copy-of` 사본은 정본과 함께 바꾼다(C7).
- 오케스트레이터가 읽는 산출물(skill 본문 · 핸드오프 문구 · description)에는 행동에 필요한 것만 쓴다 — 출처·배경·존재 정당화 금지(C8, CLAUDE.md **Self-narrating artifact**). 이력은 CHANGELOG 에.
- 버전: spec-distill `1.0.0` → `2.0.0`(major), quality-gates `7.5.1` → `7.5.2`(patch). 플러그인을 처음 건드리는 커밋에서 올린다. **번호는 Task 12 에서 `origin/main` 기준으로 다시 확정한다**(C5).
- 작업 위치: 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-spec-review-hook`, 브랜치 `feature/remove-spec-review-hook`. main 체크아웃으로 `cd` 하지 않는다. bare `git stash` 금지. 하위 에이전트에게는 이 절대경로를 못 박아 준다.
- 워크트리 하니스는 여러 명령을 `&&`·파이프·heredoc 으로 엮은 셸을 거부할 수 있다 — 스크립트는 Write 도구로 파일에 쓰고 `bash <파일>` / `python3 <파일>` 로 한 명령씩 돌린다.
- python 테스트는 `cd plugins/<p>/tests && python3 -m unittest -v <module>` 로만 돈다(직접 실행은 0건 실행 후 exit 0 인 파일이 있다). 셸 테스트는 `bash <파일>`. 모든 실행에 `PYTHONDONTWRITEBYTECODE=1`.
- 시스템 python 은 3.9 — `str | None` 주석을 쓰는 파일은 `from __future__ import annotations` 필수. bash 는 3.2 — `mapfile` 없음, `set -u` 아래 빈 배열 확장 금지.
- 커밋: Conventional Commits, 한국어 설명, `<type>(spec-distill): …`(quality-gates 만 바꾸면 `(quality-gates)`, 둘 다면 `(spec-distill)`). 본문 끝에:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK
  ```
- 문서는 Korean-primary. 영어는 식별자·고유명사·원문 인용·번역이 어색한 기술어만.
- 진입 펜스와 복귀 지시의 **정확한 문자열**은 이 계획에 한 번 정의되고 여러 파일이 그대로 쓴다. 복귀 지시:
  `리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).`

## 설계의 Deferred to plan 처분

| 설계가 넘긴 것 | 이 계획의 처분 |
|---|---|
| `test_dispatch_name_defined.sh` 의 README 은퇴 절 표기 | 그 락의 참조 정규식은 백틱 바로 뒤가 **소문자로 시작하는** `<plugin>:<name>` 만 잡는다(`tools/adjudication/check_names.py` `_REF_RE`). 은퇴 절은 v0.36.0 표기를 따라 `` `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` `` 로 쓴다 — 앞은 `D` 로 시작해 안 잡히고 뒤는 플러그인 접두가 없어 안 잡힌다. 새 스위치는 반대로 단독 백틱 `` `spec-distill:review-entry` `` 를 README 에 한 번 써서 **잡히게** 한다 — `review_entry.py` 의 `kill_switch_active("spec-distill", "review-entry")` 리터럴에서 도출된 키로 해소되므로, 수신처가 사라지면 이 락이 매달림으로 잡는다(Task 7). |
| `codex_prompt_common.py` 사본 비교 방식 | `shared/tests/test_copy_of_contract.sh` 축 1b 가 사본에서 마커 줄 **하나만** 지우고 정본과 바이트 비교한다. 정본을 고친 뒤 두 사본을 `# copy-of: …` 한 줄 + 정본 전문으로 다시 만든다(Task 6). |
| `check_wiring.py` baseline 재계수 | 손으로 빼지 않는다. 삭제 뒤 `run_wiring_scan.py` 의 `exempt_total=` · `comprehensions=` 를 읽어 그 값으로 쓴다(Task 3). 예상치 17 · 54 는 교차 확인용일 뿐이다. |
| `review_entry.py` CLI · 종료 코드 | 인자 없음. stdout 에 JSON 한 줄, 정상이면 항상 rc 0. 끔 여부는 rc 가 아니라 JSON 의 `disabled` 가 말한다 — rc≠0 은 「검사 자체가 실패」 하나의 뜻만 갖게 한다(펜스가 그것을 끔으로 친다). |
| README kill switch 문구 | Task 7 에 전문. |
| 삭제 오라클(AC2)의 별칭 목록 · 범위 | 식별자는 삭제 집합에서 **도출**한다(규칙은 Task 8 락 docstring). 도출 규칙을 현재 트리에 dry-run 했을 때 잔존 인용 파일 21개가 전부 이 계획의 수정 목록 안이었다(목록 밖 0). 개념 별칭 13개는 손 목록이고, 범위는 spec-distill 배포 파일(`tests/`·CHANGELOG 제외) + 설계 §5 공용 파일 넷이다. |
| 핸드오프 문구 넷의 확정 문안 · `finishing.md` ① 템플릿 락 갱신 | Task 5 에 전문. ① 템플릿을 고정하는 기존 락은 `test_conducting_interview_stage.sh:127`(`/compact interview brief at` 존재) 하나이고 새 문안에서도 참이다. |
| `marketplace.json` | 닫힘 — version 필드가 없다. |
| baseline 실행 명령 | Task 0 스크립트. |
| 두 `test_handoff_*.sh` 처분 | **리뷰어 쪽 단독 앵커로 재조준**한다(삭제하지 않는다). 프로필 `design-doc.md` 는 `defer_target: "### Deferred to plan"` 과 `handoff_incomplete` rubric 만 이름으로 댄다 — `TL;DR` · `Implicit context` 두 라벨과 「대화 컨텍스트 가정 금지」 저자 지시는 템플릿과 함께 기계 앵커를 잃는다. 커밋 메시지와 CHANGELOG 에 적는다(Task 3). |
| AC14 새 판 표식 확인 방법 | 세션 시작 직후 `/hooks` 로 spec-distill 훅 목록을 보고(SessionEnd 하나 · 경로가 워크트리 · Stop 없음), `/interview` 가 skill 을 부를 때 출력되는 「Base directory for this skill:」 경로가 워크트리인지 본다. 둘 다 PR 에 붙인다(Task 11). |

## 파일 구조

**신설**
- `plugins/spec-distill/scripts/review_entry.py` — 진입 검사. 끄기 판정 + 은퇴 스위치 공시. 한 파일 한 책임.
- `plugins/spec-distill/tests/test_review_entry.py` — AC4·AC5 (프로세스 실행 + 환경변수 행렬).
- `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` — AC6·AC9·AC16(행동) — SKILL 의 두 펜스를 잘라내 실행.
- `plugins/spec-distill/tests/test_review_handoff_order.sh` — AC8·AC16(정적).
- `plugins/spec-distill/tests/test_review_hook_removed.py` — AC1·AC2·AC7(정적, 도출 오라클).

**삭제** — 설계 Files to Modify 의 목록 그대로(코어 7 · 테스트 13 · fixture 7 · 공용 fixture 2).

**수정** — Task 마다 `Files:` 에 적는다. 수정 파일 전체 집합은 Task 8 락의 `EDITED` 튜플과 같아야 한다.

**리포 밖 작업 파일** — `.claude/plan-baseline/`(워크트리 루트, `.gitignore` 의 `/.claude/*` 로 무시됨 — `git check-ignore` 로 확인했다). baseline 결과 · 편집 스크립트 · 변이 실행기를 둔다.

---

### Task 0: baseline 캡처

설계 Verification Plan 1 · AC12 의 비교 키를 만든다. 코드 변경 없음, 커밋 없음. 현재 HEAD(`592d7e64`)는 base `c7b4f580` 에 설계문서만 더한 것이라 테스트 결과가 base 와 같다.

**Files:**
- Create: `.claude/plan-baseline/run_suites.sh` (git 무시)
- Create: `.claude/plan-baseline/before/` (결과)

- [ ] **Step 1: 실행 스크립트를 쓴다** — Write 도구로 `.claude/plan-baseline/run_suites.sh`:

```bash
#!/usr/bin/env bash
# 사용: bash .claude/plan-baseline/run_suites.sh <출력 디렉토리>
# spec-distill · shared · quality-gates 스위트를 돌려 실패 식별자 집합(AC12 비교 키)을 남긴다.
# 셸 테스트의 식별자 = 파일 :: 실패 줄(임시 경로·숫자 정규화), python = 파일 :: unittest 케이스.
set -u
OUT="$1"
mkdir -p "$OUT"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1
export PYTHONDONTWRITEBYTECODE=1
: > "$OUT/failing_ids.raw"
: > "$OUT/summary.tsv"
norm() { sed -E 's#/(private/)?(var|tmp)/[^[:space:]]*#<tmp>#g; s/[0-9]+/N/g'; }
for f in plugins/spec-distill/tests/test_*.sh shared/tests/test_*.sh plugins/quality-gates/tests/test_*.sh; do
  log="$OUT/$(printf '%s' "$f" | tr '/' '_').log"
  bash "$f" > "$log" 2>&1
  rc=$?
  n="$(grep -cE '^[[:space:]]*(✗|\[FAIL\])' "$log")"
  printf '%s\t%s\t%s\n' "$f" "$rc" "$n" >> "$OUT/summary.tsv"
  grep -E '^[[:space:]]*(✗|\[FAIL\])' "$log" | norm | sed "s|^|$f :: |" >> "$OUT/failing_ids.raw"
  if [ "$rc" -ne 0 ] && [ "$n" -eq 0 ]; then echo "$f :: <rc!=0, 실패 줄 없음>" >> "$OUT/failing_ids.raw"; fi
done
for dir in plugins/spec-distill/tests plugins/quality-gates/tests; do
  for py in "$dir"/test_*.py; do
    mod="$(basename "$py" .py)"
    log="$OUT/$(printf '%s' "$py" | tr '/' '_').log"
    ( cd "$dir" && python3 -m unittest -v "$mod" ) > "$log" 2>&1
    rc=$?
    n="$(grep -cE ' \.\.\. (FAIL|ERROR)$' "$log")"
    printf '%s\t%s\t%s\n' "$py" "$rc" "$n" >> "$OUT/summary.tsv"
    grep -E ' \.\.\. (FAIL|ERROR)$' "$log" | sed "s|^|$py :: |" >> "$OUT/failing_ids.raw"
    if [ "$rc" -ne 0 ] && [ "$n" -eq 0 ]; then echo "$py :: <rc!=0, 실패 줄 없음>" >> "$OUT/failing_ids.raw"; fi
  done
done
sort -u "$OUT/failing_ids.raw" > "$OUT/failing_ids.txt"
wc -l < "$OUT/failing_ids.txt"
```

- [ ] **Step 2: 백그라운드로 돌린다** (수 분 걸린다 — Bash 의 `run_in_background: true`)

Run: `bash .claude/plan-baseline/run_suites.sh .claude/plan-baseline/before`
Expected: 끝에 실패 식별자 줄 수 하나. 알려진 선재 RED: `test_hook_output_schema.py :: test_python_and_bash_resolvers_agree`(워크트리에서만 — python `state_root` 는 main 체크아웃, bash 는 워크트리를 가리킨다), quality-gates 의 선재 RED 들(메모리 `project_qg_pre_existing_test_reds`).

- [ ] **Step 3: RED 인 파일마다 이유를 적는다** — `.claude/plan-baseline/before/REASONS.md` 에 `summary.tsv` 의 rc≠0 행마다 한 줄: 파일 · 실패 줄 수 · 이유(로그에서 읽은 것, 추측이면 「추측」이라고). 이 파일은 Task 9 에서 새 실패와 선재 실패를 가르는 근거다.

---

### Task 1: 진입 검사 모듈 review_entry.py

AC4 · AC5. 훅이 하던 끄기 판정과 `retired_switch_advisory`(옛 `review-dispatch.py:117-170`)의 매칭 규칙을 새 모듈로 옮긴다. 은퇴 토큰 목록은 여섯 + 환경변수 하나로 넓어지고, 세션당 1회 마커는 없앤다(설계 §4.2).

**Files:**
- Create: `plugins/spec-distill/scripts/review_entry.py`
- Create: `plugins/spec-distill/tests/test_review_entry.py`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`"version": "1.0.0"` → `"2.0.0"`)
- Modify: `plugins/spec-distill/CHANGELOG.md` (맨 위에 `[2.0.0]` 신설)

**Interfaces:**
- Produces: `python3 plugins/spec-distill/scripts/review_entry.py` → stdout JSON 한 줄 `{"disabled": bool, "reason": str|null, "advisories": [str]}`, rc 0. `reason` 값은 정확히 `DEVBREW_SPEC_DISTILL_DISABLE=1` · `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · `null` 넷 중 하나. Task 4 의 진입 펜스가 이 계약을 소비한다.
- 모듈 안 이름은 삭제된 훅의 이름을 재사용하지 않는다(`retired_switch_advisory` · `RETIRED_TOKENS` · `RETIRED_AUTOREVIEW_VAR` · `RETIRED_MARKER` 금지) — Task 8 의 도출 오라클이 그 이름들을 삭제 식별자로 잡는다.
- `kill_switch_active` 는 **문자열 리터럴 인자**로 부른다: `kill_switch_active("spec-distill", "review-entry")`. `tools/adjudication/check_names.py` 가 호출부의 리터럴에서 kill switch 키를 도출한다 — 변수로 넘기면 `spec-distill:review-entry` 가 정의 집합에서 사라진다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_review_entry.py`:

```python
#!/usr/bin/env python3
"""AC4 · AC5 — `scripts/review_entry.py` 의 끄기 판정과 은퇴 스위치 공시.

프로세스로 실행해 stdout JSON 한 줄을 본다 — 소비자(`reviewing-spec` 의 진입 펜스)가 보는
것과 같은 채널이다. 환경은 케이스마다 PATH·HOME 만 남기고 새로 짠다: 러너 셸에 켜져 있는
스위치가 케이스를 오염시키지 않게.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_review_entry
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "review_entry.py"

ENTRY_TOKEN = "spec-distill:review-entry"
DESIGN_VAR = "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"
GLOBAL_VAR = "DEVBREW_SPEC_DISTILL_DISABLE"
AUTOREVIEW_VAR = "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW"
REVIEW_RETIRED = ("spec-distill:Stop", "spec-distill:review-dispatch")
GONE_RETIRED = ("spec-distill:validator", "spec-distill:PostToolUse",
                "spec-distill:reminder", "spec-distill:UserPromptSubmit")


def run_raw(**env_extra: str) -> subprocess.CompletedProcess:
    env = {"PATH": os.environ["PATH"], "HOME": os.environ.get("HOME", "/tmp"),
           "PYTHONDONTWRITEBYTECODE": "1"}
    env.update(env_extra)
    return subprocess.run(["python3", str(SCRIPT)], env=env, capture_output=True,
                          text=True, encoding="utf-8", timeout=10)


def run_entry(**env_extra: str) -> dict:
    cp = run_raw(**env_extra)
    if cp.returncode != 0:
        raise AssertionError(f"rc={cp.returncode} stderr={cp.stderr}")
    lines = cp.stdout.splitlines()
    if len(lines) != 1:
        raise AssertionError(f"stdout 이 JSON 한 줄이 아니다: {cp.stdout!r}")
    return json.loads(lines[0])


class TestDisabledVerdict(unittest.TestCase):
    """AC4 — 끄는 스위치 셋과 `=0`·무설정."""

    def test_nothing_set_proceeds(self):
        self.assertEqual(run_entry(), {"disabled": False, "reason": None, "advisories": []})

    def test_global_disable(self):
        out = run_entry(**{GLOBAL_VAR: "1"})
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"{GLOBAL_VAR}=1")

    def test_entry_token(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=ENTRY_TOKEN)
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}")

    def test_entry_token_among_others_with_spaces(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=f"quality-gates:Stop, {ENTRY_TOKEN} ")
        self.assertTrue(out["disabled"])

    def test_design_mode_disable(self):
        out = run_entry(**{DESIGN_VAR: "1"})
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"{DESIGN_VAR}=1")

    def test_zero_values_do_not_disable(self):
        for var in (GLOBAL_VAR, DESIGN_VAR):
            with self.subTest(var=var):
                self.assertFalse(run_entry(**{var: "0"})["disabled"])

    def test_superstring_entry_token_does_not_disable(self):
        self.assertFalse(run_entry(DEVBREW_SKIP_HOOKS=ENTRY_TOKEN + "-v2")["disabled"])

    def test_c_locale_still_one_json_line(self):
        cp = run_raw(LC_ALL="C", DEVBREW_SKIP_HOOKS="spec-distill:Stop")
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(len(cp.stdout.splitlines()), 1)
        self.assertIn("더 이상 리뷰를 막지 않는다", cp.stdout,
                      "한국어가 \\uXXXX 로 나가면 사람이 읽는 advisory 가 판독 불가다")


class TestRetiredSwitchAdvisory(unittest.TestCase):
    """AC5 — 은퇴 스위치 일곱. 각 스위치를 읽던 방식 그대로 읽는다.

    토큰은 콤마 분리 + 양끝 공백 제거 + 전체 일치(부분 문자열이면 설정하지 않은 토큰을
    설정했다고 말한다), `SKIP_AUTOREVIEW` 는 `== "1"`(설정만 보면 `=0` 으로 꺼 둔 사용자에게
    거짓을 말한다).
    """

    def test_each_retired_token_is_named_and_does_not_disable(self):
        for tok in REVIEW_RETIRED + GONE_RETIRED:
            with self.subTest(tok=tok):
                out = run_entry(DEVBREW_SKIP_HOOKS=tok)
                self.assertFalse(out["disabled"], "은퇴 토큰은 리뷰를 끄지 않는다(D9)")
                self.assertEqual(len(out["advisories"]), 1)
                self.assertIn(tok, out["advisories"][0])

    def test_autoreview_var_1_is_named(self):
        out = run_entry(**{AUTOREVIEW_VAR: "1"})
        self.assertFalse(out["disabled"])
        self.assertEqual(len(out["advisories"]), 1)
        self.assertIn(AUTOREVIEW_VAR, out["advisories"][0])

    def test_autoreview_var_not_1_is_silent(self):
        for value in ("0", "", "true", "yes"):
            with self.subTest(value=value):
                self.assertEqual(run_entry(**{AUTOREVIEW_VAR: value})["advisories"], [])

    def test_superstring_retired_token_is_silent(self):
        for tok in ("spec-distill:validator-v2", "spec-distill:Stop2"):
            with self.subTest(tok=tok):
                self.assertEqual(run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"], [])

    def test_review_retired_says_review_proceeds_and_names_new_switches(self):
        for tok in REVIEW_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("더 이상 리뷰를 막지 않는다", msg)
                self.assertIn("이번 리뷰는 진행된다", msg)
                self.assertIn(f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}", msg)
                self.assertIn(f"{DESIGN_VAR}=1", msg)

    def test_review_retired_with_live_switch_states_why_off(self):
        out = run_entry(DEVBREW_SKIP_HOOKS="spec-distill:Stop", **{DESIGN_VAR: "1"})
        self.assertTrue(out["disabled"])
        msg = out["advisories"][0]
        self.assertNotIn("이번 리뷰는 진행된다", msg)
        self.assertIn(f"{DESIGN_VAR}=1 때문에 꺼졌다", msg)

    def test_review_retired_with_entry_token_in_same_list(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=f"spec-distill:Stop,{ENTRY_TOKEN}")
        self.assertTrue(out["disabled"])
        self.assertIn(f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN} 때문에 꺼졌다", out["advisories"][0])

    def test_gone_retired_names_no_alternative(self):
        for tok in GONE_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("대상이 삭제돼 아무것도 끄지 않는다", msg)
                self.assertNotIn(ENTRY_TOKEN, msg)
                self.assertNotIn(DESIGN_VAR, msg)
                self.assertNotIn("spec-distill:Stop", msg)

    def test_advisories_point_only_at_live_switches(self):
        """advisory 가 «권하는» 스위치는 전부 살아 있는 끄기 스위치다.

        사용자 자신의 `SKIP_AUTOREVIEW=1` 은 되읽기라 권유가 아니지만 같은 모양이라 허용 집합에
        함께 둔다. 토큰 되읽기(`DEVBREW_SKIP_HOOKS 의 spec-distill:Stop`)는 `=` 가 없어 추출되지
        않는다.
        """
        live = {f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}", f"{DESIGN_VAR}=1", f"{GLOBAL_VAR}=1",
                f"{AUTOREVIEW_VAR}=1"}
        every = ",".join(REVIEW_RETIRED + GONE_RETIRED)
        out = run_entry(DEVBREW_SKIP_HOOKS=every, **{AUTOREVIEW_VAR: "1"})
        text = " ".join(out["advisories"])
        suggested = set(re.findall(
            r"DEVBREW_SKIP_HOOKS=spec-distill:[A-Za-z-]+|DEVBREW_[A-Z_]+=1", text))
        self.assertTrue(suggested, "권하는 스위치를 하나도 못 뽑았다 — 추출이 깨졌다")
        self.assertLessEqual(suggested, live)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_review_entry`
Expected: 전 케이스 FAIL/ERROR — `rc=2 stderr=... can't open file '.../review_entry.py'`.

- [ ] **Step 3: 모듈을 쓴다** — `plugins/spec-distill/scripts/review_entry.py`:

```python
#!/usr/bin/env python3
"""reviewing-spec 진입 검사 — 끄기 판정과 은퇴 스위치 공시.

stdout 에 JSON 한 줄을 낸다: {"disabled": bool, "reason": str|null, "advisories": [str]}.
정상 실행은 항상 rc 0 이다 — 끔 여부는 rc 가 아니라 `disabled` 가 말한다. 소비자는
`skills/reviewing-spec/SKILL.md` 의 `review-entry` 펜스이고, 펜스가 스키마를 검사해
어긋나거나 rc≠0 이면 끔으로 친다.

끄는 스위치:
  DEVBREW_SPEC_DISTILL_DISABLE=1                  — 플러그인 전체
  DEVBREW_SKIP_HOOKS=spec-distill:review-entry    — 설계문서 리뷰 진입
  DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1      — 설계문서 리뷰 진입
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kill_switch_active import kill_switch_active  # noqa: E402

GLOBAL_VAR = "DEVBREW_SPEC_DISTILL_DISABLE"
DESIGN_MODE_VAR = "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"
ENTRY_TOKEN = "spec-distill:review-entry"

#: 자동 리뷰를 끄던 토큰. 리뷰 기능은 남아 있으므로 대체 스위치를 댄다.
REVIEW_TOKENS = ("spec-distill:Stop", "spec-distill:review-dispatch")
#: 구조 검사·리마인더를 끄던 토큰. 끄던 대상이 삭제돼 등가물이 없다 — 대체재를 대지 않는다.
GONE_TOKENS = ("spec-distill:validator", "spec-distill:PostToolUse",
               "spec-distill:reminder", "spec-distill:UserPromptSubmit")
#: 독립 환경변수 스위치. 옛 소비자가 `== "1"` 로 읽었으므로 여기서도 그렇게 읽는다.
AUTOREVIEW_VAR = "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW"

ALTERNATIVES = (
    f"설계문서 리뷰를 끄려면 DEVBREW_SKIP_HOOKS={ENTRY_TOKEN} 또는 {DESIGN_MODE_VAR}=1, "
    f"플러그인 전체는 {GLOBAL_VAR}=1."
)


def disabled_reason() -> str | None:
    """켜진 끄기 스위치의 이름. 없으면 None."""
    if kill_switch_active("spec-distill", "review-entry"):
        if os.environ.get(GLOBAL_VAR) == "1":
            return f"{GLOBAL_VAR}=1"
        return f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}"
    if os.environ.get(DESIGN_MODE_VAR) == "1":
        return f"{DESIGN_MODE_VAR}=1"
    return None


def retired_advisories(reason: str | None) -> list[str]:
    """설정된 은퇴 스위치마다 사용자의 토큰을 되읽는 문장.

    `kill_switch_active` 를 쓰지 않는 이유: bool 만 내므로 어느 토큰이 설정됐는지 이름을 댈 수
    없다. 매칭은 그 함수와 같은 규칙(콤마 분리 · 양끝 공백 제거 · 전체 토큰)이다.
    """
    raw = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in raw.split(",") if t.strip()}
    out: list[str] = []
    review_hit = [t for t in REVIEW_TOKENS if t in tokens]
    if review_hit:
        verdict = ("이번 리뷰는 진행된다." if reason is None
                   else f"이번 리뷰는 {reason} 때문에 꺼졌다.")
        out.append(
            f"[spec-distill] DEVBREW_SKIP_HOOKS 의 {', '.join(review_hit)} 는 더 이상 리뷰를 "
            f"막지 않는다 — 가리키던 훅이 삭제됐다. {verdict} {ALTERNATIVES}"
        )
    gone_hit = [t for t in GONE_TOKENS if t in tokens]
    if gone_hit:
        out.append(
            f"[spec-distill] DEVBREW_SKIP_HOOKS 의 {', '.join(gone_hit)} 는 대상이 삭제돼 "
            f"아무것도 끄지 않는다."
        )
    if os.environ.get(AUTOREVIEW_VAR) == "1":
        out.append(
            f"[spec-distill] {AUTOREVIEW_VAR}=1 은 읽는 곳이 없어 아무것도 끄지 않는다. "
            f"{ALTERNATIVES}"
        )
    return out


def evaluate() -> dict:
    reason = disabled_reason()
    return {"disabled": reason is not None, "reason": reason,
            "advisories": retired_advisories(reason)}


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except (AttributeError, OSError, ValueError):
        pass
    print(json.dumps(evaluate(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_review_entry`
Expected: `OK` (17 tests).

- [ ] **Step 5: 키 도출 락이 새 이름을 보는지 확인한다**

Run: `bash shared/tests/test_dispatch_name_defined.sh`
Expected: `Fail: 0`. 이어서 `PYTHONDONTWRITEBYTECODE=1 python3 -c 'import sys; sys.path.insert(0,"tools/adjudication"); import check_names; print("spec-distill:review-entry" in check_names.killswitch_keys("."))'` → `True`.

- [ ] **Step 6: 버전을 올리고 CHANGELOG 를 연다**

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `"version": "1.0.0",` → `"version": "2.0.0",`.

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 다음 빈 줄 뒤, 기존 `## [1.0.0] — 2026-09-09` **앞**에 넣는다:

```markdown
## [2.0.0] — 2026-09-11

major인 이유: **설계문서 리뷰의 자동 진입 계약이 깨진다.** Stop 훅(`hooks/review-dispatch.py`)이 턴 경계에서 `reviewing-spec` 을 강제하던 경로를 없애고, 리뷰 진입을 오케스트레이터가 인터뷰 핸드오프 문구와 skill description 을 읽고 스스로 부르는 것으로 바꾼다. 이 자리의 집행(철학 P13 의 hook)이 사라졌다는 사실을 숨기지 않는다 — 리뷰어 분리(Law 2 `tools:` allowlist)는 그대로다. 표준 흐름에서 그 훅은 이미 발동하지 않고 있었다: brainstorming 이 턴 안에서 설계문서를 커밋하고, 훅의 발견은 dirty·untracked 문서만 보았다. 설계: `docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md`.

**알려진 결과** — (1) 리뷰 진입에 강제가 없다. `/brainstorming` 직접 경로는 `reviewing-spec` description 하나에 기댄다 — 건너뛰면 `/spec-distill:reviewing-spec <경로>` 로 부른다. (2) CLAUDE.md Law 1 필수 섹션 게이트의 리포 내 구현이 0 이 됐다(사용자 결정 D10 — 유일한 구현이던 spec 모드 검사는 생산자가 없어 발동하지 않았다). (3) `spec-distill:Stop`·`:review-dispatch` 로 자동 리뷰를 꺼 둔 사용자는 리뷰가 되살아나고(advisory 가 알린다), 같은 토큰이 부수효과로 막던 TTL-GC 도 advisory 없이 다시 돈다(D9). (4) 저자 쪽 Handoff Context 계약의 기계 앵커가 사라졌다(아래 Changed). (5) deprecation window 면제의 근거가 약하다(아래 Deprecated).

### Added

- **`scripts/review_entry.py` — `reviewing-spec` 진입 검사.** 끄기 판정(`DEVBREW_SPEC_DISTILL_DISABLE=1` · `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`)과 은퇴 스위치 공시를 stdout JSON 한 줄(`disabled` · `reason` · `advisories`)로 낸다. 새 kill switch 이름 `spec-distill:review-entry` 가 여기서 생긴다 — 공용 헬퍼 `kill_switch_active` 가 이름을 요구하고, 이름은 스크립트 이름을 따른다(`spec-distill-gc` 와 같은 관례). skill 이름 `reviewing-spec` 을 쓰지 않은 이유: `check_names.py` 가 README 참조를 skill 이름으로도 해소해 수신처가 사라져도 매달림으로 잡히지 않는다. 락: `tests/test_review_entry.py`.
```

- [ ] **Step 7: 구조 정합을 확인한다**

Run: `bash shared/tests/test_changelog_integrity.sh`
Expected: `Fail: 0`.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/scripts/review_entry.py plugins/spec-distill/tests/test_review_entry.py plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "feat(spec-distill): reviewing-spec 진입 검사 모듈 review_entry.py" -m "끄기 판정 셋과 은퇴 스위치 일곱의 공시를 JSON 한 줄로 낸다. 새 kill switch 이름 spec-distill:review-entry. 2.0.0 으로 bump(번호는 머지 직전 재확인)." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 2: TTL-GC 를 SessionEnd 로

AC3 · 설계 §2 #1. TTL-GC(`scripts/spec-distill-gc.py`)의 유일한 기동자가 Stop 훅이다. SessionEnd 훅이 ① 자기 kill switch → ② 끝나는 세션 폴더 삭제 → ③ `finally` 에서 `fire_and_forget_gc()` 순으로 돈다. 이 Task 뒤 Task 3 전까지는 두 훅이 모두 GC 를 부른다 — GC 는 멱등이고 fcntl 락을 잡으므로 무해하다.

**Files:**
- Modify: `plugins/spec-distill/hooks/session-end-cleanup.py` (전면 교체)
- Modify: `plugins/spec-distill/tests/test_session_end_cleanup.py` (전면 교체)
- Modify: `plugins/spec-distill/CHANGELOG.md` (`[2.0.0]` 에 `### Changed` 신설)

**Interfaces:**
- Consumes: `hook_common.fire_and_forget_gc()`(기존 — 동기 `subprocess.run`, timeout 5초, 실패는 stderr).
- Produces: `run_hook(payload, env_extra=None, cwd=..., raw_stdin=None)` 는 이제 `cwd` 가 없으면 `ValueError` — SessionEnd 훅을 띄우는 모든 테스트 호출이 러너 cwd 의 실제 상태 루트에서 GC 를 돌리지 않게 하는 구조적 가드(AC3 마지막 문장).

- [ ] **Step 1: 테스트를 교체한다** — `plugins/spec-distill/tests/test_session_end_cleanup.py` 전문:

```python
"""AC4 · AC3 — SessionEnd 훅: 끝나는 세션의 폴더 정리 + TTL-GC 기동."""
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

HOOK = (Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py").resolve()

#: TTL 기본값(24h)보다 늙은 나이.
STALE_AGE_S = 90_000


def run_hook(payload, env_extra=None, cwd=None, raw_stdin=None):
    """훅을 실행한다. **`cwd` 는 필수다.**

    훅은 TTL-GC 를 돌리고, GC 의 루트는 프로세스 cwd 의 state_root 다. cwd 를 비우면 러너
    cwd — 워크트리에서 돌리면 main 체크아웃의 `.claude/spec-distill/` — 의 실제 세션 폴더를
    지운다.
    """
    if cwd is None:
        raise ValueError("run_hook: cwd 필수 — GC 가 러너 cwd 의 실제 상태 루트를 돌지 않게")
    env = {**os.environ}
    for k in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS",
              "DEVBREW_SPEC_DISTILL_TTL_HOURS", "CLAUDE_CODE_SESSION_ID"):
        env.pop(k, None)
    if env_extra:
        env.update(env_extra)
    if raw_stdin is not None:
        stdin = raw_stdin
    else:
        stdin = (json.dumps(payload) if payload is not None else "not-json").encode("utf-8")
    cp = subprocess.run(
        ["python3", str(HOOK)], input=stdin, env=env, cwd=cwd,
        capture_output=True, timeout=15,
    )
    return (cp.returncode, cp.stdout.decode("utf-8", "replace"),
            cp.stderr.decode("utf-8", "replace"))


class SessionEndCleanupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.root = Path(self.tmp) / ".claude" / "spec-distill"
        self.sid = "abc12345"
        self.folder = self.root / self.sid
        self.folder.mkdir(parents=True)
        (self.folder / "state.local.md").write_text(f"---\nsession_id: {self.sid}\n---\n")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _plant(self, name, age_s):
        """다른 세션의 폴더. 폴더 나이 = 직속 파일의 최신 mtime(gc_common)."""
        d = self.root / name
        d.mkdir(parents=True)
        f = d / "state.local.md"
        f.write_text("x")
        t = time.time() - age_s
        os.utime(f, (t, t))
        return d

    def test_1_happy_path(self):
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())

    def test_2_folder_absent(self):
        shutil.rmtree(self.folder)
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)

    def test_3_json_decode_fail(self):
        rc, _, _ = run_hook(None, cwd=self.tmp)  # sends "not-json"
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_4_session_id_missing(self):
        rc, _, _ = run_hook({"cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_5_charset_reject(self):
        rc, _, _ = run_hook({"session_id": "../evil", "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_6_cwd_missing(self):
        rc, _, stderr = run_hook({"session_id": self.sid}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())
        self.assertIn("missing 'cwd'", stderr)

    def test_7_global_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_8_granular_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    # --- AC3: TTL-GC 는 SessionEnd 의 `finally` 에서 돈다 ---

    def test_9_gc_collects_stale_other_session(self):
        stale = self._plant("stale-session-01", STALE_AGE_S)
        fresh = self._plant("fresh-session-01", 0)
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())
        self.assertFalse(stale.exists(), "TTL 이 지난 다른 세션 폴더가 남았다 — GC 가 안 돌았다")
        self.assertTrue(fresh.exists(), "살아 있는 세션 폴더까지 지웠다")

    def test_10_gc_runs_when_stdin_not_json(self):
        stale = self._plant("stale-session-02", STALE_AGE_S)
        rc, _, _ = run_hook(None, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())
        self.assertFalse(stale.exists())

    def test_11_gc_runs_when_session_id_missing(self):
        stale = self._plant("stale-session-03", STALE_AGE_S)
        rc, _, _ = run_hook({"cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())
        self.assertFalse(stale.exists())

    def test_12_gc_runs_when_stdin_undecodable(self):
        """stdin 디코딩 예외로 정리가 죽어도 GC 는 돈다(`finally`).

        훅의 rc 는 재지 않는다 — 예외는 GC 뒤에 그대로 전파된다(옛 동작과 같다).
        `PYTHONIOENCODING=utf-8:strict` 는 C 로케일의 surrogateescape 를 꺼서 디코딩 예외를
        확실히 낸다.
        """
        stale = self._plant("stale-session-04", STALE_AGE_S)
        run_hook(None, cwd=self.tmp, raw_stdin=b"\xff\xfe{",
                 env_extra={"PYTHONIOENCODING": "utf-8:strict"})
        self.assertFalse(stale.exists())

    def test_13_gc_switch_spares_stale_only(self):
        stale = self._plant("stale-session-05", STALE_AGE_S)
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:spec-distill-gc"},
        )
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists(), "GC 스위치는 세션 정리를 끄지 않는다")
        self.assertTrue(stale.exists())

    def test_14_global_disable_spares_both(self):
        stale = self._plant("stale-session-06", STALE_AGE_S)
        run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
                 env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"})
        self.assertTrue(self.folder.exists())
        self.assertTrue(stale.exists())

    def test_15_sessionend_switch_spares_both(self):
        for tok in ("spec-distill:SessionEnd", "spec-distill:session-end-cleanup"):
            with self.subTest(tok=tok):
                stale = self._plant("stale-" + tok.split(":")[1].lower(), STALE_AGE_S)
                run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
                         env_extra={"DEVBREW_SKIP_HOOKS": tok})
                self.assertTrue(self.folder.exists(), "훅은 자기 kill switch 를 거부할 수 없다")
                self.assertTrue(stale.exists(), "꺼진 훅이 다른 세션 폴더를 지웠다")

    def test_16_run_hook_refuses_missing_cwd(self):
        with self.assertRaises(ValueError):
            run_hook({"session_id": self.sid, "cwd": self.tmp})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_session_end_cleanup`
Expected: `test_9`·`test_10`·`test_11`·`test_12` FAIL(`stale.exists()` 가 참 — GC 가 안 돈다). 나머지 PASS.

- [ ] **Step 3: 훅을 교체한다** — `plugins/spec-distill/hooks/session-end-cleanup.py` 전문:

```python
#!/usr/bin/env python3
"""SessionEnd hook: 끝나는 세션의 상태 폴더 정리 + TTL-GC 기동.

순서가 계약이다:
  ① kill switch — 켜져 있으면 아무것도 하지 않는다(GC 포함). 어떤 훅도 자기 kill switch
     존중을 거부할 수 없다.
  ② 끝나는 세션의 `.claude/spec-distill/<sid>/` 삭제. 루트는 payload `cwd` 의 git-aware
     state_root(worktree compat — qg 의 cwd-relative 패턴과 다르다, spec §C9).
  ③ `finally` 에서 TTL-GC 한 번. ② 가 payload 문제로 일찍 끝나거나 예외로 죽어도 돈다.
     GC 의 루트는 **프로세스 cwd** 의 state_root 다(GC 스크립트가 스스로 푼다).
     `fire_and_forget_gc` 는 동기(timeout 5초)라, 훅 timeout 을 넘기면 잃는 것은 맨 뒤의
     GC 뿐이다 — ② 는 이미 끝났고 GC 는 다음 SessionEnd 가 다시 돈다.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_SPEC_DISTILL_DISABLE=1                       - 전부 끈다
  DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd           - 이 훅 전체(② + ③)
  DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup  - 같은 훅을 훅명으로 지목
  DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc      - ③ 의 GC 만(GC 스크립트가 스스로 검사)
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "scripts"))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from gc_common import safe_rmtree  # noqa: E402 # pyright: ignore[reportMissingImports]
from hook_common import fire_and_forget_gc  # noqa: E402 # pyright: ignore[reportMissingImports]
from kill_switch_active import kill_switch_active  # noqa: E402


def cleanup_ending_session() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    except OSError as exc:
        print(f"[spec-distill] session-end-cleanup: stdin read error: {exc}", file=sys.stderr)
        return
    # SessionEnd targets the ending session (from payload), NOT the current
    # session (from CLAUDE_CODE_SESSION_ID env). Use payload directly — do not
    # use resolve_session_id which has env precedence.
    session_id = payload.get("session_id", "")
    if not session_id or not SESSION_PATTERN.match(session_id):
        return
    cwd = payload.get("cwd")
    if not cwd:
        print(
            "[spec-distill] session-end-cleanup: payload missing 'cwd', "
            "falling back to process cwd",
            file=sys.stderr,
        )
        cwd = os.getcwd()
    root = state_root(cwd)
    folder = root / session_id
    # `SESSION_PATTERN` 이 위에서 이미 charset 으로 걸렀지만 삭제는 두 겹으로 막는다 —
    # 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제로 이어지지 않도록.
    safe_rmtree(folder, root)


def main() -> int:
    if kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd"):
        return 0
    try:
        cleanup_ending_session()
    finally:
        fire_and_forget_gc()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_session_end_cleanup`
Expected: `OK` (16 tests).

- [ ] **Step 5: SessionEnd 훅을 띄우는 다른 테스트의 격리를 확인한다**

SessionEnd 훅을 실행하는 테스트는 이 파일 밖에 둘이다(`grep -rln session-end-cleanup plugins/spec-distill/tests` 로 확인한 전수: `test_brainstorming_entry.sh` · `test_kill_switches_v060.sh` · `test_brief_review_meta.sh` — 마지막은 파일 이름만 나열하고 실행하지 않는다). 둘 다 `mktemp -d` 로 만든 새 git 리포로 `cd` 한 뒤 훅을 부르므로 GC 루트가 그 임시 리포다. 코드 변경 없이 실행만 확인한다:

Run: `bash plugins/spec-distill/tests/test_kill_switches_v060.sh` → `Fail: 0`
Run: `bash plugins/spec-distill/tests/test_brainstorming_entry.sh` → `PASSED: 3 cases sequential`(Task 3 에서 이 파일을 다시 쓴다)

- [ ] **Step 6: CHANGELOG** — `[2.0.0]` 의 `### Added` 절 **뒤**에 넣는다:

```markdown
### Changed

- **TTL-GC 기동자가 SessionEnd 훅으로 옮겨왔다.** 그전의 유일한 기동자는 삭제된 Stop 훅이었다. `hooks/session-end-cleanup.py` 가 ① 자기 kill switch → ② 끝나는 세션의 폴더 삭제 → ③ `finally` 에서 `fire_and_forget_gc()` 순으로 돈다 — payload 가 JSON 이 아니거나 sid 가 없거나 stdin 디코딩이 실패해도 GC 는 돈다. 그래서 **`DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd`(와 `:session-end-cleanup`)는 이제 세션 정리와 TTL-GC 를 함께 끈다** — GC 만 끄려면 `spec-distill:spec-distill-gc`. GC 의 루트는 옛 훅과 같이 프로세스 cwd 의 state root 다. `fire_and_forget_gc` 는 이름과 달리 동기(timeout 5초)라 훅 timeout 을 넘기면 끊기는 것은 맨 뒤의 GC 뿐이다. `tests/test_session_end_cleanup.py` 의 `run_hook` 은 이제 `cwd` 를 필수로 받는다 — 비우면 러너 cwd 의 실제 상태 루트에서 GC 가 돈다.
```

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/hooks/session-end-cleanup.py plugins/spec-distill/tests/test_session_end_cleanup.py plugins/spec-distill/CHANGELOG.md
git commit -m "feat(spec-distill): TTL-GC 를 SessionEnd 훅의 finally 에서 기동" -m "kill switch → 세션 폴더 삭제 → finally GC. spec-distill:SessionEnd 가 두 층을 함께 끈다. 테스트 run_hook 은 cwd 필수(실제 상태 루트 GC 방지)." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 3: 훅과 훅 전용 코드 삭제

G1 · 설계 §1 · §2 #3 · #4(일부). 삭제와, 삭제된 파일에 기대던 락의 정리를 **한 커밋**으로 한다 — 둘을 가르면 중간 커밋에서 배선 락(`test_adjudication_wiring.sh`)의 면제 키가 stale 이 되어 RED 다. README 의 두 줄(`REDISPATCH_TTL` · `spec-distill:Stop`)도 여기서 뺀다: 훅이 사라지면 `spec-distill:review-dispatch` 가 kill switch 키 집합에서 빠져 `test_dispatch_name_defined.sh` 가 README `:227` 을 매달림으로 잡는다. README 의 나머지는 Task 7.

**Files:**
- Delete (spec-distill): `hooks/review-dispatch.py` · `scripts/arm_ledger.py` · `scripts/discover_candidates.py` · `scripts/parse_spec_structure.py` · `scripts/resolve_mode.py` · `scripts/ambiguity-blacklist.txt` · `templates/spec-template.md` · 테스트 13 · fixture 7 (Step 1 의 명령이 전수)
- Delete (shared): `shared/tests/fixtures/adjudication/block_disposition_decoy.py` · `run_block_disposition_count.py`
- Modify: `plugins/spec-distill/hooks/hooks.json` · `plugins/spec-distill/scripts/hook_common.py` (전면 교체 둘)
- Modify: `tools/adjudication/check_wiring.py` · `shared/tests/test_adjudication_wiring.sh` · `plugins/spec-distill/tests/test_stale_terms.sh` · `plugins/spec-distill/tests/test_brief_review_meta.sh` · `plugins/spec-distill/README.md` (편집 스크립트)
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` · `test_brainstorming_entry.sh` · `test_handoff_context_empty_subsections.sh` · `test_handoff_conversation_reference.sh` (전면 교체)
- Modify: `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 2 의 SessionEnd 훅(GC 기동자가 이미 옮겨 있어야 한다 — 이 Task 가 옛 기동자를 지운다).
- Produces: `hook_common` 에 남는 공개 이름은 `SCRIPTS_DIR` · `GC_SCRIPT` · `fire_and_forget_gc` · `_yaml_scalar`(+ 두 `_YAML_UNSAFE_*` 상수) 뿐이다. Task 8 의 오라클이 base 대비 빠진 최상위 이름(`LAST_DISPATCHED_RE` · `configure_utf8_streams` · `parse_iso` · `state_file_for`)을 삭제 식별자로 도출한다.

- [ ] **Step 1: 파일을 지운다**

```bash
git rm -q plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/scripts/arm_ledger.py plugins/spec-distill/scripts/discover_candidates.py plugins/spec-distill/scripts/parse_spec_structure.py plugins/spec-distill/scripts/resolve_mode.py plugins/spec-distill/scripts/ambiguity-blacklist.txt plugins/spec-distill/templates/spec-template.md plugins/spec-distill/tests/test_arm_ledger.py plugins/spec-distill/tests/test_arm_ledger_timing.sh plugins/spec-distill/tests/test_arm_once.sh plugins/spec-distill/tests/arm_test_helpers.sh plugins/spec-distill/tests/test_discover_candidates.py plugins/spec-distill/tests/test_discovery_driven_dispatch.py plugins/spec-distill/tests/test_parse_spec_structure.sh plugins/spec-distill/tests/test_resolve_mode_scope.sh plugins/spec-distill/tests/test_review_dispatch.sh plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh plugins/spec-distill/tests/test_review_dispatch_disposition.sh plugins/spec-distill/tests/test_stop_absorbs_validation.py plugins/spec-distill/tests/test_write_path_behavior.sh plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md plugins/spec-distill/tests/fixtures/spec-valid.md plugins/spec-distill/tests/fixtures/spec-missing-goals.md plugins/spec-distill/tests/fixtures/spec-ambiguity-line12.md plugins/spec-distill/tests/fixtures/spec-ambiguity-escaped.md plugins/spec-distill/tests/fixtures/design-no-frontmatter.md plugins/spec-distill/tests/fixtures/design-tbd.md shared/tests/fixtures/adjudication/block_disposition_decoy.py shared/tests/fixtures/adjudication/run_block_disposition_count.py
```

Run: `git status --porcelain | grep -c '^D '` → `29`

- [ ] **Step 2: `hooks/hooks.json` 전문 교체**

```json
{
  "description": "spec-distill — SessionEnd cleanup (ending session's state folder + TTL-GC).",
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: `scripts/hook_common.py` 전문 교체** — 훅 전용 넷(`LAST_DISPATCHED_RE` · `configure_utf8_streams` · `parse_iso` · `state_file_for`)과 그것만 쓰던 import(`re` · `datetime` · `timezone` · `Optional`)를 뺀다. 모듈 이름은 유지한다(`test_yaml_scalar_single_definition.py` 가 `hook_common` 이름을 핀한다).

```python
#!/usr/bin/env python3
"""spec-distill `hooks/` 와 `scripts/` 가 함께 쓰는 조각.

**사본이 아니다** — 같은 플러그인 안이므로 import 하나로 중복이 소멸한다. 배포 경로는
훅과 같은 플러그인 트리라 `${CLAUDE_PLUGIN_ROOT}/scripts/` 로 함께 실린다. `copy-of`
마커도 사본 동일성 검사도 붙지 않는다 — 지킬 두 번째 파일이 없다.

소비자:

  - `hooks/session-end-cleanup.py` 가 `fire_and_forget_gc` 를 쓴다.
  - `merge_review.py` · `merge_brief_review.py` · `brief_review_state.py` 가
    `_yaml_scalar` 을 쓴다(census #45의 spec-distill 부분).

**담지 않는 것** — `kill_switch_active`(`shared/killswitch/` 정본의 형제 사본에서
온다. 여기로 다시 가져오면 정본이 둘이 된다) · `resolve_session_id` / `state_root`
(`state_path.py` 소유).
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent

GC_SCRIPT = SCRIPTS_DIR / "spec-distill-gc.py"


def fire_and_forget_gc() -> None:
    """TTL-GC 를 best-effort 로 한 번 돌린다. 실패는 non-fatal 이되 조용하지 않다.

    훅의 본업이 아니므로 결과를 기다려 판단하지 않는다 — 다만 GC 가 멈춘 사실이
    보이지 않으면 상태 폴더가 조용히 쌓이므로, 두 실패 모드(비정상 rc · 실행 자체
    실패) 모두 stderr 로 낸다.
    """
    try:
        result = subprocess.run(
            ["python3", str(GC_SCRIPT)],
            timeout=5, check=False, capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(
                f"[spec-distill] GC exited rc={result.returncode}: {result.stderr.strip()}",
                file=sys.stderr,
            )
    except (subprocess.TimeoutExpired, OSError) as exc:
        print(
            f"[spec-distill] gc fire-and-forget failed (non-fatal): {exc}",
            file=sys.stderr,
        )


# `_yaml_scalar` 가 인용해야 하는 문자 — **두 축**이다. 이 두 상수는
# `shared/codex/codex_findings_to_yaml.py` 와 같은 값이어야 한다(정본과 이 소비자가
# 다른 인용 규칙을 쓰면 census #45 가 닫은 drift 가 되살아난다).
#
# _YAML_UNSAFE_ANYWHERE — 문자열 어디에 있어도 위험: 매핑 구분자 `:` · 주석 `#` ·
#   인용부호 · 개행 · flow collection 지시자 `[]{}`.
# _YAML_UNSAFE_FIRST — **첫 글자일 때만** 위험: block sequence `-` · complex key
#   `?` · tag `!` · anchor/alias `&`/`*` · directive `%` · block scalar `|`/`>` ·
#   flow 구분자 `,` · YAML 이 예약한 `@`/backtick.
#
# 두 집합은 상상이 아니라 전수 측정으로 얻었다(2026-08-19, PyYAML 6.0.3): 첫 글자를
# 0x20–0x7E 전부로 돌려 `k: <값>` 을 파싱했을 때 깨진 첫 글자는
# ` !"#%&'*,-:>?@[]`{|}` 였다. 그 중 ANYWHERE 와 앞뒤 공백 검사(`s.strip() != s`)
# 가 이미 덮는 것을 뺀 잔여가 FIRST 다. 합집합(문자 멤버십)만으로는 `- ` 로 시작하는
# 값이 ScannerError 로 죽는 잔여 구멍이 남아 있었다 — 위치 축이 별도로 필요하다.
_YAML_UNSAFE_ANYWHERE = ":#\"'\n[]{}"
_YAML_UNSAFE_FIRST = "!%&*,->?@|`"
```

그 아래 `def _yaml_scalar(v) -> str:` 함수는 **현재 파일의 134–173 줄을 한 글자도 바꾸지 않고** 그대로 붙인다(Read 로 옮긴다 — docstring 포함). 교체 뒤:

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_yaml_scalar_single_definition`
Expected: `OK`.

- [ ] **Step 4: 편집 스크립트를 쓴다** — Write 도구로 `.claude/plan-baseline/task3_edits.py`. 모든 치환은 **정확히 1회** 매치를 요구하고, 아니면 아무것도 쓰지 않고 죽는다.

```python
"""Task 3 편집 — check_wiring · 배선 락 주석 · stale_terms · brief_review_meta · README.

사용: python3 .claude/plan-baseline/task3_edits.py   (워크트리 루트에서)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(".").resolve()
texts = {}


def load(rel):
    if rel not in texts:
        texts[rel] = (ROOT / rel).read_text(encoding="utf-8")
    return texts[rel]


def replace(rel, old, new):
    s = load(rel)
    n = s.count(old)
    if n != 1:
        sys.exit(f"[중단] {rel}: 치환 대상이 {n}회 — 정확히 1회여야 한다:\n{old[:120]!r}")
    texts[rel] = s.replace(old, new)


def cut(rel, start, end):
    """start 줄부터 end(포함)까지 지운다. start 는 정확히 1회, end 는 start 뒤 첫 매치."""
    s = load(rel)
    if s.count(start) != 1:
        sys.exit(f"[중단] {rel}: 시작 앵커가 {s.count(start)}회: {start[:80]!r}")
    i = s.index(start)
    j = s.find(end, i)
    if j < 0:
        sys.exit(f"[중단] {rel}: 끝 앵커 없음: {end[:80]!r}")
    texts[rel] = s[:i] + s[j + len(end):]


CW = "tools/adjudication/check_wiring.py"
# A. 삭제된 훅의 선택·검증 루프 사유 상수 다섯과 그 머리 주석.
cut(CW, "# Task 11 (T5) — 훅에 `from adjudication import Ledger` 를 더하면서\n",
    '    "처분 개념이 없다."\n)\n\n')
# B. EXEMPT 의 훅 열 자리(선택 루프 7 · 검증 루프 3)와 그 주석.
cut(CW, "    # Task 11 (T5) — select_dispatch_target() 의 선택 루프 7 자리.\n",
    "        _T5_MAIN_VALIDATION_LOOP_SUCCESS,\n\n")
# C. TERMINAL_CONSUMERS 의 훅 항목.
cut(CW, '    "plugins/spec-distill/hooks/review-dispatch.py":\n',
    '        "원리적으로 없다.",\n')
# D. 남는 사유 문자열 셋이 삭제된 훅을 「같은 범주」로 인용한다 — 인용만 걷는다.
replace(CW,
    '    "로 떨어진다 — 어느 쪽도 판정 대상 항목을 버리지 않는다. review-dispatch.py "\n'
    '    "의 `select_dispatch_target()` 선택 루프(같은 파일 위 `_T5_SELECT_LOOP`)와 "\n'
    '    "같은 범주: 처분을 낼 대상 자체가 없는 탐색 루프다."\n',
    '    "로 떨어진다 — 어느 쪽도 판정 대상 항목을 버리지 않는다. 처분을 낼 "\n'
    '    "대상 자체가 없는 탐색 루프다."\n')
replace(CW,
    '    "사라지지 않는다(review-dispatch.py 의 `capped.append` 선행 대입과 같은 "\n'
    '    "모양 — continue 이전에 보존이 먼저 실행된다)."\n',
    '    "사라지지 않는다(continue 이전에 보존이 먼저 실행된다)."\n')
replace(CW,
    '    "review-dispatch.py 의 `_T5_SELECT_LOOP`(discover() 가 매 Stop 재스캔) 와 "\n'
    '    "같은 범주: 이번 라운드에 못 골랐다고 사라지는 게 아니라 다음 라운드의 "\n',
    '    "이번 라운드에 못 골랐다고 사라지는 게 아니라 다음 라운드의 "\n')
replace(CW,
    "    # PR1 배선 baseline=14, T1-A/T1-B 가 review-dispatch.py 열을 닫아 남긴 게\n",
    "    # PR1 배선 baseline=14, T1-A/T1-B 가 (삭제된) 설계문서 리뷰 훅 열을 닫아 남긴 게\n")
replace(CW,
    "# 전부 어딘가 dispatch 자리에서 `consumer=` 로 불린다\")은 PR1 이 넣은 것이고\n"
    "# review-dispatch.py 가 그 반례다: 앵커(`consumer=`)는 skill/command/agent\n"
    "# 문서가 \"이 subagent 의 발견물을 이 스크립트가 판정한다\"고 선언하는 자리인데,\n"
    "# 훅은 subagent dispatch 결과를 받는 소비자가 아니라 **그 자신이** 직접\n"
    "# `decision:\"block\"` 으로 차단/통과를 정하는 **종단(terminal) 결정자**다 —\n"
    "# 이름 붙일 dispatch 자리 자체가 없다. 없는 자리를 만들어 붙이면 그건 허구다.\n",
    "# 전부 어딘가 dispatch 자리에서 `consumer=` 로 불린다\")은 PR1 이 넣은 것이다.\n"
    "# 앵커(`consumer=`)는 skill/command/agent 문서가 \"이 subagent 의 발견물을 이\n"
    "# 스크립트가 판정한다\"고 선언하는 자리인데, 원장을 import 하면서도 그렇게 불릴\n"
    "# dispatch 자리가 없는 파일이 있다(아래 항목마다 사유). 없는 자리를 만들어\n"
    "# 붙이면 그건 허구다. 첫 반례였던 설계문서 리뷰 훅(스스로 차단/통과를 정하던\n"
    "# 종단 결정자)은 spec-distill 2.0.0 에서 삭제됐다.\n")
replace(CW,
    "    # 순수 재사용 라이브러리로 변했다. review-dispatch.py 처럼 «원리적으로»\n",
    "    # 순수 재사용 라이브러리로 변했다. 종단 결정자처럼 «원리적으로»\n")

AW = "shared/tests/test_adjudication_wiring.sh"
replace(AW,
    "                   # 들어온 review-dispatch.py 자신의 컴프리헨션 넷: `raw.split`\n"
    "                   # 토큰 집합·필터(:145-146, DEVBREW_SKIP_HOOKS 파싱)와 회전\n"
    "                   # 커서 계산·선택(:270-271, select_keys 의 라운드로빈). 넷 다\n"
    "                   # 설정 파싱·목록 회전이지 처분 대상을 버리는 자리가 아니다\n"
    "                   # (코드 확인 완료).\n",
    "                   # 들어온 설계문서 리뷰 훅 자신의 컴프리헨션 넷(토큰 파싱 둘 ·\n"
    "                   # 목록 회전 둘). 넷 다 처분 대상을 버리는 자리가 아니었다.\n"
    "                   # 그 훅은 spec-distill 2.0.0 에서 삭제됐다(아래 재계수).\n")

ST = "plugins/spec-distill/tests/test_stale_terms.sh"
replace(ST, "templates/scripts/plugin.json 뿐 아니라 scripts/ambiguity-blacklist.txt 같은 .txt/.yaml/",
            "templates/scripts/plugin.json 뿐 아니라 scripts/codex-killswitch.conf 같은 .conf/.yaml/")
replace(ST, "# (whitelist는 scripts/ambiguity-blacklist.txt 같은 .txt production 파일을 놓쳐",
            "# (whitelist는 scripts/codex-killswitch.conf 같은 비-.md/.py production 파일을 놓쳐")
# V11 — 삭제된 원장·훅의 존재를 요구하던 양성 락. 대상이 사라졌다.
cut(ST, "# --- V11 (v0.25.0): 대체 surface 가 실재한다",
    '  || no "V11: Stop 훅의 armed 판정이 소비 위치에 없다 (주석/neutered 호출 의심 — 게이트 증발)"\n')

BM = "plugins/spec-distill/tests/test_brief_review_meta.sh"
replace(BM, 'EXPECTED="hooks.json review-dispatch.py session-end-cleanup.py"',
            'EXPECTED="hooks.json session-end-cleanup.py"')
replace(BM, '"T18: hooks/ 집합이 고정 열거와 정확히 일치 (3개)"',
            '"T18: hooks/ 집합이 고정 열거와 정확히 일치 (2개)"')

RM = "plugins/spec-distill/README.md"
replace(RM,
    "- `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>` (v0.3.0) — Stop hook redispatch TTL guard (default 30초). spec self-reference cycle 방지용. plan phase에서 default 값 재검토.\n"
    "- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` (alias: `spec-distill:review-dispatch`) — Stop hook만 skip.\n",
    "")

for rel, s in texts.items():
    (ROOT / rel).write_text(s, encoding="utf-8")

LEFT = re.compile(r"review-dispatch|select_dispatch_target|_T5_|arm_ledger|is_inflight|"
                  r"record_attempt|flush_advisory|with_advisory|resolve_mode|"
                  r"DISPATCH_ATTEMPT_CAP|VALIDATION_ATTEMPT_CAP|select_keys|ambiguity-blacklist")
bad = [f"{rel}:{i}: {ln.strip()[:100]}" for rel in (CW, AW, ST, BM)
       for i, ln in enumerate((ROOT / rel).read_text(encoding="utf-8").splitlines(), 1)
       if LEFT.search(ln)]
print("\n".join(bad) if bad else "잔존 0")
sys.exit(1 if bad else 0)
```

- [ ] **Step 5: 편집 스크립트를 돌린다**

Run: `python3 .claude/plan-baseline/task3_edits.py`
Expected: `잔존 0`. `[중단]` 이 나오면 대상 파일의 그 자리를 Read 로 보고 앵커를 현재 텍스트에 맞춘 뒤 다시 돈다(스크립트는 중단 시 아무것도 쓰지 않는다). 잔존 줄이 나오면 그 줄을 같은 방식(인용만 걷기)으로 손으로 고친다.

Run: `python3 -c 'import ast,sys; ast.parse(open("tools/adjudication/check_wiring.py",encoding="utf-8").read()); print("ok")'` → `ok`

- [ ] **Step 6: baseline 을 재계수한다** — Write 도구로 `.claude/plan-baseline/task3_recount.py`:

```python
"""삭제 뒤 배선 스캔을 돌려 EXEMPT_BASELINE · COMP_BASELINE 을 재계수 값으로 쓴다."""
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(".").resolve()
out = subprocess.run(
    ["python3", "shared/tests/fixtures/adjudication/run_wiring_scan.py", str(ROOT)],
    capture_output=True, text=True, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
).stdout
vals = dict(re.findall(r"^(exempt_total|comprehensions|unwired|exempt_stale|terminal_stale)=(\d+)$",
                       out, re.M))
print(vals)
if set(vals) != {"exempt_total", "comprehensions", "unwired", "exempt_stale", "terminal_stale"}:
    sys.exit("[중단] 스캔 출력에서 다섯 값을 다 못 뽑았다:\n" + out[-2000:])
if vals["unwired"] != "0" or vals["exempt_stale"] != "0" or vals["terminal_stale"] != "0":
    sys.exit("[중단] 미배선·낡은 면제가 남았다 — 재계수 전에 고쳐라:\n" + out[-2000:])
ex, comp = int(vals["exempt_total"]), int(vals["comprehensions"])

cw = ROOT / "tools/adjudication/check_wiring.py"
s = cw.read_text(encoding="utf-8")
old = "# 직접 읽어라.\nEXEMPT_BASELINE = 27\n"
if s.count(old) != 1:
    sys.exit("[중단] check_wiring.py 의 EXEMPT_BASELINE 자리를 못 찾았다")
s = s.replace(old, (
    "# 직접 읽어라.\n"
    "#\n"
    f"# spec-distill 2.0.0 — 27 → {ex}. 설계문서 리뷰 훅이 삭제되며 그 파일의 면제 열 자리가\n"
    "# 대상과 함께 사라졌다. 줄인 것이지 면제로 옮긴 것이 아니다 — 값은 손으로 빼지 않고\n"
    "# 삭제 뒤 스캔의 `exempt_total` 로 재계수했다.\n"
    f"EXEMPT_BASELINE = {ex}\n"))
cw.write_text(s, encoding="utf-8")

aw = ROOT / "shared/tests/test_adjudication_wiring.sh"
t = aw.read_text(encoding="utf-8")
if t.count("COMP_BASELINE=58   #") != 1:
    sys.exit("[중단] COMP_BASELINE=58 자리를 못 찾았다")
t = t.replace("COMP_BASELINE=58   #", f"COMP_BASELINE={comp}   #")
anchor = "                   # 라벨로 그대로 대응된다 — 버려지는 원소가 없다.\n"
if t.count(anchor) != 1:
    sys.exit("[중단] COMP 주석 끝 앵커를 못 찾았다")
t = t.replace(anchor, anchor + (
    f"                   # spec-distill 2.0.0 이 {58 - comp} 줄인다(58→{comp}) — 설계문서\n"
    "                   # 리뷰 훅이 삭제되며 그 파일의 컴프리헨션이 모집단에서 빠졌다.\n"
    "                   # 값은 삭제 뒤 스캔의 `comprehensions=` 로 재계수했다.\n"))
aw.write_text(t, encoding="utf-8")
print(f"EXEMPT_BASELINE={ex} COMP_BASELINE={comp}")
```

Run: `python3 .claude/plan-baseline/task3_recount.py`
Expected: `EXEMPT_BASELINE=17 COMP_BASELINE=54` 근처. **값이 17·54 가 아니면** 그 차이를 스캔 출력에서 설명할 수 있는지 보고 커밋 메시지에 적는다(예상치는 교차 확인용이지 정답이 아니다).

Run: `bash shared/tests/test_adjudication_wiring.sh` → `Fail: 0`

- [ ] **Step 7: `tests/test_hook_output_schema.py` 전문 교체** — 훅을 실행하던 여섯 클래스와 `TestRetiredSwitchAdvisory`(Task 1 의 `test_review_entry.py` 로 옮겨 갔다)를 지우고 `state_path` 만 쓰는 `TestCrossResolverAdvisory` 를 남긴다. `TestInterviewDirectionLayerScope` 는 두 케이스 모두 `_run_hook("review-dispatch.py", …)` 만 실행하므로(현재 파일 920–975 줄에서 확인) 함께 지운다.

```python
#!/usr/bin/env python3
"""NG9 — Python `state_path.state_root()` 와 bash `CLAUDE_PROJECT_DIR` resolver 의 일치.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_hook_output_schema
"""
from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "scripts"


def _in_worktree() -> bool:
    """Detect git worktree (vs main repo) via .git file (not dir)."""
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=REPO_ROOT, capture_output=True, text=True, timeout=3, check=False,
        )
        if cp.returncode != 0 or cp.stdout.strip() != "true":
            return False
        # main repo has .git/ dir; worktree has .git file pointing to gitdir.
        dot_git = REPO_ROOT / ".git"
        return dot_git.is_file()
    except (OSError, subprocess.TimeoutExpired):
        return False


class TestCrossResolverAdvisory(unittest.TestCase):
    """NG9 — Python state_path vs bash CLAUDE_PROJECT_DIR resolver consistency.

    Skips if not running inside a worktree (the cross-resolver mismatch only
    manifests there). PASS = both resolvers point to the same dir; FAIL = the
    follow-up unification PR is needed.
    """

    @unittest.skipUnless(_in_worktree(), "cross-resolver test runs only inside a git worktree")
    def test_python_and_bash_resolvers_agree(self):
        # Python resolver: state_path.state_root()
        sys.path.insert(0, str(SCRIPTS_DIR))
        try:
            import state_path  # type: ignore
            py_root = state_path.state_root()
        finally:
            sys.path.pop(0)
        # Bash resolver: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill
        bash_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) \
            / ".claude" / "spec-distill"
        self.assertEqual(
            py_root.resolve(), bash_root.resolve(),
            msg=(
                "Python state_path and bash CLAUDE_PROJECT_DIR resolvers disagree. "
                "Follow-up PR per spec NG9 needed."
            ),
        )


if __name__ == "__main__":
    unittest.main()
```

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_hook_output_schema`
Expected: 워크트리에서 1 test FAIL(선재 RED — Task 0 `REASONS.md` 에 있는 그것). main 체크아웃에서는 skip.

- [ ] **Step 8: `tests/test_brainstorming_entry.sh` 전문 교체** — 옛 (i)(ii)는 Stop 훅이 상태 파일을 쓰는 것을 쟀다. 남는 성질은 「`/interview` 없이 들어온 세션의 상태 폴더도 SessionEnd 가 payload 의 sid 로 치운다」다.

```bash
#!/usr/bin/env bash
# AC9 — /interview 없이 들어온 세션(brainstorming 직접 진입)의 상태 폴더도 SessionEnd 가 치운다.
# sid 는 payload 에서만 온다 — 두 env 를 지우는 것이 이 케이스의 요지다(/interview 없이
# 들어온 세션은 하니스 payload 의 session_id 밖에 없다).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
END="$PLUGIN_DIR/hooks/session-end-cleanup.py"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q

SID="brainstorm-12345678"
STATE_DIR="$WORK/.claude/spec-distill/$SID"
mkdir -p "$STATE_DIR"
echo "x" > "$STATE_DIR/docreview-state.md"

# (i) Setup — reviewing-spec 이 엔진 상태를 쓰는 세션 상태 디렉토리가 있다.
[[ -f "$STATE_DIR/docreview-state.md" ]] \
    && echo "[PASS] case i: session state dir present (sid=$SID)" \
    || { echo "[FAIL] case i: setup failed"; exit 1; }

# (ii) Cleanup — SessionEnd 훅이 payload 의 sid 로 그 폴더를 지운다. cwd 가 $WORK 라
# 같은 훅이 기동하는 TTL-GC 도 이 임시 리포의 상태 루트만 돈다.
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID python3 "$END" >/dev/null 2>&1

[[ ! -d "$STATE_DIR" ]] \
    && echo "[PASS] case ii: SessionEnd cleanup removed folder" \
    || { echo "[FAIL] case ii: folder still exists"; exit 1; }

echo "PASSED: 2 cases sequential"
```

- [ ] **Step 9: 두 handoff 락을 리뷰어 쪽으로 재조준한다**

`plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` 전문:

```bash
#!/usr/bin/env bash
# AC3 — design doc 의 Handoff Context 계약이 리뷰어 쪽에 실재한다.
#
# 재는 것 — design 자리 프로필(`references/docreview-profiles/design-doc.md`):
#   · `defer_target` 이 `### Deferred to plan` 을 이름으로 가리킨다. 엔진이 `defer` 처분을 실제로
#     적어 넣는 자리이고, 이름이 갈라지면 `defer` 가 문서에 없는 절을 가리킨다.
#   · 층 2 의 `handoff_incomplete` rubric 줄이 Handoff Context 를 이름으로 댄다.
#
# 재지 못하는 것 — 저자 쪽 지시. Handoff Context 를 `TL;DR` · `Implicit context` · `Deferred to plan`
# 세 하위 항목으로 쓰라는 기계 앵커는 spec-distill 2.0.0 에서 템플릿과 함께 사라졌다
# (brainstorming 은 그 템플릿을 읽지 않았다). 앞의 두 라벨은 이제 어디서도 기계로 재지 않는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$REPO_ROOT/shared/tests/assert.sh"

[[ -f "$PROFILE" ]] && ok "AC3: 대상 실재 — ${PROFILE#"$REPO_ROOT/"}" \
                    || { no "AC3: 대상 부재 — ${PROFILE#"$REPO_ROOT/"}"; finish; exit; }

DEFER="$(sed -n 's/^[[:space:]]*defer_target:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -z "$DEFER" ]]; then
  no "AC3: 프로필에서 defer_target 을 추출하지 못했다"
elif printf '%s' "$DEFER" | grep -qF 'Deferred to plan'; then
  ok "AC3: 프로필 defer_target 이 'Deferred to plan' 을 이름으로 가리킨다 ($DEFER)"
else
  no "AC3: 프로필 defer_target 이 'Deferred to plan' 이 아니다 ($DEFER) — defer 가 문서에 없는 절로 간다"
fi

BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
RUBRIC="$(printf '%s\n' "$BODY2" | grep -F 'handoff_incomplete' | head -1)"
if [[ -z "$BODY2" ]]; then
  no "AC3: 프로필의 '## 층 2' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif [[ -z "$RUBRIC" ]]; then
  no "AC3: 층 2 본문에 handoff_incomplete rubric 줄이 없다"
elif printf '%s' "$RUBRIC" | grep -qF 'Handoff Context'; then
  ok "AC3: handoff_incomplete rubric 이 Handoff Context 를 이름으로 댄다"
else
  no "AC3: handoff_incomplete rubric 이 Handoff Context 를 대지 않는다 ($RUBRIC)"
fi
finish
```

`plugins/spec-distill/tests/test_handoff_conversation_reference.sh` 전문:

```bash
#!/usr/bin/env bash
# AC4 — 「대화 컨텍스트 의존」 축이 design 자리에서 살아 있는가 — 리뷰어 쪽.
#
# 재는 것: 프로필 층 2 의 `handoff_incomplete` rubric 이 `/compact` 뒤 남은 암묵 컨텍스트를
# 발화 조건으로 이름 댄다.
#
# 재지 못하는 것: 저자 쪽 지시(「대화 컨텍스트를 가정하지 말라」). 그 앵커였던 템플릿이
# spec-distill 2.0.0 에서 삭제됐다 — 이 성질은 이제 리뷰어가 결함으로 잡는 쪽에만 남는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$REPO_ROOT/shared/tests/assert.sh"

[[ -f "$PROFILE" ]] && ok "AC4: 대상 실재 — ${PROFILE#"$REPO_ROOT/"}" \
                    || { no "AC4: 대상 부재 — ${PROFILE#"$REPO_ROOT/"}"; finish; exit; }

# 창은 「## 층 2」 절이다. frontmatter 의 카테고리 목록 한 줄로는 만족되지 않는다
# (그 줄에는 산문이 없다) — header-satisfiable 회피.
BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
if [[ -z "$BODY2" ]]; then
  no "AC4: 프로필의 '## 층 2' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
else
  RUBRIC="$(printf '%s\n' "$BODY2" | grep -F 'handoff_incomplete' | head -1)"
  if [[ -z "$RUBRIC" ]]; then
    no "AC4: 층 2 본문에 handoff_incomplete rubric 줄이 없다"
  elif printf '%s' "$RUBRIC" | grep -qF '/compact' \
       && printf '%s' "$RUBRIC" | grep -qE '암묵 컨텍스트|implicit context'; then
    ok "AC4: 프로필 rubric 이 '/compact 뒤 남은 암묵 컨텍스트'를 발화 조건으로 이름 댄다"
  else
    no "AC4: handoff_incomplete rubric 이 대화 컨텍스트 의존 축을 잃었다 ($RUBRIC)"
  fi
fi
finish
```

- [ ] **Step 10: 영향 받는 락을 돌린다**

각각 따로 실행한다(한 명령씩):
- `bash shared/tests/test_adjudication_wiring.sh` → `Fail: 0`
- `bash shared/tests/test_dispatch_name_defined.sh` → `Fail: 0`
- `bash shared/tests/test_adjudication_consumed.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_stale_terms.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_brief_review_meta.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_brainstorming_entry.sh` → `PASSED: 2 cases sequential`
- `bash plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` · `test_handoff_conversation_reference.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_hooks.sh` · `test_kill_switches_v060.sh` · `test_no_write_matcher_hooks_repo.sh` → `Fail: 0`
- `cd plugins/spec-distill/tests && python3 -m unittest -v test_session_end_cleanup test_review_entry test_yaml_scalar_single_definition test_gc` → `OK`

- [ ] **Step 11: CHANGELOG** — `[2.0.0]` 의 `### Changed` 절 **뒤**에 넣는다:

```markdown
### Removed

- **`hooks/review-dispatch.py`(Stop 훅)와 `hooks/hooks.json` 의 `Stop` 항목.** 발견(`git status` 로 dirty·untracked 문서) → Layer 1 구조 검증 → 다음 턴 `reviewing-spec` 강제의 셋이 함께 사라진다.
- **그 훅만 쓰던 코드**: `scripts/arm_ledger.py`(arm 원장 — 같은 문서의 반복 강제를 막던 `armed_paths` · `inflight_paths` · `dispatch_attempts`) · `scripts/discover_candidates.py`(발견) · `scripts/parse_spec_structure.py` + `scripts/ambiguity-blacklist.txt`(구조 검증 — placeholder 4토큰 · 영어 모호어 10개 · spec 모드 필수 섹션) · `scripts/resolve_mode.py`(content-aware 모드 판정) · `templates/spec-template.md` · `scripts/hook_common.py` 의 `LAST_DISPATCHED_RE` · `parse_iso` · `state_file_for` · `configure_utf8_streams`.
- **`state.local.md` 필드**: `last_dispatched_at` · `armed_paths` · `inflight_paths` · `dispatch_attempts` · `validation_attempts` · `discovery_cursor` · `git_unavailable_advised` · `retired_token_advised`.
- **환경변수 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`** — 끄기 스위치가 아니라 조율 값이라 advisory 대상이 아니다. README 스위치 목록에서도 뺐다.
- **테스트 13 · fixture 9** — 삭제된 코드만 재던 것(`test_arm_ledger.py` · `test_arm_ledger_timing.sh` · `test_arm_once.sh` · `arm_test_helpers.sh` · `test_discover_candidates.py` · `test_discovery_driven_dispatch.py` · `test_parse_spec_structure.sh` · `test_resolve_mode_scope.sh` · `test_review_dispatch.sh` · `test_review_dispatch_design_mandate.sh` · `test_review_dispatch_disposition.sh` · `test_stop_absorbs_validation.py` · `test_write_path_behavior.sh`, fixture 는 이들만 쓰던 7개 + `shared/tests/fixtures/adjudication/` 의 둘). `test_hook_output_schema.py` 는 NG9 cross-resolver 케이스만 남는다 — 은퇴 스위치 케이스는 `test_review_entry.py` 로 옮겼다. `test_stale_terms.sh` V11(원장·훅 본문의 존재 요구)은 대상과 함께 지웠다.
- **공용 도구의 삭제된 훅 항목** — `tools/adjudication/check_wiring.py` 의 `EXEMPT` 열 자리 · `TERMINAL_CONSUMERS` 한 항목 · 사유 상수 다섯. `EXEMPT_BASELINE` 과 `test_adjudication_wiring.sh` 의 `COMP_BASELINE` 은 삭제 뒤 스캔으로 재계수했다.
```

그리고 `### Changed` 절 끝에 한 항목을 더한다:

```markdown
- **Handoff Context 두 락이 리뷰어 쪽만 잰다.** `test_handoff_context_empty_subsections.sh` · `test_handoff_conversation_reference.sh` 는 저자 쪽 계약의 정답 출처로 `templates/spec-template.md` 를 썼다. 템플릿이 사라져 두 락은 `design-doc.md` 프로필(`defer_target` · `handoff_incomplete` rubric)만 잰다. **잃은 것**: Handoff Context 를 `TL;DR` · `Implicit context` · `Deferred to plan` 세 항목으로 쓰라는 저자 지시와 「대화 컨텍스트 가정 금지」 지시의 기계 앵커. brainstorming 은 그 템플릿을 읽지 않았으므로 실제 저자에게 닿던 지시는 아니었다.
```

- [ ] **Step 12: 커밋**

```bash
git add -A plugins/spec-distill shared/tests tools/adjudication
git status --porcelain
```

`git status --porcelain` 출력이 이 Task 의 Files 목록과 삭제 29건뿐인지 본다(`.claude/` 는 무시돼 나오지 않는다). 그다음:

```bash
git commit -m "refactor(spec-distill)!: 설계문서 리뷰 Stop 훅과 훅 전용 코드 삭제" -m "review-dispatch.py · arm_ledger · 발견 · 구조 검증 · resolve_mode · spec-template 과 그것만 재던 테스트 13·fixture 9 를 지운다. check_wiring 의 훅 항목을 걷고 baseline 을 재계수했다. handoff 두 락은 리뷰어 쪽만 잰다 — 저자 쪽 Handoff Context 앵커(세 라벨 · 대화 컨텍스트 가정 금지)는 템플릿과 함께 잃었다." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 4: reviewing-spec 진입 계약

AC6 · AC7 · AC9 · AC16(행동) · 설계 §3.2 · §4. `reviewing-spec/SKILL.md` 를 다시 쓴다: 경로는 호출 인자, 인자 없으면 후보 선택, `mode:` 슬롯·`$STATE`·`## 원장` 삭제, 리터럴 진입 펜스(fail-closed), 원장 없는 미커밋 펜스, 게이트 없는 두 경로의 복귀 지시, description.

**다른 락이 이 파일에서 요구하는 것 — 새 본문이 지켜야 한다** (현재 락을 읽어 확인한 전수):
- `test_reviewing_spec_disclosure.sh` — `<!-- codex-gate:end -->` 부터 다음 `## ` 까지의 창에 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` · `DEVBREW_SPEC_DISTILL_DISABLE=1` · `캐시하지 않` / `## degrade 채널` 절에 `advisory[]` · `blocks` · `gate --render` · `codex 부재`.
- `test_proceed_gate_adopters.sh` — 표면에 `턴 종료|다음 턴` · `polite stop` · `degrade 채널` · `재결정|반증`.
- `test_rereview_cap_consistency.sh` — 상한 어휘 줄의 숫자가 정본(2)과 같다.
- `test_reviewing_spec_residue.sh` · qg `test_codex_gate_observation.sh` — codex 게이트 펜스(마커 포함)가 그대로 돈다.
- `test_conducting_interview_internal.sh` — `conducting-interview` 가 본문에 있다. qg `test_skill_plugin_root_fallback.sh` — `CLAUDE_PLUGIN_ROOT:-` 가 있다.
- `test_no_wall_clock.sh` — `wall-clock` 류 토큰이 없다. `shared/tests/test_dispatch_disposition.sh` · `test_agent_input_slots.sh` — dispatch 블록 둘과 처분 줄이 그대로다.

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (전면 교체)
- Create: `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh` (전면 교체)
- Modify: `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` (부분)
- Modify: `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1 의 `review_entry.py` JSON 계약.
- Produces: SKILL 의 마커 넷 — `<!-- review-entry:begin -->` · `<!-- review-entry:end -->` · `<!-- uncommitted-check:begin -->` · `<!-- uncommitted-check:end -->`. 진입 펜스 출력의 **마지막 줄**이 `review-entry: PROCEED` 또는 `review-entry: DISABLED:<사유>`. Task 5 와 Task 8 이 이 마커와 절 이름(`## 입력` · `### 대상 부재` · `## 진입 검사` · `## 프로필` · `### 미커밋 확인`)에 기댄다.

- [ ] **Step 1: 실패하는 펜스 테스트를 쓴다** — `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/scripts/review_entry.py plugins/spec-distill/scripts/kill_switch_active.py
#
# AC6 · AC9 · AC16 — `reviewing-spec` 의 두 리터럴 펜스를 **잘라내 실행**한다.
#
#   · 진입 펜스(`review-entry:begin` ~ `:end`) — `review_entry.py` 의 출력을 스키마로 검사해
#     마지막 줄에 판결(`review-entry: PROCEED` | `review-entry: DISABLED:<사유>`)을 낸다.
#     모듈 부재 · rc≠0 · 비-JSON · 스키마 위반이면 전부 DISABLED(fail-closed)이고, PROCEED 가
#     아닌 판결 앞에는 복귀 지시가 나와야 한다(AC16).
#   · 미커밋 펜스(`uncommitted-check:begin` ~ `:end`) — 깨끗함 · 미커밋 · untracked · 작업 트리
#     밖 · 상대 경로를 가른다. 출력이 비었다는 이유로 깨끗함으로 읽지 않는다(AC9).
#
# 판정은 리터럴의 존재가 아니라 **실행한 펜스의 출력**이다 — 산문·주석은 이 판정을 만족시킬
# 수 없다. 재지 못하는 것: 모델이 판결 줄대로 분기하는가(산문 지시 — AC14 수동 e2e 몫).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
SD_SCRIPTS="$ROOT/plugins/spec-distill/scripts"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/scripts/review_entry.py"
  echo "plugins/spec-distill/scripts/kill_switch_active.py"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-entry-fence-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

RETURN_MSG='[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'
PY_DIR="$(dirname "$(command -v python3)")"

extract() {   # extract <begin-marker> <end-marker> <out>
  awk -v b="$1" -v e="$2" '
    index($0, b) {ing=1; next}
    index($0, e) {ing=0}
    ing && /^```bash$/ {inb=1; next}
    ing && inb && /^```$/ {inb=0; next}
    ing && inb {print}
  ' "$SKILL" > "$3"
}
check_fence() {   # check_fence <라벨> <파일> <최소 줄 수> — 계측기 바닥
  local n; n="$(grep -c . "$2" || true)"
  if [ "${n:-0}" -lt "$3" ]; then
    no "추출($1): ${n:-0}줄 — 마커가 사라졌거나 추출이 깨졌다. 아래 판정은 무의미하다"
    return 1
  fi
  ok "추출($1): ${n}줄"
  if bash -n "$2" 2>/dev/null; then ok "추출($1): bash -n 통과"; else no "추출($1): bash -n 실패"; fi
}

ENTRY_FENCE="$SCRATCH/entry.sh"
extract '<!-- review-entry:begin -->' '<!-- review-entry:end -->' "$ENTRY_FENCE"
check_fence "진입" "$ENTRY_FENCE" 15 || { finish; exit; }

# ── 가짜 플러그인 루트 — scripts/review_entry.py 를 케이스마다 갈아 끼운다 ────────
PR="$SCRATCH/plugin"
mkdir -p "$PR/scripts"
stub() {   # stub <stdout 문자열> <rc>
  python3 -c '
import sys
path, out, rc = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(path, "w", encoding="utf-8") as f:
    f.write("import sys\nsys.stdout.write(%r)\nsys.exit(%d)\n" % (out, rc))
' "$PR/scripts/review_entry.py" "$1" "$2"
}
run_entry_fence() {   # run_entry_fence [VAR=값 …] → 펜스 stdout
  ( cd "$SCRATCH" && env -i PATH="/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" \
      PYTHONDONTWRITEBYTECODE=1 CLAUDE_PLUGIN_ROOT="$PR" "$@" bash "$ENTRY_FENCE" ) 2>/dev/null
}
expect_verdict() {   # expect_verdict <라벨> <기대 판결> <펜스 출력>
  local label="$1" want="$2" out="$3" got n
  got="$(printf '%s\n' "$out" | grep -E '^review-entry: ' || true)"
  n="$(printf '%s' "$got" | grep -c . || true)"
  if [ "$n" != "1" ]; then
    no "$label: 판결 줄이 정확히 하나가 아니다 (${n}줄) — 출력: $(printf '%s' "$out" | head -c 300)"
    return
  fi
  if [ "$(printf '%s\n' "$out" | tail -n 1)" != "$got" ]; then
    no "$label: 판결 줄이 마지막 줄이 아니다"
    return
  fi
  assert_eq "$got" "$want" "$label: 판결"
  if [ "$want" = "review-entry: PROCEED" ]; then
    assert_not_contains "$out" "$RETURN_MSG" "$label: PROCEED 에는 복귀 지시가 없다"
  else
    assert_contains "$out" "$RETURN_MSG" "$label: 게이트 없이 끝나는 판결 앞에 복귀 지시 (AC16)"
  fi
}

# ── AC6: 모듈 부재 ────────────────────────────────────────────────────────────
rm -f "$PR/scripts/review_entry.py"
out="$(run_entry_fence)"
expect_verdict "모듈 부재" "review-entry: DISABLED:entry_check_failed" "$out"
assert_contains "$out" "모듈 부재" "모듈 부재: 실패 사유를 advisory 로 댄다"

# ── AC6: 스텁 행렬 — 계약을 어기는 출력은 전부 끔 ──────────────────────────────
F='review-entry: DISABLED:entry_check_failed'
case_stub() {   # case_stub <라벨> <stdout> <rc> <기대 판결>
  stub "$2" "$3"
  expect_verdict "$1" "$4" "$(run_entry_fence)"
}
case_stub "rc≠0 (유효 JSON 이어도)" '{"disabled": false, "reason": null, "advisories": []}' 3 "$F"
case_stub "비-JSON"                'hello' 0 "$F"
case_stub "빈 출력"                '' 0 "$F"
case_stub "JSON 두 줄"             $'{"disabled": false, "reason": null, "advisories": []}\n{"disabled": false, "reason": null, "advisories": []}' 0 "$F"
case_stub "{}"                      '{}' 0 "$F"
case_stub "disabled 문자열"         '{"disabled": "false", "reason": null, "advisories": []}' 0 "$F"
case_stub "disabled 정수"           '{"disabled": 0, "reason": null, "advisories": []}' 0 "$F"
case_stub "reason 키 없음"          '{"disabled": false, "advisories": []}' 0 "$F"
case_stub "reason 정수"             '{"disabled": true, "reason": 3, "advisories": []}' 0 "$F"
case_stub "advisories 문자열"       '{"disabled": false, "reason": null, "advisories": "x"}' 0 "$F"
case_stub "advisories 비문자열 원소" '{"disabled": false, "reason": null, "advisories": [1]}' 0 "$F"
case_stub "최상위 null"             'null' 0 "$F"
case_stub "최상위 배열"             '[]' 0 "$F"
# 양성 대조 — 계약을 지키는 출력은 통과한다(「언제나 끔」 구현이 여기서 RED).
case_stub "정상 false"              '{"disabled": false, "reason": null, "advisories": []}' 0 'review-entry: PROCEED'
case_stub "정상 true"               '{"disabled": true, "reason": "X_SWITCH=1", "advisories": []}' 0 'review-entry: DISABLED:X_SWITCH=1'
stub '{"disabled": false, "reason": null, "advisories": ["[spec-distill] ADV_MARK_q1"]}' 0
out="$(run_entry_fence)"
expect_verdict "정상 false + advisory" 'review-entry: PROCEED' "$out"
assert_contains "$out" "ADV_MARK_q1" "정상 false + advisory: advisory 를 그대로 보인다"

# ── AC6: 리포 정본 모듈 end-to-end ─────────────────────────────────────────────
cp "$SD_SCRIPTS/review_entry.py" "$SD_SCRIPTS/kill_switch_active.py" "$PR/scripts/"
expect_verdict "정본: 무설정" 'review-entry: PROCEED' "$(run_entry_fence)"
expect_verdict "정본: 전역 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DISABLE=1' \
  "$(run_entry_fence DEVBREW_SPEC_DISTILL_DISABLE=1)"
expect_verdict "정본: review-entry 토큰" 'review-entry: DISABLED:DEVBREW_SKIP_HOOKS=spec-distill:review-entry' \
  "$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:review-entry)"
expect_verdict "정본: design 모드 끔" 'review-entry: DISABLED:DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1' \
  "$(run_entry_fence DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1)"
out="$(run_entry_fence DEVBREW_SKIP_HOOKS=spec-distill:Stop)"
expect_verdict "정본: 은퇴 Stop 토큰" 'review-entry: PROCEED' "$out"
assert_contains "$out" "spec-distill:Stop" "정본: 은퇴 Stop 토큰 — 사용자의 토큰을 되읽는 advisory"

# ── AC9: 미커밋 펜스 ─────────────────────────────────────────────────────────
UNC_FENCE="$SCRATCH/uncommitted.sh"
extract '<!-- uncommitted-check:begin -->' '<!-- uncommitted-check:end -->' "$UNC_FENCE"
check_fence "미커밋" "$UNC_FENCE" 5 || { finish; exit; }

REPO="$SCRATCH/repo"
mkdir -p "$REPO/docs/superpowers/specs"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t )
DOC="$REPO/docs/superpowers/specs/2026-01-01-x-design.md"
echo "v1" > "$DOC"
( cd "$REPO" && git add -A && git commit -qm init )
run_unc() {   # run_unc <cwd> <spec_path>
  ( cd "$1" && env spec_path="$2" bash "$UNC_FENCE" ) 2>/dev/null
}
assert_eq "$(run_unc "$SCRATCH" "$DOC")" "" "AC9: 커밋된 깨끗한 문서 — advisory 없음 (양성 대조)"
echo "v2" >> "$DOC"
assert_contains "$(run_unc "$SCRATCH" "$DOC")" "커밋되지 않았다" "AC9: 수정 후 미커밋 — advisory"
( cd "$REPO" && git checkout -q -- docs )
NEW="$REPO/docs/superpowers/specs/2026-01-02-y-design.md"
echo "new" > "$NEW"
assert_contains "$(run_unc "$SCRATCH" "$NEW")" "커밋되지 않았다" "AC9: untracked — advisory"
rm -f "$NEW"
OUTSIDE="$SCRATCH/not-a-repo/doc-design.md"
mkdir -p "$(dirname "$OUTSIDE")"
echo x > "$OUTSIDE"
assert_contains "$(run_unc "$SCRATCH" "$OUTSIDE")" "확인하지 못했다" "AC9: 작업 트리 밖 — rc≠0 을 깨끗함으로 읽지 않는다"
REL="docs/superpowers/specs/2026-01-01-x-design.md"
assert_eq "$(run_unc "$REPO" "$REL")" "" "AC9: 상대 경로 + 커밋된 문서 — advisory 없음"
echo "v3" >> "$DOC"
assert_contains "$(run_unc "$REPO" "$REL")" "커밋되지 않았다" "AC9: 상대 경로 + 미커밋 — pathspec 이 -C 기준으로 풀린다"
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`
Expected: `✗ 추출(진입): 0줄 — 마커가 사라졌거나 …` 후 `Fail: 1` 로 끝난다.

- [ ] **Step 3: `skills/reviewing-spec/SKILL.md` 전문 교체**

codex 게이트 펜스(`<!-- codex-gate:begin … -->` ~ `<!-- codex-gate:end -->`)는 **현재 파일의 68–157 줄을 옮기되 세 군데만** 바꾼다(아래 전문에 반영돼 있다): ① 71–73 줄 주석에서 「어느 모드가 어느 프로필로 가는가(매핑)…」 두 문장 삭제 ② 125 줄 주석 `훅 mandate 의 슬롯(\`## 입력\`)` → `호출 인자(\`## 입력\`)` ③ 131 줄 echo 끝 `spec_path 에는 dispatch mandate 의 'spec path:' 슬롯 값을 대입해라.` → `spec_path 에는 이 skill 의 호출 인자(설계문서 경로)를 대입해라.` 나머지 줄은 한 글자도 바꾸지 않는다 — `test_reviewing_spec_residue.sh` 가 이 펜스를 잘라 돌린다.

````markdown
---
name: reviewing-spec
description: >
  Use right after superpowers:brainstorming writes and commits a design doc
  (docs/superpowers/specs/...-design.md), before superpowers:writing-plans — this review replaces
  brainstorming's user-review gate. Pass the design doc path as the argument. Runs the shared
  document-review engine with the design-doc profile (snapshot → detection → codex → anonymize →
  re-critique → freeze-check and routing → gate) inside a single turn and closes with the shared
  proceed gate. Design-mode only — the interview brief has its own reviewers (reviewing-brief).
cost_class: medium
---

# reviewing-spec — 문서 리뷰 엔진의 design doc 자리

이 skill 은 진입 껍데기다. 한 라운드의 절차는 공유 엔진이 갖고 있고, 여기 남는 것은 이 자리의
것 — 입력 · 진입 검사 · 프로필 · dispatch 둘 · 게이트 · degrade 채널 — 뿐이다.

## 입력

`$spec_path` 는 **호출 인자**다 — `Skill spec-distill:reviewing-spec <설계문서 경로>` 또는
`/spec-distill:reviewing-spec <경로>`. 상대 경로면 리포 루트 기준 절대 경로로 바꿔 쓴다.

인자가 없으면 후보를 뽑아 `AskUserQuestion` 으로 고르게 한다 — 현재 브랜치의 최근 커밋 50개
안에서 추가된 `-design.md` 중 최신 5개와 untracked 전부:

```bash
top="$(git rev-parse --show-toplevel)"
git -C "$top" log -n 50 --diff-filter=A --name-only --pretty=format: -- 'docs/superpowers/specs/*-design.md' | awk 'NF && !seen[$0]++' | head -n 5 | sed "s|^|$top/|"
git -C "$top" ls-files --others --exclude-standard -- 'docs/superpowers/specs/*-design.md' | sed "s|^|$top/|"
```

후보가 없거나 사용자가 고르지 않으면 아래 「대상 부재」로 끝낸다.

세션 상태 디렉토리는 `state_path.py` 리졸버로 연다 — 엔진 상태(`docreview-state.md`)와 codex
산출물이 여기 산다:

```bash
harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/state_path.py" session-id)"
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/state_path.py" state-root)"
STATE_DIR="$ROOT/$harness_sid"
```

### 대상 부재 — 게이트 없이 끝나는 경로 (정본 Step A)

`$spec_path` 가 working-tree 에 없거나(삭제된 워크트리 경로 등) 인자 없이 불려 후보를 고르지
않았으면 게이트를 띄우지 않고 이 문면 그대로 끝낸다. 승인 게이트 직전에도 같은 확인을 한 번 더
한다.

> `[spec-distill] current_spec '<path>' 부재 (working-tree 에 없거나 후보를 고르지 않았다) — handoff 진행 안 함. 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).`

## 진입 검사

엔진 라운드 전에 한 번 돈다. 끄기 판정은 이 펜스가 하고, 산문은 펜스 출력의 **마지막 줄**(판결)만
읽는다 — 조건을 산문으로 적지 않는다. 산문 조건은 집행되지 않고, kill switch 는 P21 보안 컨트롤이라
그 공백은 "껐다고 믿게만" 만든다.

<!-- review-entry:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
ENTRY="$SD/scripts/review_entry.py"
RETURN_MSG="[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
if [ ! -f "$ENTRY" ]; then
  block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — 모듈 부재: $ENTRY" "review-entry: DISABLED:entry_check_failed")"
else
  entry_err="$(mktemp 2>/dev/null || printf '/dev/null')"
  entry_out="$(python3 "$ENTRY" 2>"$entry_err")"; entry_rc=$?
  entry_err_1="$(head -n 1 "$entry_err" 2>/dev/null)"
  [ "$entry_err" != /dev/null ] && rm -f "$entry_err"
  if [ "$entry_rc" -ne 0 ]; then
    block="$(printf '%s\n' "[spec-distill] 진입 검사 실패(끔으로 친다) — $ENTRY rc=$entry_rc: $entry_err_1" "review-entry: DISABLED:entry_check_failed")"
  else
    block="$(printf '%s' "$entry_out" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except ValueError:
    d = None
ok = (isinstance(d, dict)
      and isinstance(d.get("disabled"), bool)
      and "reason" in d
      and (d["reason"] is None or isinstance(d["reason"], str))
      and isinstance(d.get("advisories"), list)
      and all(isinstance(a, str) for a in d["advisories"]))
if not ok:
    print("[spec-distill] 진입 검사 실패(끔으로 친다) — 출력이 계약(JSON 객체 · disabled boolean · reason 문자열|null · advisories 문자열 배열)을 어긴다: " + raw[:120].replace("\n", " "))
    print("review-entry: DISABLED:entry_check_failed")
    sys.exit(0)
for a in d["advisories"]:
    print(a)
if d["disabled"]:
    print("review-entry: DISABLED:" + (d["reason"] or "disabled"))
else:
    print("review-entry: PROCEED")
')" || block="review-entry: DISABLED:entry_check_failed"
  fi
fi
verdict="$(printf '%s\n' "$block" | tail -n 1)"
case "$verdict" in
  "review-entry: PROCEED"|"review-entry: DISABLED:"?*) ;;
  *) verdict="review-entry: DISABLED:entry_check_failed" ;;
esac
printf '%s\n' "$block" | sed '$d'
[ "$verdict" = "review-entry: PROCEED" ] || printf '%s\n' "$RETURN_MSG"
printf '%s\n' "$verdict"
```
<!-- review-entry:end -->

마지막 줄이 정확히 `review-entry: PROCEED` 일 때만 `## 절차` 로 간다. 그 밖이면 — `review-entry:
DISABLED:<사유>` — 펜스가 낸 `[spec-distill]` 줄을 **그대로** 한 단락으로 보이고 게이트 없이 끝난다
(그 단락의 마지막 문장이 복귀 지시다). 정본 `proceed-gate.md` 의 kill switch 예외 경로다. `PROCEED`
여도 `[spec-distill]` 줄(은퇴 스위치 공시)이 있으면 그대로 보인다.

끄는 스위치는 셋이고 셋 다 이 skill 을 직접 불러도 끈다: `DEVBREW_SKIP_HOOKS=spec-distill:review-entry`
· `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · 플러그인 전체 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 진입
검사 자신이 실패하면(모듈 부재 · rc≠0 · 출력 계약 위반) 끔으로 친다.

## 프로필

```bash
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/design-doc.md"
```

프로필은 `design-doc.md` 로 **고정**이다 — 이 skill 은 design 자리 전용이고 다른 프로필을 고르지 않는다.

## 절차

```
Read ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/reviewing-document.md
```

그 파일의 여덟 단계를 **한 턴 안에서** 돈다. 절차를 여기 복사하지 않는다 — 네 자리가 같은 절차를
쓰기 때문에 공유 정본에 두는 것이다. `--state-dir` 는 위 `$STATE_DIR` 이고, 상한은 그 문서가 정하는
**재리뷰 상한 2** 다(라운드 4 이상은 사용자가 승인 게이트에서 열어야만 돈다).

4단계 codex 는 이 자리의 리터럴 게이트다. 조건을 산문으로 적지 않는다 — 산문 조건은 집행되지 않고,
kill switch 는 P21 보안 컨트롤이라 그 공백은 "껐다고 믿게만" 만든다.

<!-- codex-gate:begin runner=run_docreview_codex_reviewer.sh -->
```bash
SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"
# `## 프로필` 과 **같은 한 줄**이다. Bash 도구는 호출마다 새 셸이라 앞 펜스의 대입이 여기로
# 오지 않는다 — `SD=` 를 펜스마다 다시 세우는 것과 같은 이유다.
PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/design-doc.md"
(… 현재 파일 75–124 줄 그대로 …)
# `$spec_path` 는 호출 인자(`## 입력`)라 디스크에서 도출되지 않는다 — 값이
# 없으면 여기서 **소리를 내고 멈춘다.** 빈 채로 러너에 넘기면 러너가 usage 로 rc 2 에
# 죽는데, 그 rc 는 아래 잔존물 제거의 옛 조건(rc 3)이 보지 않는 값이라 직전 라운드 YAML 이
# 그대로 남아 이번 라운드 판정으로 읽힌다. 처방은 「앞에 이어 붙여라」다 — 별개 호출로 다시
# 돌려도 같은 빈 상태가 재생산된다.
if [[ -z "${spec_path:-}" || -z "${CODEX_YAML:-}" ]]; then
  echo "[spec-distill] codex 게이트 입력 부재 — spec_path='${spec_path:-}' CODEX_YAML='${CODEX_YAML:-}'. 「## 입력」 블록을 이 펜스 앞에 이어 붙여 같은 Bash 호출 안에서 함께 돌리고, spec_path 에는 이 skill 의 호출 인자(설계문서 경로)를 대입해라. 이 라운드의 codex 축은 없이 간다." >&2
  codex_avail=""; skip_reason="gate_inputs_missing"
fi
(… 현재 파일 134–155 줄 그대로 …)
```
<!-- codex-gate:end -->

`DEVBREW_SPEC_DISTILL_DISABLE=1` 은 `## 진입 검사` 펜스가 엔진 라운드 전에 걸러낸다(엔진 2단계도 한 번
더 본다). `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 은 codex 만 끄고 탐지 리뷰는 그대로 돈다.
`DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` 은 재비판만 끈다. 뒤의 둘은 dispatch 직전에 확인하고
캐시하지 않으며, 발화한 스위치는 아래 degrade 채널로 공시한다.

## dispatch 블록 둘

(… 현재 파일 165–193 줄 그대로 — 절 제목 다음 줄부터 두 번째 Agent 블록의 닫는 펜스까지 …)

## 게이트

골격 · 두 가드 · 예외 경로의 정본은 아래 파일이다. 게이트 진입 시 읽고 따른다.

```
Read ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/proceed-gate.md
```

엔진 8단계의 `docreview_state.py gate --state-dir "$STATE_DIR" --render` 가 어느 게이트인지 정한다.
`round_gate_needed` 면 라운드 게이트(결정 묶음 + 차단 `ask`)를 `AskUserQuestion` **하나**로 띄우고
응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다. `approval_gate_open` 이면 승인 게이트이고, 열린
것이 남아 있으면 두 단계다.

승인 게이트를 띄우기 직전에 `$spec_path` 가 working-tree 에 있는지 다시 본다 — 없으면
`### 대상 부재` 문면으로 끝낸다(게이트 없음).

승인 게이트의 옵션 넷 — 정본 Step B 표를 이 skill 어휘로 채운 것이다:

| # | 이 skill 에서 |
|---|---|
| ① | 미커밋 확인 → `/compact` 후 `superpowers:writing-plans` (권장) — verbatim `/compact` 명령을 노출하고 **턴 종료** |
| ② | 미커밋 확인 → 바로 `Skill superpowers:writing-plans <path>` |
| ③ | 수정 필요 — 후속 질문으로 revise per findings / `conducting-interview` 재진입 / 사용자 직접 편집 분기 |
| ④ | 멈춤 — 상태 보존하고 종료 |

- **① 의 정지 요건** — verbatim `/compact` 명령을 노출한 자리에서 **턴 종료(STOP)** 한다. 같은 턴
  에서 `writing-plans` 를 호출하지 않는다(compact 전 진입은 옵션 ① 을 무력화한다). 진입은 사용자가
  `/compact` 를 실제로 실행한 **다음 턴**에 사용자 트리거로만 일어나고, 사용자가 redirect 하면
  미진입한다(P17).
- **polite stop 금지 (AP2)** — ①/② 를 골랐는데 narrate 만 하고 `### 미커밋 확인` 과 다음 단계
  진입을 skip 하면 polite stop 이다. 이 skill 을 종료하는 모든 경로는 이 게이트를 거치거나, 게이트를
  거치지 않는 예외 경로(`### 대상 부재` · `## 진입 검사` 의 끔)면 명시적 advisory 단락을 동반한다 —
  게이트-less silent 종료는 금지다.
- **재결정 규약 (P23)** — `decide` 처분이 인터뷰가 이미 확정한 항목을 겨냥하면 조용히 덮어쓰지
  않는다. design.md 의 재결정 기록에 *원래 / 재결정 후보 / 근거* 를 적어 다음 라운드로 들고 가고,
  확정이 실제로 뒤집히는 자리는 이 승인 게이트 하나다 — 사용자가 판정한다. 하류의 반증은 보고의
  근거이지 임의 변경의 근거가 아니다. 정본은 `proceed-gate.md` 의 「재결정 규약」 절.

### 미커밋 확인 — ①/② 직전

사용자가 진행을 고르면 다음 단계로 가기 전에 이 펜스를 돌리고, 나온 `[spec-distill]` 줄을 그대로
보인다. 진행은 막지 않는다.

<!-- uncommitted-check:begin -->
```bash
spec_dir="$(dirname -- "$spec_path")"
spec_base="$(basename -- "$spec_path")"
born_out="$(git -C "$spec_dir" status --porcelain -- "$spec_base" 2>/dev/null)"; born_rc=$?
if [ "$born_rc" -ne 0 ]; then
  echo "[spec-distill] 커밋 여부를 확인하지 못했다(git rc=$born_rc) — '$spec_path' 가 git 작업 트리 밖이거나 git 이 실패했다. writing-plans 전에 문서가 커밋됐는지 직접 확인하라."
elif [ -n "$born_out" ]; then
  echo "[spec-distill] 리뷰 수정분이 커밋되지 않았다: $spec_path — writing-plans 전에 커밋하라."
fi
```
<!-- uncommitted-check:end -->

## degrade 채널

(… 현재 파일 290–303 줄 그대로 — 절 제목 다음 줄부터 끝까지 …)
````

**「그대로」 네 자리**는 Read 로 현재 파일의 해당 줄을 복사해 붙인다 — 요약하거나 다시 쓰지 않는다. 교체 뒤 확인:

Run: `grep -cE 'mandate|arm_ledger|## 원장|clear-inflight|mark-reviewed|check-born|\$STATE([^_A-Za-z0-9]|$)' plugins/spec-distill/skills/reviewing-spec/SKILL.md` → `0` (`$STATE_DIR` 은 마지막 패턴에 걸리지 않는다)
Run: `bash plugins/spec-distill/tests/test_reviewing_spec_residue.sh` → `Fail: 0` (codex 펜스를 옮기며 깨지지 않았다)

- [ ] **Step 4: 펜스 테스트 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`
Expected: `Fail: 0`.

- [ ] **Step 5: `tests/test_reviewing_spec_state_keying.sh` 전문 교체** — 원장 호출 창을 재던 S2b·S3–S5·S7–S11 은 대상(`## 원장`)과 함께 지운다. sid·`STATE_DIR` 도출(S1·S2a2)은 남기고, 옛 `$STATE` 단언(S2a)은 「없다」로 뒤집어 `STATE_DIR` 존재의 음의 짝으로 쓴다.

```bash
#!/usr/bin/env bash
# state-keying 불변식 락 — reviewing-spec 이 세션 상태를 harness sid 하나로 연다.
#
# 재는 것:
#   · `## 입력` 이 `state_path.py` 의 session-id · state-root 로 `STATE_DIR="$ROOT/$harness_sid"`
#     를 만든다(엔진 상태 `docreview-state.md` 가 여기 산다).
#   · codex 펜스가 산출물 경로를 같은 `$ROOT/$harness_sid` 에서 도출한다 — 엔진 상태와 codex
#     산출물이 한 디렉토리에 앉는다. 갈리면 재개·GC 가 서로 다른 것을 본다.
#   · `## 절차` 가 `--state-dir` 로 그 `$STATE_DIR` 을 넘긴다.
#   · 음의 짝: 옛 상태 파일 변수 `$STATE`(원장 파일)가 skill 어디에도 없다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
. "$REPO_ROOT/shared/tests/assert.sh"

# 창의 끝 앵커가 실제로 범위를 닫았는지 본다 — sed 범위는 종료 주소가 없으면 EOF 까지 흐른다.
bounded_window() {  # $1=시작 정규식  $2=종료 정규식
  local out; out="$(sed -n "/$1/,/$2/p" "$SKILL")"
  [[ -n "$out" ]] || return 0
  grep -q "$2" <<<"$(tail -n1 <<<"$out")" || return 0
  printf '%s\n' "$out"
}

w_out="$(bounded_window '^## 입력$' '^## 진입 검사$')"
[[ -n "$w_out" ]] \
  && ok "W: 입력 윈도우가 비어 있지 않다 (앵커 생존)" \
  || no "W: 입력 윈도우가 비었다 — 구조 앵커 파손"

grep -qF 'state_path.py" session-id' <<<"$w_out" \
  && ok "S1: 입력 절이 state_path.py session-id 로 sid 를 해석한다" \
  || no "S1: 입력 절에 session-id 해석이 없다"
grep -qF 'state_path.py" state-root' <<<"$w_out" \
  && ok "S1b: 입력 절이 state_path.py state-root 로 루트를 해석한다" \
  || no "S1b: 입력 절에 state-root 해석이 없다"
grep -qE '^STATE_DIR="\$ROOT/\$harness_sid"$' <<<"$w_out" \
  && ok "S2: 입력 절이 STATE_DIR 을 \$ROOT/\$harness_sid 로 만든다" \
  || no "S2: 입력 절의 STATE_DIR 이 \$ROOT/\$harness_sid 가 아니다"

grep -qF 'CODEX_YAML="$ROOT/$harness_sid/docreview-codex.yaml"' "$SKILL" \
  && ok "S3: codex 산출물이 같은 \$ROOT/\$harness_sid 아래 도출된다" \
  || no "S3: codex 산출물 경로가 엔진 상태와 다른 디렉토리로 갈린다"

proc="$(bounded_window '^## 절차$' '^## dispatch 블록 둘$')"
grep -qF '`--state-dir` 는 위 `$STATE_DIR`' <<<"$proc" \
  && ok "S4: 절차 절이 --state-dir 로 \$STATE_DIR 을 넘긴다" \
  || no "S4: 절차 절의 --state-dir 가 \$STATE_DIR 이 아니다 (창 ${#proc}자)"

# S5 (S2 의 음의 짝) — 옛 원장 파일 변수. `$STATE_DIR` 은 걸리지 않게 뒤를 막는다.
if grep -qE '\$STATE([^_A-Za-z0-9]|$)' "$SKILL"; then
  no "S5: skill 에 옛 원장 파일 변수 \$STATE 가 남았다: $(grep -nE '\$STATE([^_A-Za-z0-9]|$)' "$SKILL" | head -3)"
else
  ok "S5: skill 에 \$STATE 가 없다 (STATE_DIR 만 있다)"
fi
finish
```

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh` → `Fail: 0`

- [ ] **Step 6: `tests/test_reviewing_spec_design_only.sh` 부분 수정** — 세 군데.

(a) 5–19 줄 헤더 블록(`# ── 앵커 재조준 (문서 리뷰 엔진 전환)` 부터 `# 은 손대지 않는다 — …` 까지)을 이것으로 바꾼다:

```bash
# ── 앵커 (2.0.0) ─────────────────────────────────────────────────────────────
# 이 파일의 주제 — *"이 skill 은 design 자리 전용인가"* — 를 오늘 지탱하는 것은 **프로필
# 고정**이다: 이 skill 은 `design-doc.md` 하나만 고르고, 호출 인자에는 모드가 없다. 그래서
# 양의 단언은 `## 프로필` 절의 고정 문장을, 음의 단언은 옛 모드 슬롯의 부재를 잰다.
#
# 아래 **부재** 단언 넷(re-consensus · mode_b_violation · spec-mode 표 행 · drafting-spec)
# 은 그대로다 — 그것들이 잠그는 개념은 되살아나면 안 된다.
```

(b) `# (2) 훅이 내는 \`mode:\` 두 값이 **그 하나로 모인다**는 주장이 실재하는가.` 줄부터 `fi`(CONVERGE 판정 블록의 끝, 현재 51 줄)까지를 이것으로 바꾼다:

```bash
# (2) 프로필이 design-doc 하나로 **고정**이라는 주장이 `## 프로필` 절 **안에** 있는가.
#     파일 어딘가가 아니라 그 절 — 헤더나 다른 절의 문장으로는 만족되지 않는다.
PROF_WIN="$(awk '/^## 프로필$/{f=1; next} f && /^## /{f=0} f' "$SKILL")"
if [[ -z "$PROF_WIN" ]]; then
  no "(2) '## 프로필' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif grep -qE 'design-doc\.md.*고정' <<<"$PROF_WIN"; then
  ok "(2) '## 프로필' 절이 design-doc.md 고정을 주장한다"
else
  no "(2) '## 프로필' 절에 design-doc.md 고정 문장이 없다 — 이 skill 이 어느 자리인지 말하지 않는다"
fi

# (2a) 옛 모드 슬롯이 없다 — 모드 값으로 프로필이 갈라질 입력 자체가 없어야 한다.
grep -qE '\$mode|mode: (design|spec)' "$SKILL" \
  && no "(2a) 모드 슬롯(\$mode / mode: design|spec)이 남았다" \
  || ok "(2a) 모드 슬롯이 없다"
```

(c) `# drafting-spec/Mode-B refs (design 자리 리뷰어 persona · spec-template comment).` → `# drafting-spec/Mode-B refs (design 자리 리뷰어 persona · 템플릿 주석).`

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` → `Fail: 0`

- [ ] **Step 7: 이 파일을 재는 다른 락을 돌린다** (한 명령씩)

`test_reviewing_spec_disclosure.sh` · `test_proceed_gate_adopters.sh` · `test_rereview_cap_consistency.sh` · `test_reviewing_spec_residue.sh` · `test_conducting_interview_internal.sh` · `test_no_wall_clock.sh` (spec-distill) · `shared/tests/test_dispatch_disposition.sh` · `shared/tests/test_agent_input_slots.sh` · `shared/tests/test_skill_reference_pointers.sh` · `shared/tests/test_adjudication_wiring.sh` · `plugins/quality-gates/tests/test_codex_gate_observation.sh` · `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh` → 전부 `Fail: 0`(또는 그 락의 통과 표시).

- [ ] **Step 8: CHANGELOG** — `### Added` 끝에 한 항목, `### Changed` 끝에 한 항목, `### Removed` 끝에 한 항목:

`### Added`:
```markdown
- **`reviewing-spec` 의 두 리터럴 펜스.** 진입 펜스(`<!-- review-entry:begin -->`)가 `review_entry.py` 를 부르고 모듈 부재 · rc≠0 · JSON 파싱 실패 · 스키마 위반(최상위 객체 · `disabled` boolean · `reason` 문자열|null · `advisories` 문자열 배열)을 전부 `DISABLED:entry_check_failed` 로 친다(fail-closed) — 끔 여부를 모르는 채 리뷰하면 사용자가 끈 스위치를 무시할 수 있고, 끔으로 치면 잃는 것은 자동 리뷰 한 번이다. skill 산문은 펜스 출력의 마지막 줄(판결)만 읽는다. 미커밋 펜스(`<!-- uncommitted-check:begin -->`)는 승인 게이트 ①/② 직전에 `git -C <dir> status --porcelain -- <basename>` 을 돌려, rc≠0(작업 트리 밖 · git 오류)이면 그 사실을, 출력이 있으면 미커밋을 advisory 로 낸다 — 출력이 비었다는 이유로 깨끗함으로 읽지 않는다. 락: `tests/test_reviewing_spec_entry_fence.sh`(두 펜스를 잘라내 실행).
```

`### Changed`:
```markdown
- **`reviewing-spec` 입력 계약.** 설계문서 경로는 **호출 인자**다. 인자가 없으면 최근 커밋 50개 안에서 추가된 `-design.md` 최신 5개 + untracked 를 후보로 보이고 고르게 한다 — 고르지 않으면 대상 부재 경로다. 옛 mandate 의 `mode:` 슬롯은 없다(프로필은 `design-doc.md` 고정). 게이트 없이 끝나는 두 경로(대상 부재 · 진입 검사의 끔 — 검사 실패 포함)의 advisory 는 같은 복귀 지시로 끝난다: 「리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).」 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` 의 집행 지점이 옛 `resolve_mode.py` 에서 이 진입 검사로 옮겨 오며 **뜻이 끄는 쪽으로 넓어졌다** — 예전에는 자동 리뷰와 구조 검사만 껐고 수동 호출은 살아 있었지만, 이제는 수동 호출까지 끈다. content-aware 판별(접미사 없는 `.md` 를 frontmatter 로 design 분류)도 함께 없어졌다. `test_reviewing_spec_state_keying.sh` 는 sid·`STATE_DIR` 도출만 잰다(원장 호출 창 단언은 대상과 함께 지웠다). `test_reviewing_spec_design_only.sh` 의 양성 단언은 「프로필 `design-doc.md` 고정」 문장으로 증인을 옮겼다.
```

`### Removed`:
```markdown
- **`reviewing-spec` 의 `## 원장` 절** — `mark-reviewed` · `check-born` · `clear-inflight` A/B 네 호출과 `$STATE`(원장 파일)·「read==write 디렉토리 불변식」 서술. `check-born` 이 사용자에게 주던 미커밋 advisory 만 원장 없이 남긴다(위 Added).
```

- [ ] **Step 9: 커밋**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh plugins/spec-distill/tests/test_reviewing_spec_state_keying.sh plugins/spec-distill/tests/test_reviewing_spec_design_only.sh plugins/spec-distill/CHANGELOG.md
git commit -m "feat(spec-distill): reviewing-spec 진입 계약 — 호출 인자 · fail-closed 진입 펜스 · 원장 없는 미커밋 확인" -m "경로는 호출 인자(없으면 후보 선택). 진입 펜스가 review_entry.py 출력 스키마를 검사해 판결 줄을 내고, 게이트 없이 끝나는 두 경로는 같은 복귀 지시로 끝난다. ## 원장 삭제." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 5: 핸드오프 문구 네 자리

AC8 · AC16(정적) · G2 · G3 · 설계 §3.1. 인터뷰 경유 경로의 세 자리(`finishing.md` ①·② · brief 템플릿 §7)가 brainstorming → `spec-distill:reviewing-spec` → writing-plans 순서를 싣는다. 넷째 자리(description)는 Task 4 에서 이미 썼고 여기서 락만 건다. 문구는 행동만 담는다(C8).

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/references/finishing.md` (349 줄 · 361–365 줄)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` (92–93 줄)
- Create: `plugins/spec-distill/tests/test_review_handoff_order.sh`
- Modify: `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 4 의 SKILL description · `### 대상 부재` 인용 줄 · `review-entry` 펜스의 `RETURN_MSG`.

- [ ] **Step 1: 실패하는 락을 쓴다** — `plugins/spec-distill/tests/test_review_handoff_order.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/reviewing-spec/SKILL.md
#
# AC8 · AC16 — 핸드오프 네 자리가 brainstorming → `spec-distill:reviewing-spec` → writing-plans
# 순서를 싣고, `reviewing-spec` 의 게이트 없는 두 종료 경로가 같은 복귀 지시로 끝나는가.
#
# **정적 락이다.** 문구의 존재와 순서만 증명한다 — 오케스트레이터가 그 문구대로 부르는지는
# 재지 못한다(AC14 수동 e2e 몫). 게이트 없는 종료의 «실행 출력»은
# `test_reviewing_spec_entry_fence.sh` 가 잰다 — 여기는 그 문장이 표면에 있는지만 본다.
#
# 자리마다 창을 따로 자른다 — 파일 어딘가에 순서가 있으면 통과하는 것이 아니라 그 자리에
# 있어야 한다. 순서는 창 안의 문자 오프셋으로 잰다(한 줄 안의 순서까지).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIN="$ROOT/plugins/spec-distill/skills/conducting-interview/references/finishing.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-brief-template.md"
SKILL="$ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/conducting-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"

RETURN_TAIL='리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).'

nonempty() {   # nonempty <라벨> <창> — 빈 창은 통과가 아니라 앵커 파손
  if [ -n "$2" ]; then ok "$1: 창 추출 ($(printf '%s\n' "$2" | wc -l | tr -d ' ')줄)"; return 0; fi
  no "$1: 창이 비었다 — 구조 앵커 파손 (통과 아님)"; return 1
}
order() {   # order <라벨> <창> <앞> <뒤>
  local r
  r="$(WIN="$2" A="$3" B="$4" python3 -c '
import os
w, a, b = os.environ["WIN"], os.environ["A"], os.environ["B"]
i, j = w.find(a), w.find(b)
print("앞 없음" if i < 0 else "뒤 없음" if j < 0 else "ok" if i < j else "역순")
')"
  if [ "$r" = "ok" ]; then ok "$1: '$3' → '$4'"; else no "$1: 순서 판정 $r ('$3' → '$4')"; fi
}

# ── ① /compact 템플릿 — 사용자가 그대로 붙여넣는 한 줄 ──────────────────────
ONE="$(grep -F '/compact interview brief at' "$FIN" || true)"
n1="$(printf '%s' "$ONE" | grep -c . || true)"
if [ "$n1" = "1" ]; then
  ok "① 템플릿 줄이 정확히 하나"
  order "① 템플릿" "$ONE" "Skill superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "① 템플릿" "$ONE" "spec-distill:reviewing-spec" "writing-plans"
  # 치환되지 않은 placeholder 를 잡는 fail-closed 검사가 없다(finishing.md 가 스스로 적는다) —
  # 새 꺾쇠 자리를 들이지 않는다.
  ph="$(printf '%s' "$ONE" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')"
  assert_eq "$ph" "<brief-path> " "① 템플릿의 꺾쇠 placeholder 는 <brief-path> 하나뿐"
else
  no "① 템플릿 줄이 ${n1}개 — 정확히 하나여야 한다"
fi

# ── ② 호출 프롬프트 ─────────────────────────────────────────────────────────
TWO="$(awk '/^- \*\*② 확정하고 바로 brainstorming\*\*/{f=1} /^- \*\*③/{f=0} f' "$FIN")"
if nonempty "②" "$TWO"; then
  order "② 호출 프롬프트" "$TWO" "Skill superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "② 호출 프롬프트" "$TWO" "spec-distill:reviewing-spec" "writing-plans"
  assert_contains "$TWO" "보다 이 순서가 우선한다" "②: brainstorming 의 「다음은 writing-plans 뿐」보다 우선한다고 적는다"
  assert_contains "$TWO" "게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다" "②: 게이트 없는 종료의 복귀 분기를 싣는다 (AC16)"
fi

# ── brief 템플릿 §7 ─────────────────────────────────────────────────────────
SEV="$(awk '/^## 7\. Next Action/{f=1} f' "$TPL")"
if nonempty "§7" "$SEV"; then
  order "brief 템플릿 §7" "$SEV" "superpowers:brainstorming" "spec-distill:reviewing-spec"
  order "brief 템플릿 §7" "$SEV" "spec-distill:reviewing-spec" "writing-plans"
fi

# ── reviewing-spec description — 자기 자신을 가리키므로 이름 대신 «앞/뒤» 를 잰다 ─
DESC="$(awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$SKILL" \
  | awk '/^description:/{d=1; print; next} d && /^[a-z_]+:/{d=0} d')"
if nonempty "description" "$DESC"; then
  order "description" "$DESC" "superpowers:brainstorming" "superpowers:writing-plans"
  assert_contains "$DESC" "before superpowers:writing-plans" "description: writing-plans «앞» 에 쓴다고 적는다"
  assert_contains "$DESC" "user-review gate" "description: brainstorming 의 사용자 리뷰 게이트를 대신한다고 적는다"
  assert_contains "$DESC" "path as the argument" "description: 설계문서 경로를 인자로 받는다고 적는다"
fi

# ── AC16 — 게이트 없는 두 종료 경로 ──────────────────────────────────────────
STEPA="$(grep -E '^> `\[spec-distill\] current_spec ' "$SKILL" || true)"
na="$(printf '%s' "$STEPA" | grep -c . || true)"
if [ "$na" = "1" ]; then
  case "$STEPA" in
    *"$RETURN_TAIL\`") ok "대상 부재 advisory 가 복귀 지시로 끝난다" ;;
    *) no "대상 부재 advisory 의 마지막 문장이 복귀 지시가 아니다: $STEPA" ;;
  esac
else
  no "대상 부재 advisory 인용 줄이 ${na}개 — 정확히 하나여야 한다"
fi
FENCE="$(awk 'index($0,"<!-- review-entry:begin -->"){f=1;next} index($0,"<!-- review-entry:end -->"){f=0} f' "$SKILL")"
if nonempty "진입 펜스" "$FENCE"; then
  assert_contains "$FENCE" "$RETURN_TAIL" "진입 펜스가 복귀 지시 문장을 갖는다"
fi
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_review_handoff_order.sh`
Expected: ① · ② · §7 의 순서 판정이 `앞 없음`/`뒤 없음` 으로 RED, description · AC16 은 GREEN(Task 4 에서 썼다). `Fail:` ≥ 5.

- [ ] **Step 3: `finishing.md` ① 템플릿** — 349 줄 끝의 `다음 단계: Skill superpowers:brainstorming <brief-path>.\`` 를 이것으로 바꾼다(줄의 나머지는 그대로):

```text
다음 단계: Skill superpowers:brainstorming <brief-path> → 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:reviewing-spec → 그 승인 게이트에서 진행을 고른 뒤 superpowers:writing-plans.`
```

Edit 의 old_string 은 `다음 단계: Skill superpowers:brainstorming <brief-path>.\`` (끝 백틱 포함 — 파일에서 유일하다). 351–353 줄의 「`<brief-path>` 두 자리」 문장은 그대로 참이다(새 꺾쇠 자리 없음).

- [ ] **Step 4: `finishing.md` ② 호출 프롬프트** — old_string:

```text
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장을 함께
  싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`
```

new_string:

```text
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장과 순서
  문장을 함께 싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`
  >
  > `설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:reviewing-spec 을 부른다 — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다. superpowers:writing-plans 는 reviewing-spec 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. reviewing-spec 이 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다.`
```

- [ ] **Step 5: brief 템플릿 §7** — old_string:

```text
(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
```

new_string:

```text
(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md` 작성·커밋
 → 그 설계문서 경로로 `spec-distill:reviewing-spec`(brainstorming 의 사용자 리뷰 게이트 대신) → 승인
 게이트에서 진행을 고른 뒤 `superpowers:writing-plans`. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
```

- [ ] **Step 6: 통과를 확인하고, 두 파일을 재는 기존 락을 돌린다** (한 명령씩)

- `bash plugins/spec-distill/tests/test_review_handoff_order.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh` → `Fail: 0` (127 줄 `/compact interview brief at` 존재 · 채택자 코퍼스 가드)
- `bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh` · `test_brief_review_entry.sh` · `test_compression_adopters.sh` · `test_check_verbatim_coverage.sh` · `test_brief_no_statement_cap.sh` · `test_reviewing_brief_skill.sh` · `test_web_kill_switch.sh` · `test_check_brief.sh` · `test_brief_no_length_cap.sh` → `Fail: 0`
- `cd plugins/spec-distill/tests && python3 -m unittest -v test_finishing_block_scope` → `OK`
- `bash plugins/quality-gates/tests/test_law2_prose.sh` · `bash shared/tests/test_skill_reference_pointers.sh` → 통과

- [ ] **Step 7: CHANGELOG** — `### Changed` 끝에:

```markdown
- **핸드오프가 리뷰 순서를 싣는다.** 인터뷰 종료 게이트의 ① `/compact` 템플릿 「다음 단계:」, ② brainstorming 호출 프롬프트, brief 템플릿 §7 이 brainstorming → 설계문서 작성·커밋 → 그 경로로 `spec-distill:reviewing-spec` → 승인 게이트 뒤 writing-plans 순서를 적는다. ② 는 「brainstorming 의 『다음은 writing-plans 뿐』 지시보다 이 순서가 우선한다」와 「reviewing-spec 이 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다」를 함께 싣는다 — brainstorming 은 spec-distill 을 모르므로 규약의 거처는 호출 프롬프트다(`finishing.md` 「규약의 거처 (C5)」). ① 은 compact 요약이 운반자라 손실이 있을 수 있다. `reviewing-spec` 의 description 은 「brainstorming 이 설계문서를 쓰고 커밋한 직후, writing-plans 전에 쓴다 · 사용자 리뷰 게이트를 대신한다 · 경로를 인자로 받는다」로 바뀌었다 — `/brainstorming` 직접 경로는 이 한 줄에 기댄다. 락: `tests/test_review_handoff_order.sh`(정적 — 문구의 존재와 순서만 잰다).
```

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/CHANGELOG.md
git commit -m "feat(spec-distill): 인터뷰 핸드오프가 brainstorming → reviewing-spec → writing-plans 순서를 싣는다" -m "finishing ① /compact 템플릿 · ② 호출 프롬프트 · brief 템플릿 §7. ② 는 brainstorming 의 writing-plans 직행 지시보다 우선한다고 적고 게이트 없는 종료의 복귀 분기를 싣는다. 정적 순서 락 신설." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 6: 죽은 인용 정정 + quality-gates bump

AC11 · 설계 §5. 존재하지 않게 된 대상을 현재형으로 가리키는 자리 일곱 중 여섯을 고친다(일곱째 `hook_common.py` docstring 은 Task 3 에서 이미 교체). 동작 변경 없음 — 주석·docstring 만. `docreview_state.py` 는 두 플러그인에 심볼릭 링크로, `codex_prompt_common.py` 는 물리 사본으로 실리므로 quality-gates 도 patch bump 한다.

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` (87–91 줄 주석)
- Modify: `plugins/spec-distill/scripts/check_brief.py` (19 줄 docstring)
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` (62 줄의 한 문장)
- Modify: `shared/docreview/scripts/docreview_state.py` (8 줄 docstring)
- Modify: `shared/codex/codex_prompt_common.py` (48–53 줄 docstring) → 사본 재생성 `plugins/spec-distill/scripts/codex_prompt_common.py` · `plugins/quality-gates/scripts/codex_prompt_common.py`
- Modify: `tools/adjudication/check_names.py` (110–112 줄 docstring)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` (`"version": "7.5.1",` → `"7.5.2",`) · `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: 사본이 지금 정본과 일치하는지 먼저 본다** — 재생성이 다른 차이를 끌고 들어오지 않게.

Run: `bash shared/tests/test_copy_of_contract.sh`
Expected: `Fail: 0` (그리고 `codex_prompt_common.py` 두 사본의 `≡` 줄).

- [ ] **Step 2: 여섯 자리를 고친다** (Edit, 각 old_string 은 파일에서 유일하다)

(a) `plugins/spec-distill/scripts/state_path.py` — old:
```text
        # env-only resolve (no hook payload on the CLI path); mirrors what the
        # Stop hook resolves so the skill keys `mark-reviewed` to the SAME state
        # file the hook reads (v0.25.0 arm ledger). Unresolved → exit 1 with NO
        # stdout (caller treats empty as "skip the ledger write, keep
        # enforcement").
```
new:
```text
        # env-only resolve (no hook payload on the CLI path). Skills key their
        # per-session state directory with this sid (reviewing-spec's STATE_DIR,
        # the brief pipeline's state.local.md). Unresolved → exit 1 with NO
        # stdout (caller treats empty as "state directory unresolved").
```

(b) `plugins/spec-distill/scripts/check_brief.py` — old: `이 게이트는 **Law 1 구조 자기검사**다 (specs의 parse_spec_structure.py와 같은 층).` → new: `이 게이트는 **Law 1 구조 자기검사**다.`

(c) `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — old: `훅이 읽는 파일과 **같은 리졸버**로 경로를 구합니다.` → new: `경로는 \`state_path.py\` 리졸버로 구합니다.`

(d) `shared/docreview/scripts/docreview_state.py` — old: `건드리지 않는다 — 그 파일은 훅과 brief 파이프라인의 줄 파서가 소유한다.` → new: `건드리지 않는다 — 그 파일은 brief 파이프라인의 줄 파서가 소유한다.`

(e) `shared/codex/codex_prompt_common.py` — old:
```text
    있고 sys.stdout을 채울 수 있는 모든 객체에 있지는 않으므로 형제 관용구(둘 다
    plugins/spec-distill/ 하위 — review-dispatch.py 모듈 최상단의 stdin/stdout/stderr
    reconfigure 루프, check_verbatim_coverage.py의 main()이 쓰는 stdout/stderr guard)와
    같이 guard한다. 단 그 둘이 잡는 예외 클래스가 서로 다르다(전자 AttributeError·OSError,
    후자 AttributeError·ValueError) — 닫힌 TextIOWrapper는 ValueError를 낸다(실측)로
    여기서는 합집합을 잡는다.
```
new:
```text
    있고 sys.stdout을 채울 수 있는 모든 객체에 있지는 않으므로 형제 관용구
    (plugins/spec-distill/scripts/check_verbatim_coverage.py 의 main() 이 쓰는
    stdout/stderr guard)와 같이 guard한다. 그 형제는 AttributeError·ValueError 를
    잡는다 — 닫힌 TextIOWrapper는 ValueError를 낸다(실측). 여기서는 쓰기 불가 스트림의
    OSError 까지 더한 합집합을 잡는다.
```

(f) `tools/adjudication/check_names.py` — old:
```text
    문맥을 «동사»(`Dispatch` 등)로 가르지 않는다 — 키 이름 자체에 `dispatch` 가
    든 것이 있어(`spec-distill:review-dispatch`) 그 매칭이 자기 자신을 문맥으로
    오인한다. 파일 종류는 그 함정이 없다.
```
new:
```text
    문맥을 «동사»(`Dispatch` 등)로 가르지 않는다 — 키 이름 자체에 `dispatch` 같은
    동사가 들 수 있어 그 매칭이 자기 자신을 문맥으로 오인한다. 파일 종류는 그 함정이
    없다.
```

- [ ] **Step 3: 사본 둘을 정본에서 다시 만든다** — Write 도구로 `.claude/plan-baseline/regen_copies.py`:

```python
"""codex_prompt_common.py 사본 둘 = `# copy-of:` 한 줄 + 정본 전문."""
import pathlib

SRC = "shared/codex/codex_prompt_common.py"
c = pathlib.Path(SRC).read_text(encoding="utf-8")
for dst in ("plugins/spec-distill/scripts/codex_prompt_common.py",
            "plugins/quality-gates/scripts/codex_prompt_common.py"):
    pathlib.Path(dst).write_text(f"# copy-of: {SRC}\n" + c, encoding="utf-8")
    print("wrote", dst)
```

Run: `python3 .claude/plan-baseline/regen_copies.py`
Run: `git diff --stat -- plugins/spec-distill/scripts/codex_prompt_common.py plugins/quality-gates/scripts/codex_prompt_common.py`
Expected: 두 파일 각각 정본과 같은 줄 수만 바뀐다(Step 2 (e) 의 diff 와 같은 크기). 다른 줄이 바뀌면 Step 1 이 GREEN 이었어도 사본에 마커 외 차이가 있었던 것이다 — 멈추고 원인을 본다.

- [ ] **Step 4: 락을 돌린다** (한 명령씩)

- `bash shared/tests/test_copy_of_contract.sh` → `Fail: 0`
- `bash plugins/quality-gates/tests/test_codex_copies_agree.sh` → `Fail: 0`
- `bash shared/tests/test_dispatch_name_defined.sh` → `Fail: 0` (check_names.py 판정기 자신이 코퍼스다)
- `bash shared/tests/test_docreview_state.sh` · `bash shared/tests/test_docreview_golden.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_check_brief.sh` · `bash plugins/spec-distill/tests/test_state_path.sh` · `bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh` · `bash plugins/spec-distill/tests/test_brief_review_ng3.sh` → `Fail: 0`

- [ ] **Step 5: quality-gates bump + CHANGELOG**

`plugins/quality-gates/.claude-plugin/plugin.json`: `"version": "7.5.1",` → `"version": "7.5.2",`

`plugins/quality-gates/CHANGELOG.md` — `## [7.5.1] — 2026-09-09` **앞**에:

```markdown
## [7.5.2] — 2026-09-11

### Fixed

- **사본·링크 둘의 주석이 삭제된 spec-distill 파일을 가리켰다.** spec-distill 2.0.0 이 설계문서 리뷰 Stop 훅을 삭제했다(`plugins/spec-distill/CHANGELOG.md` `[2.0.0]`). 이 플러그인의 `scripts/codex_prompt_common.py`(정본 `shared/codex/codex_prompt_common.py` 의 `# copy-of:` 사본) docstring 이 그 훅의 stdin/stdout reconfigure 루프를 형제 관용구로 인용했고, 심볼릭 링크로 싣는 `scripts/docreview_state.py`(정본 `shared/docreview/scripts/`) docstring 이 `state.local.md` 의 소유자로 그 훅을 들었다. 두 인용을 살아 있는 대상으로 고쳤다. 동작 무변경 — 주석만 바뀌지만 배포 파일 바이트가 바뀌므로 bump 한다(cache key).
```

`plugins/spec-distill/CHANGELOG.md` — `[2.0.0]` 의 `### Changed` 끝에:

```markdown
- **삭제된 대상을 현재형으로 가리키던 인용 여섯을 고쳤다** — `scripts/state_path.py`(session-id CLI 주석) · `scripts/check_brief.py`(docstring 의 「같은 층」 비교) · `skills/reviewing-brief/SKILL.md`(「훅이 읽는 파일과 같은 리졸버」) · `shared/docreview/scripts/docreview_state.py`(`state.local.md` 소유자) · `shared/codex/codex_prompt_common.py` 와 사본 둘(형제 관용구 인용) · `tools/adjudication/check_names.py`(`dispatch` 가 든 키 이름의 예). `scripts/hook_common.py` 의 모듈 docstring 은 소비자 목록을 현재 둘로 다시 썼다. 동작 무변경. quality-gates 는 사본·링크 때문에 7.5.2 로 함께 bump.
```

Run: `bash shared/tests/test_changelog_integrity.sh` → `Fail: 0`

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/state_path.py plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/skills/reviewing-brief/SKILL.md shared/docreview/scripts/docreview_state.py shared/codex/codex_prompt_common.py plugins/spec-distill/scripts/codex_prompt_common.py plugins/quality-gates/scripts/codex_prompt_common.py tools/adjudication/check_names.py plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/spec-distill/CHANGELOG.md
git commit -m "docs(spec-distill): 삭제된 리뷰 훅을 현재형으로 가리키던 인용 정정 + quality-gates 7.5.2" -m "state_path · check_brief · reviewing-brief · docreview_state · codex_prompt_common(정본+사본 둘) · check_names. 동작 무변경. qg 는 사본·링크 바이트 변경으로 patch bump." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 7: README

AC15(README 부분) · 설계 §6. 흐름도 · Principles Instantiated · Hooks Installed · kill switch 절 · 은퇴 절을 고친다. 원칙 서술의 정직성: 「리뷰 진입은 집행(hook)이 아니라 skill 표면과 핸드오프 지시다」를 숨기지 않는다. `:146` gstack 흡수 이력은 **남기되** 그 흡수분이 삭제됐다고 한 문장 붙인다(설계가 plan 에 넘긴 판정 — 역사 서술이지만 「Structural baseline 을 흡수했다」만 두면 지금도 구현이 있는 것으로 읽힌다). 다른 리포에 CLAUDE.md 줄을 권하는 문장은 쓰지 않는다(D5).

README 문장은 Task 8 락의 두 검사를 통과해야 한다: 삭제 식별자(`arm_ledger` · `check-born` · `CANDIDATE_CAP` · `resolve_mode` 등)가 은퇴 절의 토큰 리터럴 밖에 없고, 개념 별칭(`Stop 훅` · `mandate` · `arm-once` · `구조 검증` · `born` · `G6 상한` · `자동 dispatch` · `발견의 한계` 등)이 README 어디에도 없다. 아래 새 문안은 그 조건으로 썼다.

**Files:**
- Modify: `plugins/spec-distill/README.md` (편집 스크립트)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (62 줄 키워드)
- Modify: `plugins/spec-distill/tests/test_probe_sweep_residue.sh` (51 줄 주석)
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: 락을 먼저 바꾼다(실패 확인용)** — `plugins/spec-distill/tests/test_readme_sync.sh` 62 줄:

old: `for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'armed_paths' 'arm-once' 'interview-brief'`
new: `for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'spec-distill:review-entry' 'review_entry.py' 'interview-brief'`

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: `✗ README-sync: missing spec-distill:review-entry` · `✗ … missing review_entry.py` 두 줄로 RED.

- [ ] **Step 2: 편집 스크립트를 쓴다** — Write 도구로 `.claude/plan-baseline/task7_readme.py`:

```python
"""Task 7 — spec-distill README 편집. 사용: python3 .claude/plan-baseline/task7_readme.py"""
import pathlib
import sys

P = pathlib.Path("plugins/spec-distill/README.md")
s = P.read_text(encoding="utf-8")


def replace(old, new):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit(f"[중단] 치환 대상 {n}회: {old[:90]!r}")
    s = s.replace(old, new)


def cut(start, end, new=""):
    """start 부터 end(포함)까지를 new 로. start 는 정확히 1회, end 는 start 뒤 첫 매치."""
    global s
    if s.count(start) != 1:
        sys.exit(f"[중단] 시작 앵커 {s.count(start)}회: {start[:90]!r}")
    i = s.index(start)
    j = s.find(end, i)
    if j < 0:
        sys.exit(f"[중단] 끝 앵커 없음: {end[:90]!r}")
    s = s[:i] + new + s[j + len(end):]


# ── 흐름도 ──
replace(
    "                                       ▼ brainstorming user-review 정지 → 턴 경계\n"
    "                                       ▼ [Stop: 발견 → 구조 검증 → review-dispatch]  (기존 hook)\n",
    "                                       ▼ brainstorming 이 설계문서를 쓰고 커밋 — 사용자 리뷰 게이트 자리\n"
    "                                       ▼ 오케스트레이터가 그 경로로 reviewing-spec 호출 (핸드오프 지시 · description — 훅 강제 없음)\n")

# ── 버전 노트 ──
replace(
    "원인 자체를 없앴다 — `scripts/arm_ledger.py`가 문서 생애 단 한 번만 arm하는 `arm-once` 게이트를 구현하고(세션 원장 `armed_paths` ∧ git 추적 여부로 판정), v0.14.0–v0.18.0에 쌓였던 방어층 3종(억제 집합·순서 교정·진행중 락)이 근거를 잃어 함께 삭제됐다.",
    "원인 자체를 없앴다 — 문서 생애 단 한 번만 리뷰를 거는 세션 원장을 도입했고, v0.14.0–v0.18.0에 쌓였던 방어층 3종(억제 집합·순서 교정·진행중 락)이 근거를 잃어 함께 삭제됐다. 그 원장은 2.0.0 에서 리뷰 훅과 함께 삭제됐다.")
replace(
    "차단하지 않는다(호환 유지).\n\n## Principles Instantiated",
    "차단하지 않는다(호환 유지).\n\n"
    "**2.0.0**: 설계문서 리뷰 진입의 훅 강제를 없앴다. brainstorming 뒤·writing-plans 앞의 `reviewing-spec` 호출은 오케스트레이터가 인터뷰 핸드오프 문구(`finishing.md` ①·②, brief 템플릿 §7)와 이 skill 의 description 을 읽고 스스로 한다. 끄기 판정은 진입 검사(`scripts/review_entry.py` + 리터럴 펜스, fail-closed)가, TTL-GC 기동은 SessionEnd 훅이 맡는다.\n\n"
    "## Principles Instantiated")

# ── Principles Instantiated ──
replace(
    "\"spec 이전엔 코딩 안 한다\" 강제. (`locked_decisions`는 design doc의 표식이 아니라 그 반대다 — `scripts/resolve_mode.py`가 frontmatter에 이 키를 가진 파일을 **spec** 모드로 분류하고, `-design.md`를 포함한 나머지는 design 모드다.)",
    "**설계문서에는 필수 섹션 구조 게이트가 없다(2.0.0)** — 그것을 검사하던 코드(spec 모드 검사)는 생산자가 없어 발동하지 않았고 리뷰 훅과 함께 삭제됐다. 설계문서의 명확성은 `doc-critic` 층 2(`placeholder`·`ambiguity`)와 승인 게이트가 판정한다 — 이 리포의 Law 1 필수 섹션 게이트 구현은 0 이다(CHANGELOG `[2.0.0]`).")
cut("- **Law 2 강화 (v0.3.0, v0.36.0 재배선)**",
    "도구 이름을 열거하던 이전 설계의 구멍이 이것이다.\n",
    "- **Law 2 — 리뷰 진입은 집행이 아니다 (2.0.0)** — 설계문서 리뷰 진입에 훅 강제가 없다. brainstorming 뒤·writing-plans 앞에 `reviewing-spec` 을 부르는 것은 오케스트레이터이고, 근거는 인터뷰 핸드오프 문구와 이 skill 의 description 이다 — 철학 P13(hook = 집행 / skill = capability 표면) 기준으로 이 자리의 집행이 사라졌다. `/brainstorming` 직접 경로는 description 하나에 기대므로 건너뛰는 일이 흔할 것이다 — 그때는 `/spec-distill:reviewing-spec <경로>` 로 부른다. 리뷰어의 물리 분리(`tools:` allowlist)는 그대로다.\n")
cut("- **Law 2 (Writer/Reviewer Never Share a Pass) — infrastructure operability**",
    "reviewer persona 분리 자체가 무의미.\n")
replace("소비자는 `scripts/merge_review.py`·`scripts/merge_brief_review.py`·`hooks/review-dispatch.py`(종단 결정자).",
        "소비자는 `scripts/merge_review.py`·`scripts/merge_brief_review.py`.")
cut("- **Law 3 (Every Cycle Must Leave the System Smarter)**: v0.5.0 PR이",
    "CI에서 즉시 잡힘.\n")
replace(
    "`arm_ledger.py check-born`(v0.25.0)은 approve 시점에 문서가 git에 커밋됐는지만 확인한다 — 미커밋이면 advisory만 내고 아무 것도 기록하지 않는다(arm 판정은 리뷰 자신이 이미 마쳤으므로 기록할 상태가 남지 않는다). 세션 dir 삭제는 SessionEnd/TTL-GC로 이관.",
    "진행(①/②) 직전의 미커밋 확인은 `reviewing-spec` `## 게이트` 의 리터럴 펜스가 한다 — 미커밋이거나 git 이 확인에 실패하면 advisory 만 내고 아무것도 기록하지 않는다. 세션 dir 삭제는 SessionEnd 훅(세션 폴더 + TTL-GC)이 한다.")
cut("- **Law 1 fail-safe + Law 2 (v0.25.0)**", "그 판단은 아직 하지 않았다.\n")
replace("- **P2 (Ambiguity Gate)** — 구조적 (필수 11 섹션) default, numerical 거부 (philosophy P2).",
        "- **P2 (Ambiguity Gate)** — numerical 거부 (philosophy P2). 설계문서의 모호성은 `doc-critic` 층 2 가 판정한다 — 필수 섹션 구조 게이트는 2.0.0 에서 삭제됐다(위 Law 1).")
replace("approve tail = proceed 게이트(AskUserQuestion) → 원장 기록(`mark-reviewed`) + 미커밋 advisory(`check-born`).",
        "approve tail = proceed 게이트(AskUserQuestion) → 미커밋 확인(리터럴 펜스, 기록 없음).")
replace("rhythm guard 3, **자동 dispatch 재시도 상한 3 (v0.25.0, 세션당·문서당)**, kill switch.",
        "rhythm guard 3, kill switch.")
replace(
    "`resolve_session_id` 검증 실패 시 None 반환 + stderr advisory, advisory hook output은 유지. cleanup 실패 시 silent skip (SessionEnd) 또는 advisory (check-born) — 사용자 attention 가용성에 따라 loud 정도 조정.",
    "`resolve_session_id` 검증 실패 시 None 반환 + stderr advisory. cleanup 실패 시 silent skip (SessionEnd), 미커밋 확인·진입 검사 실패는 advisory — 사용자 attention 가용성에 따라 loud 정도 조정. 진입 검사 자신의 실패는 끔으로 친다(fail-closed).")
replace("- **gstack** — Structural baseline (11 필수 섹션) + concrete-next-action refusal pattern + ETHOS (\"AI recommends, users decide\").",
        "- **gstack** — concrete-next-action refusal pattern + ETHOS (\"AI recommends, users decide\"). Structural baseline(11 필수 섹션) 흡수분은 2.0.0 에서 그 검사 코드와 함께 삭제됐다.")

# ── Hooks Installed ──
cut("| Stop | `hooks/review-dispatch.py` |", "Bash 로 쓴 문서를 통째로 놓쳤다. |\n")
replace(
    "| SessionEnd | `hooks/session-end-cleanup.py` | deterministic per-session `.claude/spec-distill/<sid>/` cleanup (v0.6.0). polite-stop이나 approve 누락 시에도 cleanup 보장 (4-layer defense의 layer 2). Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` / `:session-end-cleanup`. |",
    "| SessionEnd | `hooks/session-end-cleanup.py` | ① kill switch → ② 끝나는 세션의 `.claude/spec-distill/<sid>/` 삭제(v0.6.0) → ③ `finally` 에서 TTL-GC(`scripts/spec-distill-gc.py`) 기동(2.0.0) — payload 가 깨져도 GC 는 돈다. polite-stop이나 approve 누락 시에도 cleanup 보장. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` / `:session-end-cleanup` — **세션 정리와 TTL-GC 를 함께 끈다**. GC 만 끄려면 `spec-distill:spec-distill-gc`. |")
cut("**Output schema (v0.5.0+):**", "`plugins/quality-gates/hooks/stop-hook.py:845-849`.\n",
    "**Output:** SessionEnd 훅은 stdout 을 내지 않는다 — 실패(stdin 판독 · GC 비정상 종료)는 `[spec-distill]` 접두의 stderr 로만 알린다.\n")
cut("### 발견의 한계\n", "성립하지 않는다(테스트가 그 경우 fail-closed 로 거부한다).\n\n")

# ── Kill switches ──
cut("### 먼저 — 무엇이 리뷰의 범위를 정하는가\n",
    "리뷰 라운드 참조). 이 표가 그 조건을 설명하는 유일한 자리입니다.\n",
    "### 먼저 — 설계문서 리뷰를 끄는 법\n\n"
    "설계문서 리뷰 진입은 `reviewing-spec` 이 엔진 라운드 전에 도는 진입 검사(`scripts/review_entry.py` + 리터럴 펜스)가 판정한다. 끄는 스위치는 셋이고 셋 다 수동 호출(`/spec-distill:reviewing-spec`)까지 끈다: `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · 플러그인 전체 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 진입 검사 자신이 실패하면(모듈 부재 · rc≠0 · 출력 계약 위반) 끔으로 친다 — 그 사실이 advisory 로 나오고 brainstorming 의 사용자 리뷰 게이트로 돌아간다. 전부 세션 스코프 env var 라 재시작이 필요하다.\n")
cut("- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0, v0.8.0 확대",
    "brainstorming 산출물 review를 일시 정지하고 싶을 때.\n",
    "- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` (v0.3.0, 2.0.0 재정의) — `reviewing-spec` 진입 검사가 설계문서 리뷰를 끈다 — **수동 호출 포함** skill 전체다(1.x 까지는 자동 리뷰와 구조 검사만 끄고 수동 호출은 살아 있었다). 파일 분류(content-aware 판별)는 없다 — 이 skill 은 받은 경로를 `design-doc.md` 프로필로 리뷰한다.\n"
    "- `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` (2.0.0) — 같은 효과의 이름 붙은 스위치. 수신처는 `scripts/review_entry.py` 의 진입 검사다(`spec-distill:review-entry`) — 훅이 아니지만 지목할 이름을 갖는다(`spec-distill-gc` 와 같은 관례).\n")
replace("(alias: `spec-distill:session-end-cleanup`) — SessionEnd cleanup hook만 skip. TTL-GC가 backup으로 작동.",
        "(alias: `spec-distill:session-end-cleanup`) — SessionEnd 훅 전체를 끈다: 끝나는 세션의 폴더 정리 **와** TTL-GC 기동 둘 다. GC 만 끄려면 아래 `spec-distill:spec-distill-gc`.")
replace("TTL-GC 스크립트(`scripts/spec-distill-gc.py`)만 skip.",
        "TTL-GC 스크립트(`scripts/spec-distill-gc.py` — SessionEnd 훅이 기동한다)만 skip.")
cut("- 자동 dispatch 가 G6 상한(3회)에 닿으면", "검증만 남기고 dispatch 만 끄는 스위치는 없다.\n")
cut("### 은퇴한 스위치 (v0.36.0)\n", "  작업이다.\n",
    "### 은퇴한 스위치 (v0.36.0 · 2.0.0)\n\n"
    "`PostToolUse` validator 와 `UserPromptSubmit` reminder(v0.36.0), 설계문서 리뷰 훅(2.0.0)이 삭제되면서 다음이 아무것도 끄지 않게 됐다. `reviewing-spec` 의 진입 검사가 리뷰를 부를 때마다 advisory 로 알린다.\n\n"
    "- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` (2.0.0) — 가리키던 훅이 삭제됐다. **리뷰를 막지 않는다** — 이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다. 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`. 이 토큰은 TTL-GC 도 더 이상 멈추지 않는다.\n"
    "- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` / `:validator` (v0.36.0) — 끄던 구조 검사가 삭제돼 아무것도 끄지 않는다.\n"
    "- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder` (v0.36.0) — 재-nag 층 자체가 없다.\n"
    "- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.36.0) — 읽는 곳이 없다. 설계문서 리뷰를 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`.\n")

P.write_text(s, encoding="utf-8")
print("README 편집 완료")
```

- [ ] **Step 3: 돌린다**

Run: `python3 .claude/plan-baseline/task7_readme.py`
Expected: `README 편집 완료`. `[중단]` 이면 그 앵커를 README 에서 Read 로 보고 스크립트의 앵커를 현재 텍스트에 맞춘다(중단 시 파일은 쓰지 않는다).

- [ ] **Step 4: 주석 하나** — `plugins/spec-distill/tests/test_probe_sweep_residue.sh` 51 줄:

old: `# 플러그인 안에서만도 7개 파일에 다른 백스톱(재리뷰 cap, arm-once 등)을 가리키며 legitimately`
new: `# 플러그인 안에서만도 여러 파일에 다른 백스톱(재리뷰 cap 등)을 가리키며 legitimately`

- [ ] **Step 5: README 를 재는 락을 돌린다** (한 명령씩)

- `bash plugins/spec-distill/tests/test_readme_sync.sh` → `Fail: 0`
- `bash plugins/spec-distill/tests/test_brief_review_meta.sh` → `Fail: 0` (Flow 다이어그램 순서 · Kill switches · Principles)
- `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh` → `Fail: 0` (C6 — 코드가 읽는 `DEVBREW_SPEC_DISTILL_*DISABLE*` 가 `### 스위치 목록` 에 있다)
- `bash shared/tests/test_dispatch_name_defined.sh` → `Fail: 0` (`spec-distill:review-entry` · `spec-distill:spec-distill-gc` 가 해소된다)
- `bash plugins/spec-distill/tests/test_handoff_kill_switch.sh` · `test_no_wall_clock.sh` · `test_rereview_cap_consistency.sh` · `test_stale_terms.sh` · `test_probe_sweep_residue.sh` → `Fail: 0`

이어서 이름 락의 **이빨**을 한 번 본다 — 새 스위치의 수신처가 사라지면 README 가 매달리는가:

Run: `python3 -c 'import pathlib; p=pathlib.Path("plugins/spec-distill/scripts/review_entry.py"); t=p.read_text(encoding="utf-8"); p.write_text(t.replace("kill_switch_active(\"spec-distill\", \"review-entry\")", "kill_switch_active(\"spec-distill\", \"review-entry-x\")"), encoding="utf-8")'`
Run: `bash shared/tests/test_dispatch_name_defined.sh` → RED, `매달림: … spec-distill:review-entry`
Run: `git checkout -- plugins/spec-distill/scripts/review_entry.py` (Task 1 에서 커밋된 판으로 되돌린다 — 이 파일은 이 Task 에서 편집하지 않았다)
Run: `git status --porcelain -- plugins/spec-distill/scripts/review_entry.py` → 빈 출력

- [ ] **Step 6: CHANGELOG** — `### Changed` 끝에:

```markdown
- **README.** 흐름도의 Stop 상자를 「오케스트레이터가 그 경로로 reviewing-spec 호출 — 훅 강제 없음」으로, Principles Instantiated 에서 훅·원장·구조 검증 서술을 걷고 「리뷰 진입은 집행이 아니다」(P13 기준 이 자리의 집행 소실)와 「Law 1 필수 섹션 게이트 구현 0」을 명시했다. Hooks Installed 는 SessionEnd 한 행(TTL-GC 기동 포함, 스위치가 두 층을 함께 끈다), kill switch 절은 「먼저 — 설계문서 리뷰를 끄는 법」 + `DESIGN_MODE_DISABLE` 재정의 + `spec-distill:review-entry` 추가, 은퇴 절은 2.0.0 토큰 둘을 더하고 v0.36.0 항목의 「끄려면 `spec-distill:Stop`」 권고를 걷었다(훅 삭제 뒤 거짓이 되는 문장). 「발견의 한계」 · 「행동 케이스 테스트」 · 「무엇이 리뷰의 범위를 정하는가」 절은 대상과 함께 지웠다. `tests/test_readme_sync.sh` 의 키워드는 `armed_paths` · `arm-once` → `spec-distill:review-entry` · `review_entry.py`.
```

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh plugins/spec-distill/tests/test_probe_sweep_residue.sh plugins/spec-distill/CHANGELOG.md
git commit -m "docs(spec-distill): README — 리뷰 진입은 집행이 아니다 · SessionEnd GC · 은퇴 스위치 2.0.0" -m "흐름도 · Principles · Hooks Installed · kill switch · 은퇴 절. Law 1 필수 섹션 게이트 구현 0 과 P13 기준 집행 소실을 명시한다." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 8: 부재 락 (AC1·AC2·AC7)

AC1 · AC2 · AC7. 삭제의 완결을 **도출 오라클**로 잰다 — 검사 목록을 손으로 적지 않는다(설계 AC2 · 메모리 「삭제 스윕은 개념 별칭으로」 · 「whack-a-mole 은 방식이 원인」). 규칙은 계획 작성 중 현재 트리에 dry-run 했다: 도출 식별자 111 · 살아 있는 어휘로 제외 13 · 잔존 인용 파일 21 — 21 전부가 이 계획의 수정 목록 안이었다(목록 밖 0). 개념 별칭 dry-run 도 걸린 38 줄이 전부 수정 목록 안이었다. 그러므로 Task 1–7 을 마친 트리에서 이 락은 처음부터 GREEN 이어야 하고, RED 면 앞 Task 가 인용을 남긴 것이다.

**Files:**
- Create: `plugins/spec-distill/tests/test_review_hook_removed.py`
- Modify: `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: base 커밋 `c7b4f580`(삭제 파일의 원본) · 현재 `hook_common.py`(빠진 이름 도출) · Task 4 의 SKILL 절 이름과 마커.

- [ ] **Step 1: 락을 쓴다** — `plugins/spec-distill/tests/test_review_hook_removed.py`:

```python
#!/usr/bin/env python3
"""AC1 · AC2 · AC7 — 설계문서 리뷰 훅 제거의 부재 락.

AC2 의 검사 목록은 손으로 적지 않고 아래 `DELETED` 에서 **도출**한다(base 커밋 `BASE` 의 원본):
  S1 삭제 파일 이름 — 코어는 stem, 테스트·fixture 는 basename.
  S2 삭제 코어 .py 의 공개 함수·클래스·대문자 상수 + `hook_common.py` 에서 빠진 최상위 이름
     (base AST − 현재 AST). `_` 나 낙타 대문자를 가진 6자 이상만 — `main`·`discover` 같은
     일반어는 삭제 식별자가 될 수 없다.
  S3 그 대문자 상수의 문자열 값에 든 상태 키(`<snake>:`).
  S4 삭제 코어 .py 의 `DEVBREW_*` 문자열.
  S5 삭제 코어 .py 의 하이픈 소문자 문자열(CLI 하위 명령 등).
S2·S4·S5 에서는 **살아 있는 어휘**를 뺀다: base 에서 삭제도 수정도 하지 않은 파일
(`DELETED` ∪ `EDITED` ∪ 역사 밖)에 이미 나오는 이름은 이 변경의 인용이 아니다. S4 는 추가로
지금 트리의 비-테스트 .py 가 문자열로 쥔 변수(살아 있는 스위치)를 뺀다.

「현재형」은 기계로 가르지 않고 면제 코퍼스로 정한다(설계 AC2):
  (a) 역사 — `*/CHANGELOG.md` · `docs/archive/**` · `docs/audits/README.md` ·
      `docs/superpowers/{specs,plans,interview}/**` · 날짜 붙은 `docs/audits/*.md`
  (b) 은퇴 토큰 리터럴 **만** — `scripts/review_entry.py` · `tests/test_review_entry.py` ·
      README 「은퇴한 스위치」 절(절 헤딩부터 다음 `## ` 까지). 그 안의 다른 삭제 식별자는 RED.
  (c) 이 파일 자신.
면제를 넓힐 때는 이 docstring 에 이유를 함께 적는다.

개념 별칭(`ALIASES`)은 일반어라 리포 전체에 걸면 무관한 파일이 걸린다 — spec-distill 배포 파일
(`tests/`·CHANGELOG 제외)과 설계 §5 의 공용 파일로 한정한다.

재지 못하는 것: 문장이 현재형인지(면제 코퍼스로 대신한다). `EDITED` 에서 빠진 인용 파일이 있으면
그 파일이 인용한 S2·S4·S5 이름은 살아 있는 어휘로 오인된다 — `test_report_live_vocabulary` 가
제외 목록과 그 사유 파일을 출력한다. 사람이 그 목록을 볼 것.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed
"""
from __future__ import annotations

import ast
import functools
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SELF = "plugins/spec-distill/tests/test_review_hook_removed.py"
BASE = "c7b4f580"
SD = "plugins/spec-distill"

DELETED_CORE = (
    f"{SD}/hooks/review-dispatch.py",
    f"{SD}/scripts/arm_ledger.py",
    f"{SD}/scripts/discover_candidates.py",
    f"{SD}/scripts/parse_spec_structure.py",
    f"{SD}/scripts/resolve_mode.py",
    f"{SD}/scripts/ambiguity-blacklist.txt",
    f"{SD}/templates/spec-template.md",
)
DELETED_OTHER = tuple(f"{SD}/tests/{n}" for n in (
    "test_arm_ledger.py", "test_arm_ledger_timing.sh", "test_arm_once.sh", "arm_test_helpers.sh",
    "test_discover_candidates.py", "test_discovery_driven_dispatch.py",
    "test_parse_spec_structure.sh", "test_resolve_mode_scope.sh", "test_review_dispatch.sh",
    "test_review_dispatch_design_mandate.sh", "test_review_dispatch_disposition.sh",
    "test_stop_absorbs_validation.py", "test_write_path_behavior.sh",
)) + tuple(f"{SD}/tests/fixtures/{n}" for n in (
    "2026-05-17-test-design.md", "spec-valid.md", "spec-missing-goals.md",
    "spec-ambiguity-line12.md", "spec-ambiguity-escaped.md",
    "design-no-frontmatter.md", "design-tbd.md",
)) + (
    "shared/tests/fixtures/adjudication/block_disposition_decoy.py",
    "shared/tests/fixtures/adjudication/run_block_disposition_count.py",
)
DELETED = DELETED_CORE + DELETED_OTHER
HOOK_COMMON = f"{SD}/scripts/hook_common.py"

#: 이 변경이 인용을 고친 파일(새 파일 제외). base 에서 여기에만 나오는 이름은 살아 있는 어휘가 아니다.
EDITED = (
    f"{SD}/.claude-plugin/plugin.json", f"{SD}/hooks/hooks.json",
    f"{SD}/hooks/session-end-cleanup.py", HOOK_COMMON,
    f"{SD}/scripts/state_path.py", f"{SD}/scripts/check_brief.py",
    f"{SD}/scripts/codex_prompt_common.py",
    f"{SD}/skills/reviewing-spec/SKILL.md", f"{SD}/skills/reviewing-brief/SKILL.md",
    f"{SD}/skills/conducting-interview/references/finishing.md",
    f"{SD}/templates/interview-brief-template.md", f"{SD}/README.md",
    f"{SD}/tests/test_hook_output_schema.py", f"{SD}/tests/test_reviewing_spec_design_only.sh",
    f"{SD}/tests/test_session_end_cleanup.py", f"{SD}/tests/test_brainstorming_entry.sh",
    f"{SD}/tests/test_brief_review_meta.sh", f"{SD}/tests/test_stale_terms.sh",
    f"{SD}/tests/test_readme_sync.sh", f"{SD}/tests/test_probe_sweep_residue.sh",
    f"{SD}/tests/test_reviewing_spec_state_keying.sh",
    f"{SD}/tests/test_handoff_context_empty_subsections.sh",
    f"{SD}/tests/test_handoff_conversation_reference.sh",
    "plugins/quality-gates/.claude-plugin/plugin.json",
    "plugins/quality-gates/scripts/codex_prompt_common.py",
    "shared/codex/codex_prompt_common.py", "shared/docreview/scripts/docreview_state.py",
    "shared/tests/test_adjudication_wiring.sh",
    "tools/adjudication/check_wiring.py", "tools/adjudication/check_names.py",
)

HISTORY = re.compile(
    r"(^|/)CHANGELOG\.md$|^docs/archive/|^docs/audits/README\.md$"
    r"|^docs/superpowers/(specs|plans|interview)/|^docs/audits/\d{4}-\d{2}-\d{2}-"
)
#: (b) 면제 — 긴 것부터 가린다. 가린 자리는 같은 길이의 공백이라 줄 번호가 보존된다.
RETIRED_LITERALS = (
    "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW", "spec-distill:UserPromptSubmit",
    "spec-distill:review-dispatch", "spec-distill:PostToolUse", "spec-distill:validator",
    "spec-distill:reminder", "spec-distill:Stop", ":review-dispatch", ":validator", ":reminder",
)
LITERAL_EXEMPT_FILES = (f"{SD}/scripts/review_entry.py", f"{SD}/tests/test_review_entry.py")
README = f"{SD}/README.md"
README_RETIRED_HEADING = re.compile(r"^### 은퇴한 스위치")

ALIAS_SCOPE_EXTRA = (
    "shared/codex/codex_prompt_common.py", "plugins/quality-gates/scripts/codex_prompt_common.py",
    "shared/docreview/scripts/docreview_state.py", "tools/adjudication/check_names.py",
)
#: (별칭 정규식, 그것이 실제로 매치하는 표본) — 표본은 계측기 확인용.
ALIASES = (
    (r"Stop ?(훅|hook)", "Stop 훅이"),
    (r"\[Stop:", "[Stop: 발견"),
    (r"(?<![\w-])mandate(?![\w-])", "the mandate says"),
    (r"arm 원장", "arm 원장을"),
    (r"arm-once", "arm-once 게이트"),
    (r"(?<![\w-])born(?![\w-])", "c.born 검사"),
    (r"in-flight 표시", "in-flight 표시를"),
    (r"구조 검증", "구조 검증을"),
    (r"REDISPATCH", "REDISPATCH_TTL"),
    (r"G6 상한", "G6 상한에"),
    (r"자동 dispatch", "자동 dispatch 가"),
    (r"훅이 읽는", "훅이 읽는 파일"),
    (r"발견의 한계", "### 발견의 한계"),
)

SPECIFIC = re.compile(r"_|[a-z][A-Z]")
KEY_RE = re.compile(r"(?<![A-Za-z0-9_])([a-z]+(?:_[a-z]+)+):")
ENV_RE = re.compile(r"^DEVBREW_[A-Z0-9_]+$")
HYPHEN_RE = re.compile(r"^[a-z]+(?:-[a-z]+)+$")


def git(*args: str, check: bool = True) -> str:
    cp = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, check=check)
    return cp.stdout.decode("utf-8", "replace")


def base_text(path: str) -> str:
    return git("show", f"{BASE}:{path}")


def head_files() -> list[str]:
    return git("ls-files", "--cached", "--others", "--exclude-standard").splitlines()


def consts(tree: ast.Module):
    for n in tree.body:
        if isinstance(n, ast.Assign):
            for tg in n.targets:
                if isinstance(tg, ast.Name):
                    yield tg.id, n.value


def strings(node) -> list[str]:
    return [n.value for n in ast.walk(node)
            if isinstance(n, ast.Constant) and isinstance(n.value, str)]


def top_names(tree: ast.Module) -> set[str]:
    out = {n.name for n in tree.body if isinstance(n, (ast.FunctionDef, ast.ClassDef))}
    return out | {k for k, _ in consts(tree)}


def boundary(tok: str) -> str:
    return r"(?<![\w-])" + re.escape(tok) + r"(?![\w-])"


@functools.lru_cache(maxsize=None)
def derivation():
    s1 = {Path(p).stem for p in DELETED_CORE} | {Path(p).name for p in DELETED_OTHER}
    trees = [ast.parse(base_text(p)) for p in DELETED_CORE if p.endswith(".py")]
    hc_base = ast.parse(base_text(HOOK_COMMON))
    hc_head = ast.parse((REPO / HOOK_COMMON).read_text(encoding="utf-8"))
    hc_removed = top_names(hc_base) - top_names(hc_head)

    s2 = set(hc_removed)
    for t in trees:
        s2 |= {n.name for n in t.body
               if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and not n.name.startswith("_")}
        s2 |= {k for k, _ in consts(t) if k.isupper()}
    s2 = {n for n in s2 if len(n) >= 6 and SPECIFIC.search(n)}

    s3 = set()
    for t in trees:
        for k, v in consts(t):
            if k.isupper():
                for s in strings(v):
                    s3.update(KEY_RE.findall(s))
    for k, v in consts(hc_base):
        if k in hc_removed and k.isupper():
            for s in strings(v):
                s3.update(KEY_RE.findall(s))

    s4, s5 = set(), set()
    for t in trees:
        for s in strings(t):
            if ENV_RE.match(s):
                s4.add(s)
            if HYPHEN_RE.match(s):
                s5.add(s)

    skip = set(DELETED) | set(EDITED)
    stop = {}
    for tok in sorted(s2 | s4 | s5):
        rx = re.compile(boundary(tok))
        for line in git("grep", "-l", "-F", "-e", tok, BASE, "--", check=False).splitlines():
            path = line.split(":", 1)[1]
            if path in skip or HISTORY.search(path):
                continue
            if rx.search(base_text(path)):
                stop[tok] = path
                break

    live_env = set()
    for f in head_files():
        if not f.endswith(".py") or "/tests/" in f or f in DELETED:
            continue
        p = REPO / f
        if p.is_symlink() or not p.is_file():
            continue
        try:
            live_env |= set(strings(ast.parse(p.read_text(encoding="utf-8")))) & s4
        except (SyntaxError, UnicodeDecodeError):
            continue

    tokens = (s1 | s3 | ((s2 | s4 | s5) - set(stop))) - live_env
    return {"S1": s1, "S2": s2, "S3": s3, "S4": s4, "S5": s5}, stop, live_env, frozenset(tokens)


def masked(path: str, text: str) -> str:
    def blank(ln: str) -> str:
        for lit in RETIRED_LITERALS:
            ln = ln.replace(lit, " " * len(lit))
        return ln
    if path in LITERAL_EXEMPT_FILES:
        return blank(text)
    if path == README:
        out, inside = [], False
        for ln in text.split("\n"):
            if README_RETIRED_HEADING.match(ln):
                inside = True
            elif inside and ln.startswith("## "):
                inside = False
            out.append(blank(ln) if inside else ln)
        return "\n".join(out)
    return text


def scan_text(path: str, text: str, tokens) -> list[str]:
    rx = re.compile(r"(?<![\w-])(" + "|".join(
        re.escape(t) for t in sorted(tokens, key=len, reverse=True)) + r")(?![\w-])")
    return [f"{path}:{i}: {m.group(1)}"
            for i, ln in enumerate(masked(path, text).splitlines(), 1)
            for m in rx.finditer(ln)]


def read_head(path: str):
    p = REPO / path
    if p.is_symlink() or not p.is_file():
        return None
    try:
        return p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


class TestHooksJson(unittest.TestCase):
    """AC1 — `Stop` 이 없고 `SessionEnd` 가 있다(부재 ↔ 존재 짝)."""

    def test_no_stop_and_session_end_present(self):
        d = json.loads((REPO / SD / "hooks" / "hooks.json").read_text(encoding="utf-8"))
        hooks = d.get("hooks", {})
        self.assertNotIn("Stop", hooks)
        cmds = [h.get("command", "") for blk in hooks.get("SessionEnd", [])
                for h in blk.get("hooks", [])]
        self.assertTrue(any("session-end-cleanup.py" in c for c in cmds), cmds)


class TestDeletedFiles(unittest.TestCase):
    """AC2 — 삭제 파일 부재 + 후계 파일 존재."""

    def test_deleted_paths_absent(self):
        self.assertEqual([p for p in DELETED if (REPO / p).exists()], [])

    def test_successors_present(self):
        for p in (f"{SD}/hooks/session-end-cleanup.py", f"{SD}/scripts/review_entry.py",
                  HOOK_COMMON):
            with self.subTest(p=p):
                self.assertTrue((REPO / p).is_file())


class TestDerivationInstrument(unittest.TestCase):
    """계측기 — 도출이 비지 않았고 스캐너가 실제 잔존을 잡는다."""

    def test_base_commit_reachable(self):
        cp = subprocess.run(["git", "-C", str(REPO), "cat-file", "-e", f"{BASE}^{{commit}}"],
                            capture_output=True)
        self.assertEqual(cp.returncode, 0,
                         f"base 커밋 {BASE} 가 없다(얕은 클론?) — 도출 불가, 이 락은 fail-closed")

    def test_derived_sets_not_vacuous(self):
        d, _, _, tokens = derivation()
        self.assertEqual(len(d["S1"]), len(DELETED))
        self.assertGreaterEqual(len(d["S2"]), 30)
        self.assertGreaterEqual(len(d["S3"]), 7)
        self.assertGreaterEqual(len(tokens), 80)

    def test_scanner_finds_residue_in_base_readme(self):
        """양성 대조 — base 의 README(이 변경 전)에는 인용이 가득했다. 못 잡으면 스캐너가 죽었다."""
        hits = scan_text(README, base_text(README), derivation()[3])
        self.assertGreaterEqual(len(hits), 10, hits)

    def test_report_live_vocabulary(self):
        _, stop, live_env, _ = derivation()
        sys.stderr.write("\n[살아 있는 어휘로 제외] " + ", ".join(
            f"{k} ← {v}" for k, v in sorted(stop.items())) + "\n")
        sys.stderr.write("[살아 있는 스위치로 제외] " + ", ".join(sorted(live_env)) + "\n")

    def test_alias_canaries(self):
        for pat, sample in ALIASES:
            with self.subTest(pat=pat):
                self.assertRegex(sample, pat)


class TestResidue(unittest.TestCase):
    """AC2 — 삭제 식별자(리포 전체)와 개념 별칭(한정 범위)의 잔존."""

    def test_no_identifier_residue(self):
        tokens = derivation()[3]
        hits = []
        for f in head_files():
            if f == SELF or HISTORY.search(f):
                continue
            text = read_head(f)
            if text is not None:
                hits += scan_text(f, text, tokens)
        self.assertEqual(hits, [], "\n".join(hits[:60]))

    def _alias_scope(self) -> list[str]:
        files = [f for f in head_files() if f.startswith(SD + "/")
                 and "/tests/" not in f and not f.endswith("CHANGELOG.md")]
        return files + list(ALIAS_SCOPE_EXTRA)

    def test_alias_scope_not_vacuous(self):
        scope = self._alias_scope()
        self.assertGreaterEqual(len(scope), 30)
        for must in (README, f"{SD}/skills/reviewing-spec/SKILL.md", *ALIAS_SCOPE_EXTRA):
            with self.subTest(must=must):
                self.assertIn(must, scope)
                self.assertIsNotNone(read_head(must))

    def test_no_alias_residue_in_scope(self):
        rx = re.compile("|".join(f"(?:{p})" for p, _ in ALIASES))
        hits = []
        for f in self._alias_scope():
            text = read_head(f)
            if text is None:
                continue
            for i, ln in enumerate(text.splitlines(), 1):
                m = rx.search(ln)
                if m:
                    hits.append(f"{f}:{i}: [{m.group(0)}] {ln.strip()[:100]}")
        self.assertEqual(hits, [], "\n".join(hits[:60]))


class TestReviewingSpecContract(unittest.TestCase):
    """AC7 — 옛 입력 계약의 부재 + 새 입력 계약의 존재."""

    SKILL = REPO / SD / "skills" / "reviewing-spec" / "SKILL.md"

    def test_old_input_contract_absent(self):
        t = self.SKILL.read_text(encoding="utf-8")
        for pat in (r"\$mode\b", r"mode: (design|spec)", r"\$STATE(?![_A-Za-z0-9])",
                    r"arm_ledger", r"## 원장", r"clear-inflight", r"mark-reviewed",
                    r"check-born", r"mandate"):
            with self.subTest(pat=pat):
                self.assertIsNone(re.search(pat, t), pat)

    def test_new_input_contract_present(self):
        t = self.SKILL.read_text(encoding="utf-8")
        self.assertIn('STATE_DIR="$ROOT/$harness_sid"', t)
        self.assertIn("<!-- review-entry:begin -->", t)
        self.assertIn("<!-- uncommitted-check:begin -->", t)
        m = re.search(r"^## 입력\n(.*?)^## ", t, re.S | re.M)
        self.assertIsNotNone(m, "## 입력 절을 못 찾았다")
        self.assertIn("호출 인자", m.group(1))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 돌린다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed`
Expected: `OK` (13 tests). stderr 의 「살아 있는 어휘로 제외」 목록을 읽는다 — dry-run 에서는 `DEVBREW_SKIP_HOOKS` · `DEVBREW_SPEC_DISTILL_DISABLE` · `FRONTMATTER_RE` · `SCRIPTS_DIR` · `SCRIPT_DIR` · `find_missing_sections` · `ls-files` · `out-of-scope` · `rev-parse` · `reviewing-spec` · `seed_body` · `skip_reason` · `spec-distill` 열셋이었고, 「살아 있는 스위치로 제외」는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` · `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW`(`review_entry.py` 가 읽는다)여야 한다. 사유 파일이 **삭제된 코드를 인용하는 파일**이면 그 파일이 `EDITED` 에서 빠진 것이다 — 그 파일을 고치고 `EDITED` 에 더한다.

RED 면 출력의 `path:line: token` 을 하나씩 본다. 대부분은 앞 Task 가 남긴 인용이다 — 그 자리를 인용만 걷는 방식으로 고치고(Task 3·6 과 같은 규칙), 고친 파일이 `EDITED` 에 없으면 더한다. **면제를 넓혀 GREEN 을 만들지 않는다** — 넓혀야 할 이유가 있으면 docstring 에 이유를 적고, 이 Task 의 커밋 메시지와 CHANGELOG 에도 적는다.

- [ ] **Step 3: 이 락이 guards 커버리지 락과 충돌하지 않는지 본다**

Run: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh`
Expected: `Fail: 0` — Task 4·5 의 두 셸 락이 `# guards:` 와 `--emit-scanned` 를 같은 목록으로 낸다. 이 python 락은 `# guards:` 대상(셸 락)이 아니다.

- [ ] **Step 4: CHANGELOG** — `### Added` 끝에:

```markdown
- **부재 락 `tests/test_review_hook_removed.py`(AC1 · AC2 · AC7).** 검사 목록을 손으로 적지 않는다 — base 커밋의 삭제 파일에서 파일 이름 · 공개 이름 · 상태 키 · 환경변수 · 하이픈 문자열을 도출하고, base 에서 이 변경이 손대지 않은 파일에 이미 나오는 이름은 살아 있는 어휘로 뺀다. 면제 코퍼스는 역사(CHANGELOG · archive · 설계·계획·인터뷰 문서 · 날짜 붙은 감사) + 은퇴 토큰 리터럴(`review_entry.py` · 그 테스트 · README 은퇴 절에서 토큰 리터럴만)이다. 개념 별칭 13개(`Stop 훅` · `mandate` · `arm-once` · `구조 검증` 등)는 spec-distill 배포 파일과 설계 §5 공용 파일로 한정해 잰다. 양성 대조로 base README(변경 전)에서 잔존을 실제로 잡는지 확인한다. **재지 못하는 것**: 수정 목록(`EDITED`)에서 빠진 인용 파일이 있으면 그 파일이 인용한 이름은 살아 있는 어휘로 오인된다 — 제외 목록과 사유 파일을 출력한다.
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_review_hook_removed.py plugins/spec-distill/CHANGELOG.md
git commit -m "test(spec-distill): 리뷰 훅 제거의 부재 락 — 삭제 집합에서 도출한 오라클" -m "AC1 hooks.json · AC2 식별자(리포 전체)·개념 별칭(한정 범위)·파일 부재 · AC7 reviewing-spec 옛 입력 계약 부재. 양성 대조: base README 에서 잔존 검출." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016f1dSy9WhzTQfUGXPhYmuK"
```

---

### Task 9: 회귀 비교 + 변이 검증

AC12 · AC13 · 설계 Verification Plan 1·3. 코드 변경 없음(찾은 결함은 해당 Task 의 파일을 고쳐 새 커밋으로 낸다).

**Files:**
- Create: `.claude/plan-baseline/after/` (결과) · `.claude/plan-baseline/mutate.py` (git 무시)

- [ ] **Step 1: 스위트 전체를 다시 돌린다** (백그라운드)

Run: `bash .claude/plan-baseline/run_suites.sh .claude/plan-baseline/after`

- [ ] **Step 2: 새 실패를 뽑는다** (AC12 — 비교 키는 실패 식별자 집합)

Run: `comm -13 .claude/plan-baseline/before/failing_ids.txt .claude/plan-baseline/after/failing_ids.txt`
Expected: **빈 출력**. 나오는 줄마다 둘 중 하나로 판정한다: (가) 새 실패 — 원인을 고친다. (나) 같은 실패의 메시지만 바뀐 것(예: 재작성한 락의 문구) — `before/REASONS.md` 의 그 항목 옆에 「after 에서 문구만 바뀜: <새 줄>」 을 적는다. (나)로 판정할 때는 before·after 로그 두 줄을 나란히 인용한다.

보조 지표: `diff <(cut -f1,3 .claude/plan-baseline/before/summary.tsv) <(cut -f1,3 .claude/plan-baseline/after/summary.tsv)` 로 파일별 실패 줄 수를 본다(삭제한 테스트 13 개의 행이 사라지는 것은 정상). 줄 수가 같아도 식별자가 바뀌었을 수 있으므로 Step 2 가 판정의 기준이다.

- [ ] **Step 3: 변이 실행기를 쓴다** — 워킹 트리가 **깨끗하고 커밋된** 상태에서만 돈다(`git checkout --` 은 «내 마지막 변이»가 아니라 HEAD 로 되돌린다 — 이 실행기는 원문 바이트를 들고 있다가 되돌린다). Write 도구로 `.claude/plan-baseline/mutate.py`:

```python
#!/usr/bin/env python3
"""AC13 변이 행렬. 사용: python3 .claude/plan-baseline/mutate.py

각 변이: 대상 파일의 old 를 new 로 한 번 바꾸고 → 락을 돌리고 → 원문 바이트로 되돌린다.
old 가 정확히 1회가 아니면 그 행은 BROKEN(계측기 고장)이다. expect 가 red 인 행은 락이
실패해야 하고, green 인 행(양성 대조)은 통과해야 한다. 되돌린 뒤 파일이 HEAD 와 다르면 FAIL.
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                           text=True, check=True).stdout.strip())
ENV = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
SD = "plugins/spec-distill"
T = "cd plugins/spec-distill/tests && python3 -m unittest"
LOCK = {
    "entry": f"{T} test_review_entry",
    "sessionend": f"{T} test_session_end_cleanup",
    "fence": f"bash {SD}/tests/test_reviewing_spec_entry_fence.sh",
    "order": f"bash {SD}/tests/test_review_handoff_order.sh",
    "removed": f"{T} test_review_hook_removed",
    "keying": f"bash {SD}/tests/test_reviewing_spec_state_keying.sh",
    "designonly": f"bash {SD}/tests/test_reviewing_spec_design_only.sh",
    "handoff": f"bash {SD}/tests/test_handoff_context_empty_subsections.sh",
}
RE = f"{SD}/scripts/review_entry.py"
SE = f"{SD}/hooks/session-end-cleanup.py"
SK = f"{SD}/skills/reviewing-spec/SKILL.md"
FIN = f"{SD}/skills/conducting-interview/references/finishing.md"
TPL = f"{SD}/templates/interview-brief-template.md"
RB = f"{SD}/skills/reviewing-brief/SKILL.md"
M = [
    # ── test_review_entry (AC4 · AC5) ──
    ("E1 삭제: design 모드 스위치", RE,
     '    if os.environ.get(DESIGN_MODE_VAR) == "1":\n        return f"{DESIGN_MODE_VAR}=1"\n', "",
     "entry", "red"),
    ("E2 반전: disabled", RE, 'return {"disabled": reason is not None, "reason": reason,',
     'return {"disabled": reason is None, "reason": reason,', "entry", "red"),
    ("E3 형태: 부분 문자열 매칭", RE, "gone_hit = [t for t in GONE_TOKENS if t in tokens]",
     "gone_hit = [t for t in GONE_TOKENS if t in raw]", "entry", "red"),
    ("E4 형태: 설정만 보면 발화", RE, "if os.environ.get(AUTOREVIEW_VAR) == \"1\":",
     "if os.environ.get(AUTOREVIEW_VAR) is not None:", "entry", "red"),
    ("E5 추가: 없는 대체재를 댄다", RE, '            f"아무것도 끄지 않는다."\n',
     '            f"아무것도 끄지 않는다. {ALTERNATIVES}"\n', "entry", "red"),
    ("E6 반전: 판정과 무관하게 '진행된다'", RE, '("이번 리뷰는 진행된다." if reason is None',
     '("이번 리뷰는 진행된다." if True', "entry", "red"),
    ("E+ 양성 대조", RE, "#: 자동 리뷰를 끄던 토큰. 리뷰 기능은 남아 있으므로 대체 스위치를 댄다.",
     "#: 자동 리뷰를 끄던 토큰. 리뷰 기능은 남아 있으므로 대체 스위치를 댄다. ", "entry", "green"),
    # ── test_session_end_cleanup (AC3) ──
    ("S1 형태: finally 제거", SE,
     "    try:\n        cleanup_ending_session()\n    finally:\n        fire_and_forget_gc()\n",
     "    cleanup_ending_session()\n    fire_and_forget_gc()\n", "sessionend", "red"),
    ("S2 순서: GC 를 kill switch 앞으로", SE,
     '    if kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd"):\n        return 0\n',
     '    fire_and_forget_gc()\n    if kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd"):\n        return 0\n',
     "sessionend", "red"),
    ("S3 삭제: GC 호출", SE, "    finally:\n        fire_and_forget_gc()\n",
     "    finally:\n        pass\n", "sessionend", "red"),
    ("S4 삭제: run_hook 의 cwd 가드", f"{SD}/tests/test_session_end_cleanup.py",
     '    if cwd is None:\n        raise ValueError("run_hook: cwd 필수 — GC 가 러너 cwd 의 실제 상태 루트를 돌지 않게")\n',
     "", "sessionend", "red"),
    ("S+ 양성 대조", SE, "# 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제로 이어지지 않도록.",
     "# 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제로 이어지지 않도록. ", "sessionend", "green"),
    # ── test_reviewing_spec_entry_fence (AC6 · AC9 · AC16) ──
    ("F1 형태: disabled 타입 검사 약화", SK, '      and isinstance(d.get("disabled"), bool)\n',
     '      and "disabled" in d\n', "fence", "red"),
    ("F2 삭제: rc 검사", SK, '  if [ "$entry_rc" -ne 0 ]; then', "  if false; then", "fence", "red"),
    ("F3 삭제: 복귀 지시 출력", SK,
     "[ \"$verdict\" = \"review-entry: PROCEED\" ] || printf '%s\\n' \"$RETURN_MSG\"\n", "",
     "fence", "red"),
    ("F4 삭제: 미커밋 rc 검사", SK, 'if [ "$born_rc" -ne 0 ]; then', "if false; then", "fence", "red"),
    ("F5 형태: pathspec 에 전체 경로", SK,
     'born_out="$(git -C "$spec_dir" status --porcelain -- "$spec_base" 2>/dev/null)"',
     'born_out="$(git -C "$spec_dir" status --porcelain -- "$spec_path" 2>/dev/null)"', "fence", "red"),
    ("F+ 양성 대조", SK, "엔진 라운드 전에 한 번 돈다. 끄기 판정은 이 펜스가 하고,",
     "엔진 라운드 전에 한 번 돈다.  끄기 판정은 이 펜스가 하고,", "fence", "green"),
    # ── test_review_handoff_order (AC8 · AC16 정적) ──
    ("O1 역순: ① 템플릿", FIN,
     "다음 단계: Skill superpowers:brainstorming <brief-path> → 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:reviewing-spec → 그 승인 게이트에서 진행을 고른 뒤 superpowers:writing-plans.",
     "다음 단계: Skill superpowers:brainstorming <brief-path> → superpowers:writing-plans → 그 설계문서 경로로 Skill spec-distill:reviewing-spec.",
     "order", "red"),
    ("O2 추가: ① 새 placeholder", FIN, "그 승인 게이트에서 진행을 고른 뒤 superpowers:writing-plans.`",
     "그 승인 게이트에서 진행을 고른 뒤 superpowers:writing-plans <design-path>.`", "order", "red"),
    ("O3 삭제: ② 우선 문장", FIN,
     "brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다. ", "", "order", "red"),
    ("O4 삭제: description 의 'before'", SK,
     "(docs/superpowers/specs/...-design.md), before superpowers:writing-plans — this review replaces",
     "(docs/superpowers/specs/...-design.md) — this review replaces", "order", "red"),
    ("O5 삭제: 대상 부재의 복귀 지시", SK,
     "— handoff 진행 안 함. 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).`",
     "— handoff 진행 안 함.`", "order", "red"),
    ("O6 삭제: §7 의 reviewing-spec", TPL,
     " → 그 설계문서 경로로 `spec-distill:reviewing-spec`(brainstorming 의 사용자 리뷰 게이트 대신) → 승인",
     " → 승인", "order", "red"),
    ("O+ 양성 대조", FIN, "이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.",
     "이것은 아래 cross-compact 정지 요건의 *명시적 예외*다. ", "order", "green"),
    # ── test_review_hook_removed (AC1 · AC2 · AC7) ──
    ("R1 추가: 식별자 잔존(상태 키)", RB, "경로는 `state_path.py` 리졸버로 구합니다.",
     "경로는 `state_path.py` 리졸버로 구합니다(`inflight_paths` 없음).", "removed", "red"),
    ("R2 추가: 별칭 잔존", RB, "경로는 `state_path.py` 리졸버로 구합니다.",
     "경로는 `state_path.py` 리졸버로 구합니다 — Stop 훅과 무관.", "removed", "red"),
    ("R3 면제 경계: (b) 는 리터럴만", RE,
     "#: 자동 리뷰를 끄던 토큰. 리뷰 기능은 남아 있으므로 대체 스위치를 댄다.",
     "#: 자동 리뷰를 끄던 토큰(check-born 과 무관). 리뷰 기능은 남아 있으므로 대체 스위치를 댄다.",
     "removed", "red"),
    ("R4 추가: README 은퇴 절 안의 별칭", f"{SD}/README.md",
     "이 토큰은 TTL-GC 도 더 이상 멈추지 않는다.",
     "이 토큰은 TTL-GC 도 더 이상 멈추지 않는다(arm-once 와 무관).", "removed", "red"),
    ("R5 추가: hooks.json 의 Stop", f"{SD}/hooks/hooks.json",
     '  "hooks": {\n    "SessionEnd": [', '  "hooks": {\n    "Stop": [],\n    "SessionEnd": [',
     "removed", "red"),
    ("R6 추가: SKILL 의 $STATE", SK, 'STATE_DIR="$ROOT/$harness_sid"\n',
     'STATE_DIR="$ROOT/$harness_sid"\nSTATE="$STATE_DIR/state.local.md"\n', "removed", "red"),
    ("R+ 양성 대조: 역사 면제", "docs/superpowers/plans/2026-09-11-spec-review-hook-removal.md",
     "# spec-distill 리뷰 훅 제거 Implementation Plan\n",
     "# spec-distill 리뷰 훅 제거 Implementation Plan\n\narm_ledger check-born Stop 훅\n",
     "removed", "green"),
    # ── 재조준한 락 셋 ──
    ("K1 형태: STATE_DIR 의 sid 키잉", SK, 'STATE_DIR="$ROOT/$harness_sid"\n',
     'STATE_DIR="$ROOT/x"\n', "keying", "red"),
    ("D1 삭제: 프로필 고정 문장", SK, "프로필은 `design-doc.md` 로 **고정**이다",
     "프로필은 `design-doc.md` 를 쓴다", "designonly", "red"),
    ("H1 형태: defer 착지점 이름", f"{SD}/references/docreview-profiles/design-doc.md",
     'heading: "### Deferred to plan"', 'heading: "### Deferred"', "handoff", "red"),
]

if subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
                  text=True).stdout.strip():
    sys.exit("[중단] 워킹 트리가 깨끗하지 않다 — 커밋한 뒤 돌려라")
bad = 0
for label, rel, old, new, lock, expect in M:
    f = ROOT / rel
    orig = f.read_bytes()
    text = orig.decode("utf-8")
    n = text.count(old)
    if n != 1:
        print(f"BROKEN\t{label}\told 가 {n}회")
        bad += 1
        continue
    f.write_bytes(text.replace(old, new).encode("utf-8"))
    try:
        rc = subprocess.run(["bash", "-c", LOCK[lock]], cwd=ROOT, env=ENV,
                            capture_output=True, timeout=900).returncode
    finally:
        f.write_bytes(orig)
    dirty = subprocess.run(["git", "status", "--porcelain", "--", rel], cwd=ROOT,
                           capture_output=True, text=True).stdout.strip()
    got = "red" if rc != 0 else "green"
    ok = got == expect and not dirty
    bad += 0 if ok else 1
    print(f"{'OK' if ok else 'FAIL'}\t{label}\t기대 {expect} · 실제 {got} (rc={rc})"
          f"{' · 복원 후 dirty' if dirty else ''}")
print(f"\n{len(M)}행 중 문제 {bad}")
sys.exit(1 if bad else 0)
```

- [ ] **Step 4: 돌린다**

Run: `python3 .claude/plan-baseline/mutate.py`
Expected: 모든 행 `OK`, 마지막 줄 `문제 0`. 판정:
- `BROKEN` — old 문자열이 지금 파일과 다르다(앞 Task 에서 문안이 바뀌었다). 파일의 현재 문안으로 old/new 를 고치고 **같은 축**(삭제/추가/반전/형태)을 유지해 다시 돈다.
- `FAIL … 기대 red · 실제 green` — 그 락에 이빨이 없다. 락을 고친다(설계 AC13). 고친 락은 새 커밋으로 내고 이 행렬을 처음부터 다시 돈다.
- `FAIL … 기대 green · 실제 red` — 양성 대조가 깨졌다: 락이 무관한 편집에도 RED 다(과민 또는 계측기 고장). 원인을 본다.
- `복원 후 dirty` — 실행기 결함. 즉시 멈추고 `git diff` 로 상태를 본다.

- [ ] **Step 5: 결과를 남긴다** — Step 2·4 의 출력 전문을 `.claude/plan-baseline/VERIFY.md` 에 붙이고, Task 12 의 PR 본문에 요약(새 실패 0 · 변이 N행 OK)을 옮긴다.

---

### Task 10: /qg 구현 리뷰

설계 Verification Plan 4 — kill switch 판정은 보안 컨트롤이므로 codex 교차 리뷰를 포함한다(메모리: 보안 컨트롤은 codex 독립 리뷰 필수 · codex 호출은 사전 승인됨 — 게이트 없이 부르고 태운 횟수를 보고한다). 이 Task 는 **오케스트레이터가** 한다(하위 에이전트는 슬래시 명령을 못 부른다).

- [ ] **Step 1:** `/qg` 를 브랜치 전체(base `c7b4f580` 대비) 범위로 돌린다. 게이트 범위 질문에는 review 게이트 + codex 를 고른다. 설계문서 경로를 AC 원천으로 쓴다 — qg 의 spec 자동 탐색은 mtime 최신을 고르므로 새 워크트리에서는 무관한 문서를 집을 수 있다(메모리 `reference_qg_discover_spec_newest_mtime`). 러너 첫 줄에 찍힌 spec 경로가 `docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md` 인지 확인하고, 아니면 `SPEC_AC_FILE` 로 지정해 다시 돈다.
- [ ] **Step 2:** findings 를 받아 처분한다 — 수정할 것은 해당 Task 의 파일을 고치고 그 Task 의 락 + `test_review_hook_removed.py` + `mutate.py` 를 다시 돌린 뒤 `fix(spec-distill): …` 커밋. 기각할 것은 이유를 PR 본문에 적는다. **findings → 편집 사이에 adversarial 판정을 둔다**(메모리: 29건 중 4건이 순감이었다).
- [ ] **Step 3:** 태운 codex 호출 수와 degrade 여부를 PR 본문에 적는다.

---

### Task 11: 수동 e2e (AC14)

사용자 결정 D8 · D11. 모델 행동은 흔들리므로 게이트된 헤드리스 테스트로 두지 않고 1회 수동 관찰한다. **사용자가 대화형 세션을 띄워야 한다** — 오케스트레이터는 절차를 안내하고 결과를 PR 에 적는다.

- [ ] **Step 1: 스크래치 리포를 만든다** — 경로에 `.claude` 가 들어가면 안 된다(Claude Code 가 그 아래를 sensitive 로 보고 쓰기를 거부한다).

```bash
mkdir -p ~/sd-e2e-20260911 && git -C ~/sd-e2e-20260911 init -q
```

- [ ] **Step 2: 수정된 플러그인을 실어 띄운다** — 사용자에게 안내:

```
cd ~/sd-e2e-20260911 && claude --plugin-dir /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+remove-spec-review-hook/plugins/spec-distill
```

superpowers 는 사용자의 기존 설치를 쓴다(`CLAUDE_CONFIG_DIR` 격리는 superpowers 까지 빠져 brainstorming 을 못 부르므로 쓰지 않는다).

- [ ] **Step 3: 새 판이 실렸는지 표식을 확인한다(교란 배제)** — 세션 첫 동작으로 `/hooks` 를 연다. spec-distill 항목이 **SessionEnd 하나**이고 명령 경로가 위 워크트리의 `hooks/session-end-cleanup.py` 이며 **Stop 항목이 없어야 한다.** 설치본(캐시)의 옛 판이 함께 실려 Stop 훅이 보이면 그 관찰은 무효다 — `/plugin` 에서 설치본 spec-distill 을 끄고 세션을 다시 연다. 이어서 `/interview` 가 skill 을 부를 때 출력되는 「Base directory for this skill:」 경로가 워크트리인지 본다. agent 이름(`doc-critic` 있음 · `spec-reviewer` 없음)은 표식이 못 된다 — base `c7b4f580` 도 그 조건을 만족한다.
- [ ] **Step 4: ② 경로(통과 조건)** — `/interview 할일 CLI 에 마감일 필드 추가` 처럼 짧은 주제로 인터뷰를 끝까지 간다(brief 리뷰는 `cost_class: high` 게이트에서 「건너뛰고 Step B로」를 골라 비용을 줄여도 된다). Step B 에서 **② 확정하고 바로 brainstorming** 을 고른다. 관찰할 것: brainstorming 이 설계문서를 쓰고 커밋한 뒤, **writing-plans 전에** 오케스트레이터가 `spec-distill:reviewing-spec` 을 부르는가.
- [ ] **Step 5: 관찰되지 않으면 보강한다 — 최대 2회(D11).** Task 5 의 ② 호출 프롬프트 문장을 더 직접적으로 고친다(예: 「설계문서를 커밋하면 **다음 도구 호출은** `Skill spec-distill:reviewing-spec <그 경로>` 다」). 고친 뒤 Task 5 의 락 · Task 9 의 `order` 변이 행을 다시 돌리고 커밋한 다음 Step 2 부터 다시 관찰한다. 두 번 보강해도 관찰되지 않으면 **머지 전에 사용자에게 묻는다**(`AskUserQuestion` — 머지 보류 / 한계로 기록하고 진행).
- [ ] **Step 6: ① 경로(관찰·기록만)** — 새 스크래치 리포에서 같은 절차로 **① 확정하고 /compact 후 brainstorming** 을 고르고, `/compact` 실행 뒤 다음 턴에 `Skill superpowers:brainstorming <경로>` 로 진입한다. 리뷰 호출 여부를 기록한다 — compact 요약이 운반자라 손실이 있을 수 있다(통과 조건 아님).
- [ ] **Step 7: PR 에 남긴다** — 이 형식으로:

```markdown
## AC14 수동 e2e
- 표식: `/hooks` → spec-distill SessionEnd 1개 (`<경로>`), Stop 없음 · skill base dir `<경로>`
- ② 경로: 설계문서 커밋 `<sha>` → reviewing-spec 호출 **[관찰됨 | 안 됨]** → writing-plans · 보강 <0|1|2>회
- ① 경로: **[관찰됨 | 안 됨]** (기록만)
```

---

### Task 12: 머지 직전 — 번호 확정과 PR

C5 · 메모리 「릴리스 번호는 머지 직전에 정하라」(같은 버전 문자열은 충돌 없이 병합된다 — git 이 알려주지 않는다).

- [ ] **Step 1: base 이동량을 잰다** — `git fetch origin` 후 `git log --oneline c7b4f580..origin/main` 과 `git merge-tree --write-tree HEAD origin/main` 로 충돌·자동 병합 파일을 본다. 자동 병합되는 파일(특히 README · CHANGELOG · `check_wiring.py`)은 따로 읽는다.
- [ ] **Step 2: 번호를 확정한다** — `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` · `git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json` 의 version 을 본다. main 이 spec-distill `1.0.0` · qg `7.5.1` 그대로면 `2.0.0` · `7.5.2` 를 유지한다. 올라가 있으면 spec-distill 은 main 의 다음 major, qg 는 main 의 다음 patch 로 plugin.json · CHANGELOG 헤딩 · CHANGELOG 본문 안의 자기 번호 인용(`[2.0.0]` · 「2.0.0 에서」 등 — `grep -rn '2\.0\.0' plugins/spec-distill plugins/quality-gates` 로 전수)을 함께 바꾸고, main 을 **merge** 로 들여온다(rebase 금지). CHANGELOG 날짜도 머지일로 맞춘다.
- [ ] **Step 3:** 번호를 바꿨으면 Task 9 Step 1–2 를 다시 돈다(`test_changelog_integrity.sh` 포함).
- [ ] **Step 4: PR** — 사용자 확인 뒤 `git push -u origin feature/remove-spec-review-hook` 와 `gh pr create`. 본문: 요약 · 설계 경로 · AC 추적표 · Task 9 결과 요약 · Task 10 findings 처분 · Task 11 e2e · 알려진 한계(설계 「알려진 한계」 여섯) · 끝에 `🤖 Generated with [Claude Code](https://claude.com/claude-code)` 와 세션 링크. 머지는 사용자가 `! gh pr merge <n> --merge` 로 한다(오케스트레이터의 `gh pr merge` 는 auto mode 판정기가 막는다) — 머지 뒤 PR 상태가 MERGED 인지 직접 확인한다.

---

### Task 13: 머지 뒤 — 메모리 갱신

설계 §7 · Law 3. 리포 밖 파일이라 커밋이 없다. **머지가 확인된 뒤에만** 한다(그 전에는 옛 메모리가 여전히 사실이다).

- [ ] **Step 1:** `/Users/jeonghokim/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/reference_commit_before_turn_end_disarms_review_hook.md` — 대상 메커니즘이 사라졌다. 파일을 지우고 `MEMORY.md` 의 그 인덱스 줄(「턴 끝나기 전 커밋이 리뷰 훅을 끈다」)도 지운다. 남길 교훈이 있으면(두 계약이 커밋 순서를 반대로 가정했다) `project_cross_skill_seam_handoff.md` 로 한 문장 옮긴다.
- [ ] **Step 2:** `project_cross_skill_seam_handoff.md` — 「미결 설계 결정 D1」 문단을 「D1 결정됨(PR #<n>, <머지일>): ③의 변형 — 자동 진행은 유지하고 강제만 버렸다. 턴을 넘는 강제 메커니즘은 이제 0 개다」로 고친다. `MEMORY.md` 의 그 줄 설명(「턴 넘는 강제는 Stop 훅 1개뿐」)도 같이 고친다.
- [ ] **Step 3:** 이 작업의 프로젝트 메모리를 하나 쓴다(`project_spec_review_hook_removal.md`) — 머지 SHA · 알려진 한계 둘(직접 경로의 약함 · Law 1 구현 0) · AC14 결과 · 남은 일. `MEMORY.md` 에 한 줄 인덱스.

---

## AC 추적표

| AC | 내용 | 구현 | 락 · 검증 |
|---|---|---|---|
| AC1 | hooks.json 에 Stop 없음 · SessionEnd 있음 | Task 3 Step 2 | `test_review_hook_removed.py` `TestHooksJson` · 변이 R5 |
| AC2 | 삭제 7 파일 부재 · 식별자·별칭 잔존 없음(도출) | Task 3 · 4 · 6 · 7 | `test_review_hook_removed.py` · 변이 R1–R4 · R+ |
| AC3 | SessionEnd 가 TTL-GC 를 `finally` 에서 · 스위치 행렬 · 테스트 격리 | Task 2 | `test_session_end_cleanup.py` 9–16 · 변이 S1–S4 |
| AC4 | `disabled` 판정 행렬 | Task 1 | `test_review_entry.py` `TestDisabledVerdict` · 변이 E1 · E2 |
| AC5 | 은퇴 스위치 일곱 · 접미·`=0` 무발화 · D9 · 대체재 규칙 | Task 1 | `test_review_entry.py` `TestRetiredSwitchAdvisory` · 변이 E3–E6 |
| AC6 | 진입 펜스 fail-closed | Task 4 | `test_reviewing_spec_entry_fence.sh` · 변이 F1 · F2 |
| AC7 | 옛 입력 계약 부재 | Task 4 | `test_review_hook_removed.py` `TestReviewingSpecContract` · `test_reviewing_spec_state_keying.sh` · 변이 R6 · K1 |
| AC8 | 네 자리의 순서 · ① 새 placeholder 없음 | Task 4(description) · 5 | `test_review_handoff_order.sh` · 변이 O1–O4 · O6 |
| AC9 | 미커밋 · git 오류 · 작업 트리 밖 advisory | Task 4 | `test_reviewing_spec_entry_fence.sh` · 변이 F4 · F5 |
| AC10 | 배선·이름 락 GREEN · baseline 재계수 | Task 3 · 7 | `test_adjudication_wiring.sh` · `test_dispatch_name_defined.sh` · Task 7 Step 5 이빨 확인 |
| AC11 | §5 인용 없음 · 사본 일치 | Task 3 · 6 | `test_copy_of_contract.sh` · `test_review_hook_removed.py` |
| AC12 | 새 실패 0 (식별자 집합) | 전체 | Task 0 · Task 9 Step 2 |
| AC13 | 새 락 전부 변이 RED(양성 대조 포함) | — | Task 9 Step 3–4 |
| AC14 | 수동 e2e — ② 필수 · 보강 ≤2 · ① 기록 | Task 11 | PR 기록 |
| AC15 | README · CHANGELOG · bump | Task 1 · 6 · 7 · 12 | `test_readme_sync.sh` · `test_changelog_integrity.sh` |
| AC16 | 게이트 없는 두 경로가 복귀 지시로 끝남 · ② 가 분기를 싣는다 | Task 4 · 5 | 행동: `test_reviewing_spec_entry_fence.sh`(F3) · 정적: `test_review_handoff_order.sh`(O5) |

설계 Goals: G1 → Task 3 · G2 → Task 5 · G3 → Task 4(description) · G4 → Task 1 · 4 · G5 → Task 2 · 3 · 7.

