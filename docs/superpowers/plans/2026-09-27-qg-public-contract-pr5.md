# qg 공개 계약 · 헌장 · 인용 락 구현 계획 (PR5)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans` 로 이 계획을 Task 단위로 실행한다. 단계는 체크박스(`- [ ]`) 표기다.

**Goal:** qg 가 더는 하지 않는 일(두 게이트 · 런타임 검증 executor)을 공개 계약과 헌장에서 거두고, 헌장이 이름으로 박는 것이 실재하는지를 락으로 잠그며, PR4d 가 넘긴 토픽 문면 정정과 §13 수동 e2e 를 마친다.

**Architecture:** 새 락 둘을 먼저 세운다.
- `shared/tests/test_charter_citations.sh` 는 헌장(`CLAUDE.md` + `docs/philosophy/*.md`)에서 이름을 두 갈래로 도출한다(§6.5.4). 첫째는 모양으로 인식되는 인용이 실재하는지, 둘째는 git 이력에서 사라진 이름이 헌장에 없는지다. AC20 의 공개 계약 문자열도 같은 락이 잰다.
- `plugins/quality-gates/tests/test_gate_era_prose_absent.sh` 는 qg 산문 전체에서 옛 게이트 시대 문구가 없는지를 잰다.

두 락을 세운 뒤 그 락을 RED 로 만드는 문면을 고친다. 토픽 문면은 기존 락(`test_topic_scope_wiring.sh` · `test_topic_head.sh`)을 먼저 바꾸고 문면을 고친다. e2e 는 컨트롤러가 `~/Downloads` 밖 scratch 리포에서 헤드리스 `claude -p` 로 돌린다.

