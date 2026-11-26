#!/usr/bin/env python3
"""SKILL 의 bash 펜스를 표지(펜스 안의 글)로 뽑아 자리표를 채운다.

사용: skill_fence.py <SKILL> <표지> [--sub <옛 글> <새 글>]...
  표지를 담은 ```bash 펜스가 꼭 하나여야 한다 — 펜스 본문을 여는 줄의 들여쓰기만큼 걷어
  stdout 에 낸다. `--sub` 는 차례대로 글자 그대로 바꾼다(옛 글이 펜스에 없으면 rc 3 —
  자리표 글자가 바뀌어 채우지 못한 펜스를 돌리지 않는다).
  skill_fence.py <SKILL> <표지> --count — 표지를 담은 펜스 수만 낸다.
종료 코드: 0 · 2 사용법 · 3 표지 펜스가 하나가 아니거나 자리표가 없다.
"""
import re
import sys

OPEN = re.compile(r"^([ \t]*)```bash[ \t]*$")


def fences(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    out = []
    i = 0
    while i < len(lines):
        m = OPEN.match(lines[i])
        if not m:
            i += 1
            continue
        indent = m.group(1)
        body = []
        i += 1
        while i < len(lines) and lines[i].strip() != "```":
            line = lines[i]
            body.append(line[len(indent):] if line.startswith(indent) else line)
            i += 1
        out.append("\n".join(body) + "\n")
        i += 1
    return out


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    path, marker, rest = argv[0], argv[1], argv[2:]
    hits = [f for f in fences(path) if marker in f]
    if rest == ["--count"]:
        print(len(hits))
        return 0
    if len(hits) != 1:
        sys.stderr.write("표지 %r 를 담은 펜스가 %d 개다\n" % (marker, len(hits)))
        return 3
    body = hits[0]
    while rest:
        if len(rest) < 3 or rest[0] != "--sub":
            sys.stderr.write(__doc__)
            return 2
        old, new, rest = rest[1], rest[2], rest[3:]
        if old not in body:
            sys.stderr.write("자리표 %r 가 펜스에 없다\n" % old)
            return 3
        body = body.replace(old, new)
    sys.stdout.write(body)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
