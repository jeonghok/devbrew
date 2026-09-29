# 감사 폴더 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `docs/audits/` 와 `docs/archive/audits/` 를 리포에서 없애고, 그 폴더에 매달린 활성 의존을 먼저 끊으며, 지금 발동 중인 결함 여섯을 고친다 — 착수 전 기준선 대비 새 실패 0.

**Architecture:** plugin-audit 의 산출을 새 스크립트 `prepare-run-dir.py` 가 만드는 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/`(안의 `.gitignore` 로 스스로 git-ignore)로 옮기고, render · validate 에서 README 인덱스 · CLAUDE.md 포인터 요구를 없앤다. 폴더를 가리키던 fixture · 인용 · 존재 단언을 차례로 정리한 뒤 폴더를 마지막 커밋에서 지운다. 한 PR 에 커밋 덩어리 셋: ① 끈 끊기 + 폴더 제거(Task 1~7) ② project-init 결함 둘(Task 8~9) ③ 테스트·락 넷(Task 10~13), 그리고 bump(Task 14) · 최종 검증(Task 15).

**Tech Stack:** Python 3.9+(표준 라이브러리만, `unittest`), bash(macOS 3.2 호환), node `--test`, git.

**Spec:** `docs/superpowers/specs/2026-09-28-audit-folder-removal-design.md` (brief: `docs/superpowers/interview/2026-09-28-audit-folder-removal-interview.md`). 실행자는 둘 다 읽는다.

## Global Constraints

- **재결정 규약** — confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. brief 의 C1~C15 · D7~D22 가 제약이다. 이 계획의 어떤 단계가 그것과 충돌하면 멈추고 보고한다.
- **작업 위치** — 워크트리 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits`, 브랜치 `feature/resolve-audits`. subagent 에게는 이 절대경로를 매번 못 박아 준다(동명 파일을 메인 체크아웃에 커밋하는 사고 방지). 모든 명령은 이 디렉토리를 cwd 로 돈다.
- **git** — 브랜치 최신화는 merge(rebase 금지). 커밋은 경로를 지정해서 한다(`git add <경로들>` 후 `git commit`, 또는 `git commit -- <경로>`) — `git add -A` · `git add .` 금지. 커밋 메시지는 Conventional Commits 이고 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 한 줄. 기존 스태시 스택을 건드리지 않는다.
- **Python** — 새·수정 코드는 파일 읽기·쓰기에 `encoding="utf-8"` 를 명시한다(`plugins/quality-gates/tests/test_utf8_explicit.py` 가 `plugins/*/scripts/*.py` 를 잰다). 스크립트 안에 `"python3"` 문자열 리터럴을 두지 않는다(`shared/tests/test_python_floor.sh` 축 E). 비신뢰 입력 정규식은 `fullmatch`. Python 3.9 에서 돌아야 한다(`from __future__ import annotations`).
- **테스트 실행** — Python 은 그 `tests/` 디렉토리에서 `python3 -m unittest -v <모듈>`. 셸 테스트는 리포 루트에서 `bash <경로>`(실행비트와 무관하게). node 는 `node --test --test-reporter=tap <파일>`. `plugins/quality-gates/tests/spike/` 는 codex 를 실제로 태우므로 돌리지 않는다.
- **변이(mutation)** — 먼저 커밋하고 변이한다. 변이 중에는 `PYTHONDONTWRITEBYTECODE=1`. 복원은 `git checkout HEAD -- <파일>` 이고, 복원 뒤 `git diff HEAD --stat` 이 빈 출력인지 확인한다. 판정은 rc 만이 아니라 지정된 줄로 한다.
- **Bash 도구** — 호출마다 새 셸이다(변수가 다음 호출로 안 넘어간다). 셸은 zsh 라 `PIPESTATUS` 가 없다 — 파이프 rc 가 필요하면 `bash -c` 안에서 잡는다.
- **버전** — 건드린 네 플러그인을 이 PR 에서 한 번씩 bump 한다: plugin-audit minor, spec-distill · quality-gates · project-init patch(Task 14). 번호는 머지 직전 origin/main 기준으로 다시 정한다.
- **문서** — 한국어 primary. 영어는 식별자 · 고유명사 · 원문 인용 · 대응어 없는 기술 용어만.
- **모델** — devbrew 에서 fable 모델을 쓰지 않는다. codex 실호출은 사전 승인돼 있다(호출 횟수는 보고한다).
- **산출 보존** — 기준선 · 최종 스위트 · 1회 점검 결과는 `~/.claude/sdd-mirror/resolve-audits/` 에 둔다(job tmp · git-ignored 워크트리 경로는 세션 재개에 사라질 수 있다).

## Review Focus

1. **사용자 리포 경로에 공백·한글이 있다** — `prepare-run-dir.py` 가 출력한 첫 줄이 실제 디렉토리 경로와 바이트 단위로 같아야 하고, 비-UTF-8 stdout 인코딩에서도 죽지 않아야 한다. → Task 1 ⑦.
2. **실행 키 자리에 디렉토리가 아닌 파일이 이미 있다** — 덮지 않고 `-2` 로 넘어가야 한다. → Task 1 ⑧.
3. **사용자 리포에 `.claude/` 가 아예 없다** — 부모까지 만들어야 한다. → Task 1 ①(빈 루트에서 시작).
4. **`.claude/` 를 ignore 하지 않는 사용자 리포** — 감사 한 번 뒤 `git status --porcelain` 이 비어야 한다(실행 디렉토리가 스스로 ignore). → Task 3(`.gitignore` 없는 임시 git 리포 + 양성 대조).
5. **빈 `$RUN_DIR` 로 이어지는 명령** — Bash 도구는 셸 변수를 넘기지 않으므로 빈 값이면 `/audit-data.json` 같은 루트 경로에 쓴다. SKILL 이 가드를 지시해야 한다. → Task 4(가드 문자열 불변식).

---

## Task 0: 착수 준비 — base 따라잡기와 기준선

**Files:**
- Create: `~/.claude/sdd-mirror/resolve-audits/run-suite.sh`(리포 밖)
- Modify: 없음(merge 커밋 하나)

**Interfaces:**
- Produces: `~/.claude/sdd-mirror/resolve-audits/run-suite.sh <label> [경로 접두]` — `<label>/summary.tsv`(파일 · rc · 실패 줄 수) · `<label>/failures.txt`(정렬된 `<파일> :: <실패 줄>`) · `<label>/logs/*.log`. Task 15 가 같은 스크립트로 `final` 을 잰다.
- Produces: `~/.claude/sdd-mirror/resolve-audits/base.txt` — merge 뒤 HEAD 와 origin/main 해시.

- [ ] **Step 1: base 이동량을 재고 merge 한다**

2026-09-28 측정: 이 브랜치의 base `6f41a6e1` 뒤로 origin/main 이 53커밋(#181~#184) 움직였고, `git merge-tree` 는 충돌 없음이었다. 계획이 건드리는 파일 중 main 이 바꾼 것은 `plugins/spec-distill/skills/framing-requests/SKILL.md` 하나이며 `## degrade 채널` 절은 그대로다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits
mkdir -p ~/.claude/sdd-mirror/resolve-audits
git status --porcelain            # 빈 출력이어야 한다
git fetch origin main
git rev-list --count HEAD..origin/main
git merge-tree --write-tree HEAD origin/main >/dev/null && echo clean || echo CONFLICT
git merge --no-edit origin/main
{ git rev-parse HEAD; git rev-parse origin/main; } > ~/.claude/sdd-mirror/resolve-audits/base.txt
```

CONFLICT 가 나오면 merge 하지 말고 멈춰 보고한다.

- [ ] **Step 2: 스위트 스크립트를 쓴다**

`~/.claude/sdd-mirror/resolve-audits/run-suite.sh` 에 아래를 그대로 쓴다(이 계획을 쓸 때 plugin-audit 26파일과 RED 인 matcher 락 하나로 동작을 확인했다):

```bash
#!/usr/bin/env bash
# run-suite.sh <label> [path-prefix-filter]
# 리포 루트에서 전 스위트를 파일 단위로 돌려 <OUT>/<label>/ 에 남긴다.
#   summary.tsv   — <file>\t<rc>\t<실패 줄 수>
#   failures.txt  — <file> :: <정규화한 실패 줄>   (정렬됨, 대조용)
#   logs/<slug>.log
# 셸 테스트는 실행비트와 무관하게 `bash <경로>` 로, python 은 그 tests 디렉토리에서
# `python3 -m unittest -v <모듈>` 로, node 는 `--test-reporter=tap` 으로 돈다.
# spike/ 는 codex 를 실제로 태우므로 제외한다.
set -u
REPO=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits
OUT="${SUITE_OUT:-$HOME/.claude/sdd-mirror/resolve-audits}"
LABEL="${1:?usage: run-suite.sh <label> [prefix]}"
FILTER="${2:-}"
D="$OUT/$LABEL"
rm -rf "$D"; mkdir -p "$D/logs"
cd "$REPO" || exit 1
export PYTHONDONTWRITEBYTECODE=1
: > "$D/summary.tsv"; : > "$D/failures.raw"

list() {
  git ls-files --cached --others --exclude-standard \
    | grep -E '^(plugins/[^/]+/tests/(harness/)?test_[^/]*\.(sh|py)|shared/tests/test_[^/]*\.sh|plugins/[^/]+/tests/[^/]*\.test\.mjs)$' \
    | grep -v '/spike/' | sort
}

run_one() {
  f="$1"; slug="$(printf '%s' "$f" | tr '/' '_')"; log="$D/logs/$slug.log"
  case "$f" in
    *.sh)  bash "$f" > "$log" 2>&1; rc=$? ;;
    *.py)  dir="$(dirname "$f")"; mod="$(basename "$f" .py)"
           ( cd "$dir" && python3 -m unittest -v "$mod" ) > "$log" 2>&1; rc=$? ;;
    *.mjs) node --test --test-reporter=tap "$f" > "$log" 2>&1; rc=$? ;;
  esac
  grep -E '^[[:space:]]*✗ |^(FAIL|ERROR): |^not ok |^BAD ' "$log" \
    | sed -E 's#/(private/)?(var/folders|tmp)/[^ :]*#<TMP>#g' \
    | sed "s#^#$f :: #" > "$D/tmp.fail"
  n="$(wc -l < "$D/tmp.fail" | tr -d ' ')"
  [ "$rc" -ne 0 ] && echo "$f :: rc=$rc" >> "$D/tmp.fail"
  cat "$D/tmp.fail" >> "$D/failures.raw"
  printf '%s\t%s\t%s\n' "$f" "$rc" "$n" >> "$D/summary.tsv"
}

for f in $(list); do
  case "$f" in "$FILTER"*) run_one "$f" ;; esac