**Tech Stack:** bash 3.2 호환(락) · Python 3.9+ 시스템 `python3`(표준 라이브러리, 3.10+ 문법 금지) · `shared/tests/assert.sh` · git 2.54 · `claude -p`(e2e)

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md`
- §6.5.3 공개 계약과 헌장
- §6.5.4 헌장 조항의 고아화 방지 — 두 갈래 도출 · 헌장 코퍼스
- §11 AC19 · AC20 · AC23
- §13 수동 e2e
- §15-12
- §16 5행과 「범위 기록 (2026-09-27)」

설계 편집은 이 브랜치의 첫 커밋(348c9852)으로 이미 들어가 있다. 이 계획은 설계 문서를 고치지 않는다.

---

## Global Constraints

- **헌장 코퍼스 = `CLAUDE.md` + `docs/philosophy/*.md`**(§6.5.4).
  - 갈래 1(모양 인식 인용의 실재): 백틱 토큰 · 마크다운 링크 대상 중 `/` 를 품은 경로와, 이 리포 `plugins/` 의 플러그인을 가리키는 `<플러그인>:<이름>` 을 본다.
    - 건너뛰는 모양은 다섯이다: 템플릿(`<…>`) · 글롭(`*`) · `/` 없는 맨 파일명 · 리포 밖 플러그인과 자리표시 · 경로 아닌 모양(URL · 절대경로 · `#` 앵커 · 공백 포함).
    - 건너뛴 모양은 조용히 재해석하지 않고, 건너뛴 수를 공시한다.
  - 갈래 2(이력에서 사라진 이름의 부재): `HEAD` 이력에서 agent · 스크립트 · 플러그인으로 존재했으나 지금 어떤 추적 파일 이름으로도 없는 이름을 대상으로 한다.
    - `-` · `_` · `.` 를 품은 식별자 모양만 본다. 한 단어 이름은 건너뛰고 수를 공시한다.
    - 대소문자를 구분하고, 앞뒤가 식별자 글자가 아닌 자리만 잰다.
  - git 이력이나 트리를 못 읽으면 실패다.
- **AC20** — `marketplace.json` · qg `plugin.json` · `CLAUDE.md` 셋 어디에도 `runtime-verifier` 나 「2-gate」가 남지 않는다.
- **AC23 은 PR4b 가 닫았다** — `plugins/quality-gates/tests/test_verdict_vocabulary.sh` 가 GREEN 인지만 확인한다.
- **판정 어휘는 `scripts/verdict.py` 밖에 두지 않는다.** 이 PR 은 사유 · status 열거를 늘리지 않는다.
- **비신뢰 입력에 거는 정규식은 `fullmatch`.**
- **락은 same-line · 부정형 거부 · 목적지 양의 단언으로 쓴다. 부재 락에는 양의 짝을 둔다.**
- **persona 파일 편집은 보안 리뷰 대상이다**(CLAUDE.md). 이 PR 의 `security-reviewer.md` · `pr-understanding-builder.md` 편집은 **역할 라벨 문구만** 바꾼다. 규칙 · 임계 · 도구는 한 글자도 바꾸지 않는다.
- **범위 불변식** — 아래는 한 바이트도 바뀌지 않는다.
  - `plugins/spec-distill/**` · `plugins/plugin-audit/**` · `plugins/project-init/**`
  - `shared/**` 에서 새 파일 `shared/tests/test_charter_citations.sh` 를 뺀 나머지
  - `docs/superpowers/specs/**`(첫 커밋 밖) · `plugins/quality-gates/skills/quality-pipeline/references/**`
  - `plugins/quality-gates/scripts/**` 에서 `qg-worktree.sh` 를 뺀 나머지
  - `plugins/quality-gates/agents/**` 에서 `security-reviewer.md` · `pr-understanding-builder.md` 를 뺀 나머지
  - `tools/**`
  - Task 6 이 대조한다.
- **커밋 본문에서 `Spec: ` 로 시작하는 줄은 트레일러 단락의 한 줄뿐이다.**
- **커밋 트레일러** — 마지막 `-m` 단락 **하나**에 두 줄을 둔다: `Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr5` 와 `Co-Authored-By: <그 커밋을 쓴 실제 모델>`.
- **버전은 브랜치에서 정하지 않는다** — 머지 직전 `origin/main` 을 다시 보고 qg minor 를 올린다(오늘 관측 9.2.0 → 9.3.0).
- **최신화는 merge, rebase 금지.** 세션이 치는 명령에서 다음은 금지다: 메인 체크아웃으로 `cd` · `git -C` · bare `git stash`.
- **명령은 워크트리 루트에서 돈다.** 격리 가드가 복합 명령을 거부하면 `$CLAUDE_JOB_DIR/tmp/` 아래 스크립트 파일로 돌린다. 계획 문면의 `$CLAUDE_JOB_DIR` 는 호출 전에 절대 경로 리터럴로 푼다.
- **`PYTHONDONTWRITEBYTECODE=1`.** 파이썬 편집마다 `python3 -m py_compile`, 셸 편집마다 `bash -n` 을 돌린다.
- **새 `*.sh` 락은 git 모드 100755.**
- **회귀 판정의 정본은 `~/Downloads` 밖 clone 비교다**(PR4d 판정 R8).
  - 이 세션은 `~/Downloads` 아래 `access()` 가 거부될 수 있어, 워크트리 스위트가 `[ -r ]` 가드 락에서 거짓 RED 를 낸다.
  - 워크트리 실행 결과는 참고로만 쓴다. 기준선과 최종은 같은 조건의 clone 두 개로 잰다.
- **git-ignored 산출물은 매 갱신마다 `~/.claude/sdd-mirror/qg-public-contract-pr5/` 로 복사한다.** 대상은 기준선 TSV · 변이 표 · e2e 산출 · SDD 원장이다.
- **계획 문면의 펜스 블록은 글자 그대로 옮긴다** — 옮기기 전에 목적지 파서로 검증한다. 인용한 옛 문구가 한 줄 grep 에 안 걸리면 앞 서너 단어로 찾아 문장 전체를 고친다. 뜻까지 다르면 멈추고 보고한다.
- **변이는 `~/Downloads` 밖 clone 에서.** 헌장 락은 git 이력을 읽으므로 `git archive` 사본이 아니라 `git clone` 이어야 한다.

## Review Focus

스펙이 함의하지만 기본 테스트가 태우지 않는 입력 가운데, 쓰는 사람을 가장 먼저 물 다섯이다. 각 줄의 증거는 소유 Task 에 있다. 락 자신의 입력 행동은 Task 4 의 변이 행이 잰다.

1. **앞으로 agent · 스크립트를 지우면서 헌장의 산문 속 언급을 잊음** — 락이 그 이름과 자리를 대며 RED 여야 한다. → Task 4 Row 1 · 2(`runtime-verifier` 를 헌장 산문에 되살림)
2. **헌장에 새 경로 인용을 오타로 적음** — 그 경로를 이름 붙인 RED. → Task 4 Row 3 · 4
3. **git 이 없는 사본(tarball · 얕은 클론)에서 락을 돌림** — 조용한 GREEN 이 아니라 RED 여야 한다. → Task 4 Row 5 · 6
4. **`marketplace.json` 과 `plugin.json` 의 설명이 서로 어긋남** — RED. → Task 4 Row 8
5. **전부 머지된 키를 `create-head --topic` 으로 재도출** — die 메시지가 `resolve` 의 사유를 싣는다. → Task 3 `case_create_head_topic_names_resolve_reason`

---

## 이 PR 이 지는 것

| 항목 | 내용 | 집행 자리 |
|---|---|---|
| **AC19** | 헌장이 이름으로 박는 것이 실재하고, 이력에서 사라진 이름이 헌장에 없다 | Task 1 `test_charter_citations.sh` |
| **AC20** | 공개 계약 · 헌장에 `runtime-verifier` · 「2-gate」 없음 | Task 1(같은 락) |
| **§6.5.3** | `marketplace.json` · `plugin.json` 설명 · `CLAUDE.md` Law 2 예외 제거 · 철학 문서의 같은 산문 | Task 1 |
| **§16 범위 기록 — qg 안 옛 게이트 문구** | `security-reviewer` · `pr-understanding-builder` · 두 SKILL | Task 2 |
| **§16 범위 기록 — PR4d 넘김** | 공지 「판정 대상에서 빠졌다」 · README 세 곳 · `create-head --topic` die 사유 | Task 3 |
| **§13 수동 e2e** | scratch 리포 · 헤드리스 `/quality-gates:qg` | Task 5(컨트롤러) |
| **AC23 확인** | `test_verdict_vocabulary.sh` GREEN | Task 6 |

## 끝에서 끝 흐름

| # | 자리 | 입력 | 산출 | 소비자 | 소유 Task |
|---|---|---|---|---|---|
| 1 | `test_charter_citations.sh` | 헌장 · git 트리 · git 이력 · 두 JSON | ✓/✗ 줄 · 건너뛴 모양 공시 | 스위트 · `test_guards_coverage_bidirectional.sh`(`--emit-scanned`) | 1 |
| 2 | `CLAUDE.md` Law 2 | — | 예외 없는 원칙 | 모든 세션(프로젝트 지시) | 1 |
| 3 | `plugin.json` · `marketplace.json` 설명 | — | 「one pipeline, one verdict (review + mandatory differential test)」 | 마켓플레이스 · 설치 UI · plugin-audit `check_staleness` | 1 |
| 4 | `test_gate_era_prose_absent.sh` | qg 산문 코퍼스 | ✓/✗ | 스위트 · guards 락 | 2 |
| 5 | SKILL ① 1a 공지 | 스코프 파일 `in_base:` | 「판정 대상에서 빠졌다 — 자기 PR 에서 판정됐다」 | 사용자 | 3 |
| 6 | `qg-worktree.sh create-head --topic` | `topic-head.sh` 출력 | 죽을 때 `status` 와 `reason` | 레퍼런스 R-init → 사용자 | 3 |
| 7 | e2e | scratch 리포 · 브랜치 코드 | 관측표 · 산출 발췌 | PR 본문 · 사용자 | 5 |

---

## 파일 구조

**신설**

| 경로 | 무엇이 |
|---|---|
| `shared/tests/test_charter_citations.sh` | AC19 · AC20 락(셸 껍데기 + python 코어 heredoc) |
| `plugins/quality-gates/tests/test_gate_era_prose_absent.sh` | 옛 게이트 문구 부재 + 새 문구 양의 짝 |

**수정**

| 경로 | 무엇이 |
|---|---|
| `CLAUDE.md` | Law 2 의 *Scoped exception (qg v2.2.0)* 문장 삭제 |
| `docs/philosophy/devbrew-harness-philosophy.md` | 같은 예외 한 줄(`*R6 scoped exception (qg v2.2.0):* …`) 삭제 |
| `.claude-plugin/marketplace.json` · `plugins/quality-gates/.claude-plugin/plugin.json` | qg `description`(두 파일 같은 문자열) · `plugin.json` `version`(Task 6) |
| `plugins/quality-gates/agents/security-reviewer.md` · `agents/pr-understanding-builder.md` | 「Review gate」 라벨 |
| `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` · `skills/publishing-pr-understanding/SKILL.md` | 「two-gate」 · 「Review gate」 라벨(+ publishing 제목 버전, Task 6) |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | ① 1a `in_base` 공지 한 줄(+ 제목 버전, Task 6) |
| `plugins/quality-gates/README.md` | 토픽 스코프 절 한 문장 · 알려진 한계 두 항목 |
| `plugins/quality-gates/scripts/qg-worktree.sh` | `create-head --topic` die 메시지에 `reason` |
| `plugins/quality-gates/tests/test_topic_scope_wiring.sh` · `tests/test_topic_head.sh` | 공지 락 문구 · 새 케이스 하나 |
| `plugins/quality-gates/CHANGELOG.md` | 새 절(Task 6) |

---

## 착수 — 컨트롤러가 Task 1 전에 한다

- [ ] **Step A: 브랜치 · base 확인**

```bash
git branch --show-current
git fetch origin --quiet
git merge-base --is-ancestor origin/main HEAD && echo "OK origin/main ⊆ HEAD"
git rev-list --count HEAD..origin/main
git log --oneline origin/main..HEAD
```

  **기대** —
  - 브랜치는 `feature/qg-public-contract-pr5`.
  - `OK …` 와 `0`.
  - `origin/main..HEAD` 에 두 커밋: 설계 커밋(`docs(spec): qg PR5 범위 · 인용 락 도출 규칙 · squash 한계 정정`)과 계획 커밋.

  계획 파일이 untracked 면 먼저 커밋한다(본문에 `Spec: ` 로 시작하는 줄 없이, 트레일러 `#pr5`).

- [ ] **Step B: 기준선 — `~/Downloads` 밖 clone 에서**

  `$CLAUDE_JOB_DIR/tmp/pr5-clone-suite.sh` 를 아래 내용으로 쓰고 돌린다. `<rev>` 는 착수 시 `git rev-parse HEAD` 값이다.

```bash
#!/usr/bin/env bash
# pr5-clone-suite.sh <name> <rev> — ~/Downloads 밖 clone 에서 run-suite · unittest · 하네스 실패 이름
set -u
T=/Users/jeonghokim/.claude/jobs/b6faa344/tmp
SRC=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-recritic-swap-pr4a
D="$T/pr5-v-$1"
rm -rf "$D"
git clone -q --no-hardlinks "$SRC" "$D" || exit 1
cd "$D" || exit 1
git checkout -q "$2" || exit 1
git update-ref refs/remotes/origin/main "$(cd "$SRC" && git rev-parse origin/main)"
git config user.email v@example.invalid; git config user.name v
echo "rev $(git rev-parse --short HEAD) access: $([ -r CLAUDE.md ] && echo yes || echo no)"
bash "$T/run-suite.sh" "$T/pr5-v-$1.tsv"
echo "--- unittest"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/quality-gates/tests -p "test_*.py" 2>&1 | tail -3
echo "--- harness"
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh 2>&1 | grep '^FAIL:' | sed -E 's/ \(.*\)$//' | sort -u > "$T/pr5-v-$1-harness-fails.txt"
cat "$T/pr5-v-$1-harness-fails.txt"
```

```bash
mkdir -p ~/.claude/sdd-mirror/qg-public-contract-pr5
cp ~/.claude/sdd-mirror/qg-topic-scope-pr4c/run-suite.sh "$CLAUDE_JOB_DIR/tmp/run-suite.sh"
bash "$CLAUDE_JOB_DIR/tmp/pr5-clone-suite.sh" base <rev> > "$CLAUDE_JOB_DIR/tmp/pr5-v-base.out" 2>&1
cp "$CLAUDE_JOB_DIR"/tmp/pr5-v-base* "$CLAUDE_JOB_DIR/tmp/run-suite.sh" "$CLAUDE_JOB_DIR/tmp/pr5-clone-suite.sh" ~/.claude/sdd-mirror/qg-public-contract-pr5/
```

  **기대**(PR4d 최종 clone 과 같다):
  - 첫 줄 `access: yes`.
  - 217 파일. 0 이 아닌 파일은 넷이다: qg `test_codex_backward_compat.sh`(1) · qg `test_runner_adapters.sh`(1) · qg `harness/test_skill_orchestration_behavior.sh`(2) · spec-distill `test_no_write_matcher_hooks_repo.sh`(1).
  - unittest `Ran 197` OK.
  - 하네스 실패 이름 2개: `R1b→R8 unclaimed 집행 사슬` · `iter cap near Review gate AskUserQuestion`.

  다르면 멈추지 않는다. 그 차이를 원장에 적고, 모든 Task 의 RED diff 기준으로 쓴다.

- [ ] **Step C: 전제 확증** — 아래가 전부 한 건 이상 나와야 한다. 하나라도 0 이면 BLOCKED. 고정 문자열이라 `-F` 다(Bash 도구 셸의 `grep` 은 ugrep 함수라 `$`·`{` 가 든 패턴을 다르게 읽는다 — 모의 실행 실측).

```bash
grep -cF 'Scoped exception (qg v2.2.0)' CLAUDE.md
grep -cF 'R6 scoped exception (qg v2.2.0)' docs/philosophy/devbrew-harness-philosophy.md
grep -cF '2-gate quality verification pipeline' .claude-plugin/marketplace.json
grep -cF '2-gate quality verification pipeline' plugins/quality-gates/.claude-plugin/plugin.json
grep -cF 'Phase 1 of the Review gate' plugins/quality-gates/agents/security-reviewer.md
grep -cF '기준선에 포함됐다 — 이번 판정 대상이 아니다' plugins/quality-gates/skills/quality-pipeline/SKILL.md
grep -cF 'topic HEAD axis is not derivable now (status: ${ch_status:-?})' plugins/quality-gates/scripts/qg-worktree.sh
grep -cF 'case_legacy_table_is_gone' plugins/quality-gates/tests/test_verdict_vocabulary.sh
```

---

### Task 1: 헌장 인용 락 · 공개 계약 · Law 2 예외 제거

**Files:**
- Create: `shared/tests/test_charter_citations.sh`
- Modify: `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` · `.claude-plugin/marketplace.json` · `plugins/quality-gates/.claude-plugin/plugin.json`(`description` 만)

**Interfaces:**
- Produces:
  - `bash shared/tests/test_charter_citations.sh` → `assert.sh` 형식 출력과 `finish` 종료 코드(모든 단언 통과면 0).
  - `--emit-scanned` 는 네 코퍼스 경로를 낸다: `CLAUDE.md` · `.claude-plugin/marketplace.json` · `plugins/quality-gates/.claude-plugin/plugin.json` · 추적되는 `docs/philosophy/*.md`.
  - qg 설명 문자열(두 JSON 같은 값): `Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish surface (not a gate). Invoke manually via /qg or /qg-publish.`

- [ ] **Step 1: 실패하는 락을 쓴다** — `shared/tests/test_charter_citations.sh` 를 아래 내용 그대로 만들고 `chmod +x`.

```bash
#!/usr/bin/env bash
# guards: CLAUDE.md docs/philosophy/*.md .claude-plugin/marketplace.json plugins/quality-gates/.claude-plugin/plugin.json
# test_charter_citations.sh — 헌장 인용 락 (설계 §6.5.4 · AC19 · AC20).
#
# 헌장(CLAUDE.md + docs/philosophy/*.md)이 이름으로 박는 것은 실재해야 한다. 조항이 가리키던 대상이
# 사라져도 조항 자체에 락이 없으면 제거가 GREEN 으로 통과하고 조항이 대상 없이 남는다(§6.5.4).
# 이름은 두 갈래로 도출한다 — 모양 하나로는 진짜 인용과 예시 이름(명명 규칙 · 금지 예시)을 못 가른다.
#  1. 모양으로 인식되는 인용은 실재한다 — 백틱 토큰 · 마크다운 링크 대상 중 `/` 를 품은 경로,
#     이 리포 plugins/ 의 플러그인을 가리키는 `<플러그인>:<이름>`. 템플릿 · 글롭 · 맨 파일명 ·
#     리포 밖 플러그인 · 경로 아닌 모양은 건너뛰고 수를 공시한다(조용히 재해석하지 않는다).
#  2. 이력에서 사라진 이름은 헌장에 없다 — HEAD 이력에서 agent · 스크립트 · 플러그인으로 존재했으나
#     지금 어떤 추적 파일 이름으로도 없는 식별자 모양(`-` `_` `.` 를 품은) 이름. 백틱 밖 산문도 잰다.
#     한 단어 이름(예: adversarial)은 산문 낱말과 부딪쳐 건너뛴다 — 이 락이 못 보는 자리다.
# AC20 — marketplace.json · qg plugin.json · CLAUDE.md 에 runtime-verifier · 2-gate 가 없다.
# git 트리 · 이력을 못 읽으면 조용히 통과하지 않는다(git archive 사본 · 얕은 클론은 RED).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$ROOT" || exit 1
  printf '%s\n' CLAUDE.md .claude-plugin/marketplace.json plugins/quality-gates/.claude-plugin/plugin.json
  git ls-files -- 'docs/philosophy/*.md'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
OUT="$(mktemp)" || exit 1
trap 'rm -f "$OUT"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" > "$OUT" <<'PY'
import fnmatch, json, os, re, subprocess, sys

sys.stdout.reconfigure(encoding="utf-8")
QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) "
           "with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish "
           "surface (not a gate). Invoke manually via /qg or /qg-publish.")
os.chdir(sys.argv[1])


def out(kind, msg):
    print(kind + "\t" + msg)


def git(*args):
    try:
        r = subprocess.run(["git", *args], capture_output=True, text=True)
    except OSError:
        return 127, ""
    return r.returncode, r.stdout


def read(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError as e:
        out("NO", f"{path} 를 읽을 수 없다: {e}")
        return None


rc, ls = git("ls-files")   # 추적 파일만 — 워킹트리의 untracked 파일이 판정을 바꾸지 않는다
if rc != 0 or not ls.strip():
    out("NO", f"git 트리를 읽을 수 없다(rc={rc}) — 트리 없이 인용을 판정하지 않는다")
    sys.exit(0)
tracked = [p for p in ls.splitlines() if p]
tracked_set = set(tracked)
tracked_dirs = set()
for p in tracked:
    parts = p.split("/")
    for i in range(1, len(parts)):
        tracked_dirs.add("/".join(parts[:i]))

charter = ["CLAUDE.md"] + sorted(p for p in tracked if re.fullmatch(r"docs/philosophy/[^/]+\.md", p))
texts = {}
for p in charter:
    t = read(p)
    if t is not None:
        texts[p] = t
if "CLAUDE.md" in texts and len(texts) >= 2:
    out("OK", f"헌장 코퍼스 {len(texts)}개를 읽었다(CLAUDE.md + docs/philosophy/*.md — 하한 2)")
else:
    out("NO", f"헌장 코퍼스가 {len(texts)}개다 — CLAUDE.md 와 철학 문서가 함께 있어야 한다")

# ── 갈래 1: 모양으로 인식되는 인용은 실재한다 ────────────────────────────────
plugins = {p.split("/")[1] for p in tracked
           if re.fullmatch(r"plugins/[^/]+/\.claude-plugin/plugin\.json", p)}


def members(pl):
    s = set()
    for p in tracked:
        m = re.fullmatch(r"plugins/" + re.escape(pl) + r"/(?:agents|commands)/([^/]+)\.md", p)
        if m:
            s.add(m.group(1))
        m = re.fullmatch(r"plugins/" + re.escape(pl) + r"/skills/([^/]+)/SKILL\.md", p)
        if m:
            s.add(m.group(1))
    return s


PLUGREF = re.compile(r"[a-z0-9][a-z0-9-]*:[a-z0-9][a-z0-9-]*")
skipped = {"템플릿": 0, "글롭": 0, "맨 파일명": 0, "리포 밖 플러그인·자리표시": 0, "경로 아닌 모양": 0}
checked = []
for doc, text in texts.items():
    toks = re.findall(r"`([^`\n]+)`", text) + re.findall(r"\]\(([^)\s]+)\)", text)
    for raw in toks:
        tok = raw.strip()
        if "<" in tok or ">" in tok:
            skipped["템플릿"] += 1
            continue
        if "*" in tok:
            # 리포 최상위 항목으로 시작하는 글롭은 추적 파일 1건 이상에 맞아야 한다(글롭 오타를 숨기지 않는다).
            # 그 밖의 글롭(규약 모양 — `*-journal.jsonl` 등)은 건너뛰고 수를 공시한다.
            head = tok.split("/", 1)[0]
            if "/" in tok and head in tracked_dirs:
                checked.append((doc, tok))
                if not any(fnmatch.fnmatchcase(p, tok) for p in tracked):
                    out("NO", f"{doc}: `{tok}` — 그 글롭에 맞는 추적 파일이 없다")
            else:
                skipped["글롭"] += 1
            continue
        if PLUGREF.fullmatch(tok):
            pl, name = tok.split(":", 1)
            if pl not in plugins:
                skipped["리포 밖 플러그인·자리표시"] += 1
                continue
            checked.append((doc, tok))
            if name not in members(pl):
                out("NO", f"{doc}: `{tok}` — 플러그인 {pl} 에 그 agent · skill · command 가 없다")
            continue
        if "/" not in tok:
            if re.fullmatch(r"[^\s/]+\.(?:md|sh|py|json)", tok):
                skipped["맨 파일명"] += 1
            continue
        if (re.match(r"[a-z][a-z0-9+.-]*://", tok) or tok.startswith("/")
                or tok.startswith("#") or re.search(r"\s", tok)):
            skipped["경로 아닌 모양"] += 1
            continue
        path = re.sub(r":\d+(?:-\d+)?$", "", tok.split("#", 1)[0])   # `경로:줄` · `경로:줄-줄` 인용
        if path.startswith("./") or path.startswith("../"):
            path = os.path.normpath(os.path.join(os.path.dirname(doc), path))
        path = path.rstrip("/")
        checked.append((doc, tok))
        if path not in tracked_set and path not in tracked_dirs:
            out("NO", f"{doc}: `{tok}` — 그 경로가 리포에 없다")
n_claude = sum(1 for d, _ in checked if d == "CLAUDE.md")
if len(checked) >= 10 and n_claude >= 3:
    out("OK", f"모양 인용 {len(checked)}건을 실재와 대조했다(CLAUDE.md {n_claude}건 — 하한 전체 10 · CLAUDE.md 3)")
else:
    out("NO", f"모양 인용이 {len(checked)}건(CLAUDE.md {n_claude}건)뿐이다 — 도출이 무너졌다(하한 10 · 3)")
out("NOTE", "건너뛴 모양 — " + " · ".join(f"{k} {v}" for k, v in skipped.items()))

# ── 갈래 2: 이력에서 사라진 이름은 헌장에 없다 ──────────────────────────────
rc, hist = git("log", "HEAD", "--format=", "--name-only", "--diff-filter=A", "--",
               ":(glob)plugins/*/agents/*.md", ":(glob)plugins/*/scripts/*",
               ":(glob)plugins/*/.claude-plugin/plugin.json")
