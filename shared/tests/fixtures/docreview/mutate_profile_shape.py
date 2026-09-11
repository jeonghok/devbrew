#!/usr/bin/env python3
"""mutate_profile_shape.py — 리뷰 F-5 회귀 락(test_docreview_codex.sh)이 쓰는 픽스처.

실재 프로필 파일(`references/docreview-profiles/*.md`) 하나를 받아 `layer1`·`layer2`·
`web`·`ground_truth` 줄만 정규식으로 다시 써서, `run_docreview_codex_reviewer.sh`의
stdlib 빌더가 그 모양을 어떻게 읽는지 재게 한다. 새 프로필을 손으로 짓지 않는다 —
실재 프로필의 나머지 필드(detectors·fix_anchors·...)는 그대로 둔다.

게이트(`load_profile()`)가 **거절하는** 모양도 있다 — 중복 키(`dup-web`·`dup-layer1`·
`gt-dup`·`gt-dup-mixed`, Task 3c R37 이후), 목록·빔·null·부재(`gt-flow-list`·`gt-block-list`·
`gt-empty`·`gt-bare`·`gt-null`·`gt-absent`), 빈 본문(`body-empty`), 문자열 아닌 `gt-value=` 값,
시퀀스 항목 뒤 텍스트(`g-seqtail`), 매핑이 아니거나 없는 `layer_rubric`(`lr-list`·`lr-bare`·`lr-absent`).
리뷰 I1·M3 재현 모양(`qcont-gt`·`qcont-all`·`flow-web`·`gt-spacecolon`·`gt-u2028`·`gt-u2028-hidden`)은 게이트가
**받는다** — 러너가 그것을 다른 값으로 읽지 않는지(이름 붙은 fail-closed 인지) 재는 용도다 — 러너가 게이트 없이 단독으로
불렸을 때의 행동을 재기 위한 것이다(러너는 게이트를 다시 구현하지 않는다).

Usage: mutate_profile_shape.py <shape> <src_profile> <dst_profile>
"""
import re
import sys

SHAPES = (
    "wrapped-layer1", "wrapped-layer2", "block-blank", "block-comment",
    "web-yes", "dup-web", "dup-layer1", "ground-truth-decoy",
    "gt-dup", "gt-plain", "gt-flow-list", "gt-block-list", "gt-dup-mixed",
    "gt-empty", "gt-bare", "gt-null", "gt-absent", "body-empty",
    "qcont-gt", "qcont-all", "flow-web", "gt-spacecolon", "gt-u2028", "dup-web-live", "web-absent",
    "rr-qkey", "rr-hashkey", "rr-qmark", "rr-nestseq", "rr-blockseq", "rr-phantom", "rr-phantom1",
    "rr-qkey-gt", "rr-control",
    "g-qkey", "g-hashkey", "g-qmark", "g-comment", "g-tailcomment", "g-sq", "g-esc", "g-nestflow",
    "g-plainquote", "g-indent4", "g-blockscalar", "g-anchor", "g-unclosed", "g-tab",
    "g-nel", "g-seqtail", "g-boolkey", "g-topqkey", "gt-u2028-hidden",
    "lr-list", "lr-bare", "lr-absent", "l1-regexy",
)
# Task 3c 재리뷰 1 의 I1(b) 재현(`t3c-rr1/mkv.py` 그대로) — `defer_target: {kind: none}` 을 frontmatter
# 끝의 block 매핑으로 옮기고, 옛 스캐너가 추적하지 못한 자리에 컬럼-0 디코이 줄을 숨긴다. 게이트는
# 전부 받는다(defer_target 은 여분 키를 검사하지 않는다).
RR_BLOCKS = {
    "rr-qkey": '\ndefer_target:\n  kind: none\n  "k": "abc\nweb: true #"',
    "rr-hashkey": '\ndefer_target:\n  kind: none\n  a#b: "abc\nweb: true #"',
    "rr-qmark": '\ndefer_target:\n  kind: none\n  ? "abc\nweb: true #"\n  : v',
    "rr-nestseq": '\ndefer_target:\n  kind: none\n  x:\n  - - "abc\nweb: true #"',
    "rr-blockseq": '\ndefer_target:\n  kind: none\n  x:\n  - k: |\n        content\n    z: "abc\nweb: true #"',
    "rr-phantom": '\ndefer_target:\n  kind: none\n  x: [a"b]\n  y: "a]\nweb: true #"',
    "rr-phantom1": "\ndefer_target:\n  kind: none\n  x: [it's]\n  y: 'a]\nweb: true #'",
    "rr-qkey-gt": '\ndefer_target:\n  kind: none\n  "k": "abc\nground_truth: DECOY_GT #"',
    "rr-control": '\ndefer_target:\n  kind: none\n  k: "abc\nweb: true #"',
}
# 러너 줄 문법(R42)의 규칙을 **하나만** 어기는 모양 — 나머지 줄은 전부 문법 안이다. 재리뷰의 일곱
# 모양은 규칙 여럿을 한꺼번에 어겨서 규칙 하나를 풀어도 여전히 멈추므로, 규칙별 이빨은 이 모양들이
# 잰다(`g-comment` · `g-tailcomment` 는 아래 분기).
G_BLOCKS = {
    "g-boolkey": '\ndefer_target:\n  kind: none\n  on: v',
    "g-qkey": '\ndefer_target:\n  kind: none\n  "k": abc',
    "g-hashkey": '\ndefer_target:\n  kind: none\n  a#b: abc',
    "g-qmark": '\ndefer_target:\n  kind: none\n  ? k\n  : v',
    "g-sq": "\ndefer_target:\n  kind: none\n  k: 'abc'",
    "g-esc": '\ndefer_target:\n  kind: none\n  k: "a\\"b"',
    "g-nestflow": '\ndefer_target:\n  kind: none\n  k: [a, [b]]',
    "g-plainquote": '\ndefer_target:\n  kind: none\n  k: [a"b]',
    "g-indent4": '\ndefer_target:\n  kind: none\n  k: abc\n    def',
    "g-blockscalar": '\ndefer_target:\n  kind: none\n  k: |',
    "g-anchor": '\ndefer_target:\n  kind: none\n  k: &a abc',
    "g-unclosed": '\ndefer_target:\n  kind: none\n  k: "abc',
    "g-tab": '\ndefer_target:\n  kind: none\n  k: "a\tb"',
}
# `gt-value=<값>` — ground_truth 줄을 `ground_truth:<값>` 으로 바꾼다(`\n` 은 줄바꿈).
GT_LINE = r"^ground_truth:.*$"