done
sort "$D/failures.raw" > "$D/failures.txt"; rm -f "$D/failures.raw" "$D/tmp.fail"
echo "files=$(wc -l < "$D/summary.tsv" | tr -d ' ') rc!=0=$(awk -F'\t' '$2!=0' "$D/summary.tsv" | wc -l | tr -d ' ') failure-lines=$(wc -l < "$D/failures.txt" | tr -d ' ')"
echo "out=$D"
```

- [ ] **Step 3: 기준선을 잰다 (첫 편집 전)**

Run(백그라운드 권장 — 수백 파일): `bash ~/.claude/sdd-mirror/resolve-audits/run-suite.sh baseline`
Expected: 마지막 두 줄 `files=… rc!=0=… failure-lines=…` · `out=…/baseline`. 이 시점에 RED 여야 하는 것(설계 Context §2): `plugins/quality-gates/tests/test_runner_adapters.sh` · `plugins/quality-gates/tests/test_codex_backward_compat.sh` · `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`. qg harness 선재 FAIL 2 는 `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` 의 줄로 보인다 — 그 줄 수를 기록한다. 셋 중 하나라도 GREEN 이거나 예상 밖 RED 가 많으면 멈추고 보고한다.

- [ ] **Step 4: 스위트가 워크트리를 더럽히지 않았는지 확인한다**

Run: `git status --porcelain`
Expected: 빈 출력. 무언가 생겼으면 그 파일이 어느 테스트의 부산물인지 적고, 추적 파일이 바뀌었으면 멈춘다.

Python 테스트 이름 목록도 남긴다(AC2 의 「사라진 테스트」 대조용). docstring 이 있는 테스트는 `-v` 가 `... ok` 를 다음 줄에 찍으므로 결과가 아니라 이름 머리만 잡는다:

```bash
O=~/.claude/sdd-mirror/resolve-audits
grep -hoE '^test_[A-Za-z0-9_]+ \([^)]*\)' "$O"/baseline/logs/*.py.log | sort -u > "$O/baseline/pytests.txt"
wc -l < "$O/baseline/pytests.txt"
```

---

## Task 1: `prepare-run-dir.py` — 실행 디렉토리 생성기 (AC4)

**Files:**
- Create: `plugins/plugin-audit/scripts/prepare-run-dir.py` (모드 100644 — 형제 스크립트와 같다)
- Test: `plugins/plugin-audit/tests/test_prepare_run_dir.py`

**Interfaces:**
- Produces: CLI `prepare-run-dir.py <target> [--repo-root <dir>] [--date YYYY-MM-DD]`
  - rc 0: stdout 정확히 두 줄 — ① `<repo-root 절대경로>/.claude/plugin-audit/<실행 키>` ② sandbox id = `sha256(<실행 키>)[:8]`(소문자 hex 8자). 실행 키 = `<date>-<target>` 또는 `<date>-<target>-<N>`(N≥2). 디렉토리 안에 내용이 `*\n` 인 `.gitignore`.
  - rc 2: target 이 `[A-Za-z0-9._-]+` 가 아니거나 `..` 를 포함하거나 `.` 로 시작 · date 가 `\d{4}-\d{2}-\d{2}` 가 아님. stdout 빈 출력, 디렉토리 없음.
  - rc 1: 디렉토리를 만들지 못함(OSError).
- Consumes: 없음.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/plugin-audit/tests/test_prepare_run_dir.py`:

```python
"""prepare-run-dir.py — 실행 디렉토리 생성기 (설계 2026-09-28-audit-folder-removal §2 · AC4).

스크립트 이름에 하이픈이 있어 import 하지 않고 subprocess 로 돈다.
"""
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare-run-dir.py"
DATE = "2026-09-28"


def run(root, target, *extra, env=None):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), target, "--repo-root", str(root), "--date", DATE, *extra],
        capture_output=True, env=env)
    return (r.returncode, r.stdout.decode("utf-8").splitlines(),
            r.stderr.decode("utf-8", "replace"))


def sha8(key):
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:8]


class TestPrepareRunDir(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name).resolve()
        self.parent = self.root / ".claude" / "plugin-audit"

    def tearDown(self):
        self._td.cleanup()

    def test_1_first_call_creates_keyed_dir_and_prints_abs_path(self):
        # 사용자 리포에는 .claude/ 가 아예 없을 수 있다 — 부모까지 만든다.
        self.assertFalse((self.root / ".claude").exists())
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        want = self.parent / f"{DATE}-quality-gates"
        self.assertTrue(want.is_dir())
        self.assertEqual(len(out), 2, out)
        self.assertTrue(Path(out[0]).is_absolute(), out[0])
        self.assertEqual(Path(out[0]), want)

    def test_2_second_call_makes_dash_2_and_leaves_first_untouched(self):
        rc, out1, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        first = Path(out1[0])
        (first / "audit.md").write_text("first run\n", encoding="utf-8")
        before = sorted(p.name for p in first.iterdir())
        rc, out2, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out2[0]), self.parent / f"{DATE}-quality-gates-2")
        self.assertEqual(sorted(p.name for p in first.iterdir()), before)
        self.assertEqual((first / "audit.md").read_text(encoding="utf-8"), "first run\n")

    def test_3_gitignore_is_single_star_line(self):
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        gi = Path(out[0]) / ".gitignore"
        self.assertEqual(gi.read_text(encoding="utf-8").splitlines(), ["*"])

    def test_4_bad_targets_are_rc2_and_create_nothing(self):
        for bad in ("../x", "a/b", ".x", "a..b", ""):
            with self.subTest(target=bad):
                rc, out, err = run(self.root, bad)
                self.assertEqual(rc, 2, err)
                self.assertIn("target 형식 불허", err)
                self.assertEqual(out, [])
        self.assertFalse(self.parent.exists() and any(self.parent.iterdir()))

    def test_5_sandbox_id_is_hash_of_run_key(self):
        seen = []
        for target in ("quality-gates", "spec-distill", "quality-gates"):  # 셋째는 -2
            rc, out, err = run(self.root, target)
            self.assertEqual(rc, 0, err)
            key = Path(out[0]).name
            self.assertRegex(out[1], r"\A[0-9a-f]{8}\Z")
            # 같은 실행 키 → 같은 id: 디렉토리 이름에서 언제든 다시 계산된다.
            self.assertEqual(out[1], sha8(key))
            seen.append((key, out[1]))
        # 같은 달의 서로 다른 실행 키 → 앞 8글자가 서로 다르다.
        self.assertEqual(len({sid for _, sid in seen}), 3, seen)
        # 키 자체의 앞 8글자는 전부 같다 — qg create-sandbox 가 id 앞 8글자만 쓰므로 해시가 필요하다.
        self.assertEqual(len({key[:8] for key, _ in seen}), 1, seen)

    def test_6_bad_date_is_rc2(self):
        rc, out, err = run(self.root, "quality-gates", "--date", "20260928")
        self.assertEqual(rc, 2, err)
        self.assertIn("date 형식 불허", err)
        self.assertEqual(out, [])

    def test_7_root_with_space_and_hangul_under_ascii_stdout(self):
        root = self.root / "내 리포"
        root.mkdir()
        env = dict(os.environ, PYTHONIOENCODING="ascii")
        rc, out, err = run(root, "quality-gates", env=env)
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out[0]), root.resolve() / ".claude" / "plugin-audit" / f"{DATE}-quality-gates")
        self.assertTrue(Path(out[0]).is_dir())

    def test_8_existing_file_at_key_is_skipped_not_overwritten(self):
        self.parent.mkdir(parents=True)
        squatter = self.parent / f"{DATE}-quality-gates"
        squatter.write_text("not a dir\n", encoding="utf-8")
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out[0]).name, f"{DATE}-quality-gates-2")
        self.assertEqual(squatter.read_text(encoding="utf-8"), "not a dir\n")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 테스트가 실패하는지 본다**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_prepare_run_dir`
Expected: 8개 전부 FAIL — 스크립트 부재로 rc 2 와 `can't open file` stderr(`test_4`·`test_6` 도 `target 형식 불허` / `date 형식 불허` 문구가 없어 FAIL).

- [ ] **Step 3: 스크립트를 쓴다**

`plugins/plugin-audit/scripts/prepare-run-dir.py`:

```python
#!/usr/bin/env python3
"""prepare-run-dir.py — plugin-audit 실행 디렉토리를 만든다 (지출 동의 승인 직후 한 번).

<repo-root>/.claude/plugin-audit/<date>-<target>[-N]/ 을 os.mkdir 로 원자적으로 만들고 그 안에
`*` 한 줄짜리 .gitignore 를 쓴다. 이미 있으면 -2, -3 … 을 붙여 다시 시도한다 — 기존 디렉토리를
덮거나 비우지 않는다.

stdout 두 줄:
  1. 실행 디렉토리의 절대경로 (basename = 실행 키)
  2. sandbox id — 실행 키의 SHA-256 앞 8 hex. qg-worktree.sh create-sandbox 는 받은 id 의 앞
     8글자만 sandbox 이름에 쓰고 같은 이름의 sandbox 를 지우고 다시 만든다. 날짜로 시작하는 실행
     키를 그대로 넘기면 같은 달의 감사가 한 sandbox 로 접힌다.

rc: 0 성공 · 1 디렉토리를 만들지 못함 · 2 인자 형식 위반(target · date).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import os
import re
import sys
from pathlib import Path

TARGET_RE = re.compile(r"[A-Za-z0-9._-]+")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
MAX_SUFFIX = 999


def valid_target(target: str) -> bool:
    return (bool(TARGET_RE.fullmatch(target))
            and ".." not in target and not target.startswith("."))


def sandbox_id(run_key: str) -> str:
    return hashlib.sha256(run_key.encode("utf-8")).hexdigest()[:8]


def make_run_dir(parent: Path, key: str) -> Path:
    parent.mkdir(parents=True, exist_ok=True)
    for n in range(1, MAX_SUFFIX + 1):
        candidate = parent / (key if n == 1 else f"{key}-{n}")
        try:
            os.mkdir(candidate)
        except FileExistsError:
            continue
        return candidate
    raise FileExistsError(f"{parent / key} 와 -2 … -{MAX_SUFFIX} 가 전부 이미 있다")


def main(argv: list[str] | None = None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="plugin-audit 실행 디렉토리를 만든다")
    ap.add_argument("target")
    ap.add_argument("--repo-root", type=Path, default=Path("."))
    ap.add_argument("--date", default=None, help="YYYY-MM-DD (기본: 오늘의 로컬 날짜)")
    args = ap.parse_args(argv)
    if not valid_target(args.target):
        print(f"[prepare-run-dir] target 형식 불허: {args.target!r} — "
              "[A-Za-z0-9._-]+ 이고 '..' 를 포함하지 않으며 '.' 으로 시작하지 않아야 한다",
              file=sys.stderr)
        return 2
    date = args.date if args.date is not None else datetime.date.today().isoformat()
    if not DATE_RE.fullmatch(date):
        print(f"[prepare-run-dir] date 형식 불허: {date!r} — YYYY-MM-DD", file=sys.stderr)
        return 2
    parent = args.repo_root.resolve() / ".claude" / "plugin-audit"
    try:
        run_dir = make_run_dir(parent, f"{date}-{args.target}")
        (run_dir / ".gitignore").write_text("*\n", encoding="utf-8")
    except OSError as e:
        print(f"[prepare-run-dir] 실행 디렉토리를 만들지 못했다: {e}", file=sys.stderr)
        return 1
    print(run_dir)
    print(sandbox_id(run_dir.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트가 통과하는지 본다**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_prepare_run_dir`
Expected: `Ran 8 tests` · `OK`.
함께 도는 리포 락: `cd plugins/quality-gates/tests && python3 -m unittest -v test_utf8_explicit` → OK. `bash shared/tests/test_python_floor.sh` → 기준선과 같은 결과(새 ✗ 없음).

- [ ] **Step 5: 커밋**

```bash
git add plugins/plugin-audit/scripts/prepare-run-dir.py plugins/plugin-audit/tests/test_prepare_run_dir.py
git commit -m "feat(plugin-audit): prepare-run-dir.py — 실행 디렉토리 생성기

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: 변이 셋 (AC4)**

각 변이 뒤 `PYTHONDONTWRITEBYTECODE=1` 로 테스트를 돌리고 `git checkout HEAD -- plugins/plugin-audit/scripts/prepare-run-dir.py` 로 되돌린 뒤 `git diff HEAD --stat` 이 빈지 본다.
1. `(run_dir / ".gitignore").write_text("*\n", encoding="utf-8")` 줄을 지운다 → `test_3` FAIL(파일 부재).
2. `make_run_dir` 의 본문을 `candidate = parent / key; parent.mkdir(parents=True, exist_ok=True); candidate.mkdir(exist_ok=True); return candidate` 로 바꾼다 → `test_2` FAIL(`-2` 가 아니라 같은 경로).
3. `print(sandbox_id(run_dir.name))` 를 `print(run_dir.name)` 으로 바꾼다 → `test_5` FAIL(8 hex 아님).
셋 중 하나라도 GREEN 이면 그 테스트를 고치고 Step 5 의 커밋에 `git commit --amend` 하지 말고 새 커밋으로 더한다.

---

## Task 2: render 의 `--readme` · validate 의 README · CLAUDE.md 요구 제거 (AC6)

**Files:**
- Modify: `plugins/plugin-audit/scripts/render-audit-report.py:174-195`(main)
- Modify: `plugins/plugin-audit/scripts/validate-audit-data.py:1-9`(docstring) · `:141-153`(validate_artifacts) · `:156-175`(main)
- Test: `plugins/plugin-audit/tests/test_render_audit_report.py:8-15` · 새 테스트 1개
- Test: `plugins/plugin-audit/tests/test_validate_audit_data.py:273-345`

**Interfaces:**
- Produces: CLI `render-audit-report.py <data.json> --out <report.md>` — 인덱스 파일을 쓰지 않는다. `--readme` 는 없는 옵션(argparse rc 2).
- Produces: CLI `validate-audit-data.py --artifacts <data.json> [--report <report.md>]` — 검사는 배너(AC-3)뿐. `--repo-root` 는 없는 옵션(rc 2). 함수 `validate_artifacts(data: dict, report_path: Path) -> list`.
- Consumes: 없음.

- [ ] **Step 1: 테스트를 먼저 바꾼다 (RED)**

`test_render_audit_report.py` 의 `render()` 를 다음으로 바꾸고, 클래스 끝에 테스트 하나를 더한다:

```python
def render(data, *extra):
    with tempfile.TemporaryDirectory() as t:
        j = Path(t) / "d.json"; out = Path(t) / "r.md"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), str(j), "--out", str(out), *extra],
                           capture_output=True, text=True, cwd=str(REPO))
        md = out.read_text(encoding="utf-8") if out.is_file() else ""
        leftovers = sorted(p.name for p in Path(t).iterdir() if p.name not in ("d.json", "r.md"))
        return r.returncode, md, r.stderr, leftovers
```

기존 테스트들이 `rc, md, err = render(...)` 로 세 값을 받으므로 네 값으로 받게 고친다 — `grep -n "= render(" plugins/plugin-audit/tests/test_render_audit_report.py` 로 호출부를 전부 찾아 `rc, md, err, _ = render(...)` 로 바꾼다(반환 개수가 다르면 ValueError 로 전부 RED 가 되니 빠뜨린 자리는 바로 보인다). 그리고:

```python
    def test_no_index_file_and_no_readme_option(self):  # 설계 §2 · AC6
        data = {"meta": META_OK, "findings": [f("A1-1", "IMPORTANT", "S")],
                "d_verdicts": [], "oq_answers": [], "new_open_questions": [],
                "axis_failures": [], "degraded": []}
        rc, md, err, leftovers = render(data)
        self.assertEqual(rc, 0, err)
        self.assertEqual(leftovers, [], "렌더가 리포트 밖에 파일(인덱스)을 썼다")
        rc, _, err, _ = render(data, "--readme", "x.md")
        self.assertEqual(rc, 2)
        self.assertIn("unrecognized arguments: --readme", err)
```

`test_validate_audit_data.py` 의 `run_validate_artifacts` 와 `TestArtifacts` 를 다음으로 바꾼다 — `test_artifacts_readme_missing_link_is_red` · `test_artifacts_missing_readme_is_red` · `test_artifacts_claude_md_missing_pointer_is_red` 세 테스트는 **의도적으로 삭제**한다(설계 C4 · D22, AC2 의 「사라진 테스트」):

```python
def run_validate_artifacts(data, report_text="# report\n", extra=()):
    """빈 tempdir 에 report 와 data 만 두고 --artifacts 로 실행 — README · CLAUDE.md 는 없다."""
    with tempfile.TemporaryDirectory() as t:
        root = Path(t)
        report_path = root / "report.md"
        report_path.write_text(report_text, encoding="utf-8")
        j = root / "audit-data.json"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        cmd = [sys.executable, str(SCRIPT), "--artifacts", str(j), "--report", str(report_path), *extra]
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(root))
        return r.returncode, r.stderr


class TestArtifacts(unittest.TestCase):
    def test_artifacts_valid_is_green_without_readme_or_claude_md(self):
        rc, err = run_validate_artifacts(copy.deepcopy(VALID))
        self.assertEqual(rc, 0, err)

    def test_repo_root_option_removed(self):
        rc, err = run_validate_artifacts(copy.deepcopy(VALID), extra=("--repo-root", "."))
        self.assertEqual(rc, 2)
        self.assertIn("unrecognized arguments: --repo-root", err)

    def test_artifacts_degraded_without_banner_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(
            bad, report_text="# report\n\nNo mention of the issue anywhere near the top.\n")
        self.assertEqual(rc, 1, "degraded 비었지 않은데 배너 없음이 통과했다 (AC-3)")

    def test_artifacts_degraded_with_banner_is_green(self):
        ok = copy.deepcopy(VALID)
        ok["degraded"] = [{"axis": 3, "reason": "권한 부족"}]
        rc, err = run_validate_artifacts(ok, report_text="# report\n\n⚠ degraded: axis 3 권한 부족\n")
        self.assertEqual(rc, 0, err)
```

`cwd` 를 빈 tempdir 로 둔 것이 요점이다 — 옛 코드는 `--repo-root` 기본값 `.` 에서 README 를 찾으므로 여기서 RED 가 난다.

- [ ] **Step 2: RED 확인**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_render_audit_report test_validate_audit_data`
Expected: FAIL — `test_render_audit_report` 에서 `render()` 헬퍼를 쓰는 테스트 전부(옛 render 는 `--readme` 가 필수라 rc 2 · `the following arguments are required: --readme`; `mod.render` 를 직접 부르는 테스트는 PASS), `test_artifacts_valid_is_green_without_readme_or_claude_md`(rc 1 · `docs/audits/README.md가 리포트를 링크하지 않음`), `test_repo_root_option_removed`(rc 2 가 아니라 1 — 옵션이 있어 README 검사로 간다). `test_validate_audit_data` 의 나머지는 PASS.

- [ ] **Step 3: render 를 고친다**

`render-audit-report.py` 의 `main()` 에서 `ap.add_argument("--readme", type=Path, required=True)` 줄과, `args.out.write_text(md, encoding="utf-8")` 다음의 인덱스 블록 전체를 지운다:

```python
    # docs/audits/README.md 인덱스에 항목 추가 (Law 3 discoverability)
    entry = f"- [{args.out.stem}]({args.out.name}) — {data.get('meta', {}).get('date', '')}\n"
    if args.readme.is_file():
        prev = args.readme.read_text(encoding="utf-8")
        if args.out.name not in prev:
            args.readme.write_text(prev + entry, encoding="utf-8")
    else:
        args.readme.write_text("# 감사 인덱스\n\n" + entry, encoding="utf-8")
```

- [ ] **Step 4: validate 를 고친다**

docstring 의 두 줄을 바꾼다:

```
파이프라인은 자기를 회계할 수 없다 (§9.1) → 검증을 파이프라인 밖에 둔다. RED면 렌더링·산출 보고 금지.
```
```
--artifacts: 렌더링 *후*. 실제 리포트 파일의 배너(AC-3)를 본다 (골든 픽스처는 실물을 안 본다).
```

`validate_artifacts` 를 다음으로 바꾼다:

```python
def validate_artifacts(data: dict, report_path: Path) -> list:
    errs: list[str] = []
    if data.get("degraded"):
        head = "\n".join(report_path.read_text(encoding="utf-8").splitlines()[:20])
        if "⚠" not in head and "degraded" not in head.lower():
            errs.append("degraded 비었지 않은데 리포트 첫 20줄에 배너 없음 (AC-3)")
    return errs
```

`main()` 에서 `ap.add_argument("--repo-root", type=Path, default=Path("."))` 줄을 지우고, 호출을 `errs = validate_artifacts(data, args.report or args.artifacts)` 로 바꾼다.

- [ ] **Step 5: GREEN 확인**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_render_audit_report test_validate_audit_data`
Expected: OK. `test_validate_audit_data` 의 `Ran N tests` 가 기준선보다 정확히 2 적다(`TestArtifacts` 6개 → 4개: 삭제 3 · 추가 1 `test_repo_root_option_removed` · `test_artifacts_valid_is_green` 은 이름만 바뀜). `test_render_audit_report` 는 1 많다. `grep -c "docs/audits" plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/scripts/validate-audit-data.py` → 둘 다 0.

- [ ] **Step 6: 커밋**

```bash
git add plugins/plugin-audit/scripts/render-audit-report.py plugins/plugin-audit/scripts/validate-audit-data.py \
        plugins/plugin-audit/tests/test_render_audit_report.py plugins/plugin-audit/tests/test_validate_audit_data.py
git commit -m "refactor(plugin-audit): render 인덱스 쓰기와 validate 의 README·CLAUDE.md 요구를 없앤다

README 링크 · CLAUDE.md 포인터를 재던 테스트 3개를 의도적으로 지운다(설계 C4 · D22).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3: 결정론 끝-끝 테스트 (AC5)

설계 「Deferred to plan」 1 의 답: **새 파일**에 둔다. `test_assemble_audit_data.py` 는 assemble 한 스크립트의 단위 테스트이고, 이 테스트는 네 스크립트와 git 을 가로지른다. 입력은 AC6 fixture 넷이고 `--no-grounding` 이다(임시 리포에는 인용 대상 파일이 없다). 계획 작성 때 같은 파이프라인을 손으로 돌려 assemble · validate --data · render 가 rc 0 임을 확인했다.

**Files:**
- Test: `plugins/plugin-audit/tests/test_run_dir_pipeline.py`

**Interfaces:**
- Consumes: Task 1 의 `prepare-run-dir.py` CLI(stdout 첫 줄) · Task 2 의 `render-audit-report.py <json> --out <md>` · `validate-audit-data.py --artifacts <json> --report <md>`.

- [ ] **Step 1: 테스트를 쓴다**

```python
"""결정론 끝-끝 — 실행 디렉토리에서 post-1 을 끝까지 돌고 사용자 리포를 더럽히지 않는다
(설계 2026-09-28-audit-folder-removal AC5).

임시 git 리포에는 `.gitignore` 가 없다 — `.claude/` 를 ignore 하지 않는 사용자 리포를 흉내 낸다.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
S = PLUGIN / "scripts"
FIX = PLUGIN / "tests" / "fixtures"


def sh(*args, cwd):
    return subprocess.run(list(args), cwd=str(cwd), capture_output=True, text=True)


class TestRunDirPipeline(unittest.TestCase):
    def test_post1_runs_in_run_dir_and_leaves_repo_clean(self):
        with tempfile.TemporaryDirectory() as t:
            repo = Path(t).resolve()
            for cmd in (["git", "init", "-q"],
                        ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit",
                         "-q", "--allow-empty", "-m", "init"]):
                r = sh(*cmd, cwd=repo)
                self.assertEqual(r.returncode, 0, r.stderr)

            r = sh(sys.executable, str(S / "prepare-run-dir.py"), "project-init",
                   "--repo-root", str(repo), "--date", "2026-09-28", cwd=repo)
            self.assertEqual(r.returncode, 0, r.stderr)
            run_dir = Path(r.stdout.splitlines()[0])
            data, report = run_dir / "audit-data.json", run_dir / "audit.md"

            steps = [
                [sys.executable, str(S / "assemble-audit-data.py"),
                 "--workflow-return", str(FIX / "ac6_workflow_return.json"),
                 "--codex-side", str(FIX / "ac6_codex_side.json"),
                 "--meta", str(FIX / "ac6_meta.json"),
                 "--assigned", str(FIX / "ac6_assigned.json"),
                 "--repo-root", str(repo), "--no-grounding", "--out", str(data)],
                [sys.executable, str(S / "validate-audit-data.py"), "--data", str(data)],
                [sys.executable, str(S / "render-audit-report.py"), str(data), "--out", str(report)],
                [sys.executable, str(S / "validate-audit-data.py"),
                 "--artifacts", str(data), "--report", str(report)],
            ]
            for cmd in steps:
                with self.subTest(step=Path(cmd[1]).name + " " + cmd[2]):
                    r = sh(*cmd, cwd=repo)
                    self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(report.is_file())
            self.assertEqual(sorted(p.name for p in (repo / ".claude" / "plugin-audit").iterdir()),
                             [run_dir.name])

            status = sh("git", "status", "--porcelain", "--untracked-files=all", cwd=repo)
            self.assertEqual(status.returncode, 0, status.stderr)
            self.assertEqual(status.stdout, "", "실행 디렉토리가 사용자 리포의 git status 에 샌다")

            # 양성 대조 — 위 status 검사가 무언가를 볼 수 있다는 증거. 자기-ignore 를 떼면 보여야 한다.
            (run_dir / ".gitignore").unlink()
            status = sh("git", "status", "--porcelain", "--untracked-files=all", cwd=repo)
            self.assertIn("audit.md", status.stdout,
                          "양성 대조 실패 — .gitignore 를 떼도 status 가 비었다 (검사가 공허하다)")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 돌린다**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_run_dir_pipeline`
Expected: `Ran 1 test` · OK. (Task 1·2 가 이미 들어와 있으므로 처음부터 GREEN 이 정답이다 — 그래서 Step 3 의 변이가 이빨의 증거다.)

- [ ] **Step 3: 커밋 후 변이 하나**

```bash
git add plugins/plugin-audit/tests/test_run_dir_pipeline.py
git commit -m "test(plugin-audit): 실행 디렉토리 post-1 끝-끝 — 사용자 리포 git status 가 비어야 한다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

변이: `prepare-run-dir.py` 에서 `.gitignore` 쓰기 줄을 지운다 → 이 테스트가 `실행 디렉토리가 사용자 리포의 git status 에 샌다` 로 FAIL. `git checkout HEAD -- plugins/plugin-audit/scripts/prepare-run-dir.py` · `git diff HEAD --stat` 빈 출력 확인.

---

## Task 4: SKILL · README · tests/README 를 실행 디렉토리로 (AC7)

설계 「Deferred to plan」 3 의 답: 재앵커 문자열은 아래 `INVARIANTS` 다. SKILL 문구는 Step 3 의 블록으로 정해진다.

**Files:**
- Modify: `plugins/plugin-audit/skills/auditing-plugins/SKILL.md:25-36`(phase 0) · `:63-87`(pre-1 step 1·2) · `:158-202`(post-1)
- Modify: `plugins/plugin-audit/README.md:7-18`(사용법) · `:71-72`(Law 3)
- Modify: `plugins/plugin-audit/tests/README.md:14` · `:20-23`
- Test: `plugins/plugin-audit/tests/test_skill_orchestration.py`(전체 교체)

**Interfaces:**
- Consumes: Task 1 의 CLI 와 두 줄 출력 · Task 2 의 render/validate CLI.
- Produces: SKILL 이 쓰는 이름 — `$RUN_DIR`(실행 디렉토리 절대경로, 리터럴로 운반) · `<sandbox id>`(prepare-run-dir 둘째 줄) · 산출 파일 `$RUN_DIR/audit-data.json` · `$RUN_DIR/audit.md` · `$RUN_DIR/audit-journal.jsonl` · `$RUN_DIR/consent.json`.

- [ ] **Step 1: 테스트를 먼저 바꾼다 (RED)**

`plugins/plugin-audit/tests/test_skill_orchestration.py` 전체를 다음으로 바꾼다:

```python
import re
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
SKILL = PLUGIN / "skills" / "auditing-plugins" / "SKILL.md"
README = PLUGIN / "README.md"
# 버그 형태: `--artifacts` 에 실행 디렉토리 자체를 넘긴다 — validate-audit-data.py가
# `read_text()`+`json.loads()`에서 IsADirectoryError로 죽는다 (review fix 1).
_BUGGY_ARTIFACTS_DIR_FORM = re.compile(r'--artifacts\s+"?\$RUN_DIR/?"?(\s|$)')
# 각 불변식 = body-unique 문구 (헤더-satisfiable 금지)
INVARIANTS = [
    "cost_class: high",                                    # 지출 게이트 owner
    "DEVBREW_PLUGIN_AUDIT_DISABLE",                         # kill switch
    "AskUserQuestion",                                     # 지출 동의 게이트 (C2)
    "check-law2.py",                                        # pre-0 정적 게이트
    "check-no-verdict-injection.py",                       # B
    "check-plugin-structure.sh",                           # E
    "check-shape-completeness.py",                         # F
    "smoke-workflow.js",                                   # namespaced agent 실증
    "assemble-audit-data.py",                              # post-1 조립
    "check-grounding.py",                                  # A
    "render-audit-report.py", "validate-audit-data.py",   # post-1
    # blind codex (P11). 2026-08-09 codex 통일 1단계에서 산문 `codex exec -s read-only`를
    # 리터럴 게이트로 바꿨다. `-s read-only`의 집행 지점은 이제 러너
    # (`scripts/run_audit_codex_reviewer.sh`)이고, 그 축은 문서 문자열이 아니라 **실행 관측**으로
    # 잰다 — `test_run_audit_codex_reviewer.py::test_argv_carries_contract_flags_and_dash`가
    # 실제 호출의 argv에서 `-s` 다음 값이 `read-only`임을 확인한다(문자열 grep보다 강하다).
    # 여기서 pin하는 것은 "SKILL이 그 러너를 게이트 안에서 부른다"는 사실이다.
    "codex-gate:begin runner=run_audit_codex_reviewer.sh",
    "자기서술은 감사 material이지 verdict 프레임이 아니다",   # AC-8b redaction (C17)
    "캐시 갱신 + 세션 재시작",                               # GC8
    # 실행 디렉토리는 지출 동의 승인 직후 prepare-run-dir.py 가 만든다 (설계 2026-09-28 §2).
    "prepare-run-dir.py",
    # 빈 RUN_DIR 가드 — Bash 도구는 셸 변수를 다음 호출로 넘기지 않는다.
    '[ -d "$RUN_DIR" ] ||',
    # sandbox 이름은 실행 키가 아니라 그 해시다 — qg create-sandbox 는 id 앞 8글자만 쓴다 (D1.1).
    "run-own-tests.sh plugins/<target> <sandbox id>",
    # H (/qg 2026-07-20 round-2): step-2 --out은 step-7이 검증하는 경로에 pin돼야 한다.
    '--out "$RUN_DIR/audit-data.json"',
    '--artifacts "$RUN_DIR/audit-data.json" --report "$RUN_DIR/audit.md"',
    # H: Workflow journal을 실행 디렉토리의 원장 파일로 persist (render 의 "journal로 확인하라" 포인터의 실체).
    "audit-journal.jsonl",
    # H R5 (codex re-verify): raw transcript journal 저술 전 P21 secret 스캔 필수 (자격증명 유출 방지).
    "P21 secret 스캔",
]


class TestSkillOrchestration(unittest.TestCase):
    def test_all_invariants_present(self):
        body = SKILL.read_text(encoding="utf-8")
        for inv in INVARIANTS:
            self.assertIn(inv, body, f"SKILL.md missing load-bearing invariant: {inv}")

    def test_cost_class_high_in_frontmatter(self):
        fm = SKILL.read_text(encoding="utf-8").split("---")[1]
        self.assertIn("cost_class: high", fm)

    def test_journal_acquired_before_assembly(self):  # H R4 (codex re-verify)
        # journal 확보가 assemble/render 뒤에 오면, journal 미획득을 degraded[]에 넣어 배너에 반영할 수
        # 없다(이미 렌더됨). 원장(journal) 확보 스텝이 assemble --out(post-1 조립)보다 **앞서야** 한다.
        body = SKILL.read_text(encoding="utf-8")
        j = body.find("audit-journal.jsonl")
        a = body.find('--out "$RUN_DIR/audit-data.json"')
        self.assertNotEqual(j, -1, "journal persist 스텝 부재")
        self.assertNotEqual(a, -1, "assemble --out 실행 디렉토리 경로 부재")
        self.assertLess(j, a, "journal 확보가 assemble 뒤에 옴 — 미획득 degrade가 배너에 못 실린다 (R4)")

    def test_run_dir_made_after_consent(self):
        # 거절이면 실행 디렉토리가 생기지 않는다 — 생성 호출이 동의 게이트보다 뒤에 와야 한다.
        body = SKILL.read_text(encoding="utf-8")
        consent, prep = body.find("AskUserQuestion"), body.find("prepare-run-dir.py")
        self.assertNotEqual(prep, -1)
        self.assertLess(consent, prep, "prepare-run-dir.py 호출이 지출 동의 게이트보다 앞에 있다")

    def test_no_docs_audits_path(self):  # AC7
        for path in (SKILL, README):
            with self.subTest(file=path.name):
                self.assertNotIn("docs/audits", path.read_text(encoding="utf-8"))
        # 양의 짝 — 부재 단언은 파일이 비어도 참이다.
        self.assertIn('"$RUN_DIR/audit.md"', SKILL.read_text(encoding="utf-8"))
        self.assertIn(".claude/plugin-audit/", README.read_text(encoding="utf-8"))

    def test_validate_artifacts_invocation_is_not_bare_directory(self):
        # review fix 1 regression lock: `--artifacts "$RUN_DIR"` (실행 디렉토리 자체) crashes
        # validate-audit-data.py with IsADirectoryError — --artifacts must point at the audit-data
        # JSON file + pass --report.
        body = SKILL.read_text(encoding="utf-8")
        self.assertIsNone(
            _BUGGY_ARTIFACTS_DIR_FORM.search(body),
            "SKILL.md tells the orchestrator to call `validate-audit-data.py --artifacts \"$RUN_DIR\"` "
            "(bare directory) — this crashes with IsADirectoryError; --artifacts must point at the "
            "audit-data JSON file.",
        )
        self.assertIn(
            "--report",
            body,
            "SKILL.md's corrected --artifacts invocation must also pass --report "
            "(the rendered .md), per validate-audit-data.py's real CLI contract.",
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_skill_orchestration`
Expected: FAIL — `test_all_invariants_present`(`prepare-run-dir.py` 부재), `test_journal_acquired_before_assembly`(assemble --out 부재), `test_run_dir_made_after_consent`, `test_no_docs_audits_path`. `test_cost_class_high_in_frontmatter` · `test_validate_artifacts_invocation_is_not_bare_directory` 는 PASS.

- [ ] **Step 3: SKILL 을 고친다**

`plugins/plugin-audit/skills/auditing-plugins/SKILL.md` 에서 아래를 차례로 바꾼다.

(a) phase 0 의 3·4번(`3. **clean-worktree precondition**…` 부터 `승인 없으면 종료. consent 아티팩트(`{approved, at, fanout}`)를 저술.` 까지)을 다음으로:

```markdown
3. **지출 동의 게이트 (cost_class: high, C2의 두 의무)** — fan-out(약 30 dispatch: 6축 + 축별 refute
   + codex refute + deep-verify 최대 8×2)을 선언하고 `AskUserQuestion`으로 명시 승인을 받는다.
   승인 없으면 종료 — 실행 디렉토리를 만들지 않는다.
4. **실행 디렉토리** — 승인 직후 **한 번만** 부른다:
   `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/prepare-run-dir.py" <target> --repo-root .`
   stdout 첫 줄이 실행 디렉토리의 절대경로(`$RUN_DIR` — `.claude/plugin-audit/<date>-<target>[-N]/`,
   basename 이 실행 키), 둘째 줄이 **sandbox id**(실행 키의 SHA-256 앞 8 hex)다. 디렉토리는 안의
   `.gitignore`(`*`)로 스스로 git-ignore 된다. 같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만들고
   이전 결과를 덮지 않는다.
   Bash 도구는 호출마다 새 셸이라 두 값이 다음 호출로 넘어가지 않는다 — 이후 모든 명령에 **리터럴로**
   넣는다. `$RUN_DIR` 을 쓰는 펜스는 첫 줄에 `RUN_DIR=<그 경로>` 를 두고 바로
   `[ -d "$RUN_DIR" ] || { echo "[plugin-audit] RUN_DIR 이 비었거나 없다 — 멈춘다" >&2; exit 1; }` 로
   가드한다 — 빈 값이면 `"$RUN_DIR/audit-data.json"` 이 루트의 `/audit-data.json` 이 된다. 한 감사
   안에서 다시 부르지 않는다 — 다시 부르면 `-2` 가 생겨 산출이 두 디렉토리로 갈라진다.
   consent 아티팩트(`{approved, at, fanout}`)를 `$RUN_DIR/consent.json` 으로 저술한다. 이후의 모든
   중간 파일(무결성 스냅샷 · 축 질문 `$AXIS_FILE` · `$CODEX_JSON` · `wf.json` · `codex.json` ·
   `meta.json` · `assigned.json`)도 `$RUN_DIR` 에 둔다.
   **중간 abort** — 실행 디렉토리가 생긴 뒤(pre-0 hard error · 무결성 불일치 등) 멈추면 디렉토리를
   지우지 않고, abort 메시지에 그 절대경로를 적는다.
```

주의: 이 블록에 `--out "$RUN_DIR/audit-data.json"` 형태를 쓰지 않는다 — `test_journal_acquired_before_assembly` 가 그 문자열의 **첫** 위치를 assemble 단계로 읽는다.

(b) pre-1 step 1 의 `check-integrity.sh ld5 <before.txt> --target <target> [--extra-path ...]` → `check-integrity.sh ld5 "$RUN_DIR/before.txt" --target <target> [--extra-path ...]`, `check-integrity.sh harness <before-harness.txt>` → `check-integrity.sh harness "$RUN_DIR/before-harness.txt"`.

(c) pre-1 step 2 의 세 줄짜리 불릿(`   - \`staleness_facts\`는 \`check-staleness.py plugins/<target>\`, \`own_tests\`는` 로 시작해 `\`shape_gaps\`는 pre-0의 E/F 출력을 그대로 이관한다.` 로 끝난다) 전체를 다음으로:

```markdown
   - `staleness_facts`는 `check-staleness.py plugins/<target>`, `own_tests`는
     `run-own-tests.sh plugins/<target> <sandbox id>` (quality-gates 미설치 시 skip 사실만) — `<sandbox id>` 는
     phase 0 step 4 의 둘째 줄이다. `qg-worktree.sh create-sandbox` 는 id 의 앞 8글자만 sandbox 이름에 쓰고
     같은 이름의 sandbox 를 지우고 다시 만들므로 실행 키를 그대로 넘기지 않는다. `structure_facts`/
     `shape_gaps`는 pre-0의 E/F 출력을 그대로 이관한다.
```

(d) post-1 머리 두 줄(`이하 \`<data.json>\` = **canonical 경로** …` · `검증하는 바로 그 파일). tmp/scratch …`)을:

```markdown
이하 `<data.json>` = `$RUN_DIR/audit-data.json` (step 7의 `--artifacts`가 검증하는 바로 그 파일). 다른
경로에 쓰면 step 7이 파일을 못 찾아 산출물 검증이 깨진다 (H /qg 2026-07-20). `<wf.json>` · `<codex.json>` ·
`<meta.json>` · `<assigned.json>` 도 `$RUN_DIR/` 아래 같은 이름의 파일이다.
```

(e) post-1 step 1 의 첫 문장부터 `…dangling 참조다.` 까지(현재 `:163`~`:169`)를:

```markdown
1. **원장 확보 (assemble 前 — P21)**: Workflow 실행이 남긴 `journal.jsonl`(그 run의 transcript
   디렉토리)을 얻어 **먼저 P21 secret 스캔**을 돌린다 — 비밀/자격증명 패턴은 placeholder 참조로 redact하고,
   스캔이 실패하거나 redact 못 하는 secret이 남으면 **persist하지 않는다**. 리포트와 원장은 사람이 복사·공유하는
   산출물이라, raw transcript journal을 그대로 두면 자격증명·민감 소스가 그 공유 경로로 샌다(codex re-verify
   R5). 통과분만 `$RUN_DIR/audit-journal.jsonl`로 저술한다. 이 파일이 `render-audit-report.py`의 "축 완주 수와
   journal로 확인하라" 포인터의 **실체**다 — journal 은 실행 디렉토리의 작업 산출물이고, persist 안 하면 그
   포인터가 부재 아티팩트를 가리키는 dangling 참조다.
```

그 뒤의 `journal을 얻지 못하거나 secret 때문에 …` 문장은 그대로 둔다.

(f) step 2 의 `--assigned <assigned.json> --repo-root . --out docs/audits/<date>-<target>-audit-data.json\` (내부에서` → `--assigned <assigned.json> --repo-root . --out "$RUN_DIR/audit-data.json"\` (내부에서`.

(g) step 4 를 `4. \`render-audit-report.py <data.json> --out "$RUN_DIR/audit.md"\`.` 로(다음 줄 `6축 전멸(exit 1) → 리포트 없음(AC-4).` 은 유지).

(h) step 5 의 `check-integrity.sh ld5 <after.txt> --target <target>` → `check-integrity.sh ld5 "$RUN_DIR/after.txt" --target <target>`, `check-integrity.sh harness <after-harness.txt>` → `check-integrity.sh harness "$RUN_DIR/after-harness.txt"`.

(i) step 6 두 줄을:

```markdown
6. **정직성 배너 (AC-3)**: `degraded[]` 비어있지 않으면 리포트 상단 배너 필수. step 1의 원장 미확보/secret
   degrade도 여기 포함.
```

(j) step 7 의 첫 두 줄(`7. \`validate-audit-data.py --artifacts docs/audits/…` · `docs/audits/<date>-<target>-audit.md --repo-root .\` → 산출물(README 링크·배너) 검사. (\`--artifacts\`는`)을:

```markdown
7. `validate-audit-data.py --artifacts "$RUN_DIR/audit-data.json" --report "$RUN_DIR/audit.md"` → 산출물(배너)
   검사. (`--artifacts`는
```

로 바꾸고 괄호 안 나머지 문장은 그대로 둔다. step 7 문단 끝 다음 줄에 추가:

```markdown
8. **종료 보고** — 리포트(`$RUN_DIR/audit.md`) · 데이터(`$RUN_DIR/audit-data.json`) · 원장
   (`$RUN_DIR/audit-journal.jsonl`)의 절대경로를 사용자에게 보인다. 리포트는 한 번 읽는 작업 산출물이다 —
   실행 디렉토리는 git-ignore 되고 커밋하지 않는다. 이 감사의 compounding 은 감사가 낳은 수정 커밋과
   reviewer persona 편집이 맡는다.
```

확인: `grep -nE 'docs/audits|clean-worktree|clean tree|커밋' plugins/plugin-audit/skills/auditing-plugins/SKILL.md` → `docs/audits` · `clean-worktree` · `clean tree` 0건, `커밋` 은 step 8 의 「커밋하지 않는다」·「수정 커밋」 두 자리뿐이다.

- [ ] **Step 4: README 둘을 고친다**

`plugins/plugin-audit/README.md` — Law 3 두 줄(`- **Law 3 (Every Cycle Leaves the System Smarter)** — 감사 결과는 …` · `커밋되고 인덱스(…)에서 검색 가능. journal.jsonl이 named/diff-able history.`)을:

```markdown
- **Law 3 (Every Cycle Leaves the System Smarter)** — 리포트는 한 번 읽는 작업 산출물이다
  (`.claude/plugin-audit/<실행 키>/`, 스스로 git-ignore). 이 사이클의 compounding 은 감사가 낳은 수정
  커밋과 reviewer persona 편집이 맡는다.
```

사용법 절의 `Kill switch: \`DEVBREW_PLUGIN_AUDIT_DISABLE=1\`.` 줄 다음에 빈 줄과 함께:

```markdown
**산출 위치** — 감사마다 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/` 이 생긴다(지출 동의
승인 직후, `scripts/prepare-run-dir.py`). 리포트 `audit.md` · 데이터 `audit-data.json` · 원장
`audit-journal.jsonl` 과 중간 파일이 모두 여기 쌓이고, 안의 `.gitignore`(`*`)로 스스로 git-ignore 된다.
감사가 끝나면 세 파일의 절대경로를 보고한다. 같은 날 같은 대상을 다시 감사하면 `-2` 로 새로 만든다.
```

`plugins/plugin-audit/tests/README.md` — `:14` 를:

```markdown
2. **phase 0** 지출 동의 게이트 (`AskUserQuestion`, fanout 30) → 승인 직후 `prepare-run-dir.py` 로 실행
   디렉토리 생성 → consent artifact(`$RUN_DIR/consent.json`).
```

`:20`~`:23`(6번 항목) 끝의 `` `validate-audit-data.py --data` → `render-audit-report.py` → CLAUDE.md 포인터 →`` · `` `validate-audit-data.py --artifacts` → AFTER#2 → 커밋(scripts/** 포함).`` 두 줄을:

```markdown
   `validate-audit-data.py --data` → `render-audit-report.py` → `validate-audit-data.py --artifacts` →
   AFTER#2 → 종료 보고(실행 디렉토리의 리포트 · 데이터 · 원장 절대경로).
```

- [ ] **Step 5: GREEN 확인**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_skill_orchestration test_skill_codex_gate`
Expected: 둘 다 OK. `bash plugins/quality-gates/tests/test_codex_gate_observation.sh`(SKILL 의 codex 게이트 블록을 잘라 실행한다) → 기준선과 같은 결과.

- [ ] **Step 6: 커밋**

```bash
git add plugins/plugin-audit/skills/auditing-plugins/SKILL.md plugins/plugin-audit/README.md \
        plugins/plugin-audit/tests/README.md plugins/plugin-audit/tests/test_skill_orchestration.py
git commit -m "feat(plugin-audit): 산출을 실행 디렉토리로 — clean-tree 선결 · README 인덱스 · 커밋 단계 제거

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 변이 셋 (AC7)**

각각 SKILL 을 바꿔 `test_skill_orchestration` 을 돌리고 `git checkout HEAD -- plugins/plugin-audit/skills/auditing-plugins/SKILL.md` 로 되돌린다.
1. post-1 step 1 문단 전체를 step 2 뒤로 옮긴다 → `test_journal_acquired_before_assembly` FAIL.
2. step 7 의 `--artifacts "$RUN_DIR/audit-data.json"` 을 `--artifacts "$RUN_DIR"` 로 → `test_validate_artifacts_invocation_is_not_bare_directory` FAIL(그리고 불변식 하나 FAIL).
3. `<sandbox id>` 를 `<실행 키>` 로 → `test_all_invariants_present` FAIL.

---

## Task 5: AC6 기준선 fixture 이동 (AC8)

**Files:**
- Move: `docs/audits/2026-07-15-project-init-audit-data.json` → `plugins/plugin-audit/tests/fixtures/ac6_baseline.json`
- Modify: `plugins/plugin-audit/tests/fixtures/ac6_build.py:4` · `:15-16`
- Modify: `plugins/plugin-audit/tests/test_ac6_regression.py:7`

**Interfaces:**
- Produces: `plugins/plugin-audit/tests/fixtures/ac6_baseline.json`(내용 불변).

- [ ] **Step 1: 옮기고 두 파일을 고친다**

```bash
git mv docs/audits/2026-07-15-project-init-audit-data.json plugins/plugin-audit/tests/fixtures/ac6_baseline.json
```

`test_ac6_regression.py:7` → `BASELINE = FIX / "ac6_baseline.json"`(`FIX` 는 `:5` 에 이미 있다).

`ac6_build.py` — docstring 의 `` baseline `docs/audits/2026-07-15-project-init-audit-data.json`(진리원천)을 읽어 `` → `` baseline `ac6_baseline.json`(같은 디렉토리, 진리원천)을 읽어 ``, 그리고 `:15`~`:16` 두 줄을 한 줄로:

```python
BASELINE = Path(__file__).resolve().parent / "ac6_baseline.json"
```

(`ROOT` 는 이제 쓰이지 않으므로 지운다 — `grep -n ROOT plugins/plugin-audit/tests/fixtures/ac6_build.py` 가 0건이어야 한다.)

- [ ] **Step 2: 돌린다**

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -v test_ac6_regression`
Expected: OK.
Run: `cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed`
Expected: `Ran 15 tests` · OK. (계획 작성 때 fixture 경로에 미추적 사본을 두고 같은 테스트를 돌려 GREEN 을 확인했다 — 이 테스트는 미추적 파일도 스캔한다.) **RED 면**: `HISTORY` 정규식에 `|^plugins/plugin-audit/tests/fixtures/ac6_baseline\.json$` 를 더하고, docstring (a) 목록에 「`plugins/plugin-audit/tests/fixtures/ac6_baseline.json`(감사 데이터 원문을 AC6 정답지로 동결한 것 — 인용된 식별자는 과거 감사가 본 코드다)」를 더한다.

- [ ] **Step 3: 커밋 후 변이 하나**

```bash
# rename 은 git mv 가 이미 스테이징했다 — 옛 경로를 다시 add 하지 않는다(pathspec 불일치 오류).
git add plugins/plugin-audit/tests/fixtures/ac6_build.py plugins/plugin-audit/tests/test_ac6_regression.py
git commit -m "test(plugin-audit): AC6 기준선을 tests/fixtures/ac6_baseline.json 으로 옮긴다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git status --porcelain` 로 rename 이 `R` 한 줄로 잡혔는지 확인한다.)
변이: `ac6_baseline.json` 의 첫 finding `"id"` 값 하나를 다른 문자열로 바꾼다 → `test_ac6_regression` FAIL(새 경로를 실제로 읽는다는 증거). `git checkout HEAD -- plugins/plugin-audit/tests/fixtures/ac6_baseline.json`.

---

## Task 6: 인용 정리 — 개념 인용 10곳 · 경로 인용 둘 · CLAUDE.md 절 (AC9 · AC10)

규칙(설계 D12): 출처 괄호만 지운다. 둘레 문장의 단어는 바꾸지 않는다. 가리키던 절 번호를 다른 문서 번호로 바꿔 넣지 않는다. 괄호 안에 감사 문서 인용과 정본 인용이 함께 있으면 감사 문서 인용만 지운다.

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md:147` · `:150`
- Modify: `shared/tests/presence_corpus.sh:18` · `:28`
- Modify: `plugins/spec-distill/tests/test_proceed_gate_adopters.sh:35` · `:36` · `:187-188`
- Modify: `plugins/spec-distill/tests/test_brief_review_entry.sh:127`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh:53` · `:835`
- Modify: `shared/tests/test_no_new_duplication.sh:246-247`
- Modify: `shared/tests/test_presence_corpus_behavior.sh:95`
- Modify: `CLAUDE.md`(`## Audits` 절)

**Interfaces:** 없음(문면 변경).

- [ ] **Step 1: 열 자리를 바꾼다**

| 파일:줄 | 전 | 후 |
|---|---|---|
| `proceed-gate.md:147` | `처방(감사문서 §3)은 *부재* 검사의 것이다.` | `처방은 *부재* 검사의 것이다.` |
| `proceed-gate.md:150` | `그 편집을 막으라고 있는 것이다(감사문서의 「거울 클래스」 절과 「공유 참조 파일」 절 참조).` | `그 편집을 막으라고 있는 것이다.` |
| `presence_corpus.sh:18` | `# 부재 전용 배열 쪽으로 넓혀야 한다(감사문서 「공유 참조 파일」 절).` | `# 부재 전용 배열 쪽으로 넓혀야 한다.` |
| `presence_corpus.sh:28` | `# 을 구별할 수 없다. 앞선 판본이 정확히 그랬다(감사문서 「계측기」 절).` | `# 을 구별할 수 없다. 앞선 판본이 정확히 그랬다.` |
| `test_proceed_gate_adopters.sh:35` | `처방(감사문서 §3)은 **부재** 검사의 것이다.` | `처방은 **부재** 검사의 것이다.` |
| `test_proceed_gate_adopters.sh:36` | `이빨이 0 이 된다(감사문서 §8). 아래 구조적 가드가` | `이빨이 0 이 된다. 아래 구조적 가드가` |
| `test_proceed_gate_adopters.sh:187-188` | `…형태가 생긴다(감사문서` / `  # 「이월된 미해결 항목」의 degrade 채널 항목). 여기서 잡는 것은 …` | `…형태가 생긴다.` / `  # 여기서 잡는 것은 …` |
| `test_brief_review_entry.sh:127` | `# (감사문서 「공유 참조 파일」 절 · 정본 「앵커는 각 skill 에」 절).` | `# (정본 「앵커는 각 skill 에」 절).` |
| `test_conducting_interview_stage.sh:53` | 위와 같은 줄 | 위와 같은 결과 |
| `test_conducting_interview_stage.sh:835` | `# 못한다(실측: 감사문서 \`§8\` 인용 하나로 발화). 거짓 RED 지만 시끄러우므로 안전하다.` | `# 못한다. 거짓 RED 지만 시끄러우므로 안전하다.` |

Edit 도구로 한 자리씩 바꾼다(각 줄의 앞뒤 문맥은 설계 Context §1 의 인용 위치 그대로다).

- [ ] **Step 2: 경로 인용 둘**

`shared/tests/test_no_new_duplication.sh:246-247` 두 줄

```
# "vacuous 아님" 을 찍는다. 이 리포가 이미 문서화한 실패 클래스 그대로다 —
# docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md §3 (코퍼스가 줄어도 락은 GREEN).
```
을 한 줄로:
```
# "vacuous 아님" 을 찍는다. 코퍼스가 줄어도 락은 GREEN 인 실패 클래스 그대로다.
```

`shared/tests/test_presence_corpus_behavior.sh:95` — `probe "docs/audits/x.md" >/dev/null 2>&1` → `probe "docs/x.md" >/dev/null 2>&1`.

- [ ] **Step 3: CLAUDE.md `## Audits` 절을 지운다**

파일 끝의 `## Audits` 헤딩과 그 문단(`읽기전용 플러그인 감사 리포트는 …찾는다.`)을 앞의 빈 줄과 함께 지운다. 파일은 `## Doc Conventions` 절의 마지막 불릿으로 끝나고 끝 개행 하나를 가진다.

- [ ] **Step 4: 확인**

```bash
git grep -nE '감사 ?문서' -- plugins/spec-distill/references/proceed-gate.md shared/tests/presence_corpus.sh \
  plugins/spec-distill/tests/test_proceed_gate_adopters.sh plugins/spec-distill/tests/test_brief_review_entry.sh \
  plugins/spec-distill/tests/test_conducting_interview_stage.sh     # 0줄
grep -nE '§[89]([^.0-9]|$)' plugins/spec-distill/references/proceed-gate.md     # 0줄
grep -n 'Audits' CLAUDE.md                                                      # 0줄
bash shared/tests/test_presence_corpus_behavior.sh
bash shared/tests/test_no_new_duplication.sh
bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh
bash plugins/spec-distill/tests/test_brief_review_entry.sh
bash plugins/spec-distill/tests/test_conducting_interview_stage.sh
```
Expected: 앞 셋 0줄, 뒤 다섯은 기준선과 같은 결과(새 ✗ 없음 — `failures.txt` 의 그 파일 줄과 대조).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/proceed-gate.md shared/tests/presence_corpus.sh \
  plugins/spec-distill/tests/test_proceed_gate_adopters.sh plugins/spec-distill/tests/test_brief_review_entry.sh \
  plugins/spec-distill/tests/test_conducting_interview_stage.sh shared/tests/test_no_new_duplication.sh \
  shared/tests/test_presence_corpus_behavior.sh CLAUDE.md
git commit -m "docs: 감사 문서 인용 괄호와 CLAUDE.md ## Audits 절을 지운다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 7: 부재 락과 폴더 제거 (AC1 · AC8 후반 · §3-7)

이 커밋이 덩어리 1 의 마지막이다. 부재 단언 뒤집기와 `test_review_hook_removed.py` 의 역사 면제 축소를 폴더 삭제와 **같은 커밋**에 둔다 — 앞 커밋에 두면 폴더가 아직 있어 그 사이 커밋이 RED 다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh:1-10`(머리 주석) · `:47-50`((5))
- Modify: `plugins/spec-distill/tests/test_review_hook_removed.py:20-21`(docstring) · `:109-112`(HISTORY)
- Delete: `docs/audits/**` · `docs/archive/audits/**`

**Interfaces:** 없음.

- [ ] **Step 1: 부재 단언을 쓴다 (RED)**

`test_brief_review_no_external_precondition.sh` 의 (5) 세 줄(`:47`~`:50`)을:

```bash
# (5) 감사 폴더는 리포에 없다 — 작업 트리의 존재를 잰다(추적 여부와 무관). 폴더가 되살아나면
#     (다른 브랜치 병합 · 옛 plugin-audit 캐시의 재기록) 여기서 RED 다.
{ [ ! -e "$REPO_ROOT/docs/audits" ] && [ ! -e "$REPO_ROOT/docs/archive/audits" ]; } \
  && ok "감사 폴더 docs/audits · docs/archive/audits 가 작업 트리에 없다" \
  || no "감사 폴더가 되살아났다 — docs/audits 또는 docs/archive/audits 가 작업 트리에 있다"
```

머리 주석 `:2` 를 `# B1 — 배포 단위 밖 파일(감사 폴더) 없이도 brief 리뷰 격리 락이 도는가. (5) 는 그 폴더의 부재 락이다.` 로 바꾼다(`:9`~`:10` 의 설명은 임시 루트 이야기라 그대로 둔다).

Run: `bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh`
Expected: `✗ 감사 폴더가 되살아났다 …` 한 줄, rc 1.

- [ ] **Step 2: 역사 면제를 줄인다**

`test_review_hook_removed.py` 의 `HISTORY` 를:

```python
HISTORY = re.compile(
    r"(^|/)CHANGELOG\.md$|^docs/archive/"
    r"|^docs/superpowers/(specs|plans|interview)/"
)
```

docstring (a) 두 줄을:

```
  (a) 역사 — `*/CHANGELOG.md` · `docs/archive/**` · `docs/superpowers/{specs,plans,interview}/**`
```

(`^docs/archive/` 는 유지한다 — interview · plans · specs 의 archive 가 남는다.)

- [ ] **Step 3: 폴더를 지운다**

직전에 대상을 다시 본다(동시 세션이 파일을 옮겼을 수 있다):

```bash
git ls-files docs/audits docs/archive/audits | wc -l          # 계획 작성 때 19 (Task 5 뒤 18)
ls -la docs/audits docs/archive/audits                        # 숨김·미추적 파일이 없는지
git rm -r -q docs/audits docs/archive/audits
[ ! -e docs/audits ] && [ ! -e docs/archive/audits ] && echo gone || echo LEFTOVER
```

`LEFTOVER` 면 남은 것이 무엇인지 `ls -la` 로 보고 멈춘다 — 확인 없이 `rm -rf` 하지 않는다.

- [ ] **Step 4: GREEN 확인**

```bash
bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh
( cd plugins/spec-distill/tests && python3 -m unittest -v test_review_hook_removed )
( cd plugins/plugin-audit/tests && python3 -m unittest -v test_ac6_regression )
```
Expected: 셋 다 통과(첫째는 `✓ 감사 폴더 docs/audits · docs/archive/audits 가 작업 트리에 없다`).

- [ ] **Step 5: 1회 점검 (§3-7)**

```bash
git grep -nE 'docs/(archive/)?audits|§ ?Audits|## Audits|감사 ?문서' -- plugins shared CLAUDE.md \
  | tee ~/.claude/sdd-mirror/resolve-audits/sweep.txt
```
걸린 줄을 한 줄씩 읽고 판정을 `sweep.txt` 옆 `sweep-judged.md` 에 적는다(`<파일:줄> — 역사 기록 | 부재 락 자신 | 무관한 일반어 | 남은 끈`). 예상: `*/CHANGELOG.md` 줄(역사) · `test_brief_review_no_external_precondition.sh` 줄(부재 락 자신 — 경로를 문자열로 쥔다) · `test_skill_orchestration.py` 의 `docs/audits` 부재 단언. **남은 끈**이 하나라도 있으면 멈추고 보고한다. 이 결과를 PR 본문에 싣는다(AC10). 영구 락이 아니다(D16).

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh plugins/spec-distill/tests/test_review_hook_removed.py
git status --porcelain | grep -vE '^D  docs/(archive/)?audits/' | grep -vE 'test_brief_review_no_external_precondition|test_review_hook_removed'   # 빈 출력
git commit -m "chore: docs/audits · docs/archive/audits 를 지우고 부재 락으로 뒤집는다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git show --stat HEAD | tail -3      # 파일 수 = 삭제 18 + 수정 2
```

