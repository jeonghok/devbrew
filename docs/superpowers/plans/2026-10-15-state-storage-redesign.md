# R7 상태 저장 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 진행 기록을 docs 의 추적 상태 파일로 옮기고, `.claude/spec-distill/` 에는 문서 단위 리뷰 원장(`.docreview/`)만 남기며, 세션 종료 · 시간 경과로 남의 기록을 지우는 훅과 TTL-GC 를 걷어 내고 문서 기준 정리 · 동시 리뷰 표지로 바꾼다.

**Architecture:** 경로 계산은 `state_path.py`(새 `interview-state`)와 공유 엔진 `docreview_state.py state-dir-for`(세션 칸 제거)에 둔다. 새 모듈 셋 — `interview_state.py`(진입 판정 · 옛 자리 이월 · seed audit 이름 되찾기), `ledger_marker.py`(동시 리뷰 표지), `ledger_sweep.py`(리뷰 진입 때의 원장 정리) — 이 새 책임을 맡고, SKILL · reference 는 그 스크립트를 부르는 리터럴 펜스와 판결 줄만 갖는다. SessionEnd 훅 · `spec-distill-gc.py` 는 지운다.

**Tech Stack:** Python 3.9(레포 `python3` 바닥) · PyYAML(엔진 원장 판독) · bash 3.2 호환 셸 펜스 · unittest · `shared/tests/assert.sh` 셸 테스트.

**Spec:** `docs/superpowers/specs/2026-10-15-state-storage-redesign-design.md` — 계획은 이 설계를 근거로 한다. 실행자는 두 문서를 함께 읽는다. 설계의 `## 결정 기록` 은 사용자 결정이라 다시 정하지 않는다.

## 목차

