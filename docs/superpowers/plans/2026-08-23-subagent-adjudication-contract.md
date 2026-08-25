# subagent 판정 계약 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** subagent 발견의 처분(`수용·기각·보류`)과 「버린 것의 회계」를 `shared/` 의 공통 파이썬 모듈로 구현하고, dispatch 자리 18곳이 자기 처분을 기계 판독 한 줄로 밝히게 하며, 그 둘을 락 하나로 묶는다.

**Architecture:** 정본 `shared/adjudication/adjudication.py` 를 두고 소비자가 사는 플러그인의 `scripts/` 에 상대 심볼릭 링크로 배포한다. dispatch 자리마다 `**처분** — consumer=… · fail-… [· disclosure=…]` 앵커 한 줄을 붙이고, `shared/tests/test_dispatch_disposition.sh` 가 축 A(앵커 1:1 귀속·서식·닫힌 어휘·경로 실재) · 축 B(`.py` 소비자의 import) · 축 C(`disclosure=` 리터럴 실재) 로 묶는다. 새 `.md` 정본은 만들지 않고 규정 문면은 `CLAUDE.md` 와 `docs/plugin-authoring.md` 에 흡수한다.

**Tech Stack:** Python 3 (표준 라이브러리만) · bash (`shared/tests/assert.sh` 하네스) · git 심볼릭 링크 · `/qg` Runtime gate

**Spec:** `docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md`

## 목차

