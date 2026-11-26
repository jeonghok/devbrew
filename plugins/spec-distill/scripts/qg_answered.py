#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_answered.py — 지휘자의 리뷰 기록 파일에서 qg 의 `--answered` 가 읽는 「이미 답한 것」 파일을 만든다.

사용:
  qg_answered.py --roadmap <로드맵 파일의 레포 상대경로> --ref <ref> [--ref <ref> ...]
                 --out <파일> --notices <파일> [--repo <레포 루트, 기본 .>]

--ref 의 차례가 앞섬이다(같은 열쇠는 앞 자리 것을 싣는다). 자리마다 `<로드맵 폴더>/reviews/` 의
`.md` 를 git 에서 읽는다(허용 git 하위 명령은 GIT_ALLOWED 뿐, 인자 목록 · 시간 상한).
기록 하나를 읽지 못하면 그 이름의 대상(에픽 번호 · `roadmap`)의 답은 어느 자리 것도 싣지 않는다 —
읽지 못한 기록이 그 답을 뒤집었을 수 있다. 이름이 틀 밖이면 대상을 가릴 수 없어 어느 답도 싣지 않는다.
출력: 알림 줄을 먼저 stderr 에 낸 뒤, --out 에 `contract: 1` · `entries`(답이 없으면 `entries: []`),
      그다음 --notices 에 같은 알림 줄(없으면 빈 파일)을 쓴다 — 둘 다 tmp + os.replace.
종료 코드: 0 정상(알림이 있어도) · 2 사용법 · 3 답 파일을 쓰지 못함 · 4 답 파일은 썼는데 알림 파일을
          쓰지 못함 · 5 PyYAML 이 없음(답 파일 · 알림 파일을 쓰지 않는다) — 3 · 4 · 5 는 stderr 끝 줄 하나.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qg_review_file import TEAM_TARGET  # noqa: E402 — 상태 파일의 team 대상 꼴과 같은 정의

try:
    import yaml
except ImportError:  # 지휘 절차가 rc 5 를 「답 없이 보낸다」 로 다룬다
    yaml = None

GIT_ALLOWED = frozenset({"rev-parse", "ls-tree", "show"})
GIT_TIMEOUT = 30
CONTRACT_OUT = 1
RECORD_CONTRACTS = (2, 3)
ANSWERS = ("의도다", "잘못 골랐다")
QUIET_ANSWERS = ("지금은 모르겠다", "답하지 않음", "묻지 않음(상한 넘어 남김)")
NO_PRIOR = ("없음", "-", "")
NO_TIME = "-"
ROUTES = ("이 에픽 안에서 고친다", "새 일의 씨앗", "재분해 신호")
SITE_ROUTES = {
    "spec": "이 에픽 안에서 고친다",
    "premerge": "이 에픽 안에서 고친다",
    "recheck": "이 에픽 안에서 고친다",
    "end": "새 일의 씨앗",
    "asked": "이 에픽 안에서 고친다",
}
CONTENT_KEYS = ("id", "answer", "question", "observation", "answered_at", "route", "record")
OBS_INDENT = "  "
HEADING = "## 질문"
SEP = " · "
TIME_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}|-")
NAME_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}-(?P<target>[A-Z][0-9]+[a-z]?|roadmap)-"
                     r"(?:spec|(?:premerge|recheck)-(?:pr[0-9]+|" + TEAM_TARGET + r")|end|asked)"
                     r"(?:-[0-9]+)?\.md")
ALL_TARGETS = None
NOTICE_FAIL = "[qg_answered] 알림 파일을 쓰지 못했다 — 알림은 위 줄뿐이다"
NO_YAML = "[qg_answered] PyYAML 이 없다 — 답 없이 보낸다"


class Unreadable(Exception):
    """기록 파일 하나를 읽지 못한다 — 그 파일과 같은 대상의 항목은 하나도 싣지 않는다.
    인자는 사유(디버깅용) — 알림 글에는 싣지 않는다."""


