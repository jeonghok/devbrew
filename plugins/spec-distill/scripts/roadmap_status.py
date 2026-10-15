#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_status.py — 로드맵과 git 을 읽어 에픽별 단계 · 경고 · 정보를 낸다.

명령줄:
  roadmap_status.py <로드맵 경로>           origin/main 의 로드맵을 읽는다(레포 상대경로)
  roadmap_status.py --roadmap-file <파일>   작업 트리의 로드맵을 읽는다(아직 main 에 없을 때)
  --json 이면 JSON 하나를 낸다.

종료 코드: 0 이상 없음 · 1 경고 있음 · 2 사용법 오류 · 3 검사 불가(로드맵 없음 · 형식 깨짐 ·
블록 하나라도 알 수 없음 · 번호 대조 검사 불가 · 미룸 표 깨짐 · 번호 전체 집합을 못 셈). 3 > 1 > 0.
정보(경로 예약 겹침 · 다른 에픽이 예약한 파일의 편집)는 종료 코드를 바꾸지 않는다 — 충돌은 머지 때 푼다.

읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다. git 은 `GIT_ALLOWED` 의 하위 명령만
부르고 fetch 하지 않는다(지휘 절차가 계산 전에 fetch 한다). 단계는 git 으로 알 수 있는 것까지다 —
구현 중 · 구현 끝 · PR 은 R5 가 붙인다.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_bundle_coverage import check, deferred_rows, receiver_ok  # noqa: E402
from roadmap_model import (  # noqa: E402,F401 — 테스트가 rs.parse_roadmap · rs.brief_universe 로 부른다
    FormatError, brief_universe, collect_assigned, frontmatter, id_sort_key, parse_ids,
    parse_roadmap, section_body, split_list, unquote)

MAIN_REF = "refs/remotes/origin/main"
GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"})
NOTICE = ("머지됨 자동 판정은 merge commit 방식에서만 된다 — 브랜치가 지워졌으면 GitHub 의 머지 메시지 "
          "`Merge pull request #<n> from <owner>/<브랜치>` 로만 알아본다. squash · rebase 로 머지했거나 "
          "로컬에서 머지한 뒤 브랜치를 지웠으면 로드맵 결정 기록에 머지 줄을 적는다. 경로 예약 겹침과 다른 에픽이 "
          "예약한 파일의 편집은 경고가 아니라 정보다 — 에픽은 병렬로 가고 충돌은 머지 때 푼다(나중 PR 이 main 을 "
          "merge 하고 스위트를 다시 돌린다).")
# 경로 예약 겹침 · 위반에서 빼는 공유 파일 — 버전은 머지 직전에 정한다(N6).
SHARED_BASENAMES = ("plugin.json", "CHANGELOG.md", "README.md")
TASK_STATUS = {"대기": "pending", "준비": "pending", "설계 중": "in_progress",
               "계획": "in_progress", "머지됨": "completed", "끝남": "completed"}
DONE = ("머지됨", "끝남")

MERGE_MSG_RE = re.compile(r"Merge pull request #\d+ from [^/\s]+/(\S+)")
BACKTICK_RE = re.compile(r"`([^`]+)`")


# ── git (읽기 전용) ──────────────────────────────────────────────────────────