- [Global Constraints](#global-constraints) · [Review Focus](#review-focus) · [File Structure](#file-structure) · [Rulings](#이-계획이-정한-것rulings--설계가-열어-둔-자리)
- [Task 1](#task-1-state_pathpy-interview-state) · [Task 2](#task-2-interview_statepy--진입-판정--옛-자리-이월--seed-audit-이름-되찾기) · [Task 3](#task-3-엔진-state-dir-for-에서-세션을-뺀다--소비자-전부를-같은-커밋에서) · [Task 4](#task-4-ledger_markerpy--동시-리뷰-표지) · [Task 5](#task-5-ledger_sweeppy--리뷰-진입-때의-원장-정리) · [Task 6](#task-6-sessionend-훅--ttl-gc-제거)
- [Task 7](#task-7-리뷰-진입-배선--spec-review--reviewing-brief--finishing-b-a) · [Task 8](#task-8-request-framing--이름-파일-제거--원장-배선) · [Task 9](#task-9-spec-interview-의-인터뷰-상태-파일) · [Task 10](#task-10-공시--bump--레포-규칙) · [Task 11](#task-11-끝에서-끝--최종-대조) · [Self-Review 기록](#self-review-기록)

## Global Constraints

- 외부 플러그인(superpowers)은 건드리지 않는다(C25 · C35 · D26).
- 있는 것을 다시 만들지 않는다(C32) — 안전한 삭제는 `gc_common.py`(`gc_one` · `locked_root` · `root_escapes` · `safe_rmtree` · `ttl_ns`), 경로 해석은 `state_path.py`, 원장 판독은 엔진 `docreview_state.load_state` · `state_dir_for`, 상태 스키마 이월은 `state-migration.md` 를 그대로 쓴다.
- 파일을 지우는 장치는 끄기 스위치를 존중한다: `DEVBREW_SPEC_DISTILL_DISABLE=1` 과 `DEVBREW_SKIP_HOOKS` 의 `spec-distill:SessionEnd` · `spec-distill:session-end-cleanup` · `spec-distill:spec-distill-gc` 셋. 은퇴하는 이름은 없다.
- 엔진(`shared/docreview/`)의 동작은 `state-dir-for` 경로 함수 하나만 바꾼다(R2a 예약). 엔진은 표지를 모른다.
- 플러그인 bump: spec-distill **major**(5.5.0 → 6.0.0), quality-gates **patch**(13.0.2 → 13.0.3 — `plugins/quality-gates/scripts/docreview_state.py` 가 공유 엔진의 심볼릭 링크). 번호는 머지 직전에 다시 정할 수 있다(PR 본문에 적는다).
- 커밋: `type(scope): 한국어 설명`. 구현 커밋마다 trailer 세 줄:
  `Spec: docs/superpowers/specs/2026-10-15-state-storage-redesign-design.md` ·
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ·
  `Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX`.
  워크트리를 공유하므로 경로 지정 커밋(`git add -- <경로들>` 뒤 `git commit --only -- <경로들>` 또는 경로 지정 `git commit -- <경로들>`)을 쓰고 커밋 결과의 파일 수를 확인한다.
- 레포 락(새 스크립트 · 테스트가 걸리는 것):
  - `plugins/*/scripts/*.py` 의 `open(` · `.read_text(` · `.write_text(` 에 `encoding="utf-8"` 필수(`plugins/quality-gates/tests/test_utf8_explicit.py`, 주석의 글자도 걸린다).
  - `plugins/**/*.py` 에 `"python3"` 문자열 리터럴 금지 — 자식 파이썬은 `sys.executable`(`shared/tests/test_python_floor.sh`). 3.9 문법만.
  - `scripts/*.py` 의 `re.compile` 리터럴이 `## 6. 사용자 원문` 의 앞 세 글자 이상과 맞으면 RED(`test_check_brief.sh` §6단일화) — `^##\s` 같은 패턴을 쓰지 않는다.
  - 20줄(200자 이상) 같은 블록이 `plugins/*` · `shared/*` 두 파일에 있으면 RED(`shared/tests/test_no_new_duplication.sh`).
  - 비신뢰 문자열의 정규식 신원 검사는 `fullmatch` 로(Python `$` 는 끝 개행 앞에서도 맞는다).
  - 인라인 python 은 `python3 -I`, 스크립트 호출은 `-I` 없이.
  - 새 셸 테스트는 실행 비트(100755)로 커밋한다(`chmod +x` 뒤 `git add`, `git ls-files -s` 로 확인).
  - SKILL 본문에 `$1`·`$2` 꼴 위치 토큰을 쓰지 않는다(Skill 인자로 치환된다) — 셸 함수 인자는 이름 있는 변수로.
  - macOS bash 3.2: `"$var"` 바로 뒤에 한글 글자를 붙이지 않는다 — `"${var}"` 로.
- `spec-interview/SKILL.md` 자기 줄 수 상한 502(`test_conducting_interview_stage.sh` 의 `SKILL_LINE_CAP`, 규칙 블록 14줄 제외). 상한을 올리지 않는다.
- 테스트 실행은 레포 루트에서, `PYTHONDONTWRITEBYTECODE=1`. 파이썬 테스트는 `python3 -m unittest <파일>`.

## Review Focus

- 다른 세션이 죽어 남긴 빈 표지(`reviewing-by` 가 0바이트) — 사람은 「누가 쥐고 있는지 모른다」를 보고 「이어 씀」으로 풀 수 있어야 한다. `acquire`·`check` 는 rc 3, `takeover` 는 성공해야 한다(Task 4 테스트 `test_empty_marker_is_foreign`).
- 한글 · 공백이 든 문서 경로의 원장 — 정리가 기록된 경로를 그대로 읽어 문서가 있으면 남기고, 옮긴 원장 경로는 `state-dir-for` 와 같아야 한다(Task 5 `test_korean_doc_path_kept_and_migrated`).
- 끝내기 커밋에서 사용자가 이미 staged 해 둔 다른 파일 — 커밋에 섞이지 않고 staged 로 남아야 한다(Task 9 픽스처 `staged_other_stays_staged`).
- 인터뷰 주제에 대문자 · 밑줄 · 한글이 들어온 경우 — 경로를 내지 않고 rc 2 와 이유를 낸다(Task 1 `test_non_kebab_topic_rejected`).
- 옛 진행 기록을 옮길 자리에 이미 파일이 있는 경우 — 덮어쓰지 않고 옛 파일도 지우지 않는다(Task 2 `test_migrate_refuses_existing_target`).

---

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `plugins/spec-distill/scripts/state_path.py` | + `interview-state` 경로 계산 · `worktree_root` · `frontmatter_scalars` | 1 |
| `plugins/spec-distill/scripts/interview_state.py` (새) | 진입 판정(`entry`) · 옛 `state.local.md` 이월(`migrate-legacy`) · seed audit 이름 되찾기(`seed-audit-for-session`) | 2 |
| `shared/docreview/scripts/docreview_state.py` | `state-dir-for --root --doc` → `<root>/.docreview/<stem40>-<hash16>` | 3 |
| `shared/docreview/references/reviewing-document.md` | 선결 문장의 `state-dir-for` 꼴 | 3 |
| `plugins/spec-distill/scripts/ledger_marker.py` (새) | `acquire` · `check` · `release` · `takeover` · `resume-note` | 4 |
| `plugins/spec-distill/scripts/ledger_sweep.py` (새) | 문서 없는 원장 · 옛 세션 폴더 정리, 옛 원장 이월 | 5 |
| `plugins/spec-distill/hooks/` (삭제) · `scripts/spec-distill-gc.py` (삭제) · `scripts/hook_common.py` | 훅 · TTL-GC 제거, `_yaml_scalar` 만 남김 | 6 |
| `skills/spec-review/SKILL.md` · `skills/reviewing-brief/SKILL.md` · `skills/spec-interview/references/finishing.md`(B-A) | 원장 열기 펜스 · 쓰기 전 확인 · 끝맺음 해제 | 7 |
| `skills/request-framing/SKILL.md` | 이름 파일 제거 · audit `session_id` 로 이름 되찾기 · 원장 표지 배선 | 8 |
| `skills/spec-interview/SKILL.md` · 새 `references/state-file.md` · `finishing.md` · `state-migration.md` · `check_verbatim_coverage.py` · `templates/interview-audit-template.md` · reviewing-brief 의 `STATE` | 인터뷰 상태 파일 | 9 |
| README · CHANGELOG · 두 `plugin.json` · quality-gates CHANGELOG · 레포 `CLAUDE.md` | 공시 · bump | 10 |
| `plugins/spec-distill/tests/test_state_storage_e2e.sh` (새) | 끝에서 끝 | 11 |

Task 순서는 의존 순서다: 1 → 2(1 의 함수) → 3(엔진 시그니처, 소비자 전부 같은 커밋) → 4 → 5(3 의 `state_dir_for`) → 6(5 가 대신하는 것 제거) → 7 · 8(4 · 5) → 9(1 · 2 · 7) → 10 → 11.

## 이 계획이 정한 것(Rulings — 설계가 열어 둔 자리)

- **R-a `hooks/` 디렉토리째 지운다.** 설계는 「SessionEnd 항목을 지운다 · 설치되는 훅이 남지 않는다」이다. quality-gates v10.0.0 의 선례(훅을 다 지워 `hooks/` 자체가 없다)를 따른다. AC10 의 음의 락은 「`plugins/spec-distill/hooks/` 가 없다」로 잰다.
- **R-b 표지 해제는 「끝맺음 펜스」 셋이 한다.** 각 리뷰 자리의 마지막 원장 쓰기는 승인 게이트 1단계 답을 원장에 적은 뒤 도는 참고 목록(advice) 펜스다 — spec-review `<!-- advice-display -->`, spec-interview `finishing.md` B-A, request-framing 「계수 기록」. 이 셋은 `acquire` → `check` → advice → `release` 로 돈다. reviewing-brief 는 스스로 풀지 않는다 — 그 원장의 마지막 쓰기는 Step B 의 B-A 이기 때문이다. 게이트 없이 끝나는 출구(대상 부재)는 해제 펜스 `<!-- ledger-release -->` 를 돈다.
- **R-c 원장 열기 펜스가 정리를 부른다.** `acquire` 가 새로 잡았을 때(`acquired`)만 `ledger_sweep.py` 를 부른다 — 같은 세션의 다음 라운드(`held`)에서는 다시 부르지 않는다(「원장 경로를 연 직후 한 번」).
- **R-d 이어 감 줄의 조건에 「표지가 이미 이 세션 것이 아니다」를 더한다.** 설계 조건(라운드 ≥ 1 이고 `last-session` 이 없거나 다름)만으로는 첫 해제 전의 같은 세션 2·3 라운드에서 줄이 반복된다. 설계의 의도(「같은 세션 안의 다음 라운드에서는 나오지 않는다」)를 지키려고 `resume-note` 는 표지가 이미 부른 세션의 것이면 줄을 내지 않는다.
- **R-e 문서를 모르는 codex 잔존물 쓸기를 걷는다.** spec-review · reviewing-brief · request-framing 의 codex 펜스는 문서 경로를 모르면 `"$ROOT/$sid"/docreview/*/docreview-codex.yaml` 전부를 지웠다. 원장이 세션 밖(`.docreview/`)으로 나가면 그 글롭은 **다른 세션이 리뷰 중인 문서**의 codex 판정을 지운다. 문서를 모르면 그 라운드는 `init` 이 `state_dir_missing` 으로 멈추고 codex 축도 건너뛰므로, 쓸 것이 없다 — 그 분기를 걷는다.
- **R-f 진입 판정은 스크립트가 한다.** 설계 §1-4 · §1-7 의 분기(이어 감 · 질문 · 옛 자리 이월 · 새로 만듦)를 산문 조건으로 두지 않고 `interview_state.py entry` 의 마지막 줄 판결(`interview-state: RESUME|ASK|LEGACY|NEW-SEED|NEW|REJECT`)로 낸다. SKILL 은 판결 표만 갖는다.
- **R-g 옛 GC 검증은 git 의 고정 커밋에서 옛 파일을 꺼낸다.** AC6 픽스처는 `git show 9b7a5e07:plugins/spec-distill/scripts/spec-distill-gc.py`(이 브랜치의 base, main HEAD)를 임시 디렉토리에 풀고 현재의 `state_path.py` · `gc_common.py` · `kill_switch_active.py` 를 옆에 둔다. 커밋이 닿지 않으면 사유를 대고 RED 다(도출 불가 = fail-closed).
- **R-h 커밋 메시지 꼴.** 끝내기 커밋은 `docs(interview): <줄기> brief · audit · 상태 기록` 이다(`<줄기>` = brief 파일 이름에서 `.md` 를 뗀 것).

---

### Task 1: `state_path.py interview-state`

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py`
- Test: `plugins/spec-distill/tests/test_state_path.sh` (케이스 추가)

**Interfaces:**
- Produces:
  - `KEBAB: re.Pattern` — `^[a-z0-9]+(?:-[a-z0-9]+)*$` (`fullmatch` 로만 쓴다)
  - `worktree_root(cwd: str | None = None) -> tuple[Path, bool]` — `(git rev-parse --show-toplevel 결과, True)`, git 이 아니면 `(Path(cwd).resolve(), False)`
  - `frontmatter_scalars(path) -> dict | None` — 맨 앞 `---` 블록의 최상위 `key: value`. 읽지 못하면 `None`, frontmatter 가 없으면 `{}`
  - `interview_state_path(topic: str, date: str | None = None, cwd: str | None = None) -> tuple[Path | None, list[str]]` — 성공이면 `(상태 파일 경로, stderr 줄들)`, 거부면 `(None, stderr 줄들)`
  - CLI `state_path.py interview-state --topic <kebab> [--date YYYY-MM-DD] [--cwd <dir>]` — stdout 경로 rc 0 / 거부 rc 2

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_state_path.sh` 끝(마지막 요약 줄 앞)에 붙인다:

```bash
# ── interview-state (R7 §1-2 · AC1) ─────────────────────────────────────────
IV="$WORK/iv-repo"; mkdir -p "$IV" && git -C "$IV" init -q
mkdir -p "$IV/docs/superpowers/interview"
got=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$got" "$IV/docs/superpowers/interview/2026-10-15-t-interview.state.md" "AC1: interview-state 가 작업 트리 루트 아래 상태 경로를 낸다"
assert_eq "$rc" "0" "AC1: rc 0"
for bad in T t_x 한글 "t x" "-t" "t-" ""; do
  python3 "$HELPER" interview-state --topic "$bad" --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC1: kebab 아닌 topic '${bad}' 은 exit 2"
done
python3 "$HELPER" interview-state --topic t --date 2026-1-5 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: 날짜 꼴이 아니면 exit 2"
# 같은 날 seed · seed audit 와의 겹침 — 세 자리 각각
put_type() { printf -- '---\ntype: %s\n---\nbody\n' "$2" > "$1"; }
D="$IV/docs/superpowers/interview"
put_type "$D/2026-10-15-t-interview.md" interview-seed
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "AC1: brief 자리에 seed 가 있으면 exit 2"
assert_contains "$out" "type: interview-seed" "AC1: 거부 사유가 그 파일의 type 을 댄다"
got=$(python3 "$HELPER" interview-state --topic t-brief --date 2026-10-15 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$got" "$D/2026-10-15-t-brief-interview.state.md" "AC1: --topic t-brief 는 seed 와 겹치지 않는 경로를 낸다"
rm -f "$D/2026-10-15-t-interview.md"
put_type "$D/2026-10-15-t-interview.audit.md" interview-seed-audit
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: audit 자리에 seed audit 가 있으면 exit 2"
rm -f "$D/2026-10-15-t-interview.audit.md"
printf 'no frontmatter\n' > "$D/2026-10-15-t-interview.state.md"
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: 상태 자리에 type 없는 파일이 있으면 exit 2"
# 양성 대조 — 세 자리에 제 종류가 있으면 통과
put_type "$D/2026-10-15-t-interview.state.md" interview-state
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-interview.audit.md" interview-audit
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "AC1 양성 대조: 세 자리가 제 종류면 rc 0"
# git 이 아니면 --cwd 기준 + stderr 한 줄
NG="$WORK/iv-nogit"; mkdir -p "$NG"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>&1 >/dev/null)
got=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>/dev/null)
assert_eq "$got" "$NG/docs/superpowers/interview/2026-10-15-t-interview.state.md" "§1-2: git 이 아니면 --cwd 기준 경로"
assert_contains "$out" "git 저장소가 아니다" "§1-2: git 이 아니면 그 사실을 stderr 로 낸다"
```

`assert.sh` 에 `assert_contains` 가 없으면 `grep -qF` 꼴의 `ok`/`no` 로 쓴다(먼저 `grep -n 'assert_contains' shared/tests/assert.sh` 로 확인).

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_state_path.sh 2>&1 | grep -E '✗|Total'`
Expected: AC1 줄들이 `✗` (unknown subcommand 로 rc 2 · 빈 stdout).

- [ ] **Step 3: 구현한다** — `state_path.py` 의 docstring CLI 목록에 한 줄을 더하고, import 에 `import datetime` 을 더한 뒤 `state_root` 아래에 붙인다:

```python
KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
INTERVIEW_DIR = ("docs", "superpowers", "interview")
# 한 인터뷰의 세 자리와 각 자리가 받아들이는 frontmatter `type:`.
_SLOTS = ((".state.md", "interview-state"), (".md", "interview-brief"), (".audit.md", "interview-audit"))


def worktree_root(cwd: str | None = None) -> tuple[Path, bool]:
    """(작업 트리 루트, git 인가). 메인 레포가 아니라 이 cwd 가 속한 worktree 의 루트다."""
    cwd = cwd or os.getcwd()
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, text=True, timeout=5, check=False,
        )
        if cp.returncode == 0 and cp.stdout.strip():
            return Path(cp.stdout.strip()), True
    except (subprocess.TimeoutExpired, OSError):
        pass
    return Path(cwd).resolve(), False


def frontmatter_scalars(path) -> dict | None:
    """맨 앞 `---` 블록의 최상위 `key: value` 줄. 읽지 못하면 None, frontmatter 가 없으면 {}."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    if not text.startswith("---\n"):
        return {}
    out = {}
    for line in text[4:].splitlines():
        if line.strip() == "---":
            break
        if not line or line[0] in " \t#-" or ":" not in line:
            continue
        key, val = line.split(":", 1)
        out[key.strip()] = val.strip().strip('"').strip("'")
    return out


def interview_state_path(topic: str, date: str | None = None,
                         cwd: str | None = None) -> tuple[Path | None, list[str]]:
    """`<작업 트리 루트>/docs/superpowers/interview/<날짜>-<topic>-interview.state.md`.

    계산한 세 자리(상태 · brief · audit) 중 이미 있는 파일의 `type:` 이 그 자리의 종류와 다르면
    경로를 내지 않는다 — seed(`interview-seed`) · seed audit(`interview-seed-audit`) 위에 인터뷰를 시작하지 않는다.
    """
    msgs: list[str] = []
    if not topic or not KEBAB.fullmatch(topic):
        return None, ["[spec-distill] topic 이 kebab-case 가 아니다: {0!r}".format(topic)]
    date = date or datetime.date.today().isoformat()
    if not _DATE.fullmatch(date):
        return None, ["[spec-distill] 날짜가 YYYY-MM-DD 가 아니다: {0!r}".format(date)]
    root, is_git = worktree_root(cwd)
    if not is_git:
        msgs.append("[spec-distill] git 저장소가 아니다 — {0} 기준으로 경로를 냈다".format(root))
    d = root.joinpath(*INTERVIEW_DIR)
    stem = "{0}-{1}-interview".format(date, topic)
    for suffix, kind in _SLOTS:
        p = d / (stem + suffix)
        if not (p.exists() or p.is_symlink()):
            continue
        fm = frontmatter_scalars(p)
        have = None if fm is None else fm.get("type")
        if have != kind:
            msgs.append("[spec-distill] 계산한 자리에 다른 종류의 파일이 있다 — {0} (type: {1}). "
                        "남의 파일 위에 인터뷰를 시작하지 않는다.".format(p, have or "없음"))
            return None, msgs
    return d / (stem + ".state.md"), msgs
```

`main` 의 `print(f"unknown subcommand…")` 앞에 분기를 더한다:

```python
    if sub == "interview-state":
        def opt(name):
            if name in argv:
                i = argv.index(name)
                if i + 1 < len(argv):
                    return argv[i + 1]
            return None
        path, msgs = interview_state_path(opt("--topic") or "", opt("--date"), opt("--cwd"))
        for m in msgs:
            print(m, file=sys.stderr)
        if path is None:
            return 2
        print(str(path))
        return 0
```

usage 줄을 `usage: state_path.py {state-root|session-id|interview-state} …` 로 고친다.

- [ ] **Step 4: 통과를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash plugins/spec-distill/tests/test_state_path.sh 2>&1 | grep -E '✗|Total'` → `✗` 없음.
Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` → OK.
Run: `bash shared/tests/test_python_floor.sh 2>&1 | tail -2` · `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -E '✗|Total'` → 새 `✗` 없음.

- [ ] **Step 5: 커밋한다**

```bash
git add -- plugins/spec-distill/scripts/state_path.py plugins/spec-distill/tests/test_state_path.sh
git commit --only -m "feat(spec-distill): 인터뷰 상태 파일 경로를 state_path.py interview-state 로 낸다" -m "Spec: docs/superpowers/specs/2026-10-15-state-storage-redesign-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01XKSh1VvN6kYTmLJS675MgX" -- plugins/spec-distill/scripts/state_path.py plugins/spec-distill/tests/test_state_path.sh
```

---

### Task 2: `interview_state.py` — 진입 판정 · 옛 자리 이월 · seed audit 이름 되찾기

**Files:**
- Create: `plugins/spec-distill/scripts/interview_state.py`
- Test: `plugins/spec-distill/tests/test_interview_state.py`

**Interfaces:**
- Consumes (Task 1): `worktree_root`, `frontmatter_scalars`, `interview_state_path`, `KEBAB`; 기존 `state_root`, `SESSION_PATTERN`.
- Produces (CLI, 판결은 **stdout 마지막 줄**):
  - `interview_state.py entry --arg <경로|""> --session <sid> [--cwd <dir>]`
    - `.state.md` 로 끝나고 `type: interview-state` → `interview-state: RESUME <절대경로>` rc 0
    - `.state.md` 로 끝나는데 종류가 다름 → `interview-state: REJECT <경로> (type: <값|없음>)` rc 2
    - 현재 세션의 옛 `<state-root>/<sid>/state.local.md` 가 있음 → `interview-state: LEGACY <옛 경로>` rc 0
    - seed(`type: interview-seed`)이고 같은 디렉토리에 `seed:` 가 그 seed 를 가리키고 짝 brief 가 없는 상태 파일이 있음 → 후보마다 `candidate: <절대경로>` 줄, 마지막 줄 `interview-state: ASK` rc 0
    - seed 이고 후보 없음, 이름이 `<날짜>-<주제>-interview.md` → `interview-state: NEW-SEED <주제>-brief seed=<작업 트리 루트 기준 상대경로>` rc 0
    - 그 밖 → `interview-state: NEW` rc 0 (seed 인데 이름에서 주제를 못 떼면 stderr 한 줄)
  - `interview_state.py migrate-legacy --session <sid> --topic <kebab> [--seed <경로>] [--date D] [--cwd <dir>]` — 옛 파일을 `interview_state_path` 자리로 옮긴다(frontmatter 맨 앞에 `type: interview-state` · `seed:` 를 더함, 원자적 쓰기 뒤 옛 파일 삭제). stdout `[spec-distill] 옛 위치의 진행 기록을 docs 로 옮겼다 — <경로>` rc 0 · 옛 파일 없음 rc 1 · 자리 거부 · 대상이 이미 있음 rc 2(아무것도 바꾸지 않는다)
  - `interview_state.py seed-audit-for-session --session <sid> [--cwd <dir>]` — `docs/superpowers/interview/*-interview.audit.md` 중 `type: interview-seed-audit` 이고 `session_id` 가 그 세션인 파일 하나 → stdout `<이름 줄기>`(파일 이름에서 `.audit.md` 를 뗀 것) rc 0 · 없음 rc 1 · 둘 이상 rc 2(stderr 에 경로들)
  - `seed_rel(seed: str) -> str` — seed 의 realpath 를 그 seed 가 속한 작업 트리 루트 기준 상대경로로

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_interview_state.py`:

```python
"""R7 §1-4 · §1-7 · §2-5 — interview_state.py (AC3 · AC4 · AC11 · AC12 의 스크립트 쪽)."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "interview_state.py"
SID = "sess-aaaa1111"


def run(*args, cwd=None, env_extra=None):
    env = {k: v for k, v in os.environ.items()
           if k not in ("DEVBREW_SPEC_DISTILL_SESSION_ID", "CLAUDE_CODE_SESSION_ID")}
    env.update(env_extra or {})
    cp = subprocess.run([sys.executable, str(SCRIPT), *args], cwd=cwd, env=env,
                        capture_output=True, text=True, timeout=20)
    return cp.returncode, cp.stdout, cp.stderr


def last(out):
    lines = [l for l in out.splitlines() if l.strip()]
    return lines[-1] if lines else ""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.iv = self.tmp / "docs" / "superpowers" / "interview"
        self.iv.mkdir(parents=True)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def put(self, name, typ, extra=""):
        p = self.iv / name
        p.write_text("---\ntype: %s\n%s---\nbody\n" % (typ, extra), encoding="utf-8")
        return p


class EntryTest(Base):
    def test_resume_on_state_file(self):
        p = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "interview-state: RESUME %s" % p)

    def test_reject_state_named_other_kind(self):
        p = self.put("2026-10-15-t-interview.state.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("interview-state: REJECT "))

    def test_new_seed_topic_gets_brief_tail(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "interview-state: NEW-SEED t-brief seed=docs/superpowers/interview/2026-10-15-t-interview.md")

    def test_ask_when_unfinished_state_points_at_seed(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "interview-state: ASK")
        self.assertIn("candidate: %s" % st, out)

    def test_finished_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        self.put("2026-10-15-t-brief-interview.md", "interview-brief")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED "))

    def test_other_seed_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-u-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-14-u-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED "))

    def test_rough_request_is_new(self):
        rc, out, _ = run("entry", "--arg", "", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (0, "interview-state: NEW"))

    def test_legacy_wins_over_seed(self):
        legacy = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        legacy.parent.mkdir(parents=True)
        legacy.write_text("---\nsession_id: x\n---\n## R1\n", encoding="utf-8")
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "interview-state: LEGACY %s" % legacy)


class MigrateTest(Base):
    def legacy(self):
        p = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        p.parent.mkdir(parents=True)
        p.write_text("---\nsession_id: x\nphase: 1\n---\n## R1\n기록\n", encoding="utf-8")
        return p

    def test_migrate_moves_and_prepends_keys(self):
        old = self.legacy()
        rc, out, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        new = self.iv / "2026-10-15-t-interview.state.md"
        self.assertEqual(rc, 0)
        self.assertIn("옛 위치의 진행 기록을 docs 로 옮겼다 — %s" % new, out)
        self.assertFalse(old.exists())
        text = new.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: interview-state\nseed: 없음\nsession_id: x\n"))
        self.assertIn("## R1\n기록\n", text)

    def test_migrate_refuses_existing_target(self):
        old = self.legacy()
        tgt = self.put("2026-10-15-t-interview.state.md", "interview-state")
        before = tgt.read_bytes()
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(old.exists())
        self.assertEqual(tgt.read_bytes(), before)

    def test_migrate_without_legacy_is_rc1(self):
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", cwd=self.tmp)
        self.assertEqual(rc, 1)


class SeedAuditTest(Base):
    def test_one_match(self):
        self.put("2026-10-15-t-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-interview"))

    def test_interview_audit_of_same_session_is_ignored(self):
        self.put("2026-10-15-t-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        self.put("2026-10-15-t-brief-interview.audit.md", "interview-audit", "session_id: %s\n" % SID)
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-interview"))

    def test_none(self):
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))

    def test_two_is_rc2(self):
        self.put("2026-10-15-a-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        self.put("2026-10-15-b-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        rc, _, err = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertIn("2026-10-15-a-interview.audit.md", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_interview_state.py 2>&1 | tail -3` → 모든 케이스 FAIL/ERROR(스크립트 없음).

- [ ] **Step 3: 구현한다** — `plugins/spec-distill/scripts/interview_state.py`:

```python
#!/usr/bin/env python3
"""spec-distill — 인터뷰 상태 파일(`<줄기>-interview.state.md`)의 진입 판정 · 옛 자리 이월 · seed audit 이름 되찾기.

CLI (판결은 stdout 마지막 줄):
  interview_state.py entry --arg <경로|""> --session <sid> [--cwd <dir>]
  interview_state.py migrate-legacy --session <sid> --topic <kebab> [--seed <경로>] [--date D] [--cwd <dir>]
  interview_state.py seed-audit-for-session --session <sid> [--cwd <dir>]
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import (  # noqa: E402
    INTERVIEW_DIR, SESSION_PATTERN, frontmatter_scalars, interview_state_path, state_root, worktree_root,
)

LEGACY_NAME = "state.local.md"
_SEED_NAME = re.compile(r"\d{4}-\d{2}-\d{2}-([a-z0-9]+(?:-[a-z0-9]+)*)-interview\.md")


def seed_rel(seed: str) -> str:
    real = os.path.realpath(seed)
    root, _ = worktree_root(os.path.dirname(real))
    return os.path.relpath(real, os.path.realpath(str(root)))


def legacy_state(sid: str, cwd: str | None) -> Path | None:
    if not sid or not SESSION_PATTERN.fullmatch(sid):
        return None
    p = state_root(cwd) / sid / LEGACY_NAME
    return p if p.is_file() else None


def resume_candidates(seed: str) -> list[Path]:
    want = seed_rel(seed)
    out = []
    for p in sorted(Path(os.path.realpath(seed)).parent.glob("*-interview.state.md")):
        fm = frontmatter_scalars(p) or {}
        if fm.get("type") != "interview-state" or fm.get("seed") != want:
            continue
        if p.with_name(p.name[:-len(".state.md")] + ".md").exists():
            continue
        out.append(p)
    return out


def cmd_entry(a) -> int:
    arg = a.arg or ""
    if arg.endswith(".state.md"):
        fm = frontmatter_scalars(arg)
        have = None if fm is None else fm.get("type")
        if have != "interview-state":
            print("interview-state: REJECT {0} (type: {1})".format(arg, have or "없음"))
            return 2
        print("interview-state: RESUME {0}".format(os.path.realpath(arg)))
        return 0
    leg = legacy_state(a.session, a.cwd)
    if leg is not None:
        print("interview-state: LEGACY {0}".format(leg))
        return 0
    if arg and (frontmatter_scalars(arg) or {}).get("type") == "interview-seed":
        cands = resume_candidates(arg)
        if cands:
            for c in cands:
                print("candidate: {0}".format(c))
            print("interview-state: ASK")
            return 0
        m = _SEED_NAME.fullmatch(os.path.basename(arg))
        if m:
            print("interview-state: NEW-SEED {0}-brief seed={1}".format(m.group(1), seed_rel(arg)))
            return 0
        print("[spec-distill] seed 이름에서 주제를 떼지 못했다 — 첫 라운드에서 정한다: {0}".format(arg),
              file=sys.stderr)
    print("interview-state: NEW")
    return 0


def cmd_migrate(a) -> int:
    leg = legacy_state(a.session, a.cwd)
    if leg is None:
        print("[spec-distill] 옮길 옛 진행 기록이 없다", file=sys.stderr)
        return 1
    path, msgs = interview_state_path(a.topic, a.date, a.cwd)
    for m in msgs:
        print(m, file=sys.stderr)
    if path is None:
        return 2
    if path.exists() or path.is_symlink():
        print("[spec-distill] 옮길 자리에 이미 파일이 있다 — {0}. 덮어쓰지 않는다.".format(path), file=sys.stderr)
        return 2
    text = leg.read_text(encoding="utf-8")
    head = "type: interview-state\nseed: {0}\n".format(seed_rel(a.seed) if a.seed else "없음")
    new = "---\n" + head + text[4:] if text.startswith("---\n") else "---\n" + head + "---\n" + text
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text(new, encoding="utf-8")
    os.replace(str(tmp), str(path))
    leg.unlink()
    print("[spec-distill] 옛 위치의 진행 기록을 docs 로 옮겼다 — {0}".format(path))
    return 0


def cmd_seed_audit(a) -> int:
    root, _ = worktree_root(a.cwd)
    d = root.joinpath(*INTERVIEW_DIR)
    hits = []
    for p in sorted(d.glob("*-interview.audit.md")):
        fm = frontmatter_scalars(p) or {}
        if fm.get("type") == "interview-seed-audit" and fm.get("session_id") == a.session:
            hits.append(p)
    if not hits:
        return 1
    if len(hits) > 1:
        print("[spec-distill] 이 세션의 seed audit 이 둘 이상이다 — 이름을 고르지 않고 멈춘다:", file=sys.stderr)
        for h in hits:
            print("  {0}".format(h), file=sys.stderr)
        return 2
    print(hits[0].name[:-len(".audit.md")])
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="interview_state.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("entry")
    x.add_argument("--arg", default="")
    x.add_argument("--session", default="")
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_entry)
    x = sp.add_parser("migrate-legacy")
    x.add_argument("--session", required=True)
    x.add_argument("--topic", required=True)
    x.add_argument("--seed", default=None)
    x.add_argument("--date", default=None)
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_migrate)
    x = sp.add_parser("seed-audit-for-session")
    x.add_argument("--session", required=True)
    x.add_argument("--cwd", default=None)
    x.set_defaults(fn=cmd_seed_audit)
    a = p.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
```

이 파일은 옛 이름 `state.local.md` 를 쥔다 — §1-7 이월 코드라서다(AC2 허용 목록, Task 9).

- [ ] **Step 4: 통과를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_interview_state.py` → OK.
Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh 2>&1 | tail -1` · `bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -1` · `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -E '✗|Total'` → 새 실패 없음.

- [ ] **Step 5: 커밋한다** (Task 1 과 같은 꼴, 경로 둘, 메시지 `feat(spec-distill): 인터뷰 상태 파일의 진입 판정과 옛 자리 이월을 interview_state.py 로 둔다`)

---

### Task 3: 엔진 `state-dir-for` 에서 세션을 뺀다 — 소비자 전부를 같은 커밋에서

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`STATE_SUBDIR` · `state_dir_for` · `cmd_state_dir_for` · parser · 머리 docstring 의 `state.local.md` 문장과 `state-dir-for` 설명)
- Modify: `shared/docreview/references/reviewing-document.md` (12행 선결 문장)
- Modify: 펜스 — `plugins/spec-distill/skills/spec-review/SKILL.md`(`## 입력` · codex 펜스 · dispatch 펜스 · advice-display 펜스), `skills/reviewing-brief/SKILL.md`(머리 블록 전부 · codex 펜스), `skills/request-framing/SKILL.md`(`## 상태` 블록 · codex 펜스), `skills/spec-interview/references/finishing.md`(B-A 펜스) — 모든 `state-dir-for … --session "<x>"` 에서 `--session "<x>"` 를 뺀다
- Modify: R-e — 문서를 모르는 codex 잔존물 쓸기 분기를 걷는다(spec-review `elif [ -n "${harness_sid:-}" ] && [ -n "${ROOT:-}" ]; then for y in "$ROOT/$harness_sid"/docreview/*/docreview-codex.yaml …` 와 reviewing-brief · request-framing 의 같은 꼴)
- Modify(테스트): `shared/tests/fixtures/docreview/cases.sh` · `cases_advice.sh` · `shared/tests/test_docreview_state.sh` · `test_docreview_mutations.sh`(59) · spec-distill `test_reviewing_spec_entry_fence.sh` · `test_reviewing_spec_state_keying.sh` · `test_reviewing_spec_residue.sh` · `test_reviewing_brief_residue.sh` · `test_reviewing_brief_skill.sh` · `test_dispatch_profile_inline.sh` · `test_seed_gate_wiring.sh` · `test_review_hook_removed.py`(445행 단언 문자열) 및 아래 Step 1 의 grep 이 내는 나머지

**Interfaces:**
- Produces: `state_dir_for(root, doc) -> Path` = `Path(root) / ".docreview" / "<label40>-<sha256(realpath)[:16]>"`; `STATE_SUBDIR = ".docreview"`; CLI `docreview_state.py state-dir-for --root <절대> --doc <절대>` (`--session` 을 주면 argparse 가 exit 2).
- 펜스의 새 꼴(리터럴, 세 자리 공통):
  `STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "${spec_path:-}" || true)"` (reviewing-brief 는 `$PR` · `"${PAYLOAD:-}"`, request-framing 은 `"$SEED_ABS"`, finishing 은 `"$PAYLOAD"`)

- [ ] **Step 1: 소비자를 전수로 센다(계획 시점 목록을 믿지 않는다)**

Run:
```bash
git grep -n 'state-dir-for' -- plugins shared tools ':!*/CHANGELOG.md'
git grep -nE '"?\$ROOT/\$(harness_sid|sid)"?/docreview|<state-root>/<sid>/docreview|/<sid>/docreview|session_invalid|_SESSION_OK' -- plugins shared ':!*/CHANGELOG.md'
```
나온 파일 전부를 이 Task 의 수정 목록으로 삼는다. 결과를 SDD ledger 에 적는다.

- [ ] **Step 2: 실패하는 테스트를 쓴다** — `cases.sh` 의 `state-dir-for` 케이스(2219행 근처 `# ── 상태 디렉토리의 문서 정체 — init 거부 · state-dir-for`)를 새 꼴로 바꾼다: 모든 `--session sess0001` 을 지우고, 세션 관련 거부 케이스(빈 세션 · 개행 세션 · `..` 세션 · `a_B-9`)는 다음 두 케이스로 바꾼다:

```bash
  # --session 은 더는 받지 않는다 — argparse 가 거부한다(exit 2)
  py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$FX/design-sample.md" >"$w/o2" 2>"$w/e2"; rc=$?
  [ "$rc" -eq 2 ] && [ ! -s "$w/o2" ] || bad "state-dir-for 가 --session 을 받았다(rc=$rc)"
  # 경로 꼴 — <root>/.docreview/<label>-<hash16>, 세션 칸이 없다
  case "$a1" in "$w/root/.docreview/design-sample-"????????????????) : ;; *) bad "state-dir-for 의 꼴이 <root>/.docreview/<label>-<hash16> 이 아니다: $a1" ;; esac
```

(`bad` 는 그 파일이 이미 쓰는 실패 보고 함수의 실제 이름으로 바꾼다 — 파일의 기존 케이스를 읽고 같은 관용구를 쓴다.)

그 밖의 소비자 테스트에서 기대 경로 `<state root>/<sid>/docreview/<문서별>` 을 `<state root>/.docreview/<문서별>` 로, 펜스 리터럴 단언의 `--session "$harness_sid" ` · `--session "$sid" ` 를 지운다. `test_reviewing_spec_entry_fence.sh` 의 「한 세션의 두 문서가 다른 값을 받는다」는 「두 문서가 다른 값, 같은 문서는 세션이 달라도 같은 값」으로 바꾼다(세션 id 를 둘로 돌려 같은 값을 단언 — 문서 단위 원장의 핵심).

- [ ] **Step 3: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 bash shared/tests/test_docreview_state.sh 2>&1 | grep -E '✗|Total'` · `bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 2>&1 | grep -E '✗|Total'` → 새 단언이 `✗`.

- [ ] **Step 4: 엔진을 고친다**

```python
STATE_SUBDIR = ".docreview"
_KEY_UNSAFE = re.compile(r"[^A-Za-z0-9._-]+")


def state_dir_for(root, doc) -> Path:
    """`<root>/.docreview/<이름표>-<정체 해시 16자>` — 문서 경로의 순수 함수(세션과 무관).
    이름표는 사람이 읽으라고 붙인 파일 stem 이고 유일성은 해시가 진다. 루트 이름이 점으로 시작하는 것은
    옛 정리 코드의 세션 이름 정규식(`^[A-Za-z0-9_-]{8,}$`) 밖에 두기 위해서다."""
    ident = doc_identity(doc)
    label = _KEY_UNSAFE.sub("-", Path(ident).stem).strip("-.")[:40] or "doc"
    digest = hashlib.sha256(os.fsencode(ident)).hexdigest()[:16]
    return Path(root) / STATE_SUBDIR / ("%s-%s" % (label, digest))


def cmd_state_dir_for(a) -> int:
    # 상대 루트·상대 문서는 cwd 의 함수다(같은 문서가 cwd 마다 다른 자리로 간다) — 거부한다.
    if not a.root or not os.path.isabs(a.root):
        return fail("root_not_absolute", root=a.root)
    if not a.doc:
        return fail("doc_empty")
    if not os.path.isabs(a.doc):
        return fail("doc_not_absolute", doc=a.doc)
    print(state_dir_for(a.root, a.doc))
    return 0
```

parser: `x = sp.add_parser("state-dir-for"); x.add_argument("--root", required=True); x.add_argument("--doc", required=True)`. `_SESSION_OK` 의 다른 사용처가 없으면 지운다(`grep -n _SESSION_OK`). 머리 docstring: 7행의 `` `state.local.md` 는 건드리지 않는다 — 그 파일은 brief 파이프라인의 줄 파서가 소유한다. `` → `인터뷰 상태 파일은 건드리지 않는다 — 그 파일은 brief 파이프라인의 줄 파서가 소유한다.`, 15행 `state-dir-for 가 세션 디렉토리와 문서 경로에서` → `state-dir-for 가 상태 루트와 문서 경로에서`.

`reviewing-document.md` 12행: `` `docreview_state.py state-dir-for --root <상태 루트> --session <세션 id> --doc <doc>` 가 세션과 문서 경로의 순수 함수로 `` → `` `docreview_state.py state-dir-for --root <상태 루트> --doc <doc>` 가 문서 경로의 순수 함수로(세션과 무관 — 같은 문서는 세션을 넘어 같은 원장을 쓴다) ``.

- [ ] **Step 5: 펜스를 고친다** — Step 1 목록의 모든 펜스에서 `--session "$harness_sid" ` / `--session "$sid" ` 를 지운다. 펜스 옆 산문의 「세션과 문서 경로의 순수 함수」 · 「`<state-root>/<sid>/docreview/<stem>-<해시>`」 를 「문서 경로의 순수 함수」 · 「`<state-root>/.docreview/<stem>-<해시>`」 로 고친다. request-framing `## 상태` 블록의 `[ -z "$sid" ] || STATE_DIR=…` 은 `STATE_DIR=…` 로(세션 가드는 Task 8 의 원장 열기 펜스가 진다). 표 「`$SEED_DIR/docreview/<seed 이름>-<해시>/`」 → 「`<state-root>/.docreview/<seed 이름>-<해시>/`」.

R-e: spec-review codex 펜스의 잔존물 분기를

```bash
if [ -n "${CODEX_YAML:-}" ]; then
  NEUTRALISE_TARGET="$CODEX_YAML"; neutralise || { residue_unclear=1; residue_left="$CODEX_YAML"; }
fi
```

로 줄이고, 바로 위 주석의 「**문서를 모르면** … 전부 같은 규칙으로 중화한다 … 게이트 입력 부재도 …」 문단과 「**전제: 한 세션은 리뷰 라운드를 동시에 둘 돌리지 않는다.** sweep 은 …」 문단을 다음 세 줄로 바꾼다:

```bash
# **문서를 모르면**(`$spec_path` 가 비어 경로를 도출하지 못했다) 지울 것이 없다 — 원장은 문서 단위라 세션을 넘어
# 공유되고(`.docreview/`), 다른 문서의 codex 산출물은 다른 리뷰의 것이다. 그 라운드는 `init` 이 `state_dir_missing`
# 으로 멈추고 아래에서 codex 축도 건너뛴다.
```

reviewing-brief · request-framing 의 같은 꼴(`for y in "$ROOT/$harness_sid"/docreview/*/…` · `for y in "$ROOT/$sid"/docreview/*/…`)도 같은 방식으로 걷는다. 그 분기를 단언하던 테스트(`test_reviewing_spec_residue.sh` 등)는 「문서를 모르면 다른 문서의 codex 산출물을 건드리지 않는다」 단언으로 바꾼다 — 픽스처로 `.docreview/other-…/docreview-codex.yaml` 을 두고 `spec_path=` 빈 채로 펜스를 돌려 그 파일이 그대로인지 본다.

- [ ] **Step 6: 통과를 확인한다**

Run(레포 루트): `bash ~/.claude/sdd-mirror/r7-impl/run_suite.sh ~/.claude/sdd-mirror/r7-impl/after-t3.txt` 후 `diff ~/.claude/sdd-mirror/r7-impl/baseline-before.txt ~/.claude/sdd-mirror/r7-impl/after-t3.txt` → 새 FAIL 이름 0.
quality-gates 쪽 확인: `git grep -n 'state-dir-for' -- plugins/quality-gates` 가 CHANGELOG 밖에서 0 이어야 한다(qg 는 이 서브커맨드를 부르지 않는다).

- [ ] **Step 7: 변이로 이빨을 잰다(AC6 · AC15)** — `PYTHONDONTWRITEBYTECODE=1`, 변이 전 커밋 상태에서:
  1. 삭제 축: `state_dir_for` 의 `STATE_SUBDIR` 를 `"docreview"` 로 → `cases.sh` 의 꼴 단언 RED.
  2. 추가 축: parser 에 `x.add_argument("--session", default=None)` 를 되살린다 → `--session` exit 2 단언 RED.
  3. 반전 축: `return Path(root) / STATE_SUBDIR / …` 앞에 `"sess0001"` 성분을 끼운다 → 꼴 단언 RED.
  각 변이 뒤 `git checkout HEAD -- <파일>` 과 `git diff HEAD --stat` 이 비었는지 확인. 결과를 `~/.claude/sdd-mirror/r7-impl/mutation.md` 에 「AC6 · 변이 · 기대 · 실측」 줄로 남긴다.

- [ ] **Step 8: 커밋한다** — 메시지 `refactor(docreview): 리뷰 원장을 세션이 아니라 문서 단위(.docreview)로 둔다`, 이 Task 가 바꾼 파일 전부를 경로 지정으로.

---

### Task 4: `ledger_marker.py` — 동시 리뷰 표지

**Files:**
- Create: `plugins/spec-distill/scripts/ledger_marker.py`
- Test: `plugins/spec-distill/tests/test_ledger_marker.py`

**Interfaces:**
- Consumes: `state_path.SESSION_PATTERN`; 엔진 `docreview_state.load_state(state_dir) -> dict`(같은 `scripts/` 의 심볼릭 링크 형제).
- Produces (CLI, 공통 인자 `--dir <원장 폴더> --session <sid>`; 폴더가 없거나 sid 가 `SESSION_PATTERN` 에 `fullmatch` 하지 않으면 rc 2):
  - `acquire` — `O_CREAT|O_EXCL|O_NOFOLLOW` 로 `reviewing-by` 생성. 새로 잡으면 stdout `acquired` rc 0 · 이미 자기 것이면 `held` rc 0 · 남의 것이면 그 세션 id(빈 표지는 `(빈 표지)`) rc 3
  - `check` — 자기 것이면 rc 0(출력 없음) · 표지 없음 `[spec-distill] 표지 없음 — <dir>` rc 3 · 남의 것 `[spec-distill] 다른 세션 <id> 의 표지 — <dir>` rc 3
  - `release` — 자기 것이면 `last-session` 에 자기 id 를 원자적으로 쓴 뒤 표지를 지우고 `released` rc 0 · 그 밖에는 지우지 않고 사실 한 줄 rc 0
  - `takeover` — 같은 폴더의 임시 파일 + `os.replace` 로 표지를 바꾼다. `[spec-distill] 표지를 넘겨받았다 — 이전: <id|없음>` rc 0
  - `resume-note` — 원장 라운드 ≥ 1 이고, 표지가 부른 세션 것이 아니고(R-d), `last-session` 이 없거나 다르면 `[spec-distill] 이전 리뷰 라운드 <n> 에서 이어 간다 — <dir>`. 원장이 없으면 아무것도 내지 않는다. 읽지 못하면 stderr 한 줄. 늘 rc 0(폴더 · sid 오류만 rc 2)
- 상수: `MARKER = "reviewing-by"`, `LAST = "last-session"`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_ledger_marker.py`:

```python
"""R7 §2-2 · §2-4 — ledger_marker.py (AC7 · AC8 의 모듈 쪽)."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "ledger_marker.py"
A, B = "sess-aaaa1111", "sess-bbbb2222"


def run(*args):
    cp = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, timeout=20)
    return cp.returncode, cp.stdout.strip(), cp.stderr.strip()


def ledger(d: Path, rnd: int):
    d.mkdir(parents=True, exist_ok=True)
    (d / "docreview-state.md").write_text(
        "---\ndocreview:\n  doc: /x/y.md\n  profile: design-doc\n  round: %d\n---\n# docreview 원장\n" % rnd,
        encoding="utf-8")


class MarkerTest(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp()) / "k"
        self.d.mkdir()

    def m(self, sub, sid):
        return run(sub, "--dir", str(self.d), "--session", sid)

    def test_acquire_then_held(self):
        self.assertEqual(self.m("acquire", A)[:2], (0, "acquired"))
        self.assertEqual(self.m("acquire", A)[:2], (0, "held"))
        self.assertEqual((self.d / "reviewing-by").read_text(encoding="utf-8"), A + "\n")

    def test_foreign_is_rc3_with_owner(self):
        self.m("acquire", A)
        self.assertEqual(self.m("acquire", B)[:2], (3, A))

    def test_concurrent_acquire_exactly_one_wins(self):
        for trial in range(10):
            d = self.d.parent / ("c%d" % trial)
            d.mkdir()
            procs = [subprocess.Popen([sys.executable, str(SCRIPT), "acquire", "--dir", str(d), "--session", s],
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for s in ("sess-p%07d" % i for i in range(6))]
            rcs = [p.wait(timeout=20) for p in procs]
            self.assertEqual(rcs.count(0), 1, "trial %d rcs=%r" % (trial, rcs))
            self.assertEqual(rcs.count(3), 5)

    def test_check(self):
        self.assertEqual(self.m("check", A)[0], 3)            # 표지 없음
        self.assertIn("표지 없음", self.m("check", A)[1])
        self.m("acquire", A)
        self.assertEqual(self.m("check", A)[0], 0)
        rc, out, _ = self.m("check", B)
        self.assertEqual(rc, 3)
        self.assertIn(A, out)

    def test_release_only_own(self):
        self.m("acquire", A)
        rc, out, _ = self.m("release", B)
        self.assertEqual(rc, 0)
        self.assertTrue((self.d / "reviewing-by").exists(), "남의 표지를 지웠다")
        self.assertEqual(self.m("release", A)[:2], (0, "released"))
        self.assertFalse((self.d / "reviewing-by").exists())
        self.assertEqual((self.d / "last-session").read_text(encoding="utf-8").strip(), A)
        self.assertEqual(self.m("release", A)[0], 0)          # 표지 없음 — rc 0

    def test_takeover_replaces_and_old_owner_stops(self):
        self.m("acquire", A)
        rc, out, _ = self.m("takeover", B)
        self.assertEqual(rc, 0)
        self.assertIn("이전: " + A, out)
        self.assertEqual(self.m("check", B)[0], 0)
        self.assertEqual(self.m("check", A)[0], 3)            # 넘겨준 세션은 다음 쓰기 앞에서 멈춘다
        self.assertEqual(self.m("acquire", A)[0], 3)
        self.m("release", A)
        self.assertTrue((self.d / "reviewing-by").exists())

    def test_empty_marker_is_foreign(self):
        (self.d / "reviewing-by").write_text("", encoding="utf-8")
        self.assertEqual(self.m("acquire", A)[:2], (3, "(빈 표지)"))
        self.assertEqual(self.m("check", A)[0], 3)
        self.assertEqual(self.m("takeover", A)[0], 0)
        self.assertEqual(self.m("check", A)[0], 0)

    def test_symlink_marker_is_error_not_followed(self):
        outside = self.d.parent / "outside.txt"
        outside.write_text(A + "\n", encoding="utf-8")
        os.symlink(outside, self.d / "reviewing-by")
        self.assertEqual(self.m("check", A)[0], 2)
        self.assertEqual(outside.read_text(encoding="utf-8"), A + "\n")

    def test_bad_inputs_rc2(self):
        self.assertEqual(run("acquire", "--dir", str(self.d / "nope"), "--session", A)[0], 2)
        self.assertEqual(self.m("acquire", "a b")[0], 2)
        self.assertEqual(self.m("acquire", A + "\n")[0], 2)


class ResumeNoteTest(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp()) / "k"

    def note(self, sid):
        return run("resume-note", "--dir", str(self.d), "--session", sid)

    def test_round0_silent(self):
        ledger(self.d, 0)
        self.assertEqual(self.note(A)[:2], (0, ""))

    def test_no_last_session_prints(self):
        ledger(self.d, 2)
        self.assertEqual(self.note(A)[1], "[spec-distill] 이전 리뷰 라운드 2 에서 이어 간다 — %s" % self.d)

    def test_other_last_session_prints(self):
        ledger(self.d, 1)
        (self.d / "last-session").write_text(B + "\n", encoding="utf-8")
        self.assertIn("이전 리뷰 라운드 1 에서 이어 간다", self.note(A)[1])

    def test_same_last_session_silent(self):
        ledger(self.d, 3)
        (self.d / "last-session").write_text(A + "\n", encoding="utf-8")
        self.assertEqual(self.note(A)[1], "")

    def test_own_marker_silent(self):            # R-d — 같은 세션의 다음 라운드
        ledger(self.d, 3)
        (self.d / "reviewing-by").write_text(A + "\n", encoding="utf-8")
        self.assertEqual(self.note(A)[1], "")

    def test_no_ledger_silent(self):
        self.d.mkdir(parents=True)
        self.assertEqual(self.note(A)[:2], (0, ""))

    def test_unreadable_ledger_stderr(self):
        self.d.mkdir(parents=True)
        (self.d / "docreview-state.md").write_text("garbage", encoding="utf-8")
        rc, out, err = self.note(A)
        self.assertEqual((rc, out), (0, ""))
        self.assertIn("이전 리뷰 원장을 읽지 못했다", err)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다** — `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_ledger_marker.py 2>&1 | tail -3` → FAIL.

- [ ] **Step 3: 구현한다** — `plugins/spec-distill/scripts/ledger_marker.py`:

```python
#!/usr/bin/env python3
"""spec-distill — 문서 리뷰 원장의 동시 리뷰 표지(`reviewing-by`, 세션 id 한 줄).

엔진(`docreview_state.py`)은 표지를 모른다. 리뷰를 부르는 진입 블록이 라운드를 시작할 때 `acquire`,
원장에 쓰기 전마다 같은 Bash 호출에서 `check`, 끝맺음 펜스 끝에서 `release` 를 부른다.

CLI: ledger_marker.py {acquire|check|release|takeover|resume-note} --dir <원장 폴더> --session <sid>
rc: 0 성공 · 3 남의 표지(acquire · check) 또는 표지 없음(check) · 2 입력 · 입출력 오류
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import SESSION_PATTERN  # noqa: E402

MARKER = "reviewing-by"
LAST = "last-session"


def _read_line(d: Path, name: str) -> str | None:
    """링크를 따라가지 않고 읽는다. 없으면 None. 링크 · 권한은 OSError."""
    try:
        fd = os.open(str(d / name), os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return None
    try:
        data = os.read(fd, 4096)
    finally:
        os.close(fd)
    return data.decode("utf-8", "replace").strip()


def _atomic_write(d: Path, name: str, text: str) -> None:
    tmp = d / (".%s.%d.tmp" % (name, os.getpid()))
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    try:
        os.write(fd, text.encode("utf-8"))
    finally:
        os.close(fd)
    os.replace(str(tmp), str(d / name))


def cmd_acquire(d: Path, sid: str) -> int:
    try:
        fd = os.open(str(d / MARKER), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    except FileExistsError:
        owner = _read_line(d, MARKER)
        if owner == sid:
            print("held")
            return 0
        print(owner if owner else "(빈 표지)")
        return 3
    try:
        os.write(fd, (sid + "\n").encode("utf-8"))
    finally:
        os.close(fd)
    print("acquired")
    return 0


def cmd_check(d: Path, sid: str) -> int:
    owner = _read_line(d, MARKER)
    if owner == sid:
        return 0
    if owner is None:
        print("[spec-distill] 표지 없음 — {0}".format(d))
    else:
        print("[spec-distill] 다른 세션 {0} 의 표지 — {1}".format(owner or "(빈 표지)", d))
    return 3


def cmd_release(d: Path, sid: str) -> int:
    owner = _read_line(d, MARKER)
    if owner != sid:
        if owner is None:
            print("[spec-distill] 표지 없음 — 지울 것이 없다: {0}".format(d))
        else:
            print("[spec-distill] 다른 세션 {0} 의 표지 — 지우지 않았다: {1}".format(owner or "(빈 표지)", d))
        return 0
    _atomic_write(d, LAST, sid + "\n")
    os.unlink(str(d / MARKER))
    print("released")
    return 0


def cmd_takeover(d: Path, sid: str) -> int:
    try:
        prev = _read_line(d, MARKER)
    except OSError:
        prev = "(읽지 못함)"
    _atomic_write(d, MARKER, sid + "\n")
    print("[spec-distill] 표지를 넘겨받았다 — 이전: {0}".format(prev or "없음"))
    return 0


def cmd_resume_note(d: Path, sid: str) -> int:
    from docreview_state import load_state  # 엔진의 원장 판독을 그대로 쓴다
    try:
        st = load_state(d)
    except FileNotFoundError:
        return 0
    except Exception as exc:  # 깨진 원장 · pyyaml 부재 — 줄을 내지 않되 조용하지 않다
        print("[spec-distill] 이전 리뷰 원장을 읽지 못했다 — {0} ({1})".format(d, exc), file=sys.stderr)
        return 0
    try:
        n = int(st.get("round") or 0)
    except (TypeError, ValueError):
        n = 0
    try:
        owner = _read_line(d, MARKER)
        last = _read_line(d, LAST)
    except OSError:
        owner = last = None
    if n >= 1 and owner != sid and last != sid:
        print("[spec-distill] 이전 리뷰 라운드 {0} 에서 이어 간다 — {1}".format(n, d))
    return 0


CMDS = {"acquire": cmd_acquire, "check": cmd_check, "release": cmd_release,
        "takeover": cmd_takeover, "resume-note": cmd_resume_note}


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="ledger_marker.py")
    p.add_argument("cmd", choices=sorted(CMDS))
    p.add_argument("--dir", required=True)
    p.add_argument("--session", required=True)
    a = p.parse_args(argv)
    d = Path(a.dir)
    if not a.session or not SESSION_PATTERN.fullmatch(a.session):
        print("[spec-distill] 세션 id 형식이 아니다: {0!r}".format(a.session[:32]), file=sys.stderr)
        return 2
    if d.is_symlink() or not d.is_dir():
        print("[spec-distill] 원장 폴더가 없다(또는 링크다): {0}".format(d), file=sys.stderr)
        return 2
    try:
        return CMDS[a.cmd](d, a.session)
    except OSError as exc:
        print("[spec-distill] 표지 {0} 실패 — {1}".format(a.cmd, exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 통과를 확인한다** — 단위 테스트 OK + `test_utf8_explicit.py` · `test_python_floor.sh` · `test_no_new_duplication.sh` 새 실패 없음.

- [ ] **Step 5: 변이로 이빨을 잰다(AC8 모듈 쪽)** — `O_EXCL` 삭제(동시 `acquire` 단언 RED) · `cmd_release` 의 `if owner != sid` 를 `if owner is None` 으로(남의 표지 삭제 단언 RED) · `cmd_check` 가 `owner is None` 에서 rc 0(표지 없음 단언 RED) · `resume-note` 의 `last != sid` 반전(같은 세션 침묵 단언 RED). `mutation.md` 에 기록.

- [ ] **Step 6: 커밋한다** — `feat(spec-distill): 문서 리뷰 원장의 동시 리뷰 표지 ledger_marker.py 를 더한다`.

---

### Task 5: `ledger_sweep.py` — 리뷰 진입 때의 원장 정리

**Files:**
- Create: `plugins/spec-distill/scripts/ledger_sweep.py`
- Test: `plugins/spec-distill/tests/test_ledger_sweep.py`

**Interfaces:**
- Consumes: `state_path.state_root` · `SESSION_PATTERN`; `gc_common` 의 `GC_PENDING_PREFIX` · `folder_mtime_ns` · `gc_one` · `locked_root` · `root_escapes` · `safe_rmtree` · `ttl_ns`; `kill_switch_active`; 엔진 `load_state` · `state_dir_for(root, doc)`(Task 3).
- Produces: CLI `ledger_sweep.py [--root <state-root>]`(기본 cwd 의 `state_root()`). 늘 rc 0. stdout 줄(설계 §3-2 의 문면):
  - `[spec-distill] 원장 정리 — 문서 없는 원장 <a>개 · 옛 세션 폴더 <b>개 지움 · 옛 원장 <c>개 옮김` (셋 다 0 이면 없음)
  - `[spec-distill] 옛 원장 충돌 — <새 키>: <옛|새> 쪽을 남겼다`
  - `[spec-distill] 옮기지 않은 옛 인터뷰 기록 <n>개 — <state.local.md 경로들, ' · ' 구분>`
  - `[spec-distill] 원장 정리 — 읽지 못한 원장 <n>개 남김 — <경로들>`
  - `[spec-distill] 원장 정리 — 셀 수 없음(<사유>)`
  - `[spec-distill] 원장 정리 — 건너뜀(다른 세션이 정리 중)`

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `plugins/spec-distill/tests/test_ledger_sweep.py`. 공통 도우미와 케이스(각 케이스가 AC9 의 한 조항이다):

```python
"""R7 §3-2 · §3-3 — ledger_sweep.py (AC9) + 옛 GC 가 .docreview 를 지우지 않음(AC6 픽스처, R-g)."""
import fcntl
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
SWEEP = SCRIPTS / "ledger_sweep.py"
REPO = Path(__file__).resolve().parents[3]
OLD_GC_COMMIT = "9b7a5e07"
OLD = time.time() - 30 * 3600          # TTL(24h) 너머


def run(args=(), env_extra=None, cwd=None):
    env = {k: v for k, v in os.environ.items()
           if k not in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS", "DEVBREW_SPEC_DISTILL_TTL_HOURS")}
    env.update(env_extra or {})
    cp = subprocess.run([sys.executable, str(SWEEP), *args], env=env, cwd=cwd,
                        capture_output=True, text=True, timeout=30)
    return cp.returncode, cp.stdout, cp.stderr


def age(path: Path, when=OLD):
    for dp, dns, fns in os.walk(path):
        for n in dns + fns:
            os.utime(os.path.join(dp, n), (when, when), follow_symlinks=False)
    os.utime(path, (when, when))


def write_ledger(d: Path, doc: str):
    d.mkdir(parents=True, exist_ok=True)
    (d / "docreview-state.md").write_text(
        "---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: 2\n---\n# docreview 원장\n" % doc,
        encoding="utf-8")


def key_for(root: Path, doc: str) -> Path:
    out = subprocess.run([sys.executable, str(SCRIPTS / "docreview_state.py"), "state-dir-for",
                          "--root", str(root), "--doc", doc], capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.root = self.tmp / ".claude" / "spec-distill"
        self.root.mkdir(parents=True)
        self.docs = self.tmp / "docs"
        self.docs.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def doc(self, name="d.md"):
        p = self.docs / name
        p.write_text("x\n", encoding="utf-8")
        return str(p)

    def sweep(self, env=None):
        return run(["--root", str(self.root)], env_extra=env)

    def old_session(self, sid, ledgers=(), state_local=False):
        s = self.root / sid
        s.mkdir()
        (s / "interview-basename").write_text("x\n", encoding="utf-8")   # 직속 파일 — grace 창을 비켜 간다
        for name, doc in ledgers:
            write_ledger(s / "docreview" / name, doc)
        if state_local:
            (s / "state.local.md").write_text("---\n---\n", encoding="utf-8")
        age(s)
        return s
```

케이스(같은 파일, `class SweepTest(Base)` 등):

```python
class LedgerRootTest(Base):
    def test_docless_ledger_removed_after_ttl(self):
        d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md")); age(d)
        rc, out, _ = self.sweep()
        self.assertFalse(d.exists())
        self.assertIn("문서 없는 원장 1개", out)

    def test_docless_ledger_within_ttl_kept(self):
        d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md"))
        self.sweep()
        self.assertTrue(d.exists())

    def test_ledger_with_doc_kept(self):
        doc = self.doc(); d = key_for(self.root, doc); write_ledger(d, doc); age(d)
        self.sweep()
        self.assertTrue(d.exists())

    def test_unreadable_ledger_kept_and_announced(self):
        d = self.root / ".docreview" / "x-0000000000000000"; d.mkdir(parents=True)
        (d / "critic.txt").write_text("y", encoding="utf-8"); age(d)
        rc, out, _ = self.sweep()
        self.assertTrue(d.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % d, out)

    def test_docreview_symlink_uncountable(self):
        outside = self.tmp / "outside"; outside.mkdir()
        os.symlink(outside, self.root / ".docreview")
        rc, out, _ = self.sweep()
        self.assertIn("원장 정리 — 셀 수 없음(", out)
        self.assertTrue(outside.exists())

    def test_korean_doc_path_kept_and_migrated(self):
        doc = self.doc("설계 문서.md")
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())
        self.assertFalse(s.exists())


class OldSessionTest(Base):
    def test_docreview_root_not_old_folder(self):
        doc = self.doc(); d = key_for(self.root, doc); write_ledger(d, doc); age(self.root / ".docreview")
        self.sweep()
        self.assertTrue(d.exists())

    def test_old_folder_without_state_local_removed(self):
        s = self.old_session("oldsess01")
        rc, out, _ = self.sweep()
        self.assertFalse(s.exists())
        self.assertIn("옛 세션 폴더 1개 지움", out)

    def test_old_folder_within_ttl_untouched(self):
        s = self.root / "newsess01"; s.mkdir(); (s / "f").write_text("x", encoding="utf-8")
        write_ledger(s / "docreview" / "k", self.doc())
        self.sweep()
        self.assertTrue((s / "docreview" / "k" / "docreview-state.md").exists())

    def test_state_local_folder_preserved_and_announced(self):
        s = self.old_session("oldsess01", state_local=True)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertIn("옮기지 않은 옛 인터뷰 기록 1개 — %s" % (s / "state.local.md"), out)

    def test_old_ledger_with_doc_migrated_to_state_dir_for_key(self):
        doc = self.doc()
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())
        self.assertFalse(s.exists())
        self.assertIn("옛 원장 1개 옮김", out)

    def test_old_ledger_without_doc_removed_with_folder(self):
        s = self.old_session("oldsess01", ledgers=[("k1", str(self.docs / "gone.md"))])
        self.sweep()
        self.assertFalse(s.exists())
        self.assertFalse(key_for(self.root, str(self.docs / "gone.md")).exists())

    def test_old_unreadable_ledger_keeps_folder(self):
        doc = self.doc()
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        bad = s / "docreview" / "k2"; bad.mkdir(); (bad / "x").write_text("y", encoding="utf-8"); age(s)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())  # 옮길 수 있는 것은 옮긴다
        self.assertIn("읽지 못한 원장", out)

    def _conflict(self, old_newer: bool, marker=False, target_unreadable=False):
        doc = self.doc()
        tgt = key_for(self.root, doc)
        if target_unreadable:
            tgt.mkdir(parents=True); (tgt / "x").write_text("y", encoding="utf-8")
        else:
            write_ledger(tgt, doc)
        if marker:
            (tgt / "reviewing-by").write_text("sess-live0001\n", encoding="utf-8")
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        old_state = s / "docreview" / "k1" / "docreview-state.md"
        old_state.write_text(old_state.read_text(encoding="utf-8") + "- old\n", encoding="utf-8")
        age(s)                                   # 옛 폴더 전체를 다시 TTL 너머로 — 아래 한 파일만 조금 젊힌다
        # 옛 폴더는 TTL 너머여야 ② 가 본다 — 옛 원장의 시각은 OLD 근처에서만 움직인다.
        t_old, t_new = (OLD + 100, OLD) if old_newer else (OLD, time.time() - 100)
        os.utime(old_state, (t_old, t_old))
        if (tgt / "docreview-state.md").exists():
            os.utime(tgt / "docreview-state.md", (t_new, t_new))
        return doc, tgt, s

    def test_conflict_old_newer_wins(self):
        doc, tgt, s = self._conflict(old_newer=True)
        rc, out, _ = self.sweep()
        self.assertIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("옛 원장 충돌 — %s: 옛 쪽을 남겼다" % tgt.name, out)

    def test_conflict_new_newer_wins(self):
        doc, tgt, s = self._conflict(old_newer=False)
        rc, out, _ = self.sweep()
        self.assertNotIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("옛 원장 충돌 — %s: 새 쪽을 남겼다" % tgt.name, out)

    def test_conflict_marker_keeps_target(self):
        doc, tgt, s = self._conflict(old_newer=True, marker=True)
        rc, out, _ = self.sweep()
        self.assertNotIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("새 쪽을 남겼다", out)

    def test_conflict_unreadable_target_keeps_both(self):
        doc, tgt, s = self._conflict(old_newer=True, target_unreadable=True)
        rc, out, _ = self.sweep()
        self.assertTrue((tgt / "x").exists())
        self.assertTrue(s.exists())
        self.assertIn("읽지 못한 원장", out)


class SafetyTest(Base):
    def test_kill_switches_spare_everything(self):
        envs = [{"DEVBREW_SPEC_DISTILL_DISABLE": "1"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:session-end-cleanup"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:spec-distill-gc"}]
        for env in envs:
            s = self.old_session("oldsess%02d" % envs.index(env))
            d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md")); age(d)
            self.sweep(env)
            self.assertTrue(s.exists(), env)
            self.assertTrue(d.exists(), env)
        self.sweep()                                   # 양성 대조 — 스위치 없으면 지운다
        self.assertFalse(d.exists())

    def test_root_escape_refused(self):
        real = self.tmp / "elsewhere"; real.mkdir()
        shutil.rmtree(self.root); os.symlink(real, self.root)
        s = real / "oldsess01"; s.mkdir(); (s / "f").write_text("x", encoding="utf-8"); age(s)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertIn("셀 수 없음(", out)

    def test_lock_held_elsewhere_skips_loudly(self):
        s = self.old_session("oldsess01")
        fd = os.open(str(self.root), os.O_RDONLY)
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            rc, out, _ = self.sweep()
        finally:
            os.close(fd)
        self.assertTrue(s.exists())
        self.assertIn("건너뜀(다른 세션이 정리 중)", out)

    def test_gc_pending_swept_in_both_places(self):
        a = self.root / ".gc-pending-aaa"; a.mkdir(); age(a)
        (self.root / ".docreview").mkdir()
        b = self.root / ".docreview" / ".gc-pending-bbb"; b.mkdir(); age(b)
        self.sweep()
        self.assertFalse(a.exists()); self.assertFalse(b.exists())


class OldGcIgnoresDocreviewTest(unittest.TestCase):
    """AC6 — 옛 버전 spec-distill-gc.py 가 .docreview 를 지우지 않는다(TTL 1h · mtime 2h 전) + 양성 짝 둘."""

    def test_old_gc(self):
        tmp = Path(tempfile.mkdtemp()).resolve()
        try:
            src = subprocess.run(["git", "-C", str(REPO), "show",
                                  OLD_GC_COMMIT + ":plugins/spec-distill/scripts/spec-distill-gc.py"],
                                 capture_output=True, text=True)
            self.assertEqual(src.returncode, 0,
                             "옛 GC 를 git 에서 꺼내지 못했다(커밋 %s 도달 불가) — 도출 불가는 RED" % OLD_GC_COMMIT)
            tools = tmp / "oldgc"; tools.mkdir()
            (tools / "spec-distill-gc.py").write_text(src.stdout, encoding="utf-8")
            for n in ("state_path.py", "gc_common.py", "kill_switch_active.py"):
                shutil.copy(SCRIPTS / n, tools / n)
            repo = tmp / "repo"; repo.mkdir()
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            root = repo / ".claude" / "spec-distill"; root.mkdir(parents=True)
            new_ledger = root / ".docreview" / "d-0123456789abcdef"; write_ledger(new_ledger, "/x/d.md")
            old_name = root / "docreview"; old_name.mkdir(); (old_name / "f").write_text("x", encoding="utf-8")
            stale = root / "stalesess01"; stale.mkdir(); (stale / "f").write_text("x", encoding="utf-8")
            fresh = root / "freshsess01"; fresh.mkdir(); (fresh / "f").write_text("x", encoding="utf-8")
            two_h = time.time() - 2 * 3600
            for p in (root / ".docreview", old_name, stale):
                age(p, two_h)
            env = {k: v for k, v in os.environ.items()
                   if k not in ("CLAUDE_CODE_SESSION_ID", "DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS")}
            env["DEVBREW_SPEC_DISTILL_TTL_HOURS"] = "1"
            subprocess.run([sys.executable, str(tools / "spec-distill-gc.py")], cwd=repo, env=env,
                           capture_output=True, text=True, timeout=30)
            self.assertTrue((new_ledger / "docreview-state.md").exists(), "옛 GC 가 .docreview 원장을 지웠다")
            self.assertFalse(old_name.exists(), "양성 짝: 정규식에 맞는 늙은 폴더(옛 docreview 이름)는 지워져야 한다")
            self.assertFalse(stale.exists(), "양성 짝: 늙은 세션 폴더는 지워져야 한다")
            self.assertTrue(fresh.exists(), "양성 짝: mtime 이 지금인 폴더는 TTL 1h 로 남아야 한다")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다** — `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_ledger_sweep.py 2>&1 | tail -3`. `OldGcIgnoresDocreviewTest` 는 Task 3 덕에 이미 통과할 수 있다(그것이 목적이다 — 옛 코드는 바꾸지 않는다). 나머지는 FAIL.

- [ ] **Step 3: 구현한다** — `plugins/spec-distill/scripts/ledger_sweep.py`:

```python
#!/usr/bin/env python3
"""spec-distill — 리뷰 진입 때 한 번 도는 원장 정리(설계 §3-2).

  ① `<state-root>/.docreview/<키>/` 중 기록된 문서가 없는 원장을 지운다 — `gc_one` 의 TTL 검사를 그대로 받는다.
     원장을 읽지 못하면 지우지 않고 알린다.
  ② 옛 세션 폴더 `<state-root>/<sid>/`(세션 이름 정규식) 중 `state.local.md` 가 없고 TTL 을 넘은 것을 지운다.
     지우기 전에 기록된 문서가 있는 옛 원장 `docreview/<x>/` 를 `.docreview/<새 키>/` 로 옮긴다.
  ③ `state.local.md` 가 있는 옛 세션 폴더는 시간과 무관하게 지우지 않고 알린다.
  안전: (a) 루트 디렉토리 잠금 (b) `.docreview` 링크 · 탈출 거부 (c) `.gc-pending-*` 줍기(두 자리).

Kill switches: DEVBREW_SPEC_DISTILL_DISABLE=1 · DEVBREW_SKIP_HOOKS 의 spec-distill:SessionEnd ·
spec-distill:session-end-cleanup · spec-distill:spec-distill-gc — 셋 다 이 정리를 끈다.
TTL: DEVBREW_SPEC_DISTILL_TTL_HOURS(기본 24) — ① 의 삭제 유예와 ② 의 판정 두 자리에 쓴다.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from state_path import SESSION_PATTERN, state_root  # noqa: E402
from gc_common import (  # noqa: E402
    GC_PENDING_PREFIX, folder_mtime_ns, gc_one, locked_root, root_escapes, safe_rmtree, ttl_ns,
)
from kill_switch_active import kill_switch_active  # noqa: E402
from docreview_state import STATE_SUBDIR, load_state, state_dir_for  # noqa: E402

MARKER = "reviewing-by"
STATE_FILE = "docreview-state.md"
OLD_SUBDIR = "docreview"
LEGACY_INTERVIEW = "state.local.md"
PENDING_SWEEP_AGE_S = 60


class Report:
    def __init__(self) -> None:
        self.docless = 0
        self.old_removed = 0
        self.moved = 0
        self.conflicts: list[str] = []
        self.preserved: list[str] = []
        self.unread: list[str] = []
        self.uncountable: list[str] = []


def disabled() -> bool:
    return (kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd")
            or kill_switch_active("spec-distill", "spec-distill-gc"))


def recorded_doc(ledger_dir: Path) -> str | None:
    try:
        st = load_state(ledger_dir)
    except Exception:
        return None
    doc = st.get("doc")
    return doc if isinstance(doc, str) and doc else None


def ledger_root_ok(root: Path, rep: Report) -> bool:
    lr = root / STATE_SUBDIR
    if lr.is_symlink() or (lr.exists() and os.path.realpath(lr) != os.path.join(os.path.realpath(root), STATE_SUBDIR)):
        rep.uncountable.append("{0} 가 링크이거나 루트 밖으로 풀린다".format(lr))
        return False
    return True


def sweep_pending(parent: Path, root: Path) -> None:
    if parent.is_symlink() or not parent.is_dir():
        return
    now = time.time()
    for child in parent.iterdir():
        if child.is_symlink() or not child.is_dir() or not child.name.startswith(GC_PENDING_PREFIX):
            continue
        try:
            if now - child.stat().st_mtime < PENDING_SWEEP_AGE_S:
                continue
        except OSError:
            continue
        safe_rmtree(child, root)


def sweep_ledgers(root: Path, ttl: int, rep: Report) -> None:
    lr = root / STATE_SUBDIR
    if not lr.is_dir():
        return
    for child in sorted(lr.iterdir()):
        if child.name.startswith(".") or child.is_symlink() or not child.is_dir():
            continue
        doc = recorded_doc(child)
        if doc is None:
            rep.unread.append(str(child))
            continue
        if os.path.exists(doc):
            continue
        try:
            if gc_one(child, ttl, lr):
                rep.docless += 1
        except OSError as exc:
            print("[spec-distill] 원장 정리 실패 — {0}: {1}".format(child, exc), file=sys.stderr)


def migrate_old_ledger(old: Path, root: Path, rep: Report) -> str:
    """'moved' · 'docless' · 'unread' · 'kept-target' 중 하나."""
    doc = recorded_doc(old)
    if doc is None:
        rep.unread.append(str(old))
        return "unread"
    if not os.path.exists(doc):
        return "docless"
    target = state_dir_for(str(root), doc)
    target.parent.mkdir(exist_ok=True)
    if not (target.exists() or target.is_symlink()):
        os.rename(str(old), str(target))
        rep.moved += 1
        return "moved"
    key = target.name
    if os.path.lexists(target / MARKER):
        rep.conflicts.append("옛 원장 충돌 — {0}: 새 쪽을 남겼다".format(key))
        return "kept-target"
    if recorded_doc(target) is None:
        rep.unread.append(str(target))
        return "unread"
    if (old / STATE_FILE).stat().st_mtime_ns > (target / STATE_FILE).stat().st_mtime_ns:
        aside = target.parent / "{0}{1}-{2}".format(GC_PENDING_PREFIX, key, time.time_ns())
        os.rename(str(target), str(aside))
        os.rename(str(old), str(target))
        rep.moved += 1
        rep.conflicts.append("옛 원장 충돌 — {0}: 옛 쪽을 남겼다".format(key))
        return "moved"
    rep.conflicts.append("옛 원장 충돌 — {0}: 새 쪽을 남겼다".format(key))
    return "kept-target"


def sweep_old_sessions(root: Path, ttl: int, rep: Report, can_migrate: bool) -> None:
    now = time.time_ns()
    for child in sorted(root.iterdir()):
        if child.is_symlink() or not child.is_dir() or not SESSION_PATTERN.fullmatch(child.name):
            continue
        if os.path.lexists(child / LEGACY_INTERVIEW):
            rep.preserved.append(str(child / LEGACY_INTERVIEW))
            continue
        try:
            if now - folder_mtime_ns(child) < ttl:
                continue
        except OSError:
            continue
        keep = False
        old_root = child / OLD_SUBDIR
        if old_root.is_dir() and not old_root.is_symlink():
            if not can_migrate:
                keep = True
            else:
                before = os.lstat(old_root)
                moved = False
                for led in sorted(old_root.iterdir()):
                    if led.is_symlink() or not led.is_dir():
                        continue
                    r = migrate_old_ledger(led, root, rep)
                    keep = keep or r == "unread"
                    moved = moved or r == "moved"
                if moved:
                    # 옮기기가 바꾼 것은 `docreview/` 의 mtime 뿐이다 — 되돌려 gc_one 의 나이 판정이 옛 값을 보게 한다.
                    os.utime(old_root, ns=(before.st_atime_ns, before.st_mtime_ns))
        if keep:
            continue
        try:
            if gc_one(child, ttl, root):
                rep.old_removed += 1
        except OSError as exc:
            print("[spec-distill] 옛 세션 폴더 정리 실패 — {0}: {1}".format(child, exc), file=sys.stderr)


def emit(rep: Report) -> None:
    if rep.docless or rep.old_removed or rep.moved:
        print("[spec-distill] 원장 정리 — 문서 없는 원장 {0}개 · 옛 세션 폴더 {1}개 지움 · 옛 원장 {2}개 옮김".format(
            rep.docless, rep.old_removed, rep.moved))
    for c in rep.conflicts:
        print("[spec-distill] " + c)
    if rep.preserved:
        print("[spec-distill] 옮기지 않은 옛 인터뷰 기록 {0}개 — {1}".format(len(rep.preserved), " · ".join(rep.preserved)))
    if rep.unread:
        print("[spec-distill] 원장 정리 — 읽지 못한 원장 {0}개 남김 — {1}".format(len(rep.unread), " · ".join(rep.unread)))
    for u in rep.uncountable:
        print("[spec-distill] 원장 정리 — 셀 수 없음({0})".format(u))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="ledger_sweep.py")
    ap.add_argument("--root", default=None)
    a = ap.parse_args(argv)
    if disabled():
        return 0
    root = Path(a.root) if a.root else state_root()
    if root_escapes(root, "spec-distill"):
        print("[spec-distill] 원장 정리 — 셀 수 없음(state root '{0}' 가 링크를 거쳐 제자리 밖으로 풀린다)".format(root))
        return 0
    if not root.is_dir():
        return 0
    ttl = ttl_ns("DEVBREW_SPEC_DISTILL_TTL_HOURS")
    rep = Report()
    with locked_root(root, "spec-distill") as held:
        if not held:
            print("[spec-distill] 원장 정리 — 건너뜀(다른 세션이 정리 중)")
            return 0
        ok = ledger_root_ok(root, rep)
        sweep_pending(root, root)
        if ok:
            sweep_pending(root / STATE_SUBDIR, root)
            sweep_ledgers(root, ttl, rep)
        sweep_old_sessions(root, ttl, rep, can_migrate=ok)
    emit(rep)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

주의: `.docreview` 가 링크면 ② 의 이월도 하지 않는다(`can_migrate=False` → 옛 원장이 있는 폴더는 남긴다). `test_docreview_symlink_uncountable` 이 그 경로를 잰다. `state.local.md` 와 `docreview` 문자열은 이 파일의 정당한 옛 이름이다(AC2 허용).

- [ ] **Step 4: 통과를 확인한다** — 단위 테스트 OK. `test_utf8_explicit.py` · `test_python_floor.sh` · `test_no_new_duplication.sh`(`spec-distill-gc.py` 와 20줄 겹침이 없어야 한다 — `sweep_pending` 은 옛 `_sweep_gc_pending` 과 다르게 쓴다; 걸리면 그 블록을 줄여 겹침을 없앤다) 새 실패 없음.

- [ ] **Step 5: 변이로 이빨을 잰다(AC9 · AC6 · AC15)** — 삭제 축: `if os.path.exists(doc): continue` 삭제 → `test_ledger_with_doc_kept` RED; `os.path.lexists(child / LEGACY_INTERVIEW)` 분기 삭제 → 보존 단언 RED; `disabled()` 의 둘째 항 삭제 → `spec-distill-gc` 스위치 칸 RED. 추가 축: `sweep_ledgers` 의 `doc is None` 분기에서 `gc_one` 을 부른다 → 읽지 못한 원장 단언 RED. 반전 축: 충돌 비교 `>` → `<` → 두 충돌 단언 RED. AC6: 테스트의 `"1"` TTL 을 `"0"` 으로 바꾸면 양성 짝(`stale` 지워짐)이 RED 가 됨을 확인(TTL 0 은 24h 로 바뀐다 — 설계 결정 7b7d0951 의 실측). 전부 `mutation.md` 에 기록.

- [ ] **Step 6: 커밋한다** — `feat(spec-distill): 리뷰 진입 때 도는 원장 정리 ledger_sweep.py 를 더한다`.

---

### Task 6: SessionEnd 훅 · TTL-GC 제거

**Files:**
- Delete: `plugins/spec-distill/hooks/hooks.json` · `plugins/spec-distill/hooks/session-end-cleanup.py`(R-a — `hooks/` 디렉토리째), `plugins/spec-distill/scripts/spec-distill-gc.py`, `plugins/spec-distill/tests/test_gc.py`, `plugins/spec-distill/tests/test_session_end_cleanup.py`
- Modify: `plugins/spec-distill/scripts/hook_common.py` — `fire_and_forget_gc` · `GC_SCRIPT` · `SCRIPTS_DIR` 와 그것만 쓰던 import(`subprocess` · `sys` · `Path`)를 지운다. `_yaml_scalar` · 두 `_YAML_UNSAFE_*` 상수 · `json` 은 남긴다. docstring 「소비자」 목록에서 훅 줄을 지우고 「훅이 없어진 뒤(6.0.0) 남은 소비자는 `brief_review_state.py` 하나다」로.
- Modify(테스트): `plugins/spec-distill/tests/test_hooks.sh` · `test_kill_switches_v060.sh` · `shared/tests/test_python_floor.sh` · `test_no_write_matcher_hooks_repo.sh`(필요하면) 및 Step 1 의 grep 이 내는 것
- Modify: `plugins/spec-distill/README.md` 의 `## Hooks Installed` 표 — `test_readme_sync.sh` 가 훅 목록과 README 를 맞춰 보면 이 Task 에서 「설치되는 훅이 없다(6.0.0) — 원장 정리는 리뷰 진입(`scripts/ledger_sweep.py`)이 한다」 한 줄로 바꾼다(나머지 문서는 Task 10)

**Interfaces:**
- Consumes: Task 5 의 `ledger_sweep.py` 가 GC 의 일을 대신한다.
- Produces: `plugins/spec-distill/hooks/` 없음 · `scripts/spec-distill-gc.py` 없음.

- [ ] **Step 1: 소비자를 센다**

```bash
git grep -nE 'session-end-cleanup|spec-distill-gc|fire_and_forget_gc|GC_SCRIPT|spec-distill/hooks|hooks/hooks\.json|DEVBREW_SPEC_DISTILL_GC_VERBOSE' -- plugins shared tools ':!*/CHANGELOG.md'
```
`plugins/project-init/scripts/kill_switch_active.py` · `plugins/quality-gates/scripts/kill_switch_active.py` · `shared/killswitch/kill_switch_active.py` · `tools/adjudication/check_names.py` 의 과거형 서술(「`spec-distill-gc.py` 는 그 변수를 아예 읽지 않았다」)은 역사 서술이라 고치지 않는다(사본 동일성 락 `test_copy_of_contract.sh` 도 정본과 사본이 같기를 요구한다). 그 밖의 현재형 참조는 이 Task 에서 고친다.

- [ ] **Step 2: 부재 락을 먼저 쓴다(AC10 음의 짝)** — `test_hooks.sh` 끝에 붙인다:

```bash
# ── R7 §3-1 · AC10 — 설치되는 훅이 없다 ────────────────────────────────────
[[ ! -e "$PLUGIN_DIR/hooks" ]] && ok "AC10: hooks/ 가 없다 — 설치되는 훅이 없다" || no "AC10: hooks/ 가 남아 있다"
[[ ! -e "$PLUGIN_DIR/scripts/spec-distill-gc.py" ]] && ok "AC10: spec-distill-gc.py 가 없다" || no "AC10: spec-distill-gc.py 가 남아 있다"
grep -qE '^def fire_and_forget_gc' "$PLUGIN_DIR/scripts/hook_common.py" \
  && no "AC10: hook_common 에 GC 기동이 남았다" || ok "AC10: hook_common 에 GC 기동이 없다"
grep -qE '^def _yaml_scalar' "$PLUGIN_DIR/scripts/hook_common.py" \
  && ok "AC10 양의 짝: hook_common 이 남은 소비자의 _yaml_scalar 를 갖는다" || no "AC10 양의 짝: _yaml_scalar 가 사라졌다"
```

(`PLUGIN_DIR` · `ok` · `no` 는 그 파일의 실제 변수 · 함수 이름에 맞춘다 — 머리를 읽고 쓴다.) 이 파일의 기존 케이스 1(「hooks.json 에 SessionStart 키가 없다 · 유효 JSON」)은 hooks.json 이 없어지므로 「hooks.json 이 없거나 SessionStart 키가 없다」로 고친다.

- [ ] **Step 3: RED 를 확인한다** — `bash plugins/spec-distill/tests/test_hooks.sh 2>&1 | grep -E '✗|Total'` → AC10 줄 `✗`.

- [ ] **Step 4: 지우고 고친다** — `git rm -- plugins/spec-distill/hooks/hooks.json plugins/spec-distill/hooks/session-end-cleanup.py plugins/spec-distill/scripts/spec-distill-gc.py plugins/spec-distill/tests/test_gc.py plugins/spec-distill/tests/test_session_end_cleanup.py`, `hook_common.py` 정리. `test_kill_switches_v060.sh` 는 SessionEnd 훅 · GC 스크립트를 직접 부르는 케이스를 지우고, 같은 스위치 넷이 `ledger_sweep.py` 에서 아무것도 지우지 않는지 재는 케이스로 바꾼다(픽스처: `.claude/spec-distill/oldsess01/f` 를 30시간 전으로 늙힌 뒤 스위치별로 `python3 "$PLUGIN_DIR/scripts/ledger_sweep.py" --root …` → 폴더가 남는다; 마지막에 스위치 없이 돌려 지워지는 양성 대조). `test_python_floor.sh` 의 훅 목록 · `SessionEnd:spec-distill:session-end-cleanup` 칸 · `hook_common.py 가 sys.executable 을 쓴다` 양의 짝을 고친다 — 그 짝은 「자식 파이썬을 띄우는 파일은 `sys.executable` 을 쓴다」의 양성 대조였으므로, 같은 락 범위 안에서 여전히 자식 파이썬을 띄우는 파일(예: `git grep -n 'sys.executable' -- 'plugins/*/scripts/*.py'` 로 찾은 것)로 대상을 옮기고 그 이유를 주석 한 줄로 남긴다. 대상이 없으면 짝과 음의 락을 함께 지우고 그 사실을 SDD ledger 에 적는다.

- [ ] **Step 5: 통과를 확인한다**

```bash
bash ~/.claude/sdd-mirror/r7-impl/run_suite.sh ~/.claude/sdd-mirror/r7-impl/after-t6.txt
diff ~/.claude/sdd-mirror/r7-impl/baseline-before.txt ~/.claude/sdd-mirror/r7-impl/after-t6.txt
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | tail -3
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py
```
새 FAIL 이름 0. `test_review_hook_removed.py` 는 `hook_common` 에서 빠진 이름(`fire_and_forget_gc` · `GC_SCRIPT`)을 레포 전체 금지 토큰으로 도출한다 — 기존 RED(roadmap.md:166) 밖의 새 적중이 없어야 한다. 사라진 테스트 파일이 `# guards:` 글롭의 유일 대상이었는지 guards 락 결과로 확인한다.

- [ ] **Step 6: 변이(AC10)** — `hooks/hooks.json` 을 되살린다(`git checkout HEAD~1 -- plugins/spec-distill/hooks/hooks.json` 대신 빈 파일 생성) → 음의 락 RED; `hook_common.py` 에서 `_yaml_scalar` 를 지운다 → 양의 짝 RED. 복원 뒤 `git diff HEAD --stat` 이 비었는지 확인, `mutation.md` 기록.

- [ ] **Step 7: 커밋한다** — `refactor(spec-distill): SessionEnd 훅과 TTL-GC 를 걷는다`(`git rm` 한 경로 포함, 경로 지정).

---

### Task 7: 리뷰 진입 배선 — spec-review · reviewing-brief · finishing B-A

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` — 새 절 `### 원장 열기 — 라운드마다 선결 앞`(펜스 `<!-- ledger-open:begin/end -->` · `<!-- ledger-takeover:begin/end -->`), `## 절차` 에 쓰기 전 확인 규칙과 `<!-- ledger-guard:begin/end -->` 한 줄 펜스, `<!-- advice-display -->` 를 끝맺음 펜스로(acquire → check → advice → release), `### 대상 부재` 에 `<!-- ledger-release:begin/end -->`
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md` — 같은 원장 열기 · 넘겨받기 펜스(머리 블록 변수명 `$PR` · `$PAYLOAD`), `## 절차` 의 쓰기 전 확인 규칙(같은 한 줄, 변수만 다름), 「이 skill 은 표지를 풀지 않는다 — Step B 의 B-A 가 마지막 원장 쓰기 뒤에 푼다」 한 문장
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` B-A 펜스 — 끝맺음 펜스로
- Create: `plugins/spec-distill/tests/test_ledger_wiring.sh` (100755)

**Interfaces:**
- Consumes: Task 4 CLI(`acquire` 의 `acquired`/`held`/rc 3, `check` rc, `release`, `takeover`, `resume-note`), Task 5 `ledger_sweep.py --root`.
- Produces: 펜스 판결 줄 `ledger-open: HELD` · `ledger-open: OTHER:<sid>` · `ledger-open: NO_SESSION` · `ledger-open: NO_DIR` · `ledger-open: ERROR`(마지막 줄). 쓰기 전 확인 한 줄(리터럴, `<var>` 는 그 skill 의 세션 변수):
  `python3 "$SD/scripts/ledger_marker.py" check --dir "$STATE_DIR" --session "$harness_sid" || { echo "[spec-distill] 원장 쓰기를 멈췄다 — 이 문서의 리뷰 표지가 이 세션 것이 아니다(위 사유). 이어 가려면 원장 열기의 표지 질문에서 「이어 씀」을 고른다."; exit 3; }`
  (reviewing-brief 는 `$PR`, request-framing 은 `--session "$sid"` — Task 8)

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_ledger_wiring.sh`. 펜스는 마커 주석으로 뽑아 실제로 돌린다. 머리:

```bash
#!/usr/bin/env bash
# R7 §2-2 · §2-4 · §3-2 — 리뷰 진입 펜스의 표지 · 정리 배선 (AC7 · AC8 · AC10 양의 짝).
set -u
ROOT_REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT_REPO/plugins/spec-distill"
. "$ROOT_REPO/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)"; [ -n "$T" ] && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
T="$(cd "$T" && pwd -P)"; trap 'rm -rf "$T"' EXIT

fence() {   # fence <파일> <마커 이름> → 그 마커 사이 첫 bash 펜스 본문
  awk -v b="<!-- $2:begin -->" -v e="<!-- $2:end -->" '
    index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$1"
}
SR="$SD/skills/spec-review/SKILL.md"; RB="$SD/skills/reviewing-brief/SKILL.md"
FIN="$SD/skills/spec-interview/references/finishing.md"

repo="$T/repo"; mkdir -p "$repo/docs" && git -C "$repo" init -q
doc="$repo/docs/a-design.md"; printf '# A\n' > "$doc"
run_open() {   # run_open <sid> → 원장 열기 펜스 출력
  ( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID="$1" DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      bash -c "spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1 )
}
```

케이스(같은 파일에 이어서):

```bash
o1="$(run_open sess-aaaa1111)"
assert_eq "$(printf '%s\n' "$o1" | tail -n 1)" "ledger-open: HELD" "AC8: 빈 원장에서 원장 열기가 표지를 잡는다"
SDIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$repo/.claude/spec-distill" --doc "$doc")"
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-aaaa1111" "AC8: 표지가 원장 폴더에 세션 id 한 줄로 선다"
o2="$(run_open sess-bbbb2222)"
assert_eq "$(printf '%s\n' "$o2" | tail -n 1)" "ledger-open: OTHER:sess-aaaa1111" "AC8: 다른 세션의 표지가 있으면 멈추고 그 세션을 댄다"
grep -qF '「그만둠 (권장)」' "$SR" && grep -qF '「이어 씀 — 표지를 내 것으로 바꾼다」' "$SR" \
  && ok "AC8: OTHER 판결이 그만둠/이어 씀 질문으로 간다(문면)" || no "AC8: 표지 질문 문면이 없다"
o3="$(cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" bash -c "unset CLAUDE_CODE_SESSION_ID DEVBREW_SPEC_DISTILL_SESSION_ID; spec_path='$doc'
$(fence "$SR" ledger-open)" 2>&1)"
assert_eq "$(printf '%s\n' "$o3" | tail -n 1)" "ledger-open: NO_SESSION" "§2-4: 세션 id 가 없으면 리뷰를 시작하지 않는다"

# AC7 — 이어 감 줄 두 분기
printf -- '---\ndocreview:\n  doc: %s\n  profile: design-doc\n  round: 2\n---\n# x\n' "$doc" > "$SDIR/docreview-state.md"
python3 "$SD/scripts/ledger_marker.py" release --dir "$SDIR" --session sess-aaaa1111 >/dev/null
o4="$(run_open sess-cccc3333)"
printf '%s\n' "$o4" | grep -qF "[spec-distill] 이전 리뷰 라운드 2 에서 이어 간다 — $SDIR" \
  && ok "AC7: 다른 세션이 이어 받으면 이어 감 줄이 난다" || no "AC7: 이어 감 줄이 없다: $o4"
o5="$(run_open sess-cccc3333)"
printf '%s\n' "$o5" | grep -qF "이전 리뷰 라운드" && no "AC7: 같은 세션의 다음 라운드에서 이어 감 줄이 났다" \
  || ok "AC7: 같은 세션의 다음 라운드에서는 이어 감 줄이 없다"

# AC8 — 넘겨받기 뒤 넘겨준 세션의 쓰기가 멈추고 원장이 그대로다
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-dddd4444 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-dddd4444 \
    bash -c "spec_path='$doc'
$(fence "$SR" ledger-takeover)" >/dev/null 2>&1 )
assert_eq "$(cat "$SDIR/reviewing-by")" "sess-dddd4444" "AC8: 「이어 씀」 뒤 표지가 바뀐다"
before="$(cksum < "$SDIR/docreview-state.md")"
guard="$(fence "$SR" ledger-guard)"
( cd "$repo" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-cccc3333 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-cccc3333 \
    bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 남의 표지 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 남의 표지 — 원장 파일이 바뀌지 않았다"
rm -f "$SDIR/reviewing-by"
( cd "$repo" && bash -c "SD='$SD'; STATE_DIR='$SDIR'; harness_sid=sess-cccc3333
$guard
python3 \"\$SD/scripts/docreview_state.py\" begin-round --state-dir \"\$STATE_DIR\" --snapshot /dev/null" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "3" "AC8: 표지 없음 — 쓰기 전 확인이 rc 3 으로 멈춘다"
assert_eq "$(cksum < "$SDIR/docreview-state.md")" "$before" "AC8: 표지 없음 — 원장 파일이 바뀌지 않았다"

# AC8 — 원장에 쓰는 명령마다 같은 펜스 안 앞에 확인이 있다(정적). request-framing 은 Task 8 이 이 목록에 더한다.
WRITERS='docreview_state\.py" (init|begin-round|record-findings|decide|fix|ask|defer|observe-diff|advice)|docreview_route\.py" (prepare-recritic|finalize)|docreview_anchor\.py" check-intent'
GUARDED="$SR $RB $FIN"
for f in $GUARDED; do
  python3 -I - "$f" "$WRITERS" <<'PY' && ok "AC8: $(basename "$(dirname "$f")")/$(basename "$f") — 원장 쓰기 명령 앞에 확인이 있다" || no "AC8: $f — 확인 없는 원장 쓰기"
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
w = re.compile(sys.argv[2]); g = 'ledger_marker.py" check --dir "$STATE_DIR"'
bad = []
for body in re.findall(r"^```bash\n(.*?)^```$", text, re.S | re.M):
    for i, line in enumerate(body.splitlines()):
        if w.search(line) and g not in "\n".join(body.splitlines()[:i]):
            bad.append(line.strip()[:120])
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY
done

# AC8 — 해제는 게이트 응답 기록 뒤(문면 순서) · 끝맺음 펜스가 release 로 끝난다
adv="$(fence "$SR" advice-display)"
printf '%s\n' "$adv" | grep -qF 'ledger_marker.py" acquire' && printf '%s\n' "$adv" | tail -n 3 | grep -qF 'ledger_marker.py" release' \
  && ok "AC8: spec-review 끝맺음 펜스가 acquire 로 시작해 release 로 끝난다" || no "AC8: spec-review 끝맺음 펜스 꼴"
python3 -I - "$SR" <<'PY' && ok "AC8: 해제가 finalize · 게이트 응답 반영 뒤에 온다(문면 순서)" || no "AC8: 해제 문면 순서"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
a = t.find("응답을 `decide`·`fix`·`ask` 서브커맨드로 반영한다"); r = t.find("<!-- advice-display:begin -->")
sys.exit(0 if 0 <= a < r else 1)
PY
finb="$(fence "$FIN" advice-ba)"
printf '%s\n' "$finb" | tail -n 3 | grep -qF 'ledger_marker.py" release' && ok "AC8: finishing B-A 가 release 로 끝난다" || no "AC8: finishing B-A 해제 없음"
grep -qF 'ledger_marker.py" release' "$RB" && no "AC8: reviewing-brief 가 스스로 표지를 푼다(B-A 가 푼다)" || ok "AC8: reviewing-brief 는 표지를 풀지 않는다"

# AC10 양의 짝 — 리뷰 진입이 ledger_sweep.py 를 부른다. request-framing 은 Task 8 이 이 목록에 더한다.
SWEEPERS="$SR $RB"
for f in $SWEEPERS; do
  fence "$f" ledger-open | grep -qF 'ledger_sweep.py" --root "$ROOT"' && ok "AC10: $(basename "$(dirname "$f")") 원장 열기가 정리를 부른다" || no "AC10: $f 정리 호출 없음"
done
summary
```

(마지막 줄은 `assert.sh` 의 실제 요약 함수 이름으로 — 다른 테스트의 끝줄을 보고 맞춘다. 이 Task 의 커밋 시점에 이 파일은 전부 GREEN 이어야 한다 — request-framing 은 Task 8 이 `GUARDED` · `SWEEPERS` 에 더한다.)

- [ ] **Step 2: RED 를 확인한다** — `bash plugins/spec-distill/tests/test_ledger_wiring.sh 2>&1 | grep -E '✗|Total'`.

- [ ] **Step 3: spec-review 에 펜스를 넣는다** — `## 프로필` 바로 앞에 새 절:

````markdown
### 원장 열기 — 라운드마다 선결 앞

절차서의 선결(`mkdir -p` · `init`) 앞에 매 라운드 이 펜스를 같은 Bash 호출 앞에 이어 붙여 돈다. 펜스 앞에
`spec_path='<「## 입력」에서 절대 경로로 바꾼 설계문서 경로>'` 한 줄을 붙인다. 마지막 줄이 판결이다.

<!-- ledger-open:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "${spec_path:-}" || true)"
if [ -z "$harness_sid" ]; then
  echo "[spec-distill] 세션 id 를 얻지 못해 동시 리뷰 표지를 잡을 수 없다 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
  echo "ledger-open: NO_SESSION"