def _git(repo, *args):
    if args[0] not in GIT_ALLOWED:
        raise ValueError("허용하지 않는 git 명령: %s" % args[0])
    try:
        p = subprocess.run(["git", *args], cwd=str(repo), capture_output=True,
                           timeout=GIT_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired):
        return 1, b""
    return p.returncode, p.stdout


def _has_control(text):
    for ch in text:
        o = ord(ch)
        if (o < 32 and ch not in "\t\n") or o == 127:
            return True
    return False


def _split_head(text):
    lines = text.split("\n")
    if lines[0] != "---":
        raise Unreadable()
    for i in range(1, len(lines)):
        if lines[i] == "---":
            try:
                head = yaml.safe_load("\n".join(lines[1:i]))
            except Exception:  # noqa: BLE001 — YAML 이 아니면 읽지 못한 기록
                raise Unreadable()
            if not isinstance(head, dict):
                raise Unreadable()
            return head, lines[i + 1:]
    raise Unreadable()


def _field(line):
    """`- 이름: 값` 한 줄이면 (이름, 값), 아니면 None."""
    if not line.startswith("- "):
        return None
    rest = line[2:]
    cut = rest.find(":")
    if cut <= 0:
        return None
    return rest[:cut], rest[cut + 1:].strip()


def _parse_sections(body):
    """절들을 [(번호, {칸 이름: 값})] 로. 관찰은 들여쓴 줄을 모은 목록."""
    sections = []
    seen_nums = set()
    cur = None
    in_obs = False
    for line in body:
        if line == HEADING or line.startswith(HEADING + " "):
            num = line[len(HEADING) + 1:]
            if not (num.isascii() and num.isdigit()):
                raise Unreadable()
            if num in seen_nums:
                raise Unreadable()
            seen_nums.add(num)
            cur = (num, {})
            sections.append(cur)
            in_obs = False
            continue
        if line.startswith("## ") or line.startswith("# "):
            cur = None
            in_obs = False
            continue
        if cur is None:
            continue
        if in_obs and line.startswith(OBS_INDENT):
            cur[1]["관찰"].append(line[len(OBS_INDENT):])
            continue
        in_obs = False
        parsed = _field(line)
        if parsed is None:
            continue
        name, value = parsed
        if name in cur[1]:
            raise Unreadable()
        if name == "관찰":
            cur[1]["관찰"] = [value] if value else []
            in_obs = True
        else:
            cur[1][name] = value
    return sections


def _prior_key(value):
    """`<답> · <답한 때> · <열쇠 또는 정체> · <까닭>` 의 셋째 칸. 칸마다 제 꼴로 읽는다 — 첫 칸은 ANSWERS
    가운데 하나, 둘째 칸은 TIME_RE, 끝 칸(오른쪽에서 뗀 것)은 까닭이고 그 사이가 열쇠 또는 정체다
    (정체에는 ` · ` 가 들어도 된다). 꼴이 아니면 열쇠를 짐작하지 않고 Unreadable.
    「없음」 · `-` · 빈 값은 앞 답이 없다."""
    if value in NO_PRIOR:
        return None
    for answer in ANSWERS:
        if value.startswith(answer + SEP):
            rest = value[len(answer) + len(SEP):]
            break
    else:
        raise Unreadable("전에 한 답의 칸이 꼴 밖이다")
    at, sep, rest = rest.partition(SEP)
    if not sep or not TIME_RE.fullmatch(at):
        raise Unreadable("전에 한 답의 칸이 꼴 밖이다")
    key, sep, why = rest.rpartition(SEP)
    if not sep or not key or not why:
        raise Unreadable("전에 한 답의 칸이 꼴 밖이다")
    return key