- [ ] **Step 7: 변이 둘 (AC1)**

1. `mkdir -p docs/audits && touch docs/audits/x.md` → `bash plugins/spec-distill/tests/test_brief_review_no_external_precondition.sh` 에 `✗ 감사 폴더가 되살아났다` · rc 1. 그리고 `rm -r docs/audits`(방금 만든 것만 있다 — `ls -la docs/audits` 로 확인 후).
2. `mkdir -p docs/archive/audits && touch docs/archive/audits/x.md` → 같은 ✗ 줄. `rm -r docs/archive/audits`.
끝나고 `git status --porcelain` 빈 출력.

---

## Task 8: project-init Pattern B — 태그에서 자른다 (AC11)

설계 「Deferred to plan」 2 의 답: 리포 전체 grep(`release/v1\.x|checkout -b release|S4 \(AGENTS|재작성`) 결과 Pattern B · S4 문구를 리터럴로 기대하는 락은 없다. 걸린 것은 `plugins/plugin-audit/tests/fixtures/ac6_*.json`(과거 감사가 인용한 원문 — 데이터이고 `--no-grounding` 으로 돈다)과 `plugins/project-init/tests/test_post_tool_use.py`(훅 입력 표본 `git checkout -b release/x` — 템플릿과 무관)뿐이다. S4 가 속한 4c 절은 `test_command_contract.py` 가 재므로 Task 9 에서 함께 돌린다.