if rc != 0 or not hist.strip():
    out("NO", f"git 이력을 읽을 수 없다(rc={rc}) — 사라진 이름을 도출하지 못하면 판정하지 않는다")
else:
    ever = set()
    for p in hist.split():
        parts = p.split("/")
        if p.endswith("/.claude-plugin/plugin.json"):
            ever.add(parts[1])
        elif len(parts) >= 4 and parts[2] == "agents":
            ever.add(parts[-1][:-3])
        else:
            ever.add(parts[-1])
    # 「지금 있는 이름」은 플러그인 · 공유 모듈 트리에서만 도출한다 — docs/ 의 무관한 문서 이름이
    # 사라진 agent 이름과 우연히 같아 고아를 가리는 것을 막는다.
    now = set()
    for p in tracked:
        if not (p.startswith("plugins/") or p.startswith("shared/")):
            continue
        for comp in p.split("/"):
            now.add(comp)
            now.add(os.path.splitext(comp)[0])
    gone = sorted(n for n in ever if n not in now)
    ident = [n for n in gone if re.search(r"[-_.]", n)]
    words = [n for n in gone if not re.search(r"[-_.]", n)]
    # 양의 짝 — 세 축(agent · 스크립트 · 플러그인)마다 알려진 제거 하나가 도출에 보여야 한다.
    # 한 축의 pathspec 이 깨지면 그 축의 고아가 조용히 사라지므로 축마다 잰다.
    for known, axis in (("runtime-verifier", "agent · PR4b"), ("detect-runtime.sh", "스크립트 · PR4b"),
                        ("agent-transparency", "플러그인 · #159")):
        if known in ident:
            out("OK", f"이력 도출이 알려진 제거 {known}({axis})를 본다(양의 짝)")
        else:
            out("NO", f"이력 도출이 알려진 제거 {known}({axis})를 못 본다 — 그 축의 도출이 무너졌거나 얕은 클론이다")
    out("NOTE", f"사라진 이름 {len(gone)}개 — 식별자 모양 {len(ident)}개 검사 · 한 단어 {len(words)}개 건너뜀({', '.join(words) or '-'})")
    hits = 0
    for doc, text in texts.items():
        for n in ident:
            k = len(re.findall(r"(?<![A-Za-z0-9_.-])" + re.escape(n) + r"(?![A-Za-z0-9_-])", text))
            if k:
                hits += 1
                out("NO", f"{doc}: 이력에서 사라진 이름 `{n}` 이 {k}곳에 있다 — 그 대상이 지금 트리에 없다")
    if hits == 0:
        out("OK", "헌장에 이력에서 사라진 식별자 모양 이름이 없다")

# ── AC20: 공개 계약 · 헌장에 옛 표면이 없다 ───────────────────────────────
FORBID = re.compile(r"runtime-verifier|(?i:\b(?:2|two)[- ]gates?\b)")
for p in (".claude-plugin/marketplace.json", "plugins/quality-gates/.claude-plugin/plugin.json", "CLAUDE.md"):
    t = read(p)
    if t is None:
        continue
    m = FORBID.search(t)
    if m:
        out("NO", f"{p}: 옛 표면 `{m.group(0)}` 이 남았다(AC20)")
    else:
        out("OK", f"{p}: runtime-verifier · 2-gate 가 없다(AC20)")
mk_desc = pj_desc = None
try:
    mk = json.loads(read(".claude-plugin/marketplace.json") or "null")
    ents = [e for e in (mk or {}).get("plugins", []) if isinstance(e, dict) and e.get("name") == "quality-gates"]
    if len(ents) == 1:
        mk_desc = ents[0].get("description")
    else:
        out("NO", f"marketplace.json 의 quality-gates 항목이 {len(ents)}개다")
    pj = json.loads(read("plugins/quality-gates/.claude-plugin/plugin.json") or "null")
    pj_desc = (pj or {}).get("description")
except (ValueError, AttributeError) as e:
    out("NO", f"공개 계약 JSON 을 해석할 수 없다: {e}")
if isinstance(mk_desc, str) and isinstance(pj_desc, str):
    # 공개 계약은 문자열 전체로 잰다 — 부분 문자열(「differential test」)은 부정문
    # (「no differential test」)도 통과시킨다(모의 실행 실측).
    if pj_desc == QG_DESC:
        out("OK", "plugin.json 의 qg 설명이 한 파이프라인의 공개 계약 문자열과 같다(양의 짝)")
    else:
        out("NO", "plugin.json 의 qg 설명이 공개 계약 문자열과 다르다 — 설명을 바꾸려면 이 락의 QG_DESC 도 함께 바꾼다")
    if mk_desc == pj_desc:
        out("OK", "marketplace.json 과 plugin.json 의 qg 설명이 같다")
    else:
        out("NO", "marketplace.json 과 plugin.json 의 qg 설명이 다르다")
