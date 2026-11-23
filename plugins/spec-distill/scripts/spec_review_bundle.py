#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""spec_review_bundle.py — spec-review 의 `--bundle`: 정답 출처 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.

명령줄:
  spec_review_bundle.py entry --spec <설계문서> [--bundle <묶음|brief|과제 파일>] --root <레포 루트>
  spec_review_bundle.py neighbors --bundle <묶음|과제 파일> --root <레포 루트>
  spec_review_bundle.py rejected --spec <설계문서> --root <레포 루트>

entry 의 마지막 줄은 `bundle-entry: PROCEED <정답 출처 절대경로 또는 ->` 이거나 `bundle-entry: REFUSE` 다.
`--bundle` 이 있으면 PROCEED 바로 앞 줄이 `번호 대조 경고 <N>개` 다. `--bundle` 은 리뷰어에게 가지 않는다 —
그 값이 설계문서 frontmatter `source_intent`(옛 기록은 `source_interview`) 와 같은 파일인지 확인하고 진입 대조 · 로드맵 위치의 입력이 된다.
team 형식(AC16): 과제 파일(머리 `type: job`)을 받으면 진입 번호 대조는 같은 폴더의 번호 파일로 하고
(번호 파일이 없는 단순 작업은 건너뜀 한 줄), 경고 수 앞에 리뷰어의 정답 출처 알림(TEAM_NOTICE) 한 줄을 낸다.
neighbors 는 정답 출처가 에픽 묶음 · 과제 파일이 아니거나 그 에픽이 로드맵에 없으면 아무것도 내지 않는다.
team 형식 로드맵에서 이웃의 결정은 그 과제 INTENT.md 의 `## 결정 기록` 줄 그대로다 — `- <종류> · <날짜> · 「…」` 꼴이고
넘김 확인만 `- 넘김 확인 · <준 에픽> · <8자> · <근거>`(날짜 칸 없음)다. 과제 파일이 없거나 칸을 읽지 못하면 「셀 수 없음」 줄이다.
rejected 는 설계문서 `## 번호 대조` 표의 「기각」 행을 번호 수와 목록으로 낸다(승인 게이트 2단계 앞 글 — N18).
표 절이 없으면 아무것도 내지 않고, 표를 못 읽으면 「셀 수 없음」 줄이다 — 「없음」과 다르다.
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
import legacy_names  # noqa: E402
import roadmap_status as rs  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
from roadmap_model import FormatError, frontmatter, section_body, unquote  # noqa: E402

KINDS = ("epic-bundle",) + legacy_names.kinds(legacy_names.CONTEXT_BRIEF)
JOB_KIND = "job"
TEAM_NOTICE = ("[spec-distill] team 형식 — 리뷰어가 번호 항목(%s)과 원자료(%s)를 정답으로 읽지 못한다. "
               "리뷰어에게 가는 정답 출처는 %s 하나다."
               % (team_layout.SOURCES_FILE, team_layout.original_rel(), team_layout.INTENT_FILE))
TASK_SKIP = "번호 대조 건너뜀 — 번호 파일이 없는 과제다(단순 작업)."
DECISION_LINE_RE = re.compile(r"- (?:[BU]\d+ · 결정 · |D\d+\.\d+ · )")
REJECTED_HEAD = "이 설계가 받지 않기로 한 번호(번호 대조의 기각)"


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
    bmeta = frontmatter(btext)
    kind = unquote(bmeta.get("type", ""))
    if kind not in KINDS and kind != JOB_KIND:
        return refuse("frontmatter type 이 epic-bundle · %s 가 아니다(%s)" % (legacy_names.CONTEXT_BRIEF, kind or "없음"))
    spath = _resolve(spec, root)
    stext = _read(spath)
    if stext is None:
        return refuse("설계문서를 읽지 못했다: %s" % spec)
    src = unquote(legacy_names.source_of(frontmatter(stext)))
    if not src:
        return refuse("설계문서 frontmatter 에 %s 가 없다" % legacy_names.HEAD_KEY)
    if _resolve(src, root) != bpath:
        return refuse("설계문서 %s(%s) 와 다른 파일이다" % (legacy_names.HEAD_KEY, src))
    if kind == JOB_KIND:
        text, warnings, ask = _job_coverage(bpath, unquote(bmeta.get("kind", "")), spath)
        return [text] + (["질문 줄: " + ask] if ask else []) + [
            TEAM_NOTICE, "번호 대조 경고 %d개" % warnings, "bundle-entry: PROCEED %s" % bpath]
    result = cbc.coverage(bpath, spath)
    ask = cbc.short_line(result)
    return [cbc.render(result)] + (["질문 줄: " + ask] if ask else []) + [
        "번호 대조 경고 %d개" % cbc.warning_count(result), "bundle-entry: PROCEED %s" % bpath]