**Files:**
- Modify: `plugins/project-init/templates/trunk-based/branch-strategy.md:91-95`

**Interfaces:** 없음.

- [ ] **Step 1: 검사를 먼저 돌린다 (RED)**

`~/.claude/sdd-mirror/resolve-audits/check-ac11.sh` 에 쓴다:

```bash
F=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits/plugins/project-init/templates/trunk-based/branch-strategy.md
STEP1="$(awk '/^### Pattern B/{p=1} p && /^```bash/{b=1; next} b && /^# 2\./{exit} b {print}' "$F")"
[ -n "$STEP1" ] || { echo "RED: step 1 추출이 비었다"; exit 1; }
rc=0
printf '%s\n' "$STEP1" | grep -nE 'git checkout main|git pull origin main' && { echo "RED: step 1 에 main 체크아웃/풀이 남았다"; rc=1; }
printf '%s\n' "$STEP1" | grep -qE 'git checkout -b release/v1\.x [^ #]+' || { echo "RED: checkout -b release/ 가 태그 인자를 받지 않는다"; rc=1; }
[ "$rc" -eq 0 ] && echo "GREEN: AC11"
exit "$rc"
```

Run: `bash ~/.claude/sdd-mirror/resolve-audits/check-ac11.sh`
Expected: 두 RED 줄(고치기 전 본문 `:92`~`:94` 에서 참인 조건이 이빨이다), rc 1.

- [ ] **Step 2: step 1 을 바꾼다**

`:91`~`:95` 다섯 줄

```bash
# 1. trunk에서 release 브랜치 cut (1회만; hook advisory 경고는 무시하고 진행)
git checkout main
git pull origin main
git checkout -b release/v1.x
git push -u origin release/v1.x
```
을:
```bash
# 1. 마지막 v1 태그에서 release 브랜치 cut (1회만; hook advisory 경고는 무시하고 진행)
#    현재 main 은 이미 다음 major 라 v1 을 고칠 수 없다 — main 이 아니라 태그에서 자른다.
git fetch --tags
git checkout -b release/v1.x v1.2.4   # v1.2.4 = 마지막 v1 릴리스 태그 (git tag -l 'v1.*' 로 확인)
git push -u origin release/v1.x
```
step 2 의 `git checkout main`(fix 는 trunk 에 먼저)은 그대로 둔다.

- [ ] **Step 3: GREEN 확인과 커밋**

Run: `bash ~/.claude/sdd-mirror/resolve-audits/check-ac11.sh` → `GREEN: AC11`. `bash plugins/project-init/tests/test_branch_strategy_rebase_clause.sh` → 기준선과 같음.

```bash
git add plugins/project-init/templates/trunk-based/branch-strategy.md
git commit -m "fix(project-init): trunk-based Pattern B 의 legacy release 브랜치를 마지막 v1 태그에서 자른다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 9: project-init 4c S4 (i) — 비-관리 컨텐츠 이전 (AC12)