else:
    out("NO", "qg 설명을 두 JSON 에서 찾지 못했다")
PY
rc=$?
[ "$rc" -eq 0 ] || no "판정 코어가 죽었다(rc=$rc) — 판정 없이 통과하지 않는다"
TAB="$(printf '\t')"
n=0
while IFS="$TAB" read -r kind msg; do
  n=$((n+1))
  case "$kind" in
    OK) ok "$msg" ;;
    NO) no "$msg" ;;
    NOTE) note "  · $msg" ;;
    *) no "판정 코어가 모르는 줄을 냈다: $kind $msg" ;;
  esac
done < "$OUT"
[ "$n" -gt 0 ] || no "판정 코어가 아무 줄도 내지 않았다"
finish
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n shared/tests/test_charter_citations.sh
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_charter_citations.sh 2>&1 | grep -E '✗|^  · |Total'
```

  **기대** — `✗` 여섯 줄:
  - 갈래 2 두 줄: `CLAUDE.md` · `docs/philosophy/devbrew-harness-philosophy.md` 의 `runtime-verifier`.
  - AC20 세 줄: `marketplace.json` · `plugin.json` 의 `2-gate`, `CLAUDE.md` 의 `runtime-verifier`.
  - 「plugin.json 의 qg 설명이 공개 계약 문자열과 다르다」 한 줄.

  공시 줄(`  · `)은 둘이다(건너뛴 모양 · 사라진 이름 수). `✓` 인 것: 모양 인용 하한, 세 축의 양의 짝(`runtime-verifier` · `detect-runtime.sh` · `agent-transparency`), 두 설명의 일치.

  갈래 1 에 `✗` 가 있으면(경로 · 글롭 · 플러그인 인용) 그 인용을 보고 멈춘다 — 설계가 가정한 헌장과 다르다(계획 결함). 갈래 2 에 `runtime-verifier` 밖의 이름이 걸려도 마찬가지다.

- [ ] **Step 3: 구현한다**

  (a) `CLAUDE.md` Law 2 문단(한 줄)에서 ` *Scoped exception (qg v2.2.0):*` 부터 줄 끝의 `(철학 Law 2).` 까지 지운다. 줄은 `검증은 load-bearing 인프라, 나중 생각이 아님.` 으로 끝난다(앞 공백 없이 마침표로).

  (b) `docs/philosophy/devbrew-harness-philosophy.md` 에서 `*R6 scoped exception (qg v2.2.0):*` 로 시작하는 줄 하나를 통째로 지운다. 바로 위 Law 2 문단 줄과 아래 빈 줄은 그대로 둔다.

  (c) `.claude-plugin/marketplace.json` 의 quality-gates 항목 `description` 과 `plugins/quality-gates/.claude-plugin/plugin.json` 의 `description` 을 둘 다 아래 값으로 바꾼다(JSON 문자열, 다른 키 불변):

```
Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish surface (not a gate). Invoke manually via /qg or /qg-publish.
```

- [ ] **Step 4: 통과를 확인한다**

```bash
python3 -c 'import json;json.load(open(".claude-plugin/marketplace.json"));json.load(open("plugins/quality-gates/.claude-plugin/plugin.json"))' && echo json-ok
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_charter_citations.sh 2>&1 | grep -E '✗|^  · |Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_law2_prose.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | grep -E 'charter|Total'
PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -q plugins/plugin-audit/tests/test_check_staleness.py 2>&1 | tail -1
git grep -n -E 'runtime-verifier|Scoped exception|scoped exception' -- CLAUDE.md docs/philosophy
```

  **기대**
  - 헌장 락 `Fail: 0`.
  - `test_law2_prose.sh` · `test_governance_no_capability_caps.sh` 는 기준선 그대로(둘 다 GREEN).
  - guards 락은 `test_charter_citations.sh` 의 네 글롭이 각각 1건 이상을 덮는다는 줄이 나오고 `Fail: 0`.
  - plugin-audit `test_check_staleness.py` 는 기준선 그대로. pytest 가 없으면 `python3 -m unittest plugins/plugin-audit/tests/test_check_staleness.py` 로 돌린다.
  - 마지막 grep 은 빈 출력.
  - 이 세션 워크트리에서 `[ -r ]` 가드 락이 환경 탓에 RED 면, `$CLAUDE_JOB_DIR/tmp/` 아래 `git clone -q --no-hardlinks` 한 사본(HEAD 커밋 후)에서 다시 돌려 판정한다.

- [ ] **Step 5: 커밋**

```bash
git add shared/tests/test_charter_citations.sh CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md \
        .claude-plugin/marketplace.json plugins/quality-gates/.claude-plugin/plugin.json
git ls-files -s shared/tests/test_charter_citations.sh | cut -c1-6
git commit -m "feat(charter): 헌장 인용 락 · 공개 계약에서 두 게이트를 거둔다 · Law 2 예외 제거" \
  -m "test_charter_citations.sh 가 헌장이 모양으로 인용하는 경로 · 플러그인 이름의 실재와, git 이력에서 사라진 agent · 스크립트 · 플러그인 이름의 부재를 잰다. 사라진 runtime-verifier 를 이름으로 박던 Law 2 예외를 CLAUDE.md 와 철학 문서에서 지우고, marketplace.json · plugin.json 의 qg 설명을 한 파이프라인으로 고친다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr5
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

  `git ls-files -s` 결과는 `100755`.

---

### Task 2: qg 안의 옛 게이트 문구

**Files:**
- Create: `plugins/quality-gates/tests/test_gate_era_prose_absent.sh`
- Modify: `plugins/quality-gates/agents/security-reviewer.md` · `plugins/quality-gates/agents/pr-understanding-builder.md` · `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`

