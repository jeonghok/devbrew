#!/usr/bin/env python3
"""인라인 python 호출 스캐너 — test_inline_python_isolated.sh 가 쓴다.

python 을 `-c` · `-m` · `-`(stdin) 로 부르거나 스크립트 인자 없이(heredoc · 파이프) 부르면
현재 디렉토리가 sys.path 맨 앞에 온다. 플러그인 스크립트와 skill 펜스는 리뷰 · 감사 대상 리포를
현재 디렉토리로 두고 도는 일이 많아서, 그 리포의 json.py · uuid.py 가 표준 모듈 대신 실행된다.
`-I` 가 그것을 막는다. 스크립트 파일 경로로 부르는 호출은 그 파일의 디렉토리가 맨 앞이라 대상이 아니다.

  scan <path>...      줄마다 `<path>:<line>\t<isolated|bare>\t<줄>` — 인라인 호출만 낸다
  classify            stdin 의 줄마다 `inline-isolated` · `inline-bare` · `script` · `none` 하나
"""
import re
import sys

# 명령 자리의 python 토큰. 경로 접두(/usr/bin/python3 · .venv/bin/python)도 잡는다.
# 앞 글자가 단어 · `$` · `-` 면 다른 단어의 일부다(PYTHONPATH · run_python3 · $python3).
TOKEN = re.compile(r"(?<![\w$-])((?:[\w.~-]*/)*python3?(?:\.\d+)?)(?=\s|$)")
# 앞에 이것이 오면 호출이 아니라 존재 확인이다.
PROBE = re.compile(r"(command\s+-v|which|type|hash)\s+$")
# 인자 하나를 먹는 python 옵션.
TAKES_ARG = {"-W", "-X", "-Q"}
# 셸 연산자 · 리다이렉트로 시작하는 토큰 — 여기까지 위치 인자가 없었으면 스크립트를 stdin 으로 받는다.
STOP = re.compile(r"^(\||&&|\|\||;|\)|<|>|\d>|&>|`|$)")


def classify(line):
    """한 줄 → (kind, isolated). kind: inline · script · none."""
    best = ("none", False)
    for m in TOKEN.finditer(line):
        if PROBE.search(line[: m.start()]):
            continue
        rest = line[m.end():].split()
        isolated = False
        kind = None
        i = 0
        while i < len(rest):
            tok = rest[i]
            if STOP.match(tok):
                kind = "inline"
                break
            if tok == "-":
                kind = "inline"
                break
            if tok in TAKES_ARG:
                i += 2
                continue
            if re.fullmatch(r"-[A-Za-z]+", tok):
                flags = tok[1:]
                if "I" in flags:
                    isolated = True
                if "c" in flags or "m" in flags:
                    kind = "inline"
                    break
                i += 1
                continue
            if tok.startswith("--"):
                i += 1
                continue
            kind = "script"
            break
        if kind is None:
            kind = "inline"   # 줄 끝까지 위치 인자가 없다 — 다음 줄(heredoc)이나 stdin 에서 받는다
        if kind == "inline":
            return ("inline", isolated)
        best = ("script", False)
    return best


def is_comment(line):
    s = line.lstrip()
    return s.startswith("#") or s.startswith("```")   # 셸 주석 · 마크다운 펜스 머리줄(```python)


def strip_trailing_comment(line):
    """따옴표 밖에서 공백 뒤에 오는 `#` 부터 줄 끝까지를 뗀다(`set +B  # … python3 -c …`)."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "#" and i > 0 and line[i - 1] in " \t":
            return line[:i]
    return line


def scan(paths):
    for path in paths:
        try:
            with open(path, encoding="utf-8") as fh:
                rows = fh.read().split("\n")
        except (OSError, UnicodeDecodeError):
            continue
        for n, row in enumerate(rows, start=1):
            if is_comment(row):
                continue
            kind, isolated = classify(strip_trailing_comment(row))
            if kind == "inline":
                state = "isolated" if isolated else "bare"
                print(f"{path}:{n}\t{state}\t{row.strip()}")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "scan":
        scan(sys.argv[2:])
        return 0
    if len(sys.argv) == 2 and sys.argv[1] == "classify":
        for row in sys.stdin.read().split("\n"):
            if not row:
                continue
            if is_comment(row):
                print("none")
                continue
            kind, isolated = classify(strip_trailing_comment(row))
            if kind == "inline":
                print("inline-isolated" if isolated else "inline-bare")
            else:
                print(kind)
        return 0
    print("usage: inline_python_scan.py scan <path>... | classify", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