elif [ -z "$STATE_DIR" ] || ! mkdir -p "$STATE_DIR" 2>/dev/null; then
  echo "[spec-distill] 원장 자리를 열지 못했다(STATE_DIR='${STATE_DIR:-}') — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)."
  echo "ledger-open: NO_DIR"
else
  python3 "$SD/scripts/ledger_marker.py" resume-note --dir "$STATE_DIR" --session "$harness_sid"
  m_rc=0; m_out="$(python3 "$SD/scripts/ledger_marker.py" acquire --dir "$STATE_DIR" --session "$harness_sid")" || m_rc=$?
  if [ "$m_rc" -eq 0 ]; then
    [ "$m_out" != acquired ] || python3 "$SD/scripts/ledger_sweep.py" --root "$ROOT" || echo "[spec-distill] 원장 정리가 실패했다 — 리뷰는 계속한다."
    echo "ledger-open: HELD"
  elif [ "$m_rc" -eq 3 ]; then
    echo "[spec-distill] 다른 세션(${m_out})이 이 문서를 리뷰하고 있다 — ${STATE_DIR}"
    echo "ledger-open: OTHER:${m_out}"
  else
    echo "[spec-distill] 동시 리뷰 표지를 잡지 못했다(rc ${m_rc}) — 리뷰 없이 끝났다."
    echo "ledger-open: ERROR"
  fi