**Files:**
- Modify: `plugins/project-init/commands/project-init.md:164`(S4 행) · `:166`(보존 불변식)

**Interfaces:** 없음. `test_command_contract.py` 가 `:166` 을 **줄 머리** `비-관리 컨텐츠 (다른 헤딩` 로 찾아 그 줄에 `파일명을 지칭하는 제목은 이전 후 대상 파일을 잘못 가리키므로` 가 있는지 잰다 — 이 두 문자열을 유지한다. S2a 행(`**S2a**`~`**S2b**`)은 건드리지 않는다.

- [ ] **Step 1: 검사를 먼저 돌린다 (RED)**

`~/.claude/sdd-mirror/resolve-audits/check-ac12.sh`:

```bash
F=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/resolve-audits/plugins/project-init/commands/project-init.md
ROW="$(grep -F '**S4 (AGENTS exists' "$F")"
RULE="$(grep '^비-관리 컨텐츠 (다른 헤딩' "$F")"
rc=0
[ "$(printf '%s\n' "$ROW" | grep -c .)" -eq 1 ] || { echo "RED: S4 행이 정확히 한 줄이 아니다"; rc=1; }
for s in '비-관리 컨텐츠' '먼저 나오는 관리 섹션 앞' '`## Git Workflow`' '`## Project Charter`' '`# CLAUDE.md`' '관리 섹션 뒤에 붙이지 않는다'; do
  printf '%s' "$ROW" | grep -qF -- "$s" || { echo "RED: S4 행에 없음 — $s"; rc=1; }
