#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_state.py — 지휘자 기계 상태(`machine.md`)의 형식 · 읽기 · 원자 쓰기 · 세션 표지.

기계 상태는 이 기계에서만 뜻이 있는 것(PR 번호 캐시 · 실행 원장 위치 · 자원 · 살아 있는 agent · 작업(로드맵 밖 일 포함) · 기다리는 질문 ·
아직 커밋하지 못한 기록 · 임시 레포 설정 · 시작 승인(같은 세션 이어 부르기 공시))만 담는다. 이어 가기에 필요한 기록은 에픽 설계문서의 절이 주인이다.
넘김 상태 계산은 읽기 전용 `roadmap_model.py` 가 하고 여기서 다시 내보낸다. 상태 계산(`roadmap_status.py`) · 화면(`control_plane.py`) · 지휘자 스크립트가 이 모듈 하나를 쓴다.

명령줄(읽기만):
  conductor_state.py path --roadmap <로드맵 레포 상대경로>   이 기계의 기계 상태 파일 경로
  conductor_state.py show --roadmap <…>                     읽은 결과 JSON — 깨졌으면 사유와 rc 3
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_defaults  # noqa: E402
from ledger_marker import _atomic_write, _read_line  # noqa: E402 — 리뷰 원장 표지와 같은 방식
from roadmap_model import (  # noqa: E402,F401 — 옮긴 이름의 옛 자리
    CONFIRM_RE, EPIC_RE, FormatError, IMPL_PREFIX, ISSUE_RE, RECEIVED, RECORD_HEADING, RULINGS_HEADING, _headings,
    confirmed_keys, handoff_key, handoff_rows, impl_done, rulings_archived, section_lines)
from state_path import SESSION_PATTERN, state_root  # noqa: E402

MACHINE_FILE = "machine.md"
MARKER = "conducting-by"
TYPE = "conductor-machine"
SECTIONS = (
    ("PR", ("브랜치", "번호", "상태", "확인한 때", "headRefOid", "교차 레포", "baseRefName", "mergeCommit", "쓴 세션")),
    ("실행 원장", ("에픽", "계획", "원장", "읽은 줄")),
    ("자원", ("종류", "경로", "에픽", "용도", "만든 때")),
    ("살아 있는 agent", ("이름", "에픽", "일", "worktree", "보낸 때")),
    ("작업", ("종류", "이름", "에픽", "단계", "담당", "근거")),
    ("기다리는 질문", ("에픽", "기대는 일", "질문")),
    ("쌓인 기록", ("에픽", "절", "글")),
    ("레포 설정", ("키", "값")),
    ("시작 승인", ("세션", "때", "규모")),
)
COLUMNS = dict(SECTIONS)
OPTIONAL_SECTIONS = ("작업",)
WORK_DONE = ("끝", "끝남", "머지됨")  # 「작업」 단계 칸에서 끝으로 세는 낱말 — 지휘 절차(conducting.md 걸음 1)가 같은 낱말을 밝힌다
PR_STATES = ("열림", "머지됨", "닫힘")
PR_NUMBER_RE = re.compile(r"#\d+")
PR_CROSS = ("예", "아니오")
OID_RE = re.compile(r"[0-9a-f]{40}")
OLD_PR_CELLS = 4
SEP = " · "


class MachineError(ValueError):
    """기계 상태를 읽거나 쓸 수 없다 — 빈 상태로 읽지 않는다."""


class OldPrRows(MachineError):
    """옛 판이 쓴 4칸 PR 캐시 줄 — 메시지가 고치는 명령(`--reset`)이다."""


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
        if not OID_RE.fullmatch(row["headRefOid"]):
            raise MachineError("%s: headRefOid 는 40자 16진이다: %r" % (where, row["headRefOid"]))
        if row["교차 레포"] not in PR_CROSS:
            raise MachineError("%s: 교차 레포는 %s 중 하나다: %r" % (where, " · ".join(PR_CROSS), row["교차 레포"]))
        if row["mergeCommit"] != "-" and not OID_RE.fullmatch(row["mergeCommit"]):
            raise MachineError("%s: mergeCommit 은 40자 16진이거나 `-` 다: %r" % (where, row["mergeCommit"]))
    if section == "실행 원장" and not re.fullmatch(r"[0-9]+", row["읽은 줄"]):
        raise MachineError("%s: 읽은 줄은 숫자다: %r" % (where, row["읽은 줄"]))