def _job_coverage(intent_path: str, job_kind: str, spec_path: str) -> tuple:
    """과제 파일의 진입 번호 대조 — (글, 경고 수, 질문 줄 — 경고가 없으면 빈 글). 같은 폴더의 번호 파일이 정답 출처다.
    번호 파일이 없으면 단순 작업(kind: task)은 건너뛰고, 그 밖의 과제는 검사 불가(경고 1)다 — 0 으로 내지 않는다."""
    sources = os.path.join(os.path.dirname(intent_path), team_layout.SOURCES_FILE)
    if not os.path.isfile(sources):
        if job_kind == team_files.KIND_TASK:
            return TASK_SKIP, 0, ""
        return (("번호 대조 검사 불가 — kind: %s 과제인데 번호 파일이 없다: %s" % (job_kind or "없음", sources)), 1,
                "번호 대조 경고 1개: 검사 불가")
    result = cbc.coverage(sources, spec_path)
    return cbc.render(result), cbc.warning_count(result), cbc.short_line(result)


def _line(b: dict) -> str:
    ex = b.get("extras") or {}
    extra = ["%s %s" % (k, ex[k]) for k in ("크기", "순서 이유") if k in ex]
    return "%s %s — %s · %s%s" % (b["id"], b["title"], b["stage"], b["reason"],
                                  (" · " + " · ".join(extra)) if extra else "")


def neighbors(bundle: str, root: str) -> list:
    bpath = _resolve(bundle, root)
    btext = _read(bpath)
    if btext is None:
        return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 묶음을 읽지 못했다: %s" % bundle]
    fm = frontmatter(btext)
    kind = unquote(fm.get("type", ""))
    if kind not in ("epic-bundle", JOB_KIND):
        return []
    epic = unquote(fm.get("job" if kind == JOB_KIND else "epic", ""))
    if kind == JOB_KIND:
        try:
            rel = team_files.roadmap_rel({k: unquote(v) for k, v in fm.items()})
        except FormatError as exc:   # 레포 밖을 가리키는 로드맵은 열지 않는다
            return ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — %s" % exc]
    else:
        rel = unquote(fm.get("roadmap", ""))
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
    together = [p["id"] for p in (me.get("parallel") or []) if p["id"] in blocks and blocks[p["id"]]["specs"]]
    out += ["  함께 진행 중: " + _line(blocks[t]) for t in together]
    if problems:
        out.append("  로드맵 상태 검사 불가 %d개 — 위 단계가 틀릴 수 있다: %s" % (len(problems), " · ".join(problems)))
    overlap = {x for o in report["overlaps"] if epic in o["blocks"] for x in o["blocks"] if x != epic}
    near = set(deps) | set(dependents) | overlap | set(together)
    main, _name = git.default_branch()
    try:
        team = team_layout.layout_of(frontmatter(_read(os.path.join(root, rel)) or "")) == team_layout.LAYOUT_TEAM
    except team_layout.UnknownLayout as exc:   # 모르는 형식은 옛 형식 규칙으로 읽지 않는다
        return out + ["이웃 에픽의 결정 — 셀 수 없음: %s" % cbc.unknown_layout(rel, exc.value)]
    if team:
        dec = _team_decisions(git, main, report["blocks"], near)
        return out + ["이웃 에픽의 결정" + ("" if dec else " — 과제 폴더가 있는 이웃 에픽 없음")] + dec
    dec = []
    for b in report["blocks"]:
        if b["id"] not in near or not b["specs"]:
            continue
        tree = main if b["stage"] == "머지됨" else (b.get("tip") or main)
        for spec in b["specs"]:
            text = git.blob(tree, spec) if tree else None
            if text is None:
                dec.append("  %s — 설계문서를 읽지 못했다: %s" % (b["id"], spec))
                continue
            try:
                body = section_body(text, "## 결정 기록") or ""
            except FormatError as exc:   # 못 읽은 절은 「결정 줄 없음」(0)이 아니라 셀 수 없음이다
                dec.append("  %s — 셀 수 없음: 결정 기록 절을 읽지 못했다(%s) — %s" % (b["id"], exc, spec))
                continue
            lines = [l for l in body.splitlines() if DECISION_LINE_RE.match(l)]
            if lines:
                dec.append("  %s — %s" % (b["id"], spec))
                dec += ["    " + l for l in lines]
            else:
                dec.append("  %s — 결정 줄 없음 — %s" % (b["id"], spec))
    out.append("이웃 에픽의 결정" + ("" if dec else " — 설계문서가 있는 이웃 에픽 없음"))
    return out + dec


