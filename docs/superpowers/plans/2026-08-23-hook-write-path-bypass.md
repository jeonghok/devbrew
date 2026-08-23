# 훅 쓰기-경로 우회 봉쇄 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew 세 플러그인에서 `matcher: "Write|Edit|MultiEdit"` 인 `PostToolUse` 훅 네 개를 제거해, Bash heredoc·`sed -i` 로 쓴 파일이 게이트를 우회하는 버그 클래스를 리포에서 없앤다.

**Architecture:** 훅이 묻던 질문을 "무엇이 바뀌었나"(도구 귀속 필요)에서 "지금 불변식이 깨졌나"(귀속 불필요)로 바꾼다. spec-distill 은 기존 `Stop` 훅(`review-dispatch.py`)이 발견·구조검증·dispatch 를 모두 흡수하고, 발견은 `git status` 전체 출력을 **상계**로 받아 `arm_ledger.canonical_key` 술어로 좁힌다. quality-gates 와 project-init 은 훅을 삭제하고 각각 git-도출 scope 와 검사 제거로 대체한다. **신규 훅 0개.**

**Tech Stack:** Python 3.9 (stdlib only — `subprocess`·`re`·`pathlib`·`unittest`), Bash 3.2 (macOS), git porcelain v1 `-z`, Claude Code 훅 API 2.1.239.

**Spec:** `docs/superpowers/specs/2026-08-23-hook-write-path-bypass-design.md` — 아래 모든 Task 는 그 문서의 §9 요구(A1–A26)에 대응한다. 실행자는 두 문서를 함께 읽는다.

## Global Constraints

이 절의 값은 모든 Task 의 요구에 암묵적으로 포함된다.

- **작업 위치**: worktree `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass`. `main` repo(`/Users/jeonghokim/Downloads/devbrew`)에 커밋하지 않는다.
- **브랜치**: PR 마다 `main` 에서 새로 분기. 현재 브랜치 `fix/hook-write-path-bypass` 는 설계 문서 전용이며 여기서 코드를 쌓지 않는다.
- **Python 실행**: 시스템 `python3` = 3.9. `str | None` 런타임 표기는 금지 — 모든 신규 모듈은 `from __future__ import annotations` 로 시작한다.
- **테스트 실행**: 셸 `bash plugins/<plugin>/tests/<file>.sh` / 파이썬 `cd plugins/<plugin>/tests && python3 -m unittest <module>` (`tests/` 에 `__init__.py` 가 없어 `discover` 는 `ImportError` 로 죽는다).
- **mutation 실행 시 항상** `PYTHONDONTWRITEBYTECODE=1` 을 붙인다 (같은 길이 변이가 stale `.pyc` 를 넘지 못해 거짓 GREEN·거짓 RED 를 둘 다 낸다).
- **버전**: project-init `2.1.1 → 3.0.0` · quality-gates `4.2.3 → 5.0.0` · spec-distill `0.33.0 → 0.34.0` (0.x 이므로 breaking = minor; v0.25.0 의 `/cancel-review` 제거 선례와 같다). `plugin.json` 은 `plugins/<name>/.claude-plugin/plugin.json` 에 있다.
- **완료 oracle 정의역** (설계 §10): 검색 대상은 `plugins/**` (단 `tests/fixtures/` 제외) + `CLAUDE.md` + `docs/philosophy/`. `CHANGELOG.md` · `docs/archive/` · `docs/audits/` · `docs/superpowers/{specs,plans}` 는 **기록물이라 제외** — 그 이름이 남아야 옳다.
- **커밋 메시지**: Conventional Commits. `<type>(<scope>): <한국어 설명>`.

## 목차