def parse_machine(text: str, roadmap_rel: str, skip: tuple = ()) -> dict:
    """skip 에 든 절은 줄 검사 없이 비운다."""
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
        if cur in skip:
            continue
        if cur is None or not line.startswith("- "):
            raise MachineError("%d줄: 읽지 못한 줄 %r" % (n, line))
        cols = COLUMNS[cur]
        cells = [c.strip() for c in line[2:].split(SEP, len(cols) - 1)]
        if cur == "PR" and len(cells) == OLD_PR_CELLS:
            raise OldPrRows("%d줄: 옛 판이 쓴 PR 캐시 줄이다(칸 4개) — ledger pr-refresh --roadmap <로드맵> "
                               "--session <세션> --reset 으로 다시 채운다" % n)
        if len(cells) != len(cols) or not all(cells):
            raise MachineError("%d줄: %s 절의 칸 %d개(%s)가 아니다" % (n, cur, len(cols), " · ".join(cols)))
        row = dict(zip(cols, cells))
        _check_row(cur, row, "%d줄" % n)
        data[cur].append(row)
    return data


def render_machine(roadmap_rel: str, data: dict) -> str:
    out = ["---", "type: " + TYPE, "roadmap: " + roadmap_rel, "---", ""]
    for name, cols in SECTIONS:
        if name in OPTIONAL_SECTIONS and not data.get(name):
            continue  # 7.6 에 더한 절 — 비어 있으면 머리를 쓰지 않아 옛 판도 이 파일을 읽는다
        out += ["## " + name, ""]
        for row in data.get(name, []):
            cells = [str(row[c]).replace("\n", " ").strip() for c in cols]
            if not all(cells):
                raise MachineError("%s 절에 빈 칸이 있다: %r" % (name, row))
            if any(SEP in c or c.startswith("·") or c.endswith("·") for c in cells[:-1]):
                raise MachineError("%s 절: 마지막 칸이 아닌 칸에 ` · ` 를 쓰거나 `·` 로 시작·끝낼 수 없다: %r" % (name, row))
            _check_row(name, dict(zip(cols, cells)), name)
            out.append("- " + SEP.join(cells))
        out.append("")
    return "\n".join(out)


def _normalized(data: dict) -> dict:
    out = empty()
    for name, cols in SECTIONS:
        for row in data.get(name, []):
            out[name].append(dict((c, str(row[c]).replace("\n", " ").strip()) for c in cols))
    return out


def load(path: Path, roadmap_rel: str, skip: tuple = ()) -> dict:
    path = Path(path)
    if path.is_symlink():
        raise MachineError("기계 상태 파일이 링크다: %s" % path)
    if not path.exists():
        return empty()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise MachineError("기계 상태 파일을 읽지 못했다: %s (%s)" % (path, type(exc).__name__))
    return parse_machine(text, roadmap_rel, skip)


def repo_settings_rows(path, roadmap_rel: str) -> dict:
    """`## 레포 설정` 의 키 → 값(해결자 `repo_defaults.resolve` 의 기계 상태 층). 같은 키가 둘이면 MachineError."""
    out = {}
    for row in load(path, roadmap_rel)["레포 설정"]:
        if row["키"] in out:
            raise MachineError("레포 설정 절에 같은 키가 둘이다(%s) — 한 줄만 남긴다" % row["키"])
        out[row["키"]] = row["값"]
    return out


# ── 표지 · 쓰기 ──────────────────────────────────────────────────────────────

def _need_session(session) -> str:
    if not isinstance(session, str) or not SESSION_PATTERN.fullmatch(session):
        raise MachineError("세션 id 형식이 아니다: %r" % (str(session) if session is not None else "")[:32])
    return session


def holder(d: Path):
    return _read_line(Path(d), MARKER) or None


def acquire(d: Path, session: str) -> str:
    """"acquired" · "held" 또는 표지를 쥔 다른 세션 id."""
    _need_session(session)
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
    _need_session(session)
    d = Path(d)
    if holder(d) != session:
        return False
    os.unlink(str(d / MARKER))
    return True


def takeover(d: Path, session: str):
    """표지를 넘겨받는다 — 사용자가 정했을 때만 부른다. 이전 주인을 돌려준다."""
    _need_session(session)
    d = Path(d)
    prev = holder(d)
    _atomic_write(d, MARKER, session + "\n")
    return prev


def save(path: Path, roadmap_rel: str, data: dict, session: str) -> None:
    """표지를 쥔 세션만 쓴다. 임시 파일 + os.replace 로 원자적으로."""
    path = Path(path)
    _need_session(session)
    owner = holder(path.parent)
    if owner != session:
        raise MachineError("표지가 이 세션 것이 아니다(쥔 세션: %s) — 읽기 전용이다" % (owner or "없음"))
    text = render_machine(roadmap_rel, data)
    if parse_machine(text, roadmap_rel) != _normalized(data):
        raise MachineError("쓴 글을 다시 읽으면 넣은 값과 다르다 — 칸 값에 구분자가 섞였다")
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

def ledger_rulings(text: str) -> list:
    """실행 방식 원장의 판정 줄 — `Ruling:` 이 든 줄."""
    return [l.strip() for l in text.splitlines() if "Ruling:" in l]


# ── 넘김 ─────────────────────────────────────────────────────────────────────

def confirm_line(giver: str, item: str, basis: str) -> str:
    return "- 넘김 확인 · %s · %s · %s" % (giver, handoff_key(giver, item), basis)


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
