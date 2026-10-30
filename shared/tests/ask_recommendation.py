#!/usr/bin/env python3
"""질문 자리 추천 표시 전수 판정 — `test_ask_recommendation.sh` 의 본체.

입력: 리포 루트 · 후보 파일 목록(한 줄에 리포 상대 경로 하나) · 목록 tsv(`경로<TAB>종류<TAB>앵커<TAB>끝`).
출력: `ok <설명>` · `no <①|②|③|④> <경로>:<줄> <설명>` 줄. rc 0 = 판정 완료, rc 2 = 인자 · 파일 읽기 실패.

- 앵커는 그 파일에서 정확히 한 번 나오는 한 줄 안의 글자다. 범위는 끝이 있으면 앵커 시작부터 앵커 뒤
  첫 `끝` 의 끝까지, 끝이 비면 앵커가 든 문단(빈 줄 사이)이다.
- 질문 행(꼬리 · 지시 · 비움 · 출처꼬리)의 범위 안에 다른 행(떼기 제외)의 앵커 시작이 있으면 ② 다.
- 후보 줄(`AskUserQuestion` 이 있는 줄)은 어느 행의 앵커가 시작하는 줄이거나 어느 질문 행의 범위 안이어야 한다.
  언급 행은 앵커 줄에 `AskUserQuestion` 이 하나일 때만 그 줄을 덮는다(둘 이상이면 ①).
"""
import io
import re
import sys
from collections import namedtuple

TAIL_RE = re.compile(r"(?<!「)\((?:권장|Recommended)\)")
DIRECTIVE = "권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다"
EMPTY = "추천을 달지 않는다 — "
SOURCE = "추천)"
STRIP = "라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다"

TOOL = "AskUserQuestion"
QUESTION_KINDS = ("꼬리", "지시", "비움", "출처꼬리")
KINDS = QUESTION_KINDS + ("언급", "떼기")

Site = namedtuple("Site", "path kind anchor end lineno")


def load_sites(path):
    """목록 tsv 를 읽는다. 칸 수가 맞지 않는 줄도 Site 로 돌려 check 가 ② 로 알린다(조용히 버리지 않는다)."""
    sites = []
    with io.open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh.read().split("\n"), 1):
            line = raw.rstrip("\r")
            if not line.strip() or line.startswith("#"):
                continue
            cells = line.split("\t")
            if len(cells) == 3:
                cells.append("")
            if len(cells) != 4:
                # 칸이 맞지 않는 줄은 종류 None, 앵커 자리에 원래 줄(탭은 \t 로)을 담아 ② 사유에 그대로 보인다.
                sites.append(Site(cells[0], None, line.replace("\t", "\\t"), "", n))
                continue
            sites.append(Site(cells[0], cells[1], cells[2], cells[3], n))
    return sites


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def paragraph(text, offset):
    """offset 이 든 문단(빈 줄 사이)의 (시작, 끝) 오프셋."""
    lines = text.split("\n")
    starts = []
    pos = 0
    for ln in lines:
        starts.append(pos)
        pos += len(ln) + 1
    i = line_of(text, offset) - 1
    a = i
    while a > 0 and lines[a - 1].strip():
        a -= 1
    b = i
    while b + 1 < len(lines) and lines[b + 1].strip():
        b += 1
    return starts[a], starts[b] + len(lines[b])


def scope(text, site):
    """질문 범위 (시작, 끝) 오프셋. 실패면 ② 사유 문자열."""
    if site.kind not in KINDS:
        return "모르는 종류 「%s」" % site.kind
    if not site.anchor or "\n" in site.anchor:
        return "앵커가 비었다"
    n = text.count(site.anchor)
    if n == 0:
        return "앵커가 없다"
    if n > 1:
        return "앵커가 %d번 나온다" % n
    start = text.find(site.anchor)
    if not site.end:
        return paragraph(text, start)
    j = text.find(site.end, start + len(site.anchor))
    if j < 0:
        return "앵커 뒤에 끝 「%s」이 없다" % site.end
    return start, j + len(site.end)


def required(kind, body):
    """범위 글에 종류가 요구하는 글자가 있으면 None, 없으면 ③ 사유."""
    if kind == "꼬리" and not TAIL_RE.search(body):
        return "범위에 라벨 꼬리 「(권장)」 · 「(Recommended)」가 없다"
    if kind == "지시" and DIRECTIVE not in body:
        return "범위에 지시 문장이 없다"
    if kind == "비움":
        if EMPTY not in body:
            return "범위에 「%s」가 없다" % EMPTY.rstrip()
        if TAIL_RE.search(body):
            return "비움 범위에 라벨 꼬리가 있다"
    if kind == "출처꼬리" and SOURCE not in body:
        return "범위에 「%s」이 없다" % SOURCE
    if kind == "떼기" and STRIP not in body:
        return "범위에 뗌 문장이 없다"
    return None