- [Global Constraints](#global-constraints)
- [PR0 결과 — 앵커 18줄](#pr0-결과--앵커-18줄-이-계획서-작성-중-실측-확정)
- [File Structure](#file-structure)
- [PR1 — 모듈 정본 + 배포 링크](#pr1--모듈-정본--배포-링크)
  - [Task 1: 회계 모듈 + 단위 테스트](#task-1-회계-모듈--단위-테스트)
  - [Task 2: 배포 링크 2개 + `shared/README.md` 갱신](#task-2-배포-링크-2개--sharedreadmemd-갱신)
- [PR2 — 결함 수리 9건 + 소비자 4개 전환](#pr2--결함-수리-9건--소비자-4개-전환)
  - [Task 3: `merge_review.py` — 결함 #1~#6 + Ledger 전환](#task-3-merge_reviewpy--결함-16--ledger-전환)
  - [Task 4: `synthesize_findings.py` — 결함 #7 #8 + Ledger 전환](#task-4-synthesize_findingspy--결함-7-8--ledger-전환)
  - [Task 5: `synthesize_artifact_findings.py` 기계적 전환](#task-5-synthesize_artifact_findingspy-기계적-전환)
  - [Task 6: `merge_brief_review.py` 기계적 전환](#task-6-merge_brief_reviewpy-기계적-전환)
  - [Task 7: `audit-workflow.js` 결함 #9 + PR2 버전 bump](#task-7-audit-workflowjs-결함-9--pr2-버전-bump)
- [PR3 — 앵커 18줄 + dispatch 락 + mutation](#pr3--앵커-18줄--dispatch-락--mutation)
  - [Task 8: 락의 도출·인쇄·vacuity 하한](#task-8-락의-도출인쇄vacuity-하한)
  - [Task 9: 축 A① · A② + 앵커 18줄](#task-9-축-a--a--앵커-18줄)
  - [Task 10: 축 A③ · A④](#task-10-축-a--a)
  - [Task 11: 축 B · 축 C](#task-11-축-b--축-c)
  - [Task 12: mutation M1~M18 + PR3 버전 bump](#task-12-mutation-m1m18--pr3-버전-bump)
- [PR4 — 규정 문면](#pr4--규정-문면)
  - [Task 13: `CLAUDE.md` + `docs/plugin-authoring.md`](#task-13-claudemd--docsplugin-authoringmd)
- [이 계획이 남기는 것 — 닫지 않은 것들](#이-계획이-남기는-것--닫지-않은-것들)

## Global Constraints

- **Law 2** — 리뷰어는 `Write`/`Edit` 를 갖지 않는다. 이 계획은 agent 정의의 `tools:` 를 건드리지 않는다.
- **버전 bump** — `plugins/<name>/` 을 건드리는 모든 PR 은 같은 커밋에서 `plugin.json` SemVer bump + `CHANGELOG.md` 항목을 낸다. 현재 버전: `agent-transparency 0.2.3` · `plugin-audit 0.6.0` · `quality-gates 4.2.3` · `spec-distill 0.33.0`.
- **Korean-primary** — 주석·문서는 한국어 primary, 영어는 식별자·고유명사·기술어에 한정.
- **파일 읽기는 명시적 UTF-8** — 생성 파일을 읽는 모든 코드는 `encoding="utf-8"` 을 명시한다 (non-UTF-8 locale fail-open 방지).
- **mutation 실행 환경** — `PYTHONDONTWRITEBYTECODE=1` 로 돌린다. 같은 길이 변이가 stale `.pyc` 를 못 넘어 거짓 GREEN/거짓 RED 를 낸다.
- **`shared/` 는 플러그인이 아니다** — bump 대상이 아니고 설치본에 들어가지 않는다.
- **새 실행 지점을 만들지 않는다** — 락은 `/qg` Runtime gate 에서만 돈다. 새 훅도 새 kill switch 도 없다.
- **락 메시지의 변수 뒤 한글** — `printf "${tot}개"` 처럼 **반드시 중괄호**. `"$tot개"` 는 bash 가 `tot개` 를 변수명으로 읽어 조용히 빈 값을 낸다.
- **파이썬 heredoc 을 `$( … )` 안에 넣지 않는다.** Task 8~11 이 같은 heredoc 을 늘리는데, 본문에 `r'(?=["\'\s,)]|$)'` 같은 `\'` + `)` 조합이 하나라도 들어오면 `OUT="$(python3 - <<'PY' … PY)"` 형태가 `bash -n` 단계에서 죽는다. 정본은 **파일로 받는 형태**(`python3 - … > "$TMPD/out.txt" <<'PY'` … `PY` … `OUT="$(cat "$TMPD/out.txt")"`) — 그러면 셸이 파이썬 내용을 아예 안 본다. **모든 shell 편집 뒤 `bash -n` 을 돌린다.**

---

## PR0 결과 — 앵커 18줄 (이 계획서 작성 중 실측 확정)

설계 §11 은 이것을 별도 PR 로 두었으나 계획서가 placeholder 없이 성립하려면 값이 먼저 있어야 하므로 여기서 확정했다. **아래 표가 Task 3~13 전체의 입력이다.**

측정 기준선 — 워크트리 HEAD `aa40619` (공유 `main` `dd1a838` 의 `ead6835..dd1a838` 이동 2커밋은 전부 `plugins/project-init/` 이며 dispatch 표기를 건드리지 않았다. 에이전트 정의 수 18 불변).

| # | 앵커가 들어갈 파일 | dispatch 줄 | 에이전트 | 앵커 본문 | 배치 |
|---|---|---|---|---|---|
| 1 | `plugins/agent-transparency/skills/briefing-current-state/SKILL.md` | 6 | transcript-reader | `**처분** — consumer=human · fail-open · disclosure=blocks:` | frontmatter 닫힘(`---`, 9행) 직후 본문 첫 블록 |
| 2 | `plugins/plugin-audit/scripts/audit-workflow.js` | 18 | plugin-auditor | `// **처분** — consumer=plugins/plugin-audit/scripts/audit-workflow.js · fail-open · disclosure=degradedEvents` | **18행과 19행 «사이에» 삽입** |
| 3 | `plugins/plugin-audit/scripts/audit-workflow.js` | 19 | audit-refuter | `// **처분** — consumer=plugins/plugin-audit/scripts/audit-workflow.js · fail-open · disclosure=degradedEvents` | 19행 바로 아래 |
| 4 | `plugins/plugin-audit/scripts/smoke-workflow.js` | 10 | smoke-probe | `// **처분** — consumer=orchestrator · fail-closed · disclosure=sentinelPath` | 10행 바로 아래 |
| 5 | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` | 136 | artifact-critic | `// **처분** — consumer=plugins/quality-gates/scripts/synthesize_artifact_findings.py · fail-closed` | **코드펜스 안** → `//` 주석 |
| 6 | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` | 194 | artifact-adversarial | `// **처분** — consumer=plugins/quality-gates/scripts/synthesize_artifact_findings.py · fail-closed` | 코드펜스 안 → `//` 주석 |
| 7 | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md` | 120 | pr-understanding-builder | `**처분** — consumer=human · fail-open · disclosure=notes (accuracy)` | 산문 — 그 불릿 블록 끝 직후 |
| 8 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 366 | security-reviewer | `// **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open` | 코드펜스 안, **366행과 377행 사이** |
| 9 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 377 | adversarial | `// **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open` | 코드펜스 안, 377행 아래 |
| 10 | `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | 259 | test-scope-validator | `// **처분** — consumer=orchestrator · fail-open · disclosure=R2 산문` | 코드펜스 안 → `//` 주석 |
| 11 | `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` | 705 | runtime-verifier | `// **처분** — consumer=orchestrator · fail-closed · disclosure=baseline_unrunnable` | 코드펜스 안 → `//` 주석 |
| 12 | `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 254 | coverage-mapper | `// **처분** — consumer=orchestrator · fail-open · disclosure=advisory` | 코드펜스 안, **254행과 269행 사이** |
| 13 | `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 269 | blind-spot-prober | `// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory` | 코드펜스 안, 269행과 320행 사이 |
| 14 | `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 320 | steelman-builder | `// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory` | 코드펜스 안, 320행 아래 |
| 15 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 196 | brief-direction-reviewer | `// **처분** — consumer=human · fail-open · disclosure=verification_status` | 코드펜스 안 → `//` 주석 |
| 16 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 286 | brief-critic | `// **처분** — consumer=plugins/spec-distill/scripts/merge_brief_review.py · fail-open` | 코드펜스 안 → `//` 주석 |
| 17 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md` | 439 | brief-readback | `// **처분** — consumer=human · fail-open · disclosure=verification_status` | 코드펜스 안 → `//` 주석 |
| 18 | `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | 64 | spec-reviewer | `// **처분** — consumer=plugins/spec-distill/scripts/merge_review.py · fail-open` | 코드펜스 안 → `//` 주석 |

**검증 완료 사실** (BAD=0):

- 4개 `.py` 경로 전부 `git ls-files --error-unmatch` 통과 (축 A④ 경로 실재).
- 14개 `disclosure=` 리터럴 전부 해당 파일 본문에 실재 (축 C). 최소 출현 1회(`blocks:`), 최대 17회(`verification_status`).
- 코드펜스 소속 판정: 12곳 FENCE · 1곳 frontmatter · 1곳 산문 · 4곳 `.js`.

**`.py` 소비자 전수 목록 — 4개** (설계 §11 의 하한 5에서 하나 줄었다):

| 소비자 | 플러그인 | `items=` | 이 PR 에서 하는 일 |
|---|---|---|---|
| `plugins/quality-gates/scripts/synthesize_findings.py` | quality-gates | `"open"` | 결함 #7 · #8 수리 + 전환 |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` | quality-gates | `"closed"` | 기계적 전환 (이미 카운터 보유) |
| `plugins/spec-distill/scripts/merge_review.py` | spec-distill | `"open"` | 결함 #1~#6 수리 + 전환 |
| `plugins/spec-distill/scripts/merge_brief_review.py` | spec-distill | `"open"` | 기계적 전환 (이미 카운터 보유) |

**목록에서 빠진 것과 그 근거** — 이 셋은 설계가 후보로 열거했으나 실측이 배제했다:

| 후보 | 배제 근거 |
|---|---|
| `check_qa_ledger.py` | 테스트 실행 결과 원장(`--aggregate`, R8)을 읽는다. 어느 subagent 의 발견도 처분하지 않는다 |
| `plugins/plugin-audit/scripts/assemble-audit-data.py` | `plugin-auditor` 발견의 처분은 `audit-workflow.js` 안에서 끝난다(`:507`·`:520-526`). 이 파일은 이미 판정된 결과를 조립하고 **codex 쪽 입력만** 별도 sanitize 한다. 앵커에 이 이름을 적으면 축 B 는 통과하는데 진짜 처분(JS)은 계속 미회계로 남는다 |
| `plugins/plugin-audit/scripts/check-grounding.py` | 위와 같은 이유. `plugin-audit` 은 배포 링크를 받지 않는다 |

**귀결** — 배포 링크는 **2개**(`quality-gates`·`spec-distill`)뿐이다. 설계 §11 이 예상한 세 번째(`plugin-audit`)는 발생하지 않는다. 설계 §1.1 이 지적한 4갈래 어휘 분열 중 `assemble-audit-data.py` 의 `dropped[]` 는 **통일되지 않은 채 남는다** — 어느 축도 그것을 요구하지 않으므로 집행 없는 전환이 된다.

**락 도출 규칙 — 실측으로 확정된 두 가지**

1. **표기 정규식은 콜론까지 포함해야 한다.** `agentType`(콜론 없음)으로 쓰면 `plugins/plugin-audit/scripts/smoke-workflow.js:8` 의 `//` 주석(*"asserts `agent` appears exactly once with agentType 'plugin-audit:smoke-probe'"*)이 19번째 dispatch 로 잡혀 축 A① 이 거짓 RED 를 낸다. 정본은 `subagent_type:` · `agentType:` · `Agent\(` · `^\s*agent:\s`.
2. **표기 필터가 이름 매칭보다 «먼저» 걸려야 한다.** 순서를 뒤집으면 산문 속 영어 단어가 dispatch 로 잡힌다 — 실측: `critiquing-artifacts/SKILL.md` 에서 맨 `adversarial` 은 5줄에 등장하고(`:7`·`:127`·`:195`·`:208`·`:212`) 전부 산문이며 dispatch 표기 줄은 하나도 아니다.

---

## File Structure

| 파일 | 책임 | 신규/수정 |
|---|---|---|
| `shared/adjudication/adjudication.py` | 처분 회계 정본. 순수 클래스 하나, 형제 경로 해석 없음 | 신규 |
| `shared/tests/test_adjudication_behavior.sh` | 모듈 행동 고정 (7 메서드 · `blocks()` 조건 · `surfaced()` 방향) | 신규 |
| `shared/tests/test_dispatch_disposition.sh` | dispatch 락 (축 A①②③④ · B · C) | 신규 |
| `plugins/quality-gates/scripts/adjudication.py` | 정본을 가리키는 상대 심볼릭 링크 | 신규 (링크) |
| `plugins/spec-distill/scripts/adjudication.py` | 정본을 가리키는 상대 심볼릭 링크 | 신규 (링크) |
| `shared/README.md` | 디렉토리 표에 `adjudication/` 행 | 수정 |
| `plugins/spec-distill/scripts/merge_review.py` | 결함 #1~#6 + Ledger 전환 | 수정 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | 결함 #7 #8 + Ledger 전환 | 수정 |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` | Ledger 전환 | 수정 |
| `plugins/spec-distill/scripts/merge_brief_review.py` | Ledger 전환 | 수정 |
| `plugins/plugin-audit/scripts/audit-workflow.js` | 결함 #9 (1줄) + 앵커 2줄 | 수정 |
| 앵커 18곳 (위 표) | 처분 선언 | 수정 |
| `CLAUDE.md` · `docs/plugin-authoring.md` | 규정 문면 | 수정 |

---

# PR1 — 모듈 정본 + 배포 링크

## Task 1: 회계 모듈 + 단위 테스트

**Files:**
- Create: `shared/adjudication/adjudication.py`
- Test: `shared/tests/test_adjudication_behavior.sh`

**Interfaces:**
- Consumes: 없음 (표준 라이브러리만)
- Produces: `Ledger(items="open"|"closed")` 와 메서드 `accept(item)` · `reject(item, why)` · `hold(item, why)` · `absorbed(item, into)` · `coerced(field, frm, to, gate=False)` · `source_failed(name, why, primary=True)` · `uncountable(what, why)` · `report() -> dict` · `surfaced() -> list[dict]` · `blocks() -> bool`. Task 3~6 이 이것을 import 한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`shared/tests/test_adjudication_behavior.sh`:

```bash
#!/usr/bin/env bash
# guards: shared/adjudication/**
#
# 처분 회계 모듈의 **행동**을 고정한다.
#
# 왜 메서드 존재 검사로 부족한가: 일곱 메서드가 전부 있어도 `absorbed` 가
# degraded 를 올리면 흡수가 소실로 세어져 신호가 희석된다. 그래서 여기서는
# 각 메서드의 **부작용**(counts 의 어느 칸이 오르는가 · degraded 가 오르는가 ·
# blocks 가 오르는가)을 직접 관측한다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/adjudication/adjudication.py"
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
MOD="$HERE/../adjudication"

run() {   # run <python-body>  → stdout
  PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$MOD" python3 -c "$1"
}

# ── 1. 일곱 메서드가 counts 의 올바른 칸을 올린다
out="$(run '
from adjudication import Ledger
L = Ledger()
L.accept("a"); L.reject("b", "근거"); L.hold("c", "판정불가")
L.absorbed("d", into="a"); L.coerced("f", 5, 0)
L.source_failed("codex", "한도", primary=False); L.uncountable("issues", "리스트 미생성")
c = L.report()["counts"]
print(c["accepted"], c["rejected"], c["held"], c["absorbed"], c["coerced"], c["sources_failed"])
')"
assert_eq "$out" "1 1 1 1 1 1" "일곱 메서드가 각자 칸을 하나씩 올린다"

# ── 2. 흡수는 degraded 가 아니다 / 보류는 degraded 다  (양성 대조 쌍)
out="$(run 'from adjudication import Ledger
L = Ledger(); L.absorbed("x", into="y"); print(L.report()["degraded"])')"
assert_eq "$out" "False" "absorbed 는 degraded 를 올리지 않는다"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.hold("x", "왜"); print(L.report()["degraded"])')"
assert_eq "$out" "True" "hold 는 degraded 를 올린다 (양성 대조)"

# ── 3. 강제는 gate 여부로 갈린다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.coerced("raised_count", 5, 0, gate=False); print(L.report()["degraded"])')"
assert_eq "$out" "False" "coerced(gate=False) 는 degraded 가 아니다"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.coerced("raised_count", 5, 0, gate=True); print(L.report()["degraded"])')"
assert_eq "$out" "True" "coerced(gate=True) 는 degraded 다"

# ── 4. 원리적 미상은 unknown_counts 로 가고 정수 칸엔 안 들어간다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.uncountable("issues", "리스트 미생성")
r = L.report(); print(r["unknown_counts"], sum(r["counts"][k] for k in
  ("accepted","rejected","held","absorbed","coerced")))')"
assert_eq "$out" "['issues'] 0" "uncountable 은 unknown_counts 로 가고 정수 칸은 0"

# ── 5. blocks() 는 §9.1 의 «조건부» 규칙이다 — 무조건이 아니다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.hold("x", "왜"); print(L.blocks())')"
assert_eq "$out" "True" "held > 0 이면 blocks"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.uncountable("x", "왜"); print(L.blocks())')"
assert_eq "$out" "True" "unknown_counts 가 비지 않으면 blocks"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.source_failed("claude", "파싱불가", primary=True); print(L.blocks())')"
assert_eq "$out" "True" "주(主) source_failed 면 blocks"

#    양성 대조 (a) — 셋 다 아니면 blocks 아님
out="$(run 'from adjudication import Ledger
L = Ledger(); L.accept("a"); L.reject("b","근거"); L.absorbed("c", into="a")
print(L.blocks())')"
assert_eq "$out" "False" "양성대조(a): 소실도 미상도 주-실패도 없으면 blocks 아님"

#    양성 대조 (b) — 보조 source 실패는 degraded 이되 blocks 아님.
#    이 단언이 없으면 이 테스트는 «철회된 보편 규칙»(degraded 면 언제나 blocks)과
#    구별되지 않는다. 실측 근거: merge_review.py:461-465 는 codex(보조) 실패에도
#    combined = claude_verdict = approved 를 내고, test_merge_review.py:130-135(AC10)·
#    :144-148 · :154-158 이 그것을 계약으로 못 박았다.
out="$(run 'from adjudication import Ledger
L = Ledger(); L.source_failed("codex", "한도 소진", primary=False)
print(L.report()["degraded"], L.blocks())')"
assert_eq "$out" "True False" "양성대조(b): 보조 source 실패는 degraded 이되 blocks 아님"

# ── 6. surfaced() 의 방향
out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.hold("h", "왜"); L.uncountable("u", "왜")
print(len(L.surfaced()), sorted(x["label"] for x in L.surfaced()))')"
assert_eq "$out" "2 ['held', 'uncountable']" "items=open 은 미판정 항목을 라벨과 함께 낸다"
out="$(run 'from adjudication import Ledger
L = Ledger(items="closed"); L.hold("h", "왜"); L.uncountable("u", "왜")
print(len(L.surfaced()))')"
assert_eq "$out" "0" "items=closed 는 미판정 항목을 제외한다"

# ── 7. items 는 닫힌 어휘다
out="$(run 'from adjudication import Ledger
try:
    Ledger(items="sideways"); print("NO_RAISE")
except ValueError:
    print("RAISED")')"
assert_eq "$out" "RAISED" "items 에 세 번째 값을 주면 ValueError"

finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash shared/tests/test_adjudication_behavior.sh`
Expected: FAIL — 모든 `run` 이 `ModuleNotFoundError: No module named 'adjudication'` 로 죽어 stdout 이 비고 `assert_eq` 가 전부 `✗`.

- [ ] **Step 3: 모듈을 구현한다**

`shared/adjudication/adjudication.py`:

```python
"""subagent 발견의 처분 회계.

이 모듈은 **회계만** 한다. 출력 서식의 권위가 아니다 — 각 소비자는 자기 필드명으로
렌더한다(proceed-gate.md:34-37 이 필드 통일을 명시적으로 거절했고, 형제 `_norm_sev`
둘이 반대 방향 기본값을 각자 근거와 함께 갖는다).

네 가지 처분을 구별한다:
  소실       — 항목이 사라지고 아무도 세지 않음        → hold()
  흡수       — 중복이 흡수처에 귀속, 소실이 아님       → absorbed()
  강제       — 항목이 아니라 값을 대체                 → coerced()
  원리적 미상 — 개수를 셀 방법이 없음                  → uncountable()

`degraded`(공시)와 `blocks()`(차단)는 **다른 술어**다:
  blocks()  == held > 0  or  unknown_counts  or  주(主) source_failed
  degraded  == 위 셋 중 하나  or  보조 source_failed  or  coerced(gate=True)
"""

_ITEM_DIRECTIONS = ("open", "closed")


class Ledger:
    """처분 원장.

    items: 미판정 항목의 방향. 다음 소비자가 기계(자동 편집)면 "closed"(제외),
           사람이면 "open"(라벨을 붙여 보여준다). 소비자 «신원»이 아니라
           «방향»이 인자다.
    """

    def __init__(self, items="open"):
        if items not in _ITEM_DIRECTIONS:
            raise ValueError(
                "items must be one of %r, got %r" % (_ITEM_DIRECTIONS, items))
        self.items = items
        self._accepted = []          # [item]
        self._rejected = []          # [(item, why)]
        self._held = []              # [(item, why)]
        self._absorbed = []          # [(item, into)]
        self._coerced = []           # [(field, frm, to, gate)]
        self._sources_failed = []    # [(name, why, primary)]
        self._unknown = []           # [(what, why)]

    # ── 처분 ──────────────────────────────────────────────────────────
    def accept(self, item):
        """수용."""
        self._accepted.append(item)

    def reject(self, item, why):
        """기각 — 근거 있는 배제."""
        self._rejected.append((item, why))

    def hold(self, item, why):
        """보류 — 판정하지 못했다. 소실의 정직한 이름이다."""
        self._held.append((item, why))

    def absorbed(self, item, into):
        """흡수 — 중복이 `into` 에 귀속됐다. 소실이 아니므로 degraded 가 아니다."""
        self._absorbed.append((item, into))

    def coerced(self, field, frm, to, gate=False):
        """강제 — 항목이 아니라 값을 대체했다.

        gate=True 는 그 대체가 **게이트 판정을 바꾼다**는 뜻이다
        (예: raised_count 5→0 이 `>=3` 정체 게이트를 무력화). 그때만 degraded.
        """
        self._coerced.append((field, frm, to, bool(gate)))

    def source_failed(self, name, why, primary=True):
        """입력 자체가 죽었다.

        primary=True 는 그 축의 유일한 판정자(그것이 죽으면 아무도 안 봤다),
        False 는 모델 다양성 보조(codex 등 — 죽어도 축은 살아 있다).
        """
        self._sources_failed.append((name, why, bool(primary)))

    def uncountable(self, what, why):
        """개수를 원리적으로 모른다.

        0 이 아니다. 0 은 거짓 clean 이다.
        """
        self._unknown.append((what, why))

    # ── 파생 술어 ─────────────────────────────────────────────────────
    def _has_primary_source_failure(self):
        return any(primary for (_n, _w, primary) in self._sources_failed)

    def _has_gate_coercion(self):
        return any(gate for (_f, _a, _b, gate) in self._coerced)

    def blocks(self):
        """차단 — 항목이 소실됐거나 그 축의 주(主) 판정자가 죽었을 때만 참.

        보조(모델 다양성) 손실은 공시하되 막지 않는다. 무조건 True 로 만들면
        test_merge_review.py:130-135(AC10)·:144-148·:154-158 이 깨진다 —
        화석이 아니라 계약이다.
        """
        return (bool(self._held)
                or bool(self._unknown)
                or self._has_primary_source_failure())

    def _degraded(self):
        return (self.blocks()
                or bool(self._sources_failed)
                or self._has_gate_coercion())

    # ── 출력 ─────────────────────────────────────────────────────────
    def reasons(self):
        """degrade 사유를 사람이 읽는 한 줄씩."""
        out = []
        for (item, why) in self._held:
            out.append("보류: %s — %s" % (item, why))
        for (what, why) in self._unknown:
            out.append("셀 수 없음: %s — %s" % (what, why))
        for (name, why, primary) in self._sources_failed:
            out.append("입력 실패(%s): %s — %s"
                       % ("주" if primary else "보조", name, why))
        for (field, frm, to, gate) in self._coerced:
            if gate:
                out.append("강제(게이트 변경): %s %r→%r" % (field, frm, to))
        return out

    def report(self):
        return {
            "counts": {
                "accepted": len(self._accepted),
                "rejected": len(self._rejected),
                "held": len(self._held),
                "absorbed": len(self._absorbed),
                "coerced": len(self._coerced),
                "sources_failed": len(self._sources_failed),
            },
            "degraded": self._degraded(),
            "unknown_counts": [what for (what, _why) in self._unknown],
            "reasons": self.reasons(),
        }

    def surfaced(self):
        """미판정 항목 — items 방향에 따라 보여주거나 제외한다."""
        if self.items == "closed":
            return []
        out = [{"label": "held", "item": item, "why": why}
               for (item, why) in self._held]
        out += [{"label": "uncountable", "item": None, "what": what, "why": why}
                for (what, why) in self._unknown]
        return out
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `bash shared/tests/test_adjudication_behavior.sh`
Expected: PASS — 14개 assertion 전부 `✓`, `finish` 가 exit 0.

- [ ] **Step 5: 커밋**

```bash
git add shared/adjudication/adjudication.py shared/tests/test_adjudication_behavior.sh
git commit -m "feat(shared): 처분 회계 모듈 adjudication.Ledger 정본"
```

---

## Task 2: 배포 링크 2개 + `shared/README.md` 갱신

**Files:**
- Create: `plugins/quality-gates/scripts/adjudication.py` (상대 심볼릭 링크)
- Create: `plugins/spec-distill/scripts/adjudication.py` (상대 심볼릭 링크)
- Modify: `shared/README.md:23-30` (디렉토리 표)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1 의 `shared/adjudication/adjudication.py`
- Produces: `from adjudication import Ledger` 가 두 플러그인의 `scripts/` 에서 해석 가능. Task 3~6 이 이것에 의존한다.

⚠ **이 링크들은 리포 최초의 「import-only `.py` 심볼릭 링크」다** (설계 §12 R10). 문서화된 기본은 링크가 맞지만(`2026-08-16-devbrew-weight-reduction-design.md:445-448`), 기존 import-only `.py` 정본 다섯 종은 **전원 사본**이다. Step 4 의 `/qg` Runtime gate 실행이 이 위험을 실제로 재는 자리이며, RED 가 나면 Step 6 의 롤백을 즉시 실행한다.

- [ ] **Step 1: 상대 심볼릭 링크를 만든다**

```bash
ln -s ../../../shared/adjudication/adjudication.py plugins/quality-gates/scripts/adjudication.py
ln -s ../../../shared/adjudication/adjudication.py plugins/spec-distill/scripts/adjudication.py
```

- [ ] **Step 2: 링크가 실제 내용에 도달하는지 확인한다**

```bash
test -L plugins/quality-gates/scripts/adjudication.py && echo "LINK OK"
test -L plugins/spec-distill/scripts/adjudication.py && echo "LINK OK"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=plugins/quality-gates/scripts \
  python3 -c "from adjudication import Ledger; print(Ledger().report()['counts']['held'])"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=plugins/spec-distill/scripts \
  python3 -c "from adjudication import Ledger; print(Ledger().report()['counts']['held'])"
```

Expected: `LINK OK` ×2, `0` ×2.

**`# copy-of:` 마커를 쓰지 않는다** — 그것은 사본 방식의 계약이다. `test_no_new_duplication.sh` 는 `is_symlink()` 로 링크를 식별해 대상 경로를 마커 대상과 동등하게 처리한다. 동일성은 링크라서 구조적으로 깨질 수 없다.

- [ ] **Step 3: `shared/README.md` 디렉토리 표에 행을 추가한다**

`shared/README.md:30` 의 `| tests/ | ... |` 행 **위에** 다음 행을 넣는다 (알파벳 순으로 `adjudication/` 이 `codex/` 앞):

```markdown
| `adjudication/` | subagent 발견의 처분 회계 (수용·기각·보류 + 흡수·강제·입력실패·원리적 미상) |
```

결과 표는 `adjudication/` · `codex/` · `killswitch/` · `gc/` · `tests/` 5행이 된다.

> **이 행에는 락이 없다** (설계 §14 의 정직한 미집행 선언). `test_copy_of_contract.sh:287-291` 의 축 0 은 그 파일의 **계약 수** 서술만 단언하고 디렉토리 표는 보지 않는다. 이 행이 빠져도 어떤 테스트도 RED 가 되지 않으므로 사람이 챙긴다.

- [ ] **Step 4: 기존 락 + Runtime gate 를 돌려 R10 을 실제로 잰다**

```bash
bash shared/tests/test_copy_of_contract.sh
bash shared/tests/test_no_new_duplication.sh
bash shared/tests/test_adjudication_behavior.sh
```

Expected: 셋 다 exit 0. `test_copy_of_contract.sh` 의 축 1a 가 새 링크 2개를 「링크인가 · 존재하는 대상을 가리키는가 · 그 대상이 기대한 정본인가」로 검사하고 통과해야 한다.

그다음 `/qg` Runtime gate 를 실제로 돌려 설치 경로에서도 링크가 풀리는지 확인한다. **이 실행이 R10 의 유일한 측정이다** — 생략하면 선례 0인 배포 형태가 미검증으로 배달된다.

- [ ] **Step 5: 버전 bump + CHANGELOG**

`plugins/quality-gates/.claude-plugin/plugin.json`: `"version": "4.2.3"` → `"4.3.0"` (새 surface = minor)
`plugins/spec-distill/.claude-plugin/plugin.json`: `"version": "0.33.0"` → `"0.34.0"`

각 `CHANGELOG.md` 맨 위에:

```markdown
## [4.3.0] — 2026-08-23

### Added
- `scripts/adjudication.py` — `shared/adjudication/adjudication.py` 정본을 가리키는 상대 심볼릭 링크. subagent 발견의 처분 회계(`수용·기각·보류` + 흡수·강제·입력실패·원리적 미상). 리포 최초의 import-only `.py` 심볼릭 링크.
```

(spec-distill 은 `## [0.34.0] — 2026-08-23` 로 같은 본문.)

- [ ] **Step 6: 커밋 — 또는 RED 면 롤백**

Step 4 가 GREEN 이면:

```bash
git add plugins/quality-gates/scripts/adjudication.py plugins/spec-distill/scripts/adjudication.py \
        shared/README.md plugins/quality-gates/.claude-plugin/plugin.json \
        plugins/quality-gates/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md
git commit -m "feat(shared): adjudication 모듈 배포 링크 2곳 + README 디렉토리 표"
```

Step 4 가 **RED 면 롤백**한다 — 링크를 바이트 동일 사본 + `# copy-of:` 마커로 바꾼다:

```bash
rm plugins/quality-gates/scripts/adjudication.py plugins/spec-distill/scripts/adjudication.py
for p in quality-gates spec-distill; do
  printf '# copy-of: shared/adjudication/adjudication.py\n' > "plugins/$p/scripts/adjudication.py"
  cat shared/adjudication/adjudication.py >> "plugins/$p/scripts/adjudication.py"
done
bash shared/tests/test_copy_of_contract.sh
```

롤백했으면 그 사실을 CHANGELOG 항목에 적고(`상대 심볼릭 링크` → `바이트 동일 사본 + copy-of 마커`) 왜 링크가 안 됐는지 관측한 그대로 남긴다.

---

# PR2 — 결함 수리 9건 + 소비자 4개 전환

## Task 3: `merge_review.py` — 결함 #1~#6 + Ledger 전환

**Files:**
- Modify: `plugins/spec-distill/scripts/merge_review.py` (520줄)
- Test: `plugins/spec-distill/tests/test_merge_review_adjudication.py`

**Interfaces:**
- Consumes: Task 2 의 `plugins/spec-distill/scripts/adjudication.py` → `from adjudication import Ledger`
- Produces: `merge_review.py` 의 stdout 에 `adjudication_held` · `adjudication_unknown` · `adjudication_reasons` 세 줄이 추가된다. Task 13 의 앵커 #18 이 이 파일을 `consumer=` 로 지목한다.

⚠ **기존 verdict 계약을 바꾸지 않는다.** `test_merge_review.py:130-135`(AC10) · `:144-148` · `:154-158` 은 셋 다 `combined_verdict == "approved"` 와 `codex_degraded == "true"` 를 **동시에** 단언한다. 이 전환은 회계를 **추가**할 뿐 verdict 경로를 건드리지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_merge_review_adjudication.py`:

```python
"""merge_review 가 버린 것을 «세는지» 본다.

「깨끗함」과 바이트 동일한 출력이 나오면 RED — 그것이 이 결함의 모양이었다.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "merge_review.py"


def run(claude_text, codex_yaml=None):
    with tempfile.TemporaryDirectory() as d:
        cp = Path(d) / "claude.txt"
        cp.write_text(claude_text, encoding="utf-8")
        argv = [sys.executable, str(SCRIPT), "--claude-output", str(cp)]
        if codex_yaml is not None:
            yp = Path(d) / "codex.yaml"
            yp.write_text(codex_yaml, encoding="utf-8")
            argv += ["--codex-yaml", str(yp)]
        else:
            argv += ["--codex-yaml", "/nonexistent"]
        r = subprocess.run(argv, capture_output=True, text=True)
        return r.stdout


SENTINEL = '```spec-review-issues\n%s\n```\n'


class TestAdjudicationAccounting(unittest.TestCase):

    def test_non_dict_issue_is_held_not_dropped(self):
        """#1 — 비-dict 원소를 버리면서 「깨끗함」을 단언하던 자리."""
        body = ('{"issues": [{"category":"c","target_section":"s",'
                '"severity":"high","message":"m"}, "쓰레기", 42]}')
        out = run("**Status:** needs_revise\n" + SENTINEL % body)
        self.assertIn("adjudication_held: 2", out,
                      "비-dict 원소 2개가 보류로 계수돼야 한다")

    def test_missing_sentinel_is_uncountable_not_zero(self):
        """#1 — 원리적 미상. issues 리스트가 만들어지기 전이라 개수를 모른다."""
        out = run("**Status:** needs_revise\n(센티널 블록 없음)\n")
        self.assertIn("adjudication_unknown:", out)
        self.assertIn("claude_issues", out,
                      "무엇을 셀 수 없었는지 이름이 나와야 한다")
        # ⚠ 이 음의 단언의 문자열은 «실제 출력 형식과 정확히 같아야» 한다.
        #   `_yaml_scalar` 를 통과하면 빈 값이 `adjudication_unknown: ""` 로 나오므로
        #   `adjudication_unknown: \n` 을 찾으면 영원히 만족돼 이빨이 0 이 된다
        #   (실측: 이 라운드에서 실제로 그렇게 무장해제됐다). 출력 형식을 바꾸는
        #   편집은 이 문자열도 함께 고친다.
        self.assertNotIn('adjudication_held: 0\nadjudication_unknown: ""\n', out,
                         "0 으로 뭉개면 거짓 clean 이다")

    def test_malformed_codex_yaml_reports_count(self):
        """#2 — 셀 수 있는데 안 세던 자리."""
        yaml = ("findings:\n"
                "  - category: a\n"
                "    target_section: b\n"
                "meta:\n"
                "  codex_failed: false\n"
                "  codex_failed: false\n")   # 중복 마커 → malformed
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body, codex_yaml=yaml)
        self.assertIn("codex_yaml_malformed", out)
        self.assertRegex(out, r"adjudication_held: [1-9]",
                         "버려진 codex finding 개수가 보고돼야 한다")

    def test_empty_key_codex_finding_is_held(self):
        """#5 — category·target_section 이 둘 다 빈 finding 이 원장에 안 들어가던 자리."""
        yaml = ("findings:\n"
                "  - category: ''\n"
                "    target_section: ''\n"
                "    severity: high\n"
                "meta:\n"
                "  codex_failed: false\n")
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body, codex_yaml=yaml)
        self.assertRegex(out, r"adjudication_held: [1-9]",
                         "키 없는 codex finding 이 보류로 계수돼야 한다")

    def test_verdict_contract_unchanged(self):
        """회계 추가가 verdict 를 바꾸지 않는다 (AC10 회귀 방어)."""
        body = '{"issues": []}'
        out = run("**Status:** approved\n" + SENTINEL % body)
        self.assertIn("combined_verdict: approved", out)
        self.assertIn("codex_degraded: true", out)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_merge_review_adjudication.py' -v`
Expected: FAIL — 앞의 4개가 `adjudication_held` / `adjudication_unknown` 부재로 실패. 마지막 `test_verdict_contract_unchanged` 는 이미 PASS (양성 대조 — 이것이 지금 통과한다는 것이 verdict 경로를 안 건드렸음의 기준선이다).

- [ ] **Step 3: 모듈을 붙이고 6곳을 고친다**

파일 상단 import 블록에 추가:

```python
from adjudication import Ledger
```

**세 원장을 만든다.** 어느 것이 어디서 생기는지 먼저 못 박는다 — 이름만 쓰고 생성처를
안 적으면 구현자가 전역 변수를 만들거나 함수마다 새로 만들어 계수가 흩어진다:

| 원장 | 어디서 생기나 | 무엇을 담나 |
|---|---|---|
| `claude_ledger` | `extract_claude_issues()` 안에서 만들어 **반환값의 셋째 원소로** 나온다 | #1 — 비-dict 원소(`hold`) · 세 `return None, True` 경로(`uncountable`) |
| `codex_ledger` | `main()` 에서 `codex_ledger = Ledger(items="open")` 로 만들어 codex 경로에 넘긴다 | #2 · #5 · #6 — codex finding 의 폐기 |
| `history_ledger` | `main()` 에서 `history_ledger = Ledger(items="open")` 로 만들어 `load_history(args.history, history_ledger)` 에 넘긴다 | #3 · #4 — 원장 소실과 값 강제 |

셋 다 `items="open"` 이다 — 이 파일의 다음 소비자는 사람(저자가 design.md 를 고친다)이므로
미판정 항목은 라벨을 붙여 보여준다.

**#1 — `extract_claude_issues`(`:70-94`).** 시그니처를 `(issues, degraded)` 에서 `(issues, degraded, ledger)` 로 바꾼다:

```python
def extract_claude_issues(text: str) -> tuple[list[dict] | None, bool, Ledger]:
    """Parse the LAST ```spec-review-issues fenced block (anti-injection,
    symmetric to codex last-fenced-block). Returns (issues, degraded, ledger).
    degraded=True when no well-formed sentinel block yields a JSON {issues:[...]}.

    세 `return None, True` 경로는 **원리적 미상**이다 — 그 지점에는 `issues`
    리스트가 아직 만들어지지 않아 몇 개였는지 알 방법이 없다. 0 은 거짓 clean 이다.
    """
    L = Ledger(items="open")
    blocks = SENTINEL_RE.findall(text)
    if not blocks:
        L.uncountable("claude_issues", "센티널 블록 부재 — 리스트가 만들어지지 않았다")
        return None, True, L
    try:
        payload = json.loads(blocks[-1])
    except json.JSONDecodeError:
        L.uncountable("claude_issues", "JSONDecodeError — 리스트가 만들어지지 않았다")
        return None, True, L
    if not isinstance(payload, dict) or not isinstance(payload.get("issues"), list):
        L.uncountable("claude_issues", "payload 형태 불일치 — 리스트가 만들어지지 않았다")
        return None, True, L
    issues = []
    for it in payload["issues"]:
        if not isinstance(it, dict):
            L.hold(repr(it)[:60], "비-dict 원소 — 판정 불가")
            continue
        issues.append({
            "category": str(it.get("category", "")),
            "target_section": str(it.get("target_section", "")),
            "severity": str(it.get("severity", "")).lower(),
            "message": str(it.get("message", "")),
        })
        L.accept(issues[-1])
    return issues, False, L
```

호출처를 `claude_issues, claude_degraded, claude_ledger = extract_claude_issues(...)` 로 바꾼다.

**#2 — codex YAML malformed(`:179-181`).** 버리는 개수를 반환값에 싣는다:

```python
    if not marker_seen or marker_invalid:
        # 셀 수 있다 — findings 가 이미 누적돼 있다. 사실만 보고하고 개수를
        # 숨기던 것이 결함이었다(#2). 원리적 미상(#1)과 다른 부류다.
        return [], True, "codex_yaml_malformed:%d" % len(findings)
    return findings, failed, reason
```

`reason` 을 소비하는 자리에서 `codex_yaml_malformed:<n>` 을 파싱해 `codex_ledger.hold(...)` 를 `n` 번 호출하거나, 더 간단히 `reason` 을 그대로 advisory 에 싣고 개수를 `adjudication_held` 에 합산한다. **후자를 택한다** — 파싱 계층을 늘리지 않는다:

```python
    if reason and reason.startswith("codex_yaml_malformed:"):
        n = int(reason.split(":", 1)[1])
        for i in range(n):
            codex_ledger.hold("codex_finding[%d]" % i, "YAML 마커 위반으로 폐기")
        reason = "codex_yaml_malformed"
```

**#3 — `load_history`(`:273-287`).** 원장 통째 손실과 `id` 없는 레코드를 센다:

```python
def load_history(path: str, ledger: Ledger | None = None) -> list[dict]:
    L = ledger if ledger is not None else Ledger(items="open")
    if not path or not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        # 원장 통째가 사라진다. 짝 `_write_history` 는 실패 시 advisory 를 내는데
        # 이쪽만 침묵했다(비대칭). 이것은 **주(主)** 입력이다 — 이 원장이 없으면
        # stagnation 판정이 통째로 근거를 잃는다.
        L.source_failed("issue_history", "%s: %s" % (type(e).__name__, e), primary=True)
        return []
    ih = data.get("issue_history") if isinstance(data, dict) else None
    if not isinstance(ih, list):
        L.source_failed("issue_history", "issue_history 가 리스트가 아니다", primary=True)
        return []
    out = []
    for r in ih:
        if not isinstance(r, dict) or "id" not in r:
            L.hold(repr(r)[:60], "id 없는 원장 레코드 — 대조 불가")
            continue
        out.append(_sanitize_history_record(r))
    return out
```

`main()` 에서 `history_ledger = Ledger(items="open")` 를 만들어 넘기고, 그 `report()` 를 advisory 에 싣는다 — **결과를 안 보던 것**이 이 결함의 절반이었다.

**#4 — `_sanitize_history_record`(`:263-267`).** 게이트를 바꾸는 강제를 계수한다:

```python
def _sanitize_history_record(rec: dict, ledger: Ledger | None = None) -> dict:
    out = dict(rec)
    for key in ("raised_count", "dismissed_by_user"):
        raw = out.get(key, 0)
        try:
            out[key] = int(raw)
        except (TypeError, ValueError):
            out[key] = 0
            if ledger is not None:
                # raised_count 5→0 은 `>=3` 정체 게이트를 무력화한다.
                # 항목이 아니라 «값»의 대체이므로 소실이 아니지만, 게이트를
                # 바꾸므로 gate=True 다.
                ledger.coerced(key, raw, 0, gate=(key == "raised_count"))
    if "resolved" in out and not isinstance(out["resolved"], bool):
        out["resolved"] = bool(out["resolved"])
    return out
```

**#5 — `build_ledger` 의 빈 키 codex finding(`:326-328`).**

```python
    for f in codex_findings:
        cat = str(f.get("category", ""))
        sec = str(f.get("target_section", ""))
        if not cat and not sec:
            codex_ledger.hold(str(f.get("summary", ""))[:60],
                              "category·target_section 둘 다 비어 issue_id 산출 불가")
            continue
        iid = compute_issue_id.compute(cat, sec)
        round_origin.setdefault(iid, set()).add("codex")
```

**#6 — `main()` 의 입력 zero 화(`:489-490`).** 개수를 센다:

```python
        if not codex_avail and codex_findings:
            for f in codex_findings:
                codex_ledger.hold(str(f.get("summary", ""))[:60],
                                  "codex 미가용 라운드 — 원장 진입 차단")
        new_history, stagnation = build_ledger(
            claude_issues if not claude_degraded else [],
            codex_findings if codex_avail else [],
            claude_degraded, history,
        )
```

> **잔여 R7 — 이 사이클에서 닫지 않는다.** `:490` 의 `codex_findings if codex_avail else []` 와 `build_codex_findings_display`(`:241-242`)는 mixed 라운드에서 **findings 전량**을 지운다. 위 수리는 **개수만 복원하고 사라진 `severity: high` finding 자체는 복원하지 않는다.** 올바른 수리는 보존 + 라벨(형제 `merge_brief_review.py:175` 의 형태)이고 그것은 회계가 아니라 데이터 흐름 변경이라 별건이다. **이 잔여를 verdict 규칙 변경으로 닫으려 하지 말 것** — `test_merge_review.py` 의 세 AC 가 깨진다.

**출력.** `main()` 끝에서 세 원장을 합산해 stdout 에 싣는다:

```python
    merged = {"held": 0, "unknown": [], "reasons": []}
    for L in (claude_ledger, codex_ledger, history_ledger):
        r = L.report()
        merged["held"] += r["counts"]["held"]
        merged["unknown"] += r["unknown_counts"]
        merged["reasons"] += r["reasons"]
    # ⚠ **이 파일의 모든 stdout 은 `_yaml_scalar` 를 거친다.** 거치지 않으면
    #   codex 가 쓴 `summary` 의 `\n`(`_yaml_unscalar` 가 진짜 개행으로 푼다)이
    #   두 번째 `combined_verdict:` 줄을 «주입»한다 — SKILL 이 stdout 에서 verdict 를
    #   읽고 평면 파서가 last-write-wins 라 주입된 값이 이긴다. 실측 재현됨.
    print("adjudication_held: %s" % _yaml_scalar(merged["held"]))
    print("adjudication_unknown: %s" % _yaml_scalar(",".join(merged["unknown"])))
    for line in merged["reasons"]:
        print("adjudication_reasons: %s" % _yaml_scalar(line))
```

**그리고 hold 사유를 만들 때 `str()` 이 아니라 `repr()` 을 쓴다** — `#5`(`:360` 부근)와
`#6`(`:535` 부근) 둘 다. claude 쪽·history 쪽 hold 는 이미 `repr()` 이고, 그것이
개행을 무력화하는 지점이다:

```python
codex_ledger.hold(repr(f.get("summary", ""))[:60], "…")   # str() 이 아니다
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_merge_review_adjudication.py' -v`
Expected: 5개 전부 PASS.

- [ ] **Step 5: 기존 스위트가 안 깨졌는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_merge_review.py' -v`
Expected: PASS. 특히 `:130-135`(AC10) · `:144-148` · `:154-158` 세 개가 GREEN 이어야 한다 — 이 셋이 RED 면 verdict 경로를 건드린 것이다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/merge_review.py plugins/spec-distill/tests/test_merge_review_adjudication.py
git commit -m "fix(spec-distill): merge_review 결함 6건 — 소실·미상·강제를 회계로"
```

---

## Task 4: `synthesize_findings.py` — 결함 #7 #8 + Ledger 전환

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` (502줄)
- Test: `plugins/quality-gates/tests/test_synthesize_findings_adjudication.py`

**Interfaces:**
- Consumes: Task 2 의 `plugins/quality-gates/scripts/adjudication.py`
- Produces: `render()` 출력에 미판정 개수가 실린다. Task 13 의 앵커 #8·#9 가 이 파일을 지목한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_synthesize_findings_adjudication.py`:

```python
"""synthesize_findings 가 «파일 부재»와 «경로 없음»을 구별하는지, 미판정을 세는지 본다."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "synthesize_findings.py"
spec = importlib.util.spec_from_file_location("synthesize_findings", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)


class TestSourceFailure(unittest.TestCase):

    def test_missing_file_is_source_failure_not_empty(self):
        """#7 — 파일 부재를 「경로 없음」과 같이 다루면 dropped=0 이 되어
        render() 의 공지가 영원히 안 켜진다."""
        L = mod.Ledger(items="open")
        items, dropped = mod.load_yaml("/nonexistent/findings.yaml", ledger=L)
        self.assertEqual(items, [])
        r = L.report()
        self.assertEqual(r["counts"]["sources_failed"], 1,
                         "부재한 «경로가 주어진» 파일은 입력 실패다")

    def test_no_path_is_not_source_failure(self):
        """양성 대조 — 경로가 아예 없는 것은 실패가 아니다."""
        L = mod.Ledger(items="open")
        items, dropped = mod.load_yaml(None, ledger=L)
        self.assertEqual(items, [])
        self.assertEqual(L.report()["counts"]["sources_failed"], 0,
                         "경로 미지정은 입력 실패가 아니다")


class TestUnadjudicated(unittest.TestCase):

    def test_finding_without_verdict_is_counted(self):
        """#8 — 판정이 없는 finding 을 카운터 없이 keep 하던 자리.
        형제 synthesize_artifact_findings.py:197 에는 unadjudicated += 1 이 있다."""
        L = mod.Ledger(items="open")
        findings = [{"file": "a.py", "line": 1, "title": "t", "severity": "high"}]
        kept, dropped = mod.apply_verdicts(findings, [], ledger=L)
        self.assertEqual(len(kept), 1, "미판정 finding 은 유지된다 (fail-open)")
        self.assertEqual(dropped, 0, "malformed 가 아니므로 dropped 는 0")
        self.assertEqual(L.report()["counts"]["held"], 1,
                         "유지하되 «세어야» 한다")

    def test_malformed_finding_still_counted_by_dropped(self):
        """양성 대조 — 기존 `dropped` 채널이 살아 있다.
        `apply_verdicts` 는 이미 non-mapping finding 을 세고 stderr 를 낸다
        (:271-277). 이 전환이 그 채널을 없애면 안 된다."""
        L = mod.Ledger(items="open")
        kept, dropped = mod.apply_verdicts(["문자열 finding"], [], ledger=L)
        self.assertEqual(kept, [])
        self.assertEqual(dropped, 1, "기존 dropped 카운터가 그대로 산다")


if __name__ == "__main__":
    unittest.main()
```

> 실측 시그니처는 `apply_verdicts(findings, verdicts)` → `(out, dropped_malformed)` 다
> (`:258`). `verdicts` 는 리스트이고 함수가 내부에서 `by_id` 로 만든다(`:270`).
> 이 태스크의 계약은 **`ledger=` 키워드를 세 번째 인자로 추가**하는 것이고,
> 반환 형태와 기존 `dropped` 채널은 건드리지 않는다.

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize_findings_adjudication.py' -v`
Expected: FAIL — `mod.Ledger` 부재(`AttributeError`) 및 `load_yaml`/`apply_verdicts` 가 `ledger=` 를 안 받음(`TypeError`).

- [ ] **Step 3: 구현한다**

파일 상단에:

```python
from adjudication import Ledger
```

**#8 의 자리를 먼저 확정한다** — `apply_verdicts`(`:258`)의 시그니처를
`apply_verdicts(findings, verdicts, ledger=None)` 로 바꾸고, `:283-285` 의
`if v is None: out.append(f); continue` 에 계수를 붙인다. **`:271-277` 의 기존
`dropped` 카운터는 건드리지 않는다** — 그것은 non-mapping finding 을 세는 다른 채널이고
이미 stderr 를 낸다.

**#7 — `load_yaml`(`:34-44`).** 부재와 미지정을 가른다:

```python
def load_yaml(path, ledger=None):
    if not path:
        # 경로가 아예 없다 — 이 실행에서 그 소스를 쓰지 않기로 한 것이지
        # 실패가 아니다. 여기서 source_failed 를 올리면 정상 실행이 degraded 가 된다.
        return [], 0
    try:
        with open(path, encoding="utf-8") as f:
            data = yaml.safe_load(f) or []
    except FileNotFoundError:
        # 경로는 주어졌는데 파일이 없다 — 입력 실패다. 이것을 위와 같이
        # 다루면 dropped=0 이 되어 render() 의 공지가 영원히 안 켜진다(#7).
        if ledger is not None:
            ledger.source_failed(str(path), "FileNotFoundError", primary=True)
        return [], 0
    if isinstance(data, dict) and "verdicts" in data:
        return _as_list(data.get("verdicts"), "verdicts")
    if isinstance(data, dict) and "findings" in data:
        return _as_list(data.get("findings"), "findings")
    return _as_list(data, "findings document")
```

**#8 — 미판정 finding 계수(`:283-285`).**

```python
        v = by_id.get(finding_id(f))
        if v is None:
            # 유지한다(fail-open — 다음 소비자가 사람이다). 다만 «세지 않으면»
            # 판정이 있었던 것과 구별되지 않는다. 형제
            # synthesize_artifact_findings.py:197 에 unadjudicated += 1 이 있다.
            if ledger is not None:
                ledger.hold(finding_id(f), "adversarial 판정 부재")
            out.append(f)
            continue
```

`main()` 에서 `L = Ledger(items="open")` 를 만들어 두 함수에 넘기고, `render()` 의 counts 줄 옆에 `미판정 <N>건` 을 싣는다.

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize_findings_adjudication.py' -v`
Expected: 3개 전부 PASS.

- [ ] **Step 5: 기존 스위트 회귀 확인**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize*.py' -v`
Expected: PASS. **선재 RED 가 있으면 착수 전 기준선과 대조해 이 변경이 만든 것인지 가른다** — 이 리포는 CI 가 없고 `main` 에 stale red 가 있다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_synthesize_findings_adjudication.py
git commit -m "fix(quality-gates): synthesize_findings 결함 2건 — 입력실패·미판정을 회계로"
```

---

## Task 5: `synthesize_artifact_findings.py` 기계적 전환

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_artifact_findings.py` (288줄)
- Test: `plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py`

**Interfaces:**
- Consumes: Task 2 의 링크
- Produces: 기존 `unadjudicated` / `sources_failed` 카운터가 `Ledger` 를 통과한다. 외부 출력 키는 **바뀌지 않는다**.

이 파일은 이미 카운터를 갖고 있다(`:197` `unadjudicated += 1`, `:252` `converged` conjunct). 전환은 그 카운터의 **구현을 바꾸는 것**이지 의미를 바꾸는 것이 아니다.

⚠ **`items="closed"` 다.** 다음 소비자가 기계(자동 편집)이므로 미판정 항목은 제외된다 — `:245-252` 가 *"un-adjudicated … must NOT be silently read as 'resolved'"* 와 `converged = (not degraded) and (crit+imp==0) and (unadjudicated==0)` 로 이미 그렇게 쓴다.

- [ ] **Step 1: 출력 불변 테스트를 쓴다**

```python
"""전환이 외부 출력을 바꾸지 않는지 고정한다.

기계적 전환이므로 회귀 방어가 이 태스크의 전부다 — 새 행동은 없다.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = (Path(__file__).resolve().parents[1] / "scripts"
          / "synthesize_artifact_findings.py")
spec = importlib.util.spec_from_file_location("synthesize_artifact_findings", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)


class TestOutputUnchanged(unittest.TestCase):

    def test_ledger_is_closed_direction(self):
        """다음 소비자가 기계다 — 미판정 항목은 제외된다."""
        L = mod.Ledger(items="closed")
        L.hold("f1", "판정 부재")
        self.assertEqual(L.surfaced(), [],
                         "items=closed 는 미판정 항목을 노출하지 않는다")
        self.assertTrue(L.blocks(),
                        "제외하되 «막는다» — converged 가 False 여야 한다")

    def test_unadjudicated_still_blocks_convergence(self):
        """:252 의 conjunct 가 살아 있는지."""
        L = mod.Ledger(items="closed")
        L.hold("f1", "판정 부재")
        r = L.report()
        self.assertEqual(r["counts"]["held"], 1)
        self.assertTrue(r["degraded"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize_artifact_adjudication.py' -v`
Expected: FAIL — `AttributeError: module has no attribute 'Ledger'`.

- [ ] **Step 3: 전환한다**

파일 상단에 `from adjudication import Ledger` 를 추가한다. 현재 코드(`:193-198`)는:

```python
    unadjudicated = 0
    for f in findings:
        v = by_v.get(f["dedup_key"])
        if v is None:
            unadjudicated += 1          # fail-closed: exclude from kept (AC16)
            continue
```

이것을 다음으로 바꾼다 — **`continue` 는 그대로 둔다**(fail-closed 제외가 이 파일의 계약):

```python
    L = Ledger(items="closed")   # 다음 소비자가 기계(자동 편집)다 — 제외한다
    for f in findings:
        v = by_v.get(f["dedup_key"])
        if v is None:
            L.hold(f["dedup_key"], "adversarial 판정 부재")   # AC16: kept 에서 제외
            continue
```

그리고 `unadjudicated` 를 읽던 자리를 `L.report()["counts"]["held"]` 로 바꾼다 — **출력 키
`unadjudicated` 는 그대로 둔다**(`critiquing-artifacts/SKILL.md:206-216` 이 이름으로 읽는다):

```python
    unadjudicated = L.report()["counts"]["held"]
```

`:252` 의 `converged` conjunct 는 이 `unadjudicated` 를 계속 쓰므로 손대지 않는다.
`sources_failed` 카운터도 같은 방식으로 `L.source_failed(name, why, primary=True)` 로 옮기고
출력 키는 유지한다.

**출력 키를 바꾸지 않는다** — `converged` / `degraded` / `degraded_reason` / `unadjudicated` / `kept_*` 는 `critiquing-artifacts/SKILL.md:206-216` 이 이름으로 읽는 계약이다.

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p 'test_synthesize_artifact*.py' -v`
Expected: PASS (신규 2개 + 기존 전부).

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/tests/test_synthesize_artifact_adjudication.py
git commit -m "refactor(quality-gates): synthesize_artifact_findings 를 Ledger 로 전환"
```

---

## Task 6: `merge_brief_review.py` 기계적 전환

**Files:**
- Modify: `plugins/spec-distill/scripts/merge_brief_review.py` (310줄)
- Test: `plugins/spec-distill/tests/test_merge_brief_adjudication.py`

**Interfaces:**
- Consumes: Task 2 의 링크
- Produces: `fidelity_verdict` · `critic_verdict` · `codex_verdict` · `critic_verdict_unrecoverable` · `codex_isolated` · `codex_degraded` · `fidelity_findings` · `advisory[]` — **전부 불변**.

이 파일이 설계 §9.1 의 잡종을 실증하는 자리다: **데이터는 fail-open**(`:175` — 부분적으로 읽히는 지적을 버리지 않는다), **verdict 는 fail-closed**(`:274` — `escalates = bool(findings) or critic_malformed`). 그래서 `items="open"` 이고 `blocks()` 는 critic(주) 파손일 때만 참이다.

- [ ] **Step 1: 잡종이 표현되는지 테스트를 쓴다**

```python
"""§9.1 의 잡종 — 데이터 fail-open + verdict fail-closed — 이 표현되는지 본다."""
import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "merge_brief_review.py"
spec = importlib.util.spec_from_file_location("merge_brief_review", SCRIPT)
mod = importlib.util.module_from_spec(spec)
sys.path.insert(0, str(SCRIPT.parent))
spec.loader.exec_module(mod)


class TestHybridDirection(unittest.TestCase):

    def test_critic_broken_blocks(self):
        """critic 은 주(主) 판정자다 — 파손되면 막는다 (:274)."""
        L = mod.Ledger(items="open")
        L.source_failed("critic", "센티널 블록 파싱 불가", primary=True)
        self.assertTrue(L.blocks())

    def test_codex_failed_does_not_block(self):
        """codex 는 보조다 — 실패해도 공시만 하고 안 막는다 (:302)."""
        L = mod.Ledger(items="open")
        L.source_failed("codex", "한도 소진", primary=False)
        self.assertTrue(L.report()["degraded"], "공시는 한다")
        self.assertFalse(L.blocks(), "차단은 안 한다")

    def test_partial_finding_is_kept_and_surfaced(self):
        """데이터는 fail-open — 부분적으로 읽히는 지적을 버리지 않는다 (:175)."""
        L = mod.Ledger(items="open")
        L.hold("partial-finding", "severity 누락")
        self.assertEqual(len(L.surfaced()), 1)
        self.assertEqual(L.surfaced()[0]["label"], "held")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_merge_brief_adjudication.py' -v`
Expected: FAIL — `AttributeError: module has no attribute 'Ledger'`.

- [ ] **Step 3: 전환한다**

파일 상단에 `from adjudication import Ledger`. `:161-176` 의 부분 파싱 keep 경로에 `L.hold(...)`, `:274` 의 `critic_malformed` 판정에 `L.source_failed("critic", …, primary=True)`, `:302` 의 `codex_degraded` 자리에 `L.source_failed("codex", …, primary=False)` 를 붙인다. **출력 키는 그대로 두고** `advisory[]` 에 `L.reasons()` 를 append 한다.

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_merge_brief*.py' -v`
Expected: PASS (신규 3개 + 기존 전부).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/merge_brief_review.py plugins/spec-distill/tests/test_merge_brief_adjudication.py
git commit -m "refactor(spec-distill): merge_brief_review 를 Ledger 로 전환"
```

---

## Task 7: `audit-workflow.js` 결함 #9 + PR2 버전 bump

**Files:**
- Modify: `plugins/plugin-audit/scripts/audit-workflow.js:589-591`
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` · `CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: 없음 (JS — 파이썬 모듈 밖)
- Produces: codex 갈래가 Claude 갈래와 같은 `degradedEvents` 를 낸다.

- [ ] **Step 1: 결함을 확인한다**

Run: `sed -n '552,560p;584,592p' plugins/plugin-audit/scripts/audit-workflow.js`
Expected: Claude 갈래(`:552-559`)는 `rec.unverified = true` 옆에 `degradedEvents.push({...})` 가 있고, 구조가 같은 codex 갈래(`:589-591`)는 `if (!v) rec.unverified = true` 만 있다.

- [ ] **Step 2: 1줄을 더한다**

`:589-591` 을 다음으로 바꾼다:

```js
    } else {
      rec.status = 'reported'
      rec.deep_verified = null
      if (!v) {
        rec.unverified = true
        // 구조가 같은 Claude 갈래(:552-559)는 이 push 를 한다. 침묵은 판정이 아니다.
        degradedEvents.push({
          what: 'codex finding ' + f.id + ': refuter가 판정을 누락 — 미검증',
          why: 'refuter 응답에 이 finding_id의 verdict가 없음',
        })
      }
    }
```

- [ ] **Step 3: Law 2 게이트가 안 깨졌는지 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/plugin-audit/scripts/check-law2.py --mode audit`
Expected: exit 0. `AGENT_TOKEN` 은 여전히 정확히 2회이고 helper 줄은 **내용으로** 매칭되므로(`:236`) 줄 번호 이동은 무해하다.

- [ ] **Step 4: 세 플러그인 버전 bump**

| 플러그인 | 현재 | PR1 후 | PR2 후 | 근거 |
|---|---|---|---|---|
| `plugin-audit` | 0.6.0 | 0.6.0 | **0.6.1** | fix |
| `quality-gates` | 4.2.3 | 4.3.0 | **4.3.1** | fix |
| `spec-distill` | 0.33.0 | 0.34.0 | **0.34.1** | fix |

각 CHANGELOG 에 `### Fixed` 항목:

```markdown
## [0.6.1] — 2026-08-23

### Fixed
- `scripts/audit-workflow.js`: codex 갈래가 `unverified=true` 를 세우면서 `degradedEvent` 를 push 하지 않아, refuter 가 판정을 누락한 codex finding 이 배너 없이 통과하던 것. 구조가 같은 Claude 갈래(`:552-559`)와 대칭으로 맞췄다.
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/plugin-audit plugins/quality-gates/.claude-plugin plugins/quality-gates/CHANGELOG.md \
        plugins/spec-distill/.claude-plugin plugins/spec-distill/CHANGELOG.md
git commit -m "fix(plugin-audit): codex 갈래 degradedEvent 누락 + PR2 버전 bump"
```

---

# PR3 — 앵커 18줄 + dispatch 락 + mutation

## Task 8: 락의 도출·인쇄·vacuity 하한

**Files:**
- Create: `shared/tests/test_dispatch_disposition.sh`

**Interfaces:**
- Consumes: 없음 (리포 트리를 직접 읽는다)
- Produces: 여섯 인쇄값 ①agents ②dispatch ③anchors ④per-agent ⑤per-axis ⑥`--emit-scanned`. Task 9~12 가 이 위에 축을 얹는다.

이 태스크는 **앵커 축을 아직 얹지 않는다.** 도출이 맞는지 먼저 고정한다 — 도출이 틀린 락은 어떤 축을 얹어도 무의미하다.

- [ ] **Step 1: 락의 도출부를 쓴다**

`shared/tests/test_dispatch_disposition.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/**
#
# 모든 dispatch 자리가 자기 처분을 밝히는지 검사한다.
#
# 도출을 «표기 열거»에서 출발시키지 않는다. 열거는 fail-open 이다 — 저자가
# 두 번 물렸다(subagent_type grep 이 5표기 중 1개만 덮은 것, 프로토타입이
# 표기 ②④를 놓쳐 18 중 16 만 센 것). 에이전트 «정의 집합»(∀)에서 출발하면
# `0건` 이 답이 되어 누락이 드러난다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  # 실제로 훑은 경로를 낸다. 선언에서 목록을 도출하면 자기 반복이라
  # 커버리지 증거가 되지 않는다.
  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
repo = Path(sys.argv[1])
seen = set()
for pat in ("plugins/*/skills/**/*", "plugins/*/commands/**/*",
            "plugins/*/scripts/*.js", "plugins/*/hooks/**/*"):
    for f in repo.glob(pat):
        if f.is_file() and f.suffix in (".md", ".js"):
            seen.add(str(f.relative_to(repo)))
for f in repo.glob("plugins/*/agents/*.md"):
    seen.add(str(f.relative_to(repo)))
for p in sorted(seen):
    print(p)
PY
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# ── 도출은 파이썬으로 한다 (경계 규칙·창 매칭·앵커 검출이 정규식 무거움).
#    **heredoc 을 `$( … )` 안에 넣지 않는다.** `OUT="$(python3 - <<'PY' … PY)"` 는
#    파이썬 본문에 `r'(?=["\'\s,)]|$)'` 같은 `\'` + `)` 조합이 들어오는 순간
#    `bash -n` 이 `syntax error near unexpected token ')'` 로 죽는다 — bash 의
#    치환 괄호 매칭 선-스캔이 single-quoted heredoc 본문을 완전히 불투명하게
#    다루지 않기 때문이다. 목 둘로 확인했다: 같은 구조 + 단순 파이썬은 통과하고,
#    같은 파이썬 줄 + heredoc 이 치환 밖이면 통과한다 — **교차항일 때만** 터진다.
#    형제 test_no_new_duplication.sh:82 가 같은 구조를 쓰는 것은 그 본문에 트리거
#    문자가 없어서이지 구조가 안전해서가 아니다. 파일로 받으면 셸이 파이썬 내용을
#    아예 안 본다.
TMPD="$(mktemp -d -t dispdisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" > "$TMPD/out.txt" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(sys.argv[1])
WINDOW = 40

# ── 1) 에이전트 집합 (∀) — 정의의 frontmatter `name:` 에서
agents = {}
for p in sorted(REPO.glob("plugins/*/agents/*.md")):
    m = re.search(r'^name:\s*(\S+)\s*$', p.read_text(encoding="utf-8"), re.M)
    if m:
        agents[m.group(1)] = str(p.relative_to(REPO))

# ── 2) 코퍼스는 **구조 규칙**이다. `.py` 는 Agent 도구를 호출할 수 없으므로
#       코퍼스 밖 — 이름 열거가 아니라 성질이다.
corpus = []
for pat in ("plugins/*/skills/**/*", "plugins/*/commands/**/*",
            "plugins/*/scripts/*.js", "plugins/*/hooks/**/*"):
    for f in REPO.glob(pat):
        if f.is_file() and f.suffix in (".md", ".js"):
            corpus.append(f)
corpus = sorted(set(corpus))

# ── 3) **표기 필터가 이름 매칭보다 먼저** 걸린다. 순서를 뒤집으면 산문 속
#       영어 단어가 dispatch 로 잡힌다 (실측: critiquing-artifacts/SKILL.md 에서
#       맨 `adversarial` 이 5줄에 등장하고 전부 산문이다).
#       **콜론까지 포함**해야 한다. `agentType`(콜론 없음)으로 쓰면
#       smoke-workflow.js:8 의 주석이 19번째 dispatch 로 잡힌다.
NOTATION = re.compile(r'subagent_type:|agentType:|Agent\(|^\s*agent:\s')

# 경계 규칙: 이름 앞은 줄머리·공백·따옴표·`:` 중 하나, 뒤는 따옴표·공백·
# 쉼표·닫는괄호·줄끝 중 하나. `-` 는 경계가 아니다 — 그래야
# `adversarial` 이 `artifact-adversarial` 을 먹지 않는다.
# 접두사는 **선택적**이다: 저자가 접두사를 빼서 자기를 감사 대상에서
# 제외하는 경로를 봉쇄한다 (spec-distill/CHANGELOG.md:1197-1198 의 실패).
PRE, POST = r'(?:^|[\s"\':])', r'(?=["\'\s,)]|$)'


def name_re(n):
    return re.compile(PRE + r'(?:[A-Za-z0-9_-]+:)?' + re.escape(n) + POST)


# ── 4) 앵커 «검출»은 느슨하다 (주석 접두사 허용). 서식 검증은 축 A④ 가 한다.
#       검출을 서식 정규식으로 하면 서식 위반 앵커가 «아예 검출되지 않아»
#       A①(17 != 18) 로 RED 가 나고 A④ 를 한 번도 재지 못한다.
ANCHOR_DETECT = re.compile(r'^\s*(?:\S+\s+)?\*\*처분\*\*\s+—')

dispatch = []   # (relpath, lineno, agent)
anchors = []    # (relpath, lineno, rawline)
per_file_disp = {}
per_file_anch = {}

for f in corpus:
    rel = str(f.relative_to(REPO))
    lines = f.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines, 1):
        if ANCHOR_DETECT.match(line):
            anchors.append((rel, i, line))
            per_file_anch.setdefault(rel, []).append(i)
        if not NOTATION.search(line):
            continue
        for a in agents:
            if name_re(a).search(line):
                dispatch.append((rel, i, a))
                per_file_disp.setdefault(rel, []).append(i)

per_agent = {a: 0 for a in agents}
for (_r, _l, a) in dispatch:
    per_agent[a] += 1

print("PRINT_1_agents %d" % len(agents))
print("PRINT_2_dispatch %d" % len(dispatch))
print("PRINT_3_anchors %d" % len(anchors))
for a in sorted(per_agent):
    print("PRINT_4_per_agent %s %d" % (a, per_agent[a]))
zero = sorted(a for a in per_agent if per_agent[a] == 0)
print("ZERO_AGENTS %s" % ",".join(zero))
PY
rc=$?
OUT="$(cat "$TMPD/out.txt")"
assert_eq "$rc" "0" "도출 스크립트가 정상 종료한다"

n_agents="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_1_agents //p')"
n_disp="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_2_dispatch //p')"
n_anch="$(printf '%s\n' "$OUT" | sed -n 's/^PRINT_3_anchors //p')"
zero="$(printf '%s\n' "$OUT" | sed -n 's/^ZERO_AGENTS //p')"

# ── vacuity 하한 — 도출이 깨진 것을 「위반 없음」으로 읽지 않는다.
#    누산기를 «루프 밖에서» 0 으로 두고 최소치를 단언하므로, 루프를 통째로
#    지워도 0 이 남아 RED 가 된다 (test_copy_of_contract.sh:916-919 의 형태).
if [ "${n_agents:-0}" -lt 1 ]; then
  no "에이전트 도출이 0 — 도출이 깨졌다 (vacuity 하한)"
else
  ok "에이전트 ${n_agents}개 도출"
fi
if [ "${n_disp:-0}" -lt 1 ]; then
  no "dispatch 줄 도출이 0 — 도출이 깨졌다 (vacuity 하한)"
else
  ok "dispatch 줄 ${n_disp}건 도출"
fi

# ── §5.1⑤ 에이전트별 dispatch >= 1. 면제값을 두지 않는다.
#    `에이전트 수 == dispatch 수` 는 «걸지 않는다» — 오늘 18/18 인 것은
#    에이전트당 dispatch 가 우연히 하나여서이고, 한 에이전트를 두 skill 에서
#    부르는 것은 정당한 편집이다.
assert_eq "$zero" "" "dispatch 0건인 에이전트가 없다 (있으면 죽은 정의이거나 락이 모르는 표기다)"

# ── 인쇄 단언 — 여섯 인쇄값이 «실제로 나오는지». 인쇄되지 않는 수치를
#    관측 근거로 적는 것은 관측하지 않는 것과 같다. 인쇄값마다 계측기가 따로 있다.
assert_grep "$OUT" '^PRINT_1_agents [0-9]+$'   "인쇄 ① 에이전트 수"
assert_grep "$OUT" '^PRINT_2_dispatch [0-9]+$' "인쇄 ② dispatch 줄 수"
assert_grep "$OUT" '^PRINT_3_anchors [0-9]+$'  "인쇄 ③ 앵커 수"
assert_grep "$OUT" '^PRINT_4_per_agent \S+ [0-9]+$' "인쇄 ④ 에이전트별 dispatch 수"

n_scanned="$(bash "$0" --emit-scanned | wc -l | tr -d ' ')"
if [ "${n_scanned:-0}" -lt 1 ]; then
  no "인쇄 ⑥ --emit-scanned 가 빈 목록 — 커버리지 대조 대상이 사라진다"
else
  ok "인쇄 ⑥ --emit-scanned ${n_scanned}개 경로"
fi

finish
```

- [ ] **Step 2: 실행해서 도출이 실측과 맞는지 확인한다**

Run: `bash shared/tests/test_dispatch_disposition.sh`
Expected: PASS. 출력에 `에이전트 18개 도출` · `dispatch 줄 18건 도출` · `dispatch 0건인 에이전트가 없다` 가 보여야 한다. 앵커는 아직 0이지만 **이 태스크는 앵커 축을 얹지 않았으므로** GREEN 이 맞다.

- [ ] **Step 3: 음성 대조를 확인한다**

Run:
```bash
bash shared/tests/test_dispatch_disposition.sh 2>&1 | grep -c 'PRINT_4_per_agent'
```
직접 세는 대신 도출 스크립트를 따로 돌려 `artifact-adversarial` 과 `adversarial` 이 각각 1건인지 본다:
```bash
bash shared/tests/test_dispatch_disposition.sh --emit-scanned | grep -c 'critiquing-artifacts'
```
Expected: `1` — 그 파일이 코퍼스에 정확히 한 번 들어온다. **양성 대조**(에이전트 18개가 각각 1건)와 **음성 대조**(맨 `adversarial` 이 `artifact-adversarial` 줄을 안 먹음)가 둘 다 있어야 경계 규칙이 검증된 것이다 — 잘못 먹어도 총계는 18 로 남기 때문이다.

- [ ] **Step 4: 커밋**

```bash
git add shared/tests/test_dispatch_disposition.sh
git commit -m "test(shared): dispatch 락 — 도출·인쇄·vacuity 하한"
```

---

## Task 9: 축 A① · A② + 앵커 18줄

**Files:**
- Modify: `shared/tests/test_dispatch_disposition.sh`
- Modify: 앵커 18곳 (PR0 표)

**Interfaces:**
- Consumes: Task 8 의 도출부 (`dispatch` · `anchors` · `per_file_disp` · `per_file_anch`)
- Produces: `PRINT_5_axis` 인쇄값. Task 10~11 이 축을 더 얹는다.

- [ ] **Step 1: 축 A①·A② 를 락에 더한다 (아직 앵커 없음 → RED)**

Task 8 의 python heredoc 끝(`print("ZERO_AGENTS …")` 앞)에 추가:

```python
# ── 축 A① : 앵커 수 == dispatch 수 (1:1 계약)
print("AXIS_A1 %d %d" % (len(dispatch), len(anchors)))

# ── 축 A② : 위치 규칙(결정론). 각 dispatch 줄에 대해, 그 **바로 아래**
#    WINDOW 줄 안의 앵커 중 **그 사이에 다른 dispatch 줄이 없는** 것이 정확히 하나.
#
#    「∃ 완전매칭」이 아니라 결정론 배정이다 — 배정 규칙이 없으면 구현할 수
#    없고, greedy-최근접과 완전매칭은 창이 겹치는 배치에서 정확히 갈린다.
#
#    방향이 「아래」인 이유: briefing-current-state/SKILL.md 의 dispatch 는
#    frontmatter 안 6행이고 `---` 닫힘이 9행이라 «위»에는 아무것도 놓을 수 없다.
#    「위」로 쓰면 그 파일이 배달 즉시 RED 다.
a2_fail = []
for (rel, dl, ag) in dispatch:
    later_disp = sorted(x for x in per_file_disp.get(rel, []) if x > dl)
    cut = later_disp[0] if later_disp else 10 ** 9
    qualifying = [x for x in per_file_anch.get(rel, [])
                  if dl < x <= dl + WINDOW and x < cut]
    if len(qualifying) != 1:
        a2_fail.append("%s:%d(%s)->%d개" % (rel, dl, ag, len(qualifying)))
print("AXIS_A2_FAIL %s" % "|".join(a2_fail))
```

bash 쪽 단언부에 추가:

```bash
a1="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A1 //p')"
a1_disp="${a1% *}"; a1_anch="${a1#* }"
assert_eq "$a1_anch" "$a1_disp" "축 A① 앵커 수(${a1_anch}) == dispatch 수(${a1_disp})"

a2f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A2_FAIL //p')"
assert_eq "$a2f" "" "축 A② 각 dispatch 아래 창에 자기 앵커가 정확히 하나"
```

> **`${a1_anch}` 의 중괄호는 장식이 아니다.** `"$a1_anch개"` 로 쓰면 bash 가 `a1_anch개` 를 변수명으로 읽어 조용히 빈 값을 낸다 (이 설계 중 실측으로 물림).

- [ ] **Step 2: RED 를 확인한다**

Run: `bash shared/tests/test_dispatch_disposition.sh`
Expected: FAIL — `축 A① 앵커 수(0) == dispatch 수(18)` 가 `✗`, 그리고 축 A② 가 18건 전부 `->0개` 로 실패.

- [ ] **Step 3: 앵커 18줄을 넣는다**

**PR0 표의 「앵커 본문」과 「배치」를 그대로 따른다.** 세 가지 배치 규칙:

**① frontmatter 표기 (앵커 #1).** `plugins/agent-transparency/skills/briefing-current-state/SKILL.md` 의 `---`(9행) 직후, `## 인벤토리 · 코드 상태`(11행) **앞**에:

```markdown
---

**처분** — consumer=human · fail-open · disclosure=blocks:

## 인벤토리 · 코드 상태
```

**② `.js` 파일 (앵커 #2 #3 #4).** 반드시 `//` 주석이다 — 취향이 아니라 게이트 요구다. `check-law2.py` 의 `strip_js_noise`(`:88-103`)는 *"a bare `/` in code (not `//` or `/*`) → **BypassError**"* 인데 `consumer=plugins/…/x.py` 값은 `/` 로 가득하다. 주석 안이면 같은 함수가 내용을 공백으로 지우므로 `:224-232`(identifier `agent` 가 정확히 N회)와 `:237-245`(내용-핀 helper 줄) 단언이 흔들리지 않는다.

`audit-workflow.js:18`·`:19` 는 **연속한 두 줄**이라 `:18` 의 자격 구간이 공집합이다. 앵커를 **사이에 삽입**한다:

```js
const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:plugin-auditor'})
// **처분** — consumer=plugins/plugin-audit/scripts/audit-workflow.js · fail-open · disclosure=degradedEvents
const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-audit:audit-refuter'})
// **처분** — consumer=plugins/plugin-audit/scripts/audit-workflow.js · fail-open · disclosure=degradedEvents
```

**③ 코드펜스 안 (앵커 #5 #6 #8 #9 #10 #11 #12 #13 #14 #15 #16 #17 #18).** 펜스를 깨지 않도록 그 언어의 주석으로 쓴다. `quality-pipeline/SKILL.md:366`·`:377` 은 `:364-385` **단일 펜스 안**이므로:

```javascript
Agent({
  subagent_type: "quality-gates:security-reviewer",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open
  ...
  subagent_type: "quality-gates:adversarial",
  // **처분** — consumer=plugins/quality-gates/scripts/synthesize_findings.py · fail-open
```

첫 앵커는 **366행과 377행 사이**에 있어야 한다 — 그렇지 않으면 A② 의 자격 구간(cut=377) 밖이다. 같은 제약이 `conducting-interview/SKILL.md` 의 254↔269↔320 에도 걸린다.

**④ 산문 (앵커 #7).** `publishing-pr-understanding/SKILL.md:120` 의 불릿 블록이 끝나는 `:127` 직후에 평범한 줄로:

```markdown
**처분** — consumer=human · fail-open · disclosure=notes (accuracy)
```

- [ ] **Step 4: GREEN 을 확인한다**

Run: `bash shared/tests/test_dispatch_disposition.sh`
Expected: PASS — `축 A① 앵커 수(18) == dispatch 수(18)` 와 `축 A② …정확히 하나` 가 `✓`.

- [ ] **Step 5: Law 2 게이트 회귀 확인**

Run:
```bash
PYTHONDONTWRITEBYTECODE=1 python3 plugins/plugin-audit/scripts/check-law2.py --mode audit
PYTHONDONTWRITEBYTECODE=1 python3 plugins/plugin-audit/scripts/check-law2.py --mode smoke
```
Expected: 둘 다 exit 0.

- [ ] **Step 6: 커밋**

```bash
git add shared/tests/test_dispatch_disposition.sh plugins/
git commit -m "feat: dispatch 처분 앵커 18줄 + 축 A①(1:1 등식) A②(위치 규칙)"
```

---

## Task 10: 축 A③ · A④

**Files:**
- Modify: `shared/tests/test_dispatch_disposition.sh`

**Interfaces:**
- Consumes: Task 9 의 `dispatch` · `anchors`
- Produces: `AXIS_A3_FAIL` · `AXIS_A4_FAIL` 인쇄값

- [ ] **Step 1: 축 A③ A④ 를 더한다**

python heredoc 에 추가:

```python
# ── 축 A③ : 각 dispatch 줄은 «정확히 한 에이전트»에 귀속.
#    이것이 경계 규칙(§5.1③)의 진짜 계측기다 — 규칙이 없으면
#    critiquing-artifacts/SKILL.md:194 한 줄이 `adversarial` 과
#    `artifact-adversarial` 둘 다에 귀속되어 여기서 RED 가 난다.
attrib = {}
for (rel, dl, ag) in dispatch:
    attrib.setdefault((rel, dl), []).append(ag)
a3_fail = ["%s:%d->%s" % (r, l, "+".join(sorted(v)))
           for ((r, l), v) in sorted(attrib.items()) if len(v) != 1]
print("AXIS_A3_FAIL %s" % "|".join(a3_fail))

# ── 축 A④ : 서식 + 닫힌 어휘 + 경로 실재. 값 종류와 무관하게 «모든» 앵커에 건다.
#    A④ 가 없으면 §4.1 의 요구가 집행 자리를 잃는다 —
#    `consumer=plugins/x/scripts/없는파일.js` + 실재 리터럴이 세 축을 그대로 통과한다.
FIELD = re.compile(
    r'^\s*(?:\S+\s+)?\*\*처분\*\*\s+—\s+consumer=(\S+)\s+·\s+fail-(open|closed)'
    r'(?:\s+·\s+disclosure=(.+?))?\s*$')
tracked = set(subprocess.run(
    ["git", "-C", str(REPO), "ls-files"],
    capture_output=True, text=True, check=True).stdout.splitlines())

parsed = []     # (rel, lineno, consumer, faildir, disclosure)
a4_fail = []
for (rel, ln, raw) in anchors:
    m = FIELD.match(raw)
    if not m:
        a4_fail.append("%s:%d 서식 위반" % (rel, ln))
        continue
    cons, faildir, disc = m.group(1), m.group(2), m.group(3)
    if cons in ("orchestrator", "human"):
        pass
    elif cons.endswith(".py") or cons.endswith(".js"):
        if cons not in tracked:
            a4_fail.append("%s:%d 경로 미실재 consumer=%s" % (rel, ln, cons))
            continue
    else:
        a4_fail.append("%s:%d 닫힌 어휘 밖 consumer=%s" % (rel, ln, cons))
        continue
    if not cons.endswith(".py") and disc is None:
        a4_fail.append("%s:%d disclosure= 누락 (consumer=%s)" % (rel, ln, cons))
        continue
    parsed.append((rel, ln, cons, faildir, disc))
print("AXIS_A4_FAIL %s" % "|".join(a4_fail))
```

bash 단언부에:

```bash
a3f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A3_FAIL //p')"
assert_eq "$a3f" "" "축 A③ 각 dispatch 줄이 정확히 한 에이전트에 귀속"
a4f="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_A4_FAIL //p')"
assert_eq "$a4f" "" "축 A④ 서식 + 닫힌 어휘 + 경로 실재"
```

- [ ] **Step 2: GREEN 을 확인한다**

Run: `bash shared/tests/test_dispatch_disposition.sh`
Expected: PASS — 축 A①②③④ 넷 다 `✓`. PR0 이 18곳 전부를 미리 검증했으므로(BAD=0) 여기서 처음 RED 가 나면 앵커 삽입이 표와 어긋난 것이다.

- [ ] **Step 3: 커밋**

```bash
git add shared/tests/test_dispatch_disposition.sh
git commit -m "test(shared): dispatch 락 축 A③(귀속 유일) A④(서식·어휘·경로)"
```

---

## Task 11: 축 B · 축 C

**Files:**
- Modify: `shared/tests/test_dispatch_disposition.sh`

**Interfaces:**
- Consumes: Task 10 의 `parsed`
- Produces: `PRINT_5_axis` (축별 대상 수) · `AXIS_B_FAIL` · `AXIS_C_FAIL`

- [ ] **Step 1: 축 B · C 를 더한다**

python heredoc 에 추가:

```python
# ── 축 B : consumer= 가 `.py` 인 앵커 — 그 파일이 `adjudication` 을 import 한다.
#    가장 센 이빨이지만 `.py` 소비자에만 걸린다.
IMPORT = re.compile(
    r'^\s*(?:from\s+adjudication\s+import\b|import\s+adjudication\b)', re.M)
b_targets = [x for x in parsed if x[2].endswith(".py")]
b_fail = []
for (rel, ln, cons, _fd, _dc) in b_targets:
    src = (REPO / cons).read_text(encoding="utf-8")
    if not IMPORT.search(src):
        b_fail.append("%s:%d -> %s 가 adjudication 을 import 하지 않는다"
                      % (rel, ln, cons))
print("AXIS_B_FAIL %s" % "|".join(b_fail))

# ── 축 C : consumer= 가 `.js`·orchestrator·human 인 앵커 — disclosure= 리터럴이
#    **그 앵커가 사는 파일의 「앵커-제외 본문」**에 실재한다.
#
#    앵커 줄을 빼는 것은 선택이 아니라 «성립 조건»이다. 리터럴은 앵커 줄
#    자신에 적혀 있고 그 앵커는 검색 대상 파일 안에 있다 — 제외하지 않으면
#    저자가 무엇을 쓰든 검색이 자기 자신에 걸려 항상 GREEN 이고 이빨이 0 이다.
#    (「헤더가 문구를 만족시키면 body 를 삭제해도 GREEN」과 동형. 판정은
#    body-unique 여야 한다.)
#
#    코퍼스가 리포 전역도 플러그인 전체도 아니고 «파일 하나»인 이유: 전역이면
#    예시 리터럴 `degrade 채널` 이 proceed-gate.md:34-41 에 이미 있어 축이
#    다시 vacuous 해진다.
c_targets = [x for x in parsed if not x[2].endswith(".py")]
c_fail = []
for (rel, ln, cons, _fd, disc) in c_targets:
    lines = (REPO / rel).read_text(encoding="utf-8").splitlines()
    anchor_lines = set(per_file_anch.get(rel, []))
    body = "\n".join(t for (i, t) in enumerate(lines, 1) if i not in anchor_lines)
    if disc not in body:
        c_fail.append("%s:%d disclosure=%r 가 앵커-제외 본문에 없다"
                      % (rel, ln, disc))
print("AXIS_C_FAIL %s" % "|".join(c_fail))

# ── 인쇄 ⑤ 축별 대상 수. M10(green-expected) 의 관측 근거가 이것이다 —
#    인쇄되지 않는 수치를 관측 근거로 적는 것은 관측하지 않는 것과 같다.
print("PRINT_5_axis B %d" % len(b_targets))
print("PRINT_5_axis C %d" % len(c_targets))
```

bash 단언부에:

```bash
bf="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_B_FAIL //p')"
assert_eq "$bf" "" "축 B .py 소비자가 adjudication 을 import 한다"
cf="$(printf '%s\n' "$OUT" | sed -n 's/^AXIS_C_FAIL //p')"
assert_eq "$cf" "" "축 C disclosure 리터럴이 앵커-제외 본문에 실재한다"
assert_grep "$OUT" '^PRINT_5_axis B [0-9]+$' "인쇄 ⑤ 축 B 대상 수"
assert_grep "$OUT" '^PRINT_5_axis C [0-9]+$' "인쇄 ⑤ 축 C 대상 수"
```

- [ ] **Step 2: GREEN 을 확인한다**

Run: `bash shared/tests/test_dispatch_disposition.sh`
Expected: PASS. 출력에 `PRINT_5_axis B 6` 과 `PRINT_5_axis C 12` 가 나와야 한다 — PR0 표에서 `.py` 앵커 6개(#5 #6 #8 #9 #16 #18), 나머지 12개.

- [ ] **Step 3: 축 C 의 한계를 문면에 적는다**

락 파일 머리 주석에 한 단락을 더한다:

```bash
# 축 C 는 축 B 보다 «약하다». `disclosure=` 리터럴이 파일에 있다는 것이 그
# 채널이 실제로 읽힌다는 증거는 아니다. 값이 저자 손에 있는 한 축 B 급 이빨은
# 이 축에서 나오지 않는다 — 이 락은 그것을 없앴다고 주장하지 않고 «어디로
# 옮겼는지» 밝힌다. `consumer=` 를 `.py` 대신 orchestrator/human 으로 쓰면
# 축 B 를 벗어나는데, 그 이동은 M10 이 «측정»한다(PRINT_5_axis 수치가 움직인다).
```

- [ ] **Step 4: 커밋**

```bash
git add shared/tests/test_dispatch_disposition.sh
git commit -m "test(shared): dispatch 락 축 B(import 교차확인) C(공시 채널 실재)"
```

---

## Task 12: mutation M1~M18 + PR3 버전 bump

**Files:**
- Create: `docs/audits/2026-08-23-dispatch-lock-mutations.md` (실행 기록)
- Modify: 네 플러그인 `plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 8~11 의 완성된 락
- Produces: 락이 실제로 무는지에 대한 관측 기록

**모든 실행은 `PYTHONDONTWRITEBYTECODE=1` 로 한다.** 같은 길이 변이가 stale `.pyc` 를 못 넘어 거짓 GREEN 과 거짓 RED 를 둘 다 낸다.

- [ ] **Step 1: 양성 대조 — 무변경 트리가 GREEN 인지 «먼저» 확인한다**

```bash
git status --porcelain   # 비어 있어야 한다
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_dispatch_disposition.sh; echo "rc=$?"
```
Expected: `rc=0`. **이것 없이는 RED 도 증거가 아니다** — 계측기 자신이 고장 나 있으면 모든 mutation 이 RED 를 내고 그것을 이빨로 오독한다.

- [ ] **Step 2: M1~M18 을 하나씩 돌린다**

각 mutation 은 `git stash push -u -m "<태그>"` 대신 **편집 → 실행 → `git checkout -- <파일>`** 로 되돌린다 (stash 스택은 다른 워크트리와 공유된다).

| # | mutation | 기대 | 무엇을 관측해 판정하나 |
|---|---|---|---|
| M1 | 앵커 #18 줄 삭제 | 축 A① RED | `reviewing-spec/SKILL.md` 가 실패 메시지에 등장 |
| M2 | 앵커 #8 의 `fail-open` → `fail-sideways` | 축 A④ RED | `서식 위반` 메시지 |
| M3 | 앵커 #16 의 `consumer=` 를 `plugins/spec-distill/scripts/state_path.py` 로 교체 | 축 B RED | 그 경로가 실패 메시지에 등장 |
| M4 | `merge_brief_review.py` 의 `from adjudication import Ledger` 삭제 | 축 B RED | 동상 |
| M5 | 새 agent 정의(`plugins/spec-distill/agents/zz-probe.md`) + 앵커 없는 dispatch 1줄 추가 | 축 A① RED | `zz-probe` 가 실패 메시지에 등장 |
| M6 | `plugins/spec-distill/agents/spec-reviewer.md` 의 `name:` 을 `spec-reviewer-x` 로 변경 | **§5.1⑤ dispatch-0건 RED** | `spec-reviewer-x` + `0건` |
| M7 | 코퍼스 글롭에서 `plugins/*/scripts/*.js` 제거 | **§5.1⑤ 0건 RED** — `plugin-auditor`·`audit-refuter`·`smoke-probe` 가 0건. 총계 등식이 «아니다»: 앵커도 함께 사라져 `dispatch == 앵커` 는 15/15 로 성립하고 vacuity 하한(0)도 발화하지 않는다 | 그 세 이름 + `0건` (인쇄 ④가 낸다) |
| M8 | 락 메시지의 `${a1_anch}` → `$a1_anch개` | 락 자기 관측 RED | 출력에 빈 문자열 |
| M9 | 앵커 #18 의 dispatch 줄에서 접두사 제거(`"spec-reviewer"`) | **GREEN 이어야 함** (자기면제 봉쇄 확인) | `--emit-scanned` 에 그 파일이 여전히 있고 `PRINT_2_dispatch 18` 유지 |
| **M10** | 앵커 #16 을 `consumer=human · disclosure=verification_status` 로 교체 | **GREEN 이 예상된다** — 축 B 를 벗어나 축 C 로 이동. 결함이 아니라 §4.2 가 명시한 면제 경로의 «측정» | `PRINT_5_axis B` 가 6→5, `PRINT_5_axis C` 가 12→13 |
| **M11** | 앵커 #15 의 `disclosure=verification_status` 를 `disclosure=존재하지않는채널명` 으로 교체 | 축 C RED | 그 리터럴이 실패 메시지에 등장. ✎ 앵커-제외 규칙이 **없으면 이 mutation 은 구성 자체가 불가능하다** — 교체하는 순간 그 문자열이 앵커 줄에 존재하게 되므로. **M11 이 구성 가능하다는 것이 곧 축 C 가 이빨을 가졌다는 증거다** |
| **M12** | 앵커 #7 에서 ` · disclosure=notes (accuracy)` 통째 삭제 | **축 A④ RED**(서식) | 서식/누락 메시지 — 축 C 가 아니다. 축 C 는 `disclosure=` 가 **있을 때** 그 리터럴을 본다 |
| **M13** | **락 자신의** 경계 규칙에서 `PRE`/`POST` 를 `r''` 로 만든다 | **축 A③ RED** — `critiquing-artifacts/SKILL.md:194` 가 `adversarial` 과 `artifact-adversarial` **두 에이전트에 동시 귀속** | 그 파일:줄 + 귀속된 두 이름. 「`adversarial` 의 dispatch 줄 삭제」로는 안 된다: 경계 규칙 없이도 `0건` 으로 RED 가 나 **규칙의 유무를 판별하지 못한다**. 그래서 피검자가 아니라 **락 자신**을 변이시킨다 |
| **M14a** | 앵커 #12 를 **삭제** | **축 A① RED** — 17 ≠ 18 | 두 수 |
| **M14b** | 앵커 #12 를 앵커 #13 의 창 안으로 **옮긴다 — 총계 18 유지** | **축 A② 단독 RED** — `:254` 아래 자격 앵커 0개, `:269` 쪽 2개 | 매칭 실패한 dispatch 의 줄 번호. **A① 만 구현한 락은 이것을 GREEN 으로 통과시킨다** — 그래서 이것이 A② 의 유일한 분리 계측기다. 「앵커 둘을 합치기」로는 안 된다: 총계가 17 ≠ 18 이라 A① 단독으로 RED 가 나 A② 를 분리하지 못한다 |
| **M15** | 앵커 #2 의 `consumer=` 를 `plugins/plugin-audit/scripts/없는파일.js` 로 교체(`disclosure=` 는 실재 리터럴 유지) | **축 A④ RED**(경로 실재) | 그 경로가 실패 메시지에 등장. 이 mutation 이 없으면 §4.1 의 경로 실재 요구가 집행되는지 아무도 모른다 |
| **M16** | 앵커 #10 의 `consumer=orchestrator` 를 `consumer=maybe` 로 교체(서식은 유효) | **축 A④ RED**(닫힌 어휘) | 그 값이 실패 메시지에 등장. 검출은 느슨하므로 이 앵커는 **검출되고** A④ 에서 걸린다 — 미검출로 A① RED 가 나면 A④ 를 잰 것이 아니다 |
| **M17** | 락에서 `print("PRINT_5_axis …")` 두 줄 삭제 | **인쇄 단언 RED** | `인쇄 ⑤ 축 B 대상 수` 가 `✗`. **M10** 의 관측 근거가 이것이다 |
| **M18** | 락에서 `print("PRINT_4_per_agent …")` 삭제 | **인쇄 단언 RED** | `인쇄 ④ …` 가 `✗`. **M6·M7·M9** 의 관측 근거가 이것이다. ✎ M17 하나로 여섯 인쇄값을 다 재는 척하면 ④가 사라져도 통과한다 — 인쇄값마다 계측기가 따로 있어야 한다 |

**mutation 은 삭제 축만 흔들지 않는다** — M2·M3·M6·M9·M10·M11·M13·M14b·M15·M16 은 추가·반전·형태변경이고, **M13 은 락 자신을 흔든다**(피검자가 아니라 계측기를 변이시키는 유일한 항목).

**M9 와 M10 은 green-expected 다.** 통과가 정답인 assert 는 모양만으로 이빨을 판별할 수 없으므로 둘 다 관측 대상 수치를 적었고, 그 수치는 인쇄 ④⑤ 로 실제 산출된다.

- [ ] **Step 3: 결과를 기록한다**

`docs/audits/2026-08-23-dispatch-lock-mutations.md` 에 표 하나:

```markdown
# dispatch 락 mutation 실행 기록 — 2026-08-23

양성 대조: 무변경 트리 rc=0 (선행 확인).

| # | 기대 | 관측 | 판정 |
|---|---|---|---|
| M1 | 축 A① RED | (실제 출력 한 줄) | ✓/✗ |
| … | | | |

**미달 항목이 있으면 그 축은 이빨이 없다** — 기대와 다른 결과가 나온 mutation 은
락을 고칠 사유이지 mutation 을 고칠 사유가 아니다.
```

18행을 전부 채운다. **기대와 다른 결과는 그대로 적는다** — 관측을 기대에 맞추면 이 기록이 무의미해진다.

- [ ] **Step 4: 네 플러그인 버전 bump**

| 플러그인 | PR2 후 | PR3 후 | 근거 |
|---|---|---|---|
| `agent-transparency` | 0.2.3 | **0.2.4** | 앵커 1줄 |
| `plugin-audit` | 0.6.1 | **0.6.2** | 앵커 3줄 |
| `quality-gates` | 4.3.1 | **4.3.2** | 앵커 6줄 |
| `spec-distill` | 0.34.1 | **0.34.2** | 앵커 8줄 |

각 CHANGELOG 에:

```markdown
### Added
- dispatch 자리에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.
```

- [ ] **Step 5: 커밋**

```bash
git add docs/audits/2026-08-23-dispatch-lock-mutations.md plugins/*/.claude-plugin/plugin.json plugins/*/CHANGELOG.md
git commit -m "test(shared): dispatch 락 mutation M1~M18 실행 기록 + PR3 버전 bump"
```

---

# PR4 — 규정 문면

## Task 13: `CLAUDE.md` + `docs/plugin-authoring.md`

**Files:**
- Modify: `CLAUDE.md` (Plugin Shape → 컴포넌트 격리)
- Modify: `docs/plugin-authoring.md` (46줄)

**Interfaces:**
- Consumes: PR1~PR3 의 실재하는 모듈·앵커·락
- Produces: 없음 (문서가 마지막이다 — 앞의 것이 실재한 뒤에 가리킨다)

⚠ **이 태스크에는 락이 없다** (설계 §14 의 정직한 미집행 선언). 두 문면이 §9.1·§4.1 과 일치하는지 재는 자동 검사는 존재하지 않는다 — **사람 리뷰가 유일한 방어다.**

- [ ] **Step 1: `CLAUDE.md` 에 항목을 더한다**

「컴포넌트 격리」 섹션의 마지막 불릿(`모든 skill에 cost_class 선언`) **뒤에**:

```markdown
- **subagent 발견은 처분을 밝힌다.** 모든 dispatch 자리는
  `**처분** — consumer=<경로|orchestrator|human> · fail-<open|closed>[ · disclosure=<리터럴>]`
  한 줄을 갖는다(`consumer=` 가 경로면 그 경로가 **실재해야** 한다). 판정기가 항목을 버리면
  센다 — 셀 수 없으면 「셀 수 없음」을 낸다(침묵과 0 은 다른 사실이다). 회계는
  `shared/adjudication/` 이 한다.
  **흡수(dedup)와 강제(coercion)는 소실이 아니다** — 계수하되 degrade 가 아니다.
  **공시와 차단은 다른 술어다**: 무엇이 degrade 든 언제나 드러내되, 막는 것은 **항목이
  소실됐거나 그 축의 주(主) 판정자가 죽었을 때**다 — 모델 다양성 손실은 공시하고 막지 않는다.
  미판정 항목의 방향은 다음 소비자가 정한다: 기계면 제외, 사람이면 라벨을 붙여 보여준다.
  집행은 `shared/tests/test_dispatch_disposition.sh`(축 A①②③④·B·C). **축 C 는 채널 «이름»의
  실재까지만 재고 그 채널이 실제로 읽히는지는 못 잰다.**
```

- [ ] **Step 2: `docs/plugin-authoring.md` 에 한 줄을 더한다**

이 문서가 `plugin-dev` 를 가리키는 **직전**에 놓는다 — `plugin-dev:agent-development` 는 외부 vendoring 이라 편집할 수 없고, 우리가 닿는 마지막 지점이 여기다.

실측: `docs/plugin-authoring.md:30` 이 첫 `plugin-dev` 언급(*"**단계별 문법 레퍼런스** — `plugin-dev`(claude-plugins-official)가 …"*)이고 `:33` 이 `agent-development` 를 이름으로 부른다. 앵커는 **`:30` 바로 앞**에 넣는다:

```markdown
> **새 agent 를 dispatch 하는 자리를 만들면 처분 앵커 한 줄이 함께 온다** —
> `**처분** — consumer=<경로|orchestrator|human> · fail-<open|closed>[ · disclosure=<리터럴>]`.
> 그 subagent 가 낸 발견을 누가 어떻게 처분하는지, 그리고 버린 것이 어디에 드러나는지를
> 밝힌다. `shared/tests/test_dispatch_disposition.sh` 가 dispatch 와 앵커를 1:1 로 묶으므로
> 빠뜨리면 `/qg` Runtime gate 가 RED 다. 회계 모듈은 `shared/adjudication/`.
```

- [ ] **Step 3: 문면이 §9.1·§4.1 과 어긋나지 않는지 손으로 대조한다**

세 가지를 확인한다:
1. `consumer=` 의 네 값이 CLAUDE.md 문면과 `test_dispatch_disposition.sh` 의 A④ 검증부에서 **같다**.
2. 「공시와 차단은 다른 술어」가 `adjudication.py` 의 `blocks()` 와 `_degraded()` 정의와 **같다**.
3. 「미판정 항목의 방향」이 `surfaced()` 의 `items` 분기와 **같다**.

셋 중 하나라도 어긋나면 문면을 코드에 맞춘다 — 코드를 문면에 맞추지 않는다.

- [ ] **Step 4: 전체 락 스위트를 마지막으로 돌린다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_dispatch_disposition.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_adjudication_behavior.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_no_new_duplication.sh
```
Expected: 넷 다 exit 0.

- [ ] **Step 5: 커밋**

```bash
git add CLAUDE.md docs/plugin-authoring.md
git commit -m "docs: 처분 앵커 규정을 CLAUDE.md 와 plugin-authoring 에 흡수"
```

`shared/` 와 리포 루트 문서는 플러그인이 아니므로 이 PR 에는 bump 가 없다.

---

## 이 계획이 남기는 것 — 닫지 않은 것들

계획이 끝나도 남는 것을 여기 적는다. 빈 칸을 남기지 않으려고 없는 집행을 적는 것이 더 나쁘다.

| 잔여 | 왜 남는가 |
|---|---|
| **R7** — `merge_review.py:490` + `build_codex_findings_display:241-242` 의 findings 전량 폐기 | Task 3 은 **개수만 복원**한다. 보존 + 라벨은 회계가 아니라 데이터 흐름 변경이라 별건. **verdict 규칙 변경으로 닫으려 하지 말 것** — `test_merge_review.py` 의 세 AC 가 깨진다 |
| **R9** — codex 미실행, 모델 다양성 0 | 설계 5라운드 전부 same-family 였다. 한도 회복 후 재리뷰가 유일한 경로이고 **우선순위 1순위는 설계 §2.1**(같은 계열 리뷰가 다섯 번 붙어 네 번을 놓친 자리) |
| **R10** — 리포 최초 import-only `.py` 심볼릭 링크 | Task 2 Step 4 의 `/qg` 실행이 유일한 측정. RED 면 Step 6 롤백 |
| **R1** — 축 B 가 재는 것은 「모듈을 쓰는가」도 아니고 **「import 처럼 생긴 줄이 raw 텍스트에 있는가」**다 | 축 B 는 파일 전체를 정규식으로 훑는다 — docstring 안의 한 줄로도 만족된다 〔실측: 실제 import 를 지우고 docstring 에 넣으면 락 전건 GREEN 인데 모듈에 `Ledger` 가 없어 런타임 NameError〕. 「출력을 렌더하는가」는 더 멀다. Task 3~6 의 회귀 테스트가 출력을 직접 보지만, 정적 락으로는 여기까지가 한계다 |
| **R8** — 산문 소비 자리가 실제로 버리는지 미측정 | 앵커가 그 자리들에 처분을 *적게* 만든다. 실제 행동 측정은 skill 실행이 필요하며 이 계획에 없다 |
| 앵커의 `fail-` 과 모듈 `items=` 의 동일성 | **미집행이고, 오늘은 대조할 행동 자체가 없다.** 축 B 는 인자로 무엇을 넘겼는지 안 본다 — 그런데 배포 소비자 4개 중 **아무도 `blocks()` 도 `surfaced()` 도 호출하지 않는다** 〔실측: 두 호출은 테스트와 모듈 자신에만 있다〕. `items=` 는 `surfaced()` 안에서만 읽히므로 앵커의 `fail-` 값과 생성자의 `items=` 값은 **오늘 양쪽 다 어떤 행동도 바꾸지 않는다.** §9.1 의 두 술어 중 공시(`_degraded`)만 소비자에 배선돼 있고 **차단은 배선이 0** 이다 |
| **축 C** — `disclosure=` 리터럴 검사 | 리터럴이 파일 본문에 있다는 것은 **그 채널이 실제로 읽힌다는 증거가 아니고**, 나아가 **채널 이름처럼 생겼는지조차 재지 않는다** — 한 글자짜리 리터럴로도 만족된다 〔실측: 어느 앵커의 `disclosure=` 값을 한 글자로 바꿔도 락 전건 GREEN〕. 값이 저자 손에 있는 한 축 B 급 이빨은 이 축에서 나오지 않는다 |
| 인쇄값 ①②③⑥ 의 **분리 mutation** | Task 8 이 `assert_grep` 로 넷의 존재를 단언하지만, ④⑤ 와 달리 **그것만 무너뜨리는 mutation 이 없다**(M17=⑤, M18=④). ①②③은 vacuity 하한·A① 등식이 간접적으로 의존하고 ⑥은 형제 락의 양방향 커버리지 검사가 읽는다 — 간접 의존은 분리 계측이 아니다 |
| §6 문면 두 곳이 §9.1·§4.1 과 일치 | **미집행.** Task 13 Step 3 의 사람 대조가 유일한 방어 |
| `shared/README.md` 디렉토리 표 | **미집행.** 축 0 은 계약 «수»만 세고 표는 안 본다 |
| `assemble-audit-data.py` 의 `dropped[]` 어휘 | 앵커가 지목하지 않아 전환하지 않는다. §1.1 의 4갈래 분열 중 이 하나가 남는다 |
| `quality-gates:synthesizer` 죽은 참조 (`quality-pipeline/SKILL.md:502`) | agent 정의가 없어 ∀18 에 안 들어온다. 별건 |