def parse_record(text, name, record_path):
    """(항목들, 앞 답의 열쇠들, 틀 밖의 답 [(번호, 값)]) — 읽지 못하면 Unreadable."""
    if _has_control(text):
        raise Unreadable()
    head, body = _split_head(text)
    contract = head.get("contract")
    if head.get("type") != "roadmap-review" or type(contract) is not int \
            or contract not in RECORD_CONTRACTS:
        raise Unreadable()
    site = head.get("site")
    entries = []
    superseded = []
    odd = []
    for num, fields in _parse_sections(body):
        answer = fields.get("답")
        at = fields.get("답한 때", "") or NO_TIME
        if not TIME_RE.fullmatch(at):
            raise Unreadable("답한 때가 꼴 밖이다")
        if "전에 한 답" in fields:
            prior = _prior_key(fields["전에 한 답"])
            # 새 답이 넘기는 값일 때만 앞 답을 뺀다 — 넘기지 않는 값 · 틀 밖의 값은 앞 답을 그대로 둔다
            if prior is not None and answer in ANSWERS:
                superseded.append(prior)
        if answer not in ANSWERS:
            if answer is not None and answer not in QUIET_ANSWERS:
                odd.append((num, answer))
            continue
        if answer == "의도다":
            route = "-"
        elif "행선" in fields:
            route = fields["행선"]
        elif contract == 2 and isinstance(site, str) and site in SITE_ROUTES:
            route = SITE_ROUTES[site]
        else:
            raise Unreadable()
        if answer == "잘못 골랐다" and route not in ROUTES:
            raise Unreadable()
        entries.append({
            "key": "%s#%s" % (name, num),
            "id": fields.get("정체", ""),
            "answer": answer,
            "question": fields.get("질문", ""),
            "observation": "\n".join(fields.get("관찰", [])),
            "answered_at": at,
            "route": route,
            "record": record_path,
        })
    return entries, superseded, odd


def _is_ctl(ch):
    return ord(ch) < 32 or ord(ch) == 127


def _name_ok(name):
    return (name.endswith(".md") and len(name) > 3 and "/" not in name and "#" not in name
            and SEP not in name and not any(_is_ctl(c) for c in name))


def _target(name):
    """기록 이름 틀 `<YYYY-MM-DD>-<대상>-<자리>[-<n>].md` 의 대상(에픽 번호 · `roadmap`), 틀 밖이면 None."""
    if not _name_ok(name):
        return None
    m = NAME_RE.fullmatch(name)
    return m.group("target") if m else None


def _esc(text):
    """알림 한 줄에 싣는 글(경로 · ref · 답 값)의 C0 제어 글자(줄 나눔 \\n · \\r · 탭 포함)와 DEL 을
    \\xNN 으로 바꾼다. 그 밖의 글자(C1 · U+2028 같은 유니코드 줄 나눔 글자)는 그대로 둔다."""
    return "".join("\\x%02x" % ord(c) if _is_ctl(c) else c for c in text)


def read_ref(repo, ref, folder):
    """한 자리의 기록들 [(표시, 이름, 경로, 글 | None)] 와 읽지 못한 자리 표시(없으면 None)."""
    place = _esc("%s:%s/" % (ref, folder))
    if not ref or ref.startswith("-"):
        return [], place
    rc, out = _git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    sha = out.decode("utf-8", "replace").strip()
    if rc != 0 or not sha:
        return [], place
    rc, out = _git(repo, "ls-tree", "-z", "--full-tree", "--name-only", sha, "--", folder + "/")
    if rc != 0:
        return [], place
    found = []
    for raw in sorted(p for p in out.split(b"\0") if p):
        path = raw.decode("utf-8", "replace")
        name = path.rsplit("/", 1)[-1]
        if not name.endswith(".md"):
            continue
        shown = _esc("%s:%s" % (ref, path))
        rc, blob = _git(repo, "show", "%s:%s" % (sha, path))
        text = None
        if rc == 0:
            try:
                text = blob.decode("utf-8")
            except UnicodeDecodeError:
                text = None
        found.append((shown, name, path, text))
    return found, None