class Git:
    def __init__(self, cwd: str):
        self.cwd = cwd
        self.env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0",
                        GIT_TERMINAL_PROMPT="0", LC_ALL="C")
        self.failures = []

    def run(self, *args):
        rc, out, _err = self.run_err(*args)
        return rc, out

    def run_err(self, *args):
        if not args or args[0] not in GIT_ALLOWED:
            raise RuntimeError("허용하지 않은 git 하위 명령: %r" % (args[:1],))
        try:
            proc = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=self.cwd,
                                  env=self.env, stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except OSError as exc:
            raise RuntimeError("git 을 실행하지 못했다: %s" % exc)
        return (proc.returncode, proc.stdout.decode("utf-8", "replace"),
                proc.stderr.decode("utf-8", "replace"))

    def fail(self, sub: str, rc: int, err: str):
        first = next((line.strip() for line in err.splitlines() if line.strip()), "(표준 오류 없음)")
        self.failures.append("git %s 실패(rc %d): %s" % (sub, rc, first))

    def commit(self, ref: str):
        rc, out = self.run("rev-parse", "--verify", "--quiet", ref + "^{commit}")
        return out.strip() if rc == 0 and out.strip() else None

    def toplevel(self):
        rc, out = self.run("rev-parse", "--show-toplevel")
        return out.strip() if rc == 0 else None

    def blob(self, rev: str, path: str):
        rc, out = self.run("cat-file", "blob", "%s:%s" % (rev, path))
        return out if rc == 0 else None

    def exists(self, rev: str, path: str) -> bool:
        return self.run("cat-file", "-e", "%s:%s" % (rev, path))[0] == 0

    def is_ancestor(self, a: str, b: str) -> bool:
        return self.run("merge-base", "--is-ancestor", a, b)[0] == 0

    def first_parent_merges(self):
        rc, out, err = self.run_err("log", "--first-parent", "--merges",
                                    "--format=%H%x09%P%x09%s", MAIN_REF)
        if rc != 0:
            self.fail("log", rc, err)
            return []
        merges = []
        for line in out.splitlines():
            parts = line.split("\t", 2)
            if len(parts) == 3:
                merges.append((parts[0], parts[1].split(), parts[2]))
        return merges

    def changed(self, base: str, tip: str):
        rc, out, err = self.run_err("diff", "--name-only", "-z", "%s...%s" % (base, tip))
        if rc != 0:
            self.fail("diff", rc, err)
            return []
        return [p for p in out.split("\0") if p]

    def grep_files(self, tree: str, fixed: str, pathspec: str):
        rc, out, err = self.run_err("grep", "-l", "-z", "-F", "-e", fixed, tree, "--", pathspec)
        if rc == 1 and not err.strip():  # 일치 없음 — git grep 은 이때 rc 1 과 빈 표준 오류다
            return []
        if rc != 0:
            self.fail("grep", rc, err)
            return []
        prefix = tree + ":"
        return [p[len(prefix):] if p.startswith(prefix) else p
                for p in out.split("\0") if p]

    def fetched_at(self):
        # git 은 FETCH_HEAD 를 워크트리마다 쓴다 — 이 워크트리 것과 공용 디렉토리 것 중 새것을 쓴다.
        stamps = []
        for args, tail in ((("rev-parse", "--git-path", "FETCH_HEAD"), ""),
                           (("rev-parse", "--git-common-dir"), "FETCH_HEAD")):
            rc, out = self.run(*args)
            if rc != 0 or not out.strip():
                continue
            try:
                stamps.append(Path(self.cwd, out.strip(), tail).stat().st_mtime)
            except OSError:
                continue
        if not stamps:
            return None
        return datetime.datetime.fromtimestamp(max(stamps)).strftime("%Y-%m-%d %H:%M")


# ── 로드맵 · 묶음 · brief 읽기 ───────────────────────────────────────────────

class Source:
    """로드맵 · 묶음 · brief · audit 을 읽는 사본 — origin/main(rev) 또는 작업 트리(root)."""

    def __init__(self, git: Git, rev=None, root=None):
        self.git, self.rev, self.root = git, rev, root
        self.label = "origin/main" if rev else "작업 트리"

    def read(self, path: str):
        if self.rev:
            return self.git.blob(self.rev, path)
        try:
            return Path(self.root, path).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return None

    def exists(self, path: str) -> bool:
        """사본에 그 경로가 있는가 — 읽을 수 있는지와는 따로 묻는다."""
        if self.rev:
            return self.git.exists(self.rev, path)
        return Path(self.root, path).exists()


# ── 단계 · 경고 ──────────────────────────────────────────────────────────────

def _reserves(entry: str, path: str) -> bool:
    return path == entry or (entry.endswith("/") and path.startswith(entry))


def _shared(path: str) -> bool:
    return path.rsplit("/", 1)[-1] in SHARED_BASENAMES