- [§0 — 설계가 plan 에 넘긴 미결 5건의 답](#§0--설계가-plan-에-넘긴-미결-5건의-답)
  - [① PR 형태 — 플러그인별 3개, 순서 고정](#①-pr-형태--플러그인별-3개-순서-고정)
  - [② `pre-pipeline-check.sh` 의 staleness anchor](#②-pre-pipeline-checksh-의-staleness-anchor--anchor-를-바꾸지-않고-스크립트를-은퇴시킨다)
  - [③ project-init 의 은퇴-토큰 advisory](#③-project-init-의-은퇴-토큰-advisory--런타임-advisory-를-두지-않는다)
  - [④⑤ — 이 plan 의 범위 밖](#④⑤--이-plan-의-범위-밖)
- [Task 0: 기준선 캡처](#task-0-기준선-캡처)
- [PR A — project-init: `docs-lint` 제거](#pr-a--project-init-docs-lint-제거-211-→-300)
  - [Task 1: 훅과 테스트 삭제 + 플러그인-로컬 락](#task-1-훅과-테스트-삭제--플러그인-로컬-락)
  - [Task 2: 문면 재작성 + 잔여 참조 스윕](#task-2-문면-재작성--잔여-참조-스윕)
  - [Task 3: bump · CHANGELOG · README](#task-3-bump-·-changelog-·-readme-a24·a25)
- [PR B — quality-gates: scope 를 git 으로](#pr-b--quality-gates-scope-를-git-으로-423-→-500)
  - [Task 4: session-tracker 훅 삭제 + 플러그인-로컬 락](#task-4-session-tracker-훅-삭제--플러그인-로컬-락)
  - [Task 5: `pre-pipeline-check.sh` 은퇴](#task-5-pre-pipeline-checksh-은퇴-§0-②)
  - [Task 6: 기본 scope 를 git-도출로 재정의](#task-6-기본-scope-를-git-도출로-재정의-a20·a22)
  - [Task 7: `files.md` 잔여 참조 스윕](#task-7-filesmd-잔여-참조-스윕-a3)
  - [Task 8: bump · CHANGELOG · README](#task-8-bump-·-changelog-·-readme-a24·a25)
- [PR C — spec-distill: `Stop` 훅이 흡수](#pr-c--spec-distill-stop-훅이-흡수-0330-→-0340)
  - [Task 9: `discover_candidates.py` — 발견](#task-9-discover_candidatespy--발견-a5·a6·a17)
  - [Task 10: 원장 확장 — in-flight · validation_attempts](#task-10-원장-확장--in-flight-·-validation_attempts-a12·a14)
  - [Task 11: `resolve_mode` 를 `scripts/` 로 이동](#task-11-resolve_mode-를-scripts-로-이동)
  - [Task 12: `Stop` 훅이 구조 검증을 흡수](#task-12-stop-훅이-구조-검증을-흡수-a4·a10·a11·a13·a15·a16)
  - [Task 13: 훅 둘 삭제 + `pending_review:` 계약 은퇴](#task-13-훅-둘-삭제--pending_review-계약-은퇴-a3·a19)
  - [Task 14: skill·persona 재작성 + 리포 전수 A1 락](#task-14-skill·persona-재작성--리포-전수-a1-락)
  - [Task 15: 행동 케이스 · 비용 측정 · bump](#task-15-행동-케이스-·-비용-측정-·-bump-a7·a8·a9·a20·a24·a26)
- [Self-Review](#self-review-이-plan-을-쓴-뒤-설계와-대조한-결과)

---

## §0 — 설계가 plan 에 넘긴 미결 5건의 답

설계 §14 가 이 자리로 넘긴 것들이다. ①②③ 은 여기서 확정하고 아래 Task 가 그대로 구현한다. ④⑤ 는 이 작업의 범위 밖이다.

### ① PR 형태 — 플러그인별 3개, 순서 고정

`main` 에서 각각 분기하는 **독립 PR 3개**. 쌓지(stack) 않는다.

- 세 플러그인은 파일을 **하나도 공유하지 않는다** — 삭제 대상 8개 검색어 전부가 `CLAUDE.md` 와 `docs/philosophy/` 에서 0 히트다(측정). 유일한 겹침처럼 보이는 `plugins/*/scripts/kill_switch_active.py:51` 은 세 플러그인이 각자 가진 **사본 3개**이고, 각 PR 이 자기 사본만 고친다.
- A24 가 bump·CHANGELOG 를 **플러그인별 독립 판정**으로 요구한다.
- stacked PR 은 base 브랜치 삭제 시 dependent 를 CLOSE 한다(retarget 아님, 재오픈 불가).

**머지 순서: project-init → quality-gates → spec-distill.** 순서는 **락이 스스로 집행한다** — 리포 전수 A1 락(`plugins/*/hooks/hooks.json` glob)은 마지막 PR(spec-distill)에만 들어간다. 그 PR 을 먼저 머지하면 남은 두 플러그인의 write matcher 때문에 락이 RED 를 낸다. 앞선 두 PR 은 자기 플러그인의 `hooks.json` 만 보는 **플러그인-로컬 락**을 갖는다.

### ② `pre-pipeline-check.sh` 의 staleness anchor — anchor 를 바꾸지 않고 스크립트를 은퇴시킨다

설계는 "대체 anchor 가 필요하다"고 적었다. 코드를 읽으니 **대체할 것이 없다**:

| 그 스크립트의 일 | `files.md` 제거 후 |
|---|---|
| SID 존재·패턴 검증 (`no_session_id`·`invalid_session_id`) | `setup-qg.sh:149-166` 이 **같은 검사를 같은 정규식으로 먼저** 수행하고 exit 1 한다. SKILL 은 P2(setup) 다음에 P3(precheck)를 부르므로 이 두 코드는 SKILL 경로에서 이미 도달 불가다 |
| 브랜치 불일치 시 state 삭제 (`cleared_branch_mismatch`) | 삭제 대상이 `files.md` 와 `pipeline.md` 인데, `pipeline.md` 는 **항상 같은 세션 소유**라 C2 가드가 매번 보존한다. `files.md` 가 사라지면 이 코드는 **아무것도 지우지 않고 "지웠다"고 보고한다** |
| staleness (`cleared_stale`) | 위와 같은 이유로 삭제 대상 0 |
| `no_session_data` | `files.md` 부재가 유일한 트리거. 제거 후 `preserved` 와 구별 불가 |
| `branch.md` 유지 | 이 파일의 **생산자도 소비자도 이 스크립트 자신뿐이다** (측정: 살아있는 소비자 표면 전수) |

그래서 `scripts/pre-pipeline-check.sh` · `branch.md` · SKILL.md Step P3 와 그 결과-코드 표를 함께 은퇴시킨다. A21("결과 코드 집합이 유지되고 SKILL.md 의 닫힌 계약이 성립한다")은 **"스크립트가 낼 수 있는 코드 집합 = SKILL 이 처리하는 코드 집합"** 으로 읽고, 그 등식을 락으로 잰다. 은퇴 후 양쪽 집합은 공집합이므로 등식은 성립한다.

**기각한 대안**: 스크립트를 "삭제 없는 브랜치-변경 *감지*"로만 남기기. 기각 사유 — git-도출 scope 에서는 브랜치가 바뀌면 scope 자체가 따라 바뀌고, `check-review-scope.sh` 가 이미 `base` 를 정직-verdict 문구에 싣는다. 감지가 알려줄 새 사실이 없다.

**부수 사실 (이 작업이 만들지 않았다)**: SKILL.md 결과-코드 표의 `active_resume` 행은 **생산자가 리포에 없다**(전수 확인). 오늘 이미 유령 행이며, 표를 지우면 함께 사라진다.

### ③ project-init 의 은퇴-토큰 advisory — 런타임 advisory 를 두지 않는다

은퇴 토큰 advisory 의 목적은 **조용한 재활성화 경고**다. `DEVBREW_SKIP_HOOKS=spec-distill:validator` 를 걸어 구조 검증을 껐던 사용자는, 그 검증이 `Stop` 훅으로 옮겨가면 검증이 **말없이 되살아난다** — 그래서 spec-distill 은 `review-dispatch.py` 가 반드시 알려야 한다(Task 13).

project-init 의 `docs-lint` 는 **옮겨가지 않고 사라진다.** 후임이 없으므로 재활성화될 기능도 없다. 남는 사실은 "환경변수가 존재하지 않는 훅을 가리킨다"뿐이고, 그것은 CHANGELOG Deprecated(A25)와 README 의 자리다. 없는 훅을 가리키는 토큰은 `kill_switch_active` 가 애초에 조회되지 않으므로 fail-open 이 아니다.

**되돌리는 조건**: 그래도 런타임 advisory 를 원한다면 발화할 수 있는 유일한 자리는 `hooks/post-tool-use.py`(`matcher: "Bash"`)이고, **Bash 호출이 없는 세션에서는 발화하지 않는다**. 그 한계를 받아들이는 경우에만 추가한다.

### ④⑤ — 이 plan 의 범위 밖

- ④ codex 재검토: 사용 한도가 2026-09-17 까지 소진돼 있다. 설계 리뷰 5라운드 전부 Claude 단독이었다(R13). 한도 복구 후 재검토 여부는 사용자 판단.
- ⑤ `/cancel-review`: **별도 설계 문서로, 이 plan 실행 다음에** (사용자 결정, 설계 §14).

---

## Task 0: 기준선 캡처

**Files:**
- Create: `docs/superpowers/plans/baseline-2026-08-23.md` (커밋하지 않는다 — 작업용 메모)

**Interfaces:**
- Produces: 세 플러그인 스위트의 pre-existing RED 목록 + 각 항목의 면제 사유 한 줄. Task 3·8·15 의 완료 판정이 이 목록을 뺀 차집합으로 이루어진다.

- [ ] **Step 1: 세 스위트를 순서대로 돌려 결과를 파일에 적는다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
git checkout main && git pull --ff-only 2>/dev/null || true
OUT=docs/superpowers/plans/baseline-2026-08-23.md
: > "$OUT"
for p in project-init quality-gates spec-distill; do
  echo "## $p" >> "$OUT"
  for t in plugins/$p/tests/*.sh; do
    [ -e "$t" ] || continue
    if bash "$t" >/dev/null 2>&1; then r=GREEN; else r=RED; fi
    echo "- $r $(basename "$t")" >> "$OUT"
  done
  for t in plugins/$p/tests/*.py; do
    [ -e "$t" ] || continue
    m=$(basename "$t" .py)
    if (cd "plugins/$p/tests" && python3 -m unittest "$m" >/dev/null 2>&1); then r=GREEN; else r=RED; fi
    echo "- $r $m (py)" >> "$OUT"
  done
done
grep -c RED "$OUT"
```

- [ ] **Step 2: RED 항목마다 면제 사유를 한 줄로 적는다**

`$OUT` 의 각 `- RED` 줄 뒤에 ` — <왜 이 작업과 무관한가>` 를 붙인다. **이유 없는 면제 목록은 그 질문을 영구히 닫는다.** 사유를 못 적는 항목은 면제가 아니라 이 작업이 고쳐야 할 회귀 후보다.

- [ ] **Step 3: quality-gates 의 blessed-red 원장이 비어 있는지 확인**

Run: `bash plugins/quality-gates/tests/test_codex_backward_compat.sh`
Expected: PASS. `plugins/quality-gates/tests/codex-blessed-red.txt` 는 2026-08-22 기준 **등재 0건**이다 — 위 스윕에서 quality-gates RED 가 나오면 그것은 blessed 되지 않은 새 RED 이므로 Step 2 의 사유가 특히 중요하다.

---

# PR A — project-init: `docs-lint` 제거 (2.1.1 → 3.0.0)

브랜치: `fix/project-init-remove-docs-lint`

## Task 1: 훅과 테스트 삭제 + 플러그인-로컬 락

**Files:**
- Delete: `plugins/project-init/hooks/docs-lint.py` (503줄)
- Delete: `plugins/project-init/tests/test_docs_lint.py` (1052줄)
- Modify: `plugins/project-init/hooks/hooks.json`
- Create: `plugins/project-init/tests/test_no_write_matcher_hooks.sh`

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `plugins/project-init/hooks/hooks.json` 에 `PostToolUse` 항목이 정확히 하나(`matcher: "Bash"`, `post-tool-use.py`)만 남은 상태.

- [ ] **Step 1: 실패하는 락을 먼저 쓴다**

Create `plugins/project-init/tests/test_no_write_matcher_hooks.sh`:

```bash
#!/usr/bin/env bash
# project-init 훅 표면 락 — 쓰기 도구에 발화하는 PostToolUse 항목이 없다 (설계 A1·A2).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok()  { echo "  ✓ $1"; }
no()  { echo "  ✗ $1"; FAIL=1; }

python3 - <<'PY'
import json, sys
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
p = "plugins/project-init/hooks/hooks.json"
entries = json.load(open(p, encoding="utf-8"))["hooks"].get("PostToolUse", [])
bad = []
for e in entries:
    m = e.get("matcher")
    # 키 부재와 빈 문자열은 둘 다 "전체 도구 발화" 다 (실측, Claude Code 2.1.239).
    if not m:
        bad.append(("<matcher 부재 또는 빈 문자열>", e))
        continue
    if WRITE_TOOLS & set(x.strip() for x in m.split("|")):
        bad.append((m, e))
if bad:
    for m, e in bad:
        print(f"BAD matcher={m!r} entry={e}", file=sys.stderr)
    sys.exit(1)
# 양성 대조: Bash matcher 는 위반이 아니다 — 하나는 남아 있어야 한다 (A2).
if not any(e.get("matcher") == "Bash" for e in entries):
    print("Bash matcher 항목이 사라졌다 — 양성 대조 실패", file=sys.stderr)
    sys.exit(1)
PY
if [[ $? -eq 0 ]]; then ok "A1/A2: project-init PostToolUse 에 쓰기-도구 matcher 없음 + Bash 항목 생존"; else no "A1/A2 위반"; fi

# 음의 짝 — 삭제된 훅 파일이 실제로 없다. 양의 짝(matcher 검사)은 hooks.json 만 보므로
# 파일이 남아 있어도 통과한다. 이 검사를 지우면 그 사실이 안 보인다.
[[ ! -e plugins/project-init/hooks/docs-lint.py ]] \
  && ok "A3: docs-lint.py 부재" || no "A3: docs-lint.py 가 남아 있다"

exit $FAIL
```

- [ ] **Step 2: 락이 RED 인지 확인**

Run: `bash plugins/project-init/tests/test_no_write_matcher_hooks.sh`
Expected: FAIL — `BAD matcher='Write|Edit|MultiEdit'` 와 `A3: docs-lint.py 가 남아 있다`.

- [ ] **Step 3: 훅과 테스트를 삭제하고 `hooks.json` 을 줄인다**

```bash
git rm plugins/project-init/hooks/docs-lint.py plugins/project-init/tests/test_docs_lint.py
cat > plugins/project-init/hooks/hooks.json <<'JSON'
{
  "description": "project-init - validates branch naming and commit messages on Bash tool calls",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
JSON
```

- [ ] **Step 4: 락이 GREEN 인지 확인**

Run: `bash plugins/project-init/tests/test_no_write_matcher_hooks.sh`
Expected: PASS (3/3 ✓)

- [ ] **Step 5: 락의 이빨을 mutation 으로 증명한다 (네 축)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
T=plugins/project-init/tests/test_no_write_matcher_hooks.sh
H=plugins/project-init/hooks/hooks.json
cp "$H" /tmp/h.bak
# 양성 대조 먼저 — 변이 전 GREEN 이어야 계측기가 살아 있다.
bash "$T" >/dev/null && echo "control GREEN ok"
# 축1 삭제: Bash 항목 제거 → RED 여야 한다 (양성 대조 락)
python3 -c "import json;d=json.load(open('$H'));d['hooks']['PostToolUse']=[];json.dump(d,open('$H','w'))"
bash "$T" >/dev/null 2>&1 && echo "MUT1 GREEN — 락 무이빨" || echo "MUT1 RED ok"
cp /tmp/h.bak "$H"
# 축2 추가: 쓰기 matcher 항목 재추가 → RED
python3 - <<'PY'
import json
p="plugins/project-init/hooks/hooks.json"
d=json.load(open(p)); d["hooks"]["PostToolUse"].append({"matcher":"Write","hooks":[]})
json.dump(d,open(p,"w"))
PY
bash "$T" >/dev/null 2>&1 && echo "MUT2 GREEN — 락 무이빨" || echo "MUT2 RED ok"
cp /tmp/h.bak "$H"
# 축3 형태변경: matcher 키를 통째로 제거 (= 전체 도구 발화) → RED
python3 - <<'PY'
import json
p="plugins/project-init/hooks/hooks.json"
d=json.load(open(p)); d["hooks"]["PostToolUse"].append({"hooks":[]})
json.dump(d,open(p,"w"))
PY
bash "$T" >/dev/null 2>&1 && echo "MUT3 GREEN — 락 무이빨" || echo "MUT3 RED ok"
cp /tmp/h.bak "$H"
# 축4 반전: 빈 문자열 matcher → RED (빈 alternation 은 전체 매칭)
python3 - <<'PY'
import json
p="plugins/project-init/hooks/hooks.json"
d=json.load(open(p)); d["hooks"]["PostToolUse"].append({"matcher":"","hooks":[]})
json.dump(d,open(p,"w"))
PY
bash "$T" >/dev/null 2>&1 && echo "MUT4 GREEN — 락 무이빨" || echo "MUT4 RED ok"
cp /tmp/h.bak "$H"; rm -f /tmp/h.bak
bash "$T" >/dev/null && echo "restored GREEN ok"
```

Expected: `control GREEN ok` · `MUT1..MUT4 RED ok` × 4 · `restored GREEN ok`. 하나라도 `GREEN — 락 무이빨` 이 나오면 락을 다시 만든다.

- [ ] **Step 6: 커밋**

```bash
git add -A plugins/project-init
git commit -m "feat(project-init)!: docs-lint PostToolUse 훅 제거

쓰기-도구 matcher 훅은 Bash heredoc·sed -i 로 쓴 파일을 보지 못한다.
검사를 옮기지 않고 제거한다 (설계 §6).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 2: 문면 재작성 + 잔여 참조 스윕

**Files:**
- Modify: `plugins/project-init/commands/project-init.md:125` (사후-플래그 약속 철회), `:227` (근거 갱신)
- Modify: `plugins/project-init/README.md`
- Modify: `plugins/project-init/tests/smoke.sh`
- Modify: `plugins/project-init/tests/test_agent_permission_contract.py`
- Modify: `plugins/project-init/tests/test_post_tool_use.py`

**Interfaces:**
- Consumes: Task 1 의 삭제 (`docs-lint.py` 부재)
- Produces: §10 oracle 정의역에서 `docs-lint`·`test_docs_lint` 0 히트

- [ ] **Step 1: 약속을 철회한다 (A23)**

`plugins/project-init/commands/project-init.md:125` 의 advisory 문구를 교체한다. 문장만 고치는 것이 아니라 **사후 플래그라는 기능을 제공하지 않는다고 밝힌다.**

```
> `[project-init] charter 미완료: <항목> 비어 abort. git-workflow 산출물은 정상 생성됩니다. 미완 항목의 사후 자동 플래그는 없습니다 — 헌장을 채우려면 /project-init 을 다시 실행하세요.`
```

- [ ] **Step 2: 근거에서 삭제된 참조를 뺀다**

`plugins/project-init/commands/project-init.md:227` 을 교체한다. **배치 결정(링크하지 않음)은 유지하고 근거만 바꾼다** — git 에서 제외되는 파일을 커밋되는 문서가 가리키면 링크가 깨지는 것은 docs-lint 유무와 무관한 사실이다.

```
이 파일은 `AGENTS.md`에서 링크하지 않는다 — git에서 제외되는 파일을 커밋되는 문서가 가리키면 클론한 사람에게 깨진 링크가 된다.
```

- [ ] **Step 3: 나머지 참조를 기계적으로 도출해 제거한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
grep -rn 'docs-lint\|test_docs_lint' plugins/project-init \
  | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md'
```

각 히트를 연다. `README.md` 는 "Hooks Installed" 표 행·디렉토리 트리·kill switch 절, `tests/smoke.sh` 는 훅 실행 검사, 두 파이썬 테스트는 인접 참조다. **삭제가 아니라 재작성이 필요한 자리인지 매 히트마다 판단한다.**

- [ ] **Step 4: 완료 oracle 을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for term in docs-lint test_docs_lint; do
  n=$(grep -rIl -- "$term" plugins CLAUDE.md docs/philosophy 2>/dev/null \
      | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md' | wc -l | tr -d ' ')
  echo "$term: $n"
done
```

Expected: 두 줄 모두 `: 0`

- [ ] **Step 5: project-init 스위트를 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for t in plugins/project-init/tests/*.sh; do echo "== $t"; bash "$t" || echo "RED"; done
cd plugins/project-init/tests && for m in test_agent_permission_contract test_command_contract test_post_tool_use; do
  echo "== $m"; python3 -m unittest "$m" 2>&1 | tail -3; done
```

Expected: Task 0 기준선의 RED 집합과 **같거나 그보다 작다**. 새 RED 는 회귀다.

- [ ] **Step 6: 커밋**

```bash
git add -A plugins/project-init
git commit -m "docs(project-init): 사후-플래그 약속 철회 + docs-lint 잔여 참조 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 3: bump · CHANGELOG · README (A24·A25)

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`
- Modify: `plugins/project-init/CHANGELOG.md`
- Modify: `plugins/project-init/README.md`

**Interfaces:**
- Consumes: Task 1·2
- Produces: PR A 의 머지 가능 상태

- [ ] **Step 1: 버전을 올린다**

`plugins/project-init/.claude-plugin/plugin.json` 의 `"version"` 을 `"2.1.1"` → `"3.0.0"`.

- [ ] **Step 2: CHANGELOG 항목을 쓴다**

`plugins/project-init/CHANGELOG.md` 최상단에 추가. **은퇴 토큰을 문자 그대로 적는다 (A25)** — 문자열 검색으로 찾을 수 있어야 한다.

```markdown
## [3.0.0] — 2026-08-23

### Removed
- **`hooks/docs-lint.py` (PostToolUse, `matcher: "Write|Edit|MultiEdit"`)** — 쓰기-도구 matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못한다. 열거를 고치는 대신 검사 자체를 제거했다(이동 아님). 함께 사라지는 검사: R1 크기 · R2 목차 · R5 코드펜스 언어 · R6 내부 링크 해석 · `CLAUDE.md`↔`AGENTS.md` 포인터 drift · `AGENTS.md` 의 `## Project Charter` 필수 하위항목 무결성. 이것들을 대신 수행하는 훅·테스트·게이트는 리포에 없다.
- `tests/test_docs_lint.py` — 위 훅의 테스트.

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=project-init:docs-lint` 은 가리킬 대상을 잃었다. 설정해도 아무 효과가 없다 — 런타임 advisory 는 두지 않는다(대응하는 기능이 옮겨간 것이 아니라 사라졌으므로 조용한 재활성화가 일어날 수 없다).

### Changed
- `commands/project-init.md` — 헌장 abort advisory 가 더 이상 "docs-lint 이 사후 플래그합니다"를 약속하지 않는다. `.claude/rules/agent-tool-permission.md` 를 `AGENTS.md` 에서 링크하지 않는 배치 결정은 유지하되, 근거에서 docs-lint R6 참조를 뺐다.
```

- [ ] **Step 3: README 를 갱신한다**

"Hooks Installed" 표에서 docs-lint 행 삭제, 디렉토리 트리에서 두 파일 삭제, kill switch 절에 은퇴 사실 한 줄.

- [ ] **Step 4: 커밋하고 PR 을 연다**

```bash
git add -A plugins/project-init
git commit -m "chore(project-init): 3.0.0 — docs-lint 훅 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
git push -u origin fix/project-init-remove-docs-lint
```

PR 본문에 적을 것: 사라지는 6개 검사의 이름, 대체가 없다는 사실, 사용자가 그 손실을 알고 선택했다는 사실.

---

# PR B — quality-gates: scope 를 git 으로 (4.2.3 → 5.0.0)

브랜치: `fix/qg-git-derived-scope` (`main` 에서 분기)

## Task 4: session-tracker 훅 삭제 + 플러그인-로컬 락

**Files:**
- Delete: `plugins/quality-gates/hooks/post-tool-use-session-tracker.py`
- Delete: `plugins/quality-gates/tests/test_session_tracker.py`
- Modify: `plugins/quality-gates/hooks/hooks.json`
- Create: `plugins/quality-gates/tests/test_no_write_matcher_hooks.sh`

**Interfaces:**
- Consumes: 없음
- Produces: `hooks.json` 의 `PostToolUse` 가 `matcher: "Bash"` 한 항목만 갖는 상태

- [ ] **Step 1: 락을 먼저 쓴다**

Create `plugins/quality-gates/tests/test_no_write_matcher_hooks.sh` — Task 1 Step 1 의 파일과 같은 구조. 두 곳을 바꾼다: `p = "plugins/quality-gates/hooks/hooks.json"` 과, 부재를 확인하는 음의 짝을 `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` 로.

```bash
sed -e 's#plugins/project-init/hooks/hooks.json#plugins/quality-gates/hooks/hooks.json#' \
    -e 's#plugins/project-init/hooks/docs-lint.py#plugins/quality-gates/hooks/post-tool-use-session-tracker.py#' \
    -e 's#docs-lint.py 부재#session-tracker 부재#' \
    -e 's#docs-lint.py 가 남아 있다#session-tracker 가 남아 있다#' \
    -e 's#project-init PostToolUse#quality-gates PostToolUse#' \
    plugins/project-init/tests/test_no_write_matcher_hooks.sh \
  > plugins/quality-gates/tests/test_no_write_matcher_hooks.sh
chmod +x plugins/quality-gates/tests/test_no_write_matcher_hooks.sh
```

> PR A 가 아직 머지되지 않아 원본 파일이 없으면, Task 1 Step 1 의 본문을 그대로 옮겨 적고 위 두 경로만 바꾼다. 복사는 문법의 복사이지 정본의 분화가 아니다 — Task 14 의 리포 전수 락이 이 셋을 모두 대체하게 되지만, 각 PR 이 독립적으로 GREEN 이려면 지금은 플러그인-로컬이어야 한다.

- [ ] **Step 2: RED 확인**

Run: `bash plugins/quality-gates/tests/test_no_write_matcher_hooks.sh`
Expected: FAIL — `BAD matcher='Edit|Write|MultiEdit'`

- [ ] **Step 3: 삭제한다**

```bash
git rm plugins/quality-gates/hooks/post-tool-use-session-tracker.py \
       plugins/quality-gates/tests/test_session_tracker.py
python3 - <<'PY'
import json
p = "plugins/quality-gates/hooks/hooks.json"
d = json.load(open(p, encoding="utf-8"))
d["hooks"]["PostToolUse"] = [
    e for e in d["hooks"]["PostToolUse"] if e.get("matcher") == "Bash"
]
d["description"] = ("Quality Gates v5.0.0 — PostToolUse Bash-command validator "
                    "+ SessionStart legacy-state advisor + SessionEnd cleanup. "
                    "Review scope is derived from git, not from an accumulated session file.")
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
open(p, "a", encoding="utf-8").write("\n")
PY
```

- [ ] **Step 4: GREEN 확인 + mutation**

Run: `bash plugins/quality-gates/tests/test_no_write_matcher_hooks.sh`
Expected: PASS

그다음 Task 1 Step 5 의 mutation 블록을 `H=plugins/quality-gates/hooks/hooks.json`, `T=plugins/quality-gates/tests/test_no_write_matcher_hooks.sh` 로 바꿔 그대로 돌린다. 양성 대조 포함 6줄이 기대값이다.

- [ ] **Step 5: 커밋**

```bash
git add -A plugins/quality-gates
git commit -m "feat(quality-gates)!: session-tracker PostToolUse 훅 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 5: `pre-pipeline-check.sh` 은퇴 (§0 ②)

**Files:**
- Delete: `plugins/quality-gates/scripts/pre-pipeline-check.sh`
- Delete: `plugins/quality-gates/tests/test_pre_pipeline_check.sh`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — frontmatter `allowed-tools`(:15), 목차(:80), Step P3(:138-159)
- Modify: `plugins/quality-gates/scripts/check-allowed-tools-order.sh:15`
- Modify: `plugins/quality-gates/tests/test_worktree.sh:17,130-136`
- Modify: `plugins/quality-gates/scripts/read-frontmatter.py:9` (call-site 수 주석)
- Create: `plugins/quality-gates/tests/test_precheck_retired.sh`

**Interfaces:**
- Consumes: Task 4 (`files.md` 생산자 부재)
- Produces: A21 — 스크립트가 낼 수 있는 결과-코드 집합 = SKILL 이 처리하는 집합 (둘 다 공집합)

- [ ] **Step 1: 등식 락을 먼저 쓴다**

Create `plugins/quality-gates/tests/test_precheck_retired.sh`:

```bash
#!/usr/bin/env bash
# A21 — pre-pipeline-check 은퇴 후, "스크립트가 낼 수 있는 결과 코드" 와
# "SKILL 이 처리하는 결과 코드" 두 집합이 같다 (둘 다 공집합).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md

[[ ! -e plugins/quality-gates/scripts/pre-pipeline-check.sh ]] \
  && ok "스크립트 부재" || no "pre-pipeline-check.sh 가 남아 있다"

# 양의 짝 — SKILL 이 그 스크립트를 호출하지 않는다.
grep -q 'pre-pipeline-check' "$SK" \
  && no "SKILL.md 가 아직 pre-pipeline-check 를 부른다" \
  || ok "SKILL.md 에 호출 없음"

# 음의 짝 — 결과 코드 이름이 SKILL 에 유령으로 남아 있지 않다. 양의 짝(호출 부재)은
# 표만 남기고 호출을 지운 상태를 통과시킨다. 그 표는 아무도 채우지 않는 계약이 된다.
GHOST=0
for c in cleared_branch_mismatch cleared_stale fresh_start no_session_data active_resume; do
  if grep -q "$c" "$SK"; then echo "    유령 코드: $c"; GHOST=1; fi
done
[[ $GHOST -eq 0 ]] && ok "SKILL.md 에 유령 결과 코드 없음" || no "SKILL.md 에 유령 결과 코드가 남았다"

# 양성 대조 — setup-qg.sh 의 SID abort 계약은 그대로다 (GREEN 이 정답).
grep -q 'fails pattern guard' plugins/quality-gates/scripts/setup-qg.sh \
  && ok "양성 대조: setup-qg.sh SID 패턴 가드 생존" \
  || no "양성 대조 실패: setup-qg.sh 의 SID 가드가 사라졌다"

# branch.md 는 생산자·소비자가 그 스크립트 자신뿐이었다.
grep -rq 'branch\.md' plugins/quality-gates --include='*.sh' --include='*.py' --include='*.md' \
  --exclude=CHANGELOG.md --exclude-dir=fixtures \
  && no "branch.md 참조가 남았다" || ok "branch.md 참조 0"

exit $FAIL
```

- [ ] **Step 2: RED 확인**

Run: `bash plugins/quality-gates/tests/test_precheck_retired.sh`
Expected: FAIL — 스크립트 존재 · SKILL 호출 존재 · 유령 코드 5개 · branch.md 참조.

- [ ] **Step 3: 스크립트와 그 테스트를 지운다**

```bash
git rm plugins/quality-gates/scripts/pre-pipeline-check.sh \
       plugins/quality-gates/tests/test_pre_pipeline_check.sh
```

- [ ] **Step 4: SKILL.md 의 Step P3 를 제거한다**

`plugins/quality-gates/skills/quality-pipeline/SKILL.md` 에서:

1. frontmatter `allowed-tools`(:15)의 `- Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)` 줄 삭제.
2. 목차(:80)의 `pre-pipeline-check` 문구 삭제 — `- [Preflight](#preflight) — kill switch / setup-qg` 로 줄인다.
3. `**Step P3 — Pre-pipeline check (scope detection).**` 로 시작하는 단락부터 결과-코드 표 끝(`| (other) | Unknown — contract violation | abort with stderr verbatim |`)까지 통째로 삭제하고, 그 자리에 한 문단을 넣는다:

```markdown
**Preflight 는 P2 에서 끝난다.** v5.0.0 이전의 Step P3(`pre-pipeline-check.sh`)는
세션 누적 파일 `files.md` 의 생애를 관리했고, 그 파일이 사라지면서 지울 대상도
알릴 사실도 남지 않았다. SID 존재·패턴 검증은 `setup-qg.sh` 가 P2 에서 같은
정규식으로 먼저 수행하고 exit 1 하므로, 그 계약은 그대로다.
```

- [ ] **Step 5: 나머지 두 참조를 고친다**

- `plugins/quality-gates/scripts/check-allowed-tools-order.sh:15` 의 `'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)'` 항목 삭제 — 이 스크립트는 SKILL frontmatter 의 **순서**를 잠그므로 Step 4-1 과 같은 커밋에서 지워야 한다.
- `plugins/quality-gates/tests/test_worktree.sh` 의 `PRECHECK=` 정의(:17)와 T3d 케이스(:130-136) 삭제.
- `plugins/quality-gates/scripts/read-frontmatter.py:9` 의 `3 call site (pre-pipeline-check.sh × 2, cancel-qg-core.sh × 1)` 를 `1 call site (cancel-qg-core.sh)` 로.

- [ ] **Step 6: GREEN 확인**

Run: `bash plugins/quality-gates/tests/test_precheck_retired.sh`
Expected: PASS (5/5 ✓)

Run: `bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh && bash plugins/quality-gates/tests/test_worktree.sh`
Expected: 둘 다 PASS

- [ ] **Step 7: 락 mutation — 유령 코드 검사가 실제로 문다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
T=plugins/quality-gates/tests/test_precheck_retired.sh
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md
cp "$SK" /tmp/sk.bak
bash "$T" >/dev/null && echo "control GREEN ok"
# 축1 추가: 유령 코드 한 줄을 되살린다 → RED
printf '\n| `no_session_data` | No prior state | normal — silent |\n' >> "$SK"
bash "$T" >/dev/null 2>&1 && echo "MUT1 GREEN — 무이빨" || echo "MUT1 RED ok"
cp /tmp/sk.bak "$SK"
# 축2 형태변경: 호출만 되살리고 표는 안 되살린다 → RED (양의 짝이 잡아야 한다)
printf '\n"${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh"\n' >> "$SK"
bash "$T" >/dev/null 2>&1 && echo "MUT2 GREEN — 무이빨" || echo "MUT2 RED ok"
cp /tmp/sk.bak "$SK"; rm -f /tmp/sk.bak
bash "$T" >/dev/null && echo "restored GREEN ok"
```

Expected: control GREEN · MUT1 RED · MUT2 RED · restored GREEN. **MUT1 과 MUT2 가 서로 다른 검사에 걸려야 한다** — 둘 다 같은 검사에 걸리면 음의 짝이 양의 짝의 동어반복이므로 다시 만든다.

- [ ] **Step 8: 커밋**

```bash
git add -A plugins/quality-gates
git commit -m "feat(quality-gates)!: pre-pipeline-check.sh 은퇴

files.md 가 사라지면서 이 스크립트의 삭제 대상이 0이 됐다. pipeline.md 는
항상 같은 세션 소유라 C2 가드가 매번 보존하므로 cleared_* 코드는 아무것도
지우지 않고 지웠다고 보고하게 된다. SID 검증은 setup-qg.sh 가 P2 에서
같은 정규식으로 먼저 한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 6: 기본 scope 를 git-도출로 재정의 (A20·A22)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:285` (scope transparency), `:514-519` (`$resolved_scope_file_count`), `:318`, `:370`
- Modify: `plugins/quality-gates/commands/qg.md:143-160` (Scope 절), `:124-128` (표)
- Create: `plugins/quality-gates/tests/test_git_derived_scope.sh`

**Interfaces:**
- Consumes: Task 4·5
- Produces: `$resolved_scope_file_count` 의 session 분기가 `check-review-scope.sh` 의 `$branch_ahead_count` + worktree 변경 파일로 정의된 상태. Task 8 의 CHANGELOG 가 이 계약 변경을 기록한다.

- [ ] **Step 1: 락을 먼저 쓴다**

Create `plugins/quality-gates/tests/test_git_derived_scope.sh`:

```bash
#!/usr/bin/env bash
# A20·A22 — 기본 scope 정의가 git 에서 오고, 판정-불가 degrade 분기가 살아 있다.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md

# 양의 짝 — $resolved_scope_file_count 정의가 git 을 근거로 든다.
DEF="$(awk '/resolved_scope_file_count. = the file count/,/do not re-measure/' "$SK")"
[[ -n "$DEF" ]] || { no "정의 단락을 찾지 못했다 (앵커 이동)"; exit 1; }
grep -qF 'check-review-scope.sh' <<<"$DEF" \
  && ok "A22: 정의가 check-review-scope.sh 를 근거로 든다" \
  || no "A22: 정의가 git 산출 신호를 근거로 들지 않는다"

# 음의 짝 — 그 정의가 files.md 를 근거로 들지 않는다. 양의 짝은 두 근거를 함께
# 적은 문서를 통과시킨다(추가는 통과, 삭제만 잡힌다).
grep -qF 'files.md' <<<"$DEF" \
  && no "A22: 정의가 아직 files.md 를 근거로 든다" \
  || ok "A22: 정의에 files.md 없음"

# degrade 분기 보존 — 판정 불가를 조용히 0으로 취급하지 않는다.
grep -qF 'do NOT silently treat it as 0' <<<"$DEF" \
  && ok "A22: 판정-불가 degrade 분기 생존" \
  || no "A22: degrade 분기가 사라졌다"

# 정직-verdict floor 자체는 이 작업이 건드리지 않는다 (양성 대조 — GREEN 이 정답).
grep -qF 'NOT certified clean' "$SK" \
  && ok "양성 대조: 정직-verdict floor 문구 생존" \
  || no "양성 대조 실패: floor 문구가 사라졌다"

# 리포 전체에서 files.md 가 살아있는 소비자 표면에 0건.
N=$(grep -rIl -- 'files\.md' plugins CLAUDE.md docs/philosophy 2>/dev/null \
    | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md' | wc -l | tr -d ' ')
[[ "$N" == "0" ]] && ok "files.md 살아있는 참조 0" || no "files.md 참조 $N 파일"

exit $FAIL
```

- [ ] **Step 2: RED 확인**

Run: `bash plugins/quality-gates/tests/test_git_derived_scope.sh`
Expected: FAIL (최소 3건)

- [ ] **Step 3: `$resolved_scope_file_count` 정의를 다시 쓴다 (SKILL.md:514-519)**

기존 단락을 아래로 교체한다. **degrade 분기는 문장을 그대로 옮겨 유지한다** — scope 와 floor 가 갈라질 수 있는 유일한 자리이고, 그것은 신호가 아니라 degrade 다.

```markdown
   **Resolved-scope file count (floor input — reuse, not a new measurement).**
   `$resolved_scope_file_count` = the file count of the scope you resolved at
   step 1. All three modes now derive from git, not from an accumulated session
   file: for the default (`session`) and for `branch` it is the cached
   `$branch_ahead_count` from `check-review-scope.sh` when the worktree is clean,
   and that count plus the worktree's own changed files when `$worktree_dirty ==
   yes`; for `paths` it is the number of `--paths` glob matches you resolved. If
   this count cannot be determined (e.g. `check-review-scope.sh` reported
   `degraded: yes`), do NOT silently treat it as 0 — treat the run as `$degraded
   == yes` for the floor (the ELSE-IF branch below + loud advisory). This is an
   already-known value; do not re-measure (the orchestrator has no raw-git/grep tool).
```

- [ ] **Step 4: scope transparency 한 줄을 고친다 (SKILL.md:285)**

`(<COUNT> = preflight files.md 항목 수)` 를 `(<COUNT> = $resolved_scope_file_count — Step 1b 의 check-review-scope.sh 산출값)` 으로. 같은 줄의 `session (<COUNT> files edited this session)` 은 `session (<COUNT> changed files)` 으로 — 편집 주체가 아니라 git 이 보는 변경이라는 사실을 문구가 말하게 한다.

- [ ] **Step 5: 나머지 두 문구를 고친다**

- `:318` 의 `the session files.md set` → `the git-derived changed-file set`
- `:370` 의 `session (files.md set)` → `session (git-derived changed files)`

- [ ] **Step 6: `commands/qg.md` 의 Scope 절을 다시 쓴다**

`:143-160` 의 "### Scope (default: session)" 절에서 훅·`files.md`·`pre-pipeline-check.sh` 를 근거로 든 두 문장을 교체한다:

```markdown
### Scope (default: git 변경)

`/qg` 는 **git 이 보고하는 변경**을 기본 scope 로 리뷰한다 — base 대비 브랜치 diff
와 worktree 변경의 합집합이며, `scripts/check-review-scope.sh` 가 결정론으로
산출한다. v5.0.0 이전에는 PostToolUse 훅이 편집 파일을 누적했고, 그래서 Bash
heredoc·`sed -i` 로 쓴 파일이 scope 에서 조용히 빠졌다. git 도출은 어떤 도구로
썼든 같은 답을 낸다.

**리포 밖 절대경로 편집은 잡히지 않는다** — `--paths` 로 명시한다.
```

`:124-128` 표의 `session-scoped diff` 를 `git-derived diff (branch + worktree)` 로.

- [ ] **Step 7: GREEN 확인**

Run: `bash plugins/quality-gates/tests/test_git_derived_scope.sh`
Expected: 마지막 검사(`files.md` 0건)를 제외하고 PASS. Task 7 이 나머지 참조를 지운 뒤 5/5 가 된다.

- [ ] **Step 8: 커밋**

```bash
git add -A plugins/quality-gates
git commit -m "feat(quality-gates)!: 기본 scope 를 git 도출로 재정의

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 7: `files.md` 잔여 참조 스윕 (A3)

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-gc.py`, `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`, `plugins/quality-gates/README.md`, `plugins/quality-gates/tests/e2e-scenarios.md`, `plugins/quality-gates/scripts/kill_switch_active.py:51`
- Modify: `plugins/quality-gates/tests/{test_qg_false_clean_floor.sh,test_session_end_cleanup.py,test_kill_switches.py,test_qg_gc.py,test_utf8_explicit.py,test_hook_cwd_contract.py,lib/extract_codex_invocations.py}`

**Interfaces:**
- Consumes: Task 4·6
- Produces: oracle GREEN — `post-tool-use-session-tracker`·`files.md` 가 살아있는 소비자 표면에서 0 히트

- [ ] **Step 1: 목록을 기계적으로 도출한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for term in post-tool-use-session-tracker 'files\.md'; do
  echo "=== $term"
  grep -rn -- "$term" plugins CLAUDE.md docs/philosophy 2>/dev/null \
    | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md'
done
```

- [ ] **Step 2: 히트마다 삭제인지 재작성인지 판단한다**

| 파일 | 처분 |
|---|---|
| `scripts/qg-gc.py` | `files.md` 를 GC 대상으로 여는 코드 — 그 파일이 더는 생기지 않으므로 삭제. 다른 상태 파일 정리는 유지 |
| `skills/quality-pipeline/references/state-file-format.md` | `files.md` 와 `branch.md` 스키마 절 삭제, `pipeline.md`·`publish-eligible.md` 는 유지 |
| `README.md` | 훅 표 행 · 디렉토리 트리 · state 파일 목록 · `QG_STALE_HOURS` 항목 |
| `tests/e2e-scenarios.md` | 시나리오 본문 재작성 (git-도출 scope 기준) |
| `scripts/kill_switch_active.py:51` | 주석의 접두 오탐 예시. `quality-gates:post-tool-use` 가 다른 토큰의 접두라는 사실 자체는 유효하니 **살아있는 토큰**을 예시로 바꾼다 |
| `tests/test_session_end_cleanup.py` 등 6개 | `files.md` 를 만들어 넣는 fixture 를 `pipeline.md` 로 교체하거나 해당 케이스 삭제 |

- [ ] **Step 3: oracle 을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for term in post-tool-use-session-tracker 'files\.md'; do
  n=$(grep -rIl -- "$term" plugins CLAUDE.md docs/philosophy 2>/dev/null \
      | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md' | wc -l | tr -d ' ')
  echo "$term: $n"
done
```

Expected: 둘 다 `: 0`

> **주의**: `plugins/project-init/scripts/kill_switch_active.py` 와 `plugins/spec-distill/scripts/kill_switch_active.py` 도 같은 주석을 갖고 있다. 이 PR 은 quality-gates 사본만 고친다 — 나머지 둘은 각자 PR 소관이고, PR A 는 이미 머지됐으므로 project-init 사본은 별도 후속으로 남는다. **oracle 이 0 이 아니면 그 사실을 CHANGELOG 에 적고 넘어가지 말 것** — 어느 사본이 왜 남았는지 한 줄로 밝힌다.

- [ ] **Step 4: quality-gates 스위트를 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for t in plugins/quality-gates/tests/*.sh; do
  bash "$t" >/dev/null 2>&1 || echo "RED $(basename "$t")"
done
cd plugins/quality-gates/tests
for f in *.py; do m="${f%.py}"; python3 -m unittest "$m" >/dev/null 2>&1 || echo "RED $m (py)"; done
```

Expected: Task 0 기준선의 RED 집합과 같거나 그보다 작다.

- [ ] **Step 5: 커밋**

```bash
git add -A plugins/quality-gates
git commit -m "refactor(quality-gates): files.md 잔여 참조 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 8: bump · CHANGELOG · README (A24·A25)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`, `CHANGELOG.md`, `README.md`

**Interfaces:**
- Consumes: Task 4–7
- Produces: PR B 의 머지 가능 상태

- [ ] **Step 1: 버전 `4.2.3` → `5.0.0`**

- [ ] **Step 2: CHANGELOG**

```markdown
## [5.0.0] — 2026-08-23

### Removed
- **`hooks/post-tool-use-session-tracker.py` (PostToolUse, `matcher: "Edit|Write|MultiEdit"`)** 와 그 산출물 `.claude/quality-gates/<sid>/files.md`. 쓰기-도구 matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못해 `/qg` 가 좁은 scope 로 돌았다.
- **`scripts/pre-pipeline-check.sh`** 와 `.claude/quality-gates/<sid>/branch.md`. 이 스크립트의 삭제 대상은 `files.md` 하나였다 — `pipeline.md` 는 항상 같은 세션 소유라 C2 가드가 매번 보존하므로, `files.md` 없이는 `cleared_branch_mismatch`·`cleared_stale` 이 아무것도 지우지 않고 지웠다고 보고하게 된다. SID 존재·패턴 검증은 `setup-qg.sh` 가 Preflight P2 에서 같은 정규식으로 먼저 수행하고 exit 1 한다.
- SKILL.md 의 Step P3 와 결과-코드 표 (`fresh_start`·`preserved`·`no_session_data`·`cleared_branch_mismatch`·`cleared_stale`·`active_resume`). `active_resume` 은 이 릴리스 이전에도 **생산자가 없는 유령 행**이었다.
- `tests/test_session_tracker.py` · `tests/test_pre_pipeline_check.sh`

### Changed
- **`/qg` 기본 scope 가 "이 세션이 편집한 파일"에서 "git 이 보고하는 변경"으로 바뀐다** (breaking, 관측 가능한 기본 동작 변경). Bash 로 쓴 파일이 이제 잡힌다. 세션 중 커밋된 변경은 base 대비 diff 가 잡는다. **리포 밖 절대경로 편집은 잡히지 않는다** — `--paths` 로 명시한다.
- `$resolved_scope_file_count` 의 정의가 `check-review-scope.sh` 산출값 기반으로 재작성됐다. 판정-불가 degrade 분기("조용히 0으로 취급하지 말 것")는 그대로 유지된다.

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=quality-gates:session-tracker` 은 가리킬 대상을 잃었다.
- 환경변수 `QG_STALE_HOURS` 는 소비자를 잃었다 (`pre-pipeline-check.sh` 가 유일한 독자였다).

### Performance
- 기준선/비교군 측정 (설계 §8): <Task 15 Step 4 의 측정 결과를 여기에 옮겨 적는다>
```

- [ ] **Step 3: README 갱신** — "Hooks Installed" 표, 디렉토리 트리, state 파일 목록(`:478`), `QG_STALE_HOURS`(`:411`), 파이프라인 다이어그램(`:256`).

- [ ] **Step 4: 커밋 + PR**

```bash
git add -A plugins/quality-gates
git commit -m "chore(quality-gates): 5.0.0 — git 도출 scope

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
git push -u origin fix/qg-git-derived-scope
```

PR 본문: 기본 scope 변경이 breaking 이라는 사실, 리포 밖 절대경로 편집이 빠진다는 사실(§13 R7), `pre-pipeline-check.sh` 은퇴가 설계 §14 미결 2 의 답이며 anchor 교체가 아니라는 사실.

---

# PR C — spec-distill: `Stop` 훅이 흡수 (0.33.0 → 0.34.0)

브랜치: `fix/spec-distill-stop-absorbs-validator` (`main` 에서 분기)

## Task 9: `discover_candidates.py` — 발견 (A5·A6·A17)

**Files:**
- Create: `plugins/spec-distill/scripts/discover_candidates.py`
- Create: `plugins/spec-distill/tests/test_discover_candidates.py`

**Interfaces:**
- Consumes: `arm_ledger.canonical_key(raw_path) -> str | None`, `arm_ledger.PREFIX`
- Produces:
  - `discover(cwd: Path | None = None) -> list[Candidate]`
  - `Candidate = namedtuple("Candidate", "path key born")` — `path` 는 리포 루트 상대 str, `key` 는 `canonical_key` 결과, `born` 은 bool
  - `class GitUnavailable(Exception)` — 후보 0 과 **구별되는** 실패 신호 (A16 이 이 구별에 기댄다)
  - `parse_status_z(raw: bytes) -> list[tuple[str, str]]` — `(xy, path)` 목록
  - `born_from_status(xy: str) -> bool`

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

Create `plugins/spec-distill/tests/test_discover_candidates.py`:

```python
#!/usr/bin/env python3
"""discover_candidates 단위 테스트 — A5(술어 일치) · A6(born 도출) · A17(파싱)."""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import arm_ledger  # noqa: E402
spec = importlib.util.spec_from_file_location("dc", SCRIPTS / "discover_candidates.py")
dc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dc)

PREFIX = arm_ledger.PREFIX


def git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True)


class TestParseStatusZ(unittest.TestCase):
    def test_plain_records(self):
        raw = b"?? a.md\x00 M b.md\x00"
        self.assertEqual(dc.parse_status_z(raw), [("??", "a.md"), (" M", "b.md")])

    def test_rename_consumes_orig_path_field(self):
        # rename/copy 항목은 `XY path\0origPath\0` 로 필드가 둘이다. orig 를 레코드로
        # 소비하면 이후 전체 항목이 한 칸씩 밀린다.
        raw = b"R  new.md\x00old.md\x00 M after.md\x00"
        self.assertEqual(dc.parse_status_z(raw),
                         [("R ", "new.md"), (" M", "after.md")])

    def test_space_and_newline_in_path(self):
        raw = b"?? a b.md\x00?? c\nd.md\x00"
        self.assertEqual(dc.parse_status_z(raw), [("??", "a b.md"), ("??", "c\nd.md")])

    def test_non_utf8_bytes_survive_as_replacement(self):
        raw = b"?? bad\xff.md\x00"
        got = dc.parse_status_z(raw)
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0][0], "??")

    def test_trailing_garbage_without_nul_is_dropped(self):
        self.assertEqual(dc.parse_status_z(b"?? a.md\x00?? trunc"), [("??", "a.md")])


class TestBornAgreesWithArmLedger(unittest.TestCase):
    """A6 — born 도출이 arm_ledger.is_born 과 모든 도달 가능 조합에서 일치한다.

    코드를 열거하지 않는다. 픽스처로 상태를 만들고 git 이 실제로 낸 XY 를 받아
    두 판정을 비교한다 — `AM` 같은 조합이 열거에서 빠지는 실패를 구조적으로 막는다.
    """

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        # macOS 의 /tmp 는 /private/tmp 심볼릭 링크다 — 경로 포함 검사가 조용히 무너진다.
        self.tmp = Path(subprocess.run(["pwd", "-P"], cwd=self.tmp, capture_output=True,
                                       text=True, check=True).stdout.strip())
        git("init", "-q", cwd=self.tmp)
        git("config", "user.email", "t@t", cwd=self.tmp)
        git("config", "user.name", "t", cwd=self.tmp)
        self.specs = self.tmp / PREFIX
        self.specs.mkdir(parents=True)

    def _mk(self, name, body="x\n"):
        p = self.specs / name
        p.write_text(body, encoding="utf-8")
        return p

    def test_all_reachable_combos_agree(self):
        # 1) untracked
        self._mk("untracked-design.md")
        # 2) staged-new (A )
        p = self._mk("added-design.md"); git("add", str(p), cwd=self.tmp)
        # 3) committed clean, then worktree-modified ( M)
        p = self._mk("mod-design.md"); git("add", str(p), cwd=self.tmp)
        # 4) staged-then-modified (AM) — 이 설계가 겨냥하는 바로 그 시나리오
        p4 = self._mk("am-design.md"); git("add", str(p4), cwd=self.tmp)
        git("commit", "-q", "-m", "c", cwd=self.tmp)
        (self.specs / "mod-design.md").write_text("y\n", encoding="utf-8")
        p4b = self._mk("am2-design.md"); git("add", str(p4b), cwd=self.tmp)
        p4b.write_text("z\n", encoding="utf-8")   # → AM

        raw = subprocess.run(["git", "status", "--porcelain", "-z",
                              "--untracked-files=all"],
                             cwd=self.tmp, capture_output=True, check=True).stdout
        records = dc.parse_status_z(raw)
        self.assertTrue(records, "픽스처가 아무 상태도 만들지 못했다 — 계측기 고장")
        seen = set()
        cwd0 = os.getcwd()
        os.chdir(self.tmp)
        try:
            for xy, path in records:
                if not (self.tmp / path).exists():
                    continue           # 존재 필터가 born 판정보다 앞선다
                seen.add(xy)
                self.assertEqual(
                    dc.born_from_status(xy), arm_ledger.is_born(path),
                    f"XY={xy!r} path={path!r} 에서 born 판정이 갈렸다")
        finally:
            os.chdir(cwd0)
        # 양성 대조 — 픽스처가 의도한 조합을 실제로 만들었는가.
        self.assertIn("??", seen)
        self.assertIn("A ", seen)
        self.assertIn(" M", seen)
        self.assertIn("AM", seen)


class TestGitIsOnlyAnUpperBound(unittest.TestCase):
    """A5 — in-scope 판정은 canonical_key 단독. git 은 상계만 준다."""

    def test_out_of_scope_dirty_file_is_not_a_candidate(self):
        recs = [("??", "README.md"), ("??", PREFIX + "x-design.md")]
        keys = [c.key for c in dc.candidates_from_records(recs, exists=lambda p: True)]
        self.assertEqual(keys, [PREFIX + "x-design.md"])

    def test_predicate_is_canonical_key_itself(self):
        # 술어를 재구현하지 않는다는 것을 성질로 잰다: canonical_key 가 None 을 내는
        # 입력은 무엇이든 후보가 아니다.
        bad = PREFIX + "with\nnewline-design.md"
        self.assertIsNone(arm_ledger.canonical_key(bad))
        self.assertEqual(dc.candidates_from_records([("??", bad)],
                                                    exists=lambda p: True), [])

    def test_nested_prefix_path_is_a_candidate(self):
        # 판본 4·5 가 두 번 놓친 자리 — 중첩 접두. pathspec 을 쓰지 않으므로
        # 이 케이스는 구조적으로 빠질 수 없다.
        nested = "sub/dir/" + PREFIX + "y-design.md"
        self.assertEqual(
            [c.key for c in dc.candidates_from_records([("??", nested)],
                                                       exists=lambda p: True)],
            [PREFIX + "y-design.md"])


class TestGitUnavailableIsDistinctFromEmpty(unittest.TestCase):
    def test_non_repo_raises(self):
        tmp = Path(tempfile.mkdtemp())
        with self.assertRaises(dc.GitUnavailable):
            dc.discover(cwd=tmp)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_discover_candidates -v`
Expected: `ModuleNotFoundError`/`FileNotFoundError` — `discover_candidates.py` 가 없다.

- [ ] **Step 3: 모듈을 구현한다**

Create `plugins/spec-distill/scripts/discover_candidates.py`:

```python
#!/usr/bin/env python3
"""스코프 문서 발견 — git 은 상계, 판정은 arm_ledger.canonical_key (설계 §4.2).

`git status` 에 **pathspec 을 주지 않는다.** 판본 4 는 `:(top,literal)` 로 중첩
접두를 빠뜨렸고, 판본 5 의 `:(glob)**docs/…` 는 선행 `**` 가 완전한 경로 컴포넌트가
아니라 `:(top,literal)` 과 동일 집합을 냈다(실측) — 고치려던 결함이 그대로였다.
슬래시를 넣은 `**/` 도 `canonical_key` 의 substring 의미와는 다른 집합이다.
그래서 wildmatch 를 쓰지 않는다: git 은 dirty 집합 전체를 상계로 주고, 좁히는 일은
플러그인 자신의 술어가 단독으로 한다. 이 형태에서는 pathspec 문법이 방정식에서
빠지므로 그 실패가 재발할 수 없다.
"""
from __future__ import annotations

import subprocess
import sys
from collections import namedtuple
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))
from arm_ledger import canonical_key  # noqa: E402 # pyright: ignore[reportMissingImports]

#: Stop 훅 전체 timeout 이 10초라 git 호출은 그 절반으로 묶는다 (arm_ledger 와 같은 값).
GIT_TIMEOUT_SEC = 5

#: rename/copy 항목만 `XY path\0origPath\0` 로 필드가 둘이다.
_TWO_FIELD_INDEX_STATES = ("R", "C")

Candidate = namedtuple("Candidate", "path key born")


class GitUnavailable(Exception):
    """git 을 쓸 수 없다. **후보 0 과 구별돼야 한다** — A16 이 이 구별에 기댄다."""


def parse_status_z(raw: bytes) -> list[tuple[str, str]]:
    """`git status --porcelain -z` 출력을 `(XY, path)` 목록으로.

    NUL 로 쪼갠 뒤 필드를 **레코드 단위로** 소비한다. rename/copy 는 뒤따르는
    origPath 필드를 함께 먹어야 하며, 그러지 않으면 이후 전체 항목이 한 칸씩 밀린다.
    """
    fields = raw.split(b"\x00")
    out: list[tuple[str, str]] = []
    i = 0
    while i < len(fields):
        f = fields[i]
        i += 1
        if len(f) < 4 or f[2:3] != b" ":
            continue            # 마지막 빈 필드 · 잘린 꼬리
        xy = f[:2].decode("utf-8", "replace")
        path = f[3:].decode("utf-8", "replace")
        if xy[0] in _TWO_FIELD_INDEX_STATES or xy[1] in _TWO_FIELD_INDEX_STATES:
            i += 1              # origPath 필드를 소비한다
        out.append((xy, path))
    return out


def born_from_status(xy: str) -> bool:
    """인덱스 자리(X)가 `?` 가 아니면 인덱스 항목이 있다 = born.

    코드를 열거하지 않고 **자리로 읽는다.** 열거는 조합을 빠뜨리고, 빠지는 대표
    사례가 하필 `AM`(git add 후 Bash 로 수정)이다 — 이 설계가 겨냥하는 시나리오.
    """
    return xy[:1] != "?"


def candidates_from_records(records, exists) -> list[Candidate]:
    """레코드 → 후보. `exists` 는 파일 존재 술어(테스트가 주입한다).

    존재 검사가 born 판정보다 **앞선다**: 스테이지된 삭제(`D `)처럼 디스크에 없는
    항목은 검증할 대상 자체가 없으므로 born 을 물을 이유가 없다. 이 순서가
    `D`·`R`·`C` 를 코드로 열거하지 않고 흡수한다.
    """
    out: list[Candidate] = []
    for xy, path in records:
        if not exists(path):
            continue
        key = canonical_key(path)
        if key is None:
            continue
        out.append(Candidate(path=path, key=key, born=born_from_status(xy)))
    out.sort(key=lambda c: c.key)
    return out


def discover(cwd: Path | None = None) -> list[Candidate]:
    """이 리포의 dirty·untracked 스코프 문서. git 불능이면 GitUnavailable."""
    root = Path(cwd) if cwd is not None else Path.cwd()
    try:
        cp = subprocess.run(
            ["git", "status", "--porcelain", "-z", "--untracked-files=all"],
            cwd=str(root), capture_output=True, check=False, timeout=GIT_TIMEOUT_SEC,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GitUnavailable(str(exc)) from exc
    if cp.returncode != 0:
        raise GitUnavailable(cp.stderr.decode("utf-8", "replace").strip()
                             or f"git status rc={cp.returncode}")
    return candidates_from_records(
        parse_status_z(cp.stdout), exists=lambda p: (root / p).exists())
```

- [ ] **Step 4: GREEN 확인**

Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_discover_candidates -v`
Expected: 전 케이스 PASS

- [ ] **Step 5: mutation — 네 축**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
M=plugins/spec-distill/scripts/discover_candidates.py
RUN='cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_discover_candidates'
cp "$M" /tmp/dc.bak
# 계측기 양성 대조 — 변이 전에 파싱이 되는지, 스위트가 GREEN 인지 둘 다 본다.
python3 -c "import ast;ast.parse(open('$M').read())" && echo "ast ok"
eval "$RUN" >/dev/null 2>&1 && echo "control GREEN ok" || echo "control RED — 계측기 고장"
# 축1 삭제: origPath 소비 제거 → rename 테스트 RED
python3 - <<'PY'
p="plugins/spec-distill/scripts/discover_candidates.py"
s=open(p).read().replace("            i += 1              # origPath 필드를 소비한다\n","")
open(p,"w").write(s)
PY
eval "$RUN" >/dev/null 2>&1 && echo "MUT1 GREEN — 무이빨" || echo "MUT1 RED ok"; cp /tmp/dc.bak "$M"
# 축2 반전: born 규칙을 뒤집는다 → 대조 테스트 RED
sed -i '' 's/return xy\[:1\] != "?"/return xy[:1] == "?"/' "$M"
eval "$RUN" >/dev/null 2>&1 && echo "MUT2 GREEN — 무이빨" || echo "MUT2 RED ok"; cp /tmp/dc.bak "$M"
# 축3 형태변경: canonical_key 를 자체 술어로 재구현 (PREFIX 부분문자열 검사)
python3 - <<'PY'
p="plugins/spec-distill/scripts/discover_candidates.py"
s=open(p).read().replace("        key = canonical_key(path)",
                         "        key = path if 'docs/superpowers/specs/' in path else None")
open(p,"w").write(s)
PY
eval "$RUN" >/dev/null 2>&1 && echo "MUT3 GREEN — 무이빨" || echo "MUT3 RED ok"; cp /tmp/dc.bak "$M"
# 축4 추가: pathspec 을 다시 넣는다 (판본 4 의 결함 재도입) → 중첩 접두 테스트 RED
python3 - <<'PY'
p="plugins/spec-distill/scripts/discover_candidates.py"
s=open(p).read().replace('"--untracked-files=all"],',
                         '"--untracked-files=all", "--", ":(top,literal)docs/superpowers/specs/"],')
open(p,"w").write(s)
PY
eval "$RUN" >/dev/null 2>&1 && echo "MUT4 GREEN — 무이빨" || echo "MUT4 RED ok"; cp /tmp/dc.bak "$M"
rm -f /tmp/dc.bak
eval "$RUN" >/dev/null 2>&1 && echo "restored GREEN ok"
```

> 축4 는 `discover()` 를 실제로 도는 테스트가 있어야 잡힌다. `TestGitIsOnlyAnUpperBound` 는 순수 함수만 부르므로 이 변이를 통과한다 — **그러면 그 사실이 발견이다.** `discover()` 를 중첩 접두 픽스처로 도는 케이스를 `test_discover_candidates.py` 에 추가하고 MUT4 를 다시 돌린다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/discover_candidates.py \
        plugins/spec-distill/tests/test_discover_candidates.py
git commit -m "feat(spec-distill): discover_candidates — git 상계 + canonical_key 판정

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 10: 원장 확장 — in-flight · validation_attempts (A12·A14)

**Files:**
- Modify: `plugins/spec-distill/scripts/arm_ledger.py`
- Modify: `plugins/spec-distill/tests/test_arm_ledger.py`

**Interfaces:**
- Consumes: 기존 `_compose`·`armed_keys`·`attempts`
- Produces:
  - `INFLIGHT_RE` · `VALIDATION_RE`
  - `inflight(body: str) -> dict[str, str]` — key → ISO 타임스탬프
  - `mark_inflight(body: str, raw_path: str, now_iso: str) -> str`
  - `clear_inflight(body: str, raw_path: str) -> str`
  - `is_inflight(body: str, raw_path: str, now, ttl_sec: int) -> bool`
  - `validation_attempts(body: str) -> dict[str, int]` · `next_validation(body, raw_path) -> int` · `record_validation(body, raw_path, n) -> str`
  - `VALIDATION_ATTEMPT_CAP = 3`
  - `INFLIGHT_TTL_SEC = 900`
  - CLI `clear-inflight <sid> <raw_path>`
  - `mark_reviewed` 가 in-flight 항목도 함께 지운다

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`plugins/spec-distill/tests/test_arm_ledger.py` 끝에 클래스를 추가한다:

```python
class TestInflightLedger(unittest.TestCase):
    """A12 — 리뷰 진행 중인 문서는 발견 결과에서 제외된다."""

    K = "docs/superpowers/specs/x-design.md"
    BODY = "---\nsession_id: s\n---\n\n"

    def test_mark_then_read(self):
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        self.assertEqual(arm_ledger.inflight(b), {self.K: "2026-08-23T00:00:00Z"})

    def test_clear_removes_only_that_key(self):
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        b = arm_ledger.mark_inflight(b, self.K.replace("x-", "y-"), "2026-08-23T00:00:00Z")
        b = arm_ledger.clear_inflight(b, self.K)
        self.assertEqual(list(arm_ledger.inflight(b)), [self.K.replace("x-", "y-")])

    def test_armed_and_attempts_blocks_survive(self):
        b = arm_ledger.mark_armed(self.BODY, self.K)
        b = arm_ledger.record_attempt(b, self.K, 2)
        b = arm_ledger.mark_inflight(b, self.K, "2026-08-23T00:00:00Z")
        self.assertIn(self.K, arm_ledger.armed_keys(b))
        self.assertEqual(arm_ledger.attempts(b)[self.K], 2)
        self.assertIn(self.K, arm_ledger.inflight(b))

    def test_expired_inflight_is_not_inflight(self):
        from datetime import datetime, timezone, timedelta
        t0 = datetime(2026, 8, 23, 0, 0, 0, tzinfo=timezone.utc)
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        self.assertTrue(arm_ledger.is_inflight(b, self.K, t0, 900))
        self.assertFalse(
            arm_ledger.is_inflight(b, self.K, t0 + timedelta(seconds=901), 900))

    def test_unparseable_timestamp_is_not_inflight(self):
        # 판독 불가 타임스탬프로 게이트가 영구히 닫히면 Law 1 이 금지하는 방향
        # (under-review) 으로 fail 한다. 만료로 읽어 dispatch 쪽으로 연다.
        from datetime import datetime, timezone
        b = arm_ledger.mark_inflight(self.BODY, self.K, "not-a-time")
        self.assertFalse(arm_ledger.is_inflight(
            b, self.K, datetime(2026, 8, 23, tzinfo=timezone.utc), 900))

    def test_mark_reviewed_clears_inflight(self):
        d = Path(tempfile.mkdtemp()) / "state.local.md"
        d.parent.mkdir(parents=True, exist_ok=True)
        d.write_text(arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z"),
                     encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(d, self.K))
        b = d.read_text(encoding="utf-8")
        self.assertIn(self.K, arm_ledger.armed_keys(b))
        self.assertNotIn(self.K, arm_ledger.inflight(b))


class TestValidationAttempts(unittest.TestCase):
    """A14 — 검증 실패 상한. dispatch_attempts 와 **별도** 카운터다."""

    K = "docs/superpowers/specs/x-design.md"
    BODY = "---\nsession_id: s\n---\n\n"

    def test_separate_from_dispatch_attempts(self):
        b = arm_ledger.record_validation(self.BODY, self.K, 2)
        self.assertEqual(arm_ledger.validation_attempts(b)[self.K], 2)
        self.assertEqual(arm_ledger.attempts(b), {})

    def test_cap_is_three_and_independent(self):
        self.assertEqual(arm_ledger.VALIDATION_ATTEMPT_CAP, 3)
        self.assertEqual(arm_ledger.DISPATCH_ATTEMPT_CAP, 3)
        # 합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다.
        b = arm_ledger.record_validation(self.BODY, self.K, 3)
        self.assertEqual(arm_ledger.next_attempt(b, self.K), 1)
```

- [ ] **Step 2: RED 확인**

Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_arm_ledger -v`
Expected: `AttributeError: module 'arm_ledger' has no attribute 'mark_inflight'`

- [ ] **Step 3: `arm_ledger.py` 를 확장한다**

`ATTEMPTS_RE` 아래에 두 정규식과 상수를 추가한다:

```python
INFLIGHT_RE = re.compile(r"^inflight_paths:\n((?:  [^\n]+\n)*)", re.MULTILINE)
VALIDATION_RE = re.compile(r"^validation_attempts:\n((?:  [^\n]+\n)*)", re.MULTILINE)

#: 구조 검증 실패의 세션당·문서당 재시도 상한. `DISPATCH_ATTEMPT_CAP` 과 **별도**여야
#: 한다 — 합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다 (설계 §4.4).
VALIDATION_ATTEMPT_CAP = 3

#: in-flight 표시의 만료. 리뷰 소요보다 넉넉히 길되 무한은 아니다 — 리뷰가 중간에
#: 죽으면 이 표시가 남아 게이트를 조용히 닫는데, 그 방향은 Law 1 이 금지하는
#: under-review 다. 만료 뒤 재-dispatch 는 `DISPATCH_ATTEMPT_CAP` 이 상한을 준다.
INFLIGHT_TTL_SEC = 900
```

`_compose` 를 네 블록으로 확장한다 (`rest` 계산에서 두 정규식을 함께 벗기고, `inflight_paths:`·`validation_attempts:` 를 정렬해 붙인다). `attempts` 와 같은 `rpartition(": ")` 파서를 `inflight` 와 `validation_attempts` 가 공유하게 한다 — 세 번째 파서를 만들지 않는다.

`is_inflight(body, raw_path, now, ttl_sec)` 는 `hook_common.parse_iso` 를 써서 만료를 판정하고, **판독 불가 타임스탬프는 만료로 읽는다**(dispatch 쪽 fail-open).

`mark_reviewed` 의 write 직전에 `body = clear_inflight(body, raw_path)` 를 넣는다.

CLI 에 `clear-inflight` 서브커맨드와 `_usage()` 한 줄을 추가한다.

- [ ] **Step 4: GREEN 확인**

Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_arm_ledger -v`
Expected: 전 케이스 PASS (기존 52 + 신규 8)

- [ ] **Step 5: mutation**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
M=plugins/spec-distill/scripts/arm_ledger.py
RUN='cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_arm_ledger'
cp "$M" /tmp/al.bak
python3 -c "import ast;ast.parse(open('$M').read())" && echo "ast ok"
eval "$RUN" >/dev/null 2>&1 && echo "control GREEN ok"
# 축1 삭제: mark_reviewed 의 clear_inflight 호출 제거
sed -i '' '/body = clear_inflight(body, raw_path)/d' "$M"
eval "$RUN" >/dev/null 2>&1 && echo "MUT1 GREEN — 무이빨" || echo "MUT1 RED ok"; cp /tmp/al.bak "$M"
# 축2 반전: 만료 판정 부등호 뒤집기
sed -i '' 's/VALIDATION_ATTEMPT_CAP = 3/VALIDATION_ATTEMPT_CAP = 99/' "$M"
eval "$RUN" >/dev/null 2>&1 && echo "MUT2 GREEN — 무이빨" || echo "MUT2 RED ok"; cp /tmp/al.bak "$M"
# 축3 형태변경: validation_attempts 를 dispatch attempts 와 같은 블록에 합친다
python3 - <<'PY'
p="plugins/spec-distill/scripts/arm_ledger.py"
s=open(p).read().replace('VALIDATION_RE = re.compile(r"^validation_attempts:',
                         'VALIDATION_RE = re.compile(r"^dispatch_attempts:')
open(p,"w").write(s)
PY
eval "$RUN" >/dev/null 2>&1 && echo "MUT3 GREEN — 무이빨" || echo "MUT3 RED ok"; cp /tmp/al.bak "$M"
# 축4 추가: 판독 불가 타임스탬프를 "만료 안 됨" 으로 읽게 한다 (fail-closed 재도입)
rm -f /tmp/al.bak; eval "$RUN" >/dev/null 2>&1 && echo "restored GREEN ok"
```

축4 는 `is_inflight` 의 `parse_iso` 실패 분기를 `return True` 로 바꿔 직접 확인한다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/arm_ledger.py plugins/spec-distill/tests/test_arm_ledger.py
git commit -m "feat(spec-distill): 원장에 in-flight 표시와 validation_attempts 추가

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 11: `resolve_mode` 를 `scripts/` 로 이동

**Files:**
- Create: `plugins/spec-distill/scripts/resolve_mode.py`
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py` (임시로 재-import — Task 13 에서 파일 자체가 사라진다)
- Modify: `plugins/spec-distill/tests/test_resolve_mode_scope.sh:10-11`

**Interfaces:**
- Consumes: 없음
- Produces: `resolve_mode(file_path: str) -> str | None` ("spec" | "design" | None), `PATH_PREFIX`

- [ ] **Step 1: 테스트의 로드 경로를 먼저 바꾼다 (RED 를 만든다)**

`plugins/spec-distill/tests/test_resolve_mode_scope.sh:10-11` 을 바꾼다:

```python
spec = importlib.util.spec_from_file_location(
    "v", "plugins/spec-distill/scripts/resolve_mode.py")
```

Run: `bash plugins/spec-distill/tests/test_resolve_mode_scope.sh`
Expected: FAIL — 파일 없음

- [ ] **Step 2: 모듈을 만든다**

`spec-write-validator.py:53-106` 의 `PATH_PREFIX`·`_frontmatter_has_locked_decisions`·`resolve_mode` 를 **한 글자도 바꾸지 않고** `plugins/spec-distill/scripts/resolve_mode.py` 로 옮긴다. 상단에 `from __future__ import annotations` 와 `import os`·`import re`·`from pathlib import Path`·`from typing import Optional` 만 남긴다.

`spec-write-validator.py` 는 그 세 정의를 지우고 `from resolve_mode import PATH_PREFIX, resolve_mode` 로 바꾼다 (`SCRIPTS_DIR` 은 이미 `sys.path` 에 있다).

- [ ] **Step 3: GREEN 확인**

```bash
bash plugins/spec-distill/tests/test_resolve_mode_scope.sh
bash plugins/spec-distill/tests/test_spec_write_validator.sh
bash plugins/spec-distill/tests/test_design_mode_validator.sh
```
Expected: 셋 다 PASS — **이동이 동작을 바꾸지 않았다는 증거다.** 하나라도 RED 면 옮기면서 무언가 바뀐 것이다.

- [ ] **Step 4: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "refactor(spec-distill): resolve_mode 를 scripts/ 로 이동 (동작 무변경)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 12: `Stop` 훅이 구조 검증을 흡수 (A4·A10·A11·A13·A15·A16)

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py`
- Create: `plugins/spec-distill/tests/test_stop_absorbs_validation.py`

**Interfaces:**
- Consumes: `discover_candidates.discover`·`GitUnavailable` (Task 9), `arm_ledger` in-flight·validation API (Task 10), `resolve_mode` (Task 11), `parse_spec_structure` 의 순수 함수 6개
- Produces: `validate_document(path: str) -> list[str]` (구조 실패 사유), `select_candidates(cands, body, now, cap, cursor) -> tuple[list, str]` (커서 회전 포함)

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

Create `plugins/spec-distill/tests/test_stop_absorbs_validation.py`:

```python
#!/usr/bin/env python3
"""Stop 훅 흡수 — A4(import) · A10(순서) · A11(block 단일) · A13(기아 없음) · A16(git 불능)."""
import ast
import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())
HOOK = REPO / "plugins" / "spec-distill" / "hooks" / "review-dispatch.py"
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
spec = importlib.util.spec_from_file_location("rd", HOOK)
rd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rd)


class TestNoParserSubprocess(unittest.TestCase):
    """A4 — 파서를 subprocess 로 부르지 않는다. 발견 모듈의 git 호출은 별도 파일이다."""

    def test_hook_has_no_subprocess_call(self):
        tree = ast.parse(HOOK.read_text(encoding="utf-8"))
        calls = [n for n in ast.walk(tree)
                 if isinstance(n, ast.Attribute) and n.attr in ("run", "Popen")
                 and isinstance(n.value, ast.Name) and n.value.id == "subprocess"]
        self.assertEqual(calls, [], "review-dispatch.py 에 subprocess 호출이 있다")

    def test_parser_is_imported(self):
        src = HOOK.read_text(encoding="utf-8")
        self.assertIn("parse_spec_structure", src)

    def test_positive_control_discovery_module_may_call_git(self):
        # 양성 대조 — 이 락은 발견 모듈의 git 호출을 금지하지 않는다 (GREEN 이 정답).
        dc = (REPO / "plugins/spec-distill/scripts/discover_candidates.py").read_text("utf-8")
        self.assertIn("subprocess.run", dc)


class TestOrdering(unittest.TestCase):
    """A10 — 구조 검증이 TTL 가드보다 **먼저** 돈다. AST 로 잰다."""

    def test_validation_precedes_ttl_guard(self):
        tree = ast.parse(HOOK.read_text(encoding="utf-8"))
        fn = next(n for n in tree.body
                  if isinstance(n, ast.FunctionDef) and n.name == "main")
        src_lines = {}
        for node in ast.walk(fn):
            if isinstance(node, ast.Name) and node.id == "validate_document":
                src_lines.setdefault("validate", node.lineno)
            if isinstance(node, ast.Name) and node.id == "LAST_DISPATCHED_RE":
                src_lines.setdefault("ttl", node.lineno)
        self.assertIn("validate", src_lines, "main() 이 validate_document 를 부르지 않는다")
        self.assertIn("ttl", src_lines, "main() 에 TTL 가드가 없다")
        self.assertLess(src_lines["validate"], src_lines["ttl"],
                        "TTL 가드가 구조 검증보다 앞이다 — dispatch 후 30초 동안 "
                        "Bash 로 쓴 깨진 문서의 검증이 통째로 건너뛰어진다")


class TestStarvationFree(unittest.TestCase):
    """A13 — dirty 문서가 상한보다 많아도 모든 문서가 결국 선택된다."""

    def test_cursor_rotation_reaches_every_candidate(self):
        keys = [f"docs/superpowers/specs/{c}-design.md" for c in "abcdefg"]
        seen, cursor = set(), None
        for _turn in range(10):
            picked, cursor = rd.select_keys(keys, cursor=cursor, cap=5)
            seen.update(picked)
            if seen == set(keys):
                break
        self.assertEqual(seen, set(keys),
                         "커서가 회전하지 않아 뒤쪽 문서가 굶는다")

    def test_cap_is_respected(self):
        keys = [f"docs/superpowers/specs/{c}-design.md" for c in "abcdefg"]
        picked, _ = rd.select_keys(keys, cursor=None, cap=5)
        self.assertEqual(len(picked), 5)


class TestGitUnavailable(unittest.TestCase):
    """A16 — git 불능은 후보 0 과 다르다."""

    def test_reason_string_names_git(self):
        self.assertIn("git", rd.GIT_UNAVAILABLE_ADVISORY.lower())
        self.assertIn("검증", rd.GIT_UNAVAILABLE_ADVISORY)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_stop_absorbs_validation -v`
Expected: 다수 FAIL — `select_keys`·`validate_document`·`GIT_UNAVAILABLE_ADVISORY` 부재, `subprocess` 호출 존재.

- [ ] **Step 3: `review-dispatch.py` 에 세 함수를 추가한다**

import 절에 추가:

```python
from parse_spec_structure import (  # noqa: E402
    find_missing_sections, load_blacklist, parse_frontmatter,
    scan_ambiguity, scan_placeholders, validate_locked_decisions,
)
from resolve_mode import resolve_mode  # noqa: E402
from discover_candidates import GitUnavailable, discover  # noqa: E402

BLACKLIST = SCRIPTS_DIR / "ambiguity-blacklist.txt"
CANDIDATE_CAP = 5
GIT_UNAVAILABLE_ADVISORY = (
    "[spec-distill] git 을 쓸 수 없어 스코프 문서 발견이 불가능하다 — 이 세션에서는 "
    "구조 검증도 자동 리뷰 dispatch 도 일어나지 않는다. 리포에서 세션을 열거나 "
    "reviewing-spec 을 직접 호출하라."
)
```

`validate_document` 를 추가한다. `call_parser` 의 subprocess 6회가 **파일 1회 읽기 + 순수 함수 호출**로 바뀐다 — 훅 timeout 10초 안에 중첩 timeout 을 만들던 구조가 사라진다:

```python
def validate_document(path: str) -> list[str]:
    """구조 실패 사유 목록. 빈 목록 = 통과. 파서를 subprocess 로 부르지 않는다 (A4)."""
    mode = resolve_mode(path)
    if mode is None:
        return []
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return [f"문서를 읽지 못했다: {exc}"]
    reasons: list[str] = []
    if mode == "spec":
        fm = parse_frontmatter(text)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        errs = validate_locked_decisions(text)
        if errs:
            reasons.append("locked_decisions errors: " + "; ".join(errs))
        missing = find_missing_sections(text)
        if missing:
            reasons.append(f"missing sections: {missing}")
    for hit in scan_ambiguity(text, load_blacklist(BLACKLIST)):
        reasons.append(f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\"")
    if mode == "design":
        for hit in scan_placeholders(text):
            reasons.append(f"placeholder hit: {hit['token']} at line {hit['line']}")
    return reasons
```

`select_keys` 로 기아를 없앤다 (A13). **정렬만으로는 부족하다** — 안정 정렬은 매 턴 같은 앞쪽 N개를 고른다:

```python
def select_keys(keys: list[str], cursor: str | None, cap: int) -> tuple[list[str], str | None]:
    """정렬된 후보에서 커서 뒤부터 최대 `cap` 개를 고르고 다음 커서를 낸다.

    커서가 없으면 처음부터. 커서가 목록에 없으면(문서가 커밋돼 후보에서 빠졌다)
    그보다 큰 첫 키부터 — 목록이 바뀌어도 회전이 끊기지 않는다. 끝에 닿으면 감는다.
    이것이 A13 의 진행 보장이다: 정렬이 안정적이라는 사실 자체가 기아의 원인이므로,
    안정 정렬 위에 회전을 얹는다.
    """
    ordered = sorted(keys)
    if not ordered:
        return [], None
    start = 0
    if cursor is not None:
        start = next((i for i, k in enumerate(ordered) if k > cursor), 0)
    picked = [ordered[(start + i) % len(ordered)] for i in range(min(cap, len(ordered)))]
    return picked, picked[-1]
```

- [ ] **Step 4: `main()` 을 다시 배선한다**

순서를 **이 순서 그대로** 둔다. 각 줄의 자리가 AC 다.

```
1. kill_switch_active("spec-distill", "review-dispatch", "Stop") → return 0        (A18)
2. fire_and_forget_gc()                                                            (§4.1 인계)
3. payload 읽기 → resolve_session_id → state_path
4. body = state 읽기. 부재는 "" (오늘의 `return 0` 을 없앤다 — pending 이 사라져
   상태 파일 없이도 발견이 돌아야 한다). 판독 실패는 기존 loud systemMessage 유지.
5. 은퇴 토큰 advisory (세션당 1회, 상태에 마커) — Task 13 이 채운다               (A19)
6. try: cands = discover()  except GitUnavailable: advisory 1회 + return 0         (A16)
7. 제외: armed_keys / is_inflight(TTL) / validation_attempts >= 상한
8. picked, cursor = select_keys([c.key for c in cands], cursor, CANDIDATE_CAP)     (A13)
9. 구조 검증 — picked 전부에 validate_document. 실패가 하나라도 있으면:
     record_validation 증가 → rewrite → decision:block(그 사유만) → return 0       (A10·A11)
   상한에 닿은 문서는 검증도 dispatch 도 하지 않고 advisory 만                     (A14)
10. TTL 가드 (여기서 처음 본다 — 9번 뒤여야 A10 이 성립한다)
11. dispatch 대상 1개 선택: not born ∧ not armed ∧ dispatch_attempts < 상한
12. mark_inflight + record_attempt + last_dispatched_at 을 **한 write** 로          (A12)
    rewrite 실패 → advisory 만, block 없음, 루프 없음                              (A15)
13. decision:block 으로 mandate emit (기존 msg_lines 로직 그대로)
```

`rewrite_state` 의 시그니처에 `cursor: str | None` 과 `inflight_key: str | None` 을 더하고, 기존 AC7.1 계약(`rewrite` 가 `print` 보다 **먼저**, fsync 포함)을 그대로 지킨다.

- [ ] **Step 5: GREEN 확인**

Run: `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_stop_absorbs_validation -v`
Expected: 전 케이스 PASS

- [ ] **Step 6: mutation — 순서 락과 기아 락이 실제로 문다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
M=plugins/spec-distill/hooks/review-dispatch.py
RUN='cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_stop_absorbs_validation'
cp "$M" /tmp/rd.bak
python3 -c "import ast;ast.parse(open('$M').read())" && echo "ast ok"
eval "$RUN" >/dev/null 2>&1 && echo "control GREEN ok"
```

그다음 손으로 네 변이를 넣고 각각 RED 인지 확인한다:

| 축 | 변이 | 어느 락이 잡아야 하나 |
|---|---|---|
| 삭제 | `select_keys` 의 회전(`% len(ordered)`)을 지우고 슬라이스로 | `TestStarvationFree` |
| 추가 | `validate_document` 안에 `subprocess.run` 한 줄 | `TestNoParserSubprocess` |
| 반전 | TTL 가드 블록을 구조 검증 앞으로 옮김 | `TestOrdering` |
| 형태변경 | `except GitUnavailable` 을 `except Exception` 으로 넓힘 | **잡히지 않는다** — 이 변이를 잡는 케이스를 추가한다 |

마지막 행이 요점이다. 넓힌 `except` 는 발견 모듈의 다른 버그를 "git 불능"으로 오보하고 게이트를 조용히 끈다. 그 변이를 RED 로 만드는 케이스를 쓰기 전까지 이 Task 는 끝나지 않는다.

- [ ] **Step 7: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "feat(spec-distill): Stop 훅이 발견·구조검증·dispatch 를 흡수

파서 subprocess 6회를 import 로 대체해 중첩 timeout 을 없애고, 발견은
git status 전체를 상계로 받아 canonical_key 로 좁힌다. 턴당 상한에는
커서 회전을 붙여 기아를 막는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 13: 훅 둘 삭제 + `pending_review:` 계약 은퇴 (A3·A19)

**Files:**
- Delete: `plugins/spec-distill/hooks/spec-write-validator.py`, `plugins/spec-distill/hooks/pending-review-reminder.py`
- Delete: `plugins/spec-distill/tests/{test_spec_write_validator.sh,test_design_mode_validator.sh,test_reminder_hook.sh,test_stale_state_truncate.sh}`
- Modify: `plugins/spec-distill/hooks/hooks.json`, `plugins/spec-distill/scripts/hook_common.py`, `plugins/spec-distill/scripts/arm_ledger.py`, `plugins/spec-distill/hooks/review-dispatch.py`
- Modify: `plugins/spec-distill/tests/{test_brief_review_meta.sh,arm_test_helpers.sh,test_hook_output_schema.py,test_arm_once.sh,test_arm_ledger.py,test_arm_ledger_timing.sh,test_review_dispatch.sh,test_review_dispatch_design_mandate.sh,test_reviewing_spec_design_routing.sh,test_reviewing_spec_state_keying.sh,test_brainstorming_entry.sh,test_stale_terms.sh}`

**Interfaces:**
- Consumes: Task 12 (Stop 훅이 이미 흡수함)
- Produces: `hooks/` 에 `hooks.json`·`review-dispatch.py`·`session-end-cleanup.py` 셋만 남은 상태

- [ ] **Step 1: 훅 집합 락을 먼저 갱신한다 (RED 를 만든다)**

`plugins/spec-distill/tests/test_brief_review_meta.sh:87` 을 바꾼다:

```bash
EXPECTED="hooks.json review-dispatch.py session-end-cleanup.py"
```

그리고 그 아래 `ok` 문구의 `(5개)` 를 `(3개)` 로.

Run: `bash plugins/spec-distill/tests/test_brief_review_meta.sh`
Expected: FAIL — `T18: hooks/ 집합 불일치`

- [ ] **Step 2: 은퇴 토큰 advisory 를 `review-dispatch.py` 에 넣는다 (A19)**

Task 12 Step 4 의 5번 자리를 채운다. **project-init 과 달리 여기는 필요하다** — 구조 검증이 이 훅으로 *옮겨왔으므로*, `spec-distill:validator` 로 검증을 껐던 사용자는 그것이 말없이 되살아난 것을 보게 된다.

```python
RETIRED_TOKENS = (
    "spec-distill:validator", "spec-distill:PostToolUse",
    "spec-distill:reminder", "spec-distill:UserPromptSubmit",
)
RETIRED_MARKER = "retired_token_advised: yes"


def retired_token_advisory(body: str) -> tuple[str, str | None]:
    """설정된 은퇴 토큰이 있으면 (새 body, advisory) — 세션당 1회.

    수명 사실만 적는다. "이제 안 걸린다" 같은 집행 공백은 적지 않는다 — 그것은
    모델이 스스로 리뷰를 면제할 근거가 되어 Law 2 를 뚫는다.
    """
    if RETIRED_MARKER in body:
        return body, None
    raw = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    hit = [t for t in RETIRED_TOKENS if t in raw]
    if not hit:
        return body, None
    return (
        body.rstrip() + f"\n{RETIRED_MARKER}\n",
        f"[spec-distill] DEVBREW_SKIP_HOOKS 에 은퇴한 토큰이 있다: {', '.join(hit)}. "
        "v0.34.0 에서 그 훅들이 삭제됐고 구조 검증은 Stop 훅으로 옮겨왔다 — "
        "이 토큰들은 더 이상 구조 검증을 끄지 않는다. 끄려면 "
        "DEVBREW_SKIP_HOOKS=spec-distill:Stop 을 쓴다.",
    )
```

- [ ] **Step 3: 두 훅과 그 전용 테스트를 지운다**

```bash
git rm plugins/spec-distill/hooks/spec-write-validator.py \
       plugins/spec-distill/hooks/pending-review-reminder.py \
       plugins/spec-distill/tests/test_spec_write_validator.sh \
       plugins/spec-distill/tests/test_design_mode_validator.sh \
       plugins/spec-distill/tests/test_reminder_hook.sh \
       plugins/spec-distill/tests/test_stale_state_truncate.sh
python3 - <<'PY'
import json
p = "plugins/spec-distill/hooks/hooks.json"
d = json.load(open(p, encoding="utf-8"))
for ev in ("UserPromptSubmit", "PostToolUse"):
    d["hooks"].pop(ev, None)
d["description"] = ("spec-distill — Stop hook (discovery + Layer 1 structural "
                    "validation + reviewer dispatch), SessionEnd cleanup.")
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
open(p, "a", encoding="utf-8").write("\n")
PY
```

- [ ] **Step 4: `pending_review:` 계약을 은퇴시킨다**

- `scripts/hook_common.py` — `PENDING_RE` 삭제. `LAST_DISPATCHED_RE`·`parse_iso`·`configure_utf8_streams`·`fire_and_forget_gc`·`state_file_for`·`_yaml_scalar` 는 유지 (다른 소비자가 있다).
- `scripts/arm_ledger.py` — `PENDING_RE`·`pending_path`·`strip_pending`·`strip_pending_file`·CLI `strip-pending` 삭제. `_compose` 의 `rest` 계산에서 pending 을 벗기던 부분은 원래 없었으므로 손대지 않는다.
- `hooks/review-dispatch.py` — `PENDING_RE` import 삭제, `rewrite_state` 의 `re.sub(r"^pending_review:...")` 삭제, veto 분기의 `strip_pending_file` 호출과 `tail` 문구 삭제.
- `scripts/state_path.py` — `strip-pending` 언급 삭제.

- [ ] **Step 5: TTL-GC 와 state-판독-실패 advisory 의 인계를 확인한다 (§4.1)**

삭제되는 `pending-review-reminder.py` 는 `PENDING_RE` 검사 **이전에** 두 가지를 했다:

| 무엇 | 인계 |
|---|---|
| `fire_and_forget_gc()` (:47) | `review-dispatch.py:93` 이 **이미 같은 자리에서** 부른다 — Stop 은 매 턴 돌므로 빈도도 같거나 높다 |
| state 판독 실패 시 `additionalContext` advisory (:63-81) | `review-dispatch.py:110-130` 이 같은 조건에서 `systemMessage` 로 낸다 — 채널이 다르나 사용자·모델 모두에게 도달한다 |

두 사실을 실제로 확인하고(코드를 읽는다), 확인 결과를 CHANGELOG Removed 항목에 한 줄로 적는다. **확인하지 않고 "인계됐다"고 쓰지 않는다.**

- [ ] **Step 6: 나머지 참조를 기계적으로 도출해 고친다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for term in spec-write-validator pending-review-reminder pending_review strip-pending strip_pending_file; do
  echo "=== $term"
  grep -rn -- "$term" plugins CLAUDE.md docs/philosophy 2>/dev/null \
    | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md'
done
```

- [ ] **Step 7: oracle 을 돌린다**

```bash
for term in spec-write-validator pending-review-reminder pending_review strip-pending strip_pending_file; do
  n=$(grep -rIl -- "$term" plugins CLAUDE.md docs/philosophy 2>/dev/null \
      | grep -v 'tests/fixtures/' | grep -v 'CHANGELOG.md' | wc -l | tr -d ' ')
  echo "$term: $n"
done
```

Expected: 다섯 줄 모두 `: 0`

- [ ] **Step 8: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "feat(spec-distill)!: PostToolUse validator 와 UserPromptSubmit reminder 삭제

pending_review: 계약을 은퇴시키고 in-flight 표시를 원장으로 옮긴다.
훅이 4개에서 2개로 줄고 신규 훅은 0개다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 14: skill·persona 재작성 + 리포 전수 A1 락

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (Step 1, pending strip 절, Step 3 mark-reviewed 절, Step C ④)
- Modify: `plugins/spec-distill/agents/spec-reviewer.md`
- Create: `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`

**Interfaces:**
- Consumes: Task 10 (`clear-inflight` CLI), Task 13 (은퇴한 계약)
- Produces: A1 이 리포 전수로 잠긴 상태. **이 락이 PR C 를 마지막에 머지하도록 강제한다.**

- [ ] **Step 1: 리포 전수 락을 쓴다**

Create `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`:

```bash
#!/usr/bin/env bash
# A1 — 리포의 **어떤** 플러그인도 쓰기 도구에 발화하는 PostToolUse 훅을 갖지 않는다.
# 대상은 하드코딩이 아니라 glob 으로 도출한다 — 네 번째 플러그인이 같은 결함을
# 들고 와도 RED 여야 한다.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }

python3 - <<'PY' || exit 1
import glob, json, sys
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
# 커밋된 프로브 픽스처는 matcher 없는 PostToolUse 항목을 **의도적으로** 갖고 있다
# (2026-08-22 헤드리스 실측용). 면제이며, 그 이유가 여기 적혀 있어야 면제다.
EXEMPT = {"shared/tests/fixtures/hookprobe/hooks/hooks.json"}
paths = sorted(set(glob.glob("plugins/*/hooks/hooks.json")
                   + glob.glob("shared/**/hooks/hooks.json", recursive=True)))
assert paths, "hooks.json 을 하나도 찾지 못했다 — glob 이 깨졌다 (계측기 고장)"
bad, scanned = [], 0
for p in paths:
    if p in EXEMPT:
        continue
    scanned += 1
    for e in json.load(open(p, encoding="utf-8"))["hooks"].get("PostToolUse", []):
        m = e.get("matcher")
        if not m:
            bad.append((p, "<matcher 부재 또는 빈 문자열>"))
        elif WRITE_TOOLS & {x.strip() for x in m.split("|")}:
            bad.append((p, m))
assert scanned >= 3, f"검사한 파일이 {scanned}개뿐이다 — 정의역이 좁아졌다"
for p, m in bad:
    print(f"BAD {p} matcher={m!r}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
ok "A1: 리포 전수 — 쓰기-도구 matcher 를 가진 PostToolUse 훅 0개"

# 양성 대조 1 — Bash matcher 는 살아 있다 (GREEN 이 정답, A2).
N_BASH=$(grep -l '"matcher": "Bash"' plugins/*/hooks/hooks.json 2>/dev/null | wc -l | tr -d ' ')
[[ "$N_BASH" -ge 2 ]] && ok "양성 대조: Bash matcher 훅 ${N_BASH}개 생존" \
                      || no "양성 대조 실패: Bash matcher 훅이 ${N_BASH}개뿐"

# 양성 대조 2 — 기록물에 남은 이름은 위반이 아니다 (GREEN 이 정답).
grep -rq 'spec-write-validator' plugins/spec-distill/CHANGELOG.md \
  && ok "양성 대조: CHANGELOG 의 은퇴 기록 생존" \
  || no "양성 대조 실패: CHANGELOG 에서 은퇴 기록이 사라졌다 (Law 3 substrate 파괴)"

# 양성 대조 3 — 건드리지 않은 플러그인은 bump 되지 않았다.
git diff --quiet origin/main -- plugins/agent-transparency plugins/plugin-audit \
  && ok "양성 대조: 무관한 두 플러그인 미변경" \
  || no "양성 대조 실패: 건드리지 않기로 한 플러그인이 바뀌었다"

exit $FAIL
```

- [ ] **Step 2: RED/GREEN 을 확인한다**

Run: `bash plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`

- PR A·B 가 이미 머지됐고 이 브랜치가 `main` 최신이면 → PASS
- 아직이면 → FAIL (`BAD plugins/quality-gates/…` 등). **그것이 정상이다** — 이 락이 머지 순서를 집행한다. `git merge origin/main` 으로 앞선 두 PR 을 받은 뒤 다시 돌린다.

- [ ] **Step 3: `reviewing-spec/SKILL.md` 를 재작성한다**

| 자리 | 무엇 |
|---|---|
| Step 1 | `$STATE` 에서 `pending_review:` 를 읽어 `spec_path`·`mode` 를 얻던 절을 삭제. 이 skill 은 이제 **인자로 받은 `spec_path`** 로 동작한다 (Stop 훅의 mandate 가 그 값을 싣는다). read==write 불변식 단락은 `armed_paths`·`inflight_paths`·`dispatch_attempts` 를 대상으로 다시 쓴다 |
| pending strip 블록 | 통째 삭제. 그 자리에 in-flight 계약 한 문단: *dispatch 시점에 Stop 훅이 원장에 in-flight 를 찍고, 이 skill 은 verdict 에서 `mark-reviewed` 로 해제한다. 진입 시 할 일은 없다* |
| Step 3 (mark-reviewed) | 그대로 유지. `mark_reviewed` 가 in-flight 도 함께 지운다는 사실을 한 줄 추가 |
| Step C ④ (멈춤) | `arm_ledger.py clear-inflight "$harness_sid" "$spec_path"` 호출을 추가. 호출하지 않으면 그 문서는 TTL(15분)까지 발견에서 빠진다 |
| Step A (spec_path 부재) | 같은 `clear-inflight` 호출 추가 |

- [ ] **Step 4: `agents/spec-reviewer.md` 에서 삭제된 경로 인용을 뺀다**

**persona 파일은 보안-민감 코드다** (CLAUDE.md). 이번 편집은 **삭제된 경로의 인용 제거로 한정**한다 — 규칙도 임계도 건드리지 않는다.

```bash
grep -n 'spec-write-validator\|pending_review' plugins/spec-distill/agents/spec-reviewer.md
git diff plugins/spec-distill/agents/spec-reviewer.md
```

diff 가 **인용 제거뿐**임을 눈으로 확인하고, PR 본문에 그 사실과 diff 를 명시한다.

- [ ] **Step 5: spec-distill 스위트를 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/hook-write-path-bypass
for t in plugins/spec-distill/tests/*.sh; do
  bash "$t" >/dev/null 2>&1 || echo "RED $(basename "$t")"
done
cd plugins/spec-distill/tests
for f in *.py; do m="${f%.py}"; PYTHONDONTWRITEBYTECODE=1 python3 -m unittest "$m" >/dev/null 2>&1 || echo "RED $m (py)"; done
```

Expected: Task 0 기준선의 RED 집합과 같거나 그보다 작다.

- [ ] **Step 6: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "feat(spec-distill): reviewing-spec 을 in-flight 계약으로 재작성 + 리포 전수 A1 락

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
```

## Task 15: 행동 케이스 · 비용 측정 · bump (A7·A8·A9·A20·A24·A26)

**Files:**
- Create: `plugins/spec-distill/tests/test_write_path_behavior.sh`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`, `CHANGELOG.md`, `README.md`
- Modify: `plugins/quality-gates/CHANGELOG.md` (§8 측정값 — PR B 에 이미 머지됐으면 후속 커밋)

**Interfaces:**
- Consumes: Task 9–14 전부
- Produces: PR C 의 머지 가능 상태

- [ ] **Step 1: 헤드리스 행동 케이스를 쓴다**

정적 검사로 확인할 수 없는 요구(A7·A8·A9·A20)는 실제 턴으로 잰다. 프로브 플러그인은 `shared/tests/fixtures/hookprobe/` 에 커밋돼 있다(commit `1a37123`).

Create `plugins/spec-distill/tests/test_write_path_behavior.sh`:

```bash
#!/usr/bin/env bash
# A7·A8·A9 — Bash 로 쓴 문서가 턴 끝에 검증·dispatch 되는가. 헤드리스 실측.
set -euo pipefail
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }

REPO="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
# macOS 의 /tmp 는 /private/tmp 심볼릭 링크다 — 정규화하지 않으면 경로 포함 검사가
# 조용히 무너져 무관한 RED 를 대량으로 낸다.
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q . && git config user.email t@t && git config user.name t
mkdir -p docs/superpowers/specs

run_turn() {  # $1 = prompt
  claude -p "$1" \
    --permission-mode acceptEdits \
    --plugin-dir "$REPO/plugins/spec-distill" \
    2>&1 || true
}

# A7 — Bash heredoc 으로 미커밋 스코프 문서를 쓴다 → 검증 + dispatch
OUT="$(run_turn 'Bash 로 heredoc 을 써서 docs/superpowers/specs/a-design.md 에 "# A\n\n내용\n" 을 만들어라. Write 도구를 쓰지 마라.')"
grep -q 'reviewing-spec' <<<"$OUT" \
  && ok "A7: Bash 로 쓴 미커밋 문서에 리뷰가 dispatch 됐다" \
  || no "A7: dispatch 되지 않았다 — 출력: $(head -c 400 <<<"$OUT")"

# A8 — 커밋된 문서를 Bash 로 고친다 → 검증은 되지만 arm 되지 않는다
git add -A && git commit -q -m c
OUT="$(run_turn 'Bash 의 sed 로 docs/superpowers/specs/a-design.md 의 "내용" 을 "내용2" 로 바꿔라.')"
grep -q 'reviewing-spec' <<<"$OUT" \
  && no "A8: 커밋된 문서에 리뷰가 붙었다 (arm-once 위반)" \
  || ok "A8: 커밋된 문서는 arm 되지 않았다"

# A9 — 읽기만 한 턴에는 아무 일도 없다 (양성 대조 — 조용함이 정답)
OUT="$(run_turn 'docs/superpowers/specs/a-design.md 를 읽고 첫 줄을 말해라.')"
grep -q 'reviewing-spec' <<<"$OUT" \
  && no "A9: 읽기만 했는데 dispatch 됐다" \
  || ok "A9: 읽기 턴은 조용하다"

exit $FAIL
```

- [ ] **Step 2: 돌린다**

Run: `bash plugins/spec-distill/tests/test_write_path_behavior.sh`
Expected: 3/3 ✓

> `--permission-mode acceptEdits` 없이는 편집이 rc 0 으로 **조용히** 죽는다 — 그러면 이 테스트는 아무것도 재지 않으면서 초록으로 보인다. 이 플래그가 빠졌는지 먼저 의심한다.

- [ ] **Step 3: A13(기아 없음)을 여러 턴으로 잰다**

Step 1 의 하네스에 dirty 문서 7개를 만들고 턴을 3회 돌려, 세 턴에 걸쳐 **7개 전부**가 최소 1회 검증되는지 확인한다. 한 턴만 재면 커서가 회전하지 않는 구현도 통과한다.

- [ ] **Step 4: 비용을 측정한다 (A26)**

기준선(`main`)과 비교군(이 브랜치)을 **같은 시나리오**로 잰다: 도구 호출 30회 — Read 20 · Bash 5 · Write 3 · Grep 2. 플러그인별 훅 시간 합과 턴 벽시계를 **둘 다** 기록한다(병렬·직렬 여부가 그 차이로 드러난다).

- 측정 래퍼를 배포본에 넣지 않는다 — `/usr/bin/time -p` 는 stderr 에 쓰는데 spec-distill 의 집행 채널이 stderr 라 차단 사유를 오염시킨다.
- 도구가 없으면 **측정을 실패로 보고**하고 추정치를 만들지 않는다.
- **머지 게이트로 쓰지 않는다.** 예상 마진(≈200 ms)이 17.4 ms 인터프리터 바닥의 여러 배라 자동 부등식은 잡음만 잰다. 비교군이 기준선보다 크면 비-차단 advisory 를 내고 CHANGELOG 에 적는다 — 위 유도가 틀렸다는 신호이므로 사람이 본다.

결과를 세 CHANGELOG 의 Performance 절에 옮겨 적는다.

- [ ] **Step 5: 버전과 CHANGELOG**

`plugins/spec-distill/.claude-plugin/plugin.json` 을 `0.33.0` → `0.34.0`.

```markdown
## [0.34.0] — 2026-08-23

### Removed
- **`hooks/spec-write-validator.py` (PostToolUse, `matcher: "Write|Edit|MultiEdit"`)** — 쓰기-도구 matcher 는 Bash heredoc·`sed -i` 로 쓴 파일을 보지 못한다. 이 리포에서 실제로 발생했다: 세션 지시가 Bash 쓰기를 요구했고 `docs/superpowers/specs/` 문서 3개가 Law 1 게이트를 한 번도 통과하지 않은 채 커밋됐다. kill switch 는 켜지지 않았다 — 게이트는 꺼졌다고 **말하지 않고** 꺼졌다.
- **`hooks/pending-review-reminder.py` (UserPromptSubmit)** — `pending_review:` 만 소비했다. 그 계약이 은퇴하면서 함께 사라진다. 그 훅이 `PENDING_RE` 검사 **이전에** 돌던 두 가지는 인계를 확인했다: `fire_and_forget_gc()` 는 `review-dispatch.py` 가 같은 자리에서 이미 부르고(Stop 은 매 턴 돌아 빈도가 같거나 높다), state 판독 실패 advisory 는 같은 훅이 같은 조건에서 `systemMessage` 로 낸다.
- `pending_review:` 상태 블록 · `arm_ledger.strip_pending`·`strip_pending_file` · CLI `strip-pending` · `hook_common.PENDING_RE`
- `tests/{test_spec_write_validator.sh,test_design_mode_validator.sh,test_reminder_hook.sh,test_stale_state_truncate.sh}`

### Added
- **`scripts/discover_candidates.py`** — 스코프 문서 발견. `git status` 에 **pathspec 을 주지 않고** dirty 집합 전체를 상계로 받은 뒤 `arm_ledger.canonical_key` 로 좁힌다. wildmatch 를 방정식에서 빼므로, 판본 4·5 가 연속으로 낸 pathspec 결함이 재발할 수 없다.
- 원장 블록 `inflight_paths:` (TTL 900초) 와 `validation_attempts:` (상한 3, `dispatch_attempts` 와 **별도**). CLI `clear-inflight`.
- `scripts/resolve_mode.py` — 삭제되는 훅에서 동작 무변경으로 옮겨왔다.

### Changed
- **`Stop` 훅(`review-dispatch.py`)이 발견·Layer 1 구조 검증·리뷰 dispatch 를 모두 수행한다.** 구조 검증은 파서를 `subprocess` 로 부르지 않고 import 한다 — 훅 timeout 이 10초인데 `call_parser` 가 호출마다 `timeout=10` 을 걸어 중첩 timeout 을 만들던 구조가 사라진다. 순서는 구조 검증 → TTL 가드 → dispatch 로 고정되며, 구조 실패가 있으면 그 사유만 block 으로 나가고 dispatch 는 그 턴에 없다.
- 턴당 검증 문서 상한 5. 정렬은 안정적이므로 그 위에 **커서 회전**을 얹어 기아를 막는다.
- 훅이 4개에서 2개(`Stop`·`SessionEnd`)로 줄었다. **신규 훅 0개.**

### Deprecated
- kill switch 토큰 `DEVBREW_SKIP_HOOKS=spec-distill:validator` · `spec-distill:PostToolUse` · `spec-distill:reminder` · `spec-distill:UserPromptSubmit` 은 가리킬 대상을 잃었다. **구조 검증이 `Stop` 훅으로 옮겨왔으므로 이 토큰들로 껐던 사용자는 검증이 말없이 되살아난 것을 보게 된다** — `review-dispatch.py` 가 세션당 1회 그 사실을 알린다. 대체: `DEVBREW_SKIP_HOOKS=spec-distill:Stop`.
- 잃는 조합 하나 — "리뷰는 끄고 구조 검증은 유지". 지정 대체재는 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (arm 을 끄고 Layer 1 은 남긴다).

### Known limitations
- 발견은 훅의 cwd 리포만 본다. 다른 체크아웃의 문서는 `git status` 에 나오지 않는다 — 그 워크트리에서 세션을 열면 커버된다 (설계 §13 R5).
- git 이 없거나 리포가 아니면 검증·dispatch 가 일어나지 않고 세션당 1회 loud advisory 가 나간다 (설계 §4.5).

### Performance
- 기준선/비교군 측정: <Step 4 결과>
```

- [ ] **Step 6: README 갱신**

"Hooks Installed" 표에서 두 행 삭제 + `Stop` 행 재작성, 디렉토리 트리, kill switch 절, `:44` 다이어그램, `:70` 의 `locked_decisions` 설명(이제 `scripts/resolve_mode.py` 가 분류한다), §13 R5 의 한계를 한 줄.

- [ ] **Step 7: 커밋 + PR**

```bash
git add -A plugins/spec-distill
git commit -m "chore(spec-distill): 0.34.0 — Stop 훅 흡수

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ToiaCL1Fb88FVZnDFZTfyw"
git push -u origin fix/spec-distill-stop-absorbs-validator
```

PR 본문에 반드시 적을 것:

- **머지 순서**: PR A·B 가 먼저다. 이 PR 의 리포 전수 A1 락이 그것을 집행한다.
- **persona 편집** (`agents/spec-reviewer.md`): 삭제된 경로의 인용 제거로 한정했고 규칙·임계는 건드리지 않았다는 사실 + diff.
- **codex co-review 부재**: 설계 리뷰 5라운드 전부 Claude 단독이었다(사용 한도 2026-09-17 소진, 실제 호출 2회로 확인). 이 설계에서 검사되지 않은 것이 무엇인지 아무도 모른다.

---

## Self-Review (이 plan 을 쓴 뒤 설계와 대조한 결과)

**1. Spec coverage** — 설계 §9 의 A1–A26 대응:

| AC | Task | AC | Task |
|---|---|---|---|
| A1 | 1·4·14 | A14 | 10·12 |
| A2 | 1·4·14 (양성 대조) | A15 | 12 |
| A3 | 2·7·13 (oracle) | A16 | 9·12 |
| A4 | 12 | A17 | 9 |
| A5 | 9 | A18 | 12 |
| A6 | 9 | A19 | 13 · §0 ③ |
| A7 | 15 | A20 | 6·15 |
| A8 | 15 | A21 | 5 (§0 ② 로 재해석) |
| A9 | 15 | A22 | 6 |
| A10 | 12 | A23 | 2 |
| A11 | 12 | A24 | 3·8·15 |
| A12 | 10·12·14 | A25 | 3·8·15 |
| A13 | 12·15 | A26 | 15 |

**2. Placeholder scan** — `<Task 15 Step 4 의 측정 결과를 여기에 옮겨 적는다>` 와 `<Step 4 결과>` 두 자리가 CHANGELOG 안에 있다. 이것은 plan 의 미완이 아니라 **실행 시점에만 존재하는 값**의 자리이며, Task 15 Step 4 가 그것을 채우는 단계다. 그 밖의 TBD/TODO 는 없다.

**3. Type consistency** — Task 9 가 내는 이름(`discover`·`GitUnavailable`·`Candidate`·`parse_status_z`·`born_from_status`·`candidates_from_records`)을 Task 12 가 그대로 소비한다. Task 10 이 내는 이름(`mark_inflight`·`clear_inflight`·`is_inflight`·`inflight`·`validation_attempts`·`next_validation`·`record_validation`·`VALIDATION_ATTEMPT_CAP`·`INFLIGHT_TTL_SEC`)을 Task 12·13·14 가 소비한다. Task 11 의 `resolve_mode`·`PATH_PREFIX` 를 Task 12 가 소비한다.

**4. 이 plan 이 답하지 않는 것** — 설계 §14 의 ④(codex 재검토)와 ⑤(`/cancel-review`). 둘 다 이 작업의 범위 밖이며 §0 이 그 사실을 적었다.
