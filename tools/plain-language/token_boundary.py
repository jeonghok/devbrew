#!/usr/bin/env python3
"""압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계가 규칙 블록 때문에 어디로 옮겼는지 잰다(근사).

근사식(줄마다 누적): 한글 음절 × KH + 그 밖 비ASCII × KO + ASCII 글자 / CA (+ 개행).
  cons(보수): KH=1.0 · KO=1.0 · CA=3.0   ·  cent(중앙): KH=0.8 · KO=1.0 · CA=3.7
오프라인 tokenizer 와 API 키가 없어(2026-10-08 실측) 실제 tokenizer 로 보정하지 않았다 — 값은 근사다.
「새로 밀려난 절」 = 넣기 전에는 경계 안에서 시작하던 `## ` 절 중 넣은 뒤 경계 밖에서 시작하는 것.
넣기 전 파일은 `--base <rev>` 의 git 내용이다.
"""
import argparse
import io
import subprocess
import sys

PROFILES = {"cons": (1.0, 1.0, 3.0), "cent": (0.8, 1.0, 3.7)}
LIMIT = 5000
BEGIN, END = "<!-- plain-language:begin -->", "<!-- plain-language:end -->"


def toks(s, prof):
    kh, ko, ca = PROFILES[prof]
    h = sum(1 for c in s if "가" <= c <= "힣")
    a = sum(1 for c in s if ord(c) < 128)
    return h * kh + (len(s) - h - a) * ko + a / ca


def boundary(lines, prof, body):
    start = 0
    if body and lines and lines[0] == "---":
        start = lines.index("---", 1) + 1
    cum = 0.0
    for i in range(start, len(lines)):
        cum += toks(lines[i] + "\n", prof)
        if cum > LIMIT:
            return i
    return None


def git(*args):
    return subprocess.run(["git"] + list(args), capture_output=True, text=True, encoding="utf-8", check=True).stdout


def heads(lines):
    return [(i, l) for i, l in enumerate(lines) if l.startswith("## ")]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="블록을 넣기 전 커밋")
    ap.add_argument("--body", action="store_true", help="frontmatter 를 빼고 잰다")
    a = ap.parse_args(argv)
    targets = git("ls-files", "--", "plugins/*/skills/*/SKILL.md", "plugins/*/commands/*.md").split()
    canon = io.open("shared/style/plain-language.md", encoding="utf-8").read()
    print("블록 근사 토큰: cons %.0f · cent %.0f" % (toks(canon, "cons"), toks(canon, "cent")))
    for rel in sorted(targets):
        old = git("show", "%s:%s" % (a.base, rel)).split("\n")
        new = io.open(rel, encoding="utf-8").read().split("\n")
        for prof in ("cons", "cent"):
            b0, b1 = boundary(old, prof, a.body), boundary(new, prof, a.body)
            if b0 is None and b1 is None:
                print("%s [%s] 파일 전체가 %d토큰 미만 — 밀린 절 없음" % (rel, prof, LIMIT))
                continue
            inside_old = {l for i, l in heads(old) if b0 is None or i < b0}
            outside_new = {l for i, l in heads(new) if b1 is not None and i >= b1}
            pushed = sorted(inside_old & outside_new)
            cut = [l for i, l in heads(new) if b1 is not None and i < b1][-1:]
            print("%s [%s] 경계 L%s → L%s · 새로 밀린 절: %s · 경계가 걸친 절: %s"
                  % (rel, prof, b0 + 1 if b0 is not None else "-", b1 + 1 if b1 is not None else "-",
                     " / ".join(pushed) or "없음", cut[0] if cut else "-"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
