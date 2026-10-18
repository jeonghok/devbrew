#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_ledger.py — 지휘자의 쓰기 · 자원 · 기록 절 · 감사 후보(R5 설계 §2 · §5).

기계 상태(`conductor_state.py` 형식) 쓰기는 세션 표지를 쥔 세션만 한다. 이어 가기에 필요한 기록은 에픽 설계문서의
절(`## 판정` · `## 구현 대조 — <계획>` · `## 지휘 기록`)에 쓰고, 커밋은 지휘자가 한다(이 스크립트는 커밋하지 않는다).

명령줄(모두 `--root <레포>` 선택):
  roadmaps                                             끝나지 않은 로드맵 찾기(frontmatter `type: roadmap`)
  claim | takeover | release --roadmap R --session S    세션 표지
  add  --roadmap R --session S --section 절 --cells "칸 · 칸 …"
  drop --roadmap R --session S --section 절 --where 칸=값
  approval | approve --roadmap R --session S --scale "규모"   시작 승인 공시 판단 · 기록
  (Task 5~7 이 자원 · 기록 절 · 감사 명령을 더한다)

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
from roadmap_model import DEFAULT_REF, NO_DEFAULT, frontmatter, unquote  # noqa: E402
from state_path import state_root  # noqa: E402

DONE = ("머지됨", "끝남")


