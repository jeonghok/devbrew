#!/usr/bin/env python3
"""리뷰어 칸 사본의 끝 값과 here-doc 끝 표지 값을 내고, 응답을 끝 값과 견준다.

명령:
  hex                                   소문자 16진수 8자 한 줄
  attach <원본> <사본>                  원본 + 끝 줄 `qg-slot-end: <16 hex>` 을 사본에 쓴다
  split <리뷰 diff> <사본> -- <경로>... 경로들의 `diff --git` 조각만 원본 차례로 + 끝 줄
  check --response <응답> --slot <사본>...
                                        칸마다 끝 값이 응답에 있으면 `ok`, 아니면 `fail: <사유>`
  check-reviewer --rd <RD> --rv <RV> --reviewer <이름>
                                        그 리뷰어의 묶음 · 시도를 짝지어 묶음마다 한 줄 + 리뷰어 한 줄
종료 코드: 0 성공 · 1 대조 실패 · 2 사용법 · 4 읽기/쓰기 실패
"""
from __future__ import annotations

import argparse
import os
import re
import secrets
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import nofollow_write  # noqa: E402

EXIT_OK = 0
EXIT_FAIL = 1
EXIT_USAGE = 2
EXIT_IO = 4

END_PREFIX = "qg-slot-end: "


class IoFail(Exception):
    """읽기 · 쓰기 실패 — 사유와 경로를 싣는다."""

    def __init__(self, reason, path):
        Exception.__init__(self, reason)
        self.reason = reason
        self.path = path


def new_hex(nbytes: int) -> str:
    return secrets.token_hex(nbytes)


def _read_bytes(path) -> bytes:
    try:
        with open(path, "rb") as fh:
            return fh.read()
    except OSError:
        raise IoFail("읽지 못했다", path)


def _write_slot(body: bytes, out) -> str:
    """body 끝에 끝 줄을 붙여 out 에 쓴다(마지막 성분의 링크를 따라가지 않는다). 값을 돌려준다."""
    value = new_hex(8)
    if body and not body.endswith(b"\n"):
        body += b"\n"
    body += (END_PREFIX + value + "\n").encode("ascii")
    try:
        nofollow_write.replace_bytes(str(out), body)
    except OSError:
        raise IoFail("쓰지 못했다", out)
    return value


def attach(src, out) -> str:
    return _write_slot(_read_bytes(src), out)


DIFF_HEAD = b"diff --git "


def _chunks(diff: bytes) -> list:
    """`diff --git ` 줄마다 조각 하나. 첫 머리 앞의 글은 버린다.

    줄은 `\n` 으로만 가른다 — 내용 줄 안의 `\r` 뒤 글자가 조각 머리로 읽히면 안 된다.
    """
    chunks = []
    for line in re.split(rb"(?<=\n)", diff):
        if not line:
            continue
        if line.startswith(DIFF_HEAD):
            chunks.append([line])
        elif chunks:
            chunks[-1].append(line)
    return chunks


_C_ESC = {"a": 7, "b": 8, "t": 9, "n": 10, "v": 11, "f": 12, "r": 13, '"': 34, "\\": 92}


def _unquote(text: str, start: int) -> tuple:
    """text[start] 의 `"` 에서 git 의 C 꼴 따옴표 글을 푼다. (경로, 닫는 따옴표 다음 자리)."""
    out = bytearray()
    i = start + 1
    while i < len(text):
        ch = text[i]
        if ch == '"':
            return out.decode("utf-8", "surrogateescape"), i + 1
        if ch == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt in _C_ESC:
                out.append(_C_ESC[nxt])
                i += 2
                continue
            octal = text[i + 1:i + 4]
            if len(octal) == 3 and all(c in "01234567" for c in octal):
                out.append(int(octal, 8) & 0xFF)
                i += 4
                continue
        out += ch.encode("utf-8", "surrogateescape")
        i += 1
    return None, len(text)


def _strip_b(path: str) -> str:
    return path[2:] if path.startswith("b/") else path


