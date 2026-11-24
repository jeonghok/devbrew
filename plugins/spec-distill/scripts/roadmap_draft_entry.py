#!/usr/bin/env python3
"""roadmap-draft 진입 검사 — 파일을 쓰지 않고 판결 줄을 낸다.

CLI
roadmap_draft_entry.py --brief <결과물 경로>

출력(차례대로, 각 한 줄)
  raw-source: FOUND <경로> | LOST <사유> | NO-FRAMING     (raw_source.py locate 의 줄 그대로)
  roadmap-entry: STOP <사유>                              (멈출 사유마다 — 모두 낸다)
  roadmap-entry: RESUME <무엇이 있는가>                   (멈출 사유가 없고 상태 파일에 분해안 표나 생성 기록이 있을 때)
  roadmap-entry: OK | RESUME | STOP                       (마지막 줄 — 늘 판결 하나)
종료 코드: OK · RESUME 0 / STOP 1 / 인자 오류 · 내부 오류 2
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from check_brief import SPLIT_LINE_PREFIX, payload_is_split  # noqa: E402
import legacy_names  # noqa: E402

PLAN_HEADING = "## 분해안"
LOG_HEADING = "## 생성 기록"
HEAD_NAME = "머리"
VERDICT = "roadmap-entry: "
SAID = "[spec-distill] "


class InternalError(Exception):
    pass


def _git(folder: str, *args: str) -> "tuple[int, str]":
    try:
        p = subprocess.run(["git", "-C", folder] + list(args), capture_output=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        raise InternalError("git 을 부르지 못했다: %s" % exc)
    return p.returncode, p.stdout.decode("utf-8", "replace")


def _split_path(path: str) -> "tuple[str, str]":
    real = os.path.realpath(path)
    return os.path.dirname(real), os.path.basename(real)


def commit_state(path: str) -> str:
    """'never' HEAD 에 없다(스테이지만 했거나 추적되지 않는다) · 'dirty' 커밋하지 않은 변경 · 'clean'."""
    folder, name = _split_path(path)
    rc, _ = _git(folder, "cat-file", "-e", "HEAD:./" + name)
    if rc != 0:
        return "never"
    rc, out = _git(folder, "status", "--porcelain", "--", name)
    if rc != 0:
        raise InternalError("git status 가 실패했다: %s" % path)
    return "dirty" if out.strip() else "clean"


def sections(text: str) -> "list[tuple[str, list[str]]]":
    """(제목 줄, 본문 줄들) — 첫 절 앞은 제목 줄이 빈 글자인 한 칸이다. 제목은 `## ` 로 시작하는 줄."""
    # 코드 펜스를 알지 못한다 — 끝내기 커밋 펜스의 awk 판독(줄 머리 `## `)과 같은 규칙이다.
    out: "list[tuple[str, list[str]]]" = [("", [])]
    for ln in text.split("\n"):
        if ln.startswith("## "):
            out.append((ln.rstrip(), []))
        else:
            out[-1][1].append(ln)
    return out


def outside_two_sections(head_text: str, work_text: str) -> "list[str]":
    """두 절(분해안 · 생성 기록)을 떼고 남은 글이 다르면 다른 절의 이름들. 같으면 빈 목록.
    줄바꿈 꼴(CRLF · LF)과 절 끝의 빈 줄은 견주지 않는다 — 작업 트리는 줄바꿈을 접어 읽고, 마지막 절 뒤에
    새 절을 빈 줄 없이 붙이면 끝 줄바꿈 뒤의 빈 칸이 새 절로 옮겨 갈 뿐 앞 절의 글자는 그대로다."""
    def kept(text: str) -> "dict[str, str]":
        bodies: "dict[str, str]" = {}
        for title, body in sections(text.replace("\r\n", "\n")):
            if title in (PLAN_HEADING, LOG_HEADING):
                continue
            while body and body[-1] == "":
                body = body[:-1]
            bodies[title] = bodies.get(title, "") + "\n".join(body) + "\x00"
        return bodies

    a, b = kept(head_text), kept(work_text)
    names = []
    for title in list(a) + [t for t in b if t not in a]:
        if a.get(title) != b.get(title):
            names.append(title or HEAD_NAME)
    return names


def resume_what(state_text: str) -> "list[str]":
    found = []
    for title, body in sections(state_text):
        if title == PLAN_HEADING and any(ln.lstrip().startswith("|") for ln in body):
            found.append("분해안 표")
        elif title == LOG_HEADING and any(ln.strip() for ln in body):
            found.append("생성 기록")
    return found


def roadmap_path(brief_text: str) -> str:
    """§7 첫 `분해됨 — ` 줄의 값 — 끝내기 커밋 펜스의 awk 판독과 같은 규칙."""
    in7 = False
    for ln in brief_text.split("\n"):
        if ln.startswith("## 7."):
            in7 = True
            continue
        if not in7:
            continue
        if ln.startswith("## "):
            return ""
        s = ln.lstrip(" \t")
        if s.startswith("- "):
            s = s[2:]
        if s.startswith("`"):
            s = s[1:]
        if s.startswith(SPLIT_LINE_PREFIX):
            val = s[len(SPLIT_LINE_PREFIX):]
            return val.split("`", 1)[0].rstrip(" \t")
    return ""


def _run(cmd: "list[str]") -> "tuple[int, str]":
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        raise InternalError("하위 프로세스를 부르지 못했다: %s" % exc)
    return p.returncode, p.stdout.decode("utf-8", "replace")


def _run_err(cmd: "list[str]") -> "tuple[int, str, str]":
    """_run 과 같되 stderr 도 돌려준다 — 하위 스크립트가 stderr 에 싣는 사유 · 해결 안내를 STOP 사유에 옮길 때 쓴다."""
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        raise InternalError("하위 프로세스를 부르지 못했다: %s" % exc)
    return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")


def _first_line(out: str, prefix: str) -> "str | None":
    for ln in out.split("\n"):
        if ln.startswith(prefix):
            return ln
    return None


def _last_said(err: str) -> str:
    """repo_defaults.py 가 stderr 에 낸 `[spec-distill] ` 줄 가운데 마지막 것(접두를 뗀 글) — 거절 사유는 「값의 출처」 줄 뒤에 온다."""
    said = [ln[len(SAID):].strip() for ln in err.split("\n") if ln.startswith(SAID)]
    return said[-1] if said else ""


def _read(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise InternalError("읽지 못했다: %s (%s)" % (path, exc))


def run(brief: str) -> int:
    brief = os.path.abspath(brief)
    if not brief.endswith(".md") or not os.path.isfile(brief):
        print("[roadmap_draft_entry] --brief 는 있는 .md 파일이어야 한다: %s" % brief, file=sys.stderr)
        return 2
    folder = os.path.dirname(os.path.realpath(brief))
    rc, top = _git(folder, "rev-parse", "--show-toplevel")
    top = top.strip()
    if rc != 0 or not top:
        print("[roadmap_draft_entry] git 저장소가 아니다: %s" % folder, file=sys.stderr)
        return 2
    audit, state = legacy_names.siblings(brief)

    rc, out = _run([sys.executable, str(HERE / "raw_source.py"), "locate", "--interview", brief, "--absolute"])
    raw_line = _first_line(out, "raw-source: ")
    if raw_line is None:
        raise InternalError("raw_source.py locate 가 판결 줄을 내지 않았다 (rc %d)" % rc)
    print(raw_line)

    stops: "list[str]" = []

    # 결과물이 의도 폴더 바로 아래인가 — 로드맵 잡기의 커밋 펜스가 늦게 거는 같은 판정을 진입에서 먼저 본다.
    # 폴더만 물리 경로로 풀고 이름은 그대로 넘긴다(해결자는 레포 루트를 물리 경로로 견준다).
    given = os.path.join(os.path.realpath(os.path.dirname(brief)), os.path.basename(brief))
    crc, _, cerr = _run_err([sys.executable, str(HERE / "repo_defaults.py"), "check-path", legacy_names.SETTING_KEY,
                             given, "--root", top])
    if crc == 3:
        stops.append("결과물이 의도 폴더 바로 아래가 아니다: %s"
                     % (_last_said(cerr) or "repo_defaults.py check-path 가 사유 없이 거절했다"))
    elif crc != 0:
        raise InternalError("repo_defaults.py check-path 가 판정하지 못했다 (rc %d): %s" % (crc, cerr.strip()))

    def check(path: str, subject_never: str, subject_dirty: "str | None") -> str:
        st = commit_state(path)
        if st == "never":
            stops.append("%s 커밋된 적이 없다: %s" % (subject_never, path))
        elif st == "dirty" and subject_dirty:
            stops.append("%s 커밋하지 않은 변경이 있다: %s" % (subject_dirty, path))
        return st

    check(brief, "결과물이", "결과물에")
    check(audit, "audit 이", "audit 에")
    state_status = check(state, "상태 파일이", None)  # 커밋 뒤 변경은 아래에서 두 절 안 · 밖으로 가른다
    state_text = _read(state) if os.path.isfile(state) else ""
    if state_status != "never" and not os.path.isfile(state):
        stops.append("상태 파일이 커밋된 뒤 작업 트리에서 지워졌다: %s" % state)
    elif state_status != "never":
        sfolder, sname = _split_path(state)
        hrc, head_text = _git(sfolder, "show", "HEAD:./" + sname)
        if hrc != 0:
            raise InternalError("HEAD 의 상태 파일을 읽지 못했다: %s" % state)
        names = outside_two_sections(head_text, state_text)
        if names:
            stops.append("상태 파일의 커밋 뒤 변경이 두 절 밖에 있다: %s" % " · ".join(names))

    if raw_line.startswith("raw-source: FOUND "):
        raw_audit = raw_line[len("raw-source: FOUND "):]
        raw_seed = raw_audit[:-len(".audit.md")] + ".md" if raw_audit.endswith(".audit.md") else ""
        for p in (raw_audit, raw_seed):
            if p and os.path.exists(p):
                check(p, "원자료가", "원자료에")

    brief_text = _read(brief)
    if not payload_is_split(brief_text):
        stops.append("결과물 §7 에 분해됨 줄이 없다 — 나눌지는 컨텍스트 쌓기에서 정한다")
    else:
        rel = roadmap_path(brief_text)
        if rel:
            if os.path.isabs(rel):
                rel = os.path.relpath(os.path.realpath(rel), os.path.realpath(top))
            drc, dout, derr = _run_err([sys.executable, str(HERE / "repo_defaults.py"), "default-branch", "--root", top])
            default = dout.strip().split("\n")[0] if drc == 0 else ""
            if not default:
                why = next((ln.strip() for ln in derr.split("\n") if ln.strip()), "")
                stops.append("기본 브랜치를 확인하지 못했다: 기본 브랜치 판정이 실패했다(repo_defaults.py default-branch rc %d)%s"
                             % (drc, " — " + why if why else ""))
            else:
                vrc, _ = _git(top, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/%s" % default)
                if vrc != 0:
                    stops.append("기본 브랜치를 확인하지 못했다: origin/%s 참조가 없다" % default)
                else:
                    crc, _ = _git(top, "cat-file", "-e", "origin/%s:%s" % (default, rel))
                    if crc == 0:
                        stops.append("이 결과물의 로드맵이 이미 기본 브랜치에 있다: %s — 고치려면 재분해 절차다" % rel)

    rc, out = _run([sys.executable, str(HERE / "roadmap_write.py"), "check", "--brief", brief, "--audit", audit])
    risk = _first_line(out, "brief-risk: ")
    if risk is None:
        raise InternalError("roadmap_write.py check 가 brief-risk 줄을 내지 않았다 (rc %d)" % rc)
    if risk.startswith("brief-risk: FAIL 못 읽었다"):
        stops.append("결과물이나 audit 을 읽지 못했다: %s" % risk[len("brief-risk: FAIL 못 읽었다"):].lstrip(": ").strip())
    elif risk.startswith("brief-risk: FAIL"):
        stops.append("결과물의 위험 줄 번호가 생성기 검사에 걸린다: %s" % risk[len("brief-risk: FAIL"):].strip())

    for reason in stops:
        print(VERDICT + "STOP " + reason)
    if stops:
        print(VERDICT + "STOP")
        return 1
    what = resume_what(state_text)
    if what:
        print(VERDICT + "RESUME " + " · ".join(what))
        print(VERDICT + "RESUME")
        return 0
    print(VERDICT + "OK")
    return 0


def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(prog="roadmap_draft_entry.py")
    ap.add_argument("--brief", required=True)
    args = ap.parse_args(argv)
    try:
        return run(args.brief)
    except InternalError as exc:
        print("[roadmap_draft_entry] %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
