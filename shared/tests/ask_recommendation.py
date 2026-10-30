#!/usr/bin/env python3
"""질문 자리 추천 표시 전수 판정 — `test_ask_recommendation.sh` 의 본체.

입력: 리포 루트 · 후보 파일 목록(한 줄에 리포 상대 경로 하나) · 목록 tsv(`경로<TAB>종류<TAB>앵커<TAB>끝<TAB>덮는 수`).
출력: `ok <설명>` · `no <①|②|③|④> <경로>:<줄> <설명>` 줄. rc 0 = 판정 완료, rc 2 = 인자 · 파일 읽기 실패.

- 앵커는 그 파일에서 정확히 한 번 나오는 한 줄 안의 글자다. 범위는 끝이 있으면 앵커 시작부터 앵커 뒤
  첫 `끝` 의 끝까지, 끝이 비면 앵커가 든 문단(빈 줄 사이)이다.
- 질문 행(꼬리 · 지시 · 비움 · 출처꼬리)의 범위 안에 다른 질문 행의 앵커 시작이 있으면 ② 다.
- 세는 단위는 줄이 아니라 `AskUserQuestion` 이 나온 자리다. 언급 행은 한 자리를 맡는다 — 앵커에 도구 이름이 있으면
  그 자리, 없으면 앵커 줄의 첫 자리. 떼기 행은 맡지 않는다.
- 질문 행의 범위 안 자리 수(언급 행이 맡은 것을 뺀다)는 `덮는 수` 칸(비면 0)과 같아야 한다 — 다르면 ① 이다.
  어느 질문 범위에도 들지 않고 언급 행도 맡지 않은 자리가 있는 후보 줄도 ① 이다.
- 꼬리 행의 범위에 `label:` 키가 있으면 꼬리는 `label:` 값 안에 있어야 한다. 없으면(마크다운 꼴) 범위 어디든 센다.
"""
import io
import re
import sys
from collections import namedtuple

TAIL_RE = re.compile(r"(?<!「)\((?:권장|Recommended)\)")
# label 은 키 자리(줄 머리 · `{` · `,` 바로 뒤)에서만 읽는다 — 앞 글자만 보므로 문자열 안의 `, label:` 글과 YAML 목록 꼴(`- label:`)은 가르지 못한다(설계 미룸 표).
LABEL_KEY_RE = re.compile(r"""(?:^|[{,])\s*["']?label["']?\s*:""", re.M)
LABEL_RE = re.compile(r"""(?:^|[{,])\s*["']?label["']?\s*:\s*(["'`])((?:(?!\1)[^\n])*)\1""", re.M)
DIRECTIVE = "권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다"
EMPTY = "추천을 달지 않는다 — "
SOURCE = "추천)"
STRIP = "라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다"

TOOL = "AskUserQuestion"
QUESTION_KINDS = ("꼬리", "지시", "비움", "출처꼬리")
KINDS = QUESTION_KINDS + ("언급", "떼기")

Site = namedtuple("Site", "path kind anchor end lines lineno")