fi
```
<!-- ledger-open:end -->

| 마지막 줄 | 동작 |
|---|---|
| `ledger-open: HELD` | 선결로 간다 |
| `ledger-open: OTHER:<sid>` | 멈추고 `AskUserQuestion` 하나 — 「그만둠 (권장)」/「이어 씀 — 표지를 내 것으로 바꾼다」. 이어 씀이면 아래 넘겨받기 펜스를 돈 뒤 이 펜스를 다시 돈다. 그만둠이면 `### 대상 부재` 처럼 게이트 없이 끝난다 |
| `ledger-open: NO_SESSION` · `NO_DIR` · `ERROR` | 그 `[spec-distill]` 줄을 보이고 게이트 없이 끝난다(`### 대상 부재` 의 하위 경우) |

<!-- ledger-takeover:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석" >&2; exit 1; }
harness_sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
ROOT="$(python3 "$SD/scripts/state_path.py" state-root || true)"
STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "${spec_path:-}" || true)"
[ -n "$harness_sid" ] && [ -n "$STATE_DIR" ] && python3 "$SD/scripts/ledger_marker.py" takeover --dir "$STATE_DIR" --session "$harness_sid"
```
<!-- ledger-takeover:end -->

이 펜스는 사용자가 「이어 씀」을 고른 뒤에만 돈다.
````

`## 절차` 의 「`--state-dir` 는 위 `$STATE_DIR` 이고 …」 문단 뒤에:

````markdown
**원장 쓰기 전 확인.** 절차서의 원장 쓰기 명령 — `docreview_state.py` 의 `init` · `begin-round` ·
`record-findings` · `decide` · `fix` · `ask` · `defer` · `observe-diff` · `advice`, `docreview_route.py` 의
`prepare-recritic` · `finalize`, `docreview_anchor.py check-intent` — 은 전부 같은 Bash 호출 안에서 아래 한 줄
**다음에만** 부른다. rc 가 0 이 아니면 그 명령을 부르지 않고 사유를 보이고 멈춘다 — 다른 세션이 표지를 넘겨받았거나
표지가 없다.

<!-- ledger-guard:begin -->
```bash
python3 "$SD/scripts/ledger_marker.py" check --dir "$STATE_DIR" --session "$harness_sid" || { echo "[spec-distill] 원장 쓰기를 멈췄다 — 이 문서의 리뷰 표지가 이 세션 것이 아니다(위 사유). 이어 가려면 원장 열기의 표지 질문에서 「이어 씀」을 고른다."; exit 3; }
```
<!-- ledger-guard:end -->
````

`<!-- advice-display -->` 펜스: `STATE_DIR=` 줄 다음, 첫 `if` 앞에

```bash
lm_rc=0
if [ -n "${STATE_DIR:-}" ] && [ -d "$STATE_DIR" ] && [ -n "${harness_sid:-}" ]; then
  python3 "$SD/scripts/ledger_marker.py" acquire --dir "$STATE_DIR" --session "$harness_sid" >/dev/null || lm_rc=$?
fi
```