def _reachable(blocks: list) -> dict:
    deps = {b["id"]: set(b.get("deps", [])) for b in blocks}
    reach = {}
    for n in deps:
        seen, todo = set(), list(deps[n])
        while todo:
            d = todo.pop()
            if d not in seen:
                seen.add(d)
                todo.extend(deps.get(d, ()))
        reach[n] = seen
    return reach


def find_specs(git: Git, tree: str, block: dict, bundle_path):
    if block["kind"] == "branch":
        spec = block["fields"]["spec"].strip().strip("`")
        return [spec] if git.exists(tree, spec) else []
    if block["kind"] != "bundle" or bundle_path is None:
        return []
    found = []
    for path in git.grep_files(tree, bundle_path, "docs/superpowers/specs/"):
        text = git.blob(tree, path)
        if text and unquote(frontmatter(text).get("source_interview", "")) == bundle_path:
            found.append(path)
    return sorted(found)


def has_plan(git: Git, tree: str, spec: str) -> bool:
    for path in git.grep_files(tree, spec, "docs/superpowers/plans/"):
        for line in (git.blob(tree, path) or "").splitlines():
            if line.lstrip().startswith("**Spec:**"):
                m = BACKTICK_RE.search(line)
                if m and m.group(1) == spec:
                    return True
    return False


def merged_by(git: Git, merges: list, main: str, branch: str, tip):
    """머지됨 근거 한 줄, 아니면 None. 조상 관계만으로는 머지됨이 아니다(D1.1)."""
    if tip:
        for sha, parents, _subj in merges:
            if len(parents) >= 2 and parents[1] == tip and not git.is_ancestor(tip, parents[0]):
                return "main 의 머지 커밋 %s" % sha[:8]
    # 머지 메시지가 이 브랜치를 정확히 부른다 — 브랜치가 지워졌거나, 남은 브랜치 끝이 main 에 다 들어가
    # 있을 때만(머지 뒤 로컬 브랜치를 main 으로 앞당긴 경우). 머지 뒤 커밋이 더 붙었으면 머지됨이 아니다.
    if tip and not git.is_ancestor(tip, main):
        return None
    for sha, _parents, subj in merges:
        m = MERGE_MSG_RE.fullmatch(subj.strip())
        if m and m.group(1) == branch:
            return "머지 메시지 %s (%s)" % (sha[:8], "브랜치 끝이 main 에 들어 있음" if tip
                                          else "브랜치는 지워짐")
    return None


class _GitTreeRepo:
    """check() 가 로드맵 · 다른 묶음의 설계문서를 읽는 자리 — 작업 트리가 아니라 한 커밋(main)의 트리에서."""

    def __init__(self, git: Git, tree: str):
        self.git, self.tree = git, tree

    def read(self, rel: str):
        return self.git.blob(self.tree, rel)

    def exists(self, rel: str) -> bool:
        return self.git.exists(self.tree, rel)

    def specs_for(self, source: str) -> list:
        out = []
        for path in self.git.grep_files(self.tree, source, "docs/superpowers/specs/"):
            text = self.git.blob(self.tree, path)
            if text and unquote(frontmatter(text).get("source_interview", "")) == source:
                out.append((path, text))
        return sorted(out)


