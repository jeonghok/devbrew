#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""spec_review_bundle.py — spec-review 의 `--bundle`: 정답 출처 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.

명령줄:
  spec_review_bundle.py entry --spec <설계문서> [--bundle <묶음|brief>] --root <레포 루트>
  spec_review_bundle.py neighbors --bundle <묶음> --root <레포 루트>

entry 의 마지막 줄은 `bundle-entry: PROCEED <정답 출처 절대경로 또는 ->` 이거나 `bundle-entry: REFUSE` 다.
`--bundle` 이 있으면 PROCEED 바로 앞 줄이 `번호 대조 경고 <N>개` 다. `--bundle` 은 리뷰어에게 가지 않는다 —
그 값이 설계문서 frontmatter `source_interview` 와 같은 파일인지 확인하고 진입 대조 · 로드맵 위치의 입력이 된다.
neighbors 는 정답 출처가 에픽 묶음이 아니거나 그 에픽이 로드맵에 없으면 아무것도 내지 않는다.
종료 코드는 0 이다(사용법 오류만 2) — 판정은 줄이 말한다. 읽기만 한다(roadmap_status 의 읽기 전용 git 만 부른다).
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_bundle_coverage as cbc  # noqa: E402
import roadmap_status as rs  # noqa: E402
from roadmap_model import FormatError, frontmatter, section_body, unquote  # noqa: E402

KINDS = ("epic-bundle", "interview-brief")
DECISION_LINE_RE = re.compile(r"- B\d+ · 결정 · ")


def _resolve(value: str, root: str) -> str:
    v = unquote(value.strip())
    if v.startswith("@"):
        v = v[1:]
    return os.path.realpath(v if os.path.isabs(v) else os.path.join(root, v))


def _read(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def entry(spec: str, bundle: str, root: str) -> list:
    if not bundle:
        return ["번호 대조 건너뜀 — --bundle 없이 불렸다(정답 출처 확인과 진입 번호 대조를 하지 않는다).",
                "bundle-entry: PROCEED -"]

    def refuse(why):
        return ["[spec-distill] --bundle '%s' 을 정답 출처로 쓸 수 없다 — %s." % (bundle, why),
                "bundle-entry: REFUSE"]

    bpath = _resolve(bundle, root)
    if not os.path.isfile(bpath):
        return refuse("파일이 없다")
    btext = _read(bpath)
    if btext is None:
        return refuse("파일을 읽지 못했다")
    kind = unquote(frontmatter(btext).get("type", ""))
    if kind not in KINDS:
        return refuse("frontmatter type 이 epic-bundle · interview-brief 가 아니다(%s)" % (kind or "없음"))
    spath = _resolve(spec, root)
    stext = _read(spath)
    if stext is None:
        return refuse("설계문서를 읽지 못했다: %s" % spec)
    src = unquote(frontmatter(stext).get("source_interview", ""))
    if not src:
        return refuse("설계문서 frontmatter 에 source_interview 가 없다")
    if _resolve(src, root) != bpath:
        return refuse("설계문서 source_interview(%s) 와 다른 파일이다" % src)
    result = cbc.coverage(bpath, spath)
    return [cbc.render(result), "번호 대조 경고 %d개" % cbc.warning_count(result),
            "bundle-entry: PROCEED %s" % bpath]


def _line(b: dict) -> str:
    return "%s %s — %s · %s" % (b["id"], b["title"], b["stage"], b["reason"])


def neighbors(bundle: str, root: str) -> list:
    bpath = _resolve(bundle, root)
    btext = _read(bpath)
    if btext is None:
        return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 묶음을 읽지 못했다: %s" % bundle]
    fm = frontmatter(btext)
    if unquote(fm.get("type", "")) != "epic-bundle":
        return []
    epic, rel = unquote(fm.get("epic", "")), unquote(fm.get("roadmap", ""))
    git = rs.Git(root)
    report = rs.build(git, argparse.Namespace(roadmap=None, roadmap_file=os.path.join(root, rel), json=True))
    blocks = {b["id"]: b for b in report["blocks"]}
    problems = report["format_errors"] + report["unknown_reasons"]
    if epic not in blocks:
        return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — %s" % " · ".join(problems)] if problems else []
    me = blocks[epic]
    deps = [d for d in me["deps"] if d in blocks]
    dependents = [b["id"] for b in report["blocks"] if epic in b["deps"]]
    out = ["로드맵 속 위치 — %s" % rel, "  " + _line(me)]
    out += ["  의존: " + _line(blocks[d]) for d in deps]
    out += ["  이 에픽에 의존: " + _line(blocks[d]) for d in dependents]
    if problems:
        out.append("  로드맵 상태 검사 불가 %d개 — 위 단계가 틀릴 수 있다: %s" % (len(problems), " · ".join(problems)))
    overlap = {x for o in report["overlaps"] if epic in o["blocks"] for x in o["blocks"] if x != epic}
    near = set(deps) | set(dependents) | overlap
    main, _name = git.default_branch()
    dec = []
    for b in report["blocks"]:
        if b["id"] not in near or not b["specs"]:
            continue
        branch = (b.get("branch") or "").strip().strip("`")
        tree = main if b["stage"] == "머지됨" else (
            git.commit("refs/heads/" + branch) or git.commit("refs/remotes/origin/" + branch))
        for spec in b["specs"]:
            text = git.blob(tree, spec) if tree else None
            if text is None:
                dec.append("  %s — 설계문서를 읽지 못했다: %s" % (b["id"], spec))
                continue
            try:
                body = section_body(text, "## 결정 기록") or ""
            except FormatError:
                body = ""
            lines = [l for l in body.splitlines() if DECISION_LINE_RE.match(l)]
            if lines:
                dec.append("  %s — %s" % (b["id"], spec))
                dec += ["    " + l for l in lines]
            else:
                dec.append("  %s — 결정 줄 없음 — %s" % (b["id"], spec))
    out.append("이웃 에픽의 결정" + ("" if dec else " — 설계문서가 있는 이웃 에픽 없음"))
    return out + dec


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="spec_review_bundle.py",
                                 description="spec-review --bundle: 정답 출처 확인 · 진입 대조 · 로드맵 위치와 이웃 결정.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("entry")
    e.add_argument("--spec", required=True)
    e.add_argument("--bundle", default="")
    e.add_argument("--root", required=True)
    n = sub.add_parser("neighbors")
    n.add_argument("--bundle", required=True)
    n.add_argument("--root", required=True)
    args = ap.parse_args(argv)
    try:
        lines = entry(args.spec, args.bundle, args.root) if args.cmd == "entry" else neighbors(args.bundle, args.root)
    except Exception as exc:  # 확인이 죽어도 조용히 통과로 내지 않는다 — 사유를 줄로 낸다
        if args.cmd == "entry":
            lines = ["[spec-distill] 번호 대조 진입 검사 내부 오류 — %s: %s. --bundle 확인과 번호 대조 없이 리뷰한다."
                     % (type(exc).__name__, exc), "번호 대조 경고 1개", "bundle-entry: PROCEED -"]
        else:
            lines = ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 내부 오류 %s: %s" % (type(exc).__name__, exc)]
    if lines:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
