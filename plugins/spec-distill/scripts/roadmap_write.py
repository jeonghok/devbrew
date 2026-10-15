#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py — 승인된 분해안 표로 로드맵 · 에픽 묶음을 쓰고, 쓴 직후 검증한다.

명령줄:
  roadmap_write.py create --brief <brief> --audit <audit> --plan-table <표 파일> --out <로드맵 폴더>
                          --title <제목> --date <YYYY-MM-DD> --approval <승인 원문>
  roadmap_write.py update --roadmap <로드맵> --brief <brief> --audit <audit> --plan-table <새 표 파일>
                          --date <YYYY-MM-DD> --change <바뀐 것 한 줄> --approval <승인 원문>
  roadmap_write.py extract --roadmap <로드맵>     로드맵 블록 · 묶음에서 분해안 표를 뽑아 낸다(쓰지 않는다)

종료 코드: 0 성공 · 1 쓰지 않음(표 오류 · 덮어쓰기 거부 · 검증 실패 — 쓴 것은 모두 되돌렸다) · 2 사용법 오류.

검증은 쓴 로드맵에 `roadmap_status.py --roadmap-file <로드맵> --json` 을 돌려 format_errors · unassigned ·
orphans · unknown_ids 넷이 모두 빈 목록일 때만 성공이다. 검사기의 종료 코드는 보지 않는다 — origin/main 을
못 읽으면 3, 진행 경고면 1 이 나와 생성물의 유효성과 무관하다.
create 는 표 파일의 `## 생성 기록` 절에 자기가 만든 파일을 적고, 다시 돌 때 그 기록에 있는 파일만 덮어쓴다.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roadmap_render as R  # noqa: E402
from check_bundle_coverage import FormatError, frontmatter, section_body, unquote  # noqa: E402
from roadmap_status import DATE_RE  # noqa: E402

RS = Path(__file__).resolve().parent / "roadmap_status.py"
RECORD_HEADING = "## 생성 기록"
LISTS = ("format_errors", "unassigned", "orphans", "unknown_ids")


class Refused(Exception):
    """쓰지 않는다 — 사유를 그대로 보이고 rc 1."""


class Usage(Exception):
    """사용법 오류 — rc 2."""


# ── 경로 · 읽기 ──────────────────────────────────────────────────────────────

def git_top(path) -> Path:
    d = Path(os.path.realpath(str(path)))
    while not d.is_dir():
        d = d.parent
    proc = subprocess.run(["git", "-C", str(d), "rev-parse", "--show-toplevel"],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.returncode != 0:
        raise Usage("git 작업 트리 밖이다: %s" % path)
    return Path(os.path.realpath(proc.stdout.decode("utf-8").strip()))


def rel(top: Path, path) -> str:
    try:
        return Path(os.path.realpath(str(path))).relative_to(top).as_posix()
    except ValueError:
        raise Usage("%s 가 작업 트리 %s 밖이다" % (path, top))


def read(path) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Refused("못 읽었다: %s (%s)" % (path, exc))


# ── 쓰기 트랜잭션 ────────────────────────────────────────────────────────────

def _atomic(path: Path, data: bytes):
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".roadmap_write.")
    try:
        os.write(fd, data)
        os.close(fd)
        if path.exists():
            mode = path.stat().st_mode & 0o777
        else:
            mask = os.umask(0)
            os.umask(mask)
            mode = 0o666 & ~mask
        os.chmod(tmp, mode)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


class Txn:
    """쓴 것을 기억했다가 되돌린다 — 덮어쓴 파일은 원래 바이트로, 새 파일 · 새 폴더는 지운다."""

    def __init__(self):
        self.saved, self.created, self.dirs = {}, [], []

    def ensure_dir(self, d: Path):
        missing = []
        while not d.exists():
            missing.append(d)
            d = d.parent
        for m in reversed(missing):
            m.mkdir()
            self.dirs.append(m)

    def _remember(self, path: Path):
        if path in self.saved or path in self.created:
            return
        if path.exists():
            self.saved[path] = path.read_bytes()
        else:
            self.created.append(path)

    def write(self, path: Path, text: str):
        self._remember(path)
        _atomic(path, text.encode("utf-8"))

    def remove(self, path: Path):
        self._remember(path)
        path.unlink()

    def rollback(self) -> list:
        errs = []
        for path, data in self.saved.items():
            try:
                _atomic(path, data)
            except OSError as exc:
                errs.append("%s 를 원래 바이트로 되돌리지 못했다: %s" % (path, exc))
        for path in self.created:
            try:
                if path.exists():
                    path.unlink()
            except OSError as exc:
                errs.append("%s 를 지우지 못했다: %s" % (path, exc))
        for d in reversed(self.dirs):
            try:
                d.rmdir()
            except OSError as exc:
                errs.append("%s 폴더를 지우지 못했다: %s" % (d, exc))
        return errs


def run_txn(txn: Txn, body):
    """body() 가 실패하면 되돌리고, 되돌리지 못한 것이 있으면 사유에 붙여 다시 올린다."""
    try:
        body()
    except BaseException as exc:
        errs = txn.rollback()
        if errs:
            raise Refused("%s / 되돌리지 못했다: %s" % (exc, " · ".join(errs)))
        raise


# ── 검증 ─────────────────────────────────────────────────────────────────────