done
printf '%s' "$ROW" | grep -qF '(AGENTS.md unchanged)' && { echo "RED: S4 (i) 가 여전히 AGENTS.md unchanged 라고 한다"; rc=1; }
printf '%s' "$RULE" | grep -qF 'S4 (i)' || { echo "RED: 보존 불변식이 S4 (i) 의 H1 처리를 밝히지 않는다"; rc=1; }
[ "$rc" -eq 0 ] && echo "GREEN: AC12"
exit "$rc"
```

Run: `bash ~/.claude/sdd-mirror/resolve-audits/check-ac12.sh`
Expected: RED 줄 여럿, rc 1.

- [ ] **Step 2: S4 행과 불변식을 바꾼다**

`:164` 전체를:

```markdown
| **S4 (AGENTS exists, CLAUDE divergent or absent)** | 존재 | 없음 또는 divergent content | 사용자에게 advisory + 두 옵션 — (i) CLAUDE.md가 존재하면 관리 섹션(`## Git Workflow` · `## Project Charter`)을 뺀 비-관리 컨텐츠를 AGENTS.md에서 **먼저 나오는 관리 섹션 앞**에 이전한 뒤(관리 섹션이 하나도 없으면 AGENTS.md 끝에) CLAUDE.md를 `@AGENTS.md` 한 줄로 교체한다. 관리 섹션 뒤에 붙이지 않는다 — 헤딩 없는 본문은 바로 앞 절의 일부가 되어 그 절의 제자리 갱신(이어지는 S3 action, 다음 `/project-init` 실행)이 함께 덮는다. 관리 섹션을 이전 대상에서 빼는 것은 중복 절을 막기 위해서다. 원본 파일명을 지칭하는 H1(`# CLAUDE.md`)은 이전하지 않는다(S2a (d)와 같은 근거). CLAUDE.md가 없으면 `@AGENTS.md` 포인터만 쓴다. advisory는 이전될 비-관리 컨텐츠가 있다는 것을 밝힌다. (ii) abort. 승인 시 (i) 수행 + S3 action. |
```

`:166` 전체를:

```markdown
비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존. 유일한 예외는 파일명을 지칭하는 H1(`# CLAUDE.md`)이다 — 4c S2a (d)는 재제목하고 S4 (i)는 이전하지 않는다. 파일명을 지칭하는 제목은 이전 후 대상 파일을 잘못 가리키므로 보존 대상이 아니다.
```

- [ ] **Step 3: GREEN 확인과 커밋**

```bash
bash ~/.claude/sdd-mirror/resolve-audits/check-ac12.sh                       # GREEN: AC12
( cd plugins/project-init/tests && python3 -m unittest -v test_command_contract test_post_tool_use )   # OK
```

```bash
git add plugins/project-init/commands/project-init.md
git commit -m "fix(project-init): 4c S4 (i) 가 CLAUDE.md 의 비-관리 컨텐츠를 첫 관리 섹션 앞으로 이전한다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 10: qg 테스트 스크립트 실행비트 (AC13 · AC3 일부)