class Fail(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


def git(cwd, *args):
    p = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout.rstrip("\n"), p.stderr.strip()


def top(cwd=None) -> Path:
    rc, out, _e = git(cwd or os.getcwd(), "rev-parse", "--show-toplevel")
    if rc or not out:
        raise Fail(3, "git 레포 안이 아니다")
    return Path(out)


def now() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")


def mpath(root, roadmap: str) -> Path:
    try:
        return cs.machine_path(state_root(str(root)), roadmap)
    except cs.MachineError as exc:
        raise Fail(3, str(exc))


def load(root, roadmap: str) -> dict:
    try:
        return cs.load(mpath(root, roadmap), roadmap)
    except cs.MachineError as exc:
        raise Fail(3, "기계 상태를 읽지 못했다 — 덮어쓰지 않는다: %s" % exc)


def update(root, roadmap: str, session: str, change) -> dict:
    """표지를 쥔 세션만 쓴다. 깨진 기계 상태는 읽기에서 멈춘다(빈 상태로 덮어쓰지 않는다)."""
    path = mpath(root, roadmap)
    owner = cs.holder(path.parent)
    if owner != session:
        raise Fail(5, "읽기 전용 — 표지를 쥔 세션: %s" % (owner or "없음(먼저 claim)"))
    data = load(root, roadmap)
    change(data)
    try:
        cs.save(path, roadmap, data, session)
    except cs.MachineError as exc:
        raise Fail(3, "기계 상태를 쓰지 못했다: %s" % exc)
    return data


def split_cells(section: str, text: str) -> dict:
    cols = cs.COLUMNS.get(section)
    if cols is None:
        raise Fail(2, "모르는 절: %r — 절은 %s" % (section, " · ".join(cs.COLUMNS)))
    cells = [c.strip() for c in text.split(cs.SEP, len(cols) - 1)]
    if len(cells) != len(cols) or not all(cells):
        raise Fail(2, "%s 절은 칸 %d개(%s)다 — 받은 것: %r" % (section, len(cols), " · ".join(cols), text))
    return dict(zip(cols, cells))


def scale_check(rows: list, session: str, scale: str):
    """(공시만이면 True, 이유). 같은 세션의 승인이 있고 규모 줄이 글자 그대로 같을 때만 공시만이다(결정 B)."""
    mine = [r for r in rows if r["세션"] == session]
    if not mine:
        return False, "이 세션의 승인이 없다"
    last = mine[-1]
    if last["규모"] != scale:
        return False, "규모가 바뀌었다 — 전: %s → 지금: %s" % (last["규모"], scale)
    return True, "이 세션에서 %s 에 승인받은 규모 그대로다" % last["때"]


def worktrees(root) -> list:
    rc, out, err = git(root, "worktree", "list", "--porcelain")
    if rc:
        raise Fail(3, "worktree 목록을 읽지 못했다: %s" % err)
    items, cur = [], None
    for line in out.splitlines() + [""]:
        if line.startswith("worktree "):
            cur = {"path": str(Path(line[len("worktree "):]).resolve()), "branch": "detached", "head": ""}
        elif cur is not None and line.startswith("branch "):
            cur["branch"] = line[len("branch "):].split("refs/heads/", 1)[-1]
        elif cur is not None and line.startswith("HEAD "):
            cur["head"] = line[len("HEAD "):]
        elif not line and cur is not None:
            items.append(cur)
            cur = None
    return items


def dirty_lines(path: Path) -> list:
    """지우기 전에 보일 것 — 수정 · 추적 안 된 파일과 git 밖 실행 기록 폴더(SDD 원장 등)."""
    rc, out, _e = git(path, "status", "--porcelain", "--untracked-files=all")
    if rc:
        raise Fail(2, "worktree 가 아니다: %s" % path)
    lines = ["바뀐 파일: %s" % l[3:] for l in out.splitlines() if l.strip()]
    work = path / repo_defaults.SDD_WORKSPACE
    if work.is_dir() and any(work.iterdir()):
        lines.append("실행 방식 작업 폴더(git 밖 기록 — 남길 것은 설계문서 절로 옮긴다): %s" % work)
    return lines


def _is_merge_copy(root, roadmap: str, path: Path) -> bool:
    base = (mpath(root, roadmap).parent / repo_defaults.MERGE_CHECK_DIR).resolve()
    return base in path.resolve().parents


# ── 하위 명령 ────────────────────────────────────────────────────────────────

def c_roadmaps(root, a) -> int:
    rc, _o, _e = git(root, "rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if rc:
        raise Fail(3, NO_DEFAULT)
    rc, out, err = git(root, "grep", "-l", "-I", "--full-name", "-E", "-e", "^type:[[:space:]]*[\"']?roadmap", DEFAULT_REF, "--", "*.md")
    if rc not in (0, 1):
        raise Fail(3, "기본 브랜치의 파일을 읽지 못했다: %s" % err)
    found = 0
    for line in out.splitlines():
        path = line.split(":", 1)[1] if ":" in line else line
        _r, text, _e = git(root, "show", "%s:%s" % (DEFAULT_REF, path))
        if unquote(frontmatter(text).get("type", "")) != "roadmap":
            continue
        p = subprocess.run([sys.executable, str(HERE / "roadmap_status.py"), "--json", path], cwd=str(root),
                           capture_output=True, encoding="utf-8", errors="replace")
        try:
            rep_ = json.loads(p.stdout)
            blocks = rep_.get("blocks") or []
            staged = any(b.get("stage") for b in blocks)
            if rep_.get("exit") == 3 or (not staged and (rep_.get("unknown_reasons") or rep_.get("format_errors"))):
                left = "검사 불가"
            else:
                left = str(sum(1 for b in blocks if b.get("stage") not in DONE))
        except ValueError:
            left = "검사 불가"
        if left != "0":
            print("%s\t%s" % (path, left))
            found += 1
    if not found:
        print("끝나지 않은 로드맵이 없다")
        return 2
    return 0


def _drop_approval(root, a):
    """표지를 새로 쥐면 옛 시작 승인은 효력이 없다(AC15) — 이 세션의 행을 지운다."""
    update(root, a.roadmap, a.session,
           lambda d: d.__setitem__("시작 승인", [r for r in d["시작 승인"] if r["세션"] != a.session]))


def c_claim(root, a) -> int:
    got = cs.acquire(mpath(root, a.roadmap).parent, a.session)
    if got in ("acquired", "held"):
        if got == "acquired":
            _drop_approval(root, a)
        print(got)
        return 0
    print("다른 세션(%s)이 이 로드맵을 지휘하고 있다 — 이 세션은 읽기 전용으로 보인다. 넘겨받을지는 사용자가 정한다(takeover)" % got)
    return 5


def c_takeover(root, a) -> int:
    prev = cs.takeover(mpath(root, a.roadmap).parent, a.session)
    _drop_approval(root, a)
    print("표지를 넘겨받았다 — 이전 주인: %s" % (prev or "없음"))
    return 0


def c_release(root, a) -> int:
    if cs.holder(mpath(root, a.roadmap).parent) == a.session:
        _drop_approval(root, a)
    print("표지를 풀었다" if cs.release(mpath(root, a.roadmap).parent, a.session) else "이 세션의 표지가 아니다 — 그대로 둔다")
    return 0


def c_add(root, a) -> int:
    row = split_cells(a.section, a.cells)
    update(root, a.roadmap, a.session, lambda d: d[a.section].append(row))
    print("적었다 — %s: %s" % (a.section, a.cells))
    return 0


def c_drop(root, a) -> int:
    key, eq, value = a.where.partition("=")
    if not eq:
        raise Fail(2, "--where 는 <칸>=<값> 모양이다: %r" % a.where)
    if key not in cs.COLUMNS.get(a.section, ()):
        raise Fail(2, "%s 절에 %r 칸이 없다" % (a.section, key))
    gone = []

    def change(d):
        keep = [r for r in d[a.section] if r[key] != value]
        gone.extend(r for r in d[a.section] if r[key] == value)
        d[a.section] = keep
    update(root, a.roadmap, a.session, change)
    print("지웠다 %d줄 — %s: %s=%s" % (len(gone), a.section, key, value))
    return 0 if gone else 1


def c_approval(root, a) -> int:
    owner = cs.holder(mpath(root, a.roadmap).parent)
    if owner != a.session:
        print("승인 필요 — 이 세션이 표지를 쥐고 있지 않다(표지를 쥔 세션: %s)" % (owner or "없음"))
        return 1
    ok, why = scale_check(load(root, a.roadmap)["시작 승인"], a.session, a.scale)
    print(("공시만 — " if ok else "승인 필요 — ") + why)
    return 0 if ok else 1


def c_approve(root, a) -> int:
    def change(d):
        d["시작 승인"] = [r for r in d["시작 승인"] if r["세션"] != a.session]
        d["시작 승인"].append({"세션": a.session, "때": now(), "규모": a.scale})
    update(root, a.roadmap, a.session, change)
    print("시작 승인을 적었다 — %s" % a.scale)
    return 0


def c_resources(root, a) -> int:
    rows = load(root, a.roadmap)["자원"]
    for r in rows:
        print(" · ".join(r[c] for c in cs.COLUMNS["자원"]))
    if not rows:
        print("없음")
    return 0


def c_cleanup_check(root, a) -> int:
    path = Path(a.path)
    if not path.is_dir():
        print("worktree 가 아니다: %s" % path)
        return 2
    lines = dirty_lines(path)
    for l in lines:
        print(l)
    if not lines:
        print("깨끗하다 — 지워도 된다: %s" % path)
    return 1 if lines else 0


def c_cleanup(root, a) -> int:
    path = Path(a.path)
    if _is_merge_copy(root, a.roadmap, path):
        shutil.rmtree(str(path), ignore_errors=True)
        git(root, "worktree", "prune")
    else:
        lines = dirty_lines(path) if path.is_dir() else []
        if lines:
            for l in lines:
                print(l)
            print("지우지 않았다 — 위 내용을 사용자에게 보이고 묻는다(--force 를 쓰지 않는다)")
            return 1
        if path.is_dir():
            rc, _o, err = git(root, "worktree", "remove", str(path))
            if rc:
                raise Fail(3, "worktree 를 지우지 못했다: %s" % err)
    update(root, a.roadmap, a.session,
           lambda d: d.__setitem__("자원", [r for r in d["자원"] if Path(r["경로"]).resolve() != path.resolve()]))
    print("정리했다 — %s (브랜치는 그대로)" % path)
    return 0


def c_orphans(root, a) -> int:
    known = {str(Path(r["경로"]).resolve()) for r in load(root, a.roadmap)["자원"]}
    items = worktrees(root)
    stray = [w for w in items[1:] if w["path"] not in known]
    for w in stray:
        n = len(dirty_lines(Path(w["path"]))) if Path(w["path"]).is_dir() else 0
        print("%s\t%s\t%s" % (w["path"], w["branch"], "깨끗" if not n else "남은 것 %d개" % n))
    if not stray:
        print("주인 모름 worktree 없음")
    return 0


def _rs(p):
    p.add_argument("--roadmap", required=True)
    p.add_argument("--session", required=True)


def _rows(p):
    _rs(p)
    p.add_argument("--section", required=True)


COMMANDS = {
    "roadmaps": (c_roadmaps, lambda p: None),
    "claim": (c_claim, _rs),
    "takeover": (c_takeover, _rs),
    "release": (c_release, _rs),
    "add": (c_add, lambda p: (_rows(p), p.add_argument("--cells", required=True))),
    "drop": (c_drop, lambda p: (_rows(p), p.add_argument("--where", required=True))),
    "approval": (c_approval, lambda p: (_rs(p), p.add_argument("--scale", required=True))),
    "approve": (c_approve, lambda p: (_rs(p), p.add_argument("--scale", required=True))),
    "resources": (c_resources, lambda p: p.add_argument("--roadmap", required=True)),
    "cleanup-check": (c_cleanup_check, lambda p: p.add_argument("--path", required=True)),
    "cleanup": (c_cleanup, lambda p: (_rs(p), p.add_argument("--path", required=True))),
    "orphans": (c_orphans, lambda p: p.add_argument("--roadmap", required=True)),
}


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="conductor_ledger.py", description="지휘자 기록 · 자원 · 감사")
    ap.add_argument("--root")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, (_fn, define) in COMMANDS.items():
        define(sub.add_parser(name))
    a = ap.parse_args(argv)
    try:
        root = Path(a.root) if a.root else top()
        return COMMANDS[a.cmd][0](root, a)
    except Fail as exc:
        print("[spec-distill] %s" % exc)
        return exc.rc
    except cs.MachineError as exc:
        print("[spec-distill] %s" % exc)
        return 3


if __name__ == "__main__":
    sys.exit(main())
