#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_check.py — 머지 전 스위트 대조(R5 AC18).

합친 사본(origin 기본 브랜치 + 에픽 브랜치)과 기준선 사본(origin 기본 브랜치)을 일회용 worktree 로 만들고,
그 레포의 스위트를 두 사본에서 돌려 실패를 단위와 «이름» 으로 대조한다. 동시 실행은 하위 agent 의 전체 스위트와
같은 공유 스위트 잠금(`suite_lock.py` — 기계 상태 자원 폴더의 `suite-lock`)으로 막는다.

명령줄:
  merge_check.py run --roadmap <로드맵 레포 상대경로> --branch <브랜치|origin/브랜치> [--keep-merged] [--no-fetch] [--wait <초>] [--root <레포>]

무엇을 돌리나: 기본 브랜치의 로드맵 frontmatter `test_command` 가 있으면 그것 — 실패 이름은 `test_failure_pattern`
(정규식, 묶음이 있으면 첫 묶음) 또는 알려진 모양. frontmatter 에 없는 키는 이 로드맵 기계 상태의 `## 레포 설정`
(지휘자가 물어 임시로 둔 값)에서 읽는다 — frontmatter 가 이기고, 기계 상태가 깨졌으면 검사 불가다. 둘 다 없으면 이
폴더의 공유본 링크로 러너 탐지 · 배정 · 단위 실행 · 귀속을 하고, 양쪽 다 빨간 단위는 그 단위의 러너 출력에서 그
러너의 실패 모양으로만 이름을 뽑아 대조한다(모양을 모르는 러너는 단위 수준만).

종료 코드: 0 새 실패 없음 · 1 새 실패 있음 · 3 검사 불가 · 4 새 실패는 없으나 이름 대조 불가 단위가 있다 ·
5 다른 스위트가 도는 중(공유 잠금) · 6 테스트 명령을 모른다(사용자에게 묻는다) · 7 스위트 대조 없음(테스트 없음).
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import branch_tip as branch_tip_mod  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
import suite_lock  # noqa: E402
from roadmap_model import DEFAULT_REF, NO_DEFAULT, frontmatter, unquote  # noqa: E402
from state_path import state_root  # noqa: E402

SELECT = HERE / "run-test-selection.sh"
DIFF = HERE / "diff-test-results.py"
SCOPE = HERE / "compute-test-scope-candidates.sh"
KNOWN_SHAPES = (
    ("pytest", re.compile(r"^(?:FAILED|ERROR) (?!\()(\S+)", re.M)),
    ("unittest", re.compile(r"^(?:FAIL|ERROR): (.+)$", re.M)),
    ("tap", re.compile(r"^\s*not ok \d+ - (.+)$", re.M)),
    ("✗ 표시", re.compile(r"^\s*✗ (.+)$", re.M)),
)
# 탐지 경로의 러너별 실패 모양 — 다른 러너의 모양(예: 셸 출력의 `ERROR:` 진단 줄)이 이름 집합을 가로채지 않게 한다.
# 여기 없는 러너는 이름을 뽑지 않는다(「이름 대조 불가 — 단위 수준만」).
RUNNER_SHAPES = {
    "pytest": (KNOWN_SHAPES[0],),
    "unittest": (KNOWN_SHAPES[1],),
    "shell": (("✗ · FAIL: 표시", re.compile(r"^\s*(?:✗|FAIL:) (.+)$", re.M)), KNOWN_SHAPES[2]),
}
MACHINE_NOTE = "(기계 상태 임시값)"
NEW, FIXED = ("NEW_REGRESSION", "NEW_TEST_RED"), ("FIXED",)