def compute(git: Git, main, blocks: list, records: list, bundles: dict, roadmap_dir: str):
    """블록마다 stage · reason · warnings · notes · specs 를 채운다. 반환: 번호 대조 검사 불가 사유 목록."""
    merges = git.first_parent_merges() if main else []
    by_id = {b["id"]: b for b in blocks}
    rec = {(r["block"], r["kind"]): r for r in records}
    cov_unknown = []
    order, seen = [], set()

    def place(n):
        if n in seen:
            return
        seen.add(n)
        for d in by_id[n].get("deps", []):
            place(d)
        order.append(n)

    for b in blocks:
        place(b["id"])

    for bid in order:
        b = by_id[bid]
        b.update(stage=None, reason="", warnings=[], notes=[], specs=[], tip=None)
        undone = [d for d in b["deps"] if by_id[d]["stage"] not in DONE]
        if main is None:
            b["stage"], b["reason"] = "알 수 없음", "origin/main 을 못 읽었다"
            continue
        if b["kind"] == "decision":
            r = rec.get((bid, "결정"))
            if r:
                b["stage"], b["reason"] = "끝남", "결정 기록 %s %s" % (r["date"], r["quote"])
            elif undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료"
            continue
        branch = b["fields"]["브랜치"].strip().strip("`")
        tip = git.commit("refs/heads/" + branch) or git.commit("refs/remotes/origin/" + branch)
        b["tip"] = tip
        bundle_path = (roadmap_dir + "/" + b["fields"]["묶음"]) if b["kind"] == "bundle" else None
        why = merged_by(git, merges, main, branch, tip)
        if not why and (bid, "머지") in rec:
            r = rec[(bid, "머지")]
            why = "결정 기록의 머지 기록 %s %s" % (r["date"], r["quote"])
        if why:
            b["stage"], b["reason"] = "머지됨", why
            b["specs"] = find_specs(git, main, b, bundle_path)
        elif not tip:
            if undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료 · 브랜치 없음"
        else:
            b["specs"] = find_specs(git, tip, b, bundle_path)
            if any(has_plan(git, tip, s) for s in b["specs"]):
                b["stage"], b["reason"] = "계획", "계획 있음"
            else:
                b["stage"] = "설계 중"
                b["reason"] = "spec 있음" if b["specs"] else "브랜치 있음 · spec 없음"
            if undone:
                b["warnings"].append("의존 미머지 상태에서 진행 중: %s" % " · ".join(undone))
        if b["kind"] == "bundle" and bundles.get(bid) is None:
            b["warnings"].append("묶음 없음: %s" % bundle_path)
        if len(b["specs"]) > 1:
            b["warnings"].append("spec 여럿: %s" % " · ".join(b["specs"]))
        tree = main if b["stage"] == "머지됨" else tip
        known_ids = set(by_id)
        for spec in b["specs"]:
            spec_text = git.blob(tree, spec)
            if spec_text is None:
                b["warnings"].append("번호 대조 검사 불가(spec 을 읽지 못했다): %s" % spec)
                cov_unknown.append("%s spec 을 읽지 못했다" % bid)
                continue
            if b["kind"] == "bundle" and bundles.get(bid) is not None:
                result = check(bundles[bid], spec_text, repo=_GitTreeRepo(git, main) if main else None)
                for w in coverage_warnings(result, spec):  # 종료 코드는 그대로 — 경고 줄만
                    b["warnings"].append(w)
                if result["status"] == 1:
                    b["warnings"].append("생략: %s 이 번호 %d개를 빠뜨렸다 — %s" % (
                        spec, len(result["missing"]), " · ".join(result["missing"])))
                elif result["status"] == 3:
                    b["warnings"].append("번호 대조 검사 불가(%s): %s" % (result["reason"], spec))
                    cov_unknown.append("%s %s" % (bid, result["reason"]))
            # 미룸(R3 §3-3) — 받는 곳이 `#<숫자>` 나 로드맵의 에픽이 아닌 행. 머지 뒤에도 남는다.
            try:
                rows = deferred_rows(spec_text)
            except FormatError as exc:
                b["warnings"].append("미룸 셀 수 없음(%s): %s" % (exc, spec))
                cov_unknown.append("%s 미룸 표 — %s" % (bid, exc))
                continue
            bad = [item for item, _why, recv in rows if not receiver_ok(recv, known_ids)]
            if bad:
                b["warnings"].append("받는 곳 없는 미룸 %d개: %s — %s" % (len(bad), spec, " · ".join(bad)))

    for b in blocks:
        if b["tip"] and b["stage"] in ("설계 중", "계획"):
            for path in git.changed(main, b["tip"]):
                if _shared(path):
                    continue
                owners = [o["id"] for o in blocks
                          if any(_reserves(e, path) for e in o["reserved"])]
                if owners and b["id"] not in owners:  # 정보 — 종료 코드를 바꾸지 않는다
                    b["notes"].append("경로 예약 위반: %s 은 %s 만 예약했다"
                                         % (path, " · ".join(owners)))
    return cov_unknown