def _wrap_flow(text, key):
    return re.sub(
        r"^  %s: \[([^\]]*)\]$" % re.escape(key),
        lambda m: "  %s: [\n    %s]" % (key, m.group(1)),
        text, count=1, flags=re.MULTILINE)


def _to_block_with_gap(text, gap_line):
    def repl(m):
        items = [x.strip() for x in m.group(1).split(",") if x.strip()]
        lines = ["    - %s" % items[0], gap_line]
        lines += ["    - %s" % it for it in items[1:]]
        return "  layer1:\n" + "\n".join(lines)
    return re.sub(r"^  layer1: \[([^\]]*)\]$", repl, text, count=1, flags=re.MULTILINE)


def _sub1(pattern, repl, text):
    # 정확히 한 번 바꾼다. 못 바꾸면 조용히 원본을 쓰지 않고 죽는다(픽스처 전제 실패).
    out, n = re.subn(pattern, lambda m: repl, text, count=1, flags=re.MULTILINE)
    if n != 1:
        sys.exit("fixture pattern not found: %r" % pattern)
    return out


def _move_to_end(text, block):
    end = text.find("\n---\n", 4)
    return text[:end] + block + text[end:]


def main():
    if len(sys.argv) != 4:
        print("usage: mutate_profile_shape.py <shape> <src> <dst>", file=sys.stderr)
        return 2
    shape, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    if shape not in SHAPES and not shape.startswith("gt-value="):
        print("unknown shape: %s (want one of %s)" % (shape, ", ".join(SHAPES)), file=sys.stderr)
        return 2
    text = open(src, encoding="utf-8").read()

    if shape == "wrapped-layer1":
        text = _wrap_flow(text, "layer1")
    elif shape == "wrapped-layer2":
        text = _wrap_flow(text, "layer2")
    elif shape == "block-blank":
        text = _to_block_with_gap(text, "")
    elif shape == "block-comment":
        text = _to_block_with_gap(text, "    # a comment between items")
    elif shape == "web-yes":
        text = re.sub(r"^web: \w+$", "web: yes", text, count=1, flags=re.MULTILINE)
    elif shape == "dup-web":
        # **순서가 결정적이다.** true 를 먼저 두고 false 를 나중에 둔다 — 반대
        # 순서(false, true)는 "진리값 패턴만 마지막까지 검색"하는 파서도
        # 우연히 맞힌다(그 패턴에 걸리는 줄이 true 하나뿐이라 어차피 그것을
        # 찾는다). 이 순서라야 "값과 무관하게 web: 줄 자체의 마지막"을 찾는지
        # 실제로 갈린다 — PyYAML 의 last-wins 는 false(나중 줄)다.
        text = re.sub(r"^web: \w+$", "web: true\nweb: false", text, count=1, flags=re.MULTILINE)
    elif shape == "dup-layer1":
        # 두 번째(이겨야 하는) 선언에 원본에 없는 표지 카테고리를 심어, 캡처된
        # 프롬프트에서 "이겼는지"를 원본 항목과 섞이지 않게 확인할 수 있게 한다.
        text = re.sub(
            r"^(  layer1: \[[^\]]*\])$",
            r"\1\n  layer1: [marker_last_wins_category]",
            text, count=1, flags=re.MULTILINE)
    elif shape == "ground-truth-decoy":
        # 리뷰 F-6 — 다른 최상위 키(`ground_truth:`)의 block scalar 안에
        # layer1·layer2·allowed_dispositions 처럼 보이는 줄을 심는다. 원본의
        # 단일행 `ground_truth: "..."` 를 지우고, frontmatter 를 닫는 `---`
        # 바로 앞(= 진짜 layer_rubric·allowed_dispositions 보다 뒤, 텍스트
        # 상 "마지막 occurrence")에 decoy 를 심은 block scalar 로 다시
        # 넣는다 — 스코프 안 된 `_last_match` 라면 이 decoy 가 진짜 값을
        # 이겨야 결함이 실제로 드러난다.
        text = re.sub(r"^ground_truth:.*$\n?", "", text, count=1, flags=re.MULTILINE)
        decoy = (
            "ground_truth: |\n"
            "  decoy block scalar deliberately mimicking field headers\n"
            "  layer1: [decoy_layer1]\n"
            "  layer2: [decoy_layer2]\n"
            "  allowed_dispositions: [decide]\n"
            "  end of decoy\n"
        )
        text = re.sub(r"\n---\n", "\n" + decoy + "---\n", text, count=1)
    elif shape == "gt-dup":
        # 원래 줄 바로 뒤에 두 번째 선언 — PyYAML 처럼 마지막(표지)이 이겨야 한다.
        text = re.sub(GT_LINE, lambda m: m.group(0) + '\nground_truth: "marker_gt_last_wins"',
                      text, count=1, flags=re.MULTILINE)
    elif shape == "gt-plain":
        text = re.sub(GT_LINE, "ground_truth: marker_gt_plain value # trailing comment",
                      text, count=1, flags=re.MULTILINE)
    elif shape == "gt-flow-list":
        text = re.sub(GT_LINE, 'ground_truth: [marker_gt_first, "marker_gt_second"]',
                      text, count=1, flags=re.MULTILINE)
    elif shape == "gt-block-list":
        # 주석 없이 — 러너의 줄 문법은 주석 줄·꼬리 주석을 받지 않는다(R42). 이 모양이 재는 것은
        # 「목록이면 게이트와 같은 판정(ground_truth_empty)」이다.
        text = re.sub(GT_LINE,
                      "ground_truth:\n  - marker_gt_first\n  - marker_gt_second",
                      text, count=1, flags=re.MULTILINE)
    elif shape == "gt-dup-mixed":
        # 모양이 다른 중복 — flow 목록이 먼저, 따옴표 스칼라가 frontmatter 끝(나중)에.
        # 나중 선언(스칼라)이 이겨야 한다 — 앞 선언(목록)을 고르는 파서는 fail-closed 로 샌다.
        text = re.sub(GT_LINE, "ground_truth: [marker_gt_first]", text, count=1, flags=re.MULTILINE)
        text = re.sub(r"\n---\n", '\nground_truth: "marker_gt_second"\n---\n', text, count=1)
    elif shape == "gt-empty":
        text = re.sub(GT_LINE, 'ground_truth: ""', text, count=1, flags=re.MULTILINE)
    elif shape == "gt-bare":
        text = re.sub(GT_LINE, "ground_truth:", text, count=1, flags=re.MULTILINE)
    elif shape == "gt-null":
        text = re.sub(GT_LINE, "ground_truth: null", text, count=1, flags=re.MULTILINE)
    elif shape == "gt-absent":
        text = re.sub(GT_LINE + r"\n?", "", text, count=1, flags=re.MULTILINE)
    elif shape == "body-empty":
        # frontmatter 는 그대로, 닫는 `---` 뒤 본문은 공백 줄만 남긴다(빈 문자열이 아니라
        # 공백 — `if not body` 로 좁혀 쓴 검사도 걸리게).
        end = text.find("\n---\n", 4)
        text = text[:end + 5] + "\n  \n"
    elif shape == "qcont-gt":
        # 리뷰 I1 재현 — immutable 목록 항목의 큰따옴표 연속줄 안 컬럼 0 에 ground_truth 를 숨긴다.
        text = _sub1(r"^immutable: .*$",
                     'immutable:\n  - "^6\\\\.\nground_truth: DECOY_GT_FROM_CONTINUATION\n    #"', text)
    elif shape == "qcont-all":
        # 리뷰 I1 재현 — decision_log 를 block 매핑으로 frontmatter 끝에 옮기고, heading 의 큰따옴표
        # 연속줄 안 컬럼 0 에 네 필드를 숨긴다(게이트는 이것을 heading 의 값으로 읽는다).
        m = re.search(r'^decision_log: \{kind: (\w+), heading: "([^"]*)"\}\n', text, flags=re.MULTILINE)
        if not m:
            sys.exit("fixture pattern not found: decision_log flow mapping")
        text = text[:m.start()] + text[m.end():]
        hidden = ("ground_truth: DECOY_GT\nweb: true\nlayer_rubric:\n  layer1: [DECOY_L1]\n  layer2: []\n"
                  "allowed_dispositions: [decide, ask]\n")
        text = _move_to_end(text, '\ndecision_log:\n  kind: %s\n  heading: "%s\n%s    #"'
                            % (m.group(1), m.group(2), hidden))
    elif shape == "flow-web":
        # 리뷰 I1 재현(배포 seed·generic) — defer_target 의 flow 매핑을 여러 줄로 펴고 그 연속줄
        # 컬럼 0 에 `web: true` 를 둔다. 게이트는 defer_target 의 여분 키로 읽고 최상위 web 은 false.
        text = _sub1(r"^defer_target: \{kind: none\}\n", "", text)
        text = _move_to_end(text, "\ndefer_target: {kind: none,\nweb: true\n  }")
    elif shape == "gt-spacecolon":
        text = _sub1(r"^ground_truth:", "ground_truth :", text)
    elif shape == "gt-u2028":
        # U+2028 규칙 **하나만** 어긴다 — 큰따옴표 안의 U+2028(PyYAML 은 보존한다). 이 규칙을 풀면
        # 러너가 같은 값을 읽고 진행하므로 셀이 RED 가 된다. 옛 입력(아래 gt-u2028-hidden)은 꼬리 주석
        # 규칙에서 먼저 멈춰 이 규칙의 이빨이 아니었다.
        text = _sub1(GT_LINE, 'ground_truth: "before\u2028REAL_BEHIND_U2028"', text)
    elif shape == "gt-u2028-hidden":
        # 리뷰 M3 재현 — PyYAML 은 U+2028 을 줄바꿈으로 본다. 진짜 ground_truth 를 그 뒤에 둔다.
        text = _sub1(GT_LINE + r"\n", "", text)
        text = _sub1(r"^detectors: 1$", 'detectors: 1 # c ground_truth: "REAL_BEHIND_U2028"', text)
    elif shape == "web-absent":
        text = _sub1(r"^web: \w+\n", "", text)
    elif shape == "dup-web-live":
        # 재리뷰 1 의 러너 단독 중복 키(`t3c-rr1/safe.sh`) — false 먼저, true 나중. 게이트는
        # duplicate_key 로 거절하고, 옛 러너는 last-wins 로 codex 웹을 켰다.
        text = _sub1(r"^web: false$", "web: false\nweb: true", text)
    elif shape in RR_BLOCKS or shape in G_BLOCKS:
        text = _sub1(r"^defer_target: \{kind: none\}\n", "", text)
        text = _move_to_end(text, RR_BLOCKS.get(shape) or G_BLOCKS[shape])
    elif shape == "g-comment":
        text = _sub1(r"^detectors: 1$", "detectors: 1\n# a comment line", text)
    elif shape == "g-tailcomment":
        text = _sub1(r"^web: false$", "web: false # note", text)
    elif shape == "g-nel":
        # 큰따옴표 안의 NEL(U+0085) — PyYAML 은 공백으로 접고, 러너는 LF 밖 줄바꿈 규칙에서 멈춘다.
        text = _sub1(GT_LINE, 'ground_truth: "NEL\u0085INSIDE"', text)
    elif shape == "g-seqtail":
        text = _sub1(r"^protected_headings: \[\]$", 'protected_headings:\n  - "x" y', text)
    elif shape == "g-topqkey":
        text = _sub1(r"^web: false$", '"web": false', text)
    elif shape in ("lr-list", "lr-bare", "lr-absent"):
        # 경로 중간의 키가 있지만 매핑이 아님(목록 · null) ↔ 키 자체가 없음 — 러너가 rc 5 와 rc 6 을 가른다.
        text = _sub1(r"^layer_rubric:\n  layer1: .*\n  layer2: .*\n",
                     {"lr-list": "layer_rubric: [a]\n", "lr-bare": "layer_rubric:\n",
                      "lr-absent": ""}[shape], text)
    elif shape == "l1-regexy":
        # 층 범주명에 정규식 메타 — 게이트와 러너가 같은 문자열로 받아야 한다.
        text = _sub1(r"^  layer1: \[", '  layer1: ["c++", ', text)
    elif shape.startswith("gt-value="):
        text = _sub1(GT_LINE, "ground_truth:" + shape[len("gt-value="):].replace("\\n", "\n"), text)

    open(dst, "w", encoding="utf-8").write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