def check(root, files, sites):
    out = []
    texts = {}
    for rel in files:
        with io.open("%s/%s" % (root, rel), encoding="utf-8") as fh:
            texts[rel] = fh.read()
    candidates = []
    for rel in files:
        for k, ln in enumerate(texts[rel].split("\n"), 1):
            if TOOL in ln:
                candidates.append((rel, k, ln))
    if not candidates:
        out.append("no ④ -:- 후보 줄이 0개다 — 글롭이 아무것도 고르지 않았다(공허한 통과 방지)")
        return out
    out.append("ok 후보 파일 %d개 · 후보 줄 %d개 · 목록 행 %d개" % (len(files), len(candidates), len(sites)))

    resolved = []  # (site, text, scope 또는 사유)
    for s in sites:
        if s.kind is None:
            resolved.append((s, None, "칸이 넷이 아니다(경로 · 종류 · 앵커 · 끝)"))
            continue
        text = texts.get(s.path)
        if text is None:
            try:
                with io.open("%s/%s" % (root, s.path), encoding="utf-8") as fh:
                    text = fh.read()
            except (OSError, UnicodeDecodeError):
                resolved.append((s, None, "파일이 없다(또는 읽지 못했다)"))
                continue
            texts[s.path] = text
        resolved.append((s, text, scope(text, s)))

    anchor_lines = set()
    mention_lines = set()
    anchor_starts = {}
    covered = {}
    for s, text, sc in resolved:
        if text is None or s.kind not in KINDS or not s.anchor or text.count(s.anchor) != 1:
            continue
        a = text.find(s.anchor)
        (mention_lines if s.kind == "언급" else anchor_lines).add((s.path, line_of(text, a)))
        anchor_starts.setdefault(s.path, []).append((a, s))
        if s.kind in QUESTION_KINDS and not isinstance(sc, str):
            covered.setdefault(s.path, []).append(sc)

    for s, text, sc in resolved:
        if s.kind is None:
            out.append("no ② %s:- 줄 「%s」 (목록 L%d): %s" % (s.path, s.anchor, s.lineno, sc))
            continue
        known = text is not None and s.anchor and s.anchor in text
        where = "%s:%s" % (s.path, line_of(text, text.find(s.anchor)) if known else "-")
        label = "%s 「%s」 (목록 L%d)" % (s.kind, s.anchor, s.lineno)
        if isinstance(sc, str):
            out.append("no ② %s %s: %s" % (where, label, sc))
            continue
        assert text is not None  # 범위가 성립했으면 글을 읽은 것이다
        if s.kind in QUESTION_KINDS:
            crossed = [o for a, o in anchor_starts.get(s.path, [])
                       if o is not s and o.kind != "떼기" and sc[0] <= a < sc[1]]
            if crossed:
                o = crossed[0]
                out.append("no ② %s %s: 범위가 다른 행의 앵커 「%s」(목록 L%d)를 넘는다" % (where, label, o.anchor, o.lineno))
                continue
        why = required(s.kind, text[sc[0]:sc[1]])
        if why:
            out.append("no ③ %s %s: %s" % (where, label, why))
            continue
        out.append("ok %s %s" % (where, label))

    for rel, k, ln in candidates:
        if (rel, k) in anchor_lines:
            continue
        text = texts[rel]
        if (rel, k) in mention_lines and ln.count(TOOL) == 1:
            continue
        lo = len("\n".join(text.split("\n")[:k - 1])) + (1 if k > 1 else 0)
        hi = lo + len(ln)
        if any(a < hi and lo < b for a, b in covered.get(rel, [])):
            continue
        if (rel, k) in mention_lines:
            out.append("no ① %s:%d 언급 행의 줄에 %s 이 둘 이상이다 — 언급 행은 한 줄에 하나만 덮는다: %s"
                       % (rel, k, TOOL, ln.strip()[:80]))
            continue
        out.append("no ① %s:%d 후보 줄이 어느 행에도 덮이지 않는다: %s" % (rel, k, ln.strip()[:80]))
    return out


def main(argv):
    if len(argv) != 4:
        sys.stderr.write("쓰는 법: ask_recommendation.py <root> <후보 파일 목록> <목록 tsv>\n")
        return 2
    root = argv[1]
    try:
        with io.open(argv[2], encoding="utf-8") as fh:
            files = [l for l in fh.read().split("\n") if l]
        sites = load_sites(argv[3])
        lines = check(root, files, sites)
    except (OSError, UnicodeDecodeError) as e:
        sys.stderr.write("읽지 못했다: %s\n" % e)
        return 2
    for line in lines:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