를 넣고, 기존 `if [ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]; then` 다음에 분기 하나를 더한다:

```bash
elif [ "$lm_rc" -ne 0 ]; then
  echo "[spec-distill] 참고(advisory) 목록 건너뜀 — 이 원장의 표지가 다른 세션 것이다(rc ${lm_rc}). 박제 · 계수 · 표시를 하지 않는다."
```

`else` 분기 첫 줄에 쓰기 전 확인 한 줄(위 리터럴)을 넣고, 펜스 맨 끝(`fi` 뒤)에

```bash
[ -z "${STATE_DIR:-}" ] || [ ! -d "$STATE_DIR" ] || [ -z "${harness_sid:-}" ] || python3 "$SD/scripts/ledger_marker.py" release --dir "$STATE_DIR" --session "$harness_sid"
```

를 둔다. 펜스 앞 산문에 한 문장: 「이 펜스가 이 리뷰의 마지막 원장 쓰기다 — 표지를 잡아(이미 잡았으면 그대로) 쓰고 끝에서 푼다. ③ 으로 다음 라운드를 돌면 원장 열기가 다시 잡는다.」

`### 대상 부재` 의 인용 문면 뒤에: 「원장 열기가 표지를 잡은 뒤 이 경로로 끝나면 아래 펜스로 푼다(남의 표지는 풀지 않는다).」 + `<!-- ledger-release:begin -->` 펜스(머리 세 줄 + `[ -n "$harness_sid" ] && [ -n "$STATE_DIR" ] && [ -d "$STATE_DIR" ] && python3 "$SD/scripts/ledger_marker.py" release --dir "$STATE_DIR" --session "$harness_sid"`).

- [ ] **Step 4: reviewing-brief · finishing 에 넣는다** — reviewing-brief: `## 진입 게이트 — 매 라운드, 번들보다 먼저` 바로 앞에 `### 원장 열기 — 라운드마다 선결 앞` 절을 spec-review 와 같은 펜스로 둔다. 다른 점: 루트 변수 `PR`, 문서 변수 `"${PAYLOAD:-}"`(머리의 상대경로 절대화 두 줄 포함), 실패 문면의 복귀 지시는 「record(`pipeline` / `all` / `unavailable`, reason = <판결>)를 남기고 Step B 로 돌아간다」, OTHER 의 「그만둠」 도 같은 record 로 Step B. 펜스 이름 `ledger-open` · `ledger-takeover` 는 같다. `## 절차` 에 같은 「원장 쓰기 전 확인」 문단과 `ledger-guard` 펜스(`$PR` 대신 `$SD` 를 쓰지 않도록 `python3 "$PR/scripts/ledger_marker.py" check …`; 단 Step 1 의 정적 단언 문자열 `ledger_marker.py" check --dir "$STATE_DIR"` 는 그대로 맞는다). 표지 해제 문장: 「이 skill 은 표지를 풀지 않는다 — 이 원장의 마지막 쓰기는 Step B 의 참고 목록(B-A)이고, 그 펜스가 쓴 뒤 푼다.」

finishing.md B-A: 펜스 앞뒤에 `<!-- advice-ba:begin -->` · `<!-- advice-ba:end -->` 마커를 달고 spec-review 끝맺음 펜스와 같은 세 조각(acquire · 표지 분기 · 쓰기 전 확인 · 끝의 release)을 넣는다. 「리뷰가 skip 됐거나 세션 정리로 걷혔다」 문구는 「리뷰가 skip 됐거나 원장이 정리됐다」로.

- [ ] **Step 5: 통과를 확인한다** — `bash plugins/spec-distill/tests/test_ledger_wiring.sh` 전부 GREEN, `run_suite.sh` 후 baseline 과 FAIL 이름 비교(새 실패 0), `bash shared/tests/test_skill_body_no_positional_tokens.sh` · `bash shared/tests/test_inline_python_isolated.sh` · `bash shared/tests/test_dispatch_disposition.sh` 통과.

- [ ] **Step 6: 변이(AC8 배선)** — spec-review `ledger-guard` 펜스의 `|| { …; exit 3; }` 를 지운다 → 남의 표지 · 표지 없음 칸 RED; advice-display 끝의 release 를 펜스 맨 앞으로 옮긴다 → 끝맺음 꼴 칸 RED; `ledger-open` 의 `[ "$m_out" != acquired ] ||` 를 `[ "$m_out" = acquired ] ||` 로 반전 → (정리 호출은 남으므로 AC10 칸은 GREEN 이어야 한다 — 이 변이는 정리 «횟수»를 재지 않는다는 한계를 `mutation.md` 에 적는다). 기록.

- [ ] **Step 7: 커밋한다** — `chmod +x plugins/spec-distill/tests/test_ledger_wiring.sh` 후 `feat(spec-distill): 리뷰 진입이 원장 표지를 잡고 쓰기 전에 확인한다`.

---

### Task 8: request-framing — 이름 파일 제거 · 원장 배선

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md` (`## 워크트리` 의 이름 파일 문장, `## 상태` 표 · 블록, `### 절차` 슬롯, 처분 · 답 기록 펜스, `### 게이트 직전` 의 계수 기록 펜스, `## degrade 채널` 의 STATE 언급)
- Modify(테스트): `test_seed_gate_wiring.sh` · `test_framing_review_contract.sh` · `test_request_framing_entry.sh` · `test_seed_codex_axes.sh` 등 `git grep -n 'interview-basename\|NAME_FILE\|SEED_DIR' -- plugins/spec-distill/tests` 가 내는 파일
- Test: `test_ledger_wiring.sh` 의 request-framing 칸(Task 7) + 새 단언(아래)

**Interfaces:**
- Consumes: Task 2 `interview_state.py seed-audit-for-session`, Task 4 · 5 CLI, Task 7 의 펜스 꼴.
- Produces: `## 상태` 블록이 `IV_NAME` 을 audit frontmatter `session_id` 로 되찾는다. `$STATE`(세션의 `state.local.md`) · `$SEED_DIR` · `$NAME_FILE` 이 없다. `ledger_rc=1` 고정(Phase 0 에는 상태 파일이 없다 — `no-state-in-phase-0`).

- [ ] **Step 1: 실패하는 단언을 쓴다** — `test_ledger_wiring.sh` 의 `GUARDED="$SR $RB $FIN"` 을 `GUARDED="$SR $RB $FIN $SD/skills/request-framing/SKILL.md"` 로, `SWEEPERS="$SR $RB"` 를 `SWEEPERS="$SR $RB $SD/skills/request-framing/SKILL.md"` 로 바꾸고, 마지막 요약 줄 **앞에** 붙인다:

```bash
RF="$SD/skills/request-framing/SKILL.md"
grep -qF 'interview-basename' "$RF" && no "AC11: request-framing 에 interview-basename 이 남았다" || ok "AC11: interview-basename 이 없다"
grep -qF 'interview_state.py" seed-audit-for-session --session "$sid"' "$RF" \
  && ok "AC11 양의 짝: audit session_id 로 이름을 되찾는다" || no "AC11: 이름 되찾기 호출이 없다"
grep -qE '^STATE="\$ROOT/\$sid/state\.local\.md"' "$RF" && no "§1-6: request-framing 의 세션 STATE 줄이 남았다" || ok "§1-6: 세션 STATE 줄이 없다"
# 상태 블록 실행 — 같은 세션 seed audit 둘이면 이름을 만들지 않는다
blk="$(awk '/^## 상태/{f=1} f&&/^```bash$/{c=1;next} c&&/^```$/{exit} c' "$RF")"
rfr="$T/rf"; mkdir -p "$rfr/docs/superpowers/interview" && git -C "$rfr" init -q
for n in a b; do printf -- '---\ntype: interview-seed-audit\nsession_id: sess-rf000001\n---\n' > "$rfr/docs/superpowers/interview/2026-10-15-$n-interview.audit.md"; done
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000001 bash -c "$blk
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[]' && ok "AC11: 같은 세션 seed audit 이 둘이면 이름을 만들지 않는다" || no "AC11: 둘 이상에서 이름을 골랐다: $out"
rm -f "$rfr/docs/superpowers/interview/2026-10-15-b-interview.audit.md"
out="$(cd "$rfr" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-rf000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-rf000001 bash -c "$blk
echo \"SEED=[\$SEED]\"" 2>&1)"
printf '%s\n' "$out" | grep -qF 'SEED=[docs/superpowers/interview/2026-10-15-a-interview.md]' \
  && ok "AC11: 하나면 그 이름을 되찾는다" || no "AC11: 이름을 되찾지 못했다: $out"
```

- [ ] **Step 2: RED 확인** — 위 칸과 새로 목록에 든 request-framing 의 정적 확인 · 정리 호출 칸이 `✗`.

- [ ] **Step 3: `## 상태` 블록을 다시 쓴다** — `STATE=` 줄과 `SEED_DIR` · `NAME_FILE` 덩어리, `TOPIC` 아래 `case` 의 이름 파일 쓰기를 다음으로 바꾼다(주석은 짧게, 그 자리의 기존 설명 중 남는 사실만):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"
# 두 산출 문서의 이름. 첫 라운드는 TOPIC 으로 정하고, audit 을 처음 쓸 때 frontmatter `session_id` 에 이 세션 id 를
# 적는다. 그 뒤로는 그 audit 에서 되찾는다 — 이 블록을 다시 돌리면 같은 두 경로가 나온다.
TOPIC="<kebab-topic>"
IV_NAME=""
if [ -z "$sid" ]; then
  echo "[spec-distill] 세션 id 를 얻지 못했다 — 이름을 되찾을 수 없어 두 경로를 만들지 않는다. 아래 가드들이 이름을 대고 멈춘다." >&2