**Files:**
- Modify(모드): `plugins/quality-gates/tests/test_cancel_all_fence.sh` 100644 → 100755

**Interfaces:** 없음. 소비자: `test_runner_adapters.sh:307-319`(인덱스 모드 락) · `run-test-selection.sh:670`(`-x`) · `run-own-tests.sh:102`(`find -perm -u+x`) · `qg-worktree.sh:188`(`cp -a`).

- [ ] **Step 1: RED 확인**

```bash
git ls-files -s plugins/quality-gates/tests/test_cancel_all_fence.sh      # 100644
[ -x plugins/quality-gates/tests/test_cancel_all_fence.sh ] && echo x || echo not-x   # not-x
bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | grep -E '✗' | head   # 비실행 커밋 모드 줄
```

- [ ] **Step 2: 두 곳을 함께 고친다**

```bash
chmod +x plugins/quality-gates/tests/test_cancel_all_fence.sh
git update-index --chmod=+x plugins/quality-gates/tests/test_cancel_all_fence.sh
```

- [ ] **Step 3: GREEN 확인과 커밋**

```bash
git ls-files -s plugins/quality-gates/tests/test_cancel_all_fence.sh      # 100755
[ -x plugins/quality-gates/tests/test_cancel_all_fence.sh ] && echo x     # x
bash plugins/quality-gates/tests/test_runner_adapters.sh; echo "rc=$?"     # rc=0
bash plugins/quality-gates/tests/test_codex_backward_compat.sh; echo "rc=$?"  # rc=0
git commit -m "fix(qg): test_cancel_all_fence.sh 를 100755 로 — 셸 어댑터가 claim 한다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/quality-gates/tests/test_cancel_all_fence.sh
git ls-tree HEAD plugins/quality-gates/tests/test_cancel_all_fence.sh    # 100755
```

두 테스트 중 하나라도 rc≠0 이면 그 ✗ 줄이 기준선에 있던 것인지 대조하고, 실행비트와 무관한 새 실패면 멈춘다.

---

## Task 11: matcher 양성 대조 기대를 현실로 (AC14 · AC3 일부)

**Files:**
- Modify: `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh:112-121`

**Interfaces:** 없음.

- [ ] **Step 1: RED 확인**

Run: `bash plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh`
Expected: `✗ 양성 대조 실패: Bash matcher 훅이 1개뿐`, rc 1.

- [ ] **Step 2: 임계와 주석을 고친다**

`# 양성 대조 1 — Bash matcher 는 살아 있다 (GREEN 이 정답, A2).` 다음 줄에 두 줄을 넣는다:

```bash
# 임계는 1 이다 — qg v7.0.0 이 자기 Bash matcher 훅을 의도적으로 지웠다(이 락은 그보다 먼저 생겼다).
# 이 대조의 목적은 grep 이 작동한다는 양성 증인이라 1 로 충분하다.
```

그리고 `[[ "$N_BASH" -ge 2 ]]` → `[[ "$N_BASH" -ge 1 ]]`.

- [ ] **Step 3: GREEN 확인과 커밋**

Run: `bash plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh; echo "rc=$?"`
Expected: `✓ 양성 대조: Bash matcher 훅 1개 생존`, rc 0.

```bash
git add plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh
git commit -m "test(spec-distill): matcher 양성 대조 임계를 1 로 — qg v7.0.0 이 Bash 훅을 지웠다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: 변이 (AC14)**

`plugins/project-init/hooks/hooks.json` 의 `"matcher": "Bash",` 를 `"matcher":"Bash",` 로 바꾼다(JSON 값은 그대로, 공백만). 테스트를 돌려 **두 줄**을 확인한다:
- `✓ A1: 리포 전수 — PostToolUse matcher 가 전부 '쓰기 도구 배제 증명 가능'` 이 그대로 있다
- `✗ 양성 대조 실패: Bash matcher 훅이 0개뿐` 이 나온다
`git checkout HEAD -- plugins/project-init/hooks/hooks.json` · `git diff HEAD --stat` 빈 출력.

---

## Task 12: P21 스캔에 플러그인 레벨 references (AC15)

**Files:**
- Modify: `plugins/quality-gates/tests/test_no_secret_prompts.py:14-28` · `:48-54`

**Interfaces:** 없음. 계획 작성 때 `plugins/quality-gates/references/**/*.md` 는 2파일(`docreview-profiles/generic.md` · `recritic-code-profile.md`), `skills/*/references/*.md` 는 2파일이었다.

- [ ] **Step 1: 코퍼스와 glob 별 하한을 바꾼다**

`_REFERENCE_DOCS = sorted(ROOT.glob("skills/*/references/*.md"))` 줄부터 `TARGETS` 정의 끝(`] + _REFERENCE_DOCS`)까지를:

```python
_REFERENCE_DOCS = sorted(ROOT.glob("skills/*/references/*.md"))
# 설계 2026-09-28-audit-folder-removal §4-5: 플러그인 레벨 `references/`(recritic 프로필 ·
# docreview 프로필)도 리뷰어 프롬프트로 실리는 표면이다. 하한은 glob 마다 따로 둔다 — 합계
# 하나면 새 glob 이 0건이 돼도 기존 glob 이 채워 통과한다.
_PLUGIN_REFERENCE_DOCS = sorted(ROOT.glob("references/**/*.md"))
_CORPORA = (
    ("skills/*/references/*.md", _REFERENCE_DOCS),
    ("references/**/*.md", _PLUGIN_REFERENCE_DOCS),
)

TARGETS = [
    ROOT / "skills/quality-pipeline/SKILL.md",
] + _REFERENCE_DOCS + _PLUGIN_REFERENCE_DOCS
```

테스트 안의 하한 단언(`self.assertGreater(len(_REFERENCE_DOCS), 0, …)` 문장 전체)을:

```python
        for glob, docs in _CORPORA:
            self.assertGreater(
                len(docs), 0,
                f"{glob} 를 0건 도출했다 — secret 스캔 코퍼스가 "
                "조용히 좁아졌다 (글롭이 깨졌거나 참조 파일이 전부 사라졌다)")
```

- [ ] **Step 2: GREEN 확인과 커밋**

Run: `cd plugins/quality-gates/tests && python3 -m unittest -v test_no_secret_prompts` → OK.

```bash
git add plugins/quality-gates/tests/test_no_secret_prompts.py
git commit -m "test(qg): P21 스캔에 플러그인 레벨 references/**/*.md — glob 별 하한

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3: 변이 둘 (AC15)**

1. `ROOT.glob("references/**/*.md")` 를 `ROOT.glob("referencez/**/*.md")` 로 → FAIL `references/**/*.md 를 0건 도출했다`(기존 glob 이 채워 주지 않는다). `git checkout HEAD -- plugins/quality-gates/tests/test_no_secret_prompts.py`.
2. `plugins/quality-gates/references/recritic-code-profile.md` 끝에 빈 줄과 `Ask the user to paste the API_KEY here.` 한 줄을 더한다 → FAIL `Found prompts that may solicit secret values:` + `recritic-code-profile.md:<줄>`. `git checkout HEAD -- plugins/quality-gates/references/recritic-code-profile.md`.
각각 `PYTHONDONTWRITEBYTECODE=1` 로 돌리고, 끝에 `git diff HEAD --stat` 빈 출력.