**Interfaces:**
- Consumes: Task 1 이 고친 `plugin.json` 설명(이 락의 코퍼스에 든다 — Task 1 전이면 `2-gate` 로 RED).
- Produces: `--emit-scanned` 는 이 락이 읽는 코퍼스를 낸다. 코퍼스는 qg 의 추적 `*.md` 와 `plugin.json` 이고, `tests/` · `CHANGELOG.md` 는 뺀다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `plugins/quality-gates/tests/test_gate_era_prose_absent.sh` 를 아래 내용 그대로 만들고 `chmod +x`.

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/*.md plugins/quality-gates/.claude-plugin/plugin.json
# test_gate_era_prose_absent.sh — 한 파이프라인 뒤 옛 게이트 시대 문구의 부재 (설계 §6.5.3 · §16 범위 기록).
#
# `Review gate` · `Runtime gate` · `2-gate`/`two-gate` 는 게이트가 둘이던 시절의 이름이다 — 한 파이프라인
# 뒤에 남으면 산문이 없는 게이트를 가리킨다. 코퍼스는 qg 의 산문 전체(추적되는 *.md 와 plugin.json)이고
# tests/ · CHANGELOG.md 는 이력이라 뺀다. 음의 락이라 양의 짝을 둔다 — 코퍼스 하한 · 고친 자리의 새 문구.
# `Review` · `Runtime` 의 첫 글자는 대문자로 잰다 — 소문자 `hard-review gate`(SKILL 의 제거 이력 한 줄)는
# 다른 말이다. `Gate`/`gate`, `-`/공백, 복수형 `gates` 는 모두 잡는다(모의 실행이 `Runtime Gate` ·
# `Two-gate` · `2 gates` 생존을 실측했다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
corpus() {
  (cd "$ROOT" && git ls-files -- 'plugins/quality-gates/*.md' 'plugins/quality-gates/.claude-plugin/plugin.json' \
    | grep -v -E '^plugins/quality-gates/(tests/|CHANGELOG\.md$)')
}
[ "${1:-}" = "--emit-scanned" ] && { corpus; exit 0; }
. "$ROOT/shared/tests/assert.sh"
QG="$ROOT/plugins/quality-gates"

case_gate_era_tokens_absent() {
  local files n f hit bad=0
  files=$(corpus)
  n=$(printf '%s\n' "$files" | grep -c .)
  if [ "$n" -ge 15 ]; then
    ok "코퍼스 ${n}개(qg 의 *.md · plugin.json, tests · CHANGELOG 제외 — 하한 15)"
  else
    no "코퍼스가 ${n}개뿐이다(하한 15) — 도출이 무너졌다"
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    hit=$(grep -n -E '(Review|Runtime)[ -][Gg]ates?|(^|[^A-Za-z0-9])([Tt]wo|2)[- ][Gg]ates?' -- "$ROOT/$f" | head -3 | tr '\n' ' ')
    if [ -n "$hit" ]; then bad=$((bad+1)); no "$f 에 옛 게이트 문구가 남았다: $hit"; fi
  done <<EOF
$files
EOF
  [ "$bad" -eq 0 ] && ok "qg 산문에 Review gate · Runtime gate · 2-gate 가 없다"
}

case_new_wording_present() {
  assert_file_grep "$QG/agents/security-reviewer.md" '^description: Phase 1 of the qg review pipeline — always-run code-level security review' \
    "security-reviewer 설명이 한 파이프라인의 Phase 1 을 이름 붙인다"
  assert_file_grep "$QG/agents/security-reviewer.md" 'the code-level security specialist for review pipeline Phase 1\.' \
    "security-reviewer 역할 문장이 한 파이프라인의 Phase 1 을 이름 붙인다"
  assert_file_grep "$QG/agents/pr-understanding-builder.md" "qg's review pipeline \(\`/qg\`\) and the publish orchestrator" \
    "pr-understanding-builder 가 판정을 한 파이프라인의 몫으로 넘긴다"
  assert_file_grep "$QG/skills/publishing-pr-understanding/SKILL.md" '^리뷰 파이프라인의 몫\), artifact' \
    "publishing SKILL 이 판정을 /qg 리뷰 파이프라인의 몫으로 넘긴다"
  assert_file_grep "$QG/skills/critiquing-artifacts/SKILL.md" '^  /qg pipeline \(one pipeline, one verdict\)\.$' \
    "critiquing SKILL 이 코드 대상을 한 파이프라인으로 보낸다"
}

for c in case_gate_era_tokens_absent case_new_wording_present; do
  "$c"
done
finish
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_gate_era_prose_absent.sh
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_gate_era_prose_absent.sh 2>&1 | grep -E '✗|Total'
```

  **기대** — 부재 쪽 `✗` 넷(`security-reviewer.md` · `pr-understanding-builder.md` · `critiquing-artifacts/SKILL.md` · `publishing-pr-understanding/SKILL.md`) + 양의 짝 `✗` 다섯. 코퍼스 하한은 `✓`. `plugin.json` 은 Task 1 이 이미 고쳐 걸리지 않는다.

- [ ] **Step 3: 구현한다** — 역할 라벨 문구만. 규칙 · 임계 · 도구 · 다른 문장은 한 글자도 바꾸지 않는다.

  (a) `agents/security-reviewer.md` 3번째 줄 `description: Phase 1 of the Review gate — always-run code-level security review.` 의 `Phase 1 of the Review gate` 를 `Phase 1 of the qg review pipeline` 으로.

  (b) 같은 파일 `You are **security-reviewer**, the code-level security specialist for the Review gate Phase 1.` 의 `for the Review gate Phase 1.` 을 `for review pipeline Phase 1.` 로.

  (c) `agents/pr-understanding-builder.md` 의 `qg's Review gate and the publish orchestrator` 를 ``qg's review pipeline (`/qg`) and the publish orchestrator`` 로.

  (d) `skills/publishing-pr-understanding/SKILL.md` 에서 `Review gate의 몫), artifact` 로 시작하는 줄의 `Review gate의 몫)` 을 `리뷰 파이프라인의 몫)` 으로(바로 윗줄 끝의 ``(그건 `/qg` `` 는 그대로).

  (e) `skills/critiquing-artifacts/SKILL.md` 머리말 `description` 의 마지막 줄 `  two-gate pipeline.` 을 `  /qg pipeline (one pipeline, one verdict).` 로(들여쓰기 두 칸 유지 — YAML 접힘 스칼라).

- [ ] **Step 4: 통과를 확인한다**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_gate_era_prose_absent.sh 2>&1 | grep -E '✗|Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_agent_frontmatter_keys.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | grep -E 'gate_era|Total'
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -1
PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_copy_of_contract.sh 2>&1 | tail -1
git status --short
```

  **기대** — 새 락 `Fail: 0`. 나머지 넷은 기준선 그대로다. guards 락은 새 락의 두 글롭이 각각 1건 이상을 덮는다. `git status --short` 는 네 문서 파일(` M`)과 새 락(`??`)만 보여야 한다. 워크트리 환경 RED 는 Task 1 Step 4 처럼 clone 으로 판정한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/tests/test_gate_era_prose_absent.sh plugins/quality-gates/agents/security-reviewer.md \
        plugins/quality-gates/agents/pr-understanding-builder.md plugins/quality-gates/skills/critiquing-artifacts/SKILL.md \
        plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md
git ls-files -s plugins/quality-gates/tests/test_gate_era_prose_absent.sh | cut -c1-6
git commit -m "docs(qg): 옛 게이트 문구를 한 파이프라인으로 — persona 라벨 · SKILL 두 곳 · 부재 락" \
  -m "security-reviewer · pr-understanding-builder 의 「Review gate」와 critiquing · publishing SKILL 의 「two-gate」 · 「Review gate」를 한 파이프라인 이름으로 바꾼다. persona 는 역할 라벨만 바꾸고 규칙 · 임계 · 도구는 그대로다. test_gate_era_prose_absent.sh 가 qg 산문 전체에서 그 문구의 부재와 새 문구를 잰다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr5
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 3: PR4d 넘김 — 공지 문구 · README · `create-head --topic` 사유

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/README.md` · `plugins/quality-gates/scripts/qg-worktree.sh`
- Test: `plugins/quality-gates/tests/test_topic_scope_wiring.sh` · `plugins/quality-gates/tests/test_topic_head.sh`

**Interfaces:**
- Produces:
  - SKILL ① 1a 공지 한 줄:
    ``   `status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `> [quality-gates] 토픽 <topic_key> 의 선언 커밋 <in_base>개는 이미 base 에 있어 이번 판정 대상에서 빠졌다 — 자기 PR 에서 판정됐다.` ``
  - `qg-worktree.sh create-head … --topic <key>` 는 재도출이 `ok` 가 아니면 stderr 에 `topic HEAD axis is not derivable now (status: <status> — <reason>) — …` 를 내고 exit 2.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

  (a) `test_topic_scope_wiring.sh` 의 `case_in_base_notice` 에서 세 줄을 바꾼다.
  - `got=$(printf '%s\n' "$win" | grep -F '`in_base:`' | grep -F '기준선에 포함됐다' | grep -F '판정 대상이 아니다')` 를 `got=$(printf '%s\n' "$win" | grep -F '`in_base:`' | grep -F '판정 대상에서 빠졌다' | grep -F '자기 PR 에서 판정됐다')` 로.
  - `assert_not_grep "$got" '않|말 것|생략|아니고' "그 줄에 부정 · 반전 토큰이 없다(「판정 대상이 아니다」는 위에서 따로 잰다)"` 의 메시지 괄호를 `(「판정 대상에서 빠졌다」는 위에서 따로 잰다)` 로.
  - `assert_grep "$got" '이번 판정 대상이 아니다\.`$' "그 문장이 닫는 백틱 직후에 끝난다(줄 끝 앵커 — 백틱 뒤 덧붙임을 잡는다)"` 의 패턴을 `'자기 PR 에서 판정됐다\.`$'` 로.

  그리고 같은 함수의 마지막 단언 아래에 한 줄을 더한다(형제 토폴로지에서 틀리는 옛 문구가 1a 창에 돌아오지 않는다 — 양의 짝은 위의 개수 단언):

```bash
  assert_not_grep "$win" '기준선에 포함' "① 1a 창에 「기준선에 포함」이 없다 — 형제 토폴로지에서는 그 조각이 경계 트리에 없다(설계 §6.2.2 2)"
```

  (b) `test_topic_head.sh` — `for c in …` **앞**에 케이스 하나를 더한다. 루프 목록 마지막 줄 `         case_explicit_topic_fully_merged; do` 를 `         case_explicit_topic_fully_merged case_create_head_topic_names_resolve_reason; do` 로 바꾼다:

```bash
case_create_head_topic_names_resolve_reason() {
  # R-init 의 create-head --topic 재도출이 ok 가 아니면 죽는다 — 그때 사용자에게 status 만이 아니라
  # resolve 의 사유를 보인다(전부 머지된 키 · base 가 1a 와 R-init 사이에 움직인 경우).
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main; git merge -q --no-ff topicA -m "merge topicA"
  git checkout -q -b later; echo l > l.txt; git add l.txt; git commit -qm "later (선언 없음)"
  local S; S=$(bash "$SEALER" seal "$SID")
  local err rc; err=$(bash "$WT" create-head "$S" "$SID" --topic "$KEY" 2>&1 >/dev/null); rc=$?
  assert_eq "$rc" "2" "전부 머지된 키를 create-head --topic: exit 2"
  assert_grep "$err" '\(status: declaration-invalid — ' "stderr 가 status 를 이름 붙인다"
  assert_grep "$err" 'all declared commits are already in base_ref' "stderr 가 resolve 의 사유를 싣는다"
  cleanup
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
bash -n plugins/quality-gates/tests/test_topic_scope_wiring.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
bash -n plugins/quality-gates/tests/test_topic_head.sh && PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
```

  **기대**
  - wiring 은 공지 개수 단언 · 긍정형 단언 · 끝 앵커 단언 · 「기준선에 포함」 부재 단언이 `✗` 다. 부정 토큰 단언은 빈 입력이라 GREEN 이다(그 이빨은 PR4d 변이 Row 11 · 13 · 14 가 증명했다).
  - topic_head 는 새 케이스의 status 형식 단언 · 사유 단언이 `✗` 다.

- [ ] **Step 3: 구현한다**

  (a) SKILL.md ① 1a 공지 줄(`` `status: ok` 이고 파일의 `in_base:` 가 0 보다 크면 공지 한 줄: `` 로 시작하는 한 줄)에서 `기준선에 포함됐다 — 이번 판정 대상이 아니다.` 를 `이번 판정 대상에서 빠졌다 — 자기 PR 에서 판정됐다.` 로(나머지 글자 그대로 — 결과는 Interfaces 의 줄).

  (b) README.md 「토픽 스코프 — `Spec:` 트레일러」 절:
  `포함)를 한 판정 단위로 본다. 같은 키로 이미 base 에 머지된 앞 조각은 기준선에 든다 — 그 조각은` ⏎ `자기 PR 에서 판정됐다 — 그 선언 커밋 수가 \`scope:\` 블록의 \`in_base:\` 에 보인다:` 두 줄을 아래 세 줄로:

```markdown
포함)를 한 판정 단위로 본다. 같은 키로 이미 base 에 머지된 앞 조각은 판정 대상에서 빠진다 — 그
조각은 자기 PR 에서 판정됐다(그 변경이 기준선 트리에 드는지는 이 브랜치가 그 머지 뒤 base 를
들였는지에 달렸다) — 그 선언 커밋 수가 `scope:` 블록의 `in_base:` 에 보인다:
```

  (c) README.md 「알려진 한계」 squash 항목(`- 같은 키의 앞 조각을 squash · rebase-merge · cherry-pick 으로` 로 시작해 `생기지 않는다.` 로 끝나는 여섯 줄)을 아래로:

```markdown
- 같은 키의 앞 조각을 squash · rebase-merge · cherry-pick 으로 base 에 넣고 그 브랜치 ref(로컬 ·
  원격-추적 어느 쪽이든)를 남겨 두면 원래 커밋이 base 의 조상이 아니라서 여전히 구성원이다 — 이미
  들어간 변경을 다시 보고, 경계가 구성원 분기점들의 merge-base 라 그 조각의 옛 분기점까지 내려가
  그 뒤 base 이력까지 리뷰 대상에 들 수 있다(`branches:` · `commits:` 에 보인다). 사이에 낀 base
  커밋이 다른 `Spec:` 키를 달았으면 흡수 대신 `not-certified (declaration-invalid)`(키 둘)로 막힌다.
  머지한 브랜치는 로컬과 원격 모두 지운다(`git branch -D` · `git push origin --delete` ·
  `git fetch --prune`). 조각마다 다른 키(`…#pr1` · `…#pr2`)를 쓰면 생기지 않는다.
```

  (d) README.md 「알려진 한계」 로컬 전용 머지 항목(`- base 는 \`base_ref\`(보통 \`origin/main\`)다 —` 로 시작해 `머지는 원격에서 하고 fetch 한 뒤 돌린다.` 로 끝나는 세 줄)을 아래로:

```markdown
- base 는 `base_ref`(보통 `origin/main`)다. 같은 키의 앞 조각을 로컬 `main` 에만 머지했으면(push
  전) 로컬 `main` 과 그 뒤 딴 브랜치가 구성원으로 잡힌다. 원격에서 머지했지만 아직 fetch 하지
  않았으면 남은 앞 조각 ref(로컬 · `origin/<b>`) 때문에 그 조각을 다시 본다. 머지는 원격에서 하고
  fetch 한 뒤 돌린다.
```

  (e) `scripts/qg-worktree.sh` `create-head` 의 `--topic` 분기에서 두 줄을 바꾼다.
  - `ch_status=$(printf '%s\n' "$ch_out" | sed -n 's/^status: //p' | head -1)` **아래**에 한 줄을 더한다.
  - 그 아래 `die` 줄을 바꾼다.

```bash
      ch_reason=$(printf '%s\n' "$ch_out" | sed -n 's/^reason: //p' | head -1)
```

  `|| die "topic HEAD axis is not derivable now (status: ${ch_status:-?}) — no combined tree to verify against"` 를 아래로:

```bash
        || die "topic HEAD axis is not derivable now (status: ${ch_status:-?} — ${ch_reason:--}) — no combined tree to verify against"
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash -n plugins/quality-gates/scripts/qg-worktree.sh
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_scope_wiring.sh 2>&1 | grep -E '✗|Total'
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | grep -E '✗|Total'
for f in test_readme_scope_reconcile test_readme_state_diagram_complete test_one_pipeline_surface test_worktree test_topic_boundary; do PYTHONDONTWRITEBYTECODE=1 bash "plugins/quality-gates/tests/$f.sh" 2>&1 | tail -1; done
git grep -n -E '기준선에 포함|기준선에 든다' -- plugins/quality-gates ':!plugins/quality-gates/CHANGELOG.md' ':!plugins/quality-gates/tests'
```

  **기대**
  - 두 락 `Fail: 0`. 나머지 다섯은 기준선 그대로다. `test_worktree.sh` 는 워크트리 환경 RED 일 수 있다 — clone 으로 판정한다. `for` 줄이 가드에 막히면 한 줄씩 돌린다.
  - 마지막 grep 은 빈 출력이다. 줄이 나오면 그 문면도 「판정 대상에서 빠진다」로 맞춘다. 범위 불변식 안(references 등)이면 멈추고 보고한다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/scripts/qg-worktree.sh \
        plugins/quality-gates/tests/test_topic_scope_wiring.sh plugins/quality-gates/tests/test_topic_head.sh
git commit -m "fix(qg): in_base 공지를 「판정 대상에서 빠졌다」로 · README 조건부 서술 · create-head --topic 이 사유를 싣는다" \
  -m "형제 토폴로지에서는 머지된 앞 조각이 경계 트리에 없으므로 「기준선에 포함됐다」가 틀린다 — 공지와 README 를 판정 대상에서 빠졌다는 사실로 고친다. squash 한계의 흡수는 다른 키가 끼면 declaration-invalid 로 막힌다는 조건을, 로컬 전용 머지와 fetch 전 원격 머지의 다른 결과를 적는다. create-head --topic 이 재도출에 실패하면 resolve 의 사유를 함께 낸다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr5
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
```

---

### Task 4: 변이 — 락 이빨

**Files:**
- Create (추적 안 함): `$CLAUDE_JOB_DIR/tmp/pr5-mutations.md` → 미러

- [ ] **Step 1: 변이를 태운다** — 행마다 새 clone 을 쓴다: `git clone -q --no-hardlinks <워크트리> "$CLAUDE_JOB_DIR/tmp/pr5-mut/rowN"`.
  - ① 변이를 적용하고 원본과 `cmp` 가 **다름**을 확인한다.
  - ② 지목 락을 clone 경로로 `PYTHONDONTWRITEBYTECODE=1` 로 돌려 기대한 단언이 `✗` 인지 본다.
  - ③ 양성 대조로 원본 clone(`pristine`)의 그 락이 `Fail: 0` 인지 본다.
  - 헌장 락은 git 이력을 읽으므로 `git archive` 사본을 쓰지 않는다(Row 5 만 예외 — 그것이 변이다).
  - 결과는 `$CLAUDE_JOB_DIR/tmp/pr5-mutations.md` 에 표로 쓰고 미러로 복사한다. 락 출력 원문도 행마다 `rowN.out` 으로 남긴다.

| # | 축 | 변이 | 지목 락 · 기대 `✗` |
|---|---|---|---|
| 1 | 추가 | `CLAUDE.md` Law 2 줄 끝에 ` 예: executor(runtime-verifier).` 를 되살림 | `test_charter_citations.sh` — `CLAUDE.md: 이력에서 사라진 이름 \`runtime-verifier\`` · AC20 `CLAUDE.md: 옛 표면` |
| 2 | 추가 | `docs/philosophy/devbrew-harness-philosophy.md` Law 2 줄 끝에 ` (runtime-verifier)` | 같은 락 — 철학 문서의 사라진 이름 |
| 3 | 변형 | `CLAUDE.md` 의 `` `shared/tests/test_dispatch_disposition.sh` `` → `` `shared/tests/test_dispatch_dispositon.sh` ``(오타) | 같은 락 — `그 경로가 리포에 없다` |
| 4 | 추가 | `CLAUDE.md` 끝에 `` `quality-gates:no-such-agent` `` 한 줄 | 같은 락 — `플러그인 quality-gates 에 그 agent · skill · command 가 없다` |
| 5 | 환경 | 락을 `git archive HEAD` 사본(비-git)에서 돌림 | 같은 락 — `git 트리를 읽을 수 없다` |
| 6 | 환경 | `git clone --depth 1` 얕은 클론에서 돌림 | 같은 락 — `이력 도출이 알려진 제거(runtime-verifier, PR4b)를 못 본다` |
| 7 | 변형 | 락의 `":(glob)plugins/*/agents/*.md"` → `":(glob)plugins/*/agentz/*.md"` | 같은 락 — `알려진 제거 runtime-verifier(agent · PR4b)를 못 본다` |
| 7b | 변형 | 락의 `":(glob)plugins/*/scripts/*"` → `":(glob)plugins/*/scriptz/*"` | 같은 락 — `알려진 제거 detect-runtime.sh(스크립트 · PR4b)를 못 본다` |
| 7c | 변형 | 락의 `":(glob)plugins/*/.claude-plugin/plugin.json"` → `":(glob)plugins/*/.claude-plugin/plugin.jsn"` | 같은 락 — `알려진 제거 agent-transparency(플러그인 · #159)를 못 본다` |
| 8 | 불일치 | `plugin.json` 설명 끝에 ` x` 를 더함(marketplace 는 그대로) | 같은 락 — `두 설명이 다르다` |
| 9 | 되돌림 | `marketplace.json` qg 설명을 옛 `2-gate quality verification pipeline (review + runtime)…` 로 | 같은 락 — AC20 `marketplace.json: 옛 표면` |
| 10 | 삭제 | 락의 갈래 1 루프에서 `checked.append((doc, tok))` 두 곳을 지움 | 같은 락 — 모양 인용 하한 `✗` |
| 11 | 되돌림 | `security-reviewer.md` 3번째 줄을 옛 `Phase 1 of the Review gate` 로 | `test_gate_era_prose_absent.sh` — 부재 `✗` · 새 문구 `✗` |
| 12 | 추가 | `skills/quality-pipeline/SKILL.md` 아무 산문 줄에 ` (Runtime gate)` | 같은 락 — 부재 `✗` |
| 13 | 추가 | `README.md` 아무 산문 줄에 ` two-gate` | 같은 락 — 부재 `✗` |
| 14 | 되돌림 | SKILL 공지 줄을 옛 `기준선에 포함됐다 — 이번 판정 대상이 아니다.` 로 | `test_topic_scope_wiring.sh` — 개수 · 끝 앵커 · 「기준선에 포함」 부재 |
| 15 | 추가 | SKILL 1a 창의 다른 **산문** 줄(펜스 밖 — 펜스 줄을 고르면 펜스 단언들이 함께 깨져 지목이 흐려진다) 끝에 ` 머지된 조각은 기준선에 포함된다.` | 같은 락 — 「기준선에 포함」 부재 |
| 16 | 삭제 | `qg-worktree.sh` die 메시지에서 ` — ${ch_reason:--}` 를 지움 | `test_topic_head.sh` — 새 케이스의 status 형식 · 사유 단언 |
| 17 | 변형 | `qg-worktree.sh` 의 `sed -n 's/^reason: //p'` → `sed -n 's/^rason: //p'` | 같은 락 — 사유 단언(`—` 뒤가 `-`) |
| 18 | 추가 | 추적 파일 `docs/notes/codex-reviewer.md` 를 커밋하고 철학 문서 Law 2 줄 끝에 ` (codex-reviewer 가 대신 본다)` | `test_charter_citations.sh` — 철학 문서의 사라진 이름 `codex-reviewer`(docs/ 의 무관한 파일이 가리지 못한다) |
| 19 | 추가 | untracked `plugins/quality-gates/agents/runtime-verifier.md` 를 두고(커밋 안 함) Row 1 과 같은 되살림 | 같은 락 — 사라진 이름 `runtime-verifier`(untracked 파일이 판정을 바꾸지 못한다) |
| 20 | 추가 | `CLAUDE.md` 끝에 ` qg 는 더 이상 2-gates 가 아니다.` | 같은 락 — AC20 `CLAUDE.md: 옛 표면` |
| 21 | 부정 | 두 JSON 의 qg 설명을 `… (review only; no differential test) …` 로(둘을 같게) | 같은 락 — `공개 계약 문자열과 다르다` |
| 22 | 변형 | `CLAUDE.md` 에 `` `docs/philosphy/*.md` ``(글롭 오타) 한 줄 | 같은 락 — `그 글롭에 맞는 추적 파일이 없다` |
| 23 | 추가 | `README.md` 아무 산문 줄 끝에 ` Two-gate pipeline.` · SKILL 아무 산문 줄 끝에 ` Then the Runtime Gate runs.`(두 clone) | `test_gate_era_prose_absent.sh` — 부재 `✗`(대소문자 변형) |

  **양의 대조 한 줄(생존이 정답)** — `CLAUDE.md` 에 `` `plugins/quality-gates/scripts/qg-worktree.sh:593` `` 를 더해도 헌장 락이 `Fail: 0` 이어야 한다(`경로:줄` 인용은 거짓 RED 가 아니다). 표에 「GREEN 기대」로 적는다.

  **양성 대조** — 변이 전과 끝에 `pristine` clone 에서 다섯 락을 돈다: `shared/tests/test_charter_citations.sh` · `test_gate_era_prose_absent.sh` · `test_topic_scope_wiring.sh` · `test_topic_head.sh` · `test_guards_coverage_bidirectional.sh`. 다섯 모두 `Fail: 0` 이어야 한다.

- [ ] **Step 2: 구멍을 닫는다** — 기대한 `✗` 가 안 난 행마다 락에 단언을 더하거나 좁혀 RED 로 만든다. 같은 변이를 새 clone 에서 다시 태워 확인하고 커밋한다(제품 문면은 바꾸지 않는다).
  - 수정 라운드는 **둘까지**다. 셋째 생존이 같은 자리에서 새로 나면 층위 신호로 보고 멈추고 원장에 적는다.
  - 닫기 커밋 메시지는 `test(…): 변이 생존 행 닫기 — <무엇을>` 에 본문 한 단락을 둔다. 트레일러는 `#pr5` 두 줄이다.

---

### Task 5: §13 수동 e2e — 컨트롤러가 한다

구현자를 디스패치하지 않는다. 사용자가 「PR5 안에서 내가 scratch 리포로 실행」을 골랐다(2026-09-27). 산출은 추적하지 않는다. `$CLAUDE_JOB_DIR/tmp/pr5-e2e/` 에 두고 미러에도 복사한다.

- [ ] **Step 1: 헤드리스 적재 스파이크** — 비용이 거의 없는 호출로 플러그인이 실리는지 먼저 본다.

```bash
J=/Users/jeonghokim/.claude/jobs/b6faa344/tmp/pr5-e2e
rm -rf "$J"; mkdir -p "$J"
git clone -q --no-hardlinks /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-recritic-swap-pr4a "$J/devbrew"
cd "$J" && claude -p --plugin-dir "$J/devbrew/plugins/quality-gates" --output-format stream-json --verbose "reply with the single word ok" > "$J/spike.jsonl" 2> "$J/spike.err"; echo "rc=$?"
python3 -c 'import json,sys
for l in open(sys.argv[1]):
    e=json.loads(l)
    if e.get("type")=="system" and e.get("subtype")=="init":
        print("qg cmd:", [c for c in e.get("slash_commands",[]) if c.startswith("quality-gates:")])
        print("qg agents:", [a for a in e.get("agents",[]) if "quality-gates" in a or a in ("security-reviewer","doc-recritic")])' "$J/spike.jsonl"
```

  **기대** — `rc=0`. `quality-gates:qg` 가 슬래시 커맨드에 있고, qg 에이전트가 목록에 있다. qg 는 `quality-gates@inline` 으로 한 번만 실린다. 적재가 안 되면 멈춘다. 원장에 적고 사용자에게 보고한다(대안: 절차서만 남기고 사용자가 대화형으로 실행).

  이 실행은 격리되지 않는다 — 모의 실행에서 init 에 플러그인 30개가 실렸다(설치본 `project-init` · `spec-distill` · `plugin-audit` 의 훅 포함). 스파이크 비용은 약 $0.23 이었다. init 의 `plugins` 목록과 `total_cost_usd` 를 `observations.md` 에 적어 e2e 가 어떤 환경에서 돌았는지 남긴다.

- [ ] **Step 2: scratch 리포** — `$J/setup.sh` 를 아래 내용으로 쓰고 `bash` 로 돌린다.

```bash
#!/usr/bin/env bash
# 형제 토픽 둘(같은 Spec: 키) — topicA 는 새 파일(정상), topicB 는 mul 을 망가뜨림(차등 테스트가 새 실패를 봐야 한다)
set -eu
J=/Users/jeonghokim/.claude/jobs/b6faa344/tmp/pr5-e2e
rm -rf "$J/origin.git" "$J/scratch"
git init -q --bare "$J/origin.git"
mkdir -p "$J/scratch" && cd "$J/scratch"
git init -q -b main
git config user.email e2e@example.invalid; git config user.name e2e
mkdir -p docs tests
printf '# e2e 설계\n\n두 수의 합 · 곱 · 차.\n' > docs/e2e-design.md
printf '#!/usr/bin/env bash\nadd() { echo $(( $1 + $2 )); }\nmul() { echo $(( $1 * $2 )); }\n' > calc.sh
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/../calc.sh"\nfail=0\n[ "$(add 2 3)" = 5 ] || { echo "FAIL add"; fail=1; }\n[ "$(mul 2 3)" = 6 ] || { echo "FAIL mul"; fail=1; }\nexit $fail\n' > tests/test_calc.sh
chmod +x calc.sh tests/test_calc.sh
git add -A; git commit -qm "init"
git remote add origin "$J/origin.git"; git push -q -u origin main; git remote set-head origin main
git checkout -q -b topicA
printf '#!/usr/bin/env bash\nsub() { echo $(( $1 - $2 )); }\n' > sub.sh
printf '#!/usr/bin/env bash\n. "$(dirname "$0")/../sub.sh"\n[ "$(sub 5 3)" = 2 ] || { echo "FAIL sub"; exit 1; }\n' > tests/test_sub.sh
chmod +x sub.sh tests/test_sub.sh
git add -A; git commit -qm "feat: sub

Spec: docs/e2e-design.md#e2e"
git checkout -q -b topicB main
sed -i '' 's/\$1 \* \$2/$1 + $2/' calc.sh
git commit -qam "refactor: mul

Spec: docs/e2e-design.md#e2e"
bash tests/test_calc.sh || echo "topicB: test_calc 실패(의도)"
git log --oneline --all --graph | head -8
```

- [ ] **Step 3: 헤드리스 `/quality-gates:qg`** — 백그라운드로 돌린다(수십 분이 걸릴 수 있다).

```bash
J=/Users/jeonghokim/.claude/jobs/b6faa344/tmp/pr5-e2e
printf '%s\n' "이 실행은 비대화 e2e 다. AskUserQuestion 결정 지점에 닿으면 질문하지 말고 「멈춤(수정하지 않음)」을 고른 것으로 하고, 코드를 고치지 않은 채 Final Summary 를 낸다." > "$J/e2e-system.txt"
cd "$J/scratch" && git checkout -q topicB && claude -p --plugin-dir "$J/devbrew/plugins/quality-gates" --dangerously-skip-permissions \
  --output-format stream-json --verbose --append-system-prompt "$(cat "$J/e2e-system.txt")" "/quality-gates:qg" \
  > "$J/run1.jsonl" 2> "$J/run1.err"; echo "rc=$?"
```

- [ ] **Step 4: 관측표** — `$J/observe.py` 로 `run1.jsonl` 에서 뽑아 `$J/observations.md` 에 쓴다. 뽑는 것:
  - `num_turns` · `is_error`.
  - `Agent` 도구 호출의 `subagent_type` 목록.
  - `Bash` 명령 중 `topic-head.sh` · `run-test-selection` · `diff-test-results` · `synthesize_findings.py` · `codex` 를 담은 것의 수. codex 호출 수는 사용자에게 보고한다.
  - 마지막 `result` 텍스트의 판정 줄과 `scope:` 블록.

```python
import json, sys, re
ev = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
agents, bash = [], []
for e in ev:
    for c in (e.get("message", {}) or {}).get("content", []) or []:
        if isinstance(c, dict) and c.get("type") == "tool_use":
            if c.get("name") == "Agent":
                agents.append(c["input"].get("subagent_type"))
            if c.get("name") == "Bash":
                bash.append(c["input"].get("command", ""))
res = [e for e in ev if e.get("type") == "result"]
init = [e for e in ev if e.get("type") == "system" and e.get("subtype") == "init"]
print("plugins:", [p.get("name") if isinstance(p, dict) else p for p in (init[0].get("plugins", []) if init else [])])
print("num_turns:", res[-1].get("num_turns") if res else None, "is_error:", res[-1].get("is_error") if res else None,
      "total_cost_usd:", res[-1].get("total_cost_usd") if res else None)
print("agents:", agents)
for k in ("topic-head.sh", "run-test-selection", "diff-test-results", "synthesize_findings.py", "codex"):
    print(k, sum(1 for b in bash if k in b))
txt = res[-1].get("result", "") if res else ""
print("verdict lines:", [l for l in txt.splitlines() if re.search(r"\b(clean|defect|not-certified)\b", l)][:5])
m = re.search(r"(?ms)^scope:\n(?:  .*\n?)+", txt)
print("scope block:\n" + (m.group(0) if m else "(없음)"))
```

  **기대(설계가 말하는 관측)**
  - `Agent` 에 `quality-gates:security-reviewer` 와 재비판(`quality-gates:doc-recritic`)이 있다.
  - `topic-head.sh` 호출 ≥ 1 · `run-test-selection` ≥ 1.
  - 판정은 `defect`(topicB 가 `test_calc.sh` 를 새로 깨뜨림 — 차등 테스트의 (P,F)).
  - `scope:` 블록에 `branches: topicA,topicB` · `in_base: 0`.
  - 다르면 그것이 e2e 의 발견이다. 원인을 가르고(스파이크 · 설정 · 제품) 원장에 적는다.
    - 제품 결함이 문서 · 배선 한 곳이면 이 PR 의 수정 한 번으로 고친다.
    - 설계 층위면 멈추고 사용자에게 보고한다.
  - `observations.md` 는 사람이 읽을 요약이다: 관측표 + 판정 줄 + `scope:` 블록 + 한 문단 소감(산출물이 사람에게 읽히는가). 이것이 PR 본문 「수동 e2e」 절의 원천이다.

---

### Task 6: 회귀 · AC23 · 범위 불변식 · bump · CHANGELOG

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`(`version` 만) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(제목 버전) · `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md`(제목 버전)

- [ ] **Step 1: AC23 · 범위 불변식**

```bash
PYTHONDONTWRITEBYTECODE=1 bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | tail -1
git diff --stat origin/main...HEAD -- plugins/spec-distill plugins/plugin-audit plugins/project-init tools \
  plugins/quality-gates/skills/quality-pipeline/references
git diff --stat origin/main...HEAD -- shared
git diff --stat origin/main...HEAD -- plugins/quality-gates/scripts plugins/quality-gates/agents docs/superpowers/specs
```

  **기대**
  - AC23 락 `Fail: 0`.
  - 첫 diff 는 빈 출력이다.
  - 둘째는 `shared/tests/test_charter_citations.sh` 한 파일이다.
  - 셋째는 `qg-worktree.sh` · `security-reviewer.md` · `pr-understanding-builder.md` · 설계 문서(첫 커밋)뿐이다.

- [ ] **Step 2: 머지 직전 동기화 · 버전을 정한다**

```bash
git fetch origin --quiet
git rev-list --count HEAD..origin/main
git show origin/main:plugins/quality-gates/.claude-plugin/plugin.json | grep '"version"'
```

  `origin/main` 이 움직였으면 **merge 한다**(rebase 금지): `git merge --no-edit origin/main`.
  - 충돌이 없어도 `plugin.json` · `CHANGELOG.md` · SKILL · `CLAUDE.md` 를 눈으로 본다.
  - 버전은 `origin/main` 의 qg minor + 1 에 `.0` 이다(오늘 9.2.0 → **9.3.0**).
  - 세 자리를 같은 값으로 맞춘다: `plugin.json` `"version"` · `skills/quality-pipeline/SKILL.md` 제목 · `skills/publishing-pr-understanding/SKILL.md` 제목의 `(vX.Y.Z)`.

- [ ] **Step 3: CHANGELOG** — `plugins/quality-gates/CHANGELOG.md` 의 `## [9.2.0] — 2026-09-27` **위**에 둔다(Korean-primary):

```markdown
## [<정한 버전>] — <오늘 날짜>

**공개 계약 · 헌장 정리** — qg 는 한 파이프라인이다. 두 게이트 · 런타임 검증 executor 를 전제하던 공개 문자열과 헌장 조항을 거두고, 헌장이 이름으로 박는 것이 실재하는지를 락으로 잠근다.

### Added
- `shared/tests/test_charter_citations.sh` — 헌장(`CLAUDE.md` + `docs/philosophy/*.md`)의 모양 인식 인용(경로 · 글롭 · 리포 플러그인 이름)이 실재하고, git 이력에서 사라진 agent · 스크립트 · 플러그인 이름이 헌장에 없음을 잰다(AC19). 공개 계약 설명 문자열 전체와 `runtime-verifier` · `2-gate` 부재도 잰다(AC20).
- `test_gate_era_prose_absent.sh` — qg 산문에 「Review gate」 · 「Runtime gate」 · 「2-gate」(대소문자 · 복수형 변형 포함)가 없다.

### Changed
- `marketplace.json` · `plugin.json` 의 qg 설명을 「one pipeline, one verdict (review + mandatory differential test)」로 바꾼다 — 「2-gate … (review + runtime)」은 사라진 런타임 게이트를 주장했다.
- `CLAUDE.md` Law 2 와 철학 문서에서 *Scoped exception (qg v2.2.0)* 을 지운다 — 그 조항이 이름으로 박던 `runtime-verifier` 는 9.0.0 에서 사라졌다. Law 2 는 예외 없는 원칙으로 돌아간다. 부팅되는 앱을 가진 설치본은 브라우저 플로우 검증 · spec AC 런타임 검증 · mutation guard 를 잃었다(9.0.0) — qg 는 그것을 대체하지 않고 주장을 거둔다.
- `security-reviewer` · `pr-understanding-builder` · `critiquing-artifacts` · `publishing-pr-understanding` 의 「Review gate」 · 「two-gate」 라벨을 한 파이프라인 이름으로 바꾼다(persona 는 라벨만 — 규칙 · 임계 · 도구 불변).
- ① 1a 의 `in_base` 공지가 「기준선에 포함됐다」 대신 「이번 판정 대상에서 빠졌다 — 자기 PR 에서 판정됐다」를 낸다 — 형제 구성원이 그 머지 전에 갈라졌으면 그 조각은 경계 트리에 없다.
- README 알려진 한계 — squash 로 든 앞 조각의 흡수는 사이 base 커밋이 다른 `Spec:` 키를 달았으면 `declaration-invalid` 로 막힌다는 조건을 적고, 로컬 전용 머지(push 전)와 fetch 전 원격 머지의 다른 결과를 가른다.

### Fixed
- `create-head --topic` 이 재도출에 실패해 죽을 때 `resolve` 의 사유를 함께 낸다(전에는 `status` 만).
```

- [ ] **Step 4: 커밋 · 최종 clone 회귀**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md
git status --short
git commit -m "chore(qg): quality-gates <정한 버전> — 공개 계약 · 헌장 정리" \
  -m "qg 설명 · 헌장 조항에서 두 게이트를 거두고 헌장 인용 락을 더한 릴리스." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr5
Co-Authored-By: <이 커밋을 쓴 실제 모델>"
bash "$CLAUDE_JOB_DIR/tmp/pr5-clone-suite.sh" final "$(git rev-parse HEAD)" > "$CLAUDE_JOB_DIR/tmp/pr5-v-final.out" 2>&1
```

  `$CLAUDE_JOB_DIR/tmp/pr5-join.sh` 로 기준선 clone 과 최종 clone 을 대조한다:

```bash
#!/usr/bin/env bash
T=/Users/jeonghokim/.claude/jobs/b6faa344/tmp
sort "$T/pr5-v-base.tsv" > "$T/pr5-b.s"; sort "$T/pr5-v-final.tsv" > "$T/pr5-f.s"
join -t "$(printf '\t')" -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 "$T/pr5-b.s" "$T/pr5-f.s" | awk -F'\t' '$2 != $4 || $3 != $5'
comm -13 "$T/pr5-v-base-harness-fails.txt" "$T/pr5-v-final-harness-fails.txt"
```

  **기대**
  - `pr5-v-final.out` 첫 줄 `access: yes`, 219 파일.
  - `join` 출력은 정확히 두 행이다: `plugins/quality-gates/tests/test_gate_era_prose_absent.sh MISSING MISSING 0 0` · `shared/tests/test_charter_citations.sh MISSING MISSING 0 0`. 기존 파일의 rc · 실패 줄 수는 하나도 안 바뀐다.
  - 기준선 쪽 플래키 파일(`test_codex_runner_degrade_contract.sh` · `shared/tests/test_docreview_round_gate_split.sh`)이 행을 내면, 단독 재실행 결과를 적고 회귀로 세지 않는다.
  - unittest `Ran 197` OK. `comm -13` 빈 출력.
  - `cp "$CLAUDE_JOB_DIR"/tmp/pr5-v-final* ~/.claude/sdd-mirror/qg-public-contract-pr5/`.

  push · PR 은 최종 리뷰 뒤 컨트롤러가 한다. PR 본문 절은 다음과 같다.
  - 요약.
  - **사용자가 뒤집을 수 있는 자리**:
    - AC19 도출 두 갈래와 그 건너뜀 — 한 단어 이름은 못 본다.
    - 철학 문서까지 코퍼스를 넓힘.
    - Law 2 예외 제거 — 설치본이 잃은 것.
  - 이 PR 이 지는 것 · 끝에서 끝 흐름 · 선재 RED(clone 기준) · 변이 표.
  - **수동 e2e**(`observations.md`) · 검증 과정(원장의 `Ruling:` 전부).
  - 마지막 줄 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

---

## 부채 원장 — 미룬 것은 전부 여기 이름이 있다

| 부채 | 소유자 | 무엇이 붙잡고 있는가 |
|---|---|---|
| 헌장의 한 단어 이름(예: `adversarial`)은 인용 락이 못 본다 | 후속 | 락 머리 주석 · 락 출력의 `건너뜀` 공시 |
| 헌장 인용 락은 `# guards:` 선택으로는 트리 삭제에 반응하지 않는다(스위트 전체 실행이 잡는다) | 후속 | 이 표 |
| 헌장의 리포 밖 플러그인 인용(`plugin-dev:…`) · 규약 글롭은 건너뛴다 — 그 자리의 오타(`quality-gate:…` 처럼 리포 이름을 틀린 것)는 공시 수만 바뀐다(모의 실행 W5) | 후속 | 락 출력의 `건너뛴 모양` 공시 |
| 백틱 · 링크 밖 산문의 경로 오타는 갈래 1 이 못 본다(설계대로 — 모양으로 인식되는 인용만) | 후속 | 설계 §6.5.4 |
| qg 스크립트 주석의 옛 게이트 문구(`synthesize_findings.py:516` `## Review gate: clean` — 과거 버그 서술)는 옛 게이트 락 코퍼스(산문 *.md) 밖이고 범위 불변식 밖 | 후속 | 이 표 |
| e2e 는 격리되지 않은 설치 환경에서 돈다(다른 devbrew 플러그인 훅이 함께 실림) | 후속 | `observations.md` 의 플러그인 목록 |
| squash · rebase-merge · cherry-pick 앞 조각 ref 가 남으면 옛 분기점 경계(N1 모양) — 코드 수준 완화(구성원 fork 가 다르면 경고) | 후속 | 설계 §15-12 · README |
| amend 뒤 낡은 upstream 이 형제(I4) · 리뷰어가 워킹트리 파일을 읽음(W3) · `resolve` 비용 | 후속(PR4c 그대로) | README 알려진 한계 |
| PR4c · PR4d Task 리뷰 Minor 들 | 후속 | PR #178 · #179 본문 · 미러 원장 |

---

## Self-Review

**1. 스펙 커버리지**
- §6.5.3 → Task 1 (c)(a)(b).
- §6.5.4 두 갈래 · 헌장 코퍼스 → Task 1 락.
- AC19 → Task 1. AC20 → Task 1. AC23 → Task 6 Step 1.
- §13 수동 e2e → Task 5.
- §15-12 정정의 README 반영 → Task 3 (c).
- §16 범위 기록의 셋:
  - qg 옛 문구 → Task 2.
  - PR4d 넘김 → Task 3. 공지 · README 세 곳 · die 사유이고, 설계 정정은 첫 커밋이 했다.
  - e2e → Task 5.

**2. 플레이스홀더** — 실행 시점 값이고 규칙이 적힌 것: `<정한 버전>` · `<오늘 날짜>` · `<이 커밋을 쓴 실제 모델>` · `<rev>`. SKILL 오케스트레이터 치환 자리인 것: `<topic_key>` · `<in_base>`.

**3. 이름 일관성**
- 락 이름: `test_charter_citations.sh` · `test_gate_era_prose_absent.sh`. Task 1 · 2 · 4 · 6 에서 같다.
- 새 케이스: `case_create_head_topic_names_resolve_reason`. Task 3 · 4 에서 같다.
- qg 설명 문자열: Task 1 Interfaces · Step 3 (c) · CHANGELOG 에서 같다.
- 공지 문구: Task 3 Interfaces · (a) · CHANGELOG 에서 같다.

**4. 코드 분기 × fixture** — 헌장 락은 판정 코어를 fixture 없이 실제 헌장에 건다. 분기마다 이빨을 증명하는 변이 행:
- 트리 못 읽음 → Row 5.
- 이력 못 읽음 · 얕음 · 축별 pathspec 파손 → Row 6 · 7 · 7b · 7c.
- 경로 없음 → Row 3. 글롭 오타 → Row 22. `경로:줄` 은 거짓 RED 가 아님 → 양의 대조 한 줄.
- 플러그인 멤버 없음 → Row 4.
- 사라진 이름 → Row 1 · 2. 무관한 docs 파일 · untracked 파일이 가리지 못함 → Row 18 · 19.
- AC20 → Row 9 · 20(복수형).
- 설명 불일치 · 부정 → Row 8 · 21.
- 하한 → Row 10.
- 옛 게이트 락의 대소문자 · 복수형 변형 → Row 23.
- 건너뛰는 모양 다섯은 공시 줄(`  · `)로 보인다. 이것이 오판하는 쪽은 과소 검사(공시)이지 거짓 RED 가 아니다. 그 대가는 부채 원장에 있다.

**5. Review Focus** — 다섯 줄의 증거가 소유 Task 에 있다:
- 1 → Task 4 Row 1 · 2.
- 2 → Row 3 · 4.
- 3 → Row 5 · 6.
- 4 → Row 8.
- 5 → Task 3 새 케이스.

---

## Execution Handoff

SDD 로 돌리면 구현은 sonnet, Task 리뷰와 최종 리뷰는 opus 다(이 리포에서는 사용자가 풀기 전까지 fable 을 쓰지 않는다).
- Task 2 리뷰에는 **persona 편집 = 보안 리뷰** 렌즈를 싣는다. 역할 라벨 외 바이트가 바뀌었는지 본다.
- Task 5 는 컨트롤러가 한다.
- 원장은 매 갱신마다 `~/.claude/sdd-mirror/qg-public-contract-pr5/` 로 복사한다.
- Task 리뷰에는 **plan-mandated** 라벨을 싣는다. 최종 리뷰는 「끝에서 끝 흐름」 표를 한 행씩 따라가게 한다.