class Stop(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


def git(cwd, *args):
    p = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def stamp() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def names_in(text: str, pattern=None, shapes=None):
    """(실패 이름 집합, 쓴 모양). 모양이 하나도 안 맞으면 (빈 집합, None) — 「이름 대조 불가」 의 근거다.

    pattern 이 있으면 그것만, shapes(러너별 모양)를 주면 그 모양들이 뽑은 이름의 합집합, 둘 다 없으면 알려진 모양
    가운데 처음 맞는 것."""
    if not pattern and shapes is not None:
        found, labels = set(), []
        for label, rx in shapes:
            got = set((m.group(1) if rx.groups else m.group(0)).strip() for m in rx.finditer(text))
            if got:
                found |= got
                labels.append(label)
        return found, (" · ".join(labels) if labels else None)
    shapes = [("test_failure_pattern", re.compile(pattern, re.M))] if pattern else list(KNOWN_SHAPES)
    for label, rx in shapes:
        found = set()
        for m in rx.finditer(text):
            found.add((m.group(1) if rx.groups else m.group(0)).strip())
        if found:
            return found, label
    return set(), None


# ── 잠금 ─────────────────────────────────────────────────────────────────────
# 하위 agent 의 전체 스위트와 같은 잠금 하나(`suite_lock.py`) — 지휘자 대조와 담당자 스위트가 같은 시각에 돌지 않는다.

def take_lock(d: Path, branch: str, wait: float = 0) -> None:
    try:
        suite_lock.take(d, "merge_check %s" % branch, wait)
    except suite_lock.Busy as exc:
        raise Stop(5, "다른 스위트가 도는 중이다(%s) — 끝난 뒤 다시 돈다(잠금 %s)" % (exc, d))


def drop_lock(d: Path) -> None:
    suite_lock.drop(d)


# ── 사본 ─────────────────────────────────────────────────────────────────────

def branch_tip(root: Path, branch: str) -> str:
    try:
        tip, note = branch_tip_mod.tip(root, branch)
    except branch_tip_mod.TipError as exc:
        raise Stop(3, str(exc))
    if tip is None:
        raise Stop(3, "브랜치를 찾지 못했다: %s" % branch)
    if note:
        print(note)
    return tip


def make_copies(root: Path, work: Path, branch: str):
    rc, base_sha, _e = git(root, "rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if rc:
        raise Stop(3, NO_DEFAULT)
    tip = branch_tip(root, branch)
    base, merged = work / "base", work / "merged"
    for d in (base, merged):
        rc, _o, err = git(root, "worktree", "add", "--detach", str(d), base_sha)
        if rc:
            raise Stop(3, "사본을 만들지 못했다(%s): %s" % (d, err))
    rc, _o, err = git(merged, "-c", "user.name=merge-check", "-c", "user.email=merge-check@invalid",
                      "-c", "commit.gpgsign=false", "merge", "--no-ff", "--no-edit", tip)
    if rc:
        _r, files, _e = git(merged, "diff", "--name-only", "--diff-filter=U")
        git(merged, "merge", "--abort")
        raise Stop(3, "합칠 수 없다 — 충돌 파일: %s" % (" · ".join(files.split()) or err))
    _r, merged_sha, _e = git(merged, "rev-parse", "HEAD")
    return base, merged, base_sha, tip, merged_sha


def drop_copy(root: Path, d: Path, work: Path) -> None:
    """일회용 사본만 지운다 — work 밖 경로는 건드리지 않는다. 테스트가 남긴 파일 때문에 rmtree 뒤 prune."""
    if work not in d.parents:
        return
    rc, _o, _e = git(root, "worktree", "remove", "--force", str(d))
    if rc and d.exists():
        shutil.rmtree(str(d), ignore_errors=True)
        print("[spec-distill] 일회용 사본을 git 으로 지우지 못해 폴더만 지웠다 — 남은 기록은 사용자가 정리한다(%s)" % d)


# ── 테스트 명령 ──────────────────────────────────────────────────────────────

def run_command(cmd: str, tree: Path, tmp: Path):
    tmp.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(["bash", "-c", cmd], cwd=str(tree), env=dict(os.environ, TMPDIR=str(tmp)),
                       capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + "\n" + p.stderr


def compare_command(cmd: str, pattern, base: Path, merged: Path, work: Path, sources=None) -> dict:
    sources = sources or {}
    res = {"new": [], "fixed": [], "both": [], "unit_only": [],
           "notes": ["무엇을 돌렸나: test_command(`%s`)%s" % (cmd, sources.get("test_command", ""))]}
    if pattern and sources.get("test_failure_pattern"):
        res["notes"].append("실패 이름 정규식: test_failure_pattern%s" % sources["test_failure_pattern"])
    b_rc, b_out = run_command(cmd, base, work / "tmp-base")
    m_rc, m_out = run_command(cmd, merged, work / "tmp-merged")
    if 127 in (b_rc, m_rc):
        raise Stop(3, "테스트 명령을 실행하지 못했다(rc 127): %s" % cmd)
    b_names, _s = names_in(b_out, pattern)
    m_names, shape = names_in(m_out, pattern)
    named = (b_rc == 0 or b_names) and (m_rc == 0 or m_names)
    if named:
        res["new"] = sorted(m_names - b_names)
        res["fixed"] = sorted(b_names - m_names)
        res["both"] = sorted(b_names & m_names)
        if shape:
            res["notes"].append("실패 이름 모양: %s" % shape)
        if m_rc != 0 and not res["new"] and not m_names - b_names and b_rc == 0:
            res["new"].append("(test_command) 전체 — 종료 코드만 실패")
    elif m_rc != 0 and b_rc == 0:
        res["new"].append("(test_command) 전체 — 이름 대조 불가 — 단위 수준만")
    elif m_rc != 0:
        res["unit_only"].append("(test_command) — 양쪽 다 실패, 이름을 뽑지 못했다")
    elif b_rc != 0:
        res["fixed"].append("(test_command) 전체")
    return res


# ── 탐지 경로(공유본) ────────────────────────────────────────────────────────

def select(*args, stdin=None, tmp=None):
    env = dict(os.environ, TMPDIR=str(tmp)) if tmp else None
    p = subprocess.run(["bash", str(SELECT), *args], input=stdin, capture_output=True, encoding="utf-8",
                       errors="replace", env=env)
    return p.returncode, p.stdout, p.stderr


def test_file_count(tree: Path):
    p = subprocess.run(["bash", str(SCOPE), "--total", "--tree", "HEAD"], cwd=str(tree), capture_output=True,
                       encoding="utf-8", errors="replace")
    out = p.stdout.strip()
    return int(out) if p.returncode == 0 and out.isdigit() else None


def _assign_rows(path: Path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            cells = line.split("\t")
            if len(cells) == 3:
                rows.append(tuple(cells))
    return rows


def assignment(tree: Path, work: Path):
    _rc, files, _e = git(tree, "ls-files")
    first = work / "all.assign"
    rc, _o, err = select("assign", str(tree), str(first), stdin=files + "\n")
    if rc:
        raise Stop(3, "배정이 실패했다: %s" % err.strip()[-300:])
    claimed = [u for u, r, _g in _assign_rows(first) if r != "unclaimed"]
    final = work / "units.assign"
    rc, _o, err = select("assign", str(tree), str(final), stdin="\n".join(claimed) + "\n")
    if rc:
        raise Stop(3, "배정이 실패했다: %s" % err.strip()[-300:])
    return final, [r for r in _assign_rows(final) if r[1] != "unclaimed"]


def run_side(tree: Path, side: str, rows: list, work: Path) -> dict:
    """{(러너, 단위): 그 실행의 표준 오류}. 행 파일은 공유본이 쓴다."""
    logs, rows_dir = {}, work / "rows"
    rows_dir.mkdir(exist_ok=True)
    for runner in sorted({r for _u, r, _g in rows}):
        units = [u for u, r, _g in rows if r == runner]
        gran = next(g for _u, r, g in rows if r == runner)
        target = rows_dir / (("baseline-%s.tsv" % runner) if side == "base" else ("head-%s-i1.tsv" % runner))
        groups, mode = ([["BULK"]], "bulk") if gran == "bulk" else ([[u] for u in units], "per-unit")
        for grp in groups:
            rc, _o, err = select("run", str(tree), runner, mode, str(target), *grp, tmp=work / ("tmp-" + side))
            if rc == 2:
                raise Stop(3, "단위 실행이 실패했다(%s %s): %s" % (runner, grp[0], err.strip()[-300:]))
            logs[(runner, grp[0])] = err
    return logs


def parse_attributions(text: str) -> list:
    out, runner, unit = [], None, None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- runner: "):
            runner = s[len("- runner: "):]
        elif s.startswith("- unit: "):
            unit = json.loads(s[len("- unit: "):])
        elif s.startswith("verdict: ") and unit is not None:
            out.append((runner, unit, s[len("verdict: "):]))
            unit = None
    return out


def compare_detected(base: Path, merged: Path, base_sha: str, merged_sha: str, work: Path) -> dict:
    rc, out, err = select("detect", str(merged))
    if rc:
        raise Stop(3, "러너 탐지가 실패했다: %s" % err.strip()[-300:])
    runners = [l.split(": ", 1)[1] for l in out.splitlines() if l.startswith("runner: ")]
    count = test_file_count(merged)
    final, rows = assignment(merged, work) if runners else (None, [])
    if not rows:
        if count is None:
            raise Stop(3, "테스트 파일 수를 세지 못했다 — compute-test-scope-candidates 가 숫자를 내지 않았다")
        if count:
            raise Stop(6, "테스트로 보이는 파일 %d개를 돌릴 러너를 모른다 — 테스트 명령을 정해 주면 로드맵 "
                          "frontmatter `test_command` 로 올린다" % count)
        raise Stop(7, "스위트 대조 없음 — 이 레포에서 테스트를 찾지 못했다. 통합 리뷰만 한다")
    res = {"new": [], "fixed": [], "both": [], "unit_only": [],
           "notes": ["무엇을 돌렸나: 탐지한 러너 %s" % " · ".join(sorted({r for _u, r, _g in rows}))]}
    files = [u for u, _r, g in rows if g == "file"]
    if count is not None and len(files) < count and not any(g == "bulk" for _u, _r, g in rows):
        res["notes"].append("테스트로 보이는 파일 %d개 중 %d개만 러너가 맡았다 — 나머지까지 돌리려면 "
                            "`test_command` 를 정한다(지휘자가 한 번 묻는다)" % (count, len(files)))
    b_logs = run_side(base, "base", rows, work)
    m_logs = run_side(merged, "merged", rows, work)
    p = subprocess.run([sys.executable, str(DIFF), "--assign", str(final), "--rows", str(work / "rows"),
                        "--iter", "1", "--baseline-commit", base_sha, "--head-commit", merged_sha],
                       cwd=str(merged), capture_output=True, encoding="utf-8", errors="replace")
    if p.returncode:
        raise Stop(3, "귀속이 실패했다: %s" % p.stderr.strip()[-300:])
    for line in p.stdout.splitlines():
        if line.startswith("degrade_causes: ") and line != "degrade_causes: []":
            res["notes"].append("귀속 강등: %s" % line[len("degrade_causes: "):])
    for runner, unit, verdict in parse_attributions(p.stdout):
        shapes = RUNNER_SHAPES.get(runner, ())
        b_names, _s = names_in(b_logs.get((runner, unit), ""), shapes=shapes)
        m_names, _s = names_in(m_logs.get((runner, unit), ""), shapes=shapes)
        if verdict in NEW:
            fresh = sorted(m_names - b_names)
            res["new"] += ["%s: %s" % (unit, n) for n in fresh] or ["%s — 이름 대조 불가 — 단위 수준만" % unit]
        elif verdict in FIXED:
            res["fixed"].append(unit)
        elif verdict == "PRE_EXISTING":
            if b_names and m_names:
                res["new"] += ["%s: %s" % (unit, n) for n in sorted(m_names - b_names)]
                res["fixed"] += ["%s: %s" % (unit, n) for n in sorted(b_names - m_names)]
                res["both"] += ["%s: %s" % (unit, n) for n in sorted(b_names & m_names)]
            else:
                res["unit_only"].append("%s — 양쪽 다 빨강, 이름을 뽑지 못했다" % unit)
        elif verdict in ("SILENT_DROP", "BASELINE_UNRUNNABLE"):
            res["unit_only"].append("%s — %s" % (unit, verdict))
    return res


# ── 보고 ─────────────────────────────────────────────────────────────────────

def report(res: dict) -> int:
    for note in res["notes"]:
        print("- " + note)
    for label, key in (("이 브랜치에만 있는 실패", "new"), ("기본 브랜치에만 있는 실패(고쳐짐)", "fixed"),
                       ("양쪽 다 있는 실패", "both")):
        print("- %s %d개%s" % (label, len(res[key]), (": " + " · ".join(res[key])) if res[key] else ""))
    if res["unit_only"]:
        print("- 이름 대조 불가 — 단위 수준만 %d개: %s" % (len(res["unit_only"]), " · ".join(res["unit_only"])))
    if res["new"]:
        print("판정: 새 실패 %d개 — 고치거나 이유를 적는다" % len(res["new"]))
        return 1
    if res["unit_only"]:
        print("판정: 새 실패는 찾지 못했으나 이름으로 가르지 못한 단위가 있다 — 위 줄을 사용자에게 보인다")
        return 4
    print("판정: 새 실패 없음")
    return 0


def machine_settings(mroot: Path, roadmap: str) -> dict:
    """이 로드맵 기계 상태의 `## 레포 설정` (키 → 값, 같은 키는 마지막 줄). 깨졌으면 검사 불가 — 조용히 넘기지 않는다."""
    try:
        data = cs.load(mroot / cs.MACHINE_FILE, roadmap)
    except cs.MachineError as exc:
        raise Stop(3, "기계 상태의 레포 설정을 읽지 못했다 — %s" % exc)
    out = {}
    for row in data.get("레포 설정", []):
        value = unquote(row["값"].strip())
        if value:
            out[row["키"]] = value
    return out


def run(root: Path, a) -> int:
    if not a.no_fetch:
        rc, _o, err = git(root, "fetch", "--quiet", "origin")
        if rc:
            print("[spec-distill] git fetch 가 실패했다 — 받아 둔 기본 브랜치로 대조한다(%s)" % err[-200:])
    try:
        _sha, ref_name, why = repo_defaults.default_branch(str(root))
        if why:
            raise Stop(3, why)
        if a.no_fetch:   # 네트워크 진입이 아니다 — 대조를 건너뛰되 알린다
            state, line = "unchecked", repo_defaults.unchecked_line(ref_name)
        else:
            state, line = repo_defaults.check_remote_head(str(root), ref_name)
    except repo_defaults.SettingsError as exc:
        raise Stop(3, str(exc))
    if state == "differs":
        raise Stop(3, line)
    if state == "unchecked":
        print("[spec-distill] " + line)
    rc, text, _e = git(root, "show", "%s:%s" % (DEFAULT_REF, a.roadmap))
    if rc:
        raise Stop(3, "기본 브랜치에서 로드맵을 읽지 못했다: %s" % a.roadmap)
    meta = frontmatter(text)
    settings = repo_defaults.repo_settings(meta)
    if settings["errors"]:
        raise Stop(3, "레포 설정이 깨졌다: %s" % settings["errors"][0])
    pattern = unquote(meta["test_failure_pattern"]) if "test_failure_pattern" in meta else None
    test_command = settings["test_command"]
    try:
        mroot = cs.machine_dir(state_root(str(root)), a.roadmap)
    except cs.MachineError as exc:
        raise Stop(3, str(exc))
    sources = {}
    if "test_command" not in meta or "test_failure_pattern" not in meta:
        temp = machine_settings(mroot, a.roadmap)
        if "test_command" not in meta and temp.get("test_command"):
            test_command = temp["test_command"]
            sources["test_command"] = MACHINE_NOTE
        if "test_failure_pattern" not in meta and temp.get("test_failure_pattern"):
            pattern = temp["test_failure_pattern"]
            sources["test_failure_pattern"] = MACHINE_NOTE
    if pattern:
        try:
            re.compile(pattern)
        except re.error as exc:
            raise Stop(3, "test_failure_pattern 정규식이 깨졌다%s: %s" % (sources.get("test_failure_pattern", ""), exc))
    mdir = mroot / repo_defaults.MERGE_CHECK_DIR
    lock = suite_lock.lock_path(mroot)
    take_lock(lock, a.branch, a.wait)
    work = mdir / ("run-%s-%d" % (datetime.datetime.now().strftime("%Y%m%d%H%M%S"), os.getpid()))
    keep = None
    try:
        work.mkdir(parents=True)
        base, merged, base_sha, tip, merged_sha = make_copies(root, work, a.branch)
        print("[spec-distill] 스위트 대조 — %s(%s) 를 기본 브랜치 %s(%s) 에 합친 사본(%s)과 기본 브랜치 사본을 돌렸다"
              % (a.branch, tip[:8], ref_name, base_sha[:8], merged_sha[:8]))
        if test_command:
            res = compare_command(test_command, pattern, base, merged, work, sources)
        else:
            res = compare_detected(base, merged, base_sha, merged_sha, work)
        if a.keep_merged:
            keep = merged
        rc = report(res)
        if keep is not None:
            print("남긴 사본: %s" % keep)
        return rc
    finally:
        for d in (work / "base", work / "merged"):
            if d != keep:
                drop_copy(root, d, work)
        if keep is None:
            shutil.rmtree(str(work), ignore_errors=True)
        drop_lock(lock)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="merge_check.py", description="머지 전 스위트 대조")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--roadmap", required=True)
    r.add_argument("--branch", required=True)
    r.add_argument("--keep-merged", action="store_true")
    r.add_argument("--no-fetch", action="store_true")
    r.add_argument("--wait", type=float, default=0, help="잠금이 잡혀 있으면 이 초까지 기다린다(줄)")
    r.add_argument("--root")
    a = ap.parse_args(argv)
    try:
        top = a.root or git(os.getcwd(), "rev-parse", "--show-toplevel")[1]
        if not top:
            print("[spec-distill] 스위트 대조 — git 레포 안이 아니다")
            return 3
        return run(Path(top), a)
    except Stop as stop:
        print("[spec-distill] 스위트 대조 — %s" % stop)
        return stop.rc
    except Exception as exc:  # 기본 종료 코드 1 은 「새 실패 있음」 이라 섞이면 안 된다
        print("[spec-distill] 스위트 대조 — 내부 오류: %s: %s" % (type(exc).__name__, exc))
        return 3


if __name__ == "__main__":
    sys.exit(main())