def load_sites(path):
    """목록 tsv 를 읽는다. 칸 수가 맞지 않는 줄도 Site 로 돌려 check 가 ② 로 알린다(조용히 버리지 않는다)."""
    sites = []
    with io.open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh.read().split("\n"), 1):
            line = raw.rstrip("\r")
            if not line.strip() or line.startswith("#"):
                continue
            cells = line.split("\t")
            if len(cells) in (3, 4):
                cells += [""] * (5 - len(cells))
            if len(cells) != 5:
                # 칸이 맞지 않는 줄은 종류 None, 앵커 자리에 원래 줄(탭은 \t 로)을 담아 ② 사유에 그대로 보인다.
                sites.append(Site(cells[0], None, line.replace("\t", "\\t"), "", "", n))
                continue
            sites.append(Site(cells[0], cells[1], cells[2], cells[3], cells[4], n))
    return sites


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def spans_line(text, k, sc):
    """범위 sc(시작, 끝 오프셋)가 k 번째 줄과 겹치는가."""
    lo = len("\n".join(text.split("\n")[:k - 1])) + (1 if k > 1 else 0)
    hi = lo + len(text.split("\n")[k - 1])
    return sc[0] < hi and lo < sc[1]


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
    if site.lines and site.kind not in QUESTION_KINDS:
        return "덮는 수 칸 「%s」은 질문 행(%s)에만 쓴다" % (site.lines, " · ".join(QUESTION_KINDS))
    if site.lines and not site.lines.isdigit():
        return "덮는 수 칸 「%s」이 수가 아니다" % site.lines
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
    if kind == "꼬리" and LABEL_KEY_RE.search(body):
        if not any(TAIL_RE.search(m.group(2)) for m in LABEL_RE.finditer(body)):
            return "범위의 `label:` 값에 라벨 꼬리 「(권장)」 · 「(Recommended)」가 없다"
    elif kind == "꼬리" and not TAIL_RE.search(body):
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
            resolved.append((s, None, "칸 수가 맞지 않다(경로 · 종류 · 앵커 · 끝 · 덮는 수)"))
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

    anchor_starts = {}
    covered = {}  # 경로 → [범위]
    claimed = set()  # 언급 행이 맡은 (경로, 오프셋)
    for s, text, sc in resolved:
        if text is None or s.kind not in KINDS or not s.anchor or text.count(s.anchor) != 1:
            continue
        a = text.find(s.anchor)
        anchor_starts.setdefault(s.path, []).append((a, s))
        if isinstance(sc, str):
            continue
        if s.kind in QUESTION_KINDS:
            covered.setdefault(s.path, []).append(sc)
        elif s.kind == "언급":
            # 앵커에 도구 이름이 있으면 그 자리를, 없으면 앵커 줄의 첫 자리를 맡는다.
            if TOOL in s.anchor:
                claimed.add((s.path, a + s.anchor.index(TOOL)))
            else:
                k0, k1 = text.rfind("\n", 0, a) + 1, text.find("\n", a)
                o = text.find(TOOL, k0, len(text) if k1 < 0 else k1)
                if o >= 0:
                    claimed.add((s.path, o))

    def occurrences(rel, lo, hi):
        """[lo, hi) 안의 도구 이름 자리 중 언급 행이 맡지 않은 것."""
        text, out_, i = texts[rel], [], texts[rel].find(TOOL, lo)
        while 0 <= i < hi:
            if (rel, i) not in claimed:
                out_.append(i)
            i = text.find(TOOL, i + 1)
        return out_

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
                       if o is not s and o.kind in QUESTION_KINDS and sc[0] <= a < sc[1]]
            if crossed:
                o = crossed[0]
                out.append("no ② %s %s: 범위가 다른 행의 앵커 「%s」(목록 L%d)를 넘는다" % (where, label, o.anchor, o.lineno))
                continue
            inside = len(occurrences(s.path, sc[0], sc[1]))
            want = int(s.lines or "0")
            if inside != want:
                out.append("no ① %s %s: 범위 안 %s 이 %d번인데 목록의 덮는 수는 %d이다 — 새 질문이면 행을 따로 더한다"
                           % (where, label, TOOL, inside, want))
                continue
        why = required(s.kind, text[sc[0]:sc[1]])
        if why:
            out.append("no ③ %s %s: %s" % (where, label, why))
            continue
        out.append("ok %s %s" % (where, label))

    for rel, k, ln in candidates:
        text = texts[rel]
        lo = len("\n".join(text.split("\n")[:k - 1])) + (1 if k > 1 else 0)
        loose = [o for o in occurrences(rel, lo, lo + len(ln))
                 if not any(a <= o < b for a, b in covered.get(rel, []))]
        if not loose:
            continue
        if any((rel, o) in claimed for o in range(lo, lo + len(ln))):
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