else
  f_rc=0; IV_NAME="$(python3 "$SD/scripts/interview_state.py" seed-audit-for-session --session "$sid")" || f_rc=$?
  if [ "$f_rc" -eq 1 ]; then
    case "$TOPIC" in
      ""|*"<"*|*">"*|*/*|*[[:space:]]*) IV_NAME="" ;;
      *) IV_NAME="$(date +%F)-${TOPIC}-interview" ;;
    esac
  elif [ "$f_rc" -ne 0 ]; then
    IV_NAME=""
    echo "[spec-distill] 이 세션의 seed audit 이 둘 이상이다(위 경로들) — 이름을 고르지 않고 멈춘다." >&2
  fi
fi
AUDIT=""
SEED=""
case "$IV_NAME" in
  ""|*/*|*"<"*|*">"*|*[[:space:]]*)
    echo "[spec-distill] 인터뷰 문서 이름을 못 구했다 (IV_NAME='$IV_NAME'). 첫 라운드면 이 블록의 TOPIC 을 요청 주제(공백 없는 kebab-case)로 바꿔 다시 돌려라 — audit 을 쓴 뒤에는 그 audit 의 session_id 로 되찾는다." >&2 ;;
  *)
    AUDIT="docs/superpowers/interview/$IV_NAME.audit.md"
    SEED="docs/superpowers/interview/$IV_NAME.md" ;;
esac
SEED_ABS=""; AUDIT_ABS=""; STATE_DIR=""
if [ -n "$SEED" ]; then
  SEED_ABS="$(pwd)/$SEED"; AUDIT_ABS="$(pwd)/$AUDIT"
  STATE_DIR="$(python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$ROOT" --doc "$SEED_ABS" || true)"
fi
```

이어지는 `PROFILE=` · `BUNDLE` … `SEED_BASE` 는 그대로, `ledger_rc` 덩어리는 `ledger_rc=1   # Phase 0 에는 상태 파일이 없다 — degrade 는 no-state-in-phase-0 경로로 간다` 한 줄로 바꾼다. 표에서 `interview-basename` 행과 `$SEED_DIR` 행을 지우고, audit 행의 「언제」에 「첫 write 때 frontmatter `session_id: <sid>` 를 적는다 — 이후 라운드의 이름 되찾기가 그 값을 본다」 를 더한다. 「만들지 않는 것: `state.local.md`」 문단은 「만들지 않는 것: 세션 폴더와 그 안의 파일. `.claude/spec-distill/` 에는 리뷰 원장(`.docreview/`)만 생긴다」 로. 「이 블록이 경로의 유일한 도출 지점입니다」 문단의 변수 목록에서 `$STATE`·`$SEED_DIR` 를 뺀다. `## 워크트리` 의 「이름 파일(`interview-basename`)은 세션 디렉토리(main repo 의 state root)에 있어 cwd 이동과 무관하다.」 → 「이름은 audit 의 `session_id` 로 되찾으므로, audit 을 처음 쓰기 전에 워크트리로 옮기면 그 뒤의 되찾기는 워크트리의 docs 를 본다.」

