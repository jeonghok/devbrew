#!/usr/bin/env python3
"""quality-pipeline SKILL.md 의 판정 펜스 하나를 뽑아 자리를 채운 셸 파일로 쓴다.

사용: verdict_fence.py <SKILL.md> <표지> <출력 .sh> [이름=값 ...]

- 표지: `<!-- <표지>:begin -->` 와 `<!-- <표지>:end -->` 사이의 첫 ```bash 펜스를 뽑는다.
- 이름이 `QG_` 로 시작하면 그 heredoc(`<<'QG_ARGS_R_<8 hex>'` …)의 몸을 값으로 바꾸고,
  끝 표지의 `<8 hex>` 는 시험 값 `deadbeef` 로 바꾼다.
  값 안의 줄바꿈은 여러 줄이 된다. 빈 값은 빈 줄 하나다.
- 그 밖의 이름은 글자 그대로 바꿀 자리표시다(예: `<session-id>=sid1` · `<N>=2`).

펜스 · 표지 · heredoc 을 못 찾으면 stderr 에 사유를 내고 exit 3 — 테스트가 빈 펜스를 돌려 공허하게
통과하지 않게 한다.
"""
import sys


def die(msg):
    print(f"verdict_fence.py: {msg}", file=sys.stderr)
    raise SystemExit(3)


def extract(text, marker):
    begin, end = f"<!-- {marker}:begin -->", f"<!-- {marker}:end -->"
    lines = text.split("\n")
    try:
        b = lines.index(begin)
        e = lines.index(end, b + 1)
    except ValueError:
        die(f"표지 {marker} 의 begin/end 를 찾지 못했다")
    window = lines[b + 1:e]
    try:
        o = window.index("```bash")
        c = window.index("```", o + 1)
    except ValueError:
        die(f"표지 {marker} 안에 bash 펜스가 없다")
    return window[o + 1:c]


NONCE = "deadbeef"


def fill_heredoc(body, name, value):
    # 끝 표지는 `<name>_<8 hex>` 다 — 값 자리를 실행처럼 16진수 8자(고정 시험 값)로 바꾸고 몸을 채운다.
    # 여는 줄의 따옴표 꼴은 가리지 않는다 — 따옴표가 빠진 펜스도 채워 돌려야 위조 줄 케이스가 그 결함을 잰다.
    # 같은 이름을 두 번 채우면(호출부가 기본값 뒤에 덮어쓸 값을 줄 때) 이미 채운 꼴도 찾아 뒤 값이 이긴다.
    term, real = f"{name}_<8 hex>", f"{name}_{NONCE}"
    openers = tuple(o for t in (term, real) for o in (f"<<'{t}'", f'<<"{t}"', f"<<{t}"))
    starts = [i for i, l in enumerate(body) if l.rstrip().endswith(openers)]
    if len(starts) != 1:
        die(f"heredoc {term} 가 {len(starts)}번 있다(정확히 한 번이어야 한다)")
    i = starts[0]
    ends = [k for k in range(i + 1, len(body)) if body[k] in (term, real)]
    if not ends:
        die(f"heredoc {term} 의 끝 줄이 없다")
    return body[:i] + [body[i].replace(term, real)] + value.split("\n") + [real] + body[ends[0] + 1:]


def main(argv):
    if len(argv) < 4:
        die("인자: <SKILL.md> <표지> <출력 .sh> [이름=값 ...]")
    skill, marker, out = argv[1], argv[2], argv[3]
    with open(skill, encoding="utf-8") as f:
        body = extract(f.read(), marker)
    subs = []
    for pair in argv[4:]:
        if "=" not in pair:
            die(f"이름=값 꼴이 아니다: {pair!r}")
        name, value = pair.split("=", 1)
        if name.startswith("QG_"):
            body = fill_heredoc(body, name, value)
        else:
            subs.append((name, value))
    text = "\n".join(body) + "\n"
    for name, value in subs:
        if name not in text:
            die(f"자리표시 {name!r} 가 펜스에 없다")
        text = text.replace(name, value)
    with open(out, "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
