#!/usr/bin/env python3
"""mutate_profile_shape.py — 리뷰 F-5 회귀 락(test_docreview_codex.sh)이 쓰는 픽스처.

실재 프로필 파일(`references/docreview-profiles/*.md`) 하나를 받아 `layer1`·`layer2`·
`web`·`ground_truth` 줄만 정규식으로 다시 써서, `run_docreview_codex_reviewer.sh`의
stdlib 빌더가 그 모양을 어떻게 읽는지 재게 한다. 새 프로필을 손으로 짓지 않는다 —
실재 프로필의 나머지 필드(detectors·fix_anchors·...)는 그대로 둔다.

`gt-*` 모양 중 목록·빔·null·부재(`gt-flow-list`·`gt-block-list`·`gt-dup-mixed`·
`gt-empty`·`gt-bare`·`gt-null`·`gt-absent`)는 `load_profile()` 이 **거절한다** — 러너가 게이트 없이 단독으로
불렸을 때의 행동을 재기 위한 것이다(러너는 게이트를 다시 구현하지 않는다).

Usage: mutate_profile_shape.py <shape> <src_profile> <dst_profile>
"""
import re
import sys

SHAPES = (
    "wrapped-layer1", "wrapped-layer2", "block-blank", "block-comment",
    "web-yes", "dup-web", "dup-layer1", "ground-truth-decoy",
    "gt-dup", "gt-plain", "gt-flow-list", "gt-block-list", "gt-dup-mixed",
    "gt-empty", "gt-bare", "gt-null", "gt-absent",
)
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


def main():
    if len(sys.argv) != 4:
        print("usage: mutate_profile_shape.py <shape> <src> <dst>", file=sys.stderr)
        return 2
    shape, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    if shape not in SHAPES:
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
        text = re.sub(GT_LINE,
                      "ground_truth:\n  - marker_gt_first\n  # a comment between items\n"
                      "  - marker_gt_second  # trailing",
                      text, count=1, flags=re.MULTILINE)
    elif shape == "gt-dup-mixed":
        # 모양이 다른 중복 — flow 목록이 먼저, block 목록이 frontmatter 끝(나중)에.
        # flow 형과 block 형을 따로 last-match 하는 파서는 앞의 flow 를 고른다.
        text = re.sub(GT_LINE, "ground_truth: [marker_gt_first]", text, count=1, flags=re.MULTILINE)
        text = re.sub(r"\n---\n", "\nground_truth:\n  - marker_gt_second\n---\n", text, count=1)
    elif shape == "gt-empty":
        text = re.sub(GT_LINE, 'ground_truth: ""', text, count=1, flags=re.MULTILINE)
    elif shape == "gt-bare":
        text = re.sub(GT_LINE, "ground_truth:", text, count=1, flags=re.MULTILINE)
    elif shape == "gt-null":
        text = re.sub(GT_LINE, "ground_truth: null", text, count=1, flags=re.MULTILINE)
    elif shape == "gt-absent":
        text = re.sub(GT_LINE + r"\n?", "", text, count=1, flags=re.MULTILINE)

    open(dst, "w", encoding="utf-8").write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