def coverage_warnings(result: dict, spec: str) -> list:
    out = []
    shallow = result.get("shallow") or []
    if shallow:
        out.append("얕은 답 %d개: %s — %s" % (len(shallow), spec, " · ".join(
            "%s(%s)" % (x["id"], x["reason"]) for x in shallow)))
    unserved = result.get("unserved") or []
    if unserved:
        out.append("받드는 에픽 없는 발화 %d개: %s — %s" % (len(unserved), spec, " · ".join(unserved)))
    return out


def overlaps(blocks: list) -> list:
    reach, out = _reachable(blocks), []
    for i, a in enumerate(blocks):
        for b in blocks[i + 1:]:
            if b["id"] in reach[a["id"]] or a["id"] in reach[b["id"]]:
                continue
            shared = sorted({ea for ea in a["reserved"] for eb in b["reserved"]
                             if not _shared(ea) and (_reserves(ea, eb) or _reserves(eb, ea))})
            if shared:
                out.append({"blocks": [a["id"], b["id"]], "paths": shared})
    return out


# ── 출력 ─────────────────────────────────────────────────────────────────────

def build(git: Git, args) -> dict:
    report = {"roadmap": None, "source": None, "fetched_at": git.fetched_at(), "notice": NOTICE,
              "blocks": [], "unassigned": None, "orphans": None, "unknown_ids": [],
              "overlaps": [], "format_errors": [], "unknown_reasons": [], "exit": 3}
    main = git.commit(MAIN_REF)
    if args.roadmap_file:
        top = git.toplevel()
        if top is None:
            report["unknown_reasons"].append("git 레포 안이 아니다")
            return report
        rel = os.path.relpath(os.path.realpath(args.roadmap_file), os.path.realpath(top))
        src = Source(git, root=top)
        if main is None:
            report["unknown_reasons"].append("origin/main 을 못 읽었다")
    else:
        rel = args.roadmap.strip("/")
        if main is None:
            report["unknown_reasons"].append("origin/main 을 못 읽었다")
            report["roadmap"], report["source"] = rel, "origin/main"
            return report
        src = Source(git, rev=main)
    report["roadmap"], report["source"] = rel, src.label
    text = src.read(rel)
    if text is None:
        report["unknown_reasons"].append("로드맵을 못 읽었다: %s (%s)" % (rel, src.label))
        return report
    meta, blocks, records, risk_rows, errors = parse_roadmap(text)
    report["format_errors"] = errors
    if errors:
        report["blocks"] = [{"id": b["id"], "title": b["title"], "kind": b.get("kind"),
                             "stage": "알 수 없음", "reason": "로드맵 형식 깨짐",
                             "task_status": None, "branch": b["fields"].get("브랜치"),
                             "deps": [], "specs": [], "ids": [], "warnings": [], "notes": []}
                            for b in blocks]
        return report

    roadmap_dir = rel.rsplit("/", 1)[0] if "/" in rel else "."
    bundles, union, errs = collect_assigned(blocks, meta, rel, src.read, src.exists)
    report["format_errors"].extend(errs)
    if report["format_errors"]:
        return report

    brief_path = unquote(meta["source_brief"])
    brief = src.read(brief_path)
    audit = src.read(brief_path[:-3] + ".audit.md") if brief_path.endswith(".md") else None
    try:
        if brief is None or audit is None:
            raise FormatError("brief 또는 audit 을 못 읽었다: %s" % brief_path)
        non_s, s_ids, k_expected = brief_universe(brief, audit)
    except FormatError as exc:
        report["unknown_reasons"].append("번호 전체 집합을 셀 수 없다 — %s" % exc)
    else:
        if risk_rows != k_expected:
            diff = [k for k, _ in k_expected if (k, dict(k_expected)[k]) not in risk_rows]
            report["format_errors"].append("위험 번호표가 brief §5 위험 줄과 다르다: %s"
                                           % (" · ".join(diff) or "줄 수가 다르다"))
        report["unassigned"] = sorted(non_s - union, key=id_sort_key)
        report["orphans"] = sorted(s_ids - union, key=id_sort_key)
        report["unknown_ids"] = sorted(union - non_s - s_ids, key=id_sort_key)

    cov_unknown = compute(git, main, blocks, records, bundles, roadmap_dir)
    report["unknown_reasons"] += ["번호 대조 검사 불가 — %s" % c for c in cov_unknown]
    report["unknown_reasons"] += ["git 읽기 실패 — %s" % f for f in git.failures]
    report["overlaps"] = overlaps(blocks)
    for b in blocks:
        ids = b["assigned"]
        report["blocks"].append({
            "id": b["id"], "title": b["title"], "kind": b["kind"], "stage": b["stage"],
            "reason": b["reason"], "task_status": TASK_STATUS.get(b["stage"]),
            "branch": b["fields"].get("브랜치"), "deps": b["deps"], "specs": b["specs"],
            "ids": sorted(ids, key=id_sort_key), "warnings": b["warnings"], "notes": b["notes"]})
    return report