def judge(stdout: str, rc: int) -> list:
    """검사기 JSON 에서 실패 사유 목록. 빈 목록이면 통과. rc 는 사유 글에만 쓴다."""
    try:
        report = json.loads(stdout)
    except ValueError:
        report = None
    if not isinstance(report, dict):
        return ["검사기 출력을 읽지 못했다(rc %d)" % rc]
    reasons = []
    for key in LISTS:
        value = report.get(key)
        if not isinstance(value, list):
            why = " · ".join(str(x) for x in report.get("unknown_reasons") or []) or "값 없음"
            reasons.append("%s: 셀 수 없음 — %s" % (key, why))
        elif value:
            reasons.append("%s: %s" % (key, " · ".join(str(x) for x in value)))
    return reasons


def _status_json(top: Path, roadmap: Path):
    try:
        proc = subprocess.run([sys.executable, str(RS), "--roadmap-file", str(roadmap), "--json"],
                              cwd=str(top), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as exc:
        return "", -1, str(exc)
    return proc.stdout.decode("utf-8", "replace"), proc.returncode, ""


def validate(top: Path, roadmap: Path) -> list:
    out, rc, err = _status_json(top, roadmap)
    if err:
        return ["검사기를 돌리지 못했다: %s" % err]
    return judge(out, rc)


# ── 생성 기록 ────────────────────────────────────────────────────────────────

def read_record(text: str) -> set:
    try:
        body = section_body(text, RECORD_HEADING)
    except FormatError as exc:
        raise Refused(str(exc))
    return {l[2:].strip() for l in (body or "").splitlines() if l.startswith("- ")}


def with_record(text: str, paths) -> str:
    block = RECORD_HEADING + "\n\n" + "".join("- %s\n" % p for p in sorted(paths))
    lines = text.splitlines(keepends=True)
    start = next((i for i, l in enumerate(lines) if l.rstrip("\r\n") == RECORD_HEADING), None)
    if start is None:
        return text.rstrip("\n") + "\n\n" + block
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    tail = "".join(lines[end:])
    return "".join(lines[:start]) + block + ("\n" + tail if tail else "")


# ── 명령 ─────────────────────────────────────────────────────────────────────

def _date(value: str) -> str:
    if not DATE_RE.fullmatch(value):
        raise Usage("--date 는 YYYY-MM-DD 다: %r" % value)
    return value


def cmd_create(a) -> int:
    out_dir = Path(os.path.realpath(a.out))
    top = git_top(out_dir)
    roadmap = out_dir / "roadmap.md"
    brief_rel, audit_rel, roadmap_rel = rel(top, a.brief), rel(top, a.audit), rel(top, roadmap)
    date = _date(a.date)
    table_path = Path(a.plan_table)
    table_text = read(table_path)
    rows = R.parse_table(table_text)
    idx = R.index_brief(read(a.brief), read(a.audit))
    history = "- %s · 처음 로드맵 · 승인 원문 「%s」" % (date, a.approval)
    files = {roadmap: R.render_roadmap(read(R.TEMPLATE), rows, idx, a.title, brief_rel, roadmap_rel, history)}
    for r in rows:
        if r.kind == R.KIND_BUNDLE:
            files[out_dir / (r.id + ".md")] = R.render_bundle(r, idx, roadmap_rel, brief_rel, audit_rel)
    record = read_record(table_text)
    targets = {rel(top, p) for p in files}
    stray = sorted(rel(top, p) for p in files if p.exists() and rel(top, p) not in record)
    if stray:
        raise Refused("이 생성기가 만들지 않은 파일은 덮어쓰지 않는다 — %s" % " · ".join(stray))
    stale = [top / p for p in sorted(record - targets) if (top / p).parent == out_dir]
    txn = Txn()

    def body():
        txn.ensure_dir(out_dir)
        for path, text in files.items():
            txn.write(path, text)
        for path in stale:
            if path.exists():
                txn.remove(path)
        reasons = validate(top, roadmap)
        if reasons:
            raise Refused("검증 실패 — %s" % " / ".join(reasons))
        txn.write(table_path, with_record(table_text, targets))

    run_txn(txn, body)
    print("[spec-distill] 로드맵을 만들었다: %s (묶음 %d개) — 검사기 네 목록이 비었다"
          % (roadmap_rel, len(files) - 1))
    return 0


def cmd_extract(a) -> int:
    roadmap = Path(os.path.realpath(a.roadmap))
    rdir = roadmap.parent
    rows = R.extract_rows(read(roadmap),
                          lambda name: read(rdir / name) if (rdir / name).is_file() else None)
    sys.stdout.write(R.format_table(rows))
    return 0


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="roadmap_write.py",
                                 description="분해안 표로 로드맵 · 에픽 묶음을 쓰고 검증한다.")
    sub = ap.add_subparsers(dest="cmd")
    sub.required = True
    c = sub.add_parser("create")
    for flag in ("--brief", "--audit", "--plan-table", "--out", "--title", "--date", "--approval"):
        c.add_argument(flag, required=True)
    e = sub.add_parser("extract")
    e.add_argument("--roadmap", required=True)
    return ap


COMMANDS = {"create": cmd_create, "extract": cmd_extract}


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    a = build_parser().parse_args(argv)   # 사용법 오류는 argparse 가 rc 2 로 끝낸다
    try:
        return COMMANDS[a.cmd](a)
    except Usage as exc:
        print("[spec-distill] 사용법 오류 — %s" % exc, file=sys.stderr)
        return 2
    except (Refused, R.TableError, FormatError) as exc:
        print("[spec-distill] 로드맵을 쓰지 않았다 — %s" % exc)
        return 1
    except Exception as exc:  # 쓰다 죽어도 성공(0)으로 내지 않는다 — 쓴 것은 run_txn 이 되돌렸다
        print("[spec-distill] 로드맵을 쓰지 않았다 — 내부 오류 %s: %s" % (type(exc).__name__, exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