def _team_decisions(git, main, blocks: list, near: set) -> list:
    """team 이웃(과제 폴더가 있는 블록)마다 그 트리의 INTENT.md 결정 기록 줄. 없음 · 못 읽음 · 칸 깨짐은 「셀 수 없음」 이다."""
    dec = []
    for b in blocks:
        job = b.get("job") or {}
        path = job.get("intent")
        if b["id"] not in near or not path:
            continue
        tree = main if b["stage"] == "머지됨" else (b.get("tip") or main)
        text = git.blob(tree, path) if tree else None
        if text is None:
            why = "과제 파일이 없다" if tree and git.absent(tree, path) else "과제 파일을 읽지 못했다"
            dec.append("  %s — 셀 수 없음: %s — %s" % (b["id"], why, path))
            continue
        try:
            lines = team_files.decision_lines(text)
        except FormatError as exc:
            dec.append("  %s — 셀 수 없음: 결정 기록 칸을 읽지 못했다(%s) — %s" % (b["id"], exc, path))
            continue
        if lines:
            dec.append("  %s — %s" % (b["id"], path))
            dec += ["    " + l for l in lines]
        else:
            dec.append("  %s — 결정 줄 없음 — %s" % (b["id"], path))
    return dec


def rejected(spec: str, root: str) -> list:
    """설계문서 `## 번호 대조` 표의 「기각」 행 — 번호 수와 줄마다 번호 · 이유. 표 절이 없으면 빈 목록."""
    text = _read(_resolve(spec, root))
    if text is None:
        return ["%s — 셀 수 없음: 설계문서를 읽지 못했다(%s)" % (REJECTED_HEAD, spec)]
    try:
        if section_body(text, cbc.TABLE_HEADING) is None:
            return []
        rows = [(ids, cell) for ids, verb, cell in cbc.table_rows(text) if verb.startswith("기각")]
    except FormatError as exc:
        return ["%s — 셀 수 없음: %s" % (REJECTED_HEAD, exc)]
    n = sum(len(ids) for ids, _cell in rows)
    if not n:
        return ["%s 없음" % REJECTED_HEAD]
    head = ("%s %d개 — 반영으로 되돌릴 번호가 있으면 ③ 수정 필요를 고르고 이어지는 질문의 기타 칸에 그 번호를 적는다."
            % (REJECTED_HEAD, n))
    return [head] + ["- %s — %s" % (" · ".join(ids), cell) for ids, cell in rows]


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="spec_review_bundle.py",
                                 description="spec-review --bundle: 정답 출처 확인 · 진입 대조 · 로드맵 위치와 이웃 결정 · 기각 번호.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("entry")
    e.add_argument("--spec", required=True)
    e.add_argument("--bundle", default="")
    e.add_argument("--root", required=True)
    n = sub.add_parser("neighbors")
    n.add_argument("--bundle", required=True)
    n.add_argument("--root", required=True)
    r = sub.add_parser("rejected")
    r.add_argument("--spec", required=True)
    r.add_argument("--root", required=True)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "entry":
            lines = entry(args.spec, args.bundle, args.root)
        elif args.cmd == "rejected":
            lines = rejected(args.spec, args.root)
        else:
            lines = neighbors(args.bundle, args.root)
    except Exception as exc:  # 확인이 죽어도 조용히 통과로 내지 않는다 — 사유를 줄로 낸다
        if args.cmd == "entry":
            lines = ["[spec-distill] 번호 대조 진입 검사 내부 오류 — %s: %s. --bundle 확인과 번호 대조 없이 리뷰한다."
                     % (type(exc).__name__, exc), "질문 줄: 번호 대조 경고 1개: 검사 불가", "번호 대조 경고 1개",
                     "bundle-entry: PROCEED -"]
        elif args.cmd == "rejected":
            lines = ["%s — 셀 수 없음: 내부 오류 %s: %s" % (REJECTED_HEAD, type(exc).__name__, exc)]
        else:
            lines = ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 내부 오류 %s: %s" % (type(exc).__name__, exc)]
    if lines:
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