def _header_path(chunk: list, prefix: bytes):
    """머리 줄들(첫 `@@` · `--- ` 앞) 가운데 prefix 로 시작하는 줄의 경로."""
    for line in chunk[1:]:
        if line.startswith(b"@@") or line.startswith(b"--- "):
            break
        if line.startswith(prefix):
            text = line[len(prefix):].rstrip(b"\n").decode("utf-8", "surrogateescape")
            if text.startswith('"'):
                return _unquote(text, 0)[0]
            return text
    return None


def _chunk_path(chunk: list) -> str:
    """조각의 `b/` 쪽 경로."""
    rest = chunk[0][len(DIFF_HEAD):].rstrip(b"\n").decode("utf-8", "surrogateescape")
    if rest.endswith('"'):
        if rest.startswith('"'):
            pos = _unquote(rest, 0)[1] + 1
        else:
            pos = rest.find(' "b/') + 1
        if pos > 0:
            path = _unquote(rest, pos)[0]
            if path is not None:
                return _strip_b(path)
    elif rest.startswith('"'):
        pos = _unquote(rest, 0)[1]
        return _strip_b(rest[pos + 1:])
    renamed = _header_path(chunk, b"rename to ") or _header_path(chunk, b"copy to ")
    if renamed is not None:
        return renamed
    if rest.startswith("a/"):
        half = (len(rest) - 5) // 2
        same = rest[2:2 + half]
        if rest == "a/" + same + " b/" + same:
            return same
    if " b/" in rest:
        return rest.split(" b/", 1)[1]
    return rest


class NotInDiff(Exception):
    """목록 경로가 리뷰 diff 에 없다."""

    def __init__(self, path):
        Exception.__init__(self, path)
        self.path = path


def split(diff_path, out, paths: list) -> str:
    chunks = _chunks(_read_bytes(diff_path))
    found = [(_chunk_path(c), c) for c in chunks]
    have = set(p for p, _ in found)
    for want in paths:
        if want not in have:
            raise NotInDiff(want)
    wanted = set(paths)
    body = b"".join(b"".join(c) for p, c in found if p in wanted)
    return _write_slot(body, out)


UNREADABLE = "QG_INPUT_UNREADABLE:"
END_LINE_RE = re.compile(r"qg-slot-end: ([0-9a-f]{16})")
NO_VALUE = "끝 값 없음"
NOT_READ = "읽지 못함"
NO_RESPONSE = "응답 없음"


def slot_value(path) -> str | None:
    """칸 사본의 끝 줄이 `qg-slot-end: <16 hex>` 이면 그 값. 아니면(읽지 못함 포함) None."""
    try:
        data = _read_bytes(path)
    except IoFail:
        return None
    if data.endswith(b"\n"):
        data = data[:-1]
    last = data.rsplit(b"\n", 1)[-1].decode("ascii", "replace")
    m = END_LINE_RE.fullmatch(last)
    return m.group(1) if m else None


def check(response_text: str, slot_paths: list) -> str | None:
    """칸마다 끝 값이 응답 글 안에 있으면 None. 아니면 `끝 값 없음` · `읽지 못함`."""
    values = [slot_value(p) for p in slot_paths]
    if values and all(v is not None and v in response_text for v in values):
        return None
    if any(line.startswith(UNREADABLE) for line in response_text.splitlines()):
        return NOT_READ
    return NO_VALUE


def _read_response(path) -> str | None:
    try:
        return _read_bytes(path).decode("utf-8", "replace")
    except IoFail:
        return None


def _check_cli(rest: list) -> int:
    parser = argparse.ArgumentParser(prog="qg_nonce.py check")
    parser.add_argument("--response", required=True)
    parser.add_argument("--slot", required=True, nargs="+", action="extend")
    opts = parser.parse_args(rest)
    text = _read_response(opts.response)
    reason = NO_RESPONSE if text is None else check(text, opts.slot)
    if reason is None:
        print("ok")
        return EXIT_OK
    print("fail: " + reason)
    return EXIT_FAIL


REVIEWER_RE = re.compile(r"[a-z0-9-]+")


class NoSlots(Exception):
    """그 리뷰어의 칸 사본이 하나도 없다."""


class BadReviewer(ValueError):
    """리뷰어 이름이 `[a-z0-9-]+` 꼴 밖이다."""


