#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_answered.py — 지휘자의 리뷰 기록 파일에서 qg 의 `--answered` 가 읽는 「이미 답한 것」 파일을 만든다.

사용:
  qg_answered.py --roadmap <로드맵 파일의 레포 상대경로> --ref <ref> [--ref <ref> ...]
                 --out <파일> --notices <파일> [--repo <레포 루트, 기본 .>]

--ref 의 차례가 앞섬이다(같은 열쇠는 앞 자리 것을 싣는다). 자리마다 `<로드맵 폴더>/reviews/` 의
`.md` 를 git 에서 읽는다(허용 git 하위 명령은 GIT_ALLOWED 뿐, 인자 목록 · 시간 상한).
출력: --out 에 `contract: 1` · `entries`(답이 없으면 `entries: []`)를 tmp + os.replace 로 쓴다.
      --notices 에 알림 줄(없으면 빈 파일) — 같은 줄을 stderr 에도 낸다.
종료 코드: 0 정상(알림이 있어도) · 2 사용법 · 3 출력 파일을 쓰지 못함(stderr 한 줄).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

import yaml

GIT_ALLOWED = frozenset({"rev-parse", "ls-tree", "show"})
GIT_TIMEOUT = 30
CONTRACT_OUT = 1
RECORD_CONTRACTS = (2, 3)
ANSWERS = ("의도다", "잘못 골랐다")
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


class Unreadable(Exception):
    """기록 파일 하나를 읽지 못한다 — 그 파일의 항목은 하나도 싣지 않는다."""


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
    """`<답> · <답한 때> · <열쇠 또는 정체> · <까닭>` 의 셋째 칸 — 앞 두 칸은 왼쪽에서, 끝 칸은 오른쪽에서
    떼고 가운데를 열쇠로 본다(정체에 ` · ` 가 들어도 읽는다)."""
    if value == "없음":
        return None
    head = value.split(" · ", 2)
    if len(head) != 3:
        raise Unreadable()
    rest = head[2].rsplit(" · ", 1)
    if len(rest) != 2:
        raise Unreadable()
    return rest[0]


def parse_record(text, name, record_path):
    """(항목들, 앞 답의 열쇠들) — 읽지 못하면 Unreadable."""
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
    for num, fields in _parse_sections(body):
        if "전에 한 답" in fields:
            prior = _prior_key(fields["전에 한 답"])
            if prior is not None:
                superseded.append(prior)
        answer = fields.get("답")
        if answer not in ANSWERS:
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
            "answered_at": fields.get("답한 때", ""),
            "route": route,
            "record": record_path,
        })
    return entries, superseded


def _is_ctl(ch):
    return ord(ch) < 32 or ord(ch) == 127


def _name_ok(name):
    return (name.endswith(".md") and len(name) > 3 and "/" not in name and "#" not in name
            and not any(_is_ctl(c) for c in name))


def _esc(text):
    """알림 한 줄에 싣는 경로의 제어 글자를 \\xNN 으로 바꾼다."""
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
    per_file = []
    for ref in refs:
        found, bad_place = read_ref(repo, ref, folder)
        if bad_place is not None:
            unreadable.append(bad_place)
        for shown, name, path, text in found:
            if text is None or not _name_ok(name):
                unreadable.append(shown)
                continue
            try:
                per_file.append(parse_record(text, name, path))
            except Unreadable:
                unreadable.append(shown)
    superseded = set()
    for _entries, prior in per_file:
        superseded.update(prior)
    kept = {}
    order = []
    conflicts = 0
    for entries, _prior in per_file:
        for entry in entries:
            if entry["key"] in superseded:
                continue
            first = kept.get(entry["key"])
            if first is None:
                kept[entry["key"]] = entry
                order.append(entry["key"])
            elif any(first[k] != entry[k] for k in CONTENT_KEYS):
                conflicts += 1
    return [kept[k] for k in order], unreadable, conflicts


def _atomic_write(path, text):
    tmp = "%s.tmp.%d" % (path, os.getpid())
    try:
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


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
    entries, unreadable, conflicts = collect(args.repo, road, args.ref)
    notices = []
    if unreadable:
        notices.append("읽지 못한 기록 %d개: %s" % (len(unreadable), " · ".join(unreadable)))
    if conflicts:
        notices.append("열쇠가 같은데 내용이 다른 기록 %d개" % conflicts)
    doc = yaml.safe_dump({"contract": CONTRACT_OUT, "entries": entries},
                         allow_unicode=True, sort_keys=False, width=1000000)
    try:
        _atomic_write(args.out, doc)
        _atomic_write(args.notices, "".join(n + "\n" for n in notices))
    except OSError as exc:
        print("[qg_answered] 출력 파일을 쓰지 못했다 — %s" % exc.strerror, file=sys.stderr)
        return 3
    for n in notices:
        print(n, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
