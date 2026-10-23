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
  pr-refresh --roadmap R --session S [--epic E] [--reset]   PR 캐시를 head 이름의 PR 전부로 채운다
  pr-record  --roadmap R --session S --epic E --pr <PR> [--drop]   대조한 에픽 PR 번호 줄과 PR 캐시 줄을 쓴다(--drop 은 지운다)
  (Task 5~7 이 자원 · 기록 절 · 감사 명령을 더한다)
  suite-lock --roadmap R                               공유 스위트 잠금 경로 · 주인 · 잡은 시각
  progress   --roadmap R                               실행 원장마다 마지막 고친 시각 · 마지막 줄

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가(gh 멈춤 — gh 없음 · origin · 인증 포함) · 4 받은 gh 출력이 기대와
다르다(pr-refresh: 다른 head · 모르는 값 / pr-record: head · 교차 레포 · base 대조 실패 · PR URL 의 레포가 origin 아님 —
아무것도 쓰지 않는다) · 5 다른 세션의 표지.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import branch_tip  # noqa: E402
import conductor_state as cs  # noqa: E402
import gh_repo  # noqa: E402
import repo_defaults  # noqa: E402
import suite_lock  # noqa: E402
from roadmap_model import (APPROVAL_PREFIX, DEFAULT_REF, IMPL_PREFIX, RECORD_HEADING,  # noqa: E402
                           RULINGS_HEADING, FormatError, approval_date, blob_reader, find_roadmaps, parse_roadmap,
                           section_lines, tree_entries)
from state_path import StateRootError, ensure_state_root, state_root  # noqa: E402

DONE = ("머지됨", "끝남")
GIT = shutil.which("git") or "git"
if os.path.isabs(GIT):  # 이 스크립트가 찾은 git 을 해결자의 git 호출도 쓰게 한다
    repo_defaults.git_bin_dir = os.path.dirname(GIT)