def exit_code(report: dict) -> int:
    """notes · overlaps 는 정보라 세지 않는다."""
    if (report["format_errors"] or report["unknown_reasons"]
            or any(b["stage"] == "알 수 없음" for b in report["blocks"])):
        return 3
    if (any(b["warnings"] for b in report["blocks"]) or report["unassigned"]
            or report["orphans"] or report["unknown_ids"]):
        return 1
    return 0


def render(report: dict) -> str:
    nwarn = sum(len(b["warnings"]) for b in report["blocks"])
    ninfo = sum(len(b.get("notes", [])) for b in report["blocks"]) + len(report["overlaps"])
    lines = ["로드맵 상태 — 블록 %d개 · 경고 %d개 · 정보 %d개 · 검사 불가 %d개 (사본: %s · origin/main 받은 시각: %s)"
             % (len(report["blocks"]), nwarn, ninfo,
                len(report["format_errors"]) + len(report["unknown_reasons"]),
                report["source"] or "알 수 없음", report["fetched_at"] or "알 수 없음"),
             report["notice"], ""]
    for b in report["blocks"]:
        lines.append("%s %s — %s · %s" % (b["id"], b["title"], b["stage"], b["reason"]))
        if b.get("ids"):
            lines.append("    번호: %s" % " · ".join(b["ids"]))
        lines += ["    경고: %s" % w for w in b["warnings"]]
        lines += ["    정보: %s" % n for n in b.get("notes", [])]
    for label, key in (("미배정 번호", "unassigned"), ("고아 발화", "orphans")):
        vals = report[key]
        lines.append("%s: %s" % (label, "셀 수 없음" if vals is None
                                 else "%d개%s" % (len(vals), " — " + " · ".join(vals) if vals else "")))
    if report["unknown_ids"]:
        lines.append("brief 에 없는 번호: %s" % " · ".join(report["unknown_ids"]))
    lines.append("경로 예약 겹침(정보): %d개" % len(report["overlaps"]))
    lines += ["    %s ↔ %s: %s" % (o["blocks"][0], o["blocks"][1], " · ".join(o["paths"]))
              for o in report["overlaps"]]
    lines += ["형식 깨짐: %s" % e for e in report["format_errors"]]
    lines += ["검사 불가: %s" % r for r in report["unknown_reasons"]]
    return "\n".join(lines)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="roadmap_status.py",
                                 description="로드맵과 git 을 읽어 에픽별 단계 · 경고 · 정보를 낸다.")
    where = ap.add_mutually_exclusive_group(required=True)
    where.add_argument("roadmap", nargs="?", help="origin/main 기준 로드맵 레포 상대경로")
    where.add_argument("--roadmap-file", help="작업 트리의 로드맵 파일")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    try:
        report = build(Git(os.getcwd()), args)
        report["exit"] = exit_code(report)
    except Exception as exc:  # 계산이 죽어도 이상 없음(0)·경고(1)로 내지 않는다
        report = {"roadmap": None, "source": None, "fetched_at": None, "notice": NOTICE,
                  "blocks": [], "unassigned": None, "orphans": None, "unknown_ids": [],
                  "overlaps": [], "format_errors": [],
                  "unknown_reasons": ["내부 오류 — %s: %s" % (type(exc).__name__, exc)], "exit": 3}
    print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else render(report))
    return report["exit"]


if __name__ == "__main__":
    sys.exit(main())