def collect(repo, roadmap, refs):
    folder = roadmap.rsplit("/", 1)[0] + "/reviews" if "/" in roadmap else "reviews"
    unreadable = []
    blocked = set()  # 읽지 못한 기록의 대상 — ALL_TARGETS 면 모든 대상
    per_file = []
    odd_answers = []
    for ref in refs:
        found, bad_place = read_ref(repo, ref, folder)
        if bad_place is not None:
            unreadable.append(bad_place)
        for shown, name, path, text in found:
            target = _target(name)
            if target is None:
                unreadable.append(shown)
                blocked.add(ALL_TARGETS)
                continue
            if text is None:
                unreadable.append(shown)
                blocked.add(target)
                continue
            try:
                entries, prior, odd = parse_record(text, name, path)
            except Unreadable:
                unreadable.append(shown)
                blocked.add(target)
                continue
            per_file.append((target, entries, prior))
            for num, value in odd:
                odd_answers.append("%s 질문 %s 「%s」" % (shown, num, _esc(value)))
    superseded = set()
    for _target_of, _entries, prior in per_file:
        superseded.update(prior)
    kept = {}
    order = []
    conflicts = 0
    for target, entries, _prior in per_file:
        if ALL_TARGETS in blocked or target in blocked:
            continue
        for entry in entries:
            if entry["key"] in superseded:
                continue
            first = kept.get(entry["key"])
            if first is None:
                kept[entry["key"]] = entry
                order.append(entry["key"])
            elif any(first[k] != entry[k] for k in CONTENT_KEYS):
                conflicts += 1
    return [kept[k] for k in order], unreadable, conflicts, odd_answers


def _atomic_write(path, text):
    """tmp 에 다 쓴 뒤 os.replace — 실패하면 tmp 를 지우고 다시 던진다(반쯤 쓴 파일이 남지 않는다)."""
    tmp = "%s.tmp.%d" % (path, os.getpid())
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _why(exc):
    return getattr(exc, "strerror", None) or type(exc).__name__


def main(argv=None):
    ap = argparse.ArgumentParser(prog="qg_answered.py")
    ap.add_argument("--roadmap", required=True)
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--out", required=True)
    ap.add_argument("--notices", required=True)
    ap.add_argument("--repo", default=".")
    args = ap.parse_args(argv)
    road = args.roadmap
    if not args.ref or not road or road.startswith("/") or ".." in road.split("/"):
        print("[qg_answered] 사용법: --ref 는 하나 이상, --roadmap 은 .. 없는 레포 상대경로",
              file=sys.stderr)
        return 2
    if yaml is None:
        print(NO_YAML, file=sys.stderr)
        return 5
    entries, unreadable, conflicts, odd_answers = collect(args.repo, road, args.ref)
    notices = []
    if unreadable:
        notices.append("읽지 못한 기록 %d개: %s" % (len(unreadable), " · ".join(unreadable)))
    if conflicts:
        notices.append("열쇠가 같은데 내용이 다른 기록 %d개" % conflicts)
    if odd_answers:
        notices.append("답이 틀의 값 밖이라 넘기지 않은 질문 %d개: %s"
                       % (len(odd_answers), " · ".join(odd_answers)))
    # 알림 줄은 파일을 쓰기 전에 화면에 먼저 낸다 — 뒤의 쓰기가 실패해도 사라지지 않는다
    for n in notices:
        print(n, file=sys.stderr)
    sys.stderr.flush()
    doc = yaml.safe_dump({"contract": CONTRACT_OUT, "entries": entries},
                         allow_unicode=True, sort_keys=False, width=1000000)
    try:
        _atomic_write(args.out, doc)
    except (OSError, UnicodeError) as exc:
        print("[qg_answered] 출력 파일을 쓰지 못했다 — %s" % _why(exc), file=sys.stderr)
        return 3
    try:
        _atomic_write(args.notices, "".join(n + "\n" for n in notices))
    except (OSError, UnicodeError):
        print(NOTICE_FAIL, file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
