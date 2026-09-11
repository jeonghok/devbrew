#!/usr/bin/env python3
"""variant-of 관계 — 변형 정본이 기준 정본과 «정해진 차이만» 갖는가.

변형(V)은 머리 20줄 안의 `# variant-of: <기준 경로>` 마커로 기준(B)을 가리킨다. 관계는 두 조건이
함께 설 때만 성립한다:
  ① frontmatter — 최상위 키 집합이 같고, `name`·`description`·`tools` 밖의 키는 값 블록이 줄 단위로
     같다. 컬럼-0 주석 줄(`# copy-of:`·`# variant-of:`)은 비교에서 뺀다.
  ② 본문(frontmatter 닫힘 뒤) — V 는 B 에 연속한 한 덩어리를 끼워 넣은 것뿐이다. B 의 어느 줄도
     바뀌거나 빠지지 않고, 끼운 덩어리에는 빈 줄이 아닌 줄이 있다.

소비자 둘: shared/tests/test_no_new_duplication.sh(관계가 서는 쌍만 중복 면제 — 마커만으로는 면제하지
않는다) · shared/tests/test_docreview_agents.sh(웹 사본의 본문 drift 락).

CLI:
  variant_of.py marker <file>              → 마커가 가리키는 경로(없으면 빈 출력) · rc 0
  variant_of.py check <variant> <base>     → "OK\\t<끼운 줄 수>" rc 0 | "FAIL\\t<사유>" rc 1
  variant_of.py inserted <variant> <base>  → 끼운 덩어리 원문 rc 0 | "FAIL\\t<사유>" rc 1
python 3.9 · stdlib 만 쓴다.
"""
import re
import sys
from pathlib import Path

MARKER = re.compile(r'^\s*(?:#|//|<!--)\s*variant-of:\s*(\S+)')
HEAD_WINDOW = 20
FREE_KEYS = ("name", "description", "tools")
_KEY = re.compile(r'^([A-Za-z_][A-Za-z0-9_.-]*):')


def marker(path):
    """머리 20줄 안의 variant-of 마커가 가리키는 경로. 없거나 못 읽으면 None."""
    try:
        with open(path, encoding="utf-8") as fh:
            for i, line in enumerate(fh):
                if i >= HEAD_WINDOW:
                    break
                m = MARKER.match(line)
                if m:
                    return m.group(1).rstrip("->").strip()
    except (OSError, UnicodeDecodeError):
        return None
    return None


def _split(text):
    if not text.startswith("---\n"):
        return None, None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None, None
    return text[4:end].split("\n"), text[end + 5:].split("\n")


def _fm_blocks(lines):
    """최상위 키 → 그 키의 줄 블록(키 줄 + 이어지는 들여쓴·빈 줄). 중복 키·키 없는 내용은 None."""
    blocks, key = {}, None
    for ln in lines:
        if ln.startswith("#"):
            continue
        m = _KEY.match(ln)
        if m:
            key = m.group(1)
            if key in blocks:
                return None
            blocks[key] = [ln]
        elif key is None:
            if ln.strip():
                return None
        else:
            blocks[key].append(ln)
    return blocks


def relation(variant, base):
    """(성립 여부, 사유, 끼운 줄 목록)."""
    try:
        vt = Path(variant).read_text(encoding="utf-8")
        bt = Path(base).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return False, "unreadable:%s" % type(exc).__name__, []
    vf, vb = _split(vt)
    bf, bb = _split(bt)
    if vf is None or bf is None:
        return False, "frontmatter_missing", []
    vk, bk = _fm_blocks(vf), _fm_blocks(bf)
    if vk is None or bk is None:
        return False, "frontmatter_unparsable", []
    if set(vk) != set(bk):
        return False, "frontmatter_keys_differ:%s" % ",".join(sorted(set(vk) ^ set(bk))), []
    for k in sorted(vk):
        if k not in FREE_KEYS and vk[k] != bk[k]:
            return False, "frontmatter_value_differs:%s" % k, []
    n, m = len(bb), len(vb)
    p = 0
    while p < n and p < m and bb[p] == vb[p]:
        p += 1
    s = 0
    while s < n - p and s < m - p and bb[n - 1 - s] == vb[m - 1 - s]:
        s += 1
    if p + s != n:
        return False, "body_changed_beyond_one_insertion:base_line_%d" % (p + 1), []
    ins = vb[p:m - s]
    if not any(x.strip() for x in ins):
        return False, "no_insertion", []
    return True, "", ins


def main(argv):
    if len(argv) >= 3 and argv[1] == "marker":
        t = marker(argv[2])
        if t:
            print(t)
        return 0
    if len(argv) >= 4 and argv[1] in ("check", "inserted"):
        ok, why, ins = relation(argv[2], argv[3])
        if not ok:
            print("FAIL\t%s" % why)
            return 1
        if argv[1] == "check":
            print("OK\t%d" % len(ins))
        else:
            print("\n".join(ins))
        return 0
    sys.stderr.write("usage: variant_of.py marker <file> | check|inserted <variant> <base>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