---

## Task 13: framing-requests degrade 채널 이름 락 (AC16)

**Files:**
- Modify: `plugins/spec-distill/tests/test_framing_review_contract.sh`(끝의 `finish` 앞)

**Interfaces:** 파일에 이미 있는 헬퍼를 쓴다 — `section <file> <시작 헤딩 정규식>`(코드 펜스를 인식하는 `## ` 절 추출), `assert_contains`, `ok`/`no`, 변수 `$SK`(framing-requests SKILL 경로). `# guards:` 머리에 SKILL 이 이미 있다.

- [ ] **Step 1: 절을 더한다**

마지막 `finish` 바로 앞에:

```bash
# ── degrade 채널 이름 (설계 2026-09-28-audit-folder-removal §4-6) ─────────────
# 「degrade 채널」 라벨의 존재는 test_proceed_gate_adopters.sh 가 잰다. 여기서는 그 절이 채널
# 다섯을 **이름으로** 대는지 잰다 — 이름이 사라지면 사람이 어디서 degrade 를 읽을지 모른다.
# 모양은 test_reviewing_spec_disclosure.sh (2). 절 추출이 비면 RED 다.
DGC="$(section "$SK" '^## degrade 채널$')"
[ -n "$DGC" ] && ok "절 추출: ## degrade 채널 (vacuous 아님)" \
              || no "절 추출: ## degrade 채널 이 비었다 — 채널 이름을 잴 수 없다"
for ch in 'advisory[]' 'blocks' 'gate --render' 'framing_degradations' '게이트 질문 텍스트'; do
  assert_contains "$DGC" "$ch" "degrade 채널 '$ch' 를 이름으로 댄다"
done
```

- [ ] **Step 2: GREEN 확인과 커밋**

Run: `bash plugins/spec-distill/tests/test_framing_review_contract.sh; echo "rc=$?"`
Expected: 새 ✓ 여섯 줄, 기준선에 없던 ✗ 없음.

```bash
git add plugins/spec-distill/tests/test_framing_review_contract.sh
git commit -m "test(spec-distill): framing-requests degrade 채널 다섯의 이름 락

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3: 변이 둘 (AC16)**

1. `sed -i '' 's/framing_degradations/framing_xxx/g' plugins/spec-distill/skills/framing-requests/SKILL.md` → `✗ degrade 채널 'framing_degradations' 를 이름으로 댄다`.
2. 되돌린 뒤 `## degrade 채널` 헤딩을 `## degrade 경로` 로 → `✗ 절 추출: ## degrade 채널 이 비었다` 와 이름 ✗ 다섯.
각각 `git checkout HEAD -- plugins/spec-distill/skills/framing-requests/SKILL.md` · `git diff HEAD --stat` 빈 출력.

---

## Task 14: 버전 bump 와 CHANGELOG (AC17)

**Files:**
- Modify: `plugins/plugin-audit/.claude-plugin/plugin.json` · `plugins/plugin-audit/CHANGELOG.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/project-init/.claude-plugin/plugin.json` · `plugins/project-init/CHANGELOG.md`

**Interfaces:** 없음. 버전 문자열을 핀한 테스트는 없다(계획 작성 때 `git grep` 으로 확인).

- [ ] **Step 1: 번호를 정한다**

```bash
git fetch origin main
for p in plugin-audit spec-distill quality-gates project-init; do
  printf '%s  branch=%s  main=%s\n' "$p" \
    "$(grep '"version"' "plugins/$p/.claude-plugin/plugin.json")" \
    "$(git show "origin/main:plugins/$p/.claude-plugin/plugin.json" | grep '"version"')"
done
```

규칙: plugin-audit 은 main 값의 minor +1(patch 0), 나머지 셋은 main 값의 patch +1. 2026-09-28 origin/main 기준이면 plugin-audit `0.10.0` · spec-distill `4.5.2` · quality-gates `9.3.5` · project-init `4.0.2` 다. main 이 그 사이 움직였으면 새 값으로 계산한다.

- [ ] **Step 2: plugin.json 넷과 CHANGELOG 넷을 쓴다**

각 `plugin.json` 의 `"version"` 값만 바꾼다. CHANGELOG 는 각 파일 맨 위 기존 첫 `## [` 항목 **앞**에 넣는다(날짜는 커밋 날짜). 본문:

plugin-audit:
```markdown
## [0.10.0] — 2026-09-28

minor 인 이유 — 산출 경로와 `render-audit-report.py` 의 CLI 가 바뀌었다.

### Added

- `scripts/prepare-run-dir.py` — 지출 동의 승인 직후 실행 디렉토리 `.claude/plugin-audit/<date>-<target>[-N]/` 을 원자적으로 만들고(`-N` 으로 기존 것을 덮지 않는다) 안에 `*` 한 줄짜리 `.gitignore` 를 쓴다. 둘째 줄로 sandbox id(실행 키의 SHA-256 앞 8 hex)를 낸다 — `qg-worktree.sh create-sandbox` 가 id 앞 8글자만 쓰므로 날짜 키를 그대로 넘기면 같은 달 감사가 한 sandbox 로 접힌다.

### Changed

- 모든 산출(`audit.md` · `audit-data.json` · `audit-journal.jsonl`)과 중간 파일이 실행 디렉토리에 쌓인다. 감사 끝에 절대경로를 보고한다. 리포트는 한 번 읽는 작업 산출물이다(README Law 3).
- phase 0 의 clean-tree 선결조건과 post-1 의 커밋 단계를 없앴다.

### Removed

- `render-audit-report.py --readme`(README 인덱스 쓰기). `validate-audit-data.py --artifacts` 의 README 링크 · CLAUDE.md 포인터 검사와 `--repo-root` 옵션. 배너 검사(AC-3)는 남는다.
```

spec-distill:
```markdown
## [4.5.2] — 2026-09-28

### Fixed

- `tests/test_no_write_matcher_hooks_repo.sh` 의 Bash matcher 양성 대조 임계를 1 로 — qg v7.0.0 이 자기 Bash 훅을 의도적으로 지운 뒤로 RED 였다.

### Changed

- `tests/test_framing_review_contract.sh` 가 framing-requests `## degrade 채널` 절의 채널 이름 다섯을 잰다.
- 삭제된 감사 문서를 가리키던 출처 괄호를 지웠다(`references/proceed-gate.md` 와 테스트 주석). `tests/test_brief_review_no_external_precondition.sh` (5)는 감사 폴더의 부재 락이 됐다.
```

quality-gates:
```markdown
## [9.3.5] — 2026-09-28

### Fixed

- `tests/test_cancel_all_fence.sh` 를 100755 로 — 셸 어댑터가 실행비트로 claim 하므로 `test_runner_adapters.sh` · `test_codex_backward_compat.sh` 가 RED 였다.

### Changed

- `tests/test_no_secret_prompts.py` 의 P21 스캔에 플러그인 레벨 `references/**/*.md` 를 더하고 glob 마다 하한을 따로 둔다.
```

project-init:
```markdown
## [4.0.2] — 2026-09-28

### Fixed

- trunk-based 템플릿 Pattern B 가 legacy release 브랜치를 현재 main 이 아니라 마지막 v1 태그에서 자른다.
- `/project-init` 4c S4 (i) 가 CLAUDE.md 의 비-관리 컨텐츠를 AGENTS.md 의 첫 관리 섹션 앞으로 이전한 뒤 포인터로 바꾼다 — 이전 없이 덮어 사용자 내용을 잃던 경로를 닫는다.
```

번호가 Step 1 과 다르면 헤딩의 번호를 그 값으로 쓴다.

- [ ] **Step 3: 커밋**

```bash
git add plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md \
        plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md \
        plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md \
        plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md
git commit -m "chore(release): plugin-audit 0.10.0 · spec-distill 4.5.2 · quality-gates 9.3.5 · project-init 4.0.2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(메시지의 번호는 Step 1 에서 정한 값으로.)

---

## Task 15: 최종 검증 · PR 본문 · memory (AC2 · AC3 · AC18)

**Files:**
- Modify: `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/*.md`(리포 밖) · `MEMORY.md`

**Interfaces:**
- Consumes: Task 0 의 `run-suite.sh` · `baseline/` · Task 7 의 `sweep-judged.md`.

- [ ] **Step 1: 최종 스위트**

Run(백그라운드 권장): `bash ~/.claude/sdd-mirror/resolve-audits/run-suite.sh final`
그리고:

```bash
O=~/.claude/sdd-mirror/resolve-audits
grep -hoE '^test_[A-Za-z0-9_]+ \([^)]*\)' "$O"/final/logs/*.py.log | sort -u > "$O/final/pytests.txt"
echo "== 새 실패 (AC2: 0줄이어야 한다)";   comm -13 "$O/baseline/failures.txt" "$O/final/failures.txt"
echo "== 사라진 실패 (AC3 의 셋이 있어야 한다)"; comm -23 "$O/baseline/failures.txt" "$O/final/failures.txt"
echo "== 사라진 python 테스트 (C4 의 3개만)";  comm -23 "$O/baseline/pytests.txt" "$O/final/pytests.txt"
echo "== 파일 목록 변화";                    diff <(cut -f1 "$O/baseline/summary.tsv") <(cut -f1 "$O/final/summary.tsv")
git status --porcelain
```

Expected:
- 새 실패 0줄. 줄이 있으면 그 줄의 파일 로그를 읽고 원인을 적는다 — 이 PR 이 만든 것이면 고친다(새 커밋). 무관한 flake 로 보이면 그 파일만 두 번 더 돌려 재현 여부를 적는다.
- 사라진 실패에 `test_runner_adapters.sh` · `test_codex_backward_compat.sh` · `test_no_write_matcher_hooks_repo.sh` 의 줄(과 rc 줄)이 있다.
- 사라진 python 테스트는 `test_artifacts_readme_missing_link_is_red` · `test_artifacts_missing_readme_is_red` · `test_artifacts_claude_md_missing_pointer_is_red` · `test_artifacts_valid_is_green`(이름 변경) 넷뿐이다 — 앞 셋이 의도적 삭제, 넷째는 `test_artifacts_valid_is_green_without_readme_or_claude_md` 로 이름이 바뀌었다.
- 파일 목록 변화는 `> plugins/plugin-audit/tests/test_prepare_run_dir.py` · `> plugins/plugin-audit/tests/test_run_dir_pipeline.py` 둘.
- `git status --porcelain` 빈 출력.

- [ ] **Step 2: 변이 전수 확인표**

Task 1·3·4·5·7·11·12·13 의 변이를 모두 돌렸는지 표로 적는다(`<AC> · <변이> · <RED 로 나온 줄>`). 빠진 것은 지금 돌린다. 이 표를 PR 본문에 싣는다.

- [ ] **Step 3: PR 본문 초안**

`~/.claude/sdd-mirror/resolve-audits/pr-body.md` 에 쓴다: 요약(두 폴더 제거 · plugin-audit 실행 디렉토리 · 결함 여섯) · 커밋 덩어리 셋 · 기준선 대비 결과(Step 1 의 넷) · 변이 표 · §3-7 1회 점검 결과(`sweep-judged.md` 전문) · 알려진 한계 L1~L6(설계 문서 그대로 인용) · 끝에 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. push 와 PR 생성은 사용자에게 묻고 한다. 머지는 사용자가 `! gh pr merge <n> --merge` 로 한다.

- [ ] **Step 4: auto-memory 포인터 갱신 (AC18)**

```bash
grep -rnE 'docs/(archive/)?audits' ~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/
```

계획 작성 때 13파일 22줄이었다. 줄마다: 그 포인터가 **사실의 출처**면 `git show 6f41a6e1:<경로>` 형태로 바꾼다(삭제된 파일은 그 커밋에 남아 있다), 「여기서 찾아라」 식 **장소 안내**면 그 안내를 지우거나 「git 이력(`git log -S`)」으로 바꾼다. `MEMORY.md` 의 줄(「재측정 전에 리포 축적물을 훑어라」 — `docs/audits/` 언급)도 같은 규칙으로 고친다. 끝나고 같은 grep 이 `6f41a6e1:` 형태 말고는 0줄이어야 한다. `project_resolve_audits.md` 를 「구현 완료 · PR 대기」로 갱신한다.

- [ ] **Step 5: 머지 직전 (사용자 트리거 뒤)**

origin/main 이 또 움직였으면 merge 하고(`git merge --no-edit origin/main`), Task 14 Step 1 로 번호를 다시 계산해 다르면 plugin.json · CHANGELOG 헤딩을 고쳐 새 커밋을 더한다. 그 뒤 Step 1 의 스위트를 한 번 더 돌린다.