def _tries(rd, reviewer: str) -> dict:
    """{(묶음, 시도): [칸 사본 경로…]}. 이름에 `-` 가 있어도 b · t · 칸은 오른쪽에서 고정된다."""
    pattern = re.compile(
        r"review-i1-slot-" + re.escape(reviewer)
        + r"-b([1-9][0-9]*)-t([1-9][0-9]*)-([a-z0-9_]+)\.txt")
    try:
        names = sorted(os.listdir(rd))
    except OSError:
        raise IoFail("읽지 못했다", rd)
    tries = {}
    for name in names:
        m = pattern.fullmatch(name)
        if m:
            key = (int(m.group(1)), int(m.group(2)))
            tries.setdefault(key, []).append(os.path.join(rd, name))
    return tries


def check_reviewer(rd, rv, reviewer) -> tuple:
    """(리뷰어 사유 또는 None, [(묶음, 사유 또는 None), …]). 응답 사본은 읽기만 한다."""
    if not REVIEWER_RE.fullmatch(reviewer):
        raise BadReviewer(reviewer)
    tries = _tries(rd, reviewer)
    if not tries:
        raise NoSlots(reviewer)
    bundles = {}
    for (b, t) in sorted(tries):
        resp = os.path.join(rv, "resp-%s-b%d-t%d.txt" % (reviewer, b, t))
        text = _read_response(resp)
        reason = NO_RESPONSE if text is None else check(text, tries[(b, t)])
        prev = bundles.get(b, NO_VALUE)
        bundles[b] = None if prev is None else reason
    rows = sorted(bundles.items())
    failed = [reason for _, reason in rows if reason is not None]
    return (failed[0] if failed else None), rows


def _check_reviewer_cli(rest: list) -> int:
    parser = argparse.ArgumentParser(prog="qg_nonce.py check-reviewer")
    parser.add_argument("--rd", required=True)
    parser.add_argument("--rv", required=True)
    parser.add_argument("--reviewer", required=True)
    opts = parser.parse_args(rest)
    try:
        reason, rows = check_reviewer(opts.rd, opts.rv, opts.reviewer)
    except BadReviewer:
        sys.stderr.write("[qg_nonce] 리뷰어 이름이 꼴 밖이다 — %s\n" % opts.reviewer)
        return EXIT_USAGE
    except NoSlots:
        sys.stderr.write("[qg_nonce] 칸 사본이 없다 — %s\n" % opts.reviewer)
        return EXIT_USAGE
    for b, r in rows:
        print("b%d: %s" % (b, "ok" if r is None else "fail: " + r))
    if reason is None:
        print("%s: ok" % opts.reviewer)
        return EXIT_OK
    print("%s: fail: %s" % (opts.reviewer, reason))
    return EXIT_FAIL


def _say_path(path: str) -> None:
    """경로 한 줄을 표준 출력에 — 명령줄에서 받은 바이트 그대로."""
    sys.stdout.flush()
    sys.stdout.buffer.write(os.fsencode(path) + b"\n")
    sys.stdout.buffer.flush()


def _usage() -> int:
    sys.stderr.write("[qg_nonce] 사용법이 맞지 않는다\n")
    return EXIT_USAGE


def main(argv: list) -> int:
    if not argv:
        return _usage()
    cmd, rest = argv[0], argv[1:]
    try:
        if cmd == "hex" and not rest:
            print(new_hex(4))
            return EXIT_OK
        if cmd == "attach" and len(rest) == 2:
            attach(rest[0], rest[1])
            _say_path(rest[1])
            return EXIT_OK
        if cmd == "split" and len(rest) >= 4 and rest[2] == "--":
            split(rest[0], rest[1], rest[3:])
            _say_path(rest[1])
            return EXIT_OK
        if cmd == "check":
            return _check_cli(rest)
        if cmd == "check-reviewer":
            return _check_reviewer_cli(rest)
    except NotInDiff as exc:
        sys.stderr.write("[qg_nonce] 리뷰 diff 에 없는 경로 — %s\n" % exc.path)
        return EXIT_IO
    except IoFail as exc:
        sys.stderr.write("[qg_nonce] %s — %s\n" % (exc.reason, exc.path))
        return EXIT_IO
    return _usage()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