class Fail(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


def git(cwd, *args):
    p = subprocess.run([GIT, *args], cwd=str(cwd), capture_output=True, encoding="utf-8", errors="replace")
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


def mdir_for_write(root, roadmap: str) -> Path:
    """기계 상태 폴더 — 상태 루트를 먼저 보장한다(스스로 무시 · 추적 파일이면 멈춤). 폴더를 만드는 자리만 부른다."""
    path = mpath(root, roadmap)
    try:
        for line in ensure_state_root(state_root(str(root)), str(root)):
            print(line, file=sys.stderr)
    except StateRootError as exc:
        raise Fail(3, str(exc))
    return path.parent


def load(root, roadmap: str, skip: tuple = ()) -> dict:
    try:
        return cs.load(mpath(root, roadmap), roadmap, skip)
    except cs.OldPrRows as exc:
        raise Fail(3, str(exc))
    except cs.MachineError as exc:
        raise Fail(3, "기계 상태를 읽지 못했다 — 덮어쓰지 않는다: %s" % exc)


def need_holder(root, roadmap: str, session: str) -> None:
    owner = cs.holder(mpath(root, roadmap).parent)
    if owner != session:
        raise Fail(5, "읽기 전용 — 표지를 쥔 세션: %s" % (owner or "없음(먼저 claim)"))


def update(root, roadmap: str, session: str, change, skip: tuple = ()) -> dict:
    """표지를 쥔 세션만 쓴다. 깨진 기계 상태는 읽기에서 멈춘다(빈 상태로 덮어쓰지 않는다)."""
    path = mpath(root, roadmap)
    need_holder(root, roadmap, session)
    data = load(root, roadmap, skip)
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
    rc, out, _e = git(path, "-c", "core.quotePath=false", "status", "--porcelain", "--untracked-files=all")
    if rc:
        raise Fail(2, "worktree 가 아니다: %s" % path)
    lines = ["바뀐 파일: %s" % l[3:] for l in out.splitlines() if l.strip()]
    work = path / repo_defaults.SDD_WORKSPACE
    if work.is_dir() and any(work.iterdir()):
        lines.append("실행 방식 작업 폴더(git 밖 기록 — 남길 것은 설계문서 절로 옮긴다): %s" % work)
    return lines


REVIEW_PACK_DIR = "review"
FILES_DIR = "files"                      # 기계 상태 자원 폴더 — <기계 상태 폴더>/files/<종류>/<이름>
FILE_KINDS = ("tmp", "relay", "report")  # agent 몫 임시 폴더 · 옮김 기록 · 하위 보고
def disposable_kind(root, roadmap: str, path: Path):
    """지휘자가 직접 만든 일회용만 「merge」(스위트 대조 사본) · 「pack」(리뷰 묶음) · 「file」(자원 폴더의 바로 아래
    항목 — `resource-dir` 이 만든 것) — 그 밖은 None."""
    mdir = mpath(root, roadmap).parent.resolve()
    rp = path.resolve()
    if (rp.parent.parent == mdir / repo_defaults.MERGE_CHECK_DIR and rp.parent.name.startswith("run-")
            and rp.name in ("base", "merged")):
        return "merge"
    if rp.parent == mdir / REVIEW_PACK_DIR:
        return "pack"
    if rp.parent.parent == mdir / FILES_DIR and rp.parent.name in FILE_KINDS:
        return "file"
    return None


def _live_lock(root, roadmap: str) -> str:
    """공유 스위트 잠금이 바쁘면 그 주인(비면 「기록 전」), 아니면 빈 글 — 판정은 `suite_lock.state` 하나."""
    s = suite_lock.state(suite_lock.lock_path(mpath(root, roadmap).parent))
    if not s["busy"]:
        return ""
    return s["owner"] or "기록 전"


def require_user_worktree(root, path: Path) -> None:
    """일회용이 아닌 경로는 등록된 worktree 이고 메인 체크아웃이 아니어야 한다."""
    if path.is_symlink():
        raise Fail(2, "worktree 가 아니다(심볼릭 링크): %s" % path)
    items = worktrees(root)
    rp = path.resolve()
    if str(rp) not in {w["path"] for w in items[1:]}:
        raise Fail(2, "worktree 가 아니다(또는 메인 체크아웃이다): %s" % path)
    here = Path(os.getcwd()).resolve()
    if rp == Path(root).resolve() or rp == here or rp in here.parents:
        raise Fail(2, "지금 작업 중인 자리다 — 지우지 않는다: %s" % path)


def _heads(lines: list) -> list:
    """(줄 번호, 머리) — 펜스 밖 `## ` 머리."""
    out, fence = [], False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            fence = not fence
        elif not fence and line.startswith("## "):
            out.append((i, line.rstrip()))
    return out


def _section_end(lines: list, start: int) -> int:
    nxt = [i for i, _h in _heads(lines) if i > start]
    end = nxt[0] if nxt else len(lines)
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    return end


def _finish(lines: list) -> str:
    return "\n".join(lines).rstrip("\n") + "\n"


def _one_line(value: str, what: str) -> None:
    """줄 나눔 글자(\\n · \\r · U+2028 …)가 든 값은 쓰지 않는다 — 쓴 문서가 달리 읽힌다."""
    if len(value.splitlines()) > 1 or (value and value.splitlines() != [value]):
        raise Fail(2, "%s 에 줄 나눔 글자가 들어 있다" % what)


def _bullet(line: str) -> str:
    return line if line.startswith("- ") else "- " + line


def insert_record(text: str, line: str) -> str:
    _one_line(line, "기록 한 줄")
    line = _bullet(line)
    try:
        section_lines(text, RECORD_HEADING)
    except FormatError as exc:
        raise Fail(3, "지휘 기록 절을 읽지 못했다: %s" % exc)
    lines = text.rstrip("\n").split("\n")
    at = [i for i, h in _heads(lines) if h == RECORD_HEADING]
    if not at:
        out = _finish(lines + ["", RECORD_HEADING, "", line])
    else:
        end = _section_end(lines, at[0])
        if end == at[0] + 1:
            out = _finish(lines[:end] + ["", line] + lines[end:])
        else:
            out = _finish(lines[:end] + [line] + lines[end:])
    try:
        approval_date(out)
    except FormatError as exc:
        raise Fail(2, "이 줄을 더하면 승인 줄을 읽을 수 없게 된다: %s" % exc)
    return out


def approval_line(date: str, choice: str) -> str:
    return "%s%s · 「%s」" % (APPROVAL_PREFIX, date, choice)


def _date_shape(value: str) -> bool:
    """YYYY-MM-DD 꼴 — 글자 검사 + 실제 달력 날짜."""
    if len(value) != 10 or value[4] != "-" or value[7] != "-":
        return False
    if not (value[:4] + value[5:7] + value[8:]).isdigit() or not value.isascii():
        return False
    try:
        datetime.date(int(value[:4]), int(value[5:7]), int(value[8:]))
    except ValueError:
        return False
    return True


def insert_sections(text: str, plan_rel: str, rulings: list, impl_line: str, counts: str) -> str:
    for what, val in [("계획 경로", plan_rel), ("구현 대조 줄", impl_line), ("보고 줄", counts)] + \
            [("판정 줄", r) for r in rulings]:
        _one_line(val, what)
    lines = text.rstrip("\n").split("\n")
    heads = _heads(lines)
    if any(h == IMPL_PREFIX + plan_rel for _i, h in heads):
        raise Fail(2, "이미 있다 — %s%s" % (IMPL_PREFIX, plan_rel))
    try:
        section_lines(text, RULINGS_HEADING)
    except FormatError as exc:
        raise Fail(3, "판정 절을 읽지 못했다: %s" % exc)
    block = ["### " + plan_rel, ""] + [r if r.startswith("- ") else "- " + r for r in rulings]
    at = [i for i, h in heads if h == RULINGS_HEADING]
    if at:
        end = _section_end(lines, at[0])
        body = lines[at[0] + 1:end]
        if any(l.rstrip() == "### " + plan_rel for l in body):
            raise Fail(2, "이미 있다 — ### %s (판정 절 안)" % plan_rel)
        first_sub = next((k for k, l in enumerate(body) if l.startswith("### ")), len(body))
        if any(l.startswith("- ") for l in body[:first_sub]):
            raise Fail(3, "앞 계획의 판정 줄이 하위 머리 없이 있다 — 먼저 `### <앞 계획 경로>` 아래로 옮긴다")
        lines = lines[:end] + [""] + block + lines[end:]
    else:
        lines = lines + ["", RULINGS_HEADING, ""] + block
    lines += ["", IMPL_PREFIX + plan_rel, "", "- 구현 대조: " + impl_line, "- 보고: " + counts]
    return _finish(lines)


def harvest(report_text: str, ledger_texts: list) -> dict:
    """실행 중 원장에서 읽은 판정과 하위의 마지막 보고의 판정을 합친다 — 보고에만 · 원장에만 있는 수도 낸다."""
    def norm(l):
        body = l.strip()
        if body[:2] in ("- ", "* "):
            body = body[2:].strip()
        return "- " + body
    led = [norm(l) for t in ledger_texts for l in cs.ledger_rulings(t)]
    rep = [norm(l) for l in cs.ledger_rulings(report_text)]
    lines = list(dict.fromkeys(led + rep))
    return {"lines": lines, "report": len(rep), "ledger": len(led),
            "only_report": [l for l in rep if l not in led], "only_ledger": [l for l in led if l not in rep]}


def write_atomic(path: Path, text: str) -> None:
    """인코딩을 먼저 하고 임시 파일 + 교체 — 실패해도 원래 파일이 남는다."""
    try:
        data = text.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise Fail(3, "글을 UTF-8 로 바꾸지 못해 쓰지 않았다: %s" % exc)
    fd, tmp = tempfile.mkstemp(prefix=".ledger.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        if path.exists():
            os.chmod(tmp, stat.S_IMODE(path.stat().st_mode))
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Fail(3, "읽지 못했다: %s (%s)" % (path, type(exc).__name__))


HANDOFF_HEADING = "## 통합 리뷰 인계"
AFTER_REVIEW = "리뷰 뒤 반영"
CARRY_HEADS = ("## 번호 대조", "## Acceptance Criteria", "## 미룸")
CARRY_PREFIX = 16


def handoff_section(body: str) -> list:
    out, inside = [], False
    for line in body.splitlines():
        if line.startswith("## "):
            inside = line.rstrip() == HANDOFF_HEADING
            continue
        if inside and line.strip():
            out.append(line.rstrip())
    return out


def after_review_lines(body: str) -> list:
    return [l.rstrip() for l in body.splitlines() if AFTER_REVIEW in l and l.lstrip().startswith("- ")]


def _plain(text: str) -> str:
    return " ".join(text.translate({ord("`"): None, ord("*"): None}).split())


def carried(item: str, receiver_text: str) -> bool:
    """받은 쪽 설계문서의 번호 대조 · AC · 미룸 절에 넘김 항목의 앞부분이 있는가 — 「줄어든 넘김 의심」 후보용."""
    key = _plain(item)[:CARRY_PREFIX]
    body, inside = [], False
    for line in receiver_text.splitlines():
        if line.startswith("## "):
            inside = line.rstrip() in CARRY_HEADS
            continue
        if inside:
            body.append(line)
    return bool(key) and key in _plain("\n".join(body))


def version_report(root, plugin_json: Path):
    """(rc, 한 줄). rc 1 = 설치본이 옛 판이거나 비교하지 못했다."""
    def cannot(why):
        return 1, "판을 비교하지 못했다 — %s" % why
    try:
        inst = json.loads(Path(plugin_json).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return cannot("설치본 plugin.json 을 읽지 못했다: %s" % plugin_json)
    if not isinstance(inst, dict) or not str(inst.get("name") or "").strip():
        return cannot("설치본 plugin.json 에 이름이 없다")
    name = str(inst["name"]).strip()
    iv = cs.version_triple(inst.get("version", ""))
    if iv is None:
        return cannot("설치본 판 %r 을 읽지 못했다" % inst.get("version"))
    rc, out, err = git(root, "ls-files", "--", "*plugin.json")
    if rc:
        return cannot("추적 파일 목록을 읽지 못했다: %s" % err)
    broken = []
    for rel in out.splitlines():
        try:
            src = json.loads((Path(root) / rel).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            broken.append(rel)
            continue
        if not isinstance(src, dict):
            broken.append(rel)
            continue
        if str(src.get("name") or "").strip() != name:
            continue
        sv = cs.version_triple(src.get("version", ""))
        if sv is None:
            return cannot("레포 사본 판 %r 을 읽지 못했다" % src.get("version"))
        if sv > iv:
            extra = (" — 레포 사본의 기능(예: 묶음 대조 · 「여기서 계속」 · 기각 번호 보이기)이 없을 수 있다"
                     if name == "spec-distill" else "")
            return 1, ("설치된 %s %s 이 레포 사본 %s 보다 옛 판이다%s. 플러그인을 갱신하거나 레포 사본으로 지휘한다"
                       % (name, inst.get("version"), src.get("version"), extra))
        if iv > sv:
            return 0, "설치된 %s %s 이 레포 사본 %s 보다 새 판이다" % (name, inst.get("version"), src.get("version"))
        return 0, "설치본과 레포 사본의 판이 맞다(%s)" % inst.get("version")
    if broken:
        return cannot("추적 중인 plugin.json 을 읽지 못했다: %s" % " · ".join(broken[:3]))
    return 0, "레포에 같은 이름(%s)의 플러그인 소스가 없다" % name


def version_gap(root, plugin_json: Path):
    rc, msg = version_report(root, plugin_json)
    return msg if rc else None


def _status(root, roadmap: str) -> dict:
    p = subprocess.run([sys.executable, str(HERE / "roadmap_status.py"), "--json", roadmap], cwd=str(root),
                       capture_output=True, encoding="utf-8", errors="replace")
    try:
        rep = json.loads(p.stdout)
    except ValueError:
        raise Fail(3, "상태 계산을 읽지 못했다(rc %d): %s" % (p.returncode, p.stderr.strip()[-200:]))
    if not isinstance(rep, dict):
        raise Fail(3, "상태 계산 출력의 모양이 다르다")
    if rep.get("exit") in (3, 4) and not any(x.get("stage") for x in rep.get("blocks") or []):
        why = list(rep.get("unknown_reasons") or []) + list(rep.get("format_errors") or [])
        if not why and rep.get("not_on_default"):
            why = ["로드맵이 기본 브랜치에 없다(읽은 곳: %s)" % rep.get("source")]
        raise Fail(3, "상태를 셀 수 없다 — %s" % (" · ".join(str(w) for w in why) or "이유 없음(rc %s)" % rep.get("exit")))
    return rep


def _block(report: dict, epic: str) -> dict:
    b = next((x for x in report.get("blocks") or [] if x.get("id") == epic), None)
    if b is None:
        raise Fail(2, "에픽 %s 가 로드맵에 없다" % epic)
    return b


def _ref(b: dict) -> str:
    return b.get("tip") or DEFAULT_REF


def _doc(root, b: dict, path: str):
    """문서 글. 읽지 못하면 None — 빈 글과 다른 사실이다."""
    rc, text, _e = git(root, "show", "%s:%s" % (_ref(b), path))
    return text if rc == 0 else None


HANDOFF_STOP = "PR 인계를 읽지 못했다 — %s"


def _gh() -> str:
    """gh 실행 파일. 없으면 Fail(3) — 멈춤 문장은 gh_repo 가 낸다."""
    try:
        return gh_repo.gh_exe()
    except gh_repo.GhStop as exc:
        raise Fail(3, HANDOFF_STOP % exc)


PR_LIMIT = 20


def _prs(root, b: dict):
    """[(브랜치, [PR…], 한도에 닿았는가)]. 브랜치가 없으면 []. PR 본문(인계 절)이 필요해 gh_repo.gh_json 으로 묻는다."""
    _gh()
    out = []
    for br in b.get("branches") or [s["branch"] for s in b.get("branch_states") or []]:
        try:
            items = gh_repo.gh_json(str(root), ["pr", "list", "--state", "all", "--head", br, "--json", "number,state,body",
                                                "--limit", str(PR_LIMIT)])
        except gh_repo.GhStop as exc:
            raise Fail(3, HANDOFF_STOP % exc)
        if not isinstance(items, list):
            raise Fail(3, HANDOFF_STOP % ("gh pr list 출력 모양이 다르다(브랜치 %s) — gh 판을 확인한다" % br))
        items = [it for it in items if isinstance(it, dict)]
        out.append((br, items, len(items) >= PR_LIMIT))
    return out


NAME_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")


def _default_sha(root) -> str:
    """기본 브랜치 커밋. 못 찾으면 고치는 법(origin 없음 · origin/HEAD 없음)을 담아 멈춘다."""
    try:
        sha, _short, why = repo_defaults.default_branch(str(root))
    except repo_defaults.SettingsError as exc:
        raise Fail(3, str(exc))
    if why:
        raise Fail(3, why)
    return sha


def _roadmap_blocks(root, roadmap: str) -> list:
    _default_sha(root)
    rc, text, err = git(root, "show", "%s:%s" % (DEFAULT_REF, roadmap))
    if rc:
        raise Fail(3, "기본 브랜치에서 로드맵을 읽지 못했다: %s" % roadmap)
    _m, blocks, _r, _k, errors = parse_roadmap(text)
    if errors:
        raise Fail(3, "로드맵 형식이 깨졌다: %s" % errors[0])
    return blocks


def _with_copy_branches(root, roadmap: str, blocks: list, warns: list) -> list:
    """블록 `브랜치:` 에 기본 브랜치에 아직 들어가지 않은 브랜치의 로드맵 사본이 더한 이름을 잇는다 — 상태 계산과 같은 규칙
    (`roadmap_status.extra_branches`: 사본 블록이 기본 브랜치 블록의 브랜치를 모두 품을 때만). 계획 2 · 3 의 브랜치는 자기
    사본에서만 블록에 자신을 더해서, 기본 브랜치 블록만 읽으면 열린 에픽 브랜치를 빠뜨린다."""
    import roadmap_status as rs
    main = _default_sha(root)
    g = rs.Git(str(root))
    if os.path.isabs(GIT):  # 이 스크립트가 찾은 git 을 상태 계산의 git 호출도 쓰게 한다
        g.env["PATH"] = os.path.dirname(GIT) + os.pathsep + g.env.get("PATH", "")
    try:
        extra, broken = rs.extra_branches(g, main, roadmap, blocks)
    except RuntimeError as exc:
        warns.append("로드맵 사본을 읽지 못했다 — 사본이 더한 브랜치를 빠뜨렸을 수 있다(%s)" % exc)
        return blocks
    for f in g.failures:
        warns.append("로드맵 사본을 다 읽지 못했다 — 사본이 더한 브랜치를 빠뜨렸을 수 있다(%s)" % f)
    if broken:
        warns.append("기본 브랜치에 아직 들어가지 않은 브랜치의 로드맵 사본 %d개는 형식이 깨져 읽은 블록만 셌다" % broken)
    for b in blocks:
        more = [br for br in extra.get(b["id"], []) if br not in (b.get("branches") or [])]
        if more:
            b["branches"] = list(b.get("branches") or []) + more
            warns.append("%s: 블록 `브랜치:` 에 없는 %s 도 열린 브랜치로 셌다 — 기본 브랜치에 아직 들어가지 않은 브랜치의 "
                         "로드맵 사본이 이 블록에 더했다" % (b["id"], " · ".join(more)))
    return blocks


def _status_with_copies(root, roadmap: str) -> dict:
    """상태 계산 + 로드맵 사본이 더한 브랜치. 사본 경고는 여기서 보인다 — pr-refresh · pr-record 가 같은 해석을 쓴다."""
    report = _status(root, roadmap)
    warns = []
    report["blocks"] = _with_copy_branches(root, roadmap, report.get("blocks") or [], warns)
    for w in warns:
        print("[spec-distill] " + w)
    return report


def _branches_of(b: dict) -> list:
    """블록의 브랜치 — `branches` 가 없으면 상태 계산의 `branch_states` 이름."""
    return list(b.get("branches") or [s["branch"] for s in b.get("branch_states") or []])


def _pack_diff(root, tip: str, warns: list, label: str) -> str:
    rc, d, err = git(root, "-c", "core.quotePath=false", "diff", "%s...%s" % (DEFAULT_REF, tip))
    if rc:
        warns.append("%s diff 를 만들지 못했다 — %s" % (label, err[-160:]))
        return "diff 를 만들지 못했다 — %s\n" % err[-160:]
    return d + "\n"


# ── 하위 명령 ────────────────────────────────────────────────────────────────

def _roadmaps_dir(root) -> str:
    """해결자가 기본 브랜치의 레포 설정으로 정한 로드맵 폴더. 설정이 깨졌으면 멈춘다 — 기본 폴더로 조용히 찾지 않는다."""
    try:
        result = repo_defaults.resolve(str(root))
    except repo_defaults.SettingsError as exc:
        raise Fail(3, str(exc))
    if result["errors"]:
        raise Fail(3, "레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다 — %s" % result["errors"][0])
    return result["values"]["roadmaps_dir"]


def _default_roadmaps(root, main: str) -> tuple:
    """(로드맵 경로들, [(검사 불가 경로, 사유)]) — 기본 브랜치의 로드맵 폴더 목록과 blob 읽기로 find_roadmaps 를 부른다."""
    folder = _roadmaps_dir(root)
    p = subprocess.run([GIT, "ls-tree", "-r", "-z", main, "--", folder], cwd=str(root), capture_output=True)
    if p.returncode:
        raise Fail(3, "기본 브랜치의 로드맵 목록을 읽지 못했다: %s" % p.stderr.decode("utf-8", "replace").strip())
    entries = tree_entries(p.stdout, folder)

    def cat(sha):
        c = subprocess.run([GIT, "cat-file", "blob", sha], cwd=str(root), capture_output=True)
        return c.returncode, c.stdout
    return find_roadmaps(list(entries), blob_reader(entries, cat, set()), folder)


def c_roadmaps(root, a) -> int:
    found_paths, unchecked = _default_roadmaps(root, _default_sha(root))
    unchecked = dict(unchecked)
    found = 0
    for path in sorted(found_paths + list(unchecked)):
        if path in unchecked:   # 머리말을 못 읽은 후보 — 조용히 빼지 않고 검사 불가로 센다
            print("%s\t검사 불가" % path)
            found += 1
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
    got = cs.acquire(mdir_for_write(root, a.roadmap), a.session)
    if got in ("acquired", "held"):
        if got == "acquired":
            _drop_approval(root, a)
        print(got)
        return 0
    print("다른 세션(%s)이 이 로드맵을 지휘하고 있다 — 이 세션은 읽기 전용으로 보인다. 넘겨받을지는 사용자가 정한다(takeover)" % got)
    return 5


def c_takeover(root, a) -> int:
    prev = cs.takeover(mdir_for_write(root, a.roadmap), a.session)
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
    if a.roadmap and not path.is_symlink() and disposable_kind(root, a.roadmap, path):
        print("일회용(지휘자가 만든 사본 · 묶음 · 자원 폴더 항목) — 확인 없이 지운다: %s" % path)
        return 0
    try:
        require_user_worktree(root, path)
    except Fail as exc:
        print(exc)
        return exc.rc
    lines = dirty_lines(path)
    for l in lines:
        print(l)
    if not lines:
        print("깨끗하다 — 지워도 된다: %s" % path)
    return 1 if lines else 0


def c_cleanup(root, a) -> int:
    path = Path(a.path)
    owner = cs.holder(mpath(root, a.roadmap).parent)
    if owner != a.session:
        raise Fail(5, "읽기 전용 — 표지를 쥔 세션: %s" % (owner or "없음(먼저 claim)"))
    if path.is_symlink():
        raise Fail(3, "심볼릭 링크는 지우지 않는다: %s" % path)
    kind = disposable_kind(root, a.roadmap, path)
    if kind == "merge":
        pid = _live_lock(root, a.roadmap)
        if pid:
            raise Fail(3, "공유 스위트 잠금을 누가 쥐고 있다(주인 %s) — 스위트가 끝난 뒤 지운다: %s" % (pid, path))
        if path.exists():
            rc, _o, err = git(root, "worktree", "remove", "--force", str(path))
            if rc:
                raise Fail(3, "스위트 대조 사본을 지우지 못했다: %s" % err)
    elif kind == "pack":
        if path.exists():
            try:
                shutil.rmtree(str(path))
            except OSError as exc:
                raise Fail(3, "리뷰 묶음을 지우지 못했다: %s" % exc)
    elif kind == "file":
        if path.exists():
            try:
                if path.is_dir():
                    shutil.rmtree(str(path))
                else:
                    os.unlink(str(path))
            except OSError as exc:
                raise Fail(3, "자원 폴더의 항목을 지우지 못했다: %s" % exc)
    else:
        if not path.is_dir():
            raise Fail(2, "폴더가 없다: %s" % path)
        require_user_worktree(root, path)
        lines = dirty_lines(path)
        if lines:
            for l in lines:
                print(l)
            print("지우지 않았다 — 위 내용을 사용자에게 보이고 묻는다(--force 를 쓰지 않는다)")
            return 1
        rc, _o, err = git(root, "worktree", "remove", str(path))
        if rc:
            raise Fail(3, "worktree 를 지우지 못했다: %s" % err)
    if path.exists():
        raise Fail(3, "지웠는데 아직 남아 있다 — 자원 줄을 그대로 둔다: %s" % path)
    update(root, a.roadmap, a.session,
           lambda d: d.__setitem__("자원", [r for r in d["자원"] if Path(r["경로"]).resolve() != path.resolve()]))
    print("정리했다 — %s (브랜치는 그대로)" % path)
    return 0


def c_orphans(root, a) -> int:
    known = {str(Path(r["경로"]).resolve()) for r in load(root, a.roadmap)["자원"]}
    items = worktrees(root)
    stray = [w for w in items[1:] if w["path"] not in known]
    for w in stray:
        try:
            if not Path(w["path"]).is_dir():
                state = "폴더 없음(prunable)"
            else:
                n = len(dirty_lines(Path(w["path"])))
                state = "깨끗" if not n else "남은 것 %d개" % n
        except (Fail, OSError):
            state = "상태를 읽지 못함"
        print("%s\t%s\t%s" % (w["path"], w["branch"], state))
    if not stray:
        print("주인 모름 worktree 없음")
    return 0


def c_record(root, a) -> int:
    path = Path(a.spec)
    if a.approval:
        if not (a.date and a.choice):
            raise Fail(2, "--approval 에는 --date 와 --choice 가 필요하다")
        if not _date_shape(a.date):
            raise Fail(2, "--date 는 YYYY-MM-DD 꼴이어야 한다: %s" % a.date)
        line = approval_line(a.date, a.choice)
    elif a.line:
        line = a.line
    else:
        raise Fail(2, "--line 또는 --approval 이 필요하다")
    write_atomic(path, insert_record(_read(path), line))
    print("적었다(커밋은 지휘자가) — %s: %s" % (path, line))
    return 0


def c_rulings(root, a) -> int:
    got = harvest(_read(Path(a.report)), [_read(Path(p)) for p in a.ledger or []])
    if not got["lines"]:
        print("판정 줄 — 셀 수 없음(보고에도 원장에도 판정이 없다)")
        return 3
    text = "\n".join(got["lines"]) + "\n"
    if a.out:
        write_atomic(Path(a.out), text)
    print(text, end="")
    print("판정 %d개(보고 %d · 원장 %d · 보고에만 %d · 원장에만 %d)"
          % (len(got["lines"]), got["report"], got["ledger"], len(got["only_report"]), len(got["only_ledger"])))
    return 0


def c_write_sections(root, a) -> int:
    path = Path(a.spec)
    raw = [l for l in _read(Path(a.rulings)).splitlines() if l.strip()]
    stray = [l for l in raw if not l.startswith("- ")]
    if stray:
        raise Fail(2, "판정 파일에 `- ` 로 시작하지 않는 줄이 있다 — 쓰지 않았다: %s" % " | ".join(stray[:3]))
    rulings = raw
    if not [l for l in rulings if l[2:].strip()]:
        raise Fail(3, "판정 줄 — 셀 수 없음(판정 파일에 판정이 없다) — 쓰지 않았다")
    write_atomic(path, insert_sections(_read(path), a.plan, rulings, a.impl_line, a.counts))
    print("판정 %d줄과 구현 대조 절을 썼다(커밋 · push 는 지휘자가) — %s" % (len(rulings), path))
    return 0


def c_flush(root, a) -> int:
    path = Path(a.spec)
    owner = cs.holder(mpath(root, a.roadmap).parent)
    if owner != a.session:
        raise Fail(5, "읽기 전용 — 표지를 쥔 세션: %s" % (owner or "없음(먼저 claim)"))
    rows = [r for r in load(root, a.roadmap)["쌓인 기록"] if r["에픽"] == a.epic and r["절"] == "지휘 기록"]
    text = _read(path)
    try:
        section_lines(text, RECORD_HEADING)
    except FormatError as exc:
        raise Fail(3, "지휘 기록 절을 읽지 못했다: %s" % exc)
    moved = 0
    for r in rows:
        have = section_lines(text, RECORD_HEADING) or []
        if _bullet(r["글"]) not in [l.strip() for l in have]:
            text = insert_record(text, r["글"])
            moved += 1
    write_atomic(path, text)
    update(root, a.roadmap, a.session, lambda d: d.__setitem__(
        "쌓인 기록", [r for r in d["쌓인 기록"] if not (r["에픽"] == a.epic and r["절"] == "지휘 기록")]))
    print("쌓인 기록 %d줄을 옮겼고 %d줄은 이미 있어 건너뛰었다(커밋은 지휘자가) — %s"
          % (moved, len(rows) - moved, path))
    return 0


def c_pending(root, a) -> int:
    rows = [r for r in load(root, a.roadmap)["쌓인 기록"] if not a.epic or r["에픽"] == a.epic]
    for r in rows:
        print("- %s · %s" % (r["에픽"], r["글"]) if not a.epic else "- " + r["글"])
    if not rows:
        print("쌓인 기록 없음")
    return 0


def c_live_agent(root, a) -> int:
    """살아 있는 agent 행 가운데 에픽 · 일이 같은 것을 낸다 — 0 있음 · 1 없음 · 3 기계 상태를 못 읽음."""
    rows = [r for r in load(root, a.roadmap)["살아 있는 agent"] if r["에픽"] == a.epic and r["일"] == a.work]
    for r in rows:
        print(" · ".join(r[c] for c in cs.COLUMNS["살아 있는 agent"]))
    if not rows:
        print("%s · %s 로 살아 있는 agent 없음" % (a.epic, a.work))
    return 0 if rows else 1


def c_pr_handoffs(root, a) -> int:
    _gh()  # gh 가 없으면 상태 계산보다 먼저 멈춘다
    b = _block(_status(root, a.roadmap), a.epic)
    got = _prs(root, b)
    if not got:
        print("%s 브랜치 없음" % a.epic)
    for br, items, hit in got:
        if not items:
            print("%s PR 없음" % br)
        for it in items:
            body = str(it.get("body") or "")
            print("%s #%s(%s)" % (br, it.get("number"), it.get("state")))
            for line in handoff_section(body) or ["(인계 절 없음)"]:
                print("  " + line)
            for line in after_review_lines(body):
                print("  " + line)
        if hit:
            print("%s PR 목록이 %d개 한도에 닿았다 — 더 있을 수 있다" % (br, PR_LIMIT))
    return 0


PR_REFRESH_LIMIT = 100
GH_PR_STATES = {"OPEN": "열림", "MERGED": "머지됨", "CLOSED": "닫힘"}


def _cache_row(br: str, it: dict, when: str, session: str) -> dict:
    state = GH_PR_STATES.get(it.get("state"))
    cross = it.get("isCrossRepository")
    if it.get("headRefName") != br:
        raise Fail(4, "gh 가 다른 브랜치의 PR 을 냈다(브랜치 %s · PR #%s 의 head %s) — 아무것도 적지 않았다. gh 판을 확인한다"
                   % (br, it.get("number"), it.get("headRefName")))
    if state is None or not isinstance(cross, bool):
        raise Fail(4, "gh pr list 출력 모양이 다르다(브랜치 %s · PR #%s) — gh 판을 확인한다" % (br, it.get("number")))
    merge = it.get("mergeCommit")
    oid = merge.get("oid") if isinstance(merge, dict) else None
    return {"브랜치": br, "번호": "#%s" % it.get("number"), "상태": state, "확인한 때": when,
            "headRefOid": str(it.get("headRefOid") or ""), "교차 레포": "예" if cross else "아니오",
            "baseRefName": str(it.get("baseRefName") or ""), "mergeCommit": str(oid or "-"), "쓴 세션": session}


def c_pr_refresh(root, a) -> int:
    """대상 블록(없으면 끝나지 않은 블록 전부, `--reset` 이면 끝난 블록까지)의 브랜치마다 그 head 이름의 PR 을 모두 받아
    그 브랜치의 PR 줄을 통째로 바꾼다. PR 이 없는 브랜치는 「PR 0개」 줄 하나로 확인한 때를 남긴다."""
    if a.reset and a.epic:
        raise Fail(2, "`--reset` 은 PR 절 전체를 다시 채운다 — `--epic` 을 빼고 다시 돌려라")
    for line in gh_repo.env_notices():
        print("[spec-distill] " + line)
    need_holder(root, a.roadmap, a.session)
    skip = ("PR",) if a.reset else ()
    load(root, a.roadmap, skip)  # 옛 판의 PR 줄 · 깨진 상태는 gh 를 부르기 전에 멈춘다
    report = _status_with_copies(root, a.roadmap)
    if a.epic:
        blocks = [_block(report, a.epic)]
    elif a.reset:
        blocks = list(report["blocks"])  # PR 절을 비웠으니 끝난 에픽의 줄도 다시 채운다 — 아니면 squash 머지가 머지됨에서 빠진다
    else:
        blocks = [b for b in report["blocks"] if b.get("stage") not in DONE]
    branches = []
    for b in blocks:
        for br in _branches_of(b):
            if br not in branches:
                branches.append(br)
    when = now()
    fresh = {}
    for br in branches:
        try:
            items, hit = gh_repo.pr_list(str(root), br, PR_REFRESH_LIMIT)
        except gh_repo.GhStop as exc:
            raise Fail(3, str(exc))
        if hit:
            print("[spec-distill] %s 의 PR 목록이 %d개 한도에 닿았다 — 더 있을 수 있다" % (br, PR_REFRESH_LIMIT))
        fresh[br] = [_cache_row(br, it, when, a.session) for it in items] or [cs.no_pr_row(br, when, a.session)]

    def change(d):
        kept = [r for r in d["PR"] if r["브랜치"] not in fresh]
        d["PR"] = kept + [r for br in branches for r in fresh[br]]
    update(root, a.roadmap, a.session, change, skip)
    print("PR 캐시: 브랜치 %d개 · PR %d개를 %s 에 채웠다"
          % (len(branches), sum(1 for v in fresh.values() for r in v if r["번호"] != cs.NO_PR), when))
    return 0


def c_pr_record(root, a) -> int:
    """번호로 물은 PR 의 head · 교차 · base 를 그 에픽의 브랜치와 대조한 뒤에만 `## 에픽 PR` 번호 줄과 `## PR` 캐시 줄을
    한 번에 쓴다. `--drop` 은 gh 없이 (에픽, 번호) 줄을 지운다."""
    ref = gh_repo.parse_pr_ref(a.pr)
    if ref is None:
        raise Fail(2, "PR 번호를 읽지 못했다: %r — PR URL 이나 숫자(예: --pr 123)를 준다" % a.pr)
    n, url = ref
    number = "#%d" % n
    if a.drop:
        gone = []

        def drop(d):
            gone.extend(r for r in d[cs.EPIC_PR] if r["에픽"] == a.epic and r["번호"] == number)
            d[cs.EPIC_PR] = [r for r in d[cs.EPIC_PR] if not (r["에픽"] == a.epic and r["번호"] == number)]
        update(root, a.roadmap, a.session, drop)
        if not gone:
            print("[spec-distill] 지울 번호 줄이 없다 — %s · %s" % (a.epic, number))
            return 1
        print("번호 줄을 지웠다 — %s · %s" % (a.epic, number))
        return 0
    need_holder(root, a.roadmap, a.session)
    load(root, a.roadmap)  # 깨진 기계 상태는 gh 를 부르기 전에 멈춘다
    if url is not None:
        try:
            origin = gh_repo.origin_slug(str(root))
        except gh_repo.GhStop as exc:
            raise Fail(3, str(exc))
        if (url[0].lower(), url[1].casefold(), url[2].casefold()) != \
                (origin[0].lower(), origin[1].casefold(), origin[2].casefold()):
            raise Fail(4, "PR URL 의 레포(%s)가 origin(%s)이 아니다 — 아무것도 적지 않았다"
                       % ("/".join(url), "/".join(origin)))
    branches = _branches_of(_block(_status_with_copies(root, a.roadmap), a.epic))
    try:
        it = gh_repo.pr_view(str(root), n)
    except gh_repo.GhStop as exc:
        raise Fail(3, str(exc))
    try:
        _sha, base, why = repo_defaults.default_branch(str(root))
    except repo_defaults.SettingsError as exc:
        raise Fail(3, str(exc))
    if why:
        raise Fail(3, why)
    head = it.get("headRefName")
    bad = []
    if it.get("number") != n:
        bad.append("number: %d ≠ %s" % (n, it.get("number")))
    if head not in branches:
        bad.append("headRefName: %s 중 하나 ≠ %s" % (" · ".join(branches) or "브랜치 없음", head))
    if it.get("isCrossRepository") is not False:
        bad.append("isCrossRepository: false ≠ %s" % json.dumps(it.get("isCrossRepository")))
    if it.get("baseRefName") != base:
        bad.append("baseRefName: %s ≠ %s — 쌓인 PR 이면 바탕을 기본 브랜치로 바꾼 직후 다시 적는다"
                   % (base, it.get("baseRefName")))
    if bad:
        raise Fail(4, "PR %s 이 에픽 %s 와 맞지 않는다(%s) — 아무것도 적지 않았다" % (number, a.epic, " · ".join(bad)))
    when = now()
    cache = _cache_row(head, it, when, a.session)
    mine = {"에픽": a.epic, "브랜치": head, "번호": number, "적은 때": when, "쓴 세션": a.session}

    def change(d):
        rows = d[cs.EPIC_PR]
        at = next((i for i, r in enumerate(rows) if r["에픽"] == a.epic and r["브랜치"] == head), None)
        if at is None:
            rows.append(mine)
        else:
            rows[at] = mine
        d["PR"] = [r for r in d["PR"] if not (r["브랜치"] == head and r["번호"] in (number, cs.NO_PR))] + [cache]
    update(root, a.roadmap, a.session, change)
    print("번호를 적었다 — %s · %s · %s(PR 캐시 줄도 썼다)" % (a.epic, head, number))
    return 0


def _unread(spec: str, b: dict) -> str:
    return "셀 수 없음 — %s 을 %s 에서 읽지 못했다" % (spec, _ref(b))


def c_audit(root, a) -> int:
    import check_bundle_coverage as cbc
    from roadmap_model import rulings_archived, section_body
    report = _status(root, a.roadmap)
    b = _block(report, a.epic)
    groups = []  # (머리, 항목 줄들, 셀 수 있는 후보 수, 셀 수 없는가)

    def add(label, items, count=None, bad=False):
        groups.append((label, items, len(items) if count is None else count, bad))
    reasons = [str(r) for r in report.get("unknown_reasons") or []]
    if reasons:
        add("상태 계산", reasons, 0, True)
    specs = b.get("specs") or []
    texts = {}
    if b.get("stage") == "알 수 없음":
        add("설계문서", ["셀 수 없음 — %s" % (b.get("reason") or "단계를 알 수 없다")], 0, True)
        specs = []
    for spec in specs:
        text = _doc(root, b, spec)
        texts[spec] = text
        if text is None:
            for label in ("기각한 번호", "미룸", "판정"):
                add("%s(%s)" % (label, spec), [_unread(spec, b)], 0, True)
            continue
        label = "기각한 번호(%s)" % spec
        try:
            if section_body(text, cbc.TABLE_HEADING) is None:
                add(label, [])
            else:
                rows = [(ids, cell) for ids, verb, cell in cbc.table_rows(text) if verb.startswith("기각")]
                add(label, ["%s — %s" % (" · ".join(ids), cell) for ids, cell in rows],
                    sum(len(ids) for ids, _c in rows))
        except FormatError as exc:
            add(label, ["셀 수 없음 — %s" % exc], 0, True)
        try:
            add("미룸(%s)" % spec, ["%s → %s" % (it, recv) for it, _w, recv in cbc.deferred_rows(text)])
        except FormatError as exc:
            add("미룸(%s)" % spec, ["셀 수 없음 — %s" % exc], 0, True)
        try:
            add("판정(%s)" % spec, rulings_archived(text) or [])
        except FormatError as exc:
            add("판정(%s)" % spec, ["셀 수 없음 — %s" % exc], 0, True)
    try:
        lines, notes = [], []
        for br, items, hit in _prs(root, b):
            lines += [l for it in items for l in after_review_lines(str(it.get("body") or ""))]
            if hit:
                notes.append("%s PR 목록이 %d개 한도에 닿았다 — 더 있을 수 있다" % (br, PR_LIMIT))
        add("리뷰 뒤 반영", lines)
        if notes:
            add("리뷰 뒤 반영(셀 수 없음)", notes, 0, True)
    except Fail as exc:
        add("리뷰 뒤 반영", ["읽지 못함 — %s" % exc], 0, True)
    handoffs = report.get("handoffs")
    if handoffs is None:
        add("줄어든 넘김 의심", ["셀 수 없음 — 넘김 목록을 읽지 못했다"], 0, True)
    else:
        mine = None if any(texts.get(s) is None for s in specs) else "\n".join(texts[s] for s in specs)
        shrunk, cannot = [], []
        for h in handoffs:
            if h.get("receiver") != a.epic:
                continue
            tag = "%s/%s: %s" % (h.get("giver"), h.get("spec"), h.get("item"))
            if h.get("state") == "셀 수 없음":
                cannot.append("셀 수 없음 — %s (%s)" % (tag, h.get("basis")))
            elif mine is None:
                cannot.append("셀 수 없음 — %s (받는 쪽 설계문서를 읽지 못했다)" % tag)
            elif specs and not carried(str(h.get("item")), mine):  # 설계문서가 아직 없으면 줄어들 것도 없다
                shrunk.append("%s → %s" % (tag, a.epic))
        add("줄어든 넘김 의심", shrunk)
        if cannot:
            add("줄어든 넘김 의심(셀 수 없음)", cannot, 0, True)
    shown = 0
    for label, items, count, bad in groups:
        if count or bad:
            print("%s %s" % (label, "— 셀 수 없음" if bad else "%d개" % count))
            for it in items:
                print("  " + it)
            shown += 1
    if not shown:
        print("감사 후보 없음(읽은 곳 모두에서)")
    return 0


def c_review_pack(root, a) -> int:
    if not a.epic or not set(a.epic) <= NAME_CHARS or a.epic in (".", ".."):
        raise Fail(2, "에픽 이름은 영숫자 · . · _ · - 만 쓴다: %r" % a.epic)
    files, conflicts, warns, skipped = [], [], [], []
    blocks = _with_copy_branches(root, a.roadmap, _roadmap_blocks(root, a.roadmap), warns)
    try:
        tip, note = branch_tip.tip(root, a.branch)
    except branch_tip.TipError as exc:
        raise Fail(3, str(exc))
    if tip is None:
        raise Fail(3, "브랜치를 찾지 못했다: %s" % a.branch)
    if note:
        print(note)
    default_dir = (mpath(root, a.roadmap).parent if a.out else mdir_for_write(root, a.roadmap)) / REVIEW_PACK_DIR
    out = Path(a.out) if a.out else default_dir / ("%s-%s" % (a.epic, datetime.datetime.now().strftime("%Y%m%d%H%M%S")))
    try:
        out.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        raise Fail(2, "이미 있는 폴더다 — 새 폴더를 쓴다: %s" % out)
    except OSError as exc:
        raise Fail(3, "묶음 폴더를 만들지 못했다: %s (%s)" % (out, type(exc).__name__))

    def put(name, text):
        write_atomic(out / name, text)
        files.append(name)
    put("pr.diff", _pack_diff(root, tip, warns, "pr.diff"))
    for b in blocks:
        for br in b.get("branches") or []:
            if a.branch in (br, "origin/" + br):
                continue
            try:
                other, note = branch_tip.tip(root, br)
            except branch_tip.TipError as exc:
                skipped.append("%s(%s): %s — 충돌 미리 보기에서 빠짐" % (b["id"], br, exc))
                continue
            if note:
                warns.append(note)
            if other is None:
                skipped.append("%s(%s): 브랜치를 찾지 못했다(아직 안 만들었거나 받지 않음) — 충돌 미리 보기에서 빠짐"
                               % (b["id"], br))
                continue
            rc = git(root, "merge-base", "--is-ancestor", other, DEFAULT_REF)[0]
            if rc == 0:
                continue  # 이미 기본 브랜치에 들어갔다
            if rc != 1:
                warns.append("%s(%s) 가 기본 브랜치에 들어갔는지 읽지 못했다 — 열린 것으로 다룬다" % (b["id"], br))
            name = "open-%s-%s.diff" % (b["id"], br.replace("/", "_"))
            put(name, _pack_diff(root, other, warns, name))
            rc, mt, err = git(root, "-c", "core.quotePath=false", "merge-tree", "--write-tree", "--name-only", tip, other)
            if rc == 1:
                names = []
                for n in mt.splitlines()[1:]:
                    if not n.strip():
                        break  # 첫 빈 줄 뒤는 안내 글이다
                    names.append(n.strip())
                if names:
                    conflicts.append("%s(%s): %s" % (b["id"], br, " · ".join(names)))
                else:
                    conflicts.append("%s(%s): 미리 보기 실패 — 충돌 파일 이름을 읽지 못했다" % (b["id"], br))
                    warns.append("%s(%s) 충돌 파일 이름을 읽지 못했다" % (b["id"], br))
            elif rc != 0:
                conflicts.append("%s(%s): 미리 보기 실패 — %s" % (b["id"], br, err[-160:]))
                warns.append("%s(%s) 충돌 미리 보기를 만들지 못했다" % (b["id"], br))
    warns.extend(skipped)
    body = list(conflicts) + skipped
    if not conflicts:
        body.insert(0, "충돌 없음(미리 본 브랜치만)" if skipped else "충돌 없음")
    put("conflicts.txt", "\n".join(body) + "\n")
    try:
        lines = []
        for b in blocks:
            for br, items, hit in _prs(root, b):
                if hit:
                    note = "%s PR 목록이 %d개 한도에 닿았다 — 더 있을 수 있다" % (br, PR_LIMIT)
                    lines += ["(" + note + ")", ""]
                    warns.append(note)
                for it in items:
                    sec = handoff_section(str(it.get("body") or ""))
                    if sec:
                        lines += ["### %s %s #%s(%s)" % (b["id"], br, it.get("number"), it.get("state")), ""] + sec + [""]
        handoffs = "\n".join(lines) or "앞선 인계 절 없음"
    except Fail as exc:
        handoffs = "(%s)" % exc
        warns.append(str(exc))
    put("handoffs.md", handoffs + "\n")
    readme = ["이 폴더는 통합 리뷰 묶음이다 — %s 의 %s" % (a.epic, a.branch),
              "합친 사본: %s" % (a.merged or "(넘기지 않았다)"),
              "pr.diff — 기본 브랜치에서 갈라진 뒤 이 브랜치의 diff",
              "open-<에픽>-<브랜치>.diff — 아직 기본 브랜치에 안 들어간 다른 에픽 브랜치의 diff",
              "conflicts.txt — 이 브랜치와 열린 다른 브랜치를 합칠 때 충돌할 파일(git merge-tree)",
              "handoffs.md — 앞선 PR 들의 `## 통합 리뷰 인계` 절"] + skipped
    put("README.txt", "\n".join(readme) + "\n")
    print(out)
    for f in files:
        print("  " + f)
    for w in warns:
        print("경고: " + w)
    try:
        inside = out.resolve().parent == default_dir.resolve()
    except OSError:
        inside = False
    if not inside:
        print("이 묶음은 지휘자의 review 폴더 밖에 있다 — `ledger cleanup` 이 지우지 않는다")
    return 0


def c_worktree_path(root, a) -> int:
    if not a.name or not set(a.name) <= NAME_CHARS or a.name in (".", ".."):
        raise Fail(2, "worktree 이름은 영숫자 · . · _ · - 만 쓴다: %r" % a.name)
    main_checkout = Path(worktrees(root)[0]["path"])
    print(main_checkout / repo_defaults.WORKTREE_HOME / a.name)
    return 0


def c_resource_dir(root, a) -> int:
    """기계 상태 자원 폴더 `<기계 상태 폴더>/files/<종류>/<이름>` 을 만들고 경로를 낸다 — `cleanup` 이 확인 없이 치우는 자리."""
    if not a.name or not set(a.name) <= NAME_CHARS or a.name in (".", ".."):
        raise Fail(2, "자원 이름은 영숫자 · . · _ · - 만 쓴다: %r" % a.name)
    mdir = mdir_for_write(root, a.roadmap)
    base = mdir / FILES_DIR / a.kind
    out = base / a.name
    for p in (mdir, mdir / FILES_DIR, base, out):
        if p.is_symlink():
            raise Fail(3, "자원 폴더 경로에 심볼릭 링크가 있다 — 만들지 않는다: %s" % p)
    try:
        out.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise Fail(3, "자원 폴더를 만들지 못했다: %s (%s)" % (out, type(exc).__name__))
    if disposable_kind(root, a.roadmap, out) != "file":
        raise Fail(3, "만든 폴더가 자원 폴더 자리가 아니다: %s" % out)
    print(out)
    return 0


def c_suite_lock(root, a) -> int:
    """공유 스위트 잠금 경로(첫 줄)와 지금 주인 · 잡은 시각(둘째 줄). 경로는 하위에게 보내는 글에 싣는다."""
    lock = suite_lock.lock_path(mpath(root, a.roadmap).parent)
    print(lock)
    print(suite_lock.describe(lock))
    return 0


PROGRESS_TAIL = 120


def c_progress(root, a) -> int:
    """실행 원장마다 마지막으로 고친 시각과 마지막 줄 — 멈춤 판단의 근거(완료 표시만으로 멈춤을 단정하지 않는다)."""
    rows = load(root, a.roadmap)["실행 원장"]
    print("기준 %s" % datetime.datetime.now().strftime("%H:%M"))
    for r in rows:
        head = "%s · %s" % (r["에픽"], r["계획"])
        path = Path(r["원장"])
        try:
            mtime = path.stat().st_mtime
            lines = [l.strip() for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
        except (OSError, UnicodeDecodeError) as exc:
            print("%s · 원장을 읽지 못했다(%s · %s)" % (head, path, type(exc).__name__))
            continue
        ago = int((time.time() - mtime) // 60)
        last = lines[-1][:PROGRESS_TAIL] if lines else "(빈 원장)"
        print("%s · 마지막 고침 %s(%d분 전) · %s" % (
            head, datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M"), ago, last))
    if not rows:
        print("실행 원장 없음")
    return 0


def c_version(root, a) -> int:
    rc, msg = version_report(root, Path(a.plugin_json))
    print(msg)
    return rc


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
    "cleanup-check": (c_cleanup_check, lambda p: (p.add_argument("--path", required=True),
                                                  p.add_argument("--roadmap", default=None))),
    "cleanup": (c_cleanup, lambda p: (_rs(p), p.add_argument("--path", required=True))),
    "orphans": (c_orphans, lambda p: p.add_argument("--roadmap", required=True)),
    "record": (c_record, lambda p: (p.add_argument("--spec", required=True), p.add_argument("--line"),
                                    p.add_argument("--approval", action="store_true"), p.add_argument("--date"),
                                    p.add_argument("--choice"))),
    "rulings": (c_rulings, lambda p: (p.add_argument("--report", required=True),
                                      p.add_argument("--ledger", action="append"), p.add_argument("--out"))),
    "write-sections": (c_write_sections, lambda p: (p.add_argument("--spec", required=True),
                                                    p.add_argument("--plan", required=True),
                                                    p.add_argument("--rulings", required=True),
                                                    p.add_argument("--impl-line", required=True),
                                                    p.add_argument("--counts", required=True))),
    "flush": (c_flush, lambda p: (_rs(p), p.add_argument("--epic", required=True), p.add_argument("--spec", required=True))),
    "pending": (c_pending, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic"))),
    "live-agent": (c_live_agent, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True),
                                            p.add_argument("--work", required=True))),
    "pr-refresh": (c_pr_refresh, lambda p: (_rs(p), p.add_argument("--epic"), p.add_argument("--reset", action="store_true"))),
    "pr-record": (c_pr_record, lambda p: (_rs(p), p.add_argument("--epic", required=True), p.add_argument("--pr", required=True),
                                          p.add_argument("--drop", action="store_true"))),
    "pr-handoffs": (c_pr_handoffs, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True))),
    "audit": (c_audit, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True))),
    "review-pack": (c_review_pack, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True),
                                              p.add_argument("--branch", required=True), p.add_argument("--merged"),
                                              p.add_argument("--out"))),
    "worktree-path": (c_worktree_path, lambda p: p.add_argument("--name", required=True)),
    "resource-dir": (c_resource_dir, lambda p: (p.add_argument("--roadmap", required=True),
                                                p.add_argument("--kind", required=True, choices=FILE_KINDS),
                                                p.add_argument("--name", required=True))),
    "version": (c_version, lambda p: p.add_argument("--plugin-json", required=True)),
    "suite-lock": (c_suite_lock, lambda p: p.add_argument("--roadmap", required=True)),
    "progress": (c_progress, lambda p: p.add_argument("--roadmap", required=True)),
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