- [ ] **Step 4: 원장 배선** — `### 절차` 의 슬롯 목록 첫 항목 앞에 「매 라운드 선결 앞에 `### 원장 열기` 펜스를 돈다」 한 줄과, 같은 위치에 `### 원장 열기 — 라운드마다 선결 앞` 절(Task 7 의 spec-review 펜스와 같은 꼴, 세션 변수 `sid`, 문서 `"$SEED_ABS"`, 경로 도출은 「## 상태 블록을 앞에 이어 붙인다」로 대신 — 펜스 본문은 `if [ -z "$sid" ]` 부터), 넘겨받기 펜스, 「원장 쓰기 전 확인」 문단 + `ledger-guard` 펜스(`--session "$sid"`)를 둔다. 슬롯 항목 「선결 `init` 앞에 `mkdir -p "$STATE_DIR"`」 은 그대로 둔다. 처분 펜스 · 답 기록 펜스의 엔진 호출 앞, 각 펜스 첫 줄에 쓰기 전 확인 한 줄을 둔다. `### 게이트 직전` 의 계수 기록 펜스를 끝맺음 펜스로 바꾼다(acquire → 표지 분기 → 확인 → advice → release; 마커 `<!-- framing-count:begin/end -->`). codex 펜스의 R-e 는 Task 3 에서 끝났다.

- [ ] **Step 5: 통과를 확인한다** — `test_ledger_wiring.sh` 전부 GREEN, `run_suite.sh` 비교 새 실패 0, `test_framing_review_contract.sh` · `test_seed_gate_wiring.sh` · `test_request_framing_entry.sh` GREEN.

- [ ] **Step 6: 변이(AC11)** — `seed-audit-for-session` 의 `type` 조건을 지운다(같은 세션 인터뷰 audit 이 걸린다 — Task 2 의 `test_interview_audit_of_same_session_is_ignored` RED); 상태 블록의 `elif [ "$f_rc" -ne 0 ]` 분기를 지운다 → 둘 이상 칸 RED. 기록.

- [ ] **Step 7: 커밋한다** — `feat(spec-distill): request-framing 이 이름 파일 없이 audit 의 session_id 로 이름을 되찾는다`.

---

### Task 9: spec-interview 의 인터뷰 상태 파일

**Files:**
- Create: `plugins/spec-distill/skills/spec-interview/references/state-file.md`
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` — `## 진입 단계` 에 `### 2.5 상태 파일` (펜스 `<!-- interview-state-entry:begin/end -->` + 판결 표 + reference 포인터), `## State location` 첫 줄, `### State write contract (PN1 — worktree-safe)` 절 삭제, `## In-flight state migration` 절을 두 줄 포인터로 압축, `## kill switch` 첫 항목의 `state.local.md` 문장
- Modify: `skills/spec-interview/references/finishing.md` — 머리의 「state.local.md에 쓰는 동시에」, Step A 2 경로(상태 파일 이름에서 도출), B-0 카운터 펜스(`STATE` = 상태 파일 · PN1 문구 제거), B-2 「하류·SessionEnd 가 cleanup」, B-3 ①/② 의 커밋 펜스 `<!-- interview-commit:begin/end -->`, ④ 의 「state는 SessionEnd hook이 cleanup」
- Modify: `skills/spec-interview/references/state-migration.md` — 「state.local.md 로드 시」 → 「상태 파일 로드 시」, 영속화 시점의 「Bash 전체-frontmatter write … (PN1)」 → 「상태 파일에 바로 쓴다(`Write`/`Edit`)」, 실패 시 「state.local.md 보존」 → 「상태 파일 보존」
- Modify: `skills/reviewing-brief/SKILL.md` 머리 블록 전부 — `STATE="${harness_sid:+$ROOT/$harness_sid/state.local.md}"` → `STATE="${PAYLOAD:+${PAYLOAD%-interview.md}-interview.state.md}"   # degrade 원장 — 그 인터뷰의 상태 파일`, `DEGRADE_FALLBACK_FILE` 은 `STATE_DIR=` 줄 **뒤로** 옮겨 `DEGRADE_FALLBACK_FILE="${STATE_DIR:+$STATE_DIR/brief-degrade-fallback.txt}"; mkdir -p "${DEGRADE_FALLBACK_FILE%/*}" 2>/dev/null || true` (그다음 `touch … || DEGRADE_FALLBACK_FILE=…` 줄은 그대로)
- Modify: `scripts/check_verbatim_coverage.py`(docstring 4행 · usage 389행의 `state.local.md` → `<상태 파일>`), `templates/interview-audit-template.md`(17행)
- Test: 새 `plugins/spec-distill/tests/test_interview_state_flow.sh` (100755) — AC2 · AC3 · AC5 · AC12 문면 + 펜스 실행

**Interfaces:**
- Consumes: Task 1 `state_path.py interview-state`, Task 2 `interview_state.py entry` · `migrate-legacy`.
- Produces: 상태 파일 frontmatter 첫 두 키 `type: interview-state` · `seed: <상대경로|없음>`; brief/audit 경로 = 상태 파일 이름에서 `.state.md` 를 뗀 `<줄기>` + `.md` / `.audit.md`; 끝내기 커밋 펜스.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_interview_state_flow.sh`(머리는 Task 7 의 `test_ledger_wiring.sh` 와 같은 꼴, `fence` 함수 포함). 케이스:

```bash
SK="$SD/skills/spec-interview/SKILL.md"; SF="$SD/skills/spec-interview/references/state-file.md"
FIN="$SD/skills/spec-interview/references/finishing.md"

# AC2 — production 표면의 state.local.md 는 §1-7 이월 문면과 정리 코드에만
hits="$(cd "$ROOT_REPO" && git grep --untracked -lF 'state.local.md' -- plugins/spec-distill/skills plugins/spec-distill/references plugins/spec-distill/scripts plugins/spec-distill/templates | sort)"
want="$(printf '%s\n' plugins/spec-distill/scripts/interview_state.py plugins/spec-distill/scripts/ledger_sweep.py plugins/spec-distill/skills/spec-interview/references/state-file.md | sort)"
assert_eq "$hits" "$want" "AC2: state.local.md 는 이월 문면(state-file.md) · interview_state.py · ledger_sweep.py 에만"
grep -cF 'state.local.md' "$SF" | grep -qx 1 && ok "AC2: state-file.md 의 옛 이름은 §1-7 이월 문단 하나에만" || no "AC2: state-file.md 의 옛 이름 횟수"

# AC3 — 진입 펜스 판결 · 상태 파일 첫 키
iv="$T/iv"; mkdir -p "$iv/docs/superpowers/interview" && git -C "$iv" init -q
D="$iv/docs/superpowers/interview"
printf -- '---\ntype: interview-state\nseed: 없음\n---\n## R1\n' > "$D/2026-10-15-t-interview.state.md"
ent() { ( cd "$iv" && CLAUDE_PLUGIN_ROOT="$SD" CLAUDE_CODE_SESSION_ID=sess-iv000001 DEVBREW_SPEC_DISTILL_SESSION_ID=sess-iv000001 \
          bash -c "ARG_PATH='$1'
$(fence "$SK" interview-state-entry)" 2>/dev/null | tail -n 1 ); }
assert_eq "$(ent "$D/2026-10-15-t-interview.state.md")" "interview-state: RESUME $D/2026-10-15-t-interview.state.md" "AC3: @<…>.state.md 는 이어 가는 분기"
grep -qF '`interview-state: RESUME <경로>`' "$SK" && ok "AC3: SKILL 판결 표에 RESUME 행" || no "AC3: SKILL 판결 표에 RESUME 행이 없다"
printf -- '---\ntype: interview-seed\n---\n' > "$D/2026-10-15-s-interview.md"
printf -- '---\ntype: interview-seed-audit\n---\n' > "$D/2026-10-15-s-interview.audit.md"
v="$(ent "$D/2026-10-15-s-interview.md")"
assert_eq "$v" "interview-state: NEW-SEED s-brief seed=docs/superpowers/interview/2026-10-15-s-interview.md" "AC3: seed 로 시작하면 주제에 -brief 꼬리"
p="$(cd "$iv" && python3 "$SD/scripts/state_path.py" interview-state --topic s-brief --date 2026-10-15)"
case "$p" in "$D/2026-10-15-s-brief-interview.state.md") ok "AC3: 같은 날 seed 와 겹치지 않는 경로";; *) no "AC3: 경로 $p";; esac
head -n 3 "$SF" >/dev/null
grep -qF 'type: interview-state' "$SF" && grep -qF 'seed: <' "$SF" && ok "AC3: state-file.md 가 첫 두 키를 정한다" || no "AC3: 첫 두 키 문면"

# AC4 — 이어 감/새로 시작 질문 문면 · 새로 시작은 지우지 않는다
grep -qF '「이어 감 (권장)」' "$SF" && grep -qF '「새로 시작」' "$SF" && grep -qF '기존 파일은 지우지 않는다' "$SF" \
  && ok "AC4: 질문 문면과 보존 문장" || no "AC4: 질문 문면"

# AC5 — 커밋은 B-3 확정 뒤 한 번(문면 순서) · Step A/A.5 · ③ 에 커밋 없음
python3 -I - "$FIN" <<'PY' && ok "AC5: 커밋 펜스 자리(문면 순서)" || no "AC5: 커밋 펜스 자리"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
a, a5, b3 = t.find("### Step A —"), t.find("### Step A.5"), t.find("#### B-3")
c = t.find("<!-- interview-commit:begin -->")
gate = t.find("`check_brief.py gate` 재실행(통과 확인)", b3)
three = t.find("- **③ 확정 목록 수정**", b3); four = t.find("- **④ brief만 종료**", b3)
nocommit = lambda s: "git commit" not in s and "interview-commit" not in s and "커밋 펜스" not in s
ok = (0 <= a < a5 < b3 < gate < c) and nocommit(t[a:b3]) and nocommit(t[three:four])
ok = ok and "interview-commit" in t[four:t.find("#### B-4")]
sys.exit(0 if ok else 1)
PY
```

커밋 펜스 실행 칸(같은 파일) — 기본 브랜치 · 기능 브랜치 · `origin/HEAD` 없음 · staged 다른 파일:

```bash
cf="$(fence "$FIN" interview-commit)"
mk() {   # mk <이름> → origin 을 가진 클론, docs 에 세 파일
  local o="$T/$1-origin.git" c="$T/$1"
  git init -q --bare -b main "$o"; git clone -q "$o" "$c" 2>/dev/null
  git -C "$c" config user.email t@t.t; git -C "$c" config user.name t
  git -C "$c" commit -q --allow-empty -m init; git -C "$c" push -q origin main 2>/dev/null
  git -C "$c" remote set-head origin main >/dev/null 2>&1
  mkdir -p "$c/docs/superpowers/interview"
  for s in .md .audit.md .state.md; do printf 'x\n' > "$c/docs/superpowers/interview/2026-10-15-t-interview$s"; done
  printf '%s' "$c"
}
c1="$(mk on-main)"
o="$(cd "$c1" && bash -c "BRIEF='$c1/docs/superpowers/interview/2026-10-15-t-interview.md'
$cf" 2>&1)"
assert_eq "$(git -C "$c1" rev-list --count HEAD)" "1" "AC5: 기본 브랜치에서는 커밋하지 않는다"
printf '%s\n' "$o" | grep -qF '브랜치에서 커밋하라' && printf '%s\n' "$o" | grep -qF '2026-10-15-t-interview.state.md' \
  && ok "AC5: 기본 브랜치 — 세 경로와 안내를 보인다" || no "AC5: 기본 브랜치 출력: $o"
c2="$(mk on-feature)"; git -C "$c2" switch -q -c feature/x
printf 'y\n' > "$c2/other.txt"; git -C "$c2" add other.txt
( cd "$c2" && bash -c "BRIEF='$c2/docs/superpowers/interview/2026-10-15-t-interview.md'
$cf" >/dev/null 2>&1 )
assert_eq "$(git -C "$c2" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' ')" \
  "docs/superpowers/interview/2026-10-15-t-interview.audit.md docs/superpowers/interview/2026-10-15-t-interview.md docs/superpowers/interview/2026-10-15-t-interview.state.md " \
  "AC5: 기능 브랜치 — 세 경로만 한 커밋으로"
git -C "$c2" diff --cached --name-only | grep -qx other.txt && ok "Review Focus: staged_other_stays_staged" || no "staged 다른 파일이 사라졌다"
c3="$(mk no-head)"; git -C "$c3" switch -q -c feature/y; git -C "$c3" remote set-head origin -d >/dev/null 2>&1
o="$(cd "$c3" && bash -c "BRIEF='$c3/docs/superpowers/interview/2026-10-15-t-interview.md'
$cf" 2>&1)"
assert_eq "$(git -C "$c3" rev-list --count HEAD)" "1" "AC5: origin/HEAD 가 없으면 커밋하지 않는다"
printf '%s\n' "$o" | grep -qF '기본 브랜치를 판정하지 못했다' && ok "AC5: 그 사유를 보인다" || no "AC5: 사유 없음: $o"

# AC12 — 옛 state.local.md 이월(펜스 + 스크립트)
mkdir -p "$iv/.claude/spec-distill/sess-iv000001"
printf -- '---\nsession_id: x\n---\n## R1\n' > "$iv/.claude/spec-distill/sess-iv000001/state.local.md"
assert_eq "$(ent "")" "interview-state: LEGACY $iv/.claude/spec-distill/sess-iv000001/state.local.md" "AC12: 옛 진행 기록이 있으면 LEGACY"
o="$(cd "$iv" && CLAUDE_CODE_SESSION_ID=sess-iv000001 python3 "$SD/scripts/interview_state.py" migrate-legacy --session sess-iv000001 --topic old --date 2026-10-15)"
printf '%s\n' "$o" | grep -qF "옛 위치의 진행 기록을 docs 로 옮겼다 — $D/2026-10-15-old-interview.state.md" \
  && ok "AC12: 옮기고 그 사실을 보인다" || no "AC12: $o"
grep -qF 'interview_state.py" migrate-legacy' "$SF" && ok "AC12: state-file.md 가 LEGACY 에서 이월을 부른다" || no "AC12: 이월 호출 문면 없음"
summary
```

(`git init --bare -b` 가 이 머신 git 에서 안 되면 `git init -q --bare` 뒤 `git -C "$o" symbolic-ref HEAD refs/heads/main` 으로 — 먼저 `git --version` 으로 확인.)

- [ ] **Step 2: RED 확인** — `bash plugins/spec-distill/tests/test_interview_state_flow.sh 2>&1 | grep -E '✗|Total'`.

- [ ] **Step 3: `references/state-file.md` 를 쓴다** — 절 다섯, 각 절은 행동에 필요한 것만(Self-narrating artifact 금지):

````markdown
## 인터뷰 상태 파일

이 인터뷰의 진행 기록(frontmatter 스키마 · `## R<n>` 라운드 기록 · 조사 원문 · `## audit §2 대기 줄`)은 작업 트리의
`docs/superpowers/interview/<날짜>-<주제>-interview.state.md` 한 파일에 산다. brief · audit 는 같은 줄기로 옆에 놓인다
(`<줄기>.md` · `<줄기>.audit.md`). 작업 트리 안이라 `Write` · `Edit` 로 고친다.

### 처음 만들 때

frontmatter 첫 두 키:

```yaml
type: interview-state
seed: <작업 트리 루트 기준 seed 상대경로 | 없음>
```

그 뒤에 SKILL `## State location` 의 스키마 키가 온다.

- 판결이 `interview-state: NEW-SEED <주제> seed=<상대경로>` 면 첫 라운드 **전에** 만든다 — `<주제>` 를 그대로 topic 으로,
  `seed=` 값을 `seed:` 로 쓴다.
- 판결이 `interview-state: NEW` 면 첫 라운드에서 주제를 정한 직후 만들고 그 라운드의 기록을 첫 내용으로 쓴다(그 전까지
  라운드 1 기록은 대화 안에만 있다). `seed:` 는 `없음`.
- 경로는 늘 스크립트가 낸다. rc 가 0 이 아니면 그 stderr 를 보이고 멈춘다(남의 파일 위에 시작하지 않는다):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — 경로를 추측하지 말고 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/state_path.py" interview-state --topic "<kebab 주제>"
```

  그 자리에 이미 `type: interview-state` 파일이 있으면 새로 쓰지 않는다 — topic 을 `<주제>-<HHMM>` 으로 바꿔 다시 낸다.

### 이어 갈 때

- `interview-state: RESUME <경로>` — 그 파일을 읽고 `state-migration.md` 의 스키마 이월을 적용한 뒤 마지막 라운드 다음부터 간다.
- `interview-state: ASK` — 앞 줄의 `candidate: <경로>` 가 같은 seed 의 끝나지 않은 상태 파일이다. `AskUserQuestion` 하나로
  「이어 감 (권장)」/「새로 시작」을 묻는다(후보가 둘 이상이면 이어 감 선택지를 후보마다 하나씩). 이어 감이면 RESUME 과 같다.
  새로 시작이면 topic 을 `<seed 주제>-brief-<HHMM>` 으로 바꿔 위 펜스로 새 경로를 낸다. 기존 파일은 지우지 않는다.
- 이어 갈 때는 고른 파일의 절대경로가 그 인터뷰의 정체다. brief · audit 경로는 그 이름에서 `.state.md` 를 떼어 도출하고,
  날짜 · 주제로 다시 계산하지 않는다.

### 옛 자리의 진행 기록

`interview-state: LEGACY <옛 경로>` 면 그 파일(이전 버전이 쓰던 `.claude/spec-distill/<session-id>/state.local.md`)을 읽어
주제를 정하고(기록에서 정하지 못하면 사용자에게 한 번 묻는다) 옮긴다. 출력 줄을 그대로 보인다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — 경로를 추측하지 말고 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
python3 "$SD/scripts/interview_state.py" migrate-legacy --session "$sid" --topic "<kebab 주제>" --seed "<seed 절대경로 — 없으면 이 인자를 뺀다>"
```

옮긴 뒤에는 RESUME 과 같다.

### 끝낼 때

brief · audit · 상태 파일 셋은 `finishing.md` B-3 의 커밋 펜스가 한 번에 커밋한다(①/② 의 확정 반영 · 게이트 재실행 통과 뒤,
④ 는 종료 안내 직전). 상태 파일은 지우지 않는다.
````

(AC2 단언: 이 파일의 `state.local.md` 는 「옛 자리의 진행 기록」 절의 한 번뿐이다.)

- [ ] **Step 4: SKILL.md 를 고친다** — `### 3.5` 와 `### 4. 본 절차로` 사이에:

````markdown
### 3.6 상태 파일

마지막 줄이 판결이다. `ARG_PATH` 는 2 에서 Read 한 절대경로(`@` 가 발동하지 않았으면 빈 값)다.

<!-- interview-state-entry:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — 경로를 추측하지 말고 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
python3 "$SD/scripts/interview_state.py" entry --arg "${ARG_PATH:-}" --session "$sid"
```
<!-- interview-state-entry:end -->

| 판결 | 동작 |
|---|---|
| `interview-state: RESUME <경로>` | 그 상태 파일로 이어 간다 |
| `interview-state: ASK` | 이어 감/새로 시작을 묻는다 |
| `interview-state: LEGACY <경로>` | 옛 진행 기록을 docs 로 옮긴 뒤 이어 간다 |
| `interview-state: NEW-SEED <주제> seed=<경로>` | 첫 라운드 전에 상태 파일을 만든다 |
| `interview-state: NEW` | 첫 라운드에서 주제를 정한 직후 만든다 |
| `interview-state: REJECT …` | 그 줄을 보이고 멈춘다 |

각 행의 절차는 아래 파일에 있다. 판결을 받으면 읽는다.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/state-file.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.
````

`## State location` 첫 줄 → `` `docs/superpowers/interview/<날짜>-<주제>-interview.state.md` — 작업 트리의 추적 파일(`### 3.6`). 끝날 때 brief · audit 와 함께 커밋한다. `` 「State write contract (PN1)」 절 전체(헤딩부터 「**brief는 예외**…」 줄까지)를 지운다. `## In-flight state migration` 절을 「상태 파일을 읽을 때 §2.4 스키마의 **어떤 키든 부재**면 아래 파일을 읽는다.」 + 기존 `Read` 줄 + 그 아래 경로 안내 문장으로 줄인다. `## kill switch` 첫 항목의 「진행 중이던 state.local.md 는 보존한다(실패 분석용).」 → 「상태 파일은 docs 에 그대로 남는다.」 줄 수 확인: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -E 'AC3/C9'` 이 자기 줄 수 < 502 를 내야 한다.

- [ ] **Step 5: finishing.md 를 고친다**
  - 머리 「state.local.md에 쓰는 동시에」 → 「상태 파일에 쓰는 동시에」.
  - Step A 2 의 두 경로: 「payload · audit 경로는 상태 파일 이름에서 `.state.md` 를 뗀 `<줄기>` 에 `.md` · `.audit.md` 를 붙인 것이다(`references/state-file.md`). 날짜 · 주제로 다시 계산하지 않는다.」
  - B-0 펜스: `ROOT=…` · `STATE="$ROOT/<session-id>/state.local.md"` · PN1 주석 세 줄을 `# confirm_repost_count 는 상태 파일(<줄기>-interview.state.md)의 frontmatter 에 Edit 로 쓴다` 한 줄로, 그 위 문장 「state에 씁니다(PN1 Bash write contract)」 → 「상태 파일에 씁니다」.
  - B-2: 「brief 는 막 검증됐고 하류·SessionEnd 가 cleanup 을 맡는다 — 설계 §5.3」 → 「brief 는 막 검증됐다 — 설계 §5.3」.
  - B-3: ④ 항목 바로 뒤, `#### B-4` 앞에 새 소절(①/② · ④ 본문이 「아래 세 파일 커밋 펜스」로 가리킨다 — 문면 순서 단언이 이 자리를 잰다):

````markdown
**세 파일 커밋 — ①/② 는 게이트 재실행 통과 뒤 두 줄 노출 전, ④ 는 종료 안내 직전, 한 번.** ③ 은 커밋하지 않는다.
게이트 재실행이 통과하지 않으면 커밋하지 않는다. 펜스 앞에 `BRIEF='<Step A.5 의 PAYLOAD 절대경로>'` 한 줄을 붙여 같은
Bash 호출로 돌리고, 나온 `[spec-distill]` 줄을 그대로 보인다. 진행은 막지 않는다.

<!-- interview-commit:begin -->
```bash
if [ -z "${BRIEF:-}" ]; then
  echo "[spec-distill] 커밋 입력 부재 — BRIEF 가 비었다(Bash 호출마다 새 셸이다 — 이 펜스 안에서 다시 대입하라)."
else
  stem="${BRIEF%.md}"; AUDIT_F="${stem}.audit.md"; STATE_F="${stem}.state.md"
  top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
  def="$(git -C "${top:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" || def=""
  def="${def#origin/}"
  cur="$(git -C "${top:-.}" branch --show-current 2>/dev/null)" || cur=""
  if [ -z "$top" ]; then
    echo "[spec-distill] 커밋하지 않았다 — git 저장소가 아니다. 파일은 docs 에 있다: $BRIEF · $AUDIT_F · $STATE_F"
  elif [ -z "$def" ]; then
    echo "[spec-distill] 커밋하지 않았다 — 기본 브랜치를 판정하지 못했다(origin/HEAD 없음). 직접 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  elif [ "$cur" = "$def" ]; then
    echo "[spec-distill] 커밋하지 않았다 — 지금 기본 브랜치(${def})에 있다. 브랜치에서 커밋하라: $BRIEF · $AUDIT_F · $STATE_F"
  else
    c_rc=0
    git -C "$top" add -- "$BRIEF" "$AUDIT_F" "$STATE_F" || c_rc=$?
    [ "$c_rc" -ne 0 ] || git -C "$top" commit -q --only -m "docs(interview): $(basename -- "$stem") brief · audit · 상태 기록" -- "$BRIEF" "$AUDIT_F" "$STATE_F" || c_rc=$?
    if [ "$c_rc" -eq 0 ]; then
      echo "[spec-distill] brief · audit · 상태 파일을 커밋했다 — $(git -C "$top" rev-parse --short HEAD) (${cur})"
    else
      echo "[spec-distill] 커밋이 실패했다(rc ${c_rc}) — 파일은 docs 에 있다: $BRIEF · $AUDIT_F · $STATE_F"
    fi
  fi
fi
```
<!-- interview-commit:end -->
````

  - ① 본문의 「`check_brief.py gate` 재실행(통과 확인) → 두 줄을 *그대로 보이게* 노출한다」 → 「`check_brief.py gate` 재실행(통과 확인) → 아래 세 파일 커밋 펜스(`interview-commit`) → 두 줄을 *그대로 보이게* 노출한다」. ② 는 「① 과 같은 절차로」라 따라온다.
  - ④: 「brief terminal advisory(…) 출력 후 종료. handoff 안 함. state는 SessionEnd hook이 cleanup.」 → 「아래 세 파일 커밋 펜스(`interview-commit`)를 돌린 뒤 brief terminal advisory(…)를 내고 종료. handoff 안 함.」
  - ③ 본문에는 커밋을 적지 않는다(「③ 은 커밋하지 않는다」는 새 소절 첫 문장이 말한다).
- [ ] **Step 6: reviewing-brief STATE · 나머지 파일** — Files 의 머리 블록 치환을 `replace_all` 로(같은 줄이 블록마다 반복된다 — 치환 뒤 `grep -c 'state.local.md' plugins/spec-distill/skills/reviewing-brief/SKILL.md` = 0). `check_verbatim_coverage.py` · 템플릿 · `state-migration.md` 고침. 「Deferred to plan」 의 코퍼스 선대조: `git grep -nE "interview/\*|\*-interview|glob\(" -- 'plugins/*/scripts/*.py' 'shared/**/*.py' tools` 로 `docs/superpowers/interview/` 를 훑는 코드가 `.state.md` 를 seed · brief · audit 로 오분류하지 않는지 보고, 결과(계획 시점 측정: `*.audit.md` 를 언급하는 `build_brief_inline_blob.py` · `roadmap_status.py` 는 `.state.md` 와 겹치지 않는다)를 SDD ledger 에 적는다.

- [ ] **Step 7: 통과를 확인한다** — `test_interview_state_flow.sh` GREEN, `run_suite.sh` 비교 새 실패 0, 특히 `test_conducting_interview_stage.sh`(줄 상한) · `test_skill_reference_pointers.sh` · `test_check_verbatim_coverage.sh` · `test_reviewing_brief_skill.sh` · `test_brief_review_state.py` · `test_finishing_block_scope.py` · `test_stale_terms.sh`.

- [ ] **Step 8: 변이(AC2 · AC5)** — AC2: `templates/interview-audit-template.md` 에 `state.local.md` 를 되살린다 → AC2 칸 RED(추가 축); `state-file.md` 의 이월 문단을 지운다 → AC2 칸 RED(삭제 축 — 허용 목록 파일이 빠짐). AC5: 커밋 펜스의 `elif [ "$cur" = "$def" ]` 분기를 지운다 → 기본 브랜치 칸 RED; `--only` 를 지운다 → staged 다른 파일 칸 RED(반전). 기록.

- [ ] **Step 9: 커밋한다** — `chmod +x` 후 `feat(spec-distill): 인터뷰 진행 기록을 docs 의 상태 파일에 두고 끝날 때 brief 와 함께 커밋한다`.

---

### Task 10: 공시 · bump · 레포 규칙

**Files:**
- Modify: `plugins/spec-distill/README.md` — `### Three Laws`/`### Principles 흡수` 의 P14 · P3 서술(80 · 97 · 122 · 127 · 146 · 147 · 148 행 근처), `## Hooks Installed`(설치되는 훅 없음 — Task 6 에서 줄였으면 사유 한 줄 보강), `### 스위치 목록`(195 · 196 · 198 행: 옛 토큰 셋은 「리뷰 진입 때의 원장 정리(`scripts/ledger_sweep.py`)를 끈다」, `DEVBREW_SPEC_DISTILL_TTL_HOURS` 는 두 자리 — 문서가 사라진 원장의 삭제 유예와 옛 세션 폴더의 정리 판정, `state.local.md` 가 있는 옛 폴더는 지우지 않는다, `DEVBREW_SPEC_DISTILL_GC_VERBOSE` 는 은퇴 — 은퇴한 스위치 절에 공시)
- Modify: `plugins/spec-distill/CHANGELOG.md` — `## [6.0.0] — 2026-10-15` (Changed · Removed · Added · Fixed)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` → `6.0.0`; `plugins/quality-gates/.claude-plugin/plugin.json` → `13.0.3`; `plugins/quality-gates/CHANGELOG.md` `## [13.0.3] — 2026-10-15`
- Modify: 레포 `CLAUDE.md` 64행(state 줄 하나)

**Interfaces:** 없음(문서).

- [ ] **Step 1: 개념 별칭으로 낡은 문구를 전수로 센다(ef79c297#r1.1)**

```bash
git grep -nE 'SessionEnd|TTL-GC|TTL_HOURS|세션 수명|세션 정리|Bash 로만|Bash로|PN1|per-session|state\.local\.md|interview-basename|spec-distill-gc|session-end-cleanup|GC_VERBOSE|세션 폴더' -- plugins/spec-distill ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests'
```
나온 줄마다 현재형이면 고친다(역사 서술 · 은퇴 공시 · §1-7 · `ledger_sweep.py` 의 정당한 사용은 둔다). 결과 수와 남긴 줄의 사유를 SDD ledger 에 적는다.

- [ ] **Step 2: README · CHANGELOG** — CHANGELOG 6.0.0 의 필수 내용:
  - **Changed** — 인터뷰 진행 기록이 `docs/superpowers/interview/<줄기>.state.md` 로 옮겼다(끝날 때 brief · audit 와 함께 커밋, 기본 브랜치에서는 커밋하지 않음). 리뷰 원장이 문서 단위 `.claude/spec-distill/.docreview/<stem>-<hash>/` 로 옮겼다(세션을 넘어 라운드 · 상한을 이어 받는다). `docreview_state.py state-dir-for` 가 `--session` 을 받지 않는다. **옛 스위치 토큰 셋 `spec-distill:SessionEnd` · `spec-distill:session-end-cleanup` · `spec-distill:spec-distill-gc` 는 이제 리뷰 진입 때의 원장 정리를 끈다.** `DEVBREW_SPEC_DISTILL_TTL_HOURS` 의 두 자리.
  - **Removed** — SessionEnd 훅(`hooks/`), `scripts/spec-distill-gc.py`, request-framing 의 `interview-basename`, `DEVBREW_SPEC_DISTILL_GC_VERBOSE`(은퇴 — README 은퇴한 스위치 절에도), `hook_common.fire_and_forget_gc`.
  - **Added** — `state_path.py interview-state`, `interview_state.py`, `ledger_marker.py`(동시 리뷰 표지), `ledger_sweep.py`.
  - major 인 이유 한 줄 · 「진행 중인 옛 인터뷰는 진입 때 docs 로 옮겨지고, 다른 세션의 옛 기록은 지우지 않고 알린다」.
  quality-gates 13.0.3 **Changed**: 「공유 엔진 `docreview_state.py`(심볼릭 링크로 함께 배송)의 `state-dir-for` 가 세션 칸 없이 `<root>/.docreview/…` 를 낸다 — quality-gates 는 이 서브커맨드를 부르지 않아 동작은 같다(배포 바이트 변경에 따른 cache key bump).」

- [ ] **Step 3: CLAUDE.md** — 64행을 다음으로:

```markdown
- **JSON이 아니라 마크다운 state.** 런타임 state 는 `.claude/<plugin>/` 하위에 산다(git-ignored, plugin namespace 밖으로 나가지 않는다) — 세션 단위 state 는 `.claude/<plugin>/<session-id>/<file>`(성공 시 auto-delete, 실패 시 디버깅을 위해 보존), 문서 단위 리뷰 원장은 그 문서가 사라질 때 정리한다. 인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다. **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).
```

다른 줄은 건드리지 않는다(R9).

- [ ] **Step 4: 통과를 확인한다** — `bash shared/tests/test_changelog_integrity.sh` · `bash plugins/spec-distill/tests/test_readme_sync.sh` · `bash plugins/spec-distill/tests/test_stale_terms.sh` · `bash shared/tests/test_plugin_description_parity.sh` · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_review_hook_removed.py`(기존 RED 하나 밖의 새 적중 0) · `run_suite.sh` 비교.

- [ ] **Step 5: 커밋한다** — `docs(spec-distill): 6.0.0 — 상태 저장 재설계를 공시하고 레포 state 규칙을 맞춘다` (quality-gates 두 파일 · CLAUDE.md 포함).

---

### Task 11: 끝에서 끝 + 최종 대조

**Files:**
- Create: `plugins/spec-distill/tests/test_state_storage_e2e.sh` (100755)

**Interfaces:** Task 1~9 의 CLI 와 펜스 전부.

- [ ] **Step 1: 테스트를 쓴다** — 버릴 디렉토리(`mktemp -d` 결과가 비지 않았는지 `cd` 전에 확인)에서 한 흐름:
  1. 픽스처 저장소(`origin` bare + 클론, 기능 브랜치 `feature/e2e`)에 seed `2026-10-15-e2e-interview.md`(`type: interview-seed`) · seed audit.
  2. 세션 A 로 `interview_state.py entry --arg <seed>` → `NEW-SEED e2e-brief seed=…` → `state_path.py interview-state --topic e2e-brief --date 2026-10-15` 로 경로 → 상태 파일을 첫 두 키와 `## R1` 로 쓴다.
  3. 세션 B 로 같은 seed 진입 → `ASK` + 후보 = 그 상태 파일. 상태 파일 경로로 진입 → `RESUME`.
  4. brief · audit 를 같은 줄기로 쓰고 `finishing.md` 의 `interview-commit` 펜스를 돌린다 → 세 경로만 커밋됨.
  5. 같은 brief 를 두 세션이 리뷰: reviewing-brief 의 `ledger-open` 펜스를 세션 A(`HELD`) → 세션 B(`OTHER:A`) → B 가 `ledger-takeover` → A 의 `ledger-guard` + `begin-round` 가 rc 3 이고 원장 바이트 그대로.
  6. 정리: brief 를 지우고(`git rm` 후 커밋) 원장 폴더 전체를 30시간 전으로 늙힌 뒤 `ledger_sweep.py --root` → 「문서 없는 원장 1개」 줄 · 원장 폴더 없음.
  각 단계는 `assert_eq`/`ok`/`no` 로 단언한다(앞 Task 들의 테스트 관용구를 그대로 쓴다).

- [ ] **Step 2: 통과 · 변이** — GREEN 확인. 변이 하나: 5 의 `ledger-guard` 펜스 본문 대신 빈 문자열을 넣는 드라이버 변이로 원장 바이트 단언이 RED 가 되는지(드라이버 안 임시 변이 — 레포 파일을 바꾸지 않는다). `mutation.md` 기록.

- [ ] **Step 3: 전체 대조** — `bash ~/.claude/sdd-mirror/r7-impl/run_suite.sh ~/.claude/sdd-mirror/r7-impl/after-t11.txt` → baseline 과 FAIL 이름 집합 비교(새 실패 0, 이 브랜치가 고친 기존 RED 가 있으면 그 이름). `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh` 도 돈다.

- [ ] **Step 4: 커밋한다** — `test(spec-distill): 상태 저장 재설계의 끝에서 끝 흐름을 잰다`.

---

## Self-Review 기록

- **설계 대조:** §1-1 → T2(`NEW-SEED …-brief`) · T9 / §1-2 → T1 / §1-3 → T9 `state-file.md` · PN1 제거 / §1-4 → T2 `entry` · T9 / §1-5 → T9 커밋 펜스 / §1-6 → T3(엔진 경로) · T8(request-framing STATE) · T9(check_verbatim · finishing · 템플릿 · reviewing-brief STATE · fallback 이동) / §1-7 → T2 `migrate-legacy` · T9 / §2-1 → T3 / §2-2 → T4 `resume-note` · T7 / §2-3 → T3(문서 realpath 해시 그대로) / §2-4 → T4 · T7 · T8 / §2-5 → T2 `seed-audit-for-session` · T8 / §3-1 → T6 / §3-2 → T5 / §3-3 → T5 · T10 / §3-4 · §3-6 → T10 / §3-5 → T10 / AC1~AC15 → 각 Task 의 테스트 · 변이 단계(AC13 · AC14 는 T10, AC15 는 T3 · T4 · T5 · T6 · T7 · T9 · T11 의 변이 단계).
- **Deferred to plan:** `hook_common` 경계 → T6 Files · `.state.md` 오분류 선대조 → T9 Step 6 · 경로 문자열 테스트 전수 → T3 Step 1 · T6 Step 1 · T10 Step 1 · SKILL 줄 예산 → T9 Step 4 · ef79c297#r1.1 개념 별칭 → T10 Step 1.
- **이 계획이 다루지 않는 것(미룸 · 받는 곳):** 정리 «횟수»를 재는 락(T7 Step 6 의 한계 — 받는 곳: R6 상태 표시 에픽) · 정리 끄기 스위치가 꺼졌을 때 그 사실을 화면에 보이는 일(설계 §3-2 문면에 없음 — 받는 곳: R6).
- **이름 일관성:** `interview_state_path` · `worktree_root` · `frontmatter_scalars` · `state_dir_for(root, doc)` · `MARKER`/`LAST` · 판결 접두 `interview-state:` · `ledger-open:` 을 Task 사이에서 같은 철자로 쓴다.
- **plan-authored 테스트 코드:** T1~T11 의 테스트 코드 블록은 이 계획이 쓴 것이다 — 리뷰어는 그 코드도 구현 코드와 같은 엄격함으로 본다(덜 검사받는 경향이 있다).
