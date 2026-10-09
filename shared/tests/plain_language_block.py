#!/usr/bin/env python3
"""규칙 블록 동일성 판정 — `test_plain_language_block.sh` 의 본체.

입력: 리포 루트 · 대상 목록 파일(한 줄에 리포 상대 경로 하나). 출력: `ok <msg>` · `no <msg>` 줄.
대상마다 넷을 잰다 — 표시 줄이 각각 정확히 한 번 · 시작 표시 줄이 H1(frontmatter 뒤 첫 `# ` 줄)
다음의 첫 비어 있지 않은 줄 · 시작이 끝보다 앞 · 표시 줄 사이(포함) 바이트가 정본과 같다.
H1 은 블록 자신의 `## ` 제목으로 만족되지 않는다 — `# ` 다음 글자가 `#` 이 아닌 줄만 H1 이다.
"""
import io
import sys
from pathlib import Path

BEGIN = "<!-- plain-language:begin -->"
END = "<!-- plain-language:end -->"
CANON = "shared/style/plain-language.md"


def h1_index(lines):
    i = 0
    if lines and lines[0] == "---":
        try:
            i = lines.index("---", 1) + 1
        except ValueError:
            return None
    for j in range(i, len(lines)):
        if lines[j].startswith("# "):
            return j
    return None


def check(root, rel, canon):
    try:
        text = io.open(str(root / rel), encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as e:
        return ["no %s: 읽지 못했다 (%s)" % (rel, e.__class__.__name__)]
    lines = text.split("\n")
    nb, ne = lines.count(BEGIN), lines.count(END)
    if nb != 1 or ne != 1:
        return ["no %s: 표시 줄이 시작 %d개 · 끝 %d개다 — 정확히 한 쌍이어야 한다" % (rel, nb, ne)]
    b, e = lines.index(BEGIN), lines.index(END)
    if e < b:
        return ["no %s: 끝 표시 줄이 시작보다 앞이다" % rel]
    h = h1_index(lines)
    if h is None:
        return ["no %s: frontmatter 뒤 H1(`# ` 줄)이 없다" % rel]
    first = next((k for k in range(h + 1, len(lines)) if lines[k].strip()), None)
    if first != b:
        return ["no %s: 블록이 H1 바로 다음이 아니다 (H1 L%d · 첫 비어 있지 않은 줄 L%s · 시작 표시 L%d)"
                % (rel, h + 1, first + 1 if first is not None else "-", b + 1)]
    region = "\n".join(lines[b:e + 1]) + "\n"
    if region != canon:
        return ["no %s: 블록 바이트가 정본(%s)과 다르다" % (rel, CANON)]
    return ["ok %s: 블록이 H1 바로 다음에 있고 정본과 같다" % rel]


def main(argv):
    root = Path(argv[1])
    targets = [l for l in io.open(argv[2], encoding="utf-8").read().split("\n") if l]
    try:
        canon = io.open(str(root / CANON), encoding="utf-8").read()
    except OSError:
        print("no 정본 %s 이 없다" % CANON)
        return 0
    cl = canon.split("\n")
    if cl.count(BEGIN) != 1 or cl.count(END) != 1 or not canon.startswith(BEGIN + "\n") or not canon.endswith(END + "\n"):
        print("no 정본 %s 이 표시 줄 한 쌍으로 시작하고 끝나는 블록 하나가 아니다" % CANON)
        return 0
    if not targets:
        print("no 대상이 0개다 — 글롭이 아무것도 고르지 않았다(공허한 통과 방지)")
        return 0
    print("ok 대상 %d개를 구조에서 도출했다" % len(targets))
    for rel in targets:
        for line in check(root, rel, canon):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
